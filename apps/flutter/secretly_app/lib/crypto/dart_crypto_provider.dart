// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto_provider.dart';

class DartCryptoProvider implements CryptoProvider {
  DartCryptoProvider(Uint8List keyData)
      : _algo = Xchacha20.poly1305Aead(),
        _key = SecretKey(keyData);

  final SecretKey _key;
  final Cipher _algo;

  // Format v1: nonce(24) + mac(16) + ciphertext(N)
  static const int nonceLen = 24;
  static const int macLen = 16;

  @override
  Future<List<int>> encrypt(List<int> plaintext) async {
    final secretBox = await _algo.encrypt(
      plaintext,
      secretKey: _key,
    );

    final out = BytesBuilder(copy: false);
    out.add(secretBox.nonce);
    out.add(secretBox.mac.bytes);
    out.add(secretBox.cipherText);
    return out.takeBytes();
  }

  @override
  Future<List<int>> decrypt(List<int> ciphertext) async {
    if (ciphertext.length < nonceLen + macLen) {
      throw StateError('ciphertext too short');
    }

    final nonce = ciphertext.sublist(0, nonceLen);
    final macBytes = ciphertext.sublist(nonceLen, nonceLen + macLen);
    final cipherText = ciphertext.sublist(nonceLen + macLen);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final plain = await _algo.decrypt(
      secretBox,
      secretKey: _key,
    );

    return plain;
  }
}
