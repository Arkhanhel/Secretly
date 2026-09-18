// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ratchet/double_ratchet_v3.dart';
import 'package:secretly_app/ratchet/session_v1.dart';
import 'package:secretly_app/ratchet/wire_v3.dart';

void main() {
  test('SKS2 prekey decrypts and payload decodes', () async {
    final handshake = PrekeyHandshakeV1();
    final dr = DoubleRatchetV3();

    // Receiver material (signed prekey).
    final x = X25519();
    final receiverSpk = await x.newKeyPair();
    final receiverSpkPub = await receiverSpk.extractPublicKey();

    // Initiator creates prekey header/session.
    final init = await handshake.initiatorCreate(
      selfDeviceId: 'A',
      peerDeviceId: 'B',
      recipientSignedPrekeyPubB64: base64Encode(receiverSpkPub.bytes),
      recipientSignedPrekeyId: 1,
    );

    var sA = await dr.initInitiator(
      peerDeviceId: 'B',
      rootKey: init.session.rootKey,
      handshakeEphKeyPair: init.ephKeyPair,
      recipientSignedPrekeyPub: Uint8List.fromList(receiverSpkPub.bytes),
    );

    final plaintext = utf8.encode('{"v":1,"sender_device_id":"A","created_at_ms":1,"events":[{"type":"msg","event_id":"e1","text":"hi"}]}');

    final headerMap = <String, Object?>{
      ...init.header.toJson(),
      'dh_pub_b64': base64Encode(sA.dhSelfPub),
      'pn': sA.pn,
      'n': sA.ns,
    };
    final headerBytes = Uint8List.fromList(utf8.encode(jsonEncode(headerMap)));
    final enc = await dr.encrypt(state: sA, plaintext: plaintext, aad: headerBytes);
    sA = enc.updated;

    final wire = RatchetWireV3.encodePrekey(header: headerMap, ratchetCiphertext: enc.ciphertext);
    final decoded = RatchetWireV3.tryDecode(wire);
    expect(decoded, isNotNull);
    expect(decoded!.kind, RatchetWireKindV3.prekey);
    expect(decoded.header['sender_device_id'], 'A');

    // Responder accepts handshake using sender_eph_pub_b64, then decrypts using dh_pub_b64.
    final pre = PrekeyHeaderV1.fromJson(decoded.header);
    final v12 = await handshake.responderAccept(
      selfDeviceId: 'B',
      peerDeviceId: pre.senderDeviceId,
      header: pre,
      recipientSignedPrekeyKeyPair: receiverSpk,
    );

    final initiatorDhPubB64 = (decoded.header['dh_pub_b64'] as String?) ?? pre.senderEphemeralPubB64;
    var sB = await dr.initResponder(
      peerDeviceId: pre.senderDeviceId,
      rootKey: v12.rootKey,
      recipientSignedPrekeyKeyPair: receiverSpk,
      initiatorDhPub: Uint8List.fromList(base64Decode(initiatorDhPubB64)),
    );

    final dec = await dr.decrypt(
      state: sB,
      headerDhPubB64: initiatorDhPubB64,
      pn: (decoded.header['pn'] as num).toInt(),
      n: (decoded.header['n'] as num).toInt(),
      ciphertext: decoded.ciphertext,
      // No skipped key applies to a first message — the pure contract just
      // takes null instead of three do-nothing callbacks.
      aad: decoded.headerBytes,
    );
    sB = dec.updated;

    final decodedPayload = jsonDecode(utf8.decode(dec.plaintext)) as Map<String, dynamic>;
    expect(decodedPayload['v'], 1);
    expect(decodedPayload['sender_device_id'], 'A');
  });
}
