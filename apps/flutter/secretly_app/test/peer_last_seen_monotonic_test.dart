// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/storage/app_db.dart';

// PRESENCE-LIE FIX R8 (2026-07-16, delivery-wake audit): peer last_seen is now
// stamped with the SENT time of inbound envelopes (not apply time), so a
// drained backlog applies rows whose activity timestamps are hours old and
// possibly out of order. That is only safe because the DB write is MONOTONIC —
// an older stamp must never regress a newer one. This test pins that property.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profileMetaUpdateLastSeen never regresses a newer stamp', () async {
    final db = await AppDb.openForTesting();
    try {
      const pid = 'PEER-profile';

      await db.profileMetaUpdateLastSeen(profileId: pid, lastSeenAtMs: 1000);
      expect(await db.profileMetaGetLastSeen(pid), 1000);

      // Newer stamp advances.
      await db.profileMetaUpdateLastSeen(profileId: pid, lastSeenAtMs: 5000);
      expect(await db.profileMetaGetLastSeen(pid), 5000);

      // Older stamp (out-of-order backlog row) must NOT regress.
      await db.profileMetaUpdateLastSeen(profileId: pid, lastSeenAtMs: 2000);
      expect(await db.profileMetaGetLastSeen(pid), 5000);

      // Equal stamp is a no-op, not an error.
      await db.profileMetaUpdateLastSeen(profileId: pid, lastSeenAtMs: 5000);
      expect(await db.profileMetaGetLastSeen(pid), 5000);
    } finally {
      await db.close();
    }
  });
}
