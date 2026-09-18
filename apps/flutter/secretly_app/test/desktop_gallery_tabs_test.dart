// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Категории галереи делят ширину панели поровну.
//
// 🔴 Проверяется геометрия, а не флаг. `isScrollable: false` можно вернуть в
// `true` одной правкой «чтобы влезало», и код при этом останется валидным —
// сломается только вид. Тест меряет ШИРИНЫ вкладок, поэтому такая правка
// обязана быть осознанной.
//
// И отдельно: подпись не имеет права обрезаться на узкой панели. «Музы…» —
// это хуже, чем мелкое «Музыка», потому что человек не понимает, что он
// потерял.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final code = File(
    'lib/ui/desktop/chat/details/desktop_media_gallery.dart',
  ).readAsStringSync();

  test('🔴 вкладки не прокручиваются, а делят ширину', () {
    expect(
      code.contains('isScrollable: false'),
      isTrue,
      reason:
          'со `isScrollable: true` четыре слова жались к левому краю, '
          'а справа росла пустота по мере расширения панели',
    );
    expect(
      code.contains('TabAlignment.start'),
      isFalse,
      reason: 'выравнивание по левому краю — это и был перекос',
    );
  });

  test('🔴 подпись ужимается, а не обрезается', () {
    expect(
      code.contains('BoxFit.scaleDown'),
      isTrue,
      reason:
          'на минимальной ширине панели «Музыка» не влезает; обрезка '
          'скрывает от человека, что именно он потерял',
    );
  });

  group('на настоящей раскладке', () {
    Widget host(double width) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: DefaultTabController(
              length: 4,
              child: TabBar(
                isScrollable: false,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                tabs: const [
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Фото', maxLines: 1),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Видео', maxLines: 1),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Файлы', maxLines: 1),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Музыка', maxLines: 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('места вкладок делятся поровну на любой ширине', (t) async {
      // 🔴 Меряем ЦЕНТРЫ, а не ширины самих вкладок.
      //
      // `Tab` обжимается по своей подписи: «Фото» короче «Музыки» и поэтому
      // уже неё. Делятся поровну не надписи, а МЕСТА под них, и симметрия —
      // это ровный шаг между центрами. Померив ширины, тест ругался бы на
      // правильную раскладку ровно за то, что слова разной длины.
      //
      // 260 — минимум панели по правилу уступок, 330 — обычная ширина,
      // 520 — растянутая. Шаг обязан держаться во всех трёх.
      for (final width in <double>[260, 330, 520]) {
        await t.pumpWidget(host(width));
        await t.pumpAndSettle();

        final centers = t
            .widgetList<Tab>(find.byType(Tab))
            .map((tab) => t.getRect(find.byWidget(tab)).center.dx)
            .toList();

        expect(centers.length, 4);
        final slot = width / 4;
        for (var i = 0; i < 4; i++) {
          expect(
            centers[i],
            closeTo(slot * (i + 0.5), 0.5),
            reason: 'при ширине $width вкладки встали неровно: $centers',
          );
        }
      }
    });

    testWidgets('🔴 панель растянули — вкладки разъехались вместе с ней', (
      t,
    ) async {
      // Прямая формулировка просьбы владельца: категории должны
      // РАСТЯГИВАТЬСЯ при увеличении панели, а не стоять кучкой слева.
      double spread(double width) {
        final centers = t
            .widgetList<Tab>(find.byType(Tab))
            .map((tab) => t.getRect(find.byWidget(tab)).center.dx)
            .toList();
        return centers.last - centers.first;
      }

      await t.pumpWidget(host(330));
      await t.pumpAndSettle();
      final narrow = spread(330);

      await t.pumpWidget(host(520));
      await t.pumpAndSettle();
      final wide = spread(520);

      expect(
        wide - narrow,
        closeTo((520 - 330) * 0.75, 1.0),
        reason:
            'расстояние между крайними вкладками растёт вместе с панелью; '
            'при прокручиваемой полосе оно не менялось бы вовсе',
      );
    });

    testWidgets('🔴 узкая панель не рвёт раскладку', (t) async {
      await t.pumpWidget(host(240));
      await t.pump();

      expect(
        t.takeException(),
        isNull,
        reason: '«Музыка» должна ужаться, а не переполнить вкладку',
      );
      expect(find.text('Музыка'), findsOneWidget);
    });
  });
}
