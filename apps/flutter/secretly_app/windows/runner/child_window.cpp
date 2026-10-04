#include "child_window.h"

#include "screen_privacy.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>
#include <mmsystem.h>
#include <shellapi.h>

#include <algorithm>
#include <utility>
#include <variant>

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#pragma comment(lib, "winmm.lib")
#pragma comment(lib, "shell32.lib")

// Внутренний API движка Windows (flutter_windows_internal.h, Flutter 3.41):
// функции экспортируются из flutter_windows.dll, но в публичных заголовках их
// нет. Сигнатуры сверены с исходником движка той же версии; сторож —
// test/desktop_child_windows_test.dart.
extern "C" {
typedef struct {
  int width;
  int height;
} FlutterDesktopViewControllerProperties;

FLUTTER_EXPORT FlutterDesktopViewControllerRef
FlutterDesktopEngineCreateViewController(
    FlutterDesktopEngineRef engine,
    const FlutterDesktopViewControllerProperties* properties);

FLUTTER_EXPORT FlutterDesktopEngineRef
FlutterDesktopEngineForId(int64_t engine_id);
}

namespace {

std::wstring Utf16FromUtf8(const std::string& text) {
  if (text.empty()) return std::wstring();
  const int length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
      static_cast<int>(text.size()), nullptr, 0);
  if (length <= 0) return std::wstring();
  std::wstring out(length, L'\0');
  ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
                        static_cast<int>(text.size()), out.data(), length);
  return out;
}

const flutter::EncodableValue* Find(const flutter::EncodableMap& args,
                                    const char* key) {
  auto it = args.find(flutter::EncodableValue(std::string(key)));
  return it == args.end() ? nullptr : &it->second;
}

std::string StringArg(const flutter::EncodableMap& args, const char* key) {
  const auto* value = Find(args, key);
  if (!value) return std::string();
  if (const auto* s = std::get_if<std::string>(value)) return *s;
  return std::string();
}

double DoubleArg(const flutter::EncodableMap& args, const char* key,
                 double fallback) {
  const auto* value = Find(args, key);
  if (!value) return fallback;
  if (const auto* d = std::get_if<double>(value)) return *d;
  if (const auto* i = std::get_if<int32_t>(value)) return *i;
  if (const auto* l = std::get_if<int64_t>(value)) {
    return static_cast<double>(*l);
  }
  return fallback;
}

int64_t IntArg(const flutter::EncodableMap& args, const char* key) {
  const auto* value = Find(args, key);
  if (!value) return 0;
  if (const auto* i = std::get_if<int32_t>(value)) return *i;
  if (const auto* l = std::get_if<int64_t>(value)) return *l;
  return 0;
}

bool BoolArg(const flutter::EncodableMap& args, const char* key) {
  const auto* value = Find(args, key);
  if (!value) return false;
  if (const auto* b = std::get_if<bool>(value)) return *b;
  return false;
}

}  // namespace

SecretlyChildWindow::SecretlyChildWindow(
    FlutterDesktopEngineRef engine,
    std::string id,
    int min_width,
    int min_height,
    bool notification,
    std::function<void(const std::string&)> on_close)
    : engine_(engine),
      id_(std::move(id)),
      min_width_(min_width),
      min_height_(min_height),
      on_close_(std::move(on_close)),
      no_activate_(notification) {
  // 🔴 Окошко уведомления РОЖДАЕТСЯ окошком (29.09.2026, разбор Р1): без
  // рамки и кнопки на панели задач, поверх всех и без фокуса. Раньше окно
  // создавалось обычным, и OnCreate отдавал фокус виду (SetChildContent →
  // SetFocus) ещё до MakeNotificationPopup — окошко забирало фокус у того,
  // где человек печатал.
  if (notification) {
    SetCreationStyle(WS_POPUP,
                     WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_TOPMOST,
                     false);
  }
}

// 🔴 Уничтожение — ЗДЕСЬ, а не в деструкторе базы: там виртуальный
// `OnDestroy` уже базовый, и вид движка остался бы висеть.
SecretlyChildWindow::~SecretlyChildWindow() { Destroy(); }

