// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/relay_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pending_acks DAO: upsert (idempotent) / list / delete / count',
      () async {
    final db = await AppDb.openForTesting();
    try {
      await db.pendingAckUpsert(msgId: 'm1', seq: 3, nowMs: 1000);
      await db.pendingAckUpsert(msgId: 'm2', seq: 4, nowMs: 2000);
      await db.pendingAckUpsert(msgId: 'm1', seq: 3, nowMs: 3000); // idempotent
      expect(await db.pendingAckCount(), 2);
      final rows = await db.pendingAckList();
      expect(
        rows.map((r) => r['msg_id']).toList(),
        orderedEquals(['m1', 'm2']),
      );
      await db.pendingAckDelete('m1');
      expect(await db.pendingAckCount(), 1);
    } finally {
      await db.close();
    }
  });

  // When an ACK cannot reach the relay it must be PARKED in the durable queue
  // (so it is retried on the next connect and the relay cursor converges),
  // instead of being silently lost (which left messages stranded below-cursor
  // and re-offered forever).
  test('a failed ACK is parked in the durable queue for retry', () async {
    final db = await AppDb.openForTesting();
    final kp = await Ed25519().newKeyPair();

    final client = MockClient((req) async {
      final path = req.url.path;
      if (req.method == 'GET' && path.contains('/v1/pending')) {
        return http.Response(
          jsonEncode({
            'items': [
              {'seq': 3, 'msg_id': 'm3', 'ciphertext_b64': 'AA=='},
            ],
          }),
          200,
        );
      }
      if (req.method == 'POST' && path.contains('/v1/ack')) {
        return http.Response('relay down', 500); // ACK fails
      }
      return http.Response('{}', 200);
    });

    final relay = RelayClient(
      db: db,
      deviceId: 'self-device',
      selfProfileId: 'self-profile',
      deviceKeys: DeviceKeys.create(),
      wsUrl: Uri.parse('ws://example.test/ws'),
      httpBaseUrl: Uri.parse('https://example.test'),
      httpClient: client,
      identityKeyPairOverride: kp,
      onDelivered: ({required msgId, required ciphertextB64}) async => true,
      loadNextSeq: () async => 5, // cursor ahead so seq 3 is below-cursor
      saveNextSeq: (_) async {},
      webSocketConnector: (uri, {pingInterval, connectTimeout}) =>
          throw StateError('no websocket in this test'),
    );

    try {
      await relay.connect();
    } catch (_) {
      // ignore — no WS in this test
    }
    await relay.pumpInbox(force: true);

    // m3 was processed (below-cursor backfill); its ACK failed (HTTP 500) and
    // must now be parked durably.
    final acks = await db.pendingAckList();
    expect(acks.map((r) => r['msg_id']).toList(), contains('m3'));
  });
}
