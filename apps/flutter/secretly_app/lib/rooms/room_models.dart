// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'room_policy_failure.dart';

enum RoomReactionsMode {
  all('all'),
  selected('selected'),
  none('none');

  const RoomReactionsMode(this.value);
  final String value;
}

extension RoomReactionsModeX on RoomReactionsMode {
  static RoomReactionsMode fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'selected':
        return RoomReactionsMode.selected;
      case 'none':
        return RoomReactionsMode.none;
      default:
        return RoomReactionsMode.all;
    }
  }
}

const List<String> roomSelectedReactionEmojis = <String>[
  '❤️',
  '🔥',
  '😁',
  '👍',
  '👎',
  '🥰',
  '👏',
];

enum RoomMembershipStatus { active, pending, left, removed, banned }

extension RoomMembershipStatusX on RoomMembershipStatus {
  String get value {
    switch (this) {
      case RoomMembershipStatus.active:
        return 'active';
      case RoomMembershipStatus.pending:
        return 'pending';
      case RoomMembershipStatus.left:
        return 'left';
      case RoomMembershipStatus.removed:
        return 'removed';
      case RoomMembershipStatus.banned:
        return 'banned';
    }
  }

  static RoomMembershipStatus fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'pending':
        return RoomMembershipStatus.pending;
      case 'left':
        return RoomMembershipStatus.left;
      case 'removed':
        return RoomMembershipStatus.removed;
      case 'banned':
        return RoomMembershipStatus.banned;
      case 'active':
      default:
        return RoomMembershipStatus.active;
    }
  }
}

enum RoomMemberRole { owner, admin, moderator, member, restricted, guest }

extension RoomMemberRoleX on RoomMemberRole {
  String get value {
    switch (this) {
      case RoomMemberRole.owner:
        return 'owner';
      case RoomMemberRole.admin:
        return 'admin';
      case RoomMemberRole.moderator:
        return 'moderator';
      case RoomMemberRole.member:
        return 'member';
      case RoomMemberRole.restricted:
        return 'restricted';
      case RoomMemberRole.guest:
        return 'guest';
    }
  }

  static RoomMemberRole fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'owner':
        return RoomMemberRole.owner;
      case 'admin':
        return RoomMemberRole.admin;
      case 'moderator':
        return RoomMemberRole.moderator;
      case 'restricted':
        return RoomMemberRole.restricted;
      case 'guest':
      case 'read_only':
      case 'readonly':
      case 'read-only':
        return RoomMemberRole.guest;
      case 'member':
      default:
        return RoomMemberRole.member;
    }
  }

  bool get canBypassPostingPolicy {
    switch (this) {
      case RoomMemberRole.owner:
      case RoomMemberRole.admin:
      case RoomMemberRole.moderator:
        return true;
      case RoomMemberRole.member:
      case RoomMemberRole.restricted:
      case RoomMemberRole.guest:
        return false;
    }
  }

  bool get canModerateMembers {
    switch (this) {
      case RoomMemberRole.owner:
      case RoomMemberRole.admin:
      case RoomMemberRole.moderator:
        return true;
      case RoomMemberRole.member:
      case RoomMemberRole.restricted:
      case RoomMemberRole.guest:
        return false;
    }
  }

  bool get canUseBroadcastMentions {
    switch (this) {
      case RoomMemberRole.owner:
      case RoomMemberRole.admin:
      case RoomMemberRole.moderator:
        return true;
      case RoomMemberRole.member:
      case RoomMemberRole.restricted:
      case RoomMemberRole.guest:
        return false;
    }
  }

  int get sortPriority {
    switch (this) {
      case RoomMemberRole.owner:
        return 0;
      case RoomMemberRole.admin:
        return 1;
      case RoomMemberRole.moderator:
        return 2;
      case RoomMemberRole.member:
        return 3;
      case RoomMemberRole.restricted:
        return 4;
      case RoomMemberRole.guest:
        return 5;
    }
  }
}

