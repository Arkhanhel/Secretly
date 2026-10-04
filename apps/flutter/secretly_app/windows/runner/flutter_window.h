#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <optional>

#include "child_window.h"
#include "screen_privacy.h"
#include "taskbar_badge.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Рамка окна и выход по завершению сеанса Windows — до плагинов.
  // `std::nullopt` — сообщение нас не касается, пусть идёт дальше.
  std::optional<LRESULT> HandleFrameMessage(HWND window, UINT const message,
                                            WPARAM const wparam,
                                            LPARAM const lparam) noexcept;

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Отдельные окна (звонок) на том же движке — см. child_window.h.
  std::unique_ptr<ChildWindowHost> child_windows_;

  // Непрочитанные поверх кнопки на панели задач и мигание — taskbar_badge.h.
  std::unique_ptr<TaskbarBadge> taskbar_badge_;

  // Счётчик изменений буфера обмена для сторожа секретов
  // (desktop_clipboard_guard.dart) — только счётчик, не содержимое.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      clipboard_guard_;

  // «Защита от снимков экрана» — screen_privacy.h.
  std::unique_ptr<ScreenPrivacyChannel> screen_privacy_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
