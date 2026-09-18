// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secretly_app/security/app_security_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('password lock persists across manager restart', () async {
    final store = _MemoryLockStore();
    final auth = _FakeBiometricAuthenticator();
    final prefs = await SharedPreferences.getInstance();

    final manager = AppSecurityManager(
      secretStore: store,
      biometricAuthenticator: auth,
    );
    await manager.init(prefs: prefs);
    await manager.setPasswordLock(
      scope: SecurityLockScope.app,
      password: 'secret-1234',
      relockOnBackground: true,
      backgroundGraceSeconds: 0,
      allowBiometricUnlock: false,
    );

    final restarted = AppSecurityManager(
      secretStore: store,
      biometricAuthenticator: auth,
    );
    await restarted.init(prefs: prefs);

    expect(restarted.isEnabled(SecurityLockScope.app), isTrue);
    expect(restarted.isLocked(SecurityLockScope.app), isTrue);
    expect(
      await restarted.unlockWithPassword(
        scope: SecurityLockScope.app,
        password: 'secret-1234',
      ),
      isTrue,
    );
    expect(restarted.isLocked(SecurityLockScope.app), isFalse);

    await manager.dispose();
    await restarted.dispose();
  });

  test('pattern lock relocks when app is hidden', () async {
    final manager = AppSecurityManager(
      secretStore: _MemoryLockStore(),
      biometricAuthenticator: _FakeBiometricAuthenticator(),
    );
    final prefs = await SharedPreferences.getInstance();
    await manager.init(prefs: prefs);
    await manager.setPatternLock(
      scope: SecurityLockScope.personal,
      pattern: const <int>[0, 1, 2, 5],
      relockOnBackground: true,
      backgroundGraceSeconds: 0,
      allowBiometricUnlock: false,
    );

    expect(manager.isLocked(SecurityLockScope.personal), isFalse);

    manager.onAppLifecycleStateChanged(AppLifecycleState.paused);

    expect(manager.isLocked(SecurityLockScope.personal), isTrue);
    expect(
      await manager.unlockWithPattern(
        scope: SecurityLockScope.personal,
        pattern: const <int>[0, 1, 2, 5],
      ),
      isTrue,
    );
    expect(manager.isLocked(SecurityLockScope.personal), isFalse);

    await manager.dispose();
  });

  // Компьютер сообщает о спрятанном в трей окне состоянием `hidden`
  // (17.09.2026): жизненный цикл такого окна не меняется.
  test('password lock relocks when the desktop window is hidden', () async {
    final manager = AppSecurityManager(
      secretStore: _MemoryLockStore(),
      biometricAuthenticator: _FakeBiometricAuthenticator(),
    );
    final prefs = await SharedPreferences.getInstance();
    await manager.init(prefs: prefs);
    await manager.setPasswordLock(
      scope: SecurityLockScope.app,
      password: 'secret-1234',
      relockOnBackground: true,
      backgroundGraceSeconds: 0,
      allowBiometricUnlock: false,
    );
    expect(manager.isLocked(SecurityLockScope.app), isFalse);

    manager.onAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(manager.isLocked(SecurityLockScope.app), isTrue);

    // Окно снова на экране — замок не открывается сам.
    manager.onAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(manager.isLocked(SecurityLockScope.app), isTrue);

    await manager.dispose();
  });

  test('biometric lock unlocks through native authenticator', () async {
    final auth = _FakeBiometricAuthenticator(
      status: const SecurityBiometricStatus(
        isSupported: true,
        canCheckBiometrics: true,
        supportsDeviceCredentials: true,
        availableTypes: <String>{'fingerprint'},
      ),
      authenticateResult: true,
    );
    final manager = AppSecurityManager(
      secretStore: _MemoryLockStore(),
      biometricAuthenticator: auth,
    );
    final prefs = await SharedPreferences.getInstance();
    await manager.init(prefs: prefs);
    await manager.setBiometricLock(
      scope: SecurityLockScope.app,
      relockOnBackground: true,
      backgroundGraceSeconds: 0,
    );

    await manager.lockNow(SecurityLockScope.app);
    expect(manager.isLocked(SecurityLockScope.app), isTrue);

    final unlocked = await manager.authenticateWithBiometrics(
      scope: SecurityLockScope.app,
      reason: 'test',
    );

    expect(unlocked, isTrue);
    expect(auth.authenticateCalls, 1);
    expect(manager.isLocked(SecurityLockScope.app), isFalse);

    await manager.dispose();
  });

  test('password lock can unlock through biometric quick unlock', () async {
    final auth = _FakeBiometricAuthenticator(
      status: const SecurityBiometricStatus(
        isSupported: true,
        canCheckBiometrics: true,
        supportsDeviceCredentials: true,
        availableTypes: <String>{'fingerprint'},
      ),
      authenticateResult: true,
    );
    final manager = AppSecurityManager(
      secretStore: _MemoryLockStore(),
      biometricAuthenticator: auth,
    );
    final prefs = await SharedPreferences.getInstance();
    await manager.init(prefs: prefs);
    await manager.setPasswordLock(
      scope: SecurityLockScope.app,
      password: 'secret-1234',
      relockOnBackground: true,
      backgroundGraceSeconds: 0,
      allowBiometricUnlock: true,
    );

    await manager.lockNow(SecurityLockScope.app);
    expect(manager.isLocked(SecurityLockScope.app), isTrue);

    final unlocked = await manager.authenticateWithBiometrics(
      scope: SecurityLockScope.app,
      reason: 'test',
    );

    expect(unlocked, isTrue);
    expect(auth.authenticateCalls, 1);
    expect(manager.isLocked(SecurityLockScope.app), isFalse);

    await manager.dispose();
  });
}

class _MemoryLockStore implements AppLockSecretStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> deleteLockSecret(String scopeId) async {
    _values.remove(scopeId);
  }

  @override
  Future<String?> readLockSecret(String scopeId) async {
    return _values[scopeId];
  }

  @override
  Future<void> writeLockSecret(String scopeId, String value) async {
    _values[scopeId] = value;
  }
}

class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  _FakeBiometricAuthenticator({
    this.status = const SecurityBiometricStatus.unavailable(),
    this.authenticateResult = false,
  });

  final SecurityBiometricStatus status;
  final bool authenticateResult;
  int authenticateCalls = 0;

  @override
  Future<bool> authenticate({
    required String reason,
    required bool useDeviceCredentialsFallback,
  }) async {
    authenticateCalls += 1;
    return authenticateResult;
  }

  @override
  Future<SecurityBiometricStatus> getStatus() async {
    return status;
  }
}