enum RoomAction {
  sendText,
  sendMedia,
  react,
  pinMessage,
  addMembers,
  approveJoinRequests,
  removeMembers,
  banMembers,
  changeGroupInfo,
  changeOwnTag,
  manageSettings,
  manageAdmins,
  manageMemberRoles,
  manageInviteLinks,
}

class RoomSettings {
  const RoomSettings({
    required this.ownerProfileId,
    this.avatarPath,
    this.avatarHash,
    this.pinnedMessageEventId,
    this.coverId,
    this.frameId,
    this.nameEmoji,
    required this.description,
    required this.reactionsMode,
    required this.allowTextMessages,
    required this.allowMedia,
    required this.allowAddMembers,
    required this.allowPinMessages,
    required this.allowChangeGroupInfo,
    required this.allowChangeTag,
    required this.joinApprovalRequired,
    required this.slowModeSeconds,
    required this.chatHistoryVisible,
    required this.membershipVersion,
    required this.stateVersion,
  });

  factory RoomSettings.defaults({
    required String ownerProfileId,
    int membershipVersion = 0,
    int stateVersion = 0,
  }) {
    return RoomSettings(
      ownerProfileId: ownerProfileId,
      avatarPath: null,
      avatarHash: null,
      pinnedMessageEventId: null,
      coverId: null,
      frameId: null,
      nameEmoji: null,
      description: null,
      reactionsMode: RoomReactionsMode.all,
      allowTextMessages: true,
      allowMedia: true,
      allowAddMembers: true,
      allowPinMessages: true,
      allowChangeGroupInfo: true,
      allowChangeTag: false,
      joinApprovalRequired: false,
      slowModeSeconds: 0,
      chatHistoryVisible: false,
      membershipVersion: membershipVersion,
      stateVersion: stateVersion,
    );
  }

  final String ownerProfileId;
  final String? avatarPath;
  final String? avatarHash;
  final String? pinnedMessageEventId;

  /// Premium ROOM cosmetics (string-only catalog ids + an emoji). Set by the
  /// room OWNER (when premium) and synced to all members via the room snapshot;
  /// rendered client-side from the shared cosmetic catalog. Viewing is never
  /// gated. Null when unset.
  final String? coverId;
  final String? frameId;
  final String? nameEmoji;
  final String? description;
  final RoomReactionsMode reactionsMode;
  final bool allowTextMessages;
  final bool allowMedia;
  final bool allowAddMembers;
  final bool allowPinMessages;
  final bool allowChangeGroupInfo;
  final bool allowChangeTag;
  final bool joinApprovalRequired;
  final int slowModeSeconds;
  final bool chatHistoryVisible;
  final int membershipVersion;
  final int stateVersion;

