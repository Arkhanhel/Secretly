// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 🔴 FIELD (2026-08-01): "our bubbles have a dynamic colour — one at the
/// bottom, another at the top. Raising the keyboard moves the bubbles up but
/// their colour does not change. A message I send WHILE typing gets the right
/// in-between colour, so it no longer matches the ones around it."
///
/// The gradient is one continuous ramp across the VIEWPORT; each bubble samples
/// the slice its screen position falls on. Repainting was driven by the scroll
/// controller alone — and opening the keyboard scrolls NOTHING. The list is
/// lifted by padding, `pixels` never moves, no listener fires, and every
/// already-painted bubble keeps the colour of the position it used to occupy.
/// A freshly built bubble resolves against the current layout, which is exactly
/// why the new message looked right and its neighbours did not.
void main() {
  group('bubble gradient follows the keyboard, not just the scroll', () {
    test('🔴 gradient bubbles repaint on scroll OR keyboard', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      expect(
        code.contains('Listenable.merge('),
        isTrue,
        reason: 'the repaint signal is a single source again',
      );
      // Not one placement may go back to listening to the scroll alone.
      final scrollOnly =
          RegExp(r'viewportListenable:\s*_scroll\b').allMatches(code).length;
      expect(
        scrollOnly,
        0,
        reason: '$scrollOnly bubble(s) repaint on scroll only — those keep a '
            'stale colour for the whole time the keyboard is up',
      );
      final merged = RegExp(r'viewportListenable:\s*_bubbleGradientRepaint')
          .allMatches(code)
          .length;
      expect(merged, greaterThanOrEqualTo(11),
          reason: 'a gradient bubble was left off the shared repaint signal');
    });

    /// The 2026-07-05 optimisation deliberately keeps the chat BODY off the
    /// keyboard's rebuild path (`_KeyboardInsetAnchor` is the one leaf allowed
    /// to read viewInsets). Fixing the colour by reading viewInsets higher up
    /// would silently undo that and rebuild the whole timeline on every frame
    /// of the keyboard animation.
    test('🔴 the fix does NOT drag the body back onto the keyboard path', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      expect(
        src.contains('publishInset: _keyboardInsetForGradient'),
        isTrue,
        reason: 'nothing feeds the keyboard half of the repaint signal',
      );

      // A TRIPWIRE, not a proof. Five reads of viewInsets are legitimate today:
      // the anchor leaf itself, plus four modal sheets/overlays (schedule menu,
      // photo draft, event composer, poll composer) that are separate routes
      // and SHOULD track the keyboard. What must never happen is a new read
      // appearing in the timeline body — that would rebuild the whole chat on
      // every frame of the keyboard animation and undo the 2026-07-05 work.
      //
      // Textually telling "body" from "modal builder" is not something a test
      // can do honestly, so this pins the COUNT instead: adding a read forces
      // whoever does it to come here and say which kind it is.
      final reads = RegExp(r'MediaQuery\.viewInsetsOf\(').allMatches(src).length;
      expect(
        reads,
        5,
        reason: 'the number of viewInsets readers changed. If the new one is '
            'in a modal sheet, bump this number. If it is in the chat BODY, '
            'do not — route it through _KeyboardInsetAnchor.publishInset '
            'instead, or the timeline rebuilds on every keyboard frame',
      );
    });

    testWidgets('a merged listenable fires for EITHER source', (tester) async {
      // The mechanism itself: if merge stopped forwarding one of the two, the
      // symptom would come back silently with no analyzer or test complaint.
      final scrollLike = ValueNotifier<double>(0);
      final keyboardLike = ValueNotifier<double>(0);
      final merged =
          Listenable.merge(<Listenable>[scrollLike, keyboardLike]);
      var ticks = 0;
      void onTick() => ticks++;
      merged.addListener(onTick);

      scrollLike.value = 10;
      expect(ticks, 1, reason: 'scrolling must repaint the gradient');
      keyboardLike.value = 320;
      expect(ticks, 2, reason: 'the keyboard must repaint the gradient too');

      merged.removeListener(onTick);
      scrollLike.dispose();
      keyboardLike.dispose();
    });

    testWidgets('the anchor publishes AFTER the frame, never during build',
        (tester) async {
      // Notifying inside build would repaint widgets the frame has already
      // handled. The value must land, but only once the frame is done.
      final sink = ValueNotifier<double>(0);
      var notifiedDuringBuild = false;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                final inset = MediaQuery.viewInsetsOf(context).bottom;
                if (sink.value != inset) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (sink.value != inset) sink.value = inset;
                  });
                }
                notifiedDuringBuild = sink.value == 300;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(notifiedDuringBuild, isFalse,
          reason: 'the inset was published during build');
      await tester.pump();
      expect(sink.value, 300, reason: 'the inset never reached the gradient');
      sink.dispose();
    });
  });
}
