// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/desktop/services/desktop_window_activity.dart';

/// A perpetually repeating animation, the shape that actually burns CPU in the
/// tray (splash / pairing spinner, sync-banner pulse, typing dots).
class _Repeating extends StatefulWidget {
  const _Repeating({required this.onFrame});
  final void Function(double value) onFrame;

  @override
  State<_Repeating> createState() => _RepeatingState();
}

class _RepeatingState extends State<_Repeating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          widget.onFrame(_c.value);
          return const SizedBox.shrink();
        },
      );
}

/// Secretly Desktop hides to the tray instead of quitting, so a "closed"
/// window still has a live Flutter tree. Without this gate every perpetual
/// animation keeps requesting frames forever — measured at roughly a third of
/// a core with a single indeterminate spinner on screen.
void main() {
  group('DesktopWindowActivity', () {
    test('starts visible', () {
      final activity = DesktopWindowActivity();
      addTearDown(activity.dispose);
      expect(activity.visible.value, isTrue,
          reason: 'the app launches on screen; starting hidden would freeze '
              'the very first paint');
    });

    test('tracks hide and show', () {
      final activity = DesktopWindowActivity();
      addTearDown(activity.dispose);

      activity.onHidden();
      expect(activity.visible.value, isFalse);

      activity.onShown();
      expect(activity.visible.value, isTrue);
    });
  });

  testWidgets('animations stop while the window is off screen', (tester) async {
    final activity = DesktopWindowActivity();
    addTearDown(activity.dispose);
    var lastValue = -1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: activity.visible,
          builder: (_, visible, child) =>
              TickerMode(enabled: visible, child: child!),
          child: _Repeating(onFrame: (v) => lastValue = v),
        ),
      ),
    );

    // Visible: the animation advances.
    await tester.pump(const Duration(milliseconds: 100));
    final whileVisible = lastValue;
    await tester.pump(const Duration(milliseconds: 200));
    expect(lastValue, isNot(whileVisible),
        reason: 'a visible window must keep animating');

    // Hidden to the tray: every ticker in the subtree is muted.
    activity.onHidden();
    await tester.pump();
    final atHide = lastValue;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(lastValue, atHide,
        reason: 'an off-screen window must not paint animation frames');

    // Restored: it picks straight back up.
    activity.onShown();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(lastValue, isNot(atHide),
        reason: 'restoring from the tray must resume animation');
  });
}
