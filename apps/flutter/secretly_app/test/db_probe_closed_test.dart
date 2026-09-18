// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

// ZOMBIE-DB (captured live on an iPhone 2026-07-23): every inbox pump died with
// DatabaseException(error_database_closed) in a tight loop while the self-heal
// watchdog stayed silent — because it gated on `db.isOpen`, which sqflite's
// singleInstance handle reports `true` even after the shared native handle was
// closed. probeClosed() must tell the truth by running a real query, so the
// watchdog can actually fire.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('probeClosed is false on a live DB, true after close', () async {
    final db = await AppDb.openForTesting();
    expect(await db.probeClosed(), isFalse, reason: 'a live DB is not closed');
    await db.close();
    // The whole point: after close, a real query throws error_database_closed,
    // and probeClosed reports it honestly — even where isOpen might not.
    expect(await db.probeClosed(), isTrue,
        reason: 'a closed DB must be detectable by a real probe');
  });
}
