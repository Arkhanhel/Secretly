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

/// Сколько языков проверять (каждый — отдельный запрос к системе; языки
/// чужого для текста алфавита не спрашиваются).
const int kSpellCheckMaxLocales = 4;

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

/// Алфавит слова или языка. Слово судят только словари его алфавита:
/// английский словарь не знает русских слов и подчёркивал их все
/// (24.11.2026, владелец: «реагирует даже на все правильные слова»).
enum SpellScript { latin, cyrillic, greek, other }

const Set<String> _cyrillicLanguages = {
  'ru', 'uk', 'be', 'bg', 'sr', 'mk', 'kk', 'ky', 'tg', 'mn',
};

@visibleForTesting
SpellScript scriptOfLanguage(String languageCode) {
  final c = languageCode.toLowerCase();
  if (_cyrillicLanguages.contains(c)) return SpellScript.cyrillic;
  if (c == 'el') return SpellScript.greek;
  const nonLatin = {'ar', 'fa', 'ur', 'he', 'iw', 'hi', 'th', 'zh', 'ja', 'ko', 'ka', 'hy'};
  if (nonLatin.contains(c)) return SpellScript.other;
  return SpellScript.latin;
}

/// Алфавит слова — по первой букве.
@visibleForTesting
SpellScript scriptOfWord(String word) {
  for (final r in word.runes) {
    if (r >= 0x0400 && r <= 0x052F) return SpellScript.cyrillic;
    if (r >= 0x0370 && r <= 0x03FF) return SpellScript.greek;
    if ((r >= 0x41 && r <= 0x5A) ||
        (r >= 0x61 && r <= 0x7A) ||
        (r >= 0xC0 && r <= 0x24F)) {
      return SpellScript.latin;
    }
    if (r > 0x7F) return SpellScript.other;
  }
  return SpellScript.other;
}

/// Запасной язык для алфавита, если среди языков человека нет ни одного
/// с таким алфавитом (телефон на английском, а пишут по-русски).
const Map<SpellScript, List<String>> _scriptFallbackLanguages = {
  SpellScript.cyrillic: ['ru', 'uk'],
  SpellScript.latin: ['en'],
};

/// Словарь iPhone (`UITextChecker.availableLanguages`, вида «ru_RU», «en»)
/// для языка. Движок Flutter превращает «ru-UA» в «ru_UA» и молча
/// пропускает язык, которого нет в списке, поэтому подбираем запись
/// заранее: тот же язык и страна → язык без страны → основная страна
/// языка → любая запись этого языка. `null` — словаря нет.
@visibleForTesting
Locale? resolveSpellLocale(Locale locale, List<String>? available) {
  final lang = locale.languageCode.toLowerCase();
  if (available == null) return locale; // Android: система подберёт сама.
  final set = available.toSet();
  final country = locale.countryCode?.toUpperCase();
  if (country != null && country.isNotEmpty && set.contains('${lang}_$country')) {
    return Locale(lang, country);
  }
  if (set.contains(lang)) return Locale(lang);
  const main = {
    'ru': 'RU', 'uk': 'UA', 'en': 'US', 'de': 'DE', 'fr': 'FR', 'es': 'ES',
    'pt': 'BR', 'it': 'IT', 'nl': 'NL', 'pl': 'PL', 'tr': 'TR', 'sv': 'SE',
    'da': 'DK', 'nb': 'NO', 'fi': 'FI', 'cs': 'CZ', 'el': 'GR', 'hu': 'HU',
    'ro': 'RO', 'bg': 'BG', 'ko': 'KR', 'ca': 'ES', 'hr': 'HR', 'sk': 'SK',
  };
  final m = main[lang];
  if (m != null && set.contains('${lang}_$m')) return Locale(lang, m);
  final any = available.where((a) => a.toLowerCase().startsWith('${lang}_'));
  if (any.isEmpty) return null;
  final parts = any.first.split('_');
  return Locale(lang, parts.length > 1 ? parts[1].toUpperCase() : null);
}

/// Ответ одного словаря: его алфавит и найденные ошибки.
typedef SpellVerdict = ({SpellScript script, List<SuggestionSpan> spans});

