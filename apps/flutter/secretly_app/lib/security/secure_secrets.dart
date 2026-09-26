// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'secure_storage_options.dart';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/diag_log.dart';
import 'serialized_secure_storage.dart';

/// The local DB passphrase cannot be read RIGHT NOW, but the failure is
/// TRANSIENT — the device has not been unlocked since boot, or the keystore is
/// still warming up right after an app update.
///
/// DATA SAFETY (2026-07-19): the caller must NEVER re-key or wipe the database
/// on this. Minting a fresh passphrase would open the existing encrypted DB
/// with the wrong key, SQLCipher would report `file is not a database`
/// (SQLITE_NOTADB, code 26), and the old recovery path then deleted the user's
/// entire history. Retry instead.
class DbPassphraseUnavailable implements Exception {
  DbPassphraseUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'DbPassphraseUnavailable($reason)';
}

/// The stored DB passphrase is PERMANENTLY gone: the keystore blob was
/// invalidated (device credential change) or the DB file was restored without
/// its keychain entry. The existing DB can never be opened again, so the caller
/// may start fresh — but it must QUARANTINE (rename) the old files, never
/// delete them.
class DbPassphraseLost implements Exception {
  DbPassphraseLost(this.reason);
  final String reason;
  @override
  String toString() => 'DbPassphraseLost($reason)';
}

/// «База есть, ключа нет» — потеря навсегда, а не «устройство ещё не
/// разблокировано»? Да — только на Windows: хранилище там файл, блокировки у
/// него не бывает (26.09.2026). Везде ещё — прежнее «подождать и повторить».
@visibleForTesting
bool dbPassphraseAbsenceIsPermanent(TargetPlatform platform) =>
    !kIsWeb && platform == TargetPlatform.windows;

/// The local CONTENT key cannot be read RIGHT NOW, and the failure is
/// TRANSIENT — the same locked-device / warming-keystore conditions as
/// [DbPassphraseUnavailable].
///
/// DATA SAFETY (2026-07-31): this key encrypts every local display copy — sent
/// messages, the self-mirror, cached received plaintext. Minting a fresh one
/// makes all of them permanently unreadable and they render as `'…'`. That is
/// the 2026-07-19 database-passphrase loss repeated verbatim on another key.
///
/// The caller must treat this as "crypto is not ready yet, retry" — never as
/// "there is no key". Startup already tolerates a not-ready crypto.
class ContentKeyUnavailable implements Exception {
  ContentKeyUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'ContentKeyUnavailable($reason)';
}

class SecureSecrets {
  SecureSecrets._(this._secureStorage);

  static const _dbPassKey = 'secretly/db_passphrase_v1';
  static const _cryptoKey = 'secretly/crypto_key_v1_b64';
  // Per-install X25519 seed for the in-app Support reply channel (TZ
  // 2026-07-24). Kept OUTSIDE the purge-on-fresh-install prefixes so it survives
  // restarts; a clean reinstall drops it (old support replies become unreadable,
  // which is acceptable for a support conversation).
  static const _supportSeedKey = 'secretly/support_reply_seed_v1_b64';
  static const _profileSecretKeyPrefix = 'secretly/profile_secret_v1_b64';
  static const _safeBackupAutoPasswordKeyPrefix =
      'secretly/safe_backup_auto_password_v1';
  static const _appLockSecretKeyPrefix = 'secretly/app_lock_secret_v1';

  // Legacy dev key location.
  static const _legacyPrefsCryptoKey = 'dev_symm_key_v1_b64';

  final FlutterSecureStorage _secureStorage;

