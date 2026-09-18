// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../app/app_controller.dart';
import '../calls/call_audio_route.dart';
import '../calls/call_log.dart';
import '../transport/relay_client.dart';
import 'room_call_media_controller.dart';
import 'room_call_media_state.dart';
import 'room_call_state.dart';

class RoomCallManager {
  RoomCallManager({
    required this.controller,
    RoomCallMediaControllerFactory? mediaControllerFactory,
  }) : mediaControllerFactory =
           mediaControllerFactory ??
           const DefaultRoomCallMediaControllerFactory() {
    _audioRouteController.state.addListener(_handleAudioRouteStateChanged);
  }

  static const Duration _mediaRefreshInterval = Duration(seconds: 5);

  final AppController controller;
  final RoomCallMediaControllerFactory mediaControllerFactory;

  static RoomCallManager? instance;

  final ValueNotifier<RoomCallRuntimeState> state = ValueNotifier(
    const RoomCallRuntimeState.idle(),
  );
  final CallAudioRouteController _audioRouteController =
      CallAudioRouteController(logTag: 'RoomAudio');

  StreamSubscription<void>? _changedSub;
  StreamSubscription<bool>? _relayConnectionSub;
  StreamSubscription<RoomCallMediaSignalEvent>? _roomMediaSignalSub;
  Timer? _syncDebounceTimer;
  Timer? _mediaRefreshTimer;
  Future<void>? _syncInFlight;
  Future<void>? _mediaRefreshInFlight;
  bool _started = false;
  RoomCallMediaController? _mediaController;
  String _mediaControllerKey = '';

  // AUD-025 (rooms variant): serialize room media signal processing to
  // prevent reordering between buffered-replay and live-stream paths.
  Future<void> _roomSignalProcessingChain = Future<void>.value();
  final Set<String> _processedRoomSignalIds = <String>{};
  static const int _processedRoomSignalIdCapacity = 512;

