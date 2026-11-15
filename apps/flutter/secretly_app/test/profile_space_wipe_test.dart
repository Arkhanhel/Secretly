// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:secretly_app/security/profile_space.dart';
import 'package:secretly_app/security/profile_space_wipe.dart';
import 'package:secretly_app/security/serialized_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Э2: стирание пространства профиля. Стирается ровно одно пространство —
// база, файлы профиля, его секреты и настройки; соседнее пространство и
// записи замка остаются.

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

Future<File> _touch(String path) async {
  final f = File(path);
  await f.create(recursive: true);
  await f.writeAsString('x');
  return f;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String docs;
  late String support;
  late String tmp;

  setUp(() async {
    ProfileSpaceRuntime.resetForTesting();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    root = await Directory.systemTemp.createTemp('secretly_wipe_');
    docs = p.join(root.path, 'docs');
    support = p.join(root.path, 'support');
    tmp = p.join(root.path, 'tmp');
    PathProviderPlatform.instance = _FakePaths(root.path);

    // Настоящий профиль.
    await _touch(p.join(docs, 'secretly.db'));
    await _touch(p.join(docs, 'secretly.db-wal'));
    await _touch(p.join(docs, 'secretly.db.corrupt_backup_1'));
    await _touch(p.join(docs, 'attachments', 'blob1.jpg'));
    await _touch(p.join(docs, 'stickers', 'pack', 's.webp'));
    await _touch(p.join(docs, 'my_avatar.png'));
    await _touch(p.join(docs, 'secretly_identity_journal.jsonl'));
    await _touch(p.join(support, 'voice_transcripts', 'v1.txt'));
    await _touch(p.join(support, 'whisper', 'model.bin'));
    await _touch(p.join(tmp, 'preview.png'));
    // Обманка.
    await _touch(p.join(docs, 'spaces', 'alt', 'secretly.db'));
    await _touch(p.join(docs, 'spaces', 'alt', 'attachments', 'b.jpg'));
    await _touch(p.join(tmp, 'spaces', 'alt', 'preview.png'));

    const storage = SerializedSecureStorage();
    await storage.write(key: 'secretly/db_passphrase_v1', value: 'main');
    await storage.write(key: 'secretly/device_keys_v1/p/d', value: 'main');
    await storage.write(key: 'secretly/app_lock_secret_v1/app', value: 'pin');
    await storage.write(
      key: 'secretly/app_lock_secret_v1/duress',
      value: 'pin2',
    );
    SerializedSecureStorage.spacePrefix = 'space/alt/';
    await storage.write(key: 'secretly/db_passphrase_v1', value: 'alt');
    SerializedSecureStorage.spacePrefix = '';
  });

  tearDown(() async {
    ProfileSpaceRuntime.resetForTesting();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.resetStatic();
    await root.delete(recursive: true);
  });

  test('🔴 стирание main: база, файлы, секреты и настройки; alt и замок целы',
      () async {
    await ProfileSpaceRuntime.enter(ProfileSpace.main);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_id', 'real');

    await ProfileSpaceWipe.wipe(ProfileSpace.main);

    for (final gone in <String>[
      p.join(docs, 'secretly.db'),
      p.join(docs, 'secretly.db-wal'),
      p.join(docs, 'secretly.db.corrupt_backup_1'),
      p.join(docs, 'attachments', 'blob1.jpg'),
      p.join(docs, 'stickers', 'pack', 's.webp'),
      p.join(docs, 'my_avatar.png'),
      p.join(docs, 'secretly_identity_journal.jsonl'),
      p.join(support, 'voice_transcripts', 'v1.txt'),
      p.join(tmp, 'preview.png'),
    ]) {
      expect(await File(gone).exists(), isFalse, reason: gone);
    }
    for (final kept in <String>[
      p.join(docs, 'spaces', 'alt', 'secretly.db'),
      p.join(docs, 'spaces', 'alt', 'attachments', 'b.jpg'),
      p.join(tmp, 'spaces', 'alt', 'preview.png'),
      p.join(support, 'whisper', 'model.bin'),
    ]) {
      expect(await File(kept).exists(), isTrue, reason: kept);
    }
    expect(prefs.getString('profile_id'), isNull);

    const storage = SerializedSecureStorage();
    expect(await storage.read(key: 'secretly/db_passphrase_v1'), isNull);
    expect(await storage.read(key: 'secretly/device_keys_v1/p/d'), isNull);
    expect(await storage.read(key: 'secretly/app_lock_secret_v1/app'), 'pin');
    expect(
      await storage.read(key: 'secretly/app_lock_secret_v1/duress'),
      'pin2',
    );
    SerializedSecureStorage.spacePrefix = 'space/alt/';
    expect(await storage.read(key: 'secretly/db_passphrase_v1'), 'alt');
  });

  test('🔴 стирание alt из main: каталог, секреты, настройки — при входе',
      () async {
    // Настройки обманки, записанные раньше.
    await ProfileSpaceRuntime.enter(ProfileSpace.alt);
    await (await SharedPreferences.getInstance()).setString(
      'profile_id',
      'decoy',
    );
    await ProfileSpaceRuntime.enter(ProfileSpace.main, resetPrefs: true);

    await ProfileSpaceWipe.wipe(ProfileSpace.alt);

    expect(await Directory(p.join(docs, 'spaces', 'alt')).exists(), isFalse);
    expect(await Directory(p.join(tmp, 'spaces', 'alt')).exists(), isFalse);
    expect(await File(p.join(docs, 'secretly.db')).exists(), isTrue);
    expect(await File(p.join(docs, 'attachments', 'blob1.jpg')).exists(),
        isTrue);

    const storage = SerializedSecureStorage();
    expect(await storage.read(key: 'secretly/db_passphrase_v1'), 'main');
    SerializedSecureStorage.spacePrefix = 'space/alt/';
    expect(await storage.read(key: 'secretly/db_passphrase_v1'), isNull);
    SerializedSecureStorage.spacePrefix = '';

    // Настройки обманки стираются при ближайшем входе в неё.
    await ProfileSpaceRuntime.enter(ProfileSpace.alt, resetPrefs: true);
    expect(
      (await SharedPreferences.getInstance()).getString('profile_id'),
      isNull,
    );
  });
}
