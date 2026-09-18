// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('event queries keep deterministic order for identical timestamps', () async {
    final db = await AppDb.openForTesting();
    try {
      for (final eventId in const ['evt-1', 'evt-2', 'evt-3']) {
        await db.insertEvent(
          eventId: eventId,
          convoId: 'convo-1',
          type: 'msg',
          senderDeviceId: 'peer-device',
          ciphertextB64: 'AA==',
          createdAtMs: 1000,
          localState: 'received',
        );
      }

      final chronological = await db.listEventsChronological(
        'convo-1',
        limit: 10,
      );
      expect(
        chronological.map((row) => row['event_id'] as String?).toList(),
        orderedEquals(['evt-1', 'evt-2', 'evt-3']),
      );

      final newestFirst = await db.listEvents('convo-1', limit: 10);
      expect(
        newestFirst.map((row) => row['event_id'] as String?).toList(),
        orderedEquals(['evt-3', 'evt-2', 'evt-1']),
      );
    } finally {
      await db.close();
    }
  });

  test('clearConversationHistoryUpTo preserves room membership metadata', () async {
    final db = await AppDb.openForTesting();
    try {
      await db.convoEnsureGroup(groupId: 'group:alpha', title: 'Alpha');
      await db.groupMemberEnsure(
        groupId: 'group:alpha',
        memberProfileId: 'member-1',
      );
      await db.insertEvent(
        eventId: 'evt-1',
        convoId: 'group:alpha',
        type: 'msg',
        senderDeviceId: 'peer-device',
        ciphertextB64: 'AA==',
        createdAtMs: 1000,
        localState: 'received',
      );
      await db.insertEvent(
        eventId: 'evt-2',
        convoId: 'group:alpha',
        type: 'msg',
        senderDeviceId: 'peer-device',
        ciphertextB64: 'AA==',
        createdAtMs: 2000,
        localState: 'received',
      );

      await db.clearConversationHistoryUpTo(
        convoId: 'group:alpha',
        cutoffCreatedAtMs: 1500,
      );

      final remaining = await db.listEventsChronological(
        'group:alpha',
        limit: 10,
      );
      expect(
        remaining.map((row) => row['event_id'] as String?).toList(),
        orderedEquals(<String?>['evt-2']),
      );

      final members = await db.groupMembersList('group:alpha');
      expect(
        members.map((row) => row['member_profile_id'] as String?).toList(),
        contains('member-1'),
      );
    } finally {
      await db.close();
    }
  });
}