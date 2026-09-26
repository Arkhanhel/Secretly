// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'attested_senders.dart';
import 'resilient_http_client.dart';
import '../calls/call_ice_config.dart';
import '../ratchet/wire_v3.dart';
import '../messages/message_delivery_state.dart';
import '../messages/outgoing_message_scheduler.dart';
import '../storage/app_db.dart';
import '../security/device_keys.dart';
import '../security/auth_signer.dart';
import 'service_health_status.dart';
import 'relay_protocol.dart';
import '../diagnostics/diag_log.dart';
import 'server_clock.dart';

typedef RelayWebSocketConnector =
    WebSocketChannel Function(
      Uri uri, {
      Duration? pingInterval,
      Duration? connectTimeout,
    });

String _jsonString(Object? value) => (value as String? ?? '').trim();

List<String> _jsonStringList(Object? value) {
  final raw = value as List?;
  if (raw == null) return const <String>[];
  return raw
      .map((entry) => _jsonString(entry))
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

int? _jsonNullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

bool _jsonBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return false;
}

class RelayHttpException implements Exception {
  const RelayHttpException({
    required this.operation,
    required this.message,
    this.statusCode,
    this.responseBody,
  });

  final String operation;
  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' HTTP $statusCode';
    return '$operation failed$status: $message';
  }
}

/// Sprint 2 R3: result of `GET /v1/active_devices/{profile_id}` on the relay.
///
/// The client uses [filterApplied] as the gating signal:
///   * `false` — the relay either had no activity data for the profile
///     yet OR the operator has not turned on the staleness filter. The
///     caller MUST fall back to its bundle-derived device set unchanged.
///   * `true`  — the relay has applied its staleness filter and the
///     [deviceIds] are the believed-live subset. The caller SHOULD
///     intersect this set with its bundle list before fanning out. If
///     the intersection ends up empty, the caller MUST NOT silently
///     drop the send — it falls back to the full bundle.
///
/// `nowMs` and `thresholdMs` are exposed for client-side diagnostics
/// only; they are not used in the filtering decision.
class RelayActiveDevicesSnapshot {
  const RelayActiveDevicesSnapshot({
    required this.profileId,
    required this.filterApplied,
    required this.deviceIds,
    required this.nowMs,
    required this.thresholdMs,
    this.liveness = const <RelayDeviceLiveness>[],
  });

  final String profileId;
  final bool filterApplied;
  final List<String> deviceIds;
  final int nowMs;
  final int thresholdMs;

  /// Когда каждое устройство в последний раз подавало признаки жизни.
  ///
  /// Пусто, если реле старое и поля не присылает, — тогда вызывающий обязан
  /// вести себя как раньше и никого не отсеивать.
  final List<RelayDeviceLiveness> liveness;
}

/// Факт о жизни устройства, как его видит реле.
/// Человеческое объяснение к отказу авторизации реле.
///
/// 🔴 ЗАЧЕМ (12.09.2026). Обращение в поддержку: iPhone 13 mini, «System
/// errors», отправить ничего нельзя, в диагностике —
/// `Relay push token set failed: HTTP 401` и больше ничего. Человек трижды
/// сбросил профиль, а причина была в другом: часы телефона разошлись с
/// сервером больше чем на пять минут, и подпись отвергалась.
///
/// Путь сервера ключей такое объясняет давно и внятно («Clock drift
/// detected… Enable automatic date/time»), а путь реле молчал. За сутки
/// `timestamp out of range` получают около восьмидесяти устройств — все они
/// видели «System errors» вместо простого совета.
///
/// Реле присылает причину в теле ответа; ниже она превращается в подсказку.
/// Ничего не решает и ни на что не влияет — только текст.
@visibleForTesting
String relayAuthFailureHint(int statusCode, String body) {
  if (statusCode != 401) return '';
  final b = body.toLowerCase();
  if (b.contains('timestamp')) {
    return ' — the device clock is off from the Secretly server by more than '
        '5 minutes. Enable automatic date & time on the device and restart '
        'the app. Resetting the profile does not help: the clock is the cause.';
  }
  if (b.contains('unknown device')) {
    return ' — the server does not know this device yet. It usually clears '
        'itself once key publication succeeds; if it persists, the device '
        'never finished registration.';
  }
  if (b.contains('signature')) {
    return ' — the device signature did not verify. The device keys and the '
        'published identity key disagree.';
  }
  if (b.contains('nonce')) {
    return ' — the request was replayed or arrived twice.';
  }
  return '';
}

class RelayDeviceLiveness {
  const RelayDeviceLiveness({
    required this.deviceId,
    required this.lastSignalMs,
    required this.superseded,
  });

  final String deviceId;
  final int lastSignalMs;
  final bool superseded;
}

class RelayCallSessionSnapshot {
  const RelayCallSessionSnapshot({
    required this.exists,
    required this.deviceId,
    required this.callId,
    required this.callAttemptId,
    this.peerDeviceId,
    this.direction,
    this.state,
    this.lastAction,
    this.lastSignalId,
    this.lastCreatedAtMs,
    this.lastReceivedAtMs,
    this.invitedAtMs,
    this.acceptedAtMs,
    this.offerSeenAtMs,
    this.answerSeenAtMs,
    this.reconnectingAtMs,
    this.endedAtMs,
    this.expiresAtMs,
  });

  final bool exists;
  final String deviceId;
  final String callId;
  final String callAttemptId;
  final String? peerDeviceId;
  final String? direction;
  final String? state;
  final String? lastAction;
  final String? lastSignalId;
  final int? lastCreatedAtMs;
  final int? lastReceivedAtMs;
  final int? invitedAtMs;
  final int? acceptedAtMs;
  final int? offerSeenAtMs;
  final int? answerSeenAtMs;
  final int? reconnectingAtMs;
  final int? endedAtMs;
  final int? expiresAtMs;

  bool get isEnded => state == 'ended' || endedAtMs != null;

  static int? _parseNullableInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  factory RelayCallSessionSnapshot.fromJson(Map<String, dynamic> json) {
    return RelayCallSessionSnapshot(
      exists: json['exists'] == true,
      deviceId: (json['device_id'] as String? ?? '').trim(),
      callId: (json['call_id'] as String? ?? '').trim(),
      callAttemptId: (json['call_attempt_id'] as String? ?? '').trim(),
      peerDeviceId: (json['peer_device_id'] as String?)?.trim(),
      direction: (json['direction'] as String?)?.trim(),
      state: (json['state'] as String?)?.trim(),
      lastAction: (json['last_action'] as String?)?.trim(),
      lastSignalId: (json['last_signal_id'] as String?)?.trim(),
      lastCreatedAtMs: _parseNullableInt(json['last_created_at_ms']),
      lastReceivedAtMs: _parseNullableInt(json['last_received_at_ms']),
      invitedAtMs: _parseNullableInt(json['invited_at_ms']),
      acceptedAtMs: _parseNullableInt(json['accepted_at_ms']),
      offerSeenAtMs: _parseNullableInt(json['offer_seen_at_ms']),
      answerSeenAtMs: _parseNullableInt(json['answer_seen_at_ms']),
      reconnectingAtMs: _parseNullableInt(json['reconnecting_at_ms']),
      endedAtMs: _parseNullableInt(json['ended_at_ms']),
      expiresAtMs: _parseNullableInt(json['expires_at_ms']),
    );
  }
}

