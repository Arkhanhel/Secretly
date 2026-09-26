// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'secure_storage_options.dart';

import 'package:secretly_app/diagnostics/diag_log.dart';
import 'serialized_secure_storage.dart';

/// Штатный пропуск переноса на платформах, где его смысла нет.
class SkipKeychainMigration implements Exception {
  const SkipKeychainMigration();
}

/// Э-4 (SEC-02): перевод секретов iOS на `first_unlock_this_device`.
///
/// ЧТО ЧИНИМ. Все секреты писались с `KeychainAccessibility.first_unlock` —
/// вариантом БЕЗ пометки «этому устройству». Такие записи Apple переносит на
/// новое устройство вместе с резервной копией, а среди них лежит
/// `secretly/db_passphrase_v1` — пароль базы SQLCipher, то есть ключ ко всей
/// переписке. Наша же модель безопасности привязана к УСТРОЙСТВУ: номер
/// безопасности принадлежит устройству, новое устройство обязано выглядеть
/// новым. Ключи, переезжающие через резервную копию, эту привязку подрывают —
/// и делают это незаметно для собеседника.
///
/// Момент доступности при этом не меняется: оба варианта открываются после
/// первой разблокировки, отличается только запрет переноса. Данные переносить
/// нам не нужно — для смены телефона есть собственный recovery kit.
///
/// 🔴 ЧЕМ ЭТО ОПАСНО. Смена атрибута у существующей записи невозможна одним
/// обновлением: пакет удаляет запись и создаёт заново. Между удалением и
/// созданием есть промежуток, и если приложение убьют именно там (iOS убивает
/// по памяти охотно), **пароль базы исчезнет безвозвратно вместе со всей
/// перепиской**. Ровно эта авария была 19.07.2026.
///
/// Поэтому каждый ключ переносится через страховочную копию: при обрыве в любой
/// момент значение остаётся минимум в одном месте, а следующий запуск
/// достраивает начатое.
class KeychainAccessibilityMigration {
  KeychainAccessibilityMigration({
    FlutterSecureStorage? storage,
    this.onEvent,
    FlutterSecureStorage? legacyStorage,
  }) : _storage =
           storage ??
           const SerializedSecureStorage(
             aOptions: kSecretlyAndroidStorageOptions,
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
             mOptions: MacOsOptions(
               useDataProtectionKeyChain: false,
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
           ),
       _legacyStorage =
           legacyStorage ??
           const SerializedSecureStorage(
             aOptions: kSecretlyAndroidStorageOptions,
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock,
             ),
             mOptions: MacOsOptions(
               useDataProtectionKeyChain: false,
               accessibility: KeychainAccessibility.first_unlock,
             ),
           );

  final FlutterSecureStorage _storage;

  /// 🔴 Отдельный экземпляр со СТАРЫМ атрибутом — только для перечисления.
  ///
  /// В отличие от чтения по ключу, перечисление в Keychain **фильтрует по
  /// атрибуту доступности** (`readAll` передаёт его в запрос, `read` — нет).
  /// Перечисление новым хранилищем вернуло бы пустой список и объявило, что
  /// переносить нечего: миграция «прошла бы» и не сделала ничего.
  final FlutterSecureStorage _legacyStorage;

  /// Для наблюдения в тестах: (ключ, исход).
  final void Function(String key, String outcome)? onEvent;

  /// Суффикс страховочной копии. Копия живёт считаные миллисекунды, но при
  /// обрыве остаётся до следующего запуска и служит источником восстановления.
  static const _backupSuffix = '__mig_tdo_v1';

  /// Все наши ключи лежат под этим префиксом — включая те, у которых в конце
  /// стоит идентификатор профиля или устройства
  /// (`secretly/profile_secret_v1_b64/<pid>`, `secretly/device_keys_v1/...`).
  /// Поэтому список строится перечислением, а не перечнем имён: перечень молча
  /// пропустил бы всё, что с суффиксом.
  static const keyPrefix = 'secretly/';

  /// Пароль базы. Переносится ПОСЛЕДНИМ.
  static const dbPassphraseKey = 'secretly/db_passphrase_v1';

  /// 🔴 ПОРЯДОК ИМЕЕТ ЗНАЧЕНИЕ: от наименее ценного к наиболее ценному.
  ///
  /// Пароль базы идёт последним — к моменту, когда очередь доходит до него,
  /// механизм уже отработал на остальных ключах в этом же запуске. Если он
  /// ломается, ломается на чём-то, что можно пересоздать, а не на ключе ко всей
  /// переписке.
  static List<String> orderKeys(Iterable<String> keys) {
    final rest = <String>{};
    final last = <String>{};
    for (final k in keys) {
      // 🔴 Страховочная копия — это СЛЕД ОБОРВАННОГО ПЕРЕНОСА, а не мусор.
      //
      // После обрыва в опасной точке оригинала может не быть вовсе: значение
      // живёт только в копии. Если выбросить копии из списка (как делала первая
      // редакция этого метода), базовый ключ в обход не попадёт, восстановление
      // не запустится — и значение останется в копии навсегда, а оригинал будет
      // потерян. Для пароля базы это потеря всей переписки.
      //
      // Поэтому по копии восстанавливаем ИМЯ оригинала и кладём в обход именно
      // его. Дефект нашёл тест `обрыв на перезаписи оригинала НЕ теряет пароль`.
      final base = k.endsWith(_backupSuffix)
          ? k.substring(0, k.length - _backupSuffix.length)
          : k;
      if (!base.startsWith(keyPrefix)) continue;
      (base == dbPassphraseKey ? last : rest).add(base);
    }
    final ordered = rest.toList()..sort();
    return [...ordered, ...last];
  }

