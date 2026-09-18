// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'call_failure.dart';
import 'call_state_machine.dart';

/// Call state machine — single source of truth for call lifecycle.
///
/// Transitions:
///   idle → ringingOutgoing   (user taps call)
///   idle → ringingIncoming   (invite received)
///   ringingOutgoing → connecting  (remote answered)
///   ringingIncoming → connecting  (user accepted)
///   connecting → connected       (ICE connected)
///   connected → reconnecting     (ICE disconnected/failed, auto-retry)
///   reconnecting → connected     (ICE recovered)
///   any → ended                  (hangup / decline / error / timeout)
enum CallPhase {
  idle,
  ringingOutgoing,
  ringingIncoming,
  connecting,
  connected,
  reconnecting,
  ended,
}

enum CallEndReason {
  localHangup,
  remoteHangup,
  remoteSuperseded,
  remoteDecline,
  timeout,
  error,
  localDecline,
}

CallEndReason? parseCallEndReason(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return null;
  for (final value in CallEndReason.values) {
    if (value.name == text) {
      return value;
    }
  }
  return null;
}

enum CallDirection { incoming, outgoing }

class CallState {
  CallState({
    this.lifecycle = CallLifecycleState.idle,
    this.phase = CallPhase.idle,
    this.callId = '',
    this.peerProfileId = '',
    this.peerName = '',
    this.peerAvatarPath,
    this.callAttemptId = '',
    this.direction = CallDirection.outgoing,
    this.startedAtMs,
    this.isVideo = false,
    this.isMuted = false,
    this.isSpeaker = false,
    this.isCameraOff = false,
    this.isFrontCamera = true,
    this.isScreenSharing = false,
    this.isUiMinimized = false,
    this.connectedAtMs,
    this.endReason,
    this.failure,
  });

  final CallLifecycleState lifecycle;
  final CallPhase phase;
  final String callId;
  final String peerProfileId;
  final String peerName;
  final String? peerAvatarPath;
  final String callAttemptId;
  final CallDirection direction;
  final int? startedAtMs;
  final bool isVideo;
  final bool isMuted;
  final bool isSpeaker;
  final bool isCameraOff;
  final bool isFrontCamera;
  final bool isScreenSharing;
  final bool isUiMinimized;
  final int? connectedAtMs;
  final CallEndReason? endReason;
  final CallFailure? failure;

  bool get isActive =>
      phase == CallPhase.ringingOutgoing ||
      phase == CallPhase.ringingIncoming ||
      phase == CallPhase.connecting ||
      phase == CallPhase.connected ||
      phase == CallPhase.reconnecting;

  bool get isRinging =>
      phase == CallPhase.ringingOutgoing || phase == CallPhase.ringingIncoming;

  CallState copyWith({
    CallLifecycleState? lifecycle,
    CallPhase? phase,
    String? callId,
    String? peerProfileId,
    String? peerName,
    String? peerAvatarPath,
    String? callAttemptId,
    CallDirection? direction,
    int? startedAtMs,
    bool? isVideo,
    bool? isMuted,
    bool? isSpeaker,
    bool? isCameraOff,
    bool? isFrontCamera,
    bool? isScreenSharing,
    bool? isUiMinimized,
    int? connectedAtMs,
    CallEndReason? endReason,
    CallFailure? failure,
    bool clearFailure = false,
  }) {
    return CallState(
      lifecycle: lifecycle ?? this.lifecycle,
      phase: phase ?? this.phase,
      callId: callId ?? this.callId,
      peerProfileId: peerProfileId ?? this.peerProfileId,
      peerName: peerName ?? this.peerName,
      peerAvatarPath: peerAvatarPath ?? this.peerAvatarPath,
      callAttemptId: callAttemptId ?? this.callAttemptId,
      direction: direction ?? this.direction,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      isVideo: isVideo ?? this.isVideo,
      isMuted: isMuted ?? this.isMuted,
      isSpeaker: isSpeaker ?? this.isSpeaker,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      isUiMinimized: isUiMinimized ?? this.isUiMinimized,
      connectedAtMs: connectedAtMs ?? this.connectedAtMs,
      endReason: endReason ?? this.endReason,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  static CallState get empty => CallState();
}

CallPhase callPhaseForLifecycle(CallLifecycleState lifecycle) {
  switch (lifecycle) {
    case CallLifecycleState.idle:
      return CallPhase.idle;
    case CallLifecycleState.outgoingInviting:
    case CallLifecycleState.offerNegotiation:
      return CallPhase.ringingOutgoing;
    case CallLifecycleState.incomingRinging:
      return CallPhase.ringingIncoming;
    case CallLifecycleState.accepting:
    case CallLifecycleState.answerNegotiation:
    case CallLifecycleState.connectingMedia:
      return CallPhase.connecting;
    case CallLifecycleState.connected:
      return CallPhase.connected;
    case CallLifecycleState.reconnecting:
      return CallPhase.reconnecting;
    case CallLifecycleState.ending:
    case CallLifecycleState.ended:
      return CallPhase.ended;
  }
}
