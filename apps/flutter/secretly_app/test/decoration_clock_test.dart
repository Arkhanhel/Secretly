// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 14.11.2026: живая рамка на ПК держала окно в непрерывной перерисовке —
// тикер просил кадр на каждом обновлении экрана. На ПК она шагает общими
// часами украшений; на телефоне (часы выключены) — тикером, как раньше.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/decoration_clock.dart';
import 'package:secretly_app/ui/premium/live_frames.dart';

Widget _frame({bool ticking = true, String id = 'ghost'}) => MaterialApp(
      home: TickerMode(
        enabled: ticking,
        child: Center(
          child: SizedBox(
            width: 104,
            height: 104,
            child: LiveFrameView(size: 104, id: id),
          ),
        ),
      ),
    );

double _simTime(WidgetTester tester) =>
    ((tester.state(find.byType(LiveFrameView)) as dynamic).debugSim as dynamic)
        .t as double;

void main() {
  tearDown(DecorationClock.debugReset);

  testWidgets('ПК: рамка идёт общими часами и не заказывает кадр на каждом '
      'обновлении экрана', (tester) async {
    DecorationClock.interval = const Duration(milliseconds: 33);
    // Первая постройка MaterialApp сама заказывает кадр — её проводим заранее.
    await tester.pumpWidget(_frame(ticking: false));
    await tester.pump();
    await tester.pumpWidget(_frame());
    expect(DecorationClock.debugSubscriberCount, 1);
    expect(DecorationClock.debugRunning, isTrue);
    await tester.pump();
    expect(
      tester.binding.hasScheduledFrame,
      isFalse,
      reason: 'без шага часов кадр не нужен — тикер его бы заказал',
    );

    final before = _simTime(tester);
    // Шаг рамки считает время по стенным часам: пусть их пройдёт больше 1/60 с.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(_simTime(tester), greaterThan(before), reason: 'часы шагают рамку');
  });

  testWidgets('ПК: выключенный TickerMode (окно без фокуса, список) '
      'отписывает рамку и останавливает часы', (tester) async {
    DecorationClock.interval = const Duration(milliseconds: 33);
    await tester.pumpWidget(_frame());
    expect(DecorationClock.debugRunning, isTrue);

    await tester.pumpWidget(_frame(ticking: false));
    expect(DecorationClock.debugSubscriberCount, 0);
    expect(DecorationClock.debugRunning, isFalse);
    final frozen = _simTime(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_simTime(tester), frozen);

    await tester.pumpWidget(_frame());
    expect(DecorationClock.debugRunning, isTrue, reason: 'фокус вернулся');
  });

  testWidgets('ПК: снятая с экрана рамка не держит часы', (tester) async {
    DecorationClock.interval = const Duration(milliseconds: 33);
    await tester.pumpWidget(_frame());
    await tester.pumpWidget(const SizedBox());
    expect(DecorationClock.debugSubscriberCount, 0);
    expect(DecorationClock.debugRunning, isFalse);
  });

  testWidgets('телефон: часы выключены — рамка идёт тикером, как раньше',
      (tester) async {
    expect(DecorationClock.enabled, isFalse);
    await tester.pumpWidget(_frame());
    expect(DecorationClock.debugSubscriberCount, 0);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0),
        reason: 'тикер рамки активен');
    await tester.pumpWidget(const SizedBox());
  });
}
