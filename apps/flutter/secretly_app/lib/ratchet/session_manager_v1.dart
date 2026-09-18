// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../security/device_keys.dart';
import '../storage/app_db.dart';
import '../transport/keys_client.dart';
import 'session_v1.dart';
import 'wire_v1.dart';

class RatchetSessionManagerV1 {
  RatchetSessionManagerV1({
    required this.db,
    required this.deviceKeys,
    required this.keysClient,
    this.fetchBundleAuthed,
    PrekeyHandshakeV1? handshake,
    SessionRatchetV1? ratchet,
  }) : handshake = handshake ?? PrekeyHandshakeV1(),
       ratchet = ratchet ?? SessionRatchetV1();

  final AppDb db;
  final DeviceKeys deviceKeys;
  final KeysClient keysClient;
  final Future<List<Map<String, Object?>>> Function(String profileId)?
  fetchBundleAuthed;
  final PrekeyHandshakeV1 handshake;
  final SessionRatchetV1 ratchet;

  Future<Uint8List> encryptToPeer({
    required String selfDeviceId,
    required String peerProfileId,
    required String peerDeviceId,
    required Uint8List plaintext,
  }) async {
    final existing = await db.sessionGet(peerDeviceId);

    if (existing == null) {
      final bundle = await _fetchAndVerifyPeerBundle(
        peerProfileId: peerProfileId,
        peerDeviceId: peerDeviceId,
      );

      final init = await handshake.initiatorCreate(
        selfDeviceId: selfDeviceId,
        peerDeviceId: peerDeviceId,
        recipientSignedPrekeyPubB64: bundle.signedPrekeyPubB64,
        recipientSignedPrekeyId: 1,
        recipientOneTimePrekeyPubB64: bundle.oneTimePrekeyPubB64,
        recipientOneTimePrekeyId: bundle.oneTimePrekeyId,
      );

      final enc = await ratchet.encrypt(
        state: init.session,
        plaintext: plaintext,
      );
      await _persistSession(enc.updated);

      return RatchetWireV1.encodePrekey(
        header: init.header,
        ratchetCiphertext: enc.ciphertext,
      );
    }

    var state = _stateFromRow(existing);
    final enc = await ratchet.encrypt(state: state, plaintext: plaintext);
    state = enc.updated;
    await _persistSession(state);

    return RatchetWireV1.encodeSession(
      senderDeviceId: selfDeviceId,
      ratchetCiphertext: enc.ciphertext,
    );
  }

  Future<Uint8List> decryptFromWire({
    required String selfProfileId,
    required String selfDeviceId,
    required Uint8List wireBytes,
  }) async {
    final decoded = RatchetWireV1.tryDecode(wireBytes);
    if (decoded == null) {
      throw StateError('not a ratchet wire message');
    }

    switch (decoded.kind) {
      case RatchetWireKindV1.prekey:
        final header = PrekeyHeaderV1.fromJson(decoded.header);

        final spk = await deviceKeys.loadSignedPrekeyKeyPair(
          profileId: selfProfileId,
          deviceId: selfDeviceId,
        );
        SimpleKeyPair? otk;
        if (header.recipientOneTimePrekeyId != null) {
          otk = await deviceKeys.loadOneTimePrekeyKeyPair(
            profileId: selfProfileId,
            deviceId: selfDeviceId,
            prekeyId: header.recipientOneTimePrekeyId!,
          );
        }

        var state = await handshake.responderAccept(
          selfDeviceId: selfDeviceId,
          peerDeviceId: header.senderDeviceId,
          header: header,
          recipientSignedPrekeyKeyPair: spk,
          recipientOneTimePrekeyKeyPair: otk,
        );

        final dec = await ratchet.decrypt(
          state: state,
          ciphertext: decoded.ciphertext,
        );
        state = dec.updated;
        await _persistSession(state);

        return dec.plaintext;

      case RatchetWireKindV1.session:
        final senderDeviceId = decoded.header['sender_device_id'] as String?;
        if (senderDeviceId == null || senderDeviceId.isEmpty) {
          throw StateError('missing sender_device_id');
        }

        final row = await db.sessionGet(senderDeviceId);
        if (row == null) {
          throw StateError('no session for sender_device_id=$senderDeviceId');
        }

        var state = _stateFromRow(row);
        final dec = await ratchet.decrypt(
          state: state,
          ciphertext: decoded.ciphertext,
        );
        state = dec.updated;
        await _persistSession(state);

        return dec.plaintext;
    }
  }

