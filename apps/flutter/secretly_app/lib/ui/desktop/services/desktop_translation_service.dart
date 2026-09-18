// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Перевод сообщений в окне — на самом компьютере.
///
/// 🔴 ПОЧЕМУ ЗДЕСЬ СВОЯ СЛУЖБА, А НЕ ОБЩАЯ С ТЕЛЕФОНОМ.
///
/// Телефон переводит через Google ML Kit
/// (`lib/translation/translation_service.dart`), и там записано главное
/// правило: «текст сообщения НИКОГДА не покидает устройство — то же обещание,
/// что и сквозное шифрование, никакого облачного переводчика». Плагины ML Kit
/// объявлены только под Android и iOS: на маке вызов ушёл бы в пустоту.
///
/// 🔴 ОБЛАЧНЫЙ ПЕРЕВОДЧИК ИСКЛЮЧЁН. Отправить расшифрованный текст чужой
/// службе значило бы отдать наружу ровно то, что приложение обещает не
/// отдавать. Такой «перевод» был бы не функцией, а дырой в самом главном.
///
/// Поэтому окно зовёт СИСТЕМНЫЙ переводчик macOS (`macos/Runner/
/// TranslationBridge.swift`): он считает на устройстве, моделями, которые
/// человек скачал себе сам.
///
/// Всё падает МЯГКО: перевод — удобство, и он не имеет права бросать
/// исключение в переписку.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import '../../../diagnostics/diag_log.dart';

/// Чем кончилась попытка перевода.
enum DesktopTranslationOutcome {
  /// Готово, текст в [DesktopTranslationResult.text].
  ok,

  /// Язык сообщения определить не удалось.
  unknownSource,

  /// Сообщение уже на нужном языке — переводить нечего.
  sameLanguage,

  /// Пара языков системе неизвестна, либо macOS старее нужной.
  unsupported,

  /// Пара переводима, но модель не скачана. Скачивание у Apple возможно
  /// только из системного окна — зовём человека в настройки.
  needsDownload,

  /// Что-то сломалось по дороге.
  failed,
}

class DesktopTranslationResult {
  const DesktopTranslationResult(this.outcome, [this.text]);

  final DesktopTranslationOutcome outcome;
  final String? text;

  bool get isOk => outcome == DesktopTranslationOutcome.ok;

  /// Что сказать человеку, когда перевода не будет. `null` — сказать нечего
  /// (перевод состоялся или переводить было нечего).
  String? get userMessage {
    switch (outcome) {
      case DesktopTranslationOutcome.ok:
      case DesktopTranslationOutcome.sameLanguage:
        return null;
      case DesktopTranslationOutcome.unknownSource:
        return 'Не удалось определить язык сообщения';
      case DesktopTranslationOutcome.unsupported:
        return 'Системный переводчик не знает этой пары языков';
      case DesktopTranslationOutcome.needsDownload:
        // Ровно то место, куда идти: без этого совет «скачайте модель»
        // отправляет человека искать её по всей системе.
        return 'Язык не скачан. Системные настройки → Основные → Язык и '
            'регион → Языки перевода';
      case DesktopTranslationOutcome.failed:
        return 'Перевести не удалось';
    }
  }
}

class DesktopTranslationService {
  DesktopTranslationService._();

  static final DesktopTranslationService instance =
      DesktopTranslationService._();

  static const MethodChannel _channel = MethodChannel('secretly/translate');

  /// 🔴 ВТОРОЙ СРОК — ЗДЕСЬ, И ОН НЕ ЛИШНИЙ.
  ///
  /// Срок стоит и в мосте, но он защищает от медленной СИСТЕМНОЙ службы. Если
  /// же не ответит сам мост — например, канала нет в этой сборке, — ждать
  /// будет уже некому. Нажатие «Перевести», повисшее навсегда, выглядит
  /// поломкой окна; ограниченное ожидание и внятный отказ — нет.
  static const Duration _deadline = Duration(seconds: 12);

