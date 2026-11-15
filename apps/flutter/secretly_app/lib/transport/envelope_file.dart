// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Конверты файлом — доставка без сети (Э4а «Мессенджер без центра», 11.10.2026).
///
/// Файл `.secretly` несёт ровно то, что обычно уходит на реле: зашифрованные
/// сквозным образом конверты (`msg_id`, устройство-получатель, шифротекст).
/// Ничего не расшифровывается и не перешифровывается: получатель кладёт
/// конверт во входящий карантин, и дальше работает обычный путь приёма —
/// с той же проверкой сессии, дедупликацией по `msg_id` и квитанциями.
///
/// Подпись файла ключом устройства отправителя — защита целостности и
/// подсказка «от кого», а не аутентификация сообщений: её даёт сам ратчет.
/// Поэтому неизвестный ключ не повод отвергать файл; неверная подпись при
/// известном ключе — повод.
class EnvelopeFile {
  EnvelopeFile._();

  static const int formatVersion = 1;
  static const String fileExtension = 'secretly';
  static const String mimeType = 'application/x-secretly-envelopes';
  static const int maxEnvelopes = 500;
  static const int maxFileBytes = 8 * 1024 * 1024;
  static const String _signingContext = 'secretly-envelope-file-v1\n';

  static final Ed25519 _ed = Ed25519();

  /// Байты, которые подписываются: контекст и канонический JSON полей.
  static List<int> _signingBytes({
    required String fromDeviceId,
    required int createdAtMs,
    required List<OfflineEnvelope> envelopes,
  }) {
    final canonical = jsonEncode(<String, Object?>{
      'v': formatVersion,
      'from_device_id': fromDeviceId,
      'created_at_ms': createdAtMs,
      'envelopes': envelopes.map((e) => e.toJson()).toList(),
    });
    return utf8.encode('$_signingContext$canonical');
  }

  static Future<List<int>> build({
    required String fromDeviceId,
    required int createdAtMs,
    required List<OfflineEnvelope> envelopes,
    required SimpleKeyPair deviceIdentity,
  }) async {
    if (envelopes.isEmpty) throw ArgumentError('no envelopes');
    if (envelopes.length > maxEnvelopes) {
      throw ArgumentError('too many envelopes');
    }
    final sig = await _ed.sign(
      _signingBytes(
        fromDeviceId: fromDeviceId,
        createdAtMs: createdAtMs,
        envelopes: envelopes,
      ),
      keyPair: deviceIdentity,
    );
    final pub = await deviceIdentity.extractPublicKey();
    final json = <String, Object?>{
      'v': formatVersion,
      'from_device_id': fromDeviceId,
      'from_identity_pub_b64': base64Encode(pub.bytes),
      'created_at_ms': createdAtMs,
      'envelopes': envelopes.map((e) => e.toJson()).toList(),
      'sig_b64': base64Encode(sig.bytes),
    };
    return utf8.encode(jsonEncode(json));
  }

  /// Разбирает и проверяет подпись (по ключу из самого файла — целостность).
  /// [knownIdentityPubB64] — ключ устройства отправителя, если он известен
  /// локально; несовпадение с ключом в файле — отказ.
  static Future<ParsedEnvelopeFile> parse(
    List<int> bytes, {
    String? knownIdentityPubB64,
  }) async {
    if (bytes.length > maxFileBytes) {
      throw const EnvelopeFileException('too_large');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const EnvelopeFileException('not_json');
    }
    if (decoded is! Map || decoded['v'] != formatVersion) {
      throw const EnvelopeFileException('bad_format');
    }
    final from = (decoded['from_device_id'] as String?)?.trim() ?? '';
    final pubB64 = (decoded['from_identity_pub_b64'] as String?)?.trim() ?? '';
    final sigB64 = (decoded['sig_b64'] as String?)?.trim() ?? '';
    final createdAt = (decoded['created_at_ms'] as num?)?.toInt() ?? 0;
    final rawList = decoded['envelopes'];
    if (from.isEmpty || pubB64.isEmpty || sigB64.isEmpty || rawList is! List) {
      throw const EnvelopeFileException('bad_format');
    }
    if (rawList.length > maxEnvelopes) {
      throw const EnvelopeFileException('too_many');
    }
    final envelopes = <OfflineEnvelope>[];
    for (final raw in rawList) {
      final e = raw is Map ? OfflineEnvelope.tryParse(raw.cast<String, Object?>()) : null;
      if (e == null) throw const EnvelopeFileException('bad_envelope');
      envelopes.add(e);
    }
    final known = knownIdentityPubB64?.trim() ?? '';
    if (known.isNotEmpty && known != pubB64) {
      throw const EnvelopeFileException('sender_key_mismatch');
    }
    final bool ok;
    try {
      ok = await _ed.verify(
        _signingBytes(fromDeviceId: from, createdAtMs: createdAt, envelopes: envelopes),
        signature: Signature(
          base64Decode(sigB64),
          publicKey: SimplePublicKey(base64Decode(pubB64), type: KeyPairType.ed25519),
        ),
      );
    } catch (_) {
      throw const EnvelopeFileException('bad_signature');
    }
    if (!ok) throw const EnvelopeFileException('bad_signature');
    return ParsedEnvelopeFile(
      fromDeviceId: from,
      fromIdentityPubB64: pubB64,
      createdAtMs: createdAt,
      envelopes: envelopes,
      senderKeyKnown: known.isNotEmpty,
    );
  }

  /// Имя файла без лишних сведений: ни имени собеседника, ни времени точнее дня.
  static String suggestedFileName(DateTime now) {
    final d = now.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'messages-${d.year}${two(d.month)}${two(d.day)}.$fileExtension';
  }
}

class OfflineEnvelope {
  const OfflineEnvelope({
    required this.msgId,
    required this.toDeviceId,
    required this.ciphertextB64,
  });

  final String msgId;
  final String toDeviceId;
  final String ciphertextB64;

  Map<String, Object?> toJson() => <String, Object?>{
    'msg_id': msgId,
    'to_device_id': toDeviceId,
    'ciphertext_b64': ciphertextB64,
  };

  static OfflineEnvelope? tryParse(Map<String, Object?> json) {
    final msgId = (json['msg_id'] as String?)?.trim() ?? '';
    final to = (json['to_device_id'] as String?)?.trim() ?? '';
    final ct = (json['ciphertext_b64'] as String?)?.trim() ?? '';
    if (msgId.isEmpty || msgId.length > 128 || to.isEmpty || to.length > 128) {
      return null;
    }
    if (ct.isEmpty || ct.length > 2 * 1024 * 1024) return null;
    return OfflineEnvelope(msgId: msgId, toDeviceId: to, ciphertextB64: ct);
  }
}

class ParsedEnvelopeFile {
  const ParsedEnvelopeFile({
    required this.fromDeviceId,
    required this.fromIdentityPubB64,
    required this.createdAtMs,
    required this.envelopes,
    required this.senderKeyKnown,
  });

  final String fromDeviceId;
  final String fromIdentityPubB64;
  final int createdAtMs;
  final List<OfflineEnvelope> envelopes;
  final bool senderKeyKnown;
}

class EnvelopeFileException implements Exception {
  const EnvelopeFileException(this.code);
  final String code;
  @override
  String toString() => 'EnvelopeFileException($code)';
}
