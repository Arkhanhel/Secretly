// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_manager.dart';

/// The phantom incoming call (2026-07-31, user report: "я звонок отменил, а он
/// при следующем заходе всё ещё видит дозвон").
///
/// Two independent defects had to line up, so both are pinned here.
void main() {
  const windowMs = CallManager.ringTimeoutSeconds * 1000;

  group('incomingRingExpired — judge the ring by the WALL clock', () {
    // The ring timeout is a plain Timer, and a suspended iOS app does not run
    // timers: they resume where they stopped. So "how long has this been
    // ringing" must be measured against the invite's timestamp, never against
    // a timer that was asleep.

    test('a fresh ring is not expired', () {
      expect(
        CallManager.incomingRingExpired(startedAtMs: 1000, nowMs: 1000),
        isFalse,
      );
      expect(
        CallManager.incomingRingExpired(
          startedAtMs: 1000,
          nowMs: 1000 + windowMs - 1,
        ),
        isFalse,
      );
    });

    test('exactly at the window is still alive; past it is not', () {
      expect(
        CallManager.incomingRingExpired(
          startedAtMs: 1000,
          nowMs: 1000 + windowMs,
        ),
        isFalse,
      );
      expect(
        CallManager.incomingRingExpired(
          startedAtMs: 1000,
          nowMs: 1000 + windowMs + 1,
        ),
        isTrue,
      );
    });

    test('REGRESSION: a call suspended for hours is expired, not re-shown', () {
      // The exact field scenario: the app was backgrounded while ringing, the
      // caller cancelled, and hours later the resume handler put the incoming
      // UI back on screen because the timer had never advanced.
      expect(
        CallManager.incomingRingExpired(
          startedAtMs: 1000,
          nowMs: 1000 + const Duration(hours: 6).inMilliseconds,
        ),
        isTrue,
      );
    });

    test('an untrustworthy origin never expires a call', () {
      // Without a stamp we cannot judge age, and cancelling a call that might
      // be real is worse than showing one that might be stale.
      expect(
        CallManager.incomingRingExpired(startedAtMs: null, nowMs: 999999),
        isFalse,
      );
      expect(
        CallManager.incomingRingExpired(startedAtMs: 0, nowMs: 999999),
        isFalse,
      );
      expect(
        CallManager.incomingRingExpired(startedAtMs: -5, nowMs: 999999),
        isFalse,
      );
    });

    test('clock skew (now BEFORE the invite) is not treated as expired', () {
      expect(
        CallManager.incomingRingExpired(startedAtMs: 100000, nowMs: 1000),
        isFalse,
      );
    });
  });

  group('isTerminalCallSignalAction — age may silence a start, never an end', () {
    // The startup drain dropped EVERY buffered signal older than 60 s. For a
    // cancel that inverts its own purpose: the signal that would dismiss the
    // ringing UI is discarded, and the UI it targeted is what survives.

    test('every call-ending action is terminal', () {
      for (final a in ['hangup', 'cancel', 'decline', 'busy']) {
        expect(
          CallManager.isTerminalCallSignalAction(a),
          isTrue,
          reason: '"$a" ends a call and must never be dropped for being old',
        );
      }
    });

    test('actions that START or ADVANCE a call are not terminal', () {
      // These stay age-gated: acting on them late is what creates a ghost.
      for (final a in ['invite', 'offer', 'answer', 'ice', 'accept', 'restore']) {
        expect(
          CallManager.isTerminalCallSignalAction(a),
          isFalse,
          reason: '"$a" opens or advances a call, so age must still gate it',
        );
      }
    });

    test('comparison tolerates case and padding from the wire', () {
      expect(CallManager.isTerminalCallSignalAction('  HANGUP '), isTrue);
      expect(CallManager.isTerminalCallSignalAction('Cancel'), isTrue);
      expect(CallManager.isTerminalCallSignalAction(''), isFalse);
    });
  });
}
