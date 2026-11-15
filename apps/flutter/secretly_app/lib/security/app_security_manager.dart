// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_secrets.dart';

enum SecurityLockScope { app, personal }

extension SecurityLockScopeX on SecurityLockScope {
  String get storageKey {
    switch (this) {
      case SecurityLockScope.app:
        return 'app';
      case SecurityLockScope.personal:
        return 'personal';
    }
  }
}

enum SecurityLockMethod { none, password, pattern, biometric }

extension SecurityLockMethodX on SecurityLockMethod {
  String get prefsValue {
    switch (this) {
      case SecurityLockMethod.none:
        return 'none';
      case SecurityLockMethod.password:
        return 'password';
      case SecurityLockMethod.pattern:
        return 'pattern';
      case SecurityLockMethod.biometric:
        return 'biometric';
    }
  }

  bool get usesCustomSecret {
    return this == SecurityLockMethod.password ||
        this == SecurityLockMethod.pattern;
  }

  static SecurityLockMethod fromPrefsValue(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'password':
        return SecurityLockMethod.password;
      case 'pattern':
        return SecurityLockMethod.pattern;
      case 'biometric':
        return SecurityLockMethod.biometric;
      default:
        return SecurityLockMethod.none;
    }
  }
}

/// Исход попытки открыть замок приложения (Э2 «код принуждения», 10.10.2026).
enum AppUnlockOutcome {
  /// Пароль не подошёл ни к одной записи.
  failed,

  /// Настоящий пароль — замок снят.
  unlocked,

  /// Введён код принуждения: замок НЕ снят, приложение обязано уйти в
  /// пространство обманки (а при соответствующей настройке — стереть основной
  /// профиль). Сам менеджер только сообщает об этом через [AppSecurityManager.emergencies].
  duress,

  /// Слишком много неверных попыток, проверка не выполнялась.
  lockedOut,
}

class AppUnlockResult {
  const AppUnlockResult._(
    this.outcome, {
    this.wipeMain = false,
    this.lockoutRemaining = Duration.zero,
    this.failedAttempts = 0,
  });

  final AppUnlockOutcome outcome;

  /// Для [AppUnlockOutcome.duress]: пользователь просил стирать основной
  /// профиль при вводе этого кода.
  final bool wipeMain;
  final Duration lockoutRemaining;
  final int failedAttempts;

  bool get unlocked => outcome == AppUnlockOutcome.unlocked;
}

/// Состояние кода принуждения, `null` — не настроен.
class DuressStatus {
  const DuressStatus({required this.wipeMain});
  final bool wipeMain;
}

enum AppLockEmergencyKind { duress, wipeAll }

/// Событие, на которое приложение обязано отреагировать уходом в обманку или
/// стиранием. Менеджер не знает ни про базу, ни про файлы — он только судья.
class AppLockEmergency {
  const AppLockEmergency({required this.kind, this.wipeMain = false});
  final AppLockEmergencyKind kind;
  final bool wipeMain;
}

class SecurityScopeConfig {
  const SecurityScopeConfig({
    required this.scope,
    required this.enabled,
    required this.method,
    required this.relockOnBackground,
    required this.backgroundGraceSeconds,
    required this.allowBiometricUnlock,
  });

  final SecurityLockScope scope;
  final bool enabled;
  final SecurityLockMethod method;
  final bool relockOnBackground;
  final int backgroundGraceSeconds;
  final bool allowBiometricUnlock;

  bool get isEnabled => enabled && method != SecurityLockMethod.none;
  bool get supportsBiometricQuickUnlock =>
      method == SecurityLockMethod.password ||
      method == SecurityLockMethod.pattern;
  bool get allowsBiometricUnlock =>
      method == SecurityLockMethod.biometric ||
      (supportsBiometricQuickUnlock && allowBiometricUnlock);

  SecurityScopeConfig normalized() {
    final normalizedMethod = enabled ? method : SecurityLockMethod.none;
    final normalizedEnabled =
        enabled && normalizedMethod != SecurityLockMethod.none;
    final normalizedGrace = backgroundGraceSeconds.clamp(0, 300).toInt();
    return SecurityScopeConfig(
      scope: scope,
      enabled: normalizedEnabled,
      method: normalizedEnabled ? normalizedMethod : SecurityLockMethod.none,
      relockOnBackground: relockOnBackground,
      backgroundGraceSeconds: normalizedGrace,
      allowBiometricUnlock:
          normalizedEnabled &&
              (normalizedMethod == SecurityLockMethod.password ||
                  normalizedMethod == SecurityLockMethod.pattern)
          ? allowBiometricUnlock
          : false,
    );
  }

  SecurityScopeConfig copyWith({
    bool? enabled,
    SecurityLockMethod? method,
    bool? relockOnBackground,
    int? backgroundGraceSeconds,
    bool? allowBiometricUnlock,
  }) {
    return SecurityScopeConfig(
      scope: scope,
      enabled: enabled ?? this.enabled,
      method: method ?? this.method,
      relockOnBackground: relockOnBackground ?? this.relockOnBackground,
      backgroundGraceSeconds:
          backgroundGraceSeconds ?? this.backgroundGraceSeconds,
      allowBiometricUnlock: allowBiometricUnlock ?? this.allowBiometricUnlock,
    ).normalized();
  }

