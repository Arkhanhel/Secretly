// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/security/account_identity.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/security/recovery_kit.dart';
import 'package:secretly_app/security/safe_backup.dart';
import 'package:secretly_app/security/secure_secrets.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Э0 программы «Мессенджер без центра» (10.10.2026).
//
// Сид ключа личности аккаунта (AIK) читался при восстановлении из набора и из
// копии, но при их СОЗДАНИИ никогда не заполнялся: сборщики в контроллере
// передавали всё, кроме него. Итог — после восстановления рождался новый AIK,
// и у каждого собеседника «менялся номер безопасности», хотя человек тот же.
// Модельный тест (`recovery_kit_account_identity_test.dart`) этого не ловил:
// он проверял поле в обход контроллера. Здесь набор и копия собираются
// настоящим путём — через `AppController`.

/// Копия SafeBackup заглядывает в каталог документов даже без медиа.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => p.join(root, 'docs');
  @override
  Future<String?> getApplicationSupportPath() async =>
      p.join(root, 'support');
  @override
  Future<String?> getTemporaryPath() async => p.join(root, 'tmp');
}

const _pid = 'profile-aik-roundtrip';
const _did = 'device-aik-roundtrip';
const _password = 'Correct-Horse-Battery-9';

Future<String> _seedB64() async {
  final pair = await Ed25519().newKeyPair();
  return base64Encode(await pair.extractPrivateKeyBytes());
}

Future<(AppDb, AppController)> _controllerWithIdentity({
  required bool withAccountIdentity,
}) async {
  final db = await AppDb.openForTesting();
  final secrets = SecureSecrets.create();
  await secrets.setProfileSecretB64(
    profileId: _pid,
    secretB64: base64Encode(List<int>.generate(32, (i) => 100 + i)),
  );
  // Материал ключей устройства создаётся при первом чтении — так же, как на
  // настоящем устройстве.
  await DeviceKeys.create().loadIdentityKeyPair(profileId: _pid, deviceId: _did);
  final cryptoKey = await secrets.getOrCreateCryptoKey(allowMint: true);
  if (withAccountIdentity) {
    await AccountIdentity.create().importSeedB64(
      profileId: _pid,
      seedB64: await _seedB64(),
    );
  }
  final controller = AppController()
    ..seedRoomRuntimeForTesting(
      db: db,
      profileId: _pid,
      deviceId: _did,
      crypto: DartCryptoProvider(Uint8List.fromList(cryptoKey)),
    );
  return (db, controller);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late PathProviderPlatform originalPaths;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    root = await Directory.systemTemp.createTemp('secretly_aik_kit_');
    for (final sub in const ['docs', 'support', 'tmp']) {
      await Directory(p.join(root.path, sub)).create(recursive: true);
    }
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(root.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    await root.delete(recursive: true);
  });

  test('🔴 набор восстановления несёт сид AIK, и он совпадает с хранилищем',
      () async {
    final (db, controller) =
        await _controllerWithIdentity(withAccountIdentity: true);
    addTearDown(db.close);
    final expected =
        await AccountIdentity.create().loadSeedB64(profileId: _pid);
    expect(expected, isNotNull);

    final payload = await controller.createRecoveryKitPayload(
      password: _password,
    );
    final restored = await RecoveryKitV1.decryptFromPayload(
      payload: payload,
      password: _password,
    );
    expect(restored.accountIdentitySeedB64, expected);
    expect(restored.profileId, _pid);
  });

  test('🔴 копия SafeBackup несёт сид AIK', () async {
    final (db, controller) =
        await _controllerWithIdentity(withAccountIdentity: true);
    addTearDown(db.close);
    final expected =
        await AccountIdentity.create().loadSeedB64(profileId: _pid);

    final payload = await controller.createSafeBackupPayload(
      password: _password,
      includeBinaryFiles: false,
    );
    final restored = await SafeBackupV1.decryptFromPayload(
      payload: payload,
      password: _password,
    );
    expect(restored.accountIdentitySeedB64, expected);
  });

  test('без сида (до первой публикации ключей) набор всё равно создаётся',
      () async {
    final (db, controller) =
        await _controllerWithIdentity(withAccountIdentity: false);
    addTearDown(db.close);
    final payload = await controller.createRecoveryKitPayload(
      password: _password,
    );
    final restored = await RecoveryKitV1.decryptFromPayload(
      payload: payload,
      password: _password,
    );
    expect(restored.accountIdentitySeedB64, isNull);
    expect(restored.profileId, _pid);
  });
}
