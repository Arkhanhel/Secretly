// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/rooms/room_system_event_text.dart';

void main() {
  test('formats ownership transfer role changes and settings updates in English', () {
    final ownershipEvent = SystemEventV1(
      eventId: 'evt-1',
      text: '',
      action: RoomSystemEventAction.ownerTransferred,
      actorProfileId: 'owner-1',
      actorDisplayName: 'Alice',
      targetProfileId: 'peer-1',
      targetDisplayName: 'Bob',
    );
    final settingsEvent = SystemEventV1(
      eventId: 'evt-2',
      text: '',
      action: RoomSystemEventAction.settingsUpdated,
      actorProfileId: 'owner-1',
      actorDisplayName: 'Alice',
      changedKeys: const <String>['join_approval_required', 'slow_mode'],
    );
    final roleEvent = SystemEventV1(
      eventId: 'evt-3',
      text: '',
      action: RoomSystemEventAction.roleChanged,
      actorProfileId: 'owner-1',
      actorDisplayName: 'Alice',
      targetProfileId: 'peer-2',
      targetDisplayName: 'Charlie',
      changedKeys: const <String>['role:moderator'],
    );

    expect(
      formatSystemEventText(ownershipEvent, isRu: false, selfProfileId: 'peer-2'),
      'Alice transferred room ownership to Bob.',
    );
    expect(
      formatSystemEventText(roleEvent, isRu: false, selfProfileId: 'peer-9'),
      'Alice made Charlie a moderator.',
    );
    expect(
      formatSystemEventText(settingsEvent, isRu: false, selfProfileId: 'peer-2'),
      'Alice updated room settings: join approval, slow mode.',
    );
  });

  test('formats self-targeted room system events in Russian', () {
    final addedEvent = SystemEventV1(
      eventId: 'evt-4',
      text: '',
      action: RoomSystemEventAction.memberAdded,
      actorProfileId: 'owner-1',
      actorDisplayName: 'Алиса',
      targetProfileId: 'me-1',
    );

    expect(
      formatSystemEventText(addedEvent, isRu: true, selfProfileId: 'me-1'),
      'Алиса добавил вас.',
    );
  });
}