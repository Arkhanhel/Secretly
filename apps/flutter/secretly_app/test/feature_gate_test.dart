// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/entitlements/entitlement_models.dart';
import 'package:secretly_app/entitlements/feature_gate.dart';

EntitlementState _state({
  required bool monetizationEnabled,
  required EntitlementTier tier,
  EntitlementFeatures? features,
  EntitlementLimits? limits,
}) {
  return EntitlementState(
    monetizationEnabled: monetizationEnabled,
    tier: tier,
    source: 'test',
    features: features ?? EntitlementFeatures.none,
    limits: limits ?? EntitlementLimits.free,
  );
}

void main() {
  group('fail-open', () {
    test('null state unlocks boolean features but keeps free size baseline', () {
      for (final f in GatedFeature.values) {
        expect(FeatureGate.isUnlocked(null, f), isTrue, reason: '$f');
      }
      // Size ceilings stay at the free baseline (kill-switch-off must not raise
      // limits above pre-freemium behaviour).
      expect(FeatureGate.attachmentBytesLimit(null),
          EntitlementLimits.free.attachmentBytes);
      expect(FeatureGate.groupMembersLimit(null),
          EntitlementLimits.free.groupMembers);
      expect(FeatureGate.callParticipantsLimit(null),
          EntitlementLimits.free.callParticipants);
    });

    test('monetization disabled unlocks boolean features, keeps free sizes', () {
      final s = _state(
        monetizationEnabled: false,
        tier: EntitlementTier.free,
      );
      for (final f in GatedFeature.values) {
        expect(FeatureGate.isUnlocked(s, f), isTrue, reason: '$f');
      }
      expect(FeatureGate.attachmentBytesLimit(s),
          EntitlementLimits.free.attachmentBytes);
    });
  });

  group('monetization enabled', () {
    test('free tier locks all premium features + uses free limits', () {
      final s = _state(
        monetizationEnabled: true,
        tier: EntitlementTier.free,
      );
      expect(FeatureGate.isUnlocked(s, GatedFeature.desktop), isFalse);
      expect(FeatureGate.isUnlocked(s, GatedFeature.customId), isFalse);
      expect(FeatureGate.isUnlocked(s, GatedFeature.premiumStickers), isFalse);
      expect(FeatureGate.isUnlocked(s, GatedFeature.cosmetic), isFalse);
      expect(FeatureGate.attachmentBytesLimit(s),
          EntitlementLimits.free.attachmentBytes);
      expect(FeatureGate.groupMembersLimit(s),
          EntitlementLimits.free.groupMembers);
      expect(FeatureGate.callParticipantsLimit(s),
          EntitlementLimits.free.callParticipants);
    });

    test('premium tier unlocks everything + premium limits', () {
      final s = _state(
        monetizationEnabled: true,
        tier: EntitlementTier.premium,
        features: EntitlementFeatures.all,
        limits: EntitlementLimits.premium,
      );
      for (final f in GatedFeature.values) {
        expect(FeatureGate.isUnlocked(s, f), isTrue, reason: '$f');
      }
      expect(FeatureGate.attachmentBytesLimit(s),
          EntitlementLimits.premium.attachmentBytes);
    });

    test('free tier with companion desktop feature unlocks only desktop', () {
      final s = _state(
        monetizationEnabled: true,
        tier: EntitlementTier.free,
        features: const EntitlementFeatures(
          desktop: true,
          customId: false,
          premiumStickers: false,
        ),
      );
      expect(FeatureGate.isUnlocked(s, GatedFeature.desktop), isTrue);
      expect(FeatureGate.isUnlocked(s, GatedFeature.customId), isFalse);
      expect(FeatureGate.isUnlocked(s, GatedFeature.cosmetic), isFalse);
    });
  });

  group('attachment gate', () {
    test('free tier rejects oversized but allows within free limit', () {
      final s = _state(
        monetizationEnabled: true,
        tier: EntitlementTier.free,
      );
      expect(FeatureGate.attachmentAllowed(s, EntitlementLimits.free.attachmentBytes),
          isTrue);
      expect(
          FeatureGate.attachmentAllowed(
              s, EntitlementLimits.free.attachmentBytes + 1),
          isFalse);
    });

    test('premium allows large attachments', () {
      final s = _state(
        monetizationEnabled: true,
        tier: EntitlementTier.premium,
        limits: EntitlementLimits.premium,
      );
      expect(
          FeatureGate.attachmentAllowed(
              s, EntitlementLimits.free.attachmentBytes + 1),
          isTrue);
    });
  });

  group('group count limits', () {
    test('free tier: create 5, join 20', () {
      final s = _state(monetizationEnabled: true, tier: EntitlementTier.free);
      expect(FeatureGate.ownedGroupsLimit(s), 5);
      expect(FeatureGate.joinedGroupsLimit(s), 20);
      expect(FeatureGate.canCreateGroup(s, 4), isTrue);
      expect(FeatureGate.canCreateGroup(s, 5), isFalse); // at cap
      expect(FeatureGate.canJoinGroup(s, 19), isTrue);
      expect(FeatureGate.canJoinGroup(s, 20), isFalse);
    });

    test('premium: create 100, join unlimited (-1)', () {
      final s = _state(
        monetizationEnabled: true,
        tier: EntitlementTier.premium,
        limits: EntitlementLimits.premium,
      );
      expect(FeatureGate.ownedGroupsLimit(s), 100);
      expect(FeatureGate.joinedGroupsLimit(s), -1);
      expect(FeatureGate.canCreateGroup(s, 99), isTrue);
      expect(FeatureGate.canCreateGroup(s, 100), isFalse);
      // unlimited join
      expect(FeatureGate.canJoinGroup(s, 100000), isTrue);
    });

    test('kill-switch off (null state) = unlimited groups (pre-freemium)', () {
      // Group COUNT was unlimited before freemium, so a disabled kill-switch
      // must report unlimited (-1), not the free cap.
      expect(FeatureGate.ownedGroupsLimit(null), -1);
      expect(FeatureGate.joinedGroupsLimit(null), -1);
      expect(FeatureGate.canCreateGroup(null, 999), isTrue);
      expect(FeatureGate.canJoinGroup(null, 999), isTrue);
    });

    test('monetization disabled but free tier = still unlimited', () {
      final s = _state(monetizationEnabled: false, tier: EntitlementTier.free);
      expect(FeatureGate.ownedGroupsLimit(s), -1);
      expect(FeatureGate.canCreateGroup(s, 999), isTrue);
    });
  });

  test('paywallTriggerFor maps features to trigger strings', () {
    expect(paywallTriggerFor(GatedFeature.desktop), 'desktop');
    expect(paywallTriggerFor(GatedFeature.customId), 'id');
    expect(paywallTriggerFor(GatedFeature.attachment), 'file');
    expect(paywallTriggerFor(GatedFeature.group), 'group');
    expect(paywallTriggerFor(GatedFeature.cosmetic), 'cosmetic');
    expect(paywallTriggerFor(GatedFeature.premiumStickers), 'cosmetic');
  });
}
