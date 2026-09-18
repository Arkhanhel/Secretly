// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:secretly_app/security/backup_password_policy.dart';
import 'package:secretly_app/security/restore_payload_validation.dart';

class RecoveryKitPlainV1 {
  const RecoveryKitPlainV1({
    required this.profileId,
    required this.profileSecretB64,
    required this.deviceId,
    required this.deviceKeysMaterialJson,
    required this.serverBinding,
    this.accountIdentitySeedB64,
  });

  final String profileId;
  final String profileSecretB64;
  final String deviceId;
  final String deviceKeysMaterialJson;
  final String serverBinding;

  /// Сид ключа личности АККАУНТА (AIK) — то, чем номер безопасности перестаёт
  /// зависеть от устройства. `null` у китов, снятых до слоя 2.
  ///
  /// 🔴 ПОЧЕМУ ВЕРСИЯ КИТА ОСТАЛАСЬ 1, ХОТЯ ТЗ ТРЕБОВАЛО v2 (К-18, найдено при
  /// разборе 08.08). [fromJson] отвергает чужую версию: `if (v != 1) throw`.
  /// Подними версию — и СТАРАЯ сборка не прочитает новый кит вовсе, а человек,
  /// сделавший кит на новой сборке и восстанавливающийся на старой либо после
  /// откота, **потеряет аккаунт**. Это тот же шрам, что потеря личности 30.07.
  ///
  /// Необязательное поле внутри v1 безопасно в ОБЕ стороны: [fromJson] читает
  /// только знакомые ключи и лишние игнорирует, поэтому старая сборка спокойно
  /// восстановит профиль, просто без AIK — а он ей и не нужен.
  final String? accountIdentitySeedB64;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'v': 1,
      'profile_id': profileId,
      'profile_secret_b64': profileSecretB64,
      'device_id': deviceId,
      'device_keys_material_json': deviceKeysMaterialJson,
      'server_binding': serverBinding,
    };
    // Ключ добавляется ТОЛЬКО когда есть что положить: кит без AIK обязан
    // остаться байт в байт таким же, каким был, иначе сравнение форматов при
    // отладке начнёт врать.
    final seed = accountIdentitySeedB64?.trim();
    if (seed != null && seed.isNotEmpty) {
      json['account_identity_seed_b64'] = seed;
    }
    return json;
  }

  static RecoveryKitPlainV1 fromJson(Map<String, Object?> json) {
    String reqStr(String k) {
      final v = json[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      throw StateError('Recovery kit missing $k');
    }

    final v = json['v'];
    if (v != 1) throw StateError('Unsupported recovery kit version: $v');

    // 🔴 Необязательно и БЕЗ броска. Кит, снятый до слоя 2, обязан продолжать
    // восстанавливать профиль: требование поля здесь означало бы, что старые
    // киты перестали работать, то есть потерю аккаунта у всех, кто снял кит
    // раньше. Испорченное значение приравнивается к отсутствию — лучше остаться
    // без AIK (и вести себя как старая сборка), чем не восстановиться вовсе.
    String? accountSeed;
    final rawAccountSeed = json['account_identity_seed_b64'];
    if (rawAccountSeed is String && rawAccountSeed.trim().isNotEmpty) {
      final candidate = rawAccountSeed.trim();
      try {
        if (base64Decode(candidate).length == 32) {
          accountSeed = candidate;
        }
      } on FormatException {
        accountSeed = null;
      }
    }

    final plain = RecoveryKitPlainV1(
      profileId: reqStr('profile_id'),
      profileSecretB64: reqStr('profile_secret_b64'),
      deviceId: reqStr('device_id'),
      deviceKeysMaterialJson: reqStr('device_keys_material_json'),
      serverBinding: reqStr('server_binding'),
      accountIdentitySeedB64: accountSeed,
    );
    plain.validateRestorePayload();
    return plain;
  }

  void validateRestorePayload() {
    validateRestoreIdentityPayload(
      payloadName: 'Recovery kit',
      profileId: profileId,
      profileSecretB64: profileSecretB64,
      deviceId: deviceId,
      deviceKeysMaterialJson: deviceKeysMaterialJson,
      serverBinding: serverBinding,
    );
  }
}

