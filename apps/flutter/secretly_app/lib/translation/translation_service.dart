// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../build_variant.dart';
import '../diagnostics/diag_log.dart';
import 'translation_rules.dart';

/// Чем закончилась попытка перевода. Экран чата показывает человеку причину,
/// а не молчит: раньше любой сбой превращался в пустое место под сообщением.
enum TranslationOutcome {
  /// Переведено — текст в [TranslationResult.text].
  ok,

  /// Сообщение уже на языке перевода.
  sameLanguage,

  /// Язык не распознан (слишком коротко, только эмодзи, смесь языков).
  undetected,

  /// Языка нет среди тех, что умеет переводчик на телефоне.
  unsupported,

  /// Не скачалась языковая модель (нет сети, оборвалась загрузка).
  downloadFailed,

  /// Нечего переводить: пусто, только ссылки или эмодзи.
  nothingToTranslate,

  /// В этой сборке переводчика нет.
  unavailable,

  /// Любая другая ошибка.
  failed,
}

@immutable
class TranslationResult {
  const TranslationResult(this.outcome, {this.text, this.sourceBcp});

  final TranslationOutcome outcome;
  final String? text;

  /// Язык, с которого переводили (распознанный или выбранный человеком).
  final String? sourceBcp;

  bool get isOk => outcome == TranslationOutcome.ok && text != null;
}

/// On-device message translation.
///
/// Privacy first: translation runs fully on the device via Google ML Kit — the
/// message plaintext NEVER leaves the phone, consistent with the app's E2EE
/// stance (no cloud translator). Language models (~30 MB each) download on
/// demand and are cached by ML Kit; translations are cached in-memory per
/// message so re-opening a chat is instant.
///
/// Translation is free for everyone — no tier checks here or in the UI.
///
/// Нормализация (11.2026): ссылки, @упоминания, почта, эмодзи и `код` не
/// отдаются модели — они вставляются обратно как были; растянутые буквы
/// («спасибооооо») сжимаются; строки переводятся по одной, поэтому переносы
/// сохраняются. Язык определяется по очищенному тексту, с запасными
/// кандидатами — так короткие сообщения и сообщения с опечатками
/// распознаются чаще.
class MessageTranslationService {
  MessageTranslationService._();
  static final MessageTranslationService instance =
      MessageTranslationService._();

  /// Растёт, когда человек меняет настройки перевода (Настройки → Язык).
  /// Открытые чаты слушают его и перечитывают настройки сразу, без
  /// перезахода в чат.
  static final ValueNotifier<int> settingsChanged = ValueNotifier<int>(0);

  /// Сколько ждать загрузки одной модели (~30 МБ) по мобильной сети.
  static const Duration downloadTimeout = Duration(seconds: 120);

  /// 🔴 ПОЗДНЕЕ СОЗДАНИЕ, А НЕ ПРИ РОЖДЕНИИ ОБЪЕКТА. В облегчённой сборке
  /// библиотек ML Kit в пакете нет, а служба — одиночка на весь процесс:
  /// обычные поля создавались бы при первом же обращении к `instance`, то
  /// есть ДО любой проверки флага. `late` отодвигает создание до настоящего
  /// использования, а до него в облегчённой сборке дело не доходит.
  late final LanguageIdentifier _languageId = LanguageIdentifier(
    confidenceThreshold: 0.5,
  );

  /// Второй опознаватель с низким порогом — для списка кандидатов.
  late final LanguageIdentifier _languageCandidates = LanguageIdentifier(
    confidenceThreshold: 0.05,
  );
  late final OnDeviceTranslatorModelManager _models =
      OnDeviceTranslatorModelManager();
  final Map<String, OnDeviceTranslator> _translators =
      <String, OnDeviceTranslator>{};

  /// Одна загрузка модели на язык, даже если её просят сразу несколько
  /// сообщений (авторежим).
  final Map<String, Future<bool>> _downloads = <String, Future<bool>>{};

  /// Cache keyed by `<cacheKey>|<targetBcp>|<source>` so the same message
  /// isn't re-translated when a chat is reopened within a session.
  final Map<String, String> _cache = <String, String>{};

