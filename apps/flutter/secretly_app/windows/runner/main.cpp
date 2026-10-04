#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "single_instance.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // 🔴 ОДНО ИМЯ ДЛЯ WINDOWS (26.09.2026, владелец: «чтобы приложение было в
  // диспетчере задач как и телеграм»). По этому имени Windows связывает между
  // собой кнопку на панели задач, закреплённый ярлык, список переходов и
  // уведомления. Ставим ДО создания окна: панель задач читает имя в тот
  // момент, когда окно появляется, и позже его уже не перечитывает.
  // Ровно это же имя стоит у ярлыка «Пуска» (windows/installer/secretly.iss)
  // и у уведомлений (`localNotifier.setup(appName: 'Secretly')`), иначе
  // Windows считала бы их тремя разными приложениями.
  if (HMODULE shell32 = ::LoadLibraryW(L"shell32.dll")) {
    using SetAppIdPtr = HRESULT(WINAPI*)(PCWSTR);
    if (auto set_app_id = reinterpret_cast<SetAppIdPtr>(::GetProcAddress(
            shell32, "SetCurrentProcessExplicitAppUserModelID"))) {
      set_app_id(L"Secretly");
    }
  }

  // Secretly уже запущен (например, спрятан в трей) — просим его показаться
  // и уходим, не поднимая второй движок. См. single_instance.h.
  if (HandOffToRunningInstance()) {
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Secretly", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  // Уходим сразу и наверняка. Обычный возврат ещё раскручивает глобальные
  // объекты плагинов, и одна застрявшая нить оставляла бы процесс в списке
  // задач без окна — то самое «закрыл, а оно висит».
  ::ExitProcess(EXIT_SUCCESS);
}
