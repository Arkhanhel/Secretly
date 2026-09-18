// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quarantine upsert is idempotent on msg_id and keyed by sender', () async {
    final db = await AppDb.openForTesting();
    try {
      await db.inboxQuarantineUpsert(
        msgId: 'm1',
        senderDeviceId: 'devA',
        ciphertextB64: 'AA==',
        nowMs: 1000,
      );
      // Re-delivery of the same msg_id must NOT create a duplicate or reset it.
      await db.inboxQuarantineUpsert(
        msgId: 'm1',
        senderDeviceId: 'devA',
        ciphertextB64: 'BB==',
        nowMs: 2000,
      );
      await db.inboxQuarantineUpsert(
        msgId: 'm2',
        senderDeviceId: 'devA',
        ciphertextB64: 'CC==',
        nowMs: 1500,
      );
      await db.inboxQuarantineUpsert(
        msgId: 'm3',
        senderDeviceId: 'devB',
        ciphertextB64: 'DD==',
        nowMs: 1200,
      );

      expect(await db.inboxQuarantineCountForSender('devA'), 2);
      expect(await db.inboxQuarantineCountForSender('devB'), 1);
      expect(await db.inboxQuarantineCountAll(), 3);

      // Idempotency: original ciphertext + created_at retained.
      final rows = await db.inboxQuarantineListForSender('devA');
      final m1 = rows.firstWhere((r) => r['msg_id'] == 'm1');
      expect(m1['ciphertext_b64'], 'AA==');
      expect((m1['created_at_ms'] as num).toInt(), 1000);

      // Listed oldest-first by created_at.
      expect(
        rows.map((r) => r['msg_id']).toList(),
        orderedEquals(['m1', 'm2']),
      );
    } finally {
      await db.close();
    }
  });

  test('null/empty sender is parked but excluded from per-sender count', () async {
    final db = await AppDb.openForTesting();
    try {
      await db.inboxQuarantineUpsert(
        msgId: 'm-null',
        senderDeviceId: null,
        ciphertextB64: 'AA==',
        nowMs: 1000,
      );
      await db.inboxQuarantineUpsert(
        msgId: 'm-empty',
        senderDeviceId: '   ',
        ciphertextB64: 'BB==',
        nowMs: 1000,
      );
      expect(await db.inboxQuarantineCountAll(), 2);
      expect(await db.inboxQuarantineCountForSender('anything'), 0);
      // Still recoverable via the "replay all" listing.
      expect((await db.inboxQuarantineListAll()).length, 2);
    } finally {
      await db.close();
    }
  });

  test('delete and markAttempt behave correctly', () async {
    final db = await AppDb.openForTesting();
    try {
      await db.inboxQuarantineUpsert(
        msgId: 'm1',
        senderDeviceId: 'devA',
        ciphertextB64: 'AA==',
        nowMs: 1000,
      );
      await db.inboxQuarantineMarkAttempt(msgId: 'm1', nowMs: 5000);
      await db.inboxQuarantineMarkAttempt(msgId: 'm1', nowMs: 6000);
      final row = (await db.inboxQuarantineListForSender('devA')).single;
      expect((row['attempts'] as num).toInt(), 2);
      expect((row['last_attempt_at_ms'] as num).toInt(), 6000);

      await db.inboxQuarantineDelete('m1');
      expect(await db.inboxQuarantineCountForSender('devA'), 0);
    } finally {
      await db.close();
    }
  });

  test('prune drops aged-out rows and trims to capacity (newest kept)', () async {
    final db = await AppDb.openForTesting();
    try {
      const nowMs = 100000000;
      // Aged row (older than maxAge) must be pruned.
      await db.inboxQuarantineUpsert(
        msgId: 'old',
        senderDeviceId: 'devA',
        ciphertextB64: 'AA==',
        nowMs: nowMs - (40 * 24 * 60 * 60 * 1000),
      );
      // Fresh rows.
      await db.inboxQuarantineUpsert(
        msgId: 'fresh1',
        senderDeviceId: 'devA',
        ciphertextB64: 'BB==',
        nowMs: nowMs - 2000,
      );
      await db.inboxQuarantineUpsert(
        msgId: 'fresh2',
        senderDeviceId: 'devA',
        ciphertextB64: 'CC==',
        nowMs: nowMs - 1000,
      );

      final removedAged = await db.inboxQuarantinePrune(nowMs: nowMs);
      expect(removedAged, 1);
      expect(await db.inboxQuarantineCountAll(), 2);

      // Capacity trim keeps the newest rows.
      await db.inboxQuarantinePrune(nowMs: nowMs, maxRows: 1);
      final remaining = await db.inboxQuarantineListAll();
      expect(remaining.length, 1);
      expect(remaining.single['msg_id'], 'fresh2');
    } finally {
      await db.close();
    }
  });

  // PHANTOM-CHURN FIX (2026-06-25): a sender whose ONLY parked entries have
  // exhausted the proactive force-ping budget must drop out of the recovery
  // sweep's stuck-peer list, so the sweep stops re-handshaking a permanently
  // dead message every cycle (the per-minute "phantom notifications" loop). A
  // sender with at least one still-recoverable entry must still be returned.
  test('sweep stuck-peer list excludes senders whose entries exhausted '
      'the force-ping budget', () async {
    final db = await AppDb.openForTesting();
    try {
      // devDead: one permanently-dead parked msg, attempts driven past the cap.
      await db.inboxQuarantineUpsert(
        msgId: 'dead',
        senderDeviceId: 'devDead',
        ciphertextB64: 'AA==',
        nowMs: 1000,
      );
      for (var i = 0; i < kInboxQuarantineForcePingMaxAttempts; i++) {
        await db.inboxQuarantineMarkAttempt(msgId: 'dead', nowMs: 2000 + i);
      }
      // devMix: a dead entry AND a fresh recoverable one -> still stuck.
      await db.inboxQuarantineUpsert(
        msgId: 'mixDead',
        senderDeviceId: 'devMix',
        ciphertextB64: 'BB==',
        nowMs: 1000,
      );
      for (var i = 0; i < kInboxQuarantineForcePingMaxAttempts; i++) {
        await db.inboxQuarantineMarkAttempt(msgId: 'mixDead', nowMs: 2000 + i);
      }
      await db.inboxQuarantineUpsert(
        msgId: 'mixFresh',
        senderDeviceId: 'devMix',
        ciphertextB64: 'CC==',
        nowMs: 3000,
      );

      final senders = await db.inboxQuarantineSendersWithOldest();
      final ids = senders
          .map((r) => (r['sender_device_id'] as String?) ?? '')
          .toSet();
      expect(ids.contains('devDead'), isFalse,
          reason: 'fully-exhausted sender must not be force-pinged');
      expect(ids.contains('devMix'), isTrue,
          reason: 'sender with a recoverable entry is still healed');
    } finally {
      await db.close();
    }
  });

  test('prune drops rows that exhausted the replay budget', () async {
    final db = await AppDb.openForTesting();
    try {
      const nowMs = 100000000;
      await db.inboxQuarantineUpsert(
        msgId: 'doomed',
        senderDeviceId: 'devA',
        ciphertextB64: 'AA==',
        nowMs: nowMs - 1000,
      );
      await db.inboxQuarantineUpsert(
        msgId: 'live',
        senderDeviceId: 'devA',
        ciphertextB64: 'BB==',
        nowMs: nowMs - 1000,
      );
      for (var i = 0; i < kInboxQuarantineMaxReplayAttempts; i++) {
        await db.inboxQuarantineMarkAttempt(msgId: 'doomed', nowMs: nowMs);
      }

      final removed = await db.inboxQuarantinePrune(nowMs: nowMs);
      expect(removed, 1, reason: 'only the exhausted row is purged');
      final remaining = await db.inboxQuarantineListAll();
      expect(remaining.map((r) => r['msg_id']), ['live']);
    } finally {
      await db.close();
    }
  });

  // TZ Epic A reachability (2026-07-19): the NACK used to fire only at the
  // moment a wire was first quarantined, so an existing backlog could never
  // tell the sender anything. The replay sweep now NACKs a still-undecryptable
  // parked wire — but it runs periodically and across restarts, so the claim
  // MUST be persistent and single-winner or it becomes a NACK storm.
  group('inboxQuarantineClaimNack', () {
    test('claims exactly once per wire, however often the sweep runs', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.inboxQuarantineUpsert(
          msgId: 'stuck',
          senderDeviceId: 'devA',
          ciphertextB64: 'AA==',
          nowMs: 1000,
        );

        expect(await db.inboxQuarantineClaimNack(msgId: 'stuck', nowMs: 2000),
            isTrue, reason: 'first sweep wins the claim');
        for (var i = 0; i < 5; i++) {
          expect(
            await db.inboxQuarantineClaimNack(msgId: 'stuck', nowMs: 2000 + i),
            isFalse,
            reason: 'every later sweep must stay silent',
          );
        }
      } finally {
        await db.close();
      }
    });

    // NARROWED 2026-07-20 (TZ_INVARIANTS §И-5): the window used to be a DAY,
    // and together with the per-device gate that is why a stuck conversation
    // stayed stuck all day — a live capture caught 18 wires re-failing every
    // second with zero NACKs, every one already claimed. The window now matches
    // the gate that actually paces this path, so recovery is bounded in
    // minutes. Still long enough that a lost receipt cannot cause a storm.
    test('re-arms only after the re-NACK interval', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.inboxQuarantineUpsert(
          msgId: 'stuck',
          senderDeviceId: 'devA',
          ciphertextB64: 'AA==',
          nowMs: 1000,
        );
        const window = 10 * 60 * 1000;
        const t0 = 1784500000000;
        expect(
          await db.inboxQuarantineClaimNack(msgId: 'stuck', nowMs: t0),
          isTrue,
        );
        // Still inside the window — a lost NACK is not worth a storm.
        expect(
          await db.inboxQuarantineClaimNack(
            msgId: 'stuck',
            nowMs: t0 + window ~/ 2,
          ),
          isFalse,
        );
        // Past it: a wire STILL undecryptable earns another nudge. Without
        // this the backlog is unrecoverable, which is exactly what happened.
        expect(
          await db.inboxQuarantineClaimNack(
            msgId: 'stuck',
            nowMs: t0 + window,
          ),
          isTrue,
        );
      } finally {
        await db.close();
      }
    });

    // Observability (2026-07-19): "quarantined > 0 while nacked == 0" is the
    // exact silent stall this work fixed — the diagnostics screen has to be
    // able to show it without a USB syslog.
    test('delivery health counters reflect quarantine and NACK state', () async {
      final db = await AppDb.openForTesting();
      try {
        var counters = await db.deliveryHealthCounters();
        expect(counters['quarantined'], 0);
        expect(counters['nacked'], 0);

        await db.inboxQuarantineUpsert(
          msgId: 'm1',
          senderDeviceId: 'devA',
          ciphertextB64: 'AA==',
          nowMs: 1000,
        );
        await db.inboxQuarantineUpsert(
          msgId: 'm2',
          senderDeviceId: 'devA',
          ciphertextB64: 'BB==',
          nowMs: 1000,
        );
        counters = await db.deliveryHealthCounters();
        expect(counters['quarantined'], 2);
        expect(counters['nacked'], 0, reason: 'nothing reported to the sender yet');

        await db.inboxQuarantineClaimNack(msgId: 'm1', nowMs: 2000);
        counters = await db.deliveryHealthCounters();
        expect(counters['quarantined'], 2);
        expect(counters['nacked'], 1);
        // Present and non-negative even when those tables are empty.
        expect(counters['receipts_queued'], isNotNull);
        expect(counters['outbox_pending'], isNotNull);
      } finally {
        await db.close();
      }
    });

    test('an unknown msg_id claims nothing', () async {
      final db = await AppDb.openForTesting();
      try {
        expect(
          await db.inboxQuarantineClaimNack(msgId: 'ghost', nowMs: 5000),
          isFalse,
        );
      } finally {
        await db.close();
      }
    });
  });
}
