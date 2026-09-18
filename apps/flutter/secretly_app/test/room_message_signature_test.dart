// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ratchet/room_key_chain.dart';
import 'package:secretly_app/ratchet/room_key_manager.dart';
import 'package:secretly_app/ratchet/room_message_signature.dart';
import 'package:secretly_app/storage/app_db.dart';

// К-1 (17.09.2026): подпись сообщений комнаты. Цепочка симметричная, поэтому
// без подписи любой участник, держащий цепочку автора, мог бы запечатать
// сообщение «от автора».

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const room = 'group:signed';
  const author = 'author-dev';
  const member = 'member-dev';

  late Directory tmp;
  var seq = 0;
  Future<AppDb> freshDb() =>
      AppDb.openForTesting(path: '${tmp.path}/d${seq++}.db');

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('room_sig');
    seq = 0;
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Автор с выданным и подтверждённым ключом; возвращает слот отправки.
  Future<({RoomKeyManager mgr, AppDb db, RoomKeyGrant grant, RoomSendSlot slot})>
  readyAuthor() async {
    final db = await freshDb();
    addTearDown(db.close);
    final mgr = RoomKeyManager(db);
    await mgr.prepareSend(
      roomId: room,
      myDeviceId: author,
      memberDeviceIds: const [author, member],
      nowMs: 1000,
    );
    final grant = (await mgr.keyGrantFor(roomId: room))!;
    await db.roomKeyDeliveryMark(
      roomId: room,
      peerDeviceId: member,
      epoch: grant.epoch,
      deliveredAtMs: 1000,
    );
    await db.roomKeyDeliveryConfirm(
      roomId: room,
      peerDeviceId: member,
      epoch: grant.epoch,
      confirmedAtMs: 1000,
    );
    final outcome = await mgr.prepareSend(
      roomId: room,
      myDeviceId: author,
      memberDeviceIds: const [author, member],
      nowMs: 1000,
    );
    return (
      mgr: mgr,
      db: db,
      grant: grant,
      slot: (outcome as RoomSendReady).slot,
    );
  }

  Future<({Uint8List nonce, Uint8List ct})> seal(RoomSendSlot slot) async {
    final box = await RoomKeyChain.encrypt(
      messageKey: slot.messageKey,
      plaintext: Uint8List.fromList('привет'.codeUnits),
      aad: slot.aad,
    );
    return (
      nonce: Uint8List.fromList(RoomKeyChainTestBytes.b64(box.nonceB64)),
      ct: Uint8List.fromList(RoomKeyChainTestBytes.b64(box.ciphertextB64)),
    );
  }

  test('новое поколение подписано, ключ подписи едет в выдаче', () async {
    final a = await readyAuthor();
    expect(a.slot.signingSeed, isNotNull);
    expect(a.grant.signingPub, hasLength(32));
    expect(
      await RoomMessageSignature.publicKeyForSeed(a.slot.signingSeed!),
      a.grant.signingPub,
    );
  });

  test('🔴 подпись верна — открывается; чужая или нет — отказ, ключ цел',
      () async {
    final a = await readyAuthor();
    final sealed = await seal(a.slot);
    final signature = await RoomMessageSignature.sign(
      seed: a.slot.signingSeed!,
      aad: a.slot.aad,
      nonce: sealed.nonce,
      ciphertext: sealed.ct,
    );

    final rdb = await freshDb();
    addTearDown(rdb.close);
    final receiver = RoomKeyManager(rdb);
    expect(
      await receiver.acceptKeyGrant(
        roomId: room,
        senderDeviceId: author,
        epoch: a.grant.epoch,
        counter: a.grant.counter,
        chainKey: a.grant.chainKey,
        signingPub: a.grant.signingPub,
        nowMs: 1000,
      ),
      isTrue,
    );
    final slot = (await receiver.openInbound(
      roomId: room,
      senderDeviceId: author,
      epoch: a.slot.epoch,
      counter: a.slot.counter,
    ))!;
    expect(slot.signingPub, a.grant.signingPub);

    // Подделка: другой ключ подписи — отказ.
    final forger = RoomMessageSignature.newSeed();
    final forged = await RoomMessageSignature.sign(
      seed: forger,
      aad: slot.aad,
      nonce: sealed.nonce,
      ciphertext: sealed.ct,
    );
    for (final bad in <Uint8List>[forged, Uint8List(64)]) {
      expect(
        await RoomMessageSignature.verify(
          publicKey: slot.signingPub!,
          signature: bad,
          aad: slot.aad,
          nonce: sealed.nonce,
          ciphertext: sealed.ct,
        ),
        isFalse,
      );
    }
    // Подпись к другому шифртексту — отказ.
    expect(
      await RoomMessageSignature.verify(
        publicKey: slot.signingPub!,
        signature: signature,
        aad: slot.aad,
        nonce: sealed.nonce,
        ciphertext: Uint8List.fromList([...sealed.ct]..[0] ^= 1),
      ),
      isFalse,
    );
    // Настоящая — проходит, и после продвижения ключ подписи на месте.
    expect(
      await RoomMessageSignature.verify(
        publicKey: slot.signingPub!,
        signature: signature,
        aad: slot.aad,
        nonce: sealed.nonce,
        ciphertext: sealed.ct,
      ),
      isTrue,
    );
    await receiver.commitInbound(slot: slot, nowMs: 1001);
    final next = await rdb.roomRecvKeyGet(
      roomId: room,
      senderDeviceId: author,
      epoch: a.slot.epoch,
    );
    expect(next!['signing_pub'], a.grant.signingPub);
  });

  test('ключ от сборки без подписи — сообщение без подписи, как раньше',
      () async {
    final rdb = await freshDb();
    addTearDown(rdb.close);
    final receiver = RoomKeyManager(rdb);
    await receiver.acceptKeyGrant(
      roomId: room,
      senderDeviceId: author,
      epoch: 1,
      counter: 0,
      chainKey: RoomKeyChain.randomKey(),
      nowMs: 1000,
    );
    final slot = (await receiver.openInbound(
      roomId: room,
      senderDeviceId: author,
      epoch: 1,
      counter: 0,
    ))!;
    expect(slot.signingPub, isNull);
  });

  test('поколение без подписи (до обновления) сменяется', () async {
    final db = await freshDb();
    addTearDown(db.close);
    await db.roomSendKeyPut(
      roomId: room,
      epoch: 3,
      chainKey: RoomKeyChain.randomKey(),
      counter: 5,
      createdAtMs: 1000,
    );
    await db.roomMemberSnapshotPut(
      roomId: room,
      deviceIds: RoomKeyManager.canonicalMembers(const [author, member]),
      updatedAtMs: 1000,
    );
    final mgr = RoomKeyManager(db);
    expect(
      await mgr.rotationReason(
        roomId: room,
        members: RoomKeyManager.canonicalMembers(const [author, member]),
        nowMs: 1001,
      ),
      RoomKeyManager.rotateReasonUnsigned,
    );
  });

  test('🔴 контроллер: поддельная подпись не доходит до ленты, настоящая — доходит',
      () async {
    final savedReceive = AppController.roomSenderKeyReceiveEnabled;
    AppController.roomSenderKeyReceiveEnabled = true;
    addTearDown(
      () => AppController.roomSenderKeyReceiveEnabled = savedReceive,
    );
    final a = await readyAuthor();

    final rdb = await freshDb();
    addTearDown(rdb.close);
    await rdb.convoEnsureGroup(groupId: room, title: 'Подписи');
    for (final pid in const ['author-1', 'owner-1']) {
      await rdb.groupMemberEnsure(groupId: room, memberProfileId: pid);
    }
    final controller = AppController()
      ..seedRoomRuntimeForTesting(
        db: rdb,
        profileId: 'owner-1',
        deviceId: 'owner-device',
        crypto: DartCryptoProvider(
          Uint8List.fromList(List<int>.generate(32, (i) => i)),
        ),
      );
    Future<void> deliver(String msgId, E2eEventV1 event) async {
      final payload = E2ePayloadV1(
        senderDeviceId: author,
        createdAtMs: 5000,
        events: [event],
      );
      await controller.handleDecryptedInboundPayloadForTesting(
        db: rdb,
        msgId: msgId,
        ciphertextB64: 'AA==',
        plainBytes: Uint8List.fromList(payload.encode()),
        payload: payload,
        senderDeviceId: author,
        senderProfileId: 'author-1',
        nowMs: 5000,
      );
    }

    await deliver(
      'grant',
      RoomKeyEventV1(
        roomId: room,
        epoch: a.grant.epoch,
        counter: a.grant.counter,
        chainKey: a.grant.chainKey,
        issuedAtMs: 1000,
        signingPub: a.grant.signingPub,
      ),
    );

    final envelope = <String, Object?>{
      'v': 1,
      'kind': 'message',
      'groupId': room,
      'groupTitle': 'Подписи',
      'msgEventId': 'signed-msg-1',
      'text': 'подписано',
      'createdAtMs': 5000,
      'memberProfileIds': const ['author-1', 'owner-1'],
      'senderProfileId': 'author-1',
    };
    final inner = E2ePayloadV1(
      senderDeviceId: author,
      createdAtMs: 5000,
      events: [
        MsgEventV1(
          eventId: 'inner-1',
          text: '__secretly_group_msg_v1__:'
              '${base64Url.encode(utf8.encode(jsonEncode(envelope)))}',
        ),
      ],
    );
    final box = await RoomKeyChain.encrypt(
      messageKey: a.slot.messageKey,
      plaintext: Uint8List.fromList(inner.encode()),
      aad: a.slot.aad,
    );
    final nonce = base64Decode(box.nonceB64);
    final ct = base64Decode(box.ciphertextB64);
    RoomMessageEventV1 wire(Uint8List? sig) => RoomMessageEventV1(
      roomId: room,
      epoch: a.slot.epoch,
      counter: a.slot.counter,
      nonce: nonce,
      ciphertext: ct,
      signature: sig,
    );
    Future<int> stored() async => (await rdb.rawQueryForTesting(
      "SELECT COUNT(*) c FROM events WHERE convo_id = ? AND payload_event_id = 'signed-msg-1'",
      <Object?>[room],
    )).first['c'] as int;

    await deliver('unsigned', wire(null));
    await deliver(
      'forged',
      wire(await RoomMessageSignature.sign(
        seed: RoomMessageSignature.newSeed(),
        aad: a.slot.aad,
        nonce: nonce,
        ciphertext: ct,
      )),
    );
    expect(await stored(), 0, reason: 'подделка не должна попасть в ленту');

    await deliver(
      'genuine',
      wire(await RoomMessageSignature.sign(
        seed: a.slot.signingSeed!,
        aad: a.slot.aad,
        nonce: nonce,
        ciphertext: ct,
      )),
    );
    expect(await stored(), 1, reason: 'настоящее сообщение открылось после подделок');
  });

  test('провод: поля подписи необязательны и проверяются по длине', () {
    final withSig = RoomMessageEventV1(
      roomId: room,
      epoch: 1,
      counter: 2,
      nonce: Uint8List(24),
      ciphertext: Uint8List(20),
      signature: Uint8List(64),
    );
    final back = RoomMessageEventV1.fromJson(
      Map<String, dynamic>.from(withSig.toJson()),
    );
    expect(back.signature, hasLength(64));
    final legacy = Map<String, dynamic>.from(withSig.toJson())
      ..remove('sig_b64');
    expect(RoomMessageEventV1.fromJson(legacy).signature, isNull);
    expect(
      () => RoomMessageEventV1.fromJson({...legacy, 'sig_b64': 'AAAA'}),
      throwsFormatException,
    );
    final grant = RoomKeyEventV1(
      roomId: room,
      epoch: 1,
      counter: 0,
      chainKey: Uint8List(32),
      issuedAtMs: 1,
      signingPub: Uint8List(32),
    );
    expect(
      RoomKeyEventV1.fromJson(Map<String, dynamic>.from(grant.toJson()))
          .signingPub,
      hasLength(32),
    );
  });
}

/// base64 без лишних зависимостей в самом тесте.
class RoomKeyChainTestBytes {
  static List<int> b64(String v) => const Base64Decoder().convert(v);
}