  static SecurityScopeConfig defaultsFor(SecurityLockScope scope) {
    return SecurityScopeConfig(
      scope: scope,
      enabled: false,
      method: SecurityLockMethod.none,
      relockOnBackground: true,
      backgroundGraceSeconds: 0,
      allowBiometricUnlock: false,
    );
  }
}

class SecurityBiometricStatus {
  const SecurityBiometricStatus({
    required this.isSupported,
    required this.canCheckBiometrics,
    required this.supportsDeviceCredentials,
    required this.availableTypes,
  });

  const SecurityBiometricStatus.unavailable()
    : isSupported = false,
      canCheckBiometrics = false,
      supportsDeviceCredentials = false,
      availableTypes = const <String>{};

  final bool isSupported;
  final bool canCheckBiometrics;
  final bool supportsDeviceCredentials;
  final Set<String> availableTypes;

  bool get isAvailable => isSupported || canCheckBiometrics;
  bool get hasFace => availableTypes.contains('face');
  bool get hasFingerprint =>
      availableTypes.contains('fingerprint') ||
      availableTypes.contains('strong') ||
      availableTypes.contains('weak');

  String label({required bool useRussian}) {
    if (hasFace && hasFingerprint) {
      return useRussian ? 'Face ID / отпечаток' : 'Face ID / fingerprint';
    }
    if (hasFace) {
      return 'Face ID';
    }
    if (hasFingerprint) {
      return useRussian ? 'Отпечаток пальца' : 'Fingerprint';
    }
    if (supportsDeviceCredentials || isSupported) {
      return useRussian
          ? 'Системная аутентификация'
          : 'Native device authentication';
    }
    return useRussian ? 'Недоступно' : 'Unavailable';
  }
}

class AppSecurityException implements Exception {
  const AppSecurityException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AppLockSecretStore {
  Future<String?> readLockSecret(String scopeId);

  Future<void> writeLockSecret(String scopeId, String value);

  Future<void> deleteLockSecret(String scopeId);
}

class SecureSecretsLockStore implements AppLockSecretStore {
  SecureSecretsLockStore({SecureSecrets? secureSecrets})
    : _secureSecrets = secureSecrets ?? SecureSecrets.create();

  final SecureSecrets _secureSecrets;

  @override
  Future<String?> readLockSecret(String scopeId) {
    return _secureSecrets.getAppLockSecret(scopeId);
  }

  @override
  Future<void> writeLockSecret(String scopeId, String value) {
    return _secureSecrets.setAppLockSecret(scopeId: scopeId, secret: value);
  }

  @override
  Future<void> deleteLockSecret(String scopeId) {
    return _secureSecrets.deleteAppLockSecret(scopeId);
  }
}

abstract class BiometricAuthenticator {
  Future<SecurityBiometricStatus> getStatus();