class RelayRoom {
  const RelayRoom({
    required this.roomId,
    required this.version,
    required this.membershipVersion,
    required this.ownerProfileId,
    required this.createdByDeviceId,
    required this.title,
    required this.description,
    required this.avatarHash,
    required this.avatarImageB64,
    required this.reactionsMode,
    required this.allowText,
    required this.allowMedia,
    required this.allowAddMembers,
    required this.allowPinMessages,
    required this.allowChangeGroupInfo,
    required this.allowChangeTag,
    required this.joinApprovalRequired,
    required this.slowModeSeconds,
    required this.chatHistoryVisible,
    required this.pinnedMessageId,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String roomId;
  final int version;
  final int membershipVersion;
  final String ownerProfileId;
  final String createdByDeviceId;
  final String title;
  final String? description;
  final String? avatarHash;
  final String? avatarImageB64;
  final String reactionsMode;
  final bool allowText;
  final bool allowMedia;
  final bool allowAddMembers;
  final bool allowPinMessages;
  final bool allowChangeGroupInfo;
  final bool allowChangeTag;
  final bool joinApprovalRequired;
  final int slowModeSeconds;
  final bool chatHistoryVisible;
  final String? pinnedMessageId;
  final int createdAtMs;
  final int updatedAtMs;

  factory RelayRoom.fromJson(Map<String, dynamic> json) {
    final description = _jsonString(json['description']);
    final avatarHash = _jsonString(json['avatar_hash']);
    final avatarImageB64 = _jsonString(json['avatar_image_b64']);
    final pinnedMessageId = _jsonString(json['pinned_message_id']);
    return RelayRoom(
      roomId: _jsonString(json['room_id']),
      version: _jsonNullableInt(json['version']) ?? 0,
      membershipVersion: _jsonNullableInt(json['membership_version']) ?? 0,
      ownerProfileId: _jsonString(json['owner_profile_id']),
      createdByDeviceId: _jsonString(json['created_by_device_id']),
      title: _jsonString(json['title']),
      description: description.isEmpty ? null : description,
      avatarHash: avatarHash.isEmpty ? null : avatarHash,
      avatarImageB64: avatarImageB64.isEmpty ? null : avatarImageB64,
      reactionsMode: _jsonString(json['reactions_mode']).isEmpty
          ? 'all'
          : _jsonString(json['reactions_mode']),
      allowText: json.containsKey('allow_text')
          ? _jsonBool(json['allow_text'])
          : true,
      allowMedia: json.containsKey('allow_media')
          ? _jsonBool(json['allow_media'])
          : true,
      allowAddMembers: json.containsKey('allow_add_members')
          ? _jsonBool(json['allow_add_members'])
          : true,
      allowPinMessages: json.containsKey('allow_pin_messages')
          ? _jsonBool(json['allow_pin_messages'])
          : true,
      allowChangeGroupInfo: json.containsKey('allow_change_group_info')
          ? _jsonBool(json['allow_change_group_info'])
          : true,
      allowChangeTag: json.containsKey('allow_change_tag')
          ? _jsonBool(json['allow_change_tag'])
          : false,
      joinApprovalRequired: json.containsKey('join_approval_required')
          ? _jsonBool(json['join_approval_required'])
          : false,
      slowModeSeconds: _jsonNullableInt(json['slow_mode_seconds']) ?? 0,
      chatHistoryVisible: json.containsKey('chat_history_visible')
          ? _jsonBool(json['chat_history_visible'])
          : false,
      pinnedMessageId: pinnedMessageId.isEmpty ? null : pinnedMessageId,
      createdAtMs: _jsonNullableInt(json['created_at_ms']) ?? 0,
      updatedAtMs: _jsonNullableInt(json['updated_at_ms']) ?? 0,
    );
  }
}

class RelayRoomMembership {
  const RelayRoomMembership({
    required this.roomId,
    required this.profileId,
    required this.status,
    required this.role,
    required this.sourceLinkId,
    required this.tag,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String roomId;
  final String profileId;
  final String status;
  final String role;
  final String? sourceLinkId;
  final String? tag;
  final int createdAtMs;
  final int updatedAtMs;

  factory RelayRoomMembership.fromJson(Map<String, dynamic> json) {
    final sourceLinkId = _jsonString(json['source_link_id']);
    final tag = _jsonString(json['tag']);
    return RelayRoomMembership(
      roomId: _jsonString(json['room_id']),
      profileId: _jsonString(json['profile_id']),
      status: _jsonString(json['status']),
      role: _jsonString(json['role']),
      sourceLinkId: sourceLinkId.isEmpty ? null : sourceLinkId,
      tag: tag.isEmpty ? null : tag,
      createdAtMs: _jsonNullableInt(json['created_at_ms']) ?? 0,
      updatedAtMs: _jsonNullableInt(json['updated_at_ms']) ?? 0,
    );
  }
}

class RelayRoomInviteLink {
  const RelayRoomInviteLink({
    required this.linkId,
    required this.roomId,
    required this.slug,
    required this.createdByProfileId,
    required this.expiresAtMs,
    required this.maxUses,
    required this.useCount,
    required this.remainingUses,
    required this.requiresApproval,
    required this.allowedRole,
    required this.revoked,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String linkId;
  final String roomId;
  final String slug;
  final String createdByProfileId;
  final int? expiresAtMs;
  final int? maxUses;
  final int useCount;
  final int? remainingUses;
  final bool requiresApproval;
  final String allowedRole;
  final bool revoked;
  final int createdAtMs;
  final int updatedAtMs;

  factory RelayRoomInviteLink.fromJson(Map<String, dynamic> json) {
    return RelayRoomInviteLink(
      linkId: _jsonString(json['link_id']),
      roomId: _jsonString(json['room_id']),
      slug: _jsonString(json['slug']),
      createdByProfileId: _jsonString(json['created_by_profile_id']),
      expiresAtMs: _jsonNullableInt(json['expires_at_ms']),
      maxUses: _jsonNullableInt(json['max_uses']),
      useCount: _jsonNullableInt(json['use_count']) ?? 0,
      remainingUses: _jsonNullableInt(json['remaining_uses']),
      requiresApproval: _jsonBool(json['requires_approval']),
      allowedRole: _jsonString(json['allowed_role']),
      revoked: _jsonBool(json['revoked']),
      createdAtMs: _jsonNullableInt(json['created_at_ms']) ?? 0,
      updatedAtMs: _jsonNullableInt(json['updated_at_ms']) ?? 0,
    );
  }
}

class RelayRoomCreateResult {
  const RelayRoomCreateResult({
    required this.ok,
    required this.created,
    required this.room,
  });

  final bool ok;
  final bool created;
  final RelayRoom room;

  factory RelayRoomCreateResult.fromJson(Map<String, dynamic> json) {
    return RelayRoomCreateResult(
      ok: _jsonBool(json['ok']),
      created: _jsonBool(json['created']),
      room: RelayRoom.fromJson((json['room'] as Map).cast<String, dynamic>()),
    );
  }
}

class RelayRoomMembersSnapshot {
  const RelayRoomMembersSnapshot({required this.room, required this.members});

  final RelayRoom room;
  final List<RelayRoomMembership> members;

  factory RelayRoomMembersSnapshot.fromJson(Map<String, dynamic> json) {
    return RelayRoomMembersSnapshot(
      room: RelayRoom.fromJson((json['room'] as Map).cast<String, dynamic>()),
      members: ((json['members'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (entry) =>
                RelayRoomMembership.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

class RelayRoomMembershipMutationResult {
  const RelayRoomMembershipMutationResult({
    required this.ok,
    required this.changed,
    required this.room,
    required this.membership,
  });

  final bool ok;
  final bool changed;
  final RelayRoom room;
  final RelayRoomMembership membership;

  factory RelayRoomMembershipMutationResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return RelayRoomMembershipMutationResult(
      ok: _jsonBool(json['ok']),
      changed: _jsonBool(json['changed']),
      room: RelayRoom.fromJson((json['room'] as Map).cast<String, dynamic>()),
      membership: RelayRoomMembership.fromJson(
        (json['membership'] as Map).cast<String, dynamic>(),
      ),
    );
  }
}

class RelayRoomStateMutationResult {
  const RelayRoomStateMutationResult({
    required this.ok,
    required this.changed,
    required this.room,
  });

  final bool ok;
  final bool changed;
  final RelayRoom room;

  factory RelayRoomStateMutationResult.fromJson(Map<String, dynamic> json) {
    return RelayRoomStateMutationResult(
      ok: _jsonBool(json['ok']),
      changed: _jsonBool(json['changed']),
      room: RelayRoom.fromJson((json['room'] as Map).cast<String, dynamic>()),
    );
  }
}

class RelayRoomMessageAdmissionResult {
  const RelayRoomMessageAdmissionResult({
    required this.ok,
    required this.messageId,
    required this.kind,
    required this.admittedAtMs,
    required this.nextAllowedAtMs,
    required this.room,
  });

  final bool ok;
  final String messageId;
  final String kind;
  final int admittedAtMs;
  final int? nextAllowedAtMs;
  final RelayRoom room;

  factory RelayRoomMessageAdmissionResult.fromJson(Map<String, dynamic> json) {
    return RelayRoomMessageAdmissionResult(
      ok: _jsonBool(json['ok']),
      messageId: _jsonString(json['message_id']),
      kind: _jsonString(json['kind']).isEmpty
          ? 'text'
          : _jsonString(json['kind']),
      admittedAtMs: _jsonNullableInt(json['admitted_at_ms']) ?? 0,
      nextAllowedAtMs: _jsonNullableInt(json['next_allowed_at_ms']),
      room: RelayRoom.fromJson((json['room'] as Map).cast<String, dynamic>()),
    );
  }
}

class RelayRoomOwnershipTransferResult {
  const RelayRoomOwnershipTransferResult({
    required this.ok,
    required this.room,
    required this.previousOwnerMembership,
    required this.nextOwnerMembership,
  });

  final bool ok;
  final RelayRoom room;
  final RelayRoomMembership previousOwnerMembership;
  final RelayRoomMembership nextOwnerMembership;

  factory RelayRoomOwnershipTransferResult.fromJson(Map<String, dynamic> json) {
    return RelayRoomOwnershipTransferResult(
      ok: _jsonBool(json['ok']),
      room: RelayRoom.fromJson((json['room'] as Map).cast<String, dynamic>()),
      previousOwnerMembership: RelayRoomMembership.fromJson(
        (json['previous_owner_membership'] as Map).cast<String, dynamic>(),
      ),
      nextOwnerMembership: RelayRoomMembership.fromJson(
        (json['next_owner_membership'] as Map).cast<String, dynamic>(),
      ),
    );
  }
}

class RelayRoomDeleteResult {
  const RelayRoomDeleteResult({
    required this.ok,
    required this.room,
    required this.deletedProfileIds,
  });

  final bool ok;
  final RelayRoom room;
  final List<String> deletedProfileIds;

  factory RelayRoomDeleteResult.fromJson(Map<String, dynamic> json) {
    return RelayRoomDeleteResult(
      ok: _jsonBool(json['ok']),
      room: RelayRoom.fromJson((json['room'] as Map).cast<String, dynamic>()),
      deletedProfileIds: _jsonStringList(json['deleted_profile_ids']),
    );
  }
}

class RelayRoomInviteLinksSnapshot {
  const RelayRoomInviteLinksSnapshot({
    required this.room,
    required this.inviteLinks,
  });

  final RelayRoom room;
  final List<RelayRoomInviteLink> inviteLinks;

  factory RelayRoomInviteLinksSnapshot.fromJson(Map<String, dynamic> json) {
    return RelayRoomInviteLinksSnapshot(
      room: RelayRoom.fromJson((json['room'] as Map).cast<String, dynamic>()),
      inviteLinks: ((json['invite_links'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (entry) =>
                RelayRoomInviteLink.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

class RelayRoomInviteLinkMutationResult {
  const RelayRoomInviteLinkMutationResult({
    required this.ok,
    required this.changed,
    required this.room,
    required this.inviteLink,
  });

  final bool ok;
  final bool changed;
  final RelayRoom room;
  final RelayRoomInviteLink inviteLink;

  factory RelayRoomInviteLinkMutationResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return RelayRoomInviteLinkMutationResult(
      ok: _jsonBool(json['ok']),
      changed: _jsonBool(json['changed']),
      room: RelayRoom.fromJson((json['room'] as Map).cast<String, dynamic>()),
      inviteLink: RelayRoomInviteLink.fromJson(
        (json['invite_link'] as Map).cast<String, dynamic>(),
      ),
    );
  }
}

class RelayRoomInvitePreview {
  const RelayRoomInvitePreview({
    required this.room,
    required this.inviteLink,
    required this.activeMemberCount,
    required this.availability,
    required this.requesterMembership,
  });

  final RelayRoom room;
  final RelayRoomInviteLink inviteLink;
  final int activeMemberCount;
  final String availability;
  final RelayRoomMembership? requesterMembership;

  factory RelayRoomInvitePreview.fromJson(Map<String, dynamic> json) {
    final requesterMembership = json['requester_membership'];
    return RelayRoomInvitePreview(
      room: RelayRoom.fromJson((json['room'] as Map).cast<String, dynamic>()),
      inviteLink: RelayRoomInviteLink.fromJson(
        (json['invite_link'] as Map).cast<String, dynamic>(),
      ),
      activeMemberCount: _jsonNullableInt(json['active_member_count']) ?? 0,
      availability: _jsonString(json['availability']),
      requesterMembership: requesterMembership is Map
          ? RelayRoomMembership.fromJson(
              requesterMembership.cast<String, dynamic>(),
            )
          : null,
    );
  }
}

class RelayRoomInviteRedeemResult {
  const RelayRoomInviteRedeemResult({
    required this.ok,
    required this.changed,
    required this.disposition,
    required this.room,
    required this.inviteLink,
    required this.membership,
  });

  final bool ok;
  final bool changed;
  final String disposition;
  final RelayRoom room;
  final RelayRoomInviteLink inviteLink;
  final RelayRoomMembership membership;

  factory RelayRoomInviteRedeemResult.fromJson(Map<String, dynamic> json) {
    return RelayRoomInviteRedeemResult(
      ok: _jsonBool(json['ok']),
      changed: _jsonBool(json['changed']),
      disposition: _jsonString(json['disposition']),
      room: RelayRoom.fromJson((json['room'] as Map).cast<String, dynamic>()),
      inviteLink: RelayRoomInviteLink.fromJson(
        (json['invite_link'] as Map).cast<String, dynamic>(),
      ),
      membership: RelayRoomMembership.fromJson(
        (json['membership'] as Map).cast<String, dynamic>(),
      ),
    );
  }
}

class RelayRoomCall {
  const RelayRoomCall({
    required this.callId,
    required this.roomId,
    required this.state,
    required this.mediaType,
    required this.createdByProfileId,
    required this.createdByDeviceId,
    required this.stateVersion,
    required this.startedAtMs,
    required this.updatedAtMs,
    required this.endedAtMs,
    required this.expiresAtMs,
  });

  final String callId;
  final String roomId;
  final String state;
  final String mediaType;
  final String createdByProfileId;
  final String createdByDeviceId;
  final int stateVersion;
  final int startedAtMs;
  final int updatedAtMs;
  final int? endedAtMs;
  final int expiresAtMs;

  bool get isActive => state == 'active' && endedAtMs == null;

  factory RelayRoomCall.fromJson(Map<String, dynamic> json) {
    return RelayRoomCall(
      callId: _jsonString(json['call_id']),
      roomId: _jsonString(json['room_id']),
      state: _jsonString(json['state']).isEmpty
          ? 'active'
          : _jsonString(json['state']),
      mediaType: _jsonString(json['media_type']).isEmpty
          ? 'audio'
          : _jsonString(json['media_type']),
      createdByProfileId: _jsonString(json['created_by_profile_id']),
      createdByDeviceId: _jsonString(json['created_by_device_id']),
      stateVersion: _jsonNullableInt(json['state_version']) ?? 0,
      startedAtMs: _jsonNullableInt(json['started_at_ms']) ?? 0,
      updatedAtMs: _jsonNullableInt(json['updated_at_ms']) ?? 0,
      endedAtMs: _jsonNullableInt(json['ended_at_ms']),
      expiresAtMs: _jsonNullableInt(json['expires_at_ms']) ?? 0,
    );
  }
}

class RelayRoomCallParticipant {
  const RelayRoomCallParticipant({
    required this.callId,
    required this.roomId,
    required this.profileId,
    required this.deviceId,
    required this.joinState,
    required this.supportsVideo,
    required this.supportsScreenShare,
    required this.muted,
    required this.deafened,
    required this.videoEnabled,
    required this.screenShareEnabled,
    required this.speaking,
    required this.joinedAtMs,
    required this.leftAtMs,
    required this.updatedAtMs,
  });

  final String callId;
  final String roomId;
  final String profileId;
  final String deviceId;
  final String joinState;
  final bool supportsVideo;
  final bool supportsScreenShare;
  final bool muted;
  final bool deafened;
  final bool videoEnabled;
  final bool screenShareEnabled;
  final bool speaking;
  final int joinedAtMs;
  final int? leftAtMs;
  final int updatedAtMs;

  bool get isJoined => joinState == 'joined' || joinState == 'reconnecting';

  factory RelayRoomCallParticipant.fromJson(Map<String, dynamic> json) {
    return RelayRoomCallParticipant(
      callId: _jsonString(json['call_id']),
      roomId: _jsonString(json['room_id']),
      profileId: _jsonString(json['profile_id']),
      deviceId: _jsonString(json['device_id']),
      joinState: _jsonString(json['join_state']).isEmpty
          ? 'joined'
          : _jsonString(json['join_state']),
      supportsVideo: _jsonBool(json['supports_video']),
      supportsScreenShare: _jsonBool(json['supports_screen_share']),
      muted: _jsonBool(json['muted']),
      deafened: _jsonBool(json['deafened']),
      videoEnabled: _jsonBool(json['video_enabled']),
      screenShareEnabled: _jsonBool(json['screen_share_enabled']),
      speaking: _jsonBool(json['speaking']),
      joinedAtMs: _jsonNullableInt(json['joined_at_ms']) ?? 0,
      leftAtMs: _jsonNullableInt(json['left_at_ms']),
      updatedAtMs: _jsonNullableInt(json['updated_at_ms']) ?? 0,
    );
  }
}

class RelayRoomCallSnapshot {
  const RelayRoomCallSnapshot({
    required this.exists,
    required this.room,
    required this.call,
    required this.participants,
    required this.selfParticipant,
  });

  final bool exists;
  final RelayRoom room;
  final RelayRoomCall? call;
  final List<RelayRoomCallParticipant> participants;
  final RelayRoomCallParticipant? selfParticipant;

  factory RelayRoomCallSnapshot.fromJson(Map<String, dynamic> json) {
    final callJson = json['call'];
    final selfParticipantJson = json['self_participant'];
    return RelayRoomCallSnapshot(
      exists: _jsonBool(json['exists']),
      room: RelayRoom.fromJson((json['room'] as Map).cast<String, dynamic>()),
      call: callJson is Map
          ? RelayRoomCall.fromJson(callJson.cast<String, dynamic>())
          : null,
      participants: ((json['participants'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (entry) => RelayRoomCallParticipant.fromJson(
              entry.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      selfParticipant: selfParticipantJson is Map
          ? RelayRoomCallParticipant.fromJson(
              selfParticipantJson.cast<String, dynamic>(),
            )
          : null,
    );
  }
}

class RelayRoomCallMutationResult {
  const RelayRoomCallMutationResult({
    required this.ok,
    required this.changed,
    required this.room,
    required this.call,
    required this.participants,
    required this.selfParticipant,
  });

  final bool ok;
  final bool changed;
  final RelayRoom room;
  final RelayRoomCall call;
  final List<RelayRoomCallParticipant> participants;
  final RelayRoomCallParticipant? selfParticipant;

  RelayRoomCallSnapshot get snapshot => RelayRoomCallSnapshot(
    exists: true,
    room: room,
    call: call,
    participants: participants,
    selfParticipant: selfParticipant,
  );

  factory RelayRoomCallMutationResult.fromJson(Map<String, dynamic> json) {
    final selfParticipantJson = json['self_participant'];
    return RelayRoomCallMutationResult(
      ok: _jsonBool(json['ok']),
      changed: _jsonBool(json['changed']),
      room: RelayRoom.fromJson((json['room'] as Map).cast<String, dynamic>()),
      call: RelayRoomCall.fromJson(
        (json['call'] as Map).cast<String, dynamic>(),
      ),
      participants: ((json['participants'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (entry) => RelayRoomCallParticipant.fromJson(
              entry.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      selfParticipant: selfParticipantJson is Map
          ? RelayRoomCallParticipant.fromJson(
              selfParticipantJson.cast<String, dynamic>(),
            )
          : null,
    );
  }
}

enum RelayRoomCallMediaTopology {
  centralized;

  static RelayRoomCallMediaTopology parse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'centralized':
      default:
        return RelayRoomCallMediaTopology.centralized;
    }
  }
}

enum RelayRoomCallMediaCapabilityState {
  bootstrapOnly,
  sessionAuthReady,
  runtimeReady;

  static RelayRoomCallMediaCapabilityState parse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'session_auth_ready':
        return RelayRoomCallMediaCapabilityState.sessionAuthReady;
      case 'runtime_ready':
        return RelayRoomCallMediaCapabilityState.runtimeReady;
      case 'bootstrap_only':
      default:
        return RelayRoomCallMediaCapabilityState.bootstrapOnly;
    }
  }
}

enum RelayRoomCallMediaBackendKind {
  unavailable,
  livekit;

  static RelayRoomCallMediaBackendKind parse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'livekit':
        return RelayRoomCallMediaBackendKind.livekit;
      case 'unavailable':
      default:
        return RelayRoomCallMediaBackendKind.unavailable;
    }
  }
}

class RelayRoomCallMediaSignalDescriptor {
  const RelayRoomCallMediaSignalDescriptor({
    required this.transportKind,
    required this.descriptorVersion,
  });

  final String transportKind;
  final int descriptorVersion;

  bool get isAvailable => transportKind.trim().isNotEmpty;

  factory RelayRoomCallMediaSignalDescriptor.fromJson(
    Map<String, dynamic> json,
  ) {
    return RelayRoomCallMediaSignalDescriptor(
      transportKind: _jsonString(json['transport_kind']).isEmpty
          ? 'room_call_media_signal_v1'
          : _jsonString(json['transport_kind']),
      descriptorVersion: _jsonNullableInt(json['descriptor_version']) ?? 0,
    );
  }
}

class RelayRoomCallMediaParticipant {
  const RelayRoomCallMediaParticipant({
    required this.profileId,
    required this.deviceId,
    required this.joinState,
    required this.isSelf,
    required this.supportsVideo,
    required this.supportsScreenShare,
    required this.muted,
    required this.deafened,
    required this.videoEnabled,
    required this.screenShareEnabled,
    required this.speaking,
    required this.publishAudio,
    required this.publishVideo,
    required this.publishScreenShare,
    required this.receiveAudio,
    required this.receiveVideo,
    required this.receiveScreenShare,
    required this.updatedAtMs,
  });

  final String profileId;
  final String deviceId;
  final String joinState;
  final bool isSelf;
  final bool supportsVideo;
  final bool supportsScreenShare;
  final bool muted;
  final bool deafened;
  final bool videoEnabled;
  final bool screenShareEnabled;
  final bool speaking;
  final bool publishAudio;
  final bool publishVideo;
  final bool publishScreenShare;
  final bool receiveAudio;
  final bool receiveVideo;
  final bool receiveScreenShare;
  final int updatedAtMs;

  bool get isJoined => joinState == 'joined' || joinState == 'reconnecting';

  factory RelayRoomCallMediaParticipant.fromJson(Map<String, dynamic> json) {
    return RelayRoomCallMediaParticipant(
      profileId: _jsonString(json['profile_id']),
      deviceId: _jsonString(json['device_id']),
      joinState: _jsonString(json['join_state']).isEmpty
          ? 'joined'
          : _jsonString(json['join_state']),
      isSelf: _jsonBool(json['is_self']),
      supportsVideo: _jsonBool(json['supports_video']),
      supportsScreenShare: _jsonBool(json['supports_screen_share']),
      muted: _jsonBool(json['muted']),
      deafened: _jsonBool(json['deafened']),
      videoEnabled: _jsonBool(json['video_enabled']),
      screenShareEnabled: _jsonBool(json['screen_share_enabled']),
      speaking: _jsonBool(json['speaking']),
      publishAudio: _jsonBool(json['publish_audio']),
      publishVideo: _jsonBool(json['publish_video']),
      publishScreenShare: _jsonBool(json['publish_screen_share']),
      receiveAudio: _jsonBool(json['receive_audio']),
      receiveVideo: _jsonBool(json['receive_video']),
      receiveScreenShare: _jsonBool(json['receive_screen_share']),
      updatedAtMs: _jsonNullableInt(json['updated_at_ms']) ?? 0,
    );
  }
}

class RelayRoomCallMediaBackend {
  const RelayRoomCallMediaBackend({
    required this.kind,
    required this.url,
    required this.roomName,
    required this.participantIdentity,
    required this.accessToken,
    required this.accessTokenExpiresAtMs,
  });

  final RelayRoomCallMediaBackendKind kind;
  final String? url;
  final String? roomName;
  final String? participantIdentity;
  final String? accessToken;
  final int? accessTokenExpiresAtMs;

  bool get isConfigured =>
      kind != RelayRoomCallMediaBackendKind.unavailable &&
      (url?.trim().isNotEmpty ?? false);

  bool get hasAccessToken => accessToken?.trim().isNotEmpty ?? false;

  factory RelayRoomCallMediaBackend.fromJson(Map<String, dynamic> json) {
    final url = _jsonString(json['url']);
    final roomName = _jsonString(json['room_name']);
    final participantIdentity = _jsonString(json['participant_identity']);
    final accessToken = _jsonString(json['access_token']);
    return RelayRoomCallMediaBackend(
      kind: RelayRoomCallMediaBackendKind.parse(_jsonString(json['kind'])),
      url: url.isEmpty ? null : url,
      roomName: roomName.isEmpty ? null : roomName,
      participantIdentity: participantIdentity.isEmpty
          ? null
          : participantIdentity,
      accessToken: accessToken.isEmpty ? null : accessToken,
      accessTokenExpiresAtMs: _jsonNullableInt(
        json['access_token_expires_at_ms'],
      ),
    );
  }
}

class RelayRoomCallMediaSession {
  const RelayRoomCallMediaSession({
    required this.roomId,
    required this.callId,
    required this.sessionId,
    required this.contractVersion,
    required this.topology,
    required this.capabilityState,
    required this.mediaType,
    required this.stateVersion,
    required this.selfProfileId,
    required this.selfDeviceId,
    required this.participantCount,
    required this.publishVideoSupported,
    required this.publishScreenShareSupported,
    required this.subscribeAllSupported,
    required this.backend,
    required this.signal,
    required this.ice,
    required this.participants,
  });

  final String roomId;
  final String callId;
  final String sessionId;
  final String contractVersion;
  final RelayRoomCallMediaTopology topology;
  final RelayRoomCallMediaCapabilityState capabilityState;
  final String mediaType;
  final int stateVersion;
  final String selfProfileId;
  final String selfDeviceId;
  final int participantCount;
  final bool publishVideoSupported;
  final bool publishScreenShareSupported;
  final bool subscribeAllSupported;
  final RelayRoomCallMediaBackend backend;
  final RelayRoomCallMediaSignalDescriptor signal;
  final CallIceConfigSnapshot ice;
  final List<RelayRoomCallMediaParticipant> participants;

  bool get isBootstrapOnly =>
      capabilityState == RelayRoomCallMediaCapabilityState.bootstrapOnly;

  bool get hasSessionAuthority =>
      capabilityState == RelayRoomCallMediaCapabilityState.sessionAuthReady ||
      capabilityState == RelayRoomCallMediaCapabilityState.runtimeReady ||
      backend.hasAccessToken;

  bool get isRuntimeReady =>
      capabilityState == RelayRoomCallMediaCapabilityState.runtimeReady;

  int get descriptorVersion => signal.descriptorVersion;

  String get signalTransportKind => signal.transportKind;

  RelayRoomCallMediaParticipant? get selfParticipant {
    for (final participant in participants) {
      if (participant.isSelf) {
        return participant;
      }
    }
    return null;
  }

  factory RelayRoomCallMediaSession.fromJson(Map<String, dynamic> json) {
    final backendJson = json['backend'];
    final iceJson = json['ice'];
    final signalJson = json['signal'];
    final participants = ((json['participants'] as List?) ?? const <Object?>[])
        .whereType<Map>()
        .map(
          (entry) => RelayRoomCallMediaParticipant.fromJson(
            entry.cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
    return RelayRoomCallMediaSession(
      roomId: _jsonString(json['room_id']),
      callId: _jsonString(json['call_id']),
      sessionId: _jsonString(json['session_id']).isEmpty
          ? _jsonString(json['call_id'])
          : _jsonString(json['session_id']),
      contractVersion: _jsonString(json['contract_version']).isEmpty
          ? 'room_media_v1'
          : _jsonString(json['contract_version']),
      topology: RelayRoomCallMediaTopology.parse(_jsonString(json['topology'])),
      capabilityState: RelayRoomCallMediaCapabilityState.parse(
        _jsonString(json['capability_state']),
      ),
      mediaType: _jsonString(json['media_type']).isEmpty
          ? 'audio'
          : _jsonString(json['media_type']),
      stateVersion: _jsonNullableInt(json['state_version']) ?? 0,
      selfProfileId: _jsonString(json['self_profile_id']),
      selfDeviceId: _jsonString(json['self_device_id']),
      participantCount:
          _jsonNullableInt(json['participant_count']) ?? participants.length,
      publishVideoSupported: _jsonBool(json['publish_video_supported']),
      publishScreenShareSupported: _jsonBool(
        json['publish_screen_share_supported'],
      ),
      subscribeAllSupported: _jsonBool(json['subscribe_all_supported']),
      backend: backendJson is Map<String, dynamic>
          ? RelayRoomCallMediaBackend.fromJson(backendJson)
          : backendJson is Map
          ? RelayRoomCallMediaBackend.fromJson(
              backendJson.cast<String, dynamic>(),
            )
          : const RelayRoomCallMediaBackend(
              kind: RelayRoomCallMediaBackendKind.unavailable,
              url: null,
              roomName: null,
              participantIdentity: null,
              accessToken: null,
              accessTokenExpiresAtMs: null,
            ),
      signal: signalJson is Map<String, dynamic>
          ? RelayRoomCallMediaSignalDescriptor.fromJson(signalJson)
          : signalJson is Map
          ? RelayRoomCallMediaSignalDescriptor.fromJson(
              signalJson.cast<String, dynamic>(),
            )
          : RelayRoomCallMediaSignalDescriptor(
              transportKind: 'room_call_media_signal_v1',
              descriptorVersion: _jsonNullableInt(json['state_version']) ?? 0,
            ),
      ice: iceJson is Map<String, dynamic>
          ? CallIceConfigSnapshot.fromJson(iceJson)
          : iceJson is Map
          ? CallIceConfigSnapshot.fromJson(iceJson.cast<String, dynamic>())
          : const CallIceConfigSnapshot.empty(),
      participants: participants,
    );
  }
}

/// The sender device id carried in a ratchet wire's HEADER, or null.
///
/// F-ROOMSK-5. Every quarantine site below used to park a wire with a null
/// sender, because the transport layer never decrypts and so "does not know"
/// who sent it. But it does: the v3 header is plaintext framing (it doubles as
/// the AEAD's AAD), so the author is readable without touching the ratchet.
///
/// Why it matters: `_maybeReplayQuarantinedFromSender` is the FAST recovery
/// path — it fires the moment that peer's next wire decrypts, which for a room
/// message is exactly when the missing `gkey` lands. A null-sender row is
/// invisible to it and waits for the slow full sweep instead. Same eventual
/// outcome, minutes apart.
///
/// Never throws: a malformed or non-v3 wire simply yields null and the row is
/// parked exactly as before.
String? _senderDeviceIdFromWireHeader(String ciphertextB64) {
  try {
    final decoded = RatchetWireV3.tryDecode(
      Uint8List.fromList(base64Decode(ciphertextB64)),
    );
    final sid = (decoded?.header['sender_device_id'] as String?)?.trim();
    return (sid == null || sid.isEmpty) ? null : sid;
  } catch (_) {
    return null;
  }
}

/// True when this wire carries a full X3DH handshake (a `prekey` wire) — i.e.
/// it is the CURE for a broken session with its sender, not ordinary traffic.
///
/// Readable WITHOUT decrypting: the wire kind is one byte of the SKS2 frame
/// (see `wire_v3.dart`), so a device whose session is dead can still tell
/// medicine from poison. That is what makes the rescue in [_drainReorderBuffer]
/// possible at all.
bool _isHandshakeWire(String ciphertextB64) {
  try {
    final decoded = RatchetWireV3.tryDecode(
      Uint8List.fromList(base64Decode(ciphertextB64)),
    );
    return decoded?.kind == RatchetWireKindV3.prekey;
  } catch (_) {
    return false;
  }
}

class RelayClient {
  RelayClient({
    required this.db,
    required this.deviceId,
    required this.selfProfileId,
    required this.deviceKeys,
    required this.wsUrl,
    required this.httpBaseUrl,
    required this.onDelivered,
    required this.loadNextSeq,
    required this.saveNextSeq,
    http.Client? httpClient,
    SimpleKeyPair? identityKeyPairOverride,
    RelayWebSocketConnector? webSocketConnector,
    this.onConnectionChanged,
    this.onFirstDrainCompleted,
    this.clientBuild = '',
    this.onServerError,
  }) : _http = httpClient ?? createResilientHttpClient(),
       _ownsHttpClient = httpClient == null,
       _identityKeyPairOverride = identityKeyPairOverride,
       _webSocketConnector = webSocketConnector ?? connectResilientWebSocket;

  final AppDb db;
  final String deviceId;
  final String selfProfileId;
  final DeviceKeys deviceKeys;
  final http.Client _http;
  final bool _ownsHttpClient;
  final SimpleKeyPair? _identityKeyPairOverride;
  final RelayWebSocketConnector _webSocketConnector;
  final Uri wsUrl;
  final Uri? httpBaseUrl;

  /// Номер сборки приложения — уезжает справочным заголовком к реле, чтобы
  /// можно было посчитать долю устройств, умеющих принимать повтор
  /// рукопожатия. Пустая строка = не отправлять.
  final String clientBuild;

  final void Function(bool connected)? onConnectionChanged;

  /// Первый разбор входящего ящика с момента запуска ЗАВЕРШЁН.
  ///
  /// 🔴 Отдельный канал, а НЕ [onConnectionChanged]. Обработчик подключения
  /// поднимает целый каскад: принудительную дозагрузку /v1/pending, синхронизацию
  /// пуш- и VoIP-токенов, обновление ICE, ресинк состояния реле. Сообщать им о
  /// разборе ящика значит запускать весь этот каскад ВТОРОЙ раз сразу после
  /// настоящего подключения — ровно тот класс лишнего трафика, с которым этот
  /// проект боролся не раз.
  ///
  /// Здесь нужно единственное: перерисовать экран, который ждёт ответа на
  /// вопрос «чат правда пуст или мы ещё не знаем».
  final void Function()? onFirstDrainCompleted;
  final void Function(String code, String message)? onServerError;

  /// Called for a newly delivered ciphertext (dedup already handled).
  ///
  /// Returns true when message was fully processed and can be marked seen+acked.
  /// Returns false for transient failures (for example decrypt/session race), in
  /// which case delivery is retried without advancing sequence.
  final Future<bool> Function({
    required String msgId,
    required String ciphertextB64,
  })
  onDelivered;

  final Future<int> Function() loadNextSeq;
  final Future<void> Function(int) saveNextSeq;

  /// Курсор, ожидающий записи, и время последней фактической записи.
  ///
  /// 🔴 ПОЧЕМУ (02.09.2026, аудит скорости доставки). Курсор писался на КАЖДОЕ
  /// разобранное сообщение, а запись идёт через платформенный канал в
  /// хранилище настроек. На пачке из шестидесяти конвертов это шестьдесят
  /// обращений через канал, и все — в главном изоляте, вперемежку с
  /// расшифровкой и отрисовкой.
  ///
  /// 🔴 ПОЧЕМУ ЭТО БЕЗОПАСНО, хотя курсор — часть модели надёжности. Он
  /// защищает от ПОВТОРНОЙ ВЫДАЧИ, а не от потери. Если процесс убьют между
  /// записями, курсор откатится на несколько сообщений, реле переотдаст их — и
  /// они отсеются: `inboxHasSeen` проверяется ПЕРЕД расшифровкой, а
  /// `inboxMarkSeen` пишется в базу (транзакционно) ещё до подтверждения реле.
  /// То есть отметка «уже видели» переживает падение надёжнее самого курсора,
  /// и худший исход — несколько лишних проверок в базе.
  ///
  /// Порядок «подтверждение раньше курсора» не меняется: правка двигает только
  /// запись курсора и не трогает `_sendAck`.
  static const int _cursorSaveMinIntervalMs = 250;
  int? _pendingCursorSeq;
  int _lastCursorSaveAtMs = 0;

  Future<void> _saveNextSeqThrottled(int value) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = nowMs - _lastCursorSaveAtMs;
    if (elapsed >= _cursorSaveMinIntervalMs || elapsed < 0) {
      _lastCursorSaveAtMs = nowMs;
      _pendingCursorSeq = null;
      await saveNextSeq(value);
      return;
    }
    _pendingCursorSeq = value;
  }

  /// Дописывает отложенный курсор. Обязателен в `finally` слива: без него
  /// последняя пачка сообщений осталась бы за пределами сохранённого курсора,
  /// и реле переотдало бы её при следующем подключении.
  Future<void> _flushPendingCursorSave() async {
    final pending = _pendingCursorSeq;
    if (pending == null) return;
    _pendingCursorSeq = null;
    _lastCursorSaveAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      await saveNextSeq(pending);
    } catch (_) {
      // Не удалось записать — курсор откатится, сообщения переотдадутся и
      // отсеются по `inbox_seen`. Ронять слив из-за этого нельзя.
    }
  }

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _rng = Random();
  SimpleKeyPair? _identityKeyPair;
  int _nextSeq = 1;
  final Map<int, Deliver> _reorderBuffer = {};
  Timer? _gapFetchTimer;
  int? _lastGapSeqRequested;
  // DEEP-SLEEP GAP RECOVERY (2026-07-14): when the realtime WS gap-fetch does
  // not fill a hole, we escalate to a RELIABLE HTTP pump instead of skipping on
  // unconfirmed WS state (the deep-sleep message loss). Debounce the escalation
  // per-seq so a network-out window can't hot-loop the pump.
  int? _lastGapHttpEscalationSeq;
  int _lastGapHttpEscalationAtMs = 0;
  int _reconnectAttempt = 0;
  int _backoffSeedMs = 0;
  Timer? _reconnectTimer;
  Timer? _deliveryRetryTimer;
  bool _connecting = false;
  bool _connected = false;
  bool _wsReady = false;

  /// Идёт принудительная выборка ящика.
  ///
  /// Пока она идёт, обычный тик не имеет права проскочить по проверке свежести:
  /// он пропустил бы затор, который мы явно просили разобрать. Признак заменил
  /// обнуление отметки живости — то ослепляло насос на все последующие тики.
  bool _forceDrainInFlight = false;

  /// 🔴 ОТСТУПЛЕНИЕ ПРИ «СЛИШКОМ МНОГО ЗАПРОСОВ» (14.08.2026).
  ///
  /// ЗАМЕР (8 минут поля, звонки владельца): **413 запросов выборки и 438
  /// ответов 429**. Ящик был закрыт больше половины времени — и звонок,
  /// принятый человеком, не собирался: `offer` и `ice` физически не могли
  /// доехать, `call_ended reason=timeout` через 30 секунд.
  ///
  /// КОРЕНЬ НЕ В ЛИМИТЕ, А В ТОМ, ЧТО МЫ ЕГО НЕ ЗАМЕЧАЛИ. На 429 клиент делал
  /// `return` — без паузы, без отметки. Следующий запрос уходил через 0,4
  /// секунды, бакет не успевал восстановиться НИКОГДА, и приложение держало
  /// себя в блокировке само.
  ///
  /// Лимит на реле считается ПО IP, а не по устройству: телефон и планшет за
  /// одним домашним Wi-Fi делят один бакет. Разговор между двумя своими
  /// устройствами тратит его вдвое быстрее — поэтому «сначала созванивался, а
  /// потом перестало».
  ///
  /// Ноль означает «не ограничены».
  int _rateLimitedUntilMs = 0;
  int _rateLimitBackoffMs = 0;

  static const int _rateLimitBackoffStartMs = 1000;
  static const int _rateLimitBackoffMaxMs = 30000;

  /// Стартовая ступень отступления. Подменяется ТОЛЬКО тестом.
  ///
  /// 🔴 Без этого тест обязан ждать настоящую секунду, а настоящее ожидание в
  /// общем прогоне сдвигает тайминг СОСЕДНИХ тестов: один из них уже упал так,
  /// проходя при этом в одиночку. Тест, который валит другие тесты, — плохой
  /// тест, даже когда проверяет верное.
  @visibleForTesting
  static int rateLimitBackoffStartMsForTest = _rateLimitBackoffStartMs;

  /// Молчим ли мы сейчас, уступая лимиту.
  bool get _isRateLimited {
    if (_rateLimitedUntilMs == 0) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Часы устройства могут прыгнуть назад (сон, смена пояса, ручная правка).
    // Отступление, пережившее свой потолок, — это молчание навсегда, поэтому
    // окно ограничено сверху не только сроком, но и здравым смыслом.
    if (_rateLimitedUntilMs - now > _rateLimitBackoffMaxMs) {
      _rateLimitedUntilMs = 0;
      _rateLimitBackoffMs = 0;
      return false;
    }
    return now < _rateLimitedUntilMs;
  }

  /// Реле сказало «слишком много»: удлиняем паузу вдвое, до потолка.
  void _noteRateLimited(String where) {
    // 🔴 НЕ ЧАЩЕ ОДНОГО РАЗА ЗА САМУ ПАУЗУ (15.08.2026, замер во время звонка).
    //
    // Первая версия удваивала паузу на КАЖДЫЙ отказ. Во время разговора запросы
    // идут пачкой, отказы приходят пачкой — и поле показало рост
    // 1→2→4→8→16→30 секунд ЗА 160 МИЛЛИСЕКУНД. Полминуты молчания посреди
    // звонка убивают его вернее, чем исходное долбление: ни сигналы не уходят,
    // ни ящик не читается.
    //
    // Отказы, пришедшие ВНУТРИ действующей паузы, — это ответы на запросы,
    // стартовавшие ДО неё. Они уже учтены; наказывать за них второй раз значит
    // наказывать за собственное эхо.
    if (_isRateLimited) return;
    final startMs = rateLimitBackoffStartMsForTest;
    _rateLimitBackoffMs = _rateLimitBackoffMs == 0
        ? startMs
        : (_rateLimitBackoffMs * 2).clamp(startMs, _rateLimitBackoffMaxMs);
    _rateLimitedUntilMs =
        DateTime.now().millisecondsSinceEpoch + _rateLimitBackoffMs;
    DiagLog.event('relay', 'rate_limited_backoff', {
      'where': where,
      'backoff_ms': _rateLimitBackoffMs,
    });
  }

  /// Любой успешный ответ снимает отступление: лимит — состояние сервера, а не
  /// наше, и держаться за него дольше нужного значит терять доставку.
  /// У-1 (17.09.2026): реле не знает это устройство (`401 unknown device`).
  /// Контроллер сам спрашивает сервер ключей, снята ли регистрация.
  void Function()? onUnknownDevice;

  /// 26.09.2026: реле не приняло подпись (`401 bad signature`) — ключ, которым
  /// подписано, не тот, что зарегистрирован у этого устройства. Само не
  /// проходит: без хука ПК молча копил сообщения на сервере.
  void Function()? onBadSignature;

  /// Реле приняло подписанный запрос этого устройства: регистрация на месте.
  /// Снимает полосу «устройство отключено», поднятую по ошибке (например,
  /// пока свежий номер после восстановления ещё регистрировался).
  void Function()? onDeviceAccepted;

  /// П-4 (25.09.2026): реле не стало хранить посылку «только на связи» —
  /// получатель [toDeviceId] не на связи. Контроллер не шлёт ему «печатает»
  /// минуту: ключ цепочки не тратится на заведомо недоставляемое.
  void Function(String toDeviceId)? onOnlineOnlyDropped;

  /// П-1 (25.09.2026): сводка росписи адресата для строки исходящих; null —
  /// сводку не ставить. Сам вызов null — сверка выключена (доля
  /// `device_check_percent`), и пути отправки побайтово прежние.
  Future<String?> Function(Map<String, Object?> row)? deviceCheckDigestFor;

  /// П-1: реле сказало, что сводка отправителя устарела; [deviceIds] —
  /// настоящий список «кому слать» адресата посылки [msgId].
  void Function(String msgId, List<String> deviceIds)? onDeviceSetStale;

  /// П-1: реле не знает устройства-адресата (HTTP 400) — роспись устарела.
  void Function(String toDeviceId)? onUnknownRecipientDevice;

  Future<String?> _rowDeviceDigest(Map<String, Object?> row) async {
    final f = deviceCheckDigestFor;
    if (f == null) return null;
    try {
      return await f(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> _noteOnlineOnlyDropped(String msgId) async {
    final cb = onOnlineOnlyDropped;
    if (cb == null) return;
    try {
      final target = await db.outboxNackTarget(msgId);
      final to = target?.toDeviceId.trim() ?? '';
      if (to.isNotEmpty) cb(to);
    } catch (_) {
      // Только подсказка отправителю; её потеря стоит одной лишней посылки.
    }
  }

  void _noteRelayRequestSucceeded() {
    if (_rateLimitedUntilMs == 0 && _rateLimitBackoffMs == 0) return;
    _rateLimitedUntilMs = 0;
    _rateLimitBackoffMs = 0;
    DiagLog.event('relay', 'rate_limit_cleared', const <String, Object?>{});
  }

  /// Когда соединение стало готовым. Нужно, чтобы назвать ЕГО ВРЕМЯ ЖИЗНИ при
  /// закрытии: «рвётся сразу» и «рвётся через минуту» — разные болезни.
  int _wsOpenedAtMs = 0;

  // ── СВОДКА ПО ЖИЗНИ СОЕДИНЕНИЯ (11.09.2026) ─────────────────────────────
  //
  // 🔴 ЗАЧЕМ. Диагностика показывала только итоговое `relay_online`, и на
  // iPhone оно ЛГАЛО: приложение сообщало `relay_online: true` в тот самый
  // момент, когда реле считало устройство не на связи (из 77 попыток доставки
  // в реальном времени прошли 22, остальные ушли через пуш). Пока приложение
  // верит, что соединено, оно не переподключается — исходящее копится и
  // выходит залпом через минуту. Звонки этого не переживают: таймаут 42 с
  // короче задержки.
  //
  // Отдельные события `ws_open` / `ws_closed` в журнале были и раньше, но
  // журнал живёт в памяти и до разбора не доживает. Эти счётчики — то же
  // самое, но накопленное и читаемое постфактум с экрана диагностики.
  //
  // Только наблюдение: ни одно поле отсюда не влияет на поведение.
  int _wsConnectCount = 0;
  int _wsCloseCount = 0;
  int _wsTotalUptimeMs = 0;
  int _wsLastCloseAtMs = 0;
  int _wsLastLivedMs = -1;
  String _wsLastCloseWhy = '';
  int _wsLastCloseCode = 0;
  final Map<String, int> _wsCloseWhyCounts = <String, int>{};

  /// Человекочитаемая сводка для экрана диагностики. Пустая строка означает,
  /// что соединение ни разу не поднималось за эту сессию.
  String get wsLifecycleSummary {
    if (_wsConnectCount == 0 && _wsCloseCount == 0) return '';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final live = _wsOpenedAtMs == 0 ? -1 : nowMs - _wsOpenedAtMs;
    final parts = <String>[
      'подъёмов=$_wsConnectCount',
      'обрывов=$_wsCloseCount',
      if (live >= 0)
        'сейчас живёт=${(live / 1000).toStringAsFixed(0)}с'
      else
        'сейчас НЕ подключён',
      'суммарно в сети=${(_wsTotalUptimeMs / 1000).toStringAsFixed(0)}с',
    ];
    if (_wsCloseCount > 0) {
      parts.add(
        'последний обрыв: why=$_wsLastCloseWhy code=$_wsLastCloseCode '
        'прожил=${_wsLastLivedMs < 0 ? '?' : '${(_wsLastLivedMs / 1000).toStringAsFixed(0)}с'} '
        '${_wsLastCloseAtMs == 0 ? '' : '(${((nowMs - _wsLastCloseAtMs) / 1000).toStringAsFixed(0)}с назад)'}',
      );
      final byWhy = _wsCloseWhyCounts.entries
          .map((e) => '${e.key}×${e.value}')
          .join(' ');
      if (byWhy.isNotEmpty) parts.add('причины: $byWhy');
    }
    return parts.join(' · ');
  }

  bool _isDraining = false;

  /// Прошёл ли хотя бы один разбор входящего ящика с запуска.
  bool _firstDrainCompleted = false;
  bool get firstDrainCompleted => _firstDrainCompleted;
  int _drainStartedAtMs = 0;
  int _drainGeneration = 0;
  int _drainWatchdogMs = 30000;

  /// Test seam: shrink the stuck-drain watchdog window so a regression test can
  /// exercise the force-release path without a 30 s real-time wait.
  @visibleForTesting
  set debugDrainWatchdogMs(int v) => _drainWatchdogMs = v;
  bool _isOutboxPumping = false;
  int _outboxPumpStartedAtMs = 0;
  int _outboxPumpGeneration = 0;
  static const int _outboxWatchdogMs = 30000;
  bool _outboxPumpQueued = false;
  int _lastAckFailureAtMs = 0;
  int _ackFailureCount = 0;
  String? _lastAckFailureSummary;
  final Map<int, int> _deliveryApplyFailuresBySeq = {};
  late final OutgoingMessageScheduler _outgoingScheduler =
      OutgoingMessageScheduler(db: db, pumpTransport: pumpOutbox);

  // WS heartbeat / liveness tracking.
  Timer? _pingTimer;
  bool _waitingForPong = false;
  int _lastWsActivityAtMs = 0;

  static const int _outboxMaxAttempts = 6;
  static const int _outboxBatchLimit = 50;
  static const int _maxDeliveryApplyFailuresPerSeq = 6;

  /// SLOW-DRAIN FIX R9 (2026-07-16): upper bound on ONE apply attempt inside
  /// the serial drain. Was 20s — with 6 retries and the 1.2s retry delay a
  /// single wedged seq stalled the whole mailbox for ~2 minutes, and a run of
  /// them produced the field incident "app open, 63-envelope backlog trickles
  /// for ~48 min". A healthy apply (ratchet decrypt + DB insert) is
  /// milliseconds; the former 20s ceiling only ever mattered when a network
  /// call was stuck INSIDE the apply path — those calls are now prefetched /
  /// backgrounded (session_manager_v3 bundle prefetch, device→profile lookup),
  /// so 10s comfortably covers worst-case local work (cold keystore, big
  /// history chunk in a single txn) while halving the poisoned-seq stall.
  /// Must stay well below `_drainWatchdogMs` (30s).
  static const Duration _deliveryApplyTimeout = Duration(seconds: 10);
  static const Duration _httpTimeout = Duration(seconds: 10);
  static const Duration _wsReadyTimeout = Duration(seconds: 6);
  static const Duration _reorderGapFetchDebounce = Duration(milliseconds: 800);
  // Minimum spacing between reliable-HTTP gap escalations for the SAME hole.
  static const int _gapHttpEscalationMinIntervalMs = 1500;
  static const Duration _deliveryRetryDelay = Duration(milliseconds: 1200);
  // How long without any WS activity before pumpInbox falls back to HTTP.
  // Fix 1b (2026-07-24): 30s→12s. After an offline→online flip a FOREGROUND app
  // (no lifecycle-resume event) fell back on the ping/pong timeout — up to ~40s
  // — to notice the half-open socket and reconnect+refetch the backlog, which is
  // the field "долго" (slow) delivery. The connectivity kick
  // (_scheduleRelayReconnectKick, ~400ms) is the fast path but did NOT fire on
  // iOS in the 2026-07-24 trace, so these constants are the reliable backstop.
  static const int _wsStaleThresholdMs = 12000;
  // Ping interval — we ping after this much silence on the WS.
  static const Duration _wsPingIdleThreshold = Duration(seconds: 5);
  // Ping timer period — also the window to receive a pong. Dead-socket detection
  // is up to 2 periods (ping on one tick, reconnect on the next with no pong),
  // so ~16s worst case, down from ~40s. Kept above a few seconds so a healthy
  // but momentarily busy socket isn't torn down on a single missed pong.
  static const Duration _wsPingTimerPeriod = Duration(seconds: 8);

  int get lastAckFailureAtMs => _lastAckFailureAtMs;
  int get ackFailureCount => _ackFailureCount;

  /// Отдаёт момент окончания запуска приложения. Ставится снаружи, чтобы
  /// транспорт не зависел от контроллера.
  int Function()? readyAtMsProvider;
  String? get lastAckFailureSummary => _lastAckFailureSummary;

  String _summarizeAckError(Object error) {
    final raw = error.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
    if (raw.isEmpty) return error.runtimeType.toString();
    return raw.length <= 240 ? raw : raw.substring(0, 240);
  }

  int _retryDelayMsForAttempt(int attempt) {
    // attempt is 1-based (first send attempt = 1).
    final a = attempt < 1 ? 1 : (attempt > 16 ? 16 : attempt);
    // 0.8s, 1.6s, 3.2s... capped at 30s.
    var base = 800 * (1 << (a - 1));
    if (base > 30000) base = 30000;
    final jitter = _rng.nextInt(350);
    return base + jitter;
  }

  bool _outboxExpired({
    required int nowMs,
    required int createdAtMs,
    required int ttlSeconds,
  }) {
    if (ttlSeconds <= 0) return false;
    return nowMs > createdAtMs + (ttlSeconds * 1000);
  }

  String _safeErrorText(Object error) {
    final raw = error.toString().replaceAll('\n', ' ').replaceAll('\r', ' ');
    if (raw.length <= 180) return raw;
    return '${raw.substring(0, 180)}…';
  }

  Future<void> _handleWsSendError({
    required String msgId,
    required String code,
    required String message,
  }) async {
    final cleanMsgId = msgId.trim();
    final cleanCode = code.trim().isEmpty ? 'unknown' : code.trim();
    final cleanMessage = _safeErrorText(
      message.trim().isEmpty ? cleanCode : message.trim(),
    );
    onServerError?.call(cleanCode, cleanMessage);
    if (cleanMsgId.isEmpty) return;

    final classification = MessageFailureReason.classifyRelaySendError(
      cleanCode,
    );
    DiagLog.event('outbox', 'send_error', {
      'transport': 'ws',
      'msg': DiagLog.pfx(cleanMsgId),
      'code': cleanCode,
      'permanent': classification.permanent,
      'reason': classification.reason,
    });
    if (classification.permanent) {
      await db.outboxMarkFailed(
        cleanMsgId,
        reasonCode: classification.reason,
        errorCode: classification.reason,
        errorMessageRedacted: 'relay send_error: $cleanCode',
      );
      return;
    }

    await db.outboxMarkSending(
      cleanMsgId,
      retryAfterMs: _retryDelayMsForAttempt(1),
      reasonCode: classification.reason,
    );
    unawaited(pumpOutbox());
  }

  Future<bool> health() async {
    final status = await healthStatus();
    return status.isHealthy;
  }

  Future<ServiceHealthStatus> healthStatus({int? clientProtocolVersion}) async {
    final base = httpBaseUrl;
    if (base == null) {
      return ServiceHealthStatus.unreachable(service: 'relay');
    }
    try {
      final uri = base
          .resolve('/health')
          .replace(
            queryParameters: {
              if (clientProtocolVersion != null)
                'client_protocol_version': clientProtocolVersion.toString(),
            },
          );
      final resp = await _http.get(uri).timeout(_httpTimeout);
      if (resp.statusCode == 426 ||
          (resp.statusCode >= 200 && resp.statusCode < 300)) {
        return ServiceHealthStatus.fromHttpResponse(
          httpStatusCode: resp.statusCode,
          responseBody: resp.body,
          fallbackService: 'relay',
          requestedClientProtocolVersion: clientProtocolVersion,
        );
      }
    } catch (_) {
      return ServiceHealthStatus.unreachable(service: 'relay');
    }
    return ServiceHealthStatus.unreachable(service: 'relay');
  }

  Uri _requireHttpBaseUrl(String operation) {
    final base = httpBaseUrl;
    if (base != null) {
      return base;
    }
    throw RelayHttpException(
      operation: operation,
      message: 'HTTP base URL not configured',
    );
  }

  Future<Map<String, String>> _signedRelayHeaders({
    required List<int> Function(int tsMs, String nonceB64) buildMessage,
    Map<String, String> extraHeaders = const <String, String>{},
  }) async {
    final tsMs = ServerClock.instance.nowMs();
    final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
    final msg = buildMessage(tsMs, nonceB64);
    final sigB64 = await AuthSigner.signEd25519B64(
      identityKeyPair: await _loadIdentityKeyPair(),
      message: msg,
    );
    return <String, String>{
      ...extraHeaders,
      'x-secretly-device-id': deviceId,
      'x-secretly-ts-ms': tsMs.toString(),
      'x-secretly-nonce-b64': nonceB64,
      'x-secretly-signature-b64': sigB64,
      // 🔴 Номер сборки, СПРАВОЧНО (03.08.2026). Нужен ровно для одного:
      // ответить, какая доля активных устройств уже умеет ПРИНИМАТЬ повтор
      // рукопожатия — без этой цифры включение отправки было бы ставкой.
      //
      // Заголовок НАМЕРЕННО вне подписи. Подписываемые сообщения имеют
      // фиксированный вид, общий с сервером; добавить в них поле — значит
      // сломать совместимость со всеми существующими сборками ради счётчика.
      // Поэтому сервер и не принимает по нему никаких решений.
      if (clientBuild.isNotEmpty) 'x-secretly-client-build': clientBuild,
    };
  }

  Never _throwRelayHttpFailure(String operation, http.Response response) {
    var message = 'HTTP ${response.statusCode}';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final serverMessage = _jsonString(decoded['message']);
        if (serverMessage.isNotEmpty) {
          message = serverMessage;
        }
      }
    } catch (_) {
      final raw = response.body.trim();
      if (raw.isNotEmpty) {
        message = raw;
      }
    }
    throw RelayHttpException(
      operation: operation,
      statusCode: response.statusCode,
      message: message,
      responseBody: response.body,
    );
  }

  Map<String, dynamic> _decodeRelayJsonBody(
    String operation,
    http.Response response,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwRelayHttpFailure(operation, response);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    throw RelayHttpException(
      operation: operation,
      statusCode: response.statusCode,
      message: 'Unexpected response body',
      responseBody: response.body,
    );
  }

  Future<Map<String, dynamic>> _getSignedJson({
    required String operation,
    required Uri uri,
    required List<int> Function(int tsMs, String nonceB64) buildMessage,
  }) async {
    final headers = await _signedRelayHeaders(buildMessage: buildMessage);
    final response = await _http
        .get(uri, headers: headers)
        .timeout(_httpTimeout);
    return _decodeRelayJsonBody(operation, response);
  }

  Future<Map<String, dynamic>> _postSignedJson({
    required String operation,
    required Uri uri,
    required Object body,
    required List<int> Function(int tsMs, String nonceB64) buildMessage,
  }) async {
    final headers = await _signedRelayHeaders(
      buildMessage: buildMessage,
      extraHeaders: const <String, String>{'content-type': 'application/json'},
    );
    final response = await _http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(_httpTimeout);
    return _decodeRelayJsonBody(operation, response);
  }

  Future<RelayRoomCreateResult> createRoom({
    required String roomId,
    required String title,
  }) async {
    final operation = 'Relay room create';
    final cleanedRoomId = roomId.trim();
    final cleanedTitle = title.trim();
    final uri = _requireHttpBaseUrl(operation).resolve('/v1/rooms');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{'room_id': cleanedRoomId, 'title': cleanedTitle},
      buildMessage: (tsMs, nonceB64) => AuthSigner.relayHttpRoomCreateMessage(
        deviceId: deviceId,
        roomId: cleanedRoomId,
        title: cleanedTitle,
        tsMs: tsMs,
        nonceB64: nonceB64,
      ),
    );
    return RelayRoomCreateResult.fromJson(json);
  }

  /// Submit an E2EE support ticket.
  /// [ciphertextB64] is a SupportSeal sealed to the support public key (the relay
  /// stores it opaquely); [replyPubkeyB64] is where the admin seals replies.
  Future<void> submitSupport({
    required String ticketId,
    required String replyPubkeyB64,
    required String ciphertextB64,
    String? clientMetaJson,
  }) async {
    const operation = 'Relay support submit';
    final uri = _requireHttpBaseUrl(operation).resolve('/v1/support');
    await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'ticket_id': ticketId,
        'reply_pubkey_b64': replyPubkeyB64,
        'ciphertext_b64': ciphertextB64,
        if (clientMetaJson != null && clientMetaJson.isNotEmpty)
          'client_meta_json': clientMetaJson,
      },
      buildMessage: (tsMs, nonceB64) => AuthSigner.relayHttpSupportSubmitMessage(
        deviceId: deviceId,
        ticketId: ticketId,
        replyPubkeyB64: replyPubkeyB64,
        tsMs: tsMs,
        nonceB64: nonceB64,
      ),
    );
  }

  /// Poll admin replies to this device's support tickets from cursor [fromSeq].
  /// Returns the raw reply maps ({reply_id, ticket_id, seq, ciphertext_b64,
  /// created_at_ms}); the caller decrypts `ciphertext_b64` with its support seed.
  /// Ответы поддержки новее [fromSeq] и отметка «переписку стёрли».
  ///
  /// 🔴 Отметка нужна потому, что удаление НЕ ВИДНО на опросе: пустой ответ
  /// после очистки неотличим от обычного «нового ничего нет». Без неё телефон
  /// держал бы стёртую ленту и красный кружок навсегда. Старое реле поля не
  /// вернёт — тогда 0, то есть «не стирали», и поведение прежнее.
  Future<({List<Map<String, dynamic>> replies, int clearedAtMs})>
      supportRepliesWithState({int fromSeq = 0}) async {
    const operation = 'Relay support replies';
    final uri = _requireHttpBaseUrl(operation)
        .resolve('/v1/support/replies?from=$fromSeq');
    final json = await _getSignedJson(
      operation: operation,
      uri: uri,
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpSupportRepliesMessage(
        deviceId: deviceId,
        from: fromSeq,
        tsMs: tsMs,
        nonceB64: nonceB64,
      ),
    );
    return (
      replies: (json['replies'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
      clearedAtMs: (json['support_cleared_at_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<Map<String, dynamic>>> supportReplies({int fromSeq = 0}) async =>
      (await supportRepliesWithState(fromSeq: fromSeq)).replies;

  /// FIX-2 (one-way blackout recovery): ask the relay to migrate a rotated-away
  /// device's un-acked mailbox into THIS (live) device's mailbox, so messages a
  /// peer queued for the old device while we were offline are recovered instead
  /// of dying at the mailbox TTL. Authenticated as this device; the relay only
  /// allows the move when both devices share a profile. Returns the number of
  /// messages moved. Best-effort.
  Future<int> rebindDevice({required String oldDeviceId}) async {
    final operation = 'Relay device rebind';
    final cleanedOld = oldDeviceId.trim();
    if (cleanedOld.isEmpty || cleanedOld == deviceId) return 0;
    final uri = _requireHttpBaseUrl(operation).resolve('/v1/device/rebind');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'new_device_id': deviceId,
        'old_device_id': cleanedOld,
      },
      buildMessage: (tsMs, nonceB64) => AuthSigner.relayHttpRebindMessage(
        newDeviceId: deviceId,
        oldDeviceId: cleanedOld,
        tsMs: tsMs,
        nonceB64: nonceB64,
      ),
    );
    final moved = json['moved'];
    if (moved is int) return moved;
    if (moved is num) return moved.toInt();
    return 0;
  }

  Future<RelayRoom> getRoom({required String roomId}) async {
    final operation = 'Relay room get';
    final cleanedRoomId = roomId.trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}');
    final json = await _getSignedJson(
      operation: operation,
      uri: uri,
      buildMessage: (tsMs, nonceB64) => AuthSigner.relayHttpRoomGetMessage(
        deviceId: deviceId,
        roomId: cleanedRoomId,
        tsMs: tsMs,
        nonceB64: nonceB64,
      ),
    );
    return RelayRoom.fromJson(json);
  }

  Future<RelayRoomMembersSnapshot> listRoomMembers({
    required String roomId,
  }) async {
    final operation = 'Relay room members list';
    final cleanedRoomId = roomId.trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/members');
    final json = await _getSignedJson(
      operation: operation,
      uri: uri,
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomMembersListMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomMembersSnapshot.fromJson(json);
  }

  Future<RelayRoomMembershipMutationResult> upsertRoomMembership({
    required String roomId,
    required String profileId,
    required String status,
    required String role,
    String? sourceLinkId,
  }) async {
    final operation = 'Relay room membership upsert';
    final cleanedRoomId = roomId.trim();
    final cleanedProfileId = profileId.trim();
    final cleanedStatus = status.trim();
    final cleanedRole = role.trim();
    final normalizedSourceLinkId = (sourceLinkId ?? '').trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/members');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'profile_id': cleanedProfileId,
        'status': cleanedStatus,
        'role': cleanedRole,
        'source_link_id': normalizedSourceLinkId.isEmpty
            ? null
            : normalizedSourceLinkId,
      },
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomMembersUpsertMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            profileId: cleanedProfileId,
            status: cleanedStatus,
            role: cleanedRole,
            sourceLinkId: normalizedSourceLinkId,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomMembershipMutationResult.fromJson(json);
  }

  Future<RelayRoomMembershipMutationResult> unbanRoomMember({
    required String roomId,
    required String profileId,
  }) async {
    final operation = 'Relay room member unban';
    final cleanedRoomId = roomId.trim();
    final cleanedProfileId = profileId.trim();
    final uri = _requireHttpBaseUrl(operation).resolve(
      '/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/members/${Uri.encodeComponent(cleanedProfileId)}/unban',
    );
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: const <String, Object?>{},
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomMemberUnbanMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            profileId: cleanedProfileId,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomMembershipMutationResult.fromJson(json);
  }

  Future<RelayRoomMembershipMutationResult> setRoomMemberTag({
    required String roomId,
    String? tag,
  }) async {
    final operation = 'Relay room member tag set';
    final cleanedRoomId = roomId.trim();
    final cleanedTag = (tag ?? '').trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/member-tag');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{'tag': cleanedTag.isEmpty ? null : cleanedTag},
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomMemberTagSetMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            tag: cleanedTag.isEmpty ? null : cleanedTag,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomMembershipMutationResult.fromJson(json);
  }

  Future<RelayRoomOwnershipTransferResult> transferRoomOwnership({
    required String roomId,
    required String nextOwnerProfileId,
  }) async {
    final operation = 'Relay room ownership transfer';
    final cleanedRoomId = roomId.trim();
    final cleanedNextOwnerProfileId = nextOwnerProfileId.trim();
    final uri = _requireHttpBaseUrl(operation).resolve(
      '/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/transfer-ownership',
    );
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'next_owner_profile_id': cleanedNextOwnerProfileId,
      },
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomTransferOwnershipMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            nextOwnerProfileId: cleanedNextOwnerProfileId,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomOwnershipTransferResult.fromJson(json);
  }

  Future<RelayRoomStateMutationResult> updateRoomProfile({
    required String roomId,
    required String title,
    String? description,
    String? avatarHash,
    String? avatarImageB64,
    bool clearAvatar = false,
  }) async {
    final operation = 'Relay room profile update';
    final cleanedRoomId = roomId.trim();
    final cleanedTitle = title.trim();
    final cleanedDescription = (description ?? '').trim();
    final cleanedAvatarHash = (avatarHash ?? '').trim();
    final cleanedAvatarImageB64 = (avatarImageB64 ?? '').trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/profile');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'title': cleanedTitle,
        'description': cleanedDescription.isEmpty ? null : cleanedDescription,
        'avatar_hash': cleanedAvatarHash.isEmpty ? null : cleanedAvatarHash,
        'avatar_image_b64': cleanedAvatarImageB64.isEmpty
            ? null
            : cleanedAvatarImageB64,
        'clear_avatar': clearAvatar,
      },
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomProfileUpdateMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            title: cleanedTitle,
            description: cleanedDescription,
            avatarHash: cleanedAvatarHash,
            avatarImageB64: cleanedAvatarImageB64,
            clearAvatar: clearAvatar,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomStateMutationResult.fromJson(json);
  }

  Future<RelayRoomStateMutationResult> updateRoomSettings({
    required String roomId,
    required String reactionsMode,
    required bool allowText,
    required bool allowMedia,
    required bool allowAddMembers,
    required bool allowPinMessages,
    required bool allowChangeGroupInfo,
    required bool allowChangeTag,
    required bool joinApprovalRequired,
    required int slowModeSeconds,
    required bool chatHistoryVisible,
  }) async {
    final operation = 'Relay room settings update';
    final cleanedRoomId = roomId.trim();
    final cleanedReactionsMode = reactionsMode.trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/settings');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'reactions_mode': cleanedReactionsMode,
        'allow_text': allowText,
        'allow_media': allowMedia,
        'allow_add_members': allowAddMembers,
        'allow_pin_messages': allowPinMessages,
        'allow_change_group_info': allowChangeGroupInfo,
        'allow_change_tag': allowChangeTag,
        'join_approval_required': joinApprovalRequired,
        'slow_mode_seconds': slowModeSeconds,
        'chat_history_visible': chatHistoryVisible,
      },
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomSettingsUpdateMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            reactionsMode: cleanedReactionsMode,
            allowText: allowText,
            allowMedia: allowMedia,
            allowAddMembers: allowAddMembers,
            allowPinMessages: allowPinMessages,
            allowChangeGroupInfo: allowChangeGroupInfo,
            allowChangeTag: allowChangeTag,
            joinApprovalRequired: joinApprovalRequired,
            slowModeSeconds: slowModeSeconds,
            chatHistoryVisible: chatHistoryVisible,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomStateMutationResult.fromJson(json);
  }

  /// К-2 (17.09.2026): один запечатанный провод комнаты — реле раздаёт его
  /// перечисленным устройствам. Возвращает, кого реле приняло; остальным
  /// вызывающий шлёт по-старому, попарно.
  Future<Set<String>> broadcastRoomWire({
    required String roomId,
    required String msgId,
    required String ciphertextB64,
    required List<String> recipients,
    required int ttlSeconds,
    int deliverAtMs = 0,
    String? transportMetaJson,
  }) async {
    final operation = 'Relay room broadcast';
    final cleanedRoomId = roomId.trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/broadcast');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'msg_id': msgId,
        'ciphertext_b64': ciphertextB64,
        'recipients': recipients,
        'ttl_seconds': ttlSeconds,
        if (transportMetaJson != null) 'transport_meta_json': transportMetaJson,
        if (deliverAtMs > 0) 'deliver_at_ms': deliverAtMs,
      },
      buildMessage: (tsMs, nonceB64) => AuthSigner.relayHttpRoomBroadcastMessage(
        fromDeviceId: deviceId,
        roomId: cleanedRoomId,
        msgId: msgId,
        ciphertextB64: ciphertextB64,
        recipients: recipients,
        ttlSeconds: ttlSeconds,
        deliverAtMs: deliverAtMs,
        transportMetaJson: transportMetaJson,
        tsMs: tsMs,
        nonceB64: nonceB64,
      ),
    );
    return ((json['accepted'] as List?) ?? const [])
        .whereType<String>()
        .toSet();
  }

  Future<RelayRoomMessageAdmissionResult> admitRoomMessage({
    required String roomId,
    required String messageId,
    required String kind,
  }) async {
    final operation = 'Relay room message admission';
    final cleanedRoomId = roomId.trim();
    final cleanedMessageId = messageId.trim();
    final cleanedKind = kind.trim().toLowerCase();
    final uri = _requireHttpBaseUrl(operation).resolve(
      '/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/message-admissions',
    );
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'message_id': cleanedMessageId,
        'kind': cleanedKind,
      },
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomMessageAdmissionMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            messageId: cleanedMessageId,
            kind: cleanedKind,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomMessageAdmissionResult.fromJson(json);
  }

  Future<RelayRoomStateMutationResult> setRoomPinnedMessage({
    required String roomId,
    String? messageId,
  }) async {
    final operation = 'Relay room pinned message set';
    final cleanedRoomId = roomId.trim();
    final cleanedMessageId = (messageId ?? '').trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/pinned-message');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'message_id': cleanedMessageId.isEmpty ? null : cleanedMessageId,
      },
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomPinnedMessageSetMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            messageId: cleanedMessageId.isEmpty ? null : cleanedMessageId,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomStateMutationResult.fromJson(json);
  }

  Future<RelayRoomMembershipMutationResult> leaveRoom({
    required String roomId,
  }) async {
    final operation = 'Relay room leave';
    final cleanedRoomId = roomId.trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/leave');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: const <String, Object?>{},
      buildMessage: (tsMs, nonceB64) => AuthSigner.relayHttpRoomLeaveMessage(
        deviceId: deviceId,
        roomId: cleanedRoomId,
        tsMs: tsMs,
        nonceB64: nonceB64,
      ),
    );
    return RelayRoomMembershipMutationResult.fromJson(json);
  }

  Future<RelayRoomDeleteResult> deleteRoom({required String roomId}) async {
    final operation = 'Relay room delete';
    final cleanedRoomId = roomId.trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/delete');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: const <String, Object?>{},
      buildMessage: (tsMs, nonceB64) => AuthSigner.relayHttpRoomDeleteMessage(
        deviceId: deviceId,
        roomId: cleanedRoomId,
        tsMs: tsMs,
        nonceB64: nonceB64,
      ),
    );
    return RelayRoomDeleteResult.fromJson(json);
  }

  Future<bool> deleteProfileData({
    required String profileId,
    required List<String> deviceIds,
  }) async {
    final operation = 'Relay profile delete';
    final cleanedProfileId = profileId.trim();
    final cleanedDeviceIds = deviceIds
        .map((deviceId) => deviceId.trim())
        .where((deviceId) => deviceId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    cleanedDeviceIds.sort();
    final uri = _requireHttpBaseUrl(operation).resolve('/v1/profile/delete');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'profile_id': cleanedProfileId,
        'device_ids': cleanedDeviceIds,
      },
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpProfileDeleteMessage(
            deviceId: deviceId,
            profileId: cleanedProfileId,
            deviceIds: cleanedDeviceIds,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return json['ok'] == true;
  }

  Future<RelayRoomCallSnapshot> getRoomCall({required String roomId}) async {
    final operation = 'Relay room call get';
    final cleanedRoomId = roomId.trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/call');
    final json = await _getSignedJson(
      operation: operation,
      uri: uri,
      buildMessage: (tsMs, nonceB64) => AuthSigner.relayHttpRoomCallGetMessage(
        deviceId: deviceId,
        roomId: cleanedRoomId,
        tsMs: tsMs,
        nonceB64: nonceB64,
      ),
    );
    return RelayRoomCallSnapshot.fromJson(json);
  }

  Future<RelayRoomCallMutationResult> joinRoomCall({
    required String roomId,
    String mediaType = 'audio',
    bool supportsVideo = false,
    bool supportsScreenShare = false,
    bool muted = false,
    bool deafened = false,
    bool videoEnabled = false,
    bool screenShareEnabled = false,
  }) async {
    final operation = 'Relay room call join';
    final cleanedRoomId = roomId.trim();
    final cleanedMediaType = mediaType.trim().toLowerCase() == 'video'
        ? 'video'
        : 'audio';
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/call');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'media_type': cleanedMediaType,
        'supports_video': supportsVideo,
        'supports_screen_share': supportsScreenShare,
        'muted': muted,
        'deafened': deafened,
        'video_enabled': videoEnabled,
        'screen_share_enabled': screenShareEnabled,
      },
      buildMessage: (tsMs, nonceB64) => AuthSigner.relayHttpRoomCallJoinMessage(
        deviceId: deviceId,
        roomId: cleanedRoomId,
        mediaType: cleanedMediaType,
        supportsVideo: supportsVideo,
        supportsScreenShare: supportsScreenShare,
        muted: muted,
        deafened: deafened,
        videoEnabled: videoEnabled,
        screenShareEnabled: screenShareEnabled,
        tsMs: tsMs,
        nonceB64: nonceB64,
      ),
    );
    return RelayRoomCallMutationResult.fromJson(json);
  }

  Future<RelayRoomCallMutationResult> updateOwnRoomCallParticipant({
    required String roomId,
    required String callId,
    bool reconnecting = false,
    bool muted = false,
    bool deafened = false,
    bool videoEnabled = false,
    bool screenShareEnabled = false,
    bool speaking = false,
  }) async {
    final operation = 'Relay room call self update';
    final cleanedRoomId = roomId.trim();
    final cleanedCallId = callId.trim();
    final uri = _requireHttpBaseUrl(operation).resolve(
      '/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/call/${Uri.encodeComponent(cleanedCallId)}/self',
    );
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'reconnecting': reconnecting,
        'muted': muted,
        'deafened': deafened,
        'video_enabled': videoEnabled,
        'screen_share_enabled': screenShareEnabled,
        'speaking': speaking,
      },
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomCallSelfUpdateMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            callId: cleanedCallId,
            reconnecting: reconnecting,
            muted: muted,
            deafened: deafened,
            videoEnabled: videoEnabled,
            screenShareEnabled: screenShareEnabled,
            speaking: speaking,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomCallMutationResult.fromJson(json);
  }

  Future<RelayRoomCallMutationResult> leaveRoomCall({
    required String roomId,
    required String callId,
  }) async {
    final operation = 'Relay room call leave';
    final cleanedRoomId = roomId.trim();
    final cleanedCallId = callId.trim();
    final uri = _requireHttpBaseUrl(operation).resolve(
      '/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/call/${Uri.encodeComponent(cleanedCallId)}/leave',
    );
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: const <String, Object?>{},
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomCallLeaveMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            callId: cleanedCallId,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomCallMutationResult.fromJson(json);
  }

  Future<RelayRoomCallMutationResult> removeRoomCallParticipant({
    required String roomId,
    required String callId,
    required String participantDeviceId,
  }) async {
    final operation = 'Relay room call participant remove';
    final cleanedRoomId = roomId.trim();
    final cleanedCallId = callId.trim();
    final cleanedParticipantDeviceId = participantDeviceId.trim();
    final uri = _requireHttpBaseUrl(operation).resolve(
      '/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/call/${Uri.encodeComponent(cleanedCallId)}/participants/${Uri.encodeComponent(cleanedParticipantDeviceId)}/remove',
    );
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: const <String, Object?>{},
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomCallParticipantRemoveMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            callId: cleanedCallId,
            participantDeviceId: cleanedParticipantDeviceId,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomCallMutationResult.fromJson(json);
  }

  Future<RelayRoomCallMutationResult> endRoomCall({
    required String roomId,
    required String callId,
  }) async {
    final operation = 'Relay room call end';
    final cleanedRoomId = roomId.trim();
    final cleanedCallId = callId.trim();
    final uri = _requireHttpBaseUrl(operation).resolve(
      '/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/call/${Uri.encodeComponent(cleanedCallId)}/end',
    );
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: const <String, Object?>{},
      buildMessage: (tsMs, nonceB64) => AuthSigner.relayHttpRoomCallEndMessage(
        deviceId: deviceId,
        roomId: cleanedRoomId,
        callId: cleanedCallId,
        tsMs: tsMs,
        nonceB64: nonceB64,
      ),
    );
    return RelayRoomCallMutationResult.fromJson(json);
  }

  Future<RelayRoomCallMediaSession> getRoomCallMedia({
    required String roomId,
    required String callId,
  }) async {
    final operation = 'Relay room call media get';
    final cleanedRoomId = roomId.trim();
    final cleanedCallId = callId.trim();
    final uri = _requireHttpBaseUrl(operation).resolve(
      '/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/call/${Uri.encodeComponent(cleanedCallId)}/media',
    );
    final json = await _getSignedJson(
      operation: operation,
      uri: uri,
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomCallMediaGetMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            callId: cleanedCallId,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomCallMediaSession.fromJson(json);
  }

  Future<RelayRoomCallMediaSession> joinRoomCallMedia({
    required String roomId,
    required String callId,
    bool publishAudio = true,
    bool publishVideo = false,
    bool publishScreenShare = false,
    bool subscribeAll = true,
  }) async {
    final operation = 'Relay room call media join';
    final cleanedRoomId = roomId.trim();
    final cleanedCallId = callId.trim();
    final uri = _requireHttpBaseUrl(operation).resolve(
      '/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/call/${Uri.encodeComponent(cleanedCallId)}/media/join',
    );
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'publish_audio': publishAudio,
        'publish_video': publishVideo,
        'publish_screen_share': publishScreenShare,
        'subscribe_all': subscribeAll,
      },
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomCallMediaJoinMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            callId: cleanedCallId,
            publishAudio: publishAudio,
            publishVideo: publishVideo,
            publishScreenShare: publishScreenShare,
            subscribeAll: subscribeAll,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    final mediaJson = json['media'];
    if (mediaJson is Map<String, dynamic>) {
      return RelayRoomCallMediaSession.fromJson(mediaJson);
    }
    if (mediaJson is Map) {
      return RelayRoomCallMediaSession.fromJson(
        mediaJson.cast<String, dynamic>(),
      );
    }
    throw const RelayHttpException(
      operation: 'Relay room call media join',
      message: 'missing media session in response',
    );
  }

  Future<RelayRoomInviteLinksSnapshot> listRoomInviteLinks({
    required String roomId,
  }) async {
    final operation = 'Relay room invite links list';
    final cleanedRoomId = roomId.trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/invite-links');
    final json = await _getSignedJson(
      operation: operation,
      uri: uri,
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomInviteLinksListMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomInviteLinksSnapshot.fromJson(json);
  }

  Future<RelayRoomInviteLinkMutationResult> createRoomInviteLink({
    required String roomId,
    int? expiresAtMs,
    int? maxUses,
    bool requiresApproval = false,
    String allowedRole = 'member',
  }) async {
    final operation = 'Relay room invite link create';
    final cleanedRoomId = roomId.trim();
    final cleanedAllowedRole = allowedRole.trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/invite-links');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{
        'expires_at_ms': expiresAtMs,
        'max_uses': maxUses,
        'requires_approval': requiresApproval,
        'allowed_role': cleanedAllowedRole,
      },
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomInviteLinksCreateMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            expiresAtMs: expiresAtMs,
            maxUses: maxUses,
            requiresApproval: requiresApproval,
            allowedRole: cleanedAllowedRole,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomInviteLinkMutationResult.fromJson(json);
  }

  Future<RelayRoomInviteLinkMutationResult> setRoomInviteLinkRevoked({
    required String roomId,
    required String linkId,
    required bool revoked,
  }) async {
    final operation = 'Relay room invite link revoke';
    final cleanedRoomId = roomId.trim();
    final cleanedLinkId = linkId.trim();
    final uri = _requireHttpBaseUrl(operation).resolve(
      '/v1/rooms/${Uri.encodeComponent(cleanedRoomId)}/invite-links/${Uri.encodeComponent(cleanedLinkId)}/revoke',
    );
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: <String, Object?>{'revoked': revoked},
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomInviteLinkRevokeMessage(
            deviceId: deviceId,
            roomId: cleanedRoomId,
            linkId: cleanedLinkId,
            revoked: revoked,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomInviteLinkMutationResult.fromJson(json);
  }

  Future<RelayRoomInvitePreview> previewRoomInvite({
    required String slug,
  }) async {
    final operation = 'Relay room invite preview';
    final cleanedSlug = slug.trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/room-invites/${Uri.encodeComponent(cleanedSlug)}');
    final json = await _getSignedJson(
      operation: operation,
      uri: uri,
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomInvitePreviewMessage(
            deviceId: deviceId,
            slug: cleanedSlug,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomInvitePreview.fromJson(json);
  }

  Future<RelayRoomInviteRedeemResult> redeemRoomInvite({
    required String slug,
  }) async {
    final operation = 'Relay room invite redeem';
    final cleanedSlug = slug.trim();
    final uri = _requireHttpBaseUrl(
      operation,
    ).resolve('/v1/room-invites/${Uri.encodeComponent(cleanedSlug)}/redeem');
    final json = await _postSignedJson(
      operation: operation,
      uri: uri,
      body: const <String, Object?>{},
      buildMessage: (tsMs, nonceB64) =>
          AuthSigner.relayHttpRoomInviteRedeemMessage(
            deviceId: deviceId,
            slug: cleanedSlug,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
    );
    return RelayRoomInviteRedeemResult.fromJson(json);
  }

  Future<List<String>> listBlockedProfiles() async {
    final base = httpBaseUrl;
    if (base == null) return const [];
    try {
      final uri = base.resolve('/v1/blocks/$deviceId');
      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = AuthSigner.relayHttpBlocksListMessage(
        deviceId: deviceId,
        tsMs: tsMs,
        nonceB64: nonceB64,
      );
      final sigB64 = await AuthSigner.signEd25519B64(
        identityKeyPair: await _loadIdentityKeyPair(),
        message: msg,
      );
      final resp = await _http
          .get(
            uri,
            headers: {
              'x-secretly-device-id': deviceId,
              'x-secretly-ts-ms': tsMs.toString(),
              'x-secretly-nonce-b64': nonceB64,
              'x-secretly-signature-b64': sigB64,
            },
          )
          .timeout(_httpTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw StateError('Relay blocks list failed: HTTP ${resp.statusCode}');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (json['blocked_profile_ids'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      return list;
    } catch (e) {
      throw StateError('Relay blocks list failed: $e');
    }
  }

  /// Sprint 2 R3: ask the relay for the active-device subset of
  /// `peerProfileId`.
  ///
  /// Returns `null` (NOT an empty snapshot) if the request fails, times
  /// out, or the response can't be parsed — the caller treats `null`
  /// the same as `filterApplied=false` and uses the unfiltered bundle.
  /// We intentionally never let a relay error narrow the fanout set.
  /// Сколько из названных конвертов реле ВСЁ ЕЩЁ держит для [toDeviceId].
  ///
  /// `null` — спросить не удалось (нет базы, сеть, старое реле, разбор).
  /// Вызывающий обязан трактовать `null` как «держит»: обратное превратило бы
  /// сбой связи в тихую отмену переотправки по-настоящему потерянной смс.
  Future<int?> pendingCheck({
    required String toDeviceId,
    required List<String> msgIds,
  }) async {
    final base = httpBaseUrl;
    if (base == null) return null;
    final peer = toDeviceId.trim();
    if (peer.isEmpty || msgIds.isEmpty) return null;
    try {
      final headers = await _signedRelayHeaders(
        buildMessage: (tsMs, nonceB64) =>
            AuthSigner.relayHttpPendingCheckMessage(
              deviceId: deviceId,
              toDeviceId: peer,
              msgIds: msgIds,
              tsMs: tsMs,
              nonceB64: nonceB64,
            ),
        extraHeaders: const {'content-type': 'application/json'},
      );
      final resp = await _http
          .post(
            base.resolve('/v1/pending_check'),
            headers: headers,
            body: jsonEncode(<String, Object?>{
              'device_id': deviceId,
              'to_device_id': peer,
              'msg_ids': msgIds,
            }),
          )
          .timeout(_httpTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return (json['still_pending'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .length;
    } catch (_) {
      return null;
    }
  }

  Future<RelayActiveDevicesSnapshot?> fetchActiveDevices({
    required String peerProfileId,
  }) async {
    final base = httpBaseUrl;
    if (base == null) return null;
    final cleanedPeer = peerProfileId.trim();
    if (cleanedPeer.isEmpty) return null;
    try {
      final uri = base.resolve('/v1/active_devices/$deviceId/$cleanedPeer');
      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = AuthSigner.relayHttpActiveDevicesMessage(
        deviceId: deviceId,
        profileId: cleanedPeer,
        tsMs: tsMs,
        nonceB64: nonceB64,
      );
      final sigB64 = await AuthSigner.signEd25519B64(
        identityKeyPair: await _loadIdentityKeyPair(),
        message: msg,
      );
      final resp = await _http
          .get(
            uri,
            headers: {
              'x-secretly-device-id': deviceId,
              'x-secretly-ts-ms': tsMs.toString(),
              'x-secretly-nonce-b64': nonceB64,
              'x-secretly-signature-b64': sigB64,
            },
          )
          .timeout(_httpTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        DiagLog.event('peer', 'active_devices_http_error', {
          'peer': DiagLog.pfx(cleanedPeer),
          'status': resp.statusCode,
        });
        return null;
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final deviceIds = (json['device_ids'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      // Новое поле реле (15.08.2026): отметки жизни по каждому устройству.
      // Старое реле его не присылает — список останется пустым, и вызывающий
      // поведёт себя ровно как раньше.
      final liveness = <RelayDeviceLiveness>[];
      for (final item in (json['devices'] as List<dynamic>? ?? const [])) {
        if (item is! Map) continue;
        final id = ((item['device_id'] as String?) ?? '').trim();
        if (id.isEmpty) continue;
        liveness.add(
          RelayDeviceLiveness(
            deviceId: id,
            lastSignalMs: (item['last_signal_ms'] as num?)?.toInt() ?? 0,
            superseded: item['superseded'] == true,
          ),
        );
      }
      return RelayActiveDevicesSnapshot(
        profileId: _jsonString(json['profile_id']),
        filterApplied: _jsonBool(json['filter_applied']),
        deviceIds: deviceIds,
        nowMs: _jsonNullableInt(json['now_ms']) ?? 0,
        thresholdMs: _jsonNullableInt(json['threshold_ms']) ?? 0,
        liveness: liveness,
      );
    } catch (e) {
      // Network / parse / signing failure: treat as "filter unavailable",
      // never as "fanout empty". Callers MUST handle `null` as a safe
      // fallback to the unfiltered bundle (Restore Safety Contract INV-7).
      DiagLog.event('peer', 'active_devices_fetch_fail', {
        'peer': DiagLog.pfx(cleanedPeer),
        'err_tag': e.runtimeType.toString(),
      });
      return null;
    }
  }

  Future<void> setProfileBlocked({
    required String blockedProfileId,
    required bool blocked,
  }) async {
    final base = httpBaseUrl;
    if (base == null) return;
    final cleaned = blockedProfileId.trim();
    if (cleaned.isEmpty) return;
    try {
      final uri = base.resolve('/v1/blocks/$deviceId');
      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = AuthSigner.relayHttpBlocksSetMessage(
        deviceId: deviceId,
        blockedProfileId: cleaned,
        blocked: blocked,
        tsMs: tsMs,
        nonceB64: nonceB64,
      );
      final sigB64 = await AuthSigner.signEd25519B64(
        identityKeyPair: await _loadIdentityKeyPair(),
        message: msg,
      );
      final resp = await _http
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              'x-secretly-device-id': deviceId,
              'x-secretly-ts-ms': tsMs.toString(),
              'x-secretly-nonce-b64': nonceB64,
              'x-secretly-signature-b64': sigB64,
            },
            body: jsonEncode({
              'blocked_profile_id': cleaned,
              'blocked': blocked,
            }),
          )
          .timeout(_httpTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw StateError('Relay blocks set failed: HTTP ${resp.statusCode}');
      }
    } catch (e) {
      throw StateError('Relay blocks set failed: $e');
    }
  }

  Future<void> setPushToken({
    required String token,
    String platform = 'android',
    bool enabled = true,
    String? policyB64,
  }) async {
    final base = httpBaseUrl;
    if (base == null) return;

    final normalizedToken = token.trim();
    final normalizedPlatform = platform.trim().toLowerCase();
    final normalizedPolicyB64 = (policyB64 ?? '').trim();
    if (enabled && normalizedToken.isEmpty) return;

    try {
      final uri = base.resolve('/v1/push/$deviceId');
      // AUD-013 fix: the current relay always reconstructs the
      // `policy_b64=` line in its auth message, so the previously-used
      // "legacy retry without policy line" path could never succeed. It has
      // been removed: the client and server now have symmetric auth-message
      // construction, which is verified by the unit tests.
      final resp = await _postPushTokenSet(
        uri: uri,
        token: normalizedToken,
        platform: normalizedPlatform,
        enabled: enabled,
        policyB64: normalizedPolicyB64,
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return;
      }
      throw StateError(
        'Relay push token set failed: HTTP ${resp.statusCode}'
        '${relayAuthFailureHint(resp.statusCode, resp.body)}',
      );
    } catch (e) {
      throw StateError('Relay push token set failed: $e');
    }
  }

  Future<http.Response> _postPushTokenSet({
    required Uri uri,
    required String token,
    required String platform,
    required bool enabled,
    String? policyB64,
  }) async {
    final normalizedPolicyB64 = (policyB64 ?? '').trim();
    final tsMs = ServerClock.instance.nowMs();
    final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
    // AUD-013: auth message always includes the policy line (possibly empty)
    // so client and server stay symmetric with `http_push_token_set_auth_message`.
    final msg = AuthSigner.relayHttpPushTokenSetMessage(
      deviceId: deviceId,
      token: token,
      platform: platform,
      enabled: enabled,
      policyB64: normalizedPolicyB64,
      tsMs: tsMs,
      nonceB64: nonceB64,
    );
    final sigB64 = await AuthSigner.signEd25519B64(
      identityKeyPair: await _loadIdentityKeyPair(),
      message: msg,
    );

    return _http
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            'x-secretly-device-id': deviceId,
            'x-secretly-ts-ms': tsMs.toString(),
            'x-secretly-nonce-b64': nonceB64,
            'x-secretly-signature-b64': sigB64,
          },
          body: jsonEncode({
            'token': token,
            'platform': platform,
            'enabled': enabled,
            if (normalizedPolicyB64.isNotEmpty)
              'policy_b64': normalizedPolicyB64,
          }),
        )
        .timeout(_httpTimeout);
  }

  Future<RelayCallSessionSnapshot> getCallSession({
    required String callId,
    required String callAttemptId,
  }) async {
    final base = httpBaseUrl;
    if (base == null) {
      throw StateError(
        'Relay call session unavailable: HTTP base URL not configured',
      );
    }
    final normalizedCallId = callId.trim();
    final normalizedAttemptId = callAttemptId.trim();
    if (normalizedCallId.isEmpty || normalizedAttemptId.isEmpty) {
      throw StateError(
        'Relay call session requires non-empty call identifiers',
      );
    }
    try {
      final uri = base.resolve(
        '/v1/call-session/${Uri.encodeComponent(deviceId)}/${Uri.encodeComponent(normalizedCallId)}/${Uri.encodeComponent(normalizedAttemptId)}',
      );
      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = AuthSigner.relayHttpCallSessionMessage(
        deviceId: deviceId,
        callId: normalizedCallId,
        callAttemptId: normalizedAttemptId,
        tsMs: tsMs,
        nonceB64: nonceB64,
      );
      final sigB64 = await AuthSigner.signEd25519B64(
        identityKeyPair: await _loadIdentityKeyPair(),
        message: msg,
      );
      final resp = await _http
          .get(
            uri,
            headers: {
              'x-secretly-device-id': deviceId,
              'x-secretly-ts-ms': tsMs.toString(),
              'x-secretly-nonce-b64': nonceB64,
              'x-secretly-signature-b64': sigB64,
            },
          )
          .timeout(_httpTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw StateError('Relay call session failed: HTTP ${resp.statusCode}');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return RelayCallSessionSnapshot.fromJson(json);
    } catch (e) {
      throw StateError('Relay call session failed: $e');
    }
  }

  Future<CallIceConfigSnapshot> getIceConfig() async {
    final base = httpBaseUrl;
    if (base == null) {
      throw StateError(
        'Relay ice config unavailable: HTTP base URL not configured',
      );
    }
    try {
      final uri = base.resolve('/v1/ice/${Uri.encodeComponent(deviceId)}');
      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = AuthSigner.relayHttpIceConfigMessage(
        deviceId: deviceId,
        tsMs: tsMs,
        nonceB64: nonceB64,
      );
      final sigB64 = await AuthSigner.signEd25519B64(
        identityKeyPair: await _loadIdentityKeyPair(),
        message: msg,
      );
      final resp = await _http
          .get(
            uri,
            headers: {
              'x-secretly-device-id': deviceId,
              'x-secretly-ts-ms': tsMs.toString(),
              'x-secretly-nonce-b64': nonceB64,
              'x-secretly-signature-b64': sigB64,
            },
          )
          .timeout(_httpTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw StateError('Relay ice config failed: HTTP ${resp.statusCode}');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return CallIceConfigSnapshot.fromJson(json);
    } catch (e) {
      throw StateError('Relay ice config failed: $e');
    }
  }

  void _setConnected(bool v) {
    if (_connected == v) return;
    _connected = v;
    onConnectionChanged?.call(v);
  }

  Future<void> connect() async {
    if (_connecting) return;
    _connecting = true;
    await disconnect();
    _wsReady = false;

    _nextSeq = await loadNextSeq();
    if (_nextSeq < 1) _nextSeq = 1;

    WebSocketChannel? ch;
    try {
      ch = _webSocketConnector(
        wsUrl,
        pingInterval: _wsPingTimerPeriod,
        connectTimeout: _wsReadyTimeout,
      );
      _channel = ch;
      // Ensure connection errors are surfaced here (and therefore catchable)
      // instead of becoming unhandled async errors.
      await ch.ready.timeout(
        _wsReadyTimeout,
        onTimeout: () {
          throw TimeoutException(
            'relay websocket ready timeout after ${_wsReadyTimeout.inSeconds}s',
          );
        },
      );

      // Authenticated hello (variant B): sign a server-verified challenge.
      final kp = await _loadIdentityKeyPair();
      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = AuthSigner.relayHelloMessage(
        deviceId: deviceId,
        tsMs: tsMs,
        nonceB64: nonceB64,
      );
      final sigB64 = await AuthSigner.signEd25519B64(
        identityKeyPair: kp,
        message: msg,
      );

      ch.sink.add(
        ClientMsg.helloAuth(
          deviceId: deviceId,
          tsMs: tsMs,
          nonceB64: nonceB64,
          signatureB64: sigB64,
          // Единственный путь, которым сборка сокет-жителя доезжает до замера.
          clientBuild: clientBuild,
        ),
      );
    } catch (e) {
      final failedChannel = ch;
      if (identical(_channel, failedChannel)) {
        _channel = null;
      }
      if (failedChannel != null) {
        await _closeChannelBestEffort(failedChannel);
      }
      _wsReady = false;
      _setConnected(false);
      _connecting = false;
      _scheduleReconnect();
      rethrow;
    }

    final connectedChannel = ch;
    _sub = connectedChannel.stream.listen(
      (data) async {
        if (data is! String) return;
        _lastWsActivityAtMs = DateTime.now().millisecondsSinceEpoch;
        final msg = ServerMsg.parse(data);
        switch (msg) {
          case Welcome(:final nextSeq):
            // after reconnect: fetch what we might have missed
            if (_nextSeq > nextSeq) {
              // DIAG (offline-drain): Welcome lowering the cursor back to the
              // relay's MIN(pending). If this re-pins a stranded low seq every
              // reconnect, it confirms the lost-ack pull-back variant.
              DiagLog.event('relay', 'welcome_lower', {
                'from': _nextSeq,
                'to': nextSeq,
              });
              _nextSeq = nextSeq;
            }
            _wsReady = true;
            // 🔴 ЗАМЕР ЖИЗНИ СОЕДИНЕНИЯ (14.08.2026). Аудит показал 33
            // переключения online/offline за сеанс и 297 HTTP-выборок на 41
            // полезный результат — 7,2 запроса впустую на один. Причину
            // сказать было НЕЧЕМ: событие relay.conn писало только «онлайн» и
            // «офлайн», без кода закрытия и без времени жизни.
            _wsOpenedAtMs = DateTime.now().millisecondsSinceEpoch;
            _wsConnectCount++; // только счётчик для сводки, см. поля выше
            DiagLog.event('relay', 'ws_open', const {});
            _setConnected(true);
            connectedChannel.sink.add(
              ClientMsg.fetchPending(deviceId: deviceId, fromSeq: _nextSeq),
            );
            _reconnectAttempt = 0;
            _startPingTimer();
            // Durable ACK queue: retry any ACKs that were parked because the
            // relay was unreachable, so its cursor converges and stranded
            // messages stop being re-offered.
            unawaited(_drainPendingAcks());
            // Re-drain any outbox entries that were queued while disconnected
            // (including stale-leased ones from a prior session).
            unawaited(() async {
              try {
                await _outgoingScheduler.recoverStaleLeases();
              } catch (_) {}
              unawaited(pumpOutbox());
            }());
          case SentOk(
            :final msgId,
            :final delivery,
            :final deviceSetStale,
            :final deviceIds,
          ):
            await db.outboxMarkSent(msgId);
            if (delivery == 'dropped_offline') {
              unawaited(_noteOnlineOnlyDropped(msgId));
            }
            if (deviceSetStale && deviceIds != null) {
              onDeviceSetStale?.call(msgId, deviceIds);
            }
            // 🔴 ВОТ ЗДЕСЬ переотправка становится потраченной попыткой: реле
            // подтвердило приём. Кадр, не доехавший из-за лимита или мёртвого
            // соединения, бюджета больше не стоит (замер 15.08: пять попыток
            // сгорели в яме 429, не отправив ничего).
            final spent = await db.resendBudgetConsumeForAcceptedMsg(
              msgId: msgId,
              nowMs: DateTime.now().millisecondsSinceEpoch,
            );
            DiagLog.event('outbox', 'sent', {
              'transport': 'ws',
              'msg': DiagLog.pfx(msgId),
              if (spent) 'resend_budget': 'spent',
            });
            unawaited(pumpOutbox());
          case Deliver(:final seq, :final msgId, :final fromDeviceId):
            // ИД-1 / С-1: the relay's word on who sent it, for _handleDelivered.
            AttestedSenders.record(msgId, fromDeviceId);
            if (seq < _nextSeq) {
              // SEQ-CURSOR FIX (2026-06-07): a delivery below our cursor is
              // usually a duplicate the relay is retrying — but it can also
              // be a message that was STRANDED when the cursor advanced past
              // a lost ACK (Android background kill / WS drop between apply
              // and ack). Re-process it iff we have not actually applied it
              // yet. Dedup is guaranteed two ways: `inbox_seen` (msg_id) and
              // the `events` table INSERT-OR-IGNORE on event_id, so a
              // re-offer can never create a duplicate in the UI. Always
              // re-ACK afterwards so the relay drops it from the mailbox.
              final alreadySeen = await db.inboxHasSeen(msgId);
              var safeToAck = alreadySeen;
              if (!alreadySeen) {
                var applied = false;
                try {
                  // R9 (2026-07-16): this below-cursor re-apply had NO timeout,
                  // so one wedged apply could stall the WS deliver handler
                  // indefinitely. Bound it like the main drain.
                  applied = await onDelivered(
                    msgId: msgId,
                    ciphertextB64: msg.ciphertextB64,
                  ).timeout(_deliveryApplyTimeout);
                } catch (_) {
                  applied = false;
                }
                if (applied) {
                  await db.inboxMarkSeen(msgId);
                  DiagLog.event('inbox', 'backfilled_below_cursor', {
                    'msg': DiagLog.pfx(msgId),
                  });
                  safeToAck = true;
                } else {
                  // LOSS-SAFETY HARDENING (2026-06-29): see the HTTP backfill
                  // path. Do NOT ack-and-drop a below-cursor re-offer we could
                  // not apply (ratchet not ready on a cold wake) — park it in
                  // quarantine first so the replay sweep re-applies it once deps
                  // are ready; only ack once durably parked, else leave it in
                  // the mailbox for the next pump.
                  try {
                    await db.inboxQuarantineUpsert(
                      attestedFromDeviceId: AttestedSenders.lookup(msgId),
                      msgId: msgId,
                      // F-ROOMSK-5: the author is in the wire header, so the
                      // fast per-sender replay can find this row later.
                      senderDeviceId: _senderDeviceIdFromWireHeader(
                        msg.ciphertextB64,
                      ),
                      ciphertextB64: msg.ciphertextB64,
                      nowMs: DateTime.now().millisecondsSinceEpoch,
                    );
                    safeToAck = true;
                    DiagLog.event('inbox', 'below_cursor_quarantined', {
                      'seq': seq,
                      'msg': DiagLog.pfx(msgId),
                    });
                  } catch (_) {
                    DiagLog.event('inbox', 'below_cursor_kept', {
                      'seq': seq,
                      'msg': DiagLog.pfx(msgId),
                    });
                  }
                }
              }
              if (safeToAck) {
                await _sendAck(seq: seq, msgId: msgId);
              }
              break;
            }
            _reorderBuffer[seq] = msg;
            await _drainReorderBuffer();
          case ErrorMsg(:final code, :final message):
            onServerError?.call(code, message);
            if (code == 'bad_handshake' ||
                code == 'auth_required' ||
                code == 'auth_failed' ||
                // AUD-041: server told us this device_id was just taken over
                // by another client. Close the socket, but also add a short
                // reconnect cooldown so the two clients don't hot-loop kicking
                // each other off if both are legitimately signed in under the
                // same device_id (usually a symptom of key-material duplication
                // after a non-atomic restore flow — surfaces in UI via
                // `onServerError`).
                code == 'session_replaced') {
              _wsReady = false;
              _setConnected(false);
              if (code == 'session_replaced') {
                _backoffSeedMs = 5000;
              }
              unawaited(connectedChannel.sink.close());
            }
          case SendErrorMsg(:final msgId, :final code, :final message):
            await _handleWsSendError(
              msgId: msgId,
              code: code,
              message: message,
            );
          case Pong():
            _waitingForPong = false;
            // A pong proves the socket is actually alive — refresh the activity
            // stamp so a healthy-but-quiet WS is never mistaken for half-open
            // (which would otherwise gate the HTTP pump for up to 30s).
            _lastWsActivityAtMs = DateTime.now().millisecondsSinceEpoch;
          case Unknown():
          // ignore
        }
      },
      onDone: () {
        // Закрытие «по-хорошему»: удалённая сторона или сеть закрыли поток.
        // Код и причину отдаёт сам канал — до этого мы их выбрасывали.
        _logWsClosed(
          reason: 'done',
          closeCode: _channel?.closeCode,
          closeReason: _channel?.closeReason,
        );
        _channel = null;
        _wsReady = false;
        _setConnected(false);
        _scheduleReconnect();
      },
      onError: (Object error, StackTrace _) {
        _logWsClosed(
          reason: 'error',
          closeCode: _channel?.closeCode,
          closeReason: error.runtimeType.toString(),
        );
        _channel = null;
        _wsReady = false;
        _setConnected(false);
        _scheduleReconnect();
      },
    );

    _connecting = false;
  }

  /// Handshake seqs already used to rescue a stuck head, so one wire can never
  /// be applied twice by this path (and the retry loop cannot spin on it).
  final Set<int> _handshakeRescuedSeqs = <int>{};

  /// Apply a buffered HANDSHAKE wire from the same sender as [blocked], out of
  /// seq order, so a dead session can be healed by mail that is sitting BEHIND
  /// the mail it would fix. Returns true when one was applied.
  ///
  /// Called ONLY after [blocked] has already failed to apply — see the call
  /// site for why this must be a rescue and not a policy.
  ///
  /// The wire is deliberately NOT acked here: it stays in the mailbox, and the
  /// ordinary in-order pass acks it when the cursor reaches it (the `inbox_seen`
  /// branch falls through to ack + cursor advance). That keeps every existing
  /// loss-safety guarantee untouched — this path can only ADD an apply, never
  /// remove a wire from the relay.
  Future<bool> _rescueWithBufferedHandshake(Deliver blocked) async {
    final blockedSender = _senderDeviceIdFromWireHeader(blocked.ciphertextB64);
    if (blockedSender == null) return false;
    for (final entry in _reorderBuffer.entries.toList(growable: false)) {
      final seq = entry.key;
      final candidate = entry.value;
      if (seq == blocked.seq) continue;
      if (_handshakeRescuedSeqs.contains(seq)) continue;
      if (!_isHandshakeWire(candidate.ciphertextB64)) continue;
      // Same peer only: another sender's handshake cannot heal THIS session,
      // and applying it early would reorder an unrelated conversation.
      if (_senderDeviceIdFromWireHeader(candidate.ciphertextB64) !=
          blockedSender) {
        continue;
      }
      if (await db.inboxHasSeen(candidate.msgId)) {
        _handshakeRescuedSeqs.add(seq);
        continue;
      }
      var applied = false;
      try {
        applied = await onDelivered(
          msgId: candidate.msgId,
          ciphertextB64: candidate.ciphertextB64,
        ).timeout(_deliveryApplyTimeout);
      } catch (_) {
        applied = false;
      }
      // Marked either way: a handshake that cannot be applied now will not
      // become applicable by being retried inside this same stuck drain, and
      // remembering it is what stops the retry loop from spinning on it. The
      // ordinary in-order pass still gets its full retry budget for this seq.
      _handshakeRescuedSeqs.add(seq);
      if (applied) {
        await db.inboxMarkSeen(candidate.msgId);
        DiagLog.event('inbox', 'handshake_rescued', {
          'blocked_seq': blocked.seq,
          'healed_seq': seq,
          'sender_dev': DiagLog.pfx(blockedSender),
        });
        return true;
      }
    }
    return false;
  }

  /// Называет, ЧТО закрыло соединение и сколько оно прожило.
  ///
  /// 🔴 «Рвётся сразу» и «рвётся через минуту» — разные болезни, и лечатся
  /// по-разному. Без времени жизни и кода закрытия любая правка была бы
  /// догадкой, а их за 13-14.08 сделано достаточно.
  void _logWsClosed({
    required String reason,
    int? closeCode,
    String? closeReason,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    DiagLog.event('relay', 'ws_closed', {
      'why': reason,
      'code': closeCode ?? -1,
      'detail': (closeReason ?? '').trim().isEmpty
          ? '—'
          : closeReason!.trim().replaceAll(RegExp(r'\s+'), '_'),
      'lived_ms': _wsOpenedAtMs == 0 ? -1 : nowMs - _wsOpenedAtMs,
      'since_activity_ms': _lastWsActivityAtMs == 0
          ? -1
          : nowMs - _lastWsActivityAtMs,
    });
    // Накопление для сводки на экране диагностики — только наблюдение.
    _wsCloseCount++;
    _wsLastCloseAtMs = nowMs;
    _wsLastCloseWhy = reason;
    _wsLastCloseCode = closeCode ?? -1;
    _wsLastLivedMs = _wsOpenedAtMs == 0 ? -1 : nowMs - _wsOpenedAtMs;
    if (_wsLastLivedMs > 0) _wsTotalUptimeMs += _wsLastLivedMs;
    final whyKey = closeCode == null || closeCode <= 0
        ? reason
        : '$reason/$closeCode';
    _wsCloseWhyCounts[whyKey] = (_wsCloseWhyCounts[whyKey] ?? 0) + 1;
    _wsOpenedAtMs = 0;
  }

  Future<void> _drainReorderBuffer() async {
    final drainStartMs = DateTime.now().millisecondsSinceEpoch;
    if (_isDraining) {
      // LIVENESS WATCHDOG (2026-06-25): a healthy drain finishes in
      // milliseconds. If the single-flight lock has been held far longer, the
      // in-flight drain is wedged on a hung await (stuck DB / keystore / native
      // ratchet future). Force-release the lock so forward progress resumes,
      // and neuter the stranded run's finally via a generation bump. Fail
      // closed: the hung seq was never acked or cursor-advanced — nothing lost.
      if (drainStartMs - _drainStartedAtMs > _drainWatchdogMs) {
        DiagLog.event('inbox', 'drain_lock_force_cleared', {
          'next_seq': _nextSeq,
          'stuck_ms': drainStartMs - _drainStartedAtMs,
        });
        _drainGeneration++;
        _isDraining = false;
      } else {
        DiagLog.event('inbox', 'drain_reentry_blocked', {
          'next_seq': _nextSeq,
          'buf': _reorderBuffer.length,
        });
        return;
      }
    }
    _isDraining = true;
    _drainStartedAtMs = drainStartMs;
    final myGen = ++_drainGeneration;
    DiagLog.event('inbox', 'drain_enter', {
      'next_seq': _nextSeq,
      'buf': _reorderBuffer.length,
    });
    try {
      while (true) {
        final next = _reorderBuffer.remove(_nextSeq);
        if (next == null) {
          // OFFLINE-DRAIN DEADLOCK FIX (2026-06-25): drop stale entries the
          // cursor already advanced past. A lingering below-cursor seq pins
          // minBufferedSeq below _nextSeq, so the gap-skip self-heal below
          // (minBufferedSeq > _nextSeq) never fires and the drain wedges
          // forever (proven live: drain_gap next_seq=16 min_buf=15 while count
          // climbs, zero inbox.delivered, zero acks, no welcome_lower, no
          // drain_reentry). Safe: the cursor only passes a seq after
          // applying/skipping it; any genuine re-offer is re-applied
          // idempotently by the below-cursor backfill (inbox_seen / events
          // INSERT-OR-IGNORE).
          _reorderBuffer.removeWhere((k, _) => k < _nextSeq);
          // Same horizon for the rescue ledger: a seq the cursor has passed can
          // never come back through this path, so remembering it is pure growth.
          _handshakeRescuedSeqs.removeWhere((s) => s < _nextSeq);
          if (_reorderBuffer.isNotEmpty) {
            final minBufferedSeq = _reorderBuffer.keys.reduce(min);
            // DIAG (offline-drain): the cursor slot is empty but the buffer
            // holds higher seqs. min_buf==next_seq would mean the floor IS
            // present (so this branch would not be entered); reaching here with
            // min_buf>next_seq is the gap-deadlock case.
            DiagLog.event('inbox', 'drain_gap', {
              'next_seq': _nextSeq,
              'min_buf': minBufferedSeq,
              'last_gap': _lastGapSeqRequested ?? -1,
            });
            if (minBufferedSeq > _nextSeq) {
              // The reorder buffer holds messages whose seq is ABOVE the cursor,
              // but `_nextSeq` itself is missing. First we gap-fetch the hole
              // over the realtime WS and wait.
              if (_lastGapSeqRequested == _nextSeq) {
                // DEEP-SLEEP LOSS FIX (2026-07-14): the WS gap-fetch already ran
                // for this exact seq and it is STILL missing. The OLD code
                // concluded "the seq no longer exists" and SKIPPED it
                // (`_nextSeq = minBufferedSeq`). That was the deep-sleep message
                // loss: a WS `fetchPending` is fire-and-forget — on a flaky
                // post-wake socket it is silently lost, so "not supplied" does
                // NOT prove the seq is gone. It is very likely still on the
                // relay (unacked), and skipping drained the burst past a hole
                // that still existed → the recipient saw the push but the
                // message never appeared (proven live: inbox.gap_skipped
                // from=343 to=345 while those seqs were still pending on the
                // relay). We NEVER advance the cursor on unconfirmed WS state.
                // Instead escalate to a RELIABLE HTTP pump: its response is the
                // relay's COMPLETE MIN-clamped view from `_nextSeq`, so it will
                // either supply the missing seqs (delivered in order) or advance
                // the cursor via the SOUND http-path skip (relay provably no
                // longer holds them — see pumpInbox). On a network failure the
                // pump throws and nothing advances: we WAIT and retry on the
                // next cadence rather than lose, because the messages are still
                // on the relay. Debounced per-hole so a network-out window can't
                // hot-loop the pump.
                final nowMs = DateTime.now().millisecondsSinceEpoch;
                final debounced = _lastGapHttpEscalationSeq == _nextSeq &&
                    (nowMs - _lastGapHttpEscalationAtMs) <
                        _gapHttpEscalationMinIntervalMs;
                if (!debounced) {
                  _lastGapHttpEscalationSeq = _nextSeq;
                  _lastGapHttpEscalationAtMs = nowMs;
                  _lastGapSeqRequested = null;
                  DiagLog.event('inbox', 'gap_escalate_http', {
                    'from': _nextSeq,
                    'min_buf': minBufferedSeq,
                  });
                  // Release the drain lock first (return below), then pump: its
                  // own _drainReorderBuffer re-drains with the lock free.
                  unawaited(pumpInbox(force: true));
                }
                return;
              }
              _scheduleGapFetch(
                expectedSeq: _nextSeq,
                minBufferedSeq: minBufferedSeq,
              );
            }
          }
          return;
        }

        final seq = next.seq;
        final msgId = next.msgId;
        final ciphertextB64 = next.ciphertextB64;

        final seen = await db.inboxHasSeen(msgId);
        if (seen) {
          // DIAG (offline-drain): the floor message is already applied, so
          // onDelivered (and its inbox.delivered log) is skipped. If this seq
          // keeps recurring, its ACK is not reaching the relay.
          DiagLog.event('inbox', 'seen_skip', {
            'seq': seq,
            'msg': DiagLog.pfx(msgId),
          });
        }
        if (!seen) {
          bool applied = false;
          var ackSent = false;
          try {
            applied = await onDelivered(
              msgId: msgId,
              ciphertextB64: ciphertextB64,
            ).timeout(_deliveryApplyTimeout);
          } catch (_) {
            // Includes TimeoutException: a hung apply is treated as not-applied
            // so the seq is re-buffered + retried (fail closed; never acked,
            // never cursor-advanced) and the drain lock is always released.
            applied = false;
          }
          if (!applied) {
            final failures = (_deliveryApplyFailuresBySeq[seq] ?? 0) + 1;
            _deliveryApplyFailuresBySeq[seq] = failures;
            if (failures < _maxDeliveryApplyFailuresPerSeq) {
              // Fail closed: never ACK or advance a delivery we could not apply.
              _reorderBuffer[seq] = next;
              // 🔴 THE ANTIDOTE IS BEHIND THE POISON (2026-08-01, ПК-3).
              //
              // Field, proven on prod: a receiver held 111 undecryptable wires
              // from one sender AND — further down the same mailbox — FOUR
              // session-heal handshakes that would have fixed it. The drain is
              // strictly seq-ordered, so the cure could only be reached by
              // first exhausting the poison; that costs six consecutive
              // failures per wire and the counter lives in memory, so any
              // reconnect resets it. The mailbox therefore never converged —
              // it grew (109 -> 115 rows in 40 minutes of observation).
              //
              // So: only once the head has actually FAILED, look ahead for a
              // handshake from the SAME sender and apply that first. Deliberately
              // a RESCUE, never a policy — applying a handshake early REPLACES
              // the session, which would strand still-pending wires encrypted
              // under the old one. Here nothing is stranded: the head already
              // cannot be opened, and the archive keeps the old session for
              // genuine stragglers.
              final rescued = await _rescueWithBufferedHandshake(next);
              if (rescued) {
                // The session may be healed now — retry the head at once
                // instead of waiting out the retry timer.
                continue;
              }
              _scheduleDeliveryRetry();
              return;
            }
            // Exhausted retries — skip this message so later messages can flow.
            // ACK it so the relay stops re-delivering; the gap is irrecoverable.
            // LOSS-SAFETY HARDENING (2026-06-25): before acking+skipping,
            // defensively park the ciphertext in quarantine. _handleDelivered
            // normally quarantines a genuine-MAC failure itself, but if it
            // returned false for a transient/not-ready dependency (e.g. crypto
            // not yet initialised at cold start) the message would otherwise be
            // acked + dropped + lost. Quarantine is INSERT-OR-IGNORE and the
            // periodic quarantine-replay sweep re-applies it idempotently once
            // deps are ready, so this can only REDUCE loss, never duplicate.
            try {
              await db.inboxQuarantineUpsert(
                      attestedFromDeviceId: AttestedSenders.lookup(msgId),
                msgId: msgId,
                // F-ROOMSK-5: the author is in the wire header, so the fast
                // per-sender replay can find this row later.
                senderDeviceId: _senderDeviceIdFromWireHeader(ciphertextB64),
                ciphertextB64: ciphertextB64,
                nowMs: DateTime.now().millisecondsSinceEpoch,
              );
            } catch (_) {
              // best-effort; fall back to the previous ack+skip behaviour
            }
            _deliveryApplyFailuresBySeq.remove(seq);
            await _sendAck(seq: seq, msgId: msgId);
            ackSent = true;
          }
          await db.inboxMarkSeen(msgId);
          _deliveryApplyFailuresBySeq.remove(seq);

          if (ackSent) {
            _nextSeq = seq + 1;
            await _saveNextSeqThrottled(_nextSeq);
            _lastGapSeqRequested = null;
            continue;
          }
        }

        // SEQ-CURSOR FIX (2026-06-07, defense-in-depth): send the ACK BEFORE
        // persisting the advanced cursor. Previously the cursor was saved
        // first and the ACK fired afterwards — if the ACK was lost (WS drop
        // / process kill right after save), the message stayed in the relay
        // mailbox with a seq BELOW the persisted cursor and was never
        // re-offered. Acking first means a lost ack is far less likely to
        // outlive the saved cursor. The server-side re-offer (clamped
        // from_seq in list_pending_from) remains the primary safety net; this
        // ordering just reduces orphan accumulation.
        await _sendAck(seq: seq, msgId: msgId);
        _nextSeq = seq + 1;
        await _saveNextSeqThrottled(_nextSeq);
        _lastGapSeqRequested = null;
      }
    } finally {
      // Отложенный курсор дописывается ПЕРВЫМ делом: дальше идут уведомления
      // экрану и диагностика, а до них слив может не дойти при исключении.
      await _flushPendingCursorSave();
      // Only release the lock if a watchdog hasn't already handed it to a newer
      // drain (generation guard) — prevents a resumed stranded drain from
      // clearing a healthy successor's lock.
      if (_drainGeneration == myGen) {
        _isDraining = false;
      }
      // 🔴 Первый разбор ящика с момента запуска. Нужен экрану чата: пока он
      // не прошёл, «пустой чат» означает «ещё не знаем», а не «переписки нет»,
      // и предлагать помахать рукой там нечестно (отчёт 03.08.2026: открыл
      // чат из уведомления — пусто, через 15 секунд всё появилось).
      //
      // О переходе сообщаем ОДИН раз тем же каналом, что и смена связи: если
      // ящик оказался пуст, доставок не будет, а значит и перерисовки экрана
      // тоже — и кружок «загружаем» завис бы до следующего чужого события.
      if (!_firstDrainCompleted) {
        _firstDrainCompleted = true;
        onFirstDrainCompleted?.call();
      }
      DiagLog.event('inbox', 'drain_exit', {
        'next_seq': _nextSeq,
        'elapsed_ms': DateTime.now().millisecondsSinceEpoch - drainStartMs,
      });
    }
  }

  @visibleForTesting
  Future<void> debugHandleDeliverForTest(Deliver msg) async {
    _reorderBuffer[msg.seq] = msg;
    await _drainReorderBuffer();
  }

  /// Seeds a raw reorder-buffer entry WITHOUT draining — used by regression
  /// tests to recreate a poisoned-buffer state (e.g. a stale below-cursor seq
  /// that a gap-fetch race can strand) and assert the drain self-heals.
  @visibleForTesting
  void debugSeedReorderEntryForTest({
    required int seq,
    required String msgId,
    required String ciphertextB64,
  }) {
    _reorderBuffer[seq] = Deliver(
      deviceId: deviceId,
      seq: seq,
      msgId: msgId,
      ciphertextB64: ciphertextB64,
    );
  }

  @visibleForTesting
  int get debugNextSeqForTest => _nextSeq;

  @visibleForTesting
  int get debugReorderBufferLengthForTest => _reorderBuffer.length;

  /// Simulates the state AFTER a realtime WS gap-fetch has already run for a
  /// hole and the relay did not supply it (a lost fire-and-forget fetchPending).
  /// The next drain must NOT skip — it must escalate to a reliable HTTP pump.
  @visibleForTesting
  set debugLastGapSeqRequestedForTest(int seq) => _lastGapSeqRequested = seq;

  /// Drives the reorder-buffer drain directly (the WS-delivery apply path).
  @visibleForTesting
  Future<void> debugDrainForTest() => _drainReorderBuffer();

  void _scheduleDeliveryRetry() {
    if (_deliveryRetryTimer != null) return;
    _deliveryRetryTimer = Timer(_deliveryRetryDelay, () {
      _deliveryRetryTimer = null;
      unawaited(_drainReorderBuffer());
    });
  }

  void _scheduleGapFetch({
    required int expectedSeq,
    required int minBufferedSeq,
  }) {
    if (_lastGapSeqRequested == expectedSeq) return;
    _lastGapSeqRequested = expectedSeq;
    _gapFetchTimer?.cancel();
    _gapFetchTimer = Timer(_reorderGapFetchDebounce, () {
      unawaited(_requestMissingFrom(expectedSeq));
    });
  }

  Future<void> _requestMissingFrom(int fromSeq) async {
    final ch = _channel;
    if (ch != null) {
      ch.sink.add(ClientMsg.fetchPending(deviceId: deviceId, fromSeq: fromSeq));
      return;
    }

    // If WS is down, fallback to HTTP fetch path.
    final prevNext = _nextSeq;
    _nextSeq = fromSeq;
    try {
      await pumpInbox();
    } finally {
      if (_nextSeq < prevNext) {
        _nextSeq = prevNext;
      }
    }
  }

  Future<void> _sendAck({required int seq, required String msgId}) async {
    final ch = _channel;
    if (ch != null && _wsReady) {
      // DURABLE-ACK HARDENING (2026-06-25): a WS ack is fire-and-forget — on a
      // half-open socket it is silently lost, the relay never deletes the row,
      // and Welcome re-pins the cursor down to MIN(pending) on the next
      // reconnect (the lost-ack pull-back / cursor thrash). Park the ack
      // durably BEFORE sending so _drainPendingAcks re-acks it over the
      // reliable, status-checked HTTP path; the row is pruned the moment any
      // HTTP ack is confirmed (pendingAckDelete below / in _drainPendingAcks).
      try {
        await db.pendingAckUpsert(
          msgId: msgId,
          seq: seq,
          nowMs: DateTime.now().millisecondsSinceEpoch,
        );
      } catch (_) {
        // best-effort durability — never block the hot ack path
      }
      DiagLog.event('inbox', 'ack_ws', {'seq': seq});
      ch.sink.add(ClientMsg.ack(deviceId: deviceId, seq: seq, msgId: msgId));
      return;
    }
    final ok = await _ackOverHttp(seq: seq, msgId: msgId);
    // DIAG (offline-drain): HTTP ack outcome. ok=false means the relay did not
    // confirm; the message stays pending and is re-offered.
    DiagLog.event('inbox', 'ack_http', {'seq': seq, 'ok': ok});
    try {
      if (ok) {
        await db.pendingAckDelete(msgId);
      } else {
        // Durable ACK queue: park the failed ack and retry on the next connect
        // so the relay's per-device cursor converges and the message is not
        // left stranded below the cursor (re-offered forever).
        await db.pendingAckUpsert(
          msgId: msgId,
          seq: seq,
          nowMs: DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (_) {
      // best-effort durability bookkeeping
    }
  }

  /// SCHEDULED RE-KEY REFRESH (2026-07-19): retract a still-held "send later"
  /// row so the sender can re-upload the same message under a fresh session.
  /// Returns true iff the relay removed the row (false once released — an
  /// already-delivered message can never be silently unsent).
  Future<bool> cancelScheduled({
    required String toDeviceId,
    required String msgId,
  }) async {
    final base = httpBaseUrl;
    if (base == null) return false;
    try {
      final uri = base.resolve('/v1/cancel_scheduled');
      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = AuthSigner.relayHttpCancelScheduledMessage(
        deviceId: deviceId,
        toDeviceId: toDeviceId,
        msgId: msgId,
        tsMs: tsMs,
        nonceB64: nonceB64,
      );
      final sigB64 = await AuthSigner.signEd25519B64(
        identityKeyPair: await _loadIdentityKeyPair(),
        message: msg,
      );
      final resp = await _http
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              'x-secretly-device-id': deviceId,
              'x-secretly-ts-ms': tsMs.toString(),
              'x-secretly-nonce-b64': nonceB64,
              'x-secretly-signature-b64': sigB64,
            },
            body: jsonEncode({
              'device_id': deviceId,
              'to_device_id': toDeviceId,
              'msg_id': msgId,
            }),
          )
          .timeout(_httpTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return false;
      final decoded = jsonDecode(resp.body);
      return decoded is Map && decoded['cancelled'] == true;
    } catch (_) {
      return false; // best-effort — caller treats false as "old copy may fire"
    }
  }

  /// Sends a single ACK over HTTP. Returns true iff the relay accepted it.
  Future<bool> _ackOverHttp({required int seq, required String msgId}) async {
    final base = httpBaseUrl;
    if (base == null) return false;
    try {
      final uri = base.resolve('/v1/ack');
      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = AuthSigner.relayHttpAckMessage(
        deviceId: deviceId,
        seq: seq,
        tsMs: tsMs,
        nonceB64: nonceB64,
      );
      final sigB64 = await AuthSigner.signEd25519B64(
        identityKeyPair: await _loadIdentityKeyPair(),
        message: msg,
      );
      final resp = await _http
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              'x-secretly-device-id': deviceId,
              'x-secretly-ts-ms': tsMs.toString(),
              'x-secretly-nonce-b64': nonceB64,
              'x-secretly-signature-b64': sigB64,
            },
            body: jsonEncode({
              'device_id': deviceId,
              'seq': seq,
              'msg_id': msgId,
            }),
          )
          .timeout(_httpTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        if (resp.statusCode == 429) _noteRateLimited('ack');
        throw StateError('ack failed: HTTP ${resp.statusCode}');
      }
      _lastAckFailureSummary = null;
      return true;
    } catch (error) {
      _lastAckFailureAtMs = DateTime.now().millisecondsSinceEpoch;
      _ackFailureCount += 1;
      _lastAckFailureSummary = _summarizeAckError(error);
      return false;
    }
  }

  /// Retry every ACK that was parked because it could not reach the relay.
  /// Called on (re)connect — the moment the network is back. Idempotent: the
  /// relay treats an ack for an already-removed message as a no-op.
  bool _drainPendingAcksInFlight = false;
  Future<void> _drainPendingAcks() async {
    if (_drainPendingAcksInFlight) return;
    // Подтверждения ходят той же дорогой и в тот же бакет: долбить ими закрытую
    // дверь значит продлевать блокировку выборки, из-за которой стоит звонок.
    if (_isRateLimited) return;
    _drainPendingAcksInFlight = true;
    try {
      final rows = await db.pendingAckList(limit: 500);
      if (rows.isEmpty) return;
      var recovered = 0;
      for (final row in rows) {
        final mId = (row['msg_id'] as String?)?.trim() ?? '';
        final s = (row['seq'] as num?)?.toInt() ?? -1;
        if (mId.isEmpty || s < 0) {
          if (mId.isNotEmpty) {
            await db.pendingAckDelete(mId);
          }
          continue;
        }
        if (await _ackOverHttp(seq: s, msgId: mId)) {
          await db.pendingAckDelete(mId);
          recovered++;
        }
      }
      if (recovered > 0) {
        DiagLog.event('relay', 'pending_acks_drained', {'count': recovered});
      }
    } catch (_) {
      // best-effort
    } finally {
      _drainPendingAcksInFlight = false;
    }
  }

  Future<SimpleKeyPair> _loadIdentityKeyPair() async {
    final cached = _identityKeyPair;
    if (cached != null) return cached;
    final override = _identityKeyPairOverride;
    if (override != null) {
      _identityKeyPair = override;
      return override;
    }
    final kp = await deviceKeys.loadIdentityKeyPair(
      profileId: selfProfileId,
      deviceId: deviceId,
    );
    _identityKeyPair = kp;
    return kp;
  }

  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(_wsPingTimerPeriod, (_) {
      if (!_wsReady || _channel == null) {
        _stopPingTimer();
        return;
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (_waitingForPong) {
        // Previous ping went unanswered — WS is stale.
        _waitingForPong = false;
        markWsStaleAndReconnect();
        return;
      }
      final idleMs = nowMs - _lastWsActivityAtMs;
      if (idleMs < _wsPingIdleThreshold.inMilliseconds) return;
      _waitingForPong = true;
      try {
        _channel?.sink.add(ClientMsg.ping());
      } catch (_) {
        markWsStaleAndReconnect();
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _waitingForPong = false;
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _deliveryRetryTimer?.cancel();
    _deliveryRetryTimer = null;
    _gapFetchTimer?.cancel();
    _gapFetchTimer = null;
    _lastGapSeqRequested = null;
    _deliveryApplyFailuresBySeq.clear();
    _stopPingTimer();
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    _wsReady = false;
    _setConnected(false);
    _connecting = false;
  }

  Future<void> close() async {
    await disconnect();
    if (_ownsHttpClient) {
      _http.close();
    }
  }

  Future<void> dispose() => close();

  Future<void> _closeChannelBestEffort(WebSocketChannel channel) async {
    try {
      await channel.sink.close().timeout(const Duration(seconds: 2));
    } catch (_) {
      // ignore cleanup failures; reconnect will use a fresh channel
    }
  }

  /// Drop the current WS and schedule a fresh reconnect.  Any pending outbox
  /// items will fall back to HTTP while the socket is down.
  ///
  /// When [urgent] is true the exponential backoff counter is reset so the
  /// next attempt fires with the minimum 400 ms delay regardless of any
  /// previous failure streak. Used during active calls when a network handoff
  /// makes the previous socket unrecoverable — waiting up to 8 s of stale
  /// backoff there would stall ICE recovery.
  void markWsStaleAndReconnect({bool urgent = false}) {
    if (urgent) {
      // Even if a reconnect was already scheduled with a long delay, cancel
      // it so the urgent reconnect can fire on the short backoff below.
      if (_reconnectTimer != null) {
        _reconnectTimer!.cancel();
        _reconnectTimer = null;
      }
      _reconnectAttempt = 0;
      _backoffSeedMs = 0;
    } else if (!_wsReady && _reconnectTimer != null) {
      return; // already reconnecting
    }
    _stopPingTimer();
    _wsReady = false;
    final ch = _channel;
    _channel = null;
    _sub?.cancel();
    _sub = null;
    // PR-E (Bug 16): bound the sink.close latency. The original
    // `unawaited(close().catchError(...))` could keep the OS socket in a
    // half-closed state if the platform process was killed mid-close
    // (airplane-mode flick, system OOM) — the relay would then keep the
    // old session record alive long enough to deliver duplicates on the
    // next reconnect. Race the close against a 500 ms wallclock budget so
    // a normal close completes promptly and a stuck close gets abandoned.
    final sink = ch?.sink;
    if (sink != null) {
      unawaited(
        Future.any<Object?>(<Future<Object?>>[
          sink.close().catchError((_) {}),
          Future<Object?>.delayed(const Duration(milliseconds: 500)),
        ]),
      );
    }
    _setConnected(false);
    _connecting = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;

    _reconnectAttempt = (_reconnectAttempt + 1).clamp(1, 10);
    final baseMs = min(8 * 1000, 400 * (1 << (_reconnectAttempt - 1)));
    final jitterMs = _rng.nextInt(250);
    // AUD-041 support: `_backoffSeedMs` can be raised temporarily by
    // specific server-push events (e.g. `session_replaced`) so the
    // local client doesn't immediately race the other client back onto
    // the socket. We drain the seed after consuming it once.
    final seedMs = _backoffSeedMs;
    _backoffSeedMs = 0;
    final delay = Duration(milliseconds: baseMs + jitterMs + seedMs);

    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      try {
        await connect();
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  Future<void> pumpOutbox() async {
    _outboxPumpQueued = true;
    final outboxStartMs = DateTime.now().millisecondsSinceEpoch;
    if (_isOutboxPumping) {
      // LIVENESS WATCHDOG (2026-06-25): mirror the inbound-drain watchdog so a
      // hung local DB / lease await can never strand outbound delivery. Outbox
      // sends dedup server-side (msg_id), so a force-cleared re-pump cannot
      // duplicate an already-delivered message.
      if (outboxStartMs - _outboxPumpStartedAtMs > _outboxWatchdogMs) {
        DiagLog.event('outbox', 'pump_force_cleared', {
          'stuck_ms': outboxStartMs - _outboxPumpStartedAtMs,
        });
        _outboxPumpGeneration++;
        _isOutboxPumping = false;
      } else {
        return;
      }
    }
    _isOutboxPumping = true;
    _outboxPumpStartedAtMs = outboxStartMs;
    final myGen = ++_outboxPumpGeneration;
    try {
      while (_outboxPumpQueued) {
        _outboxPumpQueued = false;
        final ch = _channel;
        if (ch == null || !_wsReady) {
          for (var i = 0; i < 8; i++) {
            final hadFullBatch = await _pumpOutboxHttpBatch();
            if (!hadFullBatch) break;
          }
          continue;
        }

        for (var i = 0; i < 8; i++) {
          final hadFullBatch = await _pumpOutboxWsBatch();
          if (!hadFullBatch) break;
        }
      }
    } finally {
      if (_outboxPumpGeneration == myGen) {
        _isOutboxPumping = false;
      }
      if (_outboxPumpQueued) {
        unawaited(pumpOutbox());
      }
    }
  }

  Future<bool> _pumpOutboxWsBatch() async {
    final ch = _channel;
    if (ch == null || !_wsReady) return false;

    final due = await _outgoingScheduler.leaseDue(limit: _outboxBatchLimit);
    for (final row in due) {
      final msgId = row['msg_id'] as String;
      try {
        final toDeviceId = row['to_device_id'] as String;
        final ciphertextB64 = row['ciphertext_b64'] as String;
        final localEventId = row['event_id_ref'] as String?;
        final correlationId = row['correlation_id'] as String?;
        final transportMetaJson = row['transport_meta_json'] as String?;
        final ttlSeconds = (row['ttl_seconds'] as num).toInt();
        final deliverAtMs = (row['deliver_at_ms'] as num?)?.toInt() ?? 0;
        final attemptCount = (row['attempt_count'] as num?)?.toInt() ?? 0;
        final createdAtMs = (row['created_at_ms'] as num?)?.toInt() ?? 0;
        final onlineOnly = isOnlineOnlyOutboxRow(row);
        final rcptDigest = await _rowDeviceDigest(row);

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (createdAtMs > 0 &&
            _outboxExpired(
              nowMs: nowMs,
              createdAtMs: createdAtMs,
              ttlSeconds: ttlSeconds,
            )) {
          await db.messageAttemptLogAppend(
            correlationId: correlationId,
            localEventId: localEventId,
            msgId: msgId,
            toDeviceId: toDeviceId,
            startedAtMs: nowMs,
            finishedAtMs: nowMs,
            attemptIndex: attemptCount,
            transport: 'ws',
            result: 'expired',
            errorCode: MessageFailureReason.ttlExpired,
            latencyMs: 0,
          );
          await db.outboxMarkFailed(
            msgId,
            reasonCode: MessageFailureReason.ttlExpired,
            errorCode: MessageFailureReason.ttlExpired,
            errorMessageRedacted: 'message ttl expired before relay send',
          );
          continue;
        }
        if (attemptCount >= _outboxMaxAttempts) {
          await db.messageAttemptLogAppend(
            correlationId: correlationId,
            localEventId: localEventId,
            msgId: msgId,
            toDeviceId: toDeviceId,
            startedAtMs: nowMs,
            finishedAtMs: nowMs,
            attemptIndex: attemptCount,
            transport: 'ws',
            result: 'exhausted',
            errorCode: MessageFailureReason.retryExhausted,
            latencyMs: 0,
          );
          await db.outboxMarkFailed(
            msgId,
            reasonCode: MessageFailureReason.retryExhausted,
            errorCode: MessageFailureReason.retryExhausted,
            errorMessageRedacted: 'max relay send attempts reached',
          );
          continue;
        }

        final startedAtMs = nowMs;
        try {
          ch.sink.add(
            ClientMsg.send(
              toDeviceId: toDeviceId,
              msgId: msgId,
              ciphertextB64: ciphertextB64,
              ttlSeconds: ttlSeconds,
              transportMetaJson: transportMetaJson,
              deliverAtMs: deliverAtMs,
              onlineOnly: onlineOnly,
              rcptDigest: rcptDigest,
            ),
          );
          // If SENT_OK doesn't arrive, we'll retry.
          final nextAttempt = attemptCount + 1;
          await db.outboxMarkSending(
            msgId,
            retryAfterMs: _retryDelayMsForAttempt(nextAttempt),
          );
          await db.messageAttemptLogAppend(
            correlationId: correlationId,
            localEventId: localEventId,
            msgId: msgId,
            toDeviceId: toDeviceId,
            startedAtMs: startedAtMs,
            finishedAtMs: DateTime.now().millisecondsSinceEpoch,
            attemptIndex: nextAttempt,
            transport: 'ws',
            result: 'queued_for_ack',
            latencyMs: DateTime.now().millisecondsSinceEpoch - startedAtMs,
          );
        } catch (e) {
          final nextAttempt = attemptCount + 1;
          await db.outboxMarkSending(
            msgId,
            retryAfterMs: _retryDelayMsForAttempt(nextAttempt),
            reasonCode: MessageFailureReason.relayUnavailable,
          );
          await db.messageAttemptLogAppend(
            correlationId: correlationId,
            localEventId: localEventId,
            msgId: msgId,
            toDeviceId: toDeviceId,
            startedAtMs: startedAtMs,
            finishedAtMs: DateTime.now().millisecondsSinceEpoch,
            attemptIndex: nextAttempt,
            transport: 'ws',
            result: 'exception_retry',
            errorCode: MessageFailureReason.relayUnavailable,
            errorMessageRedacted: _safeErrorText(e),
            latencyMs: DateTime.now().millisecondsSinceEpoch - startedAtMs,
          );
          _channel = null;
          _wsReady = false;
          _setConnected(false);
          _scheduleReconnect();
        }
      } finally {
        await _outgoingScheduler.releaseLease(msgId);
      }
    }

    return due.length >= _outboxBatchLimit;
  }

  Future<bool> _pumpOutboxHttpBatch() async {
    final base = httpBaseUrl;
    if (base == null) return false;

    final due = await _outgoingScheduler.leaseDue(limit: _outboxBatchLimit);
    for (final row in due) {
      final msgId = row['msg_id'] as String;
      try {
        final toDeviceId = row['to_device_id'] as String;
        final ciphertextB64 = row['ciphertext_b64'] as String;
        final localEventId = row['event_id_ref'] as String?;
        final correlationId = row['correlation_id'] as String?;
        final transportMetaJson = row['transport_meta_json'] as String?;
        final ttlSeconds = (row['ttl_seconds'] as num).toInt();
        final deliverAtMs = (row['deliver_at_ms'] as num?)?.toInt() ?? 0;
        final attemptCount = (row['attempt_count'] as num?)?.toInt() ?? 0;
        final createdAtMs = (row['created_at_ms'] as num?)?.toInt() ?? 0;
        final onlineOnly = isOnlineOnlyOutboxRow(row);
        final rcptDigest = await _rowDeviceDigest(row);

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (createdAtMs > 0 &&
            _outboxExpired(
              nowMs: nowMs,
              createdAtMs: createdAtMs,
              ttlSeconds: ttlSeconds,
            )) {
          await db.messageAttemptLogAppend(
            correlationId: correlationId,
            localEventId: localEventId,
            msgId: msgId,
            toDeviceId: toDeviceId,
            startedAtMs: nowMs,
            finishedAtMs: nowMs,
            attemptIndex: attemptCount,
            transport: 'http',
            result: 'expired',
            errorCode: MessageFailureReason.ttlExpired,
            latencyMs: 0,
          );
          await db.outboxMarkFailed(
            msgId,
            reasonCode: MessageFailureReason.ttlExpired,
            errorCode: MessageFailureReason.ttlExpired,
            errorMessageRedacted: 'message ttl expired before relay send',
          );
          continue;
        }
        if (attemptCount >= _outboxMaxAttempts) {
          await db.messageAttemptLogAppend(
            correlationId: correlationId,
            localEventId: localEventId,
            msgId: msgId,
            toDeviceId: toDeviceId,
            startedAtMs: nowMs,
            finishedAtMs: nowMs,
            attemptIndex: attemptCount,
            transport: 'http',
            result: 'exhausted',
            errorCode: MessageFailureReason.retryExhausted,
            latencyMs: 0,
          );
          await db.outboxMarkFailed(
            msgId,
            reasonCode: MessageFailureReason.retryExhausted,
            errorCode: MessageFailureReason.retryExhausted,
            errorMessageRedacted: 'max relay send attempts reached',
          );
          continue;
        }

        final startedAtMs = nowMs;
        try {
          final uri = base.resolve('/v1/send');
          final tsMs = ServerClock.instance.nowMs();
          final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
          final msg = AuthSigner.relayHttpSendMessage(
            fromDeviceId: deviceId,
            toDeviceId: toDeviceId,
            msgId: msgId,
            ciphertextB64: ciphertextB64,
            ttlSeconds: ttlSeconds,
            transportMetaJson: transportMetaJson,
            tsMs: tsMs,
            nonceB64: nonceB64,
          );
          final sigB64 = await AuthSigner.signEd25519B64(
            identityKeyPair: await _loadIdentityKeyPair(),
            message: msg,
          );
          final resp = await _http
              .post(
                uri,
                headers: {
                  'content-type': 'application/json',
                  'x-secretly-device-id': deviceId,
                  'x-secretly-ts-ms': tsMs.toString(),
                  'x-secretly-nonce-b64': nonceB64,
                  'x-secretly-signature-b64': sigB64,
                },
                body: jsonEncode({
                  'to_device_id': toDeviceId,
                  'msg_id': msgId,
                  'ciphertext_b64': ciphertextB64,
                  'ttl_seconds': ttlSeconds,
                  if (transportMetaJson != null &&
                      transportMetaJson.trim().isNotEmpty)
                    'transport_meta_json': transportMetaJson.trim(),
                  // SCHEDULED DELIVERY (2026-07-17): relay release time (not
                  // part of the request signature — it is not sensitive; the
                  // relay holds vs delivers, nothing more).
                  if (deliverAtMs > 0) 'deliver_at_ms': deliverAtMs,
                  // П-4: тоже вне подписи, по тому же прецеденту.
                  if (onlineOnly) 'online_only': true,
                  // П-1: сводка росписи — вне подписи, как и выше.
                  if (rcptDigest != null) 'rcpt_digest': rcptDigest,
                }),
              )
              .timeout(_httpTimeout);
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            await db.outboxMarkSent(msgId);
            if (onlineOnly && resp.body.contains('dropped_offline')) {
              unawaited(_noteOnlineOnlyDropped(msgId));
            }
            if (rcptDigest != null && resp.body.contains('device_set_stale')) {
              try {
                final j = jsonDecode(resp.body);
                final ids = j is Map && j['device_ids'] is List
                    ? (j['device_ids'] as List).whereType<String>().toList()
                    : null;
                if (ids != null) onDeviceSetStale?.call(msgId, ids);
              } catch (_) {}
            }
            await db.messageAttemptLogAppend(
              correlationId: correlationId,
              localEventId: localEventId,
              msgId: msgId,
              toDeviceId: toDeviceId,
              startedAtMs: startedAtMs,
              finishedAtMs: DateTime.now().millisecondsSinceEpoch,
              attemptIndex: attemptCount + 1,
              transport: 'http',
              result: 'accepted',
              latencyMs: DateTime.now().millisecondsSinceEpoch - startedAtMs,
            );
            final spentHttp = await db.resendBudgetConsumeForAcceptedMsg(
              msgId: msgId,
              nowMs: DateTime.now().millisecondsSinceEpoch,
            );
            DiagLog.event('outbox', 'sent', {
              'transport': 'http',
              'msg': DiagLog.pfx(msgId),
              if (spentHttp) 'resend_budget': 'spent',
              'http_status': resp.statusCode,
              'latency_ms': DateTime.now().millisecondsSinceEpoch - startedAtMs,
            });
          } else if (resp.statusCode == 400 ||
              resp.statusCode == 401 ||
              resp.statusCode == 403 ||
              resp.statusCode == 404) {
            // П-1: «устройства больше нет» — повод обновить роспись адресата,
            // а не только молча отметить сбой (при включённой сверке).
            if (resp.statusCode == 400 &&
                resp.body.contains('unknown recipient device')) {
              onUnknownRecipientDevice?.call(toDeviceId);
            }
            await db.messageAttemptLogAppend(
              correlationId: correlationId,
              localEventId: localEventId,
              msgId: msgId,
              toDeviceId: toDeviceId,
              startedAtMs: startedAtMs,
              finishedAtMs: DateTime.now().millisecondsSinceEpoch,
              attemptIndex: attemptCount + 1,
              transport: 'http',
              result: 'permanent_failure',
              errorCode: 'http_${resp.statusCode}',
              errorMessageRedacted:
                  'relay rejected send with HTTP ${resp.statusCode}',
              latencyMs: DateTime.now().millisecondsSinceEpoch - startedAtMs,
            );
            await db.outboxMarkFailed(
              msgId,
              reasonCode: 'http_${resp.statusCode}',
              errorCode: 'http_${resp.statusCode}',
              errorMessageRedacted:
                  'relay rejected send with HTTP ${resp.statusCode}',
            );
          } else {
            final nextAttempt = attemptCount + 1;
            await db.outboxMarkSending(
              msgId,
              retryAfterMs: _retryDelayMsForAttempt(nextAttempt),
              reasonCode: MessageFailureReason.relayUnavailable,
            );
            await db.messageAttemptLogAppend(
              correlationId: correlationId,
              localEventId: localEventId,
              msgId: msgId,
              toDeviceId: toDeviceId,
              startedAtMs: startedAtMs,
              finishedAtMs: DateTime.now().millisecondsSinceEpoch,
              attemptIndex: nextAttempt,
              transport: 'http',
              result: 'retryable_http_failure',
              errorCode: 'http_${resp.statusCode}',
              errorMessageRedacted: 'relay temporary HTTP ${resp.statusCode}',
              latencyMs: DateTime.now().millisecondsSinceEpoch - startedAtMs,
            );
          }
        } catch (e) {
          final nextAttempt = attemptCount + 1;
          await db.outboxMarkSending(
            msgId,
            retryAfterMs: _retryDelayMsForAttempt(nextAttempt),
            reasonCode: MessageFailureReason.relayUnavailable,
          );
          await db.messageAttemptLogAppend(
            correlationId: correlationId,
            localEventId: localEventId,
            msgId: msgId,
            toDeviceId: toDeviceId,
            startedAtMs: startedAtMs,
            finishedAtMs: DateTime.now().millisecondsSinceEpoch,
            attemptIndex: nextAttempt,
            transport: 'http',
            result: 'exception_retry',
            errorCode: MessageFailureReason.relayUnavailable,
            errorMessageRedacted: _safeErrorText(e),
            latencyMs: DateTime.now().millisecondsSinceEpoch - startedAtMs,
          );
        }
      } finally {
        await _outgoingScheduler.releaseLease(msgId);
      }
    }

    return due.length >= _outboxBatchLimit;
  }

  /// PR4 (SPRINT2_AUDIT §16, 2026-05-19): the optional [force] flag bypasses
  /// the "WS is fresh → skip HTTP" short-circuit. Passed `true` by the
  /// desktop boot-time eager backfill kicker (and the wake-from-sleep
  /// orchestrator) because there's a race window where:
  ///   • WS has just connected (so `_wsReady=true`, `_lastWsActivityAtMs` is
  ///     fresh from the handshake),
  ///   • the `Welcome → FetchPending` reply is still in flight on the WS,
  ///   • but the user has already opened a chat and the panel rendered an
  ///     empty list from a stale local DB snapshot.
  /// Calling with `force: true` issues the HTTP `/v1/pending` request
  /// immediately so the events land in the local DB and the chat-thread
  /// `controller.changed` listener can re-render. Mobile callers continue
  /// to pass `force=false` (default), so this is additive — the running
  /// mobile build keeps its exact existing behaviour.
  Future<void> pumpInbox({bool force = false}) async {
    // WebSocket delivers in realtime; skip HTTP poll when WS is fresh.
    // If the WS has been silent for > _wsStaleThresholdMs the connection is
    // likely half-open (OS killed the TCP silently) — fall through to HTTP so
    // we don't miss messages while waiting for the ping timer to fire.
    // 🔴 ПОЧЕМУ НАСОС ПОШЁЛ В СЕТЬ (14.08.2026).
    //
    // Аудит: 297 HTTP-выборок на 41 полезный результат — 7,2 запроса впустую на
    // один. Насос обязан выходить здесь, ничего не запрашивая, когда вебсокет
    // жив и свеж. Значит он не считался свежим — а почему, сказать было нечем.
    //
    // Подозрение, требующее подтверждения замером: `force` ниже НАМЕРЕННО
    // обнуляет `_lastWsActivityAtMs` (страховка 25.06 от проскока мимо затора),
    // и обнулённая отметка выглядит как «мёртв целую вечность», пока не придёт
    // следующий кадр. Принудительный проход идёт каждые 8 секунд, а обычный —
    // каждую секунду. Если кадров нет, каждый обычный тик уходит в сеть.
    //
    // Поэтому пишем ПРИЧИНУ, а не только факт: живо ли соединение, готово ли,
    // и какого возраста отметка. Одного сеанса хватит, чтобы отделить
    // «обнулили сами» от «сеть действительно молчит».
    // 🔴 Уступаем лимиту. Запрос, отправленный в закрытую дверь, не приносит
    // ничего и продлевает блокировку — а вместе с ней и молчание ящика, из-за
    // которого не собирается принятый звонок.
    if (_isRateLimited) return;
    final gateNowMs = DateTime.now().millisecondsSinceEpoch;
    final staleMs = _lastWsActivityAtMs == 0
        ? -1
        : gateNowMs - _lastWsActivityAtMs;
    if (!force && _channel != null && _wsReady && !_forceDrainInFlight) {
      if (staleMs >= 0 && staleMs < _wsStaleThresholdMs) return;
    }
    DiagLog.event('relay', 'pump_went_to_network', {
      'force': force,
      'has_channel': _channel != null,
      'ws_ready': _wsReady,
      // -1 означает «отметка обнулена» — это и есть подозреваемый.
      'stale_ms': staleMs,
      'threshold_ms': _wsStaleThresholdMs,
      'force_in_flight': _forceDrainInFlight,
    });
    if (force) {
      // 🔴 РАНЬШЕ ЗДЕСЬ ОТМЕТКУ ЖИВОСТИ ОБНУЛЯЛИ (исправлено 14.08.2026).
      //
      // Замысел был верным: пока идёт принудительная выборка, соседний обычный
      // тик не должен проскочить мимо затора по проверке свежести (PR-E, Bug 14).
      // Способ оказался слишком широким: обнулённая отметка выглядит как «вебсокет
      // мёртв целую вечность» для ВСЕХ последующих тиков — до самого следующего
      // кадра. Принудительный проход идёт раз в 8 секунд, обычный — раз в секунду.
      //
      // ЗАМЕР 14.08 (сборка 504): 30 раз подряд `pump_went_to_network` при
      // has_channel=true, ws_ready=true, stale_ms=-1 — вебсокет ЖИВ И ГОТОВ, а
      // насос всё равно шёл в сеть. За сеанс: 297 выборок на 41 полезный
      // результат, 7,2 запроса впустую на один. `ws_closed` не было НИ РАЗУ,
      // то есть сеть ни при чём — мы ослепляли себя сами.
      //
      // Теперь намерение выражено прямо: отдельный признак «идёт принудительная
      // выборка». Защита та же, а живость соединения остаётся правдой.
      _forceDrainInFlight = true;
      // CONVERGENCE HARDENING (2026-06-25): parked acks were previously drained
      // ONLY on a full WS Welcome. A WS-blocked background device (MIUI / iOS
      // suspend) that reaches the relay only over HTTP would never re-send
      // them, so the relay cursor never converged and stranded rows were
      // re-offered forever. Drain them on the force-pump cadence too
      // (idempotent; single-flight guarded inside _drainPendingAcks).
      unawaited(_drainPendingAcks());
    }
    final base = httpBaseUrl;
    if (base == null) {
      // 🔴 Признак ставится ВЫШЕ, а `finally` начинается НИЖЕ — этот выход в
      // щели между ними. Не снять здесь значит оставить насос ходить в сеть
      // навсегда: ровно тот дефект, что мы чиним, только вечный.
      if (force) _forceDrainInFlight = false;
      return;
    }

    try {
      // 🔴 ЗАМЕР ПО ФАЗАМ (12.08.2026).
      //
      // Полевой замер ответа на звонок: приложение стартовало за 646 мс, а
      // приглашение звонка пришло только на 8-й секунде — причём
      // `call_signal_received` случился В ТУ ЖЕ СЕКУНДУ, что `pump_inbox_ok`.
      // Значит разбор был быстрым, а время съел САМ НАСОС. Чем именно — сказать
      // было нечем: у него нет ни одной промежуточной отметки, только «ок» либо
      // «таймаут через 10 с».
      //
      // Три подозреваемых, и лечатся они по-разному: поздний ВЫЗОВ насоса
      // (чинить порядок запуска), медленная ПОДПИСЬ (хранилище ключей на
      // холодном старте) и медленная СЕТЬ (DNS/TLS).
      final phaseStart = DateTime.now().millisecondsSinceEpoch;
      final fromSeq = _nextSeq;
      const limit = 500;
      final uri = base.resolve(
        '/v1/pending/$deviceId?from_seq=$fromSeq&limit=$limit',
      );

      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = AuthSigner.relayHttpPendingMessage(
        deviceId: deviceId,
        fromSeq: fromSeq,
        limit: limit,
        tsMs: tsMs,
        nonceB64: nonceB64,
      );
      final sigB64 = await AuthSigner.signEd25519B64(
        identityKeyPair: await _loadIdentityKeyPair(),
        message: msg,
      );
      final signedAtMs = DateTime.now().millisecondsSinceEpoch;
      final resp = await _http
          .get(
            uri,
            headers: {
              'x-secretly-device-id': deviceId,
              'x-secretly-ts-ms': tsMs.toString(),
              'x-secretly-nonce-b64': nonceB64,
              'x-secretly-signature-b64': sigB64,
            },
          )
          .timeout(_httpTimeout);
      final httpDoneAtMs = DateTime.now().millisecondsSinceEpoch;
      DiagLog.event('relay', 'pump_inbox_phases', {
        'sign_ms': signedAtMs - phaseStart,
        'http_ms': httpDoneAtMs - signedAtMs,
        'total_ms': httpDoneAtMs - phaseStart,
        'force': force,
        'status': resp.statusCode,
        // Разрыв от «запуск закончен» до ответа насоса. Пять секунд в поле —
        // и всё это время приглашение звонка лежало в ящике.
        if (readyAtMsProvider != null)
          'since_ready_ms': readyAtMsProvider!() <= 0
              ? -1
              : httpDoneAtMs - readyAtMsProvider!(),
      });
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        // PR-D (Bug 12): emit telemetry so silent 5xx/auth/DNS hiccups are
        // observable in DebugConsole. Swallow stays so we don't crash the
        // app, but the breadcrumb makes field reports actionable.
        DiagLog.event('relay', 'pump_inbox_http_status', {
          'status': resp.statusCode,
          'force': force,
          'from_seq': fromSeq,
        });
        if (resp.statusCode == 429) _noteRateLimited('pump_inbox');
        if (resp.statusCode == 401 && resp.body.contains('unknown device')) {
          onUnknownDevice?.call();
        }
        if (resp.statusCode == 401 && resp.body.contains('bad signature')) {
          onBadSignature?.call();
        }
        return;
      }
      _noteRelayRequestSucceeded();
      onDeviceAccepted?.call();
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final items = (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

      // Field diagnosis (2026-06-19): pump success was silent, so "did the
      // fetch actually retrieve the pending message?" was a blind spot. Log
      // non-empty drains (kept quiet on the common empty 1s-timer poll).
      if (items.isNotEmpty) {
        DiagLog.event('relay', 'pump_inbox_ok', {
          'force': force,
          'count': items.length,
          'from_seq': fromSeq,
        });
      }

      for (final it in items) {
        final seq = (it['seq'] as num).toInt();
        final msgId = it['msg_id'] as String?;
        final ciphertextB64 = it['ciphertext_b64'] as String?;
        if (msgId == null || ciphertextB64 == null) continue;
        AttestedSenders.record(msgId, it['from_device_id']);

        if (seq < _nextSeq) {
          // SEQ-CURSOR FIX (2026-06-12): a below-cursor item over HTTP is a
          // message that was STRANDED when the cursor advanced past a lost ACK
          // (app closed / background-killed between apply and ack). Previously
          // this path ACKed and DROPPED it WITHOUT decrypting — so the
          // stranded message (and that inbound direction) was lost forever
          // after the app was reopened. Mirror the WebSocket below-cursor
          // handler: re-process it (idempotent via inbox_seen + events
          // INSERT-OR-IGNORE) and only then re-ACK. This is the fix for
          // "after I close the app, messages from a peer never arrive again".
          final alreadySeen = await db.inboxHasSeen(msgId);
          var safeToAck = alreadySeen;
          if (!alreadySeen) {
            var applied = false;
            try {
              applied = await onDelivered(
                msgId: msgId,
                ciphertextB64: ciphertextB64,
              );
            } catch (_) {
              applied = false;
            }
            if (applied) {
              await db.inboxMarkSeen(msgId);
              DiagLog.event('inbox', 'backfilled_below_cursor_http', {
                'msg': DiagLog.pfx(msgId),
              });
              safeToAck = true;
            } else {
              // LOSS-SAFETY HARDENING (2026-06-29): a below-cursor re-offer we
              // could NOT apply (ratchet/crypto not ready on a cold overnight
              // wake, or a transient decrypt) must NOT be acked-and-dropped —
              // ack DELETEs it from the relay mailbox forever and it was never
              // persisted (the exact "1-2 messages lost after long sleep" bug).
              // Park it in quarantine first (INSERT-OR-IGNORE; the periodic
              // replay sweep re-applies it idempotently once deps are ready),
              // mirroring the normal drain path. Only ack once it is durably
              // parked; if even quarantine fails, LEAVE it in the mailbox so the
              // next pump retries — never ack-and-drop.
              try {
                await db.inboxQuarantineUpsert(
                      attestedFromDeviceId: AttestedSenders.lookup(msgId),
                  msgId: msgId,
                  // F-ROOMSK-5: the author is in the wire header, so the fast
                  // per-sender replay can find this row later.
                  senderDeviceId: _senderDeviceIdFromWireHeader(ciphertextB64),
                  ciphertextB64: ciphertextB64,
                  nowMs: DateTime.now().millisecondsSinceEpoch,
                );
                safeToAck = true;
                DiagLog.event('inbox', 'below_cursor_http_quarantined', {
                  'seq': seq,
                  'msg': DiagLog.pfx(msgId),
                });
              } catch (_) {
                DiagLog.event('inbox', 'below_cursor_http_kept', {
                  'seq': seq,
                  'msg': DiagLog.pfx(msgId),
                });
              }
            }
          }
          if (safeToAck) {
            await _sendAck(seq: seq, msgId: msgId);
          }
          continue;
        }

        _reorderBuffer[seq] = Deliver(
          deviceId: deviceId,
          seq: seq,
          msgId: msgId,
          ciphertextB64: ciphertextB64,
        );
      }

      // DELIVERY DEADLOCK FIX (2026-06-19): the HTTP /v1/pending response is the
      // relay's complete view from `from_seq` (the relay MIN-clamps from_seq up
      // to its lowest available seq). So if the lowest seq it actually returned
      // is already ABOVE our cursor, the [_nextSeq, min) range provably no longer
      // exists on the relay (acked elsewhere / TTL-trimmed below a stale
      // persisted cursor). Advance the cursor immediately — otherwise the
      // reorder buffer waits for the missing `_nextSeq` forever and NOT A SINGLE
      // message is ever applied (observed live: pump_inbox_ok count climbs,
      // from_seq frozen, zero inbox.delivered). Safe: a skipped seq that later
      // shows up lands below the cursor and is re-applied via the below-cursor
      // backfill (idempotent via inbox_seen).
      // OFFLINE-DRAIN DEADLOCK FIX (2026-06-25): purge stale below-cursor
      // entries before computing minBuffered, else a lingering seq < _nextSeq
      // pins minBuffered below the cursor and this self-heal silently no-ops
      // (the same wedge the WS-drain gap branch hit).
      _reorderBuffer.removeWhere((k, _) => k < _nextSeq);
      // Same horizon for the rescue ledger: a seq the cursor has passed can
      // never come back through this path, so remembering it is pure growth.
      _handshakeRescuedSeqs.removeWhere((s) => s < _nextSeq);
      if (_reorderBuffer.isNotEmpty) {
        final minBuffered = _reorderBuffer.keys.reduce(min);
        if (minBuffered > _nextSeq) {
          DiagLog.event('inbox', 'gap_skipped', {
            'from': _nextSeq,
            'to': minBuffered,
            'src': 'http',
          });
          _nextSeq = minBuffered;
          await saveNextSeq(_nextSeq);
          _lastGapSeqRequested = null;
        }
      }

      await _drainReorderBuffer();
    } catch (e) {
      // PR-D (Bug 12): emit telemetry so silent network errors don't
      // disappear. Swallow preserved so a transient DNS failure doesn't
      // bubble up into a crash on the UI thread.
      DiagLog.event('relay', 'pump_inbox_failed', {
        'force': force,
        'reason': e.runtimeType.toString(),
        // Field diagnosis (2026-06-19): the type alone (_ClientSocketException)
        // hid whether this was a DNS "Failed host lookup" vs a connection
        // reset. Log a short sanitized message so the distinction is visible.
        'detail': e
            .toString()
            .replaceAll(RegExp(r'\s+'), '_')
            .replaceAll("'", ''),
      });
    } finally {
      // 🔴 СНЯТЬ ОБЯЗАТЕЛЬНО. Признак, который некому снять, оставил бы насос
      // ходить в сеть вечно — то есть ровно тот дефект, что мы чиним, только
      // навсегда. Поэтому в finally, а не в успешной ветке.
      if (force) _forceDrainInFlight = false;
    }
  }
}
