// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 СТРОКА ДЕЙСТВИЙ НАД СООБЩЕНИЕМ НЕ НАЖИМАЛАСЬ ВООБЩЕ.
//
// ЧТО БЫЛО. Строка рисовалась `Positioned(top: -36)` внутри `Stack` пузыря —
// то есть ЗА его верхним краем. Во Flutter это значит «не нажимается»:
// проверка попадания у `RenderBox` начинается с `size.contains(position)`, и
// точка вне рамки родителя до детей просто не доходит. `Clip.none` тут не
// помогает — он снимает обрезку РИСОВАНИЯ, а не проверку попадания.
//
// Измерено на этом же дереве: строка занимала 99…127 по вертикали, `Stack`
// пузыря — 132…208. Они не пересекались НИ В ОДНОЙ точке. 👍, 🔥, «Ещё
// реакции», «Ответить» и «Ещё» появлялись при наведении и не делали ничего:
// нажатие проваливалось насквозь.
//
// Почему пропажа не бросалась в глаза: ровно те же действия есть в меню по
// правой кнопке, и люди пользовались им.
//
// СТАЛО. Строка живёт в наложении (`Overlay`), а место держит через
// `LayerLink` — слой во весь экран, точка над пузырём принадлежит уже ему, и
// при прокрутке строка едет вместе с пузырём, а не отрывается от него.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:secretly_app/ui/desktop/chat/message_bubble.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

const _msg = MessageData(
  id: 'm1',
  payloadId: 'p1',
  authorName: 'Игорь',
  text: 'привет',
  time: '14:19',
);

Future<void> hoverBubble(WidgetTester t) async {
  final g = await t.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: Offset.zero);
  addTearDown(g.removePointer);
  await g.moveTo(t.getCenter(find.textContaining(_msg.text)));
  await t.pumpAndSettle();
}