  RoomSettings copyWith({
    String? ownerProfileId,
    String? avatarPath,
    String? avatarHash,
    bool clearAvatar = false,
    String? pinnedMessageEventId,
    bool clearPinnedMessageEventId = false,
    String? coverId,
    bool clearCoverId = false,
    String? frameId,
    bool clearFrameId = false,
    String? nameEmoji,
    bool clearNameEmoji = false,
    String? description,
    bool clearDescription = false,
    RoomReactionsMode? reactionsMode,
    bool? allowTextMessages,
    bool? allowMedia,
    bool? allowAddMembers,
    bool? allowPinMessages,
    bool? allowChangeGroupInfo,
    bool? allowChangeTag,
    bool? joinApprovalRequired,
    int? slowModeSeconds,
    bool? chatHistoryVisible,
    int? membershipVersion,
    int? stateVersion,
  }) {
    final nextAvatarPath = clearAvatar
        ? avatarPath
        : (avatarPath ?? this.avatarPath);
    final nextAvatarHash = clearAvatar
        ? avatarHash
        : (avatarHash ?? this.avatarHash);
    final nextPinnedMessageEventId = clearPinnedMessageEventId
        ? null
        : (pinnedMessageEventId ?? this.pinnedMessageEventId);
    final nextCoverId = clearCoverId ? null : (coverId ?? this.coverId);
    final nextFrameId = clearFrameId ? null : (frameId ?? this.frameId);
    final nextNameEmoji = clearNameEmoji ? null : (nameEmoji ?? this.nameEmoji);
    return RoomSettings(
      ownerProfileId: ownerProfileId ?? this.ownerProfileId,
      avatarPath: nextAvatarPath,
      avatarHash: nextAvatarHash,
      pinnedMessageEventId: nextPinnedMessageEventId,
      coverId: nextCoverId,
      frameId: nextFrameId,
      nameEmoji: nextNameEmoji,
      description: clearDescription ? null : (description ?? this.description),
      reactionsMode: reactionsMode ?? this.reactionsMode,
      allowTextMessages: allowTextMessages ?? this.allowTextMessages,
      allowMedia: allowMedia ?? this.allowMedia,
      allowAddMembers: allowAddMembers ?? this.allowAddMembers,
      allowPinMessages: allowPinMessages ?? this.allowPinMessages,
      allowChangeGroupInfo: allowChangeGroupInfo ?? this.allowChangeGroupInfo,
      allowChangeTag: allowChangeTag ?? this.allowChangeTag,
      joinApprovalRequired: joinApprovalRequired ?? this.joinApprovalRequired,
      slowModeSeconds: slowModeSeconds ?? this.slowModeSeconds,
      chatHistoryVisible: chatHistoryVisible ?? this.chatHistoryVisible,
      membershipVersion: membershipVersion ?? this.membershipVersion,
      stateVersion: stateVersion ?? this.stateVersion,
    );
  }
}

class RoomMember {
  const RoomMember({
    required this.profileId,
    required this.displayName,
    required this.avatarPath,
    required this.tag,
    required this.role,
    required this.isOnline,
    required this.membershipStatus,
    required this.membershipCreatedAtMs,
    required this.membershipUpdatedAtMs,
  });

  final String profileId;
  final String displayName;
  final String? avatarPath;
  final String? tag;
  final RoomMemberRole role;
  final bool isOnline;
  final RoomMembershipStatus membershipStatus;
  final int membershipCreatedAtMs;
  final int membershipUpdatedAtMs;

  bool get isOwner => role == RoomMemberRole.owner;
  bool get isAdmin => isOwner || role == RoomMemberRole.admin;
  bool get isModerator => role == RoomMemberRole.moderator;
  bool get isRestricted => role == RoomMemberRole.restricted;
  bool get isGuest => role == RoomMemberRole.guest;
  bool get isActive => membershipStatus == RoomMembershipStatus.active;
  bool get isPending => membershipStatus == RoomMembershipStatus.pending;
  bool get isBanned => membershipStatus == RoomMembershipStatus.banned;
}

class RoomPolicyState {
  const RoomPolicyState({
    required this.settings,
    required this.isMember,
    required this.role,
    required this.canSendText,
    required this.canSendMedia,
    required this.canAddMembers,
    required this.canPinMessages,
    required this.canChangeGroupInfo,
    required this.canChangeOwnTag,
    required this.canManageSettings,
    required this.canManageAdmins,
    required this.canManageMemberRoles,
    required this.canManageInviteLinks,
    required this.canApproveJoinRequests,
    required this.canRemoveMembers,
    required this.canBanMembers,
    required this.canUseBroadcastMentions,
    required this.canReceiveAdminMentions,
    required this.canReact,
    required this.allowedReactionEmojis,
    required this.isSlowModeActive,
    required this.slowModeRemainingSeconds,
  });

