// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import Cocoa
import FlutterMacOS
import ServiceManagement

/// Запуск при входе в систему.
///
/// 🔴 ЭТО НЕ УДОБСТВО, А УСЛОВИЕ ДОСТАВКИ. Окно живёт в трее и большую часть
/// времени спрятано; сообщения приходят, пока приложение ЗАПУЩЕНО. Не
/// запущенное приложение не получает ничего — и человек узнаёт о разговоре
/// тогда, когда сам вспомнит открыть Secretly. На телефоне такой проблемы нет:
/// там за доставку отвечает система. На компьютере отвечаем мы.
///
/// 🔴 `SMAppService`, А НЕ ЗАПИСЬ В СПИСОК ВХОДА РУКАМИ. Прежний путь
/// (`LSSharedFileList`, папка `~/Library/LaunchAgents`) в песочнице недоступен
/// и объявлен устаревшим. `SMAppService.mainApp` регистрирует САМО приложение,
/// работает из песочницы и показывается человеку в «Системных настройках →
/// Основные → Объекты входа», где он может отменить это без нас. Право
/// отменить — часть честности: автозапуск, который нельзя выключить снаружи,
/// ведёт себя как то, от чего мы отличаемся.
///
/// Требуется macOS 13. На более старых честно отвечаем `unavailable`, и
/// переключатель не показывается вовсе — вместо переключателя, который
/// притворяется работающим.
final class LoginItemBridge: NSObject {
  private var channel: FlutterMethodChannel?

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "secretly/login_item",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard self != nil else {
        result(FlutterError(code: "gone", message: "bridge released", details: nil))
        return
      }
      guard #available(macOS 13.0, *) else {
        // Не ошибка, а отсутствие возможности: Flutter по этому ответу прячет
        // переключатель, а не показывает сломанный.
        result(["available": false, "enabled": false])
        return
      }
      switch call.method {
      case "status":
        let s = SMAppService.mainApp.status
        result([
          "available": true,
          "enabled": s == .enabled,
          // `requiresApproval` — человек выключил это в системных настройках.
          // Показывать в таком случае «включено» значило бы врать.
          "needsApproval": s == .requiresApproval,
        ])
      case "setEnabled":
        let on = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
        do {
          if on {
            try SMAppService.mainApp.register()
          } else {
            try SMAppService.mainApp.unregister()
          }
          result(["available": true, "enabled": SMAppService.mainApp.status == .enabled])
        } catch {
          // Отказ системы передаём словами: молчаливый возврат прежнего
          // состояния выглядел бы как «переключатель не нажимается».
          result(FlutterError(
            code: "login_item_failed",
            message: "\(error)",
            details: nil
          ))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
