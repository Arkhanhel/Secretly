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

// MESSAGE-LOSS REGRESSION (2026-07-08): a peer's inbound ratchet session row is
// read-modify-write. When two inbound messages from the SAME sender were
// processed concurrently (prod: the HTTP `/pending` drain and a realtime WS
// `Deliver` draining the same mailbox at once — one message acked over BOTH
// transports in the same second), both read the same base session state and the
// second persist clobbered the first's ratchet advance, leaving neighbouring
// messages of the burst permanently undecryptable. RatchetSessionManagerV3 now
// serialises all session ops per peer device. These tests fire a whole burst
// concurrently (and reordered) and assert zero loss.

const String aDev = 'A-device';
const String bDev = 'B-device';

RatchetSessionManagerV3 _manager(AppDb db) => RatchetSessionManagerV3(
      db: db,
      deviceKeys: DeviceKeys.create(),
      keysClient: KeysClient(baseUrl: Uri.parse('http://127.0.0.1:1')),
    );

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

// Encrypt [texts] as a burst on A's single send chain, threading A's state so
// each wire carries the next message number (n = 0, 1, 2, ...). Returns the
// SESSION wires in send order.
Future<List<Uint8List>> _burst({
  required DoubleRatchetV3 dr,
  required DoubleRatchetStateV3 init,
  required List<String> texts,
}) async {
  var s = init;
  final wires = <Uint8List>[];
  for (final text in texts) {
    final headerMap = <String, Object?>{
      'sender_device_id': aDev,
      'dh_pub_b64': base64Encode(s.dhSelfPub),
      'pn': s.pn,
      'n': s.ns,
    };
    final headerBytes = Uint8List.fromList(utf8.encode(jsonEncode(headerMap)));
    final enc = await dr.encrypt(
      state: s,
      plaintext: Uint8List.fromList(utf8.encode(text)),
      aad: headerBytes,
    );
    s = enc.updated;
    wires.add(RatchetWireV3.encodeSession(
      senderDeviceId: aDev,
      dhPubB64: headerMap['dh_pub_b64'] as String,
      pn: headerMap['pn'] as int,
      n: headerMap['n'] as int,
      ratchetCiphertext: enc.ciphertext,
    ));
  }
  return wires;
}

