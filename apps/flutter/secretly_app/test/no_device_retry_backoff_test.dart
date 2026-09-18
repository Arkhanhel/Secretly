// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

/// Backoff for the "recipient has no devices yet" retry.
///
/// FIELD BUG (2026-07-31): the retry ran at a FIXED 10 s with a forced
/// cache-bypassing lookup, and its queue entry lives 24 h. A recipient that
/// never resolves (stale/ghost room member, peer who reinstalled) therefore
/// produced thousands of forced keys-server lookups a day. The keys service is
/// a per-IP token bucket (30 burst, ~1 req/s) shared by the user's own devices,
/// so this background loop drained the budget the SEND path needs and sends
/// started failing with "rate_limit" every few messages.
void main() {
  const baseMs = 10 * 1000; // _noDeviceRetryIntervalMs
  const capMs = 10 * 60 * 1000; // _noDeviceRetryMaxIntervalMs

  group('noDeviceRetryDelayMs', () {
    test('first attempt keeps the fast interval', () {
      // A peer that just published keys must still be picked up quickly.
      expect(AppController.noDeviceRetryDelayMs(0), baseMs);
    });

    test('doubles per consecutive empty attempt', () {
      expect(AppController.noDeviceRetryDelayMs(1), 20 * 1000);
      expect(AppController.noDeviceRetryDelayMs(2), 40 * 1000);
      expect(AppController.noDeviceRetryDelayMs(3), 80 * 1000);
    });

    test('never exceeds the cap, however long the peer stays unreachable', () {
      for (final attempts in <int>[6, 7, 12, 100, 100000]) {
        final delay = AppController.noDeviceRetryDelayMs(attempts);
        expect(
          delay,
          lessThanOrEqualTo(capMs),
          reason: 'attempts=$attempts must stay under the ceiling',
        );
      }
      expect(AppController.noDeviceRetryDelayMs(100), capMs);
    });

    test('is monotonic — a longer stall never retries sooner', () {
      var previous = 0;
      for (var attempts = 0; attempts <= 20; attempts++) {
        final delay = AppController.noDeviceRetryDelayMs(attempts);
        expect(delay, greaterThanOrEqualTo(previous));
        previous = delay;
      }
    });

    test('negative/garbage attempt counts degrade to the base interval', () {
      expect(AppController.noDeviceRetryDelayMs(-1), baseMs);
      expect(AppController.noDeviceRetryDelayMs(-999), baseMs);
    });

    test(
      'REGRESSION: an unreachable peer costs far fewer lookups than the old '
      'fixed interval over one hour',
      () {
        // Replays an hour of sweeps and counts how many lookups each policy
        // would issue. The old policy is what drained the shared token bucket.
        const oneHourMs = 60 * 60 * 1000;

        var backoffLookups = 0;
        var elapsed = 0;
        var attempts = 0;
        while (elapsed < oneHourMs) {
          elapsed += AppController.noDeviceRetryDelayMs(attempts);
          if (elapsed <= oneHourMs) {
            backoffLookups++;
            attempts++;
          }
        }

        final fixedLookups = oneHourMs ~/ baseMs; // old behaviour: 360/hour

        expect(fixedLookups, 360);
        // The whole point of the fix: an order of magnitude fewer forced hits.
        expect(backoffLookups, lessThan(fixedLookups ~/ 10));
      },
    );
  });
}
