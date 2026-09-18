// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Monetization entitlement models (TZ-MONETIZE-01 §C-1).
//
// Pure-Dart, no Flutter deps, so they unit-test fast. The whole module is
// dormant until the server flips `monetization_enabled` in the signed
// /v1/config (kill-switch). Until then [EntitlementState.unlockEverything]
// reports everything unlocked — security features are NEVER routed through
// this module (TZ Appendix B).

/// Subscription/grandfathering tier mirrored from the server entitlement blob.
enum EntitlementTier { free, premium, lifetime, legacy, team }

EntitlementTier entitlementTierFromWire(String? wire) {
  switch (wire) {
    case 'premium':
      return EntitlementTier.premium;
    case 'lifetime':
      return EntitlementTier.lifetime;
    case 'legacy':
      return EntitlementTier.legacy;
    case 'team':
      return EntitlementTier.team;
    case 'free':
    default:
      return EntitlementTier.free;
  }
}

String entitlementTierToWire(EntitlementTier tier) {
  switch (tier) {
    case EntitlementTier.premium:
      return 'premium';
    case EntitlementTier.lifetime:
      return 'lifetime';
    case EntitlementTier.legacy:
      return 'legacy';
    case EntitlementTier.team:
      return 'team';
    case EntitlementTier.free:
      return 'free';
  }
}

extension EntitlementTierX on EntitlementTier {
  /// Any paid/grandfathered tier (everything except plain free). Matches the
  /// server's `entitlement_tier_is_paid`.
  bool get isPaid => this != EntitlementTier.free;
}

/// Numeric limits applied for the resolved tier. Values come from the signed
/// /v1/config (Free vs Premium tables) echoed in the entitlement blob.
class EntitlementLimits {
  const EntitlementLimits({
    required this.attachmentBytes,
    required this.groupMembers,
    required this.callParticipants,
    required this.ownedGroups,
    required this.joinedGroups,
  });

  final int attachmentBytes;
  final int groupMembers;
  final int callParticipants;

  /// Max groups the profile may OWN/create. -1 = unlimited.
  final int ownedGroups;

  /// Max groups the profile may be a member of. -1 = unlimited.
  final int joinedGroups;

  /// Default free-tier safety values (must match server `from_env` defaults).
  static const EntitlementLimits free = EntitlementLimits(
    attachmentBytes: 104857600, // 100 MiB (raised from 25 MiB, 2026-07-06)
    // ROOM CAP (2026-07-29): held at 10 on BOTH tiers while rooms still fan out
    // pairwise — every room message is encrypted separately for each device of
    // each member, so cost grows with membership and a large room burns the
    // sender's CPU and battery. Raise only once rooms move to a shared group
    // key (see docs/TZ_ROOMS_SCALE_2026-07-29.md). Server env is authoritative:
    // SECRETLY_FREE_GROUP_MEMBERS / SECRETLY_PREMIUM_GROUP_MEMBERS.
    groupMembers: 10,
    callParticipants: 8,
    ownedGroups: 5,
    joinedGroups: 20,
  );

  /// Default premium-tier values (must match server `from_env` defaults).
  static const EntitlementLimits premium = EntitlementLimits(
    attachmentBytes: 1073741824, // 1 GiB
    // Same cap as free for now — see the note above; this is a technical
    // ceiling, not a tier differentiator, until the group-key work lands.
    groupMembers: 10,
    callParticipants: 50,
    ownedGroups: 100,
    joinedGroups: -1, // unlimited
  );

  factory EntitlementLimits.fromJson(Map<String, dynamic> json) {
    return EntitlementLimits(
      attachmentBytes:
          (json['attachment_bytes'] as num?)?.toInt() ?? free.attachmentBytes,
      groupMembers:
          (json['group_members'] as num?)?.toInt() ?? free.groupMembers,
      callParticipants:
          (json['call_participants'] as num?)?.toInt() ?? free.callParticipants,
      ownedGroups:
          (json['owned_groups'] as num?)?.toInt() ?? free.ownedGroups,
      joinedGroups:
          (json['joined_groups'] as num?)?.toInt() ?? free.joinedGroups,
    );
  }

