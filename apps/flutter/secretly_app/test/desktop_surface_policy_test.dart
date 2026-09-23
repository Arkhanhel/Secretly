// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Guards the "One Desktop Path" decision: the MOBILE entrypoint must never
// render the legacy wide layout (Surface B) on a desktop OS. Shipping the
// mobile main.dart as a desktop app is the documented "double desktop"
// failure.
//
// These tests run on the VM (a desktop OS), so `isDesktopOs` is true here and
// the desktop branch is exercised directly.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop_surface_policy.dart';

void main() {
  test('the test host is a desktop OS (premise of this file)', () {
    expect(isDesktopOs, isTrue);
  });

  test('desktop OS never gets the legacy wide layout, at any width', () {
    for (final width in const <double>[320, 800, 1179, 1180, 1440, 3840]) {
      expect(
        useLegacyWideLayout(width),
        isFalse,
        reason: 'width $width must stay on the mobile layout on a desktop OS',
      );
    }
  });

  test('the rollback flag is off by default', () {
    expect(kLegacyDesktopSurfaceOnDesktopOs, isFalse);
  });

  group('mobile behaviour is unchanged (the shipped app)', () {
    // The mobile clients are RELEASED. The desktop-OS opt-out must not have
    // altered a single decision they make, so both sides of the breakpoint are
    // pinned here rather than assumed.
    test('phones stay on the mobile layout', () {
      for (final width in const <double>[320, 390, 428, 768, 1024, 1179]) {
        expect(
          legacyWideLayoutFor(isDesktop: false, width: width),
          isFalse,
          reason: 'width \$width is below the breakpoint',
        );
      }
    });

    test('wide tablets still get the legacy wide layout', () {
      // iPad 11" landscape is 1194 and 12.9" is 1366 — real users are here.
      for (final width in const <double>[1180, 1194, 1366, 2048]) {
        expect(
          legacyWideLayoutFor(isDesktop: false, width: width),
          isTrue,
          reason: 'width \$width is at or above the breakpoint',
        );
      }
    });

    test('the rollback flag does not touch mobile', () {
      // It only ever gates the desktop-OS branch.
      expect(legacyWideLayoutFor(isDesktop: false, width: 1180), isTrue);
      expect(legacyWideLayoutFor(isDesktop: false, width: 1179), isFalse);
    });
  });

  test('the tablet breakpoint is unchanged', () {
    // Deliberately still 1180: iPad is a shipped device family and real users
    // are on Surface B in landscape today. Moving them is a product decision
    // gated on epic T-01…T-06, not a cleanup.
    expect(kWideLayoutBreakpoint, 1180);
  });
}
