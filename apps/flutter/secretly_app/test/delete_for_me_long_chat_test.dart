// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/storage/app_db.dart';

// 🔴 DF-1 (17.09.2026): «удалить у себя» в длинной переписке.
//
// Принадлежность чату проверялась по 5 000 самых СТАРЫХ событий, поэтому в
// переписке длиннее свежее сообщение не находилось и не удалялось — молча.

Future<int> _count(AppDb db, String where, [List<Object?>? args]) async {
  final rows = await db.rawQueryForTesting(
    'SELECT COUNT(*) c FROM events WHERE $where',
    args,
  );
  return (rows.first['c'] as num).toInt();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 свежее сообщение удаляется и в переписке длиннее 5 000', () async {
    final db = await AppDb.openForTesting();
    addTearDown(db.close);
    final controller = AppController()
      ..seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );
    await db.rawInsertForTesting(
      'WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n '
      'WHERE i < 5100) '
      'INSERT INTO events(event_id, convo_id, type, sender_device_id, '
      'ciphertext_b64, created_at_ms) '
      "SELECT 'e-' || i, 'friend-1', 'msg', 'peer', 'AA==', i FROM n",
    );
    expect(await _count(db, "convo_id = 'friend-1'"), 5100);

    await controller.deleteEventsLocal(
      convoId: 'friend-1',
      eventIds: const ['e-5100', 'e-1'],
    );

    expect(await _count(db, "event_id IN ('e-5100', 'e-1')"), 0);
    expect(await _count(db, "convo_id = 'friend-1'"), 5098);
  });

  test('событие из другой переписки не трогается', () async {
    final db = await AppDb.openForTesting();
    addTearDown(db.close);
    final controller = AppController()
      ..seedRoomRuntimeForTesting(
        db: db,
        profileId: 'owner-1',
        deviceId: 'owner-device',
      );
    for (final (id, convo) in const [
      ('mine', 'friend-1'),
      ('theirs', 'other-1'),
    ]) {
      await db.insertEvent(
        eventId: id,
        convoId: convo,
        type: 'msg',
        senderDeviceId: 'peer',
        ciphertextB64: 'AA==',
        createdAtMs: 1,
      );
    }

    await controller.deleteEventsLocal(
      convoId: 'friend-1',
      eventIds: const ['mine', 'theirs'],
    );

    expect(await _count(db, "event_id = 'mine'"), 0);
    expect(await _count(db, "event_id = 'theirs'"), 1);
  });

  test('выделение длиннее предела параметров SQLite', () async {
    final db = await AppDb.openForTesting();
    addTearDown(db.close);
    await db.rawInsertForTesting(
      'WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n '
      'WHERE i < 1200) '
      'INSERT INTO events(event_id, convo_id, type, sender_device_id, '
      'ciphertext_b64, created_at_ms) '
      "SELECT 'e-' || i, 'friend-1', 'msg', 'peer', 'AA==', i FROM n",
    );
    final ids = [for (var i = 1; i <= 1200; i++) 'e-$i'];
    final found = await db.eventIdsInConvo(convoId: 'friend-1', eventIds: ids);
    expect(found, hasLength(1200));
    expect(
      await db.eventIdsInConvo(convoId: 'other-1', eventIds: ids),
      isEmpty,
    );
  });
}
