// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// One-shot anonymous "sealed box" for the in-app Support channel (TZ
/// Variant C). It lets a user encrypt a
/// support message to the SUPPORT public key (whose private key lives ONLY in
/// the admin console — the server/relay store ciphertext only), and lets the
/// admin encrypt a reply back to the user's per-device support key.
///
/// This is deliberately NOT libsodium `crypto_box_seal` wire-compatible — it is
/// built from the same `package:cryptography` primitives the ratchet already
/// uses (X25519 + HKDF-SHA256 + XChaCha20-Poly1305), so BOTH ends (this Dart
/// app and the Dart admin console, which copies this file verbatim) must use
/// THIS construction. Do not "port to libsodium" on one side only.
///
/// Wire (then base64):  ephPub(32) ‖ nonce(24) ‖ ciphertext ‖ mac(16)
///
/// KDF: shared = X25519(eph_priv, recipient_pub); key = HKDF-SHA256(shared,
/// salt = ephPub‖recipientPub, info = "secretly/support/seal/v1", 32 bytes).
/// Binding the salt to both public keys domain-separates every (ephemeral,
/// recipient) pair.
class SupportSeal {
  SupportSeal._();

  static const String _info = 'secretly/support/seal/v1';
  static const int _keyLen = 32; // X25519 pub / priv-seed length
  static const int _ephPubLen = 32;
  static const int _nonceLen = 24; // XChaCha20 nonce
  static const int _macLen = 16; // Poly1305 tag

  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _aead = Xchacha20.poly1305Aead();

  /// Fresh X25519 keypair. Returns the 32-byte private SEED (store this) and
  /// the 32-byte public key (publish/attach this). Rebuild the pair anywhere
  /// with [publicKeyFromSeed] / the seed.
  static Future<({Uint8List privateSeed, Uint8List publicKey})>
      generateKeypair() async {
    final seed = _randomBytes(_keyLen);
    final pub = await publicKeyFromSeed(seed);
    return (privateSeed: seed, publicKey: pub);
  }

  /// The 32-byte X25519 public key for a 32-byte private [seed].
  static Future<Uint8List> publicKeyFromSeed(Uint8List seed) async {
    _requireLen(seed, _keyLen, 'private seed');
    final kp = await X25519().newKeyPairFromSeed(seed);
    final pub = await kp.extractPublicKey();
    return Uint8List.fromList(pub.bytes);
  }

  /// Seal [plaintext] to [recipientPublicKey] (32 raw X25519 bytes). Returns the
  /// base64 wire. Anonymous: the wire never reveals the sender's key.
  static Future<String> seal({
    required List<int> plaintext,
    required Uint8List recipientPublicKey,
  }) async {
    _requireLen(recipientPublicKey, _keyLen, 'recipient public key');
    final ephSeed = _randomBytes(_keyLen);
    final eph = await X25519().newKeyPairFromSeed(ephSeed);
    final ephPub =
        Uint8List.fromList((await eph.extractPublicKey()).bytes);

    final key = await _deriveKey(
      keyPair: eph,
      peerPublicKey: recipientPublicKey,
      ephPub: ephPub,
      recipientPub: recipientPublicKey,
    );

    final nonce = _randomBytes(_nonceLen);
    final box = await _aead.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final ct = box.cipherText;
    final mac = box.mac.bytes;

    final out = Uint8List(_ephPubLen + _nonceLen + ct.length + mac.length);
    var off = 0;
    out.setRange(off, off += _ephPubLen, ephPub);
    out.setRange(off, off += _nonceLen, nonce);
    out.setRange(off, off += ct.length, ct);
    out.setRange(off, off + mac.length, mac);
    return base64Encode(out);
  }

  /// Open [sealedB64] with the recipient's 32-byte private [recipientPrivateSeed].
  /// Throws on a malformed or tampered wire (Poly1305 auth failure).
  static Future<Uint8List> open({
    required String sealedB64,
    required Uint8List recipientPrivateSeed,
  }) async {
    _requireLen(recipientPrivateSeed, _keyLen, 'recipient private seed');
    final Uint8List wire;
    try {
      wire = base64Decode(sealedB64.trim());
    } on FormatException {
      throw const FormatException('support seal: not valid base64');
    }
    if (wire.length < _ephPubLen + _nonceLen + _macLen) {
      throw const FormatException('support seal: wire too short');
    }
    var off = 0;
    final ephPub = Uint8List.sublistView(wire, off, off += _ephPubLen);
    final nonce = Uint8List.sublistView(wire, off, off += _nonceLen);
    final ct = Uint8List.sublistView(wire, off, wire.length - _macLen);
    final mac = Uint8List.sublistView(wire, wire.length - _macLen);

    final kp = await X25519().newKeyPairFromSeed(recipientPrivateSeed);
    final recipientPub =
        Uint8List.fromList((await kp.extractPublicKey()).bytes);
    final key = await _deriveKey(
      keyPair: kp,
      peerPublicKey: ephPub,
      ephPub: ephPub,
      recipientPub: recipientPub,
    );

    final plain = await _aead.decrypt(
      SecretBox(ct, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(plain);
  }

  // ── internals ──────────────────────────────────────────────────────────

  static Future<Uint8List> _deriveKey({
    required SimpleKeyPair keyPair,
    required Uint8List peerPublicKey,
    required Uint8List ephPub,
    required Uint8List recipientPub,
  }) async {
    final shared = await X25519().sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey:
          SimplePublicKey(peerPublicKey, type: KeyPairType.x25519),
    );
    final salt = Uint8List(_keyLen * 2)
      ..setRange(0, _keyLen, ephPub)
      ..setRange(_keyLen, _keyLen * 2, recipientPub);
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(await shared.extractBytes()),
      nonce: salt,
      info: utf8.encode(_info),
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  static void _requireLen(List<int> b, int n, String what) {
    if (b.length != n) {
      throw ArgumentError('support seal: $what must be $n bytes, got ${b.length}');
    }
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = r.nextInt(256);
    }
    return out;
  }
}
