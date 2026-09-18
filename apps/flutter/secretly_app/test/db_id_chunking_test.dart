// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

/// ОТКАЗ, А НЕ ЗАМЕДЛЕНИЕ (найдено 02.09.2026 при аудите масштабирования).
///
/// Число параметров одного запроса ограничено `SQLITE_MAX_VARIABLE_NUMBER`:
/// 999 в сборках SQLite до 3.32 и 32766 в новых. Какая версия скомпилирована
/// внутри `sqflite_sqlcipher` на конкретном устройстве, приложение не
/// контролирует.
///
/// `_applyAutoDeleteRetention` собирает ВСЕ события чата старше отсечки — без
/// `limit` — и подставляет их одним списком в `IN (...)`. В чате, где под
/// автоудаление попала тысяча сообщений, запрос падал с
/// `too many SQL variables`: автоудаление переставало работать целиком.
///
/// Второй путь — `profileMetaGetForProfiles`, который `listContacts` зовёт со
/// ВСЕМИ контактами разом; там же в коде стоит комментарий про «large contact
/// books» и «up to 500».
void main() {
  group('порции идентификаторов', () {
    test('пустой список даёт пустой результат', () {
      expect(AppDb.chunkIds<String>(const []).toList(), isEmpty);
    });

    test('список короче предела остаётся одной порцией', () {
      final ids = List.generate(10, (i) => 'e$i');
      final chunks = AppDb.chunkIds(ids).toList();
      expect(chunks, hasLength(1));
      expect(chunks.single, equals(ids));
    });

    test('ровно предел — по-прежнему одна порция', () {
      final ids = List.generate(AppDb.idChunkSize, (i) => 'e$i');
      expect(AppDb.chunkIds(ids).toList(), hasLength(1));
    });

    test('на один больше предела — уже две порции', () {
      final ids = List.generate(AppDb.idChunkSize + 1, (i) => 'e$i');
      final chunks = AppDb.chunkIds(ids).toList();
      expect(chunks, hasLength(2));
      expect(chunks.first, hasLength(AppDb.idChunkSize));
      expect(chunks.last, hasLength(1));
    });

    test('тысяча событий — тот самый случай, что ронял автоудаление', () {
      final ids = List.generate(1000, (i) => 'event-$i');
      final chunks = AppDb.chunkIds(ids).toList();

      for (final chunk in chunks) {
        expect(
          chunk.length,
          lessThanOrEqualTo(AppDb.idChunkSize),
          reason: 'ни одна порция не должна превышать предел параметров SQLite',
        );
      }
      expect(
        chunks.expand((c) => c).toList(),
        equals(ids),
        reason: 'склейка порций обязана давать исходный список без потерь '
            'и без перестановок — иначе часть событий не удалится',
      );
    });

    test('предел с запасом относительно самой строгой сборки SQLite', () {
      expect(
        AppDb.idChunkSize,
        lessThan(999),
        reason: 'в сборках до SQLite 3.32 предел равен 999; берём с запасом, '
            'потому что версию внутри sqflite_sqlcipher мы не выбираем',
      );
    });
  });
}
