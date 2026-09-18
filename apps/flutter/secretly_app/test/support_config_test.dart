// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/messages/support_flags.dart';

void main() {
  group('secretly-support-v1 config block', () {
    test('supportSigningMessage is the exact canonical string', () {
      // The Rust keys-server must produce byte-identical output.
      expect(
        supportSigningMessage(
            supportEnabled: true, supportPubB64: 'PUBKEY', issuedAtMs: 123),
        'secretly-support-v1|true|PUBKEY|123',
      );
      expect(
        supportSigningMessage(
            supportEnabled: false, supportPubB64: '', issuedAtMs: 0),
        'secretly-support-v1|false||0',
      );
    });

    test('fromConfigResponse fails OFF when the block is unverified', () {
      final cfg = <String, dynamic>{
        'support': {'support_enabled': true, 'support_pub_b64': 'PUBKEY'},
      };
      final c = SupportConfig.fromConfigResponse(cfg, verified: false);
      expect(c.supportEnabled, isFalse);
      expect(c.supportPubB64, isEmpty);
      expect(c.isUsable, isFalse);
    });

    test('fromConfigResponse parses a verified block', () {
      final cfg = <String, dynamic>{
        'support': {'support_enabled': true, 'support_pub_b64': 'PUBKEY'},
      };
      final c = SupportConfig.fromConfigResponse(cfg, verified: true);
      expect(c.supportEnabled, isTrue);
      expect(c.supportPubB64, 'PUBKEY');
      expect(c.isUsable, isTrue);
    });

    test('verified but a missing/blank block → defaults', () {
      expect(SupportConfig.fromConfigResponse(<String, dynamic>{}, verified: true),
          SupportConfig.defaults);
      expect(
          SupportConfig.fromConfigResponse(
              <String, dynamic>{'support': 'oops'},
              verified: true),
          SupportConfig.defaults);
    });

    test('isUsable requires BOTH the flag and a key', () {
      expect(const SupportConfig(supportEnabled: true, supportPubB64: '').isUsable,
          isFalse);
      expect(
          const SupportConfig(supportEnabled: false, supportPubB64: 'PUBKEY')
              .isUsable,
          isFalse);
      expect(
          const SupportConfig(supportEnabled: true, supportPubB64: 'PUBKEY')
              .isUsable,
          isTrue);
    });

    test('verifySupportSignature is false with no config key (fail-OFF)', () async {
      // kConfigPublicKeyB64 is empty under `flutter test` → nothing verifies →
      // the page stays hidden, which is the required failure direction.
      final ok = await verifySupportSignature(<String, dynamic>{
        'support': {'support_enabled': true, 'support_pub_b64': 'PUBKEY'},
        'support_signature': 'AAAA',
      });
      expect(ok, isFalse);
    });
  });
}
