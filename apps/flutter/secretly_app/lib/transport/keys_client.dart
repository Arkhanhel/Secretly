// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:http/http.dart' as http;

import 'server_clock.dart';

import 'resilient_http_client.dart';
import 'service_health_status.dart';
import '../diagnostics/diag_log.dart';

enum KeysDeviceClass { mobile, desktop, web }

extension on KeysDeviceClass {
  String get wireValue => switch (this) {
    KeysDeviceClass.mobile => 'mobile',
    KeysDeviceClass.desktop => 'desktop',
    KeysDeviceClass.web => 'web',
  };
}

enum KeysPolicyFailureCode {
  // Device/registration policy failures (server-enforced product policy).
  profileDeviceLimitReached,
  desktopCompanionEntitlementRequired,
  desktopCompanionLimitReached,
  serverError,
  // register_device_proof diagnostics: every silent `ok=false` branch now
  // surfaces one of these codes so the client can decide between "retry
  // after fixing local state", "rotate device_id", and "abort with a
  // user-visible message". See `server/keys/src/main.rs::reg_proof_fail`.
  invalidProfileId,
  invalidDeviceId,
  invalidIdentityKey,
  challengeMissing,
  challengeExpired,
  challengeNonceMismatch,
  clockSkew,
  signatureInvalid,
  profileSecretMissing,
  profileSecretInvalidFormat,
  profileSecretMismatch,
  profileSecretRequired,
  profileNotFound,
  deviceIdentityKeyMismatch,
  storeError,
  /// П-5 (25.09.2026): номер устройства отвязан (надгробие). Привязывать
  /// заново — только с телефона; новый номер без одобрения не поможет.
  deviceUnlinked,
  unknown,
}

class KeysPolicyFailure implements Exception {
  const KeysPolicyFailure({required this.code, required this.message});

  final KeysPolicyFailureCode code;
  final String message;

  bool get isDesktopCompanionFailure =>
      code == KeysPolicyFailureCode.desktopCompanionEntitlementRequired ||
      code == KeysPolicyFailureCode.desktopCompanionLimitReached;

  /// Failures the caller can likely self-heal by rotating the local
  /// `device_id` (and the associated key material) and retrying once with a
  /// fresh /device/challenge.
  ///
  /// - [signatureInvalid]: local identity key material is corrupt or out of
  ///   sync with the pubkey we just sent; a fresh keypair under a new
  ///   device_id fixes it.
  /// - [deviceIdentityKeyMismatch]: this device_id is already bound to a
  ///   different identity key on the server; rotating device_id side-steps
  ///   the pinning conflict without touching the peer's pinned key.
  bool get isRecoverableByDeviceRotation =>
      code == KeysPolicyFailureCode.signatureInvalid ||
      code == KeysPolicyFailureCode.deviceIdentityKeyMismatch;

  /// Failures that are purely transient and retryable without any local
  /// mutation (clock resync, fresh challenge fetch). Current caller uses
  /// this to distinguish "surface an operator warning" from "fatal".
  bool get isTransientRetryable =>
      code == KeysPolicyFailureCode.challengeMissing ||
      code == KeysPolicyFailureCode.challengeExpired ||
      code == KeysPolicyFailureCode.challengeNonceMismatch ||
      code == KeysPolicyFailureCode.clockSkew ||
      code == KeysPolicyFailureCode.storeError;

  @override
  String toString() => message;
}

/// П-5: ответ сервера ключей на вопрос устройства о себе.
class KeysDeviceSelfStatus {
  const KeysDeviceSelfStatus({
    required this.status,
    this.reason,
    this.unlinkedAtMs,
    required this.nowMs,
  });

  /// `active` | `hidden` | `unlinked` | `unknown`.
  final String status;

  /// `ended_by_owner` | `inactive` | `removed_by_server` — только у `unlinked`.
  final String? reason;
  final int? unlinkedAtMs;
  final int nowMs;

  bool get isUnlinked => status == 'unlinked';

  static KeysDeviceSelfStatus fromJson(Map<String, dynamic> json) =>
      KeysDeviceSelfStatus(
        status: (json['status'] as String? ?? 'unknown').trim(),
        reason: (json['reason'] as String?)?.trim(),
        unlinkedAtMs: (json['unlinked_at_ms'] as num?)?.toInt(),
        nowMs: (json['now_ms'] as num?)?.toInt() ?? 0,
      );
}

class KeysDeviceStatus {
  const KeysDeviceStatus({
    required this.deviceId,
    required this.hasBundle,
    this.identityKeyPubB64,
    this.signedPrekeyPubB64,
    this.signedPrekeySigB64,
  });

  final String deviceId;
  final bool hasBundle;
  final String? identityKeyPubB64;
  final String? signedPrekeyPubB64;
  final String? signedPrekeySigB64;

  bool get hasBundleMetadata =>
      (identityKeyPubB64 ?? '').trim().isNotEmpty &&
      (signedPrekeyPubB64 ?? '').trim().isNotEmpty &&
      (signedPrekeySigB64 ?? '').trim().isNotEmpty;
}

