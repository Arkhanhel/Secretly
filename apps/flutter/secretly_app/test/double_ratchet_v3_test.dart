// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ratchet/double_ratchet_v3.dart';


/// Mirrors production `decryptWithSkippedTxn` (session_manager_v3): pre-load
/// the ONE key that could apply, run the now-PURE ratchet, then apply what it
/// asked for. Kept here so the tests exercise the same order the app does.
Future<DoubleRatchetDecryptResultV3> decWith(
  DoubleRatchetV3 dr,
  Map<String, Uint8List> store, {
  required DoubleRatchetStateV3 state,
  required String headerDhPubB64,
  required int pn,
  required int n,
  required List<int> ciphertext,
  List<int> aad = const <int>[],
}) async {
  String key(String dh, int num) => '${state.peerDeviceId}|$dh|$num';
  final d = await dr.decrypt(
    state: state,
    headerDhPubB64: headerDhPubB64,
    pn: pn,
    n: n,
    ciphertext: ciphertext,
    preloadedSkippedKey: store[key(headerDhPubB64, n)],
    aad: aad,
  );
  if (d.consumedPreloadedKey) store.remove(key(headerDhPubB64, n));
  for (final r in d.skippedToStore) {
    store[key(r.dhPubB64, r.msgNum)] = r.messageKey;
  }
  return d;
}

