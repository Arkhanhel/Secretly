import AVFoundation
import Cocoa
import CoreAudio
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

  /// Запуск при входе в систему — см. [LoginItemBridge].
  private let loginItemBridge = LoginItemBridge()

  /// Число непрочитанных на значке в Dock — см. [DockBadgeBridge].
  private let dockBadgeBridge = DockBadgeBridge()

  /// Общесистемное «показать Secretly» — см. [GlobalHotKeyBridge].
  private let globalHotKeyBridge = GlobalHotKeyBridge()

  /// Отдельные окна (звонок) на том же движке — см. [ChildWindowBridge].
  private let childWindowBridge = ChildWindowBridge()

  /// Проверочный звук настроек звонков в выбранных динамиках — см.
  /// [AudioTestBridge].
  private let audioTestBridge = AudioTestBridge()

  /// Счётчик изменений буфера обмена для сторожа секретов — см.
  /// [ClipboardGuardBridge].
  private let clipboardGuardBridge = ClipboardGuardBridge()

  /// Защита окон от снимков и записи экрана — см. [ScreenPrivacyBridge].
  private let screenPrivacyBridge = ScreenPrivacyBridge()

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
    loginItemBridge.attach(to: flutterViewController.engine.binaryMessenger)
    dockBadgeBridge.attach(to: flutterViewController.engine.binaryMessenger)
    globalHotKeyBridge.attach(to: flutterViewController.engine.binaryMessenger)
    childWindowBridge.attach(engine: flutterViewController.engine, mainWindow: self)
    audioTestBridge.attach(to: flutterViewController.engine.binaryMessenger)
    clipboardGuardBridge.attach(to: flutterViewController.engine.binaryMessenger)
    screenPrivacyBridge.attach(to: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// «Защита от снимков экрана» на Mac (01.10.2026) — тот же канал
/// `secretly/screen_privacy`, что у телефона: контроллер зовёт его при запуске
/// и при переключении настройки, и до сих пор на компьютере ему никто не
/// отвечал, поэтому переключателя здесь не было вовсе.
///
/// `sharingType = .none` просит систему не отдавать содержимое окна снимкам,
/// записи и демонстрации экрана — в том числе нашей же демонстрации в звонке.
/// 🔴 ЭТО ПРОСЬБА, А НЕ ЗАМОК: не все способы захвата её соблюдают (новые
/// версии macOS и часть программ записи), и текст настройки говорит это прямо.
///
/// Применяется ко ВСЕМ окнам программы — главному и отдельным (звонок,
/// окошки уведомлений); окна, открытые позже, получают то же при создании
/// ([ChildWindowBridge]) и при первом становлении ключевыми.
final class ScreenPrivacyBridge {
  /// Текущее состояние — чтобы новые окна рождались уже защищёнными.
  static private(set) var enabled = false

  private var channel: FlutterMethodChannel?
  private var keyObserver: NSObjectProtocol?

  static func apply(to window: NSWindow) {
    window.sharingType = enabled ? .none : .readOnly
  }

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "secretly/screen_privacy",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setEnabled":
        let on = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
        self?.setEnabled(on)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    // Окно, созданное мимо моста отдельных окон, защищается, как только
    // становится ключевым: без этого оно осталось бы видимым для записи.
    keyObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didBecomeKeyNotification,
      object: nil,
      queue: .main
    ) { note in
      guard ScreenPrivacyBridge.enabled, let w = note.object as? NSWindow else { return }
      ScreenPrivacyBridge.apply(to: w)
    }
  }

  private func setEnabled(_ on: Bool) {
    ScreenPrivacyBridge.enabled = on
    for w in NSApp.windows {
      ScreenPrivacyBridge.apply(to: w)
    }
  }
}

