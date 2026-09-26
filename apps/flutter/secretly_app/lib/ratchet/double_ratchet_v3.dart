// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class DoubleRatchetStateV3 {
  const DoubleRatchetStateV3({
    required this.peerDeviceId,
    required this.rootKey,
    required this.dhSelfSeed,
    required this.dhSelfPub,
    required this.dhRemotePub,
    required this.sendChainKey,
    required this.recvChainKey,
    required this.ns,
    required this.nr,
    required this.pn,
  });

  final String peerDeviceId;
  final Uint8List rootKey;

  // X25519 keypair stored as seed + pub.
  final Uint8List dhSelfSeed;
  final Uint8List dhSelfPub;

  // Remote X25519 public key (current ratchet public key).
  final Uint8List? dhRemotePub;

  // Current chain keys (nullable until initialized).
  final Uint8List? sendChainKey;
  final Uint8List? recvChainKey;

  // Message numbers.
  final int ns;
  final int nr;
  final int pn;

  DoubleRatchetStateV3 copyWith({
    Uint8List? rootKey,
    Uint8List? dhSelfSeed,
    Uint8List? dhSelfPub,
    Uint8List? dhRemotePub,
    Uint8List? sendChainKey,
    Uint8List? recvChainKey,
    int? ns,
    int? nr,
    int? pn,
  }) {
    return DoubleRatchetStateV3(
      peerDeviceId: peerDeviceId,
      rootKey: rootKey ?? this.rootKey,
      dhSelfSeed: dhSelfSeed ?? this.dhSelfSeed,
      dhSelfPub: dhSelfPub ?? this.dhSelfPub,
      dhRemotePub: dhRemotePub ?? this.dhRemotePub,
      sendChainKey: sendChainKey ?? this.sendChainKey,
      recvChainKey: recvChainKey ?? this.recvChainKey,
      ns: ns ?? this.ns,
      nr: nr ?? this.nr,
      pn: pn ?? this.pn,
    );
  }
}

class DoubleRatchetEncryptResultV3 {
  const DoubleRatchetEncryptResultV3({
    required this.updated,
    required this.ciphertext,
    required this.dhPubB64,
    required this.pn,
    required this.n,
  });

  final DoubleRatchetStateV3 updated;
  final Uint8List ciphertext;
  final String dhPubB64;
  final int pn;
  final int n;
}

/// One message key the receiver derived while skipping FORWARD over messages
/// that have not arrived yet, so a straggler can still be opened later.
///
/// Returned to the caller rather than written from inside the ratchet — see
/// [DoubleRatchetV3.decrypt] for why that matters.
class SkippedKeyRecordV3 {
  const SkippedKeyRecordV3({
    required this.dhPubB64,
    required this.msgNum,
    required this.messageKey,
  });

  final String dhPubB64;
  final int msgNum;
  final Uint8List messageKey;
}

class DoubleRatchetDecryptResultV3 {
  const DoubleRatchetDecryptResultV3({
    required this.updated,
    required this.plaintext,
    this.skippedToStore = const <SkippedKeyRecordV3>[],
    this.consumedPreloadedKey = false,
  });

  final DoubleRatchetStateV3 updated;
  final Uint8List plaintext;

  /// Keys the caller must PERSIST — derived while ratcheting past messages that
  /// have not arrived yet. Empty on the common in-order path.
  ///
  /// Bounded by [DoubleRatchetV3.maxSkip] per skip loop, so this never grows
  /// unbounded however absurd a wire's counter claims to be — and, when
  /// [DoubleRatchetV3.maxStoredSkipped] is set, by that: only the NEWEST keys
  /// come back (П-3, 25.09.2026).
  final List<SkippedKeyRecordV3> skippedToStore;

  /// True when the message was opened with the pre-loaded skipped key, i.e.
  /// the caller must now DELETE that key: it is single-use, and leaving it
  /// behind would let the same ciphertext be opened twice.
  final bool consumedPreloadedKey;
}

// The three `SkippedKey*V3` callback typedefs that used to live here were
// DELETED on 2026-07-31 along with the impure `decrypt` that took them.
//
// They are not kept "just in case": their whole purpose was to let the ratchet
// reach into the database mid-computation, which is exactly what pins the
// heaviest maths in the app to the isolate that draws frames. Leaving the
// signatures behind would make it a one-line change to wire that path back in.
// If you find yourself wanting them, read the comment on [DoubleRatchetV3.decrypt]
// first — the caller pre-loads and post-applies now, on purpose.

