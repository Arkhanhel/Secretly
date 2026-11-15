// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Keeps an upload alive for a short while after the app goes to the
/// background (media audit О7, 15.11.2026).
///
/// iPhone: a standard `beginBackgroundTask` around the job (see
/// `AppDelegate.attachBackgroundTaskChannel`); iOS usually grants ~30 s. Other
/// platforms: nothing changes. Any failure of the channel (old host, tests)
/// just runs the job as before — this never decides whether the upload runs.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class UploadBackgroundTask {
  UploadBackgroundTask._();

  static const MethodChannel _channel = MethodChannel(
    'secretly/background_task',
  );

  static Future<T> guard<T>(Future<T> Function() job) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return job();
    int? key;
    try {
      key = await _channel.invokeMethod<int>('begin');
    } catch (_) {
      key = null;
    }
    try {
      return await job();
    } finally {
      if (key != null) {
        try {
          await _channel.invokeMethod<void>('end', key);
        } catch (_) {}
      }
    }
  }
}
