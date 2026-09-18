// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/storage/app_db.dart';

// Надгробия удалений (07.08.2026).
//
// Полевая жалоба: «после восстановления вернулись чаты, которые я давно удалил».
//
// Причина была не в восстановлении, а в том, что система не помнила удалений.
// Удаление жёсткое — строки стираются; восстановление — полная замена. Копия,
// снятая ДО удаления, возвращала всё обратно, и отличить «я это удалил» от
// «этого никогда не было» было нечем.
//
// 🔴 Главное свойство, которое здесь закрепляется: надгробие обязано ПЕРЕЖИТЬ
// восстановление. Попади таблица `deletions` в снимок копии — местные надгробия
// затирались бы теми, что в копии, ровно в тот момент, когда они нужны.

Future<void> seedConvo(AppDb db, String convoId) async {
  await db.convoEnsure1to1(peerProfileId: convoId);
  await db.insertEvent(
    eventId: 'evt-$convoId',
    convoId: convoId,
    type: 'message',
    senderDeviceId: 'peer-device',
    ciphertextB64: 'AA==',
    createdAtMs: 1000,
    localState: 'received',
  );
}

Future<void> queueWire(AppDb db, String convoId, String msgId) async {
  await db.outboxUpsert(
    msgId: msgId,
    toDeviceId: 'peer-device',
    ciphertextB64: 'AA==',
    ttlSeconds: 604800,
    state: 'pending',
    attemptCount: 0,
    nextRetryAtMs: 0,
    createdAtMs: 1000,
    eventIdRef: 'evt-$convoId',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('удаление чата оставляет надгробие', () async {
    final db = await AppDb.openForTesting();
    try {
      await seedConvo(db, 'convo-a');
      await db.deleteConversationData(
        convoId: 'convo-a',
        keepConversationRow: false,
      );

      final marks = await db.deletionsList();
      expect(marks, hasLength(1));
      expect(marks.single['kind'], 'convo');
      expect(marks.single['target_id'], 'convo-a');
    } finally {
      await db.close();
    }
  });

  test('надгробие снимает чат, вернувшийся из копии', () async {
    // Ровно полевой сценарий: копия снята вчера, чат удалён сегодня,
    // восстановление вернуло его — надгробие обязано убрать снова.
    final db = await AppDb.openForTesting();
    try {
      await seedConvo(db, 'convo-a');
      await db.deleteConversationData(
        convoId: 'convo-a',
        keepConversationRow: false,
      );

      // Снимок из копии возвращает чат и его сообщения.
      await seedConvo(db, 'convo-a');
      expect(await db.listEvents('convo-a'), hasLength(1));

      final removed = await db.applyDeletionTombstones();
      expect(removed, 1);
      expect(await db.listEvents('convo-a'), isEmpty);
    } finally {
      await db.close();
    }
  });

  test('чат, который НЕ удаляли, надгробия не трогают', () async {
    // Обратная защёлка: механизм не имеет права уносить лишнее. Ошибка здесь
    // стоила бы дороже исходной болезни — молчаливая потеря переписки.
    final db = await AppDb.openForTesting();
    try {
      await seedConvo(db, 'convo-keep');
      await seedConvo(db, 'convo-gone');
      await db.deleteConversationData(
        convoId: 'convo-gone',
        keepConversationRow: false,
      );
      await seedConvo(db, 'convo-gone');

      final removed = await db.applyDeletionTombstones();
      expect(removed, 1);
      expect(await db.listEvents('convo-keep'), hasLength(1));
      expect(await db.listEvents('convo-gone'), isEmpty);
    } finally {
      await db.close();
    }
  });

  test('повторное применение ничего не ломает и не считает лишнего', () async {
    // Свип может запуститься не один раз; идемпотентность здесь обязательна,
    // иначе счётчик в журнале начнёт врать о масштабе уборки.
    final db = await AppDb.openForTesting();
    try {
      await seedConvo(db, 'convo-a');
      await db.deleteConversationData(
        convoId: 'convo-a',
        keepConversationRow: false,
      );
      await seedConvo(db, 'convo-a');

      expect(await db.applyDeletionTombstones(), 1);
      expect(
        await db.applyDeletionTombstones(),
        0,
        reason: 'убирать уже нечего — второй заход обязан быть пустым',
      );
    } finally {
      await db.close();
    }
  });

  test('🔴 надгробие уносит и неотправленный конверт этого чата', () async {
    // MSG-01 (26.08.2026). Функция чистила события, реакции и сам чат, а
    // очередь отправки оставляла. Следствие хуже недоставки: чат ушёл с
    // экрана, а его конверты ПРОДОЛЖАЛИ уходить собеседнику — человек уверен,
    // что переписки нет, и всё равно её получают.
    final db = await AppDb.openForTesting();
    try {
      await seedConvo(db, 'convo-a');
      await queueWire(db, 'convo-a', 'wire-a');
      await db.deleteConversationData(
        convoId: 'convo-a',
        keepConversationRow: false,
      );

      // Копия, снятая до удаления, возвращает и чат, и его конверт.
      await seedConvo(db, 'convo-a');
      await queueWire(db, 'convo-a', 'wire-a');
      expect(await db.outboxListForEventRef('evt-convo-a'), hasLength(1));

      expect(await db.applyDeletionTombstones(), 1);
      expect(
        await db.outboxListForEventRef('evt-convo-a'),
        isEmpty,
        reason: 'конверт удалённого чата обязан уйти вместе с ним',
      );
    } finally {
      await db.close();
    }
  });

  test('🔴 конверты ЖИВОГО чата надгробие не трогает', () async {
    // Обратная защёлка, и она здесь важнее прямой: ошибка в условии DELETE
    // молча уничтожит неотправленные сообщения постороннего чата. Такая
    // потеря невидима — очередь не показывают человеку.
    final db = await AppDb.openForTesting();
    try {
      await seedConvo(db, 'convo-keep');
      await queueWire(db, 'convo-keep', 'wire-keep');
      await seedConvo(db, 'convo-gone');
      await queueWire(db, 'convo-gone', 'wire-gone');
      await db.deleteConversationData(
        convoId: 'convo-gone',
        keepConversationRow: false,
      );
      await seedConvo(db, 'convo-gone');
      await queueWire(db, 'convo-gone', 'wire-gone');

      expect(await db.applyDeletionTombstones(), 1);
      expect(
        await db.outboxListForEventRef('evt-convo-keep'),
        hasLength(1),
        reason: 'чужой чат не удаляли — его очередь обязана уцелеть',
      );
      expect(await db.outboxListForEventRef('evt-convo-gone'), isEmpty);
    } finally {
      await db.close();
    }
  });

  test('удаление С СОХРАНЕНИЕМ чата надгробия НЕ ставит', () async {
    // «Очистить переписку» — не то же самое, что «удалить чат». Надгробие тут
    // означало бы, что чат исчезнет после ближайшего восстановления, хотя
    // человек просил только очистить.
    final db = await AppDb.openForTesting();
    try {
      await seedConvo(db, 'convo-a');
      await db.deleteConversationData(
        convoId: 'convo-a',
        keepConversationRow: true,
      );
      expect(await db.deletionsList(), isEmpty);
    } finally {
      await db.close();
    }
  });
}
