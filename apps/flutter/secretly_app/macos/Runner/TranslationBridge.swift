import Cocoa
import FlutterMacOS
import NaturalLanguage
import Translation

/// Перевод сообщений НА САМОМ КОМПЬЮТЕРЕ — через системный переводчик macOS.
///
/// 🔴 ПОЧЕМУ НЕ ТАК, КАК НА ТЕЛЕФОНЕ. Телефон переводит через Google ML Kit
/// (`lib/translation/translation_service.dart`), и там же записано главное
/// правило: «текст сообщения НИКОГДА не покидает устройство — это то же
/// обещание, что и сквозное шифрование, никакого облачного переводчика».
/// Плагины ML Kit собраны только под Android и iOS: в `pubspec.yaml` у них
/// объявлены ровно эти две платформы, и на маке вызов ушёл бы в пустоту.
///
/// 🔴 И ТЕМ БОЛЕЕ НЕ ЧЕРЕЗ ОБЛАКО. Отправить расшифрованный текст чужому
/// переводчику значило бы отдать наружу ровно то, что приложение обещает не
/// отдавать. Такой «перевод» был бы не функцией, а дырой.
///
/// Остаётся системный переводчик Apple. Он считает на устройстве, моделями,
/// которые человек уже скачал себе в настройках.
///
/// 🔴 БЕЗ SwiftUI. До macOS 26 сессию перевода можно было получить только из
/// SwiftUI-представления (`.translationTask`), и городить невидимое
/// представление внутри окна Flutter было бы хрупко. В macOS 26 появился
/// `TranslationSession(installedSource:target:)` — прямой вход, без вида.
/// Поэтому перевод здесь требует macOS 26; на более старых система честно
/// отвечает `unsupported`, и пункт меню не показывается вовсе.
///
/// 🔴 МОДЕЛИ НЕ КАЧАЕМ САМИ. Скачивание у Apple показывает системное окно и
/// возможно только из SwiftUI-сессии. Поэтому при отсутствующей модели
/// возвращаем `needs_download` и говорим человеку, где её взять, — это
/// честнее, чем крутить ожидание, которое ничем не кончится.
/// 🔴 У КАЖДОГО ОБРАЩЕНИЯ К СИСТЕМЕ ЕСТЬ СРОК.
///
/// Проверено 16.09.2026: `LanguageAvailability.status` МОЖЕТ не ответить
/// вовсе — отдельная программа и программа в бандле ждали его больше минуты и
/// не дождались (служба `translationd` при этом была запущена). Отчего именно
/// зависит ответ — от заблокированного экрана, от несобранных настроек
/// перевода — снаружи не видно.
///
/// Вывод для кода один: ждать бесконечно нельзя. Без срока нажатие
/// «Перевести» повисало бы навсегда, не показывая НИ перевода, НИ отказа, —
/// то есть выглядело бы поломкой окна, а не молчанием системной службы.
@available(macOS 15.0, *)
private func withDeadline<T: Sendable>(
  seconds: Double,
  operation: @escaping @Sendable () async -> T
) async -> T? {
  await withTaskGroup(of: T?.self) { group in
    group.addTask { await operation() }
    group.addTask {
      try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
      return nil
    }
    let first = await group.next() ?? nil
    group.cancelAll()
    return first
  }
}

/// Сколько ждём системную службу. Восемь секунд — это уже «не работает» с
/// точки зрения человека, который нажал пункт меню.
private let kTranslationDeadline: Double = 8

