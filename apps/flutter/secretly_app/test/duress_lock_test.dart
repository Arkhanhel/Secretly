// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/app_security_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Э2 «код принуждения» (10.10.2026). Менеджер замка — судья: он отличает
// настоящий пароль от кода принуждения, считает неверные попытки и сообщает,
// когда приложение обязано уйти в обманку или стереть данные. Что именно
// стирать и как переключать пространство — не его дело.

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

const _real = '2468';
const _duress = '1357';

Future<(AppSecurityManager, _MemoryLockStore, List<AppLockEmergency>)>
_managerWithLock({int Function()? nowMs}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final store = _MemoryLockStore();
  final manager = AppSecurityManager(
    secretStore: store,
    biometricAuthenticator: _NoBiometrics(),
    nowMs: nowMs,
    // Поведение не зависит от стоимости PBKDF2; боевые 200 000 проверяет
    // app_security_manager_test.
    pbkdf2Iterations: 1000,
  );
  await manager.init();
  await manager.setPasswordLock(
    scope: SecurityLockScope.app,
    password: _real,
    relockOnBackground: true,
    backgroundGraceSeconds: 0,
    allowBiometricUnlock: false,
  );
  // Пароль только что задан — область открыта; запираем, как при запуске.
  await manager.lockNow(SecurityLockScope.app);
  final events = <AppLockEmergency>[];
  manager.emergencies.listen(events.add);
  return (manager, store, events);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 код принуждения: замок не снят, событие с настройкой стирания',
      () async {
    final (manager, _, events) = await _managerWithLock();
    await manager.setDuressPassword(password: _duress, wipeMain: true);
    expect((await manager.duressStatus())?.wipeMain, isTrue);

    final result = await manager.unlockApp(password: _duress);
    expect(result.outcome, AppUnlockOutcome.duress);
    expect(result.wipeMain, isTrue);
    expect(manager.isLocked(SecurityLockScope.app), isTrue,
        reason: 'обманка открывается перезапуском, а не снятием замка');
    await Future<void>.delayed(Duration.zero);
    expect(events.single.kind, AppLockEmergencyKind.duress);
    expect(events.single.wipeMain, isTrue);
    expect(await manager.failedAttempts(), 0,
        reason: 'для наблюдателя это успешный вход');
  });

  test('настоящий пароль открывает, счётчик сбрасывается', () async {
    final (manager, _, events) = await _managerWithLock();
    await manager.setDuressPassword(password: _duress, wipeMain: false);
    expect((await manager.unlockApp(password: '0000')).outcome,
        AppUnlockOutcome.failed);
    expect(await manager.failedAttempts(), 1);
    final ok = await manager.unlockApp(password: _real);
    expect(ok.outcome, AppUnlockOutcome.unlocked);
    expect(manager.isLocked(SecurityLockScope.app), isFalse);
    expect(await manager.failedAttempts(), 0);
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
  });

  test('старый путь unlockWithPassword: код принуждения — «не подошёл» плюс событие',
      () async {
    final (manager, _, events) = await _managerWithLock();
    await manager.setDuressPassword(password: _duress, wipeMain: false);
    expect(
      await manager.unlockWithPassword(
        scope: SecurityLockScope.app,
        password: _duress,
      ),
      isFalse,
    );
    await Future<void>.delayed(Duration.zero);
    expect(events.single.kind, AppLockEmergencyKind.duress);
    expect(events.single.wipeMain, isFalse);
  });

  test('🔴 неверные попытки: задержки 3→5с, 5→15с и ожидание', () async {
    var now = 1000000;
    final (manager, _, _) = await _managerWithLock(nowMs: () => now);
    for (var i = 0; i < 3; i++) {
      final r = await manager.unlockApp(password: '0000');
      expect(r.outcome, AppUnlockOutcome.failed);
    }
    var blocked = await manager.unlockApp(password: _real);
    expect(blocked.outcome, AppUnlockOutcome.lockedOut);
    expect(blocked.lockoutRemaining.inSeconds, inInclusiveRange(4, 5));
    expect(manager.isLocked(SecurityLockScope.app), isTrue,
        reason: 'в задержке даже верный пароль не проверяется');

    now += 5001;
    expect((await manager.unlockApp(password: '0000')).failedAttempts, 4);
    expect((await manager.unlockApp(password: '0000')).outcome,
        AppUnlockOutcome.lockedOut);
    now += 5001;
    expect((await manager.unlockApp(password: '0000')).failedAttempts, 5);
    blocked = await manager.unlockApp(password: _real);
    expect(blocked.lockoutRemaining.inSeconds, inInclusiveRange(14, 15));

    now += 15001;
    expect((await manager.unlockApp(password: _real)).outcome,
        AppUnlockOutcome.unlocked);
    expect(await manager.lockoutRemaining(), Duration.zero);
  });

  test('🔴 стирание после N попыток — событие wipeAll ровно на N-й', () async {
    var now = 0;
    final (manager, _, events) = await _managerWithLock(nowMs: () => now);
    await manager.setWipeAfterFailedAttempts(5);
    expect(await manager.wipeAfterFailedAttempts(), 5);
    for (var i = 1; i <= 5; i++) {
      now += 400000; // задержки прошли
      await manager.unlockApp(password: '0000');
      await Future<void>.delayed(Duration.zero);
      expect(events.length, i == 5 ? 1 : 0, reason: 'попытка $i');
    }
    expect(events.single.kind, AppLockEmergencyKind.wipeAll);
    expect(() => manager.setWipeAfterFailedAttempts(2), throwsA(anything));
    await manager.setWipeAfterFailedAttempts(null);
    expect(await manager.wipeAfterFailedAttempts(), isNull);
  });

  test('код принуждения нельзя задать без парольного замка и равным паролю',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final bare = AppSecurityManager(
      secretStore: _MemoryLockStore(),
      biometricAuthenticator: _NoBiometrics(),
    );
    await bare.init();
    expect(
      () => bare.setDuressPassword(password: _duress, wipeMain: false),
      throwsA(isA<AppSecurityException>()),
    );
    final (manager, _, _) = await _managerWithLock();
    expect(
      () => manager.setDuressPassword(password: _real, wipeMain: false),
      throwsA(isA<AppSecurityException>()),
    );
    expect(await manager.duressStatus(), isNull);
  });

  test('отключение замка приложения убирает код принуждения и счётчик',
      () async {
    final (manager, store, _) = await _managerWithLock();
    await manager.setDuressPassword(password: _duress, wipeMain: true);
    await manager.unlockApp(password: '0000');
    expect(store.values.keys,
        containsAll(<String>['app', 'duress', 'attempts']));
    await manager.disableLock(SecurityLockScope.app);
    expect(store.values, isEmpty);
    expect(await manager.duressStatus(), isNull);
  });

  test('без кода принуждения неверный пароль — просто неверный', () async {
    final (manager, _, events) = await _managerWithLock();
    final r = await manager.unlockApp(password: _duress);
    expect(r.outcome, AppUnlockOutcome.failed);
    expect(r.failedAttempts, 1);
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
  });
}
