// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Украшения на телефоне — не чаще 60 кадров в секунду (23.11.2026).

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/motion/decoration_pacer.dart';

class _Deco extends StatefulWidget {
  const _Deco(this.ticks);
  final List<Duration> ticks;
  @override
  State<_Deco> createState() => _DecoState();
}

class _DecoState extends State<_Deco> with PacedTickerProviderStateMixin {
  late final Ticker _t = createTicker(widget.ticks.add);

  @override
  void initState() {
    super.initState();
    _t.start();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Секунда кадров с периодом экрана [periodUs]; сколько шагов сделало
/// украшение.
Future<int> _ticksPerSecond(WidgetTester t, int periodUs, {bool mode = true}) async {
  final ticks = <Duration>[];
  await t.pumpWidget(TickerMode(enabled: mode, child: _Deco(ticks)));
  ticks.clear();
  for (var i = 0; i < 1000000 ~/ periodUs; i++) {
    await t.pump(Duration(microseconds: periodUs));
  }
  final n = ticks.length;
  await t.pumpWidget(const SizedBox());
  return n;
}

void main() {
  tearDown(DecorationPacer.debugReset);

  test('сетка: шаг украшения — в кадрах, кратных 2 на 120 Гц', () {
    expect(DecorationPacer.stepFor(8333), 2);
    expect(DecorationPacer.stepFor(16667), 1);
    expect(DecorationPacer.stepFor(11111), 1, reason: '90 Гц — не рваные 45');
    expect(DecorationPacer.stepFor(6944), 2);
    // Чётный кадр (№4): следующий по сетке — №6, заказ между №5 и №6.
    final even = DecorationPacer.delayFor(frameUs: 4 * 8333, periodUs: 8333);
    expect(even.inMicroseconds, greaterThan(8333));
    expect(even.inMicroseconds, lessThan(16667));
    // 🔴 Нечётный кадр (№5, запуск посреди круга): следующий по сетке — №6,
    // то есть СЛЕДУЮЩЕЕ обновление, а не через одно — иначе сдвиг навсегда.
    final odd = DecorationPacer.delayFor(frameUs: 5 * 8333, periodUs: 8333);
    expect(odd.inMicroseconds, lessThan(8333));
  });

  testWidgets('выключен (ПК, проверки) — шаг на каждом кадре, как раньше', (
    t,
  ) async {
    expect(await _ticksPerSecond(t, 8333), inInclusiveRange(118, 121));
  });

  testWidgets('🔴 120 Гц — украшение шагает 60 раз в секунду', (t) async {
    DecorationPacer.debugEnable(periodUs: 8333);
    expect(await _ticksPerSecond(t, 8333), inInclusiveRange(58, 61));
  });

  testWidgets('60 Гц — каждый кадр, ничего не теряется', (t) async {
    DecorationPacer.debugEnable(periodUs: 16667);
    expect(await _ticksPerSecond(t, 16667), inInclusiveRange(58, 61));
  });

  testWidgets('под выключенным TickerMode — молчит и не держит таймер', (
    t,
  ) async {
    DecorationPacer.debugEnable(periodUs: 8333);
    expect(await _ticksPerSecond(t, 8333, mode: false), 0);
  });

  testWidgets('🔴 десять украшений — один общий таймер, каждое по 60/с', (
    t,
  ) async {
    DecorationPacer.debugEnable(periodUs: 8333);
    final ticks = List.generate(10, (_) => <Duration>[]);
    await t.pumpWidget(Column(children: [for (final l in ticks) _Deco(l)]));
    for (final l in ticks) {
      l.clear();
    }
    await t.pump(const Duration(microseconds: 8333));
    expect(debugPacerTimersPending, lessThanOrEqualTo(1));
    for (var i = 0; i < 119; i++) {
      await t.pump(const Duration(microseconds: 8333));
    }
    for (final l in ticks) {
      expect(l.length, inInclusiveRange(58, 61));
    }
    await t.pumpWidget(const SizedBox());
    expect(debugPacerTimersPending, 0);
  });

  test('🔴 свои же кадры через 1/60 с не убеждают, что экран 60 Гц', () {
    DecorationPacer.debugEnable(periodUs: 8333);
    for (var i = 0; i < 500; i++) {
      DecorationPacer.observeFrameGap(16667);
    }
    expect(DecorationPacer.debugPeriodUs, 8333, reason: 'иначе качели 60↔120');
    // Экран 144 Гц — период уменьшается.
    DecorationPacer.observeFrameGap(6944);
    expect(DecorationPacer.debugPeriodUs, 6944);
    // Шум таймстемпов не дёргает период.
    DecorationPacer.observeFrameGap(6800);
    expect(DecorationPacer.debugPeriodUs, 6944);
  });

  testWidgets('🔴 украшение, запущенное на «нечётном» кадре, встаёт в общую сетку', (
    t,
  ) async {
    DecorationPacer.debugEnable(periodUs: 8333);
    final a = <Duration>[];
    final b = <Duration>[];
    final showB = ValueNotifier<bool>(false);
    await t.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: showB,
        builder: (_, on, _) => Column(children: [_Deco(a), if (on) _Deco(b)]),
      ),
    );
    for (var i = 0; i < 11; i++) {
      await t.pump(const Duration(microseconds: 8333));
    }
    showB.value = true; // появляется посреди круга
    final frames = <int>[];
    var lastA = a.length, lastB = b.length;
    for (var i = 0; i < 120; i++) {
      await t.pump(const Duration(microseconds: 8333));
      if (a.length != lastA || b.length != lastB) frames.add(i);
      lastA = a.length;
      lastB = b.length;
    }
    // Кадров с шагом украшений — около 60, а не 120 (две сдвинутые группы).
    expect(frames.length, inInclusiveRange(58, 62));
    await t.pumpWidget(const SizedBox());
  });
}
