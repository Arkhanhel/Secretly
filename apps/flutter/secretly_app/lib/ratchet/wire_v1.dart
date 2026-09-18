// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'session_v1.dart';

enum RatchetWireKindV1 {
  session(0),
  prekey(1);

  const RatchetWireKindV1(this.code);
  final int code;

  static RatchetWireKindV1 fromCode(int v) {
    return switch (v) {
      0 => RatchetWireKindV1.session,
      1 => RatchetWireKindV1.prekey,
      _ => throw StateError('unknown wire kind: $v'),
    };
  }
}

class RatchetWireDecodedV1 {
  const RatchetWireDecodedV1({
    required this.kind,
    required this.header,
    required this.ciphertext,
  });

  final RatchetWireKindV1 kind;
  final Map<String, dynamic> header;
  final Uint8List ciphertext;
}

class RatchetWireV1 {
  static const _magic = <int>[0x53, 0x4B, 0x53, 0x31]; // "SKS1"

  static Uint8List encodeSession({
    required String senderDeviceId,
    required Uint8List ratchetCiphertext,
  }) {
    final header = <String, Object?>{
      'sender_device_id': senderDeviceId,
    };
    return _encode(kind: RatchetWireKindV1.session, header: header, ciphertext: ratchetCiphertext);
  }

  static Uint8List encodePrekey({
    required PrekeyHeaderV1 header,
    required Uint8List ratchetCiphertext,
  }) {
    return _encode(kind: RatchetWireKindV1.prekey, header: header.toJson(), ciphertext: ratchetCiphertext);
  }

  static Uint8List _encode({
    required RatchetWireKindV1 kind,
    required Map<String, Object?> header,
    required Uint8List ciphertext,
  }) {
    final headerBytes = Uint8List.fromList(utf8.encode(jsonEncode(header)));
    if (headerBytes.length > 65535) throw StateError('header too large');

    final out = Uint8List(_magic.length + 1 + 2 + headerBytes.length + ciphertext.length);
    var o = 0;

    out.setRange(o, o + _magic.length, _magic);
    o += _magic.length;

    out[o++] = kind.code;

    out[o++] = (headerBytes.length >> 8) & 0xFF;
    out[o++] = headerBytes.length & 0xFF;

    out.setRange(o, o + headerBytes.length, headerBytes);
    o += headerBytes.length;

    out.setRange(o, o + ciphertext.length, ciphertext);

    return out;
  }

  static RatchetWireDecodedV1? tryDecode(Uint8List bytes) {
    if (bytes.length < _magic.length + 1 + 2) return null;

    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return null;
    }

    var o = _magic.length;
    final kind = RatchetWireKindV1.fromCode(bytes[o++]);

    final headerLen = (bytes[o++] << 8) | bytes[o++];
    if (bytes.length < _magic.length + 1 + 2 + headerLen) {
      throw StateError('truncated header');
    }

    final headerBytes = bytes.sublist(o, o + headerLen);
    o += headerLen;

    final header = jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;
    final ciphertext = Uint8List.fromList(bytes.sublist(o));

    return RatchetWireDecodedV1(kind: kind, header: header, ciphertext: ciphertext);
  }
}
