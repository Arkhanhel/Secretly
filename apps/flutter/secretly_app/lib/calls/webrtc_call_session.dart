// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import 'dart:convert';

import '../diagnostics/diag_log.dart';
import 'call_failure.dart';
import 'call_ice_config.dart';
import 'call_log.dart';
import 'screen_share_runtime.dart';

enum CallQualityLevel { excellent, good, fair, poor }

enum CallVideoQualityPreset { hd, sd, low }

enum RemoteVideoLifecycleState {
  notExpected,
  expectedWaitingTrack,
  trackReceived,
  rendererBound,
  renderingFrames,
  failed,
}

enum RemoteVideoFailureReason {
  waitingForTrackTimeout,
  rendererBindingTimeout,
  rendererNoFrames,
}

class RemoteVideoLifecycle {
  const RemoteVideoLifecycle({required this.state, this.failureReason});

  const RemoteVideoLifecycle.notExpected()
    : state = RemoteVideoLifecycleState.notExpected,
      failureReason = null;

  const RemoteVideoLifecycle.waitingTrack()
    : state = RemoteVideoLifecycleState.expectedWaitingTrack,
      failureReason = null;

  const RemoteVideoLifecycle.trackReceived()
    : state = RemoteVideoLifecycleState.trackReceived,
      failureReason = null;

  const RemoteVideoLifecycle.rendererBound()
    : state = RemoteVideoLifecycleState.rendererBound,
      failureReason = null;

  const RemoteVideoLifecycle.renderingFrames()
    : state = RemoteVideoLifecycleState.renderingFrames,
      failureReason = null;

  const RemoteVideoLifecycle.failed(this.failureReason)
    : state = RemoteVideoLifecycleState.failed;

  static const int waitingForTrackTimeoutMs = 8000;
  static const int rendererBindingTimeoutMs = 5000;
  // Reduced from 6000ms – after the renderer is bound but delivers no frames
  // for this long, we re-attach the renderer to force native VideoSink
  // re-registration (required after flutter_webrtc's internal EglRenderer
  // release/reinit cycle that occurs when srcObject is first set).
  static const int rendererNoFramesTimeoutMs = 3000;

  final RemoteVideoLifecycleState state;
  final RemoteVideoFailureReason? failureReason;

  bool get isRenderable => state == RemoteVideoLifecycleState.renderingFrames;
  bool get isFailure => state == RemoteVideoLifecycleState.failed;

  static RemoteVideoLifecycle derive({
    required bool expectsRemoteVideo,
    required bool mediaEstablished,
    required bool hasRemoteVideoTrack,
    required bool rendererHasRemoteVideo,
    required bool rendererHasVisibleFrame,
    required bool hasInboundRemoteVideo,
    required int nowMs,
    int? expectedAtMs,
    int? trackReceivedAtMs,
    int? rendererBoundAtMs,
  }) {
    if (!expectsRemoteVideo) {
      return const RemoteVideoLifecycle.notExpected();
    }
    if (rendererHasRemoteVideo) {
      if (mediaEstablished) {
        // A bound renderer is not enough: on Android that still frequently
        // means a black Texture until the first real frame (or resize event)
        // arrives from flutter_webrtc. Keep the UI in rendererBound until we
        // have a visible-frame signal, then fail into recovery if the bind
        // stays black for too long.
        if (rendererHasVisibleFrame) {
          return const RemoteVideoLifecycle.renderingFrames();
        }
        if (rendererBoundAtMs != null &&
            (nowMs - rendererBoundAtMs) > rendererNoFramesTimeoutMs) {
          return const RemoteVideoLifecycle.failed(
            RemoteVideoFailureReason.rendererNoFrames,
          );
        }
      }
      return const RemoteVideoLifecycle.rendererBound();
    }
    if (hasRemoteVideoTrack) {
      if (mediaEstablished &&
          trackReceivedAtMs != null &&
          (nowMs - trackReceivedAtMs) > rendererBindingTimeoutMs) {
        return const RemoteVideoLifecycle.failed(
          RemoteVideoFailureReason.rendererBindingTimeout,
        );
      }
      return const RemoteVideoLifecycle.trackReceived();
    }
    if (mediaEstablished &&
        expectedAtMs != null &&
        (nowMs - expectedAtMs) > waitingForTrackTimeoutMs) {
      return const RemoteVideoLifecycle.failed(
        RemoteVideoFailureReason.waitingForTrackTimeout,
      );
    }
    return const RemoteVideoLifecycle.waitingTrack();
  }
}

class CallQualityMetrics {
  const CallQualityMetrics({
    required this.rttMs,
    required this.jitterMs,
    required this.outboundVideoBitrateKbps,
    required this.packetLossPct,
    required this.qualityLevel,
    required this.videoPreset,
  });

  const CallQualityMetrics.empty()
    : rttMs = null,
      jitterMs = null,
      outboundVideoBitrateKbps = null,
      packetLossPct = null,
      qualityLevel = CallQualityLevel.good,
      videoPreset = CallVideoQualityPreset.hd;

  final double? rttMs;
  final double? jitterMs;
  final double? outboundVideoBitrateKbps;
  final double? packetLossPct;
  final CallQualityLevel qualityLevel;
  final CallVideoQualityPreset videoPreset;

  CallQualityMetrics copyWith({
    double? rttMs,
    double? jitterMs,
    double? outboundVideoBitrateKbps,
    double? packetLossPct,
    CallQualityLevel? qualityLevel,
    CallVideoQualityPreset? videoPreset,
  }) {
    return CallQualityMetrics(
      rttMs: rttMs ?? this.rttMs,
      jitterMs: jitterMs ?? this.jitterMs,
      outboundVideoBitrateKbps:
          outboundVideoBitrateKbps ?? this.outboundVideoBitrateKbps,
      packetLossPct: packetLossPct ?? this.packetLossPct,
      qualityLevel: qualityLevel ?? this.qualityLevel,
      videoPreset: videoPreset ?? this.videoPreset,
    );
  }
}

class WebRtcCallSession {
  WebRtcCallSession();

  @visibleForTesting
  static CallVideoQualityPreset preferredInitialVideoPreset({
    required bool requestedVideo,
  }) {
    return requestedVideo
        ? CallVideoQualityPreset.sd
        : CallVideoQualityPreset.low;
  }

