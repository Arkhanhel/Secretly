// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'secure_storage_options.dart';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'serialized_secure_storage.dart';

/// Ключ личности АККАУНТА (AIK) — один на человека, а не на устройство.
///
/// ЗАЧЕМ. Номер безопасности сегодня считается от identity-ключа УСТРОЙСТВА,
/// поэтому «номер этого контакта изменился» выскакивает от любой смены телефона
/// и — что хуже — от ротации личности И-1, которая по построению выглядит как
/// новое устройство. То есть механизм, чинивший доставку, работает генератором
/// ложных предупреждений. У Signal номер считается от ключа аккаунта, общего для
/// всех устройств человека.
///
/// Устройство при публикации связки прикладывает СЕРТИФИКАТ: подпись своего
/// identity-ключа ключом аккаунта. Получатель, увидев новое устройство контакта,
/// проверяет подпись против известного ему AIK этого контакта: сошлось — тот же
/// человек, номер не меняется; не сошлось — вот теперь настоящая смена номера.
///
/// 🔴 AIK НЕЛЬЗЯ ВЫВОДИТЬ ИЗ `profile_secret` (К-1). Соблазн велик: секрет уже
/// общий для устройств профиля и уже едет в ключе восстановления. Но
/// `profile_secret` уходит на сервер ОТКРЫТЫМ ТЕКСТОМ в заголовке
/// `x-secretly-profile-secret-b64`; сервер лишь ХРАНИТ его как SHA-256, а ВИДИТ
/// целиком. Ключ, выведенный из него, был бы известен серверу ключей, и сервер
/// смог бы подписать подставное устройство от имени любого человека — то есть
/// уничтожил бы ровно ту защиту, ради которой номер безопасности существует.
/// AIK — собственный сид, никогда не покидающий устройство в открытом виде.
///
/// 🔴 ПОЧЕМУ ОТДЕЛЬНЫЙ КЛЮЧ ХРАНИЛИЩА, А НЕ ПОЛЕ В БЛОКЕ КЛЮЧЕЙ УСТРОЙСТВА
/// (К-16, найдено при разборе 08.08). `_DeviceKeyMaterialV1.toJson` перечисляет
/// поля ВРУЧНУЮ. Положи сид туда — и ОТКАТ сборки уничтожит его навсегда:
/// старый код прочитает JSON, не заметит незнакомого поля и перезапишет блок без
/// него. При обратном обновлении родится НОВЫЙ AIK, и у всех собеседников номер
/// изменится. Свой ключ хранилища старая сборка просто не трогает.
///
/// 🔴 КЛЮЧ БЕЗ `device_id` — НАМЕРЕННО. AIK принадлежит профилю и приезжает на
/// новое устройство ключом восстановления. Ключ хранилища устройства
/// (`device_keys_v1/<profile>/<device>`) построен иначе, и повторять его форму
/// здесь было бы ошибкой.
class AccountIdentity {
  AccountIdentity._(this._secureStorage);

