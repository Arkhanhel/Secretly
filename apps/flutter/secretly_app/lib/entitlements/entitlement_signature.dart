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
// FAIL-OPEN contract (monetization rule: billing fails OPEN, security fails CLOSED):
// these verifiers only ever return a *boolean*. They never lock anyone out —
// the caller (EntitlementRepository) decides what an unverifiable result means,
// and in every case the fallback is the fully-open state (full access). A
// forged/unsigned config or blob can therefore only fail to *unlock*; it can
// never gate a feature, and security features are never routed through here.

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

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

/// Следующий ключ подписи конфигурации (15.11.2026, план П3, шаг В).
///
/// Открытый ключ зашит одной строкой, поэтому сменить ключ на сервере
/// одномоментно нельзя: все выпущенные сборки перестали бы верить
/// конфигурации. Смена идёт в два шага: сначала выпуск, который знает и
/// нынешний ключ, и следующий; когда таких сборок большинство — сервер
/// подписывает следующим. Пока здесь пусто, поведение прежнее побайтово.
///   `--dart-define=SECRETLY_CONFIG_PUBLIC_KEY_NEXT_B64=<base64>`
const String kConfigPublicKeyNextB64 = String.fromEnvironment(
  'SECRETLY_CONFIG_PUBLIC_KEY_NEXT_B64',
  defaultValue: '',
);

/// Подпись конфигурации: нынешним ключом, а если не сошлась — следующим
/// ([kConfigPublicKeyNextB64]). Без нынешнего ключа не проверяет ничего —
/// включение проверки по-прежнему решает [configSignatureEnforced].
Future<bool> verifyConfigEd25519B64({
  required String signatureB64,
  required List<int> message,
}) =>
    verifyWithConfigKeys(
      currentKeyB64: kConfigPublicKeyB64,
      nextKeyB64: kConfigPublicKeyNextB64,
      signatureB64: signatureB64,
      message: message,
    );

/// То же, что [verifyConfigEd25519B64], с ключами параметрами — для проверок.
@visibleForTesting
Future<bool> verifyWithConfigKeys({
  required String currentKeyB64,
  required String nextKeyB64,
  required String signatureB64,
  required List<int> message,
}) async {
  if (await verifyEd25519B64(
    publicKeyB64: currentKeyB64,
    signatureB64: signatureB64,
    message: message,
  )) {
    return true;
  }
  if (currentKeyB64.isEmpty || nextKeyB64.isEmpty) return false;
  return verifyEd25519B64(
    publicKeyB64: nextKeyB64,
    signatureB64: signatureB64,
    message: message,
  );
}

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
/// (F-ROOMSK-2.)
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
/// заморожен навсегда, дописывать в него новый переключатель нельзя (Э-4).
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

/// Зеркало Rust `handshake_auth_signing_message` (v1): блок `handshake_auth`,
/// С-2 (24.09.2026). Отдельный блок со своей подписью: подписываемые сообщения
/// других блоков заморожены, новое поле в них сломало бы проверку у всех
/// выпущенных сборок.
String handshakeAuthSigningMessage({
  required bool enforceDisabled,
  required int issuedAtMs,
}) {
  return 'secretly-handshake-auth-v1|'
      '${_bool(enforceDisabled)}|'
      '$issuedAtMs';
}

/// Зеркало Rust `handshake_auth2_signing_message` (v1): блок
/// `handshake_auth2`, флаг-день С-2 (Э4, 14.11.2026). Заморожено.
String handshakeAuth2SigningMessage({
  required bool requireAll,
  required int issuedAtMs,
}) {
  return 'secretly-handshake-auth2-v1|'
      '${_bool(requireAll)}|'
      '$issuedAtMs';
}

