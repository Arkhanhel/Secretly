// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'secure_storage_options.dart';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceKeys {
  DeviceKeys._(this._secureStorage);

  static DeviceKeys create() {
    return DeviceKeys._(
      const FlutterSecureStorage(
        aOptions: kSecretlyAndroidStorageOptions,
        // `first_unlock_this_device` (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        // — ключи устройства должны читаться после ПЕРВОЙ разблокировки с
        // момента загрузки, в том числе на ЗАБЛОКИРОВАННОМ устройстве (пробуждение
        // пушем, запуск до разблокировки). Значение по умолчанию (`whenUnlocked`)
        // давало errSecInteractionNotAllowed (-25308) и фатальный экран.
        //
        // 🔴 Суффикс `_this_device` добавлен 25.08.2026 (SEC-02): без него Apple
        // переносит запись на НОВОЕ устройство вместе с резервной копией, а наша
        // модель безопасности привязана к устройству — номер безопасности
        // принадлежит устройству, и новое обязано выглядеть новым. Момент
        // доступности при этом тот же, отличается только запрет переноса.
        // Перенос уже записанных значений делает KeychainAccessibilityMigration.
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
        mOptions: MacOsOptions(
          useDataProtectionKeyChain: false,
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      ),
    );
  }

  static String validateMaterialJson(String rawJson) {
    final normalized = rawJson.trim();
    if (normalized.isEmpty) {
      throw StateError('device keys missing material json');
    }

    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        throw StateError('device keys material must be an object');
      }

      _DeviceKeyMaterialV1.fromJson(Map<String, dynamic>.from(decoded));
      return normalized;
    } on FormatException {
      throw StateError('device keys invalid material json');
    }
  }

  final FlutterSecureStorage _secureStorage;

  static String _storageKey({
    required String profileId,
    required String deviceId,
  }) {
    return 'secretly/device_keys_v1/$profileId/$deviceId';
  }

  Future<_DeviceKeyMaterialV1> _loadOrCreateMaterial({
    required String profileId,
    required String deviceId,
  }) async {
    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    final existingRaw = await _secureStorage.read(key: key);
    final material = existingRaw == null || existingRaw.isEmpty
        ? _DeviceKeyMaterialV1.createNew()
        : _DeviceKeyMaterialV1.fromJson(
            jsonDecode(existingRaw) as Map<String, dynamic>,
          );
    if (existingRaw == null || existingRaw.isEmpty) {
      await _secureStorage.write(
        key: key,
        value: jsonEncode(material.toJson()),
      );
    }
    return material;
  }

  Future<SimpleKeyPair> loadIdentityKeyPair({
    required String profileId,
    required String deviceId,
  }) async {
    final material = await _loadOrCreateMaterial(
      profileId: profileId,
      deviceId: deviceId,
    );
    return Ed25519().newKeyPairFromSeed(material.identitySeed);
  }

  /// iOS NSE (2026-07-17): base64 of the raw Ed25519 identity SEED, mirrored
  /// into the App Group so the Notification Service Extension can sign
  /// GET /v1/pending in the background. This is the device auth key, NOT a
  /// message-decryption key. Callers must only hand it to the App-Group
  /// bridge, never the network.
  Future<String> loadIdentitySeedB64({
    required String profileId,
    required String deviceId,
  }) async {
    final material = await _loadOrCreateMaterial(
      profileId: profileId,
      deviceId: deviceId,
    );
    return base64Encode(material.identitySeed);
  }

  Future<SimpleKeyPair> loadSignedPrekeyKeyPair({
    required String profileId,
    required String deviceId,
  }) async {
    final material = await _loadOrCreateMaterial(
      profileId: profileId,
      deviceId: deviceId,
    );
    return X25519().newKeyPairFromSeed(material.signedPrekeySeed);
  }

  Future<SimpleKeyPair?> loadOneTimePrekeyKeyPair({
    required String profileId,
    required String deviceId,
    required int prekeyId,
  }) async {
    final material = await _loadOrCreateMaterial(
      profileId: profileId,
      deviceId: deviceId,
    );
    final b64 = material.otkSeedById['$prekeyId'];
    if (b64 == null || b64.isEmpty) return null;
    final seed = Uint8List.fromList(base64Decode(b64));
    return X25519().newKeyPairFromSeed(seed);
  }

  Future<DeviceKeyBundleV1> createOrLoadAndAllocateOtk({
    required String profileId,
    required String deviceId,
    required int allocateOneTimePrekeys,
  }) async {
    if (allocateOneTimePrekeys < 0) {
      throw ArgumentError.value(
        allocateOneTimePrekeys,
        'allocateOneTimePrekeys',
        'must be >= 0',
      );
    }

    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    final existingRaw = await _secureStorage.read(key: key);
    final material = existingRaw == null || existingRaw.isEmpty
        ? _DeviceKeyMaterialV1.createNew()
        : _DeviceKeyMaterialV1.fromJson(
            jsonDecode(existingRaw) as Map<String, dynamic>,
          );

    final ed = Ed25519();
    final x = X25519();

    final identitySeed = material.identitySeed;
    final signedPrekeySeed = material.signedPrekeySeed;

    final identityKeyPair = await ed.newKeyPairFromSeed(identitySeed);
    final identityPub = await identityKeyPair.extractPublicKey();

    final signedPrekeyKeyPair = await x.newKeyPairFromSeed(signedPrekeySeed);
    final signedPrekeyPub = await signedPrekeyKeyPair.extractPublicKey();

    final signature = await ed.sign(
      signedPrekeyPub.bytes,
      keyPair: identityKeyPair,
    );

    final allocated = <Map<String, Object?>>[];
    var nextId = material.nextOtkId;

    for (var i = 0; i < allocateOneTimePrekeys; i++) {
      final id = nextId;
      nextId++;

      final seed = _randomBytes(32);
      final kp = await x.newKeyPairFromSeed(seed);
      final pub = await kp.extractPublicKey();

      material.otkSeedById['$id'] = base64Encode(seed);
      allocated.add({
        'prekey_id': id,
        'prekey_pub_b64': base64Encode(pub.bytes),
      });
    }

    material.nextOtkId = nextId;

    await _secureStorage.write(key: key, value: jsonEncode(material.toJson()));

    return DeviceKeyBundleV1(
      identityKeyPubB64: base64Encode(identityPub.bytes),
      signedPrekeyPubB64: base64Encode(signedPrekeyPub.bytes),
      signedPrekeySigB64: base64Encode(signature.bytes),
      oneTimePrekeys: allocated,
    );
  }

  Future<void> debugDumpPresence({
    required String profileId,
    required String deviceId,
  }) async {
    if (!kDebugMode) return;
    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    final raw = await _secureStorage.read(key: key);
    debugPrint('DeviceKeys: material=${raw == null ? 'missing' : 'set'}');
  }

  Future<void> deleteMaterial({
    required String profileId,
    required String deviceId,
  }) async {
    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    await _secureStorage.delete(key: key);
  }

  Future<String?> exportMaterialJson({
    required String profileId,
    required String deviceId,
  }) async {
    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    final raw = await _secureStorage.read(key: key);
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  Future<void> importMaterialJson({
    required String profileId,
    required String deviceId,
    required String rawJson,
  }) async {
    final key = _storageKey(profileId: profileId, deviceId: deviceId);
    await _secureStorage.write(key: key, value: validateMaterialJson(rawJson));
  }
}