  @visibleForTesting
  static List<RTCRtpCodecCapability> selectPreferredVideoCodecCapabilities(
    List<RTCRtpCodecCapability> codecs,
  ) {
    if (codecs.isEmpty) {
      return const <RTCRtpCodecCapability>[];
    }
    final hasSaferAlternative = codecs.any((codec) {
      final mimeType = codec.mimeType.toLowerCase().trim();
      return mimeType == 'video/vp8' ||
          mimeType == 'video/vp9' ||
          mimeType == 'video/av1' ||
          mimeType == 'video/av01';
    });
    if (!hasSaferAlternative) {
      return List<RTCRtpCodecCapability>.from(codecs);
    }
    final indexed = codecs.asMap().entries.toList(growable: false);
    int codecWeight(RTCRtpCodecCapability codec) {
      final mimeType = codec.mimeType.toLowerCase().trim();
      if (mimeType == 'video/vp8') return 0;
      if (mimeType == 'video/vp9') return 1;
      if (mimeType == 'video/av1' || mimeType == 'video/av01') return 2;
      if (mimeType == 'video/rtx' ||
          mimeType == 'video/red' ||
          mimeType == 'video/ulpfec' ||
          mimeType == 'video/flexfec-03') {
        return 3;
      }
      if (mimeType == 'video/h264') return 4;
      return 5;
    }

    indexed.sort((left, right) {
      final byWeight = codecWeight(
        left.value,
      ).compareTo(codecWeight(right.value));
      if (byWeight != 0) {
        return byWeight;
      }
      return left.key.compareTo(right.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  List<Map<String, Object?>> _iceServers = const <Map<String, Object?>>[];
  String _iceTransportPolicy = 'all';
  CallNetworkPolicy _networkPolicy = CallNetworkPolicy.p2pPreferred;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  final ValueNotifier<RTCPeerConnectionState?> connectionState =
      ValueNotifier<RTCPeerConnectionState?>(null);
  final ValueNotifier<RTCIceConnectionState?> iceConnectionState =
      ValueNotifier<RTCIceConnectionState?>(null);
  final ValueNotifier<bool> mediaEstablished = ValueNotifier<bool>(false);
  final ValueNotifier<RemoteVideoLifecycle> remoteVideoLifecycle =
      ValueNotifier<RemoteVideoLifecycle>(
        const RemoteVideoLifecycle.notExpected(),
      );
  final ValueNotifier<CallQualityMetrics> qualityMetrics =
      ValueNotifier<CallQualityMetrics>(const CallQualityMetrics.empty());

  bool get hasRemoteDescription => _remoteDescriptionSet;
  bool get hasLocalVideoTrack =>
      _localStream?.getVideoTracks().isNotEmpty ?? false;

  bool _initialized = false;
  Timer? _statsTimer;
  int? _lastVideoBytesSent;
  int? _lastPacketsLost;
  int? _lastPacketsReceived;
  int _lastSampleAtMs = 0;
  int _lastIceDiagnosticsLogAtMs = 0;
  bool _isVideoEnabled = false;
  bool _expectsRemoteVideo = false;
  bool _speakerEnabled = false;
  bool _remoteDescriptionSet = false;
  bool _hasRemoteVideoTrack = false;
  bool _remoteRendererHasVisibleFrame = false;
  bool _lastHasInboundRemoteVideo = false;
  final List<RTCIceCandidate> _pendingRemoteCandidates = <RTCIceCandidate>[];
  CallVideoQualityPreset _videoPreset = CallVideoQualityPreset.hd;
  RTCRtpSender? _videoSender;
  RTCRtpTransceiver? _audioTransceiver;
  RTCRtpTransceiver? _videoTransceiver;
  List<RTCRtpCodecCapability>? _preferredVideoCodecCapabilities;
  MediaStream? _upgradedVideoStream;
  Future<String?>? _activeLocalOfferOperation;
  MediaStream? _syntheticRemoteVideoStream;
  int _consecutivePoorVideoSamples = 0;
  int _lastRemoteVideoRecoveryAttemptMs = 0;
  int? _remoteVideoExpectedAtMs;
  int? _remoteVideoTrackReceivedAtMs;
  int? _remoteVideoRendererBoundAtMs;
  String _boundRemoteVideoTrackId = '';
  String _debugCallId = '';
  String _debugCallAttemptId = '';
  // Which call attempt this session was created for — lets CallManager
  // detect a would-be "reuse" of a session that actually belongs to a
  // DIFFERENT, already-ended call (see _createSession's re-entry guard).
  String get debugCallAttemptId => _debugCallAttemptId;

  // Screen share state
  MediaStream? _screenStream;
  MediaStreamTrack? _priorVideoTrack;
  ScreenShareRuntimeLease? _screenShareLease;
  VoidCallback? onScreenShareStopped;

  Future<void> initializeRenderers() async {
    if (_initialized) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    remoteRenderer.onFirstFrameRendered = () {
      _markRemoteVideoVisible(source: 'first_frame_rendered');
    };
    remoteRenderer.onResize = () {
      _markRemoteVideoVisible(source: 'renderer_resize');
    };
    _initialized = true;
  }

  void attachDebugContext({
    required String callId,
    required String callAttemptId,
  }) {
    _debugCallId = callId.trim();
    _debugCallAttemptId = callAttemptId.trim().isEmpty
        ? _debugCallId
        : callAttemptId.trim();
  }

  @visibleForTesting
  static String normalizeIceTransportPolicy(String iceTransportPolicy) {
    final normalized = iceTransportPolicy.trim().toLowerCase();
    return normalized == 'relay' ? 'relay' : 'all';
  }

  @visibleForTesting
  static Map<String, Object?> normalizeRtcIceServer(
    Map<String, Object?> iceServer,
  ) {
    final urls = <String>[];
    final rawUrls = iceServer['urls'];
    if (rawUrls is String) {
      final value = rawUrls.trim();
      if (value.isNotEmpty) {
        urls.add(value);
      }
    } else if (rawUrls is Iterable) {
      for (final value in rawUrls) {
        final text = (value as Object?)?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          urls.add(text);
        }
      }
    }

    final username = iceServer['username']?.toString().trim() ?? '';
    final credential = iceServer['credential']?.toString().trim() ?? '';

    return <String, Object?>{
      'urls': urls.length == 1 ? urls.first : urls,
      if (username.isNotEmpty) 'username': username,
      if (credential.isNotEmpty) 'credential': credential,
    };
  }

  @visibleForTesting
  static List<Map<String, Object?>> normalizeRtcIceServers(
    List<Map<String, Object?>> iceServers,
  ) {
    return List<Map<String, Object?>>.unmodifiable(
      iceServers.map(normalizeRtcIceServer).toList(growable: false),
    );
  }

  @visibleForTesting
  static Map<String, Object?> buildPeerConnectionConfiguration({
    required List<Map<String, Object?>> iceServers,
    required String iceTransportPolicy,
  }) {
    return <String, Object?>{
      'iceServers': normalizeRtcIceServers(iceServers),
      'sdpSemantics': 'unified-plan',
      'iceTransportPolicy': normalizeIceTransportPolicy(iceTransportPolicy),
    };
  }

  @visibleForTesting
  static bool shouldApplyRuntimeIceConfiguration({
    required List<Map<String, Object?>> currentIceServers,
    required String currentIceTransportPolicy,
    required List<Map<String, Object?>> nextIceServers,
    required String nextIceTransportPolicy,
  }) {
    final currentConfiguration = buildPeerConnectionConfiguration(
      iceServers: currentIceServers,
      iceTransportPolicy: currentIceTransportPolicy,
    );
    final nextConfiguration = buildPeerConnectionConfiguration(
      iceServers: nextIceServers,
      iceTransportPolicy: nextIceTransportPolicy,
    );
    return jsonEncode(currentConfiguration) != jsonEncode(nextConfiguration);
  }

  void configureIce({
    required List<Map<String, Object?>> iceServers,
    required String iceTransportPolicy,
    required CallNetworkPolicy networkPolicy,
  }) {
    if (_peerConnection != null) {
      throw StateError(
        'configureIce must be called before peer connection setup',
      );
    }
    _iceServers = normalizeRtcIceServers(iceServers);
    _iceTransportPolicy = normalizeIceTransportPolicy(iceTransportPolicy);
    _networkPolicy = networkPolicy;
  }

  Future<bool> applyIceConfiguration({
    required List<Map<String, Object?>> iceServers,
    required String iceTransportPolicy,
    required CallNetworkPolicy networkPolicy,
  }) async {
    final normalizedIceServers = normalizeRtcIceServers(iceServers);
    final normalizedIceTransportPolicy = normalizeIceTransportPolicy(
      iceTransportPolicy,
    );
    final shouldApplyRuntimeUpdate = shouldApplyRuntimeIceConfiguration(
      currentIceServers: _iceServers,
      currentIceTransportPolicy: _iceTransportPolicy,
      nextIceServers: normalizedIceServers,
      nextIceTransportPolicy: normalizedIceTransportPolicy,
    );

    _iceServers = normalizedIceServers;
    _iceTransportPolicy = normalizedIceTransportPolicy;
    _networkPolicy = networkPolicy;

    final pc = _peerConnection;
    if (pc == null || !shouldApplyRuntimeUpdate) {
      return false;
    }

    final configuration = buildPeerConnectionConfiguration(
      iceServers: _iceServers,
      iceTransportPolicy: _iceTransportPolicy,
    );
    callOpLog(
      'WebRTC',
      'peer_connection_configuration_update_start',
      fields: _debugFields(<String, Object?>{
        'iceServerCount': _iceServers.length,
        'iceTransportPolicy': _iceTransportPolicy,
        'networkPolicy': _networkPolicy.name,
      }),
    );
    try {
      await pc.setConfiguration(Map<String, dynamic>.from(configuration));
      callOpLog(
        'WebRTC',
        'peer_connection_configuration_update_applied',
        fields: _debugFields(<String, Object?>{
          'iceServerCount': _iceServers.length,
          'iceTransportPolicy': _iceTransportPolicy,
          'networkPolicy': _networkPolicy.name,
        }),
      );
      callLog(
        'WebRTC',
        'applied runtime ICE configuration update policy=$_iceTransportPolicy servers=${_iceServers.length}',
      );
      return true;
    } catch (e) {
      callOpLog(
        'WebRTC',
        'peer_connection_configuration_update_failed',
        fields: _debugFields(<String, Object?>{
          'iceServerCount': _iceServers.length,
          'iceTransportPolicy': _iceTransportPolicy,
          'networkPolicy': _networkPolicy.name,
          'error': '$e',
        }),
      );
      rethrow;
    }
  }

  Map<String, Object?> _debugFields([
    Map<String, Object?> extra = const <String, Object?>{},
  ]) {
    return <String, Object?>{
      'callId': _debugCallId,
      'callAttemptId': _debugCallAttemptId,
      ...extra,
    };
  }

  void _updateRemoteVideoLifecycle(
    RemoteVideoLifecycle next, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    final previous = remoteVideoLifecycle.value;
    if (previous.state == next.state &&
        previous.failureReason == next.failureReason) {
      return;
    }
    remoteVideoLifecycle.value = next;
    switch (next.state) {
      case RemoteVideoLifecycleState.notExpected:
        callLog('WebRTC', 'remote video lifecycle reset to not_expected');
        break;
      case RemoteVideoLifecycleState.expectedWaitingTrack:
        callOpLog(
          'WebRTC',
          'remote_video_waiting_for_track',
          fields: _debugFields(extra),
        );
        break;
      case RemoteVideoLifecycleState.trackReceived:
        callOpLog(
          'WebRTC',
          'remote_video_track_received',
          fields: _debugFields(extra),
        );
        break;
      case RemoteVideoLifecycleState.rendererBound:
        callOpLog(
          'WebRTC',
          'remote_video_renderer_bound',
          fields: _debugFields(extra),
        );
        break;
      case RemoteVideoLifecycleState.renderingFrames:
        callOpLog(
          'WebRTC',
          'remote_video_rendering_started',
          fields: _debugFields(extra),
        );
        break;
      case RemoteVideoLifecycleState.failed:
        callOpLog(
          'WebRTC',
          'remote_video_rendering_failed',
          fields: _debugFields(<String, Object?>{
            'failureReason': next.failureReason?.name,
            ...extra,
          }),
        );
        break;
    }
  }

  void _setRemoteVideoExpectation(bool expectsRemoteVideo) {
    _expectsRemoteVideo = expectsRemoteVideo;
    _hasRemoteVideoTrack = false;
    _remoteRendererHasVisibleFrame = false;
    _lastHasInboundRemoteVideo = false;
    _boundRemoteVideoTrackId = '';
    _remoteVideoTrackReceivedAtMs = null;
    _remoteVideoRendererBoundAtMs = null;
    if (!expectsRemoteVideo) {
      _remoteVideoExpectedAtMs = null;
      _updateRemoteVideoLifecycle(const RemoteVideoLifecycle.notExpected());
      return;
    }
    _remoteVideoExpectedAtMs = DateTime.now().millisecondsSinceEpoch;
    _updateRemoteVideoLifecycle(const RemoteVideoLifecycle.waitingTrack());
  }

  void _refreshRemoteVideoLifecycle({bool? hasInboundRemoteVideo, int? nowMs}) {
    if (hasInboundRemoteVideo != null) {
      _lastHasInboundRemoteVideo = hasInboundRemoteVideo;
    }
    final next = RemoteVideoLifecycle.derive(
      expectsRemoteVideo: _expectsRemoteVideo,
      mediaEstablished: mediaEstablished.value,
      hasRemoteVideoTrack: _hasRemoteVideoTrack,
      rendererHasRemoteVideo: _rendererHasRemoteVideo(),
      rendererHasVisibleFrame: _remoteRendererHasVisibleFrame,
      hasInboundRemoteVideo: _lastHasInboundRemoteVideo,
      nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
      expectedAtMs: _remoteVideoExpectedAtMs,
      trackReceivedAtMs: _remoteVideoTrackReceivedAtMs,
      rendererBoundAtMs: _remoteVideoRendererBoundAtMs,
    );
    _updateRemoteVideoLifecycle(next);
  }

  @visibleForTesting
  static Map<String, dynamic> buildVideoCaptureConstraints({
    required bool withAudio,
    required CallVideoQualityPreset preset,
  }) {
    late final int idealWidth;
    late final int minWidth;
    late final int idealHeight;
    late final int minHeight;
    late final int idealFrameRate;
    late final int minFrameRate;

    switch (preset) {
      case CallVideoQualityPreset.hd:
        idealWidth = 1280;
        minWidth = 960;
        idealHeight = 720;
        minHeight = 540;
        idealFrameRate = 24;
        minFrameRate = 20;
        break;
      case CallVideoQualityPreset.sd:
        idealWidth = 960;
        minWidth = 640;
        idealHeight = 540;
        minHeight = 360;
        idealFrameRate = 20;
        minFrameRate = 15;
        break;
      case CallVideoQualityPreset.low:
        idealWidth = 640;
        minWidth = 480;
        idealHeight = 360;
        minHeight = 270;
        idealFrameRate = 15;
        minFrameRate = 12;
        break;
    }

    return <String, dynamic>{
      'audio': withAudio,
      'video': <String, dynamic>{
        'facingMode': 'user',
        'width': <String, dynamic>{'ideal': idealWidth, 'min': minWidth},
        'height': <String, dynamic>{'ideal': idealHeight, 'min': minHeight},
        'frameRate': <String, dynamic>{
          'ideal': idealFrameRate,
          'min': minFrameRate,
        },
      },
    };
  }

  Map<String, dynamic> _videoCaptureConstraints({required bool withAudio}) {
    return buildVideoCaptureConstraints(
      withAudio: withAudio,
      preset: _videoPreset,
    );
  }

  Future<void> startOutgoing({
    required bool video,
    required Future<void> Function(String sdp) onOffer,
    required Future<void> Function(
      String candidate,
      String? sdpMid,
      int? sdpMLineIndex,
    )
    onIceCandidate,
  }) async {
    await _setupPeerConnection(video: video, onIceCandidate: onIceCandidate);
    await _createAndSendOffer(
      video: video,
      onOffer: onOffer,
      iceRestart: false,
    );
    _speakerEnabled = video;
    await _applySpeakerRoute();
  }

  Future<void> startIncomingFromOffer({
    required bool video,
    required String remoteOfferSdp,
    required Future<void> Function(String sdp) onAnswer,
    required Future<void> Function(
      String candidate,
      String? sdpMid,
      int? sdpMLineIndex,
    )
    onIceCandidate,
  }) async {
    callLog('WebRTC', '[OP] event=incoming_offer_processing_start');
    callLog(
      'WebRTC',
      'startIncomingFromOffer video=$video sdpLen=${remoteOfferSdp.length}',
    );
    await _setupPeerConnection(video: video, onIceCandidate: onIceCandidate);
    callLog('WebRTC', 'peer connection ready');

    final pc = _peerConnection;
    if (pc == null) {
      callLog('WebRTC', 'ERROR: _peerConnection is null after setup');
      return;
    }

    final normalizedOfferSdp = _normalizeSdp(remoteOfferSdp);
    final sdpLines = normalizedOfferSdp.split('\r\n');
    final hasAudioMLine = sdpLines.any((l) => l.startsWith('m=audio'));
    final hasVideoMLine = sdpLines.any((l) => l.startsWith('m=video'));
    final remoteOffersSendingVideo = remoteDescriptionRequestsSendingVideo(
      normalizedOfferSdp,
    );
    callLog(
      'WebRTC',
      'remote offer normalized: len=${normalizedOfferSdp.length}, startsWithV=${normalizedOfferSdp.startsWith('v=')}, audioM=$hasAudioMLine, videoM=$hasVideoMLine, remoteSendsVideo=$remoteOffersSendingVideo, preview=${base64Encode(utf8.encode(normalizedOfferSdp.substring(0, normalizedOfferSdp.length > 80 ? 80 : normalizedOfferSdp.length)))}',
    );
    if (!normalizedOfferSdp.startsWith('v=')) {
      throw CallFailure(
        CallFailureCode.invalidRemoteOffer,
        message: 'Incoming SDP is invalid (missing v= line)',
      );
    }
    if (!hasAudioMLine && !hasVideoMLine) {
      throw CallFailure(
        CallFailureCode.invalidRemoteOffer,
        message: 'Incoming SDP is invalid (no media m-lines)',
      );
    }
    if (hasVideoMLine) {
      _setRemoteVideoExpectation(remoteOffersSendingVideo);
    }
    final signalingBeforeOffer = await _readSignalingState(pc);
    callLog('WebRTC', 'signaling before remote offer: $signalingBeforeOffer');
    if (signalingBeforeOffer == 'have-local-offer') {
      final rolledBack = await _tryRollbackLocalOffer(pc);
      if (rolledBack) {
        _invalidateVideoTransportAfterRollback(
          reason: 'startIncomingFromOffer_pre_remote_offer',
        );
      }
      callLog(
        'WebRTC',
        rolledBack
            ? 'local offer rolled back before applying remote offer'
            : 'local rollback not applied',
      );
    }

    await _setRemoteDescriptionRobust(
      pc: pc,
      type: 'offer',
      rawSdp: remoteOfferSdp,
    );
    callLog('WebRTC', 'remote description set');
    _remoteDescriptionSet = true;
    await _flushPendingRemoteIce();
    if (hasVideoMLine) {
      await _ensureVideoReceiveTransceiver(pc);
    }
    if (shouldPrepareLocalVideoForIncomingOffer(
      requestedLocalVideo: video,
      localVideoAlreadyPresent:
          _localStream?.getVideoTracks().isNotEmpty ?? false,
    )) {
      callOpLog(
        'WebRTC',
        'incoming_offer_prepare_local_video',
        fields: _debugFields(<String, Object?>{
          'requestedLocalVideo': video,
          'remoteOffersSendingVideo': remoteOffersSendingVideo,
        }),
      );
      callLog(
        'WebRTC',
        'preparing local video track for incoming offer before answer',
      );
      await addVideoTrack();
    }
    final answer = await pc.createAnswer(<String, dynamic>{});
    await pc.setLocalDescription(answer);
    final answerSdp =
        await _readLocalDescriptionSdp(pc, expectedType: 'answer') ??
        answer.sdp ??
        '';
    callLog('WebRTC', 'local description set (answer)');
    _speakerEnabled = video || remoteOffersSendingVideo;
    await _applySpeakerRoute();
    await onAnswer(answerSdp);
    callLog('WebRTC', '[OP] event=incoming_offer_processing_done');
    callLog('WebRTC', 'startIncomingFromOffer done');
  }

  String _normalizeSdp(String sdp) {
    var value = sdp.trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    if (value.contains('\\r\\n')) {
      value = value.replaceAll('\\r\\n', '\r\n');
    }
    if (value.contains('\\n')) {
      value = value.replaceAll('\\n', '\n');
    }
    value = value.replaceAll('\u0000', '');

    // Normalize line endings strictly to CRLF as expected by native WebRTC parsers.
    value = value.replaceAll('\r\n', '\n');
    value = value.replaceAll('\r', '\n');
    final lines = value
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return '';
    return '${lines.join('\r\n')}\r\n';
  }

  static bool remoteDescriptionRequestsSendingVideo(String sdp) {
    final normalized = _normalizeStaticSdp(sdp);
    if (normalized.isEmpty) {
      return false;
    }

    final lines = normalized.split('\r\n');
    var inVideoSection = false;
    String? direction;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith('m=')) {
        inVideoSection = line.startsWith('m=video');
        if (inVideoSection) {
          direction = null;
        } else if (direction != null) {
          break;
        }
        continue;
      }
      if (!inVideoSection) {
        continue;
      }
      if (line == 'a=sendrecv' ||
          line == 'a=sendonly' ||
          line == 'a=recvonly' ||
          line == 'a=inactive') {
        direction = line.substring(2);
      }
    }

    if (!inVideoSection &&
        direction == null &&
        !normalized.contains('m=video')) {
      return false;
    }

    final effectiveDirection = direction ?? 'sendrecv';
    return effectiveDirection == 'sendrecv' || effectiveDirection == 'sendonly';
  }

  static bool shouldPrepareLocalVideoForIncomingOffer({
    required bool requestedLocalVideo,
    required bool localVideoAlreadyPresent,
  }) {
    return requestedLocalVideo && !localVideoAlreadyPresent;
  }

  @visibleForTesting
  static bool isTransportConnected({
    required RTCPeerConnectionState? peerConnectionState,
    required RTCIceConnectionState? iceConnectionState,
    required bool hasSelectedCandidatePair,
  }) {
    final rtcConnected =
        peerConnectionState ==
        RTCPeerConnectionState.RTCPeerConnectionStateConnected;
    final iceConnected =
        iceConnectionState ==
            RTCIceConnectionState.RTCIceConnectionStateConnected ||
        iceConnectionState ==
            RTCIceConnectionState.RTCIceConnectionStateCompleted;
    return hasSelectedCandidatePair || rtcConnected || iceConnected;
  }

  @visibleForTesting
  static bool shouldDeclareMediaEstablished({
    required RTCPeerConnectionState? peerConnectionState,
    required RTCIceConnectionState? iceConnectionState,
    required bool hasSelectedCandidatePair,
    required bool hasInboundRemoteMedia,
  }) {
    final transportConnected = isTransportConnected(
      peerConnectionState: peerConnectionState,
      iceConnectionState: iceConnectionState,
      hasSelectedCandidatePair: hasSelectedCandidatePair,
    );
    if (!transportConnected) return false;
    if (hasInboundRemoteMedia) return true;
    // Fallback 1: RTCPeerConnectionState.connected means DTLS + ICE are both
    // fully negotiated. Audio packets ARE flowing at this point — the stats
    // poll simply hasn't caught the first inbound-rtp report yet.  Without
    // this fallback, audio-only calls never promote to "connected" because
    // there is no video-frame callback to set mediaEstablished directly.
    if (peerConnectionState ==
        RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      return true;
    }
    // Fallback 2: ICE completed with a selected candidate pair. This covers
    // flutter_webrtc platforms where RTCPeerConnectionState doesn't reliably
    // transition to Connected (a known quirk on some iOS/Android builds).
    // A selected ICE candidate pair proves a working network path exists.
    if (hasSelectedCandidatePair &&
        (iceConnectionState ==
                RTCIceConnectionState.RTCIceConnectionStateConnected ||
            iceConnectionState ==
                RTCIceConnectionState.RTCIceConnectionStateCompleted)) {
      return true;
    }
    return false;
  }

  bool _shouldResetMediaEstablishedForTransportLoss() {
    final rtcState = connectionState.value;
    final iceState = iceConnectionState.value;
    final transportConnected = isTransportConnected(
      peerConnectionState: rtcState,
      iceConnectionState: iceState,
      hasSelectedCandidatePair: false,
    );
    if (transportConnected) {
      return false;
    }
    return rtcState ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
        rtcState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
        rtcState == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
        iceState == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
        iceState == RTCIceConnectionState.RTCIceConnectionStateFailed ||
        iceState == RTCIceConnectionState.RTCIceConnectionStateClosed;
  }

  void _maybeDeclareMediaEstablishedFromTransport({required String source}) {
    if (mediaEstablished.value) return;
    final peerConnectionStateNow = connectionState.value;
    final iceConnectionStateNow = iceConnectionState.value;
    if (!shouldDeclareMediaEstablished(
      peerConnectionState: peerConnectionStateNow,
      iceConnectionState: iceConnectionStateNow,
      hasSelectedCandidatePair: false,
      hasInboundRemoteMedia: false,
    )) {
      return;
    }
    callOpLog(
      'WebRTC',
      'media_established_from_transport_state',
      fields: _debugFields(<String, Object?>{
        'source': source,
        'peerConnectionState': peerConnectionStateNow,
        'iceConnectionState': iceConnectionStateNow,
      }),
    );
    mediaEstablished.value = true;
    // Reset the poor-quality sample counter so that reconnected sessions start
    // at the highest quality preset rather than immediately degrading to 'low'.
    _consecutivePoorVideoSamples = 0;
  }

  void _resetMediaEstablishedForTransportLoss({required String source}) {
    if (!mediaEstablished.value ||
        !_shouldResetMediaEstablishedForTransportLoss()) {
      return;
    }
    callOpLog(
      'WebRTC',
      'media_established_reset',
      fields: _debugFields(<String, Object?>{'source': source}),
    );
    mediaEstablished.value = false;
    _refreshRemoteVideoLifecycle(hasInboundRemoteVideo: false);
  }

  static String _normalizeStaticSdp(String sdp) {
    var value = sdp.trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    if (value.contains('\\r\\n')) {
      value = value.replaceAll('\\r\\n', '\r\n');
    }
    if (value.contains('\\n')) {
      value = value.replaceAll('\\n', '\n');
    }
    value = value.replaceAll('\u0000', '');
    value = value.replaceAll('\r\n', '\n');
    value = value.replaceAll('\r', '\n');
    final lines = value
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return '';
    return '${lines.join('\r\n')}\r\n';
  }

  Future<void> applyRemoteAnswer(String remoteAnswerSdp) async {
    final pc = _peerConnection;
    if (pc == null || remoteAnswerSdp.trim().isEmpty) return;
    final signalingBeforeAnswer = await _readSignalingState(pc);
    if (!_canApplyRemoteAnswerInState(signalingBeforeAnswer)) {
      callLog(
        'WebRTC',
        'remote answer in signalingState=$signalingBeforeAnswer; attempting best-effort apply',
      );
    }
    final normalizedAnswerSdp = _normalizeSdp(remoteAnswerSdp);
    final sdpLines = normalizedAnswerSdp.split('\r\n');
    final hasAudioMLine = sdpLines.any((l) => l.startsWith('m=audio'));
    final hasVideoMLine = sdpLines.any((l) => l.startsWith('m=video'));
    callLog(
      'WebRTC',
      'applyRemoteAnswer len=${normalizedAnswerSdp.length}, startsWithV=${normalizedAnswerSdp.startsWith('v=')}, audioM=$hasAudioMLine, videoM=$hasVideoMLine, preview=${base64Encode(utf8.encode(normalizedAnswerSdp.substring(0, normalizedAnswerSdp.length > 80 ? 80 : normalizedAnswerSdp.length)))}',
    );
    if (!normalizedAnswerSdp.startsWith('v=')) {
      throw CallFailure(
        CallFailureCode.invalidRemoteAnswer,
        message: 'Incoming ANSWER SDP is invalid (missing v= line)',
      );
    }
    if (!hasAudioMLine && !hasVideoMLine) {
      throw CallFailure(
        CallFailureCode.invalidRemoteAnswer,
        message: 'Incoming ANSWER SDP is invalid (no media m-lines)',
      );
    }
    await _setRemoteDescriptionRobust(
      pc: pc,
      type: 'answer',
      rawSdp: remoteAnswerSdp,
    );
    _remoteDescriptionSet = true;
    await _flushPendingRemoteIce();

    // If the answer introduces remote video that we weren't already expecting
    // (i.e. an audio→video upgrade on the CALLER side), set the expectation
    // now that the remote has confirmed it will send video.  This is the
    // correct moment because:
    //   • _handleRemoteTrack may have already fired (onTrack during
    //     setRemoteDescription) and bound the renderer.
    //   • If onTrack did NOT fire for the offerer (flutter_webrtc quirk in
    //     renegotiation), _expectsRemoteVideo=true + !_rendererHasRemoteVideo()
    //     will trigger the recovery below, finding the track via the transceiver
    //     receiver path.
    if (!_expectsRemoteVideo &&
        hasVideoMLine &&
        remoteDescriptionRequestsSendingVideo(normalizedAnswerSdp)) {
      _setRemoteVideoExpectation(true);
    }

    if (_expectsRemoteVideo && !_rendererHasRemoteVideo()) {
      await _recoverRemoteVideoAttachment(
        pc,
        reason: 'apply_remote_answer',
        throttle: false,
      );
    }
    callLog('WebRTC', '[OP] event=remote_answer_applied');
    callLog('WebRTC', 'applyRemoteAnswer done');
  }

  Future<void> _setRemoteDescriptionRobust({
    required RTCPeerConnection pc,
    required String type,
    required String rawSdp,
  }) async {
    final candidates = _buildSdpCandidates(rawSdp);
    Object? lastError;

    for (var i = 0; i < candidates.length; i++) {
      final sdp = candidates[i];
      if (sdp.isEmpty) continue;
      try {
        await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
        if (i > 0) {
          callLog(
            'WebRTC',
            'setRemoteDescription($type) succeeded on fallback variant #$i',
          );
        }
        return;
      } catch (e) {
        lastError = e;
        final msg = e.toString().toLowerCase();
        callLog(
          'WebRTC',
          'setRemoteDescription($type) failed on variant #$i: $e',
        );

        if (type == 'offer' && msg.contains('have-local-offer')) {
          DiagLog.event('call', 'sdp.set_remote_offer_glare', <String, Object?>{
            'variant': i,
          });
          final rolledBack = await _tryRollbackLocalOffer(pc);
          if (rolledBack) {
            _invalidateVideoTransportAfterRollback(
              reason: 'setRemoteDescription_offer_retry',
            );
          }
          callLog(
            'WebRTC',
            rolledBack
                ? 'rollback before offer retry succeeded'
                : 'rollback before offer retry failed',
          );
          if (rolledBack) {
            try {
              await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
              callLog(
                'WebRTC',
                'setRemoteDescription(offer) succeeded after rollback retry',
              );
              DiagLog.event(
                'call',
                'sdp.set_remote_offer_retry_ok',
                <String, Object?>{},
              );
              return;
            } catch (retryError) {
              lastError = retryError;
              callLog(
                'WebRTC',
                'setRemoteDescription(offer) retry after rollback failed: $retryError',
              );
              DiagLog.event(
                'call',
                'sdp.set_remote_offer_retry_fail',
                <String, Object?>{'err': retryError.toString()},
              );
            }
          }
        }
      }
    }

    throw describeCallFailure(
      lastError ?? StateError('setRemoteDescription($type) failed'),
      fallbackCode: type == 'answer'
          ? CallFailureCode.invalidRemoteAnswer
          : CallFailureCode.invalidRemoteOffer,
    );
  }

  List<String> _buildSdpCandidates(String rawSdp) {
    final out = <String>{};
    final decoded = _decodeEscapedSdp(rawSdp);
    final rawTrimmed = rawSdp.trim();

    for (final source in [decoded, rawTrimmed]) {
      if (source.isEmpty) continue;
      out.add(_normalizeSdp(source));

      final lf = source
          .replaceAll('\\r\\n', '\n')
          .replaceAll('\\r', '\n')
          .trim();
      if (lf.isNotEmpty) {
        out.add(
          '${lf.split('\n').where((l) => l.isNotEmpty).join('\r\n')}\r\n',
        );
      }

      final crlfOnly = source.replaceAll('\r', '').trim();
      if (crlfOnly.isNotEmpty) {
        out.add(
          '${crlfOnly.split('\n').where((l) => l.isNotEmpty).join('\r\n')}\r\n',
        );
      }
    }

    return out.where((s) => s.isNotEmpty).toList(growable: false);
  }

  String _decodeEscapedSdp(String sdp) {
    var value = sdp.trim();
    if (value.isEmpty) return value;

    for (var i = 0; i < 2; i++) {
      if ((value.startsWith('"') && value.endsWith('"')) ||
          value.contains('\\r\\n') ||
          value.contains('\\n')) {
        try {
          final jsonWrapped = value.startsWith('"')
              ? value
              : '"${value.replaceAll('"', '\\"')}"';
          final decoded = jsonDecode(jsonWrapped);
          if (decoded is String && decoded.trim().isNotEmpty) {
            value = decoded.trim();
            continue;
          }
        } catch (_) {
          // keep best-effort variants below
        }
      }
      break;
    }

    return value;
  }

  Future<bool> isAwaitingRemoteAnswer() async {
    final pc = _peerConnection;
    if (pc == null) return false;
    final state = await _readSignalingState(pc);
    return _canApplyRemoteAnswerInState(state);
  }

  bool _canApplyRemoteAnswerInState(String state) {
    return state.isEmpty ||
        state == 'have-local-offer' ||
        state == 'have-remote-pranswer';
  }

  Future<bool> _tryRollbackLocalOffer(RTCPeerConnection pc) async {
    final stateBefore = await _readSignalingState(pc);
    try {
      await pc.setLocalDescription(RTCSessionDescription('', 'rollback'));
      final stateAfter = await _readSignalingState(pc);
      DiagLog.event('call', 'sdp.rollback_ok', <String, Object?>{
        'state_before': stateBefore,
        'state_after': stateAfter,
      });
      return true;
    } catch (e) {
      callLog('WebRTC', 'rollback failed: $e');
      DiagLog.event('call', 'sdp.rollback_fail', <String, Object?>{
        'state_before': stateBefore,
        'err': e.toString(),
      });
      return false;
    }
  }

  Future<String> _readSignalingState(RTCPeerConnection pc) async {
    try {
      final dynamic dyn = pc;
      final dynamic value = dyn.signalingState;
      final parsed = _normalizeSignalingState(value);
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {
      // ignore
    }

    try {
      final dynamic dyn = pc;
      final dynamic value = await dyn.getSignalingState();
      final parsed = _normalizeSignalingState(value);
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {
      // ignore
    }

    return '';
  }

  String _normalizeSignalingState(dynamic value) {
    if (value == null) return '';
    final raw = value.toString();
    if (raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    if (lower.contains('have-local-offer')) return 'have-local-offer';
    if (lower.contains('have-remote-offer')) return 'have-remote-offer';
    if (lower.contains('have-local-pranswer')) return 'have-local-pranswer';
    if (lower.contains('have-remote-pranswer')) return 'have-remote-pranswer';
    if (lower.contains('stable')) return 'stable';
    if (lower.contains('closed')) return 'closed';
    return lower;
  }

  Future<void> setSpeakerEnabled(bool enabled) async {
    _speakerEnabled = enabled;
    await _applySpeakerRoute();
  }

  Future<void> setAudioEnabled(bool enabled) async {
    final stream = _localStream;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      track.enabled = enabled;
    }
  }

  Future<void> setVideoEnabled(bool enabled) async {
    final stream = _localStream;
    if (stream == null) return;
    for (final track in stream.getVideoTracks()) {
      track.enabled = enabled;
    }
    _isVideoEnabled = enabled;
  }

  Future<void> switchCamera() async {
    final stream = _localStream;
    if (stream == null) return;
    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
  }

  Future<void> restartIce({
    required bool video,
    required Future<void> Function(String sdp) onOffer,
  }) async {
    await _createAndSendOffer(video: video, onOffer: onOffer, iceRestart: true);
  }

  Future<void> renegotiate({
    required bool video,
    required Future<void> Function(String sdp) onOffer,
  }) async {
    await _createAndSendOffer(
      video: video,
      onOffer: onOffer,
      iceRestart: false,
    );
  }

  Future<void> _createAndSendOffer({
    required bool video,
    required Future<void> Function(String sdp) onOffer,
    required bool iceRestart,
  }) async {
    final inFlight = _activeLocalOfferOperation;
    // Only reuse an in-flight offer when ICE restart is NOT requested.
    // An iceRestart offer must carry a fresh ICE ufrag/pwd in the SDP;
    // reusing the previous non-restart offer would silently skip the restart
    // and leave the transport stuck on the old failed candidate pair.
    if (inFlight != null && !iceRestart) {
      final sdp = await inFlight;
      if (sdp != null && sdp.isNotEmpty) {
        callLog('WebRTC', 'reused in-flight local offer');
        await onOffer(sdp);
      }
      return;
    }

    final op = _buildLocalOffer(video: video, iceRestart: iceRestart);
    _activeLocalOfferOperation = op;
    final sdp = await op;
    if (identical(_activeLocalOfferOperation, op)) {
      _activeLocalOfferOperation = null;
    }
    if (sdp == null || sdp.isEmpty) {
      throw CallFailure(
        CallFailureCode.localOfferUnavailable,
        message: 'Local offer generation returned empty SDP',
      );
    }
    await onOffer(sdp);
  }

  Future<String?> _buildLocalOffer({
    required bool video,
    required bool iceRestart,
  }) async {
    final pc = _peerConnection;
    if (pc == null) return null;
    final signalingState = await _readSignalingState(pc);
    if (signalingState == 'have-local-offer') {
      final existingSdp = await _readLocalOfferSdp(pc);
      if (existingSdp != null && existingSdp.isNotEmpty) {
        callLog('WebRTC', 'reusing existing pending local offer');
        return existingSdp;
      }
      throw CallFailure(
        CallFailureCode.signalingConflict,
        message:
            'Cannot create a replacement offer while a local offer is still pending',
      );
    } else if (signalingState.isNotEmpty && signalingState != 'stable') {
      final existingSdp = await _readLocalOfferSdp(pc);
      if (existingSdp != null && existingSdp.isNotEmpty) {
        callLog(
          'WebRTC',
          'non-stable signalingState=$signalingState; reusing current local offer',
        );
        return existingSdp;
      }
      throw CallFailure(
        CallFailureCode.signalingConflict,
        message: 'Cannot create local offer in signalingState=$signalingState',
      );
    }
    final offer = await pc.createOffer({'iceRestart': iceRestart});
    await pc.setLocalDescription(offer);
    return await _readLocalDescriptionSdp(pc, expectedType: 'offer') ??
        offer.sdp;
  }

  Future<String?> _readLocalDescriptionSdp(
    RTCPeerConnection pc, {
    required String expectedType,
  }) async {
    try {
      final desc = await pc.getLocalDescription();
      if (desc == null) return null;
      final type = (desc.type ?? '').toLowerCase().trim();
      final sdp = (desc.sdp ?? '').trim();
      if (type == expectedType && sdp.isNotEmpty) {
        return sdp;
      }
    } catch (e) {
      callLog('WebRTC', 'getLocalDescription failed: $e');
    }
    return null;
  }

  Future<String?> _readLocalOfferSdp(RTCPeerConnection pc) async {
    return _readLocalDescriptionSdp(pc, expectedType: 'offer');
  }

  String _candidateTypeFromSdp(String candidate) {
    final tokens = candidate.trim().split(RegExp(r'\s+'));
    final typIndex = tokens.indexOf('typ');
    if (typIndex >= 0 && typIndex + 1 < tokens.length) {
      return tokens[typIndex + 1].trim().toLowerCase();
    }
    return 'unknown';
  }

  String _candidateProtocolFromSdp(String candidate) {
    final tokens = candidate.trim().split(RegExp(r'\s+'));
    if (tokens.length >= 3) {
      return tokens[2].trim().toLowerCase();
    }
    return 'unknown';
  }

  Map<String, Object?> _iceCandidateFields({
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) {
    return <String, Object?>{
      'sdpMid': sdpMid,
      'sdpMLineIndex': sdpMLineIndex,
      'candidateType': _candidateTypeFromSdp(candidate),
      'candidateProtocol': _candidateProtocolFromSdp(candidate),
    };
  }

  Future<void> addRemoteIceCandidate({
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) async {
    if (candidate.trim().isEmpty) return;
    final rtcCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
    final pc = _peerConnection;
    // Buffer if peer connection not ready or remote description not set yet.
    if (pc == null || !_remoteDescriptionSet) {
      _pendingRemoteCandidates.add(rtcCandidate);
      callOpLog(
        'WebRTC',
        'remote_ice_candidate_buffered',
        fields: _debugFields(<String, Object?>{
          ..._iceCandidateFields(
            candidate: candidate,
            sdpMid: sdpMid,
            sdpMLineIndex: sdpMLineIndex,
          ),
          'pendingCount': _pendingRemoteCandidates.length,
          'peerConnectionReady': pc != null,
          'remoteDescriptionSet': _remoteDescriptionSet,
        }),
      );
      callLog(
        'WebRTC',
        'Buffered ICE candidate (pc=${pc != null}, rdSet=$_remoteDescriptionSet, pending=${_pendingRemoteCandidates.length})',
      );
      return;
    }
    try {
      await pc.addCandidate(rtcCandidate);
      callOpLog(
        'WebRTC',
        'remote_ice_candidate_applied',
        fields: _debugFields(
          _iceCandidateFields(
            candidate: candidate,
            sdpMid: sdpMid,
            sdpMLineIndex: sdpMLineIndex,
          ),
        ),
      );
    } catch (e) {
      callOpLog(
        'WebRTC',
        'remote_ice_candidate_apply_failed',
        fields: _debugFields(<String, Object?>{
          ..._iceCandidateFields(
            candidate: candidate,
            sdpMid: sdpMid,
            sdpMLineIndex: sdpMLineIndex,
          ),
          'error': '$e',
        }),
      );
      rethrow;
    }
  }

  Future<void> _setupPeerConnection({
    required bool video,
    required Future<void> Function(
      String candidate,
      String? sdpMid,
      int? sdpMLineIndex,
    )
    onIceCandidate,
  }) async {
    if (_peerConnection != null) {
      callLog('WebRTC', 'already have peer connection, skipping');
      return;
    }

    callLog('WebRTC', 'initializing renderers');
    await initializeRenderers();

    callLog('WebRTC', 'creating peer connection');
    callOpLog(
      'WebRTC',
      'peer_connection_create_start',
      fields: _debugFields(<String, Object?>{
        'requestedVideo': video,
        'iceServerCount': _iceServers.length,
        'iceTransportPolicy': _iceTransportPolicy,
        'networkPolicy': _networkPolicy.name,
      }),
    );
    final configuration = buildPeerConnectionConfiguration(
      iceServers: _iceServers,
      iceTransportPolicy: _iceTransportPolicy,
    );
    final pc = await createPeerConnection(
      Map<String, dynamic>.from(configuration),
    );
    callLog('WebRTC', 'peer connection created');

    pc.onConnectionState = (state) {
      callOpLog(
        'WebRTC',
        'connection_state_changed',
        fields: _debugFields(<String, Object?>{'state': state}),
      );
      callLog('WebRTC', 'connectionState -> $state');
      connectionState.value = state;
      _resetMediaEstablishedForTransportLoss(
        source: 'connection_state_changed',
      );
      _maybeDeclareMediaEstablishedFromTransport(
        source: 'connection_state_changed',
      );
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
          _expectsRemoteVideo &&
          !_rendererHasRemoteVideo()) {
        unawaited(
          _recoverRemoteVideoAttachment(
            pc,
            reason: 'connection_state_connected',
            throttle: false,
          ),
        );
      }
    };

    pc.onIceConnectionState = (state) {
      callOpLog(
        'WebRTC',
        'ice_connection_state_changed',
        fields: _debugFields(<String, Object?>{'state': state}),
      );
      callLog('WebRTC', 'iceConnectionState -> $state');
      iceConnectionState.value = state;
      _resetMediaEstablishedForTransportLoss(
        source: 'ice_connection_state_changed',
      );
      _maybeDeclareMediaEstablishedFromTransport(
        source: 'ice_connection_state_changed',
      );
      if ((state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
              state == RTCIceConnectionState.RTCIceConnectionStateCompleted) &&
          _expectsRemoteVideo &&
          !_rendererHasRemoteVideo()) {
        unawaited(
          _recoverRemoteVideoAttachment(
            pc,
            reason: 'ice_connection_connected',
            throttle: false,
          ),
        );
      }
    };

    pc.onIceGatheringState = (state) {
      callOpLog(
        'WebRTC',
        'ice_gathering_state_changed',
        fields: _debugFields(<String, Object?>{'state': state}),
      );
      // When gathering is complete, the browser signals end-of-candidates by
      // emitting a null/empty candidate. flutter_webrtc may not always emit
      // that sentinel; detecting 'complete' here ensures the remote side never
      // waits indefinitely for a closing candidate.
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        callLog(
          'WebRTC',
          'ICE gathering complete — all local candidates ready',
        );
      }
    };

    pc.onIceCandidate = (candidate) {
      final c = candidate.candidate;
      if (c == null || c.isEmpty) return;
      callOpLog(
        'WebRTC',
        'local_ice_candidate_emitted',
        fields: _debugFields(
          _iceCandidateFields(
            candidate: c,
            sdpMid: candidate.sdpMid,
            sdpMLineIndex: candidate.sdpMLineIndex,
          ),
        ),
      );
      unawaited(onIceCandidate(c, candidate.sdpMid, candidate.sdpMLineIndex));
    };

    pc.onTrack = (event) {
      unawaited(_handleRemoteTrack(pc, event));
    };

    _videoPreset = preferredInitialVideoPreset(requestedVideo: video);
    callLog('WebRTC', 'getUserMedia video=$video preset=${_videoPreset.name}');
    MediaStream local;
    try {
      local = await navigator.mediaDevices.getUserMedia(
        video
            ? _videoCaptureConstraints(withAudio: true)
            : <String, dynamic>{'audio': true, 'video': false},
      );
    } catch (e) {
      callOpLog(
        'WebRTC',
        'get_user_media_failed',
        fields: _debugFields(<String, Object?>{'requestedVideo': video}),
      );
      callLog('WebRTC', 'getUserMedia FAILED: $e');
      // If video fails, try audio only.
      if (video) {
        callOpLog(
          'WebRTC',
          'get_user_media_retry_audio_only',
          fields: _debugFields(),
        );
        callLog('WebRTC', 'Retrying audio-only');
        try {
          local = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
            'audio': true,
            'video': false,
          });
        } catch (audioOnlyError) {
          throw describeCallFailure(audioOnlyError);
        }
      } else {
        throw describeCallFailure(e);
      }
    }
    callLog('WebRTC', 'getUserMedia OK, tracks=${local.getTracks().length}');

    final audioTracks = local.getAudioTracks();
    for (final track in audioTracks) {
      await _attachLocalTrack(pc: pc, stream: local, track: track);
    }
    final videoTracks = local.getVideoTracks();
    for (final track in videoTracks) {
      await _attachLocalTrack(pc: pc, stream: local, track: track);
    }
    callOpLog(
      'WebRTC',
      'local_media_ready',
      fields: _debugFields(<String, Object?>{
        'audioTracks': audioTracks.length,
        'videoTracks': videoTracks.length,
        'requestedVideo': video,
      }),
    );
    localRenderer.srcObject = local;
    _localStream = local;
    _isVideoEnabled = video;
    _setRemoteVideoExpectation(video);
    _remoteDescriptionSet = false;
    _pendingRemoteCandidates.clear();
    _peerConnection = pc;
    _startStatsSampling();
    callLog('WebRTC', 'setupPeerConnection done');
  }

  Future<RTCRtpTransceiver?> _getSendersTransceiver(
    RTCPeerConnection pc,
    String senderId,
  ) async {
    if (senderId.trim().isEmpty) return null;
    try {
      final transceivers = await pc.getTransceivers();
      for (final transceiver in transceivers) {
        if (transceiver.sender.senderId == senderId) {
          return transceiver;
        }
      }
    } catch (e) {
      callLog('WebRTC', 'getSendersTransceiver failed: $e');
    }
    return null;
  }

  Future<void> _cacheLocalSender({
    required RTCPeerConnection pc,
    required RTCRtpSender sender,
    required bool isVideo,
  }) async {
    final transceiver = await _getSendersTransceiver(pc, sender.senderId);
    if (isVideo) {
      _videoSender = sender;
      if (transceiver != null) {
        _videoTransceiver = transceiver;
        _videoSender = transceiver.sender;
      }
      return;
    }

    if (transceiver != null) {
      _audioTransceiver = transceiver;
    }
  }

  @visibleForTesting
  static bool isDisposedWebRtcHandleError(Object error) {
    final message = error.toString().toLowerCase();
    if (!message.contains('disposed')) return false;
    return message.contains('rtptransceiver') ||
        message.contains('rtcrtpsender') ||
        message.contains('rtpsender') ||
        message.contains('transceiver') ||
        message.contains('sender');
  }

  Future<RTCRtpTransceiver?> _resolveCachedVideoTransceiver(
    RTCPeerConnection pc,
  ) async {
    final sender = _videoSender;
    if (sender != null) {
      final rebound = await _getSendersTransceiver(pc, sender.senderId);
      if (rebound != null) {
        _videoTransceiver = rebound;
        _videoSender = rebound.sender;
        return rebound;
      }
    }
    final discovered = await _findExistingVideoTransceiver(pc);
    if (discovered != null) {
      _videoTransceiver = discovered;
      _videoSender = discovered.sender;
      return discovered;
    }
    return _videoTransceiver;
  }

  Future<RTCRtpTransceiver?> _findExistingVideoTransceiver(
    RTCPeerConnection pc,
  ) async {
    try {
      final transceivers = await pc.getTransceivers();
      final knownAudioSenderId = _audioTransceiver?.sender.senderId ?? '';
      for (final transceiver in transceivers) {
        final senderId = transceiver.sender.senderId;
        final senderKind = transceiver.sender.track?.kind;
        final receiverKind = transceiver.receiver.track?.kind;
        if (isLikelyVideoTransceiverCandidate(
          senderKind: senderKind,
          receiverKind: receiverKind,
          isKnownAudioTransceiver:
              knownAudioSenderId.isNotEmpty && senderId == knownAudioSenderId,
        )) {
          return transceiver;
        }
      }
    } catch (e) {
      callLog('WebRTC', 'findExistingVideoTransceiver failed: $e');
    }
    return null;
  }

  @visibleForTesting
  static bool isLikelyVideoTransceiverCandidate({
    required String? senderKind,
    required String? receiverKind,
    required bool isKnownAudioTransceiver,
  }) {
    final normalizedSenderKind = (senderKind ?? '').toLowerCase().trim();
    final normalizedReceiverKind = (receiverKind ?? '').toLowerCase().trim();
    if (normalizedSenderKind == 'video' || normalizedReceiverKind == 'video') {
      return true;
    }
    if (isKnownAudioTransceiver) {
      return false;
    }
    if (normalizedSenderKind == 'audio' || normalizedReceiverKind == 'audio') {
      return false;
    }
    return normalizedSenderKind.isEmpty && normalizedReceiverKind.isEmpty;
  }

  void _invalidateCachedVideoTransceiver({
    required String operation,
    required Object error,
  }) {
    callLog(
      'WebRTC',
      '$operation invalidated cached video transport handles: $error',
    );
    _videoTransceiver = null;
    _videoSender = null;
  }

  void _invalidateVideoTransportAfterRollback({required String reason}) {
    if (_videoTransceiver == null && _videoSender == null) {
      return;
    }
    callLog(
      'WebRTC',
      'local rollback invalidated cached video transport handles: $reason',
    );
    _videoTransceiver = null;
    _videoSender = null;
  }

  Future<RTCRtpTransceiver> _createVideoTransceiver({
    required RTCPeerConnection pc,
    required TransceiverDirection direction,
    MediaStream? stream,
    MediaStreamTrack? track,
  }) async {
    final init = RTCRtpTransceiverInit(
      direction: direction,
      streams: stream == null ? const <MediaStream>[] : <MediaStream>[stream],
    );
    final transceiver = track == null
        ? await pc.addTransceiver(
            kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init: init,
          )
        : await pc.addTransceiver(track: track, init: init);
    _videoTransceiver = transceiver;
    _videoSender = transceiver.sender;
    await _applyPreferredVideoCodecPreferences(
      transceiver: transceiver,
      operation: 'createVideoTransceiver',
    );
    callOpLog(
      'WebRTC',
      'video_transceiver_created',
      fields: _debugFields(<String, Object?>{
        'direction': direction.name,
        'hasTrack': track != null,
        'creationMode': track == null ? 'kind' : 'track',
        'streamId': stream?.id,
        'trackId': track?.id,
      }),
    );
    return transceiver;
  }

  Future<RTCRtpTransceiver> _ensureConfiguredVideoTransceiver({
    required RTCPeerConnection pc,
    required TransceiverDirection direction,
    required String operation,
    MediaStream? stream,
    MediaStreamTrack? track,
  }) async {
    var transceiver = await _resolveCachedVideoTransceiver(pc);
    if (transceiver == null) {
      return _createVideoTransceiver(
        pc: pc,
        direction: direction,
        stream: stream,
        track: track,
      );
    }

    try {
      await transceiver.setDirection(direction);
    } catch (e) {
      if (isDisposedWebRtcHandleError(e)) {
        _invalidateCachedVideoTransceiver(operation: operation, error: e);
        return _createVideoTransceiver(
          pc: pc,
          direction: direction,
          stream: stream,
          track: track,
        );
      }
      callLog('WebRTC', '$operation ignored setDirection failure: $e');
    }

    if (track != null) {
      try {
        await transceiver.sender.replaceTrack(track);
      } catch (e) {
        if (isDisposedWebRtcHandleError(e)) {
          _invalidateCachedVideoTransceiver(operation: operation, error: e);
          return _createVideoTransceiver(
            pc: pc,
            direction: direction,
            stream: stream,
            track: track,
          );
        }
        rethrow;
      }
    }

    _videoTransceiver = transceiver;
    _videoSender = transceiver.sender;
    await _applyPreferredVideoCodecPreferences(
      transceiver: transceiver,
      operation: operation,
    );
    callOpLog(
      'WebRTC',
      'video_transceiver_reused',
      fields: _debugFields(<String, Object?>{
        'operation': operation,
        'direction': direction.name,
        'hasTrack': track != null,
        'senderTrackKind': transceiver.sender.track?.kind,
        'receiverTrackKind': transceiver.receiver.track?.kind,
        'trackId': track?.id,
      }),
    );
    return transceiver;
  }

  Future<List<RTCRtpCodecCapability>> _preferredVideoCodecs() async {
    final cached = _preferredVideoCodecCapabilities;
    if (cached != null) {
      return cached;
    }
    try {
      final capabilities = await getRtpSenderCapabilities('video');
      final ordered = selectPreferredVideoCodecCapabilities(
        capabilities.codecs ?? const <RTCRtpCodecCapability>[],
      );
      _preferredVideoCodecCapabilities = ordered;
      return ordered;
    } catch (e) {
      callLog('WebRTC', 'getRtpSenderCapabilities(video) failed: $e');
      const empty = <RTCRtpCodecCapability>[];
      _preferredVideoCodecCapabilities = empty;
      return empty;
    }
  }

  Future<void> _applyPreferredVideoCodecPreferences({
    required RTCRtpTransceiver transceiver,
    required String operation,
  }) async {
    final codecs = await _preferredVideoCodecs();
    if (codecs.isEmpty) {
      return;
    }
    try {
      await transceiver.setCodecPreferences(codecs);
      callOpLog(
        'WebRTC',
        'video_codec_preferences_applied',
        fields: _debugFields(<String, Object?>{
          'operation': operation,
          'codecCount': codecs.length,
          'codecOrder': codecs.take(6).map((codec) => codec.mimeType).join(','),
        }),
      );
    } catch (e) {
      callLog('WebRTC', '$operation setCodecPreferences failed: $e');
    }
  }

  Future<void> _attachLocalTrack({
    required RTCPeerConnection pc,
    required MediaStream stream,
    required MediaStreamTrack track,
  }) async {
    final kind = (track.kind ?? '').toLowerCase().trim();
    final isVideo = kind == 'video';
    if (isVideo) {
      final transceiver = await _ensureConfiguredVideoTransceiver(
        pc: pc,
        direction: TransceiverDirection.SendRecv,
        operation: 'attachLocalTrack',
        stream: stream,
        track: track,
      );
      _videoSender = transceiver.sender;
      return;
    }
    final transceiver = isVideo ? _videoTransceiver : _audioTransceiver;
    if (transceiver != null) {
      try {
        await transceiver.setDirection(TransceiverDirection.SendRecv);
      } catch (_) {
        // Ignore runtimes that reject redundant direction changes.
      }
      await transceiver.sender.replaceTrack(track);
      if (isVideo) {
        _videoSender = transceiver.sender;
      }
      return;
    }

    final sender = await pc.addTrack(track, stream);
    await _cacheLocalSender(pc: pc, sender: sender, isVideo: isVideo);
  }

  Future<void> _flushPendingRemoteIce() async {
    final pc = _peerConnection;
    if (pc == null ||
        !_remoteDescriptionSet ||
        _pendingRemoteCandidates.isEmpty) {
      return;
    }
    final queued = List<RTCIceCandidate>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    callLog('WebRTC', 'Flushing ${queued.length} pending ICE candidates');
    for (final c in queued) {
      try {
        await pc.addCandidate(c);
        callOpLog(
          'WebRTC',
          'remote_ice_candidate_applied',
          fields: _debugFields(<String, Object?>{
            ..._iceCandidateFields(
              candidate: c.candidate ?? '',
              sdpMid: c.sdpMid,
              sdpMLineIndex: c.sdpMLineIndex,
            ),
            'source': 'flush_pending',
          }),
        );
      } catch (e) {
        callOpLog(
          'WebRTC',
          'remote_ice_candidate_apply_failed',
          fields: _debugFields(<String, Object?>{
            ..._iceCandidateFields(
              candidate: c.candidate ?? '',
              sdpMid: c.sdpMid,
              sdpMLineIndex: c.sdpMLineIndex,
            ),
            'source': 'flush_pending',
            'error': '$e',
          }),
        );
        callLog('WebRTC', 'addCandidate failed: $e');
      }
    }
  }

  Future<void> _ensureVideoReceiveTransceiver(RTCPeerConnection pc) async {
    final stream = _localStream;
    final hasLocalVideoTrack = stream?.getVideoTracks().isNotEmpty ?? false;
    if (!hasLocalVideoTrack) {
      final transceiver = await _resolveCachedVideoTransceiver(pc);
      if (transceiver == null) {
        callLog(
          'WebRTC',
          'video receive transceiver not yet discoverable; waiting for onTrack',
        );
        return;
      }
      try {
        await transceiver.setDirection(TransceiverDirection.RecvOnly);
      } catch (e) {
        if (isDisposedWebRtcHandleError(e)) {
          _invalidateCachedVideoTransceiver(
            operation: 'ensureVideoReceiveTransceiver',
            error: e,
          );
          callLog(
            'WebRTC',
            'video receive transceiver disposed before answer; waiting for onTrack',
          );
          return;
        }
        callLog(
          'WebRTC',
          'ensureVideoReceiveTransceiver ignored setDirection failure: $e',
        );
      }
      _videoTransceiver = transceiver;
      _videoSender = transceiver.sender;
      await _applyPreferredVideoCodecPreferences(
        transceiver: transceiver,
        operation: 'ensureVideoReceiveTransceiver',
      );
      callLog('WebRTC', 'video transceiver prepared for incoming remote video');
      return;
    }

    await _ensureConfiguredVideoTransceiver(
      pc: pc,
      direction: TransceiverDirection.SendRecv,
      operation: 'ensureVideoReceiveTransceiver',
      stream: stream,
      track: stream!.getVideoTracks().first,
    );
    callLog('WebRTC', 'video transceiver prepared for incoming remote video');
  }

  Future<MediaStream> _createSyntheticRemoteVideoStream({
    required MediaStreamTrack track,
    required String reason,
  }) async {
    final previous = _syntheticRemoteVideoStream;
    if (previous != null) {
      for (final oldTrack in List<MediaStreamTrack>.from(
        previous.getVideoTracks(),
      )) {
        try {
          await previous.removeTrack(oldTrack);
        } catch (e) {
          callLog(
            'WebRTC',
            'synthetic remote stream cleanup failed reason=$reason trackId=${oldTrack.id}: $e',
          );
        }
      }
    }

    final synthetic = await createLocalMediaStream('local');
    await synthetic.addTrack(track);
    _syntheticRemoteVideoStream = synthetic;
    return synthetic;
  }

  Future<void> _clearVideoRendererSafely(
    RTCVideoRenderer renderer, {
    required String label,
  }) async {
    try {
      await renderer.setSrcObject(stream: null);
      return;
    } catch (e) {
      callLog('WebRTC', '$label clear failed: $e');
    }

    try {
      renderer.srcObject = null;
    } catch (e) {
      callLog('WebRTC', '$label fallback clear failed: $e');
    }
  }

  void _adoptVideoTransceiverFromTrackEvent(RTCTrackEvent event) {
    final transceiver = event.transceiver;
    if (transceiver == null) {
      return;
    }
    _videoTransceiver = transceiver;
    _videoSender = transceiver.sender;
    callOpLog(
      'WebRTC',
      'video_transceiver_adopted_from_ontrack',
      fields: _debugFields(<String, Object?>{
        'mid': transceiver.mid,
        'trackId': event.track.id,
        'senderTrackKind': transceiver.sender.track?.kind,
        'receiverTrackKind': transceiver.receiver.track?.kind,
      }),
    );
  }

  Future<void> _handleRemoteTrack(
    RTCPeerConnection pc,
    RTCTrackEvent event,
  ) async {
    final track = event.track;
    final kind = (track.kind ?? '').toLowerCase().trim();
    callLog(
      'WebRTC',
      'onTrack kind=$kind streams=${event.streams.length} trackId=${track.id}',
    );
    if (kind != 'video') {
      return;
    }
    _adoptVideoTransceiverFromTrackEvent(event);
    _hasRemoteVideoTrack = true;
    _remoteVideoTrackReceivedAtMs = DateTime.now().millisecondsSinceEpoch;
    _updateRemoteVideoLifecycle(
      const RemoteVideoLifecycle.trackReceived(),
      extra: <String, Object?>{
        'streamCount': event.streams.length,
        'trackId': track.id,
      },
    );

    MediaStream? targetStream;
    for (final stream in event.streams) {
      if (stream.getVideoTracks().isNotEmpty) {
        targetStream = stream;
        break;
      }
    }

    if (targetStream == null) {
      try {
        final remoteStreams = pc.getRemoteStreams();
        for (final stream in remoteStreams.whereType<MediaStream>()) {
          if (stream.getVideoTracks().any((t) => t.id == track.id) ||
              stream.getVideoTracks().isNotEmpty) {
            targetStream = stream;
            break;
          }
        }
      } catch (e) {
        callLog('WebRTC', 'getRemoteStreams failed during onTrack: $e');
      }
    }

    if (targetStream == null) {
      targetStream = await _createSyntheticRemoteVideoStream(
        track: track,
        reason: 'on_track',
      );
      callOpLog(
        'WebRTC',
        'remote_video_bound_via_synthetic_stream',
        fields: _debugFields(<String, Object?>{'trackId': track.id}),
      );
      callLog('WebRTC', 'onTrack video attached via synthetic remote stream');
    }

    await _bindRemoteVideoRenderer(
      stream: targetStream,
      track: track,
      reason: 'on_track',
    );
  }

  bool _rendererHasRemoteVideo() {
    final stream = remoteRenderer.srcObject;
    return stream != null && stream.getVideoTracks().isNotEmpty;
  }

  void _markRemoteVideoVisible({required String source}) {
    if (!_expectsRemoteVideo || !_rendererHasRemoteVideo()) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final wasVisible = _remoteRendererHasVisibleFrame;
    _remoteRendererHasVisibleFrame = true;
    if (!wasVisible) {
      callOpLog(
        'WebRTC',
        'remote_video_first_frame_visible',
        fields: _debugFields(<String, Object?>{
          'source': source,
          'trackId': _boundRemoteVideoTrackId,
          'width': remoteRenderer.videoWidth,
          'height': remoteRenderer.videoHeight,
        }),
      );
      if (!mediaEstablished.value) {
        mediaEstablished.value = true;
        callOpLog(
          'WebRTC',
          'media_established_via_remote_video',
          fields: _debugFields(<String, Object?>{'source': source}),
        );
      }
    }
    _refreshRemoteVideoLifecycle(nowMs: nowMs);
  }

  @visibleForTesting
  static bool shouldClearRendererBeforeBinding({
    required bool forceReattach,
    required bool sameTrackAsCurrent,
    required bool rendererAlreadyBound,
  }) {
    return forceReattach || sameTrackAsCurrent || rendererAlreadyBound;
  }

  Future<void> _bindRemoteVideoRenderer({
    required MediaStream stream,
    required MediaStreamTrack track,
    required String reason,
    bool forceReattach = false,
  }) async {
    final trackId = track.id ?? '';
    final sameTrackAsCurrent =
        _boundRemoteVideoTrackId.isNotEmpty &&
        _boundRemoteVideoTrackId == trackId;
    final clearBeforeBind = shouldClearRendererBeforeBinding(
      forceReattach: forceReattach,
      sameTrackAsCurrent: sameTrackAsCurrent,
      rendererAlreadyBound: remoteRenderer.srcObject != null,
    );
    _remoteRendererHasVisibleFrame = false;
    _lastHasInboundRemoteVideo = false;
    _boundRemoteVideoTrackId = trackId;

    if (clearBeforeBind) {
      await _clearVideoRendererSafely(
        remoteRenderer,
        label: 'remoteRenderer clear before reattach',
      );
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    try {
      await remoteRenderer.setSrcObject(stream: stream, trackId: trackId);
    } catch (e) {
      callLog(
        'WebRTC',
        'remoteRenderer.setSrcObject(trackId=$trackId) failed: $e',
      );
      try {
        remoteRenderer.srcObject = stream;
      } catch (fallbackError) {
        callLog(
          'WebRTC',
          'remoteRenderer fallback srcObject assign failed: $fallbackError',
        );
      }
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _remoteVideoRendererBoundAtMs = nowMs;
    _refreshRemoteVideoLifecycle(nowMs: nowMs);
    callOpLog(
      'WebRTC',
      'remote_video_renderer_attach',
      fields: _debugFields(<String, Object?>{
        'reason': reason,
        'streamId': stream.id,
        'trackId': trackId,
        'forceReattach': clearBeforeBind,
      }),
    );
    callLog(
      'WebRTC',
      'remote video renderer attached streamId=${stream.id} trackId=$trackId reason=$reason',
    );
  }

  Future<void> _recoverRemoteVideoAttachment(
    RTCPeerConnection pc, {
    required String reason,
    bool throttle = true,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (throttle && nowMs - _lastRemoteVideoRecoveryAttemptMs < 3000) {
      return;
    }
    _lastRemoteVideoRecoveryAttemptMs = nowMs;
    callOpLog(
      'WebRTC',
      'remote_video_recovery_start',
      fields: _debugFields(<String, Object?>{'reason': reason}),
    );

    MediaStream? targetStream;
    MediaStreamTrack? targetTrack;
    try {
      final remoteStreams = pc.getRemoteStreams();
      for (final stream in remoteStreams.whereType<MediaStream>()) {
        final videoTracks = stream.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          targetStream = stream;
          targetTrack = videoTracks.first;
          break;
        }
      }
    } catch (e) {
      callLog('WebRTC', 'remote video recovery getRemoteStreams failed: $e');
    }

    if (targetStream == null) {
      try {
        final dynamic dynPc = pc;
        final dynamic transceiversDynamic = await dynPc.getTransceivers();
        if (transceiversDynamic is Iterable) {
          for (final dynamic transceiver in transceiversDynamic) {
            final dynamic receiver = transceiver.receiver;
            final dynamic maybeTrack = receiver?.track;
            if (maybeTrack is MediaStreamTrack) {
              final kind = (maybeTrack.kind ?? '').toLowerCase().trim();
              if (kind == 'video') {
                targetStream = await _createSyntheticRemoteVideoStream(
                  track: maybeTrack,
                  reason: 'recovery_transceiver',
                );
                targetTrack = maybeTrack;
                break;
              }
            }
          }
        }
      } catch (e) {
        callLog('WebRTC', 'remote video recovery via transceivers failed: $e');
      }
    }

    if (targetStream == null) {
      return;
    }

    targetTrack ??= targetStream.getVideoTracks().isNotEmpty
        ? targetStream.getVideoTracks().first
        : null;
    if (targetTrack == null) {
      return;
    }

    _hasRemoteVideoTrack = true;
    _remoteVideoTrackReceivedAtMs ??= nowMs;
    await _bindRemoteVideoRenderer(
      stream: targetStream,
      track: targetTrack,
      reason: reason,
      forceReattach: true,
    );
    callOpLog(
      'WebRTC',
      'remote_video_recovery_success',
      fields: _debugFields(<String, Object?>{
        'reason': reason,
        'streamId': targetStream.id,
        'trackId': targetTrack.id,
      }),
    );
    callLog(
      'WebRTC',
      'remote video renderer recovered via stats reason=$reason streamId=${targetStream.id}',
    );
  }

  Future<void> forceRemoteVideoRendererRecovery({
    required String reason,
  }) async {
    final pc = _peerConnection;
    if (pc == null || !_expectsRemoteVideo) {
      return;
    }
    await _recoverRemoteVideoAttachment(pc, reason: reason);
  }

  void beginRemoteVideoRecoveryWindow({
    required RemoteVideoFailureReason reason,
  }) {
    if (!_expectsRemoteVideo) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _remoteRendererHasVisibleFrame = false;
    switch (reason) {
      case RemoteVideoFailureReason.waitingForTrackTimeout:
        _remoteVideoExpectedAtMs = nowMs;
        _remoteVideoTrackReceivedAtMs = null;
        _remoteVideoRendererBoundAtMs = null;
        _updateRemoteVideoLifecycle(const RemoteVideoLifecycle.waitingTrack());
        break;
      case RemoteVideoFailureReason.rendererBindingTimeout:
        _remoteVideoTrackReceivedAtMs = nowMs;
        _remoteVideoRendererBoundAtMs = null;
        _updateRemoteVideoLifecycle(const RemoteVideoLifecycle.trackReceived());
        break;
      case RemoteVideoFailureReason.rendererNoFrames:
        _remoteVideoRendererBoundAtMs = nowMs;
        _updateRemoteVideoLifecycle(const RemoteVideoLifecycle.rendererBound());
        break;
    }
  }

  Future<void> _applySpeakerRoute() async {
    // PR-H+2 (2026-05-20): on iOS, prefer the native `secretly/call_ui#
    // setSpeakerEnabled` MethodChannel which sets the AVAudioSession
    // category WITH `.defaultToSpeaker` and survives RTCAudioSession's
    // auto-revert + CallKit's `provider:didActivate:` re-config.
    // `Helper.setSpeakerphoneOn` alone is silently reverted on iOS, which
    // is why the speaker button has appeared to "not work" in 1.1.x.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        const channel = MethodChannel('secretly/call_ui');
        final ok = await channel.invokeMethod<bool>(
          'setSpeakerEnabled',
          {'enabled': _speakerEnabled},
        );
        if (ok == true) {
          return;
        }
      } on PlatformException catch (e) {
        callLog(
          'WebRTC',
          '_applySpeakerRoute native iOS setSpeakerEnabled failed: '
          '${e.message}',
        );
      } on MissingPluginException {
        // Older build without the native handler — fall through to Helper.
      } catch (_) {}
    }
    // 🔴 ANDROID: СНАЧАЛА СОВРЕМЕННЫЙ ПУТЬ, И НИКОГДА МОЛЧА (12.08.2026).
    //
    // Полевая жалоба: громкую включил, выключить не смог — кнопка нажимается,
    // звук не меняется. В логе за весь звонок НИ ОДНОЙ строки о маршруте:
    // единственным механизмом был `Helper.setSpeakerphoneOn` внутри
    // `try/catch(_){}`. Успех не логировался, отказ глотался — молчаливый
    // отказ выглядел ровно как успех. Тот же класс дефекта, что трижды за день
    // стоил замеров: замер, который не умеет провалиться, не замер.
    //
    // `setSpeakerphoneOn` объявлен устаревшим в Android 12: в режиме разговора
    // маршрутом владеет `setCommunicationDevice`, и снять громкую можно только
    // `clearCommunicationDevice`. Старый путь остаётся откатом — до Android 12
    // и на случай отказа нового.
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        const channel = MethodChannel('secretly/call_ui');
        final res = await channel.invokeMapMethod<String, Object?>(
          'setCommunicationSpeaker',
          {'enabled': _speakerEnabled},
        );
        final applied = res?['applied'] == true;
        callLog(
          'WebRTC',
          'speaker android native enabled=$_speakerEnabled '
          'applied=$applied reason=${res?['reason']} '
          'currentType=${res?['current']}',
        );
        if (applied) return;
      } on MissingPluginException {
        callLog('WebRTC', 'speaker android native handler absent');
      } catch (e) {
        callLog('WebRTC', 'speaker android native threw: $e');
      }
    }

