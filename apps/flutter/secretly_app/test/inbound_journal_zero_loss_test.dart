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
import 'package:sqflite_common/sqlite_api.dart' show DatabaseExecutor;
import 'package:secretly_app/transport/keys_client.dart';

// ZERO-LOSS inbound journal (2026-07-12).
//
// ROOT CAUSE these tests pin down: `RatchetSessionManagerV3.decryptFromWire`
// consumes the in-order message key and PERSISTS the advanced ratchet the moment
// a wire decrypts, but the plaintext is stored much later by the caller — after
// an awaited device->profile network lookup. On a deep-sleep first wake the OS
// suspends/kills the app in that gap: the ratchet is advanced+saved (message key
// gone) while the plaintext is never stored. The relay re-offers the un-acked
// ciphertext, but it is now PERMANENTLY undecryptable — a genuine MAC failure —
// so it is acked + quarantined + lost. The push preview still showed the text,
// hence "notification arrives but message missing".
//
// The fix: `decryptFromWire` calls `onPlaintextBeforeCommit` INSIDE the per-peer
// lock, immediately BEFORE persisting the advanced ratchet, so the caller can
// durably journal the plaintext. Invariant: "ratchet advanced past a wire => its
// plaintext is journaled". A kill anywhere after that is recovered from the
// journal; a kill/throw before it leaves the ratchet un-advanced for a clean
// re-decrypt. Either way: no message is ever lost.

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

// Encrypt [texts] as a burst on A's single send chain (n = 0, 1, 2, ...).
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