  Future<bool> authenticate({
    required String reason,
    required bool useDeviceCredentialsFallback,
  });
}

class LocalBiometricAuthenticator implements BiometricAuthenticator {
  LocalBiometricAuthenticator({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<SecurityBiometricStatus> getStatus() async {
    try {
      final isSupported = await _localAuthentication.isDeviceSupported();
      final canCheckBiometrics = await _localAuthentication.canCheckBiometrics;
      final types = isSupported || canCheckBiometrics
          ? await _localAuthentication.getAvailableBiometrics()
          : const <BiometricType>[];
      final availableTypes = types
          .map((type) => type.toString().split('.').last.toLowerCase())
          .toSet();
      return SecurityBiometricStatus(
        isSupported: isSupported,
        canCheckBiometrics: canCheckBiometrics,
        supportsDeviceCredentials: isSupported,
        availableTypes: availableTypes,
      );
    } on MissingPluginException {
      return const SecurityBiometricStatus.unavailable();
    } on PlatformException {
      return const SecurityBiometricStatus.unavailable();
    }
  }

  @override
  Future<bool> authenticate({
    required String reason,
    required bool useDeviceCredentialsFallback,
  }) async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: !useDeviceCredentialsFallback,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

class AppSecurityManager {
  AppSecurityManager({
    AppLockSecretStore? secretStore,
    BiometricAuthenticator? biometricAuthenticator,
    int Function()? nowMs,
    @visibleForTesting int? pbkdf2Iterations,
  }) : _secretStore = secretStore ?? SecureSecretsLockStore(),
       _biometricAuthenticator =
           biometricAuthenticator ?? LocalBiometricAuthenticator(),
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _iterations = pbkdf2Iterations ?? _pbkdf2Iterations {
    _unlockedScopes.addAll(SecurityLockScope.values);
  }

  /// Стоимость вывода ключа. В бою — [_pbkdf2Iterations]; тесты виджетов
  /// задают меньше, иначе две проверки на нажатие длятся секунды.
  final int _iterations;

  /// Идентификаторы записей в хранилище замка, общих для всех пространств
  /// профиля (см. `SerializedSecureStorage.globalKeyPrefixes`).
  static const String duressStorageId = 'duress';
  static const String attemptsStorageId = 'attempts';

  /// Задержка после неверных попыток открыть замок приложения.
  static Duration lockoutFor(int failedAttempts) {
    if (failedAttempts >= 9) return const Duration(minutes: 5);
    if (failedAttempts >= 7) return const Duration(minutes: 1);
    if (failedAttempts >= 5) return const Duration(seconds: 15);
    if (failedAttempts >= 3) return const Duration(seconds: 5);
    return Duration.zero;
  }

  static const int minWipeAfterFailedAttempts = 5;
  static const int maxWipeAfterFailedAttempts = 30;

  final int Function() _nowMs;
  final StreamController<AppLockEmergency> _emergency =
      StreamController<AppLockEmergency>.broadcast();

  /// Код принуждения или стирание после N попыток: приложение подписывается
  /// и выполняет действие само.
  Stream<AppLockEmergency> get emergencies => _emergency.stream;

  // AUD-074 fix: Unified with SafeBackup / RecoveryKit (200 000) so the
  // app-lock parameter is no longer weaker than other password-derived keys.
  // Legacy records continue to verify because `_verifySecret` uses the
  // iteration count stored in the record. On next successful unlock the code
  // rotates stored hashes to the current value (see `_maybeUpgradeRecord`).
  static const int _pbkdf2Iterations = 200000;
  static const int _minimumPasswordLength = 4;
  static const int _minimumPatternLength = 4;
  static const String _prefsEnabledPrefix = 'security_lock_enabled_v1_';
  static const String _prefsMethodPrefix = 'security_lock_method_v1_';
  static const String _prefsRelockPrefix = 'security_lock_relock_v1_';
  static const String _prefsGracePrefix = 'security_lock_grace_v1_';
  static const String _prefsBiometricPrefix = 'security_lock_biometric_v1_';

  final AppLockSecretStore _secretStore;
  final BiometricAuthenticator _biometricAuthenticator;
  final StreamController<void> _changed = StreamController<void>.broadcast();
  final Map<SecurityLockScope, SecurityScopeConfig> _configs =
      <SecurityLockScope, SecurityScopeConfig>{};
  final Set<SecurityLockScope> _unlockedScopes = <SecurityLockScope>{};
  final Map<SecurityLockScope, DateTime?> _backgroundedAt =
      <SecurityLockScope, DateTime?>{};

  SharedPreferences? _prefs;
  bool _initialized = false;
  bool _biometricPromptInProgress = false;

  Stream<void> get changed => _changed.stream;
  bool get isInitialized => _initialized;

  /// Знак «секрет есть, но не читается» — отличается от `null` («нет»).
  static const String _unreadable = '\u0000unreadable';

  Future<String?> _readLockSecretOrUnreadable(String scopeId) async {
    try {
      return await _secretStore.readLockSecret(scopeId);
    } on SecureSecretUnreadable {
      return _unreadable;
    }
  }

  Future<void> init({SharedPreferences? prefs}) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    _prefs = resolvedPrefs;
    for (final scope in SecurityLockScope.values) {
      var config = _readScopeConfig(scope).normalized();
      if (config.isEnabled && config.method.usesCustomSecret) {
        // 🔴 Секрет есть, но сейчас не читается — замок остаётся ВКЛЮЧЁННЫМ
        // (15.11.2026). Раньше сбой хранилища приходил сюда как «секрета
        // нет», и замок сбрасывался в выключенный вместе с удалением секрета:
        // временная ошибка открывала приложение без пароля.
        final rawSecret = await _readLockSecretOrUnreadable(scope.storageKey);
        final record = rawSecret == _unreadable
            ? null
            : _LockSecretRecord.tryParse(rawSecret);
        if (rawSecret != _unreadable &&
            (record == null || record.method != config.method)) {
          config = SecurityScopeConfig.defaultsFor(scope);
          await _secretStore.deleteLockSecret(scope.storageKey);
          await _persistScopeConfig(config);
        }
      }
      _configs[scope] = config;
      if (config.isEnabled) {
        _unlockedScopes.remove(scope);
      } else {
        _unlockedScopes.add(scope);
      }
      _backgroundedAt[scope] = null;
    }
    // Шлюз пространства профиля уже проверил пароль до старта приложения:
    // второй раз спрашивать тот же код сразу после запуска нельзя.
    for (final scope in startupUnlockedScopes) {
      _unlockedScopes.add(scope);
      _backgroundedAt[scope] = null;
    }
    startupUnlockedScopes.clear();
    _initialized = true;
    _notifyChanged();
  }

  /// Области, открытые шлюзом до создания контроллера (Э2). Потребляются
  /// первым [init] в процессе.
  static final Set<SecurityLockScope> startupUnlockedScopes =
      <SecurityLockScope>{};

  Future<void> dispose() async {
    await _changed.close();
    await _emergency.close();
  }

  SecurityScopeConfig scopeConfig(SecurityLockScope scope) {
    return _configs[scope] ?? SecurityScopeConfig.defaultsFor(scope);
  }

  bool isEnabled(SecurityLockScope scope) {
    return scopeConfig(scope).isEnabled;
  }

  bool isLocked(SecurityLockScope scope) {
    final config = scopeConfig(scope);
    if (!config.isEnabled) return false;
    return !_unlockedScopes.contains(scope);
  }

  bool canOfferBiometricUnlock(SecurityLockScope scope) {
    return scopeConfig(scope).allowsBiometricUnlock;
  }

  Future<SecurityBiometricStatus> biometricStatus() {
    return _biometricAuthenticator.getStatus();
  }

  Future<void> disableLock(SecurityLockScope scope) async {
    final config = SecurityScopeConfig.defaultsFor(scope);
    await _secretStore.deleteLockSecret(scope.storageKey);
    if (scope == SecurityLockScope.app) {
      // Без настоящего пароля код принуждения и счётчик теряют смысл.
      await _secretStore.deleteLockSecret(duressStorageId);
      await _secretStore.deleteLockSecret(attemptsStorageId);
    }
    await _persistScopeConfig(config);
    _configs[scope] = config;
    _unlockedScopes.add(scope);
    _backgroundedAt[scope] = null;
    _notifyChanged();
  }

  Future<void> updateScopeConfig(SecurityScopeConfig config) async {
    final normalized = config.normalized();
    if (normalized.isEnabled && normalized.method.usesCustomSecret) {
      final rawSecret = await _readLockSecretOrUnreadable(
        normalized.scope.storageKey,
      );
      if (rawSecret == _unreadable) {
        throw const AppSecurityException(
          'The saved credential cannot be read right now. Try again.',
        );
      }
      final record = _LockSecretRecord.tryParse(rawSecret);
      if (record == null || record.method != normalized.method) {
        throw const AppSecurityException(
          'Missing saved credential for this protection method.',
        );
      }
    }
    await _persistScopeConfig(normalized);
    _configs[normalized.scope] = normalized;
    if (!normalized.isEnabled) {
      _unlockedScopes.add(normalized.scope);
    }
    _notifyChanged();
  }

  Future<void> setPasswordLock({
    required SecurityLockScope scope,
    required String password,
    required bool relockOnBackground,
    required int backgroundGraceSeconds,
    required bool allowBiometricUnlock,
  }) async {
    final normalizedPassword = password;
    if (normalizedPassword.length < _minimumPasswordLength) {
      throw const AppSecurityException('Password is too short.');
    }
    final record = await _createSecretRecord(
      method: SecurityLockMethod.password,
      secretBytes: Uint8List.fromList(utf8.encode(normalizedPassword)),
    );
    await _secretStore.writeLockSecret(
      scope.storageKey,
      jsonEncode(record.toJson()),
    );
    final config = SecurityScopeConfig(
      scope: scope,
      enabled: true,
      method: SecurityLockMethod.password,
      relockOnBackground: relockOnBackground,
      backgroundGraceSeconds: backgroundGraceSeconds,
      allowBiometricUnlock: allowBiometricUnlock,
    ).normalized();
    await _persistScopeConfig(config);
    _configs[scope] = config;
    _unlockedScopes.add(scope);
    _backgroundedAt[scope] = null;
    _notifyChanged();
  }

  Future<void> setPatternLock({
    required SecurityLockScope scope,
    required List<int> pattern,
    required bool relockOnBackground,
    required int backgroundGraceSeconds,
    required bool allowBiometricUnlock,
  }) async {
    _validatePattern(pattern);
    final record = await _createSecretRecord(
      method: SecurityLockMethod.pattern,
      secretBytes: Uint8List.fromList(utf8.encode(_serializePattern(pattern))),
    );
    await _secretStore.writeLockSecret(
      scope.storageKey,
      jsonEncode(record.toJson()),
    );
    final config = SecurityScopeConfig(
      scope: scope,
      enabled: true,
      method: SecurityLockMethod.pattern,
      relockOnBackground: relockOnBackground,
      backgroundGraceSeconds: backgroundGraceSeconds,
      allowBiometricUnlock: allowBiometricUnlock,
    ).normalized();
    await _persistScopeConfig(config);
    _configs[scope] = config;
    _unlockedScopes.add(scope);
    _backgroundedAt[scope] = null;
    _notifyChanged();
  }

  Future<void> setBiometricLock({
    required SecurityLockScope scope,
    required bool relockOnBackground,
    required int backgroundGraceSeconds,
  }) async {
    final status = await biometricStatus();
    if (!status.isAvailable) {
      throw const AppSecurityException(
        'Biometric authentication is unavailable on this device.',
      );
    }
    await _secretStore.deleteLockSecret(scope.storageKey);
    final config = SecurityScopeConfig(
      scope: scope,
      enabled: true,
      method: SecurityLockMethod.biometric,
      relockOnBackground: relockOnBackground,
      backgroundGraceSeconds: backgroundGraceSeconds,
      allowBiometricUnlock: false,
    ).normalized();
    await _persistScopeConfig(config);
    _configs[scope] = config;
    _unlockedScopes.add(scope);
    _backgroundedAt[scope] = null;
    _notifyChanged();
  }

  Future<void> lockNow(SecurityLockScope scope) async {
    if (!isEnabled(scope)) return;
    _unlockedScopes.remove(scope);
    _backgroundedAt[scope] = null;
    _notifyChanged();
  }

  Future<bool> unlockWithPassword({
    required SecurityLockScope scope,
    required String password,
  }) async {
    if (scope == SecurityLockScope.app) {
      // Замок приложения проверяется с учётом кода принуждения и счётчика;
      // старые вызывающие получают прежний ответ «подошёл или нет», а про
      // код принуждения узнают из [emergencies].
      final result = await unlockApp(password: password);
      return result.unlocked;
    }
    final config = scopeConfig(scope);
    if (!config.isEnabled || config.method != SecurityLockMethod.password) {
      return false;
    }
    // Не читается — «не подошло», замок не открывается.
    final raw = await _readLockSecretOrUnreadable(scope.storageKey);
    final record = raw == _unreadable ? null : _LockSecretRecord.tryParse(raw);
    if (record == null || record.method != SecurityLockMethod.password) {
      return false;
    }
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final verified = await _verifySecret(
      record: record,
      secretBytes: passwordBytes,
    );
    if (verified) {
      _unlockedScopes.add(scope);
      // AUD-074: transparently migrate legacy records to the current iteration
      // count. Best-effort: any failure leaves the legacy record untouched so
      // the user can still unlock next time.
      unawaited(
        _maybeUpgradeRecord(
          scope: scope,
          record: record,
          method: SecurityLockMethod.password,
          secretBytes: passwordBytes,
        ),
      );
      _notifyChanged();
    }
    return verified;
  }

  Future<bool> unlockWithPattern({
    required SecurityLockScope scope,
    required List<int> pattern,
  }) async {
    final config = scopeConfig(scope);
    if (!config.isEnabled || config.method != SecurityLockMethod.pattern) {
      return false;
    }
    // Не читается — «не подошло», замок не открывается.
    final raw = await _readLockSecretOrUnreadable(scope.storageKey);
    final record = raw == _unreadable ? null : _LockSecretRecord.tryParse(raw);
    if (record == null || record.method != SecurityLockMethod.pattern) {
      return false;
    }
    final patternBytes = Uint8List.fromList(
      utf8.encode(_serializePattern(pattern)),
    );
    if (scope == SecurityLockScope.app &&
        (await lockoutRemaining()) > Duration.zero) {
      return false;
    }
    final verified = await _verifySecret(
      record: record,
      secretBytes: patternBytes,
    );
    if (scope == SecurityLockScope.app) {
      if (verified) {
        await _noteUnlockSuccess();
      } else {
        await _noteUnlockFailure();
      }
    }
    if (verified) {
      _unlockedScopes.add(scope);
      unawaited(
        _maybeUpgradeRecord(
          scope: scope,
          record: record,
          method: SecurityLockMethod.pattern,
          secretBytes: patternBytes,
        ),
      );
      _notifyChanged();
    }
    return verified;
  }

  Future<void> _maybeUpgradeRecord({
    required SecurityLockScope scope,
    required _LockSecretRecord record,
    required SecurityLockMethod method,
    required Uint8List secretBytes,
  }) async {
    if (record.iterations >= _iterations) return;
    try {
      final upgraded = await _createSecretRecord(
        method: method,
        secretBytes: secretBytes,
      );
      await _secretStore.writeLockSecret(
        scope.storageKey,
        jsonEncode(upgraded.toJson()),
      );
    } catch (_) {
      // Ignore; user remains on legacy iterations and can still authenticate.
    }
  }

  Future<bool> authenticateWithBiometrics({
    required SecurityLockScope scope,
    required String reason,
  }) async {
    final config = scopeConfig(scope);
    if (!config.isEnabled || !config.allowsBiometricUnlock) {
      return false;
    }
    final status = await biometricStatus();
    if (!status.isAvailable) {
      return false;
    }
    _biometricPromptInProgress = true;
    try {
      final authenticated = await _biometricAuthenticator.authenticate(
        reason: reason,
        useDeviceCredentialsFallback: true,
      );
      if (authenticated) {
        _unlockedScopes.add(scope);
        _notifyChanged();
      }
      return authenticated;
    } finally {
      _biometricPromptInProgress = false;
    }
  }

  Future<bool> authenticateDevice({required String reason}) async {
    final status = await biometricStatus();
    if (!status.isAvailable) {
      return false;
    }
    _biometricPromptInProgress = true;
    try {
      return await _biometricAuthenticator.authenticate(
        reason: reason,
        useDeviceCredentialsFallback: true,
      );
    } finally {
      _biometricPromptInProgress = false;
    }
  }

  void onAppLifecycleStateChanged(AppLifecycleState state) {
    if (!_initialized || _biometricPromptInProgress) {
      return;
    }

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _handleBackgroundTransition();
        return;
      case AppLifecycleState.resumed:
        _handleResumeTransition();
        return;
      case AppLifecycleState.inactive:
        return;
    }
  }

  String serializePattern(List<int> pattern) => _serializePattern(pattern);

  SecurityScopeConfig _readScopeConfig(SecurityLockScope scope) {
    final prefs = _prefs;
    if (prefs == null) {
      return SecurityScopeConfig.defaultsFor(scope);
    }
    final enabled =
        prefs.getBool('$_prefsEnabledPrefix${scope.storageKey}') ?? false;
    final method = SecurityLockMethodX.fromPrefsValue(
      prefs.getString('$_prefsMethodPrefix${scope.storageKey}'),
    );
    final relock =
        prefs.getBool('$_prefsRelockPrefix${scope.storageKey}') ?? true;
    final grace = prefs.getInt('$_prefsGracePrefix${scope.storageKey}') ?? 0;
    final allowBiometric =
        prefs.getBool('$_prefsBiometricPrefix${scope.storageKey}') ?? false;
    return SecurityScopeConfig(
      scope: scope,
      enabled: enabled,
      method: method,
      relockOnBackground: relock,
      backgroundGraceSeconds: grace,
      allowBiometricUnlock: allowBiometric,
    );
  }

  Future<void> _persistScopeConfig(SecurityScopeConfig config) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(
      '$_prefsEnabledPrefix${config.scope.storageKey}',
      config.isEnabled,
    );
    await prefs.setString(
      '$_prefsMethodPrefix${config.scope.storageKey}',
      config.method.prefsValue,
    );
    await prefs.setBool(
      '$_prefsRelockPrefix${config.scope.storageKey}',
      config.relockOnBackground,
    );
    await prefs.setInt(
      '$_prefsGracePrefix${config.scope.storageKey}',
      config.backgroundGraceSeconds,
    );
    await prefs.setBool(
      '$_prefsBiometricPrefix${config.scope.storageKey}',
      config.allowBiometricUnlock,
    );
  }

