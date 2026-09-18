// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:secretly_app/calls/webrtc_call_session.dart';

void main() {
  group('WebRtcCallSession.isLikelyVideoTransceiverCandidate', () {
    test('accepts explicit video sender transceiver', () {
      expect(
        WebRtcCallSession.isLikelyVideoTransceiverCandidate(
          senderKind: 'video',
          receiverKind: null,
          isKnownAudioTransceiver: false,
        ),
        isTrue,
      );
    });

    test('accepts explicit video receiver transceiver', () {
      expect(
        WebRtcCallSession.isLikelyVideoTransceiverCandidate(
          senderKind: null,
          receiverKind: 'video',
          isKnownAudioTransceiver: false,
        ),
        isTrue,
      );
    });

    test('rejects known audio transceiver even when kinds are empty', () {
      expect(
        WebRtcCallSession.isLikelyVideoTransceiverCandidate(
          senderKind: null,
          receiverKind: null,
          isKnownAudioTransceiver: true,
        ),
        isFalse,
      );
    });

    test('rejects explicit audio transceiver', () {
      expect(
        WebRtcCallSession.isLikelyVideoTransceiverCandidate(
          senderKind: 'audio',
          receiverKind: null,
          isKnownAudioTransceiver: false,
        ),
        isFalse,
      );
    });

    test('accepts pending non-audio transceiver with empty kinds', () {
      expect(
        WebRtcCallSession.isLikelyVideoTransceiverCandidate(
          senderKind: null,
          receiverKind: null,
          isKnownAudioTransceiver: false,
        ),
        isTrue,
      );
    });
  });

  group('WebRtcCallSession.selectPreferredVideoCodecCapabilities', () {
    test('prefers VP8-family codecs ahead of H264', () {
      final ordered = WebRtcCallSession.selectPreferredVideoCodecCapabilities([
        RTCRtpCodecCapability(mimeType: 'video/H264', clockRate: 90000),
        RTCRtpCodecCapability(mimeType: 'video/rtx', clockRate: 90000),
        RTCRtpCodecCapability(mimeType: 'video/VP8', clockRate: 90000),
        RTCRtpCodecCapability(mimeType: 'video/red', clockRate: 90000),
      ]);

      expect(ordered.map((codec) => codec.mimeType).toList(), <String>[
        'video/VP8',
        'video/rtx',
        'video/red',
        'video/H264',
      ]);
    });

    test('preserves original order when safer codecs are unavailable', () {
      final original = <RTCRtpCodecCapability>[
        RTCRtpCodecCapability(mimeType: 'video/H264', clockRate: 90000),
        RTCRtpCodecCapability(mimeType: 'video/rtx', clockRate: 90000),
      ];

      final ordered = WebRtcCallSession.selectPreferredVideoCodecCapabilities(
        original,
      );

      expect(ordered.map((codec) => codec.mimeType).toList(), <String>[
        'video/H264',
        'video/rtx',
      ]);
    });
  });
}
