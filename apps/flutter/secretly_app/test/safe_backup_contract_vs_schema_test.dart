// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/storage/safe_backup_snapshot_contract.dart';

// 🔴 КОНТРАКТ ПРОТИВ НАСТОЯЩЕЙ СХЕМЫ (09.08.2026).
//
// Этого теста не было, и именно поэтому опечатка уехала на телефон: я вписал в
// контракт `sha` вместо `sha256_b64`, потому что вытаскивал имена столбцов
// регуляркой без цифр. Копия перестала СОЗДАВАТЬСЯ — человек не мог сделать
// резервную копию вовсе.
//
// Прежние тесты сверяли контракт САМ С СОБОЙ: что у каждой таблицы есть список
// столбцов, что исключения не пересекаются с разрешёнными. Ни один не мог поймать
// имя, которого в базе нет, — потому что базу они не открывали.
//
// Здесь контракт сверяется с ЖИВОЙ схемой в обе стороны.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Set<String>> columnsOf(AppDb db, String table) async {
    final rows = await db.rawQueryForTesting('PRAGMA table_info($table);');
    return rows
        .map((r) => ((r['name'] as String?) ?? '').trim())
        .where((n) => n.isNotEmpty)
        .toSet();
  }

  // 🔴 ЧЕГО ЗДЕСЬ НАМЕРЕННО НЕТ: проверки «каждый столбец контракта существует в
  // базе». Я её написал, и она сразу «нашла» `profile_meta.cover_path` — а его в
  // боевой базе ДОБАВЛЯЕТ лечащая функция `_ensureProfileMetaColumns` при каждом
  // открытии. `openForTesting` этих лечений не запускает, то есть тестовая схема
  // НЕ авторитетна для вопроса «есть ли столбец у людей», и такая проверка врала
  // бы про боевое состояние.
  //
  // Гарантию даёт проверка ниже, и она сильнее: она смотрит с той стороны, с
  // которой ломается копия. Мёртвая запись в контракте безвредна (экспорт её
  // никогда не прочитает), а вот столбец базы БЕЗ решения обрушивает создание
  // копии — именно это и случилось с `sha256_b64`.

  test('🔴 каждый столбец базы РЕШЁН: разрешён либо исключён', () async {
    // Обратная сторона: новый столбец, про который забыли решить, обрушит
    // создание копии у людей. Пусть падает здесь, а не у них.
    final db = await AppDb.openForTesting();
    try {
      for (final table in kSafeBackupSnapshotTables) {
        final actual = await columnsOf(db, table);
        final allowed = kSafeBackupSnapshotColumnsByTable[table] ?? const <String>{};
        final excluded =
            kSafeBackupSnapshotExcludedColumnsByTable[table] ?? const <String>{};
        final undecided = actual.difference(allowed).difference(excluded);
        expect(
          undecided,
          isEmpty,
          reason:
              'в $table есть столбцы без решения: $undecided — внесите их в '
              'разрешённые либо в исключённые',
        );
      }
    } finally {
      await db.close();
    }
  });

  test('исключённые столбцы тоже существуют в базе', () async {
    // Иначе исключение мёртвое: оно никогда не применится и будет врать, что мы
    // что-то не переносим.
    final db = await AppDb.openForTesting();
    try {
      for (final entry in kSafeBackupSnapshotExcludedColumnsByTable.entries) {
        final actual = await columnsOf(db, entry.key);
        for (final column in entry.value) {
          expect(actual, contains(column), reason: '${entry.key}.$column');
        }
      }
    } finally {
      await db.close();
    }
  });
}