class RecoveryKitV1 {
  static const prefix = 'secretly-recovery:v1:';
  static const _iter = 200000;

  static int _validatedIter(Object? rawIter) {
    final iter = (rawIter as num?)?.toInt() ?? _iter;
    if (iter < _iter) {
      throw StateError('Unsupported recovery kit PBKDF2 iteration count');
    }
    return iter;
  }

  static Future<String> encryptToPayload({
    required RecoveryKitPlainV1 plain,
    required String password,
  }) async {
    BackupPasswordPolicy.validateOrThrow(password);

    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final keyBytes = await _deriveKey(password: password, salt: salt);
    final key = SecretKey(keyBytes);

    final aes = AesGcm.with256bits();
    final plaintextBytes = utf8.encode(jsonEncode(plain.toJson()));
    final box = await aes.encrypt(plaintextBytes, secretKey: key, nonce: nonce);

    final wrapped = {
      'v': 1,
      'kdf': 'pbkdf2-sha256',
      'iter': _iter,
      'salt_b64': base64Encode(salt),
      'nonce_b64': base64Encode(nonce),
      'ciphertext_b64': base64Encode(box.cipherText),
      'mac_b64': base64Encode(box.mac.bytes),
    };

    final compact = base64UrlEncode(utf8.encode(jsonEncode(wrapped)));
    return '$prefix$compact';
  }

  static Future<RecoveryKitPlainV1> decryptFromPayload({
    required String payload,
    required String password,
  }) async {
    final raw = payload.trim();
    if (!raw.startsWith(prefix)) {
      throw StateError('Not a recovery kit');
    }
    final b64 = raw.substring(prefix.length);
    final wrapped =
        jsonDecode(utf8.decode(base64Url.decode(b64))) as Map<String, dynamic>;
    if ((wrapped['v'] as num?)?.toInt() != 1) {
      throw StateError('Unsupported recovery kit');
    }

    final iter = _validatedIter(wrapped['iter']);
    final salt = base64Decode(wrapped['salt_b64'] as String);
    final nonce = base64Decode(wrapped['nonce_b64'] as String);
    final ciphertext = base64Decode(wrapped['ciphertext_b64'] as String);
    final macBytes = base64Decode(wrapped['mac_b64'] as String);

    final aes = AesGcm.with256bits();
    final box = SecretBox(ciphertext, nonce: nonce, mac: Mac(macBytes));

    // AUD-060 fix: prefer raw password; fall back to trimmed form for kits
    // that were created before this fix (and therefore always trimmed).
    Future<RecoveryKitPlainV1> tryWith(String pw) async {
      final keyBytes = await _deriveKey(
        password: pw,
        salt: Uint8List.fromList(salt),
        iter: iter,
      );
      final key = SecretKey(keyBytes);
      final plainBytes = await aes.decrypt(box, secretKey: key);
      final plainJson =
          jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;
      return RecoveryKitPlainV1.fromJson(
        plainJson.map((k, v) => MapEntry(k, v as Object?)),
      );
    }

    try {
      return await tryWith(password);
    } catch (_) {
      final trimmed = password.trim();
      if (trimmed == password) {
        rethrow;
      }
      return tryWith(trimmed);
    }
  }

  static Future<Uint8List> _deriveKey({
    required String password,
    required Uint8List salt,
    int iter = _iter,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iter,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final bytes = await key.extractBytes();
    return Uint8List.fromList(bytes);
  }
}

Uint8List _randomBytes(int n) {
  final r = Random.secure();
  final out = Uint8List(n);
  for (var i = 0; i < out.length; i++) {
    out[i] = r.nextInt(256);
  }
  return out;
}
