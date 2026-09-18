// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/messages/outgoing_message_scheduler.dart';
import 'package:secretly_app/storage/app_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OutgoingMessageScheduler', () {
    test('leases due rows, releases them, and recovers stale leases', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.outboxUpsert(
          msgId: 'msg-lease-1',
          toDeviceId: 'peer-1',
          ciphertextB64: 'AA==',
          ttlSeconds: 60,
          state: OutboxSendState.pending,
          attemptCount: 0,
          nextRetryAtMs: 1000,
          createdAtMs: 1000,
        );

        final schedulerA = OutgoingMessageScheduler(
          db: db,
          pumpTransport: () async {},
          workerId: 'worker-a',
        );
        final schedulerB = OutgoingMessageScheduler(
          db: db,
          pumpTransport: () async {},
          workerId: 'worker-b',
        );

        final leasedByA = await db.outboxLeaseDue(
          workerId: schedulerA.workerId,
          nowMs: 5000,
          limit: 10,
        );
        expect(leasedByA, hasLength(1));
        expect(leasedByA.first['msg_id'], 'msg-lease-1');
        expect(leasedByA.first['locked_by_worker'], schedulerA.workerId);

        final leasedByBWhileLocked = await db.outboxLeaseDue(
          workerId: schedulerB.workerId,
          nowMs: 5001,
          limit: 10,
        );
        expect(leasedByBWhileLocked, isEmpty);

        await schedulerA.releaseLease('msg-lease-1');

        final leasedByBAfterRelease = await db.outboxLeaseDue(
          workerId: schedulerB.workerId,
          nowMs: 5002,
          limit: 10,
        );
        expect(leasedByBAfterRelease, hasLength(1));
        expect(
          leasedByBAfterRelease.first['locked_by_worker'],
          schedulerB.workerId,
        );

        final recovered = await schedulerB.recoverStaleLeases(
          nowMs: 5002 + OutgoingMessageScheduler.staleLeaseMs + 1,
        );
        expect(recovered, 1);

        final leasedByAAfterRecovery = await db.outboxLeaseDue(
          workerId: schedulerA.workerId,
          nowMs: 5003 + OutgoingMessageScheduler.staleLeaseMs + 1,
          limit: 10,
        );
        expect(leasedByAAfterRecovery, hasLength(1));
        expect(
          leasedByAAfterRecovery.first['locked_by_worker'],
          schedulerA.workerId,
        );
      } finally {
        await db.close();
      }
    });

    test('leases higher-priority rows before older default-priority rows', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.outboxUpsert(
          msgId: 'msg-default',
          toDeviceId: 'peer-default',
          ciphertextB64: 'AA==',
          ttlSeconds: 60,
          state: OutboxSendState.pending,
          attemptCount: 0,
          nextRetryAtMs: 1000,
          createdAtMs: 1000,
          priority: 0,
        );
        await db.outboxUpsert(
          msgId: 'msg-call-critical',
          toDeviceId: 'peer-call',
          ciphertextB64: 'AA==',
          ttlSeconds: 60,
          state: OutboxSendState.pending,
          attemptCount: 0,
          nextRetryAtMs: 1000,
          createdAtMs: 2000,
          priority: 100,
          transportHint: 'call_signal',
          retryBucket: 'call_critical',
        );

        final scheduler = OutgoingMessageScheduler(
          db: db,
          pumpTransport: () async {},
          workerId: 'worker-priority',
        );

        final leased = await db.outboxLeaseDue(
          workerId: scheduler.workerId,
          nowMs: 5000,
          limit: 10,
        );

        expect(leased, hasLength(2));
        expect(leased.first['msg_id'], 'msg-call-critical');
        expect(leased.last['msg_id'], 'msg-default');
      } finally {
        await db.close();
      }
    });

    test('triggerNow delegates to transport pump', () async {
      final db = await AppDb.openForTesting();
      var pumpCalls = 0;
      try {
        final scheduler = OutgoingMessageScheduler(
          db: db,
          pumpTransport: () async {
            pumpCalls += 1;
          },
          workerId: 'worker-trigger',
        );

        await scheduler.triggerNow();

        expect(pumpCalls, 1);
      } finally {
        await db.close();
      }
    });
  });
}