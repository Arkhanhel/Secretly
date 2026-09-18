// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Canonical signing-message reconstruction + Ed25519 verification for the
// monetization config & entitlement blobs (TZ-MONETIZE-01 §C-1, audit §E/R3).
//
// These functions MUST produce byte-identical strings to the Rust server
// (`config_signing_message` / `entitlement_signing_message` in
// `server/keys/src/main.rs`). The server signs a fixed pipe-joined string
// (NOT JSON) precisely so the client can avoid JSON key-ordering pitfalls.
//
// FAIL-OPEN contract (CLAUDE.md: billing fails OPEN, security fails CLOSED):
// these verifiers only ever return a *boolean*. They never lock anyone out —
// the caller (EntitlementRepository) decides what an unverifiable result means,
// and in every case the fallback is the fully-open state (full access). A
// forged/unsigned config or blob can therefore only fail to *unlock*; it can
// never gate a feature, and security features are never routed through here.

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'entitlement_models.dart';

/// The server's config-signing Ed25519 public key (base64 of the 32-byte
/// verifying key), baked into the binary at build time:
///   `--dart-define=SECRETLY_CONFIG_PUBLIC_KEY_B64=<base64>`
/// Empty when not provisioned yet (R0/R1): the client then fails OPEN and does
/// not require a verified signature.
const String kConfigPublicKeyB64 =
    String.fromEnvironment('SECRETLY_CONFIG_PUBLIC_KEY_B64', defaultValue: '');

/// True only when a config/entitlement verifying key was baked into the build
/// (release via `--dart-define`). Signature *enforcement* keys off this: when no
/// key is present (debug/test builds, R0/R1) we cannot verify anything, so we
/// fail OPEN and never enforce — behaviour is byte-for-byte the pre-R3 build.
/// When a key IS present (production R3) an unverifiable config/blob is treated
/// as untrusted and the caller drops to the fully-open state (full access),
/// never a lockout.
bool get configSignatureEnforced => kConfigPublicKeyB64.isNotEmpty;

String _ms(int? v) => v == null ? 'null' : v.toString();
String _bool(bool v) => v ? 'true' : 'false';

/// Mirrors Rust `config_signing_message` (v2).
String configSigningMessage({
  required bool monetizationEnabled,
  required int freeAttachmentBytes,
  required int freeGroupMembers,
  required int freeCallParticipants,
  required int freeOwnedGroups,
  required int freeJoinedGroups,
  required int premiumAttachmentBytes,
  required int premiumGroupMembers,
  required int premiumCallParticipants,
  required int premiumOwnedGroups,
  required int premiumJoinedGroups,
  required int desktopTrialDays,
  required int issuedAtMs,
}) {
  return 'secretly-config-v2|'
      '${_bool(monetizationEnabled)}|'
      '$freeAttachmentBytes|$freeGroupMembers|$freeCallParticipants|'
      '$freeOwnedGroups|$freeJoinedGroups|'
      '$premiumAttachmentBytes|$premiumGroupMembers|$premiumCallParticipants|'
      '$premiumOwnedGroups|$premiumJoinedGroups|'
      '$desktopTrialDays|$issuedAtMs';
}

/// Mirrors Rust `reliability_signing_message` (v1).
///
/// Deliberately a SEPARATE message from [configSigningMessage]: the reliability
/// kill-switches were added long after clients shipped, and folding a field
/// into `secretly-config-v2` would have invalidated the signature for every
/// build already in the wild.
String reliabilitySigningMessage({
  required bool nackReceiptsEnabled,
  required bool convergenceResendEnabled,
  required int issuedAtMs,
}) {
  return 'secretly-reliability-v1|'
      '${_bool(nackReceiptsEnabled)}|'
      '${_bool(convergenceResendEnabled)}|'
      '$issuedAtMs';
}

/// Mirrors Rust `identity_signing_message` (v1) — the И-1 rotation switch
/// (TZ_I1_IDENTITY_2026-07-21 §Д-5). A separate signed message for the same
/// reason as the reliability block: `secretly-config-v2` is frozen forever.
String identitySigningMessage({
  required bool rotationOnStateLossEnabled,
  required int issuedAtMs,
}) {
  return 'secretly-identity-v1|'
      '${_bool(rotationOnStateLossEnabled)}|'
      '$issuedAtMs';
}

