// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ПЕРЕНОС СЕКРЕТОВ НА «ТОЛЬКО ЭТО УСТРОЙСТВО» (SEC-02, этап Э-4).
//
// Что чинится: секреты писались с атрибутом БЕЗ пометки «этому устройству», и
// Apple переносит такие записи на новое устройство вместе с резервной копией.
// Среди них — пароль базы SQLCipher, то есть ключ ко всей переписке.
//
// 🔴 Чем опасен сам перенос: сменить атрибут у существующей записи одним
// обновлением нельзя — запись удаляется и создаётся заново. Между этими двумя
// действиями есть промежуток, и обрыв именно там означает потерю пароля базы
// вместе со всей перепиской (авария 19.07.2026).
//
// Поэтому здесь сторожится не «перенос случился», а «значение невозможно
// потерять»: тесты обрывают перенос в каждой опасной точке и требуют, чтобы
// значение осталось доступным.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/keychain_migration.dart';

/// Хранилище в памяти, умеющее ломаться в заданный момент.
class _FakeStorage implements FlutterSecureStorage {
  _FakeStorage(this.data);

  final Map<String, String> data;

  /// Сколько записей выполнить до того, как начать бросать.
  int failWritesAfter = -1;
  int _writes = 0;

  /// Ключи, чтение которых падает (временный сбой хранилища).
  final Set<String> unreadable = <String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (unreadable.contains(key)) throw StateError('keychain not ready');
    return data[key];
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
  }) async {
    if (failWritesAfter >= 0 && _writes >= failWritesAfter) {
      // Обрыв: запись НЕ состоялась. Настоящий пакет в этот момент уже мог
      // снять старую запись — самый опасный миг переноса.
      data.remove(key);
      throw StateError('interrupted');
    }
    _writes++;
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map<String, String>.from(data);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен в тесте');
}

void main() {
  const dbKey = KeychainAccessibilityMigration.dbPassphraseKey;

  test('пароль базы переносится ПОСЛЕДНИМ', () {
    final ordered = KeychainAccessibilityMigration.orderKeys([
      dbKey,
      'secretly/crypto_key_v1_b64',
      'secretly/profile_secret_v1_b64/PID',
    ]);
    expect(
      ordered.last,
      dbKey,
      reason: 'пароль базы переносится не последним — сбой механизма придётся '
          'на ключ ко всей переписке, а не на то, что можно пересоздать',
    );
    expect(ordered.length, 3);
  });

  test('ключи с идентификатором в конце тоже попадают в перенос', () {
    // Перечень имён молча пропустил бы их — отсюда перечисление.
    final ordered = KeychainAccessibilityMigration.orderKeys([
      'secretly/device_keys_v1/PID/DEV',
      'secretly/profile_secret_v1_b64/PID',
      'unrelated/other_app_key',
    ]);
    expect(ordered, contains('secretly/device_keys_v1/PID/DEV'));
    expect(ordered, contains('secretly/profile_secret_v1_b64/PID'));
    expect(
      ordered,
      isNot(contains('unrelated/other_app_key')),
      reason: 'перенос трогает чужие ключи',
    );
  });

  test('обычный перенос сохраняет значения', () async {
    final store = _FakeStorage({
      dbKey: 'db-passphrase-value',
      'secretly/crypto_key_v1_b64': 'content-key-value',
    });
    final migration = KeychainAccessibilityMigration(
      storage: store,
      legacyStorage: store,
    );

    final moved = await migration.run();
    expect(moved, 2);
    expect(store.data[dbKey], 'db-passphrase-value');
    expect(store.data['secretly/crypto_key_v1_b64'], 'content-key-value');
    // Страховочных копий после успеха остаться не должно.
    expect(store.data.keys.where((k) => k.contains('__mig')), isEmpty);
  });

  test('🔴 обрыв на перезаписи оригинала НЕ теряет пароль базы', () async {
    final store = _FakeStorage({dbKey: 'db-passphrase-value'});
    // Первая запись (страховочная копия) проходит, вторая — обрыв.
    store.failWritesAfter = 1;
    final migration = KeychainAccessibilityMigration(
      storage: store,
      legacyStorage: store,
    );

    await migration.run();

    // Оригинала нет — обрыв случился ровно в опасной точке. Значение обязано
    // сохраниться в страховочной копии.
    final surviving = store.data.values.where(
      (v) => v == 'db-passphrase-value',
    );
    expect(
      surviving,
      isNotEmpty,
      reason: '🔴 значение исчезло полностью — это потеря всей переписки',
    );

    // Следующий запуск обязан достроить начатое.
    store.failWritesAfter = -1;
    await KeychainAccessibilityMigration(
      storage: store,
      legacyStorage: store,
    ).run();
    expect(
      store.data[dbKey],
      'db-passphrase-value',
      reason: 'после перезапуска пароль базы не восстановлен из копии',
    );
  });

  test('временный сбой чтения не трогает ключ', () async {
    // И-2: отказ чтения — это «не готово», а НЕ «ключа нет».
    final store = _FakeStorage({dbKey: 'db-passphrase-value'})
      ..unreadable.add(dbKey);
    final outcomes = <String, String>{};
    final migration = KeychainAccessibilityMigration(
      storage: store,
      legacyStorage: store,
      onEvent: (k, o) => outcomes[k] = o,
    );

    final moved = await migration.run();
    expect(moved, 0);
    expect(outcomes[dbKey], 'read_failed');
    expect(
      store.data[dbKey],
      'db-passphrase-value',
      reason: 'ключ стёрт из-за временного сбоя чтения',
    );
  });

  test('повторный запуск безвреден', () async {
    final store = _FakeStorage({dbKey: 'db-passphrase-value'});
    final migration = KeychainAccessibilityMigration(
      storage: store,
      legacyStorage: store,
    );
    await migration.run();
    await migration.run();
    expect(store.data[dbKey], 'db-passphrase-value');
  });
}
