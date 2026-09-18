// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/calls/call_manager.dart';

void main() {
  group('CallManager.shouldAcceptNativeCallAction', () {
    test('accepts matching call id and attempt id', () {
      expect(
        CallManager.shouldAcceptNativeCallAction(
          currentCallId: 'call-1',
          currentCallAttemptId: 'attempt-1',
          actionCallId: 'call-1',
          actionCallAttemptId: 'attempt-1',
        ),
        isTrue,
      );
    });

    test('rejects stale action for same call id but different attempt id', () {
      expect(
        CallManager.shouldAcceptNativeCallAction(
          currentCallId: 'call-1',
          currentCallAttemptId: 'attempt-new',
          actionCallId: 'call-1',
          actionCallAttemptId: 'attempt-old',
        ),
        isFalse,
      );
    });

    test('falls back to call id when attempt id is absent', () {
      expect(
        CallManager.shouldAcceptNativeCallAction(
          currentCallId: 'call-1',
          currentCallAttemptId: '',
          actionCallId: 'call-1',
          actionCallAttemptId: '',
        ),
        isTrue,
      );
    });

    test('rejects action for different call id', () {
      expect(
        CallManager.shouldAcceptNativeCallAction(
          currentCallId: 'call-1',
          currentCallAttemptId: 'attempt-1',
          actionCallId: 'call-2',
          actionCallAttemptId: 'attempt-1',
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldBufferNativeCallActionWithoutState', () {
    test('buffers accept and decline before Flutter has call state', () {
      expect(
        CallManager.shouldBufferNativeCallActionWithoutState(
          currentCallId: '',
          action: 'accept',
        ),
        isTrue,
      );
      expect(
        CallManager.shouldBufferNativeCallActionWithoutState(
          currentCallId: '',
          action: 'decline',
        ),
        isTrue,
      );
    });

    test('does not buffer hangup or actions for an existing call', () {
      expect(
        CallManager.shouldBufferNativeCallActionWithoutState(
          currentCallId: '',
          action: 'hangup',
        ),
        isFalse,
      );
      expect(
        CallManager.shouldBufferNativeCallActionWithoutState(
          currentCallId: 'call-1',
          action: 'decline',
        ),
        isFalse,
      );
    });

    test('never buffers a notification-body tap', () {
      // The buffer has ONE slot and the last writer wins. A tap queued as if it
      // were a decision would overwrite an accept the user pressed a moment
      // earlier — the answer would vanish. A tap is adopted, never buffered.
      expect(
        CallManager.shouldBufferNativeCallActionWithoutState(
          currentCallId: '',
          action: 'tap',
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldAdoptNativeIncomingRingWithoutState', () {
    test('adopts a body tap for a call this isolate never heard of', () {
      // Cold start: the ring was posted by the native FCM service while Flutter
      // was not running, so there is no call state to match against.
      expect(
        CallManager.shouldAdoptNativeIncomingRingWithoutState(
          currentCallId: '',
          action: 'tap',
        ),
        isTrue,
      );
    });

    test('does not adopt when a call is already in state', () {
      expect(
        CallManager.shouldAdoptNativeIncomingRingWithoutState(
          currentCallId: 'call-1',
          action: 'tap',
        ),
        isFalse,
      );
    });

    test('adopts nothing but a tap', () {
      // `restore` comes from the ONGOING-call notification, which implies a
      // live call — adopting it would seed an incoming ring that was never
      // posted. Decisions are buffered instead, never adopted.
      for (final action in const ['restore', 'accept', 'decline', 'hangup']) {
        expect(
          CallManager.shouldAdoptNativeIncomingRingWithoutState(
            currentCallId: '',
            action: action,
          ),
          isFalse,
          reason: '$action must not be adopted as an incoming ring',
        );
      }
    });
  });
}
