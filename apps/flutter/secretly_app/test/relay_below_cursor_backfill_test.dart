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

  // Regression for the "after I close the app, messages from a peer never
  // arrive again" bug. When the cursor advances past an un-acked message, the
  // relay re-offers it BELOW the cursor. The HTTP pumpInbox path used to ACK +
  // DROP such items without decrypting them, losing the message (and that
  // inbound direction) permanently. It must now PROCESS them via onDelivered.
  test('pumpInbox processes below-cursor stranded messages (not ack+drop)',
      () async {
    final db = await AppDb.openForTesting();
    final kp = await Ed25519().newKeyPair();
    final delivered = <String>[];

    final client = MockClient((req) async {
      final path = req.url.path;
      if (req.method == 'GET' && path.contains('/v1/pending')) {
        // seq 3 is BELOW the client cursor (5) — a stranded re-offer.
        return http.Response(
          jsonEncode({
            'items': [
              {'seq': 3, 'msg_id': 'm3', 'ciphertext_b64': 'AA=='},
            ],
          }),
          200,
        );
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
      onDelivered: ({required msgId, required ciphertextB64}) async {
        delivered.add(msgId);
        return true;
      },
      loadNextSeq: () async => 5, // cursor AHEAD of the stranded seq=3
      saveNextSeq: (_) async {},
      webSocketConnector: (uri, {pingInterval, connectTimeout}) =>
          throw StateError('no websocket in this test'),
    );

    try {
      await relay.connect(); // seeds _nextSeq=5; the WS attempt throws (caught)
    } catch (_) {
      // ignore — we only needed the cursor seeded
    }

    await relay.pumpInbox(force: true);

    expect(
      delivered,
      contains('m3'),
      reason: 'below-cursor stranded message was dropped instead of processed',
    );
  });

  // LOSS-SAFETY regression (2026-06-29): the "1-2 messages lost after long
  // sleep" bug. A below-cursor re-offer that FAILS to apply (onDelivered
  // returns false — e.g. the ratchet isn't restored yet on a cold overnight
  // wake) must NOT be acked-and-dropped (relay ack = permanent DELETE). It must
  // be parked in quarantine so the replay sweep re-applies it once the ratchet
  // is ready.
  test('below-cursor apply failure is quarantined, not ack+dropped', () async {
    final db = await AppDb.openForTesting();
    final kp = await Ed25519().newKeyPair();

    // Unique msg_id so the shared in-memory test DB (openForTesting reuses one
    // path across the file) can't have it already marked seen by another test.
    final client = MockClient((req) async {
      if (req.method == 'GET' && req.url.path.contains('/v1/pending')) {
        return http.Response(
          jsonEncode({
            'items': [
              {'seq': 3, 'msg_id': 'mfail', 'ciphertext_b64': 'AA=='},
            ],
          }),
          200,
        );
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
      // Simulate a cold-wake apply failure (ratchet not ready yet).
      onDelivered: ({required msgId, required ciphertextB64}) async => false,
      loadNextSeq: () async => 5, // cursor AHEAD of the stranded seq=3
      saveNextSeq: (_) async {},
      webSocketConnector: (uri, {pingInterval, connectTimeout}) =>
          throw StateError('no websocket in this test'),
    );

    try {
      await relay.connect();
    } catch (_) {}

    final before = await db.inboxQuarantineCountAll();
    await relay.pumpInbox(force: true);

    expect(
      await db.inboxQuarantineCountAll(),
      before + 1,
      reason: 'a below-cursor message that could not be applied must be '
          'quarantined (recoverable), never silently ack+dropped',
    );
  });
}