Widget host(Widget child) => MaterialApp(
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 120),
        child: SizedBox(width: 760, child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('🔴 «Ответить» из строки наведения РАБОТАЕТ', (t) async {
    var replied = 0;
    await t.pumpWidget(
      host(MessageBubble(message: _msg, onReply: () => replied++)),
    );
    await hoverBubble(t);

    final reply = find.byIcon(FluentIcons.arrow_reply_24_regular);
    expect(reply, findsOneWidget);
    // `warnIfMissed` фатальным здесь и делает тест настоящим: именно мимо
    // кнопки нажатие и уходило.
    await t.tap(reply, warnIfMissed: true);
    await t.pump();
    expect(replied, 1);
  });

  testWidgets('🔴 быстрые реакции из строки наведения РАБОТАЮТ', (t) async {
    final reacted = <String>[];
    await t.pumpWidget(
      host(MessageBubble(message: _msg, onReact: reacted.add)),
    );
    await hoverBubble(t);

    for (final e in kDesktopQuickReactions) {
      await t.tap(find.text(e), warnIfMissed: true);
      await t.pump();
    }
    expect(reacted, kDesktopQuickReactions);
  });

  testWidgets('🔴 «Ещё» из строки наведения РАБОТАЕТ', (t) async {
    Offset? at;
    await t.pumpWidget(
      host(MessageBubble(message: _msg, onMoreActions: (p) => at = p)),
    );
    await hoverBubble(t);
    await t.tap(
      find.byIcon(FluentIcons.more_horizontal_24_regular),
      warnIfMissed: true,
    );
    await t.pump();
    expect(at, isNotNull);
  });

  testWidgets('строка исчезает, когда курсор ушёл', (t) async {
    await t.pumpWidget(host(MessageBubble(message: _msg, onReply: () {})));
    final g = await t.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(t.getCenter(find.textContaining(_msg.text)));
    await t.pumpAndSettle();
    expect(find.byIcon(FluentIcons.arrow_reply_24_regular), findsOneWidget);

    await g.moveTo(const Offset(5, 5));
    // Отсрочка в 120 мс: курсор может на миг пересечь щель между пузырём и
    // строкой, и мигать она от этого не должна.
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();
    expect(find.byIcon(FluentIcons.arrow_reply_24_regular), findsNothing);
  });

  testWidgets('🔴 пузырь уехал — строка не осталась висеть', (t) async {
    await t.pumpWidget(host(MessageBubble(message: _msg, onReply: () {})));
    await hoverBubble(t);
    expect(find.byIcon(FluentIcons.arrow_reply_24_regular), findsOneWidget);

    // Лента прокрутилась, сообщение сняли с дерева.
    await t.pumpWidget(host(const SizedBox.shrink()));
    await t.pumpAndSettle();
    expect(find.byIcon(FluentIcons.arrow_reply_24_regular), findsNothing);
  });

  testWidgets('🔴 ПОДСКАЗКА кнопки не роняет строку (красный экран)', (t) async {
    // Ровно тот случай из жалобы 16.09.2026. `Tooltip` показывает себя через
    // `OverlayPortal`; пока строка висела на `CompositedTransformFollower`,
    // портал при раскладке спотыкался о «ленивое» преобразование follower-а и
    // Flutter ронял проверку — в отладочной сборке это красный экран во всё
    // окно, а строка исчезала недонажатой.
    await t.pumpWidget(host(MessageBubble(message: _msg, onReply: () {})));
    final g = await t.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(t.getCenter(find.textContaining(_msg.text)));
    await t.pumpAndSettle();

    // Наводим на саму кнопку и ждём дольше, чем `waitDuration` подсказки.
    await g.moveTo(
      t.getCenter(find.byIcon(FluentIcons.arrow_reply_24_regular)),
    );
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();

    expect(
      t.takeException(),
      isNull,
      reason: 'подсказка над строкой не имеет права ронять раскладку',
    );
    expect(find.text('Ответить'), findsOneWidget);
    // И кнопка под подсказкой по-прежнему нажимается.
    expect(find.byIcon(FluentIcons.arrow_reply_24_regular), findsOneWidget);
  });

  group('правила', () {
    final src = File(
      'lib/ui/desktop/chat/message_bubble.dart',
    ).readAsStringSync();

    test('🔴 строки больше нет в `Stack` пузыря за его краем', () {
      expect(src.contains('top: -36,'), isFalse);
      expect(src.contains('OverlayPortal.overlayChildLayoutBuilder('), isTrue);
    });

    test('🔴 место держит ПОРТАЛ, а не CompositedTransformFollower', () {
      // 16.09.2026. Подсказки кнопок (`Tooltip`) показывают себя через
      // `OverlayPortal`, а тот при раскладке спрашивает путь до слоя
      // наложения. `RenderFollowerLayer` своё преобразование ставит позже, при
      // композиции, — Flutter роняет проверку, и в отладочной сборке это
      // КРАСНЫЙ ЭКРАН, а строка исчезает недонажатой. Ровно жалоба владельца.
      // Замену советует текст самой ошибки.
      expect(src.contains('CompositedTransformFollower('), isFalse);
      expect(src.contains('CompositedTransformTarget('), isFalse);
      expect(src.contains('LayerLink()'), isFalse);
      expect(src.contains('info.childPaintTransform'), isTrue);
    });

    test('строка едет с лентой: место считается от пузыря каждый раз', () {
      final i = src.indexOf('Widget _barOverlayChild(');
      expect(i, greaterThan(0));
      final body = src.substring(i, i + 1800);
      expect(body.contains('MatrixUtils.transformPoint'), isTrue);
      // Своё сообщение прижимается ПРАВЫМ краем — ширина строки заранее
      // неизвестна (кнопка веток то есть, то нет).
      expect(body.contains('info.overlaySize.width'), isTrue);
    });

    test('🔴 строку больше не надо снимать вручную', () {
      // Запись наложения переживала виджет и висела поверх окна; ребёнок
      // портала уходит вместе с пузырём.
      expect(src.contains('OverlayEntry('), isFalse);
      final i = src.indexOf('  void dispose() {');
      expect(i, greaterThan(0));
      expect(src.substring(i, i + 400).contains('_hideBarOverlay();'), isFalse);
    });

    test('палитра внутри строки — та же, что у пузыря', () {
      // Наложенный ребёнок портала — ребёнок ЭТОГО виджета в дереве, поэтому
      // `DColors.of` находит ту же палитру. Прежняя запись наложения этого не
      // умела: кнопки молча брали набор по яркости системы.
      final i = src.indexOf('Widget _barOverlayChild(');
      final body = src.substring(i, i + 400);
      expect(body.contains('final c = DColors.of(ctx);'), isTrue);
    });
  });
}
