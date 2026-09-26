// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/app/message_command_utils.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';
import 'package:secretly_app/transport/relay_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Застрявшие отчёты (25.09.2026). Три ветви самосинхронизации (прочитано,
/// папки, состояние чата) не отмечали сообщение обработанным: оно ложилось
/// скрытой строкой в чат с самим собой и ставило вечный отчёт своему же
/// устройству. Сброс гонял такие строки раз в секунду, а после 512 свежие
/// отчёты переставали попадать в выборку вовсе.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Применение состояния чата (звук) обновляет правила пушей, а те читают
  // настройки.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const self = 'self-profile';
  const selfDev = 'device-self';
  const otherOwnDev = 'device-self-2';

  /// [withRatchet] = false — сброс очереди отчётов не работает (нет чем
  /// шифровать): так видно, что строку не поставил сам приём, а не убрал сброс.
  Future<(AppController, AppDb)> runtime({bool withRatchet = true}) async {
    final controller = AppController();
    final db = await AppDb.openForTesting();
    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: self,
      deviceId: selfDev,
      ratchetV3: withRatchet
          ? RatchetSessionManagerV3(
              db: db,
              deviceKeys: DeviceKeys.create(),
              keysClient: KeysClient(
                baseUrl: Uri.parse('https://example.test'),
              ),
            )
          : null,
    );
    controller.seedRelayRuntimeForTesting(
      relay: RelayClient(
        db: db,
        deviceId: selfDev,
        selfProfileId: self,
        deviceKeys: DeviceKeys.create(),
        wsUrl: Uri.parse('ws://example.test/ws'),
        httpBaseUrl: null,
        httpClient: MockClient((request) async {
          throw StateError('offline relay should not send HTTP');
        }),
        identityKeyPairOverride: await Ed25519().newKeyPair(),
        onDelivered: ({required msgId, required ciphertextB64}) async => true,
        loadNextSeq: () async => 1,
        saveNextSeq: (_) async {},
      ),
      relayOnline: false,
    );
    addTearDown(db.close);
    return (controller, db);
  }

  Future<bool> inbound(
    AppController controller,
    AppDb db,
    MsgEventV1 event,
  ) {
    final payload = E2ePayloadV1(
      senderDeviceId: otherOwnDev,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      events: [event],
    );
    return controller.handleDecryptedInboundPayloadForTesting(
      db: db,
      msgId: 'wire-${event.eventId}',
      ciphertextB64: 'cipher-${event.eventId}',
      plainBytes: Uint8List.fromList(payload.encode()),
      payload: payload,
      senderDeviceId: otherOwnDev,
      senderProfileId: self,
    );
  }

  group('поведение', () {
    test('🔴 A: команда самосинхронизации с моего устройства не оседает', () async {
      final (controller, db) = await runtime(withRatchet: false);
      final now = DateTime.now().millisecondsSinceEpoch;
      final handled = await inbound(
        controller,
        db,
        MsgEventV1(
          eventId: 'cmd-state-1',
          text: buildSelfMirrorConvoStateCommand(
            convoId: 'peer-1',
            appliedAtMs: now,
            muted: true,
          ),
        ),
      );
      expect(handled, isTrue);
      expect(
        await db.listEvents(self),
        isEmpty,
        reason: 'ни скрытой строки в чате с самим собой',
      );
      expect(await db.pendingReceiptCount(), 0, reason: 'ни отчёта себе');
    });

    test('C: своему же сообщению отчёт «доставлено» не ставится', () async {
      final (controller, db) = await runtime(withRatchet: false);
      final handled = await inbound(
        controller,
        db,
        MsgEventV1(eventId: 'own-msg-1', text: 'заметка себе'),
      );
      expect(handled, isTrue);
      expect(await db.pendingReceiptCount(), 0);
    });

    test('🔴 B: строка, адресованная только своим устройствам, уходит', () async {
      final (controller, db) = await runtime();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.pendingReceiptUpsert(
        peerDeviceId: selfDev,
        peerProfileId: self,
        payloadEventId: 'own-evt',
        convoId: self,
        status: MessageReceiptState.delivered,
        createdAtMs: now,
        updatedAtMs: now,
      );
      await controller.forceOutboxPump();
      expect(await db.pendingReceiptCount(), 0);
      expect(await db.outboxDue(limit: 10), isEmpty, reason: 'и никуда не ушла');
    });

    test('B: без адресата старое убирается, свежее ждёт', () async {
      final (controller, db) = await runtime();
      final now = DateTime.now().millisecondsSinceEpoch;
      Future<void> put(String ev, int at) => db.pendingReceiptUpsert(
        peerDeviceId: 'ghost-device',
        payloadEventId: ev,
        convoId: 'group:gone',
        status: MessageReceiptState.delivered,
        createdAtMs: at,
        updatedAtMs: at,
      );
      await put('stale', now - 8 * 24 * 60 * 60 * 1000);
      await put('fresh', now);
      await controller.forceOutboxPump();
      final left = await db.pendingReceiptList();
      expect(left.map((r) => r.payloadEventId), ['fresh']);
    });
  });

  group('очередь отчётов в базе', () {
    late Directory dir;
    late AppDb db;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('stuck_receipts');
      db = await AppDb.openForTesting(path: '${dir.path}/t.db');
    });
    tearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });

    Future<void> put(String dev, String ev, int at) => db.pendingReceiptUpsert(
      peerDeviceId: dev,
      peerProfileId: 'P',
      payloadEventId: ev,
      convoId: 'P',
      status: MessageReceiptState.delivered,
      createdAtMs: at,
      updatedAtMs: at,
    );

    test('удаление по ключу — ровно указанные строки', () async {
      await put('own', 'e1', 10);
      await put('own', 'e2', 10);
      await put('peer', 'e1', 10);
      final all = await db.pendingReceiptList();
      final dropped = await db.pendingReceiptDeleteRecords(
        all.where((r) => r.peerDeviceId == 'own'),
      );
      expect(dropped, 2);
      expect(
        (await db.pendingReceiptList()).map(
          (r) => '${r.peerDeviceId}/${r.payloadEventId}',
        ),
        ['peer/e1'],
      );
      expect(await db.pendingReceiptDeleteRecords(const []), 0);
    });

    test('🔴 после 512 застрявших свежий отчёт в выборку не попадал', () async {
      for (var i = 0; i < 512; i++) {
        await put('own', 'stuck-$i', 100 + i);
      }
      await put('peer', 'fresh', 100000);
      final batch = await db.pendingReceiptList(limit: 512);
      expect(
        batch.any((r) => r.payloadEventId == 'fresh'),
        isFalse,
        reason: 'поэтому неотправляемое надо убирать, а не пропускать',
      );
      await db.pendingReceiptDeleteRecords(
        batch.where((r) => r.peerDeviceId == 'own'),
      );
      expect(
        (await db.pendingReceiptList(limit: 512)).single.payloadEventId,
        'fresh',
      );
    });
  });

  group('порядок в исходнике', () {
    final src = File('lib/app/app_controller.dart').readAsStringSync();

    String between(String from, String to) {
      final start = src.indexOf(from);
      expect(start, greaterThan(0), reason: from);
      final end = src.indexOf(to, start + from.length);
      expect(end, greaterThan(start), reason: to);
      return src.substring(start, end);
    }

    String flushBody() => between(
      'Future<int> _flushPendingReceiptsBestEffort()',
      'Future<String> identityFingerprint()',
    );

    test('🔴 A: каждая ветвь самосинхронизации ставит отметку', () {
      const parsers = [
        'parseSelfMirrorReadCommand(msgEvent.text)',
        'parseSelfMirrorFolderCommand(msgEvent.text)',
        'parseSelfMirrorConvoStateCommand(msgEvent.text)',
        'parseSelfMirrorReceiptCommand(msgEvent.text)',
      ];
      for (final parser in parsers) {
        final branch = between(parser, '(msgEvent.text)');
        expect(
          RegExp(r'handledCommand = true;\s*continue;\s*\}$').hasMatch(
            branch.substring(0, branch.lastIndexOf('}') + 1),
          ),
          isTrue,
          reason: parser,
        );
      }
    });

    test('🔴 B: по возрасту — только то, что проход отправить не смог', () {
      final f = flushBody();
      expect(f.contains('pendingReceiptPruneOlderThan'), isFalse,
          reason: 'никакой слепой чистки по часам');
      final unresolved = f.indexOf('if (peerProfileId.isEmpty) {');
      final stale = f.indexOf('dropStale.add(record);');
      final ownOnly = f.indexOf('dropOwnOnly.add(record);');
      final drop = f.indexOf(
        'await db.pendingReceiptDeleteRecords([...dropOwnOnly, ...dropStale]);',
      );
      final failStale = f.indexOf('final stale = records.where(isStale)');
      expect(stale, greaterThan(unresolved));
      expect(ownOnly, greaterThan(stale));
      expect(drop, greaterThan(ownOnly));
      expect(failStale, greaterThan(drop), reason: 'и после сбоя шифрования');
    });

    test('D: flush_start — только когда есть что слать', () {
      final f = flushBody();
      final idle = f.indexOf('if (grouped.isEmpty) {');
      final start = f.indexOf("DiagLog.event('receipt', 'flush_start'");
      expect(idle, greaterThan(0));
      expect(start, greaterThan(idle));
      expect("'receipt', 'flush_start'".allMatches(src).length, 1);
    });
  });
}
