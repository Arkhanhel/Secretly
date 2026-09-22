import AVFoundation
import Cocoa
import FlutterMacOS
import ImageIO
import UniformTypeIdentifiers

class MainFlutterWindow: NSWindow {
  // Strong ref so the bridge outlives `awakeFromNib`; the window itself is
  // long-lived, so this keeps the EventChannel handler attached for the life
  // of the app.
  private let powerStateBridge = PowerStateBridge()

  /// Перевод сообщений на самом компьютере — см. `TranslationBridge.swift`.
  private let translationBridge = TranslationBridge()

  /// Подготовка снимков к отправке — см. [ImagePrepBridge].
  private let imagePrepBridge = ImagePrepBridge()

  /// Теги песни, когда их не прочла библиотека, — см. [MusicTagsBridge].
  private let musicTagsBridge = MusicTagsBridge()

  /// Показ PDF внутри окна — см. [PdfRenderBridge].
  private let pdfRenderBridge = PdfRenderBridge()

  /// Обновление приложения, скачанного с сайта, — см. [SparkleBridge].
  private let sparkleBridge = SparkleBridge()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Wake-event bridge (Sprint 2 / PR2, TZ §21.x):
    // macOS suspends background activity when the system sleeps or the lid is
    // closed. When the OS resumes, our WebSocket has typically been silently
    // dropped by the network stack, but Flutter's connectivity_plus stream
    // doesn't fire on sleep/wake transitions, so the relay socket stays
    // half-open until the next heartbeat times out. This bridge forwards
    // `NSWorkspace.didWakeNotification` (and willSleep, for diagnostics) to
    // the Flutter side over the `secretly/power_state` EventChannel so
    // AppController can force-reconnect immediately on wake.
    powerStateBridge.attach(to: flutterViewController.engine.binaryMessenger)
    translationBridge.attach(to: flutterViewController.engine.binaryMessenger)
    imagePrepBridge.attach(to: flutterViewController.engine.binaryMessenger)
    musicTagsBridge.attach(to: flutterViewController.engine.binaryMessenger)
    pdfRenderBridge.attach(to: flutterViewController.engine.binaryMessenger)
    sparkleBridge.attach(to: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// Bridges macOS sleep/wake notifications into Flutter via an EventChannel.
///
/// Emits dicts like `{"event": "wake", "ts_ms": 1700000000000}` on
/// `NSWorkspace.didWakeNotification` and `{"event": "sleep", ...}` on
/// `NSWorkspace.willSleepNotification`. The Flutter side debounces and turns
/// `wake` events into an urgent relay reconnect.
private final class PowerStateBridge: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var observers: [NSObjectProtocol] = []

  func attach(to messenger: FlutterBinaryMessenger) {
    let eventChannel = FlutterEventChannel(
      name: "secretly/power_state",
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(self)
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    startObserving()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopObserving()
    eventSink = nil
    return nil
  }

  private func startObserving() {
    stopObserving()
    let center = NSWorkspace.shared.notificationCenter
    let wakeObs = center.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.emit(event: "wake")
    }
    let sleepObs = center.addObserver(
      forName: NSWorkspace.willSleepNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.emit(event: "sleep")
    }
    let screenWakeObs = center.addObserver(
      forName: NSWorkspace.screensDidWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.emit(event: "screen_wake")
    }
    observers = [wakeObs, sleepObs, screenWakeObs]
  }

  private func stopObserving() {
    let center = NSWorkspace.shared.notificationCenter
    for obs in observers {
      center.removeObserver(obs)
    }
    observers.removeAll()
  }

  private func emit(event: String) {
    let payload: [String: Any] = [
      "event": event,
      "ts_ms": Int(Date().timeIntervalSince1970 * 1000),
    ]
    // Notifications are already delivered on the main queue (we registered
    // with `.main`), but keep an explicit dispatch in case Apple ever
    // changes that contract.
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(payload)
    }
  }

  deinit {
    stopObserving()
  }
}

