// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/webrtc_call_session.dart';

void main() {
  group('WebRtcCallSession.isDisposedWebRtcHandleError', () {
    test('recognizes disposed transceiver errors from Android runtime', () {
      expect(
        WebRtcCallSession.isDisposedWebRtcHandleError(
          StateError('java.lang.IllegalStateException: RtpTransceiver has been disposed.'),
        ),
        isTrue,
      );
    });

    test('recognizes disposed sender errors', () {
      expect(
        WebRtcCallSession.isDisposedWebRtcHandleError(
          StateError('RTCRtpSender has been disposed'),
        ),
        isTrue,
      );
    });

    test('does not treat unrelated failures as disposed handle errors', () {
      expect(
        WebRtcCallSession.isDisposedWebRtcHandleError(
          StateError('Operation not supported on this platform'),
        ),
        isFalse,
      );
    });
  });

  group('WebRtcCallSession.shouldClearRendererBeforeBinding', () {
    test('clears renderer for explicit reattach', () {
      expect(
        WebRtcCallSession.shouldClearRendererBeforeBinding(
          forceReattach: true,
          sameTrackAsCurrent: false,
          rendererAlreadyBound: false,
        ),
        isTrue,
      );
    });

    test('clears renderer when rebinding the same track', () {
      expect(
        WebRtcCallSession.shouldClearRendererBeforeBinding(
          forceReattach: false,
          sameTrackAsCurrent: true,
          rendererAlreadyBound: false,
        ),
        isTrue,
      );
    });

    test('clears renderer when replacing an already bound remote track', () {
      expect(
        WebRtcCallSession.shouldClearRendererBeforeBinding(
          forceReattach: false,
          sameTrackAsCurrent: false,
          rendererAlreadyBound: true,
        ),
        isTrue,
      );
    });

    test('skips clear for first renderer bind', () {
      expect(
        WebRtcCallSession.shouldClearRendererBeforeBinding(
          forceReattach: false,
          sameTrackAsCurrent: false,
          rendererAlreadyBound: false,
        ),
        isFalse,
      );
    });
  });
}