  // ---------------------------------------------------------------------------
  // Код принуждения и счётчик попыток (Э2).
  // ---------------------------------------------------------------------------

  /// Проверяет пароль замка приложения против настоящей записи И записи кода
  /// принуждения.
  ///
  /// 🔴 Обе проверки выполняются ВСЕГДА, даже если код принуждения не
  /// настроен (тогда вторая идёт против фиктивной записи той же стоимости):
  /// по времени ответа нельзя понять, есть ли у человека второй код.
  Future<AppUnlockResult> unlockApp({required String password}) async {
    const scope = SecurityLockScope.app;
    final config = scopeConfig(scope);
    if (!config.isEnabled || config.method != SecurityLockMethod.password) {
      return const AppUnlockResult._(AppUnlockOutcome.failed);
    }
    final lockout = await lockoutRemaining();
    if (lockout > Duration.zero) {
      final attempts = await _readAttempts();
      return AppUnlockResult._(
        AppUnlockOutcome.lockedOut,
        lockoutRemaining: lockout,
        failedAttempts: attempts.count,
      );
    }
    // Секрет не читается — замок не открывается и попытка не считается:
    // человек ни в чём не ошибся.
    final rawReal = await _readLockSecretOrUnreadable(scope.storageKey);
    final record = rawReal == _unreadable
        ? null
        : _LockSecretRecord.tryParse(rawReal);
    if (record == null || record.method != SecurityLockMethod.password) {
      return const AppUnlockResult._(AppUnlockOutcome.failed);
    }
    final rawDuress = await _readLockSecretOrUnreadable(duressStorageId);
    final duressRecord = rawDuress == _unreadable
        ? null
        : _LockSecretRecord.tryParse(rawDuress);
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final realOk = await _verifySecret(
      record: record,
      secretBytes: passwordBytes,
    );
    final duressOk = await _verifySecret(
      record: duressRecord ?? _dummyRecordLike(record),
      secretBytes: passwordBytes,
    );
    if (realOk) {
      await _noteUnlockSuccess();
      _unlockedScopes.add(scope);
      unawaited(
        _maybeUpgradeRecord(
          scope: scope,
          record: record,
          method: SecurityLockMethod.password,
          secretBytes: passwordBytes,
        ),
      );
      _notifyChanged();
      return const AppUnlockResult._(AppUnlockOutcome.unlocked);
    }
    if (duressRecord != null && duressOk) {
      // Счётчик не трогаем: для наблюдателя это «успешный вход».
      final wipeMain = duressRecord.wipeMain;
      _emit(AppLockEmergency(
        kind: AppLockEmergencyKind.duress,
        wipeMain: wipeMain,
      ));
      return AppUnlockResult._(AppUnlockOutcome.duress, wipeMain: wipeMain);
    }
    final attempts = await _noteUnlockFailure();
    return AppUnlockResult._(
      AppUnlockOutcome.failed,
      failedAttempts: attempts.count,
      lockoutRemaining: _lockoutRemainingFor(attempts),
    );
  }

