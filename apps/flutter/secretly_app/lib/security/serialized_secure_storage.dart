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
      key: key,
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
      key: key,
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
      key: key,
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
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _queued(
    () => super.readAll(
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _queued(
    () => super.deleteAll(
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );
}
