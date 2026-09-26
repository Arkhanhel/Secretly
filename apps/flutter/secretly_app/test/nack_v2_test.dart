// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ratchet/wire_v3.dart';
import 'package:secretly_app/storage/app_db.dart';

/// П-2 (ТЗ мультиустройства, 25.09.2026), фаза 1: повтор по заявке «не смог
/// расшифровать» — адресно, один раз, без лишних сбросов.
///
/// Всё новое — за долей `nack_v2_percent`; без неё путь прежний. Проверка
/// адресата (Н-1) действует всегда и проверена в своём тесте.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('правила', () {
    test('🔴 сброс только если провод умер под ТЕКУЩЕЙ сессией', () {
      bool reset(int? se, int epoch) =>
          AppController.nackV2ShouldResetSession(refSe: se, currentEpoch: epoch);
      expect(reset(1000, 1000), isTrue, reason: 'текущая сломана');
      expect(reset(900, 1000), isFalse, reason: 'провод от старой — только повтор');
      expect(reset(null, 1000), isTrue, reason: 'старый получатель — как раньше');
      expect(reset(0, 1000), isTrue);
      expect(reset(1200, 1000), isTrue);
      expect(reset(1000, 0), isTrue, reason: 'сессии нет — нужна новая');
    });

    test('«уже отвечено» держит 6 часов, потом — снова, но в бюджете', () {
      const now = 10 * 60 * 60 * 1000;
      bool recent(String? mark) =>
          AppController.nackV2AnsweredRecently(answeredMark: mark, nowMs: now);
      expect(recent(null), isFalse);
      expect(recent(''), isFalse);
      expect(recent('${now - 60 * 60 * 1000}'), isTrue);
      expect(recent('${now - 7 * 60 * 60 * 1000}'), isFalse);
      expect(recent('мусор'), isFalse);
    });

    test('эпоха сессии читается из заголовка провода', () {
      Uint8List wire(int? se) => RatchetWireV3.encodeSession(
        senderDeviceId: 'a',
        dhPubB64: 'AAAA',
        pn: 0,
        n: 3,
        ratchetCiphertext: Uint8List(48),
        se: se,
      );
      expect(AppController.wireSessionEpoch(base64Encode(wire(1790000000000))),
          1790000000000);
      expect(AppController.wireSessionEpoch(base64Encode(wire(null))), isNull);
      expect(AppController.wireSessionEpoch('не провод'), isNull);
    });
  });

  group('заявка на проводе', () {
    test('ref_se уходит только когда есть, старые разбираются как раньше', () {
      final plain = ReceiptEventV1(
        eventId: 'e',
        refEventId: 'wire-1',
        status: 'nack_undecryptable',
        refKind: 'msg_id',
      ).toJson();
      expect(plain.containsKey('ref_se'), isFalse, reason: 'побайтово прежняя');
      final withSe = ReceiptEventV1(
        eventId: 'e',
        refEventId: 'wire-1',
        status: 'nack_undecryptable',
        refKind: 'msg_id',
        refSe: 1790000000000,
      );
      final payload = E2ePayloadV1(
        senderDeviceId: 'd',
        createdAtMs: 1,
        events: [withSe],
      );
      final back = E2ePayloadV1.decode(payload.encode()).events.single
          as ReceiptEventV1;
      expect(back.refSe, 1790000000000);
      final legacy = E2ePayloadV1.decode(
        E2ePayloadV1(senderDeviceId: 'd', createdAtMs: 1, events: [
          ReceiptEventV1(eventId: 'e', refEventId: 'w', status: 'read'),
        ]).encode(),
      ).events.single as ReceiptEventV1;
      expect(legacy.refSe, isNull);
    });
  });

  group('уборка', () {
    test('исходящие: только отправленные и старые, порциями', () async {
      final dir = await Directory.systemTemp.createTemp('nack_v2_prune');
      final db = await AppDb.openForTesting(path: '${dir.path}/t.db');
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      Future<void> row(String id, int createdAt, String state) async {
        await db.outboxUpsert(
          msgId: id,
          toDeviceId: 'dev',
          ciphertextB64: 'x',
          ttlSeconds: 60,
          state: 'pending',
          attemptCount: 0,
          nextRetryAtMs: 0,
          createdAtMs: createdAt,
        );
        if (state == 'sent') await db.outboxMarkSent(id);
      }

      for (var i = 0; i < 5; i++) {
        await row('old-sent-$i', 1000 + i, 'sent');
      }
      await row('old-pending', 1000, 'pending');
      await row('fresh-sent', 9000000, 'sent');

      expect(await db.outboxPruneSentOlderThan(cutoffMs: 5000, limit: 3), 3);
      expect(await db.outboxPruneSentOlderThan(cutoffMs: 5000, limit: 3), 2);
      expect(await db.outboxPruneSentOlderThan(cutoffMs: 5000, limit: 3), 0);
      expect(await db.outboxNackTarget('old-pending'), isNotNull,
          reason: 'неотправленное не удаляется никогда');
      expect(await db.outboxNackTarget('fresh-sent'), isNotNull);
    });
  });

  group('порядок в исходнике', () {
    final src = File('lib/app/app_controller.dart').readAsStringSync();

    String body(String signature, int span) {
      final start = src.indexOf(signature);
      expect(start, greaterThan(0), reason: signature);
      return src.substring(start, start + span);
    }

    test('🔴 фоновая заявка не теряется: ветка v2 — до выхода «в фоне»', () {
      final h = body('Future<void> _handleNackUndecryptableReceipt({', 900);
      final v2 = h.indexOf('if (_nackV2Active)');
      final bg = h.indexOf('if (_backgroundInboundMode) return;');
      expect(v2, greaterThan(0));
      expect(bg, greaterThan(v2));
    });

    test('🔴 адресат → сброс ДОЖДАН → повтор; общего свипа нет', () {
      final p = body('Future<void> _processNackV2({', 7000);
      final decide = p.indexOf('nackResendDecision(');
      final reset = p.indexOf('await _sendSessionResetPingNow(');
      final resend = p.indexOf('await _resendOneEventReEncrypted(');
      expect(decide, greaterThan(0));
      expect(reset, greaterThan(decide));
      expect(resend, greaterThan(reset));
      expect(p.contains('_resendUndeliveredDirect('), isFalse);
      expect(p.contains('resendBudgetHasRoom('), isTrue, reason: 'бюджет Э-0');
    });

    test('заявка — одному устройству, только в доле', () {
      final flush = body('Future<int> _flushPendingReceiptsBestEffort()', 9000);
      expect(flush.contains('if (nackOnlyToSender) break;'), isTrue);
      expect(flush.contains('_nackV2Active &&'), isTrue);
    });

    test('прежний сброс по-прежнему не ждёт', () {
      final d = body('void _dispatchSessionResetPing(String peerDeviceId', 4000);
      expect(d.contains('unawaited(_sendSessionResetPingNow(peerDeviceId, cause));'),
          isTrue);
    });

    test('очередь фоновых заявок отрабатывается при выходе на экран', () {
      expect(src.contains('await _flushQueuedNacksV2().timeout('), isTrue);
    });
  });
}