  final RoomSettings settings;
  final bool isMember;
  final RoomMemberRole role;
  final bool canSendText;
  final bool canSendMedia;
  final bool canAddMembers;
  final bool canPinMessages;
  final bool canChangeGroupInfo;
  final bool canChangeOwnTag;
  final bool canManageSettings;
  final bool canManageAdmins;
  final bool canManageMemberRoles;
  final bool canManageInviteLinks;
  final bool canApproveJoinRequests;
  final bool canRemoveMembers;
  final bool canBanMembers;
  final bool canUseBroadcastMentions;
  final bool canReceiveAdminMentions;
  final bool canReact;
  final List<String> allowedReactionEmojis;
  final bool isSlowModeActive;
  final int slowModeRemainingSeconds;

  bool get isOwner => role == RoomMemberRole.owner;
  bool get isAdmin => isOwner || role == RoomMemberRole.admin;
  bool get isModerator => role == RoomMemberRole.moderator;
  bool get isRestricted => role == RoomMemberRole.restricted;
  bool get isGuest => role == RoomMemberRole.guest;

  bool isReactionAllowed(String emoji) {
    final cleaned = emoji.trim();
    if (cleaned.isEmpty || !canReact) return false;
    if (settings.reactionsMode != RoomReactionsMode.selected) return true;
    return allowedReactionEmojis.contains(cleaned);
  }
}

typedef RoomReadReceiptDispatchTarget = ({
  String peerProfileId,
  String peerDeviceId,
  List<String> payloadEventIds,
});

typedef RoomRelayResyncPlan = ({
  bool shouldRefresh,
  bool refreshMemberships,
  bool forceAuthoritative,
});

RoomRelayResyncPlan planRoomRelayResync({
  required bool hasLocalRoomState,
  required int localStateVersion,
  required int localMembershipVersion,
  required int remoteStateVersion,
  required int remoteMembershipVersion,
}) {
  final normalizedLocalStateVersion = localStateVersion < 0
      ? 0
      : localStateVersion;
  final normalizedRemoteStateVersion = remoteStateVersion < 0
      ? 0
      : remoteStateVersion;
  final effectiveLocalMembershipVersion = localMembershipVersion > 0
      ? localMembershipVersion
      : normalizedLocalStateVersion;
  final effectiveRemoteMembershipVersion = remoteMembershipVersion > 0
      ? remoteMembershipVersion
      : normalizedRemoteStateVersion;
  final refreshMemberships =
      !hasLocalRoomState ||
      effectiveRemoteMembershipVersion != effectiveLocalMembershipVersion;
  final stateChanged =
      normalizedRemoteStateVersion != normalizedLocalStateVersion;
  final shouldRefresh = stateChanged || refreshMemberships;
  final forceAuthoritative =
      shouldRefresh &&
      (normalizedRemoteStateVersion < normalizedLocalStateVersion ||
          effectiveRemoteMembershipVersion < effectiveLocalMembershipVersion);
  return (
    shouldRefresh: shouldRefresh,
    refreshMemberships: refreshMemberships,
    forceAuthoritative: forceAuthoritative,
  );
}

RoomRelayResyncPlan? planAuthoritativeRoomSyncHintResync({
  required bool hasLocalRoomState,
  required int localStateVersion,
  required int localMembershipVersion,
  required int hintedStateVersion,
  required int hintedMembershipVersion,
  bool includeInviteLinks = false,
}) {
  if (hintedStateVersion <= 0) {
    return null;
  }
  final plan = planRoomRelayResync(
    hasLocalRoomState: hasLocalRoomState,
    localStateVersion: localStateVersion,
    localMembershipVersion: localMembershipVersion,
    remoteStateVersion: hintedStateVersion,
    remoteMembershipVersion: hintedMembershipVersion,
  );
  if (!includeInviteLinks) {
    return plan;
  }
  return (
    shouldRefresh: true,
    refreshMemberships: true,
    forceAuthoritative: plan.forceAuthoritative,
  );
}