/// Ошибка — только если её отметили ВСЕ словари алфавита этого слова.
/// Слово, для алфавита которого нет ни одного словаря, не подчёркивается.
/// Подсказки — сначала от первого словаря, без повторов, до пяти.
@visibleForTesting
List<SuggestionSpan> judgeSpellResults(String text, List<SpellVerdict> verdicts) {
  final candidates = <TextRange, SuggestionSpan>{};
  for (final v in verdicts) {
    for (final s in v.spans) {
      candidates.putIfAbsent(s.range, () => s);
    }
  }
  final urls = [for (final m in _kUrlLike.allMatches(text)) m];
  final out = <SuggestionSpan>[];
  for (final range in candidates.keys) {
    if (range.start < 0 || range.end > text.length || range.end <= range.start) {
      continue;
    }
    if (_notAWord(text, range, urls)) continue;
    final script = scriptOfWord(text.substring(range.start, range.end));
    final judges = verdicts.where((v) => v.script == script).toList();
    if (judges.isEmpty) continue;
    final suggestions = <String>{};
    var everyone = true;
    for (final j in judges) {
      final hit = j.spans.where((s) => s.range == range);
      if (hit.isEmpty) {
        everyone = false;
        break;
      }
      suggestions.addAll(hit.first.suggestions);
    }
    if (!everyone) continue;
    out.add(SuggestionSpan(range, suggestions.take(5).toList(growable: false)));
  }
  out.sort((a, b) => a.range.start.compareTo(b.range.start));
  // Построитель текста Flutter рассчитан на неперекрывающиеся отрезки.
  final clean = <SuggestionSpan>[];
  for (final sp in out) {
    if (clean.isNotEmpty && sp.range.start < clean.last.range.end) continue;
    clean.add(sp);
  }
  return clean;
}

final RegExp _kUrlLike = RegExp(
  r'(https?://|www\.)\S+|\S+\.(com|net|org|ru|ua|app|io|dev|me|info|рф)\b\S*',
  caseSensitive: false,
  unicode: true,
);

/// Не слово для проверки: ссылка, @ник, #тег, слово с цифрами, название в
/// смешанном регистре (iPhone, WhatsApp) или ЗАГЛАВНЫМИ (аббревиатуры).
@visibleForTesting
bool spellSkipWord(String text, TextRange range) =>
    _notAWord(text, range, _kUrlLike.allMatches(text));

/// [urls] — ссылки текста, найденные один раз: на каждое слово искать их по
/// всему тексту заново дорого.
bool _notAWord(String text, TextRange range, Iterable<RegExpMatch> urls) {
  final word = text.substring(range.start, range.end);
  if (word.contains(RegExp(r'\d'))) return true;
  if (range.start > 0) {
    final prev = text[range.start - 1];
    if (prev == '@' || prev == '#' || prev == '/' || prev == '.') return true;
  }
  for (final m in urls) {
    if (m.start <= range.start && m.end >= range.end) return true;
  }
  final letters = word.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
  if (letters.length >= 2) {
    final upper = letters.toUpperCase() == letters;
    final inner = letters.substring(1);
    final mixed = inner.toLowerCase() != inner;
    if (upper || mixed) return true;
  }
  return false;
}

/// Ошибки, общие для всех языков (старое правило, один алфавит).
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

const MethodChannel _spellLanguagesChannel = MethodChannel(
  'secretly/spell_languages',
);

/// Список словарей iPhone; `null` — платформа списка не даёт (Android).
Future<List<String>?> _loadAvailableSpellLanguages() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  try {
    final r = await _spellLanguagesChannel.invokeListMethod<String>('available');
    return r;
  } catch (_) {
    return null;
  }
}

/// Словари iPhone по одному запросу. Отдельно — чтобы проверять логику без
/// системы.
abstract class SpellDictionary {
  /// Отрезки ошибок в [text]; `null` — словаря нет. Без подбора вариантов.
  Future<List<TextRange>?> check(String text, String language);

  /// Варианты исправления слова.
  Future<List<String>> guesses(String word, String language);
}

class _IosSpellDictionary implements SpellDictionary {
  const _IosSpellDictionary();

  @override
  Future<List<TextRange>?> check(String text, String language) async {
    final r = await _spellLanguagesChannel.invokeListMethod<int>('check', {
      'text': text,
      'language': language,
    });
    if (r == null) return null;
    return [
      for (var i = 0; i + 1 < r.length; i += 2)
        TextRange(start: r[i], end: r[i + 1]),
    ];
  }

  @override
  Future<List<String>> guesses(String word, String language) async =>
      await _spellLanguagesChannel.invokeListMethod<String>('guesses', {
        'word': word,
        'language': language,
      }) ??
      const <String>[];
}

/// Слово с буквой в начале; апостроф и дефис внутри — его часть.
final RegExp _kSpellWord = RegExp(
  r"[\p{L}\p{M}][\p{L}\p{M}\p{N}'’ʼ\-]*",
  unicode: true,
);

