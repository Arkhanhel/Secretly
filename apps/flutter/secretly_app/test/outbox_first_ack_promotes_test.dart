// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/storage/app_db.dart';

// Часы на пузыре и правило их снятия (06.08.2026).
//
// Полевая жалоба: «отправил, сообщение уже пришло на второе устройство, а
// часики всё крутятся, и так несколько секунд». Причина была не в значках, а в
// правиле: событие переходило в `sent` только когда реле подтвердило ПОСЛЕДНЮЮ
// копию рассылки. Сообщение 1:1 разлетается по всем устройствам собеседника, и
// часы держала самая медленная из них.
//
// Здесь закрепляются две вещи, которые легко потерять при следующей правке:
//  1. поднимает первое подтверждение, а не последнее;
//  2. подтверждение, пришедшее ПОЗЖЕ квитанции о доставке или прочтении, не
//     откатывает состояние назад. `updateEventLocalState` пишет БЕЗУСЛОВНО, без
//     `canPromote`, поэтому защита живёт в самом `outboxMarkSent`.

Future<void> seedFanout(AppDb db, {required String state}) async {
  await db.insertEvent(
    eventId: 'evt',
    convoId: 'convo',
    type: 'message',
    senderDeviceId: 'self-device',
    ciphertextB64: 'AA==',
    createdAtMs: 1000,
    localState: state,
  );
  for (final target in const ['a', 'b']) {
    await db.outboxUpsert(
      msgId: 'msg-$target',
      toDeviceId: 'peer-device-$target',
      ciphertextB64: 'AA==',
      ttlSeconds: 60,
      state: OutboxSendState.pending,
      attemptCount: 0,
      nextRetryAtMs: 1000,
      createdAtMs: 1000,
      correlationId: 'corr',
      convoId: 'convo',
      eventIdRef: 'evt',
    );
  }
}

Future<String> stateOf(AppDb db) async {
  final events = await db.listEvents('convo');
  return (events.single['local_state'] as String?) ?? '';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('первая подтверждённая копия уже снимает часы', () async {
    final db = await AppDb.openForTesting();
    try {
      await seedFanout(db, state: MessageLocalState.pending);
      expect(await stateOf(db), MessageLocalState.pending);

      await db.outboxMarkSent('msg-a');
      expect(
        await stateOf(db),
        MessageLocalState.sent,
        reason: 'вторая копия ещё в пути, но сообщение уже НА реле',
      );
    } finally {
      await db.close();
    }
  });

  test('подтверждение после квитанции не откатывает «доставлено»', () async {
    final db = await AppDb.openForTesting();
    try {
      await seedFanout(db, state: MessageLocalState.pending);

      await db.outboxMarkSent('msg-a');
      // Собеседник прочитал с первого устройства раньше, чем реле приняло копию
      // для второго — обычная гонка при нескольких устройствах.
      await db.updateEventLocalState(
        eventId: 'evt',
        localState: MessageLocalState.delivered,
      );
      await db.outboxMarkSent('msg-b');

      expect(
        await stateOf(db),
        MessageLocalState.delivered,
        reason: 'галочки не имеют права прыгать назад',
      );
    } finally {
      await db.close();
    }
  });

  test('подтверждение после прочтения не откатывает «прочитано»', () async {
    final db = await AppDb.openForTesting();
    try {
      await seedFanout(db, state: MessageLocalState.pending);

      await db.outboxMarkSent('msg-a');
      await db.updateEventLocalState(
        eventId: 'evt',
        localState: MessageLocalState.read,
      );
      await db.outboxMarkSent('msg-b');

      expect(await stateOf(db), MessageLocalState.read);
    } finally {
      await db.close();
    }
  });

  test('подтверждение не воскрешает сообщение, признанное несостоявшимся', () async {
    // Обратное направление оставлено КАК БЫЛО и сознательно: красная галочка —
    // это призыв к действию, и снимать её задним числом без разбора опаснее,
    // чем оставить. Отдельный вопрос, стоит ли её снимать по успешной копии, —
    // он не входит в эту правку.
    final db = await AppDb.openForTesting();
    try {
      await seedFanout(db, state: MessageLocalState.failed);
      await db.outboxMarkSent('msg-a');
      expect(await stateOf(db), MessageLocalState.failed);
    } finally {
      await db.close();
    }
  });
}
