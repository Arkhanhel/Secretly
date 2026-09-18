// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

class RoomCallSyncTransportMeta {
  RoomCallSyncTransportMeta._();

  static const String transportMetaKind = 'room_call_sync_v1';

  static String buildTransportMetaJson({
    required String roomId,
    String? callId,
    required int stateVersion,
    required bool callExists,
    required int createdAtMs,
  }) {
    final cleanedRoomId = roomId.trim();
    final cleanedCallId = (callId ?? '').trim();
    return jsonEncode(<String, Object?>{
      'kind': transportMetaKind,
      'room_call': <String, Object?>{
        'room_id': cleanedRoomId,
        'call_exists': callExists,
        if (cleanedCallId.isNotEmpty) 'call_id': cleanedCallId,
        'state_version': stateVersion < 0 ? 0 : stateVersion,
        'created_at_ms': createdAtMs < 0 ? 0 : createdAtMs,
      },
    });
  }
}