// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/storage/app_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loadEvents falls back from legacy device convo to profile convo',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      try {
        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'self-profile',
          deviceId: 'self-device',
        );
        await db.deviceProfileUpsert(
          deviceId: 'peer-device-1',
          profileId: 'peer-profile-1',
        );
        await db.convoEnsure1to1(peerProfileId: 'peer-profile-1');
        await db.insertEvent(
          eventId: 'local:msg-1',
          convoId: 'peer-profile-1',
          type: 'msg',
          senderDeviceId: 'self-device',
          ciphertextB64: 'AA==',
          createdAtMs: 1000,
          localState: 'pending',
          payloadEventId: 'payload-1',
        );

        final events = await controller.loadEvents('dev:peer-device-1');

        expect(events, hasLength(1));
        expect(events.first.eventId, 'local:msg-1');
        expect(events.first.payloadEventId, 'payload-1');
      } finally {
        await db.close();
      }
    },
  );

  test(
    'loadEvents falls back from merged request convo to direct convo',
    () async {
      final controller = AppController();
      final db = await AppDb.openForTesting();

      try {
        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'self-profile',
          deviceId: 'self-device',
        );
        await db.convoEnsure1to1(peerProfileId: 'peer-profile-1');
        await db.insertEvent(
          eventId: 'local:msg-2',
          convoId: 'peer-profile-1',
          type: 'msg',
          senderDeviceId: 'self-device',
          ciphertextB64: 'AA==',
          createdAtMs: 2000,
          localState: 'pending',
          payloadEventId: 'payload-2',
        );

        final events = await controller.loadEvents('req:peer-profile-1');

        expect(events, hasLength(1));
        expect(events.first.eventId, 'local:msg-2');
        expect(events.first.payloadEventId, 'payload-2');
      } finally {
        await db.close();
      }
    },
  );

  test(
    'requestAccept merges request into existing direct conversation',
    () async {
      final db = await AppDb.openForTesting();

      try {
        await db.convoEnsure1to1(peerProfileId: 'peer-profile-1');
        await db.convoTouch(convoId: 'peer-profile-1', atMs: 100);
        await db.requestUpsert(profileId: 'peer-profile-1', status: 'pending');
        await db.convoEnsureRequest(peerProfileId: 'peer-profile-1');
        await db.convoTouch(convoId: 'req:peer-profile-1', atMs: 2000);
        await db.insertEvent(
          eventId: 'request-msg-1',
          convoId: 'req:peer-profile-1',
          type: 'msg',
          senderDeviceId: 'peer-device-1',
          ciphertextB64: 'AA==',
          createdAtMs: 2000,
          payloadEventId: 'payload-request-1',
        );

        await db.requestAccept(profileId: 'peer-profile-1');

        expect(await db.requestStatus('peer-profile-1'), isNull);
        expect(await db.convoGet('req:peer-profile-1'), isNull);

        final directConvo = await db.convoGet('peer-profile-1');
        expect(directConvo, isNotNull);
        expect(
          (directConvo!['last_event_at_ms'] as num).toInt(),
          greaterThanOrEqualTo(2000),
        );

        final conversations = await db.convoList(limit: 10);
        expect(
          conversations.where(
            (row) => (row['convo_id'] as String).startsWith('req:'),
          ),
          isEmpty,
        );

        final directEvents = await db.listEventsChronological(
          'peer-profile-1',
          limit: 10,
        );
        expect(directEvents, hasLength(1));
        expect(directEvents.single['event_id'], 'request-msg-1');
      } finally {
        await db.close();
      }
    },
  );
}
