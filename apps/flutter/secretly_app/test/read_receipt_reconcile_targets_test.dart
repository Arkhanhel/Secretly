// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

// 2026-07-23: a read receipt is one encrypted wire per message; when some die
// undecryptable with no NACK the peer stays stuck showing half our messages
// read. The reader-side backstop re-emits read state for a BOUNDED, recently-
// read set. These pin the two queries that scope it — the wrong scope would
// either miss stranded reads or turn reconciliation into a receipt storm.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const self = 'self-dev';
  const peer = 'peer-dev';
  const base = 1000000000000; // fixed clock; ms

  Future<void> addEvent(
    AppDb db, {
    required String id,
    required String convoId,
    required String senderDeviceId,
    int? readAtMs,
    String? payloadEventId,
    int? createdAtMs,
    String type = 'msg',
  }) => db.insertEvent(
    eventId: id,
    convoId: convoId,
    type: type,
    senderDeviceId: senderDeviceId,
    ciphertextB64: 'x',
    createdAtMs: createdAtMs ?? base,
    payloadEventId: payloadEventId ?? 'pe-$id',
    readAtMs: readAtMs,
  );

  test('convoIdsWithRecentInboundReads returns only 1:1 convos with recent reads',
      () async {
    final db = await AppDb.openForTesting();
    // Should match: inbound, read recently.
    await addEvent(db, id: 'a', convoId: 'peerA', senderDeviceId: peer, readAtMs: base + 5000);
    // Excluded: unread (read_at_ms null).
    await addEvent(db, id: 'b', convoId: 'peerB', senderDeviceId: peer, readAtMs: null);
    // Excluded: read too long ago (before the window).
    await addEvent(db, id: 'c', convoId: 'peerC', senderDeviceId: peer, readAtMs: base - 999999);
    // Excluded: group convo (room receipts, not per-row local_state).
    await addEvent(db, id: 'g', convoId: 'group:g1', senderDeviceId: peer, readAtMs: base + 5000);
    // Excluded: our OWN send (sender is self).
    await addEvent(db, id: 'd', convoId: 'peerD', senderDeviceId: self, readAtMs: base + 5000);

    final convos = await db.convoIdsWithRecentInboundReads(
      selfDeviceId: self,
      readAfterMs: base,
    );
    expect(convos, ['peerA']);
    await db.close();
  });

  test('recentReadReceiptTargets returns recent reads newest-first, unread excluded, capped',
      () async {
    final db = await AppDb.openForTesting();
    await addEvent(db, id: 'm1', convoId: 'peerA', senderDeviceId: peer, readAtMs: base + 1000, payloadEventId: 'p1');
    await addEvent(db, id: 'm2', convoId: 'peerA', senderDeviceId: peer, readAtMs: base + 2000, payloadEventId: 'p2');
    await addEvent(db, id: 'm3', convoId: 'peerA', senderDeviceId: peer, readAtMs: base + 3000, payloadEventId: 'p3');
    // Unread — must not appear.
    await addEvent(db, id: 'm4', convoId: 'peerA', senderDeviceId: peer, readAtMs: null, payloadEventId: 'p4');

    final all = await db.recentReadReceiptTargets(
      convoId: 'peerA',
      selfDeviceId: self,
      readAfterMs: base,
    );
    expect(all, ['p3', 'p2', 'p1'], reason: 'newest-read first, unread dropped');

    final capped = await db.recentReadReceiptTargets(
      convoId: 'peerA',
      selfDeviceId: self,
      readAfterMs: base,
      limit: 2,
    );
    expect(capped, ['p3', 'p2'], reason: 'hard cap keeps it from becoming a storm');
    await db.close();
  });
}
