// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/storage/app_db.dart';

/// FIELD REPORT (2026-07-21): a tester's "send later" message scheduled for
/// 6:25 arrived at 6:10 — fifteen minutes early — at the exact moment a device
/// rotation kicked the convergence resend sweep on the sender's phone.
///
/// Mechanism: a scheduled message is stored with `created_at_ms` = COMPOSE time
/// (so history sorts right) and is flipped to `sent` as soon as the relay
/// accepts it for HOLDING until `scheduled_at_ms`. The resend backstop matched
/// on `created_at_ms` alone, so a still-held schedule looked like "sent but
/// never receipted = stuck" and was pushed out immediately.
///
/// The invariant these tests pin: **the resend backstop may never see a
/// schedule whose time has not come.** A scheduled row's effective send time is
/// its scheduled time.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const convo = 'peer-1';
  // A fixed clock: "now" is 6:20, the schedule fires at 6:25, and the resend
  // backstop considers anything sent before 6:18 to be stuck.
  const composedAtMs = 1000000; // 6:00 — when the user typed it
  const scheduledAtMs = 2500000; // 6:25 — when the relay must release it
  const stuckBeforeMs = 1800000; // 6:18 — resend staleness cutoff

  Future<void> insertScheduledHeldByRelay(AppDb db) async {
    // Exactly what the app writes: composed now, flipped to `sent` once the
    // relay accepted it for holding.
    await db.insertEvent(
      eventId: 'local:sched:1',
      convoId: convo,
      type: 'msg',
      senderDeviceId: 'me',
      ciphertextB64: 'Y2lwaGVy',
      createdAtMs: composedAtMs,
      localState: MessageLocalState.scheduled,
      payloadEventId: 'msg-1',
      scheduledAtMs: scheduledAtMs,
    );
    await db.markScheduledDirectUploaded('local:sched:1');
  }

  test('a scheduled message the relay still holds is NEVER resent early',
      () async {
    final db = await AppDb.openForTesting();
    await insertScheduledHeldByRelay(db);

    final stuck = await db.undeliveredDirectSentEvents(
      convoId: convo,
      stuckBeforeMs: stuckBeforeMs,
    );
    expect(
      stuck,
      isEmpty,
      reason: 'its scheduled time (6:25) has not arrived — releasing it now '
          'would fire the message 15 minutes early',
    );
    await db.close();
  });

  test('once its time has passed, a schedule gets the normal stuck-backstop',
      () async {
    final db = await AppDb.openForTesting();
    await insertScheduledHeldByRelay(db);

    // Same row, but the backstop now runs well after the scheduled instant.
    final stuck = await db.undeliveredDirectSentEvents(
      convoId: convo,
      stuckBeforeMs: scheduledAtMs + 60000,
    );
    expect(
      stuck.length,
      1,
      reason: 'a schedule that fired but earned no receipt must still be '
          'protected by the resend backstop',
    );
    await db.close();
  });

  test('a normal (unscheduled) message keeps the old behaviour', () async {
    final db = await AppDb.openForTesting();
    await db.insertEvent(
      eventId: 'local:plain:1',
      convoId: convo,
      type: 'msg',
      senderDeviceId: 'me',
      ciphertextB64: 'Y2lwaGVy',
      createdAtMs: composedAtMs,
      localState: MessageLocalState.sent,
      payloadEventId: 'msg-2',
    );

    final stuck = await db.undeliveredDirectSentEvents(
      convoId: convo,
      stuckBeforeMs: stuckBeforeMs,
    );
    expect(stuck.length, 1,
        reason: 'unscheduled sends are unaffected by the scheduled guard');
    await db.close();
  });
}
