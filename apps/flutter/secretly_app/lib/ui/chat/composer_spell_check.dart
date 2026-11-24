// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Проверка орфографии в поле ввода — красная волнистая линия, как в
/// Telegram (23.11.2026, владелец: «логично, как в Telegram, для всех
/// языков»).
///
/// Системная проверка (Android — словарь системы, iPhone — UITextChecker)
/// умеет один язык за раз, а Flutter спрашивает её на языке ИНТЕРФЕЙСА:
/// в русском приложении любое английское слово было бы подчёркнуто.
/// Поэтому текст проверяется на нескольких языках человека (язык
/// приложения + языки телефона, до трёх), и слово подчёркивается, только
/// если оно ошибочно ВО ВСЕХ: верное русское, украинское, английское,
/// немецкое слово остаётся чистым, опечатка — красная. Варианты исправления
/// — по касанию слова (системная панель подсказок).
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Выключатель: `false` — поле ввода без проверки (как раньше).
const bool kComposerSpellCheck = true;

/// Сколько языков проверять (каждый — отдельный запрос к системе).
const int kSpellCheckMaxLocales = 3;

/// Языки для проверки: язык приложения, затем языки телефона по порядку,
/// без повторов (по коду языка).
@visibleForTesting
List<Locale> spellCheckLocales(Locale appLocale, List<Locale> deviceLocales) {
  final out = <Locale>[];
  final seen = <String>{};
  for (final l in [appLocale, ...deviceLocales]) {
    final code = l.languageCode.toLowerCase();
    if (code.isEmpty || code == 'und' || !seen.add(code)) continue;
    out.add(l);
    if (out.length >= kSpellCheckMaxLocales) break;
  }
  return out;
}

/// Ошибки, общие для всех языков: место слова совпадает у каждого списка.
/// Подсказки — сначала от первого языка, потом от остальных, без повторов.
@visibleForTesting
List<SuggestionSpan> intersectSpellResults(List<List<SuggestionSpan>> perLocale) {
  if (perLocale.isEmpty) return const <SuggestionSpan>[];
  var common = perLocale.first;
  for (final next in perLocale.skip(1)) {
    final byRange = <TextRange, SuggestionSpan>{
      for (final s in next) s.range: s,
    };
    common = [
      for (final s in common)
        if (byRange[s.range] case final other?)
          SuggestionSpan(s.range, <String>{
            ...s.suggestions,
            ...other.suggestions,
          }.take(5).toList(growable: false)),
    ];
  }
  return common;
}

/// Проверка на нескольких языках сразу (см. описание файла).
class MultiLocaleSpellCheckService implements SpellCheckService {
  MultiLocaleSpellCheckService({List<Locale> Function()? deviceLocales})
    : _deviceLocales =
          deviceLocales ?? (() => ui.PlatformDispatcher.instance.locales);

  final List<Locale> Function() _deviceLocales;

  /// Свой системный проверяющий на каждый язык: у него есть память о
  /// прошлом ответе, и смешивать её между языками нельзя.
  final Map<String, DefaultSpellCheckService> _services = {};

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    final locales = spellCheckLocales(locale, _deviceLocales());
    final results = <List<SuggestionSpan>>[];
    for (final l in locales) {
      final service = _services.putIfAbsent(
        l.languageCode,
        DefaultSpellCheckService.new,
      );
      try {
        final spans = await service.fetchSpellCheckSuggestions(l, text);
        // null — для этого языка в системе нет словаря: язык не судит.
        if (spans != null) results.add(spans);
      } catch (_) {
        // Нет системной проверки — молчим, поле работает как раньше.
      }
    }
    if (results.isEmpty) return null;
    return intersectSpellResults(results);
  }
}

/// Одна настройка на всё приложение: поле перестраивается часто, а
/// проверяющий хранит память о прошлых ответах системы.
final SpellCheckConfiguration _composerSpellCheck = SpellCheckConfiguration(
  spellCheckService: MultiLocaleSpellCheckService(),
  // Красная волнистая линия на обеих системах — как просил владелец.
  misspelledTextStyle: TextField.materialMisspelledTextStyle,
);

/// Настройка проверки для поля ввода сообщения; `null` — выключено.
SpellCheckConfiguration? composerSpellCheckConfiguration() {
  if (!kComposerSpellCheck) return null;
  if (kIsWeb) return null;
  final platform = defaultTargetPlatform;
  if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
    return null;
  }
  return _composerSpellCheck;
}