KeysPolicyFailureCode _keysPolicyFailureCodeFromWire(String? wireCode) {
  switch ((wireCode ?? '').trim()) {
    case 'profile_device_limit_reached':
      return KeysPolicyFailureCode.profileDeviceLimitReached;
    case 'desktop_companion_entitlement_required':
      return KeysPolicyFailureCode.desktopCompanionEntitlementRequired;
    case 'desktop_companion_limit_reached':
      return KeysPolicyFailureCode.desktopCompanionLimitReached;
    case 'server_error':
      return KeysPolicyFailureCode.serverError;
    // register_device_proof diagnostics (see server/keys reg_proof_fail).
    case 'invalid_profile_id':
      return KeysPolicyFailureCode.invalidProfileId;
    case 'invalid_device_id':
      return KeysPolicyFailureCode.invalidDeviceId;
    case 'invalid_identity_key':
      return KeysPolicyFailureCode.invalidIdentityKey;
    case 'challenge_missing':
      return KeysPolicyFailureCode.challengeMissing;
    case 'challenge_expired':
      return KeysPolicyFailureCode.challengeExpired;
    case 'challenge_nonce_mismatch':
      return KeysPolicyFailureCode.challengeNonceMismatch;
    case 'clock_skew':
      return KeysPolicyFailureCode.clockSkew;
    case 'signature_invalid':
      return KeysPolicyFailureCode.signatureInvalid;
    case 'profile_secret_missing':
      return KeysPolicyFailureCode.profileSecretMissing;
    case 'profile_secret_invalid_format':
      return KeysPolicyFailureCode.profileSecretInvalidFormat;
    case 'profile_secret_mismatch':
      return KeysPolicyFailureCode.profileSecretMismatch;
    case 'profile_secret_required':
      return KeysPolicyFailureCode.profileSecretRequired;
    case 'profile_not_found':
      return KeysPolicyFailureCode.profileNotFound;
    case 'device_identity_key_mismatch':
      return KeysPolicyFailureCode.deviceIdentityKeyMismatch;
    case 'store_error':
      return KeysPolicyFailureCode.storeError;
    case 'device_unlinked':
      return KeysPolicyFailureCode.deviceUnlinked;
    default:
      return KeysPolicyFailureCode.unknown;
  }
}

class KeysClient {
  KeysClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? createResilientHttpClient(),
      _ownsHttpClient = httpClient == null;

  final Uri baseUrl;
  http.Client _http;
  final bool _ownsHttpClient;

  static const Duration _httpTimeout = Duration(seconds: 8);

  void close() {
    if (_ownsHttpClient) {
      _http.close();
    }
  }

  /// Drops the pooled HTTP connection(s) and opens a fresh client. Used when the
  /// app returns from background: on aggressive vendors (MIUI/Xiaomi) the OS can
  /// freeze a keep-alive socket, which is then reused as a half-open dead socket
  /// and strands `/health` checks until an app restart. No-op for an injected
  /// client (tests).
  void resetConnections() {
    if (!_ownsHttpClient) return;
    try {
      _http.close();
    } catch (_) {
      // ignore
    }
    _http = createResilientHttpClient();
  }

