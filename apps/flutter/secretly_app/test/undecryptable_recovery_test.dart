// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

// 2026-07-23 (TZ_UNDECRYPTABLE_RECOVERY): a message that fails to decrypt
// (secretbox auth = ratchet desync) is quarantined + ACKed and never recovered
// — the NACK is throttled and the blanket resend only covers local_state='sent'.
// The fix resends the SPECIFIC NACKed wire by mapping its relay msg_id back to
// the outbound event, and dedups a re-sent copy by payload_event_id so recovery
// never duplicates a message that did arrive. These pin the two primitives.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Part 1: outboxEventRefByMsgId (relay msg_id -> outbound event)', () {
    test('maps a retained outbox row back to its event + payload', () async {
      final db = await AppDb.openForTesting();
      await db.outboxUpsert(
        msgId: 'relay-M1',
        toDeviceId: 'peer-dev',
        ciphertextB64: 'x',
        ttlSeconds: 3600,
        state: 'pending',
        attemptCount: 0,
        nextRetryAtMs: 0,
        createdAtMs: 1000,
        payloadEventId: 'pe-42',
        eventIdRef: 'local-evt-42',
        convoId: 'peerA',
      );
      // The row survives being marked sent (that is why a NACKed-after-delivery
      // wire is still resendable).
      await db.outboxMarkSent('relay-M1');

      final ref = await db.outboxEventRefByMsgId('relay-M1');
      expect(ref, isNotNull);
      expect(ref!['event_id_ref'], 'local-evt-42');
      expect(ref['payload_event_id'], 'pe-42');
      await db.close();
    });

    test('returns null for a msg_id we never held', () async {
      final db = await AppDb.openForTesting();
      expect(await db.outboxEventRefByMsgId('unknown'), isNull);
      expect(await db.outboxEventRefByMsgId('   '), isNull);
      await db.close();
    });
  });

  group('Part 2: payload_event_id dedup primitive', () {
    test('convoIdForPayloadEventId finds an applied payload, in its convo only',
        () async {
      final db = await AppDb.openForTesting();
      // Not applied yet -> a fresh copy would NOT be deduped (recovery case).
      expect(await db.convoIdForPayloadEventId('pe-99'), isNull);

      // Apply an inbound message (relay msg_id M1) carrying payload pe-99.
      await db.insertEvent(
        eventId: 'relay-M1',
        convoId: 'peerA',
        type: 'msg',
        senderDeviceId: 'peer-dev',
        ciphertextB64: 'x',
        createdAtMs: 1000,
        payloadEventId: 'pe-99',
      );

      // Now a re-sent copy (new relay msg_id, SAME payload) resolves to peerA,
      // so the apply guard dedups it instead of appending a second bubble.
      expect(await db.convoIdForPayloadEventId('pe-99'), 'peerA');
      // A different payload is unaffected.
      expect(await db.convoIdForPayloadEventId('pe-other'), isNull);
      await db.close();
    });
  });
}