  /// Перевод по ключу сообщения: перечитывать один и тот же текст незачем.
  final Map<String, DesktopTranslationResult> _cache =
      <String, DesktopTranslationResult>{};

  /// Догадки о языке по ключу: определение тоже стоит времени.
  final Map<String, List<String>> _detected = <String, List<String>>{};

  @visibleForTesting
  static MethodChannel get channel => _channel;

  @visibleForTesting
  void clearCacheForTest() {
    _cache.clear();
    _detected.clear();
  }

  /// Язык текста (например `ru`) или `null`, если определить не вышло.
  Future<String?> detect(String text, {String? cacheKey}) async {
    final ranked = await detectRanked(text, cacheKey: cacheKey);
    return ranked.isEmpty ? null : ranked.first;
  }

  /// 🔴 ДОГАДКИ О ЯЗЫКЕ — СПИСКОМ, ПО УБЫВАНИЮ УВЕРЕННОСТИ.
  ///
  /// Найдено 16.09.2026 на живом окне: «Congrats!! 🎉» определилось как
  /// КАТАЛАНСКИЙ (`translate.unsupported_pair src=ca dst=ru` в журнале), и
  /// человек получал отказ на сообщении, которое переводится безо всяких
  /// затруднений. Коротким фразам это свойственно: двух слов на уверенное
  /// определение не хватает никакому распознавателю.
  ///
  /// Одна догадка на такой длине — лотерея. Несколько превращают лотерею в
  /// перебор: первый язык, который переводчик ЗНАЕТ, и есть ответ.
  Future<List<String>> detectRanked(String text, {String? cacheKey}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const <String>[];
    if (cacheKey != null && _detected.containsKey(cacheKey)) {
      return _detected[cacheKey]!;
    }
    List<String> out = const <String>[];
    try {
      final raw = await _channel
          .invokeListMethod<String>('detect', {'text': trimmed})
          .timeout(_deadline);
      out = (raw ?? const <String>[])
          .map(_baseLanguage)
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } catch (_) {
      out = const <String>[];
    }
    if (cacheKey != null) _detected[cacheKey] = out;
    return out;
  }

  /// Переводит [text] на [targetBcp].
  ///
  /// [sourceBcp] — закреплённый язык оригинала; `null` значит «определить».
  Future<DesktopTranslationResult> translate({
    required String text,
    required String targetBcp,
    String? sourceBcp,
    String? cacheKey,
  }) async {
    final trimmed = text.trim();
    final target = _baseLanguage(targetBcp);
    if (trimmed.isEmpty || target.isEmpty) {
      return const DesktopTranslationResult(DesktopTranslationOutcome.failed);
    }
    final key = cacheKey == null
        ? null
        : '$cacheKey|$target|${sourceBcp ?? 'auto'}';
    if (key != null) {
      final hit = _cache[key];
      if (hit != null) return hit;
    }

    final pinned = _baseLanguage(sourceBcp ?? '');
    final candidates = pinned.isNotEmpty
        ? <String>[pinned]
        : await detectRanked(trimmed, cacheKey: cacheKey);
    if (candidates.isEmpty) {
      _log('unknown_source', target: target);
      return _remember(
        key,
        const DesktopTranslationResult(
          DesktopTranslationOutcome.unknownSource,
        ),
      );
    }
    // Уже на нужном языке — молчим, а не показываем ту же строку второй раз.
    // Сверяемся с ПЕРВОЙ догадкой: она и есть «язык сообщения».
    if (candidates.first == target) {
      _log('same_language', source: candidates.first, target: target);
      return _remember(
        key,
        const DesktopTranslationResult(DesktopTranslationOutcome.sameLanguage),
      );
    }

    DesktopTranslationResult? lastRefusal;
    for (final source in candidates) {
      if (source == target) continue;
      final attempt = await _attempt(
        text: trimmed,
        source: source,
        target: target,
      );
      if (attempt.isOk) return _remember(key, attempt);
      lastRefusal = attempt;
      // Перебираем дальше ТОЛЬКО когда пара неизвестна: это и значит «мы
      // угадали язык неверно». Отсутствие модели или поломка перебором не
      // лечатся, и следующая попытка лишь отняла бы время.
      if (attempt.outcome != DesktopTranslationOutcome.unsupported) break;
    }
    return _remember(
      key,
      lastRefusal ??
          const DesktopTranslationResult(DesktopTranslationOutcome.failed),
    );
  }