  /// Сколько записей ВСЁ ЕЩЁ лежит со старым атрибутом.
  ///
  /// 🔴 Это и есть проверка результата, которой требует И-4, — прямое
  /// наблюдение вместо флага «миграция выполнена». Работает потому, что
  /// перечисление в Keychain фильтрует по атрибуту доступности: хранилище со
  /// старым атрибутом видит ТОЛЬКО непере­несённые записи. Ноль здесь означает,
  /// что переносить больше нечего, а не что код отработал.
  Future<int> remainingLegacyCount() async => (await discover()).length;

  /// Перечислить ключи, которые ещё лежат со старым атрибутом.
  Future<List<String>> discover() async {
    try {
      final all = await _legacyStorage.readAll();
      return orderKeys(all.keys);
    } catch (_) {
      return const <String>[];
    }
  }

  /// Перенести все ключи. Возвращает число успешно перенесённых.
  ///
  /// Идемпотентна: повторный запуск на уже перенесённых ключах безвреден —
  /// перечисление старым хранилищем их уже не увидит.
  Future<int> run({List<String>? keys}) async {
    final list = keys ?? await discover();
    if (list.isEmpty) return 0;
    var migrated = 0;
    // Сначала достраиваем то, что могло оборваться в прошлый раз.
    for (final key in list) {
      await _recoverIfInterrupted(key);
    }
    for (final key in list) {
      if (await _migrateOne(key)) migrated++;
    }
    return migrated;
  }

  /// Восстановление после обрыва: копия есть, а оригинала нет.
  ///
  /// Обратный случай (есть оригинал, есть копия) безопасен — копию просто
  /// уберёт обычный проход.
  Future<void> _recoverIfInterrupted(String key) async {
    final backupKey = '$key$_backupSuffix';
    String? backup;
    try {
      backup = await _storage.read(key: backupKey);
    } catch (_) {
      return; // хранилище не готово — трогать нечего
    }
    if (backup == null || backup.isEmpty) return;

    String? original;
    try {
      original = await _storage.read(key: key);
    } catch (_) {
      return;
    }
    if (original != null && original.isNotEmpty) return; // обрыва не было

    try {
      await _storage.write(key: key, value: backup);
      final check = await _storage.read(key: key);
      if (check == backup) {
        await _storage.delete(key: backupKey);
        _emit(key, 'recovered');
      }
    } catch (_) {
      // Копию НЕ удаляем: пока оригинал не восстановлен, она — единственный
      // экземпляр значения.
      _emit(key, 'recover_failed');
    }
  }

  Future<bool> _migrateOne(String key) async {
    final backupKey = '$key$_backupSuffix';

    String? value;
    try {
      value = await _storage.read(key: key);
    } catch (_) {
      // 🔴 И-2: отказ чтения — это «не готово», а НЕ «ключа нет». Выходим, не
      // трогая ничего; следующий запуск попробует снова.
      _emit(key, 'read_failed');
      return false;
    }
    if (value == null || value.isEmpty) {
      _emit(key, 'absent');
      return false;
    }

    // 1) Страховочная копия с НУЖНЫМ атрибутом.
    try {
      await _storage.write(key: backupKey, value: value);
      final copy = await _storage.read(key: backupKey);
      if (copy != value) {
        await _storage.delete(key: backupKey);
        _emit(key, 'backup_mismatch');
        return false;
      }
    } catch (_) {
      _emit(key, 'backup_failed');
      return false;
    }

    // 2) Перезапись оригинала. Пакет сам снимет старую запись по всем уровням
    //    доступности и создаст новую с нужным атрибутом.
    try {
      await _storage.write(key: key, value: value);
      final check = await _storage.read(key: key);
      if (check != value) {
        // Оригинал испорчен — возвращаем из копии и уходим.
        await _storage.write(key: key, value: value);
        _emit(key, 'verify_failed');
        return false;
      }
    } catch (_) {
      _emit(key, 'write_failed');
      return false;
    }

    // 3) Значение на месте и с нужным атрибутом — копия больше не нужна.
    try {
      await _storage.delete(key: backupKey);
    } catch (_) {
      // Копия останется до следующего запуска. Не потеря, а мусор.
    }
    _emit(key, 'migrated');
    return true;
  }

  void _emit(String key, String outcome) {
    onEvent?.call(key, outcome);
    // Имя ключа — не секрет, значение не пишем никогда.
    DiagLog.event('keychain', 'migrate', {'key': key, 'outcome': outcome});
  }
}
