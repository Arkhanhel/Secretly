// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

class CallSignalCommandCodec {
  const CallSignalCommandCodec._();

  static const String prefix = '__secretly_call_cmd_v1__:';
  static const String signalIdKey = 'signalId';

  static bool isEncodedText(String text) {
    return text.trim().startsWith(prefix);
  }

  static Map<String, Object?> normalizeOutgoingPayload(
    Map<String, Object?> payload, {
    required String fallbackSignalId,
    required int createdAtMs,
  }) {
    final normalized = <String, Object?>{...payload};
    final action = (normalized['action'] as String?)?.trim().toLowerCase() ?? '';
    final callId = (normalized['callId'] as String?)?.trim() ?? '';
    final callAttemptId =
        ((normalized['callAttemptId'] as String?) ??
                (normalized['call_attempt_id'] as String?) ??
                callId)
            .trim();
    final signalId =
        (normalized[signalIdKey] as String?)?.trim() ?? fallbackSignalId;
    final rawCreatedAtMs = normalized['createdAtMs'];
    final effectiveCreatedAtMs = rawCreatedAtMs is num
        ? rawCreatedAtMs.toInt()
        : createdAtMs;

    if (action.isNotEmpty) {
      normalized['action'] = action;
    }
    if (callId.isNotEmpty) {
      normalized['callId'] = callId;
    }
    if (callAttemptId.isNotEmpty) {
      normalized['callAttemptId'] = callAttemptId;
    }
    normalized[signalIdKey] = signalId.isEmpty ? fallbackSignalId : signalId;
    normalized['createdAtMs'] = effectiveCreatedAtMs > 0
        ? effectiveCreatedAtMs
        : createdAtMs;
    return normalized;
  }

  static String encode(Map<String, Object?> payload) {
    return '$prefix${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
  }

  static Map<String, Object?>? decode(String text) {
    if (!isEncodedText(text)) return null;
    final raw = text.trim().substring(prefix.length).trim();
    if (raw.isEmpty) return null;
    try {
      final decoded = utf8.decode(base64Url.decode(raw));
      final jsonObj = jsonDecode(decoded);
      if (jsonObj is Map<String, dynamic>) {
        return Map<String, Object?>.from(jsonObj);
      }
      if (jsonObj is Map) {
        return jsonObj.cast<String, Object?>();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static String resolveSignalId(Map<String, Object?> payload) {
    return (payload[signalIdKey] as String?)?.trim() ?? '';
  }

  static String resolveInboundSignalId(
    Map<String, Object?> payload, {
    String? senderProfileId,
    String? senderDeviceId,
  }) {
    final signalId = resolveSignalId(payload);
    if (signalId.isNotEmpty) return signalId;

    final action = (payload['action'] as String?)?.trim().toLowerCase() ?? '';
    final callId = (payload['callId'] as String?)?.trim() ?? '';
    final callAttemptId =
        ((payload['callAttemptId'] as String?) ??
                (payload['call_attempt_id'] as String?) ??
                callId)
            .trim();
    final createdAtMs = payload['createdAtMs'];
    final createdPart = createdAtMs is num ? createdAtMs.toInt().toString() : '';
    final fromProfileId = (senderProfileId ?? '').trim();
    final fromDeviceId = (senderDeviceId ?? '').trim();
    if (action.isEmpty || callId.isEmpty || createdPart.isEmpty) {
      return '';
    }

    return <String>[
      'legacy',
      fromProfileId,
      fromDeviceId,
      callId,
      callAttemptId,
      action,
      createdPart,
    ].join(':');
  }
}