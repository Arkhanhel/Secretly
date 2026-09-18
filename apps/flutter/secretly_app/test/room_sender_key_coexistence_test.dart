// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ratchet/room_key_manager.dart';
import 'package:secretly_app/storage/app_db.dart';

/// F-ROOMSK-3 — a room containing ONE member who cannot read the sender-key
/// format must never produce a sender-key message.
///
/// 🔴 THIS IS THE TEST FOR THE 1.7.4+416 FIELD LOSS. A build shipped with
/// sending enabled; a peer on an older build did not understand `gmsg`, stored
/// it invisibly, ACKed it, and every room message was lost permanently, with no
/// self-healing and no way to stop it short of reinstalling.
///
/// The protection is deliberately built on PROOF rather than advertisement: a
/// member is promoted from the pairwise fanout to the sender key only after it
/// has sent a `gkeyack`, and only a build that understands the format can
/// produce one. An advertised capability could be stale or forged; an ack
/// cannot — it is carried by the pairwise ratchet, whose session is looked up
/// BY the sender device id, so producing one for a device means holding that
/// device's chain keys.
///
/// The chain that guarantees coexistence has eight links across three files. The
/// tests below pin the ones that decide whether messages survive. If someone
/// relaxes `recipientsMissingKey` back to "delivered" — which is exactly what
/// 416 shipped — these fail.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const author = 'author-dev';
  const modern = 'modern-dev'; // a build that understands `gmsg`
  const legacy = 'legacy-dev'; // an older build that does not — never acks
  const room = 'group:mixed';

  late Directory tmp;
  late AppDb db;
  late RoomKeyManager mgr;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('room_coexist');
    db = await AppDb.openForTesting(path: '${tmp.path}/author.db');
    mgr = RoomKeyManager(db);
  });

  tearDown(() async {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<RoomSendOutcome> trySend(int nowMs) => mgr.prepareSend(
        roomId: room,
        myDeviceId: author,
        memberDeviceIds: const [modern, legacy],
        nowMs: nowMs,
      );

  /// One send attempt exactly as the app performs it: try, and when blocked,
  /// hand the key to whoever is owed it so the NEXT message can use it.
  ///
  /// The order matters and is easy to get wrong: `prepareSend` is what creates
  /// (and rotates) a generation, so there is nothing to deliver or confirm
  /// before the first attempt. Marking delivery earlier silently does nothing —
  /// `roomKeyDeliveryConfirm` is an UPDATE over a row we created, which is also
  /// what stops a peer from registering itself.
  Future<RoomSendOutcome> attemptSend(int nowMs) async {
    final outcome = await trySend(nowMs);
    if (outcome is RoomSendBlocked) {
      final row = await db.roomSendKeyGet(roomId: room);
      final epoch = (row?['epoch'] as num?)?.toInt() ?? 0;
      for (final d in outcome.awaitingKey) {
        await db.roomKeyDeliveryMark(
          roomId: room,
          peerDeviceId: d,
          epoch: epoch,
          deliveredAtMs: nowMs,
        );
      }
    }
    return outcome;
  }

  /// What arriving `gkeyack` does. Only a build that understands the format can
  /// produce one, which is the whole basis of the gate.
  Future<void> memberAcks(String device, {required int nowMs}) async {
    final row = await db.roomSendKeyGet(roomId: room);
    final epoch = (row?['epoch'] as num?)?.toInt() ?? 0;
    await db.roomKeyDeliveryConfirm(
      roomId: room,
      peerDeviceId: device,
      epoch: epoch,
      confirmedAtMs: nowMs,
    );
  }

  group('one member who never acks holds the WHOLE room on pairwise', () {
    test(
      'REGRESSION 1.7.4+416: sending stays blocked forever, however many times '
      'we try and however long we wait',
      () async {
        var now = 1000;

        // The author does everything it possibly can, repeatedly: rotate,
        // deliver, retry. None of it can manufacture consent from a build that
        // does not speak the format.
        for (var attempt = 0; attempt < 25; attempt++) {
          final first = await attemptSend(now);
          expect(
            first,
            isA<RoomSendBlocked>(),
            reason: 'attempt $attempt sealed a gmsg a member cannot read',
          );
          expect(
            (first as RoomSendBlocked).awaitingKey,
            contains(legacy),
            reason: 'the silent member must always hold the room back',
          );

          // The capable member acks, as it would on every generation.
          await memberAcks(modern, nowMs: now);

          // Now the ONLY thing standing between us and a sender-key message is
          // the member that cannot read one. This is the steady state a real
          // mixed room lives in, and it must never resolve.
          final second = await trySend(now);
          expect(second, isA<RoomSendBlocked>());
          expect(
            (second as RoomSendBlocked).awaitingKey,
            equals(const [legacy]),
            reason: 'once the capable member is confirmed, only the silent one '
                'should remain — anything else means the gate lost track',
          );

          // Every fifth round, time moves past the generation's age bound so a
          // rotation happens and the whole dance repeats from scratch. A
          // rotation must not become a loophole.
          if (attempt % 5 == 4) {
            now += RoomKeyManager.maxGenerationAgeMs + 1;
          } else {
            now += 1000;
          }
        }
      },
    );

    test('the capable member being fully confirmed changes nothing', () async {
      const now = 1000;
      await attemptSend(now); // creates the generation and delivers the key
      await memberAcks(modern, nowMs: now);

      // Confirming the same member again — a duplicate ack, a re-issued key,
      // a retried delivery — must not accumulate into permission.
      await memberAcks(modern, nowMs: now + 1);
      await memberAcks(modern, nowMs: now + 2);

      expect(await trySend(now + 3), isA<RoomSendBlocked>());
    });

    test('DELIVERING the key to the silent member is not consent', () async {
      const now = 1000;
      // Mark it delivered as many times as you like: "we put it in the outbox"
      // was the 416 signal, and it says nothing about whether it can be read.
      for (var i = 0; i < 5; i++) {
        await attemptSend(now + i);
      }
      await memberAcks(modern, nowMs: now);

      final outcome = await trySend(now + 10);
      expect(outcome, isA<RoomSendBlocked>());
      expect((outcome as RoomSendBlocked).awaitingKey, contains(legacy));
    });
  });

  group('the gate opens the moment the proof arrives', () {
    test('once the last member acks, sending is allowed', () async {
      const now = 1000;
      expect(await attemptSend(now), isA<RoomSendBlocked>());
      await memberAcks(modern, nowMs: now);
      expect(await trySend(now), isA<RoomSendBlocked>());

      // The user updates their other phone; it now understands the format.
      await memberAcks(legacy, nowMs: now + 1);

      expect(
        await trySend(now + 2),
        isA<RoomSendReady>(),
        reason: 'the gate must not be permanently stuck — that would make the '
            'whole feature dead code and hide a real regression',
      );
    });

    test('and closes again for a member who has not acked the NEW generation',
        () async {
      var now = 1000;
      await attemptSend(now);
      await memberAcks(modern, nowMs: now);
      await memberAcks(legacy, nowMs: now);
      expect(await trySend(now), isA<RoomSendReady>());

      // Age forces a fresh generation. Consent is per generation: a key nobody
      // has yet is exactly as unreadable as a format nobody understands.
      now += RoomKeyManager.maxGenerationAgeMs + 1;
      await attemptSend(now);
      await memberAcks(modern, nowMs: now);

      final outcome = await trySend(now);
      expect(outcome, isA<RoomSendBlocked>());
      expect((outcome as RoomSendBlocked).awaitingKey, equals(const [legacy]));
    });
  });

  group('the failure direction is the safe one', () {
    test('a blocked send yields the devices to key, not an exception', () async {
      // The caller turns RoomSendBlocked into "send this one pairwise and hand
      // out the key for next time". If this ever threw instead, the message
      // would be lost rather than downgraded.
      final outcome = await trySend(1000);
      expect(outcome, isA<RoomSendBlocked>());
      final blocked = outcome as RoomSendBlocked;
      expect(blocked.awaitingKey, containsAll(const [modern, legacy]));
      expect(blocked.roomId, room);
    });

    test('a room whose members never confirm never advances its chain',
        () async {
      // Nothing may be consumed from the sending chain while blocked: a
      // position spent without a readable message is a gap every member must
      // later skip over.
      final before = await db.roomSendKeyGet(roomId: room);
      for (var i = 0; i < 5; i++) {
        expect(await attemptSend(1000 + i), isA<RoomSendBlocked>());
      }
      final after = await db.roomSendKeyGet(roomId: room);
      expect(
        (after?['counter'] as num?)?.toInt() ?? 0,
        equals((before?['counter'] as num?)?.toInt() ?? 0),
      );
    });
  });
}
