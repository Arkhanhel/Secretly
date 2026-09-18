// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/crypto/support_seal.dart';

void main() {
  group('SupportSeal', () {
    test('seal → open round-trips the exact plaintext', () async {
      final kp = await SupportSeal.generateKeypair();
      final msg = utf8.encode('Здравствуйте, у меня не приходят смс. Build 400.');
      final sealed =
          await SupportSeal.seal(plaintext: msg, recipientPublicKey: kp.publicKey);
      final opened =
          await SupportSeal.open(sealedB64: sealed, recipientPrivateSeed: kp.privateSeed);
      expect(opened, equals(msg));
    });

    test('empty plaintext round-trips', () async {
      final kp = await SupportSeal.generateKeypair();
      final sealed = await SupportSeal.seal(
          plaintext: const <int>[], recipientPublicKey: kp.publicKey);
      final opened = await SupportSeal.open(
          sealedB64: sealed, recipientPrivateSeed: kp.privateSeed);
      expect(opened, isEmpty);
    });

    test('a different recipient key CANNOT open (auth fails)', () async {
      final good = await SupportSeal.generateKeypair();
      final other = await SupportSeal.generateKeypair();
      final sealed = await SupportSeal.seal(
          plaintext: utf8.encode('secret'), recipientPublicKey: good.publicKey);
      await expectLater(
        SupportSeal.open(sealedB64: sealed, recipientPrivateSeed: other.privateSeed),
        throwsA(anything),
        reason: 'only the intended recipient key may open the box',
      );
    });

    test('tampering any byte breaks authentication', () async {
      final kp = await SupportSeal.generateKeypair();
      final sealed = await SupportSeal.seal(
          plaintext: utf8.encode('tamper me'), recipientPublicKey: kp.publicKey);
      final raw = base64Decode(sealed);
      // Flip a bit in the ciphertext/mac region (past ephPub+nonce = 56).
      final tampered = Uint8List.fromList(raw);
      tampered[tampered.length - 1] ^= 0x01;
      await expectLater(
        SupportSeal.open(
            sealedB64: base64Encode(tampered), recipientPrivateSeed: kp.privateSeed),
        throwsA(anything),
      );
    });

    test('a too-short / non-base64 wire throws a clean error', () async {
      final kp = await SupportSeal.generateKeypair();
      await expectLater(
        SupportSeal.open(sealedB64: 'AAAA', recipientPrivateSeed: kp.privateSeed),
        throwsA(isA<FormatException>()),
      );
    });

    test('two seals of the same plaintext differ (ephemeral randomness)',
        () async {
      final kp = await SupportSeal.generateKeypair();
      final msg = utf8.encode('same');
      final a = await SupportSeal.seal(plaintext: msg, recipientPublicKey: kp.publicKey);
      final b = await SupportSeal.seal(plaintext: msg, recipientPublicKey: kp.publicKey);
      expect(a, isNot(equals(b)),
          reason: 'each seal uses a fresh ephemeral key + nonce');
    });

    test('publicKeyFromSeed is deterministic + matches generateKeypair', () async {
      final kp = await SupportSeal.generateKeypair();
      final derived = await SupportSeal.publicKeyFromSeed(kp.privateSeed);
      expect(derived, equals(kp.publicKey));
    });

    test('bidirectional: user→support and support→user reply', () async {
      // Support side owns the support keypair (priv only in the admin console).
      final support = await SupportSeal.generateKeypair();
      // User side owns a per-device reply keypair (priv in SecureSecrets).
      final user = await SupportSeal.generateKeypair();

      // 1. User seals a ticket to the SUPPORT public key.
      final ticket = await SupportSeal.seal(
          plaintext: utf8.encode('нужна помощь'),
          recipientPublicKey: support.publicKey);
      // Admin opens it with the support private seed.
      final gotTicket = await SupportSeal.open(
          sealedB64: ticket, recipientPrivateSeed: support.privateSeed);
      expect(utf8.decode(gotTicket), 'нужна помощь');

      // 2. Admin seals a reply to the USER's reply pubkey (carried in the ticket).
      final reply = await SupportSeal.seal(
          plaintext: utf8.encode('починили, обновитесь'),
          recipientPublicKey: user.publicKey);
      final gotReply = await SupportSeal.open(
          sealedB64: reply, recipientPrivateSeed: user.privateSeed);
      expect(utf8.decode(gotReply), 'починили, обновитесь');

      // Cross-check: the support key cannot open the user-bound reply.
      await expectLater(
        SupportSeal.open(sealedB64: reply, recipientPrivateSeed: support.privateSeed),
        throwsA(anything),
      );
    });

    test('rejects wrong-length keys', () async {
      await expectLater(
        SupportSeal.seal(
            plaintext: const [1, 2, 3],
            recipientPublicKey: Uint8List(31)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
