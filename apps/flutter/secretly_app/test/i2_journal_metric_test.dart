// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

/// И-2c (TZ_I2_ATOMICITY_2026-07-21): the journal rescue is now a countable
/// field metric (local_kv counter surfaced in deliveryHealthCounters), so the
/// residual advance→event-insert gap the journal covers can be watched with
/// data rather than log-grep.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local_kv counter increments monotonically and surfaces in health',
      () async {
    final db = await AppDb.openForTesting();

    expect(await db.localKvCounterGet('i2_journal_recovered'), 0);

    await db.localKvCounterInc('i2_journal_recovered');
    await db.localKvCounterInc('i2_journal_recovered');
    await db.localKvCounterInc('i2_journal_recovered');
    expect(await db.localKvCounterGet('i2_journal_recovered'), 3);

    final health = await db.deliveryHealthCounters();
    expect(health['journal_recovered_total'], 3);

    await db.close();
  });

  test('counter is independent per key', () async {
    final db = await AppDb.openForTesting();
    await db.localKvCounterInc('a');
    await db.localKvCounterInc('b');
    await db.localKvCounterInc('a');
    expect(await db.localKvCounterGet('a'), 2);
    expect(await db.localKvCounterGet('b'), 1);
    // A key that was set as a non-numeric string never crashes the reader.
    await db.localKvSet('own_device_id_v1', 'device-xyz');
    expect(await db.localKvCounterGet('own_device_id_v1'), 0);
    await db.close();
  });
}
