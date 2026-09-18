// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class PrekeyHeaderV1 {
  const PrekeyHeaderV1({
    required this.senderDeviceId,
    required this.senderEphemeralPubB64,
    required this.recipientSignedPrekeyId,
    this.recipientOneTimePrekeyId,
  });

  final String senderDeviceId;
  final String senderEphemeralPubB64;

  // For future rotation. For now we assume a single active signed prekey per device.
  final int recipientSignedPrekeyId;

  // Optional.
  final int? recipientOneTimePrekeyId;

  Map<String, Object?> toJson() => {
        'sender_device_id': senderDeviceId,
        'sender_eph_pub_b64': senderEphemeralPubB64,
        'spk_id': recipientSignedPrekeyId,
        if (recipientOneTimePrekeyId != null) 'otk_id': recipientOneTimePrekeyId,
      };

  static PrekeyHeaderV1 fromJson(Map<String, dynamic> json) {
    return PrekeyHeaderV1(
      senderDeviceId: json['sender_device_id'] as String,
      senderEphemeralPubB64: json['sender_eph_pub_b64'] as String,
      recipientSignedPrekeyId: (json['spk_id'] as num).toInt(),
      recipientOneTimePrekeyId: (json['otk_id'] as num?)?.toInt(),
    );
  }
}

class SessionStateV1 {
  const SessionStateV1({
    required this.peerDeviceId,
    required this.rootKey,
    required this.sendChainKey,
    required this.recvChainKey,
    required this.sendCount,
    required this.recvCount,
  });

  final String peerDeviceId;
  final Uint8List rootKey;
  final Uint8List sendChainKey;
  final Uint8List recvChainKey;
  final int sendCount;
  final int recvCount;

  SessionStateV1 copyWith({
    Uint8List? rootKey,
    Uint8List? sendChainKey,
    Uint8List? recvChainKey,
    int? sendCount,
    int? recvCount,
  }) {
    return SessionStateV1(
      peerDeviceId: peerDeviceId,
      rootKey: rootKey ?? this.rootKey,
      sendChainKey: sendChainKey ?? this.sendChainKey,
      recvChainKey: recvChainKey ?? this.recvChainKey,
      sendCount: sendCount ?? this.sendCount,
      recvCount: recvCount ?? this.recvCount,
    );
  }

  Map<String, Object?> toJson() => {
        'peer_device_id': peerDeviceId,
        'root_key_b64': base64Encode(rootKey),
        'send_chain_key_b64': base64Encode(sendChainKey),
        'recv_chain_key_b64': base64Encode(recvChainKey),
        'send_count': sendCount,
        'recv_count': recvCount,
      };

  static SessionStateV1 fromJson(Map<String, dynamic> json) {
    return SessionStateV1(
      peerDeviceId: json['peer_device_id'] as String,
      rootKey: Uint8List.fromList(base64Decode(json['root_key_b64'] as String)),
      sendChainKey: Uint8List.fromList(base64Decode(json['send_chain_key_b64'] as String)),
      recvChainKey: Uint8List.fromList(base64Decode(json['recv_chain_key_b64'] as String)),
      sendCount: (json['send_count'] as num).toInt(),
      recvCount: (json['recv_count'] as num).toInt(),
    );
  }
}

class RatchetEncryptResultV1 {
  const RatchetEncryptResultV1({
    required this.updated,
    required this.ciphertext,
  });

  final SessionStateV1 updated;
  final Uint8List ciphertext;
}

class RatchetDecryptResultV1 {
  const RatchetDecryptResultV1({
    required this.updated,
    required this.plaintext,
  });

  final SessionStateV1 updated;
  final Uint8List plaintext;
}

