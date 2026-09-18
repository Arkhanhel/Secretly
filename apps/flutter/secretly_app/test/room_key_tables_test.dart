// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

/// Storage for the room sender key (docs/TZ_ROOM_SENDER_KEY_2026-07-29.md фаза 2).
///
/// The schema tests guard against a table added to only ONE of the two schema
/// paths — a classic way to ship a feature that works for existing users and
/// crashes for new ones. The accessor tests pin the properties whose violation
/// means a departed member keeps reading, or a member silently stops receiving.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List key(int b) => Uint8List.fromList(List.filled(32, b));

  const roomKeyTables = <String>[
    'room_send_keys',
    'room_recv_keys',
    'room_skipped_keys',
    'room_key_delivery',
    'room_member_snapshot',
  ];

  test('a freshly created database has every room-key table', () async {
    final db = await AppDb.openForTesting();
    for (final table in roomKeyTables) {
      final rows = await db.rawQueryForTesting(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [table],
      );
      expect(
        rows,
        isNotEmpty,
        reason: '$table is missing from the fresh schema',
      );
    }
    await db.close();
  });

  test('a chain key survives storage byte for byte', () async {
    // A BLOB that came back mangled would be a decrypt failure with no visible
    // cause — the hardest kind of bug to trace back to storage.
    final db = await AppDb.openForTesting();
    final chain = Uint8List.fromList(List.generate(32, (i) => (i * 7) % 256));
    await db.roomSendKeyPut(
      roomId: 'group:r1',
      epoch: 1,
      chainKey: chain,
      counter: 0,
      createdAtMs: 100,
    );
    final row = await db.roomSendKeyGet(roomId: 'group:r1');
    expect(row!['chain_key'], equals(chain));
    expect(row['epoch'], 1);
    await db.close();
  });

  test(
    'advancing a stale generation is refused — a rotation must not be undone',
    () async {
      // Send path: read chain → encrypt → write back. If a rotation lands in
      // that gap, an unguarded write-back would reinstate the generation a
      // departed member still holds. The epoch guard makes that a no-op.
      final db = await AppDb.openForTesting();
      await db.roomSendKeyPut(
        roomId: 'group:r1',
        epoch: 1,
        chainKey: key(1),
        counter: 0,
        createdAtMs: 100,
      );
      // A rotation happens (member left).
      await db.roomSendKeyPut(
        roomId: 'group:r1',
        epoch: 2,
        chainKey: key(2),
        counter: 0,
        createdAtMs: 200,
      );
      // The in-flight send still holds epoch 1 and tries to write back.
      final advanced = await db.roomSendKeyAdvance(
        roomId: 'group:r1',
        epoch: 1,
        nextChainKey: key(99),
        nextCounter: 1,
      );
      expect(advanced, isFalse);

      final row = await db.roomSendKeyGet(roomId: 'group:r1');
      expect(row!['epoch'], 2);
      expect(row['chain_key'], equals(key(2)));

      // The current generation still advances normally.
      expect(
        await db.roomSendKeyAdvance(
          roomId: 'group:r1',
          epoch: 2,
          nextChainKey: key(3),
          nextCounter: 1,
        ),
        isTrue,
      );
      expect((await db.roomSendKeyGet(roomId: 'group:r1'))!['counter'], 1);
      await db.close();
    },
  );

  test('generations of one sender coexist — in-flight messages survive a '
      'rotation', () async {
    final db = await AppDb.openForTesting();
    for (final e in [1, 2]) {
      await db.roomRecvKeyPut(
        roomId: 'group:r1',
        senderDeviceId: 'devA',
        epoch: e,
        chainKey: key(e),
        counter: 0,
        updatedAtMs: 100,
      );
    }
    expect(
      (await db.roomRecvKeyGet(
        roomId: 'group:r1',
        senderDeviceId: 'devA',
        epoch: 1,
      ))!['chain_key'],
      equals(key(1)),
    );
    expect(
      (await db.roomRecvKeyGet(
        roomId: 'group:r1',
        senderDeviceId: 'devA',
        epoch: 2,
      ))!['chain_key'],
      equals(key(2)),
    );
    await db.close();
  });

  test('forgetting a departed member drops their chains AND their skipped '
      'keys', () async {
    // Leaving one behind would leave a readable hole in a room they were
    // removed from.
    final db = await AppDb.openForTesting();
    await db.roomRecvKeyPut(
      roomId: 'group:r1',
      senderDeviceId: 'gone',
      epoch: 1,
      chainKey: key(1),
      counter: 0,
      updatedAtMs: 100,
    );
    await db.roomSkippedKeyPut(
      roomId: 'group:r1',
      senderDeviceId: 'gone',
      epoch: 1,
      counter: 5,
      messageKey: key(5),
      createdAtMs: 100,
    );
    // A different member must be untouched.
    await db.roomRecvKeyPut(
      roomId: 'group:r1',
      senderDeviceId: 'stays',
      epoch: 1,
      chainKey: key(7),
      counter: 0,
      updatedAtMs: 100,
    );

    await db.roomRecvKeysForget(roomId: 'group:r1', senderDeviceId: 'gone');

    expect(
      await db.roomRecvKeyGet(
        roomId: 'group:r1',
        senderDeviceId: 'gone',
        epoch: 1,
      ),
      isNull,
    );
    expect(
      await db.roomSkippedKeyGet(
        roomId: 'group:r1',
        senderDeviceId: 'gone',
        epoch: 1,
        counter: 5,
      ),
      isNull,
    );
    expect(
      await db.roomRecvKeyGet(
        roomId: 'group:r1',
        senderDeviceId: 'stays',
        epoch: 1,
      ),
      isNotNull,
    );
    await db.close();
  });

  test('a skipped key is read without being consumed, and the first key for a '
      'position wins', () async {
    // Read-and-delete would let anyone destroy a legitimate key by posting one
    // corrupt ciphertext at that position; overwrite-on-conflict would let them
    // replace it. Both are message loss on demand.
    final db = await AppDb.openForTesting();
    await db.roomSkippedKeyPut(
      roomId: 'group:r1',
      senderDeviceId: 'devA',
      epoch: 1,
      counter: 3,
      messageKey: key(3),
      createdAtMs: 100,
    );
    await db.roomSkippedKeyPut(
      roomId: 'group:r1',
      senderDeviceId: 'devA',
      epoch: 1,
      counter: 3,
      messageKey: key(66),
      createdAtMs: 200,
    );

    Future<Uint8List?> read() => db.roomSkippedKeyGet(
      roomId: 'group:r1',
      senderDeviceId: 'devA',
      epoch: 1,
      counter: 3,
    );

    expect(await read(), equals(key(3)));
    // Still there after a failed attempt to use it.
    expect(await read(), equals(key(3)));

    await db.roomSkippedKeyDelete(
      roomId: 'group:r1',
      senderDeviceId: 'devA',
      epoch: 1,
      counter: 3,
    );
    expect(await read(), isNull);
    await db.close();
  });

  test('skipped keys age out on the same 7-day horizon as the pairwise '
      'store', () async {
    final db = await AppDb.openForTesting();
    for (final (c, at) in [(1, 100), (2, 5000)]) {
      await db.roomSkippedKeyPut(
        roomId: 'group:r1',
        senderDeviceId: 'devA',
        epoch: 1,
        counter: c,
        messageKey: key(c),
        createdAtMs: at,
      );
    }
    await db.roomSkippedKeysPrune(olderThanMs: 1000);
    expect(
      await db.roomSkippedKeyGet(
        roomId: 'group:r1',
        senderDeviceId: 'devA',
        epoch: 1,
        counter: 1,
      ),
      isNull,
    );
    expect(
      await db.roomSkippedKeyGet(
        roomId: 'group:r1',
        senderDeviceId: 'devA',
        epoch: 1,
        counter: 2,
      ),
      isNotNull,
    );
    await db.close();
  });

  test(
    'a late confirmation for an OLD generation never masks a newer one',
    () async {
      // If the recorded epoch could go backwards it would be fine; the danger is
      // the opposite — a stale mark must not be able to LOWER the record either,
      // because "peer already has epoch 2" is what suppresses re-sending the
      // key. Getting this wrong means one member silently stops reading forever.
      final db = await AppDb.openForTesting();
      await db.roomKeyDeliveryMark(
        roomId: 'group:r1',
        peerDeviceId: 'devB',
        epoch: 2,
        deliveredAtMs: 200,
      );
      await db.roomKeyDeliveryMark(
        roomId: 'group:r1',
        peerDeviceId: 'devB',
        epoch: 1,
        deliveredAtMs: 100,
      );
      expect(
        await db.roomKeyDeliveredEpoch(roomId: 'group:r1', peerDeviceId: 'devB'),
        2,
      );

      // Forward still moves.
      await db.roomKeyDeliveryMark(
        roomId: 'group:r1',
        peerDeviceId: 'devB',
        epoch: 3,
        deliveredAtMs: 300,
      );
      expect(
        await db.roomKeyDeliveredEpoch(roomId: 'group:r1', peerDeviceId: 'devB'),
        3,
      );

      // Never delivered reads as null, not 0 — "no record" and "generation 0"
      // must not be confused.
      expect(
        await db.roomKeyDeliveredEpoch(
          roomId: 'group:r1',
          peerDeviceId: 'never',
        ),
        isNull,
      );

      await db.roomKeyDeliveryForget(
        roomId: 'group:r1',
        peerDeviceId: 'devB',
      );
      expect(
        await db.roomKeyDeliveredEpoch(roomId: 'group:r1', peerDeviceId: 'devB'),
        isNull,
      );
      await db.close();
    },
  );

  test(
    'membership is compared by content, not by the order the server sent it',
    () async {
      // Membership change is the trigger to rotate. If a reordered member list
      // read as "changed", the room would re-key on every sync — an expensive
      // key broadcast storm for nothing.
      final db = await AppDb.openForTesting();
      await db.roomMemberSnapshotPut(
        roomId: 'group:r1',
        deviceIds: ['c', 'a', 'b'],
        updatedAtMs: 100,
      );
      final first = await db.roomMemberSnapshotGet(roomId: 'group:r1');
      expect(first, ['a', 'b', 'c']);

      await db.roomMemberSnapshotPut(
        roomId: 'group:r1',
        deviceIds: ['b', 'c', 'a', 'a', '  '],
        updatedAtMs: 200,
      );
      expect(await db.roomMemberSnapshotGet(roomId: 'group:r1'), first);

      // A genuine change is still visible.
      await db.roomMemberSnapshotPut(
        roomId: 'group:r1',
        deviceIds: ['a', 'b'],
        updatedAtMs: 300,
      );
      expect(await db.roomMemberSnapshotGet(roomId: 'group:r1'), ['a', 'b']);

      // No snapshot yet is an empty list, so the first keying reads as a change.
      expect(await db.roomMemberSnapshotGet(roomId: 'group:none'), isEmpty);
      await db.close();
    },
  );

  test(
    'F-ROOMSK-6: the diagnostics summary counts who still OWES a confirmation',
    () async {
      // The number a field tester needs: while anyone is owed, the room sends
      // over the PAIRWISE fanout. Only when every delivered device has acked
      // does the sender key engage.
      final db = await AppDb.openForTesting();
      await db.roomSendKeyPut(
        roomId: 'group:diag',
        epoch: 2,
        chainKey: key(9),
        counter: 5,
        createdAtMs: 100,
      );
      for (final dev in ['devA', 'devB']) {
        await db.roomKeyDeliveryMark(
          roomId: 'group:diag',
          peerDeviceId: dev,
          epoch: 2,
          deliveredAtMs: 100,
        );
      }
      // Only one of the two confirmed.
      await db.roomKeyDeliveryConfirm(
        roomId: 'group:diag',
        peerDeviceId: 'devA',
        epoch: 2,
        confirmedAtMs: 101,
      );

      var rows = await db.roomSenderKeyDiagnostics();
      expect(rows, hasLength(1));
      expect(rows.first['epoch'], 2);
      expect(rows.first['counter'], 5);
      expect(rows.first['delivered'], 2);
      expect(
        rows.first['confirmed'],
        1,
        reason: 'delivered is not confirmed — that gap is the whole point',
      );

      await db.roomKeyDeliveryConfirm(
        roomId: 'group:diag',
        peerDeviceId: 'devB',
        epoch: 2,
        confirmedAtMs: 102,
      );
      rows = await db.roomSenderKeyDiagnostics();
      expect(rows.first['confirmed'], 2);

      await db.close();
    },
  );
}
