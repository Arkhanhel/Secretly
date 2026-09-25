// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ПК НЕ ВИДЕЛ ПОЛОВИНЫ ПЕРЕПИСКИ (25.09.2026).
//
// Владелец: «десктоп не подтягивает половину смс, которые писал я через
// мобильную или писали мне, пока ПК был выключен, и на половину показывает
// непрочитанными, хотя я их прочитал». Журнал реле: за ночь истекли все 23
// копии его ответов — копии для своих устройств жили на сервере час. Здесь
// проверяются части исправления, которые можно поднять без всего приложения.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/diagnostics/diag_log.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/sync/peer_history_protocol.dart';
import 'package:secretly_app/sync/peer_history_service.dart';
import 'package:secretly_app/ui/desktop/services/desktop_diag_file_log.dart';
import 'package:secretly_app/ui/desktop/services/desktop_history_catch_up.dart';

const _hour = 60 * 60 * 1000;

Future<void> _msg(
  AppDb db,
  String id, {
  String convo = 'peer1',
  String sender = 'dev-peer',
  String type = 'msg',
  required int at,
  int? readAt,
  int? scheduledAt,
}) => db.insertEvent(
  eventId: id,
  convoId: convo,
  type: type,
  senderDeviceId: sender,
  ciphertextB64: 'AA==',
  createdAtMs: at,
  readAtMs: readAt,
  scheduledAtMs: scheduledAt,
);

