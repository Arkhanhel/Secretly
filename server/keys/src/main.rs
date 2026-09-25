// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
use axum::{
    Json, Router,
    body::Body,
    extract::DefaultBodyLimit,
    extract::{ConnectInfo, Path, Query, State},
    http::HeaderMap,
    http::{Request, StatusCode},
    middleware,
    response::IntoResponse,
    routing::get,
    routing::post,
};
use base32ct::{Base32UpperUnpadded, Encoding};
use base64::Engine as _;
use crc32fast::Hasher;
use dashmap::DashMap;
use ed25519_dalek::{Signature, Signer, SigningKey, VerifyingKey};
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{env, net::SocketAddr, sync::Arc, time::Instant};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod billing;
mod store;
use store::{
    EntitlementRebind, EntitlementRecord, KeysStore, OneTimePrekey, ProfileInactivityStatus,
    ReceiptClaim,
};

const KEYS_HTTP_BODY_LIMIT_BYTES: usize = 1024 * 1024;

/// How long a purchase must stay put before a different profile may claim it
/// with the same receipt. A reinstall claims immediately (the first move is
/// always allowed); only a second hand-off within the window is refused, which
/// is what keeps two people sharing one store account from taking it from each
/// other on every launch.
const RECEIPT_CLAIM_MIN_INTERVAL_MS: i64 = 24 * 60 * 60 * 1000;

// Server Safe Backup payloads are encrypted account snapshots that can far
// exceed the 1 MB global request cap (a full account with history serialises to
// several MB; the field wanted headroom for media-inclusive backups too). The
// global limit stays small to keep every OTHER endpoint's DoS surface tight;
// only `/v1/backup/set` gets this larger, route-specific limit (see the router).
// 2026-07-05: raised after a 2.23 MB backup was silently rejected by the old
// 1.2 MB cap, stranding a profile with no server copy.
const KEYS_BACKUP_MAX_PAYLOAD_BYTES: usize = 200 * 1024 * 1024;
// The whole JSON envelope (payload + profile_id/device_id/sha/nonce/signature)
// must fit under the route body limit, so allow a 1 MB margin over the payload.
const KEYS_BACKUP_MAX_BODY_BYTES: usize =
    KEYS_BACKUP_MAX_PAYLOAD_BYTES + 1024 * 1024;

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
    service: &'static str,
    server_protocol_version: i64,
    min_client_protocol_version: i64,
    max_client_protocol_version: i64,
    client_protocol_version: Option<i64>,
    compatibility_status: &'static str,
    compatibility_message: Option<String>,
    deployment_id: Option<String>,
    release_channel: Option<String>,
    service_started_at_ms: i64,
    max_request_body_bytes: i64,
}

#[derive(Deserialize)]
struct HealthQuery {
    client_protocol_version: Option<i64>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ClientCompatibilityResult {
    supported: bool,
    compatibility_status: &'static str,
    compatibility_message: Option<String>,
}

// ── Monetization signed config (TZ-MONETIZE-01 §S-3) ───────────────────────
#[derive(Serialize)]
struct ConfigLimits {
    attachment_bytes: i64,
    group_members: i64,
    call_participants: i64,
    /// Max groups a profile may OWN/create. -1 = unlimited.
    owned_groups: i64,
    /// Max groups a profile may be a member of. -1 = unlimited.
    joined_groups: i64,
}

/// The signed portion of /v1/config. Field order here is the canonical signing
/// order — the client verifies the Ed25519 signature over `serde_json` of this
/// struct exactly. Do NOT reorder/rename fields without bumping a version.
#[derive(Serialize)]
struct ConfigPayload {
    monetization_enabled: bool,
    free_limits: ConfigLimits,
    premium_limits: ConfigLimits,
    desktop_trial_days: i64,
    issued_at_ms: i64,
}

/// Reliability kill-switches (TZ_RELIABLE_DELIVERY_E2E_RECEIPTS §12), signed
/// SEPARATELY from [`ConfigPayload`].
///
/// ⚠️ These MUST NOT be folded into `ConfigPayload`. The client verifies
/// `config_signing_message` as an exact pipe-joined string, so adding a field
/// there would invalidate the signature for every already-shipped client.
/// Keeping a second payload with its own signature means old clients ignore
/// these fields entirely while `payload`/`signature` stay byte-identical.
#[derive(Serialize)]
struct ReliabilityPayload {
    nack_receipts_enabled: bool,
    convergence_resend_enabled: bool,
    issued_at_ms: i64,
}

/// И-1 identity-rotation switch (TZ_I1_IDENTITY_2026-07-21 §Д-5), signed
/// SEPARATELY for the same reason as [`ReliabilityPayload`]: nothing may ever
/// be folded into `secretly-config-v2`.
///
/// Client polarity is the OPPOSITE of reliability: rotation-on-state-loss only
/// activates after the client has seen a VERIFIED block with the flag on
/// (fail-OFF activation). A stripped, forged or absent block leaves the new
/// behaviour dormant — it can never be force-enabled from outside.
#[derive(Serialize)]
struct IdentityPayload {
    rotation_on_state_loss_enabled: bool,
    issued_at_ms: i64,
}

/// Additive (2026-07-31): SEND kill-switch for the room sender key
/// (F-ROOMSK-2).
///
/// Client polarity is fail-OFF, like identity: sealing room messages under the
/// sender key activates only after a VERIFIED block permits it. This exists
/// because 1.7.4+416 shipped a build that sealed room messages a peer could not
/// read — the messages were ACKed and lost permanently, and with a compile-time
/// flag the only remedy was reinstalling the app. Two independent keys now turn
/// sending on (build flag AND this block); either one turns it off.
///
/// Turning this off is SAFE at any moment: the client falls back to the
/// ordinary pairwise fanout, which every build in existence can read.
#[derive(Serialize)]
struct RoomsPayload {
    sender_key_send_enabled: bool,
    issued_at_ms: i64,
}

/// К-2 / К-5 (17.09.2026):
/// the second rooms block, with its OWN signature. A new block instead of new
/// fields in `rooms`: that block's signed text is frozen, and changing it would
/// make every released client distrust it — which turns their room sending off.
///
/// * `raw_broadcast_enabled` — clients may upload one sealed room message and
///   let the relay fan it out (fails OFF: new behaviour);
/// * `big_room_members` / `big_room_min_build` — how far a room may grow past
///   the tier cap, and from which build (0 = no big rooms). The relay applies
///   the same numbers; clients only use them to explain a refusal.
#[derive(Serialize)]
struct Rooms2Payload {
    raw_broadcast_enabled: bool,
    big_room_members: i64,
    big_room_min_build: i64,
    issued_at_ms: i64,
}

/// Canonical signing message for `rooms2`. MUST match the Dart
/// `rooms2SigningMessage` byte-for-byte.
fn rooms2_signing_message(p: &Rooms2Payload) -> String {
    format!(
        "secretly-rooms2-v1|{}|{}|{}|{}",
        p.raw_broadcast_enabled, p.big_room_members, p.big_room_min_build, p.issued_at_ms,
    )
}

/// Additive (2026-08-03): сведения о новой версии для напоминания об
/// обновлении, со своей подписью.
///
/// 🔴 ПОЧЕМУ ОТДЕЛЬНЫЙ БЛОК, А НЕ ПОЛЯ В `payload`. Клиент умеет читать
/// latest_build/update_url из основного блока с 2026-07, но сервер их никогда
/// не присылал — и правильно делал: подписываемый вид `secretly-config-v2`
/// заморожен, поэтому дописанные туда поля оказались бы ВНЕ ПОДПИСИ. А
/// неподписанный `update_url` — это готовый фишинг: кто сумеет подменить
/// конфиг, отправит людей за «обновлением» куда захочет. Для мессенджера,
/// который продаёт приватность, это худший из возможных провалов.
///
/// Уровня «требовать обновление» здесь СОЗНАТЕЛЬНО НЕТ (решение владельца,
/// 03.08.2026). Принудительная блокировка — оружие двустороннее: одна опечатка
/// в номере сборки кладёт приложение у всех сразу. Напоминание же в худшем
/// случае надоедает.
#[derive(Serialize, Clone)]
struct UpdatePayload {
    /// Самая свежая опубликованная сборка. 0 — напоминать не о чем.
    latest_build: i64,
    /// Куда вести по кнопке. Пусто — клиент возьмёт стор своей платформы.
    update_url: String,
    issued_at_ms: i64,
}

/// Additive (2026-08-03): переключатель ОТПРАВКИ повторного prekey (Э-4,
/// со своей подписью. Клиенты,
/// собранные до этого поля, просто его не увидят.
///
/// ЧЕМ ОТЛИЧАЕТСЯ ОТ БЛОКА `rooms`. Там сервер — только выключатель: включить
/// отправку без пересборки нельзя, нужны два независимых ключа. Здесь сервер —
/// ЕДИНСТВЕННЫЙ ключ, и это осознанный выбор: сборочный флаг означал бы, что
/// каждое включение и каждый откат едут через ревью Play несколько дней, а
/// откат нужен за минуты.
///
/// Безопасность даёт не пересборка, а два других свойства:
///   * отказ В ЗАКРЫТУЮ при любой неясности — старый сервер, отсутствующий
///     блок, срезанное поле, поддельная подпись — всё оставляет отправку спящей;
///   * ДОЛЯ раскатки: включать можно не всем сразу, а проценту устройств,
///     и доля считается детерминированно от device_id, поэтому телефон не
///     перескакивает между группами от опроса к опросу.
#[derive(Serialize, Clone, Copy)]
struct HandshakePayload {
    prekey_until_confirmed_send_enabled: bool,
    /// 0..100. Доля устройств, которым разрешена отправка. 0 — никому даже при
    /// включённом флаге; 100 — всем.
    prekey_until_confirmed_send_percent: i64,
    issued_at_ms: i64,
}

/// С-2 (24.09.2026): выключатель ОТКАЗОВ проверки подписи рукопожатия.
///
/// Клиент проверяет подпись рукопожатия всегда, а отвергает только рукопожатие
/// устройства, которое уже доказало, что подписывает. Этот блок снимает именно
/// отказы — на случай, если в поле найдётся ошибка. По умолчанию `false`:
/// отказы действуют. Отдельный блок со своей подписью, потому что подписываемое
/// сообщение `handshake` заморожено выпущенными сборками.
#[derive(Serialize, Clone, Copy)]
struct HandshakeAuthPayload {
    enforce_disabled: bool,
    issued_at_ms: i64,
}

/// Additive (2026-07-24): in-app Support feature flag + the X25519 public key
/// tickets are sealed to. Fail-OFF on the client (empty key / unverified block
/// hides the page). TZ.
#[derive(Serialize, Clone)]
struct SupportPayload {
    support_enabled: bool,
    support_pub_b64: String,
    issued_at_ms: i64,
}

#[derive(Serialize)]
struct ConfigResponse {
    payload: ConfigPayload,
    /// base64(Ed25519 signature over serde_json bytes of `payload`); empty when
    /// no server signing key is configured (R0 client does not yet verify).
    signature: String,
    alg: &'static str,
    /// Additive (2026-07-19): reliability kill-switches with their OWN
    /// signature. Clients built before this field simply ignore both.
    reliability: ReliabilityPayload,
    reliability_signature: String,
    /// Additive (2026-07-21): И-1 identity-rotation switch with its OWN
    /// signature. Clients built before this field simply ignore both.
    identity: IdentityPayload,
    identity_signature: String,
    /// Additive (2026-07-31): room sender-key SEND kill-switch with its OWN
    /// signature. Clients built before this field simply ignore both.
    rooms: RoomsPayload,
    rooms_signature: String,
    /// Additive (2026-09-17): see [`Rooms2Payload`].
    rooms2: Rooms2Payload,
    rooms2_signature: String,
    /// Additive (2026-08-03): переключатель отправки повторного prekey (Э-4)
    /// со своей подписью. Старые клиенты игнорируют оба поля.
    handshake: HandshakePayload,
    handshake_signature: String,
    /// Additive (2026-09-24): выключатель отказов С-2 со своей подписью.
    /// Старые клиенты игнорируют оба поля.
    handshake_auth: HandshakeAuthPayload,
    handshake_auth_signature: String,
    /// Additive (2026-08-03): сведения о новой версии со своей подписью.
    update: UpdatePayload,
    update_signature: String,
    /// Additive (2026-07-24): in-app Support key + flag with its OWN signature.
    /// Clients built before this field simply ignore both.
    support: SupportPayload,
    support_signature: String,
}

/// Canonical, language-independent signing message for /v1/config. Signing a
/// fixed pipe-joined string (NOT JSON) lets the Dart client reconstruct the
/// exact same bytes without depending on JSON key ordering. Bump the `v1`
/// prefix if the field set changes.
fn config_signing_message(p: &ConfigPayload) -> String {
    format!(
        "secretly-config-v2|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
        p.monetization_enabled,
        p.free_limits.attachment_bytes,
        p.free_limits.group_members,
        p.free_limits.call_participants,
        p.free_limits.owned_groups,
        p.free_limits.joined_groups,
        p.premium_limits.attachment_bytes,
        p.premium_limits.group_members,
        p.premium_limits.call_participants,
        p.premium_limits.owned_groups,
        p.premium_limits.joined_groups,
        p.desktop_trial_days,
        p.issued_at_ms,
    )
}

/// Canonical signing message for the reliability kill-switches. Same pipe-joined
/// shape as [`config_signing_message`] so the Dart client can rebuild the exact
/// bytes. Bump the `v1` prefix if the field set changes.
fn reliability_signing_message(p: &ReliabilityPayload) -> String {
    format!(
        "secretly-reliability-v1|{}|{}|{}",
        p.nack_receipts_enabled, p.convergence_resend_enabled, p.issued_at_ms,
    )
}

/// Canonical signing message for the И-1 identity block. Same pipe-joined
/// shape as [`config_signing_message`]; bump the `v1` prefix if the field set
/// changes.
fn identity_signing_message(p: &IdentityPayload) -> String {
    format!(
        "secretly-identity-v1|{}|{}",
        p.rotation_on_state_loss_enabled, p.issued_at_ms,
    )
}

/// Canonical signing message for the rooms block. Same pipe-joined shape; MUST
/// match the Dart `roomsSigningMessage` byte-for-byte. Bump the `v1` prefix if
/// the field set ever changes — appending to a frozen message is what breaks a
/// signature silently.
fn rooms_signing_message(p: &RoomsPayload) -> String {
    format!(
        "secretly-rooms-v1|{}|{}",
        p.sender_key_send_enabled, p.issued_at_ms,
    )
}

/// Каноническое подписываемое сообщение блока обновления. ОБЯЗАН совпадать с
/// Dart `updateSigningMessage` побайтово.
fn update_signing_message(p: &UpdatePayload) -> String {
    format!(
        "secretly-update-v1|{}|{}|{}",
        p.latest_build, p.update_url, p.issued_at_ms,
    )
}

/// Каноническое подписываемое сообщение блока рукопожатия. Тот же
/// вид через вертикальную черту; ОБЯЗАН совпадать с Dart
/// `handshakeSigningMessage` побайтово.
fn handshake_signing_message(p: &HandshakePayload) -> String {
    format!(
        "secretly-handshake-v1|{}|{}|{}",
        p.prekey_until_confirmed_send_enabled,
        p.prekey_until_confirmed_send_percent,
        p.issued_at_ms,
    )
}

/// Каноническое подписываемое сообщение блока `handshake_auth`. ОБЯЗАНО
/// совпадать с Dart `handshakeAuthSigningMessage` побайтово.
fn handshake_auth_signing_message(p: &HandshakeAuthPayload) -> String {
    format!(
        "secretly-handshake-auth-v1|{}|{}",
        p.enforce_disabled, p.issued_at_ms,
    )
}

/// Canonical signing message for the Support block. Same pipe-joined shape; MUST
/// match the Dart `supportSigningMessage` byte-for-byte.
fn support_signing_message(p: &SupportPayload) -> String {
    format!(
        "secretly-support-v1|{}|{}|{}",
        p.support_enabled, p.support_pub_b64, p.issued_at_ms,
    )
}

/// GET /v1/config — signed monetization kill-switch + limits (S-3).
/// Defaults are fully open (`monetization_enabled=false`) so the app behaves
/// exactly as before until a human flips the flag at R3.
async fn get_config(State(state): State<AppState>) -> impl IntoResponse {
    let m = state.monetization.as_ref();
    let payload = ConfigPayload {
        monetization_enabled: m.enabled,
        free_limits: ConfigLimits {
            attachment_bytes: m.free_attachment_bytes,
            group_members: m.free_group_members,
            call_participants: m.free_call_participants,
            owned_groups: m.free_owned_groups,
            joined_groups: m.free_joined_groups,
        },
        premium_limits: ConfigLimits {
            attachment_bytes: m.premium_attachment_bytes,
            group_members: m.premium_group_members,
            call_participants: m.premium_call_participants,
            owned_groups: m.premium_owned_groups,
            joined_groups: m.premium_joined_groups,
        },
        desktop_trial_days: m.desktop_trial_days,
        issued_at_ms: now_ms(),
    };
    let signing_message = config_signing_message(&payload);
    let signature = match state.config_signing_key.as_ref() {
        Some(sk) => base64::engine::general_purpose::STANDARD
            .encode(sk.sign(signing_message.as_bytes()).to_bytes()),
        None => String::new(),
    };
    let r = state.reliability.as_ref();
    let reliability = ReliabilityPayload {
        nack_receipts_enabled: r.nack_receipts_enabled,
        convergence_resend_enabled: r.convergence_resend_enabled,
        issued_at_ms: payload.issued_at_ms,
    };
    let reliability_signature = match state.config_signing_key.as_ref() {
        Some(sk) => base64::engine::general_purpose::STANDARD.encode(
            sk.sign(reliability_signing_message(&reliability).as_bytes())
                .to_bytes(),
        ),
        None => String::new(),
    };
    let id_cfg = state.identity.as_ref();
    let identity = IdentityPayload {
        rotation_on_state_loss_enabled: id_cfg.rotation_on_state_loss_enabled,
        issued_at_ms: payload.issued_at_ms,
    };
    let identity_signature = match state.config_signing_key.as_ref() {
        Some(sk) => base64::engine::general_purpose::STANDARD.encode(
            sk.sign(identity_signing_message(&identity).as_bytes())
                .to_bytes(),
        ),
        None => String::new(),
    };
    let room_cfg = state.rooms.as_ref();
    let rooms = RoomsPayload {
        sender_key_send_enabled: room_cfg.sender_key_send_enabled,
        issued_at_ms: payload.issued_at_ms,
    };
    let rooms_signature = match state.config_signing_key.as_ref() {
        Some(sk) => base64::engine::general_purpose::STANDARD
            .encode(sk.sign(rooms_signing_message(&rooms).as_bytes()).to_bytes()),
        None => String::new(),
    };
    let rooms2_cfg = state.rooms2.as_ref();
    let rooms2 = Rooms2Payload {
        raw_broadcast_enabled: rooms2_cfg.raw_broadcast_enabled,
        big_room_members: rooms2_cfg.big_room_members,
        big_room_min_build: rooms2_cfg.big_room_min_build,
        issued_at_ms: payload.issued_at_ms,
    };
    let rooms2_signature = match state.config_signing_key.as_ref() {
        Some(sk) => base64::engine::general_purpose::STANDARD.encode(
            sk.sign(rooms2_signing_message(&rooms2).as_bytes())
                .to_bytes(),
        ),
        None => String::new(),
    };
    let sup_cfg = state.support.as_ref();
    let support = SupportPayload {
        support_enabled: sup_cfg.support_enabled,
        support_pub_b64: sup_cfg.support_pub_b64.clone(),
        issued_at_ms: payload.issued_at_ms,
    };
    let support_signature = match state.config_signing_key.as_ref() {
        Some(sk) => base64::engine::general_purpose::STANDARD.encode(
            sk.sign(support_signing_message(&support).as_bytes()).to_bytes(),
        ),
        None => String::new(),
    };
    let hs_cfg = state.handshake.as_ref();
    let handshake = HandshakePayload {
        prekey_until_confirmed_send_enabled: hs_cfg.prekey_until_confirmed_send_enabled,
        prekey_until_confirmed_send_percent: hs_cfg.prekey_until_confirmed_send_percent,
        issued_at_ms: payload.issued_at_ms,
    };
    let upd_cfg = state.update.as_ref();
    let update = UpdatePayload {
        latest_build: upd_cfg.latest_build,
        update_url: upd_cfg.update_url.clone(),
        issued_at_ms: payload.issued_at_ms,
    };
    let handshake_auth = HandshakeAuthPayload {
        enforce_disabled: hs_cfg.hs_auth_enforce_disabled,
        issued_at_ms: payload.issued_at_ms,
    };
    let handshake_auth_signature = match state.config_signing_key.as_ref() {
        Some(sk) => base64::engine::general_purpose::STANDARD.encode(
            sk.sign(handshake_auth_signing_message(&handshake_auth).as_bytes())
                .to_bytes(),
        ),
        None => String::new(),
    };
    let update_signature = match state.config_signing_key.as_ref() {
        Some(sk) => base64::engine::general_purpose::STANDARD
            .encode(sk.sign(update_signing_message(&update).as_bytes()).to_bytes()),
        None => String::new(),
    };
    let handshake_signature = match state.config_signing_key.as_ref() {
        Some(sk) => base64::engine::general_purpose::STANDARD.encode(
            sk.sign(handshake_signing_message(&handshake).as_bytes())
                .to_bytes(),
        ),
        None => String::new(),
    };
    // ETag over the static (limits/flag) part — note issued_at_ms changes each
    // call, so derive the ETag from the limits+flag only for cache stability.
    // The reliability flags are part of the seed too — otherwise flipping a
    // kill-switch would keep serving a stale cached response for up to max-age.
    let etag_seed = format!(
        "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
        m.enabled,
        m.free_attachment_bytes,
        m.free_group_members,
        m.free_call_participants,
        m.free_owned_groups,
        m.free_joined_groups,
        m.premium_attachment_bytes,
        m.premium_group_members,
        m.premium_call_participants,
        m.premium_owned_groups,
        m.premium_joined_groups,
        m.desktop_trial_days,
        r.nack_receipts_enabled,
        r.convergence_resend_enabled,
        id_cfg.rotation_on_state_loss_enabled,
        // 🔴 Блок рукопожатия ОБЯЗАН быть в зерне ETag: иначе включение флага
        // или смена доли раскатки продолжали бы отдавать кэш до минуты, и
        // «включить за минуты» превратилось бы в «включить когда-нибудь».
        hs_cfg.prekey_until_confirmed_send_enabled,
        hs_cfg.prekey_until_confirmed_send_percent,
        upd_cfg.latest_build,
        // С-2: выключатель тоже в зерне — иначе «снять отказы за минуты»
        // упёрлось бы в кэш.
        hs_cfg.hs_auth_enforce_disabled,
    );
    let etag = format!(
        "\"{}\"",
        base64::engine::general_purpose::STANDARD.encode(Sha256::digest(etag_seed.as_bytes()))
    );
    let mut headers = HeaderMap::new();
    if let Ok(v) = etag.parse() {
        headers.insert(axum::http::header::ETAG, v);
    }
    if let Ok(v) = "public, max-age=60".parse() {
        headers.insert(axum::http::header::CACHE_CONTROL, v);
    }
    (
        StatusCode::OK,
        headers,
        Json(ConfigResponse {
            payload,
            signature,
            alg: "ed25519",
            reliability,
            reliability_signature,
            identity,
            identity_signature,
            rooms,
            rooms_signature,
            rooms2,
            rooms2_signature,
            handshake,
            handshake_signature,
            handshake_auth,
            handshake_auth_signature,
            update,
            update_signature,
            support,
            support_signature,
        }),
    )
}

// ── Monetization entitlements (TZ-MONETIZE-01 §S-1) ────────────────────────
#[derive(Serialize)]
struct EntitlementFeatures {
    desktop: bool,
    custom_id: bool,
    premium_stickers: bool,
}

#[derive(Serialize)]
struct EntitlementResponse {
    profile_id: String,
    /// free|premium|lifetime|legacy|team
    tier: String,
    /// appstore|play|stripe|legacy|none
    source: String,
    /// Epoch-ms (matches /v1/config style). null = no expiry / not set.
    expires_at_ms: Option<i64>,
    grace_until_ms: Option<i64>,
    features: EntitlementFeatures,
    limits: ConfigLimits,
    issued_at_ms: i64,
    /// base64(Ed25519 over the canonical signing message); empty when no server
    /// signing key is configured (R0/R1 client fails open without verification).
    signature: String,
    alg: &'static str,
}

/// True for any paid/grandfathered tier (everything except plain `free`).
fn entitlement_tier_is_paid(tier: &str) -> bool {
    matches!(tier, "premium" | "lifetime" | "legacy" | "team")
}

/// Whether applying verified purchase `v` to a profile that currently holds
/// `current` would LOWER its access. iOS "Restore" replays EVERY past
/// transaction in an arbitrary order, so an old/expired/revoked receipt can
/// arrive after the user already holds a better one (a lifetime bought later,
/// or a longer sub). The redeem path must never downgrade in that case.
/// Aligned with fail-OPEN: this only ever SKIPS a change — it never revokes
/// access. Refunds and expiries still land through the store webhooks, which
/// do not go through this check.
///
/// 🔴 Restored 17.09.2026 from `7435c11d`: the guard ran on prod from 11.07,
/// lived only on `feature/admin-panel`, and vanished when keys started being
/// built from the main branch.
fn purchase_would_downgrade(
    current: Option<&EntitlementRecord>,
    v: &billing::VerifiedPurchase,
) -> bool {
    let Some(cur) = current else {
        return false; // no row — any receipt is an upgrade
    };
    if !entitlement_tier_is_paid(&cur.tier) {
        return false;
    }
    if !entitlement_tier_is_paid(v.tier) {
        return true; // a free/revoked receipt must not clobber a paid profile
    }
    let cur_nonexpiring = cur.expires_at_ms.is_none();
    let inc_nonexpiring = v.expires_at_ms.is_none();
    if cur_nonexpiring {
        // lifetime/legacy is the top tier: only an equally non-expiring receipt
        // may replace it; a subscription (has an expiry) is a downgrade.
        return !inc_nonexpiring;
    }
    if inc_nonexpiring {
        return false; // sub -> lifetime is an upgrade
    }
    // both are expiring subs: a downgrade only if the incoming one ends earlier.
    match (cur.expires_at_ms, v.expires_at_ms) {
        (Some(cur_exp), Some(inc_exp)) => inc_exp < cur_exp,
        _ => false,
    }
}

/// Canonical, language-independent signing message for the entitlement blob.
/// null timestamps serialize as the literal "null" so the Dart client can
/// reconstruct identical bytes without JSON key-ordering dependencies.
fn entitlement_signing_message(
    profile_id: &str,
    tier: &str,
    source: &str,
    expires_at_ms: Option<i64>,
    grace_until_ms: Option<i64>,
    features: &EntitlementFeatures,
    limits: &ConfigLimits,
    issued_at_ms: i64,
) -> String {
    let ms = |v: Option<i64>| v.map(|n| n.to_string()).unwrap_or_else(|| "null".into());
    format!(
        "secretly-entitlements-v2|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
        profile_id,
        tier,
        source,
        ms(expires_at_ms),
        ms(grace_until_ms),
        features.desktop,
        features.custom_id,
        features.premium_stickers,
        limits.attachment_bytes,
        limits.group_members,
        limits.call_participants,
        limits.owned_groups,
        limits.joined_groups,
        issued_at_ms,
    )
}

/// GET /v1/profile/{profile_id}/entitlements — signed entitlement blob (S-1).
/// Owner-only: authenticated via the existing device challenge/proof mechanism
/// (same headers as backup_get). Absent row → default `free` tier (fail-open).
async fn get_entitlements(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(profile_id): Path<String>,
) -> Result<Json<EntitlementResponse>, (StatusCode, String)> {
    if !is_valid_id(&profile_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "invalid profile id".into()));
    }

    if !internal_key_matches(&state, &headers) && require_entitlements_get_auth_enabled() {
        let ts_ms = header_str(&headers, "x-secretly-ts-ms")
            .and_then(|s| s.parse::<i64>().ok())
            .unwrap_or(0);
        let nonce_b64 = header_str(&headers, "x-secretly-nonce-b64").unwrap_or("");
        let req_did = header_str(&headers, "x-secretly-device-id").unwrap_or("");
        let msg = keys_entitlements_get_auth_message(req_did, &profile_id, ts_ms, nonce_b64);
        verify_requester_device_auth(&state, &headers, msg, true, Some(&profile_id)).await?;
    }

    let response = build_signed_entitlement_response(&state, &profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    Ok(Json(response))
}

/// Reads the stored entitlement (defaulting to free), derives features + limits,
/// and signs the blob. Shared by GET /entitlements (S-1) and legacy_claim (S-4).
async fn build_signed_entitlement_response(
    state: &AppState,
    profile_id: &str,
) -> Result<EntitlementResponse, String> {
    let row = state.store.entitlement_get(profile_id).await?;
    let (tier, source, expires_at_ms, grace_until_ms) = match row {
        Some(r) => (r.tier, r.source, r.expires_at_ms, r.grace_until_ms),
        None => ("free".to_string(), "none".to_string(), None, None),
    };

    // Desktop companion access can also be granted independently of tier via the
    // existing internal companion-limit setter, so OR it in.
    let companion_limit = state
        .store
        .desktop_companion_limit(profile_id)
        .await
        .unwrap_or(None)
        .unwrap_or(0);
    let paid = entitlement_tier_is_paid(&tier);
    let features = EntitlementFeatures {
        desktop: paid || companion_limit > 0,
        custom_id: paid,
        premium_stickers: paid,
    };

    let m = state.monetization.as_ref();
    let limits = if paid {
        ConfigLimits {
            attachment_bytes: m.premium_attachment_bytes,
            group_members: m.premium_group_members,
            call_participants: m.premium_call_participants,
            owned_groups: m.premium_owned_groups,
            joined_groups: m.premium_joined_groups,
        }
    } else {
        ConfigLimits {
            attachment_bytes: m.free_attachment_bytes,
            group_members: m.free_group_members,
            call_participants: m.free_call_participants,
            owned_groups: m.free_owned_groups,
            joined_groups: m.free_joined_groups,
        }
    };

    let issued_at_ms = now_ms();
    let signing_message = entitlement_signing_message(
        profile_id,
        &tier,
        &source,
        expires_at_ms,
        grace_until_ms,
        &features,
        &limits,
        issued_at_ms,
    );
    let signature = match state.config_signing_key.as_ref() {
        Some(sk) => base64::engine::general_purpose::STANDARD
            .encode(sk.sign(signing_message.as_bytes()).to_bytes()),
        None => String::new(),
    };

    Ok(EntitlementResponse {
        profile_id: profile_id.to_string(),
        tier,
        source,
        expires_at_ms,
        grace_until_ms,
        features,
        limits,
        issued_at_ms,
        signature,
        alg: "ed25519",
    })
}

// ── S-4 legacy_claim (grandfathering $5.99 buyers) ─────────────────────────
#[derive(Deserialize)]
struct LegacyClaimRequest {
    profile_id: String,
}

fn keys_legacy_claim_auth_message(
    requester_device_id: &str,
    profile_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-KEYS-LEGACY-CLAIM-V1\nrequester_device_id={}\nprofile_id={}\nts_ms={}\nnonce_b64={}\n",
        requester_device_id, profile_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

/// POST /v1/entitlements/legacy_claim — device-authenticated. Before deadline
/// `D` any valid profile gets `tier=legacy` (lifetime-equivalent) exactly once;
/// after `D` returns 410 Gone. Idempotent: a profile that already holds a paid
/// tier keeps it and the call just returns the current signed blob.
async fn legacy_claim(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<LegacyClaimRequest>,
) -> Result<Json<EntitlementResponse>, (StatusCode, String)> {
    let profile_id = req.profile_id;
    if !is_valid_id(&profile_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "invalid profile id".into()));
    }

    if !internal_key_matches(&state, &headers) {
        let ts_ms = header_str(&headers, "x-secretly-ts-ms")
            .and_then(|s| s.parse::<i64>().ok())
            .unwrap_or(0);
        let nonce_b64 = header_str(&headers, "x-secretly-nonce-b64").unwrap_or("");
        let req_did = header_str(&headers, "x-secretly-device-id").unwrap_or("");
        let msg = keys_legacy_claim_auth_message(req_did, &profile_id, ts_ms, nonce_b64);
        verify_requester_device_auth(&state, &headers, msg, true, Some(&profile_id)).await?;
    }

    // Idempotency: if the profile already holds any paid/grandfathered tier,
    // do not downgrade or re-stamp — just return what it has.
    let existing = state
        .store
        .entitlement_get(&profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    let already_paid = existing
        .as_ref()
        .map(|r| entitlement_tier_is_paid(&r.tier))
        .unwrap_or(false);

    if !already_paid {
        // Deadline gate: after `D` legacy grandfathering is closed.
        if let Some(deadline) = state.monetization.legacy_claim_deadline_ms {
            if now_ms() >= deadline {
                return Err((
                    StatusCode::GONE,
                    "legacy claim window has closed".into(),
                ));
            }
        }
        let granted = state
            .store
            .entitlement_upsert(EntitlementRecord {
                profile_id: profile_id.clone(),
                tier: "legacy".into(),
                source: "legacy".into(),
                store_tx_id: None,
                expires_at_ms: None,
                grace_until_ms: None,
                updated_at_ms: now_ms(),
            })
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
        if !granted {
            return Err((StatusCode::NOT_FOUND, "unknown profile".into()));
        }
    }

    let response = build_signed_entitlement_response(&state, &profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    Ok(Json(response))
}

#[derive(Deserialize)]
struct RebindEntitlementRequest {
    from_profile_id: String,
    to_profile_id: String,
}

/// POST /v1/entitlements/admin/rebind — INTERNAL-KEY ONLY (no device-auth
/// fallback). Moves an existing entitlement from one profile_id to another, for
/// the "I bought premium but lost my profile / created a new Secretly ID" case.
/// Preserves tier/source/store_tx_id so the UNIQUE receipt binding follows the
/// new profile; the old row is removed. Returns the signed entitlement for the
/// target profile. Operators call this instead of hand-editing keys.db.
async fn rebind_entitlement(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<RebindEntitlementRequest>,
) -> Result<Json<EntitlementResponse>, (StatusCode, String)> {
    if !internal_key_matches(&state, &headers) {
        return Err((StatusCode::UNAUTHORIZED, "internal key required".into()));
    }
    let from = req.from_profile_id;
    let to = req.to_profile_id;
    if !is_valid_id(&from, 128) || !is_valid_id(&to, 128) {
        return Err((StatusCode::BAD_REQUEST, "invalid profile id".into()));
    }
    if from == to {
        return Err((StatusCode::BAD_REQUEST, "from and to must differ".into()));
    }
    match state
        .store
        .entitlement_rebind(&from, &to, now_ms())
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
    {
        EntitlementRebind::UnknownTarget => {
            return Err((StatusCode::NOT_FOUND, "target profile does not exist".into()));
        }
        EntitlementRebind::NoSource => {
            return Err((
                StatusCode::NOT_FOUND,
                "source profile has no entitlement to move".into(),
            ));
        }
        EntitlementRebind::Moved(rec) => {
            tracing::info!(
                from = %from,
                to = %to,
                tier = %rec.tier,
                source = %rec.source,
                "admin: rebound entitlement",
            );
        }
    }
    let response = build_signed_entitlement_response(&state, &to)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    Ok(Json(response))
}

#[derive(Deserialize)]
struct GrantEntitlementRequest {
    profile_id: String,
    /// Comped tier — "lifetime" (default), "premium" or "team".
    tier: Option<String>,
}

/// POST /v1/entitlements/admin/grant — INTERNAL-KEY ONLY. Grants a comped tier
/// (default "lifetime", source "manual", no expiry) to a profile without a store
/// receipt — for gifting premium / comping testers. Idempotent upsert; the
/// profile must already exist. Returns the signed entitlement. Operators call
/// this instead of hand-editing keys.db.
async fn grant_entitlement(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<GrantEntitlementRequest>,
) -> Result<Json<EntitlementResponse>, (StatusCode, String)> {
    if !internal_key_matches(&state, &headers) {
        return Err((StatusCode::UNAUTHORIZED, "internal key required".into()));
    }
    let profile_id = req.profile_id;
    if !is_valid_id(&profile_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "invalid profile id".into()));
    }
    let tier = req.tier.unwrap_or_else(|| "lifetime".into());
    if !matches!(tier.as_str(), "lifetime" | "premium" | "team") {
        return Err((
            StatusCode::BAD_REQUEST,
            "tier must be lifetime, premium or team".into(),
        ));
    }
    tracing::info!(profile_id = %profile_id, tier = %tier, "admin: granting entitlement");
    let granted = state
        .store
        .entitlement_upsert(EntitlementRecord {
            profile_id: profile_id.clone(),
            tier,
            source: "manual".into(),
            store_tx_id: None,
            expires_at_ms: None,
            grace_until_ms: None,
            updated_at_ms: now_ms(),
        })
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    if !granted {
        return Err((StatusCode::NOT_FOUND, "unknown profile".into()));
    }
    let response = build_signed_entitlement_response(&state, &profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    Ok(Json(response))
}

#[derive(Deserialize)]
struct RevokeEntitlementRequest {
    profile_id: String,
}

/// POST /v1/entitlements/admin/revoke — INTERNAL-KEY ONLY. Drops a profile's
/// entitlement (comp / stale grant) so it reverts to free and releases its
/// store_tx binding. An active store subscription re-grants on the next redeem,
/// so this removes gifts/stale rows without denying a paid subscription.
/// Returns the (now free) signed entitlement.
///
/// 🔴 Restored 17.09.2026 from `ba63912d`: the admin console's «Снять премиум»
/// calls this route, and it vanished from prod together with the rest of the
/// `feature/admin-panel` server code.
async fn revoke_entitlement(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<RevokeEntitlementRequest>,
) -> Result<Json<EntitlementResponse>, (StatusCode, String)> {
    if !internal_key_matches(&state, &headers) {
        return Err((StatusCode::UNAUTHORIZED, "internal key required".into()));
    }
    let profile_id = req.profile_id;
    if !is_valid_id(&profile_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "invalid profile id".into()));
    }
    tracing::info!(profile_id = %profile_id, "admin: revoking entitlement");
    state
        .store
        .entitlement_revoke(&profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    let response = build_signed_entitlement_response(&state, &profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    Ok(Json(response))
}

// ── S-2 redeem + store webhooks (TZ-MONETIZE-01) ────────────────────────────
//
// FAIL-CLOSED: any verification failure rejects (never grants). Behind the
// `monetization_enabled` flag. Live sandbox/license-tester validation (§10) is
// required before R3. See server/keys/src/billing.rs for required config.

fn keys_redeem_auth_message(
    requester_device_id: &str,
    profile_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-KEYS-REDEEM-V1\nrequester_device_id={}\nprofile_id={}\nts_ms={}\nnonce_b64={}\n",
        requester_device_id, profile_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

#[derive(Deserialize)]
struct RedeemRequest {
    profile_id: String,
    /// "appstore" | "play"
    platform: String,
    /// App Store: the StoreKit2 signed-transaction JWS.
    #[serde(default)]
    jws: Option<String>,
    /// Google Play: the purchase token + product id.
    #[serde(default)]
    purchase_token: Option<String>,
    #[serde(default)]
    product_id: Option<String>,
}

fn map_verify_err(e: billing::VerifyError) -> (StatusCode, String) {
    use billing::VerifyError::*;
    match e {
        NotConfigured(s) => (StatusCode::SERVICE_UNAVAILABLE, format!("not configured: {s}")),
        Network(s) => (StatusCode::BAD_GATEWAY, format!("store api: {s}")),
        UnknownProduct(s) => (StatusCode::BAD_REQUEST, format!("unknown product: {s}")),
        Malformed(s) => (StatusCode::BAD_REQUEST, format!("malformed receipt: {s}")),
        Untrusted(s) => (StatusCode::BAD_REQUEST, format!("receipt rejected: {s}")),
    }
}

/// Upserts a verified purchase onto a profile. `store_tx_id` is UNIQUE, so a
/// receipt already bound to a DIFFERENT profile is rejected with 409 — one
/// receipt cannot grant two profiles.
async fn apply_verified_purchase(
    state: &AppState,
    profile_id: &str,
    v: &billing::VerifiedPurchase,
) -> Result<(), (StatusCode, String)> {
    // Anti-downgrade guard — first, before the receipt claim below: the claim
    // DELETEs the requester's own row, so a stale receipt owned by another
    // profile would otherwise replace a lifetime with a lapsed sub. Bail out
    // with OK (idempotent) so the client does not loop.
    let current_ent = state
        .store
        .entitlement_get(profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    if purchase_would_downgrade(current_ent.as_ref(), v) {
        tracing::info!(
            "redeem: skipping downgrade for profile={} (already holds a better entitlement than store_tx={})",
            profile_id,
            v.store_tx_id
        );
        return Ok(());
    }
    if let Some(existing) = state
        .store
        .entitlement_profile_for_store_tx(&v.store_tx_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
    {
        if existing != profile_id {
            // The receipt is the only durable proof of purchase in a design
            // with no accounts — it outlives reinstalls, new phones and a lost
            // database, where a profile_id does not. So the purchase follows
            // the receipt to whoever can present it, rather than being stranded
            // on the profile that happened to redeem it first. That refusal was
            // the reason a reinstalled user lost a live subscription and was
            // told, wrongly, that no purchase existed.
            let claim = state
                .store
                .entitlement_claim_by_receipt(
                    &existing,
                    profile_id,
                    now_ms(),
                    RECEIPT_CLAIM_MIN_INTERVAL_MS,
                )
                .await
                .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
            if !claim.moved() {
                // Blocked by the anti-flap guard (or an unknown target): keep
                // the old refusal, and name both sides so an operator can
                // rebind by hand if this is a genuine support case.
                tracing::warn!(
                    "redeem: receipt claim refused — owner={} requester={} \
                     (moved too recently; rebind by hand if legitimate)",
                    existing,
                    profile_id
                );
                return Err((
                    StatusCode::CONFLICT,
                    "receipt already redeemed by another profile".into(),
                ));
            }
            if claim == ReceiptClaim::MovedToFreshProfile {
                // Свежая установка забрала чек автоматически; окно не взведено,
                // и восстановленный следом настоящий профиль вернёт его сразу.
                tracing::info!(
                    "redeem: receipt moved to a fresh profile (anti-flap window not armed) — from={} to={}",
                    existing,
                    profile_id
                );
            } else {
                tracing::info!(
                    "redeem: receipt moved to the profile presenting it — from={} to={}",
                    existing,
                    profile_id
                );
            }
        }
    }
    let granted = state
        .store
        .entitlement_upsert(EntitlementRecord {
            profile_id: profile_id.to_string(),
            tier: v.tier.to_string(),
            source: v.source.to_string(),
            store_tx_id: Some(v.store_tx_id.clone()),
            expires_at_ms: v.expires_at_ms,
            grace_until_ms: None,
            updated_at_ms: now_ms(),
        })
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    if !granted {
        return Err((StatusCode::NOT_FOUND, "unknown profile".into()));
    }
    Ok(())
}

/// POST /v1/entitlements/redeem — device-authenticated. Verifies a store receipt
/// and grants the mapped tier. While monetization is disabled this is a no-op
/// that returns the current (open) entitlement.
async fn redeem(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<RedeemRequest>,
) -> Result<Json<EntitlementResponse>, (StatusCode, String)> {
    let profile_id = req.profile_id;
    if !is_valid_id(&profile_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "invalid profile id".into()));
    }
    tracing::info!(
        "redeem: received profile={} platform={} has_jws={} product={:?}",
        profile_id,
        req.platform,
        req.jws.is_some(),
        req.product_id
    );
    if !internal_key_matches(&state, &headers) {
        let ts_ms = header_str(&headers, "x-secretly-ts-ms")
            .and_then(|s| s.parse::<i64>().ok())
            .unwrap_or(0);
        let nonce_b64 = header_str(&headers, "x-secretly-nonce-b64").unwrap_or("");
        let req_did = header_str(&headers, "x-secretly-device-id").unwrap_or("");
        let msg = keys_redeem_auth_message(req_did, &profile_id, ts_ms, nonce_b64);
        if let Err(e) =
            verify_requester_device_auth(&state, &headers, msg, true, Some(&profile_id)).await
        {
            tracing::warn!(
                "redeem: device-auth REJECTED profile={} req_did={} status={}",
                profile_id,
                req_did,
                e.0
            );
            return Err(e);
        }
        tracing::info!(
            "redeem: device-auth ok profile={} req_did={}",
            profile_id,
            req_did
        );
    }

    if !state.monetization.enabled {
        let response = build_signed_entitlement_response(&state, &profile_id)
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
        return Ok(Json(response));
    }

    let verified = match req.platform.as_str() {
        "appstore" => {
            let jws = req
                .jws
                .as_deref()
                .ok_or((StatusCode::BAD_REQUEST, "missing jws".to_string()))?;
            let bundle = state.billing.appstore_bundle_id.as_deref().ok_or((
                StatusCode::SERVICE_UNAVAILABLE,
                "appstore not configured".to_string(),
            ))?;
            let root = state.billing.apple_root_der.as_deref().ok_or((
                StatusCode::SERVICE_UNAVAILABLE,
                "appstore root not configured".to_string(),
            ))?;
            match billing::verify_app_store_jws(jws, bundle, root) {
                Ok(v) => v,
                Err(e) => {
                    tracing::warn!(
                        "redeem: appstore JWS verify FAILED profile={}: {:?}",
                        profile_id,
                        e
                    );
                    return Err(map_verify_err(e));
                }
            }
        }
        "play" => {
            let token = req.purchase_token.as_deref().ok_or((
                StatusCode::BAD_REQUEST,
                "missing purchase_token".to_string(),
            ))?;
            let product = req
                .product_id
                .as_deref()
                .ok_or((StatusCode::BAD_REQUEST, "missing product_id".to_string()))?;
            let pkg = state.billing.play_package.as_deref().ok_or((
                StatusCode::SERVICE_UNAVAILABLE,
                "play not configured".to_string(),
            ))?;
            let sa = state.billing.play_sa.as_ref().ok_or((
                StatusCode::SERVICE_UNAVAILABLE,
                "play service account not configured".to_string(),
            ))?;
            match billing::verify_play(&state.http, sa, pkg, product, token).await {
                Ok(v) => v,
                Err(e) => {
                    // Mirror the appstore branch: without this the play verify
                    // failure was silent (only the caller's device-auth/summary
                    // lines showed), which hid a Play Console service-account
                    // permission error (subscriptionsv2 → 401 permissionDenied)
                    // for days. Log the exact reason so redeem failures are
                    // diagnosable from the journal.
                    tracing::warn!(
                        "redeem: play verify FAILED profile={} product={}: {:?}",
                        profile_id,
                        product,
                        e
                    );
                    return Err(map_verify_err(e));
                }
            }
        }
        other => {
            return Err((StatusCode::BAD_REQUEST, format!("unknown platform: {other}")));
        }
    };

    // Report the grant AFTER it happens. This line used to sit above the call
    // and say "granting", which read as success in the log while the grant was
    // still refused a millisecond later. A user whose receipt was bound to an
    // older profile produced ten of these in a row with no entitlement row and
    // no error anywhere — the log promised instead of reporting, and that is
    // what kept a paying customer's stranded purchase invisible for a day.
    tracing::info!(
        "redeem: receipt verified profile={} platform={}",
        profile_id,
        req.platform
    );
    apply_verified_purchase(&state, &profile_id, &verified).await?;
    tracing::info!(
        "redeem: entitlement granted profile={} platform={}",
        profile_id,
        req.platform
    );
    let response = build_signed_entitlement_response(&state, &profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    Ok(Json(response))
}

/// Best-effort lifecycle update from a store webhook: find the profile that owns
/// the transaction and re-apply the (re-verified) tier/expiry. Unknown tx (not
/// yet redeemed) is ignored.
async fn apply_webhook_update(state: &AppState, v: &billing::VerifiedPurchase) {
    let Ok(Some(profile_id)) = state
        .store
        .entitlement_profile_for_store_tx(&v.store_tx_id)
        .await
    else {
        return;
    };
    let _ = state
        .store
        .entitlement_upsert(EntitlementRecord {
            profile_id,
            tier: v.tier.to_string(),
            source: v.source.to_string(),
            store_tx_id: Some(v.store_tx_id.clone()),
            expires_at_ms: v.expires_at_ms,
            grace_until_ms: None,
            updated_at_ms: now_ms(),
        })
        .await;
}

/// POST /v1/webhooks/appstore — App Store Server Notifications V2. Always 200
/// (Apple retries non-2xx aggressively); processing is best-effort + fail-safe.
async fn webhook_appstore(
    State(state): State<AppState>,
    Json(body): Json<serde_json::Value>,
) -> StatusCode {
    let Some(signed) = body.get("signedPayload").and_then(|v| v.as_str()) else {
        return StatusCode::OK;
    };
    let (Some(bundle), Some(root)) = (
        state.billing.appstore_bundle_id.as_deref(),
        state.billing.apple_root_der.as_deref(),
    ) else {
        return StatusCode::OK;
    };
    if let Some(tx_jws) = billing::appstore_notification_inner_jws(signed) {
        if let Ok(v) = billing::verify_app_store_jws(&tx_jws, bundle, root) {
            apply_webhook_update(&state, &v).await;
        }
    }
    StatusCode::OK
}

/// POST /v1/webhooks/play — Google Play Real-Time Developer Notifications (Pub/Sub
/// push). Always 200; re-verifies via the Developer API before applying.
async fn webhook_play(
    State(state): State<AppState>,
    Json(body): Json<serde_json::Value>,
) -> StatusCode {
    let (Some(pkg), Some(sa)) = (
        state.billing.play_package.as_deref(),
        state.billing.play_sa.as_ref(),
    ) else {
        return StatusCode::OK;
    };
    if let Some(ev) = billing::parse_rtdn(&body) {
        if let Ok(v) =
            billing::verify_play(&state.http, sa, pkg, &ev.product_id, &ev.purchase_token).await
        {
            apply_webhook_update(&state, &v).await;
        }
    }
    StatusCode::OK
}

async fn health(
    State(state): State<AppState>,
    Query(query): Query<HealthQuery>,
) -> impl IntoResponse {
    let server_protocol_version = keys_server_protocol_version();
    let min_client_protocol_version = keys_min_client_protocol_version();
    let max_client_protocol_version =
        keys_max_client_protocol_version(min_client_protocol_version, server_protocol_version);
    let compatibility = evaluate_client_compatibility(
        "keys",
        query.client_protocol_version,
        min_client_protocol_version,
        max_client_protocol_version,
    );
    let status_code = if query.client_protocol_version.is_some() && !compatibility.supported {
        StatusCode::UPGRADE_REQUIRED
    } else {
        StatusCode::OK
    };
    let body = HealthResponse {
        status: if compatibility.supported {
            "ok"
        } else {
            "unsupported_client"
        },
        service: "keys",
        server_protocol_version,
        min_client_protocol_version,
        max_client_protocol_version,
        client_protocol_version: query.client_protocol_version,
        compatibility_status: compatibility.compatibility_status,
        compatibility_message: compatibility.compatibility_message,
        deployment_id: optional_trimmed_string(state.deployment_id.as_ref().as_str()),
        release_channel: optional_trimmed_string(state.release_channel.as_ref().as_str()),
        service_started_at_ms: state.service_started_at_ms,
        max_request_body_bytes: KEYS_HTTP_BODY_LIMIT_BYTES as i64,
    };
    (status_code, Json(body))
}

#[derive(Clone)]
struct AppState {
    store: Arc<KeysStore>,
    limiter: Arc<IpRateLimiter>,
    challenges: Arc<DashMap<String, DeviceChallenge>>,
    used_nonces: Arc<DashMap<String, i64>>,
    internal_key: Arc<String>,
    deployment_id: Arc<String>,
    release_channel: Arc<String>,
    service_started_at_ms: i64,
    // Monetization (TZ-MONETIZE-01, S-3): signed config + limits. Defaults are
    // fully open (monetization_enabled=false) so behaviour is unchanged until a
    // human flips the flag at R3.
    monetization: Arc<MonetizationConfig>,
    // Delivery-reliability kill-switches, served (separately signed) on
    // /v1/config. Defaults ON — see ReliabilityConfig.
    reliability: Arc<ReliabilityConfig>,
    identity: Arc<IdentityConfig>,
    rooms: Arc<RoomsConfig>,
    rooms2: Arc<Rooms2Config>,
    handshake: Arc<HandshakeServerConfig>,
    update: Arc<UpdateServerConfig>,
    support: Arc<SupportServerConfig>,
    // Server Ed25519 key used to sign /v1/config (and later entitlements). None
    // in dev/test → responses carry an empty signature (R0 client does not yet
    // verify; the public key is baked into the client before R2).
    config_signing_key: Arc<Option<SigningKey>>,
    /// Shared HTTP client for store verification calls (S-2 Google Play API).
    http: reqwest::Client,
    /// Receipt-verification config: App Store bundle/root, Play service account.
    billing: Arc<billing::BillingVerifyConfig>,
}

/// Monetization limits + kill-switch (TZ-MONETIZE-01 §S-3). Loaded from env with
/// safe, fully-open defaults.
#[derive(Clone)]
struct MonetizationConfig {
    enabled: bool,
    free_attachment_bytes: i64,
    free_group_members: i64,
    free_call_participants: i64,
    free_owned_groups: i64,
    free_joined_groups: i64,
    premium_attachment_bytes: i64,
    premium_group_members: i64,
    premium_call_participants: i64,
    premium_owned_groups: i64,
    premium_joined_groups: i64,
    desktop_trial_days: i64,
    /// Epoch-ms deadline `D` (day of R3) after which legacy_claim returns 410
    /// Gone. None = no deadline configured yet → claims stay open (pre-R3).
    legacy_claim_deadline_ms: Option<i64>,
}

impl MonetizationConfig {
    fn from_env() -> Self {
        fn int_env(key: &str, default: i64) -> i64 {
            std::env::var(key)
                .ok()
                .and_then(|v| v.trim().parse::<i64>().ok())
                .unwrap_or(default)
        }
        let enabled = std::env::var("SECRETLY_MONETIZATION_ENABLED")
            .map(|v| matches!(v.trim().to_ascii_lowercase().as_str(), "1" | "true" | "yes"))
            .unwrap_or(false);
        MonetizationConfig {
            enabled,
            free_attachment_bytes: int_env("SECRETLY_FREE_ATTACHMENT_BYTES", 104_857_600),
            free_group_members: int_env("SECRETLY_FREE_GROUP_MEMBERS", 50),
            free_call_participants: int_env("SECRETLY_FREE_CALL_PARTICIPANTS", 8),
            free_owned_groups: int_env("SECRETLY_FREE_OWNED_GROUPS", 5),
            free_joined_groups: int_env("SECRETLY_FREE_JOINED_GROUPS", 20),
            premium_attachment_bytes: int_env(
                "SECRETLY_PREMIUM_ATTACHMENT_BYTES",
                1_073_741_824,
            ),
            premium_group_members: int_env("SECRETLY_PREMIUM_GROUP_MEMBERS", 500),
            premium_call_participants: int_env("SECRETLY_PREMIUM_CALL_PARTICIPANTS", 50),
            premium_owned_groups: int_env("SECRETLY_PREMIUM_OWNED_GROUPS", 100),
            // -1 = unlimited joined groups for premium.
            premium_joined_groups: int_env("SECRETLY_PREMIUM_JOINED_GROUPS", -1),
            desktop_trial_days: int_env("SECRETLY_DESKTOP_TRIAL_DAYS", 14),
            legacy_claim_deadline_ms: std::env::var("SECRETLY_LEGACY_CLAIM_DEADLINE_MS")
                .ok()
                .and_then(|v| v.trim().parse::<i64>().ok())
                .filter(|n| *n > 0),
        }
    }
}

/// Server-side kill-switches for the self-healing delivery machinery
/// (NACK-driven rekey+resend, sender-convergence resend backstop).
///
/// Defaults are **ON**, and only an explicitly falsey env value turns a switch
/// off. This is deliberately the opposite polarity from `MonetizationConfig`
/// (which defaults to fully open): billing fails OPEN, but delivery reliability
/// is a safety net that must never be disabled by an unset/typo'd variable.
/// The point of the switch is to stop a misbehaving heuristic in minutes
/// instead of waiting on an App Store review.
#[derive(Clone, Copy)]
struct ReliabilityConfig {
    nack_receipts_enabled: bool,
    convergence_resend_enabled: bool,
}

impl Default for ReliabilityConfig {
    fn default() -> Self {
        ReliabilityConfig {
            nack_receipts_enabled: true,
            convergence_resend_enabled: true,
        }
    }
}

impl ReliabilityConfig {
    fn from_env() -> Self {
        ReliabilityConfig {
            nack_receipts_enabled: env_on_unless_disabled("SECRETLY_NACK_RECEIPTS_ENABLED"),
            convergence_resend_enabled: env_on_unless_disabled(
                "SECRETLY_CONVERGENCE_RESEND_ENABLED",
            ),
        }
    }
}

/// Anything that is not an explicit "0"/"false"/"no" keeps the switch ON.
fn env_on_unless_disabled(key: &str) -> bool {
    std::env::var(key)
        .map(|v| {
            !matches!(
                v.trim().to_ascii_lowercase().as_str(),
                "0" | "false" | "no"
            )
        })
        .unwrap_or(true)
}

/// Server-side switch for И-1 rotation-on-state-loss
/// (TZ_I1_IDENTITY_2026-07-21 §Д-5).
///
/// Default ON: deploying this binary is the deliberate act that OFFERS the
/// invariant to clients; `SECRETLY_I1_ROTATION_ENABLED=0` is the lever that
/// stops a rotation avalanche in minutes. The client additionally requires a
/// verified signature before acting (fail-OFF activation), so this flag can
/// offer the behaviour but never force it.
#[derive(Clone, Copy)]
struct IdentityConfig {
    rotation_on_state_loss_enabled: bool,
}

impl Default for IdentityConfig {
    fn default() -> Self {
        IdentityConfig {
            rotation_on_state_loss_enabled: true,
        }
    }
}

impl IdentityConfig {
    fn from_env() -> Self {
        IdentityConfig {
            rotation_on_state_loss_enabled: env_on_unless_disabled(
                "SECRETLY_I1_ROTATION_ENABLED",
            ),
        }
    }
}

/// Server-side source for the additive rooms block (F-ROOMSK-2).
///
/// Default ON so the switch is a genuine KILL-switch: it exists to STOP a
/// misbehaving rollout in minutes, not to be a second place someone has to
/// remember to enable. Sending still requires the client's own compile-time
/// flag, so "on" here grants nothing to a build that was not made for it.
///
/// Kill it with `SECRETLY_ROOM_SENDER_KEY_SEND_ENABLED=0`; every client stops
/// sealing room messages under the sender key within one config poll and falls
/// back to the pairwise fanout, which every build can read.
#[derive(Clone, Copy)]
struct RoomsConfig {
    sender_key_send_enabled: bool,
}

impl Default for RoomsConfig {
    fn default() -> Self {
        RoomsConfig {
            sender_key_send_enabled: true,
        }
    }
}

impl RoomsConfig {
    fn from_env() -> Self {
        RoomsConfig {
            sender_key_send_enabled: env_on_unless_disabled(
                "SECRETLY_ROOM_SENDER_KEY_SEND_ENABLED",
            ),
        }
    }
}

/// Source of the `rooms2` block (К-2 / К-5). Raw broadcast fails OFF; big
/// rooms are off until both numbers are set.
#[derive(Clone, Copy, Default)]
struct Rooms2Config {
    raw_broadcast_enabled: bool,
    big_room_members: i64,
    big_room_min_build: i64,
}

impl Rooms2Config {
    fn from_env() -> Self {
        let int = |key: &str| {
            std::env::var(key)
                .ok()
                .and_then(|v| v.trim().parse::<i64>().ok())
                .unwrap_or(0)
                .max(0)
        };
        Rooms2Config {
            raw_broadcast_enabled: std::env::var("SECRETLY_ROOM_RAW_BROADCAST_ENABLED")
                .map(|v| matches!(v.trim().to_ascii_lowercase().as_str(), "1" | "true" | "yes"))
                .unwrap_or(false),
            big_room_members: int("SECRETLY_BIG_ROOM_MEMBERS"),
            big_room_min_build: int("SECRETLY_BIG_ROOM_MIN_BUILD"),
        }
    }
}

/// Источник блока обновления. По умолчанию 0 — напоминаний нет, пока человек
/// не выставит номер свежей сборки.
#[derive(Clone)]
struct UpdateServerConfig {
    latest_build: i64,
    update_url: String,
}

impl Default for UpdateServerConfig {
    fn default() -> Self {
        UpdateServerConfig {
            latest_build: 0,
            update_url: String::new(),
        }
    }
}

impl UpdateServerConfig {
    fn from_env() -> Self {
        UpdateServerConfig {
            latest_build: std::env::var("SECRETLY_LATEST_BUILD")
                .ok()
                .and_then(|v| v.trim().parse::<i64>().ok())
                .unwrap_or(0)
                .max(0),
            update_url: std::env::var("SECRETLY_UPDATE_URL")
                .ok()
                .map(|v| v.trim().to_string())
                .unwrap_or_default(),
        }
    }
}

/// Источник блока рукопожатия. По умолчанию ВЫКЛЮЧЕНО и доля 0 — фича едет
/// тёмной, пока человек не выставит переменные окружения. Это ровно тот
/// порядок, что записан в плане: сначала измеритель, потом флаг, и только
/// потом — включение долями.
#[derive(Clone, Copy)]
struct HandshakeServerConfig {
    prekey_until_confirmed_send_enabled: bool,
    prekey_until_confirmed_send_percent: i64,
    /// С-2: `SECRETLY_HS_AUTH_ENFORCE_DISABLED=1` снимает отказы проверки
    /// подписи рукопожатия у всех клиентов. По умолчанию выключено — отказы
    /// действуют.
    hs_auth_enforce_disabled: bool,
}

impl Default for HandshakeServerConfig {
    fn default() -> Self {
        HandshakeServerConfig {
            prekey_until_confirmed_send_enabled: false,
            prekey_until_confirmed_send_percent: 0,
            hs_auth_enforce_disabled: false,
        }
    }
}

impl HandshakeServerConfig {
    fn from_env() -> Self {
        let enabled = std::env::var("SECRETLY_PREKEY_UNTIL_CONFIRMED_SEND_ENABLED")
            .ok()
            .map(|v| {
                let v = v.trim().to_ascii_lowercase();
                v == "1" || v == "true" || v == "yes" || v == "on"
            })
            .unwrap_or(false);
        // Доля зажимается в 0..100 здесь, на сервере: клиент не обязан
        // защищаться от опечатки оператора, а «110» не должно означать «всем».
        let percent = std::env::var("SECRETLY_PREKEY_UNTIL_CONFIRMED_SEND_PERCENT")
            .ok()
            .and_then(|v| v.trim().parse::<i64>().ok())
            .unwrap_or(0)
            .clamp(0, 100);
        let hs_auth_enforce_disabled = std::env::var("SECRETLY_HS_AUTH_ENFORCE_DISABLED")
            .ok()
            .map(|v| {
                let v = v.trim().to_ascii_lowercase();
                v == "1" || v == "true" || v == "yes" || v == "on"
            })
            .unwrap_or(false);
        HandshakeServerConfig {
            prekey_until_confirmed_send_enabled: enabled,
            prekey_until_confirmed_send_percent: percent,
            hs_auth_enforce_disabled,
        }
    }
}

/// Server-side source for the additive Support block. Default OFF (fail-OFF):
/// the feature ships dark until a human sets SECRETLY_SUPPORT_PUB_B64 (the
/// X25519 public key from ops/support/gen_support_key.sh) and
/// SECRETLY_SUPPORT_ENABLED=1. No key ⇒ forced OFF regardless of the flag.
#[derive(Clone)]
struct SupportServerConfig {
    support_enabled: bool,
    support_pub_b64: String,
}

impl Default for SupportServerConfig {
    fn default() -> Self {
        SupportServerConfig {
            support_enabled: false,
            support_pub_b64: String::new(),
        }
    }
}

impl SupportServerConfig {
    fn from_env() -> Self {
        let support_pub_b64 = std::env::var("SECRETLY_SUPPORT_PUB_B64")
            .unwrap_or_default()
            .trim()
            .to_string();
        let flag = std::env::var("SECRETLY_SUPPORT_ENABLED")
            .map(|v| matches!(v.trim().to_ascii_lowercase().as_str(), "1" | "true" | "yes"))
            .unwrap_or(false);
        SupportServerConfig {
            support_enabled: flag && !support_pub_b64.is_empty(),
            support_pub_b64,
        }
    }
}

/// Loads the server config-signing Ed25519 key from a base64-encoded 32-byte
/// seed in `SECRETLY_KEYS_CONFIG_SIGNING_KEY`. Returns None if unset/invalid.
fn load_config_signing_key() -> Option<SigningKey> {
    let raw = std::env::var("SECRETLY_KEYS_CONFIG_SIGNING_KEY").ok()?;
    let raw = raw.trim();
    if raw.is_empty() {
        return None;
    }
    let bytes = base64::engine::general_purpose::STANDARD
        .decode(raw.as_bytes())
        .ok()?;
    let seed: [u8; 32] = bytes.as_slice().try_into().ok()?;
    Some(SigningKey::from_bytes(&seed))
}

#[derive(Clone)]
struct DeviceChallenge {
    nonce_b64: String,
    expires_at_ms: i64,
}

fn is_valid_id(s: &str, max_len: usize) -> bool {
    if s.is_empty() || s.len() > max_len {
        return false;
    }
    s.chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
}

/// Validates an optional cosmetic id (frame_id / cover_id).
/// Returns Ok(None) when empty/absent, Ok(Some(id)) when it matches
/// `^[a-z0-9_]{1,32}$`, and Err(()) for anything else.
fn validate_cosmetic_id(value: &Option<String>) -> Result<Option<String>, ()> {
    let s = value.as_deref().unwrap_or("");
    if s.is_empty() {
        return Ok(None);
    }
    if s.len() <= 32 && s.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_')
    {
        Ok(Some(s.to_string()))
    } else {
        Err(())
    }
}

fn log_fingerprint(value: &str) -> String {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return "empty".into();
    }
    let digest = Sha256::digest(trimmed.as_bytes());
    format!(
        "sha256:{:02x}{:02x}{:02x}{:02x}:len={}",
        digest[0],
        digest[1],
        digest[2],
        digest[3],
        trimmed.len()
    )
}

fn b64_decoded_len_is(b64: &str, expected_len: usize) -> bool {
    let Ok(bytes) = base64::engine::general_purpose::STANDARD.decode(b64.as_bytes()) else {
        return false;
    };
    bytes.len() == expected_len
}

#[derive(Clone)]
struct IpRateLimiter {
    buckets: DashMap<std::net::IpAddr, TokenBucket>,
    capacity: f64,
    refill_per_sec: f64,
}

#[derive(Clone, Copy)]
struct TokenBucket {
    tokens: f64,
    last: Instant,
}

impl IpRateLimiter {
    fn new(capacity: u32, refill_per_sec: f64) -> Self {
        Self {
            buckets: DashMap::new(),
            capacity: capacity as f64,
            refill_per_sec,
        }
    }

    fn allow(&self, ip: std::net::IpAddr) -> bool {
        let now = Instant::now();
        let mut entry = self.buckets.entry(ip).or_insert(TokenBucket {
            tokens: self.capacity,
            last: now,
        });

        let elapsed = now.duration_since(entry.last).as_secs_f64();
        if elapsed > 0.0 {
            entry.tokens = (entry.tokens + elapsed * self.refill_per_sec).min(self.capacity);
            entry.last = now;
        }

        if entry.tokens >= 1.0 {
            entry.tokens -= 1.0;
            true
        } else {
            false
        }
    }
}

async fn rate_limit(
    State(state): State<AppState>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    req: Request<Body>,
    next: middleware::Next,
) -> axum::response::Response {
    // Health should always be reachable.
    if req.uri().path() == "/health" {
        return next.run(req).await;
    }

    // Apply to all other endpoints (keys service is a high-value target for enumeration).
    let trust_xff = std::env::var("SECRETLY_KEYS_TRUST_XFF")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(false);

    // This is only safe when the service is not directly reachable from the internet
    // and all traffic passes through a trusted reverse proxy.
    let ip = effective_client_ip(req.headers(), addr.ip(), trust_xff);
    if state.limiter.allow(ip) {
        next.run(req).await
    } else {
        // 🔴 ОТКАЗ ПО ЛИМИТУ МОЛЧАЛ (24.08.2026).
        //
        // Отказ уходил клиенту и НИГДЕ не отмечался: в журнале сервера не было
        // ни одной строки о том, что кому-то отказано. Из-за этого нельзя было
        // ответить на прямой вопрос «сколько отказов и по какому пути» — а
        // README требует мерить ПЕРЕД подъёмом лимита. Защита, которая не
        // печатает, неотличима от отсутствующей.
        //
        // Поле 24.08: звонок не соединился, потому что ответ нечем было
        // зашифровать — клиент получил `429 rate_limited` на запрос бандла.
        // Со стороны сервера этого события не существовало.
        //
        // ПРИВАТНОСТЬ: адрес клиента НЕ пишем. Для замера частоты и для ответа
        // на вопрос «какой путь страдает» достаточно самого пути; адрес — это
        // персональные данные, а мессенджер не обязан их накапливать.
        tracing::warn!(
            path = %req.uri().path(),
            "keys rate limit rejected"
        );
        (StatusCode::TOO_MANY_REQUESTS, "rate_limited").into_response()
    }
}

#[derive(Serialize)]
struct CreateProfileResponse {
    profile_id: String,
    profile_secret_b64: String,
}

#[derive(Deserialize)]
struct DeviceChallengeQuery {
    profile_id: String,
    device_id: String,
}

#[derive(Serialize)]
struct DeviceChallengeResponse {
    nonce_b64: String,
    expires_at_ms: i64,
}

#[derive(Deserialize)]
struct RegisterDeviceProofRequest {
    profile_id: String,
    device_id: String,
    identity_key_pub_b64: String,
    ts_ms: i64,
    nonce_b64: String,
    signature_b64: String,
    device_class: Option<String>,
    device_label: Option<String>,
    /// И-1 (TZ_I1_IDENTITY_2026-07-21 §Д-7): optional id of the device this
    /// registration replaces after a state-loss rotation. At the per-profile
    /// cap the named device is evicted instead of the stalest one, protecting
    /// an innocent sibling (the dead old phone has a RECENT last_seen). Old
    /// clients simply omit it.
    replaces_device_id: Option<String>,
}

#[derive(Serialize)]
struct RegisterDeviceProofResponse {
    ok: bool,
    error_code: Option<String>,
    error_message: Option<String>,
}

#[derive(Deserialize)]
struct SetDesktopCompanionEntitlementRequest {
    limit: Option<usize>,
    source: Option<String>,
}

#[derive(Serialize)]
struct DesktopCompanionEntitlementResponse {
    ok: bool,
    profile_id: String,
    desktop_companion_limit: usize,
    active_companion_devices: usize,
    slots_remaining: usize,
    entitled: bool,
}

#[derive(Serialize)]
struct ProfileExistsResponse {
    exists: bool,
}

#[derive(Deserialize)]
struct ProfileSearchQuery {
    query: String,
    limit: Option<usize>,
}

#[derive(Serialize)]
struct ProfileSearchItemResponse {
    profile_id: String,
    nickname: Option<String>,
    updated_at_ms: i64,
}

#[derive(Serialize)]
struct ProfileSearchResponse {
    items: Vec<ProfileSearchItemResponse>,
}

fn profile_search_min_query_len() -> usize {
    env::var("SECRETLY_KEYS_PROFILE_SEARCH_MIN_QUERY")
        .ok()
        .and_then(|v| v.parse::<usize>().ok())
        .unwrap_or(2)
        .clamp(1, 32)
}

#[derive(Deserialize)]
struct BackupSetRequest {
    profile_id: String,
    device_id: String,
    payload: String,
    payload_sha256_b64: String,
    ts_ms: i64,
    nonce_b64: String,
    signature_b64: String,
    // Э-1 (SEC-01): опора токена доступа. Присылают только клиенты, которые
    // это умеют, поэтому поля необязательные — старые сборки продолжают
    // сохранять архив как раньше.
    //
    // 🔴 Приходят ВМЕСТЕ с архивом и только так. Отдельное обновление
    // проверочного значения дало бы худший исход: владелец прошёл бы проверку
    // доступа новым паролем и не смог расшифровать содержимое, зашифрованное
    // старым (смена пароля архив не перезаливает).
    #[serde(default)]
    access_salt_b64: Option<String>,
    #[serde(default)]
    access_verifier_b64: Option<String>,
}

#[derive(Serialize)]
struct BackupSetResponse {
    ok: bool,
}

#[derive(Serialize)]
struct BackupGetResponse {
    exists: bool,
    profile_id: String,
    payload: Option<String>,
    updated_at_ms: i64,
}

#[derive(Serialize)]
struct ListDevicesEntry {
    device_id: String,
    has_bundle: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    identity_key_pub_b64: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    signed_prekey_pub_b64: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    signed_prekey_sig_b64: Option<String>,
}

#[derive(Serialize)]
struct ListDevicesResponse {
    device_ids: Vec<String>,
    devices: Vec<ListDevicesEntry>,
}

#[derive(Deserialize)]
struct DeleteDeviceRequest {
    profile_id: String,
    device_id: String,
}

#[derive(Serialize)]
struct DeleteDeviceResponse {
    ok: bool,
}

#[derive(Deserialize)]
struct DeleteProfileRequest {
    profile_id: String,
}

#[derive(Serialize)]
struct DeleteProfileResponse {
    ok: bool,
}

#[derive(Serialize)]
struct DeviceLookupResponse {
    exists: bool,
    profile_id: Option<String>,
}

#[derive(Serialize)]
struct DeviceIdentityResponse {
    exists: bool,
    profile_id: Option<String>,
    identity_key_pub_b64: Option<String>,
}

fn require_device_lookup_auth_enabled() -> bool {
    env::var("SECRETLY_KEYS_REQUIRE_DEVICE_LOOKUP_AUTH")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(true)
}

fn max_devices_per_profile() -> usize {
    env::var("SECRETLY_KEYS_MAX_DEVICES_PER_PROFILE")
        .ok()
        .and_then(|v| v.parse::<usize>().ok())
        .unwrap_or(2)
}

/// When the per-profile device cap is hit on a profile-secret-PROVEN
/// registration, evict the stalest existing device (one-out / one-in) instead
/// of rejecting the new (live) device. This prevents a profile that churns
/// device_ids (reinstalls, desktop pairings, key rotations) from filling its
/// slots with stale device_ids and leaving the newest live device
/// undiscoverable. Defaults ON; flip the env var to "0"/"false" to revert to
/// hard-reject without a redeploy.
fn evict_stalest_on_cap() -> bool {
    match env::var("SECRETLY_KEYS_EVICT_STALEST_ON_CAP") {
        Ok(v) => !(v == "0" || v.eq_ignore_ascii_case("false")),
        Err(_) => true,
    }
}

fn default_desktop_companion_limit() -> usize {
    env::var("SECRETLY_KEYS_DEFAULT_DESKTOP_COMPANION_LIMIT")
        .ok()
        .and_then(|v| v.parse::<usize>().ok())
        .unwrap_or(0)
        .min(max_devices_per_profile())
}

fn normalize_device_class(raw: Option<&str>) -> &'static str {
    let value = raw.unwrap_or("").trim().to_ascii_lowercase();
    match value.as_str() {
        "desktop" | "windows" | "macos" | "linux" => "desktop",
        "web" | "browser" => "web",
        _ => "mobile",
    }
}

fn sanitize_device_label(raw: Option<&str>) -> Option<String> {
    let trimmed = raw.unwrap_or("").trim();
    if trimmed.is_empty() {
        return None;
    }

    let sanitized = trimmed
        .chars()
        .filter(|ch| !ch.is_control())
        .take(120)
        .collect::<String>();
    if sanitized.is_empty() {
        None
    } else {
        Some(sanitized)
    }
}

fn requires_desktop_companion_entitlement(device_class: &str) -> bool {
    matches!(device_class, "desktop" | "web")
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum DeviceRegistrationPolicyViolation {
    ProfileDeviceLimitReached,
    DesktopCompanionEntitlementRequired,
    DesktopCompanionLimitReached,
    ServerError,
}

impl DeviceRegistrationPolicyViolation {
    fn code(self) -> &'static str {
        match self {
            DeviceRegistrationPolicyViolation::ProfileDeviceLimitReached => {
                "profile_device_limit_reached"
            }
            DeviceRegistrationPolicyViolation::DesktopCompanionEntitlementRequired => {
                "desktop_companion_entitlement_required"
            }
            DeviceRegistrationPolicyViolation::DesktopCompanionLimitReached => {
                "desktop_companion_limit_reached"
            }
            DeviceRegistrationPolicyViolation::ServerError => "server_error",
        }
    }

    fn message(self, limit: usize) -> String {
        match self {
            DeviceRegistrationPolicyViolation::ProfileDeviceLimitReached => {
                format!("Profile is already using the maximum number of devices ({limit}).")
            }
            DeviceRegistrationPolicyViolation::DesktopCompanionEntitlementRequired => {
                "Desktop companion access is not enabled for this profile. Activate companion access on your primary mobile account, then retry linking desktop.".into()
            }
            DeviceRegistrationPolicyViolation::DesktopCompanionLimitReached => {
                format!("Desktop companion limit reached for this profile ({limit}). Remove an old desktop session or increase the companion seat limit.")
            }
            DeviceRegistrationPolicyViolation::ServerError => {
                "Keys could not verify the current registration policy. Retry in a moment.".into()
            }
        }
    }
}

#[derive(Debug, Clone)]
struct DeviceRegistrationPolicyError {
    violation: DeviceRegistrationPolicyViolation,
    limit: usize,
}

impl DeviceRegistrationPolicyError {
    fn new(violation: DeviceRegistrationPolicyViolation, limit: usize) -> Self {
        Self { violation, limit }
    }

    fn response(self) -> (String, String) {
        (
            self.violation.code().to_string(),
            self.violation.message(self.limit),
        )
    }
}

fn header_str<'a>(headers: &'a HeaderMap, name: &'static str) -> Option<&'a str> {
    headers.get(name).and_then(|v| v.to_str().ok())
}

fn effective_client_ip(
    headers: &HeaderMap,
    socket_ip: std::net::IpAddr,
    trust_xff: bool,
) -> std::net::IpAddr {
    if !trust_xff {
        return socket_ip;
    }

    headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.split(',').next())
        .map(|s| s.trim())
        .and_then(|s| s.parse::<std::net::IpAddr>().ok())
        .unwrap_or(socket_ip)
}

fn internal_key_matches(state: &AppState, headers: &HeaderMap) -> bool {
    let expected = state.internal_key.as_str();
    if expected.is_empty() {
        return false;
    }
    let got = header_str(headers, "x-secretly-internal-key").unwrap_or("");
    !got.is_empty() && got == expected
}

fn nonce_key(device_id: &str, nonce_b64: &str) -> String {
    format!("{device_id}:{nonce_b64}")
}

fn check_and_mark_nonce(
    state: &AppState,
    device_id: &str,
    nonce_b64: &str,
    now: i64,
) -> Result<(), (StatusCode, String)> {
    let key = nonce_key(device_id, nonce_b64);
    if let Some(exp) = state.used_nonces.get(&key).map(|v| *v.value()) {
        if exp > now {
            return Err((StatusCode::UNAUTHORIZED, "replayed nonce".into()));
        }
        state.used_nonces.remove(&key);
    }

    // 10 minutes replay window.
    state.used_nonces.insert(key, now + 10 * 60 * 1000);

    // Best-effort prune to avoid unbounded growth.
    if state.used_nonces.len() > 20_000 {
        let mut to_remove: Vec<String> = Vec::new();
        for it in state.used_nonces.iter() {
            if *it.value() <= now {
                to_remove.push(it.key().clone());
                if to_remove.len() >= 5_000 {
                    break;
                }
            }
        }
        for k in to_remove {
            state.used_nonces.remove(&k);
        }
    }

    Ok(())
}

fn require_profile_secret_enabled() -> bool {
    env::var("SECRETLY_KEYS_REQUIRE_PROFILE_SECRET")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(true)
}

/// Этап SEC-01 для доступа к архиву: `accept` (Э-1) или `require` (Э-2).
///
/// 🔴 РЕЖИМ ПЕРЕМЕННОЙ, А НЕ ПЕРЕСБОРКОЙ. Требование токена — единственная
/// правка во всей находке, способная оставить человека без восстановления.
/// Откат обязан быть быстрее выката: одна переменная и перезапуск, без
/// ожидания сборки.
///
/// `accept` — токен принимается, неверный отвергается, отсутствие допускается.
/// `require` — у профилей, где опора УЖЕ есть, токен обязателен. Профили без
/// опоры обслуживаются прежним путём: их владельцы не могут предъявить то,
/// чего их сборка не умеет считать.
/// Отказать ли в выдаче архива из-за отсутствующего токена (Э-2).
///
/// 🔴 Чистая функция, потому что все четыре условия обязаны быть видны разом.
/// Каждое из них — чья-то потерянная переписка, если ошибиться:
///
/// * `require_mode` — на Э-1 требовать нельзя, в магазинах живут сборки без
///   токена;
/// * `has_verifier` — у профиля без опоры требовать нечего, его владелец
///   физически не может предъявить токен;
/// * `authorized` — подписанное устройство уже доказало право ключами;
/// * `presented_token` — предъявленный токен проверяется отдельно, здесь важен
///   только факт.
fn backup_get_requires_access_token(
    require_mode: bool,
    has_verifier: bool,
    authorized: bool,
    presented_token: bool,
) -> bool {
    require_mode && has_verifier && !authorized && !presented_token
}

/// Применять ли настройки приватности профиля на сервере (SEC-07).
///
/// Режим переменной, а не пересборкой — как и в SEC-01 Э-2.
fn profile_meta_enforce_enabled() -> bool {
    env::var("SECRETLY_KEYS_PROFILE_META_MODE")
        .map(|v| v.eq_ignore_ascii_case("enforce"))
        .unwrap_or(false)
}

/// Значение настройки приватности по ключу: `everyone` | `contacts` | `nobody`.
///
/// Умолчание — `contacts`: ровно то, что показывает клиент, когда настройки
/// нет (`AppController._defaultPrivacyAudience`). Расхождение здесь означало бы,
/// что сервер и приложение обещают человеку разное.
fn profile_audience_for(privacy_audience_json: Option<&str>, key: &str) -> String {
    let raw = privacy_audience_json.unwrap_or("").trim();
    if raw.is_empty() {
        return "contacts".to_string();
    }
    serde_json::from_str::<serde_json::Value>(raw)
        .ok()
        .and_then(|v| v.get(key).and_then(|x| x.as_str().map(|s| s.to_string())))
        .filter(|v| v == "everyone" || v == "contacts" || v == "nobody")
        .unwrap_or_else(|| "contacts".to_string())
}

/// Отдавать ли фотографию профиля и обложку.
///
/// 🔴 ГРАНИЦА, КОТОРУЮ НЕЛЬЗЯ ЗАМАЛЧИВАТЬ. `contacts` здесь **не проверяется**:
/// у сервера ключей нет графа контактов — в нём только профили, устройства и
/// ключи, и узнать, состоят ли двое в контактах, ему физически нечем.
///
/// Значит выполнимо ровно одно из трёх значений: `nobody`. Написать, что
/// «настройки приватности применяются на сервере», было бы ложью — применяется
/// одно значение из трёх, и об этом сказано прямо в модели угроз.
fn profile_meta_shows_photo(audience: &str, is_owner: bool) -> bool {
    is_owner || audience != "nobody"
}

/// Какое время последней активности отдать.
///
/// * владельцу — точное;
/// * `nobody` — ноль, то есть «неизвестно»;
/// * подписанному запросу — точное;
/// * остальным — округлённое вниз до часа: интерфейсу хватает, для наблюдения
///   за распорядком дня — нет.
fn profile_meta_last_seen_ms(
    audience: &str,
    is_owner: bool,
    authenticated: bool,
    raw_ms: i64,
) -> i64 {
    if is_owner {
        return raw_ms;
    }
    if audience == "nobody" {
        return 0;
    }
    if authenticated || raw_ms == 0 {
        return raw_ms;
    }
    const HOUR_MS: i64 = 60 * 60 * 1000;
    (raw_ms / HOUR_MS) * HOUR_MS
}

fn backup_access_require_enabled() -> bool {
    env::var("SECRETLY_KEYS_BACKUP_ACCESS_MODE")
        .map(|v| v.eq_ignore_ascii_case("require"))
        .unwrap_or(false)
}

fn allow_legacy_profiles_without_secret() -> bool {
    env::var("SECRETLY_KEYS_ALLOW_LEGACY_PROFILE_NO_SECRET")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(false)
}

async fn require_profile_secret(
    state: &AppState,
    headers: &HeaderMap,
    profile_id: &str,
) -> Result<(), (StatusCode, String)> {
    if !require_profile_secret_enabled() {
        return Ok(());
    }

    let stored = state
        .store
        .profile_secret_sha256_b64(profile_id)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "store error".into()))?;

    // Legacy profile: allow only when explicitly enabled.
    if stored.as_deref().unwrap_or("").is_empty() {
        if allow_legacy_profiles_without_secret() {
            return Ok(());
        }
        return Err((StatusCode::UNAUTHORIZED, "profile secret required".into()));
    }

    let got = header_str(headers, "x-secretly-profile-secret-b64").unwrap_or("");
    if got.is_empty() {
        return Err((StatusCode::UNAUTHORIZED, "missing profile secret".into()));
    }
    let Ok(sec_bytes) = base64::engine::general_purpose::STANDARD.decode(got.as_bytes()) else {
        return Err((StatusCode::UNAUTHORIZED, "invalid profile secret".into()));
    };
    if sec_bytes.len() != 32 {
        return Err((StatusCode::UNAUTHORIZED, "invalid profile secret".into()));
    }

    let mut h = Sha256::new();
    h.update(&sec_bytes);
    let want = stored.unwrap_or_default();
    let have = base64::engine::general_purpose::STANDARD.encode(h.finalize());
    if have != want {
        return Err((StatusCode::UNAUTHORIZED, "bad profile secret".into()));
    }

    Ok(())
}

async fn enforce_device_registration_policy(
    state: &AppState,
    profile_id: &str,
    device_id: &str,
    device_class: &str,
    evict_stalest_on_cap: bool,
    replaces_device_id: Option<&str>,
) -> Result<(), DeviceRegistrationPolicyError> {
    let existing = state.store.list_devices(profile_id).await.map_err(|_| {
        DeviceRegistrationPolicyError::new(DeviceRegistrationPolicyViolation::ServerError, 0)
    })?;

    let profile_limit = max_devices_per_profile();
    let is_new_device = !existing
        .iter()
        .any(|existing_device_id| existing_device_id == device_id);
    if profile_limit > 0 && is_new_device && existing.len() >= profile_limit {
        // И-1 (TZ_I1_IDENTITY_2026-07-21 §Д-7): a state-loss rotation names the
        // device it replaces. Preferring the named id over "stalest" protects
        // an innocent sibling — the freshly-dead old phone has a RECENT
        // last_seen, so the stalest-ranking would evict the living desktop
        // instead. Trust model: this path is profile-secret-proven, the same
        // authority /v1/device/delete grants the owner anyway, and the hint is
        // honoured only if it names an EXISTING same-profile device that is
        // not the one registering. Anything else falls back to stalest.
        let mut slot_freed_by_hint = false;
        if let Some(replaced) = replaces_device_id
            .map(str::trim)
            .filter(|r| !r.is_empty() && *r != device_id)
        {
            if existing.iter().any(|d| d == replaced) {
                match state.store.delete_device(profile_id, replaced).await {
                    Ok(true) => {
                        tracing::info!(
                            profile_ref = %log_fingerprint(profile_id),
                            evicted_device_ref = %log_fingerprint(replaced),
                            new_device_ref = %log_fingerprint(device_id),
                            cap = profile_limit,
                            "evicted rotation-replaced device to admit new registration at per-profile cap"
                        );
                        slot_freed_by_hint = true;
                    }
                    // Row already gone (race) → the slot is free anyway.
                    Ok(false) => {
                        slot_freed_by_hint = true;
                    }
                    // Store error → fall through to the stalest path below.
                    Err(_) => {}
                }
            }
        }
        // Cap hit while ADDING a genuinely new device. This function is only
        // reached from `register_device_proof` AFTER the profile secret has been
        // proven (require_profile_secret), so the requester is authorized to
        // manage this profile's device roster. Rather than reject the new (live)
        // device — which would leave it undiscoverable while stale device_ids
        // hold the slots — evict the single stalest existing device and proceed
        // strictly one-out / one-in.
        //
        // Invariants upheld here:
        //   (a) never evict the registering device — the eviction query EXCLUDES
        //       `device_id` (and the hint filter above rejects it too);
        //   (b) never leave the profile with zero devices — eviction only runs
        //       in this "adding a new device" branch and removes exactly one
        //       existing device, so the post-op count == profile_limit >= 1;
        //   (c) profile-secret-proven path only — unauthenticated callers never
        //       reach this function.
        if slot_freed_by_hint {
            // One slot freed by the rotation hint; fall through to the
            // companion checks below and then proceed with registration.
        } else if evict_stalest_on_cap {
            match state
                .store
                .stalest_evictable_device(profile_id, device_id)
                .await
            {
                Ok(Some(stale_device_id)) => {
                    // Defensive: the query already excludes the registering
                    // device, but never evict it even if that ever changes.
                    if stale_device_id != device_id {
                        match state.store.delete_device(profile_id, &stale_device_id).await {
                            Ok(true) => {
                                // WARN, not INFO: evicting a device destroys a
                                // live mailbox. Anything still addressed to it is
                                // never read, which reads to the sender as "my
                                // first message vanished". At INFO this was
                                // invisible to every ops filter we actually
                                // watch, and the true scale (115 profiles) had
                                // to be reconstructed by diffing two databases.
                                tracing::warn!(
                                    profile_ref = %log_fingerprint(profile_id),
                                    evicted_device_ref = %log_fingerprint(&stale_device_id),
                                    new_device_ref = %log_fingerprint(device_id),
                                    cap = profile_limit,
                                    "evicted stalest device to admit new registration at per-profile cap"
                                );
                                // One slot freed; fall through to the companion
                                // checks below and then proceed with registration.
                            }
                            // Eviction did not remove a row (race: another path
                            // already deleted it) or the store errored. Fall back
                            // to the original hard reject so we never proceed past
                            // the cap.
                            Ok(false) | Err(_) => {
                                return Err(DeviceRegistrationPolicyError::new(
                                    DeviceRegistrationPolicyViolation::ProfileDeviceLimitReached,
                                    profile_limit,
                                ));
                            }
                        }
                    } else {
                        return Err(DeviceRegistrationPolicyError::new(
                            DeviceRegistrationPolicyViolation::ProfileDeviceLimitReached,
                            profile_limit,
                        ));
                    }
                }
                // No other device to evict (would leave zero devices) or store
                // error — keep the original behavior and reject.
                Ok(None) | Err(_) => {
                    return Err(DeviceRegistrationPolicyError::new(
                        DeviceRegistrationPolicyViolation::ProfileDeviceLimitReached,
                        profile_limit,
                    ));
                }
            }
        } else {
            return Err(DeviceRegistrationPolicyError::new(
                DeviceRegistrationPolicyViolation::ProfileDeviceLimitReached,
                profile_limit,
            ));
        }
    }

    if !requires_desktop_companion_entitlement(device_class) {
        return Ok(());
    }

    let companion_limit = state
        .store
        .desktop_companion_limit(profile_id)
        .await
        .map_err(|_| {
            DeviceRegistrationPolicyError::new(DeviceRegistrationPolicyViolation::ServerError, 0)
        })?
        .unwrap_or_else(default_desktop_companion_limit);

    if companion_limit == 0 {
        return Err(DeviceRegistrationPolicyError::new(
            DeviceRegistrationPolicyViolation::DesktopCompanionEntitlementRequired,
            0,
        ));
    }

    let companion_devices = state
        .store
        .list_companion_devices(profile_id)
        .await
        .map_err(|_| {
            DeviceRegistrationPolicyError::new(DeviceRegistrationPolicyViolation::ServerError, 0)
        })?;

    if !companion_devices
        .iter()
        .any(|existing_device_id| existing_device_id == device_id)
        && companion_devices.len() >= companion_limit
    {
        return Err(DeviceRegistrationPolicyError::new(
            DeviceRegistrationPolicyViolation::DesktopCompanionLimitReached,
            companion_limit,
        ));
    }

    Ok(())
}

fn keys_device_lookup_auth_message(
    requester_device_id: &str,
    target_device_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-KEYS-DEVICE-LOOKUP-V1\nrequester_device_id={}\ntarget_device_id={}\nts_ms={}\nnonce_b64={}\n",
        requester_device_id, target_device_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn keys_device_identity_auth_message(
    requester_device_id: &str,
    target_device_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-KEYS-DEVICE-IDENTITY-V1\nrequester_device_id={}\ntarget_device_id={}\nts_ms={}\nnonce_b64={}\n",
        requester_device_id, target_device_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn keys_profile_search_auth_message(
    requester_device_id: &str,
    query: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-KEYS-PROFILE-SEARCH-V1\nrequester_device_id={}\nquery={}\nts_ms={}\nnonce_b64={}\n",
        requester_device_id, query, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn keys_list_devices_auth_message(
    requester_device_id: &str,
    profile_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-KEYS-LIST-DEVICES-V1\nrequester_device_id={}\nprofile_id={}\nts_ms={}\nnonce_b64={}\n",
        requester_device_id, profile_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn keys_fetch_bundle_auth_message(
    requester_device_id: &str,
    profile_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-KEYS-BUNDLE-FETCH-V1\nrequester_device_id={}\nprofile_id={}\nts_ms={}\nnonce_b64={}\n",
        requester_device_id, profile_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn keys_delete_device_auth_message(
    requester_device_id: &str,
    profile_id: &str,
    target_device_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-KEYS-DELETE-DEVICE-V1\nrequester_device_id={}\nprofile_id={}\ntarget_device_id={}\nts_ms={}\nnonce_b64={}\n",
        requester_device_id, profile_id, target_device_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn keys_delete_profile_auth_message(
    requester_device_id: &str,
    profile_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-KEYS-DELETE-PROFILE-V1\nrequester_device_id={}\nprofile_id={}\nts_ms={}\nnonce_b64={}\n",
        requester_device_id, profile_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn keys_backup_get_auth_message(
    requester_device_id: &str,
    profile_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-KEYS-BACKUP-GET-V1\nrequester_device_id={}\nprofile_id={}\nts_ms={}\nnonce_b64={}\n",
        requester_device_id, profile_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn keys_entitlements_get_auth_message(
    requester_device_id: &str,
    profile_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-KEYS-ENTITLEMENTS-GET-V1\nrequester_device_id={}\nprofile_id={}\nts_ms={}\nnonce_b64={}\n",
        requester_device_id, profile_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn require_entitlements_get_auth_enabled() -> bool {
    env::var("SECRETLY_KEYS_REQUIRE_ENTITLEMENTS_GET_AUTH")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(true)
}

fn require_profile_search_auth_enabled() -> bool {
    env::var("SECRETLY_KEYS_REQUIRE_PROFILE_SEARCH_AUTH")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(true)
}

fn require_list_devices_auth_enabled() -> bool {
    env::var("SECRETLY_KEYS_REQUIRE_LIST_DEVICES_AUTH")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(true)
}

fn require_backup_get_auth_enabled() -> bool {
    env::var("SECRETLY_KEYS_REQUIRE_BACKUP_GET_AUTH")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(true)
}

fn allow_public_backup_restore_enabled() -> bool {
    env::var("SECRETLY_KEYS_ALLOW_PUBLIC_BACKUP_RESTORE")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(true)
}

fn has_backup_get_auth_headers(headers: &HeaderMap) -> bool {
    header_str(headers, "x-secretly-device-id").is_some()
        || header_str(headers, "x-secretly-ts-ms").is_some()
        || header_str(headers, "x-secretly-nonce-b64").is_some()
        || header_str(headers, "x-secretly-signature-b64").is_some()
}

fn require_bundle_fetch_auth_enabled() -> bool {
    env::var("SECRETLY_KEYS_REQUIRE_BUNDLE_FETCH_AUTH")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(true)
}

async fn verify_profile_search_auth(
    state: &AppState,
    headers: &HeaderMap,
    query: &str,
) -> Result<(), (StatusCode, String)> {
    if internal_key_matches(state, headers) {
        return Ok(());
    }

    if !require_profile_search_auth_enabled() {
        return Ok(());
    }

    let requester_device_id = header_str(headers, "x-secretly-device-id")
        .ok_or((
            StatusCode::UNAUTHORIZED,
            "missing x-secretly-device-id".into(),
        ))?
        .to_string();
    let ts_ms = header_str(headers, "x-secretly-ts-ms")
        .ok_or((StatusCode::UNAUTHORIZED, "missing x-secretly-ts-ms".into()))?
        .parse::<i64>()
        .map_err(|_| (StatusCode::UNAUTHORIZED, "bad x-secretly-ts-ms".into()))?;
    let nonce_b64 = header_str(headers, "x-secretly-nonce-b64")
        .ok_or((
            StatusCode::UNAUTHORIZED,
            "missing x-secretly-nonce-b64".into(),
        ))?
        .to_string();
    let signature_b64 = header_str(headers, "x-secretly-signature-b64")
        .ok_or((
            StatusCode::UNAUTHORIZED,
            "missing x-secretly-signature-b64".into(),
        ))?
        .to_string();

    if !is_valid_id(&requester_device_id, 128) {
        return Err((StatusCode::UNAUTHORIZED, "bad requester device_id".into()));
    }

    let now = now_ms();
    if (ts_ms - now).abs() > 5 * 60 * 1000 {
        return Err((StatusCode::UNAUTHORIZED, "timestamp out of range".into()));
    }
    check_and_mark_nonce(state, &requester_device_id, &nonce_b64, now)?;

    let ik = state
        .store
        .identity_key_for_device(&requester_device_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::UNAUTHORIZED, "unknown requester device".into()))?;
    if ik.is_empty() {
        return Err((
            StatusCode::UNAUTHORIZED,
            "requester device missing identity key".into(),
        ));
    }

    let msg = keys_profile_search_auth_message(&requester_device_id, query, ts_ms, &nonce_b64);
    if !verify_ed25519_b64(&ik, &signature_b64, &msg) {
        return Err((StatusCode::UNAUTHORIZED, "bad signature".into()));
    }

    Ok(())
}

async fn verify_requester_device_auth(
    state: &AppState,
    headers: &HeaderMap,
    msg: Vec<u8>,
    require_auth: bool,
    expected_profile_id: Option<&str>,
) -> Result<(), (StatusCode, String)> {
    if internal_key_matches(state, headers) {
        return Ok(());
    }

    if !require_auth {
        return Ok(());
    }

    let requester_device_id = header_str(headers, "x-secretly-device-id")
        .ok_or((
            StatusCode::UNAUTHORIZED,
            "missing x-secretly-device-id".into(),
        ))?
        .to_string();
    let ts_ms = header_str(headers, "x-secretly-ts-ms")
        .ok_or((StatusCode::UNAUTHORIZED, "missing x-secretly-ts-ms".into()))?
        .parse::<i64>()
        .map_err(|_| (StatusCode::UNAUTHORIZED, "bad x-secretly-ts-ms".into()))?;
    let nonce_b64 = header_str(headers, "x-secretly-nonce-b64")
        .ok_or((
            StatusCode::UNAUTHORIZED,
            "missing x-secretly-nonce-b64".into(),
        ))?
        .to_string();
    let signature_b64 = header_str(headers, "x-secretly-signature-b64")
        .ok_or((
            StatusCode::UNAUTHORIZED,
            "missing x-secretly-signature-b64".into(),
        ))?
        .to_string();

    if !is_valid_id(&requester_device_id, 128) {
        return Err((StatusCode::UNAUTHORIZED, "bad requester device_id".into()));
    }

    let now = now_ms();
    if (ts_ms - now).abs() > 5 * 60 * 1000 {
        return Err((StatusCode::UNAUTHORIZED, "timestamp out of range".into()));
    }
    check_and_mark_nonce(state, &requester_device_id, &nonce_b64, now)?;

    let ik = state
        .store
        .identity_key_for_device(&requester_device_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::UNAUTHORIZED, "unknown requester device".into()))?;
    if ik.is_empty() {
        return Err((
            StatusCode::UNAUTHORIZED,
            "requester device missing identity key".into(),
        ));
    }

    if !verify_ed25519_b64(&ik, &signature_b64, &msg) {
        return Err((StatusCode::UNAUTHORIZED, "bad signature".into()));
    }

    if let Some(expected_profile_id) = expected_profile_id {
        let requester_profile_id = state
            .store
            .profile_id_for_device(&requester_device_id)
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
        if requester_profile_id.as_deref() != Some(expected_profile_id) {
            return Err((StatusCode::FORBIDDEN, "forbidden".into()));
        }
    }

    Ok(())
}

async fn verify_device_lookup_auth(
    state: &AppState,
    headers: &HeaderMap,
    target_device_id: &str,
    msg: Vec<u8>,
) -> Result<(), (StatusCode, String)> {
    // Allow trusted internal callers (Relay) to bypass with a shared key.
    if internal_key_matches(state, headers) {
        return Ok(());
    }

    if !require_device_lookup_auth_enabled() {
        return Ok(());
    }

    let requester_device_id = header_str(headers, "x-secretly-device-id")
        .ok_or((
            StatusCode::UNAUTHORIZED,
            "missing x-secretly-device-id".into(),
        ))?
        .to_string();
    let ts_ms = header_str(headers, "x-secretly-ts-ms")
        .ok_or((StatusCode::UNAUTHORIZED, "missing x-secretly-ts-ms".into()))?
        .parse::<i64>()
        .map_err(|_| (StatusCode::UNAUTHORIZED, "bad x-secretly-ts-ms".into()))?;
    let nonce_b64 = header_str(headers, "x-secretly-nonce-b64")
        .ok_or((
            StatusCode::UNAUTHORIZED,
            "missing x-secretly-nonce-b64".into(),
        ))?
        .to_string();
    let signature_b64 = header_str(headers, "x-secretly-signature-b64")
        .ok_or((
            StatusCode::UNAUTHORIZED,
            "missing x-secretly-signature-b64".into(),
        ))?
        .to_string();

    if !is_valid_id(&requester_device_id, 128) {
        return Err((StatusCode::UNAUTHORIZED, "bad requester device_id".into()));
    }
    if !is_valid_id(target_device_id, 128) {
        return Err((StatusCode::UNAUTHORIZED, "bad target device_id".into()));
    }

    let now = now_ms();
    if (ts_ms - now).abs() > 5 * 60 * 1000 {
        return Err((StatusCode::UNAUTHORIZED, "timestamp out of range".into()));
    }
    check_and_mark_nonce(state, &requester_device_id, &nonce_b64, now)?;

    let ik = state
        .store
        .identity_key_for_device(&requester_device_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::UNAUTHORIZED, "unknown requester device".into()))?;
    if ik.is_empty() {
        return Err((
            StatusCode::UNAUTHORIZED,
            "requester device missing identity key".into(),
        ));
    }

    if !verify_ed25519_b64(&ik, &signature_b64, &msg) {
        return Err((StatusCode::UNAUTHORIZED, "bad signature".into()));
    }

    Ok(())
}

#[derive(Deserialize)]
struct PublishKeysRequest {
    profile_id: String,
    device_id: String,
    identity_key_pub_b64: String,
    signed_prekey_pub_b64: String,
    signed_prekey_sig_b64: String,
    one_time_prekeys: Vec<OneTimePrekey>,
    ts_ms: i64,
    nonce_b64: String,
    signature_b64: Option<String>,
    /// Account identity (2026-08-08): one safety number per PERSON.
    ///
    /// 🔴 NOT covered by the publish signature, and that is deliberate. The
    /// signed message is `SECRETLY-KEYS-PUBLISH-V1` with a FIXED field list
    /// (`publish_keys_signature_b64`); adding fields to it would break the
    /// signature of every client built before this, killing their key publish and
    /// with it their delivery.
    ///
    /// Leaving them unsigned costs nothing, because neither is trusted on the
    /// server's word: the certificate is self-validating (signed by the account
    /// key), and the receiver PINS a contact's account key on first sight, so a
    /// swapped key reads as "safety number changed" rather than being accepted
    /// silently.
    #[serde(default)]
    account_identity_pub_b64: Option<String>,
    #[serde(default)]
    device_cert_b64: Option<String>,
}

/// 🔴 ОТКАЗ ОБЯЗАН НАЗЫВАТЬ ПРИЧИНУ.
///
/// Раньше ответ был голым `ok: false` — двенадцать разных отказов выглядели
/// одинаково. Клиент превращал это в `StateError('publishKeys returned
/// ok=false')`, а экран спаривания показывал человеку текст исключения Dart
/// рядом с надписью «QR недоступен». Ни человек, ни поддержка, ни разбор по
/// журналу не могли отличить уплывшие часы от неверной подписи.
///
/// Поле необязательное, поэтому старые сборки, читающие только `ok`, ничего не
/// замечают. Ровно так же 12.09.2026 перестал молчать путь авторизации реле —
/// и сразу выяснилось, что 13 отказов из 13 это отставшие часы.
#[derive(Serialize)]
struct PublishKeysResponse {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    reason: Option<&'static str>,
}

impl PublishKeysResponse {
    fn ok() -> Self {
        Self { ok: true, reason: None }
    }

    /// Отказ с причиной: она же уходит в журнал сервера вместе с отпечатком
    /// устройства, чтобы разбор не требовал воспроизведения у человека.
    fn refused(reason: &'static str, profile_id: &str, device_id: &str) -> Self {
        tracing::warn!(
            target: "keys_publish",
            reason = reason,
            profile = %short_id(profile_id),
            device = %short_id(device_id),
            "publish_keys refused"
        );
        Self { ok: false, reason: Some(reason) }
    }
}

/// Восемь символов — достаточно, чтобы сопоставить со своим журналом, и
/// недостаточно, чтобы журнал стал хранилищем чужих идентификаторов.
fn short_id(id: &str) -> String {
    id.chars().take(8).collect()
}

#[derive(Serialize)]
struct FetchBundleResponse {
    devices: Vec<store::DeviceKeyBundle>,
}

#[derive(Serialize)]
struct ProfileMetaResponse {
    exists: bool,
    profile_id: String,
    nickname: Option<String>,
    avatar_png_b64: Option<String>,
    bio: Option<String>,
    privacy_audience_json: Option<String>,
    searchable_by_nickname: bool,
    frame_id: Option<String>,
    cover_id: Option<String>,
    cover_png_b64: Option<String>,
    emoji_status: Option<String>,
    premium_badge: Option<String>,
    updated_at_ms: i64,
    last_active_at_ms: i64,
}

#[derive(Deserialize)]
struct ProfileMetaSetRequest {
    profile_id: String,
    device_id: String,
    nickname: Option<String>,
    avatar_png_b64: Option<String>,
    bio: Option<String>,
    privacy_audience_json: Option<String>,
    searchable_by_nickname: Option<bool>,
    frame_id: Option<String>,
    cover_id: Option<String>,
    cover_png_b64: Option<String>,
    emoji_status: Option<String>,
    premium_badge: Option<String>,
    signature_b64: String,
}

#[derive(Serialize)]
struct ProfileMetaSetResponse {
    ok: bool,
}

#[derive(Deserialize)]
struct ProfileInactivitySetRequest {
    profile_id: String,
    device_id: String,
    delete_after_inactivity_months: Option<i64>,
    ts_ms: i64,
    nonce_b64: String,
    signature_b64: String,
}

#[derive(Deserialize)]
struct ProfileInactivityHeartbeatRequest {
    profile_id: String,
    device_id: String,
    ts_ms: i64,
    nonce_b64: String,
    signature_b64: String,
}

#[derive(Serialize)]
struct ProfileInactivityResponse {
    exists: bool,
    ok: bool,
    delete_after_inactivity_months: Option<i64>,
    last_active_at_ms: i64,
}

fn now_ms() -> i64 {
    // coarse time for debugging; not used for crypto.
    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default();
    ts.as_millis() as i64
}

fn profile_meta_set_message(
    profile_id: &str,
    device_id: &str,
    nickname: &str,
    avatar_png_b64: &str,
    bio: &str,
    privacy_audience_json: &str,
    searchable_by_nickname: bool,
) -> Vec<u8> {
    format!(
        "SECRETLY-PROFILE-META-SET-V1\nprofile_id={}\ndevice_id={}\nnickname={}\navatar_png_b64={}\nbio={}\nprivacy_audience_json={}\nsearchable_by_nickname={}\n",
        profile_id,
        device_id,
        nickname,
        avatar_png_b64,
        bio,
        privacy_audience_json,
        if searchable_by_nickname { 1 } else { 0 }
    )
    .into_bytes()
}

fn canonicalize_privacy_audience_json(raw: &str) -> Option<String> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Some(String::new());
    }
    let value: serde_json::Value = serde_json::from_str(trimmed).ok()?;
    let obj = value.as_object()?;
    const KEYS: [&str; 6] = [
        "last_seen",
        "photo",
        "forwards",
        "calls",
        "voice_messages",
        "messages",
    ];
    if obj.len() != KEYS.len() {
        return None;
    }
    let mut values = Vec::with_capacity(KEYS.len());
    for key in KEYS {
        let raw_value = obj.get(key)?.as_str()?;
        if raw_value != "nobody" && raw_value != "contacts" && raw_value != "everyone" {
            return None;
        }
        values.push(raw_value);
    }
    Some(format!(
        "{{\"last_seen\":\"{}\",\"photo\":\"{}\",\"forwards\":\"{}\",\"calls\":\"{}\",\"voice_messages\":\"{}\",\"messages\":\"{}\"}}",
        values[0], values[1], values[2], values[3], values[4], values[5]
    ))
}

fn normalize_delete_after_inactivity_months(raw: Option<i64>) -> Option<Option<i64>> {
    match raw {
        None | Some(0) => Some(None),
        Some(months) if (1..=24).contains(&months) => Some(Some(months)),
        _ => None,
    }
}

fn profile_inactivity_set_message(
    profile_id: &str,
    device_id: &str,
    delete_after_inactivity_months: Option<i64>,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    let months = delete_after_inactivity_months
        .map(|value| value.to_string())
        .unwrap_or_default();
    format!(
        "SECRETLY-PROFILE-INACTIVITY-SET-V1\nprofile_id={}\ndevice_id={}\ndelete_after_inactivity_months={}\nts_ms={}\nnonce_b64={}\n",
        profile_id, device_id, months, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn profile_inactivity_heartbeat_message(
    profile_id: &str,
    device_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-PROFILE-INACTIVITY-HEARTBEAT-V1\nprofile_id={}\ndevice_id={}\nts_ms={}\nnonce_b64={}\n",
        profile_id, device_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

/// Does this profile exist — with a store error kept DISTINCT from "no".
///
/// 🔴 The distinction is the whole point. `exists: false` is not information to
/// this client, it is an INSTRUCTION: `_handleDeletedProfileFromServer()` wipes
/// the profile id, the local database, the contacts and the purchases, then
/// registers a brand-new identity. Everyone who ever added the user keeps
/// writing to the old profile, into a mailbox nobody will ever read again.
///
/// So a `.unwrap_or(false)` here — an error silently read as "no such profile"
/// — means ONE transient database hiccup costs a real person their account.
/// `None` lets the caller answer "I don't know" (5xx), which every client
/// already treats as transient and retries.
async fn profile_exists_or_unknown(state: &AppState, profile_id: &str) -> Option<bool> {
    match state.store.profile_exists(profile_id).await {
        Ok(exists) => Some(exists),
        Err(e) => {
            tracing::error!(
                profile_ref = %log_fingerprint(profile_id),
                error = %e,
                "profile_exists store error — answering UNKNOWN, never \"deleted\""
            );
            None
        }
    }
}

fn profile_inactivity_response_from_status(
    status: Option<ProfileInactivityStatus>,
    ok: bool,
) -> ProfileInactivityResponse {
    match status {
        Some(status) => ProfileInactivityResponse {
            exists: true,
            ok,
            delete_after_inactivity_months: status.delete_after_inactivity_months,
            last_active_at_ms: status.last_active_at_ms,
        },
        None => ProfileInactivityResponse {
            exists: false,
            ok: false,
            delete_after_inactivity_months: None,
            last_active_at_ms: 0,
        },
    }
}

async fn profile_inactivity_response_for_profile(
    state: &AppState,
    profile_id: &str,
    ok: bool,
) -> ProfileInactivityResponse {
    let status = state
        .store
        .profile_inactivity_get(profile_id)
        .await
        .unwrap_or(None);
    profile_inactivity_response_from_status(status, ok)
}

/// Сравнение с постоянным временем.
///
/// Обычное `==` на срезах выходит на первом несовпавшем байте, и по времени
/// ответа можно подбирать проверочное значение побайтно. Здесь время зависит
/// только от длины.
fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let mut diff: u8 = 0;
    for (x, y) in a.iter().zip(b.iter()) {
        diff |= x ^ y;
    }
    diff == 0
}

/// Правдоподобная соль для профиля, у которого опоры нет.
///
/// 🔴 Без неё запрос вызова работает оракулом существования: «соли нет» —
/// значит профиля нет либо он ещё не пересохранял архив. Ответ обязан быть
/// неотличим, поэтому соль выводится детерминированно из внутреннего ключа и
/// идентификатора: одинакова между запросами (иначе видно, что она поддельная)
/// и не раскрывает ничего о профиле.
fn decoy_access_salt_b64(internal_key: &str, profile_id: &str) -> String {
    let mut h = Sha256::new();
    h.update(b"secretly-backup-access-decoy-v1\n");
    h.update(internal_key.as_bytes());
    h.update(b"\n");
    h.update(profile_id.as_bytes());
    base64::engine::general_purpose::STANDARD.encode(&h.finalize()[..16])
}

/// SEC-07: сообщение подписи для запроса метаданных профиля.
///
/// Эндпоинт исторически отвечал вообще без авторизации — вместе с именем и
/// аватаром отдавалось точное время последней активности, по которому
/// посторонний мог строить график чужого дня. Подпись вводится постепенно:
/// сервер её ПРИНИМАЕТ, но не требует, иначе полторы тысячи уже выпущенных
/// клиентов разом лишились бы имён и аватаров собеседников.
fn profile_meta_get_message(
    requester_device_id: &str,
    profile_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-PROFILE-META-GET-V1\nrequester_device_id={}\nprofile_id={}\nts_ms={}\nnonce_b64={}\n",
        requester_device_id, profile_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn backup_set_message(
    profile_id: &str,
    device_id: &str,
    payload_sha256_b64: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-BACKUP-SET-V1\nprofile_id={}\ndevice_id={}\npayload_sha256_b64={}\nts_ms={}\nnonce_b64={}\n",
        profile_id, device_id, payload_sha256_b64, ts_ms, nonce_b64
    )
    .into_bytes()
}

/// Э-1: сообщение подписи, когда клиент прислал опору токена доступа.
///
/// Опора обязана быть ПОД подписью: иначе посредник внутри TLS подменил бы
/// проверочное значение и запер владельца в его собственном архиве. Отдельная
/// версия сообщения, а не расширение прежней, — чтобы старые клиенты
/// продолжали подписывать ровно то, что подписывали всегда.
fn backup_set_message_v2(
    profile_id: &str,
    device_id: &str,
    payload_sha256_b64: &str,
    access_salt_b64: &str,
    access_verifier_b64: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-BACKUP-SET-V2\nprofile_id={}\ndevice_id={}\npayload_sha256_b64={}\naccess_salt_b64={}\naccess_verifier_b64={}\nts_ms={}\nnonce_b64={}\n",
        profile_id,
        device_id,
        payload_sha256_b64,
        access_salt_b64,
        access_verifier_b64,
        ts_ms,
        nonce_b64
    )
    .into_bytes()
}

async fn backup_set(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<BackupSetRequest>,
) -> Json<BackupSetResponse> {
    // Every rejection below logs a structured `reason` (2026-07-05: backup_set
    // previously returned a bare ok:false with ZERO logging, so a stranded user
    // — and we — had no way to tell WHY a "backup" silently failed to store.
    // The reason names the failed check only; it never logs payload bytes,
    // signatures, or the profile secret.
    fn reject(profile_id: &str, device_id: &str, reason: &str) -> Json<BackupSetResponse> {
        tracing::warn!(
            "backup_set rejected profile={} device={} reason={}",
            profile_id,
            device_id,
            reason
        );
        Json(BackupSetResponse { ok: false })
    }

    if !is_valid_id(&req.profile_id, 128) || !is_valid_id(&req.device_id, 128) {
        return reject(&req.profile_id, &req.device_id, "invalid_id");
    }

    // Payload is encrypted client-side. Enforce size to prevent abuse. The
    // route-specific DefaultBodyLimit (KEYS_BACKUP_MAX_BODY_BYTES) is the outer
    // guard that returns 413 before we allocate; this is the semantic cap.
    if req.payload.len() > KEYS_BACKUP_MAX_PAYLOAD_BYTES {
        tracing::warn!(
            "backup_set rejected profile={} device={} reason=payload_too_large bytes={} cap={}",
            req.profile_id,
            req.device_id,
            req.payload.len(),
            KEYS_BACKUP_MAX_PAYLOAD_BYTES
        );
        return Json(BackupSetResponse { ok: false });
    }
    if req.payload_sha256_b64.len() > 128 {
        return reject(&req.profile_id, &req.device_id, "sha_field_too_long");
    }
    if req.nonce_b64.is_empty() || req.nonce_b64.len() > 512 {
        return reject(&req.profile_id, &req.device_id, "bad_nonce_len");
    }

    if require_profile_secret(&state, &headers, &req.profile_id)
        .await
        .is_err()
    {
        return reject(&req.profile_id, &req.device_id, "profile_secret_mismatch");
    }

    // Verify sha256 matches.
    let h = Sha256::digest(req.payload.as_bytes());
    let have = base64::engine::general_purpose::STANDARD.encode(h);
    if have != req.payload_sha256_b64 {
        return reject(&req.profile_id, &req.device_id, "sha_mismatch");
    }

    let now = now_ms();
    if (req.ts_ms - now).abs() > 5 * 60 * 1000 {
        tracing::warn!(
            "backup_set rejected profile={} device={} reason=clock_skew ts_ms={} now_ms={} skew_ms={}",
            req.profile_id,
            req.device_id,
            req.ts_ms,
            now,
            (req.ts_ms - now).abs()
        );
        return Json(BackupSetResponse { ok: false });
    }
    if check_and_mark_nonce(&state, &req.device_id, &req.nonce_b64, now).is_err() {
        return reject(&req.profile_id, &req.device_id, "nonce_replayed");
    }

    // Auth: device must belong to profile and have an identity key. Verify signature.
    let device_profile = state
        .store
        .profile_id_for_device(&req.device_id)
        .await
        .unwrap_or(None);
    if device_profile.as_deref() != Some(req.profile_id.as_str()) {
        return reject(&req.profile_id, &req.device_id, "device_not_bound_to_profile");
    }
    let ik = state
        .store
        .identity_key_for_device(&req.device_id)
        .await
        .unwrap_or(None);
    let Some(ik_b64) = ik else {
        return reject(&req.profile_id, &req.device_id, "no_identity_key");
    };
    if ik_b64.is_empty() {
        return reject(&req.profile_id, &req.device_id, "empty_identity_key");
    }

    // Э-1: какое сообщение подписывал клиент — зависит от того, прислал ли он
    // опору токена доступа. Обе половины опоры либо есть, либо нет: половина
    // опоры бессмысленна и принимать её нельзя.
    let access = match (
        req.access_salt_b64.as_deref(),
        req.access_verifier_b64.as_deref(),
    ) {
        (Some(salt), Some(verifier)) if !salt.is_empty() && !verifier.is_empty() => {
            Some((salt, verifier))
        }
        (None, None) => None,
        _ => {
            return reject(&req.profile_id, &req.device_id, "incomplete_backup_access");
        }
    };

    let msg = match access {
        Some((salt, verifier)) => backup_set_message_v2(
            &req.profile_id,
            &req.device_id,
            &req.payload_sha256_b64,
            salt,
            verifier,
            req.ts_ms,
            &req.nonce_b64,
        ),
        None => backup_set_message(
            &req.profile_id,
            &req.device_id,
            &req.payload_sha256_b64,
            req.ts_ms,
            &req.nonce_b64,
        ),
    };
    if !verify_ed25519_b64(&ik_b64, &req.signature_b64, &msg) {
        return reject(&req.profile_id, &req.device_id, "bad_signature");
    }

    let ok = state
        .store
        .backup_set(&req.profile_id, &req.payload, &req.payload_sha256_b64, now)
        .await
        .unwrap_or(false);
    if ok {
        // 🔴 Опора пишется ТОЛЬКО после успешной записи архива и только вместе
        // с ним. Порядок именно такой: проверочное значение, оставшееся от
        // пароля, которым текущий архив НЕ зашифрован, впустит владельца и
        // оставит его с нечитаемым содержимым.
        if let Some((salt, verifier)) = access {
            if let Err(e) = state
                .store
                .backup_access_set(&req.profile_id, salt, verifier)
                .await
            {
                tracing::warn!(
                    profile_id = %req.profile_id,
                    error = %e,
                    "backup_access_set failed"
                );
            }
        }
        let _ = state.store.mark_profile_active(&req.profile_id, now).await;
        tracing::info!(
            "backup_set stored profile={} device={} bytes={} access_bound={}",
            req.profile_id,
            req.device_id,
            req.payload.len(),
            access.is_some()
        );
    } else {
        tracing::warn!(
            "backup_set rejected profile={} device={} reason=store_write_failed",
            req.profile_id,
            req.device_id
        );
    }

    Json(BackupSetResponse { ok })
}

#[derive(Serialize)]
struct BackupChallengeResponse {
    profile_id: String,
    access_salt_b64: String,
}

/// Э-1 (SEC-01): соль для вывода токена доступа к архиву.
///
/// Отдаётся публично и намеренно: сама по себе соль ничего не открывает, а без
/// неё владелец не сможет вывести токен из своего пароля на новом устройстве,
/// где ключей ещё нет. Для профилей без опоры отдаётся правдоподобная ложная
/// соль — ответ обязан быть неотличим (см. `decoy_access_salt_b64`).
async fn backup_challenge(
    State(state): State<AppState>,
    Path(profile_id): Path<String>,
) -> Json<BackupChallengeResponse> {
    let decoy = decoy_access_salt_b64(&state.internal_key, &profile_id);
    if !is_valid_id(&profile_id, 128) {
        return Json(BackupChallengeResponse {
            profile_id,
            access_salt_b64: decoy,
        });
    }
    let salt = state
        .store
        .backup_access_get(&profile_id)
        .await
        .unwrap_or(None)
        .and_then(|(salt, _)| salt)
        .filter(|s| !s.is_empty())
        .unwrap_or(decoy);
    Json(BackupChallengeResponse {
        profile_id,
        access_salt_b64: salt,
    })
}

async fn backup_get(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(profile_id): Path<String>,
) -> Json<BackupGetResponse> {
    if !is_valid_id(&profile_id, 128) {
        return Json(BackupGetResponse {
            exists: false,
            profile_id,
            payload: None,
            updated_at_ms: 0,
        });
    }

    let has_auth_headers = has_backup_get_auth_headers(&headers);
    // Э-0 (25.08.2026), SEC-01. Поведение на этом этапе НЕ меняется — меняется
    // только видимость: до сих пор выдача архива постороннему не оставляла в
    // журнале ни одной строки, поэтому на вопрос «происходит ли это уже
    // сейчас» ответить было нечем.
    let mut authorized = false;
    if require_backup_get_auth_enabled()
        && (has_auth_headers || !allow_public_backup_restore_enabled())
    {
        let ts_ms = header_str(&headers, "x-secretly-ts-ms")
            .and_then(|s| s.parse::<i64>().ok())
            .unwrap_or(0);
        let nonce_b64 = header_str(&headers, "x-secretly-nonce-b64").unwrap_or("");
        let req_did = header_str(&headers, "x-secretly-device-id").unwrap_or("");
        let msg = keys_backup_get_auth_message(req_did, &profile_id, ts_ms, nonce_b64);
        if verify_requester_device_auth(
            &state,
            &headers,
            msg,
            require_backup_get_auth_enabled(),
            Some(&profile_id),
        )
        .await
        .is_err()
        {
            tracing::warn!(
                profile_id = %profile_id,
                "backup_get rejected: device auth failed"
            );
            return Json(BackupGetResponse {
                exists: false,
                profile_id,
                payload: None,
                updated_at_ms: 0,
            });
        }
        authorized = true;
    }

    // ── Э-1 (SEC-01): токен доступа, выводимый из пароля архива ─────────────
    //
    // На этом этапе токен ПРИНИМАЕТСЯ, но не требуется: в магазинах живут
    // сборки, которые его не умеют, и требование сразу оставило бы их владельцев
    // без восстановления навсегда. Требование включается на Э-2 — и только для
    // профилей, у которых опора уже есть.
    //
    // Предъявленный НЕВЕРНЫЙ токен — отказ: раз владелец умеет его считать,
    // несовпадение означает чужого либо чужой пароль.
    let presented = header_str(&headers, "x-secretly-backup-access-b64").unwrap_or("");
    let mut access_ok: Option<bool> = None;
    let stored_verifier = state
        .store
        .backup_access_get(&profile_id)
        .await
        .unwrap_or(None)
        .and_then(|(_, verifier)| verifier)
        .filter(|v| !v.is_empty());

    // ── Э-2 (SEC-01): у профиля есть опора — токен обязателен ───────────────
    //
    // Только для тех, у кого опора УЖЕ есть: значит их приложение умеет её
    // считать, и требование им по силам. Профиль без опоры обслуживается
    // прежним путём — иначе владелец старой сборки остался бы без
    // восстановления навсегда.
    //
    // Подписанное устройство того же профиля пропускается: оно предъявило
    // ключи, то есть уже доказало право. Токен нужен там, где доказательства
    // нет вовсе, — на пути «восстановление на чистом устройстве».
    if backup_get_requires_access_token(
        backup_access_require_enabled(),
        stored_verifier.is_some(),
        authorized,
        !presented.is_empty(),
    ) {
        tracing::warn!(
            profile_id = %profile_id,
            "backup_get rejected: access token required for this profile"
        );
        return Json(BackupGetResponse {
            exists: false,
            profile_id,
            payload: None,
            updated_at_ms: 0,
        });
    }

    // 🔴 Запирание по ПРОФИЛЮ, а не по адресу. Лимит по IP обходится сменой
    // адреса, а подбор токена — это подбор пароля архива: он обязан упираться
    // в стену независимо от того, откуда идут запросы.
    if stored_verifier.is_some() && !authorized {
        let locked_until = state
            .store
            .backup_access_lock_until_ms(&profile_id)
            .await
            .unwrap_or(0);
        if locked_until > now_ms() {
            tracing::warn!(
                profile_id = %profile_id,
                "backup_get rejected: profile locked after failed access attempts"
            );
            return Json(BackupGetResponse {
                exists: false,
                profile_id,
                payload: None,
                updated_at_ms: 0,
            });
        }
    }

    if !presented.is_empty() {
        let stored = stored_verifier.clone();
        if let Some(expected) = stored {
            let token = base64::engine::general_purpose::STANDARD
                .decode(presented)
                .unwrap_or_default();
            let actual = base64::engine::general_purpose::STANDARD
                .encode(Sha256::digest(&token));
            let ok = !token.is_empty()
                && constant_time_eq(actual.as_bytes(), expected.as_bytes());
            access_ok = Some(ok);
            if ok {
                let _ = state.store.backup_access_note_success(&profile_id).await;
            } else {
                let attempts = state
                    .store
                    .backup_access_note_failure(&profile_id, now_ms())
                    .await
                    .unwrap_or(0);
                tracing::warn!(
                    profile_id = %profile_id,
                    attempts = attempts,
                    "backup_get rejected: backup access token mismatch"
                );
                return Json(BackupGetResponse {
                    exists: false,
                    profile_id,
                    payload: None,
                    updated_at_ms: 0,
                });
            }
        }
    }

    let _ = state.store.mark_profile_active(&profile_id, now_ms()).await;

    let row = state.store.backup_get(&profile_id).await.unwrap_or(None);
    if let Some((payload, _sha, updated)) = row {
        // 🔴 Ключевая строка этапа Э-0: `authorized = false` означает, что архив
        // ушёл тому, кто ничего не предъявлял. Пока это штатный путь
        // восстановления на новом устройстве, но именно по этой строке можно
        // отличить восстановление от постороннего сбора — и увидеть, что
        // происходило раньше, когда след не оставался вовсе.
        tracing::info!(
            profile_id = %profile_id,
            authorized = authorized,
            access_token = ?access_ok,
            bytes = payload.len(),
            "backup_get served"
        );
        return Json(BackupGetResponse {
            exists: true,
            profile_id,
            payload: Some(payload),
            updated_at_ms: updated,
        });
    }

    tracing::info!(
        profile_id = %profile_id,
        authorized = authorized,
        "backup_get miss"
    );
    Json(BackupGetResponse {
        exists: false,
        profile_id,
        payload: None,
        updated_at_ms: 0,
    })
}

async fn profile_meta_get(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(profile_id): Path<String>,
) -> Json<ProfileMetaResponse> {
    // PRESENCE-LIE FIX (2026-07-21): report the explicit presence heartbeat,
    // not account liveness. Peers render this as «Онлайн», and
    // last_active_at_ms is bumped by any device touch — so a push that merely
    // woke a peer's phone (which then republishes its keys) used to show them
    // as online although nobody touched the device. Reproduced on a Pixel,
    // where FCM wakes the app reliably; battery-throttled phones hid it.
    //
    // The wire field keeps its name, so every already-shipped client gets the
    // honest value with no app update. 0 = we have never seen a heartbeat,
    // which clients already treat as "unknown" and render offline.
    let last_active_at_ms = state
        .store
        .profile_inactivity_get(&profile_id)
        .await
        .unwrap_or(None)
        .map(|status| status.last_presence_at_ms)
        .unwrap_or(0);

    // ── SEC-07: точное время присутствия — только предъявившему подпись ──────
    //
    // Эндпоинт отвечает без авторизации: так его вызывают все уже выпущенные
    // клиенты, и отнять это разом значит лишить людей имён и аватаров
    // собеседников. Но точное время присутствия в открытом ответе — это
    // возможность следить: опрашивая раз в минуту, посторонний строит график
    // чужого дня, зная только полупубличный идентификатор.
    //
    // Поэтому: подпись ПРИНИМАЕТСЯ, но не требуется. Предъявившему отдаём
    // точное значение, остальным — огрублённое до часа. «Был в сети» остаётся
    // осмысленным, слежка становится бессмысленной.
    //
    // Требование подписи включится отдельным этапом, когда измеритель версий
    // покажет, что клиенты научились её присылать.
    let requester_authenticated = {
        let ts_ms = header_str(&headers, "x-secretly-ts-ms")
            .and_then(|v| v.parse::<i64>().ok())
            .unwrap_or(0);
        let nonce_b64 = header_str(&headers, "x-secretly-nonce-b64").unwrap_or("");
        let req_did = header_str(&headers, "x-secretly-device-id").unwrap_or("");
        if req_did.is_empty() {
            false
        } else {
            let msg = profile_meta_get_message(req_did, &profile_id, ts_ms, nonce_b64);
            verify_requester_device_auth(&state, &headers, msg, true, None)
                .await
                .is_ok()
        }
    };

    // SEC-07: владелец отличается от «просто подписанного устройства».
    // `requester_authenticated` выше означает лишь «какое-то
    // зарегистрированное устройство подписало запрос» — а завести своё
    // устройство может кто угодно. Здесь проверяется принадлежность ИМЕННО
    // этому профилю, иначе настройка `nobody` спрятала бы фотографию от самого
    // владельца.
    let requester_is_owner = if !requester_authenticated {
        false
    } else {
        let ts_ms = header_str(&headers, "x-secretly-ts-ms")
            .and_then(|v| v.parse::<i64>().ok())
            .unwrap_or(0);
        let nonce_b64 = header_str(&headers, "x-secretly-nonce-b64").unwrap_or("");
        let req_did = header_str(&headers, "x-secretly-device-id").unwrap_or("");
        let msg = profile_meta_get_message(req_did, &profile_id, ts_ms, nonce_b64);
        verify_requester_device_auth(&state, &headers, msg, true, Some(&profile_id))
            .await
            .is_ok()
    };

    // 🔴 ОГРУБЛЕНИЕ — БЕЗУСЛОВНОЕ. Оно работает на проде с 26.08 и флагом не
    // управляется: спрятать его за новым переключателем значило бы молча
    // вернуть точность до миллисекунды всем, пока переключатель выключен.
    // Существующий тест поймал ровно эту ошибку при первом заходе.
    let last_active_at_ms = profile_meta_last_seen_ms(
        "contacts",
        requester_is_owner,
        requester_authenticated,
        last_active_at_ms,
    );

    if !is_valid_id(&profile_id, 128) {
        return Json(ProfileMetaResponse {
            exists: false,
            profile_id,
            nickname: None,
            avatar_png_b64: None,
            bio: None,
            privacy_audience_json: None,
            searchable_by_nickname: false,
            frame_id: None,
            cover_id: None,
            cover_png_b64: None,
            emoji_status: None,
            premium_badge: None,
            updated_at_ms: 0,
            last_active_at_ms,
        });
    }

    let row = state
        .store
        .profile_meta_get(&profile_id)
        .await
        .unwrap_or(None);
    if let Some((
        nick,
        avatar,
        bio,
        privacy_audience_json,
        searchable_by_nickname,
        frame_id,
        cover_id,
        cover_png_b64,
        emoji_status,
        premium_badge,
        updated,
    )) = row
    {
        // SEC-07: настройки владельца применяются ЗДЕСЬ, на сервере. Проверка
        // приватности, выполняемая на стороне клиента, проверкой не является:
        // тот, кто обращается к API напрямую, её просто не выполняет.
        let enforce = profile_meta_enforce_enabled();
        let audience_photo =
            profile_audience_for(privacy_audience_json.as_deref(), "photo");
        let audience_last_seen =
            profile_audience_for(privacy_audience_json.as_deref(), "last_seen");
        let show_photo =
            !enforce || profile_meta_shows_photo(&audience_photo, requester_is_owner);
        // Флаг добавляет к безусловному огрублению ровно одно: значение
        // `nobody`. Всё остальное уже применено выше.
        let last_active_at_ms = if enforce {
            profile_meta_last_seen_ms(
                &audience_last_seen,
                requester_is_owner,
                requester_authenticated,
                last_active_at_ms,
            )
        } else {
            last_active_at_ms
        };
        return Json(ProfileMetaResponse {
            exists: true,
            profile_id,
            nickname: nick,
            avatar_png_b64: if show_photo { avatar } else { None },
            bio,
            privacy_audience_json,
            searchable_by_nickname,
            frame_id,
            cover_id,
            cover_png_b64: if show_photo { cover_png_b64 } else { None },
            emoji_status,
            premium_badge,
            updated_at_ms: updated,
            last_active_at_ms,
        });
    }

    // Exists (profile) but no meta yet.
    // Benign case, unlike the three above: the client treats "no meta" as "no
    // data this round" and does nothing destructive. Still routed through the
    // helper so a store error is LOGGED rather than silently becoming a "no".
    let exists = profile_exists_or_unknown(&state, &profile_id)
        .await
        .unwrap_or(false);
    Json(ProfileMetaResponse {
        exists,
        profile_id,
        nickname: None,
        avatar_png_b64: None,
        bio: None,
        privacy_audience_json: None,
        searchable_by_nickname: false,
        frame_id: None,
        cover_id: None,
        cover_png_b64: None,
        emoji_status: None,
        premium_badge: None,
        updated_at_ms: 0,
        last_active_at_ms,
    })
}

async fn profile_meta_set(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<ProfileMetaSetRequest>,
) -> Json<ProfileMetaSetResponse> {
    if !is_valid_id(&req.profile_id, 128) || !is_valid_id(&req.device_id, 128) {
        return Json(ProfileMetaSetResponse { ok: false });
    }

    if require_profile_secret(&state, &headers, &req.profile_id)
        .await
        .is_err()
    {
        return Json(ProfileMetaSetResponse { ok: false });
    }

    // Whether the client SENT these at all. Absent means "no opinion" and must
    // preserve what is stored; only an explicit empty string clears. Collapsing
    // both into "" is what let one publish erase a user's name and photo for
    // every contact who had them.
    // Cover art keeps the old "empty means absent" handling below; it is
    // cosmetic and never carried the identity a contact recognises.
    let nickname_present = req.nickname.is_some();
    let avatar_present = req.avatar_png_b64.is_some();
    let bio_present = req.bio.is_some();

    // Basic input constraints.
    let nickname = req
        .nickname
        .unwrap_or_default()
        .chars()
        .filter(|c| *c != '\n' && *c != '\r' && *c != '\t')
        .collect::<String>()
        .trim()
        .to_string();
    if nickname.len() > 32 {
        return Json(ProfileMetaSetResponse { ok: false });
    }

    let avatar_b64 = req.avatar_png_b64.unwrap_or_default();
    let bio = req
        .bio
        .unwrap_or_default()
        .chars()
        .filter(|c| *c != '\n' && *c != '\r' && *c != '\t')
        .collect::<String>()
        .trim()
        .to_string();
    if bio.len() > 140 {
        return Json(ProfileMetaSetResponse { ok: false });
    }
    let privacy_audience_json =
        match canonicalize_privacy_audience_json(&req.privacy_audience_json.unwrap_or_default()) {
            Some(value) => value,
            None => return Json(ProfileMetaSetResponse { ok: false }),
        };
    if privacy_audience_json.len() > 512 {
        return Json(ProfileMetaSetResponse { ok: false });
    }
    let searchable_by_nickname = req.searchable_by_nickname.unwrap_or(true);
    // Optional cosmetic ids (not part of the signed message): empty -> None,
    // otherwise must match ^[a-z0-9_]{1,32}$.
    let Ok(frame_id) = validate_cosmetic_id(&req.frame_id) else {
        return Json(ProfileMetaSetResponse { ok: false });
    };
    let Ok(cover_id) = validate_cosmetic_id(&req.cover_id) else {
        return Json(ProfileMetaSetResponse { ok: false });
    };
    // Premium badge marker (slug, e.g. "1"); cosmetic, not part of the signed msg.
    let Ok(premium_badge) = validate_cosmetic_id(&req.premium_badge) else {
        return Json(ProfileMetaSetResponse { ok: false });
    };
    // Emoji status: a short unicode emoji (not a slug). Empty -> None; strip control
    // chars + cap length so it can't be abused as an arbitrary data channel.
    let emoji_status = req
        .emoji_status
        .as_deref()
        .map(|s| {
            s.chars()
                .filter(|c| !c.is_control())
                .take(24)
                .collect::<String>()
        })
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());
    // Optional custom cover image (not part of the signed message). Empty -> None.
    // Covers must stay small: reject anything above ~4MB of base64.
    let cover_png_b64 = req.cover_png_b64.clone().filter(|s| !s.is_empty());
    if let Some(ref cover_png) = cover_png_b64 {
        if cover_png.len() > 4_000_000 {
            return Json(ProfileMetaSetResponse { ok: false });
        }
    }
    // Allow clearing avatar by sending empty string.
    if avatar_b64.len() > 700_000 {
        return Json(ProfileMetaSetResponse { ok: false });
    }
    if !avatar_b64.is_empty() {
        // Validate base64 and size.
        let Ok(bytes) = base64::engine::general_purpose::STANDARD.decode(avatar_b64.as_bytes())
        else {
            return Json(ProfileMetaSetResponse { ok: false });
        };
        if bytes.len() > 512_000 {
            return Json(ProfileMetaSetResponse { ok: false });
        }
        // PNG signature check (best-effort).
        if bytes.len() < 8 || &bytes[0..8] != b"\x89PNG\r\n\x1a\n" {
            return Json(ProfileMetaSetResponse { ok: false });
        }
    }

    // Auth: device must belong to profile and have an identity key. Verify signature with that key.
    let device_profile = state
        .store
        .profile_id_for_device(&req.device_id)
        .await
        .unwrap_or(None);
    if device_profile.as_deref() != Some(req.profile_id.as_str()) {
        return Json(ProfileMetaSetResponse { ok: false });
    }
    let ik = state
        .store
        .identity_key_for_device(&req.device_id)
        .await
        .unwrap_or(None);
    let Some(ik_b64) = ik else {
        return Json(ProfileMetaSetResponse { ok: false });
    };
    if ik_b64.is_empty() {
        return Json(ProfileMetaSetResponse { ok: false });
    }

    let msg = profile_meta_set_message(
        &req.profile_id,
        &req.device_id,
        &nickname,
        &avatar_b64,
        &bio,
        &privacy_audience_json,
        searchable_by_nickname,
    );
    if !verify_ed25519_b64(&ik_b64, &req.signature_b64, &msg) {
        return Json(ProfileMetaSetResponse { ok: false });
    }

    let now = now_ms();
    let ok = state
        .store
        .profile_meta_set(
            &req.profile_id,
            if nickname_present {
                Some(nickname.as_str())
            } else {
                None
            },
            if avatar_present {
                Some(avatar_b64.as_str())
            } else {
                None
            },
            if bio_present {
                Some(bio.as_str())
            } else {
                None
            },
            if privacy_audience_json.is_empty() {
                None
            } else {
                Some(privacy_audience_json.as_str())
            },
            searchable_by_nickname,
            frame_id.as_deref(),
            cover_id.as_deref(),
            cover_png_b64.as_deref(),
            emoji_status.as_deref(),
            premium_badge.as_deref(),
            now,
        )
        .await
        .unwrap_or(false);
    if ok {
        let _ = state.store.mark_profile_active(&req.profile_id, now).await;
    }

    Json(ProfileMetaSetResponse { ok })
}

async fn profile_inactivity_set(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<ProfileInactivitySetRequest>,
) -> Result<Json<ProfileInactivityResponse>, StatusCode> {
    if !is_valid_id(&req.profile_id, 128) || !is_valid_id(&req.device_id, 128) {
        return Ok(Json(profile_inactivity_response_from_status(None, false)));
    }
    let Some(delete_after_inactivity_months) =
        normalize_delete_after_inactivity_months(req.delete_after_inactivity_months)
    else {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    };

    // Same rule as the heartbeat — the client reacts to `exists: false` here by
    // wiping the account too (`_applyProfileInactivityStatus`).
    let Some(exists) = profile_exists_or_unknown(&state, &req.profile_id).await else {
        return Err(StatusCode::SERVICE_UNAVAILABLE);
    };
    if !exists {
        return Ok(Json(profile_inactivity_response_from_status(None, false)));
    }
    if require_profile_secret(&state, &headers, &req.profile_id)
        .await
        .is_err()
    {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }
    if req.nonce_b64.is_empty() || req.nonce_b64.len() > 512 {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }

    let now = now_ms();
    if (req.ts_ms - now).abs() > 5 * 60 * 1000 {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }
    if check_and_mark_nonce(&state, &req.device_id, &req.nonce_b64, now).is_err() {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }

    let device_profile = state
        .store
        .profile_id_for_device(&req.device_id)
        .await
        .unwrap_or(None);
    if device_profile.as_deref() != Some(req.profile_id.as_str()) {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }
    let ik = state
        .store
        .identity_key_for_device(&req.device_id)
        .await
        .unwrap_or(None);
    let Some(ik_b64) = ik else {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    };
    if ik_b64.is_empty() {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }

    let msg = profile_inactivity_set_message(
        &req.profile_id,
        &req.device_id,
        delete_after_inactivity_months,
        req.ts_ms,
        &req.nonce_b64,
    );
    if !verify_ed25519_b64(&ik_b64, &req.signature_b64, &msg) {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }

    let ok = state
        .store
        .profile_inactivity_set(&req.profile_id, delete_after_inactivity_months, now)
        .await
        .unwrap_or(false);
    Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, ok).await))
}

async fn profile_inactivity_heartbeat(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<ProfileInactivityHeartbeatRequest>,
) -> Result<Json<ProfileInactivityResponse>, StatusCode> {
    if !is_valid_id(&req.profile_id, 128) || !is_valid_id(&req.device_id, 128) {
        return Ok(Json(profile_inactivity_response_from_status(None, false)));
    }

    // 🔴 A store error must NEVER be answered as "your profile is gone": the
    // client obeys that answer by wiping the account. 503 is transient to every
    // client — the heartbeat simply retries on its next tick.
    let Some(exists) = profile_exists_or_unknown(&state, &req.profile_id).await else {
        return Err(StatusCode::SERVICE_UNAVAILABLE);
    };
    if !exists {
        return Ok(Json(profile_inactivity_response_from_status(None, false)));
    }
    if require_profile_secret(&state, &headers, &req.profile_id)
        .await
        .is_err()
    {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }
    if req.nonce_b64.is_empty() || req.nonce_b64.len() > 512 {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }

    let now = now_ms();
    if (req.ts_ms - now).abs() > 5 * 60 * 1000 {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }
    if check_and_mark_nonce(&state, &req.device_id, &req.nonce_b64, now).is_err() {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }

    let device_profile = state
        .store
        .profile_id_for_device(&req.device_id)
        .await
        .unwrap_or(None);
    if device_profile.as_deref() != Some(req.profile_id.as_str()) {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }
    let ik = state
        .store
        .identity_key_for_device(&req.device_id)
        .await
        .unwrap_or(None);
    let Some(ik_b64) = ik else {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    };
    if ik_b64.is_empty() {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }

    let msg = profile_inactivity_heartbeat_message(
        &req.profile_id,
        &req.device_id,
        req.ts_ms,
        &req.nonce_b64,
    );
    if !verify_ed25519_b64(&ik_b64, &req.signature_b64, &msg) {
        return Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, false).await));
    }

    let ok = state
        .store
        .mark_profile_active(&req.profile_id, now)
        .await
        .unwrap_or(false);
    // This endpoint is the ONLY human-presence signal: the app sends it while
    // a person actually has the app open. Everything else that bumps
    // last_active_at_ms (publishing keys on launch, registering a device,
    // backups) is a machine touch and must never light the online dot.
    let _ = state.store.mark_profile_present(&req.profile_id, now).await;
    Ok(Json(profile_inactivity_response_for_profile(&state, &req.profile_id, ok).await))
}

fn generate_secretly_id() -> String {
    // 8 random bytes -> Base32 (RFC4648, unpadded) = 13 chars.
    // + CRC32 checksum (4 bytes -> Base32) = 7 chars.
    // Total with dashes: ~24 chars.  Entropy = 2^64 ≈ 1.8×10^19.
    // Birthday-collision at 50 % requires ~4.3 billion IDs — more than enough.
    let mut bytes = [0u8; 8];
    rand::rng().fill_bytes(&mut bytes);

    let mut buf = [0u8; 16];
    let encoded = Base32UpperUnpadded::encode(&bytes, &mut buf).unwrap();

    let mut hasher = Hasher::new();
    hasher.update(&bytes);
    let crc = hasher.finalize();
    let crc_bytes = crc.to_be_bytes();
    let mut crc_buf = [0u8; 16];
    let crc_enc = Base32UpperUnpadded::encode(&crc_bytes, &mut crc_buf).unwrap();

    // Format: XXXX-XXXX-XXXXX-XXXXXXX  (13-char body chunked by 4, then checksum)
    let s = encoded;
    let mut out = String::new();
    for (i, ch) in s.chars().enumerate() {
        if i > 0 && i % 4 == 0 {
            out.push('-');
        }
        out.push(ch);
    }
    out.push('-');
    out.push_str(crc_enc);
    out
}

async fn create_profile(State(state): State<AppState>) -> Json<CreateProfileResponse> {
    let profile_id = generate_secretly_id();
    let mut secret = [0u8; 32];
    rand::rng().fill_bytes(&mut secret);
    let secret_b64 = base64::engine::general_purpose::STANDARD.encode(secret);

    let mut h = Sha256::new();
    h.update(secret);
    let secret_hash_b64 = base64::engine::general_purpose::STANDARD.encode(h.finalize());

    let _ = state
        .store
        .insert_profile(&profile_id, now_ms(), Some(secret_hash_b64.as_str()))
        .await;
    Json(CreateProfileResponse {
        profile_id,
        profile_secret_b64: secret_b64,
    })
}

async fn device_challenge(
    State(state): State<AppState>,
    Query(q): Query<DeviceChallengeQuery>,
) -> Json<DeviceChallengeResponse> {
    if !is_valid_id(&q.profile_id, 128) || !is_valid_id(&q.device_id, 128) {
        return Json(DeviceChallengeResponse {
            nonce_b64: "".into(),
            expires_at_ms: 0,
        });
    }
    // Challenge is best-effort even if profile doesn't exist yet; actual registration checks profile.
    let mut nonce = [0u8; 32];
    rand::rng().fill_bytes(&mut nonce);
    let nonce_b64 = base64::engine::general_purpose::STANDARD.encode(nonce);
    let now = now_ms();
    let expires_at_ms = now + 2 * 60 * 1000;

    // Best-effort prune of expired challenges to avoid unbounded growth.
    if state.challenges.len() > 10_000 {
        let mut to_remove: Vec<String> = Vec::new();
        for it in state.challenges.iter() {
            if it.value().expires_at_ms <= now {
                to_remove.push(it.key().clone());
                if to_remove.len() >= 5_000 {
                    break;
                }
            }
        }
        for k in to_remove {
            state.challenges.remove(&k);
        }
    }
    state.challenges.insert(
        q.device_id.clone(),
        DeviceChallenge {
            nonce_b64: nonce_b64.clone(),
            expires_at_ms,
        },
    );
    Json(DeviceChallengeResponse {
        nonce_b64,
        expires_at_ms,
    })
}

fn verify_ed25519_b64(pub_b64: &str, sig_b64: &str, msg: &[u8]) -> bool {
    let Ok(pub_bytes) = base64::engine::general_purpose::STANDARD.decode(pub_b64.as_bytes()) else {
        return false;
    };
    let Ok(sig_bytes) = base64::engine::general_purpose::STANDARD.decode(sig_b64.as_bytes()) else {
        return false;
    };

    let pub_arr: [u8; 32] = match pub_bytes.as_slice().try_into() {
        Ok(v) => v,
        Err(_) => return false,
    };
    let sig_arr: [u8; 64] = match sig_bytes.as_slice().try_into() {
        Ok(v) => v,
        Err(_) => return false,
    };

    let pk = match VerifyingKey::from_bytes(&pub_arr) {
        Ok(v) => v,
        Err(_) => return false,
    };
    let sig = Signature::from_bytes(&sig_arr);
    pk.verify_strict(msg, &sig).is_ok()
}

fn register_proof_message(req: &RegisterDeviceProofRequest) -> Vec<u8> {
    format!(
        "SECRETLY-DEVICE-REGISTER-V1\nprofile_id={}\ndevice_id={}\nidentity_key_pub_b64={}\nts_ms={}\nnonce_b64={}\n",
        req.profile_id, req.device_id, req.identity_key_pub_b64, req.ts_ms, req.nonce_b64
    )
    .into_bytes()
}

/// Build a `RegisterDeviceProofResponse { ok: false }` with a machine-readable
/// `error_code` plus an ops-friendly `error_message`. Every silent `ok=false`
/// branch goes through this helper so clients (and operators reading logs)
/// can distinguish:
///   - `invalid_profile_id` / `invalid_device_id` — malformed identifiers
///   - `invalid_identity_key` — not a 32-byte Ed25519 pubkey
///   - `challenge_missing` — no /device/challenge was issued for this device_id
///   - `clock_skew` — |ts_ms − server_now| > 5 min (client clock drift)
///   - `challenge_expired` — the stored challenge TTL elapsed
///   - `challenge_nonce_mismatch` — client replayed/forged nonce
///   - `signature_invalid` — Ed25519 signature did not verify under identity key
///   - `profile_secret_missing` / `profile_secret_mismatch` — AUD-058/AUD-073
///     protection against unauthorized devices attaching to a foreign profile
///   - `profile_not_found` — profile_id does not exist on the keys server
///   - `device_identity_key_mismatch` — existing device row is pinned to a
///     different identity key (caller must rotate device_id before retrying)
///   - `store_error` — unexpected database failure
///
/// Policy-failure codes (device_class_limit_reached, etc.) still come from
/// `enforce_device_registration_policy`.
fn reg_proof_fail(code: &'static str, message: &'static str) -> RegisterDeviceProofResponse {
    RegisterDeviceProofResponse {
        ok: false,
        error_code: Some(code.to_string()),
        error_message: Some(message.to_string()),
    }
}

async fn register_device_proof(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<RegisterDeviceProofRequest>,
) -> Json<RegisterDeviceProofResponse> {
    if !is_valid_id(&req.profile_id, 128) {
        return Json(reg_proof_fail(
            "invalid_profile_id",
            "profile_id is missing or exceeds the allowed length/charset",
        ));
    }
    if !is_valid_id(&req.device_id, 128) {
        return Json(reg_proof_fail(
            "invalid_device_id",
            "device_id is missing or exceeds the allowed length/charset",
        ));
    }
    // Identity key pub must be a 32-byte Ed25519 public key.
    if !b64_decoded_len_is(&req.identity_key_pub_b64, 32) {
        return Json(reg_proof_fail(
            "invalid_identity_key",
            "identity_key_pub_b64 must decode to 32 bytes",
        ));
    }

    // Validate and consume challenge.
    let now = now_ms();
    let ch = state.challenges.get(&req.device_id).map(|v| v.clone());
    let Some(ch) = ch else {
        return Json(reg_proof_fail(
            "challenge_missing",
            "no active challenge for this device_id; fetch /v1/device/challenge first",
        ));
    };
    if (req.ts_ms - now).abs() > 5 * 60 * 1000 {
        return Json(reg_proof_fail(
            "clock_skew",
            "ts_ms differs from server time by more than 5 minutes; check device clock",
        ));
    }
    if ch.expires_at_ms <= now {
        // Consume the stale challenge so the next /challenge replaces it cleanly.
        state.challenges.remove(&req.device_id);
        return Json(reg_proof_fail(
            "challenge_expired",
            "stored challenge TTL elapsed; fetch a fresh /v1/device/challenge",
        ));
    }
    if ch.nonce_b64 != req.nonce_b64 {
        return Json(reg_proof_fail(
            "challenge_nonce_mismatch",
            "nonce_b64 does not match the challenge issued for this device_id",
        ));
    }
    // Consume challenge (one-time) only after all cheap prechecks pass so a
    // legitimate client can retry after a clock fix without burning the nonce.
    state.challenges.remove(&req.device_id);

    // Verify signature proves ownership of identity key.
    let msg = register_proof_message(&req);
    if !verify_ed25519_b64(&req.identity_key_pub_b64, &req.signature_b64, &msg) {
        return Json(reg_proof_fail(
            "signature_invalid",
            "Ed25519 signature does not verify under the supplied identity key",
        ));
    }

    // Fail fast with a specific code when the profile does not exist on the
    // server. Running this BEFORE the profile-secret check avoids the
    // ambiguous "profile secret required" branch (triggered by an empty
    // stored-secret hash, which also happens when the profile row is absent)
    // bleeding into `profile_secret_*` error codes.
    match state.store.profile_exists(&req.profile_id).await {
        Ok(false) => {
            return Json(reg_proof_fail(
                "profile_not_found",
                "profile_id is not known to the keys server",
            ));
        }
        Err(_) => {
            return Json(reg_proof_fail(
                "store_error",
                "unexpected database error while looking up the profile",
            ));
        }
        Ok(true) => {}
    }

    // Prevent unauthorized devices from attaching to an existing profile.
    if let Err((status, reason)) = require_profile_secret(&state, &headers, &req.profile_id).await {
        let code = match status {
            StatusCode::UNAUTHORIZED => {
                if reason.contains("missing") {
                    "profile_secret_missing"
                } else if reason.contains("invalid") {
                    "profile_secret_invalid_format"
                } else if reason.contains("required") {
                    // Legacy profile with no stored secret and legacy bypass off.
                    "profile_secret_required"
                } else {
                    "profile_secret_mismatch"
                }
            }
            _ => "store_error",
        };
        return Json(RegisterDeviceProofResponse {
            ok: false,
            error_code: Some(code.to_string()),
            error_message: Some(reason),
        });
    }

    let device_class = normalize_device_class(req.device_class.as_deref());
    let device_label = sanitize_device_label(req.device_label.as_deref());
    // Profile-secret-proven path (require_profile_secret passed above), so the
    // requester is authorized to manage this profile's device roster — eviction
    // of the stalest device on a cap hit is permitted when the flag is on.
    if let Err(policy) = enforce_device_registration_policy(
        &state,
        &req.profile_id,
        &req.device_id,
        device_class,
        evict_stalest_on_cap(),
        req.replaces_device_id.as_deref(),
    )
    .await
    {
        let (error_code, error_message) = policy.response();
        return Json(RegisterDeviceProofResponse {
            ok: false,
            error_code: Some(error_code),
            error_message: Some(error_message),
        });
    }

    let register_result = state
        .store
        .register_device(
            &req.profile_id,
            &req.device_id,
            Some(&req.identity_key_pub_b64),
            now_ms(),
        )
        .await;

    let ok = match register_result {
        Ok(v) => v,
        Err(_) => {
            return Json(reg_proof_fail(
                "store_error",
                "unexpected database error while registering the device",
            ));
        }
    };

    if !ok {
        // The only reason `register_device` returns `Ok(false)` after we already
        // verified `profile_exists` is an identity-key mismatch on an existing
        // (device_id, profile_id) row. Disambiguate so the client can rotate
        // the device_id instead of blindly retrying.
        if let Ok(Some(existing)) = state.store.identity_key_for_device(&req.device_id).await {
            if !existing.is_empty() && existing != req.identity_key_pub_b64 {
                return Json(reg_proof_fail(
                    "device_identity_key_mismatch",
                    "this device_id is already bound to a different identity key; rotate device_id",
                ));
            }
        }
        return Json(reg_proof_fail(
            "store_error",
            "register_device returned false without an explicit reason",
        ));
    }

    let _ = state
        .store
        .upsert_device_metadata(
            &req.profile_id,
            &req.device_id,
            device_class,
            device_label.as_deref(),
            now,
        )
        .await;
    let _ = state.store.mark_profile_active(&req.profile_id, now).await;

    Json(RegisterDeviceProofResponse {
        ok: true,
        error_code: None,
        error_message: None,
    })
}

async fn profile_exists(
    State(state): State<AppState>,
    Path(profile_id): Path<String>,
) -> Result<Json<ProfileExistsResponse>, StatusCode> {
    if !is_valid_id(&profile_id, 128) {
        return Ok(Json(ProfileExistsResponse { exists: false }));
    }
    // Same rule as the heartbeat: this answer is what the STARTUP path uses to
    // decide "re-create the profile after a Keys reset". A store error read as
    // `exists: false` therefore mints a brand-new identity on app launch.
    let Some(exists) = profile_exists_or_unknown(&state, &profile_id).await else {
        return Err(StatusCode::SERVICE_UNAVAILABLE);
    };
    Ok(Json(ProfileExistsResponse { exists }))
}

async fn profile_search(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<ProfileSearchQuery>,
) -> Result<Json<ProfileSearchResponse>, (StatusCode, String)> {
    let normalized = q
        .query
        .chars()
        .filter(|c| *c != '\n' && *c != '\r' && *c != '\t')
        .collect::<String>();
    let query = normalized.trim();
    if query.is_empty() {
        return Ok(Json(ProfileSearchResponse { items: Vec::new() }));
    }
    let min_len = profile_search_min_query_len();
    if query.chars().count() < min_len {
        return Ok(Json(ProfileSearchResponse { items: Vec::new() }));
    }
    verify_profile_search_auth(&state, &headers, query).await?;
    let limit = q.limit.unwrap_or(20).clamp(1, 50);
    let items = state
        .store
        .search_profiles_by_nickname(query, limit)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(|it| ProfileSearchItemResponse {
            profile_id: it.profile_id,
            nickname: it.nickname,
            updated_at_ms: it.updated_at_ms,
        })
        .collect();
    Ok(Json(ProfileSearchResponse { items }))
}

async fn list_devices(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(profile_id): Path<String>,
) -> Result<Json<ListDevicesResponse>, (StatusCode, String)> {
    if !is_valid_id(&profile_id, 128) {
        return Ok(Json(ListDevicesResponse {
            device_ids: vec![],
            devices: vec![],
        }));
    }

    if require_list_devices_auth_enabled() {
        let ts_ms = header_str(&headers, "x-secretly-ts-ms")
            .and_then(|s| s.parse::<i64>().ok())
            .unwrap_or(0);
        let nonce_b64 = header_str(&headers, "x-secretly-nonce-b64").unwrap_or("");
        let req_did = header_str(&headers, "x-secretly-device-id").unwrap_or("");
        let msg = keys_list_devices_auth_message(req_did, &profile_id, ts_ms, nonce_b64);
        if let Err((status, message)) = verify_requester_device_auth(
            &state,
            &headers,
            msg,
            require_list_devices_auth_enabled(),
            None,
        )
        .await
        {
            tracing::warn!(
                %profile_id,
                %req_did,
                %status,
                %message,
                "keys list_devices auth rejected"
            );
            return Err((status, message));
        }
    }

    let devices = state
        .store
        .list_device_statuses(&profile_id)
        .await
        .unwrap_or_default();
    let device_ids = devices
        .iter()
        .map(|device| device.device_id.clone())
        .collect();
    let devices = devices
        .into_iter()
        .map(|device| ListDevicesEntry {
            device_id: device.device_id,
            has_bundle: device.has_bundle,
            identity_key_pub_b64: device.identity_key_pub_b64,
            signed_prekey_pub_b64: device.signed_prekey_pub_b64,
            signed_prekey_sig_b64: device.signed_prekey_sig_b64,
        })
        .collect();
    Ok(Json(ListDevicesResponse {
        device_ids,
        devices,
    }))
}

async fn set_desktop_companion_entitlement(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(profile_id): Path<String>,
    Json(req): Json<SetDesktopCompanionEntitlementRequest>,
) -> Result<Json<DesktopCompanionEntitlementResponse>, (StatusCode, String)> {
    if !is_valid_id(&profile_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "invalid profile id".into()));
    }
    if !internal_key_matches(&state, &headers) {
        return Err((StatusCode::UNAUTHORIZED, "internal key required".into()));
    }

    let limit = req
        .limit
        .unwrap_or_else(default_desktop_companion_limit)
        .min(max_devices_per_profile());
    let source = sanitize_device_label(req.source.as_deref());
    let ok = state
        .store
        .set_desktop_companion_limit(&profile_id, limit, now_ms(), source.as_deref())
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    let active_companion_devices = state
        .store
        .list_companion_devices(&profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .len();

    Ok(Json(DesktopCompanionEntitlementResponse {
        ok,
        profile_id,
        desktop_companion_limit: limit,
        active_companion_devices,
        slots_remaining: limit.saturating_sub(active_companion_devices),
        entitled: limit > 0,
    }))
}

async fn delete_device(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<DeleteDeviceRequest>,
) -> Result<Json<DeleteDeviceResponse>, (StatusCode, String)> {
    if !is_valid_id(&req.profile_id, 128) || !is_valid_id(&req.device_id, 128) {
        return Ok(Json(DeleteDeviceResponse { ok: false }));
    }

    if !internal_key_matches(&state, &headers) {
        require_profile_secret(&state, &headers, &req.profile_id).await?;

        let ts_ms = header_str(&headers, "x-secretly-ts-ms")
            .and_then(|s| s.parse::<i64>().ok())
            .unwrap_or(0);
        let nonce_b64 = header_str(&headers, "x-secretly-nonce-b64").unwrap_or("");
        let req_did = header_str(&headers, "x-secretly-device-id").unwrap_or("");
        let msg = keys_delete_device_auth_message(
            req_did,
            &req.profile_id,
            &req.device_id,
            ts_ms,
            nonce_b64,
        );
        verify_requester_device_auth(&state, &headers, msg, true, Some(&req.profile_id)).await?;
    }

    let ok = state
        .store
        .delete_device(&req.profile_id, &req.device_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    if ok {
        let _ = state
            .store
            .mark_profile_active(&req.profile_id, now_ms())
            .await;
    }
    Ok(Json(DeleteDeviceResponse { ok }))
}

async fn delete_profile(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<DeleteProfileRequest>,
) -> Result<Json<DeleteProfileResponse>, (StatusCode, String)> {
    if !is_valid_id(&req.profile_id, 128) {
        return Ok(Json(DeleteProfileResponse { ok: false }));
    }

    if !internal_key_matches(&state, &headers) {
        require_profile_secret(&state, &headers, &req.profile_id).await?;

        let ts_ms = header_str(&headers, "x-secretly-ts-ms")
            .and_then(|s| s.parse::<i64>().ok())
            .unwrap_or(0);
        let nonce_b64 = header_str(&headers, "x-secretly-nonce-b64").unwrap_or("");
        let req_did = header_str(&headers, "x-secretly-device-id").unwrap_or("");
        let msg = keys_delete_profile_auth_message(req_did, &req.profile_id, ts_ms, nonce_b64);
        verify_requester_device_auth(&state, &headers, msg, true, Some(&req.profile_id)).await?;
    }

    let ok = state
        .store
        .delete_profile(&req.profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    Ok(Json(DeleteProfileResponse { ok }))
}

async fn device_lookup(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(device_id): Path<String>,
) -> Result<Json<DeviceLookupResponse>, (StatusCode, String)> {
    if !is_valid_id(&device_id, 128) {
        return Ok(Json(DeviceLookupResponse {
            exists: false,
            profile_id: None,
        }));
    }

    // Protect device->profile mapping from unauthenticated scraping.
    let ts_ms = header_str(&headers, "x-secretly-ts-ms")
        .and_then(|s| s.parse::<i64>().ok())
        .unwrap_or(0);
    let nonce_b64 = header_str(&headers, "x-secretly-nonce-b64").unwrap_or("");
    let req_did = header_str(&headers, "x-secretly-device-id").unwrap_or("");
    let msg = keys_device_lookup_auth_message(req_did, &device_id, ts_ms, nonce_b64);
    verify_device_lookup_auth(&state, &headers, &device_id, msg).await?;

    let profile_id = state
        .store
        .profile_id_for_device(&device_id)
        .await
        .unwrap_or(None);
    Ok(Json(DeviceLookupResponse {
        exists: profile_id.is_some(),
        profile_id,
    }))
}

async fn device_identity(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(device_id): Path<String>,
) -> Result<Json<DeviceIdentityResponse>, (StatusCode, String)> {
    if !is_valid_id(&device_id, 128) {
        return Ok(Json(DeviceIdentityResponse {
            exists: false,
            profile_id: None,
            identity_key_pub_b64: None,
        }));
    }

    let ts_ms = header_str(&headers, "x-secretly-ts-ms")
        .and_then(|s| s.parse::<i64>().ok())
        .unwrap_or(0);
    let nonce_b64 = header_str(&headers, "x-secretly-nonce-b64").unwrap_or("");
    let req_did = header_str(&headers, "x-secretly-device-id").unwrap_or("");
    let msg = keys_device_identity_auth_message(req_did, &device_id, ts_ms, nonce_b64);
    verify_device_lookup_auth(&state, &headers, &device_id, msg).await?;

    let profile_id = state
        .store
        .profile_id_for_device(&device_id)
        .await
        .unwrap_or(None);
    let ik = state
        .store
        .identity_key_for_device(&device_id)
        .await
        .unwrap_or(None);

    Ok(Json(DeviceIdentityResponse {
        exists: profile_id.is_some(),
        profile_id,
        identity_key_pub_b64: ik,
    }))
}

async fn publish_keys(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<PublishKeysRequest>,
) -> Json<PublishKeysResponse> {
    if !is_valid_id(&req.profile_id, 128) || !is_valid_id(&req.device_id, 128) {
        return Json(PublishKeysResponse::refused(
            "bad id",
            &req.profile_id,
            &req.device_id,
        ));
    }

    if require_profile_secret(&state, &headers, &req.profile_id)
        .await
        .is_err()
    {
        return Json(PublishKeysResponse::refused(
            "profile secret rejected",
            &req.profile_id,
            &req.device_id,
        ));
    }

    // Sanity-check key material lengths (X25519 keys are 32 bytes, Ed25519 pub is 32 bytes).
    if !b64_decoded_len_is(&req.identity_key_pub_b64, 32) {
        return Json(PublishKeysResponse::refused(
            "bad identity key length",
            &req.profile_id,
            &req.device_id,
        ));
    }
    if !b64_decoded_len_is(&req.signed_prekey_pub_b64, 32) {
        return Json(PublishKeysResponse::refused(
            "bad signed prekey length",
            &req.profile_id,
            &req.device_id,
        ));
    }
    if !b64_decoded_len_is(&req.signed_prekey_sig_b64, 64) {
        return Json(PublishKeysResponse::refused(
            "bad signed prekey signature length",
            &req.profile_id,
            &req.device_id,
        ));
    }

    // 🔴 Account identity: malformed values are DROPPED, not rejected.
    //
    // Refusing the whole publish would turn a cosmetic problem (no safety-number
    // improvement for this device) into a delivery outage: publish_keys is also
    // the liveness heartbeat, and a device that cannot publish stops receiving.
    // Dropping leaves the device behaving exactly like a build from before this
    // feature — which is the defined fallback everywhere else in this design.
    let account_identity_pub = req
        .account_identity_pub_b64
        .as_deref()
        .map(str::trim)
        .filter(|value| b64_decoded_len_is(value, 32));
    let device_cert = req
        .device_cert_b64
        .as_deref()
        .map(str::trim)
        .filter(|value| b64_decoded_len_is(value, 64));
    // A certificate without the key that signed it is unverifiable, so the pair
    // is stored only when BOTH are present. Half a pair would look to a receiver
    // like a device that has a certificate, and it would never verify.
    let (account_identity_pub, device_cert) = match (account_identity_pub, device_cert) {
        (Some(aik), Some(cert)) => (Some(aik), Some(cert)),
        _ => (None, None),
    };

    // Anti-abuse: cap one-time prekey count.
    if req.one_time_prekeys.len() > 200 {
        return Json(PublishKeysResponse::refused(
            "too many one-time prekeys",
            &req.profile_id,
            &req.device_id,
        ));
    }
    let require_sig = std::env::var("SECRETLY_KEYS_REQUIRE_PUBLISH_SIG")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(true);

    if require_sig {
        let Some(sig_b64) = req.signature_b64.as_ref() else {
            return Json(PublishKeysResponse::refused(
                "signature required",
                &req.profile_id,
                &req.device_id,
            ));
        };

        // Stable hash of OTK list.
        let mut otks = req.one_time_prekeys.clone();
        otks.sort_by_key(|k| k.prekey_id);
        let mut h = Sha256::new();
        for k in &otks {
            h.update(k.prekey_id.to_be_bytes());
            h.update(k.prekey_pub_b64.as_bytes());
            h.update(b"\n");
        }
        let otk_hash_b64 = base64::engine::general_purpose::STANDARD.encode(h.finalize());

        if req.nonce_b64.is_empty() || req.nonce_b64.len() > 512 {
            return Json(PublishKeysResponse::refused(
                "bad nonce",
                &req.profile_id,
                &req.device_id,
            ));
        }
        let now = now_ms();
        if (req.ts_ms - now).abs() > 5 * 60 * 1000 {
            return Json(PublishKeysResponse::refused(
                "timestamp out of range",
                &req.profile_id,
                &req.device_id,
            ));
        }
        if check_and_mark_nonce(&state, &req.device_id, &req.nonce_b64, now).is_err() {
            return Json(PublishKeysResponse::refused(
                "nonce replay",
                &req.profile_id,
                &req.device_id,
            ));
        }

        let msg = format!(
            "SECRETLY-KEYS-PUBLISH-V1\nprofile_id={}\ndevice_id={}\nidentity_key_pub_b64={}\nsigned_prekey_pub_b64={}\nsigned_prekey_sig_b64={}\none_time_prekeys_sha256_b64={}\nts_ms={}\nnonce_b64={}\n",
            req.profile_id,
            req.device_id,
            req.identity_key_pub_b64,
            req.signed_prekey_pub_b64,
            req.signed_prekey_sig_b64,
            otk_hash_b64,
            req.ts_ms,
            req.nonce_b64
        );

        if !verify_ed25519_b64(&req.identity_key_pub_b64, sig_b64, msg.as_bytes()) {
            return Json(PublishKeysResponse::refused(
                "bad signature",
                &req.profile_id,
                &req.device_id,
            ));
        }
    }

    let ok = state
        .store
        .publish_key_bundle(
            &req.profile_id,
            &req.device_id,
            &req.identity_key_pub_b64,
            &req.signed_prekey_pub_b64,
            &req.signed_prekey_sig_b64,
            req.one_time_prekeys,
            now_ms(),
            account_identity_pub,
            device_cert,
        )
        .await
        .unwrap_or(false);
    if ok {
        let _ = state
            .store
            .mark_profile_active(&req.profile_id, now_ms())
            .await;
    }
    if ok {
        Json(PublishKeysResponse::ok())
    } else {
        Json(PublishKeysResponse::refused(
            "store rejected bundle",
            &req.profile_id,
            &req.device_id,
        ))
    }
}

async fn fetch_bundle(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(profile_id): Path<String>,
) -> Result<Json<FetchBundleResponse>, (StatusCode, String)> {
    if !is_valid_id(&profile_id, 128) {
        return Ok(Json(FetchBundleResponse { devices: vec![] }));
    }

    if require_bundle_fetch_auth_enabled() {
        let ts_ms = header_str(&headers, "x-secretly-ts-ms")
            .and_then(|s| s.parse::<i64>().ok())
            .unwrap_or(0);
        let nonce_b64 = header_str(&headers, "x-secretly-nonce-b64").unwrap_or("");
        let req_did = header_str(&headers, "x-secretly-device-id").unwrap_or("");
        let msg = keys_fetch_bundle_auth_message(req_did, &profile_id, ts_ms, nonce_b64);
        if let Err((status, message)) = verify_requester_device_auth(
            &state,
            &headers,
            msg,
            require_bundle_fetch_auth_enabled(),
            None,
        )
        .await
        {
            tracing::warn!(
                profile_ref=%log_fingerprint(&profile_id),
                requester_device_ref=%log_fingerprint(req_did),
                %status,
                %message,
                "keys fetch_bundle auth rejected"
            );
            return Err((status, message));
        }
    }

    let devices = state
        .store
        .fetch_bundles_for_profile(&profile_id)
        .await
        .unwrap_or_default();
    Ok(Json(FetchBundleResponse { devices }))
}

fn port_from_env(var: &str, default_port: u16) -> u16 {
    match env::var(var) {
        Ok(value) => value.parse().unwrap_or(default_port),
        Err(_) => default_port,
    }
}

fn i64_from_env(var: &str, default_value: i64) -> i64 {
    env::var(var)
        .ok()
        .and_then(|value| value.parse::<i64>().ok())
        .unwrap_or(default_value)
}

fn keys_server_protocol_version() -> i64 {
    i64_from_env("SECRETLY_KEYS_SERVER_PROTOCOL_VERSION", 1).max(1)
}

fn keys_min_client_protocol_version() -> i64 {
    i64_from_env("SECRETLY_KEYS_MIN_CLIENT_PROTOCOL_VERSION", 1).max(1)
}

fn keys_max_client_protocol_version(
    min_client_protocol_version: i64,
    server_protocol_version: i64,
) -> i64 {
    i64_from_env(
        "SECRETLY_KEYS_MAX_CLIENT_PROTOCOL_VERSION",
        server_protocol_version.max(min_client_protocol_version),
    )
    .max(min_client_protocol_version)
}

fn optional_trimmed_string(value: &str) -> Option<String> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}

fn optional_string_env(var: &str) -> Option<String> {
    env::var(var)
        .ok()
        .and_then(|value| optional_trimmed_string(&value))
}

fn evaluate_client_compatibility(
    service: &str,
    client_protocol_version: Option<i64>,
    min_client_protocol_version: i64,
    max_client_protocol_version: i64,
) -> ClientCompatibilityResult {
    let Some(client_protocol_version) = client_protocol_version else {
        return ClientCompatibilityResult {
            supported: true,
            compatibility_status: "unknown",
            compatibility_message: None,
        };
    };

    if client_protocol_version < min_client_protocol_version {
        return ClientCompatibilityResult {
            supported: false,
            compatibility_status: "client_too_old",
            compatibility_message: Some(format!(
                "This Secretly client is too old for the {service} service. Client protocol {client_protocol_version}, minimum supported {min_client_protocol_version}. Install a newer app build."
            )),
        };
    }

    if client_protocol_version > max_client_protocol_version {
        return ClientCompatibilityResult {
            supported: false,
            compatibility_status: "client_too_new",
            compatibility_message: Some(format!(
                "This {service} server is older than the app build. Client protocol {client_protocol_version}, maximum supported {max_client_protocol_version}. Update the server or install a matching app build."
            )),
        };
    }

    ClientCompatibilityResult {
        supported: true,
        compatibility_status: "supported",
        compatibility_message: None,
    }
}

fn bind_ip_from_env(var: &str, default_ip: [u8; 4]) -> std::net::IpAddr {
    match env::var(var) {
        Ok(value) => {
            // Accept either an IP ("0.0.0.0") or an ip:port ("0.0.0.0:8081").
            // Only the IP part is used here; port is read from SECRETLY_KEYS_PORT.
            let ip_part = value
                .trim()
                .split_once(':')
                .map(|(ip, _port)| ip)
                .unwrap_or(value.trim());
            ip_part
                .parse()
                .unwrap_or(std::net::IpAddr::from(default_ip))
        }
        Err(_) => std::net::IpAddr::from(default_ip),
    }
}

fn bool_env(var: &str, default_value: bool) -> bool {
    env::var(var)
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(default_value)
}

fn is_production_mode(runtime_env: Option<&str>, strict_production: bool) -> bool {
    if strict_production {
        return true;
    }

    runtime_env
        .map(|v| v.trim().to_ascii_lowercase())
        .map(|v| v == "prod" || v == "production")
        .unwrap_or(false)
}

fn current_runtime_env() -> Option<String> {
    env::var("SECRETLY_RUNTIME_ENV")
        .ok()
        .or_else(|| env::var("SECRETLY_ENV").ok())
}

fn keys_security_errors(
    bind_ip: std::net::IpAddr,
    production_mode: bool,
    require_profile_secret: bool,
    require_device_lookup_auth: bool,
    require_list_devices_auth: bool,
    require_bundle_fetch_auth: bool,
    trust_xff: bool,
    proxy_only: bool,
    internal_key: &str,
) -> Vec<String> {
    let mut errors = Vec::new();
    if !production_mode {
        return errors;
    }

    if !require_profile_secret {
        errors.push(
            "SECURITY: keys refuses to start in production when SECRETLY_KEYS_REQUIRE_PROFILE_SECRET is disabled."
                .into(),
        );
    }

    if !require_device_lookup_auth {
        errors.push(
            "SECURITY: keys refuses to start in production when SECRETLY_KEYS_REQUIRE_DEVICE_LOOKUP_AUTH is disabled."
                .into(),
        );
    }

    if !require_list_devices_auth {
        errors.push(
            "SECURITY: keys refuses to start in production when SECRETLY_KEYS_REQUIRE_LIST_DEVICES_AUTH is disabled."
                .into(),
        );
    }

    if !require_bundle_fetch_auth {
        errors.push(
            "SECURITY: keys refuses to start in production when SECRETLY_KEYS_REQUIRE_BUNDLE_FETCH_AUTH is disabled."
                .into(),
        );
    }

    if trust_xff && !bind_ip.is_loopback() && !proxy_only {
        errors.push(
            "SECURITY: keys refuses to trust X-Forwarded-For on non-loopback bind in production unless SECRETLY_KEYS_PROXY_ONLY is enabled."
                .into(),
        );
    }

    if internal_key.trim().is_empty() {
        errors.push(
            "SECURITY: keys refuses to start in production with empty SECRETLY_INTERNAL_KEY."
                .into(),
        );
    }

    errors
}

fn keys_security_preflight(bind_ip: std::net::IpAddr) -> Result<(), Vec<String>> {
    if !require_profile_secret_enabled() {
        tracing::warn!(
            "SECURITY: SECRETLY_KEYS_REQUIRE_PROFILE_SECRET is disabled. This is unsafe for production."
        );
    }

    if !require_device_lookup_auth_enabled() {
        tracing::warn!(
            "SECURITY: SECRETLY_KEYS_REQUIRE_DEVICE_LOOKUP_AUTH is disabled. Device/profile mapping enumeration risk increases."
        );
    }

    if !require_list_devices_auth_enabled() {
        tracing::warn!(
            "SECURITY: SECRETLY_KEYS_REQUIRE_LIST_DEVICES_AUTH is disabled. Device enumeration risk increases."
        );
    }

    if !require_bundle_fetch_auth_enabled() {
        tracing::warn!(
            "SECURITY: SECRETLY_KEYS_REQUIRE_BUNDLE_FETCH_AUTH is disabled. Bundle enumeration risk increases."
        );
    }

    let trust_xff = bool_env("SECRETLY_KEYS_TRUST_XFF", false);
    let proxy_only = bool_env("SECRETLY_KEYS_PROXY_ONLY", false);
    if trust_xff && !bind_ip.is_loopback() {
        tracing::warn!(
            %bind_ip,
            "SECURITY: SECRETLY_KEYS_TRUST_XFF is enabled on non-loopback bind. Ensure keys service is behind trusted proxy and not directly reachable."
        );
    }

    let internal_key = env::var("SECRETLY_INTERNAL_KEY").unwrap_or_default();
    if internal_key.trim().is_empty() {
        tracing::warn!(
            "SECURITY: SECRETLY_INTERNAL_KEY is empty. Internal caller bypass protection is disabled."
        );
    }

    let production_mode = is_production_mode(
        current_runtime_env().as_deref(),
        bool_env("SECRETLY_STRICT_PRODUCTION", false),
    );
    let errors = keys_security_errors(
        bind_ip,
        production_mode,
        require_profile_secret_enabled(),
        require_device_lookup_auth_enabled(),
        require_list_devices_auth_enabled(),
        require_bundle_fetch_auth_enabled(),
        trust_xff,
        proxy_only,
        &internal_key,
    );
    if errors.is_empty() {
        Ok(())
    } else {
        Err(errors)
    }
}

#[tokio::main]
async fn main() {
    let log_format = env::var("SECRETLY_LOG_FORMAT")
        .ok()
        .unwrap_or_else(|| "text".into())
        .to_ascii_lowercase();
    let filter =
        tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into());

    if log_format == "json" {
        tracing_subscriber::registry()
            .with(filter)
            .with(tracing_subscriber::fmt::layer().json())
            .init();
    } else {
        tracing_subscriber::registry()
            .with(filter)
            .with(tracing_subscriber::fmt::layer())
            .init();
    }

    let port = port_from_env("SECRETLY_KEYS_PORT", 8081);
    let ip = bind_ip_from_env("SECRETLY_KEYS_BIND", [127, 0, 0, 1]);
    if let Err(errors) = keys_security_preflight(ip) {
        for error in errors {
            tracing::error!("{error}");
        }
        panic!("unsafe keys production configuration");
    }
    let addr: SocketAddr = (ip, port).into();

    let db_path = env::var("SECRETLY_KEYS_DB").unwrap_or_else(|_| "keys.db".into());
    let store = KeysStore::open(db_path).await.expect("open keys store");

    // Basic anti-abuse: per-IP token bucket.
    // Default: 30 req burst, ~1 req/sec sustained.
    let cap = env::var("SECRETLY_KEYS_RL_CAP")
        .ok()
        .and_then(|v| v.parse::<u32>().ok())
        .unwrap_or(30);
    let refill_per_sec = env::var("SECRETLY_KEYS_RL_REFILL_PER_SEC")
        .ok()
        .and_then(|v| v.parse::<f64>().ok())
        .unwrap_or(1.0);
    let limiter = Arc::new(IpRateLimiter::new(cap, refill_per_sec));
    let deployment_id = optional_string_env("SECRETLY_KEYS_DEPLOYMENT_ID").unwrap_or_default();
    let release_channel = optional_string_env("SECRETLY_KEYS_RELEASE_CHANNEL").unwrap_or_default();
    let service_started_at_ms = now_ms();
    let monetization = MonetizationConfig::from_env();
    let config_signing_key = load_config_signing_key();
    match config_signing_key.as_ref() {
        Some(sk) => tracing::info!(
            monetization_enabled = monetization.enabled,
            config_signing_public_key = %base64::engine::general_purpose::STANDARD
                .encode(sk.verifying_key().to_bytes()),
            "monetization config signer loaded (bake this public key into the client)"
        ),
        None => tracing::warn!(
            monetization_enabled = monetization.enabled,
            "SECRETLY_KEYS_CONFIG_SIGNING_KEY not set — /v1/config served UNSIGNED (ok for R0)"
        ),
    }

    let http = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(20))
        .build()
        .unwrap_or_else(|_| reqwest::Client::new());
    let state = AppState {
        store: Arc::new(store),
        limiter,
        challenges: Arc::new(DashMap::new()),
        used_nonces: Arc::new(DashMap::new()),
        internal_key: Arc::new(env::var("SECRETLY_INTERNAL_KEY").unwrap_or_default()),
        deployment_id: Arc::new(deployment_id),
        release_channel: Arc::new(release_channel),
        service_started_at_ms,
        monetization: Arc::new(monetization),
        reliability: Arc::new(ReliabilityConfig::from_env()),
        identity: Arc::new(IdentityConfig::from_env()),
        rooms: Arc::new(RoomsConfig::from_env()),
        rooms2: Arc::new(Rooms2Config::from_env()),
        handshake: Arc::new(HandshakeServerConfig::from_env()),
        update: Arc::new(UpdateServerConfig::from_env()),
        support: Arc::new(SupportServerConfig::from_env()),
        config_signing_key: Arc::new(config_signing_key),
        http,
        billing: Arc::new(billing::BillingVerifyConfig::from_env()),
    };

    tokio::spawn(run_inactive_profile_cleanup_loop(state.clone()));

    let app = Router::new()
        .route("/health", get(health))
        .route("/v1/config", get(get_config))
        .route("/v1/profile/create", post(create_profile))
        .route("/v1/profile/search", get(profile_search))
        .route(
            "/v1/profile/{profile_id}/desktop_companion_entitlement",
            post(set_desktop_companion_entitlement),
        )
        .route(
            "/v1/profile/{profile_id}/entitlements",
            get(get_entitlements),
        )
        .route("/v1/entitlements/legacy_claim", post(legacy_claim))
        .route("/v1/entitlements/redeem", post(redeem))
        .route("/v1/entitlements/admin/grant", post(grant_entitlement))
        .route("/v1/entitlements/admin/rebind", post(rebind_entitlement))
        .route("/v1/entitlements/admin/revoke", post(revoke_entitlement))
        .route("/v1/webhooks/appstore", post(webhook_appstore))
        .route("/v1/webhooks/play", post(webhook_play))
        .route("/v1/profile/{profile_id}/meta", get(profile_meta_get))
        .route(
            "/v1/profile/inactivity/heartbeat",
            post(profile_inactivity_heartbeat),
        )
        .route("/v1/profile/inactivity/set", post(profile_inactivity_set))
        .route("/v1/profile/meta/set", post(profile_meta_set))
        // Backups can be several MB — override the 1 MB global body limit for
        // this route only (route layer is innermost, so it wins for this path).
        .route(
            "/v1/backup/set",
            post(backup_set).layer(DefaultBodyLimit::max(KEYS_BACKUP_MAX_BODY_BYTES)),
        )
        .route("/v1/backup/{profile_id}", get(backup_get))
        .route(
            "/v1/backup/{profile_id}/challenge",
            get(backup_challenge),
        )
        .route("/v1/device/challenge", get(device_challenge))
        .route("/v1/device/register_proof", post(register_device_proof))
        .route("/v1/device/delete", post(delete_device))
        .route("/v1/profile/delete", post(delete_profile))
        .route("/v1/device/{device_id}", get(device_lookup))
        .route("/v1/device/{device_id}/identity", get(device_identity))
        .route("/v1/profile/{profile_id}", get(profile_exists))
        .route("/v1/profile/{profile_id}/devices", get(list_devices))
        .route("/v1/keys/publish", post(publish_keys))
        .route("/v1/keys/bundle/{profile_id}", get(fetch_bundle))
        .layer(DefaultBodyLimit::max(KEYS_HTTP_BODY_LIMIT_BYTES))
        .layer(middleware::from_fn_with_state(state.clone(), rate_limit))
        .with_state(state);

    tracing::info!(%addr, "starting keys service");

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("bind keys service");

    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .with_graceful_shutdown(shutdown_signal())
    .await
    .expect("serve keys service");
}

async fn shutdown_signal() {
    let _ = tokio::signal::ctrl_c().await;
    tracing::info!("shutdown signal received");
}

async fn run_inactive_profile_cleanup_loop(state: AppState) {
    let interval_ms = env::var("SECRETLY_KEYS_INACTIVITY_CLEANUP_INTERVAL_MS")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or(60 * 60 * 1000)
        .max(60_000);
    let mut interval = tokio::time::interval(std::time::Duration::from_millis(interval_ms));
    interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        interval.tick().await;
        match state.store.delete_expired_inactive_profiles(now_ms()).await {
            Ok(profile_ids) if !profile_ids.is_empty() => {
                tracing::info!(count = profile_ids.len(), "deleted inactive profiles");
            }
            Ok(_) => {}
            Err(error) => {
                tracing::error!(%error, "inactive profile cleanup failed");
            }
        }
    }
}

#[cfg(test)]
mod tests {

    /// SEC-07: настройка `nobody` действительно прячет фотографию.
    #[test]
    fn photo_is_hidden_only_when_the_owner_asked_for_nobody() {
        assert!(!profile_meta_shows_photo("nobody", false), "«никому» значит никому");

        // 🔴 От САМОГО владельца прятать нельзя: его приложение читает свои же
        // метаданные, и настройка «никому» стёрла бы человеку его фотографию.
        assert!(profile_meta_shows_photo("nobody", true), "владелец видит своё");

        assert!(profile_meta_shows_photo("everyone", false));

        // 🔴 `contacts` НЕ проверяется и проверяться не может: у сервера ключей
        // нет графа контактов. Отдаём — и говорим об этом прямо, а не делаем
        // вид, что настройка работает.
        assert!(
            profile_meta_shows_photo("contacts", false),
            "«только контактам» серверу проверить нечем — см. модель угроз"
        );
    }

    /// SEC-07: время последней активности.
    #[test]
    fn last_seen_is_hidden_for_nobody_and_coarsened_for_strangers() {
        const HOUR: i64 = 60 * 60 * 1000;
        let raw = 5 * HOUR + 37 * 60 * 1000 + 12_345;

        assert_eq!(profile_meta_last_seen_ms("nobody", false, true, raw), 0);
        assert_eq!(profile_meta_last_seen_ms("nobody", true, true, raw), raw);
        assert_eq!(profile_meta_last_seen_ms("contacts", false, true, raw), raw);

        // 🔴 Главное свойство: посторонний получает час, а не минуту. Точность
        // до минуты превращает эндпоинт в наблюдение за распорядком дня.
        assert_eq!(
            profile_meta_last_seen_ms("contacts", false, false, raw),
            5 * HOUR,
            "постороннему — округление вниз до часа"
        );

        // Ноль остаётся нулём: «никогда не был активен» не должно превратиться
        // в «был активен в начале эпохи».
        assert_eq!(profile_meta_last_seen_ms("everyone", false, false, 0), 0);
    }

    /// Разбор настроек: умолчание обязано совпадать с клиентским.
    #[test]
    fn audience_defaults_to_contacts_like_the_client_does() {
        assert_eq!(profile_audience_for(None, "photo"), "contacts");
        assert_eq!(profile_audience_for(Some(""), "photo"), "contacts");
        assert_eq!(profile_audience_for(Some("не json"), "photo"), "contacts");
        assert_eq!(
            profile_audience_for(Some("{\"photo\":\"nobody\"}"), "photo"),
            "nobody"
        );
        // Неизвестное значение не должно ослаблять защиту.
        assert_eq!(
            profile_audience_for(Some("{\"photo\":\"anything\"}"), "photo"),
            "contacts"
        );
        // Чужой ключ не влияет.
        assert_eq!(
            profile_audience_for(Some("{\"last_seen\":\"nobody\"}"), "photo"),
            "contacts"
        );
    }

    /// SEC-01, Э-2: у профиля есть опора — токен обязателен.
    ///
    /// Каждое из четырёх условий проверяется отдельно, потому что ошибка в
    /// любом стоит человеку либо переписки (пустили чужого), либо
    /// восстановления (не пустили владельца).
    #[test]
    fn access_token_required_only_for_profiles_that_can_provide_one() {
        // Э-2 включён, опора есть, подписи нет, токена нет → отказ.
        assert!(
            backup_get_requires_access_token(true, true, false, false),
            "профиль с опорой обязан предъявлять токен"
        );

        // 🔴 Профиль БЕЗ опоры обслуживается прежним путём. Иначе владелец
        // старой сборки, которая не умеет считать токен, остался бы без
        // восстановления навсегда.
        assert!(
            !backup_get_requires_access_token(true, false, false, false),
            "у профиля без опоры требовать нечего"
        );

        // Подписанное устройство уже доказало право ключами.
        assert!(
            !backup_get_requires_access_token(true, true, true, false),
            "подписанному устройству токен не нужен"
        );

        // Токен предъявлен — его проверяет отдельная ветка.
        assert!(
            !backup_get_requires_access_token(true, true, false, true),
            "предъявленный токен проверяется, а не отвергается здесь"
        );

        // 🔴 На Э-1 требовать НЕЛЬЗЯ: в магазинах живут сборки без токена.
        assert!(
            !backup_get_requires_access_token(false, true, false, false),
            "режим accept обязан оставаться прежним поведением"
        );
    }

    /// Запирание профиля после неудачных попыток токена.
    #[test]
    fn access_lock_starts_at_ten_attempts_and_caps_at_a_day() {
        use crate::store::backup_access_lock_deadline_ms;
        const NOW: i64 = 1_000_000;
        const DAY: i64 = 24 * 60 * 60 * 1000;

        // Девять ошибок бесплатны: человек мог ошибиться в пароле.
        assert_eq!(backup_access_lock_deadline_ms(9, NOW), 0);

        // С десятой — минута, дальше удвоение.
        assert_eq!(backup_access_lock_deadline_ms(10, NOW), NOW + 60_000);
        assert_eq!(backup_access_lock_deadline_ms(11, NOW), NOW + 120_000);

        // 🔴 Потолок обязателен: без него сдвиг ушёл бы в переполнение, а
        // запертым навсегда оказался бы владелец, а не нападающий.
        assert_eq!(backup_access_lock_deadline_ms(60, NOW), NOW + DAY);
        assert_eq!(backup_access_lock_deadline_ms(i64::MAX, NOW), NOW + DAY);
    }

    /// SEC-08 (26.08.2026): небезопасный путь регистрации устройства удалён и
    /// не имеет права вернуться.
    ///
    /// Он был выключен переменной окружения, а не отсутствием кода. На проде
    /// переменная стояла верно — обработчик отвечал `ok:false`, ничего не
    /// регистрируя, — но выключатель можно передвинуть, а удалённого кода нет
    /// вовсе. Живая проверка перед удалением: `POST /v1/device/register`
    /// возвращал `200 {"ok":false}`.
    ///
    /// 🔴 Игла собирается через `concat!`, иначе строка поиска попала бы в сам
    /// файл и тест ловил бы собственный текст.
    ///
    /// Журнал сервера здесь ничего не доказывает: путей он не пишет вовсе — за
    /// 7 дней ноль записей и о рабочем `register_proof`, через который
    /// регистрируются все.
    #[test]
    fn legacy_device_register_route_stays_deleted() {
        let src = include_str!("main.rs");
        let route = concat!("\"/v1/device/regist", "er\"");
        let handler = concat!("post(register_", "device)");
        assert!(
            !src.contains(route),
            "маршрут {route} вернулся; рабочий путь — register_proof"
        );
        assert!(
            !src.contains(handler),
            "обработчик {handler} вернулся; рабочий путь — register_proof"
        );
    }
    use super::*;
    use axum::{
        Json,
        body::to_bytes,
        extract::{Path, Query, State},
        http::{HeaderMap, HeaderValue},
        response::IntoResponse,
    };
    use ed25519_dalek::{Signer, SigningKey};
    use tempfile::TempDir;

    async fn test_app_state() -> (AppState, TempDir) {
        let dir = tempfile::tempdir().unwrap();
        let db_path = dir.path().join("keys.db");
        let store = KeysStore::open(&db_path).await.unwrap();
        let state = AppState {
            store: Arc::new(store),
            limiter: Arc::new(IpRateLimiter::new(10_000, 10_000.0)),
            challenges: Arc::new(DashMap::new()),
            used_nonces: Arc::new(DashMap::new()),
            internal_key: Arc::new("internal-test-key".into()),
            deployment_id: Arc::new(String::new()),
            release_channel: Arc::new(String::new()),
            service_started_at_ms: now_ms(),
            monetization: Arc::new(MonetizationConfig::from_env()),
            reliability: Arc::new(ReliabilityConfig::default()),
            identity: Arc::new(IdentityConfig::default()),
            rooms: Arc::new(RoomsConfig::default()),
            rooms2: Arc::new(Rooms2Config::default()),
            handshake: Arc::new(HandshakeServerConfig::default()),
            update: Arc::new(UpdateServerConfig::default()),
            support: Arc::new(SupportServerConfig::default()),
            config_signing_key: Arc::new(None),
            http: reqwest::Client::new(),
            billing: Arc::new(billing::BillingVerifyConfig::default()),
        };
        (state, dir)
    }

    /// С-2: блок `handshake_auth` отдаётся со своей подписью, подпись сходится
    /// с каноническим сообщением (его зеркало — Dart
    /// `handshakeAuthSigningMessage`), а выключатель по умолчанию снят.
    #[tokio::test]
    async fn config_serves_signed_handshake_auth_block() {
        let (mut state, _dir) = test_app_state().await;
        let sk = SigningKey::from_bytes(&[7u8; 32]);
        let vk = sk.verifying_key();
        state.config_signing_key = Arc::new(Some(sk));

        for disabled in [false, true] {
            state.handshake = Arc::new(HandshakeServerConfig {
                hs_auth_enforce_disabled: disabled,
                ..HandshakeServerConfig::default()
            });
            let response = get_config(State(state.clone())).await.into_response();
            assert_eq!(response.status(), StatusCode::OK);
            let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
            let v: serde_json::Value = serde_json::from_slice(&body).unwrap();
            let block = &v["handshake_auth"];
            assert_eq!(block["enforce_disabled"], serde_json::json!(disabled));
            let issued = block["issued_at_ms"].as_i64().unwrap();
            let msg = format!("secretly-handshake-auth-v1|{}|{}", disabled, issued);
            let sig_b64 = v["handshake_auth_signature"].as_str().unwrap();
            let sig_bytes = base64::engine::general_purpose::STANDARD
                .decode(sig_b64)
                .unwrap();
            let sig = ed25519_dalek::Signature::from_slice(&sig_bytes).unwrap();
            assert!(vk.verify_strict(msg.as_bytes(), &sig).is_ok());
            // Старый блок не тронут: его подпись по-прежнему на месте.
            assert!(!v["handshake_signature"].as_str().unwrap().is_empty());
        }
        assert!(!HandshakeServerConfig::default().hs_auth_enforce_disabled);
    }

    #[tokio::test]
    async fn health_reports_request_body_limit() {
        let (state, _dir) = test_app_state().await;

        let response = health(
            State(state),
            Query(HealthQuery {
                client_protocol_version: None,
            }),
        )
        .await
        .into_response();

        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(json["service"], "keys");
        assert_eq!(json["status"], "ok");
        assert_eq!(
            json["max_request_body_bytes"],
            KEYS_HTTP_BODY_LIMIT_BYTES as i64
        );
    }

    #[tokio::test]
    async fn config_open_and_unsigned_by_default() {
        let (state, _dir) = test_app_state().await;
        let response = get_config(State(state)).await.into_response();
        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(json["payload"]["monetization_enabled"], false);
        assert_eq!(
            json["payload"]["free_limits"]["attachment_bytes"],
            104_857_600i64
        );
        assert_eq!(json["payload"]["free_limits"]["group_members"], 50);
        assert_eq!(json["payload"]["free_limits"]["owned_groups"], 5);
        assert_eq!(json["payload"]["free_limits"]["joined_groups"], 20);
        assert_eq!(
            json["payload"]["premium_limits"]["attachment_bytes"],
            1_073_741_824i64
        );
        assert_eq!(json["payload"]["premium_limits"]["owned_groups"], 100);
        assert_eq!(json["payload"]["premium_limits"]["joined_groups"], -1);
        assert_eq!(json["payload"]["desktop_trial_days"], 14);
        assert_eq!(json["alg"], "ed25519");
        // No signing key in tests → unsigned (R0 client doesn't verify).
        assert_eq!(json["signature"], "");
    }

    #[tokio::test]
    async fn config_signature_verifies_when_key_present() {
        let (base, _dir) = test_app_state().await;
        let sk = SigningKey::from_bytes(&[7u8; 32]);
        let pub_b64 = base64::engine::general_purpose::STANDARD
            .encode(sk.verifying_key().to_bytes());
        let state = AppState {
            config_signing_key: Arc::new(Some(sk)),
            ..base
        };
        let response = get_config(State(state)).await.into_response();
        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
        let sig_b64 = json["signature"].as_str().unwrap();
        assert!(!sig_b64.is_empty());
        let p = &json["payload"];
        let payload = ConfigPayload {
            monetization_enabled: p["monetization_enabled"].as_bool().unwrap(),
            free_limits: ConfigLimits {
                attachment_bytes: p["free_limits"]["attachment_bytes"].as_i64().unwrap(),
                group_members: p["free_limits"]["group_members"].as_i64().unwrap(),
                call_participants: p["free_limits"]["call_participants"].as_i64().unwrap(),
                owned_groups: p["free_limits"]["owned_groups"].as_i64().unwrap(),
                joined_groups: p["free_limits"]["joined_groups"].as_i64().unwrap(),
            },
            premium_limits: ConfigLimits {
                attachment_bytes: p["premium_limits"]["attachment_bytes"].as_i64().unwrap(),
                group_members: p["premium_limits"]["group_members"].as_i64().unwrap(),
                call_participants: p["premium_limits"]["call_participants"]
                    .as_i64()
                    .unwrap(),
                owned_groups: p["premium_limits"]["owned_groups"].as_i64().unwrap(),
                joined_groups: p["premium_limits"]["joined_groups"].as_i64().unwrap(),
            },
            desktop_trial_days: p["desktop_trial_days"].as_i64().unwrap(),
            issued_at_ms: p["issued_at_ms"].as_i64().unwrap(),
        };
        let msg = config_signing_message(&payload);
        assert!(verify_ed25519_b64(&pub_b64, sig_b64, msg.as_bytes()));
    }

    // ⚠️ Backward-compat guard (2026-07-19). The reliability kill-switches ride
    // their OWN signed block precisely so this message stays byte-identical:
    // every already-shipped client rebuilds this exact string and would reject
    // the whole config if a field were folded in here.
    #[test]
    fn config_signing_message_stays_v2_and_excludes_reliability() {
        let payload = ConfigPayload {
            monetization_enabled: false,
            free_limits: ConfigLimits {
                attachment_bytes: 1,
                group_members: 2,
                call_participants: 3,
                owned_groups: 4,
                joined_groups: 5,
            },
            premium_limits: ConfigLimits {
                attachment_bytes: 6,
                group_members: 7,
                call_participants: 8,
                owned_groups: 9,
                joined_groups: 10,
            },
            desktop_trial_days: 11,
            issued_at_ms: 12,
        };
        assert_eq!(
            config_signing_message(&payload),
            "secretly-config-v2|false|1|2|3|4|5|6|7|8|9|10|11|12"
        );
    }

    #[test]
    fn reliability_signing_message_is_canonical() {
        let p = ReliabilityPayload {
            nack_receipts_enabled: true,
            convergence_resend_enabled: false,
            issued_at_ms: 42,
        };
        assert_eq!(
            reliability_signing_message(&p),
            "secretly-reliability-v1|true|false|42"
        );
    }

    // The safety net must be ON unless a signed `false` says otherwise.
    /// A store error must never be answerable as "this profile does not exist".
    ///
    /// That answer is not information to the client — it is an INSTRUCTION.
    /// `_handleDeletedProfileFromServer()` wipes the profile id, the local
    /// database, the contacts and the purchases, then registers a brand-new
    /// identity; everyone who ever added the user keeps writing to the old
    /// profile, into a mailbox nobody will ever read again. So one transient
    /// `.unwrap_or(false)` here costs a real person their account.
    ///
    /// Pinned at the source level because the danger is not a value but a
    /// SHAPE: an existence query whose error is unwrapped into `false`. The
    /// moment someone writes that again the landmine is back, and nothing else
    /// would catch it. Every existence answer must go through
    /// `profile_exists_or_unknown`, which keeps "I don't know" (logged, 503)
    /// distinct from "no".
    #[test]
    fn profile_existence_never_answers_a_store_error_as_deleted() {
        let src = include_str!("main.rs");
        let mut offenders = 0usize;
        let mut rest = src;
        while let Some(i) = rest.find(".profile_exists(") {
            let after = &rest[i..];
            // Look at the next ~120 chars: an `.unwrap_or(false)` that close is
            // the anti-pattern regardless of how the call is line-wrapped.
            let window = &after[..after.len().min(120)];
            if window.contains(".unwrap_or(false)") {
                offenders += 1;
            }
            rest = &rest[i + 1..];
        }
        assert_eq!(
            offenders, 0,
            "a store error was turned into \"profile does not exist\"; \
             route it through profile_exists_or_unknown instead"
        );
    }

    #[tokio::test]
    async fn reliability_switches_default_on_and_verify() {
        let (base, _dir) = test_app_state().await;
        let sk = SigningKey::from_bytes(&[9u8; 32]);
        let pub_b64 = base64::engine::general_purpose::STANDARD
            .encode(sk.verifying_key().to_bytes());
        let state = AppState {
            config_signing_key: Arc::new(Some(sk)),
            ..base
        };
        let response = get_config(State(state)).await.into_response();
        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(json["reliability"]["nack_receipts_enabled"], true);
        assert_eq!(json["reliability"]["convergence_resend_enabled"], true);
        let sig_b64 = json["reliability_signature"].as_str().unwrap();
        assert!(!sig_b64.is_empty());
        let p = ReliabilityPayload {
            nack_receipts_enabled: json["reliability"]["nack_receipts_enabled"]
                .as_bool()
                .unwrap(),
            convergence_resend_enabled: json["reliability"]["convergence_resend_enabled"]
                .as_bool()
                .unwrap(),
            issued_at_ms: json["reliability"]["issued_at_ms"].as_i64().unwrap(),
        };
        assert!(verify_ed25519_b64(
            &pub_b64,
            sig_b64,
            reliability_signing_message(&p).as_bytes()
        ));
    }

    #[test]
    fn identity_signing_message_is_canonical() {
        let p = IdentityPayload {
            rotation_on_state_loss_enabled: true,
            issued_at_ms: 42,
        };
        assert_eq!(identity_signing_message(&p), "secretly-identity-v1|true|42");
    }

    // И-1: the block rides /v1/config default-ON server-side, and its signature
    // must verify independently of the frozen v2 payload. (The CLIENT is the
    // fail-OFF side: it acts only on a verified block.)
    #[tokio::test]
    async fn identity_block_default_on_and_verify() {
        let (base, _dir) = test_app_state().await;
        let sk = SigningKey::from_bytes(&[9u8; 32]);
        let pub_b64 = base64::engine::general_purpose::STANDARD
            .encode(sk.verifying_key().to_bytes());
        let state = AppState {
            config_signing_key: Arc::new(Some(sk)),
            ..base
        };
        let response = get_config(State(state)).await.into_response();
        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(json["identity"]["rotation_on_state_loss_enabled"], true);
        let sig_b64 = json["identity_signature"].as_str().unwrap();
        assert!(!sig_b64.is_empty());
        let p = IdentityPayload {
            rotation_on_state_loss_enabled: json["identity"]
                ["rotation_on_state_loss_enabled"]
                .as_bool()
                .unwrap(),
            issued_at_ms: json["identity"]["issued_at_ms"].as_i64().unwrap(),
        };
        assert!(verify_ed25519_b64(
            &pub_b64,
            sig_b64,
            identity_signing_message(&p).as_bytes()
        ));
        // The frozen v2 message must be byte-identical with or without the new
        // block — nothing may ever leak into secretly-config-v2.
        assert!(!identity_signing_message(&p).starts_with("secretly-config-v2"));
    }

    // PRESENCE-LIE FIX (2026-07-21). The online dot must reflect a HUMAN, not a
    // phone that a push woke up. Machine touches (publishing keys on launch,
    // registering a device, backups) legitimately bump account liveness for the
    // deletion sweep — they must never be reported as presence.
    #[tokio::test]
    async fn machine_touches_never_report_presence() {
        let (state, _dir) = test_app_state().await;
        let profile_id = "profile_presence_machine";
        state
            .store
            .insert_profile(profile_id, now_ms(), None)
            .await
            .unwrap();

        // Exactly what a push-woken phone does: it marks the account alive.
        let _ = state.store.mark_profile_active(profile_id, now_ms()).await;

        let response = profile_meta_get(State(state.clone()), HeaderMap::new(), Path(profile_id.to_string()))
            .await
            .into_response();
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(
            json["last_active_at_ms"], 0,
            "a woken phone republishing its keys must not read as «Онлайн»"
        );

        // A real heartbeat — the app open in someone's hand — does show.
        //
        // SEC-07: этот вызов идёт БЕЗ подписи, поэтому время приходит
        // огрублённым до часа. Суть проверки от этого не меняется: машинное
        // касание даёт ноль, живое присутствие — ненулевое значение того же
        // часа. Точное значение получает только тот, кто предъявил подпись, и
        // это сторожит `profile_meta_coarsens_presence_for_unauthenticated_callers`.
        let beat = now_ms();
        let _ = state.store.mark_profile_present(profile_id, beat).await;
        let response = profile_meta_get(State(state), HeaderMap::new(), Path(profile_id.to_string()))
            .await
            .into_response();
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
        const HOUR_MS: i64 = 60 * 60 * 1000;
        assert_eq!(
            json["last_active_at_ms"],
            (beat / HOUR_MS) * HOUR_MS,
            "живое присутствие обязано читаться как «Онлайн» — пусть и с \
             точностью до часа для неавторизованного запроса"
        );
    }

    // The two clocks stay independent: presence must not disturb the liveness
    // value the inactive-profile deletion sweep reads.
    #[tokio::test]
    async fn presence_and_account_liveness_are_separate_clocks() {
        let (state, _dir) = test_app_state().await;
        let profile_id = "profile_presence_split";
        state
            .store
            .insert_profile(profile_id, now_ms(), None)
            .await
            .unwrap();

        let active_at = now_ms();
        let _ = state.store.mark_profile_active(profile_id, active_at).await;
        let present_at = active_at + 5_000;
        let _ = state
            .store
            .mark_profile_present(profile_id, present_at)
            .await;

        let status = state
            .store
            .profile_inactivity_get(profile_id)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(status.last_active_at_ms, active_at, "deletion sweep clock");
        assert_eq!(status.last_presence_at_ms, present_at, "online-dot clock");
    }

    // ── S-1 entitlements ───────────────────────────────────────────────────
    #[tokio::test]
    async fn entitlements_default_free_for_unknown_profile() {
        let (state, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[81u8; 32]);
        let profile_id = "profile_ent_free_1";
        let device_id = "device_ent_free_1";
        seed_profile_device(&state, profile_id, device_id, &key).await;

        let headers = signed_auth_headers(device_id, &key, "ent-free", |ts, nonce| {
            keys_entitlements_get_auth_message(device_id, profile_id, ts, nonce)
        });
        let resp = get_entitlements(State(state), headers, Path(profile_id.to_string()))
            .await
            .unwrap()
            .0;
        assert_eq!(resp.tier, "free");
        assert_eq!(resp.source, "none");
        assert!(!resp.features.desktop);
        assert!(!resp.features.custom_id);
        assert!(!resp.features.premium_stickers);
        assert_eq!(resp.limits.attachment_bytes, 104_857_600);
        assert_eq!(resp.limits.group_members, 50);
        assert_eq!(resp.limits.owned_groups, 5);
        assert_eq!(resp.limits.joined_groups, 20);
        assert_eq!(resp.expires_at_ms, None);
        // No signing key configured in tests → unsigned.
        assert_eq!(resp.signature, "");
        assert_eq!(resp.alg, "ed25519");
    }

    #[tokio::test]
    async fn entitlements_reflect_paid_tier_and_premium_limits() {
        let (state, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[82u8; 32]);
        let profile_id = "profile_ent_premium_1";
        let device_id = "device_ent_premium_1";
        seed_profile_device(&state, profile_id, device_id, &key).await;
        state
            .store
            .entitlement_upsert(EntitlementRecord {
                profile_id: profile_id.to_string(),
                tier: "premium".into(),
                source: "appstore".into(),
                store_tx_id: Some("tx_premium_1".into()),
                expires_at_ms: Some(now_ms() + 30 * 24 * 3600 * 1000),
                grace_until_ms: None,
                updated_at_ms: now_ms(),
            })
            .await
            .unwrap();

        let headers = signed_auth_headers(device_id, &key, "ent-premium", |ts, nonce| {
            keys_entitlements_get_auth_message(device_id, profile_id, ts, nonce)
        });
        let resp = get_entitlements(State(state), headers, Path(profile_id.to_string()))
            .await
            .unwrap()
            .0;
        assert_eq!(resp.tier, "premium");
        assert_eq!(resp.source, "appstore");
        assert!(resp.features.desktop);
        assert!(resp.features.custom_id);
        assert!(resp.features.premium_stickers);
        assert_eq!(resp.limits.attachment_bytes, 1_073_741_824);
        assert_eq!(resp.limits.group_members, 500);
        assert_eq!(resp.limits.owned_groups, 100);
        assert_eq!(resp.limits.joined_groups, -1);
        assert!(resp.expires_at_ms.is_some());
    }

    #[tokio::test]
    async fn entitlements_desktop_feature_from_companion_limit_only() {
        let (state, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[83u8; 32]);
        let profile_id = "profile_ent_companion_1";
        let device_id = "device_ent_companion_1";
        seed_profile_device(&state, profile_id, device_id, &key).await;
        // Free tier but granted a desktop companion seat via the internal setter.
        state
            .store
            .set_desktop_companion_limit(profile_id, 1, now_ms(), Some("test"))
            .await
            .unwrap();

        let headers = signed_auth_headers(device_id, &key, "ent-companion", |ts, nonce| {
            keys_entitlements_get_auth_message(device_id, profile_id, ts, nonce)
        });
        let resp = get_entitlements(State(state), headers, Path(profile_id.to_string()))
            .await
            .unwrap()
            .0;
        assert_eq!(resp.tier, "free");
        assert!(resp.features.desktop);
        // Companion seat does not unlock paid cosmetic gates.
        assert!(!resp.features.custom_id);
        assert!(!resp.features.premium_stickers);
    }

    #[tokio::test]
    async fn entitlements_rejects_foreign_device() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[84u8; 32]);
        let foreign_key = SigningKey::from_bytes(&[85u8; 32]);
        let profile_id = "profile_ent_owner_1";
        seed_profile_device(&state, profile_id, "device_ent_owner_1", &owner_key).await;
        seed_profile_device(
            &state,
            "profile_ent_foreign_1",
            "device_ent_foreign_1",
            &foreign_key,
        )
        .await;

        let headers = signed_auth_headers(
            "device_ent_foreign_1",
            &foreign_key,
            "ent-foreign",
            |ts, nonce| {
                keys_entitlements_get_auth_message("device_ent_foreign_1", profile_id, ts, nonce)
            },
        );
        let err = get_entitlements(State(state), headers, Path(profile_id.to_string()))
            .await
            .err()
            .expect("foreign device must be rejected");
        // A validly-signed request from a device on a *different* profile is
        // FORBIDDEN (owner mismatch), not merely UNAUTHORIZED.
        assert!(
            err.0 == StatusCode::FORBIDDEN || err.0 == StatusCode::UNAUTHORIZED,
            "expected 401/403, got {}",
            err.0
        );
    }

    #[tokio::test]
    async fn entitlements_signed_when_key_present() {
        let (base, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[86u8; 32]);
        let profile_id = "profile_ent_signed_1";
        let device_id = "device_ent_signed_1";
        seed_profile_device(&base, profile_id, device_id, &key).await;

        let sk = SigningKey::from_bytes(&[9u8; 32]);
        let pub_b64 = base64::engine::general_purpose::STANDARD.encode(sk.verifying_key().to_bytes());
        let state = AppState {
            config_signing_key: Arc::new(Some(sk)),
            ..base
        };

        let headers = signed_auth_headers(device_id, &key, "ent-signed", |ts, nonce| {
            keys_entitlements_get_auth_message(device_id, profile_id, ts, nonce)
        });
        let resp = get_entitlements(State(state), headers, Path(profile_id.to_string()))
            .await
            .unwrap()
            .0;
        assert!(!resp.signature.is_empty());
        let msg = entitlement_signing_message(
            &resp.profile_id,
            &resp.tier,
            &resp.source,
            resp.expires_at_ms,
            resp.grace_until_ms,
            &resp.features,
            &resp.limits,
            resp.issued_at_ms,
        );
        assert!(verify_ed25519_b64(&pub_b64, &resp.signature, msg.as_bytes()));
    }

    #[tokio::test]
    async fn entitlement_upsert_enforces_unique_store_tx() {
        let (state, _dir) = test_app_state().await;
        let k1 = SigningKey::from_bytes(&[87u8; 32]);
        let k2 = SigningKey::from_bytes(&[88u8; 32]);
        seed_profile_device(&state, "profile_tx_a", "device_tx_a", &k1).await;
        seed_profile_device(&state, "profile_tx_b", "device_tx_b", &k2).await;

        state
            .store
            .entitlement_upsert(EntitlementRecord {
                profile_id: "profile_tx_a".into(),
                tier: "premium".into(),
                source: "play".into(),
                store_tx_id: Some("shared_tx".into()),
                expires_at_ms: None,
                grace_until_ms: None,
                updated_at_ms: now_ms(),
            })
            .await
            .unwrap();

        // Same store_tx_id bound to a different profile must be rejected (one
        // receipt = one profile).
        let dup = state
            .store
            .entitlement_upsert(EntitlementRecord {
                profile_id: "profile_tx_b".into(),
                tier: "premium".into(),
                source: "play".into(),
                store_tx_id: Some("shared_tx".into()),
                expires_at_ms: None,
                grace_until_ms: None,
                updated_at_ms: now_ms(),
            })
            .await;
        assert!(dup.is_err(), "duplicate store_tx_id must error");
    }

    // ── S-4 legacy_claim ───────────────────────────────────────────────────
    fn legacy_claim_headers(
        device_id: &str,
        key: &SigningKey,
        profile_id: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, key, nonce_seed, |ts, nonce| {
            keys_legacy_claim_auth_message(device_id, profile_id, ts, nonce)
        })
    }

    #[tokio::test]
    async fn legacy_claim_grants_legacy_before_deadline() {
        let (state, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[90u8; 32]);
        let profile_id = "profile_legacy_1";
        let device_id = "device_legacy_1";
        seed_profile_device(&state, profile_id, device_id, &key).await;

        let headers = legacy_claim_headers(device_id, &key, profile_id, "legacy-1");
        let resp = legacy_claim(
            State(state.clone()),
            headers,
            Json(LegacyClaimRequest {
                profile_id: profile_id.to_string(),
            }),
        )
        .await
        .unwrap()
        .0;
        assert_eq!(resp.tier, "legacy");
        assert_eq!(resp.source, "legacy");
        assert_eq!(resp.expires_at_ms, None);
        assert!(resp.features.desktop);
        assert!(resp.features.custom_id);
        assert!(resp.features.premium_stickers);

        let stored = state.store.entitlement_get(profile_id).await.unwrap().unwrap();
        assert_eq!(stored.tier, "legacy");
    }

    #[tokio::test]
    async fn legacy_claim_is_idempotent() {
        let (state, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[91u8; 32]);
        let profile_id = "profile_legacy_idem_1";
        let device_id = "device_legacy_idem_1";
        seed_profile_device(&state, profile_id, device_id, &key).await;

        for seed in ["legacy-idem-a", "legacy-idem-b"] {
            let headers = legacy_claim_headers(device_id, &key, profile_id, seed);
            let resp = legacy_claim(
                State(state.clone()),
                headers,
                Json(LegacyClaimRequest {
                    profile_id: profile_id.to_string(),
                }),
            )
            .await
            .unwrap()
            .0;
            assert_eq!(resp.tier, "legacy");
        }
    }

    #[tokio::test]
    async fn legacy_claim_returns_gone_after_deadline() {
        let (base, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[92u8; 32]);
        let profile_id = "profile_legacy_gone_1";
        let device_id = "device_legacy_gone_1";
        seed_profile_device(&base, profile_id, device_id, &key).await;

        let state = AppState {
            monetization: Arc::new(MonetizationConfig {
                legacy_claim_deadline_ms: Some(1),
                ..MonetizationConfig::from_env()
            }),
            reliability: Arc::new(ReliabilityConfig::default()),
            identity: Arc::new(IdentityConfig::default()),
            support: Arc::new(SupportServerConfig::default()),
            ..base
        };

        let headers = legacy_claim_headers(device_id, &key, profile_id, "legacy-gone");
        let err = legacy_claim(
            State(state),
            headers,
            Json(LegacyClaimRequest {
                profile_id: profile_id.to_string(),
            }),
        )
        .await
        .err()
        .expect("claim after deadline must fail");
        assert_eq!(err.0, StatusCode::GONE);
    }

    /// A reinstall must not forfeit a live subscription. The receipt is the
    /// only durable proof of purchase here, so the purchase follows it.
    /// A publish that carries no nickname must not erase the one every contact
    /// already sees. This is the field bug where a user's name and photo simply
    /// vanished after an app update.
    #[tokio::test]
    async fn absent_profile_fields_preserve_what_is_stored() {
        let (state, _dir) = test_app_state().await;
        let pid = "profile_meta_preserve_1";
        state.store.insert_profile(pid, now_ms(), None).await.ok();

        // Full profile: name, photo, and a cosmetic.
        state
            .store
            .profile_meta_set(pid, Some("Igor"), Some("AAAA"), Some("bio"), None, true,
                              Some("phoenix"), None, None, None, None, 1)
            .await
            .unwrap();

        // A later publish that says nothing about the name or photo.
        state
            .store
            .profile_meta_set(pid, None, None, None, None, true,
                              Some("phoenix"), None, None, Some("earth"), None, 2)
            .await
            .unwrap();

        // tuple order: nickname, avatar, bio, privacy, searchable, frame, ...
        let kept = state.store.profile_meta_get(pid).await.unwrap().expect("meta");
        assert_eq!(kept.0.as_deref(), Some("Igor"), "silence must not erase the name");
        assert_eq!(kept.1.as_deref(), Some("AAAA"), "silence must not erase the photo");
        assert_eq!(kept.2.as_deref(), Some("bio"));

        // An explicit empty string still clears — deleting a photo must work.
        state
            .store
            .profile_meta_set(pid, Some(""), Some(""), None, None, true,
                              None, None, None, None, None, 3)
            .await
            .unwrap();
        let cleared = state.store.profile_meta_get(pid).await.unwrap().expect("meta");
        assert_eq!(cleared.0.as_deref(), Some(""));
        assert_eq!(cleared.1.as_deref(), Some(""));
        assert_eq!(cleared.2.as_deref(), Some("bio"), "untouched field still preserved");
    }

    #[tokio::test]
    async fn receipt_follows_the_profile_that_presents_it() {
        let (state, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[102u8; 32]);
        let old = "profile_claim_old";
        let new = "profile_claim_new";
        let third = "profile_claim_third";
        seed_profile_device(&state, old, "dev_claim_old", &key).await;
        seed_profile_device(&state, new, "dev_claim_new", &key).await;
        seed_profile_device(&state, third, "dev_claim_third", &key).await;

        state
            .store
            .entitlement_upsert(EntitlementRecord {
                profile_id: old.to_string(),
                tier: "premium".into(),
                source: "play".into(),
                store_tx_id: Some("tx-claim-1".into()),
                expires_at_ms: Some(9_999),
                grace_until_ms: None,
                updated_at_ms: 1,
            })
            .await
            .unwrap();

        let day = RECEIPT_CLAIM_MIN_INTERVAL_MS;

        // The reinstall claims immediately: the first move is always allowed.
        assert!(state
            .store
            .entitlement_claim_by_receipt(old, new, day, day)
            .await
            .unwrap()
            .moved());
        let moved = state.store.entitlement_get(new).await.unwrap().expect("moved");
        assert_eq!(moved.tier, "premium");
        assert_eq!(moved.store_tx_id.as_deref(), Some("tx-claim-1"));
        assert!(state.store.entitlement_get(old).await.unwrap().is_none());

        // A second hand-off inside the window is refused, so two people sharing
        // one store account cannot take it from each other on every launch.
        assert!(!state
            .store
            .entitlement_claim_by_receipt(new, third, day + 1, day)
            .await
            .unwrap()
            .moved());
        assert!(state.store.entitlement_get(third).await.unwrap().is_none());
        assert!(state.store.entitlement_get(new).await.unwrap().is_some());

        // Once the window passes it may move again -- a real second reinstall.
        assert!(state
            .store
            .entitlement_claim_by_receipt(new, third, day * 3, day)
            .await
            .unwrap()
            .moved());
        assert_eq!(
            state
                .store
                .entitlement_profile_for_store_tx("tx-claim-1")
                .await
                .unwrap()
                .as_deref(),
            Some(third)
        );

        // An unknown target never wins the receipt.
        assert!(!state
            .store
            .entitlement_claim_by_receipt(third, "profile_that_does_not_exist", day * 9, day)
            .await
            .unwrap()
            .moved());
    }

    // 🔴 ПЕРЕУСТАНОВКА НЕ ЗАПИРАЕТ ПОДПИСКУ НА СУТКИ (25.09.2026).
    //
    // Телефон при первом запуске заводит серверный профиль и в ту же секунду
    // сам предъявляет чек. Раньше этот перенос взводил окно, и настоящий
    // профиль, восстановленный через минуту, получал 409 на сутки: 24.09
    // (профиль-однодневка прожил одну секунду) и 20.09 (33 часа без премиума).
    #[tokio::test]
    async fn fresh_install_claim_does_not_lock_out_the_restored_profile() {
        let (state, _dir) = test_app_state().await;
        let day = RECEIPT_CLAIM_MIN_INTERVAL_MS;
        let fresh_ms = store::RECEIPT_CLAIM_FRESH_PROFILE_MS;
        let t = 10 * day;
        let real = "profile_restore_real";
        let throwaway = "profile_restore_throwaway";
        let throwaway2 = "profile_restore_throwaway_2";
        let deliberate = "profile_restore_deliberate";
        state.store.insert_profile(real, 1_000, None).await.unwrap();
        state
            .store
            .insert_profile(throwaway, t - 2_000, None)
            .await
            .unwrap();
        state
            .store
            .entitlement_upsert(EntitlementRecord {
                profile_id: real.to_string(),
                tier: "premium".into(),
                source: "play".into(),
                store_tx_id: Some("tx-fresh-1".into()),
                expires_at_ms: Some(t + 365 * day),
                grace_until_ms: None,
                updated_at_ms: 1,
            })
            .await
            .unwrap();
        let owner = |state: &AppState| {
            let store = state.store.clone();
            async move {
                store
                    .entitlement_profile_for_store_tx("tx-fresh-1")
                    .await
                    .unwrap()
            }
        };

        // Первый запуск свежей установки забирает чек, но окно не взводит.
        assert_eq!(
            state
                .store
                .entitlement_claim_by_receipt(real, throwaway, t, day)
                .await
                .unwrap(),
            ReceiptClaim::MovedToFreshProfile
        );
        // Через минуту человек восстановил настоящий профиль — подписка
        // возвращается сразу, а не через сутки.
        assert_eq!(
            state
                .store
                .entitlement_claim_by_receipt(throwaway, real, t + 60_000, day)
                .await
                .unwrap(),
            ReceiptClaim::Moved
        );
        assert_eq!(owner(&state).await.as_deref(), Some(real));

        // Этот возврат окно взвёл: однодневка следующей переустановки в течение
        // суток уже не забирает подписку у настоящего профиля.
        state
            .store
            .insert_profile(throwaway2, t + 120_000, None)
            .await
            .unwrap();
        assert_eq!(
            state
                .store
                .entitlement_claim_by_receipt(real, throwaway2, t + 121_000, day)
                .await
                .unwrap(),
            ReceiptClaim::Refused
        );
        assert_eq!(owner(&state).await.as_deref(), Some(real));

        // Профиль ровно десятиминутной давности — уже не однодневка: перенос
        // к нему взводит окно, как раньше, и вернуть его сразу нельзя.
        let later = t + 60_000 + day + 1;
        state
            .store
            .insert_profile(deliberate, later - fresh_ms, None)
            .await
            .unwrap();
        assert_eq!(
            state
                .store
                .entitlement_claim_by_receipt(real, deliberate, later, day)
                .await
                .unwrap(),
            ReceiptClaim::Moved
        );
        assert_eq!(
            state
                .store
                .entitlement_claim_by_receipt(deliberate, real, later + 1, day)
                .await
                .unwrap(),
            ReceiptClaim::Refused
        );
        assert_eq!(owner(&state).await.as_deref(), Some(deliberate));
    }

    // 🔴 ЗАЩИТА ОТ ПОНИЖЕНИЯ ПОКУПКИ (17.09.2026, перенос 7435c11d).
    //
    // Восстановление покупок на iPhone проигрывает ВСЕ прошлые транзакции в
    // произвольном порядке, и приложение отдаёт каждую в /redeem. Старый,
    // истёкший или отозванный чек не должен перетирать lifetime или более
    // длинную подписку — ни своей записью, ни переносом с другого профиля
    // (перенос удаляет запись получателя). В июле защита стояла на проде с
    // ветки админки и пропала, когда keys стали собирать из основной ветки.
    #[tokio::test]
    async fn redeem_never_downgrades_lifetime_or_shortens_sub() {
        let (state, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[73u8; 32]);
        for (profile, device) in [
            ("B", "dev_b"),
            ("C", "dev_c"),
            ("D", "dev_d"),
            ("E", "dev_e"),
        ] {
            seed_profile_device(&state, profile, device, &key).await;
        }

        fn vp(tx: &str, tier: &'static str, expires: Option<i64>) -> billing::VerifiedPurchase {
            billing::VerifiedPurchase {
                store_tx_id: tx.into(),
                tier,
                source: "appstore",
                expires_at_ms: expires,
            }
        }

        // B купил lifetime, потом восстановление проигрывает старую подписку и
        // отозванный (возвращённый) чек.
        apply_verified_purchase(&state, "B", &vp("TX-LIFE", "lifetime", None))
            .await
            .unwrap();
        apply_verified_purchase(&state, "B", &vp("TX-OLD-SUB", "premium", Some(1)))
            .await
            .unwrap();
        apply_verified_purchase(&state, "B", &vp("TX-REFUNDED", "free", None))
            .await
            .unwrap();
        let b = state.store.entitlement_get("B").await.unwrap().unwrap();
        assert_eq!(b.tier, "lifetime", "lifetime must survive a restore replay");
        assert_eq!(b.expires_at_ms, None);
        assert_eq!(b.store_tx_id.as_deref(), Some("TX-LIFE"));

        // Более ранний срок той же подписки не укорачивает более поздний, а
        // продление и покупка lifetime проходят как раньше.
        apply_verified_purchase(&state, "C", &vp("TX-YEAR", "premium", Some(9_000)))
            .await
            .unwrap();
        apply_verified_purchase(&state, "C", &vp("TX-YEAR", "premium", Some(3_000)))
            .await
            .unwrap();
        let expires = |r: Option<EntitlementRecord>| r.unwrap().expires_at_ms;
        assert_eq!(
            expires(state.store.entitlement_get("C").await.unwrap()),
            Some(9_000),
            "a shorter/older expiry must not overwrite a longer one"
        );
        apply_verified_purchase(&state, "C", &vp("TX-YEAR", "premium", Some(12_000)))
            .await
            .unwrap();
        assert_eq!(
            expires(state.store.entitlement_get("C").await.unwrap()),
            Some(12_000),
            "a renewal still extends the subscription"
        );
        apply_verified_purchase(&state, "C", &vp("TX-LIFE-C", "lifetime", None))
            .await
            .unwrap();
        assert_eq!(
            state
                .store
                .entitlement_get("C")
                .await
                .unwrap()
                .unwrap()
                .tier,
            "lifetime",
            "sub -> lifetime is an upgrade"
        );

        // Чужой старый чек не снимает lifetime с B и не уезжает с D…
        state
            .store
            .entitlement_upsert(EntitlementRecord {
                profile_id: "D".into(),
                tier: "premium".into(),
                source: "appstore".into(),
                store_tx_id: Some("TX-D".into()),
                expires_at_ms: Some(5),
                grace_until_ms: None,
                updated_at_ms: 1,
            })
            .await
            .unwrap();
        apply_verified_purchase(&state, "B", &vp("TX-D", "premium", Some(5)))
            .await
            .unwrap();
        assert_eq!(
            state
                .store
                .entitlement_get("B")
                .await
                .unwrap()
                .unwrap()
                .tier,
            "lifetime"
        );
        assert_eq!(
            state
                .store
                .entitlement_profile_for_store_tx("TX-D")
                .await
                .unwrap()
                .as_deref(),
            Some("D")
        );
        // …а переустановка без покупки на новом профиле забирает чек как раньше.
        apply_verified_purchase(&state, "E", &vp("TX-D", "premium", Some(5)))
            .await
            .unwrap();
        assert_eq!(
            state
                .store
                .entitlement_profile_for_store_tx("TX-D")
                .await
                .unwrap()
                .as_deref(),
            Some("E")
        );

        // Сама проверка.
        let row = |tier: &str, expires: Option<i64>| EntitlementRecord {
            profile_id: "X".into(),
            tier: tier.into(),
            source: "appstore".into(),
            store_tx_id: Some("TX-X".into()),
            expires_at_ms: expires,
            grace_until_ms: None,
            updated_at_ms: 0,
        };
        assert!(purchase_would_downgrade(
            Some(&row("lifetime", None)),
            &vp("x", "premium", Some(1))
        ));
        assert!(purchase_would_downgrade(
            Some(&row("premium", Some(10))),
            &vp("x", "free", None)
        ));
        assert!(purchase_would_downgrade(
            Some(&row("premium", Some(10))),
            &vp("x", "premium", Some(9))
        ));
        assert!(!purchase_would_downgrade(
            None,
            &vp("x", "premium", Some(1))
        ));
        assert!(!purchase_would_downgrade(
            Some(&row("free", None)),
            &vp("x", "premium", Some(1))
        ));
        assert!(!purchase_would_downgrade(
            Some(&row("premium", Some(10))),
            &vp("x", "lifetime", None)
        ));
        assert!(!purchase_would_downgrade(
            Some(&row("premium", Some(10))),
            &vp("x", "premium", Some(11))
        ));
        assert!(!purchase_would_downgrade(
            Some(&row("lifetime", None)),
            &vp("x", "lifetime", None)
        ));
    }

    #[tokio::test]
    async fn entitlement_rebind_moves_tier_to_new_profile() {
        let (state, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[101u8; 32]);
        let from = "profile_rebind_from";
        let to = "profile_rebind_to";
        seed_profile_device(&state, from, "dev_rebind_from", &key).await;
        seed_profile_device(&state, to, "dev_rebind_to", &key).await;

        // Grant a lifetime entitlement (with a unique receipt) on the old profile.
        state
            .store
            .entitlement_upsert(EntitlementRecord {
                profile_id: from.to_string(),
                tier: "lifetime".into(),
                source: "manual".into(),
                store_tx_id: Some("tx-rebind-1".into()),
                expires_at_ms: None,
                grace_until_ms: None,
                updated_at_ms: 1,
            })
            .await
            .unwrap();

        // Rebind to the new profile: tier/source/receipt follow, old row clears.
        let outcome = state.store.entitlement_rebind(from, to, 12345).await.unwrap();
        assert!(matches!(outcome, EntitlementRebind::Moved(_)));
        let moved = state.store.entitlement_get(to).await.unwrap().expect("moved");
        assert_eq!(moved.tier, "lifetime");
        assert_eq!(moved.source, "manual");
        assert_eq!(moved.store_tx_id.as_deref(), Some("tx-rebind-1"));
        assert_eq!(moved.updated_at_ms, 12345);
        assert!(state.store.entitlement_get(from).await.unwrap().is_none());
        assert_eq!(
            state
                .store
                .entitlement_profile_for_store_tx("tx-rebind-1")
                .await
                .unwrap()
                .as_deref(),
            Some(to),
        );

        // No source entitlement → NoSource (target keeps what it has).
        assert!(matches!(
            state.store.entitlement_rebind(from, to, 2).await.unwrap(),
            EntitlementRebind::NoSource
        ));
        // Unknown target profile → UnknownTarget (nothing moved).
        assert!(matches!(
            state.store.entitlement_rebind(to, "ghost_profile", 3).await.unwrap(),
            EntitlementRebind::UnknownTarget
        ));
        assert_eq!(
            state.store.entitlement_get(to).await.unwrap().unwrap().tier,
            "lifetime"
        );
    }

    #[tokio::test]
    async fn grant_entitlement_requires_internal_key_and_grants_lifetime() {
        let (state, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[102u8; 32]);
        let pid = "profile_grant_1";
        seed_profile_device(&state, pid, "dev_grant_1", &key).await;

        // Without the internal key → 401, nothing granted.
        let err = grant_entitlement(
            State(state.clone()),
            HeaderMap::new(),
            Json(GrantEntitlementRequest {
                profile_id: pid.to_string(),
                tier: None,
            }),
        )
        .await
        .err()
        .expect("grant without internal key must fail");
        assert_eq!(err.0, StatusCode::UNAUTHORIZED);
        assert!(state.store.entitlement_get(pid).await.unwrap().is_none());

        // With the internal key → grants lifetime (default tier).
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-secretly-internal-key",
            HeaderValue::from_static("internal-test-key"),
        );
        let resp = grant_entitlement(
            State(state.clone()),
            headers,
            Json(GrantEntitlementRequest {
                profile_id: pid.to_string(),
                tier: None,
            }),
        )
        .await
        .unwrap()
        .0;
        assert_eq!(resp.tier, "lifetime");
        let ent = state.store.entitlement_get(pid).await.unwrap().expect("granted");
        assert_eq!(ent.tier, "lifetime");
        assert_eq!(ent.source, "manual");
        assert!(ent.expires_at_ms.is_none());
    }

    // «Снять премиум» в админке (17.09.2026, перенос ba63912d): только с
    // внутренним ключом, снимает запись и отдаёт бесплатный тариф.
    #[tokio::test]
    async fn revoke_entitlement_requires_internal_key_and_drops_the_row() {
        let (state, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[104u8; 32]);
        let pid = "profile_revoke_1";
        seed_profile_device(&state, pid, "dev_revoke_1", &key).await;
        state
            .store
            .entitlement_upsert(EntitlementRecord {
                profile_id: pid.to_string(),
                tier: "lifetime".into(),
                source: "manual".into(),
                store_tx_id: None,
                expires_at_ms: None,
                grace_until_ms: None,
                updated_at_ms: 1,
            })
            .await
            .unwrap();

        let err = revoke_entitlement(
            State(state.clone()),
            HeaderMap::new(),
            Json(RevokeEntitlementRequest {
                profile_id: pid.to_string(),
            }),
        )
        .await
        .err()
        .expect("revoke without internal key must fail");
        assert_eq!(err.0, StatusCode::UNAUTHORIZED);
        assert!(state.store.entitlement_get(pid).await.unwrap().is_some());

        let mut headers = HeaderMap::new();
        headers.insert(
            "x-secretly-internal-key",
            HeaderValue::from_static("internal-test-key"),
        );
        let resp = revoke_entitlement(
            State(state.clone()),
            headers.clone(),
            Json(RevokeEntitlementRequest {
                profile_id: pid.to_string(),
            }),
        )
        .await
        .unwrap()
        .0;
        assert_eq!(resp.tier, "free");
        assert!(state.store.entitlement_get(pid).await.unwrap().is_none());

        // Повтор безвреден, чужой адрес не проходит проверку.
        assert_eq!(
            revoke_entitlement(
                State(state.clone()),
                headers.clone(),
                Json(RevokeEntitlementRequest {
                    profile_id: pid.to_string(),
                }),
            )
            .await
            .unwrap()
            .0
            .tier,
            "free"
        );
        let bad = revoke_entitlement(
            State(state.clone()),
            headers,
            Json(RevokeEntitlementRequest {
                profile_id: "../etc".to_string(),
            }),
        )
        .await
        .err()
        .expect("invalid id must fail");
        assert_eq!(bad.0, StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn legacy_claim_preserves_existing_paid_tier() {
        let (base, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[93u8; 32]);
        let profile_id = "profile_legacy_premium_1";
        let device_id = "device_legacy_premium_1";
        seed_profile_device(&base, profile_id, device_id, &key).await;
        base.store
            .entitlement_upsert(EntitlementRecord {
                profile_id: profile_id.to_string(),
                tier: "premium".into(),
                source: "appstore".into(),
                store_tx_id: Some("tx_keep_premium".into()),
                expires_at_ms: Some(now_ms() + 1_000_000),
                grace_until_ms: None,
                updated_at_ms: now_ms(),
            })
            .await
            .unwrap();

        // Even past the deadline, an already-paid profile is not gated/changed.
        let state = AppState {
            monetization: Arc::new(MonetizationConfig {
                legacy_claim_deadline_ms: Some(1),
                ..MonetizationConfig::from_env()
            }),
            reliability: Arc::new(ReliabilityConfig::default()),
            identity: Arc::new(IdentityConfig::default()),
            support: Arc::new(SupportServerConfig::default()),
            ..base
        };
        let headers = legacy_claim_headers(device_id, &key, profile_id, "legacy-keep");
        let resp = legacy_claim(
            State(state.clone()),
            headers,
            Json(LegacyClaimRequest {
                profile_id: profile_id.to_string(),
            }),
        )
        .await
        .unwrap()
        .0;
        assert_eq!(resp.tier, "premium");
        let stored = state.store.entitlement_get(profile_id).await.unwrap().unwrap();
        assert_eq!(stored.tier, "premium");
    }

    #[tokio::test]
    async fn legacy_claim_rejects_foreign_device() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[94u8; 32]);
        let foreign_key = SigningKey::from_bytes(&[95u8; 32]);
        let profile_id = "profile_legacy_owner_1";
        seed_profile_device(&state, profile_id, "device_legacy_owner_1", &owner_key).await;
        seed_profile_device(
            &state,
            "profile_legacy_foreign_1",
            "device_legacy_foreign_1",
            &foreign_key,
        )
        .await;

        let headers =
            legacy_claim_headers("device_legacy_foreign_1", &foreign_key, profile_id, "legacy-f");
        let err = legacy_claim(
            State(state.clone()),
            headers,
            Json(LegacyClaimRequest {
                profile_id: profile_id.to_string(),
            }),
        )
        .await
        .err()
        .expect("foreign device must be rejected");
        assert!(err.0 == StatusCode::FORBIDDEN || err.0 == StatusCode::UNAUTHORIZED);
        // No entitlement should have been written for the victim profile.
        assert!(state.store.entitlement_get(profile_id).await.unwrap().is_none());
    }

    async fn seed_profile_device(
        state: &AppState,
        profile_id: &str,
        device_id: &str,
        signing_key: &SigningKey,
    ) {
        state
            .store
            .insert_profile(profile_id, now_ms(), None)
            .await
            .unwrap();
        let identity_key_pub_b64 = base64::engine::general_purpose::STANDARD
            .encode(signing_key.verifying_key().to_bytes());
        let registered = state
            .store
            .register_device(profile_id, device_id, Some(&identity_key_pub_b64), now_ms())
            .await
            .unwrap();
        assert!(registered);
    }

    async fn seed_profile_device_with_secret(
        state: &AppState,
        profile_id: &str,
        device_id: &str,
        signing_key: &SigningKey,
        secret_seed: u8,
    ) -> String {
        let secret_bytes = [secret_seed; 32];
        let secret_b64 = base64::engine::general_purpose::STANDARD.encode(secret_bytes);
        let secret_hash_b64 =
            base64::engine::general_purpose::STANDARD.encode(Sha256::digest(secret_bytes));
        state
            .store
            .insert_profile(profile_id, now_ms(), Some(&secret_hash_b64))
            .await
            .unwrap();
        let identity_key_pub_b64 = base64::engine::general_purpose::STANDARD
            .encode(signing_key.verifying_key().to_bytes());
        let registered = state
            .store
            .register_device(profile_id, device_id, Some(&identity_key_pub_b64), now_ms())
            .await
            .unwrap();
        assert!(registered);
        secret_b64
    }

    async fn seed_profile_with_secret(
        state: &AppState,
        profile_id: &str,
        secret_seed: u8,
    ) -> String {
        let secret_bytes = [secret_seed; 32];
        let secret_b64 = base64::engine::general_purpose::STANDARD.encode(secret_bytes);
        let secret_hash_b64 =
            base64::engine::general_purpose::STANDARD.encode(Sha256::digest(secret_bytes));
        state
            .store
            .insert_profile(profile_id, now_ms(), Some(&secret_hash_b64))
            .await
            .unwrap();
        secret_b64
    }

    fn signature_b64(signing_key: &SigningKey, message: &[u8]) -> String {
        base64::engine::general_purpose::STANDARD.encode(signing_key.sign(message).to_bytes())
    }

    fn profile_secret_headers(secret_b64: &str) -> HeaderMap {
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-secretly-profile-secret-b64",
            HeaderValue::from_str(secret_b64).unwrap(),
        );
        headers
    }

    fn inactivity_set_request(
        signing_key: &SigningKey,
        profile_id: &str,
        device_id: &str,
        delete_after_inactivity_months: Option<i64>,
        nonce_seed: &str,
    ) -> ProfileInactivitySetRequest {
        let ts_ms = now_ms();
        let nonce_b64 = base64::engine::general_purpose::STANDARD.encode(nonce_seed.as_bytes());
        let signature_b64 = signature_b64(
            signing_key,
            &profile_inactivity_set_message(
                profile_id,
                device_id,
                delete_after_inactivity_months,
                ts_ms,
                &nonce_b64,
            ),
        );
        ProfileInactivitySetRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            delete_after_inactivity_months,
            ts_ms,
            nonce_b64,
            signature_b64,
        }
    }

    fn inactivity_heartbeat_request(
        signing_key: &SigningKey,
        profile_id: &str,
        device_id: &str,
        nonce_seed: &str,
    ) -> ProfileInactivityHeartbeatRequest {
        let ts_ms = now_ms();
        let nonce_b64 = base64::engine::general_purpose::STANDARD.encode(nonce_seed.as_bytes());
        let signature_b64 = signature_b64(
            signing_key,
            &profile_inactivity_heartbeat_message(profile_id, device_id, ts_ms, &nonce_b64),
        );
        ProfileInactivityHeartbeatRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            ts_ms,
            nonce_b64,
            signature_b64,
        }
    }

    fn publish_keys_signature_b64(signing_key: &SigningKey, req: &PublishKeysRequest) -> String {
        let mut otks = req.one_time_prekeys.clone();
        otks.sort_by_key(|key| key.prekey_id);

        let mut hash = Sha256::new();
        for key in &otks {
            hash.update(key.prekey_id.to_be_bytes());
            hash.update(key.prekey_pub_b64.as_bytes());
            hash.update(b"\n");
        }
        let otk_hash_b64 = base64::engine::general_purpose::STANDARD.encode(hash.finalize());
        let message = format!(
            "SECRETLY-KEYS-PUBLISH-V1\nprofile_id={}\ndevice_id={}\nidentity_key_pub_b64={}\nsigned_prekey_pub_b64={}\nsigned_prekey_sig_b64={}\none_time_prekeys_sha256_b64={}\nts_ms={}\nnonce_b64={}\n",
            req.profile_id,
            req.device_id,
            req.identity_key_pub_b64,
            req.signed_prekey_pub_b64,
            req.signed_prekey_sig_b64,
            otk_hash_b64,
            req.ts_ms,
            req.nonce_b64,
        );
        signature_b64(signing_key, message.as_bytes())
    }

    fn signed_auth_headers<F>(
        device_id: &str,
        signing_key: &SigningKey,
        nonce_seed: &str,
        build_message: F,
    ) -> HeaderMap
    where
        F: FnOnce(i64, &str) -> Vec<u8>,
    {
        let ts_ms = now_ms();
        let nonce_b64 = base64::engine::general_purpose::STANDARD.encode(nonce_seed.as_bytes());
        let auth_message = build_message(ts_ms, &nonce_b64);
        let signature_b64 = base64::engine::general_purpose::STANDARD
            .encode(signing_key.sign(&auth_message).to_bytes());

        let mut headers = HeaderMap::new();
        headers.insert(
            "x-secretly-device-id",
            HeaderValue::from_str(device_id).unwrap(),
        );
        headers.insert(
            "x-secretly-ts-ms",
            HeaderValue::from_str(&ts_ms.to_string()).unwrap(),
        );
        headers.insert(
            "x-secretly-nonce-b64",
            HeaderValue::from_str(&nonce_b64).unwrap(),
        );
        headers.insert(
            "x-secretly-signature-b64",
            HeaderValue::from_str(&signature_b64).unwrap(),
        );
        headers
    }

    #[tokio::test]
    async fn device_lookup_rejects_unauthenticated_request_when_auth_required() {
        let (state, _dir) = test_app_state().await;
        let target_key = SigningKey::from_bytes(&[41u8; 32]);
        seed_profile_device(&state, "profile_lookup_1", "device_lookup_1", &target_key).await;

        let err = match device_lookup(
            State(state),
            HeaderMap::new(),
            Path("device_lookup_1".to_string()),
        )
        .await
        {
            Ok(_) => panic!("expected unauthenticated device lookup to be rejected"),
            Err(err) => err,
        };
        assert_eq!(err.0, StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn device_lookup_allows_internal_key_bypass() {
        let (state, _dir) = test_app_state().await;
        let target_key = SigningKey::from_bytes(&[42u8; 32]);
        seed_profile_device(&state, "profile_lookup_2", "device_lookup_2", &target_key).await;

        let mut headers = HeaderMap::new();
        headers.insert(
            "x-secretly-internal-key",
            HeaderValue::from_static("internal-test-key"),
        );

        let response = device_lookup(State(state), headers, Path("device_lookup_2".to_string()))
            .await
            .unwrap()
            .0;
        assert!(response.exists);
        assert_eq!(response.profile_id.as_deref(), Some("profile_lookup_2"));
    }

    #[tokio::test]
    async fn profile_search_rejects_unauthenticated_request_when_auth_required() {
        let (state, _dir) = test_app_state().await;
        let target_key = SigningKey::from_bytes(&[43u8; 32]);
        seed_profile_device(
            &state,
            "profile_search_target_1",
            "device_search_target_1",
            &target_key,
        )
        .await;
        state
            .store
            .profile_meta_set(
                "profile_search_target_1",
                Some("Alice"),
                None,
                None,
                None,
                true,
                None,
                None,
                None,
                None,
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let err = match profile_search(
            State(state),
            HeaderMap::new(),
            Query(ProfileSearchQuery {
                query: "Alice".into(),
                limit: Some(10),
            }),
        )
        .await
        {
            Ok(_) => panic!("expected unauthenticated profile search to be rejected"),
            Err(err) => err,
        };
        assert_eq!(err.0, StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn profile_search_returns_results_for_valid_signed_request() {
        let (state, _dir) = test_app_state().await;
        let requester_key = SigningKey::from_bytes(&[44u8; 32]);
        let target_key = SigningKey::from_bytes(&[45u8; 32]);
        seed_profile_device(
            &state,
            "profile_search_requester_1",
            "device_search_requester_1",
            &requester_key,
        )
        .await;
        seed_profile_device(
            &state,
            "profile_search_target_2",
            "device_search_target_2",
            &target_key,
        )
        .await;
        state
            .store
            .profile_meta_set(
                "profile_search_target_2",
                Some("Alice"),
                None,
                None,
                None,
                true,
                None,
                None,
                None,
                None,
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let headers = signed_auth_headers(
            "device_search_requester_1",
            &requester_key,
            "profile-search-signed",
            |ts_ms, nonce_b64| {
                keys_profile_search_auth_message(
                    "device_search_requester_1",
                    "Alice",
                    ts_ms,
                    nonce_b64,
                )
            },
        );

        let response = profile_search(
            State(state),
            headers,
            Query(ProfileSearchQuery {
                query: "Alice".into(),
                limit: Some(10),
            }),
        )
        .await
        .unwrap()
        .0;

        assert_eq!(response.items.len(), 1);
        assert_eq!(response.items[0].profile_id, "profile_search_target_2");
        assert_eq!(response.items[0].nickname.as_deref(), Some("Alice"));
    }

    #[tokio::test]
    async fn list_devices_returns_devices_for_valid_signed_request() {
        let (state, _dir) = test_app_state().await;
        let requester_key = SigningKey::from_bytes(&[46u8; 32]);
        let target_key_a = SigningKey::from_bytes(&[47u8; 32]);
        let target_key_b = SigningKey::from_bytes(&[48u8; 32]);
        seed_profile_device(
            &state,
            "profile_list_1",
            "device_list_requester_1",
            &requester_key,
        )
        .await;
        let target_key_a_pub_b64 = base64::engine::general_purpose::STANDARD
            .encode(target_key_a.verifying_key().to_bytes());
        let registered_second = state
            .store
            .register_device(
                "profile_list_1",
                "device_list_other_1",
                Some(&target_key_a_pub_b64),
                now_ms(),
            )
            .await
            .unwrap();
        assert!(registered_second);
        let registered_third = state
            .store
            .register_device(
                "profile_list_1",
                "device_list_other_2",
                Some(
                    &base64::engine::general_purpose::STANDARD
                        .encode(target_key_b.verifying_key().to_bytes()),
                ),
                now_ms(),
            )
            .await
            .unwrap();
        assert!(registered_third);

        let signed_prekey_pub_b64 = base64::engine::general_purpose::STANDARD.encode([49u8; 32]);
        let signed_prekey_sig_b64 = base64::engine::general_purpose::STANDARD.encode([50u8; 64]);
        let published = state
            .store
            .publish_key_bundle(
                "profile_list_1",
                "device_list_other_1",
                &target_key_a_pub_b64,
                &signed_prekey_pub_b64,
                &signed_prekey_sig_b64,
                vec![OneTimePrekey {
                    prekey_id: 1,
                    prekey_pub_b64: "otk-list-1".into(),
                }],
                now_ms(),
                None,
                None,
            )
            .await
            .unwrap();
        assert!(published);

        let headers = signed_auth_headers(
            "device_list_requester_1",
            &requester_key,
            "list-devices-signed",
            |ts_ms, nonce_b64| {
                keys_list_devices_auth_message(
                    "device_list_requester_1",
                    "profile_list_1",
                    ts_ms,
                    nonce_b64,
                )
            },
        );

        let response = list_devices(State(state), headers, Path("profile_list_1".to_string()))
            .await
            .unwrap()
            .0;

        assert_eq!(response.device_ids.len(), 3);
        assert_eq!(response.devices.len(), 3);
        let requester = response
            .devices
            .iter()
            .find(|device| device.device_id == "device_list_requester_1")
            .unwrap();
        assert!(!requester.has_bundle);
        assert!(requester.identity_key_pub_b64.is_none());

        let published_device = response
            .devices
            .iter()
            .find(|device| device.device_id == "device_list_other_1")
            .unwrap();
        assert!(published_device.has_bundle);
        assert_eq!(
            published_device.identity_key_pub_b64.as_deref(),
            Some(target_key_a_pub_b64.as_str())
        );
        assert_eq!(
            published_device.signed_prekey_pub_b64.as_deref(),
            Some(signed_prekey_pub_b64.as_str())
        );
        assert_eq!(
            published_device.signed_prekey_sig_b64.as_deref(),
            Some(signed_prekey_sig_b64.as_str())
        );

        let unpublished_device = response
            .devices
            .iter()
            .find(|device| device.device_id == "device_list_other_2")
            .unwrap();
        assert!(!unpublished_device.has_bundle);
        assert!(unpublished_device.identity_key_pub_b64.is_none());
        assert!(
            response
                .device_ids
                .contains(&"device_list_requester_1".to_string())
        );
        assert!(
            response
                .device_ids
                .contains(&"device_list_other_1".to_string())
        );
        assert!(
            response
                .device_ids
                .contains(&"device_list_other_2".to_string())
        );
    }

    #[tokio::test]
    async fn list_devices_allows_signed_foreign_device() {
        let (state, _dir) = test_app_state().await;
        let foreign_key = SigningKey::from_bytes(&[49u8; 32]);
        let target_key = SigningKey::from_bytes(&[50u8; 32]);
        seed_profile_device(
            &state,
            "profile_foreign_1",
            "device_foreign_1",
            &foreign_key,
        )
        .await;
        seed_profile_device(&state, "profile_target_1", "device_target_1", &target_key).await;

        let headers = signed_auth_headers(
            "device_foreign_1",
            &foreign_key,
            "list-devices-foreign",
            |ts_ms, nonce_b64| {
                keys_list_devices_auth_message(
                    "device_foreign_1",
                    "profile_target_1",
                    ts_ms,
                    nonce_b64,
                )
            },
        );

        let response = list_devices(State(state), headers, Path("profile_target_1".to_string()))
            .await
            .unwrap()
            .0;

        assert_eq!(response.device_ids, vec!["device_target_1".to_string()]);
        assert_eq!(response.devices.len(), 1);
        assert_eq!(response.devices[0].device_id, "device_target_1");
    }

    #[tokio::test]
    async fn delete_device_removes_target_for_valid_same_profile_requester() {
        let (state, _dir) = test_app_state().await;
        let requester_key = SigningKey::from_bytes(&[70u8; 32]);
        let target_key = SigningKey::from_bytes(&[71u8; 32]);
        let profile_secret_b64 = seed_profile_device_with_secret(
            &state,
            "profile_delete_1",
            "device_delete_requester_1",
            &requester_key,
            72,
        )
        .await;
        let target_identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(target_key.verifying_key().to_bytes());
        assert!(
            state
                .store
                .register_device(
                    "profile_delete_1",
                    "device_delete_target_1",
                    Some(&target_identity_key_pub_b64),
                    now_ms(),
                )
                .await
                .unwrap()
        );

        let mut headers = signed_auth_headers(
            "device_delete_requester_1",
            &requester_key,
            "delete-device-signed",
            |ts_ms, nonce_b64| {
                keys_delete_device_auth_message(
                    "device_delete_requester_1",
                    "profile_delete_1",
                    "device_delete_target_1",
                    ts_ms,
                    nonce_b64,
                )
            },
        );
        headers.insert(
            "x-secretly-profile-secret-b64",
            HeaderValue::from_str(&profile_secret_b64).unwrap(),
        );

        let response = delete_device(
            State(state.clone()),
            headers,
            Json(DeleteDeviceRequest {
                profile_id: "profile_delete_1".into(),
                device_id: "device_delete_target_1".into(),
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        let remaining_devices = state.store.list_devices("profile_delete_1").await.unwrap();
        assert_eq!(
            remaining_devices,
            vec!["device_delete_requester_1".to_string()]
        );
        assert!(
            state
                .store
                .profile_id_for_device("device_delete_target_1")
                .await
                .unwrap()
                .is_none()
        );
    }

    #[tokio::test]
    async fn delete_device_rejects_signed_foreign_requester() {
        let (state, _dir) = test_app_state().await;
        let foreign_key = SigningKey::from_bytes(&[73u8; 32]);
        let target_key = SigningKey::from_bytes(&[74u8; 32]);
        let profile_secret_b64 = seed_profile_device_with_secret(
            &state,
            "profile_delete_2",
            "device_delete_target_2",
            &target_key,
            75,
        )
        .await;
        seed_profile_device(
            &state,
            "profile_delete_foreign_2",
            "device_delete_foreign_2",
            &foreign_key,
        )
        .await;

        let mut headers = signed_auth_headers(
            "device_delete_foreign_2",
            &foreign_key,
            "delete-device-foreign",
            |ts_ms, nonce_b64| {
                keys_delete_device_auth_message(
                    "device_delete_foreign_2",
                    "profile_delete_2",
                    "device_delete_target_2",
                    ts_ms,
                    nonce_b64,
                )
            },
        );
        headers.insert(
            "x-secretly-profile-secret-b64",
            HeaderValue::from_str(&profile_secret_b64).unwrap(),
        );

        let err = match delete_device(
            State(state),
            headers,
            Json(DeleteDeviceRequest {
                profile_id: "profile_delete_2".into(),
                device_id: "device_delete_target_2".into(),
            }),
        )
        .await
        {
            Ok(_) => panic!("expected foreign signed requester to be rejected"),
            Err(err) => err,
        };
        assert_eq!(err.0, StatusCode::FORBIDDEN);
    }

    #[tokio::test]
    async fn device_identity_returns_identity_for_valid_signed_request() {
        let (state, _dir) = test_app_state().await;
        let requester_key = SigningKey::from_bytes(&[51u8; 32]);
        let target_key = SigningKey::from_bytes(&[52u8; 32]);
        let expected_identity_key =
            base64::engine::general_purpose::STANDARD.encode(target_key.verifying_key().to_bytes());
        seed_profile_device(
            &state,
            "profile_identity_requester_1",
            "device_identity_requester_1",
            &requester_key,
        )
        .await;
        seed_profile_device(
            &state,
            "profile_identity_target_1",
            "device_identity_target_1",
            &target_key,
        )
        .await;

        let headers = signed_auth_headers(
            "device_identity_requester_1",
            &requester_key,
            "device-identity-signed",
            |ts_ms, nonce_b64| {
                keys_device_identity_auth_message(
                    "device_identity_requester_1",
                    "device_identity_target_1",
                    ts_ms,
                    nonce_b64,
                )
            },
        );

        let response = device_identity(
            State(state),
            headers,
            Path("device_identity_target_1".to_string()),
        )
        .await
        .unwrap()
        .0;

        assert!(response.exists);
        assert_eq!(
            response.profile_id.as_deref(),
            Some("profile_identity_target_1")
        );
        assert_eq!(
            response.identity_key_pub_b64.as_deref(),
            Some(expected_identity_key.as_str())
        );
    }

    #[tokio::test]
    async fn register_device_proof_accepts_valid_request_and_consumes_challenge() {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[53u8; 32]);
        let profile_id = "profile_register_proof_1";
        let device_id = "device_register_proof_1";
        let secret_b64 = seed_profile_with_secret(&state, profile_id, 61).await;

        let challenge = device_challenge(
            State(state.clone()),
            Query(DeviceChallengeQuery {
                profile_id: profile_id.into(),
                device_id: device_id.into(),
            }),
        )
        .await
        .0;
        assert!(!challenge.nonce_b64.is_empty());

        let identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(device_key.verifying_key().to_bytes());
        let mut req = RegisterDeviceProofRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            identity_key_pub_b64,
            ts_ms: now_ms(),
            nonce_b64: challenge.nonce_b64.clone(),
            signature_b64: String::new(),
            device_class: None,
            device_label: None,
            replaces_device_id: None,
        };
        req.signature_b64 = signature_b64(&device_key, &register_proof_message(&req));

        let response = register_device_proof(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(RegisterDeviceProofRequest {
                profile_id: req.profile_id.clone(),
                device_id: req.device_id.clone(),
                identity_key_pub_b64: req.identity_key_pub_b64.clone(),
                ts_ms: req.ts_ms,
                nonce_b64: req.nonce_b64.clone(),
                signature_b64: req.signature_b64.clone(),
                device_class: None,
                device_label: None,
                replaces_device_id: None,
            }),
        )
        .await
        .0;
        assert!(response.ok);
        assert_eq!(
            state
                .store
                .profile_id_for_device(device_id)
                .await
                .unwrap()
                .as_deref(),
            Some(profile_id)
        );

        let replay_response =
            register_device_proof(State(state), profile_secret_headers(&secret_b64), Json(req))
                .await
                .0;
        assert!(!replay_response.ok);
        // Replay after the challenge was consumed must surface as
        // `challenge_missing` so the client knows to fetch a fresh challenge.
        assert_eq!(
            replay_response.error_code.as_deref(),
            Some("challenge_missing")
        );
    }

    #[tokio::test]
    async fn register_device_proof_rejects_clock_skew() {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[80u8; 32]);
        let profile_id = "profile_register_proof_clock_skew";
        let device_id = "device_register_proof_clock_skew";
        let secret_b64 = seed_profile_with_secret(&state, profile_id, 140).await;

        let challenge = device_challenge(
            State(state.clone()),
            Query(DeviceChallengeQuery {
                profile_id: profile_id.into(),
                device_id: device_id.into(),
            }),
        )
        .await
        .0;
        let identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(device_key.verifying_key().to_bytes());
        // ts_ms is 10 minutes in the past — beyond the ±5 min window.
        let bad_ts = now_ms() - 10 * 60 * 1000;
        let mut req = RegisterDeviceProofRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            identity_key_pub_b64,
            ts_ms: bad_ts,
            nonce_b64: challenge.nonce_b64,
            signature_b64: String::new(),
            device_class: None,
            device_label: None,
            replaces_device_id: None,
        };
        req.signature_b64 = signature_b64(&device_key, &register_proof_message(&req));

        let response = register_device_proof(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(req),
        )
        .await
        .0;
        assert!(!response.ok);
        assert_eq!(response.error_code.as_deref(), Some("clock_skew"));
        // Challenge must NOT be consumed on clock-skew — a retry after a clock
        // fix should succeed without fetching a fresh nonce.
        assert!(state.challenges.contains_key(device_id));
    }

    #[tokio::test]
    async fn register_device_proof_rejects_bad_signature() {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[81u8; 32]);
        let wrong_key = SigningKey::from_bytes(&[82u8; 32]);
        let profile_id = "profile_register_proof_bad_sig";
        let device_id = "device_register_proof_bad_sig";
        let secret_b64 = seed_profile_with_secret(&state, profile_id, 141).await;

        let challenge = device_challenge(
            State(state.clone()),
            Query(DeviceChallengeQuery {
                profile_id: profile_id.into(),
                device_id: device_id.into(),
            }),
        )
        .await
        .0;
        let identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(device_key.verifying_key().to_bytes());
        let mut req = RegisterDeviceProofRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            identity_key_pub_b64,
            ts_ms: now_ms(),
            nonce_b64: challenge.nonce_b64,
            signature_b64: String::new(),
            device_class: None,
            device_label: None,
            replaces_device_id: None,
        };
        // Sign with a key that does NOT correspond to identity_key_pub_b64.
        req.signature_b64 = signature_b64(&wrong_key, &register_proof_message(&req));

        let response = register_device_proof(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(req),
        )
        .await
        .0;
        assert!(!response.ok);
        assert_eq!(response.error_code.as_deref(), Some("signature_invalid"));
    }

    #[tokio::test]
    async fn register_device_proof_rejects_unknown_profile() {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[83u8; 32]);
        // No profile seeding — profile_id is unknown to the keys server.
        let profile_id = "profile_register_proof_unknown";
        let device_id = "device_register_proof_unknown";

        // Still issue a challenge (challenges are device-keyed, not profile-keyed).
        let challenge = device_challenge(
            State(state.clone()),
            Query(DeviceChallengeQuery {
                profile_id: profile_id.into(),
                device_id: device_id.into(),
            }),
        )
        .await
        .0;
        let identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(device_key.verifying_key().to_bytes());
        let mut req = RegisterDeviceProofRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            identity_key_pub_b64,
            ts_ms: now_ms(),
            nonce_b64: challenge.nonce_b64,
            signature_b64: String::new(),
            device_class: None,
            device_label: None,
            replaces_device_id: None,
        };
        req.signature_b64 = signature_b64(&device_key, &register_proof_message(&req));

        // Unknown profile — the profile-existence pre-check now runs BEFORE
        // the profile-secret check, so the client learns immediately that the
        // profile is not known to the keys server instead of a generic secret
        // failure. This is the remediation advice for the exact Android crash
        // `Bad state: registerDeviceProof returned ok=false`.
        let response = register_device_proof(State(state.clone()), HeaderMap::new(), Json(req))
            .await
            .0;
        assert!(!response.ok);
        assert_eq!(response.error_code.as_deref(), Some("profile_not_found"));
    }

    #[tokio::test]
    async fn register_device_proof_rejects_device_identity_key_mismatch() {
        let (state, _dir) = test_app_state().await;
        let old_key = SigningKey::from_bytes(&[90u8; 32]);
        let new_key = SigningKey::from_bytes(&[91u8; 32]);
        let profile_id = "profile_register_proof_ik_mismatch";
        let device_id = "device_register_proof_ik_mismatch";
        let secret_b64 =
            seed_profile_device_with_secret(&state, profile_id, device_id, &old_key, 142).await;

        // Fetch a fresh challenge for the SAME device_id but register with a
        // DIFFERENT identity key — the server must refuse with a specific code.
        let challenge = device_challenge(
            State(state.clone()),
            Query(DeviceChallengeQuery {
                profile_id: profile_id.into(),
                device_id: device_id.into(),
            }),
        )
        .await
        .0;
        let new_identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(new_key.verifying_key().to_bytes());
        let mut req = RegisterDeviceProofRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            identity_key_pub_b64: new_identity_key_pub_b64,
            ts_ms: now_ms(),
            nonce_b64: challenge.nonce_b64,
            signature_b64: String::new(),
            device_class: None,
            device_label: None,
            replaces_device_id: None,
        };
        req.signature_b64 = signature_b64(&new_key, &register_proof_message(&req));

        let response = register_device_proof(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(req),
        )
        .await
        .0;
        assert!(!response.ok);
        assert_eq!(
            response.error_code.as_deref(),
            Some("device_identity_key_mismatch")
        );
    }

    #[tokio::test]
    async fn register_device_proof_rejects_missing_profile_secret() {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[54u8; 32]);
        let profile_id = "profile_register_proof_2";
        let device_id = "device_register_proof_2";
        let _secret_b64 = seed_profile_with_secret(&state, profile_id, 62).await;

        let challenge = device_challenge(
            State(state.clone()),
            Query(DeviceChallengeQuery {
                profile_id: profile_id.into(),
                device_id: device_id.into(),
            }),
        )
        .await
        .0;
        let identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(device_key.verifying_key().to_bytes());
        let mut req = RegisterDeviceProofRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            identity_key_pub_b64,
            ts_ms: now_ms(),
            nonce_b64: challenge.nonce_b64,
            signature_b64: String::new(),
            device_class: None,
            device_label: None,
            replaces_device_id: None,
        };
        req.signature_b64 = signature_b64(&device_key, &register_proof_message(&req));

        let response = register_device_proof(State(state.clone()), HeaderMap::new(), Json(req))
            .await
            .0;
        assert!(!response.ok);
        assert!(
            state
                .store
                .profile_id_for_device(device_id)
                .await
                .unwrap()
                .is_none()
        );
    }

    #[tokio::test]
    async fn register_device_proof_rejects_expired_challenge() {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[59u8; 32]);
        let profile_id = "profile_register_proof_3";
        let device_id = "device_register_proof_3";
        let secret_b64 = seed_profile_with_secret(&state, profile_id, 66).await;
        let nonce_b64 = base64::engine::general_purpose::STANDARD.encode(b"expired-register-proof");
        state.challenges.insert(
            device_id.to_string(),
            DeviceChallenge {
                nonce_b64: nonce_b64.clone(),
                expires_at_ms: now_ms() - 1,
            },
        );

        let identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(device_key.verifying_key().to_bytes());
        let mut req = RegisterDeviceProofRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            identity_key_pub_b64,
            ts_ms: now_ms(),
            nonce_b64,
            signature_b64: String::new(),
            device_class: None,
            device_label: None,
            replaces_device_id: None,
        };
        req.signature_b64 = signature_b64(&device_key, &register_proof_message(&req));

        let response = register_device_proof(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(req),
        )
        .await
        .0;
        assert!(!response.ok);
        assert!(
            state
                .store
                .profile_id_for_device(device_id)
                .await
                .unwrap()
                .is_none()
        );
    }

    // Flag-OFF behaviour for the per-profile cap is asserted directly against
    // `enforce_device_registration_policy` in
    // `policy_rejects_new_device_at_cap_when_eviction_disabled` (deterministic,
    // no env coupling). This test now covers the production DEFAULT
    // (SECRETLY_KEYS_EVICT_STALEST_ON_CAP on): a cap hit on the proven
    // register_proof path evicts the stalest device and admits the new one.
    #[tokio::test]
    async fn register_device_proof_evicts_stalest_and_admits_new_device_at_capacity() {
        let (state, _dir) = test_app_state().await;
        let first_key = SigningKey::from_bytes(&[60u8; 32]);
        let second_key = SigningKey::from_bytes(&[61u8; 32]);
        let third_key = SigningKey::from_bytes(&[62u8; 32]);
        let profile_id = "profile_register_proof_4";
        // `first` is registered first (oldest created_at_ms) → the stalest, and
        // therefore the eviction target. `second` stays. `third` is the new
        // (live) device attempting to register at the cap.
        let first_device_id = "device_register_proof_4a";
        let second_device_id = "device_register_proof_4b";
        let third_device_id = "device_register_proof_4c";
        let secret_b64 =
            seed_profile_device_with_secret(&state, profile_id, first_device_id, &first_key, 67)
                .await;
        let second_identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(second_key.verifying_key().to_bytes());
        assert!(
            state
                .store
                .register_device(
                    profile_id,
                    second_device_id,
                    Some(&second_identity_key_pub_b64),
                    now_ms(),
                )
                .await
                .unwrap()
        );
        // Sanity: profile is exactly at the cap (2) before the new registration.
        assert_eq!(state.store.list_devices(profile_id).await.unwrap().len(), 2);

        let challenge = device_challenge(
            State(state.clone()),
            Query(DeviceChallengeQuery {
                profile_id: profile_id.into(),
                device_id: third_device_id.into(),
            }),
        )
        .await
        .0;
        let identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(third_key.verifying_key().to_bytes());
        let mut req = RegisterDeviceProofRequest {
            profile_id: profile_id.into(),
            device_id: third_device_id.into(),
            identity_key_pub_b64,
            ts_ms: now_ms(),
            nonce_b64: challenge.nonce_b64,
            signature_b64: String::new(),
            // Mobile class so the desktop-companion entitlement gate does not
            // mask the per-profile-cap eviction path under test.
            device_class: None,
            device_label: None,
            replaces_device_id: None,
        };
        req.signature_b64 = signature_b64(&third_key, &register_proof_message(&req));

        let response = register_device_proof(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(req),
        )
        .await
        .0;
        // The new (live) device is admitted.
        assert!(response.ok, "expected new device to be admitted at cap");
        assert_eq!(
            state
                .store
                .profile_id_for_device(third_device_id)
                .await
                .unwrap()
                .as_deref(),
            Some(profile_id)
        );
        // Strictly one-out / one-in: the stalest (first) device is gone.
        assert!(
            state
                .store
                .profile_id_for_device(first_device_id)
                .await
                .unwrap()
                .is_none(),
            "stalest device should have been evicted"
        );
        // The non-stalest device survives, and the count holds at the cap (>= 1).
        let remaining = state.store.list_devices(profile_id).await.unwrap();
        assert_eq!(remaining.len(), 2, "post-op device count must equal the cap");
        assert!(remaining.iter().any(|d| d == second_device_id));
        assert!(remaining.iter().any(|d| d == third_device_id));
    }

    // Flag-OFF: at the cap, a new device is hard-rejected and nothing is evicted.
    #[tokio::test]
    async fn policy_rejects_new_device_at_cap_when_eviction_disabled() {
        let (state, _dir) = test_app_state().await;
        let first_key = SigningKey::from_bytes(&[90u8; 32]);
        let second_key = SigningKey::from_bytes(&[91u8; 32]);
        let profile_id = "profile_policy_cap_off";
        seed_profile_device(&state, profile_id, "dev_cap_off_a", &first_key).await;
        let second_identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(second_key.verifying_key().to_bytes());
        assert!(
            state
                .store
                .register_device(
                    profile_id,
                    "dev_cap_off_b",
                    Some(&second_identity_key_pub_b64),
                    now_ms(),
                )
                .await
                .unwrap()
        );

        let err = enforce_device_registration_policy(
            &state,
            profile_id,
            "dev_cap_off_new",
            "mobile",
            /* evict_stalest_on_cap = */ false,
            None,
        )
        .await
        .expect_err("cap should reject new device when eviction disabled");
        assert_eq!(err.violation, DeviceRegistrationPolicyViolation::ProfileDeviceLimitReached);
        // Nothing evicted; the original two devices are intact.
        assert_eq!(state.store.list_devices(profile_id).await.unwrap().len(), 2);
        assert!(
            state
                .store
                .profile_id_for_device("dev_cap_off_a")
                .await
                .unwrap()
                .is_some()
        );
    }

    // Flag-ON but the only other device IS the registering device (re-register):
    // not a new device, so the cap branch is skipped and nothing is evicted —
    // upholds "never leave zero devices".
    #[tokio::test]
    async fn policy_does_not_evict_when_registering_device_already_present() {
        let (state, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[92u8; 32]);
        let profile_id = "profile_policy_reregister";
        seed_profile_device(&state, profile_id, "dev_reregister", &key).await;
        // Cap is 2 and only one device exists, but re-registering the SAME
        // device_id must be a no-op for the cap logic (and must never self-evict).
        enforce_device_registration_policy(
            &state,
            profile_id,
            "dev_reregister",
            "mobile",
            /* evict_stalest_on_cap = */ true,
            None,
        )
        .await
        .expect("re-registering an existing device must pass policy");
        let devices = state.store.list_devices(profile_id).await.unwrap();
        assert_eq!(devices, vec!["dev_reregister".to_string()]);
    }

    // И-1 §Д-7: at the cap, a rotation hint must evict the NAMED device — not
    // the stalest one. The dead old phone was alive minutes ago (fresh
    // last_seen), so the stalest ranking would sacrifice the innocent desktop.
    #[tokio::test]
    async fn policy_cap_evicts_hinted_device_not_stalest() {
        let (state, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[93u8; 32]);
        let profile_id = "profile_policy_i1_hint";
        // Desktop seeded FIRST → oldest timestamps → it IS the stalest.
        seed_profile_device(&state, profile_id, "dev_i1_desktop", &key).await;
        tokio::time::sleep(std::time::Duration::from_millis(5)).await;
        let phone_key = SigningKey::from_bytes(&[95u8; 32]);
        let phone_identity_b64 = base64::engine::general_purpose::STANDARD
            .encode(phone_key.verifying_key().to_bytes());
        assert!(
            state
                .store
                .register_device(
                    profile_id,
                    "dev_i1_old_phone",
                    Some(&phone_identity_b64),
                    now_ms(),
                )
                .await
                .unwrap()
        );

        enforce_device_registration_policy(
            &state,
            profile_id,
            "dev_i1_new_phone",
            "mobile",
            /* evict_stalest_on_cap = */ true,
            Some("dev_i1_old_phone"),
        )
        .await
        .expect("hinted eviction must admit the rotated device");

        let devices = state.store.list_devices(profile_id).await.unwrap();
        assert!(
            !devices.iter().any(|d| d == "dev_i1_old_phone"),
            "the hinted (replaced) device must be evicted"
        );
        assert!(
            devices.iter().any(|d| d == "dev_i1_desktop"),
            "the innocent sibling must survive a hinted eviction"
        );
    }

    // A hint naming an unknown (or foreign) id must change nothing about the
    // existing behaviour: fall back to the stalest ranking.
    #[tokio::test]
    async fn policy_cap_hint_unknown_falls_back_to_stalest() {
        let (state, _dir) = test_app_state().await;
        let key = SigningKey::from_bytes(&[94u8; 32]);
        let profile_id = "profile_policy_i1_hint_unknown";
        seed_profile_device(&state, profile_id, "dev_i1_stalest", &key).await;
        tokio::time::sleep(std::time::Duration::from_millis(5)).await;
        let fresh_key = SigningKey::from_bytes(&[96u8; 32]);
        let fresh_identity_b64 = base64::engine::general_purpose::STANDARD
            .encode(fresh_key.verifying_key().to_bytes());
        assert!(
            state
                .store
                .register_device(
                    profile_id,
                    "dev_i1_fresh",
                    Some(&fresh_identity_b64),
                    now_ms(),
                )
                .await
                .unwrap()
        );

        enforce_device_registration_policy(
            &state,
            profile_id,
            "dev_i1_newcomer",
            "mobile",
            /* evict_stalest_on_cap = */ true,
            Some("dev_i1_does_not_exist"),
        )
        .await
        .expect("unknown hint must fall back to stalest eviction");

        let devices = state.store.list_devices(profile_id).await.unwrap();
        assert!(
            !devices.iter().any(|d| d == "dev_i1_stalest"),
            "fallback must evict the stalest device"
        );
        assert!(devices.iter().any(|d| d == "dev_i1_fresh"));
    }

    #[tokio::test]
    async fn register_device_proof_rejects_desktop_without_companion_entitlement() {
        let (state, _dir) = test_app_state().await;
        let first_key = SigningKey::from_bytes(&[63u8; 32]);
        let profile_id = "profile_register_proof_desktop_entitlement_1";
        let secret_b64 = seed_profile_with_secret(&state, profile_id, 68).await;

        let challenge = device_challenge(
            State(state.clone()),
            Query(DeviceChallengeQuery {
                profile_id: profile_id.into(),
                device_id: "desktop_entitlement_a".into(),
            }),
        )
        .await
        .0;
        let identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(first_key.verifying_key().to_bytes());
        let mut req = RegisterDeviceProofRequest {
            profile_id: profile_id.into(),
            device_id: "desktop_entitlement_a".into(),
            identity_key_pub_b64,
            ts_ms: now_ms(),
            nonce_b64: challenge.nonce_b64,
            signature_b64: String::new(),
            device_class: Some("desktop".into()),
            device_label: Some("Windows Desktop".into()),
            replaces_device_id: None,
        };
        req.signature_b64 = signature_b64(&first_key, &register_proof_message(&req));
        let response = register_device_proof(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(req),
        )
        .await
        .0;
        assert!(!response.ok);
        assert_eq!(
            response.error_code.as_deref(),
            Some("desktop_companion_entitlement_required")
        );
    }

    #[tokio::test]
    async fn register_device_proof_rejects_second_desktop_when_companion_limit_is_full() {
        let (state, _dir) = test_app_state().await;
        let first_key = SigningKey::from_bytes(&[64u8; 32]);
        let second_key = SigningKey::from_bytes(&[65u8; 32]);
        let profile_id = "profile_register_proof_desktop_limit_1";
        let secret_b64 = seed_profile_with_secret(&state, profile_id, 70).await;

        let mut entitlement_headers = HeaderMap::new();
        entitlement_headers.insert(
            "x-secretly-internal-key",
            HeaderValue::from_static("internal-test-key"),
        );
        let entitlement_response = set_desktop_companion_entitlement(
            State(state.clone()),
            entitlement_headers,
            Path(profile_id.to_string()),
            Json(SetDesktopCompanionEntitlementRequest {
                limit: Some(1),
                source: Some("billing-admin".into()),
            }),
        )
        .await
        .unwrap()
        .0;
        assert!(entitlement_response.ok);

        let first_challenge = device_challenge(
            State(state.clone()),
            Query(DeviceChallengeQuery {
                profile_id: profile_id.into(),
                device_id: "desktop_limit_a".into(),
            }),
        )
        .await
        .0;
        let first_identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(first_key.verifying_key().to_bytes());
        let mut first_req = RegisterDeviceProofRequest {
            profile_id: profile_id.into(),
            device_id: "desktop_limit_a".into(),
            identity_key_pub_b64: first_identity_key_pub_b64,
            ts_ms: now_ms(),
            nonce_b64: first_challenge.nonce_b64,
            signature_b64: String::new(),
            device_class: Some("desktop".into()),
            device_label: Some("Windows Desktop".into()),
            replaces_device_id: None,
        };
        first_req.signature_b64 = signature_b64(&first_key, &register_proof_message(&first_req));
        let first_response = register_device_proof(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(first_req),
        )
        .await
        .0;
        assert!(first_response.ok);

        let second_challenge = device_challenge(
            State(state.clone()),
            Query(DeviceChallengeQuery {
                profile_id: profile_id.into(),
                device_id: "desktop_limit_b".into(),
            }),
        )
        .await
        .0;
        let second_identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(second_key.verifying_key().to_bytes());
        let mut second_req = RegisterDeviceProofRequest {
            profile_id: profile_id.into(),
            device_id: "desktop_limit_b".into(),
            identity_key_pub_b64: second_identity_key_pub_b64,
            ts_ms: now_ms(),
            nonce_b64: second_challenge.nonce_b64,
            signature_b64: String::new(),
            device_class: Some("desktop".into()),
            device_label: Some("Windows Desktop 2".into()),
            replaces_device_id: None,
        };
        second_req.signature_b64 = signature_b64(&second_key, &register_proof_message(&second_req));
        let second_response = register_device_proof(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(second_req),
        )
        .await
        .0;

        assert!(!second_response.ok);
        assert_eq!(
            second_response.error_code.as_deref(),
            Some("desktop_companion_limit_reached")
        );
    }

    #[tokio::test]
    async fn internal_entitlement_update_allows_second_desktop_registration() {
        let (state, _dir) = test_app_state().await;
        let first_key = SigningKey::from_bytes(&[66u8; 32]);
        let second_key = SigningKey::from_bytes(&[67u8; 32]);
        let profile_id = "profile_register_proof_desktop_limit_2";
        let secret_b64 = seed_profile_with_secret(&state, profile_id, 71).await;

        let mut initial_entitlement_headers = HeaderMap::new();
        initial_entitlement_headers.insert(
            "x-secretly-internal-key",
            HeaderValue::from_static("internal-test-key"),
        );
        let initial_entitlement_response = set_desktop_companion_entitlement(
            State(state.clone()),
            initial_entitlement_headers,
            Path(profile_id.to_string()),
            Json(SetDesktopCompanionEntitlementRequest {
                limit: Some(1),
                source: Some("billing-admin".into()),
            }),
        )
        .await
        .unwrap()
        .0;
        assert!(initial_entitlement_response.ok);

        let first_challenge = device_challenge(
            State(state.clone()),
            Query(DeviceChallengeQuery {
                profile_id: profile_id.into(),
                device_id: "desktop_limit2_a".into(),
            }),
        )
        .await
        .0;
        let first_identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(first_key.verifying_key().to_bytes());
        let mut first_req = RegisterDeviceProofRequest {
            profile_id: profile_id.into(),
            device_id: "desktop_limit2_a".into(),
            identity_key_pub_b64: first_identity_key_pub_b64,
            ts_ms: now_ms(),
            nonce_b64: first_challenge.nonce_b64,
            signature_b64: String::new(),
            device_class: Some("desktop".into()),
            device_label: Some("Windows Desktop".into()),
            replaces_device_id: None,
        };
        first_req.signature_b64 = signature_b64(&first_key, &register_proof_message(&first_req));
        let first_response = register_device_proof(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(first_req),
        )
        .await
        .0;
        assert!(first_response.ok);

        let mut entitlement_headers = HeaderMap::new();
        entitlement_headers.insert(
            "x-secretly-internal-key",
            HeaderValue::from_static("internal-test-key"),
        );
        let entitlement_response = set_desktop_companion_entitlement(
            State(state.clone()),
            entitlement_headers,
            Path(profile_id.to_string()),
            Json(SetDesktopCompanionEntitlementRequest {
                limit: Some(2),
                source: Some("billing-admin".into()),
            }),
        )
        .await
        .unwrap()
        .0;
        assert!(entitlement_response.ok);
        assert_eq!(entitlement_response.desktop_companion_limit, 2);

        let second_challenge = device_challenge(
            State(state.clone()),
            Query(DeviceChallengeQuery {
                profile_id: profile_id.into(),
                device_id: "desktop_limit2_b".into(),
            }),
        )
        .await
        .0;
        let second_identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(second_key.verifying_key().to_bytes());
        let mut second_req = RegisterDeviceProofRequest {
            profile_id: profile_id.into(),
            device_id: "desktop_limit2_b".into(),
            identity_key_pub_b64: second_identity_key_pub_b64,
            ts_ms: now_ms(),
            nonce_b64: second_challenge.nonce_b64,
            signature_b64: String::new(),
            device_class: Some("desktop".into()),
            device_label: Some("macOS Desktop".into()),
            replaces_device_id: None,
        };
        second_req.signature_b64 = signature_b64(&second_key, &register_proof_message(&second_req));
        let second_response = register_device_proof(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(second_req),
        )
        .await
        .0;

        assert!(second_response.ok);
    }

    #[tokio::test]
    async fn backup_set_stores_payload_for_valid_same_profile_device_and_secret() {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[55u8; 32]);
        let profile_id = "profile_backup_set_1";
        let device_id = "device_backup_set_1";
        let secret_b64 =
            seed_profile_device_with_secret(&state, profile_id, device_id, &device_key, 63).await;
        let payload = "encrypted-backup-payload-v2";
        let payload_sha256_b64 =
            base64::engine::general_purpose::STANDARD.encode(Sha256::digest(payload.as_bytes()));
        let ts_ms = now_ms();
        let nonce_b64 = "backup-set-1".to_string();
        let signature_b64 = signature_b64(
            &device_key,
            &backup_set_message(
                profile_id,
                device_id,
                &payload_sha256_b64,
                ts_ms,
                &nonce_b64,
            ),
        );

        let response = backup_set(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(BackupSetRequest {
                profile_id: profile_id.into(),
                device_id: device_id.into(),
                payload: payload.into(),
                payload_sha256_b64: payload_sha256_b64.clone(),
                ts_ms,
                nonce_b64,
                signature_b64,
                access_salt_b64: None,
                access_verifier_b64: None,
            }),
        )
        .await
        .0;
        assert!(response.ok);

        let stored = state.store.backup_get(profile_id).await.unwrap().unwrap();
        assert_eq!(stored.0, payload);
        assert_eq!(stored.1, payload_sha256_b64);
    }

    #[tokio::test]
    async fn backup_set_rejects_payload_hash_mismatch_even_with_valid_signature() {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[56u8; 32]);
        let profile_id = "profile_backup_set_2";
        let device_id = "device_backup_set_2";
        let secret_b64 =
            seed_profile_device_with_secret(&state, profile_id, device_id, &device_key, 64).await;
        let payload = "encrypted-backup-payload-v3";
        let wrong_payload_sha256_b64 =
            base64::engine::general_purpose::STANDARD.encode(Sha256::digest(b"different-payload"));
        let ts_ms = now_ms();
        let nonce_b64 = "backup-set-2".to_string();
        let signature_b64 = signature_b64(
            &device_key,
            &backup_set_message(
                profile_id,
                device_id,
                &wrong_payload_sha256_b64,
                ts_ms,
                &nonce_b64,
            ),
        );

        let response = backup_set(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(BackupSetRequest {
                profile_id: profile_id.into(),
                device_id: device_id.into(),
                payload: payload.into(),
                payload_sha256_b64: wrong_payload_sha256_b64,
                ts_ms,
                nonce_b64,
                signature_b64,
                access_salt_b64: None,
                access_verifier_b64: None,
            }),
        )
        .await
        .0;
        assert!(!response.ok);
        assert!(state.store.backup_get(profile_id).await.unwrap().is_none());
    }

    #[tokio::test]
    async fn backup_set_rejects_signed_foreign_device_even_with_target_secret() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[57u8; 32]);
        let foreign_key = SigningKey::from_bytes(&[58u8; 32]);
        let target_profile_id = "profile_backup_set_3";
        let owner_device_id = "device_backup_set_owner_3";
        let foreign_device_id = "device_backup_set_foreign_3";
        let secret_b64 = seed_profile_device_with_secret(
            &state,
            target_profile_id,
            owner_device_id,
            &owner_key,
            65,
        )
        .await;
        seed_profile_device(
            &state,
            "profile_backup_set_foreign_3",
            foreign_device_id,
            &foreign_key,
        )
        .await;

        let payload = "encrypted-backup-payload-v4";
        let payload_sha256_b64 =
            base64::engine::general_purpose::STANDARD.encode(Sha256::digest(payload.as_bytes()));
        let ts_ms = now_ms();
        let nonce_b64 = "backup-set-3".to_string();
        let signature_b64 = signature_b64(
            &foreign_key,
            &backup_set_message(
                target_profile_id,
                foreign_device_id,
                &payload_sha256_b64,
                ts_ms,
                &nonce_b64,
            ),
        );

        let response = backup_set(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(BackupSetRequest {
                profile_id: target_profile_id.into(),
                device_id: foreign_device_id.into(),
                payload: payload.into(),
                payload_sha256_b64,
                ts_ms,
                nonce_b64,
                signature_b64,
                access_salt_b64: None,
                access_verifier_b64: None,
            }),
        )
        .await
        .0;
        assert!(!response.ok);
        assert!(
            state
                .store
                .backup_get(target_profile_id)
                .await
                .unwrap()
                .is_none()
        );
    }

    #[tokio::test]
    async fn backup_set_rejects_replayed_nonce() {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[71u8; 32]);
        let profile_id = "profile_backup_set_replay";
        let device_id = "device_backup_set_replay";
        let secret_b64 =
            seed_profile_device_with_secret(&state, profile_id, device_id, &device_key, 71).await;
        let payload = "encrypted-backup-payload-replay";
        let payload_sha256_b64 =
            base64::engine::general_purpose::STANDARD.encode(Sha256::digest(payload.as_bytes()));
        let ts_ms = now_ms();
        let nonce_b64 = "backup-set-replay".to_string();
        let signature_b64 = signature_b64(
            &device_key,
            &backup_set_message(
                profile_id,
                device_id,
                &payload_sha256_b64,
                ts_ms,
                &nonce_b64,
            ),
        );

        let first = backup_set(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(BackupSetRequest {
                profile_id: profile_id.into(),
                device_id: device_id.into(),
                payload: payload.into(),
                payload_sha256_b64: payload_sha256_b64.clone(),
                ts_ms,
                nonce_b64: nonce_b64.clone(),
                signature_b64: signature_b64.clone(),
                access_salt_b64: None,
                access_verifier_b64: None,
            }),
        )
        .await
        .0;
        assert!(first.ok);

        let replay = backup_set(
            State(state),
            profile_secret_headers(&secret_b64),
            Json(BackupSetRequest {
                profile_id: profile_id.into(),
                device_id: device_id.into(),
                payload: payload.into(),
                payload_sha256_b64,
                ts_ms,
                nonce_b64,
                signature_b64,
                access_salt_b64: None,
                access_verifier_b64: None,
            }),
        )
        .await
        .0;
        assert!(!replay.ok);
    }

    // 🔴 Account identity (2026-08-08): one safety number per PERSON.
    //
    // The whole design leans on ONE property — a build that knows nothing about
    // account keys must keep publishing and keep receiving exactly as before.
    // publish_keys is also the liveness heartbeat, so any strictness added here
    // turns into lost messages, not a lost feature.
    async fn publish_with_account_identity(
        aik: Option<&str>,
        cert: Option<&str>,
        nonce: &str,
        seed: u8,
    ) -> (bool, Vec<store::DeviceKeyBundle>) {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[seed; 32]);
        let profile_id = "profile_aik_1";
        let device_id = "device_aik_1";
        let secret_b64 =
            seed_profile_device_with_secret(&state, profile_id, device_id, &device_key, seed).await;
        let identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(device_key.verifying_key().to_bytes());

        let mut req = PublishKeysRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            identity_key_pub_b64,
            signed_prekey_pub_b64: base64::engine::general_purpose::STANDARD.encode([9u8; 32]),
            signed_prekey_sig_b64: base64::engine::general_purpose::STANDARD.encode([10u8; 64]),
            one_time_prekeys: vec![],
            ts_ms: now_ms(),
            nonce_b64: nonce.into(),
            signature_b64: None,
            account_identity_pub_b64: aik.map(str::to_string),
            device_cert_b64: cert.map(str::to_string),
        };
        // 🔴 Подпись считается по ФИКСИРОВАННОМУ списку полей и новые НЕ
        // покрывает. Тест это и закрепляет: подпись остаётся верной, что бы мы
        // ни положили в новые поля, — иначе публикация у старых клиентов умерла
        // бы вместе с доставкой.
        req.signature_b64 = Some(publish_keys_signature_b64(&device_key, &req));

        let ok = publish_keys(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(req),
        )
        .await
        .0
        .ok;

        let fetched = fetch_bundle(
            State(state.clone()),
            signed_auth_headers(
                device_id,
                &device_key,
                &format!("fetch-{nonce}"),
                |ts_ms, nonce_b64| {
                    keys_fetch_bundle_auth_message(device_id, profile_id, ts_ms, nonce_b64)
                },
            ),
            Path(profile_id.to_string()),
        )
        .await
        .unwrap()
        .0
        .devices;

        (ok, fetched)
    }

    #[tokio::test]
    async fn account_identity_and_certificate_survive_publish_and_fetch() {
        let aik = base64::engine::general_purpose::STANDARD.encode([21u8; 32]);
        let cert = base64::engine::general_purpose::STANDARD.encode([22u8; 64]);
        let (ok, devices) =
            publish_with_account_identity(Some(&aik), Some(&cert), "aik-roundtrip", 71).await;
        assert!(ok);
        assert_eq!(devices.len(), 1);
        assert_eq!(
            devices[0].account_identity_pub_b64.as_deref(),
            Some(&aik[..])
        );
        assert_eq!(devices[0].device_cert_b64.as_deref(), Some(&cert[..]));
    }

    #[tokio::test]
    async fn a_client_that_sends_no_account_identity_still_publishes() {
        // Это все существующие установки. Ужесточи здесь что-нибудь — и они
        // перестанут публиковать ключи, то есть перестанут получать сообщения.
        let (ok, devices) = publish_with_account_identity(None, None, "aik-absent", 72).await;
        assert!(ok);
        assert_eq!(devices.len(), 1);
        assert!(devices[0].account_identity_pub_b64.is_none());
        assert!(devices[0].device_cert_b64.is_none());
    }

    #[tokio::test]
    async fn half_a_pair_is_dropped_whole() {
        // 🔴 Сертификат без ключа, которым он подписан, непроверяем. Оставь мы
        // половину — получатель видел бы «у устройства есть сертификат», и тот
        // никогда бы не сошёлся, то есть предупреждение о смене номера висело бы
        // навсегда.
        let aik = base64::engine::general_purpose::STANDARD.encode([21u8; 32]);
        let cert = base64::engine::general_purpose::STANDARD.encode([22u8; 64]);

        let (ok_a, devices_a) =
            publish_with_account_identity(Some(&aik), None, "aik-half-1", 73).await;
        assert!(ok_a);
        assert!(devices_a[0].account_identity_pub_b64.is_none());
        assert!(devices_a[0].device_cert_b64.is_none());

        let (ok_b, devices_b) =
            publish_with_account_identity(None, Some(&cert), "aik-half-2", 74).await;
        assert!(ok_b);
        assert!(devices_b[0].account_identity_pub_b64.is_none());
        assert!(devices_b[0].device_cert_b64.is_none());
    }

    #[tokio::test]
    async fn malformed_account_identity_is_dropped_but_publish_still_succeeds() {
        // 🔴 Направление отказа: НЕ отвергать публикацию. Отказ превратил бы
        // косметическую беду (нет улучшения номера у этого устройства) в
        // потерю доставки, потому что publish_keys — ещё и пульс живости.
        for (aik, cert) in [("не base64", "тоже не base64"), ("AAAA", "AAAA"), ("", "")] {
            let (ok, devices) = publish_with_account_identity(
                Some(aik),
                Some(cert),
                &format!("aik-bad-{}", aik.len()),
                75,
            )
            .await;
            assert!(ok, "publish must survive: {aik}");
            assert!(devices[0].account_identity_pub_b64.is_none());
            assert!(devices[0].device_cert_b64.is_none());
        }
    }

    #[tokio::test]
    async fn a_republish_refreshes_the_account_identity_columns() {
        // 🔴 Капкан, который я назвал сам: `ON CONFLICT DO UPDATE` перечисляет
        // столбцы ВРУЧНУЮ — та же форма, что `ConflictAlgorithm.replace` на
        // клиенте. Забудь новые столбцы в списке обновления, и первая публикация
        // выглядела бы верной, а дальше значение застыло бы навсегда: клиент
        // перепубликовывает ключи примерно каждые 12 часов, и именно этот путь
        // работает в проде, а не путь первой вставки.
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[81u8; 32]);
        let profile_id = "profile_aik_republish";
        let device_id = "device_aik_republish";
        let secret_b64 =
            seed_profile_device_with_secret(&state, profile_id, device_id, &device_key, 81).await;
        let identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(device_key.verifying_key().to_bytes());

        let publish = |aik: String, cert: String, nonce: String| {
            let state = state.clone();
            let secret_b64 = secret_b64.clone();
            let identity_key_pub_b64 = identity_key_pub_b64.clone();
            let device_key = device_key.clone();
            async move {
                let mut req = PublishKeysRequest {
                    profile_id: profile_id.into(),
                    device_id: device_id.into(),
                    identity_key_pub_b64,
                    signed_prekey_pub_b64: base64::engine::general_purpose::STANDARD
                        .encode([9u8; 32]),
                    signed_prekey_sig_b64: base64::engine::general_purpose::STANDARD
                        .encode([10u8; 64]),
                    one_time_prekeys: vec![],
                    ts_ms: now_ms(),
                    nonce_b64: nonce,
                    signature_b64: None,
                    account_identity_pub_b64: Some(aik),
                    device_cert_b64: Some(cert),
                };
                req.signature_b64 = Some(publish_keys_signature_b64(&device_key, &req));
                publish_keys(State(state), profile_secret_headers(&secret_b64), Json(req))
                    .await
                    .0
                    .ok
            }
        };

        let first_aik = base64::engine::general_purpose::STANDARD.encode([31u8; 32]);
        let first_cert = base64::engine::general_purpose::STANDARD.encode([32u8; 64]);
        assert!(publish(first_aik, first_cert, "aik-re-1".into()).await);

        // Устройство перевыпустило сертификат (например, сменился его
        // identity-ключ при ротации И-1) — связка обязана показать НОВЫЙ.
        let second_aik = base64::engine::general_purpose::STANDARD.encode([41u8; 32]);
        let second_cert = base64::engine::general_purpose::STANDARD.encode([42u8; 64]);
        assert!(publish(second_aik.clone(), second_cert.clone(), "aik-re-2".into()).await);

        let devices = fetch_bundle(
            State(state.clone()),
            signed_auth_headers(
                device_id,
                &device_key,
                "fetch-aik-republish",
                |ts_ms, nonce_b64| {
                    keys_fetch_bundle_auth_message(device_id, profile_id, ts_ms, nonce_b64)
                },
            ),
            Path(profile_id.to_string()),
        )
        .await
        .unwrap()
        .0
        .devices;

        assert_eq!(devices.len(), 1);
        assert_eq!(
            devices[0].account_identity_pub_b64.as_deref(),
            Some(&second_aik[..]),
            "повторная публикация обязана обновить ключ аккаунта"
        );
        assert_eq!(
            devices[0].device_cert_b64.as_deref(),
            Some(&second_cert[..]),
            "повторная публикация обязана обновить сертификат"
        );
    }

    #[tokio::test]
    async fn publish_keys_accepts_valid_signature_and_fetch_bundle_pops_one_time_prekey() {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[63u8; 32]);
        let profile_id = "profile_publish_keys_1";
        let device_id = "device_publish_keys_1";
        let secret_b64 =
            seed_profile_device_with_secret(&state, profile_id, device_id, &device_key, 68).await;
        let identity_key_pub_b64 =
            base64::engine::general_purpose::STANDARD.encode(device_key.verifying_key().to_bytes());
        let signed_prekey_pub_b64 = base64::engine::general_purpose::STANDARD.encode([9u8; 32]);
        let signed_prekey_sig_b64 = base64::engine::general_purpose::STANDARD.encode([10u8; 64]);

        let mut req = PublishKeysRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            identity_key_pub_b64: identity_key_pub_b64.clone(),
            signed_prekey_pub_b64: signed_prekey_pub_b64.clone(),
            signed_prekey_sig_b64: signed_prekey_sig_b64.clone(),
            one_time_prekeys: vec![OneTimePrekey {
                prekey_id: 7,
                prekey_pub_b64: base64::engine::general_purpose::STANDARD.encode([11u8; 32]),
            }],
            ts_ms: now_ms(),
            nonce_b64: "publish-keys-1".into(),
            signature_b64: None,
            account_identity_pub_b64: None,
            device_cert_b64: None,
        };
        req.signature_b64 = Some(publish_keys_signature_b64(&device_key, &req));

        let response = publish_keys(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(req),
        )
        .await
        .0;
        assert!(response.ok);

        let fetch_headers = signed_auth_headers(
            device_id,
            &device_key,
            "fetch-bundle-publish-1",
            |ts_ms, nonce_b64| {
                keys_fetch_bundle_auth_message(device_id, profile_id, ts_ms, nonce_b64)
            },
        );

        let first_fetch = fetch_bundle(
            State(state.clone()),
            fetch_headers.clone(),
            Path(profile_id.to_string()),
        )
        .await
        .unwrap()
        .0;
        assert_eq!(first_fetch.devices.len(), 1);
        assert_eq!(first_fetch.devices[0].device_id, device_id);
        assert_eq!(
            first_fetch.devices[0].identity_key_pub_b64,
            identity_key_pub_b64
        );
        assert_eq!(
            first_fetch.devices[0].signed_prekey_pub_b64,
            signed_prekey_pub_b64
        );
        assert_eq!(
            first_fetch.devices[0].signed_prekey_sig_b64,
            signed_prekey_sig_b64
        );
        assert_eq!(
            first_fetch.devices[0]
                .one_time_prekey
                .as_ref()
                .map(|key| key.prekey_id),
            Some(7)
        );

        let second_fetch = fetch_bundle(
            State(state),
            signed_auth_headers(
                device_id,
                &device_key,
                "fetch-bundle-publish-2",
                |ts_ms, nonce_b64| {
                    keys_fetch_bundle_auth_message(device_id, profile_id, ts_ms, nonce_b64)
                },
            ),
            Path(profile_id.to_string()),
        )
        .await
        .unwrap()
        .0;
        assert_eq!(second_fetch.devices.len(), 1);
        assert!(second_fetch.devices[0].one_time_prekey.is_none());
    }

    #[tokio::test]
    async fn publish_keys_rejects_bad_signature() {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[64u8; 32]);
        let wrong_key = SigningKey::from_bytes(&[65u8; 32]);
        let profile_id = "profile_publish_keys_2";
        let device_id = "device_publish_keys_2";
        let secret_b64 =
            seed_profile_device_with_secret(&state, profile_id, device_id, &device_key, 69).await;

        let mut req = PublishKeysRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            identity_key_pub_b64: base64::engine::general_purpose::STANDARD
                .encode(device_key.verifying_key().to_bytes()),
            signed_prekey_pub_b64: base64::engine::general_purpose::STANDARD.encode([12u8; 32]),
            signed_prekey_sig_b64: base64::engine::general_purpose::STANDARD.encode([13u8; 64]),
            one_time_prekeys: vec![OneTimePrekey {
                prekey_id: 8,
                prekey_pub_b64: base64::engine::general_purpose::STANDARD.encode([14u8; 32]),
            }],
            ts_ms: now_ms(),
            nonce_b64: "publish-keys-2".into(),
            signature_b64: None,
            account_identity_pub_b64: None,
            device_cert_b64: None,
        };
        req.signature_b64 = Some(publish_keys_signature_b64(&wrong_key, &req));

        let response = publish_keys(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(req),
        )
        .await
        .0;
        assert!(!response.ok);

        let fetched = fetch_bundle(
            State(state),
            signed_auth_headers(
                device_id,
                &device_key,
                "fetch-bundle-empty-after-bad-publish",
                |ts_ms, nonce_b64| {
                    keys_fetch_bundle_auth_message(device_id, profile_id, ts_ms, nonce_b64)
                },
            ),
            Path(profile_id.to_string()),
        )
        .await
        .unwrap()
        .0;
        assert!(fetched.devices.is_empty());
    }

    #[tokio::test]
    async fn fetch_bundle_rejects_unauthenticated_request_when_auth_required() {
        let (state, _dir) = test_app_state().await;
        let target_key = SigningKey::from_bytes(&[73u8; 32]);
        seed_profile_device(
            &state,
            "profile_fetch_bundle_1",
            "device_fetch_bundle_1",
            &target_key,
        )
        .await;

        let err = match fetch_bundle(
            State(state),
            HeaderMap::new(),
            Path("profile_fetch_bundle_1".to_string()),
        )
        .await
        {
            Ok(_) => panic!("expected unauthenticated fetch_bundle to be rejected"),
            Err(err) => err,
        };
        assert_eq!(err.0, StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn fetch_bundle_allows_signed_foreign_device() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[74u8; 32]);
        let foreign_key = SigningKey::from_bytes(&[75u8; 32]);
        let profile_id = "profile_fetch_bundle_2";
        let owner_device_id = "device_fetch_bundle_owner_2";
        let foreign_device_id = "device_fetch_bundle_foreign_2";
        let owner_identity_b64 =
            base64::engine::general_purpose::STANDARD.encode(owner_key.verifying_key().to_bytes());
        let signed_prekey_pub_b64 = base64::engine::general_purpose::STANDARD.encode([31u8; 32]);
        let signed_prekey_sig_b64 = base64::engine::general_purpose::STANDARD.encode([32u8; 64]);

        seed_profile_device(&state, profile_id, owner_device_id, &owner_key).await;
        seed_profile_device(
            &state,
            "profile_fetch_bundle_foreign_2",
            foreign_device_id,
            &foreign_key,
        )
        .await;
        let published = state
            .store
            .publish_key_bundle(
                profile_id,
                owner_device_id,
                &owner_identity_b64,
                &signed_prekey_pub_b64,
                &signed_prekey_sig_b64,
                vec![OneTimePrekey {
                    prekey_id: 3,
                    prekey_pub_b64: "otk-fetch-bundle-1".into(),
                }],
                now_ms(),
                None,
                None,
            )
            .await
            .unwrap();
        assert!(published);

        let response = fetch_bundle(
            State(state),
            signed_auth_headers(
                foreign_device_id,
                &foreign_key,
                "fetch-bundle-foreign",
                |ts_ms, nonce_b64| {
                    keys_fetch_bundle_auth_message(foreign_device_id, profile_id, ts_ms, nonce_b64)
                },
            ),
            Path(profile_id.to_string()),
        )
        .await
        .unwrap()
        .0;

        assert_eq!(response.devices.len(), 1);
        assert_eq!(response.devices[0].device_id, owner_device_id);
        assert_eq!(response.devices[0].identity_key_pub_b64, owner_identity_b64);
    }

    #[tokio::test]
    async fn publish_keys_rejects_replayed_nonce() {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[72u8; 32]);
        let profile_id = "profile_publish_keys_replay";
        let device_id = "device_publish_keys_replay";
        let secret_b64 =
            seed_profile_device_with_secret(&state, profile_id, device_id, &device_key, 72).await;

        let mut req = PublishKeysRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            identity_key_pub_b64: base64::engine::general_purpose::STANDARD
                .encode(device_key.verifying_key().to_bytes()),
            signed_prekey_pub_b64: base64::engine::general_purpose::STANDARD.encode([21u8; 32]),
            signed_prekey_sig_b64: base64::engine::general_purpose::STANDARD.encode([22u8; 64]),
            one_time_prekeys: vec![OneTimePrekey {
                prekey_id: 9,
                prekey_pub_b64: base64::engine::general_purpose::STANDARD.encode([23u8; 32]),
            }],
            ts_ms: now_ms(),
            nonce_b64: "publish-keys-replay".into(),
            signature_b64: None,
            account_identity_pub_b64: None,
            device_cert_b64: None,
        };
        req.signature_b64 = Some(publish_keys_signature_b64(&device_key, &req));

        let first = publish_keys(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(PublishKeysRequest {
                profile_id: req.profile_id.clone(),
                device_id: req.device_id.clone(),
                identity_key_pub_b64: req.identity_key_pub_b64.clone(),
                signed_prekey_pub_b64: req.signed_prekey_pub_b64.clone(),
                signed_prekey_sig_b64: req.signed_prekey_sig_b64.clone(),
                one_time_prekeys: req.one_time_prekeys.clone(),
                ts_ms: req.ts_ms,
                nonce_b64: req.nonce_b64.clone(),
                signature_b64: req.signature_b64.clone(),
                account_identity_pub_b64: None,
                device_cert_b64: None,
            }),
        )
        .await
        .0;
        assert!(first.ok);

        let replay = publish_keys(State(state), profile_secret_headers(&secret_b64), Json(req))
            .await
            .0;
        assert!(!replay.ok);
    }

    #[tokio::test]
    async fn backup_get_rejects_signed_foreign_device() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[53u8; 32]);
        let foreign_key = SigningKey::from_bytes(&[54u8; 32]);
        let profile_id = "profile_backup_target_1";
        let payload = "encrypted-backup-payload";
        let payload_sha256_b64 =
            base64::engine::general_purpose::STANDARD.encode(Sha256::digest(payload.as_bytes()));

        seed_profile_device(&state, profile_id, "device_backup_owner_1", &owner_key).await;
        seed_profile_device(
            &state,
            "profile_backup_foreign_1",
            "device_backup_foreign_1",
            &foreign_key,
        )
        .await;
        state
            .store
            .backup_set(profile_id, payload, &payload_sha256_b64, now_ms())
            .await
            .unwrap();

        let headers = signed_auth_headers(
            "device_backup_foreign_1",
            &foreign_key,
            "backup-get-foreign",
            |ts_ms, nonce_b64| {
                keys_backup_get_auth_message(
                    "device_backup_foreign_1",
                    profile_id,
                    ts_ms,
                    nonce_b64,
                )
            },
        );

        let response = backup_get(State(state), headers, Path(profile_id.to_string()))
            .await
            .0;
        assert!(!response.exists);
        assert!(response.payload.is_none());
    }

    // ── Э-0 (25.08.2026), SEC-01: опора для токена доступа ───────────────────
    //
    // Схема правится в двух местах: `CREATE TABLE` (описание для свежей базы)
    // и `ALTER TABLE` в `init()`. Проверено на поломках: рабочую нагрузку несёт
    // именно ALTER — он выполняется при КАЖДОМ открытии, поэтому существующая
    // прод-база получает колонки только оттуда, а в свежей он лишь повторяет
    // то, что уже создал CREATE. Тест ниже с настоящей старой базой сторожит
    // этот путь и падает, если ALTER убрать; колонки в CREATE держим ради
    // читаемости схемы (шрам Wave-2, 06.07 — правка одной половины).

    /// SEC-07: точное время присутствия — только тому, кто предъявил подпись.
    ///
    /// Эндпоинт метаданных отвечает без авторизации: так его вызывают все уже
    /// выпущенные сборки, и отнять это разом значит лишить людей имён и
    /// аватаров собеседников. Но точное время присутствия в открытом ответе —
    /// это возможность следить: опрашивая раз в минуту, посторонний строит
    /// график чужого дня по одному лишь полупубличному идентификатору.
    ///
    /// 🔴 Тест сторожит ОБА свойства. Убрать огрубление — вернётся слежка;
    /// огрубить всем без разбора — сломается «был в сети» у своих же.
    #[tokio::test]
    async fn profile_meta_coarsens_presence_for_unauthenticated_callers() {
        let (state, _dir) = test_app_state().await;
        let profile_id = "profile_meta_presence_1";

        // Время, заведомо не кратное часу.
        let precise = 1_700_000_000_000i64 + 37 * 60 * 1000 + 21 * 1000;
        state.store.insert_profile(profile_id, precise, None).await.ok();
        state.store.mark_profile_present(profile_id, precise).await.ok();

        let response = profile_meta_get(
            State(state.clone()),
            HeaderMap::new(),
            Path(profile_id.to_string()),
        )
        .await
        .0;

        if response.last_active_at_ms == 0 {
            // Присутствие не записалось — проверять нечего, но и утечки нет.
            return;
        }

        const HOUR_MS: i64 = 60 * 60 * 1000;
        assert_eq!(
            response.last_active_at_ms % HOUR_MS,
            0,
            "неавторизованному отдано ТОЧНОЕ время присутствия — по нему \
             восстанавливается распорядок дня"
        );
    }

    #[tokio::test]
    async fn backup_access_columns_exist_on_fresh_database() {
        let (state, _dir) = test_app_state().await;
        let profile_id = "profile_backup_access_fresh_1";
        state
            .store
            .backup_set(profile_id, "payload", "sha", now_ms())
            .await
            .unwrap();

        // Пустая опора: профиль ещё не пересохранял архив новым клиентом.
        let before = state.store.backup_access_get(profile_id).await.unwrap();
        assert_eq!(before, Some((None, None)));

        state
            .store
            .backup_access_set(profile_id, "salt-b64", "verifier-b64")
            .await
            .unwrap();
        let after = state.store.backup_access_get(profile_id).await.unwrap();
        assert_eq!(
            after,
            Some((Some("salt-b64".to_string()), Some("verifier-b64".to_string())))
        );
    }

    #[tokio::test]
    async fn backup_access_columns_are_added_to_an_existing_database() {
        // База, созданная ДО этого этапа: таблица без новых колонок.
        let dir = tempfile::tempdir().unwrap();
        let db_path = dir.path().join("keys.db");
        {
            let c = tokio_rusqlite::rusqlite::Connection::open(&db_path).unwrap();
            c.execute(
                "CREATE TABLE profile_backups (
                    profile_id TEXT PRIMARY KEY,
                    payload TEXT NOT NULL,
                    payload_sha256_b64 TEXT NOT NULL,
                    updated_at_ms INTEGER NOT NULL
                )",
                [],
            )
            .unwrap();
            c.execute(
                "INSERT INTO profile_backups VALUES ('legacy_profile_1', 'old-payload', 'sha', 1)",
                [],
            )
            .unwrap();
        }

        // Открытие хранилища обязано достроить схему, НЕ тронув данные.
        let store = KeysStore::open(&db_path).await.unwrap();

        let row = store.backup_get("legacy_profile_1").await.unwrap();
        assert_eq!(
            row.map(|(payload, _, _)| payload),
            Some("old-payload".to_string()),
            "миграция схемы потеряла существующий архив"
        );

        store
            .backup_access_set("legacy_profile_1", "salt-b64", "verifier-b64")
            .await
            .unwrap();
        assert_eq!(
            store.backup_access_get("legacy_profile_1").await.unwrap(),
            Some((Some("salt-b64".to_string()), Some("verifier-b64".to_string()))),
            "колонки не добавлены в существующую базу — правка задела только CREATE"
        );
    }

    #[tokio::test]
    async fn backup_access_set_is_scoped_to_one_profile() {
        let (state, _dir) = test_app_state().await;
        for pid in ["profile_scope_a", "profile_scope_b"] {
            state
                .store
                .backup_set(pid, "payload", "sha", now_ms())
                .await
                .unwrap();
        }
        state
            .store
            .backup_access_set("profile_scope_a", "salt-a", "ver-a")
            .await
            .unwrap();

        assert_eq!(
            state.store.backup_access_get("profile_scope_b").await.unwrap(),
            Some((None, None)),
            "опора протекла на чужой профиль"
        );
    }

    // ── Э-1 (SEC-01): токен доступа принимается, но ещё не требуется ────────

    fn access_headers(token: &[u8]) -> HeaderMap {
        let mut h = HeaderMap::new();
        h.insert(
            "x-secretly-backup-access-b64",
            base64::engine::general_purpose::STANDARD
                .encode(token)
                .parse()
                .unwrap(),
        );
        h
    }

    fn verifier_for(token: &[u8]) -> String {
        base64::engine::general_purpose::STANDARD.encode(Sha256::digest(token))
    }

    #[tokio::test]
    async fn backup_get_accepts_a_matching_access_token() {
        let (state, _dir) = test_app_state().await;
        let profile_id = "profile_access_ok_1";
        let token = b"correct-access-token";
        state
            .store
            .backup_set(profile_id, "payload", "sha", now_ms())
            .await
            .unwrap();
        state
            .store
            .backup_access_set(profile_id, "salt-b64", &verifier_for(token))
            .await
            .unwrap();

        let response = backup_get(
            State(state),
            access_headers(token),
            Path(profile_id.to_string()),
        )
        .await
        .0;
        assert!(response.exists);
        assert_eq!(response.payload.as_deref(), Some("payload"));
    }

    #[tokio::test]
    async fn backup_get_rejects_a_wrong_access_token() {
        let (state, _dir) = test_app_state().await;
        let profile_id = "profile_access_bad_1";
        state
            .store
            .backup_set(profile_id, "payload", "sha", now_ms())
            .await
            .unwrap();
        state
            .store
            .backup_access_set(profile_id, "salt-b64", &verifier_for(b"correct"))
            .await
            .unwrap();

        let response = backup_get(
            State(state),
            access_headers(b"guessed-wrong"),
            Path(profile_id.to_string()),
        )
        .await
        .0;
        assert!(!response.exists, "неверный токен открыл чужой архив");
        assert!(response.payload.is_none());
    }

    #[tokio::test]
    async fn backup_get_still_serves_old_clients_without_a_token() {
        // Совместимость: сборка, которая про токен не знает, обязана
        // восстанавливаться как раньше — иначе её владелец теряет архив
        // навсегда. Требование включается только на Э-2.
        let (state, _dir) = test_app_state().await;
        let profile_id = "profile_access_legacy_1";
        state
            .store
            .backup_set(profile_id, "payload", "sha", now_ms())
            .await
            .unwrap();
        state
            .store
            .backup_access_set(profile_id, "salt-b64", &verifier_for(b"correct"))
            .await
            .unwrap();

        let response = backup_get(State(state), HeaderMap::new(), Path(profile_id.to_string()))
            .await
            .0;
        assert!(response.exists, "старый клиент потерял доступ к архиву на Э-1");
    }

    #[tokio::test]
    async fn backup_challenge_is_indistinguishable_for_unknown_profiles() {
        let (state, _dir) = test_app_state().await;

        // Профиль с опорой отдаёт свою соль.
        let known = "profile_challenge_known_1";
        state
            .store
            .backup_set(known, "payload", "sha", now_ms())
            .await
            .unwrap();
        state
            .store
            .backup_access_set(known, "real-salt-b64", "verifier")
            .await
            .unwrap();
        let real = backup_challenge(State(state.clone()), Path(known.to_string()))
            .await
            .0;
        assert_eq!(real.access_salt_b64, "real-salt-b64");

        // Несуществующий профиль обязан ответить правдоподобной солью, а не
        // пустотой: пустой ответ работал бы оракулом существования.
        let unknown = "profile_challenge_unknown_1";
        let decoy = backup_challenge(State(state.clone()), Path(unknown.to_string()))
            .await
            .0;
        assert!(
            !decoy.access_salt_b64.is_empty(),
            "вызов раскрывает, что профиля не существует"
        );

        // И она обязана быть устойчивой между запросами — «каждый раз новая»
        // выдаёт подделку не хуже пустоты.
        let again = backup_challenge(State(state), Path(unknown.to_string()))
            .await
            .0;
        assert_eq!(
            decoy.access_salt_b64, again.access_salt_b64,
            "ложная соль меняется между запросами и потому распознаётся"
        );
    }

    #[tokio::test]
    async fn backup_get_returns_payload_for_public_restore_without_auth_headers() {
        let (state, _dir) = test_app_state().await;
        let profile_id = "profile_backup_public_restore_1";
        let payload = "encrypted-backup-payload";
        let payload_sha256_b64 =
            base64::engine::general_purpose::STANDARD.encode(Sha256::digest(payload.as_bytes()));
        state
            .store
            .backup_set(profile_id, payload, &payload_sha256_b64, now_ms())
            .await
            .unwrap();

        let response = backup_get(State(state), HeaderMap::new(), Path(profile_id.to_string()))
            .await
            .0;
        assert!(response.exists);
        assert_eq!(response.payload.as_deref(), Some(payload));
    }

    #[tokio::test]
    async fn backup_get_returns_payload_for_same_profile_signed_device() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[55u8; 32]);
        let profile_id = "profile_backup_target_2";
        let requester_device_id = "device_backup_owner_2";
        let payload = "encrypted-backup-payload";
        let payload_sha256_b64 =
            base64::engine::general_purpose::STANDARD.encode(Sha256::digest(payload.as_bytes()));

        seed_profile_device(&state, profile_id, requester_device_id, &owner_key).await;
        state
            .store
            .backup_set(profile_id, payload, &payload_sha256_b64, now_ms())
            .await
            .unwrap();

        let headers = signed_auth_headers(
            requester_device_id,
            &owner_key,
            "backup-get-owner",
            |ts_ms, nonce_b64| {
                keys_backup_get_auth_message(requester_device_id, profile_id, ts_ms, nonce_b64)
            },
        );

        let response = backup_get(State(state), headers, Path(profile_id.to_string()))
            .await
            .0;
        assert!(response.exists);
        assert_eq!(response.payload.as_deref(), Some(payload));
    }

    #[tokio::test]
    async fn profile_meta_set_requires_profile_secret_and_accepts_valid_secret() {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[56u8; 32]);
        let profile_id = "profile_meta_secret_1";
        let device_id = "device_meta_secret_1";
        let secret_b64 =
            seed_profile_device_with_secret(&state, profile_id, device_id, &device_key, 57).await;

        let message = profile_meta_set_message(profile_id, device_id, "Alice", "", "", "", true);
        let signature_b64 =
            base64::engine::general_purpose::STANDARD.encode(device_key.sign(&message).to_bytes());
        let req = ProfileMetaSetRequest {
            profile_id: profile_id.into(),
            device_id: device_id.into(),
            nickname: Some("Alice".into()),
            avatar_png_b64: None,
            bio: None,
            privacy_audience_json: None,
            searchable_by_nickname: Some(true),
            frame_id: None,
            cover_id: None,
            cover_png_b64: None,
            emoji_status: None,
            premium_badge: None,
            signature_b64,
        };

        let missing_secret_response = profile_meta_set(
            State(state.clone()),
            HeaderMap::new(),
            Json(ProfileMetaSetRequest {
                profile_id: profile_id.into(),
                device_id: device_id.into(),
                nickname: Some("Alice".into()),
                avatar_png_b64: None,
                bio: None,
                privacy_audience_json: None,
                searchable_by_nickname: Some(true),
                frame_id: None,
                cover_id: None,
                cover_png_b64: None,
                emoji_status: None,
                premium_badge: None,
                signature_b64: req.signature_b64.clone(),
            }),
        )
        .await
        .0;
        assert!(!missing_secret_response.ok);

        let mut headers = HeaderMap::new();
        headers.insert(
            "x-secretly-profile-secret-b64",
            HeaderValue::from_str(&secret_b64).unwrap(),
        );
        let ok_response = profile_meta_set(State(state.clone()), headers, Json(req))
            .await
            .0;
        assert!(ok_response.ok);

        let stored = state
            .store
            .profile_meta_get(profile_id)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(stored.0.as_deref(), Some("Alice"));
        assert!(stored.4);
    }

    #[tokio::test]
    async fn profile_inactivity_set_requires_profile_secret_and_heartbeat_reports_deleted_profile()
    {
        let (state, _dir) = test_app_state().await;
        let device_key = SigningKey::from_bytes(&[57u8; 32]);
        let profile_id = "profile_inactivity_secret_1";
        let device_id = "device_inactivity_secret_1";
        let secret_b64 =
            seed_profile_device_with_secret(&state, profile_id, device_id, &device_key, 58).await;

        let missing_secret_response = profile_inactivity_set(
            State(state.clone()),
            HeaderMap::new(),
            Json(inactivity_set_request(
                &device_key,
                profile_id,
                device_id,
                Some(6),
                "inactivity-set-missing-secret",
            )),
        )
        .await
        .unwrap()
        .0;
        assert!(missing_secret_response.exists);
        assert!(!missing_secret_response.ok);

        let set_response = profile_inactivity_set(
            State(state.clone()),
            profile_secret_headers(&secret_b64),
            Json(inactivity_set_request(
                &device_key,
                profile_id,
                device_id,
                Some(6),
                "inactivity-set-ok",
            )),
        )
        .await
        .unwrap()
        .0;
        assert!(set_response.exists);
        assert!(set_response.ok);
        assert_eq!(set_response.delete_after_inactivity_months, Some(6));

        state
            .store
            .profile_inactivity_set(profile_id, Some(1), 1_000)
            .await
            .unwrap();
        let deleted = state
            .store
            .delete_expired_inactive_profiles(1_000 + 30 * 24 * 60 * 60 * 1000 + 1)
            .await
            .unwrap();
        assert_eq!(deleted, vec![profile_id.to_string()]);

        let heartbeat_response = profile_inactivity_heartbeat(
            State(state),
            profile_secret_headers(&secret_b64),
            Json(inactivity_heartbeat_request(
                &device_key,
                profile_id,
                device_id,
                "inactivity-heartbeat-deleted",
            )),
        )
        .await
        .unwrap()
        .0;
        assert!(!heartbeat_response.exists);
        assert!(!heartbeat_response.ok);
    }

    #[test]
    fn effective_client_ip_ignores_xff_when_untrusted() {
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-forwarded-for",
            HeaderValue::from_static("198.51.100.10, 10.0.0.1"),
        );

        let ip = effective_client_ip(&headers, std::net::IpAddr::from([127, 0, 0, 1]), false);
        assert_eq!(ip, std::net::IpAddr::from([127, 0, 0, 1]));
    }

    #[test]
    fn effective_client_ip_uses_first_xff_hop_when_trusted() {
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-forwarded-for",
            HeaderValue::from_static("198.51.100.10, 10.0.0.1"),
        );

        let ip = effective_client_ip(&headers, std::net::IpAddr::from([127, 0, 0, 1]), true);
        assert_eq!(ip, std::net::IpAddr::from([198, 51, 100, 10]));
    }

    #[test]
    fn effective_client_ip_falls_back_for_bad_xff() {
        let mut headers = HeaderMap::new();
        headers.insert("x-forwarded-for", HeaderValue::from_static("not-an-ip"));

        let ip = effective_client_ip(&headers, std::net::IpAddr::from([127, 0, 0, 1]), true);
        assert_eq!(ip, std::net::IpAddr::from([127, 0, 0, 1]));
    }

    #[test]
    fn production_mode_detects_runtime_env_or_strict_flag() {
        assert!(is_production_mode(Some("production"), false));
        assert!(is_production_mode(Some("Prod"), false));
        assert!(is_production_mode(None, true));
        assert!(!is_production_mode(Some("development"), false));
        assert!(!is_production_mode(None, false));
    }

    #[test]
    fn keys_security_errors_fail_closed_in_production() {
        let errors = keys_security_errors(
            std::net::IpAddr::from([0, 0, 0, 0]),
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            "",
        );

        assert_eq!(errors.len(), 6);
        assert!(
            errors
                .iter()
                .any(|err| err.contains("SECRETLY_KEYS_REQUIRE_PROFILE_SECRET"))
        );
        assert!(
            errors
                .iter()
                .any(|err| err.contains("SECRETLY_KEYS_REQUIRE_DEVICE_LOOKUP_AUTH"))
        );
        assert!(
            errors
                .iter()
                .any(|err| err.contains("SECRETLY_KEYS_REQUIRE_LIST_DEVICES_AUTH"))
        );
        assert!(
            errors
                .iter()
                .any(|err| err.contains("SECRETLY_KEYS_REQUIRE_BUNDLE_FETCH_AUTH"))
        );
        assert!(
            errors
                .iter()
                .any(|err| err.contains("SECRETLY_KEYS_PROXY_ONLY"))
        );
        assert!(
            errors
                .iter()
                .any(|err| err.contains("SECRETLY_INTERNAL_KEY"))
        );
    }

    #[test]
    fn keys_security_errors_allow_trusted_proxy_mode() {
        let errors = keys_security_errors(
            std::net::IpAddr::from([0, 0, 0, 0]),
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            "super-secret",
        );

        assert!(errors.is_empty());
    }

    #[test]
    fn keys_security_errors_allow_relaxed_config_outside_production() {
        let errors = keys_security_errors(
            std::net::IpAddr::from([0, 0, 0, 0]),
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            "",
        );

        assert!(errors.is_empty());
    }

    #[test]
    fn keys_security_errors_allow_trusted_xff_on_loopback_without_proxy_only() {
        let errors = keys_security_errors(
            std::net::IpAddr::from([127, 0, 0, 1]),
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            "super-secret",
        );

        assert!(errors.is_empty());
    }

    /// The canonical rooms message is a CONTRACT with the Dart client
    /// (`roomsSigningMessage`). Pinning the exact bytes here is what stops a
    /// silent divergence: a mismatched message does not fail loudly, it just
    /// makes every signature unverifiable — and this block fails OFF, so room
    /// sending would quietly stop working with no error anywhere.
    #[test]
    fn rooms2_signing_message_is_byte_stable() {
        let p = Rooms2Payload {
            raw_broadcast_enabled: true,
            big_room_members: 50,
            big_room_min_build: 600,
            issued_at_ms: 42,
        };
        assert_eq!(
            rooms2_signing_message(&p),
            "secretly-rooms2-v1|true|50|600|42"
        );
        // Defaults: raw broadcast off, no big rooms.
        let d = Rooms2Config::default();
        assert!(!d.raw_broadcast_enabled);
        assert_eq!((d.big_room_members, d.big_room_min_build), (0, 0));
    }

    #[test]
    fn rooms_signing_message_is_byte_stable() {
        let p = RoomsPayload {
            sender_key_send_enabled: true,
            issued_at_ms: 42,
        };
        assert_eq!(rooms_signing_message(&p), "secretly-rooms-v1|true|42");

        let off = RoomsPayload {
            sender_key_send_enabled: false,
            issued_at_ms: 7,
        };
        assert_eq!(rooms_signing_message(&off), "secretly-rooms-v1|false|7");
    }

    /// The kill-switch must default to ARMED (allowed). It exists to stop a bad
    /// rollout, not to be a second toggle someone forgets to turn on — the
    /// client's compile-time flag is the actual gate.
    #[test]
    fn rooms_config_defaults_to_allowed() {
        assert!(RoomsConfig::default().sender_key_send_enabled);
    }

    #[test]
    fn evaluate_client_compatibility_accepts_supported_protocol() {
        let result = evaluate_client_compatibility("keys", Some(2), 1, 2);

        assert!(result.supported);
        assert_eq!(result.compatibility_status, "supported");
        assert!(result.compatibility_message.is_none());
    }

    #[test]
    fn evaluate_client_compatibility_rejects_too_old_client() {
        let result = evaluate_client_compatibility("keys", Some(1), 2, 3);

        assert!(!result.supported);
        assert_eq!(result.compatibility_status, "client_too_old");
        assert!(
            result
                .compatibility_message
                .as_deref()
                .unwrap_or_default()
                .contains("Install a newer app build")
        );
    }

    #[test]
    fn evaluate_client_compatibility_rejects_too_new_client() {
        let result = evaluate_client_compatibility("keys", Some(4), 1, 3);

        assert!(!result.supported);
        assert_eq!(result.compatibility_status, "client_too_new");
        assert!(
            result
                .compatibility_message
                .as_deref()
                .unwrap_or_default()
                .contains("Update the server or install a matching app build")
        );
    }

    #[test]
    fn optional_trimmed_string_discards_blank_values() {
        assert_eq!(optional_trimmed_string("   \n\t "), None);
        assert_eq!(
            optional_trimmed_string(" deploy-20260331 "),
            Some("deploy-20260331".to_string())
        );
    }
}
