// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/entitlements/entitlement_models.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';

void main() {
  group('canonical signing messages', () {
    test('configSigningMessage matches the documented v2 pipe layout', () {
      final msg = configSigningMessage(
        monetizationEnabled: false,
        freeAttachmentBytes: 26214400,
        freeGroupMembers: 50,
        freeCallParticipants: 8,
        freeOwnedGroups: 5,
        freeJoinedGroups: 20,
        premiumAttachmentBytes: 1073741824,
        premiumGroupMembers: 500,
        premiumCallParticipants: 50,
        premiumOwnedGroups: 100,
        premiumJoinedGroups: -1,
        desktopTrialDays: 14,
        issuedAtMs: 1700000000000,
      );
      expect(
        msg,
        'secretly-config-v2|false|26214400|50|8|5|20|'
        '1073741824|500|50|100|-1|14|1700000000000',
      );
    });

    test('entitlementSigningMessage renders null timestamps as "null"', () {
      final msg = entitlementSigningMessage(
        profileId: 'PROF-1',
        tier: 'free',
        source: 'none',
        expiresAtMs: null,
        graceUntilMs: null,
        features: EntitlementFeatures.none,
        limits: EntitlementLimits.free,
        issuedAtMs: 42,
      );
      expect(
        msg,
        'secretly-entitlements-v2|PROF-1|free|none|null|null|'
        'false|false|false|104857600|10|8|5|20|42',
      );
    });

    test('entitlementSigningMessage renders present timestamps + paid flags', () {
      final msg = entitlementSigningMessage(
        profileId: 'PROF-2',
        tier: 'premium',
        source: 'appstore',
        expiresAtMs: 999,
        graceUntilMs: 1000,
        features: EntitlementFeatures.all,
        limits: EntitlementLimits.premium,
        issuedAtMs: 7,
      );
      expect(
        msg,
        'secretly-entitlements-v2|PROF-2|premium|appstore|999|1000|'
        'true|true|true|1073741824|10|50|100|-1|7',
      );
    });
  });

  group('Ed25519 verification', () {
    test('round-trips a real signature over the canonical message', () async {
      final algo = Ed25519();
      final keyPair = await algo.newKeyPair();
      final pub = await keyPair.extractPublicKey();
      final pubB64 = base64Encode(pub.bytes);

      final message = utf8.encode(
        entitlementSigningMessage(
          profileId: 'P',
          tier: 'legacy',
          source: 'legacy',
          expiresAtMs: null,
          graceUntilMs: null,
          features: EntitlementFeatures.all,
          limits: EntitlementLimits.premium,
          issuedAtMs: 123,
        ),
      );
      final sig = await algo.sign(message, keyPair: keyPair);
      final sigB64 = base64Encode(sig.bytes);

      expect(
        await verifyEd25519B64(
          publicKeyB64: pubB64,
          signatureB64: sigB64,
          message: message,
        ),
        isTrue,
      );
    });

    test('rejects a tampered message', () async {
      final algo = Ed25519();
      final keyPair = await algo.newKeyPair();
      final pub = await keyPair.extractPublicKey();
      final pubB64 = base64Encode(pub.bytes);

      final sig = await algo.sign(utf8.encode('original'), keyPair: keyPair);
      final sigB64 = base64Encode(sig.bytes);

      expect(
        await verifyEd25519B64(
          publicKeyB64: pubB64,
          signatureB64: sigB64,
          message: utf8.encode('tampered'),
        ),
        isFalse,
      );
    });

    test('returns false for empty key or signature', () async {
      expect(
        await verifyEd25519B64(
          publicKeyB64: '',
          signatureB64: 'x',
          message: const [1, 2, 3],
        ),
        isFalse,
      );
      expect(
        await verifyEd25519B64(
          publicKeyB64: 'x',
          signatureB64: '',
          message: const [1, 2, 3],
        ),
        isFalse,
      );
    });

    test('verifyEntitlementSignature is false when no public key is baked in',
        () async {
      // kConfigPublicKeyB64 defaults to empty in test builds → fail open.
      final ok = await verifyEntitlementSignature({
        'profile_id': 'P',
        'tier': 'premium',
        'source': 'appstore',
        'features': EntitlementFeatures.all.toJson(),
        'limits': EntitlementLimits.premium.toJson(),
        'issued_at_ms': 1,
        'signature': 'AAAA',
      });
      expect(ok, isFalse);
    });
  });

  group('verifyConfigSignature (audit §E/R3)', () {
    Map<String, dynamic> configBody({
      required bool enabled,
      String signature = '',
    }) =>
        {
          'payload': {
            'monetization_enabled': enabled,
            'free_limits': EntitlementLimits.free.toJson(),
            'premium_limits': EntitlementLimits.premium.toJson(),
            'desktop_trial_days': 14,
            'issued_at_ms': 1700000000000,
          },
          'signature': signature,
          'alg': 'ed25519',
        };

    test('reconstructs the canonical config message byte-for-byte', () async {
      // Prove the nested /v1/config payload flattens into the documented
      // pipe-string by signing that exact string with a throwaway key and
      // verifying via the shared Ed25519 primitive (verifyConfigSignature
      // itself reads the baked-in const, which is empty under test).
      final algo = Ed25519();
      final keyPair = await algo.newKeyPair();
      final pub = await keyPair.extractPublicKey();
      final pubB64 = base64Encode(pub.bytes);

      final body = configBody(enabled: true);
      final payload = body['payload'] as Map<String, dynamic>;
      final free = payload['free_limits'] as Map<String, dynamic>;
      final premium = payload['premium_limits'] as Map<String, dynamic>;
      final message = utf8.encode(
        configSigningMessage(
          monetizationEnabled: payload['monetization_enabled'] == true,
          freeAttachmentBytes: free['attachment_bytes'] as int,
          freeGroupMembers: free['group_members'] as int,
          freeCallParticipants: free['call_participants'] as int,
          freeOwnedGroups: free['owned_groups'] as int,
          freeJoinedGroups: free['joined_groups'] as int,
          premiumAttachmentBytes: premium['attachment_bytes'] as int,
          premiumGroupMembers: premium['group_members'] as int,
          premiumCallParticipants: premium['call_participants'] as int,
          premiumOwnedGroups: premium['owned_groups'] as int,
          premiumJoinedGroups: premium['joined_groups'] as int,
          desktopTrialDays: payload['desktop_trial_days'] as int,
          issuedAtMs: payload['issued_at_ms'] as int,
        ),
      );
      expect(
        utf8.decode(message),
        'secretly-config-v2|true|104857600|10|8|5|20|'
        '1073741824|10|50|100|-1|14|1700000000000',
      );
      final sig = await algo.sign(message, keyPair: keyPair);
      expect(
        await verifyEd25519B64(
          publicKeyB64: pubB64,
          signatureB64: base64Encode(sig.bytes),
          message: message,
        ),
        isTrue,
      );
    });

    test('false when no public key is baked in (debug/test → fail open)',
        () async {
      // Even a syntactically present signature cannot be trusted with an empty
      // baked-in key; caller fails OPEN on the false result.
      expect(await verifyConfigSignature(configBody(enabled: true, signature: 'AAAA')), isFalse);
    });

    test('false on empty signature', () async {
      expect(await verifyConfigSignature(configBody(enabled: true)), isFalse);
    });

    test('false on malformed/missing payload', () async {
      expect(await verifyConfigSignature({'signature': 'AAAA'}), isFalse);
      expect(
        await verifyConfigSignature({'payload': 'nope', 'signature': 'AAAA'}),
        isFalse,
      );
      expect(
        await verifyConfigSignature({
          'payload': {'monetization_enabled': true},
          'signature': 'AAAA',
        }),
        isFalse,
      );
    });

    test('configSignatureEnforced is false in test builds (no baked key)', () {
      expect(configSignatureEnforced, isFalse);
    });
  });
}
