// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
enum RoomPolicyFailureCode {
  notMember,
  adminOnly,
  moderationOnly,
  serviceUnavailable,
  transportBlocked,
  textMessagesDisabled,
  mediaDisabled,
  reactionsDisabled,
  reactionNotAllowed,
  slowModeActive,
  addMembersDenied,
  pinMessagesDenied,
  groupInfoChangeDenied,
  changeOwnTagDenied,
  invalidOwnTag,
  noRecipients,
  allRecipientsUnavailable,
  generic,
}

class RoomPolicyFailure implements Exception {
  RoomPolicyFailure(
    this.code, {
    this.cause,
    this.retryAfterSeconds,
    String? message,
  }) : message = message ??
           _defaultRoomPolicyFailureMessage(
             code,
             retryAfterSeconds: retryAfterSeconds,
           );

  final RoomPolicyFailureCode code;
  final Object? cause;
  final int? retryAfterSeconds;
  final String message;

  @override
  String toString() => message;
}

String _defaultRoomPolicyFailureMessage(
  RoomPolicyFailureCode code, {
  int? retryAfterSeconds,
}) {
  switch (code) {
    case RoomPolicyFailureCode.notMember:
      return 'You are no longer a participant in this room.';
    case RoomPolicyFailureCode.adminOnly:
      return 'Only admins can do that in this room.';
    case RoomPolicyFailureCode.moderationOnly:
      return 'Only moderators and admins can do that in this room.';
    case RoomPolicyFailureCode.serviceUnavailable:
      return 'Room service is unavailable right now. Try again when the relay reconnects.';
    case RoomPolicyFailureCode.transportBlocked:
      return 'This action is unavailable because room transport is blocked by policy.';
    case RoomPolicyFailureCode.textMessagesDisabled:
      return 'Your role cannot send text messages in this room.';
    case RoomPolicyFailureCode.mediaDisabled:
      return 'Your role cannot send media in this room.';
    case RoomPolicyFailureCode.reactionsDisabled:
      return 'Your role cannot use reactions in this room.';
    case RoomPolicyFailureCode.reactionNotAllowed:
      return 'This reaction is not allowed in this room.';
    case RoomPolicyFailureCode.slowModeActive:
      final seconds = retryAfterSeconds ?? 0;
      return 'Slow mode is enabled. Try again in ${seconds}s.';
    case RoomPolicyFailureCode.addMembersDenied:
      return 'Your role cannot add participants to this room.';
    case RoomPolicyFailureCode.pinMessagesDenied:
      return 'Your role cannot pin messages in this room.';
    case RoomPolicyFailureCode.groupInfoChangeDenied:
      return 'Your role cannot change the group profile.';
    case RoomPolicyFailureCode.changeOwnTagDenied:
      return 'Your role cannot change your room tag.';
    case RoomPolicyFailureCode.invalidOwnTag:
      return 'Room tag must be 32 characters or fewer and cannot contain control characters.';
    case RoomPolicyFailureCode.noRecipients:
      return 'No active participants are available to receive this message yet.';
    case RoomPolicyFailureCode.allRecipientsUnavailable:
      return 'Message could not be delivered: no participant devices are reachable right now.';
    case RoomPolicyFailureCode.generic:
      return 'This action is not available in this room right now.';
  }
}