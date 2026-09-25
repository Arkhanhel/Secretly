// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Production-safe diagnostic logging facade.
//
// Goals:
//  * Single, greppable channel for the messaging pipeline ("Sly/Diag" tag).
//  * Release-mode safe: builds on top of `callOpLog` which already uses the
//    native `secretly/log` MethodChannel and the `[OP]` redaction whitelist
//    enforced by [callLog].
//  * Never logs plaintext message bodies, ratchet keys, ciphertext, raw
//    profile/device IDs, or push tokens. Identifiers are truncated to an
//    8 hex prefix via [pfx]. Long base64 blobs collapse to `<b64:N>`.
//  * Per-(scope,name) rate limiting so a hot loop can't flood logcat.
//
// Usage:
//   DiagLog.event('send', 'fanout_targets', {
//     'peer': DiagLog.pfx(peerProfileId),
//     'count': targets.length,
//   });
//
// Greppable shape on logcat:
//   I/Sly/Diag( ... ): event=send.fanout_targets peer=ab12cd34 count=2

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../calls/call_log.dart';

class DiagLog {
  static const String _tag = 'Sly/Diag';

  // Per-(scope,name) token bucket. Keeps memory bounded by capping the map.
  static final Map<String, _Bucket> _buckets = <String, _Bucket>{};
  static const int _maxBuckets = 256;
  static const int _bucketCapacity = 30; // events
  static const int _bucketRefillMs = 1000; // tokens per second

  /// Truncate any identifier to an 8 hex-character prefix.
  /// For non-hex inputs returns up to 8 leading characters of a sha-like
  /// stable representation. Returns `''` for null/empty.
  static String pfx(Object? id) {
    if (id == null) return '';
    final s = id.toString();
    if (s.isEmpty) return '';
    final clean = s.replaceAll('-', '');
    final n = clean.length < 8 ? clean.length : 8;
    return clean.substring(0, n);
  }

  /// Тот же отпечаток устройства, что печатает реле (`log_fingerprint`,
  /// `server/relay/src/main.rs:1399`): `sha256:<4 байта в hex>:len=<длина>`.
  ///
  /// 🔴 ЗАЧЕМ. Реле обозначает устройство ХЕШЕМ, клиент — ПРЕФИКСОМ настоящего
  /// идентификатора. Это разные пространства имён, и, имея оба журнала, сшить
  /// их было НЕЛЬЗЯ. Именно поэтому разбор сбоя звонка 15.08 закончился ничем:
  /// серверные строки не привязывались ни к одному устройству.
  ///
  /// Формат обязан совпадать с серверным ДОСЛОВНО, иначе сшивка снова не
  /// состоится: обрезка до четырёх байт, строчный hex, длина ИСХОДНОЙ строки
  /// после обрезки пробелов. Закреплено тестом `diag_log_relay_ref_test.dart`.
  static String relayRef(Object? deviceId) {
    final s = (deviceId?.toString() ?? '').trim();
    if (s.isEmpty) return 'empty';
    final digest = sha256.convert(utf8.encode(s)).bytes;
    final hex = digest
        .take(4)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'sha256:$hex:len=${s.length}';
  }

  /// Emit a single event. Silently drops on rate-limit. In release builds
  /// the underlying [callLog] always lets the `[OP]`-prefixed payload
  /// produced by [callOpLog] through after redaction, so this is the
  /// canonical channel for production observability — see audit O1.
  static void event(
    String scope,
    String name, [
    Map<String, Object?> fields = const <String, Object?>{},
  ]) {
    if (scope.isEmpty || name.isEmpty) return;
    if (!_allow('$scope|$name')) return;

    final sanitized = <String, Object?>{};
    fields.forEach((k, v) {
      final key = k.trim();
      if (key.isEmpty) return;
      if (_isForbiddenKey(key)) return;
      sanitized[key] = _sanitizeValue(key, v);
    });

    callOpLog(_tag, '$scope.$name', fields: sanitized);

    final extra = sink;
    if (extra != null) {
      try {
        final buf = StringBuffer('event=$scope.$name');
        sanitized.forEach((k, v) => buf.write(' $k=$v'));
        extra(buf.toString());
      } catch (_) {
        // Журнал не имеет права ронять то, что он описывает.
      }
    }
  }

