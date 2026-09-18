// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/services.dart';

class PlatformFileOpen {
  PlatformFileOpen._();

  static const MethodChannel _channel = MethodChannel('secretly/file_open');

  static Future<bool> open({
    required String path,
    String? mime,
    String? displayName,
  }) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('open', <String, Object?>{
            'path': normalizedPath,
            'mime': mime?.trim(),
            'displayName': displayName?.trim(),
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
