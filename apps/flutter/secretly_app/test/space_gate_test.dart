// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:secretly_app/security/app_security_manager.dart';
import 'package:secretly_app/security/profile_space.dart';
import 'package:secretly_app/security/space_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Э2: шлюз пространства профиля. Здесь — решения без экрана и порядок вызова
// в `main()`: шлюз обязан идти раньше всего, что трогает настройки.

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

class _MemoryLockStore implements AppLockSecretStore {
  final Map<String, String> values = <String, String>{};
  @override
  Future<void> deleteLockSecret(String scopeId) async => values.remove(scopeId);
  @override
  Future<String?> readLockSecret(String scopeId) async => values[scopeId];
  @override
  Future<void> writeLockSecret(String scopeId, String value) async =>
      values[scopeId] = value;
}

class _NoBiometrics implements BiometricAuthenticator {
  @override
  Future<bool> authenticate({
    required String reason,
    required bool useDeviceCredentialsFallback,
  }) async => false;
  @override
  Future<SecurityBiometricStatus> getStatus() async =>
      const SecurityBiometricStatus.unavailable();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    ProfileSpaceRuntime.resetForTesting();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    AppSecurityManager.startupUnlockedScopes.clear();
    root = await Directory.systemTemp.createTemp('secretly_gate_');
    PathProviderPlatform.instance = _FakePaths(root.path);
  });

  tearDown(() async {
    ProfileSpaceRuntime.resetForTesting();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.resetStatic();
    AppSecurityManager.startupUnlockedScopes.clear();
    await root.delete(recursive: true);
  });

  test('исход → пространство', () {
    expect(SpaceGate.spaceFor(SpaceGateOutcome.real), ProfileSpace.main);
    expect(SpaceGate.spaceFor(SpaceGateOutcome.duress), ProfileSpace.alt);
    expect(SpaceGate.spaceFor(SpaceGateOutcome.wipeAll), ProfileSpace.main);
  });

  test('🔴 без кода принуждения шлюз молча входит в main', () async {
    final space = await SpaceGate.resolveAtStartup();
    expect(space, ProfileSpace.main);
    expect(ProfileSpaceRuntime.active, ProfileSpace.main);
    expect(await ProfileSpaceRuntime.readStored(), ProfileSpace.main);
    expect(AppSecurityManager.startupUnlockedScopes, isEmpty);
  });

  test('🔴 событие «код принуждения» переводит в alt и стирает main по просьбе',
      () async {
    final mainDb = File(p.join(root.path, 'docs', 'secretly.db'));
    await mainDb.create(recursive: true);
    final manager = AppSecurityManager(
      secretStore: _MemoryLockStore(),
      biometricAuthenticator: _NoBiometrics(),
    );
    await manager.init();
    await ProfileSpaceRuntime.enter(ProfileSpace.main);

    final space = await SpaceGate.applyEmergency(
      const AppLockEmergency(kind: AppLockEmergencyKind.duress, wipeMain: true),
      security: manager,
    );
    expect(space, ProfileSpace.alt);
    expect(ProfileSpaceRuntime.active, ProfileSpace.alt);
    expect(await ProfileSpaceRuntime.readStored(), ProfileSpace.alt);
    expect(await mainDb.exists(), isFalse);
  });

  test('событие «код принуждения» без стирания оставляет main на месте',
      () async {
    final mainDb = File(p.join(root.path, 'docs', 'secretly.db'));
    await mainDb.create(recursive: true);
    final manager = AppSecurityManager(
      secretStore: _MemoryLockStore(),
      biometricAuthenticator: _NoBiometrics(),
    );
    await manager.init();
    await ProfileSpaceRuntime.enter(ProfileSpace.main);
    final space = await SpaceGate.applyEmergency(
      const AppLockEmergency(kind: AppLockEmergencyKind.duress),
      security: manager,
    );
    expect(space, ProfileSpace.alt);
    expect(await mainDb.exists(), isTrue);
  });

  test('🔴 «стереть всё» стирает оба пространства и снимает замок', () async {
    final mainDb = File(p.join(root.path, 'docs', 'secretly.db'));
    final altDb = File(p.join(root.path, 'docs', 'spaces', 'alt', 'secretly.db'));
    await mainDb.create(recursive: true);
    await altDb.create(recursive: true);
    final store = _MemoryLockStore();
    final manager = AppSecurityManager(
      secretStore: store,
      biometricAuthenticator: _NoBiometrics(),
    );
    await manager.init();
    await manager.setPasswordLock(
      scope: SecurityLockScope.app,
      password: '2468',
      relockOnBackground: true,
      backgroundGraceSeconds: 0,
      allowBiometricUnlock: false,
    );
    await manager.setDuressPassword(password: '1357', wipeMain: false);
    await ProfileSpaceRuntime.enter(ProfileSpace.main);

    final space = await SpaceGate.applyEmergency(
      const AppLockEmergency(kind: AppLockEmergencyKind.wipeAll),
      security: manager,
    );
    expect(space, ProfileSpace.main);
    expect(await mainDb.exists(), isFalse);
    expect(await altDb.exists(), isFalse);
    expect(store.values, isEmpty, reason: 'замок, код и счётчик сняты');
    expect(manager.isEnabled(SecurityLockScope.app), isFalse);
  });

  group('порядок в main()', () {
    final src = File('lib/main.dart').readAsStringSync();
    final mainAt = src.indexOf('Future<void> main() async {');
    final gateAt = src.indexOf('await SpaceGate.resolveAtStartup();', mainAt);

    test('🔴 шлюз вызывается в main()', () {
      expect(mainAt, greaterThan(0));
      expect(gateAt, greaterThan(mainAt));
    });

    test('🔴 шлюз идёт раньше пушей, фоновых задач и настроек', () {
      for (final later in <String>[
        'PushWakeService.initialize()',
        'BackgroundWorker.ensureRegistered()',
        'SharedPreferences.getInstance()',
        'runApp(',
      ]) {
        expect(src.indexOf(later, mainAt), greaterThan(gateAt), reason: later);
      }
    });

    test('замок, открытый шлюзом, не спрашивается второй раз', () {
      final manager = File('lib/security/app_security_manager.dart')
          .readAsStringSync();
      expect(manager.contains('for (final scope in startupUnlockedScopes)'),
          isTrue);
    });
  });
}