/// Mirrors Rust `rooms_signing_message` (v1). A SEPARATE signed block for the
/// same reason as identity/reliability: `secretly-config-v2` is frozen forever,
/// so a new switch may never be appended to an existing block.
/// (docs/TZ_ROOM_SENDER_KEY_2026-07-29.md, F-ROOMSK-2.)
String roomsSigningMessage({
  required bool senderKeySendEnabled,
  required int issuedAtMs,
}) {
  return 'secretly-rooms-v1|'
      '${_bool(senderKeySendEnabled)}|'
      '$issuedAtMs';
}

/// Зеркало Rust `handshake_signing_message` (v1). Отдельный подписанный блок
/// по той же причине, что identity/reliability/rooms: `secretly-config-v2`
/// заморожен навсегда, дописывать в него новый переключатель нельзя.
/// (Э-4, docs/TZ_PREKEY_UNTIL_CONFIRMED_2026-08-01.md.)
String handshakeSigningMessage({
  required bool prekeyUntilConfirmedSendEnabled,
  required int prekeyUntilConfirmedSendPercent,
  required int issuedAtMs,
}) {
  return 'secretly-handshake-v1|'
      '${_bool(prekeyUntilConfirmedSendEnabled)}|'
      '$prekeyUntilConfirmedSendPercent|'
      '$issuedAtMs';
}

/// Mirrors Rust `support_signing_message` (v1). A SEPARATE signed block for the
/// same reason as identity/reliability: `secretly-config-v2` is frozen forever.
/// Carries the SUPPORT X25519 public key (recipient for in-app support tickets)
/// and the feature flag (TZ docs/TZ_SUPPORT_TICKETS_2026-07-24.md).
String supportSigningMessage({
  required bool supportEnabled,
  required String supportPubB64,
  required int issuedAtMs,
}) {
  return 'secretly-support-v1|'
      '${_bool(supportEnabled)}|'
      '$supportPubB64|'
      '$issuedAtMs';
}

/// Mirrors Rust `entitlement_signing_message`.
String entitlementSigningMessage({
  required String profileId,
  required String tier,
  required String source,
  required int? expiresAtMs,
  required int? graceUntilMs,
  required EntitlementFeatures features,
  required EntitlementLimits limits,
  required int issuedAtMs,
}) {
  return 'secretly-entitlements-v2|'
      '$profileId|$tier|$source|'
      '${_ms(expiresAtMs)}|${_ms(graceUntilMs)}|'
      '${_bool(features.desktop)}|${_bool(features.customId)}|${_bool(features.premiumStickers)}|'
      '${limits.attachmentBytes}|${limits.groupMembers}|${limits.callParticipants}|'
      '${limits.ownedGroups}|${limits.joinedGroups}|'
      '$issuedAtMs';
}

/// Verifies an Ed25519 signature (base64) over [message] using a base64 public
/// key. Returns false on any malformed input rather than throwing.
Future<bool> verifyEd25519B64({
  required String publicKeyB64,
  required String signatureB64,
  required List<int> message,
}) async {
  if (publicKeyB64.isEmpty || signatureB64.isEmpty) return false;
  try {
    final pub = base64Decode(publicKeyB64);
    final sig = base64Decode(signatureB64);
    if (pub.length != 32) return false;
    final publicKey = SimplePublicKey(pub, type: KeyPairType.ed25519);
    return await Ed25519().verify(
      message,
      signature: Signature(sig, publicKey: publicKey),
    );
  } catch (_) {
    return false;
  }
}