  Future<DuressStatus?> duressStatus() async {
    final raw = await _readLockSecretOrUnreadable(duressStorageId);
    final record = raw == _unreadable ? null : _LockSecretRecord.tryParse(raw);
    if (record == null) return null;
    return DuressStatus(wipeMain: record.wipeMain);
  }

  /// Задаёт код принуждения. Требует включённого парольного замка приложения;
  /// код не может совпадать с настоящим паролем.
  Future<void> setDuressPassword({
    required String password,
    required bool wipeMain,
  }) async {
    final config = scopeConfig(SecurityLockScope.app);
    if (!config.isEnabled || config.method != SecurityLockMethod.password) {
      throw const AppSecurityException(
        'A password lock for the app is required first.',
      );
    }
    if (password.length < _minimumPasswordLength) {
      throw const AppSecurityException('Password is too short.');
    }
    final rawReal = await _readLockSecretOrUnreadable(
      SecurityLockScope.app.storageKey,
    );
    if (rawReal == _unreadable) {
      throw const AppSecurityException(
        'The saved credential cannot be read right now. Try again.',
      );
    }
    final real = _LockSecretRecord.tryParse(rawReal);
    final bytes = Uint8List.fromList(utf8.encode(password));
    if (real != null && await _verifySecret(record: real, secretBytes: bytes)) {
      throw const AppSecurityException(
        'The duress code must differ from the real password.',
      );
    }
    final record = await _createSecretRecord(
      method: SecurityLockMethod.password,
      secretBytes: bytes,
    );
    await _secretStore.writeLockSecret(
      duressStorageId,
      jsonEncode(record.copyWith(wipeMain: wipeMain).toJson()),
    );
    _notifyChanged();
  }

