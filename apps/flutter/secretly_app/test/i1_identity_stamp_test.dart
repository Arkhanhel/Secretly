// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';

/// И-1 (TZ_I1_IDENTITY_2026-07-21): the database file carries a stamp of the
/// device identity it belongs to, and a file stamped by a ROTATED-AWAY
/// identity may keep its history but must shed its ratchet rows.
///
/// The scenario these tests pin: launch A loses the session store and rotates
/// device_id; launch B's second-chance rescue resurrects the quarantined
/// database. The events inside belong to the user — the sessions belong to
/// the dead device. Re-using them under the new identity would desync every
/// peer again, which is the exact class of bug И-1 exists to remove.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('local_kv stamp', () {
    test('round-trips and overwrites', () async {
      final db = await AppDb.openForTesting();
      expect(await db.localKvGet('own_device_id_v1'), isNull);
      await db.localKvSet('own_device_id_v1', 'device-a');
      expect(await db.localKvGet('own_device_id_v1'), 'device-a');
      await db.localKvSet('own_device_id_v1', 'device-b');
      expect(await db.localKvGet('own_device_id_v1'), 'device-b');
      await db.close();
    });
  });

  group('purgeRatchetStateForForeignIdentity', () {
    test('drops every ratchet surface but keeps history', () async {
      final db = await AppDb.openForTesting();

      // History that must survive the purge.
      await db.insertEvent(
        eventId: 'evt-1',
        convoId: 'peer-1',
        type: 'msg',
        senderDeviceId: 'peer-device-1',
        ciphertextB64: 'aGVsbG8=',
        createdAtMs: 1000,
      );

      // A live ratchet row agreed under the OLD identity.
      await db.sessionV3Upsert(
        peerDeviceId: 'peer-device-1',
        rootKeyB64: 'cm9vdA==',
        dhSelfSeedB64: 'c2VlZA==',
        dhSelfPubB64: 'c2VsZg==',
        dhRemotePubB64: 'cHVi',
        sendChainKeyB64: 'c2VuZA==',
        recvChainKeyB64: 'cmVjdg==',
        ns: 1,
        nr: 2,
        pn: 0,
      );
      // An undecryptable inbound parked for that identity.
      await db.inboxQuarantineUpsert(
        msgId: 'wire-1',
        senderDeviceId: 'peer-device-1',
        ciphertextB64: 'Y2lwaGVy',
        nowMs: 1000,
      );

      expect(await db.sessionV3Get('peer-device-1'), isNotNull);
      expect(await db.inboxQuarantineCountAll(), 1);
      expect(await db.countEvents(), 1);

      await db.purgeRatchetStateForForeignIdentity();

      expect(
        await db.sessionV3Get('peer-device-1'),
        isNull,
        reason: 'foreign sessions must not survive',
      );
      expect(
        await db.inboxQuarantineCountAll(),
        0,
        reason: 'ciphertext for the dead identity can never be applied',
      );
      expect(
        await db.countEvents(),
        1,
        reason: 'history belongs to the user, not the device identity',
      );
      await db.close();
    });

    test('purge then stamp is what a resurrected copy goes through', () async {
      final db = await AppDb.openForTesting();
      // The copy was stamped by the OLD identity...
      await db.localKvSet('own_device_id_v1', 'device-old');
      await db.sessionV3Upsert(
        peerDeviceId: 'peer-device-2',
        rootKeyB64: 'cm9vdA==',
        dhSelfSeedB64: 'c2VlZA==',
        dhSelfPubB64: 'c2VsZg==',
        dhRemotePubB64: null,
        sendChainKeyB64: null,
        recvChainKeyB64: null,
        ns: 0,
        nr: 0,
        pn: 0,
      );
      // ...the controller sees the mismatch, purges, and re-stamps.
      expect(await db.localKvGet('own_device_id_v1'), isNot('device-new'));
      await db.purgeRatchetStateForForeignIdentity();
      await db.localKvSet('own_device_id_v1', 'device-new');

      expect(await db.sessionV3Get('peer-device-2'), isNull);
      expect(await db.localKvGet('own_device_id_v1'), 'device-new');
      await db.close();
    });
  });
}
