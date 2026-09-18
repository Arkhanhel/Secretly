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

/// И-2 (TZ_I2_ATOMICITY_2026-07-21): applying one inbound wire — the ratchet
/// advance, its skipped-key mutations and the journaled plaintext — is ONE
/// sqlite transaction. A crash anywhere before commit rolls everything back,
/// so the relay's redelivery re-decrypts the SAME wire cleanly because
/// sessions_v3 was never advanced.
///
/// Before И-2 this test failed by construction: the ratchet advance was
/// persisted the instant decrypt succeeded, in its own auto-commit statement,
/// so a failure after it left the chain permanently advanced.
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
  final headerBytes = Uint8List.fromList(utf8.encode(jsonEncode(header)));
  final enc = await dr.encrypt(
    state: init,
    plaintext: Uint8List.fromList(utf8.encode(text)),
    aad: headerBytes,
  );
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

Future<int?> _nr(AppDb db) async =>
    ((await db.sessionV3Get(aDev))?['nr'] as num?)?.toInt();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Т-1 — the invariant: a crash AFTER the ratchet advanced but BEFORE the
  // apply finished must roll the advance back, so redelivery re-decrypts.
  test('a post-advance crash rolls the ratchet back; redelivery re-decrypts',
      () async {
    final db = await AppDb.openForTesting();
    final dr = DoubleRatchetV3();
    final (init, resp) = await _matchedPair(dr);
    final wire = await _wire(dr, init, 'atomic-hello');
    await _seed(db, resp);
    final mgr = _manager(db);

    expect(await _nr(db), 0, reason: 'seeded, unadvanced');

    // The apply "crashes" from inside the pre-commit hook — the same seam the
    // real journal write uses, i.e. after decrypt+advance, before commit.
    await expectLater(
      mgr.decryptFromWire(
        selfProfileId: 'B-profile',
        selfDeviceId: bDev,
        wireBytes: wire,
        onPlaintextBeforeCommit: (plaintext, sdev, txn) async {
          expect(utf8.decode(plaintext), 'atomic-hello');
          throw StateError('crash after advance, before commit');
        },
      ),
      throwsA(anything),
    );

    // THE ASSERTION И-2 exists for: the chain did NOT advance, because the
    // transaction rolled back. Pre-И-2 this was 1 (advance escaped).
    expect(await _nr(db), 0,
        reason: 'rolled back — the ratchet may not advance without the apply');

    // Redelivery of the very same wire now succeeds (the message key was never
    // consumed durably).
    final pb = await mgr.decryptFromWire(
      selfProfileId: 'B-profile',
      selfDeviceId: bDev,
      wireBytes: wire,
    );
    expect(utf8.decode(pb), 'atomic-hello');
    expect(await _nr(db), 1, reason: 'clean re-apply advanced once');
    await db.close();
  });

  // Т-4 — a FAILED decrypt must not leak orphan skipped keys. dr.decrypt writes
  // skipped keys mid-stream (before its AEAD verify); on a corrupt wire those
  // used to persist as orphans (and could burn a legit stored key). Now they
  // ride the same transaction and roll back with the failure.
  test('a failed decrypt leaves no orphan skipped keys', () async {
    final db = await AppDb.openForTesting();
    final dr = DoubleRatchetV3();
    final (init, resp) = await _matchedPair(dr);

    // Build a burst so wire #3 forces #1,#2 to be skipped-and-stored, then
    // corrupt #3's ciphertext so its AEAD verify fails AFTER the skips.
    var s = init;
    final wires = <Uint8List>[];
    for (var i = 0; i < 3; i++) {
      final header = <String, Object?>{
        'sender_device_id': aDev,
        'dh_pub_b64': base64Encode(s.dhSelfPub),
        'pn': s.pn,
        'n': s.ns,
      };
      final hb = Uint8List.fromList(utf8.encode(jsonEncode(header)));
      final enc = await dr.encrypt(
        state: s,
        plaintext: Uint8List.fromList(utf8.encode('m$i')),
        aad: hb,
      );
      s = enc.updated;
      final ct = Uint8List.fromList(enc.ciphertext);
      if (i == 2) ct[ct.length - 1] ^= 0xff; // corrupt the target wire
      wires.add(RatchetWireV3.encodeSession(
        senderDeviceId: aDev,
        dhPubB64: header['dh_pub_b64'] as String,
        pn: header['pn'] as int,
        n: header['n'] as int,
        ratchetCiphertext: ct,
      ));
    }
    await _seed(db, resp);
    final mgr = _manager(db);

    await expectLater(
      mgr.decryptFromWire(
        selfProfileId: 'B-profile',
        selfDeviceId: bDev,
        wireBytes: wires[2],
      ),
      throwsA(anything),
    );

    // No skipped keys survived the rolled-back failed decrypt, and the ratchet
    // did not advance.
    final skipped = await db.skippedKeyGet(
      peerDeviceId: aDev,
      dhPubB64: base64Encode(init.dhSelfPub),
      msgNum: 0,
    );
    expect(skipped, isNull, reason: 'orphan skipped key rolled back');
    expect(await _nr(db), 0, reason: 'failed decrypt did not advance');
    await db.close();
  });
}
