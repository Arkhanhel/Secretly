// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

// Regression tests for the phantom-unread guards (release 1.4.3):
//  R1 — my own message arriving from another device, matched by profile id
//       before that device id is known as mine, is inserted already-read
//       (readAtMs) so it can never count as unread FOR ME.
//  R2 — a non-visible / future / control event is stored as type 'sys', which
//       the unread query excludes.
void main() {
  const self = 'my-self-device';

  test('own-send (read) and sys events never count as unread', () async {
    final db = await AppDb.openForTesting();
    try {
      const convoId = 'direct:alice';

      // A real incoming message from the peer — SHOULD count as unread.
      await db.insertEvent(
        eventId: 'm-visible',
        convoId: convoId,
        type: 'msg',
        senderDeviceId: 'peer-device',
        ciphertextB64: 'c1',
        createdAtMs: 10,
      );

      // R1: my own message from another device — its sender id is NOT yet in the
      // self-exclusion set, but readAtMs keeps it out of the unread count.
      await db.insertEvent(
        eventId: 'm-own-send',
        convoId: convoId,
        type: 'msg',
        senderDeviceId: 'my-other-device-not-yet-known',
        ciphertextB64: 'c2',
        createdAtMs: 11,
        localState: 'sent',
        readAtMs: 11,
      );

      // R2: a non-visible / future control event, classified 'sys'.
      await db.insertEvent(
        eventId: 'm-sys',
        convoId: convoId,
        type: 'sys',
        senderDeviceId: 'peer-device',
        ciphertextB64: 'c3',
        createdAtMs: 12,
      );

      expect(
        await db.countUnreadForConvo(convoId: convoId, selfDeviceId: self),
        1,
        reason: 'only the one real visible incoming message is unread',
      );
      expect(
        await db.countUnreadForConvos(
          convoIds: const <String>[convoId],
          selfDeviceId: self,
        ),
        <String, int>{convoId: 1},
      );
    } finally {
      await db.close();
    }
  });

  test('control: without the R1 read guard the same own-send WOULD phantom', () async {
    final db = await AppDb.openForTesting();
    try {
      const convoId = 'direct:bob';
      // Identical own-send row but WITHOUT readAtMs — reproduces the phantom the
      // R1 guard prevents (unread appears though nobody sent me anything).
      await db.insertEvent(
        eventId: 'm-own-noguard',
        convoId: convoId,
        type: 'msg',
        senderDeviceId: 'my-other-device-not-yet-known',
        ciphertextB64: 'c',
        createdAtMs: 5,
        localState: 'sent',
      );
      expect(
        await db.countUnreadForConvo(convoId: convoId, selfDeviceId: self),
        1,
        reason: 'demonstrates the phantom that readAtMs closes',
      );
    } finally {
      await db.close();
    }
  });
}
