// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Защищённое хранилище, чьи операции на Windows идут строго по одной.
///
/// 🔴 26.09.2026. `flutter_secure_storage_windows` держит ВСЕ секреты в одном
/// файле (DPAPI) и на каждую запись читает его целиком, меняет одно значение и
/// записывает целиком обратно — без блокировки. Две записи одновременно — и
/// одна из них пропадает. Так Windows-версия теряла ключ устройства (реле
/// отвечало «неверная подпись», и сообщения копились на сервере) и пароль базы
/// (при запуске — `DbPassphraseUnavailable`, вход заперт). На телефонах и Mac
/// каждый секрет хранится отдельно, там очередь не нужна и не включается.
///
/// Очередь общая для всех экземпляров: файл один на всё приложение.
///
/// 🔴 10.10.2026, пространство профиля (Э2). Через этот класс ходят все
/// секреты приложения: пароль базы, ключ содержимого, секрет профиля, ключи
/// устройства, ключ личности. Пространство обманки получает свои копии всех
/// секретов одним [spacePrefix] здесь, а не правкой каждого ключа. Записи
/// замка (PIN) и счётчик попыток остаются общими: их читает шлюз ДО выбора
/// пространства, и именно по ним это пространство выбирается.
class SerializedSecureStorage extends FlutterSecureStorage {
  const SerializedSecureStorage({
    super.iOptions,
    super.aOptions,
    super.lOptions,
    super.wOptions,
    super.webOptions,
    super.mOptions,
  });

  static Future<void> _tail = Future<void>.value();

  /// Префикс ключей активного пространства профиля; пусто для `main`.
  static String spacePrefix = '';

  /// Ключи, общие для всех пространств (см. комментарий класса).
  static const List<String> globalKeyPrefixes = <String>[
    'secretly/app_lock_secret_v1',
    'secretly/lock_attempts_v1',
  ];

  static bool isGlobalKey(String key) {
    for (final prefix in globalKeyPrefixes) {
      if (key == prefix || key.startsWith('$prefix/')) return true;
    }
    return false;
  }

  /// Ключ с учётом пространства.
  static String scopedKey(String key) =>
      spacePrefix.isEmpty || isGlobalKey(key) ? key : '$spacePrefix$key';

  /// Стирает ключи ПО СЫРЫМ именам, минуя префикс пространства. Нужно
  /// стиранию пространства, которое не является активным.
  static Future<void> deleteRawKeysWhere(bool Function(String rawKey) test) {
    const storage = SerializedSecureStorage();
    return _queued(() async {
      final all = await storage._readAllRaw();
      for (final k in all.keys.toList(growable: false)) {
        if (!test(k)) continue;
        await storage._deleteRaw(k);
      }
    });
  }

  Future<Map<String, String>> _readAllRaw() => super.readAll();

  Future<void> _deleteRaw(String rawKey) => super.delete(key: rawKey);

  /// Очередь нужна там, где хранилище — один файл на все секреты.
  static bool get serializes =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<T> _queued<T>(Future<T> Function() op) {
    if (!serializes) return op();
    final result = _tail.then((_) => op());
    // Сбой одной операции не должен останавливать следующие.
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _queued(
    () => super.write(
      key: scopedKey(key),
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _queued(
    () => super.read(
      key: scopedKey(key),
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _queued(
    () => super.containsKey(
      key: scopedKey(key),
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _queued(
    () => super.delete(
      key: scopedKey(key),
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );

  /// В пространстве обманки видны только её ключи (без префикса в именах) и
  /// общие; секреты настоящего профиля наружу не выдаются.
  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _queued(() async {
    final all = await super.readAll(
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
    final prefix = spacePrefix;
    if (prefix.isEmpty) return all;
    final out = <String, String>{};
    all.forEach((k, v) {
      if (k.startsWith(prefix)) {
        out[k.substring(prefix.length)] = v;
      } else if (isGlobalKey(k)) {
        out[k] = v;
      }
    });
    return out;
  });

  /// В пространстве обманки стираются только её ключи. Общие (замок) и ключи
  /// настоящего профиля это не трогает.
  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _queued(() async {
    final prefix = spacePrefix;
    if (prefix.isEmpty) {
      await super.deleteAll(
        iOptions: iOptions,
        aOptions: aOptions,
        lOptions: lOptions,
        webOptions: webOptions,
        mOptions: mOptions,
        wOptions: wOptions,
      );
      return;
    }
    final all = await super.readAll(
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
    // Копия: реализация может отдать свою живую карту, а мы её меняем.
    for (final k in all.keys.toList(growable: false)) {
      if (!k.startsWith(prefix)) continue;
      await super.delete(
        key: k,
        iOptions: iOptions,
        aOptions: aOptions,
        lOptions: lOptions,
        webOptions: webOptions,
        mOptions: mOptions,
        wOptions: wOptions,
      );
    }
  });
}
