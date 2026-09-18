// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// · Шкала отступов: у макета нет сетки 4, и притворяться, что есть, нельзя.
//
// ЧТО БЫЛО. `DSpace` знал только чётные 4/8/12/16/20/24/32/48 — «сетку 4» из
// легенды макета. Сама разметка макета этой легенде НЕ следует: пересчёт по
// файлу даёт зазоры 10 (40 раз), 6 (39), 8 (34), 5 (30), 9 (29), 7 (22) и
// отступы 10 (54), 8 (46), 9 (40), 12 (26), 11 (25), 5 (24), 14 (22).
//
// Пока нечётные ступени были невыразимы, каждая девятка превращалась в
// восьмёрку или двенадцать — а где не превращалась, там писали числом мимо
// шкалы (`DSpace.s + 2` вместо десятки). Расхождение накапливалось там, где
// оно заметнее всего: высота строки списка, поля пузыря, фишка реакции.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/spacing.dart';

void main() {
  group('ступени макета выражаются', () {
    test('· нечётные ступени заведены', () {
      expect(DSpace.p5, 5);
      expect(DSpace.p6, 6);
      expect(DSpace.p7, 7);
      expect(DSpace.p9, 9);
      expect(DSpace.p11, 11);
      expect(DSpace.p13, 13);
    });

    test('· чётные, которых не было в сетке 4, — тоже', () {
      expect(DSpace.p10, 10);
      expect(DSpace.p14, 14);
    });

    test('🔴 старые имена не тронуты: за ними 450 обращений', () {
      expect(DSpace.xs, 4);
      expect(DSpace.s, 8);
      expect(DSpace.m, 12);
      expect(DSpace.l, 16);
      expect(DSpace.xl, 20);
      expect(DSpace.xl2, 24);
      expect(DSpace.xl3, 32);
      expect(DSpace.xl4, 48);
    });

    test('· докстринг не выдаёт «сетку 4» за правило', () {
      // Легенда макета её объявляет, а разметка не соблюдает; цитировать
      // легенду как правило значит закрепить расхождение.
      final src = File(
        'lib/ui/desktop/design/spacing.dart',
      ).readAsStringSync();
      expect(src.contains('сама разметка макета ей НЕ'), isTrue);
      expect(src.contains('каждое целое от 5 до 14'), isTrue);
    });
  });

  group('· строка списка чатов — 9 и 10 из макета', () {
    final src = File(
      'lib/ui/desktop/chat/chat_list_panel.dart',
    ).readAsStringSync();

    test('отступы строки', () {
      // 14.09: портрет 42 плюс девятки = 60 точек, как в макете.
      // 16.09: по замерам скриншота телеграма от владельца — шаг строк 70,
      // портрет 50 и три строки текста (имя 18 и две строки превью по 16),
      // то есть те же девятки по вертикали, но рост 50 вместо 42.
      expect(
        src.contains(
          'horizontal: DSpace.p10,\n                  vertical: DSpace.p9,',
        ),
        isTrue,
      );
      expect(src.contains('static const double avatar = 50;'), isTrue);
      expect(src.contains('size: _avatar,'), isTrue);
      // Обходного «DSpace.s + 2» больше нет: ступень 10 теперь существует.
      expect(src.contains('DSpace.s + 2'), isFalse);
    });

    test('зазор портрет↔текст — 10, а не 12', () {
      expect(src.contains('const SizedBox(width: DSpace.p10),'), isTrue);
    });
  });

  group('· пузырь и фишка реакции', () {
    final src = File(
      'lib/ui/desktop/chat/message_bubble.dart',
    ).readAsStringSync();

    test('поля пузыря — 10 сверху, 13 по бокам, 8 снизу', () {
      expect(src.contains('EdgeInsets.fromLTRB(13, 10, 13, 8)'), isTrue);
    });

    test('🔴 боковое поле 13 у ВСЕХ видов пузыря, а не только у текстового', () {
      // Иначе подпись под снимком и текст в соседнем пузыре стояли бы на
      // разном расстоянии от края — на точку, но в столбик и заметно.
      expect(src.contains('fromLTRB(14, '), isFalse);
      expect(src.contains(', 14, '), isFalse);
    });

    test('🔴 фишка реакции — ТЕЛЕГРАМНАЯ геометрия', () {
      // 14.09 здесь стояли числа макета (9 по бокам, 26 высоты): фишки жили
      // отдельной строкой ПОД пузырём и могли быть крупнее.
      // 16.09 владелец велел вернуть их ВНУТРЬ пузыря «как в мобильной».
      // 16.09 он же: «реакции слишком большие» — со скриншотом телеграма.
      // Внутри пузыря фишка обязана быть мельче текста, рядом с которым
      // стоит: знак 15-й, поля 6×2, радиус 10, весь рост около двадцати.
      expect(src.contains('EdgeInsets.fromLTRB(6, 2, 6, 2)'), isTrue);
      expect(src.contains('BorderRadius.circular(10)'), isTrue);
      expect(
        src.contains('EdgeInsets.fromLTRB(7, 3, 7, 3)'),
        isFalse,
        reason: 'крупная фишка вернулась',
      );
      final i = src.indexOf('Widget _reactionsRow(');
      final row = src.substring(i, i + 700);
      expect(row.contains('spacing: 6,'), isTrue);
      expect(row.contains('runSpacing: 6,'), isTrue);
    });
  });
}