Future<int?> _readAt(AppDb db, String id) async {
  final rows = await db.rawQueryForTesting(
    'SELECT read_at_ms FROM events WHERE event_id = ?',
    [id],
  );
  return (rows.first['read_at_ms'] as num?)?.toInt();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('срок копий для своих устройств', () {
    const hour = 60 * 60;
    const week = 7 * 24 * hour;

    test('🔴 копии сообщений, вложений, реакций, «прочитано» — неделя', () {
      for (final prefix in [
        '__secretly_self_mirror_msg_v1__:',
        kSelfMirrorAttachmentCommandPrefix,
        kSelfMirrorStickerCommandPrefix,
        kSelfMirrorReactionCommandPrefix,
        kSelfMirrorReadCommandPrefix,
        kSelfMirrorConvoStateCommandPrefix,
        kSelfMirrorFolderCommandPrefix,
      ]) {
        expect(
          AppController.selfMirrorTtlSecondsFor('${prefix}e30=', hour),
          week,
          reason: prefix,
        );
      }
    });

    test('квитанции моих сообщений — три дня: их больше всего', () {
      expect(
        AppController.selfMirrorTtlSecondsFor(
          '${kSelfMirrorReceiptCommandPrefix}e30=',
          hour,
        ),
        3 * 24 * hour,
      );
    });

    test('чужие служебные посылки и свой срок вызывающего не трогаются', () {
      // «Печатает», квитанции собеседнику и прочее — прежний час.
      expect(
        AppController.selfMirrorTtlSecondsFor('__secretly_typing_v1__:x', hour),
        hour,
      );
      // Вызов, выбравший свой срок, его и сохраняет.
      expect(
        AppController.selfMirrorTtlSecondsFor(
          '__secretly_self_mirror_msg_v1__:x',
          90,
        ),
        90,
      );
    });
  });

  group('прочитанность на ПК', () {
    late Directory dir;
    late AppDb db;
    setUp(() async {
      // Своя база на каждый тест: база «в памяти» общая на весь процесс.
      dir = await Directory.systemTemp.createTemp('readthrough');
      db = await AppDb.openForTesting(path: '${dir.path}/t.db');
    });
    tearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });

    test('🔴 водораздел помечает ВСЕ входящие до него — без предела 500', () async {
      for (var i = 0; i < 600; i++) {
        await _msg(db, 'in$i', at: 1000 + i);
      }
      await _msg(db, 'later', at: 5000);
      final marked = await db.markIncomingReadThrough(
        convoId: 'peer1',
        selfDeviceId: 'desk',
        upToMs: 1000 + 599,
        readAtMs: 9,
      );
      expect(marked, 600);
      expect(await _readAt(db, 'in0'), 9, reason: 'самое старое');
      expect(await _readAt(db, 'later'), isNull, reason: 'новее водораздела');
    });

    test('не трогает свои строки, чужую переписку и служебные', () async {
      await _msg(db, 'mine', sender: 'phone', at: 10);
      await _msg(db, 'other-convo', convo: 'peer2', at: 10);
      await _msg(db, 'system', type: 'sys', at: 10);
      await _msg(db, 'incoming', at: 10);
      final marked = await db.markIncomingReadThrough(
        convoId: 'peer1',
        selfDeviceId: 'desk',
        excludedSenderDeviceIds: const ['phone'],
        upToMs: 100,
        readAtMs: 9,
      );
      expect(marked, 1);
      expect(await _readAt(db, 'incoming'), 9);
      expect(await _readAt(db, 'mine'), isNull);
      expect(await _readAt(db, 'other-convo'), isNull);
      expect(await _readAt(db, 'system'), isNull);
    });

    test('рубеж прочтения: моё последнее сообщение или последнее прочитанное', () async {
      expect(
        await db.readThroughAnchorMs(convoId: 'peer1', selfDeviceId: 'desk'),
        0,
      );
      await _msg(db, 'read-in', at: 300, readAt: 1);
      await _msg(db, 'unread-in', at: 900);
      expect(
        await db.readThroughAnchorMs(convoId: 'peer1', selfDeviceId: 'desk'),
        300,
      );
      // Ответ с телефона позже — значит, всё до него видели.
      await _msg(db, 'my-reply', sender: 'phone', at: 700);
      expect(
        await db.readThroughAnchorMs(
          convoId: 'peer1',
          selfDeviceId: 'desk',
          ownDeviceIds: const ['phone'],
        ),
        700,
      );
      // Отложенное сообщение уходит без человека — не в счёт.
      await _msg(db, 'scheduled', sender: 'phone', at: 5000, scheduledAt: 5000);
      expect(
        await db.readThroughAnchorMs(
          convoId: 'peer1',
          selfDeviceId: 'desk',
          ownDeviceIds: const ['phone'],
        ),
        700,
      );
    });

    test('отложенные отметки ищутся по префиксу, а не по LIKE', () async {
      await db.localKvSet('parked_read_mirror_v1:peer1', '10');
      await db.localKvSet('parked_read_mirror_v1:peer2', '20');
      // `_` в LIKE — любой символ: эта строка попала бы в выборку.
      await db.localKvSet('parkedXread_mirror_v1:peer3', '30');
      final keys = await db.localKvKeysWithPrefix('parked_read_mirror_v1:');
      expect(keys.toSet(), {
        'parked_read_mirror_v1:peer1',
        'parked_read_mirror_v1:peer2',
      });
    });
  });

  group('прочитанность едет вместе с историей', () {
    test('🔴 отметка прочтения доходит до приёмника', () {
      const ev = PeerHistoryChunkEvent(
        eventId: 'e1',
        convoId: 'peer1',
        type: 'msg',
        senderDeviceId: 'dev-peer',
        createdAtMs: 100,
        payloadB64: 'AA==',
        localState: 'received',
        readAtMs: 150,
      );
      final back = PeerHistoryChunkEvent.fromJson(
        jsonDecode(jsonEncode(ev.toJson())) as Map<String, Object?>,
      );
      expect(back!.readAtMs, 150);
    });

    test('ответ старого телефона без отметки читается как раньше', () {
      final back = PeerHistoryChunkEvent.fromJson({
        'eventId': 'e1',
        'convoId': 'peer1',
        'type': 'msg',
        'senderDeviceId': 'dev-peer',
        'createdAtMs': 100,
        'payloadB64': 'AA==',
      });
      expect(back, isNotNull);
      expect(back!.readAtMs, isNull);
      expect(back.toJson().containsKey('readAtMs'), isFalse);
    });

    test('мусор в отметке не ломает событие', () {
      final back = PeerHistoryChunkEvent.fromJson({
        'eventId': 'e1',
        'convoId': 'peer1',
        'type': 'msg',
        'senderDeviceId': 'dev-peer',
        'createdAtMs': 100,
        'payloadB64': 'AA==',
        'readAtMs': 'не число',
      });
      expect(back!.readAtMs, isNull);
    });
  });

  group('с какого момента догонять', () {
    const now = 1000 * _hour;

    test('ПК был на связи недавно — догонять нечего', () {
      expect(
        DesktopHistoryCatchUp.catchUpFloorMs(
          lastOnlineMs: now - 5 * 60 * 1000,
          pendingSinceMs: 0,
          nowMs: now,
        ),
        isNull,
      );
    });

    test('🔴 ночь без связи — с последней связи, с запасом', () {
      final lastOnline = now - 9 * _hour;
      expect(
        DesktopHistoryCatchUp.catchUpFloorMs(
          lastOnlineMs: lastOnline,
          pendingSinceMs: 0,
          nowMs: now,
        ),
        lastOnline - DesktopHistoryCatchUp.floorMargin.inMilliseconds,
      );
    });

    test('неотвеченный догон не теряется и берётся самый ранний', () {
      expect(
        DesktopHistoryCatchUp.catchUpFloorMs(
          lastOnlineMs: now - 60 * 1000,
          pendingSinceMs: now - 20 * _hour,
          nowMs: now,
        ),
        now - 20 * _hour,
      );
      expect(
        DesktopHistoryCatchUp.catchUpFloorMs(
          lastOnlineMs: now - 3 * _hour,
          pendingSinceMs: now - 1 * _hour,
          nowMs: now,
        ),
        now - 3 * _hour - DesktopHistoryCatchUp.floorMargin.inMilliseconds,
      );
    });

    test('первый запуск сборки — три дня; дальше недели — никогда', () {
      expect(
        DesktopHistoryCatchUp.catchUpFloorMs(
          lastOnlineMs: 0,
          pendingSinceMs: 0,
          nowMs: now,
        ),
        now - DesktopHistoryCatchUp.firstRunLookback.inMilliseconds,
      );
      expect(
        DesktopHistoryCatchUp.catchUpFloorMs(
          lastOnlineMs: now - 30 * 24 * _hour,
          pendingSinceMs: 0,
          nowMs: now,
        ),
        now - DesktopHistoryCatchUp.maxLookback.inMilliseconds,
      );
    });
  });

  group('догон повторяется, пока телефон не ответит', () {
    tearDown(DesktopHistoryCatchUp.resetForTest);

    test('🔴 телефон молчал — повтор, как только он подал признак жизни', () async {
      SharedPreferences.setMockInitialValues({
        // ПК был на связи девять часов назад.
        'desktop_relay_online_at_ms_v1':
            DateTime.now().millisecondsSinceEpoch - 9 * _hour,
      });
      final prefs = await SharedPreferences.getInstance();
      final conn = StreamController<bool>.broadcast();
      final activity = StreamController<String>.broadcast();
      final asked = <int>[];
      var answer = PeerHistoryCatchUpOutcome.noResponse;
      await DesktopHistoryCatchUp.start(
        relayConnectionChanges: conn.stream,
        ownDeviceActivity: activity.stream,
        relayOnline: () => true,
        runCatchUp: (since) async {
          asked.add(since);
          return answer;
        },
        prefsForTest: prefs,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(asked, hasLength(1), reason: 'при запуске');
      expect(prefs.getInt('desktop_history_pending_since_ms_v1'), asked.first);

      // Телефон что-то прислал — значит, он на экране: спрашиваем снова.
      DesktopHistoryCatchUp.debugForgetLastAttempt();
      answer = PeerHistoryCatchUpOutcome.completed;
      activity.add('phone');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(asked, hasLength(2));
      expect(asked[1], asked[0], reason: 'то же окно, ничего не потеряно');
      expect(
        prefs.getInt('desktop_history_pending_since_ms_v1'),
        isNull,
        reason: 'догнали — окно закрыто',
      );

      // Закрытое окно больше не спрашивается.
      DesktopHistoryCatchUp.debugForgetLastAttempt();
      activity.add('phone');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(asked, hasLength(2));
      await conn.close();
      await activity.close();
    });

    test('без связи с реле не спрашивает, а ждёт её', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final conn = StreamController<bool>.broadcast();
      final asked = <int>[];
      var online = false;
      await DesktopHistoryCatchUp.start(
        relayConnectionChanges: conn.stream,
        ownDeviceActivity: const Stream<String>.empty(),
        relayOnline: () => online,
        runCatchUp: (since) async {
          asked.add(since);
          return PeerHistoryCatchUpOutcome.completed;
        },
        prefsForTest: prefs,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(asked, isEmpty);
      online = true;
      conn.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(asked, hasLength(1), reason: 'первый запуск: три дня назад');
      await conn.close();
    });
  });

  group('журнал ПК в файл', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('diaglog');
      await DesktopDiagFileLog.resetForTest();
    });
    tearDown(() async {
      await DesktopDiagFileLog.resetForTest();
      await dir.delete(recursive: true);
    });

    test('🔴 события DiagLog попадают в файл и без текста сообщений', () async {
      await DesktopDiagFileLog.start(directoryForTest: dir);
      DiagLog.event('selfsync', 'read_mirror_applied', {
        'convo': DiagLog.pfx('ABCD-EFGH-IJKL-M-NOPQRST'),
        'marked': 3,
        'text': 'секретный текст сообщения',
      });
      await DesktopDiagFileLog.stop();
      final log = File('${dir.path}/logs/diag.log').readAsStringSync();
      expect(log, contains('event=selfsync.read_mirror_applied'));
      expect(log, contains('marked=3'));
      expect(log, contains('convo=ABCDEFGH'));
      expect(log, isNot(contains('секретный')), reason: 'текст не пишется');
      expect(log, isNot(contains('ABCD-EFGH-IJKL')), reason: 'id обрезается');
      expect(DiagLog.sink, isNull, reason: 'после остановки приёмник снят');
    });

    test('файл не растёт без предела: прежнее уходит в diag.1.log', () async {
      await DesktopDiagFileLog.start(directoryForTest: dir);
      final line = 'x' * 1000;
      for (var i = 0; i < 2300; i++) {
        DesktopDiagFileLog.write(line);
        if (i % 200 == 0) await Future<void>.delayed(Duration.zero);
      }
      await DesktopDiagFileLog.settleForTest();
      await DesktopDiagFileLog.stop();
      final current = File('${dir.path}/logs/diag.log');
      final previous = File('${dir.path}/logs/diag.1.log');
      expect(previous.existsSync(), isTrue);
      expect(current.lengthSync(), lessThan(DesktopDiagFileLog.maxBytes));
    });
  });

  group('порядок в исходнике', () {
    final src = File('lib/app/app_controller.dart').readAsStringSync();

    String body(String signature, [int span = 12000]) {
      final start = src.indexOf(signature);
      expect(start, greaterThan(0), reason: signature);
      return src.substring(start, (start + span).clamp(0, src.length));
    }

    test('🔴 копия своего сообщения сверяется по логическому id до записи', () {
      for (final synthetic in [
        "'selfsync:\$msgEventId:\$effectiveSenderDid'",
        "'selfsync:att:\$msgEventId:\$effectiveSenderDid'",
        "'selfsync:sticker:\$msgEventId:\$effectiveSenderDid'",
      ]) {
        final at = src.indexOf(synthetic);
        expect(at, greaterThan(0), reason: synthetic);
        final tail = src.substring(at, at + 900);
        final check = tail.indexOf('_selfMirrorPayloadAlreadyApplied(');
        final write = tail.indexOf('await db.insertEvent(');
        expect(check, greaterThan(0), reason: '$synthetic без сверки');
        expect(check, lessThan(write), reason: '$synthetic: сверка после записи');
      }
    });

    test('🔴 отложенная отправка получает копию, когда реально ушла', () {
      final flush = body('Future<void> _flushPendingNoDeviceEntries(', 7000);
      expect(flush, contains('_mirrorFlushedParkedPayloadToOwnDevices('));
    });

    test('🔴 импорт истории кладёт прочитанность, а не всегда «непрочитано»', () {
      final apply = body('Future<void> _applyPeerHistoryChunk(');
      expect(apply, contains('readAtMs: importedReadAtMs'));
      expect(apply, contains('_desktopSettleImportedReadState('));
    });

    test('🔴 в фоне «прочитано» откладывается, а не теряется', () {
      final mirror = body('Future<void> _mirrorReadWatermarkToOwnDevices(', 900);
      final parked = mirror.indexOf('_parkReadWatermarkForOwnDevices(');
      final sent = mirror.indexOf('_sendSelfMirrorControl(');
      expect(parked, greaterThan(0));
      expect(parked, lessThan(sent));
      expect(
        body('Future<void> _flushOutboundOnResume()', 1200),
        contains('_flushParkedReadWatermarks()'),
      );
    });

    test('🔴 ПК догоняет историю с момента отключения', () {
      final app = File(
        'lib/ui/desktop/app/desktop_production_app.dart',
      ).readAsStringSync();
      expect(app, contains('DesktopHistoryCatchUp.start('));
      expect(app, contains('ownDeviceActivity: _controller.ownDeviceActivity'));
      expect(app, isNot(contains('maybeSyncOnBoot()')));
      expect(app, contains('DesktopDiagFileLog.start()'));
    });
  });
}
