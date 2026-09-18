// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

/// Backend guarantees for 1:1 "send later" (scheduled) messages:
///  1. [AppDb.listDueScheduledDirectEvents] discovers due 1:1 scheduled
///     placeholders (and only those) so the sweep can fire them — mirroring the
///     group path.
///  2. [AppDb.outboxRekickStuckPending] must NEVER re-arm a row tied to a
///     `scheduled` event. That re-arming was the root cause of "a scheduled 1:1
///     message sends immediately" (a future-dated outbox row got reset to `now`
///     ~90s after it was scheduled), while still rescuing genuinely-stuck rows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'listDueScheduledDirectEvents returns due 1:1 scheduled placeholders only '
      '(excludes future, non-scheduled, groups and requests)', () async {
    final db = await AppDb.openForTesting();
    final now = DateTime.now().millisecondsSinceEpoch;
    final due = now - 1000; // already due
    final future = now + 3600000; // 1h out

    Future<void> put(String id, String convo, String state, int? sched) =>
        db.insertEvent(
          eventId: id,
          convoId: convo,
          type: 'msg',
          senderDeviceId: 'me',
          ciphertextB64: 'x',
          createdAtMs: now,
          localState: state,
          scheduledAtMs: sched,
        );

    await put('d1', 'peerA', 'scheduled', due); // due 1:1 → INCLUDED
    await put('d2', 'peerB', 'scheduled', future); // future → excluded
    await put('d3', 'peerC', 'sent', due); // not scheduled → excluded
    await put('g1', 'group:room1', 'scheduled', due); // group → excluded
    await put('r1', 'req:peerX', 'scheduled', due); // request → excluded

    final ids = (await db.listDueScheduledDirectEvents(nowMs: now))
        .map((r) => r['event_id'] as String)
        .toSet();

    expect(ids, contains('d1'));
    expect(ids, isNot(contains('d2')));
    expect(ids, isNot(contains('d3')));
    expect(ids, isNot(contains('g1')));
    expect(ids, isNot(contains('r1')));

    await db.close();
  });

  test(
      'outboxRekickStuckPending never force-sends a scheduled placeholder row '
      'but still rescues a genuinely-stuck non-scheduled row', () async {
    final db = await AppDb.openForTesting();
    final now = DateTime.now().millisecondsSinceEpoch;
    final oldCreate = now - 5 * 60 * 1000; // older than the 90s stuck window
    final future = now + 3600000;

    // A scheduled 1:1 placeholder event + a legacy-style future outbox row.
    await db.insertEvent(
      eventId: 'ev_sched',
      convoId: 'peerA',
      type: 'msg',
      senderDeviceId: 'me',
      ciphertextB64: 'x',
      createdAtMs: oldCreate,
      localState: 'scheduled',
      scheduledAtMs: future,
    );
    await db.outboxUpsert(
      msgId: 'ob_sched',
      toDeviceId: 'devA',
      ciphertextB64: 'x',
      ttlSeconds: 60,
      state: 'pending',
      attemptCount: 0,
      nextRetryAtMs: future,
      createdAtMs: oldCreate,
      eventIdRef: 'ev_sched',
    );
    // A genuinely-stuck non-scheduled row: pending, future retry, unlinked.
    await db.outboxUpsert(
      msgId: 'ob_stuck',
      toDeviceId: 'devB',
      ciphertextB64: 'x',
      ttlSeconds: 60,
      state: 'pending',
      attemptCount: 0,
      nextRetryAtMs: future,
      createdAtMs: oldCreate,
      eventIdRef: null,
    );

    final rearmed = await db.outboxRekickStuckPending(
      nowMs: now,
      stuckBeforeMs: now - 90 * 1000,
    );

    expect(rearmed, 1, reason: 'only the non-scheduled stuck row is re-armed');

    final dueMsgIds =
        (await db.outboxDue(limit: 50)).map((r) => r['msg_id'] as String).toSet();
    expect(dueMsgIds, contains('ob_stuck'),
        reason: 'a genuinely-stuck non-scheduled row must be rescued to now');
    expect(dueMsgIds, isNot(contains('ob_sched')),
        reason: 'a scheduled placeholder row must NEVER be force-sent early');

    await db.close();
  });
}
