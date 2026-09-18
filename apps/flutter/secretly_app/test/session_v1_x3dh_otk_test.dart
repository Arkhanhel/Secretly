// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ratchet/session_v1.dart';

// X3DH one-time-prekey (OTK) asymmetry fix (2026-07-12).
//
// The initiator mixes DH2 (the OTK) into the root iff it has the OTK pub+id, and
// advertises the id in the prekey header. The responder previously decided to mix
// DH2 based on whether it could LOAD the OTK keypair — so if the initiator used an
// OTK the responder no longer holds (consumed / lost on reinstall / re-served),
// the responder silently derived the root from DH1 alone. That DIVERGED root
// corrupts EVERY message under the session, not just the first. The fix ties the
// responder's DH2 decision to the header (what the initiator actually did) and
// fails cleanly when a required OTK is missing, so the session is never diverged.

Future<(SimpleKeyPair, String)> _x25519() async {
  final x = X25519();
  final kp = await x.newKeyPair();
  final pub = await kp.extractPublicKey();
  return (kp, base64Encode(pub.bytes));
}

void main() {
  test('present OTK on both sides → identical root + crossed chains', () async {
    final hs = PrekeyHandshakeV1();
    final (spk, spkPub) = await _x25519();
    final (otk, otkPub) = await _x25519();

    final init = await hs.initiatorCreate(
      selfDeviceId: 'A',
      peerDeviceId: 'B',
      recipientSignedPrekeyPubB64: spkPub,
      recipientSignedPrekeyId: 1,
      recipientOneTimePrekeyPubB64: otkPub,
      recipientOneTimePrekeyId: 7,
    );
    expect(init.header.recipientOneTimePrekeyId, 7);

    final resp = await hs.responderAccept(
      selfDeviceId: 'B',
      peerDeviceId: 'A',
      header: init.header,
      recipientSignedPrekeyKeyPair: spk,
      recipientOneTimePrekeyKeyPair: otk,
    );

    expect(resp.rootKey, init.session.rootKey);
    // Initiator's send chain is the responder's receive chain and vice-versa.
    expect(resp.recvChainKey, init.session.sendChainKey);
    expect(resp.sendChainKey, init.session.recvChainKey);
  });

  test('no OTK on either side → identical root (header id null)', () async {
    final hs = PrekeyHandshakeV1();
    final (spk, spkPub) = await _x25519();

    final init = await hs.initiatorCreate(
      selfDeviceId: 'A',
      peerDeviceId: 'B',
      recipientSignedPrekeyPubB64: spkPub,
      recipientSignedPrekeyId: 1,
    );
    expect(init.header.recipientOneTimePrekeyId, isNull);

    final resp = await hs.responderAccept(
      selfDeviceId: 'B',
      peerDeviceId: 'A',
      header: init.header,
      recipientSignedPrekeyKeyPair: spk,
    );
    expect(resp.rootKey, init.session.rootKey);
  });

  test(
      'FIX: initiator used an OTK the responder no longer holds → responderAccept '
      'THROWS instead of deriving a diverged DH1-only session', () async {
    final hs = PrekeyHandshakeV1();
    final (spk, spkPub) = await _x25519();
    final (_, otkPub) = await _x25519(); // OTK pub known to the initiator only

    final init = await hs.initiatorCreate(
      selfDeviceId: 'A',
      peerDeviceId: 'B',
      recipientSignedPrekeyPubB64: spkPub,
      recipientSignedPrekeyId: 1,
      recipientOneTimePrekeyPubB64: otkPub,
      recipientOneTimePrekeyId: 9,
    );
    expect(init.header.recipientOneTimePrekeyId, 9);

    await expectLater(
      hs.responderAccept(
        selfDeviceId: 'B',
        peerDeviceId: 'A',
        header: init.header,
        recipientSignedPrekeyKeyPair: spk,
        recipientOneTimePrekeyKeyPair: null, // private key gone
      ),
      throwsA(anything),
    );
  });

  test('initiator advertises OTK id ONLY when DH2 is actually mixed', () async {
    final hs = PrekeyHandshakeV1();
    final (_, spkPub) = await _x25519();

    // id supplied but pub missing → DH2 not mixed → header id must be null, so a
    // responder never tries (or is forced) to mix a DH2 the initiator didn't.
    final init = await hs.initiatorCreate(
      selfDeviceId: 'A',
      peerDeviceId: 'B',
      recipientSignedPrekeyPubB64: spkPub,
      recipientSignedPrekeyId: 1,
      recipientOneTimePrekeyId: 5,
    );
    expect(init.header.recipientOneTimePrekeyId, isNull);
  });
}
