// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

// Receipt re-emission after a session heal (2026-07-19, "one tick forever"):
// a flushed receipt wire deletes its pending_receipts rows atomically with
// entering the outbox, so a wire that dies in a session rotation dies WITH its
// receipt content. After the NACK-driven heal the sender re-emits receipt
// state from this query — it must pick exactly the peer's recent inbound
// events with their local read marks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recentInboundReceiptTargets picks inbound events with read marks',
      () async {
    final db = await AppDb.openForTesting();
    const self = 'my-device';
    const peer = 'peer-device';
    try {
      Future<void> put({
        required String id,
        required String sender,
        required String type,
        String? payloadEventId,
        int? readAtMs,
      }) => db.insertEvent(
            eventId: id,
            convoId: 'PEER-PROFILE',
            type: type,
            senderDeviceId: sender,
            ciphertextB64: 'AA==',
            createdAtMs: 1000,
            localState: 'received',
            payloadEventId: payloadEventId,
            readAtMs: readAtMs,
          );

      await put(id: 'in-read', sender: peer, type: 'msg',
          payloadEventId: 'p-read', readAtMs: 2000);
      await put(id: 'in-unread', sender: peer, type: 'att',
          payloadEventId: 'p-unread');
      // My OWN send must never earn a receipt back to the peer.
      await put(id: 'mine', sender: self, type: 'msg', payloadEventId: 'p-mine');
      // An inbound row without a payload id cannot be receipted.
      await put(id: 'no-payload', sender: peer, type: 'msg');

      final rows = await db.recentInboundReceiptTargets(
        convoId: 'PEER-PROFILE',
        selfDeviceId: self,
      );
      final byId = {
        for (final r in rows) r['payload_event_id'] as String: r['read_at_ms'],
      };
      expect(byId.keys.toSet(), {'p-read', 'p-unread'});
      expect((byId['p-read'] as num?)?.toInt(), 2000,
          reason: 'read mark drives a READ receipt');
      expect(((byId['p-unread'] as num?)?.toInt() ?? 0), 0,
          reason: 'no read mark → DELIVERED receipt');
    } finally {
      await db.close();
    }
  });
}
