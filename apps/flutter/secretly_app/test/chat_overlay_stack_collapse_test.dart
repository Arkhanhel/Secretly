// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: 1.6.2+292 shipped a black chat screen with no composer.
///
/// The chat body is a loose Stack whose children were ALL Positioned. The
/// scroll-perf pass wrapped two overlays (jump-to-latest, floating day chip)
/// in ValueListenableBuilders that returned a bare `SizedBox.shrink()` for
/// their empty state — a NON-positioned child.
///
/// The trap is the Scaffold body's constraints: width is tight, but HEIGHT IS
/// LOOSE (min 0). A loose Stack with any non-positioned child sizes itself to
/// those children — so one 0×0 child collapsed the body to height 0, and every
/// Positioned.fill inside (wallpaper, message list, composer overlays) got a
/// zero-height box: the whole chat vanished. Under fully tight constraints the
/// same shape is harmless, which is exactly why it looked safe in review.
///
/// chat_screen has no pumpable harness, so these tests pin the mechanism in
/// the same Scaffold-body context: the broken shape must collapse, the fixed
/// shape (empty state INSIDE an always-returned Positioned) must not.
void main() {
  Widget host(Widget overlay) => MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Container(key: const Key('fill'))),
          overlay,
        ],
      ),
    ),
  );

  testWidgets('bare shrink overlay collapses the Scaffold-body Stack to '
      'height 0 (the 292 black-screen shape)', (tester) async {
    await tester.pumpWidget(host(const SizedBox.shrink()));
    final size = tester.getSize(find.byKey(const Key('fill')));
    expect(
      size.height,
      0,
      reason: 'Scaffold body height is LOOSE: one non-positioned 0×0 child '
          'must shrink the loose Stack to zero height — this is the bug shape',
    );
  });

  testWidgets('empty state inside an always-Positioned overlay keeps the '
      'Stack full-size (the fix)', (tester) async {
    await tester.pumpWidget(
      host(
        const Positioned(right: 14, bottom: 0, child: SizedBox.shrink()),
      ),
    );
    final size = tester.getSize(find.byKey(const Key('fill')));
    expect(size.width, 800);
    expect(size.height, 600);
  });
}
