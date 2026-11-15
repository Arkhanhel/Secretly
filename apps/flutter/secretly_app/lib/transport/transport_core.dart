// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Привязка к библиотеке транспорта SeyLock (крейт `seylock`; до 15.10.2026 —
/// `secretly_transport`; Э1, 10.10.2026).
///
/// Библиотека собирается плагином `third_party/secretly_transport_ffi`
/// (cargokit) и живёт в процессе приложения: локальный обратный прокси на
/// loopback, выбор пути, TLS наружу. Здесь — только тонкий C-ABI.
///
/// Правила: любая строка, полученная от библиотеки, освобождается
/// `seylock_string_free`; ошибки — кодами (см. `ffi.rs`); если
/// библиотеку не удалось загрузить (тесты, сборка без плагина) — [tryLoad]
/// возвращает `null`, и клиент работает как раньше, напрямую.
abstract class TransportCoreApi {
  String get version;

  /// Запускает прокси. Возвращает порт и токен или бросает [TransportCoreException].
  TransportStarted start(String policyJson);
  void update(String policyJson);
  void setNetwork(String networkId);

  /// JSON состояния или `null`, если прокси не запущен.
  String? statusJson();
  bool stop();

  /// 0 — список принят, `outDoc` получает JSON; иначе код ошибки.
  (int, String?) verifyEndpoints({
    required String signedJson,
    required String verifyingKeyB64,
    required int nowMs,
    required int currentIssuedAtMs,
  });
}

class TransportStarted {
  const TransportStarted({required this.port, required this.token});
  final int port;
  final String token;
}

class TransportCoreException implements Exception {
  const TransportCoreException(this.code, this.what);
  final int code;
  final String what;
  @override
  String toString() => 'TransportCoreException($what, code $code)';
}

typedef _VersionNative = ffi.Pointer<ffi.Char> Function();
typedef _VersionDart = ffi.Pointer<ffi.Char> Function();
typedef _FreeNative = ffi.Void Function(ffi.Pointer<ffi.Char>);
typedef _FreeDart = void Function(ffi.Pointer<ffi.Char>);
typedef _StartNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Uint16>,
      ffi.Pointer<ffi.Pointer<ffi.Char>>,
    );
typedef _StartDart =
    int Function(
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Uint16>,
      ffi.Pointer<ffi.Pointer<ffi.Char>>,
    );
typedef _StrToIntNative = ffi.Int32 Function(ffi.Pointer<ffi.Char>);
typedef _StrToIntDart = int Function(ffi.Pointer<ffi.Char>);
typedef _NoArgIntNative = ffi.Int32 Function();
typedef _NoArgIntDart = int Function();
typedef _VerifyNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Int64,
      ffi.Int64,
      ffi.Pointer<ffi.Pointer<ffi.Char>>,
    );
typedef _VerifyDart =
    int Function(
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      int,
      int,
      ffi.Pointer<ffi.Pointer<ffi.Char>>,
    );

class TransportCore implements TransportCoreApi {
  TransportCore._(ffi.DynamicLibrary lib)
    : _version = lib.lookupFunction<_VersionNative, _VersionDart>(
        'seylock_version',
      ),
      _free = lib.lookupFunction<_FreeNative, _FreeDart>(
        'seylock_string_free',
      ),
      _start = lib.lookupFunction<_StartNative, _StartDart>(
        'seylock_start',
      ),
      _update = lib.lookupFunction<_StrToIntNative, _StrToIntDart>(
        'seylock_update',
      ),
      _setNetwork = lib.lookupFunction<_StrToIntNative, _StrToIntDart>(
        'seylock_set_network',
      ),
      _status = lib.lookupFunction<_VersionNative, _VersionDart>(
        'seylock_status_json',
      ),
      _stop = lib.lookupFunction<_NoArgIntNative, _NoArgIntDart>(
        'seylock_stop',
      ),
      _verify = lib.lookupFunction<_VerifyNative, _VerifyDart>(
        'seylock_endpoints_verify',
      );

