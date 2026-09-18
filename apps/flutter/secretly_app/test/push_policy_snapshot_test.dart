// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'push policy snapshot includes muted convos quiet hours and per-contact overrides',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settings_notif_background_card_v1': false,
        'settings_notif_privacy_level_v1': 2,
        'settings_notif_private_messages_v1': true,
        'settings_notif_groups_messages_v1': true,
        'chat_notif_v1_group:quiet-room_privacy_level': 0,
        'chat_notif_v1_group:quiet-room_quiet_hours': true,
        'chat_notif_v1_group:quiet-room_quiet_start_hour': 23,
        'chat_notif_v1_group:quiet-room_quiet_end_hour': 7,
        'contact_notif_privacy_level_v1_peer-contact': 1,
        'contact_call_allowed_v1_peer-nocall': false,
      });

      final prefs = await SharedPreferences.getInstance();
      final db = await AppDb.openForTesting();
      final controller = AppController();

      try {
        controller.seedRoomRuntimeForTesting(
          db: db,
          profileId: 'self-profile',
          deviceId: 'self-device',
        );
        await db.convoEnsure1to1(peerProfileId: 'peer-muted');
        await db.convoSetMuted(convoId: 'peer-muted', muted: true);

        final snapshot = await controller.buildPushPolicySnapshotForTesting(
          prefs,
        );

        expect(snapshot['notifications_enabled'], isTrue);
        expect(snapshot['message_visual_alerts_enabled'], isFalse);
        expect(snapshot['direct_message_privacy'], 2);
        expect(snapshot['group_message_privacy'], 2);

        expect(
          snapshot['muted_conversations'],
          containsAll(<String>['peer-muted']),
        );
        expect(
          snapshot['convo_privacy_overrides'],
          <String, Object?>{'group:quiet-room': 0},
        );
        expect(
          snapshot['contact_privacy_overrides'],
          <String, Object?>{'peer-contact': 1},
        );
        expect(
          snapshot['contact_calls_disabled'],
          containsAll(<String>['peer-nocall']),
        );
        expect(
          snapshot['convo_quiet_hours'],
          <String, Object?>{
            'group:quiet-room': <String, Object?>{
              'start_hour': 23,
              'end_hour': 7,
            },
          },
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'push policy snapshot keeps visual alerts enabled when only legacy popup pref is false',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settings_notif_in_app_popup_v1': false,
      });

      final prefs = await SharedPreferences.getInstance();
      final controller = AppController();

      final snapshot = await controller.buildPushPolicySnapshotForTesting(
        prefs,
      );

      expect(snapshot['notifications_enabled'], isTrue);
      expect(snapshot['message_visual_alerts_enabled'], isTrue);
    },
  );
}