  Future<void> _persistSession(SessionStateV1 s) async {
    await db.sessionUpsert(
      peerDeviceId: s.peerDeviceId,
      rootKeyB64: base64Encode(s.rootKey),
      sendChainKeyB64: base64Encode(s.sendChainKey),
      recvChainKeyB64: base64Encode(s.recvChainKey),
      sendCount: s.sendCount,
      recvCount: s.recvCount,
    );
  }

  SessionStateV1 _stateFromRow(Map<String, Object?> row) {
    return SessionStateV1(
      peerDeviceId: row['peer_device_id'] as String,
      rootKey: Uint8List.fromList(base64Decode(row['root_key_b64'] as String)),
      sendChainKey: Uint8List.fromList(
        base64Decode(row['send_chain_key_b64'] as String),
      ),
      recvChainKey: Uint8List.fromList(
        base64Decode(row['recv_chain_key_b64'] as String),
      ),
      sendCount: (row['send_count'] as num).toInt(),
      recvCount: (row['recv_count'] as num).toInt(),
    );
  }

  Future<_PeerBundleV1> _fetchAndVerifyPeerBundle({
    required String peerProfileId,
    required String peerDeviceId,
  }) async {
    final devices = await (fetchBundleAuthed != null
        ? fetchBundleAuthed!(peerProfileId)
        : keysClient.fetchBundle(peerProfileId));

    final match = devices
        .where((d) => d['device_id'] == peerDeviceId)
        .toList(growable: false);
    if (match.isEmpty) {
      throw StateError('peer device not found in bundle: $peerDeviceId');
    }

    final d = match.first;
    final identityB64 = d['identity_key_pub_b64'] as String?;
    final spkB64 = d['signed_prekey_pub_b64'] as String?;
    final spkSigB64 = d['signed_prekey_sig_b64'] as String?;
    final otk = d['one_time_prekey'];

    if (identityB64 == null || spkB64 == null || spkSigB64 == null) {
      throw StateError('bundle missing required fields');
    }

    // Verify signed prekey signature.
    final identityPub = SimplePublicKey(
      base64Decode(identityB64),
      type: KeyPairType.ed25519,
    );
    final spkBytes = base64Decode(spkB64);
    final sigBytes = base64Decode(spkSigB64);

    final ed = Ed25519();
    final sig = Signature(sigBytes, publicKey: identityPub);
    final ok = await ed.verify(spkBytes, signature: sig);
    if (!ok) {
      throw StateError('signed prekey signature verification failed');
    }

    await db.contactDeviceUpsert(
      profileId: peerProfileId,
      deviceId: peerDeviceId,
      identityKeyPubB64: identityB64,
      signedPrekeyPubB64: spkB64,
      signedPrekeySigB64: spkSigB64,
    );

    int? otkId;
    String? otkPubB64;
    if (otk is Map) {
      final prekeyId = otk['prekey_id'];
      if (prekeyId is num) otkId = prekeyId.toInt();
      final pub = otk['prekey_pub_b64'];
      if (pub is String) otkPubB64 = pub;
    }

    return _PeerBundleV1(
      deviceId: peerDeviceId,
      identityKeyPubB64: identityB64,
      signedPrekeyPubB64: spkB64,
      signedPrekeySigB64: spkSigB64,
      oneTimePrekeyId: otkId,
      oneTimePrekeyPubB64: otkPubB64,
    );
  }
}

class _PeerBundleV1 {
  const _PeerBundleV1({
    required this.deviceId,
    required this.identityKeyPubB64,
    required this.signedPrekeyPubB64,
    required this.signedPrekeySigB64,
    required this.oneTimePrekeyId,
    required this.oneTimePrekeyPubB64,
  });

  final String deviceId;
  final String identityKeyPubB64;
  final String signedPrekeyPubB64;
  final String signedPrekeySigB64;
  final int? oneTimePrekeyId;
  final String? oneTimePrekeyPubB64;
}