  final _VersionDart _version;
  final _FreeDart _free;
  final _StartDart _start;
  final _StrToIntDart _update;
  final _StrToIntDart _setNetwork;
  final _VersionDart _status;
  final _NoArgIntDart _stop;
  final _VerifyDart _verify;

  /// Загруженная библиотека или `null`, если её нет в этой сборке.
  static TransportCore? tryLoad() {
    try {
      return TransportCore._(_open());
    } catch (_) {
      return null;
    }
  }

  /// Для живых тестов на машине разработчика: библиотека по явному пути.
  @visibleForTesting
  static TransportCore loadFrom(String path) =>
      TransportCore._(ffi.DynamicLibrary.open(path));

  static ffi.DynamicLibrary _open() {
    if (Platform.isAndroid || Platform.isLinux) {
      return ffi.DynamicLibrary.open('libseylock.so');
    }
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('seylock.dll');
    }
    // iOS и macOS: статическая библиотека вшита в приложение (-force_load).
    return ffi.DynamicLibrary.process();
  }

  String _take(ffi.Pointer<ffi.Char> ptr) {
    if (ptr.address == 0) return '';
    try {
      return ptr.cast<Utf8>().toDartString();
    } finally {
      _free(ptr);
    }
  }

  @override
  String get version => _take(_version());

  @override
  TransportStarted start(String policyJson) {
    final json = policyJson.toNativeUtf8();
    final port = calloc<ffi.Uint16>();
    final token = calloc<ffi.Pointer<ffi.Char>>();
    try {
      final code = _start(json.cast(), port, token);
      if (code != 0) {
        throw TransportCoreException(code, 'start');
      }
      return TransportStarted(port: port.value, token: _take(token.value));
    } finally {
      calloc.free(json);
      calloc.free(port);
      calloc.free(token);
    }
  }

  @override
  void update(String policyJson) {
    final json = policyJson.toNativeUtf8();
    try {
      final code = _update(json.cast());
      if (code != 0) throw TransportCoreException(code, 'update');
    } finally {
      calloc.free(json);
    }
  }

  @override
  void setNetwork(String networkId) {
    final id = networkId.toNativeUtf8();
    try {
      final code = _setNetwork(id.cast());
      if (code != 0) throw TransportCoreException(code, 'set_network');
    } finally {
      calloc.free(id);
    }
  }

  @override
  String? statusJson() {
    final ptr = _status();
    if (ptr.address == 0) return null;
    return _take(ptr);
  }

  @override
  bool stop() => _stop() == 0;

  @override
  (int, String?) verifyEndpoints({
    required String signedJson,
    required String verifyingKeyB64,
    required int nowMs,
    required int currentIssuedAtMs,
  }) {
    final signed = signedJson.toNativeUtf8();
    final key = verifyingKeyB64.toNativeUtf8();
    final out = calloc<ffi.Pointer<ffi.Char>>();
    try {
      final code = _verify(signed.cast(), key.cast(), nowMs, currentIssuedAtMs, out);
      final doc = code == 0 && out.value.address != 0 ? _take(out.value) : null;
      return (code, doc);
    } finally {
      calloc.free(signed);
      calloc.free(key);
      calloc.free(out);
    }
  }
}

/// Разобранное состояние прокси (JSON `Status` из `runtime.rs`).
class TransportStatus {
  const TransportStatus({
    required this.port,
    required this.currentKind,
    required this.networkId,
    required this.memoryJson,
    required this.issuedAtMs,
  });

  final int port;
  final String? currentKind;
  final String networkId;
  final String memoryJson;
  final int issuedAtMs;

  static TransportStatus? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return TransportStatus(
        port: (m['port'] as num).toInt(),
        currentKind: m['current_kind'] as String?,
        networkId: (m['network_id'] as String?) ?? '',
        memoryJson: jsonEncode(m['memory'] ?? const <String, Object?>{}),
        issuedAtMs: (m['issued_at_ms'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