    try {
      final dynamic helper = Helper;
      await helper.setSpeakerphoneOn(_speakerEnabled);
      callLog('WebRTC', 'speaker helper fallback ok enabled=$_speakerEnabled');
    } catch (e) {
      // Больше НЕ глотаем: раньше здесь дефект и жил.
      callLog(
        'WebRTC',
        'speaker helper fallback FAILED enabled=$_speakerEnabled: $e',
      );
    }
  }

  void _startStatsSampling() {
    _statsTimer?.cancel();
    _lastVideoBytesSent = null;
    _lastPacketsLost = null;
    _lastPacketsReceived = null;
    _lastSampleAtMs = DateTime.now().millisecondsSinceEpoch;
    _lastIceDiagnosticsLogAtMs = 0;
    unawaited(_sampleStats());
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_sampleStats());
    });
  }

  Future<void> _sampleStats() async {
    final pc = _peerConnection;
    if (pc == null) return;
    try {
      final dynamic dynPc = pc;
      final dynamic reportsDynamic = await dynPc.getStats();
      if (reportsDynamic is! Iterable) return;

      double? rttMs;
      double? jitterMs;
      int? videoBytesSent;
      int? packetsLost;
      int? packetsReceived;
      int? inboundVideoBytesReceived;
      bool hasSelectedCandidatePair = false;
      bool hasInboundRemoteMedia = false;
      String? selectedLocalCandidateId;
      String? selectedRemoteCandidateId;
      String? selectedPairState;
      final candidateReports = <String, Map<String, dynamic>>{};

      for (final report in reportsDynamic) {
        final type = _reportType(report);
        final values = _extractValuesMap(report);
        final reportId = _reportId(report, values);

        if ((type == 'local-candidate' || type == 'remote-candidate') &&
            reportId.isNotEmpty) {
          candidateReports[reportId] = values;
        }

        if (type == 'candidate-pair') {
          final state = (values['state'] ?? '').toString().toLowerCase();
          final selected =
              values['selected'] == true || values['nominated'] == true;
          if (selected || state == 'succeeded') {
            hasSelectedCandidatePair = true;
            selectedPairState = state.isEmpty ? null : state;
            selectedLocalCandidateId = _statsString(values['localCandidateId']);
            selectedRemoteCandidateId = _statsString(
              values['remoteCandidateId'],
            );
            final rttSeconds =
                _toDouble(values['currentRoundTripTime']) ??
                _toDouble(values['roundTripTime']);
            if (rttSeconds != null) {
              rttMs = rttSeconds * 1000.0;
            }
          }
        }

        if (type == 'outbound-rtp' && _isVideoStats(values)) {
          final bytes = _toInt(values['bytesSent']);
          if (bytes != null) {
            videoBytesSent = bytes;
          }
        }

        if (type == 'inbound-rtp') {
          final packets = _toInt(values['packetsReceived']);
          final bytes = _toInt(values['bytesReceived']);
          if ((packets != null && packets > 0) ||
              (bytes != null && bytes > 0)) {
            hasInboundRemoteMedia = true;
          }
          if (_isVideoStats(values)) {
            packetsLost = _toInt(values['packetsLost']) ?? packetsLost;
            packetsReceived = packets ?? packetsReceived;
            inboundVideoBytesReceived = bytes ?? inboundVideoBytesReceived;
          }
          final j = _toDouble(values['jitter']);
          if (j != null) {
            jitterMs = j * 1000.0;
          }
        }
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final dtMs = (nowMs - _lastSampleAtMs).clamp(1, 120000);
      _lastSampleAtMs = nowMs;

      double? bitrateKbps;
      if (videoBytesSent != null && _lastVideoBytesSent != null) {
        final deltaBytes = (videoBytesSent - _lastVideoBytesSent!).clamp(
          0,
          1 << 30,
        );
        bitrateKbps = (deltaBytes * 8.0) / dtMs;
      }
      _lastVideoBytesSent = videoBytesSent ?? _lastVideoBytesSent;

      double? packetLossPct;
      if (packetsLost != null &&
          packetsReceived != null &&
          _lastPacketsLost != null &&
          _lastPacketsReceived != null) {
        final dLost = (packetsLost - _lastPacketsLost!).clamp(0, 1 << 20);
        final dRecv = (packetsReceived - _lastPacketsReceived!).clamp(
          0,
          1 << 20,
        );
        final total = dLost + dRecv;
        if (total > 0) {
          packetLossPct = (dLost * 100.0) / total;
        }
      }
      _lastPacketsLost = packetsLost ?? _lastPacketsLost;
      _lastPacketsReceived = packetsReceived ?? _lastPacketsReceived;

      final hasInboundRemoteVideo =
          (packetsReceived != null && packetsReceived > 0) ||
          (inboundVideoBytesReceived != null && inboundVideoBytesReceived > 0);
      final peerConnectionStateNow = connectionState.value;
      final iceConnectionStateNow = iceConnectionState.value;
      final selectedCandidateFields = _selectedCandidatePairFields(
        localCandidate: candidateReports[selectedLocalCandidateId],
        remoteCandidate: candidateReports[selectedRemoteCandidateId],
        selectedPairState: selectedPairState,
      );
      final shouldLogIceDiagnostics =
          !mediaEstablished.value &&
          nowMs - _lastIceDiagnosticsLogAtMs >= 4000 &&
          (peerConnectionStateNow ==
                  RTCPeerConnectionState.RTCPeerConnectionStateConnecting ||
              peerConnectionStateNow ==
                  RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
              iceConnectionStateNow ==
                  RTCIceConnectionState.RTCIceConnectionStateChecking ||
              iceConnectionStateNow ==
                  RTCIceConnectionState.RTCIceConnectionStateFailed);
      if (shouldLogIceDiagnostics) {
        _lastIceDiagnosticsLogAtMs = nowMs;
        callOpLog(
          'WebRTC',
          'ice_stats_sample',
          fields: _debugFields(<String, Object?>{
            'hasSelectedCandidatePair': hasSelectedCandidatePair,
            'hasInboundRemoteMedia': hasInboundRemoteMedia,
            'hasInboundRemoteVideo': hasInboundRemoteVideo,
            'peerConnectionState': peerConnectionStateNow,
            'iceConnectionState': iceConnectionStateNow,
            'rttMs': rttMs?.round(),
            'jitterMs': jitterMs?.round(),
            'packetsLost': packetsLost,
            'packetsReceived': packetsReceived,
            'inboundVideoBytesReceived': inboundVideoBytesReceived,
            'videoBytesSent': videoBytesSent,
            'bitrateKbps': bitrateKbps?.round(),
            ...selectedCandidateFields,
          }),
        );
      }
      if (!mediaEstablished.value &&
          shouldDeclareMediaEstablished(
            peerConnectionState: peerConnectionStateNow,
            iceConnectionState: iceConnectionStateNow,
            hasSelectedCandidatePair: hasSelectedCandidatePair,
            hasInboundRemoteMedia: hasInboundRemoteMedia,
          )) {
        callOpLog(
          'WebRTC',
          'media_established',
          fields: _debugFields(<String, Object?>{
            'hasSelectedCandidatePair': hasSelectedCandidatePair,
            'hasInboundRemoteMedia': hasInboundRemoteMedia,
            'peerConnectionState': peerConnectionStateNow,
            'iceConnectionState': iceConnectionStateNow,
            ...selectedCandidateFields,
          }),
        );
        mediaEstablished.value = true;
        _consecutivePoorVideoSamples = 0;
      }
      // Skip renderer recovery and quality adaptation while transport is lost.
      // During disconnected/failed/reconnecting states:
      //   • Stats show 0 bitrate and null RTT → _deriveQuality uses defaults
      //     that look deceptively good, causing applyConstraints flicker.
      //   • _recoverRemoteVideoAttachment bind/unbind cycles cause visible
      //     camera flickering on the remote side.
      // Both resume automatically once the transport reconnects.
      final transportLost = _shouldResetMediaEstablishedForTransportLoss();
      if (!transportLost) {
        if (_expectsRemoteVideo && !_rendererHasRemoteVideo()) {
          await _recoverRemoteVideoAttachment(
            pc,
            reason: hasInboundRemoteVideo
                ? 'packetsReceived=${packetsReceived ?? 0} bytesReceived=${inboundVideoBytesReceived ?? 0}'
                : 'missing_renderer_without_inbound_video_stats',
          );
        }
      }
      _refreshRemoteVideoLifecycle(
        hasInboundRemoteVideo: transportLost ? false : hasInboundRemoteVideo,
        nowMs: nowMs,
      );

      final quality = _deriveQuality(
        rttMs: rttMs,
        jitterMs: jitterMs,
        packetLossPct: packetLossPct,
      );
      if (_isVideoEnabled && !transportLost) {
        final nextPreset = _targetPresetForQuality(quality);
        await _applyVideoPreset(nextPreset);
      }

      qualityMetrics.value = CallQualityMetrics(
        rttMs: rttMs,
        jitterMs: jitterMs,
        outboundVideoBitrateKbps: bitrateKbps,
        packetLossPct: packetLossPct,
        qualityLevel: quality,
        videoPreset: _videoPreset,
      );
    } catch (_) {
      // ignore stats issues
    }
  }

  Future<void> _applyVideoPreset(CallVideoQualityPreset preset) async {
    if (_videoPreset == preset) return;
    final stream = _localStream;
    if (stream == null) return;
    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) return;
    final track = tracks.first;

    int width;
    int height;
    int frameRate;
    switch (preset) {
      case CallVideoQualityPreset.hd:
        width = 1280;
        height = 720;
        frameRate = 24;
        break;
      case CallVideoQualityPreset.sd:
        width = 960;
        height = 540;
        frameRate = 20;
        break;
      case CallVideoQualityPreset.low:
        width = 640;
        height = 360;
        frameRate = 15;
        break;
    }

    try {
      final dynamic dynTrack = track;
      await dynTrack.applyConstraints({
        'width': width,
        'height': height,
        'frameRate': frameRate,
      });
      _videoPreset = preset;
    } catch (_) {
      // ignore unsupported constraints
    }
  }

  CallQualityLevel _deriveQuality({
    required double? rttMs,
    required double? jitterMs,
    required double? packetLossPct,
  }) {
    final rtt = rttMs ?? 120;
    final jitter = jitterMs ?? 15;
    final loss = packetLossPct ?? 0;

    if (rtt >= 280 || jitter >= 45 || loss >= 8) {
      return CallQualityLevel.poor;
    }
    if (rtt >= 180 || jitter >= 28 || loss >= 4) {
      return CallQualityLevel.fair;
    }
    if (rtt >= 110 || jitter >= 18 || loss >= 2) {
      return CallQualityLevel.good;
    }
    return CallQualityLevel.excellent;
  }

  @visibleForTesting
  static CallVideoQualityPreset selectVideoPresetForQuality({
    required CallQualityLevel quality,
    required CallVideoQualityPreset currentPreset,
    required int consecutivePoorSamples,
  }) {
    switch (quality) {
      case CallQualityLevel.excellent:
        return CallVideoQualityPreset.hd;
      case CallQualityLevel.good:
        return currentPreset == CallVideoQualityPreset.low
            ? CallVideoQualityPreset.sd
            : CallVideoQualityPreset.hd;
      case CallQualityLevel.fair:
        return currentPreset == CallVideoQualityPreset.low
            ? CallVideoQualityPreset.low
            : CallVideoQualityPreset.sd;
      case CallQualityLevel.poor:
        if (consecutivePoorSamples >= 2) {
          return CallVideoQualityPreset.low;
        }
        return currentPreset == CallVideoQualityPreset.low
            ? CallVideoQualityPreset.low
            : CallVideoQualityPreset.sd;
    }
  }

  CallVideoQualityPreset _targetPresetForQuality(CallQualityLevel quality) {
    _consecutivePoorVideoSamples = quality == CallQualityLevel.poor
        ? _consecutivePoorVideoSamples + 1
        : 0;
    return selectVideoPresetForQuality(
      quality: quality,
      currentPreset: _videoPreset,
      consecutivePoorSamples: _consecutivePoorVideoSamples,
    );
  }

  bool _isVideoStats(Map<String, dynamic> values) {
    final kind = (values['kind'] ?? values['mediaType'] ?? '')
        .toString()
        .toLowerCase();
    return kind == 'video';
  }

  Map<String, dynamic> _extractValuesMap(dynamic report) {
    final map = <String, dynamic>{};
    dynamic valuesObj;
    try {
      final dynamic dyn = report;
      valuesObj = dyn.values;
    } catch (_) {}
    if (valuesObj is Map) {
      for (final entry in valuesObj.entries) {
        map[entry.key.toString()] = entry.value;
      }
    }
    if (report is Map) {
      for (final entry in report.entries) {
        map.putIfAbsent(entry.key.toString(), () => entry.value);
      }
    }
    return map;
  }

  String _reportType(dynamic report) {
    if (report is Map) {
      return (report['type'] ?? '').toString().toLowerCase();
    }
    try {
      final dynamic dyn = report;
      return (dyn.type ?? '').toString().toLowerCase();
    } catch (_) {
      return '';
    }
  }

  String _reportId(dynamic report, Map<String, dynamic> values) {
    final fromValues = _statsString(values['id']);
    if (fromValues.isNotEmpty) return fromValues;
    if (report is Map) {
      return (report['id'] ?? '').toString();
    }
    try {
      final dynamic dyn = report;
      return (dyn.id ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  String _statsString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _statsUrlScheme(dynamic value) {
    final raw = _statsString(value).toLowerCase();
    final separator = raw.indexOf(':');
    if (separator <= 0) return '';
    return raw.substring(0, separator);
  }

  Map<String, Object?> _selectedCandidatePairFields({
    required Map<String, dynamic>? localCandidate,
    required Map<String, dynamic>? remoteCandidate,
    required String? selectedPairState,
  }) {
    if (localCandidate == null && remoteCandidate == null) {
      return selectedPairState == null
          ? const <String, Object?>{}
          : <String, Object?>{'selectedPairState': selectedPairState};
    }
    return <String, Object?>{
      'selectedPairState': selectedPairState,
      'localCandidateType': _statsString(localCandidate?['candidateType']),
      'localProtocol': _statsString(localCandidate?['protocol']),
      'localRelayProtocol': _statsString(localCandidate?['relayProtocol']),
      'localNetworkType': _statsString(localCandidate?['networkType']),
      'localUrlScheme': _statsUrlScheme(localCandidate?['url']),
      'remoteCandidateType': _statsString(remoteCandidate?['candidateType']),
      'remoteProtocol': _statsString(remoteCandidate?['protocol']),
      'remoteRelayProtocol': _statsString(remoteCandidate?['relayProtocol']),
    };
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  /// Add a video track to an existing audio-only session (for upgrade).
  Future<void> addVideoTrack() async {
    final pc = _peerConnection;
    final stream = _localStream;
    if (pc == null || stream == null) return;
    // If we already have video, skip.
    if (stream.getVideoTracks().isNotEmpty) return;
    if (_videoPreset == CallVideoQualityPreset.low) {
      _videoPreset = preferredInitialVideoPreset(requestedVideo: true);
    }
    final videoStream = await navigator.mediaDevices.getUserMedia(
      _videoCaptureConstraints(withAudio: false),
    );
    final videoTrack = videoStream.getVideoTracks().first;
    _upgradedVideoStream = videoStream;
    stream.addTrack(videoTrack);
    final transceiver = await _ensureConfiguredVideoTransceiver(
      pc: pc,
      direction: TransceiverDirection.SendRecv,
      operation: 'addVideoTrack',
      stream: stream,
      track: videoTrack,
    );
    _videoSender = transceiver.sender;
    callOpLog(
      'WebRTC',
      'local_video_track_added',
      fields: _debugFields(<String, Object?>{
        'trackId': videoTrack.id,
        'streamId': stream.id,
      }),
    );
    localRenderer.srcObject = stream;
    callOpLog(
      'WebRTC',
      'local_video_renderer_bound',
      fields: _debugFields(<String, Object?>{
        'trackId': videoTrack.id,
        'streamId': stream.id,
      }),
    );
    _isVideoEnabled = true;
    // Do NOT call _setRemoteVideoExpectation(true) here.
    //
    // • On the ANSWERER side (called from startIncomingFromOffer): the remote
    //   track has already been received and _handleRemoteTrack has bound the
    //   renderer.  Resetting the expectation would clear _hasRemoteVideoTrack
    //   and cause a spurious "waiting_for_track" log, and it resets
    //   _remoteVideoRendererBoundAtMs which breaks the rendererNoFrames
    //   timeout that triggers VideoSink re-registration after EglRenderer
    //   reinit.
    //
    // • On the CALLER/UPGRADER side (called before renegotiate): the remote
    //   hasn't confirmed video yet.  Setting the expectation here causes
    //   premature recovery to run before the answer arrives, sometimes binding
    //   the renderer to an empty receiver track.  Instead, the expectation is
    //   set in applyRemoteAnswer() once the remote answer confirms video.
  }

  Future<void> rollbackVideoUpgrade({
    bool keepReceivingRemoteVideo = false,
  }) async {
    final pc = _peerConnection;
    var transceiver = _videoTransceiver;
    final sender = _videoSender;
    if (transceiver == null && pc != null && sender != null) {
      transceiver = await _getSendersTransceiver(pc, sender.senderId);
      if (transceiver != null) {
        _videoTransceiver = transceiver;
        _videoSender = transceiver.sender;
      }
    }
    if (transceiver != null) {
      try {
        await transceiver.sender.replaceTrack(null);
      } catch (_) {}
      try {
        await transceiver.setDirection(
          keepReceivingRemoteVideo
              ? TransceiverDirection.RecvOnly
              : TransceiverDirection.Inactive,
        );
      } catch (_) {}
    }
    final localStream = _localStream;
    if (localStream != null) {
      await _clearVideoRendererSafely(
        localRenderer,
        label: 'localRenderer rollbackVideoUpgrade',
      );
      for (final track in List<MediaStreamTrack>.from(
        localStream.getVideoTracks(),
      )) {
        try {
          await localStream.removeTrack(track);
        } catch (e) {
          callLog('WebRTC', 'rollbackVideoUpgrade removeTrack failed: $e');
        }
      }
      try {
        localRenderer.srcObject = localStream;
      } catch (e) {
        callLog(
          'WebRTC',
          'rollbackVideoUpgrade localRenderer audio-only rebind failed: $e',
        );
      }
    }
    // Тот же изъян, что и в hangup: поток обязан быть снят с учёта плагина,
    // иначе он останется в реестре с мёртвыми дорожками. Выключение видео в
    // разговоре — самый частый путь сюда.
    final stream = _upgradedVideoStream;
    _upgradedVideoStream = null;
    await _retireStream(stream);
    _isVideoEnabled = false;
  }

  /// Replace the local video track with the device screen capture.
  /// Returns true on success. Replaces the sender's video track via
  /// [RTCRtpSender.replaceTrack] so no SDP renegotiation is needed.
  Future<bool> startScreenShare() async {
    final pc = _peerConnection;
    final stream = _localStream;
    if (pc == null || stream == null) return false;
    final lease = await ScreenShareRuntime.acquire();
    if (lease == null) {
      callLog(
        'WebRtcCallSession',
        'startScreenShare aborted: permission or background runtime unavailable',
      );
      return false;
    }
    try {
      final screenStream = await navigator.mediaDevices.getDisplayMedia({
        'audio': false,
        'video': true,
      });
      final screenTracks = screenStream.getVideoTracks();
      if (screenTracks.isEmpty) {
        // Тот же путь отпускания: захват состоялся, значит поток уже в реестре
        // плагина, и бросать его там нельзя даже на пути отказа.
        await _retireStream(screenStream);
        throw StateError('screen capture returned no video track');
      }
      final screenTrack = screenTracks.first;
      screenTrack.onEnded = () {
        unawaited(_handleUnexpectedScreenShareEnded());
      };
      // Replace the video sender's track — no renegotiation required.
      final senders = await pc.getSenders();
      var replaced = false;
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          _priorVideoTrack = sender.track;
          await sender.replaceTrack(screenTrack);
          replaced = true;
          break;
        }
      }
      if (!replaced) {
        screenTrack.onEnded = () {};
        await _retireStream(screenStream);
        throw StateError('screen share sender unavailable');
      }
      _screenStream = screenStream;
      _screenShareLease = lease;
      localRenderer.srcObject = screenStream;
      callLog('WebRtcCallSession', 'screen share started');
      return true;
    } catch (e) {
      await lease.release();
      callLog('WebRtcCallSession', 'startScreenShare failed: $e');
      return false;
    }
  }

  Future<void> _handleUnexpectedScreenShareEnded() async {
    if (_screenStream == null) {
      return;
    }
    callLog('WebRtcCallSession', 'screen share ended unexpectedly');
    await stopScreenShare();
    onScreenShareStopped?.call();
  }

  /// Stop screen share and restore the camera track.
  Future<void> stopScreenShare() async {
    final pc = _peerConnection;
    // Stop the screen capture tracks.
    final screenStream = _screenStream;
    _screenStream = null;
    if (screenStream != null) {
      // Снимаем обработчик до снятия с учёта, иначе он выстрелит на нашей же
      // остановке; дальше — то же правило, что у прочих потоков.
      for (final track in screenStream.getTracks()) {
        track.onEnded = () {};
      }
      await _retireStream(screenStream);
    }
    // Restore the prior camera track if available.
    final prior = _priorVideoTrack;
    if (prior != null && pc != null) {
      _priorVideoTrack = null;
      try {
        final senders = await pc.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(prior);
            break;
          }
        }
      } catch (e) {
        callLog(
          'WebRtcCallSession',
          'stopScreenShare restore track failed: $e',
        );
      }
    }
    // Restore local preview to the camera stream.
    final stream = _localStream;
    if (stream != null) {
      localRenderer.srcObject = stream;
    }
    final lease = _screenShareLease;
    _screenShareLease = null;
    if (lease != null) {
      await lease.release();
    }
    callLog('WebRtcCallSession', 'screen share stopped');
  }

  Future<void> hangup() async {
    _statsTimer?.cancel();
    _statsTimer = null;
    _lastVideoBytesSent = null;
    _lastPacketsLost = null;
    _lastPacketsReceived = null;
    _lastIceDiagnosticsLogAtMs = 0;
    _consecutivePoorVideoSamples = 0;
    _lastRemoteVideoRecoveryAttemptMs = 0;
    _remoteDescriptionSet = false;
    _remoteRendererHasVisibleFrame = false;
    _lastHasInboundRemoteVideo = false;
    _boundRemoteVideoTrackId = '';
    _pendingRemoteCandidates.clear();
    mediaEstablished.value = false;
    _setRemoteVideoExpectation(false);
    if (_screenStream != null) {
      await stopScreenShare();
    }
    await _clearVideoRendererSafely(
      localRenderer,
      label: 'localRenderer hangup',
    );
    await _clearVideoRendererSafely(
      remoteRenderer,
      label: 'remoteRenderer hangup',
    );
    // 🔴 СИНТЕТИЧЕСКИЙ ПОТОК — ДО ЗАКРЫТИЯ СОЕДИНЕНИЯ (09.09.2026, трасса
    // владельца из Play Console, версия 565).
    //
    // Правка от 20.08 (разбор ниже) была верной, но неполной: правило «снимать
    // поток с учёта, ПОКА дорожки живы» применили к локальным потокам и не
    // применили к этому. А он особенный:
    //
    //   * создаётся как ЛОКАЛЬНЫЙ — `createLocalMediaStream` в
    //     [_createSyntheticRemoteVideoStream], значит попадает в реестр
    //     `localStreams` плагина;
    //   * но дорожка внутри него УДАЛЁННАЯ — принадлежит соединению.
    //
    // Отсюда порядок был губителен: `_peerConnection.close()` уничтожал
    // удалённые дорожки, и только потом мы звали `_retireStream`. Тот уходил в
    // `streamDispose`, плагин звал `track.id()` у мёртвой дорожки и бросал.
    // Наш `catch` это проглатывал — и запись оставалась в реестре НАВСЕГДА,
    // потому что `localStreams.remove()` стоит в плагине ПОСЛЕ обхода дорожек.
    // При закрытии экрана плагин обходил реестр снова, натыкался на ту же
    // мёртвую дорожку, и там ловить было уже некому:
    //
    //   IllegalStateException: MediaStreamTrack has been disposed
    //     at FlutterWebRTCPlugin.onDetachedFromEngine
    //     at MainActivity.onDestroy
    //
    // Теперь снятие с учёта идёт ПЕРЕД закрытием соединения — дорожка ещё жива,
    // обход в плагине проходит целиком, запись из реестра уходит.
    //
    // Отрисовке это не мешает: оба видео-приёмника погашены выше
    // (`_clearVideoRendererSafely`), синтетический поток к этому моменту уже
    // никому не показывается.
    final syntheticRemoteVideoStream = _syntheticRemoteVideoStream;
    _syntheticRemoteVideoStream = null;
    await _retireStream(syntheticRemoteVideoStream);

    try {
      await _peerConnection?.close();
    } catch (_) {}
    _peerConnection = null;
    _videoSender = null;
    _audioTransceiver = null;
    _videoTransceiver = null;

    // 🔴 ПОТОК СНИМАЕТСЯ С УЧЁТА ПЛАГИНА ПЕРВЫМ (20.08.2026, Play Console).
    //
    // Сбой `IllegalStateException: MediaStreamTrack has been disposed` внутри
    // `FlutterWebRTCPlugin.onDetachedFromEngine` (стек владельца, версии 405 и
    // 468). Механизм точный:
    //
    //   * `track.stop()` уходит в плагин как `trackDispose`: тот убирает
    //     дорожку из своего реестра, гасит её и УНИЧТОЖАЕТ захватчик камеры;
    //   * но сам ПОТОК остаётся в реестре `localStreams` со ссылками на уже
    //     мёртвые дорожки — мы обнуляли только СВОЮ ссылку;
    //   * при уничтожении экрана плагин обходит свой реестр и зовёт
    //     `track.id()` у мёртвой дорожки — исключение улетает в систему.
    //
    // Порядок здесь решает всё: в плагине `localStreams.remove()` стоит ПОСЛЕ
    // обхода дорожек, поэтому бросок на полпути оставил бы запись навсегда.
    // Значит поток надо снимать с учёта, ПОКА дорожки живы — тогда обход
    // проходит целиком. `streamDispose` заодно делает всё, что делал бы
    // `track.stop()`: убирает дорожки из реестра и снимает захватчик.
    //
    // `track.stop()` ниже оставлен запасным путём: если снятие с учёта не
    // удалось, камера обязана погаснуть всё равно.
    final stream = _localStream;
    _localStream = null;
    await _retireStream(stream);

    final upgradedStream = _upgradedVideoStream;
    _upgradedVideoStream = null;
    await _retireStream(upgradedStream);

    // Синтетический поток снят с учёта ВЫШЕ, до закрытия соединения — иначе его
    // удалённая дорожка была бы уже мертва. Здесь его трогать нечего.
    connectionState.value = RTCPeerConnectionState.RTCPeerConnectionStateClosed;
    iceConnectionState.value =
        RTCIceConnectionState.RTCIceConnectionStateClosed;
    qualityMetrics.value = const CallQualityMetrics.empty();
  }

  /// 🔴 ЕДИНСТВЕННОЕ ПРАВИЛО «КАК ОТПУСКАТЬ ПОТОК» (20.08.2026).
  ///
  /// Сбой `IllegalStateException: MediaStreamTrack has been disposed` внутри
  /// `FlutterWebRTCPlugin.onDetachedFromEngine` (Play Console, версии 405/468).
  ///
  ///   * `track.stop()` уходит в плагин как `trackDispose`: он убирает дорожку
  ///     из своего реестра, гасит её и уничтожает захватчик камеры;
  ///   * но сам ПОТОК остаётся в реестре `localStreams` со ссылками на уже
  ///     мёртвые дорожки — мы обнуляли только СВОЮ ссылку;
  ///   * при уничтожении экрана плагин обходит реестр и зовёт `track.id()` у
  ///     мёртвой дорожки — исключение улетает в систему.
  ///
  /// Порядок решает всё: в плагине `localStreams.remove()` стоит ПОСЛЕ обхода
  /// дорожек, поэтому бросок на полпути оставил бы запись навсегда. Значит
  /// поток снимаем с учёта, ПОКА дорожки живы. `streamDispose` заодно делает
  /// всё, что делал бы `track.stop()`.
  ///
  /// `track.stop()` ниже — запасной путь: не сняли с учёта, а камера обязана
  /// погаснуть всё равно.
  Future<void> _retireStream(MediaStream? s) async {
    if (s == null) return;
    try {
      await s.dispose();
    } catch (_) {
      // Не сняли с учёта — гасим дорожки поимённо, как раньше.
    }
    for (final track in s.getTracks()) {
      try {
        track.stop();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await hangup();
    try {
      await localRenderer.dispose();
    } catch (_) {}
    try {
      await remoteRenderer.dispose();
    } catch (_) {}
    connectionState.dispose();
    iceConnectionState.dispose();
    mediaEstablished.dispose();
    remoteVideoLifecycle.dispose();
    qualityMetrics.dispose();
  }
}
