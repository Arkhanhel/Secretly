// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Переводчик (22.11.2026, Т-1): «русский переводился на русский». Правила
// «тот же язык или нет» — чистые функции, без ML Kit.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/translation/translation_languages.dart';
import 'package:secretly_app/translation/translation_rules.dart';
import 'package:secretly_app/translation/translation_service.dart';

SourceDecision _d(
  List<(String, double)> candidates,
  String text, {
  String target = 'ru',
  bool user = true,
  String? pinned,
}) => TranslationRules.decideSource(
  candidates: candidates,
  target: target,
  cleanedText: TranslationText.forDetection(text),
  userInitiated: user,
  pinnedSource: pinned,
);

void main() {
  test('выключатель новых правил включён', () {
    expect(kTranslationStrictSameLanguage, isTrue);
  });

  group('письменность', () {
    test('основная письменность текста', () {
      expect(TranslationRules.dominantScript('Привет'), TextScript.cyrillic);
      expect(TranslationRules.dominantScript('Hello'), TextScript.latin);
      expect(TranslationRules.dominantScript('こんにちは'), TextScript.kana);
      expect(TranslationRules.dominantScript('今日は晴れです'), TextScript.kana);
      expect(TranslationRules.dominantScript('你好'), TextScript.han);
      expect(TranslationRules.dominantScript('안녕하세요'), TextScript.hangul);
      expect(TranslationRules.dominantScript('Γεια σου'), TextScript.greek);
      expect(TranslationRules.dominantScript('Hi, привет всем'), TextScript.cyrillic);
      expect(TranslationRules.dominantScript('123 !!!'), TextScript.none);
    });

    test('письменность единственного языка = язык перевода → уже на нём', () {
      expect(_d(const [], '안녕하세요', target: 'ko').verdict,
          SourceVerdict.sameLanguage);
      expect(_d(const [], 'Γεια σου', target: 'el', user: false).verdict,
          SourceVerdict.sameLanguage);
      expect(_d(const [], 'こんにちは', target: 'ja').verdict,
          SourceVerdict.sameLanguage);
    });

    test('короткий греческий без кандидатов — переводится с греческого', () {
      final d = _d(const [], 'Γεια', user: false);
      expect(d.verdict, SourceVerdict.translate);
      expect(d.source, 'el');
    });

    test('язык перевода — латиница, текст кириллицей: сосед не нужен', () {
      final d = _d(const [('ru', 0.9)], 'Привет', target: 'en', user: false);
      expect(d.verdict, SourceVerdict.translate);
      expect(d.source, 'ru');
    });
  });

  group('буквы ru / uk / be', () {
    test('признаки по буквам', () {
      expect(TranslationRules.eastSlavicHint('Привіт, як справи?'), 'uk');
      expect(TranslationRules.eastSlavicHint('Їж'), 'uk');
      expect(TranslationRules.eastSlavicHint('Ґанок'), 'uk');
      expect(TranslationRules.eastSlavicHint('Ты где?'), 'ru');
      expect(TranslationRules.eastSlavicHint('Это'), 'ru');
      expect(TranslationRules.eastSlavicHint('Ёлка'), 'ru');
      expect(TranslationRules.eastSlavicHint('Ўсё'), 'be');
      expect(
        TranslationRules.eastSlavicHint('Дзякуй, усё выдатна і добра'),
        'be',
      );
      // Без особых букв — решают кандидаты.
      expect(TranslationRules.eastSlavicHint('Привет как дела'), isNull);
      // «ъ» есть и в болгарском — не признак русского.
      expect(TranslationRules.eastSlavicHint('Къде си?'), isNull);
      // Противоречие — не решаем.
      expect(TranslationRules.eastSlavicHint('їы'), isNull);
    });

    test('«ы» при соседе впереди — уже русский (короткая фраза)', () {
      final d = _d(const [('uk', 0.5), ('ru', 0.3)], 'Ты где?');
      expect(d.verdict, SourceVerdict.sameLanguage);
      expect(
        _d(const [('bg', 0.7)], 'Ты где?', user: false).verdict,
        SourceVerdict.sameLanguage,
      );
    });

    test('украинский с «і» переводится на русский — и по нажатию, и сам', () {
      for (final user in [true, false]) {
        final d = _d(const [('ru', 0.5)], 'Привіт, як справи?', user: user);
        expect(d.verdict, SourceVerdict.translate);
        expect(d.source, 'uk');
      }
    });

    test('русский с «ё» на украинский — переводится с русского', () {
      final d = _d(const [('uk', 0.4)], 'Всё хорошо', target: 'uk');
      expect(d.verdict, SourceVerdict.translate);
      expect(d.source, 'ru');
    });
  });

  group('транслит', () {
    test('ru-Latn при переводе на русский — уже русский', () {
      expect(
        _d(const [('ru-Latn', 0.8), ('en', 0.1)], 'privet kak dela').verdict,
        SourceVerdict.sameLanguage,
      );
      expect(
        _d(const [('en', 0.4), ('ru-Latn', 0.3)], 'privet kak dela').verdict,
        SourceVerdict.sameLanguage,
      );
    });

    test('чужой транслит — «не распознан»', () {
      expect(
        _d(const [('hi-Latn', 0.8)], 'kya haal hai', target: 'en').verdict,
        SourceVerdict.undetected,
      );
    });
  });

  group('соседи', () {
    test('группы соседей', () {
      expect(TranslationRules.areNeighbours('es', 'pt'), isTrue);
      expect(TranslationRules.areNeighbours('ru', 'uk'), isTrue);
      expect(TranslationRules.areNeighbours('da', 'sv'), isTrue);
      expect(TranslationRules.areNeighbours('ms', 'id'), isTrue);
      expect(TranslationRules.areNeighbours('ru', 'en'), isFalse);
      expect(TranslationRules.areNeighbours('ru', 'ru'), isFalse);
    });

    test('🔴 сам случай жалобы: ru 0,4 и uk 0,35 — уже русский', () {
      expect(
        _d(const [('ru', 0.4), ('uk', 0.35)], 'Привет как дела').verdict,
        SourceVerdict.sameLanguage,
      );
      expect(
        _d(const [('uk', 0.4), ('ru', 0.35)], 'Привет как дела').verdict,
        SourceVerdict.sameLanguage,
      );
      expect(
        _d(const [('uk', 0.55), ('ru', 0.4)], 'Привет как дела', user: false)
            .verdict,
        SourceVerdict.sameLanguage,
      );
    });

    test('авторежим: сосед с запасом и без языка перевода — переводит', () {
      final d = _d(const [('bg', 0.7), ('ru', 0.1)], 'Как си днес', user: false);
      expect(d.verdict, SourceVerdict.translate);
      expect(d.source, 'bg');
    });

    test('авторежим: испанский при переводе на португальский рядом — нет', () {
      expect(
        _d(
          const [('es', 0.6), ('pt', 0.45)],
          'Hola, que tal',
          target: 'pt',
          user: false,
        ).verdict,
        SourceVerdict.sameLanguage,
      );
    });
  });

  group('авторежим и нажатие', () {
    test('авторежим не уверен — молча пропускает', () {
      expect(
        _d(const [('en', 0.45)], 'hm ok', user: false).verdict,
        SourceVerdict.undetected,
      );
    });

    test('авторежим: язык перевода среди кандидатов ≥ 0,25 — никогда', () {
      expect(
        _d(const [('en', 0.6), ('ru', 0.3)], 'Hello', user: false).verdict,
        SourceVerdict.sameLanguage,
      );
    });

    test('авторежим: уверенно другой язык — переводит', () {
      final d = _d(const [('en', 0.9)], 'Hello my friend', user: false);
      expect(d.verdict, SourceVerdict.translate);
      expect(d.source, 'en');
    });

    test('нажатие: уверенно язык перевода — уже на нём', () {
      expect(
        _d(const [('ru', 0.8)], 'Привет как дела').verdict,
        SourceVerdict.sameLanguage,
      );
    });

    test('нажатие: язык перевода слабый, запасной не сосед — переводит', () {
      final d = _d(const [('ru', 0.2), ('en', 0.15)], 'ok cool');
      expect(d.verdict, SourceVerdict.translate);
      expect(d.source, 'en');
    });
  });

  group('выбранный язык оригинала', () {
    test('🔴 «с украинского», текст русский — уже русский', () {
      const text = 'Привет, как дела? Что делаешь?';
      for (final user in [true, false]) {
        expect(
          _d(const [('ru', 0.9)], text, pinned: 'uk', user: user).verdict,
          SourceVerdict.sameLanguage,
        );
      }
      expect(
        _d(const [('ru', 0.45), ('uk', 0.4)], text, pinned: 'uk').verdict,
        SourceVerdict.sameLanguage,
      );
    });

    test('«с английского», текст кириллицей — уже на языке перевода', () {
      expect(
        _d(const [], 'Привет', pinned: 'en').verdict,
        SourceVerdict.sameLanguage,
      );
    });

    test('авторежим пропускает уверенно другой язык, нажатие — нет', () {
      expect(
        _d(const [('de', 0.9)], 'Guten Morgen', pinned: 'en', user: false)
            .verdict,
        SourceVerdict.undetected,
      );
      final d = _d(const [('de', 0.9)], 'Guten Morgen', pinned: 'en');
      expect(d.verdict, SourceVerdict.translate);
      expect(d.source, 'en');
    });

    test('совпадает с языком сообщения — переводит', () {
      final d = _d(const [('en', 0.9)], 'Hello', pinned: 'en', user: false);
      expect(d.verdict, SourceVerdict.translate);
      expect(d.source, 'en');
    });

    test('«с» = «на» — уже на этом языке', () {
      expect(
        _d(const [('en', 0.9)], 'Hello', pinned: 'ru').verdict,
        SourceVerdict.sameLanguage,
      );
      expect(
        _d(const [('en', 0.9)], 'Hello', pinned: 'en', target: 'en').verdict,
        SourceVerdict.sameLanguage,
      );
    });
  });

  group('«перевод почти совпал»', () {
    test('совпадение слов ≥ 80 %', () {
      expect(
        TranslationRules.looksUnchanged('Привет, как дела?', 'Привет как дела'),
        isTrue,
      );
      expect(TranslationRules.looksUnchanged('Ёлка', 'елка'), isTrue);
      expect(
        TranslationRules.looksUnchanged('Hello friend', 'Привет друг'),
        isFalse,
      );
      expect(
        TranslationRules.looksUnchanged('Я иду домой сейчас', 'Я иду домой'),
        isFalse,
      );
      expect(TranslationRules.looksUnchanged('Ok', 'Ок'), isFalse);
      expect(TranslationRules.looksUnchanged('', 'x'), isFalse);
      expect(TranslationRules.looksUnchanged('123', '123'), isFalse);
    });
  });

  group('пусто, эмодзи, ссылки', () {
    test('нечего определять — «не распознан», без исключений', () {
      expect(TranslationText.forDetection('👍🔥 https://a.b'), '');
      expect(_d(const [], '👍🔥 https://a.b').verdict, SourceVerdict.undetected);
      expect(
        _d(const [], '', user: false).verdict,
        SourceVerdict.undetected,
      );
    });
  });

  group('список языков', () {
    // 59 языков ML Kit (google_mlkit_translation 0.13.1, TranslateLanguage).
    const mlKit = <String>{
      'af', 'sq', 'ar', 'be', 'bn', 'bg', 'ca', 'zh', 'hr', 'cs', 'da', 'nl',
      'en', 'eo', 'et', 'fi', 'fr', 'gl', 'ka', 'de', 'el', 'gu', 'ht', 'he',
      'hi', 'hu', 'is', 'id', 'ga', 'it', 'ja', 'kn', 'ko', 'lv', 'lt', 'mk',
      'ms', 'mt', 'mr', 'no', 'fa', 'pl', 'pt', 'ro', 'ru', 'sk', 'sl', 'es',
      'sw', 'sv', 'tl', 'ta', 'te', 'th', 'tr', 'uk', 'ur', 'vi', 'cy',
    };

    test('все 59, без повторов, 16 популярных — прежние и по порядку', () {
      final codes = kAllTranslationLanguages.map((l) => l.code).toList();
      expect(codes.length, 59);
      expect(codes.toSet(), mlKit);
      expect(kPopularTranslationLanguages.map((l) => l.code).toList(), [
        'en', 'ru', 'uk', 'es', 'pt', 'fr', 'de', 'it', //
        'pl', 'tr', 'nl', 'zh', 'ja', 'ko', 'ar', 'hi',
      ]);
      expect(translationLanguageLabel('ru'), '🇷🇺  Русский');
      expect(translationLanguageLabel('xx'), 'xx');
    });
  });
}
