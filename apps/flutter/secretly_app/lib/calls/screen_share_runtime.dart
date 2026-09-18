// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_log.dart';

class ScreenShareRuntimeLease {
  ScreenShareRuntimeLease._();

  bool _released = false;

  Future<void> release() async {
    if (_released) {
      return;
    }
    _released = true;
    await ScreenShareRuntime._releaseLease();
  }
}

class ScreenShareRuntime {
  static const FlutterBackgroundAndroidConfig _androidConfig =
      FlutterBackgroundAndroidConfig(
        notificationTitle: 'Screen sharing active',
        notificationText: 'Secretly is sharing your screen during a call.',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(
          name: 'ic_launcher',
          defType: 'mipmap',
        ),
      );

  static int _activeLeaseCount = 0;
  static Future<void> _serial = Future<void>.value();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<ScreenShareRuntimeLease?> acquire() {
    return _serialize<ScreenShareRuntimeLease?>(() async {
      if (!_isAndroid) {
        return ScreenShareRuntimeLease._();
      }

      final hasCapturePermission = await Helper.requestCapturePermission();
      if (!hasCapturePermission) {
        callLog('ScreenShareRuntime', 'capture permission denied');
        return null;
      }

      final ready = await _ensureBackgroundExecution();
      if (!ready) {
        callLog('ScreenShareRuntime', 'background execution unavailable');
        return null;
      }

      _activeLeaseCount += 1;
      callLog(
        'ScreenShareRuntime',
        'lease acquired count=$_activeLeaseCount',
      );
      return ScreenShareRuntimeLease._();
    });
  }

  static Future<void> _releaseLease() {
    return _serialize<void>(() async {
      if (!_isAndroid) {
        return;
      }

      if (_activeLeaseCount > 0) {
        _activeLeaseCount -= 1;
      }

      if (_activeLeaseCount > 0) {
        callLog(
          'ScreenShareRuntime',
          'lease released count=$_activeLeaseCount',
        );
        return;
      }

      if (!FlutterBackground.isBackgroundExecutionEnabled) {
        return;
      }

      try {
        await FlutterBackground.disableBackgroundExecution();
        callLog('ScreenShareRuntime', 'background execution disabled');
      } catch (e) {
        callLog(
          'ScreenShareRuntime',
          'background disable failed: $e',
        );
      }
    });
  }

  static Future<bool> _ensureBackgroundExecution() async {
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        var hasPermissions = await FlutterBackground.hasPermissions;
        if (!hasPermissions) {
          hasPermissions = await FlutterBackground.initialize(
            androidConfig: _androidConfig,
          );
        }

        if (!hasPermissions) {
          return false;
        }

        if (!FlutterBackground.isBackgroundExecutionEnabled) {
          await FlutterBackground.enableBackgroundExecution();
        }

        return FlutterBackground.isBackgroundExecutionEnabled;
      } catch (e) {
        callLog(
          'ScreenShareRuntime',
          'background enable attempt ${attempt + 1} failed: $e',
        );
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    }

    return false;
  }

  static Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _serial = _serial.catchError((_) {}).then((_) async {
      try {
        final value = await operation();
        completer.complete(value);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}