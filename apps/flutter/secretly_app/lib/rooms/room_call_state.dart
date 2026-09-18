// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
class CachedRoomCallParticipant {
  const CachedRoomCallParticipant({
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

  bool get isReconnecting => joinState == 'reconnecting';
}

class CachedRoomCall {
  const CachedRoomCall({
    required this.roomId,
    required this.callId,
    required this.state,
    required this.mediaType,
    required this.createdByProfileId,
    required this.createdByDeviceId,
    required this.stateVersion,
    required this.startedAtMs,
    required this.updatedAtMs,
    required this.endedAtMs,
    required this.expiresAtMs,
    required this.participants,
    required this.selfParticipant,
  });

  final String roomId;
  final String callId;
  final String state;
  final String mediaType;
  final String createdByProfileId;
  final String createdByDeviceId;
  final int stateVersion;
  final int startedAtMs;
  final int updatedAtMs;
  final int? endedAtMs;
  final int expiresAtMs;
  final List<CachedRoomCallParticipant> participants;
  final CachedRoomCallParticipant? selfParticipant;

  bool get isActive => state == 'active' && endedAtMs == null;

  int get joinedParticipantCount =>
      participants.where((participant) => participant.isJoined).length;
}
