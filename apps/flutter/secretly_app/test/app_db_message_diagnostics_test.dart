// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_event.dart';
import 'package:secretly_app/calls/call_failure.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/storage/app_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppDb message diagnostics', () {
    test('reschedules stalled outbox sends and records diagnostics', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.insertEvent(
          eventId: 'evt-1',
          convoId: 'convo-1',
          type: 'message',
          senderDeviceId: 'self-device',
          ciphertextB64: 'AA==',
          createdAtMs: 1000,
          localState: MessageLocalState.sending,
        );
        await db.outboxUpsert(
          msgId: 'msg-1',
          toDeviceId: 'peer-device',
          ciphertextB64: 'AA==',
          ttlSeconds: 60,
          state: OutboxSendState.sending,
          attemptCount: 2,
          nextRetryAtMs: 2000,
          createdAtMs: 1000,
          correlationId: 'corr-1',
          convoId: 'convo-1',
          transportHint: 'ws',
          eventIdRef: 'evt-1',
        );

        final recovered = await db.outboxRescheduleStalledSends(
          nowMs: 10000,
          stalledBeforeMs: 9000,
          retryAtMs: 12000,
        );

        expect(recovered, 1);

        final outboxRows = await db.outboxListForEventRef('evt-1');
        expect(outboxRows, hasLength(1));
        expect(outboxRows.first['state'], OutboxSendState.retry);
        expect(outboxRows.first['next_retry_at_ms'], 12000);
        expect(
          outboxRows.first['last_error_code'],
          MessageFailureReason.sendStallTimeout,
        );

        final events = await db.listEvents('convo-1');
        expect(events, hasLength(1));
        expect(events.first['local_state'], MessageLocalState.retry);

        final stateLog = await db.messageStateLogList(localEventId: 'evt-1');
        expect(stateLog, hasLength(1));
        expect(stateLog.first['previous_state'], MessageLocalState.sending);
        expect(stateLog.first['new_state'], MessageLocalState.retry);
        expect(
          stateLog.first['reason_code'],
          MessageFailureReason.sendStallTimeout,
        );

        final attemptLog = await db.messageAttemptLogList(
          localEventId: 'evt-1',
        );
        expect(attemptLog, hasLength(1));
        expect(attemptLog.first['msg_id'], 'msg-1');
        expect(attemptLog.first['transport'], 'ws');
        expect(attemptLog.first['result'], 'stalled_recovered');
        expect(
          attemptLog.first['error_code'],
          MessageFailureReason.sendStallTimeout,
        );

        final snapshots = await db.messageDiagSnapshots(actionableOnly: true);
        final snapshot = snapshots.firstWhere(
          (row) => row['local_event_id'] == 'evt-1',
        );
        expect(snapshot['message_state'], MessageLocalState.retry);
        expect(snapshot['outbox_state_summary'], contains('retry:1'));
        expect(
          snapshot['last_error_code'],
          MessageFailureReason.sendStallTimeout,
        );
      } finally {
        await db.close();
      }
    });

    test('state and attempt log queries return appended diagnostics', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.insertEvent(
          eventId: 'evt-2',
          convoId: 'convo-2',
          type: 'message',
          senderDeviceId: 'self-device',
          ciphertextB64: 'AA==',
          createdAtMs: 2000,
          localState: MessageLocalState.pending,
        );
        await db.outboxUpsert(
          msgId: 'msg-2',
          toDeviceId: 'peer-device',
          ciphertextB64: 'AA==',
          ttlSeconds: 60,
          state: OutboxSendState.pending,
          attemptCount: 0,
          nextRetryAtMs: 2000,
          createdAtMs: 2000,
          correlationId: 'corr-2',
          convoId: 'convo-2',
          eventIdRef: 'evt-2',
        );

        await db.messageStateLogAppend(
          localEventId: 'evt-2',
          previousState: MessageLocalState.pending,
          newState: MessageLocalState.sending,
          reasonCode: MessageFailureReason.manualRetry,
          correlationId: 'corr-2',
          convoId: 'convo-2',
        );
        await db.messageAttemptLogAppend(
          correlationId: 'corr-2',
          localEventId: 'evt-2',
          msgId: 'msg-2',
          toDeviceId: 'peer-device',
          startedAtMs: 2100,
          finishedAtMs: 2400,
          attemptIndex: 1,
          transport: 'http',
          result: 'failed',
          errorCode: MessageFailureReason.relayUnavailable,
          errorMessageRedacted: 'relay unavailable',
          latencyMs: 300,
        );

        final stateLog = await db.messageStateLogList(correlationId: 'corr-2');
        expect(stateLog, hasLength(1));
        expect(stateLog.first['local_event_id'], 'evt-2');
        expect(stateLog.first['new_state'], MessageLocalState.sending);
        expect(stateLog.first['reason_code'], MessageFailureReason.manualRetry);

        final attemptLog = await db.messageAttemptLogList(
          correlationId: 'corr-2',
        );
        expect(attemptLog, hasLength(1));
        expect(attemptLog.first['local_event_id'], 'evt-2');
        expect(attemptLog.first['transport'], 'http');
        expect(attemptLog.first['result'], 'failed');
        expect(
          attemptLog.first['error_code'],
          MessageFailureReason.relayUnavailable,
        );

        final snapshots = await db.messageDiagSnapshots(actionableOnly: true);
        final snapshot = snapshots.firstWhere(
          (row) => row['local_event_id'] == 'evt-2',
        );
        expect(snapshot['message_state'], MessageLocalState.pending);
        expect(snapshot['outbox_state_summary'], contains('pending:1'));
      } finally {
        await db.close();
      }
    });

    test('the first acked outbox row promotes the event, and a partial fanout '
        'stays visible in diagnostics', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.insertEvent(
          eventId: 'evt-multi-send',
          convoId: 'convo-multi-send',
          type: 'message',
          senderDeviceId: 'self-device',
          ciphertextB64: 'AA==',
          createdAtMs: 3000,
          localState: MessageLocalState.pending,
        );
        await db.outboxUpsert(
          msgId: 'msg-multi-send-a',
          toDeviceId: 'peer-device-a',
          ciphertextB64: 'AA==',
          ttlSeconds: 60,
          state: OutboxSendState.pending,
          attemptCount: 0,
          nextRetryAtMs: 3000,
          createdAtMs: 3000,
          correlationId: 'corr-multi-send',
          convoId: 'convo-multi-send',
          eventIdRef: 'evt-multi-send',
        );
        await db.outboxUpsert(
          msgId: 'msg-multi-send-b',
          toDeviceId: 'peer-device-b',
          ciphertextB64: 'AA==',
          ttlSeconds: 60,
          state: OutboxSendState.pending,
          attemptCount: 0,
          nextRetryAtMs: 3000,
          createdAtMs: 3001,
          correlationId: 'corr-multi-send',
          convoId: 'convo-multi-send',
          eventIdRef: 'evt-multi-send',
        );

        // 06.08.2026: первое подтверждение реле уже поднимает сообщение в
        // `sent`. Раньше ждали последнего, и часы на пузыре держала самая
        // медленная копия из рассылки по устройствам собеседника.
        await db.outboxMarkSent('msg-multi-send-a');

        var events = await db.listEvents('convo-multi-send');
        expect(events, hasLength(1));
        expect(events.first['local_state'], MessageLocalState.sent);

        // Неполнота рассылки при этом не исчезает: сообщение с недосланной
        // копией остаётся ДЕЙСТВЕННЫМ для диагностики, хотя на пузыре уже
        // галочка. Именно это и делает правку безопасной.
        final partialSnapshot = (await db.messageDiagSnapshots(
          actionableOnly: true,
        )).firstWhere((row) => row['local_event_id'] == 'evt-multi-send');
        expect(partialSnapshot['outbox_state_summary'], contains('sent:1'));
        expect(partialSnapshot['outbox_state_summary'], contains('pending:1'));

        await db.outboxMarkSent('msg-multi-send-b');

        events = await db.listEvents('convo-multi-send');
        expect(events, hasLength(1));
        expect(events.first['local_state'], MessageLocalState.sent);
      } finally {
        await db.close();
      }
    });

    test(
      'contact device key drift resets sessions and prunes removed devices',
      () async {
        final db = await AppDb.openForTesting();
        try {
          await db.contactDeviceUpsert(
            profileId: 'peer-profile',
            deviceId: 'peer-device-a',
            identityKeyPubB64: 'identity-a',
            signedPrekeyPubB64: 'spk-a',
            signedPrekeySigB64: 'sig-a',
          );
          await db.contactDeviceUpsert(
            profileId: 'peer-profile',
            deviceId: 'peer-device-b',
            identityKeyPubB64: 'identity-b',
            signedPrekeyPubB64: 'spk-b',
            signedPrekeySigB64: 'sig-b',
          );

          await db.sessionUpsert(
            peerDeviceId: 'peer-device-a',
            rootKeyB64: 'AA==',
            sendChainKeyB64: 'AQ==',
            recvChainKeyB64: 'Ag==',
            sendCount: 1,
            recvCount: 1,
          );
          await db.sessionV3Upsert(
            peerDeviceId: 'peer-device-a',
            rootKeyB64: 'AA==',
            dhSelfSeedB64: 'AQ==',
            dhSelfPubB64: 'Ag==',
            dhRemotePubB64: 'Aw==',
            sendChainKeyB64: 'BA==',
            recvChainKeyB64: 'BQ==',
            ns: 1,
            nr: 1,
            pn: 0,
          );
          await db.sessionUpsert(
            peerDeviceId: 'peer-device-b',
            rootKeyB64: 'AA==',
            sendChainKeyB64: 'AQ==',
            recvChainKeyB64: 'Ag==',
            sendCount: 1,
            recvCount: 1,
          );
          await db.sessionV3Upsert(
            peerDeviceId: 'peer-device-b',
            rootKeyB64: 'AA==',
            dhSelfSeedB64: 'AQ==',
            dhSelfPubB64: 'Ag==',
            dhRemotePubB64: 'Aw==',
            sendChainKeyB64: 'BA==',
            recvChainKeyB64: 'BQ==',
            ns: 1,
            nr: 1,
            pn: 0,
          );

          await db.contactDeviceUpsert(
            profileId: 'peer-profile',
            deviceId: 'peer-device-a',
            identityKeyPubB64: 'identity-a',
            signedPrekeyPubB64: 'spk-a-rotated',
            signedPrekeySigB64: 'sig-a-rotated',
          );

          expect(await db.sessionGet('peer-device-a'), isNull);
          expect(await db.sessionV3Get('peer-device-a'), isNull);

          await db.contactDevicesDeleteMissing(
            profileId: 'peer-profile',
            keepDeviceIds: const ['peer-device-a'],
          );

          final rows = await db.contactDevicesList('peer-profile');
          expect(rows.map((row) => row['device_id']), ['peer-device-a']);
          expect(await db.sessionGet('peer-device-b'), isNull);
          expect(await db.sessionV3Get('peer-device-b'), isNull);
        } finally {
          await db.close();
        }
      },
    );

    test(
      'И-4h: contactDevicesDeleteMissing keeps the session when deleteSessions=false',
      () async {
        final db = await AppDb.openForTesting();
        try {
          await db.contactDeviceUpsert(
            profileId: 'peer-profile',
            deviceId: 'peer-device-live',
            identityKeyPubB64: 'id-live',
            signedPrekeyPubB64: 'spk-live',
            signedPrekeySigB64: 'sig-live',
          );
          await db.contactDeviceUpsert(
            profileId: 'peer-profile',
            deviceId: 'peer-device-idle',
            identityKeyPubB64: 'id-idle',
            signedPrekeyPubB64: 'spk-idle',
            signedPrekeySigB64: 'sig-idle',
          );
          await db.sessionV3Upsert(
            peerDeviceId: 'peer-device-idle',
            rootKeyB64: 'AA==',
            dhSelfSeedB64: 'AQ==',
            dhSelfPubB64: 'Ag==',
            dhRemotePubB64: 'Aw==',
            sendChainKeyB64: 'BA==',
            recvChainKeyB64: 'BQ==',
            ns: 1,
            nr: 1,
            pn: 0,
          );
          expect(await db.sessionV3Get('peer-device-idle'), isNotNull);

          // Server liveness list omits the idle device — prune the targeting
          // cache but KEEP the session (И-4h, cause C1).
          await db.contactDevicesDeleteMissing(
            profileId: 'peer-profile',
            keepDeviceIds: const ['peer-device-live'],
            deleteSessions: false,
          );

          final rows = await db.contactDevicesList('peer-profile');
          expect(rows.map((r) => r['device_id']), ['peer-device-live']);
          expect(
            await db.sessionV3Get('peer-device-idle'),
            isNotNull,
            reason: 'И-4h: pruning an idle device must not delete its session',
          );
        } finally {
          await db.close();
        }
      },
    );

    test(
      'contactDevicesDeleteMissing still deletes the session by default (legacy)',
      () async {
        final db = await AppDb.openForTesting();
        try {
          await db.contactDeviceUpsert(
            profileId: 'peer-profile',
            deviceId: 'peer-device-idle',
            identityKeyPubB64: 'id-idle',
            signedPrekeyPubB64: 'spk-idle',
            signedPrekeySigB64: 'sig-idle',
          );
          await db.sessionV3Upsert(
            peerDeviceId: 'peer-device-idle',
            rootKeyB64: 'AA==',
            dhSelfSeedB64: 'AQ==',
            dhSelfPubB64: 'Ag==',
            dhRemotePubB64: 'Aw==',
            sendChainKeyB64: 'BA==',
            recvChainKeyB64: 'BQ==',
            ns: 1,
            nr: 1,
            pn: 0,
          );
          await db.contactDevicesDeleteMissing(
            profileId: 'peer-profile',
            keepDeviceIds: const <String>[],
          );
          expect(await db.sessionV3Get('peer-device-idle'), isNull);
        } finally {
          await db.close();
        }
      },
    );

    test('И-4c: an archiving reset keeps skipped keys; legacy delete wipes them',
        () async {
      final db = await AppDb.openForTesting();
      try {
        await db.sessionV3Upsert(
          peerDeviceId: 'peer-c',
          rootKeyB64: 'AA==',
          dhSelfSeedB64: 'AQ==',
          dhSelfPubB64: 'Ag==',
          dhRemotePubB64: 'Aw==',
          sendChainKeyB64: 'BA==',
          recvChainKeyB64: 'BQ==',
          ns: 1,
          nr: 1,
          pn: 0,
        );
        await db.skippedKeyUpsert(
          peerDeviceId: 'peer-c',
          dhPubB64: 'old-dh',
          msgNum: 5,
          mkB64: 'mk',
        );
        expect(
          await db.skippedKeyGet(
              peerDeviceId: 'peer-c', dhPubB64: 'old-dh', msgNum: 5),
          isNotNull,
        );

        // И-4c: an archiving reset deletes the session but KEEPS the skipped keys
        // so a straggler under the archived old chain still decrypts.
        await db.sessionV3Delete('peer-c', pruneSkippedKeys: false);
        expect(await db.sessionV3Get('peer-c'), isNull);
        expect(
          await db.skippedKeyGet(
              peerDeviceId: 'peer-c', dhPubB64: 'old-dh', msgNum: 5),
          isNotNull,
          reason: 'И-4c: skipped keys must survive an archiving reset',
        );

        // Legacy default still wipes them (device gone / identity rotated).
        await db.sessionV3Delete('peer-c');
        expect(
          await db.skippedKeyGet(
              peerDeviceId: 'peer-c', dhPubB64: 'old-dh', msgNum: 5),
          isNull,
          reason: 'default delete keeps the legacy skipped-key wipe',
        );
      } finally {
        await db.close();
      }
    });

    test('И-4d: archive retains the newest 8 prior sessions (was 3)', () async {
      final db = await AppDb.openForTesting();
      try {
        for (var i = 0; i < 9; i++) {
          await db.sessionV3ArchivePush(
            peerDeviceId: 'peer-x',
            rootKeyB64: 'root-$i',
            dhSelfSeedB64: 'seed-$i',
            dhSelfPubB64: 'self-$i',
            dhRemotePubB64: 'remote-$i',
            sendChainKeyB64: 'sck-$i',
            recvChainKeyB64: 'rck-$i',
            ns: i,
            nr: i,
            pn: 0,
          );
        }
        final rows = await db.sessionV3ArchiveList('peer-x');
        // keepLast=8 → the oldest (root-0) is trimmed, the newest 8 survive and
        // are all returned by the fallback list.
        expect(rows.length, 8);
        final roots = rows.map((r) => r['root_key_b64']).toSet();
        expect(roots.contains('root-0'), isFalse,
            reason: 'oldest archive trimmed at keepLast=8');
        expect(roots.contains('root-8'), isTrue, reason: 'newest archive kept');
      } finally {
        await db.close();
      }
    });

    test('contact device identity drift fails closed and keeps pinned identity', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.contactDeviceUpsert(
          profileId: 'peer-profile',
          deviceId: 'peer-device-a',
          identityKeyPubB64: 'identity-a',
          signedPrekeyPubB64: 'spk-a',
          signedPrekeySigB64: 'sig-a',
        );
        await db.contactDeviceMarkVerified(
          profileId: 'peer-profile',
          deviceId: 'peer-device-a',
        );
        await db.sessionUpsert(
          peerDeviceId: 'peer-device-a',
          rootKeyB64: 'AA==',
          sendChainKeyB64: 'AQ==',
          recvChainKeyB64: 'Ag==',
          sendCount: 1,
          recvCount: 1,
        );
        await db.sessionV3Upsert(
          peerDeviceId: 'peer-device-a',
          rootKeyB64: 'AA==',
          dhSelfSeedB64: 'AQ==',
          dhSelfPubB64: 'Ag==',
          dhRemotePubB64: 'Aw==',
          sendChainKeyB64: 'BA==',
          recvChainKeyB64: 'BQ==',
          ns: 1,
          nr: 1,
          pn: 0,
        );

        await expectLater(
          db.contactDeviceUpsert(
            profileId: 'peer-profile',
            deviceId: 'peer-device-a',
            identityKeyPubB64: 'identity-rotated',
            signedPrekeyPubB64: 'spk-rotated',
            signedPrekeySigB64: 'sig-rotated',
          ),
          throwsStateError,
        );

        final rows = await db.contactDevicesList('peer-profile');
        expect(rows, hasLength(1));
        expect(rows.single['identity_key_pub_b64'], 'identity-a');
        expect(rows.single['verified_at_ms'], isNull);
        expect(await db.sessionGet('peer-device-a'), isNull);
        expect(await db.sessionV3Get('peer-device-a'), isNull);
      } finally {
        await db.close();
      }
    });

    test('call journal persists completed call entries', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.callJournalUpsert(
          entry: const CallJournalEntry(
            callId: 'call-1',
            callAttemptId: 'attempt-1',
            convoId: 'peer-1',
            peerProfileId: 'peer-1',
            direction: CallRecordDirection.outgoing,
            scope: CallRecordScope.oneToOne,
            mediaType: CallRecordMediaType.audio,
            result: CallRecordResult.completed,
            startedAtMs: 1000,
            connectedAtMs: 1500,
            endedAtMs: 5000,
            durationMs: 3500,
            endReason: 'localHangup',
            peerDisplayName: 'Peer',
            peerAvatarPath: null,
            didConnect: true,
            hadVideo: false,
            hadScreenShare: false,
            qualitySummaryJson: '{"quality_level":"good"}',
            createdLocalEventId: 'local:event-1',
            syncedChatEventId: 'event-1',
            acknowledgedAtMs: null,
          ),
        );

        final rows = await db.callJournalList(convoId: 'peer-1');
        expect(rows, hasLength(1));
        expect(rows.first['call_id'], 'call-1');
        expect(rows.first['call_attempt_id'], 'attempt-1');
        expect(rows.first['result'], CallRecordResult.completed.value);
        expect(rows.first['did_connect'], 1);
        expect(rows.first['duration_ms'], 3500);
        expect(rows.first['acknowledged_at_ms'], isNull);
      } finally {
        await db.close();
      }
    });

    test('call journal persists typed failure codes for failed calls', () async {
      final db = await AppDb.openForTesting();
      try {
        await db.callJournalUpsert(
          entry: const CallJournalEntry(
            callId: 'call-3',
            callAttemptId: 'attempt-3',
            convoId: 'peer-3',
            peerProfileId: 'peer-3',
            direction: CallRecordDirection.outgoing,
            scope: CallRecordScope.oneToOne,
            mediaType: CallRecordMediaType.audio,
            result: CallRecordResult.failed,
            startedAtMs: 1000,
            connectedAtMs: null,
            endedAtMs: 4000,
            durationMs: 0,
            endReason: 'error',
            failureCode: CallFailureCode.connectionInterrupted,
            peerDisplayName: 'Peer Three',
            peerAvatarPath: null,
            didConnect: false,
            hadVideo: false,
            hadScreenShare: false,
            qualitySummaryJson: null,
            createdLocalEventId: 'local:event-3',
            syncedChatEventId: 'event-3',
            acknowledgedAtMs: null,
          ),
        );

        final entry = await db.callJournalGetByAttemptId('attempt-3');
        expect(entry, isNotNull);
        expect(entry!.failureCode, CallFailureCode.connectionInterrupted);

        final rows = await db.callJournalList(convoId: 'peer-3');
        expect(rows, hasLength(1));
        expect(rows.first['failure_code'], 'connectionInterrupted');
      } finally {
        await db.close();
      }
    });

    test(
      'missed call acknowledgement is persisted and preserved on upsert',
      () async {
        final db = await AppDb.openForTesting();
        try {
          const missedEntry = CallJournalEntry(
            callId: 'call-2',
            callAttemptId: 'attempt-2',
            convoId: 'peer-2',
            peerProfileId: 'peer-2',
            direction: CallRecordDirection.incoming,
            scope: CallRecordScope.oneToOne,
            mediaType: CallRecordMediaType.audio,
            result: CallRecordResult.missed,
            startedAtMs: 2000,
            connectedAtMs: null,
            endedAtMs: 5000,
            durationMs: 0,
            endReason: 'timeout',
            peerDisplayName: 'Peer Two',
            peerAvatarPath: null,
            didConnect: false,
            hadVideo: false,
            hadScreenShare: false,
            qualitySummaryJson: null,
            createdLocalEventId: 'local:event-2',
            syncedChatEventId: 'event-2',
            acknowledgedAtMs: null,
          );

          await db.callJournalUpsert(entry: missedEntry);
          await db.callJournalMarkMissedAcknowledged(convoId: 'peer-2');

          final acknowledgedRows = await db.callJournalList(convoId: 'peer-2');
          final acknowledgedAtMs =
              (acknowledgedRows.first['acknowledged_at_ms'] as num?)?.toInt();
          expect(acknowledgedAtMs, isNotNull);
          expect(acknowledgedAtMs, greaterThan(0));

          await db.callJournalUpsert(entry: missedEntry);

          final persistedRows = await db.callJournalList(convoId: 'peer-2');
          expect(
            (persistedRows.first['acknowledged_at_ms'] as num?)?.toInt(),
            acknowledgedAtMs,
          );
        } finally {
          await db.close();
        }
      },
    );
  });
}
