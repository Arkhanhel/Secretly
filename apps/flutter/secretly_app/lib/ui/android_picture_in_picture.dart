// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cross-platform Picture-in-Picture bridge for active video calls.
///
/// On Android (API 26+): backed by the Activity's `enterPictureInPictureMode`
/// with `setAutoEnterEnabled(true)` so PiP triggers automatically when the
/// user presses Home or switches apps during a video call.
///
/// On iOS (15+): backed by [AVPictureInPictureController] in video-call mode,
/// which mounts an invisible host view in the Flutter window so the system can
/// auto-enter PiP when the app is backgrounded. Audio continues uninterrupted
/// via CallKit + AVAudioSession.
///
/// All methods are safe to call on unsupported platforms (return `false`).
///
/// Default aspect ratio is **portrait 9:16** so the system PiP window matches
/// the typical 1-to-1 video call camera orientation (face vertically).
class NativePictureInPicture {
  NativePictureInPicture._();

  static const MethodChannel _channel = MethodChannel(
    'secretly/picture_in_picture',
  );

  static const EventChannel _eventsChannel = EventChannel(
    'secretly/picture_in_picture_events',
  );

  static bool get _isSupportedPlatform => Platform.isAndroid || Platform.isIOS;

  /// Live mirror of the OS PiP mode. Flutter widgets can rebuild against this
  /// notifier to hide app UX overlays while the system has shrunk the window.
  ///
  /// `true` while the OS reports the activity is in PiP, `false` otherwise.
  static final ValueNotifier<bool> isInPipMode = ValueNotifier<bool>(false);

  // Holds the app-lifetime PiP-events subscription. The OS PiP-mode mirror must
  // run for the whole process, so this listener is bound once (guarded by
  // [_eventsBound]) and intentionally never cancelled — the field is a
  // reference holder, hence written but not read.
  // ignore: unused_field
  static StreamSubscription<dynamic>? _eventsSub;
  static bool _eventsBound = false;

  static void _ensureEventsBound() {
    if (_eventsBound || !_isSupportedPlatform) return;
    _eventsBound = true;
    try {
      _eventsSub = _eventsChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final value = event['isInPip'];
            if (value is bool) {
              if (isInPipMode.value != value) {
                isInPipMode.value = value;
              }
            }
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {
      _eventsBound = false;
    }
  }

  /// Returns true if the underlying OS supports native PiP for this app.
  static Future<bool> isSupported() async {
    if (!_isSupportedPlatform) return false;
    _ensureEventsBound();
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Enable / disable automatic PiP entry on app-background.
  ///
  /// - [enabled] turns auto-PiP on or off for the current call.
  /// - [peerName] is shown in the iOS PiP placeholder. Ignored on Android.
  /// - [aspectWidth] / [aspectHeight] tune the Android PiP aspect ratio.
  ///   Default is 9:16 (portrait) to match a typical 1-to-1 video-call camera
  ///   feed. Ignored on iOS.
  static Future<bool> setAutoEnterEnabled({
    required bool enabled,
    String peerName = '',
    int aspectWidth = 9,
    int aspectHeight = 16,
  }) async {
    if (!_isSupportedPlatform) return false;
    _ensureEventsBound();
    try {
      return await _channel.invokeMethod<bool>('setAutoEnterEnabled', {
            'enabled': enabled,
            'peerName': peerName,
            'aspectWidth': aspectWidth,
            'aspectHeight': aspectHeight,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Request immediate entry into PiP mode. Returns `false` if PiP cannot be
  /// activated right now (no active video stream, perm denied, not configured).
  static Future<bool> enter({
    int aspectWidth = 9,
    int aspectHeight = 16,
  }) async {
    if (!_isSupportedPlatform) return false;
    _ensureEventsBound();
    try {
      return await _channel.invokeMethod<bool>('enter', {
            'aspectWidth': aspectWidth,
            'aspectHeight': aspectHeight,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}

/// Backwards-compatible alias retained for call sites that still reference
/// the original Android-only name. New code should use [NativePictureInPicture].
@Deprecated('Use NativePictureInPicture instead — works on Android and iOS.')
typedef AndroidPictureInPicture = NativePictureInPicture;