bool shouldRefreshRoomCallFromSyncHint({
  required bool hasLocalCallState,
  required int localStateVersion,
  String? localCallId,
  required bool hintedCallExists,
  int hintedStateVersion = 0,
  String? hintedCallId,
}) {
  if (!hintedCallExists) {
    return hasLocalCallState;
  }
  if (!hasLocalCallState) {
    return true;
  }

  final normalizedHintedCallId = (hintedCallId ?? '').trim();
  final normalizedLocalCallId = (localCallId ?? '').trim();
  if (normalizedHintedCallId.isEmpty) {
    return true;
  }
  if (normalizedHintedCallId != normalizedLocalCallId) {
    return true;
  }

  final normalizedHintedStateVersion = hintedStateVersion < 0
      ? 0
      : hintedStateVersion;
  if (normalizedHintedStateVersion <= 0) {
    return true;
  }

  final normalizedLocalStateVersion = localStateVersion < 0
      ? 0
      : localStateVersion;
  return normalizedHintedStateVersion != normalizedLocalStateVersion;
}

List<RoomReadReceiptDispatchTarget> planRoomReadReceiptDispatchTargets({
  required Iterable<Map<String, Object?>> unreadRows,
  required Map<String, String?> senderProfileIdByDeviceId,
  required String selfProfileId,
  required bool Function(String senderDeviceId) isOwnDeviceId,
}) {
  final payloadIdsBySenderDeviceId = <String, List<String>>{};
  final indexedUnreadRows =
      unreadRows.toList(growable: false).asMap().entries.toList()
        ..sort((left, right) {
          final leftCreatedAtMs =
              ((left.value['created_at_ms'] as num?)?.toInt()) ?? 0;
          final rightCreatedAtMs =
              ((right.value['created_at_ms'] as num?)?.toInt()) ?? 0;
          final byCreatedAt = leftCreatedAtMs.compareTo(rightCreatedAtMs);
          if (byCreatedAt != 0) {
            return byCreatedAt;
          }
          return left.key.compareTo(right.key);
        });

  for (final entry in indexedUnreadRows) {
    final row = entry.value;
    final senderDeviceId = ((row['sender_device_id'] as String?) ?? '').trim();
    if (senderDeviceId.isEmpty || isOwnDeviceId(senderDeviceId)) {
      continue;
    }
    final payloadEventId = ((row['payload_event_id'] as String?) ?? '').trim();
    if (payloadEventId.isEmpty) continue;
    payloadIdsBySenderDeviceId
        .putIfAbsent(senderDeviceId, () => <String>[])
        .add(payloadEventId);
  }

  final targets = <RoomReadReceiptDispatchTarget>[];
  for (final entry in payloadIdsBySenderDeviceId.entries) {
    final peerProfileId = (senderProfileIdByDeviceId[entry.key] ?? '').trim();
    if (peerProfileId.isEmpty ||
        (selfProfileId.isNotEmpty && peerProfileId == selfProfileId)) {
      continue;
    }
    targets.add((
      peerProfileId: peerProfileId,
      peerDeviceId: entry.key,
      payloadEventIds: List<String>.unmodifiable(entry.value),
    ));
  }
  return targets;
}

bool _policyCanSendText(RoomMemberRole role, RoomSettings settings) {
  switch (role) {
    case RoomMemberRole.owner:
    case RoomMemberRole.admin:
    case RoomMemberRole.moderator:
      return true;
    case RoomMemberRole.member:
    case RoomMemberRole.restricted:
      return settings.allowTextMessages;
    case RoomMemberRole.guest:
      return false;
  }
}

bool _policyCanSendMedia(RoomMemberRole role, RoomSettings settings) {
  switch (role) {
    case RoomMemberRole.owner:
    case RoomMemberRole.admin:
    case RoomMemberRole.moderator:
      return true;
    case RoomMemberRole.member:
      return settings.allowMedia;
    case RoomMemberRole.restricted:
    case RoomMemberRole.guest:
      return false;
  }
}

