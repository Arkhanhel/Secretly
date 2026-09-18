// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'call_failure.dart';
import 'call_event.dart';
import 'call_state.dart';

class CallQualitySummary {
  const CallQualitySummary({
    required this.rttMs,
    required this.jitterMs,
    required this.packetLossPct,
    required this.qualityLevel,
  });

  final double? rttMs;
  final double? jitterMs;
  final double? packetLossPct;
  final String? qualityLevel;

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  factory CallQualitySummary.fromJsonMap(Map<String, Object?> json) {
    return CallQualitySummary(
      rttMs: _readDouble(json['rtt_ms']),
      jitterMs: _readDouble(json['jitter_ms']),
      packetLossPct: _readDouble(json['packet_loss_pct']),
      qualityLevel: (json['quality_level'] as String?)?.trim(),
    );
  }

  static CallQualitySummary? decode(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    try {
      final json = jsonDecode(text);
      if (json is Map<String, dynamic>) {
        return CallQualitySummary.fromJsonMap(
          json.map((key, value) => MapEntry(key, value)),
        );
      }
      if (json is Map) {
        return CallQualitySummary.fromJsonMap(
          json.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String encode() {
    return jsonEncode({
      'rtt_ms': rttMs,
      'jitter_ms': jitterMs,
      'packet_loss_pct': packetLossPct,
      'quality_level': qualityLevel,
    });
  }
}

class CallRecordDraft {
  const CallRecordDraft({
    required this.callId,
    required this.callAttemptId,
    required this.convoId,
    required this.peerProfileId,
    required this.peerDisplayName,
    required this.peerAvatarPath,
    required this.direction,
    required this.isVideo,
    required this.hadScreenShare,
    required this.startedAtMs,
    required this.connectedAtMs,
    required this.endedAtMs,
    required this.endReason,
    this.failureCode,
    required this.qualitySummary,
  });

  final String callId;
  final String callAttemptId;
  final String convoId;
  final String peerProfileId;
  final String peerDisplayName;
  final String? peerAvatarPath;
  final CallRecordDirection direction;
  final bool isVideo;
  final bool hadScreenShare;
  final int startedAtMs;
  final int? connectedAtMs;
  final int endedAtMs;
  final CallEndReason endReason;
  final CallFailureCode? failureCode;
  final CallQualitySummary? qualitySummary;

  bool get didConnect => connectedAtMs != null && connectedAtMs! > 0;

  int get durationMs {
    final start = connectedAtMs ?? startedAtMs;
    final delta = endedAtMs - start;
    return delta > 0 ? delta : 0;
  }

  CallRecordResult get result => callRecordResultFromEndReason(
    reason: endReason,
    didConnect: didConnect,
    direction: direction,
  );

  CallJournalEntry toJournalEntry({
    String? createdLocalEventId,
    String? syncedChatEventId,
  }) {
    return CallJournalEntry(
      callId: callId,
      callAttemptId: callAttemptId,
      convoId: convoId,
      peerProfileId: peerProfileId,
      direction: direction,
      scope: CallRecordScope.oneToOne,
      mediaType: callRecordMediaTypeFromFlags(
        isVideo: isVideo,
        hadScreenShare: hadScreenShare,
      ),
      result: result,
      startedAtMs: startedAtMs,
      connectedAtMs: connectedAtMs,
      endedAtMs: endedAtMs,
      durationMs: durationMs,
      endReason: endReason.name,
      failureCode: failureCode,
      peerDisplayName: peerDisplayName,
      peerAvatarPath: peerAvatarPath,
      didConnect: didConnect,
      hadVideo: isVideo,
      hadScreenShare: hadScreenShare,
      qualitySummaryJson: qualitySummary?.encode(),
      createdLocalEventId: createdLocalEventId,
      syncedChatEventId: syncedChatEventId,
      acknowledgedAtMs: null,
    );
  }
}
