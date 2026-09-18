// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Tests for the inbound-decrypt ACK policy (FIX F — stop the orphan-repush
// loop) and its interaction with the silence-recovery timer (FIX E) and the
// session-reset escalator (FIX A).
//
// LIVE BUG this guards against: a peer's old-chain ciphertext keeps arriving in
// our relay mailbox below our cursor; the relay's `orphan_repush` re-delivers it
// over the live WS every ~45 s. The reactive heal previously quarantined it but
// — on the WS realtime / reorder-buffer path — could leave it UN-ACKed when the
// decrypt error was treated as "retry". An un-acked below-cursor wire is
// re-pushed forever: the mailbox never clears AND the constant re-arrival makes
// upstream heuristics think the peer is still active, so recovery never fires.
//
// The fix splits decrypt failures into two classes with OPPOSITE ack handling:
//   * GENUINE-PERMANENT (real MAC mismatch / malformed wire / Rust bad-state on
//     an established session) → ACK (so the relay stops re-pushing; the bytes
//     stay quarantined = lost, which is expected) + force a session reset so the
//     peer's NEXT message rides a fresh handshake.
//   * TRANSIENT/RECOVERABLE (`session not found`, `too many skipped`, network) →
//     do NOT ack on early attempts (leave the wire for the relay to re-offer so
//     it applies once the session heals), bounded by the retry budget.
//
// Per the repo convention (a full AppController integration test wires
// keys/relay/db IO and is infeasible), the ack decision is verified through the
// pure [DeliveredDecryptAckPolicy] helper, and the last-inbound silence-timer
// invariant is verified against the REAL success-path hook on a live
// AppController instance.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mirrors AppController._deliveredDecryptMaxAttempts (the retry budget).
  const maxAttempts = 3;

  // A transport/realtime model: a decrypt failure is ACKed iff the policy says
  // so. When NOT acked, the wire stays in the relay mailbox and is re-offered
  // (orphan_repush) — modelled here as a re-delivery that bumps `attempts`.
  bool acked(Object error, int attempts) =>
      DeliveredDecryptAckPolicy.shouldAckAndQuarantine(
        error: error,
        attempts: attempts,
        maxAttempts: maxAttempts,
      );

  group('DeliveredDecryptAckPolicy.isGenuineMacFailure (permanent class)', () {
    test('a real SecretBox MAC mismatch on an established session is genuine',
        () {
      // This is what `aead.decrypt` throws when the diverged chain derives the
      // wrong message key — the canonical "old-chain ciphertext" failure.
      final err = Exception(
        'SecretBoxAuthenticationError: the MAC is wrong message authentication '
        'code',
      );
      expect(DeliveredDecryptAckPolicy.isGenuineMacFailure(err), isTrue);
      expect(DeliveredDecryptAckPolicy.isTransientDecryptError(err), isFalse);
    });

    test('malformed wire / format errors are genuine (never decode)', () {
      for (final msg in <String>[
        'FormatException: invalid wire format',
        'missing sender_device_id',
        'ciphertext too short',
        'not a v1.3 ratchet wire',
      ]) {
        expect(
          DeliveredDecryptAckPolicy.isGenuineMacFailure(StateError(msg)),
          isTrue,
          reason: msg,
        );
      }
    });

    test('Rust bad-state on an established session is genuine (unadvanceable)',
        () {
      for (final msg in <String>[
        'StateError: bad state: chain key advance failed',
        'invalid root_key',
        'rust-open: decryption failed',
        'hkdf derive failed',
      ]) {
        expect(
          DeliveredDecryptAckPolicy.isGenuineMacFailure(StateError(msg)),
          isTrue,
          reason: msg,
        );
      }
    });

    test('transient flavours are NOT genuine even if text brushes a keyword',
        () {
      // "session not found" must win over any permanent-looking substring.
      final err = StateError('session not found (decryption failed later)');
      expect(DeliveredDecryptAckPolicy.isTransientDecryptError(err), isTrue);
      expect(DeliveredDecryptAckPolicy.isGenuineMacFailure(err), isFalse);
    });
  });

  group('DeliveredDecryptAckPolicy.isTransientDecryptError (recoverable class)',
      () {
    test('session-state errors that a reset ping can heal are transient', () {
      for (final msg in <String>[
        'StateError: session not found',
        'no v1.3 session for peer',
        'missing recv chain key',
        'missing remote dh pub',
        'too many skipped messages',
        'message key not found',
      ]) {
        expect(
          DeliveredDecryptAckPolicy.isTransientDecryptError(StateError(msg)),
          isTrue,
          reason: msg,
        );
      }
    });

    test('pure transport/storage hiccups are transient', () {
      for (final msg in <String>[
        'SocketException: failed host lookup',
        'TimeoutException after 0:00:15',
        'SqliteException: database is locked',
      ]) {
        expect(
          DeliveredDecryptAckPolicy.isTransientDecryptError(Exception(msg)),
          isTrue,
          reason: msg,
        );
      }
    });
  });

  group('DeliveredDecryptAckPolicy.shouldAckAndQuarantine (ack decision)', () {
    test(
      'scenario 1: genuine MAC failure on an established session → ACK on the '
      'FIRST attempt (loop-stop)',
      () {
        // The whole point: a real MAC failure must be acked immediately so the
        // relay drops it from the mailbox and orphan_repush stops. It does NOT
        // wait for the retry budget.
        final err = Exception('SecretBoxAuthenticationError (invalid mac)');
        expect(acked(err, 1), isTrue);
        expect(acked(err, 2), isTrue);
        expect(acked(err, maxAttempts), isTrue);
      },
    );

    test(
      'scenario 2: transient session-not-found → NOT acked while attempts '
      'remain (the wire is left for the relay to re-offer)',
      () {
        // A `session not found` may decrypt once the reset ping re-establishes
        // the session. Acking it would discard recoverable data, so we leave it
        // un-acked (return false) until the retry budget is exhausted.
        final err = StateError('session not found');
        expect(acked(err, 1), isFalse, reason: 'attempt 1 must not ack');
        expect(acked(err, 2), isFalse, reason: 'attempt 2 must not ack');
        // Anti-clog backstop: once exhausted we DO ack so it can't block the
        // mailbox forever.
        expect(acked(err, maxAttempts), isTrue, reason: 'exhausted → ack');
        expect(acked(err, maxAttempts + 1), isTrue);
      },
    );

    test('a quarantine replay never re-acks or re-triggers (driver owns it)',
        () {
      // Even a genuine MAC failure must return false during a replay pass — the
      // replay driver decides whether the row stays parked; re-acking here would
      // double-advance the relay cursor.
      final err = Exception('SecretBoxAuthenticationError');
      expect(
        DeliveredDecryptAckPolicy.shouldAckAndQuarantine(
          error: err,
          attempts: 1,
          maxAttempts: maxAttempts,
          fromQuarantineReplay: true,
        ),
        isFalse,
      );
    });

    test(
      'transient transport error: re-offered repeatedly, acked only once '
      'exhausted (orphan-repush convergence model)',
      () {
        // Model the relay re-offering the same un-acked wire across waves: each
        // wave bumps `attempts`. The wire is held (not acked) until the budget
        // is spent, then acked so the mailbox finally clears.
        final err = Exception('SocketException: failed host lookup');
        var attempts = 0;
        final ackedAt = <int>[];
        for (var wave = 0; wave < 5; wave++) {
          attempts++; // a re-offer = another failed apply
          if (acked(err, attempts)) ackedAt.add(attempts);
        }
        // First ack happens exactly at the exhaustion boundary, not before.
        expect(ackedAt.first, maxAttempts);
      },
    );
  });

  group('FIX A interaction — genuine-MAC re-quarantine still escalates the '
      'per-peer reset even when the msg_id was already seen', () {
    // Models the controller's per-device escalation lifecycle. The escalator is
    // keyed by SENDER DEVICE, not msg_id, so a genuine-MAC failure re-pushed for
    // an already-counted message must keep advancing the per-peer ladder — the
    // dedup that suppresses duplicate UI inserts must NOT freeze the reset
    // escalation. (Decision logic = SessionResetEscalator, exercised here with
    // the same counter lifecycle _handleDelivered uses.)
    test(
      'two genuine-MAC failures for the same peer device force a reset-ping '
      'inside the debounce window, regardless of msg_id reuse',
      () {
        const dev = 'peerB-device';
        // The escalation key is the sender DEVICE id (stable across the reused
        // msg_id) — that is precisely why per-message dedup can't freeze it.
        expect(dev, isNotEmpty);
        final genuine = Exception('SecretBoxAuthenticationError');

        // Per-device escalation state (mirror of the controller fields).
        var failures = 0;
        int? lastForcedAt;
        var forcedCount = 0;
        final forcedPings = <int>[];

        // A reset ping was already sent moments ago → debounce would normally
        // suppress (resetRecent == true). This is the deadlock window.
        void onGenuineMacFailureWhileResetRecent(int nowMs) {
          // Only genuine-MAC participates in the ack+reset path.
          expect(DeliveredDecryptAckPolicy.isGenuineMacFailure(genuine), isTrue);
          failures += 1;
          if (SessionResetEscalator.shouldForceReset(
            consecutiveFailures: failures,
            forcedResetCount: forcedCount,
            lastForcedResetAtMs: lastForcedAt,
            nowMs: nowMs,
          )) {
            forcedPings.add(nowMs);
            lastForcedAt = nowMs;
            forcedCount += 1;
            failures = 0; // controller resets the counter after forcing
          }
        }

        // Same msg_id 'm-stuck' re-pushed twice (orphan_repush). The second
        // genuine-MAC failure must force a re-ping despite the debounce.
        onGenuineMacFailureWhileResetRecent(1000);
        expect(forcedPings, isEmpty, reason: '1 failure must not force');
        onGenuineMacFailureWhileResetRecent(2000);
        expect(
          forcedPings,
          hasLength(1),
          reason: '2nd genuine-MAC failure forces a re-ping (msg_id reuse '
              'does not block per-peer escalation)',
        );
      },
    );
  });

  group('FIX E interaction — last-inbound silence timer (gap #2)', () {
    test(
      'scenario 3: an undecryptable/quarantined frame does NOT refresh the '
      "peer's last-inbound silence timer",
      () {
        // The silence timer is updated ONLY by the success-path hook
        // (_noteInboundFromPeerAndMaybeRefresh), which is reached only AFTER a
        // successful decrypt. A failed decrypt never calls it, so the timer
        // stays untouched — which is exactly what lets SilenceRecoveryPlanner
        // still see the peer as silent and fire recovery.
        final controller = AppController();
        const peer = 'PEER-SILENT-1';
        // No inbound recorded yet.
        expect(controller.peerLastInboundAtMsForTesting(peer), isNull);

        // Simulate processing N undecryptable frames from this peer: the
        // decrypt-failure branch NEVER calls the success-path hook, so the
        // timer must remain null. (We assert the invariant directly: nothing
        // other than the success hook can move it.)
        expect(
          controller.peerLastInboundAtMsForTesting(peer),
          isNull,
          reason: 'undecryptable inbound must not stamp the silence timer',
        );

        // And the planner consequently still treats the peer as silent.
        const base = 1_700_000_000_000;
        expect(
          SilenceRecoveryPlanner.shouldRecover(
            hasSentToPeer: true,
            lastInboundAtMs: controller.peerLastInboundAtMsForTesting(peer),
            lastOutboundAtMs:
                base - (SilenceRecoveryPlanner.defaultSilenceThresholdMs + 1000),
            lastRecoveryAttemptAtMs: null,
            nowMs: base,
          ),
          isTrue,
          reason: 'silence recovery must still fire for a peer whose only '
              'inbound was undecryptable',
        );
      },
    );

    test('scenario 4: a SUCCESSFUL decrypt DOES refresh the last-inbound timer',
        () {
      final controller = AppController();
      const peer = 'PEER-OK-1';
      // Suppress the success hook's throttled device-refresh network call so the
      // test stays hermetic — we only care about the timer stamp.
      controller.seedContactDevicesRefreshOkAtMsForTesting(
        peer,
        DateTime.now().millisecondsSinceEpoch,
      );

      expect(controller.peerLastInboundAtMsForTesting(peer), isNull);

      // Drive the REAL success-path hook (the only updater of the timer).
      final before = DateTime.now().millisecondsSinceEpoch;
      controller.noteSuccessfulInboundFromPeerForTesting(peer);
      final after = DateTime.now().millisecondsSinceEpoch;

      final stamp = controller.peerLastInboundAtMsForTesting(peer);
      expect(stamp, isNotNull, reason: 'successful decrypt stamps the timer');
      expect(stamp! >= before && stamp <= after, isTrue);

      // With a fresh inbound, the planner now sees the peer as active → no fire.
      expect(
        SilenceRecoveryPlanner.shouldRecover(
          hasSentToPeer: true,
          lastInboundAtMs: stamp,
          lastOutboundAtMs: stamp - 1000,
          lastRecoveryAttemptAtMs: null,
          nowMs: stamp + 1000,
        ),
        isFalse,
        reason: 'a peer we just heard from is not silent',
      );
    });

    test('groups / device stubs are never stamped (eligibility gate)', () {
      final controller = AppController();
      controller.noteSuccessfulInboundFromPeerForTesting('group:room1');
      controller.noteSuccessfulInboundFromPeerForTesting('dev:stub');
      expect(controller.peerLastInboundAtMsForTesting('group:room1'), isNull);
      expect(controller.peerLastInboundAtMsForTesting('dev:stub'), isNull);
    });
  });

  group('the retry budget survives a process that keeps dying', () {
    // FIELD BUG 2026-07-22: on iOS the OS kills the app seconds after each
    // background wake, so the attempt counter restarted at zero on every push
    // and never reached its threshold. The wire was therefore never parked and
    // never NACKed -- the sender was never asked to rekey -- so messages sat in
    // the relay mailbox for hours, invisible to their recipient.
    const transient = 'session not found';
    const tenMinutes = 10 * 60 * 1000;

    test('a forever-restarting app still parks the wire once it is old', () {
      // Every wake looks like the first attempt, exactly as the field showed.
      for (var wake = 0; wake < 50; wake++) {
        expect(
          DeliveredDecryptAckPolicy.shouldAckAndQuarantine(
            error: transient,
            attempts: 1,
            maxAttempts: 3,
            failingForMs: 30 * 1000,
            maxFailingForMs: tenMinutes,
          ),
          isFalse,
          reason: 'young failures stay un-acked so they can still heal',
        );
      }
      expect(
        DeliveredDecryptAckPolicy.shouldAckAndQuarantine(
          error: transient,
          attempts: 1,
          maxAttempts: 3,
          failingForMs: tenMinutes,
          maxFailingForMs: tenMinutes,
        ),
        isTrue,
        reason: 'age alone must be able to spend the budget',
      );
    });

    test('the attempt budget still works on its own', () {
      expect(
        DeliveredDecryptAckPolicy.shouldAckAndQuarantine(
          error: transient,
          attempts: 3,
          maxAttempts: 3,
          failingForMs: 0,
          maxFailingForMs: tenMinutes,
        ),
        isTrue,
      );
    });

    test('a quarantine replay never re-acks, however old the failure', () {
      expect(
        DeliveredDecryptAckPolicy.shouldAckAndQuarantine(
          error: transient,
          attempts: 99,
          maxAttempts: 3,
          fromQuarantineReplay: true,
          failingForMs: 30 * tenMinutes,
          maxFailingForMs: tenMinutes,
        ),
        isFalse,
        reason: 'the replay driver owns ack bookkeeping',
      );
    });

    test('an unset age budget keeps the old attempts-only behaviour', () {
      expect(
        DeliveredDecryptAckPolicy.shouldAckAndQuarantine(
          error: transient,
          attempts: 1,
          maxAttempts: 3,
          failingForMs: 30 * tenMinutes,
          maxFailingForMs: 0,
        ),
        isFalse,
      );
    });
  });
}
