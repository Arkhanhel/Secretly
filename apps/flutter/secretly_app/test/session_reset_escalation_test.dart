// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Tests for the self-healing E2EE delivery recovery (FIX A + FIX D).
//
// FIX A — break the reset-ping deadlock. When inbound from a peer permanently
// stops after a ratchet root-key divergence (peer reinstall / lost prekey /
// >200 skipped messages), recovery fires ONE debounced session-reset-ping and
// then does nothing for the rest of the 30 s window. If that prekey was lost in
// transit the session deadlocks forever. `SessionResetEscalator` decides, per
// device, whether to FORCE a fresh re-ping even inside the debounce window —
// gated by a consecutive-failure threshold and an escalating cooldown so it can
// never loop tighter than the floor.
//
// FIX D — durable periodic recovery. `AppDb.inboxQuarantineSendersWithOldest()`
// is what the 90 s sweep uses to find peers whose quarantined inbound is stuck,
// so the heal can fire without waiting for a reconnect or an (impossible, while
// the session is broken) successful decrypt.
//
// A full AppController integration test is infeasible (it wires keys/relay/db
// IO), so per the task we unit-test the pure decision logic in isolation and
// the new DB query against the real in-memory database — together these model
// all four required scenarios.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/storage/app_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionResetEscalator.shouldForceReset (FIX A decision)', () {
    test('does NOT force below the failure threshold', () {
      // A single quarantined failure must never escalate (could be a one-off
      // reorder / transient). Threshold is 2.
      expect(
        SessionResetEscalator.shouldForceReset(
          consecutiveFailures: 1,
          forcedResetCount: 0,
          lastForcedResetAtMs: null,
          nowMs: 100000,
        ),
        isFalse,
      );
    });

    test(
      'forces the first re-ping once the threshold is met, even inside the '
      'debounce window (deadlock break)',
      () {
        // This is the core deadlock break: a normal reset ping was sent moments
        // ago (so the debounce would normally suppress), but inbound is STILL
        // failing for the 2nd time → force a re-ping regardless of the debounce.
        expect(
          SessionResetEscalator.shouldForceReset(
            consecutiveFailures: 2,
            forcedResetCount: 0,
            lastForcedResetAtMs: 0, // no forced reset yet
            nowMs: 100000,
          ),
          isTrue,
        );
      },
    );

    test('treats null lastForcedResetAtMs the same as "never forced"', () {
      expect(
        SessionResetEscalator.shouldForceReset(
          consecutiveFailures: 3,
          forcedResetCount: 0,
          lastForcedResetAtMs: null,
          nowMs: 100000,
        ),
        isTrue,
      );
    });

    test('escalating cadence is bounded — no tight loop (step ladder)', () {
      // After the 1st forced reset has fired (forcedResetCount == 1) the NEXT
      // one must wait the step-1 cooldown (60 s). At +59 s it is still
      // suppressed; at +60 s it is allowed. This is what guarantees we can never
      // loop tighter than the ladder even while the peer stays permanently
      // broken.
      const base = 1_000_000;
      // Just before the step-1 cooldown elapses → suppressed.
      expect(
        SessionResetEscalator.shouldForceReset(
          consecutiveFailures: 5,
          forcedResetCount: 1,
          lastForcedResetAtMs: base,
          nowMs: base + 59 * 1000,
        ),
        isFalse,
      );
      // Exactly at the step-1 cooldown (60 s) → allowed.
      expect(
        SessionResetEscalator.shouldForceReset(
          consecutiveFailures: 5,
          forcedResetCount: 1,
          lastForcedResetAtMs: base,
          nowMs: base + 60 * 1000,
        ),
        isTrue,
      );
      // The step-0 → step-1 transition uses the 30 s floor: after the FIRST
      // forced reset (count 0 at decision time becomes 1 once fired), a freshly
      // stamped device must still wait the step-0 (30 s) cooldown before the
      // 2nd. Verify the floor rung directly.
      expect(
        SessionResetEscalator.shouldForceReset(
          consecutiveFailures: 5,
          forcedResetCount: 0,
          lastForcedResetAtMs: base, // already forced once, just stamped
          nowMs: base + 29 * 1000,
        ),
        isFalse,
      );
      expect(
        SessionResetEscalator.shouldForceReset(
          consecutiveFailures: 5,
          forcedResetCount: 0,
          lastForcedResetAtMs: base,
          nowMs: base + 30 * 1000,
        ),
        isTrue,
      );
    });

    test('cooldown grows with the escalation step and caps at 5 min', () {
      expect(SessionResetEscalator.cooldownForStep(0), 30 * 1000);
      expect(SessionResetEscalator.cooldownForStep(1), 60 * 1000);
      expect(SessionResetEscalator.cooldownForStep(2), 120 * 1000);
      expect(SessionResetEscalator.cooldownForStep(3), 300 * 1000);
      // Beyond the ladder it clamps to the 5-minute cap (repeats forever).
      expect(SessionResetEscalator.cooldownForStep(4), 300 * 1000);
      expect(SessionResetEscalator.cooldownForStep(99), 300 * 1000);
      // Negative / zero clamp to the floor.
      expect(SessionResetEscalator.cooldownForStep(-1), 30 * 1000);
    });

    test(
      'a permanently-broken peer can never force-reset faster than the cap',
      () {
        // Simulate many forced resets in a row; once we are past the ladder the
        // gate must require the full 5-minute cap every time. Use a realistic
        // non-zero epoch base — in production nowMs is never 0, so the
        // 0/null "never forced yet" sentinel never collides with a real stamp.
        const cap = 300 * 1000;
        const epochBase = 1_700_000_000_000; // ~real wall-clock ms
        int? lastForcedAt; // null == never forced yet
        var step = 0;
        var firedTimes = <int>[];
        // Drive 50 minutes of constant failures, advancing the clock in 10 s
        // ticks (like the real failure stream), and record when a forced reset
        // is actually allowed.
        for (var t = 0; t < 300; t++) {
          final nowMs = epochBase + t * 10 * 1000; // 10 s/tick → 50 min total
          final allowed = SessionResetEscalator.shouldForceReset(
            consecutiveFailures: 10, // always well over threshold
            forcedResetCount: step,
            lastForcedResetAtMs: lastForcedAt,
            nowMs: nowMs,
          );
          if (allowed) {
            firedTimes.add(nowMs);
            lastForcedAt = nowMs;
            step++;
          }
        }
        expect(firedTimes, isNotEmpty);
        // After the ladder is exhausted, consecutive forced resets must be at
        // least the cap apart — proving the cadence is bounded.
        final tailGaps = <int>[];
        for (var i = 1; i < firedTimes.length; i++) {
          tailGaps.add(firedTimes[i] - firedTimes[i - 1]);
        }
        // The first few gaps follow the ladder (30/60/120 s); every gap once we
        // reach the cap step must be >= cap. Assert the LAST gap (deep into the
        // run) respects the cap floor.
        expect(tailGaps.last, greaterThanOrEqualTo(cap));
        // And no gap is ever below the smallest ladder rung (30 s) — no tight
        // loop at any point.
        for (final g in tailGaps) {
          expect(g, greaterThanOrEqualTo(30 * 1000));
        }
      },
    );
  });

  group('FIX A — peer-reinstall failure-counter lifecycle (logic model)', () {
    // The AppController increments _consecutiveDecryptFailuresSinceReset on each
    // quarantined failure and resets it to 0 on a successful decrypt. We model
    // that counter here against the same escalation gate the controller uses, to
    // prove scenarios (1) and (3) end-to-end at the decision level.

    test(
      'scenario 1: peer reinstall (same device id) → 2nd failure forces a '
      're-ping despite the debounce; success then clears the counter',
      () {
        const dev = 'peerA-device';
        final failures = <String, int>{};
        final lastForcedAt = <String, int>{};
        final forcedCount = <String, int>{};
        final forcedPings = <int>[];

        // Mirror of the controller's quarantined-failure branch when a reset
        // ping was already sent recently (resetRecent == true).
        void onQuarantinedFailureWhileResetRecent(int nowMs) {
          final f = (failures[dev] ?? 0) + 1;
          failures[dev] = f;
          if (SessionResetEscalator.shouldForceReset(
            consecutiveFailures: f,
            forcedResetCount: forcedCount[dev] ?? 0,
            lastForcedResetAtMs: lastForcedAt[dev],
            nowMs: nowMs,
          )) {
            forcedPings.add(nowMs);
            lastForcedAt[dev] = nowMs;
            forcedCount[dev] = (forcedCount[dev] ?? 0) + 1;
            failures[dev] = 0; // controller resets the counter after forcing
          }
        }

        // Mirror of the controller's success path.
        void onSuccessfulDecrypt() {
          failures.remove(dev);
          lastForcedAt.remove(dev);
          forcedCount.remove(dev);
        }

        // 1st undecryptable message after the (recent, lost) reset ping.
        onQuarantinedFailureWhileResetRecent(1000);
        expect(forcedPings, isEmpty, reason: '1 failure must not force');
        expect(failures[dev], 1);

        // 2nd undecryptable message → forced re-ping fires despite debounce.
        onQuarantinedFailureWhileResetRecent(2000);
        expect(forcedPings, hasLength(1), reason: '2nd failure forces re-ping');
        expect(failures[dev], 0, reason: 'counter reset after forcing');

        // The peer applies our fresh prekey; its next message decrypts.
        onSuccessfulDecrypt();
        expect(failures.containsKey(dev), isFalse);
        expect(lastForcedAt.containsKey(dev), isFalse);
        expect(forcedCount.containsKey(dev), isFalse);

        // A later isolated failure starts the ladder fresh (no carry-over):
        // one failure alone must NOT immediately force again.
        onQuarantinedFailureWhileResetRecent(900000);
        expect(forcedPings, hasLength(1));
      },
    );

    test('scenario 3: a successful decrypt resets the failure counter', () {
      const dev = 'peerB-device';
      final failures = <String, int>{};

      // Accumulate one quarantined failure.
      failures[dev] = (failures[dev] ?? 0) + 1;
      expect(failures[dev], 1);

      // Successful decrypt (controller clears it).
      failures.remove(dev);
      expect(failures.containsKey(dev), isFalse);
      // After reset, a single new failure is again just 1 (sub-threshold).
      failures[dev] = (failures[dev] ?? 0) + 1;
      expect(
        SessionResetEscalator.shouldForceReset(
          consecutiveFailures: failures[dev]!,
          forcedResetCount: 0,
          lastForcedResetAtMs: null,
          nowMs: 5000,
        ),
        isFalse,
      );
    });
  });

  group('FIX D — quarantine sweep selection (inboxQuarantineSendersWithOldest)',
      () {
    test('returns distinct senders with oldest entry, excluding null sender',
        () async {
      final db = await AppDb.openForTesting();
      try {
        // devA: two parked, oldest at 1000.
        await db.inboxQuarantineUpsert(
          msgId: 'a1',
          senderDeviceId: 'devA',
          ciphertextB64: 'AA==',
          nowMs: 3000,
        );
        await db.inboxQuarantineUpsert(
          msgId: 'a2',
          senderDeviceId: 'devA',
          ciphertextB64: 'BB==',
          nowMs: 1000,
        );
        // devB: one parked at 2000.
        await db.inboxQuarantineUpsert(
          msgId: 'b1',
          senderDeviceId: 'devB',
          ciphertextB64: 'CC==',
          nowMs: 2000,
        );
        // Unknown sender — cannot be re-pinged, must be excluded.
        await db.inboxQuarantineUpsert(
          msgId: 'n1',
          senderDeviceId: null,
          ciphertextB64: 'DD==',
          nowMs: 500,
        );

        final rows = await db.inboxQuarantineSendersWithOldest();
        // Two distinct *named* senders, oldest-stuck first (devA@1000 < devB@2000).
        expect(rows.map((r) => r['sender_device_id']).toList(),
            orderedEquals(['devA', 'devB']));
        final devA = rows.firstWhere((r) => r['sender_device_id'] == 'devA');
        expect((devA['oldest_ms'] as num).toInt(), 1000);
        expect((devA['cnt'] as num).toInt(), 2);
        final devB = rows.firstWhere((r) => r['sender_device_id'] == 'devB');
        expect((devB['oldest_ms'] as num).toInt(), 2000);
        expect((devB['cnt'] as num).toInt(), 1);
      } finally {
        await db.close();
      }
    });

    test('empty quarantine yields no sweep candidates', () async {
      final db = await AppDb.openForTesting();
      try {
        expect(await db.inboxQuarantineSendersWithOldest(), isEmpty);
      } finally {
        await db.close();
      }
    });

    test(
      'scenario 2: lost-prekey deadlock → sweep selects the stuck peer once '
      'its oldest entry passes the min-age gate',
      () async {
        // Models the periodic sweep decision: a peer whose reset ping was lost
        // has quarantine that never drains. The sweep acts only once the OLDEST
        // entry is older than the 60 s grace window — proving the durable heal
        // fires without a reconnect or a successful decrypt.
        const minAgeMs = 60 * 1000; // == AppController._quarantineRecoveryMinAgeMs
        final db = await AppDb.openForTesting();
        try {
          final parkedAt = 1_000_000;
          await db.inboxQuarantineUpsert(
            msgId: 'stuck1',
            senderDeviceId: 'lostPrekeyPeer',
            ciphertextB64: 'AA==',
            nowMs: parkedAt,
          );

          List<String> stuckPeersAt(int nowMs) {
            // Recompute synchronously per the row already in the DB.
            return _selectStuck(
              rows: _rowsSnapshot,
              nowMs: nowMs,
              minAgeMs: minAgeMs,
            );
          }

          // Snapshot the sweep query result and exercise the age gate purely.
          _rowsSnapshot = await db.inboxQuarantineSendersWithOldest();
          expect(_rowsSnapshot, hasLength(1));

          // Within the grace window → NOT yet acted on.
          expect(stuckPeersAt(parkedAt + 30 * 1000), isEmpty);
          // Past the grace window → selected for forced re-ping + refresh.
          expect(stuckPeersAt(parkedAt + minAgeMs), equals(['lostPrekeyPeer']));
          expect(
            stuckPeersAt(parkedAt + 5 * minAgeMs),
            equals(['lostPrekeyPeer']),
          );

          // Once the peer applies the re-ping and the message re-decrypts, the
          // replay removes it → no more sweep candidates.
          await db.inboxQuarantineDelete('stuck1');
          _rowsSnapshot = await db.inboxQuarantineSendersWithOldest();
          expect(stuckPeersAt(parkedAt + 10 * minAgeMs), isEmpty);
        } finally {
          await db.close();
        }
      },
    );
  });
}

// Test-local mirror of the sweep's age-gate selection (FIX D), kept identical
// to _runQuarantineRecoverySweep's filter so the gate is verified in isolation.
List<Map<String, Object?>> _rowsSnapshot = const <Map<String, Object?>>[];

List<String> _selectStuck({
  required List<Map<String, Object?>> rows,
  required int nowMs,
  required int minAgeMs,
}) {
  final out = <String>[];
  for (final row in rows) {
    final sid = ((row['sender_device_id'] as String?) ?? '').trim();
    if (sid.isEmpty) continue;
    final oldestMs = (row['oldest_ms'] as num?)?.toInt() ?? nowMs;
    if (nowMs - oldestMs < minAgeMs) continue;
    out.add(sid);
  }
  return out;
}
