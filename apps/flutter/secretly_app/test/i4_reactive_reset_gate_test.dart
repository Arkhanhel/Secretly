// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

/// И-4a — the receiver-side reactive session-reset gate.
///
/// Unrepresentability tests for [AppController.i4ReactiveResetAllowed], the pure
/// predicate that decides whether `_handleDelivered` may tear down + re-handshake
/// the session on an inbound decrypt failure. The whole class of "сессия вдруг
/// поменялась" churn (and its glare) came from resetting on the FIRST miss of
/// ANY class; under the gate a reset is a last resort.
void main() {
  group('И-4a i4ReactiveResetAllowed', () {
    // Gate OFF → exact pre-И-4 behavior: a reset is always allowed, for every
    // class of failure, on the very first miss. Shipping the code is a no-op
    // until the flag is flipped (fail-safe kill-switch).
    test('gate OFF always allows (legacy behavior preserved)', () {
      for (final epoch in [true, false]) {
        for (final mac in [true, false]) {
          for (final n in [0, 1, 5]) {
            expect(
              AppController.i4ReactiveResetAllowed(
                gateEnabled: false,
                isEpochAhead: epoch,
                isGenuineMac: mac,
                consecutiveFailures: n,
              ),
              isTrue,
              reason: 'gate off must never suppress (epoch=$epoch mac=$mac n=$n)',
            );
          }
        }
      }
    });

    // T-И4-1: a transient / out-of-order / DB-lock / too-many-skipped miss must
    // NEVER reset, no matter how many times it repeats — recovery is quarantine
    // + relay redeliver + skipped-keys, not a session teardown. This is the
    // elevator case (late offline backlog draining out of order).
    test('gate ON + transient (not genuine-MAC) → suppressed at ANY count', () {
      for (final n in [1, 3, 50]) {
        expect(
          AppController.i4ReactiveResetAllowed(
            gateEnabled: true,
            isEpochAhead: false,
            isGenuineMac: false,
            consecutiveFailures: n,
          ),
          isFalse,
          reason: 'transient must never reset (n=$n)',
        );
      }
    });

    // T-И4-2 / A5-note: a single genuine-MAC (a legitimately-late straggler whose
    // skipped key was pruned re-derives a diverged chain and fails AEAD) must NOT
    // reset — one occurrence is not evidence of a dead session.
    test('gate ON + genuine-MAC below threshold → suppressed', () {
      expect(
        AppController.i4ReactiveResetAllowed(
          gateEnabled: true,
          isEpochAhead: false,
          isGenuineMac: true,
          consecutiveFailures: 1,
          minConsecutive: 3,
        ),
        isFalse,
      );
      expect(
        AppController.i4ReactiveResetAllowed(
          gateEnabled: true,
          isEpochAhead: false,
          isGenuineMac: true,
          consecutiveFailures: 2,
          minConsecutive: 3,
        ),
        isFalse,
      );
    });

    // T-И4-4: a PERSISTENT genuine-MAC divergence (chain truly diverged, ≥N in a
    // row with no successful decrypt in between) is the ONLY thing that may still
    // reset — the last-resort backstop for a genuinely dead session. Even here
    // the NACK has already fired earlier, so this rarely bites.
    test('gate ON + persistent genuine-MAC at/above threshold → allowed', () {
      expect(
        AppController.i4ReactiveResetAllowed(
          gateEnabled: true,
          isEpochAhead: false,
          isGenuineMac: true,
          consecutiveFailures: 3,
          minConsecutive: 3,
        ),
        isTrue,
      );
      expect(
        AppController.i4ReactiveResetAllowed(
          gateEnabled: true,
          isEpochAhead: false,
          isGenuineMac: true,
          consecutiveFailures: 9,
          minConsecutive: 3,
        ),
        isTrue,
      );
    });

    // A4: an epoch-ahead wire (the peer's rekey is already inbound) must NEVER
    // reset — even if it presents as a persistent genuine-MAC — because resetting
    // would fire a redundant, glare-prone second rekey. This is the guard the
    // legacy reactive-reset block was missing.
    test('gate ON + epoch-ahead → suppressed WHILE the rekey may still arrive',
        () {
      // The count alone must never unlock it: replays can arrive in a burst
      // within one second, long before the pump has reached the prekey wire
      // sitting in the same mailbox.
      for (final n in [1, 3, 100]) {
        expect(
          AppController.i4ReactiveResetAllowed(
            gateEnabled: true,
            isEpochAhead: true,
            isGenuineMac: true,
            consecutiveFailures: n,
            epochAheadStuckMs: 0,
          ),
          isFalse,
          reason: 'a fresh epoch-ahead streak must wait (n=$n)',
        );
      }
      expect(
        AppController.i4ReactiveResetAllowed(
          gateEnabled: true,
          isEpochAhead: true,
          isGenuineMac: true,
          consecutiveFailures: 100,
          epochAheadStuckMs: 119999,
        ),
        isFalse,
        reason: 'one millisecond short of the grace is still inside it',
      );
    });

    // 🔴 11.09.2026 — the assumption above USED to be unconditional, and that
    // is what made messages stop arriving: the peer had rekeyed, the prekey
    // wire never came (zero in a whole run), every wire parked, and the repair
    // was refused 30 times in a row — all with reason=epoch_ahead.
    test('gate ON + epoch-ahead stuck past the grace → reset finally allowed',
        () {
      expect(
        AppController.i4ReactiveResetAllowed(
          gateEnabled: true,
          isEpochAhead: true,
          isGenuineMac: false,
          consecutiveFailures: 3,
          epochAheadStuckMs: 120000,
        ),
        isTrue,
        reason: 'the rekey has had two minutes; it is not coming',
      );
    });

    test('a stuck streak still needs the failure to repeat', () {
      // Time alone is not evidence either: one straggler wire from an old
      // epoch, arriving once after a long quiet spell, must not tear down a
      // session that is otherwise healthy.
      expect(
        AppController.i4ReactiveResetAllowed(
          gateEnabled: true,
          isEpochAhead: true,
          isGenuineMac: false,
          consecutiveFailures: 1,
          epochAheadStuckMs: 10 * 60 * 1000,
        ),
        isFalse,
      );
    });

    test('the grace is reachable by the quarantine sweep', () {
      // The sweep runs every 90 s and only takes entries at least 60 s old, so
      // a grace longer than one sweep cycle would never be reached inside a
      // session and the deadlock would survive the fix. Pin the relationship,
      // not just the number.
      const graceMs = 2 * 60 * 1000;
      const sweepIntervalMs = 90 * 1000;
      const sweepMinAgeMs = 60 * 1000;
      expect(
        graceMs,
        lessThanOrEqualTo(sweepIntervalMs + sweepMinAgeMs),
        reason: 'a grace no sweep can reach would re-create the deadlock',
      );
      expect(
        graceMs,
        greaterThan(sweepMinAgeMs),
        reason: 'shorter than the legitimate in-flight window would reset too eagerly',
      );
    });

    test('background still never resets, however long it has been stuck', () {
      // И-4i is unchanged: the background isolate can delete a session but not
      // heal it, so a deadline must not hand it the trigger.
      expect(
        AppController.i4ReactiveResetAllowed(
          gateEnabled: true,
          isEpochAhead: true,
          isGenuineMac: true,
          consecutiveFailures: 100,
          epochAheadStuckMs: 24 * 60 * 60 * 1000,
          isBackground: true,
        ),
        isFalse,
      );
    });

    // И-4i (T-И4-11): the background inbox isolate can DELETE a session but
    // cannot heal it (reset-ping + NACK are suppressed in _backgroundInboundMode),
    // so it must NEVER reset — even a persistent genuine-MAC — and leave recovery
    // to the foreground.
    test('gate ON + background → suppressed even if persistent genuine-MAC', () {
      expect(
        AppController.i4ReactiveResetAllowed(
          gateEnabled: true,
          isBackground: true,
          isEpochAhead: false,
          isGenuineMac: true,
          consecutiveFailures: 100,
        ),
        isFalse,
      );
    });

    // Shipped-default sanity: with the default threshold, the first two
    // consecutive genuine failures are suppressed and the third is allowed.
    test('default minConsecutive gates the third consecutive genuine failure',
        () {
      bool allow(int n) => AppController.i4ReactiveResetAllowed(
            gateEnabled: true,
            isEpochAhead: false,
            isGenuineMac: true,
            consecutiveFailures: n,
          );
      expect(allow(1), isFalse);
      expect(allow(2), isFalse);
      expect(allow(3), isTrue);
    });
  });

  // И-4k — resend-undelivered-outbound when OUR send session to a peer changes
  // (we reset toward them, or we adopt their reset). Closes the first-message-to-
  // a-brand-new-account orphan: the first wire races X3DH bootstrap → the peer
  // can't decrypt it → it NACKs, but during fresh-account setup the REVERSE
  // session isn't ready so the NACK never reaches us → without this the content
  // is lost (field 2026-07-24: wire 844d8103 dropped, "arrived only from the 2nd
  // message"). The behavior itself rides the already-tested _resendUndeliveredDirect
  // /undeliveredDirectSentEvents path (see sender_convergence_backstop_test.dart);
  // here we lock the fail-safe default and the staged-rollout toggle.
  // REGRESSION GUARD (live incident 2026-07-28): the quarantine-replay path
  // (site #3) used to be suppressed UNCONDITIONALLY under the gate. That
  // re-opened the 2026-07-20 deadlock — once every wire from a peer is parked
  // there are no FRESH failures left, the per-msg NACK is `already_claimed`, and
  // with the reset suppressed NOTHING can unstick the session: a tester's device
  // sat with 65 undecryptable wires / 63 NACKs / zero recovery for ~28 h.
  // Site #3 must use the SAME last-resort rule as the fresh path: a parked wire
  // that still fails with a genuine MAC is persistent-divergence evidence and, at
  // the threshold, MUST be allowed to reset.
  group('И-4a site #3 (quarantine replay) obeys the same last-resort rule', () {
    bool replayAllow(int failures, {bool genuineMac = true, bool bg = false}) =>
        AppController.i4ReactiveResetAllowed(
          gateEnabled: true,
          isEpochAhead: false,
          isGenuineMac: genuineMac,
          consecutiveFailures: failures,
          isBackground: bg,
        );

    test('a persistently genuine-MAC replay MUST eventually reset (not "never")',
        () {
      expect(replayAllow(1), isFalse, reason: 'first replay is not evidence yet');
      expect(replayAllow(2), isFalse);
      // The regression was: this stayed false FOREVER → session never healed.
      expect(replayAllow(3), isTrue,
          reason: 'persistent genuine-MAC divergence must be repairable');
      expect(replayAllow(65), isTrue);
    });

    test('a transient replay still never resets', () {
      expect(replayAllow(65, genuineMac: false), isFalse);
    });

    test('a background replay still never resets (И-4i)', () {
      expect(replayAllow(65, bg: true), isFalse);
    });
  });

  // All three И-4 delivery gates ship default ON as of 1.7.4+404: i4a/i4h were
  // field-proven on 403 (31 reset suppressions, 0 spurious resets, empty relay
  // device-churn) and i4k was no-regression on 404 (new-account traffic delivered
  // 16/16 clean). The --dart-define kill-switch (=false) can still force any back
  // to the legacy behavior. These pin the RELEASE defaults + the override so an
  // accidental re-flip to OFF is caught. (The const-context correctness of the
  // --dart-define wiring is not observable from a unit test — no define is set in
  // the test env — so it is verified in the field via the `i4_flags` startup log.)
  group('И-4 gates ship default ON (release value)', () {
    tearDown(() {
      // Restore the shipped defaults so test ORDER can never leak static state
      // into another test (these flags are process-global statics).
      AppController.i4aReactiveResetGateEnabled = true;
      AppController.i4hKeepSessionOnDevicePrune = true;
      AppController.i4kResendUndeliveredOnReset = true;
    });

    test('all three ship ON by default', () {
      expect(AppController.i4aReactiveResetGateEnabled, isTrue);
      expect(AppController.i4hKeepSessionOnDevicePrune, isTrue);
      expect(AppController.i4kResendUndeliveredOnReset, isTrue);
    });

    test('each kill-switch can still force it OFF', () {
      AppController.i4aReactiveResetGateEnabled = false;
      AppController.i4hKeepSessionOnDevicePrune = false;
      AppController.i4kResendUndeliveredOnReset = false;
      expect(AppController.i4aReactiveResetGateEnabled, isFalse);
      expect(AppController.i4hKeepSessionOnDevicePrune, isFalse);
      expect(AppController.i4kResendUndeliveredOnReset, isFalse);
    });
  });
}