  Map<String, dynamic> toJson() => {
    'attachment_bytes': attachmentBytes,
    'group_members': groupMembers,
    'call_participants': callParticipants,
    'owned_groups': ownedGroups,
    'joined_groups': joinedGroups,
  };
}

/// Boolean feature flags resolved server-side from the tier (+ companion seat).
class EntitlementFeatures {
  const EntitlementFeatures({
    required this.desktop,
    required this.customId,
    required this.premiumStickers,
  });

  final bool desktop;
  final bool customId;
  final bool premiumStickers;

  static const EntitlementFeatures none = EntitlementFeatures(
    desktop: false,
    customId: false,
    premiumStickers: false,
  );

  static const EntitlementFeatures all = EntitlementFeatures(
    desktop: true,
    customId: true,
    premiumStickers: true,
  );

  factory EntitlementFeatures.fromJson(Map<String, dynamic> json) {
    return EntitlementFeatures(
      desktop: json['desktop'] == true,
      customId: json['custom_id'] == true,
      premiumStickers: json['premium_stickers'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'desktop': desktop,
    'custom_id': customId,
    'premium_stickers': premiumStickers,
  };
}

/// The resolved client-side entitlement snapshot. Combines the kill-switch flag
/// from /v1/config with the per-profile entitlement blob. The `unlock*` getters
/// are the ONLY thing UI gates should consult — they fail OPEN when monetization
/// is disabled so the app behaves exactly as the pre-freemium build.
class EntitlementState {
  const EntitlementState({
    required this.monetizationEnabled,
    required this.tier,
    required this.source,
    required this.features,
    required this.limits,
    this.expiresAtMs,
    this.graceUntilMs,
    this.issuedAtMs = 0,
    this.signatureVerified = false,
    this.fetchedAtMs = 0,
  });

  /// True only when the server kill-switch is ON. While false the app is fully
  /// open (pre-freemium behaviour).
  final bool monetizationEnabled;
  final EntitlementTier tier;
  final String source;
  final EntitlementFeatures features;
  final EntitlementLimits limits;
  final int? expiresAtMs;
  final int? graceUntilMs;
  final int issuedAtMs;

  /// Whether the Ed25519 signature on the blob was cryptographically verified.
  ///
  /// This is a pure parse-time fact; ENFORCEMENT lives in
  /// [EntitlementRepository] (audit §E/R3), not in this model. When a verifying
  /// key is baked into the build, the repository discards any blob whose
  /// signature did not verify and falls back to [open] (full access) instead of
  /// applying a possibly-forged gating blob — so a state that actually reaches
  /// the UI in a release build is either signature-verified or the open
  /// default. In debug/test builds (no key) nothing is enforced and this stays
  /// `false`. Recorded here for diagnostics and cache round-tripping.
  final bool signatureVerified;

  /// Local clock ms when this snapshot was obtained/cached (for offline grace).
  final int fetchedAtMs;

  /// The fully-open default used whenever monetization is disabled or the
  /// entitlement service is unreachable (billing fails OPEN, §0.4 / §6).
  ///
  /// Note `limits` is the FREE baseline, not premium: boolean features fail
  /// open (unlocked), but size ceilings (attachments/groups/calls) must stay at
  /// the pre-freemium baseline so a disabled kill-switch never silently RAISES
  /// a limit. A genuinely-paid user keeps premium ceilings via their cached
  /// `tier=premium` snapshot (7-day grace), not via this default.
  static const EntitlementState open = EntitlementState(
    monetizationEnabled: false,
    tier: EntitlementTier.free,
    source: 'none',
    features: EntitlementFeatures.all,
    limits: EntitlementLimits.free,
  );

  /// True when every *boolean* gated feature should be unlocked: either the
  /// kill-switch is off (pre-freemium) or the profile holds a paid tier.
  /// Size ceilings do NOT key off this — see the limit getters.
  bool get unlockEverything => !monetizationEnabled || tier.isPaid;

  bool get desktopUnlocked => unlockEverything || features.desktop;
  bool get customIdUnlocked => unlockEverything || features.customId;
  bool get premiumStickersUnlocked =>
      unlockEverything || features.premiumStickers;

  /// Effective attachment byte ceiling. Only a positive paid tier raises it
  /// above the free baseline — kill-switch-off / fail-open keep 25 MB so
  /// current behaviour is preserved byte-for-byte.
  int get attachmentBytesLimit => tier.isPaid
      ? limits.attachmentBytes
      : EntitlementLimits.free.attachmentBytes;

  EntitlementState copyWith({
    bool? monetizationEnabled,
    EntitlementTier? tier,
    String? source,
    EntitlementFeatures? features,
    EntitlementLimits? limits,
    int? expiresAtMs,
    int? graceUntilMs,
    int? issuedAtMs,
    bool? signatureVerified,
    int? fetchedAtMs,
  }) {
    return EntitlementState(
      monetizationEnabled: monetizationEnabled ?? this.monetizationEnabled,
      tier: tier ?? this.tier,
      source: source ?? this.source,
      features: features ?? this.features,
      limits: limits ?? this.limits,
      expiresAtMs: expiresAtMs ?? this.expiresAtMs,
      graceUntilMs: graceUntilMs ?? this.graceUntilMs,
      issuedAtMs: issuedAtMs ?? this.issuedAtMs,
      signatureVerified: signatureVerified ?? this.signatureVerified,
      fetchedAtMs: fetchedAtMs ?? this.fetchedAtMs,
    );
  }

  /// Parses the signed entitlement blob returned by GET /entitlements, combined
  /// with the kill-switch flag resolved from /v1/config.
  ///
  /// This is a pure parser — it does NOT enforce the signature. Signature
  /// enforcement (rejecting unverified blobs → open) is the repository's job
  /// (audit §E/R3), so callers that obtain a blob over the network must route
  /// it through [EntitlementRepository], not construct state directly.
  factory EntitlementState.fromEntitlementJson(
    Map<String, dynamic> json, {
    required bool monetizationEnabled,
    bool signatureVerified = false,
    int fetchedAtMs = 0,
  }) {
    final featuresJson = json['features'];
    final limitsJson = json['limits'];
    return EntitlementState(
      monetizationEnabled: monetizationEnabled,
      tier: entitlementTierFromWire(json['tier'] as String?),
      source: (json['source'] as String?) ?? 'none',
      features: featuresJson is Map<String, dynamic>
          ? EntitlementFeatures.fromJson(featuresJson)
          : EntitlementFeatures.none,
      limits: limitsJson is Map<String, dynamic>
          ? EntitlementLimits.fromJson(limitsJson)
          : EntitlementLimits.free,
      expiresAtMs: (json['expires_at_ms'] as num?)?.toInt(),
      graceUntilMs: (json['grace_until_ms'] as num?)?.toInt(),
      issuedAtMs: (json['issued_at_ms'] as num?)?.toInt() ?? 0,
      signatureVerified: signatureVerified,
      fetchedAtMs: fetchedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'monetization_enabled': monetizationEnabled,
    'tier': entitlementTierToWire(tier),
    'source': source,
    'features': features.toJson(),
    'limits': limits.toJson(),
    'expires_at_ms': expiresAtMs,
    'grace_until_ms': graceUntilMs,
    'issued_at_ms': issuedAtMs,
    'signature_verified': signatureVerified,
    'fetched_at_ms': fetchedAtMs,
  };

  factory EntitlementState.fromCacheJson(Map<String, dynamic> json) {
    final featuresJson = json['features'];
    final limitsJson = json['limits'];
    return EntitlementState(
      monetizationEnabled: json['monetization_enabled'] == true,
      tier: entitlementTierFromWire(json['tier'] as String?),
      source: (json['source'] as String?) ?? 'none',
      features: featuresJson is Map<String, dynamic>
          ? EntitlementFeatures.fromJson(featuresJson)
          : EntitlementFeatures.none,
      limits: limitsJson is Map<String, dynamic>
          ? EntitlementLimits.fromJson(limitsJson)
          : EntitlementLimits.free,
      expiresAtMs: (json['expires_at_ms'] as num?)?.toInt(),
      graceUntilMs: (json['grace_until_ms'] as num?)?.toInt(),
      issuedAtMs: (json['issued_at_ms'] as num?)?.toInt() ?? 0,
      signatureVerified: json['signature_verified'] == true,
      fetchedAtMs: (json['fetched_at_ms'] as num?)?.toInt() ?? 0,
    );
  }
}
