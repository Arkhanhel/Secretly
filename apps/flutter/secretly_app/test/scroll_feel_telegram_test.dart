// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Прокрутка как у Telegram (23.11.2026, docs/SCROLL_FEEL_TELEGRAM_2026-11-23.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/pin_jump.dart';
import 'package:secretly_app/ui/scroll_feel.dart';

ScrollMetrics _metrics(double pixels, {double max = 20000}) =>
    FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: max,
      pixels: pixels,
      viewportDimension: 800,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 3,
    );

void main() {
  group('iPhone: профиль и комната — торможение iOS с прижатым краем', () {
    const ios = IosClampedGlideScrollPhysics();
    const bounce = BouncingScrollPhysics();

    test('🔴 бросок посреди страницы идёт ровно по кривой UIScrollView', () {
      final m = _metrics(5000);
      final a = ios.createBallisticSimulation(m, 2500)!;
      final b = bounce.createBallisticSimulation(m, 2500)!;
      for (final t in const [0.0, 0.1, 0.3, 0.6, 1.0, 1.5]) {
        expect(a.x(t), closeTo(b.x(t), 0.5), reason: 't=$t');
        expect(a.dx(t), closeTo(b.dx(t), 0.5), reason: 't=$t');
      }
    });

    test('у края — ничего (край прижат, жест «потянуть фото» цел)', () {
      expect(ios.createBallisticSimulation(_metrics(0), -1500), isNull);
      expect(
        ios.createBallisticSimulation(_metrics(20000), 1500),
        isNull,
      );
      // Перетянутый край: граница прижата, как у ClampingScrollPhysics.
      expect(ios.applyBoundaryConditions(_metrics(0), -30), -30);
    });

    test('повторный бросок разгоняет, как у iOS', () {
      expect(ios.carriedMomentum(3000), bounce.carriedMomentum(3000));
      expect(ios.carriedMomentum(3000), greaterThan(0));
    });
  });

  testWidgets('одна прокрутка: вне Android — стандарт Flutter без изменений', (
    t,
  ) async {
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      const SecretlyScrollBehavior().getScrollPhysics(ctx).runtimeType,
      const MaterialScrollBehavior().getScrollPhysics(ctx).runtimeType,
    );
  });

  test('сглаживание касаний — один кадр 120 Гц, а не стандартные 38 мс', () {
    expect(kTouchSamplingOffset.inMilliseconds, inInclusiveRange(-10, -4));
  });

  test('«вниз» издалека — прыжок на полтора экрана, вблизи — доезд целиком', () {
    expect(scrollToLatestJumpOffset(pixels: 40000, viewport: 800), 1200);
    expect(scrollToLatestJumpOffset(pixels: 900, viewport: 800), isNull);
  });

  testWidgets('«вниз» с 50 экранов: строится лишь пара экранов ленты', (
    t,
  ) async {
    final built = <int>{};
    final c = ScrollController();
    await t.pumpWidget(
      MaterialApp(
        home: ListView.builder(
          controller: c,
          reverse: true,
          itemExtent: 80,
          itemCount: 2000,
          itemBuilder: (_, i) {
            built.add(i);
            return Text('$i');
          },
        ),
      ),
    );
    c.jumpTo(40000);
    await t.pump();
    built.clear();
    final near = scrollToLatestJumpOffset(
      pixels: c.offset,
      viewport: c.position.viewportDimension,
    );
    c.jumpTo(near!);
    final done = c.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutQuint,
    );
    await t.pumpAndSettle();
    await done;
    expect(c.offset, 0);
    // 40000 px / 80 = 500 строк пролёта раньше; теперь — около двух экранов.
    expect(built.length, lessThan(60));
  });

  test('🔴 Android: бросок тормозит плавно и долго, а не резко (как HyperOS/Telegram)', () {
    final m = _metrics(5000);
    final ours = debugAndroidGlidePhysics().createBallisticSimulation(m, 2000)!;
    final spline = const ClampingScrollPhysics().createBallisticSimulation(m, 2000)!;
    // Стартует со скоростью пальца — не быстрее.
    expect(ours.dx(0), closeTo(2000, 1));
    // Катится дальше.
    expect(ours.x(4) - 5000, greaterThan(spline.x(4) - 5000));
    // К 1,5 с сплайн давно стоит, а у нас ещё плавно катится.
    expect(spline.isDone(1.5), isTrue);
    expect(ours.dx(1.5), greaterThan(50));
    // Хвост без рывка: скорость всё время убывает плавно (без излома).
    var prev = ours.dx(0);
    for (var t = 0.05; t < 2.0; t += 0.05) {
      final v = ours.dx(t);
      expect(v, lessThan(prev));
      expect(prev - v, lessThan(prev * 0.11), reason: 'гладко, t=$t');
      prev = v;
    }
  });
}
