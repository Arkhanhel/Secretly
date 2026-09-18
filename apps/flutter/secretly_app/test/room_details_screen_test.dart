// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/rooms/room_call_state.dart';
import 'package:secretly_app/ui/icons/app_icons.dart';
import 'package:secretly_app/ui/room_details_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets('room details action row promotes call instead of invite', (
    WidgetTester tester,
  ) async {
    final controller = _FakeRoomDetailsController();

    await tester.pumpWidget(
      wrapWithApp(
        RoomDetailsScreen(
          controller: controller,
          groupId: 'group:alpha',
          initialTitle: 'Alpha Room',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Sound'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
    expect(find.byIcon(AppIcons.roomCallAction), findsOneWidget);
    expect(find.byIcon(AppIcons.leaveRoomAction), findsOneWidget);
    expect(find.text('Invite'), findsNothing);
  });

  testWidgets('room details menu hides invite sharing for regular members', (
    WidgetTester tester,
  ) async {
    final controller = _FakeRoomDetailsController(currentProfileId: 'member-1');

    await tester.pumpWidget(
      wrapWithApp(
        RoomDetailsScreen(
          controller: controller,
          groupId: 'group:alpha',
          initialTitle: 'Alpha Room',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(controller.inviteLinkLoadCount, 0);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Invite'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Manage invite links'), findsNothing);
    expect(find.text('Clear history'), findsNothing);
    expect(find.text('Search participants'), findsOneWidget);
  });

  testWidgets('room details menu lets admins clear room history', (
    WidgetTester tester,
  ) async {
    final controller = _FakeRoomDetailsController();

    await tester.pumpWidget(
      wrapWithApp(
        RoomDetailsScreen(
          controller: controller,
          groupId: 'group:alpha',
          initialTitle: 'Alpha Room',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Clear history'), findsOneWidget);

    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(controller.clearedHistoryConvoIds, <String>['group:alpha']);
  });

  testWidgets('room administration screen shows owner-only room tools', (
    WidgetTester tester,
  ) async {
    final controller = _FakeRoomDetailsController(
      inviteLinks: const <RoomInviteLink>[
        RoomInviteLink(
          linkId: 'link-1',
          groupId: 'group:alpha',
          slug: 'alpha',
          createdByProfileId: 'owner-1',
          expiresAtMs: null,
          maxUses: null,
          useCount: 0,
          requiresApproval: false,
          allowedRole: RoomMemberRole.member,
          revoked: false,
          createdAtMs: 1000,
          updatedAtMs: 1000,
        ),
      ],
    );

    await tester.pumpWidget(
      wrapWithApp(
        RoomAdministrationScreen(
          controller: controller,
          groupId: 'group:alpha',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reactions'), findsOneWidget);
    expect(find.text('Permissions'), findsOneWidget);
    expect(find.text('Manage invite links'), findsOneWidget);
    expect(find.text('Roles'), findsOneWidget);
  });

  testWidgets('room administration owner delete action uses deleteRoom directly', (
    WidgetTester tester,
  ) async {
    final controller = _FakeRoomDetailsController();

    await tester.pumpWidget(
      wrapWithApp(
        RoomAdministrationScreen(
          controller: controller,
          groupId: 'group:alpha',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView), const Offset(0, -1200), 1000);
    await tester.pumpAndSettle();

    final ownerAction = find.widgetWithText(
      FilledButton,
      'Transfer ownership or delete room',
    );
    expect(ownerAction, findsOneWidget);
    await tester.tap(ownerAction);
    await tester.pumpAndSettle();

    final deleteAllAction = find.widgetWithText(
      TextButton,
      'Delete room for everyone',
    );
    expect(deleteAllAction, findsOneWidget);
    await tester.tap(deleteAllAction);
    await tester.pumpAndSettle();

    expect(controller.deletedGroupIds, <String>['group:alpha']);
    expect(controller.leftGroupIds, isEmpty);
    expect(controller.removedMemberIds, isEmpty);
  });

  testWidgets(
    'invite links hide per-link approval toggle when room approval is already enabled',
    (WidgetTester tester) async {
      final controller = _FakeRoomDetailsController(
        settings: RoomSettings.defaults(
          ownerProfileId: 'owner-1',
        ).copyWith(joinApprovalRequired: true),
      );

      await tester.pumpWidget(
        wrapWithApp(
          RoomInviteLinksScreen(controller: controller, groupId: 'group:alpha'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Create link'));
      await tester.pumpAndSettle();

      expect(find.text('Require approval for this link'), findsNothing);
      expect(
        find.text(
          'Room-wide approval is already enabled for new members. This invite will still require approval.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(controller.createdInviteRequiresApproval, <bool>[false]);
    },
  );
}

class _FakeRoomDetailsController extends AppController {
  _FakeRoomDetailsController({
    this.currentProfileId = 'owner-1',
    RoomSettings? settings,
    List<RoomMember>? members,
    List<RoomInviteLink>? inviteLinks,
  }) : _settings = settings ?? RoomSettings.defaults(ownerProfileId: 'owner-1'),
       _members =
           members ??
           const <RoomMember>[
             RoomMember(
               profileId: 'owner-1',
               displayName: 'Owner',
               avatarPath: null,
               tag: null,
               role: RoomMemberRole.owner,
               isOnline: true,
               membershipStatus: RoomMembershipStatus.active,
               membershipCreatedAtMs: 1000,
               membershipUpdatedAtMs: 1000,
             ),
             RoomMember(
               profileId: 'member-1',
               displayName: 'Member',
               avatarPath: null,
               tag: null,
               role: RoomMemberRole.member,
               isOnline: false,
               membershipStatus: RoomMembershipStatus.active,
               membershipCreatedAtMs: 1000,
               membershipUpdatedAtMs: 1000,
             ),
           ],
       _inviteLinks = List<RoomInviteLink>.of(
         inviteLinks ?? const <RoomInviteLink>[],
       );

  final String currentProfileId;
  final RoomSettings _settings;
  final List<RoomMember> _members;
  final List<RoomInviteLink> _inviteLinks;
  final List<String> deletedGroupIds = <String>[];
  final List<String> leftGroupIds = <String>[];
  final List<String> removedMemberIds = <String>[];
  final List<String> clearedHistoryConvoIds = <String>[];
  final List<bool> createdInviteRequiresApproval = <bool>[];
  int inviteLinkLoadCount = 0;

  final List<Conversation> _conversations = const <Conversation>[
    Conversation(
      convoId: 'group:alpha',
      peerProfileId: null,
      title: 'Alpha Room',
      avatarPath: null,
      lastEventAtMs: 1000,
      pinnedAtMs: null,
      muted: false,
      archivedAtMs: null,
      autoDeleteSeconds: null,
      emoji: null,
      unreadCount: 0,
    ),
  ];

  RoomMember? _memberForProfile(String profileId) {
    for (final member in _members) {
      if (member.profileId == profileId) {
        return member;
      }
    }
    return null;
  }

  RoomPolicyState _policyFor(String profileId, {int? nowMs}) {
    final member = _memberForProfile(profileId);
    return evaluateRoomPolicyState(
      settings: _settings,
      isMember: member?.isActive ?? false,
      role: member?.role ?? RoomMemberRole.member,
      lastOwnMessageAtMs: null,
      nowMs: nowMs,
    );
  }

  @override
  String get profileId => currentProfileId;

  @override
  Future<List<Conversation>> listConversations() async => _conversations;

  @override
  Future<RoomSettings> getRoomSettings(String groupId) async => _settings;

  @override
  Future<List<RoomMember>> listRoomMembersDetailed(
    String groupId, {
    Set<RoomMembershipStatus>? statuses,
  }) async {
    if (statuses == null || statuses.isEmpty) {
      return _members;
    }
    return _members
        .where((member) => statuses.contains(member.membershipStatus))
        .toList(growable: false);
  }

  @override
  Future<List<RoomMember>> listRoomJoinRequestsDetailed(String groupId) async =>
      const <RoomMember>[];

  @override
  Future<List<RoomMember>> listRoomBannedMembersDetailed(
    String groupId,
  ) async => const <RoomMember>[];

  @override
  Future<List<RoomInviteLink>> listRoomInviteLinks(String groupId) async {
    inviteLinkLoadCount += 1;
    return _inviteLinks;
  }

  @override
  Future<bool> isRoomAdmin(String groupId, {String? profileIdOverride}) async =>
      _policyFor(profileIdOverride ?? currentProfileId).canManageSettings;

  @override
  Future<RoomPolicyState> getRoomPolicyState(
    String groupId, {
    int? nowMs,
    String? profileIdOverride,
  }) async {
    return _policyFor(profileIdOverride ?? currentProfileId, nowMs: nowMs);
  }

  @override
  Future<CachedRoomCall?> getCachedRoomCall(String roomId) async => null;

  @override
  Future<void> deleteRoom(String groupId) async {
    deletedGroupIds.add(groupId);
  }

  @override
  Future<void> leaveRoom(String groupId) async {
    leftGroupIds.add(groupId);
  }

  @override
  Future<void> clearChatHistoryEverywhere({
    required String convoId,
    String? directPeerProfileId,
  }) async {
    clearedHistoryConvoIds.add(convoId);
  }

  @override
  Future<void> removeGroupMember({
    required String groupId,
    required String memberProfileId,
  }) async {
    removedMemberIds.add(memberProfileId);
  }

  @override
  Future<RoomInviteLink> createRoomInviteLink(
    String groupId, {
    int? expiresAtMs,
    int? maxUses,
    bool requiresApproval = false,
    RoomMemberRole allowedRole = RoomMemberRole.member,
  }) async {
    createdInviteRequiresApproval.add(requiresApproval);
    final link = RoomInviteLink(
      linkId: 'link-${createdInviteRequiresApproval.length}',
      groupId: groupId,
      slug: 'slug-${createdInviteRequiresApproval.length}',
      createdByProfileId: currentProfileId,
      expiresAtMs: expiresAtMs,
      maxUses: maxUses,
      useCount: 0,
      requiresApproval: requiresApproval,
      allowedRole: allowedRole,
      revoked: false,
      createdAtMs: 1000,
      updatedAtMs: 1000,
    );
    _inviteLinks.insert(0, link);
    return link;
  }
}
