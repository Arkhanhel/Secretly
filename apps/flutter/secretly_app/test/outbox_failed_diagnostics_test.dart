// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/storage/app_db.dart';

// `failed` — КОНЕЧНОЕ состояние: очередь на отправку берёт только pending,
// retry и sending. В поле 12.08.2026 таких строк было восемь, и по одному числу
// нельзя понять, потерянные это смс или мусор: переотправка минтит НОВЫЙ msg_id
// при том же payload, поэтому содержимое могло уехать другим конвертом.
// Различает только состояние САМОГО события.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now().millisecondsSinceEpoch;

  Future<void> failedRow(
    AppDb db,
    String msgId,
    String eventId,
    String? eventState,
  ) async {
    if (eventState != null) {
      await db.insertEvent(
        eventId: eventId,
        convoId: 'peerA',
        type: 'msg',
        senderDeviceId: 'me',
        ciphertextB64: 'x',
        createdAtMs: now - 60000,
        localState: eventState,
      );
    }
    await db.outboxUpsert(
      msgId: msgId,
      toDeviceId: 'devA',
      ciphertextB64: 'ct',
      ttlSeconds: 604800,
      state: 'failed',
      attemptCount: 5,
      nextRetryAtMs: 0,
      createdAtMs: now - 60000,
      eventIdRef: eventId,
    );
  }

  test('🔴 различает «дошло другим конвертом» и «доставки не видели»', () async {
    final db = await AppDb.openForTesting();
    await failedRow(db, 'm-ok', 'e-ok', 'delivered');
    await failedRow(db, 'm-stuck', 'e-stuck', 'sent');
    final rows = await db.outboxFailedWithEventState();
    final byMsg = {for (final r in rows) r['msg_id']: r['event_state']};
    expect(byMsg['m-ok'], 'delivered', reason: 'мусор в таблице');
    expect(byMsg['m-stuck'], 'sent', reason: 'доставки не видели');
    await db.close();
  });

  test('осиротевшая строка (события нет) видна как таковая', () async {
    final db = await AppDb.openForTesting();
    await failedRow(db, 'm-orphan', 'e-missing', null);
    final rows = await db.outboxFailedWithEventState();
    expect(rows.length, 1);
    expect(rows.first['event_state'], isNull);
    await db.close();
  });

  test('строки в других состояниях не попадают', () async {
    final db = await AppDb.openForTesting();
    await db.outboxUpsert(
      msgId: 'm-pending',
      toDeviceId: 'devA',
      ciphertextB64: 'ct',
      ttlSeconds: 604800,
      state: 'pending',
      attemptCount: 0,
      nextRetryAtMs: 0,
      createdAtMs: now,
    );
    expect(await db.outboxFailedWithEventState(), isEmpty);
    await db.close();
  });

  // ------------------------------------------------------------------
  // MSG-02 (26.08.2026): служебный конверт — не потерянное сообщение.
  //
  // Пинги сессии кладутся в очередь БЕЗ ссылки на событие и живут час; когда
  // собеседник офлайн дольше, они истекают. Это норма. В отчёте они попадали
  // в общий счёт, и `failed: 4` читалось как «четыре сообщения не дошли» —
  // на разбор такой строки в поле ушёл час.
  // ------------------------------------------------------------------

  Map<String, Object?> row({
    String? eventIdRef,
    String? eventState,
    String errorCode = 'ttl_expired',
  }) => <String, Object?>{
    'msg_id': 'm',
    'event_id_ref': eventIdRef,
    'event_state': eventState,
    'last_error_code': errorCode,
    'created_at_ms': now - 3600000,
  };

  test('🔴 служебные конверты не выдаются за потерянные сообщения', () {
    final summary = AppController.formatOutboxFailedSummary([
      row(errorCode: 'ttl_expired'),
      row(errorCode: 'retry_exhausted'),
    ], nowMs: now);
    expect(summary, contains('сообщений 0'));
    expect(summary, contains('служебных 2'));
    expect(
      summary,
      isNot(contains('🔴')),
      reason: 'служебный трафик не имеет права изображать беду',
    );
  });

  test('🔴 осиротевшее СООБЩЕНИЕ остаётся тревожным', () {
    // Пустая ссылка значит «сообщения и не было»; НЕПУСТАЯ ссылка на
    // исчезнувшее событие — след потери, и её прятать нельзя. Если однажды
    // счесть эти случаи одинаковыми, отчёт замолчит именно о том, ради чего
    // его читают.
    final summary = AppController.formatOutboxFailedSummary([
      row(eventIdRef: 'e-gone'),
      row(),
    ], nowMs: now);
    expect(summary, contains('🔴 сообщений 1'));
    expect(summary, contains('осиротело 1'));
    expect(summary, contains('служебных 1'));
  });

  test('сообщение, уехавшее другим конвертом, считается отдельно', () {
    final summary = AppController.formatOutboxFailedSummary([
      row(eventIdRef: 'e-ok', eventState: 'delivered'),
      row(eventIdRef: 'e-stuck', eventState: 'sent'),
    ], nowMs: now);
    expect(summary, contains('дошло другим конвертом 1'));
    expect(summary, contains('доставки не видели 1'));
    expect(summary, contains('служебных 0'));
  });
}
