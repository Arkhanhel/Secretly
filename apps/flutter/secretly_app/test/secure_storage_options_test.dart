// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// SEC-03 (26.08.2026). Настройки Android для защищённого хранилища.
//
// 🔴 ПОЧЕМУ ЭТО СТОРОЖ, А НЕ ДОВЕРИЕ. Плагин держит все значения в ОДНОМ файле
// (`FlutterSecureStorage`), и метка использованного алгоритма там тоже одна на
// всех. Разойдись настройки хотя бы в одном месте — экземпляры начнут
// перешифровывать хранилище туда-обратно на каждом запуске: один видит
// «сохранено GCM, просят CBC», другой наоборот.
//
// Там лежит `secretly/db_passphrase_v1` — пароль базы SQLCipher. Лишнее окно
// отказа над ним не нужно.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 каждое хранилище создаётся с общими настройками Android', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      var from = 0;
      while (true) {
        final i = src.indexOf('FlutterSecureStorage(', from);
        if (i < 0) break;
        from = i + 1;
        // Заглядываем только в начало списка аргументов: настройки обязаны
        // стоять первыми, иначе поиск наткнётся на соседний конструктор.
        final head = src.substring(i, (i + 200).clamp(0, src.length));
        if (!head.contains('kSecretlyAndroidStorageOptions')) {
          offenders.add('${entity.path} (позиция $i)');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'здесь создаётся хранилище без общих настроек Android — '
          'разойдясь, они заставят плагин перешифровывать данные на каждом '
          'запуске: $offenders',
    );
  });

  test('🔴 шифрованное хранилище остаётся выключенным намеренно', () {
    // Не «забыли включить», а решение: `checkAndMigrateToEncrypted` переносит
    // ключи по одному и удаляет каждый из старого хранилища сразу, а
    // исключение цикла только пишет в журнал. Упало на середине — часть
    // ключей стёрта, и откат плагина возвращает в хранилище, где их нет.
    // Потеря `secretly/db_passphrase_v1` = вся переписка человека.
    //
    // Если решение изменится, менять придётся и этот тест — вместе с
    // собственной миграцией через копию-страховку, как в SEC-02 на iOS.
    final lines = File(
      'lib/security/secure_storage_options.dart',
    ).readAsLinesSync();
    // Пояснения отбрасываем: слово встречается там намеренно, и первый заход
    // этого теста поймал собственный комментарий вместо кода.
    final code = lines
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(
      code.contains('encryptedSharedPreferences'),
      isFalse,
      reason:
          'включение требует своей миграции с копией-страховкой, а не '
          'доверия к checkAndMigrateToEncrypted — см. '
          'docs/TZ_SEC03_ANDROID_STORAGE_2026-08-26.md',
    );
    // 🔴 26.08.2026: ОТКАЧЕНО. Смена шифра КЛЮЧА (OAEP) сломала живое
    // устройство — существующий ключ AndroidKeyStore выпущен под PKCS#1 и для
    // OAEP не годится. Значения вернулись к умолчанию плагина.
    expect(code, isNot(contains('AES_GCM_NoPadding')));
    expect(code, isNot(contains('RSA_ECB_OAEP')));
  });
}
