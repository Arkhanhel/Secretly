// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Проверка орфографии в поле ввода на нескольких языках (23.11.2026).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/composer_spell_check.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('языки: приложение, потом телефон, без повторов, до трёх', () {
    final l = spellCheckLocales(const Locale('ru'), const [
      Locale('ru', 'RU'),
      Locale('en', 'US'),
      Locale('uk'),
      Locale('de'),
    ]);
    expect(l.map((e) => e.languageCode), ['ru', 'en', 'uk']);
  });

  test('🔴 подчёркнуто только то, что ошибочно во всех языках', () {
    const text = 'Привет hello превет helo';
    // ru: «hello» и «helo» — чужие слова, «превет» — ошибка.
    final ru = [
      const SuggestionSpan(TextRange(start: 7, end: 12), []),
      const SuggestionSpan(TextRange(start: 13, end: 19), ['привет']),
      const SuggestionSpan(TextRange(start: 20, end: 24), []),
    ];
    // en: «Привет», «превет» — чужие, «helo» — ошибка.
    final en = [
      const SuggestionSpan(TextRange(start: 0, end: 6), []),
      const SuggestionSpan(TextRange(start: 13, end: 19), []),
      const SuggestionSpan(TextRange(start: 20, end: 24), ['hello', 'help']),
    ];
    final out = intersectSpellResults([ru, en]);
    expect(text.substring(out[0].range.start, out[0].range.end), 'превет');
    expect(text.substring(out[1].range.start, out[1].range.end), 'helo');
    expect(out, hasLength(2));
    expect(out[0].suggestions, ['привет']);
    expect(out[1].suggestions, ['hello', 'help']);
  });

  testWidgets('язык без словаря в системе не судит; нет проверки — молчим', (
    t,
  ) async {
    final calls = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.spellCheck,
      (call) async {
        final args = call.arguments as List<Object?>;
        final locale = args[0] as String;
        calls.add(locale);
        if (locale.startsWith('uk')) return null; // нет словаря
        // Ответ системы: список {startIndex, endIndex, suggestions} —
        // ошибка одна и та же у ru и en.
        return <Object?>[
          <String, Object?>{
            'startIndex': 0,
            'endIndex': 4,
            'suggestions': <Object?>['test'],
          },
        ];
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.spellCheck,
        null,
      ),
    );
    final service = MultiLocaleSpellCheckService(
      deviceLocales: () => const [Locale('en'), Locale('uk')],
    );
    final out = await service.fetchSpellCheckSuggestions(
      const Locale('ru'),
      'tset',
    );
    expect(calls.map((c) => c.split(RegExp('[-_]')).first), ['ru', 'en', 'uk']);
    expect(out, isNotNull);
    expect(out!.single.range, const TextRange(start: 0, end: 4));
  });

  test('поле ввода сообщения подключено к проверке', () {
    final s = File('lib/ui/chat_screen.dart').readAsStringSync();
    expect(s.contains('composerSpellCheckConfiguration()'), isTrue);
  });
}