  /// Detects the BCP-47 language code of [text] (e.g. "ru"), or null when it
  /// can't be determined. Used to decide whether to offer a translate button.
  Future<String?> detectLanguage(String text) async {
    if (!kTranslationAvailable) return null;
    final cleaned = TranslationText.forDetection(text);
    if (cleaned.isEmpty) return null;
    try {
      final code = await _languageId.identifyLanguage(cleaned);
      return (code == 'und' || code.isEmpty) ? null : code;
    } catch (_) {
      return null;
    }
  }

  /// Кандидаты языка по убыванию уверенности, только те, что умеет
  /// переводчик. Латинская запись («ru-Latn» — транслит) пропускается:
  /// модель перевода ждёт родную письменность и выдаёт по ней мусор.
  Future<List<(String, double)>> _candidates(String cleaned) async {
    final out = <(String, double)>[];
    try {
      final found = await _languageCandidates.identifyPossibleLanguages(
        cleaned,
      );
      for (final l in found) {
        final tag = l.languageTag.trim();
        if (tag.isEmpty || tag == 'und' || tag.contains('-')) continue;
        if (BCP47Code.fromRawValue(tag) == null) continue;
        out.add((tag, l.confidence));
      }
    } catch (_) {
      // Пустой список — вызывающий решит, что язык не распознан.
    }
    out.sort((a, b) => b.$2.compareTo(a.$2));
    return out;
  }

  /// Все кандидаты, включая транслит (`ru-Latn`) — для [TranslationRules].
  Future<List<(String, double)>> _rawCandidates(String cleaned) async {
    final out = <(String, double)>[];
    try {
      final found = await _languageCandidates.identifyPossibleLanguages(
        cleaned,
      );
      for (final l in found) {
        final tag = l.languageTag.trim();
        if (tag.isEmpty || tag == 'und') continue;
        out.add((tag, l.confidence));
      }
    } catch (_) {
      // Пустой список — правила решат «не распознан».
    }
    out.sort((a, b) => b.$2.compareTo(a.$2));
    return out;
  }

  /// Выбор языка оригинала по кандидатам. Если самый вероятный язык —
  /// язык перевода, но уверенность невысока (короткая фраза, опечатки),
  /// берём следующий правдоподобный: человек нажал «перевести», значит,
  /// текст ему непонятен.
  static String? pickSource(
    List<(String, double)> candidates,
    String target, {
    double sureSame = 0.6,
    double minOther = 0.12,
  }) {
    if (candidates.isEmpty) return null;
    final top = candidates.first;
    if (top.$1 != target) return top.$1;
    if (top.$2 >= sureSame) return target;
    for (final c in candidates.skip(1)) {
      if (c.$1 != target && c.$2 >= minOther) return c.$1;
    }
    return target;
  }

  /// True when the on-device model for [bcp] is already present (no download
  /// needed). Best-effort.
  Future<bool> isModelReady(String bcp) async {
    if (!kTranslationAvailable) return false;
    try {
      return await _models.isModelDownloaded(bcp);
    } catch (_) {
      return false;
    }
  }

  /// Скачивает модель языка заранее — например, когда человек включает
  /// кнопку переводчика, чтобы первое нажатие в чате не ждало загрузки.
  Future<bool> prefetchModel(String bcp) async {
    if (!kTranslationAvailable) return false;
    final code = BCP47Code.fromRawValue(bcp);
    if (code == null) return false;
    return _ensureModel(code.bcpCode);
  }

  Future<bool> _ensureModel(String bcp) {
    final running = _downloads[bcp];
    if (running != null) return running;
    final job = () async {
      try {
        if (await _models.isModelDownloaded(bcp)) return true;
        final ok = await _models
            .downloadModel(bcp, isWifiRequired: false)
            .timeout(downloadTimeout);
        return ok && await _models.isModelDownloaded(bcp);
      } catch (_) {
        return false;
      }
    }();
    _downloads[bcp] = job;
    // Неудачу не запоминаем: следующее нажатие попробует снова.
    job.whenComplete(() => _downloads.remove(bcp));
    return job;
  }

  /// Translates [text] into [targetBcp] (e.g. "ru"). Returns the text or
  /// null; use [translateDetailed] to learn why it failed.
  Future<String?> translate({
    required String text,
    required String targetBcp,
    String? sourceBcp,
    String? cacheKey,
    bool userInitiated = true,
  }) async {
    final r = await translateDetailed(
      text: text,
      targetBcp: targetBcp,
      sourceBcp: sourceBcp,
      cacheKey: cacheKey,
      userInitiated: userInitiated,
    );
    return r.isOk ? r.text : null;
  }