  /// Дополнительный приёмник событий (25.09.2026). На телефоне пуст: там
  /// события уходят в logcat через канал `secretly/log`. На macOS этого канала
  /// нет, и всё, что писал DiagLog, пропадало — разобрать, почему ПК потерял
  /// сообщение, было нечем. ПК ставит сюда запись в файл
  /// (`DesktopDiagFileLog`). Строка уже очищена: идентификаторы обрезаны,
  /// текста сообщений в ней нет.
  static void Function(String line)? sink;

  // --- internals --------------------------------------------------------

  static bool _allow(String key) {
    final now = DateTime.now().millisecondsSinceEpoch;
    var bucket = _buckets[key];
    if (bucket == null) {
      if (_buckets.length >= _maxBuckets) {
        // Drop the oldest bucket to bound memory.
        final oldestKey = _buckets.entries
            .reduce((a, b) => a.value.lastRefillMs < b.value.lastRefillMs ? a : b)
            .key;
        _buckets.remove(oldestKey);
      }
      bucket = _Bucket(tokens: _bucketCapacity, lastRefillMs: now);
      _buckets[key] = bucket;
    } else {
      final elapsed = now - bucket.lastRefillMs;
      if (elapsed >= _bucketRefillMs) {
        final refill = elapsed ~/ _bucketRefillMs;
        bucket.tokens = (bucket.tokens + refill).clamp(0, _bucketCapacity);
        bucket.lastRefillMs = now;
      }
    }
    if (bucket.tokens <= 0) return false;
    bucket.tokens -= 1;
    return true;
  }

  static bool _isForbiddenKey(String key) {
    final lower = key.toLowerCase();
    return lower == 'text' ||
        lower == 'body' ||
        lower == 'plaintext' ||
        lower == 'payload' ||
        lower == 'message' ||
        lower == 'msg_text' ||
        lower == 'token' ||
        lower == 'fcm_token' ||
        lower == 'apns_token' ||
        lower == 'auth' ||
        lower == 'authorization' ||
        lower == 'password' ||
        lower == 'secret' ||
        lower.endsWith('_secret') ||
        lower.endsWith('_key') ||
        lower == 'key' ||
        lower == 'private_key' ||
        lower == 'priv_key' ||
        lower.contains('plaintext');
  }

  static Object? _sanitizeValue(String key, Object? value) {
    if (value == null) return null;
    if (value is bool || value is int || value is double) return value;
    if (value is Enum) return value.name;
    var s = value.toString();
    // Collapse any base64-looking blob > 16 chars to length marker.
    if (s.length > 16 && _looksBase64(s)) {
      return '<b64:${s.length}>';
    }
    // Hard cap on length.
    if (s.length > 120) {
      s = '${s.substring(0, 117)}...';
    }
    // Strip newlines so the log line stays single-line.
    s = s.replaceAll('\n', ' ').replaceAll('\r', ' ');
    return s;
  }

  static final RegExp _b64Re = RegExp(r'^[A-Za-z0-9+/_=\-]+$');
  static bool _looksBase64(String s) {
    if (s.length < 24) return false;
    return _b64Re.hasMatch(s);
  }

  /// Encode a small json-safe map for one-off snapshots. Not used by [event]
  /// (it goes through callOpLog) but exposed for places that already have a
  /// formatted message string and need consistent escaping.
  static String json(Map<String, Object?> fields) =>
      const JsonEncoder().convert(fields);
}

class _Bucket {
  int tokens;
  int lastRefillMs;
  _Bucket({required this.tokens, required this.lastRefillMs});
}
