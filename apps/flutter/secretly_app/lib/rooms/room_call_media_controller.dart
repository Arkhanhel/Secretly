// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../calls/call_log.dart';
import '../calls/screen_share_runtime.dart';
import '../transport/relay_client.dart';
import 'room_call_media_state.dart';

/// Какой именно вид участника нужен: экран, камера или «что есть».
///
/// 🔴 ДОБАВОЧНОЕ, А НЕ ЗАМЕНЯЮЩЕЕ (15.09.2026). Умолчание [auto] повторяет
/// прежнее поведение знак в знак — `screenShare ?? camera`. Мобильный экран
/// созвона вызывает метод без этого параметра и потому не меняется НИ НА
/// СТРОКУ: он выпущен, и трогать его нельзя.
///
/// Зачем понадобилось: у показывающего экран камера была недостижима в
/// принципе — оба вида шли через один вызов, и первым всегда выигрывал экран.
/// Из-за этого один человек не мог одновременно занимать сцену демонстрацией и
/// держать свою плитку с лицом в ленте участников, как просит макет.
enum RoomCallVideoKind {
  /// Экран, если он есть; иначе камера. Прежнее поведение.
  auto,

  /// Только демонстрация экрана. Нет — `null`.
  screenShare,

  /// Только камера. Нет — `null`.
  camera,
}

/// Устройства системы без всякого созвона.
///
/// 🔴 ПЕРЕЧИСЛЕНИЕ НЕ ТРЕБУЕТ СЕССИИ: список даёт система, а не движок
/// созвона. Поэтому выбрать камеру можно заранее, в настройках, а не только
/// когда уже звонишь.
///
/// Отдельная функция, а не метод: у фасада `DefaultRoomCallMediaController`
/// вне звонка нет делегата, и любой его метод честно вернул бы «не знаю».
Future<List<RoomCallVideoDevice>> roomCallSystemDevices({
  required bool video,
}) async {
  final kind = video ? 'videoinput' : 'audioinput';
  final fallback = video ? 'Камера' : 'Микрофон';
  try {
    final devices = await navigator.mediaDevices.enumerateDevices();
    return devices
        .where((d) => d.kind == kind)
        .map(
          (d) => RoomCallVideoDevice(
            deviceId: d.deviceId,
            // Безымянное устройство всё равно надо как-то назвать: система
            // отдаёт пустой ярлык, пока не выдано разрешение.
            label: d.label.trim().isEmpty ? fallback : d.label.trim(),
          ),
        )
        .toList(growable: false);
  } catch (_) {
    return const <RoomCallVideoDevice>[];
  }
}

/// Устройство видеозахвата — то, из чего человек выбирает камеру.
class RoomCallVideoDevice {
  const RoomCallVideoDevice({required this.deviceId, required this.label});

  final String deviceId;
  final String label;
}

/// Показатели видеодорожки: «1920×1080 · 30 к/с».
///
/// 🔴 ЧИСЛА НАСТОЯЩИЕ, ИЗ ДВИЖКА. Раньше их неоткуда было взять, и чип
/// качества из макета не рисовался вовсе — выдуманное число хуже
/// отсутствующего: по нему судят, стоит ли просить показывающего сменить окно.
class RoomCallVideoStats {
  const RoomCallVideoStats({this.width, this.height, this.fps});

  final int? width;
  final int? height;
  final double? fps;

  bool get isEmpty => width == null && height == null && fps == null;
}

abstract class RoomCallMediaController {
  ValueListenable<RoomCallLocalMediaState> get state;

  RTCVideoRenderer? get localRenderer;

  bool hasParticipantCameraView(String deviceId);

  bool hasParticipantScreenShareView(String deviceId);

  /// Live voice-activity for [deviceId], sourced from the media runtime
  /// (LiveKit active-speaker events). Always false for runtimes without a
  /// VAD signal (local preview).
  bool isParticipantSpeaking(String deviceId);

  Widget? buildParticipantVideoView({
    required String deviceId,
    bool mirror = false,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  });

  Future<void> syncSession({required RelayRoomCallMediaSession session});

  Future<void> setSpeakerEnabled(bool enabled);

  Future<void> switchCamera();

  // ── Добавочное (15.09.2026) ─────────────────────────────────────────────
  //
  // 🔴 У ЭТИХ ТРЁХ ЕСТЬ ТЕЛО ПО УМОЛЧАНИЮ, И ЭТО НАРОЧНО.
  //
  // Движок, который чего-то из них не умеет, продолжает работать без единой
  // правки: он унаследует «не знаю» и ничего не сломает. Так же не меняется
  // и мобильный экран созвона — он их просто не зовёт.
  //
  // «Не знаю» здесь возвращается ПУСТОТОЙ, а не нулём и не выдуманным
  // значением: пустой список камер значит «выбирать не из чего», `null` у
  // показателей — «мерить нечем», ноль у громкости — «тихо», и это правда,
  // когда сигнала нет.

  /// Камеры, из которых можно выбирать. Пусто — движок их не перечисляет.
  Future<List<RoomCallVideoDevice>> videoInputs() async =>
      const <RoomCallVideoDevice>[];

  /// Микрофоны. Тот же тип, что у камер: устройство это имя и
  /// идентификатор, а чем оно снимает — звук или картинку — говорит метод.
  Future<List<RoomCallVideoDevice>> audioInputs() async =>
      const <RoomCallVideoDevice>[];

  /// Выбранный микрофон. `null` — движок не знает.
  String? get selectedAudioInputId => null;

  /// Переключиться на микрофон. Неизвестное устройство игнорируется.
  Future<void> selectAudioInput(String deviceId) async {}

  /// Выбранная камера. `null` — движок не знает.
  String? get selectedVideoInputId => null;

  /// Переключиться на камеру. Неизвестное устройство игнорируется.
  Future<void> selectVideoInput(String deviceId) async {}

  /// Показатели дорожки участника. `null` — движок статистики не отдаёт.
  Future<RoomCallVideoStats?> videoStats({
    required String deviceId,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) async => null;

  /// Громкость участника, 0…1. Ноль — тихо или сигнала нет.
  ///
  /// Отличается от [isParticipantSpeaking] тем же, чем «насколько» от
  /// «говорит ли»: по признаку рисуется рамка говорящего, по громкости —
  /// полоска уровня.
  double participantAudioLevel(String deviceId) => 0;

  Future<void> dispose();
}

abstract class RoomCallMediaControllerFactory {
  RoomCallMediaController create();
}

class DefaultRoomCallMediaControllerFactory
    implements RoomCallMediaControllerFactory {
  const DefaultRoomCallMediaControllerFactory();

  @override
  RoomCallMediaController create() => DefaultRoomCallMediaController();
}

enum _RoomCallMediaRuntimeKind { localPreview, livekit }

class DefaultRoomCallMediaController implements RoomCallMediaController {
  DefaultRoomCallMediaController();

  final ValueNotifier<RoomCallLocalMediaState> _state = ValueNotifier(
    const RoomCallLocalMediaState.idle(),
  );

  RoomCallMediaController? _delegate;
  _RoomCallMediaRuntimeKind? _delegateKind;