  Future<void> clearDuressPassword() async {
    await _secretStore.deleteLockSecret(duressStorageId);
    _notifyChanged();
  }

  /// Меняет только настройку стирания у уже заданного кода принуждения.
  Future<void> setDuressWipeMain(bool wipeMain) async {
    final raw = await _readLockSecretOrUnreadable(duressStorageId);
    if (raw == _unreadable) {
      throw const AppSecurityException(
        'The saved credential cannot be read right now. Try again.',
      );
    }
    final record = _LockSecretRecord.tryParse(raw);
    if (record == null) {
      throw const AppSecurityException('The duress code is not set.');
    }
    await _secretStore.writeLockSecret(
      duressStorageId,
      jsonEncode(record.copyWith(wipeMain: wipeMain).toJson()),
    );
    _notifyChanged();
  }

  /// Сколько ещё ждать до следующей попытки открыть замок приложения.
  Future<Duration> lockoutRemaining() async =>
      _lockoutRemainingFor(await _readAttempts());

  Future<int> failedAttempts() async => (await _readAttempts()).count;

  /// `null` — не стирать. Иначе после N неверных попыток подряд менеджер
  /// сообщает [AppLockEmergencyKind.wipeAll].
  Future<int?> wipeAfterFailedAttempts() async =>
      (await _readAttempts()).wipeAfter;

