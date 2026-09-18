// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/widgets/island_backdrop.dart';

/// Turning "Frosted panels" OFF must leave a SOLID plate behind, not a hole.
///
/// 🔴 FIELD REPORT (2026-08-01): with the setting off, the chat panels became
/// see-through — wallpaper and messages showed straight through them.
///
/// The cause was that every island's fill was tuned to sit on top of a blur.
/// In dark mode it is white at alpha 0.015–0.13: enough to take the dirtiness
/// off a blurred backdrop, and visually nothing on its own. Skipping the
/// BackdropFilter without swapping that fill removes the panel itself.
///
/// These pin the rule the fix depends on: off ⇒ opaque, in both themes.
void main() {
  group('the plate is fully opaque, or it is not a plate', () {
    testWidgets('dark theme: opaque, and near the owner-picked neutral',
        (tester) async {
      late Color fill;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6750A4),
              brightness: Brightness.dark,
            ),
          ),
          home: Builder(
            builder: (context) {
              fill = opaquePanelFill(context);
              return const SizedBox();
            },
          ),
        ),
      );

      // Opaque is the whole point — any alpha below 255 is a see-through panel.
      expect(fill.a, 1.0, reason: 'a translucent plate is the bug itself');

      // And it must stay a DARK neutral: the tint is a hint of the theme, not
      // a coloured panel. Each channel stays close to the base.
      const base = kOpaquePanelDarkBase;
      for (final pair in <List<double>>[
        [fill.r, base.r],
        [fill.g, base.g],
        [fill.b, base.b],
      ]) {
        expect(
          (pair[0] - pair[1]).abs(),
          lessThan(0.12),
          reason: 'the theme tint overwhelmed the neutral base',
        );
      }
    });

    testWidgets('light theme: plain white, with no tint at all', (tester) async {
      late Color fill;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00695C),
              brightness: Brightness.light,
            ),
          ),
          home: Builder(
            builder: (context) {
              fill = opaquePanelFill(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(fill, Colors.white,
          reason: 'anything translucent here greys the text underneath');
    });

    testWidgets('the dark plate DOES follow the theme, just faintly',
        (tester) async {
      // The counterweight to the test above: prove the tint exists, so a future
      // "simplify" that drops it fails here rather than shipping a dead knob.
      final fills = <Color>[];
      for (final seed in <Color>[
        const Color(0xFFD32F2F),
        const Color(0xFF1565C0),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(seed.toARGB32()),
            theme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: seed,
                brightness: Brightness.dark,
              ),
            ),
            home: Builder(
              builder: (context) {
                fills.add(opaquePanelFill(context));
                return const SizedBox();
              },
            ),
          ),
        );
      }
      expect(
        fills[0],
        isNot(fills[1]),
        reason: 'two very different themes produced an identical plate — the '
            'tint is not being applied',
      );
      for (final f in fills) {
        expect(f.a, 1.0);
      }
    });
  });

  group('the switch actually reaches the islands', () {
    test('defaults to ON, so the look is unchanged until asked', () {
      expect(PanelPrefs.frostedEnabled.value, isTrue);
    });

    test('is a notifier, so screens already on the stack can be rebuilt', () {
      // The nav bar, the top bar and the chat islands never see AppController.
      // If this were a plain field, flipping the setting would leave whatever
      // is already built still blurred — half the app on the old surface.
      var notified = 0;
      void listener() => notified++;
      PanelPrefs.frostedEnabled.addListener(listener);
      addTearDown(() {
        PanelPrefs.frostedEnabled.removeListener(listener);
        PanelPrefs.frostedEnabled.value = true;
      });

      PanelPrefs.frostedEnabled.value = false;
      expect(notified, 1);
      PanelPrefs.frostedEnabled.value = true;
      expect(notified, 2);
    });
  });
}

