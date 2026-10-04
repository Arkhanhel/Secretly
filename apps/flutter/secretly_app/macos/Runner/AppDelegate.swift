import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // 🔴 ЗАКРЫТОЕ ОКНО — НЕ ВЫХОД (30.09.2026). Крестик и ⌘W прячут окно
  // (`windowManager.hide()` = `orderOut`), а AppKit считает спрятанное
  // последнее окно закрытым и при `true` здесь завершал процесс через ~30 мс:
  // Secretly «в строке меню» на деле не работал — ни сообщений, ни
  // уведомлений, ни входящих звонков, пока его не запустят заново. Выход
  // всегда явный: «Выйти» в строке меню, ⌘Q и крестик при выключенном
  // «Закрывать в трей» идут через `quitDesktopApp` → `NSApp.terminate`.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  // Щелчок по значку в Dock при спрятанном окне возвращает окно, как у
  // Telegram. Dart узнаёт об этом сам: окно становится ключевым, и
  // window_manager присылает `focus` — тот же путь, что у «Показать окно».
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag, let window = mainFlutterWindow, !window.isMiniaturized {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return false
    }
    // Свёрнутое в Dock окно разворачивает сам AppKit.
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