  Future<void> setWipeAfterFailedAttempts(int? count) async {
    if (count != null &&
        (count < minWipeAfterFailedAttempts ||
            count > maxWipeAfterFailedAttempts)) {
      throw const AppSecurityException('Unsupported attempt limit.');
    }
    final attempts = await _readAttempts();
    await _writeAttempts(attempts.copyWith(wipeAfter: count, clearWipe: count == null));
    _notifyChanged();
  }

  Duration _lockoutRemainingFor(_AttemptsRecord attempts) {
    final required = lockoutFor(attempts.count);
    if (required == Duration.zero) return Duration.zero;
    final elapsed = _nowMs() - attempts.lastAtMs;
    final remaining = required.inMilliseconds - elapsed;
    return remaining > 0 ? Duration(milliseconds: remaining) : Duration.zero;
  }

  Future<void> _noteUnlockSuccess() async {
    final attempts = await _readAttempts();
    if (attempts.count == 0) return;
    await _writeAttempts(attempts.copyWith(count: 0, lastAtMs: 0));
  }

  Future<_AttemptsRecord> _noteUnlockFailure() async {
    final previous = await _readAttempts();
    final next = previous.copyWith(
      count: previous.count + 1,
      lastAtMs: _nowMs(),
    );
    await _writeAttempts(next);
    final limit = next.wipeAfter;
    if (limit != null && next.count >= limit) {
      _emit(const AppLockEmergency(kind: AppLockEmergencyKind.wipeAll));
    }
    return next;
  }

  Future<_AttemptsRecord> _readAttempts() async {
    try {
      return _AttemptsRecord.parse(
        await _secretStore.readLockSecret(attemptsStorageId),
      );
    } catch (_) {
      return const _AttemptsRecord();
    }
  }

  Future<void> _writeAttempts(_AttemptsRecord record) async {
    try {
      await _secretStore.writeLockSecret(
        attemptsStorageId,
        jsonEncode(record.toJson()),
      );
    } catch (_) {
      // Сбой записи счётчика не должен запирать человека снаружи.
    }
  }

  void _emit(AppLockEmergency event) {
    if (_emergency.isClosed) return;
    _emergency.add(event);
  }

  /// Фиктивная запись той же стоимости, что настоящая: хэш из нулей никогда
  /// не совпадёт, а PBKDF2 отработает столько же.
  _LockSecretRecord _dummyRecordLike(_LockSecretRecord record) =>
      _LockSecretRecord(
        method: SecurityLockMethod.password,
        saltB64: base64Encode(Uint8List(16)),
        hashB64: base64Encode(Uint8List(32)),
        iterations: record.iterations,
      );

  Future<_LockSecretRecord> _createSecretRecord({
    required SecurityLockMethod method,
    required Uint8List secretBytes,
  }) async {
    final salt = _randomBytes(16);
    final derived = await _deriveHash(secretBytes: secretBytes, salt: salt);
    return _LockSecretRecord(
      method: method,
      saltB64: base64Encode(salt),
      hashB64: base64Encode(derived),
      iterations: _iterations,
    );
  }

  Future<bool> _verifySecret({
    required _LockSecretRecord record,
    required Uint8List secretBytes,
  }) async {
    try {
      final salt = base64Decode(record.saltB64);
      final expected = base64Decode(record.hashB64);
      final derived = await _deriveHash(
        secretBytes: secretBytes,
        salt: salt,
        iterations: record.iterations,
      );
      return _constantTimeEquals(expected, derived);
    } on FormatException {
      return false;
    }
  }

  Future<List<int>> _deriveHash({
    required Uint8List secretBytes,
    required List<int> salt,
    int? iterations,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations ?? _iterations,
      bits: 256,
    );
    final secretKey = SecretKey(secretBytes);
    final derivedKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );
    return derivedKey.extractBytes();
  }

