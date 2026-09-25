// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
use axum::extract::DefaultBodyLimit;
use axum::http::{HeaderMap, HeaderValue, header};
use axum::{
    Json, Router,
    body::Body,
    extract::{
        ConnectInfo, Path, Query, State,
        ws::{CloseCode, CloseFrame, Message, WebSocket, WebSocketUpgrade},
    },
    http::{Request, StatusCode},
    middleware,
    response::IntoResponse,
    routing::{get, post},
};
use base64::Engine as _;
use dashmap::DashMap;
use ed25519_dalek::{Signature, VerifyingKey};
use futures_util::{SinkExt, StreamExt};
use hmac::{Hmac, Mac};
use jsonwebtoken::{Algorithm, EncodingKey, Header};
use reqwest::Client as HttpClient;
use serde::{Deserialize, Serialize};
use sha1::Sha1;
use sha2::{Digest, Sha256};
use std::{
    collections::{BTreeMap, BTreeSet},
    env,
    net::SocketAddr,
    path::PathBuf,
    sync::{
        Arc,
        atomic::{AtomicI64, Ordering},
    },
    time::{Duration, Instant},
};
use tokio::io::AsyncWriteExt;
use tokio::sync::{Mutex, mpsc};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use uuid::Uuid;

mod cosmetics_catalog;
mod sticker_catalog;
mod store;
use cosmetics_catalog::CosmeticsCatalogDocument;
use sticker_catalog::StickerCatalogDocument;
use store::{
    AdmitRoomMessageError, CallSignalRecord, CreateRoomError, CreateRoomInviteLinkError,
    DeleteRoomError, DeviceActivityRow, LeaveRoomError, PendingRow, PushTokenRow,
    RedeemRoomInviteError, RelayStore,
    RoomCallControlError, RoomCallMediaHealthSummary, RoomCallMediaParticipantRow,
    RoomCallParticipantRow, RoomCallRow, RoomCallSnapshot, RoomInviteLinkRow, RoomMembershipRow,
    RoomRow, SetRoomInviteLinkRevokedError, SetRoomMemberTagError, SetRoomPinnedMessageError,
    TransferRoomOwnershipError, UnbanRoomMembershipError, UpdateRoomStateError,
    UpsertRoomMembershipError,
};

type HmacSha1 = Hmac<Sha1>;

const STICKER_CATALOG_SIGNATURE_HEADER: &str = "x-secretly-sticker-catalog-signature-b64";
const STICKER_CATALOG_SIGNING_PUBLIC_KEY_B64: &str = "rDfK+tfKZg3/1YFDjuX+cp0KBZAS4D0qvZuE6Pee3ag=";
// Premium cosmetics (profile icons + chat wallpapers). Dedicated Ed25519
// signing keypair (private seed in ops/secrets/cosmetics_catalog_signing.*,
// signed by tools/cosmetics_catalog_admin.dart).
const COSMETICS_CATALOG_SIGNATURE_HEADER: &str = "x-secretly-cosmetics-catalog-signature-b64";
const COSMETICS_CATALOG_SIGNING_PUBLIC_KEY_B64: &str =
    "wVglSPPCfQ+r+rF0LzoDSxT+n3ewDCVFzfsQoMDuevw=";
const COSMETICS_CATALOG_DEFAULT_RAW_JSON: &str =
    "{\"schema_version\":1,\"generated_at_ms\":0,\"items\":[]}";
const COSMETICS_CATALOG_DEFAULT_SIGNATURE_B64: &str = "";
const STICKER_CATALOG_DEFAULT_RAW_JSON: &str =
    r#"{"schema_version":1,"generated_at_ms":0,"packs":[]}"#;
const STICKER_CATALOG_DEFAULT_SIGNATURE_B64: &str =
    "YUVmImTPVe1yn8O8j+1dOAjEX8KLjm/nmzLmrHGxEcD8l4VW5MXpLNzVzZ4j7ibLzVxWLk3w1d9sriXXQSMxDQ==";
const RELAY_HTTP_BODY_LIMIT_BYTES: usize = 25 * 1024 * 1024;
const RELAY_MAX_BLOB_BYTES: u64 = 1024 * 1024 * 1024;
// Attachments stream through /v1/blob/upload, which bypasses the buffered HTTP
// body limit, so the real attachment ceiling is the blob cap (not the inline
// message-body limit). /health reports this; the client clamps it by the
// per-tier entitlement (free stays 25 MB, premium up to this cap). The relay
// also enforces the per-tier ceiling server-side in http_blob_upload.
const RELAY_MAX_ATTACHMENT_BYTES: i64 = RELAY_MAX_BLOB_BYTES as i64;

// Server-side WebSocket keepalive. We send a WS-level Ping frame every
// WS_HEARTBEAT_INTERVAL and assume the channel is dead if no Pong arrives
// within WS_HEARTBEAT_TIMEOUT. Prevents zombie connections from being
// considered "online" by the realtime delivery path — see
// docs/MESSAGE_DELIVERY_AUDIT_2026-05-28.md §10.1 R2.
const WS_HEARTBEAT_INTERVAL_SECS: u64 = 30;
const WS_HEARTBEAT_TIMEOUT_MS: i64 = 90_000;

// Sprint 2 R3: device staleness threshold. A device is considered live if
// `now - max(last_pump_at_ms, last_push_delivered_at_ms) <= DEVICE_STALENESS_THRESHOLD_MS`.
// 30 days matches the audit recommendation and provides ~3-4× the FCM /
// APNs token rotation cycle, so a legitimate-but-quiet device has ample
// time to bump its activity timestamp before being filtered.
const DEVICE_STALENESS_THRESHOLD_MS: i64 = 30 * 24 * 60 * 60 * 1000;

// Sprint 2 R4: inactive-device cleanup threshold. Strictly longer than
// the R3 staleness threshold so a device is first quietly hidden from
// peer fanout (R3) for a 60-day grace window before any physical
// `push_tokens` / `device_activity` row is deleted (R4). See
// docs/RESTORE_SAFETY_CONTRACT_2026-05-28.md INV-5.
const DEVICE_INACTIVE_CLEANUP_THRESHOLD_MS: i64 = 90 * 24 * 60 * 60 * 1000;

// Sprint 2 R4: cleanup loop tick interval. Default 24 hours. The actual
// value is read from `RELAY_INACTIVE_DEVICE_CLEANUP_INTERVAL_SECS` and
// clamped to a sane range so a typo can't put us in a hot loop.
const DEVICE_CLEANUP_INTERVAL_DEFAULT_SECS: u64 = 24 * 60 * 60;
const DEVICE_CLEANUP_INTERVAL_MIN_SECS: u64 = 60 * 60; // 1 h
const DEVICE_CLEANUP_INTERVAL_MAX_SECS: u64 = 7 * 24 * 60 * 60; // 7 d
const DEVICE_CLEANUP_BATCH_LIMIT: usize = 500;

/// Sprint 2 R3 feature flag — returns `true` iff the operator has
/// explicitly opted into the staleness filter via
/// `RELAY_DEVICE_STALENESS_FILTER_ENABLED=true`. Default is OFF for
/// safe rollout (see docs/RESTORE_SAFETY_CONTRACT_2026-05-28.md INV-4).
fn device_staleness_filter_enabled() -> bool {
    matches!(
        env::var("RELAY_DEVICE_STALENESS_FILTER_ENABLED")
            .ok()
            .as_deref(),
        Some("1") | Some("true") | Some("TRUE") | Some("yes") | Some("YES")
    )
}

/// Sprint 2 R4 feature flag — returns `true` iff the operator has
/// explicitly opted into physical device cleanup via
/// `RELAY_INACTIVE_DEVICE_CLEANUP_ENABLED=true`. Default OFF.
fn device_cleanup_enabled() -> bool {
    matches!(
        env::var("RELAY_INACTIVE_DEVICE_CLEANUP_ENABLED")
            .ok()
            .as_deref(),
        Some("1") | Some("true") | Some("TRUE") | Some("yes") | Some("YES")
    )
}

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
    service: &'static str,
    require_auth: bool,
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
    max_attachment_bytes: i64,
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

#[derive(Debug, Clone, PartialEq, Eq)]
struct CallReadinessSummary {
    calls_ready: bool,
    requested_policy: String,
    effective_policy: String,
    stun_server_count: usize,
    turn_server_count: usize,
    turn_credentials_ready: bool,
}

#[derive(Serialize)]
struct CallHealthResponse {
    status: &'static str,
    service: &'static str,
    calls_ready: bool,
    requested_policy: String,
    effective_policy: String,
    stun_server_count: usize,
    turn_server_count: usize,
    turn_credentials_ready: bool,
    deployment_id: Option<String>,
    release_channel: Option<String>,
    service_started_at_ms: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct RoomMediaReadinessSummary {
    room_media_ready: bool,
    ice_ready: bool,
    runtime_registration_complete: bool,
    session_auth_ready: bool,
    requested_backend: String,
    effective_backend: String,
    backend_url_configured: bool,
    token_issuer_ready: bool,
    requested_policy: String,
    effective_policy: String,
    stun_server_count: usize,
    turn_server_count: usize,
    turn_credentials_ready: bool,
    active_room_call_count: i64,
    joined_room_call_participant_count: i64,
    registered_room_media_participant_count: i64,
    fully_registered_room_call_count: i64,
}

#[derive(Serialize)]
struct RoomMediaHealthResponse {
    status: &'static str,
    service: &'static str,
    room_media_ready: bool,
    ice_ready: bool,
    runtime_registration_complete: bool,
    session_auth_ready: bool,
    requested_backend: String,
    effective_backend: String,
    backend_url_configured: bool,
    token_issuer_ready: bool,
    requested_policy: String,
    effective_policy: String,
    stun_server_count: usize,
    turn_server_count: usize,
    turn_credentials_ready: bool,
    active_room_call_count: i64,
    joined_room_call_participant_count: i64,
    registered_room_media_participant_count: i64,
    fully_registered_room_call_count: i64,
    deployment_id: Option<String>,
    release_channel: Option<String>,
    service_started_at_ms: i64,
}

#[derive(Serialize)]
struct PushHealthResponse {
    status: &'static str,
    service: &'static str,
    push_ready: bool,
    fcm_v1_configured: bool,
    fcm_legacy_configured: bool,
    apns_voip_configured: bool,
    android_push_ready: bool,
    ios_push_ready: bool,
    ios_voip_push_ready: bool,
    push_tokens_total: i64,
    push_tokens_android: i64,
    push_tokens_ios: i64,
    push_tokens_ios_voip: i64,
    push_tokens_unsupported: i64,
    push_tokens_updated_last_24h: i64,
    apns_environment: Option<String>,
    apns_environment_fallback_enabled: Option<bool>,
    apns_voip_topic: Option<String>,
    deployment_id: Option<String>,
    release_channel: Option<String>,
    service_started_at_ms: i64,
}

async fn health(
    State(state): State<AppState>,
    Query(query): Query<HealthQuery>,
) -> impl IntoResponse {
    let server_protocol_version = relay_server_protocol_version();
    let min_client_protocol_version = relay_min_client_protocol_version();
    let max_client_protocol_version =
        relay_max_client_protocol_version(min_client_protocol_version, server_protocol_version);
    let compatibility = evaluate_client_compatibility(
        "relay",
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
        service: "relay",
        require_auth: state.require_auth,
        server_protocol_version,
        min_client_protocol_version,
        max_client_protocol_version,
        client_protocol_version: query.client_protocol_version,
        compatibility_status: compatibility.compatibility_status,
        compatibility_message: compatibility.compatibility_message,
        deployment_id: optional_trimmed_string(state.deployment_id.as_ref().as_str()),
        release_channel: optional_trimmed_string(state.release_channel.as_ref().as_str()),
        service_started_at_ms: state.service_started_at_ms,
        max_request_body_bytes: RELAY_HTTP_BODY_LIMIT_BYTES as i64,
        max_attachment_bytes: RELAY_MAX_ATTACHMENT_BYTES,
    };
    (status_code, Json(body))
}

fn summarize_call_ice_readiness(cfg: &RelayCallIceRuntimeConfig) -> CallReadinessSummary {
    let requested_policy = normalize_call_ice_policy(&cfg.policy);
    let turn_credentials_ready =
        !cfg.turn_urls.is_empty() && !cfg.turn_shared_secret.trim().is_empty();
    let calls_ready = turn_credentials_ready;
    CallReadinessSummary {
        calls_ready,
        requested_policy: requested_policy.clone(),
        effective_policy: effective_call_ice_policy(&requested_policy, turn_credentials_ready),
        stun_server_count: cfg.stun_urls.len(),
        turn_server_count: cfg.turn_urls.len(),
        turn_credentials_ready,
    }
}

async fn call_health(State(state): State<AppState>) -> impl IntoResponse {
    let summary = summarize_call_ice_readiness(state.call_ice.as_ref());
    let status = if summary.calls_ready {
        StatusCode::OK
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    };
    let body = CallHealthResponse {
        status: if summary.calls_ready {
            "ok"
        } else {
            "degraded"
        },
        service: "relay",
        calls_ready: summary.calls_ready,
        requested_policy: summary.requested_policy,
        effective_policy: summary.effective_policy,
        stun_server_count: summary.stun_server_count,
        turn_server_count: summary.turn_server_count,
        turn_credentials_ready: summary.turn_credentials_ready,
        deployment_id: optional_trimmed_string(state.deployment_id.as_ref().as_str()),
        release_channel: optional_trimmed_string(state.release_channel.as_ref().as_str()),
        service_started_at_ms: state.service_started_at_ms,
    };
    (status, Json(body))
}

async fn push_health(State(state): State<AppState>) -> impl IntoResponse {
    let fcm_v1_configured = state.fcm_v1.is_some();
    let fcm_legacy_configured = !state.fcm_legacy_server_key.trim().is_empty();
    let apns_voip_configured = state.apns_voip.is_some();
    let push_ready = fcm_v1_configured || fcm_legacy_configured;
    let ios_voip_push_ready = apns_voip_configured;
    let apns_voip = state.apns_voip.as_ref().as_ref();
    let stats = state
        .store
        .push_token_stats(now_ms())
        .await
        .unwrap_or_default();
    let body = PushHealthResponse {
        status: if push_ready { "ok" } else { "degraded" },
        service: "relay_push",
        push_ready,
        fcm_v1_configured,
        fcm_legacy_configured,
        apns_voip_configured,
        android_push_ready: push_ready,
        ios_push_ready: push_ready && fcm_v1_configured,
        ios_voip_push_ready,
        push_tokens_total: stats.total,
        push_tokens_android: stats.android,
        push_tokens_ios: stats.ios,
        push_tokens_ios_voip: stats.ios_voip,
        push_tokens_unsupported: stats.unsupported,
        push_tokens_updated_last_24h: stats.updated_last_24h,
        apns_environment: apns_voip.map(|config| config.environment.clone()),
        apns_environment_fallback_enabled: apns_voip
            .map(|config| config.allow_environment_fallback),
        apns_voip_topic: apns_voip.map(|config| config.topic.clone()),
        deployment_id: optional_trimmed_string(state.deployment_id.as_ref().as_str()),
        release_channel: optional_trimmed_string(state.release_channel.as_ref().as_str()),
        service_started_at_ms: state.service_started_at_ms,
    };
    (StatusCode::OK, Json(body))
}

fn summarize_room_media_readiness(
    call_summary: &CallReadinessSummary,
    media_summary: &RoomCallMediaHealthSummary,
    room_media_config: &RelayRoomMediaRuntimeConfig,
) -> RoomMediaReadinessSummary {
    let runtime_registration_complete = media_summary.joined_room_call_participant_count
        == media_summary.registered_room_media_participant_count
        && media_summary.active_room_call_count == media_summary.fully_registered_room_call_count;
    let session_auth_ready = room_media_config.session_auth_ready();
    RoomMediaReadinessSummary {
        room_media_ready: call_summary.calls_ready
            && runtime_registration_complete
            && session_auth_ready,
        ice_ready: call_summary.calls_ready,
        runtime_registration_complete,
        session_auth_ready,
        requested_backend: room_media_config.requested_backend.as_str().to_string(),
        effective_backend: room_media_config.effective_backend.as_str().to_string(),
        backend_url_configured: room_media_config.backend_url_configured(),
        token_issuer_ready: room_media_config.token_issuer_ready(),
        requested_policy: call_summary.requested_policy.clone(),
        effective_policy: call_summary.effective_policy.clone(),
        stun_server_count: call_summary.stun_server_count,
        turn_server_count: call_summary.turn_server_count,
        turn_credentials_ready: call_summary.turn_credentials_ready,
        active_room_call_count: media_summary.active_room_call_count,
        joined_room_call_participant_count: media_summary.joined_room_call_participant_count,
        registered_room_media_participant_count: media_summary
            .registered_room_media_participant_count,
        fully_registered_room_call_count: media_summary.fully_registered_room_call_count,
    }
}

async fn room_media_health(State(state): State<AppState>) -> impl IntoResponse {
    let call_summary = summarize_call_ice_readiness(state.call_ice.as_ref());
    let media_summary = match state.store.summarize_room_call_media_health().await {
        Ok(summary) => summary,
        Err(err) => return (StatusCode::INTERNAL_SERVER_ERROR, err).into_response(),
    };
    let summary =
        summarize_room_media_readiness(&call_summary, &media_summary, state.room_media.as_ref());
    let status = if summary.room_media_ready {
        StatusCode::OK
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    };
    let body = RoomMediaHealthResponse {
        status: if summary.room_media_ready {
            "ok"
        } else {
            "degraded"
        },
        service: "relay",
        room_media_ready: summary.room_media_ready,
        ice_ready: summary.ice_ready,
        runtime_registration_complete: summary.runtime_registration_complete,
        session_auth_ready: summary.session_auth_ready,
        requested_backend: summary.requested_backend,
        effective_backend: summary.effective_backend,
        backend_url_configured: summary.backend_url_configured,
        token_issuer_ready: summary.token_issuer_ready,
        requested_policy: summary.requested_policy,
        effective_policy: summary.effective_policy,
        stun_server_count: summary.stun_server_count,
        turn_server_count: summary.turn_server_count,
        turn_credentials_ready: summary.turn_credentials_ready,
        active_room_call_count: summary.active_room_call_count,
        joined_room_call_participant_count: summary.joined_room_call_participant_count,
        registered_room_media_participant_count: summary.registered_room_media_participant_count,
        fully_registered_room_call_count: summary.fully_registered_room_call_count,
        deployment_id: optional_trimmed_string(state.deployment_id.as_ref().as_str()),
        release_channel: optional_trimmed_string(state.release_channel.as_ref().as_str()),
        service_started_at_ms: state.service_started_at_ms,
    };
    (status, Json(body)).into_response()
}

/// Что мы уже сделали для устройства — для схлопывания пачки пробуждений.
///
/// 🔴 ДВА ПОЛЯ, А НЕ ОДНО. «Телефон разбудили» и «человеку сказали» — разные
/// факты. В доказанной ленте 10.08 пачка шла так: тихое лечение сессии, затем
/// два чат-пробуждения с баннером. Схлопывание по одному полю оставило бы
/// ПЕРВОЕ, то есть тихое, и человек не получил бы уведомления вовсе —
/// «лишние уведомления» превратились бы в «сообщения приходят молча».
#[derive(Clone, Copy, Debug, Default)]
struct WakeCoalesceMark {
    /// Когда устройству в последний раз УСПЕШНО ушло любое пробуждение.
    last_wake_at_ms: i64,
    /// Когда в последний раз УСПЕШНО ушло пробуждение С БАННЕРОМ.
    last_announced_at_ms: i64,
}

#[derive(Clone)]
struct AppState {
    store: Arc<RelayStore>,
    conns: Arc<DashMap<String, mpsc::UnboundedSender<Message>>>,
    /// Отметки схлопывания пробуждений, по устройству.
    ///
    /// 🔴 НАМЕРЕННО В ПАМЯТИ, А НЕ В БАЗЕ. Потеря отметки при перезапуске реле
    /// стоит одного ЛИШНЕГО пуша, а не потерянного сообщения — то есть сбой
    /// уводит в безопасную сторону. Хранить это в базе значило бы добавить
    /// запись на каждый пуш ради экономии, которая и так почти всегда не нужна.
    wake_coalesce: Arc<DashMap<String, WakeCoalesceMark>>,
    blobs_dir: Arc<PathBuf>,
    sticker_catalog_dir: Arc<PathBuf>,
    cosmetics_dir: Arc<PathBuf>,
    limiter: Arc<IpRateLimiter>,
    /// AUD-080: per-invite-slug bucket. Slows down probing of a single
    /// well-known slug, even when the caller rotates devices / IPs.
    invite_redeem_slug_limiter: Arc<StringKeyRateLimiter>,
    /// AUD-080: per-caller bucket keyed by authenticated device id.
    /// Limits how fast one device can try many different slugs.
    invite_redeem_caller_limiter: Arc<StringKeyRateLimiter>,
    max_msg_ttl_seconds: u32,
    /// Срок служебных посылок между устройствами ОДНОГО аккаунта; 0 = выкл.
    /// См. [`own_device_control_ttl`].
    own_device_control_ttl_seconds: u32,
    max_pending_per_device: u64,
    keys_internal_base_url: Arc<String>,
    internal_key: Arc<String>,
    http: HttpClient,
    identity_cache: Arc<DashMap<String, String>>,
    profile_cache: Arc<DashMap<String, String>>,
    used_nonces: Arc<DashMap<String, i64>>,
    push_wake_last_ms: Arc<DashMap<String, i64>>,
    fcm_legacy_server_key: Arc<String>,
    fcm_v1: Arc<Option<FcmV1Config>>,
    apns_voip: Arc<Option<ApnsVoipConfig>>,
    fcm_oauth_cache: Arc<Mutex<Option<FcmOAuthCache>>>,
    apns_jwt_cache: Arc<Mutex<Option<ApnsJwtCache>>>,
    call_ice: Arc<RelayCallIceRuntimeConfig>,
    room_media: Arc<RelayRoomMediaRuntimeConfig>,
    call_sessions: Arc<RelayCallSessionRuntimeConfig>,
    require_auth: bool,
    deployment_id: Arc<String>,
    release_channel: Arc<String>,
    service_started_at_ms: i64,
    // Monetization (TZ-MONETIZE-01 §C-3): server-side enforcement of group
    // count/size + call participant caps. Master flag mirrors the keys
    // `SECRETLY_MONETIZATION_ENABLED`. When false the relay does NOT gate
    // anything (pre-freemium behaviour). Limits are resolved per-profile from
    // the keys entitlements endpoint; any failure fails OPEN (never block).
    monetization_enabled: bool,
    entitlement_cache: Arc<DashMap<String, (i64, RelayEntitlement)>>,
    // К-5 (17.09.2026): a room
    // may grow past its owner's tier cap up to `big_room_members`, but only
    // while EVERY live device of every member (and of the one joining) runs
    // build `big_room_min_build` or newer — the first build that carries a
    // big room safely. 0 in either = the exception is off.
    big_room_members: i64,
    big_room_min_build: i64,
}

/// Per-tier limits resolved for a profile from keys `/v1/profile/{id}/entitlements`.
#[derive(Clone, Debug)]
struct RelayEntitlement {
    owned_groups: i64,
    joined_groups: i64,
    group_members: i64,
    call_participants: i64,
    attachment_bytes: i64,
}

#[derive(Clone)]
struct RelayCallIceRuntimeConfig {
    policy: String,
    stun_urls: Vec<String>,
    turn_urls: Vec<String>,
    turn_shared_secret: String,
    turn_ttl_seconds: u32,
}

#[derive(Clone)]
struct RelayCallSessionRuntimeConfig {
    active_ttl_seconds: u32,
    terminal_ttl_seconds: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum RelayRoomMediaBackendKind {
    Unavailable,
    Livekit,
}

impl RelayRoomMediaBackendKind {
    fn parse(raw: &str) -> Self {
        match raw.trim().to_ascii_lowercase().as_str() {
            "livekit" => Self::Livekit,
            _ => Self::Unavailable,
        }
    }

    fn as_str(self) -> &'static str {
        match self {
            Self::Unavailable => "unavailable",
            Self::Livekit => "livekit",
        }
    }
}

#[derive(Clone)]
struct RelayRoomMediaRuntimeConfig {
    requested_backend: RelayRoomMediaBackendKind,
    effective_backend: RelayRoomMediaBackendKind,
    livekit_url: String,
    livekit_api_key: String,
    livekit_api_secret: String,
    token_ttl_seconds: u32,
}

impl RelayRoomMediaRuntimeConfig {
    fn session_auth_ready(&self) -> bool {
        self.effective_backend == RelayRoomMediaBackendKind::Livekit
    }

    fn backend_url_configured(&self) -> bool {
        !self.livekit_url.trim().is_empty()
    }

    fn token_issuer_ready(&self) -> bool {
        !self.livekit_api_key.trim().is_empty() && !self.livekit_api_secret.trim().is_empty()
    }
}

#[derive(Clone, Deserialize)]
struct FcmServiceAccount {
    project_id: String,
    private_key: String,
    client_email: String,
    token_uri: String,
}

#[derive(Clone)]
struct FcmV1Config {
    project_id: String,
    client_email: String,
    private_key_pem: String,
    token_uri: String,
    scope: String,
    send_url: String,
}

#[derive(Clone)]
struct ApnsVoipConfig {
    team_id: String,
    key_id: String,
    private_key_pem: String,
    topic: String,
    endpoint_base: String,
    environment: String,
    allow_environment_fallback: bool,
}

#[derive(Clone)]
struct FcmOAuthCache {
    access_token: String,
    expires_at_ms: i64,
}

#[derive(Clone)]
struct ApnsJwtCache {
    jwt: String,
    expires_at_ms: i64,
}

#[derive(Serialize)]
struct GoogleJwtClaims<'a> {
    iss: &'a str,
    scope: &'a str,
    aud: &'a str,
    iat: i64,
    exp: i64,
}

#[derive(Serialize)]
struct ApnsJwtClaims<'a> {
    iss: &'a str,
    iat: i64,
}

#[derive(Deserialize)]
struct GoogleTokenResp {
    access_token: String,
    expires_in: i64,
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

/// String-keyed token bucket limiter used for application-level buckets
/// (invite slug, invite caller, etc.). Complements the IP-based limiter by
/// enforcing per-resource and per-principal ceilings regardless of source IP.
///
/// AUD-080: invite redeem path must not be limited only by the global per-IP
/// bucket, otherwise a distributed attacker (or a shared NAT) can brute-force
/// invite slugs anonymously from many IPs. A per-slug bucket rate-limits
/// traffic against any single slug, and a per-caller bucket limits how
/// quickly one authenticated device can probe many distinct slugs.
struct StringKeyRateLimiter {
    buckets: DashMap<String, TokenBucket>,
    capacity: f64,
    refill_per_sec: f64,
}

impl StringKeyRateLimiter {
    fn new(capacity: u32, refill_per_sec: f64) -> Self {
        Self {
            buckets: DashMap::new(),
            capacity: capacity as f64,
            refill_per_sec,
        }
    }

    fn allow(&self, key: &str) -> bool {
        let now = Instant::now();
        let mut entry = self.buckets.entry(key.to_string()).or_insert(TokenBucket {
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
    // Health + static signed catalog endpoints should always be reachable.
    // Catalog ASSET downloads (icons / wallpapers / stickers) are immutable,
    // public, and fetched in legitimate bursts when a picker opens — a 750-icon
    // grid pulls hundreds of small cached thumbnails at once. Exempt them from
    // the per-IP message rate limiter; otherwise the burst trips 429 and the
    // client falls back to placeholder glyphs / blank wallpaper tiles.
    {
        let path = req.uri().path();
        let exempt = path == "/health"
            || path == "/health/calls"
            || path == "/health/room-media"
            || path == "/v1/sticker-catalog/manifest"
            || path == "/v1/cosmetics/manifest"
            || path.starts_with("/v1/cosmetics/assets/")
            || path.starts_with("/v1/sticker-catalog/assets/");
        if exempt {
            return next.run(req).await;
        }
    }

    let trust_xff = std::env::var("SECRETLY_RELAY_TRUST_XFF")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(false);

    // Only safe when Relay is not directly reachable and all traffic passes through a trusted proxy.
    let ip = effective_client_ip(req.headers(), addr.ip(), trust_xff);

    if state.limiter.allow(ip) {
        next.run(req).await
    } else {
        (StatusCode::TOO_MANY_REQUESTS, "rate_limited").into_response()
    }
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ClientMsg {
    Hello {
        device_id: String,
    },
    HelloAuth {
        device_id: String,
        ts_ms: i64,
        nonce_b64: String,
        signature_b64: String,
        /// Номер сборки, СПРАВОЧНО и НЕ ПОДПИСАН — как и одноимённый HTTP-заголовок.
        ///
        /// 🔴 Почему поле появилось (22.08.2026). Активность устройства
        /// отмечается в четырёх местах, три из которых — этот сокет, а версию
        /// писал только HTTP-путь. Сокет-жители отмечались активными и никогда
        /// не называли сборку: 29% парка попадали в «версии нет», и по этой
        /// графе нельзя было отличить необновившегося от обычного пользователя.
        /// Замер раскатки, который не видит треть парка, — не замер.
        ///
        /// Старые клиенты поля не шлют: `default` оставляет их поведение ровно
        /// таким, каким оно было.
        #[serde(default)]
        client_build: Option<String>,
    },
    Send {
        to_device_id: String,
        msg_id: String,
        ciphertext_b64: String,
        transport_meta_json: Option<String>,
        ttl_seconds: u32,
        // SERVER-SIDE SCHEDULED DELIVERY (2026-07-17): epoch-ms release time.
        // Absent / 0 = deliver immediately (every current client). > now =
        // the relay holds the ciphertext and releases it at T, so "send later"
        // survives the SENDER's phone sleeping.
        #[serde(default)]
        deliver_at_ms: Option<i64>,
    },
    Ack {
        device_id: String,
        seq: u64,
        msg_id: String,
    },
    FetchPending {
        device_id: String,
        from_seq: u64,
    },
    Ping,
}

#[derive(Deserialize)]
struct KeysDeviceIdentityResp {
    exists: bool,
    profile_id: Option<String>,
    identity_key_pub_b64: Option<String>,
}

#[derive(Deserialize)]
struct KeysProfileMetaResp {
    exists: bool,
    nickname: Option<String>,
}

#[derive(Deserialize)]
struct KeysEntitlementResp {
    limits: KeysEntitlementLimits,
}

#[derive(Deserialize)]
struct KeysEntitlementLimits {
    owned_groups: i64,
    joined_groups: i64,
    group_members: i64,
    call_participants: i64,
    #[serde(default)]
    attachment_bytes: i64,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct CallTransportMetaBody {
    action: String,
    call_id: String,
    call_attempt_id: String,
    signal_id: String,
    created_at_ms: i64,
    #[serde(default)]
    caller_profile_id: Option<String>,
    #[serde(default)]
    caller_display_name: Option<String>,
    #[serde(default)]
    is_video: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct MessageTransportMetaBody {
    convo_id: String,
    #[serde(default)]
    is_group: bool,
    #[serde(default)]
    category: Option<String>,
    message_kind: String,
    payload_event_id: String,
    created_at_ms: i64,
    #[serde(default)]
    sender_profile_id: Option<String>,
    #[serde(default)]
    sender_display_name: Option<String>,
    #[serde(default)]
    convo_title: Option<String>,
    // 🔴 Приватность (24.09.2026): поля `preview_text` здесь НЕТ намеренно.
    // Приложение кладёт в него начало текста сообщения открытым текстом;
    // реле его не читает, не хранит (`store::strip_transport_meta_preview`)
    // и не отдаёт в push. Неизвестное поле serde пропускает.
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct RoomCallTransportMetaBody {
    room_id: String,
    call_id: Option<String>,
    #[serde(default)]
    state_version: i64,
    #[serde(default)]
    call_exists: bool,
    created_at_ms: i64,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct RoomCallMediaSignalTransportMetaBody {
    action: String,
    room_id: String,
    call_id: String,
    session_id: String,
    #[serde(default)]
    descriptor_version: i64,
    #[serde(default)]
    state_version: i64,
    signal_id: String,
    created_at_ms: i64,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct TransportMetaEnvelope {
    kind: String,
    call: Option<CallTransportMetaBody>,
    room_call: Option<RoomCallTransportMetaBody>,
    room_media_signal: Option<RoomCallMediaSignalTransportMetaBody>,
    message: Option<MessageTransportMetaBody>,
}

#[derive(Debug, Clone)]
struct RoomCallSyncTransportRecord {
    room_id: String,
    call_id: Option<String>,
    state_version: i64,
    call_exists: bool,
    created_at_ms: i64,
}

#[derive(Debug, Clone)]
struct RoomCallMediaSignalTransportRecord {
    action: String,
    room_id: String,
    call_id: String,
    session_id: String,
    descriptor_version: i64,
    state_version: i64,
    signal_id: String,
    created_at_ms: i64,
}

#[derive(Debug, Clone)]
struct MessageTransportMetaRecord {
    convo_id: String,
    is_group: bool,
    message_kind: String,
    payload_event_id: String,
    created_at_ms: i64,
    sender_profile_id: Option<String>,
    sender_display_name: Option<String>,
}

#[derive(Debug, Clone)]
struct CallInvitePushHint {
    is_video: bool,
    call_id: String,
    call_attempt_id: String,
    signal_id: String,
    created_at_ms: i64,
}

#[derive(Serialize, Deserialize, Debug, Clone, Default)]
struct PushQuietHoursWindowWire {
    #[serde(default, alias = "startHour")]
    start_hour: Option<i64>,
    #[serde(default, alias = "endHour")]
    end_hour: Option<i64>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct PushQuietHoursWindowCanonical {
    start_hour: i64,
    end_hour: i64,
}

#[derive(Debug, Clone)]
struct PushQuietHoursWindow {
    start_hour: i64,
    end_hour: i64,
}

#[derive(Serialize, Deserialize, Debug, Clone, Default)]
struct PushPolicySnapshotWire {
    #[serde(default, alias = "global_enabled")]
    notifications_enabled: Option<bool>,
    #[serde(default)]
    direct_messages_enabled: Option<bool>,
    #[serde(default)]
    group_messages_enabled: Option<bool>,
    #[serde(default)]
    incoming_calls_enabled: Option<bool>,
    #[serde(default)]
    message_visual_alerts_enabled: Option<bool>,
    #[serde(default, alias = "direct_privacy_level")]
    direct_message_privacy: Option<i64>,
    #[serde(default, alias = "group_privacy_level")]
    group_message_privacy: Option<i64>,
    #[serde(default, alias = "muted_convo_ids")]
    muted_conversations: Vec<String>,
    #[serde(default)]
    convo_privacy_overrides: BTreeMap<String, i64>,
    #[serde(default)]
    contact_privacy_overrides: BTreeMap<String, i64>,
    #[serde(default, alias = "call_disabled_profile_ids")]
    contact_calls_disabled: Vec<String>,
    #[serde(default, alias = "tz_offset_minutes")]
    timezone_offset_minutes: Option<i64>,
    #[serde(default)]
    convo_quiet_hours: BTreeMap<String, PushQuietHoursWindowWire>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct PushPolicySnapshotCanonical {
    notifications_enabled: bool,
    direct_messages_enabled: bool,
    group_messages_enabled: bool,
    incoming_calls_enabled: bool,
    message_visual_alerts_enabled: bool,
    direct_message_privacy: i64,
    group_message_privacy: i64,
    muted_conversations: Vec<String>,
    convo_privacy_overrides: BTreeMap<String, i64>,
    contact_privacy_overrides: BTreeMap<String, i64>,
    contact_calls_disabled: Vec<String>,
    timezone_offset_minutes: i64,
    convo_quiet_hours: BTreeMap<String, PushQuietHoursWindowCanonical>,
}

#[derive(Debug, Clone)]
struct PushPolicySnapshot {
    notifications_enabled: bool,
    direct_messages_enabled: bool,
    group_messages_enabled: bool,
    incoming_calls_enabled: bool,
    message_visual_alerts_enabled: bool,
    direct_message_privacy: i64,
    group_message_privacy: i64,
    muted_conversations: BTreeSet<String>,
    convo_privacy_overrides: BTreeMap<String, i64>,
    contact_privacy_overrides: BTreeMap<String, i64>,
    contact_calls_disabled: BTreeSet<String>,
    timezone_offset_minutes: i64,
    convo_quiet_hours: BTreeMap<String, PushQuietHoursWindow>,
}

#[derive(Debug, Clone)]
struct PushWakePayload {
    notification_title: String,
    notification_body: String,
    collapse_key: String,
    notification_tag: String,
    include_notification: bool,
    data: serde_json::Map<String, serde_json::Value>,
    // iOS app-icon unread badge. `Some(n)` sets `aps.badge = n`; `None` omits it
    // so the OS leaves the current badge untouched (call/receipt wakes must not
    // stomp the message count).
    badge: Option<u32>,
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

async fn fetch_identity_pub_b64(state: &AppState, device_id: &str) -> Option<String> {
    if !is_valid_id(device_id, 128) {
        return None;
    }
    if let Some(v) = state.identity_cache.get(device_id) {
        return Some(v.value().clone());
    }

    let url = format!(
        "{}/v1/device/{}/identity",
        state.keys_internal_base_url.trim_end_matches('/'),
        device_id
    );

    let mut req = state.http.get(url);
    if !state.internal_key.is_empty() {
        req = req.header("x-secretly-internal-key", state.internal_key.as_str());
    }
    let resp = req.send().await.ok()?;
    if !resp.status().is_success() {
        return None;
    }
    let body: KeysDeviceIdentityResp = resp.json().await.ok()?;
    if !body.exists {
        return None;
    }
    let ik = body.identity_key_pub_b64?;
    if ik.is_empty() {
        return None;
    }
    state
        .identity_cache
        .insert(device_id.to_string(), ik.clone());
    Some(ik)
}

async fn fetch_profile_id(state: &AppState, device_id: &str) -> Option<String> {
    if !is_valid_id(device_id, 128) {
        return None;
    }
    if let Some(v) = state.profile_cache.get(device_id) {
        return Some(v.value().clone());
    }

    let url = format!(
        "{}/v1/device/{}/identity",
        state.keys_internal_base_url.trim_end_matches('/'),
        device_id
    );

    let mut req = state.http.get(url);
    if !state.internal_key.is_empty() {
        req = req.header("x-secretly-internal-key", state.internal_key.as_str());
    }
    let resp = req.send().await.ok()?;
    if !resp.status().is_success() {
        return None;
    }
    let body: KeysDeviceIdentityResp = resp.json().await.ok()?;
    if !body.exists {
        return None;
    }
    let pid = body.profile_id?;
    if pid.is_empty() {
        return None;
    }
    state
        .profile_cache
        .insert(device_id.to_string(), pid.clone());
    Some(pid)
}

async fn fetch_profile_nickname(state: &AppState, profile_id: &str) -> Option<String> {
    if !is_valid_id(profile_id, 128) {
        return None;
    }

    let url = format!(
        "{}/v1/profile/{}/meta",
        state.keys_internal_base_url.trim_end_matches('/'),
        profile_id
    );

    let mut req = state.http.get(url);
    if !state.internal_key.is_empty() {
        req = req.header("x-secretly-internal-key", state.internal_key.as_str());
    }
    let resp = req.send().await.ok()?;
    if !resp.status().is_success() {
        return None;
    }

    let body: KeysProfileMetaResp = resp.json().await.ok()?;
    if !body.exists {
        return None;
    }
    let nick = body.nickname?.trim().to_string();
    if nick.is_empty() {
        return None;
    }
    Some(nick)
}

/// Resolves a profile's monetization limits from the keys entitlements endpoint
/// (internal-key authed). Cached for 60s. Returns None on any failure — callers
/// MUST treat None as fail-open (allow the action). TZ §C-3 / §0.4.
async fn fetch_entitlement(state: &AppState, profile_id: &str) -> Option<RelayEntitlement> {
    if !is_valid_id(profile_id, 128) {
        return None;
    }
    let now = now_ms();
    if let Some(v) = state.entitlement_cache.get(profile_id) {
        let (cached_at, ent) = v.value();
        if now - *cached_at < 60_000 {
            return Some(ent.clone());
        }
    }

    let url = format!(
        "{}/v1/profile/{}/entitlements",
        state.keys_internal_base_url.trim_end_matches('/'),
        profile_id
    );
    let mut req = state.http.get(url);
    if !state.internal_key.is_empty() {
        req = req.header("x-secretly-internal-key", state.internal_key.as_str());
    }
    let resp = req.send().await.ok()?;
    if !resp.status().is_success() {
        return None;
    }
    let body: KeysEntitlementResp = resp.json().await.ok()?;
    let ent = RelayEntitlement {
        owned_groups: body.limits.owned_groups,
        joined_groups: body.limits.joined_groups,
        group_members: body.limits.group_members,
        call_participants: body.limits.call_participants,
        attachment_bytes: body.limits.attachment_bytes,
    };
    state
        .entitlement_cache
        .insert(profile_id.to_string(), (now, ent.clone()));
    Some(ent)
}

/// True when `count` is at/over `limit`. A negative limit = unlimited.
fn over_limit(count: i64, limit: i64) -> bool {
    limit >= 0 && count >= limit
}

/// Enforces the owned-group cap before creating a room. Fails OPEN when
/// monetization is disabled or the entitlement can't be resolved. Existing
/// rooms are grandfathered — this only blocks creating a NEW room past the cap.
async fn enforce_group_create_limit(
    state: &AppState,
    owner_profile_id: &str,
) -> Result<(), (StatusCode, String)> {
    if !state.monetization_enabled {
        return Ok(());
    }
    let Some(ent) = fetch_entitlement(state, owner_profile_id).await else {
        return Ok(()); // fail-open
    };
    if ent.owned_groups < 0 {
        return Ok(());
    }
    let owned = state
        .store
        .count_owned_rooms(owner_profile_id)
        .await
        .unwrap_or(0);
    if over_limit(owned, ent.owned_groups) {
        return Err((
            StatusCode::PAYMENT_REQUIRED,
            "group_create_limit_reached".into(),
        ));
    }
    Ok(())
}

/// Enforces the joined-group cap before adding a NEW active membership for
/// `profile_id`. Fails open; grandfathers existing memberships.
async fn enforce_group_join_limit(
    state: &AppState,
    profile_id: &str,
) -> Result<(), (StatusCode, String)> {
    if !state.monetization_enabled {
        return Ok(());
    }
    let Some(ent) = fetch_entitlement(state, profile_id).await else {
        return Ok(());
    };
    if ent.joined_groups < 0 {
        return Ok(());
    }
    let joined = state
        .store
        .count_active_memberships_for_profile(profile_id)
        .await
        .unwrap_or(0);
    if over_limit(joined, ent.joined_groups) {
        return Err((
            StatusCode::PAYMENT_REQUIRED,
            "group_join_limit_reached".into(),
        ));
    }
    Ok(())
}

/// Enforces the per-group member-size cap (owner's tier governs the room).
/// Fails open; grandfathers rooms already over the cap.
async fn enforce_group_size_limit(
    state: &AppState,
    owner_profile_id: &str,
    room_id: &str,
    joining_profile_id: &str,
) -> Result<(), (StatusCode, String)> {
    if !state.monetization_enabled {
        return Ok(());
    }
    let Some(ent) = fetch_entitlement(state, owner_profile_id).await else {
        return Ok(());
    };
    if ent.group_members < 0 {
        return Ok(());
    }
    let members = state
        .store
        .count_active_room_members(room_id)
        .await
        .unwrap_or(0);
    if over_limit(members, ent.group_members)
        && !big_room_allows(state, room_id, members, joining_profile_id).await
    {
        return Err((
            StatusCode::PAYMENT_REQUIRED,
            "group_member_limit_reached".into(),
        ));
    }
    Ok(())
}

/// Integer setting from the environment; unset or unparsable = `default`.
fn i64_env(name: &str, default: i64) -> i64 {
    env::var(name)
        .ok()
        .and_then(|v| v.trim().parse::<i64>().ok())
        .unwrap_or(default)
}

/// Devices silent this long do not hold a big room back (К-5): a phone left
/// in a drawer on an old build must not freeze a room forever.
const BIG_ROOM_DEVICE_ACTIVE_WINDOW_MS: i64 = 30 * 24 * 60 * 60 * 1000;

/// К-5: may a room that already hit its owner's tier cap take one more member?
/// Only below `big_room_members`, and only when the oldest live device among
/// the members and the newcomer runs `big_room_min_build` or newer. Anything we
/// cannot establish keeps the ordinary ceiling.
async fn big_room_allows(
    state: &AppState,
    room_id: &str,
    members: i64,
    joining_profile_id: &str,
) -> bool {
    if state.big_room_members <= 0 || state.big_room_min_build <= 0 {
        return false;
    }
    if members >= state.big_room_members {
        return false;
    }
    let Ok(memberships) = state.store.list_room_memberships(room_id).await else {
        return false;
    };
    let mut profiles: Vec<String> = memberships
        .into_iter()
        .filter(|m| m.status == "active")
        .map(|m| m.profile_id)
        .collect();
    let joining = joining_profile_id.trim();
    if !joining.is_empty() {
        profiles.push(joining.to_string());
    }
    match state
        .store
        .oldest_client_build_for_profiles(profiles, now_ms() - BIG_ROOM_DEVICE_ACTIVE_WINDOW_MS)
        .await
    {
        Ok(Some(oldest)) => oldest >= state.big_room_min_build,
        _ => false,
    }
}

/// Enforces the per-call participant cap before a NEW participant joins. The
/// room owner's tier governs the call. Fails open; skips when the requester is
/// already in the call (rejoin) and when no active call exists yet.
async fn enforce_call_participant_limit(
    state: &AppState,
    room_id: &str,
    requester_profile_id: &str,
) -> Result<(), (StatusCode, String)> {
    if !state.monetization_enabled {
        return Ok(());
    }
    let room = match state.store.get_room(room_id).await {
        Ok(Some(room)) => room,
        _ => return Ok(()), // fail-open
    };
    let Some(ent) = fetch_entitlement(state, &room.owner_profile_id).await else {
        return Ok(());
    };
    if ent.call_participants < 0 {
        return Ok(());
    }
    let snapshot = match state.store.get_active_room_call(room_id, None).await {
        Ok(Some(snapshot)) => snapshot,
        _ => return Ok(()), // no active call yet → first joiner is always fine
    };
    let already_in = snapshot
        .participants
        .iter()
        .any(|p| p.profile_id == requester_profile_id && p.left_at_ms.is_none());
    if already_in {
        return Ok(());
    }
    let active = snapshot
        .participants
        .iter()
        .filter(|p| p.left_at_ms.is_none())
        .count() as i64;
    if over_limit(active, ent.call_participants) {
        return Err((
            StatusCode::PAYMENT_REQUIRED,
            "call_participant_limit_reached".into(),
        ));
    }
    Ok(())
}

fn is_valid_id(s: &str, max_len: usize) -> bool {
    if s.is_empty() || s.len() > max_len {
        return false;
    }
    s.chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
}

fn is_valid_room_id(s: &str, max_len: usize) -> bool {
    if s.is_empty() || s.len() > max_len {
        return false;
    }
    s.chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_' || c == ':')
}

fn is_valid_uuid(s: &str) -> bool {
    Uuid::parse_str(s).is_ok()
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

fn log_optional_fingerprint(value: Option<&str>) -> Option<String> {
    value.map(log_fingerprint)
}

/// One line summarising a mailbox drain — the MIDDLE of a message's life.
///
/// 🔴 WHY (2026-08-01, docs/DELIVERY_AUDIT_2026-08-01.md): the relay already
/// logged both ENDS — `send enqueued` and `ack received` — and nothing between
/// them. When the field asked "when was it offered to her phone and when did
/// she actually take it", `journalctl -u secretly-relay` for the window was
/// EMPTY, and the timeline could not be reconstructed at all. The whole audit
/// had to proceed by inference. This is the cheapest possible fix and it pays
/// for itself on the first incident.
///
/// Per DRAIN, not per message, deliberately: a stuck mailbox is re-offered
/// every 30 s (`REDELIVER_BACKOFF_MS`), and one info line per message would
/// flood the journal exactly when it is most needed. To time a SPECIFIC
/// message, correlate its `msg_ref` across the enqueue and ack lines — the
/// fingerprint is stable, so that is a single grep.
///
/// Silent on an empty mailbox: the overwhelming majority of drains find
/// nothing, and logging those would bury the ones that matter.
///
/// Privacy: ids go through [`log_fingerprint`] (sha256 prefix + length, the
/// same redaction every other id in this journal uses); ciphertext, plaintext
/// and push payloads never appear.
fn log_mailbox_drain(transport: &str, device_id: &str, rows: &[PendingRow], now_ms: i64) {
    if rows.is_empty() {
        return;
    }
    // How long the most-neglected row in this batch has gone since it was last
    // offered. THE number the audit needed: ~0 means mail is flowing, and a
    // large value means this mailbox has been sitting unacked that long.
    //
    // 🔴 TRAP, caught by the test before this shipped: `last_attempt_ms` is NOT
    // "0 until first offered" — `enqueue` deliberately stamps it with the
    // enqueue time and counts that as attempt #1 (store.rs, "Count enqueue as
    // the first delivery attempt"). So this column cannot separate a first
    // offer from a re-offer, and any count built on `last_attempt_ms > 0` reads
    // 100% re-offers on a perfectly healthy mailbox. Age is the honest reading;
    // a first-offer count would have been a confident lie in the journal, which
    // is worse than the silence this replaces. Legacy pre-migration rows carry
    // 0 and are skipped rather than reported as decades old.
    let longest_wait_ms = rows
        .iter()
        .filter(|r| r.last_attempt_ms > 0)
        .map(|r| now_ms.saturating_sub(r.last_attempt_ms))
        .max()
        .unwrap_or(0);
    // The soonest TTL in this batch: how long until the relay drops the oldest
    // message for good. Visible BEFORE the loss, not reconstructed after it.
    let expires_in_ms = rows
        .iter()
        .map(|r| r.expires_at_ms.saturating_sub(now_ms))
        .min()
        .unwrap_or(0);
    tracing::info!(
        transport = %transport,
        device_ref = %log_fingerprint(device_id),
        count = rows.len(),
        longest_wait_ms = longest_wait_ms,
        soonest_expiry_in_ms = expires_in_ms,
        "mailbox drained"
    );
}

// NB: the two REALTIME hand-off paths (`ws delivered realtime` /
// `http delivered realtime`, plus their failure and offline twins) were
// already logged per message and are left exactly as they were. The hole was
// only ever the DRAIN paths above — which is precisely the path a woken-but-
// backgrounded phone takes, and therefore the one the field case ran through.

fn log_body_summary(value: &str) -> String {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return "empty".into();
    }
    format!("len={}, ref={}", trimmed.len(), log_fingerprint(trimmed))
}

fn normalize_room_title(title: &str) -> Result<String, (StatusCode, String)> {
    let normalized = title.trim();
    if normalized.is_empty() || normalized.chars().count() > 120 {
        return Err((StatusCode::BAD_REQUEST, "bad room title".into()));
    }
    if normalized.chars().any(|c| c.is_control()) {
        return Err((StatusCode::BAD_REQUEST, "bad room title".into()));
    }
    Ok(normalized.to_string())
}

fn parse_call_signal_transport_meta(
    transport_meta_json: Option<&str>,
) -> Result<Option<CallSignalRecord>, String> {
    let Some(raw) = transport_meta_json.map(str::trim).filter(|v| !v.is_empty()) else {
        return Ok(None);
    };
    if raw.len() > 4096 {
        return Err("transport_meta_json too large".into());
    }

    let envelope: TransportMetaEnvelope =
        serde_json::from_str(raw).map_err(|_| "bad transport_meta_json".to_string())?;
    if envelope.kind != "call_signal_v1" {
        return Ok(None);
    }

    let call = envelope
        .call
        .ok_or_else(|| "missing call metadata".to_string())?;
    let action = call.action.trim().to_lowercase();
    if !matches!(
        action.as_str(),
        "invite" | "decline" | "hangup" | "offer" | "answer" | "ice" | "need_offer"
    ) {
        return Err("bad call transport action".into());
    }
    if !is_valid_id(&call.call_id, 128) {
        return Err("bad call_id".into());
    }
    if !is_valid_id(&call.call_attempt_id, 128) {
        return Err("bad call_attempt_id".into());
    }
    if !is_valid_id(&call.signal_id, 128) {
        return Err("bad signal_id".into());
    }

    Ok(Some(CallSignalRecord {
        action,
        call_id: call.call_id.trim().to_string(),
        call_attempt_id: call.call_attempt_id.trim().to_string(),
        signal_id: call.signal_id.trim().to_string(),
        created_at_ms: call.created_at_ms,
    }))
}

fn parse_room_call_sync_transport_meta(
    transport_meta_json: Option<&str>,
) -> Result<Option<RoomCallSyncTransportRecord>, String> {
    let Some(raw) = transport_meta_json.map(str::trim).filter(|v| !v.is_empty()) else {
        return Ok(None);
    };
    if raw.len() > 4096 {
        return Err("transport_meta_json too large".into());
    }

    let envelope: TransportMetaEnvelope =
        serde_json::from_str(raw).map_err(|_| "bad transport_meta_json".to_string())?;
    if envelope.kind != "room_call_sync_v1" {
        return Ok(None);
    }

    let room_call = envelope
        .room_call
        .ok_or_else(|| "missing room call metadata".to_string())?;
    if !is_valid_room_id(&room_call.room_id, 160) {
        return Err("bad room_id".into());
    }

    let call_id = room_call
        .call_id
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty());
    if let Some(call_id) = call_id.as_deref() {
        if !is_valid_id(call_id, 128) {
            return Err("bad room call_id".into());
        }
    }
    if room_call.call_exists && call_id.is_none() {
        return Err("missing room call_id".into());
    }
    if room_call.state_version < 0 {
        return Err("bad room state_version".into());
    }
    if room_call.created_at_ms < 0 {
        return Err("bad room call created_at_ms".into());
    }

    Ok(Some(RoomCallSyncTransportRecord {
        room_id: room_call.room_id.trim().to_string(),
        call_id,
        state_version: room_call.state_version,
        call_exists: room_call.call_exists,
        created_at_ms: room_call.created_at_ms,
    }))
}

fn parse_room_call_media_signal_transport_meta(
    transport_meta_json: Option<&str>,
) -> Result<Option<RoomCallMediaSignalTransportRecord>, String> {
    let Some(raw) = transport_meta_json.map(str::trim).filter(|v| !v.is_empty()) else {
        return Ok(None);
    };
    if raw.len() > 4096 {
        return Err("transport_meta_json too large".into());
    }

    let envelope: TransportMetaEnvelope =
        serde_json::from_str(raw).map_err(|_| "bad transport_meta_json".to_string())?;
    if envelope.kind != "room_call_media_signal_v1" {
        return Ok(None);
    }

    let room_media_signal = envelope
        .room_media_signal
        .ok_or_else(|| "missing room media signal metadata".to_string())?;
    let action = room_media_signal.action.trim().to_ascii_lowercase();
    if !matches!(action.as_str(), "descriptor_updated") {
        return Err("bad room media signal action".into());
    }
    if !is_valid_room_id(&room_media_signal.room_id, 160) {
        return Err("bad room_id".into());
    }
    if !is_valid_id(&room_media_signal.call_id, 128) {
        return Err("bad room call_id".into());
    }
    if !is_valid_id(&room_media_signal.session_id, 128) {
        return Err("bad room media session_id".into());
    }
    if !is_valid_id(&room_media_signal.signal_id, 128) {
        return Err("bad room media signal_id".into());
    }
    if room_media_signal.descriptor_version < 0 {
        return Err("bad room media descriptor_version".into());
    }
    if room_media_signal.state_version < 0 {
        return Err("bad room media state_version".into());
    }
    if room_media_signal.created_at_ms < 0 {
        return Err("bad room media created_at_ms".into());
    }

    Ok(Some(RoomCallMediaSignalTransportRecord {
        action,
        room_id: room_media_signal.room_id.trim().to_string(),
        call_id: room_media_signal.call_id.trim().to_string(),
        session_id: room_media_signal.session_id.trim().to_string(),
        descriptor_version: room_media_signal.descriptor_version,
        state_version: room_media_signal.state_version,
        signal_id: room_media_signal.signal_id.trim().to_string(),
        created_at_ms: room_media_signal.created_at_ms,
    }))
}

fn normalize_push_text(raw: Option<&str>, max_chars: usize) -> Option<String> {
    let raw = raw?.trim();
    if raw.is_empty() {
        return None;
    }
    let sanitized: String = raw
        .chars()
        .filter(|ch| !ch.is_control() || matches!(ch, '\n' | '\r' | '\t'))
        .collect();
    let normalized = sanitized.split_whitespace().collect::<Vec<_>>().join(" ");
    if normalized.is_empty() {
        return None;
    }
    Some(normalized.chars().take(max_chars).collect())
}

fn normalize_push_convo_id(raw: &str) -> Option<String> {
    let value = raw.trim();
    if is_valid_room_id(value, 160) {
        Some(value.to_string())
    } else {
        None
    }
}

fn normalize_push_profile_id(raw: &str) -> Option<String> {
    let value = raw.trim();
    if is_valid_id(value, 128) {
        Some(value.to_string())
    } else {
        None
    }
}

fn normalize_privacy_level(level: Option<i64>, default_value: i64) -> i64 {
    level.unwrap_or(default_value).clamp(0, 2)
}

fn normalize_timezone_offset_minutes(value: Option<i64>) -> i64 {
    value.unwrap_or(0).clamp(-24 * 60, 24 * 60)
}

fn normalize_quiet_hour(value: Option<i64>, default_value: i64) -> i64 {
    value.unwrap_or(default_value).clamp(0, 23)
}

impl PushQuietHoursWindow {
    fn from_wire(wire: PushQuietHoursWindowWire) -> Self {
        Self {
            start_hour: normalize_quiet_hour(wire.start_hour, 22),
            end_hour: normalize_quiet_hour(wire.end_hour, 8),
        }
    }

    fn to_canonical(&self) -> PushQuietHoursWindowCanonical {
        PushQuietHoursWindowCanonical {
            start_hour: self.start_hour,
            end_hour: self.end_hour,
        }
    }

    fn is_active_at_hour(&self, hour: i64) -> bool {
        if self.start_hour == self.end_hour {
            return true;
        }
        if self.start_hour < self.end_hour {
            return hour >= self.start_hour && hour < self.end_hour;
        }
        hour >= self.start_hour || hour < self.end_hour
    }
}

impl PushPolicySnapshot {
    fn from_wire(wire: PushPolicySnapshotWire) -> Self {
        let muted_conversations = wire
            .muted_conversations
            .into_iter()
            .filter_map(|value| normalize_push_convo_id(&value))
            .collect::<BTreeSet<_>>();

        let convo_privacy_overrides = wire
            .convo_privacy_overrides
            .into_iter()
            .filter_map(|(key, value)| {
                normalize_push_convo_id(&key)
                    .map(|normalized| (normalized, normalize_privacy_level(Some(value), 1)))
            })
            .collect::<BTreeMap<_, _>>();

        let contact_privacy_overrides = wire
            .contact_privacy_overrides
            .into_iter()
            .filter_map(|(key, value)| {
                normalize_push_profile_id(&key)
                    .map(|normalized| (normalized, normalize_privacy_level(Some(value), 2)))
            })
            .collect::<BTreeMap<_, _>>();

        let contact_calls_disabled = wire
            .contact_calls_disabled
            .into_iter()
            .filter_map(|value| normalize_push_profile_id(&value))
            .collect::<BTreeSet<_>>();

        let convo_quiet_hours = wire
            .convo_quiet_hours
            .into_iter()
            .filter_map(|(key, value)| {
                normalize_push_convo_id(&key)
                    .map(|normalized| (normalized, PushQuietHoursWindow::from_wire(value)))
            })
            .collect::<BTreeMap<_, _>>();

        Self {
            notifications_enabled: wire.notifications_enabled.unwrap_or(true),
            direct_messages_enabled: wire.direct_messages_enabled.unwrap_or(true),
            group_messages_enabled: wire.group_messages_enabled.unwrap_or(true),
            incoming_calls_enabled: wire.incoming_calls_enabled.unwrap_or(true),
            message_visual_alerts_enabled: wire.message_visual_alerts_enabled.unwrap_or(true),
            direct_message_privacy: normalize_privacy_level(wire.direct_message_privacy, 2),
            group_message_privacy: normalize_privacy_level(wire.group_message_privacy, 1),
            muted_conversations,
            convo_privacy_overrides,
            contact_privacy_overrides,
            contact_calls_disabled,
            timezone_offset_minutes: normalize_timezone_offset_minutes(
                wire.timezone_offset_minutes,
            ),
            convo_quiet_hours,
        }
    }

    fn to_canonical(&self) -> PushPolicySnapshotCanonical {
        PushPolicySnapshotCanonical {
            notifications_enabled: self.notifications_enabled,
            direct_messages_enabled: self.direct_messages_enabled,
            group_messages_enabled: self.group_messages_enabled,
            incoming_calls_enabled: self.incoming_calls_enabled,
            message_visual_alerts_enabled: self.message_visual_alerts_enabled,
            direct_message_privacy: self.direct_message_privacy,
            group_message_privacy: self.group_message_privacy,
            muted_conversations: self.muted_conversations.iter().cloned().collect(),
            convo_privacy_overrides: self.convo_privacy_overrides.clone(),
            contact_privacy_overrides: self.contact_privacy_overrides.clone(),
            contact_calls_disabled: self.contact_calls_disabled.iter().cloned().collect(),
            timezone_offset_minutes: self.timezone_offset_minutes,
            convo_quiet_hours: self
                .convo_quiet_hours
                .iter()
                .map(|(key, value)| (key.clone(), value.to_canonical()))
                .collect(),
        }
    }

    fn is_quiet_hours_active_for_convo(&self, convo_id: &str, now_ms: i64) -> bool {
        let Some(window) = self.convo_quiet_hours.get(convo_id) else {
            return false;
        };
        let local_minutes = ((now_ms / 60_000) + self.timezone_offset_minutes).rem_euclid(24 * 60);
        let local_hour = local_minutes / 60;
        window.is_active_at_hour(local_hour)
    }

    fn privacy_for_message(&self, message: &MessageTransportMetaRecord) -> i64 {
        if let Some(level) = self.convo_privacy_overrides.get(&message.convo_id) {
            return *level;
        }
        if !message.is_group {
            if let Some(sender_profile_id) = message.sender_profile_id.as_deref() {
                if let Some(level) = self.contact_privacy_overrides.get(sender_profile_id) {
                    return *level;
                }
            }
            return self.direct_message_privacy;
        }
        self.group_message_privacy
    }

    fn should_alert_for_message(&self, message: &MessageTransportMetaRecord, now_ms: i64) -> bool {
        self.notifications_enabled
            && self.message_visual_alerts_enabled
            && if message.is_group {
                self.group_messages_enabled
            } else {
                self.direct_messages_enabled
            }
            && !self.muted_conversations.contains(&message.convo_id)
            && !self.is_quiet_hours_active_for_convo(&message.convo_id, now_ms)
    }

    fn should_alert_for_call(&self, caller_profile_id: Option<&str>) -> bool {
        if !self.notifications_enabled || !self.incoming_calls_enabled {
            return false;
        }
        if let Some(profile_id) = caller_profile_id {
            return !self.contact_calls_disabled.contains(profile_id);
        }
        true
    }
}

fn normalize_push_policy_json(
    policy_b64: Option<&str>,
) -> Result<Option<String>, (StatusCode, String)> {
    let Some(raw) = policy_b64.map(str::trim).filter(|value| !value.is_empty()) else {
        return Ok(None);
    };
    if raw.len() > 65536 {
        return Err((StatusCode::BAD_REQUEST, "bad policy_b64".into()));
    }

    let decoded = base64::engine::general_purpose::STANDARD
        .decode(raw)
        .map_err(|_| (StatusCode::BAD_REQUEST, "bad policy_b64".into()))?;
    if decoded.len() > 131072 {
        return Err((StatusCode::BAD_REQUEST, "bad policy_b64".into()));
    }

    let wire: PushPolicySnapshotWire = serde_json::from_slice(&decoded)
        .map_err(|_| (StatusCode::BAD_REQUEST, "bad policy_b64".into()))?;
    let normalized = PushPolicySnapshot::from_wire(wire);
    let canonical = serde_json::to_string(&normalized.to_canonical())
        .map_err(|_| (StatusCode::BAD_REQUEST, "bad policy_b64".into()))?;
    Ok(Some(canonical))
}

fn parse_push_policy_json(policy_json: Option<&str>) -> Option<PushPolicySnapshot> {
    let raw = policy_json?.trim();
    if raw.is_empty() || raw.len() > 131072 {
        return None;
    }
    let wire: PushPolicySnapshotWire = serde_json::from_str(raw).ok()?;
    Some(PushPolicySnapshot::from_wire(wire))
}

/// True when the transport meta marks a Double-Ratchet session-heal control
/// wake (`{"kind":"session_heal_v1"}`), sent by [reset-ping / confirm-ping]. The
/// body is intentionally empty — it carries no user content, only the signal to
/// wake a (possibly frozen) peer so the forward heal completes promptly.
fn is_session_heal_transport_meta(transport_meta_json: Option<&str>) -> bool {
    let Some(raw) = transport_meta_json.map(str::trim).filter(|v| !v.is_empty()) else {
        return false;
    };
    if raw.len() > 8192 {
        return false;
    }
    serde_json::from_str::<TransportMetaEnvelope>(raw)
        .map(|envelope| envelope.kind == "session_heal_v1")
        .unwrap_or(false)
}

/// Срок, который клиент по умолчанию ставит служебной посылке
/// (`_controlMessageTtlSeconds` в `app_controller.dart`).
const CLIENT_CONTROL_TTL_SECONDS: u32 = 60 * 60;

/// 🔴 МОСТ ДЛЯ СВОИХ УСТРОЙСТВ (25.09.2026).
///
/// Всё, что телефон пересылает на ПК того же аккаунта, — копии своих
/// сообщений, вложений, реакций, правок, отметки «прочитано», состояние
/// чатов, запросы и порции истории — клиент шлёт служебной посылкой со
/// сроком 1 час. ПК, выключенный дольше часа, терял всё это навсегда: в ночь
/// на 25.09 истекли все 23 копии ответов владельца, за неделю — 48 из 56.
/// Сами сообщения собеседникам живут 7 дней, поэтому переписка на ПК
/// выглядела «наполовину пустой», а прочитанное — непрочитанным.
///
/// Чинится это в клиенте (срок копий), но выпущенные телефоны так и будут
/// слать час. Поэтому реле продлевает срок ровно таким посылкам:
/// - отправитель и получатель — устройства одного профиля, и это разные
///   устройства;
/// - клиент попросил срок служебной посылки по умолчанию (час). Звонки
///   (90 с), «печатает» (20 с) и сами сообщения (7 дней) идут со своими
///   сроками и сюда не попадают;
/// - это не лечение сессии (`session_heal_v1`) и не сигнал звонка: их поздняя
///   доставка бессмысленна.
///
/// Срок никогда не укорачивается; 0 в настройке — прежнее поведение.
fn own_device_control_ttl(
    own_device_ttl_seconds: u32,
    capped_ttl_seconds: u32,
    sender_profile_id: &str,
    receiver_profile_id: &str,
    from_device_id: &str,
    to_device_id: &str,
    is_session_heal: bool,
    is_call_signal: bool,
) -> u32 {
    if own_device_ttl_seconds <= capped_ttl_seconds
        || capped_ttl_seconds != CLIENT_CONTROL_TTL_SECONDS
        || is_session_heal
        || is_call_signal
        || sender_profile_id.is_empty()
        || sender_profile_id != receiver_profile_id
        || from_device_id == to_device_id
    {
        return capped_ttl_seconds;
    }
    own_device_ttl_seconds
}

fn parse_chat_message_transport_meta(
    transport_meta_json: Option<&str>,
) -> Result<Option<MessageTransportMetaRecord>, String> {
    let Some(raw) = transport_meta_json.map(str::trim).filter(|v| !v.is_empty()) else {
        return Ok(None);
    };
    if raw.len() > 8192 {
        return Err("transport_meta_json too large".into());
    }

    let envelope: TransportMetaEnvelope =
        serde_json::from_str(raw).map_err(|_| "bad transport_meta_json".to_string())?;
    if envelope.kind != "chat_message_v1" {
        return Ok(None);
    }

    let message = envelope
        .message
        .ok_or_else(|| "missing message metadata".to_string())?;
    let convo_id =
        normalize_push_convo_id(&message.convo_id).ok_or_else(|| "bad convo_id".to_string())?;
    let message_kind = message.message_kind.trim().to_ascii_lowercase();
    if !matches!(message_kind.as_str(), "text" | "sticker" | "attachment") {
        return Err("bad message_kind".into());
    }
    let payload_event_id = message.payload_event_id.trim();
    if !is_valid_id(payload_event_id, 128) {
        return Err("bad payload_event_id".into());
    }
    if message.created_at_ms < 0 {
        return Err("bad message created_at_ms".into());
    }
    let category = message
        .category
        .as_deref()
        .unwrap_or_default()
        .trim()
        .to_ascii_lowercase();
    let is_group = message.is_group || category == "group" || convo_id.starts_with("room:");

    Ok(Some(MessageTransportMetaRecord {
        convo_id,
        is_group,
        message_kind,
        payload_event_id: payload_event_id.to_string(),
        created_at_ms: message.created_at_ms,
        sender_profile_id: message
            .sender_profile_id
            .as_deref()
            .and_then(normalize_push_profile_id),
        sender_display_name: normalize_push_text(message.sender_display_name.as_deref(), 80),
    }))
}

/// Текст уведомления по виду сообщения. Содержимого сообщения здесь нет и
/// быть не может: реле его не знает.
fn push_body_for_kind(message_kind: &str) -> String {
    match message_kind {
        "sticker" => "Sticker".to_string(),
        "attachment" => "Attachment".to_string(),
        _ => "New message".to_string(),
    }
}

fn parse_call_invite_push_hint(
    transport_meta_json: Option<&str>,
) -> Result<Option<CallInvitePushHint>, String> {
    let Some(raw) = transport_meta_json.map(str::trim).filter(|v| !v.is_empty()) else {
        return Ok(None);
    };
    if raw.len() > 8192 {
        return Err("transport_meta_json too large".into());
    }

    let envelope: TransportMetaEnvelope =
        serde_json::from_str(raw).map_err(|_| "bad transport_meta_json".to_string())?;
    if envelope.kind != "call_signal_v1" {
        return Ok(None);
    }

    let call = envelope
        .call
        .ok_or_else(|| "missing call metadata".to_string())?;
    let action = call.action.trim().to_ascii_lowercase();
    if action != "invite" {
        return Ok(None);
    }

    Ok(Some(CallInvitePushHint {
        is_video: call.is_video,
        call_id: call.call_id.trim().to_string(),
        call_attempt_id: call.call_attempt_id.trim().to_string(),
        signal_id: call.signal_id.trim().to_string(),
        created_at_ms: call.created_at_ms,
    }))
}

fn is_ciphertext_b64_reasonable(s: &str) -> bool {
    // Keep bounded: big payloads should use blob upload.
    // Base64 expands by ~4/3, so 256KiB b64 is already a fairly large message.
    s.len() <= 256 * 1024
}

fn hello_auth_message(device_id: &str, ts_ms: i64, nonce_b64: &str) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HELLO-V1\ndevice_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn require_auth_enabled() -> bool {
    env::var("SECRETLY_RELAY_REQUIRE_AUTH")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(true)
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

    // Best-effort prune to avoid unbounded growth under nonce spray.
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

fn header_str<'a>(headers: &'a HeaderMap, name: &'static str) -> Option<&'a str> {
    headers.get(name).and_then(|v| v.to_str().ok())
}

fn required_http_device_id_header(headers: &HeaderMap) -> Result<String, (StatusCode, String)> {
    let device_id = header_str(headers, "x-secretly-device-id")
        .ok_or((
            StatusCode::BAD_REQUEST,
            "missing x-secretly-device-id".into(),
        ))?
        .trim()
        .to_string();
    if !is_valid_id(&device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }
    Ok(device_id)
}

fn normalize_profile_delete_device_ids(
    raw_device_ids: Option<Vec<String>>,
) -> Result<Vec<String>, (StatusCode, String)> {
    let mut device_ids = Vec::<String>::new();
    for raw in raw_device_ids.unwrap_or_default() {
        let device_id = raw.trim().to_string();
        if device_id.is_empty() {
            continue;
        }
        if !is_valid_id(&device_id, 128) {
            return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
        }
        device_ids.push(device_id);
    }
    device_ids.sort();
    device_ids.dedup();
    if device_ids.len() > 128 {
        return Err((StatusCode::BAD_REQUEST, "too many device_ids".into()));
    }
    Ok(device_ids)
}

fn profile_delete_device_ids_csv(device_ids: &[String]) -> String {
    device_ids.join(",")
}

fn effective_client_ip(
    headers: &HeaderMap,
    socket_ip: std::net::IpAddr,
    trust_xff: bool,
) -> std::net::IpAddr {
    if !trust_xff {
        return socket_ip;
    }

    // 🔴 ПОСЛЕДНЕЕ значение цепочки, а не первое (06.08.2026).
    //
    // X-Forwarded-For — список, куда каждый прокси ДОПИСЫВАЕТ адрес того, от
    // кого получил запрос. Перед нами ровно один доверенный прокси (Caddy,
    // порт реле закрыт наружу), поэтому последним всегда стоит адрес, который
    // подставил ОН, — то есть настоящий клиент.
    //
    // Первое значение подставляет кто угодно. Клиент, приславший
    // `X-Forwarded-For: 1.2.3.4`, превращал бы цепочку в «1.2.3.4, <его адрес>»,
    // и чтение первого отдало бы ограничителю выдуманный адрес: своё ведро
    // подделывается одним заголовком, а чужое — исчерпывается за него. То есть
    // включение доверия к заголовку со старым разбором не починило бы
    // ограничитель, а отключило.
    //
    // Если доверенных прокси когда-нибудь станет двое, брать надо будет не
    // последний, а N-й с конца по их числу. Пока их один — берём последний.
    headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.split(',').next_back())
        .map(|s| s.trim())
        .and_then(|s| s.parse::<std::net::IpAddr>().ok())
        .unwrap_or(socket_ip)
}

fn http_auth_headers(
    headers: &HeaderMap,
) -> Result<(String, i64, String, String), (StatusCode, String)> {
    let device_id = header_str(headers, "x-secretly-device-id")
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

    Ok((device_id, ts_ms, nonce_b64, signature_b64))
}

async fn verify_http_auth(
    state: &AppState,
    headers: &HeaderMap,
    expected_device_id: Option<&str>,
    msg: Vec<u8>,
) -> Result<String, (StatusCode, String)> {
    if !require_auth_enabled() {
        return Ok(expected_device_id.unwrap_or("").to_string());
    }

    // 🔴 ОТКАЗ АВТОРИЗАЦИИ ОБЯЗАН БЫТЬ ВИДЕН (12.09.2026).
    //
    // Обращение в поддержку: iPhone 13 mini, «System errors», отправить ничего
    // нельзя, `Relay push token set failed: HTTP 401`, и так с самой установки.
    // Разбор упёрся в стену: реле отвергало запросы этого устройства десятками,
    // но в журнале не было НИ ОДНОЙ записи об отказе — ни причины, ни кода.
    // Сказать, что именно не сошлось (часы, подпись, одноразовый код или
    // неизвестное устройство), было нечем.
    //
    // Пишем ТОЛЬКО причину и отпечаток устройства. Ни подписи, ни ключа, ни
    // самого device_id в журнал не попадает — `log_fingerprint` для того и есть.
    let reject = |reason: &'static str, did: &str| -> (StatusCode, String) {
        tracing::warn!(
            device_ref = %log_fingerprint(did),
            reason = reason,
            "http auth rejected"
        );
        (StatusCode::UNAUTHORIZED, reason.to_string())
    };

    let (device_id, ts_ms, nonce_b64, signature_b64) = http_auth_headers(headers)?;
    if !is_valid_id(&device_id, 128) {
        return Err(reject("bad device_id", &device_id));
    }
    if let Some(exp) = expected_device_id {
        if exp != device_id {
            return Err(reject("device_id mismatch", &device_id));
        }
    }

    let now = now_ms();
    if (ts_ms - now).abs() > 5 * 60 * 1000 {
        // Расхождение часов — самая частая догадка, поэтому его величину
        // называем прямо: по ней сразу видно, клиент спешит или отстаёт.
        tracing::warn!(
            device_ref = %log_fingerprint(&device_id),
            reason = "timestamp out of range",
            skew_ms = ts_ms - now,
            "http auth rejected"
        );
        return Err((StatusCode::UNAUTHORIZED, "timestamp out of range".into()));
    }
    if let Err(e) = check_and_mark_nonce(state, &device_id, &nonce_b64, now) {
        tracing::warn!(
            device_ref = %log_fingerprint(&device_id),
            reason = "nonce",
            "http auth rejected"
        );
        return Err(e);
    }

    let Some(ik_b64) = fetch_identity_pub_b64(state, &device_id).await else {
        // Устройства нет у сервера ключей ЛИБО запрос к нему не удался —
        // изнутри `fetch_identity_pub_b64` эти два случая неразличимы, и это
        // отдельный повод смотреть журнал сервера ключей рядом.
        return Err(reject("unknown device", &device_id));
    };
    if !verify_ed25519_b64(&ik_b64, &signature_b64, &msg) {
        return Err(reject("bad signature", &device_id));
    }

    // 🔴 ОДНО ГОРЛО ДЛЯ ЗАМЕРА РАСКАТКИ (12.08.2026).
    //
    // Номер сборки записывался ТОЛЬКО в /v1/pending — а его зовёт ФОНОВЫЙ
    // изолят, который собирает заголовки вручную и client-build не посылает.
    // Заголовок добавляет RelayClient переднего плана, но его запросы идут в
    // другие точки, где записи не стояло. Результат: 0 из 2001 устройства с
    // известной сборкой, то есть измеритель раскатки не работал НИКОГДА.
    //
    // Это гейт: требование номера безопасности (К-5 и пауза между Ш-2 и Ш-3)
    // требует знать долю сборок, умеющих AIK,
    // прежде чем менять то, что решают приёмники. Строить решение поверх
    // неработающего замера нельзя.
    //
    // Здесь проходят ВСЕ подписанные точки, поэтому одно место покрывает и
    // передний план, и фон. Запись дешёвая: UPDATE стоит под условием
    // `client_build <> ?`, то есть после первого раза не пишет ничего.
    //
    // Заголовок НАМЕРЕННО вне подписи (как и было): подписывать его значило бы
    // сломать совместимость со всеми существующими сборками ради счётчика.
    if let Some(build) = header_str(headers, "x-secretly-client-build") {
        if let Err(e) = state
            .store
            .device_activity_set_client_build(&device_id, build, now_ms())
            .await
        {
            tracing::debug!(
                device_ref = %log_fingerprint(&device_id),
                error = %e,
                "client build note failed"
            );
        }
    }

    Ok(device_id)
}

fn http_welcome_auth_message(device_id: &str, ts_ms: i64, nonce_b64: &str) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-WELCOME-V1\ndevice_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_pending_auth_message(
    device_id: &str,
    from_seq: u64,
    limit: u64,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-PENDING-V1\ndevice_id={}\nfrom_seq={}\nlimit={}\nts_ms={}\nnonce_b64={}\n",
        device_id, from_seq, limit, ts_ms, nonce_b64
    )
    .into_bytes()
}

/// ПРОВЕРКА «ДОШЛО ЛИ» (12.08.2026). Канонический текст для
/// `/v1/pending_check` — отправитель спрашивает, держит ли реле ещё названные
/// им конверты для получателя.
///
/// 🔴 ЗАЧЕМ ЭТА ТОЧКА ВООБЩЕ ЕСТЬ. Страховка отправителя переотправляет смс,
/// на которую не пришла квитанция о доставке. Получатель, разобравший смс в
/// ФОНЕ, квитанцию отправить не может: она шифруется, а это продвижение
/// отправляющей цепи ратчета, запрещённое в фоне правилом И-3. Отправитель по
/// молчанию считал смс потерянной и слал заново каждые несколько минут —
/// новый конверт, новый пуш, новый баннер у получателя. Замер 12.08 в поле:
/// повторы шли, пока приложение отправителя открыто, и прекращались, как
/// только он его закрывал.
///
/// Реле и так знает факт забора: подтверждение удаляет строку. Здесь мы лишь
/// даём отправителю СПРОСИТЬ об этом.
///
/// ⚠️ ЧТО ЭТО НЕ ЕСТЬ. Это транспортный факт, а не криптографическое
/// доказательство прочтения. Галочки в чате по нему НЕ ставятся — им остаётся
/// сквозная квитанция. Отсюда гасится только переотправка.
///
/// Ответ перечисляет ПОДМНОЖЕСТВО присланных msg_id, поэтому спрашивающий не
/// узнаёт ничего, чего не знал: чужие идентификаторы случайны и неугадываемы,
/// а глубина чужого ящика отсюда не видна.
fn http_pending_check_auth_message(
    device_id: &str,
    to_device_id: &str,
    msg_ids: &[String],
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    // msg_id входят в подпись, иначе посредник мог бы подменить список.
    format!(
        "SECRETLY-RELAY-HTTP-PENDING-CHECK-V1\ndevice_id={}\nto_device_id={}\nmsg_ids={}\nts_ms={}\nnonce_b64={}\n",
        device_id,
        to_device_id,
        msg_ids.join(","),
        ts_ms,
        nonce_b64
    )
    .into_bytes()
}

#[cfg(test)]
mod pending_check_tests {
    use super::*;

    /// Текст подписи ОБЯЗАН посимвольно совпадать с клиентским
    /// `AuthSigner.relayHttpPendingCheckMessage`. Расхождение здесь не упало бы
    /// нигде: реле молча вернуло бы 401, клиент молча счёл бы «держит» и
    /// продолжил переотправлять — то есть правка выглядела бы рабочей и не
    /// работала. Ровно так 11.08 выжил дефект с подтверждениями.
    #[test]
    fn pending_check_auth_message_is_canonical() {
        let msg = http_pending_check_auth_message(
            "dev-1",
            "dev-2",
            &["m1".to_string(), "m2".to_string()],
            1700000000000,
            "nonce",
        );
        assert_eq!(
            String::from_utf8(msg).unwrap(),
            "SECRETLY-RELAY-HTTP-PENDING-CHECK-V1\n\
             device_id=dev-1\n\
             to_device_id=dev-2\n\
             msg_ids=m1,m2\n\
             ts_ms=1700000000000\n\
             nonce_b64=nonce\n"
        );
    }

    #[test]
    fn pending_check_auth_message_binds_every_msg_id() {
        // Иначе посредник подменил бы список и заставил отправителя поверить,
        // что доставлено то, что не доставлено.
        let a = http_pending_check_auth_message("d", "t", &["m1".into()], 1, "n");
        let b = http_pending_check_auth_message("d", "t", &["m2".into()], 1, "n");
        assert_ne!(a, b);
    }
}

fn http_ack_auth_message(device_id: &str, seq: u64, ts_ms: i64, nonce_b64: &str) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ACK-V1\ndevice_id={}\nseq={}\nts_ms={}\nnonce_b64={}\n",
        device_id, seq, ts_ms, nonce_b64
    )
    .into_bytes()
}

/// SCHEDULED RE-KEY REFRESH (2026-07-19). Canonical auth message for
/// `/v1/cancel_scheduled` — the SENDER retracts a still-held "send later" row
/// so it can re-upload the same message under a fresh session. Without this a
/// session rotation between upload and release leaves a stale ciphertext that
/// the recipient can never decrypt (proven live: two wires encrypted 12s
/// apart, one released before a rotation decrypted, one after it did not).
fn http_cancel_scheduled_auth_message(
    device_id: &str,
    to_device_id: &str,
    msg_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-CANCEL-SCHEDULED-V1\ndevice_id={}\nto_device_id={}\nmsg_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, to_device_id, msg_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_rebind_auth_message(
    new_device_id: &str,
    old_device_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-REBIND-V1\nnew_device_id={}\nold_device_id={}\nts_ms={}\nnonce_b64={}\n",
        new_device_id, old_device_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

/// К-2: what a room broadcast signs. The ciphertext and the recipient list go
/// in as SHA-256 digests (base64) so the signed text stays small; the list is
/// sorted and newline-joined before hashing.
fn http_room_broadcast_auth_message(
    from_device_id: &str,
    room_id: &str,
    msg_id: &str,
    ciphertext_b64: &str,
    recipients: &[String],
    transport_meta_json: Option<&str>,
    ttl_seconds: u32,
    deliver_at_ms: i64,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    let b64 =
        |bytes: &[u8]| base64::engine::general_purpose::STANDARD.encode(Sha256::digest(bytes));
    let mut sorted: Vec<&str> = recipients.iter().map(|r| r.as_str()).collect();
    sorted.sort_unstable();
    format!(
        "SECRETLY-RELAY-ROOM-BROADCAST-V1\nfrom_device_id={}\nroom_id={}\nmsg_id={}\nciphertext_sha256_b64={}\nrecipients_sha256_b64={}\nttl_seconds={}\ndeliver_at_ms={}\ntransport_meta_json={}\nts_ms={}\nnonce_b64={}\n",
        from_device_id,
        room_id,
        msg_id,
        b64(ciphertext_b64.as_bytes()),
        b64(sorted.join("\n").as_bytes()),
        ttl_seconds,
        deliver_at_ms,
        transport_meta_json.unwrap_or("").trim(),
        ts_ms,
        nonce_b64
    )
    .into_bytes()
}

fn http_send_auth_message(
    from_device_id: &str,
    to_device_id: &str,
    msg_id: &str,
    ciphertext_b64: &str,
    transport_meta_json: Option<&str>,
    ttl_seconds: u32,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    let normalized_transport_meta_json = transport_meta_json.unwrap_or("").trim();
    format!(
        "SECRETLY-RELAY-HTTP-SEND-V1\nfrom_device_id={}\nto_device_id={}\nmsg_id={}\nciphertext_b64={}\nttl_seconds={}\ntransport_meta_json={}\nts_ms={}\nnonce_b64={}\n",
        from_device_id, to_device_id, msg_id, ciphertext_b64, ttl_seconds, normalized_transport_meta_json, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_call_session_auth_message(
    device_id: &str,
    call_id: &str,
    call_attempt_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-CALL-SESSION-V1\ndevice_id={}\ncall_id={}\ncall_attempt_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, call_id, call_attempt_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_ice_config_auth_message(device_id: &str, ts_ms: i64, nonce_b64: &str) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ICE-CONFIG-V1\ndevice_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_blob_upload_auth_message(
    device_id: &str,
    ttl_seconds: u64,
    body_sha256_b64: &str,
    access_token_sha256_b64: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-BLOB-UPLOAD-V1\ndevice_id={}\nttl_seconds={}\nbody_sha256_b64={}\naccess_token_sha256_b64={}\nts_ms={}\nnonce_b64={}\n",
        device_id, ttl_seconds, body_sha256_b64, access_token_sha256_b64, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_blob_get_auth_message(
    device_id: &str,
    blob_id: &str,
    access_token_sha256_b64: Option<&str>,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    if let Some(access_token_sha256_b64) = access_token_sha256_b64 {
        format!(
            "SECRETLY-RELAY-HTTP-BLOB-GET-V1\ndevice_id={}\nblob_id={}\naccess_token_sha256_b64={}\nts_ms={}\nnonce_b64={}\n",
            device_id, blob_id, access_token_sha256_b64, ts_ms, nonce_b64
        )
        .into_bytes()
    } else {
        format!(
            "SECRETLY-RELAY-HTTP-BLOB-GET-V1\ndevice_id={}\nblob_id={}\nts_ms={}\nnonce_b64={}\n",
            device_id, blob_id, ts_ms, nonce_b64
        )
        .into_bytes()
    }
}

fn blob_access_token_hash_b64(token_b64: &str) -> Result<String, (StatusCode, String)> {
    let token_bytes = base64::engine::general_purpose::STANDARD
        .decode(token_b64.as_bytes())
        .map_err(|_| (StatusCode::BAD_REQUEST, "bad blob access token".into()))?;
    if token_bytes.len() < 16 || token_bytes.len() > 128 {
        return Err((StatusCode::BAD_REQUEST, "bad blob access token".into()));
    }
    Ok(base64::engine::general_purpose::STANDARD.encode(Sha256::digest(token_bytes)))
}

fn ensure_blob_capability_authorized(
    stored_access_token_sha256_b64: &str,
    provided_access_token_sha256_b64: Option<&str>,
) -> Result<(), (StatusCode, String)> {
    // AUD-029 fix: fail-close when the stored access token hash is missing
    // (e.g. legacy rows or corrupted capability). Before this fix any caller
    // could download such blobs without a token. Uploads now always require a
    // token (http_blob_upload rejects empty values), so this is reachable only
    // for historical rows; serve them 403 rather than granting anonymous read.
    if stored_access_token_sha256_b64.is_empty() {
        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
    }

    let Some(got_hash) = provided_access_token_sha256_b64 else {
        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
    };

    if got_hash != stored_access_token_sha256_b64 {
        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
    }

    Ok(())
}

fn http_blocks_list_auth_message(device_id: &str, ts_ms: i64, nonce_b64: &str) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-BLOCKS-LIST-V1\ndevice_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

// Sprint 2 R3: auth message for the new active-devices endpoint. The
// requester proves possession of an identity key registered for
// `device_id` and asks for the active-device subset of `profile_id`.
fn http_active_devices_auth_message(
    device_id: &str,
    profile_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ACTIVE-DEVICES-V1\ndevice_id={}\nprofile_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, profile_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_blocks_set_auth_message(
    device_id: &str,
    blocked_profile_id: &str,
    blocked: bool,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-BLOCKS-SET-V1\ndevice_id={}\nblocked_profile_id={}\nblocked={}\nts_ms={}\nnonce_b64={}\n",
        device_id,
        blocked_profile_id,
        if blocked { 1 } else { 0 },
        ts_ms,
        nonce_b64
    )
    .into_bytes()
}

fn http_push_token_set_auth_message(
    device_id: &str,
    token: &str,
    platform: &str,
    enabled: bool,
    policy_b64: Option<&str>,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-PUSH-TOKEN-SET-V1\ndevice_id={}\ntoken={}\nplatform={}\nenabled={}\npolicy_b64={}\nts_ms={}\nnonce_b64={}\n",
        device_id,
        token,
        platform,
        if enabled { 1 } else { 0 },
        policy_b64.unwrap_or(""),
        ts_ms,
        nonce_b64
    )
    .into_bytes()
}

fn http_profile_delete_auth_message(
    device_id: &str,
    profile_id: &str,
    device_ids_csv: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-PROFILE-DELETE-V1\ndevice_id={}\nprofile_id={}\ndevice_ids={}\nts_ms={}\nnonce_b64={}\n",
        device_id, profile_id, device_ids_csv, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_room_create_auth_message(
    device_id: &str,
    room_id: &str,
    title: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-CREATE-V1\ndevice_id={}\nroom_id={}\ntitle={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, title, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_room_get_auth_message(
    device_id: &str,
    room_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-GET-V1\ndevice_id={}\nroom_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_room_members_list_auth_message(
    device_id: &str,
    room_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-MEMBERS-LIST-V1\ndevice_id={}\nroom_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_room_members_upsert_auth_message(
    device_id: &str,
    room_id: &str,
    profile_id: &str,
    status: &str,
    role: &str,
    source_link_id: Option<&str>,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    let source_link_id = source_link_id.unwrap_or("");
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-MEMBERS-UPSERT-V1\ndevice_id={}\nroom_id={}\nprofile_id={}\nstatus={}\nrole={}\nsource_link_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, profile_id, status, role, source_link_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_room_member_tag_set_auth_message(
    device_id: &str,
    room_id: &str,
    tag: Option<&str>,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-MEMBER-TAG-SET-V1\ndevice_id={}\nroom_id={}\ntag={}\nts_ms={}\nnonce_b64={}\n",
        device_id,
        room_id,
        tag.unwrap_or_default(),
        ts_ms,
        nonce_b64,
    )
    .into_bytes()
}

fn http_room_member_unban_auth_message(
    device_id: &str,
    room_id: &str,
    profile_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-MEMBER-UNBAN-V1\ndevice_id={}\nroom_id={}\nprofile_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, profile_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_room_transfer_ownership_auth_message(
    device_id: &str,
    room_id: &str,
    next_owner_profile_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-TRANSFER-OWNERSHIP-V1\ndevice_id={}\nroom_id={}\nnext_owner_profile_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, next_owner_profile_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_room_profile_update_auth_message(
    device_id: &str,
    room_id: &str,
    title: &str,
    description: Option<&str>,
    avatar_hash: Option<&str>,
    avatar_image_b64: Option<&str>,
    clear_avatar: bool,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-PROFILE-UPDATE-V2\ndevice_id={}\nroom_id={}\ntitle={}\ndescription={}\navatar_hash={}\navatar_image_b64={}\nclear_avatar={}\nts_ms={}\nnonce_b64={}\n",
        device_id,
        room_id,
        title,
        description.unwrap_or_default(),
        avatar_hash.unwrap_or_default(),
        avatar_image_b64.unwrap_or_default(),
        if clear_avatar { "true" } else { "false" },
        ts_ms,
        nonce_b64
    )
    .into_bytes()
}

fn http_room_settings_update_auth_message(
    device_id: &str,
    room_id: &str,
    reactions_mode: &str,
    allow_text: bool,
    allow_media: bool,
    allow_add_members: bool,
    allow_pin_messages: bool,
    allow_change_group_info: bool,
    allow_change_tag: bool,
    join_approval_required: bool,
    slow_mode_seconds: i64,
    chat_history_visible: bool,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-SETTINGS-UPDATE-V1\ndevice_id={}\nroom_id={}\nreactions_mode={}\nallow_text={}\nallow_media={}\nallow_add_members={}\nallow_pin_messages={}\nallow_change_group_info={}\nallow_change_tag={}\njoin_approval_required={}\nslow_mode_seconds={}\nchat_history_visible={}\nts_ms={}\nnonce_b64={}\n",
        device_id,
        room_id,
        reactions_mode,
        if allow_text { 1 } else { 0 },
        if allow_media { 1 } else { 0 },
        if allow_add_members { 1 } else { 0 },
        if allow_pin_messages { 1 } else { 0 },
        if allow_change_group_info { 1 } else { 0 },
        if allow_change_tag { 1 } else { 0 },
        if join_approval_required { 1 } else { 0 },
        slow_mode_seconds,
        if chat_history_visible { 1 } else { 0 },
        ts_ms,
        nonce_b64,
    )
    .into_bytes()
}

fn http_room_message_admission_auth_message(
    device_id: &str,
    room_id: &str,
    message_id: &str,
    kind: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-MESSAGE-ADMISSION-V1\ndevice_id={}\nroom_id={}\nmessage_id={}\nkind={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, message_id, kind, ts_ms, nonce_b64,
    )
    .into_bytes()
}

fn http_room_pinned_message_set_auth_message(
    device_id: &str,
    room_id: &str,
    message_id: Option<&str>,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-PINNED-MESSAGE-SET-V1\ndevice_id={}\nroom_id={}\nmessage_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id,
        room_id,
        message_id.unwrap_or_default(),
        ts_ms,
        nonce_b64,
    )
    .into_bytes()
}

fn http_room_leave_auth_message(
    device_id: &str,
    room_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-LEAVE-V1\ndevice_id={}\nroom_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_room_delete_auth_message(
    device_id: &str,
    room_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-DELETE-V1\ndevice_id={}\nroom_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_room_invite_links_list_auth_message(
    device_id: &str,
    room_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-INVITE-LINKS-LIST-V1\ndevice_id={}\nroom_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_room_invite_links_create_auth_message(
    device_id: &str,
    room_id: &str,
    expires_at_ms: Option<i64>,
    max_uses: Option<i64>,
    requires_approval: bool,
    allowed_role: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-INVITE-LINKS-CREATE-V1\ndevice_id={}\nroom_id={}\nexpires_at_ms={}\nmax_uses={}\nrequires_approval={}\nallowed_role={}\nts_ms={}\nnonce_b64={}\n",
        device_id,
        room_id,
        expires_at_ms.map(|value| value.to_string()).unwrap_or_default(),
        max_uses.map(|value| value.to_string()).unwrap_or_default(),
        if requires_approval { 1 } else { 0 },
        allowed_role,
        ts_ms,
        nonce_b64
    )
    .into_bytes()
}

fn http_room_invite_link_revoke_auth_message(
    device_id: &str,
    room_id: &str,
    link_id: &str,
    revoked: bool,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-INVITE-LINK-REVOKE-V1\ndevice_id={}\nroom_id={}\nlink_id={}\nrevoked={}\nts_ms={}\nnonce_b64={}\n",
        device_id,
        room_id,
        link_id,
        if revoked { 1 } else { 0 },
        ts_ms,
        nonce_b64
    )
    .into_bytes()
}

fn http_room_invite_preview_auth_message(
    device_id: &str,
    slug: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-INVITE-PREVIEW-V1\ndevice_id={}\nslug={}\nts_ms={}\nnonce_b64={}\n",
        device_id, slug, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_room_invite_redeem_auth_message(
    device_id: &str,
    slug: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-INVITE-REDEEM-V1\ndevice_id={}\nslug={}\nts_ms={}\nnonce_b64={}\n",
        device_id, slug, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_room_call_get_auth_message(
    device_id: &str,
    room_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-CALL-GET-V1\ndevice_id={}\nroom_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, ts_ms, nonce_b64,
    )
    .into_bytes()
}

fn http_room_call_join_auth_message(
    device_id: &str,
    room_id: &str,
    media_type: &str,
    supports_video: bool,
    supports_screen_share: bool,
    muted: bool,
    deafened: bool,
    video_enabled: bool,
    screen_share_enabled: bool,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-CALL-JOIN-V1\ndevice_id={}\nroom_id={}\nmedia_type={}\nsupports_video={}\nsupports_screen_share={}\nmuted={}\ndeafened={}\nvideo_enabled={}\nscreen_share_enabled={}\nts_ms={}\nnonce_b64={}\n",
        device_id,
        room_id,
        media_type,
        if supports_video { 1 } else { 0 },
        if supports_screen_share { 1 } else { 0 },
        if muted { 1 } else { 0 },
        if deafened { 1 } else { 0 },
        if video_enabled { 1 } else { 0 },
        if screen_share_enabled { 1 } else { 0 },
        ts_ms,
        nonce_b64,
    )
    .into_bytes()
}

fn http_room_call_self_update_auth_message(
    device_id: &str,
    room_id: &str,
    call_id: &str,
    reconnecting: bool,
    muted: bool,
    deafened: bool,
    video_enabled: bool,
    screen_share_enabled: bool,
    speaking: bool,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-CALL-SELF-UPDATE-V1\ndevice_id={}\nroom_id={}\ncall_id={}\nreconnecting={}\nmuted={}\ndeafened={}\nvideo_enabled={}\nscreen_share_enabled={}\nspeaking={}\nts_ms={}\nnonce_b64={}\n",
        device_id,
        room_id,
        call_id,
        if reconnecting { 1 } else { 0 },
        if muted { 1 } else { 0 },
        if deafened { 1 } else { 0 },
        if video_enabled { 1 } else { 0 },
        if screen_share_enabled { 1 } else { 0 },
        if speaking { 1 } else { 0 },
        ts_ms,
        nonce_b64,
    )
    .into_bytes()
}

fn http_room_call_leave_auth_message(
    device_id: &str,
    room_id: &str,
    call_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-CALL-LEAVE-V1\ndevice_id={}\nroom_id={}\ncall_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, call_id, ts_ms, nonce_b64,
    )
    .into_bytes()
}

fn http_room_call_participant_remove_auth_message(
    device_id: &str,
    room_id: &str,
    call_id: &str,
    participant_device_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-CALL-PARTICIPANT-REMOVE-V1\ndevice_id={}\nroom_id={}\ncall_id={}\nparticipant_device_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, call_id, participant_device_id, ts_ms, nonce_b64,
    )
    .into_bytes()
}

fn http_room_call_end_auth_message(
    device_id: &str,
    room_id: &str,
    call_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-CALL-END-V1\ndevice_id={}\nroom_id={}\ncall_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, call_id, ts_ms, nonce_b64,
    )
    .into_bytes()
}

fn http_room_call_media_get_auth_message(
    device_id: &str,
    room_id: &str,
    call_id: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-CALL-MEDIA-GET-V1\ndevice_id={}\nroom_id={}\ncall_id={}\nts_ms={}\nnonce_b64={}\n",
        device_id, room_id, call_id, ts_ms, nonce_b64,
    )
    .into_bytes()
}

fn http_room_call_media_join_auth_message(
    device_id: &str,
    room_id: &str,
    call_id: &str,
    publish_audio: bool,
    publish_video: bool,
    publish_screen_share: bool,
    subscribe_all: bool,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-ROOM-CALL-MEDIA-JOIN-V1\ndevice_id={}\nroom_id={}\ncall_id={}\npublish_audio={}\npublish_video={}\npublish_screen_share={}\nsubscribe_all={}\nts_ms={}\nnonce_b64={}\n",
        device_id,
        room_id,
        call_id,
        if publish_audio { 1 } else { 0 },
        if publish_video { 1 } else { 0 },
        if publish_screen_share { 1 } else { 0 },
        if subscribe_all { 1 } else { 0 },
        ts_ms,
        nonce_b64,
    )
    .into_bytes()
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ServerMsg {
    Welcome {
        device_id: String,
        next_seq: u64,
    },
    SentOk {
        msg_id: String,
    },
    Deliver {
        device_id: String,
        seq: u64,
        msg_id: String,
        ciphertext_b64: String,
        transport_meta_json: Option<String>,
        /// ИД-1 / С-1 (17.09.2026): the device that authenticated when the
        /// message was sent. Absent for legacy rows. Old clients ignore it.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        from_device_id: Option<String>,
    },
    Error {
        code: String,
        message: String,
    },
    Pong,
}

#[derive(Deserialize)]
struct HttpSendReq {
    to_device_id: String,
    msg_id: String,
    ciphertext_b64: String,
    transport_meta_json: Option<String>,
    ttl_seconds: u32,
    // SERVER-SIDE SCHEDULED DELIVERY (2026-07-17): see ClientMsg::Send.
    #[serde(default)]
    deliver_at_ms: Option<i64>,
}

/// К-2 (17.09.2026): one sealed room message, handed to many devices.
#[derive(Deserialize)]
struct HttpRoomBroadcastReq {
    msg_id: String,
    ciphertext_b64: String,
    recipients: Vec<String>,
    ttl_seconds: u32,
    #[serde(default)]
    transport_meta_json: Option<String>,
    #[serde(default)]
    deliver_at_ms: Option<i64>,
}

#[derive(Serialize, Debug)]
struct HttpRoomBroadcastRejected {
    device_id: String,
    reason: &'static str,
}

#[derive(Serialize, Debug)]
struct HttpRoomBroadcastResp {
    ok: bool,
    accepted: Vec<String>,
    rejected: Vec<HttpRoomBroadcastRejected>,
}

/// Most recipient devices one broadcast may name: a big room (50 members)
/// with a generous number of devices each.
const ROOM_BROADCAST_MAX_RECIPIENTS: usize = 400;

#[derive(Serialize)]
struct HttpSendResp {
    ok: bool,
    seq: u64,
}

#[derive(Deserialize)]
struct HttpPendingCheckReq {
    device_id: String,
    to_device_id: String,
    msg_ids: Vec<String>,
}

#[derive(Serialize)]
struct HttpPendingCheckResp {
    /// Те из присланных msg_id, что реле ВСЁ ЕЩЁ держит для получателя.
    still_pending: Vec<String>,
}

#[derive(Deserialize)]
struct HttpAckReq {
    device_id: String,
    seq: u64,
    #[allow(dead_code)]
    msg_id: Option<String>,
}

#[derive(Serialize)]
struct HttpAckResp {
    ok: bool,
}

#[derive(Deserialize)]
struct HttpRebindReq {
    // The authenticated caller — the live (new) device reclaiming its mailbox.
    new_device_id: String,
    // The rotated-away (old) device whose un-acked pending should move to `new`.
    old_device_id: String,
}

#[derive(Serialize)]
struct HttpRebindResp {
    ok: bool,
    moved: u64,
}

#[derive(Deserialize)]
struct PendingQuery {
    from_seq: Option<u64>,
    limit: Option<u64>,
}

#[derive(Deserialize)]
struct BlobUploadQuery {
    ttl_seconds: Option<u64>,
}

#[derive(Serialize)]
struct HttpWelcomeResp {
    device_id: String,
    next_seq: u64,
}

#[derive(Serialize)]
struct PendingItem {
    seq: u64,
    msg_id: String,
    ciphertext_b64: String,
    transport_meta_json: Option<String>,
    /// ИД-1 / С-1: see `ServerMsg::Deliver::from_device_id`.
    #[serde(skip_serializing_if = "Option::is_none")]
    from_device_id: Option<String>,
}

#[derive(Serialize)]
struct HttpPendingResp {
    device_id: String,
    items: Vec<PendingItem>,
}

#[derive(Serialize)]
struct HttpCallSessionResp {
    exists: bool,
    device_id: String,
    call_id: String,
    call_attempt_id: String,
    peer_device_id: Option<String>,
    direction: Option<String>,
    state: Option<String>,
    last_action: Option<String>,
    last_signal_id: Option<String>,
    last_created_at_ms: Option<i64>,
    last_received_at_ms: Option<i64>,
    invited_at_ms: Option<i64>,
    accepted_at_ms: Option<i64>,
    offer_seen_at_ms: Option<i64>,
    answer_seen_at_ms: Option<i64>,
    reconnecting_at_ms: Option<i64>,
    ended_at_ms: Option<i64>,
    expires_at_ms: Option<i64>,
}

#[derive(Debug, Serialize)]
struct HttpIceServerResp {
    urls: Vec<String>,
    username: Option<String>,
    credential: Option<String>,
}

#[derive(Serialize)]
struct HttpIceConfigResp {
    device_id: String,
    policy: String,
    expires_at_ms: Option<i64>,
    ice_servers: Vec<HttpIceServerResp>,
}

#[derive(Serialize)]
struct BlobUploadResp {
    blob_id: String,
    size_bytes: u64,
    expires_at_ms: i64,
}

#[derive(Serialize)]
struct HttpBlocksListResp {
    device_id: String,
    blocked_profile_ids: Vec<String>,
}

// Sprint 2 R3: response shape for `GET /v1/active_devices/{profile_id}`.
//
// Contract for the client:
// - `filter_applied = false`: the staleness filter is disabled on this
//   relay deployment OR the relay has no activity rows for this profile.
//   The client MUST fall back to the unfiltered bundle returned by the
//   keys server and treat all known devices as targets.
// - `filter_applied = true`: the relay has at least one activity row
//   for this profile AND the staleness filter is enabled. `device_ids`
//   contains the subset that is currently considered live by the relay.
//   The client SHOULD intersect this set with its bundle-derived
//   device_ids before fanning out. If the intersection is empty, the
//   client MUST NOT silently drop the send — it should fall back to
//   the full bundle (treat it as "filter cannot be trusted").
//
// `now_ms` and `threshold_ms` are echoed back so the client can sanity-
// check its clock against the relay's and rate-limit re-queries
// without storing additional state.
#[derive(Serialize)]
struct HttpActiveDevicesResp {
    profile_id: String,
    filter_applied: bool,
    device_ids: Vec<String>,
    now_ms: i64,
    threshold_ms: i64,
    /// 🔴 КОГДА КАЖДОЕ УСТРОЙСТВО ПОДАВАЛО ПРИЗНАКИ ЖИЗНИ (15.08.2026).
    ///
    /// ЗАЧЕМ. Замер звонка показал: половина сигналов уходит на копию
    /// устройства, оставшуюся от переустановки (молчит 5 суток, токена пушей
    /// нет). Она не ответит никогда, но каждый её сигнал — запрос в лимит по
    /// IP, а лимит рвёт живой разговор.
    ///
    /// Сузить рассылку ОБЩИМ фильтром нельзя: сообщению копия не мешает — оно
    /// полежит в ящике и дождётся возвращения хозяина. Разница между
    /// сообщением и сигналом звонка в сроке годности: звонок живёт 45 секунд.
    ///
    /// Поэтому решение принимает КЛИЕНТ и только для эфемерного трафика, а
    /// реле лишь сообщает факты. Поле ДОБАВЛЕНО рядом со старым `device_ids`:
    /// клиенты, которые о нём не знают, ведут себя ровно как раньше.
    devices: Vec<HttpDeviceLiveness>,
}

/// Факт о жизни одного устройства: когда оно в последний раз забирало почту или
/// принимало доставленный пуш. Ноль означает «признаков не было».
#[derive(Serialize)]
struct HttpDeviceLiveness {
    device_id: String,
    last_signal_ms: i64,
    superseded: bool,
}

#[derive(Deserialize)]
struct HttpBlocksSetReq {
    blocked_profile_id: String,
    blocked: bool,
}

#[derive(Serialize)]
struct HttpBlocksSetResp {
    ok: bool,
}

#[derive(Deserialize)]
struct HttpPushTokenSetReq {
    token: String,
    platform: Option<String>,
    enabled: Option<bool>,
    policy_b64: Option<String>,
}

#[derive(Debug, Serialize)]
struct HttpPushTokenSetResp {
    ok: bool,
}

#[derive(Deserialize)]
struct HttpProfileDeleteReq {
    profile_id: String,
    device_ids: Option<Vec<String>>,
}

#[derive(Serialize)]
struct HttpProfileDeleteResp {
    ok: bool,
    profile_id: String,
    deleted_rows: i64,
    deleted_blob_count: usize,
}

#[derive(Deserialize)]
struct HttpRoomCreateReq {
    room_id: String,
    title: String,
}

#[derive(Deserialize)]
struct HttpRoomProfileUpdateReq {
    title: String,
    description: Option<String>,
    avatar_hash: Option<String>,
    avatar_image_b64: Option<String>,
    #[serde(default)]
    clear_avatar: bool,
}

#[derive(Deserialize)]
struct HttpRoomSettingsUpdateReq {
    reactions_mode: String,
    allow_text: bool,
    allow_media: bool,
    allow_add_members: bool,
    allow_pin_messages: bool,
    allow_change_group_info: bool,
    allow_change_tag: bool,
    join_approval_required: bool,
    slow_mode_seconds: i64,
    chat_history_visible: bool,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum HttpRoomMessageKind {
    Text,
    Media,
}

impl HttpRoomMessageKind {
    fn as_str(self) -> &'static str {
        match self {
            Self::Text => "text",
            Self::Media => "media",
        }
    }
}

#[derive(Deserialize)]
struct HttpRoomMessageAdmissionReq {
    message_id: String,
    kind: HttpRoomMessageKind,
}

#[derive(Deserialize)]
struct HttpRoomPinnedMessageSetReq {
    message_id: Option<String>,
}

#[derive(Deserialize)]
struct HttpRoomMemberTagSetReq {
    tag: Option<String>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum HttpRoomMembershipStatus {
    Active,
    Pending,
    Left,
    Removed,
    Banned,
}

impl HttpRoomMembershipStatus {
    fn as_str(self) -> &'static str {
        match self {
            Self::Active => "active",
            Self::Pending => "pending",
            Self::Left => "left",
            Self::Removed => "removed",
            Self::Banned => "banned",
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum HttpRoomMemberRole {
    Owner,
    Admin,
    Moderator,
    Member,
    Restricted,
    Guest,
}

impl HttpRoomMemberRole {
    fn as_str(self) -> &'static str {
        match self {
            Self::Owner => "owner",
            Self::Admin => "admin",
            Self::Moderator => "moderator",
            Self::Member => "member",
            Self::Restricted => "restricted",
            Self::Guest => "guest",
        }
    }
}

#[derive(Debug, Deserialize)]
struct HttpRoomMembershipUpsertReq {
    profile_id: String,
    status: HttpRoomMembershipStatus,
    role: HttpRoomMemberRole,
    source_link_id: Option<String>,
}

#[derive(Debug, Deserialize)]
struct HttpRoomTransferOwnershipReq {
    next_owner_profile_id: String,
}

#[derive(Debug, Deserialize)]
struct HttpRoomInviteLinkCreateReq {
    expires_at_ms: Option<i64>,
    max_uses: Option<i64>,
    requires_approval: Option<bool>,
    allowed_role: Option<HttpRoomMemberRole>,
}

#[derive(Debug, Deserialize)]
struct HttpRoomInviteLinkRevokeReq {
    revoked: bool,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum HttpRoomCallState {
    Active,
    Ended,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum HttpRoomCallMediaType {
    Audio,
    Video,
}

impl HttpRoomCallMediaType {
    fn as_str(self) -> &'static str {
        match self {
            Self::Audio => "audio",
            Self::Video => "video",
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum HttpRoomCallJoinState {
    Joined,
    Reconnecting,
    Left,
    Removed,
}

#[derive(Debug, Deserialize)]
struct HttpRoomCallJoinReq {
    media_type: HttpRoomCallMediaType,
    supports_video: bool,
    supports_screen_share: bool,
    muted: bool,
    deafened: bool,
    video_enabled: bool,
    screen_share_enabled: bool,
}

#[derive(Debug, Deserialize)]
struct HttpRoomCallParticipantUpdateReq {
    reconnecting: bool,
    muted: bool,
    deafened: bool,
    video_enabled: bool,
    screen_share_enabled: bool,
    speaking: bool,
}

#[derive(Debug, Serialize)]
struct HttpRoomResp {
    room_id: String,
    version: i64,
    membership_version: i64,
    owner_profile_id: String,
    created_by_device_id: String,
    title: String,
    description: Option<String>,
    avatar_hash: Option<String>,
    avatar_image_b64: Option<String>,
    reactions_mode: String,
    allow_text: bool,
    allow_media: bool,
    allow_add_members: bool,
    allow_pin_messages: bool,
    allow_change_group_info: bool,
    allow_change_tag: bool,
    join_approval_required: bool,
    slow_mode_seconds: i64,
    chat_history_visible: bool,
    pinned_message_id: Option<String>,
    created_at_ms: i64,
    updated_at_ms: i64,
}

#[derive(Debug, Serialize)]
struct HttpRoomMembershipResp {
    room_id: String,
    profile_id: String,
    status: HttpRoomMembershipStatus,
    role: HttpRoomMemberRole,
    source_link_id: Option<String>,
    tag: Option<String>,
    created_at_ms: i64,
    updated_at_ms: i64,
}

#[derive(Debug, Serialize)]
struct HttpRoomCreateResp {
    ok: bool,
    created: bool,
    room: HttpRoomResp,
}

#[derive(Debug, Serialize)]
struct HttpRoomMembersResp {
    room: HttpRoomResp,
    members: Vec<HttpRoomMembershipResp>,
}

#[derive(Debug, Serialize)]
struct HttpRoomMembershipUpsertResp {
    ok: bool,
    changed: bool,
    room: HttpRoomResp,
    membership: HttpRoomMembershipResp,
}

#[derive(Debug, Serialize)]
struct HttpRoomStateUpdateResp {
    ok: bool,
    changed: bool,
    room: HttpRoomResp,
}

#[derive(Debug, Serialize)]
struct HttpRoomLeaveResp {
    ok: bool,
    changed: bool,
    room: HttpRoomResp,
    membership: HttpRoomMembershipResp,
}

#[derive(Debug, Serialize)]
struct HttpRoomDeleteResp {
    ok: bool,
    room: HttpRoomResp,
    deleted_profile_ids: Vec<String>,
}

#[derive(Debug, Serialize)]
struct HttpRoomTransferOwnershipResp {
    ok: bool,
    room: HttpRoomResp,
    previous_owner_membership: HttpRoomMembershipResp,
    next_owner_membership: HttpRoomMembershipResp,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum HttpRoomInviteAvailability {
    Available,
    AlreadyActive,
    AlreadyPending,
    Banned,
    Revoked,
    Expired,
    UsageLimitReached,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum HttpRoomInviteJoinDisposition {
    Active,
    PendingApproval,
}

#[derive(Debug, Serialize)]
struct HttpRoomInviteLinkResp {
    link_id: String,
    room_id: String,
    slug: String,
    created_by_profile_id: String,
    expires_at_ms: Option<i64>,
    max_uses: Option<i64>,
    use_count: i64,
    remaining_uses: Option<i64>,
    requires_approval: bool,
    allowed_role: HttpRoomMemberRole,
    revoked: bool,
    created_at_ms: i64,
    updated_at_ms: i64,
}

#[derive(Debug, Serialize)]
struct HttpRoomInviteLinksResp {
    room: HttpRoomResp,
    invite_links: Vec<HttpRoomInviteLinkResp>,
}

#[derive(Debug, Serialize)]
struct HttpRoomInviteLinkCreateResp {
    ok: bool,
    room: HttpRoomResp,
    invite_link: HttpRoomInviteLinkResp,
}

#[derive(Debug, Serialize)]
struct HttpRoomInviteLinkRevokeResp {
    ok: bool,
    changed: bool,
    room: HttpRoomResp,
    invite_link: HttpRoomInviteLinkResp,
}

#[derive(Debug, Serialize)]
struct HttpRoomInvitePreviewResp {
    room: HttpRoomResp,
    invite_link: HttpRoomInviteLinkResp,
    active_member_count: i64,
    availability: HttpRoomInviteAvailability,
    requester_membership: Option<HttpRoomMembershipResp>,
}

#[derive(Debug, Serialize)]
struct HttpRoomInviteRedeemResp {
    ok: bool,
    changed: bool,
    disposition: HttpRoomInviteJoinDisposition,
    room: HttpRoomResp,
    invite_link: HttpRoomInviteLinkResp,
    membership: HttpRoomMembershipResp,
}

#[derive(Debug, Serialize)]
struct HttpRoomMessageAdmissionResp {
    ok: bool,
    message_id: String,
    kind: HttpRoomMessageKind,
    admitted_at_ms: i64,
    next_allowed_at_ms: Option<i64>,
    room: HttpRoomResp,
}

#[derive(Debug, Serialize)]
struct HttpRoomErrorResp {
    code: String,
    message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    retry_after_seconds: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    next_allowed_at_ms: Option<i64>,
}

#[derive(Debug, Serialize)]
struct HttpRoomCallResp {
    call_id: String,
    room_id: String,
    state: HttpRoomCallState,
    media_type: HttpRoomCallMediaType,
    created_by_profile_id: String,
    created_by_device_id: String,
    state_version: i64,
    started_at_ms: i64,
    updated_at_ms: i64,
    ended_at_ms: Option<i64>,
    expires_at_ms: i64,
}

#[derive(Debug, Serialize)]
struct HttpRoomCallParticipantResp {
    call_id: String,
    room_id: String,
    profile_id: String,
    device_id: String,
    join_state: HttpRoomCallJoinState,
    supports_video: bool,
    supports_screen_share: bool,
    muted: bool,
    deafened: bool,
    video_enabled: bool,
    screen_share_enabled: bool,
    speaking: bool,
    joined_at_ms: i64,
    left_at_ms: Option<i64>,
    updated_at_ms: i64,
}

#[derive(Debug, Serialize)]
struct HttpRoomCallSnapshotResp {
    exists: bool,
    room: HttpRoomResp,
    call: Option<HttpRoomCallResp>,
    participants: Vec<HttpRoomCallParticipantResp>,
    self_participant: Option<HttpRoomCallParticipantResp>,
}

#[derive(Debug, Serialize)]
struct HttpRoomCallMutationResp {
    ok: bool,
    changed: bool,
    room: HttpRoomResp,
    call: HttpRoomCallResp,
    participants: Vec<HttpRoomCallParticipantResp>,
    self_participant: Option<HttpRoomCallParticipantResp>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum HttpRoomCallMediaTopology {
    Centralized,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum HttpRoomCallMediaCapabilityState {
    BootstrapOnly,
    SessionAuthReady,
    RuntimeReady,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum HttpRoomCallMediaBackendKind {
    Unavailable,
    Livekit,
}

#[derive(Debug, Deserialize)]
struct HttpRoomCallMediaJoinReq {
    publish_audio: bool,
    publish_video: bool,
    publish_screen_share: bool,
    subscribe_all: bool,
}

#[derive(Debug, Serialize)]
struct HttpRoomCallMediaIceResp {
    policy: String,
    expires_at_ms: Option<i64>,
    ice_servers: Vec<HttpIceServerResp>,
}

#[derive(Debug, Serialize)]
struct HttpRoomCallMediaParticipantResp {
    profile_id: String,
    device_id: String,
    join_state: HttpRoomCallJoinState,
    is_self: bool,
    supports_video: bool,
    supports_screen_share: bool,
    muted: bool,
    deafened: bool,
    video_enabled: bool,
    screen_share_enabled: bool,
    speaking: bool,
    publish_audio: bool,
    publish_video: bool,
    publish_screen_share: bool,
    receive_audio: bool,
    receive_video: bool,
    receive_screen_share: bool,
    updated_at_ms: i64,
}

#[derive(Debug, Serialize)]
struct HttpRoomCallMediaSignalResp {
    transport_kind: String,
    descriptor_version: i64,
}

#[derive(Debug, Serialize)]
struct HttpRoomCallMediaBackendResp {
    kind: HttpRoomCallMediaBackendKind,
    url: Option<String>,
    room_name: Option<String>,
    participant_identity: Option<String>,
    access_token: Option<String>,
    access_token_expires_at_ms: Option<i64>,
}

#[derive(Debug, Serialize)]
struct HttpRoomCallMediaResp {
    room_id: String,
    call_id: String,
    session_id: String,
    contract_version: String,
    topology: HttpRoomCallMediaTopology,
    capability_state: HttpRoomCallMediaCapabilityState,
    media_type: HttpRoomCallMediaType,
    state_version: i64,
    self_profile_id: String,
    self_device_id: String,
    participant_count: usize,
    publish_video_supported: bool,
    publish_screen_share_supported: bool,
    subscribe_all_supported: bool,
    backend: HttpRoomCallMediaBackendResp,
    signal: HttpRoomCallMediaSignalResp,
    ice: HttpRoomCallMediaIceResp,
    participants: Vec<HttpRoomCallMediaParticipantResp>,
}

#[derive(Debug, Serialize)]
struct HttpRoomCallMediaJoinResp {
    ok: bool,
    media: HttpRoomCallMediaResp,
}

fn room_to_http_resp(room: RoomRow) -> HttpRoomResp {
    HttpRoomResp {
        room_id: room.room_id,
        version: room.version,
        membership_version: room.membership_version,
        owner_profile_id: room.owner_profile_id,
        created_by_device_id: room.created_by_device_id,
        title: room.title,
        description: room.description,
        avatar_hash: room.avatar_hash,
        avatar_image_b64: room.avatar_image_b64,
        reactions_mode: room.reactions_mode,
        allow_text: room.allow_text,
        allow_media: room.allow_media,
        allow_add_members: room.allow_add_members,
        allow_pin_messages: room.allow_pin_messages,
        allow_change_group_info: room.allow_change_group_info,
        allow_change_tag: room.allow_change_tag,
        join_approval_required: room.join_approval_required,
        slow_mode_seconds: room.slow_mode_seconds,
        chat_history_visible: room.chat_history_visible,
        pinned_message_id: room.pinned_message_id,
        created_at_ms: room.created_at_ms,
        updated_at_ms: room.updated_at_ms,
    }
}

fn room_membership_status_from_str(
    value: &str,
) -> Result<HttpRoomMembershipStatus, (StatusCode, String)> {
    match value.trim().to_ascii_lowercase().as_str() {
        "active" => Ok(HttpRoomMembershipStatus::Active),
        "pending" => Ok(HttpRoomMembershipStatus::Pending),
        "left" => Ok(HttpRoomMembershipStatus::Left),
        "removed" => Ok(HttpRoomMembershipStatus::Removed),
        "banned" => Ok(HttpRoomMembershipStatus::Banned),
        _ => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            "invalid stored room membership status".into(),
        )),
    }
}

fn room_member_role_from_str(value: &str) -> Result<HttpRoomMemberRole, (StatusCode, String)> {
    match value.trim().to_ascii_lowercase().as_str() {
        "owner" => Ok(HttpRoomMemberRole::Owner),
        "admin" => Ok(HttpRoomMemberRole::Admin),
        "moderator" => Ok(HttpRoomMemberRole::Moderator),
        "member" => Ok(HttpRoomMemberRole::Member),
        "restricted" => Ok(HttpRoomMemberRole::Restricted),
        "guest" | "read_only" | "readonly" | "read-only" => Ok(HttpRoomMemberRole::Guest),
        _ => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            "invalid stored room member role".into(),
        )),
    }
}

fn room_membership_to_http_resp(
    membership: RoomMembershipRow,
) -> Result<HttpRoomMembershipResp, (StatusCode, String)> {
    Ok(HttpRoomMembershipResp {
        room_id: membership.room_id,
        profile_id: membership.profile_id,
        status: room_membership_status_from_str(&membership.status)?,
        role: room_member_role_from_str(&membership.role)?,
        source_link_id: membership.source_link_id,
        tag: membership.tag,
        created_at_ms: membership.created_at_ms,
        updated_at_ms: membership.updated_at_ms,
    })
}

fn room_call_state_from_str(value: &str) -> Result<HttpRoomCallState, (StatusCode, String)> {
    match value.trim().to_ascii_lowercase().as_str() {
        "active" => Ok(HttpRoomCallState::Active),
        "ended" => Ok(HttpRoomCallState::Ended),
        _ => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            "invalid stored room call state".into(),
        )),
    }
}

fn room_call_media_type_from_str(
    value: &str,
) -> Result<HttpRoomCallMediaType, (StatusCode, String)> {
    match value.trim().to_ascii_lowercase().as_str() {
        "audio" => Ok(HttpRoomCallMediaType::Audio),
        "video" => Ok(HttpRoomCallMediaType::Video),
        _ => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            "invalid stored room call media type".into(),
        )),
    }
}

fn room_call_join_state_from_str(
    value: &str,
) -> Result<HttpRoomCallJoinState, (StatusCode, String)> {
    match value.trim().to_ascii_lowercase().as_str() {
        "joined" => Ok(HttpRoomCallJoinState::Joined),
        "reconnecting" => Ok(HttpRoomCallJoinState::Reconnecting),
        "left" => Ok(HttpRoomCallJoinState::Left),
        "removed" => Ok(HttpRoomCallJoinState::Removed),
        _ => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            "invalid stored room call participant state".into(),
        )),
    }
}

fn room_call_to_http_resp(call: RoomCallRow) -> Result<HttpRoomCallResp, (StatusCode, String)> {
    Ok(HttpRoomCallResp {
        call_id: call.call_id,
        room_id: call.room_id,
        state: room_call_state_from_str(&call.state)?,
        media_type: room_call_media_type_from_str(&call.media_type)?,
        created_by_profile_id: call.created_by_profile_id,
        created_by_device_id: call.created_by_device_id,
        state_version: call.state_version,
        started_at_ms: call.started_at_ms,
        updated_at_ms: call.updated_at_ms,
        ended_at_ms: call.ended_at_ms,
        expires_at_ms: call.expires_at_ms,
    })
}

fn room_call_participant_to_http_resp(
    participant: RoomCallParticipantRow,
) -> Result<HttpRoomCallParticipantResp, (StatusCode, String)> {
    Ok(HttpRoomCallParticipantResp {
        call_id: participant.call_id,
        room_id: participant.room_id,
        profile_id: participant.profile_id,
        device_id: participant.device_id,
        join_state: room_call_join_state_from_str(&participant.join_state)?,
        supports_video: participant.supports_video,
        supports_screen_share: participant.supports_screen_share,
        muted: participant.muted,
        deafened: participant.deafened,
        video_enabled: participant.video_enabled,
        screen_share_enabled: participant.screen_share_enabled,
        speaking: participant.speaking,
        joined_at_ms: participant.joined_at_ms,
        left_at_ms: participant.left_at_ms,
        updated_at_ms: participant.updated_at_ms,
    })
}

fn room_call_snapshot_to_http_parts(
    snapshot: RoomCallSnapshot,
) -> Result<
    (
        HttpRoomResp,
        HttpRoomCallResp,
        Vec<HttpRoomCallParticipantResp>,
        Option<HttpRoomCallParticipantResp>,
    ),
    (StatusCode, String),
> {
    let room = room_to_http_resp(snapshot.room);
    let call = room_call_to_http_resp(snapshot.call)?;
    let participants = snapshot
        .participants
        .into_iter()
        .map(room_call_participant_to_http_resp)
        .collect::<Result<Vec<_>, _>>()?;
    let self_participant = snapshot
        .self_participant
        .map(room_call_participant_to_http_resp)
        .transpose()?;
    Ok((room, call, participants, self_participant))
}

fn room_call_participant_is_joined(join_state: &str) -> bool {
    matches!(
        join_state.trim().to_ascii_lowercase().as_str(),
        "joined" | "reconnecting"
    )
}

fn build_http_ice_config_resp_for_device(
    state: &AppState,
    device_id: &str,
) -> Result<HttpIceConfigResp, (StatusCode, String)> {
    let cfg = state.call_ice.as_ref();
    let mut ice_servers: Vec<HttpIceServerResp> = cfg
        .stun_urls
        .iter()
        .cloned()
        .map(|url| HttpIceServerResp {
            urls: vec![url],
            username: None,
            credential: None,
        })
        .collect();

    let mut expires_at_ms = None;
    let turn_secret = cfg.turn_shared_secret.trim();
    if !cfg.turn_urls.is_empty() && !turn_secret.is_empty() {
        let ttl_seconds = cfg.turn_ttl_seconds as i64;
        let expires_at_s = (now_ms() / 1000) + ttl_seconds;
        let username = build_turn_rest_username(device_id, expires_at_s);
        let credential = build_turn_rest_credential(turn_secret, &username).ok_or((
            StatusCode::INTERNAL_SERVER_ERROR,
            "turn credential generation failed".into(),
        ))?;
        expires_at_ms = Some(expires_at_s * 1000);
        ice_servers.extend(cfg.turn_urls.iter().cloned().map(|url| HttpIceServerResp {
            urls: vec![url],
            username: Some(username.clone()),
            credential: Some(credential.clone()),
        }));
    }

    let has_turn = ice_servers.iter().any(|server| {
        server
            .urls
            .iter()
            .any(|url| url.starts_with("turn:") || url.starts_with("turns:"))
    });

    Ok(HttpIceConfigResp {
        device_id: device_id.to_string(),
        policy: effective_call_ice_policy(&cfg.policy, has_turn),
        expires_at_ms,
        ice_servers,
    })
}

fn room_call_media_ice_from_http_config(config: HttpIceConfigResp) -> HttpRoomCallMediaIceResp {
    HttpRoomCallMediaIceResp {
        policy: config.policy,
        expires_at_ms: config.expires_at_ms,
        ice_servers: config.ice_servers,
    }
}

fn room_call_media_descriptor_version(snapshot: &RoomCallSnapshot) -> i64 {
    let mut descriptor_version = snapshot.call.updated_at_ms.max(snapshot.call.state_version);
    for participant in &snapshot.participants {
        descriptor_version = descriptor_version.max(participant.updated_at_ms);
    }
    for media_participant in &snapshot.media_participants {
        descriptor_version = descriptor_version.max(media_participant.updated_at_ms);
    }
    descriptor_version
}

fn room_media_backend_safe_segment(value: &str, max_len: usize) -> String {
    let mut out = String::new();
    for ch in value.chars() {
        let next = if ch.is_ascii_alphanumeric() || ch == '-' || ch == '_' {
            ch
        } else {
            '_'
        };
        out.push(next);
        if out.len() >= max_len {
            break;
        }
    }
    if out.is_empty() { "x".to_string() } else { out }
}

fn room_media_backend_hash_suffix(value: &str, max_len: usize) -> String {
    let encoded =
        base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(Sha256::digest(value.as_bytes()));
    encoded.chars().take(max_len).collect()
}

fn room_media_backend_room_name(room_id: &str, call_id: &str) -> String {
    let room_segment = room_media_backend_safe_segment(room_id, 18);
    let suffix = room_media_backend_hash_suffix(&format!("{room_id}:{call_id}"), 10);
    format!("secretly-room-{room_segment}-{suffix}")
}

fn room_media_backend_participant_identity(profile_id: &str, device_id: &str) -> String {
    let device_segment = room_media_backend_safe_segment(device_id, 18);
    let suffix = room_media_backend_hash_suffix(&format!("{profile_id}:{device_id}"), 10);
    format!("secretly-participant-{device_segment}-{suffix}")
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct LiveKitVideoGrantClaims {
    room: String,
    room_join: bool,
    can_publish: bool,
    can_publish_data: bool,
    can_subscribe: bool,
}

#[derive(Debug, Serialize)]
struct LiveKitAccessTokenClaims {
    exp: i64,
    iss: String,
    sub: String,
    nbf: i64,
    video: LiveKitVideoGrantClaims,
    metadata: String,
}

fn build_livekit_room_media_access_token(
    config: &RelayRoomMediaRuntimeConfig,
    room_id: &str,
    call_id: &str,
    session_id: &str,
    requester_profile_id: &str,
    requester_device_id: &str,
    room_name: &str,
    participant_identity: &str,
) -> Result<(String, i64), (StatusCode, String)> {
    let now_s = now_ms() / 1000;
    let expires_at_s = now_s + config.token_ttl_seconds as i64;
    let metadata = serde_json::json!({
        "room_id": room_id,
        "call_id": call_id,
        "session_id": session_id,
        "profile_id": requester_profile_id,
        "device_id": requester_device_id,
        "contract_version": "room_media_v1",
    })
    .to_string();
    let claims = LiveKitAccessTokenClaims {
        exp: expires_at_s,
        iss: config.livekit_api_key.clone(),
        sub: participant_identity.to_string(),
        nbf: now_s.saturating_sub(5),
        video: LiveKitVideoGrantClaims {
            room: room_name.to_string(),
            room_join: true,
            can_publish: true,
            can_publish_data: true,
            can_subscribe: true,
        },
        metadata,
    };
    let token = jsonwebtoken::encode(
        &Header::new(Algorithm::HS256),
        &claims,
        &EncodingKey::from_secret(config.livekit_api_secret.as_bytes()),
    )
    .map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("room media backend token generation failed: {err}"),
        )
    })?;
    Ok((token, expires_at_s * 1000))
}

fn room_call_media_backend_resp(
    state: &AppState,
    snapshot: &RoomCallSnapshot,
    requester_device_id: &str,
    requester_profile_id: &str,
    requester_is_joined: bool,
) -> Result<
    (
        HttpRoomCallMediaBackendResp,
        HttpRoomCallMediaCapabilityState,
    ),
    (StatusCode, String),
> {
    let config = state.room_media.as_ref();
    let room_name = room_media_backend_room_name(&snapshot.call.room_id, &snapshot.call.call_id);
    match config.effective_backend {
        RelayRoomMediaBackendKind::Livekit => {
            if !requester_is_joined {
                return Ok((
                    HttpRoomCallMediaBackendResp {
                        kind: HttpRoomCallMediaBackendKind::Livekit,
                        url: Some(config.livekit_url.clone()),
                        room_name: Some(room_name),
                        participant_identity: None,
                        access_token: None,
                        access_token_expires_at_ms: None,
                    },
                    HttpRoomCallMediaCapabilityState::BootstrapOnly,
                ));
            }

            let participant_identity =
                room_media_backend_participant_identity(requester_profile_id, requester_device_id);
            let (access_token, access_token_expires_at_ms) = build_livekit_room_media_access_token(
                config,
                &snapshot.call.room_id,
                &snapshot.call.call_id,
                &snapshot.call.call_id,
                requester_profile_id,
                requester_device_id,
                &room_name,
                &participant_identity,
            )?;
            Ok((
                HttpRoomCallMediaBackendResp {
                    kind: HttpRoomCallMediaBackendKind::Livekit,
                    url: Some(config.livekit_url.clone()),
                    room_name: Some(room_name),
                    participant_identity: Some(participant_identity),
                    access_token: Some(access_token),
                    access_token_expires_at_ms: Some(access_token_expires_at_ms),
                },
                HttpRoomCallMediaCapabilityState::SessionAuthReady,
            ))
        }
        RelayRoomMediaBackendKind::Unavailable => Ok((
            HttpRoomCallMediaBackendResp {
                kind: HttpRoomCallMediaBackendKind::Unavailable,
                url: None,
                room_name: None,
                participant_identity: None,
                access_token: None,
                access_token_expires_at_ms: None,
            },
            HttpRoomCallMediaCapabilityState::BootstrapOnly,
        )),
    }
}

fn room_call_media_participant_to_http_resp(
    participant: &RoomCallParticipantRow,
    self_device_id: &str,
    media_registration: Option<&RoomCallMediaParticipantRow>,
) -> Result<HttpRoomCallMediaParticipantResp, (StatusCode, String)> {
    let is_self = participant.device_id == self_device_id;
    let joined = room_call_participant_is_joined(&participant.join_state);
    let publish_audio_requested = media_registration
        .map(|value| value.publish_audio)
        .unwrap_or(false);
    let publish_video_requested = media_registration
        .map(|value| value.publish_video)
        .unwrap_or(false);
    let publish_screen_share_requested = media_registration
        .map(|value| value.publish_screen_share)
        .unwrap_or(false);
    let subscribe_all = media_registration
        .map(|value| value.subscribe_all)
        .unwrap_or(false);

    Ok(HttpRoomCallMediaParticipantResp {
        profile_id: participant.profile_id.clone(),
        device_id: participant.device_id.clone(),
        join_state: room_call_join_state_from_str(&participant.join_state)?,
        is_self,
        supports_video: participant.supports_video,
        supports_screen_share: participant.supports_screen_share,
        muted: participant.muted,
        deafened: participant.deafened,
        video_enabled: participant.video_enabled,
        screen_share_enabled: participant.screen_share_enabled,
        speaking: participant.speaking,
        publish_audio: publish_audio_requested
            && joined
            && !participant.muted
            && !participant.deafened,
        publish_video: publish_video_requested
            && joined
            && participant.supports_video
            && participant.video_enabled,
        publish_screen_share: publish_screen_share_requested
            && joined
            && participant.supports_screen_share
            && participant.screen_share_enabled,
        receive_audio: joined && !participant.deafened && subscribe_all,
        receive_video: joined && subscribe_all,
        receive_screen_share: joined && subscribe_all,
        updated_at_ms: participant.updated_at_ms,
    })
}

fn room_call_snapshot_to_media_resp(
    state: &AppState,
    snapshot: &RoomCallSnapshot,
    requester_device_id: &str,
    requester_profile_id: &str,
) -> Result<HttpRoomCallMediaResp, (StatusCode, String)> {
    let self_participant = snapshot.self_participant.as_ref().or_else(|| {
        snapshot
            .participants
            .iter()
            .find(|participant| participant.device_id == requester_device_id)
    });
    let requester_is_joined = self_participant
        .map(|participant| room_call_participant_is_joined(&participant.join_state))
        .unwrap_or(false);
    let ice = room_call_media_ice_from_http_config(build_http_ice_config_resp_for_device(
        state,
        requester_device_id,
    )?);
    let participants = snapshot
        .participants
        .iter()
        .map(|participant| {
            let media_registration = snapshot.media_participants.iter().find(|value| {
                value.device_id == participant.device_id && value.call_id == participant.call_id
            });
            room_call_media_participant_to_http_resp(
                participant,
                requester_device_id,
                media_registration,
            )
        })
        .collect::<Result<Vec<_>, _>>()?;
    let descriptor_version = room_call_media_descriptor_version(snapshot);
    let (backend, capability_state) = room_call_media_backend_resp(
        state,
        snapshot,
        requester_device_id,
        requester_profile_id,
        requester_is_joined,
    )?;
    Ok(HttpRoomCallMediaResp {
        room_id: snapshot.call.room_id.clone(),
        call_id: snapshot.call.call_id.clone(),
        session_id: snapshot.call.call_id.clone(),
        contract_version: "room_media_v1".to_string(),
        topology: HttpRoomCallMediaTopology::Centralized,
        capability_state,
        media_type: room_call_media_type_from_str(&snapshot.call.media_type)?,
        state_version: snapshot.call.state_version,
        self_profile_id: requester_profile_id.to_string(),
        self_device_id: requester_device_id.to_string(),
        participant_count: participants.len(),
        publish_video_supported: self_participant
            .map(|participant| participant.supports_video)
            .unwrap_or(false),
        publish_screen_share_supported: self_participant
            .map(|participant| participant.supports_screen_share)
            .unwrap_or(false),
        subscribe_all_supported: true,
        backend,
        signal: HttpRoomCallMediaSignalResp {
            transport_kind: "room_call_media_signal_v1".to_string(),
            descriptor_version,
        },
        ice,
        participants,
    })
}

fn normalize_room_invite_expires_at_ms(expires_at_ms: Option<i64>) -> Option<i64> {
    expires_at_ms.filter(|value| *value > 0)
}

fn normalize_room_invite_max_uses(max_uses: Option<i64>) -> Option<i64> {
    max_uses.filter(|value| *value > 0)
}

fn normalize_room_invite_allowed_role(role: Option<HttpRoomMemberRole>) -> HttpRoomMemberRole {
    match role.unwrap_or(HttpRoomMemberRole::Member) {
        HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin | HttpRoomMemberRole::Moderator => {
            HttpRoomMemberRole::Member
        }
        HttpRoomMemberRole::Member => HttpRoomMemberRole::Member,
        HttpRoomMemberRole::Restricted => HttpRoomMemberRole::Restricted,
        HttpRoomMemberRole::Guest => HttpRoomMemberRole::Guest,
    }
}

fn room_invite_remaining_uses(max_uses: Option<i64>, use_count: i64) -> Option<i64> {
    max_uses.map(|value| (value - use_count).max(0))
}

fn room_invite_link_to_http_resp(
    invite_link: RoomInviteLinkRow,
) -> Result<HttpRoomInviteLinkResp, (StatusCode, String)> {
    let allowed_role = normalize_room_invite_allowed_role(Some(room_member_role_from_str(
        &invite_link.allowed_role,
    )?));
    Ok(HttpRoomInviteLinkResp {
        link_id: invite_link.link_id,
        room_id: invite_link.room_id,
        slug: invite_link.slug,
        created_by_profile_id: invite_link.created_by_profile_id,
        expires_at_ms: invite_link.expires_at_ms,
        max_uses: invite_link.max_uses,
        use_count: invite_link.use_count,
        remaining_uses: room_invite_remaining_uses(invite_link.max_uses, invite_link.use_count),
        requires_approval: invite_link.requires_approval,
        allowed_role,
        revoked: invite_link.revoked,
        created_at_ms: invite_link.created_at_ms,
        updated_at_ms: invite_link.updated_at_ms,
    })
}

fn room_invite_availability(
    invite_link: &RoomInviteLinkRow,
    requester_membership: Option<&RoomMembershipRow>,
    now_ms: i64,
) -> HttpRoomInviteAvailability {
    match requester_membership.map(|membership| membership.status.as_str()) {
        Some("active") => return HttpRoomInviteAvailability::AlreadyActive,
        Some("pending") => return HttpRoomInviteAvailability::AlreadyPending,
        Some("banned") => return HttpRoomInviteAvailability::Banned,
        _ => {}
    }

    if invite_link.revoked {
        return HttpRoomInviteAvailability::Revoked;
    }
    if let Some(expires_at_ms) = invite_link.expires_at_ms {
        if expires_at_ms <= now_ms {
            return HttpRoomInviteAvailability::Expired;
        }
    }
    if let Some(max_uses) = invite_link.max_uses {
        if invite_link.use_count >= max_uses {
            return HttpRoomInviteAvailability::UsageLimitReached;
        }
    }

    HttpRoomInviteAvailability::Available
}

fn room_invite_join_disposition(
    status: HttpRoomMembershipStatus,
) -> Result<HttpRoomInviteJoinDisposition, (StatusCode, String)> {
    match status {
        HttpRoomMembershipStatus::Active => Ok(HttpRoomInviteJoinDisposition::Active),
        HttpRoomMembershipStatus::Pending => Ok(HttpRoomInviteJoinDisposition::PendingApproval),
        _ => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            "invalid invite redemption membership status".into(),
        )),
    }
}

fn normalize_room_source_link_id(
    source_link_id: Option<&str>,
) -> Result<Option<String>, (StatusCode, String)> {
    let normalized = source_link_id
        .map(|value| value.trim())
        .filter(|value| !value.is_empty())
        .map(|value| value.to_string());
    if let Some(value) = normalized.as_deref() {
        if !is_valid_id(value, 128) {
            return Err((StatusCode::BAD_REQUEST, "bad source_link_id".into()));
        }
    }
    Ok(normalized)
}

fn normalize_room_member_tag(tag: Option<&str>) -> Result<Option<String>, (StatusCode, String)> {
    let normalized = tag
        .map(|value| value.trim())
        .filter(|value| !value.is_empty())
        .map(|value| value.to_string());
    if let Some(value) = normalized.as_deref() {
        if value.chars().count() > 32 || value.chars().any(|ch| ch.is_control()) {
            return Err((StatusCode::BAD_REQUEST, "bad room member tag".into()));
        }
    }
    Ok(normalized)
}

async fn requester_profile_id_for_device(
    state: &AppState,
    requester_device_id: &str,
) -> Result<String, (StatusCode, String)> {
    fetch_profile_id(state, requester_device_id)
        .await
        .ok_or((StatusCode::UNAUTHORIZED, "unknown requester device".into()))
}

async fn ensure_room_active_member_access(
    state: &AppState,
    room: &RoomRow,
    requester_profile_id: &str,
) -> Result<(), (StatusCode, String)> {
    let membership = state
        .store
        .get_room_membership(&room.room_id, requester_profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    match membership {
        Some(membership) if membership.status == HttpRoomMembershipStatus::Active.as_str() => {
            Ok(())
        }
        _ => Err((StatusCode::FORBIDDEN, "forbidden".into())),
    }
}

async fn requester_room_role(
    state: &AppState,
    room: &RoomRow,
    requester_profile_id: &str,
) -> Result<HttpRoomMemberRole, (StatusCode, String)> {
    let membership = state
        .store
        .get_room_membership(&room.room_id, requester_profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::FORBIDDEN, "forbidden".into()))?;
    if membership.status != HttpRoomMembershipStatus::Active.as_str() {
        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
    }

    if requester_profile_id == room.owner_profile_id {
        return Ok(HttpRoomMemberRole::Owner);
    }

    room_member_role_from_str(&membership.role)
}

fn can_change_room_info(actor_role: HttpRoomMemberRole, room: &RoomRow) -> bool {
    match actor_role {
        HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin => true,
        HttpRoomMemberRole::Moderator | HttpRoomMemberRole::Member => room.allow_change_group_info,
        HttpRoomMemberRole::Restricted | HttpRoomMemberRole::Guest => false,
    }
}

fn can_change_own_room_tag(actor_role: HttpRoomMemberRole, room: &RoomRow) -> bool {
    match actor_role {
        HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin => true,
        HttpRoomMemberRole::Moderator | HttpRoomMemberRole::Member => room.allow_change_tag,
        HttpRoomMemberRole::Restricted | HttpRoomMemberRole::Guest => false,
    }
}

fn can_add_room_members(actor_role: HttpRoomMemberRole, room: &RoomRow) -> bool {
    match actor_role {
        HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin => true,
        HttpRoomMemberRole::Moderator | HttpRoomMemberRole::Member => room.allow_add_members,
        HttpRoomMemberRole::Restricted | HttpRoomMemberRole::Guest => false,
    }
}

fn can_pin_room_messages(actor_role: HttpRoomMemberRole, room: &RoomRow) -> bool {
    match actor_role {
        HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin | HttpRoomMemberRole::Moderator => {
            true
        }
        HttpRoomMemberRole::Member => room.allow_pin_messages,
        HttpRoomMemberRole::Restricted | HttpRoomMemberRole::Guest => false,
    }
}

fn can_manage_room_invite_links(actor_role: HttpRoomMemberRole) -> bool {
    matches!(
        actor_role,
        HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin
    )
}

// Owner/Admin can change room-wide settings (reactions mode, allow_text/media,
// join approval, slow mode, history visibility, etc.). Aliased to the
// invite-link rule today because both require the same Owner/Admin authority,
// but kept separate so future policy changes don't entangle the two.
fn can_manage_room_settings(actor_role: HttpRoomMemberRole) -> bool {
    matches!(
        actor_role,
        HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin
    )
}

fn can_assign_room_role(
    actor_role: HttpRoomMemberRole,
    target_current_role: HttpRoomMemberRole,
    target_next_role: HttpRoomMemberRole,
    is_target_self: bool,
) -> bool {
    if is_target_self {
        return false;
    }
    if target_current_role == HttpRoomMemberRole::Owner
        || target_next_role == HttpRoomMemberRole::Owner
    {
        return false;
    }

    match actor_role {
        HttpRoomMemberRole::Owner => true,
        HttpRoomMemberRole::Admin => {
            target_current_role != HttpRoomMemberRole::Admin
                && target_next_role != HttpRoomMemberRole::Admin
        }
        HttpRoomMemberRole::Moderator
        | HttpRoomMemberRole::Member
        | HttpRoomMemberRole::Restricted
        | HttpRoomMemberRole::Guest => false,
    }
}

fn can_moderate_room_member(
    actor_role: HttpRoomMemberRole,
    target_role: HttpRoomMemberRole,
    actor_profile_id: &str,
    target_profile_id: &str,
) -> bool {
    let cleaned_actor_profile_id = actor_profile_id.trim();
    let cleaned_target_profile_id = target_profile_id.trim();
    if cleaned_actor_profile_id.is_empty()
        || cleaned_target_profile_id.is_empty()
        || cleaned_actor_profile_id == cleaned_target_profile_id
        || target_role == HttpRoomMemberRole::Owner
    {
        return false;
    }

    match actor_role {
        HttpRoomMemberRole::Owner => true,
        HttpRoomMemberRole::Admin => target_role != HttpRoomMemberRole::Admin,
        HttpRoomMemberRole::Moderator => {
            target_role == HttpRoomMemberRole::Member
                || target_role == HttpRoomMemberRole::Restricted
                || target_role == HttpRoomMemberRole::Guest
        }
        HttpRoomMemberRole::Member | HttpRoomMemberRole::Restricted | HttpRoomMemberRole::Guest => {
            false
        }
    }
}

fn target_room_member_role(
    room: &RoomRow,
    target_profile_id: &str,
    target_membership: Option<&RoomMembershipRow>,
) -> Result<HttpRoomMemberRole, (StatusCode, String)> {
    if target_profile_id == room.owner_profile_id {
        return Ok(HttpRoomMemberRole::Owner);
    }

    target_membership
        .map(|membership| room_member_role_from_str(&membership.role))
        .transpose()?
        .or(Some(HttpRoomMemberRole::Member))
        .ok_or((
            StatusCode::INTERNAL_SERVER_ERROR,
            "invalid target role".into(),
        ))
}

fn can_direct_add_room_membership(
    actor_role: HttpRoomMemberRole,
    room: &RoomRow,
    target_current_status: Option<HttpRoomMembershipStatus>,
    target_current_role: HttpRoomMemberRole,
    req: &HttpRoomMembershipUpsertReq,
    target_current_source_link_id: Option<&str>,
    normalized_source_link_id: Option<&str>,
    is_target_self: bool,
) -> bool {
    if is_target_self
        || !can_add_room_members(actor_role, room)
        || req.status != HttpRoomMembershipStatus::Active
    {
        return false;
    }

    match target_current_status {
        None => req.role == HttpRoomMemberRole::Member && normalized_source_link_id.is_none(),
        Some(HttpRoomMembershipStatus::Removed | HttpRoomMembershipStatus::Left) => {
            matches!(
                target_current_role,
                HttpRoomMemberRole::Member
                    | HttpRoomMemberRole::Restricted
                    | HttpRoomMemberRole::Guest
            ) && req.role == target_current_role
                && target_current_source_link_id == normalized_source_link_id
        }
        Some(
            HttpRoomMembershipStatus::Active
            | HttpRoomMembershipStatus::Pending
            | HttpRoomMembershipStatus::Banned,
        ) => false,
    }
}

fn authorize_room_membership_upsert(
    actor_profile_id: &str,
    actor_role: HttpRoomMemberRole,
    room: &RoomRow,
    target_membership: Option<&RoomMembershipRow>,
    req: &HttpRoomMembershipUpsertReq,
    normalized_source_link_id: Option<&str>,
) -> Result<(), (StatusCode, String)> {
    let target_current_role = target_room_member_role(room, &req.profile_id, target_membership)?;
    let target_current_status = target_membership
        .map(|membership| room_membership_status_from_str(&membership.status))
        .transpose()?;
    let is_target_self = actor_profile_id == req.profile_id;

    if req.status == HttpRoomMembershipStatus::Left {
        return Err((
            StatusCode::BAD_REQUEST,
            "left mutations are not supported by this endpoint".into(),
        ));
    }

    if target_membership.is_none() {
        if req.status != HttpRoomMembershipStatus::Active
            && req.status != HttpRoomMembershipStatus::Pending
        {
            return Err((
                StatusCode::BAD_REQUEST,
                "membership must exist for this mutation".into(),
            ));
        }
        if can_direct_add_room_membership(
            actor_role,
            room,
            None,
            target_current_role,
            req,
            None,
            normalized_source_link_id,
            is_target_self,
        ) {
            return Ok(());
        }
        if !matches!(
            actor_role,
            HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin
        ) {
            return Err((StatusCode::FORBIDDEN, "forbidden".into()));
        }
        if !can_assign_room_role(
            actor_role,
            HttpRoomMemberRole::Member,
            req.role,
            is_target_self,
        ) {
            return Err((StatusCode::FORBIDDEN, "forbidden".into()));
        }
        return Ok(());
    }

    let target_membership = target_membership.expect("checked target membership presence");
    let current_status = target_current_status.expect("checked target membership status");
    let status_changed = current_status != req.status;
    let role_changed = target_current_role != req.role;
    let source_link_changed =
        target_membership.source_link_id.as_deref() != normalized_source_link_id;

    if !status_changed && !role_changed && !source_link_changed {
        if matches!(
            actor_role,
            HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin
        ) || can_moderate_room_member(
            actor_role,
            target_current_role,
            actor_profile_id,
            &req.profile_id,
        ) {
            return Ok(());
        }
        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
    }

    if role_changed {
        if status_changed {
            match req.status {
                HttpRoomMembershipStatus::Removed | HttpRoomMembershipStatus::Banned => {
                    if req.role != HttpRoomMemberRole::Member {
                        return Err((
                            StatusCode::BAD_REQUEST,
                            "moderation status changes must normalize role to member".into(),
                        ));
                    }
                }
                HttpRoomMembershipStatus::Active => {
                    if current_status == HttpRoomMembershipStatus::Pending {
                        return Err((
                            StatusCode::BAD_REQUEST,
                            "join approval cannot change role".into(),
                        ));
                    }
                    if current_status == HttpRoomMembershipStatus::Banned {
                        return Err((
                            StatusCode::BAD_REQUEST,
                            "banned memberships must be unbanned before activation".into(),
                        ));
                    }
                    if !matches!(
                        actor_role,
                        HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin
                    ) {
                        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
                    }
                    if !can_assign_room_role(
                        actor_role,
                        target_current_role,
                        req.role,
                        is_target_self,
                    ) {
                        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
                    }
                    return Ok(());
                }
                HttpRoomMembershipStatus::Pending | HttpRoomMembershipStatus::Left => {
                    return Err((
                        StatusCode::BAD_REQUEST,
                        "unsupported role change for this membership status".into(),
                    ));
                }
            }
        } else {
            if current_status != HttpRoomMembershipStatus::Active {
                return Err((
                    StatusCode::BAD_REQUEST,
                    "room roles can only be changed for active members".into(),
                ));
            }
            if !can_assign_room_role(actor_role, target_current_role, req.role, is_target_self) {
                return Err((StatusCode::FORBIDDEN, "forbidden".into()));
            }
            return Ok(());
        }
    }

    if status_changed {
        return match req.status {
            HttpRoomMembershipStatus::Active => match current_status {
                HttpRoomMembershipStatus::Pending => {
                    if source_link_changed {
                        return Err((
                            StatusCode::BAD_REQUEST,
                            "join approval cannot rewrite source_link_id".into(),
                        ));
                    }
                    if !can_moderate_room_member(
                        actor_role,
                        target_current_role,
                        actor_profile_id,
                        &req.profile_id,
                    ) {
                        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
                    }
                    Ok(())
                }
                HttpRoomMembershipStatus::Removed | HttpRoomMembershipStatus::Left => {
                    if can_direct_add_room_membership(
                        actor_role,
                        room,
                        Some(current_status),
                        target_current_role,
                        req,
                        target_membership.source_link_id.as_deref(),
                        normalized_source_link_id,
                        is_target_self,
                    ) {
                        return Ok(());
                    }
                    if !matches!(
                        actor_role,
                        HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin
                    ) {
                        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
                    }
                    Ok(())
                }
                HttpRoomMembershipStatus::Banned => Err((
                    StatusCode::BAD_REQUEST,
                    "banned memberships must be unbanned before activation".into(),
                )),
                HttpRoomMembershipStatus::Active => Ok(()),
            },
            HttpRoomMembershipStatus::Pending => {
                if !matches!(
                    actor_role,
                    HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin
                ) {
                    return Err((StatusCode::FORBIDDEN, "forbidden".into()));
                }
                Ok(())
            }
            HttpRoomMembershipStatus::Removed => {
                if req.role != HttpRoomMemberRole::Member {
                    return Err((
                        StatusCode::BAD_REQUEST,
                        "removed memberships must use member role".into(),
                    ));
                }
                match current_status {
                    HttpRoomMembershipStatus::Pending
                    | HttpRoomMembershipStatus::Active
                    | HttpRoomMembershipStatus::Removed
                    | HttpRoomMembershipStatus::Banned => {
                        if !can_moderate_room_member(
                            actor_role,
                            target_current_role,
                            actor_profile_id,
                            &req.profile_id,
                        ) {
                            return Err((StatusCode::FORBIDDEN, "forbidden".into()));
                        }
                        Ok(())
                    }
                    HttpRoomMembershipStatus::Left => {
                        if !can_moderate_room_member(
                            actor_role,
                            target_current_role,
                            actor_profile_id,
                            &req.profile_id,
                        ) {
                            return Err((StatusCode::FORBIDDEN, "forbidden".into()));
                        }
                        Ok(())
                    }
                }
            }
            HttpRoomMembershipStatus::Banned => {
                if req.role != HttpRoomMemberRole::Member {
                    return Err((
                        StatusCode::BAD_REQUEST,
                        "banned memberships must use member role".into(),
                    ));
                }
                if !can_moderate_room_member(
                    actor_role,
                    target_current_role,
                    actor_profile_id,
                    &req.profile_id,
                ) {
                    return Err((StatusCode::FORBIDDEN, "forbidden".into()));
                }
                Ok(())
            }
            HttpRoomMembershipStatus::Left => Err((
                StatusCode::BAD_REQUEST,
                "left mutations are not supported by this endpoint".into(),
            )),
        };
    }

    if source_link_changed {
        if !matches!(
            actor_role,
            HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin
        ) {
            return Err((StatusCode::FORBIDDEN, "forbidden".into()));
        }
    }

    Ok(())
}

fn now_ms() -> i64 {
    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default();
    ts.as_millis() as i64
}

fn remove_conn_if_same(
    state: &AppState,
    device_id: &str,
    candidate: &mpsc::UnboundedSender<Message>,
) {
    let should_remove = state
        .conns
        .get(device_id)
        .map(|entry| entry.value().same_channel(candidate))
        .unwrap_or(false);
    if should_remove {
        state.conns.remove(device_id);
    }
}

/// AUD-041: Explicit WS session-replacement.
///
/// When a new authenticated WebSocket hello arrives for a `device_id` that
/// already has a live sender in `state.conns`, we:
///   1. Atomically install the new sender (via `DashMap::insert`, which
///      returns the previous value so we never race two half-installed
///      writers).
///   2. Forward an `Error { code: "session_replaced" }` frame to the old
///      socket so the old client can surface a "signed in elsewhere"
///      warning instead of a silent disconnect.
///   3. Send a protocol-level Close with code 1008 (policy violation)
///      and reason `"session_replaced"` so the old browser/client sees a
///      distinguishable close event and does not re-attempt hello in a
///      hot-loop (the reason is observable via the standard WebSocket
///      CloseEvent.code/reason surface).
///   4. Drop our remaining reference to the old sender so the old
///      outgoing task exits once the queued messages drain.
///
/// The helper is idempotent: when there is no previous session (or the
/// previous session already shares the same channel) this is a no-op.
fn evict_existing_ws_session(
    state: &AppState,
    device_id: &str,
    new_tx: &mpsc::UnboundedSender<Message>,
) {
    let Some(prev_tx) = state.conns.insert(device_id.to_string(), new_tx.clone()) else {
        return;
    };
    if prev_tx.same_channel(new_tx) {
        return;
    }

    let err = ServerMsg::Error {
        code: "session_replaced".into(),
        message: "another client authenticated with this device_id".into(),
    };
    if let Ok(payload) = serde_json::to_string(&err) {
        let _ = prev_tx.send(Message::Text(payload.into()));
    }

    // 1008 = WebSocket "policy violation"; the historical code closest to
    // "your session was taken over by another client".
    const WS_POLICY_VIOLATION: CloseCode = 1008;
    let _ = prev_tx.send(Message::Close(Some(CloseFrame {
        code: WS_POLICY_VIOLATION,
        reason: "session_replaced".into(),
    })));
}

async fn ws_handler(ws: WebSocketUpgrade, State(state): State<AppState>) -> impl IntoResponse {
    ws.on_upgrade(|socket| handle_socket(socket, state))
}

async fn handle_socket(socket: WebSocket, state: AppState) {
    let (mut ws_sender, mut ws_receiver) = socket.split();

    // Per-connection outgoing queue.
    let (tx, mut rx) = mpsc::unbounded_channel::<Message>();

    let outgoing_task = tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            if ws_sender.send(msg).await.is_err() {
                break;
            }
        }
    });

    // Last time we received a WebSocket-level Pong (or any liveness
    // signal) from the client. The heartbeat task reads this to detect a
    // silent (TCP half-open / NAT-dropped) connection. Spawned after the
    // handshake so the heartbeat task can take ownership of `did`+`state`
    // and unregister the channel immediately on timeout (otherwise
    // `state.conns.get(...)` would still route Deliver frames to a
    // zombie channel and the push fallback would be skipped).
    let last_pong_at_ms = Arc::new(AtomicI64::new(now_ms()));

    // Basic handshake: expect hello first.
    // Сборка, названная в приветствии, — её надо пережить разбор и дойти до
    // записи активности ниже (см. «Замер раскатки для СОКЕТ-ЖИТЕЛЕЙ»).
    let mut hello_client_build: Option<String> = None;
    let did = if let Some(Ok(Message::Text(text))) = ws_receiver.next().await {
        match serde_json::from_str::<ClientMsg>(&text) {
            Ok(ClientMsg::HelloAuth {
                device_id,
                ts_ms,
                nonce_b64,
                signature_b64,
                client_build,
            }) => {
                hello_client_build = client_build;
                // Verify hello signature using identity key from Keys.
                let now = now_ms();
                if require_auth_enabled() {
                    if !is_valid_id(&device_id, 128) {
                        let err = ServerMsg::Error {
                            code: "auth_failed".into(),
                            message: "bad device_id".into(),
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        return;
                    }
                    // timestamp window: +/- 5 minutes
                    if (ts_ms - now).abs() > 5 * 60 * 1000 {
                        let err = ServerMsg::Error {
                            code: "auth_failed".into(),
                            message: "timestamp out of range".into(),
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        return;
                    }

                    // Basic nonce replay protection (best-effort, in-memory).
                    if let Err((_code, message)) =
                        check_and_mark_nonce(&state, &device_id, &nonce_b64, now)
                    {
                        let err = ServerMsg::Error {
                            code: "auth_failed".into(),
                            message,
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        return;
                    }

                    let Some(ik_b64) = fetch_identity_pub_b64(&state, &device_id).await else {
                        let err = ServerMsg::Error {
                            code: "auth_failed".into(),
                            message: "unknown device".into(),
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        return;
                    };

                    let msg = hello_auth_message(&device_id, ts_ms, &nonce_b64);
                    if !verify_ed25519_b64(&ik_b64, &signature_b64, &msg) {
                        let err = ServerMsg::Error {
                            code: "auth_failed".into(),
                            message: "bad signature".into(),
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        return;
                    }
                }

                let did = device_id;
                // AUD-041: explicit session-replacement signal. If another
                // socket is already registered for this device_id, evict it
                // with a distinguishable error+close code BEFORE we register
                // the new sender. The old client can then surface a
                // "signed-in elsewhere" hint instead of a silent disconnect,
                // and we are guaranteed the new socket is authoritative.
                evict_existing_ws_session(&state, &did, &tx);

                let next_seq = state
                    .store
                    .welcome_next_seq(&did, now_ms())
                    .await
                    .unwrap_or(1);
                let welcome = ServerMsg::Welcome {
                    device_id: did.clone(),
                    next_seq,
                };
                let _ = tx.send(Message::Text(
                    serde_json::to_string(&welcome).unwrap().into(),
                ));

                // Sprint 2 R3/R7: record this device as freshly authenticated.
                // We resolve the profile_id from the existing keys-server
                // helper (`fetch_profile_id` already caches in-memory) so
                // the activity row carries a profile binding for the
                // `device_activity_list_for_profile` query later.
                let activity_profile_id = fetch_profile_id(&state, &did).await;
                if let Err(e) = state
                    .store
                    .record_device_login(&did, activity_profile_id.as_deref(), now_ms())
                    .await
                {
                    tracing::warn!(
                        device_ref = %log_fingerprint(&did),
                        error = %e,
                        "device_activity login record failed (non-fatal)"
                    );
                }

                // Замер раскатки для СОКЕТ-ЖИТЕЛЕЙ. До 22.08.2026 версия
                // записывалась только на HTTP-пути, а активность — ещё и здесь;
                // устройство, которое держит сокет и не делает HTTP-pump,
                // считалось активным «без версии». Пишется после проверки
                // подписи и ни на что, кроме счётчика, не влияет.
                if let Some(build) = hello_client_build.as_deref() {
                    let build = build.trim();
                    if !build.is_empty() && build.len() <= 64 {
                        if let Err(e) = state
                            .store
                            .device_activity_set_client_build(&did, build, now_ms())
                            .await
                        {
                            tracing::debug!(
                                device_ref = %log_fingerprint(&did),
                                error = %e,
                                "ws client_build record failed (non-fatal)"
                            );
                        }
                    }
                }

                // Send pending (best-effort). Client will ack and/or dedup.
                if let Ok(pending) = state.store.list_pending_from(&did, 1, now_ms(), 500).await {
                    log_mailbox_drain("ws-hello", &did, &pending, now_ms());
                    // Sprint 2 R3: a non-empty fetch_pending response is the
                    // strongest possible "this device just drained its
                    // mailbox" signal. Bump the pump timestamp regardless of
                    // whether the list is empty — the act of asking is
                    // already proof of liveness.
                    if let Err(e) = state.store.record_pump_activity(&did, now_ms()).await {
                        tracing::debug!(
                            device_ref = %log_fingerprint(&did),
                            error = %e,
                            "device_activity pump record failed (non-fatal)"
                        );
                    }
                    let mut delivered_seqs: Vec<u64> = Vec::with_capacity(pending.len());
                    for p in pending {
                        let seq = p.seq;
                        let deliver = ServerMsg::Deliver {
                            device_id: did.clone(),
                            seq,
                            msg_id: p.msg_id,
                            ciphertext_b64: p.ciphertext_b64,
                            transport_meta_json: p.transport_meta_json,
                            from_device_id: p.from_device_id,
                        };
                        let _ = tx.send(Message::Text(
                            serde_json::to_string(&deliver).unwrap().into(),
                        ));
                        delivered_seqs.push(seq);
                    }
                    // RELIABLE-DELIVERY: stamp these as attempted so the redeliver
                    // sweep waits one backoff before re-sending — but WILL re-send
                    // any this client fails to ack (backfill Deliver above is
                    // best-effort, so a dropped one must not strand).
                    let _ = state
                        .store
                        .mark_pending_attempted(&did, delivered_seqs, now_ms())
                        .await;
                }

                did
            }
            Ok(ClientMsg::Hello { device_id }) => {
                // Legacy hello (dev-only when auth is required).
                if require_auth_enabled() {
                    let err = ServerMsg::Error {
                        code: "auth_required".into(),
                        message: "hello_auth required".into(),
                    };
                    let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                    return;
                }

                let did = device_id;
                evict_existing_ws_session(&state, &did, &tx);

                let next_seq = state
                    .store
                    .welcome_next_seq(&did, now_ms())
                    .await
                    .unwrap_or(1);
                let welcome = ServerMsg::Welcome {
                    device_id: did.clone(),
                    next_seq,
                };
                let _ = tx.send(Message::Text(
                    serde_json::to_string(&welcome).unwrap().into(),
                ));

                // Sprint 2 R3/R7: legacy unauthenticated hello path — still
                // record activity, but the profile binding may be empty
                // if `fetch_profile_id` fails. The activity row is created
                // anyway so subsequent push attempts can record outcomes.
                let activity_profile_id = fetch_profile_id(&state, &did).await;
                if let Err(e) = state
                    .store
                    .record_device_login(&did, activity_profile_id.as_deref(), now_ms())
                    .await
                {
                    tracing::warn!(
                        device_ref = %log_fingerprint(&did),
                        error = %e,
                        "device_activity legacy-login record failed (non-fatal)"
                    );
                }

                if let Ok(pending) = state.store.list_pending_from(&did, 1, now_ms(), 500).await {
                    log_mailbox_drain("ws-hello-legacy", &did, &pending, now_ms());
                    if let Err(e) = state.store.record_pump_activity(&did, now_ms()).await {
                        tracing::debug!(
                            device_ref = %log_fingerprint(&did),
                            error = %e,
                            "device_activity pump record failed (non-fatal)"
                        );
                    }
                    let mut delivered_seqs: Vec<u64> = Vec::with_capacity(pending.len());
                    for p in pending {
                        let seq = p.seq;
                        let deliver = ServerMsg::Deliver {
                            device_id: did.clone(),
                            seq,
                            msg_id: p.msg_id,
                            ciphertext_b64: p.ciphertext_b64,
                            transport_meta_json: p.transport_meta_json,
                            from_device_id: p.from_device_id,
                        };
                        let _ = tx.send(Message::Text(
                            serde_json::to_string(&deliver).unwrap().into(),
                        ));
                        delivered_seqs.push(seq);
                    }
                    // RELIABLE-DELIVERY: stamp these as attempted so the redeliver
                    // sweep waits one backoff before re-sending — but WILL re-send
                    // any this client fails to ack (backfill Deliver above is
                    // best-effort, so a dropped one must not strand).
                    let _ = state
                        .store
                        .mark_pending_attempted(&did, delivered_seqs, now_ms())
                        .await;
                }

                did
            }
            Ok(other) => {
                let err = ServerMsg::Error {
                    code: "bad_handshake".into(),
                    message: format!("expected hello first, got {other:?}"),
                };
                let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                return;
            }
            Err(e) => {
                let err = ServerMsg::Error {
                    code: "bad_json".into(),
                    message: e.to_string(),
                };
                let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                return;
            }
        }
    } else {
        return;
    };

    // Now that the device_id is known, spawn the heartbeat task. It owns
    // a clone of `tx`, `state`, and `did`, so it can both emit a Ping and
    // perform an authoritative `remove_conn_if_same` immediately when
    // pong silence exceeds the threshold — closing the race window where
    // a zombie channel would still be in `state.conns`.
    let heartbeat_tx = tx.clone();
    let heartbeat_last_pong = Arc::clone(&last_pong_at_ms);
    let heartbeat_state = state.clone();
    let heartbeat_did = did.clone();
    let heartbeat_task = tokio::spawn(async move {
        let mut ticker =
            tokio::time::interval(Duration::from_secs(WS_HEARTBEAT_INTERVAL_SECS));
        // Skip the immediate first tick; the handshake itself is fresh.
        ticker.tick().await;
        loop {
            ticker.tick().await;
            let last = heartbeat_last_pong.load(Ordering::Relaxed);
            let now = now_ms();
            if now.saturating_sub(last) > WS_HEARTBEAT_TIMEOUT_MS {
                tracing::warn!(
                    device_ref = %log_fingerprint(&heartbeat_did),
                    silent_ms = now.saturating_sub(last),
                    "ws heartbeat timeout; closing zombie channel"
                );
                // Remove ourselves from state.conns FIRST so no further
                // Deliver frames are routed here — this triggers the
                // push fallback path for any newly enqueued messages
                // instead of pretending to deliver them realtime to a
                // dead socket. Then send a Close so the client gets a
                // distinguishable shutdown signal (the receive loop will
                // exit on the close echo / read error).
                remove_conn_if_same(&heartbeat_state, &heartbeat_did, &heartbeat_tx);
                let _ = heartbeat_tx.send(Message::Close(Some(CloseFrame {
                    code: 1011, // server error / unexpected condition
                    reason: "heartbeat_timeout".into(),
                })));
                break;
            }
            if heartbeat_tx
                .send(Message::Ping(Vec::<u8>::new().into()))
                .is_err()
            {
                // Outgoing channel closed — the connection is already gone.
                break;
            }
        }
    });

    while let Some(Ok(msg)) = ws_receiver.next().await {
        match msg {
            Message::Text(text) => match serde_json::from_str::<ClientMsg>(&text) {
                Ok(ClientMsg::Ping) => {
                    let _ = tx.send(Message::Text(
                        serde_json::to_string(&ServerMsg::Pong).unwrap().into(),
                    ));
                }
                Ok(ClientMsg::Send {
                    to_device_id,
                    msg_id,
                    ciphertext_b64,
                    transport_meta_json,
                    ttl_seconds,
                    deliver_at_ms,
                }) => {
                    let from_device_ref = log_fingerprint(&did);
                    let to_device_ref = log_fingerprint(&to_device_id);
                    let msg_ref = log_fingerprint(&msg_id);
                    tracing::info!(from_device_ref=%from_device_ref, to_device_ref=%to_device_ref, msg_ref=%msg_ref, "ws send request");
                    if !is_valid_id(&to_device_id, 128) {
                        let err = ServerMsg::Error {
                            code: "bad_request".into(),
                            message: "bad to_device_id".into(),
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        continue;
                    }
                    if !is_valid_uuid(&msg_id) {
                        let err = ServerMsg::Error {
                            code: "bad_request".into(),
                            message: "bad msg_id".into(),
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        continue;
                    }
                    if !is_ciphertext_b64_reasonable(&ciphertext_b64) {
                        let err = ServerMsg::Error {
                            code: "bad_request".into(),
                            message: "ciphertext too large".into(),
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        continue;
                    }
                    if base64::engine::general_purpose::STANDARD
                        .decode(ciphertext_b64.as_bytes())
                        .is_err()
                    {
                        let err = ServerMsg::Error {
                            code: "bad_ciphertext".into(),
                            message: "ciphertext_b64 is not valid base64".into(),
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        continue;
                    }
                    let capped_ttl = ttl_seconds.min(state.max_msg_ttl_seconds);
                    let call_signal =
                        match parse_call_signal_transport_meta(transport_meta_json.as_deref()) {
                            Ok(v) => v,
                            Err(message) => {
                                let err = ServerMsg::Error {
                                    code: "bad_request".into(),
                                    message,
                                };
                                let _ = tx.send(Message::Text(
                                    serde_json::to_string(&err).unwrap().into(),
                                ));
                                continue;
                            }
                        };
                    if let Err(message) =
                        parse_room_call_sync_transport_meta(transport_meta_json.as_deref())
                    {
                        let err = ServerMsg::Error {
                            code: "bad_request".into(),
                            message,
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        continue;
                    }
                    if let Err(message) =
                        parse_room_call_media_signal_transport_meta(transport_meta_json.as_deref())
                    {
                        let err = ServerMsg::Error {
                            code: "bad_request".into(),
                            message,
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        continue;
                    }

                    // Server-side block list: receiver profile can block sender profile.
                    let Some(sender_pid) = fetch_profile_id(&state, &did).await else {
                        let err = ServerMsg::Error {
                            code: "auth_failed".into(),
                            message: "unknown sender device".into(),
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        continue;
                    };
                    let Some(receiver_pid) = fetch_profile_id(&state, &to_device_id).await else {
                        let err = ServerMsg::Error {
                            code: "bad_request".into(),
                            message: "unknown recipient device".into(),
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        continue;
                    };
                    if let Ok(true) = state.store.is_blocked(&receiver_pid, &sender_pid).await {
                        let err = ServerMsg::Error {
                            code: "blocked".into(),
                            message: "recipient blocked sender".into(),
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        continue;
                    }
                    let store_ttl = own_device_control_ttl(
                        state.own_device_control_ttl_seconds,
                        capped_ttl,
                        &sender_pid,
                        &receiver_pid,
                        &did,
                        &to_device_id,
                        is_session_heal_transport_meta(transport_meta_json.as_deref()),
                        call_signal.is_some(),
                    );
                    if store_ttl != capped_ttl {
                        tracing::info!(from_device_ref=%log_fingerprint(&did), to_device_ref=%to_device_ref, msg_ref=%msg_ref, ttl_seconds=store_ttl, "own-device control ttl extended");
                    }

                    // Basic spam control: cap per-recipient pending queue.
                    if let Ok(cnt) = state.store.pending_count(&to_device_id, now_ms()).await {
                        if cnt >= state.max_pending_per_device {
                            let err = ServerMsg::Error {
                                code: "over_capacity".into(),
                                message: "recipient queue full".into(),
                            };
                            let _ =
                                tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                            continue;
                        }
                    }

                    // SCHEDULED DELIVERY (2026-07-17): a future release time
                    // holds the row; anything <= now is the immediate path.
                    let ws_now = now_ms();
                    let deliver_at = deliver_at_ms.unwrap_or(0).max(0);
                    let is_scheduled = deliver_at > ws_now;
                    let enq = match state
                        .store
                        .enqueue_scheduled(
                            &to_device_id,
                            &msg_id,
                            &ciphertext_b64,
                            transport_meta_json.as_deref(),
                            store_ttl,
                            ws_now,
                            if is_scheduled { deliver_at } else { 0 },
                            Some(did.as_str()),
                        )
                        .await
                    {
                        Ok(v) => v,
                        Err(e) => {
                            let err = ServerMsg::Error {
                                code: "store_error".into(),
                                message: e,
                            };
                            let _ =
                                tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                            continue;
                        }
                    };

                    tracing::info!(to_device_ref=%to_device_ref, seq=enq.seq, msg_ref=%msg_ref, dedup=enq.dedup, scheduled=is_scheduled, "ws send enqueued");
                    if let Some(call_signal) = call_signal.as_ref() {
                        if let Err(e) = state
                            .store
                            .record_call_signal(
                                &did,
                                &to_device_id,
                                call_signal,
                                state.call_sessions.active_ttl_seconds,
                                state.call_sessions.terminal_ttl_seconds,
                                now_ms(),
                            )
                            .await
                        {
                            let err = ServerMsg::Error {
                                code: "store_error".into(),
                                message: e,
                            };
                            let _ =
                                tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                            continue;
                        }
                    }
                    // A scheduled (not-yet-due) row must NOT wake or deliver to
                    // the recipient now — the release tick handles it at T. Ack
                    // the sender so its outbox clears; the ciphertext is safely
                    // held on the relay.
                    //
                    // The gate is the row's STORED release time, never this
                    // request's: on a dedup hit against a still-held row (a
                    // client outbox re-kick / retry re-submitting the scheduled
                    // msg_id as "immediate") the request claims "deliver now"
                    // while the stored row is still held. Trusting the request
                    // there is exactly what let a scheduled message fire the
                    // moment the user sent their NEXT message.
                    let held = enq.deliver_at_ms > ws_now;
                    if held {
                        let _ = tx.send(Message::Text(
                            serde_json::to_string(&ServerMsg::SentOk {
                                msg_id: msg_id.clone(),
                            })
                            .unwrap()
                            .into(),
                        ));
                        tracing::info!(to_device_ref=%to_device_ref, seq=enq.seq, msg_ref=%msg_ref, deliver_at=enq.deliver_at_ms, dedup=enq.dedup, "ws scheduled; held for release");
                        continue;
                    }

                    if !enq.dedup {
                        // Снимается СИНХРОННО, до `spawn`: внутри задачи это
                        // значение уже относилось бы к другому моменту.
                        let had_live_socket = state.conns.contains_key(&to_device_id);
                        tokio::spawn(schedule_fcm_if_still_pending(
                            state.clone(),
                            to_device_id.clone(),
                            msg_id.clone(),
                            Some(did.clone()),
                            transport_meta_json.clone(),
                            // Момент постановки — здесь конверт и кладётся.
                            now_ms(),
                            had_live_socket,
                        ));
                    }

                    let _ = tx.send(Message::Text(
                        serde_json::to_string(&ServerMsg::SentOk {
                            msg_id: msg_id.clone(),
                        })
                        .unwrap()
                        .into(),
                    ));

                    if let Some(recipient_tx) = state.conns.get(&to_device_id).map(|v| v.clone()) {
                        let deliver = ServerMsg::Deliver {
                            device_id: to_device_id.clone(),
                            seq: enq.seq,
                            msg_id: msg_id.clone(),
                            ciphertext_b64: ciphertext_b64.clone(),
                            transport_meta_json: transport_meta_json.clone(),
                            from_device_id: Some(did.clone()),
                        };
                        if recipient_tx
                            .send(Message::Text(
                                serde_json::to_string(&deliver).unwrap().into(),
                            ))
                            .is_err()
                        {
                            remove_conn_if_same(&state, &to_device_id, &recipient_tx);
                            tracing::info!(to_device_ref=%to_device_ref, seq=enq.seq, msg_ref=%msg_ref, "ws recipient send failed; rely on scheduled fallback push");
                        } else {
                            tracing::info!(to_device_ref=%to_device_ref, seq=enq.seq, msg_ref=%msg_ref, "ws delivered realtime; skip push");
                        }
                    } else {
                        tracing::info!(to_device_ref=%to_device_ref, seq=enq.seq, msg_ref=%msg_ref, "ws recipient offline; rely on scheduled fallback push");
                    }
                }
                Ok(ClientMsg::Ack {
                    device_id,
                    seq,
                    msg_id,
                }) => {
                    if device_id != did {
                        let err = ServerMsg::Error {
                            code: "bad_request".into(),
                            message: "ack device_id mismatch".into(),
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                    } else {
                        let _ = state.store.ack(&device_id, seq, now_ms()).await;
                        tracing::info!(device_ref=%log_fingerprint(&device_id), seq=seq, msg_ref=%log_fingerprint(&msg_id), "ws ack received");
                    }
                }
                Ok(ClientMsg::FetchPending {
                    device_id,
                    from_seq,
                }) => {
                    if device_id != did {
                        let err = ServerMsg::Error {
                            code: "bad_request".into(),
                            message: "fetch_pending device_id mismatch".into(),
                        };
                        let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                        continue;
                    }
                    // Sprint 2 R3: the client explicitly asking for pending
                    // is proof the device is alive — bump activity before
                    // emitting any Deliver frames.
                    if let Err(e) = state.store.record_pump_activity(&device_id, now_ms()).await {
                        tracing::debug!(
                            device_ref = %log_fingerprint(&device_id),
                            error = %e,
                            "device_activity pump record failed (non-fatal)"
                        );
                    }
                    if let Ok(to_deliver) = state
                        .store
                        .list_pending_from(&device_id, from_seq, now_ms(), 500)
                        .await
                    {
                        log_mailbox_drain("ws-fetch-pending", &device_id, &to_deliver, now_ms());
                        let mut delivered_seqs: Vec<u64> = Vec::with_capacity(to_deliver.len());
                        for p in to_deliver {
                            let seq = p.seq;
                            let deliver = ServerMsg::Deliver {
                                device_id: device_id.clone(),
                                seq,
                                msg_id: p.msg_id,
                                ciphertext_b64: p.ciphertext_b64,
                                transport_meta_json: p.transport_meta_json,
                                from_device_id: p.from_device_id,
                            };
                            let _ = tx.send(Message::Text(
                                serde_json::to_string(&deliver).unwrap().into(),
                            ));
                            delivered_seqs.push(seq);
                        }
                        // RELIABLE-DELIVERY: back off the redeliver sweep for the
                        // rows we just served on this explicit pull.
                        let _ = state
                            .store
                            .mark_pending_attempted(&device_id, delivered_seqs, now_ms())
                            .await;
                    }
                }
                Ok(ClientMsg::Hello { .. }) => {}
                Ok(ClientMsg::HelloAuth { .. }) => {}
                Err(e) => {
                    let err = ServerMsg::Error {
                        code: "bad_json".into(),
                        message: e.to_string(),
                    };
                    let _ = tx.send(Message::Text(serde_json::to_string(&err).unwrap().into()));
                }
            },
            Message::Close(_) => break,
            // WebSocket protocol-level Pong from the client — refresh the
            // heartbeat timer so we don't tear down a healthy connection.
            // We also accept an unsolicited Pong as a liveness signal (RFC 6455).
            Message::Pong(_) => {
                last_pong_at_ms.store(now_ms(), Ordering::Relaxed);
            }
            // A protocol-level Ping from the client. axum/tungstenite
            // automatically responds with a Pong, but receiving the Ping
            // itself is also strong evidence the channel is alive.
            Message::Ping(_) => {
                last_pong_at_ms.store(now_ms(), Ordering::Relaxed);
            }
            _ => {}
        }
    }

    remove_conn_if_same(&state, &did, &tx);
    heartbeat_task.abort();
    outgoing_task.abort();
}

async fn http_welcome(
    Path(device_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpWelcomeResp>, (StatusCode, String)> {
    if !is_valid_id(&device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }
    if require_auth_enabled() {
        let (_hdr_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_welcome_auth_message(&device_id, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
    }
    let next_seq = state
        .store
        .welcome_next_seq(&device_id, now_ms())
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    // Sprint 2 R3/R7: HTTP-side parity with the WS welcome activity record.
    let activity_profile_id = fetch_profile_id(&state, &device_id).await;
    if let Err(e) = state
        .store
        .record_device_login(&device_id, activity_profile_id.as_deref(), now_ms())
        .await
    {
        tracing::warn!(
            device_ref = %log_fingerprint(&device_id),
            error = %e,
            "device_activity http-welcome record failed (non-fatal)"
        );
    }
    Ok(Json(HttpWelcomeResp {
        device_id,
        next_seq,
    }))
}

async fn http_pending(
    Path(device_id): Path<String>,
    Query(q): Query<PendingQuery>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpPendingResp>, (StatusCode, String)> {
    if !is_valid_id(&device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }
    let from_seq = q.from_seq.unwrap_or(1);
    let limit = q.limit.unwrap_or(500).min(2000) as usize;

    if require_auth_enabled() {
        let (_hdr_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_pending_auth_message(&device_id, from_seq, limit as u64, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
    }

    // Sprint 2 R3: HTTP-side parity with the WS FetchPending activity record.
    // 🔴 ВЕРСИЯ КЛИЕНТА (03.08.2026), справочно. Записывается здесь, потому что
    // /v1/pending дёргает КАЖДЫЙ клиент, и запрос уже проверен подписью выше —
    // значит device_id настоящий.
    //
    // Сам заголовок НЕ ПОДПИСАН и НИКОГДА не влияет ни на доставку, ни на
    // авторизацию: только на подсчёт долей раскатки. Подписывать его значило бы
    // ломать совместимость со всеми существующими сборками ради счётчика.
    if let Some(build) = header_str(&headers, "x-secretly-client-build") {
        if let Err(e) = state
            .store
            .device_activity_set_client_build(&device_id, build, now_ms())
            .await
        {
            tracing::debug!(
                device_ref = %log_fingerprint(&device_id),
                error = %e,
                "client_build record failed (non-fatal)"
            );
        }
    }
    if let Err(e) = state.store.record_pump_activity(&device_id, now_ms()).await {
        tracing::debug!(
            device_ref = %log_fingerprint(&device_id),
            error = %e,
            "device_activity http-pump record failed (non-fatal)"
        );
    }

    let pending = state
        .store
        .list_pending_from(&device_id, from_seq, now_ms(), limit)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;

    // The iOS NSE / background-fetch drain. Logged like every other drain —
    // this is the path a woken-but-backgrounded phone uses, so it is exactly
    // where "the notification arrived but the chat was empty" gets decided.
    log_mailbox_drain("http-pending", &device_id, &pending, now_ms());

    // RELIABLE-DELIVERY: back off the redeliver sweep for the rows this HTTP
    // pull just served (iOS NSE / background fetch path), so they aren't
    // re-sent over a concurrent WS while the client is applying them — but if
    // the client never acks, the sweep still retries them later.
    let _ = state
        .store
        .mark_pending_attempted(&device_id, pending.iter().map(|p| p.seq).collect(), now_ms())
        .await;

    let items = pending
        .into_iter()
        .map(|p| PendingItem {
            seq: p.seq,
            msg_id: p.msg_id,
            ciphertext_b64: p.ciphertext_b64,
            transport_meta_json: p.transport_meta_json,
            from_device_id: p.from_device_id,
        })
        .collect();

    Ok(Json(HttpPendingResp { device_id, items }))
}

/// К-2 (17.09.2026): a room
/// member uploads ONE sealed room message and names the devices that asked for
/// the raw room wire; the relay queues the same row for each of them, with the
/// authenticated sender attached (С-1). Devices it refuses are reported back so
/// the client carries them over the pairwise path. The relay never sees the
/// room key; it only checks who may send and who may receive.
async fn http_room_broadcast(
    Path(room_id): Path<String>,
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<HttpRoomBroadcastReq>,
) -> Result<Json<HttpRoomBroadcastResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    if !is_valid_uuid(&req.msg_id) {
        return Err((StatusCode::BAD_REQUEST, "bad msg_id".into()));
    }
    if req.recipients.is_empty() || req.recipients.len() > ROOM_BROADCAST_MAX_RECIPIENTS {
        return Err((StatusCode::BAD_REQUEST, "bad recipients".into()));
    }
    if !is_ciphertext_b64_reasonable(&req.ciphertext_b64)
        || base64::engine::general_purpose::STANDARD
            .decode(req.ciphertext_b64.as_bytes())
            .is_err()
    {
        return Err((StatusCode::BAD_REQUEST, "bad ciphertext".into()));
    }
    let capped_ttl = req.ttl_seconds.min(state.max_msg_ttl_seconds);
    let deliver_at = req.deliver_at_ms.unwrap_or(0).max(0);
    let (sender_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
    let msg = http_room_broadcast_auth_message(
        &sender_device_id,
        &room_id,
        &req.msg_id,
        &req.ciphertext_b64,
        &req.recipients,
        req.transport_meta_json.as_deref(),
        capped_ttl,
        deliver_at,
        ts_ms,
        &nonce_b64,
    );
    let _ = verify_http_auth(&state, &headers, Some(&sender_device_id), msg).await?;
    let sender_profile_id = requester_profile_id_for_device(&state, &sender_device_id).await?;
    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    ensure_room_active_member_access(&state, &room, &sender_profile_id).await?;
    let active_members: std::collections::HashSet<String> = state
        .store
        .list_room_memberships(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .into_iter()
        .filter(|m| m.status == HttpRoomMembershipStatus::Active.as_str())
        .map(|m| m.profile_id)
        .collect();

    let now = now_ms();
    let is_scheduled = deliver_at > now;
    let mut accepted = Vec::new();
    let mut rejected = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for to_device_id in req.recipients.iter() {
        let to_device_id = to_device_id.trim().to_string();
        let mut reject = |reason: &'static str| {
            rejected.push(HttpRoomBroadcastRejected {
                device_id: to_device_id.clone(),
                reason,
            })
        };
        if !is_valid_id(&to_device_id, 128) || !seen.insert(to_device_id.clone()) {
            reject("bad_device");
            continue;
        }
        if to_device_id == sender_device_id {
            reject("self");
            continue;
        }
        let Some(to_profile_id) = fetch_profile_id(&state, &to_device_id).await else {
            reject("unknown_device");
            continue;
        };
        if !active_members.contains(&to_profile_id) {
            reject("not_member");
            continue;
        }
        if state
            .store
            .is_blocked(&to_profile_id, &sender_profile_id)
            .await
            .unwrap_or(false)
        {
            reject("blocked");
            continue;
        }
        if let Ok(cnt) = state.store.pending_count(&to_device_id, now).await {
            if cnt >= state.max_pending_per_device {
                reject("queue_full");
                continue;
            }
        }
        let enq = match state
            .store
            .enqueue_scheduled(
                &to_device_id,
                &req.msg_id,
                &req.ciphertext_b64,
                req.transport_meta_json.as_deref(),
                capped_ttl,
                now,
                if is_scheduled { deliver_at } else { 0 },
                Some(sender_device_id.as_str()),
            )
            .await
        {
            Ok(v) => v,
            Err(_) => {
                reject("store_error");
                continue;
            }
        };
        accepted.push(to_device_id.clone());
        // Same release rule as `http_send`: a held row gets no realtime
        // delivery and no push until its release tick.
        if enq.deliver_at_ms > now {
            continue;
        }
        if !enq.dedup {
            let had_live_socket = state.conns.contains_key(&to_device_id);
            tokio::spawn(schedule_fcm_if_still_pending(
                state.clone(),
                to_device_id.clone(),
                req.msg_id.clone(),
                Some(sender_device_id.clone()),
                req.transport_meta_json.clone(),
                now,
                had_live_socket,
            ));
        }
        if let Some(recipient_tx) = state.conns.get(&to_device_id).map(|v| v.clone()) {
            let deliver = ServerMsg::Deliver {
                device_id: to_device_id.clone(),
                seq: enq.seq,
                msg_id: req.msg_id.clone(),
                ciphertext_b64: req.ciphertext_b64.clone(),
                transport_meta_json: req.transport_meta_json.clone(),
                from_device_id: Some(sender_device_id.clone()),
            };
            if recipient_tx
                .send(Message::Text(
                    serde_json::to_string(&deliver).unwrap().into(),
                ))
                .is_err()
            {
                remove_conn_if_same(&state, &to_device_id, &recipient_tx);
            }
        }
    }
    tracing::info!(
        room_ref=%log_fingerprint(&room_id),
        from_device_ref=%log_fingerprint(&sender_device_id),
        msg_ref=%log_fingerprint(&req.msg_id),
        accepted=accepted.len(),
        rejected=rejected.len(),
        scheduled=is_scheduled,
        "room broadcast"
    );
    Ok(Json(HttpRoomBroadcastResp {
        ok: true,
        accepted,
        rejected,
    }))
}

async fn http_send(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<HttpSendReq>,
) -> Result<Json<HttpSendResp>, (StatusCode, String)> {
    let to_device_ref = log_fingerprint(&req.to_device_id);
    let msg_ref = log_fingerprint(&req.msg_id);
    tracing::info!(to_device_ref=%to_device_ref, msg_ref=%msg_ref, "http send request");
    if !is_valid_id(&req.to_device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad to_device_id".into()));
    }
    if !is_valid_uuid(&req.msg_id) {
        return Err((StatusCode::BAD_REQUEST, "bad msg_id".into()));
    }
    if !is_ciphertext_b64_reasonable(&req.ciphertext_b64) {
        return Err((StatusCode::BAD_REQUEST, "ciphertext too large".into()));
    }
    if base64::engine::general_purpose::STANDARD
        .decode(req.ciphertext_b64.as_bytes())
        .is_err()
    {
        return Err((
            StatusCode::BAD_REQUEST,
            "ciphertext_b64 is not valid base64".into(),
        ));
    }
    let capped_ttl = req.ttl_seconds.min(state.max_msg_ttl_seconds);
    let call_signal = parse_call_signal_transport_meta(req.transport_meta_json.as_deref())
        .map_err(|e| (StatusCode::BAD_REQUEST, e))?;
    parse_room_call_sync_transport_meta(req.transport_meta_json.as_deref())
        .map_err(|e| (StatusCode::BAD_REQUEST, e))?;
    parse_room_call_media_signal_transport_meta(req.transport_meta_json.as_deref())
        .map_err(|e| (StatusCode::BAD_REQUEST, e))?;

    if let Ok(cnt) = state.store.pending_count(&req.to_device_id, now_ms()).await {
        if cnt >= state.max_pending_per_device {
            return Err((StatusCode::TOO_MANY_REQUESTS, "recipient queue full".into()));
        }
    }

    let mut from_device_id_opt: Option<String> = None;
    if require_auth_enabled() {
        let (from_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_send_auth_message(
            &from_device_id,
            &req.to_device_id,
            &req.msg_id,
            &req.ciphertext_b64,
            req.transport_meta_json.as_deref(),
            capped_ttl,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&from_device_id), msg).await?;
        from_device_id_opt = Some(from_device_id);
    }

    // Block enforcement (best-effort in dev when auth is disabled).
    // We only enforce if we can identify the sender device id (from auth headers).
    // The ttl stored for the row may differ from the signed `capped_ttl` only
    // by the own-device bridge below — the signature check above is untouched.
    let mut store_ttl = capped_ttl;
    if let Some(from_device_id) = from_device_id_opt.as_ref() {
        let sender_pid = fetch_profile_id(&state, &from_device_id)
            .await
            .ok_or((StatusCode::UNAUTHORIZED, "unknown sender device".into()))?;
        let receiver_pid = fetch_profile_id(&state, &req.to_device_id)
            .await
            .ok_or((StatusCode::BAD_REQUEST, "unknown recipient device".into()))?;
        if state
            .store
            .is_blocked(&receiver_pid, &sender_pid)
            .await
            .unwrap_or(false)
        {
            return Err((StatusCode::FORBIDDEN, "blocked".into()));
        }
        store_ttl = own_device_control_ttl(
            state.own_device_control_ttl_seconds,
            capped_ttl,
            &sender_pid,
            &receiver_pid,
            from_device_id,
            &req.to_device_id,
            is_session_heal_transport_meta(req.transport_meta_json.as_deref()),
            call_signal.is_some(),
        );
        if store_ttl != capped_ttl {
            tracing::info!(from_device_ref=%log_fingerprint(from_device_id), to_device_ref=%to_device_ref, msg_ref=%msg_ref, ttl_seconds=store_ttl, "own-device control ttl extended");
        }
    }

    let http_now = now_ms();
    let deliver_at = req.deliver_at_ms.unwrap_or(0).max(0);
    let is_scheduled = deliver_at > http_now;
    let enq = state
        .store
        .enqueue_scheduled(
            &req.to_device_id,
            &req.msg_id,
            &req.ciphertext_b64,
            req.transport_meta_json.as_deref(),
            store_ttl,
            http_now,
            if is_scheduled { deliver_at } else { 0 },
            from_device_id_opt.as_deref(),
        )
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;

    tracing::info!(to_device_ref=%to_device_ref, seq=enq.seq, msg_ref=%msg_ref, dedup=enq.dedup, scheduled=is_scheduled, "http send enqueued");
    // Scheduled row: held for the release tick — no realtime deliver, no push.
    // Gated on the row's STORED release time, never this request's: a dedup hit
    // that re-submits a still-held scheduled msg_id as "immediate" must not be
    // able to flush it early (see the WS path for the full rationale).
    let held = enq.deliver_at_ms > http_now;
    if held {
        tracing::info!(to_device_ref=%to_device_ref, seq=enq.seq, msg_ref=%msg_ref, deliver_at=enq.deliver_at_ms, dedup=enq.dedup, "http scheduled; held for release");
        return Ok(Json(HttpSendResp {
            ok: true,
            seq: enq.seq,
        }));
    }
    if let (Some(from_device_id), Some(call_signal)) =
        (from_device_id_opt.as_ref(), call_signal.as_ref())
    {
        state
            .store
            .record_call_signal(
                from_device_id,
                &req.to_device_id,
                call_signal,
                state.call_sessions.active_ttl_seconds,
                state.call_sessions.terminal_ttl_seconds,
                now_ms(),
            )
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    }
    if !enq.dedup {
        // Снимается СИНХРОННО, до `spawn`, и до попытки отдать конверт в сокет
        // несколькими строками ниже: нас интересует картина на момент
        // постановки, а не на момент, когда задача до неё дойдёт.
        let had_live_socket = state.conns.contains_key(&req.to_device_id);
        tokio::spawn(schedule_fcm_if_still_pending(
            state.clone(),
            req.to_device_id.clone(),
            req.msg_id.clone(),
            from_device_id_opt.clone(),
            req.transport_meta_json.clone(),
            // Момент постановки — здесь конверт и кладётся.
            now_ms(),
            had_live_socket,
        ));
    }

    if let Some(recipient_tx) = state.conns.get(&req.to_device_id).map(|v| v.clone()) {
        let deliver = ServerMsg::Deliver {
            device_id: req.to_device_id.clone(),
            seq: enq.seq,
            msg_id: req.msg_id.clone(),
            ciphertext_b64: req.ciphertext_b64.clone(),
            transport_meta_json: req.transport_meta_json.clone(),
            from_device_id: from_device_id_opt.clone(),
        };
        if recipient_tx
            .send(Message::Text(
                serde_json::to_string(&deliver).unwrap().into(),
            ))
            .is_err()
        {
            remove_conn_if_same(&state, &req.to_device_id, &recipient_tx);
            tracing::info!(to_device_ref=%to_device_ref, seq=enq.seq, msg_ref=%msg_ref, "http recipient send failed; rely on scheduled fallback push");
        } else {
            tracing::info!(to_device_ref=%to_device_ref, seq=enq.seq, msg_ref=%msg_ref, "http delivered realtime; skip push");
        }
    } else {
        tracing::info!(to_device_ref=%to_device_ref, seq=enq.seq, msg_ref=%msg_ref, "http recipient offline; rely on scheduled fallback push");
    }

    Ok(Json(HttpSendResp {
        ok: true,
        seq: enq.seq,
    }))
}

/// Максимум конвертов за один вопрос. Страховка отправителя чинит одно
/// устройство за проход, столько за раз ей и нужно.
const PENDING_CHECK_MAX_IDS: usize = 64;

async fn http_pending_check(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<HttpPendingCheckReq>,
) -> Result<Json<HttpPendingCheckResp>, (StatusCode, String)> {
    if !is_valid_id(&req.device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }
    if !is_valid_id(&req.to_device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad to_device_id".into()));
    }
    if req.msg_ids.is_empty() || req.msg_ids.len() > PENDING_CHECK_MAX_IDS {
        return Err((StatusCode::BAD_REQUEST, "bad msg_ids".into()));
    }
    if req.msg_ids.iter().any(|m| !is_valid_id(m, 128)) {
        return Err((StatusCode::BAD_REQUEST, "bad msg_id".into()));
    }
    if require_auth_enabled() {
        let (_hdr_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_pending_check_auth_message(
            &req.device_id,
            &req.to_device_id,
            &req.msg_ids,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&req.device_id), msg).await?;
    }
    let now = now_ms();
    let mut still_pending = Vec::new();
    for msg_id in &req.msg_ids {
        // 🔴 ОТКАЗ ТРАКТУЕТСЯ КАК «ДЕРЖУ». Иначе сбой чтения выглядел бы как
        // «доставлено» и ОТМЕНИЛ БЫ переотправку по-настоящему потерянной смс.
        // Безопасная сторона отказа здесь — лишний повтор, а не тишина.
        let held = state
            .store
            .has_pending_msg(&req.to_device_id, msg_id, now)
            .await
            .unwrap_or(true);
        if held {
            still_pending.push(msg_id.clone());
        }
    }
    tracing::info!(
        device_ref = %log_fingerprint(&req.device_id),
        to_device_ref = %log_fingerprint(&req.to_device_id),
        asked = req.msg_ids.len(),
        still_pending = still_pending.len(),
        "http pending_check"
    );
    Ok(Json(HttpPendingCheckResp { still_pending }))
}

async fn http_ack(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<HttpAckReq>,
) -> Result<Json<HttpAckResp>, (StatusCode, String)> {
    if !is_valid_id(&req.device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }
    if require_auth_enabled() {
        let (_hdr_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_ack_auth_message(&req.device_id, req.seq, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&req.device_id), msg).await?;
    }
    state
        .store
        .ack(&req.device_id, req.seq, now_ms())
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    let msg_ref = req
        .msg_id
        .as_deref()
        .map(log_fingerprint)
        .unwrap_or_else(|| "none".to_string());
    tracing::info!(device_ref=%log_fingerprint(&req.device_id), seq=req.seq, msg_ref=%msg_ref, "http ack received");
    Ok(Json(HttpAckResp { ok: true }))
}

#[derive(Deserialize)]
struct HttpCancelScheduledReq {
    /// The CANCELLER (sender of the original scheduled wire) — authenticated.
    device_id: String,
    /// Mailbox the held row sits in (the recipient device).
    to_device_id: String,
    msg_id: String,
}

#[derive(Serialize)]
struct HttpCancelScheduledResp {
    cancelled: bool,
}

/// POST /v1/cancel_scheduled — retract a not-yet-released "send later" row so
/// the sender can re-upload it under a fresh session (see
/// `http_cancel_scheduled_auth_message`). The store refuses once
/// `deliver_at_ms` has passed, so an already-released message can never be
/// silently unsent. Authorization: the caller must be an authenticated device
/// AND know the exact (to_device_id, msg_id) pair — msg_id is a v4 UUID minted
/// by the sender, so possession works as a capability token (the pending table
/// does not record from_device; tightening to a stored sender check is a
/// follow-up, not a blocker: a stranger cannot guess 122 bits).
async fn http_cancel_scheduled(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<HttpCancelScheduledReq>,
) -> Result<Json<HttpCancelScheduledResp>, (StatusCode, String)> {
    if !is_valid_id(&req.device_id, 128) || !is_valid_id(&req.to_device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }
    if !is_valid_uuid(&req.msg_id) {
        return Err((StatusCode::BAD_REQUEST, "bad msg_id".into()));
    }
    if require_auth_enabled() {
        let (_hdr_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_cancel_scheduled_auth_message(
            &req.device_id,
            &req.to_device_id,
            &req.msg_id,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&req.device_id), msg).await?;
    }
    let cancelled = state
        .store
        .cancel_scheduled(&req.to_device_id, &req.msg_id, now_ms())
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    tracing::info!(
        canceller_ref=%log_fingerprint(&req.device_id),
        to_device_ref=%log_fingerprint(&req.to_device_id),
        msg_ref=%log_fingerprint(&req.msg_id),
        cancelled,
        "http cancel scheduled"
    );
    Ok(Json(HttpCancelScheduledResp { cancelled }))
}

// FIX-2 (one-way blackout recovery): move a rotated-away device's un-acked
// mailbox to the live device of the SAME profile. Authenticated as the NEW
// (live) device; authorized only when both devices share a profile (verified
// against keys), so a device can never steal another user's mailbox.
async fn http_device_rebind(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<HttpRebindReq>,
) -> Result<Json<HttpRebindResp>, (StatusCode, String)> {
    if !is_valid_id(&req.new_device_id, 128) || !is_valid_id(&req.old_device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }
    if req.new_device_id == req.old_device_id {
        return Ok(Json(HttpRebindResp { ok: true, moved: 0 }));
    }
    if require_auth_enabled() {
        let (_hdr_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_rebind_auth_message(
            &req.new_device_id,
            &req.old_device_id,
            ts_ms,
            &nonce_b64,
        );
        // Caller must prove ownership of the NEW (live) device.
        let _ = verify_http_auth(&state, &headers, Some(&req.new_device_id), msg).await?;
        // Same-profile gate: both devices must map to the same profile on keys.
        let new_pid = fetch_profile_id(&state, &req.new_device_id)
            .await
            .ok_or((StatusCode::UNAUTHORIZED, "unknown new device".into()))?;
        let old_pid = fetch_profile_id(&state, &req.old_device_id)
            .await
            .ok_or((StatusCode::UNAUTHORIZED, "unknown old device".into()))?;
        if new_pid != old_pid {
            return Err((StatusCode::FORBIDDEN, "device profile mismatch".into()));
        }
    }
    let moved = state
        .store
        .rebind_pending(&req.old_device_id, &req.new_device_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    tracing::info!(
        new_ref=%log_fingerprint(&req.new_device_id),
        old_ref=%log_fingerprint(&req.old_device_id),
        moved=moved,
        "http device rebind"
    );
    Ok(Json(HttpRebindResp { ok: true, moved }))
}

async fn http_room_create(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<HttpRoomCreateReq>,
) -> Result<Json<HttpRoomCreateResp>, (StatusCode, String)> {
    if !is_valid_room_id(&req.room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    let title = normalize_room_title(&req.title)?;
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg =
            http_room_create_auth_message(&device_id, &req.room_id, &title, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let owner_profile_id = fetch_profile_id(&state, &requester_device_id)
        .await
        .ok_or((StatusCode::UNAUTHORIZED, "unknown creator device".into()))?;

    // Monetization §C-3: cap owned groups (fail-open, grandfathers existing).
    enforce_group_create_limit(&state, &owner_profile_id).await?;

    tracing::info!(room_ref=%log_fingerprint(&req.room_id), creator_device_ref=%log_fingerprint(&requester_device_id), owner_profile_ref=%log_fingerprint(&owner_profile_id), "http room create request");

    let result = match state
        .store
        .create_room(
            &req.room_id,
            &owner_profile_id,
            &requester_device_id,
            &title,
            now_ms(),
        )
        .await
    {
        Ok(result) => result,
        Err(CreateRoomError::Conflict(existing_room)) => {
            tracing::warn!(room_ref=%log_fingerprint(&req.room_id), existing_owner_profile_ref=%log_fingerprint(&existing_room.owner_profile_id), requester_device_ref=%log_fingerprint(&requester_device_id), "http room create conflict");
            return Err((
                StatusCode::CONFLICT,
                "room already exists with different authoritative metadata".into(),
            ));
        }
        Err(CreateRoomError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
    };

    Ok(Json(HttpRoomCreateResp {
        ok: true,
        created: result.created,
        room: room_to_http_resp(result.room),
    }))
}

async fn http_room_get(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpRoomResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_get_auth_message(&device_id, &room_id, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;
    ensure_room_active_member_access(&state, &room, &requester_profile_id).await?;

    tracing::info!(room_ref=%log_fingerprint(&room_id), requester_device_ref=%log_fingerprint(&requester_device_id), "http room get");

    Ok(Json(room_to_http_resp(room)))
}

fn room_error(
    status: StatusCode,
    code: &str,
    message: impl Into<String>,
) -> (StatusCode, Json<HttpRoomErrorResp>) {
    (
        status,
        Json(HttpRoomErrorResp {
            code: code.into(),
            message: message.into(),
            retry_after_seconds: None,
            next_allowed_at_ms: None,
        }),
    )
}

fn room_error_from_pair(
    code: &str,
    err: (StatusCode, String),
) -> (StatusCode, Json<HttpRoomErrorResp>) {
    room_error(err.0, code, err.1)
}

async fn http_room_profile_update(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpRoomProfileUpdateReq>,
) -> Result<Json<HttpRoomStateUpdateResp>, (StatusCode, Json<HttpRoomErrorResp>)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err(room_error(StatusCode::BAD_REQUEST, "bad_room_id", "bad room_id"));
    }
    let title = req.title.trim();
    if title.is_empty() {
        return Err(room_error(StatusCode::BAD_REQUEST, "bad_title", "title is required"));
    }
    let description = req
        .description
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string);
    let avatar_hash = req
        .avatar_hash
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string);
    let avatar_image_b64 = req
        .avatar_image_b64
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string);
    let clear_avatar = req.clear_avatar;

    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) =
            http_auth_headers(&headers).map_err(|err| room_error_from_pair("auth_invalid", err))?;
        let msg = http_room_profile_update_auth_message(
            &device_id,
            &room_id,
            title,
            description.as_deref(),
            avatar_hash.as_deref(),
            avatar_image_b64.as_deref(),
            clear_avatar,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg)
            .await
            .map_err(|err| room_error_from_pair("auth_invalid", err))?;
        device_id
    } else {
        required_http_device_id_header(&headers)
            .map_err(|err| room_error_from_pair("auth_invalid", err))?
    };
    let requester_profile_id = requester_profile_id_for_device(&state, &requester_device_id)
        .await
        .map_err(|err| room_error_from_pair("auth_invalid", err))?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|err| room_error(StatusCode::INTERNAL_SERVER_ERROR, "storage_error", err))?
        .ok_or_else(|| room_error(StatusCode::NOT_FOUND, "room_not_found", "room not found"))?;
    let actor_role = requester_room_role(&state, &room, &requester_profile_id)
        .await
        .map_err(|err| room_error_from_pair("not_member", err))?;
    if !can_change_room_info(actor_role, &room) {
        return Err(room_error(
            StatusCode::FORBIDDEN,
            "change_group_info_not_allowed",
            "changing group info is not allowed for this member",
        ));
    }

    let result = state
        .store
        .update_room_profile(
            &room_id,
            title,
            description.as_deref(),
            avatar_hash.as_deref(),
            avatar_image_b64.as_deref(),
            clear_avatar,
            now_ms(),
        )
        .await;
    let result = match result {
        Ok(result) => result,
        Err(UpdateRoomStateError::RoomNotFound) => {
            return Err(room_error(
                StatusCode::NOT_FOUND,
                "room_not_found",
                "room not found",
            ));
        }
        Err(UpdateRoomStateError::Storage(err)) => {
            return Err(room_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "storage_error",
                err,
            ));
        }
    };

    tracing::info!(room_ref=%log_fingerprint(&room_id), requester_device_ref=%log_fingerprint(&requester_device_id), requester_profile_ref=%log_fingerprint(&requester_profile_id), changed=result.changed, "http room profile update");

    Ok(Json(HttpRoomStateUpdateResp {
        ok: true,
        changed: result.changed,
        room: room_to_http_resp(result.room),
    }))
}

async fn http_room_settings_update(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpRoomSettingsUpdateReq>,
) -> Result<Json<HttpRoomStateUpdateResp>, (StatusCode, Json<HttpRoomErrorResp>)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err(room_error(StatusCode::BAD_REQUEST, "bad_room_id", "bad room_id"));
    }

    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) =
            http_auth_headers(&headers).map_err(|err| room_error_from_pair("auth_invalid", err))?;
        let msg = http_room_settings_update_auth_message(
            &device_id,
            &room_id,
            &req.reactions_mode,
            req.allow_text,
            req.allow_media,
            req.allow_add_members,
            req.allow_pin_messages,
            req.allow_change_group_info,
            req.allow_change_tag,
            req.join_approval_required,
            req.slow_mode_seconds,
            req.chat_history_visible,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg)
            .await
            .map_err(|err| room_error_from_pair("auth_invalid", err))?;
        device_id
    } else {
        required_http_device_id_header(&headers)
            .map_err(|err| room_error_from_pair("auth_invalid", err))?
    };
    let requester_profile_id = requester_profile_id_for_device(&state, &requester_device_id)
        .await
        .map_err(|err| room_error_from_pair("auth_invalid", err))?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|err| room_error(StatusCode::INTERNAL_SERVER_ERROR, "storage_error", err))?
        .ok_or_else(|| room_error(StatusCode::NOT_FOUND, "room_not_found", "room not found"))?;
    let actor_role = requester_room_role(&state, &room, &requester_profile_id)
        .await
        .map_err(|err| room_error_from_pair("not_member", err))?;
    if !can_manage_room_settings(actor_role) {
        return Err(room_error(
            StatusCode::FORBIDDEN,
            "admin_only",
            "only admins can change room settings",
        ));
    }

    let result = state
        .store
        .update_room_settings(
            &room_id,
            &req.reactions_mode,
            req.allow_text,
            req.allow_media,
            req.allow_add_members,
            req.allow_pin_messages,
            req.allow_change_group_info,
            req.allow_change_tag,
            req.join_approval_required,
            req.slow_mode_seconds,
            req.chat_history_visible,
            now_ms(),
        )
        .await;
    let result = match result {
        Ok(result) => result,
        Err(UpdateRoomStateError::RoomNotFound) => {
            return Err(room_error(
                StatusCode::NOT_FOUND,
                "room_not_found",
                "room not found",
            ));
        }
        Err(UpdateRoomStateError::Storage(err)) => {
            return Err(room_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "storage_error",
                err,
            ));
        }
    };

    tracing::info!(room_ref=%log_fingerprint(&room_id), requester_device_ref=%log_fingerprint(&requester_device_id), requester_profile_ref=%log_fingerprint(&requester_profile_id), changed=result.changed, "http room settings update");

    Ok(Json(HttpRoomStateUpdateResp {
        ok: true,
        changed: result.changed,
        room: room_to_http_resp(result.room),
    }))
}

async fn http_room_pinned_message_set(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpRoomPinnedMessageSetReq>,
) -> Result<Json<HttpRoomStateUpdateResp>, (StatusCode, Json<HttpRoomErrorResp>)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(HttpRoomErrorResp {
                code: "bad_room_id".into(),
                message: "bad room_id".into(),
                retry_after_seconds: None,
                next_allowed_at_ms: None,
            }),
        ));
    }
    let pinned_message_id = req
        .message_id
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string);
    if let Some(message_id) = pinned_message_id.as_deref() {
        if !is_valid_id(message_id, 128) {
            return Err((
                StatusCode::BAD_REQUEST,
                Json(HttpRoomErrorResp {
                    code: "bad_message_id".into(),
                    message: "bad message_id".into(),
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            ));
        }
    }

    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers).map_err(|err| {
            (
                err.0,
                Json(HttpRoomErrorResp {
                    code: "auth_invalid".into(),
                    message: err.1,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            )
        })?;
        let msg = http_room_pinned_message_set_auth_message(
            &device_id,
            &room_id,
            pinned_message_id.as_deref(),
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg)
            .await
            .map_err(|err| {
                (
                    err.0,
                    Json(HttpRoomErrorResp {
                        code: "auth_invalid".into(),
                        message: err.1,
                        retry_after_seconds: None,
                        next_allowed_at_ms: None,
                    }),
                )
            })?;
        device_id
    } else {
        required_http_device_id_header(&headers).map_err(|err| {
            (
                err.0,
                Json(HttpRoomErrorResp {
                    code: "auth_invalid".into(),
                    message: err.1,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            )
        })?
    };
    let requester_profile_id = requester_profile_id_for_device(&state, &requester_device_id)
        .await
        .map_err(|err| {
            (
                err.0,
                Json(HttpRoomErrorResp {
                    code: "auth_invalid".into(),
                    message: err.1,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            )
        })?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(HttpRoomErrorResp {
                    code: "storage_error".into(),
                    message: err,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            )
        })?
        .ok_or((
            StatusCode::NOT_FOUND,
            Json(HttpRoomErrorResp {
                code: "room_not_found".into(),
                message: "room not found".into(),
                retry_after_seconds: None,
                next_allowed_at_ms: None,
            }),
        ))?;
    let actor_role = requester_room_role(&state, &room, &requester_profile_id)
        .await
        .map_err(|err| {
            (
                err.0,
                Json(HttpRoomErrorResp {
                    code: "not_member".into(),
                    message: err.1,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            )
        })?;
    if !can_pin_room_messages(actor_role, &room) {
        return Err((
            StatusCode::FORBIDDEN,
            Json(HttpRoomErrorResp {
                code: "pin_not_allowed".into(),
                message: "pinning is not allowed for this room member".into(),
                retry_after_seconds: None,
                next_allowed_at_ms: None,
            }),
        ));
    }

    let result = state
        .store
        .set_room_pinned_message(&room_id, pinned_message_id.as_deref(), now_ms())
        .await;
    let result = match result {
        Ok(result) => result,
        Err(SetRoomPinnedMessageError::RoomNotFound) => {
            return Err((
                StatusCode::NOT_FOUND,
                Json(HttpRoomErrorResp {
                    code: "room_not_found".into(),
                    message: "room not found".into(),
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            ));
        }
        Err(SetRoomPinnedMessageError::MessageNotFound) => {
            return Err((
                StatusCode::NOT_FOUND,
                Json(HttpRoomErrorResp {
                    code: "message_not_found".into(),
                    message: "message was not admitted for this room".into(),
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            ));
        }
        Err(SetRoomPinnedMessageError::Storage(err)) => {
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(HttpRoomErrorResp {
                    code: "storage_error".into(),
                    message: err,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            ));
        }
    };

    tracing::info!(
        room_ref=%log_fingerprint(&room_id),
        requester_device_ref=%log_fingerprint(&requester_device_id),
        requester_profile_ref=%log_fingerprint(&requester_profile_id),
        pinned_message_ref=?log_optional_fingerprint(pinned_message_id.as_deref()),
        changed=result.changed,
        "http room pinned message set"
    );

    Ok(Json(HttpRoomStateUpdateResp {
        ok: true,
        changed: result.changed,
        room: room_to_http_resp(result.room),
    }))
}

async fn http_room_member_tag_set(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpRoomMemberTagSetReq>,
) -> Result<Json<HttpRoomMembershipUpsertResp>, (StatusCode, Json<HttpRoomErrorResp>)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(HttpRoomErrorResp {
                code: "bad_room_id".into(),
                message: "bad room_id".into(),
                retry_after_seconds: None,
                next_allowed_at_ms: None,
            }),
        ));
    }
    let normalized_tag = normalize_room_member_tag(req.tag.as_deref()).map_err(|err| {
        (
            err.0,
            Json(HttpRoomErrorResp {
                code: "bad_tag".into(),
                message: err.1,
                retry_after_seconds: None,
                next_allowed_at_ms: None,
            }),
        )
    })?;

    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers).map_err(|err| {
            (
                err.0,
                Json(HttpRoomErrorResp {
                    code: "auth_invalid".into(),
                    message: err.1,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            )
        })?;
        let msg = http_room_member_tag_set_auth_message(
            &device_id,
            &room_id,
            normalized_tag.as_deref(),
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg)
            .await
            .map_err(|err| {
                (
                    err.0,
                    Json(HttpRoomErrorResp {
                        code: "auth_invalid".into(),
                        message: err.1,
                        retry_after_seconds: None,
                        next_allowed_at_ms: None,
                    }),
                )
            })?;
        device_id
    } else {
        required_http_device_id_header(&headers).map_err(|err| {
            (
                err.0,
                Json(HttpRoomErrorResp {
                    code: "auth_invalid".into(),
                    message: err.1,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            )
        })?
    };
    let requester_profile_id = requester_profile_id_for_device(&state, &requester_device_id)
        .await
        .map_err(|err| {
            (
                err.0,
                Json(HttpRoomErrorResp {
                    code: "auth_invalid".into(),
                    message: err.1,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            )
        })?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(HttpRoomErrorResp {
                    code: "storage_error".into(),
                    message: err,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            )
        })?
        .ok_or((
            StatusCode::NOT_FOUND,
            Json(HttpRoomErrorResp {
                code: "room_not_found".into(),
                message: "room not found".into(),
                retry_after_seconds: None,
                next_allowed_at_ms: None,
            }),
        ))?;
    let actor_role = requester_room_role(&state, &room, &requester_profile_id)
        .await
        .map_err(|err| {
            (
                err.0,
                Json(HttpRoomErrorResp {
                    code: "not_member".into(),
                    message: err.1,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            )
        })?;
    if !can_change_own_room_tag(actor_role, &room) {
        return Err((
            StatusCode::FORBIDDEN,
            Json(HttpRoomErrorResp {
                code: "change_tag_not_allowed".into(),
                message: "changing own room tag is not allowed for this member".into(),
                retry_after_seconds: None,
                next_allowed_at_ms: None,
            }),
        ));
    }

    let result = state
        .store
        .set_room_member_tag(
            &room_id,
            &requester_profile_id,
            normalized_tag.as_deref(),
            now_ms(),
        )
        .await;
    let result = match result {
        Ok(result) => result,
        Err(SetRoomMemberTagError::RoomNotFound) => {
            return Err((
                StatusCode::NOT_FOUND,
                Json(HttpRoomErrorResp {
                    code: "room_not_found".into(),
                    message: "room not found".into(),
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            ));
        }
        Err(SetRoomMemberTagError::MembershipNotActive) => {
            return Err((
                StatusCode::CONFLICT,
                Json(HttpRoomErrorResp {
                    code: "not_active_member".into(),
                    message: "membership is not active".into(),
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            ));
        }
        Err(SetRoomMemberTagError::Storage(err)) => {
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(HttpRoomErrorResp {
                    code: "storage_error".into(),
                    message: err,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            ));
        }
    };
    let membership = room_membership_to_http_resp(result.membership).map_err(|err| {
        (
            err.0,
            Json(HttpRoomErrorResp {
                code: "storage_error".into(),
                message: err.1,
                retry_after_seconds: None,
                next_allowed_at_ms: None,
            }),
        )
    })?;

    tracing::info!(
        room_ref=%log_fingerprint(&room_id),
        requester_device_ref=%log_fingerprint(&requester_device_id),
        requester_profile_ref=%log_fingerprint(&requester_profile_id),
        tag=?normalized_tag,
        changed=result.changed,
        "http room member tag set"
    );

    Ok(Json(HttpRoomMembershipUpsertResp {
        ok: true,
        changed: result.changed,
        room: room_to_http_resp(result.room),
        membership,
    }))
}

async fn http_room_message_admission(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpRoomMessageAdmissionReq>,
) -> Result<Json<HttpRoomMessageAdmissionResp>, (StatusCode, Json<HttpRoomErrorResp>)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(HttpRoomErrorResp {
                code: "bad_room_id".into(),
                message: "bad room_id".into(),
                retry_after_seconds: None,
                next_allowed_at_ms: None,
            }),
        ));
    }
    if !is_valid_id(&req.message_id, 128) {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(HttpRoomErrorResp {
                code: "bad_message_id".into(),
                message: "bad message_id".into(),
                retry_after_seconds: None,
                next_allowed_at_ms: None,
            }),
        ));
    }

    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers).map_err(|err| {
            (
                err.0,
                Json(HttpRoomErrorResp {
                    code: "auth_invalid".into(),
                    message: err.1,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            )
        })?;
        let msg = http_room_message_admission_auth_message(
            &device_id,
            &room_id,
            &req.message_id,
            req.kind.as_str(),
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg)
            .await
            .map_err(|err| {
                (
                    err.0,
                    Json(HttpRoomErrorResp {
                        code: "auth_invalid".into(),
                        message: err.1,
                        retry_after_seconds: None,
                        next_allowed_at_ms: None,
                    }),
                )
            })?;
        device_id
    } else {
        required_http_device_id_header(&headers).map_err(|err| {
            (
                err.0,
                Json(HttpRoomErrorResp {
                    code: "auth_invalid".into(),
                    message: err.1,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            )
        })?
    };
    let requester_profile_id = requester_profile_id_for_device(&state, &requester_device_id)
        .await
        .map_err(|err| {
            (
                err.0,
                Json(HttpRoomErrorResp {
                    code: "auth_invalid".into(),
                    message: err.1,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            )
        })?;

    let outcome = state
        .store
        .admit_room_message(
            &room_id,
            &requester_profile_id,
            &req.message_id,
            req.kind.as_str(),
            now_ms(),
        )
        .await;

    let outcome = match outcome {
        Ok(result) => result,
        Err(AdmitRoomMessageError::RoomNotFound) => {
            return Err((
                StatusCode::NOT_FOUND,
                Json(HttpRoomErrorResp {
                    code: "room_not_found".into(),
                    message: "room not found".into(),
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            ));
        }
        Err(AdmitRoomMessageError::NotActiveMember) => {
            return Err((
                StatusCode::FORBIDDEN,
                Json(HttpRoomErrorResp {
                    code: "not_member".into(),
                    message: "not an active room member".into(),
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            ));
        }
        Err(AdmitRoomMessageError::TextDisabled) => {
            return Err((
                StatusCode::FORBIDDEN,
                Json(HttpRoomErrorResp {
                    code: "text_messages_disabled".into(),
                    message: "text messages are disabled for this room".into(),
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            ));
        }
        Err(AdmitRoomMessageError::MediaDisabled) => {
            return Err((
                StatusCode::FORBIDDEN,
                Json(HttpRoomErrorResp {
                    code: "media_disabled".into(),
                    message: "media messages are disabled for this room".into(),
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            ));
        }
        Err(AdmitRoomMessageError::SlowModeActive {
            retry_after_seconds,
            next_allowed_at_ms,
        }) => {
            return Err((
                StatusCode::TOO_MANY_REQUESTS,
                Json(HttpRoomErrorResp {
                    code: "slow_mode_active".into(),
                    message: "slow mode is active".into(),
                    retry_after_seconds: Some(retry_after_seconds),
                    next_allowed_at_ms: Some(next_allowed_at_ms),
                }),
            ));
        }
        Err(AdmitRoomMessageError::Storage(err)) => {
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(HttpRoomErrorResp {
                    code: "storage_error".into(),
                    message: err,
                    retry_after_seconds: None,
                    next_allowed_at_ms: None,
                }),
            ));
        }
    };

    tracing::info!(
        room_ref=%log_fingerprint(&room_id),
        requester_device_ref=%log_fingerprint(&requester_device_id),
        requester_profile_ref=%log_fingerprint(&requester_profile_id),
        message_ref=%log_fingerprint(&outcome.message_id),
        kind=%outcome.kind,
        admitted_at_ms=outcome.admitted_at_ms,
        next_allowed_at_ms=?outcome.next_allowed_at_ms,
        "http room message admission"
    );

    Ok(Json(HttpRoomMessageAdmissionResp {
        ok: true,
        message_id: outcome.message_id,
        kind: req.kind,
        admitted_at_ms: outcome.admitted_at_ms,
        next_allowed_at_ms: outcome.next_allowed_at_ms,
        room: room_to_http_resp(outcome.room),
    }))
}

async fn http_room_members_list(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpRoomMembersResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_members_list_auth_message(&device_id, &room_id, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;
    ensure_room_active_member_access(&state, &room, &requester_profile_id).await?;

    let members = state
        .store
        .list_room_memberships(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .into_iter()
        .map(room_membership_to_http_resp)
        .collect::<Result<Vec<_>, _>>()?;

    tracing::info!(room_ref=%log_fingerprint(&room_id), requester_device_ref=%log_fingerprint(&requester_device_id), requester_profile_ref=%log_fingerprint(&requester_profile_id), member_count=members.len(), "http room members list");

    Ok(Json(HttpRoomMembersResp {
        room: room_to_http_resp(room),
        members,
    }))
}

async fn http_room_members_upsert(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpRoomMembershipUpsertReq>,
) -> Result<Json<HttpRoomMembershipUpsertResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    if !is_valid_id(&req.profile_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad profile_id".into()));
    }
    let normalized_source_link_id = normalize_room_source_link_id(req.source_link_id.as_deref())?;

    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_members_upsert_auth_message(
            &device_id,
            &room_id,
            &req.profile_id,
            req.status.as_str(),
            req.role.as_str(),
            normalized_source_link_id.as_deref(),
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    let actor_role = requester_room_role(&state, &room, &requester_profile_id).await?;
    let target_membership = state
        .store
        .get_room_membership(&room_id, &req.profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    authorize_room_membership_upsert(
        &requester_profile_id,
        actor_role,
        &room,
        target_membership.as_ref(),
        &req,
        normalized_source_link_id.as_deref(),
    )?;

    // Monetization §C-3: cap active group size, but only when this upsert ADDS a
    // new active member. Existing active members and non-active transitions
    // (pending/left/removed/banned) are never blocked. Owner's tier governs the
    // room; fails open.
    if state.monetization_enabled && req.status.as_str() == "active" {
        let already_active = target_membership
            .as_ref()
            .map(|m| m.status == "active")
            .unwrap_or(false);
        if !already_active {
            enforce_group_size_limit(&state, &room.owner_profile_id, &room_id, &req.profile_id)
                .await?;
        }
    }

    let result = state
        .store
        .upsert_room_membership(
            &room_id,
            &req.profile_id,
            req.status.as_str(),
            req.role.as_str(),
            normalized_source_link_id.as_deref(),
            now_ms(),
        )
        .await;
    let result = match result {
        Ok(result) => result,
        Err(UpsertRoomMembershipError::RoomNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room not found".into()));
        }
        Err(UpsertRoomMembershipError::InvalidOwnerMutation) => {
            return Err((
                StatusCode::BAD_REQUEST,
                "invalid owner membership mutation".into(),
            ));
        }
        Err(UpsertRoomMembershipError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
    };
    let membership = room_membership_to_http_resp(result.membership)?;

    tracing::info!(room_ref=%log_fingerprint(&room_id), requester_device_ref=%log_fingerprint(&requester_device_id), requester_profile_ref=%log_fingerprint(&requester_profile_id), target_profile_ref=%log_fingerprint(&req.profile_id), changed=result.changed, "http room membership upsert");

    Ok(Json(HttpRoomMembershipUpsertResp {
        ok: true,
        changed: result.changed,
        room: room_to_http_resp(result.room),
        membership,
    }))
}

async fn http_room_leave(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpRoomLeaveResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }

    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_leave_auth_message(&device_id, &room_id, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let result = state
        .store
        .leave_room(&room_id, &requester_profile_id, now_ms())
        .await;
    let result = match result {
        Ok(result) => result,
        Err(LeaveRoomError::RoomNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room not found".into()));
        }
        Err(LeaveRoomError::MembershipNotActive) => {
            return Err((StatusCode::CONFLICT, "membership is not active".into()));
        }
        Err(LeaveRoomError::OwnerTransferRequired) => {
            return Err((
                StatusCode::CONFLICT,
                "owner transfer required before leave".into(),
            ));
        }
        Err(LeaveRoomError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
    };

    tracing::info!(room_ref=%log_fingerprint(&room_id), requester_device_ref=%log_fingerprint(&requester_device_id), requester_profile_ref=%log_fingerprint(&requester_profile_id), changed=result.changed, "http room leave");

    Ok(Json(HttpRoomLeaveResp {
        ok: true,
        changed: result.changed,
        room: room_to_http_resp(result.room),
        membership: room_membership_to_http_resp(result.membership)?,
    }))
}

async fn http_room_delete(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpRoomDeleteResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }

    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_delete_auth_message(&device_id, &room_id, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let result = state
        .store
        .delete_room(&room_id, &requester_profile_id)
        .await;
    let result = match result {
        Ok(result) => result,
        Err(DeleteRoomError::RoomNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room not found".into()));
        }
        Err(DeleteRoomError::OwnerMismatch) => {
            return Err((StatusCode::FORBIDDEN, "only owner may delete room".into()));
        }
        Err(DeleteRoomError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
    };

    tracing::info!(room_ref=%log_fingerprint(&room_id), requester_device_ref=%log_fingerprint(&requester_device_id), requester_profile_ref=%log_fingerprint(&requester_profile_id), deleted_profiles=result.deleted_profile_ids.len(), "http room delete");

    Ok(Json(HttpRoomDeleteResp {
        ok: true,
        room: room_to_http_resp(result.room),
        deleted_profile_ids: result.deleted_profile_ids,
    }))
}

async fn http_room_member_unban(
    Path((room_id, profile_id)): Path<(String, String)>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpRoomMembershipUpsertResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    if !is_valid_id(&profile_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad profile_id".into()));
    }

    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_member_unban_auth_message(
            &device_id,
            &room_id,
            &profile_id,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    let actor_role = requester_room_role(&state, &room, &requester_profile_id).await?;
    let target_membership = state
        .store
        .get_room_membership(&room_id, &profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::CONFLICT, "membership is not banned".into()))?;
    let target_role = target_room_member_role(&room, &profile_id, Some(&target_membership))?;
    if !can_moderate_room_member(actor_role, target_role, &requester_profile_id, &profile_id) {
        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
    }

    let result = state
        .store
        .unban_room_membership(&room_id, &profile_id, now_ms())
        .await;
    let result = match result {
        Ok(result) => result,
        Err(UnbanRoomMembershipError::RoomNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room not found".into()));
        }
        Err(UnbanRoomMembershipError::MembershipNotBanned) => {
            return Err((StatusCode::CONFLICT, "membership is not banned".into()));
        }
        Err(UnbanRoomMembershipError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
    };
    let membership = room_membership_to_http_resp(result.membership)?;

    tracing::info!(room_ref=%log_fingerprint(&room_id), requester_device_ref=%log_fingerprint(&requester_device_id), requester_profile_ref=%log_fingerprint(&requester_profile_id), target_profile_ref=%log_fingerprint(&profile_id), changed=result.changed, "http room member unban");

    Ok(Json(HttpRoomMembershipUpsertResp {
        ok: true,
        changed: result.changed,
        room: room_to_http_resp(result.room),
        membership,
    }))
}

async fn http_room_transfer_ownership(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpRoomTransferOwnershipReq>,
) -> Result<Json<HttpRoomTransferOwnershipResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    if !is_valid_id(&req.next_owner_profile_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad next_owner_profile_id".into()));
    }

    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_transfer_ownership_auth_message(
            &device_id,
            &room_id,
            &req.next_owner_profile_id,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    let actor_role = requester_room_role(&state, &room, &requester_profile_id).await?;
    let allow_idempotent_retry = actor_role == HttpRoomMemberRole::Admin
        && room.owner_profile_id == req.next_owner_profile_id;
    if actor_role != HttpRoomMemberRole::Owner && !allow_idempotent_retry {
        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
    }

    let result = state
        .store
        .transfer_room_ownership(
            &room_id,
            &requester_profile_id,
            &req.next_owner_profile_id,
            now_ms(),
        )
        .await;
    let result = match result {
        Ok(result) => result,
        Err(TransferRoomOwnershipError::RoomNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room not found".into()));
        }
        Err(TransferRoomOwnershipError::OwnerMismatch) => {
            return Err((StatusCode::CONFLICT, "room ownership changed".into()));
        }
        Err(TransferRoomOwnershipError::InvalidNextOwner) => {
            return Err((StatusCode::BAD_REQUEST, "invalid next owner".into()));
        }
        Err(TransferRoomOwnershipError::NextOwnerNotActive) => {
            return Err((
                StatusCode::BAD_REQUEST,
                "next owner must be an active member".into(),
            ));
        }
        Err(TransferRoomOwnershipError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
    };

    tracing::info!(room_ref=%log_fingerprint(&room_id), requester_device_ref=%log_fingerprint(&requester_device_id), previous_owner_profile_ref=%log_fingerprint(&requester_profile_id), next_owner_profile_ref=%log_fingerprint(&req.next_owner_profile_id), "http room transfer ownership");

    Ok(Json(HttpRoomTransferOwnershipResp {
        ok: true,
        room: room_to_http_resp(result.room),
        previous_owner_membership: room_membership_to_http_resp(result.previous_owner_membership)?,
        next_owner_membership: room_membership_to_http_resp(result.next_owner_membership)?,
    }))
}

async fn http_room_invite_links_list(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpRoomInviteLinksResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_invite_links_list_auth_message(&device_id, &room_id, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    let actor_role = requester_room_role(&state, &room, &requester_profile_id).await?;
    if !can_manage_room_invite_links(actor_role) {
        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
    }

    let invite_links = state
        .store
        .list_room_invite_links(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .into_iter()
        .map(room_invite_link_to_http_resp)
        .collect::<Result<Vec<_>, _>>()?;

    tracing::info!(room_ref=%log_fingerprint(&room_id), requester_device_ref=%log_fingerprint(&requester_device_id), requester_profile_ref=%log_fingerprint(&requester_profile_id), invite_count=invite_links.len(), "http room invite links list");

    Ok(Json(HttpRoomInviteLinksResp {
        room: room_to_http_resp(room),
        invite_links,
    }))
}

async fn http_room_invite_links_create(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpRoomInviteLinkCreateReq>,
) -> Result<Json<HttpRoomInviteLinkCreateResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    let expires_at_ms = normalize_room_invite_expires_at_ms(req.expires_at_ms);
    let max_uses = normalize_room_invite_max_uses(req.max_uses);
    let requires_approval = req.requires_approval.unwrap_or(false);
    let allowed_role = normalize_room_invite_allowed_role(req.allowed_role);

    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_invite_links_create_auth_message(
            &device_id,
            &room_id,
            expires_at_ms,
            max_uses,
            requires_approval,
            allowed_role.as_str(),
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    let actor_role = requester_room_role(&state, &room, &requester_profile_id).await?;
    if !can_manage_room_invite_links(actor_role) {
        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
    }

    let link_id = Uuid::now_v7().to_string();
    let slug = Uuid::now_v7().simple().to_string();
    let result = state
        .store
        .create_room_invite_link(
            &room_id,
            &link_id,
            &slug,
            &requester_profile_id,
            expires_at_ms,
            max_uses,
            requires_approval,
            allowed_role.as_str(),
            now_ms(),
        )
        .await;
    let result = match result {
        Ok(result) => result,
        Err(CreateRoomInviteLinkError::RoomNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room not found".into()));
        }
        Err(CreateRoomInviteLinkError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
    };

    tracing::info!(room_ref=%log_fingerprint(&room_id), requester_device_ref=%log_fingerprint(&requester_device_id), requester_profile_ref=%log_fingerprint(&requester_profile_id), link_ref=%log_fingerprint(&result.invite_link.link_id), slug_ref=%log_fingerprint(&result.invite_link.slug), requires_approval=requires_approval, "http room invite link create");

    Ok(Json(HttpRoomInviteLinkCreateResp {
        ok: true,
        room: room_to_http_resp(result.room),
        invite_link: room_invite_link_to_http_resp(result.invite_link)?,
    }))
}

async fn http_room_invite_link_revoke(
    Path((room_id, link_id)): Path<(String, String)>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpRoomInviteLinkRevokeReq>,
) -> Result<Json<HttpRoomInviteLinkRevokeResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    if !is_valid_id(&link_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad link_id".into()));
    }

    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_invite_link_revoke_auth_message(
            &device_id,
            &room_id,
            &link_id,
            req.revoked,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    let actor_role = requester_room_role(&state, &room, &requester_profile_id).await?;
    if !can_manage_room_invite_links(actor_role) {
        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
    }

    let result = state
        .store
        .set_room_invite_link_revoked(&room_id, &link_id, req.revoked, now_ms())
        .await;
    let result = match result {
        Ok(result) => result,
        Err(SetRoomInviteLinkRevokedError::RoomNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room not found".into()));
        }
        Err(SetRoomInviteLinkRevokedError::InviteNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room invite link not found".into()));
        }
        Err(SetRoomInviteLinkRevokedError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
    };

    tracing::info!(room_ref=%log_fingerprint(&room_id), link_ref=%log_fingerprint(&link_id), requester_device_ref=%log_fingerprint(&requester_device_id), requester_profile_ref=%log_fingerprint(&requester_profile_id), revoked=req.revoked, changed=result.changed, "http room invite link revoke");

    Ok(Json(HttpRoomInviteLinkRevokeResp {
        ok: true,
        changed: result.changed,
        room: room_to_http_resp(result.room),
        invite_link: room_invite_link_to_http_resp(result.invite_link)?,
    }))
}

async fn http_room_invite_preview(
    Path(slug): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpRoomInvitePreviewResp>, (StatusCode, String)> {
    if !is_valid_id(&slug, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad invite slug".into()));
    }
    // AUD-080 mitigation on the preview path as well: same per-slug bucket is
    // shared with redeem so scraping the preview endpoint does not bypass the
    // invite rate limit.
    if !state.invite_redeem_slug_limiter.allow(&slug) {
        return Err((
            StatusCode::TOO_MANY_REQUESTS,
            "invite slug temporarily rate-limited".into(),
        ));
    }
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_invite_preview_auth_message(&device_id, &slug, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    if !state
        .invite_redeem_caller_limiter
        .allow(&requester_device_id)
    {
        return Err((
            StatusCode::TOO_MANY_REQUESTS,
            "invite preview rate-limited for caller".into(),
        ));
    }
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let invite_link = state
        .store
        .get_room_invite_link_by_slug(&slug)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room invite link not found".into()))?;
    let room = state
        .store
        .get_room(&invite_link.room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    let requester_membership = state
        .store
        .get_room_membership(&room.room_id, &requester_profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    let active_member_count = state
        .store
        .count_active_room_members(&room.room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    let availability =
        room_invite_availability(&invite_link, requester_membership.as_ref(), now_ms());
    let requester_membership = requester_membership
        .map(room_membership_to_http_resp)
        .transpose()?;

    tracing::info!(room_ref=%log_fingerprint(&room.room_id), slug_ref=%log_fingerprint(&slug), requester_device_ref=%log_fingerprint(&requester_device_id), requester_profile_ref=%log_fingerprint(&requester_profile_id), active_member_count=active_member_count, availability=?availability, "http room invite preview");

    Ok(Json(HttpRoomInvitePreviewResp {
        room: room_to_http_resp(room),
        invite_link: room_invite_link_to_http_resp(invite_link)?,
        active_member_count,
        availability,
        requester_membership,
    }))
}

async fn http_room_invite_redeem(
    Path(slug): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpRoomInviteRedeemResp>, (StatusCode, String)> {
    if !is_valid_id(&slug, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad invite slug".into()));
    }
    // AUD-080: rate-limit per slug BEFORE signature verification so that
    // unauthenticated callers also burn the slug bucket, not just the caller
    // bucket. Signed verification happens right after and still gates state
    // mutations, so this only slows down probing, never leaks validity.
    if !state.invite_redeem_slug_limiter.allow(&slug) {
        return Err((
            StatusCode::TOO_MANY_REQUESTS,
            "invite slug temporarily rate-limited".into(),
        ));
    }
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_invite_redeem_auth_message(&device_id, &slug, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    if !state
        .invite_redeem_caller_limiter
        .allow(&requester_device_id)
    {
        return Err((
            StatusCode::TOO_MANY_REQUESTS,
            "invite redeem rate-limited for caller".into(),
        ));
    }
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    // Monetization §C-3: cap joined groups. Fail-open and skip the gate for a
    // profile that is ALREADY an active member of this room (re-redeem must
    // never be blocked — only a genuinely new join counts against the cap).
    if state.monetization_enabled {
        let invite = state
            .store
            .get_room_invite_link_by_slug(&slug)
            .await
            .ok()
            .flatten();
        let membership = match invite.as_ref() {
            Some(invite) => state
                .store
                .get_room_membership(&invite.room_id, &requester_profile_id)
                .await
                .ok()
                .flatten(),
            None => None,
        };
        let membership_status = membership.as_ref().map(|m| m.status.as_str());
        let already_member = membership_status == Some("active");
        if !already_member {
            enforce_group_join_limit(&state, &requester_profile_id).await?;
        }

        // Р-4 (17.09.2026): the room's OWN member cap. The membership-upsert
        // path enforces it; redeem did not, so an invite link grew a room past
        // its owner's tier. Only a redeem that ADDS an active member counts:
        // a pending (approval) join is checked when it is approved (upsert),
        // and existing active / pending / banned rows never reach the insert
        // (`redeem_room_invite` returns them as-is or refuses).
        let reaches_insert = !matches!(membership_status, Some("active" | "pending" | "banned"));
        if let (Some(invite), true) = (invite.as_ref(), reaches_insert) {
            if let Ok(Some(room)) = state.store.get_room(&invite.room_id).await {
                let joins_active = !(room.join_approval_required || invite.requires_approval);
                if joins_active {
                    enforce_group_size_limit(
                        &state,
                        &room.owner_profile_id,
                        &room.room_id,
                        &requester_profile_id,
                    )
                    .await?;
                }
            }
        }
    }

    let result = state
        .store
        .redeem_room_invite(&slug, &requester_profile_id, now_ms())
        .await;
    let result = match result {
        Ok(result) => result,
        Err(RedeemRoomInviteError::InviteNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room invite link not found".into()));
        }
        Err(RedeemRoomInviteError::RoomNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room not found".into()));
        }
        Err(RedeemRoomInviteError::InviteRevoked | RedeemRoomInviteError::InviteExpired) => {
            return Err((StatusCode::GONE, "room invite link unavailable".into()));
        }
        Err(RedeemRoomInviteError::InviteUsageLimitReached) => {
            return Err((StatusCode::CONFLICT, "room invite link exhausted".into()));
        }
        Err(RedeemRoomInviteError::Banned) => {
            return Err((StatusCode::FORBIDDEN, "forbidden".into()));
        }
        Err(RedeemRoomInviteError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
    };
    let membership = room_membership_to_http_resp(result.membership)?;
    let disposition = room_invite_join_disposition(membership.status)?;

    tracing::info!(room_ref=%log_fingerprint(&result.room.room_id), slug_ref=%log_fingerprint(&slug), requester_device_ref=%log_fingerprint(&requester_device_id), requester_profile_ref=%log_fingerprint(&requester_profile_id), changed=result.changed, disposition=?disposition, "http room invite redeem");

    Ok(Json(HttpRoomInviteRedeemResp {
        ok: true,
        changed: result.changed,
        disposition,
        room: room_to_http_resp(result.room),
        invite_link: room_invite_link_to_http_resp(result.invite_link)?,
        membership,
    }))
}

async fn http_room_call_get(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpRoomCallSnapshotResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_call_get_auth_message(&device_id, &room_id, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    ensure_room_active_member_access(&state, &room, &requester_profile_id).await?;

    let snapshot = state
        .store
        .get_active_room_call(&room_id, Some(&requester_device_id))
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;

    tracing::info!(
        room_ref=%log_fingerprint(&room_id),
        requester_device_ref=%log_fingerprint(&requester_device_id),
        requester_profile_ref=%log_fingerprint(&requester_profile_id),
        exists=snapshot.is_some(),
        "http room call get"
    );

    if let Some(snapshot) = snapshot {
        let (room, call, participants, self_participant) =
            room_call_snapshot_to_http_parts(snapshot)?;
        return Ok(Json(HttpRoomCallSnapshotResp {
            exists: true,
            room,
            call: Some(call),
            participants,
            self_participant,
        }));
    }

    Ok(Json(HttpRoomCallSnapshotResp {
        exists: false,
        room: room_to_http_resp(room),
        call: None,
        participants: Vec::new(),
        self_participant: None,
    }))
}

async fn http_room_call_join(
    Path(room_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpRoomCallJoinReq>,
) -> Result<Json<HttpRoomCallMutationResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_call_join_auth_message(
            &device_id,
            &room_id,
            req.media_type.as_str(),
            req.supports_video,
            req.supports_screen_share,
            req.muted,
            req.deafened,
            req.video_enabled,
            req.screen_share_enabled,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    // Monetization §C-3: cap call participants (owner's tier governs; fail-open;
    // rejoin and the first joiner are never blocked).
    enforce_call_participant_limit(&state, &room_id, &requester_profile_id).await?;

    let result = state
        .store
        .create_or_join_room_call(
            &room_id,
            &requester_profile_id,
            &requester_device_id,
            req.media_type.as_str(),
            req.supports_video,
            req.supports_screen_share,
            req.muted,
            req.deafened,
            req.video_enabled,
            req.screen_share_enabled,
            now_ms(),
        )
        .await;
    let result = match result {
        Ok(result) => result,
        Err(RoomCallControlError::RoomNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room not found".into()));
        }
        Err(RoomCallControlError::NotActiveMember) => {
            return Err((StatusCode::FORBIDDEN, "forbidden".into()));
        }
        Err(RoomCallControlError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
        Err(
            RoomCallControlError::CallNotFound
            | RoomCallControlError::CallNotActive
            | RoomCallControlError::ParticipantNotJoined,
        ) => {
            return Err((StatusCode::CONFLICT, "room call state conflict".into()));
        }
    };
    let (room, call, participants, self_participant) =
        room_call_snapshot_to_http_parts(result.snapshot)?;

    tracing::info!(
        room_ref=%log_fingerprint(&room_id),
        requester_device_ref=%log_fingerprint(&requester_device_id),
        requester_profile_ref=%log_fingerprint(&requester_profile_id),
        call_ref=%log_fingerprint(&call.call_id),
        changed=result.changed,
        "http room call join"
    );

    Ok(Json(HttpRoomCallMutationResp {
        ok: true,
        changed: result.changed,
        room,
        call,
        participants,
        self_participant,
    }))
}

async fn http_room_call_self_update(
    Path((room_id, call_id)): Path<(String, String)>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpRoomCallParticipantUpdateReq>,
) -> Result<Json<HttpRoomCallMutationResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    if !is_valid_id(&call_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad call_id".into()));
    }
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_call_self_update_auth_message(
            &device_id,
            &room_id,
            &call_id,
            req.reconnecting,
            req.muted,
            req.deafened,
            req.video_enabled,
            req.screen_share_enabled,
            req.speaking,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let result = state
        .store
        .update_room_call_participant_state(
            &room_id,
            &call_id,
            &requester_profile_id,
            &requester_device_id,
            req.reconnecting,
            req.muted,
            req.deafened,
            req.video_enabled,
            req.screen_share_enabled,
            req.speaking,
            now_ms(),
        )
        .await;
    let result = match result {
        Ok(result) => result,
        Err(RoomCallControlError::RoomNotFound | RoomCallControlError::CallNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room call not found".into()));
        }
        Err(RoomCallControlError::NotActiveMember) => {
            return Err((StatusCode::FORBIDDEN, "forbidden".into()));
        }
        Err(RoomCallControlError::CallNotActive) => {
            return Err((StatusCode::CONFLICT, "room call is not active".into()));
        }
        Err(RoomCallControlError::ParticipantNotJoined) => {
            return Err((StatusCode::CONFLICT, "participant is not joined".into()));
        }
        Err(RoomCallControlError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
    };
    let (room, call, participants, self_participant) =
        room_call_snapshot_to_http_parts(result.snapshot)?;

    tracing::info!(
        room_ref=%log_fingerprint(&room_id),
        requester_device_ref=%log_fingerprint(&requester_device_id),
        requester_profile_ref=%log_fingerprint(&requester_profile_id),
        call_ref=%log_fingerprint(&call.call_id),
        changed=result.changed,
        reconnecting=req.reconnecting,
        muted=req.muted,
        deafened=req.deafened,
        video_enabled=req.video_enabled,
        screen_share_enabled=req.screen_share_enabled,
        speaking=req.speaking,
        "http room call self update"
    );

    Ok(Json(HttpRoomCallMutationResp {
        ok: true,
        changed: result.changed,
        room,
        call,
        participants,
        self_participant,
    }))
}

async fn http_room_call_leave(
    Path((room_id, call_id)): Path<(String, String)>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpRoomCallMutationResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    if !is_valid_id(&call_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad call_id".into()));
    }
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg =
            http_room_call_leave_auth_message(&device_id, &room_id, &call_id, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let result = state
        .store
        .leave_room_call(
            &room_id,
            &call_id,
            &requester_profile_id,
            &requester_device_id,
            now_ms(),
        )
        .await;
    let result = match result {
        Ok(result) => result,
        Err(RoomCallControlError::RoomNotFound | RoomCallControlError::CallNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room call not found".into()));
        }
        Err(RoomCallControlError::ParticipantNotJoined) => {
            return Err((StatusCode::CONFLICT, "participant is not joined".into()));
        }
        Err(RoomCallControlError::NotActiveMember | RoomCallControlError::CallNotActive) => {
            return Err((StatusCode::CONFLICT, "room call state conflict".into()));
        }
        Err(RoomCallControlError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
    };
    let (room, call, participants, self_participant) =
        room_call_snapshot_to_http_parts(result.snapshot)?;

    tracing::info!(
        room_ref=%log_fingerprint(&room_id),
        requester_device_ref=%log_fingerprint(&requester_device_id),
        requester_profile_ref=%log_fingerprint(&requester_profile_id),
        call_ref=%log_fingerprint(&call.call_id),
        changed=result.changed,
        "http room call leave"
    );

    Ok(Json(HttpRoomCallMutationResp {
        ok: true,
        changed: result.changed,
        room,
        call,
        participants,
        self_participant,
    }))
}

async fn http_room_call_participant_remove(
    Path((room_id, call_id, participant_device_id)): Path<(String, String, String)>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpRoomCallMutationResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    if !is_valid_id(&call_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad call_id".into()));
    }
    if !is_valid_id(&participant_device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad participant_device_id".into()));
    }
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_call_participant_remove_auth_message(
            &device_id,
            &room_id,
            &call_id,
            &participant_device_id,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    let actor_role = requester_room_role(&state, &room, &requester_profile_id).await?;
    let snapshot = state
        .store
        .get_room_call(&room_id, &call_id, Some(&requester_device_id))
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room call not found".into()))?;
    let target_participant = snapshot
        .participants
        .iter()
        .find(|participant| participant.device_id == participant_device_id)
        .cloned()
        .ok_or((
            StatusCode::NOT_FOUND,
            "room call participant not found".into(),
        ))?;
    let target_membership = state
        .store
        .get_room_membership(&room_id, &target_participant.profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    let target_role = target_room_member_role(
        &room,
        &target_participant.profile_id,
        target_membership.as_ref(),
    )?;
    if !can_moderate_room_member(
        actor_role,
        target_role,
        &requester_profile_id,
        &target_participant.profile_id,
    ) {
        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
    }

    let result = state
        .store
        .remove_room_call_participant(
            &room_id,
            &call_id,
            &target_participant.profile_id,
            &participant_device_id,
            Some(&requester_device_id),
            now_ms(),
        )
        .await;
    let result = match result {
        Ok(result) => result,
        Err(RoomCallControlError::RoomNotFound | RoomCallControlError::CallNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room call not found".into()));
        }
        Err(RoomCallControlError::NotActiveMember) => {
            return Err((StatusCode::FORBIDDEN, "forbidden".into()));
        }
        Err(RoomCallControlError::CallNotActive) => {
            return Err((StatusCode::CONFLICT, "room call is not active".into()));
        }
        Err(RoomCallControlError::ParticipantNotJoined) => {
            return Err((StatusCode::CONFLICT, "participant is not joined".into()));
        }
        Err(RoomCallControlError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
    };
    let (room, call, participants, self_participant) =
        room_call_snapshot_to_http_parts(result.snapshot)?;

    tracing::info!(
        room_ref=%log_fingerprint(&room_id),
        requester_device_ref=%log_fingerprint(&requester_device_id),
        requester_profile_ref=%log_fingerprint(&requester_profile_id),
        call_ref=%log_fingerprint(&call.call_id),
        target_profile_ref=%log_fingerprint(&target_participant.profile_id),
        target_device_ref=%log_fingerprint(&participant_device_id),
        changed=result.changed,
        "http room call participant remove"
    );

    Ok(Json(HttpRoomCallMutationResp {
        ok: true,
        changed: result.changed,
        room,
        call,
        participants,
        self_participant,
    }))
}

async fn http_room_call_end(
    Path((room_id, call_id)): Path<(String, String)>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpRoomCallMutationResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    if !is_valid_id(&call_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad call_id".into()));
    }
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg =
            http_room_call_end_auth_message(&device_id, &room_id, &call_id, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    let actor_role = requester_room_role(&state, &room, &requester_profile_id).await?;
    if !matches!(
        actor_role,
        HttpRoomMemberRole::Owner | HttpRoomMemberRole::Admin
    ) {
        return Err((StatusCode::FORBIDDEN, "forbidden".into()));
    }

    let result = state
        .store
        .end_room_call(&room_id, &call_id, Some(&requester_device_id), now_ms())
        .await;
    let result = match result {
        Ok(result) => result,
        Err(RoomCallControlError::RoomNotFound | RoomCallControlError::CallNotFound) => {
            return Err((StatusCode::NOT_FOUND, "room call not found".into()));
        }
        Err(RoomCallControlError::NotActiveMember) => {
            return Err((StatusCode::FORBIDDEN, "forbidden".into()));
        }
        Err(RoomCallControlError::CallNotActive | RoomCallControlError::ParticipantNotJoined) => {
            return Err((StatusCode::CONFLICT, "room call state conflict".into()));
        }
        Err(RoomCallControlError::Storage(err)) => {
            return Err((StatusCode::INTERNAL_SERVER_ERROR, err));
        }
    };
    let (room, call, participants, self_participant) =
        room_call_snapshot_to_http_parts(result.snapshot)?;

    tracing::info!(
        room_ref=%log_fingerprint(&room_id),
        requester_device_ref=%log_fingerprint(&requester_device_id),
        requester_profile_ref=%log_fingerprint(&requester_profile_id),
        call_ref=%log_fingerprint(&call.call_id),
        changed=result.changed,
        "http room call end"
    );

    Ok(Json(HttpRoomCallMutationResp {
        ok: true,
        changed: result.changed,
        room,
        call,
        participants,
        self_participant,
    }))
}

async fn http_call_session(
    Path((device_id, call_id, call_attempt_id)): Path<(String, String, String)>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpCallSessionResp>, (StatusCode, String)> {
    if !is_valid_id(&device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }
    if !is_valid_id(&call_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad call_id".into()));
    }
    if !is_valid_id(&call_attempt_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad call_attempt_id".into()));
    }
    if require_auth_enabled() {
        let (_hdr_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_call_session_auth_message(
            &device_id,
            &call_id,
            &call_attempt_id,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
    }

    let session = state
        .store
        .get_call_session(&device_id, &call_id, &call_attempt_id, now_ms())
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;

    if let Some(session) = session {
        return Ok(Json(HttpCallSessionResp {
            exists: true,
            device_id,
            call_id,
            call_attempt_id,
            peer_device_id: Some(session.peer_device_id),
            direction: Some(session.direction),
            state: Some(session.state),
            last_action: Some(session.last_action),
            last_signal_id: Some(session.last_signal_id),
            last_created_at_ms: Some(session.last_created_at_ms),
            last_received_at_ms: Some(session.last_received_at_ms),
            invited_at_ms: session.invited_at_ms,
            accepted_at_ms: session.accepted_at_ms,
            offer_seen_at_ms: session.offer_seen_at_ms,
            answer_seen_at_ms: session.answer_seen_at_ms,
            reconnecting_at_ms: session.reconnecting_at_ms,
            ended_at_ms: session.ended_at_ms,
            expires_at_ms: Some(session.expires_at_ms),
        }));
    }

    Ok(Json(HttpCallSessionResp {
        exists: false,
        device_id,
        call_id,
        call_attempt_id,
        peer_device_id: None,
        direction: None,
        state: None,
        last_action: None,
        last_signal_id: None,
        last_created_at_ms: None,
        last_received_at_ms: None,
        invited_at_ms: None,
        accepted_at_ms: None,
        offer_seen_at_ms: None,
        answer_seen_at_ms: None,
        reconnecting_at_ms: None,
        ended_at_ms: None,
        expires_at_ms: None,
    }))
}

async fn http_ice_config(
    Path(device_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpIceConfigResp>, (StatusCode, String)> {
    if !is_valid_id(&device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }
    if require_auth_enabled() {
        let (_hdr_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_ice_config_auth_message(&device_id, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
    }

    Ok(Json(build_http_ice_config_resp_for_device(
        &state, &device_id,
    )?))
}

async fn http_room_call_media_get(
    Path((room_id, call_id)): Path<(String, String)>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpRoomCallMediaResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    if !is_valid_id(&call_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad call_id".into()));
    }
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_call_media_get_auth_message(
            &device_id, &room_id, &call_id, ts_ms, &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    ensure_room_active_member_access(&state, &room, &requester_profile_id).await?;

    let snapshot = state
        .store
        .get_room_call(&room_id, &call_id, Some(&requester_device_id))
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room call not found".into()))?;
    if !snapshot.call.state.eq_ignore_ascii_case("active") {
        return Err((StatusCode::CONFLICT, "room call is not active".into()));
    }

    let media = room_call_snapshot_to_media_resp(
        &state,
        &snapshot,
        &requester_device_id,
        &requester_profile_id,
    )?;

    tracing::info!(
        room_ref=%log_fingerprint(&room_id),
        requester_device_ref=%log_fingerprint(&requester_device_id),
        requester_profile_ref=%log_fingerprint(&requester_profile_id),
        call_ref=%log_fingerprint(&call_id),
        participant_count=media.participant_count,
        "http room call media get"
    );

    Ok(Json(media))
}

async fn http_room_call_media_join(
    Path((room_id, call_id)): Path<(String, String)>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpRoomCallMediaJoinReq>,
) -> Result<Json<HttpRoomCallMediaJoinResp>, (StatusCode, String)> {
    if !is_valid_room_id(&room_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad room_id".into()));
    }
    if !is_valid_id(&call_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad call_id".into()));
    }
    let requester_device_id = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_room_call_media_join_auth_message(
            &device_id,
            &room_id,
            &call_id,
            req.publish_audio,
            req.publish_video,
            req.publish_screen_share,
            req.subscribe_all,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        device_id
    } else {
        required_http_device_id_header(&headers)?
    };
    let requester_profile_id =
        requester_profile_id_for_device(&state, &requester_device_id).await?;

    let room = state
        .store
        .get_room(&room_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room not found".into()))?;
    ensure_room_active_member_access(&state, &room, &requester_profile_id).await?;

    let snapshot = state
        .store
        .get_room_call(&room_id, &call_id, Some(&requester_device_id))
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "room call not found".into()))?;
    if !snapshot.call.state.eq_ignore_ascii_case("active") {
        return Err((StatusCode::CONFLICT, "room call is not active".into()));
    }
    let self_participant = snapshot
        .self_participant
        .as_ref()
        .or_else(|| {
            snapshot
                .participants
                .iter()
                .find(|participant| participant.device_id == requester_device_id)
        })
        .ok_or((StatusCode::CONFLICT, "participant is not joined".into()))?;
    if !room_call_participant_is_joined(&self_participant.join_state) {
        return Err((StatusCode::CONFLICT, "participant is not joined".into()));
    }

    let snapshot = state
        .store
        .upsert_room_call_media_participant(
            &room_id,
            &call_id,
            &requester_profile_id,
            &requester_device_id,
            req.publish_audio,
            req.publish_video,
            req.publish_screen_share,
            req.subscribe_all,
            now_ms(),
        )
        .await
        .map_err(|err| match err {
            RoomCallControlError::RoomNotFound => (StatusCode::NOT_FOUND, "room not found".into()),
            RoomCallControlError::CallNotFound => {
                (StatusCode::NOT_FOUND, "room call not found".into())
            }
            RoomCallControlError::CallNotActive => {
                (StatusCode::CONFLICT, "room call is not active".into())
            }
            RoomCallControlError::NotActiveMember => (StatusCode::FORBIDDEN, "forbidden".into()),
            RoomCallControlError::ParticipantNotJoined => {
                (StatusCode::CONFLICT, "participant is not joined".into())
            }
            RoomCallControlError::Storage(err) => (StatusCode::INTERNAL_SERVER_ERROR, err),
        })?;

    let media = room_call_snapshot_to_media_resp(
        &state,
        &snapshot,
        &requester_device_id,
        &requester_profile_id,
    )?;

    tracing::info!(
        room_ref=%log_fingerprint(&room_id),
        requester_device_ref=%log_fingerprint(&requester_device_id),
        requester_profile_ref=%log_fingerprint(&requester_profile_id),
        call_ref=%log_fingerprint(&call_id),
        publish_audio=req.publish_audio,
        publish_video=req.publish_video,
        publish_screen_share=req.publish_screen_share,
        subscribe_all=req.subscribe_all,
        participant_count=media.participant_count,
        "http room call media join"
    );

    Ok(Json(HttpRoomCallMediaJoinResp { ok: true, media }))
}

/// Убирает `*.tmp`, пережившие прошлые запуски: обрыв соединения, падение
/// процесса, перезапуск посреди заливки.
///
/// Удаляются только файлы старше суток. Полностью best-effort: любая ошибка
/// проглатывается — уборка мусора не имеет права мешать старту релея.
async fn sweep_stale_tmp_blobs(blobs_dir: &std::path::Path) {
    const MAX_AGE: Duration = Duration::from_secs(24 * 60 * 60);
    let mut entries = match tokio::fs::read_dir(blobs_dir).await {
        Ok(v) => v,
        Err(_) => return,
    };
    let mut removed = 0u64;
    let mut freed_bytes = 0u64;
    while let Ok(Some(entry)) = entries.next_entry().await {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("tmp") {
            continue;
        }
        let Ok(meta) = entry.metadata().await else {
            continue;
        };
        if !meta.is_file() {
            continue;
        }
        let stale = meta
            .modified()
            .ok()
            .and_then(|m| m.elapsed().ok())
            .map(|age| age >= MAX_AGE)
            .unwrap_or(false);
        if !stale {
            continue;
        }
        let size = meta.len();
        if tokio::fs::remove_file(&path).await.is_ok() {
            removed += 1;
            freed_bytes += size;
        }
    }
    if removed > 0 {
        tracing::info!(
            files = removed,
            freed_mb = freed_bytes / (1024 * 1024),
            "swept stale blob upload temp files"
        );
    }
}

/// Удаляет временный файл заливки на любом выходе, пока его не обезвредили.
///
/// Синхронный `std::fs::remove_file` намеренно: `Drop` не может быть async, а
/// снятие одной ссылки — это микросекунды и только на путях, которые и так уже
/// провалились. Ошибка удаления проглатывается: файла может не быть, если
/// раньше сработала одна из явных веток очистки.
struct TmpBlobGuard {
    path: Option<std::path::PathBuf>,
}

impl TmpBlobGuard {
    fn arm(path: std::path::PathBuf) -> Self {
        Self { path: Some(path) }
    }

    /// Файл больше не временный — он переименован в постоянный.
    fn disarm(&mut self) {
        self.path = None;
    }
}

impl Drop for TmpBlobGuard {
    fn drop(&mut self) {
        if let Some(path) = self.path.take() {
            let _ = std::fs::remove_file(&path);
        }
    }
}

async fn http_blob_upload(
    State(state): State<AppState>,
    Query(q): Query<BlobUploadQuery>,
    headers: HeaderMap,
    body: Body,
) -> Result<Json<BlobUploadResp>, (StatusCode, String)> {
    let ttl_seconds = q.ttl_seconds.unwrap_or(7 * 24 * 3600).min(30 * 24 * 3600) as i64;
    let now = now_ms();
    let expires_at_ms = now + ttl_seconds * 1000;
    let access_token_sha256_b64 = header_str(&headers, "x-secretly-blob-access-token-sha256-b64")
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
        .ok_or((
            StatusCode::BAD_REQUEST,
            "missing blob access token hash".into(),
        ))?;
    if access_token_sha256_b64.len() > 512 {
        return Err((StatusCode::BAD_REQUEST, "bad blob access token hash".into()));
    }

    let pre_auth = if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let body_hash_header = header_str(&headers, "x-secretly-body-sha256-b64")
            .map(|v| v.trim().to_string())
            .filter(|v| !v.is_empty());

        if let Some(ref expected_hash) = body_hash_header {
            if expected_hash.len() > 512 {
                return Err((StatusCode::BAD_REQUEST, "bad body hash header".into()));
            }
            let msg = http_blob_upload_auth_message(
                &device_id,
                ttl_seconds as u64,
                expected_hash,
                &access_token_sha256_b64,
                ts_ms,
                &nonce_b64,
            );
            let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
        }

        Some((device_id, ts_ms, nonce_b64, body_hash_header))
    } else {
        None
    };

    // §C-3 (TZ-MONETIZE-01): per-tier attachment ceiling, enforced server-side.
    // Fail-open: monetization disabled / unauthenticated / unresolved entitlement
    // => the hard blob cap (unchanged behaviour). The uploader device in pre_auth
    // isn't signature-verified yet here, but it only narrows the cap; a spoofed
    // device still fails the post-stream auth check below.
    let blob_cap: u64 = if state.monetization_enabled {
        let mut cap = RELAY_MAX_BLOB_BYTES;
        if let Some((device_id, _, _, _)) = pre_auth.as_ref() {
            if let Some(pid) = fetch_profile_id(&state, device_id).await {
                if let Some(ent) = fetch_entitlement(&state, &pid).await {
                    if ent.attachment_bytes > 0 {
                        cap = (ent.attachment_bytes as u64).min(RELAY_MAX_BLOB_BYTES);
                    }
                }
            }
        }
        cap
    } else {
        RELAY_MAX_BLOB_BYTES
    };

    // MVP guardrail (also protects server RAM/disk).
    let blob_id = Uuid::now_v7().to_string();
    let rel_path = format!("{blob_id}.bin");
    let abs_path = state.blobs_dir.join(&rel_path);

    tokio::fs::create_dir_all(state.blobs_dir.as_ref())
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    // Write to temp first (so we can delete if auth fails).
    let tmp_path = state.blobs_dir.join(format!("{blob_id}.tmp"));
    let mut f = tokio::fs::File::create(&tmp_path)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    // 🔴 СТРАЖ ВРЕМЕННОГО ФАЙЛА (02.09.2026, аудит передачи файлов).
    //
    // Явное удаление стояло только на трёх ветках: превышение лимита,
    // несовпадение хеша, провал подписи. Всё остальное оставляло `.tmp`
    // навсегда — обрыв клиента посреди тела, ошибка записи на диск, провал
    // flush, неизвестное устройство, провал самого rename и, отдельно, отказ
    // от future самим axum, когда соединение умирает: там ни одна строка
    // обработчика уже не выполнится, а `Drop` — выполнится.
    //
    // Убрать это потом было НЕЧЕМ: `cleanup_expired_blobs` ходит по строкам
    // таблицы, а до `blob_insert` оборванная заливка не доходит. Отмена на
    // 90 % от 200 МБ — это 180 МБ, лежащих на диске релея вечно. Хуже: скрипт
    // ежедневной копии архивирует папку `blobs` целиком, поэтому мусор
    // попадал ещё и в каждый бэкап.
    let mut tmp_guard = TmpBlobGuard::arm(tmp_path.clone());

    let mut hasher = Sha256::new();
    let mut size: u64 = 0;
    let mut stream = body.into_data_stream();
    while let Some(next) = stream.next().await {
        let chunk = next.map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;
        size = size.saturating_add(chunk.len() as u64);
        if size > blob_cap {
            let _ = tokio::fs::remove_file(&tmp_path).await;
            return Err((StatusCode::PAYLOAD_TOO_LARGE, "blob too large".into()));
        }
        hasher.update(chunk.as_ref());
        f.write_all(chunk.as_ref())
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    }
    f.flush()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let body_sha256_b64 = base64::engine::general_purpose::STANDARD.encode(hasher.finalize());

    let mut owner_device_id = String::new();
    let mut owner_profile_id = String::new();
    if let Some((device_id, ts_ms, nonce_b64, body_hash_header)) = pre_auth {
        if let Some(expected_hash) = body_hash_header {
            if expected_hash != body_sha256_b64 {
                let _ = tokio::fs::remove_file(&tmp_path).await;
                return Err((StatusCode::UNAUTHORIZED, "body hash mismatch".into()));
            }
        } else {
            let msg = http_blob_upload_auth_message(
                &device_id,
                ttl_seconds as u64,
                &body_sha256_b64,
                &access_token_sha256_b64,
                ts_ms,
                &nonce_b64,
            );
            if let Err(e) = verify_http_auth(&state, &headers, Some(&device_id), msg).await {
                let _ = tokio::fs::remove_file(&tmp_path).await;
                return Err(e);
            }
        }

        owner_device_id = device_id;
        owner_profile_id = fetch_profile_id(&state, &owner_device_id)
            .await
            .ok_or((StatusCode::UNAUTHORIZED, "unknown device".into()))?;
    }

    // Best-effort cleanup of expired blobs.
    if let Ok(expired) = state.store.cleanup_expired_blobs(now).await {
        for rel in expired {
            let _ = tokio::fs::remove_file(state.blobs_dir.join(rel)).await;
        }
    }

    tokio::fs::rename(&tmp_path, &abs_path)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    // 🔴 ТОЛЬКО ПОСЛЕ УДАЧНОГО rename. Снять охрану раньше — значит оставить
    // мусор при провале переименования; не снять вовсе — значит удалить
    // только что принятый блоб по его новому имени.
    tmp_guard.disarm();

    state
        .store
        .blob_insert(
            &blob_id,
            &rel_path,
            size,
            expires_at_ms,
            now,
            &owner_device_id,
            &owner_profile_id,
            &access_token_sha256_b64,
        )
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;

    Ok(Json(BlobUploadResp {
        blob_id,
        size_bytes: size,
        expires_at_ms,
    }))
}

struct SignedStickerCatalogManifest {
    raw_json: String,
    document: StickerCatalogDocument,
    signature_b64: String,
}

async fn load_signed_sticker_catalog_manifest(
    state: &AppState,
) -> Result<SignedStickerCatalogManifest, (StatusCode, String)> {
    let raw = match tokio::fs::read_to_string(state.sticker_catalog_dir.join("catalog.json")).await
    {
        Ok(value) => value,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            return Ok(SignedStickerCatalogManifest {
                raw_json: STICKER_CATALOG_DEFAULT_RAW_JSON.to_string(),
                document: StickerCatalogDocument::default(),
                signature_b64: STICKER_CATALOG_DEFAULT_SIGNATURE_B64.to_string(),
            });
        }
        Err(error) => {
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("failed to read sticker catalog: {error}"),
            ));
        }
    };
    let parsed = StickerCatalogDocument::from_json_str(&raw).map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("invalid sticker catalog: {error}"),
        )
    })?;
    let signature_b64 =
        match tokio::fs::read_to_string(state.sticker_catalog_dir.join("catalog.sig")).await {
            Ok(value) => value.trim().to_string(),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                return Err((
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "sticker catalog signature is missing".into(),
                ));
            }
            Err(error) => {
                return Err((
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("failed to read sticker catalog signature: {error}"),
                ));
            }
        };
    if signature_b64.is_empty() {
        return Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            "sticker catalog signature is empty".into(),
        ));
    }
    if !verify_ed25519_b64(
        STICKER_CATALOG_SIGNING_PUBLIC_KEY_B64,
        &signature_b64,
        raw.as_bytes(),
    ) {
        return Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            "invalid sticker catalog signature".into(),
        ));
    }
    Ok(SignedStickerCatalogManifest {
        raw_json: raw,
        document: parsed,
        signature_b64,
    })
}

async fn load_sticker_catalog_document(
    state: &AppState,
) -> Result<StickerCatalogDocument, (StatusCode, String)> {
    Ok(load_signed_sticker_catalog_manifest(state).await?.document)
}

async fn http_sticker_catalog_manifest(
    State(state): State<AppState>,
) -> Result<impl IntoResponse, (StatusCode, String)> {
    let catalog = load_signed_sticker_catalog_manifest(&state).await?;
    let mut headers = HeaderMap::new();
    headers.insert(
        header::CONTENT_TYPE,
        HeaderValue::from_static("application/json"),
    );
    headers.insert(
        header::HeaderName::from_static(STICKER_CATALOG_SIGNATURE_HEADER),
        HeaderValue::from_str(&catalog.signature_b64).map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("invalid sticker catalog signature header: {error}"),
            )
        })?,
    );
    Ok((headers, catalog.raw_json))
}

async fn http_sticker_catalog_asset(
    Path((pack_id, pack_version, sticker_id)): Path<(String, i64, String)>,
    State(state): State<AppState>,
) -> Result<([(header::HeaderName, &'static str); 1], Vec<u8>), (StatusCode, String)> {
    if !is_valid_id(&pack_id, 128) || !is_valid_id(&sticker_id, 128) || pack_version <= 0 {
        return Err((StatusCode::BAD_REQUEST, "bad sticker asset path".into()));
    }
    let catalog = load_sticker_catalog_document(&state).await?;
    let (asset_path, content_type) = catalog
        .asset_path_and_content_type(
            state.sticker_catalog_dir.as_ref(),
            &pack_id,
            pack_version,
            &sticker_id,
        )
        .map_err(|error| (StatusCode::NOT_FOUND, error))?;
    let data = tokio::fs::read(&asset_path)
        .await
        .map_err(|_| (StatusCode::NOT_FOUND, "sticker asset not found".into()))?;
    Ok(([(header::CONTENT_TYPE, content_type)], data))
}

struct SignedCosmeticsCatalogManifest {
    raw_json: String,
    document: CosmeticsCatalogDocument,
    signature_b64: String,
}

async fn load_signed_cosmetics_manifest(
    state: &AppState,
) -> Result<SignedCosmeticsCatalogManifest, (StatusCode, String)> {
    let raw = match tokio::fs::read_to_string(state.cosmetics_dir.join("catalog.json")).await {
        Ok(value) => value,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            // No catalog deployed yet → empty (clients show no server cosmetics).
            return Ok(SignedCosmeticsCatalogManifest {
                raw_json: COSMETICS_CATALOG_DEFAULT_RAW_JSON.to_string(),
                document: CosmeticsCatalogDocument::default(),
                signature_b64: COSMETICS_CATALOG_DEFAULT_SIGNATURE_B64.to_string(),
            });
        }
        Err(error) => {
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("failed to read cosmetics catalog: {error}"),
            ));
        }
    };
    let parsed = CosmeticsCatalogDocument::from_json_str(&raw).map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("invalid cosmetics catalog: {error}"),
        )
    })?;
    let signature_b64 =
        match tokio::fs::read_to_string(state.cosmetics_dir.join("catalog.sig")).await {
            Ok(value) => value.trim().to_string(),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                return Err((
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "cosmetics catalog signature is missing".into(),
                ));
            }
            Err(error) => {
                return Err((
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("failed to read cosmetics catalog signature: {error}"),
                ));
            }
        };
    if signature_b64.is_empty() {
        return Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            "cosmetics catalog signature is empty".into(),
        ));
    }
    if !verify_ed25519_b64(
        COSMETICS_CATALOG_SIGNING_PUBLIC_KEY_B64,
        &signature_b64,
        raw.as_bytes(),
    ) {
        return Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            "invalid cosmetics catalog signature".into(),
        ));
    }
    Ok(SignedCosmeticsCatalogManifest {
        raw_json: raw,
        document: parsed,
        signature_b64,
    })
}

async fn load_cosmetics_document(
    state: &AppState,
) -> Result<CosmeticsCatalogDocument, (StatusCode, String)> {
    Ok(load_signed_cosmetics_manifest(state).await?.document)
}

async fn http_cosmetics_manifest(
    State(state): State<AppState>,
) -> Result<impl IntoResponse, (StatusCode, String)> {
    let catalog = load_signed_cosmetics_manifest(&state).await?;
    let mut headers = HeaderMap::new();
    headers.insert(
        header::CONTENT_TYPE,
        HeaderValue::from_static("application/json"),
    );
    headers.insert(
        header::HeaderName::from_static(COSMETICS_CATALOG_SIGNATURE_HEADER),
        HeaderValue::from_str(&catalog.signature_b64).map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("invalid cosmetics catalog signature header: {error}"),
            )
        })?,
    );
    Ok((headers, catalog.raw_json))
}

async fn http_cosmetics_asset(
    Path((item_id, variant)): Path<(String, String)>,
    State(state): State<AppState>,
) -> Result<([(header::HeaderName, &'static str); 1], Vec<u8>), (StatusCode, String)> {
    if !is_valid_id(&item_id, 128) || (variant != "thumb" && variant != "full") {
        return Err((StatusCode::BAD_REQUEST, "bad cosmetic asset path".into()));
    }
    let catalog = load_cosmetics_document(&state).await?;
    let (asset_path, content_type) = catalog
        .asset_path_and_content_type(state.cosmetics_dir.as_ref(), &item_id, &variant)
        .map_err(|error| (StatusCode::NOT_FOUND, error))?;
    let data = tokio::fs::read(&asset_path)
        .await
        .map_err(|_| (StatusCode::NOT_FOUND, "cosmetic asset not found".into()))?;
    Ok(([(header::CONTENT_TYPE, content_type)], data))
}

/// 🔴 ОТДАЁТ ПОТОКОМ, А НЕ ЦЕЛИКОМ В ПАМЯТЬ (02.09.2026, аудит передачи файлов).
///
/// Раньше здесь стоял `tokio::fs::read` и возврат `Vec<u8>`, то есть память
/// релея под скачивания равнялась сумме размеров всех блобов, которые тянут
/// прямо сейчас. Потолок блоба — гигабайт; три получателя одного
/// двухсотмегабайтного видео давали шестьсот мегабайт мгновенного пика, а
/// клиент тянет вложения по три параллельно. Прямой путь к тому, что ядро
/// убьёт релей по памяти — на ровном месте, при исправной работе.
///
/// Асимметрия была видна невооружённым глазом: ЗАЛИВКА уже потоковая, кусками
/// по мере поступления, а отдача — нет.
///
/// `Content-Length` ставится явно из метаданных файла, чтобы клиент по-прежнему
/// видел размер заранее и мог показывать прогресс. Шифротекст не трогается:
/// сервер отдаёт те же байты, только не собирая их в один буфер.
async fn http_blob_get(
    Path(blob_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<axum::response::Response, (StatusCode, String)> {
    let access_token_b64 = header_str(&headers, "x-secretly-blob-access-token-b64")
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty());
    let access_token_sha256_b64 = match access_token_b64.as_deref() {
        Some(token) => Some(blob_access_token_hash_b64(token)?),
        None => None,
    };
    let mut requester_profile_id = String::new();
    if require_auth_enabled() {
        let (hdr_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_blob_get_auth_message(
            &hdr_device_id,
            &blob_id,
            access_token_sha256_b64.as_deref(),
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&hdr_device_id), msg).await?;
        requester_profile_id = fetch_profile_id(&state, &hdr_device_id)
            .await
            .ok_or((StatusCode::UNAUTHORIZED, "unknown device".into()))?;
    }

    // Best-effort cleanup.
    if let Ok(expired) = state.store.cleanup_expired_blobs(now_ms()).await {
        for rel in expired {
            let _ = tokio::fs::remove_file(state.blobs_dir.join(rel)).await;
        }
    }

    let now = now_ms();
    let row = state
        .store
        .blob_get(&blob_id, now)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    let Some(row) = row else {
        return Err((StatusCode::NOT_FOUND, "not found".into()));
    };

    ensure_blob_capability_authorized(
        &row.access_token_sha256_b64,
        access_token_sha256_b64.as_deref(),
    )?;

    if require_auth_enabled()
        && !row.owner_profile_id.is_empty()
        && !requester_profile_id.is_empty()
    {
        let blocked = state
            .store
            .is_blocked(&row.owner_profile_id, &requester_profile_id)
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
        if blocked {
            return Err((StatusCode::FORBIDDEN, "forbidden".into()));
        }
    }

    let abs_path = state.blobs_dir.join(row.rel_path);
    let file = tokio::fs::File::open(&abs_path)
        .await
        .map_err(|_| (StatusCode::NOT_FOUND, "not found".into()))?;
    // Длина — из метаданных файла: это ровно те байты, что уйдут в поток.
    // (В `BlobRow` размера нет; тянуть его из базы значило бы менять слой
    // хранения ради числа, которое файловая система уже знает.) Если метаданные
    // недоступны, заголовок просто не ставится: ответ уйдёт chunked, и клиент
    // получит те же байты, лишившись только заранее известного размера.
    let content_length = file.metadata().await.ok().map(|m| m.len());
    let stream = tokio_util::io::ReaderStream::new(file);
    let body = axum::body::Body::from_stream(stream);
    let mut builder = axum::response::Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, "application/octet-stream");
    if let Some(len) = content_length {
        builder = builder.header(header::CONTENT_LENGTH, len);
    }
    builder
        .body(body)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))
}

async fn http_blocks_list(
    Path(device_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpBlocksListResp>, (StatusCode, String)> {
    if !is_valid_id(&device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }

    if require_auth_enabled() {
        let (_hdr_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_blocks_list_auth_message(&device_id, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
    }

    let owner_profile_id = fetch_profile_id(&state, &device_id)
        .await
        .ok_or((StatusCode::UNAUTHORIZED, "unknown device".into()))?;

    let rows = state
        .store
        .list_blocks(&owner_profile_id, 2000)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;

    Ok(Json(HttpBlocksListResp {
        device_id,
        blocked_profile_ids: rows.into_iter().map(|r| r.blocked_profile_id).collect(),
    }))
}

/// Sprint 2 R3: return the subset of `profile_id`'s devices that are
/// currently considered live by the relay's activity tracker.
///
/// `device_id` (path) is the **requester**, not the target. We sign
/// the request as the requester so any authenticated peer can probe
/// liveness for any profile — this is the same shape used by
/// `/v1/blocks/{device_id}` and other authenticated reads.
///
/// Behavior is fully gated by `RELAY_DEVICE_STALENESS_FILTER_ENABLED`:
/// when disabled (default), the response advertises `filter_applied=false`
/// and returns all activity-known device IDs without any staleness check.
/// The client treats `filter_applied=false` as «do not narrow the fanout».
async fn http_active_devices(
    Path((device_id, profile_id)): Path<(String, String)>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpActiveDevicesResp>, (StatusCode, String)> {
    if !is_valid_id(&device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }
    if !is_valid_id(&profile_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad profile_id".into()));
    }

    if require_auth_enabled() {
        let (_hdr_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_active_devices_auth_message(&device_id, &profile_id, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
    }

    let now = now_ms();
    let activity_rows = state
        .store
        .device_activity_list_for_profile(&profile_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;

    let filter_enabled = device_staleness_filter_enabled();
    // Факты о жизни — до фильтра: клиенту нужны ВСЕ известные устройства с их
    // отметками, а не только те, что пережили серверный порог в 30 дней.
    let devices: Vec<HttpDeviceLiveness> = activity_rows
        .iter()
        .map(|row| HttpDeviceLiveness {
            device_id: row.device_id.clone(),
            last_signal_ms: row.last_pump_at_ms.max(row.last_push_delivered_at_ms),
            superseded: row.superseded_at_ms > 0,
        })
        .collect();
    let (device_ids, filter_applied) = compute_active_device_ids(
        activity_rows,
        filter_enabled,
        now,
        DEVICE_STALENESS_THRESHOLD_MS,
    );
    if !filter_applied {
        tracing::debug!(
            profile_ref = %log_fingerprint(&profile_id),
            "active_devices: returning unfiltered set (filter off / would empty)"
        );
    }

    Ok(Json(HttpActiveDevicesResp {
        profile_id,
        filter_applied,
        device_ids,
        now_ms: now,
        threshold_ms: DEVICE_STALENESS_THRESHOLD_MS,
        devices,
    }))
}

/// Pure fanout-narrowing decision for `GET /v1/active_devices` (extracted so it
/// is unit-testable). Rules:
///   * A SUPERSEDED device (rotated away — proven by a push-token takeover, see
///     `upsert_push_token`) is dropped UNCONDITIONALLY. The signal is
///     unambiguous, so unlike the conservative 30-day staleness heuristic it is
///     NOT gated by `RELAY_DEVICE_STALENESS_FILTER_ENABLED`.
///   * A 30-day-silent device is dropped only when `filter_enabled`.
///   * INV-1: narrowing NEVER empties the fanout and never applies when it would
///     be a no-op — in those cases the FULL set is returned with
///     `filter_applied=false`, so the client keeps its own bundle-derived set.
/// This makes the common case (no superseded device, filter off) byte-identical
/// to the historical behaviour — zero blast radius outside a genuine rotation.
fn compute_active_device_ids(
    rows: Vec<DeviceActivityRow>,
    filter_enabled: bool,
    now: i64,
    threshold: i64,
) -> (Vec<String>, bool) {
    let has_superseded = rows.iter().any(|r| r.superseded_at_ms > 0);
    if (!filter_enabled && !has_superseded) || rows.is_empty() {
        return (rows.into_iter().map(|r| r.device_id).collect(), false);
    }
    let active: Vec<String> = rows
        .iter()
        .filter(|row| {
            if row.superseded_at_ms > 0 {
                return false;
            }
            if !filter_enabled {
                return true;
            }
            let last_signal = row.last_pump_at_ms.max(row.last_push_delivered_at_ms);
            now.saturating_sub(last_signal) <= threshold
        })
        .map(|row| row.device_id.clone())
        .collect();
    if active.is_empty() {
        // INV-1 safety: return the full set unfiltered rather than an empty one.
        (rows.into_iter().map(|r| r.device_id).collect(), false)
    } else {
        (active, true)
    }
}

async fn http_blocks_set(
    Path(device_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpBlocksSetReq>,
) -> Result<Json<HttpBlocksSetResp>, (StatusCode, String)> {
    if !is_valid_id(&device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }
    if !is_valid_id(&req.blocked_profile_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad blocked_profile_id".into()));
    }

    if require_auth_enabled() {
        let (_hdr_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_blocks_set_auth_message(
            &device_id,
            &req.blocked_profile_id,
            req.blocked,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
    }

    let owner_profile_id = fetch_profile_id(&state, &device_id)
        .await
        .ok_or((StatusCode::UNAUTHORIZED, "unknown device".into()))?;
    if owner_profile_id == req.blocked_profile_id {
        return Err((StatusCode::BAD_REQUEST, "cannot block self".into()));
    }

    state
        .store
        .set_block(
            &owner_profile_id,
            &req.blocked_profile_id,
            req.blocked,
            now_ms(),
        )
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;

    Ok(Json(HttpBlocksSetResp { ok: true }))
}

// ── SUPPORT TICKETS ────────────────
// E2EE support channel: the relay stores ONLY ciphertext (sealed to the support
// key, whose private key lives only in the admin console) + the user's reply
// pubkey + anonymous profile_id. User endpoints are device-signature authed;
// admin endpoints are internal-key gated (fail-closed).

// Потолок ОДНОГО зашифрованного сообщения поддержки, в символах base64.
//
// 🔴 Поднято 03.08.2026 со 128 КБ (полевой отчёт: «пишет, что файл больше 58 КБ,
// хотя фото весит 5 МБ»). 128 КБ давали клиенту всего ~58 КБ сырого вложения, и
// приложить обычный снимок экрана было нельзя.
//
// Откуда 12 МБ. Вложение шифруется ЦЕЛИКОМ и едет одним телом, проходя base64
// ДВАЖДЫ: сперва внутри JSON, потом уже как шифртекст.
//   5 МБ сырых -> 6.67 МБ base64 внутри JSON -> +текст и тех-инфо
//   -> ~6.67 МБ открытого текста -> sealed-box -> 8.89 МБ base64 на проводе.
// 12 МБ дают запас и остаются вчетверо ниже общего предела тела
// (RELAY_HTTP_BODY_LIMIT_BYTES = 25 МБ).
const SUPPORT_CIPHERTEXT_MAX_B64: usize = 12 * 1024 * 1024;

// 🔴 Бюджет ОДНОГО ответа со списком, в байтах шифртекстов.
//
// Списки считали ШТУКИ, а не байты: у тикетов лимит по умолчанию 200 (до 1000),
// у ответов — 100 (до 500). Пока сообщение весило 128 КБ, это было безобидно.
// С вложением в 9 МБ тот же запрос попытался бы отдать ПОЛТОРА ГИГАБАЙТА и
// положил бы и консоль, и реле.
//
// Поэтому набор обрывается по суммарному весу. ОДИН тикет отдаётся всегда,
// даже если он один переполняет бюджет, иначе большое обращение стало бы
// недостижимым. Консоль дочитывает остальное следующим запросом (`since` /
// `from`) — форма ответа не меняется, старая админка продолжает работать.
const SUPPORT_LIST_BYTE_BUDGET: usize = 24 * 1024 * 1024;
const SUPPORT_META_MAX: usize = 8 * 1024;
const SUPPORT_PUBKEY_MAX_B64: usize = 128;

#[derive(Deserialize)]
struct HttpSupportSubmitReq {
    ticket_id: String,
    reply_pubkey_b64: String,
    ciphertext_b64: String,
    #[serde(default)]
    client_meta_json: Option<String>,
}
#[derive(Serialize)]
struct HttpSupportSubmitResp {
    ok: bool,
    ticket_id: String,
}
#[derive(Deserialize)]
struct SupportRepliesQuery {
    from: Option<i64>,
    limit: Option<u64>,
}
#[derive(Serialize)]
struct HttpSupportReplyItem {
    reply_id: String,
    ticket_id: String,
    seq: i64,
    ciphertext_b64: String,
    created_at_ms: i64,
}
#[derive(Serialize)]
struct HttpSupportRepliesResp {
    replies: Vec<HttpSupportReplyItem>,
    /// Когда переписку профиля стёрли из админки (0 — не стирали).
    ///
    /// 🔴 Без этого поля удаление НЕ ВИДНО телефону: он спрашивает ответы новее
    /// своего курсора, и пустой ответ после очистки неотличим от обычного
    /// «нового ничего нет» — лента и красный кружок остались бы навсегда.
    /// Поле добавлено в конец: старые сборки его просто не заметят.
    #[serde(default)]
    support_cleared_at_ms: i64,
}
#[derive(Deserialize)]
struct SupportAdminTicketsQuery {
    since: Option<i64>,
    limit: Option<u64>,
}
#[derive(Serialize)]
struct HttpSupportTicketItem {
    ticket_id: String,
    profile_id_prefix: String,
    reply_pubkey_b64: String,
    ciphertext_b64: String,
    client_meta_json: Option<String>,
    created_at_ms: i64,
    status: String,
}
#[derive(Serialize)]
struct HttpSupportAdminTicketsResp {
    tickets: Vec<HttpSupportTicketItem>,
}
#[derive(Deserialize)]
struct HttpSupportAdminReplyReq {
    reply_id: String,
    ticket_id: String,
    ciphertext_b64: String,
}
#[derive(Serialize)]
struct HttpSupportAdminReplyResp {
    ok: bool,
    seq: i64,
}

fn http_support_submit_auth_message(
    device_id: &str,
    ticket_id: &str,
    reply_pubkey_b64: &str,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-SUPPORT-SUBMIT-V1\ndevice_id={}\nticket_id={}\nreply_pubkey_b64={}\nts_ms={}\nnonce_b64={}\n",
        device_id, ticket_id, reply_pubkey_b64, ts_ms, nonce_b64
    )
    .into_bytes()
}

fn http_support_replies_auth_message(
    device_id: &str,
    from: i64,
    ts_ms: i64,
    nonce_b64: &str,
) -> Vec<u8> {
    format!(
        "SECRETLY-RELAY-HTTP-SUPPORT-REPLIES-V1\ndevice_id={}\nfrom={}\nts_ms={}\nnonce_b64={}\n",
        device_id, from, ts_ms, nonce_b64
    )
    .into_bytes()
}

/// Inbound internal-key gate for admin support endpoints (ported from the keys
/// service). Fail-closed when the key is unset.
fn internal_key_matches(state: &AppState, headers: &HeaderMap) -> bool {
    let expected = state.internal_key.as_str();
    if expected.is_empty() {
        return false;
    }
    let got = header_str(headers, "x-secretly-internal-key").unwrap_or("");
    !got.is_empty() && got == expected
}

async fn http_support_submit(
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpSupportSubmitReq>,
) -> Result<Json<HttpSupportSubmitResp>, (StatusCode, String)> {
    if !is_valid_id(&req.ticket_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad ticket_id".into()));
    }
    if req.reply_pubkey_b64.is_empty() || req.reply_pubkey_b64.len() > SUPPORT_PUBKEY_MAX_B64 {
        return Err((StatusCode::BAD_REQUEST, "bad reply_pubkey_b64".into()));
    }
    if req.ciphertext_b64.is_empty() || req.ciphertext_b64.len() > SUPPORT_CIPHERTEXT_MAX_B64 {
        return Err((StatusCode::BAD_REQUEST, "bad ciphertext_b64".into()));
    }
    if let Some(m) = &req.client_meta_json {
        if m.len() > SUPPORT_META_MAX {
            return Err((StatusCode::BAD_REQUEST, "client_meta too large".into()));
        }
    }
    let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
    if !is_valid_id(&device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }
    if require_auth_enabled() {
        let msg = http_support_submit_auth_message(
            &device_id,
            &req.ticket_id,
            &req.reply_pubkey_b64,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
    }
    let profile_id = fetch_profile_id(&state, &device_id)
        .await
        .ok_or((StatusCode::UNAUTHORIZED, "unknown device".into()))?;
    state
        .store
        .support_ticket_insert(
            &req.ticket_id,
            &profile_id,
            &device_id,
            &req.reply_pubkey_b64,
            &req.ciphertext_b64,
            req.client_meta_json.as_deref(),
            now_ms(),
        )
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    Ok(Json(HttpSupportSubmitResp {
        ok: true,
        ticket_id: req.ticket_id,
    }))
}

async fn http_support_replies(
    Query(q): Query<SupportRepliesQuery>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpSupportRepliesResp>, (StatusCode, String)> {
    let from = q.from.unwrap_or(0).max(0);
    let limit = q.limit.unwrap_or(100).clamp(1, 500);
    let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
    if !is_valid_id(&device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }
    if require_auth_enabled() {
        let msg = http_support_replies_auth_message(&device_id, from, ts_ms, &nonce_b64);
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
    }
    let profile_id = fetch_profile_id(&state, &device_id)
        .await
        .ok_or((StatusCode::UNAUTHORIZED, "unknown device".into()))?;
    let rows = state
        .store
        .list_support_replies_from(&profile_id, from, limit)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    // Тот же бюджет, что и у списка тикетов: ответ поддержки тоже может нести
    // вложение, а телефон читает эту ленту по `from`. Один ответ отдаём всегда,
    // иначе тяжёлый ответ навсегда застрял бы и заблокировал ленту за собой.
    let mut spent: usize = 0;
    let mut replies: Vec<HttpSupportReplyItem> = Vec::new();
    for r in rows.into_iter() {
        let weight = r.ciphertext_b64.len();
        if !replies.is_empty() && spent + weight > SUPPORT_LIST_BYTE_BUDGET {
            break;
        }
        spent += weight;
        replies.push(HttpSupportReplyItem {
            reply_id: r.reply_id,
            ticket_id: r.ticket_id,
            seq: r.seq,
            ciphertext_b64: r.ciphertext_b64,
            created_at_ms: r.created_at_ms,
        });
    }
    let support_cleared_at_ms = state
        .store
        .support_cleared_at(&profile_id)
        .await
        .unwrap_or(0);
    Ok(Json(HttpSupportRepliesResp {
        replies,
        support_cleared_at_ms,
    }))
}

async fn http_support_admin_tickets(
    Query(q): Query<SupportAdminTicketsQuery>,
    headers: HeaderMap,
    State(state): State<AppState>,
) -> Result<Json<HttpSupportAdminTicketsResp>, (StatusCode, String)> {
    if !internal_key_matches(&state, &headers) {
        return Err((StatusCode::UNAUTHORIZED, "internal key required".into()));
    }
    let since = q.since.unwrap_or(0).max(0);
    let limit = q.limit.unwrap_or(200).clamp(1, 1000);
    let rows = state
        .store
        .list_support_tickets(since, limit)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    // Обрыв по суммарному весу, а не только по числу штук — см.
    // SUPPORT_LIST_BYTE_BUDGET. Первый тикет берём всегда, иначе одно тяжёлое
    // обращение стало бы недостижимым.
    let mut spent: usize = 0;
    let mut tickets: Vec<HttpSupportTicketItem> = Vec::new();
    for t in rows.into_iter() {
        let weight = t.ciphertext_b64.len();
        if !tickets.is_empty() && spent + weight > SUPPORT_LIST_BYTE_BUDGET {
            break;
        }
        spent += weight;
        tickets.push(HttpSupportTicketItem {
            ticket_id: t.ticket_id,
            profile_id_prefix: t.profile_id.chars().take(8).collect(),
            reply_pubkey_b64: t.reply_pubkey_b64,
            ciphertext_b64: t.ciphertext_b64,
            client_meta_json: t.client_meta_json,
            created_at_ms: t.created_at_ms,
            status: t.status,
        });
    }
    Ok(Json(HttpSupportAdminTicketsResp { tickets }))
}

#[derive(Deserialize)]
struct HttpSupportAdminClearReq {
    /// Любой тикет этой переписки — по нему находим профиль. Так админке не
    /// нужно знать полный profile_id (в консоли он показан лишь префиксом).
    ticket_id: String,
}

#[derive(Serialize)]
struct HttpSupportAdminClearResp {
    ok: bool,
    removed: i64,
}

/// Стереть всю переписку с поддержкой у одного пользователя.
///
/// Удаляет тикеты и ответы и ставит отметку времени, по которой телефон
/// поймёт, что ленты больше нет, и погасит свой красный кружок.
async fn http_support_admin_clear(
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpSupportAdminClearReq>,
) -> Result<Json<HttpSupportAdminClearResp>, (StatusCode, String)> {
    if !internal_key_matches(&state, &headers) {
        return Err((StatusCode::UNAUTHORIZED, "internal key required".into()));
    }
    if !is_valid_id(&req.ticket_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad ticket_id".into()));
    }
    // Профиль ищем ДО удаления: после него тикета уже не будет.
    let target = state
        .store
        .support_ticket_target(&req.ticket_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    let Some((profile_id, _)) = target else {
        return Err((StatusCode::NOT_FOUND, "unknown ticket".into()));
    };
    let removed = state
        .store
        .support_clear_profile(&profile_id, now_ms())
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    Ok(Json(HttpSupportAdminClearResp { ok: true, removed }))
}

async fn http_support_admin_reply(
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpSupportAdminReplyReq>,
) -> Result<Json<HttpSupportAdminReplyResp>, (StatusCode, String)> {
    if !internal_key_matches(&state, &headers) {
        return Err((StatusCode::UNAUTHORIZED, "internal key required".into()));
    }
    if !is_valid_id(&req.reply_id, 128) || !is_valid_id(&req.ticket_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad id".into()));
    }
    if req.ciphertext_b64.is_empty() || req.ciphertext_b64.len() > SUPPORT_CIPHERTEXT_MAX_B64 {
        return Err((StatusCode::BAD_REQUEST, "bad ciphertext_b64".into()));
    }
    let (profile_id, device_id) = state
        .store
        .support_ticket_target(&req.ticket_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        .ok_or((StatusCode::NOT_FOUND, "unknown ticket".into()))?;
    let seq = state
        .store
        .support_reply_insert(
            &req.reply_id,
            &req.ticket_id,
            &profile_id,
            &req.ciphertext_b64,
            now_ms(),
        )
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    // Wake the device that opened the ticket so the app fetches the reply.
    let st = state.clone();
    tokio::spawn(async move {
        // Support reply: keep the banner. `fetchSupportReplies` runs ONLY when
        // the user opens the support screen — there is no background poll and
        // no local notification, so this push is the ONLY thing that tells them
        // an answer arrived. Silencing it would silence support entirely.
        maybe_send_fcm_data_push(st, device_id, None, None, None, false, None).await;
    });
    Ok(Json(HttpSupportAdminReplyResp { ok: true, seq }))
}

fn normalize_push_platform(platform: Option<&str>) -> String {
    let raw = platform.unwrap_or("android").trim().to_ascii_lowercase();
    if raw.is_empty() {
        "android".to_string()
    } else {
        raw
    }
}

fn is_supported_push_registration_platform(platform: &str) -> bool {
    matches!(platform, "android" | "ios" | "ios_voip")
}

fn load_fcm_v1_config_from_path(path: &str) -> Option<FcmV1Config> {
    let text = std::fs::read_to_string(path).ok()?;
    let sa: FcmServiceAccount = serde_json::from_str(&text).ok()?;
    if sa.project_id.trim().is_empty()
        || sa.client_email.trim().is_empty()
        || sa.private_key.trim().is_empty()
        || sa.token_uri.trim().is_empty()
    {
        return None;
    }

    Some(FcmV1Config {
        send_url: format!(
            "https://fcm.googleapis.com/v1/projects/{}/messages:send",
            sa.project_id
        ),
        project_id: sa.project_id,
        client_email: sa.client_email,
        private_key_pem: sa.private_key,
        token_uri: sa.token_uri,
        scope: "https://www.googleapis.com/auth/firebase.messaging".to_string(),
    })
}

fn load_apns_voip_config_from_env() -> Option<ApnsVoipConfig> {
    let team_id = env::var("SECRETLY_APNS_TEAM_ID").ok()?.trim().to_string();
    let key_id = env::var("SECRETLY_APNS_KEY_ID").ok()?.trim().to_string();
    let key_path = env::var("SECRETLY_APNS_KEY_PATH").ok()?.trim().to_string();
    let private_key_pem = std::fs::read_to_string(&key_path).ok()?;
    let bundle_id = env::var("SECRETLY_APNS_BUNDLE_ID")
        .unwrap_or_else(|_| "com.secretly.messenger".to_string())
        .trim()
        .to_string();
    let topic = env::var("SECRETLY_APNS_VOIP_TOPIC")
        .unwrap_or_else(|_| format!("{bundle_id}.voip"))
        .trim()
        .to_string();
    let environment = env::var("SECRETLY_APNS_ENV")
        .unwrap_or_else(|_| "development".to_string())
        .trim()
        .to_ascii_lowercase();
    let endpoint_base = if matches!(environment.as_str(), "prod" | "production") {
        "https://api.push.apple.com".to_string()
    } else {
        "https://api.sandbox.push.apple.com".to_string()
    };
    let allow_environment_fallback = bool_env("SECRETLY_APNS_ENV_FALLBACK", true);

    if team_id.is_empty()
        || key_id.is_empty()
        || private_key_pem.trim().is_empty()
        || topic.is_empty()
    {
        return None;
    }

    Some(ApnsVoipConfig {
        team_id,
        key_id,
        private_key_pem,
        topic,
        endpoint_base,
        environment,
        allow_environment_fallback,
    })
}

fn build_google_jwt_assertion(cfg: &FcmV1Config, now_s: i64) -> Option<String> {
    let claims = GoogleJwtClaims {
        iss: &cfg.client_email,
        scope: &cfg.scope,
        aud: &cfg.token_uri,
        iat: now_s,
        exp: now_s + 3600,
    };

    let key = EncodingKey::from_rsa_pem(cfg.private_key_pem.as_bytes()).ok()?;
    let header = Header::new(Algorithm::RS256);
    jsonwebtoken::encode(&header, &claims, &key).ok()
}

fn build_apns_jwt(cfg: &ApnsVoipConfig, now_s: i64) -> Option<String> {
    let claims = ApnsJwtClaims {
        iss: &cfg.team_id,
        iat: now_s,
    };
    let key = EncodingKey::from_ec_pem(cfg.private_key_pem.as_bytes()).ok()?;
    let mut header = Header::new(Algorithm::ES256);
    header.kid = Some(cfg.key_id.clone());
    jsonwebtoken::encode(&header, &claims, &key).ok()
}

async fn get_apns_provider_jwt(state: &AppState, cfg: &ApnsVoipConfig) -> Option<String> {
    let now = now_ms();
    {
        let guard = state.apns_jwt_cache.lock().await;
        if let Some(cached) = guard.as_ref() {
            if cached.expires_at_ms > now + 60_000 {
                return Some(cached.jwt.clone());
            }
        }
    }

    let jwt = build_apns_jwt(cfg, now / 1000)?;
    {
        let mut guard = state.apns_jwt_cache.lock().await;
        *guard = Some(ApnsJwtCache {
            jwt: jwt.clone(),
            expires_at_ms: now + (50 * 60 * 1000),
        });
    }
    Some(jwt)
}

async fn get_fcm_v1_access_token(state: &AppState, cfg: &FcmV1Config) -> Option<String> {
    let now = now_ms();
    {
        let guard = state.fcm_oauth_cache.lock().await;
        if let Some(cached) = guard.as_ref() {
            if cached.expires_at_ms > now + 60_000 {
                return Some(cached.access_token.clone());
            }
        }
    }

    let assertion = match build_google_jwt_assertion(cfg, now / 1000) {
        Some(v) => v,
        None => {
            tracing::warn!(project_id=%cfg.project_id, "failed to build google jwt assertion for fcm oauth");
            return None;
        }
    };
    let form = [
        ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
        ("assertion", assertion.as_str()),
    ];

    let resp = match state.http.post(&cfg.token_uri).form(&form).send().await {
        Ok(v) => v,
        Err(e) => {
            tracing::warn!(error=%e, token_uri=%cfg.token_uri, project_id=%cfg.project_id, "fcm oauth token request transport failed");
            return None;
        }
    };

    if !resp.status().is_success() {
        let status = resp.status();
        let body = resp.text().await.unwrap_or_default();
        let body_summary = log_body_summary(&body);
        tracing::warn!(status=%status, body_summary=%body_summary, token_uri=%cfg.token_uri, project_id=%cfg.project_id, "fcm oauth token request failed");
        return None;
    }

    let body: GoogleTokenResp = match resp.json().await {
        Ok(v) => v,
        Err(e) => {
            tracing::warn!(error=%e, project_id=%cfg.project_id, "fcm oauth token response parse failed");
            return None;
        }
    };
    let expires_at = now + (body.expires_in.max(60) * 1000);

    {
        let mut guard = state.fcm_oauth_cache.lock().await;
        *guard = Some(FcmOAuthCache {
            access_token: body.access_token.clone(),
            expires_at_ms: expires_at,
        });
    }

    Some(body.access_token)
}

async fn resolve_push_sender_profile_and_name(
    state: &AppState,
    sender_device_id: Option<&str>,
) -> (Option<String>, Option<String>) {
    let mut profile_id = None;
    let mut display_name = None;

    if let Some(device_id) = sender_device_id {
        profile_id = fetch_profile_id(state, device_id)
            .await
            .and_then(|value| normalize_push_profile_id(&value));
    }

    if let Some(profile_id) = profile_id.as_deref() {
        display_name = fetch_profile_nickname(state, profile_id)
            .await
            .and_then(|value| normalize_push_text(Some(value.as_str()), 80));
    }

    (profile_id, display_name)
}

fn is_active_room_membership(row: Option<RoomMembershipRow>) -> bool {
    row.map(|membership| membership.status == "active")
        .unwrap_or(false)
}

async fn resolve_authoritative_message_convo_id(
    state: &AppState,
    to_device_id: &str,
    message: &MessageTransportMetaRecord,
) -> Option<String> {
    let sender_profile_id = message.sender_profile_id.as_deref()?;
    if !message.is_group {
        return Some(sender_profile_id.to_string());
    }

    let room_id = message.convo_id.trim();
    // Rooms are stored under the client-supplied convo id, which uses the
    // `group:` prefix (AppController creates group convo ids as `group:<id>`
    // and passes them verbatim as the relay room id). The previous hard-coded
    // `room:` requirement therefore never matched a real room, so per-room
    // mute / quiet-hours / title resolution were silently bypassed on the push
    // path. Validate the id shape only — membership is still verified below,
    // mirroring resolve_authoritative_room_push_id().
    if !is_valid_room_id(room_id, 160) {
        return None;
    }

    let recipient_profile_id = fetch_profile_id(state, to_device_id)
        .await
        .and_then(|value| normalize_push_profile_id(&value))?;
    let sender_membership = state
        .store
        .get_room_membership(room_id, sender_profile_id)
        .await
        .ok()
        .flatten();
    let recipient_membership = state
        .store
        .get_room_membership(room_id, &recipient_profile_id)
        .await
        .ok()
        .flatten();

    if is_active_room_membership(sender_membership)
        && is_active_room_membership(recipient_membership)
    {
        Some(room_id.to_string())
    } else {
        None
    }
}

async fn resolve_authoritative_room_push_id(
    state: &AppState,
    to_device_id: &str,
    sender_device_id: Option<&str>,
    room_id: &str,
) -> Option<String> {
    let room_id = room_id.trim();
    if !is_valid_room_id(room_id, 160) {
        return None;
    }

    let sender_profile_id = fetch_profile_id(state, sender_device_id?)
        .await
        .and_then(|value| normalize_push_profile_id(&value))?;
    let recipient_profile_id = fetch_profile_id(state, to_device_id)
        .await
        .and_then(|value| normalize_push_profile_id(&value))?;
    let sender_membership = state
        .store
        .get_room_membership(room_id, &sender_profile_id)
        .await
        .ok()
        .flatten();
    let recipient_membership = state
        .store
        .get_room_membership(room_id, &recipient_profile_id)
        .await
        .ok()
        .flatten();

    if is_active_room_membership(sender_membership)
        && is_active_room_membership(recipient_membership)
    {
        Some(room_id.to_string())
    } else {
        None
    }
}

fn build_generic_push_wake_payload(
    to_device_id: &str,
    sender_device_id: Option<&str>,
    msg_id: Option<&str>,
    include_notification: bool,
) -> PushWakePayload {
    let mut data = serde_json::Map::new();
    data.insert(
        "type".into(),
        serde_json::Value::String("relay_pending".to_string()),
    );
    data.insert(
        "device_id".into(),
        serde_json::Value::String(to_device_id.to_string()),
    );
    data.insert(
        "ts_ms".into(),
        serde_json::Value::String(now_ms().to_string()),
    );
    data.insert(
        "sender_device_id".into(),
        serde_json::Value::String(sender_device_id.unwrap_or("").to_string()),
    );
    data.insert(
        "msg_id".into(),
        serde_json::Value::String(msg_id.unwrap_or("").to_string()),
    );

    PushWakePayload {
        notification_title: "Secretly".to_string(),
        notification_body: "New message".to_string(),
        collapse_key: format!("secretly_pending_{}", to_device_id),
        notification_tag: msg_id.unwrap_or("secretly_pending").to_string(),
        include_notification,
        data,
        // Generic wakes (calls / control envelopes) never carry a message count;
        // leave the icon badge untouched.
        badge: None,
    }
}

async fn build_push_wake_payload(
    state: &AppState,
    to_device_id: &str,
    sender_device_id: Option<&str>,
    msg_id: Option<&str>,
    transport_meta_json: Option<&str>,
    push_policy_json: Option<&str>,
    // A wake that is ABOUT NOTHING: "come drain your mailbox", not "you have a
    // new message". Must never raise a banner or move the icon badge — see
    // where this is applied, at the very end of the builder.
    force_silent: bool,
) -> PushWakePayload {
    let notification_title = "Secretly".to_string();
    let mut notification_body = "New message".to_string();
    let device_ref = log_fingerprint(to_device_id);
    let push_policy = parse_push_policy_json(push_policy_json);
    let mut include_notification = push_policy
        .as_ref()
        .map(|policy| policy.notifications_enabled && policy.message_visual_alerts_enabled)
        .unwrap_or(true);
    let mut notification_title = notification_title;
    let mut notification_tag = msg_id.unwrap_or("secretly_pending").to_string();

    let mut data = serde_json::Map::new();
    data.insert(
        "type".into(),
        serde_json::Value::String("relay_pending".to_string()),
    );
    data.insert(
        "device_id".into(),
        serde_json::Value::String(to_device_id.to_string()),
    );
    data.insert(
        "ts_ms".into(),
        serde_json::Value::String(now_ms().to_string()),
    );
    data.insert(
        "sender_device_id".into(),
        serde_json::Value::String(sender_device_id.unwrap_or("").to_string()),
    );
    data.insert(
        "msg_id".into(),
        serde_json::Value::String(msg_id.unwrap_or("").to_string()),
    );

    let mut room_call_hint_applied = false;
    let mut any_transport_hint_applied = false;
    match parse_room_call_sync_transport_meta(transport_meta_json) {
        Ok(Some(room_call)) => {
            let Some(room_id) = resolve_authoritative_room_push_id(
                state,
                to_device_id,
                sender_device_id,
                &room_call.room_id,
            )
            .await
            else {
                tracing::warn!(device_ref=%device_ref, room_id=%room_call.room_id, "push wake room call metadata dropped because room membership was not verified");
                return build_generic_push_wake_payload(
                    to_device_id,
                    sender_device_id,
                    msg_id,
                    include_notification,
                );
            };
            notification_body = if room_call.call_exists {
                "Room call activity".to_string()
            } else {
                "Room call ended".to_string()
            };
            notification_tag = room_id.clone();
            if let Some(policy) = push_policy.as_ref() {
                include_notification = policy.notifications_enabled
                    && policy.incoming_calls_enabled
                    && !policy.muted_conversations.contains(&room_id);
            }
            data.insert(
                "wake_kind".into(),
                serde_json::Value::String("room_call_sync_v1".to_string()),
            );
            data.insert("room_id".into(), serde_json::Value::String(room_id.clone()));
            data.insert("convo_id".into(), serde_json::Value::String(room_id));
            data.insert(
                "call_exists".into(),
                serde_json::Value::String(if room_call.call_exists {
                    "true".to_string()
                } else {
                    "false".to_string()
                }),
            );
            data.insert(
                "state_version".into(),
                serde_json::Value::String(room_call.state_version.to_string()),
            );
            data.insert(
                "created_at_ms".into(),
                serde_json::Value::String(room_call.created_at_ms.to_string()),
            );
            if let Some(call_id) = room_call.call_id.as_deref() {
                data.insert(
                    "call_id".into(),
                    serde_json::Value::String(call_id.to_string()),
                );
            }
            room_call_hint_applied = true;
            any_transport_hint_applied = true;
        }
        Err(e) => {
            tracing::warn!(device_ref=%device_ref, error=%e, "push wake transport metadata parse failed");
        }
        Ok(None) => {}
    }

    if !room_call_hint_applied {
        match parse_room_call_media_signal_transport_meta(transport_meta_json) {
            Ok(Some(room_media_signal)) => {
                let Some(room_id) = resolve_authoritative_room_push_id(
                    state,
                    to_device_id,
                    sender_device_id,
                    &room_media_signal.room_id,
                )
                .await
                else {
                    tracing::warn!(device_ref=%device_ref, room_id=%room_media_signal.room_id, "push wake room media metadata dropped because room membership was not verified");
                    return build_generic_push_wake_payload(
                        to_device_id,
                        sender_device_id,
                        msg_id,
                        include_notification,
                    );
                };
                notification_body = "Room media update".to_string();
                notification_tag = room_id.clone();
                if let Some(policy) = push_policy.as_ref() {
                    include_notification = policy.notifications_enabled
                        && policy.incoming_calls_enabled
                        && !policy.muted_conversations.contains(&room_id);
                }
                data.insert(
                    "wake_kind".into(),
                    serde_json::Value::String("room_call_sync_v1".to_string()),
                );
                data.insert("room_id".into(), serde_json::Value::String(room_id.clone()));
                data.insert("convo_id".into(), serde_json::Value::String(room_id));
                data.insert(
                    "call_id".into(),
                    serde_json::Value::String(room_media_signal.call_id.clone()),
                );
                data.insert(
                    "call_exists".into(),
                    serde_json::Value::String("true".to_string()),
                );
                data.insert(
                    "state_version".into(),
                    serde_json::Value::String(room_media_signal.state_version.to_string()),
                );
                data.insert(
                    "descriptor_version".into(),
                    serde_json::Value::String(room_media_signal.descriptor_version.to_string()),
                );
                data.insert(
                    "created_at_ms".into(),
                    serde_json::Value::String(room_media_signal.created_at_ms.to_string()),
                );
                any_transport_hint_applied = true;
            }
            Err(e) => {
                tracing::warn!(device_ref=%device_ref, error=%e, "push wake room media transport metadata parse failed");
            }
            Ok(None) => {}
        }
    }

    if !room_call_hint_applied {
        match parse_call_invite_push_hint(transport_meta_json) {
            Ok(Some(call_hint)) => {
                let (caller_profile_id, caller_display_name) =
                    resolve_push_sender_profile_and_name(state, sender_device_id).await;
                let call_label = if call_hint.is_video {
                    "Incoming video call"
                } else {
                    "Incoming call"
                };
                notification_title = caller_display_name
                    .clone()
                    .unwrap_or_else(|| "Secretly".to_string());
                notification_body = call_label.to_string();
                if let Some(display_name) = caller_display_name.as_deref() {
                    data.insert(
                        "peer_name".into(),
                        serde_json::Value::String(display_name.to_string()),
                    );
                }
                if let Some(policy) = push_policy.as_ref() {
                    include_notification =
                        policy.should_alert_for_call(caller_profile_id.as_deref());
                }
                let canonical_call_convo_id = caller_profile_id.clone();
                if let Some(convo_id) = canonical_call_convo_id.as_deref() {
                    notification_tag = convo_id.to_string();
                    data.insert(
                        "convo_id".into(),
                        serde_json::Value::String(convo_id.to_string()),
                    );
                }
                if let Some(profile_id) = caller_profile_id.as_deref() {
                    data.insert(
                        "caller_profile_id".into(),
                        serde_json::Value::String(profile_id.to_string()),
                    );
                }
                data.insert(
                    "wake_kind".into(),
                    serde_json::Value::String("call_invite_v1".to_string()),
                );
                data.insert(
                    "action".into(),
                    serde_json::Value::String("invite".to_string()),
                );
                data.insert(
                    "display_mode".into(),
                    serde_json::Value::String("incoming".to_string()),
                );
                // Identity fields so the client can validate the specific
                // call attempt against the relay and dismiss stale native UX.
                data.insert(
                    "call_id".into(),
                    serde_json::Value::String(call_hint.call_id.clone()),
                );
                data.insert(
                    "call_attempt_id".into(),
                    serde_json::Value::String(call_hint.call_attempt_id.clone()),
                );
                data.insert(
                    "signal_id".into(),
                    serde_json::Value::String(call_hint.signal_id.clone()),
                );
                data.insert(
                    "created_at_ms".into(),
                    serde_json::Value::String(call_hint.created_at_ms.to_string()),
                );
                data.insert(
                    "is_video".into(),
                    serde_json::Value::String(if call_hint.is_video {
                        "true".to_string()
                    } else {
                        "false".to_string()
                    }),
                );
                data.insert(
                    "notification_label".into(),
                    serde_json::Value::String(call_label.to_string()),
                );
                any_transport_hint_applied = true;
            }
            Err(e) => {
                tracing::warn!(device_ref=%device_ref, error=%e, "push wake call transport metadata parse failed");
            }
            Ok(None) => {}
        }
    }

    if !room_call_hint_applied && !any_transport_hint_applied {
        match parse_call_signal_transport_meta(transport_meta_json) {
            Ok(Some(call_signal)) => {
                notification_body = "Call activity".to_string();
                notification_tag = call_signal.call_id.clone();
                include_notification = false;
                data.insert(
                    "wake_kind".into(),
                    serde_json::Value::String("call_signal_wake_v1".to_string()),
                );
                data.insert(
                    "display_mode".into(),
                    serde_json::Value::String("silent".to_string()),
                );
                data.insert(
                    "action".into(),
                    serde_json::Value::String(call_signal.action.clone()),
                );
                data.insert(
                    "call_id".into(),
                    serde_json::Value::String(call_signal.call_id.clone()),
                );
                data.insert(
                    "call_attempt_id".into(),
                    serde_json::Value::String(call_signal.call_attempt_id.clone()),
                );
                data.insert(
                    "signal_id".into(),
                    serde_json::Value::String(call_signal.signal_id.clone()),
                );
                data.insert(
                    "created_at_ms".into(),
                    serde_json::Value::String(call_signal.created_at_ms.to_string()),
                );
                any_transport_hint_applied = true;
            }
            Err(e) => {
                tracing::warn!(device_ref=%device_ref, error=%e, "push wake call signal metadata parse failed");
            }
            Ok(None) => {}
        }
    }

    if !room_call_hint_applied {
        match parse_chat_message_transport_meta(transport_meta_json) {
            Ok(Some(message_meta)) => {
                let (resolved_sender_profile_id, resolved_sender_name) =
                    resolve_push_sender_profile_and_name(state, sender_device_id).await;
                let metadata_sender_matches_auth = resolved_sender_profile_id
                    .as_deref()
                    .zip(message_meta.sender_profile_id.as_deref())
                    .map(|(resolved, provided)| resolved == provided)
                    .unwrap_or(false);
                let verified_metadata_sender_name = if metadata_sender_matches_auth {
                    message_meta.sender_display_name.clone()
                } else {
                    None
                };
                let message = MessageTransportMetaRecord {
                    sender_profile_id: resolved_sender_profile_id.clone(),
                    sender_display_name: resolved_sender_name
                        .clone()
                        .or(verified_metadata_sender_name),
                    ..message_meta
                };
                let authoritative_convo_id =
                    resolve_authoritative_message_convo_id(state, to_device_id, &message).await;
                let authoritative_room_title = if message.is_group {
                    if let Some(convo_id) = authoritative_convo_id.as_deref() {
                        state
                            .store
                            .get_room(convo_id)
                            .await
                            .ok()
                            .flatten()
                            .and_then(|room| normalize_push_text(Some(room.title.as_str()), 80))
                    } else {
                        None
                    }
                } else {
                    None
                };
                let policy_message = MessageTransportMetaRecord {
                    convo_id: authoritative_convo_id.clone().unwrap_or_default(),
                    ..message.clone()
                };
                let privacy_level = push_policy
                    .as_ref()
                    .map(|policy| policy.privacy_for_message(&policy_message))
                    .unwrap_or(if message.is_group { 1 } else { 2 });
                if let Some(policy) = push_policy.as_ref() {
                    include_notification =
                        policy.should_alert_for_message(&policy_message, now_ms());
                }

                // 🔴 ПОВТОРНАЯ ПОПЫТКА ДОСТАВКИ НЕ ПОДНИМАЕТ БАННЕР ЗАНОВО
                // (02.09.2026, полевая жалоба «повторные уведомления о
                // непрочитанном»).
                //
                // Страховка отправителя пересобирает недоставленное сообщение в
                // НОВЫЙ конверт с новым `msg_id`. Схлопывание по беседе при этом
                // отрабатывает верно — запись в центре уведомлений остаётся
                // одна, — но у `apns-collapse-id` семантика ЗАМЕНЫ, а замена
                // всплывает баннером и звучит заново. Человек видит, что
                // уведомление пришло опять о том, о чём ему уже сообщили.
                //
                // Ключ — `payload_event_id`: единственное, что переживает
                // переотправку. `created_at_ms` из этих же метаданных для такой
                // роли НЕ годится, хотя и выглядит подходяще: при пересборке
                // конверта туда попадает новое время постановки, а не время
                // создания сообщения.
                //
                // Конверт доезжает как раньше: тихое пробуждение будит
                // устройство, и оно забирает почту. Молчит только баннер.
                if include_notification && !message.payload_event_id.is_empty() {
                    const ALERT_REPEAT_WINDOW_MS: i64 = 10 * 60 * 1000;
                    let alert_key = format!("alert:{}", message.payload_event_id);
                    match state
                        .store
                        .try_mark_alert_shown(
                            to_device_id,
                            &alert_key,
                            now_ms(),
                            ALERT_REPEAT_WINDOW_MS,
                        )
                        .await
                    {
                        Ok(true) => {}
                        Ok(false) => {
                            include_notification = false;
                            tracing::info!(
                                device_ref = %device_ref,
                                "alert suppressed: banner already raised for this message"
                            );
                        }
                        // Не смогли проверить — ведём себя как раньше. Лишний
                        // баннер это неудобство, пропущенный — потерянное
                        // сообщение.
                        Err(e) => {
                            tracing::warn!(device_ref=%device_ref, error=%e, "alert dedup check failed");
                        }
                    }
                }

                if let Some(convo_id) = authoritative_convo_id.as_deref() {
                    notification_tag = convo_id.to_string();
                }
                data.insert(
                    "wake_kind".into(),
                    serde_json::Value::String("chat_message_v1".to_string()),
                );
                if let Some(convo_id) = authoritative_convo_id.as_deref() {
                    data.insert(
                        "convo_id".into(),
                        serde_json::Value::String(convo_id.to_string()),
                    );
                }
                data.insert(
                    "message_kind".into(),
                    serde_json::Value::String(message.message_kind.clone()),
                );
                data.insert(
                    "payload_event_id".into(),
                    serde_json::Value::String(message.payload_event_id.clone()),
                );
                data.insert(
                    "created_at_ms".into(),
                    serde_json::Value::String(message.created_at_ms.to_string()),
                );
                data.insert(
                    "is_group".into(),
                    serde_json::Value::String(if message.is_group {
                        "true".to_string()
                    } else {
                        "false".to_string()
                    }),
                );

                let sender_name = message.sender_display_name.clone();
                let group_title = authoritative_room_title;
                notification_title = if !include_notification || privacy_level <= 0 {
                    "Secretly".to_string()
                } else if privacy_level == 1 {
                    sender_name
                        .clone()
                        .unwrap_or_else(|| "Secretly".to_string())
                } else if message.is_group {
                    group_title
                        .clone()
                        .or(sender_name.clone())
                        .unwrap_or_else(|| "Secretly".to_string())
                } else {
                    sender_name
                        .clone()
                        .unwrap_or_else(|| "Secretly".to_string())
                };

                notification_body = if !include_notification || privacy_level <= 0 {
                    "New message".to_string()
                } else if privacy_level == 1 {
                    "New message".to_string()
                } else if message.is_group {
                    // Приватность (24.09.2026): текст сообщения в push не
                    // попадает никогда — только вид сообщения. Сообщение
                    // зашифровано сквозным образом; его начало не должно
                    // уходить Apple и Google.
                    let preview = push_body_for_kind(&message.message_kind);
                    if let Some(sender_name) = sender_name.as_deref() {
                        normalize_push_text(Some(format!("{sender_name}: {preview}").as_str()), 220)
                            .unwrap_or(preview)
                    } else {
                        preview
                    }
                } else {
                    push_body_for_kind(&message.message_kind)
                };
                data.insert(
                    "notification_title".into(),
                    serde_json::Value::String(notification_title.clone()),
                );
                data.insert(
                    "notification_body".into(),
                    serde_json::Value::String(notification_body.clone()),
                );
                any_transport_hint_applied = true;
            }
            Err(e) => {
                tracing::warn!(device_ref=%device_ref, error=%e, "push wake chat transport metadata parse failed");
            }
            Ok(None) => {}
        }
    }

    if !any_transport_hint_applied && is_session_heal_transport_meta(transport_meta_json) {
        // Silent Double-Ratchet session-heal wake (reset-ping / confirm-ping).
        // It raises no banner, but unlike a bare control envelope it carries a
        // real wake_kind so `push_wake_bypasses_interval_throttle` lets it wake a
        // frozen peer immediately — otherwise the throttle collapses it and a
        // diverged session stays unhealed until the peers happen to be online
        // together (message-loss audit 2026-07-08, F4).
        data.insert(
            "wake_kind".into(),
            serde_json::Value::String("session_heal_v1".to_string()),
        );
        include_notification = false;
        any_transport_hint_applied = true;
    }

    if !any_transport_hint_applied {
        // No chat/call transport hint present. Real user messages always carry
        // chat transport meta (text/sticker/attachment), so a metadata-less
        // wake from a modern client — one that registered a push policy — is a
        // control envelope: a read receipt, reaction, typing or multi-device
        // sync message. Wake the device silently so the app can process it, but
        // do NOT raise a banner (fixes "I get a notification when my message is
        // read"). Devices without a registered policy keep the legacy
        // generic-notify behaviour for backward compatibility.
        if push_policy.is_some() {
            include_notification = false;
        }
    }

    // 🔴 FIX 2026-07-30 (field reports: "a notification about an unread message
    // every half hour", "the icon says 51 unread and I have read everything").
    //
    // `include_notification` DEFAULTS TO TRUE and `notification_body` defaults to
    // "New message"; every branch that turns it off is reached only by PARSING
    // transport metadata. A bare device-level wake carries NO metadata, so not
    // one of those branches ran and the "silent" re-wake went out as a real
    // banner reading "Secretly — New message". The offline re-wake ladder sends
    // exactly such a wake every 10 min for a fresh stranded mailbox and every 30
    // MIN once the backlog is half an hour old — the reported cadence, repeated
    // for hours, about messages the user had already read.
    //
    // Forced here, at the very END, so no earlier branch can re-enable it: a
    // wake with nothing to announce announces nothing. The device still wakes
    // and drains its mailbox; anything genuinely new is announced by the app,
    // the only side that knows what is actually unread.
    if force_silent {
        include_notification = false;
    }

    // iOS app-icon unread badge: count only UNDELIVERED CHAT MESSAGES, not the
    // whole mailbox. `pending_count` also counts receipts / session-heal /
    // self-mirror / control envelopes (no chat transport_meta), which inflated
    // the badge — one user message enqueues the chat row plus a couple of control
    // rows, so the badge showed 3 per message. For a KILLED app (the only case
    // the client can't set the badge itself) pending-messages ≈ unread; a running
    // client overwrites it with the true unread total on foreground reconcile.
    // `None` on error leaves the current badge untouched.
    //
    // NOT on a silent wake (same 2026-07-30 report). This number is UNDELIVERED
    // MAILBOX ROWS, which only approximates "unread" while the device is
    // actually draining. A stranded mailbox — a rotated/zombie device_id whose
    // push token still points at the same phone — keeps that count forever, and
    // every re-wake stamped it back onto the icon, overwriting the true zero the
    // running client had just set. `None` leaves the icon exactly as it is.
    let badge = if force_silent {
        None
    } else {
        state
            .store
            .pending_message_count(to_device_id, now_ms())
            .await
            .ok()
            .map(|c| c.min(u64::from(u32::MAX)) as u32)
    };

    PushWakePayload {
        notification_title,
        notification_body,
        collapse_key: format!("secretly_pending_{}", to_device_id),
        notification_tag,
        include_notification,
        data,
        badge,
    }
}

fn is_supported_fcm_platform(platform: &str) -> bool {
    matches!(platform, "android" | "ios")
}

fn ios_message_notification_category_id(payload: &PushWakePayload) -> Option<&'static str> {
    if !payload.include_notification {
        return None;
    }
    let wake_kind = payload
        .data
        .get("wake_kind")
        .and_then(|value| value.as_str())
        .unwrap_or_default();
    if wake_kind != "chat_message_v1" {
        return None;
    }
    let convo_id = payload
        .data
        .get("convo_id")
        .and_then(|value| value.as_str())
        .unwrap_or_default()
        .trim();
    if convo_id.is_empty() || convo_id.starts_with("req:") {
        return None;
    }
    Some("secretly_chat_message_actions_v1")
}

fn push_payload_wake_kind(payload: &PushWakePayload) -> &str {
    payload
        .data
        .get("wake_kind")
        .and_then(|value| value.as_str())
        .unwrap_or_default()
}

/// Whether a wake must skip the coarse per-device interval throttle.
///
/// The throttle (`PUSH_WAKE_MIN_INTERVAL_MS`) exists to avoid waking a device
/// too often, but it is a SINGLE per-device timer shared across every wake
/// kind. A steady stream of *silent* control wakes (read receipts, typing,
/// multi-device sync — `wake_kind=""`, no banner) kept resetting that window
/// and starved every banner-raising chat message, so real notifications never
/// reached the user (observed in prod: 43/43 `chat_message_v1` wakes throttled,
/// 0 delivered). ALL chat messages and call invites must therefore bypass the
/// interval throttle.
///
/// R2 (2026-07-03): this now includes *silent* chat messages
/// (`include_notification == false` — muted / quiet-hours / notifications-off
/// conversations, common in group chats). The bypass is about the background
/// DATA wake that lets the device drain its mailbox and APPLY the message; the
/// visible banner stays separately suppressed by policy via
/// `should_include_fcm_notification`. Before this, a burst of quiet GROUP
/// messages to an offline member could have its only wake throttled away,
/// stranding those messages until the next reconnect. Bypassing is safe from
/// spamming the user because each message is de-duplicated per `msg_id`
/// (`try_mark_push_wake_sent`) and collapsed on-device via `collapse_key`, and
/// the banner remains policy-gated. Only truly silent CONTROL wakes
/// (`wake_kind == ""`) stay throttled — which is exactly what the throttle was
/// built to suppress.
fn push_wake_bypasses_interval_throttle(payload: &PushWakePayload) -> bool {
    let kind = push_payload_wake_kind(payload);
    // `session_heal_v1` is a silent Double-Ratchet recovery wake (reset-ping /
    // confirm-ping). It MUST NOT be throttled: on aggressive vendors (MIUI) a
    // frozen peer only heals when this wakes it, and the throttle used to
    // collapse it into the empty-kind control bucket, leaving a diverged session
    // unhealed until the next accidental co-online window (message-loss audit
    // 2026-07-08, F4). Dedup per `msg_id` + `collapse_key` still prevents spam.
    //
    // `call_signal_wake_v1` (offer / answer / ICE for an in-progress call) must
    // ALSO bypass: throttling it stalls call setup — a backgrounded/locked callee
    // that was woken by the invite still needs the offer + ICE to arrive to
    // negotiate media, and the throttle was dropping ~all of them mid-connect
    // (call audit 2026-07-09: 167 `call_signal_wake_v1` throttled → "calls
    // sometimes don't connect"). The signals are already user-initiated + bounded
    // to the brief connect window, and dedup per msg_id/collapse_key caps spam.
    kind == "call_invite_v1"
        || kind == "chat_message_v1"
        || kind == "session_heal_v1"
        || kind == "call_signal_wake_v1"
}

/// Можно ли схлопывать это пробуждение с уже отправленным.
///
/// 🔴 ТОЛЬКО ЧАТ. Звонки и лечение сессии не схлопываются НИКОГДА, и у каждого
/// свой шрам:
///
/// * `call_invite_v1` и `call_signal_wake_v1` — аудит звонков 09.07.2026: 167
///   задушенных сигналов связи давали «звонки иногда не соединяются»;
/// * `session_heal_v1` — разбор потери сообщений 08.07.2026 (F4): на MIUI
///   замороженный собеседник лечится ТОЛЬКО этим пробуждением.
///
/// Пустой вид тоже не трогаем: он и так под общим ограничителем в 3,5 с, и
/// расширять область правки без нужды значит увеличивать риск для доставки.
fn push_wake_is_coalescable(payload: &PushWakePayload) -> bool {
    push_payload_wake_kind(payload) == "chat_message_v1"
}

fn should_include_fcm_notification(payload: &PushWakePayload, platform: &str) -> bool {
    if !payload.include_notification {
        return false;
    }
    // Android must receive one-to-one call invites as high-priority data-only
    // messages. If FCM gets a top-level notification block while the app is in
    // the background, Play Services may render it itself and skip
    // FirebaseMessagingService, so the native full-screen call UI never opens.
    !(platform == "android" && push_payload_wake_kind(payload) == "call_invite_v1")
}

/// FCM `android.ttl` per wake kind.
///
/// DELIVERY-WAKE AUDIT (2026-07-16): the blanket `ttl="30s"` silently discarded
/// almost every wake sent to a dozing device. On mobile networks the device↔FCM
/// socket is routinely dead (carrier-NAT idle kill; FCM re-establishes on its
/// ~15–28 min heartbeat) and Doze batches delivery windows, so a push that
/// cannot be handed to the device within 30 seconds was dropped by FCM — the
/// visible banner rides the same message, so users saw NO notification at all.
/// Combined with the one-push-per-msg_id dedup this stranded mailboxes for
/// hours (prod case: 36 accepted FCM wakes, first device ack 86 minutes later,
/// on a stock Pixel with no battery saver).
///
/// Chat/control/heal wakes now survive 4 hours — long enough to outlive any
/// Doze window, short enough not to fire absurdly stale wakes. `collapse_key`
/// keeps at most ONE queued wake per device, so a long TTL cannot pile up.
/// Call wakes stay short: ringing someone for a call that ended long ago is
/// wrong (the APNs VoIP path already uses a 45s expiration for the same
/// reason).
fn fcm_android_ttl_for_payload(payload: &PushWakePayload) -> &'static str {
    let kind = push_payload_wake_kind(payload);
    if kind == "call_invite_v1" || kind == "call_signal_wake_v1" {
        "30s"
    } else {
        "14400s"
    }
}

/// Collapse identity for a wake push.
///
/// Collapse-id policy. `collapse_key` is PER-DEVICE (`secretly_pending_<dev>`)
/// — right for SILENT "you have mail" wakes (coalesce N redundant ones into
/// one), but WRONG for ALERT banners: apns-collapse-id / FCM collapse_key have
/// REPLACE semantics, so a per-device id makes every new message (from ANY chat)
/// overwrite the previous banner in Notification Center. That is the "half the
/// notifications never arrive / через раз" bug. Alerts collapse
/// PER-CONVERSATION instead (`notification_tag` = convo_id/room_id): a burst in
/// one chat coalesces into one updating banner, but different chats never
/// clobber each other (Telegram model).
///
/// 🔴 CALL WAKES GET THEIR OWN KEY (2026-08-08, field: "звонок отменил, но на
/// андроид не отменился" AND "звонки вообще не приходят при закрытом
/// приложении").
///
/// The same REPLACE semantics bite the SILENT path too, and that was missed
/// when the banner case was fixed. Call invites and call hangups are silent
/// (`include_notification == false`), so they rode the shared per-device key
/// together with every ordinary mailbox wake. While a device sleeps the delivery
/// service keeps exactly ONE message per key, so whichever silent wake arrived
/// last won:
///
///   * a `relay_pending` burst overwrote the queued INVITE  → the call never
///     rang at all;
///   * anything overwrote the queued HANGUP  → the native ring kept ringing
///     until its own timeout.
///
/// Field proof: two identical calls 27 s apart — the first hangup arrived in
/// 6.7 s, the second never arrived, and three `relay_pending` wakes landed
/// within 100 ms of the invite. Exactly the "через раз" signature.
///
/// The old reasoning ("any silent wake does the job of any other one") holds
/// for mailbox wakes, which ARE interchangeable, and they keep the per-device
/// key. It does NOT hold for call signals: an invite must ring and a hangup must
/// silence, so they are interchangeable neither with each other nor with the
/// mailbox stream. Hence per call AND per action.
/// Собственный ключ для звонковых пробуждений, или `None` для всех прочих.
///
/// Отдельной функцией НАМЕРЕННО: у двух сборщиков пуша разные исторические
/// правила для не-звонков (v1 разводит баннеры по переписке, старый формат — нет),
/// и правка про звонки не имеет права заодно менять эти правила.
fn push_call_collapse_key(payload: &PushWakePayload) -> Option<String> {
    let kind = push_payload_wake_kind(payload);
    if kind == "call_invite_v1" || kind == "call_signal_wake_v1" {
        let call_id = payload
            .data
            .get("call_id")
            .and_then(|value| value.as_str())
            .unwrap_or_default();
        let action = payload
            .data
            .get("action")
            .and_then(|value| value.as_str())
            .filter(|value| !value.is_empty())
            .unwrap_or(kind);
        // 🔴 ACTION FIRST, call_id SECOND — deliberately. The id is truncated to
        // 64 bytes for APNs (`truncate_collapse_id`), and `call_id` is accepted
        // up to 128 chars: with the id first, a long one would push the action
        // past the cut and an invite would collide with its own hangup again —
        // recreating the exact bug this function exists to prevent. Action first
        // keeps that distinction unconditionally; the worst a truncated call_id
        // can do is collide two DIFFERENT concurrent calls, which random ids make
        // vanishingly unlikely and which costs far less than the ring that never
        // stops.
        if !call_id.is_empty() {
            return Some(format!("secretly_call_{action}_{call_id}"));
        }
        // No call_id to key on: still keep call wakes out of the mailbox key
        // rather than letting them be clobbered by it.
        return Some(format!("secretly_call_{action}_{kind}"));
    }
    None
}

fn push_collapse_identity(payload: &PushWakePayload, include_notification: bool) -> String {
    if let Some(call_key) = push_call_collapse_key(payload) {
        return call_key;
    }
    if include_notification {
        payload.notification_tag.clone()
    } else {
        payload.collapse_key.clone()
    }
}

/// Apple rejects an apns-collapse-id longer than 64 BYTES with 400
/// BadCollapseId and drops the alert. convo/room/call ids the server accepts can
/// exceed that (≤128 / ≤160), so truncate on a char boundary. FCM's Android
/// collapse_key has no such limit but the shorter key is fine.
fn truncate_collapse_id(raw: String) -> String {
    if raw.len() > 64 {
        let mut end = 64;
        while end > 0 && !raw.is_char_boundary(end) {
            end -= 1;
        }
        raw[..end].to_string()
    } else {
        raw
    }
}

fn build_fcm_v1_message_payload(
    token: &str,
    payload: &PushWakePayload,
    platform: &str,
) -> serde_json::Value {
    let mut message = serde_json::Map::new();
    let include_notification = should_include_fcm_notification(payload, platform);
    let collapse_id =
        truncate_collapse_id(push_collapse_identity(payload, include_notification));
    message.insert("token".into(), serde_json::Value::String(token.to_string()));
    if include_notification {
        message.insert(
            "notification".into(),
            serde_json::json!({
                "title": payload.notification_title.clone(),
                "body": payload.notification_body.clone()
            }),
        );
    }
    message.insert(
        "data".into(),
        serde_json::Value::Object(payload.data.clone()),
    );

    match platform {
        "android" => {
            let mut android = serde_json::Map::new();
            android.insert(
                "priority".into(),
                serde_json::Value::String("high".to_string()),
            );
            android.insert(
                "collapse_key".into(),
                serde_json::Value::String(collapse_id.clone()),
            );
            android.insert(
                "ttl".into(),
                serde_json::Value::String(fcm_android_ttl_for_payload(payload).to_string()),
            );
            if include_notification {
                android.insert(
                    "notification".into(),
                    serde_json::json!({
                        "sound": "default",
                        "tag": payload.notification_tag.clone(),
                        "channel_id": "secretly_messages_v2"
                    }),
                );
            }
            message.insert("android".into(), serde_json::Value::Object(android));
        }
        "ios" => {
            let mut aps = serde_json::Map::new();
            aps.insert(
                "content-available".into(),
                serde_json::Value::Number(1.into()),
            );
            if include_notification {
                // NSE GROUNDWORK (2026-07-16, delivery-wake audit P1): let a
                // Notification Service Extension intercept alert pushes (it
                // will pre-fetch/stage the mailbox and fix the badge while the
                // app is suspended). Harmless no-op until the client ships an
                // NSE target — iOS displays the banner unchanged when no
                // extension is registered.
                aps.insert(
                    "mutable-content".into(),
                    serde_json::Value::Number(1.into()),
                );
                aps.insert(
                    "sound".into(),
                    serde_json::Value::String("default".to_string()),
                );
                aps.insert(
                    "thread-id".into(),
                    serde_json::Value::String(payload.notification_tag.clone()),
                );
                if let Some(category) = ios_message_notification_category_id(payload) {
                    aps.insert(
                        "category".into(),
                        serde_json::Value::String(category.to_string()),
                    );
                }
            }
            // App-icon unread badge (set even on silent wakes so the count keeps
            // updating while the app is killed). Omitted when None.
            if let Some(badge) = payload.badge {
                aps.insert("badge".into(), serde_json::Value::Number(badge.into()));
            }
            message.insert(
                "apns".into(),
                serde_json::json!({
                    "headers": {
                        "apns-priority": if include_notification { "10" } else { "5" },
                        "apns-push-type": if include_notification { "alert" } else { "background" },
                        "apns-collapse-id": collapse_id.clone()
                    },
                    "payload": {
                        "aps": serde_json::Value::Object(aps)
                    }
                }),
            );
        }
        _ => {}
    }

    serde_json::json!({ "message": serde_json::Value::Object(message) })
}

fn build_fcm_legacy_payload(
    token: &str,
    payload: &PushWakePayload,
    platform: &str,
) -> serde_json::Value {
    let mut root = serde_json::Map::new();
    let include_notification = should_include_fcm_notification(payload, platform);
    root.insert("to".into(), serde_json::Value::String(token.to_string()));
    root.insert(
        "priority".into(),
        serde_json::Value::String("high".to_string()),
    );
    // 🔴 Звонкам — свой ключ (иначе на старом пути они продолжали бы затирать
    // друг друга), всему остальному — ровно прежний per-device ключ. Правка про
    // звонки не меняет здесь правил для сообщений. См. push_call_collapse_key.
    root.insert(
        "collapse_key".into(),
        serde_json::Value::String(truncate_collapse_id(
            push_call_collapse_key(payload).unwrap_or_else(|| payload.collapse_key.clone()),
        )),
    );
    if include_notification {
        let mut notification = serde_json::Map::new();
        notification.insert(
            "title".into(),
            serde_json::Value::String(payload.notification_title.clone()),
        );
        notification.insert(
            "body".into(),
            serde_json::Value::String(payload.notification_body.clone()),
        );
        notification.insert(
            "sound".into(),
            serde_json::Value::String("default".to_string()),
        );
        notification.insert(
            "tag".into(),
            serde_json::Value::String(payload.notification_tag.clone()),
        );
        if platform == "ios" {
            if let Some(category) = ios_message_notification_category_id(payload) {
                notification.insert(
                    "click_action".into(),
                    serde_json::Value::String(category.to_string()),
                );
            }
        }
        root.insert(
            "notification".into(),
            serde_json::Value::Object(notification),
        );
    }
    root.insert(
        "data".into(),
        serde_json::Value::Object(payload.data.clone()),
    );

    if platform == "ios" {
        root.insert("content_available".into(), serde_json::Value::Bool(true));
        root.insert("mutable_content".into(), serde_json::Value::Bool(true));
    }

    serde_json::Value::Object(root)
}

fn build_apns_voip_payload(payload: &PushWakePayload) -> serde_json::Value {
    let mut root = payload.data.clone();
    root.insert("aps".into(), serde_json::json!({}));
    if let Some(raw) = root.get("is_video").and_then(|value| value.as_str()) {
        root.insert(
            "is_video".into(),
            serde_json::Value::Bool(raw.eq_ignore_ascii_case("true") || raw == "1"),
        );
    }
    serde_json::Value::Object(root)
}

#[derive(Debug)]
struct ApnsVoipSendResult {
    delivered: bool,
    bad_device_token: bool,
}

fn apns_error_reason(body: &str) -> Option<String> {
    serde_json::from_str::<serde_json::Value>(body)
        .ok()
        .and_then(|value| {
            value
                .get("reason")
                .and_then(|reason| reason.as_str())
                .map(str::to_string)
        })
}

fn alternate_apns_voip_config(cfg: &ApnsVoipConfig) -> Option<ApnsVoipConfig> {
    let mut fallback = cfg.clone();
    if matches!(cfg.environment.as_str(), "prod" | "production") {
        fallback.environment = "development".to_string();
        fallback.endpoint_base = "https://api.sandbox.push.apple.com".to_string();
        Some(fallback)
    } else if cfg.environment == "development" || cfg.environment == "sandbox" {
        fallback.environment = "production".to_string();
        fallback.endpoint_base = "https://api.push.apple.com".to_string();
        Some(fallback)
    } else {
        None
    }
}

async fn send_apns_voip_push_once(
    state: &AppState,
    cfg: &ApnsVoipConfig,
    to_device_id: &str,
    token: &str,
    payload: &PushWakePayload,
) -> ApnsVoipSendResult {
    let device_ref = log_fingerprint(to_device_id);
    let Some(jwt) = get_apns_provider_jwt(state, cfg).await else {
        tracing::warn!(device_ref=%device_ref, environment=%cfg.environment, topic=%cfg.topic, "failed to build apns voip jwt");
        return ApnsVoipSendResult {
            delivered: false,
            bad_device_token: false,
        };
    };
    let url = format!("{}/3/device/{}", cfg.endpoint_base, token.trim());
    let expiration = ((now_ms() / 1000) + 45).to_string();
    let body = build_apns_voip_payload(payload);

    let resp = state
        .http
        .post(&url)
        .header("authorization", format!("bearer {jwt}"))
        .header("apns-topic", cfg.topic.as_str())
        .header("apns-push-type", "voip")
        .header("apns-priority", "10")
        .header("apns-expiration", expiration)
        .header("apns-collapse-id", payload.notification_tag.as_str())
        .json(&body)
        .send()
        .await;

    match resp {
        Ok(r) if r.status().is_success() => {
            tracing::info!(device_ref=%device_ref, environment=%cfg.environment, topic=%cfg.topic, "apns voip send success");
            // Sprint 2 R3/R7: record successful APNs delivery as a liveness signal.
            if let Err(e) = state.store.record_push_delivered(to_device_id, now_ms()).await {
                tracing::debug!(
                    device_ref=%device_ref,
                    error=%e,
                    "device_activity push-delivered record failed (non-fatal)"
                );
            }
            ApnsVoipSendResult {
                delivered: true,
                bad_device_token: false,
            }
        }
        Ok(r) => {
            let status = r.status();
            let body = r.text().await.unwrap_or_default();
            let body_summary = log_body_summary(&body);
            let reason = apns_error_reason(&body).unwrap_or_default();
            let bad_device_token = reason == "BadDeviceToken";
            tracing::warn!(
                status=%status,
                body_summary=%body_summary,
                apns_reason=%reason,
                device_ref=%device_ref,
                environment=%cfg.environment,
                topic=%cfg.topic,
                "apns voip send returned non-success"
            );
            ApnsVoipSendResult {
                delivered: false,
                bad_device_token,
            }
        }
        Err(error) => {
            tracing::warn!(device_ref=%device_ref, environment=%cfg.environment, topic=%cfg.topic, error=%error, "apns voip send failed");
            ApnsVoipSendResult {
                delivered: false,
                bad_device_token: false,
            }
        }
    }
}

async fn send_apns_voip_push(
    state: &AppState,
    cfg: &ApnsVoipConfig,
    to_device_id: &str,
    token: &str,
    payload: &PushWakePayload,
) -> bool {
    let primary = send_apns_voip_push_once(state, cfg, to_device_id, token, payload).await;
    if primary.delivered {
        return true;
    }
    let device_ref = log_fingerprint(to_device_id);
    if !primary.bad_device_token {
        return false;
    }
    if !cfg.allow_environment_fallback {
        // Primary returned BadDeviceToken and we have no environment to fall back to.
        // The token is dead (e.g. app uninstalled / restored from backup) — invalidate
        // so we stop sending pushes that can never be delivered. See
        // docs/MESSAGE_DELIVERY_AUDIT_2026-05-28.md §10.1 R1.
        invalidate_dead_push_token(
            state,
            to_device_id,
            "ios_voip",
            token,
            "apns_bad_device_token",
        )
        .await;
        return false;
    }

    let Some(fallback) = alternate_apns_voip_config(cfg) else {
        invalidate_dead_push_token(
            state,
            to_device_id,
            "ios_voip",
            token,
            "apns_bad_device_token",
        )
        .await;
        return false;
    };
    tracing::warn!(
        device_ref=%device_ref,
        from_environment=%cfg.environment,
        to_environment=%fallback.environment,
        topic=%cfg.topic,
        "retrying apns voip call wake in alternate environment after BadDeviceToken"
    );
    let secondary = send_apns_voip_push_once(state, &fallback, to_device_id, token, payload).await;
    if secondary.delivered {
        return true;
    }
    if secondary.bad_device_token {
        // Both APNs environments reject the token — it's permanently dead.
        invalidate_dead_push_token(
            state,
            to_device_id,
            "ios_voip",
            token,
            "apns_bad_device_token_both_envs",
        )
        .await;
    }
    false
}

/// Parse FCM HTTP v1 error body and return the canonical FCM `errorCode`
/// string from `error.details[].errorCode` if present (e.g. `UNREGISTERED`,
/// `INVALID_ARGUMENT`, `SENDER_ID_MISMATCH`, `QUOTA_EXCEEDED`).
///
/// Falls back to `error.status` when the typed details are absent.
fn fcm_v1_error_code(body: &str) -> Option<String> {
    let value: serde_json::Value = serde_json::from_str(body).ok()?;
    let error = value.get("error")?;
    if let Some(details) = error.get("details").and_then(|d| d.as_array()) {
        for detail in details {
            if let Some(code) = detail.get("errorCode").and_then(|c| c.as_str()) {
                return Some(code.to_string());
            }
        }
    }
    error
        .get("status")
        .and_then(|s| s.as_str())
        .map(str::to_string)
}

/// Returns `true` if the given FCM v1 error code (or `status`) indicates the
/// recipient token is permanently dead and should be removed from our store.
fn fcm_v1_token_is_dead(code: &str) -> bool {
    matches!(
        code,
        // Canonical FCM HTTP v1 codes per https://firebase.google.com/docs/cloud-messaging/migrate-v1
        "UNREGISTERED"
            | "INVALID_ARGUMENT"
            // Status-level fallbacks for legacy / abbreviated bodies.
            | "NOT_FOUND"
            | "PERMISSION_DENIED"
    )
}

/// Delete a `(device_id, platform)` push token row only if the stored token
/// is still equal to the one that just failed. Logs the result.
///
/// Used after APNs / FCM return an unregistered-token error. We intentionally
/// invalidate only the token we tried — if the client rotated its token in
/// the meantime and uploaded a new one, the new token survives (TOCTOU-safe).
async fn invalidate_dead_push_token(
    state: &AppState,
    device_id: &str,
    platform: &str,
    token: &str,
    reason: &str,
) {
    let device_ref = log_fingerprint(device_id);
    match state
        .store
        .delete_push_token_if_token_matches(device_id, platform, token)
        .await
    {
        Ok(true) => {
            tracing::warn!(
                device_ref=%device_ref,
                platform=%platform,
                reason=%reason,
                "push_token_invalidated: removed dead token"
            );
        }
        Ok(false) => {
            // Token was already rotated/removed by the client — nothing to do.
            tracing::info!(
                device_ref=%device_ref,
                platform=%platform,
                reason=%reason,
                "push_token_invalidation_skipped: token already replaced"
            );
        }
        Err(e) => {
            tracing::warn!(
                device_ref=%device_ref,
                platform=%platform,
                reason=%reason,
                error=%e,
                "push_token_invalidation_failed"
            );
        }
    }
}

async fn send_fcm_v1_data_push(
    state: &AppState,
    cfg: &FcmV1Config,
    to_device_id: &str,
    token: &str,
    payload: &PushWakePayload,
    platform: &str,
) -> bool {
    let device_ref = log_fingerprint(to_device_id);
    let Some(access_token) = get_fcm_v1_access_token(state, cfg).await else {
        tracing::warn!(project_id=%cfg.project_id, device_ref=%device_ref, "fcm v1 access token unavailable");
        return false;
    };

    let payload = build_fcm_v1_message_payload(token, payload, platform);

    let resp = state
        .http
        .post(&cfg.send_url)
        .header("Authorization", format!("Bearer {access_token}"))
        .header("Content-Type", "application/json; UTF-8")
        .json(&payload)
        .send()
        .await;

    match resp {
        Ok(r) if r.status().is_success() => {
            tracing::info!(project_id=%cfg.project_id, device_ref=%device_ref, "fcm v1 send success");
            // Sprint 2 R3/R7: record successful FCM v1 delivery.
            if let Err(e) = state.store.record_push_delivered(to_device_id, now_ms()).await {
                tracing::debug!(
                    device_ref=%device_ref,
                    error=%e,
                    "device_activity push-delivered record failed (non-fatal)"
                );
            }
            true
        }
        Ok(r) => {
            let status = r.status();
            let body = r.text().await.unwrap_or_default();
            let body_summary = log_body_summary(&body);
            let fcm_code = fcm_v1_error_code(&body).unwrap_or_default();
            tracing::warn!(
                status=%status,
                body_summary=%body_summary,
                fcm_code=%fcm_code,
                project_id=%cfg.project_id,
                device_ref=%device_ref,
                "fcm v1 send returned non-success"
            );
            // Per FCM HTTP v1 spec, UNREGISTERED / INVALID_ARGUMENT (and the
            // status-level fallbacks NOT_FOUND / PERMISSION_DENIED) indicate a
            // permanently dead recipient token (app uninstalled, token rotated,
            // or sender/project mismatch). Stop sending to it — see
            // docs/MESSAGE_DELIVERY_AUDIT_2026-05-28.md §10.1 R1.
            if !fcm_code.is_empty() && fcm_v1_token_is_dead(&fcm_code) {
                invalidate_dead_push_token(
                    state,
                    to_device_id,
                    platform,
                    token,
                    &format!("fcm_v1_{}", fcm_code.to_ascii_lowercase()),
                )
                .await;
            }
            false
        }
        Err(e) => {
            tracing::warn!(
                error=%e,
                project_id=%cfg.project_id,
                device_ref=%device_ref,
                "fcm v1 send failed"
            );
            false
        }
    }
}

async fn send_fcm_push_for_token(
    state: &AppState,
    to_device_id: &str,
    token_row: &PushTokenRow,
    push_payload: &PushWakePayload,
) -> bool {
    let device_ref = log_fingerprint(to_device_id);
    if !is_supported_fcm_platform(&token_row.platform) {
        tracing::info!(device_ref=%device_ref, platform=%token_row.platform, "unsupported fcm platform; skipping fcm wake");
        return false;
    }

    if let Some(cfg) = state.fcm_v1.as_ref() {
        tracing::info!(device_ref=%device_ref, platform=%token_row.platform, project_id=%cfg.project_id, "attempting fcm v1 wake");
        if send_fcm_v1_data_push(
            state,
            cfg,
            to_device_id,
            &token_row.token,
            push_payload,
            &token_row.platform,
        )
        .await
        {
            tracing::info!(device_ref=%device_ref, platform=%token_row.platform, "fcm v1 wake sent");
            return true;
        }
        tracing::warn!(device_ref=%device_ref, platform=%token_row.platform, "fcm v1 wake failed; falling back to legacy if configured");
    } else {
        tracing::warn!(device_ref=%device_ref, platform=%token_row.platform, "fcm v1 not configured; falling back to legacy if configured");
    }

    let server_key = state.fcm_legacy_server_key.trim().to_string();
    if server_key.is_empty() {
        tracing::warn!(device_ref=%device_ref, "fcm legacy server key missing; push wake not sent");
        return false;
    }

    let payload = build_fcm_legacy_payload(&token_row.token, push_payload, &token_row.platform);

    let resp = state
        .http
        .post("https://fcm.googleapis.com/fcm/send")
        .header("Authorization", format!("key={server_key}"))
        .header("Content-Type", "application/json")
        .json(&payload)
        .send()
        .await;

    match resp {
        Ok(r) if r.status().is_success() => {
            let status = r.status();
            let body = r.text().await.unwrap_or_default();
            // Legacy FCM returns 200 even for individual-message errors.
            // Body contains {"failure":1, "results":[{"error":"NotRegistered"}]}.
            // We invalidate the token if any result reports a dead-token error.
            let legacy_err = fcm_legacy_dead_token_error(&body);
            if let Some(err_code) = legacy_err {
                tracing::warn!(
                    device_ref=%device_ref,
                    platform=%token_row.platform,
                    legacy_err=%err_code,
                    "fcm legacy wake reports dead recipient token"
                );
                invalidate_dead_push_token(
                    state,
                    to_device_id,
                    &token_row.platform,
                    &token_row.token,
                    &format!("fcm_legacy_{}", err_code.to_ascii_lowercase()),
                )
                .await;
                return false;
            }
            tracing::info!(status=%status, device_ref=%device_ref, platform=%token_row.platform, "fcm legacy wake sent");
            // Sprint 2 R3/R7: record successful legacy FCM delivery.
            if let Err(e) = state.store.record_push_delivered(to_device_id, now_ms()).await {
                tracing::debug!(
                    device_ref=%device_ref,
                    error=%e,
                    "device_activity push-delivered record failed (non-fatal)"
                );
            }
            true
        }
        Ok(r) => {
            tracing::warn!(
                status=%r.status(),
                device_ref=%device_ref,
                platform=%token_row.platform,
                "fcm send returned non-success"
            );
            false
        }
        Err(e) => {
            tracing::warn!(device_ref=%device_ref, platform=%token_row.platform, error=%e, "fcm send failed");
            false
        }
    }
}

/// Inspect a legacy FCM HTTP/HTTPS response body and return the FIRST
/// dead-token error code if any (`NotRegistered`, `InvalidRegistration`,
/// `MismatchSenderId`). Legacy FCM batches results in `results[]`; we only
/// send one token per request so we inspect index 0.
fn fcm_legacy_dead_token_error(body: &str) -> Option<String> {
    let value: serde_json::Value = serde_json::from_str(body).ok()?;
    let results = value.get("results")?.as_array()?;
    for entry in results {
        if let Some(err) = entry.get("error").and_then(|v| v.as_str()) {
            if matches!(
                err,
                "NotRegistered" | "InvalidRegistration" | "MismatchSenderId"
            ) {
                return Some(err.to_string());
            }
        }
    }
    None
}

async fn maybe_send_fcm_data_push(
    state: AppState,
    to_device_id: String,
    sender_device_id: Option<String>,
    msg_id: Option<String>,
    transport_meta_json: Option<String>,
    // True only for a bare "drain your mailbox" wake that announces nothing.
    force_silent: bool,
    // Когда конверт попал в ящик. `None` — схлопывание не применяется
    // (лестница офлайн-пробуждений и прочие вызовы без конкретного конверта).
    enqueued_at_ms: Option<i64>,
) {
    let device_ref = log_fingerprint(&to_device_id);
    let sender_device_ref = log_optional_fingerprint(sender_device_id.as_deref());
    let msg_ref = log_optional_fingerprint(msg_id.as_deref());
    tracing::info!(device_ref=%device_ref, sender_device_ref=?sender_device_ref, msg_ref=?msg_ref, "push wake attempt start");

    // 🔴 NEVER wake a SUPERSEDED device (2026-07-30). `superseded_at_ms > 0`
    // means this device_id was replaced by a newer one on the SAME physical
    // phone, proven by a push-token takeover — the store's own words: "such a
    // device can never receive again", which is why `GET /v1/active_devices`
    // already drops it from senders' fanout.
    //
    // Its mailbox is therefore undeliverable BY DEFINITION, yet the wake ladder
    // kept pushing at it and its dead rows kept feeding `aps.badge`. Measured in
    // production on 2026-07-30: ONE superseded device held 511 of the 1007
    // pending rows on the whole relay — half the backlog — stranded 5.6 days,
    // never once pumped, still holding a live iOS token. That is the engine
    // behind "a notification every half hour" and "51 unread and I have read
    // everything".
    //
    // Guarded here rather than only in the sweep queries so no caller — now or
    // later — can wake a device the system has already declared dead.
    match state.store.device_activity_get(&to_device_id).await {
        Ok(Some(activity)) if activity.superseded_at_ms > 0 => {
            tracing::info!(
                device_ref=%device_ref,
                "push wake skipped: device superseded by a newer device_id on the same phone"
            );
            return;
        }
        Ok(_) => {}
        Err(e) => {
            // Unknown state → behave as before rather than silently dropping a
            // real wake.
            tracing::warn!(device_ref=%device_ref, error=%e, "superseded check failed; proceeding with wake");
        }
    }

    let token_rows = match state.store.list_push_tokens(&to_device_id).await {
        Ok(v) => v,
        Err(e) => {
            tracing::warn!(device_ref=%device_ref, error=%e, "push token lookup failed");
            return;
        }
    };

    if token_rows.is_empty() {
        tracing::info!(device_ref=%device_ref, "no push token registered; skipping fcm wake");
        return;
    }

    let regular_token = token_rows
        .iter()
        .find(|row| is_supported_fcm_platform(&row.platform))
        .cloned();
    let voip_token = token_rows
        .iter()
        .find(|row| row.platform == "ios_voip")
        .cloned();
    let policy_json = regular_token
        .as_ref()
        .and_then(|row| row.policy_json.as_deref())
        .or_else(|| {
            voip_token
                .as_ref()
                .and_then(|row| row.policy_json.as_deref())
        });

    let push_payload = build_push_wake_payload(
        &state,
        &to_device_id,
        sender_device_id.as_deref(),
        msg_id.as_deref(),
        transport_meta_json.as_deref(),
        policy_json,
        force_silent,
    )
    .await;

    let is_call_invite = push_payload_wake_kind(&push_payload) == "call_invite_v1";
    let bypass_interval_throttle = push_wake_bypasses_interval_throttle(&push_payload);
    tracing::info!(device_ref=%device_ref, wake_kind=%push_payload_wake_kind(&push_payload), "push wake payload built");

    const PUSH_WAKE_MIN_INTERVAL_MS: i64 = 3500;
    let now = now_ms();
    if !bypass_interval_throttle {
        if let Some(prev) = state
            .push_wake_last_ms
            .get(&to_device_id)
            .map(|v| *v.value())
        {
            if now - prev < PUSH_WAKE_MIN_INTERVAL_MS {
                tracing::info!(
                    device_ref=%device_ref,
                    wake_kind=%push_payload_wake_kind(&push_payload),
                    since_last_ms=(now - prev),
                    "push wake throttled"
                );
                return;
            }
        }
        state.push_wake_last_ms.insert(to_device_id.clone(), now);
    }

    if let Some(mid) = msg_id.as_deref() {
        let mid_ref = log_fingerprint(mid);
        match state
            .store
            .try_mark_push_wake_sent(&to_device_id, mid, now)
            .await
        {
            Ok(true) => {}
            Ok(false) => {
                tracing::info!(device_ref=%device_ref, msg_ref=%mid_ref, "push wake skipped: already sent for msg_id");
                return;
            }
            Err(e) => {
                tracing::warn!(device_ref=%device_ref, msg_ref=%mid_ref, error=%e, "push wake dedup check failed");
            }
        }
    }

    // Sprint 2 R3/R7: we have at least one push token and a wake payload,
    // so we are about to attempt a push on the wire. Record the attempt
    // BEFORE any of the platform-specific branches below — this way the
    // metric reflects every wake we tried, not just the ones that succeeded.
    if let Err(e) = state.store.record_push_attempted(&to_device_id, now).await {
        tracing::debug!(
            device_ref=%device_ref,
            error=%e,
            "device_activity push-attempt record failed (non-fatal)"
        );
    }

    if is_call_invite {
        let mut voip_sent = false;
        if let Some(voip_token) = voip_token.as_ref() {
            if let Some(apns) = state.apns_voip.as_ref() {
                tracing::info!(device_ref=%device_ref, platform=%voip_token.platform, "attempting apns voip call wake");
                voip_sent = send_apns_voip_push(
                    &state,
                    apns,
                    &to_device_id,
                    &voip_token.token,
                    &push_payload,
                )
                .await;
            } else {
                tracing::warn!(device_ref=%device_ref, "ios_voip token registered but apns voip provider is not configured");
            }
        }

        if let Some(regular_token) = regular_token.as_ref() {
            if regular_token.platform == "android" || !voip_sent {
                let _ =
                    send_fcm_push_for_token(&state, &to_device_id, regular_token, &push_payload)
                        .await;
            } else {
                tracing::info!(device_ref=%device_ref, platform=%regular_token.platform, "skipping normal fcm call wake because apns voip wake was sent");
            }
        } else if !voip_sent {
            tracing::warn!(device_ref=%device_ref, "call invite push had no usable regular or voip token");
        }
        return;
    }

    let Some(regular_token) = regular_token.as_ref() else {
        tracing::info!(device_ref=%device_ref, "no regular fcm push token registered; skipping non-call wake");
        return;
    };

    // Несёт ли это пробуждение баннер. Решается платформой получателя, поэтому
    // считается здесь, а не раньше.
    let announces = should_include_fcm_notification(&push_payload, &regular_token.platform);

    // Э-1: схлопывание пачки по СОСТОЯНИЮ, а не по времени.
    //
    // 🔴 ПОЧЕМУ НЕ ОКНОМ. Ограничитель в 3,5 с не отличает три конверта ОДНОГО
    // действия от второго сообщения, написанного человеком через две секунды —
    // и именно поэтому `chat_message_v1` когда-то внесли в исключения
    // (56a55689, 14.06.2026), а вместе с этим открыли дорогу пачке.
    //
    // Правило точнее: пуш означает «приди забери ящик», и один заход вычерпывает
    // ВСЁ. Значит пуш не нужен, если устройству уже ушёл пуш ПОЗЖЕ момента, когда
    // наш конверт попал в ящик. Три конверта одного действия схлопнутся; сообщение,
    // положенное после пуша, разбудит телефон как раньше — регрессия из 56a55689
    // закрыта по построению, а не окном.
    // 🔴 ЗАЯВКА ДЕЛАЕТСЯ ДО ОТПРАВКИ И АТОМАРНО.
    //
    // Первая редакция этой правки проверяла отметку перед отправкой, а ставила
    // ПОСЛЕ — и не сработала на проде (11.08, устройство c3410842): три задачи
    // одного действия идут ОДНОВРЕМЕННО, все три проверили отметку в пределах
    // трёх миллисекунд, а первая успела отметиться только через 60–110 мс, уже
    // после отправки. Все три увидели пустоту и ушли на телефон.
    //
    // Поэтому под замком записи делаются ОБА действия сразу: проверка и
    // выставление отметки. Кто первым занял слот — тот и шлёт.
    let claim_at = now_ms();
    let mut claimed_from: Option<WakeCoalesceMark> = None;
    if let Some(enqueued_at) = enqueued_at_ms
        && push_wake_is_coalescable(&push_payload)
    {
        let mut skip = false;
        {
            let mut mark = state.wake_coalesce.entry(to_device_id.clone()).or_default();
            // Э-2: тихое подавляется любым пробуждением, баннерное — только
            // баннерным. Иначе тихое лечение сессии, идущее в пачке ПЕРВЫМ,
            // съело бы единственное уведомление человека.
            let covered = if announces {
                mark.last_announced_at_ms >= enqueued_at
            } else {
                mark.last_wake_at_ms >= enqueued_at
            };
            if covered {
                skip = true;
            } else {
                claimed_from = Some(*mark);
                mark.last_wake_at_ms = mark.last_wake_at_ms.max(claim_at);
                if announces {
                    mark.last_announced_at_ms = mark.last_announced_at_ms.max(claim_at);
                }
            }
        }
        if skip {
            tracing::info!(
                device_ref=%device_ref,
                msg_ref=?msg_ref,
                announces=%announces,
                "push wake coalesced; mailbox already covered by a newer wake"
            );
            return;
        }
    }

    let sent = send_fcm_push_for_token(&state, &to_device_id, regular_token, &push_payload).await;

    if sent {
        // Пробуждения, которые не схлопываются (звонки, лечение сессии), тоже
        // отмечаются: тогда ТИХОЕ чат-пробуждение может схлопнуться о них, а
        // баннерное — нет, потому что у него своё поле.
        let stamp = now_ms();
        {
            let mut mark = state.wake_coalesce.entry(to_device_id.clone()).or_default();
            mark.last_wake_at_ms = mark.last_wake_at_ms.max(stamp);
            if announces {
                mark.last_announced_at_ms = mark.last_announced_at_ms.max(stamp);
            }
        }
        // Чистка, чтобы карта не росла бесконечно. Держатель записи выше уже
        // отпущен — иначе `retain` встал бы на собственном замке.
        if state.wake_coalesce.len() > 4096 {
            let cutoff = stamp - 10 * 60 * 1000;
            state
                .wake_coalesce
                .retain(|_, m| m.last_wake_at_ms >= cutoff);
        }
    } else if let Some(prev) = claimed_from {
        // 🔴 ОТКАТ ЗАЯВКИ. Неудачная отправка не имеет права подавлять следующую
        // попытку — иначе один сбой сети оставляет сообщение до лестницы
        // офлайн-пробуждений, у которой первый шаг десять минут (К-2 из ТЗ).
        //
        // Откатываем ТОЛЬКО свою отметку: если за время отправки её обновил
        // кто-то другой, значит слот занят по-настоящему и трогать его нельзя.
        let mut mark = state.wake_coalesce.entry(to_device_id.clone()).or_default();
        if mark.last_wake_at_ms == claim_at {
            mark.last_wake_at_ms = prev.last_wake_at_ms;
        }
        if announces && mark.last_announced_at_ms == claim_at {
            mark.last_announced_at_ms = prev.last_announced_at_ms;
        }
    }
}

async fn schedule_fcm_if_still_pending(
    state: AppState,
    to_device_id: String,
    msg_id: String,
    sender_device_id: Option<String>,
    transport_meta_json: Option<String>,
    // Момент постановки конверта в ящик. Снимается на месте запуска задачи —
    // именно там, где конверт и кладётся, поэтому отдельного столбца в базе не
    // нужно.
    enqueued_at_ms: i64,
    // Был ли у получателя живой сокет В МОМЕНТ ПОСТАНОВКИ конверта. Снимается
    // синхронно на месте `spawn`, не здесь: к началу этой задачи картина
    // подключений уже другая.
    had_live_socket: bool,
) {
    // Пауза перед запасным push существует ради одного случая: конверт ушёл в
    // живой сокет, и надо дать получателю время подтвердить доставку, чтобы не
    // будить телефон зря. Если сокета не было, ждать нечего — доставки по WS не
    // будет по построению, конверт пролежит в ящике до следующего подключения,
    // и эти две секунды целиком уходят в задержку «написал → баннер».
    //
    // Гонка «клиент подключился в эти две секунды» закрыта тем же, чем и
    // раньше: `has_pending_msg` ниже отсекает уже забранный конверт, а
    // `try_mark_push_wake_sent` не даёт послать второй push по тому же msg_id.
    // Худший исход — один лишний тихий data-push устройству, которое как раз
    // подключилось; шифротекста правка не касается вовсе.
    if had_live_socket {
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
    let device_ref = log_fingerprint(&to_device_id);
    let msg_ref = log_fingerprint(&msg_id);
    let still_pending = match state
        .store
        .has_pending_msg(&to_device_id, &msg_id, now_ms())
        .await
    {
        Ok(v) => v,
        Err(e) => {
            tracing::warn!(device_ref=%device_ref, msg_ref=%msg_ref, error=%e, "pending check failed before fallback push");
            false
        }
    };

    if !still_pending {
        return;
    }

    // For live call media signals, verify the call session is still alive before
    // sending a wake push. A caller may have hung up in the 2-second delay
    // window, leaving the session ended while the pending message survives.
    if let Ok(Some(call_signal)) = parse_call_signal_transport_meta(transport_meta_json.as_deref())
    {
        if matches!(
            call_signal.action.as_str(),
            "invite" | "offer" | "answer" | "ice" | "need_offer"
        ) {
            let session_result = state
                .store
                .get_call_session(
                    &to_device_id,
                    &call_signal.call_id,
                    &call_signal.call_attempt_id,
                    now_ms(),
                )
                .await;
            match session_result {
                Ok(Some(session)) if session.ended_at_ms.is_some() => {
                    tracing::info!(
                        device_ref=%device_ref,
                        msg_ref=%msg_ref,
                        action=%call_signal.action,
                        "suppressing call wake push: call session already ended"
                    );
                    return;
                }
                Ok(None) => {
                    // Session missing — call may have been cancelled before the
                    // session record was written, or already expired. Suppress push.
                    tracing::info!(
                        device_ref=%device_ref,
                        msg_ref=%msg_ref,
                        action=%call_signal.action,
                        "suppressing call wake push: call session not found"
                    );
                    return;
                }
                Err(e) => {
                    // Store error — allow push to proceed; client will validate.
                    tracing::warn!(
                        device_ref=%device_ref,
                        msg_ref=%msg_ref,
                        error=%e,
                        "call session check failed before invite push; proceeding"
                    );
                }
                Ok(Some(_)) => {
                    // Session alive — proceed with push.
                }
            }
        }
    }

    tracing::info!(device_ref=%device_ref, msg_ref=%msg_ref, "message still pending; fallback push trigger");
    maybe_send_fcm_data_push(
        state,
        to_device_id,
        sender_device_id,
        Some(msg_id),
        transport_meta_json,
        false,
        Some(enqueued_at_ms),
    )
    .await;
}

async fn http_push_token_set(
    Path(device_id): Path<String>,
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpPushTokenSetReq>,
) -> Result<Json<HttpPushTokenSetResp>, (StatusCode, String)> {
    if !is_valid_id(&device_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad device_id".into()));
    }

    let token = req.token.trim();
    let platform = normalize_push_platform(req.platform.as_deref());
    let enabled = req.enabled.unwrap_or(true);
    let normalized_policy_json = normalize_push_policy_json(req.policy_b64.as_deref())?;

    if !is_supported_push_registration_platform(&platform) {
        return Err((StatusCode::BAD_REQUEST, "unsupported push platform".into()));
    }

    if enabled {
        if token.is_empty() || token.len() > 4096 {
            return Err((StatusCode::BAD_REQUEST, "bad token".into()));
        }
    }

    let device_ref = log_fingerprint(&device_id);

    tracing::info!(
        device_ref=%device_ref,
        enabled,
        platform=%platform,
        token_len=token.len(),
        "push token set request"
    );

    if require_auth_enabled() {
        let (_hdr_device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_push_token_set_auth_message(
            &device_id,
            token,
            &platform,
            enabled,
            req.policy_b64.as_deref(),
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;
    }

    if enabled {
        state
            .store
            .upsert_push_token(
                &device_id,
                token,
                &platform,
                normalized_policy_json.as_deref(),
                now_ms(),
            )
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
        tracing::info!(device_ref=%device_ref, platform=%platform, "push token upserted");
    } else {
        state
            .store
            .delete_push_token_for_platform(&device_id, &platform)
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
        tracing::info!(device_ref=%device_ref, platform=%platform, "push token removed");
    }

    Ok(Json(HttpPushTokenSetResp { ok: true }))
}

async fn http_profile_delete(
    headers: HeaderMap,
    State(state): State<AppState>,
    Json(req): Json<HttpProfileDeleteReq>,
) -> Result<Json<HttpProfileDeleteResp>, (StatusCode, String)> {
    let profile_id = req.profile_id.trim().to_string();
    if !is_valid_id(&profile_id, 128) {
        return Err((StatusCode::BAD_REQUEST, "bad profile_id".into()));
    }

    let signed_device_ids = normalize_profile_delete_device_ids(req.device_ids)?;
    let signed_device_ids_csv = profile_delete_device_ids_csv(&signed_device_ids);
    let mut cleanup_device_ids = signed_device_ids.clone();

    if require_auth_enabled() {
        let (device_id, ts_ms, nonce_b64, _sig) = http_auth_headers(&headers)?;
        let msg = http_profile_delete_auth_message(
            &device_id,
            &profile_id,
            &signed_device_ids_csv,
            ts_ms,
            &nonce_b64,
        );
        let _ = verify_http_auth(&state, &headers, Some(&device_id), msg).await?;

        let requester_profile_id = fetch_profile_id(&state, &device_id)
            .await
            .ok_or((StatusCode::UNAUTHORIZED, "unknown device".into()))?;
        if requester_profile_id != profile_id {
            return Err((StatusCode::FORBIDDEN, "forbidden".into()));
        }
        if !cleanup_device_ids.iter().any(|id| id == &device_id) {
            cleanup_device_ids.push(device_id);
        }
    } else if let Some(device_id) = header_str(&headers, "x-secretly-device-id") {
        let device_id = device_id.trim().to_string();
        if is_valid_id(&device_id, 128) && !cleanup_device_ids.iter().any(|id| id == &device_id) {
            cleanup_device_ids.push(device_id);
        }
    }

    cleanup_device_ids.sort();
    cleanup_device_ids.dedup();

    if require_auth_enabled() {
        for device_id in &cleanup_device_ids {
            let Some(device_profile_id) = fetch_profile_id(&state, device_id).await else {
                return Err((StatusCode::BAD_REQUEST, "unknown device_id".into()));
            };
            if device_profile_id != profile_id {
                return Err((
                    StatusCode::FORBIDDEN,
                    "device_id does not belong to profile".into(),
                ));
            }
        }
    }

    let result = state
        .store
        .as_ref()
        .delete_profile_data(&profile_id, &cleanup_device_ids)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    let deleted_blob_count = result.deleted_blob_paths.len();
    for rel_path in result.deleted_blob_paths {
        let _ = tokio::fs::remove_file(state.blobs_dir.join(rel_path)).await;
    }

    for device_id in &cleanup_device_ids {
        state.identity_cache.remove(device_id);
        state.profile_cache.remove(device_id);
        state.push_wake_last_ms.remove(device_id);
    }
    let cached_profile_devices = state
        .profile_cache
        .iter()
        .filter(|entry| entry.value().as_str() == profile_id)
        .map(|entry| entry.key().clone())
        .collect::<Vec<_>>();
    for device_id in cached_profile_devices {
        state.identity_cache.remove(&device_id);
        state.profile_cache.remove(&device_id);
        state.push_wake_last_ms.remove(&device_id);
    }

    Ok(Json(HttpProfileDeleteResp {
        ok: true,
        profile_id,
        deleted_rows: result.deleted_rows,
        deleted_blob_count,
    }))
}

fn port_from_env(var: &str, default_port: u16) -> u16 {
    match env::var(var) {
        Ok(value) => value.parse().unwrap_or(default_port),
        Err(_) => default_port,
    }
}

fn u32_from_env(var: &str, default_value: u32) -> u32 {
    match env::var(var) {
        Ok(value) => value.parse().unwrap_or(default_value),
        Err(_) => default_value,
    }
}

fn f64_from_env(var: &str, default_value: f64) -> f64 {
    match env::var(var) {
        Ok(value) => value.parse().unwrap_or(default_value),
        Err(_) => default_value,
    }
}

fn bind_ip_from_env(var: &str, default_ip: [u8; 4]) -> std::net::IpAddr {
    match env::var(var) {
        Ok(value) => {
            // Accept either an IP ("0.0.0.0") or an ip:port ("0.0.0.0:8082").
            // Only the IP part is used here; port is read from SECRETLY_RELAY_PORT.
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

fn csv_env(var: &str) -> Vec<String> {
    env::var(var)
        .ok()
        .map(|value| {
            value
                .split(',')
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(|value| value.to_string())
                .collect::<Vec<String>>()
        })
        .unwrap_or_default()
}

fn normalize_call_ice_policy(raw: &str) -> String {
    match raw.trim().to_ascii_lowercase().as_str() {
        "relay_preferred" => "relay_preferred".to_string(),
        "relay_only" => "relay_only".to_string(),
        _ => "p2p_preferred".to_string(),
    }
}

fn effective_call_ice_policy(requested: &str, has_turn: bool) -> String {
    let normalized = normalize_call_ice_policy(requested);
    if has_turn {
        normalized
    } else {
        "p2p_preferred".to_string()
    }
}

fn build_turn_rest_username(device_id: &str, expires_at_s: i64) -> String {
    format!("{}:{}", expires_at_s, device_id)
}

fn build_turn_rest_credential(shared_secret: &str, username: &str) -> Option<String> {
    let mut mac = HmacSha1::new_from_slice(shared_secret.as_bytes()).ok()?;
    mac.update(username.as_bytes());
    Some(base64::engine::general_purpose::STANDARD.encode(mac.finalize().into_bytes()))
}

fn i64_from_env(var: &str, default_value: i64) -> i64 {
    env::var(var)
        .ok()
        .and_then(|value| value.parse::<i64>().ok())
        .unwrap_or(default_value)
}

fn relay_server_protocol_version() -> i64 {
    i64_from_env("SECRETLY_RELAY_SERVER_PROTOCOL_VERSION", 1).max(1)
}

fn relay_min_client_protocol_version() -> i64 {
    i64_from_env("SECRETLY_RELAY_MIN_CLIENT_PROTOCOL_VERSION", 1).max(1)
}

fn relay_max_client_protocol_version(
    min_client_protocol_version: i64,
    server_protocol_version: i64,
) -> i64 {
    i64_from_env(
        "SECRETLY_RELAY_MAX_CLIENT_PROTOCOL_VERSION",
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

fn load_call_ice_runtime_config() -> RelayCallIceRuntimeConfig {
    RelayCallIceRuntimeConfig {
        policy: normalize_call_ice_policy(
            &env::var("SECRETLY_RELAY_ICE_POLICY").unwrap_or_else(|_| "p2p_preferred".into()),
        ),
        stun_urls: csv_env("SECRETLY_RELAY_ICE_STUN_URLS"),
        turn_urls: csv_env("SECRETLY_RELAY_ICE_TURN_URLS"),
        turn_shared_secret: env::var("SECRETLY_RELAY_TURN_SHARED_SECRET").unwrap_or_default(),
        turn_ttl_seconds: u32_from_env("SECRETLY_RELAY_TURN_TTL_SECONDS", 600).clamp(60, 3600),
    }
}

fn load_call_session_runtime_config() -> RelayCallSessionRuntimeConfig {
    let active_ttl_seconds = u32_from_env("SECRETLY_RELAY_CALL_SESSION_TTL_SECONDS", 6 * 60 * 60)
        .clamp(5 * 60, 7 * 24 * 60 * 60);
    let terminal_ttl_seconds =
        u32_from_env("SECRETLY_RELAY_TERMINAL_CALL_SESSION_TTL_SECONDS", 15 * 60)
            .clamp(60, 24 * 60 * 60)
            .min(active_ttl_seconds);

    RelayCallSessionRuntimeConfig {
        active_ttl_seconds,
        terminal_ttl_seconds,
    }
}

fn load_room_media_runtime_config() -> RelayRoomMediaRuntimeConfig {
    let requested_backend = RelayRoomMediaBackendKind::parse(
        &env::var("SECRETLY_RELAY_ROOM_MEDIA_BACKEND").unwrap_or_else(|_| "unavailable".into()),
    );
    let livekit_url =
        optional_string_env("SECRETLY_RELAY_ROOM_MEDIA_LIVEKIT_URL").unwrap_or_default();
    let livekit_api_key =
        optional_string_env("SECRETLY_RELAY_ROOM_MEDIA_LIVEKIT_API_KEY").unwrap_or_default();
    let livekit_api_secret =
        optional_string_env("SECRETLY_RELAY_ROOM_MEDIA_LIVEKIT_API_SECRET").unwrap_or_default();
    let token_ttl_seconds =
        u32_from_env("SECRETLY_RELAY_ROOM_MEDIA_TOKEN_TTL_SECONDS", 600).clamp(60, 3600);
    let effective_backend = match requested_backend {
        RelayRoomMediaBackendKind::Livekit
            if !livekit_url.trim().is_empty()
                && !livekit_api_key.trim().is_empty()
                && !livekit_api_secret.trim().is_empty() =>
        {
            RelayRoomMediaBackendKind::Livekit
        }
        _ => RelayRoomMediaBackendKind::Unavailable,
    };

    RelayRoomMediaRuntimeConfig {
        requested_backend,
        effective_backend,
        livekit_url,
        livekit_api_key,
        livekit_api_secret,
        token_ttl_seconds,
    }
}

fn relay_call_ice_preflight(cfg: &RelayCallIceRuntimeConfig) {
    if cfg.stun_urls.is_empty() && cfg.turn_urls.is_empty() {
        tracing::warn!(
            "CALLS: no relay-managed ICE servers configured; clients will fall back to empty ICE config"
        );
    }

    if !cfg.turn_urls.is_empty() && cfg.turn_shared_secret.trim().is_empty() {
        tracing::warn!(
            "CALLS: TURN URLs configured but SECRETLY_RELAY_TURN_SHARED_SECRET is empty; relay cannot mint short-lived TURN credentials"
        );
    }

    if cfg.policy == "relay_only"
        && (cfg.turn_urls.is_empty() || cfg.turn_shared_secret.trim().is_empty())
    {
        tracing::warn!(
            "CALLS: relay_only ICE policy requested without working TURN configuration; effective policy will downgrade at runtime"
        );
    }
}

fn relay_call_session_preflight(cfg: &RelayCallSessionRuntimeConfig) {
    if cfg.active_ttl_seconds <= 90 {
        tracing::warn!(
            active_ttl_seconds = cfg.active_ttl_seconds,
            "CALLS: relay call-session TTL is still too close to signal TTL; long-call reconnect authority may still expire too early"
        );
    }

    tracing::info!(
        active_ttl_seconds = cfg.active_ttl_seconds,
        terminal_ttl_seconds = cfg.terminal_ttl_seconds,
        "CALLS: relay call-session retention configured"
    );
}

fn relay_room_media_preflight(cfg: &RelayRoomMediaRuntimeConfig) {
    if cfg.requested_backend == RelayRoomMediaBackendKind::Livekit && !cfg.backend_url_configured()
    {
        tracing::warn!(
            "ROOM-MEDIA: livekit backend requested but SECRETLY_RELAY_ROOM_MEDIA_LIVEKIT_URL is empty; relay will stay bootstrap-only"
        );
    }

    if cfg.requested_backend == RelayRoomMediaBackendKind::Livekit && !cfg.token_issuer_ready() {
        tracing::warn!(
            "ROOM-MEDIA: livekit backend requested but API key/secret are missing; relay will stay bootstrap-only"
        );
    }

    if cfg.effective_backend == RelayRoomMediaBackendKind::Livekit {
        tracing::info!(
            backend = cfg.effective_backend.as_str(),
            url = %cfg.livekit_url,
            token_ttl_seconds = cfg.token_ttl_seconds,
            "ROOM-MEDIA: session authority configured"
        );
    } else {
        tracing::info!(
            requested_backend = cfg.requested_backend.as_str(),
            effective_backend = cfg.effective_backend.as_str(),
            "ROOM-MEDIA: session authority unavailable; relay will expose bootstrap-only descriptors"
        );
    }
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

fn relay_security_errors(
    bind_ip: std::net::IpAddr,
    production_mode: bool,
    require_auth: bool,
    trust_xff: bool,
    proxy_only: bool,
    internal_key: &str,
) -> Vec<String> {
    let mut errors = Vec::new();
    if !production_mode {
        return errors;
    }

    if !require_auth {
        errors.push(
            "SECURITY: relay refuses to start in production when SECRETLY_RELAY_REQUIRE_AUTH is disabled."
                .into(),
        );
    }

    if trust_xff && !bind_ip.is_loopback() && !proxy_only {
        errors.push(
            "SECURITY: relay refuses to trust X-Forwarded-For on non-loopback bind in production unless SECRETLY_RELAY_PROXY_ONLY is enabled."
                .into(),
        );
    }

    if internal_key.trim().is_empty() {
        errors.push(
            "SECURITY: relay refuses to start in production with empty SECRETLY_INTERNAL_KEY."
                .into(),
        );
    }

    errors
}

fn relay_security_preflight(bind_ip: std::net::IpAddr) -> Result<(), Vec<String>> {
    let require_auth = require_auth_enabled();
    if !require_auth {
        tracing::warn!(
            "SECURITY: SECRETLY_RELAY_REQUIRE_AUTH is disabled. This is unsafe for production."
        );
    }

    let trust_xff = bool_env("SECRETLY_RELAY_TRUST_XFF", false);
    let proxy_only = bool_env("SECRETLY_RELAY_PROXY_ONLY", false);
    if trust_xff && !bind_ip.is_loopback() {
        tracing::warn!(
            %bind_ip,
            "SECURITY: SECRETLY_RELAY_TRUST_XFF is enabled on non-loopback bind. Ensure relay is reachable only through trusted proxy and direct public access is blocked."
        );
    }

    let internal_key = env::var("SECRETLY_INTERNAL_KEY").unwrap_or_default();
    if internal_key.trim().is_empty() {
        tracing::warn!(
            "SECURITY: SECRETLY_INTERNAL_KEY is empty. Internal service-to-service trust protection is disabled."
        );
    }

    let production_mode = is_production_mode(
        current_runtime_env().as_deref(),
        bool_env("SECRETLY_STRICT_PRODUCTION", false),
    );
    let errors = relay_security_errors(
        bind_ip,
        production_mode,
        require_auth,
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

/// Sprint 2 R4: physical cleanup of inactive devices.
///
/// One iteration of the cleanup loop. Holds the following invariants:
///
/// * INV-1 (Restore Safety Contract): a profile is never left with
///   zero non-cleanup-eligible devices. The per-row INV-1 check is
///   the **post-delete** active count for the profile — if removing
///   the row would leave the profile with 0 devices outside the
///   cleanup eligibility window, the row is kept.
/// * INV-5: cleanup acts only on devices whose newest liveness signal
///   is older than [`DEVICE_INACTIVE_CLEANUP_THRESHOLD_MS`] — strictly
///   longer than the R3 hide threshold so devices first pass through
///   the «hidden but recoverable» state before being physically
///   removed.
/// * Idempotency: re-running the loop in quick succession is safe.
///   The store's `device_activity_delete` returns `false` for already-
///   gone rows; the push-token delete is unconditional.
///
/// Returns the number of device rows actually deleted. The caller
/// should sleep `RELAY_INACTIVE_DEVICE_CLEANUP_INTERVAL_SECS` between
/// invocations.
async fn run_inactive_device_cleanup_pass(state: &AppState) -> u64 {
    let now = now_ms();
    let cutoff = now.saturating_sub(DEVICE_INACTIVE_CLEANUP_THRESHOLD_MS);

    let candidates = match state
        .store
        .device_activity_list_stale(cutoff, DEVICE_CLEANUP_BATCH_LIMIT)
        .await
    {
        Ok(v) => v,
        Err(e) => {
            tracing::warn!(error=%e, "device_cleanup: list_stale failed");
            return 0;
        }
    };

    if candidates.is_empty() {
        return 0;
    }

    let mut deleted: u64 = 0;
    // Group candidates by profile so we evaluate INV-1 once per profile.
    let mut by_profile: std::collections::BTreeMap<String, Vec<DeviceActivityRow>> =
        std::collections::BTreeMap::new();
    for row in candidates {
        by_profile.entry(row.profile_id.clone()).or_default().push(row);
    }

    for (profile_id, mut stale_rows) in by_profile {
        if profile_id.is_empty() {
            continue;
        }

        // Read ALL devices known to relay for this profile (not just the
        // stale ones) so we can compute "active devices after deletion".
        let all_for_profile = match state
            .store
            .device_activity_list_for_profile(&profile_id)
            .await
        {
            Ok(v) => v,
            Err(e) => {
                tracing::warn!(
                    profile_ref=%log_fingerprint(&profile_id),
                    error=%e,
                    "device_cleanup: list_for_profile failed; skipping batch"
                );
                continue;
            }
        };

        let stale_device_ids: std::collections::BTreeSet<String> = stale_rows
            .iter()
            .map(|r| r.device_id.clone())
            .collect();
        let survivors_active = all_for_profile
            .iter()
            .filter(|r| !stale_device_ids.contains(&r.device_id))
            .filter(|r| {
                let last_signal = r.last_pump_at_ms.max(r.last_push_delivered_at_ms);
                now.saturating_sub(last_signal) <= DEVICE_STALENESS_THRESHOLD_MS
            })
            .count();

        // Sort stale rows oldest-first so the very stalest goes first
        // and the more recently-silent rows get a stay-of-execution if
        // INV-1 needs them.
        stale_rows.sort_by_key(|r| r.updated_at_ms);

        for row in stale_rows {
            if survivors_active < 1 {
                // INV-1: keep this row. The profile would otherwise
                // have zero discoverable devices.
                tracing::info!(
                    profile_ref=%log_fingerprint(&profile_id),
                    device_ref=%log_fingerprint(&row.device_id),
                    "device_cleanup: skipping delete (INV-1: no other active device would remain)"
                );
                continue;
            }

            // Remove the device's push tokens (any platform) so we stop
            // attempting wake-ups, then drop the activity row so the
            // R3 filter forgets about the device entirely.
            if let Err(e) = state.store.delete_push_token(&row.device_id).await {
                tracing::warn!(
                    profile_ref=%log_fingerprint(&profile_id),
                    device_ref=%log_fingerprint(&row.device_id),
                    error=%e,
                    "device_cleanup: delete_push_token failed; aborting this device"
                );
                continue;
            }
            match state.store.device_activity_delete(&row.device_id).await {
                Ok(true) => {
                    deleted += 1;
                    tracing::warn!(
                        profile_ref=%log_fingerprint(&profile_id),
                        device_ref=%log_fingerprint(&row.device_id),
                        silent_ms = now.saturating_sub(row.updated_at_ms),
                        "device_cleanup_deleted: dropped push token + activity row"
                    );
                }
                Ok(false) => {
                    // Row was already gone — count nothing.
                }
                Err(e) => {
                    tracing::warn!(
                        profile_ref=%log_fingerprint(&profile_id),
                        device_ref=%log_fingerprint(&row.device_id),
                        error=%e,
                        "device_cleanup: device_activity_delete failed"
                    );
                }
            }
        }
    }

    deleted
}

/// Long-running background task that periodically invokes
/// `run_inactive_device_cleanup_pass`. Exits silently if the feature
/// flag flips OFF mid-run; the next process restart will re-evaluate.
async fn inactive_device_cleanup_loop(state: AppState) {
    let interval_secs = env::var("RELAY_INACTIVE_DEVICE_CLEANUP_INTERVAL_SECS")
        .ok()
        .and_then(|v| v.parse::<u64>().ok())
        .unwrap_or(DEVICE_CLEANUP_INTERVAL_DEFAULT_SECS)
        .clamp(DEVICE_CLEANUP_INTERVAL_MIN_SECS, DEVICE_CLEANUP_INTERVAL_MAX_SECS);

    tracing::info!(
        interval_secs,
        threshold_days = (DEVICE_INACTIVE_CLEANUP_THRESHOLD_MS / 86_400_000),
        "inactive_device_cleanup_loop started"
    );

    let mut ticker = tokio::time::interval(Duration::from_secs(interval_secs));
    // First tick fires immediately; skip it so we don't run the loop
    // on the very first server boot before any clients have logged in.
    ticker.tick().await;

    loop {
        ticker.tick().await;
        if !device_cleanup_enabled() {
            // Feature flag flipped OFF — sleep and re-check next tick.
            continue;
        }
        let started = std::time::Instant::now();
        let deleted = run_inactive_device_cleanup_pass(&state).await;
        let elapsed_ms = started.elapsed().as_millis();
        if deleted > 0 {
            tracing::info!(
                deleted,
                elapsed_ms = elapsed_ms as i64,
                "inactive_device_cleanup_pass completed"
            );
        }
    }
}

// SEQ-CURSOR FIX A2 (2026-06-07): how often the orphan re-push sweep runs.
const ORPHAN_REPUSH_INTERVAL_SECS: u64 = 45;
// Max rows re-pushed per device per sweep (keeps a huge backlog from
// monopolising a single tick; the next tick continues the drain).
const ORPHAN_REPUSH_PER_DEVICE_LIMIT: usize = 100;
// RELIABLE-DELIVERY (2026-07-08): a pending row is only re-delivered by the
// sweep once its last delivery attempt is at least this old — long enough that
// a healthy client has had time to ACK the realtime/backfill copy, short enough
// that a dropped message is retried promptly. Smaller than the sweep interval so
// a genuinely stuck row is re-tried on (almost) every pass until acked.
const REDELIVER_BACKOFF_MS: i64 = 30_000;

/// One pass of the reliable-delivery re-push sweep. For every CONNECTED device
/// it re-delivers EVERY still-pending (unacked) row whose last delivery attempt
/// is older than [`REDELIVER_BACKOFF_MS`] — an at-least-once "retry until the
/// client ACKs" guarantee.
///
/// This supersedes the old below-cursor-only sweep. A message dropped by a
/// connected client — lost in a reconnect-backfill flood (the connect handler
/// fires Deliver best-effort), or transiently undecryptable — sits ABOVE the
/// delivery cursor, so the below-cursor sweep never retried it and it stranded
/// until the next reconnect. Now any unacked row is retried on the live socket
/// until the client stores+ACKs it (which deletes the row).
///
/// Safety / idempotency:
///   * Only touches devices with a LIVE socket in `state.conns` — never wakes
///     offline devices, never sends a push.
///   * `last_attempt_ms` backoff (stamped at enqueue, connect-backfill, and
///     here) means a freshly delivered message is not re-sent for one backoff,
///     so the happy path never double-delivers a message the client is about to
///     ack.
///   * The client de-duplicates every re-delivery (`inbox_seen` msg_id +
///     `events` INSERT-OR-IGNORE on event_id), so a re-send is invisible.
///   * Expired rows are excluded by the query; TTL cleanup removes them.
///
/// Returns the number of rows re-pushed this pass (for telemetry).
async fn run_orphan_repush_pass(state: &AppState) -> u64 {
    // Snapshot the connected device ids so we don't hold DashMap guards
    // across awaits.
    let device_ids: Vec<String> = state
        .conns
        .iter()
        .map(|entry| entry.key().clone())
        .collect();
    if device_ids.is_empty() {
        return 0;
    }

    let now = now_ms();
    let mut repushed: u64 = 0;
    for device_id in device_ids {
        let stale = match state
            .store
            .list_pending_for_redelivery(
                &device_id,
                REDELIVER_BACKOFF_MS,
                now,
                ORPHAN_REPUSH_PER_DEVICE_LIMIT,
            )
            .await
        {
            Ok(v) => v,
            Err(e) => {
                tracing::warn!(
                    device_ref = %log_fingerprint(&device_id),
                    error = %e,
                    "redeliver_sweep: list_pending_for_redelivery failed"
                );
                continue;
            }
        };
        if stale.is_empty() {
            continue;
        }
        // Re-resolve the live sender each row-batch in case the socket was
        // replaced mid-sweep.
        let Some(tx) = state.conns.get(&device_id).map(|v| v.clone()) else {
            continue;
        };
        // The sweep is where a stuck mailbox shows itself: every row here has
        // already been offered at least once and gone unacked for a full
        // backoff. `reoffered` == `count` on this line is the signature.
        log_mailbox_drain("ws-redeliver", &device_id, &stale, now);
        let mut sent_seqs: Vec<u64> = Vec::with_capacity(stale.len());
        for p in &stale {
            let deliver = ServerMsg::Deliver {
                device_id: device_id.clone(),
                seq: p.seq,
                msg_id: p.msg_id.clone(),
                ciphertext_b64: p.ciphertext_b64.clone(),
                transport_meta_json: p.transport_meta_json.clone(),
                from_device_id: p.from_device_id.clone(),
            };
            match serde_json::to_string(&deliver) {
                Ok(payload) => {
                    if tx.send(Message::Text(payload.into())).is_err() {
                        remove_conn_if_same(state, &device_id, &tx);
                        break;
                    }
                    sent_seqs.push(p.seq);
                    repushed += 1;
                }
                Err(_) => {}
            }
        }
        if !sent_seqs.is_empty() {
            let count = sent_seqs.len();
            // Back off before re-sending these again next pass.
            if let Err(e) = state
                .store
                .mark_pending_attempted(&device_id, sent_seqs, now)
                .await
            {
                tracing::debug!(
                    device_ref = %log_fingerprint(&device_id),
                    error = %e,
                    "redeliver_sweep: mark_pending_attempted failed (non-fatal)"
                );
            }
            tracing::info!(
                device_ref = %log_fingerprint(&device_id),
                count,
                "redeliver_sweep: re-delivered unacked pending messages"
            );
        }
    }
    repushed
}

/// DELIVERY-WAKE AUDIT (2026-07-16): minimum gap since the device's last push
/// attempt (or pump) before the offline re-wake sweep fires another push,
/// keyed by how old the stranded backlog is.
///
/// Why this exists: a wake push is normally sent exactly once per message, 2s
/// after enqueue (`schedule_fcm_if_still_pending` + `push_wake_dedup`). If that
/// single handoff dies — FCM socket dead behind carrier NAT, transient FCM/APNs
/// error, relay restart inside the 2s window — NOTHING ever pushed that device
/// again and its mailbox stranded until the next fresh message (prod: mailboxes
/// stuck for days, then TTL-pruned unread). This ladder re-attempts a wake for
/// any stranded mailbox, seldom enough not to spam (collapse_key already keeps
/// at most one queued wake per device; the banner replaces, never stacks):
/// fresh backlog retries every 10 min, day-old backlog every 6 h.
///
/// The gap is measured against `max(last_push_attempted, last_pump)`, so an
/// initial push that DID go out starts a full 10-min quiet window, while a
/// backlog whose initial push was never attempted (restart window) fires on the
/// next sweep tick.
/// Whether an offline re-wake may ANNOUNCE the backlog, or must only wake the
/// device silently.
///
/// It may announce exactly when NO push was ever attempted for THIS backlog —
/// i.e. the last attempt predates the moment the backlog started. That is the
/// case the ladder exists for: the one push at send time never went out (dead
/// FCM socket behind carrier NAT, relay restart inside the 2s window), so
/// nobody has ever been told these messages are waiting. Announcing matters
/// most on a KILLED iOS app, which a silent data push may not even launch.
///
/// Every LATER attempt is silent, because sending the first one stamps
/// `last_push_attempted_at_ms` past `backlog_started_ms`. So a stranded backlog
/// produces at most ONE banner — never the every-30-minutes stream of
/// "Secretly — New message" that users reported on 2026-07-30 for messages they
/// had already read.
///
/// A device that keeps receiving pushes for NEW messages is likewise silent
/// here: its last attempt is newer than the backlog, and those new messages
/// already alerted the user themselves.
fn offline_rewake_should_announce(backlog_started_ms: i64, last_push_attempted_at_ms: i64) -> bool {
    last_push_attempted_at_ms < backlog_started_ms
}

fn offline_rewake_required_gap_ms(backlog_age_ms: i64) -> i64 {
    const MIN_10: i64 = 10 * 60 * 1000;
    const MIN_30: i64 = 30 * 60 * 1000;
    const HOUR_2: i64 = 2 * 60 * 60 * 1000;
    const HOUR_6: i64 = 6 * 60 * 60 * 1000;
    if backlog_age_ms < 30 * 60 * 1000 {
        MIN_10
    } else if backlog_age_ms < 6 * 60 * 60 * 1000 {
        MIN_30
    } else if backlog_age_ms < 48 * 60 * 60 * 1000 {
        HOUR_2
    } else {
        HOUR_6
    }
}

/// One pass of the offline re-wake sweep — the push-side counterpart of
/// [`run_orphan_repush_pass`]. That sweep retries delivery over LIVE sockets;
/// this one re-attempts the WAKE for devices with NO live socket whose mailbox
/// is stranded, on the [`offline_rewake_required_gap_ms`] backoff ladder.
///
/// The re-wake is device-level (`msg_id = None`), so the per-msg_id
/// `push_wake_dedup` does not apply; `record_push_attempted` (stamped inside
/// `maybe_send_fcm_data_push`) is what arms the next backoff window. It covers
/// reactions/receipts whose only wake was dropped by the 3.5s interval throttle,
/// too — they are pending rows like any other.
///
/// The wake is SILENT except for at most ONE announcement per stranded backlog
/// — see [`offline_rewake_should_announce`]. Normally the recipient was already
/// alerted by the push at send time, and a re-attempt exists to make the device
/// drain and ACK, not to announce anything again.
///
/// Until 2026-07-30 that was only intended, never implemented: the payload
/// builder defaults `include_notification` to true and every branch that turns
/// it off needs transport metadata to parse, so the metadata-less re-wake went
/// out as a real "Secretly — New message" banner — every 30 minutes, for hours,
/// about messages the user had already read.
async fn run_offline_rewake_pass(state: &AppState) -> u64 {
    let now = now_ms();
    let candidates = match state.store.list_offline_wake_candidates(now).await {
        Ok(v) => v,
        Err(e) => {
            tracing::warn!(error = %e, "offline_rewake: candidate query failed");
            return 0;
        }
    };
    if candidates.is_empty() {
        return 0;
    }

    let mut woken: u64 = 0;
    for c in candidates {
        // A device with a live socket is the WS redeliver sweep's job.
        if state.conns.contains_key(&c.device_id) {
            continue;
        }
        let backlog_age_ms = (now - c.backlog_started_ms).max(0);
        let last_wake_floor = c.last_push_attempted_at_ms.max(c.last_pump_at_ms);
        let gap_ms = now - last_wake_floor;
        let required_gap_ms = offline_rewake_required_gap_ms(backlog_age_ms);
        if gap_ms < required_gap_ms {
            continue;
        }
        let has_chat = c
            .newest_meta_json
            .as_deref()
            .is_some_and(|m| m.contains("chat_message_v1"));
        // At most ONE announcement per stranded backlog — see
        // `offline_rewake_should_announce`. When we do announce, carry the real
        // transport meta so the banner names the sender and shows the preview
        // instead of a bare "New message"; policy, mute and quiet-hours gating
        // then apply exactly as they do for a normal message push.
        let announce = offline_rewake_should_announce(
            c.backlog_started_ms,
            c.last_push_attempted_at_ms,
        );
        let meta = if announce {
            c.newest_meta_json.clone()
        } else {
            None
        };
        tracing::info!(
            device_ref = %log_fingerprint(&c.device_id),
            pending = c.pending_count,
            backlog_age_ms,
            gap_ms,
            has_chat,
            announce,
            "offline_rewake: re-attempting push wake for stranded mailbox"
        );
        // SILENT re-wake: the recipient was ALREADY alerted by the FIRST push at
        // send time. A re-attempt must only WAKE the device to drain/ACK — never
        // raise a DUPLICATE banner (users saw a fresh banner every ~10-12 min for
        // the same stranded message). None meta ⇒ data-only wake, no
        // notification. (None also can't be misread as a call-signal.)
        maybe_send_fcm_data_push(
            state.clone(),
            c.device_id.clone(),
            None,
            None,
            meta,
            !announce,
            // Лестница офлайн-пробуждений не привязана к конверту и схлопыванию
            // не подлежит: у неё своё правило «не более одного объявления».
            None,
        )
        .await;
        woken += 1;
    }
    woken
}

/// Long-running background task driving `run_orphan_repush_pass` (live-socket
/// redelivery) and `run_offline_rewake_pass` (push re-wake for stranded
/// offline mailboxes).
/// SERVER-SIDE SCHEDULED DELIVERY (2026-07-17): the release tick. Finds
/// scheduled rows that crossed their `deliver_at_ms` since the previous scan
/// and delivers them PROMPTLY — WS if the recipient is connected (the same
/// pass's `run_orphan_repush_pass` re-delivers the now-visible row), else a
/// single immediate push wake so the recipient's device drains it. This is
/// what makes "send later" fire at (roughly) T even though the SENDER's phone
/// is asleep: the ciphertext was uploaded at schedule time and the relay,
/// which never sleeps, releases it.
///
/// `since_ms` starts at 0 so the first tick after a (re)start also releases
/// any rows whose T already passed while the relay was down — recovery is
/// automatic, nothing is stranded.
async fn run_scheduled_release_pass(state: &AppState, since_ms: i64) -> u64 {
    let now = now_ms();
    let due = match state
        .store
        .list_devices_with_freshly_due_scheduled(now, since_ms)
        .await
    {
        Ok(v) => v,
        Err(e) => {
            tracing::warn!(error = %e, "scheduled_release: due query failed");
            return 0;
        }
    };
    let mut released: u64 = 0;
    for c in due {
        released += 1;
        // Connected recipient → the orphan repush pass (same loop tick)
        // re-delivers the now-visible row over the live socket; no push needed.
        if state.conns.contains_key(&c.device_id) {
            tracing::info!(
                device_ref = %log_fingerprint(&c.device_id),
                pending = c.pending_count,
                "scheduled_release: due row for connected device; WS sweep delivers"
            );
            continue;
        }
        let meta = c
            .newest_meta_json
            .clone()
            .filter(|m| !m.contains("call_signal_v1"));
        tracing::info!(
            device_ref = %log_fingerprint(&c.device_id),
            pending = c.pending_count,
            "scheduled_release: released scheduled row; waking offline recipient"
        );
        maybe_send_fcm_data_push(state.clone(), c.device_id.clone(), None, None, meta, false, None)
            .await;
    }
    released
}

async fn orphan_repush_loop(state: AppState) {
    let mut ticker = tokio::time::interval(Duration::from_secs(ORPHAN_REPUSH_INTERVAL_SECS));
    // Skip the immediate first tick; let the service settle after boot.
    ticker.tick().await;
    tracing::info!(
        interval_secs = ORPHAN_REPUSH_INTERVAL_SECS,
        "orphan_repush_loop started"
    );
    // Release-scan watermark: 0 on boot so the first pass releases anything
    // whose T elapsed while the relay was restarting.
    let mut last_release_scan_ms: i64 = 0;
    loop {
        ticker.tick().await;
        // Release freshly-due scheduled rows FIRST, so the orphan repush pass
        // below immediately re-delivers them to any connected recipient in the
        // same tick.
        let scan_at = now_ms();
        let released = run_scheduled_release_pass(&state, last_release_scan_ms).await;
        last_release_scan_ms = scan_at;
        if released > 0 {
            tracing::info!(released, "scheduled_release_pass released due scheduled messages");
        }
        let repushed = run_orphan_repush_pass(&state).await;
        if repushed > 0 {
            tracing::info!(repushed, "orphan_repush_pass re-delivered stranded messages");
        }
        let rewoken = run_offline_rewake_pass(&state).await;
        if rewoken > 0 {
            tracing::info!(rewoken, "offline_rewake_pass re-attempted stranded mailbox wakes");
        }
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

    let port = port_from_env("SECRETLY_RELAY_PORT", 8082);
    let ip = bind_ip_from_env("SECRETLY_RELAY_BIND", [127, 0, 0, 1]);
    if let Err(errors) = relay_security_preflight(ip) {
        for error in errors {
            tracing::error!("{error}");
        }
        panic!("unsafe relay production configuration");
    }
    let require_auth = require_auth_enabled();
    let addr: SocketAddr = (ip, port).into();

    let db_path = env::var("SECRETLY_RELAY_DB").unwrap_or_else(|_| "relay.db".into());
    let store = RelayStore::open(db_path).await.expect("open relay store");

    let blobs_dir = env::var("SECRETLY_BLOBS_DIR").unwrap_or_else(|_| "blobs".into());
    let blobs_dir = PathBuf::from(blobs_dir);
    let sticker_catalog_dir = env::var("SECRETLY_RELAY_STICKER_CATALOG_DIR")
        .unwrap_or_else(|_| "server/relay/sticker_catalog".into());
    let sticker_catalog_dir = PathBuf::from(sticker_catalog_dir);
    let cosmetics_dir = env::var("SECRETLY_RELAY_COSMETICS_DIR")
        .unwrap_or_else(|_| "server/relay/cosmetics".into());
    let cosmetics_dir = PathBuf::from(cosmetics_dir);

    let keys_internal_base_url = env::var("SECRETLY_RELAY_KEYS_INTERNAL_BASE_URL")
        .unwrap_or_else(|_| "http://127.0.0.1:8081".into());

    let internal_key = env::var("SECRETLY_INTERNAL_KEY").unwrap_or_default();
    let call_ice = load_call_ice_runtime_config();
    let room_media = load_room_media_runtime_config();
    let call_sessions = load_call_session_runtime_config();
    relay_call_ice_preflight(&call_ice);
    relay_room_media_preflight(&room_media);
    relay_call_session_preflight(&call_sessions);

    // Basic anti-abuse: per-IP token bucket.
    // Default: 60 req burst, ~2 req/sec sustained.
    let cap = u32_from_env("SECRETLY_RELAY_RL_CAP", 60);
    let refill_per_sec = f64_from_env("SECRETLY_RELAY_RL_REFILL_PER_SEC", 2.0);
    let limiter = Arc::new(IpRateLimiter::new(cap, refill_per_sec));

    // AUD-080: invite-redeem-specific limiters. Defaults are conservative:
    // per slug - 10 burst, 1 req/sec sustained.
    // per caller device - 30 burst, 3 req/sec sustained.
    let invite_slug_cap = u32_from_env("SECRETLY_RELAY_RL_INVITE_SLUG_CAP", 10);
    let invite_slug_refill = f64_from_env("SECRETLY_RELAY_RL_INVITE_SLUG_REFILL_PER_SEC", 1.0);
    let invite_caller_cap = u32_from_env("SECRETLY_RELAY_RL_INVITE_CALLER_CAP", 30);
    let invite_caller_refill = f64_from_env("SECRETLY_RELAY_RL_INVITE_CALLER_REFILL_PER_SEC", 3.0);
    let invite_redeem_slug_limiter = Arc::new(StringKeyRateLimiter::new(
        invite_slug_cap,
        invite_slug_refill,
    ));
    let invite_redeem_caller_limiter = Arc::new(StringKeyRateLimiter::new(
        invite_caller_cap,
        invite_caller_refill,
    ));

    // Cap message TTL to keep pending queue bounded.
    let max_msg_ttl_seconds = u32_from_env("SECRETLY_RELAY_MAX_TTL_SECONDS", 7 * 24 * 3600)
        .min(30 * 24 * 3600)
        .max(60);

    // Мост для своих устройств (25.09.2026): 0 = выключено, иначе срок в
    // секундах, не длиннее общего предела. См. `own_device_control_ttl`.
    let own_device_control_ttl_seconds =
        u32_from_env("SECRETLY_RELAY_OWN_DEVICE_CONTROL_TTL_SECONDS", 0).min(max_msg_ttl_seconds);

    // Cap pending queue per device to avoid unbounded DB growth.
    let max_pending_per_device = u32_from_env("SECRETLY_RELAY_MAX_PENDING_PER_DEVICE", 5000)
        .min(100_000)
        .max(100) as u64;

    let http_timeout_secs = u32_from_env("SECRETLY_RELAY_HTTP_TIMEOUT_SECS", 8).clamp(2, 60) as u64;
    let deployment_id = optional_string_env("SECRETLY_RELAY_DEPLOYMENT_ID").unwrap_or_default();
    let release_channel = optional_string_env("SECRETLY_RELAY_RELEASE_CHANNEL").unwrap_or_default();
    let service_started_at_ms = now_ms();

    let state = AppState {
        store: Arc::new(store),
        conns: Arc::new(DashMap::new()),
        wake_coalesce: Arc::new(DashMap::new()),
        blobs_dir: Arc::new(blobs_dir),
        sticker_catalog_dir: Arc::new(sticker_catalog_dir),
        cosmetics_dir: Arc::new(cosmetics_dir),
        limiter,
        invite_redeem_slug_limiter,
        invite_redeem_caller_limiter,
        max_msg_ttl_seconds,
        own_device_control_ttl_seconds,
        max_pending_per_device,
        keys_internal_base_url: Arc::new(keys_internal_base_url),
        internal_key: Arc::new(internal_key),
        http: HttpClient::builder()
            .connect_timeout(Duration::from_secs(http_timeout_secs.min(10)))
            .timeout(Duration::from_secs(http_timeout_secs))
            .build()
            .expect("build relay internal http client"),
        identity_cache: Arc::new(DashMap::new()),
        profile_cache: Arc::new(DashMap::new()),
        used_nonces: Arc::new(DashMap::new()),
        push_wake_last_ms: Arc::new(DashMap::new()),
        fcm_legacy_server_key: Arc::new(
            env::var("SECRETLY_RELAY_FCM_SERVER_KEY").unwrap_or_default(),
        ),
        fcm_v1: Arc::new(
            env::var("SECRETLY_RELAY_FCM_SERVICE_ACCOUNT_JSON_PATH")
                .ok()
                .and_then(|v| {
                    let p = v.trim();
                    if p.is_empty() {
                        None
                    } else {
                        load_fcm_v1_config_from_path(p)
                    }
                }),
        ),
        apns_voip: Arc::new(load_apns_voip_config_from_env()),
        fcm_oauth_cache: Arc::new(Mutex::new(None)),
        apns_jwt_cache: Arc::new(Mutex::new(None)),
        call_ice: Arc::new(call_ice),
        room_media: Arc::new(room_media),
        call_sessions: Arc::new(call_sessions),
        require_auth,
        deployment_id: Arc::new(deployment_id),
        release_channel: Arc::new(release_channel),
        service_started_at_ms,
        monetization_enabled: env::var("SECRETLY_MONETIZATION_ENABLED")
            .map(|v| matches!(v.trim().to_ascii_lowercase().as_str(), "1" | "true" | "yes"))
            .unwrap_or(false),
        entitlement_cache: Arc::new(DashMap::new()),
        big_room_members: i64_env("SECRETLY_BIG_ROOM_MEMBERS", 0),
        big_room_min_build: i64_env("SECRETLY_BIG_ROOM_MIN_BUILD", 0),
    };

    // Разовая уборка временных файлов заливки, оставшихся от прошлых запусков.
    //
    // Страж `TmpBlobGuard` закрывает всё, что сломается ВПРЕДЬ, но на дисках
    // уже лежит мусор, накопленный до него, — и он же попал в ежедневные
    // копии, потому что скрипт архивирует папку `blobs` целиком.
    //
    // Возраст в сутки взят с большим запасом: заливка идёт минуты, а не часы,
    // и `.tmp` живёт только на время запроса. Свежий файл заведомо
    // принадлежит заливке, идущей прямо сейчас, — удалить его значит эту
    // заливку сорвать.
    {
        let sweep_dir = state.blobs_dir.clone();
        tokio::spawn(async move {
            sweep_stale_tmp_blobs(sweep_dir.as_ref()).await;
        });
    }

    // Sprint 2 R4: spawn the periodic inactive-device cleanup loop.
    // The loop itself rechecks `RELAY_INACTIVE_DEVICE_CLEANUP_ENABLED`
    // on every tick, so we can roll out the deploy with the flag OFF
    // and flip it ON via env var without a restart (the loop will
    // notice on its next tick).
    {
        let cleanup_state = state.clone();
        tokio::spawn(inactive_device_cleanup_loop(cleanup_state));
    }

    // SEQ-CURSOR FIX A2 (2026-06-07): spawn the orphaned-message re-push
    // sweep. For every currently-connected device it re-delivers any
    // pending rows stranded below the device cursor (lost-ACK strand),
    // because clients holding a stable WS never re-request them on their
    // own. Always on (no flag) — it is a pure delivery-correctness
    // mechanism with no destructive side effects.
    {
        let repush_state = state.clone();
        tokio::spawn(orphan_repush_loop(repush_state));
    }

    let app = Router::new()
        .route("/health", get(health))
        .route("/health/calls", get(call_health))
        .route("/health/push", get(push_health))
        .route("/health/room-media", get(room_media_health))
        .route("/ws", get(ws_handler))
        .route("/v1/welcome/{device_id}", get(http_welcome))
        .route("/v1/pending/{device_id}", get(http_pending))
        .route("/v1/send", post(http_send))
        .route("/v1/rooms/{room_id}/broadcast", post(http_room_broadcast))
        .route("/v1/ack", post(http_ack))
        .route("/v1/pending_check", post(http_pending_check))
        .route("/v1/cancel_scheduled", post(http_cancel_scheduled))
        .route("/v1/device/rebind", post(http_device_rebind))
        .route("/v1/rooms", post(http_room_create))
        .route("/v1/rooms/{room_id}", get(http_room_get))
        .route(
            "/v1/rooms/{room_id}/profile",
            post(http_room_profile_update),
        )
        .route(
            "/v1/rooms/{room_id}/settings",
            post(http_room_settings_update),
        )
        .route(
            "/v1/rooms/{room_id}/pinned-message",
            post(http_room_pinned_message_set),
        )
        .route(
            "/v1/rooms/{room_id}/member-tag",
            post(http_room_member_tag_set),
        )
        .route(
            "/v1/rooms/{room_id}/message-admissions",
            post(http_room_message_admission),
        )
        .route(
            "/v1/rooms/{room_id}/call",
            get(http_room_call_get).post(http_room_call_join),
        )
        .route(
            "/v1/rooms/{room_id}/call/{call_id}/self",
            post(http_room_call_self_update),
        )
        .route(
            "/v1/rooms/{room_id}/call/{call_id}/leave",
            post(http_room_call_leave),
        )
        .route(
            "/v1/rooms/{room_id}/call/{call_id}/participants/{participant_device_id}/remove",
            post(http_room_call_participant_remove),
        )
        .route(
            "/v1/rooms/{room_id}/call/{call_id}/end",
            post(http_room_call_end),
        )
        .route(
            "/v1/rooms/{room_id}/call/{call_id}/media",
            get(http_room_call_media_get),
        )
        .route(
            "/v1/rooms/{room_id}/call/{call_id}/media/join",
            post(http_room_call_media_join),
        )
        .route(
            "/v1/rooms/{room_id}/members",
            get(http_room_members_list).post(http_room_members_upsert),
        )
        .route(
            "/v1/rooms/{room_id}/members/{profile_id}/unban",
            post(http_room_member_unban),
        )
        .route("/v1/rooms/{room_id}/leave", post(http_room_leave))
        .route("/v1/rooms/{room_id}/delete", post(http_room_delete))
        .route(
            "/v1/rooms/{room_id}/transfer-ownership",
            post(http_room_transfer_ownership),
        )
        .route(
            "/v1/rooms/{room_id}/invite-links",
            get(http_room_invite_links_list).post(http_room_invite_links_create),
        )
        .route(
            "/v1/rooms/{room_id}/invite-links/{link_id}/revoke",
            post(http_room_invite_link_revoke),
        )
        .route("/v1/room-invites/{slug}", get(http_room_invite_preview))
        .route(
            "/v1/room-invites/{slug}/redeem",
            post(http_room_invite_redeem),
        )
        .route("/v1/ice/{device_id}", get(http_ice_config))
        .route(
            "/v1/call-session/{device_id}/{call_id}/{call_attempt_id}",
            get(http_call_session),
        )
        .route(
            "/v1/blocks/{device_id}",
            get(http_blocks_list).post(http_blocks_set),
        )
        // SUPPORT TICKETS (TZ 2026-07-24): user submits/polls (device-authed);
        // admin lists/replies (internal-key gated).
        .route("/v1/support", post(http_support_submit))
        .route("/v1/support/replies", get(http_support_replies))
        .route("/v1/support/admin/tickets", get(http_support_admin_tickets))
        .route("/v1/support/admin/reply", post(http_support_admin_reply))
        .route("/v1/support/admin/clear", post(http_support_admin_clear))
        // Sprint 2 R3: active-devices probe. Requester device_id signs
        // the request, target profile_id is the second path segment.
        .route(
            "/v1/active_devices/{device_id}/{profile_id}",
            get(http_active_devices),
        )
        .route("/v1/profile/delete", post(http_profile_delete))
        .route("/v1/push/{device_id}", post(http_push_token_set))
        .route(
            "/v1/sticker-catalog/manifest",
            get(http_sticker_catalog_manifest),
        )
        .route(
            "/v1/sticker-catalog/assets/{pack_id}/{pack_version}/{sticker_id}",
            get(http_sticker_catalog_asset),
        )
        .route("/v1/cosmetics/manifest", get(http_cosmetics_manifest))
        .route(
            "/v1/cosmetics/assets/{item_id}/{variant}",
            get(http_cosmetics_asset),
        )
        .route("/v1/blob/upload", post(http_blob_upload))
        .route("/v1/blob/{blob_id}", get(http_blob_get))
        .layer(DefaultBodyLimit::max(RELAY_HTTP_BODY_LIMIT_BYTES))
        .layer(middleware::from_fn_with_state(state.clone(), rate_limit))
        .with_state(state);

    tracing::info!(%addr, "starting relay service");

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("bind relay service");

    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .with_graceful_shutdown(shutdown_signal())
    .await
    .expect("serve relay service");
}

async fn shutdown_signal() {
    let _ = tokio::signal::ctrl_c().await;
    tracing::info!("shutdown signal received");
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{
        Json, Router,
        body::to_bytes,
        extract::{Path, Query, State},
        http::{HeaderMap, HeaderValue},
        response::IntoResponse,
        routing::get,
    };
    use ed25519_dalek::{Signer, SigningKey};
    use tempfile::TempDir;
    use tokio::{
        io::{AsyncRead, AsyncWrite},
        task::JoinHandle,
    };
    use tokio_tungstenite::{
        WebSocketStream, connect_async, tungstenite::Message as ClientWsMessage,
    };

    #[test]
    fn log_fingerprint_is_stable_and_redacted() {
        let first = log_fingerprint("device-12345");
        let second = log_fingerprint("device-12345");

        assert_eq!(first, second);
        assert!(first.starts_with("sha256:"));
        assert!(!first.contains("device-12345"));
    }

    #[test]
    fn compute_active_device_ids_drops_superseded_unconditionally() {
        // now must sit comfortably above the staleness threshold so a "stale"
        // timestamp stays positive.
        let now = DEVICE_STALENESS_THRESHOLD_MS * 100;
        let threshold = DEVICE_STALENESS_THRESHOLD_MS;
        let row = |id: &str, pump: i64, superseded: i64| DeviceActivityRow {
            device_id: id.into(),
            profile_id: "p".into(),
            last_pump_at_ms: pump,
            last_push_attempted_at_ms: 0,
            last_push_delivered_at_ms: 0,
            updated_at_ms: pump,
            superseded_at_ms: superseded,
        };

        // Filter OFF, no superseded → historical behaviour: full set, not applied.
        let (ids, applied) = compute_active_device_ids(
            vec![row("a", now, 0), row("b", now, 0)],
            false,
            now,
            threshold,
        );
        assert!(!applied);
        assert_eq!(ids.len(), 2);

        // Filter OFF, one superseded → drop it even though the global filter is
        // off; filter_applied=true so the client narrows.
        let (ids, applied) = compute_active_device_ids(
            vec![row("old", now, now), row("new", now, 0)],
            false,
            now,
            threshold,
        );
        assert!(applied);
        assert_eq!(ids, vec!["new".to_string()]);

        // Filter OFF, ONLY a superseded device → INV-1: return it unfiltered
        // rather than empty the fanout.
        let (ids, applied) =
            compute_active_device_ids(vec![row("old", now, now)], false, now, threshold);
        assert!(!applied);
        assert_eq!(ids, vec!["old".to_string()]);

        // Filter ON → drop superseded AND 30-day-silent, keep the fresh one.
        let stale = now - threshold - 1;
        let (ids, applied) = compute_active_device_ids(
            vec![
                row("old", now, now),
                row("silent", stale, 0),
                row("fresh", now, 0),
            ],
            true,
            now,
            threshold,
        );
        assert!(applied);
        assert_eq!(ids, vec!["fresh".to_string()]);

        // No devices → not applied, empty.
        let (ids, applied) = compute_active_device_ids(vec![], false, now, threshold);
        assert!(!applied);
        assert!(ids.is_empty());
    }

    #[test]
    fn log_body_summary_omits_raw_body() {
        let summary = log_body_summary("{\"token\":\"secret\"}");

        assert!(summary.starts_with("len="));
        assert!(summary.contains("ref=sha256:"));
        assert!(!summary.contains("secret"));
    }

    #[test]
    fn string_key_rate_limiter_exhausts_capacity_per_key() {
        // AUD-080: ensure per-slug limiter denies traffic after its
        // capacity is consumed and that a different slug is tracked
        // independently.
        let limiter = StringKeyRateLimiter::new(3, 0.0);
        assert!(limiter.allow("slug-a"));
        assert!(limiter.allow("slug-a"));
        assert!(limiter.allow("slug-a"));
        assert!(
            !limiter.allow("slug-a"),
            "exhausted slug bucket must deny further tokens"
        );
        assert!(
            limiter.allow("slug-b"),
            "distinct slugs must be isolated buckets"
        );
    }

    async fn test_app_state() -> (AppState, TempDir) {
        let dir = tempfile::tempdir().unwrap();
        let db_path = dir.path().join("relay.db");
        let blobs_dir = dir.path().join("blobs");
        let sticker_catalog_dir = dir.path().join("sticker_catalog");
        let cosmetics_dir = dir.path().join("cosmetics");
        tokio::fs::create_dir_all(&blobs_dir).await.unwrap();
        tokio::fs::create_dir_all(&sticker_catalog_dir)
            .await
            .unwrap();
        tokio::fs::create_dir_all(&cosmetics_dir).await.unwrap();

        let store = RelayStore::open(&db_path).await.unwrap();
        let state = AppState {
            store: Arc::new(store),
            conns: Arc::new(DashMap::new()),
            wake_coalesce: Arc::new(DashMap::new()),
            blobs_dir: Arc::new(blobs_dir),
            sticker_catalog_dir: Arc::new(sticker_catalog_dir),
            cosmetics_dir: Arc::new(cosmetics_dir),
            limiter: Arc::new(IpRateLimiter::new(10_000, 10_000.0)),
            invite_redeem_slug_limiter: Arc::new(StringKeyRateLimiter::new(10_000, 10_000.0)),
            invite_redeem_caller_limiter: Arc::new(StringKeyRateLimiter::new(10_000, 10_000.0)),
            max_msg_ttl_seconds: 7 * 24 * 3600,
            own_device_control_ttl_seconds: 0,
            max_pending_per_device: 5_000,
            keys_internal_base_url: Arc::new("http://127.0.0.1:1".into()),
            internal_key: Arc::new(String::new()),
            http: HttpClient::builder()
                .connect_timeout(Duration::from_secs(1))
                .timeout(Duration::from_secs(1))
                .build()
                .unwrap(),
            identity_cache: Arc::new(DashMap::new()),
            profile_cache: Arc::new(DashMap::new()),
            used_nonces: Arc::new(DashMap::new()),
            push_wake_last_ms: Arc::new(DashMap::new()),
            fcm_legacy_server_key: Arc::new(String::new()),
            fcm_v1: Arc::new(None),
            apns_voip: Arc::new(None),
            fcm_oauth_cache: Arc::new(Mutex::new(None)),
            apns_jwt_cache: Arc::new(Mutex::new(None)),
            call_ice: Arc::new(RelayCallIceRuntimeConfig {
                policy: "p2p_preferred".into(),
                stun_urls: Vec::new(),
                turn_urls: Vec::new(),
                turn_shared_secret: String::new(),
                turn_ttl_seconds: 600,
            }),
            room_media: Arc::new(RelayRoomMediaRuntimeConfig {
                requested_backend: RelayRoomMediaBackendKind::Unavailable,
                effective_backend: RelayRoomMediaBackendKind::Unavailable,
                livekit_url: String::new(),
                livekit_api_key: String::new(),
                livekit_api_secret: String::new(),
                token_ttl_seconds: 600,
            }),
            call_sessions: Arc::new(RelayCallSessionRuntimeConfig {
                active_ttl_seconds: 24 * 60 * 60,
                terminal_ttl_seconds: 15 * 60,
            }),
            require_auth: true,
            deployment_id: Arc::new(String::new()),
            release_channel: Arc::new(String::new()),
            service_started_at_ms: now_ms(),
            monetization_enabled: false,
            entitlement_cache: Arc::new(DashMap::new()),
            big_room_members: 0,
            big_room_min_build: 0,
        };

        (state, dir)
    }

    fn cache_authenticated_device(
        state: &AppState,
        device_id: &str,
        profile_id: &str,
        signing_key: &SigningKey,
    ) {
        state.identity_cache.insert(
            device_id.to_string(),
            base64::engine::general_purpose::STANDARD
                .encode(signing_key.verifying_key().to_bytes()),
        );
        state
            .profile_cache
            .insert(device_id.to_string(), profile_id.to_string());
    }

    // ── Monetization §C-3 relay enforcement ───────────────────────────────
    fn seed_entitlement(
        state: &AppState,
        profile_id: &str,
        owned_groups: i64,
        joined_groups: i64,
        group_members: i64,
        call_participants: i64,
    ) {
        state.entitlement_cache.insert(
            profile_id.to_string(),
            (
                now_ms(),
                RelayEntitlement {
                    owned_groups,
                    joined_groups,
                    group_members,
                    call_participants,
                    attachment_bytes: -1,
                },
            ),
        );
    }

    #[test]
    fn over_limit_treats_negative_as_unlimited() {
        assert!(!over_limit(0, 5));
        assert!(!over_limit(4, 5));
        assert!(over_limit(5, 5));
        assert!(over_limit(6, 5));
        // Negative = unlimited.
        assert!(!over_limit(1_000_000, -1));
        // A zero limit allows nothing (count 0 is already at/over).
        assert!(over_limit(0, 0));
    }

    #[tokio::test]
    async fn relay_group_create_limit_blocks_over_owned_cap() {
        let (base, _dir) = test_app_state().await;
        let state = AppState {
            monetization_enabled: true,
            ..base
        };
        let pid = "profile_mon_create_1";
        seed_entitlement(&state, pid, 2, 20, 50, 8);

        // Under cap: 0 then 1 owned room → allowed.
        assert!(enforce_group_create_limit(&state, pid).await.is_ok());
        state
            .store
            .create_room("room_mon_1", pid, "dev_mon_1", "A", now_ms())
            .await
            .unwrap();
        assert!(enforce_group_create_limit(&state, pid).await.is_ok());
        state
            .store
            .create_room("room_mon_2", pid, "dev_mon_1", "B", now_ms())
            .await
            .unwrap();
        // Now at cap (2) → 3rd create blocked.
        let err = enforce_group_create_limit(&state, pid).await.unwrap_err();
        assert_eq!(err.0, StatusCode::PAYMENT_REQUIRED);
    }

    #[tokio::test]
    async fn relay_group_create_unlimited_when_negative_limit() {
        let (base, _dir) = test_app_state().await;
        let state = AppState {
            monetization_enabled: true,
            ..base
        };
        let pid = "profile_mon_unl_1";
        seed_entitlement(&state, pid, -1, -1, 500, 50);
        for i in 0..5 {
            state
                .store
                .create_room(&format!("room_unl_{i}"), pid, "dev_unl_1", "x", now_ms())
                .await
                .unwrap();
        }
        assert!(enforce_group_create_limit(&state, pid).await.is_ok());
    }

    #[tokio::test]
    async fn relay_create_failopen_when_monetization_disabled() {
        let (state, _dir) = test_app_state().await; // monetization_enabled = false
        let pid = "profile_mon_off_1";
        // Even a 0 cap in cache is ignored because the flag is off.
        seed_entitlement(&state, pid, 0, 0, 0, 0);
        state
            .store
            .create_room("room_off_1", pid, "dev_off_1", "x", now_ms())
            .await
            .unwrap();
        assert!(enforce_group_create_limit(&state, pid).await.is_ok());
    }

    #[tokio::test]
    async fn relay_create_failopen_when_entitlement_unresolved() {
        let (base, _dir) = test_app_state().await;
        let state = AppState {
            monetization_enabled: true,
            ..base
        };
        // No cache entry + no reachable keys server → fetch returns None → allow.
        let pid = "profile_mon_noent_1";
        state
            .store
            .create_room("room_noent_1", pid, "dev_noent_1", "x", now_ms())
            .await
            .unwrap();
        assert!(enforce_group_create_limit(&state, pid).await.is_ok());
    }

    #[tokio::test]
    async fn relay_group_join_limit_blocks_over_cap() {
        let (base, _dir) = test_app_state().await;
        let state = AppState {
            monetization_enabled: true,
            ..base
        };
        let pid = "profile_mon_join_1";
        seed_entitlement(&state, pid, 5, 1, 50, 8);
        // Create a room (so memberships can attach) and add an active membership.
        state
            .store
            .create_room("room_join_a", "owner_x", "dev_owner_x", "A", now_ms())
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership("room_join_a", pid, "active", "member", None, now_ms())
            .await
            .unwrap();
        // Now joined = 1 = cap → next join blocked.
        let err = enforce_group_join_limit(&state, pid).await.unwrap_err();
        assert_eq!(err.0, StatusCode::PAYMENT_REQUIRED);
    }

    #[tokio::test]
    async fn relay_group_size_limit_blocks_over_cap() {
        let (base, _dir) = test_app_state().await;
        let state = AppState {
            monetization_enabled: true,
            ..base
        };
        let owner = "owner_size_1";
        seed_entitlement(&state, owner, 5, 20, 2, 8);
        state
            .store
            .create_room("room_size_1", owner, "dev_owner_size_1", "A", now_ms())
            .await
            .unwrap();
        // Add two active members → reaches cap of 2.
        state
            .store
            .upsert_room_membership("room_size_1", "m1", "active", "member", None, now_ms())
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership("room_size_1", "m2", "active", "member", None, now_ms())
            .await
            .unwrap();
        let err = enforce_group_size_limit(&state, owner, "room_size_1", "m3")
            .await
            .unwrap_err();
        assert_eq!(err.0, StatusCode::PAYMENT_REQUIRED);
    }

    #[test]
    fn client_build_number_is_parsed_or_treated_as_oldest() {
        assert_eq!(store::parse_client_build("588"), 588);
        assert_eq!(store::parse_client_build(" 1.8.39+588 "), 588);
        assert_eq!(store::parse_client_build(""), 0);
        assert_eq!(store::parse_client_build("dev"), 0);
    }

    #[tokio::test]
    async fn big_room_grows_past_the_tier_cap_only_on_new_builds() {
        // К-5: the tier cap (2 here) may be exceeded up to `big_room_members`,
        // but only while every live device of the members and of the newcomer
        // runs `big_room_min_build` or newer.
        let (base, _dir) = test_app_state().await;
        let state = AppState {
            monetization_enabled: true,
            big_room_members: 4,
            big_room_min_build: 600,
            ..base
        };
        let owner = "owner_big_1";
        let room = "room_big_1";
        seed_entitlement(&state, owner, 5, 20, 2, 8);
        state
            .store
            .create_room(room, owner, "dev_owner_big_1", "Big", now_ms())
            .await
            .unwrap();
        let add_device = |pid: &'static str, did: &'static str, build: &'static str| {
            let store = state.store.clone();
            async move {
                store
                    .record_device_login(did, Some(pid), now_ms())
                    .await
                    .unwrap();
                store
                    .device_activity_set_client_build(did, build, now_ms())
                    .await
                    .unwrap();
            }
        };
        for (pid, did) in [(owner, "dev_owner_big_1"), ("mb1", "dev_mb1")] {
            add_device(pid, did, "600").await;
        }
        state
            .store
            .upsert_room_membership(room, owner, "active", "owner", None, now_ms())
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(room, "mb1", "active", "member", None, now_ms())
            .await
            .unwrap();
        let active = state.store.count_active_room_members(room).await.unwrap();
        assert!(active >= 2, "room must be at the tier cap for this test");

        add_device("mb_new", "dev_mb_new", "601").await;
        enforce_group_size_limit(&state, owner, room, "mb_new")
            .await
            .expect("all devices are new: the big-room exception applies");

        add_device("mb_old", "dev_mb_old", "588").await;
        let err = enforce_group_size_limit(&state, owner, room, "mb_old")
            .await
            .unwrap_err();
        assert_eq!(err.0, StatusCode::PAYMENT_REQUIRED);

        // A dead phone that peers only keep pushing to is not a live device…
        let long_ago = now_ms() - BIG_ROOM_DEVICE_ACTIVE_WINDOW_MS - 60_000;
        state
            .store
            .record_device_login("dev_mb1_dead_phone", Some("mb1"), long_ago)
            .await
            .unwrap();
        state
            .store
            .device_activity_set_client_build("dev_mb1_dead_phone", "556", long_ago)
            .await
            .unwrap();
        state
            .store
            .record_push_attempted("dev_mb1_dead_phone", now_ms())
            .await
            .unwrap();
        enforce_group_size_limit(&state, owner, room, "mb_new")
            .await
            .expect("push attempts alone must not keep an old device alive");
        // …but a delivered push means the old phone is still out there.
        state
            .store
            .record_push_delivered("dev_mb1_dead_phone", now_ms())
            .await
            .unwrap();
        assert!(
            enforce_group_size_limit(&state, owner, room, "mb_new")
                .await
                .is_err()
        );

        // An old device of an existing member closes the exception for everyone.
        add_device("mb1", "dev_mb1_old_tablet", "").await;
        assert!(
            enforce_group_size_limit(&state, owner, room, "mb_new")
                .await
                .is_err()
        );

        // The exception is off without both settings.
        let off = AppState {
            big_room_min_build: 0,
            ..state.clone()
        };
        assert!(
            enforce_group_size_limit(&off, owner, room, "mb_new")
                .await
                .is_err()
        );
    }

    #[test]
    fn room_broadcast_auth_message_is_byte_stable() {
        // К-2: the Dart `AuthSigner.relayHttpRoomBroadcastMessage` pins the
        // same text; a mismatch turns every broadcast into a 401.
        let msg = http_room_broadcast_auth_message(
            "dev-s",
            "group:r",
            "m-1",
            "QUJD",
            &["dev-b".to_string(), "dev-a".to_string()],
            None,
            604800,
            0,
            42,
            "bm9uY2U=",
        );
        assert_eq!(
            String::from_utf8(msg).unwrap(),
            "SECRETLY-RELAY-ROOM-BROADCAST-V1\nfrom_device_id=dev-s\nroom_id=group:r\nmsg_id=m-1\nciphertext_sha256_b64=2crg29vweLICDiq+X810vB7bqDw19riobWOO2bjT0fk=\nrecipients_sha256_b64=8x4SK7ZypzL/R9bqWpL2Ise2VFWcxUwqPanRpcxjwgI=\nttl_seconds=604800\ndeliver_at_ms=0\ntransport_meta_json=\nts_ms=42\nnonce_b64=bm9uY2U=\n"
        );
    }

    #[tokio::test]
    async fn room_broadcast_queues_one_sealed_row_for_member_devices_only() {
        // К-2: one upload, one row per accepted device, the authenticated sender
        // attached; strangers, the sender itself and bad ids are reported back.
        let (state, _dir) = test_app_state().await;
        let sender_key = SigningKey::from_bytes(&[101u8; 32]);
        let member_key = SigningKey::from_bytes(&[102u8; 32]);
        let stranger_key = SigningKey::from_bytes(&[103u8; 32]);
        let room_id = "room_broadcast_1";
        cache_authenticated_device(&state, "dev_bc_sender", "pid_bc_sender", &sender_key);
        cache_authenticated_device(&state, "dev_bc_member", "pid_bc_member", &member_key);
        cache_authenticated_device(&state, "dev_bc_stranger", "pid_bc_stranger", &stranger_key);
        state
            .store
            .create_room(room_id, "pid_bc_sender", "dev_bc_sender", "Room", now_ms())
            .await
            .unwrap();
        // The creator is already the active owner.
        state
            .store
            .upsert_room_membership(room_id, "pid_bc_member", "active", "member", None, now_ms())
            .await
            .unwrap();
        let msg_id = "00000000-0000-0000-0000-00000000bc01".to_string();
        let recipients: Vec<String> = [
            "dev_bc_member",
            "dev_bc_stranger",
            "dev_bc_sender",
            "dev_unknown_x",
        ]
        .iter()
        .map(|v| v.to_string())
        .collect();
        let headers = signed_auth_headers(
            "dev_bc_sender",
            &sender_key,
            "broadcast-1",
            |ts_ms, nonce_b64| {
                http_room_broadcast_auth_message(
                    "dev_bc_sender",
                    room_id,
                    &msg_id,
                    "QUJD",
                    &recipients,
                    None,
                    60,
                    0,
                    ts_ms,
                    nonce_b64,
                )
            },
        );
        let resp = http_room_broadcast(
            Path(room_id.to_string()),
            State(state.clone()),
            headers,
            Json(HttpRoomBroadcastReq {
                msg_id: msg_id.clone(),
                ciphertext_b64: "QUJD".into(),
                recipients: recipients.clone(),
                ttl_seconds: 60,
                transport_meta_json: None,
                deliver_at_ms: None,
            }),
        )
        .await
        .unwrap()
        .0;
        assert_eq!(resp.accepted, vec!["dev_bc_member".to_string()]);
        let reasons: Vec<(&str, &str)> = resp
            .rejected
            .iter()
            .map(|r| (r.device_id.as_str(), r.reason))
            .collect();
        assert!(reasons.contains(&("dev_bc_stranger", "not_member")));
        assert!(reasons.contains(&("dev_bc_sender", "self")));
        assert!(reasons.contains(&("dev_unknown_x", "unknown_device")));
        let rows = state
            .store
            .list_pending_from("dev_bc_member", 1, now_ms(), 10)
            .await
            .unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].from_device_id.as_deref(), Some("dev_bc_sender"));
        assert!(
            state
                .store
                .list_pending_from("dev_bc_stranger", 1, now_ms(), 10)
                .await
                .unwrap()
                .is_empty()
        );

        // A non-member may not broadcast at all.
        let headers = signed_auth_headers(
            "dev_bc_stranger",
            &stranger_key,
            "broadcast-2",
            |ts_ms, nonce_b64| {
                http_room_broadcast_auth_message(
                    "dev_bc_stranger",
                    room_id,
                    &msg_id,
                    "QUJD",
                    &recipients,
                    None,
                    60,
                    0,
                    ts_ms,
                    nonce_b64,
                )
            },
        );
        let err = http_room_broadcast(
            Path(room_id.to_string()),
            State(state.clone()),
            headers,
            Json(HttpRoomBroadcastReq {
                msg_id,
                ciphertext_b64: "QUJD".into(),
                recipients,
                ttl_seconds: 60,
                transport_meta_json: None,
                deliver_at_ms: None,
            }),
        )
        .await
        .unwrap_err();
        assert_eq!(err.0, StatusCode::FORBIDDEN);
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
    async fn http_sticker_catalog_manifest_returns_detached_signature_header() {
        let (state, _dir) = test_app_state().await;
        let manifest_raw = r#"{"schema_version":1,"generated_at_ms":123,"packs":[{"pack_id":"studio_pack","pack_version":1,"title":"Studio","description":"Design pack","icon_sticker_id":"studio_palette","icon_emoji_hint":"🎨","featured_rank":7,"tags":["remote","design"],"stickers":[{"sticker_id":"studio_palette","file_name":"studio_palette.png","format":"png","animated":false,"emoji_hint":"🎨","label":"Palette","keywords":["palette","design"],"sha256_b64":"aGFzaA==","size_bytes":128}]}]}"#;
        let signature_b64 = "uWlnkhaHWYYCObofT1BqFvt4n4ArOYy4WllmhYHT8dE9EodxVxTS7pqGjTmY1aX4W/b0eBCzuER4Lv3nZryQCg==";
        tokio::fs::write(state.sticker_catalog_dir.join("catalog.json"), manifest_raw)
            .await
            .unwrap();
        tokio::fs::write(state.sticker_catalog_dir.join("catalog.sig"), signature_b64)
            .await
            .unwrap();

        let response = http_sticker_catalog_manifest(State(state))
            .await
            .unwrap()
            .into_response();

        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(
            response
                .headers()
                .get(STICKER_CATALOG_SIGNATURE_HEADER)
                .unwrap()
                .to_str()
                .unwrap(),
            signature_b64,
        );
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        assert_eq!(body.as_ref(), manifest_raw.as_bytes());
    }

    #[tokio::test]
    async fn http_sticker_catalog_manifest_rejects_invalid_signature() {
        let (state, _dir) = test_app_state().await;
        tokio::fs::write(
            state.sticker_catalog_dir.join("catalog.json"),
            r#"{"schema_version":1,"generated_at_ms":0,"packs":[]}"#,
        )
        .await
        .unwrap();
        tokio::fs::write(
            state.sticker_catalog_dir.join("catalog.sig"),
            "bad-signature",
        )
        .await
        .unwrap();

        let error = match http_sticker_catalog_manifest(State(state)).await {
            Ok(_) => panic!("expected invalid signature error"),
            Err(error) => error,
        };
        assert_eq!(error.0, StatusCode::INTERNAL_SERVER_ERROR);
        assert!(error.1.contains("invalid sticker catalog signature"));
    }

    async fn insert_blob_fixture(
        state: &AppState,
        blob_id: &str,
        owner_device_id: &str,
        owner_profile_id: &str,
        access_token_b64: Option<&str>,
        body: &[u8],
        expires_at_ms: i64,
    ) {
        let rel_path = format!("{blob_id}.bin");
        tokio::fs::write(state.blobs_dir.join(&rel_path), body)
            .await
            .unwrap();
        let access_token_sha256_b64 = access_token_b64
            .map(|token| blob_access_token_hash_b64(token).unwrap())
            .unwrap_or_default();
        state
            .store
            .blob_insert(
                blob_id,
                &rel_path,
                body.len() as u64,
                expires_at_ms,
                now_ms(),
                owner_device_id,
                owner_profile_id,
                &access_token_sha256_b64,
            )
            .await
            .unwrap();
    }

    fn signed_blob_get_headers(
        device_id: &str,
        signing_key: &SigningKey,
        blob_id: &str,
        access_token_b64: Option<&str>,
        nonce_seed: &str,
    ) -> HeaderMap {
        let ts_ms = now_ms();
        let nonce_b64 = base64::engine::general_purpose::STANDARD.encode(nonce_seed.as_bytes());
        let access_token_sha256_b64 =
            access_token_b64.map(|token| blob_access_token_hash_b64(token).unwrap());
        let auth_message = http_blob_get_auth_message(
            device_id,
            blob_id,
            access_token_sha256_b64.as_deref(),
            ts_ms,
            &nonce_b64,
        );
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
        if let Some(token) = access_token_b64 {
            headers.insert(
                "x-secretly-blob-access-token-b64",
                HeaderValue::from_str(token).unwrap(),
            );
        }
        headers
    }

    fn signed_room_create_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        title: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_create_auth_message(device_id, room_id, title, ts_ms, nonce_b64)
        })
    }

    fn signed_room_get_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_get_auth_message(device_id, room_id, ts_ms, nonce_b64)
        })
    }

    fn signed_room_profile_update_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        req: &HttpRoomProfileUpdateReq,
        nonce_seed: &str,
    ) -> HeaderMap {
        let title = req.title.trim();
        let description = req
            .description
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty());
        let avatar_hash = req
            .avatar_hash
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty());
        let avatar_image_b64 = req
            .avatar_image_b64
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty());

        let clear_avatar = req.clear_avatar;

        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_profile_update_auth_message(
                device_id,
                room_id,
                title,
                description,
                avatar_hash,
                avatar_image_b64,
                clear_avatar,
                ts_ms,
                nonce_b64,
            )
        })
    }

    fn signed_room_message_admission_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        message_id: &str,
        kind: HttpRoomMessageKind,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_message_admission_auth_message(
                device_id,
                room_id,
                message_id,
                kind.as_str(),
                ts_ms,
                nonce_b64,
            )
        })
    }

    fn signed_room_settings_update_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        req: &HttpRoomSettingsUpdateReq,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_settings_update_auth_message(
                device_id,
                room_id,
                &req.reactions_mode,
                req.allow_text,
                req.allow_media,
                req.allow_add_members,
                req.allow_pin_messages,
                req.allow_change_group_info,
                req.allow_change_tag,
                req.join_approval_required,
                req.slow_mode_seconds,
                req.chat_history_visible,
                ts_ms,
                nonce_b64,
            )
        })
    }

    fn signed_room_pinned_message_set_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        message_id: Option<&str>,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_pinned_message_set_auth_message(
                device_id, room_id, message_id, ts_ms, nonce_b64,
            )
        })
    }

    fn signed_room_member_tag_set_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        tag: Option<&str>,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_member_tag_set_auth_message(device_id, room_id, tag, ts_ms, nonce_b64)
        })
    }

    fn signed_room_members_list_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_members_list_auth_message(device_id, room_id, ts_ms, nonce_b64)
        })
    }

    fn signed_room_members_upsert_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        profile_id: &str,
        status: HttpRoomMembershipStatus,
        role: HttpRoomMemberRole,
        source_link_id: Option<&str>,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_members_upsert_auth_message(
                device_id,
                room_id,
                profile_id,
                status.as_str(),
                role.as_str(),
                source_link_id,
                ts_ms,
                nonce_b64,
            )
        })
    }

    fn signed_room_member_unban_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        profile_id: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_member_unban_auth_message(device_id, room_id, profile_id, ts_ms, nonce_b64)
        })
    }

    fn signed_room_leave_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_leave_auth_message(device_id, room_id, ts_ms, nonce_b64)
        })
    }

    fn signed_room_delete_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_delete_auth_message(device_id, room_id, ts_ms, nonce_b64)
        })
    }

    fn signed_room_call_get_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_call_get_auth_message(device_id, room_id, ts_ms, nonce_b64)
        })
    }

    fn signed_room_call_join_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        req: &HttpRoomCallJoinReq,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_call_join_auth_message(
                device_id,
                room_id,
                req.media_type.as_str(),
                req.supports_video,
                req.supports_screen_share,
                req.muted,
                req.deafened,
                req.video_enabled,
                req.screen_share_enabled,
                ts_ms,
                nonce_b64,
            )
        })
    }

    fn signed_room_call_self_update_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        call_id: &str,
        req: &HttpRoomCallParticipantUpdateReq,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_call_self_update_auth_message(
                device_id,
                room_id,
                call_id,
                req.reconnecting,
                req.muted,
                req.deafened,
                req.video_enabled,
                req.screen_share_enabled,
                req.speaking,
                ts_ms,
                nonce_b64,
            )
        })
    }

    fn signed_room_call_leave_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        call_id: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_call_leave_auth_message(device_id, room_id, call_id, ts_ms, nonce_b64)
        })
    }

    fn signed_room_call_participant_remove_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        call_id: &str,
        participant_device_id: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_call_participant_remove_auth_message(
                device_id,
                room_id,
                call_id,
                participant_device_id,
                ts_ms,
                nonce_b64,
            )
        })
    }

    fn signed_room_call_end_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        call_id: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_call_end_auth_message(device_id, room_id, call_id, ts_ms, nonce_b64)
        })
    }

    fn signed_room_call_media_get_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        call_id: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_call_media_get_auth_message(device_id, room_id, call_id, ts_ms, nonce_b64)
        })
    }

    fn signed_room_call_media_join_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        call_id: &str,
        req: &HttpRoomCallMediaJoinReq,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_call_media_join_auth_message(
                device_id,
                room_id,
                call_id,
                req.publish_audio,
                req.publish_video,
                req.publish_screen_share,
                req.subscribe_all,
                ts_ms,
                nonce_b64,
            )
        })
    }

    fn signed_room_transfer_ownership_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        next_owner_profile_id: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_transfer_ownership_auth_message(
                device_id,
                room_id,
                next_owner_profile_id,
                ts_ms,
                nonce_b64,
            )
        })
    }

    fn signed_room_invite_links_list_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_invite_links_list_auth_message(device_id, room_id, ts_ms, nonce_b64)
        })
    }

    fn signed_room_invite_links_create_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        expires_at_ms: Option<i64>,
        max_uses: Option<i64>,
        requires_approval: bool,
        allowed_role: HttpRoomMemberRole,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_invite_links_create_auth_message(
                device_id,
                room_id,
                expires_at_ms,
                max_uses,
                requires_approval,
                allowed_role.as_str(),
                ts_ms,
                nonce_b64,
            )
        })
    }

    fn signed_room_invite_link_revoke_headers(
        device_id: &str,
        signing_key: &SigningKey,
        room_id: &str,
        link_id: &str,
        revoked: bool,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_invite_link_revoke_auth_message(
                device_id, room_id, link_id, revoked, ts_ms, nonce_b64,
            )
        })
    }

    fn signed_room_invite_preview_headers(
        device_id: &str,
        signing_key: &SigningKey,
        slug: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_invite_preview_auth_message(device_id, slug, ts_ms, nonce_b64)
        })
    }

    fn signed_room_invite_redeem_headers(
        device_id: &str,
        signing_key: &SigningKey,
        slug: &str,
        nonce_seed: &str,
    ) -> HeaderMap {
        signed_auth_headers(device_id, signing_key, nonce_seed, |ts_ms, nonce_b64| {
            http_room_invite_redeem_auth_message(device_id, slug, ts_ms, nonce_b64)
        })
    }

    async fn start_test_ws_server(state: AppState) -> (String, JoinHandle<()>) {
        let app = Router::new()
            .route("/ws", get(ws_handler))
            .with_state(state);
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let handle = tokio::spawn(async move {
            axum::serve(listener, app).await.unwrap();
        });
        (format!("ws://{addr}/ws"), handle)
    }

    fn signed_ws_hello_text(device_id: &str, signing_key: &SigningKey, nonce_seed: &str) -> String {
        let ts_ms = now_ms();
        let nonce_b64 = base64::engine::general_purpose::STANDARD.encode(nonce_seed.as_bytes());
        let auth_message = hello_auth_message(device_id, ts_ms, &nonce_b64);
        let signature_b64 = base64::engine::general_purpose::STANDARD
            .encode(signing_key.sign(&auth_message).to_bytes());
        serde_json::to_string(&ClientMsg::HelloAuth {
            device_id: device_id.to_string(),
            ts_ms,
            nonce_b64,
            signature_b64,
            client_build: None,
        })
        .unwrap()
    }

    /// То же приветствие, но с названной сборкой — для замера раскатки.
    fn signed_ws_hello_text_with_build(
        device_id: &str,
        signing_key: &SigningKey,
        nonce_seed: &str,
        client_build: &str,
    ) -> String {
        let ts_ms = now_ms();
        let nonce_b64 = base64::engine::general_purpose::STANDARD.encode(nonce_seed.as_bytes());
        let auth_message = hello_auth_message(device_id, ts_ms, &nonce_b64);
        let signature_b64 = base64::engine::general_purpose::STANDARD
            .encode(signing_key.sign(&auth_message).to_bytes());
        serde_json::to_string(&ClientMsg::HelloAuth {
            device_id: device_id.to_string(),
            ts_ms,
            nonce_b64,
            signature_b64,
            client_build: Some(client_build.to_string()),
        })
        .unwrap()
    }

    async fn recv_ws_server_msg<S>(socket: &mut WebSocketStream<S>) -> ServerMsg
    where
        S: AsyncRead + AsyncWrite + Unpin,
    {
        let message = socket
            .next()
            .await
            .expect("expected websocket message")
            .expect("expected successful websocket frame");
        match message {
            ClientWsMessage::Text(text) => serde_json::from_str(text.as_ref()).unwrap(),
            other => panic!("expected text websocket message, got {other:?}"),
        }
    }

    async fn expect_ws_welcome<S>(socket: &mut WebSocketStream<S>, device_id: &str, next_seq: u64)
    where
        S: AsyncRead + AsyncWrite + Unpin,
    {
        match recv_ws_server_msg(socket).await {
            ServerMsg::Welcome {
                device_id: welcome_device_id,
                next_seq: welcome_next_seq,
            } => {
                assert_eq!(welcome_device_id, device_id);
                assert_eq!(welcome_next_seq, next_seq);
            }
            other => panic!("expected welcome message, got {other:?}"),
        }
    }

    async fn wait_until_pending_absent(state: &AppState, device_id: &str, msg_id: &str) {
        for _ in 0..20 {
            if !state
                .store
                .has_pending_msg(device_id, msg_id, now_ms())
                .await
                .unwrap()
            {
                return;
            }
            tokio::task::yield_now().await;
        }

        panic!("expected pending message {msg_id} for {device_id} to be removed");
    }

    #[tokio::test]
    async fn build_push_wake_payload_includes_room_call_metadata() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[71u8; 32]);
        let target_key = SigningKey::from_bytes(&[72u8; 32]);
        cache_authenticated_device(&state, "owner_device_push_1", "owner_push_1", &owner_key);
        cache_authenticated_device(
            &state,
            "target_device_push_1",
            "target_profile_push_1",
            &target_key,
        );
        state
            .store
            .create_room(
                "room_alpha_push_1",
                "owner_push_1",
                "owner_device_push_1",
                "Incident Bridge",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                "room_alpha_push_1",
                "target_profile_push_1",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_1",
            Some("owner_device_push_1"),
            Some("msg_push_1"),
            Some(
                r#"{"kind":"room_call_sync_v1","room_call":{"room_id":"room_alpha_push_1","call_id":"call_push_1","call_exists":true,"state_version":7,"created_at_ms":12345}}"#,
            ),
            None,
        false,
    )
        .await;

        assert_eq!(payload.notification_title, "Secretly");
        assert_eq!(payload.notification_body, "Room call activity");
        assert_eq!(payload.notification_tag, "room_alpha_push_1");
        assert!(payload.include_notification);
        assert_eq!(
            payload
                .data
                .get("wake_kind")
                .and_then(|value| value.as_str()),
            Some("room_call_sync_v1")
        );
        assert_eq!(
            payload.data.get("room_id").and_then(|value| value.as_str()),
            Some("room_alpha_push_1")
        );
        assert_eq!(
            payload.data.get("call_id").and_then(|value| value.as_str()),
            Some("call_push_1")
        );
        assert_eq!(
            payload
                .data
                .get("state_version")
                .and_then(|value| value.as_str()),
            Some("7")
        );
    }

    /// A stranded backlog may be announced ONCE, and only when nobody was ever
    /// told about it.
    ///
    /// The ladder re-wakes the same mailbox every 10 min, then every 30 min for
    /// hours. Announcing on each pass is what users reported on 2026-07-30: a
    /// "Secretly — New message" banner every half hour about messages they had
    /// already read. Announcing on NONE of them would be worse in one specific
    /// case — a killed iOS app, which a silent data push may not even launch —
    /// so the one attempt that follows a backlog nobody was told about keeps its
    /// banner.
    #[test]
    fn offline_rewake_announces_once_for_a_backlog_nobody_was_told_about() {
        // The push at send time never went out: the last attempt predates the
        // backlog. Nobody has ever been told → announce.
        assert!(offline_rewake_should_announce(1_000, 500));
        assert!(offline_rewake_should_announce(1_000, 0));

        // Having announced stamps the attempt past the backlog, so every later
        // pass on the very same backlog is silent. This is the harassment fix.
        assert!(!offline_rewake_should_announce(1_000, 1_001));
        assert!(!offline_rewake_should_announce(1_000, 9_999));

        // A device that keeps receiving pushes for NEW messages is silent here
        // too: those messages alerted the user themselves.
        assert!(!offline_rewake_should_announce(1_000, 1_000));
    }

    /// A bare device-level wake — no message, no transport metadata — must not
    /// announce anything.
    ///
    /// `include_notification` DEFAULTS to true and the body defaults to "New
    /// message"; every branch that turns it off needs metadata to parse. So a
    /// metadata-less wake used to go out as a real "Secretly — New message"
    /// banner. The offline re-wake ladder sends exactly such a wake every 10 min
    /// for a fresh stranded mailbox and every 30 MIN once the backlog is half an
    /// hour old — which is how one already-read message produced a notification
    /// every half hour, for hours (field reports 2026-07-30).
    #[tokio::test]
    async fn build_push_wake_payload_silent_wake_never_announces_anything() {
        let (state, _dir) = test_app_state().await;

        let payload = build_push_wake_payload(
            &state,
            "target_device_silent_wake_1",
            None,
            None,
            None,
            None,
            true,
        )
        .await;

        assert!(
            !payload.include_notification,
            "a wake about no message must never raise a banner"
        );

        // The SAME call without the flag is what used to ship — proof that the
        // flag is what makes the difference, not some other guard.
        let loud = build_push_wake_payload(
            &state,
            "target_device_silent_wake_1",
            None,
            None,
            None,
            None,
            false,
        )
        .await;
        assert!(loud.include_notification);
        assert_eq!(loud.notification_body, "New message");
    }

    /// A silent wake must still WAKE the device — that is its whole purpose.
    /// Removing the banner must not remove the data the client needs to drain,
    /// and it must leave the icon badge alone.
    #[tokio::test]
    async fn build_push_wake_payload_silent_wake_wakes_without_touching_the_icon() {
        let (state, _dir) = test_app_state().await;

        let payload = build_push_wake_payload(
            &state,
            "target_device_silent_wake_2",
            None,
            None,
            None,
            None,
            true,
        )
        .await;

        assert_eq!(
            payload.data.get("type").and_then(|v| v.as_str()),
            Some("relay_pending"),
            "the device still has to be told to come and drain"
        );
        assert_eq!(
            payload.data.get("device_id").and_then(|v| v.as_str()),
            Some("target_device_silent_wake_2")
        );
        // The count it would carry is UNDELIVERED MAILBOX ROWS, not unread
        // messages: a stranded mailbox keeps that number forever, and stamping
        // it on every re-wake overwrote the true zero the running client had
        // just set — the "51 unread and I have read everything" report.
        assert_eq!(
            payload.badge, None,
            "a silent re-wake must leave the app-icon badge exactly as it is"
        );
    }

    #[tokio::test]
    async fn build_push_wake_payload_maps_room_media_signal_to_room_call_hint() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[73u8; 32]);
        let target_key = SigningKey::from_bytes(&[74u8; 32]);
        cache_authenticated_device(
            &state,
            "owner_device_push_media_1",
            "owner_push_media_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "target_device_push_media_1",
            "target_profile_push_media_1",
            &target_key,
        );
        state
            .store
            .create_room(
                "room_alpha_push_media_1",
                "owner_push_media_1",
                "owner_device_push_media_1",
                "Media Bridge",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                "room_alpha_push_media_1",
                "target_profile_push_media_1",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_media_1",
            Some("owner_device_push_media_1"),
            Some("msg_push_media_1"),
            Some(
                r#"{"kind":"room_call_media_signal_v1","room_media_signal":{"action":"descriptor_updated","room_id":"room_alpha_push_media_1","call_id":"call_push_media_1","session_id":"call_push_media_1","descriptor_version":17,"state_version":9,"signal_id":"sig_push_media_1","created_at_ms":12346}}"#,
            ),
            None,
        false,
    )
        .await;

        assert_eq!(payload.notification_title, "Secretly");
        assert_eq!(payload.notification_body, "Room media update");
        assert_eq!(
            payload
                .data
                .get("wake_kind")
                .and_then(|value| value.as_str()),
            Some("room_call_sync_v1")
        );
        assert_eq!(
            payload.data.get("room_id").and_then(|value| value.as_str()),
            Some("room_alpha_push_media_1")
        );
        assert_eq!(
            payload.data.get("call_id").and_then(|value| value.as_str()),
            Some("call_push_media_1")
        );
        assert_eq!(
            payload
                .data
                .get("descriptor_version")
                .and_then(|value| value.as_str()),
            Some("17")
        );
    }

    #[tokio::test]
    async fn build_push_wake_payload_drops_unverified_room_call_room_id() {
        let (state, _dir) = test_app_state().await;
        let sender_key = SigningKey::from_bytes(&[75u8; 32]);
        let target_key = SigningKey::from_bytes(&[76u8; 32]);
        cache_authenticated_device(
            &state,
            "sender_device_push_room_spoof_1",
            "sender_profile_push_room_spoof_1",
            &sender_key,
        );
        cache_authenticated_device(
            &state,
            "target_device_push_room_spoof_1",
            "target_profile_push_room_spoof_1",
            &target_key,
        );

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_room_spoof_1",
            Some("sender_device_push_room_spoof_1"),
            Some("msg_push_room_spoof_1"),
            Some(
                r#"{"kind":"room_call_sync_v1","room_call":{"room_id":"room_alpha_push_spoof_1","call_id":"call_push_spoof_1","call_exists":true,"state_version":7,"created_at_ms":12345}}"#,
            ),
            None,
        false,
    )
        .await;

        assert_eq!(payload.notification_title, "Secretly");
        assert_eq!(payload.notification_body, "New message");
        assert_eq!(payload.notification_tag, "msg_push_room_spoof_1");
        assert!(payload.data.get("wake_kind").is_none());
        assert!(payload.data.get("room_id").is_none());
        assert!(payload.data.get("convo_id").is_none());
    }

    #[tokio::test]
    async fn build_push_wake_payload_drops_unverified_room_media_room_id() {
        let (state, _dir) = test_app_state().await;
        let sender_key = SigningKey::from_bytes(&[77u8; 32]);
        let target_key = SigningKey::from_bytes(&[78u8; 32]);
        cache_authenticated_device(
            &state,
            "sender_device_push_media_spoof_1",
            "sender_profile_push_media_spoof_1",
            &sender_key,
        );
        cache_authenticated_device(
            &state,
            "target_device_push_media_spoof_1",
            "target_profile_push_media_spoof_1",
            &target_key,
        );

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_media_spoof_1",
            Some("sender_device_push_media_spoof_1"),
            Some("msg_push_media_spoof_1"),
            Some(
                r#"{"kind":"room_call_media_signal_v1","room_media_signal":{"action":"descriptor_updated","room_id":"room_alpha_push_media_spoof_1","call_id":"call_push_media_spoof_1","session_id":"call_push_media_spoof_1","descriptor_version":17,"state_version":9,"signal_id":"sig_push_media_spoof_1","created_at_ms":12346}}"#,
            ),
            None,
        false,
    )
        .await;

        assert_eq!(payload.notification_title, "Secretly");
        assert_eq!(payload.notification_body, "New message");
        assert_eq!(payload.notification_tag, "msg_push_media_spoof_1");
        assert!(payload.data.get("wake_kind").is_none());
        assert!(payload.data.get("room_id").is_none());
        assert!(payload.data.get("convo_id").is_none());
    }

    #[tokio::test]
    async fn build_push_wake_payload_keeps_message_preview_generic() {
        let (state, _dir) = test_app_state().await;

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_plain_1",
            Some("sender_device_push_plain_1"),
            Some("msg_push_plain_1"),
            None,
            None,
        false,
    )
        .await;

        assert_eq!(payload.notification_title, "Secretly");
        assert_eq!(payload.notification_body, "New message");
        assert_eq!(payload.notification_tag, "msg_push_plain_1");
        assert!(payload.include_notification);
    }

    #[tokio::test]
    async fn build_push_wake_payload_uses_chat_transport_metadata() {
        let (state, _dir) = test_app_state().await;
        let sender_key = SigningKey::from_bytes(&[76u8; 32]);
        cache_authenticated_device(
            &state,
            "sender_device_push_chat_1",
            "sender_profile_push_1",
            &sender_key,
        );

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_chat_1",
            Some("sender_device_push_chat_1"),
            Some("msg_push_chat_1"),
            Some(
                r#"{"kind":"chat_message_v1","message":{"convo_id":"chat_profile_push_1","is_group":false,"message_kind":"text","payload_event_id":"event_push_chat_1","created_at_ms":4321,"sender_profile_id":"sender_profile_push_1","sender_display_name":"Alice","preview_text":"hello there"}}"#,
            ),
            Some(
                r#"{"notifications_enabled":true,"direct_messages_enabled":true,"group_messages_enabled":true,"incoming_calls_enabled":true,"message_visual_alerts_enabled":true,"direct_message_privacy":2,"group_message_privacy":1,"muted_conversations":[],"convo_privacy_overrides":{},"contact_privacy_overrides":{},"contact_calls_disabled":[]}"#,
            ),
        false,
    )
        .await;

        assert_eq!(payload.notification_title, "Alice");
        // Приватность (24.09.2026): даже при «отправитель + текст» текст
        // сообщения в push не уходит — реле его не знает и не хранит.
        assert_eq!(payload.notification_body, "New message");
        assert!(!format!("{:?}", payload.data).contains("hello there"));
        assert_eq!(payload.notification_tag, "sender_profile_push_1");
        assert!(payload.include_notification);
        assert_eq!(
            payload
                .data
                .get("wake_kind")
                .and_then(|value| value.as_str()),
            Some("chat_message_v1")
        );
        assert_eq!(
            payload
                .data
                .get("convo_id")
                .and_then(|value| value.as_str()),
            Some("sender_profile_push_1")
        );
        assert_eq!(
            payload
                .data
                .get("sender_device_id")
                .and_then(|value| value.as_str()),
            Some("sender_device_push_chat_1")
        );
    }

    #[tokio::test]
    async fn build_push_wake_payload_uses_group_category_and_preview() {
        let (state, _dir) = test_app_state().await;
        let sender_key = SigningKey::from_bytes(&[84u8; 32]);
        let target_key = SigningKey::from_bytes(&[85u8; 32]);
        cache_authenticated_device(
            &state,
            "sender_device_push_group_category_1",
            "sender_profile_push_group_category_1",
            &sender_key,
        );
        cache_authenticated_device(
            &state,
            "target_device_push_group_category_1",
            "target_profile_push_group_category_1",
            &target_key,
        );
        state
            .store
            .create_room(
                "room:push-category-1",
                "sender_profile_push_group_category_1",
                "sender_device_push_group_category_1",
                "Category Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                "room:push-category-1",
                "target_profile_push_group_category_1",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_group_category_1",
            Some("sender_device_push_group_category_1"),
            Some("msg_push_group_category_1"),
            Some(
                r#"{"kind":"chat_message_v1","message":{"convo_id":"room:push-category-1","category":"group","message_kind":"text","payload_event_id":"event_push_group_category_1","created_at_ms":6322,"sender_profile_id":"sender_profile_push_group_category_1","sender_display_name":"Dina","convo_title":"Spoofable Client Title","preview_text":"team hello"}}"#,
            ),
            Some(
                r#"{"notifications_enabled":true,"direct_messages_enabled":true,"group_messages_enabled":true,"incoming_calls_enabled":true,"message_visual_alerts_enabled":true,"direct_message_privacy":2,"group_message_privacy":2,"muted_conversations":[],"convo_privacy_overrides":{},"contact_privacy_overrides":{},"contact_calls_disabled":[]}"#,
            ),
        false,
    )
        .await;

        assert_eq!(payload.notification_title, "Category Room");
        assert_eq!(payload.notification_body, "Dina: New message");
        assert!(!format!("{:?}", payload.data).contains("team hello"));
        assert_eq!(payload.notification_tag, "room:push-category-1");
        assert_eq!(
            payload
                .data
                .get("convo_id")
                .and_then(|value| value.as_str()),
            Some("room:push-category-1")
        );
    }

    #[tokio::test]
    async fn build_push_wake_payload_ignores_spoofed_chat_display_but_uses_preview() {
        let (state, _dir) = test_app_state().await;
        let sender_key = SigningKey::from_bytes(&[77u8; 32]);
        cache_authenticated_device(
            &state,
            "sender_device_push_chat_spoof_1",
            "sender_profile_push_chat_spoof_1",
            &sender_key,
        );

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_chat_spoof_1",
            Some("sender_device_push_chat_spoof_1"),
            Some("msg_push_chat_spoof_1"),
            Some(
                r#"{"kind":"chat_message_v1","message":{"convo_id":"chat_profile_push_spoof_1","is_group":false,"message_kind":"text","payload_event_id":"event_push_chat_spoof_1","created_at_ms":5321,"sender_profile_id":"spoofed_profile","sender_display_name":"Mallory","preview_text":"spoofed preview"}}"#,
            ),
            Some(
                r#"{"notifications_enabled":true,"direct_messages_enabled":true,"group_messages_enabled":true,"incoming_calls_enabled":true,"message_visual_alerts_enabled":true,"direct_message_privacy":2,"group_message_privacy":1,"muted_conversations":[],"convo_privacy_overrides":{},"contact_privacy_overrides":{},"contact_calls_disabled":[]}"#,
            ),
        false,
    )
        .await;

        assert_eq!(payload.notification_title, "Secretly");
        assert_eq!(payload.notification_body, "New message");
        assert_eq!(
            payload
                .data
                .get("sender_device_id")
                .and_then(|value| value.as_str()),
            Some("sender_device_push_chat_spoof_1")
        );
        assert_eq!(payload.notification_tag, "sender_profile_push_chat_spoof_1");
        assert_eq!(
            payload
                .data
                .get("convo_id")
                .and_then(|value| value.as_str()),
            Some("sender_profile_push_chat_spoof_1")
        );
    }

    #[tokio::test]
    async fn build_push_wake_payload_drops_unverified_group_convo_id() {
        let (state, _dir) = test_app_state().await;
        let sender_key = SigningKey::from_bytes(&[83u8; 32]);
        cache_authenticated_device(
            &state,
            "sender_device_push_group_spoof_1",
            "sender_profile_push_group_spoof_1",
            &sender_key,
        );

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_group_spoof_1",
            Some("sender_device_push_group_spoof_1"),
            Some("msg_push_group_spoof_1"),
            Some(
                r#"{"kind":"chat_message_v1","message":{"convo_id":"room:spoofed-room-1","is_group":true,"message_kind":"text","payload_event_id":"event_push_group_spoof_1","created_at_ms":5322,"sender_profile_id":"sender_profile_push_group_spoof_1","sender_display_name":"Mallory","convo_title":"Spoofed Room","preview_text":"spoofed preview"}}"#,
            ),
            Some(
                r#"{"notifications_enabled":true,"direct_messages_enabled":true,"group_messages_enabled":true,"incoming_calls_enabled":true,"message_visual_alerts_enabled":true,"direct_message_privacy":2,"group_message_privacy":1,"muted_conversations":[],"convo_privacy_overrides":{},"contact_privacy_overrides":{},"contact_calls_disabled":[]}"#,
            ),
        false,
    )
        .await;

        assert_eq!(payload.notification_tag, "msg_push_group_spoof_1");
        assert_eq!(
            payload
                .data
                .get("wake_kind")
                .and_then(|value| value.as_str()),
            Some("chat_message_v1")
        );
        assert!(payload.data.get("convo_id").is_none());
    }

    #[tokio::test]
    async fn build_push_wake_payload_ignores_spoofed_call_caller_name() {
        let (state, _dir) = test_app_state().await;
        let caller_key = SigningKey::from_bytes(&[78u8; 32]);
        cache_authenticated_device(
            &state,
            "caller_device_push_call_1",
            "caller_profile_push_call_1",
            &caller_key,
        );

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_call_1",
            Some("caller_device_push_call_1"),
            Some("msg_push_call_1"),
            Some(
                r#"{"kind":"call_signal_v1","call":{"action":"invite","call_id":"call_push_call_1","call_attempt_id":"attempt_push_call_1","signal_id":"signal_push_call_1","created_at_ms":6321,"caller_profile_id":"spoofed_profile","caller_display_name":"Mallory","convo_id":"chat_profile_push_call_1","is_video":false}}"#,
            ),
            Some(
                r#"{"notifications_enabled":true,"direct_messages_enabled":true,"group_messages_enabled":true,"incoming_calls_enabled":true,"message_visual_alerts_enabled":true,"direct_message_privacy":2,"group_message_privacy":1,"muted_conversations":[],"convo_privacy_overrides":{},"contact_privacy_overrides":{},"contact_calls_disabled":[]}"#,
            ),
        false,
    )
        .await;

        assert_eq!(payload.notification_title, "Secretly");
        assert_eq!(payload.notification_body, "Incoming call");
        assert_eq!(
            payload
                .data
                .get("caller_profile_id")
                .and_then(|value| value.as_str()),
            Some("caller_profile_push_call_1")
        );
        assert_eq!(
            payload
                .data
                .get("convo_id")
                .and_then(|value| value.as_str()),
            Some("caller_profile_push_call_1")
        );
        assert_eq!(
            payload.data.get("action").and_then(|value| value.as_str()),
            Some("invite")
        );
        assert_eq!(
            payload
                .data
                .get("display_mode")
                .and_then(|value| value.as_str()),
            Some("incoming")
        );
    }

    #[tokio::test]
    async fn build_push_wake_payload_maps_call_offer_to_silent_wake() {
        let (state, _dir) = test_app_state().await;

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_offer_1",
            Some("caller_device_push_offer_1"),
            Some("msg_push_offer_1"),
            Some(
                r#"{"kind":"call_signal_v1","call":{"action":"offer","call_id":"call_push_offer_1","call_attempt_id":"attempt_push_offer_1","signal_id":"signal_push_offer_1","created_at_ms":7331,"is_video":false}}"#,
            ),
            Some(
                r#"{"notifications_enabled":true,"direct_messages_enabled":true,"group_messages_enabled":true,"incoming_calls_enabled":true,"message_visual_alerts_enabled":true,"direct_message_privacy":2,"group_message_privacy":1,"muted_conversations":[],"convo_privacy_overrides":{},"contact_privacy_overrides":{},"contact_calls_disabled":[]}"#,
            ),
        false,
    )
        .await;

        assert!(!payload.include_notification);
        assert_eq!(payload.notification_body, "Call activity");
        assert_eq!(payload.notification_tag, "call_push_offer_1");
        assert_eq!(
            payload
                .data
                .get("wake_kind")
                .and_then(|value| value.as_str()),
            Some("call_signal_wake_v1")
        );
        assert_eq!(
            payload
                .data
                .get("display_mode")
                .and_then(|value| value.as_str()),
            Some("silent")
        );
        assert_eq!(
            payload.data.get("action").and_then(|value| value.as_str()),
            Some("offer")
        );
        assert_eq!(
            payload.data.get("call_id").and_then(|value| value.as_str()),
            Some("call_push_offer_1")
        );
    }

    #[tokio::test]
    async fn build_push_wake_payload_respects_muted_conversation_policy() {
        let (state, _dir) = test_app_state().await;
        let sender_key = SigningKey::from_bytes(&[79u8; 32]);
        let target_key = SigningKey::from_bytes(&[80u8; 32]);
        cache_authenticated_device(
            &state,
            "sender_device_push_chat_2",
            "sender_profile_push_2",
            &sender_key,
        );
        cache_authenticated_device(
            &state,
            "target_device_push_chat_2",
            "target_profile_push_2",
            &target_key,
        );
        state
            .store
            .create_room(
                "room:push-muted-1",
                "sender_profile_push_2",
                "sender_device_push_chat_2",
                "Muted Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                "room:push-muted-1",
                "target_profile_push_2",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_chat_2",
            Some("sender_device_push_chat_2"),
            Some("msg_push_chat_2"),
            Some(
                r#"{"kind":"chat_message_v1","message":{"convo_id":"room:push-muted-1","is_group":true,"message_kind":"text","payload_event_id":"event_push_chat_2","created_at_ms":4322,"sender_profile_id":"sender_profile_push_2","sender_display_name":"Bob","convo_title":"Muted Room","preview_text":"hidden preview"}}"#,
            ),
            Some(
                r#"{"notifications_enabled":true,"direct_messages_enabled":true,"group_messages_enabled":true,"incoming_calls_enabled":true,"message_visual_alerts_enabled":true,"direct_message_privacy":2,"group_message_privacy":2,"muted_conversations":["room:push-muted-1"],"convo_privacy_overrides":{},"contact_privacy_overrides":{},"contact_calls_disabled":[]}"#,
            ),
        false,
    )
        .await;

        assert!(!payload.include_notification);
        assert_eq!(payload.notification_body, "New message");
    }

    // Regression (BUG-1): real rooms use the client's `group:` convo-id prefix,
    // not `room:`. Muting such a room must suppress the push banner.
    #[tokio::test]
    async fn build_push_wake_payload_respects_muted_group_prefixed_room() {
        let (state, _dir) = test_app_state().await;
        let sender_key = SigningKey::from_bytes(&[91u8; 32]);
        let target_key = SigningKey::from_bytes(&[92u8; 32]);
        cache_authenticated_device(
            &state,
            "sender_device_push_grp_1",
            "sender_profile_push_grp_1",
            &sender_key,
        );
        cache_authenticated_device(
            &state,
            "target_device_push_grp_1",
            "target_profile_push_grp_1",
            &target_key,
        );
        state
            .store
            .create_room(
                "group:push-muted-grp-1",
                "sender_profile_push_grp_1",
                "sender_device_push_grp_1",
                "Muted Group",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                "group:push-muted-grp-1",
                "target_profile_push_grp_1",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_grp_1",
            Some("sender_device_push_grp_1"),
            Some("msg_push_grp_1"),
            Some(
                r#"{"kind":"chat_message_v1","message":{"convo_id":"group:push-muted-grp-1","is_group":true,"message_kind":"text","payload_event_id":"event_push_grp_1","created_at_ms":4322,"sender_profile_id":"sender_profile_push_grp_1","sender_display_name":"Bob","convo_title":"Muted Group","preview_text":"hidden preview"}}"#,
            ),
            Some(
                r#"{"notifications_enabled":true,"direct_messages_enabled":true,"group_messages_enabled":true,"incoming_calls_enabled":true,"message_visual_alerts_enabled":true,"direct_message_privacy":2,"group_message_privacy":2,"muted_conversations":["group:push-muted-grp-1"],"convo_privacy_overrides":{},"contact_privacy_overrides":{},"contact_calls_disabled":[]}"#,
            ),
        false,
    )
        .await;

        assert!(!payload.include_notification);
    }

    // Regression (BUG-2): a wake with no chat/call transport meta from a client
    // that registered a push policy is a control envelope (e.g. a read receipt)
    // and must wake silently instead of raising a "New message" banner.
    #[tokio::test]
    async fn build_push_wake_payload_silences_control_wake_with_policy() {
        let (state, _dir) = test_app_state().await;

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_ctrl_1",
            Some("sender_device_push_ctrl_1"),
            Some("msg_push_ctrl_1"),
            None,
            Some(
                r#"{"notifications_enabled":true,"direct_messages_enabled":true,"group_messages_enabled":true,"incoming_calls_enabled":true,"message_visual_alerts_enabled":true,"direct_message_privacy":2,"group_message_privacy":1,"muted_conversations":[],"convo_privacy_overrides":{},"contact_privacy_overrides":{},"contact_calls_disabled":[]}"#,
            ),
        false,
    )
        .await;

        assert!(!payload.include_notification);
    }

    // Regression: a banner-raising chat message must bypass the coarse
    // per-device interval throttle, otherwise a preceding silent control wake
    // (read receipt / typing / sync) starves it and the user never sees a
    // notification (observed in prod: 43/43 chat_message_v1 wakes throttled).
    // ── Схлопывание пачки пробуждений (ТЗ 10.08.2026) ───────────────────────
    //
    // Доказанная лента: одно действие человека кладёт ТРИ конверта, каждый
    // заводит свою отложенную задачу, и все три срабатывают в пределах 24 мс.
    // Два из трёх несут баннер — человек видит два уведомления об одном смс.

    fn coalesce_payload(kind: &str) -> PushWakePayload {
        let mut data = serde_json::Map::new();
        data.insert(
            "wake_kind".into(),
            serde_json::Value::String(kind.to_string()),
        );
        PushWakePayload {
            notification_title: "Secretly".into(),
            notification_body: "New message".into(),
            collapse_key: "k".into(),
            notification_tag: "t".into(),
            include_notification: true,
            data,
            badge: None,
        }
    }

    /// Повторяет решение из `maybe_send_fcm_data_push`, чтобы правило можно было
    /// проверить без сети и токенов.
    fn coalesced(mark: WakeCoalesceMark, enqueued_at: i64, announces: bool) -> bool {
        if announces {
            mark.last_announced_at_ms >= enqueued_at
        } else {
            mark.last_wake_at_ms >= enqueued_at
        }
    }

    #[test]
    fn only_chat_wakes_are_coalescable() {
        // 🔴 Звонки и лечение сессии не схлопываются НИКОГДА: у каждого свой
        // шрам (167 задушенных сигналов связи; замороженный MIUI).
        assert!(push_wake_is_coalescable(&coalesce_payload("chat_message_v1")));
        assert!(!push_wake_is_coalescable(&coalesce_payload(
            "session_heal_v1"
        )));
        assert!(!push_wake_is_coalescable(&coalesce_payload(
            "call_invite_v1"
        )));
        assert!(!push_wake_is_coalescable(&coalesce_payload(
            "call_signal_wake_v1"
        )));
        assert!(!push_wake_is_coalescable(&coalesce_payload("")));
    }

    #[test]
    fn a_burst_of_envelopes_collapses_to_one_wake() {
        // Три конверта одного действия, положенные в 18.000, 18.018 и 18.024.
        // Первый пуш ушёл в 20.000 и объявил.
        let mark = WakeCoalesceMark {
            last_wake_at_ms: 20_000,
            last_announced_at_ms: 20_000,
        };
        assert!(coalesced(mark, 18_000, true));
        assert!(coalesced(mark, 18_018, true));
        assert!(coalesced(mark, 18_024, true));
    }

    #[test]
    fn a_message_written_after_the_wake_still_wakes_the_device() {
        // 🔴 САМАЯ ВАЖНАЯ ПРОВЕРКА ЭТОГО ФАЙЛА. Именно ради этого случая
        // `chat_message_v1` когда-то внесли в исключения ограничителя
        // (56a55689, 14.06.2026): под окном в 3,5 с второе сообщение человека
        // не будило телефон вовсе и ждало лестницы, у которой шаг десять минут.
        //
        // Правило по СОСТОЯНИЮ закрывает это по построению: конверт, положенный
        // ПОСЛЕ пуша, не считается покрытым.
        let mark = WakeCoalesceMark {
            last_wake_at_ms: 20_000,
            last_announced_at_ms: 20_000,
        };
        assert!(!coalesced(mark, 20_001, true));
        assert!(!coalesced(mark, 23_000, true));
    }

    #[test]
    fn a_silent_wake_never_swallows_the_announcement() {
        // 🔴 В доказанной ленте ПЕРВЫМ шло тихое лечение сессии, а баннерные —
        // вторым и третьим. Схлопывание «оставить первый» отбросило бы оба
        // баннерных, и «лишние уведомления» стали бы «сообщения приходят молча».
        let woken_but_silent = WakeCoalesceMark {
            last_wake_at_ms: 20_000,
            last_announced_at_ms: 0,
        };
        // Тихое — подавляется: телефон уже разбужен.
        assert!(coalesced(woken_but_silent, 18_000, false));
        // Баннерное — НЕ подавляется: человеку ещё не сказали.
        assert!(!coalesced(woken_but_silent, 18_000, true));
    }

    #[test]
    fn a_concurrent_burst_cannot_slip_past_the_claim() {
        // 🔴 ЭТОТ ТЕСТ ПРО МОЮ СОБСТВЕННУЮ ОШИБКУ (11.08.2026).
        //
        // Первая редакция проверяла отметку ПЕРЕД отправкой, а ставила ПОСЛЕ.
        // На проде это не сработало: три задачи одного действия идут
        // одновременно, все три проверили отметку в пределах трёх миллисекунд,
        // а первая отметилась только через 60–110 мс — уже после отправки. Все
        // три увидели пустоту и ушли на телефон.
        //
        // Здесь воспроизводится именно тот порядок: три проверки подряд, и
        // только потом отправки. С заявкой ПОД ЗАМКОМ выживает ровно одна.
        let map: DashMap<String, WakeCoalesceMark> = DashMap::new();
        let device = "dev-1".to_string();
        let enqueued_at = 18_000;
        let claim_at = 20_000;

        let mut sent = 0;
        for _ in 0..3 {
            let mut mark = map.entry(device.clone()).or_default();
            if mark.last_announced_at_ms >= enqueued_at {
                continue;
            }
            // Заявка выставляется ЗДЕСЬ ЖЕ, под тем же замком, а не после
            // отправки. В этом вся разница.
            mark.last_announced_at_ms = mark.last_announced_at_ms.max(claim_at);
            mark.last_wake_at_ms = mark.last_wake_at_ms.max(claim_at);
            sent += 1;
        }
        assert_eq!(sent, 1, "пачка обязана схлопнуться в одно пробуждение");
    }

    #[test]
    fn a_failed_send_releases_the_claim() {
        // 🔴 К-2 из ТЗ: неудачная отправка не имеет права подавлять следующую
        // попытку, иначе один сбой сети оставляет сообщение до лестницы с шагом
        // в десять минут.
        let map: DashMap<String, WakeCoalesceMark> = DashMap::new();
        let device = "dev-1".to_string();
        let claim_at = 20_000;

        // Заявка выставлена...
        let prev = {
            let mut mark = map.entry(device.clone()).or_default();
            let prev = *mark;
            mark.last_wake_at_ms = claim_at;
            mark.last_announced_at_ms = claim_at;
            prev
        };
        // ...отправка провалилась — откатываем свою и только свою отметку.
        {
            let mut mark = map.entry(device.clone()).or_default();
            if mark.last_wake_at_ms == claim_at {
                mark.last_wake_at_ms = prev.last_wake_at_ms;
            }
            if mark.last_announced_at_ms == claim_at {
                mark.last_announced_at_ms = prev.last_announced_at_ms;
            }
        }
        let after = *map.get(&device).unwrap();
        assert_eq!(after.last_wake_at_ms, 0);
        assert_eq!(after.last_announced_at_ms, 0);
    }

    #[test]
    fn a_rollback_never_clobbers_someone_elses_claim() {
        // Если за время неудачной отправки слот занял кто-то другой — значит он
        // занят по-настоящему, и откатывать его нельзя.
        let map: DashMap<String, WakeCoalesceMark> = DashMap::new();
        let device = "dev-1".to_string();
        let claim_at = 20_000;
        let someone_else = 20_500;

        {
            let mut mark = map.entry(device.clone()).or_default();
            mark.last_wake_at_ms = claim_at;
        }
        // Пока мы отправляли, отметку обновил другой.
        {
            let mut mark = map.entry(device.clone()).or_default();
            mark.last_wake_at_ms = someone_else;
        }
        // Наш откат не должен её тронуть.
        {
            let mut mark = map.entry(device.clone()).or_default();
            if mark.last_wake_at_ms == claim_at {
                mark.last_wake_at_ms = 0;
            }
        }
        assert_eq!(map.get(&device).unwrap().last_wake_at_ms, someone_else);
    }

    #[test]
    fn a_device_is_never_covered_by_another_devices_wake() {
        // 🔴 У человека несколько устройств. Отметка пустая — значит ничего не
        // подавляем: пробуждение одного телефона не отменяет пробуждение второго.
        let fresh = WakeCoalesceMark::default();
        assert!(!coalesced(fresh, 1, true));
        assert!(!coalesced(fresh, 1, false));
    }

    #[test]
    fn push_wake_interval_throttle_bypass_rules() {
        fn payload(kind: &str, include_notification: bool) -> PushWakePayload {
            let mut data = serde_json::Map::new();
            data.insert(
                "wake_kind".into(),
                serde_json::Value::String(kind.to_string()),
            );
            PushWakePayload {
                notification_title: "Secretly".into(),
                notification_body: "New message".into(),
                collapse_key: "k".into(),
                notification_tag: "t".into(),
                include_notification,
                data,
                badge: None,
            }
        }

        // Alert-bearing chat message: must bypass the throttle.
        assert!(push_wake_bypasses_interval_throttle(&payload(
            "chat_message_v1",
            true
        )));
        // Call invite: always rings through.
        assert!(push_wake_bypasses_interval_throttle(&payload(
            "call_invite_v1",
            true
        )));
        // R2 (2026-07-03): a muted/silent chat message (no banner) now ALSO
        // bypasses the throttle. The background DATA wake must reach the device
        // so it drains its mailbox and applies the message; the visible banner
        // stays suppressed separately by `should_include_fcm_notification`.
        // Previously this was throttled, which could strand a burst of quiet
        // GROUP messages to an offline member until the next reconnect.
        assert!(push_wake_bypasses_interval_throttle(&payload(
            "chat_message_v1",
            false
        )));
        // Silent control wake (read receipt / typing / sync): stays throttled —
        // this is exactly what the interval throttle was built to suppress.
        assert!(!push_wake_bypasses_interval_throttle(&payload("", false)));
        // F4 (2026-07-08): a silent Double-Ratchet session-heal wake must NOT be
        // throttled even though it raises no banner — a MIUI-frozen peer only
        // heals when this reaches it. It rides the same bypass as chat wakes.
        assert!(push_wake_bypasses_interval_throttle(&payload(
            "session_heal_v1",
            false
        )));
        // Call audit 2026-07-09: an in-progress call's offer/answer/ICE wake must
        // NOT be throttled — throttling it stalls call setup ("calls sometimes
        // don't connect"; 167 call_signal_wake_v1 throttled in one session).
        assert!(push_wake_bypasses_interval_throttle(&payload(
            "call_signal_wake_v1",
            false
        )));
    }

    // DELIVERY-WAKE AUDIT (2026-07-16): message wakes must SURVIVE Doze / a dead
    // FCM socket. The old blanket ttl="30s" made FCM silently discard nearly
    // every wake (and its banner) sent to a dozing device — prod case: 36
    // accepted FCM wakes, first ack 86 minutes later, stock Pixel. Call wakes
    // stay short: a stale ring is worse than no ring.
    #[test]
    fn fcm_android_ttl_per_wake_kind() {
        fn payload(kind: &str) -> PushWakePayload {
            let mut data = serde_json::Map::new();
            data.insert(
                "wake_kind".into(),
                serde_json::Value::String(kind.to_string()),
            );
            PushWakePayload {
                notification_title: "Secretly".into(),
                notification_body: "New message".into(),
                collapse_key: "k".into(),
                notification_tag: "t".into(),
                include_notification: true,
                data,
                badge: None,
            }
        }

        assert_eq!(fcm_android_ttl_for_payload(&payload("chat_message_v1")), "14400s");
        assert_eq!(fcm_android_ttl_for_payload(&payload("session_heal_v1")), "14400s");
        // Control wakes (receipts/reactions/typing/sync) ride the long TTL too.
        assert_eq!(fcm_android_ttl_for_payload(&payload("")), "14400s");
        // Stale call wakes must die fast.
        assert_eq!(fcm_android_ttl_for_payload(&payload("call_invite_v1")), "30s");
        assert_eq!(
            fcm_android_ttl_for_payload(&payload("call_signal_wake_v1")),
            "30s"
        );

        // And the built FCM message actually carries the chosen TTL.
        let built = build_fcm_v1_message_payload("tok-1", &payload("chat_message_v1"), "android");
        assert_eq!(
            built["message"]["android"]["ttl"],
            serde_json::Value::String("14400s".into())
        );
        let built = build_fcm_v1_message_payload("tok-2", &payload("call_invite_v1"), "android");
        assert_eq!(
            built["message"]["android"]["ttl"],
            serde_json::Value::String("30s".into())
        );
    }

    // DELIVERY-WAKE AUDIT (2026-07-16): backoff ladder for the offline re-wake
    // sweep — frequent enough that a lost initial push is recovered in minutes,
    // sparse enough that a long-ignored backlog cannot ping the user all day.
    #[test]
    fn offline_rewake_backoff_ladder() {
        const MIN: i64 = 60 * 1000;
        const HOUR: i64 = 60 * MIN;
        // Fresh backlog (initial push may have died): retry every 10 min.
        assert_eq!(offline_rewake_required_gap_ms(0), 10 * MIN);
        assert_eq!(offline_rewake_required_gap_ms(29 * MIN), 10 * MIN);
        // Sub-6h backlog: every 30 min.
        assert_eq!(offline_rewake_required_gap_ms(30 * MIN), 30 * MIN);
        assert_eq!(offline_rewake_required_gap_ms(5 * HOUR), 30 * MIN);
        // Sub-48h: every 2 h.
        assert_eq!(offline_rewake_required_gap_ms(6 * HOUR), 2 * HOUR);
        assert_eq!(offline_rewake_required_gap_ms(47 * HOUR), 2 * HOUR);
        // Ancient backlog: every 6 h until it TTL-expires.
        assert_eq!(offline_rewake_required_gap_ms(48 * HOUR), 6 * HOUR);
        assert_eq!(offline_rewake_required_gap_ms(6 * 24 * HOUR), 6 * HOUR);
    }

    #[test]
    fn session_heal_transport_meta_detection() {
        assert!(is_session_heal_transport_meta(Some(
            r#"{"kind":"session_heal_v1"}"#
        )));
        // Whitespace tolerated.
        assert!(is_session_heal_transport_meta(Some(
            "  {\"kind\":\"session_heal_v1\"}  "
        )));
        // Other kinds / absent / malformed are not heal wakes.
        assert!(!is_session_heal_transport_meta(Some(
            r#"{"kind":"chat_message_v1"}"#
        )));
        assert!(!is_session_heal_transport_meta(None));
        assert!(!is_session_heal_transport_meta(Some("")));
        assert!(!is_session_heal_transport_meta(Some("not json")));
    }

    // 🔴 Мост для своих устройств (25.09.2026): продлевается ТОЛЬКО служебная
    // посылка по умолчанию между разными устройствами одного профиля.
    #[test]
    fn own_device_control_ttl_extends_only_own_default_control_traffic() {
        let three_days = 3 * 24 * 3600;
        let week = 7 * 24 * 3600;
        let ttl = |cfg, capped, from_pid, to_pid, from_did, to_did, heal, call| {
            own_device_control_ttl(cfg, capped, from_pid, to_pid, from_did, to_did, heal, call)
        };
        // Выключено по умолчанию — прежнее поведение.
        assert_eq!(ttl(0, 3600, "P", "P", "phone", "desk", false, false), 3600);
        // Телефон → ПК того же профиля, служебная посылка по умолчанию.
        assert_eq!(ttl(three_days, 3600, "P", "P", "phone", "desk", false, false), three_days);
        // Собеседнику — как раньше: квитанции чужим не копятся.
        assert_eq!(ttl(three_days, 3600, "P", "Q", "phone", "desk", false, false), 3600);
        // Лечение сессии и сигналы звонка поздно доставлять бессмысленно.
        assert_eq!(ttl(three_days, 3600, "P", "P", "phone", "desk", true, false), 3600);
        assert_eq!(ttl(three_days, 3600, "P", "P", "phone", "desk", false, true), 3600);
        // Свои сроки не трогаются: «печатает», звонок, сами сообщения.
        assert_eq!(ttl(three_days, 20, "P", "P", "phone", "desk", false, false), 20);
        assert_eq!(ttl(three_days, 90, "P", "P", "phone", "desk", false, false), 90);
        assert_eq!(ttl(three_days, week, "P", "P", "phone", "desk", false, false), week);
        // Никогда не укорачивает.
        assert_eq!(ttl(1800, 3600, "P", "P", "phone", "desk", false, false), 3600);
        // Сам себе и неизвестный профиль — нет.
        assert_eq!(ttl(three_days, 3600, "P", "P", "desk", "desk", false, false), 3600);
        assert_eq!(ttl(three_days, 3600, "", "", "phone", "desk", false, false), 3600);
    }

    #[tokio::test]
    async fn build_push_wake_payload_respects_conversation_quiet_hours_policy() {
        let (state, _dir) = test_app_state().await;
        let sender_key = SigningKey::from_bytes(&[81u8; 32]);
        let target_key = SigningKey::from_bytes(&[82u8; 32]);
        cache_authenticated_device(
            &state,
            "sender_device_push_chat_3",
            "sender_profile_push_3",
            &sender_key,
        );
        cache_authenticated_device(
            &state,
            "target_device_push_chat_3",
            "target_profile_push_3",
            &target_key,
        );
        state
            .store
            .create_room(
                "room:push-quiet-1",
                "sender_profile_push_3",
                "sender_device_push_chat_3",
                "Quiet Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                "room:push-quiet-1",
                "target_profile_push_3",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let payload = build_push_wake_payload(
            &state,
            "target_device_push_chat_3",
            Some("sender_device_push_chat_3"),
            Some("msg_push_chat_3"),
            Some(
                r#"{"kind":"chat_message_v1","message":{"convo_id":"room:push-quiet-1","is_group":true,"message_kind":"text","payload_event_id":"event_push_chat_3","created_at_ms":4323,"sender_profile_id":"sender_profile_push_3","sender_display_name":"Cara","convo_title":"Quiet Room","preview_text":"night ping"}}"#,
            ),
            Some(
                r#"{"notifications_enabled":true,"direct_messages_enabled":true,"group_messages_enabled":true,"incoming_calls_enabled":true,"message_visual_alerts_enabled":true,"direct_message_privacy":2,"group_message_privacy":2,"muted_conversations":[],"convo_privacy_overrides":{},"contact_privacy_overrides":{},"contact_calls_disabled":[],"timezone_offset_minutes":0,"convo_quiet_hours":{"room:push-quiet-1":{"start_hour":0,"end_hour":0}}}"#,
            ),
        false,
    )
        .await;

        assert!(!payload.include_notification);
        assert_eq!(
            payload
                .data
                .get("convo_id")
                .and_then(|value| value.as_str()),
            Some("room:push-quiet-1")
        );
    }

    #[test]
    fn normalize_push_policy_json_accepts_legacy_client_policy_keys() {
        let raw = r#"{"v":1,"global_enabled":false,"direct_messages_enabled":true,"group_messages_enabled":true,"incoming_calls_enabled":true,"message_visual_alerts_enabled":true,"direct_privacy_level":1,"group_privacy_level":2,"muted_convo_ids":["room:legacy-quiet-1"],"convo_privacy_overrides":{"room:legacy-quiet-1":0},"contact_privacy_overrides":{"profile_legacy_1":1},"call_disabled_profile_ids":["profile_legacy_2"],"tz_offset_minutes":180,"convo_quiet_hours":{"room:legacy-quiet-1":{"startHour":22,"endHour":8}}}"#;
        let encoded = base64::engine::general_purpose::STANDARD.encode(raw.as_bytes());

        let normalized = normalize_push_policy_json(Some(encoded.as_str()))
            .expect("policy should normalize")
            .expect("policy should be present");
        let parsed =
            parse_push_policy_json(Some(normalized.as_str())).expect("policy should parse");

        assert!(!parsed.notifications_enabled);
        assert!(parsed.muted_conversations.contains("room:legacy-quiet-1"));
        assert_eq!(parsed.timezone_offset_minutes, 180);
        assert!(parsed.contact_calls_disabled.contains("profile_legacy_2"));
        assert_eq!(
            parsed
                .convo_quiet_hours
                .get("room:legacy-quiet-1")
                .map(|value| (value.start_hour, value.end_hour)),
            Some((22, 8))
        );
    }

    #[test]
    fn build_fcm_v1_message_payload_adds_ios_apns_wake_fields() {
        let mut data = serde_json::Map::new();
        data.insert(
            "type".into(),
            serde_json::Value::String("relay_pending".to_string()),
        );
        data.insert(
            "wake_kind".into(),
            serde_json::Value::String("chat_message_v1".to_string()),
        );
        data.insert(
            "convo_id".into(),
            serde_json::Value::String("chat_profile_push_ios_1".to_string()),
        );
        let payload = PushWakePayload {
            notification_title: "Secretly".to_string(),
            notification_body: "New message".to_string(),
            collapse_key: "secretly_pending_target_device".to_string(),
            notification_tag: "msg_push_ios_1".to_string(),
            include_notification: true,
            data,
            badge: Some(3),
        };

        let built = build_fcm_v1_message_payload("ios-token-1", &payload, "ios");

        assert_eq!(
            built
                .get("message")
                .and_then(|value| value.get("token"))
                .and_then(|value| value.as_str()),
            Some("ios-token-1")
        );
        assert_eq!(
            built
                .get("message")
                .and_then(|value| value.get("apns"))
                .and_then(|value| value.get("headers"))
                .and_then(|value| value.get("apns-push-type"))
                .and_then(|value| value.as_str()),
            Some("alert")
        );
        assert_eq!(
            built
                .get("message")
                .and_then(|value| value.get("apns"))
                .and_then(|value| value.get("payload"))
                .and_then(|value| value.get("aps"))
                .and_then(|value| value.get("content-available"))
                .and_then(|value| value.as_i64()),
            Some(1)
        );
        assert_eq!(
            built
                .get("message")
                .and_then(|value| value.get("apns"))
                .and_then(|value| value.get("headers"))
                .and_then(|value| value.get("apns-collapse-id"))
                .and_then(|value| value.as_str()),
            // Alert → collapse PER-CONVERSATION (notification_tag), not per-device,
            // so different chats never overwrite each other's banners.
            Some("msg_push_ios_1")
        );
        assert_eq!(
            built
                .get("message")
                .and_then(|value| value.get("apns"))
                .and_then(|value| value.get("payload"))
                .and_then(|value| value.get("aps"))
                .and_then(|value| value.get("category"))
                .and_then(|value| value.as_str()),
            Some("secretly_chat_message_actions_v1")
        );
        // App-icon unread badge is emitted into aps when the payload carries it.
        assert_eq!(
            built
                .get("message")
                .and_then(|value| value.get("apns"))
                .and_then(|value| value.get("payload"))
                .and_then(|value| value.get("aps"))
                .and_then(|value| value.get("badge"))
                .and_then(|value| value.as_i64()),
            Some(3)
        );
        // NSE GROUNDWORK (2026-07-16): alert pushes must carry
        // mutable-content:1 so a Notification Service Extension can intercept
        // them (no-op for clients without the extension).
        assert_eq!(
            built
                .get("message")
                .and_then(|value| value.get("apns"))
                .and_then(|value| value.get("payload"))
                .and_then(|value| value.get("aps"))
                .and_then(|value| value.get("mutable-content"))
                .and_then(|value| value.as_i64()),
            Some(1)
        );
    }

    #[test]
    fn build_fcm_legacy_payload_marks_ios_content_available() {
        let mut data = serde_json::Map::new();
        data.insert(
            "type".into(),
            serde_json::Value::String("relay_pending".to_string()),
        );
        data.insert(
            "wake_kind".into(),
            serde_json::Value::String("chat_message_v1".to_string()),
        );
        data.insert(
            "convo_id".into(),
            serde_json::Value::String("chat_profile_push_ios_legacy_1".to_string()),
        );
        let payload = PushWakePayload {
            notification_title: "Secretly".to_string(),
            notification_body: "New message".to_string(),
            collapse_key: "secretly_pending_target_device".to_string(),
            notification_tag: "msg_push_ios_legacy_1".to_string(),
            include_notification: true,
            data,
            badge: None,
        };

        let built = build_fcm_legacy_payload("ios-token-legacy-1", &payload, "ios");

        assert_eq!(
            built.get("to").and_then(|value| value.as_str()),
            Some("ios-token-legacy-1")
        );
        assert_eq!(
            built
                .get("content_available")
                .and_then(|value| value.as_bool()),
            Some(true)
        );
        assert_eq!(
            built
                .get("mutable_content")
                .and_then(|value| value.as_bool()),
            Some(true)
        );
        assert_eq!(
            built
                .get("notification")
                .and_then(|value| value.get("click_action"))
                .and_then(|value| value.as_str()),
            Some("secretly_chat_message_actions_v1")
        );
    }

    #[test]
    fn build_fcm_v1_message_payload_uses_background_headers_when_visuals_suppressed() {
        let mut data = serde_json::Map::new();
        data.insert(
            "type".into(),
            serde_json::Value::String("relay_pending".to_string()),
        );
        let payload = PushWakePayload {
            notification_title: "Secretly".to_string(),
            notification_body: "New message".to_string(),
            collapse_key: "secretly_pending_target_device".to_string(),
            notification_tag: "msg_push_ios_bg_1".to_string(),
            include_notification: false,
            data,
            badge: None,
        };

        let built = build_fcm_v1_message_payload("ios-token-bg-1", &payload, "ios");

        assert!(
            built
                .get("message")
                .and_then(|value| value.get("notification"))
                .is_none()
        );
        assert_eq!(
            built
                .get("message")
                .and_then(|value| value.get("apns"))
                .and_then(|value| value.get("headers"))
                .and_then(|value| value.get("apns-push-type"))
                .and_then(|value| value.as_str()),
            Some("background")
        );
    }

    #[test]
    fn build_fcm_v1_message_payload_suppresses_android_notification_for_call_invite() {
        let mut data = serde_json::Map::new();
        data.insert(
            "type".into(),
            serde_json::Value::String("relay_pending".to_string()),
        );
        data.insert(
            "wake_kind".into(),
            serde_json::Value::String("call_invite_v1".to_string()),
        );
        data.insert(
            "call_id".into(),
            serde_json::Value::String("call_push_android_1".to_string()),
        );
        let payload = PushWakePayload {
            notification_title: "Alice".to_string(),
            notification_body: "Incoming call".to_string(),
            collapse_key: "secretly_pending_target_device".to_string(),
            notification_tag: "call_push_android_1".to_string(),
            include_notification: true,
            data,
            badge: None,
        };

        let built = build_fcm_v1_message_payload("android-token-call-1", &payload, "android");

        let message = built.get("message").expect("message");
        assert!(message.get("notification").is_none());
        assert!(
            message
                .get("android")
                .and_then(|value| value.get("notification"))
                .is_none()
        );
        assert_eq!(
            message
                .get("android")
                .and_then(|value| value.get("priority"))
                .and_then(|value| value.as_str()),
            Some("high")
        );
        assert_eq!(
            message
                .get("data")
                .and_then(|value| value.get("wake_kind"))
                .and_then(|value| value.as_str()),
            Some("call_invite_v1")
        );
    }

    #[test]
    fn build_fcm_legacy_payload_suppresses_android_notification_for_call_invite() {
        let mut data = serde_json::Map::new();
        data.insert(
            "type".into(),
            serde_json::Value::String("relay_pending".to_string()),
        );
        data.insert(
            "wake_kind".into(),
            serde_json::Value::String("call_invite_v1".to_string()),
        );
        let payload = PushWakePayload {
            notification_title: "Alice".to_string(),
            notification_body: "Incoming call".to_string(),
            collapse_key: "secretly_pending_target_device".to_string(),
            notification_tag: "call_push_android_legacy_1".to_string(),
            include_notification: true,
            data,
            badge: None,
        };

        let built = build_fcm_legacy_payload("android-token-call-legacy-1", &payload, "android");

        assert!(built.get("notification").is_none());
        assert_eq!(
            built.get("priority").and_then(|value| value.as_str()),
            Some("high")
        );
        assert_eq!(
            built
                .get("data")
                .and_then(|value| value.get("wake_kind"))
                .and_then(|value| value.as_str()),
            Some("call_invite_v1")
        );
    }

    #[test]
    fn build_apns_voip_payload_preserves_callkit_fields() {
        let mut data = serde_json::Map::new();
        data.insert(
            "wake_kind".into(),
            serde_json::Value::String("call_invite_v1".to_string()),
        );
        data.insert(
            "call_id".into(),
            serde_json::Value::String("call_voip_payload_1".to_string()),
        );
        data.insert(
            "call_attempt_id".into(),
            serde_json::Value::String("attempt_voip_payload_1".to_string()),
        );
        data.insert(
            "signal_id".into(),
            serde_json::Value::String("signal_voip_payload_1".to_string()),
        );
        data.insert(
            "peer_name".into(),
            serde_json::Value::String("Alice".to_string()),
        );
        data.insert(
            "is_video".into(),
            serde_json::Value::String("true".to_string()),
        );
        let payload = PushWakePayload {
            notification_title: "Alice".to_string(),
            notification_body: "Incoming call".to_string(),
            collapse_key: "secretly_pending_target_device".to_string(),
            notification_tag: "call_voip_payload_1".to_string(),
            include_notification: true,
            data,
            badge: None,
        };

        let built = build_apns_voip_payload(&payload);

        assert_eq!(built["aps"], serde_json::json!({}));
        assert_eq!(built["wake_kind"], "call_invite_v1");
        assert_eq!(built["call_id"], "call_voip_payload_1");
        assert_eq!(built["call_attempt_id"], "attempt_voip_payload_1");
        assert_eq!(built["signal_id"], "signal_voip_payload_1");
        assert_eq!(built["peer_name"], "Alice");
        assert_eq!(built["is_video"], true);
    }

    #[test]
    fn parse_chat_message_transport_meta_rejects_unknown_kind() {
        let err = parse_chat_message_transport_meta(Some(
            r#"{"kind":"chat_message_v1","message":{"convo_id":"chat_profile_push_bad_1","is_group":false,"message_kind":"poll","payload_event_id":"event_push_bad_1","created_at_ms":44}}"#,
        ))
        .unwrap_err();

        assert_eq!(err, "bad message_kind");
    }

    #[test]
    fn parse_room_call_sync_transport_meta_rejects_active_call_without_call_id() {
        let err = parse_room_call_sync_transport_meta(Some(
            r#"{"kind":"room_call_sync_v1","room_call":{"room_id":"room_alpha_push_2","call_exists":true,"state_version":2,"created_at_ms":55}}"#,
        ))
        .unwrap_err();

        assert_eq!(err, "missing room call_id");
    }

    #[test]
    fn parse_room_call_media_signal_transport_meta_accepts_descriptor_update() {
        let parsed = parse_room_call_media_signal_transport_meta(Some(
            r#"{"kind":"room_call_media_signal_v1","room_media_signal":{"action":"descriptor_updated","room_id":"room_alpha_push_media_2","call_id":"call_push_media_2","session_id":"call_push_media_2","descriptor_version":18,"state_version":10,"signal_id":"sig_push_media_2","created_at_ms":99}}"#,
        ))
        .unwrap()
        .unwrap();

        assert_eq!(parsed.action, "descriptor_updated");
        assert_eq!(parsed.room_id, "room_alpha_push_media_2");
        assert_eq!(parsed.call_id, "call_push_media_2");
        assert_eq!(parsed.session_id, "call_push_media_2");
        assert_eq!(parsed.descriptor_version, 18);
        assert_eq!(parsed.state_version, 10);
        assert_eq!(parsed.signal_id, "sig_push_media_2");
        assert_eq!(parsed.created_at_ms, 99);
    }

    #[test]
    fn parse_room_call_media_signal_transport_meta_rejects_negative_descriptor_version() {
        let err = parse_room_call_media_signal_transport_meta(Some(
            r#"{"kind":"room_call_media_signal_v1","room_media_signal":{"action":"descriptor_updated","room_id":"room_alpha_push_media_3","call_id":"call_push_media_3","session_id":"call_push_media_3","descriptor_version":-1,"state_version":10,"signal_id":"sig_push_media_3","created_at_ms":99}}"#,
        ))
        .unwrap_err();

        assert_eq!(err, "bad room media descriptor_version");
    }

    /// Сокет-житель обязан попасть в замер раскатки.
    ///
    /// Активность отмечается и на этом пути, а версия писалась только на
    /// HTTP-pump: устройство, которое держит сокет, считалось активным «без
    /// версии». Замер, не видящий треть парка, не годится для решения о
    /// раскатке — и молчит он ровно так же, как работающий.
    #[tokio::test]
    async fn ws_hello_auth_records_client_build_for_socket_dwellers() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[73u8; 32]);
        let device_id = "dev_ws_build_1";
        cache_authenticated_device(&state, device_id, "profile_ws_build_1", &signing_key);

        let (url, server_handle) = start_test_ws_server(state.clone()).await;
        let (mut socket, _) = connect_async(&url).await.unwrap();
        socket
            .send(ClientWsMessage::Text(
                signed_ws_hello_text_with_build(device_id, &signing_key, "ws-build-1", "544")
                    .into(),
            ))
            .await
            .unwrap();
        expect_ws_welcome(&mut socket, device_id, 1).await;

        // Welcome уходит РАНЬШЕ записи активности, поэтому ждём её появления, а
        // не читаем сразу: иначе тест ловил бы не отсутствие записи, а гонку.
        let mut recorded = String::new();
        for _ in 0..100 {
            recorded = state
                .store
                .device_activity_client_build(device_id)
                .await
                .unwrap();
            if !recorded.is_empty() {
                break;
            }
            tokio::time::sleep(std::time::Duration::from_millis(20)).await;
        }
        assert_eq!(
            recorded, "544",
            "приветствие назвало сборку, но замер её не записал"
        );

        server_handle.abort();
    }

    #[tokio::test]
    async fn ws_hello_auth_returns_welcome_and_pending_messages() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[41u8; 32]);
        let device_id = "dev_ws_welcome_1";

        cache_authenticated_device(&state, device_id, "profile_ws_welcome_1", &signing_key);
        state
            .store
            .enqueue(device_id, "msg-ws-pending-1", "QUJD", None, 60, now_ms())
            .await
            .unwrap();

        let (url, server_handle) = start_test_ws_server(state).await;
        let (mut socket, _) = connect_async(&url).await.unwrap();
        socket
            .send(ClientWsMessage::Text(
                signed_ws_hello_text(device_id, &signing_key, "ws-hello-ok").into(),
            ))
            .await
            .unwrap();

        expect_ws_welcome(&mut socket, device_id, 1).await;

        match recv_ws_server_msg(&mut socket).await {
            ServerMsg::Deliver {
                device_id: deliver_device_id,
                seq,
                msg_id,
                ciphertext_b64,
                transport_meta_json,
                ..
            } => {
                assert_eq!(deliver_device_id, device_id);
                assert_eq!(seq, 1);
                assert_eq!(msg_id, "msg-ws-pending-1");
                assert_eq!(ciphertext_b64, "QUJD");
                assert_eq!(transport_meta_json, None);
            }
            other => panic!("expected pending delivery, got {other:?}"),
        }

        let _ = socket.close(None).await;
        server_handle.abort();
    }

    #[tokio::test]
    async fn ws_legacy_hello_is_rejected_when_auth_is_required() {
        let (state, _dir) = test_app_state().await;

        let (url, server_handle) = start_test_ws_server(state).await;
        let (mut socket, _) = connect_async(&url).await.unwrap();
        let hello = serde_json::to_string(&ClientMsg::Hello {
            device_id: "dev_ws_legacy_1".to_string(),
        })
        .unwrap();
        socket
            .send(ClientWsMessage::Text(hello.into()))
            .await
            .unwrap();

        match recv_ws_server_msg(&mut socket).await {
            ServerMsg::Error { code, message } => {
                assert_eq!(code, "auth_required");
                assert_eq!(message, "hello_auth required");
            }
            other => panic!("expected auth_required error, got {other:?}"),
        }

        let _ = socket.close(None).await;
        server_handle.abort();
    }

    #[tokio::test]
    async fn ws_hello_auth_rejects_replayed_nonce_across_connections() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[42u8; 32]);
        let device_id = "dev_ws_replay_1";

        cache_authenticated_device(&state, device_id, "profile_ws_replay_1", &signing_key);

        let (url, server_handle) = start_test_ws_server(state).await;
        let hello_auth = signed_ws_hello_text(device_id, &signing_key, "ws-replay");

        let (mut first_socket, _) = connect_async(&url).await.unwrap();
        first_socket
            .send(ClientWsMessage::Text(hello_auth.clone().into()))
            .await
            .unwrap();
        expect_ws_welcome(&mut first_socket, device_id, 1).await;

        let (mut replay_socket, _) = connect_async(&url).await.unwrap();
        replay_socket
            .send(ClientWsMessage::Text(hello_auth.into()))
            .await
            .unwrap();
        match recv_ws_server_msg(&mut replay_socket).await {
            ServerMsg::Error { code, message } => {
                assert_eq!(code, "auth_failed");
                assert_eq!(message, "replayed nonce");
            }
            other => panic!("expected replay rejection, got {other:?}"),
        }

        let _ = first_socket.close(None).await;
        let _ = replay_socket.close(None).await;
        server_handle.abort();
    }

    #[tokio::test]
    async fn ws_send_rejects_blocked_sender_after_valid_signed_hello() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[43u8; 32]);
        let sender_device_id = "dev_ws_sender_1";
        let receiver_device_id = "dev_ws_receiver_1";
        let sender_profile_id = "profile_ws_sender_1";
        let receiver_profile_id = "profile_ws_receiver_1";

        cache_authenticated_device(&state, sender_device_id, sender_profile_id, &signing_key);
        state.profile_cache.insert(
            receiver_device_id.to_string(),
            receiver_profile_id.to_string(),
        );
        state
            .store
            .set_block(receiver_profile_id, sender_profile_id, true, now_ms())
            .await
            .unwrap();

        let (url, server_handle) = start_test_ws_server(state).await;
        let (mut socket, _) = connect_async(&url).await.unwrap();
        socket
            .send(ClientWsMessage::Text(
                signed_ws_hello_text(sender_device_id, &signing_key, "ws-send-blocked").into(),
            ))
            .await
            .unwrap();
        expect_ws_welcome(&mut socket, sender_device_id, 1).await;

        let send = serde_json::to_string(&ClientMsg::Send {
            to_device_id: receiver_device_id.to_string(),
            msg_id: "123e4567-e89b-12d3-a456-426614174000".to_string(),
            ciphertext_b64: "QUJD".to_string(),
            transport_meta_json: None,
            ttl_seconds: 60,
            deliver_at_ms: None,
        })
        .unwrap();
        socket
            .send(ClientWsMessage::Text(send.into()))
            .await
            .unwrap();

        match recv_ws_server_msg(&mut socket).await {
            ServerMsg::Error { code, message } => {
                assert_eq!(code, "blocked");
                assert_eq!(message, "recipient blocked sender");
            }
            other => panic!("expected blocked error, got {other:?}"),
        }

        let _ = socket.close(None).await;
        server_handle.abort();
    }

    #[tokio::test]
    async fn ws_ping_returns_pong_after_signed_hello() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[44u8; 32]);
        let device_id = "dev_ws_ping_1";

        cache_authenticated_device(&state, device_id, "profile_ws_ping_1", &signing_key);

        let (url, server_handle) = start_test_ws_server(state).await;
        let (mut socket, _) = connect_async(&url).await.unwrap();
        socket
            .send(ClientWsMessage::Text(
                signed_ws_hello_text(device_id, &signing_key, "ws-ping").into(),
            ))
            .await
            .unwrap();
        expect_ws_welcome(&mut socket, device_id, 1).await;

        let ping = serde_json::to_string(&ClientMsg::Ping).unwrap();
        socket
            .send(ClientWsMessage::Text(ping.into()))
            .await
            .unwrap();

        match recv_ws_server_msg(&mut socket).await {
            ServerMsg::Pong => {}
            other => panic!("expected pong, got {other:?}"),
        }

        let _ = socket.close(None).await;
        server_handle.abort();
    }

    #[tokio::test]
    async fn ws_ack_removes_pending_message_for_authenticated_device() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[45u8; 32]);
        let device_id = "dev_ws_ack_1";
        let msg_id = "msg-ws-ack-1";

        cache_authenticated_device(&state, device_id, "profile_ws_ack_1", &signing_key);
        state
            .store
            .enqueue(device_id, msg_id, "QUJD", None, 60, now_ms())
            .await
            .unwrap();

        let (url, server_handle) = start_test_ws_server(state.clone()).await;
        let (mut socket, _) = connect_async(&url).await.unwrap();
        socket
            .send(ClientWsMessage::Text(
                signed_ws_hello_text(device_id, &signing_key, "ws-ack-ok").into(),
            ))
            .await
            .unwrap();
        expect_ws_welcome(&mut socket, device_id, 1).await;

        let deliver = recv_ws_server_msg(&mut socket).await;
        let seq = match deliver {
            ServerMsg::Deliver {
                device_id: deliver_device_id,
                seq,
                msg_id: deliver_msg_id,
                ..
            } => {
                assert_eq!(deliver_device_id, device_id);
                assert_eq!(deliver_msg_id, msg_id);
                seq
            }
            other => panic!("expected deliver message, got {other:?}"),
        };

        let ack = serde_json::to_string(&ClientMsg::Ack {
            device_id: device_id.to_string(),
            seq,
            msg_id: msg_id.to_string(),
        })
        .unwrap();
        socket
            .send(ClientWsMessage::Text(ack.into()))
            .await
            .unwrap();

        wait_until_pending_absent(&state, device_id, msg_id).await;

        let _ = socket.close(None).await;
        server_handle.abort();
    }

    #[tokio::test]
    async fn ws_ack_rejects_device_id_mismatch() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[46u8; 32]);
        let device_id = "dev_ws_ack_mismatch_1";

        cache_authenticated_device(&state, device_id, "profile_ws_ack_mismatch_1", &signing_key);

        let (url, server_handle) = start_test_ws_server(state).await;
        let (mut socket, _) = connect_async(&url).await.unwrap();
        socket
            .send(ClientWsMessage::Text(
                signed_ws_hello_text(device_id, &signing_key, "ws-ack-mismatch").into(),
            ))
            .await
            .unwrap();
        expect_ws_welcome(&mut socket, device_id, 1).await;

        let ack = serde_json::to_string(&ClientMsg::Ack {
            device_id: "dev_ws_ack_other_1".to_string(),
            seq: 1,
            msg_id: "msg-other".to_string(),
        })
        .unwrap();
        socket
            .send(ClientWsMessage::Text(ack.into()))
            .await
            .unwrap();

        match recv_ws_server_msg(&mut socket).await {
            ServerMsg::Error { code, message } => {
                assert_eq!(code, "bad_request");
                assert_eq!(message, "ack device_id mismatch");
            }
            other => panic!("expected ack mismatch error, got {other:?}"),
        }

        let _ = socket.close(None).await;
        server_handle.abort();
    }

    #[tokio::test]
    async fn ws_fetch_pending_returns_messages_after_signed_hello() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[47u8; 32]);
        let device_id = "dev_ws_fetch_1";
        let msg_id = "msg-ws-fetch-1";

        cache_authenticated_device(&state, device_id, "profile_ws_fetch_1", &signing_key);

        let (url, server_handle) = start_test_ws_server(state.clone()).await;
        let (mut socket, _) = connect_async(&url).await.unwrap();
        socket
            .send(ClientWsMessage::Text(
                signed_ws_hello_text(device_id, &signing_key, "ws-fetch-ok").into(),
            ))
            .await
            .unwrap();
        expect_ws_welcome(&mut socket, device_id, 1).await;

        state
            .store
            .enqueue(device_id, msg_id, "QUJD", None, 60, now_ms())
            .await
            .unwrap();

        let fetch_pending = serde_json::to_string(&ClientMsg::FetchPending {
            device_id: device_id.to_string(),
            from_seq: 1,
        })
        .unwrap();
        socket
            .send(ClientWsMessage::Text(fetch_pending.into()))
            .await
            .unwrap();

        match recv_ws_server_msg(&mut socket).await {
            ServerMsg::Deliver {
                device_id: deliver_device_id,
                seq,
                msg_id: deliver_msg_id,
                ciphertext_b64,
                transport_meta_json,
                ..
            } => {
                assert_eq!(deliver_device_id, device_id);
                assert_eq!(seq, 1);
                assert_eq!(deliver_msg_id, msg_id);
                assert_eq!(ciphertext_b64, "QUJD");
                assert_eq!(transport_meta_json, None);
            }
            other => panic!("expected fetch_pending delivery, got {other:?}"),
        }

        let _ = socket.close(None).await;
        server_handle.abort();
    }

    #[tokio::test]
    async fn ws_fetch_pending_rejects_device_id_mismatch() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[48u8; 32]);
        let device_id = "dev_ws_fetch_mismatch_1";

        cache_authenticated_device(
            &state,
            device_id,
            "profile_ws_fetch_mismatch_1",
            &signing_key,
        );

        let (url, server_handle) = start_test_ws_server(state).await;
        let (mut socket, _) = connect_async(&url).await.unwrap();
        socket
            .send(ClientWsMessage::Text(
                signed_ws_hello_text(device_id, &signing_key, "ws-fetch-mismatch").into(),
            ))
            .await
            .unwrap();
        expect_ws_welcome(&mut socket, device_id, 1).await;

        let fetch_pending = serde_json::to_string(&ClientMsg::FetchPending {
            device_id: "dev_ws_fetch_other_1".to_string(),
            from_seq: 1,
        })
        .unwrap();
        socket
            .send(ClientWsMessage::Text(fetch_pending.into()))
            .await
            .unwrap();

        match recv_ws_server_msg(&mut socket).await {
            ServerMsg::Error { code, message } => {
                assert_eq!(code, "bad_request");
                assert_eq!(message, "fetch_pending device_id mismatch");
            }
            other => panic!("expected fetch_pending mismatch error, got {other:?}"),
        }

        let _ = socket.close(None).await;
        server_handle.abort();
    }

    #[tokio::test]
    async fn ws_rejects_non_hello_first_message() {
        let (state, _dir) = test_app_state().await;

        let (url, server_handle) = start_test_ws_server(state).await;
        let (mut socket, _) = connect_async(&url).await.unwrap();
        let ping = serde_json::to_string(&ClientMsg::Ping).unwrap();
        socket
            .send(ClientWsMessage::Text(ping.into()))
            .await
            .unwrap();

        match recv_ws_server_msg(&mut socket).await {
            ServerMsg::Error { code, message } => {
                assert_eq!(code, "bad_handshake");
                assert!(message.contains("expected hello first"));
            }
            other => panic!("expected bad_handshake error, got {other:?}"),
        }

        let _ = socket.close(None).await;
        server_handle.abort();
    }

    #[tokio::test]
    async fn http_welcome_accepts_valid_signature_and_rejects_replayed_nonce() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[31u8; 32]);
        let device_id = "dev_welcome_1";

        cache_authenticated_device(&state, device_id, "profile_welcome_1", &signing_key);
        let headers = signed_auth_headers(
            device_id,
            &signing_key,
            "welcome-replay",
            |ts_ms, nonce_b64| http_welcome_auth_message(device_id, ts_ms, nonce_b64),
        );

        let response = http_welcome(
            Path(device_id.to_string()),
            headers.clone(),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;
        assert_eq!(response.device_id, device_id);
        assert_eq!(response.next_seq, 1);

        let replay_err =
            match http_welcome(Path(device_id.to_string()), headers, State(state)).await {
                Ok(_) => panic!("expected replayed nonce to be rejected"),
                Err(err) => err,
            };
        assert_eq!(replay_err.0, StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn http_pending_returns_items_for_valid_signed_request() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[32u8; 32]);
        let device_id = "dev_pending_1";

        cache_authenticated_device(&state, device_id, "profile_pending_1", &signing_key);
        state
            .store
            .enqueue(device_id, "msg-pending-1", "QUJD", None, 60, now_ms())
            .await
            .unwrap();

        let headers = signed_auth_headers(
            device_id,
            &signing_key,
            "pending-fetch",
            |ts_ms, nonce_b64| http_pending_auth_message(device_id, 1, 10, ts_ms, nonce_b64),
        );

        let response = http_pending(
            Path(device_id.to_string()),
            Query(PendingQuery {
                from_seq: Some(1),
                limit: Some(10),
            }),
            headers,
            State(state),
        )
        .await
        .unwrap()
        .0;

        assert_eq!(response.device_id, device_id);
        assert_eq!(response.items.len(), 1);
        assert_eq!(response.items[0].seq, 1);
        assert_eq!(response.items[0].msg_id, "msg-pending-1");
        assert_eq!(response.items[0].ciphertext_b64, "QUJD");
    }

    #[tokio::test]
    async fn http_send_rejects_blocked_sender_with_valid_auth() {
        let (state, _dir) = test_app_state().await;
        let sender_key = SigningKey::from_bytes(&[33u8; 32]);
        let receiver_key = SigningKey::from_bytes(&[34u8; 32]);
        let sender_device_id = "dev_sender_1";
        let receiver_device_id = "dev_receiver_1";
        let sender_profile_id = "profile_sender_1";
        let receiver_profile_id = "profile_receiver_1";
        let req = HttpSendReq {
            deliver_at_ms: None,
            to_device_id: receiver_device_id.to_string(),
            msg_id: "00000000-0000-0000-0000-000000000031".into(),
            ciphertext_b64: "QUJD".into(),
            transport_meta_json: None,
            ttl_seconds: 60,
        };

        cache_authenticated_device(&state, sender_device_id, sender_profile_id, &sender_key);
        cache_authenticated_device(
            &state,
            receiver_device_id,
            receiver_profile_id,
            &receiver_key,
        );
        state
            .store
            .set_block(receiver_profile_id, sender_profile_id, true, now_ms())
            .await
            .unwrap();

        let headers = signed_auth_headers(
            sender_device_id,
            &sender_key,
            "send-blocked",
            |ts_ms, nonce_b64| {
                http_send_auth_message(
                    sender_device_id,
                    receiver_device_id,
                    &req.msg_id,
                    &req.ciphertext_b64,
                    req.transport_meta_json.as_deref(),
                    req.ttl_seconds,
                    ts_ms,
                    nonce_b64,
                )
            },
        );

        let err = match http_send(State(state.clone()), headers, Json(req)).await {
            Ok(_) => panic!("expected blocked sender to be rejected"),
            Err(err) => err,
        };
        assert_eq!(err.0, StatusCode::FORBIDDEN);

        let pending = state
            .store
            .list_pending_from(receiver_device_id, 1, now_ms(), 10)
            .await
            .unwrap();
        assert!(pending.is_empty());
    }

    #[tokio::test]
    async fn http_send_enqueues_message_for_valid_signed_request() {
        let (state, _dir) = test_app_state().await;
        let sender_key = SigningKey::from_bytes(&[35u8; 32]);
        let receiver_key = SigningKey::from_bytes(&[36u8; 32]);
        let sender_device_id = "dev_sender_2";
        let receiver_device_id = "dev_receiver_2";
        let req = HttpSendReq {
            deliver_at_ms: None,
            to_device_id: receiver_device_id.to_string(),
            msg_id: "00000000-0000-0000-0000-000000000032".into(),
            ciphertext_b64: "QUJD".into(),
            transport_meta_json: None,
            ttl_seconds: 60,
        };

        cache_authenticated_device(&state, sender_device_id, "profile_sender_2", &sender_key);
        cache_authenticated_device(
            &state,
            receiver_device_id,
            "profile_receiver_2",
            &receiver_key,
        );

        let headers = signed_auth_headers(
            sender_device_id,
            &sender_key,
            "send-success",
            |ts_ms, nonce_b64| {
                http_send_auth_message(
                    sender_device_id,
                    receiver_device_id,
                    &req.msg_id,
                    &req.ciphertext_b64,
                    req.transport_meta_json.as_deref(),
                    req.ttl_seconds,
                    ts_ms,
                    nonce_b64,
                )
            },
        );

        let response = http_send(State(state.clone()), headers, Json(req))
            .await
            .unwrap()
            .0;
        assert!(response.ok);
        assert_eq!(response.seq, 1);

        let pending = state
            .store
            .list_pending_from(receiver_device_id, 1, now_ms(), 10)
            .await
            .unwrap();
        assert_eq!(pending.len(), 1);
        assert_eq!(pending[0].msg_id, "00000000-0000-0000-0000-000000000032");
        assert_eq!(pending[0].ciphertext_b64, "QUJD");
        // ИД-1 / С-1: the authenticated sender travels with the row.
        assert_eq!(pending[0].from_device_id.as_deref(), Some(sender_device_id));
    }

    #[test]
    fn deliver_frame_names_the_sender_only_when_known() {
        // ИД-1 / С-1: a legacy row (no sender) serialises exactly as before, so
        // released clients see the same frame; a known sender adds one field.
        let legacy = serde_json::to_value(ServerMsg::Deliver {
            device_id: "d".into(),
            seq: 1,
            msg_id: "m".into(),
            ciphertext_b64: "QQ".into(),
            transport_meta_json: None,
            from_device_id: None,
        })
        .unwrap();
        assert!(legacy.get("from_device_id").is_none());
        let attested = serde_json::to_value(ServerMsg::Deliver {
            device_id: "d".into(),
            seq: 1,
            msg_id: "m".into(),
            ciphertext_b64: "QQ".into(),
            transport_meta_json: None,
            from_device_id: Some("sender".into()),
        })
        .unwrap();
        assert_eq!(attested["from_device_id"], "sender");
        assert_eq!(attested["type"], "deliver");
    }

    #[tokio::test]
    async fn http_ack_removes_pending_for_valid_signed_request() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[39u8; 32]);
        let device_id = "dev_ack_1";
        let msg_id = "msg-ack-1";

        cache_authenticated_device(&state, device_id, "profile_ack_1", &signing_key);
        state
            .store
            .enqueue(device_id, msg_id, "QUJD", None, 60, now_ms())
            .await
            .unwrap();

        let headers =
            signed_auth_headers(device_id, &signing_key, "ack-valid", |ts_ms, nonce_b64| {
                http_ack_auth_message(device_id, 1, ts_ms, nonce_b64)
            });

        let response = http_ack(
            State(state.clone()),
            headers,
            Json(HttpAckReq {
                device_id: device_id.into(),
                seq: 1,
                msg_id: Some(msg_id.into()),
            }),
        )
        .await
        .unwrap()
        .0;
        assert!(response.ok);
        assert!(
            !state
                .store
                .has_pending_msg(device_id, msg_id, now_ms())
                .await
                .unwrap()
        );
    }

    #[tokio::test]
    async fn http_cancel_scheduled_removes_only_future_held_rows() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[41u8; 32]);
        let canceller = "dev_cancel_sender_1";
        let mailbox = "dev_cancel_recipient_1";
        let msg_id = "00000000-0000-0000-0000-0000000000c1";

        cache_authenticated_device(&state, canceller, "profile_cancel_1", &signing_key);
        let deliver_at = now_ms() + 120_000;
        state
            .store
            .enqueue_scheduled(
                mailbox,
                msg_id,
                "QUJD",
                None,
                3600,
                now_ms(),
                deliver_at,
                None,
            )
            .await
            .unwrap();

        let headers = signed_auth_headers(
            canceller,
            &signing_key,
            "cancel-sched-1",
            |ts_ms, nonce_b64| {
                http_cancel_scheduled_auth_message(canceller, mailbox, msg_id, ts_ms, nonce_b64)
            },
        );
        let response = http_cancel_scheduled(
            State(state.clone()),
            headers,
            Json(HttpCancelScheduledReq {
                device_id: canceller.into(),
                to_device_id: mailbox.into(),
                msg_id: msg_id.into(),
            }),
        )
        .await
        .unwrap()
        .0;
        assert!(response.cancelled, "future held row must be retractable");
        assert!(
            !state
                .store
                .has_pending_msg(mailbox, msg_id, now_ms())
                .await
                .unwrap()
        );

        // A second cancel finds nothing — and, critically, a row whose release
        // time has PASSED refuses to cancel (an already-released message can
        // never be silently unsent).
        let released = "00000000-0000-0000-0000-0000000000c2";
        state
            .store
            .enqueue_scheduled(
                mailbox,
                released,
                "QUJD",
                None,
                3600,
                now_ms(),
                now_ms() - 1,
                None,
            )
            .await
            .unwrap();
        let headers2 = signed_auth_headers(
            canceller,
            &signing_key,
            "cancel-sched-2",
            |ts_ms, nonce_b64| {
                http_cancel_scheduled_auth_message(canceller, mailbox, released, ts_ms, nonce_b64)
            },
        );
        let response2 = http_cancel_scheduled(
            State(state.clone()),
            headers2,
            Json(HttpCancelScheduledReq {
                device_id: canceller.into(),
                to_device_id: mailbox.into(),
                msg_id: released.into(),
            }),
        )
        .await
        .unwrap()
        .0;
        assert!(!response2.cancelled, "released rows must never be unsent");
    }

    #[tokio::test]
    async fn http_room_create_persists_authoritative_room_for_valid_signed_request() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[52u8; 32]);
        let device_id = "dev_room_create_1";
        let profile_id = "profile_room_create_1";
        let room_id = "room_alpha_1";

        cache_authenticated_device(&state, device_id, profile_id, &signing_key);

        let response = http_room_create(
            State(state.clone()),
            signed_room_create_headers(
                device_id,
                &signing_key,
                room_id,
                "Launch Team",
                "room-create",
            ),
            Json(HttpRoomCreateReq {
                room_id: room_id.into(),
                title: "Launch Team".into(),
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert!(response.created);
        assert_eq!(response.room.room_id, room_id);
        assert_eq!(response.room.version, 1);
        assert_eq!(response.room.membership_version, 1);
        assert_eq!(response.room.owner_profile_id, profile_id);
        assert_eq!(response.room.created_by_device_id, device_id);
        assert_eq!(response.room.title, "Launch Team");

        let stored = state.store.get_room(room_id).await.unwrap().unwrap();
        assert_eq!(stored.membership_version, 1);
        assert_eq!(stored.owner_profile_id, profile_id);
        assert_eq!(stored.created_by_device_id, device_id);
        assert_eq!(stored.title, "Launch Team");
    }

    #[tokio::test]
    async fn http_room_create_is_idempotent_for_same_authoritative_metadata() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[53u8; 32]);
        let device_id = "dev_room_create_2";
        let room_id = "room_alpha_2";

        cache_authenticated_device(&state, device_id, "profile_room_create_2", &signing_key);

        let first = http_room_create(
            State(state.clone()),
            signed_room_create_headers(
                device_id,
                &signing_key,
                room_id,
                "Project Atlas",
                "room-create-first",
            ),
            Json(HttpRoomCreateReq {
                room_id: room_id.into(),
                title: "Project Atlas".into(),
            }),
        )
        .await
        .unwrap()
        .0;
        let second = http_room_create(
            State(state.clone()),
            signed_room_create_headers(
                device_id,
                &signing_key,
                room_id,
                "Project Atlas",
                "room-create-second",
            ),
            Json(HttpRoomCreateReq {
                room_id: room_id.into(),
                title: "Project Atlas".into(),
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(first.created);
        assert!(!second.created);
        assert_eq!(second.room.version, 1);
        assert_eq!(second.room.membership_version, 1);
        assert_eq!(second.room.title, "Project Atlas");
    }

    #[tokio::test]
    async fn http_room_create_rejects_conflicting_authoritative_metadata() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[54u8; 32]);
        let device_id = "dev_room_create_3";
        let room_id = "room_alpha_3";

        cache_authenticated_device(&state, device_id, "profile_room_create_3", &signing_key);

        let _ = http_room_create(
            State(state.clone()),
            signed_room_create_headers(
                device_id,
                &signing_key,
                room_id,
                "Team Mercury",
                "room-create-ok",
            ),
            Json(HttpRoomCreateReq {
                room_id: room_id.into(),
                title: "Team Mercury".into(),
            }),
        )
        .await
        .unwrap();

        let err = http_room_create(
            State(state.clone()),
            signed_room_create_headers(
                device_id,
                &signing_key,
                room_id,
                "Team Mercury v2",
                "room-create-conflict",
            ),
            Json(HttpRoomCreateReq {
                room_id: room_id.into(),
                title: "Team Mercury v2".into(),
            }),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::CONFLICT);

        let stored = state.store.get_room(room_id).await.unwrap().unwrap();
        assert_eq!(stored.title, "Team Mercury");
        assert_eq!(stored.version, 1);
        assert_eq!(stored.membership_version, 1);
    }

    #[tokio::test]
    async fn http_room_get_returns_authoritative_room_metadata() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[55u8; 32]);
        let device_id = "dev_room_get_1";
        let profile_id = "profile_room_get_1";
        let room_id = "room_alpha_get_1";

        cache_authenticated_device(&state, device_id, profile_id, &signing_key);
        state
            .store
            .create_room(room_id, profile_id, device_id, "Ops Bridge", now_ms())
            .await
            .unwrap();

        let response = http_room_get(
            Path(room_id.to_string()),
            signed_room_get_headers(device_id, &signing_key, room_id, "room-get"),
            State(state),
        )
        .await
        .unwrap()
        .0;

        assert_eq!(response.room_id, room_id);
        assert_eq!(response.version, 1);
        assert_eq!(response.membership_version, 1);
        assert_eq!(response.owner_profile_id, profile_id);
        assert_eq!(response.created_by_device_id, device_id);
        assert_eq!(response.title, "Ops Bridge");
    }

    #[tokio::test]
    async fn http_room_get_rejects_non_member_requester() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[57u8; 32]);
        let outsider_key = SigningKey::from_bytes(&[58u8; 32]);
        let room_id = "room_alpha_get_3";

        cache_authenticated_device(
            &state,
            "dev_room_owner_3",
            "profile_room_owner_3",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_outsider_3",
            "profile_room_outsider_3",
            &outsider_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_3",
                "dev_room_owner_3",
                "Restricted Room",
                now_ms(),
            )
            .await
            .unwrap();

        let err = http_room_get(
            Path(room_id.to_string()),
            signed_room_get_headers(
                "dev_room_outsider_3",
                &outsider_key,
                room_id,
                "room-get-outsider",
            ),
            State(state),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::FORBIDDEN);
    }

    #[tokio::test]
    async fn http_room_get_returns_not_found_for_unknown_room() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[56u8; 32]);
        let device_id = "dev_room_get_2";

        cache_authenticated_device(&state, device_id, "profile_room_get_2", &signing_key);

        let err = http_room_get(
            Path("room_missing_1".to_string()),
            signed_room_get_headers(
                device_id,
                &signing_key,
                "room_missing_1",
                "room-get-missing",
            ),
            State(state),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn http_room_profile_update_allows_member_when_room_policy_enables_group_info_changes() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[87u8; 32]);
        let member_key = SigningKey::from_bytes(&[88u8; 32]);
        let room_id = "room_alpha_profile_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_profile_1",
            "profile_room_owner_profile_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_profile_1",
            "profile_room_member_profile_1",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_profile_1",
                "dev_room_owner_profile_1",
                "Profile Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_profile_1",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .update_room_settings(
                room_id,
                "all",
                true,
                true,
                true,
                true,
                true,
                false,
                false,
                0,
                false,
                now_ms(),
            )
            .await
            .unwrap();
        let before = state.store.get_room(room_id).await.unwrap().unwrap();

        let req = HttpRoomProfileUpdateReq {
            title: "Profile Room Renamed".into(),
            description: Some("Coordinated room profile update".into()),
            avatar_hash: Some("avatar-hash-1".into()),
            avatar_image_b64: Some("YXZhdGFyLXBheWxvYWQ=".into()),
            clear_avatar: false,
        };

        let response = http_room_profile_update(
            Path(room_id.to_string()),
            signed_room_profile_update_headers(
                "dev_room_member_profile_1",
                &member_key,
                room_id,
                &req,
                "room-profile-update-1",
            ),
            State(state.clone()),
            Json(req),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert!(response.changed);
        assert_eq!(response.room.room_id, room_id);
        assert_eq!(response.room.title, "Profile Room Renamed");
        assert_eq!(
            response.room.description.as_deref(),
            Some("Coordinated room profile update")
        );
        assert_eq!(response.room.avatar_hash.as_deref(), Some("avatar-hash-1"));
        assert_eq!(
            response.room.avatar_image_b64.as_deref(),
            Some("YXZhdGFyLXBheWxvYWQ=")
        );
        assert_eq!(response.room.version, before.version + 1);
        assert_eq!(response.room.membership_version, before.membership_version);

        let stored = state.store.get_room(room_id).await.unwrap().unwrap();
        assert_eq!(stored.title, "Profile Room Renamed");
        assert_eq!(
            stored.description.as_deref(),
            Some("Coordinated room profile update")
        );
        assert_eq!(stored.avatar_hash.as_deref(), Some("avatar-hash-1"));
        assert_eq!(
            stored.avatar_image_b64.as_deref(),
            Some("YXZhdGFyLXBheWxvYWQ=")
        );
    }

    #[tokio::test]
    async fn http_room_profile_update_rejects_member_when_room_policy_disables_group_info_changes()
    {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[89u8; 32]);
        let member_key = SigningKey::from_bytes(&[90u8; 32]);
        let room_id = "room_alpha_profile_2";

        cache_authenticated_device(
            &state,
            "dev_room_owner_profile_2",
            "profile_room_owner_profile_2",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_profile_2",
            "profile_room_member_profile_2",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_profile_2",
                "dev_room_owner_profile_2",
                "Profile Locked Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_profile_2",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .update_room_settings(
                room_id,
                "all",
                true,
                true,
                true,
                true,
                false,
                false,
                false,
                0,
                false,
                now_ms(),
            )
            .await
            .unwrap();

        let req = HttpRoomProfileUpdateReq {
            title: "Should Not Apply".into(),
            description: Some("blocked".into()),
            avatar_hash: None,
            avatar_image_b64: None,
            clear_avatar: false,
        };

        let err = http_room_profile_update(
            Path(room_id.to_string()),
            signed_room_profile_update_headers(
                "dev_room_member_profile_2",
                &member_key,
                room_id,
                &req,
                "room-profile-update-2",
            ),
            State(state.clone()),
            Json(req),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::FORBIDDEN);
        assert_eq!(err.1.0.code, "change_group_info_not_allowed");

        let stored = state.store.get_room(room_id).await.unwrap().unwrap();
        assert_eq!(stored.title, "Profile Locked Room");
        assert!(stored.description.is_none());
    }

    #[tokio::test]
    async fn http_room_message_admission_returns_authoritative_room_and_cooldown() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[93u8; 32]);
        let member_key = SigningKey::from_bytes(&[94u8; 32]);
        let room_id = "room_alpha_admission_1";
        let message_id = "00000000-0000-0000-0000-00000000a101";

        cache_authenticated_device(
            &state,
            "dev_room_owner_admission_1",
            "profile_room_owner_admission_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_admission_1",
            "profile_room_member_admission_1",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_admission_1",
                "dev_room_owner_admission_1",
                "Launch Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_admission_1",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .update_room_settings(
                room_id,
                "all",
                true,
                true,
                true,
                true,
                true,
                false,
                false,
                15,
                false,
                now_ms(),
            )
            .await
            .unwrap();

        let response = http_room_message_admission(
            Path(room_id.to_string()),
            signed_room_message_admission_headers(
                "dev_room_member_admission_1",
                &member_key,
                room_id,
                message_id,
                HttpRoomMessageKind::Text,
                "room-admission-ok",
            ),
            State(state.clone()),
            Json(HttpRoomMessageAdmissionReq {
                message_id: message_id.into(),
                kind: HttpRoomMessageKind::Text,
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert_eq!(response.message_id, message_id);
        assert_eq!(response.kind, HttpRoomMessageKind::Text);
        assert_eq!(response.room.room_id, room_id);
        assert_eq!(response.room.slow_mode_seconds, 15);
        assert_eq!(
            response.next_allowed_at_ms,
            Some(response.admitted_at_ms + 15_000)
        );
    }

    #[tokio::test]
    async fn http_room_message_admission_rejects_active_slow_mode_with_retry_metadata() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[95u8; 32]);
        let member_key = SigningKey::from_bytes(&[96u8; 32]);
        let room_id = "room_alpha_admission_2";

        cache_authenticated_device(
            &state,
            "dev_room_owner_admission_2",
            "profile_room_owner_admission_2",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_admission_2",
            "profile_room_member_admission_2",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_admission_2",
                "dev_room_owner_admission_2",
                "Launch Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_admission_2",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .update_room_settings(
                room_id,
                "all",
                true,
                true,
                true,
                true,
                true,
                false,
                false,
                20,
                false,
                now_ms(),
            )
            .await
            .unwrap();

        let first = http_room_message_admission(
            Path(room_id.to_string()),
            signed_room_message_admission_headers(
                "dev_room_member_admission_2",
                &member_key,
                room_id,
                "00000000-0000-0000-0000-00000000a201",
                HttpRoomMessageKind::Text,
                "room-admission-first",
            ),
            State(state.clone()),
            Json(HttpRoomMessageAdmissionReq {
                message_id: "00000000-0000-0000-0000-00000000a201".into(),
                kind: HttpRoomMessageKind::Text,
            }),
        )
        .await
        .unwrap()
        .0;

        let err = http_room_message_admission(
            Path(room_id.to_string()),
            signed_room_message_admission_headers(
                "dev_room_member_admission_2",
                &member_key,
                room_id,
                "00000000-0000-0000-0000-00000000a202",
                HttpRoomMessageKind::Text,
                "room-admission-second",
            ),
            State(state),
            Json(HttpRoomMessageAdmissionReq {
                message_id: "00000000-0000-0000-0000-00000000a202".into(),
                kind: HttpRoomMessageKind::Text,
            }),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::TOO_MANY_REQUESTS);
        assert_eq!(err.1.0.code, "slow_mode_active");
        assert_eq!(err.1.0.retry_after_seconds, Some(20));
        assert_eq!(err.1.0.next_allowed_at_ms, first.next_allowed_at_ms);
    }

    #[tokio::test]
    async fn http_room_message_admission_rejects_media_when_room_disables_member_uploads() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[97u8; 32]);
        let member_key = SigningKey::from_bytes(&[98u8; 32]);
        let room_id = "room_alpha_admission_3";

        cache_authenticated_device(
            &state,
            "dev_room_owner_admission_3",
            "profile_room_owner_admission_3",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_admission_3",
            "profile_room_member_admission_3",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_admission_3",
                "dev_room_owner_admission_3",
                "Media Locked Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_admission_3",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .update_room_settings(
                room_id,
                "all",
                true,
                false,
                true,
                true,
                true,
                false,
                false,
                0,
                false,
                now_ms(),
            )
            .await
            .unwrap();

        let err = http_room_message_admission(
            Path(room_id.to_string()),
            signed_room_message_admission_headers(
                "dev_room_member_admission_3",
                &member_key,
                room_id,
                "00000000-0000-0000-0000-00000000a301",
                HttpRoomMessageKind::Media,
                "room-admission-media-denied",
            ),
            State(state),
            Json(HttpRoomMessageAdmissionReq {
                message_id: "00000000-0000-0000-0000-00000000a301".into(),
                kind: HttpRoomMessageKind::Media,
            }),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::FORBIDDEN);
        assert_eq!(err.1.0.code, "media_disabled");
        assert_eq!(err.1.0.retry_after_seconds, None);
        assert_eq!(err.1.0.next_allowed_at_ms, None);
    }

    #[tokio::test]
    async fn http_room_settings_update_round_trip_for_admin() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[95u8; 32]);
        let admin_key = SigningKey::from_bytes(&[96u8; 32]);
        let room_id = "room_alpha_settings_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_settings_1",
            "profile_room_owner_settings_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_admin_settings_1",
            "profile_room_admin_settings_1",
            &admin_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_settings_1",
                "dev_room_owner_settings_1",
                "Settings Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_admin_settings_1",
                "active",
                "admin",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let req = HttpRoomSettingsUpdateReq {
            reactions_mode: "selected".into(),
            allow_text: true,
            allow_media: false,
            allow_add_members: false,
            allow_pin_messages: false,
            allow_change_group_info: true,
            allow_change_tag: true,
            join_approval_required: true,
            slow_mode_seconds: 45,
            chat_history_visible: true,
        };

        let response = http_room_settings_update(
            Path(room_id.to_string()),
            signed_room_settings_update_headers(
                "dev_room_admin_settings_1",
                &admin_key,
                room_id,
                &req,
                "room-settings-update-1",
            ),
            State(state.clone()),
            Json(req),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert!(response.changed);
        assert_eq!(response.room.room_id, room_id);
        assert_eq!(response.room.version, 3);
        assert_eq!(response.room.membership_version, 2);
        assert_eq!(response.room.reactions_mode, "selected");
        assert!(response.room.allow_text);
        assert!(!response.room.allow_media);
        assert!(!response.room.allow_add_members);
        assert!(!response.room.allow_pin_messages);
        assert!(response.room.allow_change_group_info);
        assert!(response.room.allow_change_tag);
        assert!(response.room.join_approval_required);
        assert_eq!(response.room.slow_mode_seconds, 45);
        assert!(response.room.chat_history_visible);

        let stored = state.store.get_room(room_id).await.unwrap().unwrap();
        assert_eq!(stored.reactions_mode, "selected");
        assert!(stored.allow_text);
        assert!(!stored.allow_media);
        assert!(!stored.allow_add_members);
        assert!(!stored.allow_pin_messages);
        assert!(stored.allow_change_group_info);
        assert!(stored.allow_change_tag);
        assert!(stored.join_approval_required);
        assert_eq!(stored.slow_mode_seconds, 45);
        assert!(stored.chat_history_visible);
    }

    #[tokio::test]
    async fn http_room_settings_update_rejects_non_admin_requester() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[97u8; 32]);
        let member_key = SigningKey::from_bytes(&[98u8; 32]);
        let room_id = "room_alpha_settings_2";

        cache_authenticated_device(
            &state,
            "dev_room_owner_settings_2",
            "profile_room_owner_settings_2",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_settings_2",
            "profile_room_member_settings_2",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_settings_2",
                "dev_room_owner_settings_2",
                "Settings Forbidden Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_settings_2",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let req = HttpRoomSettingsUpdateReq {
            reactions_mode: "all".into(),
            allow_text: true,
            allow_media: true,
            allow_add_members: false,
            allow_pin_messages: true,
            allow_change_group_info: true,
            allow_change_tag: false,
            join_approval_required: false,
            slow_mode_seconds: 0,
            chat_history_visible: false,
        };

        let err = http_room_settings_update(
            Path(room_id.to_string()),
            signed_room_settings_update_headers(
                "dev_room_member_settings_2",
                &member_key,
                room_id,
                &req,
                "room-settings-update-2",
            ),
            State(state),
            Json(req),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::FORBIDDEN);
        assert_eq!(err.1.0.code, "admin_only");
    }

    #[tokio::test]
    async fn http_room_pinned_message_set_updates_authoritative_room_state() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[99u8; 32]);
        let member_key = SigningKey::from_bytes(&[100u8; 32]);
        let room_id = "room_alpha_pin_1";
        let message_id = "00000000-0000-0000-0000-00000000c101";

        cache_authenticated_device(
            &state,
            "dev_room_owner_pin_1",
            "profile_room_owner_pin_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_pin_1",
            "profile_room_member_pin_1",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_pin_1",
                "dev_room_owner_pin_1",
                "Pinned Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_pin_1",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .admit_room_message(
                room_id,
                "profile_room_member_pin_1",
                message_id,
                "text",
                now_ms(),
            )
            .await
            .unwrap();

        let response = http_room_pinned_message_set(
            Path(room_id.to_string()),
            signed_room_pinned_message_set_headers(
                "dev_room_member_pin_1",
                &member_key,
                room_id,
                Some(message_id),
                "room-pin-ok",
            ),
            State(state.clone()),
            Json(HttpRoomPinnedMessageSetReq {
                message_id: Some(message_id.into()),
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert!(response.changed);
        assert_eq!(response.room.room_id, room_id);
        assert_eq!(response.room.pinned_message_id.as_deref(), Some(message_id));

        let stored = state.store.get_room(room_id).await.unwrap().unwrap();
        assert_eq!(stored.pinned_message_id.as_deref(), Some(message_id));
    }

    #[tokio::test]
    async fn http_room_pinned_message_set_rejects_non_admitted_message_ids() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[101u8; 32]);
        let member_key = SigningKey::from_bytes(&[102u8; 32]);
        let room_id = "room_alpha_pin_2";
        let message_id = "00000000-0000-0000-0000-00000000c201";

        cache_authenticated_device(
            &state,
            "dev_room_owner_pin_2",
            "profile_room_owner_pin_2",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_pin_2",
            "profile_room_member_pin_2",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_pin_2",
                "dev_room_owner_pin_2",
                "Pinned Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_pin_2",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let err = http_room_pinned_message_set(
            Path(room_id.to_string()),
            signed_room_pinned_message_set_headers(
                "dev_room_member_pin_2",
                &member_key,
                room_id,
                Some(message_id),
                "room-pin-missing",
            ),
            State(state),
            Json(HttpRoomPinnedMessageSetReq {
                message_id: Some(message_id.into()),
            }),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::NOT_FOUND);
        assert_eq!(err.1.0.code, "message_not_found");
        assert_eq!(err.1.0.retry_after_seconds, None);
        assert_eq!(err.1.0.next_allowed_at_ms, None);
    }

    #[tokio::test]
    async fn http_room_member_tag_set_updates_authoritative_membership_when_allowed() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[103u8; 32]);
        let member_key = SigningKey::from_bytes(&[104u8; 32]);
        let room_id = "room_alpha_tag_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_tag_1",
            "profile_room_owner_tag_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_tag_1",
            "profile_room_member_tag_1",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_tag_1",
                "dev_room_owner_tag_1",
                "Tag Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_tag_1",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .update_room_settings(
                room_id,
                "all",
                true,
                true,
                true,
                true,
                true,
                true,
                false,
                0,
                false,
                now_ms(),
            )
            .await
            .unwrap();

        let response = http_room_member_tag_set(
            Path(room_id.to_string()),
            signed_room_member_tag_set_headers(
                "dev_room_member_tag_1",
                &member_key,
                room_id,
                Some("alpha-crew"),
                "room-member-tag-1",
            ),
            State(state.clone()),
            Json(HttpRoomMemberTagSetReq {
                tag: Some("alpha-crew".into()),
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert!(response.changed);
        assert_eq!(response.room.room_id, room_id);
        assert!(response.room.allow_change_tag);
        assert_eq!(response.membership.profile_id, "profile_room_member_tag_1");
        assert_eq!(response.membership.role, HttpRoomMemberRole::Member);
        assert_eq!(response.membership.tag.as_deref(), Some("alpha-crew"));

        let stored = state
            .store
            .get_room_membership(room_id, "profile_room_member_tag_1")
            .await
            .unwrap()
            .unwrap();
        assert_eq!(stored.tag.as_deref(), Some("alpha-crew"));
    }

    #[tokio::test]
    async fn http_room_member_tag_set_rejects_member_when_room_disallows_tag_changes() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[105u8; 32]);
        let member_key = SigningKey::from_bytes(&[106u8; 32]);
        let room_id = "room_alpha_tag_2";

        cache_authenticated_device(
            &state,
            "dev_room_owner_tag_2",
            "profile_room_owner_tag_2",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_tag_2",
            "profile_room_member_tag_2",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_tag_2",
                "dev_room_owner_tag_2",
                "Tag Forbidden Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_tag_2",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let err = http_room_member_tag_set(
            Path(room_id.to_string()),
            signed_room_member_tag_set_headers(
                "dev_room_member_tag_2",
                &member_key,
                room_id,
                Some("blocked-tag"),
                "room-member-tag-2",
            ),
            State(state),
            Json(HttpRoomMemberTagSetReq {
                tag: Some("blocked-tag".into()),
            }),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::FORBIDDEN);
        assert_eq!(err.1.0.code, "change_tag_not_allowed");
        assert_eq!(err.1.0.retry_after_seconds, None);
        assert_eq!(err.1.0.next_allowed_at_ms, None);
    }

    #[tokio::test]
    async fn http_room_members_list_returns_authoritative_memberships_for_active_member() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[59u8; 32]);
        let member_key = SigningKey::from_bytes(&[60u8; 32]);
        let room_id = "room_alpha_members_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_4",
            "profile_room_owner_4",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_4",
            "profile_room_member_4",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_4",
                "dev_room_owner_4",
                "Roster Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_4",
                "active",
                "moderator",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_pending_4",
                "pending",
                "guest",
                Some("link-alpha-members-1"),
                now_ms(),
            )
            .await
            .unwrap();

        let response = http_room_members_list(
            Path(room_id.to_string()),
            signed_room_members_list_headers(
                "dev_room_member_4",
                &member_key,
                room_id,
                "room-members-list",
            ),
            State(state),
        )
        .await
        .unwrap()
        .0;

        assert_eq!(response.room.room_id, room_id);
        assert_eq!(response.room.version, 3);
        assert_eq!(response.room.membership_version, 3);
        assert_eq!(response.members.len(), 3);
        assert_eq!(response.members[0].profile_id, "profile_room_owner_4");
        assert_eq!(response.members[0].role, HttpRoomMemberRole::Owner);
        assert_eq!(response.members[1].profile_id, "profile_room_member_4");
        assert_eq!(response.members[1].status, HttpRoomMembershipStatus::Active);
        assert_eq!(response.members[1].role, HttpRoomMemberRole::Moderator);
        assert_eq!(response.members[2].profile_id, "profile_room_pending_4");
        assert_eq!(
            response.members[2].status,
            HttpRoomMembershipStatus::Pending
        );
        assert_eq!(
            response.members[2].source_link_id.as_deref(),
            Some("link-alpha-members-1")
        );
    }

    #[tokio::test]
    async fn http_room_members_list_rejects_non_member_requester() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[61u8; 32]);
        let outsider_key = SigningKey::from_bytes(&[62u8; 32]);
        let room_id = "room_alpha_members_2";

        cache_authenticated_device(
            &state,
            "dev_room_owner_5",
            "profile_room_owner_5",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_outsider_5",
            "profile_room_outsider_5",
            &outsider_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_5",
                "dev_room_owner_5",
                "Members Guard Room",
                now_ms(),
            )
            .await
            .unwrap();

        let err = http_room_members_list(
            Path(room_id.to_string()),
            signed_room_members_list_headers(
                "dev_room_outsider_5",
                &outsider_key,
                room_id,
                "room-members-list-outsider",
            ),
            State(state),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::FORBIDDEN);
    }

    #[tokio::test]
    async fn http_room_members_upsert_persists_authoritative_membership_for_owner() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[63u8; 32]);
        let room_id = "room_alpha_members_3";

        cache_authenticated_device(
            &state,
            "dev_room_owner_6",
            "profile_room_owner_6",
            &owner_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_6",
                "dev_room_owner_6",
                "Mutation Room",
                now_ms(),
            )
            .await
            .unwrap();

        let response = http_room_members_upsert(
            Path(room_id.to_string()),
            signed_room_members_upsert_headers(
                "dev_room_owner_6",
                &owner_key,
                room_id,
                "profile_room_member_6",
                HttpRoomMembershipStatus::Pending,
                HttpRoomMemberRole::Guest,
                Some("link-alpha-members-3"),
                "room-members-upsert-first",
            ),
            State(state.clone()),
            Json(HttpRoomMembershipUpsertReq {
                profile_id: "profile_room_member_6".into(),
                status: HttpRoomMembershipStatus::Pending,
                role: HttpRoomMemberRole::Guest,
                source_link_id: Some("link-alpha-members-3".into()),
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert!(response.changed);
        assert_eq!(response.room.version, 2);
        assert_eq!(response.room.membership_version, 2);
        assert_eq!(response.membership.profile_id, "profile_room_member_6");
        assert_eq!(
            response.membership.status,
            HttpRoomMembershipStatus::Pending
        );
        assert_eq!(response.membership.role, HttpRoomMemberRole::Guest);
        assert_eq!(
            response.membership.source_link_id.as_deref(),
            Some("link-alpha-members-3")
        );

        let stored = state
            .store
            .get_room_membership(room_id, "profile_room_member_6")
            .await
            .unwrap()
            .unwrap();
        assert_eq!(stored.status, "pending");
        assert_eq!(stored.role, "guest");
    }

    #[tokio::test]
    async fn http_room_members_upsert_allows_admin_to_change_non_admin_member_role() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[163u8; 32]);
        let admin_key = SigningKey::from_bytes(&[164u8; 32]);
        let room_id = "room_alpha_members_admin_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_admin_1",
            "profile_room_owner_admin_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_admin_1",
            "profile_room_admin_1",
            &admin_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_admin_1",
                "dev_room_owner_admin_1",
                "Admin Mutation Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_admin_1",
                "active",
                "admin",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_admin_1",
                "active",
                "moderator",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let response = http_room_members_upsert(
            Path(room_id.to_string()),
            signed_room_members_upsert_headers(
                "dev_room_admin_1",
                &admin_key,
                room_id,
                "profile_room_member_admin_1",
                HttpRoomMembershipStatus::Active,
                HttpRoomMemberRole::Guest,
                None,
                "room-members-upsert-admin-role-change",
            ),
            State(state.clone()),
            Json(HttpRoomMembershipUpsertReq {
                profile_id: "profile_room_member_admin_1".into(),
                status: HttpRoomMembershipStatus::Active,
                role: HttpRoomMemberRole::Guest,
                source_link_id: None,
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert!(response.changed);
        assert_eq!(response.membership.role, HttpRoomMemberRole::Guest);
        assert_eq!(response.membership.status, HttpRoomMembershipStatus::Active);

        let stored = state
            .store
            .get_room_membership(room_id, "profile_room_member_admin_1")
            .await
            .unwrap()
            .unwrap();
        assert_eq!(stored.role, "guest");
        assert_eq!(stored.status, "active");
    }

    #[tokio::test]
    async fn http_room_members_upsert_allows_moderator_to_ban_supported_member() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[165u8; 32]);
        let moderator_key = SigningKey::from_bytes(&[166u8; 32]);
        let room_id = "room_alpha_members_moderator_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_moderator_1",
            "profile_room_owner_moderator_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_moderator_1",
            "profile_room_moderator_1",
            &moderator_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_moderator_1",
                "dev_room_owner_moderator_1",
                "Moderator Mutation Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_moderator_1",
                "active",
                "moderator",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_moderator_1",
                "active",
                "restricted",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let response = http_room_members_upsert(
            Path(room_id.to_string()),
            signed_room_members_upsert_headers(
                "dev_room_moderator_1",
                &moderator_key,
                room_id,
                "profile_room_member_moderator_1",
                HttpRoomMembershipStatus::Banned,
                HttpRoomMemberRole::Member,
                None,
                "room-members-upsert-moderator-ban",
            ),
            State(state.clone()),
            Json(HttpRoomMembershipUpsertReq {
                profile_id: "profile_room_member_moderator_1".into(),
                status: HttpRoomMembershipStatus::Banned,
                role: HttpRoomMemberRole::Member,
                source_link_id: None,
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert!(response.changed);
        assert_eq!(response.membership.status, HttpRoomMembershipStatus::Banned);
        assert_eq!(response.membership.role, HttpRoomMemberRole::Member);
    }

    #[tokio::test]
    async fn http_room_members_upsert_treats_remove_after_left_as_idempotent_for_moderator() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[177u8; 32]);
        let moderator_key = SigningKey::from_bytes(&[178u8; 32]);
        let room_id = "room_alpha_members_left_remove_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_left_remove_1",
            "profile_room_owner_left_remove_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_moderator_left_remove_1",
            "profile_room_moderator_left_remove_1",
            &moderator_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_left_remove_1",
                "dev_room_owner_left_remove_1",
                "Left Remove Conflict Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_moderator_left_remove_1",
                "active",
                "moderator",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_left_remove_1",
                "active",
                "guest",
                Some("link-left-remove-http-1"),
                now_ms(),
            )
            .await
            .unwrap();

        let left = state
            .store
            .leave_room(room_id, "profile_room_member_left_remove_1", now_ms())
            .await
            .unwrap();

        let response = http_room_members_upsert(
            Path(room_id.to_string()),
            signed_room_members_upsert_headers(
                "dev_room_moderator_left_remove_1",
                &moderator_key,
                room_id,
                "profile_room_member_left_remove_1",
                HttpRoomMembershipStatus::Removed,
                HttpRoomMemberRole::Member,
                Some("link-left-remove-http-1"),
                "room-members-upsert-left-remove-noop",
            ),
            State(state.clone()),
            Json(HttpRoomMembershipUpsertReq {
                profile_id: "profile_room_member_left_remove_1".into(),
                status: HttpRoomMembershipStatus::Removed,
                role: HttpRoomMemberRole::Member,
                source_link_id: Some("link-left-remove-http-1".into()),
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert!(!response.changed);
        assert_eq!(response.room.version, left.room.version);
        assert_eq!(
            response.room.membership_version,
            left.room.membership_version
        );
        assert_eq!(response.room.updated_at_ms, left.room.updated_at_ms);
        assert_eq!(response.membership.status, HttpRoomMembershipStatus::Left);
        assert_eq!(response.membership.role, HttpRoomMemberRole::Guest);
        assert_eq!(
            response.membership.updated_at_ms,
            left.membership.updated_at_ms
        );
        assert_eq!(
            response.membership.source_link_id.as_deref(),
            Some("link-left-remove-http-1")
        );
    }

    #[tokio::test]
    async fn http_room_leave_round_trip_for_active_member() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[184u8; 32]);
        let member_key = SigningKey::from_bytes(&[185u8; 32]);
        let room_id = "room_alpha_leave_active_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_leave_active_1",
            "profile_room_owner_leave_active_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_leave_active_1",
            "profile_room_member_leave_active_1",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_leave_active_1",
                "dev_room_owner_leave_active_1",
                "Leave Active Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_leave_active_1",
                "active",
                "member",
                Some("link-leave-active-http-1"),
                now_ms(),
            )
            .await
            .unwrap();
        let before = state.store.get_room(room_id).await.unwrap().unwrap();

        let response = http_room_leave(
            Path(room_id.to_string()),
            signed_room_leave_headers(
                "dev_room_member_leave_active_1",
                &member_key,
                room_id,
                "room-leave-active-1",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert!(response.changed);
        assert_eq!(response.room.room_id, room_id);
        assert_eq!(response.room.version, before.version + 1);
        assert_eq!(
            response.room.membership_version,
            before.membership_version + 1
        );
        assert_eq!(response.membership.status, HttpRoomMembershipStatus::Left);
        assert_eq!(
            response.membership.source_link_id.as_deref(),
            Some("link-leave-active-http-1")
        );

        let stored = state
            .store
            .get_room_membership(room_id, "profile_room_member_leave_active_1")
            .await
            .unwrap()
            .unwrap();
        assert_eq!(stored.status, "left");
    }

    #[tokio::test]
    async fn http_room_leave_rejects_owner_when_other_active_members_exist() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[186u8; 32]);
        let member_key = SigningKey::from_bytes(&[187u8; 32]);
        let room_id = "room_alpha_leave_owner_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_leave_owner_1",
            "profile_room_owner_leave_owner_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_leave_owner_1",
            "profile_room_member_leave_owner_1",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_leave_owner_1",
                "dev_room_owner_leave_owner_1",
                "Leave Owner Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_leave_owner_1",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let err = http_room_leave(
            Path(room_id.to_string()),
            signed_room_leave_headers(
                "dev_room_owner_leave_owner_1",
                &owner_key,
                room_id,
                "room-leave-owner-1",
            ),
            State(state.clone()),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::CONFLICT);
        assert_eq!(err.1, "owner transfer required before leave");

        let stored = state.store.get_room(room_id).await.unwrap().unwrap();
        assert_eq!(stored.owner_profile_id, "profile_room_owner_leave_owner_1");
    }

    #[tokio::test]
    async fn http_room_leave_keeps_removed_and_banned_terminal_state_as_idempotent_noop() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[181u8; 32]);
        let removed_key = SigningKey::from_bytes(&[182u8; 32]);
        let banned_key = SigningKey::from_bytes(&[183u8; 32]);

        cache_authenticated_device(
            &state,
            "dev_room_owner_leave_terminal_1",
            "profile_room_owner_leave_terminal_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_leave_removed_1",
            "profile_room_member_leave_removed_1",
            &removed_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_leave_banned_1",
            "profile_room_member_leave_banned_1",
            &banned_key,
        );

        let removed_room_id = "room_alpha_leave_removed_1";
        state
            .store
            .create_room(
                removed_room_id,
                "profile_room_owner_leave_terminal_1",
                "dev_room_owner_leave_terminal_1",
                "Leave Removed Conflict HTTP Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                removed_room_id,
                "profile_room_member_leave_removed_1",
                "active",
                "guest",
                Some("link-leave-removed-http-1"),
                now_ms(),
            )
            .await
            .unwrap();
        let removed = state
            .store
            .upsert_room_membership(
                removed_room_id,
                "profile_room_member_leave_removed_1",
                "removed",
                "member",
                Some("link-leave-removed-http-1"),
                now_ms(),
            )
            .await
            .unwrap();

        let removed_response = http_room_leave(
            Path(removed_room_id.to_string()),
            signed_room_leave_headers(
                "dev_room_member_leave_removed_1",
                &removed_key,
                removed_room_id,
                "room-leave-removed-noop",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;

        assert!(removed_response.ok);
        assert!(!removed_response.changed);
        assert_eq!(removed_response.room.version, removed.room.version);
        assert_eq!(
            removed_response.room.membership_version,
            removed.room.membership_version
        );
        assert_eq!(
            removed_response.room.updated_at_ms,
            removed.room.updated_at_ms
        );
        assert_eq!(
            removed_response.membership.status,
            HttpRoomMembershipStatus::Removed
        );
        assert_eq!(removed_response.membership.role, HttpRoomMemberRole::Member);
        assert_eq!(
            removed_response.membership.updated_at_ms,
            removed.membership.updated_at_ms
        );
        assert_eq!(
            removed_response.membership.source_link_id.as_deref(),
            Some("link-leave-removed-http-1")
        );

        let banned_room_id = "room_alpha_leave_banned_1";
        state
            .store
            .create_room(
                banned_room_id,
                "profile_room_owner_leave_terminal_1",
                "dev_room_owner_leave_terminal_1",
                "Leave Banned Conflict HTTP Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                banned_room_id,
                "profile_room_member_leave_banned_1",
                "active",
                "guest",
                Some("link-leave-banned-http-1"),
                now_ms(),
            )
            .await
            .unwrap();
        let banned = state
            .store
            .upsert_room_membership(
                banned_room_id,
                "profile_room_member_leave_banned_1",
                "banned",
                "member",
                Some("link-leave-banned-http-1"),
                now_ms(),
            )
            .await
            .unwrap();

        let banned_response = http_room_leave(
            Path(banned_room_id.to_string()),
            signed_room_leave_headers(
                "dev_room_member_leave_banned_1",
                &banned_key,
                banned_room_id,
                "room-leave-banned-noop",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;

        assert!(banned_response.ok);
        assert!(!banned_response.changed);
        assert_eq!(banned_response.room.version, banned.room.version);
        assert_eq!(
            banned_response.room.membership_version,
            banned.room.membership_version
        );
        assert_eq!(
            banned_response.room.updated_at_ms,
            banned.room.updated_at_ms
        );
        assert_eq!(
            banned_response.membership.status,
            HttpRoomMembershipStatus::Banned
        );
        assert_eq!(banned_response.membership.role, HttpRoomMemberRole::Member);
        assert_eq!(
            banned_response.membership.updated_at_ms,
            banned.membership.updated_at_ms
        );
        assert_eq!(
            banned_response.membership.source_link_id.as_deref(),
            Some("link-leave-banned-http-1")
        );
    }

    #[tokio::test]
    async fn http_room_member_unban_requires_explicit_path_after_ban() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[179u8; 32]);
        let moderator_key = SigningKey::from_bytes(&[180u8; 32]);
        let room_id = "room_alpha_members_ban_remove_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_ban_remove_1",
            "profile_room_owner_ban_remove_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_moderator_ban_remove_1",
            "profile_room_moderator_ban_remove_1",
            &moderator_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_ban_remove_1",
                "dev_room_owner_ban_remove_1",
                "Ban Remove Conflict HTTP Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_moderator_ban_remove_1",
                "active",
                "moderator",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_ban_remove_1",
                "active",
                "guest",
                Some("link-ban-remove-http-1"),
                now_ms(),
            )
            .await
            .unwrap();
        let banned = state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_ban_remove_1",
                "banned",
                "member",
                Some("link-ban-remove-http-1"),
                now_ms(),
            )
            .await
            .unwrap();

        let remove_response = http_room_members_upsert(
            Path(room_id.to_string()),
            signed_room_members_upsert_headers(
                "dev_room_moderator_ban_remove_1",
                &moderator_key,
                room_id,
                "profile_room_member_ban_remove_1",
                HttpRoomMembershipStatus::Removed,
                HttpRoomMemberRole::Member,
                Some("link-ban-remove-http-1"),
                "room-members-upsert-ban-remove-noop",
            ),
            State(state.clone()),
            Json(HttpRoomMembershipUpsertReq {
                profile_id: "profile_room_member_ban_remove_1".into(),
                status: HttpRoomMembershipStatus::Removed,
                role: HttpRoomMemberRole::Member,
                source_link_id: Some("link-ban-remove-http-1".into()),
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(remove_response.ok);
        assert!(!remove_response.changed);
        assert_eq!(remove_response.room.version, banned.room.version);
        assert_eq!(
            remove_response.room.membership_version,
            banned.room.membership_version
        );
        assert_eq!(
            remove_response.membership.status,
            HttpRoomMembershipStatus::Banned
        );
        assert_eq!(
            remove_response.membership.source_link_id.as_deref(),
            Some("link-ban-remove-http-1")
        );

        let unban_response = http_room_member_unban(
            Path((
                room_id.to_string(),
                "profile_room_member_ban_remove_1".to_string(),
            )),
            signed_room_member_unban_headers(
                "dev_room_moderator_ban_remove_1",
                &moderator_key,
                room_id,
                "profile_room_member_ban_remove_1",
                "room-member-unban-first",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;

        assert!(unban_response.ok);
        assert!(unban_response.changed);
        assert_eq!(unban_response.room.version, banned.room.version + 1);
        assert_eq!(
            unban_response.room.membership_version,
            banned.room.membership_version + 1
        );
        assert_eq!(
            unban_response.membership.status,
            HttpRoomMembershipStatus::Removed
        );
        assert_eq!(unban_response.membership.role, HttpRoomMemberRole::Member);

        let unban_retry = http_room_member_unban(
            Path((
                room_id.to_string(),
                "profile_room_member_ban_remove_1".to_string(),
            )),
            signed_room_member_unban_headers(
                "dev_room_moderator_ban_remove_1",
                &moderator_key,
                room_id,
                "profile_room_member_ban_remove_1",
                "room-member-unban-retry",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;

        assert!(unban_retry.ok);
        assert!(!unban_retry.changed);
        assert_eq!(unban_retry.room.version, unban_response.room.version);
        assert_eq!(
            unban_retry.room.membership_version,
            unban_response.room.membership_version
        );
        assert_eq!(
            unban_retry.membership.status,
            HttpRoomMembershipStatus::Removed
        );
    }

    #[tokio::test]
    async fn http_room_members_upsert_is_idempotent_for_same_authoritative_state() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[64u8; 32]);
        let room_id = "room_alpha_members_4";

        cache_authenticated_device(
            &state,
            "dev_room_owner_7",
            "profile_room_owner_7",
            &owner_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_7",
                "dev_room_owner_7",
                "Idempotent Room",
                now_ms(),
            )
            .await
            .unwrap();

        let _first = http_room_members_upsert(
            Path(room_id.to_string()),
            signed_room_members_upsert_headers(
                "dev_room_owner_7",
                &owner_key,
                room_id,
                "profile_room_member_7",
                HttpRoomMembershipStatus::Active,
                HttpRoomMemberRole::Member,
                None,
                "room-members-upsert-idempotent-first",
            ),
            State(state.clone()),
            Json(HttpRoomMembershipUpsertReq {
                profile_id: "profile_room_member_7".into(),
                status: HttpRoomMembershipStatus::Active,
                role: HttpRoomMemberRole::Member,
                source_link_id: None,
            }),
        )
        .await
        .unwrap()
        .0;

        let second = http_room_members_upsert(
            Path(room_id.to_string()),
            signed_room_members_upsert_headers(
                "dev_room_owner_7",
                &owner_key,
                room_id,
                "profile_room_member_7",
                HttpRoomMembershipStatus::Active,
                HttpRoomMemberRole::Member,
                None,
                "room-members-upsert-idempotent-second",
            ),
            State(state),
            Json(HttpRoomMembershipUpsertReq {
                profile_id: "profile_room_member_7".into(),
                status: HttpRoomMembershipStatus::Active,
                role: HttpRoomMemberRole::Member,
                source_link_id: None,
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(second.ok);
        assert!(!second.changed);
        assert_eq!(second.room.version, 2);
        assert_eq!(second.room.membership_version, 2);
    }

    #[tokio::test]
    async fn http_room_members_upsert_allows_member_to_add_new_member_when_room_policy_enables_it()
    {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[171u8; 32]);
        let member_key = SigningKey::from_bytes(&[172u8; 32]);
        let room_id = "room_alpha_members_allow_add_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_allow_add_1",
            "profile_room_owner_allow_add_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_allow_add_1",
            "profile_room_member_allow_add_1",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_allow_add_1",
                "dev_room_owner_allow_add_1",
                "Allow Add Members Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_allow_add_1",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let response = http_room_members_upsert(
            Path(room_id.to_string()),
            signed_room_members_upsert_headers(
                "dev_room_member_allow_add_1",
                &member_key,
                room_id,
                "profile_room_added_allow_add_1",
                HttpRoomMembershipStatus::Active,
                HttpRoomMemberRole::Member,
                None,
                "room-members-upsert-member-add-1",
            ),
            State(state.clone()),
            Json(HttpRoomMembershipUpsertReq {
                profile_id: "profile_room_added_allow_add_1".into(),
                status: HttpRoomMembershipStatus::Active,
                role: HttpRoomMemberRole::Member,
                source_link_id: None,
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert!(response.changed);
        assert_eq!(response.membership.status, HttpRoomMembershipStatus::Active);
        assert_eq!(response.membership.role, HttpRoomMemberRole::Member);

        let stored = state
            .store
            .get_room_membership(room_id, "profile_room_added_allow_add_1")
            .await
            .unwrap()
            .unwrap();
        assert_eq!(stored.status, "active");
        assert_eq!(stored.role, "member");
    }

    #[tokio::test]
    async fn http_room_members_upsert_allows_member_to_reactivate_removed_supported_role() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[173u8; 32]);
        let member_key = SigningKey::from_bytes(&[174u8; 32]);
        let room_id = "room_alpha_members_allow_add_2";

        cache_authenticated_device(
            &state,
            "dev_room_owner_allow_add_2",
            "profile_room_owner_allow_add_2",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_allow_add_2",
            "profile_room_member_allow_add_2",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_allow_add_2",
                "dev_room_owner_allow_add_2",
                "Allow Reactivate Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_allow_add_2",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_readded_allow_add_2",
                "removed",
                "guest",
                Some("link-allow-add-2"),
                now_ms(),
            )
            .await
            .unwrap();

        let response = http_room_members_upsert(
            Path(room_id.to_string()),
            signed_room_members_upsert_headers(
                "dev_room_member_allow_add_2",
                &member_key,
                room_id,
                "profile_room_readded_allow_add_2",
                HttpRoomMembershipStatus::Active,
                HttpRoomMemberRole::Guest,
                Some("link-allow-add-2"),
                "room-members-upsert-member-reactivate-1",
            ),
            State(state.clone()),
            Json(HttpRoomMembershipUpsertReq {
                profile_id: "profile_room_readded_allow_add_2".into(),
                status: HttpRoomMembershipStatus::Active,
                role: HttpRoomMemberRole::Guest,
                source_link_id: Some("link-allow-add-2".into()),
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert!(response.changed);
        assert_eq!(response.membership.status, HttpRoomMembershipStatus::Active);
        assert_eq!(response.membership.role, HttpRoomMemberRole::Guest);
        assert_eq!(
            response.membership.source_link_id.as_deref(),
            Some("link-allow-add-2")
        );
    }

    #[tokio::test]
    async fn http_room_members_upsert_rejects_member_direct_add_when_room_policy_disables_it() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[65u8; 32]);
        let member_key = SigningKey::from_bytes(&[66u8; 32]);
        let room_id = "room_alpha_members_5";

        cache_authenticated_device(
            &state,
            "dev_room_owner_8",
            "profile_room_owner_8",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_8",
            "profile_room_member_8",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_8",
                "dev_room_owner_8",
                "Forbidden Mutation Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_8",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .update_room_settings(
                room_id,
                "all",
                true,
                true,
                false,
                true,
                true,
                false,
                false,
                0,
                false,
                now_ms(),
            )
            .await
            .unwrap();

        let err = http_room_members_upsert(
            Path(room_id.to_string()),
            signed_room_members_upsert_headers(
                "dev_room_member_8",
                &member_key,
                room_id,
                "profile_room_added_8",
                HttpRoomMembershipStatus::Active,
                HttpRoomMemberRole::Member,
                None,
                "room-members-upsert-forbidden-add-members",
            ),
            State(state),
            Json(HttpRoomMembershipUpsertReq {
                profile_id: "profile_room_added_8".into(),
                status: HttpRoomMembershipStatus::Active,
                role: HttpRoomMemberRole::Member,
                source_link_id: None,
            }),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::FORBIDDEN);
    }

    #[tokio::test]
    async fn http_room_members_upsert_rejects_member_pending_membership_creation() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[175u8; 32]);
        let member_key = SigningKey::from_bytes(&[176u8; 32]);
        let room_id = "room_alpha_members_5b";

        cache_authenticated_device(
            &state,
            "dev_room_owner_8b",
            "profile_room_owner_8b",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_8b",
            "profile_room_member_8b",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_8b",
                "dev_room_owner_8b",
                "Forbidden Pending Mutation Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_8b",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let err = http_room_members_upsert(
            Path(room_id.to_string()),
            signed_room_members_upsert_headers(
                "dev_room_member_8b",
                &member_key,
                room_id,
                "profile_room_pending_8b",
                HttpRoomMembershipStatus::Pending,
                HttpRoomMemberRole::Guest,
                Some("link-alpha-members-5b"),
                "room-members-upsert-forbidden-pending",
            ),
            State(state),
            Json(HttpRoomMembershipUpsertReq {
                profile_id: "profile_room_pending_8b".into(),
                status: HttpRoomMembershipStatus::Pending,
                role: HttpRoomMemberRole::Guest,
                source_link_id: Some("link-alpha-members-5b".into()),
            }),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::FORBIDDEN);
    }

    #[tokio::test]
    async fn http_room_delete_returns_deleted_room_and_profile_ids_for_owner() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[171u8; 32]);
        let room_id = "room_alpha_delete_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_delete_1",
            "profile_room_owner_delete_1",
            &owner_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_delete_1",
                "dev_room_owner_delete_1",
                "Delete Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_delete_1",
                "active",
                "member",
                Some("link-delete-1"),
                now_ms(),
            )
            .await
            .unwrap();

        let response = http_room_delete(
            Path(room_id.to_string()),
            signed_room_delete_headers(
                "dev_room_owner_delete_1",
                &owner_key,
                room_id,
                "room-delete-1",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert_eq!(response.room.room_id, room_id);
        assert_eq!(
            response.deleted_profile_ids,
            vec!["profile_room_member_delete_1"]
        );
        assert!(state.store.get_room(room_id).await.unwrap().is_none());
        assert!(
            state
                .store
                .list_room_memberships(room_id)
                .await
                .unwrap()
                .is_empty()
        );
    }

    #[tokio::test]
    async fn http_room_delete_rejects_non_owner_requester() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[172u8; 32]);
        let member_key = SigningKey::from_bytes(&[173u8; 32]);
        let room_id = "room_alpha_delete_2";

        cache_authenticated_device(
            &state,
            "dev_room_owner_delete_2",
            "profile_room_owner_delete_2",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_delete_2",
            "profile_room_member_delete_2",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_delete_2",
                "dev_room_owner_delete_2",
                "Delete Forbidden Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_delete_2",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let err = http_room_delete(
            Path(room_id.to_string()),
            signed_room_delete_headers(
                "dev_room_member_delete_2",
                &member_key,
                room_id,
                "room-delete-2",
            ),
            State(state.clone()),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::FORBIDDEN);
        assert_eq!(err.1, "only owner may delete room");
        assert!(state.store.get_room(room_id).await.unwrap().is_some());
    }

    #[tokio::test]
    async fn http_room_transfer_ownership_round_trip_for_owner() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[167u8; 32]);
        let next_owner_key = SigningKey::from_bytes(&[168u8; 32]);
        let room_id = "room_alpha_transfer_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_transfer_1",
            "profile_room_owner_transfer_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_next_owner_transfer_1",
            "profile_room_next_owner_transfer_1",
            &next_owner_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_transfer_1",
                "dev_room_owner_transfer_1",
                "Ownership Transfer Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_next_owner_transfer_1",
                "active",
                "member",
                Some("link-transfer-1"),
                now_ms(),
            )
            .await
            .unwrap();

        let response = http_room_transfer_ownership(
            Path(room_id.to_string()),
            signed_room_transfer_ownership_headers(
                "dev_room_owner_transfer_1",
                &owner_key,
                room_id,
                "profile_room_next_owner_transfer_1",
                "room-transfer-ownership-1",
            ),
            State(state.clone()),
            Json(HttpRoomTransferOwnershipReq {
                next_owner_profile_id: "profile_room_next_owner_transfer_1".into(),
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(response.ok);
        assert_eq!(
            response.room.owner_profile_id,
            "profile_room_next_owner_transfer_1"
        );
        assert_eq!(
            response.previous_owner_membership.role,
            HttpRoomMemberRole::Admin
        );
        assert_eq!(
            response.next_owner_membership.role,
            HttpRoomMemberRole::Owner
        );
        assert_eq!(
            response.next_owner_membership.source_link_id.as_deref(),
            Some("link-transfer-1")
        );
    }

    #[tokio::test]
    async fn http_room_transfer_ownership_is_idempotent_for_previous_owner_retry() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[169u8; 32]);
        let next_owner_key = SigningKey::from_bytes(&[170u8; 32]);
        let room_id = "room_alpha_transfer_retry_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_transfer_retry_1",
            "profile_room_owner_transfer_retry_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_next_owner_transfer_retry_1",
            "profile_room_next_owner_transfer_retry_1",
            &next_owner_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_transfer_retry_1",
                "dev_room_owner_transfer_retry_1",
                "Ownership Transfer Retry Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_next_owner_transfer_retry_1",
                "active",
                "member",
                Some("link-transfer-retry-1"),
                now_ms(),
            )
            .await
            .unwrap();

        let first = http_room_transfer_ownership(
            Path(room_id.to_string()),
            signed_room_transfer_ownership_headers(
                "dev_room_owner_transfer_retry_1",
                &owner_key,
                room_id,
                "profile_room_next_owner_transfer_retry_1",
                "room-transfer-ownership-retry-1a",
            ),
            State(state.clone()),
            Json(HttpRoomTransferOwnershipReq {
                next_owner_profile_id: "profile_room_next_owner_transfer_retry_1".into(),
            }),
        )
        .await
        .unwrap()
        .0;

        let second = http_room_transfer_ownership(
            Path(room_id.to_string()),
            signed_room_transfer_ownership_headers(
                "dev_room_owner_transfer_retry_1",
                &owner_key,
                room_id,
                "profile_room_next_owner_transfer_retry_1",
                "room-transfer-ownership-retry-1b",
            ),
            State(state.clone()),
            Json(HttpRoomTransferOwnershipReq {
                next_owner_profile_id: "profile_room_next_owner_transfer_retry_1".into(),
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(second.ok);
        assert_eq!(
            second.room.owner_profile_id,
            "profile_room_next_owner_transfer_retry_1"
        );
        assert_eq!(second.room.version, first.room.version);
        assert_eq!(
            second.room.membership_version,
            first.room.membership_version
        );
        assert_eq!(second.room.updated_at_ms, first.room.updated_at_ms);
        assert_eq!(
            second.previous_owner_membership.role,
            HttpRoomMemberRole::Admin
        );
        assert_eq!(second.next_owner_membership.role, HttpRoomMemberRole::Owner);
    }

    #[tokio::test]
    async fn http_room_invite_links_create_list_and_revoke_round_trip_for_owner() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[67u8; 32]);
        let room_id = "room_alpha_invites_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_9",
            "profile_room_owner_9",
            &owner_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_9",
                "dev_room_owner_9",
                "Invite Control Room",
                now_ms(),
            )
            .await
            .unwrap();

        let created = http_room_invite_links_create(
            Path(room_id.to_string()),
            signed_room_invite_links_create_headers(
                "dev_room_owner_9",
                &owner_key,
                room_id,
                Some(1_900_000_000_000),
                Some(2),
                true,
                HttpRoomMemberRole::Guest,
                "room-invite-create-1",
            ),
            State(state.clone()),
            Json(HttpRoomInviteLinkCreateReq {
                expires_at_ms: Some(1_900_000_000_000),
                max_uses: Some(2),
                requires_approval: Some(true),
                allowed_role: Some(HttpRoomMemberRole::Guest),
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(created.ok);
        assert_eq!(created.room.room_id, room_id);
        assert_eq!(created.room.version, 2);
        assert_eq!(created.room.membership_version, 1);
        assert_eq!(created.invite_link.use_count, 0);
        assert_eq!(created.invite_link.remaining_uses, Some(2));
        assert!(created.invite_link.requires_approval);
        assert_eq!(created.invite_link.allowed_role, HttpRoomMemberRole::Guest);
        assert!(!created.invite_link.revoked);

        let listed = http_room_invite_links_list(
            Path(room_id.to_string()),
            signed_room_invite_links_list_headers(
                "dev_room_owner_9",
                &owner_key,
                room_id,
                "room-invite-list-1",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;

        assert_eq!(listed.invite_links.len(), 1);
        assert_eq!(listed.invite_links[0].link_id, created.invite_link.link_id);
        assert_eq!(listed.invite_links[0].slug, created.invite_link.slug);

        let revoked = http_room_invite_link_revoke(
            Path((room_id.to_string(), created.invite_link.link_id.clone())),
            signed_room_invite_link_revoke_headers(
                "dev_room_owner_9",
                &owner_key,
                room_id,
                &created.invite_link.link_id,
                true,
                "room-invite-revoke-1",
            ),
            State(state),
            Json(HttpRoomInviteLinkRevokeReq { revoked: true }),
        )
        .await
        .unwrap()
        .0;

        assert!(revoked.ok);
        assert!(revoked.changed);
        assert_eq!(revoked.room.version, 3);
        assert_eq!(revoked.room.membership_version, 1);
        assert!(revoked.invite_link.revoked);
    }

    #[tokio::test]
    async fn http_room_invite_links_create_list_and_revoke_round_trip_for_admin() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[169u8; 32]);
        let admin_key = SigningKey::from_bytes(&[170u8; 32]);
        let room_id = "room_alpha_invites_admin_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_invite_admin_1",
            "profile_room_owner_invite_admin_1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_admin_invite_1",
            "profile_room_admin_invite_1",
            &admin_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_invite_admin_1",
                "dev_room_owner_invite_admin_1",
                "Admin Invite Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_admin_invite_1",
                "active",
                "admin",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let created = http_room_invite_links_create(
            Path(room_id.to_string()),
            signed_room_invite_links_create_headers(
                "dev_room_admin_invite_1",
                &admin_key,
                room_id,
                None,
                Some(3),
                false,
                HttpRoomMemberRole::Restricted,
                "room-invite-create-admin-1",
            ),
            State(state.clone()),
            Json(HttpRoomInviteLinkCreateReq {
                expires_at_ms: None,
                max_uses: Some(3),
                requires_approval: Some(false),
                allowed_role: Some(HttpRoomMemberRole::Restricted),
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(created.ok);
        assert_eq!(created.room.room_id, room_id);
        assert_eq!(
            created.invite_link.allowed_role,
            HttpRoomMemberRole::Restricted
        );

        let listed = http_room_invite_links_list(
            Path(room_id.to_string()),
            signed_room_invite_links_list_headers(
                "dev_room_admin_invite_1",
                &admin_key,
                room_id,
                "room-invite-list-admin-1",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;

        assert_eq!(listed.invite_links.len(), 1);

        let revoked = http_room_invite_link_revoke(
            Path((room_id.to_string(), created.invite_link.link_id.clone())),
            signed_room_invite_link_revoke_headers(
                "dev_room_admin_invite_1",
                &admin_key,
                room_id,
                &created.invite_link.link_id,
                true,
                "room-invite-revoke-admin-1",
            ),
            State(state),
            Json(HttpRoomInviteLinkRevokeReq { revoked: true }),
        )
        .await
        .unwrap()
        .0;

        assert!(revoked.ok);
        assert!(revoked.changed);
        assert!(revoked.invite_link.revoked);
    }

    #[tokio::test]
    async fn http_room_invite_links_list_rejects_non_owner_requester() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[68u8; 32]);
        let member_key = SigningKey::from_bytes(&[69u8; 32]);
        let room_id = "room_alpha_invites_2";

        cache_authenticated_device(
            &state,
            "dev_room_owner_10",
            "profile_room_owner_10",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_10",
            "profile_room_member_10",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_10",
                "dev_room_owner_10",
                "Owner Invite Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_member_10",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let err = http_room_invite_links_list(
            Path(room_id.to_string()),
            signed_room_invite_links_list_headers(
                "dev_room_member_10",
                &member_key,
                room_id,
                "room-invite-list-forbidden",
            ),
            State(state),
        )
        .await
        .unwrap_err();

        assert_eq!(err.0, StatusCode::FORBIDDEN);
    }

    #[tokio::test]
    async fn http_room_invite_preview_returns_authoritative_link_state() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[70u8; 32]);
        let viewer_key = SigningKey::from_bytes(&[71u8; 32]);
        let room_id = "room_alpha_invites_3";

        cache_authenticated_device(
            &state,
            "dev_room_owner_11",
            "profile_room_owner_11",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_viewer_11",
            "profile_room_viewer_11",
            &viewer_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_11",
                "dev_room_owner_11",
                "Preview Invite Room",
                now_ms(),
            )
            .await
            .unwrap();

        let created = http_room_invite_links_create(
            Path(room_id.to_string()),
            signed_room_invite_links_create_headers(
                "dev_room_owner_11",
                &owner_key,
                room_id,
                None,
                Some(4),
                false,
                HttpRoomMemberRole::Member,
                "room-invite-create-preview",
            ),
            State(state.clone()),
            Json(HttpRoomInviteLinkCreateReq {
                expires_at_ms: None,
                max_uses: Some(4),
                requires_approval: Some(false),
                allowed_role: Some(HttpRoomMemberRole::Member),
            }),
        )
        .await
        .unwrap()
        .0;

        let preview = http_room_invite_preview(
            Path(created.invite_link.slug.clone()),
            signed_room_invite_preview_headers(
                "dev_room_viewer_11",
                &viewer_key,
                &created.invite_link.slug,
                "room-invite-preview-1",
            ),
            State(state),
        )
        .await
        .unwrap()
        .0;

        assert_eq!(preview.room.room_id, room_id);
        assert_eq!(preview.invite_link.link_id, created.invite_link.link_id);
        assert_eq!(preview.active_member_count, 1);
        assert_eq!(preview.availability, HttpRoomInviteAvailability::Available);
        assert!(preview.requester_membership.is_none());
    }

    #[tokio::test]
    async fn http_room_invite_redeem_activates_member_and_is_idempotent() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[72u8; 32]);
        let member_key = SigningKey::from_bytes(&[73u8; 32]);
        let room_id = "room_alpha_invites_4";

        cache_authenticated_device(
            &state,
            "dev_room_owner_12",
            "profile_room_owner_12",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_12",
            "profile_room_member_12",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_12",
                "dev_room_owner_12",
                "Redeem Invite Room",
                now_ms(),
            )
            .await
            .unwrap();

        let created = http_room_invite_links_create(
            Path(room_id.to_string()),
            signed_room_invite_links_create_headers(
                "dev_room_owner_12",
                &owner_key,
                room_id,
                None,
                Some(1),
                false,
                HttpRoomMemberRole::Member,
                "room-invite-create-redeem",
            ),
            State(state.clone()),
            Json(HttpRoomInviteLinkCreateReq {
                expires_at_ms: None,
                max_uses: Some(1),
                requires_approval: Some(false),
                allowed_role: Some(HttpRoomMemberRole::Member),
            }),
        )
        .await
        .unwrap()
        .0;

        let first = http_room_invite_redeem(
            Path(created.invite_link.slug.clone()),
            signed_room_invite_redeem_headers(
                "dev_room_member_12",
                &member_key,
                &created.invite_link.slug,
                "room-invite-redeem-first",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;

        assert!(first.ok);
        assert!(first.changed);
        assert_eq!(first.disposition, HttpRoomInviteJoinDisposition::Active);
        assert_eq!(first.room.version, 3);
        assert_eq!(first.room.membership_version, 2);
        assert_eq!(first.invite_link.use_count, 1);
        assert_eq!(first.membership.status, HttpRoomMembershipStatus::Active);
        assert_eq!(first.membership.role, HttpRoomMemberRole::Member);

        let second = http_room_invite_redeem(
            Path(created.invite_link.slug.clone()),
            signed_room_invite_redeem_headers(
                "dev_room_member_12",
                &member_key,
                &created.invite_link.slug,
                "room-invite-redeem-second",
            ),
            State(state),
        )
        .await
        .unwrap()
        .0;

        assert!(second.ok);
        assert!(!second.changed);
        assert_eq!(second.disposition, HttpRoomInviteJoinDisposition::Active);
        assert_eq!(second.invite_link.use_count, 1);
        assert_eq!(second.membership.status, HttpRoomMembershipStatus::Active);
    }

    #[tokio::test]
    async fn http_room_invite_redeem_respects_room_member_cap() {
        // Р-4: an invite link must not grow a room past its owner's tier. The
        // membership-upsert path enforced the cap; redeem did not.
        let (base, _dir) = test_app_state().await;
        let state = AppState {
            monetization_enabled: true,
            ..base
        };
        let owner_key = SigningKey::from_bytes(&[91u8; 32]);
        let member_key = SigningKey::from_bytes(&[92u8; 32]);
        let late_key = SigningKey::from_bytes(&[93u8; 32]);
        let room_id = "room_cap_invites_1";
        cache_authenticated_device(&state, "dev_cap_owner", "profile_cap_owner", &owner_key);
        cache_authenticated_device(&state, "dev_cap_member", "profile_cap_member", &member_key);
        cache_authenticated_device(&state, "dev_cap_late", "profile_cap_late", &late_key);
        state
            .store
            .create_room(
                room_id,
                "profile_cap_owner",
                "dev_cap_owner",
                "Cap Room",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_cap_member",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        let active_now = state
            .store
            .count_active_room_members(room_id)
            .await
            .unwrap();
        // The room is exactly full for its owner's tier; joiners have room to spare.
        seed_entitlement(&state, "profile_cap_owner", 5, 20, active_now, 8);
        seed_entitlement(&state, "profile_cap_member", 5, 20, 50, 8);
        seed_entitlement(&state, "profile_cap_late", 5, 20, 50, 8);

        let create_link = |requires_approval: bool, nonce: &'static str| {
            let state = state.clone();
            let owner_key = owner_key.clone();
            async move {
                http_room_invite_links_create(
                    Path(room_id.to_string()),
                    signed_room_invite_links_create_headers(
                        "dev_cap_owner",
                        &owner_key,
                        room_id,
                        None,
                        None,
                        requires_approval,
                        HttpRoomMemberRole::Member,
                        nonce,
                    ),
                    State(state),
                    Json(HttpRoomInviteLinkCreateReq {
                        expires_at_ms: None,
                        max_uses: None,
                        requires_approval: Some(requires_approval),
                        allowed_role: Some(HttpRoomMemberRole::Member),
                    }),
                )
                .await
                .unwrap()
                .0
            }
        };

        let open = create_link(false, "room-cap-link-open").await;
        let err = http_room_invite_redeem(
            Path(open.invite_link.slug.clone()),
            signed_room_invite_redeem_headers(
                "dev_cap_late",
                &late_key,
                &open.invite_link.slug,
                "room-cap-redeem-late",
            ),
            State(state.clone()),
        )
        .await
        .unwrap_err();
        assert_eq!(err.0, StatusCode::PAYMENT_REQUIRED);
        assert_eq!(err.1, "group_member_limit_reached");
        assert!(
            state
                .store
                .get_room_membership(room_id, "profile_cap_late")
                .await
                .unwrap()
                .is_none()
        );
        assert_eq!(
            state
                .store
                .count_active_room_members(room_id)
                .await
                .unwrap(),
            active_now
        );

        // An existing member re-redeeming a full room is never blocked.
        let again = http_room_invite_redeem(
            Path(open.invite_link.slug.clone()),
            signed_room_invite_redeem_headers(
                "dev_cap_member",
                &member_key,
                &open.invite_link.slug,
                "room-cap-redeem-member",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;
        assert!(!again.changed);
        assert_eq!(again.disposition, HttpRoomInviteJoinDisposition::Active);

        // A join that waits for approval is checked when approved, not here.
        let gated = create_link(true, "room-cap-link-gated").await;
        let pending = http_room_invite_redeem(
            Path(gated.invite_link.slug.clone()),
            signed_room_invite_redeem_headers(
                "dev_cap_late",
                &late_key,
                &gated.invite_link.slug,
                "room-cap-redeem-gated",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;
        assert!(pending.changed);
        assert_eq!(
            pending.disposition,
            HttpRoomInviteJoinDisposition::PendingApproval
        );
    }

    #[tokio::test]
    async fn http_room_invite_redeem_rate_limits_slug_bucket() {
        // AUD-080: replace the slug limiter with a zero-refill bucket with
        // capacity 1 and confirm the second redeem attempt on the same slug
        // returns 429 TOO_MANY_REQUESTS without touching the store.
        let (mut state, _dir) = test_app_state().await;
        state.invite_redeem_slug_limiter = Arc::new(StringKeyRateLimiter::new(1, 0.0));
        let owner_key = SigningKey::from_bytes(&[82u8; 32]);
        let member_key = SigningKey::from_bytes(&[83u8; 32]);
        let room_id = "room_invite_rate_limited_1";

        cache_authenticated_device(
            &state,
            "dev_room_owner_rl1",
            "profile_room_owner_rl1",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_rl1",
            "profile_room_member_rl1",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_rl1",
                "dev_room_owner_rl1",
                "Rate Limited Invite Room",
                now_ms(),
            )
            .await
            .unwrap();

        let created = http_room_invite_links_create(
            Path(room_id.to_string()),
            signed_room_invite_links_create_headers(
                "dev_room_owner_rl1",
                &owner_key,
                room_id,
                None,
                None,
                false,
                HttpRoomMemberRole::Member,
                "room-invite-rl-create",
            ),
            State(state.clone()),
            Json(HttpRoomInviteLinkCreateReq {
                expires_at_ms: None,
                max_uses: None,
                requires_approval: None,
                allowed_role: None,
            }),
        )
        .await
        .unwrap()
        .0;

        let first = http_room_invite_redeem(
            Path(created.invite_link.slug.clone()),
            signed_room_invite_redeem_headers(
                "dev_room_member_rl1",
                &member_key,
                &created.invite_link.slug,
                "room-invite-rl-first",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;
        assert!(first.ok);

        let err = http_room_invite_redeem(
            Path(created.invite_link.slug.clone()),
            signed_room_invite_redeem_headers(
                "dev_room_member_rl1",
                &member_key,
                &created.invite_link.slug,
                "room-invite-rl-second",
            ),
            State(state),
        )
        .await
        .unwrap_err();
        assert_eq!(err.0, StatusCode::TOO_MANY_REQUESTS);
    }

    #[tokio::test]
    async fn http_room_invite_redeem_rate_limits_caller_bucket() {
        // AUD-080: confirm the per-caller bucket also produces 429 so that a
        // single authenticated device cannot scrape many slugs quickly.
        let (mut state, _dir) = test_app_state().await;
        state.invite_redeem_caller_limiter = Arc::new(StringKeyRateLimiter::new(1, 0.0));
        let owner_key = SigningKey::from_bytes(&[84u8; 32]);
        let member_key = SigningKey::from_bytes(&[85u8; 32]);
        let room_id_a = "room_invite_rl_caller_a";
        let room_id_b = "room_invite_rl_caller_b";

        cache_authenticated_device(
            &state,
            "dev_room_owner_rl2",
            "profile_room_owner_rl2",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_rl2",
            "profile_room_member_rl2",
            &member_key,
        );
        for (room_id, suffix) in [(room_id_a, "a"), (room_id_b, "b")] {
            state
                .store
                .create_room(
                    room_id,
                    "profile_room_owner_rl2",
                    "dev_room_owner_rl2",
                    &format!("Caller Rate Limited {suffix}"),
                    now_ms(),
                )
                .await
                .unwrap();
        }

        let invite_a = http_room_invite_links_create(
            Path(room_id_a.to_string()),
            signed_room_invite_links_create_headers(
                "dev_room_owner_rl2",
                &owner_key,
                room_id_a,
                None,
                None,
                false,
                HttpRoomMemberRole::Member,
                "room-invite-rl-caller-a",
            ),
            State(state.clone()),
            Json(HttpRoomInviteLinkCreateReq {
                expires_at_ms: None,
                max_uses: None,
                requires_approval: None,
                allowed_role: None,
            }),
        )
        .await
        .unwrap()
        .0;
        let invite_b = http_room_invite_links_create(
            Path(room_id_b.to_string()),
            signed_room_invite_links_create_headers(
                "dev_room_owner_rl2",
                &owner_key,
                room_id_b,
                None,
                None,
                false,
                HttpRoomMemberRole::Member,
                "room-invite-rl-caller-b",
            ),
            State(state.clone()),
            Json(HttpRoomInviteLinkCreateReq {
                expires_at_ms: None,
                max_uses: None,
                requires_approval: None,
                allowed_role: None,
            }),
        )
        .await
        .unwrap()
        .0;

        let first = http_room_invite_redeem(
            Path(invite_a.invite_link.slug.clone()),
            signed_room_invite_redeem_headers(
                "dev_room_member_rl2",
                &member_key,
                &invite_a.invite_link.slug,
                "room-invite-rl-caller-first",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;
        assert!(first.ok);

        let err = http_room_invite_redeem(
            Path(invite_b.invite_link.slug.clone()),
            signed_room_invite_redeem_headers(
                "dev_room_member_rl2",
                &member_key,
                &invite_b.invite_link.slug,
                "room-invite-rl-caller-second",
            ),
            State(state),
        )
        .await
        .unwrap_err();
        assert_eq!(err.0, StatusCode::TOO_MANY_REQUESTS);
    }

    #[tokio::test]
    async fn http_room_invite_redeem_returns_pending_approval_when_required() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[74u8; 32]);
        let member_key = SigningKey::from_bytes(&[75u8; 32]);
        let room_id = "room_alpha_invites_5";

        cache_authenticated_device(
            &state,
            "dev_room_owner_13",
            "profile_room_owner_13",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_member_13",
            "profile_room_member_13",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_owner_13",
                "dev_room_owner_13",
                "Approval Invite Room",
                now_ms(),
            )
            .await
            .unwrap();

        let created = http_room_invite_links_create(
            Path(room_id.to_string()),
            signed_room_invite_links_create_headers(
                "dev_room_owner_13",
                &owner_key,
                room_id,
                None,
                None,
                true,
                HttpRoomMemberRole::Restricted,
                "room-invite-create-pending",
            ),
            State(state.clone()),
            Json(HttpRoomInviteLinkCreateReq {
                expires_at_ms: None,
                max_uses: None,
                requires_approval: Some(true),
                allowed_role: Some(HttpRoomMemberRole::Restricted),
            }),
        )
        .await
        .unwrap()
        .0;

        let redeemed = http_room_invite_redeem(
            Path(created.invite_link.slug.clone()),
            signed_room_invite_redeem_headers(
                "dev_room_member_13",
                &member_key,
                &created.invite_link.slug,
                "room-invite-redeem-pending",
            ),
            State(state),
        )
        .await
        .unwrap()
        .0;

        assert!(redeemed.ok);
        assert!(redeemed.changed);
        assert_eq!(
            redeemed.disposition,
            HttpRoomInviteJoinDisposition::PendingApproval
        );
        assert_eq!(
            redeemed.membership.status,
            HttpRoomMembershipStatus::Pending
        );
        assert_eq!(redeemed.membership.role, HttpRoomMemberRole::Restricted);
        assert_eq!(redeemed.invite_link.use_count, 1);
    }

    #[tokio::test]
    async fn http_room_call_join_get_and_idempotent_round_trip() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[171u8; 32]);
        let room_id = "room_alpha_call_1";

        cache_authenticated_device(
            &state,
            "dev_room_call_owner_1",
            "profile_room_call_owner_1",
            &owner_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_call_owner_1",
                "dev_room_call_owner_1",
                "Room Call HTTP",
                now_ms(),
            )
            .await
            .unwrap();

        let join_req = HttpRoomCallJoinReq {
            media_type: HttpRoomCallMediaType::Video,
            supports_video: true,
            supports_screen_share: true,
            muted: false,
            deafened: false,
            video_enabled: true,
            screen_share_enabled: false,
        };

        let joined = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_owner_1",
                &owner_key,
                room_id,
                &join_req,
                "room-call-join-1",
            ),
            State(state.clone()),
            Json(HttpRoomCallJoinReq {
                media_type: join_req.media_type,
                supports_video: join_req.supports_video,
                supports_screen_share: join_req.supports_screen_share,
                muted: join_req.muted,
                deafened: join_req.deafened,
                video_enabled: join_req.video_enabled,
                screen_share_enabled: join_req.screen_share_enabled,
            }),
        )
        .await
        .unwrap()
        .0;

        assert!(joined.ok);
        assert!(joined.changed);
        assert_eq!(joined.room.room_id, room_id);
        assert_eq!(joined.call.state, HttpRoomCallState::Active);
        assert_eq!(joined.call.media_type, HttpRoomCallMediaType::Video);
        assert_eq!(joined.call.state_version, 1);
        assert_eq!(joined.participants.len(), 1);
        assert_eq!(
            joined.self_participant.as_ref().unwrap().join_state,
            HttpRoomCallJoinState::Joined
        );

        let fetched = http_room_call_get(
            Path(room_id.to_string()),
            signed_room_call_get_headers(
                "dev_room_call_owner_1",
                &owner_key,
                room_id,
                "room-call-get-1",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;

        assert!(fetched.exists);
        assert_eq!(fetched.call.as_ref().unwrap().call_id, joined.call.call_id);
        assert_eq!(fetched.participants.len(), 1);

        let repeated = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_owner_1",
                &owner_key,
                room_id,
                &join_req,
                "room-call-join-repeat-1",
            ),
            State(state),
            Json(join_req),
        )
        .await
        .unwrap()
        .0;

        assert!(repeated.ok);
        assert!(!repeated.changed);
        assert_eq!(repeated.call.call_id, joined.call.call_id);
        assert_eq!(repeated.call.state_version, 1);
    }

    #[tokio::test]
    async fn http_room_call_self_update_and_leave_round_trip() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[172u8; 32]);
        let member_key = SigningKey::from_bytes(&[173u8; 32]);
        let room_id = "room_alpha_call_2";

        cache_authenticated_device(
            &state,
            "dev_room_call_owner_2",
            "profile_room_call_owner_2",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_call_member_2",
            "profile_room_call_member_2",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_call_owner_2",
                "dev_room_call_owner_2",
                "Room Call HTTP Two",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_call_member_2",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let owner_join = HttpRoomCallJoinReq {
            media_type: HttpRoomCallMediaType::Video,
            supports_video: true,
            supports_screen_share: false,
            muted: false,
            deafened: false,
            video_enabled: true,
            screen_share_enabled: false,
        };
        let member_join = HttpRoomCallJoinReq {
            media_type: HttpRoomCallMediaType::Video,
            supports_video: true,
            supports_screen_share: true,
            muted: false,
            deafened: false,
            video_enabled: false,
            screen_share_enabled: false,
        };

        let created = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_owner_2",
                &owner_key,
                room_id,
                &owner_join,
                "room-call-owner-join-2",
            ),
            State(state.clone()),
            Json(owner_join),
        )
        .await
        .unwrap()
        .0;
        let joined = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_member_2",
                &member_key,
                room_id,
                &member_join,
                "room-call-member-join-2",
            ),
            State(state.clone()),
            Json(member_join),
        )
        .await
        .unwrap()
        .0;

        assert_eq!(joined.call.call_id, created.call.call_id);
        assert_eq!(joined.participants.len(), 2);

        let update_req = HttpRoomCallParticipantUpdateReq {
            reconnecting: true,
            muted: true,
            deafened: false,
            video_enabled: true,
            screen_share_enabled: true,
            speaking: true,
        };
        let updated = http_room_call_self_update(
            Path((room_id.to_string(), created.call.call_id.clone())),
            signed_room_call_self_update_headers(
                "dev_room_call_member_2",
                &member_key,
                room_id,
                &created.call.call_id,
                &update_req,
                "room-call-self-update-2",
            ),
            State(state.clone()),
            Json(update_req),
        )
        .await
        .unwrap()
        .0;

        assert!(updated.ok);
        assert!(updated.changed);
        assert_eq!(
            updated.self_participant.as_ref().unwrap().join_state,
            HttpRoomCallJoinState::Reconnecting
        );
        assert!(updated.self_participant.as_ref().unwrap().muted);
        assert!(updated.self_participant.as_ref().unwrap().video_enabled);
        assert!(
            updated
                .self_participant
                .as_ref()
                .unwrap()
                .screen_share_enabled
        );
        assert!(!updated.self_participant.as_ref().unwrap().speaking);

        let member_left = http_room_call_leave(
            Path((room_id.to_string(), created.call.call_id.clone())),
            signed_room_call_leave_headers(
                "dev_room_call_member_2",
                &member_key,
                room_id,
                &created.call.call_id,
                "room-call-member-leave-2",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;

        assert!(member_left.ok);
        assert!(member_left.changed);
        assert_eq!(member_left.call.state, HttpRoomCallState::Active);
        assert_eq!(
            member_left.self_participant.as_ref().unwrap().join_state,
            HttpRoomCallJoinState::Left
        );

        let owner_left = http_room_call_leave(
            Path((room_id.to_string(), created.call.call_id.clone())),
            signed_room_call_leave_headers(
                "dev_room_call_owner_2",
                &owner_key,
                room_id,
                &created.call.call_id,
                "room-call-owner-leave-2",
            ),
            State(state),
        )
        .await
        .unwrap()
        .0;

        assert!(owner_left.ok);
        assert!(owner_left.changed);
        assert_eq!(owner_left.call.state, HttpRoomCallState::Ended);
        assert!(owner_left.call.ended_at_ms.is_some());
        assert_eq!(
            owner_left.self_participant.as_ref().unwrap().join_state,
            HttpRoomCallJoinState::Left
        );
    }

    #[tokio::test]
    async fn http_room_call_moderation_remove_and_end_round_trip() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[174u8; 32]);
        let moderator_key = SigningKey::from_bytes(&[175u8; 32]);
        let member_key = SigningKey::from_bytes(&[176u8; 32]);
        let room_id = "room_alpha_call_3";

        cache_authenticated_device(
            &state,
            "dev_room_call_owner_3",
            "profile_room_call_owner_3",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_call_moderator_3",
            "profile_room_call_moderator_3",
            &moderator_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_call_member_3",
            "profile_room_call_member_3",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_call_owner_3",
                "dev_room_call_owner_3",
                "Room Call HTTP Three",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_call_moderator_3",
                "active",
                "moderator",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_call_member_3",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let join_req = HttpRoomCallJoinReq {
            media_type: HttpRoomCallMediaType::Video,
            supports_video: true,
            supports_screen_share: false,
            muted: false,
            deafened: false,
            video_enabled: true,
            screen_share_enabled: false,
        };

        let created = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_owner_3",
                &owner_key,
                room_id,
                &join_req,
                "room-call-owner-join-3",
            ),
            State(state.clone()),
            Json(HttpRoomCallJoinReq {
                media_type: join_req.media_type,
                supports_video: join_req.supports_video,
                supports_screen_share: join_req.supports_screen_share,
                muted: join_req.muted,
                deafened: join_req.deafened,
                video_enabled: join_req.video_enabled,
                screen_share_enabled: join_req.screen_share_enabled,
            }),
        )
        .await
        .unwrap()
        .0;
        let call_id = created.call.call_id.clone();

        let _ = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_moderator_3",
                &moderator_key,
                room_id,
                &join_req,
                "room-call-moderator-join-3",
            ),
            State(state.clone()),
            Json(HttpRoomCallJoinReq {
                media_type: join_req.media_type,
                supports_video: join_req.supports_video,
                supports_screen_share: join_req.supports_screen_share,
                muted: join_req.muted,
                deafened: join_req.deafened,
                video_enabled: join_req.video_enabled,
                screen_share_enabled: join_req.screen_share_enabled,
            }),
        )
        .await
        .unwrap();
        let _ = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_member_3",
                &member_key,
                room_id,
                &join_req,
                "room-call-member-join-3",
            ),
            State(state.clone()),
            Json(join_req),
        )
        .await
        .unwrap();

        let removed = http_room_call_participant_remove(
            Path((
                room_id.to_string(),
                call_id.clone(),
                "dev_room_call_member_3".to_string(),
            )),
            signed_room_call_participant_remove_headers(
                "dev_room_call_moderator_3",
                &moderator_key,
                room_id,
                &call_id,
                "dev_room_call_member_3",
                "room-call-remove-3",
            ),
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;

        assert!(removed.ok);
        assert!(removed.changed);
        assert_eq!(removed.call.state, HttpRoomCallState::Active);
        assert_eq!(removed.call.state_version, 4);
        assert_eq!(removed.participants.len(), 3);
        assert_eq!(
            removed.self_participant.as_ref().unwrap().profile_id,
            "profile_room_call_moderator_3"
        );
        let removed_member = removed
            .participants
            .iter()
            .find(|participant| participant.device_id == "dev_room_call_member_3")
            .unwrap();
        assert_eq!(removed_member.join_state, HttpRoomCallJoinState::Removed);

        let ended = http_room_call_end(
            Path((room_id.to_string(), call_id.clone())),
            signed_room_call_end_headers(
                "dev_room_call_owner_3",
                &owner_key,
                room_id,
                &call_id,
                "room-call-end-3",
            ),
            State(state),
        )
        .await
        .unwrap()
        .0;

        assert!(ended.ok);
        assert!(ended.changed);
        assert_eq!(ended.call.state, HttpRoomCallState::Ended);
        assert!(ended.call.ended_at_ms.is_some());
        assert_eq!(
            ended.self_participant.as_ref().unwrap().join_state,
            HttpRoomCallJoinState::Left
        );
        let ended_removed_member = ended
            .participants
            .iter()
            .find(|participant| participant.device_id == "dev_room_call_member_3")
            .unwrap();
        assert_eq!(
            ended_removed_member.join_state,
            HttpRoomCallJoinState::Removed
        );
    }

    #[tokio::test]
    async fn http_room_call_moderation_authz_matrix_is_enforced() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[177u8; 32]);
        let moderator_key = SigningKey::from_bytes(&[178u8; 32]);
        let member_key = SigningKey::from_bytes(&[179u8; 32]);
        let room_id = "room_alpha_call_4";

        cache_authenticated_device(
            &state,
            "dev_room_call_owner_4",
            "profile_room_call_owner_4",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_call_moderator_4",
            "profile_room_call_moderator_4",
            &moderator_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_call_member_4",
            "profile_room_call_member_4",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_call_owner_4",
                "dev_room_call_owner_4",
                "Room Call HTTP Four",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_call_moderator_4",
                "active",
                "moderator",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_call_member_4",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let join_req = HttpRoomCallJoinReq {
            media_type: HttpRoomCallMediaType::Audio,
            supports_video: false,
            supports_screen_share: false,
            muted: false,
            deafened: false,
            video_enabled: false,
            screen_share_enabled: false,
        };

        let created = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_owner_4",
                &owner_key,
                room_id,
                &join_req,
                "room-call-owner-join-4",
            ),
            State(state.clone()),
            Json(HttpRoomCallJoinReq {
                media_type: join_req.media_type,
                supports_video: join_req.supports_video,
                supports_screen_share: join_req.supports_screen_share,
                muted: join_req.muted,
                deafened: join_req.deafened,
                video_enabled: join_req.video_enabled,
                screen_share_enabled: join_req.screen_share_enabled,
            }),
        )
        .await
        .unwrap()
        .0;
        let call_id = created.call.call_id.clone();

        let _ = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_moderator_4",
                &moderator_key,
                room_id,
                &join_req,
                "room-call-moderator-join-4",
            ),
            State(state.clone()),
            Json(HttpRoomCallJoinReq {
                media_type: join_req.media_type,
                supports_video: join_req.supports_video,
                supports_screen_share: join_req.supports_screen_share,
                muted: join_req.muted,
                deafened: join_req.deafened,
                video_enabled: join_req.video_enabled,
                screen_share_enabled: join_req.screen_share_enabled,
            }),
        )
        .await
        .unwrap();
        let _ = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_member_4",
                &member_key,
                room_id,
                &join_req,
                "room-call-member-join-4",
            ),
            State(state.clone()),
            Json(join_req),
        )
        .await
        .unwrap();

        let member_remove_err = http_room_call_participant_remove(
            Path((
                room_id.to_string(),
                call_id.clone(),
                "dev_room_call_moderator_4".to_string(),
            )),
            signed_room_call_participant_remove_headers(
                "dev_room_call_member_4",
                &member_key,
                room_id,
                &call_id,
                "dev_room_call_moderator_4",
                "room-call-member-remove-4",
            ),
            State(state.clone()),
        )
        .await
        .unwrap_err();
        assert_eq!(member_remove_err.0, StatusCode::FORBIDDEN);

        let moderator_remove_owner_err = http_room_call_participant_remove(
            Path((
                room_id.to_string(),
                call_id.clone(),
                "dev_room_call_owner_4".to_string(),
            )),
            signed_room_call_participant_remove_headers(
                "dev_room_call_moderator_4",
                &moderator_key,
                room_id,
                &call_id,
                "dev_room_call_owner_4",
                "room-call-moderator-remove-owner-4",
            ),
            State(state.clone()),
        )
        .await
        .unwrap_err();
        assert_eq!(moderator_remove_owner_err.0, StatusCode::FORBIDDEN);

        let moderator_end_err = http_room_call_end(
            Path((room_id.to_string(), call_id)),
            signed_room_call_end_headers(
                "dev_room_call_moderator_4",
                &moderator_key,
                room_id,
                &created.call.call_id,
                "room-call-moderator-end-4",
            ),
            State(state),
        )
        .await
        .unwrap_err();
        assert_eq!(moderator_end_err.0, StatusCode::FORBIDDEN);
    }

    #[tokio::test]
    async fn http_room_call_media_get_returns_bootstrap_descriptor_before_media_join() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[180u8; 32]);
        let room_id = "room_alpha_call_media_1";

        cache_authenticated_device(
            &state,
            "dev_room_call_owner_media_1",
            "profile_room_call_owner_media_1",
            &owner_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_call_owner_media_1",
                "dev_room_call_owner_media_1",
                "Room Call Media One",
                now_ms(),
            )
            .await
            .unwrap();

        let join_req = HttpRoomCallJoinReq {
            media_type: HttpRoomCallMediaType::Video,
            supports_video: true,
            supports_screen_share: true,
            muted: false,
            deafened: false,
            video_enabled: true,
            screen_share_enabled: false,
        };

        let created = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_owner_media_1",
                &owner_key,
                room_id,
                &join_req,
                "room-call-media-owner-join-1",
            ),
            State(state.clone()),
            Json(join_req),
        )
        .await
        .unwrap()
        .0;

        let media = http_room_call_media_get(
            Path((room_id.to_string(), created.call.call_id.clone())),
            signed_room_call_media_get_headers(
                "dev_room_call_owner_media_1",
                &owner_key,
                room_id,
                &created.call.call_id,
                "room-call-media-get-1",
            ),
            State(state),
        )
        .await
        .unwrap()
        .0;

        assert_eq!(media.room_id, room_id);
        assert_eq!(media.call_id, created.call.call_id);
        assert_eq!(media.session_id, media.call_id);
        assert_eq!(media.contract_version, "room_media_v1");
        assert_eq!(media.topology, HttpRoomCallMediaTopology::Centralized);
        assert_eq!(
            media.capability_state,
            HttpRoomCallMediaCapabilityState::BootstrapOnly
        );
        assert_eq!(media.media_type, HttpRoomCallMediaType::Video);
        assert_eq!(media.self_profile_id, "profile_room_call_owner_media_1");
        assert_eq!(media.self_device_id, "dev_room_call_owner_media_1");
        assert_eq!(media.participant_count, 1);
        assert!(media.subscribe_all_supported);
        assert!(media.publish_video_supported);
        assert!(media.publish_screen_share_supported);
        assert_eq!(
            media.backend.kind,
            HttpRoomCallMediaBackendKind::Unavailable
        );
        assert!(media.backend.access_token.is_none());
        assert_eq!(media.signal.transport_kind, "room_call_media_signal_v1");
        assert!(media.signal.descriptor_version > 0);
        let self_participant = media
            .participants
            .iter()
            .find(|participant| participant.is_self)
            .unwrap();
        assert_eq!(self_participant.device_id, "dev_room_call_owner_media_1");
        assert_eq!(
            self_participant.profile_id,
            "profile_room_call_owner_media_1"
        );
        assert_eq!(self_participant.join_state, HttpRoomCallJoinState::Joined);
        assert!(!self_participant.publish_audio);
        assert!(!self_participant.publish_video);
        assert!(!self_participant.publish_screen_share);
        assert!(!self_participant.receive_audio);
        assert!(!self_participant.receive_video);
    }

    #[tokio::test]
    async fn http_room_call_media_join_requires_self_join_and_persists_publish_preferences() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[181u8; 32]);
        let member_key = SigningKey::from_bytes(&[182u8; 32]);
        let room_id = "room_alpha_call_media_2";

        cache_authenticated_device(
            &state,
            "dev_room_call_owner_media_2",
            "profile_room_call_owner_media_2",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            "dev_room_call_member_media_2",
            "profile_room_call_member_media_2",
            &member_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_call_owner_media_2",
                "dev_room_call_owner_media_2",
                "Room Call Media Two",
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_call_member_media_2",
                "active",
                "member",
                None,
                now_ms(),
            )
            .await
            .unwrap();

        let join_req = HttpRoomCallJoinReq {
            media_type: HttpRoomCallMediaType::Video,
            supports_video: true,
            supports_screen_share: true,
            muted: false,
            deafened: false,
            video_enabled: true,
            screen_share_enabled: false,
        };

        let created = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_owner_media_2",
                &owner_key,
                room_id,
                &join_req,
                "room-call-media-owner-join-2",
            ),
            State(state.clone()),
            Json(HttpRoomCallJoinReq {
                media_type: join_req.media_type,
                supports_video: join_req.supports_video,
                supports_screen_share: join_req.supports_screen_share,
                muted: join_req.muted,
                deafened: join_req.deafened,
                video_enabled: join_req.video_enabled,
                screen_share_enabled: join_req.screen_share_enabled,
            }),
        )
        .await
        .unwrap()
        .0;

        let member_join_req = HttpRoomCallMediaJoinReq {
            publish_audio: true,
            publish_video: true,
            publish_screen_share: false,
            subscribe_all: true,
        };
        let member_join_err = http_room_call_media_join(
            Path((room_id.to_string(), created.call.call_id.clone())),
            signed_room_call_media_join_headers(
                "dev_room_call_member_media_2",
                &member_key,
                room_id,
                &created.call.call_id,
                &member_join_req,
                "room-call-media-member-join-2",
            ),
            State(state.clone()),
            Json(member_join_req),
        )
        .await
        .unwrap_err();
        assert_eq!(member_join_err.0, StatusCode::CONFLICT);

        let member_call_join_req = HttpRoomCallJoinReq {
            media_type: join_req.media_type,
            supports_video: join_req.supports_video,
            supports_screen_share: join_req.supports_screen_share,
            muted: join_req.muted,
            deafened: join_req.deafened,
            video_enabled: false,
            screen_share_enabled: join_req.screen_share_enabled,
        };

        let member_call_joined = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_member_media_2",
                &member_key,
                room_id,
                &member_call_join_req,
                "room-call-media-member-control-join-2",
            ),
            State(state.clone()),
            Json(member_call_join_req),
        )
        .await
        .unwrap()
        .0;
        assert_eq!(member_call_joined.call.call_id, created.call.call_id);

        let owner_media_join_req = HttpRoomCallMediaJoinReq {
            publish_audio: true,
            publish_video: false,
            publish_screen_share: false,
            subscribe_all: true,
        };
        let owner_media = http_room_call_media_join(
            Path((room_id.to_string(), created.call.call_id.clone())),
            signed_room_call_media_join_headers(
                "dev_room_call_owner_media_2",
                &owner_key,
                room_id,
                &created.call.call_id,
                &owner_media_join_req,
                "room-call-media-owner-bootstrap-2",
            ),
            State(state.clone()),
            Json(owner_media_join_req),
        )
        .await
        .unwrap()
        .0;

        assert!(owner_media.ok);
        assert_eq!(owner_media.media.call_id, created.call.call_id);
        assert_eq!(
            owner_media.media.signal.transport_kind,
            "room_call_media_signal_v1"
        );
        assert!(owner_media.media.signal.descriptor_version > 0);
        assert_eq!(
            owner_media.media.backend.kind,
            HttpRoomCallMediaBackendKind::Unavailable
        );
        let self_participant = owner_media
            .media
            .participants
            .iter()
            .find(|participant| participant.is_self)
            .unwrap();
        assert!(self_participant.publish_audio);
        assert!(!self_participant.publish_video);
        assert!(!self_participant.publish_screen_share);
        assert!(self_participant.receive_audio);
        assert!(self_participant.receive_video);

        let member_media_join_req = HttpRoomCallMediaJoinReq {
            publish_audio: true,
            publish_video: false,
            publish_screen_share: false,
            subscribe_all: false,
        };
        let member_media = http_room_call_media_join(
            Path((room_id.to_string(), created.call.call_id.clone())),
            signed_room_call_media_join_headers(
                "dev_room_call_member_media_2",
                &member_key,
                room_id,
                &created.call.call_id,
                &member_media_join_req,
                "room-call-media-member-bootstrap-2",
            ),
            State(state.clone()),
            Json(member_media_join_req),
        )
        .await
        .unwrap()
        .0;
        assert!(member_media.ok);

        let owner_media_get = http_room_call_media_get(
            Path((room_id.to_string(), created.call.call_id.clone())),
            signed_room_call_media_get_headers(
                "dev_room_call_owner_media_2",
                &owner_key,
                room_id,
                &created.call.call_id,
                "room-call-media-owner-get-after-join-2",
            ),
            State(state),
        )
        .await
        .unwrap()
        .0;
        let persisted_owner = owner_media_get
            .participants
            .iter()
            .find(|participant| participant.is_self)
            .unwrap();
        assert_eq!(
            owner_media_get.signal.transport_kind,
            "room_call_media_signal_v1"
        );
        assert!(
            owner_media_get.signal.descriptor_version
                >= owner_media.media.signal.descriptor_version
        );
        assert!(persisted_owner.publish_audio);
        assert!(!persisted_owner.publish_video);
        let persisted_member = owner_media_get
            .participants
            .iter()
            .find(|participant| participant.device_id == "dev_room_call_member_media_2")
            .unwrap();
        assert!(persisted_member.publish_audio);
        assert!(!persisted_member.publish_video);
        assert!(!persisted_member.receive_audio);
        assert!(!persisted_member.receive_video);
        assert!(!persisted_member.receive_screen_share);
    }

    #[tokio::test]
    async fn room_call_media_health_summary_counts_active_registrations() {
        let (state, _dir) = test_app_state().await;
        let state = AppState {
            call_ice: Arc::new(RelayCallIceRuntimeConfig {
                policy: "relay_preferred".into(),
                stun_urls: vec!["stun:stun.secretly.test:3478".into()],
                turn_urls: vec!["turn:turn.secretly.test:3478?transport=udp".into()],
                turn_shared_secret: "super-secret".into(),
                turn_ttl_seconds: 600,
            }),
            room_media: Arc::new(RelayRoomMediaRuntimeConfig {
                requested_backend: RelayRoomMediaBackendKind::Livekit,
                effective_backend: RelayRoomMediaBackendKind::Livekit,
                livekit_url: "wss://livekit.secretly.test".into(),
                livekit_api_key: "relay-livekit-key".into(),
                livekit_api_secret: "relay-livekit-secret".into(),
                token_ttl_seconds: 300,
            }),
            ..state
        };
        let room_id = "room_alpha_call_media_health_1";
        let now = now_ms();

        state
            .store
            .create_room(
                room_id,
                "profile_room_call_owner_media_health_1",
                "dev_room_call_owner_media_health_1",
                "Room Call Media Health One",
                now,
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_membership(
                room_id,
                "profile_room_call_member_media_health_1",
                "active",
                "member",
                None,
                now,
            )
            .await
            .unwrap();

        let created = state
            .store
            .create_or_join_room_call(
                room_id,
                "profile_room_call_owner_media_health_1",
                "dev_room_call_owner_media_health_1",
                "video",
                true,
                true,
                false,
                false,
                true,
                false,
                now,
            )
            .await
            .unwrap();
        state
            .store
            .create_or_join_room_call(
                room_id,
                "profile_room_call_member_media_health_1",
                "dev_room_call_member_media_health_1",
                "audio",
                false,
                false,
                false,
                false,
                false,
                false,
                now + 1,
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_call_media_participant(
                room_id,
                &created.snapshot.call.call_id,
                "profile_room_call_owner_media_health_1",
                "dev_room_call_owner_media_health_1",
                true,
                true,
                false,
                true,
                now + 2,
            )
            .await
            .unwrap();
        state
            .store
            .upsert_room_call_media_participant(
                room_id,
                &created.snapshot.call.call_id,
                "profile_room_call_member_media_health_1",
                "dev_room_call_member_media_health_1",
                true,
                false,
                false,
                false,
                now + 3,
            )
            .await
            .unwrap();

        let media_summary = state
            .store
            .summarize_room_call_media_health()
            .await
            .unwrap();
        assert_eq!(media_summary.active_room_call_count, 1);
        assert_eq!(media_summary.joined_room_call_participant_count, 2);
        assert_eq!(media_summary.registered_room_media_participant_count, 2);
        assert_eq!(media_summary.fully_registered_room_call_count, 1);

        let readiness = summarize_room_media_readiness(
            &summarize_call_ice_readiness(state.call_ice.as_ref()),
            &media_summary,
            state.room_media.as_ref(),
        );
        assert!(readiness.ice_ready);
        assert!(readiness.runtime_registration_complete);
        assert!(readiness.session_auth_ready);
        assert!(readiness.room_media_ready);
    }

    #[tokio::test]
    async fn http_room_call_media_join_returns_livekit_session_descriptor_when_backend_is_configured()
     {
        let (state, _dir) = test_app_state().await;
        let state = AppState {
            room_media: Arc::new(RelayRoomMediaRuntimeConfig {
                requested_backend: RelayRoomMediaBackendKind::Livekit,
                effective_backend: RelayRoomMediaBackendKind::Livekit,
                livekit_url: "wss://livekit.secretly.test".into(),
                livekit_api_key: "relay-livekit-key".into(),
                livekit_api_secret: "relay-livekit-secret".into(),
                token_ttl_seconds: 300,
            }),
            ..state
        };
        let owner_key = SigningKey::from_bytes(&[183u8; 32]);
        let room_id = "room_alpha_call_media_livekit_1";

        cache_authenticated_device(
            &state,
            "dev_room_call_owner_livekit_1",
            "profile_room_call_owner_livekit_1",
            &owner_key,
        );
        state
            .store
            .create_room(
                room_id,
                "profile_room_call_owner_livekit_1",
                "dev_room_call_owner_livekit_1",
                "Room Call Media LiveKit One",
                now_ms(),
            )
            .await
            .unwrap();

        let join_req = HttpRoomCallJoinReq {
            media_type: HttpRoomCallMediaType::Video,
            supports_video: true,
            supports_screen_share: true,
            muted: false,
            deafened: false,
            video_enabled: true,
            screen_share_enabled: false,
        };

        let created = http_room_call_join(
            Path(room_id.to_string()),
            signed_room_call_join_headers(
                "dev_room_call_owner_livekit_1",
                &owner_key,
                room_id,
                &join_req,
                "room-call-media-livekit-owner-join-1",
            ),
            State(state.clone()),
            Json(join_req),
        )
        .await
        .unwrap()
        .0;

        let media_join_req = HttpRoomCallMediaJoinReq {
            publish_audio: true,
            publish_video: true,
            publish_screen_share: false,
            subscribe_all: true,
        };
        let media = http_room_call_media_join(
            Path((room_id.to_string(), created.call.call_id.clone())),
            signed_room_call_media_join_headers(
                "dev_room_call_owner_livekit_1",
                &owner_key,
                room_id,
                &created.call.call_id,
                &media_join_req,
                "room-call-media-livekit-join-1",
            ),
            State(state),
            Json(media_join_req),
        )
        .await
        .unwrap()
        .0;

        assert_eq!(
            media.media.capability_state,
            HttpRoomCallMediaCapabilityState::SessionAuthReady
        );
        assert_eq!(
            media.media.backend.kind,
            HttpRoomCallMediaBackendKind::Livekit
        );
        assert_eq!(
            media.media.backend.url.as_deref(),
            Some("wss://livekit.secretly.test")
        );
        assert!(
            media
                .media
                .backend
                .room_name
                .as_deref()
                .unwrap()
                .starts_with("secretly-room-")
        );
        assert!(
            media
                .media
                .backend
                .participant_identity
                .as_deref()
                .unwrap()
                .starts_with("secretly-participant-")
        );
        assert!(media.media.backend.access_token.is_some());
        assert!(media.media.backend.access_token_expires_at_ms.unwrap() > now_ms());

        let token = media.media.backend.access_token.as_deref().unwrap();
        let mut segments = token.split('.');
        let _header = segments.next().unwrap();
        let payload = segments.next().unwrap();
        let payload_bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD
            .decode(payload)
            .unwrap();
        let payload_json: serde_json::Value = serde_json::from_slice(&payload_bytes).unwrap();
        assert_eq!(payload_json["iss"], "relay-livekit-key");
        assert_eq!(
            payload_json["sub"],
            media.media.backend.participant_identity.as_deref().unwrap()
        );
        assert_eq!(
            payload_json["video"]["room"],
            media.media.backend.room_name.as_deref().unwrap()
        );
        assert_eq!(payload_json["video"]["roomJoin"], true);
        assert_eq!(payload_json["video"]["canPublish"], true);
        assert_eq!(payload_json["video"]["canSubscribe"], true);
    }

    #[test]
    fn room_media_readiness_degrades_when_session_authority_is_unconfigured() {
        let call_summary = CallReadinessSummary {
            calls_ready: true,
            requested_policy: "relay_preferred".into(),
            effective_policy: "relay_preferred".into(),
            stun_server_count: 1,
            turn_server_count: 1,
            turn_credentials_ready: true,
        };
        let media_summary = RoomCallMediaHealthSummary {
            active_room_call_count: 1,
            joined_room_call_participant_count: 2,
            registered_room_media_participant_count: 2,
            fully_registered_room_call_count: 1,
        };
        let room_media_config = RelayRoomMediaRuntimeConfig {
            requested_backend: RelayRoomMediaBackendKind::Unavailable,
            effective_backend: RelayRoomMediaBackendKind::Unavailable,
            livekit_url: String::new(),
            livekit_api_key: String::new(),
            livekit_api_secret: String::new(),
            token_ttl_seconds: 300,
        };

        let summary =
            summarize_room_media_readiness(&call_summary, &media_summary, &room_media_config);
        assert!(summary.ice_ready);
        assert!(summary.runtime_registration_complete);
        assert!(!summary.session_auth_ready);
        assert!(!summary.room_media_ready);
        assert_eq!(summary.effective_backend, "unavailable");
    }

    #[tokio::test]
    async fn http_blocks_set_and_list_round_trip_for_valid_signed_request() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[40u8; 32]);
        let device_id = "dev_blocks_1";
        let owner_profile_id = "profile_blocks_owner_1";
        let blocked_profile_id = "profile_blocks_target_1";

        cache_authenticated_device(&state, device_id, owner_profile_id, &signing_key);

        let set_headers =
            signed_auth_headers(device_id, &signing_key, "blocks-set", |ts_ms, nonce_b64| {
                http_blocks_set_auth_message(device_id, blocked_profile_id, true, ts_ms, nonce_b64)
            });
        let set_response = http_blocks_set(
            Path(device_id.to_string()),
            set_headers,
            State(state.clone()),
            Json(HttpBlocksSetReq {
                blocked_profile_id: blocked_profile_id.into(),
                blocked: true,
            }),
        )
        .await
        .unwrap()
        .0;
        assert!(set_response.ok);

        let list_headers = signed_auth_headers(
            device_id,
            &signing_key,
            "blocks-list",
            |ts_ms, nonce_b64| http_blocks_list_auth_message(device_id, ts_ms, nonce_b64),
        );
        let list_response = http_blocks_list(
            Path(device_id.to_string()),
            list_headers,
            State(state.clone()),
        )
        .await
        .unwrap()
        .0;
        assert_eq!(list_response.device_id, device_id);
        assert_eq!(
            list_response.blocked_profile_ids,
            vec![blocked_profile_id.to_string()]
        );

        let unset_headers = signed_auth_headers(
            device_id,
            &signing_key,
            "blocks-unset",
            |ts_ms, nonce_b64| {
                http_blocks_set_auth_message(device_id, blocked_profile_id, false, ts_ms, nonce_b64)
            },
        );
        let unset_response = http_blocks_set(
            Path(device_id.to_string()),
            unset_headers,
            State(state.clone()),
            Json(HttpBlocksSetReq {
                blocked_profile_id: blocked_profile_id.into(),
                blocked: false,
            }),
        )
        .await
        .unwrap()
        .0;
        assert!(unset_response.ok);

        let list_after_unset_headers = signed_auth_headers(
            device_id,
            &signing_key,
            "blocks-list-after-unset",
            |ts_ms, nonce_b64| http_blocks_list_auth_message(device_id, ts_ms, nonce_b64),
        );
        let list_after_unset = http_blocks_list(
            Path(device_id.to_string()),
            list_after_unset_headers,
            State(state),
        )
        .await
        .unwrap()
        .0;
        assert!(list_after_unset.blocked_profile_ids.is_empty());
    }

    #[tokio::test]
    async fn http_push_token_set_upserts_and_deletes_token_for_valid_signed_request() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[41u8; 32]);
        let device_id = "dev_push_1";
        let token = "push-token-123";

        cache_authenticated_device(&state, device_id, "profile_push_1", &signing_key);

        let upsert_headers = signed_auth_headers(
            device_id,
            &signing_key,
            "push-upsert",
            |ts_ms, nonce_b64| {
                http_push_token_set_auth_message(
                    device_id, token, "ios", true, None, ts_ms, nonce_b64,
                )
            },
        );
        let upsert_response = http_push_token_set(
            Path(device_id.to_string()),
            upsert_headers,
            State(state.clone()),
            Json(HttpPushTokenSetReq {
                token: token.into(),
                platform: Some("ios".into()),
                enabled: Some(true),
                policy_b64: None,
            }),
        )
        .await
        .unwrap()
        .0;
        assert!(upsert_response.ok);

        let stored = state
            .store
            .get_push_token(device_id)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(stored.device_id, device_id);
        assert_eq!(stored.token, token);
        assert_eq!(stored.platform, "ios");

        let delete_headers = signed_auth_headers(
            device_id,
            &signing_key,
            "push-delete",
            |ts_ms, nonce_b64| {
                http_push_token_set_auth_message(
                    device_id, token, "ios", false, None, ts_ms, nonce_b64,
                )
            },
        );
        let delete_response = http_push_token_set(
            Path(device_id.to_string()),
            delete_headers,
            State(state.clone()),
            Json(HttpPushTokenSetReq {
                token: token.into(),
                platform: Some("ios".into()),
                enabled: Some(false),
                policy_b64: None,
            }),
        )
        .await
        .unwrap()
        .0;
        assert!(delete_response.ok);
        assert!(
            state
                .store
                .get_push_token(device_id)
                .await
                .unwrap()
                .is_none()
        );
    }

    #[tokio::test]
    async fn http_push_token_set_rejects_cross_device_binding_attempt() {
        let (state, _dir) = test_app_state().await;
        let owner_key = SigningKey::from_bytes(&[42u8; 32]);
        let foreign_key = SigningKey::from_bytes(&[43u8; 32]);
        let target_device_id = "dev_push_target_2";
        let foreign_device_id = "dev_push_foreign_2";
        let token = "push-token-foreign";

        cache_authenticated_device(
            &state,
            target_device_id,
            "profile_push_target_2",
            &owner_key,
        );
        cache_authenticated_device(
            &state,
            foreign_device_id,
            "profile_push_foreign_2",
            &foreign_key,
        );

        let headers = signed_auth_headers(
            foreign_device_id,
            &foreign_key,
            "push-cross-device",
            |ts_ms, nonce_b64| {
                http_push_token_set_auth_message(
                    target_device_id,
                    token,
                    "ios",
                    true,
                    None,
                    ts_ms,
                    nonce_b64,
                )
            },
        );

        let err = match http_push_token_set(
            Path(target_device_id.to_string()),
            headers,
            State(state.clone()),
            Json(HttpPushTokenSetReq {
                token: token.into(),
                platform: Some("ios".into()),
                enabled: Some(true),
                policy_b64: None,
            }),
        )
        .await
        {
            Ok(_) => panic!("expected cross-device push token bind to be rejected"),
            Err(err) => err,
        };
        assert_eq!(err.0, StatusCode::UNAUTHORIZED);
        assert_eq!(err.1, "device_id mismatch");
        assert!(
            state
                .store
                .get_push_token(target_device_id)
                .await
                .unwrap()
                .is_none()
        );
    }

    #[tokio::test]
    async fn http_push_token_set_accepts_ios_voip_without_overwriting_regular_ios() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[44u8; 32]);
        let device_id = "dev_push_unsupported_1";
        let token = "push-token-ios";
        let voip_token = "push-token-voip";

        cache_authenticated_device(
            &state,
            device_id,
            "profile_push_unsupported_1",
            &signing_key,
        );

        let upsert_headers = signed_auth_headers(
            device_id,
            &signing_key,
            "push-unsupported-existing",
            |ts_ms, nonce_b64| {
                http_push_token_set_auth_message(
                    device_id, token, "ios", true, None, ts_ms, nonce_b64,
                )
            },
        );
        let upsert_response = http_push_token_set(
            Path(device_id.to_string()),
            upsert_headers,
            State(state.clone()),
            Json(HttpPushTokenSetReq {
                token: token.into(),
                platform: Some("ios".into()),
                enabled: Some(true),
                policy_b64: None,
            }),
        )
        .await
        .unwrap()
        .0;
        assert!(upsert_response.ok);

        let voip_headers = signed_auth_headers(
            device_id,
            &signing_key,
            "push-ios-voip",
            |ts_ms, nonce_b64| {
                http_push_token_set_auth_message(
                    device_id, voip_token, "ios_voip", true, None, ts_ms, nonce_b64,
                )
            },
        );
        let voip_response = http_push_token_set(
            Path(device_id.to_string()),
            voip_headers,
            State(state.clone()),
            Json(HttpPushTokenSetReq {
                token: voip_token.into(),
                platform: Some("ios_voip".into()),
                enabled: Some(true),
                policy_b64: None,
            }),
        )
        .await
        .unwrap()
        .0;
        assert!(voip_response.ok);

        let stored = state
            .store
            .get_push_token_for_platform(device_id, "ios")
            .await
            .unwrap()
            .unwrap();
        assert_eq!(stored.token, token);
        assert_eq!(stored.platform, "ios");

        let stored_voip = state
            .store
            .get_push_token_for_platform(device_id, "ios_voip")
            .await
            .unwrap()
            .unwrap();
        assert_eq!(stored_voip.token, voip_token);
        assert_eq!(stored_voip.platform, "ios_voip");
    }

    fn blob_body_hash_b64(body: &[u8]) -> String {
        base64::engine::general_purpose::STANDARD.encode(Sha256::digest(body))
    }

    fn signed_blob_upload_headers(
        device_id: &str,
        signing_key: &SigningKey,
        ttl_seconds: u64,
        body_hash_for_auth_message: &str,
        access_token_b64: &str,
        nonce_seed: &str,
        body_hash_header: Option<&str>,
        include_access_token_hash_header: bool,
    ) -> HeaderMap {
        let ts_ms = now_ms();
        let nonce_b64 = base64::engine::general_purpose::STANDARD.encode(nonce_seed.as_bytes());
        let access_token_sha256_b64 = blob_access_token_hash_b64(access_token_b64).unwrap();
        let auth_message = http_blob_upload_auth_message(
            device_id,
            ttl_seconds,
            body_hash_for_auth_message,
            &access_token_sha256_b64,
            ts_ms,
            &nonce_b64,
        );
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
        if include_access_token_hash_header {
            headers.insert(
                "x-secretly-blob-access-token-sha256-b64",
                HeaderValue::from_str(&access_token_sha256_b64).unwrap(),
            );
        }
        if let Some(body_hash_header) = body_hash_header {
            headers.insert(
                "x-secretly-body-sha256-b64",
                HeaderValue::from_str(body_hash_header).unwrap(),
            );
        }
        headers
    }

    #[tokio::test]
    async fn http_blob_upload_requires_access_token_hash_header() {
        let (state, _dir) = test_app_state().await;

        let err = match http_blob_upload(
            State(state),
            Query(BlobUploadQuery {
                ttl_seconds: Some(60),
            }),
            HeaderMap::new(),
            Body::from(Vec::from(*b"ciphertext-body")),
        )
        .await
        {
            Ok(_) => panic!("expected missing blob access token hash header to fail"),
            Err(err) => err,
        };

        assert_eq!(err.0, StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn http_blob_upload_rejects_body_hash_mismatch_after_valid_auth() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[21u8; 32]);
        let access_token_b64 = base64::engine::general_purpose::STANDARD.encode([17u8; 32]);
        let body = b"ciphertext-body";
        let wrong_hash = blob_body_hash_b64(b"different-body");

        cache_authenticated_device(&state, "dev_uploader_1", "profile_uploader_1", &signing_key);
        let headers = signed_blob_upload_headers(
            "dev_uploader_1",
            &signing_key,
            60,
            &wrong_hash,
            &access_token_b64,
            "upload-mismatch",
            Some(&wrong_hash),
            true,
        );

        let err = match http_blob_upload(
            State(state),
            Query(BlobUploadQuery {
                ttl_seconds: Some(60),
            }),
            headers,
            Body::from(body.to_vec()),
        )
        .await
        {
            Ok(_) => panic!("expected mismatched body hash upload to fail"),
            Err(err) => err,
        };

        assert_eq!(err.0, StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn http_blob_upload_persists_hashed_capability_for_authenticated_owner() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[22u8; 32]);
        let access_token_b64 = base64::engine::general_purpose::STANDARD.encode([18u8; 32]);
        let expected_token_hash = blob_access_token_hash_b64(&access_token_b64).unwrap();
        let body = b"ciphertext-body";
        let body_hash = blob_body_hash_b64(body);

        cache_authenticated_device(&state, "dev_uploader_2", "profile_uploader_2", &signing_key);
        let headers = signed_blob_upload_headers(
            "dev_uploader_2",
            &signing_key,
            60,
            &body_hash,
            &access_token_b64,
            "upload-success",
            Some(&body_hash),
            true,
        );

        let response = http_blob_upload(
            State(state.clone()),
            Query(BlobUploadQuery {
                ttl_seconds: Some(60),
            }),
            headers,
            Body::from(body.to_vec()),
        )
        .await
        .unwrap()
        .0;

        let stored = state
            .store
            .blob_get(&response.blob_id, now_ms())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(stored.owner_profile_id, "profile_uploader_2");
        assert_eq!(stored.access_token_sha256_b64, expected_token_hash);

        let stored_bytes = tokio::fs::read(state.blobs_dir.join(stored.rel_path))
            .await
            .unwrap();
        assert_eq!(stored_bytes, body);
    }

    #[tokio::test]
    async fn http_blob_get_allows_authenticated_request_with_matching_capability() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[11u8; 32]);
        let access_token_b64 = base64::engine::general_purpose::STANDARD.encode([7u8; 32]);
        let blob_id = "bloballow1";
        let body = b"ciphertext-body";

        cache_authenticated_device(&state, "dev_reader_1", "profile_reader_1", &signing_key);
        insert_blob_fixture(
            &state,
            blob_id,
            "dev_owner_1",
            "profile_owner_1",
            Some(&access_token_b64),
            body,
            now_ms() + 60_000,
        )
        .await;

        let headers = signed_blob_get_headers(
            "dev_reader_1",
            &signing_key,
            blob_id,
            Some(&access_token_b64),
            "allow-capability",
        );

        let resp = http_blob_get(Path(blob_id.to_string()), headers, State(state))
            .await
            .unwrap();

        // Отдача стала потоковой (02.09.2026): содержимое собирается из тела
        // ответа, а не приходит готовым вектором. Проверяем и заявленную длину
        // — клиент по ней рисует прогресс, и молчаливая её потеря увела бы
        // скачивание в chunked без видимого отказа.
        assert_eq!(resp.status(), StatusCode::OK);
        assert_eq!(
            resp.headers()
                .get(header::CONTENT_LENGTH)
                .and_then(|v| v.to_str().ok()),
            Some(body.len().to_string().as_str()),
        );
        let data = axum::body::to_bytes(resp.into_body(), usize::MAX)
            .await
            .unwrap();

        assert_eq!(data.as_ref(), body);
    }

    /// СТРАЖ ВРЕМЕННОГО ФАЙЛА (найдено 02.09.2026, аудит передачи файлов).
    ///
    /// Явное удаление `.tmp` стояло только на трёх ветках обработчика заливки:
    /// превышение лимита, несовпадение хеша, провал подписи. Обрыв клиента
    /// посреди тела, ошибка записи, провал flush или rename и отказ от future
    /// самим axum не удаляли ничего — а убрать это потом было нечем:
    /// `cleanup_expired_blobs` ходит по строкам таблицы, куда оборванная
    /// заливка не попадает. Отмена на 90 % от 200 МБ означала 180 МБ, лежащих
    /// на диске вечно и попадающих в каждую ежедневную копию.
    #[test]
    fn tmp_blob_guard_removes_file_when_upload_never_completes() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("aborted.tmp");
        std::fs::write(&path, b"partial upload").unwrap();

        {
            let _guard = TmpBlobGuard::arm(path.clone());
            // Выход без disarm — обрыв, ошибка записи, отказ от future.
        }

        assert!(
            !path.exists(),
            "временный файл обязан исчезнуть на любом выходе, иначе он остаётся \
             на диске навсегда: свипера по нему нет"
        );
    }

    /// Обратная сторона: снятый страж НЕ ИМЕЕТ ПРАВА трогать файл. Если снять
    /// охрану неверно, удалится только что принятый блоб — под его новым
    /// именем, уже записанным в базу.
    #[test]
    fn tmp_blob_guard_keeps_file_after_disarm() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("accepted.bin");
        std::fs::write(&path, b"accepted blob").unwrap();

        {
            let mut guard = TmpBlobGuard::arm(path.clone());
            guard.disarm(); // так делает обработчик после удачного rename
        }

        assert!(
            path.exists(),
            "после успешного переименования файл принадлежит хранилищу, \
             а не заливке — страж обязан его отпустить"
        );
    }

    #[tokio::test]
    async fn http_blob_get_rejects_missing_capability_even_with_valid_auth() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[12u8; 32]);
        let access_token_b64 = base64::engine::general_purpose::STANDARD.encode([8u8; 32]);
        let blob_id = "blobmiss1";

        cache_authenticated_device(&state, "dev_reader_2", "profile_reader_2", &signing_key);
        insert_blob_fixture(
            &state,
            blob_id,
            "dev_owner_2",
            "profile_owner_2",
            Some(&access_token_b64),
            b"ciphertext-body",
            now_ms() + 60_000,
        )
        .await;

        let headers = signed_blob_get_headers(
            "dev_reader_2",
            &signing_key,
            blob_id,
            None,
            "missing-capability",
        );

        let err = http_blob_get(Path(blob_id.to_string()), headers, State(state))
            .await
            .unwrap_err();
        assert_eq!(err.0, StatusCode::FORBIDDEN);
    }

    #[tokio::test]
    async fn http_blob_get_rejects_wrong_capability_even_with_valid_auth() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[13u8; 32]);
        let good_access_token_b64 = base64::engine::general_purpose::STANDARD.encode([9u8; 32]);
        let wrong_access_token_b64 = base64::engine::general_purpose::STANDARD.encode([10u8; 32]);
        let blob_id = "blobwrong1";

        cache_authenticated_device(&state, "dev_reader_3", "profile_reader_3", &signing_key);
        insert_blob_fixture(
            &state,
            blob_id,
            "dev_owner_3",
            "profile_owner_3",
            Some(&good_access_token_b64),
            b"ciphertext-body",
            now_ms() + 60_000,
        )
        .await;

        let headers = signed_blob_get_headers(
            "dev_reader_3",
            &signing_key,
            blob_id,
            Some(&wrong_access_token_b64),
            "wrong-capability",
        );

        let err = http_blob_get(Path(blob_id.to_string()), headers, State(state))
            .await
            .unwrap_err();
        assert_eq!(err.0, StatusCode::FORBIDDEN);
    }

    #[tokio::test]
    async fn http_blob_get_rejects_blocked_authenticated_requester() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[14u8; 32]);
        let access_token_b64 = base64::engine::general_purpose::STANDARD.encode([11u8; 32]);
        let blob_id = "blobblock1";

        cache_authenticated_device(&state, "dev_reader_4", "profile_reader_4", &signing_key);
        insert_blob_fixture(
            &state,
            blob_id,
            "dev_owner_4",
            "profile_owner_4",
            Some(&access_token_b64),
            b"ciphertext-body",
            now_ms() + 60_000,
        )
        .await;
        state
            .store
            .set_block("profile_owner_4", "profile_reader_4", true, now_ms())
            .await
            .unwrap();

        let headers = signed_blob_get_headers(
            "dev_reader_4",
            &signing_key,
            blob_id,
            Some(&access_token_b64),
            "blocked-reader",
        );

        let err = http_blob_get(Path(blob_id.to_string()), headers, State(state))
            .await
            .unwrap_err();
        assert_eq!(err.0, StatusCode::FORBIDDEN);
    }

    #[tokio::test]
    async fn http_blob_get_returns_not_found_for_expired_blob() {
        let (state, _dir) = test_app_state().await;
        let signing_key = SigningKey::from_bytes(&[15u8; 32]);
        let access_token_b64 = base64::engine::general_purpose::STANDARD.encode([12u8; 32]);
        let blob_id = "blobexp1";

        cache_authenticated_device(&state, "dev_reader_5", "profile_reader_5", &signing_key);
        insert_blob_fixture(
            &state,
            blob_id,
            "dev_owner_5",
            "profile_owner_5",
            Some(&access_token_b64),
            b"ciphertext-body",
            now_ms() - 1,
        )
        .await;

        let headers = signed_blob_get_headers(
            "dev_reader_5",
            &signing_key,
            blob_id,
            Some(&access_token_b64),
            "expired-blob",
        );

        let err = http_blob_get(Path(blob_id.to_string()), headers, State(state))
            .await
            .unwrap_err();
        assert_eq!(err.0, StatusCode::NOT_FOUND);
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
    fn relay_security_errors_fail_closed_in_production() {
        let errors = relay_security_errors(
            std::net::IpAddr::from([0, 0, 0, 0]),
            true,
            false,
            true,
            false,
            "",
        );

        assert_eq!(errors.len(), 3);
        assert!(
            errors
                .iter()
                .any(|err| err.contains("SECRETLY_RELAY_REQUIRE_AUTH"))
        );
        assert!(
            errors
                .iter()
                .any(|err| err.contains("SECRETLY_RELAY_PROXY_ONLY"))
        );
        assert!(
            errors
                .iter()
                .any(|err| err.contains("SECRETLY_INTERNAL_KEY"))
        );
    }

    #[test]
    fn relay_security_errors_allow_trusted_proxy_mode() {
        let errors = relay_security_errors(
            std::net::IpAddr::from([0, 0, 0, 0]),
            true,
            true,
            true,
            true,
            "super-secret",
        );

        assert!(errors.is_empty());
    }

    #[test]
    fn relay_security_errors_allow_relaxed_config_outside_production() {
        let errors = relay_security_errors(
            std::net::IpAddr::from([0, 0, 0, 0]),
            false,
            false,
            true,
            false,
            "",
        );

        assert!(errors.is_empty());
    }

    #[test]
    fn relay_security_errors_allow_trusted_xff_on_loopback_without_proxy_only() {
        let errors = relay_security_errors(
            std::net::IpAddr::from([127, 0, 0, 1]),
            true,
            true,
            true,
            false,
            "super-secret",
        );

        assert!(errors.is_empty());
    }

    #[tokio::test]
    async fn health_reports_require_auth_runtime_flag() {
        let (mut state, _dir) = test_app_state().await;
        state.require_auth = false;

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
        assert_eq!(json["service"], "relay");
        assert_eq!(json["require_auth"], false);
        assert_eq!(json["status"], "ok");
        assert_eq!(
            json["max_request_body_bytes"],
            RELAY_HTTP_BODY_LIMIT_BYTES as i64
        );
        assert_eq!(json["max_attachment_bytes"], RELAY_MAX_ATTACHMENT_BYTES);
    }

    #[tokio::test]
    async fn push_health_reports_provider_readiness_and_token_counts() {
        let (mut state, _dir) = test_app_state().await;
        state.fcm_v1 = Arc::new(Some(FcmV1Config {
            project_id: "project-1".into(),
            client_email: "firebase@example.test".into(),
            private_key_pem: "key".into(),
            token_uri: "https://oauth.example.test/token".into(),
            scope: "https://www.googleapis.com/auth/firebase.messaging".into(),
            send_url: "https://fcm.googleapis.com/v1/projects/project-1/messages:send".into(),
        }));
        state.apns_voip = Arc::new(Some(ApnsVoipConfig {
            team_id: "TEAMID1234".into(),
            key_id: "KEYID1234".into(),
            private_key_pem: "key".into(),
            topic: "com.secretly.messenger.voip".into(),
            endpoint_base: "https://api.sandbox.push.apple.com".into(),
            environment: "development".into(),
            allow_environment_fallback: true,
        }));
        state
            .store
            .upsert_push_token(
                "device_push_android_1",
                "token-a",
                "android",
                None,
                now_ms(),
            )
            .await
            .unwrap();
        state
            .store
            .upsert_push_token("device_push_ios_1", "token-i", "ios", None, now_ms())
            .await
            .unwrap();
        state
            .store
            .upsert_push_token("device_push_ios_1", "token-v", "ios_voip", None, now_ms())
            .await
            .unwrap();

        let response = push_health(State(state)).await.into_response();

        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(json["service"], "relay_push");
        assert_eq!(json["status"], "ok");
        assert_eq!(json["push_ready"], true);
        assert_eq!(json["fcm_v1_configured"], true);
        assert_eq!(json["apns_voip_configured"], true);
        assert_eq!(json["android_push_ready"], true);
        assert_eq!(json["ios_push_ready"], true);
        assert_eq!(json["ios_voip_push_ready"], true);
        assert_eq!(json["push_tokens_total"], 3);
        assert_eq!(json["push_tokens_android"], 1);
        assert_eq!(json["push_tokens_ios"], 1);
        assert_eq!(json["push_tokens_ios_voip"], 1);
        assert_eq!(json["apns_environment"], "development");
        assert_eq!(json["apns_environment_fallback_enabled"], true);
        assert_eq!(json["apns_voip_topic"], "com.secretly.messenger.voip");
    }

    #[test]
    fn blob_access_token_hash_is_stable_for_same_token() {
        let token = base64::engine::general_purpose::STANDARD.encode([7u8; 32]);
        let first = blob_access_token_hash_b64(&token).unwrap();
        let second = blob_access_token_hash_b64(&token).unwrap();
        assert_eq!(first, second);
    }

    #[test]
    fn blob_access_token_hash_rejects_bad_input() {
        assert!(blob_access_token_hash_b64("not-base64").is_err());
        let short = base64::engine::general_purpose::STANDARD.encode([1u8; 4]);
        assert!(blob_access_token_hash_b64(&short).is_err());
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

    // 🔴 Ключ схлопывания звонковых пробуждений (08.08.2026).
    //
    // Полевой дефект: «звонок отменил, но на андроид не отменился» и «звонки
    // вообще не приходят при закрытом приложении». Причина — общий ключ
    // `secretly_pending_<dev>` у ВСЕХ тихих пушей: у FCM/APNs он работает на
    // ЗАМЕНУ, и пока устройство спит, служба держит одно последнее сообщение на
    // ключ. Поток обычных пробуждений затирал то приглашение, то отбой.
    fn call_wake_payload(action: &str, call_id: &str) -> PushWakePayload {
        let mut data = serde_json::Map::new();
        let kind = if action == "invite" {
            "call_invite_v1"
        } else {
            "call_signal_wake_v1"
        };
        data.insert("wake_kind".into(), serde_json::Value::String(kind.into()));
        data.insert("action".into(), serde_json::Value::String(action.into()));
        data.insert("call_id".into(), serde_json::Value::String(call_id.into()));
        PushWakePayload {
            notification_title: String::new(),
            notification_body: String::new(),
            collapse_key: "secretly_pending_dev-A".into(),
            notification_tag: call_id.into(),
            include_notification: false,
            data,
            badge: None,
        }
    }

    #[test]
    fn call_invite_and_hangup_never_share_a_collapse_key() {
        // Сердце дефекта: под общим ключом отбой затирал приглашение (звонок не
        // приходил) или наоборот (плашка звонила до таймаута).
        let invite = push_call_collapse_key(&call_wake_payload("invite", "call-1")).unwrap();
        let hangup = push_call_collapse_key(&call_wake_payload("hangup", "call-1")).unwrap();
        assert_ne!(invite, hangup);
    }

    #[test]
    fn call_wakes_never_share_the_mailbox_key() {
        // Иначе поток «сходи забери почту» продолжит затирать звонок: именно
        // такие пачки и стояли рядом с потерянным отбоем в полевом логе.
        let invite = push_call_collapse_key(&call_wake_payload("invite", "call-1")).unwrap();
        assert!(!invite.contains("secretly_pending"));
    }

    #[test]
    fn different_calls_get_different_collapse_keys() {
        let a = push_call_collapse_key(&call_wake_payload("invite", "call-1")).unwrap();
        let b = push_call_collapse_key(&call_wake_payload("invite", "call-2")).unwrap();
        assert_ne!(a, b);
    }

    #[test]
    fn a_long_call_id_still_cannot_collide_invite_with_hangup() {
        // 🔴 Обратная защёлка на МОЮ ЖЕ ловушку: ключ обрезается до 64 байт для
        // APNs, а call_id сервер принимает до 128 символов. Стой идентификатор
        // первым — действие уехало бы за обрез, и дефект вернулся бы целиком.
        let long_id = "c".repeat(128);
        let invite = truncate_collapse_id(
            push_call_collapse_key(&call_wake_payload("invite", &long_id)).unwrap(),
        );
        let hangup = truncate_collapse_id(
            push_call_collapse_key(&call_wake_payload("hangup", &long_id)).unwrap(),
        );
        assert_ne!(invite, hangup);
        assert!(invite.len() <= 64, "APNs отвергает ключ длиннее 64 байт");
        assert!(hangup.len() <= 64);
    }

    #[test]
    fn non_call_wakes_keep_their_old_key() {
        // Границы правки: сообщения не тронуты. Тихое пробуждение почты обязано
        // остаться на прежнем ключе — эти пробуждения ВЗАИМОЗАМЕНЯЕМЫ, и
        // схлопывать их в одно правильно.
        let mut data = serde_json::Map::new();
        data.insert(
            "wake_kind".into(),
            serde_json::Value::String("chat_message_v1".into()),
        );
        let payload = PushWakePayload {
            notification_title: String::new(),
            notification_body: String::new(),
            collapse_key: "secretly_pending_dev-A".into(),
            notification_tag: "convo-1".into(),
            include_notification: false,
            data,
            badge: None,
        };
        assert!(push_call_collapse_key(&payload).is_none());
        assert_eq!(
            push_collapse_identity(&payload, false),
            "secretly_pending_dev-A"
        );
    }

    #[test]
    fn effective_client_ip_uses_last_xff_hop_when_trusted() {
        // Последний в цепочке — тот, кого подставил ДОВЕРЕННЫЙ прокси.
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-forwarded-for",
            HeaderValue::from_static("198.51.100.10, 10.0.0.1"),
        );

        let ip = effective_client_ip(&headers, std::net::IpAddr::from([127, 0, 0, 1]), true);
        assert_eq!(ip, std::net::IpAddr::from([10, 0, 0, 1]));
    }

    /// 🔴 ПОДДЕЛКА АДРЕСА ОДНИМ ЗАГОЛОВКОМ.
    ///
    /// Клиент присылает свой X-Forwarded-For, прокси ДОПИСЫВАЕТ его настоящий
    /// адрес следом. Чтение первого значения отдало бы ограничителю выдуманный
    /// адрес: своё ведро подделывается, чужое исчерпывается за него. Именно
    /// поэтому доверие к заголовку нельзя было включать со старым разбором —
    /// это не починило бы ограничитель, а отключило.
    #[test]
    fn effective_client_ip_ignores_client_supplied_xff_prefix() {
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-forwarded-for",
            // "1.2.3.4" прислал сам клиент; "203.0.113.7" дописал прокси.
            HeaderValue::from_static("1.2.3.4, 203.0.113.7"),
        );

        let ip = effective_client_ip(&headers, std::net::IpAddr::from([127, 0, 0, 1]), true);
        assert_eq!(
            ip,
            std::net::IpAddr::from([203, 0, 113, 7]),
            "подставленный клиентом адрес не имеет права попасть в ограничитель"
        );
    }

    #[test]
    fn effective_client_ip_uses_the_only_hop_when_proxy_sets_one() {
        // Обычный случай: клиент заголовок не слал, прокси поставил один адрес.
        let mut headers = HeaderMap::new();
        headers.insert("x-forwarded-for", HeaderValue::from_static("203.0.113.7"));

        let ip = effective_client_ip(&headers, std::net::IpAddr::from([127, 0, 0, 1]), true);
        assert_eq!(ip, std::net::IpAddr::from([203, 0, 113, 7]));
    }

    #[test]
    fn effective_client_ip_falls_back_for_bad_xff() {
        let mut headers = HeaderMap::new();
        headers.insert("x-forwarded-for", HeaderValue::from_static("not-an-ip"));

        let ip = effective_client_ip(&headers, std::net::IpAddr::from([127, 0, 0, 1]), true);
        assert_eq!(ip, std::net::IpAddr::from([127, 0, 0, 1]));
    }

    #[test]
    fn blob_capability_authorization_rejects_empty_stored_token() {
        // AUD-029: historic rows with no stored access-token hash must not be
        // treated as public; fail-close with 403 regardless of whether a
        // token is presented by the caller.
        let err = ensure_blob_capability_authorized("", None).unwrap_err();
        assert_eq!(err.0, StatusCode::FORBIDDEN);
        let err = ensure_blob_capability_authorized("", Some("any-hash")).unwrap_err();
        assert_eq!(err.0, StatusCode::FORBIDDEN);
    }

    #[test]
    fn blob_capability_authorization_rejects_missing_capability() {
        let err = ensure_blob_capability_authorized("stored-hash", None).unwrap_err();
        assert_eq!(err.0, StatusCode::FORBIDDEN);
    }

    #[test]
    fn blob_capability_authorization_rejects_wrong_capability() {
        let err = ensure_blob_capability_authorized("stored-hash", Some("wrong-hash")).unwrap_err();
        assert_eq!(err.0, StatusCode::FORBIDDEN);
    }

    #[test]
    fn blob_capability_authorization_accepts_matching_capability() {
        assert!(ensure_blob_capability_authorized("stored-hash", Some("stored-hash")).is_ok());
    }

    #[test]
    fn call_readiness_requires_working_turn_credentials() {
        let cfg = RelayCallIceRuntimeConfig {
            policy: "relay_preferred".into(),
            stun_urls: vec!["stun:stun.secretly.test:3478".into()],
            turn_urls: vec!["turn:turn.secretly.test:3478?transport=udp".into()],
            turn_shared_secret: String::new(),
            turn_ttl_seconds: 600,
        };

        let summary = summarize_call_ice_readiness(&cfg);
        assert!(!summary.calls_ready);
        assert!(!summary.turn_credentials_ready);
        assert_eq!(summary.effective_policy, "p2p_preferred");
        assert_eq!(summary.turn_server_count, 1);
    }

    #[test]
    fn call_readiness_is_ready_when_turn_and_secret_exist() {
        let cfg = RelayCallIceRuntimeConfig {
            policy: "relay_preferred".into(),
            stun_urls: vec!["stun:stun.secretly.test:3478".into()],
            turn_urls: vec!["turn:turn.secretly.test:3478?transport=udp".into()],
            turn_shared_secret: "super-secret".into(),
            turn_ttl_seconds: 600,
        };

        let summary = summarize_call_ice_readiness(&cfg);
        assert!(summary.calls_ready);
        assert!(summary.turn_credentials_ready);
        assert_eq!(summary.effective_policy, "relay_preferred");
        assert_eq!(summary.stun_server_count, 1);
        assert_eq!(summary.turn_server_count, 1);
    }

    #[test]
    fn room_media_readiness_degrades_when_runtime_registration_is_incomplete() {
        let call_summary = CallReadinessSummary {
            calls_ready: true,
            requested_policy: "relay_preferred".into(),
            effective_policy: "relay_preferred".into(),
            stun_server_count: 1,
            turn_server_count: 1,
            turn_credentials_ready: true,
        };
        let media_summary = RoomCallMediaHealthSummary {
            active_room_call_count: 1,
            joined_room_call_participant_count: 2,
            registered_room_media_participant_count: 1,
            fully_registered_room_call_count: 0,
        };
        let room_media_config = RelayRoomMediaRuntimeConfig {
            requested_backend: RelayRoomMediaBackendKind::Livekit,
            effective_backend: RelayRoomMediaBackendKind::Livekit,
            livekit_url: "wss://livekit.secretly.test".into(),
            livekit_api_key: "relay-livekit-key".into(),
            livekit_api_secret: "relay-livekit-secret".into(),
            token_ttl_seconds: 300,
        };

        let summary =
            summarize_room_media_readiness(&call_summary, &media_summary, &room_media_config);
        assert!(summary.ice_ready);
        assert!(!summary.runtime_registration_complete);
        assert!(summary.session_auth_ready);
        assert!(!summary.room_media_ready);
    }

    #[test]
    fn evaluate_client_compatibility_accepts_supported_protocol() {
        let result = evaluate_client_compatibility("relay", Some(2), 1, 2);

        assert!(result.supported);
        assert_eq!(result.compatibility_status, "supported");
        assert!(result.compatibility_message.is_none());
    }

    #[test]
    fn evaluate_client_compatibility_rejects_too_old_client() {
        let result = evaluate_client_compatibility("relay", Some(1), 2, 3);

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
        let result = evaluate_client_compatibility("relay", Some(4), 1, 3);

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
            optional_trimmed_string(" candidate "),
            Some("candidate".to_string())
        );
    }
}
