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

const String aDev = 'A-device';
const String bDev = 'B-device';

RatchetSessionManagerV3 _manager(AppDb db) => RatchetSessionManagerV3(
      db: db,
      deviceKeys: DeviceKeys.create(),
      // Never reached for SESSION-wire decryption / archiveCurrentSession.
      keysClient: KeysClient(baseUrl: Uri.parse('http://127.0.0.1:1')),
    );

// Build a matched initiator/responder pair sharing a root key, simulating the
// post-X3DH state. From A's perspective the peer is B (init.peerDeviceId == B);
// from B's perspective the peer is A (resp.peerDeviceId == A).
Future<(DoubleRatchetStateV3, DoubleRatchetStateV3)> _matchedPair({
  required DoubleRatchetV3 dr,
  required int rkByte,
  required int spkBase,
  required int ephBase,
}) async {
  final x = X25519();
  final spk = await x.newKeyPairFromSeed(
    Uint8List.fromList(List<int>.generate(32, (i) => (spkBase + i) & 0xff)),
  );
  final spkPub = await spk.extractPublicKey();
  final eph = await x.newKeyPairFromSeed(
    Uint8List.fromList(List<int>.generate(32, (i) => (ephBase + i) & 0xff)),
  );
  final ephPub = await eph.extractPublicKey();
  final rk = Uint8List.fromList(List<int>.filled(32, rkByte));

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

// Encrypt [text] with [init] and serialise it as a SESSION wire exactly the way
// RatchetSessionManagerV3.encryptToPeer does (header built from the pre-encrypt
// state, used as AAD), so RatchetSessionManagerV3.decryptFromWire accepts it.
Future<Uint8List> _sessionWire({
  required DoubleRatchetV3 dr,
  required DoubleRatchetStateV3 init,
  required String text,
}) async {
  final headerMap = <String, Object?>{
    'sender_device_id': aDev,
    'dh_pub_b64': base64Encode(init.dhSelfPub),
    'pn': init.pn,
    'n': init.ns,
  };
  final headerBytes = Uint8List.fromList(utf8.encode(jsonEncode(headerMap)));
  final enc = await dr.encrypt(
    state: init,
    plaintext: Uint8List.fromList(utf8.encode(text)),
    aad: headerBytes,
  );
  return RatchetWireV3.encodeSession(
    senderDeviceId: aDev,
    dhPubB64: headerMap['dh_pub_b64'] as String,
    pn: headerMap['pn'] as int,
    n: headerMap['n'] as int,
    ratchetCiphertext: enc.ciphertext,
  );
}

Map<String, Object?> _stateCols(DoubleRatchetStateV3 s) => <String, Object?>{
      'rootKeyB64': base64Encode(s.rootKey),
      'dhSelfSeedB64': base64Encode(s.dhSelfSeed),
      'dhSelfPubB64': base64Encode(s.dhSelfPub),
      'dhRemotePubB64':
          s.dhRemotePub == null ? null : base64Encode(s.dhRemotePub!),
      'sendChainKeyB64':
          s.sendChainKey == null ? null : base64Encode(s.sendChainKey!),
      'recvChainKeyB64':
          s.recvChainKey == null ? null : base64Encode(s.recvChainKey!),
      'ns': s.ns,
      'nr': s.nr,
      'pn': s.pn,
    };

Future<void> _seedPrimary(AppDb db, DoubleRatchetStateV3 s) async {
  final c = _stateCols(s);
  await db.sessionV3Upsert(
    peerDeviceId: s.peerDeviceId,
    rootKeyB64: c['rootKeyB64'] as String,
    dhSelfSeedB64: c['dhSelfSeedB64'] as String,
    dhSelfPubB64: c['dhSelfPubB64'] as String,
    dhRemotePubB64: c['dhRemotePubB64'] as String?,
    sendChainKeyB64: c['sendChainKeyB64'] as String?,
    recvChainKeyB64: c['recvChainKeyB64'] as String?,
    ns: c['ns'] as int,
    nr: c['nr'] as int,
    pn: c['pn'] as int,
  );
}

Future<void> _seedArchive(AppDb db, DoubleRatchetStateV3 s) async {
  final c = _stateCols(s);
  await db.sessionV3ArchivePush(
    peerDeviceId: s.peerDeviceId,
    rootKeyB64: c['rootKeyB64'] as String,
    dhSelfSeedB64: c['dhSelfSeedB64'] as String,
    dhSelfPubB64: c['dhSelfPubB64'] as String,
    dhRemotePubB64: c['dhRemotePubB64'] as String?,
    sendChainKeyB64: c['sendChainKeyB64'] as String?,
    recvChainKeyB64: c['recvChainKeyB64'] as String?,
    ns: c['ns'] as int,
    nr: c['nr'] as int,
    pn: c['pn'] as int,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('candidate session recovers a straggler the primary cannot decrypt',
      () async {
    final db = await AppDb.openForTesting();
    try {
      final dr = DoubleRatchetV3();
      final (init, correctResp) =
          await _matchedPair(dr: dr, rkByte: 7, spkBase: 1, ephBase: 200);
      final (_, wrongResp) =
          await _matchedPair(dr: dr, rkByte: 9, spkBase: 80, ephBase: 30);

      // A's straggler was encrypted under the CORRECT (rk=7) session.
      final wire = await _sessionWire(dr: dr, init: init, text: 'straggler');

      // B's live session is the WRONG one (e.g. overwritten by a later prekey),
      // while the correct one survives only in the candidate archive.
      await _seedPrimary(db, wrongResp);
      await _seedArchive(db, correctResp);

      final plain = await _manager(db).decryptFromWire(
        selfProfileId: 'B-profile',
        selfDeviceId: bDev,
        wireBytes: wire,
      );
      expect(utf8.decode(plain), 'straggler');
    } finally {
      await db.close();
    }
  });

  test('without the archive the same straggler is undecryptable (control)',
      () async {
    final db = await AppDb.openForTesting();
    try {
      final dr = DoubleRatchetV3();
      final (init, _) =
          await _matchedPair(dr: dr, rkByte: 7, spkBase: 1, ephBase: 200);
      final (_, wrongResp) =
          await _matchedPair(dr: dr, rkByte: 9, spkBase: 80, ephBase: 30);

      final wire = await _sessionWire(dr: dr, init: init, text: 'straggler');
      await _seedPrimary(db, wrongResp); // primary only, no archive

      await expectLater(
        _manager(db).decryptFromWire(
          selfProfileId: 'B-profile',
          selfDeviceId: bDev,
          wireBytes: wire,
        ),
        throwsA(isA<Object>()),
      );
    } finally {
      await db.close();
    }
  });

  test('primary happy path is unaffected (no archive consulted)', () async {
    final db = await AppDb.openForTesting();
    try {
      final dr = DoubleRatchetV3();
      final (init, correctResp) =
          await _matchedPair(dr: dr, rkByte: 7, spkBase: 1, ephBase: 200);

      final wire = await _sessionWire(dr: dr, init: init, text: 'hello');
      await _seedPrimary(db, correctResp); // correct primary, no archive

      final plain = await _manager(db).decryptFromWire(
        selfProfileId: 'B-profile',
        selfDeviceId: bDev,
        wireBytes: wire,
      );
      expect(utf8.decode(plain), 'hello');
    } finally {
      await db.close();
    }
  });

  test('archiveCurrentSession copies the live session and skips on same root',
      () async {
    final db = await AppDb.openForTesting();
    try {
      final dr = DoubleRatchetV3();
      final (_, resp) =
          await _matchedPair(dr: dr, rkByte: 7, spkBase: 1, ephBase: 200);
      await _seedPrimary(db, resp);

      final mgr = _manager(db);
      // No live session for a different peer -> no-op.
      await mgr.archiveCurrentSession('nobody');
      expect(await db.sessionV3ArchiveList('nobody'), isEmpty);

      // Archives the live session for aDev.
      await mgr.archiveCurrentSession(aDev);
      final archived = await db.sessionV3ArchiveList(aDev);
      expect(archived, hasLength(1));
      expect(archived.single['root_key_b64'], base64Encode(resp.rootKey));

      // Same replacement root -> skipped (no duplicate).
      await mgr.archiveCurrentSession(
        aDev,
        replacementRootKeyB64: base64Encode(resp.rootKey),
      );
      expect(await db.sessionV3ArchiveList(aDev), hasLength(1));
    } finally {
      await db.close();
    }
  });

  test('archive DAO: keepLast trims oldest, update + prune behave', () async {
    final db = await AppDb.openForTesting();
    try {
      Future<void> push(int rk) => db.sessionV3ArchivePush(
            peerDeviceId: aDev,
            rootKeyB64: 'root-$rk',
            dhSelfSeedB64: 'seed',
            dhSelfPubB64: 'pub',
            dhRemotePubB64: null,
            sendChainKeyB64: null,
            recvChainKeyB64: null,
            ns: 0,
            nr: 0,
            pn: 0,
            keepLast: 3,
          );
      for (final rk in [1, 2, 3, 4, 5]) {
        await push(rk);
      }
      final rows = await db.sessionV3ArchiveList(aDev, limit: 10);
      // Only the newest 3 survive, newest first.
      expect(
        rows.map((r) => r['root_key_b64']).toList(),
        orderedEquals(['root-5', 'root-4', 'root-3']),
      );

      // Update advances the newest slot.
      final newestId = (rows.first['id'] as num).toInt();
      await db.sessionV3ArchiveUpdate(
        id: newestId,
        dhSelfSeedB64: 'seed2',
        dhSelfPubB64: 'pub2',
        dhRemotePubB64: 'remote2',
        sendChainKeyB64: 'send2',
        recvChainKeyB64: 'recv2',
        ns: 5,
        nr: 6,
        pn: 7,
      );
      final updated = (await db.sessionV3ArchiveList(aDev)).first;
      expect((updated['ns'] as num).toInt(), 5);
      expect(updated['recv_chain_key_b64'], 'recv2');
      expect(updated['root_key_b64'], 'root-5'); // root unchanged

      // Prune by age removes everything older than the cutoff.
      final removed = await db.sessionV3ArchivePrune(
        olderThanMs: DateTime.now().millisecondsSinceEpoch + 1,
      );
      expect(removed, 3);
      expect(await db.sessionV3ArchiveList(aDev), isEmpty);
    } finally {
      await db.close();
    }
  });
}
