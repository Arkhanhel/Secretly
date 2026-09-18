// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// 🔴 ОЧЕРЕДЬ СИГНАЛОВ ЗВОНКА ЧЕРЕЗ ГРАНИЦУ ИЗОЛЯТА
/// (docs/TZ_CALL_SIGNALS_CROSS_ISOLATE_2026-08-14.md).
///
/// ЗАМЕР 14.08, звонок `d41fdf11`: приглашение и предложение приехали за ТРИ
/// СЕКУНДЫ до того, как человек нажал «Принять», — но в фоновый изолят. Он их
/// применил, подтвердил реле и очистил ящик; главный изолят поднялся на пустой
/// ящик и о звонке не узнал никогда. Экран остался пустым, звонящий сдался.
///
/// Буфер в ОЗУ границу изолята не переживает. Эти тесты держат то, что переживёт.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('сериализация сигнала', () {
    test('🔴 предложение соединения переживает круг через JSON', () {
      // Без `sdp` звонок ПОКАЖЕТСЯ и не соединится — а это ровно та жалоба,
      // ради которой всё делается. Круг проверяем на самом тяжёлом сигнале.
      const original = CallSignalEvent(
        action: 'offer',
        callId: 'call-1',
        callAttemptId: 'att-1',
        signalId: 'sig-1',
        fromProfileId: 'peer-1',
        fromDeviceId: 'dev-1',
        media: CallMedia.video,
        screenShare: true,
        sdp: 'v=0\r\no=- 42 2 IN IP4 127.0.0.1\r\n',
        candidate: 'candidate:1 1 udp 2130706431 10.0.0.1 54321 typ host',
        sdpMid: '0',
        sdpMLineIndex: 3,
        createdAtMs: 1_700_000_000_000,
      );

      final restored = CallSignalEvent.fromJson(
        (jsonDecode(jsonEncode(original.toJson())) as Map)
            .cast<Object?, Object?>(),
      );

      expect(restored, isNotNull);
      expect(restored!.action, 'offer');
      expect(restored.callId, 'call-1');
      expect(restored.callAttemptId, 'att-1');
      expect(restored.signalId, 'sig-1');
      expect(restored.fromProfileId, 'peer-1');
      expect(restored.fromDeviceId, 'dev-1');
      expect(restored.media, CallMedia.video);
      expect(restored.screenShare, isTrue);
      expect(restored.sdp, original.sdp);
      expect(restored.candidate, original.candidate);
      expect(restored.sdpMid, '0');
      expect(restored.sdpMLineIndex, 3);
      expect(restored.createdAtMs, 1_700_000_000_000);
    });

    test('пустая попытка подставляется идентификатором звонка', () {
      final restored = CallSignalEvent.fromJson(<Object?, Object?>{
        'action': 'invite',
        'call_id': 'call-9',
        'call_attempt_id': '',
        'created_at_ms': 1,
      });
      expect(restored?.callAttemptId, 'call-9');
    });

    test('без действия или звонка сигнал не восстанавливается', () {
      expect(
        CallSignalEvent.fromJson(<Object?, Object?>{'call_id': 'c'}),
        isNull,
      );
      expect(
        CallSignalEvent.fromJson(<Object?, Object?>{'action': 'invite'}),
        isNull,
      );
    });
  });

  group('очередь в базе', () {
    test('🔴 порядок сохраняется: приглашение раньше предложения', () async {
      // Предложение, применённое раньше приглашения, не соберёт соединение.
      final db = await AppDb.openForTesting();

      await db.pendingCallSignalUpsert(
        signalId: 'sig-invite',
        callId: 'call-1',
        callAttemptId: 'att-1',
        action: 'invite',
        fromProfileId: 'peer-1',
        fromDeviceId: 'dev-1',
        payloadJson: '{"action":"invite"}',
        createdAtMs: 100,
        nowMs: 1000,
      );
      await db.pendingCallSignalUpsert(
        signalId: 'sig-offer',
        callId: 'call-1',
        callAttemptId: 'att-1',
        action: 'offer',
        fromProfileId: 'peer-1',
        fromDeviceId: 'dev-1',
        payloadJson: '{"action":"offer"}',
        createdAtMs: 200,
        nowMs: 2000,
      );

      final rows = await db.pendingCallSignalsDrain();
      expect(rows.map((r) => r['action']).toList(), <String>['invite', 'offer']);
    });

    test('🔴 вычерпанное удаляется — иначе фантом на каждом запуске', () async {
      final db = await AppDb.openForTesting();
      await db.pendingCallSignalUpsert(
        signalId: 'sig-1',
        callId: 'call-1',
        callAttemptId: 'att-1',
        action: 'invite',
        fromProfileId: 'peer-1',
        fromDeviceId: null,
        payloadJson: '{"action":"invite"}',
        createdAtMs: 1,
        nowMs: 1,
      );

      expect((await db.pendingCallSignalsDrain()).length, 1);
      expect(await db.pendingCallSignalsDrain(), isEmpty);
    });

    test('повторный сигнал не плодит вторую строку', () async {
      final db = await AppDb.openForTesting();
      for (var i = 0; i < 3; i += 1) {
        await db.pendingCallSignalUpsert(
          signalId: 'sig-same',
          callId: 'call-1',
          callAttemptId: 'att-1',
          action: 'invite',
          fromProfileId: 'peer-1',
          fromDeviceId: 'dev-1',
          payloadJson: '{"action":"invite"}',
          createdAtMs: 1,
          nowMs: 10 + i,
        );
      }
      expect((await db.pendingCallSignalsDrain()).length, 1);
    });

    test('сигнал без идентификатора не пишется', () async {
      final db = await AppDb.openForTesting();
      await db.pendingCallSignalUpsert(
        signalId: '   ',
        callId: 'call-1',
        callAttemptId: 'att-1',
        action: 'invite',
        fromProfileId: 'peer-1',
        fromDeviceId: null,
        payloadJson: '{}',
        createdAtMs: 1,
        nowMs: 1,
      );
      expect(await db.pendingCallSignalsDrain(), isEmpty);
    });

    test('чистка убирает старое и не трогает свежее', () async {
      final db = await AppDb.openForTesting();
      await db.pendingCallSignalUpsert(
        signalId: 'sig-old',
        callId: 'call-old',
        callAttemptId: 'att-old',
        action: 'invite',
        fromProfileId: 'peer-1',
        fromDeviceId: null,
        payloadJson: '{}',
        createdAtMs: 1,
        nowMs: 1000,
      );
      await db.pendingCallSignalUpsert(
        signalId: 'sig-new',
        callId: 'call-new',
        callAttemptId: 'att-new',
        action: 'invite',
        fromProfileId: 'peer-1',
        fromDeviceId: null,
        payloadJson: '{}',
        createdAtMs: 1,
        nowMs: 5000,
      );

      await db.pendingCallSignalsPrune(3000);

      final rows = await db.pendingCallSignalsDrain();
      expect(rows.map((r) => r['signal_id']).toList(), <String>['sig-new']);
    });
  });

  group('миграция 66 → 67', () {
    test('🔴 старая база получает таблицу и открывается', () async {
      // Падение в цепочке миграций — это база, которая не открывается, то есть
      // потеря переписки. Ветка обязана быть выполнена тестом хотя бы раз.
      final dir = await Directory.systemTemp.createTemp('mig_v67');
      final path = p.join(dir.path, 'old.db');
      try {
        ffi.sqfliteFfiInit();
        final db = await ffi.databaseFactoryFfi.openDatabase(path);
        // База «до»: таблицы очереди нет и быть не должно.
        expect(
          (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name='pending_call_signals';",
          )),
          isEmpty,
        );

        await AppDb.runMigrationsForTest(db, 66, 67);

        expect(
          (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name='pending_call_signals';",
          )),
          isNotEmpty,
        );
        // Повторный прогон той же ветки не имеет права упасть.
        await AppDb.runMigrationsForTest(db, 66, 67);
        await db.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
