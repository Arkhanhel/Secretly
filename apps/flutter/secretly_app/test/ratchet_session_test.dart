// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ratchet/session_v1.dart';
import 'package:cryptography/cryptography.dart';

void main() {
  test('prekey handshake derives same root + directional chain keys', () async {
    final handshake = PrekeyHandshakeV1();

    // Receiver key material (signed prekey + OTK).
    final x = X25519();
    final receiverSpk = await x.newKeyPair();
    final receiverSpkPub = await receiverSpk.extractPublicKey();

    final receiverOtk = await x.newKeyPair();
    final receiverOtkPub = await receiverOtk.extractPublicKey();

    final r = await handshake.initiatorCreate(
      selfDeviceId: 'A',
      peerDeviceId: 'B',
      recipientSignedPrekeyPubB64: base64Encode(receiverSpkPub.bytes),
      recipientSignedPrekeyId: 1,
      recipientOneTimePrekeyPubB64: base64Encode(receiverOtkPub.bytes),
      recipientOneTimePrekeyId: 7,
    );

    final responder = await handshake.responderAccept(
      selfDeviceId: 'B',
      peerDeviceId: 'A',
      header: r.header,
      recipientSignedPrekeyKeyPair: receiverSpk,
      recipientOneTimePrekeyKeyPair: receiverOtk,
    );

    expect(r.session.rootKey, responder.rootKey);

    // Directional: initiator send == responder recv.
    expect(r.session.sendChainKey, responder.recvChainKey);
    expect(r.session.recvChainKey, responder.sendChainKey);
  });

  test('ratchet encrypt/decrypt roundtrip advances state', () async {
    final handshake = PrekeyHandshakeV1();
    final ratchet = SessionRatchetV1();

    final x = X25519();
    final receiverSpk = await x.newKeyPair();
    final receiverSpkPub = await receiverSpk.extractPublicKey();

    final init = await handshake.initiatorCreate(
      selfDeviceId: 'A',
      peerDeviceId: 'B',
      recipientSignedPrekeyPubB64: base64Encode(receiverSpkPub.bytes),
    );

    var responder = await handshake.responderAccept(
      selfDeviceId: 'B',
      peerDeviceId: 'A',
      header: init.header,
      recipientSignedPrekeyKeyPair: receiverSpk,
    );

    var initiator = init.session;

    final p1 = utf8.encode('hello');
    final e1 = await ratchet.encrypt(state: initiator, plaintext: p1);
    initiator = e1.updated;

    final d1 = await ratchet.decrypt(state: responder, ciphertext: e1.ciphertext);
    responder = d1.updated;

    expect(utf8.decode(d1.plaintext), 'hello');
    expect(initiator.sendCount, 1);
    expect(responder.recvCount, 1);

    final p2 = utf8.encode('world');
    final e2 = await ratchet.encrypt(state: responder, plaintext: p2);
    responder = e2.updated;

    final d2 = await ratchet.decrypt(state: initiator, ciphertext: e2.ciphertext);
    initiator = d2.updated;

    expect(utf8.decode(d2.plaintext), 'world');
    expect(responder.sendCount, 1);
    expect(initiator.recvCount, 1);
  });
}
