// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// М2: отклик нажатия как в Telegram — кнопка сжимается, нажатие доходит,
// прокрутка снимает отклик, выключенная кнопка и компьютер не сжимаются.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/motion/press_feedback.dart';

double _scale(WidgetTester t) {
  final tr = t.widget<Transform>(
    find.descendant(
      of: find.byType(PressFeedback),
      matching: find.byType(Transform),
    ),
  );
  return tr.transform.entry(0, 0);
}

double _opacity(WidgetTester t) => t
    .widget<Opacity>(
      find.descendant(
        of: find.byType(PressFeedback),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

Widget _app(VoidCallback? onPressed, {bool reduce = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(
      body: Center(
        child: PressFeedback(
          child: IconButton(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('iPhone: сжатие и прозрачность, нажатие доходит, возврат', (
    t,
  ) async {
    var taps = 0;
    await t.pumpWidget(_app(() => taps++));
    final g = await t.startGesture(t.getCenter(find.byType(IconButton)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 250));
    // 48 px: (48 − 8) / 48 ≈ 0,833 → ограничено 0,84.
    expect(_scale(t), closeTo(0.84, 0.001));
    expect(_opacity(t), closeTo(0.7, 0.01));
    await g.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 130));
    // Перелёт (w + 2) / w.
    expect(_scale(t), closeTo(50 / 48, 0.002));
    await t.pumpAndSettle();
    expect(_scale(t), 1.0);
    expect(_opacity(t), 1.0);
    expect(taps, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android: быстрое сжатие, перелёт выше 1,0, без прозрачности', (
    t,
  ) async {
    var taps = 0;
    await t.pumpWidget(_app(() => taps++));
    final g = await t.startGesture(t.getCenter(find.byType(IconButton)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 80));
    expect(_scale(t), closeTo(0.84, 0.001));
    expect(_opacity(t), 1.0);
    await g.up();
    var peak = 0.0;
    for (var i = 0; i < 25; i++) {
      await t.pump(const Duration(milliseconds: 16));
      peak = peak < _scale(t) ? _scale(t) : peak;
    }
    expect(peak, greaterThan(1.0));
    await t.pumpAndSettle();
    expect(_scale(t), 1.0);
    expect(taps, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('палец поехал (прокрутка) — отклик снимается', (t) async {
    await t.pumpWidget(_app(() {}));
    final g = await t.startGesture(t.getCenter(find.byType(IconButton)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 250));
    expect(_scale(t), lessThan(1.0));
    await g.moveBy(const Offset(0, 40));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(_scale(t), 1.0);
    await g.up();
    await t.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('выключенная кнопка и «Уменьшить движение» — не сжимаются', (
    t,
  ) async {
    for (final (cb, reduce) in <(VoidCallback?, bool)>[
      (null, false),
      (() {}, true),
    ]) {
      await t.pumpWidget(_app(cb, reduce: reduce));
      final g = await t.startGesture(t.getCenter(find.byType(IconButton)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 250));
      expect(_scale(t), 1.0);
      await g.up();
      await t.pumpAndSettle();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('🔴 компьютер — кнопка как была, без обёрток', (t) async {
    await t.pumpWidget(_app(() {}));
    expect(
      find.descendant(
        of: find.byType(PressFeedback),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
