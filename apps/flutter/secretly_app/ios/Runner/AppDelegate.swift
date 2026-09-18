import AVFAudio
import AVFoundation
import AVKit
import CallKit
import CoreImage
import FirebaseCore
import FirebaseMessaging
import Flutter
import MediaPlayer
import PDFKit
import Network
import os
import PushKit
import QuickLook
import UIKit
import UserNotifications
import Vision
import WebRTC

private let slyDiagLog = OSLog(subsystem: "com.secretly.secretly_app", category: "Sly/Diag")

private let secretlyMessageCategoryId = "secretly_chat_message_actions_v1"
private let secretlyMessageReplyActionId = "secretly_msg_reply_v1"
private let secretlyMessageMarkReadActionId = "secretly_msg_mark_read_v1"

private func secretlyLocalized(_ key: String, _ fallback: String) -> String {
  NSLocalizedString(key, tableName: nil, bundle: .main, value: fallback, comment: "")
}

private func secretlyConversationId(from userInfo: [AnyHashable: Any]) -> String? {
  let keys = ["convo_id", "convoId", "room_id"]
  for key in keys {
    if let value = userInfo[key] as? String {
      let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
      if !normalized.isEmpty {
        return normalized
      }
    }
  }
  return nil
}

private func secretlyMessageNotificationCategories() -> Set<UNNotificationCategory> {
  let replyAction = UNTextInputNotificationAction(
    identifier: secretlyMessageReplyActionId,
    title: secretlyLocalized("notification_reply", "Reply"),
    options: [],
    textInputButtonTitle: secretlyLocalized("notification_send", "Send"),
    textInputPlaceholder: secretlyLocalized("notification_message_placeholder", "Message")
  )
  let markReadAction = UNNotificationAction(
    identifier: secretlyMessageMarkReadActionId,
    title: secretlyLocalized("notification_mark_read", "Mark Read"),
    options: []
  )
  return [
    UNNotificationCategory(
      identifier: secretlyMessageCategoryId,
      actions: [replyAction, markReadAction],
      intentIdentifiers: [],
      options: []
    )
  ]
}

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {
  private let nativeMessageNotificationBridge = NativeMessageNotificationBridge()
  private let nativeNotificationBridge = NativeNotificationBridge()
  private let nativeMessageActionsBridge = NativeMessageActionsBridge()
  private let nativePushDiagnosticsBridge = NativePushDiagnosticsBridge()
  private let nativeCallLogBridge = NativeCallLogBridge()
  private let nativeMediaBridge = NativeMediaBridge()
  private let nativeCallBridge = NativeCallBridge()
  private let nativeNetworkPathBridge = NativeNetworkPathBridge()
  private let nativeClipboardMediaBridge = NativeClipboardMediaBridge()
  private let nativeFileOpenBridge = NativeFileOpenBridge()
  private let nativePictureInPictureBridge = NativePictureInPictureBridge()
  private var firebaseConfigured = false
  private var voipRegistry: PKPushRegistry?

  /// SEC-11: заслонка поверх окна, пока приложение не активно.
  private var screenPrivacyEnabled = false
  private var screenPrivacyCover: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureFirebaseIfAvailable()
    nativePushDiagnosticsBridge.setFirebaseConfigured(firebaseConfigured)
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().setNotificationCategories(
      secretlyMessageNotificationCategories()
    )
    GeneratedPluginRegistrant.register(with: self)
    attachNativeBridges()

    // CallKit ↔ WebRTC audio handoff (2026-07-08). WebRTC (flutter_webrtc) must
    // NOT auto-activate its audio unit — CallKit owns the call audio session.
    // Without manual audio, a call answered from a LOCKED / killed state
    // connects but has NO AUDIO in either direction (WebRTC started its audio
    // unit against a session CallKit had not yet handed over). We now keep the
    // WebRTC audio unit OFF until CallKit's provider(_:didActivate:) fires, then
    // turn it on there. LiveKit room calls are unaffected — they use a separate
    // WebRTC framework with its own RTCAudioSession.
    let rtcAudioSession = RTCAudioSession.sharedInstance()
    rtcAudioSession.useManualAudio = true
    rtcAudioSession.isAudioEnabled = false
    if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      nativeNotificationBridge.bufferLaunchNotification(userInfo: remoteNotification)
    }
    nativePushDiagnosticsBridge.markRemoteRegistrationRequested()
    application.registerForRemoteNotifications()

    // VoIP push — must be registered on the main queue; CallKit requires it.
    let registry = PKPushRegistry(queue: .main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry

    attachAppIconChannel()
    attachStickerAiChannel()
    attachReliabilityChannel()
    attachScreenPrivacyChannel()
    attachNseConfigChannel()
    attachThermalStateChannel()
    attachPdfChannel()
    attachMusicTagsChannel()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Thermal state bridge (2026-07-19, liquid glass governor)
  //
  // Streams ProcessInfo.thermalState to Dart (0 nominal / 1 fair / 2 serious /
  // 3 critical) so GPU-heavy cosmetics (the liquid-glass nav bar) can drop to
  // their classic material while the device is hot and come back when it
  // cools. Initial state is emitted on listen, changes via the system
  // notification.
  private final class ThermalStreamHandler: NSObject, FlutterStreamHandler {
    private var observer: NSObjectProtocol?

    private func rawState() -> Int {
      switch ProcessInfo.processInfo.thermalState {
      case .nominal: return 0
      case .fair: return 1
      case .serious: return 2
      case .critical: return 3
      @unknown default: return 0
      }
    }

    func onListen(
      withArguments arguments: Any?,
      eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
      events(rawState())
      observer = NotificationCenter.default.addObserver(
        forName: ProcessInfo.thermalStateDidChangeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard let self else { return }
        events(self.rawState())
      }
      return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
      if let observer {
        NotificationCenter.default.removeObserver(observer)
      }
      observer = nil
      return nil
    }
  }

  private var thermalStreamHandler: ThermalStreamHandler?

  // MARK: - In-app document reader (2026-07-29)
  //
  // Renders PDF pages with the SYSTEM engine (PDFKit) and hands Flutter PNG
  // bytes, so the reader UI is ours while parsing of an UNTRUSTED file stays in
  // the OS component Apple patches — we do not bundle a PDF engine into an E2EE
  // app. Rendering runs off the main thread; the page is drawn on white first
  // because PDF pages composite onto transparency.
  private let pdfRenderQueue = DispatchQueue(
    label: "com.secretly.pdf-render",
    qos: .userInitiated
  )

  // MARK: - Music tags (17.09.2026)
  //
  // Название и исполнитель песни. Библиотека тегов (Rust) на iPhone отключена,
  // и песни с iPhone уходили с именем файла вместо названия и без исполнителя,
  // а полученную песню нечем было подписать. Читает система (AVFoundation):
  // разбор чужого файла остаётся в системном компоненте, как у PDF. Dart:
  // `lib/media/music_tags.dart`.
  private func attachMusicTagsChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController
    else { return }
    let channel = FlutterMethodChannel(
      name: "secretly/music_tags",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "read" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
        let path = args["path"] as? String, !path.isEmpty
      else {
        result(FlutterError(code: "bad_args", message: "path is required", details: nil))
        return
      }
      Task {
        let tags = await SecretlyMusicTags.read(path: path)
        DispatchQueue.main.async { result(tags) }
      }
    }
  }

  private func attachPdfChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController
    else { return }
    let channel = FlutterMethodChannel(
      name: "secretly/pdf",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      let args = call.arguments as? [String: Any]
      guard let path = args?["path"] as? String, !path.isEmpty else {
        result(FlutterError(code: "bad_args", message: "path is required", details: nil))
        return
      }
      switch call.method {
      case "pageCount":
        self.pdfRenderQueue.async {
          guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else {
            DispatchQueue.main.async {
              result(FlutterError(code: "pdf_open_failed", message: "not a readable pdf", details: nil))
            }
            return
          }
          // An encrypted PDF we cannot unlock has no renderable pages; report a
          // failure so Dart falls back to handing the file to another app.
          if doc.isLocked {
            DispatchQueue.main.async {
              result(FlutterError(code: "pdf_locked", message: "pdf is locked", details: nil))
            }
            return
          }
          let count = doc.pageCount
          DispatchQueue.main.async { result(count) }
        }

      case "renderPage":
        let index = (args?["index"] as? Int) ?? 0
        let targetWidth = min(max((args?["width"] as? Int) ?? 1080, 120), 4096)
        self.pdfRenderQueue.async {
          guard let doc = PDFDocument(url: URL(fileURLWithPath: path)),
                index >= 0, index < doc.pageCount,
                let page = doc.page(at: index)
          else {
            DispatchQueue.main.async {
              result(FlutterError(code: "pdf_render_failed", message: "page unavailable", details: nil))
            }
            return
          }
          let bounds = page.bounds(for: .mediaBox)
          guard bounds.width > 0, bounds.height > 0 else {
            DispatchQueue.main.async {
              result(FlutterError(code: "pdf_render_failed", message: "empty page", details: nil))
            }
            return
          }
          let scale = CGFloat(targetWidth) / bounds.width
          let pixelSize = CGSize(
            width: CGFloat(targetWidth),
            height: max(bounds.height * scale, 1)
          )
          let format = UIGraphicsImageRendererFormat()
          format.scale = 1
          format.opaque = true
          let image = UIGraphicsImageRenderer(size: pixelSize, format: format)
            .image { ctx in
              UIColor.white.setFill()
              ctx.fill(CGRect(origin: .zero, size: pixelSize))
              ctx.cgContext.translateBy(x: 0, y: pixelSize.height)
              ctx.cgContext.scaleBy(x: scale, y: -scale)
              page.draw(with: .mediaBox, to: ctx.cgContext)
            }
          guard let png = image.pngData() else {
            DispatchQueue.main.async {
              result(FlutterError(code: "pdf_render_failed", message: "encode failed", details: nil))
            }
            return
          }
          DispatchQueue.main.async { result(FlutterStandardTypedData(bytes: png)) }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func attachThermalStateChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let handler = ThermalStreamHandler()
    thermalStreamHandler = handler
    FlutterEventChannel(
      name: "secretly/thermal_state",
      binaryMessenger: controller.binaryMessenger
    ).setStreamHandler(handler)
  }

  // MARK: - NSE config bridge (2026-07-17, delivery-wake NSE)
  //
  // Mirrors the identity/config the Notification Service Extension needs into
  // the shared App Group so it can authenticate GET /v1/pending in the
  // background. The extension reads these keys (see SecretlyNSE); it never
  // touches flutter_secure_storage's keychain layout directly.
  //
  // The signing seed lives in the App-Group container (iOS sandbox scoped to
  // this app + its extensions). It is the device IDENTITY/auth key, NOT a
  // message-decryption key — a leak would allow auth impersonation, never
  // plaintext, and the E2EE content stays sealed.
  private func attachNseConfigChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController
    else { return }
    let channel = FlutterMethodChannel(
      name: "secretly/nse_config",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      let defaults = UserDefaults(suiteName: "group.com.secretly.messenger")
      switch call.method {
      case "sync":
        guard let args = call.arguments as? [String: Any] else {
          result(false)
          return
        }
        defaults?.set(args["device_id"] as? String ?? "", forKey: "nse_device_id")
        defaults?.set(args["profile_id"] as? String ?? "", forKey: "nse_profile_id")
        defaults?.set(args["base_url"] as? String ?? "", forKey: "nse_base_url")
        defaults?.set(
          args["identity_seed_b64"] as? String ?? "",
          forKey: "nse_identity_seed_b64")
        if let seq = args["next_seq"] as? Int {
          defaults?.set(seq, forKey: "nse_next_seq")
        }
        result(true)
      case "updateCursor":
        // The app advanced its delivery cursor — keep the NSE's from_seq fresh
        // so it doesn't re-fetch already-applied rows.
        if let seq = (call.arguments as? [String: Any])?["next_seq"] as? Int {
          defaults?.set(seq, forKey: "nse_next_seq")
        }
        result(true)
      case "clearBadgeHint":
        defaults?.set(0, forKey: "nse_badge_hint")
        result(true)
      case "readStaged":
        // Return the staged NDJSON lines and clear the file. The app imports
        // them into its quarantine store on launch/resume.
        guard
          let dir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.secretly.messenger")
        else {
          result(nil)
          return
        }
        let fileURL = dir.appendingPathComponent("nse_staged_inbox.jsonl")
        let contents = (try? String(contentsOf: fileURL, encoding: .utf8))
        try? FileManager.default.removeItem(at: fileURL)
        result(contents)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Delivery reliability diagnostics (2026-07-16, delivery-wake audit)
  //
  // Read-only status of the iOS settings that silently degrade message
  // delivery (Background App Refresh off, Low Power Mode, notifications
  // denied) + a deep link into this app's Settings page. Nothing is toggled
  // programmatically — iOS only allows user-driven changes.
  // MARK: - SEC-11: содержимое экрана

  /// 🔴 НА iOS СНИМОК ЭКРАНА ЗАПРЕТИТЬ НЕЛЬЗЯ — такого механизма у системы
  /// просто нет, в отличие от `FLAG_SECURE` на Android. Закрыть можно ровно
  /// одно: карточку приложения в переключателе, куда система сама снимает
  /// экран при уходе в фон.
  ///
  /// Поэтому текст настройки на iOS говорит про переключатель приложений, а не
  /// про скриншоты. Обещать здесь защиту от снимков значило бы соврать, а
  /// неверное обещание в мессенджере опаснее отсутствующей функции: человек
  /// станет вести себя смелее, чем позволяет действительность.
  private func attachScreenPrivacyChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "secretly/screen_privacy",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setEnabled" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      let enabled = (args?["enabled"] as? Bool) ?? false
      self?.screenPrivacyEnabled = enabled
      if !enabled {
        self?.hideScreenPrivacyCover()
      }
      result(true)
    }
  }

  /// Заслонка ставится на `willResignActive`, а НЕ на `didEnterBackground`:
  /// системный снимок для переключателя делается раньше, чем приложение уходит
  /// в фон, и на позднем событии карточка успела бы сняться с содержимым.
  ///
  /// Тот же обработчик срабатывает на шторке управления и на входящем звонке —
  /// заслонка мелькнёт. Это дешевле, чем не закрыть карточку.
  private func showScreenPrivacyCover() {
    guard screenPrivacyEnabled, let host = window, screenPrivacyCover == nil else {
      return
    }
    let cover = UIView(frame: host.bounds)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.backgroundColor = UIColor.systemBackground
    let logo = UIImageView(image: UIImage(named: "AppIcon"))
    logo.contentMode = .scaleAspectFit
    logo.translatesAutoresizingMaskIntoConstraints = false
    cover.addSubview(logo)
    NSLayoutConstraint.activate([
      logo.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
      logo.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
      logo.widthAnchor.constraint(equalToConstant: 96),
      logo.heightAnchor.constraint(equalToConstant: 96),
    ])
    host.addSubview(cover)
    screenPrivacyCover = cover
  }

  private func hideScreenPrivacyCover() {
    screenPrivacyCover?.removeFromSuperview()
    screenPrivacyCover = nil
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    showScreenPrivacyCover()
    super.applicationWillResignActive(application)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    hideScreenPrivacyCover()
    super.applicationDidBecomeActive(application)
  }

  private func attachReliabilityChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "secretly/reliability",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getStatus":
        let backgroundRefresh: String
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available: backgroundRefresh = "available"
        case .denied: backgroundRefresh = "denied"
        case .restricted: backgroundRefresh = "restricted"
        @unknown default: backgroundRefresh = "unknown"
        }
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          let notificationsEnabled = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
          DispatchQueue.main.async {
            result([
              "backgroundRefresh": backgroundRefresh,
              "lowPowerMode": lowPower,
              "notificationsEnabled": notificationsEnabled,
            ])
          }
        }
      case "openAppSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url, options: [:]) { ok in
            result(ok)
          }
        } else {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Sticker AI cutout (on-device Vision subject mask, iOS 17+)

  private func attachStickerAiChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "secretly/sticker_ai",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "segment":
        guard let path = (call.arguments as? [String: Any])?["path"] as? String,
          !path.isEmpty
        else {
          result(FlutterError(code: "bad_args", message: "path required", details: nil))
          return
        }
        if #available(iOS 17.0, *) {
          // Vision is heavy — run off the main thread. Returns one full-frame
          // masked PNG path per detected subject instance.
          DispatchQueue.global(qos: .userInitiated).async {
            let paths = self?.stickerSegment(imagePath: path) ?? []
            DispatchQueue.main.async { result(paths) }
          }
        } else {
          // iOS < 17 has no foreground-instance mask; Dart keeps the original.
          result([String]())
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Detect every subject in the image at `imagePath` using Vision's on-device
  /// foreground-instance mask (fully on-device). Returns one **full-frame**
  /// masked PNG path per subject instance (that subject visible, the rest
  /// transparent, aligned to the source) — empty on failure. The editor lets
  /// the user pick which subjects to keep.
  @available(iOS 17.0, *)
  private func stickerSegment(imagePath: String) -> [String] {
    guard let image = UIImage(contentsOfFile: imagePath) else { return [] }
    // Normalise orientation so Vision sees upright pixels.
    let renderer = UIGraphicsImageRenderer(size: image.size)
    let normalized = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: image.size))
    }
    guard let cg = normalized.cgImage else { return [] }
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
    do {
      try handler.perform([request])
      guard let observation = request.results?.first else { return [] }
      let context = CIContext(options: nil)
      let stamp = Int(Date().timeIntervalSince1970 * 1000)
      var paths: [String] = []
      var index = 0
      for instance in observation.allInstances {
        index += 1
        do {
          let masked = try observation.generateMaskedImage(
            ofInstances: IndexSet(integer: instance),
            from: handler,
            croppedToInstancesExtent: false
          )
          let ciImage = CIImage(cvPixelBuffer: masked)
          guard let outCg = context.createCGImage(ciImage, from: ciImage.extent),
            let png = UIImage(cgImage: outCg).pngData()
          else { continue }
          let outPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("sticker_subj_\(index)_\(stamp).png")
          try png.write(to: URL(fileURLWithPath: outPath))
          paths.append(outPath)
        } catch {
          continue
        }
      }
      return paths
    } catch {
      os_log(
        "sticker segment failed: %{public}@", log: slyDiagLog, type: .error,
        String(describing: error))
      return []
    }
  }

  // MARK: - Alternate app icons (premium feature #4)

  private func attachAppIconChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      os_log("alt-icon channel: no FlutterViewController", log: slyDiagLog, type: .error)
      return
    }
    let channel = FlutterMethodChannel(
      name: "secretly/app_icon",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "supportsAlternateIcons":
        result(UIApplication.shared.supportsAlternateIcons)
      case "getAlternateIconName":
        result(UIApplication.shared.alternateIconName)
      case "setAlternateIcon":
        guard UIApplication.shared.supportsAlternateIcons else {
          result(false)
          return
        }
        // A nil/empty name reverts to the primary (default) app icon.
        let rawName = (call.arguments as? [String: Any])?["name"] as? String
        let name = (rawName?.isEmpty ?? true) ? nil : rawName
        UIApplication.shared.setAlternateIconName(name) { error in
          if let error = error {
            os_log(
              "alt-icon set failed: %{public}@",
              log: slyDiagLog, type: .error, error.localizedDescription
            )
          }
          DispatchQueue.main.async { result(error == nil) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - PKPushRegistryDelegate

  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate pushCredentials: PKPushCredentials,
    for type: PKPushType
  ) {
    guard type == .voIP else { return }
    let tokenData = pushCredentials.token
    let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
    os_log(
      "event=voip_push.token_updated len=%d",
      log: slyDiagLog, type: .info,
      tokenHex.count
    )
    UserDefaults.standard.set(tokenHex, forKey: "secretly_voip_push_token")
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    // ── Apple VoIP push contract (iOS 13+) ────────────────────────────────
    // Every PKPushTypeVoIP push MUST result in CXProvider.reportNewIncomingCall
    // BEFORE the `completion` handler returns. If we silently early-return
    // (filter mismatch, stale push, parse error), iOS treats the app as
    // "abusing" the VoIP entitlement: it terminates the process, then
    // progressively throttles the token, and eventually stops delivering
    // VoIP pushes entirely until reinstall. Symptom in the field: «calls
    // stopped arriving on iOS».
    //
    // The fix: every rejection path goes through `reportRejectedVoipPush`,
    // which (1) reports a synthetic incoming call so the contract is
    // satisfied, then (2) immediately reports it ended with `.failed`.
    // Done within the same run-loop tick, CallKit dismisses the call
    // before any UI is rendered — so the user sees nothing, the token
    // stays alive, and the next legit push rings normally.
    guard type == .voIP else {
      nativeCallBridge.reportRejectedVoipPush(peerName: "Secretly", isVideo: false, reason: "wrong_type")
      completion()
      return
    }
    let data = payload.dictionaryPayload
    let wakeKind = ((data["wake_kind"] as? String) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let action = ((data["action"] as? String) ?? (data["call_action"] as? String) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let displayMode = ((data["display_mode"] as? String) ?? (data["displayMode"] as? String) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let payloadPeerName = ((data["peer_name"] as? String) ?? (data["peerName"] as? String) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let payloadIsVideo = (data["is_video"] as? Bool) ?? ((data["is_video"] as? String)?.lowercased() == "true") ?? false
    if !wakeKind.isEmpty && wakeKind != "call_invite_v1" {
      os_log(
        "event=voip_push.ignored_non_invite wakeKind=%{public}@ action=%{public}@ displayMode=%{public}@",
        log: slyDiagLog, type: .info,
        wakeKind, action, displayMode
      )
      nativeCallBridge.reportRejectedVoipPush(
        peerName: payloadPeerName.isEmpty ? "Secretly" : payloadPeerName,
        isVideo: payloadIsVideo,
        reason: "wrong_wake_kind"
      )
      completion()
      return
    }
    if wakeKind == "call_invite_v1" &&
      ((!action.isEmpty && action != "invite") || (!displayMode.isEmpty && displayMode != "incoming")) {
      os_log(
        "event=voip_push.ignored_non_invite action=%{public}@ displayMode=%{public}@",
        log: slyDiagLog, type: .info,
        action, displayMode
      )
      nativeCallBridge.reportRejectedVoipPush(
        peerName: payloadPeerName.isEmpty ? "Secretly" : payloadPeerName,
        isVideo: payloadIsVideo,
        reason: "wrong_action_or_display_mode"
      )
      completion()
      return
    }
    let callId = ((data["call_id"] as? String) ?? (data["callId"] as? String) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let callAttemptId = ((data["call_attempt_id"] as? String) ?? (data["callAttemptId"] as? String) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let peerName = payloadPeerName
    let isVideo = payloadIsVideo

    os_log(
      "event=voip_push.incoming_call callId=%{public}@ isVideo=%d",
      log: slyDiagLog, type: .info,
      String(callId.prefix(8)), isVideo ? 1 : 0
    )

    // Parse creation timestamp for stale-call detection (added by relay Phase 4).
    // Accept both string and numeric encodings — earlier relay builds shipped
    // it as a string, newer ones occasionally use a JSON number.
    let createdAtMsRaw = (data["created_at_ms"] as? String) ?? ""
    var createdAtMs = Int64(createdAtMsRaw) ?? 0
    if createdAtMs == 0, let numeric = data["created_at_ms"] as? NSNumber {
      createdAtMs = numeric.int64Value
    }

    // CallKit REQUIRES reportNewIncomingCall before the completion handler.
    // This wakes the app from a killed state and shows the native call UI.
    // Post-report stale validation (which always reports first, then ends
    // the call if stale) is handled inside reportVoipIncomingCall — so this
    // path is always contract-compliant.
    nativeCallBridge.reportVoipIncomingCall(
      callId: callId.isEmpty ? UUID().uuidString : callId,
      callAttemptId: callAttemptId,
      peerName: peerName.isEmpty ? secretlyLocalized("call_unknown", "Secretly") : peerName,
      isVideo: isVideo,
      createdAtMs: createdAtMs
    )
    completion()
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didInvalidatePushTokenFor type: PKPushType
  ) {
    guard type == .voIP else { return }
    UserDefaults.standard.removeObject(forKey: "secretly_voip_push_token")
    os_log("event=voip_push.token_invalidated", log: slyDiagLog, type: .info)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    nativePushDiagnosticsBridge.recordApnsToken(deviceToken)
    if firebaseConfigured {
      Messaging.messaging().apnsToken = deviceToken
    }
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    nativePushDiagnosticsBridge.recordApnsRegistrationFailure(error)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    let typ = (userInfo["type"] as? String) ?? ""
    os_log("event=notif.will_present type=%{public}@", log: slyDiagLog, type: .info, typ)
    // Suppress message notification banners while a call is active (any phase).
    // Call notifications (type="incoming_call") still go through.
    if nativeCallBridge.isCallActive && typ != "incoming_call" {
      completionHandler([])
      return
    }
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
      return
    }
    completionHandler([.alert, .sound, .badge])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    let convoId = (userInfo["convo_id"] as? String) ?? ""
    let convoPfx = String(convoId.replacingOccurrences(of: "-", with: "").prefix(8))
    os_log("event=notif.opened convo=%{public}@", log: slyDiagLog, type: .info, convoPfx)
    if !nativeMessageActionsBridge.handleNotificationResponse(response) {
      nativeNotificationBridge.handleNotificationResponse(response)
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  private func configureFirebaseIfAvailable() {
    if FirebaseApp.app() != nil {
      firebaseConfigured = true
      return
    }
    guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
      return
    }
    FirebaseApp.configure()
    firebaseConfigured = true
  }

  private func attachNativeBridges() {
    if let messageNotificationRegistrar = registrar(forPlugin: "SecretlyNativeMessageNotificationBridge") {
      nativeMessageNotificationBridge.attach(to: messageNotificationRegistrar.messenger())
    }
    if let notificationRegistrar = registrar(forPlugin: "SecretlyNativeNotificationBridge") {
      nativeNotificationBridge.attach(to: notificationRegistrar.messenger())
    }
    if let messageActionsRegistrar = registrar(forPlugin: "SecretlyNativeMessageActionsBridge") {
      nativeMessageActionsBridge.attach(to: messageActionsRegistrar.messenger())
    }
    if let pushDiagnosticsRegistrar = registrar(forPlugin: "SecretlyNativePushDiagnosticsBridge") {
      nativePushDiagnosticsBridge.attach(to: pushDiagnosticsRegistrar.messenger())
    }
    if let callLogRegistrar = registrar(forPlugin: "SecretlyNativeCallLogBridge") {
      nativeCallLogBridge.attach(to: callLogRegistrar.messenger())
    }
    if let mediaRegistrar = registrar(forPlugin: "SecretlyNativeMediaBridge") {
      nativeMediaBridge.attach(to: mediaRegistrar.messenger())
    }
    if let callRegistrar = registrar(forPlugin: "SecretlyNativeCallBridge") {
      nativeCallBridge.attach(to: callRegistrar.messenger())
    }
    if let networkPathRegistrar = registrar(forPlugin: "SecretlyNativeNetworkPathBridge") {
      nativeNetworkPathBridge.attach(to: networkPathRegistrar.messenger())
    }
    if let clipboardRegistrar = registrar(forPlugin: "SecretlyNativeClipboardMediaBridge") {
      nativeClipboardMediaBridge.attach(to: clipboardRegistrar.messenger())
    }
    if let fileOpenRegistrar = registrar(forPlugin: "SecretlyNativeFileOpenBridge") {
      nativeFileOpenBridge.attach(to: fileOpenRegistrar.messenger())
    }
    if let pipRegistrar = registrar(forPlugin: "SecretlyNativePictureInPictureBridge") {
      nativePictureInPictureBridge.attach(
        to: pipRegistrar.messenger(),
        hostViewControllerProvider: { [weak self] in
          self?.window?.rootViewController
        }
      )
    }
  }
}

private final class NativeNetworkPathBridge: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var monitor: NWPathMonitor?
  private let queue = DispatchQueue(label: "secretly.network_path")

  func attach(to messenger: FlutterBinaryMessenger) {
    let eventChannel = FlutterEventChannel(
      name: "secretly/network_path",
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    startMonitor()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopMonitor()
    eventSink = nil
    return nil
  }

  private func startMonitor() {
    stopMonitor()
    let monitor = NWPathMonitor()
    self.monitor = monitor
    monitor.pathUpdateHandler = { [weak self] path in
      self?.emit(path: path)
    }
    monitor.start(queue: queue)
    emit(path: monitor.currentPath)
  }

  private func stopMonitor() {
    monitor?.cancel()
    monitor = nil
  }

  private func emit(path: NWPath) {
    let payload = payload(for: path)
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(payload)
    }
  }

  private func payload(for path: NWPath) -> [String: Any] {
    var transports: [String] = []
    if path.usesInterfaceType(.wifi) {
      transports.append("wifi")
    }
    if path.usesInterfaceType(.cellular) {
      transports.append("cellular")
    }
    if path.usesInterfaceType(.wiredEthernet) {
      transports.append("wired")
    }
    if path.usesInterfaceType(.other) {
      transports.append("other")
    }
    if path.status == .satisfied, transports.isEmpty {
      transports.append("other")
    }
    let available = path.status == .satisfied
    let sortedTransports = transports.sorted()
    let status: String
    switch path.status {
    case .satisfied:
      status = "satisfied"
    case .unsatisfied:
      status = "unsatisfied"
    case .requiresConnection:
      status = "requiresConnection"
    @unknown default:
      status = "unknown"
    }
    // F9 (2026-05-16, A3): include the concrete interface identifiers and
    // gateway endpoints so Wi-Fi-A → Wi-Fi-B and cellular handovers that
    // swap the underlying interface or default gateway produce a different
    // signature. Without this, both networks collapse to
    // `wifi|unmetered|...` and the Flutter recovery handler never sees
    // `forcePathChanged=true`. Gateway debug strings include the gateway IP
    // which differs between most networks (gateways API is iOS 14+; we
    // fall back to the interface tokens on iOS 13).
    let interfaceTokens = path.availableInterfaces
      .map { "\($0.name)#\($0.index)" }
      .sorted()
    let gatewayToken: String
    if #available(iOS 14.0, *) {
      gatewayToken = path.gateways
        .map { String(describing: $0) }
        .sorted()
        .joined(separator: ",")
    } else {
      gatewayToken = ""
    }
    let signature = [
      sortedTransports.joined(separator: "+"),
      path.isExpensive ? "expensive" : "unmetered",
      path.isConstrained ? "constrained" : "unconstrained",
      "status=\(status)",
      "if=\(interfaceTokens.joined(separator: ","))",
      "gw=\(gatewayToken)",
    ].joined(separator: "|")
    return [
      "available": available,
      "transports": sortedTransports,
      "expensive": path.isExpensive,
      "constrained": path.isConstrained,
      "signature": signature,
    ]
  }
}

// MARK: - Picture-in-Picture bridge
//
// Provides iOS parity with `AndroidPictureInPicture` for the Flutter side via
// the `secretly/picture_in_picture` MethodChannel. Implements the iOS 15+
// `AVPictureInPictureVideoCallViewController` API path: when a video call is
// active, the bridge mounts an invisible 1×1 host controller in the Flutter
// window. When the user backgrounds the app, iOS automatically activates PiP
// and displays the host view inside a floating system window. Audio continues
// uninterrupted via CallKit + AVAudioSession.
//
// The PiP content is a lightweight placeholder UI (peer-name label + call-active
// indicator). True WebRTC remote-track frame piping into the PiP layer would
// require deeper integration with flutter_webrtc's iOS RTCVideoTrack — this
// bridge is structured so the placeholder UIView can be swapped for an
// RTCMTLVideoView whenever the upstream plugin exposes the track reference.

private final class NativePictureInPictureBridge: NSObject {
  private var methodChannel: FlutterMethodChannel?
  private var hostProvider: (() -> UIViewController?)?
  private var enabled = false
  private var configuredPeerName: String = ""
  // iOS 15+ only — guarded by availability checks at every call site that
  // touches AVPictureInPicture* types. We hold these as `Any?` so the type
  // is erased and the bridge compiles on older minimum-deployment targets.
  private var pipController: Any?
  private var pipContentVC: UIViewController?
  private var placeholderTitleLabel: UILabel?
  private var placeholderSubtitleLabel: UILabel?

  func attach(
    to messenger: FlutterBinaryMessenger,
    hostViewControllerProvider: @escaping () -> UIViewController?
  ) {
    self.hostProvider = hostViewControllerProvider
    let channel = FlutterMethodChannel(
      name: "secretly/picture_in_picture",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    self.methodChannel = channel
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(isSupportedNative())

    case "setAutoEnterEnabled":
      let args = call.arguments as? [String: Any] ?? [:]
      let wantsEnabled = (args["enabled"] as? Bool) ?? false
      let peerName = (args["peerName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { result(false); return }
        if wantsEnabled {
          let ok = self.configure(peerName: peerName)
          result(ok)
        } else {
          self.teardown()
          result(true)
        }
      }

    case "enter":
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { result(false); return }
        result(self.enterPiP())
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func isSupportedNative() -> Bool {
    if #available(iOS 15.0, *) {
      return AVPictureInPictureController.isPictureInPictureSupported()
    }
    return false
  }

  @discardableResult
  private func configure(peerName: String) -> Bool {
    guard #available(iOS 15.0, *),
          AVPictureInPictureController.isPictureInPictureSupported(),
          let host = hostProvider?() else {
      return false
    }

    let displayName = peerName.isEmpty
      ? secretlyLocalized("call_unknown", "Secretly")
      : peerName
    configuredPeerName = displayName

    // If already configured, just refresh the labels and bail.
    if let titleLabel = placeholderTitleLabel {
      titleLabel.text = displayName
      placeholderSubtitleLabel?.text = secretlyLocalized(
        "call_pip_active",
        "Call in progress — tap to return"
      )
      enabled = true
      return true
    }

    let contentVC = AVPictureInPictureVideoCallViewController()
    contentVC.preferredContentSize = CGSize(width: 360, height: 640)
    contentVC.view.backgroundColor = UIColor(
      red: 0.04, green: 0.18, blue: 0.10, alpha: 1.0
    )

    let stack = UIStackView()
    stack.axis = .vertical
    stack.alignment = .center
    stack.distribution = .equalCentering
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false
    contentVC.view.addSubview(stack)

    let dot = UIView()
    dot.translatesAutoresizingMaskIntoConstraints = false
    dot.backgroundColor = UIColor(
      red: 0.13, green: 0.85, blue: 0.45, alpha: 1.0
    )
    dot.layer.cornerRadius = 6

    let title = UILabel()
    title.translatesAutoresizingMaskIntoConstraints = false
    title.text = displayName
    title.textColor = .white
    title.font = .systemFont(ofSize: 18, weight: .semibold)
    title.numberOfLines = 2
    title.textAlignment = .center

    let subtitle = UILabel()
    subtitle.translatesAutoresizingMaskIntoConstraints = false
    subtitle.text = secretlyLocalized(
      "call_pip_active",
      "Call in progress — tap to return"
    )
    subtitle.textColor = UIColor.white.withAlphaComponent(0.75)
    subtitle.font = .systemFont(ofSize: 12, weight: .regular)
    subtitle.numberOfLines = 2
    subtitle.textAlignment = .center

    stack.addArrangedSubview(dot)
    stack.addArrangedSubview(title)
    stack.addArrangedSubview(subtitle)
    NSLayoutConstraint.activate([
      dot.widthAnchor.constraint(equalToConstant: 12),
      dot.heightAnchor.constraint(equalToConstant: 12),
      stack.centerXAnchor.constraint(equalTo: contentVC.view.centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: contentVC.view.centerYAnchor),
      stack.leadingAnchor.constraint(
        greaterThanOrEqualTo: contentVC.view.leadingAnchor, constant: 12
      ),
      stack.trailingAnchor.constraint(
        lessThanOrEqualTo: contentVC.view.trailingAnchor, constant: -12
      ),
    ])

    placeholderTitleLabel = title
    placeholderSubtitleLabel = subtitle

    // Mount the PiP content VC as an invisible child of the host so the system
    // has a live UIView source to snapshot.
    host.addChild(contentVC)
    host.view.addSubview(contentVC.view)
    contentVC.view.frame = CGRect(x: -2, y: -2, width: 1, height: 1)
    contentVC.view.alpha = 0.0
    contentVC.didMove(toParent: host)

    let source = AVPictureInPictureController.ContentSource(
      activeVideoCallSourceView: contentVC.view,
      contentViewController: contentVC
    )
    let controller = AVPictureInPictureController(contentSource: source)
    controller.canStartPictureInPictureAutomaticallyFromInline = true

    pipContentVC = contentVC
    pipController = controller
    enabled = true
    os_log(
      "event=ios_pip.configured peerName=%{public}@",
      log: slyDiagLog, type: .info,
      String(displayName.prefix(32))
    )
    return true
  }

  private func teardown() {
    enabled = false
    if #available(iOS 15.0, *), let controller = pipController as? AVPictureInPictureController {
      if controller.isPictureInPictureActive {
        controller.stopPictureInPicture()
      }
      controller.canStartPictureInPictureAutomaticallyFromInline = false
    }
    pipController = nil
    if let vc = pipContentVC {
      vc.willMove(toParent: nil)
      vc.view.removeFromSuperview()
      vc.removeFromParent()
    }
    pipContentVC = nil
    placeholderTitleLabel = nil
    placeholderSubtitleLabel = nil
    configuredPeerName = ""
    os_log("event=ios_pip.tore_down", log: slyDiagLog, type: .info)
  }

  private func enterPiP() -> Bool {
    if #available(iOS 15.0, *), let controller = pipController as? AVPictureInPictureController {
      if controller.isPictureInPicturePossible && !controller.isPictureInPictureActive {
        controller.startPictureInPicture()
        return true
      }
      return controller.isPictureInPictureActive
    }
    return false
  }
}

private final class NativeFileOpenBridge: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
  private var previewUrl: URL?

  func attach(to messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "secretly/file_open",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "open":
      guard let args = call.arguments as? [String: Any],
            let rawPath = args["path"] as? String else {
        result(false)
        return
      }
      let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !path.isEmpty else {
        result(false)
        return
      }
      DispatchQueue.main.async { [weak self] in
        result(self?.open(path: path) ?? false)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func open(path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path),
          let presenter = Self.topViewController() else {
      return false
    }
    previewUrl = url
    let preview = QLPreviewController()
    preview.dataSource = self
    preview.delegate = self
    presenter.present(preview, animated: true)
    return true
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
    previewUrl == nil ? 0 : 1
  }

  func previewController(
    _ controller: QLPreviewController,
    previewItemAt index: Int
  ) -> QLPreviewItem {
    return (previewUrl ?? URL(fileURLWithPath: NSTemporaryDirectory())) as NSURL
  }

  func previewControllerDidDismiss(_ controller: QLPreviewController) {
    previewUrl = nil
  }

  private static func topViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    if let navigation = top as? UINavigationController {
      return navigation.visibleViewController ?? navigation
    }
    if let tab = top as? UITabBarController {
      return tab.selectedViewController ?? tab
    }
    return top
  }
}

private final class NativeClipboardMediaBridge: NSObject {
  private struct PasteboardImageType {
    let pasteboardType: String
    let mime: String
    let fileExtension: String
  }

  private static let imageTypes = [
    PasteboardImageType(pasteboardType: "public.png", mime: "image/png", fileExtension: "png"),
    PasteboardImageType(pasteboardType: "public.jpeg", mime: "image/jpeg", fileExtension: "jpg"),
    PasteboardImageType(pasteboardType: "public.tiff", mime: "image/tiff", fileExtension: "tiff"),
    PasteboardImageType(pasteboardType: "com.compuserve.gif", mime: "image/gif", fileExtension: "gif"),
    PasteboardImageType(pasteboardType: "org.webmproject.webp", mime: "image/webp", fileExtension: "webp"),
    PasteboardImageType(pasteboardType: "public.heic", mime: "image/heic", fileExtension: "heic"),
    PasteboardImageType(pasteboardType: "public.heif", mime: "image/heif", fileExtension: "heif"),
  ]

  func attach(to messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "secretly/clipboard_media",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "readImage":
      DispatchQueue.main.async { [weak self] in
        result(self?.readImageFromPasteboard())
      }
    case "copyUri":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func readImageFromPasteboard() -> [String: Any]? {
    let pasteboard = UIPasteboard.general
    for type in Self.imageTypes {
      if pasteboard.contains(pasteboardTypes: [type.pasteboardType]),
         let data = pasteboard.data(forPasteboardType: type.pasteboardType),
         !data.isEmpty {
        return saveImageData(data, mime: type.mime, fileExtension: type.fileExtension)
      }
    }

    if let fileUrl = pasteboard.url,
       fileUrl.isFileURL,
       let type = Self.imageType(forExtension: fileUrl.pathExtension),
       let data = try? Data(contentsOf: fileUrl),
       !data.isEmpty {
      return saveImageData(data, mime: type.mime, fileExtension: type.fileExtension)
    }

    if let image = pasteboard.image,
       let data = image.pngData(),
       !data.isEmpty {
      return saveImageData(data, mime: "image/png", fileExtension: "png")
    }

    return nil
  }

  private func saveImageData(
    _ data: Data,
    mime: String,
    fileExtension: String
  ) -> [String: Any]? {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("secretly_clipboard_media", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: nil
      )
      pruneOldFiles(in: directory)
      let fileName = "clipboard_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString).\(fileExtension)"
      let fileUrl = directory.appendingPathComponent(fileName)
      try data.write(to: fileUrl, options: [.atomic])
      return ["path": fileUrl.path, "mime": mime, "name": fileName]
    } catch {
      os_log(
        "event=clipboard_image_save_failed error=%{public}@",
        log: slyDiagLog, type: .error,
        String(describing: error)
      )
      return nil
    }
  }

  private func pruneOldFiles(in directory: URL) {
    let cutoff = Date().addingTimeInterval(-3 * 24 * 60 * 60)
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
      return
    }
    for file in files {
      let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate
      if let modified, modified < cutoff {
        try? FileManager.default.removeItem(at: file)
      }
    }
  }

  private static func imageType(forExtension rawExtension: String) -> PasteboardImageType? {
    switch rawExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "png": return imageTypes[0]
    case "jpg", "jpeg": return imageTypes[1]
    case "tif", "tiff": return imageTypes[2]
    case "gif": return imageTypes[3]
    case "webp": return imageTypes[4]
    case "heic": return imageTypes[5]
    case "heif": return imageTypes[6]
    default: return nil
    }
  }
}

private final class NativeCallLogBridge: NSObject {
  func attach(to messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "secretly/log",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "log":
      let raw = call.arguments as? [String: Any]
      let tag = Self.clean((raw?["tag"] as? String) ?? "Flutter", maxLength: 48)
      let msg = Self.clean((raw?["msg"] as? String) ?? "", maxLength: 240)
      os_log(
        "event=dart_call_log tag=%{public}@ msg=%{public}@",
        log: slyDiagLog, type: .info,
        tag, msg
      )
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func clean(_ value: String, maxLength: Int) -> String {
    let collapsed = value
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\r", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if collapsed.count <= maxLength {
      return collapsed
    }
    return String(collapsed.prefix(maxLength))
  }
}

private final class NativePushDiagnosticsBridge: NSObject {
  private let stateLock = NSLock()
  private var firebaseConfigured = false
  private var remoteRegistrationRequestedAtMs = 0
  private var apnsTokenPresent = false
  private var apnsTokenRegisteredAtMs = 0
  private var apnsRegistrationError: String?

  func attach(to messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "secretly/push_diag",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  func setFirebaseConfigured(_ configured: Bool) {
    stateLock.lock()
    firebaseConfigured = configured
    stateLock.unlock()
  }

  func markRemoteRegistrationRequested() {
    stateLock.lock()
    remoteRegistrationRequestedAtMs = Self.nowMs()
    stateLock.unlock()
  }

  func recordApnsToken(_ deviceToken: Data) {
    stateLock.lock()
    apnsTokenPresent = !deviceToken.isEmpty
    apnsTokenRegisteredAtMs = Self.nowMs()
    apnsRegistrationError = nil
    stateLock.unlock()
  }

  func recordApnsRegistrationFailure(_ error: Error) {
    stateLock.lock()
    apnsTokenPresent = false
    apnsRegistrationError = Self.summarize(error)
    stateLock.unlock()
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getStatus":
      result(snapshot())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func snapshot() -> [String: Any] {
    stateLock.lock()
    defer { stateLock.unlock() }
    let voipToken = UserDefaults.standard.string(forKey: "secretly_voip_push_token") ?? ""
    return [
      "firebaseConfigured": firebaseConfigured,
      "remoteRegistrationRequestedAtMs": remoteRegistrationRequestedAtMs,
      "apnsTokenPresent": apnsTokenPresent,
      "apnsTokenRegisteredAtMs": apnsTokenRegisteredAtMs,
      "apnsRegistrationError": apnsRegistrationError ?? "",
      "voipPushToken": voipToken,
    ]
  }

  private static func nowMs() -> Int {
    Int(Date().timeIntervalSince1970 * 1000)
  }

  private static func summarize(_ error: Error) -> String {
    let raw = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    if raw.isEmpty {
      return String(describing: type(of: error))
    }
    return raw.count <= 240 ? raw : String(raw.prefix(240))
  }
}

private final class NativeMessageNotificationBridge: NSObject {
  func attach(to messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "secretly/msg_notif",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "show":
      guard let raw = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: "args are required", details: nil))
        return
      }
      let convoId = (raw["convoId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let title = (raw["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Secretly"
      let body = (raw["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if convoId.isEmpty || body.isEmpty {
        result(FlutterError(code: "bad_args", message: "convoId and body are required", details: nil))
        return
      }
      let playSound = raw["playSound"] as? Bool ?? true

      let content = UNMutableNotificationContent()
      content.title = title.isEmpty ? "Secretly" : title
      content.body = body
      content.threadIdentifier = convoId
      content.userInfo = [
        "convo_id": convoId,
      ]
      if !convoId.hasPrefix("req:") {
        content.categoryIdentifier = secretlyMessageCategoryId
      }
      if playSound {
        content.sound = .default
      }

      let request = UNNotificationRequest(
        identifier: notificationId(for: convoId),
        content: content,
        trigger: nil
      )
      UNUserNotificationCenter.current().add(request) { error in
        if let error {
          result(FlutterError(code: "show_failed", message: error.localizedDescription, details: nil))
          return
        }
        result(nil)
      }

    case "clear", "cancel":
      let raw = call.arguments as? [String: Any]
      let convoId = (raw?["convoId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      guard !convoId.isEmpty else {
        result(FlutterError(code: "bad_args", message: "convoId is required", details: nil))
        return
      }
      let identifier = notificationId(for: convoId)
      let center = UNUserNotificationCenter.current()
      center.removePendingNotificationRequests(withIdentifiers: [identifier])
      center.removeDeliveredNotifications(withIdentifiers: [identifier])
      result(nil)

    case "setBadge":
      // Set the app-icon unread badge to `count` (0 clears it). Called by the
      // Dart side whenever the local unread total changes; the server also sets
      // aps.badge on pushes so the count updates while the app is killed.
      let raw = call.arguments as? [String: Any]
      let count = max(0, (raw?["count"] as? NSNumber)?.intValue ?? 0)
      let apply = {
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(count)
        } else {
          UIApplication.shared.applicationIconBadgeNumber = count
        }
      }
      if Thread.isMainThread {
        apply()
      } else {
        DispatchQueue.main.async { apply() }
      }
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func notificationId(for convoId: String) -> String {
    "secretly_msg_\(convoId)"
  }
}

private final class NativeNotificationBridge: NSObject, FlutterStreamHandler {
  private static let pendingConvoIdKey = "secretly_pending_notif_tap_convo_id"

  private var eventSink: FlutterEventSink?

  func attach(to messenger: FlutterBinaryMessenger) {
    let eventChannel = FlutterEventChannel(
      name: "secretly/notif_tap",
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    flushPendingConversation()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func handleNotificationResponse(_ response: UNNotificationResponse) {
    guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
      return
    }
    emitOrBuffer(conversationId: extractConversationId(from: response.notification.request.content.userInfo))
  }

  func bufferLaunchNotification(userInfo: [AnyHashable: Any]) {
    emitOrBuffer(conversationId: extractConversationId(from: userInfo))
  }

  private func extractConversationId(from userInfo: [AnyHashable: Any]) -> String? {
    secretlyConversationId(from: userInfo)
  }

  private func emitOrBuffer(conversationId: String?) {
    guard let conversationId else {
      return
    }
    if let eventSink {
      eventSink(conversationId)
      return
    }
    UserDefaults.standard.set(conversationId, forKey: Self.pendingConvoIdKey)
  }

  private func flushPendingConversation() {
    guard let eventSink else {
      return
    }
    let conversationId = (UserDefaults.standard.string(forKey: Self.pendingConvoIdKey) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !conversationId.isEmpty else {
      return
    }
    UserDefaults.standard.removeObject(forKey: Self.pendingConvoIdKey)
    eventSink(conversationId)
  }
}

private final class NativeMessageActionsBridge: NSObject, FlutterStreamHandler {
  private static let pendingActionKey = "secretly_pending_msg_action_v1"

  private var eventSink: FlutterEventSink?

  func attach(to messenger: FlutterBinaryMessenger) {
    let eventChannel = FlutterEventChannel(
      name: "secretly/msg_actions",
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    flushPendingAction()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func handleNotificationResponse(_ response: UNNotificationResponse) -> Bool {
    let userInfo = response.notification.request.content.userInfo
    guard let convoId = secretlyConversationId(from: userInfo) else {
      return false
    }
    switch response.actionIdentifier {
    case secretlyMessageReplyActionId:
      let text = (response as? UNTextInputNotificationResponse)?.userText
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if text.isEmpty {
        return true
      }
      emitOrBuffer(action: [
        "action": "reply",
        "convoId": convoId,
        "text": text,
      ])
      return true

    case secretlyMessageMarkReadActionId:
      emitOrBuffer(action: [
        "action": "mark_read",
        "convoId": convoId,
      ])
      return true

    default:
      return false
    }
  }

  private func emitOrBuffer(action: [String: Any]) {
    if let eventSink {
      eventSink(action)
      return
    }
    if action["text"] is String {
      UserDefaults.standard.removeObject(forKey: Self.pendingActionKey)
      return
    }
    guard let data = try? JSONSerialization.data(withJSONObject: action),
      let raw = String(data: data, encoding: .utf8)
    else {
      return
    }
    UserDefaults.standard.set(raw, forKey: Self.pendingActionKey)
  }

  private func flushPendingAction() {
    guard let eventSink else {
      return
    }
    let raw = (UserDefaults.standard.string(forKey: Self.pendingActionKey) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty,
      let data = raw.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return
    }
    UserDefaults.standard.removeObject(forKey: Self.pendingActionKey)
    eventSink(json)
  }
}

private final class NativeMediaBridge: NSObject, FlutterStreamHandler {
  private struct MediaState {
    let trackId: String
    let title: String
    let artist: String
    let album: String
    let artworkPath: String?
    let playing: Bool
    let positionMs: Double
    let durationMs: Double
    let canSkipPrevious: Bool
    let canSkipNext: Bool

    init?(arguments: Any?) {
      guard let raw = arguments as? [String: Any] else {
        return nil
      }

      trackId = (raw["trackId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let rawTitle = (raw["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      title = rawTitle.isEmpty ? "Secretly" : rawTitle
      artist = (raw["artist"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      album = (raw["album"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let rawArtworkPath = (raw["artworkPath"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      artworkPath = (rawArtworkPath?.isEmpty == false) ? rawArtworkPath : nil
      playing = raw["playing"] as? Bool ?? false
      positionMs = NativeMediaBridge.doubleValue(raw["positionMs"])
      durationMs = NativeMediaBridge.doubleValue(raw["durationMs"])
      canSkipPrevious = raw["canSkipPrevious"] as? Bool ?? false
      canSkipNext = raw["canSkipNext"] as? Bool ?? false
    }
  }

  private var eventSink: FlutterEventSink?
  private var pendingActions: [String] = []
  private let commandCenter = MPRemoteCommandCenter.shared()
  private let nowPlayingCenter = MPNowPlayingInfoCenter.default()
  private var remoteCommandsInstalled = false

  func attach(to messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "secretly/media_notif",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }

    let eventChannel = FlutterEventChannel(
      name: "secretly/media_actions",
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    flushPendingActions()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func handle(call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "update":
      guard let state = MediaState(arguments: call.arguments) else {
        result(
          FlutterError(
            code: "bad_args",
            message: "state is required",
            details: nil
          )
        )
        return
      }
      apply(state: state)
      result(nil)

    case "clear":
      clear()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func apply(state: MediaState) {
    installRemoteCommandsIfNeeded()
    configureAudioSession()

    var nowPlayingInfo = nowPlayingCenter.nowPlayingInfo ?? [:]
    nowPlayingInfo[MPMediaItemPropertyTitle] = state.title

    if state.artist.isEmpty {
      nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyArtist)
    } else {
      nowPlayingInfo[MPMediaItemPropertyArtist] = state.artist
    }

    if state.album.isEmpty {
      nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyAlbumTitle)
    } else {
      nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = state.album
    }

    if state.durationMs > 0 {
      nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = state.durationMs / 1000.0
    } else {
      nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyPlaybackDuration)
    }

    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, state.positionMs / 1000.0)
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = state.playing ? 1.0 : 0.0

    if let artwork = loadArtwork(from: state.artworkPath) {
      nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
    } else {
      nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyArtwork)
    }

    nowPlayingCenter.nowPlayingInfo = nowPlayingInfo
    commandCenter.previousTrackCommand.isEnabled = state.canSkipPrevious
    commandCenter.nextTrackCommand.isEnabled = state.canSkipNext
    commandCenter.playCommand.isEnabled = !state.playing
    commandCenter.pauseCommand.isEnabled = state.playing
    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.stopCommand.isEnabled = true
    UIApplication.shared.beginReceivingRemoteControlEvents()
  }

  private func clear() {
    nowPlayingCenter.nowPlayingInfo = nil
    commandCenter.playCommand.isEnabled = false
    commandCenter.pauseCommand.isEnabled = false
    commandCenter.togglePlayPauseCommand.isEnabled = false
    commandCenter.nextTrackCommand.isEnabled = false
    commandCenter.previousTrackCommand.isEnabled = false
    commandCenter.stopCommand.isEnabled = false
    UIApplication.shared.endReceivingRemoteControlEvents()

    do {
      try AVAudioSession.sharedInstance().setActive(
        false,
        options: [.notifyOthersOnDeactivation]
      )
    } catch {
    }
  }

  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playback,
        mode: .default,
        options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
      )
      try session.setActive(true)
    } catch {
    }
  }

  private func installRemoteCommandsIfNeeded() {
    guard !remoteCommandsInstalled else {
      return
    }
    remoteCommandsInstalled = true

    commandCenter.playCommand.addTarget { [weak self] _ in
      self?.emit(action: "play")
      return .success
    }
    commandCenter.pauseCommand.addTarget { [weak self] _ in
      self?.emit(action: "pause")
      return .success
    }
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.emit(action: "play_pause")
      return .success
    }
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
      self?.emit(action: "next")
      return .success
    }
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
      self?.emit(action: "previous")
      return .success
    }
    commandCenter.stopCommand.addTarget { [weak self] _ in
      self?.emit(action: "stop")
      return .success
    }
    commandCenter.changePlaybackPositionCommand.isEnabled = false
  }

  private func emit(action: String) {
    let normalized = action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalized.isEmpty else {
      return
    }

    if let eventSink {
      eventSink(["action": normalized])
      return
    }

    pendingActions.append(normalized)
    if pendingActions.count > 8 {
      pendingActions.removeFirst(pendingActions.count - 8)
    }
  }

  private func flushPendingActions() {
    guard let eventSink, !pendingActions.isEmpty else {
      return
    }

    let buffered = pendingActions
    pendingActions.removeAll(keepingCapacity: true)
    for action in buffered {
      eventSink(["action": action])
    }
  }

  private func loadArtwork(from path: String?) -> MPMediaItemArtwork? {
    guard let path, !path.isEmpty, let image = UIImage(contentsOfFile: path) else {
      return nil
    }

    return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
  }

  private static func doubleValue(_ value: Any?) -> Double {
    if let number = value as? NSNumber {
      return number.doubleValue
    }
    return 0
  }
}

private final class NativeCallBridge: NSObject, FlutterStreamHandler, CXProviderDelegate {
  private struct CallArguments {
    let callId: String
    let callAttemptId: String
    let peerName: String
    let isVideo: Bool

    init?(arguments: Any?) {
      guard let raw = arguments as? [String: Any] else {
        return nil
      }

      let rawCallId = (raw["callId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if rawCallId.isEmpty {
        return nil
      }
      let rawCallAttemptId = (raw["callAttemptId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      callId = rawCallId
      callAttemptId = rawCallAttemptId.isEmpty ? rawCallId : rawCallAttemptId
      let rawPeerName = (raw["peerName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      peerName = rawPeerName.isEmpty ? "Secretly" : rawPeerName
      isVideo = raw["isVideo"] as? Bool ?? false
    }
  }

  private final class NativeCallContext {
    init(arguments: CallArguments, uuid: UUID) {
      self.callId = arguments.callId
      self.callAttemptId = arguments.callAttemptId
      self.peerName = arguments.peerName
      self.isVideo = arguments.isVideo
      self.uuid = uuid
    }

    let callId: String
    let callAttemptId: String
    let uuid: UUID
    var peerName: String
    var isVideo: Bool
    var wasAnswered = false
    var isConnected = false
    var isEnded = false
    var isOutgoing = false
  }

  private let provider: CXProvider
  private let callController = CXCallController()
  private var eventSink: FlutterEventSink?
  private var pendingEvents: [[String: Any]] = []
  private var callsByKey: [String: NativeCallContext] = [:]
  private var keyByUuid: [UUID: String] = [:]
  // Whether a call is currently active (any phase: ringing, connecting, connected).
  // Set by Flutter via setCallActive so willPresent can suppress message banners.
  var isCallActive = false

  // Persistent user preference for in-call audio output (speaker vs earpiece).
  // Set via `secretly/call_ui#setSpeakerEnabled`. Consumed by
  // `audioSessionCategoryOptions()` (`.defaultToSpeaker`) and re-applied as the
  // output port by `didActivate` / `reapplyCallOutputRoute` / `reestablish…`, so
  // every legitimate (re)configuration honours the current preference.
  private var speakerOverrideEnabled: Bool = false

  override init() {
    let configuration = CXProviderConfiguration(localizedName: "Secretly")
    configuration.supportsVideo = true
    configuration.maximumCallGroups = 1
    configuration.maximumCallsPerCallGroup = 1
    configuration.supportedHandleTypes = [.generic]
    configuration.includesCallsInRecents = false
    provider = CXProvider(configuration: configuration)
    super.init()
    provider.setDelegate(self, queue: nil)
    clearStaleCallKitState()

    // Observe audio route changes so that when the user
    //   • plugs / unplugs headphones,
    //   • toggles Bluetooth (AirPods, car kit, etc.),
    //   • switches between speaker and earpiece,
    //   • or the OS hand-offs between Wi-Fi and cellular networks,
    // we re-activate the audio session and restore .voiceChat category to
    // prevent WebRTC microphone capture from freezing or routing audio to a
    // disconnected device. This addresses CALLS-AUDIT P2/P3 on iOS.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioRouteChange(notification:)),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioInterruption(notification:)),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleMediaServerReset(notification:)),
      name: AVAudioSession.mediaServicesWereResetNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // SINGLE-OWNER CALL AUDIO (redesign 2026-07-09, docs/CALL_AUDIT_2026-07-09.md).
  // CallKit `provider:didActivate:` OWNS session activation + category + the
  // WebRTC unit enable; the app only ever sets the OUTPUT ROUTE (speaker vs
  // earpiece). The route observer reacts ONLY to genuine HARDWARE device changes
  // — never to our own writes — which removes the reactivate↔routeChange feedback
  // loop that flickered the speaker button and stopped the audio unit.
  @objc private func handleAudioRouteChange(notification: Notification) {
    guard isCallActive else { return }
    let userInfo = notification.userInfo ?? [:]
    let reasonRaw = (userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 0
    let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw)
    os_log(
      "event=audio.route_change reason=%lu",
      log: slyDiagLog, type: .info, reasonRaw
    )
    // React ONLY to a real device being added/removed (headset / Bluetooth
    // plug-unplug). Every OTHER reason — .categoryChange / .override /
    // .routeConfigurationChange / .wakeFromSleep — is produced by OUR OWN
    // setCategory / setActive / overrideOutputAudioPort / isAudioEnabled writes
    // (or by WebRTC applying our intent). Reacting to those is exactly what fed
    // the feedback loop. For a genuine device change we only need to re-apply the
    // OUTPUT PORT for the current preference — never setActive or bounce the unit.
    switch reason {
    case .oldDeviceUnavailable, .newDeviceAvailable:
      reapplyCallOutputRoute()
    default:
      break
    }
  }

  @objc private func handleAudioInterruption(notification: Notification) {
    guard isCallActive else { return }
    let userInfo = notification.userInfo ?? [:]
    guard let typeRaw = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
    else { return }
    if type == .ended {
      // Siri / a phone call interrupted us and the OS DEACTIVATED our session,
      // so a full re-establish (category + active + unit) is legitimately needed.
      reestablishCallAudioSession()
    }
  }

  @objc private func handleMediaServerReset(notification: Notification) {
    // Rare but catastrophic: the OS reset the audio HW. Full re-establish.
    guard isCallActive else { return }
    os_log("event=audio.media_server_reset", log: slyDiagLog, type: .error)
    reestablishCallAudioSession()
  }

  // Single source of truth for the in-call category options. `.defaultToSpeaker`
  // whenever the user has speaker on. NO `.mixWithOthers` (on `.playAndRecord` it
  // marks the session mixable, so a backgrounded/locked call keeps playback but
  // STOPS the mic — peer can't hear you; call-reliability audit 2026-06-27 BUG A).
  private func audioSessionCategoryOptions() -> AVAudioSession.CategoryOptions {
    var options: AVAudioSession.CategoryOptions = [
      .allowBluetooth,
      .allowBluetoothA2DP,
    ]
    if speakerOverrideEnabled {
      options.insert(.defaultToSpeaker)
    }
    return options
  }

  /// Re-apply ONLY the output port (speaker vs earpiece) for the current
  /// preference. The session category + activation are owned by CallKit
  /// `didActivate` and are NOT touched here, so this can neither deactivate the
  /// session nor restart the unit — i.e. it can never loop or flicker. Used on a
  /// real hardware device change and by `setSpeakerEnabled`.
  private func reapplyCallOutputRoute() {
    do {
      try AVAudioSession.sharedInstance().overrideOutputAudioPort(
        speakerOverrideEnabled ? .speaker : .none
      )
      os_log(
        "event=call_audio.route_reapplied speaker=%{public}@",
        log: slyDiagLog, type: .info,
        speakerOverrideEnabled ? "true" : "false"
      )
    } catch {
      os_log(
        "event=call_audio.route_reapply_failed err=%{public}@",
        log: slyDiagLog, type: .error,
        error.localizedDescription
      )
    }
  }

  /// Full re-establish after the OS tore the session down (interruption end,
  /// media-services reset). Reconfigures category + activates + re-enables the
  /// WebRTC unit. Fires ONLY on those rare OS events — not on our own route
  /// changes — so it can no longer feed the route-change observer.
  private func reestablishCallAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: audioSessionCategoryOptions()
      )
      try session.setActive(true, options: .notifyOthersOnDeactivation)
      try session.overrideOutputAudioPort(
        speakerOverrideEnabled ? .speaker : .none
      )
      ensureCallAudioUnitEnabled()
      os_log(
        "event=audio.session_reestablished speaker=%{public}@",
        log: slyDiagLog, type: .info,
        speakerOverrideEnabled ? "true" : "false"
      )
    } catch {
      os_log(
        "event=audio.session_reestablish_failed err=%{public}@",
        log: slyDiagLog, type: .error,
        error.localizedDescription
      )
    }
  }

  /// Backstop enable of WebRTC's manual-audio unit for an active call — a PLAIN
  /// set (never a NO→YES bounce). CallKit `didActivate` is the primary enabler;
  /// this covers the rare case it was missed/late. Setting YES when already YES
  /// is a harmless no-op and emits no route change.
  private func ensureCallAudioUnitEnabled() {
    guard isCallActive else { return }
    let rtcSession = RTCAudioSession.sharedInstance()
    if !rtcSession.isAudioEnabled {
      rtcSession.isAudioEnabled = true
      os_log("event=call_audio.unit_enabled", log: slyDiagLog, type: .info)
    }
  }

  /// Restart the WebRTC unit (bounce NO→YES) ONCE, at the CONNECTED transition,
  /// to guarantee it renders the freshly-attached remote audio track (the
  /// incoming-call case where the track arrives after `didActivate` enabled the
  /// unit against no track). Safe now that the route observer ignores the
  /// resulting `.routeConfigurationChange` — it can no longer loop. Called from
  /// the Dart `reassertCallAudio` on connect.
  private func restartCallAudioUnit() {
    guard isCallActive else { return }
    let rtcSession = RTCAudioSession.sharedInstance()
    rtcSession.isAudioEnabled = false
    rtcSession.isAudioEnabled = true
    os_log("event=call_audio.unit_restarted", log: slyDiagLog, type: .info)
  }

  func attach(to messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "secretly/call_ui",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }

    let eventChannel = FlutterEventChannel(
      name: "secretly/call_actions",
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    flushPendingEvents()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func providerDidReset(_ provider: CXProvider) {
    callsByKey.removeAll(keepingCapacity: false)
    keyByUuid.removeAll(keepingCapacity: false)
  }

  func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
    guard let context = context(for: action.callUUID) else {
      action.fail()
      return
    }
    // PR-G (bug 18): do NOT set `wasAnswered=true` here. Previously this
    // mis-flag caused a CallKit auto-fail (AudioSession activation failure /
    // missing reportOutgoingCall(connectedAt:)) to be reported to Flutter as
    // a user-confirmed "hangup" instead of a caller-side cancel, which kept
    // the callee ringing because the cancel signal got swallowed on the
    // wire. Mark wasAnswered ONLY in CXAnswerCallAction below.
    provider.reportOutgoingCall(with: context.uuid, startedConnectingAt: Date())
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    guard let context = context(for: action.callUUID) else {
      action.fail()
      return
    }
    context.wasAnswered = true
    context.isConnected = true
    emit(action: "accept", context: context)
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    guard let context = context(for: action.callUUID) else {
      action.fulfill()
      return
    }
    // PR-G (bug 18): emit one of three actions so Flutter can react
    // correctly to all three CallKit-triggered teardown scenarios:
    //
    //   • outgoing + media never connected  → "cancel"
    //     (caller hung up before callee answered — relay must propagate
    //     a hangup/cancel control to the callee or it keeps ringing)
    //   • incoming + never answered         → "decline"
    //     (user pressed Decline on the CallKit screen)
    //   • either + media connected/answered → "hangup"
    //     (normal mid-call end)
    let resolvedAction: String
    if context.wasAnswered || context.isConnected {
      resolvedAction = "hangup"
    } else if context.isOutgoing {
      resolvedAction = "cancel"
    } else {
      resolvedAction = "decline"
    }
    emit(action: resolvedAction, context: context)
    cleanup(callKey: Self.callKey(callId: context.callId, callAttemptId: context.callAttemptId))
    action.fulfill()
  }

  func provider(
    _ provider: CXProvider,
    didActivate audioSession: AVAudioSession
  ) {
    // CallKit hands us an already-activated session; we just need to configure
    // the category so WebRTC / flutter_webrtc gets proper echo-cancellation,
    // mic input, and Bluetooth routing.  Without this, some devices route audio
    // incorrectly or fail to activate the microphone after the call connects.
    //
    // PR-H+3 (2026-05-20): honour the persistent speakerOverrideEnabled flag
    // so that when CallKit re-activates the session mid-call (interruption
    // end, app foreground after PiP, etc.), the loudspeaker preference is
    // preserved instead of being reset to the earpiece.
    // Hand CallKit's already-activated session to WebRTC's RTCAudioSession
    // BEFORE enabling audio, so its manual-audio bookkeeping matches reality.
    let rtcSession = RTCAudioSession.sharedInstance()
    rtcSession.audioSessionDidActivate(audioSession)
    do {
      try audioSession.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: audioSessionCategoryOptions()
      )
      try audioSession.overrideOutputAudioPort(
        speakerOverrideEnabled ? .speaker : .none
      )
      os_log(
        "event=callkit.audio_session.activated speaker=%{public}@",
        log: slyDiagLog, type: .info,
        speakerOverrideEnabled ? "true" : "false"
      )
    } catch {
      os_log(
        "event=callkit.audio_session.activate_failed err=%{public}@",
        log: slyDiagLog, type: .error,
        error.localizedDescription
      )
    }
    // START the WebRTC audio unit now that CallKit's session is active. This is
    // the line that makes audio actually flow on a locked/killed-state answer.
    rtcSession.isAudioEnabled = true
  }

  func provider(
    _ provider: CXProvider,
    didDeactivate audioSession: AVAudioSession
  ) {
    // Stop WebRTC's audio unit + tell RTCAudioSession CallKit deactivated the
    // session, then release it so other apps (Music, Siri) can resume.
    let rtcSession = RTCAudioSession.sharedInstance()
    rtcSession.isAudioEnabled = false
    rtcSession.audioSessionDidDeactivate(audioSession)
    do {
      try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
      os_log("event=callkit.audio_session.deactivated", log: slyDiagLog, type: .info)
    } catch {
      os_log(
        "event=callkit.audio_session.deactivate_failed err=%{public}@",
        log: slyDiagLog, type: .error,
        error.localizedDescription
      )
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "showIncomingNative":
      guard let arguments = CallArguments(arguments: call.arguments) else {
        result(
          FlutterError(
            code: "bad_args",
            message: "callId is required",
            details: nil
          )
        )
        return
      }
      showIncoming(arguments: arguments, result: result)

    case "hideIncomingNative":
      guard let arguments = CallArguments(arguments: call.arguments) else {
        result(nil)
        return
      }
      hideIncoming(arguments: arguments)
      result(nil)

    case "startOutgoingNative":
      guard let arguments = CallArguments(arguments: call.arguments) else {
        result(
          FlutterError(
            code: "bad_args",
            message: "callId is required",
            details: nil
          )
        )
        return
      }
      startOutgoing(arguments: arguments, result: result)

    case "showOngoingCallNative":
      guard let arguments = CallArguments(arguments: call.arguments) else {
        result(nil)
        return
      }
      showOngoing(arguments: arguments)
      result(nil)

    case "hideOngoingCallNative":
      guard let arguments = CallArguments(arguments: call.arguments) else {
        result(nil)
        return
      }
      hideOngoing(arguments: arguments)
      result(nil)

    case "setRingtoneMode":
      do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
          .playback,
          mode: .default,
          options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP]
        )
        try session.setActive(true)
      } catch {
        os_log(
          "event=callkit.ringtone_audio_mode_failed err=%{public}@",
          log: slyDiagLog, type: .error,
          error.localizedDescription
        )
      }
      result(nil)

    // In-call speaker button = OUTPUT ROUTE ONLY (single-owner audio, redesign
    // 2026-07-09). Persist the preference into `speakerOverrideEnabled` (consumed
    // by didActivate + audioSessionCategoryOptions) and re-apply only the output
    // port. We do NOT setCategory/setActive/bounce the unit here — that is
    // CallKit didActivate's job, and doing it on the speaker toggle stopped the
    // audio unit and fed the route-observer loop.
    case "setSpeakerEnabled":
      let enabled: Bool
      if let args = call.arguments as? [String: Any],
         let value = args["enabled"] as? Bool {
        enabled = value
      } else if let value = call.arguments as? Bool {
        enabled = value
      } else {
        result(
          FlutterError(
            code: "bad_args",
            message: "setSpeakerEnabled requires a Bool",
            details: nil
          )
        )
        return
      }
      // SINGLE-OWNER audio (redesign 2026-07-09): the speaker toggle is OUTPUT
      // ROUTE ONLY. The category + activation + unit are owned by CallKit
      // `didActivate`; we must NOT setCategory / setActive / bounce the unit here.
      // The old churn tore down the didActivate-established session (→ no audio,
      // esp. on incoming where it hit right as the remote track attached) and its
      // routeChange notifications fed the observer loop (→ flickering speaker
      // button). `speakerOverrideEnabled` is persisted and consumed by
      // `audioSessionCategoryOptions()` + `didActivate`, so the preference sticks
      // even if the immediate override no-ops because the session isn't active yet.
      speakerOverrideEnabled = enabled
      reapplyCallOutputRoute()
      result(true)

    case "clearAudioMode":
      do {
        try AVAudioSession.sharedInstance().setActive(
          false,
          options: [.notifyOthersOnDeactivation]
        )
      } catch {
      }
      result(nil)

    case "setCallActive":
      let active = (call.arguments as? Bool) ?? false
      isCallActive = active
      result(nil)

    case "reassertCallAudio":
      // Called from Dart the moment the call reaches CONNECTED (ICE up, remote
      // audio track flowing). Restart the unit ONCE so it renders the freshly
      // attached remote track (incoming: the track arrives after didActivate
      // enabled the unit against no track). Safe now that the route observer
      // ignores the resulting routeChange — it can no longer loop.
      restartCallAudioUnit()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // Called directly from AppDelegate for VoIP push — bypasses the Flutter
  // method channel so the call UI appears even when the app is killed.
  // createdAtMs: signal creation timestamp from relay push payload (0 = unknown).
  //
  // PR-H 2026-05-20: CRITICAL — every code path here MUST end with a
  // `reportNewIncomingCall` invocation (directly or via `reportRejectedVoipPush`)
  // BEFORE the caller's completion handler runs. See Apple's PushKit
  // contract: silent rejection of a VoIP push → progressive token throttle
  // → token invalidation. Symptom in the field: «calls stopped arriving».
  func reportVoipIncomingCall(
    callId: String,
    callAttemptId: String,
    peerName: String,
    isVideo: Bool,
    createdAtMs: Int64 = 0
  ) {
    // Stale guard. We RAISED the window from 45 s to 60 s (Apple's APNs
    // SLA caps at ~30 s for high-priority pushes, so 60 s leaves 2× headroom
    // for genuine cell/WiFi handovers without trusting random clock skew).
    //
    // Additionally: if `ageMs` is *negative* (push is "from the future"),
    // the device clock and the relay clock disagree — distrust the
    // timestamp entirely rather than silently rejecting. Without this guard
    // a single NTP skew event would suppress every incoming call until the
    // device re-syncs.
    if createdAtMs > 0 {
      let ageMs = Int64(Date().timeIntervalSince1970 * 1000) - createdAtMs
      if ageMs > 60_000 {
        os_log(
          "event=voip_push.stale_reported_and_ended callId=%{public}@ ageMs=%ld",
          log: slyDiagLog, type: .info,
          String(callId.prefix(8)), ageMs
        )
        // Contract: still must report-then-end. Otherwise iOS throttles us.
        reportRejectedVoipPush(
          peerName: peerName.isEmpty ? "Secretly" : peerName,
          isVideo: isVideo,
          reason: "stale_age_\(ageMs)ms"
        )
        return
      } else if ageMs < -5_000 {
        // Wall-clock skew detected — log it but continue with normal
        // reporting (the call is presumably fresh).
        os_log(
          "event=voip_push.clock_skew_detected callId=%{public}@ ageMs=%ld",
          log: slyDiagLog, type: .info,
          String(callId.prefix(8)), ageMs
        )
      }
    }

    let rawArgs: [String: Any] = [
      "callId": callId,
      "callAttemptId": callAttemptId.isEmpty ? callId : callAttemptId,
      "peerName": peerName.isEmpty ? "Secretly" : peerName,
      "isVideo": isVideo,
    ]
    guard let args = CallArguments(arguments: rawArgs) else {
      // Even on parse failure: contract forces us to report. Use a synthetic
      // call that ends instantly so the user sees nothing but Apple is happy.
      reportRejectedVoipPush(
        peerName: peerName.isEmpty ? "Secretly" : peerName,
        isVideo: isVideo,
        reason: "args_parse_failed"
      )
      return
    }

    // Report to CallKit immediately (iOS requirement), then schedule a
    // short post-report window. Flutter will send hideIncomingNative if the
    // call was already terminated; otherwise CallKit stays open for the user.
    showIncoming(arguments: args) { _ in }
  }

  /// PR-H 2026-05-20: contract-compliant rejection helper for VoIP pushes
  /// that we want to drop (wrong type, stale, wrong wake_kind, parse error).
  ///
  /// Apple's PKPushRegistry contract requires `provider.reportNewIncomingCall`
  /// to be invoked synchronously inside the push handler — otherwise iOS
  /// throttles and ultimately invalidates the VoIP token. To honour the
  /// contract without showing a ghost ring, we:
  ///   1. Generate a brand-new UUID (no conflict with real calls).
  ///   2. Report a synthetic incoming call with a placeholder caller name.
  ///   3. In the completion callback (next runloop tick), end the call with
  ///      `.failed` so CallKit dismisses its UI before it ever paints.
  /// This pattern is used by Signal, Telegram, and Apple's own samples.
  func reportRejectedVoipPush(peerName: String, isVideo: Bool, reason: String) {
    let uuid = UUID()
    let update = CXCallUpdate()
    let safePeer = peerName.trimmingCharacters(in: .whitespacesAndNewlines)
    update.localizedCallerName = safePeer.isEmpty ? "Secretly" : safePeer
    update.remoteHandle = CXHandle(
      type: .generic,
      value: safePeer.isEmpty ? "Secretly" : safePeer
    )
    update.hasVideo = isVideo
    update.supportsDTMF = false
    update.supportsHolding = false
    update.supportsGrouping = false
    update.supportsUngrouping = false

    os_log(
      "event=voip_push.rejected_reported_then_ended reason=%{public}@",
      log: slyDiagLog, type: .info,
      reason
    )

    // Report first (Apple's contract), then end immediately. CallKit
    // collapses the UI before paint when end is reported synchronously.
    provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] _ in
      // Use `Date()` in the future by 0 s so CallKit logs it as a normal
      // end, not a hang-up; .failed signals "call did not connect" which
      // does NOT add an entry to recents (we set includesCallsInRecents=false
      // anyway, so this is belt-and-braces).
      self?.provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
    }
  }

  private func startOutgoing(arguments: CallArguments, result: @escaping FlutterResult) {
    let callKey = Self.callKey(callId: arguments.callId, callAttemptId: arguments.callAttemptId)
    if let existing = callsByKey[callKey], !existing.isEnded {
      existing.peerName = arguments.peerName
      existing.isVideo = arguments.isVideo
      provider.reportCall(with: existing.uuid, updated: callUpdate(for: existing))
      result(nil)
      return
    }

    endAllCalls(except: callKey, reason: .remoteEnded)

    let context = NativeCallContext(arguments: arguments, uuid: UUID())
    context.isOutgoing = true
    callsByKey[callKey] = context
    keyByUuid[context.uuid] = callKey

    let handle = CXHandle(type: .generic, value: context.peerName)
    let action = CXStartCallAction(call: context.uuid, handle: handle)
    action.isVideo = context.isVideo
    let transaction = CXTransaction(action: action)
    callController.request(transaction) { [weak self] error in
      DispatchQueue.main.async {
        if let error = error {
          self?.cleanup(callKey: callKey)
          result(
            FlutterError(
              code: "callkit_start_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }
        self?.provider.reportCall(with: context.uuid, updated: self?.callUpdate(for: context) ?? CXCallUpdate())
        result(nil)
      }
    }
  }

  private func showIncoming(arguments: CallArguments, result: @escaping FlutterResult) {
    let callKey = Self.callKey(callId: arguments.callId, callAttemptId: arguments.callAttemptId)
    if let existing = callsByKey[callKey], !existing.isEnded {
      existing.peerName = arguments.peerName
      existing.isVideo = arguments.isVideo
      provider.reportCall(with: existing.uuid, updated: callUpdate(for: existing))
      result(nil)
      return
    }

    endAllCalls(except: callKey, reason: .remoteEnded)

    let context = NativeCallContext(arguments: arguments, uuid: UUID())
    callsByKey[callKey] = context
    keyByUuid[context.uuid] = callKey
    provider.reportNewIncomingCall(with: context.uuid, update: callUpdate(for: context)) { [weak self] error in
      if error != nil {
        self?.cleanup(callKey: callKey)
      }
      result(
        error == nil
          ? nil
          : FlutterError(
              code: "callkit_show_failed",
              message: error?.localizedDescription ?? "Failed to show incoming call",
              details: nil
            )
      )
    }
  }

  private func hideIncoming(arguments: CallArguments) {
    let callKey = Self.callKey(callId: arguments.callId, callAttemptId: arguments.callAttemptId)
    guard let context = callsByKey[callKey], !context.isEnded else {
      return
    }
    if context.wasAnswered || context.isConnected {
      return
    }
    end(callKey: callKey, reason: .remoteEnded)
  }

  private func showOngoing(arguments: CallArguments) {
    let callKey = Self.callKey(callId: arguments.callId, callAttemptId: arguments.callAttemptId)
    guard let context = callsByKey[callKey], !context.isEnded else {
      return
    }
    context.peerName = arguments.peerName
    context.isVideo = arguments.isVideo
    context.wasAnswered = true
    context.isConnected = true
    provider.reportCall(with: context.uuid, updated: callUpdate(for: context))
    if context.isOutgoing {
      provider.reportOutgoingCall(with: context.uuid, connectedAt: Date())
    }
  }

  private func hideOngoing(arguments: CallArguments) {
    let callKey = Self.callKey(callId: arguments.callId, callAttemptId: arguments.callAttemptId)
    end(callKey: callKey, reason: .remoteEnded)
  }

  private func context(for uuid: UUID) -> NativeCallContext? {
    guard let callKey = keyByUuid[uuid] else {
      return nil
    }
    return callsByKey[callKey]
  }

  private func callUpdate(for context: NativeCallContext) -> CXCallUpdate {
    let update = CXCallUpdate()
    update.localizedCallerName = context.peerName
    update.remoteHandle = CXHandle(type: .generic, value: context.peerName)
    update.hasVideo = context.isVideo
    update.supportsDTMF = false
    update.supportsHolding = false
    update.supportsGrouping = false
    update.supportsUngrouping = false
    return update
  }

  private func end(callKey: String, reason: CXCallEndedReason) {
    guard let context = callsByKey[callKey], !context.isEnded else {
      return
    }
    context.isEnded = true
    provider.reportCall(with: context.uuid, endedAt: Date(), reason: reason)
    cleanup(callKey: callKey)
  }

  private func endAllCalls(except exemptCallKey: String, reason: CXCallEndedReason) {
    let keysToEnd = callsByKey.keys.filter { $0 != exemptCallKey }
    for callKey in keysToEnd {
      end(callKey: callKey, reason: reason)
    }
  }

  // Bug: if the app is force-killed (or "clear from recents") while a call
  // was ringing/active, CallKit's OWN call registry survives the process
  // death — it's owned by the OS, not by `callsByKey` (a plain in-memory
  // dict that's always empty on a fresh launch and can't reflect anything
  // from a previous run). On relaunch this stale registration can resurface
  // as an unanswerable "incoming call" UI with no live Dart-side session
  // behind it. CXCallObserver reflects the OS's real, current call list
  // regardless of which process instance originally reported them, so this
  // runs once at init and ends anything already there before we report any
  // new call of our own.
  private func clearStaleCallKitState() {
    let staleCalls = CXCallObserver().calls
    guard !staleCalls.isEmpty else { return }
    for call in staleCalls {
      provider.reportCall(with: call.uuid, endedAt: Date(), reason: .failed)
    }
  }

  private func cleanup(callKey: String) {
    guard let context = callsByKey.removeValue(forKey: callKey) else {
      return
    }
    keyByUuid.removeValue(forKey: context.uuid)
    // Reset once no calls remain: speaker preference (so the NEXT call starts at
    // the earpiece; Flutter re-sets speaker for a video call), AND `isCallActive`
    // — the master gate for all three audio observers. Previously only Dart's
    // `setCallActive(false)` disarmed them, so a missed/late disarm left the route
    // observer live after the call and a post-call route change re-activated a
    // call audio session (redesign 2026-07-09, docs/CALL_AUDIT_2026-07-09.md).
    if callsByKey.isEmpty {
      speakerOverrideEnabled = false
      isCallActive = false
    }
  }

  private func emit(action: String, context: NativeCallContext) {
    let payload: [String: Any] = [
      "action": action,
      "callId": context.callId,
      "callAttemptId": context.callAttemptId,
    ]
    if let eventSink {
      eventSink(payload)
      return
    }
    pendingEvents.append(payload)
    if pendingEvents.count > 12 {
      pendingEvents.removeFirst(pendingEvents.count - 12)
    }
  }

  private func flushPendingEvents() {
    guard let eventSink, !pendingEvents.isEmpty else {
      return
    }
    let buffered = pendingEvents
    pendingEvents.removeAll(keepingCapacity: true)
    for payload in buffered {
      eventSink(payload)
    }
  }

  private static func callKey(callId: String, callAttemptId: String) -> String {
    let normalizedCallId = callId.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedAttemptId = callAttemptId.trimmingCharacters(in: .whitespacesAndNewlines)
    let effectiveAttemptId = normalizedAttemptId.isEmpty ? normalizedCallId : normalizedAttemptId
    return normalizedCallId + "::" + effectiveAttemptId
  }
}

/// FlutterViewController whose status-bar style follows the IN-APP theme pushed
/// from Dart — NOT the iOS system appearance. Without this, iOS ignores Flutter's
/// `SystemUiOverlayStyle` in some configs (e.g. the phone is in system-DARK mode
/// but the user picked the app's in-app LIGHT theme → a white status bar on a
/// light screen). Dart sends the value over the `secretly/system_ui`
/// `setLightStatusBar` channel (the same one Android uses). `light == true` ⇒
/// light bars ⇒ DARK status text (correct for the app's light theme); `false` ⇒
/// light/white status text for the dark theme. Updates live on theme switch.
class StatusBarFlutterViewController: FlutterViewController {
  private var lightStatusBar = true {
    didSet {
      if oldValue != lightStatusBar {
        setNeedsStatusBarAppearanceUpdate()
      }
    }
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    if #available(iOS 13.0, *) {
      return lightStatusBar ? .darkContent : .lightContent
    }
    return lightStatusBar ? .default : .lightContent
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    let channel = FlutterMethodChannel(
      name: "secretly/system_ui",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setLightStatusBar" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if let args = call.arguments as? [String: Any],
        let light = args["light"] as? Bool
      {
        self?.lightStatusBar = light
      }
      result(nil)
    }
  }
}

/// Название и исполнитель песни — системным разбором (AVFoundation).
enum SecretlyMusicTags {
  /// `["title": …, "artist": …]` — или `nil`, если система тегов не нашла.
  static func read(path: String) async -> [String: String]? {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let items = try? await asset.load(.commonMetadata) else { return nil }
    var out: [String: String] = [:]
    if let title = await firstString(in: items, id: .commonIdentifierTitle) {
      out["title"] = title
    }
    if let artist = await firstString(in: items, id: .commonIdentifierArtist) {
      out["artist"] = artist
    }
    return out.isEmpty ? nil : out
  }

  private static func firstString(
    in items: [AVMetadataItem],
    id: AVMetadataIdentifier
  ) async -> String? {
    for item in AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id) {
      guard let value = try? await item.load(.stringValue) else { continue }
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    return nil
  }
}