  static AccountIdentity create() {
    return AccountIdentity._(
      const SerializedSecureStorage(
        aOptions: kSecretlyAndroidStorageOptions,
        // Те же условия доступности, что у ключей устройства: сертификат
        // подписывается при публикации связки, а она бывает и на запуске
        // из-под блокировки. `whenUnlocked` дал бы -25308 и фатальный экран.
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

  /// Контекст подписи сертификата устройства.
  ///
  /// 🔴 Обязателен и обязан быть в подписываемых байтах ПЕРВЫМ: без разделения
  /// областей подпись, снятая с одного назначения, годилась бы для другого.
  static const String certificateContext = 'secretly-device-cert-v1';

  final FlutterSecureStorage _secureStorage;

  static String _storageKey(String profileId) =>
      'secretly/account_identity_v1/$profileId';

  /// Защёлка от двух генераций ВНУТРИ одного изолята. Между изолятами она не
  /// работает — там защита в том, что генерировать имеет право только главный,
  /// см. [ensureSeedB64].
  static final Map<String, Future<String>> _inFlight = <String, Future<String>>{};

  /// Читает сид. `null` — если его нет.
  ///
  /// 🔴 Терпимость к отсутствию — не удобство, а требование (К-15). Аналогичный
  /// `readSeed` в `_DeviceKeyMaterialV1.fromJson` БРОСАЕТ на отсутствующем поле,
  /// и повтори мы это здесь — у каждой существующей установки первый же запуск
  /// новой сборки кончился бы ошибкой чтения ключей.
  Future<String?> loadSeedB64({required String profileId}) async {
    final pid = profileId.trim();
    if (pid.isEmpty) return null;
    final raw = await _secureStorage.read(key: _storageKey(pid));
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    // Испорченное значение — то же, что отсутствие: пусть верхний слой ведёт
    // себя как со старым контактом, а не падает.
    return _isValidSeedB64(value) ? value : null;
  }

  /// Создаёт сид, если его ещё нет, и возвращает его.
  ///
  /// 🔴 ТОЛЬКО ИЗ ГЛАВНОГО ИЗОЛЯТА (К-17). Фоновые изоляты трогают ключи
  /// (`background_decrypt`, `background_inbox_fetcher`, `background_worker`), а
  /// `_loadOrCreateMaterial` у ключей устройства создаёт материал при отсутствии
  /// БЕЗ всякого замка. Для ключей устройства это дремлющий риск — к работе фона
  /// они уже есть. Для AIK «отсутствует» — норма первого запуска после
  /// обновления, поэтому гонка вероятна, а её цена — ДВА РАЗНЫХ AIK у одного
  /// человека, то есть расщепление личности (класс «два писателя» из И-3).
  ///
  /// Фоновые пути обязаны звать [loadSeedB64] и терпеть `null`.
  Future<String> ensureSeedB64({required String profileId}) {
    final pid = profileId.trim();
    if (pid.isEmpty) {
      throw ArgumentError('account identity requires a profile id');
    }
    final pending = _inFlight[pid];
    if (pending != null) return pending;
    final future = _ensureSeedB64Locked(pid);
    _inFlight[pid] = future;
    return future.whenComplete(() => _inFlight.remove(pid));
  }

  Future<String> _ensureSeedB64Locked(String profileId) async {
    final existing = await loadSeedB64(profileId: profileId);
    if (existing != null) return existing;
    final seed = base64Encode(_randomBytes(32));
    await _secureStorage.write(key: _storageKey(profileId), value: seed);
    return seed;
  }

  /// Кладёт сид, приехавший ключом восстановления.
  ///
  /// 🔴 Всегда перезаписывает: кит — источник истины о личности профиля. Если
  /// здесь уже лежал сид, сгенерированный локально до восстановления, оставить
  /// его значило бы разойтись с остальными устройствами человека навсегда.
  Future<void> importSeedB64({
    required String profileId,
    required String seedB64,
  }) async {
    final pid = profileId.trim();
    final seed = seedB64.trim();
    if (pid.isEmpty) {
      throw ArgumentError('account identity requires a profile id');
    }
    if (!_isValidSeedB64(seed)) {
      throw StateError('account identity seed is invalid');
    }
    await _secureStorage.write(key: _storageKey(pid), value: seed);
  }

  Future<void> deleteSeed({required String profileId}) async {
    final pid = profileId.trim();
    if (pid.isEmpty) return;
    await _secureStorage.delete(key: _storageKey(pid));
  }

  /// Открытая часть AIK, или `null` если сида нет.
  Future<String?> loadPublicKeyB64({required String profileId}) async {
    final seed = await loadSeedB64(profileId: profileId);
    if (seed == null) return null;
    return publicKeyB64FromSeed(seed);
  }

  /// Подписывает сертификат устройства, или `null` если сида нет.
  Future<String?> signDeviceCertificate({
    required String profileId,
    required String deviceId,
    required String deviceIdentityPubB64,
  }) async {
    final seed = await loadSeedB64(profileId: profileId);
    if (seed == null) return null;
    final keyPair = await Ed25519().newKeyPairFromSeed(base64Decode(seed));
    final signature = await Ed25519().sign(
      deviceCertificateMessage(
        profileId: profileId,
        deviceId: deviceId,
        deviceIdentityPubB64: deviceIdentityPubB64,
      ),
      keyPair: keyPair,
    );
    return base64Encode(signature.bytes);
  }

  // ── Чистые функции: без хранилища, поэтому проверяемы тестом ──────────────

  static bool _isValidSeedB64(String value) {
    try {
      return base64Decode(value).length == 32;
    } on FormatException {
      return false;
    }
  }

  /// Открытая часть выводится из сида однозначно, поэтому хранить её отдельно
  /// незачем — и незачем бояться, что она разойдётся с приватной.
  static Future<String> publicKeyB64FromSeed(String seedB64) async {
    final keyPair = await Ed25519().newKeyPairFromSeed(base64Decode(seedB64));
    final pub = await keyPair.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  /// Байты, которые подписывает AIK.
  ///
  /// 🔴 Разделители обязательны. Без них `profile|device` и `profiledevice|`
  /// дали бы одни и те же байты, и сертификат от одного устройства годился бы
  /// другому — то есть проверка перестала бы что-либо доказывать.
  static List<int> deviceCertificateMessage({
    required String profileId,
    required String deviceId,
    required String deviceIdentityPubB64,
  }) {
    return utf8.encode(
      '$certificateContext|$profileId|$deviceId|$deviceIdentityPubB64',
    );
  }

  /// Проверяет сертификат устройства против AIK контакта.
  ///
  /// 🔴 Возвращает `false` на любой неясности — испорченный base64, не тот
  /// размер ключа, пустое поле. Отказ в закрытую: «не доказано» никогда не
  /// должно читаться как «доказано».
  static Future<bool> verifyDeviceCertificate({
    required String accountPubB64,
    required String certificateB64,
    required String profileId,
    required String deviceId,
    required String deviceIdentityPubB64,
  }) async {
    if (accountPubB64.trim().isEmpty || certificateB64.trim().isEmpty) {
      return false;
    }
    try {
      final pub = base64Decode(accountPubB64.trim());
      final sig = base64Decode(certificateB64.trim());
      if (pub.length != 32 || sig.length != 64) return false;
      return await Ed25519().verify(
        deviceCertificateMessage(
          profileId: profileId,
          deviceId: deviceId,
          deviceIdentityPubB64: deviceIdentityPubB64,
        ),
        signature: Signature(
          sig,
          publicKey: SimplePublicKey(pub, type: KeyPairType.ed25519),
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Число повторов хэша при выводе отпечатка.
  ///
  /// 🔴 Повторы — не украшение. Отпечаток УСЕЧЁН до 30 цифр (≈100 бит), и без
  /// удорожания вычисления злоумышленник мог бы перебором подобрать ключ, чей
  /// отпечаток совпадает с настоящим, — люди сверяют цифры, а не ключи. Signal
  /// берёт 5200 повторов; берём столько же, чтобы не изобретать своей стойкости.
  static const int fingerprintIterations = 5200;

  /// Отпечаток ОДНОЙ стороны: 30 десятичных цифр.
  ///
  /// 🔴 Считается только от своего ключа, независимо от собеседника — так у
  /// Signal. Это не мелочь: отпечаток человека один и тот же во всех его
  /// переписках, поэтому его можно опубликовать и сверить один раз.
  static String fingerprintDigits(String accountPubB64) {
    final key = accountPubB64.trim();
    if (key.isEmpty) return '';
    List<int> bytes;
    try {
      bytes = base64Decode(key);
    } on FormatException {
      return '';
    }
    if (bytes.length != 32) return '';

    // Первый проход завязывает и версию формата, и сам ключ; дальше повторы
    // идут по хэшу вместе с ключом, как в libsignal.
    var digest = crypto.sha512
        .convert(<int>[...utf8.encode('secretly-safety-number-v2'), ...bytes])
        .bytes;
    for (var i = 1; i < fingerprintIterations; i++) {
      digest = crypto.sha512.convert(<int>[...digest, ...bytes]).bytes;
    }

    // 6 групп по 5 байт → 6 × 5 = 30 цифр. Байты НЕ переиспользуются: sha512
    // даёт 64, нужно 30. Обход по кругу сделал бы цифры зависимыми.
    final buffer = StringBuffer();
    for (var group = 0; group < 6; group++) {
      var value = 0;
      for (var i = 0; i < 5; i++) {
        value = (value << 8) | digest[group * 5 + i];
      }
      buffer.write((value % 100000).toString().padLeft(5, '0'));
    }
    return buffer.toString();
  }

  /// Номер безопасности пары: два отпечатка по 30 цифр, 60 всего.
  ///
  /// 🔴 Отпечатки СОРТИРУЮТСЯ, чтобы обе стороны видели один и тот же код
  /// (модель Signal). Сравнивать по телефону разные строки бессмысленно.
  ///
  /// 🔴 Формат обязан ВИЗУАЛЬНО отличаться от нынешнего пер-девайсного (24 hex,
  /// четыре группы по 6), иначе люди начнут сверять старый код с новым и решат,
  /// что номер «изменился», ровно в тот момент, когда мы это и лечим.
  static String safetyNumberFromAccountKeys({
    required String selfAccountPubB64,
    required String peerAccountPubB64,
  }) {
    final mine = fingerprintDigits(selfAccountPubB64);
    final theirs = fingerprintDigits(peerAccountPubB64);
    if (mine.isEmpty || theirs.isEmpty) return '';
    final ordered = mine.compareTo(theirs) <= 0
        ? <String>[mine, theirs]
        : <String>[theirs, mine];
    final joined = ordered[0] + ordered[1];
    // Группы по пять — так их читают вслух.
    final buffer = StringBuffer();
    for (var i = 0; i < joined.length; i += 5) {
      if (i > 0) buffer.write(' ');
      buffer.write(joined.substring(i, i + 5));
    }
    return buffer.toString();
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
