// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/calls/call_event.dart';
import 'package:secretly_app/calls/call_failure.dart';
import 'package:secretly_app/calls/call_journal.dart';
import 'package:secretly_app/calls/call_state.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';

void main() {
  test('CallRecordDraft preserves typed failure code in journal entries', () {
    const draft = CallRecordDraft(
      callId: 'call-1',
      callAttemptId: 'attempt-1',
      convoId: 'peer-1',
      peerProfileId: 'peer-1',
      peerDisplayName: 'Peer',
      peerAvatarPath: null,
      direction: CallRecordDirection.outgoing,
      isVideo: false,
      hadScreenShare: false,
      startedAtMs: 1000,
      connectedAtMs: null,
      endedAtMs: 5000,
      endReason: CallEndReason.error,
      failureCode: CallFailureCode.connectionInterrupted,
      qualitySummary: null,
    );

    final entry = draft.toJournalEntry();

    expect(entry.result, CallRecordResult.failed);
    expect(entry.endReason, 'error');
    expect(entry.endReasonValue, CallEndReason.error);
    expect(entry.failureCode, CallFailureCode.connectionInterrupted);
  });

  test('CallEventV1 payload roundtrip preserves failure code', () {
    final payload = E2ePayloadV1(
      senderDeviceId: 'device-1',
      createdAtMs: 5000,
      events: <E2eEventV1>[
        CallEventV1(
          eventId: 'event-1',
          callId: 'call-1',
          callAttemptId: 'attempt-1',
          convoId: 'peer-1',
          direction: CallRecordDirection.outgoing,
          scope: CallRecordScope.oneToOne,
          mediaType: CallRecordMediaType.audio,
          result: CallRecordResult.failed,
          startedAtMs: 1000,
          connectedAtMs: null,
          endedAtMs: 5000,
          durationMs: 0,
          endReason: 'error',
          failureCode: CallFailureCode.signalingConflict,
          participantCount: 2,
          hadVideo: false,
          hadScreenShare: false,
          qualitySummary: null,
        ),
      ],
    );

    final decoded = E2ePayloadV1.decode(payload.encode());
    final event = decoded.events.single as CallEventV1;

    expect(event.endReason, 'error');
    expect(event.failureCode, CallFailureCode.signalingConflict);
  });
}