final class TranslationBridge {
  private var channel: FlutterMethodChannel?

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "secretly/translate",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "detect":
        self.handleDetect(call, result)
      case "translate":
        self.handleTranslate(call, result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Определение языка

  /// `NLLanguageRecognizer` есть с macOS 10.14 и работает всегда — даже там,
  /// где самого перевода нет. Поэтому определение отделено от перевода.
  ///
  /// 🔴 ОТДАЁМ НЕ ОДИН ЯЗЫК, А НЕСКОЛЬКО ПО УБЫВАНИЮ УВЕРЕННОСТИ.
  ///
  /// Найдено 16.09.2026 на живом окне: «Congrats!! 🎉» определилось как
  /// КАТАЛАНСКИЙ, пара ca→ru системе неизвестна, и человек получал отказ на
  /// сообщении, которое переводится безо всяких затруднений. Коротким фразам
  /// это свойственно: двух слов на уверенное определение не хватает никакому
  /// распознавателю.
  ///
  /// Одна догадка на такой длине — это лотерея. Несколько превращают лотерею
  /// в перебор: первый язык, который переводчик ЗНАЕТ, и есть ответ.
  private func handleDetect(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let raw = args["text"] as? String
    else {
      result([String]())
      return
    }
    let text = Self.stripNoise(raw)
    guard !text.isEmpty else {
      result([String]())
      return
    }
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
    let ranked = hypotheses
      .sorted { $0.value > $1.value }
      // Совсем беспочвенные догадки отбрасываем: перебирать их значит тратить
      // время человека на заведомо чужие языки.
      .filter { $0.value >= 0.05 }
      .map { $0.key.rawValue }
      .filter { $0 != "und" && !$0.isEmpty }
    if ranked.isEmpty, let dominant = recognizer.dominantLanguage {
      result([dominant.rawValue])
      return
    }
    result(Array(ranked.prefix(3)))
  }

  /// Убирает из текста то, что распознаватель языка только путает: эмодзи,
  /// значки и ссылки.
  ///
  /// 🔴 ЭМОДЗИ — НЕ ЯЗЫК. В «Congrats!! 🎉» на два слова приходится один
  /// символ, который не принадлежит никакому языку, и вес его в такой короткой
  /// строке непропорционален.
  private static func stripNoise(_ raw: String) -> String {
    var out = ""
    for scalar in raw.unicodeScalars {
      if scalar.properties.isEmoji && scalar.properties.isEmojiPresentation {
        continue
      }
      if scalar.properties.isVariationSelector { continue }
      out.unicodeScalars.append(scalar)
    }
    return out.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - Сам перевод

  private func handleTranslate(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let text = args["text"] as? String,
      let source = args["source"] as? String,
      let target = args["target"] as? String,
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(FlutterError(code: "bad_args", message: nil, details: nil))
      return
    }
    guard #available(macOS 26.0, *) else {
      // До macOS 26 сессию без SwiftUI не получить — см. заголовок файла.
      result(FlutterError(code: "unsupported_os", message: nil, details: nil))
      return
    }
    Task {
      let sourceLanguage = Locale.Language(identifier: source)
      let targetLanguage = Locale.Language(identifier: target)

      // 🔴 СНАЧАЛА ПРОБУЕМ ПЕРЕВЕСТИ, И ТОЛЬКО ПОТОМ ВЫЯСНЯЕМ ПРИЧИНУ.
      //
      // Сперва здесь стояла проверка доступности пары, и лишь после неё —
      // перевод. Это два обращения к службе вместо одного на КАЖДОЕ нажатие,
      // причём первое из них — то самое, которое может не ответить. Удачный
      // путь не должен зависеть от медленной справки: пробуем перевод, а
      // справку спрашиваем, только когда надо объяснить отказ.
      let translated = await withDeadline(seconds: kTranslationDeadline) {
        () -> String? in
        let session = TranslationSession(
          installedSource: sourceLanguage,
          target: targetLanguage
        )
        return try? await session.translate(text).targetText
      }
      if let translated, let value = translated, !value.isEmpty {
        result(value)
        return
      }

      // Не вышло. Теперь можно позволить себе справку — ради внятного ответа
      // человеку, а не ради самого перевода.
      let status = await withDeadline(seconds: kTranslationDeadline) {
        await LanguageAvailability().status(
          from: sourceLanguage,
          to: targetLanguage
        )
      }
      switch status {
      case .supported:
        // Пара переводима, но модели на устройстве нет. Скачать её отсюда
        // нельзя (см. заголовок файла), поэтому говорим прямо.
        result(FlutterError(code: "needs_download", message: nil, details: nil))
      case .unsupported:
        result(FlutterError(code: "unsupported_pair", message: nil, details: nil))
      case .installed, .none:
        result(FlutterError(code: "failed", message: nil, details: nil))
      @unknown default:
        result(FlutterError(code: "failed", message: nil, details: nil))
      }
    }
  }
}
