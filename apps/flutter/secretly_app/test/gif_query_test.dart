// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/gifs/gif_query.dart';

// Поиск гифок по-русски (09.08.2026).
//
// Жалоба владельца: «поиск работает только на англ языке». Проверяется не запрос
// к сети, а РЕШЕНИЕ: что и в каком порядке спросить у GIPHY. Ошибка здесь стоит
// человеку пустого экрана при живой сети — то есть выглядит как поломка.

void main() {
  group('план запроса', () {
    test('пустой запрос — пустой план, это «популярное»', () {
      expect(gifQueryPlan(''), isEmpty);
      expect(gifQueryPlan('   '), isEmpty);
    });

    test('латиница спрашивается один раз и как есть', () {
      expect(gifQueryPlan('cat'), <GifQueryAttempt>[
        const GifQueryAttempt(term: 'cat', lang: 'en'),
      ]);
    });

    test('🔴 русское слово из словаря спрашивается ПО-АНГЛИЙСКИ первым', () {
      // Английский корпус GIPHY на порядки богаче. Спросить сначала по-русски
      // значит почти наверняка получить пустоту и потратить второй запрос.
      final plan = gifQueryPlan('кот');
      expect(plan.first, const GifQueryAttempt(term: 'cat', lang: 'en'));
      expect(plan.last, const GifQueryAttempt(term: 'кот', lang: 'ru'));
    });

    test('🔴 русское слово ВНЕ словаря: сначала как есть, потом транслитом', () {
      final plan = gifQueryPlan('чебурашка');
      expect(plan.first, const GifQueryAttempt(term: 'чебурашка', lang: 'ru'));
      expect(plan.last, const GifQueryAttempt(term: 'cheburashka', lang: 'en'));
    });

    test('🔴 язык привязан к ПОПЫТКЕ, а не к запросу человека', () {
      // Один язык на весь план был бы ошибкой: английский перевод спросили бы
      // с lang=ru и снова получили пустоту.
      final plan = gifQueryPlan('привет');
      expect(plan.map((a) => a.lang).toList(), <String>['en', 'ru']);
    });

    test('🔴 план не длиннее двух попыток', () {
      // Третья попытка стоит человеку ещё одного ожидания, а шансов добавляет
      // мало.
      for (final q in <String>['кот', 'чебурашка', 'обнимашки', 'привет мир']) {
        expect(gifQueryPlan(q).length, lessThanOrEqualTo(2), reason: q);
      }
    });

    test('нет пустых слов в плане', () {
      for (final q in <String>['кот', '...', 'ъь', 'привет']) {
        for (final attempt in gifQueryPlan(q)) {
          expect(attempt.term.trim(), isNotEmpty, reason: q);
        }
      }
    });

    test('запрос из одних мягких знаков не даёт пустой попытки', () {
      // «ъь» транслитерируется в пустоту — такая попытка не имеет права уехать.
      final plan = gifQueryPlan('ъь');
      expect(plan, hasLength(1));
      expect(plan.single.term, 'ъь');
    });
  });

  group('словарь', () {
    test('фраза важнее отдельного слова', () {
      // «день рождения» это не «день».
      expect(gifEnglishTermFor('день рождения'), 'birthday');
      expect(gifEnglishTermFor('с днем рождения'), 'happy birthday');
    });

    test('ё и регистр не мешают', () {
      expect(gifEnglishTermFor('Слёзы'), 'crying');
      expect(gifEnglishTermFor('  ПРИВЕТ  '), 'hello');
    });

    test('основа слова ловит склонения и спряжения', () {
      // Держать все формы русского слова в словаре бессмысленно.
      expect(gifEnglishTermFor('люблю'), 'love');
      expect(gifEnglishTermFor('любовь'), 'love');
      expect(gifEnglishTermFor('обнимаю'), 'hug');
      expect(gifEnglishTermFor('танцевать'), 'dance');
      expect(gifEnglishTermFor('поздравления'), 'congratulations');
    });

    test('слово из середины фразы тоже находится', () {
      expect(gifEnglishTermFor('очень смешно получилось'), 'funny');
    });

    test('неизвестное слово честно возвращает null', () {
      expect(gifEnglishTermFor('чебурашка'), isNull);
      expect(gifEnglishTermFor(''), isNull);
    });

    test('короткие основы не дают ложных попаданий', () {
      // «радио» не про радость, и раньше основа «рад» его ловила.
      expect(gifEnglishTermFor('радио'), isNull);
    });
  });

  group('транслитерация', () {
    test('звучание, а не побуквенная замена', () {
      expect(gifTransliterate('привет'), 'privet');
      expect(gifTransliterate('кошка'), 'koshka');
      expect(gifTransliterate('щенок'), 'schenok');
      expect(gifTransliterate('ёлка'), 'elka');
    });

    test('латиница проходит насквозь', () {
      expect(gifTransliterate('cat'), 'cat');
    });
  });

  group('определение кириллицы', () {
    test('видит русские буквы', () {
      expect(gifQueryLooksCyrillic('кот'), isTrue);
      expect(gifQueryLooksCyrillic('cat кот'), isTrue);
    });

    test('не видит там, где их нет', () {
      expect(gifQueryLooksCyrillic('cat'), isFalse);
      expect(gifQueryLooksCyrillic('123 :)'), isFalse);
      expect(gifQueryLooksCyrillic(''), isFalse);
    });
  });
}
