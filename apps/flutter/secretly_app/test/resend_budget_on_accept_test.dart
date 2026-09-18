// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secretly_app/storage/app_db.dart';

/// 🔴 БЮДЖЕТ ПЕРЕОТПРАВКИ СПИСЫВАЕТСЯ ПО ПОДТВЕРЖДЕНИЮ РЕЛЕ.
///
/// ЗАМЕР ПРОДА 15.08: у владельца пять попыток сгорели в яме `429`, не отправив
/// НИ ОДНОГО кадра. Сообщения застряли на телефоне навсегда — при каждом
/// следующем проходе `resend_budget_spent`, и уйти они уже не могли.
///
/// Замысел потолка сохранён: пять доставок ДО РЕЛЕ остаются пределом, поэтому
/// шторм с 94 копиями (прод, 01.08) вернуться не может. Исправлена граница:
/// очередь — это ещё дом, а не отправка.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const maxAttempts = 5;
  const dev = 'dev-1';
  const ev = 'event-1';

  // 🔴 СВОЯ БАЗА НА КАЖДЫЙ ТЕСТ. `openForTesting()` без пути отдаёт ОБЩУЮ базу
  // в памяти, и состояние перетекает между тестами: исчерпанный в одном тесте
  // бюджет ронял следующий. Тест, зависящий от соседа, ничего не доказывает.
  var dbSeq = 0;
  late Directory tmpDir;
  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('resend_budget');
  });
  tearDownAll(() async {
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {}
  });
  Future<AppDb> freshDb() =>
      AppDb.openForTesting(path: p.join(tmpDir.path, 'db${dbSeq++}.sqlite'));

  test('🔴 кадр, НЕ принятый реле, бюджета не стоит', () async {
    final db = await freshDb();

    // Пять проходов переотправки: кадр ставится в очередь и погибает в сети.
    for (var i = 0; i < 5; i += 1) {
      expect(
        await db.resendBudgetHasRoom(
          eventId: ev,
          deviceId: dev,
          epoch: 0,
          maxAttempts: maxAttempts,
        ),
        isTrue,
        reason: 'попытка ${i + 1}: бюджет не должен таять без подтверждения',
      );
      await db.resendPendingMark(msgId: 'msg-$i', eventId: ev, deviceId: dev, epoch: 0);
      // Подтверждения нет — реле кадра не видело.
    }

    expect(
      await db.resendBudgetHasRoom(
        eventId: ev,
        deviceId: dev,
        epoch: 0,
        maxAttempts: maxAttempts,
      ),
      isTrue,
      reason: 'ПЯТЬ несостоявшихся отправок не имеют права запереть сообщение',
    );
  });

  test('🔴 принятый реле кадр бюджет ТРАТИТ — потолок остаётся', () async {
    final db = await freshDb();

    for (var i = 0; i < maxAttempts; i += 1) {
      expect(
        await db.resendBudgetHasRoom(
          eventId: ev,
          deviceId: dev,
          epoch: 0,
          maxAttempts: maxAttempts,
        ),
        isTrue,
      );
      await db.resendPendingMark(msgId: 'msg-$i', eventId: ev, deviceId: dev, epoch: 0);
      final spent = await db.resendBudgetConsumeForAcceptedMsg(
        msgId: 'msg-$i',
        nowMs: 1000 + i,
      );
      expect(spent, isTrue);
    }

    expect(
      await db.resendBudgetHasRoom(
        eventId: ev,
        deviceId: dev,
        epoch: 0,
        maxAttempts: maxAttempts,
      ),
      isFalse,
      reason: 'после пяти ДОСТАВЛЕННЫХ копий переотправка обязана остановиться',
    );
  });

  test('первичная отправка (без отметки) бюджета не трогает', () async {
    final db = await freshDb();

    final spent = await db.resendBudgetConsumeForAcceptedMsg(
      msgId: 'обычное-сообщение',
      nowMs: 1,
    );

    expect(spent, isFalse);
    expect(
      await db.resendBudgetHasRoom(
        eventId: ev,
        deviceId: dev,
        epoch: 0,
        maxAttempts: maxAttempts,
      ),
      isTrue,
    );
  });

  test('повторное подтверждение того же кадра не списывает дважды', () async {
    final db = await freshDb();
    await db.resendPendingMark(msgId: 'msg-x', eventId: ev, deviceId: dev, epoch: 0);

    expect(
      await db.resendBudgetConsumeForAcceptedMsg(msgId: 'msg-x', nowMs: 1),
      isTrue,
    );
    expect(
      await db.resendBudgetConsumeForAcceptedMsg(msgId: 'msg-x', nowMs: 2),
      isFalse,
      reason: 'отметка снята — второй раз платить не за что',
    );
  });

  test('кадр, умерший в очереди, отметку отпускает без списания', () async {
    final db = await freshDb();
    await db.resendPendingMark(msgId: 'msg-y', eventId: ev, deviceId: dev, epoch: 0);
    await db.resendPendingDrop('msg-y');

    expect(
      await db.resendBudgetConsumeForAcceptedMsg(msgId: 'msg-y', nowMs: 3),
      isFalse,
    );
  });

  group('разовая амнистия', () {
    test('🔴 возвращает бюджет застрявшим за последнюю неделю', () async {
      final db = await freshDb();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Исчерпали бюджет «по-старому» — так выглядят сообщения владельца.
      for (var i = 0; i < maxAttempts; i += 1) {
        await db.resendBudgetConsume(eventId: ev, deviceId: dev, epoch: 0, nowMs: nowMs);
      }
      expect(
        await db.resendBudgetHasRoom(
          eventId: ev,
          deviceId: dev,
          epoch: 0,
          maxAttempts: maxAttempts,
        ),
        isFalse,
      );

      final healed = await db.resendBudgetAmnestyOnce(nowMs: nowMs);

      expect(healed, 1);
      expect(
        await db.resendBudgetHasRoom(
          eventId: ev,
          deviceId: dev,
          epoch: 0,
          maxAttempts: maxAttempts,
        ),
        isTrue,
        reason: 'застрявшее сообщение обязано получить возможность уйти',
      );
    });

    test('🔴 выполняется РОВНО ОДИН раз', () async {
      final db = await freshDb();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.resendBudgetConsume(eventId: ev, deviceId: dev, epoch: 0, nowMs: nowMs);

      expect(await db.resendBudgetAmnestyOnce(nowMs: nowMs), 1);
      expect(
        await db.resendBudgetAmnestyOnce(nowMs: nowMs),
        0,
        reason: 'повторная амнистия на каждом запуске = бесконечные переотправки',
      );
    });

    test('🔴 старое НЕ воскрешает — это был бы шторм', () async {
      final db = await freshDb();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final oldMs = nowMs - const Duration(days: 30).inMilliseconds;
      await db.resendBudgetConsume(eventId: ev, deviceId: dev, epoch: 0, nowMs: oldMs);

      expect(await db.resendBudgetAmnestyOnce(nowMs: nowMs), 0);
    });
  });
}
