// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// М1: словарь движения. Кривые выбираются по платформе, компьютер получает
// прежние, пружины не отскакивают.
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/motion/motion.dart';

double _ratio(SpringDescription s) =>
    s.damping / (2 * math.sqrt(s.mass * s.stiffness));

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iPhone — фирменная кривая Telegram, Android — EASE_OUT_QUINT', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(Motion.standard.transform(0.3), TgCurves.ios.transform(0.3));
    expect(Motion.pop.transform(0.5), TgCurves.ios.transform(0.5));
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      Motion.standard.transform(0.3),
      TgCurves.androidQuint.transform(0.3),
    );
    expect(Motion.fade.transform(0.3), TgCurves.androidDefault.transform(0.3));
  });

  test('🔴 компьютер — прежние кривые мест', () {
    for (final p in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = p;
      for (final (motion, old) in <(Curve, Curve)>[
        (Motion.standard, Curves.easeOutCubic),
        (Motion.standardQuart, Curves.easeOutQuart),
        (Motion.fade, Curves.easeOut),
        (Motion.pop, Curves.easeOutBack),
        (Motion.popElastic, Curves.elasticOut),
      ]) {
        for (final t in [0.1, 0.4, 0.8]) {
          expect(motion.transform(t), old.transform(t), reason: '$p $motion');
        }
      }
    }
  });

  test('кривые начинаются в 0 и кончаются в 1', () {
    for (final p in [TargetPlatform.iOS, TargetPlatform.android]) {
      debugDefaultTargetPlatformOverride = p;
      for (final c in <Curve>[
        Motion.standard,
        Motion.fade,
        Motion.pop,
        Motion.popElastic,
        Motion.sheet,
      ]) {
        expect(c.transform(0), 0);
        expect(c.transform(1), 1);
      }
    }
  });

  test('🔴 пружины не отскакивают (ratio ≥ 1), кроме доводки после свайпа', () {
    for (final s in [
      MotionSprings.standard,
      MotionSprings.navigation,
      MotionSprings.large,
      MotionSprings.bubble,
    ]) {
      expect(_ratio(s), greaterThanOrEqualTo(0.999), reason: '$s');
    }
    expect(_ratio(MotionSprings.afterSwipe), closeTo(0.85, 0.01));
  });

  test('пружина Telegram доходит до цели без перелёта', () {
    final sim = SpringSimulation(MotionSprings.standard, 0, 1, 0);
    var maxX = 0.0;
    for (var t = 0.0; t < 1.0; t += 1 / 120) {
      maxX = math.max(maxX, sim.x(t));
    }
    expect(maxX, lessThanOrEqualTo(1.0 + 1e-6));
    expect(sim.x(0.6), closeTo(1, 0.01));
  });
}