/// Флаг-день С-2: `true` — неподписанное рукопожатие отвергается от любого
/// устройства с известным ключом; `false` — только от доказавших подпись,
/// как с 1.8.58; `null` — блока нет или подпись не сошлась: вызывающий
/// ничего не меняет.
Future<bool?> verifiedHandshakeAuthRequireAll(
  Map<String, dynamic> configResponse,
) async {
  final sig = (configResponse['handshake_auth2_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return null;
  final payload = configResponse['handshake_auth2'];
  if (payload is! Map) return null;
  final requireAll = payload['require_all'] == true;
  final message = utf8.encode(
    handshakeAuth2SigningMessage(
      requireAll: requireAll,
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  final ok = await verifyConfigEd25519B64(
    signatureB64: sig,
    message: message,
  );
  return ok ? requireAll : null;
}

/// Mirrors Rust `support_signing_message` (v1). A SEPARATE signed block for the
/// same reason as identity/reliability: `secretly-config-v2` is frozen forever.
/// Carries the SUPPORT X25519 public key (recipient for in-app support tickets)
/// and the feature flag.
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
  return verifyConfigEd25519B64(
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
  return verifyConfigEd25519B64(
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
  return verifyConfigEd25519B64(
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
  return verifyConfigEd25519B64(
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
  return verifyConfigEd25519B64(
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
  return verifyConfigEd25519B64(
    signatureB64: sig,
    message: message,
  );
}

/// С-2 (24.09.2026): выключатель ОТКАЗОВ проверки подписи рукопожатия.
///
/// `true` — отказы сняты, `false` — действуют, `null` — блока нет или подпись
/// не сошлась: тогда вызывающий НИЧЕГО не меняет. Молчащий сервер (старый,
/// недоступный, срезанный блок) не может ни выключить защиту, ни включить её
/// обратно — действует последнее проверенное значение, а без него — отказы.
Future<bool?> verifiedHandshakeAuthEnforceDisabled(
  Map<String, dynamic> configResponse,
) async {
  final sig = (configResponse['handshake_auth_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return null;
  final payload = configResponse['handshake_auth'];
  if (payload is! Map) return null;
  final disabled = payload['enforce_disabled'] == true;
  final message = utf8.encode(
    handshakeAuthSigningMessage(
      enforceDisabled: disabled,
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  final ok = await verifyConfigEd25519B64(
    signatureB64: sig,
    message: message,
  );
  return ok ? disabled : null;
}

/// Зеркало Rust `multidevice_signing_message` (v1): блок `multidevice`, ТЗ
/// мультиустройства §2 (25.09.2026). ЗАМОРОЖЕНО: новое поле — только новым
/// блоком `multidevice2`, иначе подпись молча перестанет сходиться у всех.
String multideviceSigningMessage({
  required int ratchetJumpMobile,
  required int ratchetJumpDesktop,
  required int ephemeralOnlineOnlyPercent,
  required int companionWarnDays,
  required int companionUnlinkDays,
  required int nackV2Percent,
  required int sendJournalPercent,
  required int deviceCheckPercent,
  required int issuedAtMs,
}) {
  return 'secretly-multidevice-v1|'
      '$ratchetJumpMobile|'
      '$ratchetJumpDesktop|'
      '$ephemeralOnlineOnlyPercent|'
      '$companionWarnDays|'
      '$companionUnlinkDays|'
      '$nackV2Percent|'
      '$sendJournalPercent|'
      '$deviceCheckPercent|'
      '$issuedAtMs';
}

/// Проверяет блок `multidevice`. Подпись сверяется по СЫРЫМ числам сервера —
/// зажим идёт потом, в `MultideviceFlags.fromConfigResponse`. При false
/// вызывающий обязан взять `MultideviceFlags.defaults`.
Future<bool> verifyMultideviceSignature(
  Map<String, dynamic> configResponse,
) async {
  final sig = (configResponse['multidevice_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['multidevice'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    multideviceSigningMessage(
      ratchetJumpMobile: _int(payload['ratchet_jump_mobile']),
      ratchetJumpDesktop: _int(payload['ratchet_jump_desktop']),
      ephemeralOnlineOnlyPercent: _int(payload['ephemeral_online_only_percent']),
      companionWarnDays: _int(payload['companion_warn_days']),
      companionUnlinkDays: _int(payload['companion_unlink_days']),
      nackV2Percent: _int(payload['nack_v2_percent']),
      sendJournalPercent: _int(payload['send_journal_percent']),
      deviceCheckPercent: _int(payload['device_check_percent']),
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyConfigEd25519B64(
    signatureB64: sig,
    message: message,
  );
}

/// Зеркало Rust `calls_signing_message` (v1): блок `calls`, ТЗ E2EE созвонов
/// (06.10.2026). ЗАМОРОЖЕНО: новое поле — только новым блоком `calls2`.
String callsSigningMessage({
  required bool groupCallsEnabled,
  required int e2eeCreatePercent,
  required bool e2eeRequired,
  required int maxParticipantsE2ee,
  required int keySwitchDelayMs,
  required bool joinRatchet,
  required int issuedAtMs,
}) {
  return 'secretly-calls-v1|'
      '${_bool(groupCallsEnabled)}|'
      '$e2eeCreatePercent|'
      '${_bool(e2eeRequired)}|'
      '$maxParticipantsE2ee|'
      '$keySwitchDelayMs|'
      '${_bool(joinRatchet)}|'
      '$issuedAtMs';
}

/// Проверяет блок `calls` по СЫРЫМ значениям сервера; зажим — потом, в
/// `CallFlags.fromConfigResponse`. При false вызывающий берёт
/// `CallFlags.defaults`.
Future<bool> verifyCallsSignature(Map<String, dynamic> configResponse) async {
  final sig = (configResponse['calls_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['calls'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    callsSigningMessage(
      groupCallsEnabled: payload['group_calls_enabled'] == true,
      e2eeCreatePercent: _int(payload['e2ee_create_percent']),
      e2eeRequired: payload['e2ee_required'] == true,
      maxParticipantsE2ee: _int(payload['max_participants_e2ee']),
      keySwitchDelayMs: _int(payload['key_switch_delay_ms']),
      joinRatchet: payload['join_ratchet'] == true,
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyConfigEd25519B64(
    signatureB64: sig,
    message: message,
  );
}

/// Зеркало Rust `privacy_signing_message` (v1), блок `privacy` (Б2,
/// 23.10.2026). Заморожено.
String privacySigningMessage({
  required int padSendShare,
  required int issuedAtMs,
}) {
  return 'secretly-privacy-v1|$padSendShare|$issuedAtMs';
}

Future<bool> verifyPrivacySignature(Map<String, dynamic> configResponse) async {
  final sig = (configResponse['privacy_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['privacy'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    privacySigningMessage(
      padSendShare: _int(payload['pad_send_share']),
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyConfigEd25519B64(
    signatureB64: sig,
    message: message,
  );
}

/// Зеркало Rust `media_signing_message` (v1), блок `media` (загрузка
/// частями, 15.11.2026). Заморожено: новое поле — только блоком `media2`.
String mediaSigningMessage({
  required int resumableUploadShare,
  required int issuedAtMs,
}) {
  return 'secretly-media-v1|$resumableUploadShare|$issuedAtMs';
}

Future<bool> verifyMediaSignature(Map<String, dynamic> configResponse) async {
  final sig = (configResponse['media_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['media'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    mediaSigningMessage(
      resumableUploadShare: _int(payload['resumable_upload_share']),
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyConfigEd25519B64(
    signatureB64: sig,
    message: message,
  );
}

/// Зеркало Rust `stickers_signing_message` (v1), блок `stickers` (наборы
/// стикеров, 14.11.2026). Заморожено: новое поле — только блоком `stickers2`.
/// Логическое поле — как его печатает Rust: `true` / `false`.
String stickersSigningMessage({
  required int packAccessPercent,
  required int publicPublishPercent,
  required bool publicSearchEnabled,
  required int issuedAtMs,
}) {
  return 'secretly-stickers-v1|$packAccessPercent|$publicPublishPercent|'
      '${publicSearchEnabled ? 'true' : 'false'}|$issuedAtMs';
}

Future<bool> verifyStickersSignature(Map<String, dynamic> configResponse) async {
  final sig = (configResponse['stickers_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['stickers'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    stickersSigningMessage(
      packAccessPercent: _int(payload['pack_access_percent']),
      publicPublishPercent: _int(payload['public_publish_percent']),
      publicSearchEnabled: payload['public_search_enabled'] == true,
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyConfigEd25519B64(
    signatureB64: sig,
    message: message,
  );
}

/// Зеркало Rust `server_auth_signing_message` (v1), блок `server_auth` (Б3,
/// 25.10.2026). Заморожено.
String serverAuthSigningMessage({
  required int enforceShare,
  required String relayKid,
  required String relayPubB64,
  required int issuedAtMs,
}) {
  return 'secretly-server-auth-v1|$enforceShare|$relayKid|$relayPubB64|'
      '$issuedAtMs';
}

Future<bool> verifyServerAuthSignature(
  Map<String, dynamic> configResponse,
) async {
  final sig = (configResponse['server_auth_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['server_auth'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    serverAuthSigningMessage(
      enforceShare: _int(payload['enforce_share']),
      relayKid: (payload['relay_kid'] as String?) ?? '',
      relayPubB64: (payload['relay_pub_b64'] as String?) ?? '',
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyConfigEd25519B64(
    signatureB64: sig,
    message: message,
  );
}

/// Зеркало Rust `prekeys_signing_message` (v1), блок `prekeys` (Б5,
/// 24.10.2026). Заморожено.
String prekeysSigningMessage({
  required int otkHygieneShare,
  required int spkRotateShare,
  required int spkRotateDays,
  required int legacyWireRejectShare,
  required int issuedAtMs,
}) {
  return 'secretly-prekeys-v1|$otkHygieneShare|$spkRotateShare|'
      '$spkRotateDays|$legacyWireRejectShare|$issuedAtMs';
}

Future<bool> verifyPrekeysSignature(Map<String, dynamic> configResponse) async {
  final sig = (configResponse['prekeys_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['prekeys'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    prekeysSigningMessage(
      otkHygieneShare: _int(payload['otk_hygiene_share']),
      spkRotateShare: _int(payload['spk_rotate_share']),
      spkRotateDays: _int(payload['spk_rotate_days']),
      legacyWireRejectShare: _int(payload['legacy_wire_reject_share']),
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyConfigEd25519B64(
    signatureB64: sig,
    message: message,
  );
}

/// Зеркало Rust `disappearing_signing_message` (v1), блок `disappearing`
/// (23.10.2026, ТЗ исчезающих сообщений §2.5). Заморожено: договор с
/// сервером побайтово.
String disappearingSigningMessage({
  required bool sendEnabled,
  required int sendShare,
  required bool expireEnabled,
  required int minBuild,
  required int customMaxS,
  required int issuedAtMs,
}) {
  return 'secretly-disappearing-v1|'
      '${_bool(sendEnabled)}|'
      '$sendShare|'
      '${_bool(expireEnabled)}|'
      '$minBuild|'
      '$customMaxS|'
      '$issuedAtMs';
}

/// Проверяет блок `disappearing` по СЫРЫМ значениям сервера; зажим — потом,
/// в `DisappearingFlags.fromConfigResponse`. При false вызывающий берёт
/// `DisappearingFlags.defaults`.
Future<bool> verifyDisappearingSignature(
  Map<String, dynamic> configResponse,
) async {
  final sig = (configResponse['disappearing_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['disappearing'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    disappearingSigningMessage(
      sendEnabled: payload['send_enabled'] == true,
      sendShare: _int(payload['send_share']),
      expireEnabled: payload['expire_enabled'] == true,
      minBuild: _int(payload['min_build']),
      customMaxS: _int(payload['custom_max_s']),
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyConfigEd25519B64(
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
  return verifyConfigEd25519B64(
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
  return verifyConfigEd25519B64(
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
  return verifyConfigEd25519B64(
    signatureB64: sig,
    message: message,
  );
}

/// Строка подписи блока `transport` (Э1). 🔴 Побайтово совпадает с
/// `transport_signing_message` в `server/keys/src/main.rs`.
String transportSigningMessage({
  required bool enabled,
  required bool reportEnabled,
  required bool torEnabled,
  required int endpointsVersion,
  required int issuedAtMs,
}) {
  return 'secretly-transport-v1|'
      '${_bool(enabled)}|'
      '${_bool(reportEnabled)}|'
      '${_bool(torEnabled)}|'
      '$endpointsVersion|'
      '$issuedAtMs';
}

Future<bool> verifyTransportSignature(
  Map<String, dynamic> configResponse,
) async {
  final sig = (configResponse['transport_signature'] as String?) ?? '';
  if (kConfigPublicKeyB64.isEmpty || sig.isEmpty) return false;
  final payload = configResponse['transport'];
  if (payload is! Map) return false;
  final message = utf8.encode(
    transportSigningMessage(
      enabled: payload['enabled'] == true,
      reportEnabled: payload['report_enabled'] == true,
      torEnabled: payload['tor_enabled'] == true,
      endpointsVersion: _int(payload['endpoints_version']),
      issuedAtMs: _int(payload['issued_at_ms']),
    ),
  );
  return verifyConfigEd25519B64(
    signatureB64: sig,
    message: message,
  );
}
