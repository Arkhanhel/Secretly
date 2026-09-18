// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:secretly_app/security/backup_password_policy.dart';
import 'package:secretly_app/security/restore_payload_validation.dart';
import 'package:secretly_app/security/secure_secrets.dart';

class SafeBackupContactV1 {
  const SafeBackupContactV1({required this.profileId, this.displayName});

  final String profileId;
  final String? displayName;

  Map<String, Object?> toJson() => {
    'profile_id': profileId,
    if (displayName != null) 'display_name': displayName,
  };

  static SafeBackupContactV1 fromJson(Map<String, Object?> json) {
    final pid = json['profile_id'];
    if (pid is! String || pid.isEmpty) {
      throw StateError('Safe backup missing profile_id');
    }
    final dn = json['display_name'];
    final normalizedProfileId = pid.trim();
    if (normalizedProfileId.isEmpty) {
      throw StateError('Safe backup missing profile_id');
    }
    return SafeBackupContactV1(
      profileId: normalizedProfileId,
      displayName: dn is String && dn.trim().isNotEmpty ? dn.trim() : null,
    );
  }
}

class SafeBackupPlainV1 {
  const SafeBackupPlainV1({
    required this.profileId,
    required this.profileSecretB64,
    required this.deviceId,
    required this.deviceKeysMaterialJson,
    this.cryptoKeyB64,
    required this.serverBinding,
    this.accountIdentitySeedB64,
    required this.contacts,
    required this.blockedProfiles,
    required this.darkMode,
    required this.blockUnverified,
    required this.shareNicknameInQr,
    required this.myNickname,
    this.profileIconAssetPath,
    this.profileAvatarGradientIndex = 0,
    this.profileAvatarIconScale = 1.0,
    required this.profileGalleryPaths,
    required this.profileBackgroundPaths,
    required this.profileMusicPaths,
    required this.personalConvoIds,
    this.dbSnapshot,
    this.filesB64ByRelativePath,
    this.cosmetics,
    this.createdAtMs,
    this.prefsAll,
  });

  final String profileId;
  final String profileSecretB64;
  final String deviceId;
  final String deviceKeysMaterialJson;
  final String? cryptoKeyB64;
  final String serverBinding;

  final List<SafeBackupContactV1> contacts;
  final List<String> blockedProfiles;

  final bool darkMode;
  final bool blockUnverified;
  final bool shareNicknameInQr;
  final String myNickname;
  final String? profileIconAssetPath;
  final int profileAvatarGradientIndex;
  final double profileAvatarIconScale;
  final List<String> profileGalleryPaths;
  final List<String> profileBackgroundPaths;
  final List<String> profileMusicPaths;
  final List<String> personalConvoIds;
  final Map<String, Object?>? dbSnapshot;
  final Map<String, String>? filesB64ByRelativePath;

  /// Optional premium *cosmetic* selections (avatar frame, cover, emoji status,
  /// wallpapers, theme/bubble/nickname/indicator presets, bio, launcher icon,
  /// and the basenames of any custom cover/avatar media). All values are
  /// optional — they are re-applied on restore so a restored Premium user keeps
  /// their look. NEVER carries entitlements/receipts (tier is server-derived).
  ///
  /// Backward compatibility: this whole block is absent from backups created
  /// before cosmetics were added; [fromJson] simply yields `null` in that case.
  final Map<String, Object?>? cosmetics;

  /// Когда копия была снята. Nullable НАМЕРЕННО: копии, снятые до 07.08.2026,
  /// этого поля не несут, и они обязаны продолжать восстанавливаться.
  ///
  /// 🔴 Полевой случай, ради которого поле появилось: человек восстановился и
  /// увидел давно удалённые чаты. Восстановление — полная замена, значит
  /// вернулось ровно то, что лежало в копии; то есть копия была СТАРШЕ
  /// удаления. Узнать это было неоткуда: диалог подтверждения показывал число
  /// контактов, сообщений и чатов — но не возраст самой копии.
  final int? createdAtMs;

  /// Все переносимые настройки человека (см. `safe_backup_prefs.dart`).
  ///
  /// Nullable: копии старее 07.08.2026 этого блока не несут и обязаны
  /// восстанавливаться по-прежнему. Семь настроек в блоке `prefs` оставлены на
  /// месте — их читают старые сборки и связка с десктопом.
  final Map<String, Object?>? prefsAll;

