// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../diagnostics/diag_log.dart';

/// iOS NSE bridge (2026-07-17, delivery-wake NSE).
///
/// Mirrors the identity/config the Notification Service Extension needs into
/// the shared App Group, and reads back the ciphertexts the NSE staged while
/// the app was asleep. iOS-only; a no-op everywhere else.
///
/// The NSE authenticates GET /v1/pending in the background and writes pending
/// ciphertexts to an App-Group file. On launch/resume the app imports those
/// (into its quarantine store, applied by the existing replay driver) so the
/// chat is already populated — even after a full night in deep sleep, which
/// iOS otherwise never wakes the app for.
class NseConfigBridge {
  NseConfigBridge._();

  static const MethodChannel _channel = MethodChannel('secretly/nse_config');

  static bool get _supported => Platform.isIOS;

  /// Push device_id / profile_id / relay base URL / identity signing seed /
  /// current delivery cursor into the App Group. Call after login and whenever
  /// endpoints or the cursor change materially.
  static Future<void> sync({
    required String deviceId,
    required String profileId,
    required String baseUrl,
    required String identitySeedB64,
    required int nextSeq,
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('sync', <String, Object?>{
        'device_id': deviceId,
        'profile_id': profileId,
        'base_url': baseUrl,
        'identity_seed_b64': identitySeedB64,
        'next_seq': nextSeq,
      });
    } catch (_) {
      // Non-fatal: without the mirror the NSE just can't pre-fetch; the app
      // still drains normally on open.
    }
  }

  /// Keep the NSE's from_seq aligned with the app's advanced delivery cursor so
  /// it doesn't re-fetch already-applied rows.
  static Future<void> updateCursor(int nextSeq) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('updateCursor', <String, Object?>{
        'next_seq': nextSeq,
      });
    } catch (_) {}
  }

  static Future<void> clearBadgeHint() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('clearBadgeHint');
    } catch (_) {}
  }

  /// Read (and clear) the NDJSON the NSE staged. Returns one map per line with
  /// `msg_id` + `ciphertext_b64`, or empty when nothing was staged.
  static Future<
    List<({String msgId, String ciphertextB64, String? fromDeviceId})>
  >
  readStaged() async {
    if (!_supported) return const [];
    String? raw;
    try {
      raw = await _channel.invokeMethod<String>('readStaged');
    } catch (_) {
      return const [];
    }
    if (raw == null || raw.trim().isEmpty) return const [];
    final out =
        <({String msgId, String ciphertextB64, String? fromDeviceId})>[];
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        final m = jsonDecode(t);
        if (m is! Map) continue;
        final msgId = (m['msg_id'] as String?)?.trim() ?? '';
        final cipher = (m['ciphertext_b64'] as String?) ?? '';
        if (msgId.isNotEmpty && cipher.isNotEmpty) {
          final from = (m['from_device_id'] as String?)?.trim();
          out.add((
            msgId: msgId,
            ciphertextB64: cipher,
            fromDeviceId: (from == null || from.isEmpty) ? null : from,
          ));
        }
      } catch (_) {
        // Skip a malformed line; the relay still holds the row for the normal
        // drain, so nothing is lost.
      }
    }
    if (out.isNotEmpty) {
      DiagLog.event('push', 'nse_staged_read', {'count': out.length});
    }
    return out;
  }
}
