// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secretly_app/storage/app_db.dart';

/// 🔴 СООБЩЕНИЕ НЕ ИМЕЕТ ПРАВА ЗАСТРЯТЬ НАВСЕГДА МЕЖДУ ЗДОРОВЫМИ УСТРОЙСТВАМИ.
///
/// ИНЦИДЕНТ 15–16.08.2026, восстановлен по журналам всех трёх сторон: семь
/// проводов Android→iPhone стояли СУТКИ с одной галочкой. Реле не потеряло ни
/// байта, оба устройства были живы, сегодняшние сообщения между теми же
/// устройствами летали мгновенно.
///
/// Виновато было КОЛЬЦО из четырёх дефектов — каждый по отдельности выглядел
/// разумным решением (ТЗ `docs/TZ_DELIVERY_STUCK_FOREVER_2026-08-16.md`):
///
///   Д-1 «реле пусто» читалось как «доставлено» → заход переотправки глох;
///   Д-2 NACK одноразовый, пауза переигровки глушила и его;
///   Д-3 бюджет считался БЕЗ эпохи → пять копий под МЁРТВОЙ сессией запирали
///       сообщение навсегда;
///   Д-4 все водители живут в бодрствующем отправителе → ночь = ноль попыток.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const maxAttempts = 5;
  const dev = 'dev-peer';
  const ev = 'event-1';

  var dbSeq = 0;
  late Directory tmpDir;
  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('stuck_forever');
  });
  tearDownAll(() async {
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {}
  });
  Future<AppDb> freshDb() =>
      AppDb.openForTesting(path: p.join(tmpDir.path, 'db${dbSeq++}.sqlite'));

  group('Л-1: бюджет живёт в эпохе сессии', () {
    test('🔴 ИНЦИДЕНТ: копии под мёртвой сессией не запирают сообщение', () async {
      final db = await freshDb();

      // Эпоха 1: получатель потерял сессию. Каждая копия ПРИНЯТА реле — и
      // каждая обречена: получатель её паркует. Пять таких копий исчерпали
      // потолок и заперли сообщение навсегда (было до 16.08).
      for (var i = 0; i < maxAttempts; i += 1) {
        await db.resendBudgetConsume(
          eventId: ev,
          deviceId: dev,
          epoch: 1,
          nowMs: 1000 + i,
        );
      }
      expect(
        await db.resendBudgetHasRoom(
          eventId: ev,
          deviceId: dev,
          epoch: 1,
          maxAttempts: maxAttempts,
        ),
        isFalse,
        reason: 'внутри эпохи потолок обязан держать — это защита от шторма',
      );

      // Сессия починилась: сброс + новое рукопожатие = новая эпоха.
      expect(
        await db.resendBudgetHasRoom(
          eventId: ev,
          deviceId: dev,
          epoch: 2,
          maxAttempts: maxAttempts,
        ),
        isTrue,
        reason: 'копии под мёртвой сессией доказывают недоставляемость СЕССИИ, '
            'а не сообщения — после починки сообщение обязано получить ход',
      );
    });

    test('🔴 шторм «одно смс 94 раза» не возвращается: он жил ВНУТРИ эпохи', () async {
      final db = await freshDb();
      for (var i = 0; i < maxAttempts; i += 1) {
        await db.resendBudgetConsume(
          eventId: ev,
          deviceId: dev,
          epoch: 7,
          nowMs: 1000 + i,
        );
      }
      // Сколько ни проси в той же эпохе — потолок держит.
      for (var i = 0; i < 20; i += 1) {
        expect(
          await db.resendBudgetHasRoom(
            eventId: ev,
            deviceId: dev,
            epoch: 7,
            maxAttempts: maxAttempts,
          ),
          isFalse,
        );
      }
    });

    test('эпохи не воруют счёт друг у друга', () async {
      final db = await freshDb();
      await db.resendBudgetConsume(
        eventId: ev,
        deviceId: dev,
        epoch: 1,
        nowMs: 1,
      );
      expect(await db.resendBudgetUsed(eventId: ev, deviceId: dev, epoch: 1), 1);
      expect(await db.resendBudgetUsed(eventId: ev, deviceId: dev, epoch: 2), 0);
    });

    test('🔴 бонус за NACK тоже принадлежит эпохе', () async {
      final db = await freshDb();
      for (var i = 0; i < maxAttempts; i += 1) {
        await db.resendBudgetConsume(
          eventId: ev,
          deviceId: dev,
          epoch: 3,
          nowMs: 1000 + i,
        );
      }
      await db.resendBudgetGrantBonus(
        eventId: ev,
        deviceId: dev,
        epoch: 3,
        maxBonus: 2,
        nowMs: 2000,
      );
      expect(
        await db.resendBudgetHasRoom(
          eventId: ev,
          deviceId: dev,
          epoch: 3,
          maxAttempts: maxAttempts,
        ),
        isTrue,
        reason: 'просьба получателя выше нашей догадки — она добавляет попытку',
      );
    });

    test('списание по подтверждению реле идёт в ТУ эпоху, под которой слали',
        () async {
      // Эпоха запоминается при постановке: пока кадр летел, сессия могла
      // смениться, и списывать надо с того счёта, под которым он шифровался.
      final db = await freshDb();
      await db.resendPendingMark(
        msgId: 'msg-1',
        eventId: ev,
        deviceId: dev,
        epoch: 4,
      );
      expect(
        await db.resendBudgetConsumeForAcceptedMsg(msgId: 'msg-1', nowMs: 5),
        isTrue,
      );
      expect(await db.resendBudgetUsed(eventId: ev, deviceId: dev, epoch: 4), 1);
      expect(await db.resendBudgetUsed(eventId: ev, deviceId: dev, epoch: 9), 0);
    });
  });

  group('🔴 ШТОРМ: сквозной потолок не сбрасывает НИЧТО', () {
    // ПОЛЕ 17–18.08.2026, регрессия моей же правки. Каждый входящий NACK делает
    // `_forceSessionResetPing` (дебаунс 30 с) ⇒ эпоха менялась при каждом
    // NACK ⇒ посуточный счёт начинался заново. Замер реле: копии одного
    // сообщения создавались РОВНО РАЗ В ЧАС по 7 штук, **70 копий** одного
    // письма в ящике. Потолок «5 + бонус 3» превратился из «восемь навсегда» в
    // «восемь в час».
    test('🔴 бесконечная смена эпох НЕ даёт бесконечных копий', () async {
      final db = await freshDb();
      var sent = 0;
      // Сто «лечений» подряд — ровно то, что делал шторм.
      for (var epoch = 1; epoch <= 100; epoch += 1) {
        while (await db.resendBudgetHasRoom(
          eventId: ev,
          deviceId: dev,
          epoch: epoch,
          maxAttempts: maxAttempts,
        )) {
          await db.resendBudgetConsume(
            eventId: ev,
            deviceId: dev,
            epoch: epoch,
            nowMs: 1000 + sent,
          );
          sent += 1;
          if (sent > 500) break; // страховка от вечного цикла в самом тесте
        }
      }
      expect(
        sent,
        AppDb.kResendBudgetAbsoluteMax,
        reason: 'сколько бы раз ни пересобиралась сессия, копий не больше '
            'сквозного потолка — иначе возвращается шторм 70 копий',
      );
    });

    test('🔴 второй шанс после ЛЕЧЕНИЯ сохранён — ради него всё и делалось',
        () async {
      final db = await freshDb();
      for (var i = 0; i < maxAttempts; i += 1) {
        await db.resendBudgetConsume(
          eventId: ev,
          deviceId: dev,
          epoch: 1,
          nowMs: 1000 + i,
        );
      }
      expect(
        await db.resendBudgetHasRoom(
          eventId: ev,
          deviceId: dev,
          epoch: 1,
          maxAttempts: maxAttempts,
        ),
        isFalse,
      );
      expect(
        await db.resendBudgetHasRoom(
          eventId: ev,
          deviceId: dev,
          epoch: 2,
          maxAttempts: maxAttempts,
        ),
        isTrue,
        reason: 'после настоящего лечения сообщение обязано получить ход',
      );
    });

    test('сквозной счёт растёт вместе с посуточным', () async {
      final db = await freshDb();
      await db.resendBudgetConsume(
        eventId: ev,
        deviceId: dev,
        epoch: 1,
        nowMs: 1,
      );
      await db.resendBudgetConsume(
        eventId: ev,
        deviceId: dev,
        epoch: 2,
        nowMs: 2,
      );
      expect(await db.resendBudgetUsed(eventId: ev, deviceId: dev, epoch: 1), 1);
      expect(await db.resendBudgetUsed(eventId: ev, deviceId: dev, epoch: 2), 1);
      expect(
        await db.resendBudgetTotalUsed(eventId: ev, deviceId: dev),
        2,
        reason: 'сквозной счёт видит обе эпохи',
      );
    });

    test('🔴 бонус за NACK не пробивает сквозной потолок', () async {
      final db = await freshDb();
      for (var i = 0; i < AppDb.kResendBudgetAbsoluteMax; i += 1) {
        await db.resendBudgetConsume(
          eventId: ev,
          deviceId: dev,
          epoch: i, // каждая копия под своей эпохой — худший случай
          nowMs: 1000 + i,
        );
      }
      await db.resendBudgetGrantBonus(
        eventId: ev,
        deviceId: dev,
        epoch: 999,
        maxBonus: 3,
        nowMs: 5000,
      );
      expect(
        await db.resendBudgetHasRoom(
          eventId: ev,
          deviceId: dev,
          epoch: 999,
          maxAttempts: maxAttempts,
        ),
        isFalse,
        reason: 'просьба получателя не отменяет сквозной предел',
      );
    });
  });

  group('Л-3: «реле пусто» даёт РОВНО одну пере-шифровку за эпоху', () {
    test('🔴 второй раз в той же эпохе — отказ (кран не открывается)', () async {
      final db = await freshDb();
      expect(
        await db.resendHeldZeroClaimOnce(
          eventId: ev,
          deviceId: dev,
          epoch: 1,
        ),
        isTrue,
      );
      expect(
        await db.resendHeldZeroClaimOnce(
          eventId: ev,
          deviceId: dev,
          epoch: 1,
        ),
        isFalse,
        reason: 'иначе пустое реле превращается в бесконечный источник копий',
      );
    });

    test('новая эпоха выдаёт новое разрешение', () async {
      final db = await freshDb();
      await db.resendHeldZeroClaimOnce(eventId: ev, deviceId: dev, epoch: 1);
      expect(
        await db.resendHeldZeroClaimOnce(
          eventId: ev,
          deviceId: dev,
          epoch: 2,
        ),
        isTrue,
      );
    });

    test('разные события считаются порознь', () async {
      final db = await freshDb();
      await db.resendHeldZeroClaimOnce(eventId: ev, deviceId: dev, epoch: 1);
      expect(
        await db.resendHeldZeroClaimOnce(
          eventId: 'event-2',
          deviceId: dev,
          epoch: 1,
        ),
        isTrue,
      );
    });
  });

  group('Л-4: вечная одна галочка становится видимой', () {
    test('🔴 событие в «sent» помечается недоставленным', () async {
      final db = await freshDb();
      await db.insertEvent(
        eventId: 'e-1',
        convoId: 'peer-1',
        type: 'msg',
        senderDeviceId: 'me',
        ciphertextB64: 'AAAA',
        createdAtMs: 1000,
        localState: 'sent',
        payloadEventId: 'p-1',
      );

      expect(await db.eventMarkFailedIfStillSent('e-1'), isTrue);
      final rows = await db.eventsByPayloadEventId(
        convoId: 'peer-1',
        payloadEventId: 'p-1',
      );
      expect(rows.single['local_state'], 'failed');
    });

    test('🔴 доставленное НЕ трогаем — иначе соврём в другую сторону', () async {
      final db = await freshDb();
      await db.insertEvent(
        eventId: 'e-2',
        convoId: 'peer-1',
        type: 'msg',
        senderDeviceId: 'me',
        ciphertextB64: 'AAAA',
        createdAtMs: 1000,
        localState: 'delivered',
        payloadEventId: 'p-2',
      );

      expect(await db.eventMarkFailedIfStillSent('e-2'), isFalse);
      final rows = await db.eventsByPayloadEventId(
        convoId: 'peer-1',
        payloadEventId: 'p-2',
      );
      expect(rows.single['local_state'], 'delivered');
    });

    test('пометка идемпотентна — второй раз отвечает «нечего менять»', () async {
      final db = await freshDb();
      await db.insertEvent(
        eventId: 'e-3',
        convoId: 'peer-1',
        type: 'msg',
        senderDeviceId: 'me',
        ciphertextB64: 'AAAA',
        createdAtMs: 1000,
        localState: 'sent',
      );
      expect(await db.eventMarkFailedIfStillSent('e-3'), isTrue);
      expect(await db.eventMarkFailedIfStillSent('e-3'), isFalse);
    });
  });

  group('Л-2: пере-NACK ограничен паузой переигровки', () {
    test('🔴 клеймо со сроком отпускает конверт через час', () async {
      final db = await freshDb();
      const hour = 60 * 60 * 1000;
      await db.inboxQuarantineUpsert(
        msgId: 'm-1',
        ciphertextB64: 'AAAA',
        senderDeviceId: 'dev-x',
        nowMs: 1000,
      );

      expect(
        await db.inboxQuarantineClaimNack(msgId: 'm-1', nowMs: 1000),
        isTrue,
      );
      // Сразу следом — нельзя: иначе пере-NACK превращается в шторм.
      expect(
        await db.inboxQuarantineClaimNack(
          msgId: 'm-1',
          nowMs: 1000 + 60 * 1000,
          reNackAfterMs: hour,
        ),
        isFalse,
      );
      // Через час — можно: получатель снова говорит «я всё ещё не могу это
      // прочитать», и отправитель, открывший приложение, чинит всё разом.
      expect(
        await db.inboxQuarantineClaimNack(
          msgId: 'm-1',
          nowMs: 1000 + hour + 1,
          reNackAfterMs: hour,
        ),
        isTrue,
      );
    });
  });
}