/// Подготовка снимка к отправке средствами самой macOS (ImageIO).
///
/// 🔴 ЗАЧЕМ (16.09.2026). Снимки с iPhone приходят на Mac по AirDrop в HEIC, а
/// движок Flutter на маке HEIC не читает: окно отправки показало бы пустую
/// плитку, а получатель на Android или на компьютере — неоткрывающийся
/// «снимок». Telegram поступает так же, как здесь: «как фото» уходит JPEG не
/// больше 2560 точек по длинной стороне.
///
/// Заодно:
///   • поворот из EXIF впекается в пиксели — снимок у всех стоит прямо;
///   • метаданные (геометка, модель камеры) в новый файл НЕ попадают вовсе;
///   • снимок с прозрачностью остаётся PNG — в JPEG прозрачное стало бы
///     чёрным.
///
/// Всё считается здесь же, на компьютере; наружу ничего не уходит.
private final class ImagePrepBridge {
  private var channel: FlutterMethodChannel?
  private let queue = DispatchQueue(
    label: "secretly.image_prep",
    qos: .userInitiated
  )

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "secretly/image_prep",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "transcode":
        guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          let outPath = args["outPath"] as? String
        else {
          result(FlutterError(code: "bad_args", message: nil, details: nil))
          return
        }
        let maxSide = (args["maxSide"] as? NSNumber)?.intValue ?? 2560
        let quality = (args["quality"] as? NSNumber)?.doubleValue ?? 0.87
        self.queue.async {
          let out = ImagePrepBridge.transcode(
            path: path,
            outPath: outPath,
            maxSide: maxSide,
            quality: quality
          )
          DispatchQueue.main.async { result(out) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// `{path, width, height, mime}` — или `nil`, если система снимок не
  /// прочла.
  private static func transcode(
    path: String,
    outPath: String,
    maxSide: Int,
    quality: Double
  ) -> [String: Any]? {
    let url = URL(fileURLWithPath: path)
    guard
      let source = CGImageSourceCreateWithURL(
        url as CFURL,
        [kCGImageSourceShouldCache: false] as CFDictionary
      ),
      CGImageSourceGetCount(source) > 0
    else { return nil }
    // У HEIC бывает несколько картинок (серия, живое фото) — берём главную.
    let index = CGImageSourceGetPrimaryImageIndex(source)
    let props =
      CGImageSourceCopyPropertiesAtIndex(source, index, nil)
      as? [CFString: Any] ?? [:]
    let pixelWidth = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
    let pixelHeight = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
    let hasAlpha = (props[kCGImagePropertyHasAlpha] as? Bool) ?? false
    let longest = max(pixelWidth, pixelHeight)
    let target = longest > 0 ? min(maxSide, longest) : maxSide
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: target,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard
      let image = CGImageSourceCreateThumbnailAtIndex(
        source,
        index,
        options as CFDictionary
      )
    else { return nil }
    let type = (hasAlpha ? UTType.png : UTType.jpeg).identifier as CFString
    let outURL = URL(fileURLWithPath: outPath)
    try? FileManager.default.removeItem(at: outURL)
    guard
      let destination = CGImageDestinationCreateWithURL(
        outURL as CFURL,
        type,
        1,
        nil
      )
    else { return nil }
    var destinationProps: [CFString: Any] = [:]
    if !hasAlpha {
      destinationProps[kCGImageDestinationLossyCompressionQuality] = quality
    }
    CGImageDestinationAddImage(
      destination,
      image,
      destinationProps as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else { return nil }
    return [
      "path": outPath,
      "width": image.width,
      "height": image.height,
      "mime": hasAlpha ? "image/png" : "image/jpeg",
    ]
  }
}

/// Название и исполнитель песни — системным разбором (AVFoundation).
///
/// Запасной путь для библиотеки тегов (Rust): она не видит M4A, у которого
/// служебный блок `moov` стоит после данных (так по умолчанию пишет, например,
/// ffmpeg), и такие песни уходили без названия и исполнителя. Разбор чужого
/// файла остаётся в системном компоненте. Dart: `lib/media/music_tags.dart`.
private final class MusicTagsBridge {
  private var channel: FlutterMethodChannel?

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "secretly/music_tags",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "read" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
        let path = args["path"] as? String, !path.isEmpty
      else {
        result(FlutterError(code: "bad_args", message: nil, details: nil))
        return
      }
      Task {
        let tags = await MusicTagsBridge.read(path: path)
        DispatchQueue.main.async { result(tags) }
      }
    }
  }

  /// `["title": …, "artist": …]` — или `nil`, если система тегов не нашла.
  static func read(path: String) async -> [String: String]? {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let items: [AVMetadataItem]
    if #available(macOS 12.0, *) {
      guard let loaded = try? await asset.load(.commonMetadata) else { return nil }
      items = loaded
    } else {
      items = asset.commonMetadata
    }
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
      let value: String?
      if #available(macOS 12.0, *) {
        value = try? await item.load(.stringValue)
      } else {
        value = item.stringValue
      }
      guard let value else { continue }
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    return nil
  }
}
