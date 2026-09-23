// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ratchet/room_key_chain.dart';
import 'package:secretly_app/ratchet/room_key_manager.dart';
import 'package:secretly_app/storage/app_db.dart';

/// The unrepresentability tests for the room sender key.
///
/// Each one pins an outcome that must be IMPOSSIBLE, not merely unlikely. The
/// two that matter most are §11.1 (a departed member reading on) and §11.2 (a
/// send that skipped rotation) — both fail silently when they go wrong, which
/// is why they are pinned here rather than left to review.
typedef Wire = ({
  String nonceB64,
  String ciphertextB64,
  int epoch,
  int counter,
  String? rotated,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const me = 'my-dev';
  const alice = 'alice-dev';
  const bob = 'bob-dev';
  const room = 'group:team';

  late Directory tmp;
  late AppDb db;
  late RoomKeyManager mgr;
  late Map<String, RoomKeyGrant> grants;
  var clock = 1000;
  var dbSeq = 0;

  /// A genuinely separate database, one per simulated device.
  ///
  /// `:memory:` will NOT do: sqflite caches by path, so every
  /// `openForTesting()` hands back the SAME database — sender and receiver
  /// would share one key store, and closing one would close the other. A test
  /// about two devices has to actually have two.
  Future<AppDb> freshDb() async =>
      AppDb.openForTesting(path: '${tmp.path}/dev${dbSeq++}.db');

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('room_key_mgr');
    dbSeq = 0;
    db = await freshDb();
    mgr = RoomKeyManager(db);
    grants = <String, RoomKeyGrant>{};
    clock = 1000;
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('F-ROOMSK-3/4 — sending waits for the member to CONFIRM the key', () {
    // The coexistence guarantee, in one property: a member we cannot prove is
    // keyed keeps the room on the pairwise fanout. Since only a build that
    // understands the sender-key wire can produce a `gkeyack`, an older peer
    // never confirms, never gets sealed messages, and therefore cannot lose
    // them. This is exactly what 1.7.4+416 lacked.

    test('DELIVERED alone does not unblock sending', () async {
      var outcome = await mgr.prepareSend(
        roomId: room,
        myDeviceId: me,
        memberDeviceIds: const [me, alice],
        nowMs: clock,
      );
      expect(outcome, isA<RoomSendBlocked>());
      final grant = (await mgr.keyGrantFor(roomId: room))!;

      // The key is in the outbox — which is all "delivered" ever meant.
      await db.roomKeyDeliveryMark(
        roomId: room,
        peerDeviceId: alice,
        epoch: grant.epoch,
        deliveredAtMs: clock,
      );

      outcome = await mgr.prepareSend(
        roomId: room,
        myDeviceId: me,
        memberDeviceIds: const [me, alice],
        nowMs: clock,
      );
      expect(
        outcome,
        isA<RoomSendBlocked>(),
        reason: 'enqueueing a key proves nothing about the peer reading it',
      );
    });

    test('a CONFIRMED key unblocks sending', () async {
      await mgr.prepareSend(
        roomId: room,
        myDeviceId: me,
        memberDeviceIds: const [me, alice],
        nowMs: clock,
      );
      final grant = (await mgr.keyGrantFor(roomId: room))!;
      await db.roomKeyDeliveryMark(
        roomId: room,
        peerDeviceId: alice,
        epoch: grant.epoch,
        deliveredAtMs: clock,
      );
      await db.roomKeyDeliveryConfirm(
        roomId: room,
        peerDeviceId: alice,
        epoch: grant.epoch,
        confirmedAtMs: clock,
      );

      final outcome = await mgr.prepareSend(
        roomId: room,
        myDeviceId: me,
        memberDeviceIds: const [me, alice],
        nowMs: clock,
      );
      expect(outcome, isA<RoomSendReady>());
    });

    test('a confirmation for an OLDER generation does not count', () async {
      await mgr.prepareSend(
        roomId: room,
        myDeviceId: me,
        memberDeviceIds: const [me, alice],
        nowMs: clock,
      );
      final first = (await mgr.keyGrantFor(roomId: room))!;
      await db.roomKeyDeliveryMark(
        roomId: room,
        peerDeviceId: alice,
        epoch: first.epoch,
        deliveredAtMs: clock,
      );
      await db.roomKeyDeliveryConfirm(
        roomId: room,
        peerDeviceId: alice,
        epoch: first.epoch,
        confirmedAtMs: clock,
      );

      // Membership changes ⇒ new generation. The old ack must not carry over,
      // or a member would look current for a key they were never given.
      final outcome = await mgr.prepareSend(
        roomId: room,
        myDeviceId: me,
        memberDeviceIds: const [me, alice, bob],
        nowMs: clock + 1,
      );
      expect(outcome, isA<RoomSendBlocked>());
      expect((outcome as RoomSendBlocked).awaitingKey, contains(alice));
    });

    test('an ack cannot invent a row for a key we never sent', () async {
      // The UPDATE matches nothing, so a peer cannot mark ITSELF as keyed.
      await db.roomKeyDeliveryConfirm(
        roomId: room,
        peerDeviceId: alice,
        epoch: 0,
        confirmedAtMs: clock,
      );
      expect(
        await db.roomKeyConfirmedEpoch(roomId: room, peerDeviceId: alice),
        isNull,
      );
    });
  });

  Future<({String nonceB64, String ciphertextB64})> sealWith(
    RoomSendSlot slot,
    String text,
  ) => RoomKeyChain.encrypt(
    messageKey: slot.messageKey,
    plaintext: Uint8List.fromList(utf8.encode(text)),
    aad: slot.aad,
  );

  /// A full send in the order §7 requires: rotate if needed → hand the key to
  /// whoever is owed it → seal → commit.
  ///
  /// The key goes out BEFORE the message on purpose. The chain only ratchets
  /// forward, so a member handed the key afterwards could never read that
  /// message — not late, never. [grants] records what each device received, the
  /// way the real delivery path will.
  Future<Wire> send({
    required List<String> members,
    required String text,
  }) async {
    String? rotated;
    var outcome = await mgr.prepareSend(
      roomId: room,
      myDeviceId: me,
      memberDeviceIds: members,
      nowMs: clock,
    );
    if (outcome is RoomSendBlocked) {
      rotated = outcome.rotatedReason;
      final grant = (await mgr.keyGrantFor(roomId: room))!;
      for (final device in outcome.awaitingKey) {
        grants[device] = grant;
        await db.roomKeyDeliveryMark(
roomId: room,
          peerDeviceId: device,
          epoch: grant.epoch,
          deliveredAtMs: clock,
        );
        // The member acks that it APPLIED the key (F-ROOMSK-3/4).
        // Delivery alone no longer unblocks sending: without this
        // proof the room stays on the pairwise path, which is what
        // keeps an older peer from silently losing messages.
        await db.roomKeyDeliveryConfirm(
roomId: room,
          peerDeviceId: device,
          epoch: grant.epoch,
          confirmedAtMs: clock,
        );
      }
      outcome = await mgr.prepareSend(
        roomId: room,
        myDeviceId: me,
        memberDeviceIds: members,
        nowMs: clock,
      );
    }
    final slot = (outcome as RoomSendReady).slot;
    rotated ??= slot.rotatedReason;
    final box = await sealWith(slot, text);
    expect(await mgr.commitSend(slot: slot), isTrue);
    return (
      nonceB64: box.nonceB64,
      ciphertextB64: box.ciphertextB64,
      epoch: slot.epoch,
      counter: slot.counter,
      rotated: rotated,
    );
  }

  /// A member's device: its own store, seeded with whatever key it was granted.
  Future<RoomKeyManager> deviceHolding(RoomKeyGrant grant) async {
    final peer = await freshDb();
    final peerMgr = RoomKeyManager(peer);
    await peerMgr.acceptKeyGrant(
      roomId: grant.roomId,
      senderDeviceId: me,
      epoch: grant.epoch,
      counter: grant.counter,
      chainKey: grant.chainKey,
      nowMs: clock,
    );
    return peerMgr;
  }

  /// Opens [wire] on [peerMgr] without consuming it (no commit).
  Future<String?> peek(RoomKeyManager peerMgr, Wire wire) async {
    final slot = await peerMgr.openInbound(
      roomId: room,
      senderDeviceId: me,
      epoch: wire.epoch,
      counter: wire.counter,
    );
    if (slot == null) return null;
    final plain = await RoomKeyChain.decrypt(
      messageKey: slot.messageKey,
      nonceB64: wire.nonceB64,
      ciphertextB64: wire.ciphertextB64,
      aad: slot.aad,
    );
    return plain == null ? null : utf8.decode(plain);
  }

  /// Opens and consumes, the way the receive path will.
  Future<String?> deliver(RoomKeyManager peerMgr, Wire wire) async {
    final slot = await peerMgr.openInbound(
      roomId: room,
      senderDeviceId: me,
      epoch: wire.epoch,
      counter: wire.counter,
    );
    if (slot == null) return null;
    final plain = await RoomKeyChain.decrypt(
      messageKey: slot.messageKey,
      nonceB64: wire.nonceB64,
      ciphertextB64: wire.ciphertextB64,
      aad: slot.aad,
    );
    if (plain == null) return null;
    await peerMgr.commitInbound(slot: slot, nowMs: clock);
    return utf8.decode(plain);
  }

  test('§11.1 a departed member cannot read what was sent after they '
      'left', () async {
    await send(members: [me, alice, bob], text: 'до ухода');
    final aliceHeld = grants[alice]!;

    clock += 1000;
    final after = await send(members: [me, bob], text: 'после ухода');
    expect(
      after.rotated,
      RoomKeyManager.rotateReasonMembership,
      reason: 'a membership change must force a new generation',
    );

    // Everything Alice ever held is useless against the new generation.
    expect(await peek(await deviceHolding(aliceHeld), after), isNull);

    // Bob, who stayed, was re-keyed by the rotation and reads it.
    expect(grants[bob]!.epoch, after.epoch);
    expect(await peek(await deviceHolding(grants[bob]!), after), 'после ухода');
  });

  test('§11.1 rotation is unilateral: a second sender who saw the same '
      'departure also locks the leaver out', () async {
    // Each sender owns their own chain. If only one rotated, the departed
    // member would keep reading everyone else — so the trigger has to be a
    // condition every sender evaluates alone, with nothing to agree on.
    final second = RoomKeyManager(await freshDb());
    Future<String?> reasonFor(List<String> members) => second.rotationReason(
      roomId: room,
      members: RoomKeyManager.canonicalMembers(members),
      nowMs: clock,
    );

    // Bring the second sender to a settled generation for the full room.
    await second.rotate(
      roomId: room,
      members: RoomKeyManager.canonicalMembers([me, alice, bob]),
      nowMs: clock,
    );
    expect(await reasonFor([me, alice, bob]), isNull);

    // The same departure, observed independently, demands the same rotation.
    expect(
      await reasonFor([me, bob]),
      RoomKeyManager.rotateReasonMembership,
    );
  });

  test('§11.2 a changed membership cannot be sent under the old '
      'generation', () async {
    // Enforced by construction: the only way to a key is prepareSend, and
    // prepareSend rotates first. No API hands out the current key unchecked, so
    // a caller cannot forget.
    await send(members: [me, alice], text: 'первое');
    final before = (await mgr.keyGrantFor(roomId: room))!;

    clock += 1000;
    final outcome = await mgr.prepareSend(
      roomId: room,
      myDeviceId: me,
      memberDeviceIds: [me, alice, bob],
      nowMs: clock,
    );

    // Blocked, because the new generation is owed to everyone — and the blocked
    // case carries no key material at all, so there is nothing to send with.
    expect(outcome, isA<RoomSendBlocked>());
    final blocked = outcome as RoomSendBlocked;
    expect(blocked.epoch, greaterThan(before.epoch));
    expect(blocked.rotatedReason, RoomKeyManager.rotateReasonMembership);
    expect(blocked.awaitingKey, [alice, bob]);
  });

  test('§6.4 a member still owed the key blocks the send instead of losing '
      'the message', () async {
    // A message sent before the key lands is unreadable to that member FOREVER
    // — the chain does not go back. Waiting costs a delay; sending costs the
    // message.
    final outcome = await mgr.prepareSend(
      roomId: room,
      myDeviceId: me,
      memberDeviceIds: [me, alice],
      nowMs: clock,
    );
    expect(outcome, isA<RoomSendBlocked>());
    expect((outcome as RoomSendBlocked).awaitingKey, [alice]);

    // Once delivery is recorded, the same call proceeds.
    final grant = (await mgr.keyGrantFor(roomId: room))!;
    await db.roomKeyDeliveryMark(
roomId: room,
      peerDeviceId: alice,
      epoch: grant.epoch,
      deliveredAtMs: clock,
    );
    // The member acks that it APPLIED the key (F-ROOMSK-3/4).
    // Delivery alone no longer unblocks sending: without this
    // proof the room stays on the pairwise path, which is what
    // keeps an older peer from silently losing messages.
    await db.roomKeyDeliveryConfirm(
roomId: room,
      peerDeviceId: alice,
      epoch: grant.epoch,
      confirmedAtMs: clock,
    );
    expect(
      await mgr.prepareSend(
        roomId: room,
        myDeviceId: me,
        memberDeviceIds: [me, alice],
        nowMs: clock,
      ),
      isA<RoomSendReady>(),
    );
  });

  test('member order and duplicates are not a membership change', () async {
    // Otherwise every sync would rotate — a key broadcast storm for nothing.
    await send(members: [me, alice, bob], text: 'первое');
    clock += 1000;
    final again = await send(
      members: [bob, alice, me, alice, '  '],
      text: 'второе',
    );
    expect(again.rotated, isNull);
    expect(again.counter, 1, reason: 'same generation, next position');
  });

  test('§11.3 a message missed at the time still opens when it turns '
      'up', () async {
    final members = [me, alice];
    await send(members: members, text: 'первое');
    final peer = await deviceHolding(grants[alice]!);

    final m1 = await send(members: members, text: 'второе');
    final m2 = await send(members: members, text: 'третье');
    final m3 = await send(members: members, text: 'четвёртое');

    // Alice's device sees the last one first; the others are still in flight.
    expect(await deliver(peer, m3), 'четвёртое');
    expect(await deliver(peer, m1), 'второе');
    expect(await deliver(peer, m2), 'третье');
  });

  test('§11.4 a replayed message never opens twice', () async {
    final members = [me, alice];
    await send(members: members, text: 'первое');
    final peer = await deviceHolding(grants[alice]!);

    final m1 = await send(members: members, text: 'второе');
    expect(await deliver(peer, m1), 'второе');
    // The position is behind the chain and its key was destroyed, so there is
    // nothing left to re-derive it from.
    expect(await deliver(peer, m1), isNull);

    // A straggler key is single use too.
    final m2 = await send(members: members, text: 'третье');
    final m3 = await send(members: members, text: 'четвёртое');
    expect(await deliver(peer, m3), 'четвёртое');
    expect(await deliver(peer, m2), 'третье');
    expect(
      await deliver(peer, m2),
      isNull,
      reason: 'a consumed straggler key must not open the same wire again',
    );
  });

  test('копия уже открытой позиции распознаётся — её не паркуют', () async {
    // Дубль после сбоя рассылки одним запросом: ключа для него не будет, и
    // парковка лишь стопорила бы ящик и крутила gkeyreq.
    final members = [me, alice];
    await send(members: members, text: 'первое');
    final peer = await deviceHolding(grants[alice]!);
    final m1 = await send(members: members, text: 'второе');
    final m2 = await send(members: members, text: 'третье');
    Future<bool> spent(Wire w, {int epochShift = 0}) => peer.isSpentPosition(
      roomId: room,
      senderDeviceId: me,
      epoch: w.epoch + epochShift,
      counter: w.counter,
    );

    expect(await spent(m1), isFalse, reason: 'ещё не открыто');
    expect(await deliver(peer, m2), 'третье');
    expect(await spent(m1), isFalse, reason: 'ключ отставшего бережётся');
    expect(await spent(m2), isTrue);
    expect(await deliver(peer, m1), 'второе');
    expect(await spent(m1), isTrue);
    expect(await spent(m1, epochShift: 1), isFalse, reason: 'чужое поколение');
  });

  test('§11.6 re-issuing a key is idempotent and never rewinds a chain in '
      'use', () async {
    // `gkeyreq` recovery re-sends the key freely, so a duplicate grant must be
    // harmless. A grant that OVERWROTE the receiving chain would rewind it and
    // orphan the keys held for messages still in flight.
    final members = [me, alice];
    await send(members: members, text: 'первое');
    final grant = grants[alice]!;
    final peer = await deviceHolding(grant);

    final m1 = await send(members: members, text: 'второе');
    expect(await deliver(peer, m1), 'второе');

    expect(
      await peer.acceptKeyGrant(
        roomId: room,
        senderDeviceId: me,
        epoch: grant.epoch,
        counter: grant.counter,
        chainKey: grant.chainKey,
        nowMs: clock,
      ),
      isFalse,
      reason: 'a duplicate grant must be ignored, not applied',
    );

    // The chain is still where consumption left it, and the next message opens.
    final m2 = await send(members: members, text: 'третье');
    expect(await deliver(peer, m2), 'третье');
  });

  test('a key is granted at its CURRENT position, never rewound to the '
      'start', () async {
    // A grant that always started at zero would hand the whole generation to
    // anyone who asked — including a member re-keyed later after losing theirs.
    final members = [me, alice];
    await send(members: members, text: 'первое');
    final early = await send(members: members, text: 'второе');
    await send(members: members, text: 'третье');

    final late = (await mgr.keyGrantFor(roomId: room))!;
    expect(late.counter, 3);
    expect(
      await peek(await deviceHolding(late), early),
      isNull,
      reason: 'a chain handed over at 3 must not reach back to 1',
    );
  });

  test('§11.5 a ciphertext cannot be moved to another generation', () async {
    final members = [me, alice];
    final m = await send(members: members, text: 'первое');
    final peer = await deviceHolding(grants[alice]!);
    expect(
      await peek(peer, (
        nonceB64: m.nonceB64,
        ciphertextB64: m.ciphertextB64,
        epoch: m.epoch + 1,
        counter: m.counter,
        rotated: null,
      )),
      isNull,
    );
  });

  test('an absurd counter is refused rather than ratcheted towards', () async {
    await send(members: [me, alice], text: 'первое');
    final peer = await deviceHolding(grants[alice]!);
    expect(
      await peer.openInbound(
        roomId: room,
        senderDeviceId: me,
        epoch: grants[alice]!.epoch,
        counter: grants[alice]!.counter + RoomKeyChain.maxSkip + 1,
      ),
      isNull,
    );
  });

  test('hygiene: a generation rotates on age and on message count', () async {
    await send(members: [me, alice], text: 'первое');
    final born = (await mgr.keyGrantFor(roomId: room))!.epoch;

    clock += RoomKeyManager.maxGenerationAgeMs + 1;
    final aged = await send(members: [me, alice], text: 'позже');
    expect(aged.rotated, RoomKeyManager.rotateReasonAge);
    expect(aged.epoch, born + 1);

    // Exhaustion: pretend the chain reached its ceiling.
    await db.roomSendKeyPut(
      roomId: room,
      epoch: aged.epoch,
      chainKey: RoomKeyChain.randomKey(),
      counter: RoomKeyManager.maxGenerationMessages,
      createdAtMs: clock,
    );
    final exhausted = await send(members: [me, alice], text: 'ещё');
    expect(exhausted.rotated, RoomKeyManager.rotateReasonExhausted);
  });

  test('rotation clears delivery, so the new key is owed to everyone', () async {
    final members = [me, alice, bob];
    await send(members: members, text: 'первое');
    expect(
      await mgr.recipientsMissingKey(
        roomId: room,
        memberDeviceIds: [alice, bob],
      ),
      isEmpty,
    );

    clock += 1000;
    await send(members: [me, alice], text: 'после ухода bob');
    expect(
      await mgr.recipientsMissingKey(roomId: room, memberDeviceIds: [alice]),
      isEmpty,
      reason: 'alice was re-keyed as part of the send',
    );

    // A device that never received the current generation is owed it.
    expect(
      await mgr.recipientsMissingKey(
        roomId: room,
        memberDeviceIds: ['newcomer-dev'],
      ),
      ['newcomer-dev'],
    );
  });

  test('§11.8 an interrupted rotation leaves nothing half-applied', () async {
    // A rotation that stored the new chain but not the new snapshot would
    // rotate again on every send, forever. One transaction is what prevents it;
    // this asserts the parts move together.
    await send(members: [me, alice], text: 'первое');
    clock += 1000;
    await mgr.rotate(
      roomId: room,
      members: RoomKeyManager.canonicalMembers([me, alice, bob]),
      nowMs: clock,
    );

    final row = await db.roomSendKeyGet(roomId: room);
    expect(row!['epoch'], 2);
    expect(row['counter'], 0);
    expect(await db.roomMemberSnapshotGet(roomId: room), [alice, bob, me]);
    expect(
      await db.roomKeyDeliveredEpoch(roomId: room, peerDeviceId: alice),
      isNull,
      reason: 'the new generation is owed to everyone again',
    );

    // The next send re-keys but does NOT rotate a second time.
    final next = await send(members: [me, alice, bob], text: 'после');
    expect(next.rotated, isNull);
  });

  test('a send whose slot was overtaken by a rotation cannot commit', () async {
    // Two sends racing with a membership change: the loser must not be able to
    // advance a generation it no longer belongs to.
    await send(members: [me, alice], text: 'первое');
    final stale =
        (await mgr.prepareSend(
              roomId: room,
              myDeviceId: me,
              memberDeviceIds: [me, alice],
              nowMs: clock,
            )
            as RoomSendReady)
        .slot;

    clock += 1000;
    await mgr.rotate(
      roomId: room,
      members: RoomKeyManager.canonicalMembers([me]),
      nowMs: clock,
    );
    expect(await mgr.commitSend(slot: stale), isFalse);
  });
}
