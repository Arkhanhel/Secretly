// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ratchet/room_key_chain.dart';
import 'package:secretly_app/ratchet/room_key_manager.dart';
import 'package:secretly_app/ratchet/room_message_signature.dart';
import 'package:secretly_app/rooms/room_raw_wire.dart';
import 'package:secretly_app/security/auth_signer.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/attested_senders.dart';
import 'package:secretly_app/transport/keys_client.dart';
import 'package:secretly_app/transport/relay_client.dart';

// К-2 (17.09.2026): сообщение комнаты раздаёт реле одним запросом — только
// устройствам, заявившим `raw_v1`. Отправитель — со слов реле, подпись
// автора обязательна.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const room = 'group:raw';
  const author = 'author-dev';

  late Directory tmp;
  var seq = 0;
  Future<AppDb> freshDb() =>
      AppDb.openForTesting(path: '${tmp.path}/d${seq++}.db');

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('room_raw');
    seq = 0;
  });
  tearDown(() {
    AttestedSenders.clearForTesting();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('подписываемый текст рассылки совпадает с сервером побайтно', () {
    final msg = utf8.decode(
      AuthSigner.relayHttpRoomBroadcastMessage(
        fromDeviceId: 'dev-s',
        roomId: 'group:r',
        msgId: 'm-1',
        ciphertextB64: 'QUJD',
        recipients: const ['dev-b', 'dev-a'],
        ttlSeconds: 604800,
        deliverAtMs: 0,
        tsMs: 42,
        nonceB64: 'bm9uY2U=',
      ),
    );
    expect(
      msg,
      'SECRETLY-RELAY-ROOM-BROADCAST-V1\n'
      'from_device_id=dev-s\n'
      'room_id=group:r\n'
      'msg_id=m-1\n'
      'ciphertext_sha256_b64=2crg29vweLICDiq+X810vB7bqDw19riobWOO2bjT0fk=\n'
      'recipients_sha256_b64=8x4SK7ZypzL/R9bqWpL2Ise2VFWcxUwqPanRpcxjwgI=\n'
      'ttl_seconds=604800\n'
      'deliver_at_ms=0\n'
      'transport_meta_json=\n'
      'ts_ms=42\n'
      'nonce_b64=bm9uY2U=\n',
    );
  });

  test('клиент реле: один запрос, принятые устройства из ответа', () async {
    final db = await freshDb();
    addTearDown(db.close);
    http.Request? seen;
    final relay = RelayClient(
      db: db,
      deviceId: 'dev-s',
      selfProfileId: 'pid-s',
      deviceKeys: DeviceKeys.create(),
      wsUrl: Uri.parse('ws://relay.invalid/ws'),
      httpBaseUrl: Uri.parse('https://relay.invalid'),
      httpClient: MockClient((req) async {
        seen = req;
        return http.Response(
          jsonEncode({
            'ok': true,
            'accepted': ['dev-a'],
            'rejected': [
              {'device_id': 'dev-x', 'reason': 'not_member'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      identityKeyPairOverride: await Ed25519().newKeyPairFromSeed(
        List<int>.filled(32, 7),
      ),
      onDelivered: ({required msgId, required ciphertextB64}) async => true,
      loadNextSeq: () async => 1,
      saveNextSeq: (_) async {},
    );
    final accepted = await relay.broadcastRoomWire(
      roomId: room,
      msgId: '00000000-0000-0000-0000-00000000aa01',
      ciphertextB64: 'QUJD',
      recipients: const ['dev-a', 'dev-x'],
      ttlSeconds: 604800,
    );
    expect(accepted, {'dev-a'});
    expect(seen!.url.path, '/v1/rooms/group%3Araw/broadcast');
    final body = jsonDecode(seen!.body) as Map<String, dynamic>;
    expect(body['recipients'], ['dev-a', 'dev-x']);
    expect(body.containsKey('deliver_at_ms'), isFalse);
    expect(seen!.headers['x-secretly-device-id'], 'dev-s');
  });

  test('провод SKR1: только подписанный gmsg', () {
    RoomMessageEventV1 gmsg(Uint8List? sig) => RoomMessageEventV1(
      roomId: room,
      epoch: 1,
      counter: 0,
      nonce: Uint8List(24),
      ciphertext: Uint8List(20),
      signature: sig,
    );
    final signed = RoomRawWire.encode(gmsg(Uint8List(64)));
    expect(RoomRawWire.looksLike(signed), isTrue);
    expect(RoomRawWire.tryDecode(signed)!.counter, 0);
    expect(RoomRawWire.tryDecode(RoomRawWire.encode(gmsg(null))), isNull);
    expect(RoomRawWire.tryDecode(Uint8List.fromList(utf8.encode('SKS2xx'))),
        isNull);
  });

  test('подтверждение ключа несёт raw_v1; старое — без него', () {
    final ack = RoomKeyAckEventV1(roomId: room, epoch: 2, rawV1: true);
    expect(
      RoomKeyAckEventV1.fromJson(Map<String, dynamic>.from(ack.toJson())).rawV1,
      isTrue,
    );
    expect(
      RoomKeyAckEventV1.fromJson({'type': 'gkeyack', 'room_id': room, 'epoch': 2})
          .rawV1,
      isFalse,
    );
  });

  test('готовы к сырому проводу только подтвердившие ЭТО поколение с raw_v1',
      () async {
    final db = await freshDb();
    addTearDown(db.close);
    for (final d in const ['old-build', 'new-build', 'stale']) {
      await db.roomKeyDeliveryMark(
        roomId: room,
        peerDeviceId: d,
        epoch: 3,
        deliveredAtMs: 1,
      );
    }
    await db.roomKeyDeliveryConfirm(
      roomId: room, peerDeviceId: 'old-build', epoch: 3, confirmedAtMs: 1);
    await db.roomKeyDeliveryConfirm(
      roomId: room, peerDeviceId: 'new-build', epoch: 3, confirmedAtMs: 1);
    await db.roomKeyRawConfirm(roomId: room, peerDeviceId: 'new-build', epoch: 3);
    await db.roomKeyDeliveryConfirm(
      roomId: room, peerDeviceId: 'stale', epoch: 2, confirmedAtMs: 1);
    await db.roomKeyRawConfirm(roomId: room, peerDeviceId: 'stale', epoch: 2);
    expect(
      await db.roomKeyRawReadyDevices(roomId: room, epoch: 3),
      {'new-build'},
    );
  });

  test('🔴 приём сырого провода: без слова реле — отброшен, с ним — в ленте',
      () async {
    final savedReceive = AppController.roomSenderKeyReceiveEnabled;
    AppController.roomSenderKeyReceiveEnabled = true;
    addTearDown(() => AppController.roomSenderKeyReceiveEnabled = savedReceive);

    // Автор: ключ выдан и подтверждён.
    final adb = await freshDb();
    addTearDown(adb.close);
    final amgr = RoomKeyManager(adb);
    await amgr.prepareSend(
      roomId: room,
      myDeviceId: author,
      memberDeviceIds: const [author, 'owner-device'],
      nowMs: 1000,
    );
    final grant = (await amgr.keyGrantFor(roomId: room))!;
    await adb.roomKeyDeliveryMark(
        roomId: room, peerDeviceId: 'owner-device', epoch: grant.epoch, deliveredAtMs: 1);
    await adb.roomKeyDeliveryConfirm(
        roomId: room, peerDeviceId: 'owner-device', epoch: grant.epoch, confirmedAtMs: 1);
    final slot = ((await amgr.prepareSend(
      roomId: room,
      myDeviceId: author,
      memberDeviceIds: const [author, 'owner-device'],
      nowMs: 1000,
    )) as RoomSendReady).slot;

    // Получатель.
    final rdb = await freshDb();
    addTearDown(rdb.close);
    await rdb.convoEnsureGroup(groupId: room, title: 'Сырой');
    for (final pid in const ['author-1', 'owner-1']) {
      await rdb.groupMemberEnsure(groupId: room, memberProfileId: pid);
    }
    await rdb.deviceProfileUpsert(deviceId: author, profileId: 'author-1');
    final controller = AppController()
      ..seedRoomRuntimeForTesting(
        db: rdb,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        crypto: DartCryptoProvider(
          Uint8List.fromList(List<int>.generate(32, (i) => i)),
        ),
      )
      ..seedKeysRuntimeForTesting(
        keys: KeysClient(baseUrl: Uri.parse('https://keys.invalid')),
      );
    final grantPayload = E2ePayloadV1(
      senderDeviceId: author,
      createdAtMs: 1,
      events: [
        RoomKeyEventV1(
          roomId: room,
          epoch: grant.epoch,
          counter: grant.counter,
          chainKey: grant.chainKey,
          issuedAtMs: 1,
          signingPub: grant.signingPub,
        ),
      ],
    );
    await controller.handleDecryptedInboundPayloadForTesting(
      db: rdb,
      msgId: 'grant',
      ciphertextB64: 'AA==',
      plainBytes: Uint8List.fromList(grantPayload.encode()),
      payload: grantPayload,
      senderDeviceId: author,
      senderProfileId: 'author-1',
    );

    final envelope = <String, Object?>{
      'v': 1,
      'kind': 'message',
      'groupId': room,
      'groupTitle': 'Сырой',
      'msgEventId': 'raw-msg-1',
      'text': 'одним запросом',
      'createdAtMs': 5000,
      'memberProfileIds': const ['author-1', 'owner-1'],
      'senderProfileId': 'author-1',
    };
    final inner = E2ePayloadV1(
      senderDeviceId: author,
      createdAtMs: 5000,
      events: [
        MsgEventV1(
          eventId: 'inner-raw',
          text: '__secretly_group_msg_v1__:'
              '${base64Url.encode(utf8.encode(jsonEncode(envelope)))}',
        ),
      ],
    );
    final box = await RoomKeyChain.encrypt(
      messageKey: slot.messageKey,
      plaintext: Uint8List.fromList(inner.encode()),
      aad: slot.aad,
    );
    final nonce = base64Decode(box.nonceB64);
    final ct = base64Decode(box.ciphertextB64);
    final wire = RoomRawWire.encode(
      RoomMessageEventV1(
        roomId: room,
        epoch: slot.epoch,
        counter: slot.counter,
        nonce: nonce,
        ciphertext: ct,
        signature: await RoomMessageSignature.sign(
          seed: slot.signingSeed!,
          aad: slot.aad,
          nonce: nonce,
          ciphertext: ct,
        ),
      ),
    );
    Future<int> stored() async => (await rdb.rawQueryForTesting(
      "SELECT COUNT(*) c FROM events WHERE payload_event_id = 'raw-msg-1'",
    )).first['c'] as int;

    // Без слова реле — отброшен навсегда.
    expect(
      await controller.handleDeliveredForTesting(
        msgId: 'raw-unattested',
        ciphertextB64: base64Encode(wire),
      ),
      isTrue,
    );
    expect(await stored(), 0);

    // Реле назвало автора — сообщение в ленте.
    AttestedSenders.record('raw-attested', author);
    await controller.handleDeliveredForTesting(
      msgId: 'raw-attested',
      ciphertextB64: base64Encode(wire),
    );
    expect(await stored(), 1);
  });
}
