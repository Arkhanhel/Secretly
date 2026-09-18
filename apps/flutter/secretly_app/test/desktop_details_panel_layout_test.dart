// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Правая панель ОТРИСОВЫВАЕТСЯ, а не молча остаётся пустой.
//
// 🔴 ПОЧЕМУ ЭТОТ ТЕСТ ЕСТЬ.
//
// 14.09.2026 ряд действий получил `crossAxisAlignment: stretch`. Ряд лежит в
// колонке с прокруткой — высота неограниченная, — и `stretch` потребовал от
// плиток занять бесконечность. Панель перестала рисоваться ЦЕЛИКОМ: чёрный
// прямоугольник вместо портрета, имени и всех кнопок.
//
// Заметить это можно было только глазами: в журнале приложения не появилось
// ни строки. Поэтому здесь живут дешёвые проверки «оно вообще строится» на те
// части панели, у которых своя геометрия.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/details/details_action_row.dart';
import 'package:secretly_app/ui/desktop/chat/details/details_headline.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/desktop_switch.dart';

Widget host(Widget child) => MaterialApp(
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: SizedBox(
            width: 360,
            // Именно так панель и устроена: узкая колонка с прокруткой, то
            // есть НЕОГРАНИЧЕННАЯ по высоте. Тест без прокрутки прошёл бы.
            child: SingleChildScrollView(child: Column(children: [child])),
          ),
        ),
      ),
    );

void main() {
  testWidgets('ряд действий строится в колонке с прокруткой', (t) async {
    await t.pumpWidget(host(
      DetailsActionRow(items: [
        DetailsActionItem(icon: Icons.call, label: 'Звонок', onPressed: () {}),
        DetailsActionItem(icon: Icons.videocam, label: 'Видео', onPressed: () {}),
        DetailsActionItem(icon: Icons.notifications, label: 'Звук', onPressed: () {}),
        DetailsActionItem(
          icon: Icons.block,
          label: 'Блок',
          danger: true,
          onPressed: () {},
        ),
      ]),
    ));
    expect(lastRenderError(), isNull);
    expect(find.text('Звонок'), findsOneWidget);
    expect(find.text('Блок'), findsOneWidget);
    // Высота плитки из макета.
    expect(
      t.getSize(find.ancestor(
        of: find.text('Звонок'),
        matching: find.byType(AnimatedContainer),
      ).first).height,
      56,
    );
  });

  testWidgets('шапка панели строится и с обложкой, и без неё', (t) async {
    for (final withCover in <bool>[false, true]) {
      await t.pumpWidget(host(
        DetailsHeadline(
          name: 'Игорь',
          avatar: const SizedBox(width: 88, height: 88),
          cover: withCover ? const ColoredBox(color: Colors.teal) : null,
          presence: 'в сети',
          presenceIsOnline: true,
          premiumBadge: true,
          verified: true,
        ),
      ));
      expect(lastRenderError(), isNull, reason: 'обложка: $withCover');
      expect(find.text('Игорь'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
    }
  });

  testWidgets('переключатель — свой, компактный, и он переключается',
      (t) async {
    var value = false;
    await t.pumpWidget(host(
      StatefulBuilder(
        builder: (ctx, setState) => DesktopSwitch(
          value: value,
          onChanged: (v) => setState(() => value = v),
        ),
      ),
    ));
    expect(find.byType(Switch), findsNothing,
        reason: 'материальный вдвое крупнее строки и красится мимо палитры');
    expect(t.getSize(find.byType(AnimatedContainer).first), const Size(36, 20));
    await t.tap(find.byType(DesktopSwitch));
    await t.pumpAndSettle();
    expect(value, isTrue);
  });

  testWidgets('недоступный переключатель не отвечает на нажатие', (t) async {
    await t.pumpWidget(host(
      const DesktopSwitch(value: false, onChanged: null),
    ));
    await t.tap(find.byType(DesktopSwitch));
    await t.pumpAndSettle();
    expect(lastRenderError(), isNull);
  });
}

/// Последнее исключение отрисовки, если оно было.
///
/// `takeException` забирает его и обнуляет — поэтому проверка «исключений не
/// было» ОБЯЗАНА стоять до любой другой: иначе следующий `expect` упадёт
/// первым, и в отчёте будет написано «текста нет», а не «панель не
/// построилась».
Object? lastRenderError() => TestWidgetsFlutterBinding.instance.takeException();
