// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/webrtc_call_session.dart';

void main() {
  group('WebRtcCallSession.shouldPrepareLocalVideoForIncomingOffer', () {
    test('prepares local video for incoming upgrade on existing audio session', () {
      expect(
        WebRtcCallSession.shouldPrepareLocalVideoForIncomingOffer(
          requestedLocalVideo: true,
          localVideoAlreadyPresent: false,
        ),
        isTrue,
      );
    });

    test('prepares local video on first incoming video setup path', () {
      expect(
        WebRtcCallSession.shouldPrepareLocalVideoForIncomingOffer(
          requestedLocalVideo: true,
          localVideoAlreadyPresent: false,
        ),
        isTrue,
      );
    });

    test('does not prepare local video when track already exists', () {
      expect(
        WebRtcCallSession.shouldPrepareLocalVideoForIncomingOffer(
          requestedLocalVideo: true,
          localVideoAlreadyPresent: true,
        ),
        isFalse,
      );
    });

    test('does not prepare local video for pure audio incoming offer', () {
      expect(
        WebRtcCallSession.shouldPrepareLocalVideoForIncomingOffer(
          requestedLocalVideo: false,
          localVideoAlreadyPresent: false,
        ),
        isFalse,
      );
    });
  });
}