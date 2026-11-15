// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/entitlements/cosmetic_catalog.dart';
import 'package:secretly_app/entitlements/entitlement_models.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';
import 'package:secretly_app/ui/theme_presets.dart';

EntitlementState _free() => const EntitlementState(
      monetizationEnabled: true,
      tier: EntitlementTier.free,
      source: 'none',
      features: EntitlementFeatures.none,
      limits: EntitlementLimits.free,
    );

EntitlementState _premium() => const EntitlementState(
      monetizationEnabled: true,
      tier: EntitlementTier.premium,
      source: 'appstore',
      features: EntitlementFeatures.all,
      limits: EntitlementLimits.premium,
    );

void main() {
  group('free catalog matches product spec', () {
    test('exactly 3 free themes: standard/ocean/graphite', () {
      expect(kFreeThemeIds, {'flutter_dash', 'ocean', 'graphite'});
      expect(isCosmeticFree(CosmeticKind.theme, 'flutter_dash'), isTrue);
      expect(isCosmeticFree(CosmeticKind.theme, 'amethyst'), isFalse);
    });

    test('free bubble styles are the first 9 presets', () {
      final firstNine =
          kChatBubbleStylePresets.take(9).map((p) => p.id).toSet();
      expect(kFreeBubbleStyleIds, firstNine);
      // The 10th preset onward is premium.
      expect(isCosmeticFree(CosmeticKind.bubbleStyle,
          kChatBubbleStylePresets[9].id), isFalse);
    });

    test('3 free indicator colors', () {
      expect(kFreeIndicatorColorIds.length, 3);
      expect(isCosmeticFree(CosmeticKind.indicatorColor, 'theme'), isTrue);
      expect(isCosmeticFree(CosmeticKind.indicatorColor, 'orange'), isFalse);
    });

    test('all current wallpapers are free', () {
      expect(kPremiumWallpaperIds, isEmpty);
      expect(isCosmeticFree(CosmeticKind.wallpaper, 'any_existing_id'), isTrue);
    });

    // Решение владельца 13.11.2026: 10 бесплатных — 6 рамок и 4 обложки.
    test('6 free frames and 4 free covers, all of them real catalog ids', () {
      expect(kFreeAvatarFrameIds, hasLength(6));
      expect(kFreeProfileCoverIds, hasLength(4));
      final frameIds = kAllAvatarFrames.map((f) => f.id).toSet();
      final coverIds = kAllProfileCovers.map((c) => c.id).toSet();
      expect(frameIds.containsAll(kFreeAvatarFrameIds), isTrue);
      expect(coverIds.containsAll(kFreeProfileCoverIds), isTrue);
    });

    test('free frame/cover allowed on free tier, the rest is Premium', () {
      expect(isCosmeticAllowed(_free(), CosmeticKind.avatarFrame, 'neon'), isTrue);
      expect(isCosmeticAllowed(_free(), CosmeticKind.profileCover, 'waves'), isTrue);
      expect(isCosmeticAllowed(_free(), CosmeticKind.avatarFrame, 'cat'), isFalse);
      expect(isCosmeticAllowed(_free(), CosmeticKind.profileCover, 'blackhole'), isFalse);
      expect(isCosmeticAllowed(_free(), CosmeticKind.profileCover, 'custom'), isFalse);
      expect(isCosmeticAllowed(_premium(), CosmeticKind.avatarFrame, 'cat'), isTrue);
    });

    // Проба 'x' отвечает «оплачен ли Premium» — эмодзи-статус, иконка
    // приложения, своя обложка. Бесплатный id с таким именем сломал бы их.
    test("probe id 'x' is never free", () {
      expect(isCosmeticFree(CosmeticKind.avatarFrame, 'x'), isFalse);
      expect(isCosmeticFree(CosmeticKind.profileCover, 'x'), isFalse);
    });
  });

  group('isCosmeticAllowed', () {
    test('free item always allowed regardless of tier', () {
      expect(isCosmeticAllowed(_free(), CosmeticKind.theme, 'graphite'), isTrue);
    });

    test('premium item blocked for free tier, allowed for premium', () {
      expect(isCosmeticAllowed(_free(), CosmeticKind.theme, 'amethyst'), isFalse);
      expect(
          isCosmeticAllowed(_premium(), CosmeticKind.theme, 'amethyst'), isTrue);
    });

    test('kill-switch off (null state) allows premium cosmetics (fail open)', () {
      expect(isCosmeticAllowed(null, CosmeticKind.theme, 'amethyst'), isTrue);
    });
  });

  group('isProfileIconAllowed (positional 50-free gate)', () {
    test('first 50 icons are free for the free tier', () {
      expect(kFreeProfileIconCount, 50);
      expect(isProfileIconAllowed(_free(), 0), isTrue);
      expect(isProfileIconAllowed(_free(), 49), isTrue);
    });

    test('icon 50+ blocked for free, allowed for premium', () {
      expect(isProfileIconAllowed(_free(), 50), isFalse);
      expect(isProfileIconAllowed(_free(), 700), isFalse);
      expect(isProfileIconAllowed(_premium(), 50), isTrue);
      expect(isProfileIconAllowed(_premium(), 700), isTrue);
    });

    test('kill-switch off (null state) allows premium icons (fail open)', () {
      expect(isProfileIconAllowed(null, 700), isTrue);
    });
  });

  group('isRingtoneAllowed (5-free notification tones)', () {
    test('exactly 5 free ringtones', () {
      expect(kFreeRingtoneIds.length, 5);
      expect(kFreeRingtoneIds.contains('bubble_mail'), isTrue);
    });

    test('free tone always allowed; premium tone gated by tier', () {
      expect(isRingtoneAllowed(_free(), 'bubble_mail'), isTrue);
      expect(isRingtoneAllowed(_free(), 'xiaomi_notification'), isFalse);
      expect(isRingtoneAllowed(_premium(), 'xiaomi_notification'), isTrue);
    });

    test('kill-switch off (null state) allows premium tones (fail open)', () {
      expect(isRingtoneAllowed(null, 'xiaomi_notification'), isTrue);
    });
  });

  group('isCallRingtoneAllowed (default free, alternatives premium)', () {
    test('default tone free; alternatives gated by tier', () {
      expect(kFreeCallRingtoneIds, {'default'});
      expect(isCallRingtoneAllowed(_free(), 'default'), isTrue);
      expect(isCallRingtoneAllowed(_free(), 'beacon'), isFalse);
      expect(isCallRingtoneAllowed(_free(), 'chime'), isFalse);
      expect(isCallRingtoneAllowed(_premium(), 'chime'), isTrue);
    });

    test('kill-switch off (null state) allows premium call tones (fail open)', () {
      expect(isCallRingtoneAllowed(null, 'chime'), isTrue);
    });
  });
}
