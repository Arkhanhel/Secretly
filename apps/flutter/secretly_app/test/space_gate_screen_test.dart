// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/app_security_manager.dart';
import 'package:secretly_app/security/space_gate.dart';
import 'package:secretly_app/ui/space_gate_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Э2: экран шлюза. Настоящий код и код принуждения выглядят на экране
// одинаково — решение уходит наружу, а не на экран.
//
// PBKDF2 на 200 000 итераций в тесте виджетов ждёт настоящих таймеров и
// виснет; менеджер получает тестовое число итераций.

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

Future<AppSecurityManager> _manager() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final manager = AppSecurityManager(
    secretStore: _MemoryLockStore(),
    biometricAuthenticator: _NoBiometrics(),
    pbkdf2Iterations: 500,
  );
  await manager.init();
  await manager.setPasswordLock(
    scope: SecurityLockScope.app,
    password: '2468',
    relockOnBackground: true,
    backgroundGraceSeconds: 0,
    allowBiometricUnlock: false,
  );
  await manager.setDuressPassword(password: '1357', wipeMain: true);
  await manager.lockNow(SecurityLockScope.app);
  return manager;
}

Future<void> _enter(WidgetTester tester, String code) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('space_gate_code')),
    code,
  );
  await tester.tap(find.byKey(const ValueKey<String>('space_gate_submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('настоящий код → real', (tester) async {
    final manager = await _manager();
    final decisions = <SpaceGateDecision>[];
    await tester.pumpWidget(
      SpaceGateApp(manager: manager, onDecided: decisions.add),
    );
    await tester.pumpAndSettle();
    await _enter(tester, '2468');
    expect(decisions.single.outcome, SpaceGateOutcome.real);
    await manager.dispose();
  });

  testWidgets(
      '🔴 код принуждения → duress с настройкой стирания, без текста ошибки',
      (tester) async {
    final manager = await _manager();
    final decisions = <SpaceGateDecision>[];
    await tester.pumpWidget(
      SpaceGateApp(manager: manager, onDecided: decisions.add),
    );
    await tester.pumpAndSettle();
    await _enter(tester, '1357');
    expect(decisions.single.outcome, SpaceGateOutcome.duress);
    expect(decisions.single.wipeMain, isTrue);
    expect(find.textContaining('не подходит'), findsNothing);
    expect(find.textContaining('did not match'), findsNothing);
    await manager.dispose();
  });

  testWidgets('неверный код — ошибка, решения нет', (tester) async {
    final manager = await _manager();
    final decisions = <SpaceGateDecision>[];
    await tester.pumpWidget(
      SpaceGateApp(manager: manager, onDecided: decisions.add),
    );
    await tester.pumpAndSettle();
    await _enter(tester, '0000');
    expect(decisions, isEmpty);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? '').contains(RegExp('не подходит|did not match')),
      ),
      findsOneWidget,
    );
    await manager.dispose();
  });
}