  /// Speaker preference recorded before the first delegate exists (the
  /// manager seeds it ahead of syncSession) — applied to every newly created
  /// delegate so a fresh LiveKit runtime never starts from its built-in
  /// "speaker on" default when the route controller says otherwise.
  bool? _pendingSpeakerEnabled;

  @override
  ValueListenable<RoomCallLocalMediaState> get state => _state;

  @override
  RTCVideoRenderer? get localRenderer => _delegate?.localRenderer;

  @override
  bool hasParticipantCameraView(String deviceId) {
    return _delegate?.hasParticipantCameraView(deviceId) ?? false;
  }

  @override
  bool hasParticipantScreenShareView(String deviceId) {
    return _delegate?.hasParticipantScreenShareView(deviceId) ?? false;
  }

  @override
  bool isParticipantSpeaking(String deviceId) {
    return _delegate?.isParticipantSpeaking(deviceId) ?? false;
  }

  @override
  Widget? buildParticipantVideoView({
    required String deviceId,
    bool mirror = false,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) {
    return _delegate?.buildParticipantVideoView(
      deviceId: deviceId,
      mirror: mirror,
      kind: kind,
    );
  }

  @override
  Future<void> syncSession({required RelayRoomCallMediaSession session}) async {
    final nextKind = _selectRuntimeKind(session);
    await _ensureDelegate(nextKind);
    await _delegate!.syncSession(session: session);
    _forwardDelegateState();
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {
    _pendingSpeakerEnabled = enabled;
    await _delegate?.setSpeakerEnabled(enabled);
    _forwardDelegateState();
  }

  @override
  Future<void> switchCamera() async {
    await _delegate?.switchCamera();
    _forwardDelegateState();
  }

  // Добавочное — просто передаём делегату. `implements` не наследует тела по
  // умолчанию, поэтому перечисляем явно.

  @override
  Future<List<RoomCallVideoDevice>> videoInputs() async =>
      await _delegate?.videoInputs() ?? const <RoomCallVideoDevice>[];

  @override
  String? get selectedVideoInputId => _delegate?.selectedVideoInputId;

  @override
  Future<void> selectVideoInput(String deviceId) async {
    await _delegate?.selectVideoInput(deviceId);
    _forwardDelegateState();
  }

  @override
  Future<List<RoomCallVideoDevice>> audioInputs() async =>
      await _delegate?.audioInputs() ?? const <RoomCallVideoDevice>[];

  @override
  String? get selectedAudioInputId => _delegate?.selectedAudioInputId;

  @override
  Future<void> selectAudioInput(String deviceId) async {
    await _delegate?.selectAudioInput(deviceId);
    _forwardDelegateState();
  }

  @override
  Future<RoomCallVideoStats?> videoStats({
    required String deviceId,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) async => _delegate?.videoStats(deviceId: deviceId, kind: kind);

  @override
  double participantAudioLevel(String deviceId) =>
      _delegate?.participantAudioLevel(deviceId) ?? 0;

  @override
  Future<void> dispose() async {
    final delegate = _delegate;
    if (delegate != null) {
      delegate.state.removeListener(_forwardDelegateState);
      _delegate = null;
      _delegateKind = null;
      await delegate.dispose();
    }
    _state.dispose();
  }

  Future<void> _ensureDelegate(_RoomCallMediaRuntimeKind nextKind) async {
    if (_delegate != null && _delegateKind == nextKind) {
      return;
    }
    final previous = _delegate;
    if (previous != null) {
      previous.state.removeListener(_forwardDelegateState);
      _delegate = null;
      _delegateKind = null;
      await previous.dispose();
    }
    final delegate = switch (nextKind) {
      _RoomCallMediaRuntimeKind.localPreview =>
        _LocalPreviewRoomCallMediaController(),
      _RoomCallMediaRuntimeKind.livekit => _LiveKitRoomCallMediaController(),
    };
    _delegate = delegate;
    _delegateKind = nextKind;
    final pendingSpeaker = _pendingSpeakerEnabled;
    if (pendingSpeaker != null) {
      // Seed BEFORE the caller's syncSession connects the runtime, so the
      // first _applySpeakerRoute on connect uses the real preference.
      await delegate.setSpeakerEnabled(pendingSpeaker);
    }
    delegate.state.addListener(_forwardDelegateState);
    _forwardDelegateState();
  }

  _RoomCallMediaRuntimeKind _selectRuntimeKind(
    RelayRoomCallMediaSession session,
  ) {
    if (session.hasSessionAuthority &&
        session.backend.kind == RelayRoomCallMediaBackendKind.livekit &&
        session.backend.isConfigured &&
        session.backend.hasAccessToken &&
        (session.backend.roomName?.trim().isNotEmpty ?? false) &&
        (session.backend.participantIdentity?.trim().isNotEmpty ?? false)) {
      return _RoomCallMediaRuntimeKind.livekit;
    }
    return _RoomCallMediaRuntimeKind.localPreview;
  }

  void _forwardDelegateState() {
    final delegateState = _delegate?.state.value;
    if (delegateState == null) {
      return;
    }
    _state.value = delegateState;
  }
}

class _LocalPreviewRoomCallMediaController implements RoomCallMediaController {
  _LocalPreviewRoomCallMediaController();

  static const Map<String, Object?> _audioOnlyConstraints = <String, Object?>{
    'audio': true,
    'video': false,
  };

  final ValueNotifier<RoomCallLocalMediaState> _state = ValueNotifier(
    const RoomCallLocalMediaState.idle(),
  );

  RTCVideoRenderer? _localRenderer;
  MediaStream? _localStream;
  MediaStream? _screenStream;
  ScreenShareRuntimeLease? _screenShareLease;
  String _selfDeviceId = '';
  bool _rendererInitialized = false;
  bool _speakerEnabled = true;
  bool _usingFrontCamera = true;
  bool _disposed = false;
  int _runtimeRevision = 0;

  @override
  ValueListenable<RoomCallLocalMediaState> get state => _state;

  @override
  RTCVideoRenderer? get localRenderer => _localRenderer;

  @override
  bool hasParticipantCameraView(String deviceId) {
    return deviceId.trim() == _selfDeviceId &&
        _state.value.localPreviewAvailable &&
        _state.value.videoCaptureActive;
  }

  @override
  bool hasParticipantScreenShareView(String deviceId) {
    return deviceId.trim() == _selfDeviceId &&
        _state.value.localPreviewAvailable &&
        _state.value.screenShareActive;
  }

  @override
  bool isParticipantSpeaking(String deviceId) => false;

  @override
  Widget? buildParticipantVideoView({
    required String deviceId,
    bool mirror = false,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) {
    if (deviceId.trim() != _selfDeviceId ||
        _localRenderer == null ||
        !_state.value.localPreviewAvailable) {
      return null;
    }
    // У местного превью дорожка одна: она показывает либо экран, либо камеру.
    // Просят не то, что идёт сейчас, — честнее отдать пусто, чем чужой вид.
    final showingScreen = _state.value.screenShareActive;
    if (kind == RoomCallVideoKind.screenShare && !showingScreen) return null;
    if (kind == RoomCallVideoKind.camera && showingScreen) return null;
    return RTCVideoView(
      key: ValueKey(
        'room-local-preview:${deviceId.trim()}:${_videoRendererBindingToken(_localRenderer!)}',
      ),
      _localRenderer!,
      mirror: mirror && !_state.value.screenShareActive,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }

  @override
  Future<void> syncSession({required RelayRoomCallMediaSession session}) async {
    if (_disposed) {
      return;
    }
    _selfDeviceId = session.selfDeviceId.trim();
    final self = session.selfParticipant;
    if (self == null || !self.isJoined) {
      _selfDeviceId = '';
      await _clearAllMedia();
      _runtimeRevision += 1;
      _setState(
        RoomCallLocalMediaState.idle(
          speakerEnabled: _speakerEnabled,
          usingFrontCamera: _usingFrontCamera,
        ).copyWith(runtimeRevision: _runtimeRevision),
      );
      return;
    }

    _setState(
      _state.value.copyWith(
        phase: RoomCallLocalMediaPhase.acquiring,
        speakerEnabled: _speakerEnabled,
        usingFrontCamera: _usingFrontCamera,
        runtimeConnected: false,
        runtimeReconnecting: false,
        clearError: true,
      ),
    );

    try {
      await _ensureRendererInitialized();
      await _applySpeakerRoute();
      await _syncLocalMedia(self);
    } catch (e) {
      callLog(
        'RoomMedia',
        'local media sync failed roomId=${session.roomId} callId=${session.callId}: $e',
      );
      _setState(
        _state.value.copyWith(
          phase: RoomCallLocalMediaPhase.failed,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {
    if (_speakerEnabled == enabled) {
      return;
    }
    _speakerEnabled = enabled;
    await _applySpeakerRoute();
    _setState(_state.value.copyWith(speakerEnabled: _speakerEnabled));
  }

  // Добавочное. Местное превью — это «движка нет»: камеры оно перечислить
  // может (список устройств даёт система), а показателей дорожки и громкости
  // у него нет вовсе — мерить нечем, и выдумывать их нельзя.

  @override
  Future<List<RoomCallVideoDevice>> videoInputs() async =>
      _enumerate('videoinput', 'Камера');

  /// Список устройств системы. Безымянное всё равно надо как-то назвать:
  /// система отдаёт пустой ярлык до выдачи разрешения.
  Future<List<RoomCallVideoDevice>> _enumerate(
    String kind,
    String fallbackLabel,
  ) => roomCallSystemDevices(video: kind == 'videoinput');

  @override
  Future<RoomCallVideoStats?> videoStats({
    required String deviceId,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) async => null;

  @override
  double participantAudioLevel(String deviceId) => 0;

  @override
  Future<List<RoomCallVideoDevice>> audioInputs() async =>
      _enumerate('audioinput', 'Микрофон');

  /// Выбранный микрофон здесь не хранится: превью звук не публикует.
  @override
  String? get selectedAudioInputId => null;

  @override
  Future<void> selectAudioInput(String deviceId) async {}

  /// Выбранная камера здесь не хранится: превью открывает ту, что дала
  /// система, и переключение идёт `switchCamera()` — «другая», а не «вот эта».
  @override
  String? get selectedVideoInputId => null;

  @override
  Future<void> selectVideoInput(String deviceId) async {}

  @override
  Future<void> switchCamera() async {
    if (_screenStream != null) {
      return;
    }
    final localStream = _localStream;
    if (localStream == null) {
      return;
    }
    final tracks = localStream.getVideoTracks();
    if (tracks.isEmpty) {
      return;
    }
    try {
      await Helper.switchCamera(tracks.first);
      _usingFrontCamera = !_usingFrontCamera;
      _runtimeRevision += 1;
      _setState(
        _state.value.copyWith(
          usingFrontCamera: _usingFrontCamera,
          runtimeRevision: _runtimeRevision,
        ),
      );
    } catch (e) {
      callLog('RoomMedia', 'switchCamera failed: $e');
      _setState(_state.value.copyWith(errorMessage: e.toString()));
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _clearAllMedia();
    if (_localRenderer != null) {
      try {
        _localRenderer!.srcObject = null;
      } catch (_) {}
      if (_rendererInitialized) {
        try {
          await _localRenderer!.dispose();
        } catch (_) {}
      }
      _localRenderer = null;
    }
    _state.dispose();
  }

  Future<void> _ensureRendererInitialized() async {
    _localRenderer ??= RTCVideoRenderer();
    if (_rendererInitialized) {
      return;
    }
    await _localRenderer!.initialize();
    _rendererInitialized = true;
  }

  Future<void> _syncLocalMedia(RelayRoomCallMediaParticipant self) async {
    final wantsAudio = self.publishAudio;
    final wantsVideo = self.publishVideo && self.supportsVideo;
    final wantsScreenShare =
        self.publishScreenShare && self.supportsScreenShare;
    String? warningMessage;

    if (wantsAudio || wantsVideo) {
      warningMessage = await _ensureBaseLocalStream(
        includeAudio: wantsAudio,
        includeVideo: wantsVideo,
      );
      await _ensureAudioTrack(enabled: wantsAudio);
      if (wantsVideo) {
        final extraWarning = await _ensureCameraVideoTrack();
        warningMessage ??= extraWarning;
      } else {
        await _removeCameraVideoTracks();
      }
    } else {
      await _releaseBaseLocalStream();
    }

    if (wantsScreenShare) {
      final extraWarning = await _ensureScreenShareStream();
      warningMessage ??= extraWarning;
    } else {
      await _stopScreenShareStream();
    }

    await _bindPreviewSource();
    _refreshDerivedState(errorMessage: warningMessage);
  }

  Future<String?> _ensureBaseLocalStream({
    required bool includeAudio,
    required bool includeVideo,
  }) async {
    if (_localStream == null) {
      try {
        _localStream = await navigator.mediaDevices.getUserMedia(
          includeVideo
              ? _cameraConstraints(includeAudio: includeAudio)
              : <String, Object?>{'audio': includeAudio, 'video': false},
        );
        callLog(
          'RoomMedia',
          'created local stream audio=$includeAudio video=$includeVideo tracks=${_localStream?.getTracks().length ?? 0}',
        );
        return null;
      } catch (e) {
        if (includeVideo && includeAudio) {
          _localStream = await navigator.mediaDevices.getUserMedia(
            _audioOnlyConstraints,
          );
          callLog(
            'RoomMedia',
            'camera unavailable, audio-only fallback active: $e',
          );
          return 'camera unavailable';
        }
        rethrow;
      }
    }
    return null;
  }

  Future<void> _ensureAudioTrack({required bool enabled}) async {
    if (_localStream == null) {
      return;
    }
    var tracks = _localStream!.getAudioTracks();
    if (enabled && tracks.isEmpty) {
      final audioStream = await navigator.mediaDevices.getUserMedia(
        _audioOnlyConstraints,
      );
      for (final track in audioStream.getAudioTracks()) {
        await _localStream!.addTrack(track);
      }
      tracks = _localStream!.getAudioTracks();
    }
    for (final track in tracks) {
      track.enabled = enabled;
    }
  }

  Future<String?> _ensureCameraVideoTrack() async {
    if (_localStream == null) {
      return 'camera unavailable';
    }
    final existing = _localStream!.getVideoTracks();
    if (existing.isNotEmpty) {
      for (final track in existing) {
        track.enabled = true;
      }
      return null;
    }
    try {
      final videoStream = await navigator.mediaDevices.getUserMedia(
        _cameraConstraints(includeAudio: false),
      );
      for (final track in videoStream.getVideoTracks()) {
        await _localStream!.addTrack(track);
      }
      return null;
    } catch (e) {
      callLog('RoomMedia', 'camera video track acquisition failed: $e');
      return 'camera unavailable';
    }
  }

  Future<void> _removeCameraVideoTracks() async {
    final localStream = _localStream;
    if (localStream == null) {
      return;
    }
    for (final track in List<MediaStreamTrack>.from(
      localStream.getVideoTracks(),
    )) {
      try {
        track.stop();
      } catch (_) {}
      try {
        await localStream.removeTrack(track);
      } catch (_) {}
    }
  }

  Future<String?> _ensureScreenShareStream() async {
    if (_screenStream != null && _screenStream!.getVideoTracks().isNotEmpty) {
      return null;
    }
    final lease = await ScreenShareRuntime.acquire();
    if (lease == null) {
      return 'screen share permission denied';
    }
    try {
      final stream = await navigator.mediaDevices.getDisplayMedia(
        const <String, Object?>{'audio': false, 'video': true},
      );
      final screenTracks = stream.getVideoTracks();
      if (screenTracks.isEmpty) {
        for (final track in stream.getTracks()) {
          try {
            track.stop();
          } catch (_) {}
        }
        throw StateError('screen capture returned no video track');
      }
      final screenTrack = screenTracks.first;
      screenTrack.onEnded = () {
        unawaited(_handleUnexpectedScreenShareEnded());
      };
      _screenStream = stream;
      _screenShareLease = lease;
      return null;
    } catch (e) {
      await lease.release();
      callLog('RoomMedia', 'screen-share acquisition failed: $e');
      return 'screen share unavailable';
    }
  }

  Future<void> _handleUnexpectedScreenShareEnded() async {
    if (_disposed || _screenStream == null) {
      return;
    }
    callLog('RoomMedia', 'screen share ended unexpectedly');
    await _stopScreenShareStream();
    await _bindPreviewSource();
    _refreshDerivedState(errorMessage: 'screen share stopped');
  }

  Future<void> _stopScreenShareStream() async {
    final screenStream = _screenStream;
    if (screenStream == null) {
      return;
    }
    for (final track in screenStream.getTracks()) {
      track.onEnded = () {};
      try {
        track.stop();
      } catch (_) {}
    }
    _screenStream = null;
    final lease = _screenShareLease;
    _screenShareLease = null;
    if (lease != null) {
      await lease.release();
    }
  }

  Future<void> _releaseBaseLocalStream() async {
    final localStream = _localStream;
    if (localStream == null) {
      return;
    }
    for (final track in localStream.getTracks()) {
      try {
        track.stop();
      } catch (_) {}
    }
    _localStream = null;
  }

  Future<void> _bindPreviewSource() async {
    if (_localRenderer == null) {
      return;
    }
    final nextSource = _screenStream ?? _localStream;
    try {
      _localRenderer!.srcObject = nextSource;
      _runtimeRevision += 1;
    } catch (e) {
      callLog('RoomMedia', 'binding preview source failed: $e');
      rethrow;
    }
  }

  void _refreshDerivedState({String? errorMessage}) {
    final localStream = _localStream;
    final rendererStream = _localRenderer?.srcObject;
    final audioCaptureActive =
        localStream?.getAudioTracks().any((track) => track.enabled) ?? false;
    final videoCaptureActive =
        localStream?.getVideoTracks().any((track) => track.enabled) ?? false;
    final screenShareActive =
        _screenStream?.getVideoTracks().any((track) => track.enabled) ?? false;
    final localPreviewAvailable =
        rendererStream?.getVideoTracks().isNotEmpty ?? false;
    _setState(
      RoomCallLocalMediaState(
        phase: RoomCallLocalMediaPhase.ready,
        audioCaptureActive: audioCaptureActive,
        videoCaptureActive: videoCaptureActive,
        screenShareActive: screenShareActive,
        localPreviewAvailable: localPreviewAvailable,
        speakerEnabled: _speakerEnabled,
        usingFrontCamera: _usingFrontCamera,
        runtimeConnected: false,
        runtimeReconnecting: false,
        runtimeRevision: _runtimeRevision,
        errorMessage: errorMessage,
      ),
    );
    callLog(
      'RoomMedia',
      'local media ready audio=$audioCaptureActive video=$videoCaptureActive screen=$screenShareActive preview=$localPreviewAvailable',
    );
  }

  Future<void> _applySpeakerRoute() async {
    try {
      final dynamic helper = Helper;
      await helper.setSpeakerphoneOn(_speakerEnabled);
    } catch (_) {
      // ignore unsupported runtime/platform
    }
  }

  Future<void> _clearAllMedia() async {
    await _stopScreenShareStream();
    await _releaseBaseLocalStream();
    if (_localRenderer != null) {
      try {
        _localRenderer!.srcObject = null;
      } catch (_) {}
    }
    _runtimeRevision += 1;
  }

  Map<String, Object?> _cameraConstraints({required bool includeAudio}) {
    return <String, Object?>{
      'audio': includeAudio,
      'video': <String, Object?>{
        'facingMode': _usingFrontCamera ? 'user' : 'environment',
        'width': const <String, int>{'ideal': 960},
        'height': const <String, int>{'ideal': 540},
        'frameRate': const <String, int>{'ideal': 20, 'max': 24},
      },
    };
  }

  void _setState(RoomCallLocalMediaState next) {
    if (_disposed) {
      return;
    }
    final current = _state.value;
    if (current.phase == next.phase &&
        current.audioCaptureActive == next.audioCaptureActive &&
        current.videoCaptureActive == next.videoCaptureActive &&
        current.screenShareActive == next.screenShareActive &&
        current.localPreviewAvailable == next.localPreviewAvailable &&
        current.speakerEnabled == next.speakerEnabled &&
        current.usingFrontCamera == next.usingFrontCamera &&
        current.runtimeConnected == next.runtimeConnected &&
        current.runtimeReconnecting == next.runtimeReconnecting &&
        current.runtimeRevision == next.runtimeRevision &&
        current.errorMessage == next.errorMessage) {
      return;
    }
    _state.value = next;
  }
}

class _LiveKitParticipantBinding {
  const _LiveKitParticipantBinding({this.cameraTrack, this.screenShareTrack});

  final lk.VideoTrack? cameraTrack;
  final lk.VideoTrack? screenShareTrack;

  String get signature {
    return '${_liveKitTrackSignature(cameraTrack)}|${_liveKitTrackSignature(screenShareTrack)}';
  }
}

class _LiveKitParticipantMetadata {
  const _LiveKitParticipantMetadata({
    required this.profileId,
    required this.deviceId,
  });

  final String profileId;
  final String deviceId;
}

class _LiveKitRoomCallMediaController implements RoomCallMediaController {
  _LiveKitRoomCallMediaController();

  final ValueNotifier<RoomCallLocalMediaState> _state = ValueNotifier(
    const RoomCallLocalMediaState.idle(),
  );

  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _roomListener;
  RelayRoomCallMediaSession? _session;
  Future<void>? _connectInFlight;
  Map<String, _LiveKitParticipantBinding> _participantBindings =
      const <String, _LiveKitParticipantBinding>{};
  String _participantBindingsSignature = '';
  String _runtimeKey = '';
  ScreenShareRuntimeLease? _screenShareLease;
  bool _speakerEnabled = true;
  bool _usingFrontCamera = true;
  bool _disposed = false;
  int _runtimeRevision = 0;
  String? _statusMessage;
  bool _statusMessageIsFatal = false;
  Set<String> _speakingDeviceIds = const <String>{};

  /// Участники по устройству — нужны ради громкости: она живёт на самом
  /// участнике (`audioLevel`), а не на дорожке.
  Map<String, lk.Participant> _participantsByDeviceId =
      const <String, lk.Participant>{};
  int _speakingRevision = 0;
  AudioPlayer? _joinChimePlayer;
  int _lastJoinChimeAtMs = 0;

  @override
  ValueListenable<RoomCallLocalMediaState> get state => _state;

  @override
  RTCVideoRenderer? get localRenderer => null;

  @override
  bool hasParticipantCameraView(String deviceId) {
    return _participantBindings[deviceId.trim()]?.cameraTrack != null;
  }

  @override
  bool hasParticipantScreenShareView(String deviceId) {
    return _participantBindings[deviceId.trim()]?.screenShareTrack != null;
  }

  @override
  bool isParticipantSpeaking(String deviceId) {
    return _speakingDeviceIds.contains(deviceId.trim());
  }

  @override
  Widget? buildParticipantVideoView({
    required String deviceId,
    bool mirror = false,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) {
    final binding = _participantBindings[deviceId.trim()];
    final track = switch (kind) {
      RoomCallVideoKind.auto =>
        binding?.screenShareTrack ?? binding?.cameraTrack,
      RoomCallVideoKind.screenShare => binding?.screenShareTrack,
      RoomCallVideoKind.camera => binding?.cameraTrack,
    };
    if (track == null) {
      return null;
    }
    Widget child = lk.VideoTrackRenderer(track);
    if (mirror) {
      child = Transform.flip(flipX: true, child: child);
    }
    return KeyedSubtree(
      // 🔴 Вид входит в ключ. Иначе сцена и плитка одного и того же человека
      // делили бы один отрисовщик, и второй вид переиспользовал бы дорожку
      // первого — на плитке показывался бы экран вместо лица.
      key: ValueKey(
        'room-livekit-video:${deviceId.trim()}:${kind.name}:${binding!.signature}:${_state.value.runtimeRevision}',
      ),
      child: child,
    );
  }

  // ── Камеры, показатели и громкость ──────────────────────────────────────

  @override
  Future<List<RoomCallVideoDevice>> videoInputs() async {
    try {
      final devices = await lk.Hardware.instance.videoInputs();
      return devices
          .map(
            (d) => RoomCallVideoDevice(
              deviceId: d.deviceId,
              // Безымянную камеру всё равно надо как-то назвать: система
              // иногда отдаёт пустой ярлык до выдачи разрешения.
              label: d.label.trim().isEmpty ? 'Камера' : d.label.trim(),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      // Перечислить не удалось — значит выбирать не из чего. Пустой список
      // честнее выдуманного устройства.
      return const <RoomCallVideoDevice>[];
    }
  }

  @override
  Future<List<RoomCallVideoDevice>> audioInputs() async {
    try {
      final devices = await lk.Hardware.instance.audioInputs();
      return devices
          .map(
            (d) => RoomCallVideoDevice(
              deviceId: d.deviceId,
              label: d.label.trim().isEmpty ? 'Микрофон' : d.label.trim(),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <RoomCallVideoDevice>[];
    }
  }

  @override
  String? get selectedAudioInputId => _selectedAudioInputId;

  String? _selectedAudioInputId;

  @override
  Future<void> selectAudioInput(String deviceId) async {
    final want = deviceId.trim();
    if (want.isEmpty) return;
    final localParticipant = _room?.localParticipant;
    if (localParticipant == null) return;
    // Как и у камеры: меняем САМУ дорожку, а не «выбранное устройство» в
    // движке — второе влияет лишь на то, что откроется потом.
    final publication = localParticipant.audioTrackPublications
        .where((v) => v.track is lk.LocalAudioTrack)
        .firstOrNull;
    final track = publication?.track;
    if (track is! lk.LocalAudioTrack) return;
    try {
      await track.setDeviceId(want);
      _selectedAudioInputId = want;
      _clearStatusMessage();
    } catch (e) {
      callLog('RoomMedia', 'livekit selectAudioInput failed: $e');
      _setStatusMessage(e.toString(), fatal: false);
      return;
    }
    _runtimeRevision += 1;
    _refreshState();
  }

  @override
  String? get selectedVideoInputId => _selectedVideoInputId;

  String? _selectedVideoInputId;

  @override
  Future<void> selectVideoInput(String deviceId) async {
    final want = deviceId.trim();
    if (want.isEmpty) return;
    final localParticipant = _room?.localParticipant;
    if (localParticipant == null) return;
    // Переключаем САМУ дорожку, а не «выбранное устройство» в движке: второе
    // влияет только на камеры, которые откроются ПОТОМ, а нам нужна та, что
    // уже идёт в созвон.
    final publication = localParticipant.videoTrackPublications
        .where((v) => !v.isScreenShare && v.track is lk.LocalVideoTrack)
        .firstOrNull;
    final track = publication?.track;
    if (track is! lk.LocalVideoTrack) return;
    try {
      await track.switchCamera(want);
      _selectedVideoInputId = want;
      _clearStatusMessage();
    } catch (e) {
      callLog('RoomMedia', 'livekit selectVideoInput failed: $e');
      _setStatusMessage(e.toString(), fatal: false);
      return;
    }
    _rebuildParticipantBindingsFromRoom();
    _runtimeRevision += 1;
    _refreshState();
  }

  @override
  Future<RoomCallVideoStats?> videoStats({
    required String deviceId,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) async {
    final binding = _participantBindings[deviceId.trim()];
    final track = switch (kind) {
      RoomCallVideoKind.auto =>
        binding?.screenShareTrack ?? binding?.cameraTrack,
      RoomCallVideoKind.screenShare => binding?.screenShareTrack,
      RoomCallVideoKind.camera => binding?.cameraTrack,
    };
    // Показатели есть только у ПРИНИМАЕМОЙ дорожки: свою мы отдаём, и
    // «сколько дошло» к ней неприменимо.
    if (track is! lk.RemoteVideoTrack) return null;
    try {
      final stats = await track.getReceiverStats();
      if (stats == null) return null;
      final out = RoomCallVideoStats(
        width: stats.frameWidth?.toInt(),
        height: stats.frameHeight?.toInt(),
        fps: stats.framesPerSecond?.toDouble(),
      );
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  @override
  double participantAudioLevel(String deviceId) {
    final p = _participantsByDeviceId[deviceId.trim()];
    if (p == null) return 0;
    final level = p.audioLevel;
    return level.isFinite ? level.clamp(0.0, 1.0) : 0;
  }

  @override
  Future<void> syncSession({required RelayRoomCallMediaSession session}) async {
    if (_disposed) {
      return;
    }
    _session = session;
    final self = session.selfParticipant;
    if (self == null || !self.isJoined) {
      await _disconnectRoom();
      _participantBindings = const <String, _LiveKitParticipantBinding>{};
      _participantBindingsSignature = '';
      _clearStatusMessage();
      _runtimeRevision += 1;
      _setState(
        RoomCallLocalMediaState.idle(
          speakerEnabled: _speakerEnabled,
          usingFrontCamera: _usingFrontCamera,
        ).copyWith(
          runtimeRevision: _runtimeRevision,
          speakingRevision: _speakingRevision,
        ),
      );
      return;
    }

    final room = _room;
    final isConnected = room?.connectionState == lk.ConnectionState.connected;
    if (!isConnected) {
      _setState(
        _state.value.copyWith(
          phase: RoomCallLocalMediaPhase.acquiring,
          speakerEnabled: _speakerEnabled,
          usingFrontCamera: _usingFrontCamera,
          clearError: true,
        ),
      );
    }

    try {
      await _ensureRoomConnected(session);
      await _syncLocalParticipant(session);
      _rebuildParticipantBindingsFromRoom();
      _refreshState();
    } catch (e) {
      callLog(
        'RoomMedia',
        'livekit room runtime sync failed roomId=${session.roomId} callId=${session.callId}: $e',
      );
      _setStatusMessage(e.toString(), fatal: true);
      _refreshState();
    }
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {
    _speakerEnabled = enabled;
    final room = _room;
    if (room != null) {
      await _applySpeakerRoute(room);
    }
    _refreshState();
  }

  @override
  Future<void> switchCamera() async {
    final room = _room;
    final localParticipant = room?.localParticipant;
    if (room == null || localParticipant == null) {
      return;
    }
    final publication = localParticipant.videoTrackPublications.firstWhere(
      (value) => !value.isScreenShare && value.track is lk.LocalVideoTrack,
      orElse: () => throw StateError('camera track unavailable'),
    );
    final track = publication.track;
    if (track is! lk.LocalVideoTrack) {
      return;
    }
    try {
      await track.setCameraPosition(
        _usingFrontCamera ? lk.CameraPosition.back : lk.CameraPosition.front,
      );
      _usingFrontCamera = !_usingFrontCamera;
      _clearStatusMessage();
    } catch (e) {
      callLog('RoomMedia', 'livekit switchCamera failed: $e');
      _setStatusMessage(e.toString(), fatal: false);
    }
    _rebuildParticipantBindingsFromRoom();
    _refreshState();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _disconnectRoom();
    final chimePlayer = _joinChimePlayer;
    _joinChimePlayer = null;
    if (chimePlayer != null) {
      try {
        await chimePlayer.dispose();
      } catch (_) {}
    }
    _state.dispose();
  }

  Future<bool> _ensureLiveKitScreenShareLease() async {
    if (_screenShareLease != null) {
      return true;
    }
    final lease = await ScreenShareRuntime.acquire();
    if (lease == null) {
      return false;
    }
    _screenShareLease = lease;
    return true;
  }

  Future<void> _releaseLiveKitScreenShareLease() async {
    final lease = _screenShareLease;
    _screenShareLease = null;
    if (lease != null) {
      await lease.release();
    }
  }

  Future<void> _ensureRoomConnected(RelayRoomCallMediaSession session) async {
    final backend = session.backend;
    final url = backend.url?.trim() ?? '';
    final token = backend.accessToken?.trim() ?? '';
    final roomName = backend.roomName?.trim() ?? '';
    final participantIdentity = backend.participantIdentity?.trim() ?? '';
    if (url.isEmpty ||
        token.isEmpty ||
        roomName.isEmpty ||
        participantIdentity.isEmpty) {
      throw StateError('room media session authority unavailable');
    }

    final nextRuntimeKey = [
      session.roomId.trim(),
      session.callId.trim(),
      url,
      roomName,
      participantIdentity,
    ].join('::');

    final room = _room;
    if (room != null &&
        _runtimeKey == nextRuntimeKey &&
        room.connectionState != lk.ConnectionState.disconnected) {
      return;
    }

    final existingConnect = _connectInFlight;
    if (existingConnect != null) {
      await existingConnect;
      final refreshedRoom = _room;
      if (refreshedRoom != null &&
          _runtimeKey == nextRuntimeKey &&
          refreshedRoom.connectionState != lk.ConnectionState.disconnected) {
        return;
      }
    }

    late final Future<void> future;
    future = _connectRoom(url: url, token: token, runtimeKey: nextRuntimeKey);
    _connectInFlight = future;
    await future.whenComplete(() {
      if (identical(_connectInFlight, future)) {
        _connectInFlight = null;
      }
    });
  }

  Future<void> _connectRoom({
    required String url,
    required String token,
    required String runtimeKey,
  }) async {
    await _disconnectRoom();

    final room = lk.Room(
      roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
    );
    room.addListener(_handleRoomChanged);
    final listener = room.createListener()
      ..on<lk.RoomDisconnectedEvent>((_) => _handleRoomChanged())
      ..on<lk.RoomReconnectingEvent>((_) => _handleRoomChanged())
      ..on<lk.RoomReconnectedEvent>((_) => _handleRoomChanged())
      ..on<lk.ActiveSpeakersChangedEvent>(_handleActiveSpeakersChanged)
      ..on<lk.ParticipantConnectedEvent>((_) {
        _playJoinChime();
        _handleRoomChanged();
      })
      ..on<lk.ParticipantDisconnectedEvent>((_) => _handleRoomChanged())
      ..on<lk.ParticipantMetadataUpdatedEvent>((_) => _handleRoomChanged())
      ..on<lk.TrackSubscribedEvent>((_) => _handleRoomChanged())
      ..on<lk.TrackUnsubscribedEvent>((_) => _handleRoomChanged())
      ..on<lk.TrackPublishedEvent>((_) => _handleRoomChanged())
      ..on<lk.TrackUnpublishedEvent>((_) => _handleRoomChanged())
      ..on<lk.TrackMutedEvent>((_) => _handleRoomChanged())
      ..on<lk.TrackUnmutedEvent>((_) => _handleRoomChanged())
      ..on<lk.LocalTrackPublishedEvent>((_) => _handleRoomChanged())
      ..on<lk.LocalTrackUnpublishedEvent>((event) {
        if (event.publication.source == lk.TrackSource.screenShareVideo) {
          unawaited(_handleLiveKitScreenShareUnpublished());
        }
        _handleRoomChanged();
      });

    try {
      await room.prepareConnection(url, token);
    } catch (_) {
      // prepareConnection is an optimization only.
    }

    await room.connect(url, token);
    try {
      await room.startAudio();
    } catch (_) {
      // some platforms do not require an explicit audio start.
    }

    _room = room;
    _roomListener = listener;
    _runtimeKey = runtimeKey;
    _clearStatusMessage();
    await _applySpeakerRoute(room);
    _rebuildParticipantBindingsFromRoom();
    _refreshState();
  }

  Future<void> _handleLiveKitScreenShareUnpublished() async {
    await _releaseLiveKitScreenShareLease();
    final wantsScreenShare = _session?.selfParticipant?.publishScreenShare == true;
    if (_disposed || !wantsScreenShare) {
      return;
    }
    callLog('RoomMedia', 'livekit screen share ended unexpectedly');
    _setStatusMessage('screen share stopped', fatal: false);
    _refreshState();
  }

  Future<void> _syncLocalParticipant(RelayRoomCallMediaSession session) async {
    final room = _room;
    final localParticipant = room?.localParticipant;
    final self = session.selfParticipant;
    if (room == null || localParticipant == null || self == null) {
      return;
    }

    String? warningMessage;

    final wantsAudio = self.publishAudio;
    if (localParticipant.isMicrophoneEnabled() != wantsAudio) {
      try {
        await localParticipant.setMicrophoneEnabled(wantsAudio);
      } catch (e) {
        callLog('RoomMedia', 'livekit microphone sync failed: $e');
        if (wantsAudio) {
          warningMessage ??= 'microphone unavailable';
        }
      }
    }

    final wantsVideo = self.publishVideo && self.supportsVideo;
    if (localParticipant.isCameraEnabled() != wantsVideo) {
      try {
        await localParticipant.setCameraEnabled(wantsVideo);
      } catch (e) {
        callLog('RoomMedia', 'livekit camera sync failed: $e');
        if (wantsVideo) {
          warningMessage ??= 'camera unavailable';
        }
      }
    }

    final wantsScreenShare =
        self.publishScreenShare && self.supportsScreenShare;
    if (localParticipant.isScreenShareEnabled() != wantsScreenShare) {
      try {
        if (wantsScreenShare) {
          final ready = await _ensureLiveKitScreenShareLease();
          if (!ready) {
            warningMessage ??= 'screen share permission denied';
          } else {
            await localParticipant.setScreenShareEnabled(true);
          }
        } else {
          await localParticipant.setScreenShareEnabled(false);
          await _releaseLiveKitScreenShareLease();
        }
      } catch (e) {
        callLog('RoomMedia', 'livekit screen-share sync failed: $e');
        if (wantsScreenShare) {
          warningMessage ??= 'screen share unavailable';
        }
        await _releaseLiveKitScreenShareLease();
      }
    } else if (!wantsScreenShare) {
      await _releaseLiveKitScreenShareLease();
    }

    // NOTE: no _applySpeakerRoute here. This sync runs on EVERY relay
    // refresh (every ~5s) — re-forcing the speaker route from the internal
    // flag on that cadence fought the user's route selection (the speaker
    // toggle appeared broken because the periodic re-apply kept resetting
    // the audio output). The route is applied once on connect and whenever
    // setSpeakerEnabled is explicitly called; the platform keeps it after
    // that.
    if (warningMessage == null) {
      _clearStatusMessage();
    } else {
      _setStatusMessage(warningMessage, fatal: false);
    }
  }

  Future<void> _applySpeakerRoute(lk.Room room) async {
    try {
      await room.setSpeakerOn(_speakerEnabled);
      return;
    } catch (_) {
      // ignore and try the lower-level route helper
    }
    try {
      final dynamic helper = Helper;
      await helper.setSpeakerphoneOn(_speakerEnabled);
    } catch (_) {
      // ignore unsupported runtime/platform
    }
  }

  Future<void> _disconnectRoom() async {
    final room = _room;
    final listener = _roomListener;
    _room = null;
    _roomListener = null;
    _runtimeKey = '';
    if (_speakingDeviceIds.isNotEmpty) {
      _speakingDeviceIds = const <String>{};
      _speakingRevision += 1;
    }
    if (listener != null) {
      listener.dispose();
    }
    if (room != null) {
      room.removeListener(_handleRoomChanged);
      try {
        await room.disconnect();
      } catch (_) {}
      try {
        await room.dispose();
      } catch (_) {}
    }
    await _releaseLiveKitScreenShareLease();
  }

  void _handleRoomChanged() {
    if (_disposed) {
      return;
    }
    _rebuildParticipantBindingsFromRoom();
    _refreshState();
  }

  /// LiveKit active-speaker list → set of speaking deviceIds. This is the
  /// ONLY source of the green "speaking" highlight: relay snapshots carry no
  /// voice-activity signal, so without this subscription the flag never
  /// becomes true in a real call.
  void _handleActiveSpeakersChanged(lk.ActiveSpeakersChangedEvent event) {
    if (_disposed) {
      return;
    }
    final session = _session;
    final next = <String>{};
    for (final speaker in event.speakers) {
      if (speaker is lk.LocalParticipant) {
        final selfDeviceId = session?.selfDeviceId.trim() ?? '';
        if (selfDeviceId.isNotEmpty) {
          next.add(selfDeviceId);
        }
        continue;
      }
      final deviceId = _parseParticipantMetadata(
        speaker.metadata,
      )?.deviceId.trim();
      if (deviceId != null && deviceId.isNotEmpty) {
        next.add(deviceId);
      }
    }
    if (setEquals(next, _speakingDeviceIds)) {
      return;
    }
    _speakingDeviceIds = next;
    _speakingRevision += 1;
    _refreshState();
  }

  /// Short audible cue for people ALREADY in the call when a new participant
  /// connects (Discord-style). Fires only on ParticipantConnectedEvent — the
  /// participants present when WE join never trigger it. Throttled so a
  /// burst of joins (reconnect storms) reads as one chime.
  void _playJoinChime() {
    if (_disposed) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastJoinChimeAtMs < 1500) {
      return;
    }
    _lastJoinChimeAtMs = nowMs;
    unawaited(() async {
      try {
        final player = _joinChimePlayer ??= AudioPlayer();
        await player.stop();
        await player.setVolume(0.32);
        await player.setLoopMode(LoopMode.off);
        await player.setAsset('assets/app_ui/sounds/noti/drip_drop.mp3');
        await player.play();
      } catch (e) {
        callLog('RoomMedia', 'join chime playback failed: $e');
      }
    }());
  }

  void _rebuildParticipantBindingsFromRoom() {
    final room = _room;
    final session = _session;
    if (room == null || session == null) {
      if (_participantBindings.isNotEmpty ||
          _participantBindingsSignature.isNotEmpty) {
        _participantBindings = const <String, _LiveKitParticipantBinding>{};
        _participantBindingsSignature = '';
        _runtimeRevision += 1;
      }
      return;
    }

    final nextBindings = <String, _LiveKitParticipantBinding>{};
    final nextParticipants = <String, lk.Participant>{};
    final localParticipant = room.localParticipant;
    if (localParticipant != null) {
      final selfDeviceId = session.selfDeviceId.trim();
      nextBindings[selfDeviceId] = _bindingFromLocalParticipant(
        localParticipant,
      );
      nextParticipants[selfDeviceId] = localParticipant;
    }
    for (final participant in room.remoteParticipants.values) {
      final metadata = _parseParticipantMetadata(participant.metadata);
      final deviceId = metadata?.deviceId.trim() ?? '';
      if (deviceId.isEmpty) {
        continue;
      }
      nextBindings[deviceId] = _bindingFromRemoteParticipant(participant);
      nextParticipants[deviceId] = participant;
    }
    // Склад участников обновляем ВСЕГДА, даже когда подпись дорожек не
    // изменилась: громкость меняется каждый кадр, а дорожки — нет.
    _participantsByDeviceId = nextParticipants;

    final nextSignature = _participantBindingsSignatureFor(nextBindings);
    if (nextSignature == _participantBindingsSignature) {
      _participantBindings = nextBindings;
      return;
    }
    _participantBindings = nextBindings;
    _participantBindingsSignature = nextSignature;
    _runtimeRevision += 1;
  }

  _LiveKitParticipantBinding _bindingFromLocalParticipant(
    lk.LocalParticipant participant,
  ) {
    lk.VideoTrack? cameraTrack;
    lk.VideoTrack? screenShareTrack;
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is! lk.VideoTrack || publication.muted) {
        continue;
      }
      if (publication.isScreenShare) {
        screenShareTrack ??= track;
      } else {
        cameraTrack ??= track;
      }
    }
    return _LiveKitParticipantBinding(
      cameraTrack: cameraTrack,
      screenShareTrack: screenShareTrack,
    );
  }

  _LiveKitParticipantBinding _bindingFromRemoteParticipant(
    lk.RemoteParticipant participant,
  ) {
    lk.VideoTrack? cameraTrack;
    lk.VideoTrack? screenShareTrack;
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is! lk.VideoTrack ||
          publication.muted ||
          !publication.subscribed) {
        continue;
      }
      if (publication.isScreenShare) {
        screenShareTrack ??= track;
      } else {
        cameraTrack ??= track;
      }
    }
    return _LiveKitParticipantBinding(
      cameraTrack: cameraTrack,
      screenShareTrack: screenShareTrack,
    );
  }

  void _refreshState() {
    final session = _session;
    if (_disposed || session == null) {
      return;
    }
    final self = session.selfParticipant;
    if (self == null || !self.isJoined) {
      _setState(
        RoomCallLocalMediaState.idle(
          speakerEnabled: _speakerEnabled,
          usingFrontCamera: _usingFrontCamera,
        ).copyWith(
          runtimeRevision: _runtimeRevision,
          speakingRevision: _speakingRevision,
        ),
      );
      return;
    }

    final room = _room;
    final localParticipant = room?.localParticipant;
    final localBinding = _participantBindings[session.selfDeviceId.trim()];
    final runtimeConnected =
        room?.connectionState == lk.ConnectionState.connected;
    final runtimeReconnecting =
        room?.connectionState == lk.ConnectionState.reconnecting;
    final audioCaptureActive = localParticipant?.isMicrophoneEnabled() ?? false;
    final videoCaptureActive = localBinding?.cameraTrack != null;
    final screenShareActive = localBinding?.screenShareTrack != null;
    final localPreviewAvailable = videoCaptureActive || screenShareActive;

    final phase = switch (room?.connectionState) {
      lk.ConnectionState.connected => RoomCallLocalMediaPhase.ready,
      lk.ConnectionState.reconnecting => RoomCallLocalMediaPhase.ready,
      lk.ConnectionState.connecting => RoomCallLocalMediaPhase.acquiring,
      lk.ConnectionState.disconnected =>
        _statusMessageIsFatal
            ? RoomCallLocalMediaPhase.failed
            : RoomCallLocalMediaPhase.acquiring,
      null =>
        _statusMessageIsFatal
            ? RoomCallLocalMediaPhase.failed
            : RoomCallLocalMediaPhase.acquiring,
    };

    _setState(
      RoomCallLocalMediaState(
        phase: phase,
        audioCaptureActive: audioCaptureActive,
        videoCaptureActive: videoCaptureActive,
        screenShareActive: screenShareActive,
        localPreviewAvailable: localPreviewAvailable,
        speakerEnabled: _speakerEnabled,
        usingFrontCamera: _usingFrontCamera,
        runtimeConnected: runtimeConnected,
        runtimeReconnecting: runtimeReconnecting,
        runtimeRevision: _runtimeRevision,
        speakingRevision: _speakingRevision,
        errorMessage: _statusMessage,
      ),
    );
  }

  void _setStatusMessage(String? message, {required bool fatal}) {
    final normalized = _normalizeRoomMediaMessage(message);
    _statusMessage = normalized;
    _statusMessageIsFatal = normalized != null && fatal;
  }

  void _clearStatusMessage() {
    _statusMessage = null;
    _statusMessageIsFatal = false;
  }

  void _setState(RoomCallLocalMediaState next) {
    if (_disposed) {
      return;
    }
    final current = _state.value;
    if (current.phase == next.phase &&
        current.audioCaptureActive == next.audioCaptureActive &&
        current.videoCaptureActive == next.videoCaptureActive &&
        current.screenShareActive == next.screenShareActive &&
        current.localPreviewAvailable == next.localPreviewAvailable &&
        current.speakerEnabled == next.speakerEnabled &&
        current.usingFrontCamera == next.usingFrontCamera &&
        current.runtimeConnected == next.runtimeConnected &&
        current.runtimeReconnecting == next.runtimeReconnecting &&
        current.runtimeRevision == next.runtimeRevision &&
        current.speakingRevision == next.speakingRevision &&
        current.errorMessage == next.errorMessage) {
      return;
    }
    _state.value = next;
  }

  static String _participantBindingsSignatureFor(
    Map<String, _LiveKitParticipantBinding> bindings,
  ) {
    final entries = bindings.entries.toList(growable: false)
      ..sort((left, right) => left.key.compareTo(right.key));
    return entries
        .map((entry) => '${entry.key}=${entry.value.signature}')
        .join(';');
  }

  static _LiveKitParticipantMetadata? _parseParticipantMetadata(String? raw) {
    final normalized = _normalizeRoomMediaMessage(raw);
    if (normalized == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        return null;
      }
      final json = decoded.cast<String, Object?>();
      final profileId = (json['profile_id'] as String? ?? '').trim();
      final deviceId = (json['device_id'] as String? ?? '').trim();
      if (profileId.isEmpty || deviceId.isEmpty) {
        return null;
      }
      return _LiveKitParticipantMetadata(
        profileId: profileId,
        deviceId: deviceId,
      );
    } catch (_) {
      return null;
    }
  }
}

String _liveKitTrackSignature(lk.VideoTrack? track) {
  if (track == null) {
    return 'none';
  }
  try {
    final baseTrack = track as lk.Track;
    final sid = (baseTrack.sid ?? '').trim();
    if (sid.isNotEmpty) {
      return sid;
    }
  } catch (_) {}
  return track.hashCode.toString();
}

String _videoRendererBindingToken(RTCVideoRenderer renderer) {
  final stream = renderer.srcObject;
  if (stream == null) {
    return 'stream:none';
  }
  try {
    final trackIds = stream.getVideoTracks().map((track) => track.id).join(',');
    return 'stream:${stream.id}|tracks:${trackIds.isEmpty ? 'none' : trackIds}';
  } catch (_) {
    return 'stream:${stream.id}|tracks:error';
  }
}

String? _normalizeRoomMediaMessage(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
