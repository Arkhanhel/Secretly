// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';

import '../transport/relay_client.dart';

enum RoomCallRuntimePhase { idle, bootstrapping, bootstrapReady, failed }

enum RoomCallLocalMediaPhase { idle, acquiring, ready, failed }

enum RoomCallParticipantRuntimeKind {
  none,
  audioOnly,
  localPreview,
  localScreenSharePreview,
  remoteVideo,
  remoteScreenShare,
  awaitingRemoteVideo,
  awaitingRemoteScreenShare,
  reconnecting,
  failed,
}

@immutable
class RoomCallLocalMediaState {
  const RoomCallLocalMediaState({
    required this.phase,
    required this.audioCaptureActive,
    required this.videoCaptureActive,
    required this.screenShareActive,
    required this.localPreviewAvailable,
    required this.speakerEnabled,
    required this.usingFrontCamera,
    required this.runtimeConnected,
    required this.runtimeReconnecting,
    required this.runtimeRevision,
    required this.errorMessage,
    this.speakingRevision = 0,
  });

  const RoomCallLocalMediaState.idle({
    this.speakerEnabled = true,
    this.usingFrontCamera = true,
  }) : phase = RoomCallLocalMediaPhase.idle,
       audioCaptureActive = false,
       videoCaptureActive = false,
       screenShareActive = false,
       localPreviewAvailable = false,
       runtimeConnected = false,
       runtimeReconnecting = false,
       runtimeRevision = 0,
       speakingRevision = 0,
       errorMessage = null;

  final RoomCallLocalMediaPhase phase;
  final bool audioCaptureActive;
  final bool videoCaptureActive;
  final bool screenShareActive;
  final bool localPreviewAvailable;
  final bool speakerEnabled;
  final bool usingFrontCamera;
  final bool runtimeConnected;
  final bool runtimeReconnecting;
  final int runtimeRevision;

  /// Bumped when the active-speaker set changes. Kept SEPARATE from
  /// [runtimeRevision] on purpose: speaking flips several times a minute and
  /// must re-emit state (so the UI can repaint the green highlight) without
  /// looking like a track/binding change — consumers key expensive work
  /// (audio-route re-apply, video view rebuilds) off [runtimeRevision] only.
  final int speakingRevision;
  final String? errorMessage;

  bool get hasRenderablePreview =>
      localPreviewAvailable && (videoCaptureActive || screenShareActive);

  RoomCallLocalMediaState copyWith({
    RoomCallLocalMediaPhase? phase,
    bool? audioCaptureActive,
    bool? videoCaptureActive,
    bool? screenShareActive,
    bool? localPreviewAvailable,
    bool? speakerEnabled,
    bool? usingFrontCamera,
    bool? runtimeConnected,
    bool? runtimeReconnecting,
    int? runtimeRevision,
    int? speakingRevision,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RoomCallLocalMediaState(
      phase: phase ?? this.phase,
      audioCaptureActive: audioCaptureActive ?? this.audioCaptureActive,
      videoCaptureActive: videoCaptureActive ?? this.videoCaptureActive,
      screenShareActive: screenShareActive ?? this.screenShareActive,
      localPreviewAvailable:
          localPreviewAvailable ?? this.localPreviewAvailable,
      speakerEnabled: speakerEnabled ?? this.speakerEnabled,
      usingFrontCamera: usingFrontCamera ?? this.usingFrontCamera,
      runtimeConnected: runtimeConnected ?? this.runtimeConnected,
      runtimeReconnecting: runtimeReconnecting ?? this.runtimeReconnecting,
      runtimeRevision: runtimeRevision ?? this.runtimeRevision,
      speakingRevision: speakingRevision ?? this.speakingRevision,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

@immutable
class RoomCallParticipantRuntimeState {
  const RoomCallParticipantRuntimeState({
    required this.profileId,
    required this.deviceId,
    required this.joinState,
    required this.isSelf,
    required this.publishAudio,
    required this.publishVideo,
    required this.publishScreenShare,
    required this.receiveAudio,
    required this.receiveVideo,
    required this.receiveScreenShare,
    required this.kind,
    required this.errorMessage,
    required this.updatedAtMs,
    this.speaking = false,
  });

  final String profileId;
  final String deviceId;
  final String joinState;
  final bool isSelf;
  final bool publishAudio;
  final bool publishVideo;
  final bool publishScreenShare;
  final bool receiveAudio;
  final bool receiveVideo;
  final bool receiveScreenShare;
  final RoomCallParticipantRuntimeKind kind;
  final String? errorMessage;
  final int updatedAtMs;

  /// Live voice-activity flag sourced from the media runtime (LiveKit active
  /// speakers) — NOT from relay snapshots, which have no VAD signal.
  final bool speaking;

  bool get isJoined => joinState == 'joined' || joinState == 'reconnecting';
  bool get isReconnecting => joinState == 'reconnecting';
}

class RoomCallRuntimeState {
  const RoomCallRuntimeState({
    required this.phase,
    required this.roomId,
    required this.callId,
    required this.stateVersion,
    required this.lastSyncedAtMs,
    required this.session,
    required this.localMedia,
    required this.participants,
    required this.errorMessage,
  });

  const RoomCallRuntimeState.idle()
    : phase = RoomCallRuntimePhase.idle,
      roomId = '',
      callId = '',
      stateVersion = 0,
      lastSyncedAtMs = 0,
      session = null,
      localMedia = const RoomCallLocalMediaState.idle(),
      participants = const <RoomCallParticipantRuntimeState>[],
      errorMessage = null;

  final RoomCallRuntimePhase phase;
  final String roomId;
  final String callId;
  final int stateVersion;
  final int lastSyncedAtMs;
  final RelayRoomCallMediaSession? session;
  final RoomCallLocalMediaState localMedia;
  final List<RoomCallParticipantRuntimeState> participants;
  final String? errorMessage;

  bool get hasActiveSession => phase != RoomCallRuntimePhase.idle;

  bool matches({required String roomId, required String callId}) {
    return this.roomId == roomId.trim() && this.callId == callId.trim();
  }

  RoomCallRuntimeState copyWith({
    RoomCallRuntimePhase? phase,
    String? roomId,
    String? callId,
    int? stateVersion,
    int? lastSyncedAtMs,
    RelayRoomCallMediaSession? session,
    bool clearSession = false,
    RoomCallLocalMediaState? localMedia,
    List<RoomCallParticipantRuntimeState>? participants,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RoomCallRuntimeState(
      phase: phase ?? this.phase,
      roomId: roomId ?? this.roomId,
      callId: callId ?? this.callId,
      stateVersion: stateVersion ?? this.stateVersion,
      lastSyncedAtMs: lastSyncedAtMs ?? this.lastSyncedAtMs,
      session: clearSession ? null : (session ?? this.session),
      localMedia: localMedia ?? this.localMedia,
      participants: participants ?? this.participants,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
