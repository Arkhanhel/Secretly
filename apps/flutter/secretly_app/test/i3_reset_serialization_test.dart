// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ratchet/double_ratchet_v3.dart';
import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/ratchet/wire_v3.dart';
import 'package:secretly_app/security/device_keys.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/keys_client.dart';

/// И-3 (TZ_I3_SINGLE_WRITER_2026-07-21): every ratchet mutation for a peer —
/// decrypt, encrypt AND session reset — goes through the ONE per-peer lock, so
/// a reset can never interleave with a concurrent same-peer decrypt. The
/// controller used to call db.sessionV3Delete directly (outside the lock) from
/// the decrypt-failure handler and the forced-prekey path; resetSessionForPeer
/// closes that.
const String aDev = 'A-device';
const String bDev = 'B-device';

RatchetSessionManagerV3 _manager(AppDb db) => RatchetSessionManagerV3(
      db: db,
      deviceKeys: DeviceKeys.create(),
      keysClient: KeysClient(baseUrl: Uri.parse('http://127.0.0.1:1')),
    );

Future<(DoubleRatchetStateV3, DoubleRatchetStateV3)> _matchedPair(
    DoubleRatchetV3 dr) async {
  final x = X25519();
  final spk = await x.newKeyPairFromSeed(
    Uint8List.fromList(List<int>.generate(32, (i) => (1 + i) & 0xff)),
  );
  final spkPub = await spk.extractPublicKey();
  final eph = await x.newKeyPairFromSeed(
    Uint8List.fromList(List<int>.generate(32, (i) => (200 + i) & 0xff)),
  );
  final ephPub = await eph.extractPublicKey();
  final rk = Uint8List.fromList(List<int>.filled(32, 7));
  final init = await dr.initInitiator(
    peerDeviceId: bDev,
    rootKey: rk,
    handshakeEphKeyPair: eph,
    recipientSignedPrekeyPub: Uint8List.fromList(spkPub.bytes),
  );
  final resp = await dr.initResponder(
    peerDeviceId: aDev,
    rootKey: rk,
    recipientSignedPrekeyKeyPair: spk,
    initiatorDhPub: Uint8List.fromList(ephPub.bytes),
  );
  return (init, resp);
}

Future<Uint8List> _wire(
    DoubleRatchetV3 dr, DoubleRatchetStateV3 init, String text) async {
  final header = <String, Object?>{
    'sender_device_id': aDev,
    'dh_pub_b64': base64Encode(init.dhSelfPub),
    'pn': init.pn,
    'n': init.ns,
  };
  final hb = Uint8List.fromList(utf8.encode(jsonEncode(header)));
  final enc = await dr.encrypt(
      state: init, plaintext: Uint8List.fromList(utf8.encode(text)), aad: hb);
  return RatchetWireV3.encodeSession(
    senderDeviceId: aDev,
    dhPubB64: header['dh_pub_b64'] as String,
    pn: header['pn'] as int,
    n: header['n'] as int,
    ratchetCiphertext: enc.ciphertext,
  );
}

Future<void> _seed(AppDb db, DoubleRatchetStateV3 s) => db.sessionV3Upsert(
      peerDeviceId: s.peerDeviceId,
      rootKeyB64: base64Encode(s.rootKey),
      dhSelfSeedB64: base64Encode(s.dhSelfSeed),
      dhSelfPubB64: base64Encode(s.dhSelfPub),
      dhRemotePubB64:
          s.dhRemotePub == null ? null : base64Encode(s.dhRemotePub!),
      sendChainKeyB64:
          s.sendChainKey == null ? null : base64Encode(s.sendChainKey!),
      recvChainKeyB64:
          s.recvChainKey == null ? null : base64Encode(s.recvChainKey!),
      ns: s.ns,
      nr: s.nr,
      pn: s.pn,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Т-1: a reset fired concurrently with a decrypt for the same peer must
  // SERIALIZE — never interleave into a torn sessions_v3 row. We launch both
  // without awaiting between them; the per-peer lock orders them.
  test('reset and decrypt for the same peer serialize, no torn state',
      () async {
    final db = await AppDb.openForTesting();
    final dr = DoubleRatchetV3();
    final (init, resp) = await _matchedPair(dr);
    final wire = await _wire(dr, init, 'race-hello');
    await _seed(db, resp);
    final mgr = _manager(db);

    // Fire decrypt and reset concurrently for the SAME peer.
    final results = await Future.wait<Object?>([
      mgr
          .decryptFromWire(
            selfProfileId: 'B-profile',
            selfDeviceId: bDev,
            wireBytes: wire,
          )
          .then<Object?>((pb) => utf8.decode(pb))
          .catchError((Object e) => 'decrypt-failed'),
      mgr.resetSessionForPeer(aDev).then<Object?>((_) => 'reset-done'),
    ]);

    // Whatever the order, the outcome is deterministic and consistent:
    // - the row is either the advanced session (decrypt won the lock first) or
    //   absent (reset won) — but NEVER a half-written mix.
    final row = await db.sessionV3Get(aDev);
    if (row != null) {
      // If a session row exists it must be internally consistent (all columns
      // present) — a torn write would miss required fields.
      expect(row['root_key_b64'], isNotNull);
      expect(row['ns'], isNotNull);
      expect(row['nr'], isNotNull);
    }
    // Both ops completed (neither hung on the lock).
    expect(results.length, 2);
    expect(results, contains('reset-done'));
    await db.close();
  });

  // Т-2 regression: reset archives before delete, so a straggler under the old
  // session is still decryptable from the archive afterwards.
  test('reset archives the session before deleting it', () async {
    final db = await AppDb.openForTesting();
    final dr = DoubleRatchetV3();
    final (_, resp) = await _matchedPair(dr);
    await _seed(db, resp);
    final mgr = _manager(db);

    expect(await db.sessionV3Get(aDev), isNotNull);
    await mgr.resetSessionForPeer(aDev);

    // Live session gone...
    expect(await db.sessionV3Get(aDev), isNull);
    // ...but archived for straggler recovery.
    final archived = await db.sessionV3ArchiveList(aDev, limit: 3);
    expect(archived, isNotEmpty,
        reason: 'reset must archive before delete for straggler decrypt');
    await db.close();
  });

  // Т-2b: archiveFirst=false skips the archive (used where the caller does not
  // want straggler retention).
  test('resetSessionForPeer(archiveFirst: false) does not archive', () async {
    final db = await AppDb.openForTesting();
    final dr = DoubleRatchetV3();
    final (_, resp) = await _matchedPair(dr);
    await _seed(db, resp);
    final mgr = _manager(db);

    await mgr.resetSessionForPeer(aDev, archiveFirst: false);
    expect(await db.sessionV3Get(aDev), isNull);
    expect(await db.sessionV3ArchiveList(aDev, limit: 3), isEmpty);
    await db.close();
  });

  // Т-3: an empty peer id is a no-op (never creates an unserialized path).
  test('resetSessionForPeer("") is a safe no-op', () async {
    final db = await AppDb.openForTesting();
    final mgr = _manager(db);
    await mgr.resetSessionForPeer('');
    await mgr.resetSessionForPeer('   ');
    // No throw, nothing to assert beyond completion.
    await db.close();
  });
}
