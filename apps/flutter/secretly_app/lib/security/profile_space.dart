// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'serialized_secure_storage.dart';

/// Пространство профиля на устройстве (Э2 «код принуждения», 10.10.2026).
///
/// На одном телефоне живут два независимых профиля: настоящий (`main`) и
/// обманка (`alt`), которую открывает второй PIN. Профиль — это база, каталоги
/// медиа, настройки и секреты. В коде всё это читается из трёх мест, через
/// которые проходит каждое обращение:
///
/// 1. `SharedPreferences` — у ключей есть общий префикс (`setPrefix`), и его
///    можно сменить ДО первого `getInstance()` в изоляте;
/// 2. `path_provider` — платформенный объект подменяем обёрткой, которая
///    уводит Documents/Support/Temp в подкаталог `spaces/alt`;
/// 3. защищённое хранилище — все классы ходят через [SerializedSecureStorage],
///    у которого есть префикс ключа.
///
/// Поэтому пространство переключается здесь, а не в сотне мест, где читаются
/// ключи и строятся пути. Для `main` ничего не меняется: ни префикса, ни
/// подкаталога, ни миграции — существующие установки этого кода не замечают.
///
/// 🔴 Признак активного пространства хранится ВНЕ префиксованных настроек,
/// через `SharedPreferencesAsync` (сырой ключ без `flutter.`): его читают до
/// `setPrefix`, и в главном изоляте, и в фоновых.
enum ProfileSpace {
  main,
  alt;

  static ProfileSpace parse(String? raw) =>
      (raw ?? '').trim() == 'alt' ? ProfileSpace.alt : ProfileSpace.main;

  String get id => this == ProfileSpace.alt ? 'alt' : 'main';
}

class ProfileSpaceRuntime {
  ProfileSpaceRuntime._();

  /// Сырой ключ в `SharedPreferencesAsync`, без префикса.
  static const String storedKey = 'secretly_active_space_v1';
  static const String altSubdir = 'spaces/alt';
  static const String altPrefsPrefix = 'flutter.s.alt.';
  static const String altSecureStoragePrefix = 'space/alt/';

  static ProfileSpace _active = ProfileSpace.main;
  static bool _entered = false;
  static PathProviderPlatform? _wrappedInner;

  /// Пространство, в котором работает ТЕКУЩИЙ изолят.
  static ProfileSpace get active => _active;
  static bool get entered => _entered;

  /// Настоящий платформенный объект путей, без обёртки пространства.
  static PathProviderPlatform get innerPathProvider {
    final current = PathProviderPlatform.instance;
    if (current is _SpacePathProvider) return current.inner;
    return _wrappedInner ?? current;
  }

  static String prefsPrefix(ProfileSpace space) =>
      space == ProfileSpace.alt ? altPrefsPrefix : 'flutter.';

  static String secureStoragePrefix(ProfileSpace space) =>
      space == ProfileSpace.alt ? altSecureStoragePrefix : '';

  static SharedPreferencesAsync _rawStore() => SharedPreferencesAsync();

  static String _prefsWipeKey(ProfileSpace space) =>
      'secretly_space_prefs_wipe_v1_${space.id}';

  /// Какое пространство выбрано на устройстве (по умолчанию `main`).
  static Future<ProfileSpace> readStored() async {
    try {
      return ProfileSpace.parse(await _rawStore().getString(storedKey));
    } catch (_) {
      // Сбой чтения не должен превращаться в открытие чужого пространства.
      return ProfileSpace.main;
    }
  }

  static Future<void> store(ProfileSpace space) async {
    final raw = _rawStore();
    if (space == ProfileSpace.main) {
      await raw.remove(storedKey);
    } else {
      await raw.setString(storedKey, space.id);
    }
  }

  /// Настройки пространства нельзя стереть снаружи (их префикс недоступен из
  /// другого пространства), поэтому стирание откладывается до ближайшего входа.
  static Future<void> markPrefsWipePending(ProfileSpace space) =>
      _rawStore().setBool(_prefsWipeKey(space), true);

