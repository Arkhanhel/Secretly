// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Подпись сообщения комнаты (К-1, 17.09.2026).
///
/// Цепочка ключа комнаты симметричная: кто держит цепочку отправителя X, тот
/// может запечатать сообщение «от X». Поэтому у каждого поколения ключа
/// отправителя есть своя пара Ed25519: закрытая часть остаётся у автора,
/// открытая едет вместе с ключом (`gkey`), и каждое сообщение (`gmsg`)
/// подписывается. Подписанное привязано к комнате, отправителю, поколению и
/// позиции (через AAD), к nonce и шифртексту.
class RoomMessageSignature {
  RoomMessageSignature._();

  static const int seedLen = 32;
  static const int publicKeyLen = 32;
  static const int signatureLen = 64;

  static final Ed25519 _alg = Ed25519();

  static Uint8List newSeed() {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(seedLen, (_) => rnd.nextInt(256)),
    );
  }

  static Future<Uint8List> publicKeyForSeed(Uint8List seed) async {
    final kp = await _alg.newKeyPairFromSeed(seed);
    final pub = await kp.extractPublicKey();
    return Uint8List.fromList(pub.bytes);
  }

  /// Что подписывается: метка версии и три части с длинами, чтобы границы
  /// частей нельзя было сдвинуть.
  static Uint8List signedBytes({
    required Uint8List aad,
    required Uint8List nonce,
    required Uint8List ciphertext,
  }) {
    final out = BytesBuilder(copy: false);
    out.add(utf8.encode('secretly/room/sig/v1'));
    for (final part in [aad, nonce, ciphertext]) {
      final len = ByteData(4)..setUint32(0, part.length);
      out.add(len.buffer.asUint8List());
      out.add(part);
    }
    return out.toBytes();
  }

  static Future<Uint8List> sign({
    required Uint8List seed,
    required Uint8List aad,
    required Uint8List nonce,
    required Uint8List ciphertext,
  }) async {
    final kp = await _alg.newKeyPairFromSeed(seed);
    final sig = await _alg.sign(
      signedBytes(aad: aad, nonce: nonce, ciphertext: ciphertext),
      keyPair: kp,
    );
    return Uint8List.fromList(sig.bytes);
  }

  static Future<bool> verify({
    required Uint8List publicKey,
    required Uint8List signature,
    required Uint8List aad,
    required Uint8List nonce,
    required Uint8List ciphertext,
  }) async {
    if (publicKey.length != publicKeyLen || signature.length != signatureLen) {
      return false;
    }
    try {
      return await _alg.verify(
        signedBytes(aad: aad, nonce: nonce, ciphertext: ciphertext),
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
