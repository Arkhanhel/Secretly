#ifndef RUNNER_TASKBAR_BADGE_H_
#define RUNNER_TASKBAR_BADGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <shobjidl.h>
#include <windows.h>

#include <memory>
#include <string>

// 🔴 НЕПРОЧИТАННЫЕ НА ПАНЕЛИ ЗАДАЧ И МИГАНИЕ (29.09.2026) — как у Telegram.
//
// Значок рисует Dart (`desktop_taskbar.dart`: красный кружок с числом тем же
// шрифтом, что приложение) и присылает пиксели; здесь из них делается HICON и
// ставится поверх кнопки окна (ITaskbarList3::SetOverlayIcon). Проводник
// пересоздаёт кнопку (перезапуск explorer.exe, смена DPI) — значок ставится
// заново по сообщению TaskbarButtonCreated.
class TaskbarBadge {
 public:
  TaskbarBadge(flutter::BinaryMessenger* messenger, HWND window);
  ~TaskbarBadge();

  static UINT TaskbarButtonCreatedMessage();
  void OnTaskbarButtonCreated();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  bool EnsureTaskbar();
  void Apply();
  void ClearIcon();

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_;
  ITaskbarList3* taskbar_ = nullptr;
  HICON icon_ = nullptr;
  std::wstring description_;
};

#endif  // RUNNER_TASKBAR_BADGE_H_
