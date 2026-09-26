// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Concrete platform adapters that wire EntitlementRepository to the device's
// identity key and secure storage (TZ-MONETIZE-01 §C-1). Kept separate from the
// pure-Dart repository so unit tests can inject in-memory fakes.

import 'package:cryptography/cryptography.dart';
import '../security/secure_storage_options.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../security/auth_signer.dart';
import '../security/device_keys.dart';
import 'entitlement_repository.dart';
import '../security/serialized_secure_storage.dart';

/// EntitlementCache backed by flutter_secure_storage (same keychain options the
/// rest of the app uses on macOS).
class SecureStorageEntitlementCache implements EntitlementCache {
  SecureStorageEntitlementCache([FlutterSecureStorage? storage])
      : _storage = storage ??
            const SerializedSecureStorage(
              aOptions: kSecretlyAndroidStorageOptions,
              // `first_unlock_this_device`: кэш прав читается на заблокированном
              // устройстве после первой разблокировки (лечит -25308, см.
              // device_keys), но не переезжает на другое устройство через
              // резервную копию Apple (SEC-02, 25.08.2026).
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
              mOptions: MacOsOptions(
                useDataProtectionKeyChain: false,
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// EntitlementSigner backed by the device identity Ed25519 key pair. The key
/// pair is loaded lazily and cached for the signer's lifetime.
class DeviceKeyEntitlementSigner implements EntitlementSigner {
  DeviceKeyEntitlementSigner({
    required this.profileId,
    required this.deviceId,
  });

  final String profileId;

  @override
  final String deviceId;

  SimpleKeyPair? _cachedKeyPair;

  Future<SimpleKeyPair> _identityKeyPair() async {
    return _cachedKeyPair ??= await DeviceKeys.create().loadIdentityKeyPair(
      profileId: profileId,
      deviceId: deviceId,
    );
  }

  @override
  Future<String> signB64(List<int> message) async {
    final keyPair = await _identityKeyPair();
    return AuthSigner.signEd25519B64(
      identityKeyPair: keyPair,
      message: message,
    );
  }
}