class DeviceKeyBundleV1 {
  const DeviceKeyBundleV1({
    required this.identityKeyPubB64,
    required this.signedPrekeyPubB64,
    required this.signedPrekeySigB64,
    required this.oneTimePrekeys,
  });

  final String identityKeyPubB64;
  final String signedPrekeyPubB64;
  final String signedPrekeySigB64;
  final List<Map<String, Object?>> oneTimePrekeys;
}

class _DeviceKeyMaterialV1 {
  _DeviceKeyMaterialV1({
    required this.identitySeed,
    required this.signedPrekeySeed,
    required this.nextOtkId,
    required this.otkSeedById,
  });

  factory _DeviceKeyMaterialV1.createNew() {
    return _DeviceKeyMaterialV1(
      identitySeed: _randomBytes(32),
      signedPrekeySeed: _randomBytes(32),
      nextOtkId: 1,
      otkSeedById: <String, String>{},
    );
  }

  factory _DeviceKeyMaterialV1.fromJson(Map<String, dynamic> json) {
    Uint8List readSeed(String key) {
      final v = json[key] as String?;
      if (v == null || v.isEmpty) throw StateError('device keys missing $key');
      try {
        final bytes = base64Decode(v);
        if (bytes.length != 32) {
          throw StateError('device keys invalid $key');
        }
        return Uint8List.fromList(bytes);
      } on FormatException {
        throw StateError('device keys invalid $key');
      }
    }

    final next = (json['next_otk_id'] as num?)?.toInt() ?? 1;
    final otkRaw = json['otk_seed_by_id'];
    final otk = <String, String>{};
    if (otkRaw is Map) {
      otkRaw.forEach((key, value) {
        final prekeyId = key.toString().trim();
        if (prekeyId.isEmpty || value is! String || value.isEmpty) {
          throw StateError('device keys invalid otk_seed_by_id');
        }
        try {
          final bytes = base64Decode(value);
          if (bytes.length != 32) {
            throw StateError('device keys invalid otk_seed_by_id');
          }
        } on FormatException {
          throw StateError('device keys invalid otk_seed_by_id');
        }
        otk[prekeyId] = value;
      });
    } else if (otkRaw != null) {
      throw StateError('device keys invalid otk_seed_by_id');
    }

    return _DeviceKeyMaterialV1(
      identitySeed: readSeed('identity_seed_b64'),
      signedPrekeySeed: readSeed('signed_prekey_seed_b64'),
      nextOtkId: next,
      otkSeedById: otk,
    );
  }

  Uint8List identitySeed;
  Uint8List signedPrekeySeed;
  int nextOtkId;
  final Map<String, String> otkSeedById;

  Map<String, Object?> toJson() {
    return {
      'identity_seed_b64': base64Encode(identitySeed),
      'signed_prekey_seed_b64': base64Encode(signedPrekeySeed),
      'next_otk_id': nextOtkId,
      'otk_seed_by_id': otkSeedById,
    };
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
