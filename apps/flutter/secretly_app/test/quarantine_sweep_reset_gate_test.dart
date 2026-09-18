// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

/// Unit tests for the storm-breaking gate on the quarantine recovery sweep's
/// force-reset (Fix A, 2026-07-24). The field root cause: the sweep force-reset
/// the ratchet session every 90 s UNCONDITIONALLY, tearing down even a
/// just-healed session, so two peers with dead parked backlog reset each other
/// into a permanent storm. `quarantineSweepResetDecline` is the pure decision.
void main() {
  const floor = 5 * 60 * 1000; // _quarantineSweepResetFloorMs
  const now = 10 * 1000 * 1000; // arbitrary large "epoch ms"

  String? decide({
    bool online = true,
    int epoch = 0,
    int oldest = now - 10 * 60 * 1000, // parked 10 min ago by default
    int lastReset = 0,
  }) =>
      AppController.quarantineSweepResetDecline(
        relayOnline: online,
        sessionEpochMs: epoch,
        oldestParkedMs: oldest,
        lastResetAtMs: lastReset,
        nowMs: now,
        floorMs: floor,
      );

  group('quarantineSweepResetDecline (storm fix)', () {
    test('offline never resets (can\'t heal, must not storm)', () {
      expect(decide(online: false), 'offline');
      // Cheapest gate wins even when everything else would allow a reset.
      expect(decide(online: false, epoch: 0, lastReset: 0), 'offline');
    });

    test('a session born AT/AFTER the dead backlog is NOT torn down', () {
      // THE core fix: epoch >= oldest ⇒ the live session is fresher than the
      // parked dead ciphertext ⇒ it is healthy; another reset is the storm.
      final oldest = now - 10 * 60 * 1000;
      expect(decide(epoch: oldest, oldest: oldest, lastReset: 0),
          'already_healed');
      expect(decide(epoch: oldest + 1, oldest: oldest, lastReset: 0),
          'already_healed');
    });

    test('a reset within the floor is suppressed (let the handshake land)', () {
      // Session older than backlog (would otherwise reset), but a reset from ANY
      // path fired recently → shared-stamp floor holds it off.
      final oldest = now - 10 * 60 * 1000;
      expect(decide(epoch: oldest - 1, oldest: oldest, lastReset: now - 1),
          'sweep_floor');
      expect(
          decide(epoch: oldest - 1, oldest: oldest, lastReset: now - (floor - 1)),
          'sweep_floor');
    });

    test('genuinely stuck peer resets (online, session predates backlog, past floor)',
        () {
      final oldest = now - 10 * 60 * 1000;
      expect(
          decide(
              epoch: oldest - 1, oldest: oldest, lastReset: now - floor - 1),
          isNull);
    });

    test('no live session (epoch 0) past the floor resets → fresh handshake', () {
      expect(decide(epoch: 0, lastReset: now - floor - 1), isNull);
      // epoch 0 must NOT be treated as "healed" just because 0 < oldest.
      expect(decide(epoch: 0, lastReset: now - floor - 1), isNot('already_healed'));
    });

    test('gate order: already_healed is checked before the floor', () {
      // Healed + also recently reset → the healed verdict (correctness) wins over
      // the floor (mere rate-limit), so diagnostics name the real reason.
      final oldest = now - 10 * 60 * 1000;
      expect(decide(epoch: oldest + 1, oldest: oldest, lastReset: now - 1),
          'already_healed');
    });

    test('regression: healed session with dead backlog no longer storms', () {
      // Pre-fix: the 90 s sweep reset this every tick. Now every sweep after the
      // session advanced past the backlog declines → the storm is broken.
      final oldest = now - 30 * 60 * 1000;
      final healedEpoch = now - 20 * 60 * 1000; // reset happened after backlog
      expect(
          decide(epoch: healedEpoch, oldest: oldest, lastReset: healedEpoch),
          isNot(isNull),
          reason: 'a healthy session newer than the backlog must not be reset');
    });
  });

  group('quarantineWireSuperseded (Fix C — dead-wire retirement)', () {
    const minAttempts = 3;
    bool superseded({
      required int epoch,
      required int parked,
      required int attempts,
    }) =>
        AppController.quarantineWireSuperseded(
          sessionEpochMs: epoch,
          wireParkedMs: parked,
          attemptCount: attempts,
          minAttempts: minAttempts,
        );

    test('no live session (epoch 0) never retires', () {
      // Without a session the wire may yet decrypt once one is established.
      expect(superseded(epoch: 0, parked: 1000, attempts: 99), isFalse);
    });

    test('session not strictly newer than the wire never retires', () {
      // Session could still ratchet forward onto the wire — don't drop it.
      expect(superseded(epoch: 1000, parked: 1000, attempts: 99), isFalse);
      expect(superseded(epoch: 999, parked: 1000, attempts: 99), isFalse);
    });

    test('superseded but too few attempts is not retired yet', () {
      // Give the re-NACK path its chance to tell the sender first.
      expect(superseded(epoch: 2000, parked: 1000, attempts: minAttempts - 1),
          isFalse);
    });

    test('superseded + enough attempts retires (dead-under-old-session)', () {
      expect(superseded(epoch: 2000, parked: 1000, attempts: minAttempts),
          isTrue);
      expect(superseded(epoch: 1001, parked: 1000, attempts: minAttempts),
          isTrue);
    });

    test('defensive: non-positive park stamp never retires', () {
      expect(superseded(epoch: 2000, parked: 0, attempts: 99), isFalse);
      expect(superseded(epoch: 2000, parked: -5, attempts: 99), isFalse);
    });
  });

  group('resetPingInitiatorGraceMs (Fix D — glare symmetry break)', () {
    const grace = 2500;
    int g(String me, String peer) =>
        AppController.resetPingInitiatorGraceMs(me, peer, graceMs: grace);

    test('smaller device_id leads immediately (0 grace)', () {
      expect(g('aaaa', 'bbbb'), 0);
      expect(g('dev01', 'dev02'), 0);
    });

    test('larger device_id waits the grace', () {
      expect(g('bbbb', 'aaaa'), grace);
      expect(g('dev02', 'dev01'), grace);
    });

    test('empty ids initiate immediately (never deadlock)', () {
      expect(g('', 'bbbb'), 0);
      expect(g('aaaa', ''), 0);
      expect(g('', ''), 0);
    });

    test('exactly one side of a pair leads (deterministic, no double-lead)', () {
      const a = 'device-alpha';
      const b = 'device-beta';
      // Each peer computes with the SAME two ids (self, other), mirrored.
      final aGrace = g(a, b); // alpha's view
      final bGrace = g(b, a); // beta's view
      expect((aGrace == 0) != (bGrace == 0), isTrue,
          reason: 'exactly one of the pair leads with 0 grace');
      expect(aGrace + bGrace, grace,
          reason: 'the other waits exactly the grace — no simultaneous prekey');
    });

    test('identical ids (degenerate) get 0 — self-pairing never hangs', () {
      expect(g('same', 'same'), 0);
    });
  });
}
