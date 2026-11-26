// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Проверка орфографии в поле ввода на нескольких языках (23.11.2026).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/composer_spell_check.dart';

/// Словарь по списку верных слов; ведёт счёт обращений.
class _FakeDictionary implements SpellDictionary {
  _FakeDictionary(this.known);

  final Map<String, Set<String>> known;
  final List<(String, String)> checks = [];
  final List<String> guessed = [];

  @override
  Future<List<TextRange>?> check(String text, String language) async {
    final ok = known[language];
    if (ok == null) return null;
    checks.add((language, text));
    final out = <TextRange>[];
    var start = 0;
    for (final w in text.split('\n')) {
      if (!ok.contains(w)) out.add(TextRange(start: start, end: start + w.length));
      start += w.length + 1;
    }
    return out;
  }

  @override
  Future<List<String>> guesses(String word, String language) async {
    guessed.add('$word|$language');
    return ['$word-$language'];
  }
}

MultiLocaleSpellCheckService _service(
  _FakeDictionary d,
  List<Locale> device,
  List<String>? available,
) => MultiLocaleSpellCheckService(
  deviceLocales: () => device,
  availableLanguages: () async => available,
  singleSystemCall: false,
  dictionary: d,
  debounce: Duration.zero,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('языки: приложение, потом телефон, без повторов, до четырёх', () {
    final l = spellCheckLocales(const Locale('ru'), const [
      Locale('ru', 'RU'),
      Locale('en', 'US'),
      Locale('uk'),
      Locale('de'),
    ]);
    expect(l.map((e) => e.languageCode), ['ru', 'en', 'uk', 'de']);
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

  test('язык без словаря в системе не судит; чужой алфавит не спрашиваем', () async {
    final d = _FakeDictionary({'en': {'test'}});
    final service = _service(d, const [Locale('en'), Locale('uk')], null);
    final out = await service.fetchSpellCheckSuggestions(
      const Locale('ru'),
      'tset',
    );
    // Латинский текст — русский и украинский словари не спрашиваются.
    expect(d.checks.map((c) => c.$1), ['en']);
    expect(out!.single.range, const TextRange(start: 0, end: 4));
    expect(out.single.suggestions, ['tset-en']);
  });

  group('длинное сообщение (25.11.2026, «нереально лагает ввод»)', () {
    const ru = {'сделать', 'комнату', 'для', 'общих', 'мероприятий', 'и', 'игры'};
    final long = List.generate(60, (_) => ru.join(' ')).join('\n');

    test('🔴 варианты подбираются только ошибкам всех словарей, не каждому '
        'русскому слову', () async {
      final d = _FakeDictionary({'ru_RU': ru, 'uk_UA': {'для'}});
      final s = _service(d, const [Locale('uk')], const ['ru_RU', 'uk_UA']);
      final out = await s.fetchSpellCheckSuggestions(
        const Locale('ru'),
        '$long превет',
      );
      expect(out!.single.suggestions, ['превет-ru_RU', 'превет-uk_UA']);
      expect(d.guessed, ['превет|ru_RU', 'превет|uk_UA']);
      // Украинскому показали только то, чего не знает русский.
      expect(d.checks.where((c) => c.$1 == 'uk_UA').single.$2, 'превет');
    });

    test('🔴 порядок языков не важен: украинский первый — вариантов русским '
        'словам всё равно не ищем', () async {
      final d = _FakeDictionary({'ru_RU': ru, 'uk_UA': {'для'}});
      final s = _service(d, const [Locale('ru')], const ['ru_RU', 'uk_UA']);
      final out = await s.fetchSpellCheckSuggestions(const Locale('uk'), long);
      expect(out, isEmpty);
      expect(d.guessed, isEmpty);
    });

    test('🔴 следующая буква: словарю уходят только новые слова', () async {
      final d = _FakeDictionary({'ru_RU': ru});
      final s = _service(d, const [], const ['ru_RU']);
      await s.fetchSpellCheckSuggestions(const Locale('ru'), long);
      d.checks.clear();
      await s.fetchSpellCheckSuggestions(const Locale('ru'), '$long игр');
      expect(d.checks, [('ru_RU', 'игр')]);
      d.checks.clear();
      await s.fetchSpellCheckSuggestions(const Locale('ru'), '$long игр');
      expect(d.checks, isEmpty);
    });

    test('🔴 пока печатают, словарь не трогаем; устаревший запрос отменён', () async {
      final d = _FakeDictionary({'ru_RU': ru});
      final s = MultiLocaleSpellCheckService(
        deviceLocales: () => const [],
        availableLanguages: () async => const ['ru_RU'],
        singleSystemCall: false,
        dictionary: d,
        debounce: const Duration(milliseconds: 60),
      );
      final results = await Future.wait([
        for (var i = 1; i <= 6; i++)
          s.fetchSpellCheckSuggestions(
            const Locale('ru'),
            'игры для'.substring(0, i + 2),
          ),
      ]);
      expect(results.take(5), everyElement(isNull));
      expect(results.last, isEmpty);
      expect(d.checks, hasLength(1));
    });

    test('места ошибок верны и в середине текста', () async {
      final d = _FakeDictionary({'ru_RU': ru});
      final s = _service(d, const [], const ['ru_RU']);
      const text = 'сделать камнату, для игры\nобщих мероприятей и игры';
      final out = await s.fetchSpellCheckSuggestions(const Locale('ru'), text);
      expect(
        [for (final o in out!) text.substring(o.range.start, o.range.end)],
        ['камнату', 'мероприятей'],
      );
    });
  });

  test('🔴 словарь iPhone подбирается по списку системы', () {
    const ios = ['en', 'en_GB', 'ru_RU', 'uk_UA', 'de_DE', 'pt_BR', 'pt_PT'];
    expect(resolveSpellLocale(const Locale('ru'), ios), const Locale('ru', 'RU'));
    expect(resolveSpellLocale(const Locale('ru', 'UA'), ios), const Locale('ru', 'RU'));
    expect(resolveSpellLocale(const Locale('uk'), ios), const Locale('uk', 'UA'));
    expect(resolveSpellLocale(const Locale('en', 'UA'), ios), const Locale('en'));
    expect(resolveSpellLocale(const Locale('en', 'GB'), ios), const Locale('en', 'GB'));
    expect(resolveSpellLocale(const Locale('pt'), ios), const Locale('pt', 'BR'));
    expect(resolveSpellLocale(const Locale('ja'), ios), isNull);
    // Android: списка нет — язык как есть.
    expect(resolveSpellLocale(const Locale('ru'), null), const Locale('ru'));
  });

  test('🔴 русское слово не судит английский словарь', () {
    const text = 'Привет как дела helo';
    final en = [
      const SuggestionSpan(TextRange(start: 0, end: 6), []),
      const SuggestionSpan(TextRange(start: 7, end: 10), []),
      const SuggestionSpan(TextRange(start: 11, end: 15), []),
      const SuggestionSpan(TextRange(start: 16, end: 20), ['hello']),
    ];
    final out = judgeSpellResults(text, [(script: SpellScript.latin, spans: en)]);
    expect(out, hasLength(1));
    expect(text.substring(out.single.range.start, out.single.range.end), 'helo');
  });

  test('ошибка у русского и украинского одновременно — красная', () {
    const text = 'превет друг';
    final ru = [const SuggestionSpan(TextRange(start: 0, end: 6), ['привет'])];
    final uk = [
      const SuggestionSpan(TextRange(start: 0, end: 6), ['привіт']),
      const SuggestionSpan(TextRange(start: 7, end: 11), ['друже']),
    ];
    final out = judgeSpellResults(text, [
      (script: SpellScript.cyrillic, spans: ru),
      (script: SpellScript.cyrillic, spans: uk),
    ]);
    expect(out, hasLength(1));
    expect(out.single.suggestions, ['привет', 'привіт']);
  });

  test('🔴 телефон на английском, пишут по-русски — русский словарь '
      'подключается сам', () async {
    final d = _FakeDictionary({'ru_RU': {'Привет'}, 'uk_UA': {'для'}});
    final s = _service(
      d,
      const [Locale('en', 'UA')],
      const ['en', 'ru_RU', 'uk_UA'],
    );
    final out = await s.fetchSpellCheckSuggestions(const Locale('en'), 'Привет');
    // Английский словарь кириллицу не судит, украинскому нечего спрашивать.
    expect(d.checks.map((c) => c.$1), ['ru_RU']);
    expect(out, isEmpty);
  });

  test('🔴 не слова — не подчёркиваются: ссылки, @ник, #тег, цифры, iPhone, '
      'аббревиатуры', () {
    bool skip(String text, String word) {
      final i = text.indexOf(word);
      return spellSkipWord(text, TextRange(start: i, end: i + word.length));
    }

    const t = 'зайди на secretlyapp.com к @dimaosa про #релиз 2fa iPhone НЛО превет';
    expect(skip(t, 'secretlyapp'), isTrue);
    expect(skip(t, 'dimaosa'), isTrue);
    expect(skip(t, 'релиз'), isTrue);
    expect(skip(t, '2fa'), isTrue);
    expect(skip(t, 'iPhone'), isTrue);
    expect(skip(t, 'НЛО'), isTrue);
    expect(skip(t, 'превет'), isFalse);
    expect(skip('Привет', 'Привет'), isFalse);
  });

  test('перекрывающиеся отрезки отбрасываются', () {
    const text = 'abcdef ghij';
    final out = judgeSpellResults(text, [
      (
        script: SpellScript.latin,
        spans: const [
          SuggestionSpan(TextRange(start: 0, end: 6), []),
          SuggestionSpan(TextRange(start: 3, end: 6), []),
          SuggestionSpan(TextRange(start: 7, end: 11), []),
        ],
      ),
    ]);
    expect(out.map((e) => e.range.start), [0, 7]);
  });

  testWidgets('Android: один обычный вызов системы, без деления по языкам', (
    t,
  ) async {
    final calls = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.spellCheck,
      (call) async {
        calls.add((call.arguments as List<Object?>)[0] as String);
        return <Object?>[];
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
      singleSystemCall: true,
      debounce: Duration.zero,
    );
    await service.fetchSpellCheckSuggestions(const Locale('ru'), 'Привет hello');
    expect(calls, hasLength(1));
  });

  test('поле ввода сообщения подключено к проверке', () {
    final s = File('lib/ui/chat_screen.dart').readAsStringSync();
    expect(s.contains('composerSpellCheckConfiguration()'), isTrue);
  });
}