/// Проверка на нескольких языках сразу (см. описание файла).
///
/// 25.11.2026 (жалоба: «нереально лагает ввод» при правке длинного
/// сообщения). Раньше на КАЖДУЮ букву системе уходил весь текст на каждом
/// языке, и система к каждой ошибке подбирала варианты — на главном потоке.
/// Украинский словарь считал ошибкой каждое русское слово: секунда с лишним
/// на букву при 2 000 знаков (и ноль, пока система держит словарь
/// выгруженным, — поэтому лаг то был, то нет). Теперь:
/// - пока печатают — не спрашиваем вовсе ([debounce]);
/// - слово проверяется один раз и запоминается; уходят только новые слова;
/// - следующий словарь спрашивают лишь о словах, которых не знает прежний;
/// - варианты подбираются только словам, ошибочным у всех, по одному, с
///   уступкой кадру.
class MultiLocaleSpellCheckService implements SpellCheckService {
  MultiLocaleSpellCheckService({
    List<Locale> Function()? deviceLocales,
    Future<List<String>?> Function()? availableLanguages,
    bool? singleSystemCall,
    SpellDictionary? dictionary,
    this.debounce = const Duration(milliseconds: 280),
  }) : _deviceLocales =
           deviceLocales ?? (() => ui.PlatformDispatcher.instance.locales),
       _availableLoader = availableLanguages ?? _loadAvailableSpellLanguages,
       _dictionary = dictionary ?? const _IosSpellDictionary(),
       _singleSystemCall =
           singleSystemCall ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// Сколько ждать паузы в наборе перед проверкой.
  final Duration debounce;

  /// Слов в одном запросе словарю и вариантов за одну проверку — чтобы
  /// вставка очень длинного текста не стала одним длинным кадром.
  static const int _wordsPerCall = 150;
  static const int _guessWordsPerPass = 40;
  static const int _memoryWords = 4000;

  final List<Locale> Function() _deviceLocales;
  final Future<List<String>?> Function() _availableLoader;
  final SpellDictionary _dictionary;
  Future<List<String>?>? _available;

  /// Номер последнего запроса: устаревший отвечает `null` («отменён»).
  int _generation = 0;

  /// Слово → `null` (верно) либо варианты (ошибка). Ключ — со словарями,
  /// которые судили: смена языков не путает ответы.
  final Map<String, List<String>?> _memory = {};

  /// Android: сессия проверки системы одна и сама держит языки клавиатуры
  /// (`referToSpellCheckerLanguageSettings`); вызовы «на других языках»
  /// шли бы в тот же словарь и только мигали. Там — один обычный вызов.
  final bool _singleSystemCall;
  DefaultSpellCheckService? _single;

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    final generation = ++_generation;
    bool stale() => generation != _generation;
    if (debounce > Duration.zero) {
      await Future<void>.delayed(debounce);
      if (stale()) return null;
    }
    final urls = [for (final m in _kUrlLike.allMatches(text)) m];
    if (_singleSystemCall) {
      final spans = await (_single ??= DefaultSpellCheckService())
          .fetchSpellCheckSuggestions(locale, text);
      if (spans == null || stale()) return null;
      return [
        for (final sp in spans)
          if (sp.range.end <= text.length && !_notAWord(text, sp.range, urls))
            sp,
      ];
    }

    final words = <({TextRange range, String word, SpellScript script})>[];
    final present = <SpellScript>{};
    for (final m in _kSpellWord.allMatches(text)) {
      final range = TextRange(start: m.start, end: m.end);
      if (_notAWord(text, range, urls)) continue;
      final word = m.group(0)!;
      final script = scriptOfWord(word);
      present.add(script);
      words.add((range: range, word: word, script: script));
    }
    if (words.isEmpty) return const <SuggestionSpan>[];

    final available = await (_available ??= _availableLoader());
    final judges = _judges(locale, present, available);
    if (judges.values.every((l) => l.isEmpty)) return null;
    // Ошибки сверх предела вариантов: подчёркиваются сейчас, но не
    // запоминаются — в следующий раз им подберут варианты (иначе до конца
    // сеанса по касанию было бы «нет вариантов»).
    final unguessed = <String, List<String>>{};
    if (!await _learn(words, judges, stale, unguessed)) return null;

