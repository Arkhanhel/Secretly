// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/storage/app_db.dart';

// Осиротевшая парковка (06.08.2026, полевой шторм после восстановления).
//
// ЧТО СЛУЧИЛОСЬ. Провод, который однажды не удалось применить, паркуется в
// карантин, подтверждается реле и помечается пройденным. Следующая доставка
// того же msg_id применилась — содержимое на месте, журнал спасения удалён.
// А карантинная строка ОСТАВАЛАСЬ: её снимали только при успехе ПОВТОРА.
//
// Но успешным повтор быть уже не мог: ключ сообщения одноразовый, журнал стёрт.
// Свип перемалывал сироту вечно, и каждый заход давал НАСТОЯЩИЙ MAC-сбой,
// который шёл в счётчики поломки сессии и в отрицательные квитанции. Замер по
// полю: 11 проводов дали 106 «сбоев расшифровки» за пять минут, и здоровая
// сессия объявлялась сломанной из-за давно прочитанных сообщений.
//
// 🔴 ПОЧЕМУ НЕЛЬЗЯ БЫЛО ЧИНИТЬ «ПРОВЕРКОЙ ПО inbox_seen». Соблазн очевидный:
// пропускать повтор, если msg_id уже помечен пройденным. Но `inboxMarkSeen`
// ставится И ПРИ ПАРКОВКЕ (relay_client.dart:3348) — отметка означает «курсор
// реле прошёл мимо», а не «содержимое применено». Такая правка выбросила бы
// ровно то недоставленное, ради которого карантин и существует.
//
// Верный признак один: содержимое ПРИМЕНЕНО. Тогда парковка избыточна по
// определению, и снимать её безопасно.

const String parkedMsg = 'msg-parked';
const String freshMsg = 'msg-never-parked';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('снятие парковки сообщает, была ли она вообще', () async {
    // Контракт, на который опирается журнал: холостое снятие не должно
    // выглядеть как снятие настоящей парковки, иначе в поле не отличить
    // «сирота убрана» от «убирать было нечего».
    final db = await AppDb.openForTesting();
    try {
      await db.inboxQuarantineUpsert(
        msgId: parkedMsg,
        senderDeviceId: 'peer-device',
        ciphertextB64: 'AA==',
        nowMs: 1000,
      );

      expect(
        await db.inboxQuarantineDelete(parkedMsg),
        isTrue,
        reason: 'строка была — снятие настоящее',
      );
      expect(
        await db.inboxQuarantineDelete(parkedMsg),
        isFalse,
        reason: 'повторное снятие уже ничего не убирает',
      );
      expect(
        await db.inboxQuarantineDelete(freshMsg),
        isFalse,
        reason: 'провод, которого там не было, тоже не считается',
      );
    } finally {
      await db.close();
    }
  });

  test('парковка идемпотентна по msg_id и переживает повторную доставку', () async {
    // Основание для правки: одна и та же доставка приходит по нескольку раз,
    // и парковка обязана оставаться ОДНОЙ строкой — иначе снятие по msg_id
    // убирало бы лишь одну из копий, а остальные продолжали бы шторм.
    final db = await AppDb.openForTesting();
    try {
      for (var i = 0; i < 3; i++) {
        await db.inboxQuarantineUpsert(
          msgId: parkedMsg,
          senderDeviceId: 'peer-device',
          ciphertextB64: 'AA==',
          nowMs: 1000 + i,
        );
      }
      final parked = await db.inboxQuarantineListForSender('peer-device');
      expect(parked, hasLength(1));

      expect(await db.inboxQuarantineDelete(parkedMsg), isTrue);
      expect(
        await db.inboxQuarantineListForSender('peer-device'),
        isEmpty,
        reason: 'одно снятие обязано убирать парковку целиком',
      );
    } finally {
      await db.close();
    }
  });

  test('счётчик попыток лежит в столбце `attempts` и реально растёт', () async {
    // Защёлка против тихой ошибки по имени столбца. Читали `attempt_count` —
    // столбец ИСХОДЯЩЕЙ очереди, которого у парковки нет. Map отвечает на
    // неизвестный ключ null, `?? 0` делает из этого законный ноль, и порог
    // отставки в 3 попытки становился недостижим НАВСЕГДА. Полевое
    // подтверждение: 11 сирот, 106 повторов, ноль отставок.
    final db = await AppDb.openForTesting();
    try {
      await db.inboxQuarantineUpsert(
        msgId: parkedMsg,
        senderDeviceId: 'peer-device',
        ciphertextB64: 'AA==',
        nowMs: 1000,
      );
      for (var i = 1; i <= 3; i++) {
        await db.inboxQuarantineMarkAttempt(msgId: parkedMsg, nowMs: 1000 + i);
      }

      final row = (await db.inboxQuarantineListForSender('peer-device')).single;
      expect(
        row.containsKey('attempt_count'),
        isFalse,
        reason: 'такого столбца у парковки нет — читать его значит читать ноль',
      );
      expect((row['attempts'] as num?)?.toInt(), 3);
    } finally {
      await db.close();
    }
  });

  test('отметка «пройдено» НЕ означает «применено» — на неё опираться нельзя', () async {
    // Защёлка против повторения ошибки: если кто-то однажды решит пропускать
    // повтор карантина по `inboxHasSeen`, этот тест покажет, что признак лжёт —
    // припаркованный (то есть НЕ применённый) провод помечен пройденным.
    final db = await AppDb.openForTesting();
    try {
      await db.inboxQuarantineUpsert(
        msgId: parkedMsg,
        senderDeviceId: 'peer-device',
        ciphertextB64: 'AA==',
        nowMs: 1000,
      );
      // Ровно то, что делает транспорт при парковке: подтвердить и пометить.
      await db.inboxMarkSeen(parkedMsg);

      expect(await db.inboxHasSeen(parkedMsg), isTrue);
      expect(
        await db.inboxQuarantineListForSender('peer-device'),
        hasLength(1),
        reason: 'помечен пройденным, но содержимое НЕ применено — '
            'значит «пройдено» не годится как признак применённости',
      );
    } finally {
      await db.close();
    }
  });
}