  void _handleBackgroundTransition() {
    var changed = false;
    final now = DateTime.now();
    for (final scope in SecurityLockScope.values) {
      final config = scopeConfig(scope);
      if (!config.isEnabled || !config.relockOnBackground) {
        _backgroundedAt[scope] = null;
        continue;
      }
      if (config.backgroundGraceSeconds <= 0) {
        if (_unlockedScopes.remove(scope)) {
          changed = true;
        }
        _backgroundedAt[scope] = null;
      } else {
        _backgroundedAt[scope] = now;
      }
    }
    if (changed) {
      _notifyChanged();
    }
  }

  void _handleResumeTransition() {
    var changed = false;
    final now = DateTime.now();
    for (final scope in SecurityLockScope.values) {
      final config = scopeConfig(scope);
      final backgroundedAt = _backgroundedAt[scope];
      _backgroundedAt[scope] = null;
      if (!config.isEnabled || !config.relockOnBackground) {
        continue;
      }
      if (backgroundedAt == null) {
        continue;
      }
      final elapsed = now.difference(backgroundedAt).inSeconds;
      if (elapsed >= config.backgroundGraceSeconds) {
        if (_unlockedScopes.remove(scope)) {
          changed = true;
        }
      }
    }
    if (changed) {
      _notifyChanged();
    }
  }

  void _validatePattern(List<int> pattern) {
    final normalized = pattern.toSet();
    if (pattern.length < _minimumPatternLength || normalized.length < 4) {
      throw const AppSecurityException('Pattern is too short.');
    }
    final invalidPoint = pattern.any((value) => value < 0 || value > 8);
    if (invalidPoint) {
      throw const AppSecurityException('Pattern is invalid.');
    }
  }

  String _serializePattern(List<int> pattern) {
    return pattern.join('-');
  }

  void _notifyChanged() {
    if (_changed.isClosed) {
      return;
    }
    _changed.add(null);
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    var difference = left.length ^ right.length;
    final limit = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < limit; index++) {
      final leftByte = index < left.length ? left[index] : 0;
      final rightByte = index < right.length ? right[index] : 0;
      difference |= leftByte ^ rightByte;
    }
    return difference == 0;
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var index = 0; index < bytes.length; index++) {
      bytes[index] = random.nextInt(256);
    }
    return bytes;
  }
}

/// Счётчик неверных попыток замка приложения. Общий для пространств профиля.
class _AttemptsRecord {
  const _AttemptsRecord({this.count = 0, this.lastAtMs = 0, this.wipeAfter});
  final int count;
  final int lastAtMs;
  final int? wipeAfter;

  _AttemptsRecord copyWith({
    int? count,
    int? lastAtMs,
    int? wipeAfter,
    bool clearWipe = false,
  }) => _AttemptsRecord(
    count: count ?? this.count,
    lastAtMs: lastAtMs ?? this.lastAtMs,
    wipeAfter: clearWipe ? null : (wipeAfter ?? this.wipeAfter),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'count': count,
    'last_at_ms': lastAtMs,
    if (wipeAfter != null) 'wipe_after': wipeAfter,
  };

  static _AttemptsRecord parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const _AttemptsRecord();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const _AttemptsRecord();
    final wipe = (decoded['wipe_after'] as num?)?.toInt();
    return _AttemptsRecord(
      count: ((decoded['count'] as num?)?.toInt() ?? 0).clamp(0, 1 << 20),
      lastAtMs: (decoded['last_at_ms'] as num?)?.toInt() ?? 0,
      wipeAfter: wipe == null || wipe <= 0 ? null : wipe,
    );
  }
}

class _LockSecretRecord {
  const _LockSecretRecord({
    required this.method,
    required this.saltB64,
    required this.hashB64,
    required this.iterations,
    this.wipeMain = false,
  });

  final SecurityLockMethod method;
  final String saltB64;
  final String hashB64;
  final int iterations;

  /// Только у записи кода принуждения: стирать основной профиль при вводе.
  final bool wipeMain;

  _LockSecretRecord copyWith({bool? wipeMain}) => _LockSecretRecord(
    method: method,
    saltB64: saltB64,
    hashB64: hashB64,
    iterations: iterations,
    wipeMain: wipeMain ?? this.wipeMain,
  );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'method': method.prefsValue,
      'salt_b64': saltB64,
      'hash_b64': hashB64,
      'iterations': iterations,
      if (wipeMain) 'wipe_main': true,
    };
  }

  static _LockSecretRecord? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final method = SecurityLockMethodX.fromPrefsValue(
        decoded['method'] as String?,
      );
      final saltB64 = (decoded['salt_b64'] as String? ?? '').trim();
      final hashB64 = (decoded['hash_b64'] as String? ?? '').trim();
      final iterations = (decoded['iterations'] as num?)?.toInt() ?? 0;
      if (method == SecurityLockMethod.none ||
          saltB64.isEmpty ||
          hashB64.isEmpty ||
          iterations <= 0) {
        return null;
      }
      return _LockSecretRecord(
        method: method,
        saltB64: saltB64,
        hashB64: hashB64,
        iterations: iterations,
        wipeMain: decoded['wipe_main'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}