/// Счётчик изменений буфера обмена — для `DesktopClipboardGuard` (01.10.2026).
///
/// 🔴 ТОЛЬКО СЧЁТЧИК, НЕ СОДЕРЖИМОЕ. Сторож стирает набор восстановления из
/// буфера, если он там ещё лежит. Узнавать «ещё лежит» чтением значило бы
/// читать и чужое — а macOS с 15.4 спрашивает разрешение, когда программа
/// сама читает буфер, записанный другой программой. `changeCount` ничего не
/// раскрывает и ни о чём не спрашивает: если он не сдвинулся с нашего
/// копирования, в буфере всё ещё наш текст.
private final class ClipboardGuardBridge {
  private var channel: FlutterMethodChannel?

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "secretly/clipboard_guard",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "changeCount":
        result(NSPasteboard.general.changeCount)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
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

/// 🔴 Отдельные окна ОС на ТОМ ЖЕ движке (29.09.2026, Р1) — см.
/// `lib/ui/desktop/services/desktop_child_windows.dart`.
///
/// Второе окно — ещё один `FlutterViewController(engine:)`: тот же изолят,
/// общий реестр текстур, видео звонка рисуется без переноса.
///
/// Мультивид движок macOS 3.41 разрешает включить только ДО первого окна
/// (`-[FlutterEngine enableMultiView]` проверяет это `NSAssert`, и
/// экспериментальный API окон Flutter на этом падает). Главное окно у нас уже
/// есть, а флаг `_multiViewEnabled` движок читает лишь при добавлении нового
/// контроллера (`addViewController`/`registerViewController`) — поэтому ставим
/// его напрямую в поле. Нет такого поля (другая версия движка) — окон нет, и
/// звонок остаётся в главном окне.
private final class ChildWindowBridge: NSObject, NSWindowDelegate {
  private var channel: FlutterMethodChannel?
  private weak var engine: FlutterEngine?
  private weak var mainWindow: NSWindow?
  private var windows: [String: NSWindow] = [:]
  private var controllers: [String: FlutterViewController] = [:]
  /// «Поверх всех» по окнам: полноэкранный режим его снимает, выход — возвращает.
  private var pinned: [String: Bool] = [:]

