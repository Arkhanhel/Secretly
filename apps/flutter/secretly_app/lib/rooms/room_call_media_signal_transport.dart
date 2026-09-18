// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

class RoomCallMediaSignalDeliveryPolicy {
  const RoomCallMediaSignalDeliveryPolicy({
    required this.name,
    required this.priority,
    required this.strictQueueing,
    required this.forceRelayFlush,
    required this.maxQueueAttempts,
    required this.transportHint,
    required this.retryBucket,
  });

  final String name;
  final int priority;
  final bool strictQueueing;
  final bool forceRelayFlush;
  final int maxQueueAttempts;
  final String transportHint;
  final String retryBucket;

  static const RoomCallMediaSignalDeliveryPolicy descriptorHint =
      RoomCallMediaSignalDeliveryPolicy(
        name: 'descriptor_hint',
        priority: 70,
        strictQueueing: false,
        forceRelayFlush: false,
        maxQueueAttempts: 2,
        transportHint: 'room_call_media_signal',
        retryBucket: 'room_call_media_signal',
      );

  static const String transportMetaKind = 'room_call_media_signal_v1';

  static RoomCallMediaSignalDeliveryPolicy forAction(String action) {
    switch (action.trim().toLowerCase()) {
      case 'descriptor_updated':
      default:
        return descriptorHint;
    }
  }

  static String buildTransportMetaJson({
    required String action,
    required String roomId,
    required String callId,
    required String sessionId,
    required int descriptorVersion,
    required int stateVersion,
    required String signalId,
    required int createdAtMs,
  }) {
    return jsonEncode(<String, Object?>{
      'kind': transportMetaKind,
      'room_media_signal': <String, Object?>{
        'action': action.trim().toLowerCase(),
        'room_id': roomId.trim(),
        'call_id': callId.trim(),
        'session_id': sessionId.trim(),
        'descriptor_version': descriptorVersion < 0 ? 0 : descriptorVersion,
        'state_version': stateVersion < 0 ? 0 : stateVersion,
        'signal_id': signalId.trim(),
        'created_at_ms': createdAtMs < 0 ? 0 : createdAtMs,
      },
    });
  }
}