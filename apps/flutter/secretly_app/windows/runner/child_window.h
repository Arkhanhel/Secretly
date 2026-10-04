#ifndef RUNNER_CHILD_WINDOW_H_
#define RUNNER_CHILD_WINDOW_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter_windows.h>
#include <windows.h>

#include <functional>
#include <map>
#include <memory>
#include <string>

#include "win32_window.h"

// 🔴 ОТДЕЛЬНОЕ ОКНО ОС НА ТОМ ЖЕ ДВИЖКЕ (29.09.2026, Р1).
//
// Владелец: «при нажатии на "позвонить" должно открываться отдельное окно
// Windows, а не внутри приложения… чтобы я мог закрепить его поверх
// приложений». Второй движок не подходит: видео звонка — текстуры первого.
// Поэтому второй вид того же движка: `FlutterDesktopEngineCreateViewController`
// из `flutter_windows.dll` (объявлен во внутреннем заголовке движка, в
// публичных его нет — прототип ниже). Рисует в окно тот же изолят Dart
// (`desktop_child_windows.dart`).
class SecretlyChildWindow : public Win32Window {
 public:
  // [notification] — окошко уведомления (как у Telegram): без рамки и кнопки
  // на панели задач, поверх всех и без фокуса — с самого создания.
  SecretlyChildWindow(FlutterDesktopEngineRef engine,
                      std::string id,
                      int min_width,
                      int min_height,
                      bool notification,
                      std::function<void(const std::string&)> on_close);
  ~SecretlyChildWindow() override;

  // Номер вида у движка; -1 — вид не создан.
  int64_t view_id() const { return view_id_; }

  void SetTopmost(bool on);
  // Окошку уведомления — скруглённые углы и место поверх всех. Зовётся сразу
  // после Create; стили окошку даёт конструктор.
  void MakeNotificationPopup();
  // Место в правом нижнем углу рабочей области: [slot] 0 — нижний.
  void PlaceAtCorner(int slot, int margin_dip, int gap_dip);
  void SetFullScreen(bool on);
  void Minimize();
  void Present();
  // Окошко уведомления начинает принимать клавиатуру: человек нажал
  // «Ответить» и будет печатать ответ прямо в окошке.
  void AllowFocus();
  void SetTitle(const std::wstring& title);
  // Размер рабочей области (от середины окна, в пределах монитора) и, если
  // больше нуля, новый наименьший размер.
  void SetLogicalSize(double width, double height, double min_width,
                      double min_height);
  // Поставить окно посередине над [owner] — главным окном приложения.
  void CenterOver(HWND owner);

 protected:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void ApplyDarkFrame();

  FlutterDesktopEngineRef engine_;
  FlutterDesktopViewControllerRef controller_ = nullptr;
  std::string id_;
  int min_width_;
  int min_height_;
  int64_t view_id_ = -1;
  std::function<void(const std::string&)> on_close_;
  // Окошко уведомления: показывается без активации, щелчок не крадёт фокус.
  bool no_activate_ = false;
  // Во весь экран: стиль и место окна до него — чтобы вернуть как было.
  bool full_screen_ = false;
  LONG saved_style_ = 0;
  RECT saved_rect_ = {};
};

// Канал `secretly/child_window`: открыть, закрыть, поверх всех, показать.
class ChildWindowHost {
 public:
  ChildWindowHost(flutter::BinaryMessenger* messenger, HWND main_window);
  ~ChildWindowHost();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::map<std::string, std::unique_ptr<SecretlyChildWindow>> windows_;
  HWND main_window_;
};

#endif  // RUNNER_CHILD_WINDOW_H_