class SessionRatchetV1 {
  SessionRatchetV1({
    Cipher? aead,
    Hkdf? hkdf,
  })  : hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32),
        aead = aead ?? Xchacha20.poly1305Aead();

  final Hkdf hkdf;
  final Cipher aead;

  Future<RatchetEncryptResultV1> encrypt({
    required SessionStateV1 state,
    required List<int> plaintext,
  }) async {
    final messageKey = await _kdfMessageKey(state.sendChainKey, state.sendCount);
    final nonce = _randomBytes(24);

    final secretKey = SecretKey(messageKey);
    final box = await aead.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    final out = Uint8List(nonce.length + box.cipherText.length + box.mac.bytes.length);
    out.setRange(0, nonce.length, nonce);
    out.setRange(nonce.length, nonce.length + box.cipherText.length, box.cipherText);
    out.setRange(
      nonce.length + box.cipherText.length,
      out.length,
      box.mac.bytes,
    );

    final nextCk = await _kdfChainStep(state.sendChainKey);
    final updated = state.copyWith(
      sendChainKey: nextCk,
      sendCount: state.sendCount + 1,
    );

    return RatchetEncryptResultV1(updated: updated, ciphertext: out);
  }

  Future<RatchetDecryptResultV1> decrypt({
    required SessionStateV1 state,
    required List<int> ciphertext,
  }) async {
    if (ciphertext.length < 24 + 16) {
      throw StateError('ciphertext too short');
    }

    final nonce = Uint8List.fromList(ciphertext.sublist(0, 24));
    final rest = ciphertext.sublist(24);
    if (rest.length < 16) {
      throw StateError('ciphertext too short (no mac)');
    }

    final macBytes = Uint8List.fromList(rest.sublist(rest.length - 16));
    final ct = Uint8List.fromList(rest.sublist(0, rest.length - 16));

    final messageKey = await _kdfMessageKey(state.recvChainKey, state.recvCount);
    final secretKey = SecretKey(messageKey);

    final box = SecretBox(ct, nonce: nonce, mac: Mac(macBytes));
    final plain = await aead.decrypt(box, secretKey: secretKey);

    final nextCk = await _kdfChainStep(state.recvChainKey);
    final updated = state.copyWith(
      recvChainKey: nextCk,
      recvCount: state.recvCount + 1,
    );

    return RatchetDecryptResultV1(updated: updated, plaintext: Uint8List.fromList(plain));
  }

  Future<Uint8List> _kdfMessageKey(Uint8List chainKey, int index) async {
    final info = utf8.encode('secretly/mk/v1/$index');
    final out = await hkdf.deriveKey(
      secretKey: SecretKey(chainKey),
      info: info,
      nonce: const <int>[],
    );
    return Uint8List.fromList(await out.extractBytes());
  }

  Future<Uint8List> _kdfChainStep(Uint8List chainKey) async {
    final info = utf8.encode('secretly/ck_step/v1');
    final out = await hkdf.deriveKey(
      secretKey: SecretKey(chainKey),
      info: info,
      nonce: const <int>[],
    );
    return Uint8List.fromList(await out.extractBytes());
  }
}

class PrekeyHandshakeV1 {
  PrekeyHandshakeV1({Hkdf? hkdf}) : hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  final Hkdf hkdf;

  /// Creates an initiator session from recipient bundle (pubkeys) and returns header + session state.
  ///
  /// Simplified X3DH-like:
  ///   root = HKDF( DH(eph, spk) || (DH(eph, otk)?), info="secretly/root/v1" )
  ///
  /// Direction:
  ///   initiator uses ck0 for send and ck1 for recv; responder is the opposite.
  Future<({PrekeyHeaderV1 header, SessionStateV1 session, SimpleKeyPair ephKeyPair})> initiatorCreate({
    required String selfDeviceId,
    required String peerDeviceId,
    required String recipientSignedPrekeyPubB64,
    int recipientSignedPrekeyId = 1,
    String? recipientOneTimePrekeyPubB64,
    int? recipientOneTimePrekeyId,
  }) async {
    final x = X25519();
    // Always create from seed so key material can be persisted/derived deterministically.
    final ephSeed = _randomBytes(32);
    final eph = await x.newKeyPairFromSeed(ephSeed);
    final ephPub = await eph.extractPublicKey();

    final spkPub = SimplePublicKey(base64Decode(recipientSignedPrekeyPubB64), type: KeyPairType.x25519);
    final dh1 = await x.sharedSecretKey(keyPair: eph, remotePublicKey: spkPub);
    final dh1Bytes = Uint8List.fromList(await dh1.extractBytes());

    // DH2 (the one-time prekey) is mixed into the root ONLY when we have BOTH its
    // public key and id. The header must advertise the id iff DH2 was actually
    // mixed, so the responder derives the IDENTICAL root (see responderAccept):
    // a header id present without DH2 (or vice-versa) diverges the session.
    Uint8List secretMaterial;
    final bool usedOtk;
    if (recipientOneTimePrekeyPubB64 != null && recipientOneTimePrekeyId != null) {
      usedOtk = true;
      final otkPub = SimplePublicKey(base64Decode(recipientOneTimePrekeyPubB64), type: KeyPairType.x25519);
      final dh2 = await x.sharedSecretKey(keyPair: eph, remotePublicKey: otkPub);
      final dh2Bytes = Uint8List.fromList(await dh2.extractBytes());
      secretMaterial = Uint8List(dh1Bytes.length + dh2Bytes.length);
      secretMaterial.setRange(0, dh1Bytes.length, dh1Bytes);
      secretMaterial.setRange(dh1Bytes.length, secretMaterial.length, dh2Bytes);
    } else {
      usedOtk = false;
      secretMaterial = dh1Bytes;
    }

    final session = await _deriveSession(
      peerDeviceId: peerDeviceId,
      secretMaterial: secretMaterial,
      isInitiator: true,
    );

    final header = PrekeyHeaderV1(
      senderDeviceId: selfDeviceId,
      senderEphemeralPubB64: base64Encode(ephPub.bytes),
      recipientSignedPrekeyId: recipientSignedPrekeyId,
      recipientOneTimePrekeyId: usedOtk ? recipientOneTimePrekeyId : null,
    );

    return (header: header, session: session, ephKeyPair: eph);
  }

