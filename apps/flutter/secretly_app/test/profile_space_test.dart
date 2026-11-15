// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:secretly_app/security/profile_space.dart';
import 'package:secretly_app/security/serialized_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Э2 «код принуждения» (10.10.2026): пространство профиля переключается в трёх
// узких местах — префикс настроек, обёртка путей, префикс защищённого
// хранилища. Каждый тест здесь закрепляет одно свойство: обманка не видит
// настоящий профиль, настоящий профиль не замечает обманку, а записи замка
// общие — по ним пространство и выбирается.

class _FakePaths extends PathProviderPlatform {
  _FakePaths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => p.join(root, 'docs');
  @override
  Future<String?> getApplicationSupportPath() async =>
      p.join(root, 'support');
  @override
  Future<String?> getTemporaryPath() async => p.join(root, 'tmp');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late _FakePaths fakePaths;

  setUp(() async {
    ProfileSpaceRuntime.resetForTesting();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    root = await Directory.systemTemp.createTemp('secretly_space_');
    fakePaths = _FakePaths(root.path);
    PathProviderPlatform.instance = fakePaths;
  });

  tearDown(() async {
    ProfileSpaceRuntime.resetForTesting();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.resetStatic();
    await root.delete(recursive: true);
  });

  group('защищённое хранилище', () {
    test('ключи обманки с префиксом, записи замка общие', () {
      SerializedSecureStorage.spacePrefix = 'space/alt/';
      expect(
        SerializedSecureStorage.scopedKey('secretly/db_passphrase_v1'),
        'space/alt/secretly/db_passphrase_v1',
      );
      expect(
        SerializedSecureStorage.scopedKey('secretly/app_lock_secret_v1/app'),
        'secretly/app_lock_secret_v1/app',
      );
      expect(
        SerializedSecureStorage.scopedKey('secretly/lock_attempts_v1'),
        'secretly/lock_attempts_v1',
      );
      SerializedSecureStorage.spacePrefix = '';
      expect(
        SerializedSecureStorage.scopedKey('secretly/db_passphrase_v1'),
        'secretly/db_passphrase_v1',
      );
    });

    test('🔴 секреты main не видны из alt, секреты alt — из main', () async {
      const storage = SerializedSecureStorage();
      await storage.write(key: 'secretly/db_passphrase_v1', value: 'main-db');
      await storage.write(
        key: 'secretly/app_lock_secret_v1/app',
        value: 'lock',
      );

      await ProfileSpaceRuntime.enter(ProfileSpace.alt);
      expect(await storage.read(key: 'secretly/db_passphrase_v1'), isNull);
      expect(
        await storage.read(key: 'secretly/app_lock_secret_v1/app'),
        'lock',
        reason: 'замок общий: по нему выбирается пространство',
      );
      await storage.write(key: 'secretly/db_passphrase_v1', value: 'alt-db');
      final seenFromAlt = await storage.readAll();
      expect(seenFromAlt['secretly/db_passphrase_v1'], 'alt-db');
      expect(seenFromAlt['secretly/app_lock_secret_v1/app'], 'lock');
      expect(seenFromAlt.length, 2, reason: 'секрет main наружу не выдан');

      await storage.deleteAll();
      expect(await storage.read(key: 'secretly/db_passphrase_v1'), isNull);

      ProfileSpaceRuntime.resetForTesting();
      expect(
        await storage.read(key: 'secretly/db_passphrase_v1'),
        'main-db',
        reason: 'deleteAll обманки не трогает настоящий профиль',
      );
      expect(
        await storage.read(key: 'secretly/app_lock_secret_v1/app'),
        'lock',
      );
    });
  });

  group('настройки', () {
    test('🔴 профиль обманки пишет под своим префиксом', () async {
      await ProfileSpaceRuntime.enter(ProfileSpace.alt);
      final alt = await SharedPreferences.getInstance();
      await alt.setString('profile_id', 'decoy');
      expect(alt.getString('profile_id'), 'decoy');

      await ProfileSpaceRuntime.enter(ProfileSpace.main, resetPrefs: true);
      final main = await SharedPreferences.getInstance();
      expect(main.getString('profile_id'), isNull);
      await main.setString('profile_id', 'real');

      await ProfileSpaceRuntime.enter(ProfileSpace.alt, resetPrefs: true);
      final altAgain = await SharedPreferences.getInstance();
      expect(altAgain.getString('profile_id'), 'decoy');
    });

    test('смена пространства после getInstance без сброса — ошибка', () async {
      await ProfileSpaceRuntime.enter(ProfileSpace.alt);
      await SharedPreferences.getInstance();
      expect(
        () => ProfileSpaceRuntime.enter(ProfileSpace.main),
        throwsStateError,
      );
    });

    test('признак активного пространства — сырой ключ, без префикса',
        () async {
      expect(await ProfileSpaceRuntime.readStored(), ProfileSpace.main);
      await ProfileSpaceRuntime.store(ProfileSpace.alt);
      expect(await ProfileSpaceRuntime.readStored(), ProfileSpace.alt);
      // Префиксованные настройки его не видят — он живёт в другом хранилище.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ProfileSpaceRuntime.storedKey), isNull);
      await ProfileSpaceRuntime.store(ProfileSpace.main);
      expect(await ProfileSpaceRuntime.readStored(), ProfileSpace.main);
    });
  });

  group('каталоги', () {
    test('🔴 alt живёт в spaces/alt, main — в настоящих каталогах', () async {
      final mainDocs = (await getApplicationDocumentsDirectory()).path;
      expect(mainDocs, p.join(root.path, 'docs'));

      await ProfileSpaceRuntime.enter(ProfileSpace.alt);
      final altDocs = (await getApplicationDocumentsDirectory()).path;
      expect(altDocs, p.join(root.path, 'docs', 'spaces', 'alt'));
      expect(await Directory(altDocs).exists(), isTrue);
      expect(
        (await getApplicationSupportDirectory()).path,
        p.join(root.path, 'support', 'spaces', 'alt'),
      );
      expect(
        (await getTemporaryDirectory()).path,
        p.join(root.path, 'tmp', 'spaces', 'alt'),
      );

      await ProfileSpaceRuntime.enter(ProfileSpace.main, resetPrefs: true);
      expect(identical(PathProviderPlatform.instance, fakePaths), isTrue);
      expect((await getApplicationDocumentsDirectory()).path, mainDocs);
    });

    test('повторный вход в alt не заворачивает обёртку дважды', () async {
      await ProfileSpaceRuntime.enter(ProfileSpace.alt);
      final once = PathProviderPlatform.instance;
      await ProfileSpaceRuntime.enter(ProfileSpace.alt);
      expect(identical(PathProviderPlatform.instance, once), isTrue);
      expect(
        (await getApplicationDocumentsDirectory()).path,
        p.join(root.path, 'docs', 'spaces', 'alt'),
      );
    });
  });
}