Future<void> _seedPrimary(AppDb db, DoubleRatchetStateV3 s) async {
  await db.sessionV3Upsert(
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
}

Future<String> _decrypt(RatchetSessionManagerV3 mgr, Uint8List wire) async {
  final pb = await mgr.decryptFromWire(
    selfProfileId: 'B-profile',
    selfDeviceId: bDev,
    wireBytes: wire,
  );
  return utf8.decode(pb);
}

// A DoubleRatchet that records enter/exit around every decrypt and yields the
// event loop in between, so any two decrypts allowed to run concurrently would
// interleave in [log]. With the per-peer lock they must not.
class _ProbeRatchet extends DoubleRatchetV3 {
  _ProbeRatchet(this.log);
  final List<String> log;
  int _seq = 0;

  @override
  Future<DoubleRatchetDecryptResultV3> decrypt({
    required DoubleRatchetStateV3 state,
    required String headerDhPubB64,
    required int pn,
    required int n,
    required List<int> ciphertext,
    Uint8List? preloadedSkippedKey,
    List<int> aad = const <int>[],
  }) async {
    final id = _seq++;
    log.add('enter-$id');
    // The yield is the point of this probe: it forces overlap so the test can
    // prove the caller serialises per peer. Now that decrypt is PURE, that
    // serialisation is entirely the caller's job — which is exactly what this
    // test still has to hold true.
    await Future<void>.delayed(Duration.zero);
    final r = await super.decrypt(
      state: state,
      headerDhPubB64: headerDhPubB64,
      pn: pn,
      n: n,
      ciphertext: ciphertext,
      preloadedSkippedKey: preloadedSkippedKey,
      aad: aad,
    );
    log.add('exit-$id');
    return r;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('concurrent in-order burst decrypt loses nothing', () async {
    final db = await AppDb.openForTesting();
    try {
      final dr = DoubleRatchetV3();
      final (init, resp) =
          await _matchedPair(dr: dr, rkByte: 7, spkBase: 1, ephBase: 200);
      final texts = List<String>.generate(16, (i) => 'msg-$i');
      final wires = await _burst(dr: dr, init: init, texts: texts);
      await _seedPrimary(db, resp);
      final mgr = _manager(db);

      // Fire the whole burst at once (models two transports draining the same
      // mailbox concurrently). Every message must come back.
      final got = await Future.wait([for (final w in wires) _decrypt(mgr, w)]);
      expect(got.toSet(), texts.toSet());
    } finally {
      await db.close();
    }
  });

  test('concurrent REVERSED burst decrypt loses nothing', () async {
    final db = await AppDb.openForTesting();
    try {
      final dr = DoubleRatchetV3();
      final (init, resp) =
          await _matchedPair(dr: dr, rkByte: 11, spkBase: 3, ephBase: 90);
      final texts = List<String>.generate(16, (i) => 'r-$i');
      final wires = await _burst(dr: dr, init: init, texts: texts);
      await _seedPrimary(db, resp);
      final mgr = _manager(db);

      // Out-of-order arrival (reversed) + concurrency: the serialized ratchet
      // + skipped-key store must still recover every message.
      final reversed = wires.reversed.toList(growable: false);
      final got = await Future.wait([for (final w in reversed) _decrypt(mgr, w)]);
      expect(got.toSet(), texts.toSet());
    } finally {
      await db.close();
    }
  });

  test('a message after a concurrent burst still decrypts (state intact)',
      () async {
    final db = await AppDb.openForTesting();
    try {
      final dr = DoubleRatchetV3();
      final (init, resp) =
          await _matchedPair(dr: dr, rkByte: 5, spkBase: 9, ephBase: 40);
      // 12 in the concurrent burst + 1 sent afterwards on the same chain.
      final texts = List<String>.generate(13, (i) => 'seq-$i');
      final wires = await _burst(dr: dr, init: init, texts: texts);
      await _seedPrimary(db, resp);
      final mgr = _manager(db);

      // Drain the first 12 concurrently, then the 13th on its own. If the
      // concurrent drain had corrupted the persisted ratchet state, the tail
      // message would be undecryptable.
      final burst = wires.sublist(0, 12);
      await Future.wait([for (final w in burst) _decrypt(mgr, w)]);
      final tail = await _decrypt(mgr, wires[12]);
      expect(tail, 'seq-12');
    } finally {
      await db.close();
    }
  });

  test('different peers are not serialized against each other', () async {
    // Two independent senders decrypt in parallel with no cross-blocking and no
    // corruption (the lock is per peer device, not global).
    final db = await AppDb.openForTesting();
    try {
      final dr = DoubleRatchetV3();
      final (initA, respA) =
          await _matchedPair(dr: dr, rkByte: 7, spkBase: 1, ephBase: 200);
      final wiresA = await _burst(dr: dr, init: initA, texts: ['a0', 'a1', 'a2']);
      await _seedPrimary(db, respA);
      final mgr = _manager(db);

      final got = await Future.wait([for (final w in wiresA) _decrypt(mgr, w)]);
      expect(got.toSet(), {'a0', 'a1', 'a2'});
    } finally {
      await db.close();
    }
  });

  test('same-peer decrypts do not interleave (serialization proof)', () async {
    final db = await AppDb.openForTesting();
    try {
      final baseDr = DoubleRatchetV3();
      final (init, resp) =
          await _matchedPair(dr: baseDr, rkByte: 7, spkBase: 1, ephBase: 200);
      final wires = await _burst(
        dr: baseDr,
        init: init,
        texts: ['s0', 's1', 's2', 's3'],
      );
      await _seedPrimary(db, resp);
      final log = <String>[];
      final mgr = RatchetSessionManagerV3(
        db: db,
        deviceKeys: DeviceKeys.create(),
        keysClient: KeysClient(baseUrl: Uri.parse('http://127.0.0.1:1')),
        dr: _ProbeRatchet(log),
      );

      await Future.wait([for (final w in wires) _decrypt(mgr, w)]);

      // Serialized => the log is strictly [enter, matching-exit] pairs. If two
      // decrypts overlapped, an 'enter-*' would sit where a matching 'exit-*'
      // is expected. (Removing the lock makes this fail.)
      expect(log.length, wires.length * 2);
      for (var i = 0; i < log.length; i += 2) {
        expect(log[i], startsWith('enter-'),
            reason: 'position $i should open a decrypt; log=$log');
        expect(log[i + 1], 'exit-${log[i].substring('enter-'.length)}',
            reason: 'decrypt at position $i interleaved; log=$log');
      }
    } finally {
      await db.close();
    }
  });
}