  func attach(engine: FlutterEngine, mainWindow: NSWindow) {
    self.engine = engine
    self.mainWindow = mainWindow
    let channel = FlutterMethodChannel(
      name: "secretly/child_window",
      binaryMessenger: engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
  }

  private func multiViewIvar() -> (Ivar, String)? {
    guard let ivar = class_getInstanceVariable(FlutterEngine.self, "_multiViewEnabled"),
      let raw = ivar_getTypeEncoding(ivar)
    else { return nil }
    let encoding = String(cString: raw)
    guard encoding == "B" || encoding == "c" else { return nil }
    return (ivar, encoding)
  }

  private func ensureMultiView(_ engine: FlutterEngine) -> Bool {
    guard let (ivar, encoding) = multiViewIvar() else { return false }
    let field = Unmanaged.passUnretained(engine).toOpaque()
      .advanced(by: ivar_getOffset(ivar))
    if encoding == "B" {
      field.assumingMemoryBound(to: Bool.self).pointee = true
    } else {
      field.assumingMemoryBound(to: Int8.self).pointee = 1
    }
    return true
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "isSupported" {
      result(multiViewIvar() != nil)
      return
    }
    guard let args = call.arguments as? [String: Any],
      let id = args["id"] as? String, !id.isEmpty
    else {
      result(FlutterError(code: "bad_args", message: "id is required", details: nil))
      return
    }
    func number(_ key: String, _ fallback: Double) -> Double {
      (args[key] as? NSNumber)?.doubleValue ?? fallback
    }
    switch call.method {
    case "open":
      if let existing = windows[id], let controller = controllers[id] {
        NSApp.activate(ignoringOtherApps: true)
        existing.makeKeyAndOrderFront(nil)
        result(NSNumber(value: controller.viewIdentifier))
        return
      }
      guard let engine = engine, ensureMultiView(engine) else {
        result(FlutterError(code: "unsupported", message: "multi-view is unavailable", details: nil))
        return
      }
      let width = number("width", 420)
      let height = number("height", 640)
      let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
      // Наведение — и в окне без фокуса: закреплённое поверх всех окно
      // звонка показывает кнопки по наведению, пока человек работает в другой
      // программе. По умолчанию движок слушает мышь только в ключевом окне.
      controller.mouseTrackingMode = .always
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
      )
      window.isReleasedWhenClosed = false
      window.contentViewController = controller
      window.setContentSize(NSSize(width: width, height: height))
      window.contentMinSize = NSSize(
        width: number("minWidth", 320),
        height: number("minHeight", 240)
      )
      window.title = (args["title"] as? String) ?? ""
      // Окно звонка тёмное при любой теме системы.
      window.appearance = NSAppearance(named: .darkAqua)
      window.delegate = self
      // Защита от снимков экрана включена — новое окно рождается защищённым.
      ScreenPrivacyBridge.apply(to: window)
      if let main = mainWindow, main.isVisible, !main.isMiniaturized {
        let frame = main.frame
        window.setFrameOrigin(
          NSPoint(
            x: frame.midX - window.frame.width / 2,
            y: frame.midY - window.frame.height / 2
          ))
      } else {
        window.center()
      }
      pinned[id] = (args["topmost"] as? Bool) ?? false
      applyTopmost(window, pinned[id] ?? false)
      windows[id] = window
      controllers[id] = controller
      // Показывает окно `show` из Dart после первого кадра.
      result(NSNumber(value: controller.viewIdentifier))
    case "close":
      if let window = windows.removeValue(forKey: id) {
        window.delegate = nil
        window.orderOut(nil)
        window.contentViewController = nil
        window.close()
      }
      // Последняя сильная ссылка: контроллер сам снимет вид с движка.
      controllers.removeValue(forKey: id)
      pinned.removeValue(forKey: id)
      result(nil)
    default:
      guard let window = windows[id] else {
        result(FlutterError(code: "no_window", message: "no window with this id", details: nil))
        return
      }
      switch call.method {
      case "show", "focus":
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
      case "setTopmost":
        pinned[id] = (args["on"] as? Bool) ?? false
        if !window.styleMask.contains(.fullScreen) {
          applyTopmost(window, pinned[id] ?? false)
        }
      case "setFullScreen":
        let on = (args["on"] as? Bool) ?? false
        if on != window.styleMask.contains(.fullScreen) {
          if on {
            // Полноэкранным бывает только «главное» окно стола: закрепление
            // (`.fullScreenAuxiliary`) на время снимаем.
            window.level = .normal
            window.collectionBehavior = [.fullScreenPrimary]
          }
          window.toggleFullScreen(nil)
        }
      case "minimize":
        window.miniaturize(nil)
      case "setTitle":
        window.title = (args["title"] as? String) ?? ""
      case "setSize":
        // Наименьший — от нового вида окна: иначе разговор ужимался до
        // размера входящего.
        if let minWidth = args["minWidth"] as? NSNumber,
          let minHeight = args["minHeight"] as? NSNumber
        {
          window.contentMinSize = NSSize(
            width: minWidth.doubleValue,
            height: minHeight.doubleValue
          )
        }
        resize(window, content: NSSize(width: number("width", 420), height: number("height", 640)))
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      result(nil)
    }
  }

  /// 🔴 Окно растёт от СЕРЕДИНЫ и не выходит за видимую часть экрана
  /// (29.09.2026, разбор Р1). `setContentSize` держал на месте левый верхний
  /// угол: входящий у края экрана после «Принять» уводил кнопки разговора
  /// под Dock или за край.
  private func resize(_ window: NSWindow, content: NSSize) {
    // Во весь экран размер задаёт система.
    if window.styleMask.contains(.fullScreen) { return }
    let old = window.frame
    var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: content))
    frame.origin = NSPoint(x: old.midX - frame.width / 2, y: old.midY - frame.height / 2)
    if let visible = (window.screen ?? NSScreen.main)?.visibleFrame {
      frame.size.width = min(frame.width, visible.width)
      frame.size.height = min(frame.height, visible.height)
      frame.origin.x = max(visible.minX, min(frame.origin.x, visible.maxX - frame.width))
      frame.origin.y = max(visible.minY, min(frame.origin.y, visible.maxY - frame.height))
    }
    window.setFrame(frame, display: true)
  }

  /// «Поверх всех окон»: и над полноэкранными программами других столов.
  private func applyTopmost(_ window: NSWindow, _ on: Bool) {
    window.level = on ? .floating : .normal
    window.collectionBehavior = on ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
  }

  func windowDidExitFullScreen(_ notification: Notification) {
    guard let window = notification.object as? NSWindow,
      let id = windows.first(where: { $0.value === window })?.key
    else { return }
    applyTopmost(window, pinned[id] ?? false)
  }

  /// Крестик окна: решает Dart (звонок может спросить, завершить ли его).
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if let id = windows.first(where: { $0.value === sender })?.key {
      channel?.invokeMethod("closeRequested", arguments: ["id": id])
      return false
    }
    return true
  }
}