  static Future<bool> _takePrefsWipePending(ProfileSpace space) async {
    final raw = _rawStore();
    final key = _prefsWipeKey(space);
    try {
      if (await raw.getBool(key) != true) return false;
      await raw.remove(key);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Входит в пространство в текущем изоляте.
  ///
  /// [resetPrefs] — когда `SharedPreferences.getInstance()` в этом изоляте уже
  /// вызывался (шлюз PIN читал настройки замка; переключение из работающего
  /// приложения). Тогда статика пакета сбрасывается, и следующий `getInstance`
  /// перечитает хранилище с новым префиксом. Экземпляры, которые кто-то держит
  /// с прошлого раза, остаются в старом пространстве — их владельцы обязаны
  /// пересоздаться (контроллер пересоздаётся целиком).
  static Future<void> enter(
    ProfileSpace space, {
    bool resetPrefs = false,
  }) async {
    if (_entered && _active == space) return;
    if (resetPrefs) {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.resetStatic();
    }
    if (space == ProfileSpace.alt) {
      SharedPreferences.setPrefix(altPrefsPrefix);
    } else if (_entered) {
      SharedPreferences.setPrefix('flutter.');
    }
    _installPaths(space);
    SerializedSecureStorage.spacePrefix = secureStoragePrefix(space);
    _active = space;
    _entered = true;
    if (await _takePrefsWipePending(space)) {
      try {
        await (await SharedPreferences.getInstance()).clear();
      } catch (_) {}
    }
  }

  /// Для фоновых изолятов: прочитать выбранное пространство и войти в него.
  static Future<void> enterStoredForIsolate() async {
    await enter(await readStored());
  }

  static void _installPaths(ProfileSpace space) {
    final current = PathProviderPlatform.instance;
    if (space == ProfileSpace.alt) {
      if (current is _SpacePathProvider) return;
      _wrappedInner = current;
      PathProviderPlatform.instance = _SpacePathProvider(current, altSubdir);
      return;
    }
    if (current is _SpacePathProvider) {
      PathProviderPlatform.instance = _wrappedInner ?? current.inner;
      _wrappedInner = null;
    }
  }

  /// Корень файлов пространства относительно настоящего каталога [root].
  static String pathFor(ProfileSpace space, String root) =>
      space == ProfileSpace.alt ? p.join(root, altSubdir) : root;

  @visibleForTesting
  static void resetForTesting() {
    if (PathProviderPlatform.instance case final _SpacePathProvider w) {
      PathProviderPlatform.instance = w.inner;
    }
    _wrappedInner = null;
    _active = ProfileSpace.main;
    _entered = false;
    SerializedSecureStorage.spacePrefix = '';
  }
}

/// Уводит все каталоги приложения в подкаталог пространства.
///
/// Временный каталог и кэш тоже: иначе превью, обрезки видео и экспорт
/// обманки лежали бы рядом с настоящими.
class _SpacePathProvider extends PathProviderPlatform {
  _SpacePathProvider(this.inner, this.subdir);

  final PathProviderPlatform inner;
  final String subdir;

  Future<String?> _sub(Future<String?> base) async {
    final root = await base;
    if (root == null || root.isEmpty) return root;
    final path = p.join(root, subdir);
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
    return path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() =>
      _sub(inner.getApplicationDocumentsPath());

  @override
  Future<String?> getApplicationSupportPath() =>
      _sub(inner.getApplicationSupportPath());

  @override
  Future<String?> getTemporaryPath() => _sub(inner.getTemporaryPath());

  @override
  Future<String?> getApplicationCachePath() =>
      _sub(inner.getApplicationCachePath());

  @override
  Future<String?> getLibraryPath() => _sub(inner.getLibraryPath());

  @override
  Future<String?> getExternalStoragePath() => inner.getExternalStoragePath();

  @override
  Future<List<String>?> getExternalCachePaths() =>
      inner.getExternalCachePaths();

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) =>
      inner.getExternalStoragePaths(type: type);

  @override
  Future<String?> getDownloadsPath() => inner.getDownloadsPath();
}
