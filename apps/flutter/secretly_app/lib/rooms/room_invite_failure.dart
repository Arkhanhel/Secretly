// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
enum RoomInviteFailureCode {
  invalidLink,
  inviteNotFound,
  inviteRevoked,
  inviteExpired,
  inviteUsageLimitReached,
  inviteCreatorUnavailable,
  banned,
  previewTimedOut,
  joinTimedOut,
  generic,
}

class RoomInviteFailure implements Exception {
  const RoomInviteFailure(this.code, {this.message});

  final RoomInviteFailureCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}