bool SecretlyChildWindow::OnCreate() {
  if (!Win32Window::OnCreate()) return false;
  const RECT frame = GetClientArea();
  const FlutterDesktopViewControllerProperties properties = {
      frame.right - frame.left, frame.bottom - frame.top};
  controller_ = FlutterDesktopEngineCreateViewController(engine_, &properties);
  if (!controller_) return false;
  view_id_ = FlutterDesktopViewControllerGetViewId(controller_);
  FlutterDesktopViewRef view = FlutterDesktopViewControllerGetView(controller_);
  SetChildContent(FlutterDesktopViewGetHWND(view));
  ApplyDarkFrame();
  return true;
}

// Вызывается дважды: из `Destroy()` и из WM_DESTROY базы. Вид — один раз.
void SecretlyChildWindow::OnDestroy() {
  if (controller_ != nullptr) {
    FlutterDesktopViewControllerRef controller = controller_;
    controller_ = nullptr;
    FlutterDesktopViewControllerDestroy(controller);
  }
  Win32Window::OnDestroy();
}

LRESULT SecretlyChildWindow::MessageHandler(HWND hwnd, UINT const message,
                                            WPARAM const wparam,
                                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_CLOSE:
      // Крестик окна: решает Dart (звонок спросит, завершить ли его). Само
      // окно закрывает только вызов `close` — после того, как Dart снял вид.
      if (on_close_) on_close_(id_);
      return 0;
    case WM_GETMINMAXINFO: {
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      const UINT dpi = FlutterDesktopGetDpiForHWND(hwnd);
      info->ptMinTrackSize.x = ::MulDiv(min_width_, dpi, 96);
      info->ptMinTrackSize.y = ::MulDiv(min_height_, dpi, 96);
      return 0;
    }
    case WM_DWMCOLORIZATIONCOLORCHANGED:
      // Окно звонка тёмное при любой теме системы.
      ApplyDarkFrame();
      return 0;
    case WM_MOUSEACTIVATE:
      // Щелчок по уведомлению не отнимает фокус у того, где человек пишет.
      if (no_activate_) return MA_NOACTIVATE;
      break;
    case WM_ACTIVATE:
      // Базовое окно передаёт фокус виду Flutter при активации; окошку
      // уведомления фокус не нужен вовсе.
      if (no_activate_) return 0;
      break;
  }
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void SecretlyChildWindow::ApplyDarkFrame() {
  if (HWND handle = GetHandle()) {
    BOOL dark = TRUE;
    ::DwmSetWindowAttribute(handle, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark,
                            sizeof(dark));
  }
}