  /// Translates [text] into [targetBcp]. When [sourceBcp] is given (e.g. "en")
  /// it is used as the source language; otherwise the source is detected from
  /// the cleaned text with fallback candidates. Never throws.
  ///
  /// [userInitiated] — человек нажал «перевести». false — авторежим: он
  /// переводит только сообщения, уверенно написанные на другом языке
  /// (22.11.2026, Т-1, правила — [TranslationRules.decideSource]).
  Future<TranslationResult> translateDetailed({
    required String text,
    required String targetBcp,
    String? sourceBcp,
    String? cacheKey,
    bool userInitiated = true,
  }) async {
    if (!kTranslationAvailable) {
      return const TranslationResult(TranslationOutcome.unavailable);
    }
    final trimmed = text.trim();
    final cleaned = TranslationText.forDetection(trimmed);
    if (cleaned.isEmpty) {
      return const TranslationResult(TranslationOutcome.nothingToTranslate);
    }
    final ck = cacheKey == null
        ? null
        : '$cacheKey|$targetBcp|${sourceBcp ?? 'auto'}';
    if (ck != null) {
      final hit = _cache[ck];
      if (hit != null) return TranslationResult(TranslationOutcome.ok, text: hit);
    }
    try {
      final target = BCP47Code.fromRawValue(targetBcp);
      if (target == null) {
        return const TranslationResult(TranslationOutcome.unsupported);
      }
      final pinned = sourceBcp?.trim() ?? '';
      final String? srcCode;
      if (kTranslationStrictSameLanguage) {
        // Определение идёт всегда, даже при выбранном языке оригинала.
        final decision = TranslationRules.decideSource(
          candidates: await _rawCandidates(cleaned),
          target: target.bcpCode,
          cleanedText: cleaned,
          userInitiated: userInitiated,
          pinnedSource: pinned.isEmpty ? null : pinned,
          supported: (c) => BCP47Code.fromRawValue(c) != null,
        );
        DiagLog.event('translate', 'decision', {
          'verdict': decision.verdict.name,
          'rule': decision.reason,
          'src': decision.source ?? '',
          'tgt': target.bcpCode,
          'pinned': pinned.isNotEmpty,
          'user': userInitiated,
          'len': cleaned.length,
        });
        switch (decision.verdict) {
          case SourceVerdict.sameLanguage:
            return TranslationResult(
              TranslationOutcome.sameLanguage,
              sourceBcp: target.bcpCode,
            );
          case SourceVerdict.undetected:
            return const TranslationResult(TranslationOutcome.undetected);
          case SourceVerdict.translate:
            srcCode = decision.source;
        }
      } else if (pinned.isNotEmpty) {
        // Прежнее поведение: выбранный язык без определения.
        srcCode = pinned;
      } else {
        srcCode = pickSource(await _candidates(cleaned), target.bcpCode);
      }
      if (srcCode == null) {
        return const TranslationResult(TranslationOutcome.undetected);
      }
      final source = BCP47Code.fromRawValue(srcCode);
      if (source == null) {
        return TranslationResult(
          TranslationOutcome.unsupported,
          sourceBcp: srcCode,
        );
      }
      if (source == target) {
        return TranslationResult(
          TranslationOutcome.sameLanguage,
          sourceBcp: source.bcpCode,
        );
      }

      // Both models must be present (~30 MB once per language). The download
      // result is checked — a silent failure used to look like «nothing
      // happens» on tap.
      final ready = await Future.wait<bool>([
        _ensureModel(source.bcpCode),
        _ensureModel(target.bcpCode),
      ]);
      if (ready.contains(false)) {
        return TranslationResult(
          TranslationOutcome.downloadFailed,
          sourceBcp: source.bcpCode,
        );
      }

      final key = '${source.bcpCode}->${target.bcpCode}';
      final translator = _translators.putIfAbsent(
        key,
        () => OnDeviceTranslator(sourceLanguage: source, targetLanguage: target),
      );
      final out = await TranslationText.translatePreserving(
        trimmed,
        (chunk) => translator.translateText(chunk),
      );
      if (out.trim().isEmpty) {
        return TranslationResult(
          TranslationOutcome.failed,
          sourceBcp: source.bcpCode,
        );
      }
      // «Перевод» почти совпал с оригиналом — сообщение уже было на языке
      // перевода: не показываем и не запоминаем.
      if (kTranslationStrictSameLanguage &&
          TranslationRules.looksUnchanged(trimmed, out)) {
        DiagLog.event('translate', 'unchanged', {
          'src': source.bcpCode,
          'tgt': target.bcpCode,
        });
        return TranslationResult(
          TranslationOutcome.sameLanguage,
          sourceBcp: source.bcpCode,
        );
      }
      if (ck != null) _cache[ck] = out;
      return TranslationResult(
        TranslationOutcome.ok,
        text: out,
        sourceBcp: source.bcpCode,
      );
    } catch (_) {
      return const TranslationResult(TranslationOutcome.failed);
    }
  }

