// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// С-2 (24.09.2026): подпись рукопожатия ключом личности устройства.
///
/// Корень сессии (`session_v1.dart`) не содержит ключа личности начинающего,
/// поэтому без подписи рукопожатие может начать кто угодно, знающий публичную
/// связку получателя, — в том числе сервер. Подпись связывает рукопожатие с
/// ключом, который получатель уже закрепил, и НЕ меняет формулу ключей:
/// поле в заголовке только добавляется, старые сборки его пропускают.
///
/// ТЗ: `docs/TZ_HANDSHAKE_SIGNATURE_C2_2026-09-24.md`.
class HandshakeSignature {
  HandshakeSignature._();

  /// Поле подписи в заголовке prekey-провода.
  static const String headerField = 'hs_sig_b64';

  /// Метка в заголовке ОБЫЧНОГО провода: «это устройство подписывает свои
  /// рукопожатия». Заголовок — AAD, поэтому метку нельзя ни подделать, ни
  /// снять, не сломав сообщение. Дописывается ПОСЛЕДНЕЙ, как `se`.
  static const String capabilityField = 'hsv';
  static const int capabilityVersion = 1;

  /// 🔴 Контекст с нулевым байтом. Тот же ключ подписывает сырой 32-байтовый
  /// SPK (без контекста) и сертификаты устройства (`secretly-device-cert-v1|…`).
  /// Байты этой подписи не должны совпасть ни с тем, ни с другим ни при каких
  /// входах: сообщение начинается с этого контекста и всегда длиннее 32 байт.
  static const String context = 'secretly-hs-sig-v1';

  /// Подписываемые байты. Поля с префиксом длины (u16, big-endian), чтобы
  /// никакое поле не могло «переехать» в соседнее. `se`, `dh_pub_b64`, `n`,
  /// `pn` не подписываются: повтор рукопожатия перештамповывает их, а время
  /// у людей бывает сбито.
  static Uint8List message({
    required String senderDeviceId,
    required String recipientDeviceId,
    required List<int> senderEphemeralPub,
    required List<int> recipientSignedPrekeyPub,
    required int signedPrekeyId,
    required int? oneTimePrekeyId,
  }) {
    final out = BytesBuilder(copy: false);
    out.add(utf8.encode(context));
    out.addByte(0);
    void lp(List<int> bytes) {
      if (bytes.length > 0xFFFF) {
        throw ArgumentError('handshake signature field too long');
      }
      out.addByte((bytes.length >> 8) & 0xFF);
      out.addByte(bytes.length & 0xFF);
      out.add(bytes);
    }

    void u32(int v) {
      out.addByte((v >> 24) & 0xFF);
      out.addByte((v >> 16) & 0xFF);
      out.addByte((v >> 8) & 0xFF);
      out.addByte(v & 0xFF);
    }

    lp(utf8.encode(senderDeviceId.trim()));
    lp(utf8.encode(recipientDeviceId.trim()));
    lp(senderEphemeralPub);
    lp(recipientSignedPrekeyPub);
    u32(signedPrekeyId);
    out.addByte(oneTimePrekeyId == null ? 0 : 1);
    u32(oneTimePrekeyId ?? 0);
    return out.toBytes();
  }

  static Future<String> sign({
    required SimpleKeyPair identityKeyPair,
    required Uint8List message,
  }) async {
    final sig = await Ed25519().sign(message, keyPair: identityKeyPair);
    return base64Encode(sig.bytes);
  }

  /// `false` на любой неясности: испорченный base64, не тот размер ключа или
  /// подписи. «Не доказано» никогда не читается как «доказано».
  static Future<bool> verify({
    required String identityKeyPubB64,
    required String signatureB64,
    required Uint8List message,
  }) async {
    try {
      final pub = base64Decode(identityKeyPubB64.trim());
      final sig = base64Decode(signatureB64.trim());
      if (pub.length != 32 || sig.length != 64) return false;
      return await Ed25519().verify(
        message,
        signature: Signature(
          sig,
          publicKey: SimplePublicKey(pub, type: KeyPairType.ed25519),
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
