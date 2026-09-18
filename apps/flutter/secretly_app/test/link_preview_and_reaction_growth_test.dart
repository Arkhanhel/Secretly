// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 🔴 FIELD (2026-08-01), two reports with one shape and one request:
///
///   * "a link preview re-loads every time I open the chat";
///   * "make the bubbles grow very smoothly when someone adds a reaction".
///
/// The first is the same defect as the reactions and the header avatar — a
/// cache that lived on the chat screen's State, died with the screen, and so
/// re-fetched OVER THE NETWORK on every entry. The second is new behaviour.
void main() {
  group('a link preview is loaded once, not once per visit', () {
    test('🔴 the preview caches are STATIC, not per-screen', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      // Instance fields die with the screen; that is precisely the bug.
      expect(
        src.contains('static final Map<String, Future<_LinkPreviewData?>> '
            '_linkPreviewFutures'),
        isTrue,
        reason: 'the in-flight map went back to being per-screen — every chat '
            'entry will re-request every preview again',
      );
      expect(
        src.contains(
            'static final Map<String, _LinkPreviewData> _linkPreviewResolved'),
        isTrue,
        reason: 'without a resolved cache there is nothing to paint on frame '
            'one, so the card still pops in after the bubble',
      );
    });

    test('🔴 the bubble is SEEDED with the resolved preview', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('initialData: linkPreviewInitial'), isTrue,
          reason: 'the preview FutureBuilder paints a null frame again');
      expect(code.contains('_linkPreviewInitialForMessage('), isTrue,
          reason: 'nothing supplies the seed to the bubble');
    });

    /// Direction of failure. `_fetchLinkPreview` answers null for a timeout and
    /// a refused host as well as for "this page has no preview". Remembering a
    /// null would hide, permanently, a preview that the next visit would have
    /// loaded fine — so only successes may be cached.
    test('🔴 a FAILED fetch must not be remembered as "no preview"', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      final start = src.indexOf('_linkPreviewFutures.putIfAbsent(');
      expect(start, greaterThan(-1));
      final window = src.substring(start, start + 900);
      expect(
        window.contains('_linkPreviewFutures.remove(key)'),
        isTrue,
        reason: 'a null result must drop the memo so a later visit retries; '
            'otherwise one network blip hides that preview forever',
      );
    });
  });

  group('bubbles grow into their first reaction', () {
    testWidgets('the slot animates a size change but NOT the first layout',
        (tester) async {
      // The slot must be silent on chat open — growth should read as "a
      // reaction just landed", never as "the screen is still assembling".
      Widget slot({required bool hasReaction}) => MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomRight,
                  child: hasReaction
                      ? const SizedBox(height: 40, width: 80)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          );

      // First layout WITH a reaction: already final size, no animation.
      await tester.pumpWidget(slot(hasReaction: true));
      final atOpen = tester.getSize(find.byType(AnimatedSize));
      expect(atOpen.height, 40,
          reason: 'opening a chat must lay reactions out at final size');

      // Now the empty -> present transition: it must pass through an
      // intermediate height rather than snapping.
      await tester.pumpWidget(slot(hasReaction: false));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AnimatedSize)).height, 0);

      await tester.pumpWidget(slot(hasReaction: true));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getSize(find.byType(AnimatedSize)).height;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(40), reason: 'the bubble snapped instead of growing');
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AnimatedSize)).height, 40);
    });

    /// 🔴 FIELD (2026-08-01, follow-up): "because of the growth animation the
    /// reaction is cut in half HORIZONTALLY until it finishes — a fraction of a
    /// second, but still infuriating."
    ///
    /// AnimatedSize animates both axes and clips to the box it is currently at,
    /// so growing from an empty slot ran the WIDTH 0 -> full too and sliced the
    /// chip down its middle for the whole animation. Clip.none is the fix, and
    /// it is one default away from silently coming back.
    testWidgets('🔴 a growing slot never slices its chip', (tester) async {
      Widget slot({required bool hasReaction, required Clip clip}) => MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  alignment: Alignment.topRight,
                  clipBehavior: clip,
                  child: hasReaction
                      ? const SizedBox(height: 40, width: 120)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          );

      // Mid-growth the BOX is still narrower than the chip — that is inherent
      // to animating size, and is exactly why it must not clip.
      await tester.pumpWidget(slot(hasReaction: false, clip: Clip.none));
      await tester.pumpAndSettle();
      await tester.pumpWidget(slot(hasReaction: true, clip: Clip.none));
      await tester.pump(const Duration(milliseconds: 60));
      final box = tester.getSize(find.byType(AnimatedSize));
      expect(box.width, lessThan(120),
          reason: 'the box should still be growing at this point');
      // The CHILD, however, must be at its true width the whole time.
      final chip = tester.getSize(
        find.descendant(
          of: find.byType(AnimatedSize),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(chip.width, 120,
          reason: 'the chip is being drawn narrower than it is — that is the '
              'horizontal cut the report is about');
      await tester.pumpAndSettle();
    });

    test('🔴 the slot must not clip — that is what halved the reaction', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      final start = src.indexOf('class _ReactionSlot');
      expect(start, greaterThan(-1));
      final body = src.substring(start, start + 2200);
      expect(
        body.contains('clipBehavior: Clip.none'),
        isTrue,
        reason: 'AnimatedSize clips by default, and while its width animates '
            '0 -> full that clip saws the reaction chip in half',
      );
    });

    test('🔴 every reaction placement uses the shared slot', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      // Three placements exist (own bubble, peer bubble, meta row). Each must
      // keep the slot in the tree even with no reactions, or there is nothing
      // for AnimatedSize to grow from.
      final slots = RegExp(r'_ReactionSlot\(').allMatches(code).length;
      expect(slots, greaterThanOrEqualTo(3),
          reason: 'a reaction row is mounted/unmounted directly again — that '
              'is a height snap, not a growth');
      expect(
        code.contains('if (reactions.isNotEmpty)\n            _ReactionPills('),
        isFalse,
        reason: 'a placement still adds the pills conditionally',
      );
    });
  });
}