  /// Releases native resources. The service is a process-long singleton, so this
  /// is mainly for tests/teardown.
  Future<void> dispose() async {
    // Ни одного переводчика и опознавателя в облегчённой сборке не создавалось:
    // `late`-поле тронуть нельзя — оно бы создалось именно здесь.
    if (!kTranslationAvailable) return;
    for (final t in _translators.values) {
      try {
        await t.close();
      } catch (_) {}
    }
    _translators.clear();
    try {
      await _languageId.close();
      await _languageCandidates.close();
    } catch (_) {}
  }
}

/// Подготовка текста к переводу: чистые функции, без ML Kit — их проверяют
/// тесты.
abstract final class TranslationText {
  /// Куски, которые модели не отдаются и возвращаются как были: ссылки,
  /// почта, @упоминания, `код`, эмодзи и прочие символы без букв.
  static final RegExp _protected = RegExp(
    r'(https?://\S+|www\.\S+|\S+@\S+\.\S+|@[\w.]+|`[^`]*`|'
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}'
    r'\u{FE0F}\u{200D}\u{1F1E6}-\u{1F1FF}]+)',
    unicode: true,
  );

  /// Буква в любой письменности.
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  /// Три и больше одинаковых буквы подряд — растянутое слово.
  static final RegExp _stretched = RegExp(r'(\p{L})\1{2,}', unicode: true);

  /// «Спасибооооо» → «Спасибоо», «sooooo» → «soo». Две буквы оставляем:
  /// в словах вроде «cool», «длинный» двойная буква настоящая.
  static String collapseStretched(String s) =>
      s.replaceAllMapped(_stretched, (m) => '${m[1]}${m[1]}');

  /// Текст для определения языка: без ссылок, упоминаний, эмодзи и кода,
  /// с сжатыми растянутыми словами. Пусто — значит, букв нет совсем.
  static String forDetection(String text) {
    final noProtected = text.replaceAll(_protected, ' ');
    if (!_letter.hasMatch(noProtected)) return '';
    return collapseStretched(
      noProtected.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
  }

  /// Переводит [text] по строкам и по кускам между защищёнными фрагментами;
  /// ссылки, эмодзи и переносы строк остаются на своих местах. Кусок без
  /// букв не переводится.
  static Future<String> translatePreserving(
    String text,
    Future<String> Function(String chunk) translate,
  ) async {
    final lines = text.split('\n');
    final out = <String>[];
    for (final line in lines) {
      out.add(await _translateLine(line, translate));
    }
    return out.join('\n').trim();
  }

  static Future<String> _translateLine(
    String line,
    Future<String> Function(String chunk) translate,
  ) async {
    if (!_letter.hasMatch(line)) return line;
    final buf = StringBuffer();
    var last = 0;
    for (final m in _protected.allMatches(line)) {
      buf.write(await _translateChunk(line.substring(last, m.start), translate));
      buf.write(m[0]);
      last = m.end;
    }
    buf.write(await _translateChunk(line.substring(last), translate));
    return buf.toString();
  }

  static Future<String> _translateChunk(
    String chunk,
    Future<String> Function(String chunk) translate,
  ) async {
    if (!_letter.hasMatch(chunk)) return chunk;
    // Пробелы по краям модель съедает — возвращаем их, чтобы слова не
    // слиплись со ссылками и эмодзи.
    final lead = RegExp(r'^\s*').stringMatch(chunk) ?? '';
    final trail = RegExp(r'\s*$').stringMatch(chunk) ?? '';
    final core = collapseStretched(chunk.trim());
    final translated = (await translate(core)).trim();
    return '$lead${translated.isEmpty ? core : translated}$trail';
  }
}
