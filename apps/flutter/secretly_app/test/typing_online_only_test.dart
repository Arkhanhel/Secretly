// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/relay_protocol.dart';
import 'package:secretly_app/transport/service_health_status.dart';

/// П-4 (ТЗ мультиустройства, 25.09.2026): «печатает» только устройствам на
/// связи, клиентская половина.
///
/// Главное: без флага всё побайтово прежнее; с флагом «печатает» не уходит
/// устройству без подтверждённой сессии (иначе брошенное рукопожатие), не
/// уходит минуту после `dropped_offline`, а объявление смены личности И-1
/// под правила не попадает вовсе.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('кому слать', () {
    List<String> pick({
      required List<String> devices,
      Map<String, int> pending = const {},
      Map<String, int> dropped = const {},
      int now = 1000000,
    }) => AppController.typingOnlineOnlyTargets(
      devices: devices,
      sessionPendingAtMs: pending,
      droppedOfflineAtMs: dropped,
      nowMs: now,
    );

    test('🔴 без сессии и с неподтверждённой — не шлём', () {
      expect(pick(devices: ['a'], pending: {}), isEmpty);
      expect(pick(devices: ['a'], pending: {'a': 555}), isEmpty);
      expect(pick(devices: ['a'], pending: {'a': 0}), ['a']);
    });

    test('минуту после dropped_offline — не шлём, потом снова', () {
      expect(
        pick(devices: ['a'], pending: {'a': 0}, dropped: {'a': 1000000 - 59999}),
        isEmpty,
      );
      expect(
        pick(devices: ['a'], pending: {'a': 0}, dropped: {'a': 1000000 - 60000}),
        ['a'],
      );
    });

    test('каждое устройство решается отдельно', () {
      expect(
        pick(
          devices: ['phone', 'desk', 'new', ' '],
          pending: {'phone': 0, 'desk': 0},
          dropped: {'desk': 999999},
        ),
        ['phone'],
      );
    });
  });

  group('устаревший «печатает»', () {
    test('старше двух минут — мусор; моложе, в будущем и без метки — нет', () {
      const now = 10 * 60 * 1000;
      bool stale(int created) =>
          AppController.typingStartIsStale(createdAtMs: created, nowMs: now);
      expect(stale(now - 121000), isTrue);
      expect(stale(now - 119000), isFalse, reason: 'часы сбиты — терпим');
      expect(stale(now + 60000), isFalse);
      expect(stale(0), isFalse);
    });
  });

  group('провод', () {
    test('🔴 без флага кадр send побайтово прежний', () {
      final plain = jsonDecode(
        ClientMsg.send(
          toDeviceId: 'd',
          msgId: 'm',
          ciphertextB64: 'QQ==',
          ttlSeconds: 20,
        ),
      ) as Map<String, dynamic>;
      expect(plain.containsKey('online_only'), isFalse);
      final flagged = jsonDecode(
        ClientMsg.send(
          toDeviceId: 'd',
          msgId: 'm',
          ciphertextB64: 'QQ==',
          ttlSeconds: 20,
          onlineOnly: true,
        ),
      ) as Map<String, dynamic>;
      expect(flagged['online_only'], isTrue);
    });

    test('sent_ok несёт delivery только у посылок «на связи»', () {
      final dropped = ServerMsg.parse(
        '{"type":"sent_ok","msg_id":"m","delivery":"dropped_offline"}',
      );
      expect(dropped, isA<SentOk>());
      expect((dropped as SentOk).delivery, 'dropped_offline');
      final plain = ServerMsg.parse('{"type":"sent_ok","msg_id":"m"}');
      expect((plain as SentOk).delivery, isNull);
    });

    test('/health: online_only только когда реле так говорит', () {
      ServiceHealthStatus parse(String body) =>
          ServiceHealthStatus.fromHttpResponse(
            httpStatusCode: 200,
            responseBody: body,
            fallbackService: 'relay',
          );
      expect(parse('{"status":"ok","online_only":true}').onlineOnly, isTrue);
      expect(parse('{"status":"ok"}').onlineOnly, isFalse);
      expect(ServiceHealthStatus.unreachable(service: 'relay').onlineOnly,
          isFalse);
    });

    test('метка строки исходящих переживает базу', () async {
      final dir = await Directory.systemTemp.createTemp('online_only_row');
      final db = await AppDb.openForTesting(path: '${dir.path}/t.db');
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      await db.outboxUpsert(
        msgId: 'w-1',
        toDeviceId: 'peer-dev',
        ciphertextB64: 'x',
        ttlSeconds: 20,
        state: 'pending',
        attemptCount: 0,
        nextRetryAtMs: 0,
        createdAtMs: 1000,
        transportHint: onlineOnlyTransportHint,
      );
      await db.outboxUpsert(
        msgId: 'w-2',
        toDeviceId: 'peer-dev',
        ciphertextB64: 'x',
        ttlSeconds: 20,
        state: 'pending',
        attemptCount: 0,
        nextRetryAtMs: 0,
        createdAtMs: 1000,
      );
      final rows = await db.rawQueryOutboxDueForBackground(nowMs: 5000);
      final byId = {for (final r in rows) r['msg_id']: r};
      expect(isOnlineOnlyOutboxRow(byId['w-1']!), isTrue);
      expect(isOnlineOnlyOutboxRow(byId['w-2']!), isFalse);
      expect((await db.outboxNackTarget('w-1'))!.toDeviceId, 'peer-dev',
          reason: 'по этой строке клиент узнаёт, кто не на связи');
    });
  });

  group('порядок в исходнике', () {
    final ctrl = File('lib/app/app_controller.dart').readAsStringSync();
    final relay = File('lib/transport/relay_client.dart').readAsStringSync();
    final bg = File('lib/push/background_worker.dart').readAsStringSync();

    test('🔴 объявление И-1 шлёт «печатает» долговечно', () {
      final start = ctrl.indexOf('Future<void> _runI1RotationAnnounceSweep()');
      expect(start, greaterThan(0));
      final body = ctrl.substring(start, start + 3000);
      expect(body.contains('durable: true'), isTrue);
    });

    test('поле доезжает по всем трём путям отправки', () {
      expect(relay.contains('onlineOnly: onlineOnly,'), isTrue, reason: 'WS');
      expect(
        relay.contains("if (onlineOnly) 'online_only': true,"),
        isTrue,
        reason: 'HTTP',
      );
      expect(
        bg.contains("if (isOnlineOnlyOutboxRow(row)) 'online_only': true,"),
        isTrue,
        reason: 'фоновый воркер',
      );
    });

    test('все места создания клиента реле слушают dropped_offline', () {
      final accepted = RegExp(
        r'relay\.onDeviceAccepted = _onRelayAcceptedOwnDevice;',
      ).allMatches(ctrl).length;
      final dropped = RegExp(
        r'relay\.onOnlineOnlyDropped = _noteTypingDroppedOffline;',
      ).allMatches(ctrl).length;
      expect(dropped, accepted);
    });

    test('«только на связи» — только за флагом и только не долговечное', () {
      final start = ctrl.indexOf('Future<void> sendTypingState({');
      final body = ctrl.substring(start, start + 3500);
      final gate = body.indexOf('if (!durable && _typingOnlineOnlyEnabled)');
      final hint = body.indexOf('transportHint: onlineOnlyTransportHint');
      expect(gate, greaterThan(0));
      expect(hint, greaterThan(gate));
    });
  });
}
