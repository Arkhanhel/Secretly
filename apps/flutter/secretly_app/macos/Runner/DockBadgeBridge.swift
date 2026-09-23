// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import Cocoa
import FlutterMacOS

/// Число непрочитанных на значке приложения в Dock.
///
/// 🔴 ЭТО НЕ УКРАШЕНИЕ, А ЕДИНСТВЕННЫЙ ВИДИМЫЙ ПРИЗНАК, КОГДА ОКНА НЕТ.
///
/// Окно живёт в трее и большую часть времени спрятано. Число непрочитанных уже
/// считалось — но уходило только в подсказку значка в трее, а её видно лишь
/// если навести мышь и подождать. Заголовок окна тоже не помогает: у спрятанного
/// окна заголовка нет. Получалось, что о новых сообщениях человек узнавал только
/// из баннера уведомления — то есть один раз, в момент прихода, и если баннер
/// пропущен, других следов не оставалось.
///
/// 🔴 ПОЧЕМУ НЕ `badgeNumber` У УВЕДОМЛЕНИЯ. `flutter_local_notifications` умеет
/// ставить значок вместе с баннером, но снять его потом нечем: значок менялся бы
/// только при ПРИХОДЕ сообщения и оставался бы висеть после прочтения. Значок,
/// который врёт в меньшую сторону, безвреден; значок, который врёт в большую,
/// гоняет человека искать несуществующее.
///
/// `badgeLabel` — строка, а не число: `nil` убирает значок, «99+» показывается
/// как есть. Порог держим здесь, а не во Flutter: это свойство площадки, а не
/// приложения.
final class DockBadgeBridge: NSObject {
  private var channel: FlutterMethodChannel?

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "secretly/dock_badge",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "set":
        let count = (call.arguments as? [String: Any])?["count"] as? Int ?? 0
        DockBadgeBridge.apply(count: count)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Значок ставится ТОЛЬКО из главного потока: `dockTile` — часть интерфейса,
  /// и обращение к нему из фонового потока роняет приложение.
  private static func apply(count: Int) {
    let label: String?
    if count <= 0 {
      label = nil
    } else if count > 99 {
      label = "99+"
    } else {
      label = String(count)
    }
    if Thread.isMainThread {
      NSApp.dockTile.badgeLabel = label
    } else {
      DispatchQueue.main.async { NSApp.dockTile.badgeLabel = label }
    }
  }
}