    final out = <SuggestionSpan>[];
    for (final w in words) {
      final langs = judges[w.script] ?? const <String>[];
      if (langs.isEmpty) continue;
      final key = _key(w.word, langs);
      final found = _memory[key] ?? unguessed[key];
      if (found != null) out.add(SuggestionSpan(w.range, found));
    }
    return out;
  }

  static String _key(String word, List<String> langs) =>
      '${langs.join(',')}|$word';

  /// Словари по алфавитам, которые есть в тексте.
  Map<SpellScript, List<String>> _judges(
    Locale locale,
    Set<SpellScript> present,
    List<String>? available,
  ) {
    final wanted = spellCheckLocales(locale, _deviceLocales());
    final covered = {for (final l in wanted) scriptOfLanguage(l.languageCode)};
    final codes = {for (final l in wanted) l.languageCode.toLowerCase()};
    final all = <Locale>[...wanted];
    // Алфавиты, которые есть в тексте, но не покрыты языками человека.
    for (final s in present) {
      if (covered.contains(s)) continue;
      for (final c in _scriptFallbackLanguages[s] ?? const <String>[]) {
        if (codes.add(c)) all.add(Locale(c));
      }
    }
    final out = <SpellScript, List<String>>{for (final s in present) s: []};
    for (final l in all) {
      // Язык, чьего алфавита в тексте нет, не спрашиваем.
      final list = out[scriptOfLanguage(l.languageCode)];
      if (list == null) continue;
      final resolved = resolveSpellLocale(l, available);
      if (resolved == null) continue;
      final country = resolved.countryCode;
      list.add(
        country == null || country.isEmpty
            ? resolved.languageCode
            : '${resolved.languageCode}_$country',
      );
    }
    return out;
  }

  /// Узнать незнакомые слова. `false` — запрос устарел (узнанное остаётся).
  Future<bool> _learn(
    List<({TextRange range, String word, SpellScript script})> words,
    Map<SpellScript, List<String>> judges,
    bool Function() stale,
    Map<String, List<String>> unguessed,
  ) async {
    var guessed = 0;
    for (final MapEntry(key: script, value: langs) in judges.entries) {
      if (langs.isEmpty) continue;
      final unknown = <String>{
        for (final w in words)
          if (w.script == script && !_memory.containsKey(_key(w.word, langs)))
            w.word,
      }.toList();
      for (var i = 0; i < unknown.length; i += _wordsPerCall) {
        final chunk = unknown.sublist(
          i,
          i + _wordsPerCall > unknown.length
              ? unknown.length
              : i + _wordsPerCall,
        );
        var suspects = chunk;
        final asked = <String>[];
        for (final lang in langs) {
          if (suspects.isEmpty) break;
          final wrong = await _wrongWords(suspects, lang);
          if (stale()) return false;
          if (wrong == null) continue; // Словаря нет — не судит.
          asked.add(lang);
          suspects = wrong;
        }
        // Ни один словарь не ответил — молчим и не запоминаем.
        if (asked.isEmpty) continue;
        final bad = suspects.toSet();
        for (final word in chunk) {
          if (!bad.contains(word)) _remember(_key(word, langs), null);
        }
        for (final word in suspects) {
          if (guessed >= _guessWordsPerPass) {
            unguessed[_key(word, langs)] = const <String>[];
            continue;
          }
          final options = <String>{};
          guessed++;
          for (final lang in asked) {
            try {
              options.addAll(await _dictionary.guesses(word, lang));
            } catch (_) {}
            if (options.length >= 5) break;
          }
          _remember(
            _key(word, langs),
            options.take(5).toList(growable: false),
          );
          if (stale()) return false;
          // Кадр между словами: набор и прокрутка не ждут словаря.
          await Future<void>.delayed(const Duration(milliseconds: 8));
          if (stale()) return false;
        }
      }
    }
    return true;
  }

  Future<List<String>?> _wrongWords(List<String> words, String lang) async {
    final List<TextRange>? ranges;
    try {
      ranges = await _dictionary.check(words.join('\n'), lang);
    } catch (_) {
      return null; // Нет системной проверки — поле работает как раньше.
    }
    if (ranges == null) return null;
    final out = <String>[];
    var start = 0;
    var r = 0;
    for (final word in words) {
      final end = start + word.length;
      while (r < ranges.length && ranges[r].end <= start) {
        r++;
      }
      if (r < ranges.length && ranges[r].start < end) out.add(word);
      start = end + 1;
    }
    return out;
  }

  void _remember(String key, List<String>? value) {
    if (_memory.length >= _memoryWords) _memory.remove(_memory.keys.first);
    _memory[key] = value;
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
