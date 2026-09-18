// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Tests for the PROACTIVE, silence-driven delivery recovery (FIX E).
//
// FIX E sits UPSTREAM of the reactive quarantine recovery (FIX A/D). The
// reactive heal only arms when a wire reaches MY mailbox and fails to decrypt.
// But the most damaging break is that the SENDER keeps fanning out to a
// STALE/dead `device_id` for a peer (keys server never prunes device rows; the
// local `contact_devices` cache has no delivery-failure TTL), so the wire lands
// in a mailbox the peer never reads — nothing arrives, nothing quarantines, and
// the reactive recovery can NEVER arm. `SilenceRecoveryPlanner.shouldRecover`
// decides, per 1:1 peer, whether to fire a forced device-refresh + reset-ping
// based purely on timestamps — INDEPENDENT of quarantine state.
//
// A full AppController integration test is infeasible (keys/relay/db IO), so per
// the task we unit-test the pure decision logic in isolation, plus the new DB
// query (`latestOwnEventAtMsForConvo`) that feeds the "have we sent?" signal,
// against the real in-memory database.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/storage/app_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const silence = SilenceRecoveryPlanner.defaultSilenceThresholdMs; // 6 min
  const throttle = SilenceRecoveryPlanner.defaultRecoveryThrottleMs; // 3 min
  const base = 1_700_000_000_000; // realistic wall-clock ms

  group('SilenceRecoveryPlanner.shouldRecover (FIX E decision)', () {
    test(
      'scenario 1: peer silent for > N after we sent → FIRE (forced refresh + '
      'reset-ping)',
      () {
        // We sent 7 min ago and have NEVER heard back. Past the 6 min silence
        // threshold → recovery must fire. This is the canonical "sender glued
        // to a dead device_id, peer never receives" symptom.
        expect(
          SilenceRecoveryPlanner.shouldRecover(
            hasSentToPeer: true,
            lastInboundAtMs: null, // never received from this peer
            lastOutboundAtMs: base - (silence + 60 * 1000),
            lastRecoveryAttemptAtMs: null,
            nowMs: base,
          ),
          isTrue,
        );
      },
    );

    test(
      'reset-ping-war gate: a firing case is SUPPRESSED when our own relay is '
      'unreachable (the silence is our outage, not the peer)',
      () {
        // Default (reachable) → fires.
        expect(
          SilenceRecoveryPlanner.shouldRecover(
            hasSentToPeer: true,
            lastInboundAtMs: null,
            lastOutboundAtMs: base - (silence + 60 * 1000),
            lastRecoveryAttemptAtMs: null,
            nowMs: base,
          ),
          isTrue,
        );
        // Our relay link is down → suppressed (no reset-ping fired at the peer,
        // which is what fed the bilateral reset-ping war).
        expect(
          SilenceRecoveryPlanner.shouldRecover(
            hasSentToPeer: true,
            lastInboundAtMs: null,
            lastOutboundAtMs: base - (silence + 60 * 1000),
            lastRecoveryAttemptAtMs: null,
            nowMs: base,
            selfRelayReachable: false,
          ),
          isFalse,
        );
      },
    );

    test(
      'scenario 1b: asymmetric silence — old inbound exists but our newer send '
      'went quiet past the threshold → FIRE',
      () {
        // We DID hear from them once (10 min ago), then sent (8 min ago) and
        // heard nothing since. Inbound is older than our send AND older than the
        // silence window → a device rotated mid-conversation; fire recovery.
        expect(
          SilenceRecoveryPlanner.shouldRecover(
            hasSentToPeer: true,
            lastInboundAtMs: base - 10 * 60 * 1000,
            lastOutboundAtMs: base - 8 * 60 * 1000,
            lastRecoveryAttemptAtMs: null,
            nowMs: base,
          ),
          isTrue,
        );
      },
    );

    test('scenario 2: received from peer recently → NO fire', () {
      // Heard from them 1 min ago (well within the 6 min window). Healthy link;
      // even though we also sent recently, there is nothing to recover.
      expect(
        SilenceRecoveryPlanner.shouldRecover(
          hasSentToPeer: true,
          lastInboundAtMs: base - 60 * 1000,
          lastOutboundAtMs: base - 30 * 1000,
          lastRecoveryAttemptAtMs: null,
          nowMs: base,
        ),
        isFalse,
      );
    });

    test(
      'scenario 2b: inbound is NEWER than our last send → NO fire even if old',
      () {
        // Both timestamps are old (quiet chat), but the most recent event we
        // have from them is newer than our last send — i.e. they replied last.
        // Not a delivery break; just an idle conversation. Must not fire.
        expect(
          SilenceRecoveryPlanner.shouldRecover(
            hasSentToPeer: true,
            lastOutboundAtMs: base - 60 * 60 * 1000, // sent 1 h ago
            lastInboundAtMs: base - 30 * 60 * 1000, // they replied 30 min ago
            lastRecoveryAttemptAtMs: null,
            nowMs: base,
          ),
          isFalse,
        );
      },
    );

    test('scenario 3: per-peer throttle blocks a 2nd attempt within the window',
        () {
      // Same silent-peer inputs as scenario 1, but we already attempted recovery
      // 2 min ago (< 3 min throttle). The throttle must suppress the 2nd attempt
      // so a permanently one-way-broken peer can't spam the keys server.
      const args = {
        'hasSentToPeer': true,
        'lastInboundAtMs': null,
        'lastOutboundAtMs': base - (silence + 60 * 1000),
        'nowMs': base,
      };
      // Within the throttle window → suppressed.
      expect(
        SilenceRecoveryPlanner.shouldRecover(
          hasSentToPeer: args['hasSentToPeer'] as bool,
          lastInboundAtMs: args['lastInboundAtMs'] as int?,
          lastOutboundAtMs: args['lastOutboundAtMs'] as int?,
          lastRecoveryAttemptAtMs: base - 2 * 60 * 1000, // 2 min ago
          nowMs: args['nowMs'] as int,
        ),
        isFalse,
      );
      // Exactly at the throttle boundary (3 min) → allowed again.
      expect(
        SilenceRecoveryPlanner.shouldRecover(
          hasSentToPeer: args['hasSentToPeer'] as bool,
          lastInboundAtMs: args['lastInboundAtMs'] as int?,
          lastOutboundAtMs: args['lastOutboundAtMs'] as int?,
          lastRecoveryAttemptAtMs: base - throttle,
          nowMs: args['nowMs'] as int,
        ),
        isTrue,
      );
    });

    test('scenario 4: decision is INDEPENDENT of quarantine state', () {
      // The planner takes no quarantine input at all — by construction the
      // decision cannot depend on it. We assert the SAME silent-peer inputs fire
      // regardless of any external quarantine condition the caller might have.
      // (Loop over both "empty" and "non-empty" quarantine worlds; the planner
      // has no parameter for it, so both must yield identical results.)
      for (final quarantineNonEmpty in <bool>[false, true]) {
        expect(
          SilenceRecoveryPlanner.shouldRecover(
            hasSentToPeer: true,
            lastInboundAtMs: null,
            lastOutboundAtMs: base - (silence + 1000),
            lastRecoveryAttemptAtMs: null,
            nowMs: base,
          ),
          isTrue,
          reason: 'quarantineNonEmpty=$quarantineNonEmpty must not change it',
        );
      }
    });

    test('never fires for a peer we have NOT sent to', () {
      // A brand-new peer (no outbound) is not "broken", just new. Even with no
      // inbound ever and a huge clock, recovery must not fire.
      expect(
        SilenceRecoveryPlanner.shouldRecover(
          hasSentToPeer: false,
          lastInboundAtMs: null,
          lastOutboundAtMs: null,
          lastRecoveryAttemptAtMs: null,
          nowMs: base,
        ),
        isFalse,
      );
    });

    test('we sent but it is too recent to call silence yet → NO fire', () {
      // Sent 2 min ago, no reply yet. Under the 6 min threshold — give the peer
      // time to respond before forcing a refresh.
      expect(
        SilenceRecoveryPlanner.shouldRecover(
          hasSentToPeer: true,
          lastInboundAtMs: null,
          lastOutboundAtMs: base - 2 * 60 * 1000,
          lastRecoveryAttemptAtMs: null,
          nowMs: base,
        ),
        isFalse,
      );
    });

    test(
      'have-sent but send time unknown (e.g. only a stuck-outbox signal) → '
      'eligible; throttle still bounds the rate',
      () {
        // hasSentToPeer is true but we cannot date the send and never received.
        // Treat as eligible (the upstream stuck-outbox already proves a problem)
        // — but the throttle must still gate repeats.
        expect(
          SilenceRecoveryPlanner.shouldRecover(
            hasSentToPeer: true,
            lastInboundAtMs: null,
            lastOutboundAtMs: null,
            lastRecoveryAttemptAtMs: null,
            nowMs: base,
          ),
          isTrue,
        );
        expect(
          SilenceRecoveryPlanner.shouldRecover(
            hasSentToPeer: true,
            lastInboundAtMs: null,
            lastOutboundAtMs: null,
            lastRecoveryAttemptAtMs: base - 1000, // just attempted
            nowMs: base,
          ),
          isFalse,
        );
      },
    );

    test('custom thresholds are honoured (override knobs)', () {
      // With a 1-min silence threshold and 10-min throttle, a 90-s-old send with
      // no reply fires, and a 5-min-old attempt is still throttled.
      expect(
        SilenceRecoveryPlanner.shouldRecover(
          hasSentToPeer: true,
          lastInboundAtMs: null,
          lastOutboundAtMs: base - 90 * 1000,
          lastRecoveryAttemptAtMs: null,
          nowMs: base,
          silenceThresholdMs: 60 * 1000,
          throttleMs: 10 * 60 * 1000,
        ),
        isTrue,
      );
      expect(
        SilenceRecoveryPlanner.shouldRecover(
          hasSentToPeer: true,
          lastInboundAtMs: null,
          lastOutboundAtMs: base - 90 * 1000,
          lastRecoveryAttemptAtMs: base - 5 * 60 * 1000,
          nowMs: base,
          silenceThresholdMs: 60 * 1000,
          throttleMs: 10 * 60 * 1000,
        ),
        isFalse,
      );
    });
  });

  group('SilenceRecoveryPlanner.isEligibleConvoId (scenario 5: groups never)',
      () {
    test('groups (group:) are NEVER eligible for the silence sweep', () {
      expect(SilenceRecoveryPlanner.isEligibleConvoId('group:abc'), isFalse);
    });

    test('transient device stubs (dev:) are NEVER eligible', () {
      expect(SilenceRecoveryPlanner.isEligibleConvoId('dev:xyz'), isFalse);
    });

    test('empty / whitespace ids are not eligible', () {
      expect(SilenceRecoveryPlanner.isEligibleConvoId(''), isFalse);
      expect(SilenceRecoveryPlanner.isEligibleConvoId('   '), isFalse);
    });

    test('a real 1:1 peer profile id IS eligible', () {
      expect(
        SilenceRecoveryPlanner.isEligibleConvoId('PEER-1234-5678'),
        isTrue,
      );
    });

    test(
      'scenario 5 end-to-end: a sweep that filters via isEligibleConvoId never '
      'selects a silent group, only the silent 1:1 peer',
      () {
        // Model the sweep selection loop: walk a mixed convo list, apply the
        // eligibility gate, then the silence decision. Both the group and the
        // 1:1 are equally "silent", but only the 1:1 may be selected.
        final convoIds = <String>['group:room1', 'dev:devstub', 'PEER-9999'];
        final selected = <String>[];
        for (final id in convoIds) {
          if (!SilenceRecoveryPlanner.isEligibleConvoId(id)) continue;
          final fire = SilenceRecoveryPlanner.shouldRecover(
            hasSentToPeer: true,
            lastInboundAtMs: null,
            lastOutboundAtMs: base - (silence + 1000),
            lastRecoveryAttemptAtMs: null,
            nowMs: base,
          );
          if (fire) selected.add(id);
        }
        expect(selected, equals(<String>['PEER-9999']));
      },
    );
  });

  group('AppDb.latestOwnEventAtMsForConvo (FIX E "have we sent?" signal)', () {
    test('returns the latest OWN outbound time, ignoring inbound events',
        () async {
      final db = await AppDb.openForTesting();
      try {
        const peer = 'PEER-A';
        const selfDid = 'self-device';
        const peerDid = 'peer-device';
        await db.convoEnsure1to1(peerProfileId: peer);

        // Our outbound at 1000 and 3000; an inbound from the peer at 5000.
        await db.insertEvent(
          eventId: 'local:o1',
          convoId: peer,
          type: 'msg',
          senderDeviceId: selfDid,
          ciphertextB64: 'AA==',
          createdAtMs: 1000,
          localState: 'sent',
        );
        await db.insertEvent(
          eventId: 'local:o2',
          convoId: peer,
          type: 'msg',
          senderDeviceId: selfDid,
          ciphertextB64: 'BB==',
          createdAtMs: 3000,
          localState: 'sent',
        );
        await db.insertEvent(
          eventId: 'in:i1',
          convoId: peer,
          type: 'msg',
          senderDeviceId: peerDid,
          ciphertextB64: 'CC==',
          createdAtMs: 5000,
          localState: 'received',
        );

        // Latest OWN event is 3000 — the inbound at 5000 must be ignored.
        expect(
          await db.latestOwnEventAtMsForConvo(
            convoId: peer,
            senderDeviceId: selfDid,
          ),
          3000,
        );
      } finally {
        await db.close();
      }
    });

    test('returns null when we have never sent into the conversation',
        () async {
      final db = await AppDb.openForTesting();
      try {
        const peer = 'PEER-B';
        const selfDid = 'self-device';
        const peerDid = 'peer-device';
        await db.convoEnsure1to1(peerProfileId: peer);
        // Only an inbound event exists — we have not sent anything.
        await db.insertEvent(
          eventId: 'in:i1',
          convoId: peer,
          type: 'msg',
          senderDeviceId: peerDid,
          ciphertextB64: 'CC==',
          createdAtMs: 5000,
          localState: 'received',
        );
        expect(
          await db.latestOwnEventAtMsForConvo(
            convoId: peer,
            senderDeviceId: selfDid,
          ),
          isNull,
        );
      } finally {
        await db.close();
      }
    });

    test('empty convo / device args yield null (defensive)', () async {
      final db = await AppDb.openForTesting();
      try {
        expect(
          await db.latestOwnEventAtMsForConvo(convoId: '', senderDeviceId: 'd'),
          isNull,
        );
        expect(
          await db.latestOwnEventAtMsForConvo(convoId: 'c', senderDeviceId: ''),
          isNull,
        );
      } finally {
        await db.close();
      }
    });
  });
}
