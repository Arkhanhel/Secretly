// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/storage/app_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // S1 regression (2026-06-29): when the SENDER is frozen (doze/MIUI) right
  // after enqueue, an outbox row can be left in 'pending' with a future
  // next_retry_at_ms — which outboxLeaseDue (state IN pending/retry/sending AND
  // next_retry_at_ms <= now) skips forever, while the unconditional stall sweep
  // only touches 'sending'/'retry'. outboxRekickStuckPending must re-arm exactly
  // those skipped-and-old pending rows (and nothing else).
  test('outboxRekickStuckPending re-arms only old, pump-skipped pending rows',
      () async {
    final db = await AppDb.openForTesting();
    const now = 1700000000000;

    // STUCK: pending, created 5 min ago, next_retry pushed 1h into the future →
    // the normal lease (next_retry <= now) would never pick it up.
    await db.outboxUpsert(
      msgId: 's1_stuck_future',
      toDeviceId: 'devX',
      ciphertextB64: 'AA==',
      ttlSeconds: 86400,
      state: OutboxSendState.pending,
      attemptCount: 0,
      nextRetryAtMs: now + 3600 * 1000,
      createdAtMs: now - 5 * 60 * 1000,
    );
    // FRESH + DUE: pending, just created, already due → the normal pump handles
    // it. Must NOT be matched (we only target rows the lease would skip).
    await db.outboxUpsert(
      msgId: 's1_fresh_due',
      toDeviceId: 'devY',
      ciphertextB64: 'AA==',
      ttlSeconds: 86400,
      state: OutboxSendState.pending,
      attemptCount: 0,
      nextRetryAtMs: now,
      createdAtMs: now,
    );
    // OLD but already DUE: pending, created long ago, next_retry already <= now
    // → also handled by the normal lease; must NOT be matched.
    await db.outboxUpsert(
      msgId: 's1_old_due',
      toDeviceId: 'devZ',
      ciphertextB64: 'AA==',
      ttlSeconds: 86400,
      state: OutboxSendState.pending,
      attemptCount: 0,
      nextRetryAtMs: now - 1000,
      createdAtMs: now - 10 * 60 * 1000,
    );

    final rearmed = await db.outboxRekickStuckPending(
      nowMs: now,
      stuckBeforeMs: now - 90 * 1000,
    );
    expect(
      rearmed,
      1,
      reason: 'only the old pending row with a FUTURE retry is re-armed',
    );

    // Idempotent: the re-armed row is now due+unlocked, so a second pass matches
    // nothing (no churn).
    final again = await db.outboxRekickStuckPending(
      nowMs: now,
      stuckBeforeMs: now - 90 * 1000,
    );
    expect(again, 0, reason: 're-armed row is now due; no longer stuck');
  });
}
