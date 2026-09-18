// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/messages/identity_flags.dart';

void main() {
  group('identitySigningMessage', () {
    // Must match Rust `identity_signing_message` byte-for-byte, and must NOT
    // be folded into secretly-config-v2 (that message is verified verbatim by
    // every already-shipped client).
    test('mirrors the Rust canonical message', () {
      expect(
        identitySigningMessage(
          rotationOnStateLossEnabled: true,
          issuedAtMs: 42,
        ),
        'secretly-identity-v1|true|42',
      );
    });
  });

  group('IdentityFlags.fromConfigResponse', () {
    Map<String, dynamic> configWith({required bool rotation}) =>
        <String, dynamic>{
          'identity': <String, dynamic>{
            'rotation_on_state_loss_enabled': rotation,
          },
          'identity_signature': 'irrelevant-here',
        };

    // THE invariant, and the OPPOSITE polarity from ReliabilityFlags: rotation
    // on state loss is NEW behaviour with visible consequences (peers see a
    // new device, the safety number changes), so it stays DORMANT until a
    // VERIFIED block switches it on. Nothing unauthenticated may enable it.
    test('defaults are dormant (rotation off)', () {
      expect(IdentityFlags.defaults.rotationOnStateLossEnabled, isFalse);
    });

    test('an unverified block cannot enable rotation', () {
      final flags = IdentityFlags.fromConfigResponse(
        configWith(rotation: true),
        verified: false,
      );
      expect(flags, IdentityFlags.defaults);
      expect(flags.rotationOnStateLossEnabled, isFalse);
    });

    test('a verified block enables rotation', () {
      final flags = IdentityFlags.fromConfigResponse(
        configWith(rotation: true),
        verified: true,
      );
      expect(flags.rotationOnStateLossEnabled, isTrue);
    });

    test('a verified block can also switch it back off', () {
      final flags = IdentityFlags.fromConfigResponse(
        configWith(rotation: false),
        verified: true,
      );
      expect(flags.rotationOnStateLossEnabled, isFalse);
    });

    // An older server that predates the block must read as dormant, not crash
    // and not accidentally enable.
    test('a missing block stays dormant even when verified', () {
      expect(
        IdentityFlags.fromConfigResponse(
          <String, dynamic>{'payload': <String, dynamic>{}},
          verified: true,
        ),
        IdentityFlags.defaults,
      );
    });
  });
}
