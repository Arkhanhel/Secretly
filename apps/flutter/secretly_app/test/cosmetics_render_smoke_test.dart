// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Smoke test: the new premium frames + covers must PAINT (across several
// animation phases) without throwing — the painters do a lot of trig/physics,
// so a stray NaN would crash a real profile screen. We can't assert on pixels
// headlessly, but we can prove no paint-time exception for any kind at any size.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';

Future<void> _pumpThroughAnimation(WidgetTester tester) async {
  // Advance the clock across ~3s so fireworks rise+burst+fade, fish cross and
  // turn (banking foreshorten through 0), bubbles wrap, etc. are all exercised.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  testWidgets('new premium avatar frames paint without throwing',
      (tester) async {
    for (final id in const ['comet', 'sakura', 'phoenix', 'frost', 'prism']) {
      final f = frameById(id);
      expect(f, isNotNull, reason: 'frame "$id" is registered');
      for (final s in const [44.0, 96.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(width: s, height: s, child: f!.builder(s)),
              ),
            ),
          ),
        );
        await _pumpThroughAnimation(tester);
        expect(tester.takeException(), isNull,
            reason: 'frame "$id" @${s}px paints cleanly');
      }
    }
  });

  testWidgets('new premium profile covers paint without throwing',
      (tester) async {
    for (final id in const [
      'fireworks',
      'fireworks_gold',
      'reef',
      'galaxy',
      'aurora_sky',
      // 'blackhole' is a fragment-shader cover now (verified on-device, not by
      // this CustomPainter smoke test — shaders don't rasterise headless).
    ]) {
      final c = coverById(id);
      expect(c, isNotNull, reason: 'cover "$id" is registered');
      // A wide banner and a tall/narrow box — the fireworks framing + reef
      // layout must survive both aspect ratios.
      for (final box in const [Size(360, 200), Size(200, 260)]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: box.width,
                  height: box.height,
                  child: c!.builder(),
                ),
              ),
            ),
          ),
        );
        await _pumpThroughAnimation(tester);
        expect(tester.takeException(), isNull,
            reason: 'cover "$id" @$box paints cleanly');
      }
    }
  });
}