void SecretlyChildWindow::MakeNotificationPopup() {
  HWND handle = GetHandle();
  if (!handle) return;
  // Стили окошка заданы при создании (см. конструктор). Windows 11 скругляет
  // углы и у окна без рамки — по просьбе.
  const int round = 2;  // DWMWCP_ROUND
  ::DwmSetWindowAttribute(handle, DWMWA_WINDOW_CORNER_PREFERENCE, &round,
                          sizeof(round));
  ::SetWindowPos(handle, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
}

void SecretlyChildWindow::PlaceAtCorner(int slot, int margin_dip,
                                        int gap_dip) {
  HWND handle = GetHandle();
  if (!handle) return;
  MONITORINFO mi = {};
  mi.cbSize = sizeof(mi);
  const POINT origin = {0, 0};
  ::GetMonitorInfo(::MonitorFromPoint(origin, MONITOR_DEFAULTTOPRIMARY), &mi);
  RECT self = {};
  ::GetWindowRect(handle, &self);
  const int w = self.right - self.left;
  const int h = self.bottom - self.top;
  const UINT dpi = FlutterDesktopGetDpiForHWND(handle);
  const int margin = ::MulDiv(margin_dip, dpi, 96);
  const int gap = ::MulDiv(gap_dip, dpi, 96);
  const int x = mi.rcWork.right - margin - w;
  const int y = mi.rcWork.bottom - margin - h - slot * (h + gap);
  ::SetWindowPos(handle, HWND_TOPMOST, x, y, 0, 0,
                 SWP_NOSIZE | SWP_NOACTIVATE);
}

void SecretlyChildWindow::SetTopmost(bool on) {
  if (HWND handle = GetHandle()) {
    ::SetWindowPos(handle, on ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  }
}

// Во весь экран — без рамки на весь монитор, как у видео в Telegram. Обычное
// «развернуть» оставило бы шапку окна и панель задач.
void SecretlyChildWindow::SetFullScreen(bool on) {
  HWND handle = GetHandle();
  if (!handle || on == full_screen_) return;
  if (on) {
    saved_style_ = ::GetWindowLong(handle, GWL_STYLE);
    ::GetWindowRect(handle, &saved_rect_);
    MONITORINFO mi = {};
    mi.cbSize = sizeof(mi);
    ::GetMonitorInfo(::MonitorFromWindow(handle, MONITOR_DEFAULTTONEAREST),
                     &mi);
    ::SetWindowLong(handle, GWL_STYLE,
                    saved_style_ & ~(WS_CAPTION | WS_THICKFRAME));
    ::SetWindowPos(handle, nullptr, mi.rcMonitor.left, mi.rcMonitor.top,
                   mi.rcMonitor.right - mi.rcMonitor.left,
                   mi.rcMonitor.bottom - mi.rcMonitor.top,
                   SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  } else {
    ::SetWindowLong(handle, GWL_STYLE, saved_style_);
    ::SetWindowPos(handle, nullptr, saved_rect_.left, saved_rect_.top,
                   saved_rect_.right - saved_rect_.left,
                   saved_rect_.bottom - saved_rect_.top,
                   SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  }
  full_screen_ = on;
}

void SecretlyChildWindow::Minimize() {
  if (HWND handle = GetHandle()) ::ShowWindow(handle, SW_MINIMIZE);
}

void SecretlyChildWindow::Present() {
  HWND handle = GetHandle();
  if (!handle) return;
  if (no_activate_) {
    ::ShowWindow(handle, SW_SHOWNOACTIVATE);
    ::SetWindowPos(handle, HWND_TOPMOST, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    return;
  }
  ::ShowWindow(handle, ::IsIconic(handle) ? SW_RESTORE : SW_SHOW);
  ::SetForegroundWindow(handle);
}

// 🔴 «ОТВЕТИТЬ» В ОКОШКЕ УВЕДОМЛЕНИЯ (30.09.2026). Окошко рождается без
// фокуса (WS_EX_NOACTIVATE, MA_NOACTIVATE) — так оно не отнимает ввод у того,
// где человек печатает. Но ответить можно, только если в окошко можно
// печатать: по нажатию «Ответить» флаг снимается, окошко выходит вперёд и
// получает клавиатуру. Щелчок был по самому окошку — последнее действие
// человека принадлежит нашему процессу, и SetForegroundWindow система
// разрешает. После отправки окошко закрывается.
void SecretlyChildWindow::AllowFocus() {
  HWND handle = GetHandle();
  if (!handle) return;
  if (no_activate_) {
    no_activate_ = false;
    const LONG_PTR ex = ::GetWindowLongPtr(handle, GWL_EXSTYLE);
    ::SetWindowLongPtr(handle, GWL_EXSTYLE,
                       ex & ~static_cast<LONG_PTR>(WS_EX_NOACTIVATE));
    ::SetWindowPos(handle, nullptr, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
  }
  ::SetForegroundWindow(handle);
  // Клавиатура — виду Flutter, а не рамке окна.
  if (HWND content = ::GetWindow(handle, GW_CHILD)) ::SetFocus(content);
}

void SecretlyChildWindow::SetTitle(const std::wstring& title) {
  if (HWND handle = GetHandle()) ::SetWindowTextW(handle, title.c_str());
}

// 🔴 Окно растёт от СЕРЕДИНЫ и не выходит за рабочую область монитора
// (29.09.2026, разбор Р1). Раньше рос правый нижний угол (SWP_NOMOVE):
// входящий стоит у края экрана, и после «Принять» кнопки разговора уезжали
// под панель задач или за край. Наименьший размер приходит вместе с новым
// видом окна — иначе разговор ужимался до 340×190 входящего.
void SecretlyChildWindow::SetLogicalSize(double width, double height,
                                         double min_width,
                                         double min_height) {
  HWND handle = GetHandle();
  if (!handle) return;
  // Наименьший — до изменения размера: его спросит WM_GETMINMAXINFO.
  if (min_width > 0) min_width_ = static_cast<int>(min_width);
  if (min_height > 0) min_height_ = static_cast<int>(min_height);
  // Во весь экран и свёрнутым размер не трогаем: у них своё место.
  if (full_screen_ || ::IsIconic(handle)) return;
  const UINT dpi = FlutterDesktopGetDpiForHWND(handle);
  RECT window = {};
  RECT client = {};
  ::GetWindowRect(handle, &window);
  ::GetClientRect(handle, &client);
  // Размер задаётся рабочей области; рамку и шапку прибавляем как есть.
  const int frame_w = (window.right - window.left) - client.right;
  const int frame_h = (window.bottom - window.top) - client.bottom;
  int w = ::MulDiv(static_cast<int>(width), dpi, 96) + frame_w;
  int h = ::MulDiv(static_cast<int>(height), dpi, 96) + frame_h;
  MONITORINFO mi = {};
  mi.cbSize = sizeof(mi);
  ::GetMonitorInfo(::MonitorFromWindow(handle, MONITOR_DEFAULTTONEAREST), &mi);
  const RECT work = mi.rcWork;
  w = std::min(w, static_cast<int>(work.right - work.left));
  h = std::min(h, static_cast<int>(work.bottom - work.top));
  const int center_x = window.left + (window.right - window.left) / 2;
  const int center_y = window.top + (window.bottom - window.top) / 2;
  int x = center_x - w / 2;
  int y = center_y - h / 2;
  x = std::max(static_cast<int>(work.left),
               std::min(x, static_cast<int>(work.right) - w));
  y = std::max(static_cast<int>(work.top),
               std::min(y, static_cast<int>(work.bottom) - h));
  ::SetWindowPos(handle, nullptr, x, y, w, h, SWP_NOZORDER | SWP_NOACTIVATE);
}

void SecretlyChildWindow::CenterOver(HWND owner) {
  HWND handle = GetHandle();
  if (!handle) return;
  RECT self = {};
  ::GetWindowRect(handle, &self);
  const int w = self.right - self.left;
  const int h = self.bottom - self.top;
  HMONITOR monitor = ::MonitorFromWindow(owner ? owner : handle,
                                         MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO mi = {};
  mi.cbSize = sizeof(mi);
  ::GetMonitorInfo(monitor, &mi);
  RECT area = mi.rcWork;
  // Главное окно спрятано в трей или свёрнуто — по центру экрана.
  if (owner && ::IsWindowVisible(owner) && !::IsIconic(owner)) {
    ::GetWindowRect(owner, &area);
  }
  int x = area.left + ((area.right - area.left) - w) / 2;
  int y = area.top + ((area.bottom - area.top) - h) / 2;
  x = std::max(static_cast<int>(mi.rcWork.left),
               std::min(x, static_cast<int>(mi.rcWork.right) - w));
  y = std::max(static_cast<int>(mi.rcWork.top),
               std::min(y, static_cast<int>(mi.rcWork.bottom) - h));
  ::SetWindowPos(handle, nullptr, x, y, 0, 0,
                 SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
}

ChildWindowHost::ChildWindowHost(flutter::BinaryMessenger* messenger,
                                 HWND main_window)
    : main_window_(main_window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "secretly/child_window",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleMethodCall(call, std::move(result)); });
}

// Окна — до движка: их виды принадлежат ему (см. FlutterWindow::OnDestroy).
ChildWindowHost::~ChildWindowHost() {
  channel_->SetMethodCallHandler(nullptr);
  windows_.clear();
}

void ChildWindowHost::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();
  if (method == "isSupported") {
    result->Success(flutter::EncodableValue(true));
    return;
  }
  if (method == "playNotificationSound") {
    // Звук уведомления Windows — тот же, что у системных уведомлений.
    ::PlaySoundW(L"Notification.Default", nullptr,
                 SND_ALIAS | SND_ASYNC | SND_NODEFAULT);
    result->Success();
    return;
  }
  if (method == "acceptsNotifications") {
    // Можно ли показывать своё окошко уведомления. Презентация, полноэкранная
    // игра или видео, заблокированный экран — Windows просит не беспокоить:
    // окошко поверх всех было бы тем самым беспокойством, а системное
    // уведомление Windows придержит сама. Система не ответила — можно.
    QUERY_USER_NOTIFICATION_STATE state = QUNS_ACCEPTS_NOTIFICATIONS;
    const bool accepts = FAILED(::SHQueryUserNotificationState(&state)) ||
                         state == QUNS_ACCEPTS_NOTIFICATIONS;
    result->Success(flutter::EncodableValue(accepts));
    return;
  }
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  if (!args) {
    result->Error("bad_args", "arguments must be a map");
    return;
  }
  const std::string id = StringArg(*args, "id");
  if (id.empty()) {
    result->Error("bad_args", "id is required");
    return;
  }

  if (method == "open") {
    auto existing = windows_.find(id);
    if (existing != windows_.end()) {
      existing->second->Present();
      result->Success(flutter::EncodableValue(existing->second->view_id()));
      return;
    }
    const int64_t engine_id = IntArg(*args, "engineId");
    FlutterDesktopEngineRef engine =
        engine_id == 0 ? nullptr : FlutterDesktopEngineForId(engine_id);
    if (!engine) {
      result->Error("no_engine", "unknown engine id");
      return;
    }
    const bool notification = BoolArg(*args, "notification");
    auto window = std::make_unique<SecretlyChildWindow>(
        engine, id, static_cast<int>(DoubleArg(*args, "minWidth", 320)),
        static_cast<int>(DoubleArg(*args, "minHeight", 240)), notification,
        [this](const std::string& closing) {
          channel_->InvokeMethod(
              "closeRequested",
              std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
                  {flutter::EncodableValue("id"),
                   flutter::EncodableValue(closing)}}));
        });
    window->SetQuitOnClose(false);
    const auto width =
        static_cast<unsigned int>(DoubleArg(*args, "width", 420));
    const auto height =
        static_cast<unsigned int>(DoubleArg(*args, "height", 640));
    if (!window->Create(Utf16FromUtf8(StringArg(*args, "title")),
                        Win32Window::Point(10, 10),
                        Win32Window::Size(width, height)) ||
        window->view_id() < 0) {
      result->Error("create_failed", "could not create the window view");
      return;
    }
    // Защита от снимков экрана включена — окно рождается защищённым
    // (screen_privacy.h), иначе звонок или окошко уведомления попали бы в
    // запись экрана, пока главное окно из неё убрано.
    if (ScreenPrivacyEnabled()) ApplyScreenPrivacy(window->GetHandle());
    if (notification) {
      window->MakeNotificationPopup();
      window->PlaceAtCorner(static_cast<int>(IntArg(*args, "slot")), 16, 10);
    } else {
      window->CenterOver(main_window_);
      if (BoolArg(*args, "topmost")) window->SetTopmost(true);
    }
    const int64_t view_id = window->view_id();
    windows_[id] = std::move(window);
    // Окно ещё скрыто: показывает его `show` из Dart после первого кадра —
    // иначе мигнул бы чёрный прямоугольник.
    result->Success(flutter::EncodableValue(view_id));
    return;
  }

  auto it = windows_.find(id);
  if (method == "close") {
    if (it != windows_.end()) windows_.erase(it);
    result->Success();
    return;
  }
  if (it == windows_.end()) {
    result->Error("no_window", "no window with this id");
    return;
  }
  SecretlyChildWindow& window = *it->second;
  if (method == "show" || method == "focus") {
    window.Present();
  } else if (method == "setTopmost") {
    window.SetTopmost(BoolArg(*args, "on"));
  } else if (method == "placeAtCorner") {
    window.PlaceAtCorner(static_cast<int>(IntArg(*args, "slot")), 16, 10);
  } else if (method == "setFullScreen") {
    window.SetFullScreen(BoolArg(*args, "on"));
  } else if (method == "minimize") {
    window.Minimize();
  } else if (method == "allowFocus") {
    window.AllowFocus();
  } else if (method == "setTitle") {
    window.SetTitle(Utf16FromUtf8(StringArg(*args, "title")));
  } else if (method == "setSize") {
    window.SetLogicalSize(DoubleArg(*args, "width", 420),
                          DoubleArg(*args, "height", 640),
                          DoubleArg(*args, "minWidth", 0),
                          DoubleArg(*args, "minHeight", 0));
  } else {
    result->NotImplemented();
    return;
  }
  result->Success();
}
