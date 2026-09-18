// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat_wallpapers.dart';
import 'package:secretly_app/ui/scroll_feel.dart';

/// Scroll feel and wallpaper decode size (field report 2026-08-01:
/// "Telegram glides longer and is smoother").
///
/// The two halves of that report have different causes and are pinned
/// separately here:
///
///   * FEEL — every list was pinned to iOS physics, so on Android the
///     deceleration matched neither the platform nor any other app on the
///     device.
///   * SMOOTHNESS — wallpapers were decoded at full asset size (1440x2560 =
///     14.1 MB each, 18 of them) against a 128 MB image cache. The cache
///     thrashed, and every re-decode is tens of milliseconds on a thread with
///     an 8.3 ms budget at 120 Hz.
void main() {
  group('scroll feel follows the platform', () {
    test('the physics allows scrolling even when the content is short', () {
      // AlwaysScrollableScrollPhysics as the parent is what keeps
      // pull-to-refresh and overscroll working on a near-empty list; losing it
      // makes short chats feel dead.
      final p = secretlyListPhysics();
      expect(p.parent, isA<AlwaysScrollableScrollPhysics>());
    });

    test('picks the curve the running device expects', () {
      final p = secretlyListPhysics();
      if (Platform.isIOS || Platform.isMacOS) {
        expect(p, isA<BouncingScrollPhysics>());
      } else {
        // 🔴 Flutter's model of Android's own OverScroller — the same curve
        // native apps get for free. Reverting this to Bouncing brings back the
        // "it does not glide like other apps" report.
        expect(p, isA<ClampingScrollPhysics>());
      }
      expect(secretlyUsesBouncingScroll, Platform.isIOS || Platform.isMacOS);
    });

    /// 🔴 THE REGRESSION THAT MADE SCROLLING "HORRIBLY SHARP AND FAST"
    /// (2026-08-01). The first glide attempt multiplied the fling's STARTING
    /// VELOCITY by 1.25. A list must leave the finger at the speed the finger
    /// actually moved — inflate that and the scroll reads as twitchy and
    /// uncontrollable, however far it eventually travels.
    ///
    /// Distance is bought with friction, never with velocity. This pins the
    /// launch speed itself, so re-introducing a velocity multiplier fails here
    /// even if the distance test above still passes.
    test('🔴 the fling starts at EXACTLY the speed the finger gave it', () {
      if (secretlyUsesBouncingScroll) return;
      final metrics = FixedScrollMetrics(
        pixels: 500,
        minScrollExtent: 0,
        maxScrollExtent: 5000,
        viewportDimension: 800,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 2.625,
      );
      for (final physics in <ScrollPhysics>[
        secretlyListPhysics(),
        secretlyPullListPhysics(),
      ]) {
        const flick = 2000.0;
        final sim = physics.createBallisticSimulation(metrics, flick)!;
        expect(
          sim.dx(0.0),
          closeTo(flick, 1.0),
          reason: 'the list launches faster than the finger — this is exactly '
              'the "horribly sharp and fast" report',
        );
      }
    });

    test('a fling travels FURTHER than the stock platform curve', () {
      // The point of the glide knob. Measured as distance actually simulated,
      // not as a constant — a change that stops reaching the simulation would
      // pass a constant check and fail here.
      final metrics = FixedScrollMetrics(
        pixels: 500,
        minScrollExtent: 0,
        maxScrollExtent: 5000,
        viewportDimension: 800,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 2.625,
      );
      const stock = ClampingScrollPhysics();
      final ours = secretlyListPhysics();

      final a = stock.createBallisticSimulation(metrics, 2000);
      final b = ours.createBallisticSimulation(metrics, 2000);
      expect(a, isNotNull);
      expect(b, isNotNull);

      // Where each simulation ends up after a second of travel.
      final stockEnd = a!.x(1.0);
      final oursEnd = b!.x(1.0);
      if (secretlyUsesBouncingScroll) {
        // iOS keeps Apple's own curve — nothing to compare against here.
        return;
      }
      expect(
        oursEnd,
        greaterThan(stockEnd),
        reason: 'the glide factor is not reaching the simulation',
      );
    });

    test('🔴 the SNAP-BACK from overscroll is NOT boosted', () {
      // The same method builds both the fling and the spring that returns an
      // over-scrolled list to its edge. Boosting the spring would throw the
      // list past the end and back — a bug, not a longer glide.
      if (secretlyUsesBouncingScroll) return;
      final past = FixedScrollMetrics(
        pixels: 5200, // beyond maxScrollExtent
        minScrollExtent: 0,
        maxScrollExtent: 5000,
        viewportDimension: 800,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 2.625,
      );
      const stock = ClampingScrollPhysics();
      final ours = secretlyListPhysics();

      final a = stock.createBallisticSimulation(past, 600);
      final b = ours.createBallisticSimulation(past, 600);
      expect(a, isNotNull, reason: 'overscroll must spring back');
      expect(b, isNotNull);
      // Identical settling behaviour: same position at the same time.
      for (final t in <double>[0.05, 0.2, 0.5]) {
        expect(b!.x(t), closeTo(a!.x(t), 0.5), reason: 'snap-back differs at t=$t');
      }
    });

    test('REGRESSION: no list is left pinned to iOS physics', () {
      // The whole point is that these are decided in one place. A stray
      // `BouncingScrollPhysics()` in a list is invisible in review and only
      // shows up as "this screen feels different from that one".
      const files = <String>[
        'lib/ui/chat_screen.dart',
        'lib/ui/widgets/secretly_sticker_widgets.dart',
        'lib/ui/active_call_screen.dart',
        'lib/ui/room_call_screen.dart',
      ];
      for (final f in files) {
        final src = File(f).readAsStringSync();
        final code = src
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(
          code.contains('BouncingScrollPhysics()'),
          isFalse,
          reason: '$f still hard-codes iOS scroll physics',
        );
      }
    });

    /// 🔴 THE BLIND SPOT THAT LET THIS SHIP (2026-08-01, field: "iOS glides
    /// beautifully, Android did not change at all").
    ///
    /// The guard above only catches a list that hard-codes the WRONG physics.
    /// Both surfaces the user actually scrolls failed a different way:
    ///
    ///   * the message timeline named NO physics at all, so it silently took
    ///     the ambient default — bouncing on iOS (which is why iOS felt right)
    ///     and stock clamping with no glide on Android;
    ///   * the chats list hard-coded plain `ClampingScrollPhysics`, which is
    ///     not iOS physics, so the guard was happy — and the glide never
    ///     reached the most-scrolled list in a messenger.
    ///
    /// Absence is invisible to a "does it contain the wrong thing" check, so
    /// these prove the WIRING instead: the two lists must reach the shared
    /// decision. Same lesson as the localization guard — coverage without
    /// wiring is worth nothing.
    test('🔴 the message timeline is WIRED to the shared physics', () {
      final src = File('lib/ui/chat_screen.dart').readAsStringSync();
      final lines = src.split('\n');
      final timeline = lines.indexWhere((l) => l.contains('reverse: true,'));
      expect(timeline, greaterThan(-1), reason: 'reversed timeline not found');
      final window = lines
          .sublist(timeline, (timeline + 30).clamp(0, lines.length))
          .join('\n');
      expect(
        window.contains('physics: secretlyListPhysics()'),
        isTrue,
        reason: 'the timeline takes the ambient default again — on Android '
            'that is stock clamping with no glide, i.e. the exact field report',
      );
    });

    test('🔴 the chats list is WIRED to the pull-safe physics', () {
      final src = File('lib/ui/chats_screen.dart').readAsStringSync();
      expect(
        src.contains('secretlyPullListPhysics()'),
        isTrue,
        reason: 'the chats list stopped using the shared physics',
      );
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code.contains('const ClampingScrollPhysics('),
        isFalse,
        reason: 'a hard-coded clamping physics is back — that is how the glide '
            'was lost here in the first place',
      );
    });

    test('pull-safe physics: glide on Android, gesture-safe on iOS', () {
      final p = secretlyPullListPhysics();
      // NEVER bouncing: these lists read top-edge overscroll to drive their own
      // pull-to-reveal, and a rubber-band fights that gesture.
      expect(p, isA<ClampingScrollPhysics>());
      expect(p, isNot(isA<BouncingScrollPhysics>()));
      expect(p.parent, isA<AlwaysScrollableScrollPhysics>());

      final metrics = FixedScrollMetrics(
        pixels: 500,
        minScrollExtent: 0,
        maxScrollExtent: 5000,
        viewportDimension: 800,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 2.625,
      );
      const stock = ClampingScrollPhysics();
      final stockEnd = stock.createBallisticSimulation(metrics, 2000)!.x(1.0);
      final oursEnd = p.createBallisticSimulation(metrics, 2000)!.x(1.0);
      if (secretlyUsesBouncingScroll) {
        // iOS is deliberately left byte-for-byte as it was.
        expect(oursEnd, closeTo(stockEnd, 0.5));
      } else {
        expect(
          oursEnd,
          greaterThan(stockEnd),
          reason: 'Android lost the glide on the pull-gesture lists',
        );
      }
    });
  });

  group('wallpapers decode at the size they are drawn', () {
    /// The picker grid is the case that hurt: 18 tiles at full size is 254 MB
    /// against a 128 MB cache, so it evicts and re-decodes in a loop.
    testWidgets('a preview tile decodes to a thumbnail, not a wallpaper',
        (tester) async {
      late int previewWidth;
      late int fullWidth;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(412, 915),
            devicePixelRatio: 2.625,
          ),
          child: Builder(
            builder: (context) {
              previewWidth = chatWallpaperDecodeWidth(context, preview: true);
              fullWidth = chatWallpaperDecodeWidth(context, preview: false);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(previewWidth, lessThan(fullWidth));
      // 320 px is ~0.4 MB against 14.1 MB for the raw asset.
      expect(previewWidth, lessThanOrEqualTo(512));
    });

    testWidgets('full-bleed decodes to the SCREEN, not the asset', (tester) async {
      late int width;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(412, 915),
            devicePixelRatio: 2.625,
          ),
          child: Builder(
            builder: (context) {
              width = chatWallpaperDecodeWidth(context, preview: false);
              return const SizedBox();
            },
          ),
        ),
      );
      // 412 * 2.625 = 1081 physical px. The assets are 1440 wide, so this is
      // where the saving comes from — and it must never exceed what is shown.
      expect(width, closeTo(1081, 2));
      expect(width, lessThan(1440), reason: 'still decoding above the screen');
    });

    testWidgets('an absurd or missing MediaQuery cannot produce a silly size',
        (tester) async {
      // Guards both directions: a tiny width would make wallpapers mush, a huge
      // one would put the memory bug straight back.
      late int width;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(4000, 4000),
            devicePixelRatio: 4.0,
          ),
          child: Builder(
            builder: (context) {
              width = chatWallpaperDecodeWidth(context, preview: false);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(width, lessThanOrEqualTo(2160));
      expect(width, greaterThanOrEqualTo(360));
    });

    test('sizing never upscales a small custom wallpaper', () {
      // Blowing a 300 px photo up to screen width costs memory AND looks worse.
      final sized = sizedChatWallpaper(
        const AssetImage('assets/Background/chat_default.jpg'),
        1080,
      );
      expect(sized, isA<ResizeImage>());
      expect((sized as ResizeImage).allowUpscaling, isFalse);
      expect(sized.width, 1080);
    });
  });
}
