// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
enum RoomMembershipFailureCode {
  ownerOnly,
  ownerTransferRequired,
  ownerTransferTargetInvalid,
  memberBanned,
  cannotRemoveOwner,
  cannotBanOwner,
  generic,
}

class RoomMembershipFailure implements Exception {
  RoomMembershipFailure(this.code, {String? message, this.cause})
    : message = message ?? _defaultRoomMembershipFailureMessage(code);

  final RoomMembershipFailureCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

String _defaultRoomMembershipFailureMessage(
  RoomMembershipFailureCode code,
) {
  switch (code) {
    case RoomMembershipFailureCode.ownerOnly:
      return 'Only the room owner can do that.';
    case RoomMembershipFailureCode.ownerTransferRequired:
      return 'Transfer room ownership before leaving this room.';
    case RoomMembershipFailureCode.ownerTransferTargetInvalid:
      return 'Choose an active room member as the next owner.';
    case RoomMembershipFailureCode.memberBanned:
      return 'This member is banned and must be unbanned before they can rejoin.';
    case RoomMembershipFailureCode.cannotRemoveOwner:
      return 'The room owner cannot be removed.';
    case RoomMembershipFailureCode.cannotBanOwner:
      return 'The room owner cannot be banned.';
    case RoomMembershipFailureCode.generic:
      return 'This room membership action is unavailable right now.';
  }
}