  /// Сид ключа личности АККАУНТА (AIK).
  ///
  /// 🔴 БЕЗ ЭТОГО ПОЛЯ восстановление из копии само порождало бы то, что слой 2
  /// убирает: копия несёт `device_keys_material_json`, то есть личность
  /// УСТРОЙСТВА, а AIK потерялся бы, на новом устройстве родился бы другой — и у
  /// всех собеседников выскочило бы «номер безопасности изменился». Ровно ту
  /// беду, от которой лечимся, притащил бы путь восстановления.
  ///
  /// 🔴 Версия копии НЕ поднята (та же причина, что у ключа восстановления,
  /// К-18): `fromJson` отвергает чужую версию, поэтому v2 означал бы, что старая
  /// сборка не прочитает новую копию ВОВСЕ — потеря аккаунта при откате.
  /// Необязательное поле внутри v1 безопасно в обе стороны.
  final String? accountIdentitySeedB64;

  Map<String, Object?> toJson() => {
    'v': 1,
    'profile_id': profileId,
    'profile_secret_b64': profileSecretB64,
    'device_id': deviceId,
    'device_keys_material_json': deviceKeysMaterialJson,
    if (cryptoKeyB64 != null) 'crypto_key_b64': cryptoKeyB64,
    'server_binding': serverBinding,
    // Только когда есть что положить: копия без AIK обязана остаться прежней.
    if ((accountIdentitySeedB64 ?? '').trim().isNotEmpty)
      'account_identity_seed_b64': accountIdentitySeedB64!.trim(),
    'contacts': contacts.map((c) => c.toJson()).toList(growable: false),
    'blocked_profiles': blockedProfiles,
    'prefs': {
      'dark_mode': darkMode,
      'block_unverified': blockUnverified,
      'share_nickname_in_qr': shareNicknameInQr,
      'my_nickname': myNickname,
      if (profileIconAssetPath != null &&
          profileIconAssetPath!.trim().isNotEmpty)
        'profile_icon_asset_path': profileIconAssetPath,
      'profile_avatar_gradient_index': profileAvatarGradientIndex,
      'profile_avatar_icon_scale': profileAvatarIconScale,
      'profile_gallery_paths': profileGalleryPaths,
      'profile_background_paths': profileBackgroundPaths,
      'profile_music_paths': profileMusicPaths,
      'personal_convo_ids': personalConvoIds,
    },
    if (dbSnapshot != null) 'db_snapshot': dbSnapshot,
    if (filesB64ByRelativePath != null) 'files_b64': filesB64ByRelativePath,
    if (cosmetics != null && cosmetics!.isNotEmpty) 'cosmetics': cosmetics,
    if (createdAtMs != null) 'created_at_ms': createdAtMs,
    if (prefsAll != null && prefsAll!.isNotEmpty) 'prefs_all': prefsAll,
  };

