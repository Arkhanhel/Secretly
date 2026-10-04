#include "flutter_window.h"

#include <windowsx.h>

#include <cwchar>
#include <optional>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "single_instance.h"

namespace {

// 🔴 РАМКА ВОКРУГ ОКНА (26.09.2026, владелец: «везде по бокам какая-то рамка
// вокруг окна приложения кроме верхней части, это раздражает и выглядит
// дёшево»).
//
// Окно у нас без системной шапки: её рисует само приложение. Плагин
// `window_manager` добивается этого так: в ответ на WM_NCCALCSIZE он ужимает
// клиентскую область на 8 точек слева, справа и снизу — и НИ НА ОДНУ сверху
// (`window_manager_plugin.cpp`, ветка `title_bar_style_ == "hidden"`). Отступы
// нужны ему, чтобы окно можно было тянуть за края: тянет их Windows, а тянуть
// она умеет только за нерабочую область. Но эту нерабочую область Windows ещё
// и ЗАКРАШИВАЕТ — системным цветом рамки. Отсюда и полоса с трёх сторон, и
// отсутствие её сверху.
//
// Здесь мы перехватываем те же два сообщения ДО плагина:
//
//   WM_NCCALCSIZE — клиентская область равна всему окну, поэтому приложение
//                   рисует до самого края и системной рамке негде взяться;
//   WM_NCHITTEST  — зоны перетаскивания краёв мы считаем сами, внутри окна.
//
// Так делают Telegram, VS Code и пакет `bitsdojo_window`. Плагин этих двух
// сообщений больше не видит; всё остальное (перетаскивание за шапку, кнопки
// окна, полноэкранный режим) остаётся за ним.

// Толщина зоны, за которую окно тянут мышью, в точках интерфейса. Шесть —
// как у невидимой рамки Windows; в углах зона шире, там её ищут на ощупь.
constexpr int kResizeGripDip = 6;
constexpr int kResizeCornerDip = 14;

// Настоящий номер сборки Windows. `IsWindows11OrGreater` из VersionHelpers
// про Windows 11 не знает, а манифест совместимости подделывает ответ
// `GetVersionEx`, поэтому спрашиваем ядро напрямую.
bool IsWindows11OrLater() {
  static const bool result = [] {
    using RtlGetVersionPtr = LONG(WINAPI*)(PRTL_OSVERSIONINFOW);
    HMODULE ntdll = ::GetModuleHandleW(L"ntdll.dll");
    if (!ntdll) return false;
    auto rtl_get_version = reinterpret_cast<RtlGetVersionPtr>(
        ::GetProcAddress(ntdll, "RtlGetVersion"));
    if (!rtl_get_version) return false;
    RTL_OSVERSIONINFOW info = {};
    info.dwOSVersionInfoSize = sizeof(info);
    if (rtl_get_version(&info) != 0) return false;
    return info.dwMajorVersion > 10 ||
           (info.dwMajorVersion == 10 && info.dwBuildNumber >= 22000);
  }();
  return result;
}

int ScaleForWindow(HWND hwnd, int dip) {
  static const auto get_dpi_for_window =
      reinterpret_cast<UINT(WINAPI*)(HWND)>(::GetProcAddress(
          ::GetModuleHandleW(L"user32.dll"), "GetDpiForWindow"));
  const UINT dpi = get_dpi_for_window ? get_dpi_for_window(hwnd) : 96;
  return ::MulDiv(dip, dpi == 0 ? 96 : dpi, 96);
}

// Можно ли окно тянуть за края прямо сейчас. Полноэкранный режим (так
// открывается видеозвонок) плагин делает, снимая со стиля WS_THICKFRAME, —
// спрашиваем ровно то, что он меняет, а не сравниваем размеры с экраном:
// окно, растянутое человеком по размеру монитора, края терять не должно.
bool IsResizableWindow(HWND hwnd) {
  return (::GetWindowLong(hwnd, GWL_STYLE) & WS_THICKFRAME) != 0;
}

// Развёрнутое окно Windows делает шире экрана на толщину рамки. Если этого не
// учесть, у развёрнутого окна срежет края. Клиентскую область кладём ровно в
// рабочую часть экрана — так же поступает и сам плагин.
void ClampToWorkArea(HWND hwnd, NCCALCSIZE_PARAMS* params) {
  // Монитор ищем по прямоугольнику окна, а не по самому окну: развёрнутое из
  // свёрнутого окно Windows на мгновение считает стоящим на левом мониторе.
  HMONITOR monitor =
      ::MonitorFromRect(&params->rgrc[0], MONITOR_DEFAULTTONEAREST);
  if (!monitor) return;
  MONITORINFO mi = {};
  mi.cbSize = sizeof(mi);
  if (!::GetMonitorInfo(monitor, &mi)) return;
  params->rgrc[0] = mi.rcWork;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  child_windows_ = std::make_unique<ChildWindowHost>(
      flutter_controller_->engine()->messenger(), GetHandle());
  taskbar_badge_ = std::make_unique<TaskbarBadge>(
      flutter_controller_->engine()->messenger(), GetHandle());
  screen_privacy_ = std::make_unique<ScreenPrivacyChannel>(
      flutter_controller_->engine()->messenger(), GetHandle());
  // 🔴 Сторож буфера (01.10.2026): набор восстановления стирается из буфера,
  // если он там ещё лежит. «Ещё лежит» — это «номер буфера не сменился с
  // нашего копирования»; содержимое для этого читать не нужно.
  clipboard_guard_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "secretly/clipboard_guard",
          &flutter::StandardMethodCodec::GetInstance());
  clipboard_guard_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "changeCount") {
          result->Success(flutter::EncodableValue(
              static_cast<int64_t>(::GetClipboardSequenceNumber())));
          return;
        }
        result->NotImplemented();
      });
  // Метка главного окна: по ней повторный запуск находит именно нас
  // (single_instance.cpp).
  ::SetPropW(GetHandle(), kSecretlyMainWindowProp,
             reinterpret_cast<HANDLE>(static_cast<INT_PTR>(1)));

  // 🔴 Автозапуск «свёрнутым» (28.09.2026): Windows запускает нас при входе
  // с `--autostart --minimized`, и окно не должно мелькать — приложение ждёт
  // в трее. Если значка в трее не окажется, окно покажет сама программа
  // (main_desktop.dart), иначе до неё было бы не добраться.
  const bool start_minimized =
      std::wcsstr(::GetCommandLineW(), L"--minimized") != nullptr;
  flutter_controller_->engine()->SetNextFrameCallback([&, start_minimized]() {
    if (!start_minimized) this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (HWND handle = GetHandle()) {
    ::RemovePropW(handle, kSecretlyMainWindowProp);
  }
  // 🔴 Отдельные окна — ДО движка: их виды принадлежат ему.
  child_windows_ = nullptr;
  taskbar_badge_ = nullptr;
  if (clipboard_guard_) {
    clipboard_guard_->SetMethodCallHandler(nullptr);
    clipboard_guard_ = nullptr;
  }
  screen_privacy_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

std::optional<LRESULT> FlutterWindow::HandleFrameMessage(
    HWND hwnd, UINT const message, WPARAM const wparam,
    LPARAM const lparam) noexcept {
  // Повторный запуск Secretly.exe просит показаться (single_instance.cpp).
  // Окно может быть спрятано в трей или свёрнуто. Фокус даёт событие
  // WM_ACTIVATE — по нему приложение само отмечает окно видимым.
  // Проводник пересоздал кнопку окна — вернуть значок непрочитанных.
  if (message == TaskbarBadge::TaskbarButtonCreatedMessage()) {
    if (taskbar_badge_) taskbar_badge_->OnTaskbarButtonCreated();
    return std::nullopt;
  }
  if (message == SecretlyShowWindowMessage()) {
    ::ShowWindow(hwnd, ::IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
    ::SetForegroundWindow(hwnd);
    return 0;
  }
  switch (message) {
    case WM_NCCALCSIZE: {
      if (wparam != TRUE) return std::nullopt;
      auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
      if (::IsZoomed(hwnd)) {
        ClampToWorkArea(hwnd, params);
      } else if (IsResizableWindow(hwnd) && !IsWindows11OrLater()) {
        // Windows 10 рисует поверх самой верхней строки окна светлую черту, и
        // убрать её нельзя — только оставить снаружи клиентской области.
        params->rgrc[0].top += 1;
      }
      // Клиентская область — всё окно. Ни одного отступа: рамке неоткуда
      // взяться (см. примечание в начале файла).
      return 0;
    }
    case WM_NCHITTEST: {
      // Полей у окна больше нет, поэтому системная проверка вернёт «рабочая
      // область» для всего окна. Края считаем сами.
      const LRESULT system = ::DefWindowProc(hwnd, message, wparam, lparam);
      if (system != HTCLIENT) return system;
      if (::IsZoomed(hwnd) || !IsResizableWindow(hwnd)) return std::nullopt;

      POINT cursor = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      if (!::ScreenToClient(hwnd, &cursor)) return std::nullopt;
      RECT client = {};
      if (!::GetClientRect(hwnd, &client)) return std::nullopt;

      const int grip = ScaleForWindow(hwnd, kResizeGripDip);
      const int corner = ScaleForWindow(hwnd, kResizeCornerDip);
      const bool left = cursor.x < grip;
      const bool right = cursor.x >= client.right - grip;
      const bool top = cursor.y < grip;
      const bool bottom = cursor.y >= client.bottom - grip;
      // В углу ловим по более широкой зоне, иначе в неё не попасть мышью.
      const bool corner_left = cursor.x < corner;
      const bool corner_right = cursor.x >= client.right - corner;
      const bool corner_top = cursor.y < corner;
      const bool corner_bottom = cursor.y >= client.bottom - corner;

      if ((top && corner_left) || (left && corner_top)) return HTTOPLEFT;
      if ((top && corner_right) || (right && corner_top)) return HTTOPRIGHT;
      if ((bottom && corner_left) || (left && corner_bottom))
        return HTBOTTOMLEFT;
      if ((bottom && corner_right) || (right && corner_bottom))
        return HTBOTTOMRIGHT;
      if (left) return HTLEFT;
      if (right) return HTRIGHT;
      if (top) return HTTOP;
      if (bottom) return HTBOTTOM;
      // Остальное — рабочая область: за шапку окно тянет само приложение.
      return std::nullopt;
    }
    case WM_ENDSESSION: {
      // 🔴 Выключение или выход из системы. Крестик у нас прячет окно в трей,
      // и без этой ветки Windows ждала бы нас до упора, а потом убивала —
      // «приложение мешает завершению работы». Уходим сами: база пишется
      // синхронно, терять при выходе нечего.
      if (wparam == TRUE) {
        ::ExitProcess(0);
      }
      return std::nullopt;
    }
    default:
      return std::nullopt;
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Рамка окна — до плагина: WM_NCCALCSIZE и WM_NCHITTEST он обрабатывает
  // по-своему, и его ответ как раз и рисует полосу по краям. Всё остальное
  // достаётся ему нетронутым.
  if (std::optional<LRESULT> frame =
          HandleFrameMessage(hwnd, message, wparam, lparam)) {
    return *frame;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
