// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:secretly_app/calls/webrtc_call_session.dart';

void main() {
  group('RemoteVideoLifecycle.derive', () {
    test('returns notExpected when remote video is not expected', () {
      final lifecycle = RemoteVideoLifecycle.derive(
        expectsRemoteVideo: false,
        mediaEstablished: false,
        hasRemoteVideoTrack: false,
        rendererHasRemoteVideo: false,
        rendererHasVisibleFrame: false,
        hasInboundRemoteVideo: false,
        nowMs: 1000,
      );

      expect(lifecycle.state, RemoteVideoLifecycleState.notExpected);
    });

    test('returns waitingTrack before timeout', () {
      final lifecycle = RemoteVideoLifecycle.derive(
        expectsRemoteVideo: true,
        mediaEstablished: true,
        hasRemoteVideoTrack: false,
        rendererHasRemoteVideo: false,
        rendererHasVisibleFrame: false,
        hasInboundRemoteVideo: false,
        nowMs: 7000,
        expectedAtMs: 1000,
      );

      expect(lifecycle.state, RemoteVideoLifecycleState.expectedWaitingTrack);
    });

    test('fails when remote video track never arrives after grace window', () {
      final lifecycle = RemoteVideoLifecycle.derive(
        expectsRemoteVideo: true,
        mediaEstablished: true,
        hasRemoteVideoTrack: false,
        rendererHasRemoteVideo: false,
        rendererHasVisibleFrame: false,
        hasInboundRemoteVideo: false,
        nowMs: 10050,
        expectedAtMs: 1000,
      );

      expect(lifecycle.state, RemoteVideoLifecycleState.failed);
      expect(
        lifecycle.failureReason,
        RemoteVideoFailureReason.waitingForTrackTimeout,
      );
    });

    test('fails when renderer never binds after track arrives', () {
      final lifecycle = RemoteVideoLifecycle.derive(
        expectsRemoteVideo: true,
        mediaEstablished: true,
        hasRemoteVideoTrack: true,
        rendererHasRemoteVideo: false,
        rendererHasVisibleFrame: false,
        hasInboundRemoteVideo: false,
        nowMs: 9000,
        expectedAtMs: 1000,
        trackReceivedAtMs: 3000,
      );

      expect(lifecycle.state, RemoteVideoLifecycleState.failed);
      expect(
        lifecycle.failureReason,
        RemoteVideoFailureReason.rendererBindingTimeout,
      );
    });

    test(
      'stays rendererBound until an actual visible frame is reported',
      () {
        // rendererBoundAtMs=5500, nowMs=7000 → 1500ms elapsed < 3000ms timeout
        final lifecycle = RemoteVideoLifecycle.derive(
          expectsRemoteVideo: true,
          mediaEstablished: true,
          hasRemoteVideoTrack: true,
          rendererHasRemoteVideo: true,
          rendererHasVisibleFrame: false,
          hasInboundRemoteVideo: false,
          nowMs: 7000,
          expectedAtMs: 1000,
          trackReceivedAtMs: 3000,
          rendererBoundAtMs: 5500,
        );

        expect(lifecycle.state, RemoteVideoLifecycleState.rendererBound);
        expect(lifecycle.isRenderable, isFalse);
      },
    );

    test(
      'fails with rendererNoFrames when renderer is bound but no frames arrive after timeout',
      () {
        // rendererBoundAtMs=2000, nowMs=7000 → 5000ms elapsed > 3000ms timeout
        // This triggers the VideoSink re-registration recovery path.
        final lifecycle = RemoteVideoLifecycle.derive(
          expectsRemoteVideo: true,
          mediaEstablished: true,
          hasRemoteVideoTrack: true,
          rendererHasRemoteVideo: true,
          rendererHasVisibleFrame: false,
          hasInboundRemoteVideo: false,
          nowMs: 7000,
          expectedAtMs: 1000,
          trackReceivedAtMs: 3000,
          rendererBoundAtMs: 2000,
        );

        expect(lifecycle.state, RemoteVideoLifecycleState.failed);
        expect(
          lifecycle.failureReason,
          RemoteVideoFailureReason.rendererNoFrames,
        );
      },
    );

    test('renders when renderer reports the first visible frame', () {
      final lifecycle = RemoteVideoLifecycle.derive(
        expectsRemoteVideo: true,
        mediaEstablished: true,
        hasRemoteVideoTrack: true,
        rendererHasRemoteVideo: true,
        rendererHasVisibleFrame: true,
        hasInboundRemoteVideo: false,
        nowMs: 5000,
        expectedAtMs: 1000,
        trackReceivedAtMs: 2000,
        rendererBoundAtMs: 2500,
      );

      expect(lifecycle.state, RemoteVideoLifecycleState.renderingFrames);
      expect(lifecycle.isRenderable, isTrue);
    });

    test('does not render from inbound video stats alone while the texture stays black', () {
      final lifecycle = RemoteVideoLifecycle.derive(
        expectsRemoteVideo: true,
        mediaEstablished: true,
        hasRemoteVideoTrack: true,
        rendererHasRemoteVideo: true,
        rendererHasVisibleFrame: false,
        hasInboundRemoteVideo: true,
        nowMs: 5000,
        expectedAtMs: 1000,
        trackReceivedAtMs: 2000,
        rendererBoundAtMs: 2500,
      );

      expect(lifecycle.state, RemoteVideoLifecycleState.rendererBound);
      expect(lifecycle.isRenderable, isFalse);
    });
  });

  group('WebRtcCallSession.shouldDeclareMediaEstablished', () {
    test('requires both transport evidence and inbound media', () {
      expect(
        WebRtcCallSession.shouldDeclareMediaEstablished(
          peerConnectionState:
              RTCPeerConnectionState.RTCPeerConnectionStateConnecting,
          iceConnectionState:
              RTCIceConnectionState.RTCIceConnectionStateChecking,
          hasSelectedCandidatePair: true,
          hasInboundRemoteMedia: false,
        ),
        isFalse,
      );
    });

    test('accepts selected candidate pair only after remote media arrives', () {
      expect(
        WebRtcCallSession.shouldDeclareMediaEstablished(
          peerConnectionState:
              RTCPeerConnectionState.RTCPeerConnectionStateConnecting,
          iceConnectionState:
              RTCIceConnectionState.RTCIceConnectionStateChecking,
          hasSelectedCandidatePair: true,
          hasInboundRemoteMedia: true,
        ),
        isTrue,
      );
    });

    test(
      'accepts connected transport with inbound media even without candidate stats',
      () {
        expect(
          WebRtcCallSession.shouldDeclareMediaEstablished(
            peerConnectionState:
                RTCPeerConnectionState.RTCPeerConnectionStateConnected,
            iceConnectionState:
                RTCIceConnectionState.RTCIceConnectionStateConnected,
            hasSelectedCandidatePair: false,
            hasInboundRemoteMedia: true,
          ),
          isTrue,
        );
      },
    );
  });

  group('WebRtcCallSession.selectVideoPresetForQuality', () {
    test('keeps HD for excellent quality', () {
      expect(
        WebRtcCallSession.selectVideoPresetForQuality(
          quality: CallQualityLevel.excellent,
          currentPreset: CallVideoQualityPreset.sd,
          consecutivePoorSamples: 0,
        ),
        CallVideoQualityPreset.hd,
      );
    });

    test('degrades HD to SD on first poor sample', () {
      expect(
        WebRtcCallSession.selectVideoPresetForQuality(
          quality: CallQualityLevel.poor,
          currentPreset: CallVideoQualityPreset.hd,
          consecutivePoorSamples: 1,
        ),
        CallVideoQualityPreset.sd,
      );
    });

    test('degrades to low after repeated poor samples', () {
      expect(
        WebRtcCallSession.selectVideoPresetForQuality(
          quality: CallQualityLevel.poor,
          currentPreset: CallVideoQualityPreset.sd,
          consecutivePoorSamples: 2,
        ),
        CallVideoQualityPreset.low,
      );
    });

    test('recovers low back to SD on good quality before HD', () {
      expect(
        WebRtcCallSession.selectVideoPresetForQuality(
          quality: CallQualityLevel.good,
          currentPreset: CallVideoQualityPreset.low,
          consecutivePoorSamples: 0,
        ),
        CallVideoQualityPreset.sd,
      );
    });
  });

  group('WebRtcCallSession startup video policy', () {
    test('starts requested video sessions at SD instead of HD', () {
      expect(
        WebRtcCallSession.preferredInitialVideoPreset(requestedVideo: true),
        CallVideoQualityPreset.sd,
      );
      expect(
        WebRtcCallSession.preferredInitialVideoPreset(requestedVideo: false),
        CallVideoQualityPreset.low,
      );
    });

    test('builds capture constraints from preset', () {
      final constraints = WebRtcCallSession.buildVideoCaptureConstraints(
        withAudio: false,
        preset: CallVideoQualityPreset.sd,
      );

      expect(constraints['audio'], isFalse);
      final video = constraints['video'] as Map<String, dynamic>;
      expect(video['facingMode'], 'user');
      expect(video['width'], {'ideal': 960, 'min': 640});
      expect(video['height'], {'ideal': 540, 'min': 360});
      expect(video['frameRate'], {'ideal': 20, 'min': 15});
    });
  });
}
