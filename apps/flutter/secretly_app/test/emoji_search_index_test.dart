// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/emoji/emoji_search_index.dart';
import 'package:secretly_app/ui/emoji/noto_emoji_catalog.dart';

// Поиск эмодзи (09.08.2026).
//
// Дефект: фильтр сравнивал набранное с ШЕСТНАДЦАТЕРИЧНЫМ кодом символа
// (`'😀': '1f600'`), поэтому не искался НИ ОДИН из 881 эмодзи — ни по-русски, ни
// по-английски. Первый тест в файле — про сам дефект: он обязан падать на старом
// поведении.

List<String> find(String query) =>
    filterEmojiByQuery(kNotoCodepoints.keys, query);

void main() {
  group('🔴 сам дефект', () {
    test('слово находит эмодзи — по-русски И по-английски', () {
      // На старом поведении оба списка были пустыми: код `1f600` не содержит ни
      // «улыб», ни «smile».
      expect(find('улыбка'), contains('😀'));
      expect(find('smile'), contains('😀'));
    });

    test('частые слова находят ожидаемое', () {
      expect(find('смех'), contains('😂'));
      expect(find('любовь'), contains('🥰'));
      expect(find('лайк'), contains('👍'));
      expect(find('огонь'), contains('🔥'));
      expect(find('сердце'), contains('❤️'));
      expect(find('плачу'), contains('😭'));
      expect(find('спасибо'), contains('🙏'));
      expect(find('праздник'), contains('🎉'));
    });

    test('поиск шестнадцатеричным кодом больше не выдаёт мусор', () {
      // Раньше «1f6» возвращало сотни символов — это и был весь «поиск».
      expect(find('1f600'), isEmpty);
    });
  });

  group('совпадение по началу — в обе стороны', () {
    test('набранное как начало слова', () {
      expect(find('улыб'), contains('😀'));
      expect(find('смеш'), isNotEmpty);
    });

    test('слово как начало набранного: склонения и спряжения', () {
      // Держать все формы русского слова в словаре бессмысленно.
      expect(find('улыбаться'), contains('😀'));
      expect(find('обнимашки'), contains('🤗'));
      expect(find('злость'), contains('😡'));
    });

    test('регистр и ё не мешают', () {
      expect(find('СМЕХ'), contains('😂'));
      expect(find('  Слёзы  '), isNotEmpty);
    });
  });

  group('🔴 тона кожи наследуют слова базового символа', () {
    test('👍 с тоном находится по «лайк»', () {
      // В каталоге 👍 лежит шестью записями. Писать слова каждой значило бы
      // утроить словарь — вместо этого тон снимается перед поиском.
      final hits = find('лайк');
      expect(hits, contains('👍'));
      expect(hits, contains('👍🏽'));
    });

    test('снятие тона и селектора не портит обычный символ', () {
      expect(emojiSearchBase('👍🏿'), '👍');
      expect(emojiSearchBase('❤️'), '❤');
      expect(emojiSearchBase('😀'), '😀');
    });

    test('символ, состоящий только из модификатора, не превращается в пустоту', () {
      // Иначе такой ключ совпал бы с любым запросом.
      expect(emojiSearchBase('🏽'), '🏽');
    });
  });

  group('второй слой: слова категории', () {
    test('🔴 символ без своих слов находится по категории', () {
      // Без этого слоя дефект остался бы для большей части каталога: своих слов
      // написано триста, а символов 881.
      expect(find('животное'), isNotEmpty);
      expect(find('еда'), isNotEmpty);
      expect(find('символ'), isNotEmpty);
    });

    test('категория не подменяет собственные слова', () {
      // «кот» обязан вернуть кошачьи морды, а не всех животных подряд.
      final hits = find('кот');
      expect(hits, contains('😺'));
      expect(hits.length, lessThan(40));
    });
  });

  group('границы', () {
    test('пустой запрос отдаёт всё без фильтра', () {
      expect(find('').length, kNotoCodepoints.length);
      expect(find('   ').length, kNotoCodepoints.length);
    });

    test('вставленный символ находит себя', () {
      expect(find('😂'), contains('😂'));
    });

    test('бессмысленный запрос честно даёт пустоту', () {
      expect(find('щщщщщ'), isEmpty);
      expect(find('zzzzzz'), isEmpty);
    });
  });

  group('целостность словаря', () {
    test('🔴 в словаре нет мёртвых записей', () {
      // Слова для символа, которого нет в анимированном наборе, — это шум,
      // который со временем расходится с каталогом. Генератор такие выбрасывает,
      // и этот тест держит его честным.
      final known = kNotoCodepoints.keys.map(emojiSearchBase).toSet();
      final dead = kEmojiSearchWords.keys
          .where((e) => !known.contains(e))
          .toList();
      expect(dead, isEmpty, reason: 'нет в каталоге Noto: ${dead.join(' ')}');
    });

    test('🔴 нет основ из одной буквы', () {
      // Одна буква совпала бы почти с любым запросом. Двухбуквенные разрешены:
      // «ок», «да», «no», «tv» — настоящие слова, и правило совпадения
      // применяет их только как набираемое начало.
      for (final entry in kEmojiSearchWords.entries) {
        for (final word in entry.value) {
          expect(
            word.length,
            greaterThanOrEqualTo(2),
            reason: '${entry.key}: «$word»',
          );
        }
      }
    });

    test('🔴 короткая основа не ловит длинный посторонний запрос', () {
      // Это и есть цена двухбуквенных слов, если применять их в обе стороны:
      // «окно» стало бы 👌, а «давай» — ✅.
      expect(find('ок'), contains('👌'));
      expect(find('окно'), isNot(contains('👌')));
      expect(find('давай'), isNot(contains('✅')));
    });

    test('основа от трёх букв ловит форму слова', () {
      expect(find('ухо'), contains('👂'));
      expect(find('охнул'), isNotEmpty);
    });

    test('слова записаны в нижнем регистре', () {
      for (final entry in kEmojiSearchWords.entries) {
        for (final word in entry.value) {
          expect(word, word.toLowerCase(), reason: entry.key);
        }
      }
    });

    test('у каждой категории каталога есть свои слова', () {
      for (final slug in kNotoCategories.values.toSet()) {
        expect(
          kEmojiCategorySearchWords.containsKey(slug),
          isTrue,
          reason: 'категория без слов: $slug',
        );
      }
    });
  });
}
