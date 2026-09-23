// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
const ROOM_MEMBERSHIP_SELECT_BY_ID_SQL: &str = "SELECT room_id, profile_id, status, role, source_link_id, tag, created_at_ms, updated_at_ms FROM room_memberships WHERE room_id = ?1 AND profile_id = ?2";

/// SEC-09: сколько дней сервер помнит, кто отправил сообщение в комнату.
///
/// После этого срока поле обнуляется — сама запись остаётся, чтобы закрепление
/// сообщений продолжало работать. Тридцати дней хватает и на разбор жалоб, и
/// на то, чтобы не держать вечный журнал участия в группах.
const ROOM_MESSAGE_SENDER_RETENTION_DAYS: i64 = 30;
const ROOM_MEMBERSHIPS_SELECT_BY_ROOM_SQL: &str = "SELECT room_id, profile_id, status, role, source_link_id, tag, created_at_ms, updated_at_ms FROM room_memberships WHERE room_id = ?1 ORDER BY CASE status WHEN 'active' THEN 0 WHEN 'pending' THEN 1 WHEN 'left' THEN 2 WHEN 'removed' THEN 3 WHEN 'banned' THEN 4 ELSE 5 END, CASE role WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 WHEN 'moderator' THEN 2 WHEN 'member' THEN 3 WHEN 'restricted' THEN 4 WHEN 'guest' THEN 5 ELSE 6 END, created_at_ms ASC, profile_id ASC";
const ROOM_CALL_SELECT_BY_ID_SQL: &str = "SELECT call_id, room_id, state, media_type, created_by_profile_id, created_by_device_id, state_version, started_at_ms, updated_at_ms, ended_at_ms, expires_at_ms FROM room_call_sessions WHERE call_id = ?1";
const ROOM_CALL_ACTIVE_SELECT_BY_ROOM_SQL: &str = "SELECT call_id, room_id, state, media_type, created_by_profile_id, created_by_device_id, state_version, started_at_ms, updated_at_ms, ended_at_ms, expires_at_ms FROM room_call_sessions WHERE room_id = ?1 AND state = 'active' ORDER BY started_at_ms DESC LIMIT 1";
const ROOM_CALL_SELECT_BY_ROOM_AND_ID_SQL: &str = "SELECT call_id, room_id, state, media_type, created_by_profile_id, created_by_device_id, state_version, started_at_ms, updated_at_ms, ended_at_ms, expires_at_ms FROM room_call_sessions WHERE room_id = ?1 AND call_id = ?2";
const ROOM_CALL_PARTICIPANT_SELECT_BY_ID_SQL: &str = "SELECT call_id, room_id, profile_id, device_id, join_state, supports_video, supports_screen_share, muted, deafened, video_enabled, screen_share_enabled, speaking, joined_at_ms, left_at_ms, updated_at_ms FROM room_call_participants WHERE call_id = ?1 AND device_id = ?2";
const ROOM_CALL_PARTICIPANTS_SELECT_BY_CALL_SQL: &str = "SELECT call_id, room_id, profile_id, device_id, join_state, supports_video, supports_screen_share, muted, deafened, video_enabled, screen_share_enabled, speaking, joined_at_ms, left_at_ms, updated_at_ms FROM room_call_participants WHERE call_id = ?1 ORDER BY CASE join_state WHEN 'joined' THEN 0 WHEN 'reconnecting' THEN 1 WHEN 'left' THEN 2 WHEN 'removed' THEN 3 ELSE 4 END, joined_at_ms ASC, profile_id ASC, device_id ASC";
const ROOM_CALL_MEDIA_PARTICIPANT_SELECT_BY_ID_SQL: &str = "SELECT call_id, room_id, profile_id, device_id, publish_audio, publish_video, publish_screen_share, subscribe_all, created_at_ms, updated_at_ms FROM room_call_media_participants WHERE call_id = ?1 AND device_id = ?2";
const ROOM_CALL_MEDIA_PARTICIPANTS_SELECT_BY_CALL_SQL: &str = "SELECT call_id, room_id, profile_id, device_id, publish_audio, publish_video, publish_screen_share, subscribe_all, created_at_ms, updated_at_ms FROM room_call_media_participants WHERE call_id = ?1 ORDER BY updated_at_ms DESC, profile_id ASC, device_id ASC";

use std::{env, path::Path};

use tokio_rusqlite::Connection;
use tokio_rusqlite::params;
use tokio_rusqlite::rusqlite::{self, OptionalExtension};
use uuid::Uuid;

#[derive(Debug, Clone)]
pub struct PendingRow {
    pub seq: u64,
    pub msg_id: String,
    pub ciphertext_b64: String,
    pub transport_meta_json: Option<String>,
    /// DELIVERY JOURNAL (2026-08-01, docs/DELIVERY_AUDIT_2026-08-01.md):
    /// 0 = this row has never been offered to the device. Lets a drain report
    /// how many rows are FIRST offers versus rows the client has already been
    /// sent and has not acked — the difference between "mail is flowing" and
    /// "this mailbox is stuck", which the journal previously could not tell.
    /// Read-only here: no delivery decision reads it from this struct (the
    /// redeliver sweep filters on the column in SQL, as before).
    pub last_attempt_ms: i64,
    /// Absolute TTL of the row. A drain reports the SOONEST of these so
    /// "messages are about to be dropped" is visible BEFORE they are gone
    /// rather than reconstructed afterwards.
    pub expires_at_ms: i64,
    /// ИД-1 / С-1 (17.09.2026): the device that AUTHENTICATED when this row
    /// was sent (WS connection or signed HTTP send). The wire header names a
    /// sender too, but that is the sender's own word; this is ours. NULL for
    /// rows queued before the column existed or sent without auth (dev).
    pub from_device_id: Option<String>,
}

/// One device eligible for the offline re-wake sweep: it has unexpired pending
/// rows and at least one push token. See `list_offline_wake_candidates`.
#[derive(Debug, Clone)]
pub struct OfflineWakeCandidate {
    pub device_id: String,
    pub pending_count: u64,
    /// MIN(last_attempt_ms) over the device's pending rows — approximates when
    /// the oldest stranded row was enqueued (nothing re-stamps it while the
    /// device has no live socket).
    pub backlog_started_ms: i64,
    /// Transport meta for the wake payload: newest chat row if any, else the
    /// newest row of any kind.
    pub newest_meta_json: Option<String>,
    pub last_pump_at_ms: i64,
    pub last_push_attempted_at_ms: i64,
}

#[derive(Debug, Clone)]
pub struct CallSignalRecord {
    pub action: String,
    pub call_id: String,
    pub call_attempt_id: String,
    pub signal_id: String,
    pub created_at_ms: i64,
}

#[derive(Debug, Clone)]
pub struct CallSessionRow {
    pub peer_device_id: String,
    pub direction: String,
    pub state: String,
    pub last_action: String,
    pub last_signal_id: String,
    pub last_created_at_ms: i64,
    pub last_received_at_ms: i64,
    pub invited_at_ms: Option<i64>,
    pub accepted_at_ms: Option<i64>,
    pub offer_seen_at_ms: Option<i64>,
    pub answer_seen_at_ms: Option<i64>,
    pub reconnecting_at_ms: Option<i64>,
    pub ended_at_ms: Option<i64>,
    pub expires_at_ms: i64,
}

fn call_session_is_terminal_state(state: &str) -> bool {
    state.eq_ignore_ascii_case("ended")
}

fn call_session_expires_at_ms(
    state: &str,
    now_ms: i64,
    active_ttl_seconds: u32,
    terminal_ttl_seconds: u32,
) -> i64 {
    let ttl_seconds = if call_session_is_terminal_state(state) {
        terminal_ttl_seconds
    } else {
        active_ttl_seconds
    };
    now_ms + (ttl_seconds as i64) * 1000
}

const DEFAULT_CALL_SESSION_TERMINAL_TTL_SECONDS: u32 = 15 * 60;
const DEFAULT_ROOM_CALL_ACTIVE_TTL_SECONDS: u32 = 12 * 60 * 60;
const MESSAGE_DEDUP_MIN_TTL_MS: i64 = 24 * 60 * 60 * 1000;

fn call_session_terminal_ttl_seconds_from_env() -> u32 {
    env::var("SECRETLY_RELAY_TERMINAL_CALL_SESSION_TTL_SECONDS")
        .ok()
        .and_then(|v| v.parse::<u32>().ok())
        .unwrap_or(DEFAULT_CALL_SESSION_TERMINAL_TTL_SECONDS)
        .clamp(60, 24 * 60 * 60)
}

fn room_call_active_ttl_seconds_from_env() -> u32 {
    env::var("SECRETLY_RELAY_ACTIVE_ROOM_CALL_TTL_SECONDS")
        .ok()
        .and_then(|v| v.parse::<u32>().ok())
        .unwrap_or(DEFAULT_ROOM_CALL_ACTIVE_TTL_SECONDS)
        .clamp(60, 24 * 60 * 60)
}

fn room_call_is_terminal_state(state: &str) -> bool {
    state.eq_ignore_ascii_case("ended")
}

fn room_call_expires_at_ms(
    state: &str,
    now_ms: i64,
    active_ttl_seconds: u32,
    terminal_ttl_seconds: u32,
) -> i64 {
    let ttl_seconds = if room_call_is_terminal_state(state) {
        terminal_ttl_seconds
    } else {
        active_ttl_seconds
    };
    now_ms + (ttl_seconds as i64) * 1000
}

#[derive(Debug, Clone)]
pub struct BlobRow {
    pub rel_path: String,
    pub expires_at_ms: i64,
    pub owner_profile_id: String,
    pub access_token_sha256_b64: String,
}

#[derive(Debug, Clone)]
pub struct EnqueueResult {
    pub seq: u64,
    pub dedup: bool,
    /// The row's STORED release time. For a fresh insert this is what we just
    /// stored; for a dedup hit it is the EXISTING row's value.
    ///
    /// SCHEDULED-DELIVERY INVARIANT: callers MUST gate realtime delivery on
    /// THIS value, never on the incoming request's `deliver_at_ms`. Otherwise a
    /// client that re-submits a scheduled `msg_id` as "immediate" (an outbox
    /// re-kick / retry) makes the send handler flush a still-held row early —
    /// the "scheduled message fired as soon as I sent the next message" bug.
    /// 0 = immediate.
    pub deliver_at_ms: i64,
}

#[derive(Debug, Clone)]
pub struct BlockRow {
    pub blocked_profile_id: String,
}

#[derive(Debug, Clone)]
pub struct SupportTicketRow {
    pub ticket_id: String,
    pub profile_id: String,
    pub device_id: String,
    pub reply_pubkey_b64: String,
    pub ciphertext_b64: String,
    pub client_meta_json: Option<String>,
    pub created_at_ms: i64,
    pub status: String,
}

#[derive(Debug, Clone)]
pub struct SupportReplyRow {
    pub reply_id: String,
    pub ticket_id: String,
    pub seq: i64,
    pub ciphertext_b64: String,
    pub created_at_ms: i64,
}

#[derive(Debug, Clone)]
pub struct PushTokenRow {
    pub device_id: String,
    pub token: String,
    pub platform: String,
    pub policy_json: Option<String>,
}

// Sprint 2 R3/R7: per-device liveness snapshot read from `device_activity`.
// `last_pump_at_ms` is bumped whenever the device runs an authenticated
// WS welcome or HTTP fetch-pending; `last_push_*` tracks our outbound
// push-wake attempts and their delivery outcomes. The R3 staleness
// filter classifies a device as "active" iff
// `now_ms - max(last_pump_at_ms, last_push_delivered_at_ms) <= threshold`.
#[derive(Debug, Clone)]
pub struct DeviceActivityRow {
    pub device_id: String,
    pub profile_id: String,
    pub last_pump_at_ms: i64,
    pub last_push_attempted_at_ms: i64,
    pub last_push_delivered_at_ms: i64,
    pub updated_at_ms: i64,
    pub superseded_at_ms: i64,
}

/// The build NUMBER from a reported client build ("588", "1.8.39+588").
/// Anything without digits is 0 — i.e. treated as the oldest possible build.
pub fn parse_client_build(raw: &str) -> i64 {
    let tail: String = raw
        .trim()
        .rsplit(|ch: char| !ch.is_ascii_digit())
        .find(|part| !part.is_empty())
        .unwrap_or("")
        .to_string();
    tail.parse::<i64>().unwrap_or(0)
}

#[derive(Debug, Clone, Default)]
pub struct PushTokenStats {
    pub total: i64,
    pub android: i64,
    pub ios: i64,
    pub ios_voip: i64,
    pub unsupported: i64,
    pub updated_last_24h: i64,
}

#[derive(Debug, Clone)]
pub struct RoomRow {
    pub room_id: String,
    pub version: i64,
    pub membership_version: i64,
    pub owner_profile_id: String,
    pub created_by_device_id: String,
    pub title: String,
    pub description: Option<String>,
    pub avatar_hash: Option<String>,
    pub avatar_image_b64: Option<String>,
    pub reactions_mode: String,
    pub allow_text: bool,
    pub allow_media: bool,
    pub allow_add_members: bool,
    pub allow_pin_messages: bool,
    pub allow_change_group_info: bool,
    pub allow_change_tag: bool,
    pub join_approval_required: bool,
    pub slow_mode_seconds: i64,
    pub chat_history_visible: bool,
    pub pinned_message_id: Option<String>,
    pub created_at_ms: i64,
    pub updated_at_ms: i64,
}

#[derive(Debug, Clone)]
pub struct RoomMembershipRow {
    pub room_id: String,
    pub profile_id: String,
    pub status: String,
    pub role: String,
    pub source_link_id: Option<String>,
    pub tag: Option<String>,
    pub created_at_ms: i64,
    pub updated_at_ms: i64,
}

#[derive(Debug, Clone)]
pub struct RoomInviteLinkRow {
    pub link_id: String,
    pub room_id: String,
    pub slug: String,
    pub created_by_profile_id: String,
    pub expires_at_ms: Option<i64>,
    pub max_uses: Option<i64>,
    pub use_count: i64,
    pub requires_approval: bool,
    pub allowed_role: String,
    pub revoked: bool,
    pub created_at_ms: i64,
    pub updated_at_ms: i64,
}

#[derive(Debug, Clone)]
pub struct RoomCallRow {
    pub call_id: String,
    pub room_id: String,
    pub state: String,
    pub media_type: String,
    pub created_by_profile_id: String,
    pub created_by_device_id: String,
    pub state_version: i64,
    pub started_at_ms: i64,
    pub updated_at_ms: i64,
    pub ended_at_ms: Option<i64>,
    pub expires_at_ms: i64,
}

#[derive(Debug, Clone)]
pub struct RoomCallParticipantRow {
    pub call_id: String,
    pub room_id: String,
    pub profile_id: String,
    pub device_id: String,
    pub join_state: String,
    pub supports_video: bool,
    pub supports_screen_share: bool,
    pub muted: bool,
    pub deafened: bool,
    pub video_enabled: bool,
    pub screen_share_enabled: bool,
    pub speaking: bool,
    pub joined_at_ms: i64,
    pub left_at_ms: Option<i64>,
    pub updated_at_ms: i64,
}

#[derive(Debug, Clone)]
pub struct RoomCallMediaParticipantRow {
    pub call_id: String,
    pub room_id: String,
    pub profile_id: String,
    pub device_id: String,
    pub publish_audio: bool,
    pub publish_video: bool,
    pub publish_screen_share: bool,
    pub subscribe_all: bool,
    pub created_at_ms: i64,
    pub updated_at_ms: i64,
}

#[derive(Debug, Clone)]
pub struct RoomCallSnapshot {
    pub room: RoomRow,
    pub call: RoomCallRow,
    pub participants: Vec<RoomCallParticipantRow>,
    pub self_participant: Option<RoomCallParticipantRow>,
    pub media_participants: Vec<RoomCallMediaParticipantRow>,
}

#[derive(Debug, Clone)]
pub struct RoomCallMutationResult {
    pub changed: bool,
    pub snapshot: RoomCallSnapshot,
}

#[derive(Debug, Clone)]
pub struct RoomCallMediaHealthSummary {
    pub active_room_call_count: i64,
    pub joined_room_call_participant_count: i64,
    pub registered_room_media_participant_count: i64,
    pub fully_registered_room_call_count: i64,
}

#[derive(Debug, Clone)]
pub struct RoomMessageAdmissionResult {
    pub room: RoomRow,
    pub message_id: String,
    pub kind: String,
    pub admitted_at_ms: i64,
    pub next_allowed_at_ms: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct CreateRoomResult {
    pub created: bool,
    pub room: RoomRow,
}

#[derive(Debug, Clone)]
pub struct UpsertRoomMembershipResult {
    pub changed: bool,
    pub room: RoomRow,
    pub membership: RoomMembershipRow,
}

#[derive(Debug, Clone)]
pub struct TransferRoomOwnershipResult {
    pub room: RoomRow,
    pub previous_owner_membership: RoomMembershipRow,
    pub next_owner_membership: RoomMembershipRow,
}

#[derive(Debug, Clone)]
pub struct DeleteRoomResult {
    pub room: RoomRow,
    pub deleted_profile_ids: Vec<String>,
}

#[derive(Debug, Clone, Default)]
pub struct DeleteProfileDataResult {
    pub deleted_rows: i64,
    pub deleted_blob_paths: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct CreateRoomInviteLinkResult {
    pub room: RoomRow,
    pub invite_link: RoomInviteLinkRow,
}

#[derive(Debug, Clone)]
pub struct SetRoomInviteLinkRevokedResult {
    pub changed: bool,
    pub room: RoomRow,
    pub invite_link: RoomInviteLinkRow,
}

#[derive(Debug, Clone)]
pub struct RedeemRoomInviteResult {
    pub changed: bool,
    pub room: RoomRow,
    pub invite_link: RoomInviteLinkRow,
    pub membership: RoomMembershipRow,
}

#[derive(Debug, Clone)]
pub struct UpdateRoomStateResult {
    pub changed: bool,
    pub room: RoomRow,
}

#[derive(Debug, Clone)]
pub enum CreateRoomError {
    Conflict(RoomRow),
    Storage(String),
}

#[derive(Debug, Clone)]
pub enum UpsertRoomMembershipError {
    RoomNotFound,
    InvalidOwnerMutation,
    Storage(String),
}

#[derive(Debug, Clone)]
pub enum TransferRoomOwnershipError {
    RoomNotFound,
    OwnerMismatch,
    InvalidNextOwner,
    NextOwnerNotActive,
    Storage(String),
}

#[derive(Debug, Clone)]
pub enum DeleteRoomError {
    RoomNotFound,
    OwnerMismatch,
    Storage(String),
}

#[derive(Debug, Clone)]
pub enum CreateRoomInviteLinkError {
    RoomNotFound,
    Storage(String),
}

#[derive(Debug, Clone)]
pub enum SetRoomInviteLinkRevokedError {
    RoomNotFound,
    InviteNotFound,
    Storage(String),
}

#[derive(Debug, Clone)]
pub enum RedeemRoomInviteError {
    InviteNotFound,
    RoomNotFound,
    InviteRevoked,
    InviteExpired,
    InviteUsageLimitReached,
    Banned,
    Storage(String),
}

#[derive(Debug, Clone)]
pub enum UpdateRoomStateError {
    RoomNotFound,
    Storage(String),
}

#[derive(Debug, Clone)]
pub enum SetRoomPinnedMessageError {
    RoomNotFound,
    MessageNotFound,
    Storage(String),
}

#[derive(Debug, Clone)]
pub enum SetRoomMemberTagError {
    RoomNotFound,
    MembershipNotActive,
    Storage(String),
}

#[derive(Debug, Clone)]
pub enum LeaveRoomError {
    RoomNotFound,
    MembershipNotActive,
    OwnerTransferRequired,
    Storage(String),
}

#[derive(Debug, Clone)]
pub enum UnbanRoomMembershipError {
    RoomNotFound,
    MembershipNotBanned,
    Storage(String),
}

#[derive(Debug, Clone)]
pub enum AdmitRoomMessageError {
    RoomNotFound,
    NotActiveMember,
    TextDisabled,
    MediaDisabled,
    SlowModeActive {
        retry_after_seconds: i64,
        next_allowed_at_ms: i64,
    },
    Storage(String),
}

#[derive(Debug, Clone)]
pub enum RoomCallControlError {
    RoomNotFound,
    CallNotFound,
    CallNotActive,
    NotActiveMember,
    ParticipantNotJoined,
    Storage(String),
}

const ROOM_SELECT_BY_ID_SQL: &str = "SELECT room_id, version, membership_version, owner_profile_id, created_by_device_id, title, description, avatar_hash, avatar_image_b64, reactions_mode, allow_text, allow_media, allow_add_members, allow_pin_messages, allow_change_group_info, allow_change_tag, join_approval_required, slow_mode_seconds, chat_history_visible, pinned_message_id, created_at_ms, updated_at_ms FROM rooms WHERE room_id = ?1";

fn map_room_row(row: &rusqlite::Row<'_>) -> Result<RoomRow, rusqlite::Error> {
    Ok(RoomRow {
        room_id: row.get(0)?,
        version: row.get(1)?,
        membership_version: row.get(2)?,
        owner_profile_id: row.get(3)?,
        created_by_device_id: row.get(4)?,
        title: row.get(5)?,
        description: row.get(6)?,
        avatar_hash: row.get(7)?,
        avatar_image_b64: row.get(8)?,
        reactions_mode: row.get(9)?,
        allow_text: row.get::<_, i64>(10)? != 0,
        allow_media: row.get::<_, i64>(11)? != 0,
        allow_add_members: row.get::<_, i64>(12)? != 0,
        allow_pin_messages: row.get::<_, i64>(13)? != 0,
        allow_change_group_info: row.get::<_, i64>(14)? != 0,
        allow_change_tag: row.get::<_, i64>(15)? != 0,
        join_approval_required: row.get::<_, i64>(16)? != 0,
        slow_mode_seconds: row.get(17)?,
        chat_history_visible: row.get::<_, i64>(18)? != 0,
        pinned_message_id: row.get(19)?,
        created_at_ms: row.get(20)?,
        updated_at_ms: row.get(21)?,
    })
}

fn map_room_membership_row(row: &rusqlite::Row<'_>) -> Result<RoomMembershipRow, rusqlite::Error> {
    Ok(RoomMembershipRow {
        room_id: row.get(0)?,
        profile_id: row.get(1)?,
        status: row.get(2)?,
        role: row.get(3)?,
        source_link_id: row.get(4)?,
        tag: row.get(5)?,
        created_at_ms: row.get(6)?,
        updated_at_ms: row.get(7)?,
    })
}

fn map_room_invite_link_row(row: &rusqlite::Row<'_>) -> Result<RoomInviteLinkRow, rusqlite::Error> {
    Ok(RoomInviteLinkRow {
        link_id: row.get(0)?,
        room_id: row.get(1)?,
        slug: row.get(2)?,
        created_by_profile_id: row.get(3)?,
        expires_at_ms: row.get(4)?,
        max_uses: row.get(5)?,
        use_count: row.get(6)?,
        requires_approval: row.get::<_, i64>(7)? != 0,
        allowed_role: row.get(8)?,
        revoked: row.get::<_, i64>(9)? != 0,
        created_at_ms: row.get(10)?,
        updated_at_ms: row.get(11)?,
    })
}

fn map_room_call_row(row: &rusqlite::Row<'_>) -> Result<RoomCallRow, rusqlite::Error> {
    Ok(RoomCallRow {
        call_id: row.get(0)?,
        room_id: row.get(1)?,
        state: row.get(2)?,
        media_type: row.get(3)?,
        created_by_profile_id: row.get(4)?,
        created_by_device_id: row.get(5)?,
        state_version: row.get(6)?,
        started_at_ms: row.get(7)?,
        updated_at_ms: row.get(8)?,
        ended_at_ms: row.get(9)?,
        expires_at_ms: row.get(10)?,
    })
}

fn map_room_call_participant_row(
    row: &rusqlite::Row<'_>,
) -> Result<RoomCallParticipantRow, rusqlite::Error> {
    Ok(RoomCallParticipantRow {
        call_id: row.get(0)?,
        room_id: row.get(1)?,
        profile_id: row.get(2)?,
        device_id: row.get(3)?,
        join_state: row.get(4)?,
        supports_video: row.get::<_, i64>(5)? != 0,
        supports_screen_share: row.get::<_, i64>(6)? != 0,
        muted: row.get::<_, i64>(7)? != 0,
        deafened: row.get::<_, i64>(8)? != 0,
        video_enabled: row.get::<_, i64>(9)? != 0,
        screen_share_enabled: row.get::<_, i64>(10)? != 0,
        speaking: row.get::<_, i64>(11)? != 0,
        joined_at_ms: row.get(12)?,
        left_at_ms: row.get(13)?,
        updated_at_ms: row.get(14)?,
    })
}

fn map_room_call_media_participant_row(
    row: &rusqlite::Row<'_>,
) -> Result<RoomCallMediaParticipantRow, rusqlite::Error> {
    Ok(RoomCallMediaParticipantRow {
        call_id: row.get(0)?,
        room_id: row.get(1)?,
        profile_id: row.get(2)?,
        device_id: row.get(3)?,
        publish_audio: row.get::<_, i64>(4)? != 0,
        publish_video: row.get::<_, i64>(5)? != 0,
        publish_screen_share: row.get::<_, i64>(6)? != 0,
        subscribe_all: row.get::<_, i64>(7)? != 0,
        created_at_ms: row.get(8)?,
        updated_at_ms: row.get(9)?,
    })
}

fn room_call_participant_is_joined(join_state: &str) -> bool {
    matches!(
        join_state.trim().to_ascii_lowercase().as_str(),
        "joined" | "reconnecting"
    )
}

fn normalize_room_call_participant_speaking(
    join_state: &str,
    muted: bool,
    deafened: bool,
    speaking: bool,
) -> bool {
    speaking && join_state.trim().eq_ignore_ascii_case("joined") && !muted && !deafened
}

fn normalize_room_call_media_type(value: &str) -> &'static str {
    match value.trim().to_ascii_lowercase().as_str() {
        "video" => "video",
        _ => "audio",
    }
}

fn load_room_call_participants(
    tx: &rusqlite::Transaction<'_>,
    call_id: &str,
) -> Result<Vec<RoomCallParticipantRow>, rusqlite::Error> {
    let mut stmt = tx.prepare(ROOM_CALL_PARTICIPANTS_SELECT_BY_CALL_SQL)?;
    let mut rows = stmt.query(params![call_id])?;
    let mut participants = Vec::new();
    while let Some(row) = rows.next()? {
        participants.push(map_room_call_participant_row(row)?);
    }
    Ok(participants)
}

fn load_room_call_media_participants(
    tx: &rusqlite::Transaction<'_>,
    call_id: &str,
) -> Result<Vec<RoomCallMediaParticipantRow>, rusqlite::Error> {
    let mut stmt = tx.prepare(ROOM_CALL_MEDIA_PARTICIPANTS_SELECT_BY_CALL_SQL)?;
    let mut rows = stmt.query(params![call_id])?;
    let mut participants = Vec::new();
    while let Some(row) = rows.next()? {
        participants.push(map_room_call_media_participant_row(row)?);
    }
    Ok(participants)
}

fn load_room_call_snapshot(
    tx: &rusqlite::Transaction<'_>,
    room_id: &str,
    call: RoomCallRow,
    self_device_id: Option<&str>,
) -> Result<RoomCallSnapshot, rusqlite::Error> {
    let room = tx.query_row(ROOM_SELECT_BY_ID_SQL, params![room_id], map_room_row)?;
    let participants = load_room_call_participants(tx, &call.call_id)?;
    let media_participants = load_room_call_media_participants(tx, &call.call_id)?;
    let self_participant = self_device_id.and_then(|device_id| {
        participants
            .iter()
            .find(|participant| participant.device_id == device_id)
            .cloned()
    });
    Ok(RoomCallSnapshot {
        room,
        call,
        participants,
        self_participant,
        media_participants,
    })
}

fn next_membership_created_at(
    existing: Option<&RoomMembershipRow>,
    next_status: &str,
    now_ms: i64,
) -> i64 {
    match existing {
        None => now_ms,
        Some(existing_membership) => {
            if existing_membership.status == next_status {
                existing_membership.created_at_ms
            } else if next_status == "active" || next_status == "pending" {
                now_ms
            } else {
                existing_membership.created_at_ms
            }
        }
    }
}

fn normalize_invite_allowed_role(role: &str) -> &'static str {
    match role.trim().to_ascii_lowercase().as_str() {
        "owner" | "admin" | "moderator" => "member",
        "restricted" => "restricted",
        "guest" | "read_only" | "readonly" | "read-only" => "guest",
        _ => "member",
    }
}

fn normalize_room_reactions_mode(value: &str) -> &'static str {
    match value.trim().to_ascii_lowercase().as_str() {
        "selected" => "selected",
        "none" => "none",
        _ => "all",
    }
}

#[derive(Clone)]
pub struct RelayStore {
    conn: Connection,
    call_session_terminal_ttl_seconds: u32,
    room_call_active_ttl_seconds: u32,
}

impl RelayStore {
    pub async fn open(path: impl AsRef<Path>) -> Result<Self, String> {
        let conn = Connection::open(path).await.map_err(|e| e.to_string())?;
        let store = Self {
            conn,
            call_session_terminal_ttl_seconds: call_session_terminal_ttl_seconds_from_env(),
            room_call_active_ttl_seconds: room_call_active_ttl_seconds_from_env(),
        };
        store.init().await?;
        Ok(store)
    }

    async fn init(&self) -> Result<(), String> {
        // 🔴 РЕЖИМ ЖУРНАЛА — ДО СОЗДАНИЯ ТАБЛИЦ (02.09.2026, аудит задержки
        // доставки).
        //
        // База открывалась с настройками по умолчанию: журнал отката и
        // `synchronous=FULL`, то есть fsync на КАЖДОМ коммите. Кадр доставки
        // уходит получателю только после этого коммита, и на обычном диске это
        // от одной до двадцати миллисекунд на конверт — при всплеске
        // единственная точка, где сериализуется вся доставка (соединение одно
        // на весь процесс).
        //
        // Проверено на боевом сервере перед правкой: `/var/lib/secretly` лежит
        // на ext4 на локальном /dev/sda1, не на сетевой ФС, — WAL там работает
        // штатно, а на NFS его включать нельзя. Резервное копирование
        // использует `sqlite3 .backup`, который читает согласованный снимок
        // вместе с содержимым `-wal`, поэтому копии не ломаются. Релей работает
        // под своим пользователем и владеет каталогом, значит `-wal` и `-shm`
        // ему создать есть чем; сервисные скрипты читают базу из-под root.
        //
        // `synchronous=NORMAL` — осознанный размен: при внезапном отключении
        // питания могут потеряться последние коммиты. Для почтового ящика с
        // TTL это приемлемо, потому что потерянный конверт восстанавливает
        // страховка отправителя: проверка ожидающих трактует отказ как «держу»
        // и отправляет заново. Целостность базы при этом не страдает — WAL
        // сохраняет атомарность транзакций и при NORMAL.
        //
        // `busy_timeout` нужен из-за читателей со стороны: скрипты выкладки и
        // проверки открывают базу параллельно, и без ожидания они получали бы
        // мгновенный отказ «database is locked».
        self.conn
            .call(|c| -> Result<(), rusqlite::Error> {
                // journal_mode возвращает строку с новым режимом, поэтому это
                // запрос, а не execute — иначе rusqlite вернёт ошибку
                // «Execute returned results».
                let mode: String =
                    c.query_row("PRAGMA journal_mode=WAL", [], |row| row.get(0))?;
                if !mode.eq_ignore_ascii_case("wal") {
                    // Не удалось — работаем как раньше. Отказ включить WAL не
                    // повод не запускать сервер.
                    tracing::warn!(journal_mode = %mode, "relay db: WAL not enabled");
                }
                c.execute_batch(
                    "PRAGMA synchronous=NORMAL; PRAGMA busy_timeout=5000;",
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;

        self.conn
            .call(|c| -> Result<(), rusqlite::Error> {
                c.execute_batch(
                    r#"
CREATE TABLE IF NOT EXISTS device_state (
  device_id TEXT PRIMARY KEY,
  next_seq INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS blocks (
    profile_id TEXT NOT NULL,
    blocked_profile_id TEXT NOT NULL,
    created_at_ms INTEGER NOT NULL,
    PRIMARY KEY(profile_id, blocked_profile_id)
);

CREATE INDEX IF NOT EXISTS blocks_profile_idx ON blocks(profile_id);

CREATE TABLE IF NOT EXISTS pending (
  device_id TEXT NOT NULL,
  seq INTEGER NOT NULL,
  msg_id TEXT NOT NULL,
  ciphertext_b64 TEXT NOT NULL,
    transport_meta_json TEXT,
  expires_at_ms INTEGER NOT NULL,
  last_attempt_ms INTEGER NOT NULL DEFAULT 0,
  -- SERVER-SIDE SCHEDULED DELIVERY (2026-07-17): 0 = deliver immediately
  -- (every legacy row + normal message). > 0 = hold the ciphertext and make
  -- it deliverable only once now >= deliver_at_ms. This is how "send later"
  -- survives the SENDER sleeping: the encrypted row is uploaded at schedule
  -- time and the relay releases it at T, instead of a Doze-frozen client timer.
  deliver_at_ms INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY(device_id, seq),
  UNIQUE(device_id, msg_id)
);

CREATE INDEX IF NOT EXISTS pending_device_seq_idx ON pending(device_id, seq);
CREATE INDEX IF NOT EXISTS pending_expires_idx ON pending(expires_at_ms);
-- NB: the `deliver_at_ms` index (pending_deliver_at_idx) is created in the
-- migration block AFTER the column is guaranteed to exist — a base-schema
-- CREATE INDEX would reference a missing column and panic when an existing DB
-- (column added by ALTER) runs this base schema. Same pattern as
-- pending_device_attempt_idx.

CREATE TABLE IF NOT EXISTS message_dedup (
    device_id TEXT NOT NULL,
    msg_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    created_at_ms INTEGER NOT NULL,
    expires_at_ms INTEGER NOT NULL,
    PRIMARY KEY(device_id, msg_id)
);

CREATE INDEX IF NOT EXISTS message_dedup_expires_idx ON message_dedup(expires_at_ms);

CREATE TABLE IF NOT EXISTS call_sessions (
    call_id TEXT NOT NULL,
    call_attempt_id TEXT NOT NULL,
    participant_device_id TEXT NOT NULL,
    peer_device_id TEXT NOT NULL,
    direction TEXT NOT NULL,
    state TEXT NOT NULL,
    last_action TEXT NOT NULL,
    last_signal_id TEXT NOT NULL,
    last_created_at_ms INTEGER NOT NULL,
    last_received_at_ms INTEGER NOT NULL,
    invited_at_ms INTEGER,
    accepted_at_ms INTEGER,
    offer_seen_at_ms INTEGER,
    answer_seen_at_ms INTEGER,
    reconnecting_at_ms INTEGER,
    ended_at_ms INTEGER,
    expires_at_ms INTEGER NOT NULL,
    PRIMARY KEY(call_id, call_attempt_id, participant_device_id)
);

CREATE INDEX IF NOT EXISTS call_sessions_participant_idx ON call_sessions(participant_device_id, call_id, call_attempt_id);
CREATE INDEX IF NOT EXISTS call_sessions_expires_idx ON call_sessions(expires_at_ms);

CREATE TABLE IF NOT EXISTS call_signal_dedup (
    call_id TEXT NOT NULL,
    call_attempt_id TEXT NOT NULL,
    signal_id TEXT NOT NULL,
    created_at_ms INTEGER NOT NULL,
    PRIMARY KEY(call_id, call_attempt_id, signal_id)
);

CREATE INDEX IF NOT EXISTS call_signal_dedup_created_idx ON call_signal_dedup(created_at_ms);
CREATE INDEX IF NOT EXISTS call_signal_dedup_call_signal_idx ON call_signal_dedup(call_id, signal_id);

CREATE TABLE IF NOT EXISTS push_tokens (
    device_id TEXT NOT NULL,
    token TEXT NOT NULL,
    platform TEXT NOT NULL,
    policy_json TEXT,
    updated_at_ms INTEGER NOT NULL,
    PRIMARY KEY(device_id, platform)
);

CREATE INDEX IF NOT EXISTS push_tokens_updated_idx ON push_tokens(updated_at_ms);

-- Sprint 2 R3/R7: per-device liveness tracking. Updated transactionally
-- from the existing pump / push paths. Used by the staleness filter on
-- `GET /v1/active_devices/{profile_id}` and (eventually) the R4
-- cleanup loop. See docs/MESSAGE_DELIVERY_AUDIT_2026-05-28.md §10.1
-- and docs/RESTORE_SAFETY_CONTRACT_2026-05-28.md INV-1..5.
--
-- `profile_id` is populated lazily on the first WS welcome / HTTP
-- welcome for the device; the field is denormalised here so the
-- per-profile filter query stays single-table and cheap. Empty
-- string means «profile not yet resolved» — such rows are excluded
-- from `list_active_devices_for_profile`.
CREATE TABLE IF NOT EXISTS device_activity (
    device_id TEXT PRIMARY KEY,
    profile_id TEXT NOT NULL DEFAULT '',
    last_pump_at_ms INTEGER NOT NULL DEFAULT 0,
    last_push_attempted_at_ms INTEGER NOT NULL DEFAULT 0,
    last_push_delivered_at_ms INTEGER NOT NULL DEFAULT 0,
    updated_at_ms INTEGER NOT NULL,
    -- >0 when this device_id was superseded by a newer device on the SAME
    -- physical phone (proven by a push-token takeover, see upsert_push_token).
    -- Such a device can never receive again; `GET /v1/active_devices` excludes
    -- it from senders' fanout unconditionally (independent of the 30-day
    -- staleness filter flag) so peers stop encrypting into its dead mailbox.
    superseded_at_ms INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS device_activity_profile_idx ON device_activity(profile_id);
CREATE INDEX IF NOT EXISTS device_activity_pump_idx ON device_activity(last_pump_at_ms);

CREATE TABLE IF NOT EXISTS push_wake_dedup (
    device_id TEXT NOT NULL,
    msg_id TEXT NOT NULL,
    created_at_ms INTEGER NOT NULL,
    PRIMARY KEY(device_id, msg_id)
);

CREATE INDEX IF NOT EXISTS push_wake_dedup_created_idx ON push_wake_dedup(created_at_ms);

CREATE TABLE IF NOT EXISTS blobs (
    blob_id TEXT PRIMARY KEY,
    rel_path TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    expires_at_ms INTEGER NOT NULL,
    created_at_ms INTEGER NOT NULL,
    owner_device_id TEXT NOT NULL DEFAULT '',
    owner_profile_id TEXT NOT NULL DEFAULT '',
    access_token_sha256_b64 TEXT NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS blobs_expires_idx ON blobs(expires_at_ms);

CREATE TABLE IF NOT EXISTS rooms (
    room_id TEXT PRIMARY KEY,
    version INTEGER NOT NULL,
    membership_version INTEGER NOT NULL DEFAULT 1,
    owner_profile_id TEXT NOT NULL,
    created_by_device_id TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    avatar_hash TEXT,
    avatar_image_b64 TEXT,
    reactions_mode TEXT NOT NULL DEFAULT 'all',
    allow_text INTEGER NOT NULL DEFAULT 1,
    allow_media INTEGER NOT NULL DEFAULT 1,
    allow_add_members INTEGER NOT NULL DEFAULT 1,
    allow_pin_messages INTEGER NOT NULL DEFAULT 1,
    allow_change_group_info INTEGER NOT NULL DEFAULT 1,
    allow_change_tag INTEGER NOT NULL DEFAULT 0,
    join_approval_required INTEGER NOT NULL DEFAULT 0,
    slow_mode_seconds INTEGER NOT NULL DEFAULT 0,
    chat_history_visible INTEGER NOT NULL DEFAULT 0,
    pinned_message_id TEXT,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS rooms_owner_updated_idx ON rooms(owner_profile_id, updated_at_ms DESC);

CREATE TABLE IF NOT EXISTS room_memberships (
    room_id TEXT NOT NULL,
    profile_id TEXT NOT NULL,
    status TEXT NOT NULL,
    role TEXT NOT NULL,
    source_link_id TEXT,
    tag TEXT,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL,
    PRIMARY KEY(room_id, profile_id)
);

CREATE INDEX IF NOT EXISTS room_memberships_room_status_idx ON room_memberships(room_id, status, created_at_ms ASC);
CREATE INDEX IF NOT EXISTS room_memberships_profile_idx ON room_memberships(profile_id, updated_at_ms DESC);

CREATE TABLE IF NOT EXISTS room_invite_links (
    link_id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    slug TEXT NOT NULL,
    created_by_profile_id TEXT NOT NULL,
    expires_at_ms INTEGER,
    max_uses INTEGER,
    use_count INTEGER NOT NULL DEFAULT 0,
    requires_approval INTEGER NOT NULL DEFAULT 0,
    allowed_role TEXT NOT NULL DEFAULT 'member',
    is_revoked INTEGER NOT NULL DEFAULT 0,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS room_invite_links_room_idx ON room_invite_links(room_id, updated_at_ms DESC);
CREATE UNIQUE INDEX IF NOT EXISTS room_invite_links_slug_idx ON room_invite_links(slug);

CREATE TABLE IF NOT EXISTS room_posting_state (
    room_id TEXT NOT NULL,
    profile_id TEXT NOT NULL,
    last_client_message_id TEXT NOT NULL DEFAULT '',
    last_message_kind TEXT NOT NULL DEFAULT 'text',
    last_admitted_at_ms INTEGER,
    next_allowed_at_ms INTEGER,
    updated_at_ms INTEGER NOT NULL,
    PRIMARY KEY(room_id, profile_id)
);

CREATE INDEX IF NOT EXISTS room_posting_state_room_next_idx ON room_posting_state(room_id, next_allowed_at_ms DESC);
CREATE INDEX IF NOT EXISTS room_posting_state_profile_updated_idx ON room_posting_state(profile_id, updated_at_ms DESC);

CREATE TABLE IF NOT EXISTS room_message_index (
    room_id TEXT NOT NULL,
    message_id TEXT NOT NULL,
    admitted_by_profile_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    admitted_at_ms INTEGER NOT NULL,
    PRIMARY KEY(room_id, message_id)
);

CREATE INDEX IF NOT EXISTS room_message_index_room_admitted_idx ON room_message_index(room_id, admitted_at_ms DESC);

CREATE TABLE IF NOT EXISTS room_call_sessions (
    call_id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    state TEXT NOT NULL,
    media_type TEXT NOT NULL,
    created_by_profile_id TEXT NOT NULL,
    created_by_device_id TEXT NOT NULL,
    state_version INTEGER NOT NULL,
    started_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL,
    ended_at_ms INTEGER,
    expires_at_ms INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS room_call_sessions_room_active_idx ON room_call_sessions(room_id, state, started_at_ms DESC);
CREATE INDEX IF NOT EXISTS room_call_sessions_expires_idx ON room_call_sessions(expires_at_ms);

CREATE TABLE IF NOT EXISTS room_call_participants (
    call_id TEXT NOT NULL,
    room_id TEXT NOT NULL,
    profile_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    join_state TEXT NOT NULL,
    supports_video INTEGER NOT NULL DEFAULT 0,
    supports_screen_share INTEGER NOT NULL DEFAULT 0,
    muted INTEGER NOT NULL DEFAULT 0,
    deafened INTEGER NOT NULL DEFAULT 0,
    video_enabled INTEGER NOT NULL DEFAULT 0,
    screen_share_enabled INTEGER NOT NULL DEFAULT 0,
    speaking INTEGER NOT NULL DEFAULT 0,
    joined_at_ms INTEGER NOT NULL,
    left_at_ms INTEGER,
    updated_at_ms INTEGER NOT NULL,
    PRIMARY KEY(call_id, device_id)
);

CREATE INDEX IF NOT EXISTS room_call_participants_call_state_idx ON room_call_participants(call_id, join_state, joined_at_ms ASC);
CREATE INDEX IF NOT EXISTS room_call_participants_room_profile_idx ON room_call_participants(room_id, profile_id, updated_at_ms DESC);

CREATE TABLE IF NOT EXISTS room_call_media_participants (
    call_id TEXT NOT NULL,
    room_id TEXT NOT NULL,
    profile_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    publish_audio INTEGER NOT NULL DEFAULT 1,
    publish_video INTEGER NOT NULL DEFAULT 0,
    publish_screen_share INTEGER NOT NULL DEFAULT 0,
    subscribe_all INTEGER NOT NULL DEFAULT 1,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL,
    PRIMARY KEY(call_id, device_id)
);

CREATE INDEX IF NOT EXISTS room_call_media_participants_call_updated_idx ON room_call_media_participants(call_id, updated_at_ms DESC);
CREATE INDEX IF NOT EXISTS room_call_media_participants_room_profile_idx ON room_call_media_participants(room_id, profile_id, updated_at_ms DESC);

-- SUPPORT TICKETS. E2EE: the relay
-- stores ONLY ciphertext (sealed to the support public key, whose private key
-- lives only in the admin console) + the user's reply pubkey + anonymous
-- profile_id. Never any plaintext, email, or the support private key.
CREATE TABLE IF NOT EXISTS support_tickets (
    ticket_id TEXT PRIMARY KEY,
    profile_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    reply_pubkey_b64 TEXT NOT NULL,
    ciphertext_b64 TEXT NOT NULL,
    client_meta_json TEXT,
    created_at_ms INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'open'
);
CREATE INDEX IF NOT EXISTS support_tickets_profile_idx ON support_tickets(profile_id, created_at_ms DESC);
CREATE INDEX IF NOT EXISTS support_tickets_created_idx ON support_tickets(created_at_ms DESC);

CREATE TABLE IF NOT EXISTS support_replies (
    reply_id TEXT PRIMARY KEY,
    ticket_id TEXT NOT NULL,
    profile_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    ciphertext_b64 TEXT NOT NULL,
    created_at_ms INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS support_replies_poll_idx ON support_replies(profile_id, seq);

-- Отметка «переписка с поддержкой стёрта».
--
-- Нужна потому, что удаления НЕ ВИДНО на опросе: приложение спрашивает ответы
-- новее своего курсора, и пустой ответ после очистки неотличим от обычного
-- «нового ничего нет». Без этой отметки телефон так и держал бы стёртую ленту
-- и красный кружок.
CREATE TABLE IF NOT EXISTS support_cleared (
    profile_id TEXT PRIMARY KEY,
    cleared_at_ms INTEGER NOT NULL
);
"#,
                )?;

                let mut has_owner_device_id = false;
                let mut has_owner_profile_id = false;
                let mut has_access_token_sha256_b64 = false;
                let mut has_pending_transport_meta_json = false;
                let mut has_pending_last_attempt_ms = false;
                let mut has_pending_deliver_at_ms = false;
                let mut has_pending_from_device_id = false;
                let mut has_push_token_policy_json = false;
                let mut push_token_platform_is_pk = false;
                let mut has_room_membership_version = false;
                let mut has_room_description = false;
                let mut has_room_avatar_hash = false;
                let mut has_room_avatar_image_b64 = false;
                let mut has_room_reactions_mode = false;
                let mut has_room_allow_text = false;
                let mut has_room_allow_media = false;
                let mut has_room_allow_add_members = false;
                let mut has_room_allow_pin_messages = false;
                let mut has_room_allow_change_group_info = false;
                let mut has_room_allow_change_tag = false;
                let mut has_room_join_approval_required = false;
                let mut has_room_slow_mode_seconds = false;
                let mut has_room_chat_history_visible = false;
                let mut has_room_pinned_message_id = false;
                let mut has_room_membership_tag = false;
                let mut has_device_activity_superseded = false;
                let mut has_device_activity_client_build = false;
                {
                    let mut stmt = c.prepare("PRAGMA table_info(blobs)")?;
                    let mut rows = stmt.query([])?;
                    while let Some(row) = rows.next()? {
                        let col_name: String = row.get(1)?;
                        if col_name == "owner_device_id" {
                            has_owner_device_id = true;
                        }
                        if col_name == "owner_profile_id" {
                            has_owner_profile_id = true;
                        }
                        if col_name == "access_token_sha256_b64" {
                            has_access_token_sha256_b64 = true;
                        }
                    }
                }

                {
                    let mut stmt = c.prepare("PRAGMA table_info(push_tokens)")?;
                    let mut rows = stmt.query([])?;
                    while let Some(row) = rows.next()? {
                        let col_name: String = row.get(1)?;
                        let pk_position: i64 = row.get(5)?;
                        if col_name == "policy_json" {
                            has_push_token_policy_json = true;
                        }
                        if col_name == "platform" && pk_position > 0 {
                            push_token_platform_is_pk = true;
                        }
                    }
                }

                {
                    let mut stmt = c.prepare("PRAGMA table_info(rooms)")?;
                    let mut rows = stmt.query([])?;
                    while let Some(row) = rows.next()? {
                        let col_name: String = row.get(1)?;
                        if col_name == "membership_version" {
                            has_room_membership_version = true;
                        }
                        if col_name == "description" {
                            has_room_description = true;
                        }
                        if col_name == "avatar_hash" {
                            has_room_avatar_hash = true;
                        }
                        if col_name == "avatar_image_b64" {
                            has_room_avatar_image_b64 = true;
                        }
                        if col_name == "reactions_mode" {
                            has_room_reactions_mode = true;
                        }
                        if col_name == "allow_text" {
                            has_room_allow_text = true;
                        }
                        if col_name == "allow_media" {
                            has_room_allow_media = true;
                        }
                        if col_name == "allow_add_members" {
                            has_room_allow_add_members = true;
                        }
                        if col_name == "allow_pin_messages" {
                            has_room_allow_pin_messages = true;
                        }
                        if col_name == "allow_change_group_info" {
                            has_room_allow_change_group_info = true;
                        }
                        if col_name == "allow_change_tag" {
                            has_room_allow_change_tag = true;
                        }
                        if col_name == "join_approval_required" {
                            has_room_join_approval_required = true;
                        }
                        if col_name == "slow_mode_seconds" {
                            has_room_slow_mode_seconds = true;
                        }
                        if col_name == "chat_history_visible" {
                            has_room_chat_history_visible = true;
                        }
                        if col_name == "pinned_message_id" {
                            has_room_pinned_message_id = true;
                        }
                    }
                }

                {
                    let mut stmt = c.prepare("PRAGMA table_info(room_memberships)")?;
                    let mut rows = stmt.query([])?;
                    while let Some(row) = rows.next()? {
                        let col_name: String = row.get(1)?;
                        if col_name == "tag" {
                            has_room_membership_tag = true;
                        }
                    }
                }

                {
                    let mut stmt = c.prepare("PRAGMA table_info(pending)")?;
                    let mut rows = stmt.query([])?;
                    while let Some(row) = rows.next()? {
                        let col_name: String = row.get(1)?;
                        if col_name == "transport_meta_json" {
                            has_pending_transport_meta_json = true;
                        }
                        if col_name == "last_attempt_ms" {
                            has_pending_last_attempt_ms = true;
                        }
                        if col_name == "deliver_at_ms" {
                            has_pending_deliver_at_ms = true;
                        }
                        if col_name == "from_device_id" {
                            has_pending_from_device_id = true;
                        }
                    }
                }

                {
                    let mut stmt = c.prepare("PRAGMA table_info(device_activity)")?;
                    let mut rows = stmt.query([])?;
                    while let Some(row) = rows.next()? {
                        let col_name: String = row.get(1)?;
                        if col_name == "superseded_at_ms" {
                            has_device_activity_superseded = true;
                        }
                        if col_name == "client_build" {
                            has_device_activity_client_build = true;
                        }
                    }
                }

                if !has_owner_device_id {
                    c.execute(
                        "ALTER TABLE blobs ADD COLUMN owner_device_id TEXT NOT NULL DEFAULT ''",
                        [],
                    )?;
                }
                if !has_owner_profile_id {
                    c.execute(
                        "ALTER TABLE blobs ADD COLUMN owner_profile_id TEXT NOT NULL DEFAULT ''",
                        [],
                    )?;
                }
                if !has_access_token_sha256_b64 {
                    c.execute(
                        "ALTER TABLE blobs ADD COLUMN access_token_sha256_b64 TEXT NOT NULL DEFAULT ''",
                        [],
                    )?;
                }
                if !has_room_membership_version {
                    c.execute(
                        "ALTER TABLE rooms ADD COLUMN membership_version INTEGER NOT NULL DEFAULT 1",
                        [],
                    )?;
                }
                if !has_room_description {
                    c.execute("ALTER TABLE rooms ADD COLUMN description TEXT", [])?;
                }
                if !has_room_avatar_hash {
                    c.execute("ALTER TABLE rooms ADD COLUMN avatar_hash TEXT", [])?;
                }
                if !has_room_avatar_image_b64 {
                    c.execute("ALTER TABLE rooms ADD COLUMN avatar_image_b64 TEXT", [])?;
                }
                if !has_room_reactions_mode {
                    c.execute(
                        "ALTER TABLE rooms ADD COLUMN reactions_mode TEXT NOT NULL DEFAULT 'all'",
                        [],
                    )?;
                }
                if !has_room_allow_text {
                    c.execute(
                        "ALTER TABLE rooms ADD COLUMN allow_text INTEGER NOT NULL DEFAULT 1",
                        [],
                    )?;
                }
                if !has_room_allow_media {
                    c.execute(
                        "ALTER TABLE rooms ADD COLUMN allow_media INTEGER NOT NULL DEFAULT 1",
                        [],
                    )?;
                }
                if !has_room_allow_add_members {
                    c.execute(
                        "ALTER TABLE rooms ADD COLUMN allow_add_members INTEGER NOT NULL DEFAULT 1",
                        [],
                    )?;
                }
                if !has_room_allow_pin_messages {
                    c.execute(
                        "ALTER TABLE rooms ADD COLUMN allow_pin_messages INTEGER NOT NULL DEFAULT 1",
                        [],
                    )?;
                }
                if !has_room_allow_change_group_info {
                    c.execute(
                        "ALTER TABLE rooms ADD COLUMN allow_change_group_info INTEGER NOT NULL DEFAULT 1",
                        [],
                    )?;
                }
                if !has_room_allow_change_tag {
                    c.execute(
                        "ALTER TABLE rooms ADD COLUMN allow_change_tag INTEGER NOT NULL DEFAULT 0",
                        [],
                    )?;
                }
                if !has_room_join_approval_required {
                    c.execute(
                        "ALTER TABLE rooms ADD COLUMN join_approval_required INTEGER NOT NULL DEFAULT 0",
                        [],
                    )?;
                }
                if !has_room_slow_mode_seconds {
                    c.execute(
                        "ALTER TABLE rooms ADD COLUMN slow_mode_seconds INTEGER NOT NULL DEFAULT 0",
                        [],
                    )?;
                }
                if !has_room_chat_history_visible {
                    c.execute(
                        "ALTER TABLE rooms ADD COLUMN chat_history_visible INTEGER NOT NULL DEFAULT 0",
                        [],
                    )?;
                }
                if !has_room_pinned_message_id {
                    c.execute("ALTER TABLE rooms ADD COLUMN pinned_message_id TEXT", [])?;
                }
                if !has_room_membership_tag {
                    c.execute("ALTER TABLE room_memberships ADD COLUMN tag TEXT", [])?;
                }
                if !has_pending_transport_meta_json {
                    c.execute(
                        "ALTER TABLE pending ADD COLUMN transport_meta_json TEXT",
                        [],
                    )?;
                }
                if !has_pending_last_attempt_ms {
                    // RELIABLE-DELIVERY (2026-07-08): timestamp of the last
                    // delivery attempt for this row. The redeliver-until-ack
                    // sweep re-sends any unacked pending row whose last attempt
                    // is older than the backoff, so a message dropped by a
                    // connected client (lost in a reconnect-backfill flood,
                    // transiently undecryptable, etc.) is retried until the
                    // client acks it — not stranded above the delivery cursor.
                    c.execute(
                        "ALTER TABLE pending ADD COLUMN last_attempt_ms INTEGER NOT NULL DEFAULT 0",
                        [],
                    )?;
                }
                if !has_pending_from_device_id {
                    // ИД-1 / С-1 (17.09.2026): authenticated sender, handed to
                    // the recipient so it can reject a wire whose header names
                    // somebody else. NULL = unknown (legacy rows).
                    c.execute("ALTER TABLE pending ADD COLUMN from_device_id TEXT", [])?;
                }
                if !has_pending_deliver_at_ms {
                    // SERVER-SIDE SCHEDULED DELIVERY (2026-07-17): future-release
                    // gate. 0 (all existing rows) = deliver immediately, so the
                    // migration is behaviourally a no-op for live traffic.
                    c.execute(
                        "ALTER TABLE pending ADD COLUMN deliver_at_ms INTEGER NOT NULL DEFAULT 0",
                        [],
                    )?;
                }
                c.execute(
                    "CREATE INDEX IF NOT EXISTS pending_deliver_at_idx ON pending(deliver_at_ms)",
                    [],
                )?;
                // Index for the redeliver sweep's `last_attempt_ms` scan. Created
                // HERE (not in the base schema) so it runs only after the column
                // is guaranteed to exist — on an existing DB the column is added
                // by the ALTER above, so a base-schema CREATE INDEX would
                // reference a missing column and panic on startup. Idempotent for
                // fresh DBs (column present from CREATE TABLE).
                c.execute(
                    "CREATE INDEX IF NOT EXISTS pending_device_attempt_idx ON pending(device_id, last_attempt_ms)",
                    [],
                )?;
                if !has_device_activity_superseded {
                    // DEVICE-ROTATION FIX (2026-07-12): explicit supersession
                    // marker so the active-devices fanout filter can drop a
                    // rotated-away device_id unconditionally (see upsert_push_token
                    // and http_active_devices). Additive, DEFAULT 0 → existing
                    // rows are treated as not-superseded.
                    c.execute(
                        "ALTER TABLE device_activity ADD COLUMN superseded_at_ms INTEGER NOT NULL DEFAULT 0",
                        [],
                    )?;
                }
                if !has_device_activity_client_build {
                    // 🔴 ИЗМЕРЕНИЕ ВЕРСИЙ (03.08.2026). Раскатка Э-4 требует
                    // ответа на вопрос «какая доля активных устройств уже умеет
                    // ПРИНИМАТЬ повтор рукопожатия». Ответить было нечем:
                    // client_protocol_version у всех единица, номера сборки
                    // сервер не видел вовсе, и любое включение отправки было бы
                    // ставкой вслепую.
                    //
                    // Столбец справочный: он НИКОГДА не участвует в решениях о
                    // доставке или авторизации, только в подсчёте. Заголовок,
                    // из которого он берётся, не подписан — доверять ему в
                    // чём-то важном было бы дырой.
                    c.execute(
                        "ALTER TABLE device_activity ADD COLUMN client_build TEXT NOT NULL DEFAULT ''",
                        [],
                    )?;
                }
                if !has_push_token_policy_json {
                    c.execute(
                        "ALTER TABLE push_tokens ADD COLUMN policy_json TEXT",
                        [],
                    )?;
                }
                if !push_token_platform_is_pk {
                    c.execute("DROP INDEX IF EXISTS push_tokens_updated_idx", [])?;
                    c.execute("ALTER TABLE push_tokens RENAME TO push_tokens_legacy_single", [])?;
                    c.execute(
                        "CREATE TABLE push_tokens (
                            device_id TEXT NOT NULL,
                            token TEXT NOT NULL,
                            platform TEXT NOT NULL,
                            policy_json TEXT,
                            updated_at_ms INTEGER NOT NULL,
                            PRIMARY KEY(device_id, platform)
                        )",
                        [],
                    )?;
                    c.execute(
                        "INSERT INTO push_tokens(device_id, token, platform, policy_json, updated_at_ms)
                         SELECT device_id,
                                token,
                                CASE WHEN TRIM(COALESCE(platform, '')) = '' THEN 'android' ELSE platform END,
                                policy_json,
                                updated_at_ms
                         FROM push_tokens_legacy_single
                         ON CONFLICT(device_id, platform) DO UPDATE SET
                           token = excluded.token,
                           policy_json = excluded.policy_json,
                           updated_at_ms = excluded.updated_at_ms",
                        [],
                    )?;
                    c.execute("DROP TABLE push_tokens_legacy_single", [])?;
                    c.execute(
                        "CREATE INDEX IF NOT EXISTS push_tokens_updated_idx ON push_tokens(updated_at_ms)",
                        [],
                    )?;
                }
                c.execute(
                    "UPDATE rooms SET membership_version = 1 WHERE membership_version <= 0",
                    [],
                )?;
                c.execute(
                    "UPDATE rooms SET reactions_mode = 'all' WHERE TRIM(COALESCE(reactions_mode, '')) = ''",
                    [],
                )?;
                c.execute(
                    "INSERT OR IGNORE INTO room_memberships(room_id, profile_id, status, role, source_link_id, created_at_ms, updated_at_ms) SELECT room_id, owner_profile_id, 'active', 'owner', NULL, created_at_ms, updated_at_ms FROM rooms WHERE owner_profile_id <> ''",
                    [],
                )?;
                c.execute(
                    "CREATE INDEX IF NOT EXISTS call_sessions_participant_idx ON call_sessions(participant_device_id, call_id, call_attempt_id)",
                    [],
                )?;
                c.execute(
                    "CREATE TABLE IF NOT EXISTS message_dedup (
                        device_id TEXT NOT NULL,
                        msg_id TEXT NOT NULL,
                        seq INTEGER NOT NULL,
                        created_at_ms INTEGER NOT NULL,
                        expires_at_ms INTEGER NOT NULL,
                        PRIMARY KEY(device_id, msg_id)
                    )",
                    [],
                )?;
                c.execute(
                    "CREATE INDEX IF NOT EXISTS message_dedup_expires_idx ON message_dedup(expires_at_ms)",
                    [],
                )?;
                c.execute(
                    "CREATE INDEX IF NOT EXISTS call_signal_dedup_call_signal_idx ON call_signal_dedup(call_id, signal_id)",
                    [],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    pub async fn set_block(
        &self,
        profile_id: &str,
        blocked_profile_id: &str,
        blocked: bool,
        now_ms: i64,
    ) -> Result<(), String> {
        let profile_id = profile_id.to_string();
        let blocked_profile_id = blocked_profile_id.to_string();
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                if blocked {
                    c.execute(
                        "INSERT OR IGNORE INTO blocks(profile_id, blocked_profile_id, created_at_ms) VALUES(?1, ?2, ?3)",
                        params![profile_id, blocked_profile_id, now_ms],
                    )?;
                } else {
                    c.execute(
                        "DELETE FROM blocks WHERE profile_id = ?1 AND blocked_profile_id = ?2",
                        params![profile_id, blocked_profile_id],
                    )?;
                }
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    pub async fn is_blocked(
        &self,
        profile_id: &str,
        blocked_profile_id: &str,
    ) -> Result<bool, String> {
        let profile_id = profile_id.to_string();
        let blocked_profile_id = blocked_profile_id.to_string();
        let v = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let exists: i64 = c.query_row(
                    "SELECT EXISTS(SELECT 1 FROM blocks WHERE profile_id = ?1 AND blocked_profile_id = ?2)",
                    params![profile_id, blocked_profile_id],
                    |row| row.get(0),
                )?;
                Ok(exists != 0)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(v)
    }

    pub async fn list_blocks(&self, profile_id: &str, limit: u64) -> Result<Vec<BlockRow>, String> {
        let profile_id = profile_id.to_string();
        let lim = limit as i64;
        let rows = self
            .conn
            .call(move |c| -> Result<Vec<BlockRow>, rusqlite::Error> {
                let mut stmt = c.prepare(
                    "SELECT blocked_profile_id FROM blocks WHERE profile_id = ?1 ORDER BY created_at_ms DESC LIMIT ?2",
                )?;
                let mut rs = stmt.query(params![profile_id, lim])?;
                let mut out = Vec::new();
                while let Some(r) = rs.next()? {
                    out.push(BlockRow {
                        blocked_profile_id: r.get(0)?,
                    });
                }
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(rows)
    }

    // ── SUPPORT TICKETS (TZ 2026-07-24) ──────────────────────────────────────
    #[allow(clippy::too_many_arguments)]
    pub async fn support_ticket_insert(
        &self,
        ticket_id: &str,
        profile_id: &str,
        device_id: &str,
        reply_pubkey_b64: &str,
        ciphertext_b64: &str,
        client_meta_json: Option<&str>,
        now_ms: i64,
    ) -> Result<(), String> {
        let ticket_id = ticket_id.to_string();
        let profile_id = profile_id.to_string();
        let device_id = device_id.to_string();
        let reply_pubkey_b64 = reply_pubkey_b64.to_string();
        let ciphertext_b64 = ciphertext_b64.to_string();
        let client_meta_json = client_meta_json.map(|s| s.to_string());
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "INSERT OR IGNORE INTO support_tickets(ticket_id, profile_id, device_id, reply_pubkey_b64, ciphertext_b64, client_meta_json, created_at_ms, status) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, 'open')",
                    params![ticket_id, profile_id, device_id, reply_pubkey_b64, ciphertext_b64, client_meta_json, now_ms],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    /// Стирает ВСЮ переписку с поддержкой для профиля и ставит отметку времени.
    ///
    /// Отметка — единственный способ сообщить телефону, что ленты больше нет:
    /// на обычном опросе удаление выглядит как «новых ответов нет».
    /// Возвращает, сколько строк удалено (тикеты + ответы).
    pub async fn support_clear_profile(
        &self,
        profile_id: &str,
        now_ms: i64,
    ) -> Result<i64, String> {
        let profile_id = profile_id.to_string();
        self.conn
            .call(move |c| -> Result<i64, rusqlite::Error> {
                let tx = c.transaction()?;
                let tickets = tx.execute(
                    "DELETE FROM support_tickets WHERE profile_id = ?1",
                    params![profile_id],
                )?;
                let replies = tx.execute(
                    "DELETE FROM support_replies WHERE profile_id = ?1",
                    params![profile_id],
                )?;
                tx.execute(
                    "INSERT INTO support_cleared(profile_id, cleared_at_ms) VALUES(?1, ?2) ON CONFLICT(profile_id) DO UPDATE SET cleared_at_ms = excluded.cleared_at_ms",
                    params![profile_id, now_ms],
                )?;
                tx.commit()?;
                Ok((tickets + replies) as i64)
            })
            .await
            .map_err(|e| e.to_string())
    }

    /// Когда переписку профиля стёрли последний раз (0 — не стирали).
    pub async fn support_cleared_at(&self, profile_id: &str) -> Result<i64, String> {
        let profile_id = profile_id.to_string();
        self.conn
            .call(move |c| -> Result<i64, rusqlite::Error> {
                let mut st = c.prepare(
                    "SELECT cleared_at_ms FROM support_cleared WHERE profile_id = ?1",
                )?;
                let mut rows = st.query(params![profile_id])?;
                if let Some(r) = rows.next()? {
                    Ok(r.get::<_, i64>(0)?)
                } else {
                    Ok(0)
                }
            })
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn list_support_tickets(
        &self,
        since_ms: i64,
        limit: u64,
    ) -> Result<Vec<SupportTicketRow>, String> {
        let lim = limit as i64;
        let rows = self
            .conn
            .call(move |c| -> Result<Vec<SupportTicketRow>, rusqlite::Error> {
                let mut stmt = c.prepare(
                    "SELECT ticket_id, profile_id, device_id, reply_pubkey_b64, ciphertext_b64, client_meta_json, created_at_ms, status FROM support_tickets WHERE created_at_ms > ?1 ORDER BY created_at_ms DESC LIMIT ?2",
                )?;
                let mut rs = stmt.query(params![since_ms, lim])?;
                let mut out = Vec::new();
                while let Some(r) = rs.next()? {
                    out.push(SupportTicketRow {
                        ticket_id: r.get(0)?,
                        profile_id: r.get(1)?,
                        device_id: r.get(2)?,
                        reply_pubkey_b64: r.get(3)?,
                        ciphertext_b64: r.get(4)?,
                        client_meta_json: r.get(5)?,
                        created_at_ms: r.get(6)?,
                        status: r.get(7)?,
                    });
                }
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(rows)
    }

    /// The (profile_id, device_id) that opened [ticket_id], to route an admin
    /// reply's wake push. None if the ticket doesn't exist.
    pub async fn support_ticket_target(
        &self,
        ticket_id: &str,
    ) -> Result<Option<(String, String)>, String> {
        let ticket_id = ticket_id.to_string();
        let out = self
            .conn
            .call(move |c| -> Result<Option<(String, String)>, rusqlite::Error> {
                c.query_row(
                    "SELECT profile_id, device_id FROM support_tickets WHERE ticket_id = ?1",
                    params![ticket_id],
                    |r| Ok((r.get::<_, String>(0)?, r.get::<_, String>(1)?)),
                )
                .optional()
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    /// Insert an admin reply; returns the new per-profile `seq` (the user's poll
    /// cursor). Seq is allocated MAX+1 inside the same call to avoid races.
    pub async fn support_reply_insert(
        &self,
        reply_id: &str,
        ticket_id: &str,
        profile_id: &str,
        ciphertext_b64: &str,
        now_ms: i64,
    ) -> Result<i64, String> {
        let reply_id = reply_id.to_string();
        let ticket_id = ticket_id.to_string();
        let profile_id = profile_id.to_string();
        let ciphertext_b64 = ciphertext_b64.to_string();
        let seq = self
            .conn
            .call(move |c| -> Result<i64, rusqlite::Error> {
                let seq: i64 = c.query_row(
                    "SELECT COALESCE(MAX(seq), 0) + 1 FROM support_replies WHERE profile_id = ?1",
                    params![profile_id],
                    |r| r.get(0),
                )?;
                c.execute(
                    "INSERT OR IGNORE INTO support_replies(reply_id, ticket_id, profile_id, seq, ciphertext_b64, created_at_ms) VALUES(?1, ?2, ?3, ?4, ?5, ?6)",
                    params![reply_id, ticket_id, profile_id, seq, ciphertext_b64, now_ms],
                )?;
                Ok(seq)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(seq)
    }

    pub async fn list_support_replies_from(
        &self,
        profile_id: &str,
        from_seq: i64,
        limit: u64,
    ) -> Result<Vec<SupportReplyRow>, String> {
        let profile_id = profile_id.to_string();
        let lim = limit as i64;
        let rows = self
            .conn
            .call(move |c| -> Result<Vec<SupportReplyRow>, rusqlite::Error> {
                let mut stmt = c.prepare(
                    "SELECT reply_id, ticket_id, seq, ciphertext_b64, created_at_ms FROM support_replies WHERE profile_id = ?1 AND seq > ?2 ORDER BY seq ASC LIMIT ?3",
                )?;
                let mut rs = stmt.query(params![profile_id, from_seq, lim])?;
                let mut out = Vec::new();
                while let Some(r) = rs.next()? {
                    out.push(SupportReplyRow {
                        reply_id: r.get(0)?,
                        ticket_id: r.get(1)?,
                        seq: r.get(2)?,
                        ciphertext_b64: r.get(3)?,
                        created_at_ms: r.get(4)?,
                    });
                }
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(rows)
    }

    pub async fn upsert_push_token(
        &self,
        device_id: &str,
        token: &str,
        platform: &str,
        policy_json: Option<&str>,
        now_ms: i64,
    ) -> Result<(), String> {
        let device_id = device_id.to_string();
        let token = token.to_string();
        let platform = platform.to_string();
        let policy_json = policy_json.map(|value| value.to_string());
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "INSERT INTO push_tokens(device_id, token, platform, policy_json, updated_at_ms) VALUES(?1, ?2, ?3, ?4, ?5)\n                     ON CONFLICT(device_id, platform) DO UPDATE SET token = excluded.token, policy_json = excluded.policy_json, updated_at_ms = excluded.updated_at_ms",
                    params![device_id, token, platform, policy_json, now_ms],
                )?;
                // FIX-SERVER-2 (R-02 push dedup): a physical FCM/APNs token is
                // unique to one app install on one phone, so any OTHER device_id
                // still holding this exact token is a stale/zombie identity from
                // a previous account on the same phone (device_id rotation keeps
                // the same token). Repoint the token to ONLY the current device
                // so a push for a zombie's mailbox can no longer wake this phone
                // ("notification arrives but no message"). Non-empty tokens only.
                if !token.is_empty() {
                    // Capture the superseded device_ids BEFORE dropping their
                    // token rows so we can also evict them from the delivery
                    // fanout below.
                    let superseded: Vec<String> = {
                        let mut stmt = c.prepare(
                            "SELECT device_id FROM push_tokens WHERE token = ?1 AND platform = ?2 AND device_id <> ?3",
                        )?;
                        let mapped = stmt.query_map(
                            params![token, platform, device_id],
                            |row| row.get::<_, String>(0),
                        )?;
                        let mut out = Vec::new();
                        for r in mapped {
                            out.push(r?);
                        }
                        out
                    };
                    let _ = c.execute(
                        "DELETE FROM push_tokens WHERE token = ?1 AND platform = ?2 AND device_id <> ?3",
                        params![token, platform, device_id],
                    )?;
                    // DEVICE-ROTATION FIX (2026-07-12): a superseded device_id (a
                    // token takeover = the SAME physical phone rotated its
                    // device_id) can never receive again, yet without this it
                    // stays "active" for the 30-day staleness window — so senders
                    // keep encrypting into its dead mailbox (message loss to a
                    // peer who reinstalled / rotated). Ciphertext encrypted for the
                    // old device can't be re-read by the new one (different keys),
                    // so migrating the mailbox is impossible; the only cure is to
                    // drop the old device from senders' fanout. Zero its activity
                    // so `GET /v1/active_devices` (the sender-side fanout filter)
                    // excludes it immediately. The INV-1 guard there still prevents
                    // emptying a solo-device profile, and desktop companions (no
                    // push token) never trigger a takeover, so they are unaffected.
                    for sd in &superseded {
                        let _ = c.execute(
                            "UPDATE device_activity SET superseded_at_ms = ?2, last_pump_at_ms = 0, last_push_attempted_at_ms = 0, last_push_delivered_at_ms = 0, updated_at_ms = ?2 WHERE device_id = ?1",
                            params![sd, now_ms],
                        )?;
                    }
                }
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    pub async fn delete_push_token(&self, device_id: &str) -> Result<(), String> {
        let device_id = device_id.to_string();
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "DELETE FROM push_tokens WHERE device_id = ?1",
                    params![device_id],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    pub async fn delete_push_token_for_platform(
        &self,
        device_id: &str,
        platform: &str,
    ) -> Result<(), String> {
        let device_id = device_id.to_string();
        let platform = platform.to_string();
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "DELETE FROM push_tokens WHERE device_id = ?1 AND platform = ?2",
                    params![device_id, platform],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    /// TOCTOU-safe variant of `delete_push_token_for_platform`.
    ///
    /// Deletes the `(device_id, platform)` row **only if** the stored token is
    /// still equal to `token`. If the client rotated the token between our
    /// failed push attempt and this invalidation call, the new token survives.
    ///
    /// Returns `Ok(true)` if a row was deleted, `Ok(false)` otherwise.
    pub async fn delete_push_token_if_token_matches(
        &self,
        device_id: &str,
        platform: &str,
        token: &str,
    ) -> Result<bool, String> {
        let device_id = device_id.to_string();
        let platform = platform.to_string();
        let token = token.to_string();
        let affected = self
            .conn
            .call(move |c| -> Result<usize, rusqlite::Error> {
                let n = c.execute(
                    "DELETE FROM push_tokens WHERE device_id = ?1 AND platform = ?2 AND token = ?3",
                    params![device_id, platform, token],
                )?;
                Ok(n)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(affected > 0)
    }

    // ============================================================
    // Sprint 2 R3/R7: device_activity tracking
    // ============================================================
    //
    // All four `record_*` methods are idempotent best-effort upserts —
    // they create the row on first observation and never delete it.
    // The reader (`list_active_devices_for_profile`) decides what counts
    // as "active" based on `now_ms` and the configured thresholds.

    /// Record a fresh login / re-authentication for `device_id`.
    ///
    /// Updates `profile_id` (if known) and bumps `last_pump_at_ms` —
    /// a successful WS welcome is the strongest possible signal that
    /// the device is alive (it just proved possession of the identity
    /// key). Called from the WS `handle_socket` handshake and from
    /// `http_welcome` for the parity HTTP path.
    pub async fn record_device_login(
        &self,
        device_id: &str,
        profile_id: Option<&str>,
        now_ms: i64,
    ) -> Result<(), String> {
        let device_id = device_id.to_string();
        let profile_id = profile_id.unwrap_or("").to_string();
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "INSERT INTO device_activity(device_id, profile_id, last_pump_at_ms, last_push_attempted_at_ms, last_push_delivered_at_ms, updated_at_ms) \
                     VALUES(?1, ?2, ?3, 0, 0, ?3) \
                     ON CONFLICT(device_id) DO UPDATE SET \
                       profile_id = CASE WHEN excluded.profile_id <> '' THEN excluded.profile_id ELSE device_activity.profile_id END, \
                       last_pump_at_ms = MAX(device_activity.last_pump_at_ms, excluded.last_pump_at_ms), \
                       updated_at_ms = excluded.updated_at_ms",
                    params![device_id, profile_id, now_ms],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    /// Bump `last_pump_at_ms` after the device drained pending messages.
    ///
    /// Called from `list_pending_from` and from the WS `FetchPending`
    /// handler. Does NOT update `profile_id` — that's exclusively the
    /// login path's job.
    pub async fn record_pump_activity(
        &self,
        device_id: &str,
        now_ms: i64,
    ) -> Result<(), String> {
        let device_id = device_id.to_string();
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "INSERT INTO device_activity(device_id, profile_id, last_pump_at_ms, last_push_attempted_at_ms, last_push_delivered_at_ms, updated_at_ms) \
                     VALUES(?1, '', ?2, 0, 0, ?2) \
                     ON CONFLICT(device_id) DO UPDATE SET \
                       last_pump_at_ms = MAX(device_activity.last_pump_at_ms, excluded.last_pump_at_ms), \
                       updated_at_ms = excluded.updated_at_ms",
                    params![device_id, now_ms],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    /// Record an outbound push attempt (regardless of delivery outcome).
    /// Called immediately before invoking FCM / APNs.
    pub async fn record_push_attempted(
        &self,
        device_id: &str,
        now_ms: i64,
    ) -> Result<(), String> {
        let device_id = device_id.to_string();
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "INSERT INTO device_activity(device_id, profile_id, last_pump_at_ms, last_push_attempted_at_ms, last_push_delivered_at_ms, updated_at_ms) \
                     VALUES(?1, '', 0, ?2, 0, ?2) \
                     ON CONFLICT(device_id) DO UPDATE SET \
                       last_push_attempted_at_ms = MAX(device_activity.last_push_attempted_at_ms, excluded.last_push_attempted_at_ms), \
                       updated_at_ms = excluded.updated_at_ms",
                    params![device_id, now_ms],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    /// Record a successful push (FCM / APNs accepted the payload).
    /// This is the closest server-side proxy to «recipient device is reachable
    /// via push» — used by the R3 staleness filter as a positive liveness signal.
    pub async fn record_push_delivered(
        &self,
        device_id: &str,
        now_ms: i64,
    ) -> Result<(), String> {
        let device_id = device_id.to_string();
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "INSERT INTO device_activity(device_id, profile_id, last_pump_at_ms, last_push_attempted_at_ms, last_push_delivered_at_ms, updated_at_ms) \
                     VALUES(?1, '', 0, ?2, ?2, ?2) \
                     ON CONFLICT(device_id) DO UPDATE SET \
                       last_push_delivered_at_ms = MAX(device_activity.last_push_delivered_at_ms, excluded.last_push_delivered_at_ms), \
                       last_push_attempted_at_ms = MAX(device_activity.last_push_attempted_at_ms, excluded.last_push_attempted_at_ms), \
                       updated_at_ms = excluded.updated_at_ms",
                    params![device_id, now_ms],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    /// Read a single device's activity snapshot. Returns `None` if the
    /// device has never been observed by relay since the table was
    /// introduced (in that case the R3 filter conservatively treats the
    /// device as fresh — see `list_active_devices_for_profile`).
    /// Запоминает версию сборки клиента (справочно, для подсчёта раскатки).
    ///
    /// Пишется ТОЛЬКО если строка активности уже есть: заводить устройство
    /// по неподписанному заголовку нельзя. Пустая строка игнорируется.
    pub async fn device_activity_set_client_build(
        &self,
        device_id: &str,
        client_build: &str,
        now_ms: i64,
    ) -> Result<(), String> {
        let device_id = device_id.to_string();
        let client_build = client_build.trim().chars().take(32).collect::<String>();
        if client_build.is_empty() {
            return Ok(());
        }
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "UPDATE device_activity SET client_build = ?2, updated_at_ms = ?3 \
                     WHERE device_id = ?1 AND client_build <> ?2",
                    params![device_id, client_build, now_ms],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    /// Разбивка активных устройств по версии сборки за последние [window_ms].
    /// Ровно то число, без которого нельзя включать отправку.
    pub async fn client_build_distribution(
        &self,
        since_ms: i64,
    ) -> Result<Vec<(String, i64)>, String> {
        self.conn
            .call(move |c| -> Result<Vec<(String, i64)>, rusqlite::Error> {
                let mut stmt = c.prepare(
                    "SELECT CASE WHEN client_build = '' THEN '(неизвестно)' ELSE client_build END AS b, \
                            COUNT(*) FROM device_activity \
                      WHERE last_pump_at_ms >= ?1 GROUP BY b ORDER BY COUNT(*) DESC",
                )?;
                let mut rows = stmt.query(params![since_ms])?;
                let mut out = Vec::new();
                while let Some(row) = rows.next()? {
                    out.push((row.get::<_, String>(0)?, row.get::<_, i64>(1)?));
                }
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())
    }

    /// Сборка, названная устройством. Пустая строка = устройство её ни разу не
    /// назвало (сокет-житель на старом клиенте, либо путь без заголовка).
    pub async fn device_activity_client_build(
        &self,
        device_id: &str,
    ) -> Result<String, String> {
        let device_id = device_id.to_string();
        self.conn
            .call(move |c| -> Result<String, rusqlite::Error> {
                let mut stmt =
                    c.prepare("SELECT client_build FROM device_activity WHERE device_id = ?1")?;
                let mut rows = stmt.query(params![device_id])?;
                if let Some(row) = rows.next()? {
                    Ok(row.get::<_, String>(0)?)
                } else {
                    Ok(String::new())
                }
            })
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn device_activity_get(
        &self,
        device_id: &str,
    ) -> Result<Option<DeviceActivityRow>, String> {
        let device_id = device_id.to_string();
        let row = self
            .conn
            .call(move |c| -> Result<Option<DeviceActivityRow>, rusqlite::Error> {
                let r = c
                    .query_row(
                        "SELECT device_id, profile_id, last_pump_at_ms, last_push_attempted_at_ms, last_push_delivered_at_ms, updated_at_ms, superseded_at_ms \
                         FROM device_activity WHERE device_id = ?1",
                        params![device_id],
                        |row| {
                            Ok(DeviceActivityRow {
                                device_id: row.get(0)?,
                                profile_id: row.get(1)?,
                                last_pump_at_ms: row.get(2)?,
                                last_push_attempted_at_ms: row.get(3)?,
                                last_push_delivered_at_ms: row.get(4)?,
                                updated_at_ms: row.get(5)?,
                                superseded_at_ms: row.get(6)?,
                            })
                        },
                    )
                    .optional()?;
                Ok(r)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(row)
    }

    /// List all device activity rows for a profile.
    ///
    /// Callers apply their own staleness filter on top of this raw set
    /// — this method intentionally returns everything so the caller can
    /// enforce the «minimum-one-active-device» invariant (INV-1 of the
    /// Restore Safety Contract).
    /// Delete a `device_activity` row. Used by the Sprint 2 R4 cleanup
    /// loop after the per-profile INV-1 check confirms the deletion is
    /// safe. Returns `Ok(true)` if a row was deleted.
    pub async fn device_activity_delete(&self, device_id: &str) -> Result<bool, String> {
        let device_id = device_id.to_string();
        let affected = self
            .conn
            .call(move |c| -> Result<usize, rusqlite::Error> {
                let n = c.execute(
                    "DELETE FROM device_activity WHERE device_id = ?1",
                    params![device_id],
                )?;
                Ok(n)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(affected > 0)
    }

    /// List `device_activity` rows whose newest liveness signal is
    /// strictly older than `older_than_ms`. Skips rows with an empty
    /// `profile_id` (we cannot evaluate INV-1 without it, so we leave
    /// such rows for a later pass when the device next logs in and the
    /// profile binding gets populated).
    pub async fn device_activity_list_stale(
        &self,
        older_than_ms: i64,
        limit: usize,
    ) -> Result<Vec<DeviceActivityRow>, String> {
        let limit = limit as i64;
        let rows = self
            .conn
            .call(move |c| -> Result<Vec<DeviceActivityRow>, rusqlite::Error> {
                let mut stmt = c.prepare(
                    "SELECT device_id, profile_id, last_pump_at_ms, last_push_attempted_at_ms, last_push_delivered_at_ms, updated_at_ms, superseded_at_ms \
                     FROM device_activity \
                     WHERE profile_id <> '' \
                       AND last_pump_at_ms < ?1 \
                       AND last_push_delivered_at_ms < ?1 \
                     ORDER BY updated_at_ms ASC \
                     LIMIT ?2",
                )?;
                let mapped = stmt.query_map(params![older_than_ms, limit], |row| {
                    Ok(DeviceActivityRow {
                        device_id: row.get(0)?,
                        profile_id: row.get(1)?,
                        last_pump_at_ms: row.get(2)?,
                        last_push_attempted_at_ms: row.get(3)?,
                        last_push_delivered_at_ms: row.get(4)?,
                        updated_at_ms: row.get(5)?,
                        superseded_at_ms: row.get(6)?,
                    })
                })?;
                let mut out = Vec::new();
                for row in mapped {
                    out.push(row?);
                }
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(rows)
    }

    /// К-5 (17.09.2026): the OLDEST app build among the live devices of these
    /// profiles (not superseded, seen since `active_since_ms`). A device with no
    /// build on record counts as 0: it predates the build report and is old by
    /// definition. `None` = no live device known at all.
    ///
    /// "Seen" = the device drained its mailbox or a push reached it — the same
    /// signals as the staleness filter. Not `updated_at_ms`: every push ATTEMPT
    /// bumps it, so a dead phone that peers keep writing to would look alive
    /// and hold the room at the tier cap forever.
    pub async fn oldest_client_build_for_profiles(
        &self,
        profile_ids: Vec<String>,
        active_since_ms: i64,
    ) -> Result<Option<i64>, String> {
        let ids: Vec<String> = profile_ids
            .into_iter()
            .map(|p| p.trim().to_string())
            .filter(|p| !p.is_empty())
            .collect();
        if ids.is_empty() {
            return Ok(None);
        }
        self.conn
            .call(move |c| -> Result<Option<i64>, rusqlite::Error> {
                let mut oldest: Option<i64> = None;
                for chunk in ids.chunks(400) {
                    let placeholders = vec!["?"; chunk.len()].join(",");
                    let sql = format!(
                        "SELECT client_build FROM device_activity \
                         WHERE profile_id IN ({placeholders}) AND superseded_at_ms = 0 \
                           AND MAX(last_pump_at_ms, last_push_delivered_at_ms) >= ?"
                    );
                    let mut stmt = c.prepare(&sql)?;
                    let mut args: Vec<rusqlite::types::Value> = chunk
                        .iter()
                        .map(|p| rusqlite::types::Value::Text(p.clone()))
                        .collect();
                    args.push(rusqlite::types::Value::Integer(active_since_ms));
                    let mut rows = stmt.query(rusqlite::params_from_iter(args))?;
                    while let Some(row) = rows.next()? {
                        let raw: String = row.get(0)?;
                        let build = parse_client_build(&raw);
                        oldest = Some(oldest.map_or(build, |o| o.min(build)));
                    }
                }
                Ok(oldest)
            })
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn device_activity_list_for_profile(
        &self,
        profile_id: &str,
    ) -> Result<Vec<DeviceActivityRow>, String> {
        let profile_id = profile_id.to_string();
        let rows = self
            .conn
            .call(move |c| -> Result<Vec<DeviceActivityRow>, rusqlite::Error> {
                let mut stmt = c.prepare(
                    "SELECT device_id, profile_id, last_pump_at_ms, last_push_attempted_at_ms, last_push_delivered_at_ms, updated_at_ms, superseded_at_ms \
                     FROM device_activity WHERE profile_id = ?1",
                )?;
                let mapped = stmt.query_map(params![profile_id], |row| {
                    Ok(DeviceActivityRow {
                        device_id: row.get(0)?,
                        profile_id: row.get(1)?,
                        last_pump_at_ms: row.get(2)?,
                        last_push_attempted_at_ms: row.get(3)?,
                        last_push_delivered_at_ms: row.get(4)?,
                        updated_at_ms: row.get(5)?,
                        superseded_at_ms: row.get(6)?,
                    })
                })?;
                let mut out = Vec::new();
                for row in mapped {
                    out.push(row?);
                }
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(rows)
    }

    pub async fn get_push_token(&self, device_id: &str) -> Result<Option<PushTokenRow>, String> {
        let device_id = device_id.to_string();
        let row = self
            .conn
            .call(move |c| -> Result<Option<PushTokenRow>, rusqlite::Error> {
                let r = c
                    .query_row(
                        "SELECT device_id, token, platform, policy_json FROM push_tokens WHERE device_id = ?1 ORDER BY CASE platform WHEN 'android' THEN 0 WHEN 'ios' THEN 0 WHEN 'ios_voip' THEN 1 ELSE 2 END, updated_at_ms DESC LIMIT 1",
                        params![device_id],
                        |row| {
                            Ok(PushTokenRow {
                                device_id: row.get(0)?,
                                token: row.get(1)?,
                                platform: row.get(2)?,
                                policy_json: row.get(3)?,
                            })
                        },
                    )
                    .optional()?;
                Ok(r)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(row)
    }

    pub async fn get_push_token_for_platform(
        &self,
        device_id: &str,
        platform: &str,
    ) -> Result<Option<PushTokenRow>, String> {
        let device_id = device_id.to_string();
        let platform = platform.to_string();
        let row = self
            .conn
            .call(move |c| -> Result<Option<PushTokenRow>, rusqlite::Error> {
                let r = c
                    .query_row(
                        "SELECT device_id, token, platform, policy_json FROM push_tokens WHERE device_id = ?1 AND platform = ?2",
                        params![device_id, platform],
                        |row| {
                            Ok(PushTokenRow {
                                device_id: row.get(0)?,
                                token: row.get(1)?,
                                platform: row.get(2)?,
                                policy_json: row.get(3)?,
                            })
                        },
                    )
                    .optional()?;
                Ok(r)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(row)
    }

    pub async fn list_push_tokens(&self, device_id: &str) -> Result<Vec<PushTokenRow>, String> {
        let device_id = device_id.to_string();
        let rows = self
            .conn
            .call(move |c| -> Result<Vec<PushTokenRow>, rusqlite::Error> {
                let mut stmt = c.prepare(
                    "SELECT device_id, token, platform, policy_json FROM push_tokens WHERE device_id = ?1 ORDER BY CASE platform WHEN 'android' THEN 0 WHEN 'ios' THEN 0 WHEN 'ios_voip' THEN 1 ELSE 2 END, updated_at_ms DESC",
                )?;
                let mapped = stmt.query_map(params![device_id], |row| {
                    Ok(PushTokenRow {
                        device_id: row.get(0)?,
                        token: row.get(1)?,
                        platform: row.get(2)?,
                        policy_json: row.get(3)?,
                    })
                })?;
                let mut out = Vec::new();
                for row in mapped {
                    out.push(row?);
                }
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(rows)
    }

    pub async fn push_token_stats(&self, now_ms: i64) -> Result<PushTokenStats, String> {
        let cutoff_ms = now_ms - 24 * 60 * 60 * 1000;
        let stats = self
            .conn
            .call(move |c| -> Result<PushTokenStats, rusqlite::Error> {
                let mut stats = PushTokenStats::default();
                let mut stmt = c.prepare(
                    "SELECT platform, COUNT(*) AS n, SUM(CASE WHEN updated_at_ms >= ?1 THEN 1 ELSE 0 END) AS recent FROM push_tokens GROUP BY platform",
                )?;
                let rows = stmt.query_map(params![cutoff_ms], |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, i64>(1)?,
                        row.get::<_, Option<i64>>(2)?.unwrap_or(0),
                    ))
                })?;
                for row in rows {
                    let (platform, count, recent) = row?;
                    stats.total += count;
                    stats.updated_last_24h += recent;
                    match platform.as_str() {
                        "android" => stats.android += count,
                        "ios" => stats.ios += count,
                        "ios_voip" => stats.ios_voip += count,
                        _ => stats.unsupported += count,
                    }
                }
                Ok(stats)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(stats)
    }

    pub async fn create_room(
        &self,
        room_id: &str,
        owner_profile_id: &str,
        created_by_device_id: &str,
        title: &str,
        now_ms: i64,
    ) -> Result<CreateRoomResult, CreateRoomError> {
        let room_id = room_id.to_string();
        let owner_profile_id = owner_profile_id.to_string();
        let created_by_device_id = created_by_device_id.to_string();
        let title = title.to_string();
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<CreateRoomResult, RoomRow>, rusqlite::Error> {
                let owner_profile_id_for_existing = owner_profile_id.clone();
                let created_by_device_id_for_existing = created_by_device_id.clone();
                let title_for_existing = title.clone();
                let existing = c
                    .query_row(
                        ROOM_SELECT_BY_ID_SQL,
                        params![room_id.clone()],
                        map_room_row,
                    )
                    .optional()?;

                if let Some(room) = existing {
                    if room.owner_profile_id == owner_profile_id_for_existing
                        && room.created_by_device_id == created_by_device_id_for_existing
                        && room.title == title_for_existing
                    {
                        return Ok(Ok(CreateRoomResult {
                            created: false,
                            room,
                        }));
                    }

                    return Ok(Err(room));
                }

                let tx = c.transaction()?;
                tx.execute(
                    "INSERT INTO rooms(room_id, version, membership_version, owner_profile_id, created_by_device_id, title, description, avatar_hash, avatar_image_b64, reactions_mode, allow_text, allow_media, allow_add_members, allow_pin_messages, allow_change_group_info, allow_change_tag, join_approval_required, slow_mode_seconds, chat_history_visible, created_at_ms, updated_at_ms) VALUES(?1, 1, 1, ?2, ?3, ?4, NULL, NULL, NULL, 'all', 1, 1, 1, 1, 1, 0, 0, 0, 0, ?5, ?5)",
                    params![
                        room_id.clone(),
                        owner_profile_id.clone(),
                        created_by_device_id.clone(),
                        title.clone(),
                        now_ms
                    ],
                )?;

                tx.execute(
                    "INSERT INTO room_memberships(room_id, profile_id, status, role, source_link_id, created_at_ms, updated_at_ms) VALUES(?1, ?2, 'active', 'owner', NULL, ?3, ?3)",
                    params![room_id.clone(), owner_profile_id, now_ms],
                )?;

                let room = tx.query_row(
                    ROOM_SELECT_BY_ID_SQL,
                    params![room_id],
                    map_room_row,
                )?;

                tx.commit()?;

                Ok(Ok(CreateRoomResult {
                    created: true,
                    room,
                }))
            })
            .await
            .map_err(|e| CreateRoomError::Storage(e.to_string()))?;

        match outcome {
            Ok(result) => Ok(result),
            Err(existing_room) => Err(CreateRoomError::Conflict(existing_room)),
        }
    }

    pub async fn get_room(&self, room_id: &str) -> Result<Option<RoomRow>, String> {
        let room_id = room_id.to_string();
        let row = self
            .conn
            .call(move |c| -> Result<Option<RoomRow>, rusqlite::Error> {
                let room = c
                    .query_row(ROOM_SELECT_BY_ID_SQL, params![room_id], map_room_row)
                    .optional()?;
                Ok(room)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(row)
    }

    pub async fn get_room_membership(
        &self,
        room_id: &str,
        profile_id: &str,
    ) -> Result<Option<RoomMembershipRow>, String> {
        let room_id = room_id.to_string();
        let profile_id = profile_id.to_string();
        let row = self
            .conn
            .call(
                move |c| -> Result<Option<RoomMembershipRow>, rusqlite::Error> {
                    let membership = c
                        .query_row(
                            ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                            params![room_id, profile_id],
                            map_room_membership_row,
                        )
                        .optional()?;
                    Ok(membership)
                },
            )
            .await
            .map_err(|e| e.to_string())?;
        Ok(row)
    }

    pub async fn list_room_memberships(
        &self,
        room_id: &str,
    ) -> Result<Vec<RoomMembershipRow>, String> {
        let room_id = room_id.to_string();
        let rows = self
            .conn
            .call(
                move |c| -> Result<Vec<RoomMembershipRow>, rusqlite::Error> {
                    let mut stmt = c.prepare(ROOM_MEMBERSHIPS_SELECT_BY_ROOM_SQL)?;
                    let mut rs = stmt.query(params![room_id])?;
                    let mut out = Vec::new();
                    while let Some(row) = rs.next()? {
                        out.push(map_room_membership_row(row)?);
                    }
                    Ok(out)
                },
            )
            .await
            .map_err(|e| e.to_string())?;
        Ok(rows)
    }

    pub async fn list_room_invite_links(
        &self,
        room_id: &str,
    ) -> Result<Vec<RoomInviteLinkRow>, String> {
        let room_id = room_id.to_string();
        let rows = self
            .conn
            .call(move |c| -> Result<Vec<RoomInviteLinkRow>, rusqlite::Error> {
                let mut stmt = c.prepare(
                    "SELECT link_id, room_id, slug, created_by_profile_id, expires_at_ms, max_uses, use_count, requires_approval, allowed_role, is_revoked, created_at_ms, updated_at_ms FROM room_invite_links WHERE room_id = ?1 ORDER BY is_revoked ASC, updated_at_ms DESC, created_at_ms DESC, link_id ASC",
                )?;
                let mut rs = stmt.query(params![room_id])?;
                let mut out = Vec::new();
                while let Some(row) = rs.next()? {
                    out.push(map_room_invite_link_row(row)?);
                }
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(rows)
    }

    pub async fn get_room_invite_link_by_slug(
        &self,
        slug: &str,
    ) -> Result<Option<RoomInviteLinkRow>, String> {
        let slug = slug.to_string();
        let row = self
            .conn
            .call(move |c| -> Result<Option<RoomInviteLinkRow>, rusqlite::Error> {
                let invite_link = c
                    .query_row(
                        "SELECT link_id, room_id, slug, created_by_profile_id, expires_at_ms, max_uses, use_count, requires_approval, allowed_role, is_revoked, created_at_ms, updated_at_ms FROM room_invite_links WHERE slug = ?1",
                        params![slug],
                        map_room_invite_link_row,
                    )
                    .optional()?;
                Ok(invite_link)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(row)
    }

    pub async fn count_active_room_members(&self, room_id: &str) -> Result<i64, String> {
        let room_id = room_id.to_string();
        let count = self
            .conn
            .call(move |c| -> Result<i64, rusqlite::Error> {
                c.query_row(
                    "SELECT COUNT(*) FROM room_memberships WHERE room_id = ?1 AND status = 'active'",
                    params![room_id],
                    |row| row.get(0),
                )
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(count)
    }

    /// Number of rooms OWNED by a profile (monetization §C-3 group-create cap).
    pub async fn count_owned_rooms(&self, owner_profile_id: &str) -> Result<i64, String> {
        let owner = owner_profile_id.to_string();
        let count = self
            .conn
            .call(move |c| -> Result<i64, rusqlite::Error> {
                c.query_row(
                    "SELECT COUNT(*) FROM rooms WHERE owner_profile_id = ?1",
                    params![owner],
                    |row| row.get(0),
                )
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(count)
    }

    /// Number of rooms a profile is an ACTIVE member of (group-join cap).
    pub async fn count_active_memberships_for_profile(
        &self,
        profile_id: &str,
    ) -> Result<i64, String> {
        let profile_id = profile_id.to_string();
        let count = self
            .conn
            .call(move |c| -> Result<i64, rusqlite::Error> {
                c.query_row(
                    "SELECT COUNT(*) FROM room_memberships WHERE profile_id = ?1 AND status = 'active'",
                    params![profile_id],
                    |row| row.get(0),
                )
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(count)
    }

    pub async fn get_active_room_call(
        &self,
        room_id: &str,
        self_device_id: Option<&str>,
    ) -> Result<Option<RoomCallSnapshot>, String> {
        let room_id = room_id.to_string();
        let self_device_id = self_device_id.map(|value| value.to_string());
        let snapshot = self
            .conn
            .call(
                move |c| -> Result<Option<RoomCallSnapshot>, rusqlite::Error> {
                    let tx = c.transaction()?;
                    let call = tx
                        .query_row(
                            ROOM_CALL_ACTIVE_SELECT_BY_ROOM_SQL,
                            params![room_id.clone()],
                            map_room_call_row,
                        )
                        .optional()?;
                    let snapshot = if let Some(call) = call {
                        Some(load_room_call_snapshot(
                            &tx,
                            &room_id,
                            call,
                            self_device_id.as_deref(),
                        )?)
                    } else {
                        None
                    };
                    tx.commit()?;
                    Ok(snapshot)
                },
            )
            .await
            .map_err(|e| e.to_string())?;
        Ok(snapshot)
    }

    pub async fn get_room_call(
        &self,
        room_id: &str,
        call_id: &str,
        self_device_id: Option<&str>,
    ) -> Result<Option<RoomCallSnapshot>, String> {
        let room_id = room_id.to_string();
        let call_id = call_id.to_string();
        let self_device_id = self_device_id.map(|value| value.to_string());
        let snapshot = self
            .conn
            .call(
                move |c| -> Result<Option<RoomCallSnapshot>, rusqlite::Error> {
                    let tx = c.transaction()?;
                    let call = tx
                        .query_row(
                            ROOM_CALL_SELECT_BY_ROOM_AND_ID_SQL,
                            params![room_id.clone(), call_id],
                            map_room_call_row,
                        )
                        .optional()?;
                    let snapshot = if let Some(call) = call {
                        Some(load_room_call_snapshot(
                            &tx,
                            &room_id,
                            call,
                            self_device_id.as_deref(),
                        )?)
                    } else {
                        None
                    };
                    tx.commit()?;
                    Ok(snapshot)
                },
            )
            .await
            .map_err(|e| e.to_string())?;
        Ok(snapshot)
    }

    pub async fn upsert_room_call_media_participant(
        &self,
        room_id: &str,
        call_id: &str,
        profile_id: &str,
        device_id: &str,
        publish_audio: bool,
        publish_video: bool,
        publish_screen_share: bool,
        subscribe_all: bool,
        now_ms: i64,
    ) -> Result<RoomCallSnapshot, RoomCallControlError> {
        let room_id = room_id.to_string();
        let call_id = call_id.to_string();
        let profile_id = profile_id.to_string();
        let device_id = device_id.to_string();
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<RoomCallSnapshot, RoomCallControlError>, rusqlite::Error> {
                let tx = c.transaction()?;

                let room_exists = tx
                    .query_row(
                        ROOM_SELECT_BY_ID_SQL,
                        params![room_id.clone()],
                        map_room_row,
                    )
                    .optional()?
                    .is_some();
                if !room_exists {
                    return Ok(Err(RoomCallControlError::RoomNotFound));
                }

                let membership = tx
                    .query_row(
                        ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                        params![room_id.clone(), profile_id.clone()],
                        map_room_membership_row,
                    )
                    .optional()?;
                let Some(membership) = membership else {
                    return Ok(Err(RoomCallControlError::NotActiveMember));
                };
                if membership.status != "active" {
                    return Ok(Err(RoomCallControlError::NotActiveMember));
                }

                let mut call = tx
                    .query_row(
                        ROOM_CALL_SELECT_BY_ROOM_AND_ID_SQL,
                        params![room_id.clone(), call_id.clone()],
                        map_room_call_row,
                    )
                    .optional()?;
                let Some(call_row) = call.take() else {
                    return Ok(Err(RoomCallControlError::CallNotFound));
                };
                if call_row.state != "active" {
                    return Ok(Err(RoomCallControlError::CallNotActive));
                }

                let participant = tx
                    .query_row(
                        ROOM_CALL_PARTICIPANT_SELECT_BY_ID_SQL,
                        params![call_id.clone(), device_id.clone()],
                        map_room_call_participant_row,
                    )
                    .optional()?;
                let Some(control_participant) = participant else {
                    return Ok(Err(RoomCallControlError::ParticipantNotJoined));
                };
                if control_participant.profile_id != profile_id
                    || control_participant.room_id != room_id
                    || !room_call_participant_is_joined(&control_participant.join_state)
                {
                    return Ok(Err(RoomCallControlError::ParticipantNotJoined));
                }

                let existing_media_participant = tx
                    .query_row(
                        ROOM_CALL_MEDIA_PARTICIPANT_SELECT_BY_ID_SQL,
                        params![call_id.clone(), device_id.clone()],
                        map_room_call_media_participant_row,
                    )
                    .optional()?;
                let changed = match existing_media_participant.as_ref() {
                    Some(existing_media_participant) => {
                        existing_media_participant.room_id != room_id
                            || existing_media_participant.profile_id != profile_id
                            || existing_media_participant.publish_audio != publish_audio
                            || existing_media_participant.publish_video != publish_video
                            || existing_media_participant.publish_screen_share
                                != publish_screen_share
                            || existing_media_participant.subscribe_all != subscribe_all
                    }
                    None => true,
                };

                if changed {
                    let created_at_ms = existing_media_participant
                        .as_ref()
                        .map(|participant| participant.created_at_ms)
                        .unwrap_or(now_ms);
                    tx.execute(
                        "INSERT INTO room_call_media_participants(call_id, room_id, profile_id, device_id, publish_audio, publish_video, publish_screen_share, subscribe_all, created_at_ms, updated_at_ms) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10) ON CONFLICT(call_id, device_id) DO UPDATE SET room_id = excluded.room_id, profile_id = excluded.profile_id, publish_audio = excluded.publish_audio, publish_video = excluded.publish_video, publish_screen_share = excluded.publish_screen_share, subscribe_all = excluded.subscribe_all, created_at_ms = excluded.created_at_ms, updated_at_ms = excluded.updated_at_ms",
                        params![
                            call_id.clone(),
                            room_id.clone(),
                            profile_id.clone(),
                            device_id.clone(),
                            if publish_audio { 1 } else { 0 },
                            if publish_video { 1 } else { 0 },
                            if publish_screen_share { 1 } else { 0 },
                            if subscribe_all { 1 } else { 0 },
                            created_at_ms,
                            now_ms,
                        ],
                    )?;
                }

                let snapshot = load_room_call_snapshot(&tx, &room_id, call_row, Some(&device_id))?;
                tx.commit()?;
                Ok(Ok(snapshot))
            })
            .await
            .map_err(|e| RoomCallControlError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn summarize_room_call_media_health(
        &self,
    ) -> Result<RoomCallMediaHealthSummary, String> {
        self.conn
            .call(|c| -> Result<RoomCallMediaHealthSummary, rusqlite::Error> {
                let active_room_call_count: i64 = c.query_row(
                    "SELECT COUNT(*) FROM room_call_sessions WHERE state = 'active'",
                    [],
                    |row| row.get(0),
                )?;
                let joined_room_call_participant_count: i64 = c.query_row(
                    "SELECT COUNT(*)
                     FROM room_call_participants participant
                     INNER JOIN room_call_sessions call_session ON call_session.call_id = participant.call_id
                     WHERE call_session.state = 'active'
                       AND participant.join_state IN ('joined', 'reconnecting')",
                    [],
                    |row| row.get(0),
                )?;
                let registered_room_media_participant_count: i64 = c.query_row(
                    "SELECT COUNT(*)
                     FROM room_call_media_participants media_participant
                     INNER JOIN room_call_sessions call_session ON call_session.call_id = media_participant.call_id
                     INNER JOIN room_call_participants participant ON participant.call_id = media_participant.call_id AND participant.device_id = media_participant.device_id
                     WHERE call_session.state = 'active'
                       AND participant.join_state IN ('joined', 'reconnecting')",
                    [],
                    |row| row.get(0),
                )?;
                let fully_registered_room_call_count: i64 = c.query_row(
                    "SELECT COUNT(*)
                     FROM room_call_sessions call_session
                     WHERE call_session.state = 'active'
                       AND NOT EXISTS (
                         SELECT 1
                         FROM room_call_participants participant
                         WHERE participant.call_id = call_session.call_id
                           AND participant.join_state IN ('joined', 'reconnecting')
                           AND NOT EXISTS (
                             SELECT 1
                             FROM room_call_media_participants media_participant
                             WHERE media_participant.call_id = participant.call_id
                               AND media_participant.device_id = participant.device_id
                           )
                       )",
                    [],
                    |row| row.get(0),
                )?;
                Ok(RoomCallMediaHealthSummary {
                    active_room_call_count,
                    joined_room_call_participant_count,
                    registered_room_media_participant_count,
                    fully_registered_room_call_count,
                })
            })
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn create_or_join_room_call(
        &self,
        room_id: &str,
        profile_id: &str,
        device_id: &str,
        media_type: &str,
        supports_video: bool,
        supports_screen_share: bool,
        muted: bool,
        deafened: bool,
        video_enabled: bool,
        screen_share_enabled: bool,
        now_ms: i64,
    ) -> Result<RoomCallMutationResult, RoomCallControlError> {
        let room_id = room_id.to_string();
        let profile_id = profile_id.to_string();
        let device_id = device_id.to_string();
        let requested_media_type = normalize_room_call_media_type(media_type).to_string();
        let room_call_active_ttl_seconds = self.room_call_active_ttl_seconds;
        let room_call_terminal_ttl_seconds = self.call_session_terminal_ttl_seconds;
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<RoomCallMutationResult, RoomCallControlError>, rusqlite::Error> {
                let tx = c.transaction()?;

                let room_exists = tx
                    .query_row(
                        ROOM_SELECT_BY_ID_SQL,
                        params![room_id.clone()],
                        map_room_row,
                    )
                    .optional()?
                    .is_some();
                if !room_exists {
                    return Ok(Err(RoomCallControlError::RoomNotFound));
                }

                let membership = tx
                    .query_row(
                        ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                        params![room_id.clone(), profile_id.clone()],
                        map_room_membership_row,
                    )
                    .optional()?;
                let Some(membership) = membership else {
                    return Ok(Err(RoomCallControlError::NotActiveMember));
                };
                if membership.status != "active" {
                    return Ok(Err(RoomCallControlError::NotActiveMember));
                }

                let existing_active_call = tx
                    .query_row(
                        ROOM_CALL_ACTIVE_SELECT_BY_ROOM_SQL,
                        params![room_id.clone()],
                        map_room_call_row,
                    )
                    .optional()?;
                let created_new_call = existing_active_call.is_none();
                let wants_video = requested_media_type == "video" || video_enabled;
                let mut call = if let Some(active_call) = existing_active_call {
                    active_call
                } else {
                    let call_id = Uuid::now_v7().to_string();
                    let initial_media_type = if wants_video { "video" } else { "audio" };
                    let expires_at_ms = room_call_expires_at_ms(
                        "active",
                        now_ms,
                        room_call_active_ttl_seconds,
                        room_call_terminal_ttl_seconds,
                    );
                    tx.execute(
                        "INSERT INTO room_call_sessions(call_id, room_id, state, media_type, created_by_profile_id, created_by_device_id, state_version, started_at_ms, updated_at_ms, ended_at_ms, expires_at_ms) VALUES(?1, ?2, 'active', ?3, ?4, ?5, 1, ?6, ?6, NULL, ?7)",
                        params![
                            call_id.clone(),
                            room_id.clone(),
                            initial_media_type,
                            profile_id.clone(),
                            device_id.clone(),
                            now_ms,
                            expires_at_ms,
                        ],
                    )?;
                    tx.query_row(
                        ROOM_CALL_SELECT_BY_ID_SQL,
                        params![call_id],
                        map_room_call_row,
                    )?
                };

                let desired_call_media_type = if call.media_type == "video" || wants_video {
                    "video"
                } else {
                    "audio"
                };
                let desired_video_enabled = desired_call_media_type == "video"
                    && supports_video
                    && video_enabled;
                let desired_screen_share_enabled = supports_screen_share && screen_share_enabled;

                let existing_participant = tx
                    .query_row(
                        ROOM_CALL_PARTICIPANT_SELECT_BY_ID_SQL,
                        params![call.call_id.clone(), device_id.clone()],
                        map_room_call_participant_row,
                    )
                    .optional()?;

                let participant_changed = match existing_participant.as_ref() {
                    Some(existing_participant) => {
                        existing_participant.room_id != room_id
                            || existing_participant.profile_id != profile_id
                            || existing_participant.join_state != "joined"
                            || existing_participant.supports_video != supports_video
                            || existing_participant.supports_screen_share != supports_screen_share
                            || existing_participant.muted != muted
                            || existing_participant.deafened != deafened
                            || existing_participant.video_enabled != desired_video_enabled
                            || existing_participant.screen_share_enabled != desired_screen_share_enabled
                            || existing_participant.speaking
                            || existing_participant.left_at_ms.is_some()
                    }
                    None => true,
                };
                let call_metadata_changed = call.media_type != desired_call_media_type;
                let changed = created_new_call || participant_changed || call_metadata_changed;

                if participant_changed {
                    let joined_at_ms = existing_participant
                        .as_ref()
                        .map(|participant| participant.joined_at_ms)
                        .unwrap_or(now_ms);
                    tx.execute(
                        "INSERT INTO room_call_participants(call_id, room_id, profile_id, device_id, join_state, supports_video, supports_screen_share, muted, deafened, video_enabled, screen_share_enabled, speaking, joined_at_ms, left_at_ms, updated_at_ms) VALUES(?1, ?2, ?3, ?4, 'joined', ?5, ?6, ?7, ?8, ?9, ?10, 0, ?11, NULL, ?12) ON CONFLICT(call_id, device_id) DO UPDATE SET room_id = excluded.room_id, profile_id = excluded.profile_id, join_state = excluded.join_state, supports_video = excluded.supports_video, supports_screen_share = excluded.supports_screen_share, muted = excluded.muted, deafened = excluded.deafened, video_enabled = excluded.video_enabled, screen_share_enabled = excluded.screen_share_enabled, speaking = excluded.speaking, joined_at_ms = excluded.joined_at_ms, left_at_ms = excluded.left_at_ms, updated_at_ms = excluded.updated_at_ms",
                        params![
                            call.call_id.clone(),
                            room_id.clone(),
                            profile_id.clone(),
                            device_id.clone(),
                            if supports_video { 1 } else { 0 },
                            if supports_screen_share { 1 } else { 0 },
                            if muted { 1 } else { 0 },
                            if deafened { 1 } else { 0 },
                            if desired_video_enabled { 1 } else { 0 },
                            if desired_screen_share_enabled { 1 } else { 0 },
                            joined_at_ms,
                            now_ms,
                        ],
                    )?;
                }

                if !created_new_call && (participant_changed || call_metadata_changed) {
                    let next_state_version = call.state_version + 1;
                    let next_expires_at_ms = room_call_expires_at_ms(
                        "active",
                        now_ms,
                        room_call_active_ttl_seconds,
                        room_call_terminal_ttl_seconds,
                    );
                    tx.execute(
                        "UPDATE room_call_sessions SET media_type = ?2, state_version = ?3, updated_at_ms = ?4, expires_at_ms = ?5 WHERE call_id = ?1",
                        params![
                            call.call_id.clone(),
                            desired_call_media_type,
                            next_state_version,
                            now_ms,
                            next_expires_at_ms,
                        ],
                    )?;
                    call = tx.query_row(
                        ROOM_CALL_SELECT_BY_ID_SQL,
                        params![call.call_id.clone()],
                        map_room_call_row,
                    )?;
                }

                let snapshot = load_room_call_snapshot(&tx, &room_id, call, Some(&device_id))?;
                tx.commit()?;
                Ok(Ok(RoomCallMutationResult { changed, snapshot }))
            })
            .await
            .map_err(|e| RoomCallControlError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn update_room_call_participant_state(
        &self,
        room_id: &str,
        call_id: &str,
        profile_id: &str,
        device_id: &str,
        reconnecting: bool,
        muted: bool,
        deafened: bool,
        video_enabled: bool,
        screen_share_enabled: bool,
        speaking: bool,
        now_ms: i64,
    ) -> Result<RoomCallMutationResult, RoomCallControlError> {
        let room_id = room_id.to_string();
        let call_id = call_id.to_string();
        let profile_id = profile_id.to_string();
        let device_id = device_id.to_string();
        let room_call_active_ttl_seconds = self.room_call_active_ttl_seconds;
        let room_call_terminal_ttl_seconds = self.call_session_terminal_ttl_seconds;
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<RoomCallMutationResult, RoomCallControlError>, rusqlite::Error> {
                let tx = c.transaction()?;

                let room_exists = tx
                    .query_row(
                        ROOM_SELECT_BY_ID_SQL,
                        params![room_id.clone()],
                        map_room_row,
                    )
                    .optional()?
                    .is_some();
                if !room_exists {
                    return Ok(Err(RoomCallControlError::RoomNotFound));
                }

                let membership = tx
                    .query_row(
                        ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                        params![room_id.clone(), profile_id.clone()],
                        map_room_membership_row,
                    )
                    .optional()?;
                let Some(membership) = membership else {
                    return Ok(Err(RoomCallControlError::NotActiveMember));
                };
                if membership.status != "active" {
                    return Ok(Err(RoomCallControlError::NotActiveMember));
                }

                let mut call = tx
                    .query_row(
                        ROOM_CALL_SELECT_BY_ROOM_AND_ID_SQL,
                        params![room_id.clone(), call_id.clone()],
                        map_room_call_row,
                    )
                    .optional()?;
                let Some(mut call_row) = call.take() else {
                    return Ok(Err(RoomCallControlError::CallNotFound));
                };
                if call_row.state != "active" {
                    return Ok(Err(RoomCallControlError::CallNotActive));
                }

                let participant = tx
                    .query_row(
                        ROOM_CALL_PARTICIPANT_SELECT_BY_ID_SQL,
                        params![call_id.clone(), device_id.clone()],
                        map_room_call_participant_row,
                    )
                    .optional()?;
                let Some(existing_participant) = participant else {
                    return Ok(Err(RoomCallControlError::ParticipantNotJoined));
                };
                if existing_participant.profile_id != profile_id
                    || !room_call_participant_is_joined(&existing_participant.join_state)
                {
                    return Ok(Err(RoomCallControlError::ParticipantNotJoined));
                }

                let next_join_state = if reconnecting { "reconnecting" } else { "joined" };
                let wants_video = existing_participant.supports_video && video_enabled;
                let desired_call_media_type = if call_row.media_type == "video" || wants_video {
                    "video"
                } else {
                    "audio"
                };
                let desired_video_enabled = desired_call_media_type == "video" && wants_video;
                let desired_screen_share_enabled = existing_participant.supports_screen_share
                    && screen_share_enabled;
                let desired_speaking = normalize_room_call_participant_speaking(
                    next_join_state,
                    muted,
                    deafened,
                    speaking,
                );
                let changed = existing_participant.join_state != next_join_state
                    || existing_participant.muted != muted
                    || existing_participant.deafened != deafened
                    || existing_participant.video_enabled != desired_video_enabled
                    || existing_participant.screen_share_enabled != desired_screen_share_enabled
                    || existing_participant.speaking != desired_speaking;

                if changed {
                    tx.execute(
                        "UPDATE room_call_participants SET join_state = ?3, muted = ?4, deafened = ?5, video_enabled = ?6, screen_share_enabled = ?7, speaking = ?8, left_at_ms = NULL, updated_at_ms = ?9 WHERE call_id = ?1 AND device_id = ?2",
                        params![
                            call_id.clone(),
                            device_id.clone(),
                            next_join_state,
                            if muted { 1 } else { 0 },
                            if deafened { 1 } else { 0 },
                            if desired_video_enabled { 1 } else { 0 },
                            if desired_screen_share_enabled { 1 } else { 0 },
                            if desired_speaking { 1 } else { 0 },
                            now_ms,
                        ],
                    )?;

                    tx.execute(
                        "UPDATE room_call_sessions SET media_type = ?2, state_version = ?3, updated_at_ms = ?4, expires_at_ms = ?5 WHERE call_id = ?1",
                        params![
                            call_id.clone(),
                            desired_call_media_type,
                            call_row.state_version + 1,
                            now_ms,
                            room_call_expires_at_ms(
                                "active",
                                now_ms,
                                room_call_active_ttl_seconds,
                                room_call_terminal_ttl_seconds,
                            ),
                        ],
                    )?;
                    call_row = tx.query_row(
                        ROOM_CALL_SELECT_BY_ID_SQL,
                        params![call_id.clone()],
                        map_room_call_row,
                    )?;
                }

                let snapshot = load_room_call_snapshot(&tx, &room_id, call_row, Some(&device_id))?;
                tx.commit()?;
                Ok(Ok(RoomCallMutationResult { changed, snapshot }))
            })
            .await
            .map_err(|e| RoomCallControlError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn leave_room_call(
        &self,
        room_id: &str,
        call_id: &str,
        profile_id: &str,
        device_id: &str,
        now_ms: i64,
    ) -> Result<RoomCallMutationResult, RoomCallControlError> {
        let room_id = room_id.to_string();
        let call_id = call_id.to_string();
        let profile_id = profile_id.to_string();
        let device_id = device_id.to_string();
        let room_call_active_ttl_seconds = self.room_call_active_ttl_seconds;
        let room_call_terminal_ttl_seconds = self.call_session_terminal_ttl_seconds;
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<RoomCallMutationResult, RoomCallControlError>, rusqlite::Error> {
                let tx = c.transaction()?;

                let room_exists = tx
                    .query_row(
                        ROOM_SELECT_BY_ID_SQL,
                        params![room_id.clone()],
                        map_room_row,
                    )
                    .optional()?
                    .is_some();
                if !room_exists {
                    return Ok(Err(RoomCallControlError::RoomNotFound));
                }

                let mut call = tx
                    .query_row(
                        ROOM_CALL_SELECT_BY_ROOM_AND_ID_SQL,
                        params![room_id.clone(), call_id.clone()],
                        map_room_call_row,
                    )
                    .optional()?;
                let Some(mut call_row) = call.take() else {
                    return Ok(Err(RoomCallControlError::CallNotFound));
                };

                let participant = tx
                    .query_row(
                        ROOM_CALL_PARTICIPANT_SELECT_BY_ID_SQL,
                        params![call_id.clone(), device_id.clone()],
                        map_room_call_participant_row,
                    )
                    .optional()?;
                let Some(existing_participant) = participant else {
                    return Ok(Err(RoomCallControlError::ParticipantNotJoined));
                };
                if existing_participant.profile_id != profile_id {
                    return Ok(Err(RoomCallControlError::ParticipantNotJoined));
                }

                let already_left = !room_call_participant_is_joined(&existing_participant.join_state);
                if !already_left {
                    tx.execute(
                        "UPDATE room_call_participants SET join_state = 'left', muted = 0, deafened = 0, video_enabled = 0, screen_share_enabled = 0, speaking = 0, left_at_ms = ?3, updated_at_ms = ?3 WHERE call_id = ?1 AND device_id = ?2",
                        params![call_id.clone(), device_id.clone(), now_ms],
                    )?;
                    tx.execute(
                        "DELETE FROM room_call_media_participants WHERE call_id = ?1 AND device_id = ?2",
                        params![call_id.clone(), device_id.clone()],
                    )?;

                    let joined_participant_count: i64 = tx.query_row(
                        "SELECT COUNT(*) FROM room_call_participants WHERE call_id = ?1 AND join_state IN ('joined', 'reconnecting')",
                        params![call_id.clone()],
                        |row| row.get(0),
                    )?;
                    let (next_state, next_ended_at_ms, next_expires_at_ms) = if joined_participant_count == 0 {
                        (
                            "ended",
                            Some(now_ms),
                            room_call_expires_at_ms(
                                "ended",
                                now_ms,
                                room_call_active_ttl_seconds,
                                room_call_terminal_ttl_seconds,
                            ),
                        )
                    } else {
                        (
                            "active",
                            None,
                            room_call_expires_at_ms(
                                "active",
                                now_ms,
                                room_call_active_ttl_seconds,
                                room_call_terminal_ttl_seconds,
                            ),
                        )
                    };
                    tx.execute(
                        "UPDATE room_call_sessions SET state = ?2, state_version = ?3, updated_at_ms = ?4, ended_at_ms = ?5, expires_at_ms = ?6 WHERE call_id = ?1",
                        params![
                            call_id.clone(),
                            next_state,
                            call_row.state_version + 1,
                            now_ms,
                            next_ended_at_ms,
                            next_expires_at_ms,
                        ],
                    )?;
                    call_row = tx.query_row(
                        ROOM_CALL_SELECT_BY_ID_SQL,
                        params![call_id.clone()],
                        map_room_call_row,
                    )?;
                }

                let snapshot = load_room_call_snapshot(&tx, &room_id, call_row, Some(&device_id))?;
                tx.commit()?;
                Ok(Ok(RoomCallMutationResult {
                    changed: !already_left,
                    snapshot,
                }))
            })
            .await
            .map_err(|e| RoomCallControlError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn remove_room_call_participant(
        &self,
        room_id: &str,
        call_id: &str,
        target_profile_id: &str,
        target_device_id: &str,
        viewer_device_id: Option<&str>,
        now_ms: i64,
    ) -> Result<RoomCallMutationResult, RoomCallControlError> {
        let room_id = room_id.to_string();
        let call_id = call_id.to_string();
        let target_profile_id = target_profile_id.to_string();
        let target_device_id = target_device_id.to_string();
        let viewer_device_id = viewer_device_id.map(|value| value.to_string());
        let room_call_active_ttl_seconds = self.room_call_active_ttl_seconds;
        let room_call_terminal_ttl_seconds = self.call_session_terminal_ttl_seconds;
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<RoomCallMutationResult, RoomCallControlError>, rusqlite::Error> {
                let tx = c.transaction()?;

                let room_exists = tx
                    .query_row(
                        ROOM_SELECT_BY_ID_SQL,
                        params![room_id.clone()],
                        map_room_row,
                    )
                    .optional()?
                    .is_some();
                if !room_exists {
                    return Ok(Err(RoomCallControlError::RoomNotFound));
                }

                let mut call = tx
                    .query_row(
                        ROOM_CALL_SELECT_BY_ROOM_AND_ID_SQL,
                        params![room_id.clone(), call_id.clone()],
                        map_room_call_row,
                    )
                    .optional()?;
                let Some(mut call_row) = call.take() else {
                    return Ok(Err(RoomCallControlError::CallNotFound));
                };
                if call_row.state != "active" {
                    return Ok(Err(RoomCallControlError::CallNotActive));
                }

                let participant = tx
                    .query_row(
                        ROOM_CALL_PARTICIPANT_SELECT_BY_ID_SQL,
                        params![call_id.clone(), target_device_id.clone()],
                        map_room_call_participant_row,
                    )
                    .optional()?;
                let Some(existing_participant) = participant else {
                    return Ok(Err(RoomCallControlError::ParticipantNotJoined));
                };
                if existing_participant.profile_id != target_profile_id
                    || existing_participant.room_id != room_id
                {
                    return Ok(Err(RoomCallControlError::ParticipantNotJoined));
                }

                let already_left =
                    !room_call_participant_is_joined(&existing_participant.join_state);
                if !already_left {
                    tx.execute(
                        "UPDATE room_call_participants SET join_state = 'removed', muted = 0, deafened = 0, video_enabled = 0, screen_share_enabled = 0, speaking = 0, left_at_ms = ?3, updated_at_ms = ?3 WHERE call_id = ?1 AND device_id = ?2",
                        params![call_id.clone(), target_device_id.clone(), now_ms],
                    )?;
                    tx.execute(
                        "DELETE FROM room_call_media_participants WHERE call_id = ?1 AND device_id = ?2",
                        params![call_id.clone(), target_device_id.clone()],
                    )?;

                    let joined_participant_count: i64 = tx.query_row(
                        "SELECT COUNT(*) FROM room_call_participants WHERE call_id = ?1 AND join_state IN ('joined', 'reconnecting')",
                        params![call_id.clone()],
                        |row| row.get(0),
                    )?;
                    let (next_state, next_ended_at_ms, next_expires_at_ms) =
                        if joined_participant_count == 0 {
                            (
                                "ended",
                                Some(now_ms),
                                room_call_expires_at_ms(
                                    "ended",
                                    now_ms,
                                    room_call_active_ttl_seconds,
                                    room_call_terminal_ttl_seconds,
                                ),
                            )
                        } else {
                            (
                                "active",
                                None,
                                room_call_expires_at_ms(
                                    "active",
                                    now_ms,
                                    room_call_active_ttl_seconds,
                                    room_call_terminal_ttl_seconds,
                                ),
                            )
                        };
                    tx.execute(
                        "UPDATE room_call_sessions SET state = ?2, state_version = ?3, updated_at_ms = ?4, ended_at_ms = ?5, expires_at_ms = ?6 WHERE call_id = ?1",
                        params![
                            call_id.clone(),
                            next_state,
                            call_row.state_version + 1,
                            now_ms,
                            next_ended_at_ms,
                            next_expires_at_ms,
                        ],
                    )?;
                    call_row = tx.query_row(
                        ROOM_CALL_SELECT_BY_ID_SQL,
                        params![call_id.clone()],
                        map_room_call_row,
                    )?;
                }

                let snapshot = load_room_call_snapshot(
                    &tx,
                    &room_id,
                    call_row,
                    viewer_device_id.as_deref(),
                )?;
                tx.commit()?;
                Ok(Ok(RoomCallMutationResult {
                    changed: !already_left,
                    snapshot,
                }))
            })
            .await
            .map_err(|e| RoomCallControlError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn end_room_call(
        &self,
        room_id: &str,
        call_id: &str,
        viewer_device_id: Option<&str>,
        now_ms: i64,
    ) -> Result<RoomCallMutationResult, RoomCallControlError> {
        let room_id = room_id.to_string();
        let call_id = call_id.to_string();
        let viewer_device_id = viewer_device_id.map(|value| value.to_string());
        let room_call_active_ttl_seconds = self.room_call_active_ttl_seconds;
        let room_call_terminal_ttl_seconds = self.call_session_terminal_ttl_seconds;
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<RoomCallMutationResult, RoomCallControlError>, rusqlite::Error> {
                let tx = c.transaction()?;

                let room_exists = tx
                    .query_row(
                        ROOM_SELECT_BY_ID_SQL,
                        params![room_id.clone()],
                        map_room_row,
                    )
                    .optional()?
                    .is_some();
                if !room_exists {
                    return Ok(Err(RoomCallControlError::RoomNotFound));
                }

                let mut call = tx
                    .query_row(
                        ROOM_CALL_SELECT_BY_ROOM_AND_ID_SQL,
                        params![room_id.clone(), call_id.clone()],
                        map_room_call_row,
                    )
                    .optional()?;
                let Some(mut call_row) = call.take() else {
                    return Ok(Err(RoomCallControlError::CallNotFound));
                };

                if call_row.state == "ended" {
                    let snapshot = load_room_call_snapshot(
                        &tx,
                        &room_id,
                        call_row,
                        viewer_device_id.as_deref(),
                    )?;
                    tx.commit()?;
                    return Ok(Ok(RoomCallMutationResult {
                        changed: false,
                        snapshot,
                    }));
                }

                tx.execute(
                    "UPDATE room_call_participants SET join_state = 'left', muted = 0, deafened = 0, video_enabled = 0, screen_share_enabled = 0, speaking = 0, left_at_ms = COALESCE(left_at_ms, ?2), updated_at_ms = ?2 WHERE call_id = ?1 AND join_state IN ('joined', 'reconnecting')",
                    params![call_id.clone(), now_ms],
                )?;
                tx.execute(
                    "DELETE FROM room_call_media_participants WHERE call_id = ?1",
                    params![call_id.clone()],
                )?;
                tx.execute(
                    "UPDATE room_call_sessions SET state = 'ended', state_version = ?2, updated_at_ms = ?3, ended_at_ms = COALESCE(ended_at_ms, ?3), expires_at_ms = ?4 WHERE call_id = ?1",
                    params![
                        call_id.clone(),
                        call_row.state_version + 1,
                        now_ms,
                        room_call_expires_at_ms(
                            "ended",
                            now_ms,
                            room_call_active_ttl_seconds,
                            room_call_terminal_ttl_seconds,
                        ),
                    ],
                )?;
                call_row = tx.query_row(
                    ROOM_CALL_SELECT_BY_ID_SQL,
                    params![call_id.clone()],
                    map_room_call_row,
                )?;

                let snapshot = load_room_call_snapshot(
                    &tx,
                    &room_id,
                    call_row,
                    viewer_device_id.as_deref(),
                )?;
                tx.commit()?;
                Ok(Ok(RoomCallMutationResult {
                    changed: true,
                    snapshot,
                }))
            })
            .await
            .map_err(|e| RoomCallControlError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn update_room_profile(
        &self,
        room_id: &str,
        title: &str,
        description: Option<&str>,
        avatar_hash: Option<&str>,
        avatar_image_b64: Option<&str>,
        clear_avatar: bool,
        now_ms: i64,
    ) -> Result<UpdateRoomStateResult, UpdateRoomStateError> {
        let room_id = room_id.to_string();
        let title = title.to_string();
        let description = description
            .map(|value| value.trim())
            .filter(|value| !value.is_empty())
            .map(|value| value.to_string());
        let avatar_hash = avatar_hash
            .map(|value| value.trim())
            .filter(|value| !value.is_empty())
            .map(|value| value.to_string());
        let avatar_image_b64 = avatar_image_b64
            .map(|value| value.trim())
            .filter(|value| !value.is_empty())
            .map(|value| value.to_string());
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<UpdateRoomStateResult, UpdateRoomStateError>, rusqlite::Error> {
                let tx = c.transaction()?;
                let room = tx
                    .query_row(ROOM_SELECT_BY_ID_SQL, params![room_id.clone()], map_room_row)
                    .optional()?;
                let Some(room) = room else {
                    return Ok(Err(UpdateRoomStateError::RoomNotFound));
                };

                // Avatar tri-state:
                //   clear_avatar=true             -> set NULL
                //   else if new hash+b64 provided -> set new values
                //   else                          -> preserve existing (don't touch)
                let (next_avatar_hash, next_avatar_image_b64) = if clear_avatar {
                    (None, None)
                } else if avatar_hash.is_some() || avatar_image_b64.is_some() {
                    (avatar_hash.clone(), avatar_image_b64.clone())
                } else {
                    (room.avatar_hash.clone(), room.avatar_image_b64.clone())
                };

                let changed = room.title != title
                    || room.description != description
                    || room.avatar_hash != next_avatar_hash
                    || room.avatar_image_b64 != next_avatar_image_b64;
                if !changed {
                    tx.commit()?;
                    return Ok(Ok(UpdateRoomStateResult { changed: false, room }));
                }

                tx.execute(
                    "UPDATE rooms SET title = ?2, description = ?3, avatar_hash = ?4, avatar_image_b64 = ?5, version = ?6, updated_at_ms = ?7 WHERE room_id = ?1",
                    params![
                        room_id.clone(),
                        title,
                        description,
                        next_avatar_hash,
                        next_avatar_image_b64,
                        room.version + 1,
                        now_ms,
                    ],
                )?;

                let updated_room = tx.query_row(
                    ROOM_SELECT_BY_ID_SQL,
                    params![room_id],
                    map_room_row,
                )?;
                tx.commit()?;
                Ok(Ok(UpdateRoomStateResult {
                    changed: true,
                    room: updated_room,
                }))
            })
            .await
            .map_err(|e| UpdateRoomStateError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn update_room_settings(
        &self,
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
        now_ms: i64,
    ) -> Result<UpdateRoomStateResult, UpdateRoomStateError> {
        let room_id = room_id.to_string();
        let reactions_mode = normalize_room_reactions_mode(reactions_mode).to_string();
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<UpdateRoomStateResult, UpdateRoomStateError>, rusqlite::Error> {
                let tx = c.transaction()?;
                let room = tx
                    .query_row(ROOM_SELECT_BY_ID_SQL, params![room_id.clone()], map_room_row)
                    .optional()?;
                let Some(room) = room else {
                    return Ok(Err(UpdateRoomStateError::RoomNotFound));
                };

                let normalized_slow_mode_seconds = slow_mode_seconds.max(0);
                let changed = room.reactions_mode != reactions_mode
                    || room.allow_text != allow_text
                    || room.allow_media != allow_media
                    || room.allow_add_members != allow_add_members
                    || room.allow_pin_messages != allow_pin_messages
                    || room.allow_change_group_info != allow_change_group_info
                    || room.allow_change_tag != allow_change_tag
                    || room.join_approval_required != join_approval_required
                    || room.slow_mode_seconds != normalized_slow_mode_seconds
                    || room.chat_history_visible != chat_history_visible;
                if !changed {
                    tx.commit()?;
                    return Ok(Ok(UpdateRoomStateResult { changed: false, room }));
                }

                tx.execute(
                    "UPDATE rooms SET reactions_mode = ?2, allow_text = ?3, allow_media = ?4, allow_add_members = ?5, allow_pin_messages = ?6, allow_change_group_info = ?7, allow_change_tag = ?8, join_approval_required = ?9, slow_mode_seconds = ?10, chat_history_visible = ?11, version = ?12, updated_at_ms = ?13 WHERE room_id = ?1",
                    params![
                        room_id.clone(),
                        reactions_mode,
                        if allow_text { 1 } else { 0 },
                        if allow_media { 1 } else { 0 },
                        if allow_add_members { 1 } else { 0 },
                        if allow_pin_messages { 1 } else { 0 },
                        if allow_change_group_info { 1 } else { 0 },
                        if allow_change_tag { 1 } else { 0 },
                        if join_approval_required { 1 } else { 0 },
                        normalized_slow_mode_seconds,
                        if chat_history_visible { 1 } else { 0 },
                        room.version + 1,
                        now_ms,
                    ],
                )?;

                let updated_room = tx.query_row(
                    ROOM_SELECT_BY_ID_SQL,
                    params![room_id],
                    map_room_row,
                )?;
                tx.commit()?;
                Ok(Ok(UpdateRoomStateResult {
                    changed: true,
                    room: updated_room,
                }))
            })
            .await
            .map_err(|e| UpdateRoomStateError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn admit_room_message(
        &self,
        room_id: &str,
        profile_id: &str,
        message_id: &str,
        kind: &str,
        now_ms: i64,
    ) -> Result<RoomMessageAdmissionResult, AdmitRoomMessageError> {
        let room_id = room_id.to_string();
        let profile_id = profile_id.to_string();
        let message_id = message_id.to_string();
        let kind = kind.trim().to_ascii_lowercase();
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<RoomMessageAdmissionResult, AdmitRoomMessageError>, rusqlite::Error> {
                let tx = c.transaction()?;
                let room = tx
                    .query_row(ROOM_SELECT_BY_ID_SQL, params![room_id.clone()], map_room_row)
                    .optional()?;
                let Some(room) = room else {
                    return Ok(Err(AdmitRoomMessageError::RoomNotFound));
                };

                let membership = tx
                    .query_row(
                        ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                        params![room_id.clone(), profile_id.clone()],
                        map_room_membership_row,
                    )
                    .optional()?;
                let Some(membership) = membership else {
                    return Ok(Err(AdmitRoomMessageError::NotActiveMember));
                };
                if membership.status != "active" {
                    return Ok(Err(AdmitRoomMessageError::NotActiveMember));
                }

                let actor_role = if profile_id == room.owner_profile_id {
                    "owner".to_string()
                } else {
                    membership.role.trim().to_ascii_lowercase()
                };
                let can_bypass_posting_policy = matches!(
                    actor_role.as_str(),
                    "owner" | "admin" | "moderator"
                );
                let can_send_text = match actor_role.as_str() {
                    "owner" | "admin" | "moderator" => true,
                    "member" | "restricted" => room.allow_text,
                    "guest" => false,
                    _ => false,
                };
                let can_send_media = match actor_role.as_str() {
                    "owner" | "admin" | "moderator" => true,
                    "member" => room.allow_media,
                    "restricted" | "guest" => false,
                    _ => false,
                };

                match kind.as_str() {
                    "text" if !can_send_text => {
                        return Ok(Err(AdmitRoomMessageError::TextDisabled));
                    }
                    "media" if !can_send_media => {
                        return Ok(Err(AdmitRoomMessageError::MediaDisabled));
                    }
                    _ => {}
                }

                let posting_state = tx
                    .query_row(
                        "SELECT last_client_message_id, last_message_kind, last_admitted_at_ms, next_allowed_at_ms FROM room_posting_state WHERE room_id = ?1 AND profile_id = ?2",
                        params![room_id.clone(), profile_id.clone()],
                        |row| {
                            Ok((
                                row.get::<_, String>(0)?,
                                row.get::<_, String>(1)?,
                                row.get::<_, Option<i64>>(2)?,
                                row.get::<_, Option<i64>>(3)?,
                            ))
                        },
                    )
                    .optional()?;

                if let Some((last_message_id, last_message_kind, last_admitted_at_ms, next_allowed_at_ms)) = posting_state.clone() {
                    if last_message_id == message_id
                        && last_message_kind == kind
                        && last_admitted_at_ms.is_some()
                    {
                        tx.execute(
                            "INSERT OR IGNORE INTO room_message_index(room_id, message_id, admitted_by_profile_id, kind, admitted_at_ms) VALUES(?1, ?2, ?3, ?4, ?5)",
                            params![
                                room_id.clone(),
                                message_id.clone(),
                                profile_id.clone(),
                                kind.clone(),
                                last_admitted_at_ms.unwrap_or(now_ms),
                            ],
                        )?;
                        tx.commit()?;
                        return Ok(Ok(RoomMessageAdmissionResult {
                            room,
                            message_id,
                            kind,
                            admitted_at_ms: last_admitted_at_ms.unwrap_or(now_ms),
                            next_allowed_at_ms,
                        }));
                    }

                    if !can_bypass_posting_policy && room.slow_mode_seconds > 0 {
                        if let Some(next_allowed_at_ms) = next_allowed_at_ms {
                            if next_allowed_at_ms > now_ms {
                                let retry_after_seconds = ((next_allowed_at_ms - now_ms + 999) / 1000).max(1);
                                return Ok(Err(AdmitRoomMessageError::SlowModeActive {
                                    retry_after_seconds,
                                    next_allowed_at_ms,
                                }));
                            }
                        }
                    }
                }

                let next_allowed_at_ms = if can_bypass_posting_policy || room.slow_mode_seconds <= 0 {
                    None
                } else {
                    Some(now_ms + (room.slow_mode_seconds * 1000))
                };

                tx.execute(
                    "INSERT OR IGNORE INTO room_message_index(room_id, message_id, admitted_by_profile_id, kind, admitted_at_ms) VALUES(?1, ?2, ?3, ?4, ?5)",
                    params![
                        room_id.clone(),
                        message_id.clone(),
                        profile_id.clone(),
                        kind.clone(),
                        now_ms,
                    ],
                )?;

                tx.execute(
                    "INSERT INTO room_posting_state(room_id, profile_id, last_client_message_id, last_message_kind, last_admitted_at_ms, next_allowed_at_ms, updated_at_ms) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7) ON CONFLICT(room_id, profile_id) DO UPDATE SET last_client_message_id = excluded.last_client_message_id, last_message_kind = excluded.last_message_kind, last_admitted_at_ms = excluded.last_admitted_at_ms, next_allowed_at_ms = excluded.next_allowed_at_ms, updated_at_ms = excluded.updated_at_ms",
                    params![
                        room_id,
                        profile_id,
                        message_id.clone(),
                        kind.clone(),
                        now_ms,
                        next_allowed_at_ms,
                        now_ms,
                    ],
                )?;

                tx.commit()?;
                Ok(Ok(RoomMessageAdmissionResult {
                    room,
                    message_id,
                    kind,
                    admitted_at_ms: now_ms,
                    next_allowed_at_ms,
                }))
            })
            .await
            .map_err(|e| AdmitRoomMessageError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn set_room_pinned_message(
        &self,
        room_id: &str,
        pinned_message_id: Option<&str>,
        now_ms: i64,
    ) -> Result<UpdateRoomStateResult, SetRoomPinnedMessageError> {
        let room_id = room_id.to_string();
        let pinned_message_id = pinned_message_id
            .map(|value| value.trim())
            .filter(|value| !value.is_empty())
            .map(|value| value.to_string());
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<UpdateRoomStateResult, SetRoomPinnedMessageError>, rusqlite::Error> {
                let tx = c.transaction()?;
                let room = tx
                    .query_row(ROOM_SELECT_BY_ID_SQL, params![room_id.clone()], map_room_row)
                    .optional()?;
                let Some(room) = room else {
                    return Ok(Err(SetRoomPinnedMessageError::RoomNotFound));
                };

                if let Some(message_id) = pinned_message_id.as_deref() {
                    let exists = tx
                        .query_row(
                            "SELECT 1 FROM room_message_index WHERE room_id = ?1 AND message_id = ?2",
                            params![room_id.clone(), message_id],
                            |_row| Ok(()),
                        )
                        .optional()?
                        .is_some();
                    if !exists {
                        return Ok(Err(SetRoomPinnedMessageError::MessageNotFound));
                    }
                }

                let changed = room.pinned_message_id != pinned_message_id;
                if !changed {
                    tx.commit()?;
                    return Ok(Ok(UpdateRoomStateResult {
                        changed: false,
                        room,
                    }));
                }

                tx.execute(
                    "UPDATE rooms SET pinned_message_id = ?2, version = ?3, updated_at_ms = ?4 WHERE room_id = ?1",
                    params![
                        room_id.clone(),
                        pinned_message_id,
                        room.version + 1,
                        now_ms,
                    ],
                )?;

                let updated_room = tx.query_row(
                    ROOM_SELECT_BY_ID_SQL,
                    params![room_id],
                    map_room_row,
                )?;
                tx.commit()?;
                Ok(Ok(UpdateRoomStateResult {
                    changed: true,
                    room: updated_room,
                }))
            })
            .await
            .map_err(|e| SetRoomPinnedMessageError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn set_room_member_tag(
        &self,
        room_id: &str,
        profile_id: &str,
        tag: Option<&str>,
        now_ms: i64,
    ) -> Result<UpsertRoomMembershipResult, SetRoomMemberTagError> {
        let room_id = room_id.to_string();
        let profile_id = profile_id.to_string();
        let tag = tag
            .map(|value| value.trim())
            .filter(|value| !value.is_empty())
            .map(|value| value.to_string());
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<UpsertRoomMembershipResult, SetRoomMemberTagError>, rusqlite::Error> {
                let tx = c.transaction()?;
                let room = tx
                    .query_row(ROOM_SELECT_BY_ID_SQL, params![room_id.clone()], map_room_row)
                    .optional()?;
                let Some(room) = room else {
                    return Ok(Err(SetRoomMemberTagError::RoomNotFound));
                };

                let existing = tx
                    .query_row(
                        ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                        params![room_id.clone(), profile_id.clone()],
                        map_room_membership_row,
                    )
                    .optional()?;
                let Some(existing_membership) = existing else {
                    return Ok(Err(SetRoomMemberTagError::MembershipNotActive));
                };

                if existing_membership.status != "active" {
                    return Ok(Err(SetRoomMemberTagError::MembershipNotActive));
                }
                if existing_membership.tag == tag {
                    tx.commit()?;
                    return Ok(Ok(UpsertRoomMembershipResult {
                        changed: false,
                        room,
                        membership: existing_membership,
                    }));
                }

                tx.execute(
                    "UPDATE room_memberships SET tag = ?3, updated_at_ms = ?4 WHERE room_id = ?1 AND profile_id = ?2",
                    params![room_id.clone(), profile_id.clone(), tag, now_ms],
                )?;
                tx.execute(
                    "UPDATE rooms SET version = ?2, membership_version = ?3, updated_at_ms = ?4 WHERE room_id = ?1",
                    params![
                        room_id.clone(),
                        room.version + 1,
                        room.membership_version + 1,
                        now_ms,
                    ],
                )?;

                let updated_room = tx.query_row(
                    ROOM_SELECT_BY_ID_SQL,
                    params![room_id.clone()],
                    map_room_row,
                )?;
                let membership = tx.query_row(
                    ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                    params![room_id, profile_id],
                    map_room_membership_row,
                )?;

                tx.commit()?;
                Ok(Ok(UpsertRoomMembershipResult {
                    changed: true,
                    room: updated_room,
                    membership,
                }))
            })
            .await
            .map_err(|e| SetRoomMemberTagError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn leave_room(
        &self,
        room_id: &str,
        profile_id: &str,
        now_ms: i64,
    ) -> Result<UpsertRoomMembershipResult, LeaveRoomError> {
        let room_id = room_id.to_string();
        let profile_id = profile_id.to_string();
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<UpsertRoomMembershipResult, LeaveRoomError>, rusqlite::Error> {
                let tx = c.transaction()?;
                let room = tx
                    .query_row(ROOM_SELECT_BY_ID_SQL, params![room_id.clone()], map_room_row)
                    .optional()?;
                let Some(room) = room else {
                    return Ok(Err(LeaveRoomError::RoomNotFound));
                };

                let existing = tx
                    .query_row(
                        ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                        params![room_id.clone(), profile_id.clone()],
                        map_room_membership_row,
                    )
                    .optional()?;
                let Some(existing_membership) = existing.clone() else {
                    return Ok(Err(LeaveRoomError::MembershipNotActive));
                };

                if matches!(
                    existing_membership.status.as_str(),
                    "left" | "removed" | "banned"
                ) {
                    tx.commit()?;
                    return Ok(Ok(UpsertRoomMembershipResult {
                        changed: false,
                        room,
                        membership: existing_membership,
                    }));
                }
                if existing_membership.status != "active" {
                    return Ok(Err(LeaveRoomError::MembershipNotActive));
                }

                if room.owner_profile_id == profile_id {
                    let other_active_count: i64 = tx.query_row(
                        "SELECT COUNT(*) FROM room_memberships WHERE room_id = ?1 AND status = 'active' AND profile_id <> ?2",
                        params![room_id.clone(), profile_id.clone()],
                        |row| row.get(0),
                    )?;
                    if other_active_count > 0 {
                        return Ok(Err(LeaveRoomError::OwnerTransferRequired));
                    }

                    tx.execute(
                        "UPDATE room_memberships SET status = 'removed', role = 'member', updated_at_ms = ?2 WHERE room_id = ?1 AND status = 'pending'",
                        params![room_id.clone(), now_ms],
                    )?;
                    tx.execute(
                        "UPDATE room_invite_links SET is_revoked = 1, updated_at_ms = ?2 WHERE room_id = ?1 AND is_revoked = 0",
                        params![room_id.clone(), now_ms],
                    )?;
                }

                let next_created_at_ms =
                    next_membership_created_at(Some(&existing_membership), "left", now_ms);
                tx.execute(
                    "UPDATE room_memberships SET status = 'left', role = ?3, source_link_id = ?4, created_at_ms = ?5, updated_at_ms = ?6 WHERE room_id = ?1 AND profile_id = ?2",
                    params![
                        room_id.clone(),
                        profile_id.clone(),
                        existing_membership.role.clone(),
                        existing_membership.source_link_id.clone(),
                        next_created_at_ms,
                        now_ms,
                    ],
                )?;
                tx.execute(
                    "UPDATE rooms SET version = ?2, membership_version = ?3, updated_at_ms = ?4 WHERE room_id = ?1",
                    params![
                        room_id.clone(),
                        room.version + 1,
                        room.membership_version + 1,
                        now_ms,
                    ],
                )?;

                let updated_room = tx.query_row(
                    ROOM_SELECT_BY_ID_SQL,
                    params![room_id.clone()],
                    map_room_row,
                )?;
                let membership = tx.query_row(
                    ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                    params![room_id, profile_id],
                    map_room_membership_row,
                )?;
                tx.commit()?;
                Ok(Ok(UpsertRoomMembershipResult {
                    changed: true,
                    room: updated_room,
                    membership,
                }))
            })
            .await
            .map_err(|e| LeaveRoomError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn delete_room(
        &self,
        room_id: &str,
        requester_profile_id: &str,
    ) -> Result<DeleteRoomResult, DeleteRoomError> {
        let room_id = room_id.to_string();
        let requester_profile_id = requester_profile_id.to_string();
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<DeleteRoomResult, DeleteRoomError>, rusqlite::Error> {
                let tx = c.transaction()?;
                let room = tx
                    .query_row(ROOM_SELECT_BY_ID_SQL, params![room_id.clone()], map_room_row)
                    .optional()?;
                let Some(room) = room else {
                    return Ok(Err(DeleteRoomError::RoomNotFound));
                };

                if room.owner_profile_id != requester_profile_id {
                    return Ok(Err(DeleteRoomError::OwnerMismatch));
                }

                let deleted_profile_ids = {
                    let mut stmt = tx.prepare(
                        "SELECT profile_id FROM room_memberships WHERE room_id = ?1 AND profile_id <> ?2 ORDER BY profile_id ASC",
                    )?;
                    stmt.query_map(
                        params![room_id.clone(), requester_profile_id.clone()],
                        |row| row.get::<_, String>(0),
                    )?
                    .collect::<Result<Vec<_>, _>>()?
                };

                tx.execute(
                    "DELETE FROM room_call_media_participants WHERE room_id = ?1",
                    params![room_id.clone()],
                )?;
                tx.execute(
                    "DELETE FROM room_call_participants WHERE room_id = ?1",
                    params![room_id.clone()],
                )?;
                tx.execute(
                    "DELETE FROM room_call_sessions WHERE room_id = ?1",
                    params![room_id.clone()],
                )?;
                tx.execute(
                    "DELETE FROM room_message_index WHERE room_id = ?1",
                    params![room_id.clone()],
                )?;
                tx.execute(
                    "DELETE FROM room_invite_links WHERE room_id = ?1",
                    params![room_id.clone()],
                )?;
                tx.execute(
                    "DELETE FROM room_memberships WHERE room_id = ?1",
                    params![room_id.clone()],
                )?;
                tx.execute("DELETE FROM rooms WHERE room_id = ?1", params![room_id])?;
                tx.commit()?;
                Ok(Ok(DeleteRoomResult {
                    room,
                    deleted_profile_ids,
                }))
            })
            .await
            .map_err(|e| DeleteRoomError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn delete_profile_data(
        &self,
        profile_id: &str,
        device_ids: &[String],
    ) -> Result<DeleteProfileDataResult, String> {
        let profile_id = profile_id.to_string();
        let mut device_ids = device_ids
            .iter()
            .map(|device_id| device_id.trim().to_string())
            .filter(|device_id| !device_id.is_empty())
            .collect::<Vec<_>>();
        device_ids.sort();
        device_ids.dedup();

        let result = self
            .conn
            .call(move |c| -> Result<DeleteProfileDataResult, rusqlite::Error> {
                let tx = c.transaction()?;

                let mut deleted_blob_paths = Vec::<String>::new();
                {
                    let mut stmt = tx.prepare(
                        "SELECT rel_path FROM blobs WHERE owner_profile_id = ?1 ORDER BY rel_path ASC",
                    )?;
                    let rows = stmt.query_map(params![profile_id.clone()], |row| {
                        row.get::<_, String>(0)
                    })?;
                    for row in rows {
                        deleted_blob_paths.push(row?);
                    }
                }
                for device_id in &device_ids {
                    let mut stmt = tx.prepare(
                        "SELECT rel_path FROM blobs WHERE owner_device_id = ?1 ORDER BY rel_path ASC",
                    )?;
                    let rows = stmt.query_map(params![device_id], |row| row.get::<_, String>(0))?;
                    for row in rows {
                        deleted_blob_paths.push(row?);
                    }
                }
                deleted_blob_paths.sort();
                deleted_blob_paths.dedup();

                let mut affected_call_ids = Vec::<String>::new();
                {
                    let mut stmt = tx.prepare(
                        "SELECT call_id FROM room_call_sessions WHERE created_by_profile_id = ?1 OR room_id IN (SELECT room_id FROM rooms WHERE owner_profile_id = ?1)
                         UNION SELECT call_id FROM room_call_participants WHERE profile_id = ?1
                         UNION SELECT call_id FROM room_call_media_participants WHERE profile_id = ?1",
                    )?;
                    let rows = stmt.query_map(params![profile_id.clone()], |row| {
                        row.get::<_, String>(0)
                    })?;
                    for row in rows {
                        affected_call_ids.push(row?);
                    }
                }
                for device_id in &device_ids {
                    let mut stmt = tx.prepare(
                        "SELECT call_id FROM call_sessions WHERE participant_device_id = ?1 OR peer_device_id = ?1
                         UNION SELECT call_id FROM room_call_sessions WHERE created_by_device_id = ?1
                         UNION SELECT call_id FROM room_call_participants WHERE device_id = ?1
                         UNION SELECT call_id FROM room_call_media_participants WHERE device_id = ?1",
                    )?;
                    let rows = stmt.query_map(params![device_id], |row| row.get::<_, String>(0))?;
                    for row in rows {
                        affected_call_ids.push(row?);
                    }
                }
                affected_call_ids.sort();
                affected_call_ids.dedup();

                let mut deleted_rows = 0usize;
                for call_id in &affected_call_ids {
                    deleted_rows += tx.execute(
                        "DELETE FROM call_signal_dedup WHERE call_id = ?1",
                        params![call_id],
                    )?;
                }

                deleted_rows += tx.execute(
                    "DELETE FROM room_call_media_participants WHERE room_id IN (SELECT room_id FROM rooms WHERE owner_profile_id = ?1) OR profile_id = ?1",
                    params![profile_id.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM room_call_participants WHERE room_id IN (SELECT room_id FROM rooms WHERE owner_profile_id = ?1) OR profile_id = ?1",
                    params![profile_id.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM room_call_sessions WHERE room_id IN (SELECT room_id FROM rooms WHERE owner_profile_id = ?1) OR created_by_profile_id = ?1",
                    params![profile_id.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM room_message_index WHERE room_id IN (SELECT room_id FROM rooms WHERE owner_profile_id = ?1) OR admitted_by_profile_id = ?1",
                    params![profile_id.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM room_invite_links WHERE room_id IN (SELECT room_id FROM rooms WHERE owner_profile_id = ?1) OR created_by_profile_id = ?1",
                    params![profile_id.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM room_posting_state WHERE room_id IN (SELECT room_id FROM rooms WHERE owner_profile_id = ?1) OR profile_id = ?1",
                    params![profile_id.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM room_memberships WHERE room_id IN (SELECT room_id FROM rooms WHERE owner_profile_id = ?1) OR profile_id = ?1",
                    params![profile_id.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM rooms WHERE owner_profile_id = ?1",
                    params![profile_id.clone()],
                )?;

                deleted_rows += tx.execute(
                    "DELETE FROM blobs WHERE owner_profile_id = ?1",
                    params![profile_id.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM blocks WHERE profile_id = ?1 OR blocked_profile_id = ?1",
                    params![profile_id.clone()],
                )?;

                for device_id in &device_ids {
                    deleted_rows += tx.execute(
                        "DELETE FROM device_state WHERE device_id = ?1",
                        params![device_id],
                    )?;
                    deleted_rows += tx.execute(
                        "DELETE FROM pending WHERE device_id = ?1",
                        params![device_id],
                    )?;
                    deleted_rows += tx.execute(
                        "DELETE FROM message_dedup WHERE device_id = ?1",
                        params![device_id],
                    )?;
                    deleted_rows += tx.execute(
                        "DELETE FROM push_tokens WHERE device_id = ?1",
                        params![device_id],
                    )?;
                    deleted_rows += tx.execute(
                        "DELETE FROM push_wake_dedup WHERE device_id = ?1",
                        params![device_id],
                    )?;
                    deleted_rows += tx.execute(
                        "DELETE FROM call_sessions WHERE participant_device_id = ?1 OR peer_device_id = ?1",
                        params![device_id],
                    )?;
                    deleted_rows += tx.execute(
                        "DELETE FROM room_call_media_participants WHERE device_id = ?1",
                        params![device_id],
                    )?;
                    deleted_rows += tx.execute(
                        "DELETE FROM room_call_participants WHERE device_id = ?1",
                        params![device_id],
                    )?;
                    deleted_rows += tx.execute(
                        "DELETE FROM room_call_sessions WHERE created_by_device_id = ?1",
                        params![device_id],
                    )?;
                    deleted_rows += tx.execute(
                        "DELETE FROM blobs WHERE owner_device_id = ?1",
                        params![device_id],
                    )?;
                }

                tx.commit()?;
                Ok(DeleteProfileDataResult {
                    deleted_rows: deleted_rows as i64,
                    deleted_blob_paths,
                })
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(result)
    }

    pub async fn unban_room_membership(
        &self,
        room_id: &str,
        profile_id: &str,
        now_ms: i64,
    ) -> Result<UpsertRoomMembershipResult, UnbanRoomMembershipError> {
        let room_id = room_id.to_string();
        let profile_id = profile_id.to_string();
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<UpsertRoomMembershipResult, UnbanRoomMembershipError>, rusqlite::Error> {
                let tx = c.transaction()?;
                let room = tx
                    .query_row(ROOM_SELECT_BY_ID_SQL, params![room_id.clone()], map_room_row)
                    .optional()?;
                let Some(room) = room else {
                    return Ok(Err(UnbanRoomMembershipError::RoomNotFound));
                };

                let existing = tx
                    .query_row(
                        ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                        params![room_id.clone(), profile_id.clone()],
                        map_room_membership_row,
                    )
                    .optional()?;
                let Some(existing_membership) = existing else {
                    return Ok(Err(UnbanRoomMembershipError::MembershipNotBanned));
                };

                if existing_membership.status == "removed" {
                    tx.commit()?;
                    return Ok(Ok(UpsertRoomMembershipResult {
                        changed: false,
                        room,
                        membership: existing_membership,
                    }));
                }
                if existing_membership.status != "banned" {
                    return Ok(Err(UnbanRoomMembershipError::MembershipNotBanned));
                }

                let next_created_at_ms =
                    next_membership_created_at(Some(&existing_membership), "removed", now_ms);
                tx.execute(
                    "UPDATE room_memberships SET status = 'removed', role = 'member', source_link_id = ?3, created_at_ms = ?4, updated_at_ms = ?5 WHERE room_id = ?1 AND profile_id = ?2",
                    params![
                        room_id.clone(),
                        profile_id.clone(),
                        existing_membership.source_link_id.clone(),
                        next_created_at_ms,
                        now_ms,
                    ],
                )?;
                tx.execute(
                    "UPDATE rooms SET version = ?2, membership_version = ?3, updated_at_ms = ?4 WHERE room_id = ?1",
                    params![
                        room_id.clone(),
                        room.version + 1,
                        room.membership_version + 1,
                        now_ms,
                    ],
                )?;

                let updated_room = tx.query_row(
                    ROOM_SELECT_BY_ID_SQL,
                    params![room_id.clone()],
                    map_room_row,
                )?;
                let membership = tx.query_row(
                    ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                    params![room_id, profile_id],
                    map_room_membership_row,
                )?;
                tx.commit()?;
                Ok(Ok(UpsertRoomMembershipResult {
                    changed: true,
                    room: updated_room,
                    membership,
                }))
            })
            .await
            .map_err(|e| UnbanRoomMembershipError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn create_room_invite_link(
        &self,
        room_id: &str,
        link_id: &str,
        slug: &str,
        created_by_profile_id: &str,
        expires_at_ms: Option<i64>,
        max_uses: Option<i64>,
        requires_approval: bool,
        allowed_role: &str,
        now_ms: i64,
    ) -> Result<CreateRoomInviteLinkResult, CreateRoomInviteLinkError> {
        let room_id = room_id.to_string();
        let link_id = link_id.to_string();
        let slug = slug.to_string();
        let created_by_profile_id = created_by_profile_id.to_string();
        let allowed_role = normalize_invite_allowed_role(allowed_role).to_string();
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<CreateRoomInviteLinkResult, CreateRoomInviteLinkError>, rusqlite::Error> {
                let tx = c.transaction()?;
                let room = tx
                    .query_row(
                        ROOM_SELECT_BY_ID_SQL,
                        params![room_id.clone()],
                        map_room_row,
                    )
                    .optional()?;
                let Some(room) = room else {
                    return Ok(Err(CreateRoomInviteLinkError::RoomNotFound));
                };

                tx.execute(
                    "INSERT INTO room_invite_links(link_id, room_id, slug, created_by_profile_id, expires_at_ms, max_uses, use_count, requires_approval, allowed_role, is_revoked, created_at_ms, updated_at_ms) VALUES(?1, ?2, ?3, ?4, ?5, ?6, 0, ?7, ?8, 0, ?9, ?9)",
                    params![
                        link_id.clone(),
                        room_id.clone(),
                        slug,
                        created_by_profile_id,
                        expires_at_ms,
                        max_uses,
                        if requires_approval { 1 } else { 0 },
                        allowed_role,
                        now_ms,
                    ],
                )?;
                tx.execute(
                    "UPDATE rooms SET version = ?2, updated_at_ms = ?3 WHERE room_id = ?1",
                    params![room_id.clone(), room.version + 1, now_ms],
                )?;

                let updated_room = tx.query_row(
                    ROOM_SELECT_BY_ID_SQL,
                    params![room_id.clone()],
                    map_room_row,
                )?;
                let invite_link = tx.query_row(
                    "SELECT link_id, room_id, slug, created_by_profile_id, expires_at_ms, max_uses, use_count, requires_approval, allowed_role, is_revoked, created_at_ms, updated_at_ms FROM room_invite_links WHERE link_id = ?1",
                    params![link_id],
                    map_room_invite_link_row,
                )?;

                tx.commit()?;

                Ok(Ok(CreateRoomInviteLinkResult {
                    room: updated_room,
                    invite_link,
                }))
            })
            .await
            .map_err(|e| CreateRoomInviteLinkError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn set_room_invite_link_revoked(
        &self,
        room_id: &str,
        link_id: &str,
        revoked: bool,
        now_ms: i64,
    ) -> Result<SetRoomInviteLinkRevokedResult, SetRoomInviteLinkRevokedError> {
        let room_id = room_id.to_string();
        let link_id = link_id.to_string();
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<SetRoomInviteLinkRevokedResult, SetRoomInviteLinkRevokedError>, rusqlite::Error> {
                let tx = c.transaction()?;
                let room = tx
                    .query_row(
                        ROOM_SELECT_BY_ID_SQL,
                        params![room_id.clone()],
                        map_room_row,
                    )
                    .optional()?;
                let Some(room) = room else {
                    return Ok(Err(SetRoomInviteLinkRevokedError::RoomNotFound));
                };
                let invite_link = tx
                    .query_row(
                        "SELECT link_id, room_id, slug, created_by_profile_id, expires_at_ms, max_uses, use_count, requires_approval, allowed_role, is_revoked, created_at_ms, updated_at_ms FROM room_invite_links WHERE room_id = ?1 AND link_id = ?2",
                        params![room_id.clone(), link_id.clone()],
                        map_room_invite_link_row,
                    )
                    .optional()?;
                let Some(invite_link) = invite_link else {
                    return Ok(Err(SetRoomInviteLinkRevokedError::InviteNotFound));
                };

                if invite_link.revoked == revoked {
                    tx.commit()?;
                    return Ok(Ok(SetRoomInviteLinkRevokedResult {
                        changed: false,
                        room,
                        invite_link,
                    }));
                }

                tx.execute(
                    "UPDATE room_invite_links SET is_revoked = ?3, updated_at_ms = ?4 WHERE room_id = ?1 AND link_id = ?2",
                    params![
                        room_id.clone(),
                        link_id.clone(),
                        if revoked { 1 } else { 0 },
                        now_ms,
                    ],
                )?;
                tx.execute(
                    "UPDATE rooms SET version = ?2, updated_at_ms = ?3 WHERE room_id = ?1",
                    params![room_id.clone(), room.version + 1, now_ms],
                )?;

                let updated_room = tx.query_row(
                    ROOM_SELECT_BY_ID_SQL,
                    params![room_id.clone()],
                    map_room_row,
                )?;
                let updated_invite_link = tx.query_row(
                    "SELECT link_id, room_id, slug, created_by_profile_id, expires_at_ms, max_uses, use_count, requires_approval, allowed_role, is_revoked, created_at_ms, updated_at_ms FROM room_invite_links WHERE room_id = ?1 AND link_id = ?2",
                    params![room_id, link_id],
                    map_room_invite_link_row,
                )?;

                tx.commit()?;

                Ok(Ok(SetRoomInviteLinkRevokedResult {
                    changed: true,
                    room: updated_room,
                    invite_link: updated_invite_link,
                }))
            })
            .await
            .map_err(|e| SetRoomInviteLinkRevokedError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn upsert_room_membership(
        &self,
        room_id: &str,
        profile_id: &str,
        status: &str,
        role: &str,
        source_link_id: Option<&str>,
        now_ms: i64,
    ) -> Result<UpsertRoomMembershipResult, UpsertRoomMembershipError> {
        let room_id = room_id.to_string();
        let profile_id = profile_id.to_string();
        let status = status.to_string();
        let role = role.to_string();
        let source_link_id = source_link_id
            .map(|value| value.trim())
            .filter(|value| !value.is_empty())
            .map(|value| value.to_string());
        let outcome = self
            .conn
            .call(
                move |c| -> Result<Result<UpsertRoomMembershipResult, UpsertRoomMembershipError>, rusqlite::Error> {
                    let tx = c.transaction()?;
                    let room = tx
                        .query_row(
                            ROOM_SELECT_BY_ID_SQL,
                            params![room_id.clone()],
                            map_room_row,
                        )
                        .optional()?;
                    let Some(room) = room else {
                        return Ok(Err(UpsertRoomMembershipError::RoomNotFound));
                    };

                    if profile_id == room.owner_profile_id {
                        if status != "active" || role != "owner" || source_link_id.is_some() {
                            return Ok(Err(UpsertRoomMembershipError::InvalidOwnerMutation));
                        }
                    } else if role == "owner" {
                        return Ok(Err(UpsertRoomMembershipError::InvalidOwnerMutation));
                    }

                    let existing = tx
                        .query_row(
                            ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                            params![room_id.clone(), profile_id.clone()],
                            map_room_membership_row,
                        )
                        .optional()?;

                    if let Some(existing_membership) = existing.clone() {
                        if existing_membership.status == status
                            && existing_membership.role == role
                            && existing_membership.source_link_id == source_link_id
                        {
                            tx.commit()?;
                            return Ok(Ok(UpsertRoomMembershipResult {
                                changed: false,
                                room,
                                membership: existing_membership,
                            }));
                        }

                        if existing_membership.status == "left" && status == "removed" {
                            tx.commit()?;
                            return Ok(Ok(UpsertRoomMembershipResult {
                                changed: false,
                                room,
                                membership: existing_membership,
                            }));
                        }

                        if existing_membership.status == "banned" && status == "removed" {
                            tx.commit()?;
                            return Ok(Ok(UpsertRoomMembershipResult {
                                changed: false,
                                room,
                                membership: existing_membership,
                            }));
                        }
                    }

                    let next_created_at_ms =
                        next_membership_created_at(existing.as_ref(), &status, now_ms);

                    tx.execute(
                        "INSERT INTO room_memberships(room_id, profile_id, status, role, source_link_id, created_at_ms, updated_at_ms) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7) ON CONFLICT(room_id, profile_id) DO UPDATE SET status = excluded.status, role = excluded.role, source_link_id = excluded.source_link_id, created_at_ms = excluded.created_at_ms, updated_at_ms = excluded.updated_at_ms",
                        params![
                            room_id.clone(),
                            profile_id.clone(),
                            status,
                            role,
                            source_link_id,
                            next_created_at_ms,
                            now_ms,
                        ],
                    )?;

                    tx.execute(
                        "UPDATE rooms SET version = ?2, membership_version = ?3, updated_at_ms = ?4 WHERE room_id = ?1",
                        params![
                            room_id.clone(),
                            room.version + 1,
                            room.membership_version + 1,
                            now_ms,
                        ],
                    )?;

                    let updated_room = tx.query_row(
                        ROOM_SELECT_BY_ID_SQL,
                        params![room_id.clone()],
                        map_room_row,
                    )?;
                    let membership = tx.query_row(
                        ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                        params![room_id, profile_id],
                        map_room_membership_row,
                    )?;

                    tx.commit()?;

                    Ok(Ok(UpsertRoomMembershipResult {
                        changed: true,
                        room: updated_room,
                        membership,
                    }))
                },
            )
            .await
            .map_err(|e| UpsertRoomMembershipError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn transfer_room_ownership(
        &self,
        room_id: &str,
        current_owner_profile_id: &str,
        next_owner_profile_id: &str,
        now_ms: i64,
    ) -> Result<TransferRoomOwnershipResult, TransferRoomOwnershipError> {
        let room_id = room_id.to_string();
        let current_owner_profile_id = current_owner_profile_id.to_string();
        let next_owner_profile_id = next_owner_profile_id.to_string();
        let outcome = self
            .conn
            .call(
                move |c| -> Result<Result<TransferRoomOwnershipResult, TransferRoomOwnershipError>, rusqlite::Error> {
                    let tx = c.transaction()?;
                    let room = tx
                        .query_row(
                            ROOM_SELECT_BY_ID_SQL,
                            params![room_id.clone()],
                            map_room_row,
                        )
                        .optional()?;
                    let Some(room) = room else {
                        return Ok(Err(TransferRoomOwnershipError::RoomNotFound));
                    };

                    if next_owner_profile_id == current_owner_profile_id {
                        return Ok(Err(TransferRoomOwnershipError::InvalidNextOwner));
                    }

                    let current_owner_membership = tx
                        .query_row(
                            ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                            params![room_id.clone(), current_owner_profile_id.clone()],
                            map_room_membership_row,
                        )
                        .optional()?;
                    let next_owner_membership = tx
                        .query_row(
                            ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                            params![room_id.clone(), next_owner_profile_id.clone()],
                            map_room_membership_row,
                        )
                        .optional()?;

                    if room.owner_profile_id != current_owner_profile_id {
                        if room.owner_profile_id == next_owner_profile_id {
                            if let (
                                Some(previous_owner_membership),
                                Some(promoted_owner_membership),
                            ) = (
                                current_owner_membership.clone(),
                                next_owner_membership.clone(),
                            ) {
                                if previous_owner_membership.status == "active"
                                    && previous_owner_membership.role == "admin"
                                    && previous_owner_membership.updated_at_ms
                                        == room.updated_at_ms
                                    && promoted_owner_membership.status == "active"
                                    && promoted_owner_membership.role == "owner"
                                    && promoted_owner_membership.updated_at_ms
                                        == room.updated_at_ms
                                {
                                    tx.commit()?;
                                    return Ok(Ok(TransferRoomOwnershipResult {
                                        room,
                                        previous_owner_membership,
                                        next_owner_membership:
                                            promoted_owner_membership,
                                    }));
                                }
                            }
                        }
                        return Ok(Err(TransferRoomOwnershipError::OwnerMismatch));
                    }

                    let Some(next_owner_membership) = next_owner_membership else {
                        return Ok(Err(TransferRoomOwnershipError::NextOwnerNotActive));
                    };
                    if next_owner_membership.status != "active" {
                        return Ok(Err(TransferRoomOwnershipError::NextOwnerNotActive));
                    }

                    let previous_owner_created_at_ms = current_owner_membership
                        .as_ref()
                        .map(|membership| membership.created_at_ms)
                        .unwrap_or(room.created_at_ms);
                    let previous_owner_source_link_id = current_owner_membership
                        .as_ref()
                        .and_then(|membership| membership.source_link_id.clone());

                    tx.execute(
                        "INSERT INTO room_memberships(room_id, profile_id, status, role, source_link_id, created_at_ms, updated_at_ms) VALUES(?1, ?2, 'active', 'admin', ?3, ?4, ?5) ON CONFLICT(room_id, profile_id) DO UPDATE SET status = 'active', role = 'admin', source_link_id = excluded.source_link_id, created_at_ms = excluded.created_at_ms, updated_at_ms = excluded.updated_at_ms",
                        params![
                            room_id.clone(),
                            current_owner_profile_id.clone(),
                            previous_owner_source_link_id,
                            previous_owner_created_at_ms,
                            now_ms,
                        ],
                    )?;
                    tx.execute(
                        "INSERT INTO room_memberships(room_id, profile_id, status, role, source_link_id, created_at_ms, updated_at_ms) VALUES(?1, ?2, 'active', 'owner', ?3, ?4, ?5) ON CONFLICT(room_id, profile_id) DO UPDATE SET status = 'active', role = 'owner', source_link_id = excluded.source_link_id, created_at_ms = excluded.created_at_ms, updated_at_ms = excluded.updated_at_ms",
                        params![
                            room_id.clone(),
                            next_owner_profile_id.clone(),
                            next_owner_membership.source_link_id.clone(),
                            next_owner_membership.created_at_ms,
                            now_ms,
                        ],
                    )?;
                    tx.execute(
                        "UPDATE rooms SET owner_profile_id = ?2, version = ?3, membership_version = ?4, updated_at_ms = ?5 WHERE room_id = ?1",
                        params![
                            room_id.clone(),
                            next_owner_profile_id.clone(),
                            room.version + 1,
                            room.membership_version + 1,
                            now_ms,
                        ],
                    )?;

                    let updated_room = tx.query_row(
                        ROOM_SELECT_BY_ID_SQL,
                        params![room_id.clone()],
                        map_room_row,
                    )?;
                    let updated_previous_owner_membership = tx.query_row(
                        ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                        params![room_id.clone(), current_owner_profile_id],
                        map_room_membership_row,
                    )?;
                    let updated_next_owner_membership = tx.query_row(
                        ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                        params![room_id, next_owner_profile_id],
                        map_room_membership_row,
                    )?;

                    tx.commit()?;

                    Ok(Ok(TransferRoomOwnershipResult {
                        room: updated_room,
                        previous_owner_membership: updated_previous_owner_membership,
                        next_owner_membership: updated_next_owner_membership,
                    }))
                },
            )
            .await
            .map_err(|e| TransferRoomOwnershipError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn redeem_room_invite(
        &self,
        slug: &str,
        profile_id: &str,
        now_ms: i64,
    ) -> Result<RedeemRoomInviteResult, RedeemRoomInviteError> {
        let slug = slug.to_string();
        let profile_id = profile_id.to_string();
        let outcome = self
            .conn
            .call(move |c| -> Result<Result<RedeemRoomInviteResult, RedeemRoomInviteError>, rusqlite::Error> {
                let tx = c.transaction()?;
                let invite_link = tx
                    .query_row(
                        "SELECT link_id, room_id, slug, created_by_profile_id, expires_at_ms, max_uses, use_count, requires_approval, allowed_role, is_revoked, created_at_ms, updated_at_ms FROM room_invite_links WHERE slug = ?1",
                        params![slug],
                        map_room_invite_link_row,
                    )
                    .optional()?;
                let Some(invite_link) = invite_link else {
                    return Ok(Err(RedeemRoomInviteError::InviteNotFound));
                };
                let room = tx
                    .query_row(
                        ROOM_SELECT_BY_ID_SQL,
                        params![invite_link.room_id.clone()],
                        map_room_row,
                    )
                    .optional()?;
                let Some(room) = room else {
                    return Ok(Err(RedeemRoomInviteError::RoomNotFound));
                };
                let existing_membership = tx
                    .query_row(
                        ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                        params![room.room_id.clone(), profile_id.clone()],
                        map_room_membership_row,
                    )
                    .optional()?;

                if let Some(existing_membership) = existing_membership.clone() {
                    if existing_membership.status == "banned" {
                        return Ok(Err(RedeemRoomInviteError::Banned));
                    }
                    if existing_membership.status == "active" || existing_membership.status == "pending" {
                        tx.commit()?;
                        return Ok(Ok(RedeemRoomInviteResult {
                            changed: false,
                            room,
                            invite_link,
                            membership: existing_membership,
                        }));
                    }
                }

                if invite_link.revoked {
                    return Ok(Err(RedeemRoomInviteError::InviteRevoked));
                }
                if let Some(expires_at_ms) = invite_link.expires_at_ms {
                    if expires_at_ms <= now_ms {
                        return Ok(Err(RedeemRoomInviteError::InviteExpired));
                    }
                }
                if let Some(max_uses) = invite_link.max_uses {
                    if invite_link.use_count >= max_uses {
                        return Ok(Err(RedeemRoomInviteError::InviteUsageLimitReached));
                    }
                }

                let next_status = if room.join_approval_required || invite_link.requires_approval {
                    "pending"
                } else {
                    "active"
                };
                let next_created_at_ms = next_membership_created_at(
                    existing_membership.as_ref(),
                    next_status,
                    now_ms,
                );

                tx.execute(
                    "INSERT INTO room_memberships(room_id, profile_id, status, role, source_link_id, created_at_ms, updated_at_ms) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7) ON CONFLICT(room_id, profile_id) DO UPDATE SET status = excluded.status, role = excluded.role, source_link_id = excluded.source_link_id, created_at_ms = excluded.created_at_ms, updated_at_ms = excluded.updated_at_ms",
                    params![
                        room.room_id.clone(),
                        profile_id.clone(),
                        next_status,
                        normalize_invite_allowed_role(&invite_link.allowed_role),
                        Some(invite_link.link_id.clone()),
                        next_created_at_ms,
                        now_ms,
                    ],
                )?;
                tx.execute(
                    "UPDATE room_invite_links SET use_count = use_count + 1, updated_at_ms = ?2 WHERE link_id = ?1",
                    params![invite_link.link_id.clone(), now_ms],
                )?;
                tx.execute(
                    "UPDATE rooms SET version = ?2, membership_version = ?3, updated_at_ms = ?4 WHERE room_id = ?1",
                    params![
                        room.room_id.clone(),
                        room.version + 1,
                        room.membership_version + 1,
                        now_ms,
                    ],
                )?;

                let updated_room = tx.query_row(
                    ROOM_SELECT_BY_ID_SQL,
                    params![room.room_id.clone()],
                    map_room_row,
                )?;
                let updated_invite_link = tx.query_row(
                    "SELECT link_id, room_id, slug, created_by_profile_id, expires_at_ms, max_uses, use_count, requires_approval, allowed_role, is_revoked, created_at_ms, updated_at_ms FROM room_invite_links WHERE link_id = ?1",
                    params![invite_link.link_id.clone()],
                    map_room_invite_link_row,
                )?;
                let updated_membership = tx.query_row(
                    ROOM_MEMBERSHIP_SELECT_BY_ID_SQL,
                    params![room.room_id, profile_id],
                    map_room_membership_row,
                )?;

                tx.commit()?;

                Ok(Ok(RedeemRoomInviteResult {
                    changed: true,
                    room: updated_room,
                    invite_link: updated_invite_link,
                    membership: updated_membership,
                }))
            })
            .await
            .map_err(|e| RedeemRoomInviteError::Storage(e.to_string()))?;
        outcome
    }

    pub async fn cleanup_expired(&self, now_ms: i64) -> Result<(), String> {
        let call_session_terminal_ttl_ms = (self.call_session_terminal_ttl_seconds as i64) * 1000;
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute("DELETE FROM pending WHERE expires_at_ms <= ?1", params![now_ms])?;
                c.execute(
                    "UPDATE call_sessions
                     SET state = 'ended',
                         last_action = 'timeout',
                         ended_at_ms = COALESCE(ended_at_ms, expires_at_ms),
                         last_received_at_ms = CASE WHEN last_received_at_ms > ?1 THEN last_received_at_ms ELSE ?1 END,
                         expires_at_ms = expires_at_ms + ?2
                     WHERE expires_at_ms <= ?1
                       AND state <> 'ended'
                       AND ended_at_ms IS NULL",
                    params![now_ms, call_session_terminal_ttl_ms],
                )?;
                c.execute(
                    "DELETE FROM call_sessions WHERE state = 'ended' AND expires_at_ms <= ?1",
                    params![now_ms],
                )?;
                c.execute(
                    "UPDATE room_call_sessions
                     SET state = 'ended',
                         ended_at_ms = COALESCE(ended_at_ms, expires_at_ms),
                         updated_at_ms = CASE WHEN updated_at_ms > ?1 THEN updated_at_ms ELSE ?1 END,
                         expires_at_ms = expires_at_ms + ?2
                     WHERE expires_at_ms <= ?1
                       AND state <> 'ended'",
                    params![now_ms, call_session_terminal_ttl_ms],
                )?;
                c.execute(
                    "UPDATE room_call_participants
                     SET join_state = 'left',
                         muted = 0,
                         deafened = 0,
                         video_enabled = 0,
                         screen_share_enabled = 0,
                         speaking = 0,
                         left_at_ms = COALESCE(left_at_ms, ?1),
                         updated_at_ms = CASE WHEN updated_at_ms > ?1 THEN updated_at_ms ELSE ?1 END
                     WHERE call_id IN (
                         SELECT call_id FROM room_call_sessions WHERE state = 'ended'
                     )
                       AND join_state IN ('joined', 'reconnecting')",
                    params![now_ms],
                )?;
                c.execute(
                    "DELETE FROM room_call_media_participants WHERE call_id IN (SELECT call_id FROM room_call_sessions WHERE state = 'ended')",
                    [],
                )?;
                c.execute(
                    "DELETE FROM room_call_participants WHERE call_id IN (SELECT call_id FROM room_call_sessions WHERE state = 'ended' AND expires_at_ms <= ?1)",
                    params![now_ms],
                )?;
                c.execute(
                    "DELETE FROM room_call_sessions WHERE state = 'ended' AND expires_at_ms <= ?1",
                    params![now_ms],
                )?;
                c.execute(
                    "DELETE FROM call_signal_dedup WHERE created_at_ms <= ?1",
                    params![now_ms - (24 * 60 * 60 * 1000)],
                )?;
                c.execute(
                    "DELETE FROM message_dedup WHERE expires_at_ms <= ?1",
                    params![now_ms],
                )?;
                c.execute(
                    "DELETE FROM push_wake_dedup WHERE created_at_ms <= ?1",
                    params![now_ms - (7 * 24 * 60 * 60 * 1000)],
                )?;
                // SEC-09 (25.08.2026): забываем, КТО отправил сообщение в
                // комнату, но помним, что сообщение было.
                //
                // Раньше `admitted_by_profile_id` хранился бессрочно: очистка
                // происходила только при удалении самой комнаты. Получался
                // вечный журнал участия в группах у сервера, который в
                // остальном отправителя не хранит вовсе — ни `pending`, ни
                // `message_dedup`, ни `call_sessions` такого поля не имеют.
                //
                // 🔴 Почему обнуляем, а не удаляем строку. Таблица читается при
                // закреплении сообщения: перед тем как закрепить, проверяется,
                // что оно действительно было в этой комнате. Удаление строки
                // отняло бы возможность закрепить сообщение старше срока.
                // Обнуление снимает метаданные и сохраняет работу функции.
                c.execute(
                    "UPDATE room_message_index SET admitted_by_profile_id = '' \
                     WHERE admitted_by_profile_id <> '' AND admitted_at_ms <= ?1",
                    params![now_ms - (ROOM_MESSAGE_SENDER_RETENTION_DAYS * 24 * 60 * 60 * 1000)],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    /// Помечает, что для этого КЛЮЧА уже поднимался баннер, и сообщает, был ли
    /// он первым за отведённое окно.
    ///
    /// 🔴 ЗАЧЕМ ОТДЕЛЬНО ОТ [try_mark_push_wake_sent] (02.09.2026, полевая
    /// жалоба «повторные уведомления о непрочитанном»). Тот дедуп работает по
    /// `msg_id` и правильно делает: он защищает от повторной ОТПРАВКИ одного и
    /// того же конверта. Но страховка отправителя пересобирает то же логическое
    /// сообщение в НОВЫЙ конверт с новым `msg_id` — для дедупа это другое
    /// сообщение, и баннер поднимается заново. Схлопывание по беседе при этом
    /// работает как задумано: запись в центре уведомлений одна. Только всплытие
    /// и звук повторяются на каждой попытке.
    ///
    /// Ключ здесь — стабильный идентификатор сообщения, переживающий
    /// переотправку. Первый раз возвращает `true` (баннер уместен), дальше
    /// `false` — конверт всё равно доедет, но молча.
    ///
    /// 🔴 ОКНО, А НЕ «НАВСЕГДА». Отметка означает «баннер отправлен», а не
    /// «человек его увидел»: push мог не дойти вовсе. Поэтому по истечении окна
    /// баннер разрешается снова — иначе единственная потерянная доставка
    /// означала бы сообщение, о котором не сообщили никогда.
    pub async fn try_mark_alert_shown(
        &self,
        device_id: &str,
        key: &str,
        now_ms: i64,
        within_ms: i64,
    ) -> Result<bool, String> {
        let device_id = device_id.to_string();
        let key = key.to_string();
        let cutoff = now_ms - within_ms;
        self.conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let recent: Option<i64> = c
                    .query_row(
                        "SELECT created_at_ms FROM push_wake_dedup WHERE device_id = ?1 AND msg_id = ?2",
                        params![device_id, key],
                        |row| row.get(0),
                    )
                    .optional()?;
                match recent {
                    Some(at) if at > cutoff => Ok(false),
                    Some(_) => {
                        // Отметка есть, но старая: окно истекло, обновляем время
                        // и разрешаем баннер снова.
                        c.execute(
                            "UPDATE push_wake_dedup SET created_at_ms = ?3 WHERE device_id = ?1 AND msg_id = ?2",
                            params![device_id, key, now_ms],
                        )?;
                        Ok(true)
                    }
                    None => {
                        c.execute(
                            "INSERT OR IGNORE INTO push_wake_dedup(device_id, msg_id, created_at_ms) VALUES(?1, ?2, ?3)",
                            params![device_id, key, now_ms],
                        )?;
                        Ok(true)
                    }
                }
            })
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn try_mark_push_wake_sent(
        &self,
        device_id: &str,
        msg_id: &str,
        now_ms: i64,
    ) -> Result<bool, String> {
        let device_id = device_id.to_string();
        let msg_id = msg_id.to_string();
        let inserted = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let changed = c.execute(
                    "INSERT OR IGNORE INTO push_wake_dedup(device_id, msg_id, created_at_ms) VALUES(?1, ?2, ?3)",
                    params![device_id, msg_id, now_ms],
                )?;
                Ok(changed > 0)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(inserted)
    }

    pub async fn cleanup_expired_blobs(&self, now_ms: i64) -> Result<Vec<String>, String> {
        let removed = self
            .conn
            .call(move |c| -> Result<Vec<String>, rusqlite::Error> {
                let mut stmt =
                    c.prepare("SELECT blob_id, rel_path FROM blobs WHERE expires_at_ms <= ?1")?;
                let mut rows = stmt.query(params![now_ms])?;
                let mut paths = Vec::new();
                while let Some(row) = rows.next()? {
                    let rel_path: String = row.get(1)?;
                    paths.push(rel_path);
                }

                c.execute(
                    "DELETE FROM blobs WHERE expires_at_ms <= ?1",
                    params![now_ms],
                )?;
                Ok(paths)
            })
            .await
            .map_err(|e| e.to_string())?;

        Ok(removed)
    }

    pub async fn blob_insert(
        &self,
        blob_id: &str,
        rel_path: &str,
        size_bytes: u64,
        expires_at_ms: i64,
        created_at_ms: i64,
        owner_device_id: &str,
        owner_profile_id: &str,
        access_token_sha256_b64: &str,
    ) -> Result<(), String> {
        let blob_id = blob_id.to_string();
        let rel_path = rel_path.to_string();
        let owner_device_id = owner_device_id.to_string();
        let owner_profile_id = owner_profile_id.to_string();
        let access_token_sha256_b64 = access_token_sha256_b64.to_string();
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "INSERT INTO blobs(blob_id, rel_path, size_bytes, expires_at_ms, created_at_ms, owner_device_id, owner_profile_id, access_token_sha256_b64) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                    params![blob_id, rel_path, size_bytes as i64, expires_at_ms, created_at_ms, owner_device_id, owner_profile_id, access_token_sha256_b64],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    pub async fn blob_get(&self, blob_id: &str, now_ms: i64) -> Result<Option<BlobRow>, String> {
        let blob_id = blob_id.to_string();
        let row = self
            .conn
            .call(move |c| -> Result<Option<BlobRow>, rusqlite::Error> {
                let r = c
                    .query_row(
                        "SELECT rel_path, expires_at_ms, owner_profile_id, access_token_sha256_b64 FROM blobs WHERE blob_id = ?1",
                        params![blob_id],
                        |row| {
                            Ok(BlobRow {
                                rel_path: row.get(0)?,
                                expires_at_ms: row.get(1)?,
                                owner_profile_id: row.get::<_, Option<String>>(2)?.unwrap_or_default(),
                                access_token_sha256_b64: row.get::<_, Option<String>>(3)?.unwrap_or_default(),
                            })
                        },
                    )
                    .optional()?;

                Ok(r)
            })
            .await
            .map_err(|e| e.to_string())?;

        if row.as_ref().is_some_and(|r| r.expires_at_ms <= now_ms) {
            return Ok(None);
        }
        Ok(row)
    }

    pub async fn ensure_device(&self, device_id: String) -> Result<(), String> {
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "INSERT OR IGNORE INTO device_state(device_id, next_seq) VALUES(?1, 1)",
                    params![device_id],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    pub async fn welcome_next_seq(&self, device_id: &str, now_ms: i64) -> Result<u64, String> {
        let device_id_owned = device_id.to_string();
        self.cleanup_expired(now_ms).await?;
        self.ensure_device(device_id_owned.clone()).await?;

        let v = self
            .conn
            .call(move |c| -> Result<u64, rusqlite::Error> {
                // If we have pending messages, return the smallest seq so the client can re-fetch.
                let min_seq: Option<i64> = c.query_row(
                    "SELECT MIN(seq) FROM pending WHERE device_id = ?1",
                    params![device_id_owned.clone()],
                    |row| row.get(0),
                )?;

                if let Some(ms) = min_seq {
                    if ms > 0 {
                        return Ok(ms as u64);
                    }
                }

                let next_seq: i64 = c.query_row(
                    "SELECT next_seq FROM device_state WHERE device_id = ?1",
                    params![device_id_owned],
                    |row| row.get(0),
                )?;

                Ok(next_seq as u64)
            })
            .await
            .map_err(|e| e.to_string())?;

        Ok(v)
    }

    pub async fn list_pending_from(
        &self,
        device_id: &str,
        from_seq: u64,
        now_ms: i64,
        limit: usize,
    ) -> Result<Vec<PendingRow>, String> {
        let device_id_owned = device_id.to_string();
        self.cleanup_expired(now_ms).await?;

        let from_seq_i64 = from_seq as i64;
        let limit_i64 = limit as i64;
        let v = self
            .conn
            .call(move |c| -> Result<Vec<PendingRow>, rusqlite::Error> {
                // SEQ-CURSOR FIX (2026-06-07): clamp the effective lower bound
                // to MIN(from_seq, oldest-unacked-seq-in-mailbox).
                //
                // Previously this query used a strict `seq >= from_seq`. If a
                // client's persisted cursor advanced past an un-acked message
                // (lost ACK after a realtime delivery — common on Android
                // background kills / WS drops), that message's seq fell BELOW
                // the cursor and was never returned again, stranding it in the
                // mailbox until its 7-day TTL. Live evidence: 63 pending rows,
                // 100% with seq < device cursor.
                //
                // By clamping the lower bound to the oldest pending seq, the
                // relay always re-offers stranded messages. The client safely
                // de-duplicates already-applied messages via `inbox_seen`
                // (msg_id) and the `events` table's INSERT-OR-IGNORE on
                // event_id, so re-offering cannot create duplicates. When there
                // is no stranded message, `MIN(from_seq, min_pending)` equals
                // `from_seq`, preserving the original behavior exactly.
                // SCHEDULED DELIVERY (2026-07-17): never surface a row whose
                // release time hasn't arrived (`deliver_at_ms` clause). 0 =
                // immediate, so normal traffic is unaffected. `now_ms` is bound
                // as ?4.
                let mut stmt = c
                    .prepare(
                        "SELECT seq, msg_id, ciphertext_b64, transport_meta_json, last_attempt_ms, expires_at_ms, from_device_id FROM pending \
                         WHERE device_id = ?1 \
                           AND deliver_at_ms <= ?4 \
                           AND seq >= MIN(?2, COALESCE((SELECT MIN(seq) FROM pending WHERE device_id = ?1 AND deliver_at_ms <= ?4), ?2)) \
                         ORDER BY seq ASC LIMIT ?3",
                    )?;
                let mut rows = stmt
                    .query(params![device_id_owned, from_seq_i64, limit_i64, now_ms])?;
                let mut out = Vec::new();
                while let Some(row) = rows.next()? {
                    let seq: i64 = row.get(0)?;
                    let msg_id: String = row.get(1)?;
                    let ciphertext_b64: String = row.get(2)?;
                    out.push(PendingRow {
                        seq: seq as u64,
                        msg_id,
                        ciphertext_b64,
                        transport_meta_json: row.get(3)?,
                        last_attempt_ms: row.get(4)?,
                        expires_at_ms: row.get(5)?,
                        from_device_id: row.get(6)?,
                    });
                }
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())?;

        Ok(v)
    }

    /// RELIABLE-DELIVERY (2026-07-08): rows still pending (unacked) for this
    /// device whose LAST delivery attempt is older than `backoff_ms` — i.e.
    /// the client was sent this message and has had `backoff_ms` to ack it but
    /// did not. Unlike [`list_orphaned_below_cursor`] this is NOT limited to
    /// below-cursor rows: a message dropped by a *connected* client (lost in a
    /// reconnect-backfill flood, or transiently undecryptable) sits ABOVE the
    /// delivery cursor and would otherwise never be retried while the socket
    /// stays up. The redeliver sweep re-sends these to the live socket until
    /// the client acks (which deletes the row); the client de-dups by `msg_id`.
    /// Expired rows are excluded so we never resurrect a TTL'd message.
    pub async fn list_pending_for_redelivery(
        &self,
        device_id: &str,
        backoff_ms: i64,
        now_ms: i64,
        limit: usize,
    ) -> Result<Vec<PendingRow>, String> {
        let device_id_owned = device_id.to_string();
        let cutoff = now_ms - backoff_ms;
        let limit_i64 = limit as i64;
        let v = self
            .conn
            .call(move |c| -> Result<Vec<PendingRow>, rusqlite::Error> {
                // SCHEDULED DELIVERY (2026-07-17): a not-yet-released row
                // (deliver_at_ms > now) must not be re-pushed by the redeliver
                // sweep either.
                let mut stmt = c.prepare(
                    "SELECT seq, msg_id, ciphertext_b64, transport_meta_json, last_attempt_ms, expires_at_ms, from_device_id FROM pending \
                     WHERE device_id = ?1 AND last_attempt_ms < ?2 AND expires_at_ms > ?3 \
                       AND deliver_at_ms <= ?3 \
                     ORDER BY seq ASC LIMIT ?4",
                )?;
                let mut rows =
                    stmt.query(params![device_id_owned, cutoff, now_ms, limit_i64])?;
                let mut out = Vec::new();
                while let Some(row) = rows.next()? {
                    out.push(PendingRow {
                        seq: row.get::<_, i64>(0)? as u64,
                        msg_id: row.get(1)?,
                        ciphertext_b64: row.get(2)?,
                        transport_meta_json: row.get(3)?,
                        last_attempt_ms: row.get(4)?,
                        expires_at_ms: row.get(5)?,
                        from_device_id: row.get(6)?,
                    });
                }
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(v)
    }

    /// Stamp the last delivery attempt for the given seqs so the redeliver
    /// sweep backs off before re-sending them again. Called after a
    /// (re)delivery to a live socket (connect-backfill and the sweep itself).
    pub async fn mark_pending_attempted(
        &self,
        device_id: &str,
        seqs: Vec<u64>,
        now_ms: i64,
    ) -> Result<(), String> {
        if seqs.is_empty() {
            return Ok(());
        }
        let device_id_owned = device_id.to_string();
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                let tx = c.transaction()?;
                {
                    let mut stmt = tx.prepare(
                        "UPDATE pending SET last_attempt_ms = ?1 WHERE device_id = ?2 AND seq = ?3",
                    )?;
                    for seq in seqs {
                        stmt.execute(params![now_ms, device_id_owned, seq as i64])?;
                    }
                }
                tx.commit()?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    /// DELIVERY-WAKE AUDIT (2026-07-16): devices whose mailbox has unexpired
    /// pending rows AND a registered push token — the candidate set for the
    /// offline re-wake sweep. The old contract ("one push per msg_id, 2s after
    /// enqueue, never again") meant a single lost FCM/APNs handoff stranded the
    /// whole mailbox until the next fresh message: prod had devices sitting on
    /// week-old pending rows that expired unread.
    ///
    /// Returned per device:
    ///   * `backlog_started_ms` — MIN(last_attempt_ms). For a device with no
    ///     live socket nothing re-stamps `last_attempt_ms` after enqueue, so
    ///     this approximates when the oldest stranded row arrived.
    ///   * `newest_meta_json` — transport meta of the newest `chat_message_v1`
    ///     row if any (so the re-wake can carry a proper banner), else the
    ///     newest NON-call row (control-only backlog → silent wake). Call
    ///     signal metas are excluded on purpose: a re-wake must never re-ring
    ///     a stale invite (VoIP push) hours after the call ended — a
    ///     call-only backlog degrades to a generic silent wake (NULL meta).
    ///   * `last_pump_at_ms` / `last_push_attempted_at_ms` from
    ///     `device_activity` — the sweep's backoff inputs.
    pub async fn list_offline_wake_candidates(
        &self,
        now_ms: i64,
    ) -> Result<Vec<OfflineWakeCandidate>, String> {
        let v = self
            .conn
            .call(
                move |c| -> Result<Vec<OfflineWakeCandidate>, rusqlite::Error> {
                    let mut stmt = c.prepare(
                        // backlog_started_ms MUST be a FIXED anchor — the oldest
                        // chat message's arrival (expires_at_ms − 7d; chat ttl is
                        // 7d). MIN(last_attempt_ms) is RESET by every re-delivery
                        // / HTTP-fetch, so the age never grew and the re-wake
                        // ladder never backed off → a re-wake every ~10 min
                        // forever. Fall back to MIN(last_attempt_ms) for a
                        // control-only backlog.
                        "SELECT p.device_id, COUNT(*), \
                            COALESCE( \
                              (SELECT MIN(pc.expires_at_ms) - 604800000 FROM pending pc \
                                 WHERE pc.device_id = p.device_id AND pc.expires_at_ms > ?1 \
                                   AND pc.deliver_at_ms <= ?1 \
                                   AND pc.transport_meta_json LIKE '%chat_message_v1%'), \
                              MIN(p.last_attempt_ms)), \
                            COALESCE( \
                              (SELECT px.transport_meta_json FROM pending px \
                                 WHERE px.device_id = p.device_id AND px.expires_at_ms > ?1 \
                                   AND px.deliver_at_ms <= ?1 \
                                   AND px.transport_meta_json LIKE '%chat_message_v1%' \
                                 ORDER BY px.seq DESC LIMIT 1), \
                              (SELECT py.transport_meta_json FROM pending py \
                                 WHERE py.device_id = p.device_id AND py.expires_at_ms > ?1 \
                                   AND py.deliver_at_ms <= ?1 \
                                   AND (py.transport_meta_json IS NULL \
                                        OR py.transport_meta_json NOT LIKE '%call_signal_v1%') \
                                 ORDER BY py.seq DESC LIMIT 1)), \
                            COALESCE(da.last_pump_at_ms, 0), \
                            COALESCE(da.last_push_attempted_at_ms, 0) \
                         FROM pending p \
                         LEFT JOIN device_activity da ON da.device_id = p.device_id \
                         WHERE p.expires_at_ms > ?1 \
                           AND p.deliver_at_ms <= ?1 \
                           AND COALESCE(da.superseded_at_ms, 0) = 0 \
                           AND EXISTS (SELECT 1 FROM push_tokens t WHERE t.device_id = p.device_id) \
                         GROUP BY p.device_id",
                    )?;
                    let mut rows = stmt.query(params![now_ms])?;
                    let mut out = Vec::new();
                    while let Some(row) = rows.next()? {
                        out.push(OfflineWakeCandidate {
                            device_id: row.get(0)?,
                            pending_count: row.get::<_, i64>(1)?.max(0) as u64,
                            backlog_started_ms: row.get(2)?,
                            newest_meta_json: row.get(3)?,
                            last_pump_at_ms: row.get(4)?,
                            last_push_attempted_at_ms: row.get(5)?,
                        });
                    }
                    Ok(out)
                },
            )
            .await
            .map_err(|e| e.to_string())?;
        Ok(v)
    }

    /// SERVER-SIDE SCHEDULED DELIVERY (2026-07-17): devices whose scheduled
    /// rows crossed their release time within the `(since_ms, now_ms]` window —
    /// i.e. became deliverable JUST NOW. The release tick delivers these
    /// promptly (WS if the recipient is connected, else a single push wake),
    /// instead of leaving them to the offline re-wake ladder (which could delay
    /// a "deliver at 03:00 sharp" message by up to its 10-minute first rung).
    ///
    /// Returns one row per device with the newest just-released chat meta (for
    /// a proper banner), NULL for a control-only release (silent wake).
    pub async fn list_devices_with_freshly_due_scheduled(
        &self,
        now_ms: i64,
        since_ms: i64,
    ) -> Result<Vec<OfflineWakeCandidate>, String> {
        let v = self
            .conn
            .call(
                move |c| -> Result<Vec<OfflineWakeCandidate>, rusqlite::Error> {
                    let mut stmt = c.prepare(
                        "SELECT p.device_id, COUNT(*), MIN(p.last_attempt_ms), \
                            COALESCE( \
                              (SELECT px.transport_meta_json FROM pending px \
                                 WHERE px.device_id = p.device_id AND px.expires_at_ms > ?1 \
                                   AND px.deliver_at_ms > ?2 AND px.deliver_at_ms <= ?1 \
                                   AND px.transport_meta_json LIKE '%chat_message_v1%' \
                                 ORDER BY px.seq DESC LIMIT 1), \
                              (SELECT py.transport_meta_json FROM pending py \
                                 WHERE py.device_id = p.device_id AND py.expires_at_ms > ?1 \
                                   AND py.deliver_at_ms > ?2 AND py.deliver_at_ms <= ?1 \
                                   AND (py.transport_meta_json IS NULL \
                                        OR py.transport_meta_json NOT LIKE '%call_signal_v1%') \
                                 ORDER BY py.seq DESC LIMIT 1)), \
                            COALESCE(da.last_pump_at_ms, 0), \
                            COALESCE(da.last_push_attempted_at_ms, 0) \
                         FROM pending p \
                         LEFT JOIN device_activity da ON da.device_id = p.device_id \
                         WHERE p.expires_at_ms > ?1 \
                           AND p.deliver_at_ms > ?2 AND p.deliver_at_ms <= ?1 \
                           AND COALESCE(da.superseded_at_ms, 0) = 0 \
                         GROUP BY p.device_id",
                    )?;
                    let mut rows = stmt.query(params![now_ms, since_ms])?;
                    let mut out = Vec::new();
                    while let Some(row) = rows.next()? {
                        out.push(OfflineWakeCandidate {
                            device_id: row.get(0)?,
                            pending_count: row.get::<_, i64>(1)?.max(0) as u64,
                            backlog_started_ms: row.get(2)?,
                            newest_meta_json: row.get(3)?,
                            last_pump_at_ms: row.get(4)?,
                            last_push_attempted_at_ms: row.get(5)?,
                        });
                    }
                    Ok(out)
                },
            )
            .await
            .map_err(|e| e.to_string())?;
        Ok(v)
    }

    /// SCHEDULED DELIVERY (2026-07-17): delete a not-yet-released scheduled row
    /// (cancel "send later" before its time). Returns true if a row was
    /// removed. Only removes rows that are still in the future
    /// (`deliver_at_ms > now_ms`) so a message already released/delivered
    /// cannot be silently unsent.
    pub async fn cancel_scheduled(
        &self,
        device_id: &str,
        msg_id: &str,
        now_ms: i64,
    ) -> Result<bool, String> {
        let device_id_owned = device_id.to_string();
        let msg_id_owned = msg_id.to_string();
        let n = self
            .conn
            .call(move |c| -> Result<usize, rusqlite::Error> {
                c.execute(
                    "DELETE FROM pending WHERE device_id = ?1 AND msg_id = ?2 \
                       AND deliver_at_ms > ?3",
                    params![device_id_owned, msg_id_owned, now_ms],
                )
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(n > 0)
    }

    pub async fn pending_count(&self, device_id: &str, now_ms: i64) -> Result<u64, String> {
        let device_id_owned = device_id.to_string();
        // Best-effort cleanup so counts reflect live data.
        self.cleanup_expired(now_ms).await?;

        let v = self
            .conn
            .call(move |c| -> Result<u64, rusqlite::Error> {
                let cnt: i64 = c.query_row(
                    "SELECT COUNT(*) FROM pending WHERE device_id = ?1 AND expires_at_ms > ?2 \
                     AND deliver_at_ms <= ?2",
                    params![device_id_owned, now_ms],
                    |row| row.get(0),
                )?;
                Ok(cnt.max(0) as u64)
            })
            .await
            .map_err(|e| e.to_string())?;

        Ok(v)
    }

    /// Count of UNDELIVERED chat-message rows for a device — the value used for
    /// the iOS app-icon unread badge. Unlike [`pending_count`] (which counts
    /// EVERY mailbox row) this counts only rows whose transport_meta marks them a
    /// `chat_message_v1`. Receipts, session-heal, self-mirror and other control
    /// envelopes carry no chat transport_meta and were inflating the badge — one
    /// user message enqueues the chat row PLUS a couple of control rows, so
    /// `pending_count` showed 3 for one message. This approximates unread messages
    /// for the killed-app window; a running client overwrites it with the true
    /// local unread total.
    pub async fn pending_message_count(
        &self,
        device_id: &str,
        now_ms: i64,
    ) -> Result<u64, String> {
        let device_id_owned = device_id.to_string();
        self.cleanup_expired(now_ms).await?;

        let v = self
            .conn
            .call(move |c| -> Result<u64, rusqlite::Error> {
                let cnt: i64 = c.query_row(
                    "SELECT COUNT(*) FROM pending WHERE device_id = ?1 AND expires_at_ms > ?2 \
                     AND deliver_at_ms <= ?2 \
                     AND transport_meta_json LIKE '%chat_message_v1%'",
                    params![device_id_owned, now_ms],
                    |row| row.get(0),
                )?;
                Ok(cnt.max(0) as u64)
            })
            .await
            .map_err(|e| e.to_string())?;

        Ok(v)
    }

    pub async fn has_pending_msg(
        &self,
        device_id: &str,
        msg_id: &str,
        now_ms: i64,
    ) -> Result<bool, String> {
        let device_id_owned = device_id.to_string();
        let msg_id_owned = msg_id.to_string();
        self.cleanup_expired(now_ms).await?;

        let exists = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let v: i64 = c.query_row(
                    "SELECT EXISTS(SELECT 1 FROM pending WHERE device_id = ?1 AND msg_id = ?2 AND expires_at_ms > ?3)",
                    params![device_id_owned, msg_id_owned, now_ms],
                    |row| row.get(0),
                )?;
                Ok(v != 0)
            })
            .await
            .map_err(|e| e.to_string())?;

        Ok(exists)
    }

    pub async fn enqueue(
        &self,
        device_id: &str,
        msg_id: &str,
        ciphertext_b64: &str,
        transport_meta_json: Option<&str>,
        ttl_seconds: u32,
        now_ms: i64,
    ) -> Result<EnqueueResult, String> {
        // Immediate delivery (deliver_at_ms = 0) — every normal message and
        // every existing call site. Scheduled sends use `enqueue_scheduled`.
        self.enqueue_scheduled(
            device_id,
            msg_id,
            ciphertext_b64,
            transport_meta_json,
            ttl_seconds,
            now_ms,
            0,
            None,
        )
        .await
    }

    /// SERVER-SIDE SCHEDULED DELIVERY (2026-07-17): like [`enqueue`], but the
    /// row is held until `now >= deliver_at_ms`. `deliver_at_ms = 0` is the
    /// immediate path. The ciphertext is already E2E-encrypted for the
    /// recipient, so the relay only stores and time-gates it.
    #[allow(clippy::too_many_arguments)]
    pub async fn enqueue_scheduled(
        &self,
        device_id: &str,
        msg_id: &str,
        ciphertext_b64: &str,
        transport_meta_json: Option<&str>,
        ttl_seconds: u32,
        now_ms: i64,
        deliver_at_ms: i64,
        from_device_id: Option<&str>,
    ) -> Result<EnqueueResult, String> {
        let device_id_owned = device_id.to_string();
        let msg_id_owned = msg_id.to_string();
        let ciphertext_owned = ciphertext_b64.to_string();
        let transport_meta_json_owned = transport_meta_json.map(|v| v.to_string());
        let from_device_id_owned = from_device_id
            .map(|v| v.trim().to_string())
            .filter(|v| !v.is_empty());
        // TTL is measured from the DELIVERY moment, not the upload moment, so a
        // message scheduled far in the future still gets its full mailbox life
        // after release.
        let ttl_anchor_ms = std::cmp::max(now_ms, deliver_at_ms);
        let expires_at_ms = ttl_anchor_ms + (ttl_seconds as i64) * 1000;
        let dedup_expires_at_ms =
            now_ms + std::cmp::max((ttl_seconds as i64) * 1000, MESSAGE_DEDUP_MIN_TTL_MS);

        self.ensure_device(device_id_owned.clone()).await?;

        let v = self
            .conn
            .call(move |c| -> Result<EnqueueResult, rusqlite::Error> {
                let tx = c.transaction()?;

                // Dedup by msg_id (per device). Read the STORED release time as
                // well: if this row is a still-held scheduled message, a
                // re-submit of the same msg_id as "immediate" must NOT be able
                // to release it early — the caller gates on the stored value.
                let existing: Option<(i64, i64)> = tx
                    .query_row(
                        "SELECT seq, deliver_at_ms FROM pending WHERE device_id = ?1 AND msg_id = ?2",
                        params![device_id_owned.clone(), msg_id_owned.clone()],
                        |row| Ok((row.get(0)?, row.get(1)?)),
                    )
                    .optional()
                    ?;

                if let Some((seq, stored_deliver_at_ms)) = existing {
                    tx.commit()?;
                    return Ok(EnqueueResult {
                        seq: seq as u64,
                        dedup: true,
                        deliver_at_ms: stored_deliver_at_ms,
                    });
                }

                let existing_dedup: Option<i64> = tx
                    .query_row(
                        "SELECT seq FROM message_dedup WHERE device_id = ?1 AND msg_id = ?2 AND expires_at_ms > ?3",
                        params![device_id_owned.clone(), msg_id_owned.clone(), now_ms],
                        |row| row.get(0),
                    )
                    .optional()?;

                if let Some(seq) = existing_dedup {
                    tx.commit()?;
                    return Ok(EnqueueResult {
                        seq: seq as u64,
                        dedup: true,
                        // No `pending` row survives (already delivered + acked),
                        // so there is nothing left to hold.
                        deliver_at_ms: 0,
                    });
                }

                let next_seq: i64 = tx
                    .query_row(
                        "SELECT next_seq FROM device_state WHERE device_id = ?1",
                        params![device_id_owned.clone()],
                        |row| row.get(0),
                    )?;

                tx.execute(
                    "INSERT INTO pending(device_id, seq, msg_id, ciphertext_b64, transport_meta_json, expires_at_ms, last_attempt_ms, deliver_at_ms, from_device_id) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
                    params![
                        device_id_owned.clone(),
                        next_seq,
                        msg_id_owned,
                        ciphertext_owned,
                        transport_meta_json_owned,
                        expires_at_ms,
                        // Count enqueue as the first delivery attempt: the realtime
                        // path delivers immediately after, and the redeliver sweep
                        // then waits one backoff before re-sending an unacked row.
                        // For a scheduled row, `deliver_at_ms` is stamped so the
                        // release scheduler picks it up at T (not before).
                        now_ms,
                        deliver_at_ms,
                        from_device_id_owned
                    ],
                )?;

                tx.execute(
                    "INSERT INTO message_dedup(device_id, msg_id, seq, created_at_ms, expires_at_ms) VALUES(?1, ?2, ?3, ?4, ?5)
                     ON CONFLICT(device_id, msg_id) DO UPDATE SET
                       seq = excluded.seq,
                       created_at_ms = excluded.created_at_ms,
                       expires_at_ms = excluded.expires_at_ms",
                    params![
                        device_id_owned.clone(),
                        msg_id_owned,
                        next_seq,
                        now_ms,
                        dedup_expires_at_ms,
                    ],
                )?;

                tx.execute(
                    "UPDATE device_state SET next_seq = next_seq + 1 WHERE device_id = ?1",
                    params![device_id_owned],
                )?;

                tx.commit()?;

                Ok(EnqueueResult {
                    seq: next_seq as u64,
                    dedup: false,
                    deliver_at_ms,
                })
            })
            .await
            .map_err(|e| e.to_string())?;

        Ok(v)
    }

    pub async fn record_call_signal(
        &self,
        from_device_id: &str,
        to_device_id: &str,
        signal: &CallSignalRecord,
        active_ttl_seconds: u32,
        terminal_ttl_seconds: u32,
        now_ms: i64,
    ) -> Result<bool, String> {
        let from_device_id = from_device_id.to_string();
        let to_device_id = to_device_id.to_string();
        let signal = signal.clone();

        let updated = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let tx = c.transaction()?;
                let reused_signal_attempt = tx
                    .query_row(
                        "SELECT call_attempt_id FROM call_signal_dedup WHERE call_id = ?1 AND signal_id = ?2 LIMIT 1",
                        params![&signal.call_id, &signal.signal_id],
                        |row| row.get::<_, String>(0),
                    )
                    .optional()?;
                if reused_signal_attempt
                    .as_ref()
                    .is_some_and(|attempt| attempt != &signal.call_attempt_id)
                {
                    tx.commit()?;
                    return Ok(false);
                }
                let inserted = tx.execute(
                    "INSERT OR IGNORE INTO call_signal_dedup(call_id, call_attempt_id, signal_id, created_at_ms) VALUES(?1, ?2, ?3, ?4)",
                    params![&signal.call_id, &signal.call_attempt_id, &signal.signal_id, now_ms],
                )?;
                if inserted <= 0 {
                    tx.commit()?;
                    return Ok(false);
                }

                fn apply_call_session_update(
                    tx: &rusqlite::Transaction<'_>,
                    participant_device_id: &str,
                    peer_device_id: &str,
                    direction: &str,
                    signal: &CallSignalRecord,
                    active_ttl_seconds: u32,
                    terminal_ttl_seconds: u32,
                    now_ms: i64,
                ) -> Result<(), rusqlite::Error> {
                    let newer_sibling_created_at_ms = tx
                        .query_row(
                            "SELECT last_created_at_ms FROM call_sessions WHERE call_id = ?1 AND participant_device_id = ?2 AND call_attempt_id <> ?3 ORDER BY last_created_at_ms DESC LIMIT 1",
                            params![&signal.call_id, participant_device_id, &signal.call_attempt_id],
                            |row| row.get::<_, i64>(0),
                        )
                        .optional()?;
                    if newer_sibling_created_at_ms
                        .is_some_and(|created_at_ms| created_at_ms > signal.created_at_ms)
                    {
                        return Ok(());
                    }

                    let existing = tx
                        .query_row(
                            "SELECT state, last_created_at_ms, invited_at_ms, accepted_at_ms, offer_seen_at_ms, answer_seen_at_ms, reconnecting_at_ms, ended_at_ms, expires_at_ms FROM call_sessions WHERE call_id = ?1 AND call_attempt_id = ?2 AND participant_device_id = ?3",
                            params![&signal.call_id, &signal.call_attempt_id, participant_device_id],
                            |row| {
                                Ok((
                                    row.get::<_, String>(0)?,
                                    row.get::<_, i64>(1)?,
                                    row.get::<_, Option<i64>>(2)?,
                                    row.get::<_, Option<i64>>(3)?,
                                    row.get::<_, Option<i64>>(4)?,
                                    row.get::<_, Option<i64>>(5)?,
                                    row.get::<_, Option<i64>>(6)?,
                                    row.get::<_, Option<i64>>(7)?,
                                    row.get::<_, i64>(8)?,
                                ))
                            },
                        )
                        .optional()?;

                    let mut state = existing
                        .as_ref()
                        .map(|v| v.0.clone())
                        .unwrap_or_else(|| "invited".to_string());
                    let last_created_at_ms = existing.as_ref().map(|v| v.1).unwrap_or(i64::MIN);
                    let mut invited_at_ms = existing.as_ref().and_then(|v| v.2);
                    let mut accepted_at_ms = existing.as_ref().and_then(|v| v.3);
                    let mut offer_seen_at_ms = existing.as_ref().and_then(|v| v.4);
                    let mut answer_seen_at_ms = existing.as_ref().and_then(|v| v.5);
                    let mut reconnecting_at_ms = existing.as_ref().and_then(|v| v.6);
                    let mut ended_at_ms = existing.as_ref().and_then(|v| v.7);
                    let stored_expires_at_ms = existing.as_ref().map(|v| v.8).unwrap_or(0);

                    if last_created_at_ms > signal.created_at_ms {
                        let refreshed_expires_at_ms = call_session_expires_at_ms(
                            &state,
                            now_ms,
                            active_ttl_seconds,
                            terminal_ttl_seconds,
                        );
                        tx.execute(
                            "UPDATE call_sessions SET expires_at_ms = CASE WHEN expires_at_ms > ?4 THEN expires_at_ms ELSE ?4 END WHERE call_id = ?1 AND call_attempt_id = ?2 AND participant_device_id = ?3",
                            params![&signal.call_id, &signal.call_attempt_id, participant_device_id, refreshed_expires_at_ms],
                        )?;
                        return Ok(());
                    }

                    if call_session_is_terminal_state(&state)
                        && !matches!(signal.action.as_str(), "decline" | "hangup")
                    {
                        let refreshed_expires_at_ms = call_session_expires_at_ms(
                            &state,
                            now_ms,
                            active_ttl_seconds,
                            terminal_ttl_seconds,
                        );
                        tx.execute(
                            "UPDATE call_sessions
                             SET last_received_at_ms = CASE WHEN last_received_at_ms > ?4 THEN last_received_at_ms ELSE ?4 END,
                                 expires_at_ms = CASE WHEN expires_at_ms > ?5 THEN expires_at_ms ELSE ?5 END
                             WHERE call_id = ?1 AND call_attempt_id = ?2 AND participant_device_id = ?3",
                            params![
                                &signal.call_id,
                                &signal.call_attempt_id,
                                participant_device_id,
                                now_ms,
                                refreshed_expires_at_ms,
                            ],
                        )?;
                        return Ok(());
                    }

                    match signal.action.as_str() {
                        "invite" => {
                            invited_at_ms = invited_at_ms.or(Some(signal.created_at_ms));
                            if state != "accepted" && state != "reconnecting" {
                                state = "ringing".to_string();
                            }
                        }
                        "offer" => {
                            offer_seen_at_ms = Some(signal.created_at_ms);
                            if state != "accepted" && state != "reconnecting" {
                                state = "ringing".to_string();
                            }
                        }
                        "answer" => {
                            state = "accepted".to_string();
                            accepted_at_ms = accepted_at_ms.or(Some(signal.created_at_ms));
                            answer_seen_at_ms = Some(signal.created_at_ms);
                        }
                        "need_offer" => {
                            state = "reconnecting".to_string();
                            reconnecting_at_ms = Some(signal.created_at_ms);
                        }
                        "decline" | "hangup" => {
                            state = "ended".to_string();
                            ended_at_ms = Some(signal.created_at_ms);
                        }
                        "ice" => {}
                        _ => {}
                    }

                    let desired_expires_at_ms = call_session_expires_at_ms(
                        &state,
                        now_ms,
                        active_ttl_seconds,
                        terminal_ttl_seconds,
                    );
                    let session_expires_at_ms = if call_session_is_terminal_state(&state) {
                        desired_expires_at_ms
                    } else {
                        stored_expires_at_ms.max(desired_expires_at_ms)
                    };
                    let superseded_expires_at_ms = call_session_expires_at_ms(
                        "ended",
                        now_ms,
                        active_ttl_seconds,
                        terminal_ttl_seconds,
                    );

                    tx.execute(
                        "INSERT INTO call_sessions(call_id, call_attempt_id, participant_device_id, peer_device_id, direction, state, last_action, last_signal_id, last_created_at_ms, last_received_at_ms, invited_at_ms, accepted_at_ms, offer_seen_at_ms, answer_seen_at_ms, reconnecting_at_ms, ended_at_ms, expires_at_ms)
                         VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17)
                         ON CONFLICT(call_id, call_attempt_id, participant_device_id) DO UPDATE SET
                           peer_device_id = excluded.peer_device_id,
                           direction = excluded.direction,
                           state = excluded.state,
                           last_action = excluded.last_action,
                           last_signal_id = excluded.last_signal_id,
                           last_created_at_ms = excluded.last_created_at_ms,
                           last_received_at_ms = excluded.last_received_at_ms,
                           invited_at_ms = excluded.invited_at_ms,
                           accepted_at_ms = excluded.accepted_at_ms,
                           offer_seen_at_ms = excluded.offer_seen_at_ms,
                           answer_seen_at_ms = excluded.answer_seen_at_ms,
                           reconnecting_at_ms = excluded.reconnecting_at_ms,
                           ended_at_ms = excluded.ended_at_ms,
                           expires_at_ms = excluded.expires_at_ms",
                        params![
                            &signal.call_id,
                            &signal.call_attempt_id,
                            participant_device_id,
                            peer_device_id,
                            direction,
                            state,
                            &signal.action,
                            &signal.signal_id,
                            signal.created_at_ms,
                            now_ms,
                            invited_at_ms,
                            accepted_at_ms,
                            offer_seen_at_ms,
                            answer_seen_at_ms,
                            reconnecting_at_ms,
                            ended_at_ms,
                            session_expires_at_ms,
                        ],
                    )?;

                    tx.execute(
                        "UPDATE call_sessions
                         SET state = 'ended',
                             last_action = 'superseded',
                             ended_at_ms = COALESCE(ended_at_ms, ?4),
                             last_received_at_ms = ?5,
                             expires_at_ms = ?6
                         WHERE call_id = ?1
                           AND participant_device_id = ?2
                           AND call_attempt_id <> ?3
                           AND last_created_at_ms < ?4
                           AND (ended_at_ms IS NULL AND state <> 'ended')",
                        params![
                            &signal.call_id,
                            participant_device_id,
                            &signal.call_attempt_id,
                            signal.created_at_ms,
                            now_ms,
                            superseded_expires_at_ms,
                        ],
                    )?;

                    Ok(())
                }

                apply_call_session_update(
                    &tx,
                    &from_device_id,
                    &to_device_id,
                    "outgoing",
                    &signal,
                    active_ttl_seconds,
                    terminal_ttl_seconds,
                    now_ms,
                )?;
                apply_call_session_update(
                    &tx,
                    &to_device_id,
                    &from_device_id,
                    "incoming",
                    &signal,
                    active_ttl_seconds,
                    terminal_ttl_seconds,
                    now_ms,
                )?;

                tx.commit()?;
                Ok(true)
            })
            .await
            .map_err(|e| e.to_string())?;

        Ok(updated)
    }

    pub async fn get_call_session(
        &self,
        device_id: &str,
        call_id: &str,
        call_attempt_id: &str,
        now_ms: i64,
    ) -> Result<Option<CallSessionRow>, String> {
        let device_id = device_id.to_string();
        let call_id = call_id.to_string();
        let call_attempt_id = call_attempt_id.to_string();
        self.cleanup_expired(now_ms).await?;

        let row = self
            .conn
            .call(move |c| -> Result<Option<CallSessionRow>, rusqlite::Error> {
                let r = c
                    .query_row(
                        "SELECT peer_device_id, direction, state, last_action, last_signal_id, last_created_at_ms, last_received_at_ms, invited_at_ms, accepted_at_ms, offer_seen_at_ms, answer_seen_at_ms, reconnecting_at_ms, ended_at_ms, expires_at_ms FROM call_sessions WHERE participant_device_id = ?1 AND call_id = ?2 AND call_attempt_id = ?3",
                        params![device_id, call_id, call_attempt_id],
                        |row| {
                            Ok(CallSessionRow {
                                peer_device_id: row.get(0)?,
                                direction: row.get(1)?,
                                state: row.get(2)?,
                                last_action: row.get(3)?,
                                last_signal_id: row.get(4)?,
                                last_created_at_ms: row.get(5)?,
                                last_received_at_ms: row.get(6)?,
                                invited_at_ms: row.get(7)?,
                                accepted_at_ms: row.get(8)?,
                                offer_seen_at_ms: row.get(9)?,
                                answer_seen_at_ms: row.get(10)?,
                                reconnecting_at_ms: row.get(11)?,
                                ended_at_ms: row.get(12)?,
                                expires_at_ms: row.get(13)?,
                            })
                        },
                    )
                    .optional()?;
                Ok(r)
            })
            .await
            .map_err(|e| e.to_string())?;

        Ok(row)
    }

    pub async fn ack(&self, device_id: &str, seq: u64, now_ms: i64) -> Result<(), String> {
        let device_id_owned = device_id.to_string();
        self.cleanup_expired(now_ms).await?;
        let seq_i64 = seq as i64;
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "DELETE FROM pending WHERE device_id = ?1 AND seq = ?2",
                    params![device_id_owned, seq_i64],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    /// FIX-2 (one-way blackout recovery): migrate every UN-ACKed pending message
    /// from a rotated-away device (`old`) into the live device's (`new`) mailbox,
    /// re-keying them to fresh tail seqs so `new`'s normal FetchPending drains
    /// them. Without this, messages a peer queued for `old` while the user was
    /// offline (before the rotation) sit unread until the 7-day TTL and are lost.
    /// Caller MUST have already verified that `old` and `new` share a profile.
    /// Returns how many messages were moved. Transactional + idempotent (a second
    /// run finds `old` empty and moves 0).
    pub async fn rebind_pending(&self, old: &str, new: &str) -> Result<u64, String> {
        if old == new || old.is_empty() || new.is_empty() {
            return Ok(0);
        }
        let old = old.to_string();
        let new = new.to_string();
        let moved = self
            .conn
            .call(move |c| -> Result<u64, rusqlite::Error> {
                let tx = c.transaction()?;
                tx.execute(
                    "INSERT OR IGNORE INTO device_state(device_id, next_seq) VALUES(?1, 1)",
                    params![new],
                )?;
                let mut next_seq: i64 = tx.query_row(
                    "SELECT next_seq FROM device_state WHERE device_id = ?1",
                    params![new],
                    |r| r.get(0),
                )?;
                // Read old's pending in delivery order. `deliver_at_ms` MUST be
                // carried across — otherwise a held scheduled message rebound to
                // the new device takes the column DEFAULT 0 and fires early.
                // `from_device_id` is carried for the same reason: a moved row
                // must still tell the recipient who really sent it (С-1).
                let rows: Vec<(String, String, Option<String>, i64, i64, Option<String>)> = {
                    let mut stmt = tx.prepare(
                        "SELECT msg_id, ciphertext_b64, transport_meta_json, expires_at_ms, deliver_at_ms, from_device_id \
                         FROM pending WHERE device_id = ?1 ORDER BY seq ASC",
                    )?;
                    let mapped = stmt.query_map(params![old], |r| {
                        Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?, r.get(5)?))
                    })?;
                    let mut v = Vec::new();
                    for m in mapped {
                        v.push(m?);
                    }
                    v
                };
                let mut moved: u64 = 0;
                for (msg_id, ciphertext, meta, exp, deliver_at, from_dev) in rows {
                    // OR IGNORE: if `new` already holds this msg_id (rare), skip it
                    // rather than colliding; the seq for the next one is reused.
                    let changed = tx.execute(
                        "INSERT OR IGNORE INTO pending(device_id, seq, msg_id, ciphertext_b64, transport_meta_json, expires_at_ms, deliver_at_ms, from_device_id) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                        params![new, next_seq, msg_id, ciphertext, meta, exp, deliver_at, from_dev],
                    )?;
                    if changed > 0 {
                        next_seq += 1;
                        moved += 1;
                    }
                }
                tx.execute(
                    "UPDATE device_state SET next_seq = ?2 WHERE device_id = ?1",
                    params![new, next_seq],
                )?;
                tx.execute("DELETE FROM pending WHERE device_id = ?1", params![old])?;
                tx.execute(
                    "DELETE FROM device_state WHERE device_id = ?1",
                    params![old],
                )?;
                tx.commit()?;
                Ok(moved)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(moved)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CALL_SESSION_ACTIVE_TTL_SECONDS: u32 = 6 * 60 * 60;
    const CALL_SESSION_TERMINAL_TTL_SECONDS: u32 = 15 * 60;

    async fn record_call_signal_ok(
        store: &RelayStore,
        from_device_id: &str,
        to_device_id: &str,
        signal: &CallSignalRecord,
        now_ms: i64,
    ) -> bool {
        store
            .record_call_signal(
                from_device_id,
                to_device_id,
                signal,
                CALL_SESSION_ACTIVE_TTL_SECONDS,
                CALL_SESSION_TERMINAL_TTL_SECONDS,
                now_ms,
            )
            .await
            .unwrap()
    }

    /// РЕЖИМ ЖУРНАЛА БАЗЫ (правка 02.09.2026, аудит задержки доставки).
    ///
    /// База открывалась с настройками по умолчанию: журнал отката и
    /// `synchronous=FULL`, то есть fsync на КАЖДОМ коммите. Кадр доставки
    /// уходит получателю только после коммита, и на обычном диске это от одной
    /// до двадцати миллисекунд на конверт — при всплеске единственная точка,
    /// где сериализуется вся доставка, потому что соединение одно на процесс.
    ///
    /// Тест закрепляет именно ВКЛЮЧЕНИЕ: молчаливый возврат к прежнему режиму
    /// — например, если строку с PRAGMA переставят после создания таблиц или
    /// потеряют при слиянии — иначе выглядел бы как «всё работает», просто
    /// медленнее прежнего и без единого признака в логах.
    #[tokio::test]
    async fn open_enables_wal_and_relaxed_sync() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let (journal_mode, synchronous): (String, i64) = store
            .conn
            .call(|c| -> Result<(String, i64), rusqlite::Error> {
                let mode: String = c.query_row("PRAGMA journal_mode", [], |r| r.get(0))?;
                let sync: i64 = c.query_row("PRAGMA synchronous", [], |r| r.get(0))?;
                Ok((mode, sync))
            })
            .await
            .unwrap();

        assert_eq!(
            journal_mode.to_ascii_lowercase(),
            "wal",
            "без WAL каждый конверт снова ждёт fsync журнала отката"
        );
        assert_eq!(
            synchronous, 1,
            "synchronous=NORMAL (1). FULL (2) возвращает fsync на каждый коммит, \
             а OFF (0) — это уже потеря целостности, чего размен не предполагал"
        );

        // Файл рядом с базой — прямое подтверждение, что режим не только
        // объявлен, но и применён к этому файлу.
        assert!(
            path.with_extension("db-wal").exists()
                || std::fs::read_dir(dir.path())
                    .unwrap()
                    .filter_map(|e| e.ok())
                    .any(|e| e.file_name().to_string_lossy().ends_with("-wal")),
            "WAL-файл рядом с базой не появился"
        );
    }

    #[tokio::test]
    async fn support_ticket_and_reply_roundtrip() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();
        let now = 2_000_000i64;

        store
            .support_ticket_insert("t1", "prof-A", "dev-A", "RPUB", "CIPHER1", Some("{\"b\":\"400\"}"), now)
            .await
            .unwrap();
        store
            .support_ticket_insert("t2", "prof-A", "dev-A", "RPUB", "CIPHER2", None, now + 1)
            .await
            .unwrap();
        // INSERT OR IGNORE: a duplicate ticket_id must not overwrite.
        store
            .support_ticket_insert("t1", "prof-A", "dev-A", "RPUB", "DUP", None, now + 2)
            .await
            .unwrap();

        let admin = store.list_support_tickets(0, 100).await.unwrap();
        assert_eq!(admin.len(), 2, "two distinct tickets");
        assert_eq!(admin[0].ticket_id, "t2", "newest first");
        assert_eq!(admin[1].ciphertext_b64, "CIPHER1", "original not clobbered by dup");
        assert_eq!(
            store.list_support_tickets(now, 100).await.unwrap().len(),
            1,
            "since-cursor excludes the oldest"
        );

        let (pid, did) = store.support_ticket_target("t1").await.unwrap().unwrap();
        assert_eq!((pid.as_str(), did.as_str()), ("prof-A", "dev-A"));
        assert!(store.support_ticket_target("nope").await.unwrap().is_none());

        let s1 = store
            .support_reply_insert("r1", "t1", "prof-A", "REPLY1", now + 10)
            .await
            .unwrap();
        let s2 = store
            .support_reply_insert("r2", "t2", "prof-A", "REPLY2", now + 11)
            .await
            .unwrap();
        assert_eq!((s1, s2), (1, 2), "per-profile seq is monotonic");

        let all = store.list_support_replies_from("prof-A", 0, 100).await.unwrap();
        assert_eq!(
            all.iter().map(|r| r.ciphertext_b64.as_str()).collect::<Vec<_>>(),
            vec!["REPLY1", "REPLY2"],
            "poll from 0 returns both in seq order"
        );
        let after = store.list_support_replies_from("prof-A", 1, 100).await.unwrap();
        assert_eq!(after.len(), 1);
        assert_eq!(after[0].seq, 2, "cursor skips already-seen replies");
        assert!(
            store.list_support_replies_from("prof-B", 0, 100).await.unwrap().is_empty(),
            "replies are per-profile"
        );

        // 🔴 ОЧИСТКА ПЕРЕПИСКИ ИЗ АДМИНКИ. Это удаление данных, поэтому
        // проверяется и что стёрлось нужное, и что НЕ стёрлось чужое.
        assert_eq!(
            store.support_cleared_at("prof-A").await.unwrap(),
            0,
            "до очистки отметки нет"
        );
        let removed = store
            .support_clear_profile("prof-A", now + 500)
            .await
            .unwrap();
        assert_eq!(removed, 4, "два тикета и два ответа");
        assert!(
            store.list_support_replies_from("prof-A", 0, 100).await.unwrap().is_empty(),
            "ответы стёрты"
        );
        assert!(
            store.support_ticket_target("t1").await.unwrap().is_none(),
            "тикеты стёрты"
        );
        assert_eq!(
            store.support_cleared_at("prof-A").await.unwrap(),
            now + 500,
            "отметка времени — единственный способ сообщить телефону об очистке"
        );

        // 🔴 Чужая переписка не пострадала.
        store
            .support_ticket_insert(
                "t9", "prof-B", "dev-B", "PUBB", "CIPHER9", None, now + 600,
            )
            .await
            .unwrap();
        store
            .support_clear_profile("prof-A", now + 700)
            .await
            .unwrap();
        assert!(
            store.support_ticket_target("t9").await.unwrap().is_some(),
            "очистка одного профиля не трогает другой"
        );
        assert_eq!(
            store.support_cleared_at("prof-B").await.unwrap(),
            0,
            "и не ставит чужую отметку"
        );

        // Повторная очистка пустой переписки безобидна и обновляет отметку.
        let again = store
            .support_clear_profile("prof-A", now + 800)
            .await
            .unwrap();
        assert_eq!(again, 0);
        assert_eq!(store.support_cleared_at("prof-A").await.unwrap(), now + 800);
    }

    #[tokio::test]
    async fn enqueue_dedup_returns_same_seq() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_000_000i64;
        let a = store
            .enqueue("dev1", "msg1", "QUJD", None, 60, now)
            .await
            .unwrap();
        let b = store
            .enqueue("dev1", "msg1", "QUJD", None, 60, now)
            .await
            .unwrap();

        assert_eq!(a.seq, 1);
        assert_eq!(b.seq, 1);
        assert_eq!(a.dedup, false);
        assert_eq!(b.dedup, true);
    }

    #[tokio::test]
    async fn ack_removes_pending() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_000_000i64;
        let enq = store
            .enqueue("dev1", "msg1", "QUJD", None, 60, now)
            .await
            .unwrap();
        assert_eq!(enq.seq, 1);

        let pending1 = store.list_pending_from("dev1", 1, now, 10).await.unwrap();
        assert_eq!(pending1.len(), 1);

        store.ack("dev1", 1, now).await.unwrap();

        let pending2 = store.list_pending_from("dev1", 1, now, 10).await.unwrap();
        assert_eq!(pending2.len(), 0);
    }

    /// DELIVERY JOURNAL (2026-08-01): the drain log distinguishes a mailbox
    /// that is FLOWING from one that is STUCK, and warns before a message is
    /// dropped for good. Both readings come from these two columns, so if they
    /// are wrong the journal does not merely go quiet — it lies, which is worse
    /// than the silence it was built to fix. Pinned here rather than trusted.
    #[tokio::test]
    async fn pending_rows_carry_attempt_and_expiry_for_the_delivery_journal() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();
        let now = 1_000_000i64;
        let ttl_secs = 60u32;

        store
            .enqueue("dev1", "msg1", "QUJD", None, ttl_secs, now)
            .await
            .unwrap();

        let fresh = store.list_pending_from("dev1", 1, now, 10).await.unwrap();
        assert_eq!(fresh.len(), 1);
        // 🔴 The trap this test exists for: `enqueue` COUNTS ITSELF as the first
        // delivery attempt, so a brand-new row reads the enqueue time — NOT 0.
        // A "first offer vs re-offer" count built on `last_attempt_ms > 0` would
        // therefore report 100% re-offers on a perfectly healthy mailbox. The
        // journal reports AGE instead, and this assertion is what forces that.
        assert_eq!(
            fresh[0].last_attempt_ms, now,
            "enqueue stamps itself as attempt #1; a 0 here would mean the journal \
             could distinguish first offers, and it cannot"
        );
        assert_eq!(
            fresh[0].expires_at_ms,
            now + (ttl_secs as i64) * 1000,
            "expiry must be the real TTL so 'about to be dropped' is truthful"
        );

        // A freshly enqueued row must read as ~no wait, or every healthy drain
        // would look alarming.
        assert_eq!(
            now.saturating_sub(fresh[0].last_attempt_ms),
            0,
            "flowing mail must report zero wait"
        );

        // Offered again and still unacked: the wait the journal reports must
        // track the LAST offer, which is what makes a stuck mailbox visible.
        let offered_at = now + 5_000;
        store
            .mark_pending_attempted("dev1", vec![1], offered_at)
            .await
            .unwrap();
        let later = offered_at + 45_000;
        let stuck = store.list_pending_from("dev1", 1, later, 10).await.unwrap();
        assert_eq!(stuck.len(), 1);
        assert_eq!(
            later.saturating_sub(stuck[0].last_attempt_ms),
            45_000,
            "wait must be measured from the last offer, not from enqueue"
        );

        // The redelivery sweep reads the same two columns; if it did not, the
        // one path that only ever sees stuck mail would report nothing useful.
        let sweep = store
            .list_pending_for_redelivery("dev1", 1_000, later, 10)
            .await
            .unwrap();
        assert_eq!(sweep.len(), 1);
        assert_eq!(sweep[0].last_attempt_ms, offered_at);
        assert_eq!(sweep[0].expires_at_ms, now + (ttl_secs as i64) * 1000);
    }

    #[tokio::test]
    async fn redeliver_backoff_retries_unacked_until_ack() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();
        let now = 1_000_000i64;
        let backoff = 30_000i64;

        let enq = store
            .enqueue("dev1", "msg1", "QUJD", None, 600, now)
            .await
            .unwrap();
        assert_eq!(enq.seq, 1);

        // Just enqueued (last_attempt = now) → within backoff, not re-sent.
        let r0 = store
            .list_pending_for_redelivery("dev1", backoff, now, 10)
            .await
            .unwrap();
        assert!(r0.is_empty(), "fresh message must not re-send within backoff");

        // After the backoff, the still-unacked row is eligible.
        let r1 = store
            .list_pending_for_redelivery("dev1", backoff, now + backoff + 1, 10)
            .await
            .unwrap();
        assert_eq!(r1.len(), 1);
        assert_eq!(r1[0].seq, 1);

        // Marking the attempt restarts the backoff.
        store
            .mark_pending_attempted("dev1", vec![1], now + backoff + 1)
            .await
            .unwrap();
        let r2 = store
            .list_pending_for_redelivery("dev1", backoff, now + backoff + 2, 10)
            .await
            .unwrap();
        assert!(r2.is_empty(), "just re-sent → back off before next retry");

        // Still unacked one backoff later → retried again.
        let r3 = store
            .list_pending_for_redelivery("dev1", backoff, now + 2 * backoff + 2, 10)
            .await
            .unwrap();
        assert_eq!(r3.len(), 1);

        // Once acked, the row is gone → never re-sent.
        store.ack("dev1", 1, now + 2 * backoff + 3).await.unwrap();
        let r4 = store
            .list_pending_for_redelivery("dev1", backoff, now + 10 * backoff, 10)
            .await
            .unwrap();
        assert!(r4.is_empty(), "acked message must never be re-sent");
    }

    #[tokio::test]
    async fn redeliver_covers_above_cursor_unacked_gap() {
        // The airplane-mode strand: the client acks a NEWER message (advancing
        // its cursor) but drops an OLDER one. The old below-cursor-only sweep
        // skipped it; the reliable-delivery query must still return it so it is
        // retried until acked — independent of cursor position.
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();
        let now = 1_000_000i64;
        let backoff = 30_000i64;

        store.enqueue("dev1", "m1", "QQ", None, 600, now).await.unwrap();
        store.enqueue("dev1", "m2", "Qg", None, 600, now).await.unwrap();
        // Ack the newer message; the older one is dropped/unacked.
        store.ack("dev1", 2, now).await.unwrap();

        let r = store
            .list_pending_for_redelivery("dev1", backoff, now + backoff + 1, 10)
            .await
            .unwrap();
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].seq, 1);
        assert_eq!(r[0].msg_id, "m1");
    }

    #[tokio::test]
    async fn pending_message_count_excludes_control_envelopes() {
        // BADGE FIX: one user message enqueues the chat row PLUS a couple of
        // control envelopes (receipts / session-heal / self-mirror) that carry no
        // chat transport_meta. pending_count counts them all (badge showed 3 for
        // one message); pending_message_count counts only chat messages.
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();
        let now = 1_000_000i64;

        store
            .enqueue(
                "dev1",
                "m1",
                "QQ",
                Some(
                    r#"{"kind":"chat_message_v1","message":{"convo_id":"c","message_kind":"text","payload_event_id":"e1","created_at_ms":1}}"#,
                ),
                600,
                now,
            )
            .await
            .unwrap();
        // Control envelope with no transport_meta (the "<none>" rows seen in prod).
        store
            .enqueue("dev1", "m2", "Qg", None, 600, now)
            .await
            .unwrap();
        // A session-heal control wire.
        store
            .enqueue("dev1", "m3", "Qw", Some(r#"{"kind":"session_heal_v1"}"#), 600, now)
            .await
            .unwrap();

        // Whole mailbox = 3, but only ONE is a chat message → badge shows 1.
        assert_eq!(store.pending_count("dev1", now + 1).await.unwrap(), 3);
        assert_eq!(
            store.pending_message_count("dev1", now + 1).await.unwrap(),
            1
        );
    }

    #[tokio::test]
    async fn migration_adds_last_attempt_ms_to_existing_pending_table() {
        // Regression for the deploy that health-check-failed + rolled back: on an
        // EXISTING database the `pending` table has no `last_attempt_ms`, so a
        // base-schema `CREATE INDEX ... (last_attempt_ms)` referenced a missing
        // column and panicked at startup. Opening an old-schema DB must migrate
        // cleanly (fresh-DB tests never exercised this path).
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        {
            let c = rusqlite::Connection::open(&path).unwrap();
            c.execute_batch(
                "CREATE TABLE pending (
                    device_id TEXT NOT NULL,
                    seq INTEGER NOT NULL,
                    msg_id TEXT NOT NULL,
                    ciphertext_b64 TEXT NOT NULL,
                    transport_meta_json TEXT,
                    expires_at_ms INTEGER NOT NULL,
                    PRIMARY KEY(device_id, seq),
                    UNIQUE(device_id, msg_id)
                );
                INSERT INTO pending(device_id, seq, msg_id, ciphertext_b64, expires_at_ms)
                VALUES('dev1', 4, 'oldmsg', 'QUJD', 9999999999999);",
            )
            .unwrap();
        }

        // Must NOT panic — runs the ADD COLUMN migration + the post-migration index.
        let store = RelayStore::open(&path).await.unwrap();

        // The pre-existing row (last_attempt_ms defaulted to 0) is eligible for
        // redelivery, proving both the column and the query work post-migration.
        let r = store
            .list_pending_for_redelivery("dev1", 30_000, 1_000_000, 10)
            .await
            .unwrap();
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].msg_id, "oldmsg");
    }

    #[tokio::test]
    async fn rebind_pending_moves_old_mailbox_to_new_and_is_idempotent() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();
        let now = 1_000_000i64;

        // A1 (rotated-away) holds two un-acked messages; A2 (live) has one.
        store.enqueue("A1", "m1", "QQ", None, 600, now).await.unwrap();
        store.enqueue("A1", "m2", "Qg", None, 600, now).await.unwrap();
        store.enqueue("A2", "m3", "Qw", None, 600, now).await.unwrap();

        let moved = store.rebind_pending("A1", "A2").await.unwrap();
        assert_eq!(moved, 2);

        // A1 drained; A2 now holds all three (its own + the two moved).
        assert_eq!(store.list_pending_from("A1", 1, now, 10).await.unwrap().len(), 0);
        assert_eq!(store.list_pending_from("A2", 1, now, 10).await.unwrap().len(), 3);

        // Idempotent: a second run finds A1 empty and moves nothing.
        assert_eq!(store.rebind_pending("A1", "A2").await.unwrap(), 0);

        // Self-rebind is a no-op.
        assert_eq!(store.rebind_pending("A2", "A2").await.unwrap(), 0);
    }

    // SERVER-SIDE SCHEDULED DELIVERY (2026-07-17): a scheduled row is held
    // until its release time — invisible to every delivery query before T,
    // and delivered exactly once after T, without the sender ever waking.
    #[tokio::test]
    async fn pending_row_carries_the_authenticated_sender() {
        // ИД-1 / С-1 (17.09.2026): the sender is stored with the row, read back
        // by both delivery queries and moved along on a device rebind.
        let dir = tempfile::tempdir().unwrap();
        let store = RelayStore::open(dir.path().join("relay.db")).await.unwrap();
        let now = 1_700_000_000_000_i64;
        store
            .enqueue_scheduled(
                "R1",
                "m-attested",
                "QQ",
                None,
                604_800,
                now,
                0,
                Some(" S1 "),
            )
            .await
            .unwrap();
        store
            .enqueue("R1", "m-legacy", "Qg", None, 604_800, now)
            .await
            .unwrap();
        let rows = store.list_pending_from("R1", 1, now, 10).await.unwrap();
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].from_device_id.as_deref(), Some("S1"));
        assert_eq!(rows[1].from_device_id, None);
        let redeliver = store
            .list_pending_for_redelivery("R1", -1, now + 1, 10)
            .await
            .unwrap();
        assert_eq!(redeliver[0].from_device_id.as_deref(), Some("S1"));
    }

    #[tokio::test]
    async fn scheduled_row_is_held_until_release_then_delivered() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();
        let now = 1_000_000i64;
        let deliver_at = now + 60_000; // +60s

        // Upload at schedule time (sender awake), release 60s later.
        store
            .enqueue_scheduled("D1", "sched1", "QQ", None, 604_800, now, deliver_at, None)
            .await
            .unwrap();
        // An ordinary message enqueued right after must deliver immediately.
        store
            .enqueue("D1", "now1", "Qg", None, 600, now)
            .await
            .unwrap();

        // BEFORE T: only the immediate message is visible to every path.
        let before = store
            .list_pending_from("D1", 1, now + 1_000, 10)
            .await
            .unwrap();
        assert_eq!(before.len(), 1, "scheduled row must be hidden before T");
        assert_eq!(before[0].msg_id, "now1");
        assert!(
            store
                .list_pending_for_redelivery("D1", 0, now + 1_000, 10)
                .await
                .unwrap()
                .iter()
                .all(|r| r.msg_id != "sched1"),
            "redelivery must not resurface a not-yet-due scheduled row"
        );
        // Offline re-wake must not target a device whose ONLY new row is future.
        // (Here "now1" keeps it a candidate, but the meta/consideration excludes
        //  the scheduled row; assert the fresh-due query sees nothing yet.)
        assert!(
            store
                .list_devices_with_freshly_due_scheduled(now + 1_000, 0)
                .await
                .unwrap()
                .is_empty(),
            "nothing is freshly due before T"
        );

        // AT/AFTER T: the scheduled row becomes visible and is reported freshly
        // due exactly once for the release window.
        let after = store.list_pending_from("D1", 1, deliver_at + 10, 10).await.unwrap();
        assert_eq!(after.len(), 2, "scheduled row visible after T");
        assert!(after.iter().any(|r| r.msg_id == "sched1"));

        let fresh = store
            .list_devices_with_freshly_due_scheduled(deliver_at + 10, now + 1_000)
            .await
            .unwrap();
        assert_eq!(fresh.len(), 1, "device reported freshly-due once at release");
        assert_eq!(fresh[0].device_id, "D1");

        // A second scan whose window starts AFTER T no longer reports it (no
        // double release).
        assert!(
            store
                .list_devices_with_freshly_due_scheduled(deliver_at + 20, deliver_at + 11)
                .await
                .unwrap()
                .is_empty(),
            "release fires once, not every tick"
        );
    }

    // REGRESSION (2026-07-18): re-submitting a STILL-HELD scheduled msg_id as an
    // IMMEDIATE send (a client outbox re-kick / retry, which every normal send
    // triggers) must not release it early. The send handlers gate realtime
    // delivery on the STORED release time reported here; trusting the incoming
    // request instead is what made a scheduled message fire the moment the user
    // sent their NEXT message.
    #[tokio::test]
    async fn resubmitting_scheduled_msg_id_as_immediate_does_not_release_it() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();
        let now = 1_000_000i64;
        let deliver_at = now + 60_000; // +60s

        let first = store
            .enqueue_scheduled("D1", "sched1", "QQ", None, 604_800, now, deliver_at, None)
            .await
            .unwrap();
        assert!(!first.dedup);
        assert_eq!(
            first.deliver_at_ms, deliver_at,
            "a fresh scheduled insert reports its own hold"
        );

        // The client re-kicks its outbox and re-sends the SAME msg_id — this
        // time as an ordinary immediate message (deliver_at_ms = 0).
        let again = store
            .enqueue_scheduled("D1", "sched1", "QQ", None, 604_800, now + 5_000, 0, None)
            .await
            .unwrap();
        assert!(
            again.dedup,
            "same msg_id dedups instead of inserting a 2nd row"
        );
        assert_eq!(again.seq, first.seq, "dedup returns the held row's seq");
        assert_eq!(
            again.deliver_at_ms, deliver_at,
            "dedup MUST report the STORED hold so the handler holds instead of delivering early"
        );

        // The row stays invisible to every delivery path before T.
        let before = store
            .list_pending_from("D1", 1, now + 10_000, 10)
            .await
            .unwrap();
        assert!(
            before.iter().all(|r| r.msg_id != "sched1"),
            "scheduled row must stay hidden after an immediate re-submit"
        );

        // …and still releases normally at T.
        let after = store
            .list_pending_from("D1", 1, deliver_at + 10, 10)
            .await
            .unwrap();
        assert!(
            after.iter().any(|r| r.msg_id == "sched1"),
            "held row still releases at T"
        );
    }

    // Cancel a scheduled row before its time; a released one cannot be unsent.
    #[tokio::test]
    async fn cancel_scheduled_only_removes_future_rows() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();
        let now = 1_000_000i64;

        store
            .enqueue_scheduled("C1", "future", "QQ", None, 604_800, now, now + 60_000, None)
            .await
            .unwrap();

        // Before T: cancel succeeds and the row is gone.
        assert!(store.cancel_scheduled("C1", "future", now).await.unwrap());
        assert!(
            store.list_pending_from("C1", 1, now + 120_000, 10).await.unwrap().is_empty()
        );

        // After T (simulated by passing a now past deliver_at): cancel refuses.
        store
            .enqueue_scheduled(
                "C1",
                "released",
                "Qg",
                None,
                604_800,
                now,
                now + 60_000,
                None,
            )
            .await
            .unwrap();
        assert!(
            !store
                .cancel_scheduled("C1", "released", now + 90_000)
                .await
                .unwrap(),
            "a released row must not be cancellable"
        );
    }

    #[tokio::test]
    async fn enqueue_dedup_persists_after_ack_until_window_expires() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_000_000i64;
        let first = store
            .enqueue("dev1", "msg1", "QUJD", None, 60, now)
            .await
            .unwrap();
        assert_eq!(first.seq, 1);
        assert!(!first.dedup);

        store.ack("dev1", 1, now).await.unwrap();

        let second = store
            .enqueue("dev1", "msg1", "QUJD", None, 60, now + 5_000)
            .await
            .unwrap();
        assert_eq!(second.seq, 1);
        assert!(second.dedup);

        let pending = store
            .list_pending_from("dev1", 1, now + 5_000, 10)
            .await
            .unwrap();
        assert!(pending.is_empty());
    }

    #[tokio::test]
    async fn push_token_stats_counts_platforms_and_recent_updates() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();
        let now = 10_000_000_000i64;

        store
            .upsert_push_token("dev-android", "token-a", "android", None, now)
            .await
            .unwrap();
        store
            .upsert_push_token("dev-ios", "token-i", "ios", None, now - 1_000)
            .await
            .unwrap();
        store
            .upsert_push_token("dev-ios", "token-v", "ios_voip", None, now - 500)
            .await
            .unwrap();
        store
            .upsert_push_token(
                "dev-web",
                "token-w",
                "web",
                None,
                now - 2 * 24 * 60 * 60 * 1000,
            )
            .await
            .unwrap();

        let stats = store.push_token_stats(now).await.unwrap();

        assert_eq!(stats.total, 4);
        assert_eq!(stats.android, 1);
        assert_eq!(stats.ios, 1);
        assert_eq!(stats.ios_voip, 1);
        assert_eq!(stats.unsupported, 1);
        assert_eq!(stats.updated_last_24h, 3);
    }

    #[tokio::test]
    async fn enqueue_allows_reuse_after_dedup_window_expires() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_000_000i64;
        let first = store
            .enqueue("dev1", "msg1", "QUJD", None, 60, now)
            .await
            .unwrap();
        assert_eq!(first.seq, 1);

        store.ack("dev1", 1, now).await.unwrap();

        let later = now + MESSAGE_DEDUP_MIN_TTL_MS + 1;
        let second = store
            .enqueue("dev1", "msg1", "QUJD", None, 60, later)
            .await
            .unwrap();
        assert_eq!(second.seq, 2);
        assert!(!second.dedup);
    }

    #[tokio::test]
    async fn ttl_cleanup_drops_expired() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_000_000i64;
        let _ = store
            .enqueue("dev1", "msg1", "QUJD", None, 1, now)
            .await
            .unwrap();

        // After 1500ms the ttl=1s message must be expired.
        let later = now + 1500;
        let pending = store.list_pending_from("dev1", 1, later, 10).await.unwrap();
        assert_eq!(pending.len(), 0);
    }

    #[tokio::test]
    async fn persists_across_restart() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");

        {
            let store = RelayStore::open(&path).await.unwrap();
            let now = 1_000_000i64;
            let _ = store
                .enqueue("dev1", "msg1", "QUJD", None, 60, now)
                .await
                .unwrap();
        }

        let store2 = RelayStore::open(&path).await.unwrap();
        let pending = store2
            .list_pending_from("dev1", 1, 1_000_000i64, 10)
            .await
            .unwrap();
        assert_eq!(pending.len(), 1);
        assert_eq!(pending[0].seq, 1);
        assert_eq!(pending[0].msg_id, "msg1");
    }

    #[tokio::test]
    async fn call_signal_dedup_and_session_state_roundtrip() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_000_000i64;
        let signal = CallSignalRecord {
            action: "invite".into(),
            call_id: "call-1".into(),
            call_attempt_id: "attempt-1".into(),
            signal_id: "signal-1".into(),
            created_at_ms: now,
        };

        assert!(record_call_signal_ok(&store, "sender-dev", "receiver-dev", &signal, now).await);
        assert!(
            !record_call_signal_ok(&store, "sender-dev", "receiver-dev", &signal, now + 10).await
        );

        let inbound = store
            .get_call_session("receiver-dev", "call-1", "attempt-1", now + 20)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(inbound.direction, "incoming");
        assert_eq!(inbound.state, "ringing");
        assert_eq!(inbound.last_signal_id, "signal-1");
    }

    #[tokio::test]
    async fn answer_promotes_call_session_to_accepted() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_000_000i64;
        let invite = CallSignalRecord {
            action: "invite".into(),
            call_id: "call-accepted".into(),
            call_attempt_id: "attempt-1".into(),
            signal_id: "signal-invite".into(),
            created_at_ms: now,
        };
        let answer = CallSignalRecord {
            action: "answer".into(),
            call_id: "call-accepted".into(),
            call_attempt_id: "attempt-1".into(),
            signal_id: "signal-answer".into(),
            created_at_ms: now + 500,
        };

        assert!(record_call_signal_ok(&store, "sender-dev", "receiver-dev", &invite, now).await);
        assert!(
            record_call_signal_ok(&store, "receiver-dev", "sender-dev", &answer, now + 500).await
        );

        let outbound = store
            .get_call_session("sender-dev", "call-accepted", "attempt-1", now + 700)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(outbound.state, "accepted");
        assert_eq!(outbound.last_action, "answer");
        assert_eq!(outbound.accepted_at_ms, Some(now + 500));
        assert_eq!(outbound.answer_seen_at_ms, Some(now + 500));
    }

    #[tokio::test]
    async fn stale_call_signal_does_not_revive_ended_session() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_000_000i64;
        let invite = CallSignalRecord {
            action: "invite".into(),
            call_id: "call-2".into(),
            call_attempt_id: "attempt-2".into(),
            signal_id: "signal-invite".into(),
            created_at_ms: now,
        };
        let hangup = CallSignalRecord {
            action: "hangup".into(),
            call_id: "call-2".into(),
            call_attempt_id: "attempt-2".into(),
            signal_id: "signal-hangup".into(),
            created_at_ms: now + 500,
        };
        let stale_offer = CallSignalRecord {
            action: "offer".into(),
            call_id: "call-2".into(),
            call_attempt_id: "attempt-2".into(),
            signal_id: "signal-offer-stale".into(),
            created_at_ms: now + 100,
        };

        record_call_signal_ok(&store, "sender-dev", "receiver-dev", &invite, now).await;
        record_call_signal_ok(&store, "sender-dev", "receiver-dev", &hangup, now + 500).await;
        record_call_signal_ok(
            &store,
            "sender-dev",
            "receiver-dev",
            &stale_offer,
            now + 700,
        )
        .await;

        let inbound = store
            .get_call_session("receiver-dev", "call-2", "attempt-2", now + 800)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(inbound.state, "ended");
        assert_eq!(inbound.last_action, "hangup");
    }

    #[tokio::test]
    async fn stale_older_attempt_signal_does_not_override_newer_attempt_session() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_000_000i64;
        let older_invite = CallSignalRecord {
            action: "invite".into(),
            call_id: "call-3".into(),
            call_attempt_id: "attempt-old".into(),
            signal_id: "signal-old-invite".into(),
            created_at_ms: now,
        };
        let newer_invite = CallSignalRecord {
            action: "invite".into(),
            call_id: "call-3".into(),
            call_attempt_id: "attempt-new".into(),
            signal_id: "signal-new-invite".into(),
            created_at_ms: now + 500,
        };
        let stale_older_hangup = CallSignalRecord {
            action: "hangup".into(),
            call_id: "call-3".into(),
            call_attempt_id: "attempt-old".into(),
            signal_id: "signal-old-hangup".into(),
            created_at_ms: now + 100,
        };

        record_call_signal_ok(&store, "sender-dev", "receiver-dev", &older_invite, now).await;
        record_call_signal_ok(
            &store,
            "sender-dev",
            "receiver-dev",
            &newer_invite,
            now + 500,
        )
        .await;
        record_call_signal_ok(
            &store,
            "sender-dev",
            "receiver-dev",
            &stale_older_hangup,
            now + 700,
        )
        .await;

        let newer_inbound = store
            .get_call_session("receiver-dev", "call-3", "attempt-new", now + 800)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(newer_inbound.state, "ringing");
        assert_eq!(newer_inbound.last_action, "invite");

        let older_inbound = store
            .get_call_session("receiver-dev", "call-3", "attempt-old", now + 800)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(older_inbound.state, "ended");
        assert_eq!(older_inbound.last_action, "superseded");
        assert_eq!(older_inbound.ended_at_ms, Some(now + 500));
    }

    #[tokio::test]
    async fn reusing_signal_id_across_attempts_is_rejected() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_000_000i64;
        let first_attempt_signal = CallSignalRecord {
            action: "invite".into(),
            call_id: "call-4".into(),
            call_attempt_id: "attempt-1".into(),
            signal_id: "signal-shared".into(),
            created_at_ms: now,
        };
        let replayed_other_attempt_signal = CallSignalRecord {
            action: "invite".into(),
            call_id: "call-4".into(),
            call_attempt_id: "attempt-2".into(),
            signal_id: "signal-shared".into(),
            created_at_ms: now + 100,
        };

        assert!(
            record_call_signal_ok(
                &store,
                "sender-dev",
                "receiver-dev",
                &first_attempt_signal,
                now,
            )
            .await
        );
        assert!(
            !record_call_signal_ok(
                &store,
                "sender-dev",
                "receiver-dev",
                &replayed_other_attempt_signal,
                now + 100,
            )
            .await
        );

        let second_attempt = store
            .get_call_session("receiver-dev", "call-4", "attempt-2", now + 200)
            .await
            .unwrap();
        assert!(second_attempt.is_none());
    }

    #[tokio::test]
    async fn newer_attempt_supersedes_older_active_attempt_session() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_000_000i64;
        let older_invite = CallSignalRecord {
            action: "invite".into(),
            call_id: "call-5".into(),
            call_attempt_id: "attempt-old".into(),
            signal_id: "signal-old-invite".into(),
            created_at_ms: now,
        };
        let newer_offer = CallSignalRecord {
            action: "offer".into(),
            call_id: "call-5".into(),
            call_attempt_id: "attempt-new".into(),
            signal_id: "signal-new-offer".into(),
            created_at_ms: now + 500,
        };

        record_call_signal_ok(&store, "sender-dev", "receiver-dev", &older_invite, now).await;
        record_call_signal_ok(
            &store,
            "sender-dev",
            "receiver-dev",
            &newer_offer,
            now + 500,
        )
        .await;

        let older_inbound = store
            .get_call_session("receiver-dev", "call-5", "attempt-old", now + 700)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(older_inbound.state, "ended");
        assert_eq!(older_inbound.last_action, "superseded");
        assert_eq!(older_inbound.ended_at_ms, Some(now + 500));

        let newer_inbound = store
            .get_call_session("receiver-dev", "call-5", "attempt-new", now + 700)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(newer_inbound.state, "ringing");
        assert_eq!(newer_inbound.last_action, "offer");
    }

    #[tokio::test]
    async fn active_call_session_outlives_short_signal_window() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_000_000i64;
        let signal = CallSignalRecord {
            action: "invite".into(),
            call_id: "call-6".into(),
            call_attempt_id: "attempt-1".into(),
            signal_id: "signal-1".into(),
            created_at_ms: now,
        };

        assert!(record_call_signal_ok(&store, "sender-dev", "receiver-dev", &signal, now).await);

        let after_old_signal_window = now + 95_000;
        let inbound = store
            .get_call_session(
                "receiver-dev",
                "call-6",
                "attempt-1",
                after_old_signal_window,
            )
            .await
            .unwrap()
            .unwrap();
        assert_eq!(inbound.state, "ringing");
        assert!(inbound.expires_at_ms >= now + (CALL_SESSION_ACTIVE_TTL_SECONDS as i64) * 1000);
    }

    #[tokio::test]
    async fn ended_call_session_is_not_revived_by_late_offer() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_000_000i64;
        let invite = CallSignalRecord {
            action: "invite".into(),
            call_id: "call-ended".into(),
            call_attempt_id: "attempt-1".into(),
            signal_id: "signal-invite".into(),
            created_at_ms: now,
        };
        let hangup = CallSignalRecord {
            action: "hangup".into(),
            call_id: "call-ended".into(),
            call_attempt_id: "attempt-1".into(),
            signal_id: "signal-hangup".into(),
            created_at_ms: now + 400,
        };
        let late_offer = CallSignalRecord {
            action: "offer".into(),
            call_id: "call-ended".into(),
            call_attempt_id: "attempt-1".into(),
            signal_id: "signal-offer-late".into(),
            created_at_ms: now + 900,
        };

        assert!(record_call_signal_ok(&store, "sender-dev", "receiver-dev", &invite, now).await);
        assert!(
            record_call_signal_ok(&store, "sender-dev", "receiver-dev", &hangup, now + 400).await
        );
        assert!(
            record_call_signal_ok(&store, "sender-dev", "receiver-dev", &late_offer, now + 900)
                .await
        );

        let inbound = store
            .get_call_session("receiver-dev", "call-ended", "attempt-1", now + 1000)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(inbound.state, "ended");
        assert_eq!(inbound.last_action, "hangup");
        assert_eq!(inbound.offer_seen_at_ms, None);
        assert_eq!(inbound.ended_at_ms, Some(now + 400));
    }

    #[tokio::test]
    async fn expired_active_call_session_is_finalized_as_timeout_before_deletion() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_000_000i64;
        let invite = CallSignalRecord {
            action: "invite".into(),
            call_id: "call-timeout".into(),
            call_attempt_id: "attempt-1".into(),
            signal_id: "signal-invite".into(),
            created_at_ms: now,
        };

        assert!(record_call_signal_ok(&store, "sender-dev", "receiver-dev", &invite, now).await);

        let timed_out_at_ms = now + (CALL_SESSION_ACTIVE_TTL_SECONDS as i64) * 1000;
        let timed_out = store
            .get_call_session(
                "receiver-dev",
                "call-timeout",
                "attempt-1",
                timed_out_at_ms + 1,
            )
            .await
            .unwrap()
            .unwrap();
        assert_eq!(timed_out.state, "ended");
        assert_eq!(timed_out.last_action, "timeout");
        assert_eq!(timed_out.ended_at_ms, Some(timed_out_at_ms));
        assert_eq!(
            timed_out.expires_at_ms,
            timed_out_at_ms + (CALL_SESSION_TERMINAL_TTL_SECONDS as i64) * 1000,
        );

        let expired = store
            .get_call_session(
                "receiver-dev",
                "call-timeout",
                "attempt-1",
                timed_out_at_ms + (CALL_SESSION_TERMINAL_TTL_SECONDS as i64) * 1000 + 1,
            )
            .await
            .unwrap();
        assert!(expired.is_none());
    }

    #[tokio::test]
    async fn terminal_call_session_uses_shorter_retention_than_active_session() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_000_000i64;
        let invite = CallSignalRecord {
            action: "invite".into(),
            call_id: "call-7".into(),
            call_attempt_id: "attempt-1".into(),
            signal_id: "signal-invite".into(),
            created_at_ms: now,
        };
        let hangup = CallSignalRecord {
            action: "hangup".into(),
            call_id: "call-7".into(),
            call_attempt_id: "attempt-1".into(),
            signal_id: "signal-hangup".into(),
            created_at_ms: now + 10_000,
        };

        assert!(record_call_signal_ok(&store, "sender-dev", "receiver-dev", &invite, now).await);
        assert!(
            record_call_signal_ok(&store, "sender-dev", "receiver-dev", &hangup, now + 10_000)
                .await
        );

        let still_visible = store
            .get_call_session(
                "receiver-dev",
                "call-7",
                "attempt-1",
                now + 10_000 + (CALL_SESSION_TERMINAL_TTL_SECONDS as i64) * 1000 - 1,
            )
            .await
            .unwrap();
        assert!(still_visible.is_some());

        let expired = store
            .get_call_session(
                "receiver-dev",
                "call-7",
                "attempt-1",
                now + 10_000 + (CALL_SESSION_TERMINAL_TTL_SECONDS as i64) * 1000 + 1,
            )
            .await
            .unwrap();
        assert!(expired.is_none());
    }

    #[tokio::test]
    async fn blocks_roundtrip() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_000_000i64;
        assert!(!store.is_blocked("P1", "P2").await.unwrap());

        store.set_block("P1", "P2", true, now).await.unwrap();
        assert!(store.is_blocked("P1", "P2").await.unwrap());

        let list = store.list_blocks("P1", 100).await.unwrap();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].blocked_profile_id, "P2");

        store.set_block("P1", "P2", false, now + 1).await.unwrap();
        assert!(!store.is_blocked("P1", "P2").await.unwrap());

        let list2 = store.list_blocks("P1", 100).await.unwrap();
        assert_eq!(list2.len(), 0);
    }

    #[tokio::test]
    async fn create_room_persists_authoritative_metadata() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_000_000i64;
        let created = store
            .create_room(
                "room-alpha-1",
                "profile-owner-1",
                "device-owner-1",
                "Launch Team",
                now,
            )
            .await
            .unwrap();

        assert!(created.created);
        assert_eq!(created.room.room_id, "room-alpha-1");
        assert_eq!(created.room.version, 1);
        assert_eq!(created.room.membership_version, 1);
        assert_eq!(created.room.owner_profile_id, "profile-owner-1");
        assert_eq!(created.room.created_by_device_id, "device-owner-1");
        assert_eq!(created.room.title, "Launch Team");
        assert_eq!(created.room.created_at_ms, now);
        assert_eq!(created.room.updated_at_ms, now);

        let stored = store.get_room("room-alpha-1").await.unwrap().unwrap();
        assert_eq!(stored.title, "Launch Team");
        assert_eq!(stored.owner_profile_id, "profile-owner-1");

        let members = store.list_room_memberships("room-alpha-1").await.unwrap();
        assert_eq!(members.len(), 1);
        assert_eq!(members[0].profile_id, "profile-owner-1");
        assert_eq!(members[0].status, "active");
        assert_eq!(members[0].role, "owner");
    }

    #[tokio::test]
    async fn create_room_is_idempotent_for_same_authoritative_metadata() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let first = store
            .create_room(
                "room-alpha-2",
                "profile-owner-2",
                "device-owner-2",
                "Project Atlas",
                1_700_000_000_100,
            )
            .await
            .unwrap();
        let second = store
            .create_room(
                "room-alpha-2",
                "profile-owner-2",
                "device-owner-2",
                "Project Atlas",
                1_700_000_000_900,
            )
            .await
            .unwrap();

        assert!(first.created);
        assert!(!second.created);
        assert_eq!(second.room.version, 1);
        assert_eq!(second.room.membership_version, 1);
        assert_eq!(second.room.created_at_ms, 1_700_000_000_100);
        assert_eq!(second.room.updated_at_ms, 1_700_000_000_100);
    }

    #[tokio::test]
    async fn create_room_rejects_conflicting_authoritative_metadata() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-3",
                "profile-owner-3",
                "device-owner-3",
                "Team Mercury",
                1_700_000_000_000,
            )
            .await
            .unwrap();

        let err = store
            .create_room(
                "room-alpha-3",
                "profile-owner-3",
                "device-owner-3",
                "Team Mercury v2",
                1_700_000_000_500,
            )
            .await
            .unwrap_err();

        assert!(matches!(err, CreateRoomError::Conflict(_)));

        let stored = store.get_room("room-alpha-3").await.unwrap().unwrap();
        assert_eq!(stored.title, "Team Mercury");
        assert_eq!(stored.version, 1);
        assert_eq!(stored.membership_version, 1);
    }

    #[tokio::test]
    async fn upsert_room_membership_persists_authoritative_membership_and_bumps_versions() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-4",
                "profile-owner-4",
                "device-owner-4",
                "Ops Bridge",
                1_700_000_001_000,
            )
            .await
            .unwrap();

        let result = store
            .upsert_room_membership(
                "room-alpha-4",
                "profile-member-4",
                "active",
                "member",
                None,
                1_700_000_001_500,
            )
            .await
            .unwrap();

        assert!(result.changed);
        assert_eq!(result.room.version, 2);
        assert_eq!(result.room.membership_version, 2);
        assert_eq!(result.membership.profile_id, "profile-member-4");
        assert_eq!(result.membership.status, "active");
        assert_eq!(result.membership.role, "member");
        assert_eq!(result.membership.created_at_ms, 1_700_000_001_500);
        assert_eq!(result.membership.updated_at_ms, 1_700_000_001_500);

        let members = store.list_room_memberships("room-alpha-4").await.unwrap();
        assert_eq!(members.len(), 2);
        assert_eq!(members[0].role, "owner");
        assert_eq!(members[1].profile_id, "profile-member-4");
    }

    #[tokio::test]
    async fn upsert_room_membership_is_idempotent_for_same_authoritative_state() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-5",
                "profile-owner-5",
                "device-owner-5",
                "Launch Pad",
                1_700_000_002_000,
            )
            .await
            .unwrap();

        let first = store
            .upsert_room_membership(
                "room-alpha-5",
                "profile-member-5",
                "pending",
                "guest",
                Some("link-alpha-5"),
                1_700_000_002_100,
            )
            .await
            .unwrap();
        let second = store
            .upsert_room_membership(
                "room-alpha-5",
                "profile-member-5",
                "pending",
                "guest",
                Some("link-alpha-5"),
                1_700_000_002_900,
            )
            .await
            .unwrap();

        assert!(first.changed);
        assert!(!second.changed);
        assert_eq!(second.room.version, 2);
        assert_eq!(second.room.membership_version, 2);
        assert_eq!(second.membership.created_at_ms, 1_700_000_002_100);
        assert_eq!(second.membership.updated_at_ms, 1_700_000_002_100);
    }

    #[tokio::test]
    async fn upsert_room_membership_preserves_created_at_for_role_change_and_resets_on_reactivation()
     {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-6",
                "profile-owner-6",
                "device-owner-6",
                "Delta Room",
                1_700_000_003_000,
            )
            .await
            .unwrap();

        let added = store
            .upsert_room_membership(
                "room-alpha-6",
                "profile-member-6",
                "active",
                "member",
                None,
                1_700_000_003_100,
            )
            .await
            .unwrap();
        let role_changed = store
            .upsert_room_membership(
                "room-alpha-6",
                "profile-member-6",
                "active",
                "moderator",
                None,
                1_700_000_003_400,
            )
            .await
            .unwrap();
        let removed = store
            .upsert_room_membership(
                "room-alpha-6",
                "profile-member-6",
                "removed",
                "member",
                None,
                1_700_000_003_700,
            )
            .await
            .unwrap();
        let reactivated = store
            .upsert_room_membership(
                "room-alpha-6",
                "profile-member-6",
                "active",
                "guest",
                Some("link-reactivate-6"),
                1_700_000_004_000,
            )
            .await
            .unwrap();

        assert_eq!(added.membership.created_at_ms, 1_700_000_003_100);
        assert_eq!(role_changed.membership.created_at_ms, 1_700_000_003_100);
        assert_eq!(removed.membership.created_at_ms, 1_700_000_003_100);
        assert_eq!(reactivated.membership.created_at_ms, 1_700_000_004_000);
        assert_eq!(reactivated.membership.role, "guest");
        assert_eq!(
            reactivated.membership.source_link_id.as_deref(),
            Some("link-reactivate-6")
        );
        assert_eq!(reactivated.room.version, 5);
        assert_eq!(reactivated.room.membership_version, 5);
    }

    #[tokio::test]
    async fn upsert_room_membership_rejects_invalid_owner_mutation() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-7",
                "profile-owner-7",
                "device-owner-7",
                "Mercury Room",
                1_700_000_005_000,
            )
            .await
            .unwrap();

        let err = store
            .upsert_room_membership(
                "room-alpha-7",
                "profile-owner-7",
                "left",
                "owner",
                None,
                1_700_000_005_500,
            )
            .await
            .unwrap_err();

        assert!(matches!(
            err,
            UpsertRoomMembershipError::InvalidOwnerMutation
        ));
    }

    #[tokio::test]
    async fn upsert_room_membership_keeps_left_state_for_remove_and_allows_followup_ban() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-7a",
                "profile-owner-7a",
                "device-owner-7a",
                "Lifecycle Race Room",
                1_700_000_005_000,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-alpha-7a",
                "profile-member-7a",
                "active",
                "guest",
                Some("link-left-remove-7a"),
                1_700_000_005_100,
            )
            .await
            .unwrap();

        let left = store
            .leave_room("room-alpha-7a", "profile-member-7a", 1_700_000_005_300)
            .await
            .unwrap();
        let removed = store
            .upsert_room_membership(
                "room-alpha-7a",
                "profile-member-7a",
                "removed",
                "member",
                Some("link-left-remove-7a"),
                1_700_000_005_500,
            )
            .await
            .unwrap();
        let banned = store
            .upsert_room_membership(
                "room-alpha-7a",
                "profile-member-7a",
                "banned",
                "member",
                Some("link-left-remove-7a"),
                1_700_000_005_700,
            )
            .await
            .unwrap();

        assert!(left.changed);
        assert_eq!(left.membership.status, "left");
        assert_eq!(left.membership.role, "guest");
        assert_eq!(left.room.version, 3);
        assert_eq!(left.room.membership_version, 3);

        assert!(!removed.changed);
        assert_eq!(removed.room.version, left.room.version);
        assert_eq!(
            removed.room.membership_version,
            left.room.membership_version
        );
        assert_eq!(removed.room.updated_at_ms, left.room.updated_at_ms);
        assert_eq!(removed.membership.status, "left");
        assert_eq!(removed.membership.role, "guest");
        assert_eq!(
            removed.membership.updated_at_ms,
            left.membership.updated_at_ms
        );
        assert_eq!(
            removed.membership.source_link_id.as_deref(),
            Some("link-left-remove-7a")
        );

        assert!(banned.changed);
        assert_eq!(banned.room.version, 4);
        assert_eq!(banned.room.membership_version, 4);
        assert_eq!(banned.membership.status, "banned");
        assert_eq!(banned.membership.role, "member");
        assert_eq!(
            banned.membership.source_link_id.as_deref(),
            Some("link-left-remove-7a")
        );
    }

    #[tokio::test]
    async fn leave_room_keeps_removed_and_banned_terminal_state_as_idempotent_noop() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-7c-removed",
                "profile-owner-7c",
                "device-owner-7c",
                "Removed Leave Conflict Room",
                1_700_000_006_800,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-alpha-7c-removed",
                "profile-member-7c-removed",
                "active",
                "guest",
                Some("link-leave-removed-7c"),
                1_700_000_006_900,
            )
            .await
            .unwrap();
        let removed = store
            .upsert_room_membership(
                "room-alpha-7c-removed",
                "profile-member-7c-removed",
                "removed",
                "member",
                Some("link-leave-removed-7c"),
                1_700_000_007_100,
            )
            .await
            .unwrap();
        let leave_removed = store
            .leave_room(
                "room-alpha-7c-removed",
                "profile-member-7c-removed",
                1_700_000_007_300,
            )
            .await
            .unwrap();

        assert!(removed.changed);
        assert!(!leave_removed.changed);
        assert_eq!(leave_removed.room.version, removed.room.version);
        assert_eq!(
            leave_removed.room.membership_version,
            removed.room.membership_version
        );
        assert_eq!(leave_removed.room.updated_at_ms, removed.room.updated_at_ms);
        assert_eq!(leave_removed.membership.status, "removed");
        assert_eq!(leave_removed.membership.role, "member");
        assert_eq!(
            leave_removed.membership.updated_at_ms,
            removed.membership.updated_at_ms
        );
        assert_eq!(
            leave_removed.membership.source_link_id.as_deref(),
            Some("link-leave-removed-7c")
        );

        store
            .create_room(
                "room-alpha-7c-banned",
                "profile-owner-7c",
                "device-owner-7c",
                "Banned Leave Conflict Room",
                1_700_000_007_600,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-alpha-7c-banned",
                "profile-member-7c-banned",
                "active",
                "guest",
                Some("link-leave-banned-7c"),
                1_700_000_007_700,
            )
            .await
            .unwrap();
        let banned = store
            .upsert_room_membership(
                "room-alpha-7c-banned",
                "profile-member-7c-banned",
                "banned",
                "member",
                Some("link-leave-banned-7c"),
                1_700_000_007_900,
            )
            .await
            .unwrap();
        let leave_banned = store
            .leave_room(
                "room-alpha-7c-banned",
                "profile-member-7c-banned",
                1_700_000_008_100,
            )
            .await
            .unwrap();

        assert!(banned.changed);
        assert!(!leave_banned.changed);
        assert_eq!(leave_banned.room.version, banned.room.version);
        assert_eq!(
            leave_banned.room.membership_version,
            banned.room.membership_version
        );
        assert_eq!(leave_banned.room.updated_at_ms, banned.room.updated_at_ms);
        assert_eq!(leave_banned.membership.status, "banned");
        assert_eq!(leave_banned.membership.role, "member");
        assert_eq!(
            leave_banned.membership.updated_at_ms,
            banned.membership.updated_at_ms
        );
        assert_eq!(
            leave_banned.membership.source_link_id.as_deref(),
            Some("link-leave-banned-7c")
        );
    }

    #[tokio::test]
    async fn leave_room_by_last_owner_revokes_invites_and_clears_pending_requests() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-7d",
                "profile-owner-7d",
                "device-owner-7d",
                "Last Owner Delete Room",
                1_700_000_008_000,
            )
            .await
            .unwrap();
        store
            .create_room_invite_link(
                "room-alpha-7d",
                "link-alpha-7d",
                "invite-alpha-7d",
                "profile-owner-7d",
                None,
                None,
                false,
                "guest",
                1_700_000_008_100,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-alpha-7d",
                "profile-pending-7d",
                "pending",
                "guest",
                Some("link-alpha-7d"),
                1_700_000_008_200,
            )
            .await
            .unwrap();

        let left = store
            .leave_room("room-alpha-7d", "profile-owner-7d", 1_700_000_008_500)
            .await
            .unwrap();

        assert!(left.changed);
        assert_eq!(left.room.version, 4);
        assert_eq!(left.room.membership_version, 3);
        assert_eq!(left.membership.status, "left");
        assert_eq!(left.membership.role, "owner");

        let invite = store
            .get_room_invite_link_by_slug("invite-alpha-7d")
            .await
            .unwrap()
            .unwrap();
        assert!(invite.revoked);

        let pending_membership = store
            .get_room_membership("room-alpha-7d", "profile-pending-7d")
            .await
            .unwrap()
            .unwrap();
        assert_eq!(pending_membership.status, "removed");
        assert_eq!(pending_membership.role, "member");
        assert_eq!(
            pending_membership.source_link_id.as_deref(),
            Some("link-alpha-7d")
        );
    }

    #[tokio::test]
    async fn delete_room_removes_room_local_state_atomically() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-7e",
                "profile-owner-7e",
                "device-owner-7e",
                "Delete Target Room",
                1_700_000_009_000,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-alpha-7e",
                "profile-member-7e",
                "active",
                "member",
                None,
                1_700_000_009_050,
            )
            .await
            .unwrap();
        store
            .create_room_invite_link(
                "room-alpha-7e",
                "link-alpha-7e",
                "invite-alpha-7e",
                "profile-owner-7e",
                None,
                None,
                false,
                "guest",
                1_700_000_009_100,
            )
            .await
            .unwrap();
        store
            .admit_room_message(
                "room-alpha-7e",
                "profile-owner-7e",
                "msg-alpha-7e",
                "text",
                1_700_000_009_150,
            )
            .await
            .unwrap();
        store
            .create_or_join_room_call(
                "room-alpha-7e",
                "profile-owner-7e",
                "device-owner-7e",
                "audio",
                false,
                false,
                false,
                false,
                false,
                false,
                1_700_000_009_200,
            )
            .await
            .unwrap();

        let deleted = store
            .delete_room("room-alpha-7e", "profile-owner-7e")
            .await
            .unwrap();

        assert_eq!(deleted.room.room_id, "room-alpha-7e");
        assert_eq!(deleted.deleted_profile_ids, vec!["profile-member-7e"]);
        assert!(store.get_room("room-alpha-7e").await.unwrap().is_none());
        assert!(
            store
                .list_room_memberships("room-alpha-7e")
                .await
                .unwrap()
                .is_empty()
        );
        assert!(
            store
                .list_room_invite_links("room-alpha-7e")
                .await
                .unwrap()
                .is_empty()
        );
        assert!(
            store
                .get_active_room_call("room-alpha-7e", None)
                .await
                .unwrap()
                .is_none()
        );

        let message_index_count = store
            .conn
            .call(|c| -> Result<i64, rusqlite::Error> {
                c.query_row(
                    "SELECT COUNT(*) FROM room_message_index WHERE room_id = ?1",
                    params!["room-alpha-7e"],
                    |row| row.get(0),
                )
            })
            .await
            .unwrap();
        assert_eq!(message_index_count, 0);
    }

    #[tokio::test]
    async fn upsert_room_membership_keeps_banned_state_for_remove_until_explicit_unban() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-7b",
                "profile-owner-7b",
                "device-owner-7b",
                "Ban Remove Conflict Room",
                1_700_000_006_000,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-alpha-7b",
                "profile-member-7b",
                "active",
                "guest",
                Some("link-ban-remove-7b"),
                1_700_000_006_100,
            )
            .await
            .unwrap();

        let banned = store
            .upsert_room_membership(
                "room-alpha-7b",
                "profile-member-7b",
                "banned",
                "member",
                Some("link-ban-remove-7b"),
                1_700_000_006_300,
            )
            .await
            .unwrap();
        let removed = store
            .upsert_room_membership(
                "room-alpha-7b",
                "profile-member-7b",
                "removed",
                "member",
                Some("link-ban-remove-7b"),
                1_700_000_006_500,
            )
            .await
            .unwrap();
        let unbanned = store
            .unban_room_membership("room-alpha-7b", "profile-member-7b", 1_700_000_006_700)
            .await
            .unwrap();
        let unbanned_retry = store
            .unban_room_membership("room-alpha-7b", "profile-member-7b", 1_700_000_006_900)
            .await
            .unwrap();

        assert!(banned.changed);
        assert_eq!(banned.room.version, 3);
        assert_eq!(banned.room.membership_version, 3);
        assert_eq!(banned.membership.status, "banned");
        assert_eq!(banned.membership.role, "member");

        assert!(!removed.changed);
        assert_eq!(removed.room.version, banned.room.version);
        assert_eq!(
            removed.room.membership_version,
            banned.room.membership_version
        );
        assert_eq!(removed.room.updated_at_ms, banned.room.updated_at_ms);
        assert_eq!(removed.membership.status, "banned");
        assert_eq!(removed.membership.role, "member");
        assert_eq!(
            removed.membership.updated_at_ms,
            banned.membership.updated_at_ms
        );
        assert_eq!(
            removed.membership.source_link_id.as_deref(),
            Some("link-ban-remove-7b")
        );

        assert!(unbanned.changed);
        assert_eq!(unbanned.room.version, 4);
        assert_eq!(unbanned.room.membership_version, 4);
        assert_eq!(unbanned.membership.status, "removed");
        assert_eq!(unbanned.membership.role, "member");
        assert_eq!(
            unbanned.membership.source_link_id.as_deref(),
            Some("link-ban-remove-7b")
        );

        assert!(!unbanned_retry.changed);
        assert_eq!(unbanned_retry.room.version, unbanned.room.version);
        assert_eq!(
            unbanned_retry.room.membership_version,
            unbanned.room.membership_version
        );
        assert_eq!(unbanned_retry.membership.status, "removed");
        assert_eq!(unbanned_retry.membership.role, "member");
        assert_eq!(
            unbanned_retry.membership.source_link_id.as_deref(),
            Some("link-ban-remove-7b")
        );
    }

    #[tokio::test]
    async fn transfer_room_ownership_promotes_next_active_member_and_demotes_previous_owner() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-7b",
                "profile-owner-7b",
                "device-owner-7b",
                "Ownership Room",
                1_700_000_005_000,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-alpha-7b",
                "profile-member-7b",
                "active",
                "member",
                Some("link-owner-transfer-7b"),
                1_700_000_005_100,
            )
            .await
            .unwrap();

        let transferred = store
            .transfer_room_ownership(
                "room-alpha-7b",
                "profile-owner-7b",
                "profile-member-7b",
                1_700_000_005_500,
            )
            .await
            .unwrap();

        assert_eq!(transferred.room.owner_profile_id, "profile-member-7b");
        assert_eq!(transferred.room.version, 3);
        assert_eq!(transferred.room.membership_version, 3);
        assert_eq!(transferred.previous_owner_membership.status, "active");
        assert_eq!(transferred.previous_owner_membership.role, "admin");
        assert_eq!(transferred.next_owner_membership.status, "active");
        assert_eq!(transferred.next_owner_membership.role, "owner");
        assert_eq!(
            transferred.next_owner_membership.source_link_id.as_deref(),
            Some("link-owner-transfer-7b")
        );
    }

    #[tokio::test]
    async fn transfer_room_ownership_is_idempotent_for_previous_owner_retry() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-7b-retry",
                "profile-owner-7b-retry",
                "device-owner-7b-retry",
                "Ownership Retry Room",
                1_700_000_005_000,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-alpha-7b-retry",
                "profile-member-7b-retry",
                "active",
                "member",
                Some("link-owner-transfer-7b-retry"),
                1_700_000_005_100,
            )
            .await
            .unwrap();

        let first = store
            .transfer_room_ownership(
                "room-alpha-7b-retry",
                "profile-owner-7b-retry",
                "profile-member-7b-retry",
                1_700_000_005_500,
            )
            .await
            .unwrap();
        let second = store
            .transfer_room_ownership(
                "room-alpha-7b-retry",
                "profile-owner-7b-retry",
                "profile-member-7b-retry",
                1_700_000_005_900,
            )
            .await
            .unwrap();

        assert_eq!(second.room.owner_profile_id, "profile-member-7b-retry");
        assert_eq!(second.room.version, first.room.version);
        assert_eq!(
            second.room.membership_version,
            first.room.membership_version
        );
        assert_eq!(second.room.updated_at_ms, first.room.updated_at_ms);
        assert_eq!(second.previous_owner_membership.status, "active");
        assert_eq!(second.previous_owner_membership.role, "admin");
        assert_eq!(
            second.previous_owner_membership.updated_at_ms,
            first.room.updated_at_ms
        );
        assert_eq!(second.next_owner_membership.status, "active");
        assert_eq!(second.next_owner_membership.role, "owner");
        assert_eq!(
            second.next_owner_membership.updated_at_ms,
            first.room.updated_at_ms
        );
    }

    #[tokio::test]
    async fn transfer_room_ownership_rejects_non_replay_admin_after_owner_changed() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-7b-admin",
                "profile-owner-7b-admin",
                "device-owner-7b-admin",
                "Ownership Admin Guard Room",
                1_700_000_005_000,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-alpha-7b-admin",
                "profile-member-7b-admin",
                "active",
                "member",
                Some("link-owner-transfer-7b-admin"),
                1_700_000_005_100,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-alpha-7b-admin",
                "profile-admin-7b-admin",
                "active",
                "admin",
                None,
                1_700_000_005_150,
            )
            .await
            .unwrap();

        store
            .transfer_room_ownership(
                "room-alpha-7b-admin",
                "profile-owner-7b-admin",
                "profile-member-7b-admin",
                1_700_000_005_500,
            )
            .await
            .unwrap();

        let err = store
            .transfer_room_ownership(
                "room-alpha-7b-admin",
                "profile-admin-7b-admin",
                "profile-member-7b-admin",
                1_700_000_005_900,
            )
            .await
            .unwrap_err();

        assert!(matches!(err, TransferRoomOwnershipError::OwnerMismatch));
    }

    #[tokio::test]
    async fn transfer_room_ownership_rejects_invalid_or_non_active_target() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-7c",
                "profile-owner-7c",
                "device-owner-7c",
                "Invalid Ownership Room",
                1_700_000_006_000,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-alpha-7c",
                "profile-pending-7c",
                "pending",
                "guest",
                Some("link-owner-transfer-7c"),
                1_700_000_006_100,
            )
            .await
            .unwrap();

        let same_owner_err = store
            .transfer_room_ownership(
                "room-alpha-7c",
                "profile-owner-7c",
                "profile-owner-7c",
                1_700_000_006_400,
            )
            .await
            .unwrap_err();
        assert!(matches!(
            same_owner_err,
            TransferRoomOwnershipError::InvalidNextOwner
        ));

        let pending_target_err = store
            .transfer_room_ownership(
                "room-alpha-7c",
                "profile-owner-7c",
                "profile-pending-7c",
                1_700_000_006_500,
            )
            .await
            .unwrap_err();
        assert!(matches!(
            pending_target_err,
            TransferRoomOwnershipError::NextOwnerNotActive
        ));
    }

    #[tokio::test]
    async fn create_list_and_revoke_room_invite_links_bump_room_state_version() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-8",
                "profile-owner-8",
                "device-owner-8",
                "Invite Room",
                1_700_000_006_000,
            )
            .await
            .unwrap();

        let created = store
            .create_room_invite_link(
                "room-alpha-8",
                "link-alpha-8",
                "invite-alpha-8",
                "profile-owner-8",
                Some(1_700_000_106_000),
                Some(5),
                true,
                "guest",
                1_700_000_006_100,
            )
            .await
            .unwrap();

        assert_eq!(created.room.version, 2);
        assert_eq!(created.room.membership_version, 1);
        assert_eq!(created.invite_link.slug, "invite-alpha-8");
        assert!(created.invite_link.requires_approval);
        assert_eq!(created.invite_link.max_uses, Some(5));

        let listed = store.list_room_invite_links("room-alpha-8").await.unwrap();
        assert_eq!(listed.len(), 1);
        assert_eq!(listed[0].link_id, "link-alpha-8");
        assert!(!listed[0].revoked);

        let revoked = store
            .set_room_invite_link_revoked("room-alpha-8", "link-alpha-8", true, 1_700_000_006_500)
            .await
            .unwrap();

        assert!(revoked.changed);
        assert_eq!(revoked.room.version, 3);
        assert_eq!(revoked.room.membership_version, 1);
        assert!(revoked.invite_link.revoked);
    }

    #[tokio::test]
    async fn redeem_room_invite_activates_member_and_increments_use_count() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-9",
                "profile-owner-9",
                "device-owner-9",
                "Redeem Room",
                1_700_000_007_000,
            )
            .await
            .unwrap();
        store
            .create_room_invite_link(
                "room-alpha-9",
                "link-alpha-9",
                "invite-alpha-9",
                "profile-owner-9",
                Some(1_700_000_107_000),
                Some(3),
                false,
                "member",
                1_700_000_007_100,
            )
            .await
            .unwrap();

        let redeemed = store
            .redeem_room_invite("invite-alpha-9", "profile-member-9", 1_700_000_007_500)
            .await
            .unwrap();

        assert!(redeemed.changed);
        assert_eq!(redeemed.room.version, 3);
        assert_eq!(redeemed.room.membership_version, 2);
        assert_eq!(redeemed.invite_link.use_count, 1);
        assert_eq!(redeemed.membership.status, "active");
        assert_eq!(redeemed.membership.role, "member");
        assert_eq!(
            redeemed.membership.source_link_id.as_deref(),
            Some("link-alpha-9")
        );
    }

    #[tokio::test]
    async fn redeem_room_invite_returns_pending_when_approval_required() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-10",
                "profile-owner-10",
                "device-owner-10",
                "Approval Room",
                1_700_000_008_000,
            )
            .await
            .unwrap();
        store
            .create_room_invite_link(
                "room-alpha-10",
                "link-alpha-10",
                "invite-alpha-10",
                "profile-owner-10",
                None,
                None,
                true,
                "guest",
                1_700_000_008_100,
            )
            .await
            .unwrap();

        let redeemed = store
            .redeem_room_invite("invite-alpha-10", "profile-member-10", 1_700_000_008_500)
            .await
            .unwrap();

        assert!(redeemed.changed);
        assert_eq!(redeemed.membership.status, "pending");
        assert_eq!(redeemed.membership.role, "guest");
        assert_eq!(redeemed.invite_link.use_count, 1);
    }

    #[tokio::test]
    async fn redeem_room_invite_returns_pending_when_room_requires_approval() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-10b",
                "profile-owner-10b",
                "device-owner-10b",
                "Room Level Approval Room",
                1_700_000_008_000,
            )
            .await
            .unwrap();
        let updated = store
            .update_room_settings(
                "room-alpha-10b",
                "all",
                true,
                true,
                true,
                true,
                true,
                false,
                true,
                0,
                false,
                1_700_000_008_050,
            )
            .await
            .unwrap();
        assert!(updated.changed);
        assert!(updated.room.join_approval_required);
        store
            .create_room_invite_link(
                "room-alpha-10b",
                "link-alpha-10b",
                "invite-alpha-10b",
                "profile-owner-10b",
                None,
                None,
                false,
                "member",
                1_700_000_008_100,
            )
            .await
            .unwrap();

        let redeemed = store
            .redeem_room_invite("invite-alpha-10b", "profile-member-10b", 1_700_000_008_500)
            .await
            .unwrap();

        assert!(redeemed.changed);
        assert_eq!(redeemed.membership.status, "pending");
        assert_eq!(redeemed.membership.role, "member");
        assert_eq!(redeemed.invite_link.use_count, 1);
    }

    #[tokio::test]
    async fn redeem_room_invite_is_idempotent_for_existing_active_or_pending_membership() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-11",
                "profile-owner-11",
                "device-owner-11",
                "Idempotent Invite Room",
                1_700_000_009_000,
            )
            .await
            .unwrap();
        store
            .create_room_invite_link(
                "room-alpha-11",
                "link-alpha-11",
                "invite-alpha-11",
                "profile-owner-11",
                None,
                Some(2),
                false,
                "member",
                1_700_000_009_100,
            )
            .await
            .unwrap();

        let first = store
            .redeem_room_invite("invite-alpha-11", "profile-member-11", 1_700_000_009_500)
            .await
            .unwrap();
        let second = store
            .redeem_room_invite("invite-alpha-11", "profile-member-11", 1_700_000_009_900)
            .await
            .unwrap();

        assert!(first.changed);
        assert!(!second.changed);
        assert_eq!(second.room.version, 3);
        assert_eq!(second.room.membership_version, 2);
        assert_eq!(second.invite_link.use_count, 1);
        assert_eq!(second.membership.status, "active");
    }

    #[tokio::test]
    async fn redeem_room_invite_rejects_banned_or_expired_invites() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .create_room(
                "room-alpha-12",
                "profile-owner-12",
                "device-owner-12",
                "Guarded Invite Room",
                1_700_000_010_000,
            )
            .await
            .unwrap();
        store
            .create_room_invite_link(
                "room-alpha-12",
                "link-alpha-12-expired",
                "invite-alpha-12-expired",
                "profile-owner-12",
                Some(1_700_000_010_100),
                Some(1),
                false,
                "member",
                1_700_000_010_050,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-alpha-12",
                "profile-banned-12",
                "banned",
                "member",
                None,
                1_700_000_010_060,
            )
            .await
            .unwrap();

        let expired_err = store
            .redeem_room_invite(
                "invite-alpha-12-expired",
                "profile-member-12",
                1_700_000_010_500,
            )
            .await
            .unwrap_err();
        assert!(matches!(expired_err, RedeemRoomInviteError::InviteExpired));

        let banned_err = store
            .redeem_room_invite(
                "invite-alpha-12-expired",
                "profile-banned-12",
                1_700_000_010_050,
            )
            .await
            .unwrap_err();
        assert!(matches!(banned_err, RedeemRoomInviteError::Banned));
    }

    #[tokio::test]
    async fn create_or_join_room_call_creates_snapshot_and_is_idempotent() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_020_000i64;
        store
            .create_room(
                "room-call-1",
                "profile-owner-call-1",
                "device-owner-call-1",
                "Room Call One",
                now,
            )
            .await
            .unwrap();

        let created = store
            .create_or_join_room_call(
                "room-call-1",
                "profile-owner-call-1",
                "device-owner-call-1",
                "video",
                true,
                true,
                false,
                false,
                true,
                false,
                now + 100,
            )
            .await
            .unwrap();

        assert!(created.changed);
        assert_eq!(created.snapshot.call.state, "active");
        assert_eq!(created.snapshot.call.media_type, "video");
        assert_eq!(created.snapshot.call.state_version, 1);
        assert_eq!(created.snapshot.participants.len(), 1);
        let self_participant = created.snapshot.self_participant.as_ref().unwrap();
        assert_eq!(self_participant.profile_id, "profile-owner-call-1");
        assert_eq!(self_participant.device_id, "device-owner-call-1");
        assert_eq!(self_participant.join_state, "joined");
        assert!(self_participant.supports_video);
        assert!(self_participant.supports_screen_share);
        assert!(self_participant.video_enabled);
        assert!(!self_participant.screen_share_enabled);

        let repeated = store
            .create_or_join_room_call(
                "room-call-1",
                "profile-owner-call-1",
                "device-owner-call-1",
                "video",
                true,
                true,
                false,
                false,
                true,
                false,
                now + 200,
            )
            .await
            .unwrap();

        assert!(!repeated.changed);
        assert_eq!(
            repeated.snapshot.call.call_id,
            created.snapshot.call.call_id
        );
        assert_eq!(repeated.snapshot.call.state_version, 1);

        let fetched = store
            .get_active_room_call("room-call-1", Some("device-owner-call-1"))
            .await
            .unwrap()
            .unwrap();
        assert_eq!(fetched.call.call_id, created.snapshot.call.call_id);
        assert_eq!(fetched.participants.len(), 1);
    }

    #[tokio::test]
    async fn room_call_participant_updates_and_last_leave_ends_call() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_030_000i64;
        store
            .create_room(
                "room-call-2",
                "profile-owner-call-2",
                "device-owner-call-2",
                "Room Call Two",
                now,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-call-2",
                "profile-member-call-2",
                "active",
                "member",
                None,
                now + 10,
            )
            .await
            .unwrap();

        let created = store
            .create_or_join_room_call(
                "room-call-2",
                "profile-owner-call-2",
                "device-owner-call-2",
                "video",
                true,
                false,
                false,
                false,
                true,
                false,
                now + 20,
            )
            .await
            .unwrap();
        let joined = store
            .create_or_join_room_call(
                "room-call-2",
                "profile-member-call-2",
                "device-member-call-2",
                "video",
                true,
                true,
                false,
                false,
                false,
                false,
                now + 30,
            )
            .await
            .unwrap();

        assert!(joined.changed);
        assert_eq!(joined.snapshot.call.call_id, created.snapshot.call.call_id);
        assert_eq!(joined.snapshot.participants.len(), 2);

        let updated = store
            .update_room_call_participant_state(
                "room-call-2",
                &created.snapshot.call.call_id,
                "profile-member-call-2",
                "device-member-call-2",
                true,
                true,
                false,
                true,
                true,
                true,
                now + 40,
            )
            .await
            .unwrap();

        assert!(updated.changed);
        let updated_self = updated.snapshot.self_participant.as_ref().unwrap();
        assert_eq!(updated_self.join_state, "reconnecting");
        assert!(updated_self.muted);
        assert!(updated_self.video_enabled);
        assert!(updated_self.screen_share_enabled);
        assert!(!updated_self.speaking);
        assert!(updated.snapshot.call.state_version >= 3);

        let member_left = store
            .leave_room_call(
                "room-call-2",
                &created.snapshot.call.call_id,
                "profile-member-call-2",
                "device-member-call-2",
                now + 50,
            )
            .await
            .unwrap();

        assert!(member_left.changed);
        assert_eq!(member_left.snapshot.call.state, "active");
        assert_eq!(member_left.snapshot.participants.len(), 2);
        assert_eq!(
            member_left
                .snapshot
                .self_participant
                .as_ref()
                .unwrap()
                .join_state,
            "left"
        );

        let owner_left = store
            .leave_room_call(
                "room-call-2",
                &created.snapshot.call.call_id,
                "profile-owner-call-2",
                "device-owner-call-2",
                now + 60,
            )
            .await
            .unwrap();

        assert!(owner_left.changed);
        assert_eq!(owner_left.snapshot.call.state, "ended");
        assert!(owner_left.snapshot.call.ended_at_ms.is_some());
        assert_eq!(
            owner_left
                .snapshot
                .self_participant
                .as_ref()
                .unwrap()
                .join_state,
            "left"
        );
    }

    #[tokio::test]
    async fn room_call_self_update_can_upgrade_audio_call_to_video() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_032_500i64;
        store
            .create_room(
                "room-call-2-upgrade",
                "profile-owner-call-2-upgrade",
                "device-owner-call-2-upgrade",
                "Room Call Two Upgrade",
                now,
            )
            .await
            .unwrap();

        let created = store
            .create_or_join_room_call(
                "room-call-2-upgrade",
                "profile-owner-call-2-upgrade",
                "device-owner-call-2-upgrade",
                "audio",
                true,
                false,
                false,
                false,
                false,
                false,
                now + 10,
            )
            .await
            .unwrap();

        assert_eq!(created.snapshot.call.media_type, "audio");
        assert!(
            !created
                .snapshot
                .self_participant
                .as_ref()
                .unwrap()
                .video_enabled
        );

        let updated = store
            .update_room_call_participant_state(
                "room-call-2-upgrade",
                &created.snapshot.call.call_id,
                "profile-owner-call-2-upgrade",
                "device-owner-call-2-upgrade",
                false,
                false,
                false,
                true,
                false,
                false,
                now + 20,
            )
            .await
            .unwrap();

        assert!(updated.changed);
        assert_eq!(updated.snapshot.call.media_type, "video");
        assert_eq!(updated.snapshot.call.state_version, 2);
        assert!(
            updated
                .snapshot
                .self_participant
                .as_ref()
                .unwrap()
                .video_enabled
        );
    }

    #[tokio::test]
    async fn room_call_remove_participant_and_end_call_are_authoritative_and_idempotent() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_035_000i64;
        store
            .create_room(
                "room-call-2b",
                "profile-owner-call-2b",
                "device-owner-call-2b",
                "Room Call Two B",
                now,
            )
            .await
            .unwrap();
        store
            .upsert_room_membership(
                "room-call-2b",
                "profile-member-call-2b",
                "active",
                "member",
                None,
                now + 10,
            )
            .await
            .unwrap();

        let created = store
            .create_or_join_room_call(
                "room-call-2b",
                "profile-owner-call-2b",
                "device-owner-call-2b",
                "video",
                true,
                false,
                false,
                false,
                true,
                false,
                now + 20,
            )
            .await
            .unwrap();
        let joined = store
            .create_or_join_room_call(
                "room-call-2b",
                "profile-member-call-2b",
                "device-member-call-2b",
                "audio",
                false,
                false,
                false,
                false,
                false,
                false,
                now + 30,
            )
            .await
            .unwrap();

        assert_eq!(joined.snapshot.participants.len(), 2);

        let removed = store
            .remove_room_call_participant(
                "room-call-2b",
                &created.snapshot.call.call_id,
                "profile-member-call-2b",
                "device-member-call-2b",
                Some("device-owner-call-2b"),
                now + 40,
            )
            .await
            .unwrap();

        assert!(removed.changed);
        assert_eq!(removed.snapshot.call.state, "active");
        assert_eq!(removed.snapshot.call.state_version, 3);
        assert_eq!(
            removed
                .snapshot
                .self_participant
                .as_ref()
                .unwrap()
                .join_state,
            "joined"
        );
        let removed_participant = removed
            .snapshot
            .participants
            .iter()
            .find(|participant| participant.device_id == "device-member-call-2b")
            .unwrap();
        assert_eq!(removed_participant.join_state, "removed");

        let removed_again = store
            .remove_room_call_participant(
                "room-call-2b",
                &created.snapshot.call.call_id,
                "profile-member-call-2b",
                "device-member-call-2b",
                Some("device-owner-call-2b"),
                now + 50,
            )
            .await
            .unwrap();

        assert!(!removed_again.changed);
        assert_eq!(removed_again.snapshot.call.state, "active");

        let ended = store
            .end_room_call(
                "room-call-2b",
                &created.snapshot.call.call_id,
                Some("device-owner-call-2b"),
                now + 60,
            )
            .await
            .unwrap();

        assert!(ended.changed);
        assert_eq!(ended.snapshot.call.state, "ended");
        assert!(ended.snapshot.call.ended_at_ms.is_some());
        assert_eq!(
            ended.snapshot.self_participant.as_ref().unwrap().join_state,
            "left"
        );
        let ended_member = ended
            .snapshot
            .participants
            .iter()
            .find(|participant| participant.device_id == "device-member-call-2b")
            .unwrap();
        assert_eq!(ended_member.join_state, "removed");

        let ended_again = store
            .end_room_call(
                "room-call-2b",
                &created.snapshot.call.call_id,
                Some("device-owner-call-2b"),
                now + 70,
            )
            .await
            .unwrap();

        assert!(!ended_again.changed);
        assert_eq!(ended_again.snapshot.call.state, "ended");
    }

    /// SEC-09: сервер забывает, КТО отправил сообщение в комнату, но помнит,
    /// что сообщение было.
    ///
    /// Отправитель хранился бессрочно — очистка происходила только при удалении
    /// комнаты. Получался вечный журнал участия в группах у сервера, который в
    /// остальном отправителя не хранит вовсе.
    ///
    /// 🔴 Проверяются ОБА свойства сразу. Простое удаление строки сняло бы
    /// метаданные, но отняло возможность закрепить сообщение старше срока:
    /// перед закреплением проверяется, что сообщение действительно было в этой
    /// комнате. Поэтому поле обнуляется, а запись остаётся.
    #[tokio::test]
    async fn cleanup_forgets_room_message_sender_but_keeps_the_message() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_000_000i64;
        let old_ms = now - (ROOM_MESSAGE_SENDER_RETENTION_DAYS + 1) * 24 * 60 * 60 * 1000;
        let recent_ms = now - 24 * 60 * 60 * 1000;

        store
            .conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "INSERT INTO room_message_index(room_id, message_id, admitted_by_profile_id, kind, admitted_at_ms) VALUES('room-sec09', 'msg-old', 'profile-sender', 'text', ?1)",
                    params![old_ms],
                )?;
                c.execute(
                    "INSERT INTO room_message_index(room_id, message_id, admitted_by_profile_id, kind, admitted_at_ms) VALUES('room-sec09', 'msg-recent', 'profile-sender', 'text', ?1)",
                    params![recent_ms],
                )?;
                Ok(())
            })
            .await
            .unwrap();

        store.cleanup_expired(now).await.unwrap();

        let rows = store
            .conn
            .call(|c| -> Result<Vec<(String, String)>, rusqlite::Error> {
                let mut stmt = c.prepare(
                    "SELECT message_id, admitted_by_profile_id FROM room_message_index WHERE room_id = 'room-sec09' ORDER BY message_id",
                )?;
                let out = stmt
                    .query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?
                    .collect::<Result<Vec<_>, _>>()?;
                Ok(out)
            })
            .await
            .unwrap();

        assert_eq!(
            rows.len(),
            2,
            "запись о сообщении удалена — закрепить старое сообщение станет нельзя"
        );

        let old = rows.iter().find(|(id, _)| id == "msg-old").unwrap();
        assert_eq!(
            old.1, "",
            "отправитель старого сообщения не забыт — вечный журнал участия в группах остался"
        );

        let recent = rows.iter().find(|(id, _)| id == "msg-recent").unwrap();
        assert_eq!(
            recent.1, "profile-sender",
            "отправитель свежего сообщения стёрт раньше срока"
        );
    }

    #[tokio::test]
    async fn cleanup_expired_times_out_and_purges_room_calls() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_700_000_040_000i64;
        store
            .create_room(
                "room-call-3",
                "profile-owner-call-3",
                "device-owner-call-3",
                "Room Call Three",
                now,
            )
            .await
            .unwrap();

        let created = store
            .create_or_join_room_call(
                "room-call-3",
                "profile-owner-call-3",
                "device-owner-call-3",
                "audio",
                false,
                false,
                false,
                false,
                false,
                false,
                now + 100,
            )
            .await
            .unwrap();

        let expire_active_at = now + 100 + (store.room_call_active_ttl_seconds as i64 * 1000) + 1;
        store.cleanup_expired(expire_active_at).await.unwrap();

        let ended_snapshot = store
            .get_room_call(
                "room-call-3",
                &created.snapshot.call.call_id,
                Some("device-owner-call-3"),
            )
            .await
            .unwrap()
            .unwrap();
        assert_eq!(ended_snapshot.call.state, "ended");
        assert!(ended_snapshot.call.ended_at_ms.is_some());
        assert_eq!(
            ended_snapshot.self_participant.as_ref().unwrap().join_state,
            "left"
        );

        store
            .cleanup_expired(ended_snapshot.call.expires_at_ms + 1)
            .await
            .unwrap();

        let purged = store
            .get_room_call(
                "room-call-3",
                &created.snapshot.call.call_id,
                Some("device-owner-call-3"),
            )
            .await
            .unwrap();
        assert!(purged.is_none());
    }

    #[tokio::test]
    async fn blob_expiry_and_cleanup() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let now = 1_000_000i64;
        store
            .blob_insert(
                "b1",
                "b1.bin",
                123,
                now + 1_000,
                now,
                "dev1",
                "P1",
                "tokhash",
            )
            .await
            .unwrap();

        let live = store.blob_get("b1", now).await.unwrap();
        assert!(live.is_some());
        assert_eq!(live.unwrap().access_token_sha256_b64, "tokhash");

        // After expiry, blob_get should behave as not found.
        let expired = store.blob_get("b1", now + 1_500).await.unwrap();
        assert!(expired.is_none());

        let removed = store.cleanup_expired_blobs(now + 1_500).await.unwrap();
        assert!(removed.contains(&"b1.bin".to_string()));

        // Row should be deleted by cleanup.
        let after = store.blob_get("b1", now + 2_000).await.unwrap();
        assert!(after.is_none());
    }

    #[tokio::test]
    async fn push_token_upsert_get_delete() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        store
            .upsert_push_token("dev1", "tokA", "android", None, 10)
            .await
            .unwrap();
        let first = store.get_push_token("dev1").await.unwrap().unwrap();
        assert_eq!(first.device_id, "dev1");
        assert_eq!(first.token, "tokA");
        assert_eq!(first.platform, "android");
        assert!(first.policy_json.is_none());

        store
            .upsert_push_token("dev1", "tokB", "android", None, 11)
            .await
            .unwrap();
        let second = store.get_push_token("dev1").await.unwrap().unwrap();
        assert_eq!(second.token, "tokB");
        assert_eq!(second.platform, "android");
        assert!(second.policy_json.is_none());

        store
            .upsert_push_token("dev1", "tokV", "ios_voip", None, 12)
            .await
            .unwrap();
        let all_tokens = store.list_push_tokens("dev1").await.unwrap();
        assert_eq!(all_tokens.len(), 2);
        assert!(all_tokens.iter().any(|row| row.platform == "android"));
        assert!(all_tokens.iter().any(|row| row.platform == "ios_voip"));
        let voip = store
            .get_push_token_for_platform("dev1", "ios_voip")
            .await
            .unwrap()
            .unwrap();
        assert_eq!(voip.token, "tokV");

        store
            .delete_push_token_for_platform("dev1", "ios_voip")
            .await
            .unwrap();
        assert!(
            store
                .get_push_token_for_platform("dev1", "ios_voip")
                .await
                .unwrap()
                .is_none()
        );
        assert!(store.get_push_token("dev1").await.unwrap().is_some());

        store.delete_push_token("dev1").await.unwrap();
        let empty = store.get_push_token("dev1").await.unwrap();
        assert!(empty.is_none());
    }

    /// A superseded device must also vanish from the offline WAKE ladder.
    ///
    /// `superseded_at_ms > 0` already means "this device can never receive
    /// again" and already removes it from senders' fanout — but the wake sweep
    /// kept selecting it, so the relay went on pushing at a dead mailbox and its
    /// undeliverable rows went on feeding `aps.badge`. Measured in production on
    /// 2026-07-30: ONE such device held 511 of the relay's 1007 pending rows,
    /// stranded 5.6 days, never once pumped, still holding a live push token.
    #[tokio::test]
    async fn superseded_device_is_not_an_offline_wake_candidate() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        // A live device with a mailbox and a token IS a candidate.
        store
            .record_device_login("live-dev", Some("profileZ"), 10_000)
            .await
            .unwrap();
        store
            .upsert_push_token("live-dev", "live-token", "android", None, 10_000)
            .await
            .unwrap();
        store
            .enqueue("live-dev", "m-live", "ct", None, 3600, 10_000)
            .await
            .unwrap();

        // A device about to be superseded, with its own mailbox.
        store
            .record_device_login("old-dev", Some("profileZ"), 10_000)
            .await
            .unwrap();
        store
            .upsert_push_token("old-dev", "shared-token", "android", None, 10_000)
            .await
            .unwrap();
        store
            .enqueue("old-dev", "m-old", "ct", None, 3600, 10_000)
            .await
            .unwrap();

        let before = store.list_offline_wake_candidates(20_000).await.unwrap();
        assert!(
            before.iter().any(|c| c.device_id == "old-dev"),
            "sanity: it is a candidate while still live"
        );

        // The same phone rotates its device_id and takes the token over.
        store
            .record_device_login("new-dev", Some("profileZ"), 20_000)
            .await
            .unwrap();
        store
            .upsert_push_token("new-dev", "shared-token", "android", None, 20_000)
            .await
            .unwrap();

        let after = store.list_offline_wake_candidates(30_000).await.unwrap();
        assert!(
            !after.iter().any(|c| c.device_id == "old-dev"),
            "a superseded device must never be woken again"
        );
        assert!(
            after.iter().any(|c| c.device_id == "live-dev"),
            "unrelated live devices must keep being woken"
        );
    }

    #[tokio::test]
    async fn push_token_takeover_evicts_superseded_device_from_fanout() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        // Old device on a phone: live activity row (recently pumped) + a push
        // token, so it is "active" for delivery fanout.
        store
            .record_device_login("old-dev", Some("profileX"), 10_000)
            .await
            .unwrap();
        store
            .upsert_push_token("old-dev", "phone-token", "android", None, 10_000)
            .await
            .unwrap();

        // Same phone reinstalls / rotates its device_id → the new device_id
        // registers the SAME physical push token. FIX-SERVER-2 repoints the token
        // AND the device-rotation fix evicts the old device from the fanout.
        store
            .record_device_login("new-dev", Some("profileX"), 20_000)
            .await
            .unwrap();
        store
            .upsert_push_token("new-dev", "phone-token", "android", None, 20_000)
            .await
            .unwrap();

        // Old device's token is gone (existing FIX-SERVER-2); new device owns it.
        assert!(
            store
                .get_push_token_for_platform("old-dev", "android")
                .await
                .unwrap()
                .is_none()
        );
        assert_eq!(
            store
                .get_push_token_for_platform("new-dev", "android")
                .await
                .unwrap()
                .unwrap()
                .token,
            "phone-token"
        );

        // Old device's activity is zeroed → the 30-day staleness filter behind
        // GET /v1/active_devices excludes it, so senders stop encrypting into its
        // dead mailbox. New device stays active.
        let rows = store
            .device_activity_list_for_profile("profileX")
            .await
            .unwrap();
        let old_row = rows.iter().find(|r| r.device_id == "old-dev").unwrap();
        assert!(
            old_row.superseded_at_ms > 0,
            "old device must be flagged superseded"
        );
        assert_eq!(old_row.last_pump_at_ms, 0);
        assert_eq!(old_row.last_push_delivered_at_ms, 0);
        let new_row = rows.iter().find(|r| r.device_id == "new-dev").unwrap();
        assert_eq!(new_row.superseded_at_ms, 0, "new device is not superseded");
        assert!(new_row.last_pump_at_ms > 0);
    }

    /// ПОВТОРНЫЙ БАННЕР О ТОМ ЖЕ СООБЩЕНИИ (полевая жалоба 02.09.2026).
    ///
    /// Страховка отправителя пересобирает недоставленное сообщение в НОВЫЙ
    /// конверт с новым `msg_id`. Дедуп по `msg_id` такую копию не ловит — для
    /// него это другое сообщение, — и баннер поднимается заново. Схлопывание по
    /// беседе при этом работает верно: запись в центре уведомлений одна. Но у
    /// `apns-collapse-id` семантика ЗАМЕНЫ, а замена всплывает и звучит.
    ///
    /// Ключ здесь — стабильный идентификатор сообщения. Окно намеренно
    /// конечное: отметка значит «баннер отправлен», а не «человек его увидел».
    #[tokio::test]
    async fn alert_dedup_suppresses_repeat_within_window() {
        let dir = tempfile::tempdir().unwrap();
        let store = RelayStore::open(&dir.path().join("relay.db")).await.unwrap();
        let window = 10 * 60 * 1000;
        let t0 = 1_000_000i64;

        assert!(
            store
                .try_mark_alert_shown("devA", "alert:evt1", t0, window)
                .await
                .unwrap(),
            "первый баннер о сообщении обязан пройти"
        );
        assert!(
            !store
                .try_mark_alert_shown("devA", "alert:evt1", t0 + 90_000, window)
                .await
                .unwrap(),
            "переотправка через полторы минуты не должна всплывать заново"
        );
        assert!(
            !store
                .try_mark_alert_shown("devA", "alert:evt1", t0 + 9 * 60_000, window)
                .await
                .unwrap(),
            "и на девятой минуте тоже: окно ещё не вышло"
        );
    }

    #[tokio::test]
    async fn alert_dedup_allows_banner_again_after_window() {
        let dir = tempfile::tempdir().unwrap();
        let store = RelayStore::open(&dir.path().join("relay.db")).await.unwrap();
        let window = 10 * 60 * 1000;
        let t0 = 2_000_000i64;

        assert!(store.try_mark_alert_shown("devA", "alert:evt2", t0, window).await.unwrap());
        assert!(
            store
                .try_mark_alert_shown("devA", "alert:evt2", t0 + window + 1, window)
                .await
                .unwrap(),
            "по истечении окна баннер разрешается снова: отметка означала \
             «отправлен», а не «увиден», и первый push мог не дойти вовсе"
        );
    }

    #[tokio::test]
    async fn alert_dedup_is_per_device_and_per_message() {
        let dir = tempfile::tempdir().unwrap();
        let store = RelayStore::open(&dir.path().join("relay.db")).await.unwrap();
        let window = 10 * 60 * 1000;
        let t0 = 3_000_000i64;

        assert!(store.try_mark_alert_shown("devA", "alert:e1", t0, window).await.unwrap());
        assert!(
            store.try_mark_alert_shown("devB", "alert:e1", t0, window).await.unwrap(),
            "второе устройство собеседника обязано получить свой баннер"
        );
        assert!(
            store.try_mark_alert_shown("devA", "alert:e2", t0, window).await.unwrap(),
            "другое сообщение — другой баннер, иначе переписка станет немой"
        );
    }

    #[tokio::test]
    async fn push_wake_dedup_marks_once_per_msg() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("relay.db");
        let store = RelayStore::open(&path).await.unwrap();

        let first = store
            .try_mark_push_wake_sent("dev1", "msg1", 1_000)
            .await
            .unwrap();
        assert!(first);

        let second = store
            .try_mark_push_wake_sent("dev1", "msg1", 2_000)
            .await
            .unwrap();
        assert!(!second);

        let other_msg = store
            .try_mark_push_wake_sent("dev1", "msg2", 3_000)
            .await
            .unwrap();
        assert!(other_msg);
    }
}

