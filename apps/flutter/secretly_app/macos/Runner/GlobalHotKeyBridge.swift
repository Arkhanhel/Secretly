// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import Carbon.HIToolbox
import Cocoa
import FlutterMacOS

/// Общесистемное сочетание клавиш «показать Secretly».
///
/// 🔴 ПОЧЕМУ `RegisterEventHotKey`, А НЕ СЛЕЖЕНИЕ ЗА СОБЫТИЯМИ.
///
/// Второй очевидный путь — `NSEvent.addGlobalMonitorForEvents`: он видит ВСЕ
/// нажатия во всех программах и поэтому требует разрешения «Универсальный
/// доступ». Мессенджер, который просит право читать любой набранный текст,
/// противоречит сам себе: человеку нечем отличить нас от того, от чего мы
/// защищаем. `RegisterEventHotKey` регистрирует ОДНО сочетание у самой системы,
/// никаких прав не просит и ничего чужого не видит — система лишь будит нас,
/// когда нажато ровно оно.
///
/// 🔴 ПО УМОЛЧАНИЮ ВЫКЛЮЧЕНО. Сочетание общесистемное: включив его молча, мы
/// отняли бы комбинацию у программы, которой человек пользуется, и он не понял
/// бы, кто её забрал. Включение — осознанный выбор в настройках.
final class GlobalHotKeyBridge: NSObject {
  private var channel: FlutterMethodChannel?
  private var hotKeyRef: EventHotKeyRef?
  private var handlerRef: EventHandlerRef?

  /// `secretly` четырьмя байтами — этого просит Carbon.
  private let signature: OSType = 0x7363_726C  // 'scrl'

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "secretly/global_hotkey",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "gone", message: "bridge released", details: nil))
        return
      }
      switch call.method {
      case "setEnabled":
        let on = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
        result(on ? self.register() : self.unregister())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// ⌥⌘S. Сочетание выбрано так, чтобы не спорить с системными: ⌘S занято
  /// сохранением почти везде, но ⌥⌘S — свободно, а буква отвечает названию.
  private func register() -> Bool {
    if hotKeyRef != nil { return true }
    installHandlerIfNeeded()
    var ref: EventHotKeyRef?
    let id = EventHotKeyID(signature: signature, id: 1)
    let status = RegisterEventHotKey(
      UInt32(kVK_ANSI_S),
      UInt32(optionKey | cmdKey),
      id,
      GetEventDispatcherTarget(),
      0,
      &ref
    )
    // Сочетание мог занять кто-то другой — это НЕ ошибка приложения, и падать
    // здесь нечему: Flutter получит `false` и покажет, что включить не вышло.
    guard status == noErr, let ref else { return false }
    hotKeyRef = ref
    return true
  }

  private func unregister() -> Bool {
    if let ref = hotKeyRef {
      UnregisterEventHotKey(ref)
      hotKeyRef = nil
    }
    return true
  }

  private func installHandlerIfNeeded() {
    guard handlerRef == nil else { return }
    var spec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    InstallEventHandler(
      GetEventDispatcherTarget(),
      { (_, event, userData) -> OSStatus in
        guard let userData else { return noErr }
        let me = Unmanaged<GlobalHotKeyBridge>.fromOpaque(userData)
          .takeUnretainedValue()
        var id = EventHotKeyID()
        GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &id
        )
        guard id.signature == me.signature else { return noErr }
        // Поднимаем окно САМИ, не спрашивая Flutter: нажатие должно показывать
        // окно и тогда, когда Flutter занят, — иначе сочетание «иногда не
        // работает», что хуже, чем его отсутствие.
        DispatchQueue.main.async {
          NSApp.activate(ignoringOtherApps: true)
          for w in NSApp.windows where !(w is NSPanel) {
            w.makeKeyAndOrderFront(nil)
          }
          me.channel?.invokeMethod("pressed", arguments: nil)
        }
        return noErr
      },
      1,
      &spec,
      Unmanaged.passUnretained(self).toOpaque(),
      &handlerRef
    )
  }
}
