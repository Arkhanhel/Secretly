// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Centralized feature gating (TZ-MONETIZE-01 §C-3).
//
// Single source of truth for "is this premium feature unlocked for the current
// entitlement state". Every UI gate reads through here so the fail-open rule is
// enforced in exactly one place: while monetization is disabled (kill-switch
// off) or the profile holds a paid/grandfathered tier, EVERYTHING is unlocked.
//
// Security features (TZ Appendix B) are NEVER represented here and must never
// be routed through this gate.

import 'entitlement_models.dart';

/// The set of monetizable features. Maps 1:1 to the C-3 gating table and the
/// paywall `trigger` parameter (C-4).
enum GatedFeature {
  /// Desktop / multi-device companion linking.
  desktop,

  /// Custom Secretly ID.
  customId,

  /// Premium sticker packs.
  premiumStickers,

  /// On-device voice-to-text: composer dictation + voice-message transcription.
  voiceToText,

  /// Cosmetic catalog: premium themes / accents / chat wallpapers.
  cosmetic,

  /// Large attachments (size-based; see [FeatureGate.attachmentBytesLimit]).
  attachment,

  /// Large groups / calls (size-based; see the *Limit getters).
  group,
}

/// Thrown by gated operations (e.g. group creation/join) when the current
/// entitlement does not allow them. The UI catches this and shows the paywall
/// for [feature]. Existing content is never affected — only new actions.
class FeatureLockedException implements Exception {
  const FeatureLockedException(this.feature, [this.message]);
  final GatedFeature feature;
  final String? message;
  @override
  String toString() => 'FeatureLockedException(${feature.name})';
}

/// The paywall trigger string for a gated feature (matches C-4 `trigger`).
String paywallTriggerFor(GatedFeature feature) {
  switch (feature) {
    case GatedFeature.desktop:
      return 'desktop';
    case GatedFeature.customId:
      return 'id';
    case GatedFeature.premiumStickers:
      return 'cosmetic';
    case GatedFeature.voiceToText:
      return 'general';
    case GatedFeature.cosmetic:
      return 'cosmetic';
    case GatedFeature.attachment:
      return 'file';
    case GatedFeature.group:
      return 'group';
  }
}

/// Pure gating decisions over an [EntitlementState]. Stateless; the caller
/// supplies the current snapshot (or null → treated as fully open).
class FeatureGate {
  const FeatureGate._();

  static EntitlementState _resolve(EntitlementState? state) =>
      state ?? EntitlementState.open;

  /// Whether [feature]'s boolean gate is unlocked. Size-based features
  /// ([GatedFeature.attachment], [GatedFeature.group]) are "unlocked" only in
  /// the sense that the premium ceiling applies — use the limit getters for the
  /// actual numeric check.
  static bool isUnlocked(EntitlementState? state, GatedFeature feature) {
    final s = _resolve(state);
    switch (feature) {
      case GatedFeature.desktop:
        return s.desktopUnlocked;
      case GatedFeature.customId:
        return s.customIdUnlocked;
      case GatedFeature.premiumStickers:
        return s.premiumStickersUnlocked;
      case GatedFeature.voiceToText:
        // On-device voice-to-text unlocks with any paid tier (or kill-switch).
        return s.unlockEverything;
      case GatedFeature.cosmetic:
        // Premium cosmetics unlock together with any paid tier (or kill-switch).
        return s.unlockEverything;
      case GatedFeature.attachment:
      case GatedFeature.group:
        // Size gates have no boolean form; full access only when everything is
        // unlocked. Prefer the numeric limit getters for real checks.
        return s.unlockEverything;
    }
  }

  /// Effective max attachment size in bytes for the current state.
  static int attachmentBytesLimit(EntitlementState? state) =>
      _resolve(state).attachmentBytesLimit;

  /// Effective max group member count. Only a positive paid tier raises it
  /// above the free baseline (kill-switch-off / fail-open keep the baseline).
  static int groupMembersLimit(EntitlementState? state) {
    final s = _resolve(state);
    return s.tier.isPaid
        ? s.limits.groupMembers
        : EntitlementLimits.free.groupMembers;
  }

  /// Effective max call participant count (same paid-tier rule as above).
  static int callParticipantsLimit(EntitlementState? state) {
    final s = _resolve(state);
    return s.tier.isPaid
        ? s.limits.callParticipants
        : EntitlementLimits.free.callParticipants;
  }

  /// Effective max number of groups the profile may OWN/create. -1 = unlimited.
  ///
  /// Unlike attachment SIZE (pre-freemium was already 25 MB), group COUNT was
  /// UNLIMITED before freemium — so a disabled kill-switch must report unlimited
  /// (-1), not the free cap, to preserve current behaviour exactly.
  static int ownedGroupsLimit(EntitlementState? state) {
    final s = _resolve(state);
    if (!s.monetizationEnabled) return -1; // pre-freemium: no group cap
    return s.tier.isPaid
        ? s.limits.ownedGroups
        : EntitlementLimits.free.ownedGroups;
  }

  /// Effective max number of groups the profile may be a member of.
  /// -1 = unlimited. Kill-switch off → unlimited (pre-freemium behaviour).
  static int joinedGroupsLimit(EntitlementState? state) {
    final s = _resolve(state);
    if (!s.monetizationEnabled) return -1;
    return s.tier.isPaid
        ? s.limits.joinedGroups
        : EntitlementLimits.free.joinedGroups;
  }

  /// True when creating one more owned group is allowed given [currentOwned].
  /// A limit of -1 means unlimited. Existing groups are always grandfathered —
  /// this only gates NEW creation.
  static bool canCreateGroup(EntitlementState? state, int currentOwned) {
    final limit = ownedGroupsLimit(state);
    return limit < 0 || currentOwned < limit;
  }

  /// True when joining one more group is allowed given [currentJoined].
  static bool canJoinGroup(EntitlementState? state, int currentJoined) {
    final limit = joinedGroupsLimit(state);
    return limit < 0 || currentJoined < limit;
  }

  /// True when an attachment of [sizeBytes] is allowed to send under the current
  /// state. Plain text messages are never gated and never call this.
  static bool attachmentAllowed(EntitlementState? state, int sizeBytes) =>
      sizeBytes <= attachmentBytesLimit(state);
}
