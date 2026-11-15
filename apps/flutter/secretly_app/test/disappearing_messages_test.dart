// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Исчезающие сообщения у всех участников — шаг 2 ТЗ 22.10.2026 (приём,
// схема, уборка). Проверяет договоры, на которых держится совместимость со
// старыми сборками: необязательное поле `exp`, скрытый префикс команды,
// колонки с NULL, отсчёт от прочтения.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/messages/disappearing_flags.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/security/restore_payload_validation.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/storage/safe_backup_snapshot_contract.dart';
import 'package:secretly_app/sync/peer_history_protocol.dart';

List<int> _encode(Map<String, Object?> map) => utf8.encode(jsonEncode(map));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('exp в полезной нагрузке', () {
    test('текст, вложение и стикер несут exp и читают его обратно', () {
      final msg = MsgEventV1(eventId: 'e1', text: 'hi', exp: 300);
      final att = AttachmentEventV1(
        eventId: 'e2',
        blobId: 'b',
        fileKeyB64: 'k',
        sizeBytes: 1,
        exp: 3600,
      );
      final sticker = StickerEventV1(
        eventId: 'e3',
        packId: 'p',
        packVersion: 1,
        stickerId: 's',
        exp: 86400,
      );
      final payload = E2ePayloadV1(
        senderDeviceId: 'dev:a',
        createdAtMs: 1,
        events: [msg, att, sticker],
      );
      final decoded = E2ePayloadV1.decode(payload.encode());
      expect((decoded.events[0] as MsgEventV1).exp, 300);
      expect((decoded.events[1] as AttachmentEventV1).exp, 3600);
      expect((decoded.events[2] as StickerEventV1).exp, 86400);
    });

    test('без exp ключ не пишется — провод старых сборок не меняется', () {
      final json = MsgEventV1(eventId: 'e1', text: 'hi').toJson();
      expect(json.containsKey('exp'), isFalse);
      final zero = MsgEventV1(eventId: 'e1', text: 'hi', exp: 0).toJson();
      expect(zero.containsKey('exp'), isFalse);
    });

    test('мусор в exp — сообщение без срока, а не падение', () {
      for (final garbage in <Object?>['300', -5, 0, 1e12, 'x', true, null]) {
        final bytes = _encode({
          'v': 1,
          'sender_device_id': 'dev:a',
          'created_at_ms': 1,
          'events': [
            {'type': 'msg', 'event_id': 'e1', 'text': 'hi', 'exp': garbage},
          ],
        });
        final decoded = E2ePayloadV1.decode(bytes);
        expect(decoded.events, hasLength(1), reason: '$garbage');
        expect((decoded.events.single as MsgEventV1).exp, isNull,
            reason: '$garbage');
      }
    });

    test('предел — год', () {
      expect(disappearSecondsFromJson(kDisappearMaxSeconds), kDisappearMaxSeconds);
      expect(disappearSecondsFromJson(kDisappearMaxSeconds + 1), isNull);
      expect(disappearSecondsFromJson(1), 1);
    });
  });

  group('команда смены таймера', () {
    test('скрыта от старых сборок: префикс __secretly_', () {
      final cmd = buildConvoTimerCommand(
        convoId: 'profile-b',
        seconds: 300,
        setAtMs: 1000,
      );
      expect(cmd.startsWith('__secretly_'), isTrue);
      expect(isHiddenMessageControlText(cmd), isTrue);
      expect(isConvoTimerCommandText(cmd), isTrue);
    });

    test('круговая сборка/разбор, выключение — seconds null', () {
      final on = parseConvoTimerCommand(
        buildConvoTimerCommand(convoId: 'c', seconds: 3600, setAtMs: 7),
      )!;
      expect(on.convoId, 'c');
      expect(on.seconds, 3600);
      expect(on.setAtMs, 7);
      final off = parseConvoTimerCommand(
        buildConvoTimerCommand(convoId: 'c', seconds: null, setAtMs: 8),
      )!;
      expect(off.seconds, isNull);
    });

    test('мусор не разбирается или даёт «выключен»', () {
      expect(parseConvoTimerCommand('__secretly_convo_timer_v1__:'), isNull);
      expect(parseConvoTimerCommand('__secretly_convo_timer_v1__:!!!'), isNull);
      expect(parseConvoTimerCommand('plain text'), isNull);
      final noConvo = base64Url.encode(utf8.encode(jsonEncode({'v': 1})));
      expect(
        parseConvoTimerCommand('__secretly_convo_timer_v1__:$noConvo'),
        isNull,
      );
      final tooLong = base64Url.encode(
        utf8.encode(jsonEncode({'convoId': 'c', 'seconds': 99999999999})),
      );
      expect(
        parseConvoTimerCommand('__secretly_convo_timer_v1__:$tooLong')!.seconds,
        isNull,
      );
    });

    test('зеркало состояния чата несёт таймер и не считается пустым', () {
      final text = buildSelfMirrorConvoStateCommand(
        convoId: 'c',
        appliedAtMs: 5,
        disappearSet: true,
        disappearSeconds: 600,
      );
      final parsed = parseSelfMirrorConvoStateCommand(text)!;
      expect(parsed.disappearSet, isTrue);
      expect(parsed.disappearSeconds, 600);
      expect(parsed.isEmpty, isFalse);
      final off = parseSelfMirrorConvoStateCommand(
        buildSelfMirrorConvoStateCommand(
          convoId: 'c',
          appliedAtMs: 5,
          disappearSet: true,
          disappearSeconds: null,
        ),
      )!;
      expect(off.disappearSet, isTrue);
      expect(off.disappearSeconds, isNull);
      // Старое зеркало без поля — как раньше.
      final legacy = parseSelfMirrorConvoStateCommand(
        buildSelfMirrorConvoStateCommand(convoId: 'c', appliedAtMs: 5, muted: true),
      )!;
      expect(legacy.disappearSet, isFalse);
    });

    test('зеркала вложения и стикера несут exp', () {
      final att = parseSelfMirrorAttachmentCommand(
        buildSelfMirrorAttachmentCommand(
          convoId: 'c',
          msgEventId: 'm',
          blobId: 'b',
          fileKeyB64: 'k',
          sizeBytes: 1,
          createdAtMs: 1,
          exp: 120,
        ),
      )!;
      expect(att.exp, 120);
      final sticker = parseSelfMirrorStickerCommand(
        buildSelfMirrorStickerCommand(
          convoId: 'c',
          msgEventId: 'm',
          packId: 'p',
          packVersion: 1,
          stickerId: 's',
          createdAtMs: 1,
          exp: 60,
        ),
      )!;
      expect(sticker.exp, 60);
      final plain = parseSelfMirrorStickerCommand(
        buildSelfMirrorStickerCommand(
          convoId: 'c',
          msgEventId: 'm',
          packId: 'p',
          packVersion: 1,
          stickerId: 's',
          createdAtMs: 1,
        ),
      )!;
      expect(plain.exp, isNull);
    });
  });

  group('блок disappearing подписанного конфига', () {
    test('подписываемое сообщение совпадает с Rust побайтово', () {
      expect(
        disappearingSigningMessage(
          sendEnabled: true,
          sendShare: 10,
          expireEnabled: true,
          minBuild: 660,
          customMaxS: 2592000,
          issuedAtMs: 1760000000123,
        ),
        'secretly-disappearing-v1|true|10|true|660|2592000|1760000000123',
      );
    });

    test('непроверенный блок — умолчания: отправка выкл, удаление вкл', () {
      final flags = DisappearingFlags.fromConfigResponse(
        {
          'disappearing': {
            'send_enabled': true,
            'send_share': 100,
            'expire_enabled': false,
            'min_build': 660,
            'custom_max_s': 60,
          },
        },
        verified: false,
      );
      expect(flags, DisappearingFlags.defaults);
      expect(flags.sendEnabled, isFalse);
      expect(flags.expireEnabled, isTrue);
      expect(flags.minBuild, 0);
    });

    test('проверенный блок читается и зажимается', () {
      final flags = DisappearingFlags.fromConfigResponse(
        {
          'disappearing': {
            'send_enabled': true,
            'send_share': 150,
            'expire_enabled': false,
            'min_build': 660,
            'custom_max_s': 5,
          },
        },
        verified: true,
      );
      expect(flags.sendEnabled, isTrue);
      expect(flags.sendShare, 100);
      expect(flags.expireEnabled, isFalse);
      expect(flags.minBuild, 660);
      expect(flags.customMaxS, DisappearingFlags.customMinS);
    });

    test('доля отправки детерминирована по профилю', () {
      const flags = DisappearingFlags(sendEnabled: true, sendShare: 50);
      final a = flags.sendAllowedFor('profile-a');
      expect(flags.sendAllowedFor('profile-a'), a);
      expect(
        const DisappearingFlags(sendEnabled: true, sendShare: 100)
            .sendAllowedFor('profile-a'),
        isTrue,
      );
      expect(
        const DisappearingFlags(sendEnabled: false, sendShare: 100)
            .sendAllowedFor('profile-a'),
        isFalse,
      );
      expect(flags.sendAllowedFor(''), isFalse);
    });
  });

  group('синхронизация истории', () {
    test('поля срока необязательны и круговые', () {
      final ev = PeerHistoryChunkEvent(
        eventId: 'e',
        convoId: 'c',
        type: 'msg',
        senderDeviceId: 'd',
        createdAtMs: 1,
        payloadB64: 'AA==',
        disappearSeconds: 300,
        expiresAtMs: 5000,
      );
      final back = PeerHistoryChunkEvent.fromJson(ev.toJson())!;
      expect(back.disappearSeconds, 300);
      expect(back.expiresAtMs, 5000);
      final legacy = PeerHistoryChunkEvent.fromJson({
        'eventId': 'e',
        'convoId': 'c',
        'type': 'msg',
        'senderDeviceId': 'd',
        'createdAtMs': 1,
        'payloadB64': 'AA==',
      })!;
      expect(legacy.disappearSeconds, isNull);
      expect(legacy.expiresAtMs, isNull);
    });
  });

  group('миграция 69 на живой базе', () {
    Future<ffi.Database> raw(String path) {
      ffi.sqfliteFfiInit();
      return ffi.databaseFactoryFfi.openDatabase(path);
    }

    Future<List<String>> columns(ffi.Database db, String table) async =>
        (await db.rawQuery('PRAGMA table_info($table);'))
            .map((r) => r['name'] as String)
            .toList();

    Future<void> oldShape(ffi.Database db) async {
      await db.execute('''
CREATE TABLE events (
  event_id TEXT PRIMARY KEY,
  convo_id TEXT NOT NULL,
  type TEXT NOT NULL,
  sender_device_id TEXT NOT NULL,
  ciphertext_b64 TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  read_at_ms INTEGER
);
''');
      await db.execute('''
CREATE TABLE conversations (
  convo_id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  auto_delete_seconds INTEGER,
  last_event_at_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
      await db.insert('events', {
        'event_id': 'old1',
        'convo_id': 'peer',
        'type': 'msg',
        'sender_device_id': 'peer-dev',
        'ciphertext_b64': 'AA==',
        'created_at_ms': 1000,
        'read_at_ms': 2000,
      });
      await db.insert('conversations', {
        'convo_id': 'peer',
        'kind': '1to1',
        'auto_delete_seconds': 86400,
        'last_event_at_ms': 1000,
        'created_at_ms': 1,
        'updated_at_ms': 1,
      });
    }

    test('🔴 68 → 69: колонки добавлены, данные и автоудаление целы', () async {
      final dir = await Directory.systemTemp.createTemp('mig69');
      final db = await raw(p.join(dir.path, 'old.db'));
      try {
        await oldShape(db);
        await AppDb.runMigrationsForTest(db, 68, 69);
        expect(await columns(db, 'events'),
            containsAll(['disappear_seconds', 'expires_at_ms']));
        expect(await columns(db, 'conversations'), contains('disappear_seconds'));
        final ev = (await db.query('events')).single;
        expect(ev['event_id'], 'old1');
        expect(ev['read_at_ms'], 2000);
        expect(ev['disappear_seconds'], isNull);
        expect(ev['expires_at_ms'], isNull);
        final convo = (await db.query('conversations')).single;
        expect(convo['auto_delete_seconds'], 86400);
        expect(convo['disappear_seconds'], isNull);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    });

    test('🔴 повторный прогон безопасен (прерванное обновление)', () async {
      final dir = await Directory.systemTemp.createTemp('mig69r');
      final db = await raw(p.join(dir.path, 'old.db'));
      try {
        await oldShape(db);
        await AppDb.runMigrationsForTest(db, 68, 69);
        await AppDb.runMigrationsForTest(db, 68, 69);
        expect((await db.query('events')).single['event_id'], 'old1');
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    });

    test('🔴 база без таблиц открывается — миграция не падает', () async {
      final dir = await Directory.systemTemp.createTemp('mig69e');
      final db = await raw(p.join(dir.path, 'empty.db'));
      try {
        await AppDb.runMigrationsForTest(db, 68, 69);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    });

    test('откат и повторное обновление: прочитанное старой сборкой получает отсчёт',
        () async {
      final dir = await Directory.systemTemp.createTemp('mig69d');
      final db = await raw(p.join(dir.path, 'old.db'));
      try {
        await oldShape(db);
        await AppDb.runMigrationsForTest(db, 68, 69);
        // Новая сборка положила входящее со сроком, не прочитанное…
        await db.insert('events', {
          'event_id': 'timed',
          'convo_id': 'peer',
          'type': 'msg',
          'sender_device_id': 'peer-dev',
          'ciphertext_b64': 'AA==',
          'created_at_ms': 3000,
          'disappear_seconds': 60,
        });
        // …старая сборка после отката отметила его прочитанным без отсчёта…
        await db.update('events', {'read_at_ms': 10000},
            where: 'event_id = ?', whereArgs: ['timed']);
        // …и снова новая сборка.
        await AppDb.runMigrationsForTest(db, 68, 69);
        final row = (await db.query('events',
                where: 'event_id = ?', whereArgs: ['timed']))
            .single;
        expect(row['expires_at_ms'], 10000 + 60 * 1000);
        // Строка без срока не тронута.
        final plain = (await db.query('events',
                where: 'event_id = ?', whereArgs: ['old1']))
            .single;
        expect(plain['expires_at_ms'], isNull);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    });
  });

  group('база: схема и отсчёт', () {
    test('новые колонки есть, старые строки без срока не трогаются', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.insertEvent(
          eventId: 'plain',
          convoId: 'peer',
          type: 'msg',
          senderDeviceId: 'peer-dev',
          ciphertextB64: 'AA==',
          createdAtMs: 1000,
        );
        await db.markEventsReadByIds(['plain'], readAtMs: 2000);
        final row = (await db.eventGet('plain'))!;
        expect(row['disappear_seconds'], isNull);
        expect(row['expires_at_ms'], isNull);
        expect(await db.nextDisappearingExpiryMs(), isNull);
        expect(await db.listExpiredEvents(nowMs: 1 << 50), isEmpty);
      } finally {
        await db.close();
      }
    });

    test('входящее: отсчёт идёт от прочтения, не от получения', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.insertEvent(
          eventId: 'in1',
          convoId: 'peer',
          type: 'msg',
          senderDeviceId: 'peer-dev',
          ciphertextB64: 'AA==',
          createdAtMs: 1000,
          disappearSeconds: 60,
        );
        expect((await db.eventGet('in1'))!['expires_at_ms'], isNull);
        expect(await db.nextDisappearingExpiryMs(), isNull);

        await db.markEventsReadByIds(['in1'], readAtMs: 50000);
        final row = (await db.eventGet('in1'))!;
        expect(row['read_at_ms'], 50000);
        expect(row['expires_at_ms'], 50000 + 60 * 1000);
        expect(await db.nextDisappearingExpiryMs(), 110000);

        // Повторное прочтение отсчёт не сдвигает.
        await db.markEventsReadByIds(['in1'], readAtMs: 90000);
        expect((await db.eventGet('in1'))!['expires_at_ms'], 110000);
      } finally {
        await db.close();
      }
    });

    test('прочтение «до водораздела» тоже запускает отсчёт', () async {
      final db = await AppDb.openForTesting();
      try {
        for (var i = 0; i < 3; i++) {
          await db.insertEvent(
            eventId: 'w$i',
            convoId: 'peer',
            type: 'msg',
            senderDeviceId: 'peer-dev',
            ciphertextB64: 'AA==',
            createdAtMs: 1000 + i,
            disappearSeconds: 30,
          );
        }
        final marked = await db.markIncomingReadThrough(
          convoId: 'peer',
          selfDeviceId: 'me',
          upToMs: 1001,
          readAtMs: 7000,
        );
        expect(marked, 2);
        expect((await db.eventGet('w0'))!['expires_at_ms'], 37000);
        expect((await db.eventGet('w1'))!['expires_at_ms'], 37000);
        expect((await db.eventGet('w2'))!['expires_at_ms'], isNull);
      } finally {
        await db.close();
      }
    });

    test('своя копия: срок задан при вставке и истекает по списку', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.insertEvent(
          eventId: 'out1',
          convoId: 'peer',
          type: 'msg',
          senderDeviceId: 'me',
          ciphertextB64: 'AA==',
          createdAtMs: 1000,
          localState: 'sent',
          readAtMs: 1000,
          disappearSeconds: 5,
          expiresAtMs: 6000,
        );
        expect(await db.listExpiredEvents(nowMs: 5999), isEmpty);
        final due = await db.listExpiredEvents(nowMs: 6000);
        expect(due.map((r) => r['event_id']), ['out1']);
        await db.deleteEventsByIds(['out1']);
        expect(await db.eventGet('out1'), isNull);
        expect(await db.nextDisappearingExpiryMs(), isNull);
      } finally {
        await db.close();
      }
    });

    test(
        '🔴 резервная копия: без строк со сроком и без новых ключей — '
        'выпущенные сборки её восстанавливают', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.convoEnsure1to1(peerProfileId: 'peer');
        await db.convoSetDisappearSeconds(convoId: 'peer', disappearSeconds: 300);
        await db.insertEvent(
          eventId: 'plain',
          convoId: 'peer',
          type: 'msg',
          senderDeviceId: 'peer-dev',
          ciphertextB64: 'AA==',
          createdAtMs: 1000,
        );
        await db.insertEvent(
          eventId: 'timed',
          convoId: 'peer',
          type: 'msg',
          senderDeviceId: 'peer-dev',
          ciphertextB64: 'AA==',
          createdAtMs: 1001,
          disappearSeconds: 60,
        );
        final snapshot = await db.exportTables(
          kSafeBackupSnapshotTables,
          allowedColumnsByTable: kSafeBackupSnapshotColumnsByTable,
        );
        final events = snapshot['events']!;
        expect(events.map((r) => r['event_id']), ['plain']);
        for (final table in snapshot.keys) {
          for (final row in snapshot[table]!) {
            expect(row.containsKey('disappear_seconds'), isFalse,
                reason: table);
            expect(
              table == 'events' && row.containsKey('expires_at_ms'),
              isFalse,
            );
          }
        }
        // Проверка восстановления — та же, что у выпущенных сборок: список
        // разрешённых столбцов не расширялся.
        validateSafeBackupDbSnapshot(
          payloadName: 'test',
          dbSnapshot: snapshot.map((k, v) => MapEntry(k, v)),
        );
      } finally {
        await db.close();
      }
    });

    test('таймер чата хранится отдельно от локальной уборки', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.convoEnsure1to1(peerProfileId: 'peer');
        await db.convoSetAutoDeleteSeconds(
          convoId: 'peer',
          autoDeleteSeconds: 86400,
        );
        await db.convoSetDisappearSeconds(convoId: 'peer', disappearSeconds: 300);
        var row = (await db.convoGet('peer'))!;
        expect(row['auto_delete_seconds'], 86400);
        expect(row['disappear_seconds'], 300);
        await db.convoSetDisappearSeconds(convoId: 'peer', disappearSeconds: null);
        row = (await db.convoGet('peer'))!;
        expect(row['auto_delete_seconds'], 86400);
        expect(row['disappear_seconds'], isNull);
        // Ноль и отрицательное — «выключен».
        await db.convoSetDisappearSeconds(convoId: 'peer', disappearSeconds: 0);
        expect((await db.convoGet('peer'))!['disappear_seconds'], isNull);
      } finally {
        await db.close();
      }
    });
  });

  group('🔴 время смены таймера из будущего (11.11.2026)', () {
    const now = 1_800_000_000_000;
    test('обычное время не меняется', () {
      expect(trustedConvoTimerSetAtMs(now - 1000, now), now - 1000);
      expect(trustedConvoTimerSetAtMs(now, now), now);
      expect(
        trustedConvoTimerSetAtMs(now + kConvoTimerFutureSkewMs, now),
        now + kConvoTimerFutureSkewMs,
      );
    });

    test('спешащие часы и «2100 год» обрезаются до сейчас + 5 минут', () {
      expect(
        trustedConvoTimerSetAtMs(now + kConvoTimerFutureSkewMs + 1, now),
        now + kConvoTimerFutureSkewMs,
      );
      expect(
        trustedConvoTimerSetAtMs(4_102_444_800_000, now),
        now + kConvoTimerFutureSkewMs,
      );
    });

    test('после «смены из будущего» следующая честная смена через 6 минут побеждает', () {
      final forged = trustedConvoTimerSetAtMs(4_102_444_800_000, now);
      const later = now + 6 * 60 * 1000;
      expect(trustedConvoTimerSetAtMs(later, later) > forged, isTrue);
    });

    test('«время не указано» остаётся нулём', () {
      expect(trustedConvoTimerSetAtMs(0, now), 0);
      expect(trustedConvoTimerSetAtMs(-5, now), -5);
    });
  });
}
