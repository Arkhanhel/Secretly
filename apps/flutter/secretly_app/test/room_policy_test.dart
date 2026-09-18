// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations_en.dart';
import 'package:secretly_app/rooms/room_policy_failure.dart';
import 'package:secretly_app/ui/room_policy_error_text.dart';

void main() {
  test(
    'room policy maps boolean room settings to member and admin capabilities',
    () {
      final settings = RoomSettings.defaults(ownerProfileId: 'owner').copyWith(
        allowTextMessages: false,
        allowMedia: false,
        allowAddMembers: false,
        allowPinMessages: false,
        allowChangeGroupInfo: false,
        reactionsMode: RoomReactionsMode.none,
      );

      final memberPolicy = evaluateRoomPolicyState(
        settings: settings,
        isMember: true,
        role: RoomMemberRole.member,
        lastOwnMessageAtMs: null,
        nowMs: 10_000,
      );

      expect(memberPolicy.canSendText, isFalse);
      expect(memberPolicy.canSendMedia, isFalse);
      expect(memberPolicy.canAddMembers, isFalse);
      expect(memberPolicy.canPinMessages, isFalse);
      expect(memberPolicy.canChangeGroupInfo, isFalse);
      expect(memberPolicy.canReact, isFalse);

      final adminPolicy = evaluateRoomPolicyState(
        settings: settings,
        isMember: true,
        role: RoomMemberRole.admin,
        lastOwnMessageAtMs: 9_000,
        nowMs: 10_000,
      );

      expect(adminPolicy.canSendText, isTrue);
      expect(adminPolicy.canSendMedia, isTrue);
      expect(adminPolicy.canAddMembers, isTrue);
      expect(adminPolicy.canPinMessages, isTrue);
      expect(adminPolicy.canChangeGroupInfo, isTrue);
      expect(adminPolicy.isSlowModeActive, isFalse);
    },
  );

  test('room policy enforces selected reactions and slow mode for members', () {
    final settings = RoomSettings.defaults(
      ownerProfileId: 'owner',
    ).copyWith(reactionsMode: RoomReactionsMode.selected, slowModeSeconds: 30);

    final memberPolicy = evaluateRoomPolicyState(
      settings: settings,
      isMember: true,
      role: RoomMemberRole.member,
      lastOwnMessageAtMs: 1_000,
      nowMs: 6_000,
    );

    expect(
      () => ensureRoomActionAllowed(memberPolicy, RoomAction.sendText),
      throwsA(
        isA<RoomPolicyFailure>()
            .having((e) => e.code, 'code', RoomPolicyFailureCode.slowModeActive)
            .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 25),
      ),
    );

    expect(
      () =>
          ensureRoomActionAllowed(memberPolicy, RoomAction.react, emoji: '🐶'),
      throwsA(
        isA<RoomPolicyFailure>().having(
          (e) => e.code,
          'code',
          RoomPolicyFailureCode.reactionNotAllowed,
        ),
      ),
    );

    expect(
      () =>
          ensureRoomActionAllowed(memberPolicy, RoomAction.react, emoji: '❤️'),
      returnsNormally,
    );
  });

  test(
    'room policy honors relay-derived next allowed timestamp for slow mode',
    () {
      final settings = RoomSettings.defaults(
        ownerProfileId: 'owner',
      ).copyWith(slowModeSeconds: 30);

      final policy = evaluateRoomPolicyState(
        settings: settings,
        isMember: true,
        role: RoomMemberRole.member,
        lastOwnMessageAtMs: null,
        nextAllowedAtMs: 25_000,
        nowMs: 20_000,
      );

      expect(policy.isSlowModeActive, isTrue);
      expect(policy.slowModeRemainingSeconds, 5);
    },
  );

  test('room policy distinguishes moderator restricted and guest roles', () {
    final baseSettings = RoomSettings.defaults(ownerProfileId: 'owner')
        .copyWith(
          allowTextMessages: true,
          allowMedia: true,
          allowAddMembers: false,
          allowPinMessages: false,
          reactionsMode: RoomReactionsMode.all,
        );

    final moderatorPolicy = evaluateRoomPolicyState(
      settings: baseSettings.copyWith(
        allowTextMessages: false,
        allowMedia: false,
        allowPinMessages: false,
      ),
      isMember: true,
      role: RoomMemberRole.moderator,
      lastOwnMessageAtMs: 9_000,
      nowMs: 10_000,
    );
    expect(moderatorPolicy.canSendText, isTrue);
    expect(moderatorPolicy.canSendMedia, isTrue);
    expect(moderatorPolicy.canPinMessages, isTrue);
    expect(moderatorPolicy.canApproveJoinRequests, isTrue);
    expect(moderatorPolicy.canManageSettings, isFalse);
    expect(moderatorPolicy.canUseBroadcastMentions, isTrue);

    final restrictedPolicy = evaluateRoomPolicyState(
      settings: baseSettings,
      isMember: true,
      role: RoomMemberRole.restricted,
      lastOwnMessageAtMs: null,
      nowMs: 10_000,
    );
    expect(restrictedPolicy.canSendText, isTrue);
    expect(restrictedPolicy.canSendMedia, isFalse);
    expect(restrictedPolicy.canReact, isFalse);

    final guestPolicy = evaluateRoomPolicyState(
      settings: baseSettings,
      isMember: true,
      role: RoomMemberRole.guest,
      lastOwnMessageAtMs: null,
      nowMs: 10_000,
    );
    expect(guestPolicy.canSendText, isFalse);
    expect(guestPolicy.canSendMedia, isFalse);
    expect(guestPolicy.canReact, isFalse);
  });

  test(
    'room policy keeps invite-link management admin-only when member adds are allowed',
    () {
      final settings = RoomSettings.defaults(
        ownerProfileId: 'owner',
      ).copyWith(allowAddMembers: true);

      final memberPolicy = evaluateRoomPolicyState(
        settings: settings,
        isMember: true,
        role: RoomMemberRole.member,
        lastOwnMessageAtMs: null,
        nowMs: 0,
      );

      expect(memberPolicy.canAddMembers, isTrue);
      expect(memberPolicy.canManageInviteLinks, isFalse);
      expect(
        () =>
            ensureRoomActionAllowed(memberPolicy, RoomAction.manageInviteLinks),
        throwsA(
          isA<RoomPolicyFailure>().having(
            (error) => error.code,
            'code',
            RoomPolicyFailureCode.adminOnly,
          ),
        ),
      );
    },
  );

  test('room policy gates self tag changes by role and allowChangeTag', () {
    final lockedSettings = RoomSettings.defaults(
      ownerProfileId: 'owner',
    ).copyWith(allowChangeTag: false);
    final unlockedSettings = lockedSettings.copyWith(allowChangeTag: true);

    final memberLockedPolicy = evaluateRoomPolicyState(
      settings: lockedSettings,
      isMember: true,
      role: RoomMemberRole.member,
      lastOwnMessageAtMs: null,
      nowMs: 0,
    );
    expect(memberLockedPolicy.canChangeOwnTag, isFalse);
    expect(
      () =>
          ensureRoomActionAllowed(memberLockedPolicy, RoomAction.changeOwnTag),
      throwsA(
        isA<RoomPolicyFailure>().having(
          (error) => error.code,
          'code',
          RoomPolicyFailureCode.changeOwnTagDenied,
        ),
      ),
    );

    final memberUnlockedPolicy = evaluateRoomPolicyState(
      settings: unlockedSettings,
      isMember: true,
      role: RoomMemberRole.member,
      lastOwnMessageAtMs: null,
      nowMs: 0,
    );
    expect(memberUnlockedPolicy.canChangeOwnTag, isTrue);
    expect(
      () => ensureRoomActionAllowed(
        memberUnlockedPolicy,
        RoomAction.changeOwnTag,
      ),
      returnsNormally,
    );

    final adminPolicy = evaluateRoomPolicyState(
      settings: lockedSettings,
      isMember: true,
      role: RoomMemberRole.admin,
      lastOwnMessageAtMs: null,
      nowMs: 0,
    );
    expect(adminPolicy.canChangeOwnTag, isTrue);
    expect(
      () => ensureRoomActionAllowed(adminPolicy, RoomAction.changeOwnTag),
      returnsNormally,
    );

    final guestPolicy = evaluateRoomPolicyState(
      settings: unlockedSettings,
      isMember: true,
      role: RoomMemberRole.guest,
      lastOwnMessageAtMs: null,
      nowMs: 0,
    );
    expect(guestPolicy.canChangeOwnTag, isFalse);
  });

  test('room policy covers media pin and moderation-managed actions', () {
    final policy = evaluateRoomPolicyState(
      settings: RoomSettings.defaults(ownerProfileId: 'owner').copyWith(
        allowMedia: false,
        allowAddMembers: false,
        allowPinMessages: false,
        allowChangeGroupInfo: false,
      ),
      isMember: true,
      role: RoomMemberRole.member,
      lastOwnMessageAtMs: null,
      nowMs: 0,
    );

    expect(
      () => ensureRoomActionAllowed(policy, RoomAction.sendMedia),
      throwsA(
        isA<RoomPolicyFailure>().having(
          (e) => e.code,
          'code',
          RoomPolicyFailureCode.mediaDisabled,
        ),
      ),
    );
    expect(
      () => ensureRoomActionAllowed(policy, RoomAction.pinMessage),
      throwsA(
        isA<RoomPolicyFailure>().having(
          (e) => e.code,
          'code',
          RoomPolicyFailureCode.pinMessagesDenied,
        ),
      ),
    );
    expect(
      () => ensureRoomActionAllowed(policy, RoomAction.addMembers),
      throwsA(
        isA<RoomPolicyFailure>().having(
          (e) => e.code,
          'code',
          RoomPolicyFailureCode.addMembersDenied,
        ),
      ),
    );
    expect(
      () => ensureRoomActionAllowed(policy, RoomAction.approveJoinRequests),
      throwsA(
        isA<RoomPolicyFailure>().having(
          (e) => e.code,
          'code',
          RoomPolicyFailureCode.moderationOnly,
        ),
      ),
    );
    expect(
      () => ensureRoomActionAllowed(policy, RoomAction.manageInviteLinks),
      throwsA(
        isA<RoomPolicyFailure>().having(
          (e) => e.code,
          'code',
          RoomPolicyFailureCode.adminOnly,
        ),
      ),
    );
    expect(
      () => ensureRoomActionAllowed(policy, RoomAction.changeGroupInfo),
      throwsA(
        isA<RoomPolicyFailure>().having(
          (e) => e.code,
          'code',
          RoomPolicyFailureCode.groupInfoChangeDenied,
        ),
      ),
    );
  });

  test('room policy rejects non-members before action-specific checks', () {
    final policy = evaluateRoomPolicyState(
      settings: RoomSettings.defaults(ownerProfileId: 'owner'),
      isMember: false,
      role: RoomMemberRole.member,
      lastOwnMessageAtMs: null,
      nowMs: 0,
    );

    expect(
      () => ensureRoomActionAllowed(policy, RoomAction.sendText),
      throwsA(
        isA<RoomPolicyFailure>().having(
          (e) => e.code,
          'code',
          RoomPolicyFailureCode.notMember,
        ),
      ),
    );
  });

  test('roomPolicyErrorText localizes typed room policy failures', () {
    final l10n = AppLocalizationsEn();

    expect(
      roomPolicyErrorText(
        l10n,
        RoomPolicyFailure(RoomPolicyFailureCode.adminOnly),
      ),
      'Only room owners and admins can do that in this room.',
    );
    expect(
      roomPolicyErrorText(
        l10n,
        RoomPolicyFailure(RoomPolicyFailureCode.mediaDisabled),
      ),
      'Your role cannot send media in this room.',
    );
    expect(
      roomPolicyErrorText(
        l10n,
        RoomPolicyFailure(RoomPolicyFailureCode.moderationOnly),
      ),
      'Only room owners, admins, and moderators can do that in this room.',
    );
    expect(
      roomPolicyErrorText(
        l10n,
        RoomPolicyFailure(
          RoomPolicyFailureCode.slowModeActive,
          retryAfterSeconds: 12,
        ),
      ),
      'Slow mode is enabled. Try again in 12s.',
    );
    expect(
      roomPolicyErrorText(
        l10n,
        RoomPolicyFailure(RoomPolicyFailureCode.serviceUnavailable),
      ),
      'Room service is unavailable right now. Try again when the relay reconnects.',
    );
    expect(
      roomPolicyErrorText(
        l10n,
        RoomPolicyFailure(
          RoomPolicyFailureCode.transportBlocked,
          message: 'Transport policy blocked this room action.',
        ),
      ),
      'Transport policy blocked this room action.',
    );
  });
}