  static SecureSecrets create() {
    return SecureSecrets._(
      const SerializedSecureStorage(
        aOptions: kSecretlyAndroidStorageOptions,
        // См. device_keys.dart: `first_unlock_this_device` — секреты читаются на
        // заблокированном устройстве после первой разблокировки (лечит -25308),
        // но НЕ переезжают на другое устройство через резервную копию Apple
        // (SEC-02, 25.08.2026). Здесь лежит в том числе пароль базы SQLCipher.
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
        mOptions: MacOsOptions(
          useDataProtectionKeyChain: false,
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      ),
    );
  }

  static String validateProfileSecretB64(String secretB64) {
    final normalized = secretB64.trim();
    if (normalized.isEmpty) {
      throw StateError('profile secret missing');
    }
    try {
      final bytes = base64Decode(normalized);
      if (bytes.isEmpty) {
        throw StateError('profile secret invalid');
      }
    } on FormatException {
      throw StateError('profile secret invalid');
    }
    return normalized;
  }

  static String validateCryptoKeyB64(String keyB64) {
    final normalized = keyB64.trim();
    if (normalized.isEmpty) {
      throw StateError('crypto key missing');
    }
    try {
      final bytes = base64Decode(normalized);
      if (bytes.length != 32) {
        throw StateError('crypto key invalid');
      }
    } on FormatException {
      throw StateError('crypto key invalid');
    }
    return normalized;
  }

  /// BACKGROUND DRAIN (2026-07-16): read-only variant for secondary isolates
  /// (the FCM background fetcher). It must NEVER create a fresh passphrase or
  /// delete a glitching key — either would sever the main app from its own
  /// encrypted DB. Any read problem simply means "not available right now" and
  /// the background work is skipped.
  Future<String?> readDbPassphraseIfExists() async {
    try {
      final existing = await _secureStorage.read(key: _dbPassKey);
      if (existing == null || existing.isEmpty) return null;
      return existing;
    } catch (_) {
      return null;
    }
  }

  /// True when the error means the keystore blob is PERMANENTLY unusable (the
  /// OS key that wrapped it was invalidated), as opposed to "not readable right
  /// now". Only these justify starting over with a fresh passphrase.
  static bool isPermanentKeystoreInvalidation(Object e) {
    if (e is! PlatformException) return false;
    final raw = '${e.code} ${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();
    // NB: deliberately does NOT include `usernotauthenticated` (device simply
    // not unlocked yet) nor a bare `keystore` substring (matches transient
    // "keystore operation failed" too) — treating those as permanent is what
    // caused databases to be wiped after an app update.
    return raw.contains('badpadding') ||
        raw.contains('aeadbadtag') ||
        raw.contains('failed to unwrap key') ||
        raw.contains('invalidkey');
  }

  /// Reads the stored passphrase, retrying through transient keychain errors.
  ///
  /// Returns `null` only when the read SUCCEEDED and there genuinely is no
  /// stored key. Throws [DbPassphraseLost] on permanent invalidation, and
  /// [DbPassphraseUnavailable] when every attempt failed transiently.
  Future<String?> _readDbPassphraseWithRetry({int attempts = 4}) async {
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final value = await _secureStorage.read(key: _dbPassKey);
        if (value != null && value.isNotEmpty) return value;
        return null; // read worked; key really is absent
      } catch (e) {
        if (isPermanentKeystoreInvalidation(e)) {
          throw DbPassphraseLost('keystore invalidated: $e');
        }
        lastError = e;
        await Future<void>.delayed(
          Duration(milliseconds: 120 * (attempt + 1)),
        );
      }
    }
    throw DbPassphraseUnavailable('keychain read failed: $lastError');
  }

  /// Passphrase for an EXISTING encrypted database. Never creates one.
  ///
  /// When a DB file is already on disk the stored key is the ONLY key that can
  /// open it, so "cannot read the key" must never degrade into "make a new
  /// key" — see [DbPassphraseUnavailable].
  Future<String> requireExistingDbPassphrase() async {
    final existing = await _readDbPassphraseWithRetry();
    if (existing != null && existing.isNotEmpty) return existing;
    // DATA LOSS (2026-07-20): "the read succeeded and found nothing" is NOT
    // proof the key is gone. On iOS a locked device — or any launch before the
    // first unlock, e.g. woken by a push — reports a perfectly good keychain
    // item as ABSENT rather than raising. Treating that as permanent loss is
    // exactly what re-keyed a live database and emptied a user's app.
    //
    // A database exists, so a key existed too. Anything we cannot read right
    // now is transient by definition: wait for the device to unlock and retry.
    // We never re-key on this path.
    //
    // 26.09.2026, Windows — исключение. Там хранилище — файл, «заблокированного
    // устройства» не бывает: чтение прошло и ключа нет — значит, он потерян
    // (гонка записей, см. SerializedSecureStorage). Ждать нечего, а
    // «Unavailable» запирал вход навсегда. Lost ведёт на готовый путь: старый
    // файл откладывается в сторону (не удаляется), запуск — с чистого листа.
    if (dbPassphraseAbsenceIsPermanent(defaultTargetPlatform)) {
      throw DbPassphraseLost('stored passphrase absent (Windows file store)');
    }
    throw DbPassphraseUnavailable(
      'stored passphrase not readable yet (device may still be locked)',
    );
  }

  /// Passphrase for a FRESH install (no database on disk yet).
  Future<String> getOrCreateDbPassphrase() async {
    String? existing;
    try {
      existing = await _readDbPassphraseWithRetry();
    } on DbPassphraseLost {
      // Blob unusable and there is nothing to protect yet — mint a new one.
      existing = null;
    }
    if (existing != null && existing.isNotEmpty) return existing;

    // SQLCipher passphrase can be any string. Use base64url for portability.
    final bytes = _randomBytes(32);
    final pass = base64UrlEncode(bytes);
    await _secureStorage.write(key: _dbPassKey, value: pass);
    return pass;
  }

  Future<String> resetDbPassphrase() async {
    await _safeDelete(_dbPassKey);
    final bytes = _randomBytes(32);
    final pass = base64UrlEncode(bytes);
    await _secureStorage.write(key: _dbPassKey, value: pass);
    return pass;
  }

  /// Reads the stored content key, retrying through transient keychain errors.
  ///
  /// Returns null only when the read SUCCEEDED and no key is stored. Throws
  /// [ContentKeyUnavailable] when every attempt failed transiently.
  ///
  /// Mirrors [_readDbPassphraseWithRetry] deliberately: the two keys have the
  /// same failure modes and the same consequence for getting it wrong.
  Future<String?> _readCryptoKeyWithRetry({int attempts = 4}) async {
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final value = await _secureStorage.read(key: _cryptoKey);
        if (value != null && value.isNotEmpty) return value;
        return null; // read worked; key really is absent
      } catch (e) {
        // A PERMANENT invalidation is not worth retrying — but it is also not
        // this method's call to act on. It returns through the same channel so
        // that the ONLY place allowed to delete is the mint path below, which
        // can first check whether there is anything to lose.
        if (isPermanentKeystoreInvalidation(e)) {
          throw ContentKeyUnavailable('keystore invalidated: $e');
        }
        lastError = e;
        await Future<void>.delayed(
          Duration(milliseconds: 120 * (attempt + 1)),
        );
      }
    }
    throw ContentKeyUnavailable('keychain read failed: $lastError');
  }

  /// Read-only variant for SECONDARY isolates (the FCM background decrypt).
  ///
  /// BACKGROUND (2026-07-31, F-CONTENTKEY-2): the background pass used to go
  /// through get-or-create, so a push arriving while the device was locked
  /// could mint a fresh content key and orphan every local copy the main app
  /// had written. A background pass that cannot read the key must SKIP.
  Future<Uint8List?> readCryptoKeyIfExists() async {
    try {
      final existing = await _secureStorage.read(key: _cryptoKey);
      if (existing == null || existing.isEmpty) return null;
      return Uint8List.fromList(base64Decode(existing));
    } catch (_) {
      return null;
    }
  }

  /// The content key for an install that ALREADY HAS local data. Never mints,
  /// never deletes.
  ///
  /// "I cannot read the key right now" must never degrade into "make a new
  /// key" — see [ContentKeyUnavailable]. A null read is NOT proof of absence:
  /// on iOS a locked device reports a perfectly good keychain item as missing.
  Future<Uint8List> requireExistingCryptoKey() async {
    final existing = await _readCryptoKeyWithRetry();
    if (existing != null && existing.isNotEmpty) {
      return Uint8List.fromList(base64Decode(existing));
    }
    throw ContentKeyUnavailable(
      'stored content key not readable yet (device may still be locked)',
    );
  }

  /// The content key for a FRESH install — one with nothing to lose.
  ///
  /// 🔴 Callers must prove that: pass [allowMint] only when the local store
  /// holds no encrypted content (see `AppController._contentKeyMintAllowed`).
  /// With `allowMint: false` this is exactly [requireExistingCryptoKey].
  ///
  /// DATA LOSS (2026-07-31): this method used to delete the stored key whenever
  /// a read threw something `_isRecoverableSecureStorageError` matched — a
  /// predicate that includes `usernotauthenticated` and a bare `keystore`, i.e.
  /// the conditions that mean "try again in a moment". It then fell through and
  /// minted a replacement, so one glitchy read during a locked-device launch
  /// permanently orphaned the user's local message copies. Deleting is now
  /// confined to a PROVEN permanent invalidation on an install with no content.
  Future<Uint8List> getOrCreateCryptoKey({bool allowMint = false}) async {
    if (!allowMint) return requireExistingCryptoKey();

    String? existing;
    // Whether we got here by DISCARDING a blob we could not read, as opposed to
    // finding nothing at all. Only the first is worth alarming about, so the two
    // must stay distinguishable in the log below.
    var discardedUnreadableBlob = false;
    try {
      existing = await _readCryptoKeyWithRetry();
    } on ContentKeyUnavailable {
      // Nothing to lose on this install, so an unreadable blob may be replaced.
      // The delete is what makes the write below succeed on platforms that
      // refuse to overwrite a corrupt item.
      await _safeDelete(_cryptoKey);
      discardedUnreadableBlob = true;
      existing = null;
    }
    if (existing != null && existing.isNotEmpty) {
      return Uint8List.fromList(base64Decode(existing));
    }

    // Migration: if old dev key exists in SharedPreferences, move it.
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_legacyPrefsCryptoKey);
      if (legacy != null && legacy.isNotEmpty) {
        await _secureStorage.write(key: _cryptoKey, value: legacy);
        // Best-effort: keep legacy as-is to not break older installs.
        return Uint8List.fromList(base64Decode(legacy));
      }
    } catch (_) {
      // ignore migration failures
    }

    // F-CONTENTKEY-3: a mint must never be silent again. Silence is why this
    // ran in production for weeks looking like a rendering bug — the only
    // visible symptom was messages turning into '…'. Reaching here is only
    // legitimate on an install with no content; anywhere else it is the single
    // event that destroys local history, so it must be findable in a log.
    DiagLog.event('security', 'content_key_minted', {
      'discarded_unreadable_blob': discardedUnreadableBlob,
    });
    final bytes = _randomBytes(32);
    final b64 = base64Encode(bytes);
    await _secureStorage.write(key: _cryptoKey, value: b64);
    return bytes;
  }

  /// The user's per-install X25519 support REPLY seed (32 bytes). The admin
  /// console seals support replies to its public key; the user decrypts with
  /// this. Get-or-create, mirroring [getOrCreateCryptoKey].
  Future<Uint8List> getOrCreateSupportSeed() async {
    String? existing;
    try {
      existing = await _secureStorage.read(key: _supportSeedKey);
    } catch (e) {
      if (_isRecoverableSecureStorageError(e)) {
        await _safeDelete(_supportSeedKey);
        existing = null;
      } else {
        rethrow;
      }
    }
    if (existing != null && existing.isNotEmpty) {
      return Uint8List.fromList(base64Decode(existing));
    }
    final bytes = _randomBytes(32);
    await _secureStorage.write(key: _supportSeedKey, value: base64Encode(bytes));
    return bytes;
  }

  Future<void> setCryptoKeyB64(String keyB64) async {
    final normalized = validateCryptoKeyB64(keyB64);
    await _secureStorage.write(key: _cryptoKey, value: normalized);
  }

  Future<void> debugDumpPresence() async {
    if (!kDebugMode) return;
    bool hasDb = false;
    bool hasCrypto = false;
    try {
      hasDb = (await _secureStorage.read(key: _dbPassKey)) != null;
      hasCrypto = (await _secureStorage.read(key: _cryptoKey)) != null;
    } catch (_) {
      // ignore debug probe failures
    }
    debugPrint(
      'SecureSecrets: db_passphrase=${hasDb ? 'set' : 'missing'}, crypto_key=${hasCrypto ? 'set' : 'missing'}',
    );
  }

  static String _profileSecretKey(String profileId) =>
      '$_profileSecretKeyPrefix/$profileId';
  static String _safeBackupAutoPasswordKey(String profileId) =>
      '$_safeBackupAutoPasswordKeyPrefix/$profileId';
  static String _appLockSecretKey(String scopeId) =>
      '$_appLockSecretKeyPrefix/$scopeId';

  Future<String?> getProfileSecretB64(String profileId) async {
    String? v;
    try {
      v = await _secureStorage.read(key: _profileSecretKey(profileId));
    } catch (e) {
      if (_isRecoverableSecureStorageError(e)) {
        await _safeDelete(_profileSecretKey(profileId));
        v = null;
      } else {
        rethrow;
      }
    }
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> setProfileSecretB64({
    required String profileId,
    required String secretB64,
  }) async {
    await _secureStorage.write(
      key: _profileSecretKey(profileId),
      value: validateProfileSecretB64(secretB64),
    );
  }

  Future<void> deleteProfileSecret(String profileId) async {
    await _secureStorage.delete(key: _profileSecretKey(profileId));
  }

  /// FIX-C1 (Z1 desync defense): purge identity material (profile secrets,
  /// per-device key bundles, safe-backup passwords) that lingers in the secure
  /// store from a PRIOR install. On iOS the Keychain survives an app uninstall,
  /// and some Android OEM transfer tools copy the secure store but not the
  /// hardware Keystore key — both leave orphaned identity material that, paired
  /// with wiped SharedPreferences, drives the device_id/identity desync that
  /// triggers a self-heal rotation and a zombie device_id. Callers MUST only
  /// invoke this on a confirmed fresh install (no profile_id in prefs), where
  /// there is no live identity to protect. The local DB passphrase, the local
  /// crypto key, and the app-lock secret are intentionally PRESERVED so this
  /// can never brick an at-rest DB or the screen lock.
  /// Диагностика: какой ключ хранилища не поддаётся расшифровке.
  ///
  /// 🔴 ЗАЧЕМ (04.09.2026). При КАЖДОМ холодном запуске Android пишет в журнал
  /// `SecureStorageAndroid: re-encryption failed / AEADBadTagException`.
  /// Приложение при этом работает, база открывается — значит пароль базы
  /// читается. Какой именно ключ спотыкается, неизвестно: сообщение плагина не
  /// называет его.
  ///
  /// 🔴 ЭТОТ МЕТОД ТОЛЬКО ЧИТАЕТ. Ни записи, ни удаления, ни пересоздания — и
  /// это не осторожность вообще, а память о конкретном случае: попытка
  /// «починить» шифрование локальных секретов уничтожила ключевой материал на
  /// живом устройстве и была откачена (SEC-03). Диагностика обязана оставаться
  /// диагностикой.
  ///
  /// Читает по ОДНОМУ ключу, а не через `readAll`: тот сам по себе затевает
  /// перешифровку всего хранилища и потому не показал бы, где именно сбой.
  ///
  /// В журнал уходит только ИМЯ ключа и то, удалось ли чтение. Значения не
  /// логируются никогда — это ключевой материал.
  Future<void> diagnoseKeyReadability({
    String? profileId,
    String? deviceId,
  }) async {
    final probes = <String>[
      _dbPassKey,
      _cryptoKey,
      _supportSeedKey,
      _legacyPrefsCryptoKey,
      if (profileId != null && profileId.trim().isNotEmpty) ...<String>[
        '$_profileSecretKeyPrefix/${profileId.trim()}',
        '$_safeBackupAutoPasswordKeyPrefix/${profileId.trim()}',
        '$_appLockSecretKeyPrefix/${profileId.trim()}',
      ],
      if (profileId != null &&
          profileId.trim().isNotEmpty &&
          deviceId != null &&
          deviceId.trim().isNotEmpty)
        'secretly/device_keys_v1/${profileId.trim()}/${deviceId.trim()}',
    ];

    for (final key in probes) {
      String outcome;
      try {
        final value = await _secureStorage.read(key: key);
        outcome = value == null
            ? 'absent'
            : (value.isEmpty ? 'empty' : 'ok');
      } catch (e) {
        // Тип ошибки называем, содержимое — нет: в сообщении платформы может
        // оказаться фрагмент данных.
        outcome = 'FAILED:${e.runtimeType}';
      }
      // 🔴 ПОЛЕ НАЗЫВАЕТСЯ `slot`, А НЕ `key`. Журнал намеренно выбрасывает поля
      // с именем `key` — как потенциально секретные. Защита сработала верно, но
      // первая редакция пробы из-за неё выводила один исход без имени, и
      // результат оказался нечитаемым. Имя ключа хранилища секретом не
      // является; секретом является его ЗНАЧЕНИЕ, которое сюда не попадает.
      DiagLog.event('keychain', 'probe', {
        'slot': key,
        'outcome': outcome,
      });
    }

    // 🔴 ВТОРАЯ ЧАСТЬ: что вообще лежит в хранилище.
    //
    // Первый прогон показал странное: ошибка перешифровки есть, а все известные
    // ключи читаются. Сопоставление по времени объяснило почему — ошибка
    // случается ДО проб и в другом потоке, то есть при первом обращении плагина
    // к хранилищу, когда он затевает свою миграцию. Значит сбойное значение в
    // список известных не входит.
    //
    // `readAll` здесь уместен именно потому, что нас интересуют ИМЕНА, а не
    // значения: он вернёт всё, что плагину удалось прочитать, и сравнение с
    // ожидаемым покажет лишнее. Осечка самого `readAll` тоже результат: она
    // означает, что хранилище не читается целиком.
    //
    // Значения не логируются — только имена и их количество.
    try {
      final all = await _secureStorage.readAll();
      DiagLog.event('keychain', 'inventory_ok', {'count': all.length});
      for (final name in all.keys) {
        DiagLog.event('keychain', 'slot_present', {'slot': name});
      }
    } catch (e) {
      DiagLog.event('keychain', 'inventory_failed', {
        'error_type': e.runtimeType.toString(),
      });
    }
  }

  Future<int> purgeOrphanedIdentityMaterial() async {
    var removed = 0;
    Map<String, String> all;
    try {
      all = await _secureStorage.readAll();
    } catch (_) {
      return 0;
    }
    for (final key in all.keys) {
      final isIdentityMaterial =
          key.startsWith(_profileSecretKeyPrefix) ||
          key.startsWith('secretly/device_keys_v1') ||
          key.startsWith(_safeBackupAutoPasswordKeyPrefix);
      if (!isIdentityMaterial) continue;
      try {
        await _secureStorage.delete(key: key);
        removed++;
      } catch (_) {
        // best-effort
      }
    }
    return removed;
  }

  Future<String?> getSafeBackupAutoPassword(String profileId) async {
    String? v;
    try {
      v = await _secureStorage.read(key: _safeBackupAutoPasswordKey(profileId));
    } catch (e) {
      if (_isRecoverableSecureStorageError(e)) {
        await _safeDelete(_safeBackupAutoPasswordKey(profileId));
        v = null;
      } else {
        rethrow;
      }
    }
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> setSafeBackupAutoPassword({
    required String profileId,
    required String password,
  }) async {
    await _secureStorage.write(
      key: _safeBackupAutoPasswordKey(profileId),
      value: password,
    );
  }

  Future<void> deleteSafeBackupAutoPassword(String profileId) async {
    await _safeDelete(_safeBackupAutoPasswordKey(profileId));
  }

  Future<String?> getAppLockSecret(String scopeId) async {
    String? value;
    try {
      value = await _secureStorage.read(key: _appLockSecretKey(scopeId));
    } catch (e) {
      if (_isRecoverableSecureStorageError(e)) {
        await _safeDelete(_appLockSecretKey(scopeId));
        value = null;
      } else {
        rethrow;
      }
    }
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> setAppLockSecret({
    required String scopeId,
    required String secret,
  }) async {
    await _secureStorage.write(key: _appLockSecretKey(scopeId), value: secret);
  }

  Future<void> deleteAppLockSecret(String scopeId) async {
    await _safeDelete(_appLockSecretKey(scopeId));
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {
      // ignore
    }
  }

  bool _isRecoverableSecureStorageError(Object e) {
    if (e is! PlatformException) return false;
    final raw = '${e.code} ${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();
    return raw.contains('badpadding') ||
        raw.contains('keystore') ||
        raw.contains('decrypt') ||
        raw.contains('invalidkey') ||
        raw.contains('failed to unwrap key') ||
        raw.contains('aeadbadtag') ||
        raw.contains('usernotauthenticated');
  }
}

Uint8List _randomBytes(int n) {
  final r = Random.secure();
  final out = Uint8List(n);
  for (var i = 0; i < out.length; i++) {
    out[i] = r.nextInt(256);
  }
  return out;
}
