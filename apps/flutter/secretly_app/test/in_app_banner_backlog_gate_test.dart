// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

// Telegram-style "live only" gate for the in-app banner (2026-07-15).
//
// When the app is opened after a pile of messages arrived (deep sleep / many
// senders), the resume-drain catches the whole backlog up in a burst while the
// app is already foreground — each caught-up message used to pop its own in-app
// banner. shouldSuppressInAppBannerAsBacklog() marks those as backlog (either
// inside the post-resume grace, or older than the live window) so ONLY genuinely
// live arrivals banner. This gate never touches the system/background push.
void main() {
  const nowMs = 1000000000000; // fixed "now"
  const grace = 4000;
  const live = 90 * 1000;

  bool suppress({
    required int foregroundSinceMs,
    required int? sourceCreatedAtMs,
  }) =>
      AppController.shouldSuppressInAppBannerAsBacklog(
        nowMs: nowMs,
        foregroundSinceMs: foregroundSinceMs,
        sourceCreatedAtMs: sourceCreatedAtMs,
        resumeGraceMs: grace,
        liveWindowMs: live,
      );

  group('resume-grace arm', () {
    test('message just after resume (inside grace) is backlog → suppressed', () {
      // Resumed 500ms ago, message is brand new → still part of the open burst.
      expect(
        suppress(foregroundSinceMs: nowMs - 500, sourceCreatedAtMs: nowMs),
        isTrue,
      );
    });

    test('message past the grace window banners (live)', () {
      // Resumed 10s ago (grace expired), fresh message → genuinely live.
      expect(
        suppress(foregroundSinceMs: nowMs - 10000, sourceCreatedAtMs: nowMs),
        isFalse,
      );
    });

    test('foregroundSinceMs == 0 (never resumed) never trips the grace arm', () {
      expect(
        suppress(foregroundSinceMs: 0, sourceCreatedAtMs: nowMs),
        isFalse,
      );
    });

    test('grace boundary is exclusive at exactly grace ms', () {
      // now - foregroundSinceMs == grace → NOT < grace → not suppressed by grace.
      expect(
        suppress(
            foregroundSinceMs: nowMs - grace, sourceCreatedAtMs: nowMs),
        isFalse,
      );
    });
  });

  group('live-window arm', () {
    test('old backlog message (older than live window) suppressed even long '
        'after resume', () {
      // Resumed 1 minute ago (grace long gone), but the message itself is 5 min
      // old → caught up late from a slow drain → still backlog.
      expect(
        suppress(
          foregroundSinceMs: nowMs - 60000,
          sourceCreatedAtMs: nowMs - 5 * 60 * 1000,
        ),
        isTrue,
      );
    });

    test('recent message past the resume grace banners (live)', () {
      expect(
        suppress(
          foregroundSinceMs: nowMs - 60000,
          sourceCreatedAtMs: nowMs - 5000,
        ),
        isFalse,
      );
    });

    test('unknown message age (null / non-positive) does not trip live arm', () {
      // Can't prove it's old → don't suppress via age; only the grace arm applies.
      expect(
        suppress(foregroundSinceMs: nowMs - 60000, sourceCreatedAtMs: null),
        isFalse,
      );
      expect(
        suppress(foregroundSinceMs: nowMs - 60000, sourceCreatedAtMs: 0),
        isFalse,
      );
    });

    test('live-window boundary is exclusive at exactly live ms', () {
      // now - sourceCreatedAtMs == live → NOT > live → not suppressed by age.
      expect(
        suppress(
          foregroundSinceMs: nowMs - 60000,
          sourceCreatedAtMs: nowMs - live,
        ),
        isFalse,
      );
    });
  });

  test('genuinely live message while actively using the app banners', () {
    // Resumed 30s ago, message arriving now → the case we MUST keep showing.
    expect(
      suppress(foregroundSinceMs: nowMs - 30000, sourceCreatedAtMs: nowMs),
      isFalse,
    );
  });

  // 2026-07-19: the DEFAULT grace must cover the real catch-up drain (10-20 s
  // of fetch+decrypt after resume), not just the first tick — every message
  // applied there already fired a system notification while the app slept.
  // These call WITHOUT resumeGraceMs so a regression of the default is caught.
  group('default resume grace covers the whole catch-up drain', () {
    test('message applied 15s after resume is still backlog → suppressed', () {
      expect(
        AppController.shouldSuppressInAppBannerAsBacklog(
          nowMs: nowMs,
          foregroundSinceMs: nowMs - 15000,
          sourceCreatedAtMs: nowMs,
        ),
        isTrue,
      );
    });

    test('message half a minute after resume banners (live)', () {
      expect(
        AppController.shouldSuppressInAppBannerAsBacklog(
          nowMs: nowMs,
          foregroundSinceMs: nowMs - 30000,
          sourceCreatedAtMs: nowMs,
        ),
        isFalse,
      );
    });
  });
}
