// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
// AuthMessages is only reachable through local_auth's platform interface, and
// the override signature below needs its type. Referenced rather than added to
// pubspec on purpose: pubspec is shared with the released mobile app and this
// is a test-only need.
// ignore: depend_on_referenced_packages
import 'package:local_auth_platform_interface/types/auth_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secretly_app/ui/desktop/services/desktop_app_lock_service.dart';

/// Fake authenticator so the lock can be exercised without a real Touch ID
/// prompt. [succeeds] models the user's answer; [missingPlugin] models a
/// machine with no platform authenticator at all.
class _FakeAuth extends LocalAuthentication {
  _FakeAuth({this.succeeds = true, this.missingPlugin = false});

  bool succeeds;
  bool missingPlugin;
  int authenticateCalls = 0;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    authenticateCalls++;
    if (missingPlugin) {
      throw MissingPluginException('no local_auth on this platform');
    }
    return succeeds;
  }
}

/// F-17 — the desktop app lock must never become unopenable.
///
/// Unlocking is deliberately fail-closed (principle P-3: security features
/// never fall open), so there is no bypass to rescue a user who armed the lock
/// on a machine that cannot authenticate. The only safe place to stop that is
/// at arming time: prove the unlock path works BEFORE turning the lock on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<DesktopAppLockService> serviceWith(_FakeAuth auth) async {
    final svc = DesktopAppLockService(auth: auth);
    await svc.init(prefs: await SharedPreferences.getInstance());
    return svc;
  }

  test('arming requires a successful authentication', () async {
    final auth = _FakeAuth(succeeds: true);
    final svc = await serviceWith(auth);

    final applied = await svc.setEnabled(true, armReason: 'x');

    expect(applied, isTrue);
    expect(svc.enabled.value, isTrue);
    expect(svc.locked.value, isTrue, reason: 'arming locks immediately');
    expect(auth.authenticateCalls, 1, reason: 'the unlock path was proven');
  });

  test('a cancelled confirmation leaves the lock OFF', () async {
    final auth = _FakeAuth(succeeds: false);
    final svc = await serviceWith(auth);

    final applied = await svc.setEnabled(true, armReason: 'x');

    expect(applied, isFalse);
    expect(svc.enabled.value, isFalse);
    expect(svc.locked.value, isFalse);
  });

  test('a machine without an authenticator can never arm the lock', () async {
    final auth = _FakeAuth(missingPlugin: true);
    final svc = await serviceWith(auth);

    final applied = await svc.setEnabled(true, armReason: 'x');

    // This is the whole point: arming here would brick the app, because
    // requestUnlock could never succeed afterwards.
    expect(applied, isFalse);
    expect(svc.enabled.value, isFalse);
    expect(svc.locked.value, isFalse);
    expect(svc.unlockUnavailable.value, isTrue,
        reason: 'the UI must be able to explain the real cause');
  });

  test('disarming never requires authentication', () async {
    final auth = _FakeAuth(succeeds: true);
    final svc = await serviceWith(auth);
    await svc.setEnabled(true, armReason: 'x');
    final callsAfterArming = auth.authenticateCalls;

    // Now make authentication impossible and disarm anyway.
    auth.missingPlugin = true;
    final applied = await svc.setEnabled(false, armReason: 'x');

    expect(applied, isTrue);
    expect(svc.enabled.value, isFalse);
    expect(svc.locked.value, isFalse);
    expect(auth.authenticateCalls, callsAfterArming,
        reason: 'turning protection OFF must not be gated');
  });

  test('unlocking clears the lock only on success', () async {
    final auth = _FakeAuth(succeeds: true);
    final svc = await serviceWith(auth);
    await svc.setEnabled(true, armReason: 'x');
    expect(svc.locked.value, isTrue);

    auth.succeeds = false;
    expect(await svc.requestUnlock(reason: 'x'), isFalse);
    expect(svc.locked.value, isTrue, reason: 'fail-closed');

    auth.succeeds = true;
    expect(await svc.requestUnlock(reason: 'x'), isTrue);
    expect(svc.locked.value, isFalse);
  });

  test('a failed attempt is not mistaken for a missing authenticator',
      () async {
    final auth = _FakeAuth(succeeds: false);
    final svc = await serviceWith(auth);

    await svc.setEnabled(true, armReason: 'x');

    expect(svc.unlockUnavailable.value, isFalse,
        reason: 'user declined — the machine can still authenticate');
  });
}