/// Проверки звука из настроек звонков — в ВЫБРАННОМ устройстве вывода
/// (30.09.2026). Dart: `lib/ui/desktop/services/desktop_audio_output.dart`.
///
/// Проигрыватель приложения (`just_audio`) выбирать устройство не умеет, а
/// проверка динамиков, которая звучит «куда придётся», хуже её отсутствия:
/// человек выбрал наушники, услышал звук из колонок и решил, что выбор
/// работает. `AVAudioPlayer.currentDevice` принимает UID устройства
/// Core Audio — тот же, что модуль звука звонков отдаёт в списке устройств.
/// Устройство не нашлось — звучим в системном и отвечаем `targeted: false`,
/// чтобы интерфейс сказал об этом прямо.
private final class AudioTestBridge {
  private var channel: FlutterMethodChannel?
  private var player: AVAudioPlayer?

  /// Элемент «главный» свойств Core Audio. Имя `...ElementMain` появилось
  /// только в macOS 12, а приложение собирается под 11; значение то же — 0.
  private static let mainElement: AudioObjectPropertyElement = 0

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "secretly/audio_test",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "play":
        self.play(call.arguments, result)
      case "stop":
        self.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// `["targeted": Bool, "durationMs": Int]` — или ошибка, и тогда Dart
  /// проиграет сам в системном устройстве.
  private func play(_ arguments: Any?, _ result: FlutterResult) {
    guard let args = arguments as? [String: Any],
      let wav = args["wav"] as? FlutterStandardTypedData
    else {
      result(FlutterError(code: "bad_args", message: "wav is required", details: nil))
      return
    }
    stop()
    let wanted = (args["deviceId"] as? String) ?? ""
    let label = (args["label"] as? String) ?? ""
    do {
      let player = try AVAudioPlayer(data: wav.data)
      var targeted = true
      if !AudioTestBridge.isSystemDefault(wanted) {
        if let uid = AudioTestBridge.outputUID(for: wanted, label: label) {
          player.currentDevice = uid
          // Система могла не принять устройство (его отключили мгновение
          // назад) — тогда звук пойдёт в системное, и мы так и скажем.
          targeted = player.currentDevice == uid
        } else {
          targeted = false
        }
      }
      player.prepareToPlay()
      guard player.play() else {
        result(FlutterError(code: "play_failed", message: nil, details: nil))
        return
      }
      self.player = player
      result([
        "targeted": targeted,
        "durationMs": Int((player.duration * 1000).rounded()),
      ])
    } catch {
      result(FlutterError(code: "play_failed", message: "\(error)", details: nil))
    }
  }

  private func stop() {
    player?.stop()
    player = nil
  }

  /// «Как в системе»: пусто или служебный пункт модуля звука «default».
  static func isSystemDefault(_ id: String) -> Bool {
    let trimmed = id.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty || trimmed.lowercased() == "default"
  }

  /// UID устройства вывода для идентификатора из списка звонков.
  ///
  /// Модуль звука WebRTC отдаёт UID Core Audio; на случай другой формы
  /// принимаем и числовой AudioDeviceID, а последним — имя устройства.
  static func outputUID(for id: String, label: String) -> String? {
    let wanted = id.trimmingCharacters(in: .whitespaces)
    let name = label.trimmingCharacters(in: .whitespaces)
    let number = UInt32(wanted)
    var byName: String?
    for device in outputDevices() {
      if device.uid == wanted { return device.uid }
      if let number, number == device.id { return device.uid }
      if byName == nil, !name.isEmpty, device.name == name { byName = device.uid }
    }
    return byName
  }

  private static func outputDevices() -> [(id: AudioDeviceID, uid: String, name: String)] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: mainElement
    )
    var size: UInt32 = 0
    let system = AudioObjectID(kAudioObjectSystemObject)
    guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else {
      return []
    }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else {
      return []
    }
    var out: [(id: AudioDeviceID, uid: String, name: String)] = []
    for id in ids where hasOutput(id) {
      guard let uid = stringProperty(id, kAudioDevicePropertyDeviceUID) else { continue }
      out.append((id: id, uid: uid, name: stringProperty(id, kAudioObjectPropertyName) ?? ""))
    }
    return out
  }

  private static func hasOutput(_ id: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreams,
      mScope: kAudioObjectPropertyScopeOutput,
      mElement: mainElement
    )
    var size: UInt32 = 0
    return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
  }

  private static func stringProperty(
    _ id: AudioDeviceID,
    _ selector: AudioObjectPropertySelector
  ) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: mainElement
    )
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr,
      let string = value?.takeRetainedValue()
    else { return nil }
    return string as String
  }
}