  RelayRoomCallMediaSession? get session => state.value.session;
  RoomCallMediaController? get mediaController => _mediaController;
  ValueListenable<CallAudioRouteState> get audioRouteState =>
      _audioRouteController.state;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _changedSub = controller.changed.listen((_) {
      _scheduleSyncFromController();
    });
    _roomMediaSignalSub = controller.roomCallMediaSignals.listen(
      _enqueueRoomMediaSignal,
    );
    _relayConnectionSub = controller.relayConnectionChanges.listen((connected) {
      if (connected) {
        unawaited(refreshCurrent(forceRefresh: true));
      }
    });
    unawaited(() async {
      await _restorePrimaryJoinedRoomCall();
      _drainBufferedRoomMediaSignals();
    }());
  }

  void onAppLifecycleStateChanged(AppLifecycleState appState) {
    if (appState != AppLifecycleState.resumed) {
      return;
    }
    unawaited(refreshCurrent(forceRefresh: true));
  }

  Future<void> dispose() async {
    _syncDebounceTimer?.cancel();
    _mediaRefreshTimer?.cancel();
    await _changedSub?.cancel();
    await _roomMediaSignalSub?.cancel();
    await _relayConnectionSub?.cancel();
    await _disposeMediaController();
    _audioRouteController.state.removeListener(_handleAudioRouteStateChanged);
    await _audioRouteController.dispose();
    state.dispose();
    if (identical(instance, this)) {
      instance = null;
    }
  }

  @visibleForTesting
  Future<void> restorePrimaryJoinedRoomCallForTesting() {
    return _restorePrimaryJoinedRoomCall();
  }

  @visibleForTesting
  Future<void> refreshMediaSessionFromRelayForTesting() {
    return _refreshMediaSessionFromRelay();
  }

  Future<void> ensureJoined({
    required String roomId,
    required String callId,
    bool forceRefresh = false,
  }) async {
    final cleanedRoomId = roomId.trim();
    final cleanedCallId = callId.trim();
    if (cleanedRoomId.isEmpty || cleanedCallId.isEmpty) {
      return;
    }
    final cached = await controller.getCachedRoomCall(cleanedRoomId);
    if (cached == null || !cached.isActive || cached.callId != cleanedCallId) {
      await clearIfMatches(roomId: cleanedRoomId, callId: cleanedCallId);
      return;
    }
    await _bootstrapFromCachedCall(cached, forceRefresh: forceRefresh);
  }

  Future<void> refreshCurrent({bool forceRefresh = false}) async {
    final current = state.value;
    if (!current.hasActiveSession) {
      await _restorePrimaryJoinedRoomCall();
      return;
    }
    final cached = await controller.getCachedRoomCall(current.roomId);
    if (cached == null ||
        !cached.isActive ||
        cached.callId != current.callId ||
        !(cached.selfParticipant?.isJoined ?? false)) {
      _setState(const RoomCallRuntimeState.idle());
      await _restorePrimaryJoinedRoomCall();
      return;
    }
    await _bootstrapFromCachedCall(cached, forceRefresh: forceRefresh);
  }

  Future<void> clearIfMatches({required String roomId, String? callId}) async {
    final current = state.value;
    final cleanedRoomId = roomId.trim();
    final cleanedCallId = (callId ?? '').trim();
    if (current.roomId != cleanedRoomId) {
      return;
    }
    if (cleanedCallId.isNotEmpty && current.callId != cleanedCallId) {
      return;
    }
    await _disposeMediaController();
    _setState(const RoomCallRuntimeState.idle());
  }

  Future<void> setSpeakerEnabled(bool enabled) async {
    final current = state.value;
    if (current.hasActiveSession) {
      final routeState = _audioRouteController.state.value;
      final targetRoute = enabled
          ? routeState.speakerRoute
          : routeState.preferredPrivateRoute;
      if (targetRoute != null) {
        await selectAudioRoute(targetRoute.deviceId);
        return;
      }
    }
    await _mediaController?.setSpeakerEnabled(enabled);
    _applyMediaControllerState();
  }

  Future<void> selectAudioRoute(String routeId) async {
    final current = state.value;
    if (!current.hasActiveSession) {
      return;
    }
    await _audioRouteController.selectRoute(
      routeId: routeId,
      preferSpeakerByDefault: _shouldPreferSpeakerByDefault(current),
      reason: 'room_ui_route_select',
    );
    final selectedRoute = _audioRouteController.state.value.selectedRoute;
    await _mediaController?.setSpeakerEnabled(
      selectedRoute?.isSpeaker ?? false,
    );
    _applyMediaControllerState();
    await _syncAudioRoutesForCurrentRoom(
      reason: 'room_ui_route_reapply',
      reapplyCurrentRoute: true,
    );
  }

  Future<void> switchCamera() async {
    await _mediaController?.switchCamera();
    _applyMediaControllerState();
  }

  void _handleAudioRouteStateChanged() {
    final current = state.value;
    if (!current.hasActiveSession) {
      return;
    }
    final isSpeakerSelected =
        _audioRouteController.state.value.isSpeakerSelected;
    if (current.localMedia.speakerEnabled == isSpeakerSelected) {
      return;
    }
    state.value = current.copyWith(
      localMedia: current.localMedia.copyWith(
        speakerEnabled: isSpeakerSelected,
      ),
    );
    final controller = _mediaController;
    if (controller == null) {
      return;
    }
    unawaited(() async {
      try {
        await controller.setSpeakerEnabled(isSpeakerSelected);
        _applyMediaControllerState();
      } catch (e, stack) {
        callLog('RoomCallMgr', 'room audio route sync failed: $e\n$stack');
      }
    }());
  }

  void _drainBufferedRoomMediaSignals() {
    final buffered = controller.drainRoomCallMediaSignalBuffer();
    if (buffered.isEmpty) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final signal in buffered) {
      if ((nowMs - signal.createdAtMs) > 60000) {
        continue;
      }
      _enqueueRoomMediaSignal(signal);
    }
  }

  // AUD-025 (rooms variant): single serialized entry point. Dedup by
  // signalId so buffered replay cannot double-process signals that the live
  // subscription has already delivered.
  void _enqueueRoomMediaSignal(RoomCallMediaSignalEvent event) {
    final id = event.signalId.trim();
    if (id.isNotEmpty) {
      if (_processedRoomSignalIds.contains(id)) {
        return;
      }
      _processedRoomSignalIds.add(id);
      if (_processedRoomSignalIds.length > _processedRoomSignalIdCapacity) {
        _processedRoomSignalIds.remove(_processedRoomSignalIds.first);
      }
    }
    _roomSignalProcessingChain = _roomSignalProcessingChain
        .then((_) async => _onRoomMediaSignal(event))
        .catchError((_) {});
  }

  void _onRoomMediaSignal(RoomCallMediaSignalEvent event) {
    final current = state.value;
    final senderDeviceId = (event.fromDeviceId ?? '').trim();
    if (senderDeviceId.isNotEmpty &&
        senderDeviceId == controller.deviceId.trim()) {
      return;
    }
    if (!current.hasActiveSession) {
      unawaited(
        ensureJoined(
          roomId: event.roomId,
          callId: event.callId,
          forceRefresh: true,
        ),
      );
      return;
    }
    if (!current.matches(roomId: event.roomId, callId: event.callId)) {
      return;
    }
    final session = current.session;
    if (session == null) {
      return;
    }
    final sessionChanged =
        event.sessionId.trim().isNotEmpty &&
        event.sessionId.trim() != session.sessionId.trim();
    final descriptorAdvanced =
        event.descriptorVersion > session.descriptorVersion;
    final stateAdvanced = event.stateVersion > session.stateVersion;
    if (!sessionChanged && !descriptorAdvanced && !stateAdvanced) {
      return;
    }

    callLog(
      'RoomCallMgr',
      'room media signal refresh roomId=${event.roomId} callId=${event.callId} reason=${event.reason} descriptorVersion=${event.descriptorVersion}',
    );

    if (current.phase == RoomCallRuntimePhase.bootstrapReady) {
      unawaited(_refreshMediaSessionFromRelay());
      return;
    }
    unawaited(refreshCurrent(forceRefresh: true));
  }

  void _scheduleSyncFromController() {
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(const Duration(milliseconds: 180), () {
      unawaited(_syncCurrentFromController());
    });
  }

  Future<void> _syncCurrentFromController() async {
    final current = state.value;
    if (!current.hasActiveSession) {
      await _restorePrimaryJoinedRoomCall();
      return;
    }
    final cached = await controller.getCachedRoomCall(current.roomId);
    if (cached == null ||
        !cached.isActive ||
        cached.callId != current.callId ||
        !(cached.selfParticipant?.isJoined ?? false)) {
      _setState(const RoomCallRuntimeState.idle());
      await _restorePrimaryJoinedRoomCall();
      return;
    }
    final shouldRefresh =
        current.phase == RoomCallRuntimePhase.failed ||
        cached.stateVersion > current.stateVersion;
    if (shouldRefresh) {
      await _bootstrapFromCachedCall(cached, forceRefresh: true);
    }
  }

  Future<void> _restorePrimaryJoinedRoomCall() async {
    if (state.value.hasActiveSession) {
      return;
    }
    final cached = await controller.getPrimarySelfJoinedCachedRoomCall();
    if (cached == null || !cached.isActive) {
      return;
    }
    await _bootstrapFromCachedCall(cached);
  }

  Future<void> _bootstrapFromCachedCall(
    CachedRoomCall cached, {
    bool forceRefresh = false,
  }) async {
    final roomId = cached.roomId.trim();
    final callId = cached.callId.trim();
    final selfParticipant = cached.selfParticipant;
    if (roomId.isEmpty || callId.isEmpty) {
      return;
    }
    if (selfParticipant == null || !selfParticipant.isJoined) {
      if (state.value.matches(roomId: roomId, callId: callId)) {
        _setState(const RoomCallRuntimeState.idle());
      }
      return;
    }
    final current = state.value;
    final reuseCurrentRuntime = current.matches(roomId: roomId, callId: callId);
    if (!forceRefresh &&
        current.phase == RoomCallRuntimePhase.bootstrapReady &&
        current.matches(roomId: roomId, callId: callId) &&
        current.stateVersion >= cached.stateVersion) {
      return;
    }
    if (_syncInFlight != null) {
      await _syncInFlight;
      return;
    }

    if (!reuseCurrentRuntime) {
      await _disposeMediaController();
    }

    final preservedSession = reuseCurrentRuntime ? current.session : null;
    final preservedLocalMedia = reuseCurrentRuntime
        ? current.localMedia
        : const RoomCallLocalMediaState.idle();
    final preservedParticipants = reuseCurrentRuntime
        ? current.participants
        : const <RoomCallParticipantRuntimeState>[];

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _setState(
      RoomCallRuntimeState(
        phase: RoomCallRuntimePhase.bootstrapping,
        roomId: roomId,
        callId: callId,
        stateVersion: cached.stateVersion,
        lastSyncedAtMs: current.matches(roomId: roomId, callId: callId)
            ? current.lastSyncedAtMs
            : 0,
        session: preservedSession,
        localMedia: preservedLocalMedia,
        participants: preservedParticipants,
        errorMessage: null,
      ),
    );

    late final Future<void> future;
    future = () async {
      try {
        final session = await controller.joinRelayRoomCallMedia(
          roomId: roomId,
          callId: callId,
          publishAudio: !selfParticipant.muted && !selfParticipant.deafened,
          publishVideo:
              selfParticipant.supportsVideo && selfParticipant.videoEnabled,
          publishScreenShare:
              selfParticipant.supportsScreenShare &&
              selfParticipant.screenShareEnabled,
          subscribeAll: true,
        );
        if (session == null) {
          throw StateError('room media bootstrap unavailable');
        }
        _setState(
          RoomCallRuntimeState(
            phase: RoomCallRuntimePhase.bootstrapReady,
            roomId: roomId,
            callId: callId,
            stateVersion: session.stateVersion,
            lastSyncedAtMs: nowMs,
            session: session,
            localMedia: preservedLocalMedia,
            participants: preservedParticipants,
            errorMessage: null,
          ),
        );
        await _ensureMediaController(session);
        callLog(
          'RoomCallMgr',
          'room media bootstrap ready roomId=$roomId callId=$callId capability=${session.capabilityState.name} participants=${session.participantCount}',
        );
      } catch (e) {
        _setState(
          RoomCallRuntimeState(
            phase: RoomCallRuntimePhase.failed,
            roomId: roomId,
            callId: callId,
            stateVersion: cached.stateVersion,
            lastSyncedAtMs: nowMs,
            session: preservedSession,
            localMedia: preservedLocalMedia,
            participants: preservedParticipants,
            errorMessage: e.toString(),
          ),
        );
        callLog(
          'RoomCallMgr',
          'room media bootstrap failed roomId=$roomId callId=$callId: $e',
        );
      }
    }();

    _syncInFlight = future;
    await future.whenComplete(() {
      if (identical(_syncInFlight, future)) {
        _syncInFlight = null;
      }
    });
  }

  Future<void> _ensureMediaController(RelayRoomCallMediaSession session) async {
    final nextKey = '${session.roomId}::${session.callId}';
    if (_mediaController == null || _mediaControllerKey != nextKey) {
      await _disposeMediaController();
      _mediaController = mediaControllerFactory.create();
      _mediaControllerKey = nextKey;
      _mediaController!.state.addListener(_applyMediaControllerState);
      // Seed the fresh controller's speaker flag from the CURRENT route
      // reality instead of its built-in "speaker on" default — otherwise an
      // audio call starts with the route controller holding "earpiece" while
      // the media runtime forces the loudspeaker on connect, and the speaker
      // toggle then appears to do nothing because the two sides disagree
      // about the actual output.
      final routeState = _audioRouteController.state.value;
      final seedSpeaker = routeState.availableRoutes.isEmpty
          ? _shouldPreferSpeakerByDefault(state.value)
          : routeState.isSpeakerSelected;
      await _mediaController!.setSpeakerEnabled(seedSpeaker);
    }
    await _mediaController!.syncSession(session: session);
    await _syncAudioRoutesForCurrentRoom(
      reason: 'room_media_session_ready',
      reapplyCurrentRoute: true,
    );
    _applyMediaControllerState();
  }

  Future<void> _disposeMediaController() async {
    final controller = _mediaController;
    if (controller == null) {
      _mediaControllerKey = '';
      return;
    }
    controller.state.removeListener(_applyMediaControllerState);
    _mediaController = null;
    _mediaControllerKey = '';
    await controller.dispose();
    await _audioRouteController.reset(keepPreference: true);
  }

  void _applyMediaControllerState() {
    final current = state.value;
    if (!current.hasActiveSession) {
      return;
    }
    final session = current.session;
    if (session == null) {
      return;
    }
    final localMedia = _mediaController?.state.value ?? current.localMedia;
    final participants = _buildParticipantRuntimeStates(
      session: session,
      localMedia: localMedia,
    );
    final shouldReapplyAudioRoute =
        localMedia.runtimeRevision != current.localMedia.runtimeRevision ||
        localMedia.phase != current.localMedia.phase;
    _setState(
      current.copyWith(localMedia: localMedia, participants: participants),
    );
    if (shouldReapplyAudioRoute) {
      unawaited(
        _syncAudioRoutesForCurrentRoom(
          reason: 'room_media_state_changed',
          reapplyCurrentRoute: true,
        ),
      );
    }
  }

  bool _shouldPreferSpeakerByDefault(RoomCallRuntimeState runtimeState) {
    final mediaType = (runtimeState.session?.mediaType ?? '')
        .trim()
        .toLowerCase();
    return mediaType == 'video';
  }

  Future<void> _syncAudioRoutesForCurrentRoom({
    required String reason,
    bool reapplyCurrentRoute = false,
  }) async {
    final current = state.value;
    if (!current.hasActiveSession || current.session == null) {
      return;
    }
    if (current.localMedia.phase == RoomCallLocalMediaPhase.idle) {
      return;
    }
    await _audioRouteController.ensureReady(
      preferSpeakerByDefault: _shouldPreferSpeakerByDefault(current),
      reason: reason,
      reapplySelectedRoute: reapplyCurrentRoute,
    );
  }

  void _setState(RoomCallRuntimeState nextState) {
    state.value = nextState;
    _scheduleMediaRefresh();
  }

  void _scheduleMediaRefresh() {
    _mediaRefreshTimer?.cancel();
    _mediaRefreshTimer = null;
    final current = state.value;
    if (!current.hasActiveSession ||
        current.phase != RoomCallRuntimePhase.bootstrapReady) {
      return;
    }
    _mediaRefreshTimer = Timer(_mediaRefreshInterval, () {
      _mediaRefreshTimer = null;
      unawaited(_refreshMediaSessionFromRelay());
    });
  }

  Future<void> _refreshMediaSessionFromRelay() async {
    final current = state.value;
    final currentSession = current.session;
    if (!current.hasActiveSession ||
        current.phase != RoomCallRuntimePhase.bootstrapReady ||
        currentSession == null) {
      _scheduleMediaRefresh();
      return;
    }
    if (_syncInFlight != null || _mediaRefreshInFlight != null) {
      _scheduleMediaRefresh();
      return;
    }

    final roomId = current.roomId;
    final callId = current.callId;
    late final Future<void> future;
    future = () async {
      final refreshedSession = await controller.fetchRelayRoomCallMedia(
        roomId: roomId,
        callId: callId,
      );
      if (refreshedSession == null) {
        return;
      }
      final latest = state.value;
      if (!latest.matches(roomId: roomId, callId: callId) ||
          latest.phase != RoomCallRuntimePhase.bootstrapReady) {
        return;
      }
      _setState(
        latest.copyWith(
          session: refreshedSession,
          stateVersion: refreshedSession.stateVersion,
          lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
          errorMessage: null,
        ),
      );
      await _ensureMediaController(refreshedSession);
    }();

    _mediaRefreshInFlight = future;
    await future.whenComplete(() {
      if (identical(_mediaRefreshInFlight, future)) {
        _mediaRefreshInFlight = null;
      }
      _scheduleMediaRefresh();
    });
  }

  List<RoomCallParticipantRuntimeState> _buildParticipantRuntimeStates({
    required RelayRoomCallMediaSession session,
    required RoomCallLocalMediaState localMedia,
  }) {
    final participants = session.participants
        .map(
          (participant) => RoomCallParticipantRuntimeState(
            profileId: participant.profileId,
            deviceId: participant.deviceId,
            joinState: participant.joinState,
            isSelf: participant.isSelf,
            publishAudio: participant.publishAudio,
            publishVideo: participant.publishVideo,
            publishScreenShare: participant.publishScreenShare,
            receiveAudio: participant.receiveAudio,
            receiveVideo: participant.receiveVideo,
            receiveScreenShare: participant.receiveScreenShare,
            kind: _deriveParticipantRuntimeKind(
              participant: participant,
              localMedia: localMedia,
            ),
            errorMessage: participant.isSelf ? localMedia.errorMessage : null,
            updatedAtMs: participant.updatedAtMs,
            speaking:
                _mediaController?.isParticipantSpeaking(participant.deviceId) ??
                false,
          ),
        )
        .toList(growable: false);
    participants.sort((left, right) {
      if (left.isSelf != right.isSelf) {
        return left.isSelf ? -1 : 1;
      }
      if (left.isJoined != right.isJoined) {
        return left.isJoined ? -1 : 1;
      }
      if (left.isReconnecting != right.isReconnecting) {
        return left.isReconnecting ? -1 : 1;
      }
      final updatedCompare = right.updatedAtMs.compareTo(left.updatedAtMs);
      if (updatedCompare != 0) {
        return updatedCompare;
      }
      final profileCompare = left.profileId.compareTo(right.profileId);
      if (profileCompare != 0) {
        return profileCompare;
      }
      return left.deviceId.compareTo(right.deviceId);
    });
    return participants;
  }

  RoomCallParticipantRuntimeKind _deriveParticipantRuntimeKind({
    required RelayRoomCallMediaParticipant participant,
    required RoomCallLocalMediaState localMedia,
  }) {
    final hasScreenShareView =
        _mediaController?.hasParticipantScreenShareView(participant.deviceId) ??
        false;
    final hasCameraView =
        _mediaController?.hasParticipantCameraView(participant.deviceId) ??
        false;
    if (!participant.isJoined) {
      return RoomCallParticipantRuntimeKind.none;
    }
    if (participant.joinState == 'reconnecting') {
      return RoomCallParticipantRuntimeKind.reconnecting;
    }
    if (hasScreenShareView) {
      return participant.isSelf
          ? RoomCallParticipantRuntimeKind.localScreenSharePreview
          : RoomCallParticipantRuntimeKind.remoteScreenShare;
    }
    if (hasCameraView) {
      return participant.isSelf
          ? RoomCallParticipantRuntimeKind.localPreview
          : RoomCallParticipantRuntimeKind.remoteVideo;
    }
    if (participant.isSelf) {
      if (localMedia.phase == RoomCallLocalMediaPhase.failed &&
          (participant.publishAudio ||
              participant.publishVideo ||
              participant.publishScreenShare)) {
        return RoomCallParticipantRuntimeKind.failed;
      }
    }
    if (localMedia.runtimeReconnecting) {
      return RoomCallParticipantRuntimeKind.reconnecting;
    }
    if (participant.publishScreenShare) {
      return RoomCallParticipantRuntimeKind.awaitingRemoteScreenShare;
    }
    if (participant.publishVideo) {
      return RoomCallParticipantRuntimeKind.awaitingRemoteVideo;
    }
    if (participant.publishAudio) {
      return RoomCallParticipantRuntimeKind.audioOnly;
    }
    return RoomCallParticipantRuntimeKind.none;
  }
}
