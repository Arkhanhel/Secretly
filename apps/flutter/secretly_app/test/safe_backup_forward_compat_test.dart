// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 КОПИЯ БОЛЕЕ НОВОЙ ВЕРСИИ (13.11.2026).
//
// Новая версия добавляет столбец или таблицу — её копия раньше не
// восстанавливалась на более старой сборке вовсе: один незнакомый столбец
// отвергал весь снимок. Теперь незнакомое отбрасывается, а известное
// восстанавливается. В базу по-прежнему попадает только разрешённое.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/restore_payload_validation.dart';
import 'package:secretly_app/storage/safe_backup_snapshot_contract.dart';

void main() {
  final knownTable = kSafeBackupSnapshotColumnsByTable.keys.firstWhere(
    (t) => t == 'group_members',
  );

  Map<String, List<Map<String, Object?>>> newerVersionSnapshot() => {
    knownTable: [
      {
        'group_id': 'g1',
        'member_profile_id': 'p1',
        'created_at_ms': 1,
        'column_from_the_future': 'x',
      },
    ],
    'table_from_the_future': [
      {'anything': 1},
    ],
  };

  test('незнакомые таблица и столбец не отвергают копию', () {
    expect(
      () => validateSafeBackupDbSnapshot(
        payloadName: 'test',
        dbSnapshot: newerVersionSnapshot(),
      ),
      returnsNormally,
    );
  });

  test('перед импортом незнакомое отбрасывается, известное остаётся', () {
    final out = sanitizeSafeBackupDbSnapshot(newerVersionSnapshot());
    expect(out.keys, [knownTable]);
    expect(out[knownTable]!.single, {
      'group_id': 'g1',
      'member_profile_id': 'p1',
      'created_at_ms': 1,
    });
  });

  test('форма снимка по-прежнему строгая', () {
    expect(
      () => validateSafeBackupDbSnapshot(
        payloadName: 'test',
        dbSnapshot: {knownTable: 'not a list'},
      ),
      throwsStateError,
    );
    expect(
      () => validateSafeBackupDbSnapshot(
        payloadName: 'test',
        dbSnapshot: {
          knownTable: ['not a row'],
        },
      ),
      throwsStateError,
    );
  });

  test('значения известных столбцов по-прежнему проверяются', () {
    expect(
      () => validateSafeBackupDbSnapshot(
        payloadName: 'test',
        dbSnapshot: {
          knownTable: [
            {
              'group_id': {'nested': 'map'},
            },
          ],
        },
      ),
      throwsStateError,
    );
  });
}
