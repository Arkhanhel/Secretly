// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

/// Zombie-handle recovery must heal every HOLDER of the database, not just the
/// controller's own reference (2026-07-31, field).
///
/// sqflite's singleInstance handle can be closed from under the app. The
/// watchdog used to recover by opening a fresh [AppDb] and replacing the
/// controller's field — but `RelayClient`, both ratchet session managers and
/// the outgoing scheduler each captured the AppDb at construction and keep it
/// for the life of the app. They kept querying the corpse: the inbound pump
/// logged `database_closed` once a second while the watchdog logged
/// `unexpected_closed_reopen_ok`, and messages, receipts and CALL SIGNALS
/// stopped being applied until the user killed the app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('db_zombie_reopen');
  });

  tearDown(() async {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('a closed database is detected by a REAL query, not by isOpen', () async {
    final db = await AppDb.openForTesting(path: '${tmp.path}/a.db');
    expect(await db.probeClosed(), isFalse);
    await db.close();
    expect(
      await db.probeClosed(),
      isTrue,
      reason: 'isOpen lies after a foreign close; probeClosed must not',
    );
  });

  test(
    'REGRESSION: adopting the reopened connection heals the SAME object every '
    'collaborator already holds',
    () async {
      final path = '${tmp.path}/b.db';
      final db = await AppDb.openForTesting(path: path);

      // Stand in for the long-lived collaborators (RelayClient, ratchet
      // managers, scheduler): they captured THIS object and never learn about
      // a replacement.
      final holder = db;

      await db.close();
      expect(await holder.probeClosed(), isTrue);

      // What the watchdog does: open a fresh handle, then adopt it in place.
      final fresh = await AppDb.openForTesting(path: path);
      holder.adoptConnectionFrom(fresh);

      expect(
        await holder.probeClosed(),
        isFalse,
        reason: 'the holder must be usable again without being re-created',
      );

      // And it must genuinely work, not merely stop throwing.
      await holder.localKvSet('zombie_probe', 'alive');
      expect(await holder.localKvGet('zombie_probe'), 'alive');

      await holder.close();
    },
  );

  test('adopting does not disturb a healthy database', () async {
    final path = '${tmp.path}/c.db';
    final db = await AppDb.openForTesting(path: path);
    await db.localKvSet('k', 'v1');

    final second = await AppDb.openForTesting(path: path);
    db.adoptConnectionFrom(second);

    expect(await db.probeClosed(), isFalse);
    expect(await db.localKvGet('k'), 'v1');
    await db.close();
  });
}
