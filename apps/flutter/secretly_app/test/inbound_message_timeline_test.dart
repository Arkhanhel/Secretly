// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/storage/app_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'incoming direct messages keep sender timeline order across delayed delivery',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      Future<void> deliver({
        required String transportMsgId,
        required String payloadEventId,
        required String text,
        required int payloadCreatedAtMs,
        required int receivedAtMs,
      }) async {
        final payload = E2ePayloadV1(
          senderDeviceId: 'peer-device-1',
          createdAtMs: payloadCreatedAtMs,
          events: [MsgEventV1(eventId: payloadEventId, text: text)],
        );

        final handled = await controller.handleDecryptedInboundPayloadForTesting(
          db: db,
          msgId: transportMsgId,
          ciphertextB64: 'AA==',
          plainBytes: Uint8List.fromList(payload.encode()),
          payload: payload,
          senderDeviceId: 'peer-device-1',
          senderProfileId: 'peer-1',
          nowMs: receivedAtMs,
        );

        expect(handled, isTrue);
      }

      try {
        await db.contactUpsert(profileId: 'peer-1', displayName: 'Peer 1');

        await deliver(
          transportMsgId: 'transport-3',
          payloadEventId: 'payload-3',
          text: 'third',
          payloadCreatedAtMs: 3000,
          receivedAtMs: 9000,
        );
        await deliver(
          transportMsgId: 'transport-1',
          payloadEventId: 'payload-1',
          text: 'first',
          payloadCreatedAtMs: 1000,
          receivedAtMs: 9001,
        );
        await deliver(
          transportMsgId: 'transport-2',
          payloadEventId: 'payload-2',
          text: 'second',
          payloadCreatedAtMs: 2000,
          receivedAtMs: 9002,
        );

        final rows = await db.listEventsChronological('peer-1', limit: 10);
        expect(
          rows.map((row) => row['payload_event_id'] as String?).toList(),
          orderedEquals(['payload-1', 'payload-2', 'payload-3']),
        );
        expect(
          rows
              .map((row) => (row['created_at_ms'] as num?)?.toInt())
              .toList(),
          orderedEquals([1000, 2000, 3000]),
        );

        final convo = await db.convoGet('peer-1');
        expect(
          (convo?['last_event_at_ms'] as num?)?.toInt(),
          greaterThanOrEqualTo(9002),
        );
      } finally {
        await db.close();
      }
    },
  );
}