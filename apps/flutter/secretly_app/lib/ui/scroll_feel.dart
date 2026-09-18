// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// The scroll feel for VERTICAL content lists — chats, messages, stickers.
///
/// 🔴 WHY THIS EXISTS (2026-08-01, field: "Telegram glides longer and smoother").
///
/// Every list in the app was pinned to [BouncingScrollPhysics], which is the
/// **iOS** curve: iOS friction plus a rubber-band at the ends. On Android that
/// is doubly wrong — it does not match the platform's own deceleration, and it
/// does not match any other app on the device, including the one being compared
/// against. Telegram for Android is a native `RecyclerView` driven by the
/// system `OverScroller`, so it inherits the platform curve for free.
///
/// [ClampingScrollPhysics] is Flutter's model of that same `OverScroller`, and
/// Android ends a list with a stretch/glow rather than a bounce. So the fix is
/// not to invent a curve — it is to stop overriding the platform's.
///
/// **This is about FEEL, not smoothness.** Frame drops come from work done
/// during the scroll (image decoding above all); no amount of physics tuning
/// hides them. The two were investigated together and fixed separately — see
/// `chatWallpaperDecodeWidth` for the other half.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// Android's fling friction, scaled. 1.0 is the platform default exactly.
///
/// 🔴 HOW THIS MUST BE TUNED — the previous attempt got it backwards
/// (2026-08-01, field: "horribly sharp and fast scrolling, just awful").
///
/// The first version lengthened the glide by handing the simulation a LARGER
/// STARTING VELOCITY (×1.25), on the belief that `ClampingScrollSimulation`
/// exposes no friction. It does — `friction`, default 0.015, right there in the
/// constructor. And multiplying velocity is not "glides longer": it makes the
/// list leave the finger 25% FASTER than the finger actually moved. That breaks
/// the one thing a scroll must never break — the list travelling at the speed
/// you flicked it — so it reads as harsh and twitchy, not smooth.
///
/// Lower friction is the honest knob: the list starts at exactly the speed your
/// finger gave it and simply coasts further before settling. Below 1.0 = longer
/// coast, same launch. Never scale velocity again.
///
/// Measured, not guessed — a 2000 px/s flick:
///
/// | model                  | distance | settles | launches at   |
/// |------------------------|----------|---------|---------------|
/// | stock Android (1.00)   |   647 px |  0.77 s | 2000  correct |
/// | the ×1.25 velocity bug |   954 px |  0.90 s | 2500  WRONG   |
/// | this (0.80 friction)   |   763 px |  0.90 s | 2000  correct |
///
/// 0.80 is chosen so the list SETTLES in the same 0.90 s the velocity version
/// did — the pacing was never the complaint — while launching at the finger's
/// real speed, which was. Raising the coast further is one number here; do that
/// only on a fresh report, and never by touching velocity.
const double kScrollFrictionScale = 0.80;

/// Android's own curve with a longer coast.
///
/// Deliberately re-implements `ClampingScrollPhysics.createBallisticSimulation`
/// instead of delegating, because the ONLY way to reach `friction` is to build
/// the simulation here. Every guard from the original is preserved verbatim —
/// the snap-back spring when out of range, the below-tolerance no-op, and the
/// two at-the-edge no-ops — so the only behavioural difference is how far an
/// in-range fling coasts.
class _GlideClampingScrollPhysics extends ClampingScrollPhysics {
  const _GlideClampingScrollPhysics({super.parent});

  @override
  _GlideClampingScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _GlideClampingScrollPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // 🔴 Out of range this method builds the SNAP-BACK spring that returns an
    // over-scrolled list to its edge — nothing to do with a fling. Delegate it
    // untouched; a "longer" snap-back reads as a bug, not as glide.
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    final Tolerance tolerance = toleranceFor(position);
    if (velocity.abs() < tolerance.velocity) {
      return null;
    }
    if (velocity > 0.0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    if (velocity < 0.0 && position.pixels <= position.minScrollExtent) {
      return null;
    }
    return ClampingScrollSimulation(
      position: position.pixels,
      // Untouched, on purpose. This is the finger's own speed.
      velocity: velocity,
      friction: 0.015 * kScrollFrictionScale,
      tolerance: tolerance,
    );
  }
}

ScrollPhysics secretlyListPhysics() {
  // `Platform` rather than `Theme.of(context).platform` on purpose: the theme's
  // platform is overridable for previews and tests, and the scroll curve should
  // follow the DEVICE the finger is actually on.
  if (Platform.isIOS || Platform.isMacOS) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
  return const _GlideClampingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );
}

/// The same glide, for lists that must KEEP clamping overscroll on every
/// platform because they carry a pull gesture of their own.
///
/// 🔴 WHY A SECOND ENTRY POINT (2026-08-01, field: "Android scrolling did not
/// change"). The chats list and the room/contact details lists read
/// `OverscrollNotification` at the top edge to drive their own pull-to-reveal.
/// iOS rubber-band overscroll competes with that gesture, which is why those
/// screens pin [ClampingScrollPhysics] on BOTH platforms instead of calling
/// [secretlyListPhysics] — and that pin is also why the glide never reached
/// them.
///
/// So: keep iOS byte-for-byte as it is today (plain clamping, gesture intact),
/// and give Android the glide it was supposed to get. The glide only scales the
/// BALLISTIC velocity of an in-range fling, so it cannot touch a drag-driven
/// pull either way.
ScrollPhysics secretlyPullListPhysics() {
  if (Platform.isIOS || Platform.isMacOS) {
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
  return const _GlideClampingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );
}

/// True when the running platform expects the iOS rubber-band at list ends.
///
/// Exposed so a widget that draws its own end-of-list affordance can match,
/// instead of each one re-deriving the platform.
bool get secretlyUsesBouncingScroll => Platform.isIOS || Platform.isMacOS;
