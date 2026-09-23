// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ДУБЛИ ОТ СИНХРОНИЗАЦИИ ИСТОРИИ (24.09.2026).
//
// Владелец: «на ПК многие сообщения через какое-то время продублировались».
// Входящее личное сообщение лежит под `event_id = msgId` — id КОНВЕРТА реле,
// а у каждого устройства свой конверт. Синхронизация истории между своими
// устройствами сверяла только `event_id`, и копия с телефона ложилась на ПК
// второй раз. Здесь проверяются обе части исправления: точная сверка по
// логическому id и разовая чистка налипших дублей.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secretly_app/storage/app_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

Future<ffi.Database> _raw(String path) {
  ffi.sqfliteFfiInit();
  return ffi.databaseFactoryFfi.openDatabase(path);
}

Future<void> _events(ffi.Database db) => db.execute('''
CREATE TABLE events (
  event_id TEXT PRIMARY KEY,
  convo_id TEXT NOT NULL,
  type TEXT NOT NULL,
  payload_event_id TEXT,
  read_at_ms INTEGER
);
''');

Future<void> _put(
  ffi.Database db,
  String id,
  String convo,
  String? payload, {
  String type = 'msg',
  int? readAt,
}) => db.insert('events', {
  'event_id': id,
  'convo_id': convo,
  'type': type,
  'payload_event_id': payload,
  'read_at_ms': readAt,
});

Future<List<String>> _ids(ffi.Database db) async => (await db.rawQuery(
  'SELECT event_id FROM events ORDER BY rowid;',
)).map((r) => r['event_id'] as String).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('разовая чистка', () {
    late Directory dir;
    late ffi.Database db;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('dedupe');
      db = await _raw(p.join(dir.path, 'x.db'));
      await _events(db);
    });

    tearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });

    test('🔴 убирает копию, оставляет принятое вживую', () async {
      // Обычный случай: ПК принял вживую (конверт A, прочитано), потом
      // синхронизация принесла то же сообщение под ключом телефона (B).
      await _put(db, 'relayA', 'peer1', 'P1', readAt: 1000);
      await _put(db, 'relayB', 'peer1', 'P1');
      final removed = await AppDb.dedupeEventsByPayload(db);
      expect(removed, 1);
      expect(await _ids(db), ['relayA']);
    });

    test('🔴 прочитанное не становится непрочитанным', () async {
      // Обратный порядок: сначала копия из истории (не прочитана), потом
      // живая, которую человек прочёл. Остаётся первая, но отметка прочтения
      // переносится — иначе счётчик непрочитанного подскочил бы.
      await _put(db, 'hist', 'peer1', 'P2');
      await _put(db, 'live', 'peer1', 'P2', readAt: 2000);
      await AppDb.dedupeEventsByPayload(db);
      final rows = await db.rawQuery('SELECT event_id, read_at_ms FROM events;');
      expect(rows, hasLength(1));
      expect(rows.single['event_id'], 'hist');
      expect(rows.single['read_at_ms'], 2000);
    });

    test('🔴 НЕ трогает то, что дублем не является', () async {
      // Тот же логический id в ДРУГОЙ переписке, другого типа, без id вовсе
      // и просто одиночное сообщение — всё это разные вещи, и чистка обязана
      // пройти мимо. Ошибка здесь — это удалённая чужая переписка.
      await _put(db, 'a', 'peer1', 'P1');
      await _put(db, 'b', 'peer2', 'P1');
      await _put(db, 'c', 'peer1', 'P1', type: 'sys');
      await _put(db, 'd', 'peer1', null);
      await _put(db, 'e', 'peer1', null);
      await _put(db, 'f', 'peer1', '');
      await _put(db, 'g', 'peer1', '');
      await _put(db, 'h', 'peer1', 'P3');
      final removed = await AppDb.dedupeEventsByPayload(db);
      expect(removed, 0);
      expect(await _ids(db), ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']);
    });

    test('повторный запуск ничего не удаляет', () async {
      await _put(db, 'x1', 'peer1', 'P9');
      await _put(db, 'x2', 'peer1', 'P9');
      await _put(db, 'x3', 'peer1', 'P9');
      expect(await AppDb.dedupeEventsByPayload(db), 2);
      expect(await AppDb.dedupeEventsByPayload(db), 0);
      expect(await _ids(db), ['x1']);
    });
  });

  group('миграция 68', () {
    test('🔴 чистит дубли в настоящей цепочке миграций', () async {
      final dir = await Directory.systemTemp.createTemp('mig68');
      final db = await _raw(p.join(dir.path, 'old.db'));
      try {
        await _events(db);
        await _put(db, 'relayA', 'peer1', 'P1', readAt: 1);
        await _put(db, 'relayB', 'peer1', 'P1');
        await AppDb.runMigrationsForTest(db, 67, 68);
        expect(await _ids(db), ['relayA']);
        expect(AppDb.debugLastPayloadDedupeRemoved, 1);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    });

    test('🔴 база без таблицы сообщений всё равно открывается', () async {
      // Падение в цепочке миграций — это база, которая не открывается, то
      // есть потеря переписки. Чистка не обязательна и не имеет права валить.
      final dir = await Directory.systemTemp.createTemp('mig68b');
      final db = await _raw(p.join(dir.path, 'old.db'));
      try {
        await AppDb.runMigrationsForTest(db, 67, 68);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    });
  });

  group('сверка при импорте истории', () {
    test('🔴 сообщение узнаётся по логическому id, а не по ключу строки', () async {
      final db = await AppDb.openForTesting();
      await db.insertEvent(
        eventId: 'relay-envelope-on-desktop',
        convoId: 'peer1',
        type: 'msg',
        senderDeviceId: 'dev-peer',
        ciphertextB64: 'AA==',
        createdAtMs: 1,
        payloadEventId: 'P1',
      );
      expect(
        await db.eventExistsForPayload(convoId: 'peer1', payloadEventId: 'P1'),
        isTrue,
      );
      // Ключ строки у телефона другой — именно поэтому прежняя сверка
      // промахивалась.
      expect(await db.eventGet('relay-envelope-on-phone'), isNull);
      // Та же id в ДРУГОЙ переписке — это не то же сообщение.
      expect(
        await db.eventExistsForPayload(convoId: 'peer2', payloadEventId: 'P1'),
        isFalse,
      );
      expect(
        await db.eventExistsForPayload(convoId: 'peer1', payloadEventId: '  '),
        isFalse,
      );
    });

    test('🔴 импорт сверяет логический id ДО записи', () {
      // Приватный путь `_applyPeerHistoryChunk` поднять без всего приложения
      // нельзя, поэтому проверяется порядок в самом исходнике: сверка стоит
      // раньше записи, и при сбое сверки событие пропускается, а не пишется.
      final src = File('lib/app/app_controller.dart').readAsStringSync();
      final start = src.indexOf('Future<void> _applyPeerHistoryChunk(');
      expect(start, greaterThan(0));
      final body = src.substring(start, start + 9000);
      final check = body.indexOf('eventExistsForPayload(');
      final write = body.indexOf('await db.insertEvent(');
      expect(check, greaterThan(0), reason: 'импорт не сверяет логический id');
      expect(check, lessThan(write), reason: 'сверка стоит после записи');
    });
  });
}
