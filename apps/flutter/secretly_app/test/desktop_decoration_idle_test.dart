// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 15.11.2026, решение владельца «замирать в простое»: украшения ПК
// движутся, пока человек действует в окне, и замирают на месте через
// `idleAfter` без действий. В простое окно не должно рисовать ничего.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_window_activity.dart';
import 'package:secretly_app/ui/premium/decoration_clock.dart';
import 'package:secretly_app/ui/premium/live_frames.dart';

Widget _decorated() => MaterialApp(
      home: Center(
        child: DesktopDecorationMotion(
          child: SizedBox(
            width: 300,
            height: 300,
            child: Builder(
              builder: (context) => Column(
                children: [
                  Text('ticker=${TickerMode.valuesOf(context).enabled}'),
                  const SizedBox(
                    width: 104,
                    height: 104,
                    child: LiveFrameView(size: 104, id: 'ghost'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

double _simTime(WidgetTester tester) =>
    ((tester.state(find.byType(LiveFrameView)) as dynamic).debugSim as dynamic)
        .t as double;

void main() {
  setUp(() {
    DesktopDecorationActivity.debugReset();
    DesktopWindowActivity.focused.value = true;
    DecorationClock.interval = const Duration(milliseconds: 33);
  });
  tearDown(() {
    DesktopDecorationActivity.debugReset();
    DesktopWindowActivity.focused.value = true;
    DecorationClock.debugReset();
  });

  testWidgets('без действий украшения засыпают, действие будит', (
    tester,
  ) async {
    DesktopDecorationActivity.idleAfter = const Duration(seconds: 10);
    DesktopDecorationActivity.poke();
    await tester.pumpWidget(_decorated());
    expect(find.text('ticker=true'), findsOneWidget);
    expect(DecorationClock.debugRunning, isTrue);

    await tester.pump(const Duration(seconds: 9));
    expect(DesktopDecorationActivity.awake.value, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(DesktopDecorationActivity.awake.value, isFalse);
    await tester.pump();
    expect(find.text('ticker=false'), findsOneWidget);
    expect(
      DecorationClock.debugRunning,
      isFalse,
      reason: 'в простое часы стоят — окно не перерисовывается',
    );

    DesktopDecorationActivity.poke();
    await tester.pump();
    expect(find.text('ticker=true'), findsOneWidget);
    expect(DecorationClock.debugRunning, isTrue);
    await tester.pumpWidget(const SizedBox());
    DesktopDecorationActivity.debugReset(); // таймер сна не должен висеть
  });

  testWidgets('окно без фокуса гасит украшения даже при действиях', (
    tester,
  ) async {
    DesktopDecorationActivity.poke();
    await tester.pumpWidget(_decorated());
    DesktopWindowActivity.focused.value = false;
    await tester.pump();
    expect(find.text('ticker=false'), findsOneWidget);
    expect(DesktopDecorationActivity.motionAllowed, isFalse);
    DesktopWindowActivity.focused.value = true;
    await tester.pump();
    expect(find.text('ticker=true'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    DesktopDecorationActivity.debugReset(); // таймер сна не должен висеть
  });

  testWidgets('рамка засыпает на месте, без прыжка позы', (tester) async {
    DesktopDecorationActivity.idleAfter = const Duration(seconds: 1);
    DesktopDecorationActivity.poke();
    await tester.pumpWidget(_decorated());
    // Пусть рамка сделает хоть один шаг: шаг считает время по стенным часам.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 40));
    final moving = _simTime(tester);

    await tester.pump(const Duration(seconds: 2)); // уснула
    expect(DecorationClock.debugRunning, isFalse);
    final asleep = _simTime(tester);
    expect(
      asleep - moving,
      lessThan(0.5),
      reason: 'settle() добавил бы полторы секунды симуляции — скачок позы',
    );
    await tester.pumpWidget(const SizedBox());
    DesktopDecorationActivity.debugReset(); // таймер сна не должен висеть
  });

  test('частые движения мыши не дёргают таймер на каждое событие', () {
    DesktopDecorationActivity.poke();
    for (var i = 0; i < 1000; i++) {
      DesktopDecorationActivity.poke();
    }
    expect(DesktopDecorationActivity.awake.value, isTrue);
  });
}
