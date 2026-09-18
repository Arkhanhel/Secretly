// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ratchet/room_key_chain.dart';
import 'package:secretly_app/ratchet/room_key_manager.dart';
import 'package:secretly_app/storage/app_db.dart';

/// The whole room-key loop, end to end, exactly the way the app performs it:
/// seal → wire → parse → open → read.
///
/// Every piece already has its own tests, but nothing until now walked a
/// message from one device to another. That is precisely where the mistakes
/// that only appear in the field live — an AAD assembled differently on each
/// side, a field lost on the wire, a position committed at the wrong moment.
/// This closes the loop in code before anyone is asked to close it on a phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const author = 'author-dev';
  const room = 'group:team';

  late Directory tmp;
  var dbSeq = 0;

  // Separate files per device: `:memory:` is cached by path, so two calls hand
  // back ONE database and the two sides would silently share a key store.
  Future<AppDb> freshDb() async =>
      AppDb.openForTesting(path: '${tmp.path}/dev${dbSeq++}.db');

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('room_e2e');
    dbSeq = 0;
  });

  tearDown(() async {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// What the sender does: reserve a position, seal the ordinary payload it
  /// would have sent pairwise, commit the position, and hand back the wire
  /// bytes every member receives.
  Future<List<int>> sealAsAuthor({
    required RoomKeyManager mgr,
    required String text,
    required List<String> memberDevices,
    required int nowMs,
  }) async {
    final outcome = await mgr.prepareSend(
      roomId: room,
      myDeviceId: author,
      memberDeviceIds: memberDevices,
      nowMs: nowMs,
    );
    final slot = (outcome as RoomSendReady).slot;

    final inner = E2ePayloadV1(
      senderDeviceId: author,
      createdAtMs: nowMs,
      events: [MsgEventV1(eventId: 'evt-$text', text: text)],
    );
    final box = await RoomKeyChain.encrypt(
      messageKey: slot.messageKey,
      plaintext: Uint8List.fromList(inner.encode()),
      aad: slot.aad,
    );
    expect(await mgr.commitSend(slot: slot), isTrue);

    // The wire as it actually travels: a gmsg inside an ordinary payload, which
    // the pairwise layer then carries to each device.
    return E2ePayloadV1(
      senderDeviceId: author,
      createdAtMs: nowMs,
      events: [
        RoomMessageEventV1(
          roomId: room,
          epoch: slot.epoch,
          counter: slot.counter,
          nonce: base64Decode(box.nonceB64),
          ciphertext: base64Decode(box.ciphertextB64),
        ),
      ],
    ).encode();
  }

  /// What the receiver does: parse the wire, open it with the room key, and
  /// read the ordinary payload inside.
  Future<String?> openAsMember(RoomKeyManager peer, List<int> wire) async {
    final outer = E2ePayloadV1.decode(wire);
    final gmsg = outer.events.whereType<RoomMessageEventV1>().single;

    final slot = await peer.openInbound(
      roomId: gmsg.roomId,
      // Attribution comes from the OUTER envelope, never from a claim inside
      // the sealed payload.
      //
      // The app is STRICTER still: it takes the author from the ratchet wire
      // HEADER, which is bound to the pairwise session, and only falls back to
      // the payload field when a wire omits it. There is no header to model
      // here, and for an honest sender the two are the same value — both are
      // that device's own id at send time. Noted so the simplification is
      // visible rather than a silent difference: if they ever diverged, the AAD
      // would stop matching and NO room message would open.
      senderDeviceId: outer.senderDeviceId,
      epoch: gmsg.epoch,
      counter: gmsg.counter,
    );
    if (slot == null) return null;

    final plain = await RoomKeyChain.decrypt(
      messageKey: slot.messageKey,
      nonceB64: base64Encode(gmsg.nonce),
      ciphertextB64: base64Encode(gmsg.ciphertext),
      aad: slot.aad,
    );
    if (plain == null) return null;
    await peer.commitInbound(slot: slot, nowMs: 1);
    return E2ePayloadV1.decode(plain).events.whereType<MsgEventV1>().single.text;
  }

  /// Hands the author's current key to a member, the way the send path does
  /// before the first message of a generation goes out.
  Future<void> handKeyOver(RoomKeyManager from, RoomKeyManager to) async {
    final grant = (await from.keyGrantFor(roomId: room))!;
    await to.acceptKeyGrant(
      roomId: room,
      senderDeviceId: author,
      epoch: grant.epoch,
      counter: grant.counter,
      chainKey: grant.chainKey,
      nowMs: 1,
    );
  }

  test('a message written in a room is readable by a member — the whole loop',
      () async {
    final authorDb = await freshDb();
    final memberDb = await freshDb();
    final mgr = RoomKeyManager(authorDb);
    final peer = RoomKeyManager(memberDb);
    const members = ['member-dev'];

    // The very first send is blocked until the member holds the key, which is
    // what the send path does before anything goes out.
    expect(
      await mgr.prepareSend(
        roomId: room,
        myDeviceId: author,
        memberDeviceIds: members,
        nowMs: 1000,
      ),
      isA<RoomSendBlocked>(),
    );
    await handKeyOver(mgr, peer);
    await authorDb.roomKeyDeliveryMark(
roomId: room,
      peerDeviceId: 'member-dev',
      epoch: 1,
      deliveredAtMs: 1000,
    );
    // The member acks that it APPLIED the key (F-ROOMSK-3/4).
    // Delivery alone no longer unblocks sending: without this
    // proof the room stays on the pairwise path, which is what
    // keeps an older peer from silently losing messages.
    await authorDb.roomKeyDeliveryConfirm(
roomId: room,
      peerDeviceId: 'member-dev',
      epoch: 1,
      confirmedAtMs: 1000,
    );

    final wire = await sealAsAuthor(
      mgr: mgr,
      text: 'привет комната',
      memberDevices: members,
      nowMs: 1000,
    );
    expect(await openAsMember(peer, wire), 'привет комната');

    await authorDb.close();
    await memberDb.close();
  });

  test('ONE sealing serves every member — that is the entire point', () async {
    final authorDb = await freshDb();
    final mgr = RoomKeyManager(authorDb);
    const members = ['m1-dev', 'm2-dev', 'm3-dev'];

    final peers = <RoomKeyManager>[];
    for (final _ in members) {
      peers.add(RoomKeyManager(await freshDb()));
    }
    // Everyone is keyed first — the key travels before the message it protects.
    expect(
      await mgr.prepareSend(
        roomId: room,
        myDeviceId: author,
        memberDeviceIds: members,
        nowMs: 1000,
      ),
      isA<RoomSendBlocked>(),
    );
    for (final peer in peers) {
      await handKeyOver(mgr, peer);
    }
    for (final d in members) {
      await authorDb.roomKeyDeliveryMark(
roomId: room,
        peerDeviceId: d,
        epoch: 1,
        deliveredAtMs: 1000,
      );
      // The member acks that it APPLIED the key (F-ROOMSK-3/4).
      // Delivery alone no longer unblocks sending: without this
      // proof the room stays on the pairwise path, which is what
      // keeps an older peer from silently losing messages.
      await authorDb.roomKeyDeliveryConfirm(
roomId: room,
        peerDeviceId: d,
        epoch: 1,
        confirmedAtMs: 1000,
      );
    }

    // Sealed ONCE. The identical bytes go to all three.
    final wire = await sealAsAuthor(
      mgr: mgr,
      text: 'одно шифрование',
      memberDevices: members,
      nowMs: 1000,
    );
    for (final peer in peers) {
      expect(await openAsMember(peer, wire), 'одно шифрование');
    }
    await authorDb.close();
  });

  test('a departed member cannot read what the room says afterwards', () async {
    final authorDb = await freshDb();
    final mgr = RoomKeyManager(authorDb);
    final leaverDb = await freshDb();
    final leaver = RoomKeyManager(leaverDb);
    final stayerDb = await freshDb();
    final stayer = RoomKeyManager(stayerDb);

    // Both members keyed and reading normally.
    await mgr.prepareSend(
      roomId: room,
      myDeviceId: author,
      memberDeviceIds: const ['leaver-dev', 'stayer-dev'],
      nowMs: 1000,
    );
    await handKeyOver(mgr, leaver);
    await handKeyOver(mgr, stayer);
    for (final d in ['leaver-dev', 'stayer-dev']) {
      await authorDb.roomKeyDeliveryMark(
roomId: room,
        peerDeviceId: d,
        epoch: 1,
        deliveredAtMs: 1000,
      );
      // The member acks that it APPLIED the key (F-ROOMSK-3/4).
      // Delivery alone no longer unblocks sending: without this
      // proof the room stays on the pairwise path, which is what
      // keeps an older peer from silently losing messages.
      await authorDb.roomKeyDeliveryConfirm(
roomId: room,
        peerDeviceId: d,
        epoch: 1,
        confirmedAtMs: 1000,
      );
    }
    final before = await sealAsAuthor(
      mgr: mgr,
      text: 'до ухода',
      memberDevices: const ['leaver-dev', 'stayer-dev'],
      nowMs: 1000,
    );
    expect(await openAsMember(leaver, before), 'до ухода');

    // The leaver goes. The membership change forces a new generation, and only
    // the member who stayed is handed it.
    final outcome = await mgr.prepareSend(
      roomId: room,
      myDeviceId: author,
      memberDeviceIds: const ['stayer-dev'],
      nowMs: 2000,
    );
    expect(outcome, isA<RoomSendBlocked>());
    expect(
      (outcome as RoomSendBlocked).rotatedReason,
      RoomKeyManager.rotateReasonMembership,
    );
    await handKeyOver(mgr, stayer);
    await authorDb.roomKeyDeliveryMark(
roomId: room,
      peerDeviceId: 'stayer-dev',
      epoch: outcome.epoch,
      deliveredAtMs: 2000,
    );
    // The member acks that it APPLIED the key (F-ROOMSK-3/4).
    // Delivery alone no longer unblocks sending: without this
    // proof the room stays on the pairwise path, which is what
    // keeps an older peer from silently losing messages.
    await authorDb.roomKeyDeliveryConfirm(
roomId: room,
      peerDeviceId: 'stayer-dev',
      epoch: outcome.epoch,
      confirmedAtMs: 2000,
    );

    final after = await sealAsAuthor(
      mgr: mgr,
      text: 'после ухода',
      memberDevices: const ['stayer-dev'],
      nowMs: 2000,
    );
    expect(await openAsMember(stayer, after), 'после ухода');
    // The whole reason the design exists.
    expect(await openAsMember(leaver, after), isNull);

    await authorDb.close();
    await leaverDb.close();
    await stayerDb.close();
  });

  test('messages that arrive out of order still all read', () async {
    final authorDb = await freshDb();
    final memberDb = await freshDb();
    final mgr = RoomKeyManager(authorDb);
    final peer = RoomKeyManager(memberDb);
    const members = ['member-dev'];

    await mgr.prepareSend(
      roomId: room,
      myDeviceId: author,
      memberDeviceIds: members,
      nowMs: 1000,
    );
    await handKeyOver(mgr, peer);
    await authorDb.roomKeyDeliveryMark(
roomId: room,
      peerDeviceId: 'member-dev',
      epoch: 1,
      deliveredAtMs: 1000,
    );
    // The member acks that it APPLIED the key (F-ROOMSK-3/4).
    // Delivery alone no longer unblocks sending: without this
    // proof the room stays on the pairwise path, which is what
    // keeps an older peer from silently losing messages.
    await authorDb.roomKeyDeliveryConfirm(
roomId: room,
      peerDeviceId: 'member-dev',
      epoch: 1,
      confirmedAtMs: 1000,
    );

    final wires = <List<int>>[];
    for (final t in ['первое', 'второе', 'третье']) {
      wires.add(
        await sealAsAuthor(
          mgr: mgr,
          text: t,
          memberDevices: members,
          nowMs: 1000,
        ),
      );
    }

    // The last one arrives first; the stragglers follow.
    expect(await openAsMember(peer, wires[2]), 'третье');
    expect(await openAsMember(peer, wires[0]), 'первое');
    expect(await openAsMember(peer, wires[1]), 'второе');
    // And a replay of one already read opens for nobody.
    expect(await openAsMember(peer, wires[0]), isNull);

    await authorDb.close();
    await memberDb.close();
  });
}
