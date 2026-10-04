#include "taskbar_badge.h"

#include <flutter/standard_method_codec.h>

#include <variant>
#include <vector>

namespace {

const flutter::EncodableValue* Find(const flutter::EncodableMap& args,
                                    const char* key) {
  auto it = args.find(flutter::EncodableValue(std::string(key)));
  return it == args.end() ? nullptr : &it->second;
}

std::wstring Utf16FromUtf8(const std::string& text) {
  if (text.empty()) return std::wstring();
  const int length = ::MultiByteToWideChar(CP_UTF8, 0, text.data(),
                                           static_cast<int>(text.size()),
                                           nullptr, 0);
  if (length <= 0) return std::wstring();
  std::wstring out(length, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, text.data(),
                        static_cast<int>(text.size()), out.data(), length);
  return out;
}

// RGBA без домножения на прозрачность (Dart: rawStraightRgba) → значок с
// альфа-каналом.
HICON IconFromRgba(const std::vector<uint8_t>& rgba, int width, int height) {
  if (width <= 0 || height <= 0 ||
      rgba.size() < static_cast<size_t>(width) * height * 4) {
    return nullptr;
  }
  BITMAPV5HEADER header = {};
  header.bV5Size = sizeof(header);
  header.bV5Width = width;
  header.bV5Height = -height;  // сверху вниз
  header.bV5Planes = 1;
  header.bV5BitCount = 32;
  header.bV5Compression = BI_BITFIELDS;
  header.bV5RedMask = 0x00FF0000;
  header.bV5GreenMask = 0x0000FF00;
  header.bV5BlueMask = 0x000000FF;
  header.bV5AlphaMask = 0xFF000000;
  void* bits = nullptr;
  HDC dc = ::GetDC(nullptr);
  HBITMAP color = ::CreateDIBSection(
      dc, reinterpret_cast<BITMAPINFO*>(&header), DIB_RGB_COLORS, &bits,
      nullptr, 0);
  ::ReleaseDC(nullptr, dc);
  if (!color || !bits) return nullptr;
  auto* out = static_cast<uint8_t*>(bits);
  for (int i = 0; i < width * height; ++i) {
    out[i * 4 + 0] = rgba[i * 4 + 2];
    out[i * 4 + 1] = rgba[i * 4 + 1];
    out[i * 4 + 2] = rgba[i * 4 + 0];
    out[i * 4 + 3] = rgba[i * 4 + 3];
  }
  HBITMAP mask = ::CreateBitmap(width, height, 1, 1, nullptr);
  ICONINFO info = {};
  info.fIcon = TRUE;
  info.hbmColor = color;
  info.hbmMask = mask;
  HICON icon = ::CreateIconIndirect(&info);
  ::DeleteObject(color);
  ::DeleteObject(mask);
  return icon;
}

}  // namespace

UINT TaskbarBadge::TaskbarButtonCreatedMessage() {
  static const UINT message = ::RegisterWindowMessageW(L"TaskbarButtonCreated");
  return message;
}

TaskbarBadge::TaskbarBadge(flutter::BinaryMessenger* messenger, HWND window)
    : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "secretly/taskbar",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleMethodCall(call, std::move(result)); });
}

TaskbarBadge::~TaskbarBadge() {
  channel_->SetMethodCallHandler(nullptr);
  ClearIcon();
  if (taskbar_) {
    taskbar_->Release();
    taskbar_ = nullptr;
  }
}

bool TaskbarBadge::EnsureTaskbar() {
  if (taskbar_) return true;
  ITaskbarList3* list = nullptr;
  if (FAILED(::CoCreateInstance(CLSID_TaskbarList, nullptr,
                                CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&list)))) {
    return false;
  }
  if (FAILED(list->HrInit())) {
    list->Release();
    return false;
  }
  taskbar_ = list;
  return true;
}

void TaskbarBadge::Apply() {
  if (!EnsureTaskbar()) return;
  taskbar_->SetOverlayIcon(window_, icon_, description_.c_str());
}

void TaskbarBadge::ClearIcon() {
  if (icon_) {
    ::DestroyIcon(icon_);
    icon_ = nullptr;
  }
}

void TaskbarBadge::OnTaskbarButtonCreated() {
  // Прежний объект привязан к старой кнопке — берём новый.
  if (taskbar_) {
    taskbar_->Release();
    taskbar_ = nullptr;
  }
  if (icon_) Apply();
}

void TaskbarBadge::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();
  if (method == "clearBadge") {
    ClearIcon();
    description_.clear();
    Apply();
    result->Success();
    return;
  }
  if (method == "flash") {
    // Мигает, пока окно не выйдут вперёд (FLASHW_TIMERNOFG), — как у
    // Telegram. Окно спрятано в трей — кнопки нет, мигать нечему.
    FLASHWINFO info = {};
    info.cbSize = sizeof(info);
    info.hwnd = window_;
    info.dwFlags = FLASHW_TRAY | FLASHW_TIMERNOFG;
    ::FlashWindowEx(&info);
    result->Success();
    return;
  }
  if (method == "setBadge") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Error("bad_args", "arguments must be a map");
      return;
    }
    const auto* rgba = Find(*args, "rgba");
    const auto* width = Find(*args, "width");
    const auto* height = Find(*args, "height");
    const auto* description = Find(*args, "description");
    const auto* bytes =
        rgba ? std::get_if<std::vector<uint8_t>>(rgba) : nullptr;
    const auto* w = width ? std::get_if<int32_t>(width) : nullptr;
    const auto* h = height ? std::get_if<int32_t>(height) : nullptr;
    if (!bytes || !w || !h) {
      result->Error("bad_args", "rgba, width and height are required");
      return;
    }
    HICON icon = IconFromRgba(*bytes, *w, *h);
    if (!icon) {
      result->Error("icon_failed", "could not build the badge icon");
      return;
    }
    ClearIcon();
    icon_ = icon;
    const auto* text =
        description ? std::get_if<std::string>(description) : nullptr;
    description_ = text ? Utf16FromUtf8(*text) : std::wstring();
    Apply();
    result->Success();
    return;
  }
  result->NotImplemented();
}