  static SafeBackupPlainV1 fromJson(Map<String, Object?> json) {
    String reqStr(String k) {
      final v = json[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      throw StateError('Safe backup missing $k');
    }

    final v = json['v'];
    if (v != 1) throw StateError('Unsupported safe backup version: $v');

    final contactsRaw = json['contacts'];
    final contacts = <SafeBackupContactV1>[];
    if (contactsRaw is List) {
      for (final it in contactsRaw) {
        if (it is Map<String, Object?>) {
          contacts.add(SafeBackupContactV1.fromJson(it));
        } else if (it is Map) {
          contacts.add(
            SafeBackupContactV1.fromJson(
              it.map((k, v) => MapEntry(k.toString(), v as Object?)),
            ),
          );
        }
      }
    }

    final blockedRaw = json['blocked_profiles'];
    final blocked = <String>[];
    if (blockedRaw is List) {
      for (final it in blockedRaw) {
        if (it is String && it.trim().isNotEmpty) blocked.add(it.trim());
      }
    }

    final prefs = (json['prefs'] is Map)
        ? (json['prefs'] as Map).map(
            (k, v) => MapEntry(k.toString(), v as Object?),
          )
        : <String, Object?>{};

    bool prefBool(String k, {bool def = false}) {
      final v = prefs[k];
      if (v is bool) return v;
      return def;
    }

    String prefStr(String k, {String def = ''}) {
      final v = prefs[k];
      if (v is String) return v;
      return def;
    }

    int prefInt(String k, {int def = 0}) {
      final v = prefs[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return def;
    }

    double prefDouble(String k, {double def = 1.0}) {
      final v = prefs[k];
      if (v is num) return v.toDouble();
      return def;
    }

    List<String> prefStrList(String k) {
      final v = prefs[k];
      if (v is! List) return const <String>[];
      return v
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    Map<String, Object?>? parseObjMap(String key) {
      final v = json[key];
      if (v is Map<String, Object?>) return v;
      if (v is Map) {
        return v.map((k, value) => MapEntry(k.toString(), value as Object?));
      }
      return null;
    }

    Map<String, String>? parseStrMap(String key) {
      final v = json[key];
      if (v is! Map) return null;
      final out = <String, String>{};
      v.forEach((k, value) {
        final ks = k.toString().trim();
        if (ks.isEmpty || value is! String) {
          throw StateError('Safe backup invalid $key');
        }
        out[ks] = value;
      });
      return out.isEmpty ? null : out;
    }

    final plain = SafeBackupPlainV1(
      profileId: reqStr('profile_id'),
      profileSecretB64: reqStr('profile_secret_b64'),
      deviceId: reqStr('device_id'),
      deviceKeysMaterialJson: reqStr('device_keys_material_json'),
      cryptoKeyB64:
          (json['crypto_key_b64'] as String?)?.trim().isNotEmpty == true
          ? (json['crypto_key_b64'] as String).trim()
          : null,
      serverBinding: reqStr('server_binding'),
      // 🔴 Необязательно и БЕЗ броска: копии, снятые до слоя 2, обязаны
      // восстанавливаться. Испорченное значение приравнивается к отсутствию —
      // лучше остаться без AIK (и вести себя как старая сборка), чем не
      // восстановиться вовсе. Бросок здесь означал бы потерю аккаунта.
      accountIdentitySeedB64: _optionalSeedB64(
        json['account_identity_seed_b64'],
      ),
      contacts: contacts,
      blockedProfiles: blocked,
      darkMode: prefBool('dark_mode'),
      blockUnverified: prefBool('block_unverified'),
      shareNicknameInQr: prefBool('share_nickname_in_qr'),
      myNickname: prefStr('my_nickname'),
      profileIconAssetPath: prefStr('profile_icon_asset_path').trim().isNotEmpty
          ? prefStr('profile_icon_asset_path').trim()
          : null,
      profileAvatarGradientIndex: prefInt('profile_avatar_gradient_index'),
      profileAvatarIconScale: prefDouble('profile_avatar_icon_scale'),
      profileGalleryPaths: prefStrList('profile_gallery_paths'),
      profileBackgroundPaths: prefStrList('profile_background_paths'),
      profileMusicPaths: prefStrList('profile_music_paths'),
      personalConvoIds: prefStrList('personal_convo_ids'),
      dbSnapshot: parseObjMap('db_snapshot'),
      filesB64ByRelativePath: parseStrMap('files_b64'),
      createdAtMs: (json['created_at_ms'] as num?)?.toInt(),
      prefsAll: parseObjMap('prefs_all'),
      // Optional: absent in pre-cosmetics backups → null (no throw). An empty
      // map is also normalized to null so the field is consistently absent.
      cosmetics: (() {
        final m = parseObjMap('cosmetics');
        return (m == null || m.isEmpty) ? null : m;
      })(),
    );
    plain.validateRestorePayload();
    return plain;
  }

  void validateRestorePayload() {
    validateRestoreIdentityPayload(
      payloadName: 'Safe backup',
      profileId: profileId,
      profileSecretB64: profileSecretB64,
      deviceId: deviceId,
      deviceKeysMaterialJson: deviceKeysMaterialJson,
      serverBinding: serverBinding,
    );
    validateSafeBackupDbSnapshot(
      payloadName: 'Safe backup',
      dbSnapshot: dbSnapshot,
    );
    validateSafeBackupFiles(
      payloadName: 'Safe backup',
      filesB64ByRelativePath: filesB64ByRelativePath,
    );
    final key = cryptoKeyB64;
    if (key != null && key.trim().isNotEmpty) {
      SecureSecrets.validateCryptoKeyB64(key);
    }
  }
}

/// Э-1 (SEC-01): опора для доступа к архиву на сервере.
///
/// До этого этапа архив отдавался любому, кто знал `profile_id`, и защищал его
/// только пароль — то есть подбор шёл ОФЛАЙН, на железе атакующего, без единого
/// ограничения. Токен доступа переносит подбор на сервер, где его можно
/// ограничить.
///
/// 🔴 Токен доступа и ключ содержимого выводятся из одного пароля, поэтому
/// разведены двумя способами сразу: разными солями и разными метками. Без
/// разделения тот, кто получил токен (а он уходит на сервер), получил бы и ключ
/// к самому архиву — сервер оказался бы способен читать переписку.
class BackupAccessV1 {
  const BackupAccessV1({
    required this.saltB64,
    required this.tokenB64,
    required this.verifierB64,
  });

  /// Публичная соль. Хранится на сервере и отдаётся до восстановления: без неё
  /// владелец не выведет токен из своего пароля на новом устройстве.
  final String saltB64;

  /// Предъявляется серверу. НИКОГДА не сохраняется на диск.
  final String tokenB64;

  /// Хранится на сервере. Сервер видит только его.
  final String verifierB64;

  static const _accessLabel = 'secretly-backup-access-v1';

  /// Новая опора: свежая соль и токен для переданного пароля.
  static Future<BackupAccessV1> mint({required String password}) async {
    final salt = _randomBytes(16);
    return _derive(password: password, salt: salt);
  }

  /// Опора для УЖЕ известной соли — путь восстановления.
  static Future<BackupAccessV1> fromSalt({
    required String password,
    required String saltB64,
  }) async {
    final salt = Uint8List.fromList(base64Decode(saltB64));
    return _derive(password: password, salt: salt);
  }

  static Future<BackupAccessV1> _derive({
    required String password,
    required Uint8List salt,
  }) async {
    // Медленная функция считается на КЛИЕНТЕ: сервер хранит быстрый хеш от
    // результата, поэтому кража серверной базы не даёт дешёвого перебора.
    final base = await SafeBackupV1.deriveAccessBase(
      password: password,
      salt: salt,
    );
    final hmac = Hmac.sha256();
    final tokenMac = await hmac.calculateMac(
      utf8.encode(_accessLabel),
      secretKey: SecretKey(base),
    );
    final token = Uint8List.fromList(tokenMac.bytes);
    final verifier = await Sha256().hash(token);
    return BackupAccessV1(
      saltB64: base64Encode(salt),
      tokenB64: base64Encode(token),
      verifierB64: base64Encode(verifier.bytes),
    );
  }
}

class SafeBackupV1 {
  static const prefix = 'secretly-safe:v1:';

  /// Э-5 (SEC-04): 🔴 ДВЕ РАЗНЫЕ КОНСТАНТЫ, И ЭТО ПРИНЦИПИАЛЬНО.
  ///
  /// Раньше здесь была одна: ею же шифровали новые архивы и ею же проверяли
  /// чужие на «не занижены ли итерации». Поднять её «в одну строку» означало
  /// объявить ВСЕ существующие архивы (записанные с 200 000) попыткой понижения
  /// и сделать их нечитаемыми — то есть отобрать у людей их собственные копии.
  ///
  /// Теперь: [_iterWrite] — чем шифруем новое, [_iterMinAccepted] — ниже чего не
  /// принимаем. Поднимать первую можно свободно, вторая не двигается никогда.
  static const _iterWrite = 400000;

  /// Планка приёма. Опускать нельзя — это защита от понижения стойкости
  /// подсунутым архивом. Поднимать тоже нельзя: сделает нечитаемыми архивы,
  /// записанные раньше.
  static const _iterMinAccepted = 200000;

  /// Э-5: стоимость вывода ключа замерена, а не взята из рекомендаций.
  ///
  /// Замер (десктоп): 200k — 731 мс, 400k — 1 477 мс, 600k — 2 213 мс. На
  /// телефоне втрое-вчетверо дольше, и с этапа Э-1 функция считается ДВАЖДЫ за
  /// сохранение: ключ содержимого и токен доступа выводятся из разных солей,
  /// поэтому общий счёт — сумма.
  ///
  /// 600 000 дали бы около полутора десятков секунд на телефоне при каждом
  /// сохранении — цена, которой рекомендация не оправдывает. 400 000 удваивают
  /// стойкость архива и остаются в разумных пределах. Дальше поднимать имеет
  /// смысл вместе с переходом на формат `v:2`, где оба ключа выводятся из
  /// ОДНОГО медленного вычисления и удвоения больше нет.
  static const _iterAccessToken = 200000;

  static int _validatedIter(Object? rawIter) {
    final iter = (rawIter as num?)?.toInt() ?? _iterMinAccepted;
    if (iter < _iterMinAccepted) {
      throw StateError('Unsupported safe backup PBKDF2 iteration count');
    }
    return iter;
  }

  /// Собрать архив с заданным числом итераций — ТОЛЬКО для проверок.
  ///
  /// Нужен, чтобы сторожевые тесты могли построить архив ровно таким, каким его
  /// записывали прежние сборки, и убедиться, что он всё ещё открывается. Без
  /// этого «совместимость со старыми копиями» пришлось бы принимать на веру.
  @visibleForTesting
  static Future<String> encryptToPayloadForTest({
    required SafeBackupPlainV1 plain,
    required String password,
    required int iter,
  }) => encryptToPayload(plain: plain, password: password, iterOverride: iter);

  static Future<String> encryptToPayload({
    required SafeBackupPlainV1 plain,
    required String password,
    int? iterOverride,
  }) async {
    BackupPasswordPolicy.validateOrThrow(password);

    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final iterations = iterOverride ?? _iterWrite;
    final keyBytes = await _deriveKey(
      password: password,
      salt: salt,
      iter: iterations,
    );
    final key = SecretKey(keyBytes);

    final aes = AesGcm.with256bits();
    final plaintextBytes = utf8.encode(jsonEncode(plain.toJson()));
    final box = await aes.encrypt(plaintextBytes, secretKey: key, nonce: nonce);

    final wrapped = {
      'v': 1,
      'kdf': 'pbkdf2-sha256',
      'iter': iterations,
      'salt_b64': base64Encode(salt),
      'nonce_b64': base64Encode(nonce),
      'ciphertext_b64': base64Encode(box.cipherText),
      'mac_b64': base64Encode(box.mac.bytes),
    };

    final compact = base64UrlEncode(utf8.encode(jsonEncode(wrapped)));
    return '$prefix$compact';
  }

  static Future<SafeBackupPlainV1> decryptFromPayload({
    required String payload,
    required String password,
  }) async {
    final raw = payload.trim();
    if (!raw.startsWith(prefix)) {
      throw StateError('Not a safe backup');
    }
    final b64 = raw.substring(prefix.length);
    final wrapped =
        jsonDecode(utf8.decode(base64Url.decode(b64))) as Map<String, dynamic>;
    if ((wrapped['v'] as num?)?.toInt() != 1) {
      throw StateError('Unsupported safe backup');
    }

    final iter = _validatedIter(wrapped['iter']);
    final salt = base64Decode(wrapped['salt_b64'] as String);
    final nonce = base64Decode(wrapped['nonce_b64'] as String);
    final ciphertext = base64Decode(wrapped['ciphertext_b64'] as String);
    final macBytes = base64Decode(wrapped['mac_b64'] as String);

    final aes = AesGcm.with256bits();
    final box = SecretBox(ciphertext, nonce: nonce, mac: Mac(macBytes));

    // AUD-060 fix: prefer the raw password (new behavior). Fall back to the
    // trimmed form only if the raw form fails, so backups created before this
    // fix (when encryption always trimmed) remain decryptable. We still
    // surface a password-error to the caller if both attempts fail.
    Future<SafeBackupPlainV1> tryWith(String pw) async {
      final keyBytes = await _deriveKey(
        password: pw,
        salt: Uint8List.fromList(salt),
        iter: iter,
      );
      final key = SecretKey(keyBytes);
      final plainBytes = await aes.decrypt(box, secretKey: key);
      final plainJson =
          jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;
      return SafeBackupPlainV1.fromJson(
        plainJson.map((k, v) => MapEntry(k, v as Object?)),
      );
    }

    try {
      return await tryWith(password);
    } catch (_) {
      final trimmed = password.trim();
      if (trimmed == password) {
        rethrow;
      }
      return tryWith(trimmed);
    }
  }

  /// Э-1: та же медленная функция, что защищает содержимое, но по ДРУГОЙ соли.
  /// Результат идёт только в вывод токена доступа и ключом архива не является.
  static Future<Uint8List> deriveAccessBase({
    required String password,
    required Uint8List salt,
  }) => _deriveKey(password: password, salt: salt, iter: _iterAccessToken);

  static Future<Uint8List> _deriveKey({
    required String password,
    required Uint8List salt,
    int iter = _iterWrite,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iter,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final bytes = await key.extractBytes();
    return Uint8List.fromList(bytes);
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

/// Разбирает необязательный 32-байтный сид в base64.
///
/// Возвращает `null` на всём, что не разобралось: в путях восстановления бросок
/// означает не «поле испорчено», а «аккаунт потерян».
String? _optionalSeedB64(Object? raw) {
  if (raw is! String) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;
  try {
    return base64Decode(value).length == 32 ? value : null;
  } on FormatException {
    return null;
  }
}
