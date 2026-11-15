// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 15.11.2026, план П3 шаг В: ключ подписи конфигурации меняется в два шага.
// Выпуск знает нынешний и следующий ключ; сервер переходит на следующий,
// когда таких сборок большинство. Сторожа: подпись следующим ключом
// принимается, чужим — нет, а без следующего ключа всё как раньше.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';

Future<(String pubB64, Future<String> Function(List<int>) sign)> _key() async {
  final kp = await Ed25519().newKeyPair();
  final pub = await kp.extractPublicKey();
  return (
    base64Encode(pub.bytes),
    (List<int> m) async =>
        base64Encode((await Ed25519().sign(m, keyPair: kp)).bytes),
  );
}

void main() {
  final msg = utf8.encode('secretly-config-v2|test');

  test('подпись нынешним ключом принимается, как раньше', () async {
    final (cur, signCur) = await _key();
    expect(
      await verifyWithConfigKeys(
        currentKeyB64: cur,
        nextKeyB64: '',
        signatureB64: await signCur(msg),
        message: msg,
      ),
      isTrue,
    );
  });

  test('подпись следующим ключом принимается, только если он зашит', () async {
    final (cur, _) = await _key();
    final (next, signNext) = await _key();
    final sig = await signNext(msg);
    expect(
      await verifyWithConfigKeys(
        currentKeyB64: cur,
        nextKeyB64: next,
        signatureB64: sig,
        message: msg,
      ),
      isTrue,
    );
    expect(
      await verifyWithConfigKeys(
        currentKeyB64: cur,
        nextKeyB64: '',
        signatureB64: sig,
        message: msg,
      ),
      isFalse,
      reason: 'сборка без следующего ключа — как раньше',
    );
  });

  test('чужой ключ и подделанное сообщение отвергаются', () async {
    final (cur, _) = await _key();
    final (next, signNext) = await _key();
    final (_, signOther) = await _key();
    expect(
      await verifyWithConfigKeys(
        currentKeyB64: cur,
        nextKeyB64: next,
        signatureB64: await signOther(msg),
        message: msg,
      ),
      isFalse,
    );
    expect(
      await verifyWithConfigKeys(
        currentKeyB64: cur,
        nextKeyB64: next,
        signatureB64: await signNext(msg),
        message: utf8.encode('secretly-config-v2|tampered'),
      ),
      isFalse,
    );
  });

  test('без нынешнего ключа следующий не включает проверку сам', () async {
    final (next, signNext) = await _key();
    expect(
      await verifyWithConfigKeys(
        currentKeyB64: '',
        nextKeyB64: next,
        signatureB64: await signNext(msg),
        message: msg,
      ),
      isFalse,
    );
  });

  test('в тестовой сборке ключей нет — проверка не включена', () {
    expect(kConfigPublicKeyNextB64, isEmpty);
    expect(configSignatureEnforced, isFalse);
  });
}