  /// Accepts an initiator header and derives the same session on responder.
  Future<SessionStateV1> responderAccept({
    required String selfDeviceId,
    required String peerDeviceId,
    required PrekeyHeaderV1 header,
    required SimpleKeyPair recipientSignedPrekeyKeyPair,
    SimpleKeyPair? recipientOneTimePrekeyKeyPair,
  }) async {
    if (header.senderDeviceId != peerDeviceId) {
      // Not fatal but keeps callers honest.
      throw StateError('header sender_device_id mismatch');
    }

    final x = X25519();
    final ephPub = SimplePublicKey(base64Decode(header.senderEphemeralPubB64), type: KeyPairType.x25519);

    final dh1 = await x.sharedSecretKey(keyPair: recipientSignedPrekeyKeyPair, remotePublicKey: ephPub);
    final dh1Bytes = Uint8List.fromList(await dh1.extractBytes());

    // DH2 must be included iff the INITIATOR included it — signalled by the
    // header carrying a one-time prekey id (see initiatorCreate) — NOT by whether
    // we happened to load the keypair. If the initiator mixed an OTK we no longer
    // hold (consumed, or lost on reinstall), we CANNOT reconstruct the matching
    // root; deriving from DH1 alone would silently create a DIVERGED session that
    // corrupts EVERY message under it, not just this one. Fail cleanly instead so
    // the caller quarantines the wire and resets — the rebuilt handshake decrypts
    // the peer's subsequent messages.
    Uint8List secretMaterial;
    if (header.recipientOneTimePrekeyId != null) {
      if (recipientOneTimePrekeyKeyPair == null) {
        throw StateError(
          'missing one-time prekey ${header.recipientOneTimePrekeyId} required by initiator handshake',
        );
      }
      final dh2 = await x.sharedSecretKey(keyPair: recipientOneTimePrekeyKeyPair, remotePublicKey: ephPub);
      final dh2Bytes = Uint8List.fromList(await dh2.extractBytes());
      secretMaterial = Uint8List(dh1Bytes.length + dh2Bytes.length);
      secretMaterial.setRange(0, dh1Bytes.length, dh1Bytes);
      secretMaterial.setRange(dh1Bytes.length, secretMaterial.length, dh2Bytes);
    } else {
      secretMaterial = dh1Bytes;
    }

    return _deriveSession(
      peerDeviceId: peerDeviceId,
      secretMaterial: secretMaterial,
      isInitiator: false,
    );
  }

  Future<SessionStateV1> _deriveSession({
    required String peerDeviceId,
    required Uint8List secretMaterial,
    required bool isInitiator,
  }) async {
    final rootKey = await _hkdf(secretMaterial, 'secretly/root/v1');
    final ck0 = await _hkdf(rootKey, 'secretly/ck0/v1');
    final ck1 = await _hkdf(rootKey, 'secretly/ck1/v1');

    final sendCk = isInitiator ? ck0 : ck1;
    final recvCk = isInitiator ? ck1 : ck0;

    return SessionStateV1(
      peerDeviceId: peerDeviceId,
      rootKey: rootKey,
      sendChainKey: sendCk,
      recvChainKey: recvCk,
      sendCount: 0,
      recvCount: 0,
    );
  }

  Future<Uint8List> _hkdf(Uint8List ikm, String infoStr) async {
    final info = utf8.encode(infoStr);
    final out = await hkdf.deriveKey(
      secretKey: SecretKey(ikm),
      info: info,
      nonce: const <int>[],
    );
    return Uint8List.fromList(await out.extractBytes());
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
