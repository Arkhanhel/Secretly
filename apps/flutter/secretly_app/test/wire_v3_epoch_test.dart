// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ratchet/session_manager_v3.dart';
import 'package:secretly_app/ratchet/wire_v3.dart';

// TZ Epic B (2026-07-18): wire-level contract of the session epoch ('se').
void main() {
  final ct = Uint8List.fromList(List<int>.generate(24, (i) => i));

  test('se round-trips in the session header and stays optional', () {
    final withSe = RatchetWireV3.encodeSession(
      senderDeviceId: 'dev-a',
      dhPubB64: 'AAAA',
      pn: 3,
      n: 7,
      ratchetCiphertext: ct,
      se: 1784500000000,
    );
    final decoded = RatchetWireV3.tryDecode(withSe)!;
    expect(decoded.kind, RatchetWireKindV3.session);
    expect((decoded.header['se'] as num).toInt(), 1784500000000);
    expect((decoded.header['n'] as num).toInt(), 7);
  });

  test('legacy byte-compat: omitting se produces the exact pre-Epic-B bytes',
      () {
    // The header bytes double as the AEAD AAD — a wire built WITHOUT se must
    // be byte-identical to what the pre-Epic-B encoder produced.
    final now = RatchetWireV3.encodeSession(
      senderDeviceId: 'dev-a',
      dhPubB64: 'AAAA',
      pn: 1,
      n: 2,
      ratchetCiphertext: ct,
      // se omitted
    );
    final legacyHeader = <String, Object?>{
      'sender_device_id': 'dev-a',
      'dh_pub_b64': 'AAAA',
      'pn': 1,
      'n': 2,
    };
    final decoded = RatchetWireV3.tryDecode(now)!;
    expect(
      utf8.decode(decoded.headerBytes),
      jsonEncode(legacyHeader),
      reason: 'AAD bytes must match the pre-Epic-B layout exactly',
    );
    expect(decoded.header.containsKey('se'), isFalse);
  });

  test('decoder ignores unknown header keys (forward compat)', () {
    final wire = RatchetWireV3.encodeSession(
      senderDeviceId: 'dev-a',
      dhPubB64: 'AAAA',
      pn: 0,
      n: 0,
      ratchetCiphertext: ct,
      se: 5,
    );
    // A legacy receiver reads only the four known fields — presence of 'se'
    // must not affect them.
    final decoded = RatchetWireV3.tryDecode(wire)!;
    expect(decoded.header['sender_device_id'], 'dev-a');
    expect(decoded.header['dh_pub_b64'], 'AAAA');
    expect((decoded.header['pn'] as num).toInt(), 0);
    expect((decoded.header['n'] as num).toInt(), 0);
  });

  test('EpochAheadException carries the comparison + a greppable tag', () {
    final e = EpochAheadException(
      senderDeviceId: 'dev-b',
      wireEpoch: 200,
      localEpoch: 100,
    );
    expect(e.toString(), contains('epoch_ahead'));
    expect(e.wireEpoch, greaterThan(e.localEpoch));
  });
}
