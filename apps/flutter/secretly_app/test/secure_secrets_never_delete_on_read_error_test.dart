// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 15.11.2026: при ошибке ЧТЕНИЯ хранилище стирало секрет профиля, пароль
// автокопии, секрет замка и сид поддержки — даже при временном сбое. Без
// секрета профиля профиль не запускается, а пустой секрет замка выключал
// замок. Здесь сторожа: ячейка не удаляется никогда, временная ошибка
// повторяется, замок остаётся запертым.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/app_security_manager.dart';
import 'package:secretly_app/security/secure_secrets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _channel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

final PlatformException _aeadBadTag = PlatformException(
  code: 'Exception encountered',
  message: 'read',
  details: 'javax.crypto.AEADBadTagException: error:1e000065:Cipher '
      'functions:OPENSSL_internal:BAD_DECRYPT',
);

final PlatformException _keystoreBusy = PlatformException(
  code: 'Exception encountered',
  message: 'read',
  details: 'android.security.KeyStoreException: Keystore operation failed',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> stored;
  late List<String> calls;

  /// [failRead] решает, чем ответить на чтение ключа: `null` — прочитать.
  void install(Object? Function(String key, int attempt)? failRead) {
    final attempts = <String, int>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      final args = Map<Object?, Object?>.from(
        call.arguments as Map<Object?, Object?>? ?? const {},
      );
      final key = args['key'] as String?;
      calls.add('${call.method}:$key');
      switch (call.method) {
        case 'read':
          final n = attempts[key!] = (attempts[key] ?? 0) + 1;
          final err = failRead?.call(key, n);
          if (err != null) throw err;
          return stored[key];
        case 'write':
          stored[key!] = (args['value'] as String?) ?? '';
          return null;
        case 'delete':
          stored.remove(key);
          return null;
        default:
          return null;
      }
    });
  }

  setUp(() {
    stored = <String, String>{};
    calls = <String>[];
    SecureSecrets.unreadableSlots.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  bool deleted() => calls.any((c) => c.startsWith('delete:'));

  test('секрет профиля: постоянная ошибка — null, ячейка НЕ удалена', () async {
    stored['secretly/profile_secret_v1_b64/P1'] = 'c2VjcmV0';
    install((key, _) => key.contains('profile_secret') ? _aeadBadTag : null);

    expect(await SecureSecrets.create().getProfileSecretB64('P1'), isNull);
    expect(deleted(), isFalse);
    expect(stored['secretly/profile_secret_v1_b64/P1'], 'c2VjcmV0');
    expect(SecureSecrets.unreadableSlots, contains('profile_secret'));
  });

  test('секрет профиля: временная ошибка повторяется и проходит', () async {
    stored['secretly/profile_secret_v1_b64/P1'] = 'c2VjcmV0';
    install((key, attempt) => attempt <= 2 ? _keystoreBusy : null);

    expect(await SecureSecrets.create().getProfileSecretB64('P1'), 'c2VjcmV0');
    expect(deleted(), isFalse);
    expect(SecureSecrets.unreadableSlots, isEmpty);
  });

  test('пароль автокопии: ошибка — null, ячейка НЕ удалена', () async {
    stored['secretly/safe_backup_auto_password_v1/P1'] = 'pw-123456789';
    install((_, __) => _aeadBadTag);

    expect(await SecureSecrets.create().getSafeBackupAutoPassword('P1'), isNull);
    expect(deleted(), isFalse);
    expect(stored.length, 1);
  });

  test('секрет замка: «не читается» — отдельная ошибка, не «нет секрета»',
      () async {
    stored['secretly/app_lock_secret_v1/app'] = '{"m":"password"}';
    install((_, __) => _aeadBadTag);

    await expectLater(
      SecureSecrets.create().getAppLockSecret('app'),
      throwsA(isA<SecureSecretUnreadable>()
          .having((e) => e.permanent, 'permanent', isTrue)
          .having((e) => e.slot, 'slot', 'app_lock')),
    );
    expect(deleted(), isFalse);
  });

  test('сид поддержки: временная ошибка — новый НЕ выпускается', () async {
    stored['secretly/support_reply_seed_v1_b64'] =
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
    install((_, __) => _keystoreBusy);

    await expectLater(
      SecureSecrets.create().getOrCreateSupportSeed(),
      throwsA(isA<SecureSecretUnreadable>()),
    );
    expect(deleted(), isFalse);
    expect(calls.any((c) => c.startsWith('write:')), isFalse);
  });

  test('сид поддержки: ключ недействителен — выпускается новый, как раньше',
      () async {
    stored['secretly/support_reply_seed_v1_b64'] = 'old';
    install((_, __) => _aeadBadTag);

    final seed = await SecureSecrets.create().getOrCreateSupportSeed();
    expect(seed.length, 32);
    expect(stored['secretly/support_reply_seed_v1_b64'], isNot('old'));
  });

  group('замок приложения', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('🔴 секрет не читается при запуске — замок остаётся ВКЛЮЧЁННЫМ и '
        'запертым, секрет не удалён', () async {
      final store = _FlakyLockStore();
      final prefs = await SharedPreferences.getInstance();
      final first = AppSecurityManager(
        secretStore: store,
        biometricAuthenticator: _NoBiometrics(),
        pbkdf2Iterations: 1000,
      );
      await first.init(prefs: prefs);
      await first.setPasswordLock(
        scope: SecurityLockScope.app,
        password: 'secret-1234',
        relockOnBackground: true,
        backgroundGraceSeconds: 0,
        allowBiometricUnlock: false,
      );

      store.unreadable = true;
      final restarted = AppSecurityManager(
        secretStore: store,
        biometricAuthenticator: _NoBiometrics(),
        pbkdf2Iterations: 1000,
      );
      await restarted.init(prefs: prefs);
      expect(restarted.isEnabled(SecurityLockScope.app), isTrue);
      expect(restarted.isLocked(SecurityLockScope.app), isTrue);
      expect(store.deletes, isEmpty);
      expect(
        await restarted.unlockWithPassword(
          scope: SecurityLockScope.app,
          password: 'secret-1234',
        ),
        isFalse,
        reason: 'не прочитали — не открываем',
      );

      // Хранилище ожило — тот же пароль открывает.
      store.unreadable = false;
      expect(
        await restarted.unlockWithPassword(
          scope: SecurityLockScope.app,
          password: 'secret-1234',
        ),
        isTrue,
      );
      await first.dispose();
      await restarted.dispose();
    });
  });
}

class _FlakyLockStore implements AppLockSecretStore {
  final Map<String, String> values = <String, String>{};
  final List<String> deletes = <String>[];
  bool unreadable = false;

  @override
  Future<String?> readLockSecret(String scopeId) async {
    if (unreadable && values.containsKey(scopeId)) {
      throw SecureSecretUnreadable('app_lock', permanent: false);
    }
    return values[scopeId];
  }

  @override
  Future<void> writeLockSecret(String scopeId, String value) async {
    values[scopeId] = value;
  }

  @override
  Future<void> deleteLockSecret(String scopeId) async {
    deletes.add(scopeId);
    values.remove(scopeId);
  }
}

class _NoBiometrics implements BiometricAuthenticator {
  @override
  Future<SecurityBiometricStatus> getStatus() async =>
      const SecurityBiometricStatus.unavailable();

  @override
  Future<bool> authenticate({
    required String reason,
    required bool useDeviceCredentialsFallback,
  }) async =>
      false;
}
