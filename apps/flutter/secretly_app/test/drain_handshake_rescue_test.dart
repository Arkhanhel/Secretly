// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:secretly_app/ratchet/wire_v3.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/relay_client.dart';

/// 🔴 THE ANTIDOTE IS BEHIND THE POISON (2026-08-01, ПК-3 of
/// docs/TZ_DELIVERY_SIGNAL_MODEL_2026-08-01.md).
///
/// Proven on production: one receiver held 111 undecryptable wires from a
/// single sender AND — further down the very same mailbox — four session-heal
/// handshakes that would have fixed it. The drain is strictly seq-ordered, so
/// the cure was only reachable by first exhausting the poison: six consecutive
/// failures per wire, with the counter held in MEMORY, so any reconnect reset
/// it. The mailbox never converged — it grew (109 -> 115 rows in 40 minutes).
///
/// The wire kind is one byte of the SKS2 frame, so a device whose session is
/// dead can still tell medicine from poison without decrypting anything. When
/// (and only when) the head has already failed, the drain now looks ahead for a
/// handshake from the SAME sender and applies it first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A real SKS2 frame — the rescue reads the kind byte and the sender out of
  /// this, so hand-rolled bytes would prove nothing.
  String sessionWire(String senderDeviceId) => base64Encode(
        RatchetWireV3.encodeSession(
          senderDeviceId: senderDeviceId,
          dhPubB64: base64Encode(Uint8List(32)),
          pn: 0,
          n: 0,
          ratchetCiphertext: Uint8List.fromList(const [1, 2, 3]),
        ),
      );

  String handshakeWire(String senderDeviceId) => base64Encode(
        RatchetWireV3.encodePrekey(
          header: <String, Object?>{
            'sender_device_id': senderDeviceId,
            'sender_eph_pub_b64': base64Encode(Uint8List(32)),
            'spk_id': 1,
            'dh_pub_b64': base64Encode(Uint8List(32)),
            'pn': 0,
            'n': 0,
          },
          ratchetCiphertext: Uint8List.fromList(const [4, 5, 6]),
        ),
      );

  Future<RelayClient> buildRelay({
    required AppDb db,
    required Future<bool> Function(String msgId, String ciphertextB64) apply,
    required List<String> acked,
  }) async {
    final kp = await Ed25519().newKeyPair();
    final client = MockClient((req) async {
      if (req.method == 'GET' && req.url.path.contains('/v1/pending')) {
        return http.Response(jsonEncode({'items': []}), 200);
      }
      if (req.url.path.contains('/v1/ack')) {
        try {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final id = body['msg_id'];
          if (id is String) acked.add(id);
        } catch (_) {}
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
      onDelivered: ({required msgId, required ciphertextB64}) =>
          apply(msgId, ciphertextB64),
      loadNextSeq: () async => 1,
      saveNextSeq: (_) async {},
      webSocketConnector: (uri, {pingInterval, connectTimeout}) =>
          throw StateError('no websocket in this test'),
    );
    try {
      await relay.connect();
    } catch (_) {}
    return relay;
  }

  test('🔴 a handshake BEHIND the stuck head heals the session', () async {
    final db = await AppDb.openForTesting();
    final order = <String>[];
    final acked = <String>[];
    var healed = false;

    final relay = await buildRelay(
      db: db,
      acked: acked,
      apply: (msgId, cipher) async {
        order.add(msgId);
        if (msgId == 'cure') {
          healed = true;
          return true;
        }
        // The poison: opens only once the session has been healed — exactly
        // what a wire encrypted under a re-established session does.
        return healed;
      },
    );

    // seq 1 = poison at the HEAD, seq 2 = the cure sitting behind it. Same
    // sender: this is one broken conversation, as in the field.
    relay.debugSeedReorderEntryForTest(
      seq: 1,
      msgId: 'poison',
      ciphertextB64: sessionWire('peer-A'),
    );
    relay.debugSeedReorderEntryForTest(
      seq: 2,
      msgId: 'cure',
      ciphertextB64: handshakeWire('peer-A'),
    );

    await relay.debugDrainForTest();

    expect(order.contains('cure'), isTrue,
        reason: 'the handshake behind the head was never reached — this is the '
            'field wedge: the mailbox can only grow');
    expect(order.indexOf('cure'), lessThan(order.lastIndexOf('poison')),
        reason: 'the cure must be applied BEFORE the head finally succeeds');
    expect(order.last, 'poison',
        reason: 'after healing, the head must be retried and land');
    expect(acked, contains('poison'), reason: 'the head must end up acked');

    await db.close();
  });

  test('🔴 a handshake from ANOTHER sender is NOT pulled forward', () async {
    // Applying an unrelated peer's handshake early cannot heal this session and
    // would reorder a conversation that is working fine.
    final db = await AppDb.openForTesting();
    final order = <String>[];
    final acked = <String>[];

    final relay = await buildRelay(
      db: db,
      acked: acked,
      apply: (msgId, cipher) async {
        order.add(msgId);
        return false; // nothing applies: the head stays stuck
      },
    );

    relay.debugSeedReorderEntryForTest(
      seq: 1,
      msgId: 'poison',
      ciphertextB64: sessionWire('peer-A'),
    );
    relay.debugSeedReorderEntryForTest(
      seq: 2,
      msgId: 'other-peer-handshake',
      ciphertextB64: handshakeWire('peer-B'),
    );

    await relay.debugDrainForTest();

    expect(order.contains('other-peer-handshake'), isFalse,
        reason: "another peer's handshake must never be pulled forward");
    await db.close();
  });

  test('the rescue is attempted ONCE, it cannot spin the drain', () async {
    // A handshake that will not apply must be remembered, or the retry loop
    // would keep re-electing it and the drain would never yield.
    final db = await AppDb.openForTesting();
    final applies = <String>[];
    final acked = <String>[];

    final relay = await buildRelay(
      db: db,
      acked: acked,
      apply: (msgId, cipher) async {
        applies.add(msgId);
        return false;
      },
    );

    relay.debugSeedReorderEntryForTest(
      seq: 1,
      msgId: 'poison',
      ciphertextB64: sessionWire('peer-A'),
    );
    relay.debugSeedReorderEntryForTest(
      seq: 2,
      msgId: 'cure',
      ciphertextB64: handshakeWire('peer-A'),
    );

    await relay.debugDrainForTest();

    expect(applies.where((m) => m == 'cure').length, 1,
        reason: 'a failing handshake must be tried once per drain, not looped');

    await db.close();
  });

  test('an ordinary healthy drain is untouched by the rescue', () async {
    // The rescue fires only after a failure. A mailbox where everything applies
    // must behave exactly as before, in strict seq order.
    final db = await AppDb.openForTesting();
    final order = <String>[];
    final acked = <String>[];

    final relay = await buildRelay(
      db: db,
      acked: acked,
      apply: (msgId, cipher) async {
        order.add(msgId);
        return true;
      },
    );

    relay.debugSeedReorderEntryForTest(
      seq: 1,
      msgId: 'first',
      ciphertextB64: sessionWire('peer-A'),
    );
    relay.debugSeedReorderEntryForTest(
      seq: 2,
      msgId: 'handshake',
      ciphertextB64: handshakeWire('peer-A'),
    );
    relay.debugSeedReorderEntryForTest(
      seq: 3,
      msgId: 'third',
      ciphertextB64: sessionWire('peer-A'),
    );

    await relay.debugDrainForTest();

    expect(order, <String>['first', 'handshake', 'third'],
        reason: 'a healthy drain must stay strictly ordered — pulling a '
            'handshake forward would strand wires under the old session');

    await db.close();
  });
}
