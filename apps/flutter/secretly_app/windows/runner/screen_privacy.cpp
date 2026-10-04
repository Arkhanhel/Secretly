#include "screen_privacy.h"

#include <flutter/standard_method_codec.h>

#include <string>
#include <variant>

// Старые SDK не знают флага Windows 10 2004 — значение из winuser.h.
#ifndef WDA_EXCLUDEFROMCAPTURE
#define WDA_EXCLUDEFROMCAPTURE 0x00000011
#endif

namespace {

bool g_screen_privacy_enabled = false;

BOOL CALLBACK ApplyToThreadWindow(HWND window, LPARAM) {
  ApplyScreenPrivacy(window);
  return TRUE;
}

}  // namespace

bool ScreenPrivacyEnabled() { return g_screen_privacy_enabled; }

bool ApplyScreenPrivacy(HWND window) {
  if (window == nullptr) return false;
  if (!g_screen_privacy_enabled) {
    return ::SetWindowDisplayAffinity(window, WDA_NONE) != FALSE;
  }
  if (::SetWindowDisplayAffinity(window, WDA_EXCLUDEFROMCAPTURE) != FALSE) {
    return true;
  }
  // До Windows 10 2004 флага нет — хотя бы чёрный прямоугольник в захвате.
  return ::SetWindowDisplayAffinity(window, WDA_MONITOR) != FALSE;
}

ScreenPrivacyChannel::ScreenPrivacyChannel(flutter::BinaryMessenger* messenger,
                                           HWND main_window)
    : main_window_(main_window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "secretly/screen_privacy",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleMethodCall(call, std::move(result)); });
}

ScreenPrivacyChannel::~ScreenPrivacyChannel() {
  channel_->SetMethodCallHandler(nullptr);
}

void ScreenPrivacyChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() != "setEnabled") {
    result->NotImplemented();
    return;
  }
  bool on = false;
  if (const auto* args =
          std::get_if<flutter::EncodableMap>(call.arguments())) {
    auto it = args->find(flutter::EncodableValue(std::string("enabled")));
    if (it != args->end()) {
      if (const auto* b = std::get_if<bool>(&it->second)) on = *b;
    }
  }
  g_screen_privacy_enabled = on;
  // Ответ решает главное окно: не приняла система на нём — защиты нет, и
  // настройка не должна выглядеть включённой (контроллер её не сохранит).
  const bool ok = ApplyScreenPrivacy(main_window_);
  if (on && !ok) {
    g_screen_privacy_enabled = false;
    ApplyScreenPrivacy(main_window_);
  }
  // Отдельные окна (звонок, окошки уведомлений) — все окна верхнего уровня
  // этого потока; новые получают то же при создании (child_window.cpp).
  ::EnumThreadWindows(::GetCurrentThreadId(), ApplyToThreadWindow, 0);
  result->Success(flutter::EncodableValue(ok));
}