  /// Одна попытка перевода с конкретной парой языков.
  Future<DesktopTranslationResult> _attempt({
    required String text,
    required String source,
    required String target,
  }) async {
    try {
      final out = await _channel.invokeMethod<String>('translate', {
        'text': text,
        'source': source,
        'target': target,
      }).timeout(_deadline);
      final value = (out ?? '').trim();
      if (value.isEmpty) {
        _log('empty', source: source, target: target);
        return const DesktopTranslationResult(
          DesktopTranslationOutcome.failed,
        );
      }
      _log('ok', source: source, target: target);
      return DesktopTranslationResult(DesktopTranslationOutcome.ok, value);
    } on PlatformException catch (e) {
      _log(e.code, source: source, target: target);
      return DesktopTranslationResult(_outcomeFor(e.code));
    } on MissingPluginException {
      // Не десктопная сборка (или канал не подключён) — тихо «не умеем».
      _log('no_channel', source: source, target: target);
      return const DesktopTranslationResult(
        DesktopTranslationOutcome.unsupported,
      );
    } catch (_) {
      _log('error', source: source, target: target);
      return const DesktopTranslationResult(DesktopTranslationOutcome.failed);
    }
  }

  /// 🔴 ЗАПОМИНАЕМ ТОЛЬКО ОКОНЧАТЕЛЬНОЕ.
  ///
  /// Перевод и «уже на этом языке» не изменятся — их держим. А вот «модель не
  /// скачана» человек чинит за минуту в системных настройках, «не ответило в
  /// срок» проходит само, и язык у короткой фразы может определиться иначе.
  /// Запомнив такой отказ, окно на второе нажатие ответило бы тем же — и
  /// человек, только что поставивший язык, решил бы, что перевод сломан.
  DesktopTranslationResult _remember(
    String? key,
    DesktopTranslationResult value,
  ) {
    final stable = value.outcome == DesktopTranslationOutcome.ok ||
        value.outcome == DesktopTranslationOutcome.sameLanguage;
    if (key != null && stable) _cache[key] = value;
    return value;
  }

  /// 🔴 ПАРА ЯЗЫКОВ И ИСХОД — В ЖУРНАЛ.
  ///
  /// Отказ «системный переводчик не знает этой пары» ничего не говорит о ТОЙ
  /// САМОЙ паре: какой язык определился и на какой переводили, из окна не
  /// видно. А это ровно то, что нужно знать, когда перевод вдруг перестал
  /// работать. Сам ТЕКСТ в журнал не идёт — ни целиком, ни куском: содержимое
  /// переписки не место для диагностики.
  void _log(String outcome, {String? source, String? target}) {
    DiagLog.event('translate', outcome, {
      'src': (source ?? '').isEmpty ? '-' : source,
      'dst': (target ?? '').isEmpty ? '-' : target,
    });
  }

  static DesktopTranslationOutcome _outcomeFor(String code) {
    switch (code) {
      case 'needs_download':
        return DesktopTranslationOutcome.needsDownload;
      case 'unsupported_pair':
      case 'unsupported_os':
        return DesktopTranslationOutcome.unsupported;
      default:
        return DesktopTranslationOutcome.failed;
    }
  }

  /// `ru-RU` → `ru`. Системный переводчик сравнивает языки, а не диалекты;
  /// без этого «ru-RU» и «ru» выглядели бы разными языками.
  static String _baseLanguage(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return '';
    final cut = trimmed.indexOf(RegExp('[-_]'));
    return cut <= 0 ? trimmed : trimmed.substring(0, cut);
  }
}
