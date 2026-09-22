// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import Cocoa
import FlutterMacOS
import Sparkle

/// Обновление приложения, скачанного С САЙТА.
///
/// 🔴 ЭТО НЕ УДОБСТВО, А ЧАСТЬ ЗАЩИТЫ. У версии из магазина обновления —
/// забота магазина. У скачанной с сайта их нет вовсе: пока человек сам не
/// зайдёт на сайт, он останется на той версии, что скачал, — включая ту, в
/// которой нашли дыру. Для мессенджера это худший из возможных долгов, и
/// закрыть его нечем, кроме проверки обновлений внутри самого приложения.
///
/// 🔴 ПОЧЕМУ SPARKLE, А НЕ СВОЯ ПРОВЕРКА. Своя свелась бы к «сходить за
/// номером версии и открыть страницу загрузки» — то есть к объявлению, а не к
/// обновлению. Главное в обновлении не «узнать», а поставить НОВОЕ И ИМЕННО
/// НАШЕ: подменённое обновление — это подменённый мессенджер. Sparkle
/// проверяет подпись EdDSA пакета ДО установки; писать такую проверку заново
/// значило бы писать заново то, что двадцать лет проверяют всем маком.
///
/// 🔴 ПЕСОЧНИЦА. Приложение живёт в песочнице (`app-sandbox`), и это не
/// обсуждается: в её контейнере лежит зашифрованная база. Sparkle в песочнице
/// работает через свою службу `Installer.xpc` внутри рамки и требует ровно
/// двух вещей: `SUEnableInstallerLauncherService` в Info.plist и временного
/// исключения `mach-lookup` на два имени в правах. `Downloader.xpc` НЕ нужен —
/// он только для приложений без `network.client`, а он у нас есть.
///
/// 🔴 БЕЗ КЛЮЧА И АДРЕСА ОБНОВЛЯТОР НЕ ЗАПУСКАЕТСЯ ВОВСЕ.
///
/// `SUFeedURL` — где лежит перечень версий, `SUPublicEDKey` — открытый ключ,
/// которым проверяется подпись пакета. Пока их нет в Info.plist, здесь не
/// создаётся ничего, а Flutter получает `configured: false` и не показывает
/// пункт «Проверить обновления». Это не заглушка «на потом»: обновлятор,
/// который не может проверить подпись, опаснее отсутствующего — он скачает
/// что угодно и назовёт это новой версией. Закрытый ключ при этом не живёт в
/// дереве исходников вообще: его создают один раз командой `generate_keys`,
/// и он остаётся в ключнице того, кто выпускает.
final class SparkleBridge: NSObject {
  private var channel: FlutterMethodChannel?
  private var controller: SPUStandardUpdaterController?

  /// Причина, по которой обновлятор не поднялся, — словом, а не молчанием.
  private var failure: String?

  private var feedUrl: String? {
    let v = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
    let trimmed = (v ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private var publicKey: String? {
    let v = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
    let trimmed = (v ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "secretly/updates",
      binaryMessenger: messenger
    )
    self.channel = channel
    startIfConfigured()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "gone", message: "bridge released", details: nil))
        return
      }
      switch call.method {
      case "status":
        result(self.status())
      case "check":
        guard let controller = self.controller else {
          result(FlutterError(
            code: "not_configured",
            message: self.failure ?? "updater is not configured",
            details: nil
          ))
          return
        }
        // Проверка ПО ПРОСЬБЕ ЧЕЛОВЕКА: Sparkle сам покажет своё окно — и
        // «новых версий нет», и предложение поставить найденную. Рисовать это
        // своими руками значило бы заводить второй разговор об одном и том же.
        controller.checkForUpdates(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func status() -> [String: Any] {
    var out: [String: Any] = [
      "configured": controller != nil,
      "hasFeed": feedUrl != nil,
      "hasKey": publicKey != nil,
    ]
    if let failure { out["error"] = failure }
    if let updater = controller?.updater {
      out["automaticChecks"] = updater.automaticallyChecksForUpdates
      if let last = updater.lastUpdateCheckDate {
        out["lastCheckMs"] = Int(last.timeIntervalSince1970 * 1000)
      }
    }
    return out
  }

  private func startIfConfigured() {
    guard feedUrl != nil else {
      failure = "SUFeedURL is not set in Info.plist"
      return
    }
    guard publicKey != nil else {
      // Самая опасная из возможных «недонастроек»: адрес есть, ключа нет.
      // Без ключа проверять подпись пакета нечем, и обновлятор превратился бы
      // в установщик чего угодно с этого адреса.
      failure = "SUPublicEDKey is not set in Info.plist"
      return
    }
    // `startingUpdater: false` + явный `start()`: при запуске «в конструкторе»
    // Sparkle на неверной настройке завершает ПРОГРАММУ. Падать целиком из-за
    // необновлённого обновлятора нельзя — приложение должно остаться рабочим,
    // просто без проверки версий.
    let candidate = SPUStandardUpdaterController(
      startingUpdater: false,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
    do {
      try candidate.updater.start()
      controller = candidate
      failure = nil
    } catch {
      controller = nil
      failure = "\(error)"
      NSLog("[Secretly] updater did not start: \(error)")
    }
  }
}