bool _policyCanAddMembers(RoomMemberRole role, RoomSettings settings) {
  switch (role) {
    case RoomMemberRole.owner:
    case RoomMemberRole.admin:
      return true;
    case RoomMemberRole.moderator:
    case RoomMemberRole.member:
      return settings.allowAddMembers;
    case RoomMemberRole.restricted:
    case RoomMemberRole.guest:
      return false;
  }
}

bool _policyCanPinMessages(RoomMemberRole role, RoomSettings settings) {
  switch (role) {
    case RoomMemberRole.owner:
    case RoomMemberRole.admin:
    case RoomMemberRole.moderator:
      return true;
    case RoomMemberRole.member:
      return settings.allowPinMessages;
    case RoomMemberRole.restricted:
    case RoomMemberRole.guest:
      return false;
  }
}

bool _policyCanChangeGroupInfo(RoomMemberRole role, RoomSettings settings) {
  switch (role) {
    case RoomMemberRole.owner:
    case RoomMemberRole.admin:
      return true;
    case RoomMemberRole.moderator:
    case RoomMemberRole.member:
      return settings.allowChangeGroupInfo;
    case RoomMemberRole.restricted:
    case RoomMemberRole.guest:
      return false;
  }
}

bool _policyCanChangeOwnTag(RoomMemberRole role, RoomSettings settings) {
  switch (role) {
    case RoomMemberRole.owner:
    case RoomMemberRole.admin:
      return true;
    case RoomMemberRole.moderator:
    case RoomMemberRole.member:
      return settings.allowChangeTag;
    case RoomMemberRole.restricted:
    case RoomMemberRole.guest:
      return false;
  }
}

RoomPolicyState evaluateRoomPolicyState({
  required RoomSettings settings,
  required bool isMember,
  required RoomMemberRole role,
  required int? lastOwnMessageAtMs,
  int? nextAllowedAtMs,
  int? nowMs,
}) {
  final effectiveRole = isMember ? role : RoomMemberRole.member;
  final canBypassPostingPolicy = effectiveRole.canBypassPostingPolicy;
  final currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  var slowModeRemainingSeconds = 0;
  if (!canBypassPostingPolicy && settings.slowModeSeconds > 0) {
    if (lastOwnMessageAtMs != null) {
      final elapsedMs = currentMs - lastOwnMessageAtMs;
      final cooldownMs = settings.slowModeSeconds * 1000;
      if (elapsedMs < cooldownMs) {
        slowModeRemainingSeconds = ((cooldownMs - elapsedMs) / 1000).ceil();
      }
    }
    if (nextAllowedAtMs != null && nextAllowedAtMs > currentMs) {
      final relayRemainingSeconds = ((nextAllowedAtMs - currentMs) / 1000)
          .ceil();
      if (relayRemainingSeconds > slowModeRemainingSeconds) {
        slowModeRemainingSeconds = relayRemainingSeconds;
      }
    }
  }

  return RoomPolicyState(
    settings: settings,
    isMember: isMember,
    role: effectiveRole,
    canSendText: isMember && _policyCanSendText(effectiveRole, settings),
    canSendMedia: isMember && _policyCanSendMedia(effectiveRole, settings),
    canAddMembers: isMember && _policyCanAddMembers(effectiveRole, settings),
    canPinMessages: isMember && _policyCanPinMessages(effectiveRole, settings),
    canChangeGroupInfo:
        isMember && _policyCanChangeGroupInfo(effectiveRole, settings),
    canChangeOwnTag:
        isMember && _policyCanChangeOwnTag(effectiveRole, settings),
    canManageSettings:
        isMember &&
        (effectiveRole == RoomMemberRole.owner ||
            effectiveRole == RoomMemberRole.admin),
    canManageAdmins: isMember && effectiveRole == RoomMemberRole.owner,
    canManageMemberRoles:
        isMember &&
        (effectiveRole == RoomMemberRole.owner ||
            effectiveRole == RoomMemberRole.admin),
    canManageInviteLinks:
        isMember &&
        (effectiveRole == RoomMemberRole.owner ||
            effectiveRole == RoomMemberRole.admin),
    canApproveJoinRequests: isMember && effectiveRole.canModerateMembers,
    canRemoveMembers: isMember && effectiveRole.canModerateMembers,
    canBanMembers: isMember && effectiveRole.canModerateMembers,
    canUseBroadcastMentions: isMember && effectiveRole.canUseBroadcastMentions,
    canReceiveAdminMentions: isMember && effectiveRole.canUseBroadcastMentions,
    canReact:
        isMember &&
        settings.reactionsMode != RoomReactionsMode.none &&
        effectiveRole != RoomMemberRole.restricted &&
        effectiveRole != RoomMemberRole.guest,
    allowedReactionEmojis: roomSelectedReactionEmojis,
    isSlowModeActive: slowModeRemainingSeconds > 0,
    slowModeRemainingSeconds: slowModeRemainingSeconds,
  );
}