class DoubleRatchetV3 {
  DoubleRatchetV3({
    Cipher? aead,
    Hkdf? hkdf,
    this.maxSkip = 200,
    this.maxStoredSkipped,
  })  : hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32),
        aead = aead ?? Xchacha20.poly1305Aead();

  final Hkdf hkdf;
  final Cipher aead;

  /// How far a wire's counter may run ahead of the chain, PER skip loop (there
  /// are two per wire: the old chain up to `pn`, the new one up to `n`).
  final int maxSkip;

  /// П-3 (25.09.2026): how many of the skipped keys one wire may hand back for
  /// storing — the NEWEST ones. The rest are still derived (the chain has to
  /// move past them) but not returned, so a long offline gap cannot flood the
  /// key table. `null` = no cap: exactly the behaviour before this field
  /// existed. Not "= maxSkip": with two loops a wire could already return up to
  /// twice that, and capping it would have changed what old builds store.
  final int? maxStoredSkipped;

  Future<SimpleKeyPair> newDhKeyPair() async {
    final seed = _randomBytes(32);
    return X25519().newKeyPairFromSeed(seed);
  }

  /// Initializes an initiator state after X3DH-like handshake.
  ///
  /// Uses the handshake ephemeral keypair as initial DHs, and uses recipient
  /// signed-prekey pub as initial DHr to derive the first sending chain.
  Future<DoubleRatchetStateV3> initInitiator({
    required String peerDeviceId,
    required Uint8List rootKey,
    required SimpleKeyPair handshakeEphKeyPair,
    required Uint8List recipientSignedPrekeyPub,
  }) async {
    final ephPub = await handshakeEphKeyPair.extractPublicKey();
    final dhSelfSeed = await _extractSeed32(handshakeEphKeyPair);

    final dhOut = await _kdfRk(
      rootKey: rootKey,
      dhOut: await _dh(handshakeEphKeyPair, recipientSignedPrekeyPub),
    );

    return DoubleRatchetStateV3(
      peerDeviceId: peerDeviceId,
      rootKey: dhOut.rootKey,
      dhSelfSeed: dhSelfSeed,
      dhSelfPub: Uint8List.fromList(ephPub.bytes),
      dhRemotePub: recipientSignedPrekeyPub,
      sendChainKey: dhOut.chainKey,
      recvChainKey: null,
      ns: 0,
      nr: 0,
      pn: 0,
    );
  }

  /// Initializes a responder state after receiving the initiator prekey message.
  ///
  /// Uses recipient signed-prekey keypair as initial DHs, and initiator
  /// handshake ephemeral pub as initial DHr to derive the first receiving chain.
  Future<DoubleRatchetStateV3> initResponder({
    required String peerDeviceId,
    required Uint8List rootKey,
    required SimpleKeyPair recipientSignedPrekeyKeyPair,
    required Uint8List initiatorDhPub,
  }) async {
    final spkPub = await recipientSignedPrekeyKeyPair.extractPublicKey();
    final dhSelfSeed = await _extractSeed32(recipientSignedPrekeyKeyPair);

    final dhOut = await _kdfRk(
      rootKey: rootKey,
      dhOut: await _dh(recipientSignedPrekeyKeyPair, initiatorDhPub),
    );

    return DoubleRatchetStateV3(
      peerDeviceId: peerDeviceId,
      rootKey: dhOut.rootKey,
      dhSelfSeed: dhSelfSeed,
      dhSelfPub: Uint8List.fromList(spkPub.bytes),
      dhRemotePub: initiatorDhPub,
      sendChainKey: null,
      recvChainKey: dhOut.chainKey,
      ns: 0,
      nr: 0,
      pn: 0,
    );
  }

  Future<DoubleRatchetEncryptResultV3> encrypt({
    required DoubleRatchetStateV3 state,
    required List<int> plaintext,
    List<int> aad = const <int>[],
  }) async {
    var s = state;

    // If no sending chain yet (responder), perform a DH ratchet step before first send.
    if (s.sendChainKey == null) {
      s = await _dhRatchetSend(s);
    }

    final chainKey = s.sendChainKey!;
    final mk = await _kdfMk(chainKey, s.ns);
    final nextCk = await _kdfCk(chainKey);

    final nonce = _randomBytes(24);
    final box = await aead.encrypt(
      plaintext,
      secretKey: SecretKey(mk),
      nonce: nonce,
      aad: aad,
    );

    final out = Uint8List(nonce.length + box.cipherText.length + box.mac.bytes.length);
    out.setRange(0, nonce.length, nonce);
    out.setRange(nonce.length, nonce.length + box.cipherText.length, box.cipherText);
    out.setRange(nonce.length + box.cipherText.length, out.length, box.mac.bytes);

    final updated = s.copyWith(
      sendChainKey: nextCk,
      ns: s.ns + 1,
    );

    return DoubleRatchetEncryptResultV3(
      updated: updated,
      ciphertext: out,
      dhPubB64: base64Encode(s.dhSelfPub),
      pn: s.pn,
      n: s.ns,
    );
  }

  /// Opens one wire. PURE: no database, no I/O, no callbacks.
  ///
  /// 🔴 WHY PURITY IS A REQUIREMENT AND NOT A STYLE CHOICE (2026-07-31).
  ///
  /// This used to take three callbacks (`loadSkipped`/`storeSkipped`/
  /// `deleteSkipped`) that each went to the database MID-COMPUTATION. That had
  /// two costs:
  ///
  ///  1. It cannot be moved off the UI isolate. Closures do not cross an
  ///     isolate boundary, so the heaviest maths in the app was pinned to the
  ///     thread that draws frames — which is what froze the UI for 9 s in the
  ///     field (ANR, 2026-07-31).
  ///  2. Skipped keys were written one at a time as the loop ran, so a failure
  ///     part-way left some of them persisted and some not.
  ///
  /// Now the caller pre-loads the ONE key that could apply, and everything the
  /// ratchet wants written comes back in the result. The caller applies it —
  /// inside its own transaction, all-or-nothing. The maths stays here, the
  /// state stays with the caller, and neither has to know about the other.
  ///
  /// [preloadedSkippedKey] is the key stored for exactly
  /// `(peerDeviceId, headerDhPubB64, n)`, or null when there is none. Passing
  /// the wrong one cannot corrupt anything: the AEAD tag simply fails.
  Future<DoubleRatchetDecryptResultV3> decrypt({
    required DoubleRatchetStateV3 state,
    required String headerDhPubB64,
    required int pn,
    required int n,
    required List<int> ciphertext,
    Uint8List? preloadedSkippedKey,
    List<int> aad = const <int>[],
  }) async {
    var s = state;
    final skippedToStore = <SkippedKeyRecordV3>[];

    // 1) A straggler we already derived a key for — open it and tell the
    //    caller to retire that key.
    if (preloadedSkippedKey != null) {
      final plain = await _aeadDecrypt(ciphertext, preloadedSkippedKey, aad);
      return DoubleRatchetDecryptResultV3(
        updated: s,
        plaintext: plain,
        consumedPreloadedKey: true,
      );
    }

    final headerDhPub = base64Decode(headerDhPubB64);

    // 2) If DH changed, perform a receiving ratchet.
    final curRemote = s.dhRemotePub;
    final dhChanged = curRemote == null || !_bytesEq(curRemote, headerDhPub);
    if (dhChanged) {
      s = await _skipMessageKeys(s, until: pn, out: skippedToStore);
      s = await _dhRatchetReceive(s, newRemoteDhPub: headerDhPub);
    }

    // 3) Skip within current receiving chain up to n.
    s = await _skipMessageKeys(s, until: n, out: skippedToStore);

    final ck = s.recvChainKey;
    if (ck == null) {
      throw StateError('missing recv chain key');
    }

    final mk = await _kdfMk(ck, s.nr);
    final plain = await _aeadDecrypt(ciphertext, mk, aad);
    final nextCk = await _kdfCk(ck);

    final updated = s.copyWith(
      recvChainKey: nextCk,
      nr: s.nr + 1,
    );

    final cap = maxStoredSkipped;
    return DoubleRatchetDecryptResultV3(
      updated: updated,
      plaintext: plain,
      // Only the tail: loops append in derivation order (old chain, then the
      // new one, each ascending), so the tail is the newest.
      skippedToStore: cap != null && cap >= 0 && skippedToStore.length > cap
          ? skippedToStore.sublist(skippedToStore.length - cap)
          : skippedToStore,
    );
  }

  Future<DoubleRatchetStateV3> _skipMessageKeys(
    DoubleRatchetStateV3 s, {
    required int until,
    required List<SkippedKeyRecordV3> out,
  }) async {
    if (s.recvChainKey == null) return s;
    if (until < s.nr) return s;
    if (until - s.nr > maxSkip) {
      throw StateError('too many skipped messages');
    }

    var ck = s.recvChainKey!;
    var nr = s.nr;
    final dhPubB64 = base64Encode(s.dhRemotePub ?? const <int>[]);

    while (nr < until) {
      final mk = await _kdfMk(ck, nr);
      out.add(
        SkippedKeyRecordV3(dhPubB64: dhPubB64, msgNum: nr, messageKey: mk),
      );
      ck = await _kdfCk(ck);
      nr++;
    }

    return s.copyWith(recvChainKey: ck, nr: nr);
  }

  Future<DoubleRatchetStateV3> _dhRatchetReceive(
    DoubleRatchetStateV3 s, {
    required Uint8List newRemoteDhPub,
  }) async {
    // Update root + recv chain based on DH(DHs, DHr).
    final dhSelf = await X25519().newKeyPairFromSeed(s.dhSelfSeed);
    final out = await _kdfRk(rootKey: s.rootKey, dhOut: await _dh(dhSelf, newRemoteDhPub));

    return s.copyWith(
      rootKey: out.rootKey,
      dhRemotePub: newRemoteDhPub,
      recvChainKey: out.chainKey,
      nr: 0,
      // send chain is not updated on receive; it will update on next send step.
    );
  }

  /// Ensure the state has a sending chain, performing the DH ratchet-send step
  /// now if it does not (e.g. a responder that has not sent yet). This must be
  /// called BEFORE building the wire header so the header's `dh_pub`/`pn`/`n`
  /// match what [encrypt] will actually use — otherwise [encrypt] ratchets
  /// internally and the header advertises a STALE `dh_pub`, making the message
  /// undecryptable for the peer. Idempotent: a no-op when a send chain exists.
  Future<DoubleRatchetStateV3> ensureSendChain(DoubleRatchetStateV3 s) async {
    if (s.sendChainKey != null) return s;
    return _dhRatchetSend(s);
  }

  Future<DoubleRatchetStateV3> _dhRatchetSend(DoubleRatchetStateV3 s) async {
    final x = X25519();
    final newSeed = _randomBytes(32);
    final newDh = await x.newKeyPairFromSeed(newSeed);
    final newPub = await newDh.extractPublicKey();

    final remote = s.dhRemotePub;
    if (remote == null) throw StateError('missing remote dh pub');

    final out = await _kdfRk(rootKey: s.rootKey, dhOut: await _dh(newDh, remote));

    return s.copyWith(
      rootKey: out.rootKey,
      dhSelfSeed: Uint8List.fromList(newSeed),
      dhSelfPub: Uint8List.fromList(newPub.bytes),
      sendChainKey: out.chainKey,
      pn: s.ns,
      ns: 0,
    );
  }

  Future<({Uint8List rootKey, Uint8List chainKey})> _kdfRk({
    required Uint8List rootKey,
    required Uint8List dhOut,
  }) async {
    // RK, CK = HKDF(dhOut, salt=RK, info=...)
    // We derive two 32-byte outputs with distinct info labels.
    final rk = await _hkdfBytes(secret: dhOut, salt: rootKey, info: 'secretly/dr/rk/v1/rk');
    final ck = await _hkdfBytes(secret: dhOut, salt: rootKey, info: 'secretly/dr/rk/v1/ck');
    return (rootKey: rk, chainKey: ck);
  }

  Future<Uint8List> _kdfCk(Uint8List chainKey) async {
    return _hkdfBytes(secret: chainKey, salt: const <int>[], info: 'secretly/dr/ck_step/v1');
  }

  Future<Uint8List> _kdfMk(Uint8List chainKey, int index) async {
    return _hkdfBytes(secret: chainKey, salt: const <int>[], info: 'secretly/dr/mk/v1/$index');
  }

  Future<Uint8List> _hkdfBytes({required List<int> secret, required List<int> salt, required String info}) async {
    final out = await hkdf.deriveKey(
      secretKey: SecretKey(secret),
      nonce: salt,
      info: utf8.encode(info),
    );
    return Uint8List.fromList(await out.extractBytes());
  }

  Future<Uint8List> _dh(SimpleKeyPair self, Uint8List remotePubBytes) async {
    final x = X25519();
    final remote = SimplePublicKey(remotePubBytes, type: KeyPairType.x25519);
    final ss = await x.sharedSecretKey(keyPair: self, remotePublicKey: remote);
    return Uint8List.fromList(await ss.extractBytes());
  }

  Future<Uint8List> _aeadDecrypt(List<int> ciphertext, Uint8List mk, List<int> aad) async {
    if (ciphertext.length < 24 + 16) throw StateError('ciphertext too short');
    final nonce = Uint8List.fromList(ciphertext.sublist(0, 24));
    final rest = ciphertext.sublist(24);
    if (rest.length < 16) throw StateError('ciphertext too short');
    final macBytes = Uint8List.fromList(rest.sublist(rest.length - 16));
    final ct = Uint8List.fromList(rest.sublist(0, rest.length - 16));
    final box = SecretBox(ct, nonce: nonce, mac: Mac(macBytes));
    final plain = await aead.decrypt(box, secretKey: SecretKey(mk), aad: aad);
    return Uint8List.fromList(plain);
  }
}

Uint8List _randomBytes(int n) {
  final r = Random.secure();
  final out = Uint8List(n);
  for (var i = 0; i < out.length; i++) {
    out[i] = r.nextInt(256);
  }
  return out;
}

bool _bytesEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Future<Uint8List> _extractSeed32(SimpleKeyPair keyPair) async {
  // cryptography SimpleKeyPair doesn't guarantee seed extractability;
  // in our usage we always create from seed.
  final data = await keyPair.extract();
  final bytes = data.bytes;
  if (bytes.length < 32) throw StateError('unexpected key material');
  return Uint8List.fromList(bytes.sublist(0, 32));
}
