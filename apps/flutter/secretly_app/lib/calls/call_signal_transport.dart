// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

class CallSignalDeliveryPolicy {
  const CallSignalDeliveryPolicy({
    required this.name,
    required this.priority,
    required this.strictQueueing,
    required this.forceRelayFlush,
    required this.relayFlushTimeoutMs,
    required this.maxQueueAttempts,
    required this.transportHint,
    required this.retryBucket,
    required this.isCritical,
  });

  final String name;
  final int priority;
  final bool strictQueueing;
  final bool forceRelayFlush;
  final int relayFlushTimeoutMs;
  final int maxQueueAttempts;
  final String transportHint;
  final String retryBucket;
  final bool isCritical;

  static const CallSignalDeliveryPolicy critical = CallSignalDeliveryPolicy(
    name: 'critical',
    priority: 100,
    strictQueueing: true,
    forceRelayFlush: true,
    relayFlushTimeoutMs: 1200,
    maxQueueAttempts: 4,
    transportHint: 'call_signal',
    retryBucket: 'call_critical',
    isCritical: true,
  );

  static const CallSignalDeliveryPolicy ice = CallSignalDeliveryPolicy(
    name: 'ice',
    priority: 95,
    strictQueueing: true,
    forceRelayFlush: true,
    relayFlushTimeoutMs: 1500,
    maxQueueAttempts: 4,
    transportHint: 'call_signal',
    retryBucket: 'call_critical',
    isCritical: true,
  );

  static const CallSignalDeliveryPolicy recoveryIce = CallSignalDeliveryPolicy(
    name: 'recovery_ice',
    priority: 90,
    strictQueueing: true,
    forceRelayFlush: true,
    relayFlushTimeoutMs: 900,
    maxQueueAttempts: 4,
    transportHint: 'call_ice_recovery',
    retryBucket: 'call_ice_recovery',
    isCritical: true,
  );

  static const String transportMetaKind = 'call_signal_v1';

  static CallSignalDeliveryPolicy forAction(
    String action, {
    bool recovery = false,
  }) {
    switch (action.trim().toLowerCase()) {
      case 'ice':
        return recovery ? recoveryIce : ice;
      case 'invite':
      case 'decline':
      case 'hangup':
      case 'offer':
      case 'answer':
      case 'need_offer':
      default:
        return critical;
    }
  }

  static String buildTransportMetaJson({
    required String action,
    required String callId,
    required String callAttemptId,
    required String signalId,
    required int createdAtMs,
    String deliveryMode = 'normal',
    String? callerProfileId,
    String? callerDisplayName,
    bool? isVideo,
    String? convoId,
  }) {
    final cleanedSignalId = signalId.trim();
    if (cleanedSignalId.isEmpty) {
      throw ArgumentError.value(signalId, 'signalId', 'must not be empty');
    }
    final cleanedCallerProfileId = (callerProfileId ?? '').trim();
    final cleanedCallerDisplayName = (callerDisplayName ?? '').trim();
    final cleanedConvoId = (convoId ?? '').trim();
    return jsonEncode(<String, Object?>{
      'kind': transportMetaKind,
      'call': <String, Object?>{
        'action': action.trim().toLowerCase(),
        'call_id': callId.trim(),
        'call_attempt_id': callAttemptId.trim(),
        'signal_id': cleanedSignalId,
        'created_at_ms': createdAtMs,
        'delivery_mode': deliveryMode.trim().isEmpty
            ? 'normal'
            : deliveryMode.trim().toLowerCase(),
        if (cleanedCallerProfileId.isNotEmpty)
          'caller_profile_id': cleanedCallerProfileId,
        if (cleanedCallerDisplayName.isNotEmpty)
          'caller_display_name': cleanedCallerDisplayName,
        if (isVideo != null) 'is_video': isVideo,
        if (cleanedConvoId.isNotEmpty) 'convo_id': cleanedConvoId,
      },
    });
  }
}
