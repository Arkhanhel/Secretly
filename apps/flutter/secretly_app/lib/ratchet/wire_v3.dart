// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

/// v1.3 Double Ratchet wire format.
///
/// Wrapper layout:
///   magic "SKS2" + kind(1) + header_len(2) + header_json + ciphertext
///
/// Header (session messages) includes:
///   sender_device_id: String
///   dh_pub_b64: String (X25519 public key)
///   pn: int (previous sending chain length)
///   n: int (message number in current sending chain)
///
/// Prekey header is still JSON and may include v1.2 fields; we treat it as an
/// initiator's first DR message (kind=prekey).

enum RatchetWireKindV3 {
  session(0),
  prekey(1);

  const RatchetWireKindV3(this.code);
  final int code;

  static RatchetWireKindV3 fromCode(int v) {
    return switch (v) {
      0 => RatchetWireKindV3.session,
      1 => RatchetWireKindV3.prekey,
      _ => throw StateError('unknown wire kind: $v'),
    };
  }
}

class RatchetWireDecodedV3 {
  const RatchetWireDecodedV3({
    required this.kind,
    required this.header,
    required this.headerBytes,
    required this.ciphertext,
  });

  final RatchetWireKindV3 kind;
  final Map<String, dynamic> header;
  final Uint8List headerBytes;
  final Uint8List ciphertext;
}

class RatchetWireV3 {
  static const _magic = <int>[0x53, 0x4B, 0x53, 0x32]; // "SKS2"

  static Uint8List encodeSession({
    required String senderDeviceId,
    required String dhPubB64,
    required int pn,
    required int n,
    required Uint8List ratchetCiphertext,
    // TZ Epic B (2026-07-18): session epoch — the creation wall-ms of the
    // session this wire is encrypted under, so a receiver that is still on an
    // OLDER session can classify the failure as "rekey en route" (park +
    // replay-after-adoption) instead of a generic decrypt error. Appended LAST
    // so the header byte layout (which doubles as the AEAD AAD) is unchanged
    // for header maps built without it; absent for legacy senders.
    int? se,
  }) {
    final header = <String, Object?>{
      'sender_device_id': senderDeviceId,
      'dh_pub_b64': dhPubB64,
      'pn': pn,
      'n': n,
      if (se != null && se > 0) 'se': se,
    };
    return _encode(kind: RatchetWireKindV3.session, header: header, ciphertext: ratchetCiphertext);
  }

  static Uint8List encodePrekey({
    required Map<String, Object?> header,
    required Uint8List ratchetCiphertext,
  }) {
    return _encode(kind: RatchetWireKindV3.prekey, header: header, ciphertext: ratchetCiphertext);
  }

  static Uint8List _encode({
    required RatchetWireKindV3 kind,
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

  static RatchetWireDecodedV3? tryDecode(Uint8List bytes) {
    if (bytes.length < _magic.length + 1 + 2) return null;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return null;
    }

    var o = _magic.length;
    final kind = RatchetWireKindV3.fromCode(bytes[o++]);

    final headerLen = (bytes[o++] << 8) | bytes[o++];
    if (bytes.length < _magic.length + 1 + 2 + headerLen) {
      throw StateError('truncated header');
    }

    final headerBytes = Uint8List.fromList(bytes.sublist(o, o + headerLen));
    o += headerLen;

    final header = jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;
    final ciphertext = Uint8List.fromList(bytes.sublist(o));
    return RatchetWireDecodedV3(kind: kind, header: header, headerBytes: headerBytes, ciphertext: ciphertext);
  }
}
