// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Cosmetic free/premium catalog (TZ-MONETIZE-01 §C-3, extended per product spec
// 2026-06-13).
//
// Single data-driven source of truth for which cosmetic presets are FREE.
// Everything not listed here is premium (shown in the showcase with a lock;
// tapping it opens the paywall with trigger `cosmetic`). Adding the future
// ~100 premium themes/wallpapers requires NO code change — they're simply
// absent from the free sets below.
//
// HARD RULE (anti-list / "не урезать бесплатное"): never remove an id a user
// might already have selected. These sets only ever GROW.
//
// Security features are never represented here.

import 'entitlement_models.dart';
import 'feature_gate.dart';

/// Free app theme preset ids (everything else in `kAppThemePresets` is premium).
/// Product decision: Standard (flutter_dash), Ocean, Graphite.
const Set<String> kFreeThemeIds = {
  'flutter_dash',
  'ocean',
  'graphite',
};

/// Бесплатные градиенты пузырей — ПЕРВЫЕ ДЕВЯТЬ из `kChatBubbleStylePresets`.
/// Всё, что идёт после «Неона», — премиальное.
const Set<String> kFreeBubbleStyleIds = {
  // 🔴 ПЕРЕПИСАН 23.09.2026 ВМЕСТЕ С НАБОРОМ ГРАДИЕНТОВ.
  //
  // Здесь лежат ОПОЗНАВАТЕЛИ, а набор заменён целиком: прежние девять указывали
  // на то, чего больше нет, и бесплатный тариф остался бы вовсе без доступных
  // градиентов. Поймала это проверка `cosmetic_catalog_test`, а не глаз.
  //
  // Правило прежнее — бесплатны ПЕРВЫЕ ДЕВЯТЬ набора. Это первые девять из
  // основной группы страницы дизайна; «Графит», «классика» и «яркие» остаются
  // премиальными, как и раньше остаток списка.
  'aurora_borealis',
  'golden_hour',
  'deep',
  'sakura',
  'lava',
  'mint',
  'nebula',
  'dunes',
  'neon',
};

/// Free indicator (accent) colour ids. Product decision: 3 free —
/// `theme` (follows the theme), `blue`, `emerald`.
const Set<String> kFreeIndicatorColorIds = {
  'theme',
  'blue',
  'emerald',
};

/// Premium wallpaper ids. Currently EMPTY — every wallpaper shipped today stays
/// free (product decision). Future packs get their ids added here.
const Set<String> kPremiumWallpaperIds = {};

/// The kind of cosmetic being checked (drives which free set is consulted).
enum CosmeticKind {
  theme,
  bubbleStyle,
  indicatorColor,
  wallpaper,
  avatarFrame,
  profileCover,
}

/// True when [id] of [kind] is part of the free catalog.
bool isCosmeticFree(CosmeticKind kind, String id) {
  switch (kind) {
    case CosmeticKind.theme:
      return kFreeThemeIds.contains(id);
    case CosmeticKind.bubbleStyle:
      return kFreeBubbleStyleIds.contains(id);
    case CosmeticKind.indicatorColor:
      return kFreeIndicatorColorIds.contains(id);
    case CosmeticKind.wallpaper:
      // Server-hosted wallpapers (id `server:<item>`) and animated wallpapers
      // (id `anim:<style>`) are premium. Other bundled wallpapers are free
      // unless explicitly listed in kPremiumWallpaperIds.
      if (id.startsWith('server:')) return false;
      if (id.startsWith('anim:')) return false;
      return !kPremiumWallpaperIds.contains(id);
    case CosmeticKind.avatarFrame:
    case CosmeticKind.profileCover:
      // Premium animated frames/covers are paid-only — no free ids.
      return false;
  }
}

/// Whether the current entitlement state allows selecting cosmetic [id] of
/// [kind]. Free items are always allowed; premium items require the cosmetic
/// gate to be unlocked (paid tier or kill-switch off → fail open).
bool isCosmeticAllowed(EntitlementState? state, CosmeticKind kind, String id) {
  if (isCosmeticFree(kind, id)) return true;
  return FeatureGate.isUnlocked(state, GatedFeature.cosmetic);
}

// ── Profile icons (avatar icon library) ──────────────────────────────────────
//
// Gating is POSITIONAL rather than id-based: the first [kFreeProfileIconCount]
// entries of `profileIconAssetCatalog` (lib/ui) are free; everything after is
// premium. Kept as a count (not an id set) so this entitlements file need not
// import the ui catalog. Product decision: 50 free / rest premium.
//
// HARD RULE: only ever GROW the free prefix — never shrink it, so a user can't
// lose an icon they already picked.
const int kFreeProfileIconCount = 50;

/// Whether the profile icon at [catalogIndex] (its position in
/// `profileIconAssetCatalog`) may be selected under [state]. Free prefix is
/// always allowed; the rest needs the cosmetic gate (paid / kill-switch off →
/// fail open).
bool isProfileIconAllowed(EntitlementState? state, int catalogIndex) {
  if (catalogIndex < kFreeProfileIconCount) return true;
  return FeatureGate.isUnlocked(state, GatedFeature.cosmetic);
}

// ── Notification ringtones (incoming-message tone) ───────────────────────────
//
// Free ringtone ids are the filename stems under assets/app_ui/sounds/noti/.
// Product decision: 5 free, the rest premium. Adding more premium tones requires
// NO code change — drop the file in, add its stem to the picker, and it is
// premium by default (absent from the free set below). Only ever GROW this set.
const Set<String> kFreeRingtoneIds = {
  'bubble_mail',
  'bubbles_v1',
  'drip_drop',
  'pingo',
  'splash',
};

/// Whether notification ringtone [id] (filename stem) may be selected under
/// [state]. Free tones always allowed; premium tones need the cosmetic gate.
bool isRingtoneAllowed(EntitlementState? state, String id) {
  if (kFreeRingtoneIds.contains(id)) return true;
  return FeatureGate.isUnlocked(state, GatedFeature.cosmetic);
}

/// Free call-ringtone ids. Product decision: the default tone is free; premium
/// unlocks the alternatives (beacon, chime, …). Only ever GROW this set.
const Set<String> kFreeCallRingtoneIds = {'default'};

/// Whether call ringtone [id] may be selected under [state]. Free tone always
/// allowed; premium tones need the cosmetic gate (paid / kill-switch off → open).
bool isCallRingtoneAllowed(EntitlementState? state, String id) {
  if (kFreeCallRingtoneIds.contains(id)) return true;
  return FeatureGate.isUnlocked(state, GatedFeature.cosmetic);
}