  Future<http.Response> _get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final resp = await _http
        .get(uri, headers: headers)
        .timeout(timeout ?? _httpTimeout);
    _observeServerClock(resp);
    return resp;
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final resp = await _http
        .post(uri, headers: headers, body: body)
        .timeout(timeout ?? _httpTimeout);
    _observeServerClock(resp);
    return resp;
  }

  /// Сверяем часы по каждому ответу сервера.
  ///
  /// Заголовок `Date` есть в любом ответе HTTP, поэтому отдельный запрос за
  /// временем не нужен. Подробности и границы доверия — в `ServerClock`.
  void _observeServerClock(http.Response resp) {
    final raw = resp.headers['date'];
    if (raw == null || raw.isEmpty) return;
    try {
      final parsed = HttpDate.parse(raw);
      if (ServerClock.instance.observeServerDate(parsed)) {
        DiagLog.event('keys', 'server_clock_skew', {
          'offset_s': (ServerClock.instance.offsetMs / 1000).round(),
        });
      }
    } catch (_) {
      // Неразобранная дата — не повод для шума: поправка просто не изменится.
    }
  }

  /// Сколько ждать загрузку резервной копии.
  ///
  /// 🔴 ПОЧЕМУ НЕ ОБЩИЕ ВОСЕМЬ СЕКУНД (14.08.2026). Копия уходила через тот же
  /// метод, что и мелкие операции с ключами, и наследовала их предел. Восемь
  /// секунд выбраны для «опубликовать связку» — там долгое ожидание вредно, оно
  /// маскирует настоящие сбои. Но копия несёт переписку и вложения и РАСТЁТ
  /// вместе с использованием.
  ///
  /// Полевой случай: «Копия не создаётся», `TimeoutException after 0:00:08`,
  /// последняя удачная — 7 августа. Сервер при этом готов принять 200 МБ
  /// (KEYS_BACKUP_MAX_PAYLOAD_BYTES), и Caddy предела не ставит вовсе. То есть
  /// упиралось только во время, и это не сбой, а АРИФМЕТИКА: копия растёт, а
  /// предел стоял на месте — поэтому «сначала работает, потом перестаёт у всех»,
  /// каждый в свой день.
  ///
  /// Считаем от размера: расчёт на скромные 250 КБ/с — это медленный мобильный
  /// интернет, а не идеальный. Пол в 30 секунд закрывает мелкие копии на плохой
  /// связи, потолок в 10 минут не даёт зависшей сети держать приложение вечно.
  /// Сколько времени отводить СКАЧИВАНИЮ копии: размер заранее неизвестен, а
  /// ждать здесь правильно — альтернатива потерянная переписка.
  static const int backupDownloadBudgetBytes = 500 * 1024 * 1024;

  static Duration backupUploadTimeoutFor(int bodyBytes) {
    const bytesPerSecond = 250 * 1024;
    const floor = Duration(seconds: 30);
    const ceiling = Duration(minutes: 10);
    final needed = Duration(
      seconds: (bodyBytes / bytesPerSecond).ceil() + 10,
    );
    if (needed < floor) return floor;
    if (needed > ceiling) return ceiling;
    return needed;
  }

  Future<Map<String, dynamic>> _listDevicesResponseJson(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async {
    final uri = baseUrl.resolve('/v1/profile/$profileId/devices');
    final headers = <String, String>{};
    if (requesterDeviceId != null &&
        requesterDeviceId.isNotEmpty &&
        tsMs != null &&
        nonceB64 != null &&
        nonceB64.isNotEmpty &&
        signatureB64 != null &&
        signatureB64.isNotEmpty) {
      headers['x-secretly-device-id'] = requesterDeviceId;
      headers['x-secretly-ts-ms'] = tsMs.toString();
      headers['x-secretly-nonce-b64'] = nonceB64;
      headers['x-secretly-signature-b64'] = signatureB64;
    }

    final resp = await _get(uri, headers: headers.isEmpty ? null : headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('listDevices failed: ${resp.statusCode} ${resp.body}');
    }
    return _decodeJsonMap(resp, 'listDevices');
  }

  Map<String, dynamic> _decodeJsonMap(http.Response resp, String operation) {
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('$operation returned invalid json payload');
    }
    return decoded;
  }

  void _throwPolicyFailureIfPresent(
    Map<String, dynamic> json,
    String operation,
  ) {
    if (json['ok'] == true) return;
    final errorCode = json['error_code'] as String?;
    final errorMessage =
        (json['error_message'] as String?)?.trim() ?? '$operation failed';
    if (errorCode == null || errorCode.trim().isEmpty) return;
    throw KeysPolicyFailure(
      code: _keysPolicyFailureCodeFromWire(errorCode),
      message: errorMessage,
    );
  }

  Future<bool> health() async {
    final status = await healthStatus();
    return status.isHealthy;
  }

  Future<ServiceHealthStatus> healthStatus({int? clientProtocolVersion}) async {
    final uri = baseUrl.resolve('/health');
    try {
      final effectiveUri = uri.replace(
        queryParameters: {
          if (clientProtocolVersion != null)
            'client_protocol_version': clientProtocolVersion.toString(),
        },
      );
      final resp = await _get(effectiveUri);
      if (resp.statusCode == 426 ||
          (resp.statusCode >= 200 && resp.statusCode < 300)) {
        return ServiceHealthStatus.fromHttpResponse(
          httpStatusCode: resp.statusCode,
          responseBody: resp.body,
          fallbackService: 'keys',
          requestedClientProtocolVersion: clientProtocolVersion,
        );
      }
    } catch (_) {
      return ServiceHealthStatus.unreachable(service: 'keys');
    }
    return ServiceHealthStatus.unreachable(service: 'keys');
  }

  Future<CreateProfileResult> createProfile() async {
    final uri = baseUrl.resolve('/v1/profile/create');
    final resp = await _post(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('createProfile failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final id = json['profile_id'] as String?;
    final secret = json['profile_secret_b64'] as String?;
    if (id == null || id.isEmpty || secret == null || secret.isEmpty) {
      throw StateError('createProfile missing profile_id/profile_secret_b64');
    }
    return CreateProfileResult(profileId: id, profileSecretB64: secret);
  }

  Future<DeviceChallenge> deviceChallenge({
    required String profileId,
    required String deviceId,
    required String profileSecretB64,
  }) async {
    final uri = baseUrl.resolve(
      '/v1/device/challenge?profile_id=$profileId&device_id=$deviceId',
    );
    final resp = await _get(
      uri,
      headers: {'x-secretly-profile-secret-b64': profileSecretB64},
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'deviceChallenge failed: ${resp.statusCode} ${resp.body}',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return DeviceChallenge(
      nonceB64: json['nonce_b64'] as String,
      expiresAtMs: (json['expires_at_ms'] as num).toInt(),
    );
  }

  Future<bool> registerDeviceProof({
    required String profileId,
    required String deviceId,
    required String identityKeyPubB64,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
    required String profileSecretB64,
    KeysDeviceClass deviceClass = KeysDeviceClass.mobile,
    String? deviceLabel,
    // И-1 (TZ §Д-7): id this registration replaces after a state-loss
    // rotation. At the per-profile cap the server evicts the named device
    // instead of the stalest one, protecting an innocent sibling. Additive —
    // old servers ignore it.
    String? replacesDeviceId,
  }) async {
    final uri = baseUrl.resolve('/v1/device/register_proof');
    final resp = await _post(
      uri,
      headers: {
        'content-type': 'application/json',
        'x-secretly-profile-secret-b64': profileSecretB64,
      },
      body: jsonEncode({
        'profile_id': profileId,
        'device_id': deviceId,
        'identity_key_pub_b64': identityKeyPubB64,
        'ts_ms': tsMs,
        'nonce_b64': nonceB64,
        'signature_b64': signatureB64,
        'device_class': deviceClass.wireValue,
        if ((deviceLabel ?? '').trim().isNotEmpty)
          'device_label': deviceLabel!.trim(),
        if ((replacesDeviceId ?? '').trim().isNotEmpty)
          'replaces_device_id': replacesDeviceId!.trim(),
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'registerDeviceProof failed: ${resp.statusCode} ${resp.body}',
      );
    }
    final json = _decodeJsonMap(resp, 'registerDeviceProof');
    _throwPolicyFailureIfPresent(json, 'registerDeviceProof');
    return json['ok'] == true;
  }

  Future<bool> profileExists(String profileId) async {
    final uri = baseUrl.resolve('/v1/profile/$profileId');
    final resp = await _get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('profileExists failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return json['exists'] == true;
  }

  Future<List<ProfileSearchItem>> searchProfiles({
    required String query,
    int limit = 20,
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final safeLimit = limit.clamp(1, 50);
    final uri = baseUrl
        .resolve('/v1/profile/search')
        .replace(queryParameters: {'query': q, 'limit': safeLimit.toString()});
    final headers = <String, String>{};
    if (requesterDeviceId != null &&
        requesterDeviceId.isNotEmpty &&
        tsMs != null &&
        nonceB64 != null &&
        nonceB64.isNotEmpty &&
        signatureB64 != null &&
        signatureB64.isNotEmpty) {
      headers['x-secretly-device-id'] = requesterDeviceId;
      headers['x-secretly-ts-ms'] = tsMs.toString();
      headers['x-secretly-nonce-b64'] = nonceB64;
      headers['x-secretly-signature-b64'] = signatureB64;
    }

    final resp = await _get(uri, headers: headers.isEmpty ? null : headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'searchProfiles failed: ${resp.statusCode} ${resp.body}',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (it) => ProfileSearchItem(
            profileId: it['profile_id'] as String? ?? '',
            nickname: it['nickname'] as String?,
            updatedAtMs: (it['updated_at_ms'] as num?)?.toInt() ?? 0,
          ),
        )
        .where((it) => it.profileId.trim().isNotEmpty)
        .toList(growable: false);
    return items;
  }

  /// П-5: подписанный вопрос устройства о себе (`/v1/device/self_status`).
  /// Работает и для отвязанного: его подпись сервер сверяет ключом из
  /// надгробия. Кроме ответа, сервер отмечает устройство «на связи» (Н-2).
  Future<KeysDeviceSelfStatus> deviceSelfStatus({
    required String deviceId,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
  }) async {
    final uri = baseUrl.resolve('/v1/device/self_status');
    final resp = await _get(
      uri,
      headers: <String, String>{
        'x-secretly-device-id': deviceId,
        'x-secretly-ts-ms': tsMs.toString(),
        'x-secretly-nonce-b64': nonceB64,
        'x-secretly-signature-b64': signatureB64,
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('deviceSelfStatus failed: ${resp.statusCode}');
    }
    return KeysDeviceSelfStatus.fromJson(_decodeJsonMap(resp, 'deviceSelfStatus'));
  }

  Future<List<String>> listDevices(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async {
    final json = await _listDevicesResponseJson(
      profileId,
      requesterDeviceId: requesterDeviceId,
      tsMs: tsMs,
      nonceB64: nonceB64,
      signatureB64: signatureB64,
    );
    final ids = (json['device_ids'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    return ids;
  }

  Future<List<KeysDeviceStatus>> listDeviceStatuses(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async {
    final json = await _listDevicesResponseJson(
      profileId,
      requesterDeviceId: requesterDeviceId,
      tsMs: tsMs,
      nonceB64: nonceB64,
      signatureB64: signatureB64,
    );
    final devices = (json['devices'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (device) => KeysDeviceStatus(
            deviceId: (device['device_id'] as String? ?? '').trim(),
            hasBundle: device['has_bundle'] == true,
            identityKeyPubB64: (device['identity_key_pub_b64'] as String?)
                ?.trim(),
            signedPrekeyPubB64: (device['signed_prekey_pub_b64'] as String?)
                ?.trim(),
            signedPrekeySigB64: (device['signed_prekey_sig_b64'] as String?)
                ?.trim(),
          ),
        )
        .where((device) => device.deviceId.isNotEmpty)
        .toList(growable: false);
    if (devices.isNotEmpty) {
      return devices;
    }

    return (json['device_ids'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .map((deviceId) => deviceId.trim())
        .where((deviceId) => deviceId.isNotEmpty)
        .map(
          (deviceId) => KeysDeviceStatus(deviceId: deviceId, hasBundle: true),
        )
        .toList(growable: false);
  }

  Future<bool> deleteDevice({
    required String profileId,
    required String deviceId,
    required String profileSecretB64,
    required String requesterDeviceId,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
  }) async {
    final uri = baseUrl.resolve('/v1/device/delete');
    final resp = await _post(
      uri,
      headers: {
        'content-type': 'application/json',
        'x-secretly-profile-secret-b64': profileSecretB64,
        'x-secretly-device-id': requesterDeviceId,
        'x-secretly-ts-ms': tsMs.toString(),
        'x-secretly-nonce-b64': nonceB64,
        'x-secretly-signature-b64': signatureB64,
      },
      body: jsonEncode({'profile_id': profileId, 'device_id': deviceId}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('deleteDevice failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return json['ok'] == true;
  }

  Future<bool> deleteProfile({
    required String profileId,
    required String profileSecretB64,
    required String requesterDeviceId,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
  }) async {
    final uri = baseUrl.resolve('/v1/profile/delete');
    final resp = await _post(
      uri,
      headers: {
        'content-type': 'application/json',
        'x-secretly-profile-secret-b64': profileSecretB64,
        'x-secretly-device-id': requesterDeviceId,
        'x-secretly-ts-ms': tsMs.toString(),
        'x-secretly-nonce-b64': nonceB64,
        'x-secretly-signature-b64': signatureB64,
      },
      body: jsonEncode({'profile_id': profileId}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('deleteProfile failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return json['ok'] == true;
  }

  Future<String?> lookupProfileByDevice(String deviceId) async {
    final uri = baseUrl.resolve('/v1/device/$deviceId');
    final resp = await _get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'lookupProfileByDevice failed: ${resp.statusCode} ${resp.body}',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final exists = json['exists'] == true;
    if (!exists) return null;
    final pid = json['profile_id'] as String?;
    if (pid == null || pid.isEmpty) return null;
    return pid;
  }

  Future<String?> lookupProfileByDeviceAuthed({
    required String requesterDeviceId,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
    required String targetDeviceId,
  }) async {
    final uri = baseUrl.resolve('/v1/device/$targetDeviceId');
    final resp = await _get(
      uri,
      headers: {
        'x-secretly-device-id': requesterDeviceId,
        'x-secretly-ts-ms': tsMs.toString(),
        'x-secretly-nonce-b64': nonceB64,
        'x-secretly-signature-b64': signatureB64,
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'lookupProfileByDeviceAuthed failed: ${resp.statusCode} ${resp.body}',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final exists = json['exists'] == true;
    if (!exists) return null;
    final pid = json['profile_id'] as String?;
    if (pid == null || pid.isEmpty) return null;
    return pid;
  }

  Future<bool> publishKeys({
    required String profileId,
    required String deviceId,
    required String identityKeyPubB64,
    required String signedPrekeyPubB64,
    required String signedPrekeySigB64,
    required List<Map<String, Object?>> oneTimePrekeys,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
    required String profileSecretB64,
    String? accountIdentityPubB64,
    String? deviceCertB64,
  }) async {
    final uri = baseUrl.resolve('/v1/keys/publish');
    final aik = accountIdentityPubB64?.trim() ?? '';
    final cert = deviceCertB64?.trim() ?? '';
    final resp = await _post(
      uri,
      headers: {
        'content-type': 'application/json',
        'x-secretly-profile-secret-b64': profileSecretB64,
      },
      body: jsonEncode({
        'profile_id': profileId,
        'device_id': deviceId,
        'identity_key_pub_b64': identityKeyPubB64,
        'signed_prekey_pub_b64': signedPrekeyPubB64,
        'signed_prekey_sig_b64': signedPrekeySigB64,
        'one_time_prekeys': oneTimePrekeys,
        'ts_ms': tsMs,
        'nonce_b64': nonceB64,
        'signature_b64': signatureB64,
        // 🔴 Только ПАРОЙ и только когда обе части есть. Сертификат без ключа,
        // которым он подписан, непроверяем; сервер такую половину всё равно
        // отбросит, но отправлять её незачем.
        //
        // 🔴 В подпись публикации эти поля НЕ входят и входить не должны:
        // подписываемое сообщение `SECRETLY-KEYS-PUBLISH-V1` имеет фиксированный
        // список полей, и расширение его сломало бы подпись у всех старых
        // сборок, убив им публикацию ключей — а с ней доставку.
        if (aik.isNotEmpty && cert.isNotEmpty) 'account_identity_pub_b64': aik,
        if (aik.isNotEmpty && cert.isNotEmpty) 'device_cert_b64': cert,
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('publishKeys failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return json['ok'] == true;
  }

  /// П-1: связка ОДНОГО устройства (`/v1/device/{id}/bundle`) — одноразовый
  /// ключ снимается только у него. Ответ того же вида, что у [fetchBundle].
  Future<List<Map<String, Object?>>> fetchDeviceBundle(
    String deviceId, {
    required String requesterDeviceId,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
  }) async {
    final uri = baseUrl.resolve('/v1/device/${Uri.encodeComponent(deviceId)}/bundle');
    final resp = await _get(
      uri,
      headers: <String, String>{
        'x-secretly-device-id': requesterDeviceId,
        'x-secretly-ts-ms': tsMs.toString(),
        'x-secretly-nonce-b64': nonceB64,
        'x-secretly-signature-b64': signatureB64,
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('fetchDeviceBundle failed: ${resp.statusCode}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return (json['devices'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((d) => d.map((k, v) => MapEntry(k, v as Object?)))
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> fetchBundle(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async {
    final uri = baseUrl.resolve('/v1/keys/bundle/$profileId');
    final headers = <String, String>{};
    if (requesterDeviceId != null &&
        requesterDeviceId.isNotEmpty &&
        tsMs != null &&
        nonceB64 != null &&
        nonceB64.isNotEmpty &&
        signatureB64 != null &&
        signatureB64.isNotEmpty) {
      headers['x-secretly-device-id'] = requesterDeviceId;
      headers['x-secretly-ts-ms'] = tsMs.toString();
      headers['x-secretly-nonce-b64'] = nonceB64;
      headers['x-secretly-signature-b64'] = signatureB64;
    }
    final resp = await _get(uri, headers: headers.isEmpty ? null : headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('fetchBundle failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final devices = (json['devices'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((d) => d.map((k, v) => MapEntry(k, v as Object?)))
        .toList(growable: false);
    return devices;
  }

  Future<ProfileMeta> getProfileMeta(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
  }) async {
    final uri = baseUrl.resolve('/v1/profile/$profileId/meta');
    // SEC-07: подпись необязательна — сервер отвечает и без неё, потому что так
    // ходят уже выпущенные сборки. Но предъявившему её отдают точное время
    // присутствия вместо огрублённого до часа.
    final headers = <String, String>{};
    if ((requesterDeviceId ?? '').isNotEmpty &&
        tsMs != null &&
        (nonceB64 ?? '').isNotEmpty &&
        (signatureB64 ?? '').isNotEmpty) {
      headers['x-secretly-device-id'] = requesterDeviceId!;
      headers['x-secretly-ts-ms'] = tsMs.toString();
      headers['x-secretly-nonce-b64'] = nonceB64!;
      headers['x-secretly-signature-b64'] = signatureB64!;
    }
    final resp = await _get(uri, headers: headers.isEmpty ? null : headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'getProfileMeta failed: ${resp.statusCode} ${resp.body}',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return ProfileMeta(
      exists: json['exists'] == true,
      profileId: json['profile_id'] as String? ?? profileId,
      nickname: json['nickname'] as String?,
      avatarPngB64: json['avatar_png_b64'] as String?,
      bio: json['bio'] as String?,
      privacyAudienceJson: json['privacy_audience_json'] as String?,
      searchableByNickname: json['searchable_by_nickname'] == true,
      updatedAtMs: (json['updated_at_ms'] as num?)?.toInt() ?? 0,
      lastActiveAtMs: (json['last_active_at_ms'] as num?)?.toInt() ?? 0,
      frameId: json['frame_id'] as String?,
      coverId: json['cover_id'] as String?,
      coverPngB64: json['cover_png_b64'] as String?,
      emojiStatus: json['emoji_status'] as String?,
      premiumBadge: json['premium_badge'] as String?,
    );
  }

  Future<bool> setProfileMeta({
    required String profileId,
    required String deviceId,
    required String? nickname,
    required String? avatarPngB64,
    required String? bio,
    required String? privacyAudienceJson,
    required bool searchableByNickname,
    required String signatureB64,
    required String profileSecretB64,
    String? frameId,
    String? coverId,
    String? coverPngB64,
    String? emojiStatus,
    String? premiumBadge,
  }) async {
    final uri = baseUrl.resolve('/v1/profile/meta/set');
    // NOTE: frame_id/cover_id are cosmetic and intentionally NOT part of the
    // signed message (see AuthSigner.keysProfileMetaSetMessage). They are sent
    // in the request body only.
    final resp = await _post(
      uri,
      headers: {
        'content-type': 'application/json',
        'x-secretly-profile-secret-b64': profileSecretB64,
      },
      body: jsonEncode({
        'profile_id': profileId,
        'device_id': deviceId,
        'nickname': nickname,
        'avatar_png_b64': avatarPngB64,
        'bio': bio,
        'privacy_audience_json': privacyAudienceJson,
        'searchable_by_nickname': searchableByNickname,
        'signature_b64': signatureB64,
        'frame_id': frameId,
        'cover_id': coverId,
        'cover_png_b64': coverPngB64,
        'emoji_status': emojiStatus,
        'premium_badge': premiumBadge,
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'setProfileMeta failed: ${resp.statusCode} ${resp.body}',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return json['ok'] == true;
  }

  Future<ProfileInactivityStatus> setProfileInactivity({
    required String profileId,
    required String deviceId,
    required int? deleteAfterInactivityMonths,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
    required String profileSecretB64,
  }) async {
    final uri = baseUrl.resolve('/v1/profile/inactivity/set');
    final resp = await _post(
      uri,
      headers: {
        'content-type': 'application/json',
        'x-secretly-profile-secret-b64': profileSecretB64,
      },
      body: jsonEncode({
        'profile_id': profileId,
        'device_id': deviceId,
        'delete_after_inactivity_months': deleteAfterInactivityMonths,
        'ts_ms': tsMs,
        'nonce_b64': nonceB64,
        'signature_b64': signatureB64,
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'setProfileInactivity failed: ${resp.statusCode} ${resp.body}',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return ProfileInactivityStatus(
      exists: json['exists'] == true,
      ok: json['ok'] == true,
      deleteAfterInactivityMonths:
          (json['delete_after_inactivity_months'] as num?)?.toInt(),
      lastActiveAtMs: (json['last_active_at_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ProfileInactivityStatus> heartbeatProfileInactivity({
    required String profileId,
    required String deviceId,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
    required String profileSecretB64,
  }) async {
    final uri = baseUrl.resolve('/v1/profile/inactivity/heartbeat');
    final resp = await _post(
      uri,
      headers: {
        'content-type': 'application/json',
        'x-secretly-profile-secret-b64': profileSecretB64,
      },
      body: jsonEncode({
        'profile_id': profileId,
        'device_id': deviceId,
        'ts_ms': tsMs,
        'nonce_b64': nonceB64,
        'signature_b64': signatureB64,
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'heartbeatProfileInactivity failed: ${resp.statusCode} ${resp.body}',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return ProfileInactivityStatus(
      exists: json['exists'] == true,
      ok: json['ok'] == true,
      deleteAfterInactivityMonths:
          (json['delete_after_inactivity_months'] as num?)?.toInt(),
      lastActiveAtMs: (json['last_active_at_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Future<bool> backupSet({
    required String profileId,
    required String deviceId,
    required String payload,
    required String payloadSha256B64,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
    required String profileSecretB64,
    String? accessSaltB64,
    String? accessVerifierB64,
  }) async {
    final uri = baseUrl.resolve('/v1/backup/set');
    // Э-1 (SEC-01): опора токена доступа уходит ВМЕСТЕ с архивом и только так.
    // Обе половины либо есть, либо нет — сервер отвергает половину как
    // `incomplete_backup_access`.
    final hasAccess =
        (accessSaltB64 ?? '').isNotEmpty && (accessVerifierB64 ?? '').isNotEmpty;
    final body = jsonEncode({
      'profile_id': profileId,
      'device_id': deviceId,
      'payload': payload,
      'payload_sha256_b64': payloadSha256B64,
      'ts_ms': tsMs,
      'nonce_b64': nonceB64,
      'signature_b64': signatureB64,
      if (hasAccess) 'access_salt_b64': accessSaltB64,
      if (hasAccess) 'access_verifier_b64': accessVerifierB64,
    });
    final timeout = backupUploadTimeoutFor(body.length);
    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    // Замер рядом с правкой: без него через месяц мы снова упрёмся и снова не
    // будем знать, во что именно.
    DiagLog.event('backup', 'upload_begin', {
      'bytes': body.length,
      'timeout_s': timeout.inSeconds,
    });
    final http.Response resp;
    try {
      resp = await _post(
        uri,
        headers: {
          'content-type': 'application/json',
          'x-secretly-profile-secret-b64': profileSecretB64,
        },
        body: body,
        timeout: timeout,
      );
    } catch (e) {
      DiagLog.event('backup', 'upload_failed', {
        'bytes': body.length,
        'timeout_s': timeout.inSeconds,
        'ms': DateTime.now().millisecondsSinceEpoch - startedAtMs,
        'reason': e.runtimeType.toString(),
      });
      rethrow;
    }
    DiagLog.event('backup', 'upload_done', {
      'bytes': body.length,
      'ms': DateTime.now().millisecondsSinceEpoch - startedAtMs,
      'status': resp.statusCode,
    });
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('backupSet failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return json['ok'] == true;
  }

  Future<(bool exists, String? payload, int updatedAtMs)> backupGet(
    String profileId, {
    String? requesterDeviceId,
    int? tsMs,
    String? nonceB64,
    String? signatureB64,
    String? accessTokenB64,
  }) async {
    final uri = baseUrl.resolve('/v1/backup/$profileId');
    final headers = <String, String>{};
    if (requesterDeviceId != null &&
        requesterDeviceId.isNotEmpty &&
        tsMs != null &&
        nonceB64 != null &&
        nonceB64.isNotEmpty &&
        signatureB64 != null &&
        signatureB64.isNotEmpty) {
      headers['x-secretly-device-id'] = requesterDeviceId;
      headers['x-secretly-ts-ms'] = tsMs.toString();
      headers['x-secretly-nonce-b64'] = nonceB64;
      headers['x-secretly-signature-b64'] = signatureB64;
    }
    // Э-1 (SEC-01): токен доступа, выведенный из пароля архива. Нужен там, где
    // подписать запрос нечем — на новом устройстве ключей ещё нет.
    if ((accessTokenB64 ?? '').isNotEmpty) {
      headers['x-secretly-backup-access-b64'] = accessTokenB64!;
    }

    // 🔴 ВОССТАНОВЛЕНИЕ КАЧАЕТ ТУ ЖЕ КОПИЮ (14.08.2026). Оно наследовало те же
    // восемь секунд, что и загрузка, и ломалось по той же арифметике — только
    // хуже: человек, потерявший телефон, не восстановился бы вовсе. Размер
    // заранее неизвестен, поэтому берём потолок: ждать долго тут правильно,
    // альтернатива — потерянная переписка.
    final resp = await _get(
      uri,
      headers: headers.isEmpty ? null : headers,
      timeout: backupUploadTimeoutFor(KeysClient.backupDownloadBudgetBytes),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('backupGet failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final exists = json['exists'] == true;
    final payload = json['payload'] as String?;
    final updatedAtMs = (json['updated_at_ms'] as num?)?.toInt() ?? 0;
    return (exists, payload, updatedAtMs);
  }

  /// Э-1 (SEC-01): соль для вывода токена доступа к архиву.
  ///
  /// Ответ приходит всегда — и для профиля без архива тоже, солью-обманкой.
  /// Так и задумано: различимый ответ работал бы оракулом существования профиля.
  Future<String> backupAccessChallenge(String profileId) async {
    final uri = baseUrl.resolve('/v1/backup/$profileId/challenge');
    final resp = await _get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'backupAccessChallenge failed: ${resp.statusCode} ${resp.body}',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return (json['access_salt_b64'] as String?) ?? '';
  }

  // ── Monetization (TZ-MONETIZE-01 §C-1) ───────────────────────────────────

  /// GET /v1/config — signed monetization kill-switch + limits (S-3). No auth.
  /// Throws on transport/HTTP error; the caller (EntitlementRepository) treats
  /// any failure as fail-open (monetization disabled).
  Future<Map<String, dynamic>> getConfig() async {
    final uri = baseUrl.resolve('/v1/config');
    final resp = await _get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('getConfig failed: ${resp.statusCode} ${resp.body}');
    }
    return _decodeJsonMap(resp, 'getConfig');
  }

  /// GET /v1/profile/{id}/entitlements — owner-only signed entitlement blob
  /// (S-1). Device-auth headers identical to [backupGet].
  Future<Map<String, dynamic>> getEntitlements(
    String profileId, {
    required String requesterDeviceId,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
  }) async {
    final uri = baseUrl.resolve('/v1/profile/$profileId/entitlements');
    final headers = <String, String>{
      'x-secretly-device-id': requesterDeviceId,
      'x-secretly-ts-ms': tsMs.toString(),
      'x-secretly-nonce-b64': nonceB64,
      'x-secretly-signature-b64': signatureB64,
    };
    final resp = await _get(uri, headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('getEntitlements failed: ${resp.statusCode} ${resp.body}');
    }
    return _decodeJsonMap(resp, 'getEntitlements');
  }

  /// POST /v1/entitlements/legacy_claim — device-authenticated grandfathering
  /// (S-4). Returns the HTTP status and parsed body. Status 410 (Gone) means the
  /// legacy window has closed; the caller should stop retrying.
  Future<(int statusCode, Map<String, dynamic>? json)> legacyClaim(
    String profileId, {
    required String requesterDeviceId,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
  }) async {
    final uri = baseUrl.resolve('/v1/entitlements/legacy_claim');
    final headers = <String, String>{
      'content-type': 'application/json',
      'x-secretly-device-id': requesterDeviceId,
      'x-secretly-ts-ms': tsMs.toString(),
      'x-secretly-nonce-b64': nonceB64,
      'x-secretly-signature-b64': signatureB64,
    };
    final resp = await _post(
      uri,
      headers: headers,
      body: jsonEncode({'profile_id': profileId}),
    );
    Map<String, dynamic>? json;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      json = _decodeJsonMap(resp, 'legacyClaim');
    }
    return (resp.statusCode, json);
  }

  /// POST /v1/entitlements/redeem — device-authenticated receipt verification
  /// (S-2). Returns the HTTP status and the parsed (signed) entitlement body on
  /// success. Non-2xx means the receipt was rejected / not yet verifiable.
  Future<(int statusCode, Map<String, dynamic>? json)> redeem(
    String profileId, {
    required String platform,
    String? jws,
    String? purchaseToken,
    String? productId,
    required String requesterDeviceId,
    required int tsMs,
    required String nonceB64,
    required String signatureB64,
  }) async {
    final uri = baseUrl.resolve('/v1/entitlements/redeem');
    final headers = <String, String>{
      'content-type': 'application/json',
      'x-secretly-device-id': requesterDeviceId,
      'x-secretly-ts-ms': tsMs.toString(),
      'x-secretly-nonce-b64': nonceB64,
      'x-secretly-signature-b64': signatureB64,
    };
    final payload = <String, dynamic>{
      'profile_id': profileId,
      'platform': platform,
      if (jws != null) 'jws': jws,
      if (purchaseToken != null) 'purchase_token': purchaseToken,
      if (productId != null) 'product_id': productId,
    };
    final resp = await _post(uri, headers: headers, body: jsonEncode(payload));
    Map<String, dynamic>? json;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      json = _decodeJsonMap(resp, 'redeem');
    }
    return (resp.statusCode, json);
  }
}

class CreateProfileResult {
  const CreateProfileResult({
    required this.profileId,
    required this.profileSecretB64,
  });

  final String profileId;
  final String profileSecretB64;
}

class ProfileMeta {
  const ProfileMeta({
    required this.exists,
    required this.profileId,
    required this.nickname,
    required this.avatarPngB64,
    required this.bio,
    required this.privacyAudienceJson,
    required this.searchableByNickname,
    required this.updatedAtMs,
    required this.lastActiveAtMs,
    this.frameId,
    this.coverId,
    this.coverPngB64,
    this.emojiStatus,
    this.premiumBadge,
  });

  final bool exists;
  final String profileId;
  final String? nickname;
  final String? avatarPngB64;
  final String? bio;
  final String? privacyAudienceJson;
  final bool searchableByNickname;
  final int updatedAtMs;
  final int lastActiveAtMs;

  /// Optional cosmetic (unsigned) fields synced via profile_meta.
  final String? frameId;
  final String? coverId;

  /// Base64 PNG of a user-picked custom cover (when cover_id == 'custom').
  final String? coverPngB64;

  /// Premium cosmetic (unsigned): a chosen emoji shown next to the name.
  final String? emojiStatus;

  /// Premium badge marker (slug, e.g. '1') shown next to the name.
  final String? premiumBadge;
}

class ProfileInactivityStatus {
  const ProfileInactivityStatus({
    required this.exists,
    required this.ok,
    required this.deleteAfterInactivityMonths,
    required this.lastActiveAtMs,
  });

  final bool exists;
  final bool ok;
  final int? deleteAfterInactivityMonths;
  final int lastActiveAtMs;
}

class DeviceChallenge {
  const DeviceChallenge({required this.nonceB64, required this.expiresAtMs});

  final String nonceB64;
  final int expiresAtMs;
}

class ProfileSearchItem {
  const ProfileSearchItem({
    required this.profileId,
    required this.nickname,
    required this.updatedAtMs,
  });

  final String profileId;
  final String? nickname;
  final int updatedAtMs;
}
