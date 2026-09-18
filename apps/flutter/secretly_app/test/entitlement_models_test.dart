// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/entitlements/entitlement_models.dart';

void main() {
  group('EntitlementTier', () {
    test('fromWire maps known + unknown values', () {
      expect(entitlementTierFromWire('premium'), EntitlementTier.premium);
      expect(entitlementTierFromWire('lifetime'), EntitlementTier.lifetime);
      expect(entitlementTierFromWire('legacy'), EntitlementTier.legacy);
      expect(entitlementTierFromWire('team'), EntitlementTier.team);
      expect(entitlementTierFromWire('free'), EntitlementTier.free);
      expect(entitlementTierFromWire(null), EntitlementTier.free);
      expect(entitlementTierFromWire('bogus'), EntitlementTier.free);
    });

    test('isPaid is true for everything except free', () {
      expect(EntitlementTier.free.isPaid, isFalse);
      expect(EntitlementTier.premium.isPaid, isTrue);
      expect(EntitlementTier.lifetime.isPaid, isTrue);
      expect(EntitlementTier.legacy.isPaid, isTrue);
      expect(EntitlementTier.team.isPaid, isTrue);
    });

    test('wire round-trips', () {
      for (final t in EntitlementTier.values) {
        expect(entitlementTierFromWire(entitlementTierToWire(t)), t);
      }
    });
  });

  group('EntitlementState fail-open default', () {
    test('open unlocks boolean features but keeps free size baseline', () {
      const s = EntitlementState.open;
      expect(s.monetizationEnabled, isFalse);
      expect(s.unlockEverything, isTrue);
      expect(s.desktopUnlocked, isTrue);
      expect(s.customIdUnlocked, isTrue);
      expect(s.premiumStickersUnlocked, isTrue);
      // Kill-switch-off keeps the pre-freemium 25 MB attachment cap.
      expect(s.attachmentBytesLimit, EntitlementLimits.free.attachmentBytes);
    });
  });

  group('EntitlementState with monetization enabled', () {
    test('free tier gates premium features and limits', () {
      final s = EntitlementState.fromEntitlementJson(
        {
          'tier': 'free',
          'source': 'none',
          'features': EntitlementFeatures.none.toJson(),
          'limits': EntitlementLimits.free.toJson(),
          'issued_at_ms': 1,
        },
        monetizationEnabled: true,
      );
      expect(s.unlockEverything, isFalse);
      expect(s.desktopUnlocked, isFalse);
      expect(s.customIdUnlocked, isFalse);
      expect(s.premiumStickersUnlocked, isFalse);
      expect(s.attachmentBytesLimit, EntitlementLimits.free.attachmentBytes);
    });

    test('free tier with companion desktop feature unlocks only desktop', () {
      final s = EntitlementState.fromEntitlementJson(
        {
          'tier': 'free',
          'source': 'none',
          'features': const {
            'desktop': true,
            'custom_id': false,
            'premium_stickers': false,
          },
          'limits': EntitlementLimits.free.toJson(),
          'issued_at_ms': 1,
        },
        monetizationEnabled: true,
      );
      expect(s.unlockEverything, isFalse);
      expect(s.desktopUnlocked, isTrue);
      expect(s.customIdUnlocked, isFalse);
    });

    test('premium tier unlocks everything + premium limit', () {
      final s = EntitlementState.fromEntitlementJson(
        {
          'tier': 'premium',
          'source': 'appstore',
          'features': EntitlementFeatures.all.toJson(),
          'limits': EntitlementLimits.premium.toJson(),
          'expires_at_ms': 123,
          'issued_at_ms': 1,
        },
        monetizationEnabled: true,
      );
      expect(s.unlockEverything, isTrue);
      expect(s.desktopUnlocked, isTrue);
      expect(s.attachmentBytesLimit, EntitlementLimits.premium.attachmentBytes);
      expect(s.expiresAtMs, 123);
    });
  });

  group('cache serialization', () {
    test('toJson/fromCacheJson round-trips', () {
      final s = EntitlementState.fromEntitlementJson(
        {
          'tier': 'legacy',
          'source': 'legacy',
          'features': EntitlementFeatures.all.toJson(),
          'limits': EntitlementLimits.premium.toJson(),
          'issued_at_ms': 99,
        },
        monetizationEnabled: true,
        signatureVerified: true,
        fetchedAtMs: 555,
      );
      final back = EntitlementState.fromCacheJson(s.toJson());
      expect(back.tier, EntitlementTier.legacy);
      expect(back.source, 'legacy');
      expect(back.monetizationEnabled, isTrue);
      expect(back.signatureVerified, isTrue);
      expect(back.fetchedAtMs, 555);
      expect(back.unlockEverything, isTrue);
    });
  });
}
