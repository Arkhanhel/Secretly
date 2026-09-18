// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/room_invite_join_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets(
    'room invite join screen uses neutral approval copy and normalizes elevated invite roles',
    (WidgetTester tester) async {
      const target = RoomInviteTarget(
        slug: 'alpha',
        inviterProfileId: 'owner-1',
        groupIdHint: 'group:alpha',
      );
      final controller = _FakeRoomInviteJoinController(
        preview: RoomInvitePreview(
          target: target,
          groupId: 'group:alpha',
          groupTitle: 'Alpha Room',
          description: 'Private room',
          inviterDisplayName: 'Owner',
          memberCount: 4,
          isAlreadyMember: false,
          joinApprovalRequired: true,
          viewerMembershipStatus: null,
          chatHistoryVisible: false,
          allowedRole: RoomMemberRole.admin,
          expiresAtMs: null,
          maxUses: null,
          remainingUses: null,
          avatarPath: null,
          avatarHash: null,
          avatarBytes: Uint8List(0),
        ),
      );

      await tester.pumpWidget(
        wrapWithApp(
          RoomInviteJoinScreen(controller: controller, target: target),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('New members join only after the request is approved.'),
        findsOneWidget,
      );
      expect(find.text('Join role: member.'), findsOneWidget);
    },
  );
}

class _FakeRoomInviteJoinController extends AppController {
  _FakeRoomInviteJoinController({required this.preview});

  final RoomInvitePreview preview;

  @override
  String get profileId => 'viewer-1';

  @override
  Future<RoomInvitePreview> resolveRoomInviteTarget(
    RoomInviteTarget target,
  ) async {
    return preview;
  }
}