Future<int?> _persistedNr(AppDb db, {DatabaseExecutor? txn}) async {
  final row = await db.sessionV3Get(aDev, txn: txn);
  return (row?['nr'] as num?)?.toInt();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('onPlaintextBeforeCommit runs BEFORE the ratchet advance is persisted',
      () async {
    final db = await AppDb.openForTesting();
    try {
      final dr = DoubleRatchetV3();
      final (init, resp) =
          await _matchedPair(dr: dr, rkByte: 7, spkBase: 1, ephBase: 200);
      final wires = await _burst(dr: dr, init: init, texts: ['hello-deep-sleep']);
      await _seedPrimary(db, resp);
      final mgr = _manager(db);

      String? seenPlaintext;
      String? seenSender;
      int? nrAtCallback;
      final pb = await mgr.decryptFromWire(
        selfProfileId: 'B-profile',
        selfDeviceId: bDev,
        wireBytes: wires[0],
        onPlaintextBeforeCommit: (plaintext, sdev, txn) async {
          seenPlaintext = utf8.decode(plaintext);
          seenSender = sdev;
          // The persisted ratchet must still be at its pre-decrypt position
          // here: the plaintext is captured strictly BEFORE the advance commits.
          nrAtCallback = await _persistedNr(db, txn: txn);
        },
      );

      expect(utf8.decode(pb), 'hello-deep-sleep');
      expect(seenPlaintext, 'hello-deep-sleep');
      expect(seenSender, aDev);
      expect(nrAtCallback, 0, reason: 'ratchet must not be advanced yet');
      // After decrypt returns, the advance is durable.
      expect(await _persistedNr(db), 1);
    } finally {
      await db.close();
    }
  });

  test(
      'killed after decrypt: ciphertext is undecryptable on redelivery, but the '
      'plaintext survives in the journal (the exact deep-sleep loss, now recoverable)',
      () async {
    final db = await AppDb.openForTesting();
    try {
      final dr = DoubleRatchetV3();
      final (init, resp) =
          await _matchedPair(dr: dr, rkByte: 9, spkBase: 5, ephBase: 111);
      final wires = await _burst(dr: dr, init: init, texts: ['the-lost-sms']);
      await _seedPrimary(db, resp);
      final mgr = _manager(db);

      const msgId = 'msg-abc-123';

      // First delivery: decrypt succeeds; the hook durably journals the
      // plaintext before the ratchet advance commits. Then simulate a deep-sleep
      // KILL by doing nothing else (no apply, no ack) — exactly the prod gap.
      await mgr.decryptFromWire(
        selfProfileId: 'B-profile',
        selfDeviceId: bDev,
        wireBytes: wires[0],
        onPlaintextBeforeCommit: (plaintext, sdev, txn) async {
          await db.inboundJournalPut(
            msgId: msgId,
            senderDeviceId: sdev,
            plaintextB64: base64Encode(plaintext),
            createdAtMs: 1000,
            txn: txn,
          );
        },
      );

      // Redelivery of the SAME wire now fails permanently: the message key was
      // consumed and the ratchet cannot rewind. This is the bug's mechanism —
      // server redelivery is futile once the ratchet advanced.
      await expectLater(
        mgr.decryptFromWire(
          selfProfileId: 'B-profile',
          selfDeviceId: bDev,
          wireBytes: wires[0],
        ),
        throwsA(anything),
        reason: 'consumed message key => ciphertext is undecryptable on retry',
      );

      // ...but the plaintext is safe in the journal, so `_handleDelivered` can
      // recover it instead of quarantining. THIS is the zero-loss guarantee.
      final j = await db.inboundJournalGet(msgId);
      expect(j, isNotNull);
      final recovered =
          utf8.decode(base64Decode((j!['plaintext_b64'] as String)));
      expect(recovered, 'the-lost-sms');
      expect(j['sender_device_id'], aDev);
    } finally {
      await db.close();
    }
  });

  test('journal-write failure does NOT advance the ratchet: clean re-decrypt',
      () async {
    final db = await AppDb.openForTesting();
    try {
      final dr = DoubleRatchetV3();
      final (init, resp) =
          await _matchedPair(dr: dr, rkByte: 3, spkBase: 8, ephBase: 60);
      final wires = await _burst(dr: dr, init: init, texts: ['retry-me']);
      await _seedPrimary(db, resp);
      final mgr = _manager(db);

      // The hook throws (models a disk/DB write failure). The ratchet must NOT
      // advance, so the same wire re-decrypts cleanly — never a silent gap.
      await expectLater(
        mgr.decryptFromWire(
          selfProfileId: 'B-profile',
          selfDeviceId: bDev,
          wireBytes: wires[0],
          onPlaintextBeforeCommit: (plaintext, sdev, txn) async {
            throw StateError('simulated journal write failure');
          },
        ),
        throwsA(anything),
      );
      expect(await _persistedNr(db), 0,
          reason: 'ratchet must stay put when capture fails');

      // Clean retry, no failing hook: succeeds with the correct plaintext.
      final pb = await mgr.decryptFromWire(
        selfProfileId: 'B-profile',
        selfDeviceId: bDev,
        wireBytes: wires[0],
      );
      expect(utf8.decode(pb), 'retry-me');
      expect(await _persistedNr(db), 1);
    } finally {
      await db.close();
    }
  });

  test('inbound_journal CRUD + prune', () async {
    final db = await AppDb.openForTesting();
    try {
      await db.inboundJournalPut(
        msgId: 'm1',
        senderDeviceId: 'devX',
        plaintextB64: base64Encode(utf8.encode('p1')),
        createdAtMs: 100,
      );
      // replace-on-conflict keeps a single row per msg_id.
      await db.inboundJournalPut(
        msgId: 'm1',
        senderDeviceId: 'devX',
        plaintextB64: base64Encode(utf8.encode('p1b')),
        createdAtMs: 150,
      );
      final got = await db.inboundJournalGet('m1');
      expect(utf8.decode(base64Decode(got!['plaintext_b64'] as String)), 'p1b');
      expect(await db.inboundJournalCountAll(), 1);

      await db.inboundJournalPut(
        msgId: 'm2',
        senderDeviceId: null,
        plaintextB64: base64Encode(utf8.encode('p2')),
        createdAtMs: 100,
      );
      expect(await db.inboundJournalCountAll(), 2);

      // Prune ages out old orphans only.
      final pruned = await db.inboundJournalPrune(olderThanMs: 120);
      expect(pruned, 1); // m2 (created 100) goes; m1 (created 150) stays.
      expect(await db.inboundJournalGet('m2'), isNull);
      expect(await db.inboundJournalGet('m1'), isNotNull);

      await db.inboundJournalDelete('m1');
      expect(await db.inboundJournalGet('m1'), isNull);
      expect(await db.inboundJournalCountAll(), 0);
    } finally {
      await db.close();
    }
  });
}
