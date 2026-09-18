// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/webrtc_call_session.dart';

void main() {
  group('WebRtcCallSession.remoteDescriptionRequestsSendingVideo', () {
    test('does not treat recvonly video m-line as incoming video', () {
      const sdp = 'v=0\r\n'
          'o=- 0 0 IN IP4 127.0.0.1\r\n'
          's=-\r\n'
          't=0 0\r\n'
          'm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
          'a=sendrecv\r\n'
          'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
          'a=recvonly\r\n';

      expect(
        WebRtcCallSession.remoteDescriptionRequestsSendingVideo(sdp),
        isFalse,
      );
    });

    test('treats sendrecv video m-line as incoming video', () {
      const sdp = 'v=0\r\n'
          'o=- 0 0 IN IP4 127.0.0.1\r\n'
          's=-\r\n'
          't=0 0\r\n'
          'm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
          'a=sendrecv\r\n'
          'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
          'a=sendrecv\r\n';

      expect(
        WebRtcCallSession.remoteDescriptionRequestsSendingVideo(sdp),
        isTrue,
      );
    });

    test('treats sendonly video m-line as incoming video', () {
      const sdp = 'v=0\r\n'
          'o=- 0 0 IN IP4 127.0.0.1\r\n'
          's=-\r\n'
          't=0 0\r\n'
          'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
          'a=sendonly\r\n';

      expect(
        WebRtcCallSession.remoteDescriptionRequestsSendingVideo(sdp),
        isTrue,
      );
    });
  });
}