// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/messages/reliability_flags.dart';

void main() {
  group('reliabilitySigningMessage', () {
    // Must match Rust `reliability_signing_message` byte-for-byte, and must NOT
    // be folded into secretly-config-v2 (that message is verified verbatim by
    // every already-shipped client).
    test('mirrors the Rust canonical message', () {
      expect(
        reliabilitySigningMessage(
          nackReceiptsEnabled: true,
          convergenceResendEnabled: false,
          issuedAtMs: 42,
        ),
        'secretly-reliability-v1|true|false|42',
      );
    });
  });

  group('ReliabilityFlags.fromConfigResponse', () {
    Map<String, dynamic> configWith({
      required bool nack,
      required bool resend,
    }) => <String, dynamic>{
      'reliability': <String, dynamic>{
        'nack_receipts_enabled': nack,
        'convergence_resend_enabled': resend,
      },
      'reliability_signature': 'irrelevant-here',
    };

    test('defaults are everything ON', () {
      expect(ReliabilityFlags.defaults.nackReceiptsEnabled, isTrue);
      expect(ReliabilityFlags.defaults.convergenceResendEnabled, isTrue);
    });

    // THE invariant: the healing machinery is a safety net against silent
    // message loss, so an UNVERIFIED block must never be able to switch it off.
    // A forged/stripped config can only fail to disable, never succeed.
    test('an unverified block cannot disable anything', () {
      final flags = ReliabilityFlags.fromConfigResponse(
        configWith(nack: false, resend: false),
        verified: false,
      );
      expect(flags, ReliabilityFlags.defaults);
      expect(flags.nackReceiptsEnabled, isTrue);
      expect(flags.convergenceResendEnabled, isTrue);
    });

    test('a verified block turns switches off', () {
      final flags = ReliabilityFlags.fromConfigResponse(
        configWith(nack: false, resend: true),
        verified: true,
      );
      expect(flags.nackReceiptsEnabled, isFalse);
      expect(flags.convergenceResendEnabled, isTrue);
    });

    // An older server that predates the block, or any response missing it,
    // must leave the machinery running rather than reading absence as "off".
    test('a missing block keeps the defaults even when verified', () {
      expect(
        ReliabilityFlags.fromConfigResponse(
          <String, dynamic>{'payload': <String, dynamic>{}},
          verified: true,
        ),
        ReliabilityFlags.defaults,
      );
    });
  });
}
