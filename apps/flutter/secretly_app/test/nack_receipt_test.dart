// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';

// TZ Epic A1 (2026-07-18): rollout-safety contract of the NACK receipt.
// A pre-Epic-A client must stay completely inert on `nack_undecryptable`,
// and the wire form must round-trip refKind for new clients.
void main() {
  test('nack status never promotes/demotes the delivered-read progression', () {
    expect(MessageReceiptState.rank(MessageReceiptState.nackUndecryptable), 0);
    // A nack can never overwrite delivered/read state...
    expect(
      MessageReceiptState.canPromote(
        from: MessageReceiptState.delivered,
        to: MessageReceiptState.nackUndecryptable,
      ),
      isFalse,
    );
    expect(
      MessageReceiptState.canPromote(
        from: MessageReceiptState.read,
        to: MessageReceiptState.nackUndecryptable,
      ),
      isFalse,
    );
  });

  test('ReceiptEventV1 round-trips refKind and stays optional', () {
    final payload = E2ePayloadV1(
      senderDeviceId: 'dev-a',
      createdAtMs: 1000,
      events: [
        ReceiptEventV1(
          eventId: 'r1',
          refEventId: 'relay-msg-77',
          status: MessageReceiptState.nackUndecryptable,
          refKind: 'msg_id',
        ),
        ReceiptEventV1(
          eventId: 'r2',
          refEventId: 'payload-evt-5',
          status: MessageReceiptState.delivered,
        ),
      ],
    );
    final decoded = E2ePayloadV1.decode(payload.encode());
    final rcpts = decoded.events.whereType<ReceiptEventV1>().toList();
    expect(rcpts, hasLength(2));
    expect(rcpts[0].status, MessageReceiptState.nackUndecryptable);
    expect(rcpts[0].refKind, 'msg_id');
    expect(rcpts[0].refEventId, 'relay-msg-77');
    // Legacy receipt: refKind absent both in object and on the wire.
    expect(rcpts[1].refKind, isNull);
  });

  test('legacy decoder shape: unknown receipt status is representable', () {
    // Simulates a FUTURE status arriving at THIS client: decode must not
    // throw, and normalize/rank must treat it as inert (rank 0).
    final payload = E2ePayloadV1(
      senderDeviceId: 'dev-a',
      createdAtMs: 1000,
      events: [
        ReceiptEventV1(
          eventId: 'r3',
          refEventId: 'x',
          status: 'some_future_status',
        ),
      ],
    );
    final decoded = E2ePayloadV1.decode(payload.encode());
    final rcpt = decoded.events.whereType<ReceiptEventV1>().single;
    expect(MessageReceiptState.rank(rcpt.status), 0);
    expect(
      MessageReceiptState.normalize(rcpt.status),
      isNot(MessageReceiptState.delivered),
    );
  });
}
