// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 Н-1 (25.09.2026): заявка «не смог расшифровать» не должна отдавать чужое
// сообщение заявителю.
//
// Повтор по заявке перешифровывает сохранённый открытый текст события на
// устройство того, кто прислал заявку. Раньше проверялось только «не
// комната»: любой, у кого есть сессия с человеком, называл номер посылки,
// ушедшей КОМУ-ТО ДРУГОМУ, и получал это сообщение. Номера посылок знает
// реле, так что сервер мог читать переписку в обход сквозного шифрования.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/storage/app_db.dart';

OutboxNackTarget _row({
  String to = 'alice-phone',
  String convo = 'ALICE',
  String event = 'local:evt-1',
  String payload = 'pe-1',
}) => (toDeviceId: to, convoId: convo, eventIdRef: event, payloadEventId: payload);

NackResendDecision _decide(
  OutboxNackTarget? row, {
  String dev = 'alice-phone',
  String pid = 'ALICE',
}) => AppController.nackResendDecision(
  row: row,
  requesterDeviceId: dev,
  requesterProfileId: pid,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('правило решения', () {
    test('🔴 чужой называет посылку, ушедшую Алисе, — ничего не делаем', () {
      expect(
        _decide(_row(), dev: 'mallory-phone', pid: 'MALLORY'),
        NackResendDecision.notAddressee,
      );
    });

    test('🔴 чужой называет посылку ВЛОЖЕНИЯ (переписка в строке пуста)', () {
      // Здесь второй рубеж по переписке не спасает — держит только устройство.
      expect(
        _decide(_row(convo: ''), dev: 'mallory-phone', pid: 'MALLORY'),
        NackResendDecision.notAddressee,
      );
    });

    test('🔴 другое устройство Алисы не получает посылку её телефона', () {
      // Номер посылки уникален на устройство: получить провод могло только
      // то устройство, которому он шёл.
      expect(
        _decide(_row(), dev: 'alice-desktop', pid: 'ALICE'),
        NackResendDecision.notAddressee,
      );
    });

    test('устройство совпало, а событие из чужой переписки — только лечение', () {
      expect(
        _decide(_row(convo: 'BOB'), dev: 'alice-phone', pid: 'ALICE'),
        NackResendDecision.foreignConvo,
      );
    });

    test('🔴 квитанция комнаты от адресата — лечение сессии не отключается', () {
      // Квитанции комнат несут convo_id = group:…; отказ по переписке оставил
      // бы сломанную сессию с участником без ремонта.
      expect(
        _decide(_row(convo: 'group:R1', event: '')),
        NackResendDecision.noEvent,
      );
      expect(
        _decide(_row(convo: 'group:R1', event: 'local:grp:e1')),
        NackResendDecision.foreignConvo,
      );
    });

    test('адресат называет свою посылку — повтор', () {
      expect(_decide(_row()), NackResendDecision.resend);
    });

    test('у вложений convo_id в строке пуст — решает устройство', () {
      expect(_decide(_row(convo: '')), NackResendDecision.resend);
    });

    test('служебная посылка без события — повторять нечего', () {
      expect(_decide(_row(event: '')), NackResendDecision.noEvent);
    });

    test('посылки не знаем — только лечение сессии с самим заявителем', () {
      expect(_decide(null), NackResendDecision.unknownWire);
    });

    test('пустой заявитель или пустой адресат — не адресат', () {
      expect(_decide(_row(), dev: '  '), NackResendDecision.notAddressee);
      expect(_decide(_row(to: '')), NackResendDecision.notAddressee);
    });
  });

  group('строка исходящих', () {
    test('отдаёт адресата и переписку, даже без события', () async {
      final dir = await Directory.systemTemp.createTemp('nack_target');
      final db = await AppDb.openForTesting(path: '${dir.path}/t.db');
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      await db.outboxUpsert(
        msgId: 'wire-1',
        toDeviceId: 'alice-phone',
        ciphertextB64: 'x',
        ttlSeconds: 3600,
        state: 'pending',
        attemptCount: 0,
        nextRetryAtMs: 0,
        createdAtMs: 1000,
        payloadEventId: 'pe-1',
        eventIdRef: 'local:evt-1',
        convoId: 'ALICE',
      );
      await db.outboxMarkSent('wire-1');
      await db.outboxUpsert(
        msgId: 'wire-2',
        toDeviceId: 'alice-phone',
        ciphertextB64: 'x',
        ttlSeconds: 3600,
        state: 'pending',
        attemptCount: 0,
        nextRetryAtMs: 0,
        createdAtMs: 1000,
      );

      final full = await db.outboxNackTarget('wire-1');
      expect(full, isNotNull);
      expect(full!.toDeviceId, 'alice-phone');
      expect(full.convoId, 'ALICE');
      expect(full.eventIdRef, 'local:evt-1');
      expect(full.payloadEventId, 'pe-1');

      final control = await db.outboxNackTarget('wire-2');
      expect(control, isNotNull, reason: 'строка есть, хоть и без события');
      expect(control!.eventIdRef, isEmpty);

      expect(await db.outboxNackTarget('unknown'), isNull);
      expect(await db.outboxNackTarget('  '), isNull);
    });
  });

  group('порядок в исходнике', () {
    final src = File('lib/app/app_controller.dart').readAsStringSync();

    String body(String signature, int span) {
      final start = src.indexOf(signature);
      expect(start, greaterThan(0), reason: signature);
      return src.substring(start, start + span);
    }

    test('🔴 проверка адресата стоит ДО сброса, свипа и повтора', () {
      final handler = body(
        'Future<void> _handleNackUndecryptableReceipt(',
        9000,
      );
      final check = handler.indexOf('nackResendDecision(');
      final skip = handler.indexOf("'not_addressee'");
      final reset = handler.indexOf('_forceSessionResetPing(');
      final sweep = handler.indexOf('_resendUndeliveredDirect(');
      final resend = handler.indexOf('_resendOneEventReEncrypted(');
      expect(check, greaterThan(0));
      expect(skip, greaterThan(check));
      for (final action in [reset, sweep, resend]) {
        expect(action, greaterThan(skip), reason: 'действие раньше проверки');
      }
      expect(
        handler.contains('outboxEventRefByMsgId('),
        isFalse,
        reason: 'старый поиск без адресата вернулся в обработчик',
      );
    });

    test('🔴 повтор сверяет переписку события с заявителем', () {
      final resend = body('Future<bool> _resendOneEventReEncrypted(', 6000);
      final guard = resend.indexOf('nack_resend_skip_foreign_convo');
      final encrypt = resend.indexOf('_encryptToPeerSerialized(');
      expect(guard, greaterThan(0));
      expect(guard, lessThan(encrypt));
    });
  });
}
