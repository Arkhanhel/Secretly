// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/auth_signer.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/storage/app_db.dart';

// SCHEDULED RE-KEY REFRESH (2026-07-19): a "send later" wire is encrypted at
// schedule time but released at T; a session rotation in between leaves a
// ciphertext the recipient can never decrypt (proven live — two wires
// encrypted 12 s apart, one released before a rotation decrypted, one after it
// did not). The sweep re-encrypts held wires whose outbox row predates the
// current session epoch. These tests pin its DB building blocks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Must match Rust `http_cancel_scheduled_auth_message` byte-for-byte or the
  // relay rejects the retraction and every rotation double-fires the message.
  test('cancel-scheduled auth message mirrors the Rust canonical form', () {
    expect(
      utf8.decode(
        AuthSigner.relayHttpCancelScheduledMessage(
          deviceId: 'devA',
          toDeviceId: 'devB',
          msgId: 'm-1',
          tsMs: 42,
          nonceB64: 'n0nce',
        ),
      ),
      'SECRETLY-RELAY-HTTP-CANCEL-SCHEDULED-V1\n'
      'device_id=devA\n'
      'to_device_id=devB\n'
      'msg_id=m-1\n'
      'ts_ms=42\n'
      'nonce_b64=n0nce\n',
    );
  });

  test('outboxHeldScheduledRows returns only ACCEPTED, still-held wires',
      () async {
    final db = await AppDb.openForTesting();
    try {
      const now = 1_000_000;
      Future<void> put({
        required String msgId,
        required int deliverAt,
        required String state,
      }) => db.outboxUpsert(
            msgId: msgId,
            toDeviceId: 'peer-dev',
            ciphertextB64: 'QUJD',
            ttlSeconds: 3600,
            state: state,
            attemptCount: 0,
            nextRetryAtMs: now,
            createdAtMs: now,
            convoId: 'PEER-PROFILE',
            eventIdRef: 'local:$msgId',
            deliverAtMs: deliverAt,
          );

      // Held on the relay, release in the future → the sweep's target.
      await put(msgId: 'held', deliverAt: now + 60_000, state: OutboxSendState.sent);
      // Not yet accepted by the relay → the ordinary pump still owns it.
      await put(msgId: 'unsent', deliverAt: now + 60_000, state: OutboxSendState.pending);
      // Already released → nothing to refresh (and cancel would refuse anyway).
      await put(msgId: 'released', deliverAt: now - 1, state: OutboxSendState.sent);
      // Ordinary non-scheduled message (deliver_at 0) → never touched.
      await put(msgId: 'plain', deliverAt: 0, state: OutboxSendState.sent);

      final rows = await db.outboxHeldScheduledRows(nowMs: now);
      expect(rows.map((r) => r['msg_id']), ['held']);
      expect((rows.single['deliver_at_ms'] as num).toInt(), now + 60_000);
      expect(rows.single['event_id_ref'], 'local:held');
    } finally {
      await db.close();
    }
  });

  test('sessionV3EpochFor reads the handshake stamp (0 when absent)', () async {
    final db = await AppDb.openForTesting();
    try {
      expect(await db.sessionV3EpochFor('nobody'), 0);
      // sessionV3SetEpoch is deliberately an UPDATE (no-op without a session
      // row) — in production the row always exists by the time the handshake
      // stamps it. Mirror that order here.
      await db.sessionV3Upsert(
        peerDeviceId: 'peer-dev',
        rootKeyB64: 'cg==',
        dhSelfSeedB64: 'cw==',
        dhSelfPubB64: 'cA==',
        dhRemotePubB64: null,
        sendChainKeyB64: null,
        recvChainKeyB64: null,
        ns: 0,
        nr: 0,
        pn: 0,
      );
      expect(await db.sessionV3EpochFor('peer-dev'), 0,
          reason: 'pre-epoch legacy session reads 0 → sweep skips it');
      // The stale test is `outbox.created_at_ms < epoch`: a wire encrypted
      // before the current handshake is dead, one encrypted after it is fine.
      await db.sessionV3SetEpoch('peer-dev', 5_000);
      expect(await db.sessionV3EpochFor('peer-dev'), 5_000);
    } finally {
      await db.close();
    }
  });

  test('outboxDeleteByMsgId removes exactly the superseded row', () async {
    final db = await AppDb.openForTesting();
    try {
      const now = 1_000_000;
      for (final id in const ['a', 'b']) {
        await db.outboxUpsert(
          msgId: id,
          toDeviceId: 'peer-dev',
          ciphertextB64: 'QUJD',
          ttlSeconds: 3600,
          state: OutboxSendState.sent,
          attemptCount: 0,
          nextRetryAtMs: now,
          createdAtMs: now,
          convoId: 'PEER-PROFILE',
          deliverAtMs: now + 60_000,
        );
      }
      await db.outboxDeleteByMsgId('a');
      final rows = await db.outboxHeldScheduledRows(nowMs: now);
      expect(rows.map((r) => r['msg_id']), ['b']);
    } finally {
      await db.close();
    }
  });
}
