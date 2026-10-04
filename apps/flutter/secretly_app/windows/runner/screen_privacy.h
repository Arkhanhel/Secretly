#ifndef RUNNER_SCREEN_PRIVACY_H_
#define RUNNER_SCREEN_PRIVACY_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

// «Защита от снимков экрана» на Windows (01.10.2026) — тот же канал
// `secretly/screen_privacy`, что у телефона: контроллер зовёт его при запуске
// и при переключении настройки.
//
// `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` (Windows 10 2004+)
// убирает окно из снимков, записи и демонстрации экрана — в том числе нашей
// же демонстрации в звонке. Где этого флага нет, остаётся `WDA_MONITOR`:
// вместо окна в захвате чёрный прямоугольник.
// 🔴 ЭТО ПРОСЬБА К СИСТЕМЕ, А НЕ ЗАМОК: фотографию экрана она не остановит,
// и текст настройки говорит это прямо.

// Включена ли защита сейчас — чтобы новые отдельные окна рождались
// защищёнными (child_window.cpp).
bool ScreenPrivacyEnabled();

// Применить текущее состояние к окну. `true` — система приняла.
bool ApplyScreenPrivacy(HWND window);

class ScreenPrivacyChannel {
 public:
  ScreenPrivacyChannel(flutter::BinaryMessenger* messenger, HWND main_window);
  ~ScreenPrivacyChannel();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND main_window_;
};

#endif  // RUNNER_SCREEN_PRIVACY_H_