/// Verifies the entitlement blob signature against [kConfigPublicKeyB64].
/// Returns true when the signature checks out. When no public key is baked in
/// or the blob is unsigned/malformed, returns false. Enforcement of a false
/// result (drop to the open state) is the repository's job — see
/// [configSignatureEnforced] (audit §E/R3).
Future<bool> verifyEntitlementSignature(Map<String, dynamic> json) async {
  final sig = (json['signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final featuresJson = json['features'];
  final limitsJson = json['limits'];
  if (featuresJson is! Map<String, dynamic> ||
      limitsJson is! Map<String, dynamic>) {
    return false;
  }
  final message = utf8.encode(
    entitlementSigningMessage(
      profileId: (json['profile_id'] as String?) ?? '',
      tier: (json['tier'] as String?) ?? 'free',
      source: (json['source'] as String?) ?? 'none',
      expiresAtMs: (json['expires_at_ms'] as num?)?.toInt(),
      graceUntilMs: (json['grace_until_ms'] as num?)?.toInt(),
      features: EntitlementFeatures.fromJson(featuresJson),
      limits: EntitlementLimits.fromJson(limitsJson),
      issuedAtMs: (json['issued_at_ms'] as num?)?.toInt() ?? 0,
    ),
  );
  return verifyEd25519B64(
    publicKeyB64: kConfigPublicKeyB64,
    signatureB64: sig,
    message: message,
  );
}

int _int(dynamic v) => v is num ? v.toInt() : 0;

/// Verifies the `/v1/config` envelope signature against [kConfigPublicKeyB64].
///
/// [configResponse] is the decoded `GET /v1/config` body
/// (`{ "payload": {...}, "signature": "<b64>", "alg": "ed25519" }`). The signed
/// portion is `payload`, whose limits are nested under `free_limits` /
/// `premium_limits`; we flatten them into [configSigningMessage] so the bytes
/// match the Rust `config_signing_message` exactly (`secretly-config-v2|...`).
///
/// Returns true only when the Ed25519 signature checks out. Returns false when
/// no public key is baked in, the signature is empty/malformed, or the payload
/// is missing — the caller fails OPEN on a false result (audit §E/R3).
Future<bool> verifyConfigSignature(Map<String, dynamic> configResponse) async {
  final sig = (configResponse['signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['payload'];
  if (payload is! Map) return false;
  final free = payload['free_limits'];
  final premium = payload['premium_limits'];
  if (free is! Map || premium is! Map) return false;
  final message = utf8.encode(
    configSigningMessage(
      monetizationEnabled: payload['monetization_enabled'] == true,
      freeAttachmentBytes: _int(free['attachment_bytes']),
      freeGroupMembers: _int(free['group_members']),
      freeCallParticipants: _int(free['call_participants']),
      freeOwnedGroups: _int(free['owned_groups']),
      freeJoinedGroups: _int(free['joined_groups']),
      premiumAttachmentBytes: _int(premium['attachment_bytes']),
      premiumGroupMembers: _int(premium['group_members']),
      premiumCallParticipants: _int(premium['call_participants']),
      premiumOwnedGroups: _int(premium['owned_groups']),
      premiumJoinedGroups: _int(premium['joined_groups']),
      desktopTrialDays: _int(payload['desktop_trial_days']),
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyEd25519B64(
    publicKeyB64: kConfigPublicKeyB64,
    signatureB64: sig,
    message: message,
  );
}

/// Verifies the additive `reliability` block on `/v1/config` (same server key,
/// its own canonical message).
///
/// Returns true only when the Ed25519 signature checks out. On false the caller
/// MUST keep the defaults — the flags gate a safety net against silent message
/// loss, so an absent, stripped or forged block must never be able to switch
/// the healing machinery off. Note this is the opposite failure direction from
/// [verifyConfigSignature]: billing fails open, reliability fails ON.
Future<bool> verifyReliabilitySignature(
  Map<String, dynamic> configResponse,
) async {
  final sig = (configResponse['reliability_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['reliability'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    reliabilitySigningMessage(
      nackReceiptsEnabled: payload['nack_receipts_enabled'] == true,
      convergenceResendEnabled: payload['convergence_resend_enabled'] == true,
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyEd25519B64(
    publicKeyB64: kConfigPublicKeyB64,
    signatureB64: sig,
    message: message,
  );
}

/// Verifies the additive И-1 `identity` block on `/v1/config` (same server
/// key, its own canonical message).
///
/// On false the caller MUST keep [IdentityFlags.defaults] — i.e. rotation
/// stays DORMANT. This is the opposite failure direction from reliability:
/// nothing unauthenticated may switch the new rotation behaviour ON.
Future<bool> verifyIdentitySignature(
  Map<String, dynamic> configResponse,
) async {
  final sig = (configResponse['identity_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['identity'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    identitySigningMessage(
      rotationOnStateLossEnabled:
          payload['rotation_on_state_loss_enabled'] == true,
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyEd25519B64(
    publicKeyB64: kConfigPublicKeyB64,
    signatureB64: sig,
    message: message,
  );
}

/// Verifies the additive `rooms` block on `/v1/config` (same server key, its
/// own canonical message).
///
/// On false the caller MUST keep [RoomFlags.defaults] — i.e. sending under the
/// room sender key stays DORMANT. Same failure direction as identity, and for a
/// sharper reason: an unauthenticated party must never be able to switch on a
/// wire format whose failure mode is silent, permanent message loss on the
/// RECIPIENT's device.
/// Зеркало Rust `update_signing_message` (v1). Отдельный подписанный блок,
/// потому что `secretly-config-v2` заморожен — а неподписанный `update_url`
/// был бы фишингом: подменивший конфиг отправил бы людей за «обновлением»
/// куда угодно.
String updateSigningMessage({
  required int latestBuild,
  required String updateUrl,
  required int issuedAtMs,
}) {
  return 'secretly-update-v1|$latestBuild|$updateUrl|$issuedAtMs';
}

Future<bool> verifyUpdateSignature(Map<String, dynamic> configResponse) async {
  final sig = (configResponse['update_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['update'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    updateSigningMessage(
      latestBuild: _int(payload['latest_build']),
      updateUrl: (payload['update_url'] as String?) ?? '',
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyEd25519B64(
    publicKeyB64: kConfigPublicKeyB64,
    signatureB64: sig,
    message: message,
  );
}

Future<bool> verifyHandshakeSignature(
  Map<String, dynamic> configResponse,
) async {
  final sig = (configResponse['handshake_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['handshake'];
  if (payload is! Map) return false;
  final rawPercent = payload['prekey_until_confirmed_send_percent'];
  final message = utf8.encode(
    handshakeSigningMessage(
      prekeyUntilConfirmedSendEnabled:
          payload['prekey_until_confirmed_send_enabled'] == true,
      prekeyUntilConfirmedSendPercent:
          rawPercent is num ? rawPercent.toInt() : 0,
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyEd25519B64(
    publicKeyB64: kConfigPublicKeyB64,
    signatureB64: sig,
    message: message,
  );
}

/// Зеркало Rust `rooms2_signing_message` (v1), блок `rooms2` (17.09.2026).
String rooms2SigningMessage({
  required bool rawBroadcastEnabled,
  required int bigRoomMembers,
  required int bigRoomMinBuild,
  required int issuedAtMs,
}) {
  return 'secretly-rooms2-v1|'
      '${_bool(rawBroadcastEnabled)}|'
      '$bigRoomMembers|'
      '$bigRoomMinBuild|'
      '$issuedAtMs';
}

Future<bool> verifyRooms2Signature(Map<String, dynamic> configResponse) async {
  final sig = (configResponse['rooms2_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['rooms2'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    rooms2SigningMessage(
      rawBroadcastEnabled: payload['raw_broadcast_enabled'] == true,
      bigRoomMembers: _int(payload['big_room_members']),
      bigRoomMinBuild: _int(payload['big_room_min_build']),
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyEd25519B64(
    publicKeyB64: kConfigPublicKeyB64,
    signatureB64: sig,
    message: message,
  );
}

Future<bool> verifyRoomsSignature(Map<String, dynamic> configResponse) async {
  final sig = (configResponse['rooms_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['rooms'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    roomsSigningMessage(
      senderKeySendEnabled: payload['sender_key_send_enabled'] == true,
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyEd25519B64(
    publicKeyB64: kConfigPublicKeyB64,
    signatureB64: sig,
    message: message,
  );
}

/// Verifies the additive `support` block on `/v1/config` (same server key, its
/// own canonical message). On false the caller MUST keep [SupportConfig.defaults]
/// — support stays OFF (page hidden), like identity: nothing unauthenticated may
/// turn a NEW feature on or inject a support public key.
Future<bool> verifySupportSignature(
  Map<String, dynamic> configResponse,
) async {
  final sig = (configResponse['support_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['support'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    supportSigningMessage(
      supportEnabled: payload['support_enabled'] == true,
      supportPubB64: (payload['support_pub_b64'] as String?) ?? '',
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyEd25519B64(
    publicKeyB64: kConfigPublicKeyB64,
    signatureB64: sig,
    message: message,
  );
}