void main() {
  test('v1.3: responder can decrypt initiator first message (prekey-derived state)', () async {
    final dr = DoubleRatchetV3();

    final x = X25519();
    final spkSeed = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final spk = await x.newKeyPairFromSeed(spkSeed);
    final spkPub = await spk.extractPublicKey();

    final ephSeed = Uint8List.fromList(List<int>.generate(32, (i) => 200 - i));
    final eph = await x.newKeyPairFromSeed(ephSeed);
    final ephPub = await eph.extractPublicKey();

    // Shared root key (pretend it came from X3DH). Must match on both sides.
    final rk = Uint8List.fromList(List<int>.generate(32, (i) => 7));

    var init = await dr.initInitiator(
      peerDeviceId: 'B',
      rootKey: rk,
      handshakeEphKeyPair: eph,
      recipientSignedPrekeyPub: Uint8List.fromList(spkPub.bytes),
    );
    var resp = await dr.initResponder(
      peerDeviceId: 'A',
      rootKey: rk,
      recipientSignedPrekeyKeyPair: spk,
      initiatorDhPub: Uint8List.fromList(ephPub.bytes),
    );

    final store = <String, Uint8List>{};

    final enc = await dr.encrypt(state: init, plaintext: utf8.encode('hello'));
    init = enc.updated;

    final dec = await decWith(
      dr,
      store,
      state: resp,
      headerDhPubB64: enc.dhPubB64,
      pn: enc.pn,
      n: enc.n,
      ciphertext: enc.ciphertext,
    );
    resp = dec.updated;

    expect(utf8.decode(dec.plaintext), 'hello');
    expect(init.ns, 1);
    expect(resp.nr, 1);
  });

  test('v1.3: out-of-order within a chain is decryptable via skipped keys', () async {
    final dr = DoubleRatchetV3(maxSkip: 50);

    final x = X25519();
    final spkSeed = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
    final spk = await x.newKeyPairFromSeed(spkSeed);
    final spkPub = await spk.extractPublicKey();

    final ephSeed = Uint8List.fromList(List<int>.generate(32, (i) => 100 + i));
    final eph = await x.newKeyPairFromSeed(ephSeed);
    final ephPub = await eph.extractPublicKey();

    final rk = Uint8List.fromList(List<int>.generate(32, (i) => 9));

    var init = await dr.initInitiator(
      peerDeviceId: 'B',
      rootKey: rk,
      handshakeEphKeyPair: eph,
      recipientSignedPrekeyPub: Uint8List.fromList(spkPub.bytes),
    );
    var resp = await dr.initResponder(
      peerDeviceId: 'A',
      rootKey: rk,
      recipientSignedPrekeyKeyPair: spk,
      initiatorDhPub: Uint8List.fromList(ephPub.bytes),
    );

    final store = <String, Uint8List>{};

    final e0 = await dr.encrypt(state: init, plaintext: utf8.encode('m0'));
    init = e0.updated;
    final e1 = await dr.encrypt(state: init, plaintext: utf8.encode('m1'));
    init = e1.updated;
    final e2 = await dr.encrypt(state: init, plaintext: utf8.encode('m2'));
    init = e2.updated;

    // Deliver m2 first.
    final d2 = await decWith(
      dr,
      store,
      state: resp,
      headerDhPubB64: e2.dhPubB64,
      pn: e2.pn,
      n: e2.n,
      ciphertext: e2.ciphertext,
    );
    resp = d2.updated;
    expect(utf8.decode(d2.plaintext), 'm2');

    // Now deliver m0 and m1 out of order; they should be in skipped store.
    final d0 = await decWith(
      dr,
      store,
      state: resp,
      headerDhPubB64: e0.dhPubB64,
      pn: e0.pn,
      n: e0.n,
      ciphertext: e0.ciphertext,
    );
    expect(utf8.decode(d0.plaintext), 'm0');

    final d1 = await decWith(
      dr,
      store,
      state: resp,
      headerDhPubB64: e1.dhPubB64,
      pn: e1.pn,
      n: e1.n,
      ciphertext: e1.ciphertext,
    );
    expect(utf8.decode(d1.plaintext), 'm1');
  });

  test('PURE contract: skipped keys are RETURNED, never written by the ratchet',
      () async {
    // The ratchet used to write these itself through a callback. It no longer
    // can — that callback is what pinned the maths to the UI isolate. Anything
    // it wants persisted must come back in the result.
    final dr = DoubleRatchetV3();
    final (init0, resp0) = await _pair(dr);
    var init = init0;
    var resp = resp0;

    // Send three, deliver only the THIRD: the receiver must ratchet past two.
    final e0 = await dr.encrypt(state: init, plaintext: utf8.encode('a'));
    init = e0.updated;
    final e1 = await dr.encrypt(state: init, plaintext: utf8.encode('b'));
    init = e1.updated;
    final e2 = await dr.encrypt(state: init, plaintext: utf8.encode('c'));
    init = e2.updated;

    final untouched = <String, Uint8List>{};
    final d2 = await dr.decrypt(
      state: resp,
      headerDhPubB64: e2.dhPubB64,
      pn: e2.pn,
      n: e2.n,
      ciphertext: e2.ciphertext,
      aad: const <int>[],
    );
    resp = d2.updated;

    expect(utf8.decode(d2.plaintext), 'c');
    expect(
      d2.skippedToStore.length,
      2,
      reason: 'the two messages it ratcheted past must be handed back',
    );
    expect(d2.skippedToStore.map((r) => r.msgNum), containsAll(<int>[0, 1]));
    expect(d2.consumedPreloadedKey, isFalse);
    expect(
      untouched,
      isEmpty,
      reason: 'a pure ratchet writes to nothing at all',
    );
  });

  test('PURE contract: a pre-loaded key opens the wire and reports itself used',
      () async {
    final dr = DoubleRatchetV3();
    final (init0, resp0) = await _pair(dr);
    var init = init0;

    final e0 = await dr.encrypt(state: init, plaintext: utf8.encode('first'));
    init = e0.updated;
    final e1 = await dr.encrypt(state: init, plaintext: utf8.encode('second'));
    init = e1.updated;

    // Receive the SECOND first — that derives and returns a key for the first.
    final d1 = await dr.decrypt(
      state: resp0,
      headerDhPubB64: e1.dhPubB64,
      pn: e1.pn,
      n: e1.n,
      ciphertext: e1.ciphertext,
    );
    final forFirst = d1.skippedToStore.firstWhere((r) => r.msgNum == e0.n);

    // Now the straggler, opened with the key the caller kept for it.
    final d0 = await dr.decrypt(
      state: d1.updated,
      headerDhPubB64: e0.dhPubB64,
      pn: e0.pn,
      n: e0.n,
      ciphertext: e0.ciphertext,
      preloadedSkippedKey: forFirst.messageKey,
    );

    expect(utf8.decode(d0.plaintext), 'first');
    expect(
      d0.consumedPreloadedKey,
      isTrue,
      reason: 'single-use: the caller must be told to delete it, or the same '
          'ciphertext could be opened twice',
    );
    expect(d0.skippedToStore, isEmpty);
  });
}

/// A matched initiator/responder pair over a fixed root key.
Future<(DoubleRatchetStateV3, DoubleRatchetStateV3)> _pair(
  DoubleRatchetV3 dr,
) async {
  final eph = await dr.newDhKeyPair();
  final spk = await dr.newDhKeyPair();
  final spkPub = await spk.extractPublicKey();
  final ephPub = await eph.extractPublicKey();
  final rk = Uint8List.fromList(List<int>.generate(32, (i) => 7));
  final init = await dr.initInitiator(
    peerDeviceId: 'peer',
    rootKey: rk,
    handshakeEphKeyPair: eph,
    recipientSignedPrekeyPub: Uint8List.fromList(spkPub.bytes),
  );
  final resp = await dr.initResponder(
    peerDeviceId: 'me',
    rootKey: rk,
    recipientSignedPrekeyKeyPair: spk,
    initiatorDhPub: Uint8List.fromList(ephPub.bytes),
  );
  return (init, resp);
}