void ensureRoomActionAllowed(
  RoomPolicyState policy,
  RoomAction action, {
  String? emoji,
}) {
  if (!policy.isMember) {
    throw RoomPolicyFailure(RoomPolicyFailureCode.notMember);
  }

  switch (action) {
    case RoomAction.sendText:
      if (!policy.canSendText) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.textMessagesDisabled);
      }
      if (policy.isSlowModeActive) {
        throw RoomPolicyFailure(
          RoomPolicyFailureCode.slowModeActive,
          retryAfterSeconds: policy.slowModeRemainingSeconds,
        );
      }
      return;
    case RoomAction.sendMedia:
      if (!policy.canSendMedia) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.mediaDisabled);
      }
      if (policy.isSlowModeActive) {
        throw RoomPolicyFailure(
          RoomPolicyFailureCode.slowModeActive,
          retryAfterSeconds: policy.slowModeRemainingSeconds,
        );
      }
      return;
    case RoomAction.react:
      if (!policy.canReact) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.reactionsDisabled);
      }
      if (!policy.isReactionAllowed(emoji ?? '')) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.reactionNotAllowed);
      }
      return;
    case RoomAction.pinMessage:
      if (!policy.canPinMessages) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.pinMessagesDenied);
      }
      return;
    case RoomAction.addMembers:
      if (!policy.canAddMembers) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.addMembersDenied);
      }
      return;
    case RoomAction.approveJoinRequests:
      if (!policy.canApproveJoinRequests) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.moderationOnly);
      }
      return;
    case RoomAction.removeMembers:
      if (!policy.canRemoveMembers) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.moderationOnly);
      }
      return;
    case RoomAction.banMembers:
      if (!policy.canBanMembers) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.moderationOnly);
      }
      return;
    case RoomAction.manageSettings:
    case RoomAction.manageInviteLinks:
      if ((action == RoomAction.manageSettings && !policy.canManageSettings) ||
          (action == RoomAction.manageInviteLinks &&
              !policy.canManageInviteLinks)) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.adminOnly);
      }
      return;
    case RoomAction.manageAdmins:
      if (!policy.canManageAdmins) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.adminOnly);
      }
      return;
    case RoomAction.manageMemberRoles:
      if (!policy.canManageMemberRoles) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.adminOnly);
      }
      return;
    case RoomAction.changeGroupInfo:
      if (!policy.canChangeGroupInfo) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.groupInfoChangeDenied);
      }
      return;
    case RoomAction.changeOwnTag:
      if (!policy.canChangeOwnTag) {
        throw RoomPolicyFailure(RoomPolicyFailureCode.changeOwnTagDenied);
      }
      return;
  }
}
