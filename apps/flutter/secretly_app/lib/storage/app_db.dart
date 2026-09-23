// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, Directory, File;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../stickers/sticker_share_mode.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

import '../calls/call_event.dart';
import '../messages/message_delivery_state.dart';
import 'safe_backup_snapshot_contract.dart';

typedef GroupMembershipStateRecord = ({
  String profileId,
  String status,
  String role,
  String? sourceLinkId,
  String? tag,
  int createdAtMs,
  int updatedAtMs,
});

typedef RoomMessageReceiptRecord = ({
  String payloadEventId,
  String readerProfileId,
  String? readerDeviceId,
  String status,
  int updatedAtMs,
});

typedef RoomMessageReceiptSummary = ({
  int deliveredCount,
  int readCount,
  List<String> deliveredByProfileIds,
  List<String> readByProfileIds,
});

typedef PendingReceiptRecord = ({
  String peerDeviceId,
  String? peerProfileId,
  String payloadEventId,
  String? convoId,
  String status,
  int createdAtMs,
  int updatedAtMs,
});

typedef RoomCallParticipantStateRecord = ({
  String profileId,
  String deviceId,
  String joinState,
  bool supportsVideo,
  bool supportsScreenShare,
  bool muted,
  bool deafened,
  bool videoEnabled,
  bool screenShareEnabled,
  bool speaking,
  int joinedAtMs,
  int? leftAtMs,
  int updatedAtMs,
});

typedef RoomCallStateRecord = ({
  String groupId,
  String callId,
  String state,
  String mediaType,
  String createdByProfileId,
  String createdByDeviceId,
  int stateVersion,
  int startedAtMs,
  int updatedAtMs,
  int? endedAtMs,
  int expiresAtMs,
  List<RoomCallParticipantStateRecord> participants,
});

typedef StickerPackCatalogRecord = ({
  String packId,
  int packVersion,
  String title,
  String description,
  String iconStickerId,
  String iconEmojiHint,
  int? featuredRank,
  List<String> tags,
  bool installed,
  int stickerCount,
  int updatedAtMs,
  int? installedAtMs,
  /// Режим доступа к набору. Для наборов каталога не имеет смысла и всегда
  /// читается значением по умолчанию — режим есть только у СВОИХ наборов.
  StickerShareMode shareMode,
});

typedef StickerPackStickerRecord = ({
  String packId,
  int packVersion,
  String stickerId,
  String fileName,
  String localPath,
  String format,
  bool animated,
  String emojiHint,
  String label,
  List<String> keywords,
  String sha256B64,
  int sizeBytes,
  int? downloadedAtMs,
  int? lastAccessedAtMs,
});

/// PHANTOM-CHURN FIX (2026-06-25): after a parked (quarantined) inbound has
/// failed replay this many times it is treated as permanently undecryptable and
/// the self-healing recovery sweep STOPS proactively force-reset-pinging its
/// sender. This kills the "phantom notifications every minute" loop a genuine
/// ratchet bad-state message (old-chain ciphertext that can never decrypt) would
/// otherwise drive forever. Small enough to stop the visible churn quickly, big
/// enough that a genuinely transient desync is still proactively healed first.
const int kInboxQuarantineForcePingMaxAttempts = 5;

/// After this many failed replays a quarantine row is purged entirely. Far
/// beyond the 3-attempt live-decrypt budget and every session-recovery window,
/// so only a provably-dead (or long-undeliverable) ciphertext is ever dropped —
/// a genuinely recoverable transient message heals long before this.
const int kInboxQuarantineMaxReplayAttempts = 50;

/// The database opened, but its first real page read failed — SQLCipher only
/// checks the passphrase then, so this is where a mis-keyed (or not-yet-
/// readable) open actually shows up.
///
/// Deliberately its own type. It must NOT be mistaken for a corrupt file: on a
/// tester's iPhone this fired at launch and force-killing the app cured it,
/// which means the key was right and the read was transient. The caller
/// retries with a freshly read passphrase instead of quarantining a database
/// that is very probably healthy.
class DbKeyUnverified implements Exception {
  DbKeyUnverified(this.cause);
  final Object cause;
  @override
  String toString() => 'DbKeyUnverified($cause)';
}

class AppDb {
  AppDb._(this._db);

  /// Максимум идентификаторов в одном `IN (...)`.
  ///
  /// 🔴 ЭТО ПРЕДЕЛ SQLITE, А НЕ ВКУСОВЩИНА. Число параметров запроса ограничено
  /// `SQLITE_MAX_VARIABLE_NUMBER`: 999 в сборках до 3.32 и 32766 в новых. Какая
  /// именно версия скомпилирована внутри `sqflite_sqlcipher` на конкретном
  /// устройстве, приложение не контролирует, поэтому берётся заведомо
  /// безопасное значение с запасом.
  ///
  /// Что происходило без этого: `_applyAutoDeleteRetention` собирает ВСЕ
  /// события чата старше отсечки — без `limit` — и подставляет их одним
  /// списком. В чате, где под автоудаление попала тысяча сообщений, запрос
  /// падал с `too many SQL variables`, то есть автоудаление переставало
  /// работать целиком. Это отказ, а не замедление.
  ///
  /// Накладные расходы дробления пренебрежимы: несколько `DELETE` вместо
  /// одного, внутри той же транзакции.
  static const int idChunkSize = 500;

  /// Режет [items] на порции не длиннее [idChunkSize].
  ///
  /// Пустой вход даёт пустой результат — вызывающему не нужно проверять
  /// отдельно. Порядок сохраняется.
  static Iterable<List<T>> chunkIds<T>(List<T> items) sync* {
    for (var start = 0; start < items.length; start += idChunkSize) {
      final end = start + idChunkSize;
      yield items.sublist(start, end > items.length ? items.length : end);
    }
  }

  /// NOT final on purpose — see [adoptConnectionFrom].
  Database _db;

  /// Replaces this wrapper's underlying connection with [reopened]'s, in place.
  ///
  /// 🔴 WHY THE SWAP HAPPENS INSIDE THE OBJECT (2026-07-31, field).
  ///
  /// sqflite's singleInstance handle can be closed from under the app, after
  /// which every query throws `database_closed`. The watchdog recovered by
  /// opening a fresh [AppDb] and REPLACING the controller's reference — but a
  /// reference is not the only one there is. `RelayClient`, both ratchet
  /// session managers and the outgoing scheduler each captured the AppDb at
  /// construction and kept it for the life of the app. They went on using the
  /// corpse: the inbound pump logged `database_closed` once a second while the
  /// watchdog cheerfully logged `unexpected_closed_reopen_ok`, and messages,
  /// receipts and CALL SIGNALS all stopped being applied until the user killed
  /// the app. Observed on a device: ~4 minutes of a totally dead inbox with a
  /// "recovered" log line every few seconds.
  ///
  /// Swapping the connection inside the object every holder already points at
  /// heals all of them at once — and, more importantly, makes it impossible to
  /// forget a holder. Adding a setter to each collaborator would have fixed
  /// today's four and quietly missed tomorrow's fifth.
  ///
  /// The caller must NOT close [reopened] afterwards: both wrappers now share
  /// one live connection.
  void adoptConnectionFrom(AppDb reopened) {
    _db = reopened._db;
  }

  static const _schemaVersion = 68;

  static String _escapeSqlString(String s) {
    // Minimal SQL string literal escaping for PRAGMA key.
    return s.replaceAll("'", "''");
  }

  static List<String> _decodeStringListJson(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded
          .map((item) => (item as String?)?.trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  /// The real upgrade chain, lifted out of [open] so it can be TESTED.
  ///
  /// 🔴 WHY (found during the Э-4 audit, 2026-08-02): this was a local closure
  /// inside [open], unreachable from any test — and [openForTesting] does not
  /// run it at all (its onUpgrade calls `_createSchema`, which is a no-op on a
  /// table that already exists). So all 59 branches had never been executed by
  /// a test even once. That is the least recoverable failure this codebase can
  /// have: a user whose database refuses to open loses their history, and no
  /// server switch can undo it.
  ///
  /// Moved VERBATIM — the diff shows no change to any branch. Production still
  /// reaches it through [open]; tests call it directly against a database
  /// standing in for an older install.
  static Future<void> runMigrationsForTest(
      Database db,
      int oldVersion,
      int newVersion,
    ) async {
      if (oldVersion < 2) {
        await db.execute('''
CREATE TABLE inbox_seen (
  msg_id TEXT PRIMARY KEY,
  seen_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX inbox_seen_seen_at_idx ON inbox_seen(seen_at_ms);',
        );
      }
      if (oldVersion < 3) {
        await db.execute('''
CREATE TABLE attachments (
  blob_id TEXT PRIMARY KEY,
  file_key_b64 TEXT NOT NULL,
  mime TEXT,
  plaintext_size_bytes INTEGER NOT NULL,
  ciphertext_size_bytes INTEGER NOT NULL,
  expires_at_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX attachments_expires_idx ON attachments(expires_at_ms);',
        );
      }
      if (oldVersion < 4) {
        await db.execute('''
CREATE TABLE sessions (
  peer_device_id TEXT PRIMARY KEY,
  root_key_b64 TEXT NOT NULL,
  send_chain_key_b64 TEXT NOT NULL,
  recv_chain_key_b64 TEXT NOT NULL,
  send_count INTEGER NOT NULL,
  recv_count INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX sessions_updated_idx ON sessions(updated_at_ms);',
        );
      }
      if (oldVersion < 5) {
        await db.execute('''
CREATE TABLE contacts (
  contact_profile_id TEXT PRIMARY KEY,
  display_name TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX contacts_updated_idx ON contacts(updated_at_ms);',
        );

        await db.execute('''
CREATE TABLE conversations (
  convo_id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  peer_profile_id TEXT,
  title TEXT,
  last_event_at_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX conversations_last_event_idx ON conversations(last_event_at_ms);',
        );

        await db.execute('''
CREATE TABLE device_profiles (
  device_id TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX device_profiles_profile_idx ON device_profiles(profile_id);',
        );
      }
      if (oldVersion < 6) {
        await db.execute('''
CREATE TABLE requests (
  contact_profile_id TEXT PRIMARY KEY,
  status TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');

        if (oldVersion < 42) {
          await db.execute('''
CREATE TABLE IF NOT EXISTS recent_stickers (
  profile_id TEXT NOT NULL,
  pack_id TEXT NOT NULL,
  pack_version INTEGER NOT NULL,
  sticker_id TEXT NOT NULL,
  last_used_at_ms INTEGER NOT NULL,
  use_count INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY(profile_id, pack_id, pack_version, sticker_id)
);
''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS recent_stickers_profile_last_used_idx ON recent_stickers(profile_id, last_used_at_ms DESC);',
          );
        }
        // Historical: some early schemas created this table before it was later formalized.
        // Keep it idempotent to avoid upgrade failures.
        await db.execute('''
CREATE TABLE IF NOT EXISTS blocked_profiles (
  blocked_profile_id TEXT PRIMARY KEY,
  created_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX requests_status_updated_idx ON requests(status, updated_at_ms);',
        );
      }
      if (oldVersion < 7) {
        // Track local message status for UI (pending/sent/failed).
        await db.execute(
          "ALTER TABLE events ADD COLUMN local_state TEXT NOT NULL DEFAULT 'received';",
        );
        await db.execute(
          'CREATE INDEX events_convo_created_state_idx ON events(convo_id, created_at_ms, local_state);',
        );

        // Link outbox entries to a local event for status updates.
        await db.execute('ALTER TABLE outbox ADD COLUMN event_id_ref TEXT;');
        await db.execute(
          'CREATE INDEX outbox_event_ref_idx ON outbox(event_id_ref);',
        );
      }
      if (oldVersion < 8) {
        // Link stored ciphertext rows to payload-level event ids (for receipts).
        await db.execute(
          'ALTER TABLE events ADD COLUMN payload_event_id TEXT;',
        );
        await db.execute(
          'CREATE INDEX events_payload_id_idx ON events(payload_event_id);',
        );
      }
      if (oldVersion < 9) {
        await db.execute('ALTER TABLE events ADD COLUMN read_at_ms INTEGER;');
        await db.execute(
          'CREATE INDEX events_convo_read_idx ON events(convo_id, read_at_ms);',
        );
      }
      if (oldVersion < 10) {
        await db.execute('''
CREATE TABLE contact_devices (
  contact_profile_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  identity_key_pub_b64 TEXT NOT NULL,
  signed_prekey_pub_b64 TEXT NOT NULL,
  signed_prekey_sig_b64 TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  verified_at_ms INTEGER,
  PRIMARY KEY(contact_profile_id, device_id)
);
''');
        await db.execute(
          'CREATE INDEX contact_devices_profile_idx ON contact_devices(contact_profile_id);',
        );
      }
      if (oldVersion < 11) {
        await db.execute('''
CREATE TABLE sessions_v3 (
  peer_device_id TEXT PRIMARY KEY,
  root_key_b64 TEXT NOT NULL,
  dh_self_seed_b64 TEXT NOT NULL,
  dh_self_pub_b64 TEXT NOT NULL,
  dh_remote_pub_b64 TEXT,
  send_chain_key_b64 TEXT,
  recv_chain_key_b64 TEXT,
  ns INTEGER NOT NULL,
  nr INTEGER NOT NULL,
  pn INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX sessions_v3_updated_idx ON sessions_v3(updated_at_ms);',
        );

        await db.execute('''
CREATE TABLE skipped_message_keys (
  peer_device_id TEXT NOT NULL,
  dh_pub_b64 TEXT NOT NULL,
  msg_num INTEGER NOT NULL,
  mk_b64 TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY(peer_device_id, dh_pub_b64, msg_num)
);
''');
        await db.execute(
          'CREATE INDEX skipped_message_keys_peer_idx ON skipped_message_keys(peer_device_id);',
        );
      }
      if (oldVersion < 12) {
        // Cache a local symmetric-encrypted copy of decrypted plaintext for display.
        // Ratchet ciphertexts are stateful and cannot be safely decrypted twice.
        await db.execute(
          'ALTER TABLE events ADD COLUMN local_ciphertext_b64 TEXT;',
        );
        await db.execute(
          'CREATE INDEX events_convo_created_local_idx ON events(convo_id, created_at_ms, local_ciphertext_b64);',
        );
      }
      if (oldVersion < 13) {
        // Conversation UI state.
        await db.execute(
          'ALTER TABLE conversations ADD COLUMN pinned_at_ms INTEGER;',
        );
        await db.execute(
          "ALTER TABLE conversations ADD COLUMN muted INTEGER NOT NULL DEFAULT 0;",
        );
        await db.execute(
          'CREATE INDEX conversations_pinned_idx ON conversations(pinned_at_ms);',
        );
        await db.execute(
          'CREATE INDEX conversations_muted_idx ON conversations(muted);',
        );
      }
      if (oldVersion < 14) {
        // Archive chats (UI-only, local).
        await db.execute(
          'ALTER TABLE conversations ADD COLUMN archived_at_ms INTEGER;',
        );
        await db.execute(
          'CREATE INDEX conversations_archived_idx ON conversations(archived_at_ms);',
        );
      }
      if (oldVersion < 15) {
        // Server-backed blocks (UI in Settings → Privacy).
        await db.execute('''
CREATE TABLE IF NOT EXISTS blocked_profiles (
  blocked_profile_id TEXT PRIMARY KEY,
  created_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS blocked_profiles_created_idx ON blocked_profiles(created_at_ms);',
        );
      }
      if (oldVersion < 16) {
        // Local per-contact avatar (self-only).
        await db.execute('ALTER TABLE contacts ADD COLUMN avatar_path TEXT;');
      }
      if (oldVersion < 17) {
        // Cache remote profile metadata (nickname + avatar) for UI.
        await db.execute('''
CREATE TABLE IF NOT EXISTS profile_meta (
  profile_id TEXT PRIMARY KEY,
  nickname TEXT,
  avatar_path TEXT,
  bio TEXT,
  privacy_audience_json TEXT,
  frame_id TEXT,
  cover_id TEXT,
  cover_path TEXT,
  emoji_status TEXT,
  premium_badge TEXT,
  updated_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS profile_meta_updated_idx ON profile_meta(updated_at_ms);',
        );
      }
      if (oldVersion < 18) {
        // Local contact emoji + per-chat auto-delete retention.
        await db.execute('ALTER TABLE contacts ADD COLUMN contact_emoji TEXT;');
        await db.execute(
          'ALTER TABLE conversations ADD COLUMN auto_delete_seconds INTEGER;',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS conversations_auto_delete_idx ON conversations(auto_delete_seconds);',
        );
      }
      if (oldVersion < 19) {
        await db.execute('''
CREATE TABLE IF NOT EXISTS message_reactions (
  event_id TEXT NOT NULL,
  convo_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  actor_name TEXT,
  actor_avatar_path TEXT,
  emoji TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(event_id, profile_id)
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS message_reactions_convo_idx ON message_reactions(convo_id, updated_at_ms DESC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS message_reactions_event_idx ON message_reactions(event_id, updated_at_ms DESC);',
        );
      }
      if (oldVersion < 20) {
        await db.execute('''
CREATE TABLE IF NOT EXISTS group_members (
  group_id TEXT NOT NULL,
  member_profile_id TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY(group_id, member_profile_id)
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS group_members_group_idx ON group_members(group_id);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS group_members_member_idx ON group_members(member_profile_id);',
        );
      }
      if (oldVersion < 21) {
        // Add last_seen_at_ms to profile_meta for online presence tracking.
        await _ensureColumnExists(
          db,
          table: 'profile_meta',
          column: 'last_seen_at_ms',
          alterSql:
              'ALTER TABLE profile_meta ADD COLUMN last_seen_at_ms INTEGER;',
        );
      }
      if (oldVersion < 41) {
        await _ensureColumnExists(
          db,
          table: 'profile_meta',
          column: 'bio',
          alterSql: 'ALTER TABLE profile_meta ADD COLUMN bio TEXT;',
        );
        await _ensureColumnExists(
          db,
          table: 'profile_meta',
          column: 'privacy_audience_json',
          alterSql:
              'ALTER TABLE profile_meta ADD COLUMN privacy_audience_json TEXT;',
        );
      }
      if (oldVersion < 51) {
        // Optional cosmetic (unsigned) profile fields synced via profile_meta.
        await _ensureColumnExists(
          db,
          table: 'profile_meta',
          column: 'frame_id',
          alterSql: 'ALTER TABLE profile_meta ADD COLUMN frame_id TEXT;',
        );
        await _ensureColumnExists(
          db,
          table: 'profile_meta',
          column: 'cover_id',
          alterSql: 'ALTER TABLE profile_meta ADD COLUMN cover_id TEXT;',
        );
      }
      if (oldVersion < 52) {
        // Cached custom-cover image file (peer covers synced via profile_meta).
        await _ensureColumnExists(
          db,
          table: 'profile_meta',
          column: 'cover_path',
          alterSql: 'ALTER TABLE profile_meta ADD COLUMN cover_path TEXT;',
        );
      }
      if (oldVersion < 53) {
        // Premium emoji status (an emoji shown next to the name) synced via
        // profile_meta.
        await _ensureColumnExists(
          db,
          table: 'profile_meta',
          column: 'emoji_status',
          alterSql: 'ALTER TABLE profile_meta ADD COLUMN emoji_status TEXT;',
        );
      }
      if (oldVersion < 54) {
        // Premium badge marker (shown next to the name) synced via profile_meta.
        await _ensureColumnExists(
          db,
          table: 'profile_meta',
          column: 'premium_badge',
          alterSql: 'ALTER TABLE profile_meta ADD COLUMN premium_badge TEXT;',
        );
      }
      if (oldVersion < 55) {
        // User-created (custom) chat folders. Local-only organization of the
        // chat list — never affects messaging, encryption, or sync. IF NOT
        // EXISTS keeps this harmless if the same statements also run via
        // _createSchema / _ensureCriticalTables on the same open.
        await db.execute('''
CREATE TABLE IF NOT EXISTS chat_folders (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT,
  position INTEGER NOT NULL DEFAULT 0,
  created_at_ms INTEGER NOT NULL
);
''');
        await db.execute('''
CREATE TABLE IF NOT EXISTS chat_folder_members (
  folder_id TEXT NOT NULL,
  convo_id TEXT NOT NULL,
  PRIMARY KEY (folder_id, convo_id)
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS chat_folder_members_convo_idx ON chat_folder_members(convo_id);',
        );
      }
      if (oldVersion < 56) {
        // A1 ZERO-LOSS: parks a DECRYPTED inbound group message when its sender
        // isn't yet in the local roster (membership-convergence race). The frame
        // is re-applied the moment membership converges and TTL-pruned if the
        // sender is never confirmed. Local-only; never affects encryption/sync.
        // IF NOT EXISTS keeps it harmless alongside _createSchema /
        // _ensureCriticalTables on the same open.
        await db.execute('''
CREATE TABLE IF NOT EXISTS deferred_room_inbound (
  synthetic_event_id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
  sender_profile_id TEXT NOT NULL,
  sender_device_id TEXT,
  command_text TEXT NOT NULL,
  msg_id TEXT,
  ciphertext_b64 TEXT,
  created_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS deferred_room_inbound_group_idx ON deferred_room_inbound(group_id, sender_profile_id);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS deferred_room_inbound_created_idx ON deferred_room_inbound(created_at_ms);',
        );
      }
      if (oldVersion < 57) {
        // SERVER-SIDE SCHEDULED DELIVERY (2026-07-17): outbox row carries the
        // relay release time. Additive, DEFAULT 0 = immediate (every existing
        // row) → the migration changes no live behaviour.
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'deliver_at_ms',
          alterSql:
              'ALTER TABLE outbox ADD COLUMN deliver_at_ms INTEGER NOT NULL DEFAULT 0;',
        );
      }
      if (oldVersion < 22) {
        await db.execute('''
CREATE TABLE IF NOT EXISTS group_settings (
  group_id TEXT PRIMARY KEY,
  owner_profile_id TEXT NOT NULL,
  description TEXT,
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
  pinned_message_event_id TEXT,
  membership_version INTEGER NOT NULL DEFAULT 0,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS group_settings_owner_idx ON group_settings(owner_profile_id);',
        );

        await db.execute('''
CREATE TABLE IF NOT EXISTS group_memberships (
  group_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  status TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member',
  source_link_id TEXT,
  tag TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(group_id, profile_id)
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS group_memberships_group_status_idx ON group_memberships(group_id, status, created_at_ms ASC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS group_memberships_profile_idx ON group_memberships(profile_id, updated_at_ms DESC);',
        );

        await db.execute('''
CREATE TABLE IF NOT EXISTS group_admins (
  group_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY(group_id, profile_id)
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS group_admins_group_idx ON group_admins(group_id);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS group_admins_profile_idx ON group_admins(profile_id);',
        );

        await db.execute('''
CREATE TABLE IF NOT EXISTS group_invite_links (
  link_id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
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
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS group_invite_links_group_idx ON group_invite_links(group_id, updated_at_ms DESC);',
        );
      }
      if (oldVersion < 23) {
        await db.execute('''
CREATE TABLE IF NOT EXISTS pending_no_device_send (
  local_event_id TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL,
  payload_b64 TEXT NOT NULL,
  transport_meta_json TEXT,
  created_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS pending_no_device_send_profile_idx ON pending_no_device_send(profile_id, created_at_ms);',
        );
      }
      if (oldVersion < 24) {
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'correlation_id',
          alterSql: 'ALTER TABLE outbox ADD COLUMN correlation_id TEXT;',
        );
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'payload_event_id',
          alterSql: 'ALTER TABLE outbox ADD COLUMN payload_event_id TEXT;',
        );
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'convo_id',
          alterSql: 'ALTER TABLE outbox ADD COLUMN convo_id TEXT;',
        );
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'last_attempt_at_ms',
          alterSql: 'ALTER TABLE outbox ADD COLUMN last_attempt_at_ms INTEGER;',
        );
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'last_error_code',
          alterSql: 'ALTER TABLE outbox ADD COLUMN last_error_code TEXT;',
        );
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'last_error_message_redacted',
          alterSql:
              'ALTER TABLE outbox ADD COLUMN last_error_message_redacted TEXT;',
        );
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'server_acked_at_ms',
          alterSql: 'ALTER TABLE outbox ADD COLUMN server_acked_at_ms INTEGER;',
        );
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'device_delivered_at_ms',
          alterSql:
              'ALTER TABLE outbox ADD COLUMN device_delivered_at_ms INTEGER;',
        );
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'expires_at_ms',
          alterSql: 'ALTER TABLE outbox ADD COLUMN expires_at_ms INTEGER;',
        );
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'priority',
          alterSql:
              "ALTER TABLE outbox ADD COLUMN priority INTEGER NOT NULL DEFAULT 0;",
        );
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'transport_hint',
          alterSql: 'ALTER TABLE outbox ADD COLUMN transport_hint TEXT;',
        );
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'retry_bucket',
          alterSql:
              "ALTER TABLE outbox ADD COLUMN retry_bucket TEXT NOT NULL DEFAULT '';",
        );
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'locked_by_worker',
          alterSql: 'ALTER TABLE outbox ADD COLUMN locked_by_worker TEXT;',
        );
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'locked_at_ms',
          alterSql: 'ALTER TABLE outbox ADD COLUMN locked_at_ms INTEGER;',
        );

        await db.execute('''
CREATE TABLE IF NOT EXISTS message_attempt_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  correlation_id TEXT,
  local_event_id TEXT,
  msg_id TEXT,
  to_device_id TEXT,
  started_at_ms INTEGER NOT NULL,
  finished_at_ms INTEGER,
  attempt_index INTEGER NOT NULL,
  transport TEXT,
  result TEXT,
  error_code TEXT,
  error_message_redacted TEXT,
  latency_ms INTEGER
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS message_attempt_log_correlation_idx ON message_attempt_log(correlation_id, started_at_ms DESC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS message_attempt_log_local_event_idx ON message_attempt_log(local_event_id, started_at_ms DESC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS message_attempt_log_msg_idx ON message_attempt_log(msg_id, started_at_ms DESC);',
        );

        await db.execute('''
CREATE TABLE IF NOT EXISTS message_state_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  correlation_id TEXT,
  local_event_id TEXT,
  previous_state TEXT,
  new_state TEXT NOT NULL,
  reason_code TEXT,
  created_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS message_state_log_correlation_idx ON message_state_log(correlation_id, created_at_ms DESC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS message_state_log_local_event_idx ON message_state_log(local_event_id, created_at_ms DESC);',
        );

        await db.execute('''
CREATE TABLE IF NOT EXISTS message_diag_snapshot (
  local_event_id TEXT PRIMARY KEY,
  correlation_id TEXT,
  convo_id TEXT,
  message_state TEXT,
  outbox_state_summary TEXT,
  last_error_code TEXT,
  last_error_message_redacted TEXT,
  updated_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS message_diag_snapshot_correlation_idx ON message_diag_snapshot(correlation_id, updated_at_ms DESC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS message_diag_snapshot_convo_idx ON message_diag_snapshot(convo_id, updated_at_ms DESC);',
        );

        await db.execute('''
CREATE TABLE IF NOT EXISTS delivery_receipts_pending (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  payload_event_id TEXT NOT NULL,
  status TEXT NOT NULL,
  sender_device_id TEXT,
  sender_profile_id TEXT,
  created_at_ms INTEGER NOT NULL,
  applied_at_ms INTEGER
);
''');
        await db.execute('''
CREATE TABLE IF NOT EXISTS call_journal (
  call_id TEXT NOT NULL,
  call_attempt_id TEXT PRIMARY KEY,
  convo_id TEXT NOT NULL,
  peer_profile_id TEXT NOT NULL,
  direction TEXT NOT NULL,
  scope TEXT NOT NULL,
  media_type TEXT NOT NULL,
  result TEXT NOT NULL,
  started_at_ms INTEGER NOT NULL,
  connected_at_ms INTEGER,
  ended_at_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  end_reason TEXT,
  failure_code TEXT,
  peer_display_name TEXT,
  peer_avatar_path TEXT,
  did_connect INTEGER NOT NULL DEFAULT 0,
  had_video INTEGER NOT NULL DEFAULT 0,
  had_screen_share INTEGER NOT NULL DEFAULT 0,
  quality_summary_json TEXT,
  created_local_event_id TEXT,
  synced_chat_event_id TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
        await db.execute('''
CREATE TABLE IF NOT EXISTS call_journal (
  call_id TEXT NOT NULL,
  call_attempt_id TEXT PRIMARY KEY,
  convo_id TEXT NOT NULL,
  peer_profile_id TEXT NOT NULL,
  direction TEXT NOT NULL,
  scope TEXT NOT NULL,
  media_type TEXT NOT NULL,
  result TEXT NOT NULL,
  started_at_ms INTEGER NOT NULL,
  connected_at_ms INTEGER,
  ended_at_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  end_reason TEXT,
  failure_code TEXT,
  peer_display_name TEXT,
  peer_avatar_path TEXT,
  did_connect INTEGER NOT NULL DEFAULT 0,
  had_video INTEGER NOT NULL DEFAULT 0,
  had_screen_share INTEGER NOT NULL DEFAULT 0,
  quality_summary_json TEXT,
  created_local_event_id TEXT,
  synced_chat_event_id TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
        await db.execute('''
CREATE TABLE IF NOT EXISTS call_journal (
  call_id TEXT NOT NULL,
  call_attempt_id TEXT PRIMARY KEY,
  convo_id TEXT NOT NULL,
  peer_profile_id TEXT NOT NULL,
  direction TEXT NOT NULL,
  scope TEXT NOT NULL,
  media_type TEXT NOT NULL,
  result TEXT NOT NULL,
  started_at_ms INTEGER NOT NULL,
  connected_at_ms INTEGER,
  ended_at_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  end_reason TEXT,
  peer_display_name TEXT,
  peer_avatar_path TEXT,
  did_connect INTEGER NOT NULL DEFAULT 0,
  had_video INTEGER NOT NULL DEFAULT 0,
  had_screen_share INTEGER NOT NULL DEFAULT 0,
  quality_summary_json TEXT,
  created_local_event_id TEXT,
  synced_chat_event_id TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS delivery_receipts_pending_payload_idx ON delivery_receipts_pending(payload_event_id, created_at_ms DESC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS call_journal_convo_ended_idx ON call_journal(convo_id, ended_at_ms DESC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS call_journal_peer_ended_idx ON call_journal(peer_profile_id, ended_at_ms DESC);',
        );

        await db.execute(
          'CREATE INDEX IF NOT EXISTS outbox_state_retry_idx ON outbox(state, next_retry_at_ms);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS outbox_to_device_state_retry_idx ON outbox(to_device_id, state, next_retry_at_ms);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS outbox_correlation_idx ON outbox(correlation_id);',
        );
      }
      if (oldVersion < 25) {
        await db.execute('''
CREATE TABLE IF NOT EXISTS call_journal (
  call_id TEXT NOT NULL,
  call_attempt_id TEXT PRIMARY KEY,
  convo_id TEXT NOT NULL,
  peer_profile_id TEXT NOT NULL,
  direction TEXT NOT NULL,
  scope TEXT NOT NULL,
  media_type TEXT NOT NULL,
  result TEXT NOT NULL,
  started_at_ms INTEGER NOT NULL,
  connected_at_ms INTEGER,
  ended_at_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  end_reason TEXT,
  peer_display_name TEXT,
  peer_avatar_path TEXT,
  did_connect INTEGER NOT NULL DEFAULT 0,
  had_video INTEGER NOT NULL DEFAULT 0,
  had_screen_share INTEGER NOT NULL DEFAULT 0,
  quality_summary_json TEXT,
  created_local_event_id TEXT,
  synced_chat_event_id TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS call_journal_convo_ended_idx ON call_journal(convo_id, ended_at_ms DESC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS call_journal_peer_ended_idx ON call_journal(peer_profile_id, ended_at_ms DESC);',
        );
      }
      if (oldVersion < 26) {
        await _ensureColumnExists(
          db,
          table: 'call_journal',
          column: 'acknowledged_at_ms',
          alterSql:
              'ALTER TABLE call_journal ADD COLUMN acknowledged_at_ms INTEGER;',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS call_journal_convo_result_ack_idx ON call_journal(convo_id, result, acknowledged_at_ms, ended_at_ms DESC);',
        );
      }
      if (oldVersion < 27) {
        await _ensureColumnExists(
          db,
          table: 'outbox',
          column: 'transport_meta_json',
          alterSql: 'ALTER TABLE outbox ADD COLUMN transport_meta_json TEXT;',
        );
      }
      if (oldVersion < 29) {
        await _ensureColumnExists(
          db,
          table: 'events',
          column: 'scheduled_at_ms',
          alterSql: 'ALTER TABLE events ADD COLUMN scheduled_at_ms INTEGER;',
        );
      }
      if (oldVersion < 30) {
        await _ensureColumnExists(
          db,
          table: 'attachments',
          column: 'access_token_b64',
          alterSql:
              "ALTER TABLE attachments ADD COLUMN access_token_b64 TEXT NOT NULL DEFAULT '';",
        );
      }
      if (oldVersion < 31) {
        await _ensureColumnExists(
          db,
          table: 'call_journal',
          column: 'failure_code',
          alterSql: 'ALTER TABLE call_journal ADD COLUMN failure_code TEXT;',
        );
      }
      if (oldVersion < 32) {
        await _ensureColumnExists(
          db,
          table: 'group_settings',
          column: 'state_version',
          alterSql:
              'ALTER TABLE group_settings ADD COLUMN state_version INTEGER NOT NULL DEFAULT 0;',
        );
      }
      if (oldVersion < 33) {
        await _ensureColumnExists(
          db,
          table: 'group_settings',
          column: 'join_approval_required',
          alterSql:
              'ALTER TABLE group_settings ADD COLUMN join_approval_required INTEGER NOT NULL DEFAULT 0;',
        );
        await _ensureColumnExists(
          db,
          table: 'group_settings',
          column: 'membership_version',
          alterSql:
              'ALTER TABLE group_settings ADD COLUMN membership_version INTEGER NOT NULL DEFAULT 0;',
        );
        await db.execute('''
CREATE TABLE IF NOT EXISTS group_memberships (
  group_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  status TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member',
  source_link_id TEXT,
  tag TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(group_id, profile_id)
);
''');
        await _ensureColumnExists(
          db,
          table: 'group_memberships',
          column: 'role',
          alterSql:
              "ALTER TABLE group_memberships ADD COLUMN role TEXT NOT NULL DEFAULT 'member';",
        );
        await _ensureColumnExists(
          db,
          table: 'group_memberships',
          column: 'tag',
          alterSql: 'ALTER TABLE group_memberships ADD COLUMN tag TEXT;',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS group_memberships_group_status_idx ON group_memberships(group_id, status, created_at_ms ASC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS group_memberships_profile_idx ON group_memberships(profile_id, updated_at_ms DESC);',
        );
      }
      if (oldVersion < 34) {
        await _ensureColumnExists(
          db,
          table: 'group_settings',
          column: 'avatar_path',
          alterSql: 'ALTER TABLE group_settings ADD COLUMN avatar_path TEXT;',
        );
        await _ensureColumnExists(
          db,
          table: 'group_settings',
          column: 'avatar_hash',
          alterSql: 'ALTER TABLE group_settings ADD COLUMN avatar_hash TEXT;',
        );
      }
      if (oldVersion < 35) {
        await _ensureColumnExists(
          db,
          table: 'group_invite_links',
          column: 'expires_at_ms',
          alterSql:
              'ALTER TABLE group_invite_links ADD COLUMN expires_at_ms INTEGER;',
        );
        await _ensureColumnExists(
          db,
          table: 'group_invite_links',
          column: 'max_uses',
          alterSql:
              'ALTER TABLE group_invite_links ADD COLUMN max_uses INTEGER;',
        );
        await _ensureColumnExists(
          db,
          table: 'group_invite_links',
          column: 'use_count',
          alterSql:
              'ALTER TABLE group_invite_links ADD COLUMN use_count INTEGER NOT NULL DEFAULT 0;',
        );
        await _ensureColumnExists(
          db,
          table: 'group_invite_links',
          column: 'requires_approval',
          alterSql:
              'ALTER TABLE group_invite_links ADD COLUMN requires_approval INTEGER NOT NULL DEFAULT 0;',
        );
        await _ensureColumnExists(
          db,
          table: 'group_invite_links',
          column: 'allowed_role',
          alterSql:
              "ALTER TABLE group_invite_links ADD COLUMN allowed_role TEXT NOT NULL DEFAULT 'member';",
        );
      }
      if (oldVersion < 36) {
        await db.execute('''
CREATE TABLE IF NOT EXISTS room_message_receipts (
  payload_event_id TEXT NOT NULL,
  reader_profile_id TEXT NOT NULL,
  reader_device_id TEXT,
  status TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(payload_event_id, reader_profile_id)
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS room_message_receipts_payload_updated_idx ON room_message_receipts(payload_event_id, updated_at_ms DESC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS room_message_receipts_reader_updated_idx ON room_message_receipts(reader_profile_id, updated_at_ms DESC);',
        );
      }
      if (oldVersion < 37) {
        await db.execute('''
CREATE TABLE IF NOT EXISTS group_posting_state (
  group_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  last_admitted_at_ms INTEGER,
  next_allowed_at_ms INTEGER,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(group_id, profile_id)
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS group_posting_state_group_updated_idx ON group_posting_state(group_id, updated_at_ms DESC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS group_posting_state_profile_next_idx ON group_posting_state(profile_id, next_allowed_at_ms DESC);',
        );
      }
      if (oldVersion < 38) {
        await _ensureColumnExists(
          db,
          table: 'group_settings',
          column: 'pinned_message_event_id',
          alterSql:
              'ALTER TABLE group_settings ADD COLUMN pinned_message_event_id TEXT;',
        );
      }
      if (oldVersion < 39) {
        await _ensureColumnExists(
          db,
          table: 'group_memberships',
          column: 'tag',
          alterSql: 'ALTER TABLE group_memberships ADD COLUMN tag TEXT;',
        );
      }
      if (oldVersion < 40) {
        await db.execute('''
CREATE TABLE IF NOT EXISTS room_call_sessions (
  group_id TEXT PRIMARY KEY,
  call_id TEXT NOT NULL,
  state TEXT NOT NULL,
  media_type TEXT NOT NULL,
  created_by_profile_id TEXT NOT NULL,
  created_by_device_id TEXT NOT NULL,
  state_version INTEGER NOT NULL DEFAULT 0,
  started_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  ended_at_ms INTEGER,
  expires_at_ms INTEGER NOT NULL
);
''');
        await db.execute('''
CREATE TABLE IF NOT EXISTS room_call_participants (
  group_id TEXT NOT NULL,
  call_id TEXT NOT NULL,
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
  PRIMARY KEY(group_id, call_id, profile_id, device_id)
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS room_call_sessions_state_updated_idx ON room_call_sessions(state, updated_at_ms DESC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS room_call_sessions_expires_idx ON room_call_sessions(expires_at_ms);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS room_call_participants_group_updated_idx ON room_call_participants(group_id, updated_at_ms DESC);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS room_call_participants_profile_updated_idx ON room_call_participants(profile_id, updated_at_ms DESC);',
        );
      }
      if (oldVersion < 43) {
        await db.execute('''
CREATE TABLE IF NOT EXISTS sticker_packs (
  pack_id TEXT NOT NULL,
  pack_version INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  icon_sticker_id TEXT NOT NULL,
  icon_emoji_hint TEXT NOT NULL DEFAULT '',
  featured_rank INTEGER,
  tags_json TEXT NOT NULL DEFAULT '[]',
  installed INTEGER NOT NULL DEFAULT 0,
  sticker_count INTEGER NOT NULL DEFAULT 0,
  updated_at_ms INTEGER NOT NULL,
  installed_at_ms INTEGER,
  -- Режим доступа к своему набору (08.08.2026, Ш-1 ТЗ по стикерам).
  --
  -- 🔴 По умолчанию `sent_only`, потому что это РОВНО нынешнее поведение: свои
  -- наборы уже ездят зашифрованными блобами, и у того, кому отправили, доступ
  -- есть. Ш-1 обязан ничего не менять — он только даёт имя тому, что уже есть.
  -- Любое другое значение по умолчанию молча поменяло бы поведение старых
  -- наборов при обновлении.
  share_mode TEXT NOT NULL DEFAULT 'sent_only',
  PRIMARY KEY(pack_id, pack_version)
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS sticker_packs_featured_idx ON sticker_packs(installed DESC, featured_rank ASC, title COLLATE NOCASE ASC);',
        );
        await db.execute('''
CREATE TABLE IF NOT EXISTS sticker_pack_stickers (
  pack_id TEXT NOT NULL,
  pack_version INTEGER NOT NULL,
  sticker_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  local_path TEXT NOT NULL DEFAULT '',
  format TEXT NOT NULL,
  animated INTEGER NOT NULL DEFAULT 0,
  emoji_hint TEXT NOT NULL DEFAULT '',
  label TEXT NOT NULL DEFAULT '',
  keywords_json TEXT NOT NULL DEFAULT '[]',
  sha256_b64 TEXT NOT NULL DEFAULT '',
  size_bytes INTEGER NOT NULL DEFAULT 0,
  downloaded_at_ms INTEGER,
  last_accessed_at_ms INTEGER,
  -- Кэш выгруженного блоба (08.08.2026, С-11 ТЗ по стикерам).
  --
  -- 🔴 ЗАЧЕМ. Ссылка на шифртекст и ключ к нему создавались в момент ОТПРАВКИ и
  -- нигде не запоминались. Значит каждая отправка стикера платила полное
  -- шифрование и выгрузку заново, а собрать приглашение в набор из 50 стикеров
  -- означало 50 выгрузок подряд. Кэш чинит и то, и другое — причём одиночные
  -- отправки люди делают гораздо чаще, чем делятся наборами.
  --
  -- 🔴 `blob_expires_at_ms` обязателен. У блоба на сервере есть срок, и кэш без
  -- срока рано или поздно начал бы отдавать МЁРТВЫЕ ссылки: собеседник видел бы
  -- стикер, который не скачивается, и считал бы это поломкой приложения. Кэш без
  -- инвалидации хуже отсутствия кэша.
  blob_id TEXT NOT NULL DEFAULT '',
  blob_file_key_b64 TEXT NOT NULL DEFAULT '',
  blob_access_token_b64 TEXT NOT NULL DEFAULT '',
  blob_expires_at_ms INTEGER,
  PRIMARY KEY(pack_id, pack_version, sticker_id)
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS sticker_pack_stickers_pack_idx ON sticker_pack_stickers(pack_id, pack_version, sticker_id);',
        );
      }
      if (oldVersion < 44) {
        await _ensureColumnExists(
          db,
          table: 'contacts',
          column: 'display_name_is_custom',
          alterSql:
              'ALTER TABLE contacts ADD COLUMN display_name_is_custom INTEGER NOT NULL DEFAULT 0;',
        );
        await db.execute('''
UPDATE contacts
SET display_name_is_custom = CASE
  WHEN TRIM(COALESCE(display_name, '')) = '' THEN 0
  WHEN updated_at_ms > created_at_ms THEN 1
  ELSE 0
END
WHERE COALESCE(display_name_is_custom, 0) = 0;
''');
      }
      if (oldVersion < 45) {
        await _createPendingReceiptsSchema(db);
      }
      if (oldVersion < 46) {
        // Granular mute: time-limited mute + mentions-only mode.
        await _ensureColumnExists(
          db,
          table: 'conversations',
          column: 'muted_until_ms',
          alterSql:
              'ALTER TABLE conversations ADD COLUMN muted_until_ms INTEGER NOT NULL DEFAULT 0;',
        );
        await _ensureColumnExists(
          db,
          table: 'conversations',
          column: 'muted_mentions_only',
          alterSql:
              'ALTER TABLE conversations ADD COLUMN muted_mentions_only INTEGER NOT NULL DEFAULT 0;',
        );
      }
      if (oldVersion < 47) {
        // Inbound quarantine for session-recovery hardening (never drop an
        // undecryptable inbound message; re-decrypt it after the session heals).
        await db.execute('''
CREATE TABLE IF NOT EXISTS inbox_quarantine (
  msg_id TEXT PRIMARY KEY,
  sender_device_id TEXT,
  ciphertext_b64 TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_attempt_at_ms INTEGER NOT NULL DEFAULT 0,
  nacked_at_ms INTEGER NOT NULL DEFAULT 0,
  attested_from_device_id TEXT
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS inbox_quarantine_sender_idx ON inbox_quarantine(sender_device_id);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS inbox_quarantine_created_idx ON inbox_quarantine(created_at_ms);',
        );
      }
      if (oldVersion < 48) {
        // Candidate (archived) sessions for session-recovery hardening.
        await db.execute('''
CREATE TABLE IF NOT EXISTS sessions_v3_archive (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  peer_device_id TEXT NOT NULL,
  root_key_b64 TEXT NOT NULL,
  dh_self_seed_b64 TEXT NOT NULL,
  dh_self_pub_b64 TEXT NOT NULL,
  dh_remote_pub_b64 TEXT,
  send_chain_key_b64 TEXT,
  recv_chain_key_b64 TEXT,
  ns INTEGER NOT NULL,
  nr INTEGER NOT NULL,
  pn INTEGER NOT NULL,
  archived_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS sessions_v3_archive_peer_idx ON sessions_v3_archive(peer_device_id, id);',
        );
      }
      if (oldVersion < 49) {
        // Glare tie-break: marks a session as a fresh, unconfirmed initiator so
        // simultaneous re-establishments converge deterministically.
        await _ensureColumnExists(
          db,
          table: 'sessions_v3',
          column: 'initiator_pending_at_ms',
          alterSql:
              'ALTER TABLE sessions_v3 ADD COLUMN initiator_pending_at_ms INTEGER NOT NULL DEFAULT 0;',
        );
      }
      if (oldVersion < 58) {
        // TZ Epic B (2026-07-18): session epoch — creation wall-ms of the
        // session, carried in the wire header ('se') so a receiver still on an
        // older session classifies the failure as "rekey en route" instead of
        // a generic decrypt error. Preserved across ratchet upserts like
        // initiator_pending_at_ms.
        await _ensureColumnExists(
          db,
          table: 'sessions_v3',
          column: 'epoch',
          alterSql:
              'ALTER TABLE sessions_v3 ADD COLUMN epoch INTEGER NOT NULL DEFAULT 0;',
        );
      }
      if (oldVersion < 59) {
        // ROOM SENDER KEY (фаза 2): additive only — no existing table is
        // touched, so an upgrade cannot disturb a working install.
        await db.execute('''
CREATE TABLE IF NOT EXISTS room_send_keys (
  room_id TEXT PRIMARY KEY,
  epoch INTEGER NOT NULL,
  chain_key BLOB NOT NULL,
  counter INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  signing_seed BLOB
);
''');
        await db.execute('''
CREATE TABLE IF NOT EXISTS room_recv_keys (
  room_id TEXT NOT NULL,
  sender_device_id TEXT NOT NULL,
  epoch INTEGER NOT NULL,
  chain_key BLOB NOT NULL,
  counter INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  signing_pub BLOB,
  PRIMARY KEY(room_id, sender_device_id, epoch)
);
''');
        await db.execute('''
CREATE TABLE IF NOT EXISTS room_skipped_keys (
  room_id TEXT NOT NULL,
  sender_device_id TEXT NOT NULL,
  epoch INTEGER NOT NULL,
  counter INTEGER NOT NULL,
  message_key BLOB NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY(room_id, sender_device_id, epoch, counter)
);
''');
        await db.execute('''
CREATE TABLE IF NOT EXISTS room_key_delivery (
  room_id TEXT NOT NULL,
  peer_device_id TEXT NOT NULL,
  epoch INTEGER NOT NULL,
  delivered_at_ms INTEGER NOT NULL,
  confirmed_epoch INTEGER NOT NULL DEFAULT -1,
  confirmed_at_ms INTEGER NOT NULL DEFAULT 0,
  raw_epoch INTEGER NOT NULL DEFAULT -1,
  PRIMARY KEY(room_id, peer_device_id)
);
''');
        await db.execute('''
CREATE TABLE IF NOT EXISTS room_member_snapshot (
  room_id TEXT PRIMARY KEY,
  device_ids_csv TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS room_skipped_keys_room_idx ON room_skipped_keys(room_id, sender_device_id, epoch);',
        );
      }
      if (oldVersion < 50) {
        // Durable ACK queue.
        await db.execute('''
CREATE TABLE IF NOT EXISTS pending_acks (
  msg_id TEXT PRIMARY KEY,
  seq INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');
      }
      if (oldVersion < 60) {
        // F-ROOMSK-3/4: a key counted as delivered the moment it was ENQUEUED,
        // so the author began sealing messages a member might never have got.
        // These columns record the member's own `gkeyack`, which is both the
        // confirmation AND the only proof that their build can read the format.
        //
        // `-1` (not 0) is the "never confirmed" sentinel: epoch 0 is a REAL
        // generation, so a 0 default would silently mark every existing row as
        // confirmed for the first generation and reintroduce the very loss this
        // closes. Existing rows therefore start unconfirmed and the room falls
        // back to the pairwise path until each member acks — safe by default.
        await _ensureColumnExists(
          db,
          table: 'room_key_delivery',
          column: 'confirmed_epoch',
          alterSql:
              'ALTER TABLE room_key_delivery ADD COLUMN confirmed_epoch INTEGER NOT NULL DEFAULT -1;',
        );
        await _ensureColumnExists(
          db,
          table: 'room_key_delivery',
          column: 'confirmed_at_ms',
          alterSql:
              'ALTER TABLE room_key_delivery ADD COLUMN confirmed_at_ms INTEGER NOT NULL DEFAULT 0;',
        );
      }
      if (oldVersion < 61) {
        // Э-4 Ш-1 (редакция 2):
        // carry a handshake in every message until the peer confirms it, the
        // way Signal does, so a receiver that lost its session heals FROM the
        // message instead of needing a round trip.
        //
        // Additive and NULLable on purpose. Every existing row reads NULL,
        // which the receiver treats as "base key unknown" and handles exactly
        // as it does today — so this migration alone changes no behaviour at
        // all (Р-10), and a downgrade is safe because sqflite's null
        // onDowngrade does nothing and the old code never selects these.
        await _ensureColumnExists(
          db,
          table: 'sessions_v3',
          column: 'handshake_base_pub_b64',
          alterSql:
              'ALTER TABLE sessions_v3 ADD COLUMN handshake_base_pub_b64 TEXT;',
        );
        await _ensureColumnExists(
          db,
          table: 'sessions_v3',
          column: 'pending_prekey_header_json',
          alterSql:
              'ALTER TABLE sessions_v3 ADD COLUMN pending_prekey_header_json TEXT;',
        );
        // Р-4: the base key must survive INTO the archive, or a late repeat of
        // an older handshake would miss the live session, fall through to X3DH
        // and overwrite a NEWER one.
        await _ensureColumnExists(
          db,
          table: 'sessions_v3_archive',
          column: 'handshake_base_pub_b64',
          alterSql:
              'ALTER TABLE sessions_v3_archive ADD COLUMN handshake_base_pub_b64 TEXT;',
        );
      }
      if (oldVersion < 63) {
        // Надгробия удалений (07.08.2026, полевая жалоба «восстанавливаются
        // чаты, которые я давно удалил»).
        //
        // Удаление было ЖЁСТКИМ: строки стирались, и система нигде не помнила,
        // что это удаляли. Восстановление — ПОЛНАЯ замена. Значит копия,
        // снятая до удаления, возвращала всё обратно, и отличить «я это
        // удалил» от «этого никогда не было» было нечем.
        //
        // 🔴 Таблица НАМЕРЕННО вне снимка копии (`kSafeBackupSnapshotTables`).
        // Попади она туда — восстановление затёрло бы местные надгробия теми,
        // что лежат в копии, ровно в тот момент, когда они нужны. Надгробие
        // обязано ПЕРЕЖИТЬ восстановление, поэтому едет отдельным полем
        // payload и объединяется, а не заменяется.
        await db.execute('''
CREATE TABLE IF NOT EXISTS deletions (
  kind TEXT NOT NULL,
  target_id TEXT NOT NULL,
  deleted_at_ms INTEGER NOT NULL,
  PRIMARY KEY(kind, target_id)
);
''');
      }
      if (oldVersion < 62) {
        // Модель Signal для смены номера безопасности. Раньше проверка была
        // «всё или ничего»: настройка blockUnverified запирала отправку любому
        // неподтверждённому устройству, а любое новое устройство контакта
        // неподтверждено ПО ОПРЕДЕЛЕНИЮ. При включённой ротации личности (И-1)
        // это срабатывало постоянно и на пустом месте.
        //
        // Две новые записи разделяют «никогда не проверяли» и «проверяли, и
        // ключ сменился» — предупреждать надо только про второе.
        await db.execute('''
CREATE TABLE IF NOT EXISTS contact_verification (
  contact_profile_id TEXT PRIMARY KEY,
  verified_ever_at_ms INTEGER NOT NULL,
  account_identity_pub_b64 TEXT,
  account_identity_pinned_at_ms INTEGER
);
''');
        // 🔴 ОТДЕЛЬНОЙ таблицей, а не столбцом в contacts: contactUpsert пишет
        // contacts через ConflictAlgorithm.replace, перечисляя столбцы вручную.
        // Столбец, добавленный в contacts, стирался бы при каждой смене имени
        // контакта — то есть проверка слетала бы молча.
        //
        // 🔴 Наличие таблицы проверяется ЯВНО. `_ensureColumnExists` идемпотентен
        // для отсутствующего СТОЛБЦА, но не для отсутствующей ТАБЛИЦЫ: PRAGMA по
        // несуществующей таблице возвращает пусто, помощник выполняет ALTER и
        // падает с «no such table» — а падение внутри цепочки миграций означает
        // базу, которая не открывается, то есть потерю переписки. Так и поймано
        // тестом цепочки. Недостающую таблицу создаст `_ensureCriticalTables`
        // при этом же открытии — уже со столбцом.
        final hasContactDevices = (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='contact_devices';",
        )).isNotEmpty;
        if (hasContactDevices) {
          await _ensureColumnExists(
            db,
            table: 'contact_devices',
            column: 'approved_at_ms',
            alterSql:
                'ALTER TABLE contact_devices ADD COLUMN approved_at_ms INTEGER;',
          );
        }
      }

      if (oldVersion < 68) {
        // 🔴 ЧИСТКА ДУБЛЕЙ ОТ СИНХРОНИЗАЦИИ ИСТОРИИ (24.09.2026).
        //
        // Входящее личное сообщение лежит под `event_id = msgId` — id
        // КОНВЕРТА реле, а у каждого устройства свой конверт. Синхронизация
        // истории между своими устройствами сверяла только `event_id`, и копия
        // с телефона ложилась на ПК второй раз, рядом с уже принятой вживую.
        // Новые дубли остановлены в `_applyPeerHistoryChunk`; здесь убираются
        // налипшие.
        //
        // 🔴 Падение в цепочке миграций — это база, которая не открывается,
        // то есть потеря переписки. Чистка не обязательна, поэтому любая
        // ошибка здесь проглатывается: лучше оставить дубли, чем закрыть
        // человеку его историю.
        try {
          final hasEvents = (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='events';",
          )).isNotEmpty;
          if (hasEvents) {
            final cols = await db.rawQuery('PRAGMA table_info(events);');
            if (cols.any((c) => c['name'] == 'payload_event_id')) {
              debugLastPayloadDedupeRemoved = await dedupeEventsByPayload(db);
            }
          }
        } catch (_) {
          // См. выше: дубль лучше закрытой базы.
        }
      }

      if (oldVersion < 67) {
        // Очередь сигналов звонка через границу изолята.
        //
        // 🔴 ЗАЧЕМ (замер 14.08, звонок d41fdf11). Фоновый изолят расшифровал,
        // применил и подтвердил реле приглашение и предложение звонка — и тем
        // очистил ящик. Разложил он их в список в ОЗУ СВОЕГО изолята. Главный
        // изолят поднялся через три секунды на пустой ящик и о звонке не узнал
        // никогда: `phase=idle` до самого отбоя, экран пустой.
        //
        // Всё, что фон производит для главного изолята, обязано лежать в базе.
        // Буфер в памяти — не доставка.
        //
        // 🔴 Таблица создаётся ЧЕРЕЗ `IF NOT EXISTS` и продублирована в
        // `_createSchema` и `_ensureCriticalTables`: `_ensureColumnExists`
        // идемпотентен для отсутствующего СТОЛБЦА, но не для отсутствующей
        // ТАБЛИЦЫ, а падение в цепочке миграций — это база, которая не
        // открывается, то есть потеря переписки (шрам 02.08).
        await _createPendingCallSignalsTable(db);
      }

      if (oldVersion < 66) {
        // Кэш выгруженного блоба стикера (С-11 ТЗ по стикерам).
        //
        // 🔴 Наличие таблицы проверяется ЯВНО, как в v62, v64 и v65:
        // `_ensureColumnExists` идемпотентен для отсутствующего СТОЛБЦА, но не
        // для отсутствующей ТАБЛИЦЫ, а падение в цепочке миграций значит базу,
        // которая не открывается, то есть потерю переписки.
        final hasStickerRows = (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='sticker_pack_stickers';",
        )).isNotEmpty;
        if (hasStickerRows) {
          for (final column in const <String, String>{
            'blob_id': "ALTER TABLE sticker_pack_stickers ADD COLUMN blob_id TEXT NOT NULL DEFAULT '';",
            'blob_file_key_b64':
                "ALTER TABLE sticker_pack_stickers ADD COLUMN blob_file_key_b64 TEXT NOT NULL DEFAULT '';",
            'blob_access_token_b64':
                "ALTER TABLE sticker_pack_stickers ADD COLUMN blob_access_token_b64 TEXT NOT NULL DEFAULT '';",
            'blob_expires_at_ms':
                'ALTER TABLE sticker_pack_stickers ADD COLUMN blob_expires_at_ms INTEGER;',
          }.entries) {
            await _ensureColumnExists(
              db,
              table: 'sticker_pack_stickers',
              column: column.key,
              alterSql: column.value,
            );
          }
        }
      }

      if (oldVersion < 65) {
        // Ш-1 ТЗ по стикерам: режим доступа к своему набору.
        //
        // 🔴 Ничего не меняет в поведении — только даёт имя тому, что уже есть.
        // Значение по умолчанию `sent_only` совпадает с нынешним поведением
        // (свои наборы ездят зашифрованными блобами), поэтому обновление не
        // может переключить старый набор в другой режим молча.
        //
        // 🔴 Наличие таблицы проверяется ЯВНО, как в v62 и v64:
        // `_ensureColumnExists` идемпотентен для отсутствующего СТОЛБЦА, но не
        // для отсутствующей ТАБЛИЦЫ — PRAGMA вернёт пусто, помощник выполнит
        // ALTER и упадёт с «no such table», а падение в цепочке миграций значит
        // базу, которая не открывается.
        final hasStickerPacks = (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='sticker_packs';",
        )).isNotEmpty;
        if (hasStickerPacks) {
          await _ensureColumnExists(
            db,
            table: 'sticker_packs',
            column: 'share_mode',
            alterSql:
                "ALTER TABLE sticker_packs ADD COLUMN share_mode TEXT NOT NULL DEFAULT 'sent_only';",
          );
        }
      }

      if (oldVersion < 64) {
        // Слой 2 модели Signal: ключ личности АККАУНТА контакта, закреплённый
        // при первом знакомстве (TOFU).
        //
        // Слой 1 (v62) починил ПОСЛЕДСТВИЯ — блокировать только тех, кого
        // проверяли. Причина осталась: номер считается от identity-ключа
        // УСТРОЙСТВА, поэтому ротация И-1, которая по построению выглядит как
        // новое устройство, поднимает «номер изменился» на пустом месте.
        //
        // 🔴 Закрепление локальное И ОБЯЗАТЕЛЬНО (К-6): ключ аккаунта отдаёт
        // сервер, и доверять его слову нельзя — подменив ответ, он подменил бы
        // и номер. Поэтому первый увиденный ключ запоминается здесь, а
        // расхождение с сервером означает событие «номер изменился», а не тихое
        // обновление.
        //
        // 🔴 Наличие таблицы проверяется ЯВНО, по той же причине, что и в v62:
        // `_ensureColumnExists` идемпотентен для отсутствующего СТОЛБЦА, но не
        // для отсутствующей ТАБЛИЦЫ — PRAGMA вернёт пусто, помощник выполнит
        // ALTER и упадёт с «no such table», а падение в цепочке миграций значит
        // базу, которая не открывается, то есть потерю переписки. Недостающую
        // таблицу создаст `_ensureCriticalTables` при этом же открытии — уже со
        // столбцами.
        final hasContactVerification = (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='contact_verification';",
        )).isNotEmpty;
        if (hasContactVerification) {
          await _ensureColumnExists(
            db,
            table: 'contact_verification',
            column: 'account_identity_pub_b64',
            alterSql:
                'ALTER TABLE contact_verification ADD COLUMN account_identity_pub_b64 TEXT;',
          );
          await _ensureColumnExists(
            db,
            table: 'contact_verification',
            column: 'account_identity_pinned_at_ms',
            alterSql:
                'ALTER TABLE contact_verification ADD COLUMN account_identity_pinned_at_ms INTEGER;',
          );
        }
      }
    }

  /// The schema version the OPEN DATABASE actually carries.
  ///
  /// Not [_schemaVersion] — that is what the build expects. This is what the
  /// file on disk says after migrations ran, which is the only thing that
  /// answers "did the upgrade really happen on THIS device". The desktop TZ
  /// (DLV-1) asked for exactly that check and it could not be made: nothing
  /// reported the number, so a device silently stuck on an old schema looked
  /// identical to a healthy one.
  Future<int> schemaVersionOnDisk() async {
    try {
      return await _db.getVersion();
    } catch (_) {
      return -1;
    }
  }

  /// The schema version this BUILD expects. Compare against
  /// [schemaVersionOnDisk] to catch a device that never finished migrating.
  static int get expectedSchemaVersion => _schemaVersion;

  static Future<AppDb> open({required String passphrase}) async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'secretly.db');

    Future<void> baseConfigure(Database db) async {
      await db.execute('PRAGMA foreign_keys = ON;');
      await db.rawQuery('PRAGMA busy_timeout = 7000;');
      try {
        await db.rawQuery('PRAGMA journal_mode = WAL;');
      } catch (_) {
        // Best-effort: some SQLCipher builds may reject this pragma.
      }
    }

    Future<void> baseCreate(Database db, int version) async {
      await _createSchema(db);
    }

    Future<void> baseOpen(Database db) async {
      // Self-heal for partially-created DBs (e.g., if a previous create/upgrade crashed mid-way).
      // This is intentionally minimal and idempotent.
      await _ensureCriticalTables(db);
      // Self-heal profile_meta cosmetic columns. Some legacy migration paths
      // recreated profile_meta from a baseline schema that predates these
      // columns AT a version >= their per-version ALTER step, so the ALTER was
      // skipped and the column never got added. A missing column makes
      // profileMetaUpsert throw "no such column" and silently breaks ALL peer
      // profile sync (name/avatar/cover/frame/emoji/badge) — messaging still
      // works because it uses the relay + cached sessions, not Keys. Ensuring
      // the columns here (idempotent) repairs such installs on next launch.
      await _ensureProfileMetaColumns(db);
      // Self-heal premium ROOM cosmetic columns on group_settings (same
      // rationale as profile_meta above — a skipped ALTER would break room
      // snapshot sync via groupSettingsUpsert).
      await _ensureGroupSettingsCosmeticColumns(db);
      // Self-heal the quarantine NACK marker. Same rationale as the two above:
      // a versioned ALTER can be skipped by installs whose baseline was
      // recreated at a later version, and a missing column would throw inside
      // the decrypt-failure path — the one path that must never fail.
      await _ensureInboxQuarantineColumns(db);
      await _ensureRoomKeySigningColumns(db);
    }

    // The chain lives at class level so it can be tested — see
    // [runMigrationsForTest].
    Future<void> baseUpgrade(
      Database db,
      int oldVersion,
      int newVersion,
    ) => runMigrationsForTest(db, oldVersion, newVersion);

    final options = OpenDatabaseOptions(
      version: _schemaVersion,
      onConfigure: baseConfigure,
      onCreate: baseCreate,
      onUpgrade: baseUpgrade,
      onOpen: baseOpen,
    );

    final bool isMobile = Platform.isAndroid || Platform.isIOS;
    late Database db;
    if (isMobile) {
      // SQLCipher on mobile.
      try {
        db = await sqlcipher.openDatabase(
          dbPath,
          password: passphrase,
          version: options.version,
          onConfigure: options.onConfigure,
          onCreate: options.onCreate,
          onUpgrade: options.onUpgrade,
          onDowngrade: options.onDowngrade,
          onOpen: options.onOpen,
        );
      } catch (e) {
        final msg = e.toString().toLowerCase();
        // Dev migration: if an unencrypted DB exists, SQLCipher can't open it.
        if (msg.contains('file is not a database') ||
            msg.contains('sqlitenotadatabase') ||
            msg.contains('file is encrypted') ||
            msg.contains('wrong key') ||
            msg.contains('not a database')) {
          // DATA SAFETY (2026-07-19): this used to `deleteDatabase(dbPath)`,
          // which destroyed the user's entire history the moment the DB was
          // opened with a wrong/unavailable key. QUARANTINE instead — the file
          // is renamed aside, so a mis-keyed open is always recoverable.
          await quarantineDatabaseFilesAt(dbPath);
          _quarantinedExistingDbDuringOpen = true;
          db = await sqlcipher.openDatabase(
            dbPath,
            password: passphrase,
            version: options.version,
            onConfigure: options.onConfigure,
            onCreate: options.onCreate,
            onUpgrade: options.onUpgrade,
            onDowngrade: options.onDowngrade,
            onOpen: options.onOpen,
          );
        } else if (msg.contains('database_closed')) {
          // ZOMBIE DB (2026-07-27, tester on 1.7.4+407): the sqflite
          // singleInstance registry handed back a handle whose native connection
          // was closed out from under us (iOS backgrounding / a stale twin). The
          // in-app restart-retry cannot clear that PROCESS-GLOBAL cache, so all 5
          // retries kept getting the dead handle and the app showed the
          // "database_closed" screen until a manual kill-from-recents (a real
          // process kill flushes the cache). Re-open with a FRESH, NON-cached
          // connection so we stop returning the dead handle. DATA-SAFE: same file,
          // same passphrase, NO delete / re-key / quarantine — this branch cannot
          // lose data, and it only ever runs on the already-broken open.
          db = await sqlcipher.openDatabase(
            dbPath,
            password: passphrase,
            version: options.version,
            onConfigure: options.onConfigure,
            onCreate: options.onCreate,
            onUpgrade: options.onUpgrade,
            onDowngrade: options.onDowngrade,
            onOpen: options.onOpen,
            singleInstance: false,
          );
        } else {
          rethrow;
        }
      }
      // ZOMBIE-DB PROBE (2026-07-27, tester on 1.7.4+407): openDatabase with the
      // singleInstance registry can hand back a CACHED handle whose native
      // connection died in the background WITHOUT throwing at open (onOpen is not
      // re-run on a cache hit) — the death then surfaces on the first query in
      // controller.init and shows the "database_closed" screen until a manual
      // kill-from-recents (the only thing that flushes the process-global cache).
      // Probe the handle once here; if it is dead, re-open FRESH + non-cached so
      // we never keep returning the corpse. DATA-SAFE: SELECT 1 is read-only and
      // the re-open is the same file / same passphrase — no delete / re-key /
      // quarantine, so this can never lose data.
      try {
        await db.rawQuery('SELECT 1');
      } catch (e) {
        if (e.toString().toLowerCase().contains('database_closed')) {
          db = await sqlcipher.openDatabase(
            dbPath,
            password: passphrase,
            version: options.version,
            onConfigure: options.onConfigure,
            onCreate: options.onCreate,
            onUpgrade: options.onUpgrade,
            onDowngrade: options.onDowngrade,
            onOpen: options.onOpen,
            singleInstance: false,
          );
        } else {
          rethrow;
        }
      }
    } else {
      // Desktop (Windows/macOS/Linux): sqlite via FFI.
      // With sqlite3 hook `source: sqlite3mc`, encryption is available via `PRAGMA key`.
      ffi.sqfliteFfiInit();
      final factory = ffi.databaseFactoryFfi;

      final desktopOptions = OpenDatabaseOptions(
        version: options.version,
        onConfigure: (db) async {
          final escaped = _escapeSqlString(passphrase);
          await db.execute("PRAGMA key = '$escaped';");
          await baseConfigure(db);
        },
        onCreate: baseCreate,
        onUpgrade: baseUpgrade,
        onOpen: baseOpen,
      );

      try {
        db = await factory.openDatabase(dbPath, options: desktopOptions);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        // Migration: if an unencrypted DB exists, opening with a key will fail.
        if (msg.contains('file is not a database') ||
            msg.contains('sqlitenotadatabase') ||
            msg.contains('file is encrypted') ||
            msg.contains('wrong key') ||
            msg.contains('not a database')) {
          try {
            final f = File(dbPath);
            if (await f.exists()) {
              final ts = DateTime.now().millisecondsSinceEpoch;
              await f.rename('$dbPath.unencrypted_backup_$ts');
              _quarantinedExistingDbDuringOpen = true;
            }
          } catch (_) {
            // ignore backup failures
          }
          await factory.deleteDatabase(dbPath);
          db = await factory.openDatabase(dbPath, options: desktopOptions);
        } else {
          rethrow;
        }
      }
    }

    // PROVE THE KEY BEFORE HANDING THE HANDLE OUT (2026-07-21, tester
    // crash-on-launch).
    //
    // SQLCipher validates the passphrase only on the first REAL page read, and
    // opening plus the PRAGMAs above never touch one. So a mis-keyed open
    // "succeeds" and the failure lands much later, inside whatever query runs
    // first — on a tester's iPhone that was the sticker catalog load at
    // startup, which surfaced a raw
    //   DatabaseException(... Code=26 "file is not a database")
    //   SELECT * FROM sticker_pack_stickers
    // as a full-screen error on every launch until the app was force-killed.
    // Nothing was wrong with stickers; that query was merely the first read.
    //
    // Deliberately OUTSIDE the quarantine branch above: force-killing the app
    // cured it, which means the key was right and the failure was transient.
    // Quarantining a healthy database on a transient read would be the very
    // data-loss the 2026-07-19 rule forbids. So we only REPORT it, typed, and
    // let the caller retry with a freshly read passphrase.
    try {
      await db.rawQuery('SELECT count(*) FROM sqlite_master;');
    } catch (e) {
      try {
        await db.close();
      } catch (_) {}
      throw DbKeyUnverified(e);
    }

    return AppDb._(db);
  }

  // И-1 (TZ_I1_IDENTITY_2026-07-21): open() can quarantine an EXISTING
  // database internally (corrupt / wrong-key file) and hand back a fresh empty
  // one — the caller never sees an error, so it cannot tell a clean first
  // launch from a session-store loss. This marker is that signal. Read once
  // per launch by AppController.init(); consuming resets it so a later open
  // (e.g. a restore flow) cannot replay a stale detection.
  static bool _quarantinedExistingDbDuringOpen = false;

  static bool consumeQuarantinedExistingDbDuringOpen() {
    final v = _quarantinedExistingDbDuringOpen;
    _quarantinedExistingDbDuringOpen = false;
    return v;
  }

  /// И-2 (TZ_I2_ATOMICITY_2026-07-21): one inbound wire's ratchet advance,
  /// skipped-key mutations and journaled plaintext commit or roll back as a
  /// unit. Every db call inside [action] MUST go through the provided executor
  /// — a stray `_db` call on the same connection would deadlock behind the
  /// open transaction.
  Future<T> runInTransaction<T>(
    Future<T> Function(DatabaseExecutor txn) action,
  ) {
    return _db.transaction((t) => action(t));
  }

  /// Raw access, TESTS ONLY — used to assert that a schema migration actually
  /// created what it claims. A table added to one schema path but not the other
  /// is a classic way to break either fresh installs or upgrades, and that is
  /// only catchable by looking at the real database.
  @visibleForTesting
  Future<List<Map<String, Object?>>> rawQueryForTesting(
    String sql, [
    List<Object?>? args,
  ]) => _db.rawQuery(sql, args);

  @visibleForTesting
  Future<int> rawInsertForTesting(String sql, [List<Object?>? args]) =>
      _db.rawInsert(sql, args);

  static Future<AppDb> openForTesting({
    String path = inMemoryDatabasePath,
  }) async {
    ffi.sqfliteFfiInit();
    final factory = ffi.databaseFactoryFfi;
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
          await db.rawQuery('PRAGMA busy_timeout = 7000;');
        },
        onCreate: (db, version) => _createSchema(db),
        onOpen: _ensureCriticalTables,
        onUpgrade: (db, oldVersion, newVersion) async {
          await _createSchema(db);
          await _ensureCriticalTables(db);
        },
      ),
    );
    return AppDb._(db);
  }

  /// Path of the main encrypted database (mobile + desktop use the same name).
  static Future<String> localDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'secretly.db');
  }

  /// Whether an encrypted database already exists on disk.
  ///
  /// When it does, the stored passphrase is the ONLY key that can open it —
  /// callers must never mint a fresh one. See [SecureSecrets
  /// .requireExistingDbPassphrase].
  static Future<bool> localDatabaseExists() async {
    try {
      return await File(await localDatabasePath()).exists();
    } catch (_) {
      // If we cannot even stat the file, assume it exists: the safe answer is
      // the one that refuses to re-key.
      return true;
    }
  }

  /// The database and every file SQLite keeps beside it. WAL mode means the
  /// newest commits can live in `-wal`, so these always travel together.
  static const List<String> _dbSidecarSuffixes = <String>[
    '',
    '-wal',
    '-shm',
    '-journal',
  ];

  /// Renames a database and its sidecars aside instead of deleting them.
  ///
  /// DATA SAFETY (2026-07-19): every "the key does not open this file" path
  /// funnels here. A wrong or temporarily-unreadable key must never cost the
  /// user their history — the bytes are kept under
  /// `secretly.db.corrupt_backup_<ts>` so they can be recovered once the real
  /// key is available again.
  static Future<void> quarantineDatabaseFilesAt(String dbPath) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    for (final suffix in _dbSidecarSuffixes) {
      final path = '$dbPath$suffix';
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.rename('$dbPath.corrupt_backup_$ts$suffix');
        }
      } catch (_) {
        // Best-effort: a sidecar we cannot move must not block recovery.
      }
    }
  }

  /// Quarantine variant of [deleteLocalDatabaseFiles] for the startup recovery
  /// path — preserves the old database instead of destroying it.
  static Future<void> quarantineLocalDatabaseFiles() async {
    await quarantineDatabaseFilesAt(await localDatabasePath());
  }

  /// Number of stored events. Used as the "how much history do I hold" figure
  /// that guards a backup from overwriting a larger one (see
  /// [SafeBackupRegressionGuard]). Returns 0 if it cannot be determined, which
  /// the guard treats as "nothing to protect".
  Future<int> countEvents() async {
    try {
      final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM events;');
      return (rows.first['n'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// [countEvents], but null when the count could not be established.
  ///
  /// The distinction matters wherever the number is STORED rather than merely
  /// read: `countEvents` answers 0 on a query failure, which is
  /// indistinguishable from a genuinely empty database. Writing that 0 into a
  /// threshold silently lowers the threshold to "anything goes".
  Future<int?> countEventsOrNull() async {
    try {
      final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM events;');
      return (rows.first['n'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// True when this install holds ANY locally stored event.
  ///
  /// F-CONTENTKEY-1 (2026-07-31): the ONLY question the content key needs
  /// answered before it may be minted — one stored event proves a content key
  /// existed, and minting a new one makes that event permanently unreadable.
  ///
  /// Deliberately NOT [countEvents], whose catch returns 0. Answering "no
  /// content" on a query failure is the direction that destroys data, so this
  /// answers TRUE on any error — the safe answer is the one that refuses to
  /// mint. Same philosophy as [localDatabaseExists].
  Future<bool> hasStoredContent() async {
    try {
      final rows = await _db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM events LIMIT 1) AS has_rows;',
      );
      final v = rows.first['has_rows'];
      if (v == null) return true;
      return ((v as num?)?.toInt() ?? 1) != 0;
    } catch (_) {
      return true;
    }
  }

  // ── И-1 (TZ_I1_IDENTITY_2026-07-21): device-identity stamp ────────────────
  // A tiny key/value side-table created LAZILY on first use. Deliberately not
  // part of the versioned migration chain: the stamp must also be writable
  // into a RESTORED quarantined database from an older schema, and a lazy
  // `CREATE TABLE IF NOT EXISTS` in one place is the whole story (the wave-2
  // lesson: never the same CREATE in three migration paths).
  Future<void> _ensureLocalKvTable() async {
    await _db.execute('''
CREATE TABLE IF NOT EXISTS local_kv (
  k TEXT PRIMARY KEY,
  v TEXT NOT NULL
);
''');
  }

  Future<String?> localKvGet(String key) async {
    await _ensureLocalKvTable();
    final rows = await _db.query(
      'local_kv',
      columns: const ['v'],
      where: 'k = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['v'] as String?;
  }

  Future<void> localKvSet(String key, String value) async {
    await _ensureLocalKvTable();
    await _db.insert('local_kv', <String, Object?>{
      'k': key,
      'v': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> localKvDelete(String key) async {
    await _ensureLocalKvTable();
    await _db.delete('local_kv', where: 'k = ?', whereArgs: [key]);
  }

  /// Monotonic lifetime counter in [local_kv] (И-2c: countable field metrics
  /// without a per-event table). Best-effort — a diagnostics counter must
  /// never throw into a delivery path.
  Future<void> localKvCounterInc(String key) async {
    try {
      await _ensureLocalKvTable();
      await _db.rawInsert(
        'INSERT INTO local_kv(k, v) VALUES(?, 1) '
        'ON CONFLICT(k) DO UPDATE SET v = CAST(v AS INTEGER) + 1',
        [key],
      );
    } catch (_) {
      // ignore — never break delivery for a metric
    }
  }

  Future<int> localKvCounterGet(String key) async {
    final v = await localKvGet(key);
    return int.tryParse(v ?? '') ?? 0;
  }

  /// Per-message inbound decrypt-failure budget, kept on disk.
  ///
  /// The in-memory counter this replaces could never reach its threshold on
  /// iOS: the OS kills the app seconds after a background wake, so every push
  /// restarted the count at zero. A wire that failed to decrypt was therefore
  /// never parked — and, worse, never NACKed, because the signal that asks the
  /// sender to rekey lives inside the quarantine branch. The message sat in the
  /// relay mailbox being re-offered forever, invisible to its recipient, while
  /// the recovery machinery waited behind a gate that could not open.
  ///
  /// Value format is `attempts|firstFailedAtMs` so [inboundDecryptFailurePrune]
  /// can age rows out in SQL without reading them.
  Future<({int attempts, int firstFailedAtMs})> inboundDecryptFailureBump(
    String msgId,
    int nowMs,
  ) async {
    final key = 'idf:$msgId';
    try {
      final prev = await localKvGet(key);
      final parts = (prev ?? '').split('|');
      final prevAttempts = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
      final firstMs =
          int.tryParse(parts.length > 1 ? parts[1] : '') ?? nowMs;
      final attempts = prevAttempts + 1;
      await localKvSet(key, '$attempts|$firstMs');
      return (attempts: attempts, firstFailedAtMs: firstMs);
    } catch (_) {
      // Storage trouble must not turn into a stuck mailbox: report this as the
      // first failure so the caller keeps the in-session behaviour.
      return (attempts: 1, firstFailedAtMs: nowMs);
    }
  }

  Future<void> inboundDecryptFailureClear(String msgId) async {
    try {
      await _ensureLocalKvTable();
      await _db.delete('local_kv', where: 'k = ?', whereArgs: ['idf:$msgId']);
    } catch (_) {
      // best-effort: a stale budget row only costs a parked retry
    }
  }

  /// Drops budget rows whose first failure is older than [cutoffMs].
  Future<void> inboundDecryptFailurePrune(int cutoffMs) async {
    try {
      await _ensureLocalKvTable();
      await _db.rawDelete(
        "DELETE FROM local_kv WHERE k LIKE 'idf:%' "
        "AND CAST(substr(v, instr(v, '|') + 1) AS INTEGER) < ?",
        [cutoffMs],
      );
    } catch (_) {
      // best-effort housekeeping
    }
  }

  // ── Resend budget (Э-0) ─────
  //
  // 🔴 WHY (proven on prod, 2026-08-01): re-sending an undelivered message had
  // a 90-second debounce and NO lifetime cap, with the debounce map held in
  // MEMORY — so an app restart reopened the floodgate immediately. A message
  // the recipient cannot apply is therefore re-sent for its whole 7-day TTL.
  // Measured: 13 real messages became 504 mailbox rows; one message was sent
  // 94 times; 298 copies went to a device the relay had evicted days earlier.
  // Every re-send is a NEW relay message, so it is also a NEW push and a NEW
  // banner — the "notifications for messages I already read" report.
  //
  // The budget is per (event × device) because that is the unit that can fail:
  // the same message may be fine for one of a peer's devices and dead for
  // another, and a device that rotates deserves a fresh start (its human never
  // saw the message at all).
  //
  // Stored in `local_kv` rather than a new table on purpose — the decrypt
  // budget above set that precedent, and it avoids a schema migration in the
  // two separate CREATE paths this database has (the Wave-2 lesson).
  //
  // Value format is `used|firstAtMs|bonus`, laid out so [resendBudgetPrune]
  // can age rows out in SQL without parsing them.

  /// 🔴 ЭПОХА СЕССИИ — ЧАСТЬ КЛЮЧА (ТЗ 16.08, Л-1).
  ///
  /// Инцидент 15–16.08: пять копий, принятых реле ПОД МЁРТВОЙ сессией, сожгли
  /// потолок, и после починки сессии переотправка была запрещена навсегда —
  /// спасла только одноразовая амнистия. Копии под мёртвой сессией доказывают
  /// недоставляемость СЕССИИ, а не сообщения; смена эпохи (сброс + новое
  /// рукопожатие) начинает счёт заново.
  ///
  /// Потолок 5 НА ЭПОХУ сохранён полностью: шторм «одно смс 94 раза» (прод,
  /// 01.08) жил ВНУТРИ одной эпохи и этим ключом не разблокируется. Смена
  /// эпохи задушена собственными пределами сброса (дебаунс, эскалатор).
  ///
  /// Старые ключи без эпохи перестают читаться — это разовая неявная амнистия
  /// при обновлении, ровно то, что амнистия 15.08 делала руками.
  static String _resendBudgetKey(String deviceId, String eventId, int epoch) =>
      'rsb:$deviceId:$eventId:e$epoch';

  /// 🔴 АБСОЛЮТНЫЙ ПОТОЛОК, КОТОРЫЙ НЕ СБРАСЫВАЕТ НИЧТО (20.08.2026).
  ///
  /// Эпоха в ключе выше чинила настоящий капкан (копии под мёртвой сессией
  /// запирали сообщение навсегда), но открыла худшее: КАЖДЫЙ входящий NACK
  /// делает `_forceSessionResetPing`, дебаунс которого 30 секунд, — значит
  /// эпоха менялась при каждом NACK, и счёт начинался заново. Полевой замер
  /// 17–18.08: копии одного сообщения создавались РОВНО РАЗ В ЧАС по 7 штук,
  /// **70 копий** одного письма в ящике. Потолок «5 + бонус 3» превратился из
  /// «восемь навсегда» в «восемь в час».
  ///
  /// Поэтому счётчиков ДВА: посуточный по эпохе (даёт второй шанс после
  /// настоящего лечения) и этот — сквозной, не сбрасываемый ничем. Он и есть
  /// защита от шторма 01.08 («одно смс 94 раза»), которую я по неосторожности
  /// снял.
  static String _resendBudgetTotalKey(String deviceId, String eventId) =>
      'rsbT:$deviceId:$eventId';

  /// Сквозной предел копий одного события для одного устройства.
  ///
  /// Выше, чем потолок эпохи (5+3): настоящее лечение имеет право дать ещё
  /// попытки. Но конечен — сколько бы раз ни пересобиралась сессия.
  static const int kResendBudgetAbsoluteMax = 12;

  /// Is there any re-send budget left for ([eventId] × [deviceId] × epoch)?
  ///
  /// Read-only. Pair it with [resendBudgetConsume], which is called only once a
  /// wire has actually been enqueued.
  ///
  /// 🔴 SPLIT FROM THE CONSUME DELIBERATELY. The first version of this consumed
  /// the attempt up-front, before the local copy was decrypted and re-encrypted
  /// — and several `continue`s sit between those two points (an unreadable
  /// local payload, the dead-blob gate, an encryption failure). A message whose
  /// LOCAL copy was temporarily unreadable — a content-key hiccup, which is a
  /// failure mode this app has actually had — would therefore burn its whole
  /// budget across a few sweeps without a single wire ever leaving the device,
  /// and could never be re-sent again once the local problem cleared. Budget is
  /// for wires that were SENT, never for attempts that died at home.
  ///
  /// 🔴 FAILURE DIRECTION: a storage error returns FALSE (do not send). A
  /// re-send is an optimisation; an unbounded re-send is measured harm, so the
  /// safe answer when we cannot count is "stop". This is the opposite of the
  /// decrypt budget above, where being unable to count must not park a wire —
  /// there the risk is losing a message, here it is drowning one.
  Future<bool> resendBudgetHasRoom({
    required String eventId,
    required String deviceId,
    required int epoch,
    required int maxAttempts,
  }) async {
    final id = eventId.trim();
    final dev = deviceId.trim();
    if (id.isEmpty || dev.isEmpty || maxAttempts <= 0) return false;
    try {
      final parts = (await localKvGet(_resendBudgetKey(dev, id, epoch)) ?? '')
          .split(
        '|',
      );
      final used = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
      final bonus = int.tryParse(parts.length > 2 ? parts[2] : '') ?? 0;
      if (used >= maxAttempts + bonus) return false;
      // 🔴 И сквозной предел — его не сбрасывает ни смена эпохи, ни бонус.
      final totalParts =
          (await localKvGet(_resendBudgetTotalKey(dev, id)) ?? '').split('|');
      final total = int.tryParse(totalParts.isNotEmpty ? totalParts[0] : '') ?? 0;
      return total < kResendBudgetAbsoluteMax;
    } catch (_) {
      return false;
    }
  }

  /// Сколько копий события ушло этому устройству за всё время (все эпохи).
  Future<int> resendBudgetTotalUsed({
    required String eventId,
    required String deviceId,
  }) async {
    try {
      final parts = (await localKvGet(
                _resendBudgetTotalKey(deviceId.trim(), eventId.trim()),
              ) ??
              '')
          .split('|');
      return int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// РАЗОВАЯ АМНИСТИЯ исчерпанным бюджетам переотправки.
  ///
  /// 🔴 ЗАЧЕМ (15.08.2026). Сообщения, чьи попытки сгорели в яме `429`, не
  /// уйдут никогда: бюджет исчерпан, а списан он был за кадры, которых реле не
  /// видело. У владельца так застряли пять сообщений — они лежат на устройстве
  /// целыми и не отправляются.
  ///
  /// Возвращает полный бюджет тем ключам, что были заведены за последние 7
  /// дней. Старые не трогаем: их получатели давно ушли, а разбудить неделю
  /// молчания разом — это шторм, ровно тот, от которого потолок и стоит.
  ///
  /// Выполняется ОДИН раз: отметка о выполнении лежит рядом, в том же
  /// хранилище.
  Future<int> resendBudgetAmnestyOnce({required int nowMs}) async {
    const doneKey = 'rsb_amnesty_2026_08_15';
    try {
      if ((await localKvGet(doneKey) ?? '').isNotEmpty) return 0;
      await _ensureLocalKvTable();
      final rows = await _db.query(
        'local_kv',
        columns: const ['k', 'v'],
        where: "k LIKE 'rsb:%'",
      );
      final cutoff = nowMs - const Duration(days: 7).inMilliseconds;
      var healed = 0;
      for (final row in rows) {
        final k = (row['k'] as String?) ?? '';
        final parts = ((row['v'] as String?) ?? '').split('|');
        final used = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
        final firstMs = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
        if (used <= 0 || firstMs < cutoff) continue;
        final bonus = parts.length > 2 ? parts[2] : '0';
        await localKvSet(k, '0|$firstMs|$bonus');
        healed += 1;
      }
      await localKvSet(doneKey, nowMs.toString());
      return healed;
    } catch (_) {
      // Амнистия — разовая любезность, а не путь доставки: её отказ не имеет
      // права помешать запуску.
      return 0;
    }
  }

  /// Ключ отметки «этот кадр в очереди — ПЕРЕОТПРАВКА».
  ///
  /// Хранит `deviceId|eventId`, чтобы по идентификатору кадра можно было найти,
  /// чей бюджет списывать, когда реле подтвердит приём.
  static String _resendPendingKey(String msgId) => 'rsp:$msgId';

  /// Помечает кадр как переотправку, чей бюджет ещё НЕ списан.
  ///
  /// 🔴 ЗАЧЕМ ОТМЕТКА, А НЕ СПИСАНИЕ НА МЕСТЕ (15.08.2026, замер прода).
  ///
  /// Бюджет списывался в момент постановки кадра в очередь. Между очередью и
  /// реле лежит СЕТЬ, и всё, что там ломается, съедало попытки: лимит `429`,
  /// полуоткрытый вебсокет, отсутствие связи. У владельца пять попыток сгорели
  /// в яме 429, не отправив НИ ОДНОГО кадра, — и сообщения застряли на телефоне
  /// навсегда: `resend_budget_spent` при каждом последующем проходе.
  ///
  /// Замысел автора был верен и записан прямо здесь: «Budget is for wires that
  /// were SENT, never for attempts that died at home». Граница «отправлено»
  /// просто проведена не там: очередь — это ещё дом.
  Future<void> resendPendingMark({
    required String msgId,
    required String eventId,
    required String deviceId,
    required int epoch,
  }) async {
    final m = msgId.trim();
    if (m.isEmpty || eventId.trim().isEmpty || deviceId.trim().isEmpty) return;
    try {
      // Эпоха запоминается В МОМЕНТ постановки: списывать по приёму реле надо
      // с того счёта, под которым кадр реально шифровался, — к моменту
      // подтверждения сессия могла смениться.
      await localKvSet(
        _resendPendingKey(m),
        '${deviceId.trim()}|${eventId.trim()}|$epoch',
      );
    } catch (_) {
      // Не смогли пометить — бюджет просто не спишется. Недосчитать безопаснее,
      // чем списать за кадр, которого никто не принимал.
    }
  }

  /// Списывает бюджет за кадр, ПРИНЯТЫЙ реле, и снимает отметку.
  ///
  /// Возвращает `true`, если кадр был переотправкой и бюджет списан. Для
  /// первичных отправок отметки нет — они бюджета не стоят, как и раньше.
  Future<bool> resendBudgetConsumeForAcceptedMsg({
    required String msgId,
    required int nowMs,
  }) async {
    final m = msgId.trim();
    if (m.isEmpty) return false;
    try {
      final raw = (await localKvGet(_resendPendingKey(m)) ?? '').trim();
      if (raw.isEmpty) return false;
      final parts = raw.split('|');
      if (parts.length < 2) return false;
      final markedEpoch =
          parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
      await resendBudgetConsume(
        eventId: parts[1],
        deviceId: parts[0],
        epoch: markedEpoch,
        nowMs: nowMs,
      );
      await localKvDelete(_resendPendingKey(m));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Разовое (на эпоху) разрешение пере-шифровать событие, когда реле пусто.
  ///
  /// ТЗ 16.08, Л-3: «реле пусто» перестаёт быть глухим отказом, но и не
  /// открывает кран — одна пере-шифровка за эпоху на событие. Возвращает true
  /// ровно один раз для данной тройки; смена эпохи выдаёт новое разрешение.
  Future<bool> resendHeldZeroClaimOnce({
    required String eventId,
    required String deviceId,
    required int epoch,
  }) async {
    final id = eventId.trim();
    final dev = deviceId.trim();
    if (id.isEmpty || dev.isEmpty) return false;
    final key = 'rsbh0:$dev:$id:e$epoch';
    try {
      if (((await localKvGet(key)) ?? '').isNotEmpty) return false;
      await localKvSet(key, '1');
      return true;
    } catch (_) {
      // Сомнение — НЕ слать: направление отказа прежнее.
      return false;
    }
  }

  /// И-Д (ТЗ 16.08, Л-4): вечная одна галочка запрещена быть невидимой.
  /// Переводит событие в `failed`, только если оно всё ещё висит в `sent`.
  Future<bool> eventMarkFailedIfStillSent(String eventId) async {
    final id = eventId.trim();
    if (id.isEmpty) return false;
    try {
      final n = await _db.update(
        'events',
        {'local_state': 'failed'},
        where: "event_id = ? AND local_state = 'sent'",
        whereArgs: [id],
      );
      return n > 0;
    } catch (_) {
      return false;
    }
  }

  /// Убирает отметку, не списывая бюджет: кадр умер, не дойдя до реле.
  Future<void> resendPendingDrop(String msgId) async {
    final m = msgId.trim();
    if (m.isEmpty) return;
    try {
      await localKvDelete(_resendPendingKey(m));
    } catch (_) {}
  }

  /// Record that one re-send attempt was actually SPENT — i.e. a wire is now in
  /// the outbox. See [resendBudgetHasRoom] for why the check is separate.
  Future<void> resendBudgetConsume({
    required String eventId,
    required String deviceId,
    required int epoch,
    required int nowMs,
  }) async {
    final id = eventId.trim();
    final dev = deviceId.trim();
    if (id.isEmpty || dev.isEmpty) return;
    try {
      final parts = (await localKvGet(_resendBudgetKey(dev, id, epoch)) ?? '')
          .split('|');
      final used = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
      final firstMs = int.tryParse(parts.length > 1 ? parts[1] : '') ?? nowMs;
      final bonus = int.tryParse(parts.length > 2 ? parts[2] : '') ?? 0;
      await localKvSet(
        _resendBudgetKey(dev, id, epoch),
        '${used + 1}|$firstMs|$bonus',
      );
      // Сквозной счётчик растёт вместе с посуточным и НИКОГДА не обнуляется.
      final totalParts =
          (await localKvGet(_resendBudgetTotalKey(dev, id)) ?? '').split('|');
      final total = int.tryParse(totalParts.isNotEmpty ? totalParts[0] : '') ?? 0;
      final totalFirstMs =
          int.tryParse(totalParts.length > 1 ? totalParts[1] : '') ?? nowMs;
      // Формат `count|firstMs` — тот же, что у посуточного ключа, чтобы
      // [resendBudgetPrune] умела состарить и эти строки.
      await localKvSet(
        _resendBudgetTotalKey(dev, id),
        '${total + 1}|$totalFirstMs',
      );
    } catch (_) {
      // Storage trouble here can only UNDER-count, which the next sweep's
      // check re-bounds. Failing the send because bookkeeping failed would be
      // the worse trade — the wire is already on its way.
    }
  }

  /// Grant one extra attempt because the RECIPIENT asked for it (a NACK).
  ///
  /// A statement from the far side outranks our own guessing, so it earns more
  /// budget — but only up to [maxBonus], or a peer stuck in a bad loop could
  /// farm unlimited re-sends out of us by NACKing forever.
  Future<void> resendBudgetGrantBonus({
    required String eventId,
    required String deviceId,
    required int epoch,
    required int maxBonus,
    required int nowMs,
  }) async {
    final id = eventId.trim();
    final dev = deviceId.trim();
    if (id.isEmpty || dev.isEmpty || maxBonus <= 0) return;
    try {
      final parts = (await localKvGet(_resendBudgetKey(dev, id, epoch)) ?? '')
          .split('|');
      final used = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
      final firstMs = int.tryParse(parts.length > 1 ? parts[1] : '') ?? nowMs;
      final bonus = int.tryParse(parts.length > 2 ? parts[2] : '') ?? 0;
      if (bonus >= maxBonus) return;
      await localKvSet(
          _resendBudgetKey(dev, id, epoch), '$used|$firstMs|${bonus + 1}');
    } catch (_) {
      // best-effort: without the bonus the ordinary cap still applies
    }
  }

  /// Attempts already spent for ([eventId] × [deviceId] × epoch) — diagnostics.
  Future<int> resendBudgetUsed({
    required String eventId,
    required String deviceId,
    int epoch = 0,
  }) async {
    try {
      final parts = (await localKvGet(
                _resendBudgetKey(deviceId.trim(), eventId.trim(), epoch),
              ) ??
              '')
          .split('|');
      return int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Drops budget rows first used before [cutoffMs]. A message older than the
  /// relay's own 7-day mailbox TTL can no longer be re-sent usefully.
  Future<void> resendBudgetPrune(int cutoffMs) async {
    try {
      await _ensureLocalKvTable();
      await _db.rawDelete(
        "DELETE FROM local_kv WHERE k LIKE 'rsb:%' "
        "AND CAST(substr(v, instr(v, '|') + 1) AS INTEGER) < ?",
        [cutoffMs],
      );
      // 🔴 Сквозные счётчики чистятся ОТДЕЛЬНЫМ запросом с точным префиксом:
      // `LIKE 'rsb%'` задело бы метку разовой амнистии (`rsb_amnesty_…`), у
      // которой нет разделителя `|`, — она бы удалилась и амнистия пошла бы по
      // второму кругу.
      await _db.rawDelete(
        "DELETE FROM local_kv WHERE k LIKE 'rsbT:%' "
        "AND CAST(substr(v, instr(v, '|') + 1) AS INTEGER) < ?",
        [cutoffMs],
      );
    } catch (_) {
      // best-effort housekeeping
    }
  }

  // ── Cross-isolate decrypt barrier (TZ_BG_DECRYPT_2026-07-23, Б-1) ─────────
  //
  // Exactly one isolate may write into the ratchet at a time. The foreground
  // app and the background fetcher are SEPARATE isolates, so an in-memory mutex
  // cannot serialize them — a Dart lock does not cross the isolate boundary.
  // This lease does, because it lives in the database FILE and SQLite serializes
  // writers to that file across every connection: the conditional upsert below
  // either finds the lease free/expired/its own and takes it, or leaves a fresh
  // foreign lease untouched and reports failure.
  //
  // The value is `holder|expiresAtMs` so the SQL can compare expiry and holder
  // without a second round trip. Nothing is wired to call this yet; it is the
  // primitive the background decrypt path will stand on, added and tested in
  // isolation first so the sensitive change lands on a proven foundation.
  static const _decryptLeaseKey = 'decrypt_lease_v1';

  /// Take (or renew) the single decrypt lease for [holder]. Returns true iff
  /// [holder] holds it afterwards. Succeeds when the lease is free, expired, or
  /// already ours; fails when a different holder's lease is still fresh.
  Future<bool> acquireDecryptLease({
    required String holder,
    required int nowMs,
    required int ttlMs,
  }) async {
    if (holder.isEmpty || holder.contains('|')) return false;
    await _ensureLocalKvTable();
    final newVal = '$holder|${nowMs + ttlMs}';
    return _db.transaction((txn) async {
      await txn.rawInsert(
        "INSERT INTO local_kv(k, v) VALUES(?, ?) "
        "ON CONFLICT(k) DO UPDATE SET v = excluded.v "
        // take it only if the current lease has expired or is already ours
        "WHERE CAST(substr(local_kv.v, instr(local_kv.v, '|') + 1) AS INTEGER) < ? "
        "OR substr(local_kv.v, 1, instr(local_kv.v, '|') - 1) = ?",
        [_decryptLeaseKey, newVal, nowMs, holder],
      );
      final rows = await txn.query(
        'local_kv',
        columns: const ['v'],
        where: 'k = ?',
        whereArgs: [_decryptLeaseKey],
        limit: 1,
      );
      final v = rows.isEmpty ? '' : (rows.first['v'] as String? ?? '');
      return v.startsWith('$holder|');
    });
  }

  /// Release the lease, but only if [holder] still owns it — a stale releaser
  /// (its lease already expired and re-taken by someone else) must not free the
  /// new owner's lease.
  Future<void> releaseDecryptLease(String holder) async {
    try {
      await _ensureLocalKvTable();
      await _db.rawDelete(
        "DELETE FROM local_kv WHERE k = ? "
        "AND substr(v, 1, instr(v, '|') - 1) = ?",
        [_decryptLeaseKey, holder],
      );
    } catch (_) {
      // best-effort: a stale lease only costs one TTL of waiting
    }
  }

  /// The current lease holder, or null if free/expired. Read-only.
  Future<String?> decryptLeaseHolder(int nowMs) async {
    final v = await localKvGet(_decryptLeaseKey);
    if (v == null || v.isEmpty) return null;
    final sep = v.indexOf('|');
    if (sep <= 0) return null;
    final expiresAt = int.tryParse(v.substring(sep + 1)) ?? 0;
    if (expiresAt < nowMs) return null;
    return v.substring(0, sep);
  }

  /// И-1: drops every ratchet/session row while keeping history intact.
  ///
  /// Used when a quarantined database is resurrected AFTER the device already
  /// rotated its identity: the events belong to the user, but the sessions
  /// inside were agreed under the ABANDONED device_id/identity — using them
  /// under the new identity would send garbage and mis-decrypt. The quarantined
  /// inbound wires are ciphertext for the dead identity and can never be
  /// applied either.
  Future<void> purgeRatchetStateForForeignIdentity() async {
    for (final table in const <String>[
      'sessions_v3',
      'sessions_v3_archive',
      'skipped_message_keys',
      'sessions',
      'inbox_quarantine',
    ]) {
      try {
        await _db.delete(table);
      } catch (_) {
        // A restored pre-migration copy may lack a table — that is fine, the
        // point is that no foreign ratchet row survives.
      }
    }
  }

  /// True when this database holds no user content at all — the signature of a
  /// database that was just created from scratch.
  ///
  /// Used to decide whether a quarantined copy may be restored over it. Never
  /// restore over a database that already has content: re-syncing peers can add
  /// rows within seconds of a fresh start, and clobbering those would trade one
  /// data-loss bug for another.
  Future<bool> looksEmpty() async {
    try {
      // Contacts and sessions count as content too. Checking only messages
      // would call a database "empty" after the user had already re-added a
      // contact and published fresh prekeys, and restoring a stale copy over
      // that loses the contact AND desyncs the session against the server.
      for (final table in const <String>[
        'events',
        'conversations',
        'contacts',
        'sessions_v3',
      ]) {
        final rows = await _db.rawQuery(
          'SELECT EXISTS(SELECT 1 FROM $table LIMIT 1) AS has_rows;',
        );
        final hasRows = ((rows.first['has_rows'] as num?)?.toInt() ?? 0) > 0;
        if (hasRows) return false;
      }
      return true;
    } catch (_) {
      // If we cannot tell, assume it is NOT empty — the safe answer is the one
      // that refuses to overwrite.
      return false;
    }
  }

  /// Whether any quarantined copy is sitting next to the live database.
  static Future<bool> hasQuarantinedBackups() async =>
      (await _quarantinedBackups()).isNotEmpty;

  /// Quarantined databases, newest first.
  static Future<List<File>> _quarantinedBackups() async {
    final dir = await getApplicationDocumentsDirectory();
    final found = <File>[];
    try {
      await for (final entity in Directory(dir.path).list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        // Only the database itself — never its -wal/-shm/-journal sidecars.
        if (!name.startsWith('secretly.db.corrupt_backup_')) continue;
        if (name.endsWith('-wal') ||
            name.endsWith('-shm') ||
            name.endsWith('-journal')) {
          continue;
        }
        found.add(entity);
      }
    } catch (_) {
      return const <File>[];
    }
    found.sort((a, b) => b.path.compareTo(a.path)); // timestamped → newest first
    return found;
  }

  /// Last-chance rescue before we give up on a database that will not open.
  ///
  /// DATA LOSS (2026-07-20): a device whose keychain was unreadable at launch
  /// got its live database quarantined and re-keyed, so the user opened the app
  /// to an empty account. When the ORIGINAL key later becomes readable again,
  /// the *current* database (written with the throwaway key) is the one that
  /// refuses to open — while a quarantined backup opens perfectly. That is the
  /// signal this looks for: if [passphrase] opens a quarantined file, it IS the
  /// real database and gets put back.
  ///
  /// Only ever runs after the main database has already failed to open, moves
  /// the current file aside rather than deleting it, and returns false if
  /// nothing matched — so it can never make things worse.
  static Future<bool> tryRestoreQuarantinedDatabase({
    required String passphrase,
  }) async {
    if (!(Platform.isAndroid || Platform.isIOS)) return false;
    final backups = await _quarantinedBackups();
    if (backups.isEmpty) return false;

    final dbPath = await localDatabasePath();
    for (final backup in backups) {
      // Probe: can this passphrase actually open the backup?
      Database? probe;
      try {
        probe = await sqlcipher.openDatabase(
          backup.path,
          password: passphrase,
          readOnly: true,
          // NEVER join the singleInstance registry: a cached handle keyed by
          // path is exactly what produced the "error_database_closed forever"
          // zombie (2026-07-18). This probe is throwaway.
          singleInstance: false,
        );
        // Force a real read — SQLCipher only rejects a wrong key on first use.
        // Must be our schema AND actually hold something: an empty copy is
        // not worth restoring over the live database, and reporting success
        // for it would be a lie.
        final rows = await probe.rawQuery(
          "SELECT EXISTS(SELECT 1 FROM events LIMIT 1) AS has_rows;",
        );
        final looksLikeOurs =
            ((rows.first['has_rows'] as num?)?.toInt() ?? 0) > 0;
        await probe.close();
        probe = null;
        if (!looksLikeOurs) continue;
      } catch (_) {
        try {
          await probe?.close();
        } catch (_) {}
        continue; // wrong key (or not our schema) — leave it untouched
      }

      // The backup is ours and opens. Put the current file aside (never
      // delete), then move the backup — AND ITS SIDECARS — back into place.
      try {
        final ts = DateTime.now().millisecondsSinceEpoch;
        for (final suffix in _dbSidecarSuffixes) {
          final f = File('$dbPath$suffix');
          if (await f.exists()) {
            await f.rename('$dbPath.superseded_$ts$suffix');
          }
        }
        await backup.rename(dbPath);
        // The database runs in WAL mode, so the newest commits may live only in
        // the -wal file. Quarantine moved it aside next to the database;
        // restoring the main file alone would silently drop exactly the most
        // recent messages while reporting success.
        for (final suffix in _dbSidecarSuffixes.skip(1)) {
          final side = File('${backup.path}$suffix');
          if (await side.exists()) {
            await side.rename('$dbPath$suffix');
          }
        }
        return true;
      } catch (_) {
        return false; // nothing was lost; caller falls through to a fresh DB
      }
    }
    return false;
  }

  /// Is there a local database FILE on disk?
  ///
  /// The invariant behind it (2026-07-19): a database file on disk proves an
  /// identity once existed here. So "no profile id in preferences, but a
  /// database file present" is not a fresh install — it is state that was
  /// PARTIALLY lost, which is exactly the anomaly the identity journal exists
  /// to catch.
  static Future<bool> localDatabaseFileExists() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File(p.join(dir.path, 'secretly.db')).exists();
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteLocalDatabaseFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = p.join(dir.path, 'secretly.db');
    final candidates = <String>[
      base,
      '$base-wal',
      '$base-shm',
      '$base-journal',
    ];
    for (final path in candidates) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {
        // ignore
      }
    }
    try {
      await for (final entity in Directory(dir.path).list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        // Every retained copy of the database, not just the legacy
        // unencrypted ones. This runs ONLY from explicit user actions
        // (profile reset, new profile, restore) — automatic paths quarantine
        // and never delete. Leaving them would make "erase my data"
        // reversible, since the empty-DB rescue would restore them on the
        // next launch.
        if (name.startsWith('secretly.db.unencrypted_backup_') ||
            name.startsWith('secretly.db.corrupt_backup_') ||
            name.startsWith('secretly.db.superseded_')) {
          await entity.delete();
        }
      }
    } catch (_) {
      // ignore legacy backup cleanup failures
    }
  }

  static Future<void> _ensureColumnExists(
    Database db, {
    required String table,
    required String column,
    required String alterSql,
  }) async {
    final rows = await db.rawQuery('PRAGMA table_info($table);');
    final exists = rows.any(
      (r) =>
          ((r['name'] as String?) ?? '').toLowerCase() == column.toLowerCase(),
    );
    if (exists) return;
    await db.execute(alterSql);
  }

  /// Idempotently ensures every column profileMetaUpsert / meta queries rely on
  /// exists on the `profile_meta` table. Runs on every DB open as a self-heal
  /// for installs whose migration path skipped a column ALTER (see baseOpen).
  static Future<void> _ensureProfileMetaColumns(Database db) async {
    const columns = <String, String>{
      'frame_id': 'ALTER TABLE profile_meta ADD COLUMN frame_id TEXT;',
      'cover_id': 'ALTER TABLE profile_meta ADD COLUMN cover_id TEXT;',
      'cover_path': 'ALTER TABLE profile_meta ADD COLUMN cover_path TEXT;',
      'emoji_status': 'ALTER TABLE profile_meta ADD COLUMN emoji_status TEXT;',
      'premium_badge': 'ALTER TABLE profile_meta ADD COLUMN premium_badge TEXT;',
      'last_seen_at_ms':
          'ALTER TABLE profile_meta ADD COLUMN last_seen_at_ms INTEGER;',
      'bio': 'ALTER TABLE profile_meta ADD COLUMN bio TEXT;',
      'privacy_audience_json':
          'ALTER TABLE profile_meta ADD COLUMN privacy_audience_json TEXT;',
    };
    try {
      for (final entry in columns.entries) {
        await _ensureColumnExists(
          db,
          table: 'profile_meta',
          column: entry.key,
          alterSql: entry.value,
        );
      }
    } catch (_) {
      // Best-effort — never block DB open on a self-heal.
    }
  }

  /// Idempotently ensures the quarantine NACK marker exists (see baseOpen).
  ///
  /// `nacked_at_ms` records when we last told the SENDER that this wire is
  /// undecryptable. It has to be persistent: a wire can sit quarantined across
  /// many launches, and an in-memory marker would either re-NACK the whole
  /// backlog on every start or (worse) never NACK it at all.
  /// К-1 (17.09.2026): ключи подписи сообщений комнаты — закрытое зерно у
  /// автора (`room_send_keys`), открытый ключ у получателя (`room_recv_keys`).
  static Future<void> _ensureRoomKeySigningColumns(Database db) async {
    try {
      await _ensureColumnExists(
        db,
        table: 'room_send_keys',
        column: 'signing_seed',
        alterSql: 'ALTER TABLE room_send_keys ADD COLUMN signing_seed BLOB;',
      );
      await _ensureColumnExists(
        db,
        table: 'room_recv_keys',
        column: 'signing_pub',
        alterSql: 'ALTER TABLE room_recv_keys ADD COLUMN signing_pub BLOB;',
      );
      // К-2: поколение, для которого устройство подтвердило сырой провод.
      await _ensureColumnExists(
        db,
        table: 'room_key_delivery',
        column: 'raw_epoch',
        alterSql:
            'ALTER TABLE room_key_delivery ADD COLUMN raw_epoch INTEGER NOT NULL DEFAULT -1;',
      );
    } catch (_) {
      // Best-effort — never block DB open on a self-heal.
    }
  }

  static Future<void> _ensureInboxQuarantineColumns(Database db) async {
    try {
      await _ensureColumnExists(
        db,
        table: 'inbox_quarantine',
        column: 'nacked_at_ms',
        alterSql:
            'ALTER TABLE inbox_quarantine ADD COLUMN nacked_at_ms INTEGER NOT NULL DEFAULT 0;',
      );
      // ИД-1 / С-1 (17.09.2026): who the RELAY says sent the parked wire, so
      // the replay can still reject a wire whose header names someone else.
      await _ensureColumnExists(
        db,
        table: 'inbox_quarantine',
        column: 'attested_from_device_id',
        alterSql:
            'ALTER TABLE inbox_quarantine ADD COLUMN attested_from_device_id TEXT;',
      );
    } catch (_) {
      // Best-effort — never block DB open on a self-heal.
    }
  }

  /// Idempotently ensures the premium ROOM cosmetic columns
  /// (cover_id / frame_id / name_emoji) exist on `group_settings`. Mirrors
  /// [_ensureProfileMetaColumns]: runs on every DB open (see baseOpen) so
  /// installs whose migration path predates these columns get them added on
  /// next launch. A missing column would make groupSettingsUpsert throw
  /// "no such column" and break ALL room snapshot sync — so this self-heal
  /// is deliberately best-effort and never blocks DB open.
  static Future<void> _ensureGroupSettingsCosmeticColumns(Database db) async {
    const columns = <String, String>{
      'cover_id': 'ALTER TABLE group_settings ADD COLUMN cover_id TEXT;',
      'frame_id': 'ALTER TABLE group_settings ADD COLUMN frame_id TEXT;',
      'name_emoji': 'ALTER TABLE group_settings ADD COLUMN name_emoji TEXT;',
    };
    try {
      for (final entry in columns.entries) {
        await _ensureColumnExists(
          db,
          table: 'group_settings',
          column: entry.key,
          alterSql: entry.value,
        );
      }
    } catch (_) {
      // Best-effort — never block DB open on a self-heal.
    }
  }

  static Future<void> _createPendingReceiptsSchema(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS pending_receipts (
  peer_device_id TEXT NOT NULL,
  payload_event_id TEXT NOT NULL,
  peer_profile_id TEXT,
  convo_id TEXT,
  status TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(peer_device_id, payload_event_id)
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS pending_receipts_updated_idx ON pending_receipts(updated_at_ms ASC, peer_device_id ASC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS pending_receipts_profile_idx ON pending_receipts(peer_profile_id, updated_at_ms ASC);',
    );

    // PR-E (Bug 17): defensive post-migration check. The original v45
    // migration relied on `CREATE INDEX IF NOT EXISTS` for two indexes
    // immediately after `CREATE TABLE IF NOT EXISTS` — if the process
    // crashed between the two statements (rare, but real on iOS during a
    // memory-pressure kill), `IF NOT EXISTS` would mask the missing index
    // forever, degrading every receipt query to a full-table scan. The
    // check below detects either index missing and drops + recreates the
    // table so the indexes are guaranteed present.
    final ok = await _pendingReceiptsIndexesPresent(db);
    if (!ok) {
      await db.execute('DROP TABLE IF EXISTS pending_receipts;');
      await db.execute('''
CREATE TABLE IF NOT EXISTS pending_receipts (
  peer_device_id TEXT NOT NULL,
  payload_event_id TEXT NOT NULL,
  peer_profile_id TEXT,
  convo_id TEXT,
  status TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(peer_device_id, payload_event_id)
);
''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS pending_receipts_updated_idx ON pending_receipts(updated_at_ms ASC, peer_device_id ASC);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS pending_receipts_profile_idx ON pending_receipts(peer_profile_id, updated_at_ms ASC);',
      );
    }
  }

  /// PR-E (Bug 17): introspect SQLite's `pragma index_list(...)` to confirm
  /// both `pending_receipts_*_idx` indexes survived the v45 migration. We
  /// rely on the index NAME (not column composition) because that's what
  /// `IF NOT EXISTS` keys on.
  static Future<bool> _pendingReceiptsIndexesPresent(
    DatabaseExecutor db,
  ) async {
    try {
      final rows = await db.rawQuery(
        "PRAGMA index_list('pending_receipts');",
      );
      final names = rows
          .map((r) => ((r['name'] as String?) ?? '').toLowerCase())
          .toSet();
      return names.contains('pending_receipts_updated_idx') &&
          names.contains('pending_receipts_profile_idx');
    } catch (_) {
      // If introspection itself fails the table almost certainly
      // doesn't exist yet (fresh-install path), so report «present» so
      // the caller doesn't drop a brand-new empty table.
      return true;
    }
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS events (
  event_id TEXT PRIMARY KEY,
  convo_id TEXT NOT NULL,
  type TEXT NOT NULL,
  sender_device_id TEXT NOT NULL,
  ciphertext_b64 TEXT NOT NULL,
  local_ciphertext_b64 TEXT,
  created_at_ms INTEGER NOT NULL,
  local_state TEXT NOT NULL DEFAULT 'received',
  payload_event_id TEXT,
  read_at_ms INTEGER,
  scheduled_at_ms INTEGER
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS outbox (
  msg_id TEXT PRIMARY KEY,
  to_device_id TEXT NOT NULL,
  ciphertext_b64 TEXT NOT NULL,
  ttl_seconds INTEGER NOT NULL,
  state TEXT NOT NULL,
  attempt_count INTEGER NOT NULL,
  next_retry_at_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  -- SERVER-SIDE SCHEDULED DELIVERY (2026-07-17): epoch-ms release time carried
  -- to the relay in the Send frame. 0 = deliver immediately. > 0 = the relay
  -- holds the ciphertext until T, so "send later" no longer depends on this
  -- device being awake at the due moment (the outbox uploads it NOW).
  deliver_at_ms INTEGER NOT NULL DEFAULT 0,
  event_id_ref TEXT,
  correlation_id TEXT,
  payload_event_id TEXT,
  convo_id TEXT,
  transport_meta_json TEXT,
  last_attempt_at_ms INTEGER,
  last_error_code TEXT,
  last_error_message_redacted TEXT,
  server_acked_at_ms INTEGER,
  device_delivered_at_ms INTEGER,
  expires_at_ms INTEGER,
  priority INTEGER NOT NULL DEFAULT 0,
  transport_hint TEXT,
  retry_bucket TEXT NOT NULL DEFAULT '',
  locked_by_worker TEXT,
  locked_at_ms INTEGER
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS inbox_seen (
  msg_id TEXT PRIMARY KEY,
  seen_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS attachments (
  blob_id TEXT PRIMARY KEY,
  file_key_b64 TEXT NOT NULL,
  access_token_b64 TEXT NOT NULL DEFAULT '',
  mime TEXT,
  plaintext_size_bytes INTEGER NOT NULL,
  ciphertext_size_bytes INTEGER NOT NULL,
  expires_at_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS sessions (
  peer_device_id TEXT PRIMARY KEY,
  root_key_b64 TEXT NOT NULL,
  send_chain_key_b64 TEXT NOT NULL,
  recv_chain_key_b64 TEXT NOT NULL,
  send_count INTEGER NOT NULL,
  recv_count INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS sessions_v3 (
  peer_device_id TEXT PRIMARY KEY,
  root_key_b64 TEXT NOT NULL,
  dh_self_seed_b64 TEXT NOT NULL,
  dh_self_pub_b64 TEXT NOT NULL,
  dh_remote_pub_b64 TEXT,
  send_chain_key_b64 TEXT,
  recv_chain_key_b64 TEXT,
  ns INTEGER NOT NULL,
  nr INTEGER NOT NULL,
  pn INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  initiator_pending_at_ms INTEGER NOT NULL DEFAULT 0,
  epoch INTEGER NOT NULL DEFAULT 0,
  -- Э-4 Ш-1 (редакция 2).
  --
  -- handshake_base_pub_b64: the initiator's ephemeral public key — the BASE KEY
  -- of the handshake this session was born from. Stable for the session's whole
  -- life, unlike root_key_b64 which is rewritten on every DH step, so it is the
  -- only sound way to recognise "this prekey wire is a REPEAT of the handshake
  -- I already adopted" (Д-3). Recognising that is what stops a repeat from
  -- re-initialising the session and destroying the receiver's own send chain
  -- (Д-1 — reproduced, it breaks the reverse direction permanently).
  --
  -- pending_prekey_header_json: the SPK-only X3DH part of our outbound
  -- handshake, cached so every message can carry it until the peer confirms,
  -- without burning a one-time prekey per message. SPK-only is mandatory: an
  -- OTK the peer no longer holds makes responderAccept hard-throw, which is
  -- poison in exactly the scenario this feature exists for (Д-2).
  handshake_base_pub_b64 TEXT,
  pending_prekey_header_json TEXT
);
''');

    // Candidate (archived) sessions for session-recovery hardening
    // (2026-06-12): when an inbound prekey overwrites — or a reset deletes —
    // the live session for a peer device, the old session is copied here first.
    // Inbound SESSION wires that fail against the primary session are retried
    // against these candidates, so a straggler encrypted under the previous
    // session is still decryptable (instead of being lost / forcing reinstall).
    await db.execute('''
CREATE TABLE IF NOT EXISTS sessions_v3_archive (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  peer_device_id TEXT NOT NULL,
  root_key_b64 TEXT NOT NULL,
  dh_self_seed_b64 TEXT NOT NULL,
  dh_self_pub_b64 TEXT NOT NULL,
  dh_remote_pub_b64 TEXT,
  send_chain_key_b64 TEXT,
  recv_chain_key_b64 TEXT,
  ns INTEGER NOT NULL,
  nr INTEGER NOT NULL,
  pn INTEGER NOT NULL,
  archived_at_ms INTEGER NOT NULL,
  -- Э-4 Р-4: the base key travels WITH the session into the archive. Without
  -- it, a late repeat of an OLDER handshake would fail to match the (newer)
  -- live session, fall through to X3DH, and overwrite that newer session —
  -- and repeats make late wires far more likely than they are today.
  handshake_base_pub_b64 TEXT
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS sessions_v3_archive_peer_idx ON sessions_v3_archive(peer_device_id, id);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS skipped_message_keys (
  peer_device_id TEXT NOT NULL,
  dh_pub_b64 TEXT NOT NULL,
  msg_num INTEGER NOT NULL,
  mk_b64 TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY(peer_device_id, dh_pub_b64, msg_num)
);
''');

    // Inbound quarantine (session-recovery hardening, 2026-06-12): inbound
    // ciphertexts that fail to decrypt right now (ratchet desync, session not
    // yet (re)established, out-of-order) are parked here instead of being
    // dropped. They are re-decrypted after the session with the sender heals,
    // so a transient desync never permanently loses a message.
    await db.execute('''
CREATE TABLE IF NOT EXISTS inbox_quarantine (
  msg_id TEXT PRIMARY KEY,
  sender_device_id TEXT,
  ciphertext_b64 TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_attempt_at_ms INTEGER NOT NULL DEFAULT 0,
  nacked_at_ms INTEGER NOT NULL DEFAULT 0,
  attested_from_device_id TEXT
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS inbox_quarantine_sender_idx ON inbox_quarantine(sender_device_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS inbox_quarantine_created_idx ON inbox_quarantine(created_at_ms);',
    );

    // Durable ACK queue: ACKs that fail to reach the relay are parked here and
    // retried on the next connect so the relay cursor always converges and
    // messages are never left stranded below the cursor.
    await db.execute('''
CREATE TABLE IF NOT EXISTS pending_acks (
  msg_id TEXT PRIMARY KEY,
  seq INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS contacts (
  contact_profile_id TEXT PRIMARY KEY,
  display_name TEXT,
  display_name_is_custom INTEGER NOT NULL DEFAULT 0,
  avatar_path TEXT,
  contact_emoji TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS profile_meta (
  profile_id TEXT PRIMARY KEY,
  nickname TEXT,
  avatar_path TEXT,
  bio TEXT,
  privacy_audience_json TEXT,
  frame_id TEXT,
  cover_id TEXT,
  last_seen_at_ms INTEGER,
  updated_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS conversations (
  convo_id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  peer_profile_id TEXT,
  title TEXT,
  pinned_at_ms INTEGER,
  muted INTEGER NOT NULL DEFAULT 0,
  muted_until_ms INTEGER NOT NULL DEFAULT 0,
  muted_mentions_only INTEGER NOT NULL DEFAULT 0,
  archived_at_ms INTEGER,
  auto_delete_seconds INTEGER,
  last_event_at_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS device_profiles (
  device_id TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS contact_devices (
  contact_profile_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  identity_key_pub_b64 TEXT NOT NULL,
  signed_prekey_pub_b64 TEXT NOT NULL,
  signed_prekey_sig_b64 TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  verified_at_ms INTEGER,
  approved_at_ms INTEGER,
  PRIMARY KEY(contact_profile_id, device_id)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS contact_verification (
  contact_profile_id TEXT PRIMARY KEY,
  verified_ever_at_ms INTEGER NOT NULL,
  account_identity_pub_b64 TEXT,
  account_identity_pinned_at_ms INTEGER
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS deletions (
  kind TEXT NOT NULL,
  target_id TEXT NOT NULL,
  deleted_at_ms INTEGER NOT NULL,
  PRIMARY KEY(kind, target_id)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS requests (
  contact_profile_id TEXT PRIMARY KEY,
  status TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS blocked_profiles (
  blocked_profile_id TEXT PRIMARY KEY,
  created_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS message_reactions (
  event_id TEXT NOT NULL,
  convo_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  actor_name TEXT,
  actor_avatar_path TEXT,
  emoji TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(event_id, profile_id)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS recent_stickers (
  profile_id TEXT NOT NULL,
  pack_id TEXT NOT NULL,
  pack_version INTEGER NOT NULL,
  sticker_id TEXT NOT NULL,
  last_used_at_ms INTEGER NOT NULL,
  use_count INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY(profile_id, pack_id, pack_version, sticker_id)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS sticker_packs (
  pack_id TEXT NOT NULL,
  pack_version INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  icon_sticker_id TEXT NOT NULL,
  icon_emoji_hint TEXT NOT NULL DEFAULT '',
  featured_rank INTEGER,
  tags_json TEXT NOT NULL DEFAULT '[]',
  installed INTEGER NOT NULL DEFAULT 0,
  sticker_count INTEGER NOT NULL DEFAULT 0,
  updated_at_ms INTEGER NOT NULL,
  installed_at_ms INTEGER,
  -- Режим доступа к своему набору (08.08.2026, Ш-1 ТЗ по стикерам).
  --
  -- 🔴 По умолчанию `sent_only`, потому что это РОВНО нынешнее поведение: свои
  -- наборы уже ездят зашифрованными блобами, и у того, кому отправили, доступ
  -- есть. Ш-1 обязан ничего не менять — он только даёт имя тому, что уже есть.
  -- Любое другое значение по умолчанию молча поменяло бы поведение старых
  -- наборов при обновлении.
  share_mode TEXT NOT NULL DEFAULT 'sent_only',
  PRIMARY KEY(pack_id, pack_version)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS sticker_pack_stickers (
  pack_id TEXT NOT NULL,
  pack_version INTEGER NOT NULL,
  sticker_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  local_path TEXT NOT NULL DEFAULT '',
  format TEXT NOT NULL,
  animated INTEGER NOT NULL DEFAULT 0,
  emoji_hint TEXT NOT NULL DEFAULT '',
  label TEXT NOT NULL DEFAULT '',
  keywords_json TEXT NOT NULL DEFAULT '[]',
  sha256_b64 TEXT NOT NULL DEFAULT '',
  size_bytes INTEGER NOT NULL DEFAULT 0,
  downloaded_at_ms INTEGER,
  last_accessed_at_ms INTEGER,
  -- Кэш выгруженного блоба (08.08.2026, С-11 ТЗ по стикерам).
  --
  -- 🔴 ЗАЧЕМ. Ссылка на шифртекст и ключ к нему создавались в момент ОТПРАВКИ и
  -- нигде не запоминались. Значит каждая отправка стикера платила полное
  -- шифрование и выгрузку заново, а собрать приглашение в набор из 50 стикеров
  -- означало 50 выгрузок подряд. Кэш чинит и то, и другое — причём одиночные
  -- отправки люди делают гораздо чаще, чем делятся наборами.
  --
  -- 🔴 `blob_expires_at_ms` обязателен. У блоба на сервере есть срок, и кэш без
  -- срока рано или поздно начал бы отдавать МЁРТВЫЕ ссылки: собеседник видел бы
  -- стикер, который не скачивается, и считал бы это поломкой приложения. Кэш без
  -- инвалидации хуже отсутствия кэша.
  blob_id TEXT NOT NULL DEFAULT '',
  blob_file_key_b64 TEXT NOT NULL DEFAULT '',
  blob_access_token_b64 TEXT NOT NULL DEFAULT '',
  blob_expires_at_ms INTEGER,
  PRIMARY KEY(pack_id, pack_version, sticker_id)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS group_members (
  group_id TEXT NOT NULL,
  member_profile_id TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY(group_id, member_profile_id)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS group_settings (
  group_id TEXT PRIMARY KEY,
  owner_profile_id TEXT NOT NULL,
  description TEXT,
  avatar_path TEXT,
  avatar_hash TEXT,
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
  pinned_message_event_id TEXT,
  state_version INTEGER NOT NULL DEFAULT 0,
  membership_version INTEGER NOT NULL DEFAULT 0,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS group_memberships (
  group_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  status TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member',
  source_link_id TEXT,
  tag TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(group_id, profile_id)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS group_admins (
  group_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY(group_id, profile_id)
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS group_invite_links (
  link_id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
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
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS pending_no_device_send (
  local_event_id TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL,
  payload_b64 TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');
    await _createPendingReceiptsSchema(db);

    await db.execute('''
CREATE TABLE IF NOT EXISTS message_attempt_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  correlation_id TEXT,
  local_event_id TEXT,
  msg_id TEXT,
  to_device_id TEXT,
  started_at_ms INTEGER NOT NULL,
  finished_at_ms INTEGER,
  attempt_index INTEGER NOT NULL,
  transport TEXT,
  result TEXT,
  error_code TEXT,
  error_message_redacted TEXT,
  latency_ms INTEGER
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS message_state_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  correlation_id TEXT,
  local_event_id TEXT,
  previous_state TEXT,
  new_state TEXT NOT NULL,
  reason_code TEXT,
  created_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS message_diag_snapshot (
  local_event_id TEXT PRIMARY KEY,
  correlation_id TEXT,
  convo_id TEXT,
  message_state TEXT,
  outbox_state_summary TEXT,
  last_error_code TEXT,
  last_error_message_redacted TEXT,
  updated_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS delivery_receipts_pending (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  payload_event_id TEXT NOT NULL,
  status TEXT NOT NULL,
  sender_device_id TEXT,
  sender_profile_id TEXT,
  created_at_ms INTEGER NOT NULL,
  applied_at_ms INTEGER
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS room_message_receipts (
  payload_event_id TEXT NOT NULL,
  reader_profile_id TEXT NOT NULL,
  reader_device_id TEXT,
  status TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(payload_event_id, reader_profile_id)
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS room_message_receipts (
  payload_event_id TEXT NOT NULL,
  reader_profile_id TEXT NOT NULL,
  reader_device_id TEXT,
  status TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(payload_event_id, reader_profile_id)
);
''');
    // ROOM SENDER KEY (2026-07-29, фаза 2).
    // Storage only — nothing writes these yet. Kept out of _ensureCriticalTables
    // on purpose: their absence disables a feature, it does not break the app.
    await db.execute('''
CREATE TABLE IF NOT EXISTS room_send_keys (
  room_id TEXT PRIMARY KEY,
  epoch INTEGER NOT NULL,
  chain_key BLOB NOT NULL,
  counter INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  signing_seed BLOB
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS room_recv_keys (
  room_id TEXT NOT NULL,
  sender_device_id TEXT NOT NULL,
  epoch INTEGER NOT NULL,
  chain_key BLOB NOT NULL,
  counter INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  signing_pub BLOB,
  PRIMARY KEY(room_id, sender_device_id, epoch)
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS room_skipped_keys (
  room_id TEXT NOT NULL,
  sender_device_id TEXT NOT NULL,
  epoch INTEGER NOT NULL,
  counter INTEGER NOT NULL,
  message_key BLOB NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY(room_id, sender_device_id, epoch, counter)
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS room_key_delivery (
  room_id TEXT NOT NULL,
  peer_device_id TEXT NOT NULL,
  epoch INTEGER NOT NULL,
  delivered_at_ms INTEGER NOT NULL,
  confirmed_epoch INTEGER NOT NULL DEFAULT -1,
  confirmed_at_ms INTEGER NOT NULL DEFAULT 0,
  raw_epoch INTEGER NOT NULL DEFAULT -1,
  PRIMARY KEY(room_id, peer_device_id)
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS room_member_snapshot (
  room_id TEXT PRIMARY KEY,
  device_ids_csv TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS room_skipped_keys_room_idx ON room_skipped_keys(room_id, sender_device_id, epoch);',
    );
    await db.execute('''
CREATE TABLE IF NOT EXISTS group_posting_state (
  group_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  last_admitted_at_ms INTEGER,
  next_allowed_at_ms INTEGER,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(group_id, profile_id)
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS room_call_sessions (
  group_id TEXT PRIMARY KEY,
  call_id TEXT NOT NULL,
  state TEXT NOT NULL,
  media_type TEXT NOT NULL,
  created_by_profile_id TEXT NOT NULL,
  created_by_device_id TEXT NOT NULL,
  state_version INTEGER NOT NULL DEFAULT 0,
  started_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  ended_at_ms INTEGER,
  expires_at_ms INTEGER NOT NULL
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS room_call_participants (
  group_id TEXT NOT NULL,
  call_id TEXT NOT NULL,
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
  PRIMARY KEY(group_id, call_id, profile_id, device_id)
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS call_journal (
  call_id TEXT NOT NULL,
  call_attempt_id TEXT PRIMARY KEY,
  convo_id TEXT NOT NULL,
  peer_profile_id TEXT NOT NULL,
  direction TEXT NOT NULL,
  scope TEXT NOT NULL,
  media_type TEXT NOT NULL,
  result TEXT NOT NULL,
  started_at_ms INTEGER NOT NULL,
  connected_at_ms INTEGER,
  ended_at_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  end_reason TEXT,
  peer_display_name TEXT,
  peer_avatar_path TEXT,
  did_connect INTEGER NOT NULL DEFAULT 0,
  had_video INTEGER NOT NULL DEFAULT 0,
  had_screen_share INTEGER NOT NULL DEFAULT 0,
  quality_summary_json TEXT,
  created_local_event_id TEXT,
  synced_chat_event_id TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS outbox_state_retry_idx ON outbox(state, next_retry_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS outbox_to_device_state_retry_idx ON outbox(to_device_id, state, next_retry_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS outbox_correlation_idx ON outbox(correlation_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS outbox_event_ref_idx ON outbox(event_id_ref);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS events_convo_created_idx ON events(convo_id, created_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS events_convo_created_state_idx ON events(convo_id, created_at_ms, local_state);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS events_payload_id_idx ON events(payload_event_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS events_convo_read_idx ON events(convo_id, read_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS inbox_seen_seen_at_idx ON inbox_seen(seen_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS attachments_expires_idx ON attachments(expires_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS recent_stickers_profile_last_used_idx ON recent_stickers(profile_id, last_used_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_attempt_log_correlation_idx ON message_attempt_log(correlation_id, started_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_attempt_log_local_event_idx ON message_attempt_log(local_event_id, started_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_attempt_log_msg_idx ON message_attempt_log(msg_id, started_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_state_log_correlation_idx ON message_state_log(correlation_id, created_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_state_log_local_event_idx ON message_state_log(local_event_id, created_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_diag_snapshot_correlation_idx ON message_diag_snapshot(correlation_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_diag_snapshot_convo_idx ON message_diag_snapshot(convo_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS delivery_receipts_pending_payload_idx ON delivery_receipts_pending(payload_event_id, created_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS room_message_receipts_payload_updated_idx ON room_message_receipts(payload_event_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS room_message_receipts_reader_updated_idx ON room_message_receipts(reader_profile_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_posting_state_group_updated_idx ON group_posting_state(group_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_posting_state_profile_next_idx ON group_posting_state(profile_id, next_allowed_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS sessions_updated_idx ON sessions(updated_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS sessions_v3_updated_idx ON sessions_v3(updated_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS contacts_updated_idx ON contacts(updated_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS conversations_last_event_idx ON conversations(last_event_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS conversations_pinned_idx ON conversations(pinned_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS conversations_muted_idx ON conversations(muted);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS conversations_archived_idx ON conversations(archived_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS conversations_auto_delete_idx ON conversations(auto_delete_seconds);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS profile_meta_updated_idx ON profile_meta(updated_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS blocked_profiles_created_idx ON blocked_profiles(created_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS device_profiles_profile_idx ON device_profiles(profile_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS contact_devices_profile_idx ON contact_devices(contact_profile_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS skipped_message_keys_peer_idx ON skipped_message_keys(peer_device_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS requests_status_updated_idx ON requests(status, updated_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_reactions_convo_idx ON message_reactions(convo_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_reactions_event_idx ON message_reactions(event_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_members_group_idx ON group_members(group_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_members_member_idx ON group_members(member_profile_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_settings_owner_idx ON group_settings(owner_profile_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_admins_group_idx ON group_admins(group_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_admins_profile_idx ON group_admins(profile_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_invite_links_group_idx ON group_invite_links(group_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS pending_no_device_send_profile_idx ON pending_no_device_send(profile_id, created_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS room_call_sessions_state_updated_idx ON room_call_sessions(state, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS room_call_sessions_expires_idx ON room_call_sessions(expires_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS room_call_participants_group_updated_idx ON room_call_participants(group_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS room_call_participants_profile_updated_idx ON room_call_participants(profile_id, updated_at_ms DESC);',
    );

    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'correlation_id',
      alterSql: 'ALTER TABLE outbox ADD COLUMN correlation_id TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'payload_event_id',
      alterSql: 'ALTER TABLE outbox ADD COLUMN payload_event_id TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'convo_id',
      alterSql: 'ALTER TABLE outbox ADD COLUMN convo_id TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'transport_meta_json',
      alterSql: 'ALTER TABLE outbox ADD COLUMN transport_meta_json TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'pending_no_device_send',
      column: 'transport_meta_json',
      alterSql:
          'ALTER TABLE pending_no_device_send ADD COLUMN transport_meta_json TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'last_attempt_at_ms',
      alterSql: 'ALTER TABLE outbox ADD COLUMN last_attempt_at_ms INTEGER;',
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'last_error_code',
      alterSql: 'ALTER TABLE outbox ADD COLUMN last_error_code TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'last_error_message_redacted',
      alterSql:
          'ALTER TABLE outbox ADD COLUMN last_error_message_redacted TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'server_acked_at_ms',
      alterSql: 'ALTER TABLE outbox ADD COLUMN server_acked_at_ms INTEGER;',
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'device_delivered_at_ms',
      alterSql: 'ALTER TABLE outbox ADD COLUMN device_delivered_at_ms INTEGER;',
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'expires_at_ms',
      alterSql: 'ALTER TABLE outbox ADD COLUMN expires_at_ms INTEGER;',
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'priority',
      alterSql:
          "ALTER TABLE outbox ADD COLUMN priority INTEGER NOT NULL DEFAULT 0;",
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'transport_hint',
      alterSql: 'ALTER TABLE outbox ADD COLUMN transport_hint TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'retry_bucket',
      alterSql:
          "ALTER TABLE outbox ADD COLUMN retry_bucket TEXT NOT NULL DEFAULT '';",
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'locked_by_worker',
      alterSql: 'ALTER TABLE outbox ADD COLUMN locked_by_worker TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'outbox',
      column: 'locked_at_ms',
      alterSql: 'ALTER TABLE outbox ADD COLUMN locked_at_ms INTEGER;',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS message_attempt_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  correlation_id TEXT,
  local_event_id TEXT,
  msg_id TEXT,
  to_device_id TEXT,
  started_at_ms INTEGER NOT NULL,
  finished_at_ms INTEGER,
  attempt_index INTEGER NOT NULL,
  transport TEXT,
  result TEXT,
  error_code TEXT,
  error_message_redacted TEXT,
  latency_ms INTEGER
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS message_state_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  correlation_id TEXT,
  local_event_id TEXT,
  previous_state TEXT,
  new_state TEXT NOT NULL,
  reason_code TEXT,
  created_at_ms INTEGER NOT NULL
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS message_diag_snapshot (
  local_event_id TEXT PRIMARY KEY,
  correlation_id TEXT,
  convo_id TEXT,
  message_state TEXT,
  outbox_state_summary TEXT,
  last_error_code TEXT,
  last_error_message_redacted TEXT,
  updated_at_ms INTEGER NOT NULL
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS delivery_receipts_pending (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  payload_event_id TEXT NOT NULL,
  status TEXT NOT NULL,
  sender_device_id TEXT,
  sender_profile_id TEXT,
  created_at_ms INTEGER NOT NULL,
  applied_at_ms INTEGER
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS outbox_state_retry_idx ON outbox(state, next_retry_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS outbox_to_device_state_retry_idx ON outbox(to_device_id, state, next_retry_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS outbox_correlation_idx ON outbox(correlation_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_attempt_log_correlation_idx ON message_attempt_log(correlation_id, started_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_attempt_log_local_event_idx ON message_attempt_log(local_event_id, started_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_attempt_log_msg_idx ON message_attempt_log(msg_id, started_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_state_log_correlation_idx ON message_state_log(correlation_id, created_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_state_log_local_event_idx ON message_state_log(local_event_id, created_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_diag_snapshot_correlation_idx ON message_diag_snapshot(correlation_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_diag_snapshot_convo_idx ON message_diag_snapshot(convo_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS delivery_receipts_pending_payload_idx ON delivery_receipts_pending(payload_event_id, created_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS room_message_receipts_payload_updated_idx ON room_message_receipts(payload_event_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS room_message_receipts_reader_updated_idx ON room_message_receipts(reader_profile_id, updated_at_ms DESC);',
    );
    await db.execute('''
CREATE TABLE IF NOT EXISTS call_journal (
  call_id TEXT NOT NULL,
  call_attempt_id TEXT PRIMARY KEY,
  convo_id TEXT NOT NULL,
  peer_profile_id TEXT NOT NULL,
  direction TEXT NOT NULL,
  scope TEXT NOT NULL,
  media_type TEXT NOT NULL,
  result TEXT NOT NULL,
  started_at_ms INTEGER NOT NULL,
  connected_at_ms INTEGER,
  ended_at_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  end_reason TEXT,
  peer_display_name TEXT,
  peer_avatar_path TEXT,
  did_connect INTEGER NOT NULL DEFAULT 0,
  had_video INTEGER NOT NULL DEFAULT 0,
  had_screen_share INTEGER NOT NULL DEFAULT 0,
  quality_summary_json TEXT,
  created_local_event_id TEXT,
  synced_chat_event_id TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS call_journal_convo_ended_idx ON call_journal(convo_id, ended_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS call_journal_peer_ended_idx ON call_journal(peer_profile_id, ended_at_ms DESC);',
    );
    await _ensureColumnExists(
      db,
      table: 'call_journal',
      column: 'acknowledged_at_ms',
      alterSql:
          'ALTER TABLE call_journal ADD COLUMN acknowledged_at_ms INTEGER;',
    );
    await _ensureColumnExists(
      db,
      table: 'call_journal',
      column: 'failure_code',
      alterSql: 'ALTER TABLE call_journal ADD COLUMN failure_code TEXT;',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS call_journal_convo_result_ack_idx ON call_journal(convo_id, result, acknowledged_at_ms, ended_at_ms DESC);',
    );

    // User-created (custom) chat folders (fresh-install schema). Local-only
    // chat-list organization — see also v55 migration and _ensureCriticalTables.
    await db.execute('''
CREATE TABLE IF NOT EXISTS chat_folders (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT,
  position INTEGER NOT NULL DEFAULT 0,
  created_at_ms INTEGER NOT NULL
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS chat_folder_members (
  folder_id TEXT NOT NULL,
  convo_id TEXT NOT NULL,
  PRIMARY KEY (folder_id, convo_id)
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS chat_folder_members_convo_idx ON chat_folder_members(convo_id);',
    );
    await _createPendingCallSignalsTable(db);
  }

  /// Очередь сигналов звонка через границу изолята.
  ///
  /// Одно определение на три пути создания — миграцию, `_createSchema` и
  /// `_ensureCriticalTables`. Три расходящихся `CREATE` мы уже проходили на
  /// `group_settings` 17.06, и разошлись они молча.
  static Future<void> _createPendingCallSignalsTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS pending_call_signals (
  signal_id TEXT PRIMARY KEY,
  call_id TEXT NOT NULL,
  call_attempt_id TEXT NOT NULL,
  action TEXT NOT NULL,
  from_profile_id TEXT NOT NULL,
  from_device_id TEXT,
  payload_json TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  stored_at_ms INTEGER NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS pending_call_signals_stored_idx '
      'ON pending_call_signals(stored_at_ms);',
    );
  }

  /// К-3 (17.09.2026): конверты отправленных сообщений комнаты — чтобы
  /// повторить ИМЕННО то, что получили участники, тому, у кого пропуск.
  /// Локальная копия сообщения конверта не содержит, а повтор голой копии
  /// попал бы в личный чат (`canReplayLocalCopyToPeer`).
  static Future<void> _createRoomOutboundTables(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS room_outbound_envelopes (
  payload_event_id TEXT PRIMARY KEY,
  room_id TEXT NOT NULL,
  envelope TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');
    // Возможности устройств собеседников (`E2ePayloadV1.caps`).
    await db.execute('''
CREATE TABLE IF NOT EXISTS device_caps (
  device_id TEXT PRIMARY KEY,
  caps TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS room_outbound_resends (
  payload_event_id TEXT NOT NULL,
  member_profile_id TEXT NOT NULL,
  resent_at_ms INTEGER NOT NULL,
  PRIMARY KEY(payload_event_id, member_profile_id)
);
''');
  }

  static Future<void> _ensureCriticalTables(Database db) async {
    await _createPendingCallSignalsTable(db);
    await _createRoomOutboundTables(db);
    await db.execute('''
CREATE TABLE IF NOT EXISTS events (
  event_id TEXT PRIMARY KEY,
  convo_id TEXT NOT NULL,
  type TEXT NOT NULL,
  sender_device_id TEXT NOT NULL,
  ciphertext_b64 TEXT NOT NULL,
  local_ciphertext_b64 TEXT,
  created_at_ms INTEGER NOT NULL,
  local_state TEXT NOT NULL DEFAULT 'received',
  payload_event_id TEXT,
  read_at_ms INTEGER,
  scheduled_at_ms INTEGER
);
''');
    await _ensureColumnExists(
      db,
      table: 'events',
      column: 'scheduled_at_ms',
      alterSql: 'ALTER TABLE events ADD COLUMN scheduled_at_ms INTEGER;',
    );

    // Э-4 Ш-1: the handshake columns are healed on EVERY open, not only by the
    // v61 migration.
    //
    // The ratchet writes `sessions_v3` on every single message, so a database
    // that somehow reached this build without the migration — an interrupted
    // upgrade, a restored file, a version anomaly — would fail on every send
    // and every receive. That is the one failure mode this table cannot
    // tolerate, and `_ensureColumnExists` is idempotent and free when the
    // column is already there. Same treatment `scheduled_at_ms` above gets,
    // and for the same reason.
    //
    // 🔴 SWALLOWED ON PURPOSE (found by the migration tests, 2026-08-02):
    // `_ensureColumnExists` is idempotent for a missing COLUMN but NOT for a
    // missing TABLE — `PRAGMA table_info` on one that does not exist returns
    // nothing, so it runs the ALTER and throws "no such table". Because this
    // helper runs on EVERY open, an un-caught throw here would turn a merely
    // degraded database into one that cannot be opened at all — trading a
    // recoverable state for the least recoverable one this app has. A healer
    // is never allowed to be the thing that blocks the door.
    Future<void> healColumn(String table, String column, String alterSql) async {
      try {
        await _ensureColumnExists(
          db,
          table: table,
          column: column,
          alterSql: alterSql,
        );
      } catch (_) {
        // The table itself is missing or unreadable. The v61 migration and
        // `_createSchema` both create it; if neither has, this open has bigger
        // problems than a column, and failing here would only hide them.
      }
    }

    await healColumn(
      'sessions_v3',
      'handshake_base_pub_b64',
      'ALTER TABLE sessions_v3 ADD COLUMN handshake_base_pub_b64 TEXT;',
    );
    await healColumn(
      'sessions_v3',
      'pending_prekey_header_json',
      'ALTER TABLE sessions_v3 ADD COLUMN pending_prekey_header_json TEXT;',
    );
    await healColumn(
      'sessions_v3_archive',
      'handshake_base_pub_b64',
      'ALTER TABLE sessions_v3_archive ADD COLUMN handshake_base_pub_b64 TEXT;',
    );

    // Состояние проверки контакта — лечим на КАЖДОМ открытии по той же причине,
    // что и столбцы ратчета выше: гейт отправки читает эти две записи перед
    // каждым сообщением. Их отсутствие после прерванного обновления означало бы
    // тихую поломку решения «предупреждать или нет» — а решение это про
    // подмену собеседника.
    await db.execute('''
CREATE TABLE IF NOT EXISTS contact_verification (
  contact_profile_id TEXT PRIMARY KEY,
  verified_ever_at_ms INTEGER NOT NULL,
  account_identity_pub_b64 TEXT,
  account_identity_pinned_at_ms INTEGER
);
''');
    await healColumn(
      'contact_devices',
      'approved_at_ms',
      'ALTER TABLE contact_devices ADD COLUMN approved_at_ms INTEGER;',
    );
    // v66: кэш выгруженного блоба стикера.
    for (final column in const <String, String>{
      'blob_id': "ALTER TABLE sticker_pack_stickers ADD COLUMN blob_id TEXT NOT NULL DEFAULT '';",
      'blob_file_key_b64':
          "ALTER TABLE sticker_pack_stickers ADD COLUMN blob_file_key_b64 TEXT NOT NULL DEFAULT '';",
      'blob_access_token_b64':
          "ALTER TABLE sticker_pack_stickers ADD COLUMN blob_access_token_b64 TEXT NOT NULL DEFAULT '';",
      'blob_expires_at_ms':
          'ALTER TABLE sticker_pack_stickers ADD COLUMN blob_expires_at_ms INTEGER;',
    }.entries) {
      await healColumn('sticker_pack_stickers', column.key, column.value);
    }
    // v65: режим доступа к своему набору стикеров.
    await healColumn(
      'sticker_packs',
      'share_mode',
      "ALTER TABLE sticker_packs ADD COLUMN share_mode TEXT NOT NULL DEFAULT 'sent_only';",
    );
    // v64: закреплённый ключ личности аккаунта контакта. Лечится здесь по той же
    // причине, что и всё выше: прерванное обновление не должно оставить базу без
    // столбца, который читает рабочий код.
    await healColumn(
      'contact_verification',
      'account_identity_pub_b64',
      'ALTER TABLE contact_verification ADD COLUMN account_identity_pub_b64 TEXT;',
    );
    await healColumn(
      'contact_verification',
      'account_identity_pinned_at_ms',
      'ALTER TABLE contact_verification ADD COLUMN account_identity_pinned_at_ms INTEGER;',
    );

    // Self-heal: inbound quarantine must exist for the session-recovery replay
    // path even if an upgrade was interrupted before migration v47 ran.
    await db.execute('''
CREATE TABLE IF NOT EXISTS inbox_quarantine (
  msg_id TEXT PRIMARY KEY,
  sender_device_id TEXT,
  ciphertext_b64 TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_attempt_at_ms INTEGER NOT NULL DEFAULT 0,
  nacked_at_ms INTEGER NOT NULL DEFAULT 0,
  attested_from_device_id TEXT
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS inbox_quarantine_sender_idx ON inbox_quarantine(sender_device_id);',
    );

    // ZERO-LOSS inbound journal (2026-07-12). Durably captures the DECRYPTED
    // plaintext the instant a wire decrypts, BEFORE the Double Ratchet advance is
    // persisted. Invariant: "ratchet advanced past a wire ⇒ its plaintext is in
    // this journal". If the process is suspended/killed in the post-decrypt gap
    // (deep-sleep first-wake: the OS reclaims the app during the device→profile
    // network lookup), the ciphertext becomes permanently undecryptable on
    // redelivery (the consumed message key is gone), but the plaintext is safe
    // here and is recovered by `_handleDelivered` instead of being lost. Rows are
    // deleted on successful apply; a TTL prune ages out orphans. Local-only;
    // never affects encryption or sync. IF NOT EXISTS keeps it harmless alongside
    // _createSchema on the same open.
    await db.execute('''
CREATE TABLE IF NOT EXISTS inbound_journal (
  msg_id TEXT PRIMARY KEY,
  sender_device_id TEXT,
  plaintext_b64 TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS inbound_journal_created_idx ON inbound_journal(created_at_ms);',
    );

    // Self-heal: candidate-session archive used by the session-recovery
    // decrypt fallback.
    await db.execute('''
CREATE TABLE IF NOT EXISTS sessions_v3_archive (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  peer_device_id TEXT NOT NULL,
  root_key_b64 TEXT NOT NULL,
  dh_self_seed_b64 TEXT NOT NULL,
  dh_self_pub_b64 TEXT NOT NULL,
  dh_remote_pub_b64 TEXT,
  send_chain_key_b64 TEXT,
  recv_chain_key_b64 TEXT,
  ns INTEGER NOT NULL,
  nr INTEGER NOT NULL,
  pn INTEGER NOT NULL,
  archived_at_ms INTEGER NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS sessions_v3_archive_peer_idx ON sessions_v3_archive(peer_device_id, id);',
    );

    // Self-heal: durable ACK queue.
    await db.execute('''
CREATE TABLE IF NOT EXISTS pending_acks (
  msg_id TEXT PRIMARY KEY,
  seq INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS profile_meta (
  profile_id TEXT PRIMARY KEY,
  nickname TEXT,
  avatar_path TEXT,
  bio TEXT,
  privacy_audience_json TEXT,
  frame_id TEXT,
  cover_id TEXT,
  last_seen_at_ms INTEGER,
  updated_at_ms INTEGER NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS profile_meta_updated_idx ON profile_meta(updated_at_ms);',
    );
    await _ensureColumnExists(
      db,
      table: 'profile_meta',
      column: 'last_seen_at_ms',
      alterSql: 'ALTER TABLE profile_meta ADD COLUMN last_seen_at_ms INTEGER;',
    );
    await _ensureColumnExists(
      db,
      table: 'profile_meta',
      column: 'bio',
      alterSql: 'ALTER TABLE profile_meta ADD COLUMN bio TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'profile_meta',
      column: 'privacy_audience_json',
      alterSql:
          'ALTER TABLE profile_meta ADD COLUMN privacy_audience_json TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'profile_meta',
      column: 'frame_id',
      alterSql: 'ALTER TABLE profile_meta ADD COLUMN frame_id TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'profile_meta',
      column: 'cover_id',
      alterSql: 'ALTER TABLE profile_meta ADD COLUMN cover_id TEXT;',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS blocked_profiles (
  blocked_profile_id TEXT PRIMARY KEY,
  created_at_ms INTEGER NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS blocked_profiles_created_idx ON blocked_profiles(created_at_ms);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS message_reactions (
  event_id TEXT NOT NULL,
  convo_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  actor_name TEXT,
  actor_avatar_path TEXT,
  emoji TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(event_id, profile_id)
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_reactions_convo_idx ON message_reactions(convo_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS message_reactions_event_idx ON message_reactions(event_id, updated_at_ms DESC);',
    );
    await db.execute('''
CREATE TABLE IF NOT EXISTS recent_stickers (
  profile_id TEXT NOT NULL,
  pack_id TEXT NOT NULL,
  pack_version INTEGER NOT NULL,
  sticker_id TEXT NOT NULL,
  last_used_at_ms INTEGER NOT NULL,
  use_count INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY(profile_id, pack_id, pack_version, sticker_id)
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS recent_stickers_profile_last_used_idx ON recent_stickers(profile_id, last_used_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS sticker_packs_featured_idx ON sticker_packs(installed DESC, featured_rank ASC, title COLLATE NOCASE ASC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS sticker_pack_stickers_pack_idx ON sticker_pack_stickers(pack_id, pack_version, sticker_id);',
    );
    await db.execute('''
CREATE TABLE IF NOT EXISTS sticker_packs (
  pack_id TEXT NOT NULL,
  pack_version INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  icon_sticker_id TEXT NOT NULL,
  icon_emoji_hint TEXT NOT NULL DEFAULT '',
  featured_rank INTEGER,
  tags_json TEXT NOT NULL DEFAULT '[]',
  installed INTEGER NOT NULL DEFAULT 0,
  sticker_count INTEGER NOT NULL DEFAULT 0,
  updated_at_ms INTEGER NOT NULL,
  installed_at_ms INTEGER,
  -- Режим доступа к своему набору (08.08.2026, Ш-1 ТЗ по стикерам).
  --
  -- 🔴 По умолчанию `sent_only`, потому что это РОВНО нынешнее поведение: свои
  -- наборы уже ездят зашифрованными блобами, и у того, кому отправили, доступ
  -- есть. Ш-1 обязан ничего не менять — он только даёт имя тому, что уже есть.
  -- Любое другое значение по умолчанию молча поменяло бы поведение старых
  -- наборов при обновлении.
  share_mode TEXT NOT NULL DEFAULT 'sent_only',
  PRIMARY KEY(pack_id, pack_version)
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS sticker_packs_featured_idx ON sticker_packs(installed DESC, featured_rank ASC, title COLLATE NOCASE ASC);',
    );
    await db.execute('''
CREATE TABLE IF NOT EXISTS sticker_pack_stickers (
  pack_id TEXT NOT NULL,
  pack_version INTEGER NOT NULL,
  sticker_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  local_path TEXT NOT NULL DEFAULT '',
  format TEXT NOT NULL,
  animated INTEGER NOT NULL DEFAULT 0,
  emoji_hint TEXT NOT NULL DEFAULT '',
  label TEXT NOT NULL DEFAULT '',
  keywords_json TEXT NOT NULL DEFAULT '[]',
  sha256_b64 TEXT NOT NULL DEFAULT '',
  size_bytes INTEGER NOT NULL DEFAULT 0,
  downloaded_at_ms INTEGER,
  last_accessed_at_ms INTEGER,
  -- Кэш выгруженного блоба (08.08.2026, С-11 ТЗ по стикерам).
  --
  -- 🔴 ЗАЧЕМ. Ссылка на шифртекст и ключ к нему создавались в момент ОТПРАВКИ и
  -- нигде не запоминались. Значит каждая отправка стикера платила полное
  -- шифрование и выгрузку заново, а собрать приглашение в набор из 50 стикеров
  -- означало 50 выгрузок подряд. Кэш чинит и то, и другое — причём одиночные
  -- отправки люди делают гораздо чаще, чем делятся наборами.
  --
  -- 🔴 `blob_expires_at_ms` обязателен. У блоба на сервере есть срок, и кэш без
  -- срока рано или поздно начал бы отдавать МЁРТВЫЕ ссылки: собеседник видел бы
  -- стикер, который не скачивается, и считал бы это поломкой приложения. Кэш без
  -- инвалидации хуже отсутствия кэша.
  blob_id TEXT NOT NULL DEFAULT '',
  blob_file_key_b64 TEXT NOT NULL DEFAULT '',
  blob_access_token_b64 TEXT NOT NULL DEFAULT '',
  blob_expires_at_ms INTEGER,
  PRIMARY KEY(pack_id, pack_version, sticker_id)
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS sticker_pack_stickers_pack_idx ON sticker_pack_stickers(pack_id, pack_version, sticker_id);',
    );
    await db.execute('''
CREATE TABLE IF NOT EXISTS group_members (
  group_id TEXT NOT NULL,
  member_profile_id TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY(group_id, member_profile_id)
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_members_group_idx ON group_members(group_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_members_member_idx ON group_members(member_profile_id);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS group_settings (
  group_id TEXT PRIMARY KEY,
  owner_profile_id TEXT NOT NULL,
  description TEXT,
  avatar_path TEXT,
  avatar_hash TEXT,
  avatar_path TEXT,
  avatar_hash TEXT,
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
  pinned_message_event_id TEXT,
  cover_id TEXT,
  frame_id TEXT,
  name_emoji TEXT,
  state_version INTEGER NOT NULL DEFAULT 0,
  membership_version INTEGER NOT NULL DEFAULT 0,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
    await _ensureColumnExists(
      db,
      table: 'group_settings',
      column: 'avatar_path',
      alterSql: 'ALTER TABLE group_settings ADD COLUMN avatar_path TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'group_settings',
      column: 'avatar_hash',
      alterSql: 'ALTER TABLE group_settings ADD COLUMN avatar_hash TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'group_settings',
      column: 'join_approval_required',
      alterSql:
          'ALTER TABLE group_settings ADD COLUMN join_approval_required INTEGER NOT NULL DEFAULT 0;',
    );
    await _ensureColumnExists(
      db,
      table: 'group_settings',
      column: 'state_version',
      alterSql:
          'ALTER TABLE group_settings ADD COLUMN state_version INTEGER NOT NULL DEFAULT 0;',
    );
    await _ensureColumnExists(
      db,
      table: 'group_settings',
      column: 'membership_version',
      alterSql:
          'ALTER TABLE group_settings ADD COLUMN membership_version INTEGER NOT NULL DEFAULT 0;',
    );
    await _ensureColumnExists(
      db,
      table: 'group_settings',
      column: 'pinned_message_event_id',
      alterSql:
          'ALTER TABLE group_settings ADD COLUMN pinned_message_event_id TEXT;',
    );
    // Premium room cosmetics (synced owner→members): preset cover, avatar frame,
    // and a name emoji. Idempotent ALTERs so existing rooms migrate in place and
    // every group_settings creation path ends up with these columns.
    await _ensureColumnExists(
      db,
      table: 'group_settings',
      column: 'cover_id',
      alterSql: 'ALTER TABLE group_settings ADD COLUMN cover_id TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'group_settings',
      column: 'frame_id',
      alterSql: 'ALTER TABLE group_settings ADD COLUMN frame_id TEXT;',
    );
    await _ensureColumnExists(
      db,
      table: 'group_settings',
      column: 'name_emoji',
      alterSql: 'ALTER TABLE group_settings ADD COLUMN name_emoji TEXT;',
    );
    await db.execute('''
CREATE TABLE IF NOT EXISTS group_memberships (
  group_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  status TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member',
  source_link_id TEXT,
  tag TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(group_id, profile_id)
);
''');
    await _ensureColumnExists(
      db,
      table: 'group_memberships',
      column: 'role',
      alterSql:
          "ALTER TABLE group_memberships ADD COLUMN role TEXT NOT NULL DEFAULT 'member';",
    );
    await _ensureColumnExists(
      db,
      table: 'group_memberships',
      column: 'tag',
      alterSql: 'ALTER TABLE group_memberships ADD COLUMN tag TEXT;',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_memberships_group_status_idx ON group_memberships(group_id, status, created_at_ms ASC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_memberships_profile_idx ON group_memberships(profile_id, updated_at_ms DESC);',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_settings_owner_idx ON group_settings(owner_profile_id);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS group_admins (
  group_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY(group_id, profile_id)
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_admins_group_idx ON group_admins(group_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_admins_profile_idx ON group_admins(profile_id);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS group_invite_links (
  link_id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
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
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_invite_links_group_idx ON group_invite_links(group_id, updated_at_ms DESC);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS pending_no_device_send (
  local_event_id TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL,
  payload_b64 TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS pending_no_device_send_profile_idx ON pending_no_device_send(profile_id, created_at_ms);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS deferred_room_inbound (
  synthetic_event_id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
  sender_profile_id TEXT NOT NULL,
  sender_device_id TEXT,
  command_text TEXT NOT NULL,
  msg_id TEXT,
  ciphertext_b64 TEXT,
  created_at_ms INTEGER NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS deferred_room_inbound_group_idx ON deferred_room_inbound(group_id, sender_profile_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS deferred_room_inbound_created_idx ON deferred_room_inbound(created_at_ms);',
    );

    await db.execute('''
CREATE TABLE IF NOT EXISTS group_posting_state (
  group_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  last_admitted_at_ms INTEGER,
  next_allowed_at_ms INTEGER,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY(group_id, profile_id)
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_posting_state_group_updated_idx ON group_posting_state(group_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS group_posting_state_profile_next_idx ON group_posting_state(profile_id, next_allowed_at_ms DESC);',
    );
    await db.execute('''
CREATE TABLE IF NOT EXISTS room_call_sessions (
  group_id TEXT PRIMARY KEY,
  call_id TEXT NOT NULL,
  state TEXT NOT NULL,
  media_type TEXT NOT NULL,
  created_by_profile_id TEXT NOT NULL,
  created_by_device_id TEXT NOT NULL,
  state_version INTEGER NOT NULL DEFAULT 0,
  started_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  ended_at_ms INTEGER,
  expires_at_ms INTEGER NOT NULL
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS room_call_participants (
  group_id TEXT NOT NULL,
  call_id TEXT NOT NULL,
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
  PRIMARY KEY(group_id, call_id, profile_id, device_id)
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS room_call_sessions_state_updated_idx ON room_call_sessions(state, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS room_call_sessions_expires_idx ON room_call_sessions(expires_at_ms);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS room_call_participants_group_updated_idx ON room_call_participants(group_id, updated_at_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS room_call_participants_profile_updated_idx ON room_call_participants(profile_id, updated_at_ms DESC);',
    );

    // Self-heal: user-created (custom) chat folders. Local-only chat-list
    // organization; mirrors the v55 migration so any install that skipped it
    // (interrupted upgrade) gets the tables on next launch.
    await db.execute('''
CREATE TABLE IF NOT EXISTS chat_folders (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT,
  position INTEGER NOT NULL DEFAULT 0,
  created_at_ms INTEGER NOT NULL
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS chat_folder_members (
  folder_id TEXT NOT NULL,
  convo_id TEXT NOT NULL,
  PRIMARY KEY (folder_id, convo_id)
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS chat_folder_members_convo_idx ON chat_folder_members(convo_id);',
    );
    // A1 ZERO-LOSS deferred-inbound park (see the v56 migration). Ensured on
    // every open so a decrypted group frame parked here can never be lost to a
    // missing table (e.g. an interrupted upgrade).
    await db.execute('''
CREATE TABLE IF NOT EXISTS deferred_room_inbound (
  synthetic_event_id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
  sender_profile_id TEXT NOT NULL,
  sender_device_id TEXT,
  command_text TEXT NOT NULL,
  msg_id TEXT,
  ciphertext_b64 TEXT,
  created_at_ms INTEGER NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS deferred_room_inbound_group_idx ON deferred_room_inbound(group_id, sender_profile_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS deferred_room_inbound_created_idx ON deferred_room_inbound(created_at_ms);',
    );
  }

  Future<Map<String, Object?>?> sessionV3Get(
    String peerDeviceId, {
    DatabaseExecutor? txn,
  }) async {
    final rows = await (txn ?? _db).query(
      'sessions_v3',
      where: 'peer_device_id = ?',
      whereArgs: [peerDeviceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> sessionV3Upsert({
    required String peerDeviceId,
    required String rootKeyB64,
    required String dhSelfSeedB64,
    required String dhSelfPubB64,
    required String? dhRemotePubB64,
    required String? sendChainKeyB64,
    required String? recvChainKeyB64,
    required int ns,
    required int nr,
    required int pn,
    DatabaseExecutor? txn,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await sessionV3Get(peerDeviceId, txn: txn);
    await (txn ?? _db).insert('sessions_v3', {
      'peer_device_id': peerDeviceId,
      'root_key_b64': rootKeyB64,
      'dh_self_seed_b64': dhSelfSeedB64,
      'dh_self_pub_b64': dhSelfPubB64,
      'dh_remote_pub_b64': dhRemotePubB64,
      'send_chain_key_b64': sendChainKeyB64,
      'recv_chain_key_b64': recvChainKeyB64,
      'ns': ns,
      'nr': nr,
      'pn': pn,
      'updated_at_ms': now,
      'created_at_ms': existing != null ? existing['created_at_ms'] : now,
      // Preserve the glare-tie-break marker across ratchet advances; it is set
      // and cleared explicitly via sessionV3SetInitiatorPendingAt.
      'initiator_pending_at_ms':
          existing != null ? (existing['initiator_pending_at_ms'] ?? 0) : 0,
      // TZ Epic B: like the glare marker — set explicitly via
      // sessionV3SetEpoch, preserved across every ratchet advance.
      'epoch': existing != null ? (existing['epoch'] ?? 0) : 0,
      // Э-4: same rule for both handshake columns. This upsert runs on EVERY
      // ratchet advance, and `ConflictAlgorithm.replace` rewrites the whole
      // row — so anything not carried here is silently erased on the next
      // message. Losing the base key would make the receiver stop recognising
      // repeats of the handshake it already adopted, which is exactly the
      // session-destroying path Д-1 describes.
      'handshake_base_pub_b64':
          existing != null ? existing['handshake_base_pub_b64'] : null,
      'pending_prekey_header_json':
          existing != null ? existing['pending_prekey_header_json'] : null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Glare tie-break marker: epoch-ms when this session was created as a fresh,
  // not-yet-confirmed initiator (0 = not a pending initiator). No-op if the
  // session row does not exist.
  Future<void> sessionV3SetInitiatorPendingAt(
    String peerDeviceId,
    int atMs, {
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).update(
      'sessions_v3',
      {'initiator_pending_at_ms': atMs},
      where: 'peer_device_id = ?',
      whereArgs: [peerDeviceId],
    );
  }

  /// TZ Epic B: stamp the session epoch (creation wall-ms; for a responder —
  /// the initiator's 'se' from the adopted prekey header). No-op if the row
  /// does not exist.
  Future<void> sessionV3SetEpoch(
    String peerDeviceId,
    int epoch, {
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).update(
      'sessions_v3',
      {'epoch': epoch},
      where: 'peer_device_id = ?',
      whereArgs: [peerDeviceId],
    );
  }

  /// Э-4: record which handshake this session was born from, and (optionally)
  /// the SPK-only header we will repeat until the peer confirms.
  ///
  /// Written in the SAME transaction as the session state (Р-6): a half-written
  /// pair means we advertise a handshake that is not in the database, or hold a
  /// base key for a session that does not exist.
  ///
  /// [pendingPrekeyHeaderJson] `null` CLEARS the cached header — that is how
  /// confirmation drops it, next to where `initiator_pending_at_ms` is zeroed.
  /// A header left behind after confirmation would be repeated forever.
  Future<void> sessionV3SetHandshake(
    String peerDeviceId, {
    String? baseKeyB64,
    String? pendingPrekeyHeaderJson,
    bool clearPendingHeader = false,
    DatabaseExecutor? txn,
  }) async {
    final values = <String, Object?>{};
    if (baseKeyB64 != null) values['handshake_base_pub_b64'] = baseKeyB64;
    if (clearPendingHeader) {
      values['pending_prekey_header_json'] = null;
    } else if (pendingPrekeyHeaderJson != null) {
      values['pending_prekey_header_json'] = pendingPrekeyHeaderJson;
    }
    if (values.isEmpty) return;
    await (txn ?? _db).update(
      'sessions_v3',
      values,
      where: 'peer_device_id = ?',
      whereArgs: [peerDeviceId],
    );
  }

  Future<void> sessionV3Delete(
    String peerDeviceId, {
    // И-4c (2026-07-24): a RESET archives the session before
    // deleting it, so its skipped message keys (out-of-order stragglers under the
    // OLD chain) must SURVIVE — otherwise a legitimately-late, correctly-ordered
    // wire that needed one of those keys can no longer decrypt from the archive.
    // They key on the peer's OLD dh_pub, never collide with the fresh session,
    // and age out via the 7-day skipped-key prune. Non-reset deletes (device gone
    // / identity rotated) keep the legacy wipe (default true).
    bool pruneSkippedKeys = true,
  }) async {
    await _db.delete(
      'sessions_v3',
      where: 'peer_device_id = ?',
      whereArgs: [peerDeviceId],
    );
    if (pruneSkippedKeys) {
      await _db.delete(
        'skipped_message_keys',
        where: 'peer_device_id = ?',
        whereArgs: [peerDeviceId],
      );
    }
  }

  /// Archive the live v3 session into the bounded candidate archive BEFORE a
  /// reset deletes it, so stragglers / quarantined ciphertext encrypted under
  /// the OLD chain can still be decrypted via the fallback path after a peer
  /// signed-prekey or identity rotation. Mirrors
  /// RatchetSessionManagerV3.archiveCurrentSession but runs inline — this was
  /// the only session-delete family that skipped archiving (every other delete
  /// site already archives first). FS-preserving: the live forward-ratchet
  /// state is still deleted; only a short-lived (keepLast=8, И-4d) copy of the old
  /// chain is retained for backward decryption of in-flight messages.
  Future<void> _archiveSessionV3BeforeDelete(String peerDeviceId) async {
    try {
      final row = await sessionV3Get(peerDeviceId);
      if (row == null) return;
      final oldRoot = row['root_key_b64'] as String?;
      if (oldRoot == null || oldRoot.isEmpty) return;
      await sessionV3ArchivePush(
        peerDeviceId: peerDeviceId,
        rootKeyB64: oldRoot,
        dhSelfSeedB64: row['dh_self_seed_b64'] as String,
        dhSelfPubB64: row['dh_self_pub_b64'] as String,
        dhRemotePubB64: row['dh_remote_pub_b64'] as String?,
        sendChainKeyB64: row['send_chain_key_b64'] as String?,
        recvChainKeyB64: row['recv_chain_key_b64'] as String?,
        ns: (row['ns'] as num).toInt(),
        nr: (row['nr'] as num).toInt(),
        pn: (row['pn'] as num).toInt(),
      );
    } catch (_) {
      // best-effort; never let archiving block the reset
    }
  }

  // ---- Candidate (archived) sessions (session-recovery hardening) -----------
  // Copy a soon-to-be-replaced/deleted session into the archive so inbound
  // stragglers encrypted under it stay decryptable. Keeps at most [keepLast]
  // newest archives per peer device.
  Future<void> sessionV3ArchivePush({
    required String peerDeviceId,
    required String rootKeyB64,
    required String dhSelfSeedB64,
    required String dhSelfPubB64,
    required String? dhRemotePubB64,
    required String? sendChainKeyB64,
    required String? recvChainKeyB64,
    required int ns,
    required int nr,
    required int pn,
    /// Э-4 Р-4: the base key of the handshake this session came from, carried
    /// into the archive so a LATE repeat of an older handshake still matches
    /// something and cannot fall through to X3DH and overwrite a newer session.
    String? handshakeBasePubB64,
    // И-4d (2026-07-24): keep the last 8 (was 3) prior sessions per
    // peer so a burst of re-keys / prekey overwrites can't evict a session that
    // still has in-flight ciphertext under it — the "пачка на одной галочке под
    // старой сессией" (Bug B). Archived rows are tiny; the straggler fallback
    // only ever reads them on the (rare) recovery path.
    int keepLast = 8,
    DatabaseExecutor? txn,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (txn ?? _db).insert('sessions_v3_archive', {
      'peer_device_id': peerDeviceId,
      'root_key_b64': rootKeyB64,
      'dh_self_seed_b64': dhSelfSeedB64,
      'dh_self_pub_b64': dhSelfPubB64,
      'dh_remote_pub_b64': dhRemotePubB64,
      'send_chain_key_b64': sendChainKeyB64,
      'recv_chain_key_b64': recvChainKeyB64,
      'ns': ns,
      'nr': nr,
      'pn': pn,
      'archived_at_ms': now,
      'handshake_base_pub_b64': handshakeBasePubB64,
    });
    // Trim to the newest [keepLast] archives for this peer.
    await (txn ?? _db).rawDelete(
      'DELETE FROM sessions_v3_archive WHERE peer_device_id = ? AND id NOT IN ('
      'SELECT id FROM sessions_v3_archive WHERE peer_device_id = ? ORDER BY id DESC LIMIT ?)',
      [peerDeviceId, peerDeviceId, keepLast],
    );
  }

  Future<List<Map<String, Object?>>> sessionV3ArchiveList(
    String peerDeviceId, {
    // И-4d: match the raised keepLast (8) so the straggler-decrypt fallback tries
    // every prior session we now retain, not just the newest 3.
    int limit = 8,
    DatabaseExecutor? txn,
  }) async {
    return (txn ?? _db).query(
      'sessions_v3_archive',
      where: 'peer_device_id = ?',
      whereArgs: [peerDeviceId],
      orderBy: 'id DESC',
      limit: limit,
    );
  }

  Future<void> sessionV3ArchiveUpdate({
    required int id,
    required String dhSelfSeedB64,
    required String dhSelfPubB64,
    required String? dhRemotePubB64,
    required String? sendChainKeyB64,
    required String? recvChainKeyB64,
    required int ns,
    required int nr,
    required int pn,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).update(
      'sessions_v3_archive',
      {
        'dh_self_seed_b64': dhSelfSeedB64,
        'dh_self_pub_b64': dhSelfPubB64,
        'dh_remote_pub_b64': dhRemotePubB64,
        'send_chain_key_b64': sendChainKeyB64,
        'recv_chain_key_b64': recvChainKeyB64,
        'ns': ns,
        'nr': nr,
        'pn': pn,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> sessionV3ArchivePrune({
    required int olderThanMs,
  }) async {
    return _db.delete(
      'sessions_v3_archive',
      where: 'archived_at_ms < ?',
      whereArgs: [olderThanMs],
    );
  }

  Future<void> skippedKeyUpsert({
    required String peerDeviceId,
    required String dhPubB64,
    required int msgNum,
    required String mkB64,
    DatabaseExecutor? txn,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (txn ?? _db).insert('skipped_message_keys', {
      'peer_device_id': peerDeviceId,
      'dh_pub_b64': dhPubB64,
      'msg_num': msgNum,
      'mk_b64': mkB64,
      'created_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Map<String, Object?>?> skippedKeyGet({
    required String peerDeviceId,
    required String dhPubB64,
    required int msgNum,
    DatabaseExecutor? txn,
  }) async {
    final rows = await (txn ?? _db).query(
      'skipped_message_keys',
      where: 'peer_device_id = ? AND dh_pub_b64 = ? AND msg_num = ?',
      whereArgs: [peerDeviceId, dhPubB64, msgNum],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> skippedKeyDelete({
    required String peerDeviceId,
    required String dhPubB64,
    required int msgNum,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).delete(
      'skipped_message_keys',
      where: 'peer_device_id = ? AND dh_pub_b64 = ? AND msg_num = ?',
      whereArgs: [peerDeviceId, dhPubB64, msgNum],
    );
  }

  Future<void> skippedKeysPrune({
    required int olderThanMs,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).delete(
      'skipped_message_keys',
      where: 'created_at_ms < ?',
      whereArgs: [olderThanMs],
    );
  }

  // ───────────────────────── ROOM SENDER KEY ─────────────────────────
  // Storage, фаза 2. Deliberately
  // placed next to the pairwise skipped-key accessors above: the room chain is
  // the same idea one level up, and the two should be read side by side.
  //
  // Every method takes `txn` for the same reason the pairwise ones do — И-2
  // applies one inbound wire in a SINGLE transaction, and a db call made
  // outside the enclosing transaction DEADLOCKS (lesson from И-2, commit
  // 69ff4224). Nothing calls any of this yet.

  /// My own sending chain for [roomId] — one per room, because I am one sender.
  Future<Map<String, Object?>?> roomSendKeyGet({
    required String roomId,
    DatabaseExecutor? txn,
  }) async {
    final rows = await (txn ?? _db).query(
      'room_send_keys',
      where: 'room_id = ?',
      whereArgs: [roomId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Installs a generation — used when the room is first keyed and on every
  /// rotation. Replaces outright: once I rotate I never send under the old
  /// generation again (receivers keep the old chain, see [roomRecvKeyPut]).
  Future<void> roomSendKeyPut({
    required String roomId,
    required int epoch,
    required Uint8List chainKey,
    required int counter,
    required int createdAtMs,
    Uint8List? signingSeed,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).insert('room_send_keys', {
      'room_id': roomId,
      'epoch': epoch,
      'chain_key': chainKey,
      'counter': counter,
      'created_at_ms': createdAtMs,
      'signing_seed': signingSeed,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Steps my chain forward after a send. Guarded on [epoch]: if a rotation
  /// landed between reading the chain and writing it back, this is a no-op
  /// instead of resurrecting the generation a departed member can still read.
  /// Returns true when the row was actually advanced.
  Future<bool> roomSendKeyAdvance({
    required String roomId,
    required int epoch,
    required Uint8List nextChainKey,
    required int nextCounter,
    DatabaseExecutor? txn,
  }) async {
    final n = await (txn ?? _db).update(
      'room_send_keys',
      {'chain_key': nextChainKey, 'counter': nextCounter},
      where: 'room_id = ? AND epoch = ?',
      whereArgs: [roomId, epoch],
    );
    return n > 0;
  }

  /// A peer's chain, per generation. Generations are SEPARATE rows on purpose:
  /// a message sent just before a rotation is still in flight, and dropping the
  /// old chain the moment a new one arrives would lose it.
  Future<Map<String, Object?>?> roomRecvKeyGet({
    required String roomId,
    required String senderDeviceId,
    required int epoch,
    DatabaseExecutor? txn,
  }) async {
    final rows = await (txn ?? _db).query(
      'room_recv_keys',
      where: 'room_id = ? AND sender_device_id = ? AND epoch = ?',
      whereArgs: [roomId, senderDeviceId, epoch],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> roomRecvKeyPut({
    required String roomId,
    required String senderDeviceId,
    required int epoch,
    required Uint8List chainKey,
    required int counter,
    required int updatedAtMs,
    Uint8List? signingPub,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).insert('room_recv_keys', {
      'room_id': roomId,
      'sender_device_id': senderDeviceId,
      'epoch': epoch,
      'chain_key': chainKey,
      'counter': counter,
      'updated_at_ms': updatedAtMs,
      'signing_pub': signingPub,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Продвинуть принимающую цепочку, НЕ трогая остальное (ключ подписи К-1).
  /// Полная перезапись строки стёрла бы открытый ключ автора, и следующие
  /// сообщения поколения перестали бы проверяться.
  Future<void> roomRecvKeyAdvance({
    required String roomId,
    required String senderDeviceId,
    required int epoch,
    required Uint8List chainKey,
    required int counter,
    required int updatedAtMs,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).update(
      'room_recv_keys',
      {'chain_key': chainKey, 'counter': counter, 'updated_at_ms': updatedAtMs},
      where: 'room_id = ? AND sender_device_id = ? AND epoch = ?',
      whereArgs: [roomId, senderDeviceId, epoch],
    );
  }

  /// Forgets every generation of [senderDeviceId] in [roomId] — for a member
  /// who left. Their FUTURE traffic is already unreadable (they get no new
  /// key); this drops what is left of their chains.
  Future<void> roomRecvKeysForget({
    required String roomId,
    required String senderDeviceId,
    DatabaseExecutor? txn,
  }) async {
    final db = txn ?? _db;
    await db.delete(
      'room_recv_keys',
      where: 'room_id = ? AND sender_device_id = ?',
      whereArgs: [roomId, senderDeviceId],
    );
    await db.delete(
      'room_skipped_keys',
      where: 'room_id = ? AND sender_device_id = ?',
      whereArgs: [roomId, senderDeviceId],
    );
  }

  /// A message key for a position the chain has already passed, kept so a
  /// straggler still opens. `ignore` on conflict: the FIRST key stored for a
  /// position is the real one — a later wire claiming the same position must
  /// not be able to overwrite it.
  Future<void> roomSkippedKeyPut({
    required String roomId,
    required String senderDeviceId,
    required int epoch,
    required int counter,
    required Uint8List messageKey,
    required int createdAtMs,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).insert('room_skipped_keys', {
      'room_id': roomId,
      'sender_device_id': senderDeviceId,
      'epoch': epoch,
      'counter': counter,
      'message_key': messageKey,
      'created_at_ms': createdAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Reads WITHOUT consuming. The caller deletes only after the tag verifies
  /// (see [roomSkippedKeyDelete]) — a read-and-delete would let anyone destroy
  /// a legitimate key by posting one corrupt ciphertext at that position, which
  /// is message loss on demand.
  Future<Uint8List?> roomSkippedKeyGet({
    required String roomId,
    required String senderDeviceId,
    required int epoch,
    required int counter,
    DatabaseExecutor? txn,
  }) async {
    final rows = await (txn ?? _db).query(
      'room_skipped_keys',
      columns: ['message_key'],
      where:
          'room_id = ? AND sender_device_id = ? AND epoch = ? AND counter = ?',
      whereArgs: [roomId, senderDeviceId, epoch, counter],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['message_key'];
    return raw is Uint8List
        ? raw
        : (raw is List<int> ? Uint8List.fromList(raw) : null);
  }

  Future<void> roomSkippedKeyDelete({
    required String roomId,
    required String senderDeviceId,
    required int epoch,
    required int counter,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).delete(
      'room_skipped_keys',
      where:
          'room_id = ? AND sender_device_id = ? AND epoch = ? AND counter = ?',
      whereArgs: [roomId, senderDeviceId, epoch, counter],
    );
  }

  /// Same 7-day horizon as the pairwise prune — an unbounded key store is both
  /// a disk leak and a widening window for a seized device.
  Future<void> roomSkippedKeysPrune({
    required int olderThanMs,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).delete(
      'room_skipped_keys',
      where: 'created_at_ms < ?',
      whereArgs: [olderThanMs],
    );
  }

  /// The newest generation of MY key that [peerDeviceId] has been given, so the
  /// key rides along once per generation instead of on every message.
  Future<int?> roomKeyDeliveredEpoch({
    required String roomId,
    required String peerDeviceId,
    DatabaseExecutor? txn,
  }) async {
    final rows = await (txn ?? _db).query(
      'room_key_delivery',
      columns: ['epoch'],
      where: 'room_id = ? AND peer_device_id = ?',
      whereArgs: [roomId, peerDeviceId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['epoch'] as int?;
  }

  /// Per-room sender-key state for the diagnostics report (F-ROOMSK-6).
  ///
  /// Answers the one question a field tester actually has: **will my next room
  /// message be sealed under the sender key, or fall back to the pairwise
  /// fanout?** It is `owed == 0`. Deliberately CURRENT STATE rather than event
  /// counters — after the confirmed-keying change the interesting thing is not
  /// how often something happened, it is who is still unconfirmed right now.
  ///
  /// `delivered` counts devices we handed this generation's key to; `confirmed`
  /// counts those that acked applying it. The gap between the two is exactly
  /// the set that keeps the room on the pairwise path.
  Future<List<Map<String, Object?>>> roomSenderKeyDiagnostics({
    int limit = 20,
  }) async {
    return _db.rawQuery(
      'SELECT k.room_id AS room_id, k.epoch AS epoch, k.counter AS counter, '
      '  (SELECT COUNT(*) FROM room_key_delivery d '
      '     WHERE d.room_id = k.room_id AND d.epoch >= k.epoch) AS delivered, '
      '  (SELECT COUNT(*) FROM room_key_delivery d '
      '     WHERE d.room_id = k.room_id AND d.confirmed_epoch >= k.epoch) '
      '   AS confirmed '
      'FROM room_send_keys k ORDER BY k.room_id LIMIT ?',
      [limit],
    );
  }

  /// The newest generation this peer has ACKNOWLEDGED applying (`gkeyack`), or
  /// null when they never confirmed one.
  ///
  /// Distinct from [roomKeyDeliveredEpoch] on purpose (F-ROOMSK-3/4): delivered
  /// means "we put it in the outbox", confirmed means "they told us they can
  /// use it". Only the second is evidence, and only the second proves their
  /// build understands the format at all.
  Future<int?> roomKeyConfirmedEpoch({
    required String roomId,
    required String peerDeviceId,
    DatabaseExecutor? txn,
  }) async {
    final rows = await (txn ?? _db).query(
      'room_key_delivery',
      columns: ['confirmed_epoch'],
      where: 'room_id = ? AND peer_device_id = ?',
      whereArgs: [roomId, peerDeviceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final v = rows.first['confirmed_epoch'] as int?;
    // -1 is the "never confirmed" sentinel; epoch 0 is a real generation.
    if (v == null || v < 0) return null;
    return v;
  }

  /// Records a peer's `gkeyack`. Never moves BACKWARD, for the same reason as
  /// [roomKeyDeliveryMark]: a delayed ack for an old generation must not make a
  /// peer look current for a newer one they cannot read.
  ///
  /// Uses an UPDATE rather than an upsert: an ack for a room/device we never
  /// sent a key to is not evidence of anything, and inventing a row for it
  /// would let a peer mark ITSELF as keyed.
  /// К-2: устройство подтвердило поколение [epoch] И умеет сырой провод.
  Future<void> roomKeyRawConfirm({
    required String roomId,
    required String peerDeviceId,
    required int epoch,
    DatabaseExecutor? txn,
  }) async {
    try {
      await (txn ?? _db).rawUpdate(
        'UPDATE room_key_delivery SET raw_epoch = MAX(raw_epoch, ?) '
        'WHERE room_id = ? AND peer_device_id = ?',
        [epoch, roomId, peerDeviceId],
      );
    } catch (_) {
      // Нет колонки (самолечение не прошло) — остаёмся на попарной рассылке.
    }
  }

  /// К-2: устройства, которым поколение [epoch] можно отдать сырым проводом.
  Future<Set<String>> roomKeyRawReadyDevices({
    required String roomId,
    required int epoch,
  }) async {
    try {
      final rows = await _db.query(
        'room_key_delivery',
        columns: ['peer_device_id'],
        where: 'room_id = ? AND confirmed_epoch >= ? AND raw_epoch >= ?',
        whereArgs: [roomId, epoch, epoch],
      );
      return rows
          .map((r) => ((r['peer_device_id'] as String?) ?? '').trim())
          .where((d) => d.isNotEmpty)
          .toSet();
    } catch (_) {
      return const <String>{};
    }
  }

  Future<void> roomKeyDeliveryConfirm({
    required String roomId,
    required String peerDeviceId,
    required int epoch,
    required int confirmedAtMs,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).rawUpdate(
      'UPDATE room_key_delivery SET '
      '  confirmed_at_ms = CASE WHEN ? >= confirmed_epoch THEN ? ELSE confirmed_at_ms END, '
      '  confirmed_epoch = MAX(confirmed_epoch, ?) '
      'WHERE room_id = ? AND peer_device_id = ?',
      [epoch, confirmedAtMs, epoch, roomId, peerDeviceId],
    );
  }

  /// Records that [epoch] reached [peerDeviceId]. Never moves BACKWARD: a
  /// delayed confirmation for an old generation must not overwrite a newer one,
  /// or the peer would be considered up to date and never receive the key it
  /// actually needs — silent, permanent unreadability for that member.
  Future<void> roomKeyDeliveryMark({
    required String roomId,
    required String peerDeviceId,
    required int epoch,
    required int deliveredAtMs,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).rawInsert(
      'INSERT INTO room_key_delivery(room_id, peer_device_id, epoch, delivered_at_ms) '
      'VALUES(?,?,?,?) '
      'ON CONFLICT(room_id, peer_device_id) DO UPDATE SET '
      '  delivered_at_ms = CASE WHEN excluded.epoch >= room_key_delivery.epoch '
      '    THEN excluded.delivered_at_ms ELSE room_key_delivery.delivered_at_ms END, '
      '  epoch = MAX(room_key_delivery.epoch, excluded.epoch)',
      [roomId, peerDeviceId, epoch, deliveredAtMs],
    );
  }

  /// Has this member EVER acknowledged a room message, in any room?
  ///
  /// Proves their build emits room receipts at all. Builds before 2026-07-30
  /// sent none, so "no receipt from them" says nothing about delivery — acting
  /// on that silence would re-key every member still on an older version, on a
  /// loop, forever. Same principle the aliveness gate already applies: absence
  /// of evidence is not evidence of failure.
  Future<bool> roomReceiptEverFrom({
    required String readerProfileId,
    DatabaseExecutor? txn,
  }) async {
    final reader = readerProfileId.trim();
    if (reader.isEmpty) return false;
    final rows = await (txn ?? _db).query(
      'room_message_receipts',
      columns: ['reader_profile_id'],
      where: 'reader_profile_id = ?',
      whereArgs: [reader],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Drops EVERY delivery record for the room — used on rotation, where the
  /// new generation is owed to everyone. Keeping stale rows would leave members
  /// marked up to date for a key they were never given.
  Future<void> roomKeyDeliveryClear({
    required String roomId,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).delete(
      'room_key_delivery',
      where: 'room_id = ?',
      whereArgs: [roomId],
    );
  }

  /// Drops the delivery record for a device — a removed member, or one whose
  /// device is gone. The next generation is then owed to them from scratch if
  /// they ever come back.
  Future<void> roomKeyDeliveryForget({
    required String roomId,
    required String peerDeviceId,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).delete(
      'room_key_delivery',
      where: 'room_id = ? AND peer_device_id = ?',
      whereArgs: [roomId, peerDeviceId],
    );
  }

  /// The membership the current generation was keyed for. Comparing this with
  /// live membership is what DETECTS that someone joined or left, which is the
  /// trigger to rotate.
  Future<List<String>> roomMemberSnapshotGet({
    required String roomId,
    DatabaseExecutor? txn,
  }) async {
    final rows = await (txn ?? _db).query(
      'room_member_snapshot',
      columns: ['device_ids_csv'],
      where: 'room_id = ?',
      whereArgs: [roomId],
      limit: 1,
    );
    if (rows.isEmpty) return const <String>[];
    final csv = (rows.first['device_ids_csv'] as String?) ?? '';
    return csv.split(',').where((e) => e.isNotEmpty).toList(growable: false);
  }

  /// Stored SORTED and de-duplicated so "did membership change?" is a string
  /// compare that cannot be fooled by the server returning the same members in
  /// a different order — which would otherwise rotate the key on every sync.
  Future<void> roomMemberSnapshotPut({
    required String roomId,
    required Iterable<String> deviceIds,
    required int updatedAtMs,
    DatabaseExecutor? txn,
  }) async {
    final sorted =
        deviceIds
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && !e.contains(','))
            .toSet()
            .toList()
          ..sort();
    await (txn ?? _db).insert('room_member_snapshot', {
      'room_id': roomId,
      'device_ids_csv': sorted.join(','),
      'updated_at_ms': updatedAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Upserts a contact's device bundle. Returns `true` when the peer's pinned
  /// identity key CHANGED and was accepted (an identity rotation — only possible
  /// when [allowIdentityRotation] is set).
  ///
  /// By default ([allowIdentityRotation] == false) an identity change is fail-
  /// CLOSED: the old session is torn down and a StateError is thrown so the
  /// caller treats it as suspicious (the historical, pinned behaviour). When the
  /// new identity comes from the AUTHENTICATED keys server (the source of truth
  /// for a profile_id), the caller may pass [allowIdentityRotation] = true to
  /// ACCEPT the rotation instead — a contact reinstalled/recreated under the
  /// same Secretly ID. Acceptance always (a) clears `verified_at_ms` (so a
  /// `blockUnverified` user is re-gated until they re-verify) and (b) drops the
  /// old ratchet session so a fresh X3DH runs against the new identity. The
  /// caller is responsible for surfacing a visible "safety number changed"
  /// warning — acceptance is never silent.
  /// Returns which kind of change this upsert applied:
  /// - [identityRotated]: the SAME device_id re-appeared under a different
  ///   identity key (classic reinstall-reusing-id) — verification was reset
  ///   and the session dropped;
  /// - [insertedNewDevice]: a device_id we had never seen for this contact —
  ///   under И-1 a rotation looks exactly like this (new id, fresh identity),
  ///   so the CALLER decides whether it warrants the safety-number notice
  ///   (known contact + not first discovery + not self).
  Future<({bool identityRotated, bool insertedNewDevice})> contactDeviceUpsert({
    required String profileId,
    required String deviceId,
    required String identityKeyPubB64,
    required String signedPrekeyPubB64,
    required String signedPrekeySigB64,
    bool allowIdentityRotation = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.query(
      'contact_devices',
      columns: [
        'identity_key_pub_b64',
        'signed_prekey_pub_b64',
        'verified_at_ms',
        'approved_at_ms',
      ],
      where: 'contact_profile_id = ? AND device_id = ?',
      whereArgs: [profileId, deviceId],
      limit: 1,
    );

    int? verifiedAtMs;
    int? approvedAtMs;
    var shouldResetSessions = false;
    var identityRotated = false;
    if (existing.isNotEmpty) {
      verifiedAtMs = (existing.first['verified_at_ms'] as num?)?.toInt();
      // 🔴 Переносится вручную вместе с verified_at_ms, потому что вставка ниже
      // идёт через ConflictAlgorithm.replace: строка удаляется и создаётся
      // заново, и всё, что здесь не перечислено, ПРОПАДАЁТ. Обновление связки
      // ключей происходит постоянно — потеря отметки означала бы, что
      // «отправить всё равно» приходится нажимать снова и снова.
      approvedAtMs = (existing.first['approved_at_ms'] as num?)?.toInt();
      final prevIdentity = existing.first['identity_key_pub_b64'] as String?;
      if (prevIdentity != null && prevIdentity != identityKeyPubB64) {
        // Identity changed. Always reset verification + tear down the session.
        await _db.update(
          'contact_devices',
          {
            'verified_at_ms': null,
            'approved_at_ms': null,
            'updated_at_ms': now,
          },
          where: 'contact_profile_id = ? AND device_id = ?',
          whereArgs: [profileId, deviceId],
        );
        await sessionDelete(deviceId);
        await _archiveSessionV3BeforeDelete(deviceId);
        await sessionV3Delete(deviceId);
        if (!allowIdentityRotation) {
          throw StateError(
            'peer identity key changed for profile=$profileId device=$deviceId',
          );
        }
        // Server-confirmed rotation: accept the new identity, stay unverified.
        verifiedAtMs = null;
        // 🔴 И отметка «отправлять всё равно» тоже снимается. Она выдана
        // КОНКРЕТНОМУ ключу, а не устройству: перенести её на новый ключ
        // значило бы, что одно нажатие когда-то в прошлом навсегда выключает
        // предупреждение о подмене на этом устройстве.
        approvedAtMs = null;
        identityRotated = true;
      }

      final prevSignedPrekey =
          existing.first['signed_prekey_pub_b64'] as String?;
      if (prevSignedPrekey != null && prevSignedPrekey != signedPrekeyPubB64) {
        shouldResetSessions = true;
      }
    }

    await _db.insert('contact_devices', {
      'contact_profile_id': profileId,
      'device_id': deviceId,
      'identity_key_pub_b64': identityKeyPubB64,
      'signed_prekey_pub_b64': signedPrekeyPubB64,
      'signed_prekey_sig_b64': signedPrekeySigB64,
      'updated_at_ms': now,
      'verified_at_ms': verifiedAtMs,
      'approved_at_ms': approvedAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    if (shouldResetSessions) {
      await sessionDelete(deviceId);
      await _archiveSessionV3BeforeDelete(deviceId);
      await sessionV3Delete(deviceId);
    }
    return (
      identityRotated: identityRotated,
      insertedNewDevice: existing.isEmpty,
    );
  }

  Future<void> contactDevicesDeleteMissing({
    required String profileId,
    required Iterable<String> keepDeviceIds,
    // И-4h (cause C1): when false, prune the device from the local targeting
    // cache but KEEP its ratchet session, so an idle companion that merely fell
    // out of the keys server's 14-day relative liveness window does NOT force a
    // fresh X3DH + "safety number changed" when it returns. A genuinely
    // reinstalled device still resets via the authoritative identity-rotation
    // path. Default true preserves the legacy raw-delete.
    bool deleteSessions = true,
  }) async {
    final keep = keepDeviceIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final rows = await _db.query(
      'contact_devices',
      columns: ['device_id'],
      where: 'contact_profile_id = ?',
      whereArgs: [profileId],
    );

    for (final row in rows) {
      final deviceId = (row['device_id'] as String?)?.trim() ?? '';
      if (deviceId.isEmpty || keep.contains(deviceId)) continue;
      await _db.delete(
        'contact_devices',
        where: 'contact_profile_id = ? AND device_id = ?',
        whereArgs: [profileId, deviceId],
      );
      if (deleteSessions) {
        await sessionDelete(deviceId);
        await sessionV3Delete(deviceId);
      }
    }
  }

  /// Профиль контакта по идентификатору его УСТРОЙСТВА.
  ///
  /// 🔴 ЗАЧЕМ (Ш-1 ТЗ входящего звонка, 13.08.2026). Пуш звонка несёт устройство
  /// звонящего, но не его профиль. Без обратного поиска интерфейс показывал бы
  /// «неизвестно» — дефект, который я уже допустил 12.08 и который владелец
  /// увидел сразу.
  Future<String?> contactProfileIdByDeviceId(String deviceId) async {
    final cleaned = deviceId.trim();
    if (cleaned.isEmpty) return null;
    final rows = await _db.query(
      'contact_devices',
      columns: ['contact_profile_id'],
      where: 'device_id = ?',
      whereArgs: [cleaned],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final pid = ((rows.first['contact_profile_id'] as String?) ?? '').trim();
    return pid.isEmpty ? null : pid;
  }

  Future<List<Map<String, Object?>>> contactDevicesList(
    String profileId,
  ) async {
    return _db.query(
      'contact_devices',
      where: 'contact_profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'device_id ASC',
    );
  }

  /// FIX (2026-07-13, sender-side session convergence): the 1:1 conversations
  /// that have at least [minCount] of MY outbound messages stuck at `'sent'` —
  /// relay-ACKed but with NO end-to-end `'delivered'` receipt — created before
  /// [stuckBeforeMs]. A silently-desynced session (the recipient cannot decrypt)
  /// surfaces here: my messages go `'sent'` and never advance to `'delivered'`
  /// because no delivered-receipt ever comes back. Groups (`group:`) and pending
  /// requests (`req:`) are excluded, so each returned convo_id IS a peer profile
  /// id. Pure read; no migration.
  Future<List<String>> convoIdsWithUndeliveredSends({
    required int stuckBeforeMs,
    required int minCount,
  }) async {
    final rows = await _db.rawQuery(
      // COALESCE(scheduled_at_ms, created_at_ms) — FIX 2026-07-30. A "send
      // later" wire the relay is still HOLDING sits at local_state='sent' the
      // moment it is uploaded (markScheduledDirectUploaded), while its
      // created_at_ms is when it was composed. Matching on created_at_ms alone
      // made a perfectly healthy scheduled message look stuck after 90 seconds
      // (minCount is 1), and the backstop answered by force-resetting the
      // session with a peer whose session was fine — the exact class of
      // needless proactive reset that И-4 exists to eliminate. The resend query
      // already carried this guard; the DETECTOR did not.
      "SELECT convo_id, COUNT(*) AS c FROM events "
      "WHERE local_state = 'sent' "
      "AND COALESCE(scheduled_at_ms, created_at_ms) < ? "
      "AND convo_id NOT LIKE 'group:%' AND convo_id NOT LIKE 'req:%' "
      "GROUP BY convo_id HAVING c >= ?",
      [stuckBeforeMs, minCount],
    );
    return rows
        .map((r) => (r['convo_id'] as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// ROOM counterpart of [convoIdsWithUndeliveredSends]: `group:` conversations
  /// whose messages are still `'sent'` — relay-ACKed but with NO end-to-end
  /// delivered receipt from ANYONE.
  ///
  /// Note what this can and cannot see. A room message flips to `'delivered'`
  /// as soon as the FIRST member acknowledges it, so this finds only the
  /// "nobody in the room received it" case — a genuinely broken room. It cannot
  /// find "9 of 10 members missed it"; that needs per-member evidence from
  /// `room_message_receipts` and is deliberately left to a later step. The
  /// upside is that this query cannot mistake a partially-delivered room for a
  /// broken one, so it can never drive a resend storm.
  Future<List<String>> roomIdsWithUndeliveredSends({
    required int stuckBeforeMs,
    required int minCount,
  }) async {
    final rows = await _db.rawQuery(
      // Same COALESCE guard as the 1:1 detector, for the same reason: a room
      // message scheduled for later is still HELD by the relay and must not be
      // read as evidence that the room is broken.
      "SELECT convo_id, COUNT(*) AS c FROM events "
      "WHERE local_state = 'sent' "
      "AND COALESCE(scheduled_at_ms, created_at_ms) < ? "
      "AND convo_id LIKE 'group:%' "
      "GROUP BY convo_id HAVING c >= ?",
      [stuckBeforeMs, minCount],
    );
    return rows
        .map((r) => (r['convo_id'] as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// The individual 1:1 message events still stuck at `'sent'` (relay-acked but
  /// never earned an end-to-end 'delivered' receipt) in [convoId], oldest first.
  /// Drives the auto-resend (TZ §20 pillar 5): after the session with this peer
  /// is re-keyed, each is re-encrypted under the fresh session and re-sent —
  /// idempotent because the receiver dedups by the payload's event id
  /// (insertEvent uses INSERT-OR-IGNORE on event_id). Once the peer finally
  /// decrypts + persists one, its delivered-receipt flips the row to
  /// `'delivered'` and it drops out of this query, so the resend self-terminates.
  Future<List<Map<String, Object?>>> undeliveredDirectSentEvents({
    required String convoId,
    required int stuckBeforeMs,
    int limit = 50,
  }) async {
    return _db.query(
      'events',
      columns: ['event_id', 'payload_event_id', 'created_at_ms'],
      // TZ Epic A3 (2026-07-18): attachments and stickers are user content
      // too — a desync must not lose them. (Was `type = 'msg'` only; the
      // resender skips attachment rows whose blob has already expired on the
      // relay — those need the E4 re-share path instead.)
      //
      // SCHEDULED SAFETY (2026-07-21, field report): a "send later" message is
      // stored with created_at_ms = COMPOSE time (so it sorts correctly) and is
      // flipped to `sent` the moment the relay accepts it for holding — while
      // the relay still holds it until scheduled_at_ms. Matching on
      // created_at_ms alone therefore made a still-held scheduled wire look
      // "sent but never receipted = stuck", and the convergence/rotation resend
      // pushed it out IMMEDIATELY — releasing it early (a tester's 6:25 message
      // arrived at 6:10, right when a device rotation kicked the resend sweep).
      // A scheduled row's effective send time is its scheduled time, so use
      // that: not-yet-due schedules are invisible to the resender, and once due
      // they get the same stuck-backstop as any other message.
      where:
          "convo_id = ? AND local_state = 'sent' "
          "AND COALESCE(scheduled_at_ms, created_at_ms) < ? "
          "AND type IN ('msg','att','sticker')",
      whereArgs: [convoId, stuckBeforeMs],
      orderBy: 'created_at_ms ASC, rowid ASC',
      limit: limit,
    );
  }

  /// Rooms this device posted to in a bounded recent window — the candidate set
  /// for the per-member receipt check. Bounded on BOTH ends on purpose: newer
  /// than the stuck window would flag messages still in flight, and older than
  /// the lookback is history nobody is waiting on, so the sweep stays cheap.
  Future<List<String>> roomIdsWithRecentSends({
    required String senderDeviceId,
    required int stuckBeforeMs,
    required int notOlderThanMs,
    int limit = 30,
  }) async {
    final rows = await _db.rawQuery(
      "SELECT DISTINCT convo_id FROM events "
      "WHERE convo_id LIKE 'group:%' AND sender_device_id = ? "
      "AND COALESCE(scheduled_at_ms, created_at_ms) < ? "
      "AND COALESCE(scheduled_at_ms, created_at_ms) > ? "
      "AND type IN ('msg','att','sticker') LIMIT ?",
      [senderDeviceId, stuckBeforeMs, notOlderThanMs, limit],
    );
    return rows
        .map((r) => (r['convo_id'] as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// My room messages that a SPECIFIC member has never acknowledged.
  ///
  /// Why this exists: a room message flips to `'delivered'` the moment the
  /// FIRST member acknowledges, so `roomIdsWithUndeliveredSends` can only see
  /// "nobody got it". The far more common failure is "one member's session
  /// broke and everyone else is fine" — invisible to local_state, but plainly
  /// visible in `room_message_receipts`, which records an ack per reader.
  ///
  /// Carries over every guard from [undeliveredDirectSentEvents], deliberately:
  ///  * `COALESCE(scheduled_at_ms, created_at_ms)` — a "send later" wire the
  ///    relay is still holding must NOT look stuck, or the resend releases it
  ///    early (field report 2026-07-21: a 6:25 message went out at 6:10);
  ///  * only user content (`msg`/`att`/`sticker`);
  ///  * oldest first, bounded.
  ///
  /// [senderDeviceId] is MY device: only messages this device sent can be
  /// re-encrypted here, because only their plaintext is stored locally.
  /// Возможности устройства, как оно само их назвало в последнем сообщении.
  Future<void> deviceCapsPut({
    required String deviceId,
    required List<String> caps,
    required int nowMs,
  }) async {
    final id = deviceId.trim();
    if (id.isEmpty) return;
    try {
      await _db.insert('device_caps', {
        'device_id': id,
        'caps': (caps.toSet().toList()..sort()).join(','),
        'updated_at_ms': nowMs,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  /// Какие из [deviceIds] заявили возможность [cap].
  Future<Set<String>> deviceIdsWithCap({
    required Iterable<String> deviceIds,
    required String cap,
  }) async {
    final ids = deviceIds.map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
    if (ids.isEmpty) return const <String>{};
    final out = <String>{};
    try {
      for (final chunk in AppDb.chunkIds(ids)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = await _db.rawQuery(
          'SELECT device_id, caps FROM device_caps WHERE device_id IN ($placeholders)',
          chunk,
        );
        for (final row in rows) {
          final caps = ((row['caps'] as String?) ?? '').split(',');
          if (caps.contains(cap)) out.add(row['device_id'] as String);
        }
      }
    } catch (_) {}
    return out;
  }

  /// К-3: запомнить конверт отправленного сообщения комнаты.
  /// К-3 выключен: сохранённые конверты (в них открытый текст) и отметки
  /// повторов больше не нужны.
  Future<void> roomOutboundEnvelopesClear() async {
    await _db.delete('room_outbound_envelopes');
    await _db.delete('room_outbound_resends');
  }

  Future<void> roomOutboundEnvelopePut({
    required String payloadEventId,
    required String roomId,
    required String envelope,
    required int createdAtMs,
  }) async {
    if (payloadEventId.trim().isEmpty || envelope.isEmpty) return;
    try {
      await _db.insert('room_outbound_envelopes', {
        'payload_event_id': payloadEventId.trim(),
        'room_id': roomId,
        'envelope': envelope,
        'created_at_ms': createdAtMs,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (_) {
      // Не повод ронять отправку: без конверта просто не будет повтора.
    }
  }

  Future<String?> roomOutboundEnvelopeGet(String payloadEventId) async {
    final rows = await _db.query(
      'room_outbound_envelopes',
      columns: ['envelope'],
      where: 'payload_event_id = ?',
      whereArgs: [payloadEventId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['envelope'] as String?;
  }

  /// К-3: повторяли ли [payloadEventId] участнику [memberProfileId].
  Future<bool> roomOutboundWasResent({
    required String payloadEventId,
    required String memberProfileId,
  }) async {
    final rows = await _db.query(
      'room_outbound_resends',
      columns: ['resent_at_ms'],
      where: 'payload_event_id = ? AND member_profile_id = ?',
      whereArgs: [payloadEventId, memberProfileId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> roomOutboundMarkResent({
    required String payloadEventId,
    required String memberProfileId,
    required int atMs,
  }) async {
    await _db.insert('room_outbound_resends', {
      'payload_event_id': payloadEventId,
      'member_profile_id': memberProfileId,
      'resent_at_ms': atMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Конверты старше срока жизни очереди реле больше никому не помогут.
  Future<void> roomOutboundPrune({required int olderThanMs}) async {
    try {
      await _db.delete(
        'room_outbound_resends',
        where:
            'payload_event_id IN (SELECT payload_event_id FROM room_outbound_envelopes WHERE created_at_ms < ?)',
        whereArgs: [olderThanMs],
      );
      await _db.delete(
        'room_outbound_envelopes',
        where: 'created_at_ms < ?',
        whereArgs: [olderThanMs],
      );
    } catch (_) {}
  }

  Future<List<Map<String, Object?>>> roomSendsMissingReceiptFrom({
    required String roomId,
    required String readerProfileId,
    required String senderDeviceId,
    required int stuckBeforeMs,
    int limit = 20,
  }) async {
    return _db.rawQuery(
      "SELECT e.event_id, e.payload_event_id, e.created_at_ms FROM events e "
      "WHERE e.convo_id = ? AND e.sender_device_id = ? "
      "AND COALESCE(e.scheduled_at_ms, e.created_at_ms) < ? "
      "AND e.type IN ('msg','att','sticker') "
      "AND e.payload_event_id IS NOT NULL AND e.payload_event_id <> '' "
      "AND NOT EXISTS ("
      "  SELECT 1 FROM room_message_receipts r "
      "  WHERE r.payload_event_id = e.payload_event_id "
      "  AND r.reader_profile_id = ?"
      ") "
      "ORDER BY e.created_at_ms ASC, e.rowid ASC LIMIT ?",
      [roomId, senderDeviceId, stuckBeforeMs, readerProfileId, limit],
    );
  }

  /// Relay-blob expiry for [blobId] (0 = unknown), for the resend gate: an
  /// attachment whose blob TTL has passed cannot be re-fetched by the peer, so
  /// re-sending its event would render a permanently-broken bubble.
  Future<int> attachmentExpiresAtMs(String blobId) async {
    final rows = await _db.query(
      'attachments',
      columns: ['expires_at_ms'],
      where: 'blob_id = ?',
      whereArgs: [blobId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['expires_at_ms'] as num?)?.toInt() ?? 0;
  }

  /// Wall-clock ms of the most recent INBOUND event in [convoId] (a message we
  /// received from the peer), or 0 if none. Used by the sender-side convergence
  /// backstop to confirm the peer is ALIVE — so a run of undelivered sends means
  /// a broken session (re-key it), not merely an offline peer (let the relay
  /// redeliver-until-ACK deliver when they wake).
  Future<int> latestInboundAtMs(String convoId) async {
    final rows = await _db.rawQuery(
      "SELECT MAX(created_at_ms) AS m FROM events "
      "WHERE convo_id = ? AND local_state = 'received'",
      [convoId],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['m'] as num?)?.toInt() ?? 0;
  }

  Future<void> contactDeviceMarkVerified({
    required String profileId,
    required String deviceId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE contact_devices SET verified_at_ms = ? WHERE contact_profile_id = ? AND device_id = ?',
      [now, profileId, deviceId],
    );
    // Отметка на уровне контакта, которая НЕ снимается при смене ключей: она
    // отвечает не на «проверено ли сейчас», а на «проверял ли этот человек
    // когда-нибудь». Только по ней и решается, стоит ли вообще беспокоить
    // предупреждением, когда номер сменится.
    // 🔴 ОБНОВИТЬ, а если строки нет — ВСТАВИТЬ. Раньше здесь стоял
    // `insert(..., ConflictAlgorithm.ignore)`, и это было верно, пока строка в
    // таблице могла появиться ТОЛЬКО отсюда. С v64 её создаёт ещё и закрепление
    // ключа аккаунта (`contactAccountIdentityPinIfAbsent`) — а `ignore` при уже
    // существующей строке не делает НИЧЕГО, то есть настоящая проверка контакта
    // молча не записалась бы. Человек сверил код, нажал «проверено», и отметка
    // не встала.
    final updated = await _db.rawUpdate(
      'UPDATE contact_verification SET verified_ever_at_ms = ? WHERE contact_profile_id = ?',
      [now, profileId],
    );
    if (updated == 0) {
      await _db.insert('contact_verification', {
        'contact_profile_id': profileId,
        'verified_ever_at_ms': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// «Отправить всё равно»: ключ признан пригодным без сверки кода.
  ///
  /// Снимается при смене ключа (см. [contactDeviceUpsert]) — отметка выдана
  /// конкретному ключу, а не устройству навсегда.
  Future<void> contactDeviceMarkApproved({
    required String profileId,
    required String deviceId,
  }) async {
    await _db.rawUpdate(
      'UPDATE contact_devices SET approved_at_ms = ? '
      'WHERE contact_profile_id = ? AND device_id = ?',
      [DateTime.now().millisecondsSinceEpoch, profileId, deviceId],
    );
  }

  /// Надгробия удалений: что человек удалил и когда.
  ///
  /// Живут ВНЕ снимка копии. Восстановление заменяет таблицы снимком целиком,
  /// и попади надгробия туда — местная память об удалениях была бы затёрта
  /// ровно тогда, когда она нужна.
  Future<List<Map<String, Object?>>> deletionsList() async {
    return _db.query('deletions', orderBy: 'deleted_at_ms ASC');
  }

  Future<void> deletionsPut({
    required String kind,
    required String targetId,
    required int deletedAtMs,
  }) async {
    final k = kind.trim();
    final id = targetId.trim();
    if (k.isEmpty || id.isEmpty) return;
    await _db.insert('deletions', {
      'kind': k,
      'target_id': id,
      'deleted_at_ms': deletedAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Применяет надгробия к тому, что только что приехало из копии.
  ///
  /// Возвращает число снятых чатов. Порядок в восстановлении обязателен:
  /// сначала снимок, потом это — иначе снимок вернёт удалённое поверх.
  Future<int> applyDeletionTombstones() async {
    final rows = await _db.query(
      'deletions',
      columns: ['kind', 'target_id'],
      where: 'kind = ?',
      whereArgs: ['convo'],
    );
    var removed = 0;
    for (final row in rows) {
      final convoId = ((row['target_id'] as String?) ?? '').trim();
      if (convoId.isEmpty) continue;
      final had = await _db.query(
        'conversations',
        columns: ['convo_id'],
        where: 'convo_id = ?',
        whereArgs: [convoId],
        limit: 1,
      );
      final hadEvents = await _db.rawQuery(
        'SELECT 1 FROM events WHERE convo_id = ? LIMIT 1',
        [convoId],
      );
      if (had.isEmpty && hadEvents.isEmpty) continue;
      // 🔴 ОЧЕРЕДЬ ОТПРАВКИ СНИМАЕТСЯ ПЕРВОЙ, И ПОРЯДОК ЗДЕСЬ ОБЯЗАТЕЛЕН
      // (26.08.2026, MSG-01).
      //
      // Раньше функция чистила события, реакции и сам чат — а конверты в
      // очереди оставляла. Следствие хуже, чем недоставка: чат, помеченный
      // удалённым, уходит с экрана, но его неотправленные конверты ПРОДОЛЖАЮТ
      // УХОДИТЬ собеседнику. Человек уверен, что переписки нет; сообщение всё
      // равно придёт.
      //
      // Подзапрос обязан отработать ДО удаления событий: после него
      // `SELECT event_id FROM events WHERE convo_id = ?` уже пуст, и очередь
      // осталась бы нетронутой — то есть правка стала бы молча бесполезной.
      //
      // Соседние `deleteConversationData`, `clearConversationHistoryUpTo`,
      // `pruneConversationEventsOlderThan` и `deleteRoomLocalData` делают ровно
      // это; расхождение было недосмотром, а не замыслом.
      await _db.rawDelete(
        'DELETE FROM outbox WHERE event_id_ref IN '
        '(SELECT event_id FROM events WHERE convo_id = ?)',
        [convoId],
      );
      await _db.delete('events', where: 'convo_id = ?', whereArgs: [convoId]);
      await _db.delete(
        'message_reactions',
        where: 'convo_id = ?',
        whereArgs: [convoId],
      );
      await _db.delete(
        'conversations',
        where: 'convo_id = ?',
        whereArgs: [convoId],
      );
      removed++;
    }
    return removed;
  }

  /// Закреплённый ключ личности аккаунта контакта, или `null` если его ещё нет.
  /// Ключи постоянных счётчиков наблюдения за слоем 2.
  ///
  /// 🔴 ЗАЧЕМ ПОСТОЯННЫЕ, А НЕ ЖУРНАЛ. Ш-3 нельзя включать, не зная, какая доля
  /// собеседников предъявляет верный сертификат. Измерять это предлагалось
  /// событиями `account_cert_ok` — а они живут только в журнале устройства, а он
  /// кольцевой. 12.08.2026 это оказался ТРЕТИЙ неизмеримый гейт за день, и
  /// правило выведено: гейт, выраженный через событие журнала, — не гейт.
  static const String kvAcctCertOk = 'acct_cert_ok';
  static const String kvAcctCertBad = 'acct_cert_bad';
  static const String kvAcctCertAbsent = 'acct_cert_absent';
  static const String kvAcctKeyChanged = 'acct_key_changed';

  /// Доля готовности к Ш-3: у скольких контактов закреплён ключ личности.
  ///
  /// Закрепление ставится только когда контакт прислал И ключ, И сертификат
  /// (см. `_observeAccountCertificate`), поэтому «закреплён» и означает «его
  /// сборка умеет слой 2». Считать ничего не надо — это уже записано.
  Future<({int contacts, int pinned})> accountIdentityReadinessStats() async {
    final total = await _db.rawQuery('SELECT COUNT(*) AS n FROM contacts');
    final pinned = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM contact_verification '
      "WHERE account_identity_pub_b64 IS NOT NULL "
      "AND TRIM(account_identity_pub_b64) <> ''",
    );
    int read(List<Map<String, Object?>> rows) =>
        (rows.isEmpty ? 0 : (rows.first['n'] as num?)?.toInt() ?? 0);
    return (contacts: read(total), pinned: read(pinned));
  }

  Future<String?> contactAccountIdentityPinned(String profileId) async {
    final rows = await _db.query(
      'contact_verification',
      columns: ['account_identity_pub_b64'],
      where: 'contact_profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = (rows.first['account_identity_pub_b64'] as String?)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Закрепляет ключ личности аккаунта контакта при ПЕРВОМ знакомстве.
  ///
  /// Возвращает `true`, только если запись действительно появилась.
  ///
  /// 🔴 НИКОГДА не перезаписывает уже закреплённый ключ, даже другим значением
  /// (К-6). Ключ аккаунта отдаёт СЕРВЕР, и молчаливое обновление означало бы, что
  /// сервер в любой момент может подменить личность человека, а вместе с ней и
  /// номер безопасности, — то есть уничтожить ровно ту защиту, ради которой номер
  /// существует. Расхождение обязано подниматься наверх как событие «номер
  /// изменился» и решаться человеком, а не тихо приниматься здесь.
  ///
  /// Ровно поэтому у метода нет параметра «перезаписать»: соблазн добавить его
  /// возникнет при первом же ложном расхождении в поле, и это будет ошибкой.
  Future<bool> contactAccountIdentityPinIfAbsent({
    required String profileId,
    required String accountIdentityPubB64,
  }) async {
    final key = accountIdentityPubB64.trim();
    if (profileId.trim().isEmpty || key.isEmpty) return false;
    final existing = await contactAccountIdentityPinned(profileId);
    if (existing != null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    // 🔴 Строка может уже существовать из слоя 1 (человек проверял контакт), и
    // трогать её `insert` с заменой нельзя — стёрся бы `verified_ever_at_ms`,
    // то есть проверка слетела бы молча. Тот же капкан, из-за которого проверка
    // изначально вынесена в отдельную таблицу.
    final updated = await _db.update(
      'contact_verification',
      <String, Object?>{
        'account_identity_pub_b64': key,
        'account_identity_pinned_at_ms': now,
      },
      where: 'contact_profile_id = ?',
      whereArgs: [profileId],
    );
    if (updated > 0) return true;

    // Строки не было — заводим, не притворяясь, что человек кого-то проверял.
    //
    // 🔴 `verified_ever_at_ms = 0` значит именно «НИКОГДА», и ради этого нуля
    // пришлось поправить два места: `contactWasEverVerified` смотрел на НАЛИЧИЕ
    // строки (объявил бы контакт проверенным и запер переписку), а
    // `contactDeviceMarkVerified` вставлял через `ConflictAlgorithm.ignore` (при
    // уже существующей строке настоящая проверка молча не записалась бы). Ставить
    // здесь отметку временем было бы ещё хуже: это прямая ложь о проверке,
    // которой не было.
    await _db.insert('contact_verification', <String, Object?>{
      'contact_profile_id': profileId,
      'verified_ever_at_ms': 0,
      'account_identity_pub_b64': key,
      'account_identity_pinned_at_ms': now,
    });
    return true;
  }

  /// Проверял ли пользователь этого человека хоть раз.
  ///
  /// 🔴 Смотрит на ЗНАЧЕНИЕ, а не на наличие строки. Раньше здесь стояло
  /// `rows.isNotEmpty`, и это было верно, пока строку заводила только сама
  /// проверка. С v64 её создаёт ещё и закрепление ключа аккаунта
  /// (`contactAccountIdentityPinIfAbsent`) — и проверка по наличию объявила бы
  /// проверенным человека, которого никто не проверял. Гейт отправки запер бы
  /// переписку с ним, то есть вернулась бы ровно та болезнь, которую лечил
  /// слой 1.
  ///
  /// Тот же класс, что и все сегодняшние камни: утверждение «строка есть =
  /// проверено» было правдой и перестало ею быть, когда у таблицы появился
  /// второй писатель.
  Future<bool> contactWasEverVerified(String profileId) async {
    final rows = await _db.query(
      'contact_verification',
      columns: ['verified_ever_at_ms'],
      where: 'contact_profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return ((rows.first['verified_ever_at_ms'] as num?)?.toInt() ?? 0) > 0;
  }

  Future<void> contactUpsert({
    required String profileId,
    String? displayName,
    bool? displayNameIsCustom,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.query(
      'contacts',
      columns: [
        'created_at_ms',
        'avatar_path',
        'contact_emoji',
        'display_name_is_custom',
      ],
      where: 'contact_profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    final existingDisplayNameIsCustom =
        ((existing.isNotEmpty ? existing.first['display_name_is_custom'] : null)
                as num?)
            ?.toInt() ??
        0;
    await _db.insert('contacts', {
      'contact_profile_id': profileId,
      'display_name': displayName,
      'display_name_is_custom': displayNameIsCustom == null
          ? existingDisplayNameIsCustom
          : (displayNameIsCustom ? 1 : 0),
      'avatar_path': existing.isNotEmpty ? existing.first['avatar_path'] : null,
      'contact_emoji': existing.isNotEmpty
          ? existing.first['contact_emoji']
          : null,
      'created_at_ms': existing.isNotEmpty
          ? existing.first['created_at_ms']
          : now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> contactSetAvatarPath({
    required String profileId,
    required String? avatarPath,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'contacts',
      {'avatar_path': avatarPath, 'updated_at_ms': now},
      where: 'contact_profile_id = ?',
      whereArgs: [profileId],
    );
  }

  Future<void> contactSetEmoji({
    required String profileId,
    required String? emoji,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'contacts',
      {
        'contact_emoji': (emoji == null || emoji.trim().isEmpty)
            ? null
            : emoji.trim(),
        'updated_at_ms': now,
      },
      where: 'contact_profile_id = ?',
      whereArgs: [profileId],
    );
  }

  Future<List<Map<String, Object?>>> contactsList({int limit = 500}) {
    return _db.query('contacts', orderBy: 'updated_at_ms DESC', limit: limit);
  }

  Future<Map<String, Object?>?> contactGet(String profileId) async {
    final rows = await _db.query(
      'contacts',
      where: 'contact_profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, Map<String, Object?>>> contactsGetForProfiles(
    List<String> profileIds,
  ) async {
    if (profileIds.isEmpty) return const <String, Map<String, Object?>>{};
    final out = <String, Map<String, Object?>>{};
    for (final chunk in AppDb.chunkIds(profileIds)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _db.rawQuery(
        'SELECT * FROM contacts WHERE contact_profile_id IN ($placeholders)',
        chunk,
      );
      for (final row in rows) {
        final profileId = row['contact_profile_id'] as String?;
        if (profileId == null || profileId.isEmpty) continue;
        out[profileId] = row;
      }
    }
    return out;
  }

  Future<void> contactDelete(String profileId) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'contact_devices',
        where: 'contact_profile_id = ?',
        whereArgs: [profileId],
      );
      await txn.delete(
        'contacts',
        where: 'contact_profile_id = ?',
        whereArgs: [profileId],
      );
    });
  }

  Future<Map<String, Object?>?> profileMetaGet(String profileId) async {
    final rows = await _db.query(
      'profile_meta',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, Map<String, Object?>>> profileMetaGetForProfiles(
    List<String> profileIds,
  ) async {
    if (profileIds.isEmpty) return const <String, Map<String, Object?>>{};
    // Порциями: `listContacts` зовёт этот метод со ВСЕМИ контактами разом
    // (см. комментарий на его стороне про «large contact books»), поэтому
    // предел параметров достигается у человека с большой книгой контактов.
    final out = <String, Map<String, Object?>>{};
    for (final chunk in AppDb.chunkIds(profileIds)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _db.rawQuery(
        'SELECT * FROM profile_meta WHERE profile_id IN ($placeholders)',
        chunk,
      );
      for (final row in rows) {
        final profileId = row['profile_id'] as String?;
        if (profileId == null || profileId.isEmpty) continue;
        out[profileId] = row;
      }
    }
    return out;
  }

  Future<void> profileMetaUpsert({
    required String profileId,
    required String? nickname,
    required String? avatarPath,
    required String? bio,
    required String? privacyAudienceJson,
    required int updatedAtMs,
    String? frameId,
    String? coverId,
    String? coverPath,
    String? emojiStatus,
    String? premiumBadge,
  }) async {
    // Cosmetic (unsigned) fields. Callers that don't manage cosmetics pass null;
    // in that case preserve whatever is already stored instead of clobbering it,
    // since this upsert does a full-row REPLACE. Pass '' to explicitly clear.
    String? resolvedFrameId = frameId;
    String? resolvedCoverId = coverId;
    String? resolvedCoverPath = coverPath;
    String? resolvedEmojiStatus = emojiStatus;
    String? resolvedPremiumBadge = premiumBadge;
    // Always read the existing row: this upsert does a full-row REPLACE, so
    // last_seen_at_ms (NOT in the insert map) would be wiped on every meta
    // refresh unless carried forward. Cosmetic fields passed as null are also
    // preserved (callers that don't manage cosmetics pass null; '' clears).
    int? preservedLastSeenAtMs;
    {
      final existing = await _db.query(
        'profile_meta',
        columns: [
          'frame_id',
          'cover_id',
          'cover_path',
          'emoji_status',
          'premium_badge',
          'last_seen_at_ms',
        ],
        where: 'profile_id = ?',
        whereArgs: [profileId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        resolvedFrameId ??= existing.first['frame_id'] as String?;
        resolvedCoverId ??= existing.first['cover_id'] as String?;
        resolvedCoverPath ??= existing.first['cover_path'] as String?;
        resolvedEmojiStatus ??= existing.first['emoji_status'] as String?;
        resolvedPremiumBadge ??= existing.first['premium_badge'] as String?;
        preservedLastSeenAtMs =
            (existing.first['last_seen_at_ms'] as num?)?.toInt();
      }
    }
    await _db.insert('profile_meta', {
      'profile_id': profileId,
      'nickname': nickname,
      'avatar_path': avatarPath,
      'bio': bio,
      'privacy_audience_json': privacyAudienceJson,
      'frame_id': resolvedFrameId,
      'cover_id': resolvedCoverId,
      'cover_path': resolvedCoverPath,
      'emoji_status': resolvedEmojiStatus,
      'premium_badge': resolvedPremiumBadge,
      'last_seen_at_ms': preservedLastSeenAtMs,
      'updated_at_ms': updatedAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Updates the last_seen_at_ms for a peer profile (called whenever we receive a message from them).
  Future<void> profileMetaUpdateLastSeen({
    required String profileId,
    required int lastSeenAtMs,
  }) async {
    final existing = await _db.query(
      'profile_meta',
      columns: ['profile_id'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await _db.insert('profile_meta', {
        'profile_id': profileId,
        'last_seen_at_ms': lastSeenAtMs,
        'updated_at_ms': lastSeenAtMs,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await _db.update(
        'profile_meta',
        {'last_seen_at_ms': lastSeenAtMs},
        where:
            'profile_id = ? AND (last_seen_at_ms IS NULL OR last_seen_at_ms < ?)',
        whereArgs: [profileId, lastSeenAtMs],
      );
    }
  }

  /// Returns the last_seen_at_ms for a peer profile, or null if unknown.
  Future<int?> profileMetaGetLastSeen(String profileId) async {
    final rows = await _db.query(
      'profile_meta',
      columns: ['last_seen_at_ms'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['last_seen_at_ms'] as num?)?.toInt();
  }

  Future<void> convoEnsure1to1({required String peerProfileId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.query(
      'conversations',
      columns: ['created_at_ms', 'last_event_at_ms', 'auto_delete_seconds'],
      where: 'convo_id = ?',
      whereArgs: [peerProfileId],
      limit: 1,
    );

    await _db.insert('conversations', {
      'convo_id': peerProfileId,
      'kind': '1to1',
      'peer_profile_id': peerProfileId,
      'title': null,
      'pinned_at_ms': null,
      'muted': 0,
      'archived_at_ms': null,
      'auto_delete_seconds': existing.isNotEmpty
          ? existing.first['auto_delete_seconds']
          : null,
      'last_event_at_ms': existing.isNotEmpty
          ? existing.first['last_event_at_ms']
          : now,
      'created_at_ms': existing.isNotEmpty
          ? existing.first['created_at_ms']
          : now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> convoEnsureRequest({required String peerProfileId}) async {
    final convoId = 'req:$peerProfileId';
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.query(
      'conversations',
      columns: ['created_at_ms', 'last_event_at_ms', 'auto_delete_seconds'],
      where: 'convo_id = ?',
      whereArgs: [convoId],
      limit: 1,
    );

    await _db.insert('conversations', {
      'convo_id': convoId,
      'kind': 'request',
      'peer_profile_id': peerProfileId,
      'title': null,
      'pinned_at_ms': null,
      'muted': 0,
      'archived_at_ms': null,
      'auto_delete_seconds': existing.isNotEmpty
          ? existing.first['auto_delete_seconds']
          : null,
      'last_event_at_ms': existing.isNotEmpty
          ? existing.first['last_event_at_ms']
          : now,
      'created_at_ms': existing.isNotEmpty
          ? existing.first['created_at_ms']
          : now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> convoMerge({
    required String fromConvoId,
    required String toConvoId,
  }) async {
    if (fromConvoId == toConvoId) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      final from = await txn.query(
        'conversations',
        columns: ['convo_id', 'created_at_ms', 'last_event_at_ms'],
        where: 'convo_id = ?',
        whereArgs: [fromConvoId],
        limit: 1,
      );
      if (from.isEmpty) return;

      final to = await txn.query(
        'conversations',
        columns: [
          'convo_id',
          'created_at_ms',
          'last_event_at_ms',
          'auto_delete_seconds',
        ],
        where: 'convo_id = ?',
        whereArgs: [toConvoId],
        limit: 1,
      );

      // Ensure destination convo exists.
      await txn.insert('conversations', {
        'convo_id': toConvoId,
        'kind': '1to1',
        'peer_profile_id': toConvoId,
        'title': null,
        'pinned_at_ms': null,
        'muted': 0,
        'archived_at_ms': null,
        'auto_delete_seconds': to.isNotEmpty
            ? to.first['auto_delete_seconds']
            : null,
        'last_event_at_ms': to.isNotEmpty ? to.first['last_event_at_ms'] : now,
        'created_at_ms': to.isNotEmpty ? to.first['created_at_ms'] : now,
        'updated_at_ms': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await txn.rawUpdate('UPDATE events SET convo_id = ? WHERE convo_id = ?', [
        toConvoId,
        fromConvoId,
      ]);

      final fromLast = (from.first['last_event_at_ms'] as int?) ?? 0;
      await txn.rawUpdate(
        'UPDATE conversations SET last_event_at_ms = MAX(last_event_at_ms, ?), updated_at_ms = ? WHERE convo_id = ?',
        [fromLast, now, toConvoId],
      );

      await txn.delete(
        'conversations',
        where: 'convo_id = ?',
        whereArgs: [fromConvoId],
      );
    });
  }

  Future<List<Map<String, Object?>>> requestsListPending({
    int limit = 200,
  }) async {
    return _db.query(
      'requests',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
  }

  Future<String?> requestStatus(String profileId) async {
    final rows = await _db.query(
      'requests',
      columns: ['status'],
      where: 'contact_profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['status'] as String?;
  }

  Future<void> requestUpsert({
    required String profileId,
    required String status,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.query(
      'requests',
      columns: ['created_at_ms'],
      where: 'contact_profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    await _db.insert('requests', {
      'contact_profile_id': profileId,
      'status': status,
      'created_at_ms': existing.isNotEmpty
          ? existing.first['created_at_ms']
          : now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> requestDelete(String profileId) async {
    await _db.delete(
      'requests',
      where: 'contact_profile_id = ?',
      whereArgs: [profileId],
    );
  }

  Future<void> requestAccept({required String profileId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      // Contact + conversation.
      final existing = await txn.query(
        'contacts',
        columns: ['created_at_ms', 'avatar_path', 'contact_emoji'],
        where: 'contact_profile_id = ?',
        whereArgs: [profileId],
        limit: 1,
      );
      await txn.insert('contacts', {
        'contact_profile_id': profileId,
        'display_name': null,
        'avatar_path': existing.isNotEmpty
            ? existing.first['avatar_path']
            : null,
        'contact_emoji': existing.isNotEmpty
            ? existing.first['contact_emoji']
            : null,
        'created_at_ms': existing.isNotEmpty
            ? existing.first['created_at_ms']
            : now,
        'updated_at_ms': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await txn.insert('conversations', {
        'convo_id': profileId,
        'kind': '1to1',
        'peer_profile_id': profileId,
        'title': null,
        'pinned_at_ms': null,
        'muted': 0,
        'archived_at_ms': null,
        'auto_delete_seconds': null,
        'last_event_at_ms': now,
        'created_at_ms': now,
        'updated_at_ms': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      // Move request events, outbox rows, and pending receipts into the real convo.
      final reqConvo = 'req:$profileId';
      await txn.rawUpdate('UPDATE events SET convo_id = ? WHERE convo_id = ?', [
        profileId,
        reqConvo,
      ]);
      await txn.rawUpdate('UPDATE outbox SET convo_id = ? WHERE convo_id = ?', [
        profileId,
        reqConvo,
      ]);
      await txn.rawUpdate(
        'UPDATE pending_receipts SET convo_id = ? WHERE convo_id = ?',
        [profileId, reqConvo],
      );
      final latestRows = await txn.rawQuery(
        'SELECT MAX(created_at_ms) AS latest_at_ms FROM events WHERE convo_id = ?',
        [profileId],
      );
      final latestEventAtMs =
          (latestRows.isNotEmpty ? latestRows.first['latest_at_ms'] : null)
              as int?;
      await txn.rawUpdate(
        'UPDATE conversations SET last_event_at_ms = MAX(last_event_at_ms, ?), updated_at_ms = ? WHERE convo_id = ?',
        [latestEventAtMs ?? now, now, profileId],
      );
      await txn.delete(
        'conversations',
        where: 'convo_id = ?',
        whereArgs: [reqConvo],
      );
      await txn.delete(
        'requests',
        where: 'contact_profile_id = ?',
        whereArgs: [profileId],
      );
    });
  }

  Future<void> blockedProfileSet({
    required String profileId,
    required bool blocked,
  }) async {
    if (blocked) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.insert('blocked_profiles', {
        'blocked_profile_id': profileId,
        'created_at_ms': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await _db.delete(
        'blocked_profiles',
        where: 'blocked_profile_id = ?',
        whereArgs: [profileId],
      );
    }
  }

  Future<bool> blockedProfileIsBlocked(String profileId) async {
    final rows = await _db.query(
      'blocked_profiles',
      columns: ['blocked_profile_id'],
      where: 'blocked_profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Map<String, Object?>>> blockedProfilesList({int limit = 500}) {
    return _db.query(
      'blocked_profiles',
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
  }

  Future<void> convoTouch({required String convoId, required int atMs}) async {
    await _db.rawUpdate(
      'UPDATE conversations SET last_event_at_ms = MAX(last_event_at_ms, ?), updated_at_ms = ? WHERE convo_id = ?',
      [atMs, DateTime.now().millisecondsSinceEpoch, convoId],
    );
  }

  // ── User-created (custom) chat folders ─────────────────────────────────────
  // Local-only chat-list organization. Never touches messaging / encryption.

  /// Returns custom folder rows ordered by position then creation time.
  Future<List<Map<String, Object?>>> folderListCustom() {
    return _db.query(
      'chat_folders',
      orderBy: 'position ASC, created_at_ms ASC',
    );
  }

  /// Inserts or updates a folder row (keyed by id).
  Future<void> folderUpsert({
    required String id,
    required String name,
    String? emoji,
    int position = 0,
  }) async {
    await _db.insert('chat_folders', {
      'id': id,
      'name': name,
      'emoji': emoji,
      'position': position,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Deletes a folder and all of its membership rows.
  Future<void> folderDelete(String id) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'chat_folder_members',
        where: 'folder_id = ?',
        whereArgs: [id],
      );
      await txn.delete('chat_folders', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Returns the convo ids that belong to a folder.
  Future<List<String>> folderMemberConvoIds(String folderId) async {
    final rows = await _db.query(
      'chat_folder_members',
      columns: ['convo_id'],
      where: 'folder_id = ?',
      whereArgs: [folderId],
    );
    return rows
        .map((r) => (r['convo_id'] as String?) ?? '')
        .where((c) => c.isNotEmpty)
        .toList(growable: false);
  }

  /// Replaces the membership set of a folder atomically.
  Future<void> folderSetMembers({
    required String folderId,
    required List<String> convoIds,
  }) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'chat_folder_members',
        where: 'folder_id = ?',
        whereArgs: [folderId],
      );
      for (final convoId in convoIds) {
        if (convoId.trim().isEmpty) continue;
        await txn.insert('chat_folder_members', {
          'folder_id': folderId,
          'convo_id': convoId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  /// Removes a conversation from every folder (chat-deletion cleanup).
  Future<void> folderRemoveConvoEverywhere(String convoId) async {
    await _db.delete(
      'chat_folder_members',
      where: 'convo_id = ?',
      whereArgs: [convoId],
    );
  }

  Future<List<Map<String, Object?>>> convoList({int limit = 200}) {
    return _db.query(
      'conversations',
      orderBy:
          'CASE WHEN archived_at_ms IS NULL THEN 0 ELSE 1 END ASC, '
          'CASE WHEN pinned_at_ms IS NULL THEN 0 ELSE 1 END DESC, '
          'pinned_at_ms DESC, last_event_at_ms DESC',
      limit: limit,
    );
  }

  Future<Map<String, Object?>?> convoGet(String convoId) async {
    final rows = await _db.query(
      'conversations',
      where: 'convo_id = ?',
      whereArgs: [convoId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> convoSetPinned({
    required String convoId,
    required bool pinned,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {'pinned_at_ms': pinned ? now : null, 'updated_at_ms': now},
      where: 'convo_id = ?',
      whereArgs: [convoId],
    );
  }

  Future<void> convoSetMuted({
    required String convoId,
    required bool muted,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {
        'muted': muted ? 1 : 0,
        // Plain on/off mute clears the granular fields.
        'muted_until_ms': muted ? -1 : 0,
        'muted_mentions_only': 0,
        'updated_at_ms': now,
      },
      where: 'convo_id = ?',
      whereArgs: [convoId],
    );
  }

  /// Granular mute. [mutedUntilMs]: 0 = unmuted, -1 = forever, else epoch-ms
  /// until which the chat is muted. [mentionsOnly] still surfaces @-mentions.
  /// The boolean `muted` column is kept in sync as the *effective* state so the
  /// existing push-policy + notification gates keep working unchanged.
  Future<void> convoSetMute({
    required String convoId,
    required int mutedUntilMs,
    required bool mentionsOnly,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final effectiveMuted =
        mutedUntilMs == -1 || (mutedUntilMs > 0 && mutedUntilMs > now);
    await _db.update(
      'conversations',
      {
        'muted': effectiveMuted ? 1 : 0,
        'muted_until_ms': mutedUntilMs,
        'muted_mentions_only': mentionsOnly ? 1 : 0,
        'updated_at_ms': now,
      },
      where: 'convo_id = ?',
      whereArgs: [convoId],
    );
  }

  /// Flips any time-limited mutes whose deadline has passed back to unmuted.
  /// Returns the convo ids that changed so the caller can refresh push policy.
  Future<List<String>> convoExpireMutes() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _db.query(
      'conversations',
      columns: ['convo_id'],
      where: 'muted = 1 AND muted_until_ms > 0 AND muted_until_ms <= ?',
      whereArgs: [now],
    );
    if (rows.isEmpty) return const <String>[];
    await _db.update(
      'conversations',
      {
        'muted': 0,
        'muted_until_ms': 0,
        'muted_mentions_only': 0,
        'updated_at_ms': now,
      },
      where: 'muted = 1 AND muted_until_ms > 0 AND muted_until_ms <= ?',
      whereArgs: [now],
    );
    return rows
        .map((row) => ((row['convo_id'] as String?) ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> convoSetArchived({
    required String convoId,
    required bool archived,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {'archived_at_ms': archived ? now : null, 'updated_at_ms': now},
      where: 'convo_id = ?',
      whereArgs: [convoId],
    );
  }

  Future<void> convoSetAutoDeleteSeconds({
    required String convoId,
    required int? autoDeleteSeconds,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {'auto_delete_seconds': autoDeleteSeconds, 'updated_at_ms': now},
      where: 'convo_id = ?',
      whereArgs: [convoId],
    );
  }

  Future<void> convoSetTitle({
    required String convoId,
    required String title,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {'title': title, 'updated_at_ms': now},
      where: 'convo_id = ?',
      whereArgs: [convoId],
    );
  }

  Future<void> convoEnsureGroup({
    required String groupId,
    required String title,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.query(
      'conversations',
      columns: ['created_at_ms', 'last_event_at_ms', 'auto_delete_seconds'],
      where: 'convo_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    await _db.insert('conversations', {
      'convo_id': groupId,
      'kind': 'group',
      'peer_profile_id': null,
      'title': title,
      'pinned_at_ms': null,
      'muted': 0,
      'archived_at_ms': null,
      'auto_delete_seconds': existing.isNotEmpty
          ? existing.first['auto_delete_seconds']
          : null,
      'last_event_at_ms': existing.isNotEmpty
          ? existing.first['last_event_at_ms']
          : now,
      'created_at_ms': existing.isNotEmpty
          ? existing.first['created_at_ms']
          : now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> groupMembersReplace({
    required String groupId,
    required List<String> memberProfileIds,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final members = memberProfileIds
        .where((m) => m.trim().isNotEmpty)
        .map((m) => m.trim())
        .toSet()
        .toList(growable: false);
    await _db.transaction((txn) async {
      await txn.delete(
        'group_members',
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      for (final member in members) {
        await txn.insert('group_members', {
          'group_id': groupId,
          'member_profile_id': member,
          'created_at_ms': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> groupMemberEnsure({
    required String groupId,
    required String memberProfileId,
  }) async {
    final member = memberProfileId.trim();
    if (member.isEmpty) return;
    await _db.insert('group_members', {
      'group_id': groupId,
      'member_profile_id': member,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, Object?>>> groupMembersList(String groupId) {
    return _db.query(
      'group_members',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'created_at_ms ASC',
    );
  }

  Future<void> _syncActiveGroupMembersFromMemberships(
    DatabaseExecutor executor, {
    required String groupId,
  }) async {
    final rows = await executor.query(
      'group_memberships',
      columns: ['profile_id', 'created_at_ms'],
      where: 'group_id = ? AND status = ?',
      whereArgs: [groupId, 'active'],
      orderBy: 'created_at_ms ASC',
    );
    await executor.delete(
      'group_members',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    for (final row in rows) {
      final profileId = ((row['profile_id'] as String?) ?? '').trim();
      if (profileId.isEmpty) continue;
      await executor.insert('group_members', {
        'group_id': groupId,
        'member_profile_id': profileId,
        'created_at_ms':
            (row['created_at_ms'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<GroupMembershipStateRecord?> groupMembershipStateGet({
    required String groupId,
    required String profileId,
  }) async {
    final cleanedGroupId = groupId.trim();
    final cleanedProfileId = profileId.trim();
    if (cleanedGroupId.isEmpty || cleanedProfileId.isEmpty) return null;
    final rows = await _db.query(
      'group_memberships',
      where: 'group_id = ? AND profile_id = ?',
      whereArgs: [cleanedGroupId, cleanedProfileId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      profileId: (row['profile_id'] as String?) ?? cleanedProfileId,
      status: ((row['status'] as String?) ?? '').trim(),
      role: ((row['role'] as String?) ?? 'member').trim(),
      sourceLinkId: (row['source_link_id'] as String?)?.trim(),
      tag: (row['tag'] as String?)?.trim(),
      createdAtMs: (row['created_at_ms'] as num?)?.toInt() ?? 0,
      updatedAtMs: (row['updated_at_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<GroupMembershipStateRecord>> groupMembershipStatesList(
    String groupId, {
    Iterable<String>? statuses,
  }) async {
    final cleanedGroupId = groupId.trim();
    if (cleanedGroupId.isEmpty) return const <GroupMembershipStateRecord>[];
    final cleanedStatuses = (statuses ?? const <String>[])
        .map((status) => status.trim())
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final where = cleanedStatuses.isEmpty
        ? 'group_id = ?'
        : 'group_id = ? AND status IN (${List.filled(cleanedStatuses.length, '?').join(', ')})';
    final rows = await _db.query(
      'group_memberships',
      where: where,
      whereArgs: <Object?>[cleanedGroupId, ...cleanedStatuses],
      orderBy: 'created_at_ms ASC, updated_at_ms ASC',
    );
    return rows
        .map(
          (row) => (
            profileId: ((row['profile_id'] as String?) ?? '').trim(),
            status: ((row['status'] as String?) ?? '').trim(),
            role: ((row['role'] as String?) ?? 'member').trim(),
            sourceLinkId: (row['source_link_id'] as String?)?.trim(),
            tag: (row['tag'] as String?)?.trim(),
            createdAtMs: (row['created_at_ms'] as num?)?.toInt() ?? 0,
            updatedAtMs: (row['updated_at_ms'] as num?)?.toInt() ?? 0,
          ),
        )
        .where(
          (record) => record.profileId.isNotEmpty && record.status.isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> listRecentStickers({
    required String profileId,
    int limit = 20,
  }) async {
    final normalizedProfileId = profileId.trim();
    if (normalizedProfileId.isEmpty || limit <= 0) return const [];
    return _db.query(
      'recent_stickers',
      where: 'profile_id = ?',
      whereArgs: [normalizedProfileId],
      orderBy: 'last_used_at_ms DESC',
      limit: limit,
    );
  }

  Future<void> recentStickerTouch({
    required String profileId,
    required String packId,
    required int packVersion,
    required String stickerId,
    required int lastUsedAtMs,
    int limit = 20,
  }) async {
    final normalizedProfileId = profileId.trim();
    final normalizedPackId = packId.trim();
    final normalizedStickerId = stickerId.trim();
    if (normalizedProfileId.isEmpty ||
        normalizedPackId.isEmpty ||
        normalizedStickerId.isEmpty) {
      return;
    }
    final cappedLimit = limit.clamp(1, 200);
    await _db.transaction((txn) async {
      final existing = await txn.query(
        'recent_stickers',
        columns: ['use_count'],
        where:
            'profile_id = ? AND pack_id = ? AND pack_version = ? AND sticker_id = ?',
        whereArgs: [
          normalizedProfileId,
          normalizedPackId,
          packVersion,
          normalizedStickerId,
        ],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert('recent_stickers', {
          'profile_id': normalizedProfileId,
          'pack_id': normalizedPackId,
          'pack_version': packVersion,
          'sticker_id': normalizedStickerId,
          'last_used_at_ms': lastUsedAtMs,
          'use_count': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        final nextCount =
            ((existing.first['use_count'] as num?)?.toInt() ?? 0) + 1;
        await txn.update(
          'recent_stickers',
          {'last_used_at_ms': lastUsedAtMs, 'use_count': nextCount},
          where:
              'profile_id = ? AND pack_id = ? AND pack_version = ? AND sticker_id = ?',
          whereArgs: [
            normalizedProfileId,
            normalizedPackId,
            packVersion,
            normalizedStickerId,
          ],
        );
      }

      final orderedRows = await txn.query(
        'recent_stickers',
        columns: ['pack_id', 'pack_version', 'sticker_id'],
        where: 'profile_id = ?',
        whereArgs: [normalizedProfileId],
        orderBy: 'last_used_at_ms DESC',
      );
      if (orderedRows.length <= cappedLimit) return;

      for (final row in orderedRows.skip(cappedLimit)) {
        await txn.delete(
          'recent_stickers',
          where:
              'profile_id = ? AND pack_id = ? AND pack_version = ? AND sticker_id = ?',
          whereArgs: [
            normalizedProfileId,
            (row['pack_id'] as String?) ?? '',
            (row['pack_version'] as num?)?.toInt() ?? 0,
            (row['sticker_id'] as String?) ?? '',
          ],
        );
      }
    });
  }

  /// Читает режим доступа к набору.
  Future<StickerShareMode> stickerPackShareMode({
    required String packId,
    required int packVersion,
  }) async {
    final rows = await _db.query(
      'sticker_packs',
      columns: ['share_mode'],
      where: 'pack_id = ? AND pack_version = ?',
      whereArgs: [packId.trim(), packVersion],
      limit: 1,
    );
    if (rows.isEmpty) return StickerShareMode.fallback;
    return StickerShareMode.fromStorage(rows.first['share_mode']);
  }

  /// Записывает режим доступа к набору.
  ///
  /// 🔴 ТОЧЕЧНЫМ `UPDATE`, а не через общий upsert набора. Тот перечисляет
  /// столбцы вручную, и запись режима «полным» путём затёрла бы всё, чего в
  /// вызове не оказалось, — тот же класс, что `ConflictAlgorithm.replace`.
  ///
  /// 🔴 Нереализованный режим не записывается. Значение [StickerShareMode.published]
  /// существует в перечислении, чтобы старые данные и будущие сборки не роняли
  /// чтение, но записать его сегодня значило бы пообещать человеку публикацию,
  /// которой нет ни на сервере, ни в модерации.
  Future<bool> stickerPackSetShareMode({
    required String packId,
    required int packVersion,
    required StickerShareMode mode,
  }) async {
    final pid = packId.trim();
    if (pid.isEmpty || packVersion <= 0) return false;
    if (!mode.isSupported) return false;
    final updated = await _db.update(
      'sticker_packs',
      <String, Object?>{'share_mode': mode.storageValue},
      where: 'pack_id = ? AND pack_version = ?',
      whereArgs: [pid, packVersion],
    );
    return updated > 0;
  }

  Future<void> upsertStickerPackSummary({
    required String packId,
    required int packVersion,
    required String title,
    String description = '',
    required String iconStickerId,
    String iconEmojiHint = '',
    int? featuredRank,
    List<String> tags = const <String>[],
    required int stickerCount,
    required int updatedAtMs,
  }) async {
    final normalizedPackId = packId.trim();
    final normalizedTitle = title.trim();
    final normalizedIconStickerId = iconStickerId.trim();
    if (normalizedPackId.isEmpty ||
        packVersion <= 0 ||
        normalizedTitle.isEmpty ||
        normalizedIconStickerId.isEmpty) {
      return;
    }
    final existing = await _db.query(
      'sticker_packs',
      columns: ['installed', 'installed_at_ms'],
      where: 'pack_id = ? AND pack_version = ?',
      whereArgs: [normalizedPackId, packVersion],
      limit: 1,
    );
    final installed = existing.isEmpty
        ? 0
        : (((existing.first['installed'] as num?)?.toInt() ?? 0) > 0 ? 1 : 0);
    final installedAtMs = existing.isEmpty
        ? null
        : (existing.first['installed_at_ms'] as num?)?.toInt();
    await _db.insert('sticker_packs', {
      'pack_id': normalizedPackId,
      'pack_version': packVersion,
      'title': normalizedTitle,
      'description': description.trim(),
      'icon_sticker_id': normalizedIconStickerId,
      'icon_emoji_hint': iconEmojiHint.trim(),
      'featured_rank': featuredRank,
      'tags_json': jsonEncode(
        tags
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
      ),
      'installed': installed,
      'sticker_count': stickerCount < 0 ? 0 : stickerCount,
      'updated_at_ms': updatedAtMs,
      'installed_at_ms': installedAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> replaceStickerPackStickers({
    required String packId,
    required int packVersion,
    required List<StickerPackStickerRecord> stickers,
  }) async {
    final normalizedPackId = packId.trim();
    if (normalizedPackId.isEmpty || packVersion <= 0) return;
    await _db.transaction((txn) async {
      final existing = await txn.query(
        'sticker_pack_stickers',
        columns: [
          'sticker_id',
          'local_path',
          'downloaded_at_ms',
          'last_accessed_at_ms',
        ],
        where: 'pack_id = ? AND pack_version = ?',
        whereArgs: [normalizedPackId, packVersion],
      );
      final existingByStickerId = <String, Map<String, Object?>>{
        for (final row in existing)
          (((row['sticker_id'] as String?) ?? '').trim()): row,
      };
      await txn.delete(
        'sticker_pack_stickers',
        where: 'pack_id = ? AND pack_version = ?',
        whereArgs: [normalizedPackId, packVersion],
      );
      for (final sticker in stickers) {
        final normalizedStickerId = sticker.stickerId.trim();
        if (normalizedStickerId.isEmpty) continue;
        final previous = existingByStickerId[normalizedStickerId];
        await txn.insert('sticker_pack_stickers', {
          'pack_id': normalizedPackId,
          'pack_version': packVersion,
          'sticker_id': normalizedStickerId,
          'file_name': sticker.fileName.trim(),
          'local_path':
              ((previous?['local_path'] as String?) ?? sticker.localPath)
                  .trim(),
          'format': sticker.format.trim(),
          'animated': sticker.animated ? 1 : 0,
          'emoji_hint': sticker.emojiHint.trim(),
          'label': sticker.label.trim(),
          'keywords_json': jsonEncode(
            sticker.keywords
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false),
          ),
          'sha256_b64': sticker.sha256B64.trim(),
          'size_bytes': sticker.sizeBytes < 0 ? 0 : sticker.sizeBytes,
          'downloaded_at_ms':
              (previous?['downloaded_at_ms'] as num?)?.toInt() ??
              sticker.downloadedAtMs,
          'last_accessed_at_ms':
              (previous?['last_accessed_at_ms'] as num?)?.toInt() ??
              sticker.lastAccessedAtMs,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Insert/replace a SINGLE sticker row in a pack (unlike
  /// [replaceStickerPackStickers] which wipes the whole pack first). Used to
  /// grow a user's own «Мои стикеры» pack one created sticker at a time.
  Future<void> upsertStickerPackSticker({
    required StickerPackStickerRecord sticker,
  }) async {
    final normalizedPackId = sticker.packId.trim();
    final normalizedStickerId = sticker.stickerId.trim();
    if (normalizedPackId.isEmpty ||
        sticker.packVersion <= 0 ||
        normalizedStickerId.isEmpty) {
      return;
    }
    await _db.insert('sticker_pack_stickers', {
      'pack_id': normalizedPackId,
      'pack_version': sticker.packVersion,
      'sticker_id': normalizedStickerId,
      'file_name': sticker.fileName.trim(),
      'local_path': sticker.localPath.trim(),
      'format': sticker.format.trim(),
      'animated': sticker.animated ? 1 : 0,
      'emoji_hint': sticker.emojiHint.trim(),
      'label': sticker.label.trim(),
      'keywords_json': jsonEncode(
        sticker.keywords
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
      ),
      'sha256_b64': sticker.sha256B64.trim(),
      'size_bytes': sticker.sizeBytes < 0 ? 0 : sticker.sizeBytes,
      'downloaded_at_ms': sticker.downloadedAtMs,
      'last_accessed_at_ms': sticker.lastAccessedAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Кэшированная ссылка на выгруженный блоб стикера.
  ///
  /// Возвращает `null`, если блоба нет ИЛИ его срок истёк.
  ///
  /// 🔴 Просроченное считается ОТСУТСТВУЮЩИМ, а не «почти годным». Отдать
  /// мёртвую ссылку значит показать собеседнику стикер, который не скачивается,
  /// — и он спишет это на поломку приложения, а не на срок хранения. Кэш без
  /// инвалидации хуже отсутствия кэша.
  ///
  /// 🔴 [safetyMarginMs] — запас на дорогу. Блоб, истекающий через секунду,
  /// формально ещё жив, но к моменту, когда получатель за ним придёт, уже нет.
  Future<({String blobId, String fileKeyB64, String accessTokenB64})?>
  stickerCachedBlob({
    required String packId,
    required int packVersion,
    required String stickerId,
    int safetyMarginMs = 10 * 60 * 1000,
    int? nowMs,
  }) async {
    final rows = await _db.query(
      'sticker_pack_stickers',
      columns: [
        'blob_id',
        'blob_file_key_b64',
        'blob_access_token_b64',
        'blob_expires_at_ms',
      ],
      where: 'pack_id = ? AND pack_version = ? AND sticker_id = ?',
      whereArgs: [packId.trim(), packVersion, stickerId.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final blobId = ((row['blob_id'] as String?) ?? '').trim();
    final fileKey = ((row['blob_file_key_b64'] as String?) ?? '').trim();
    // Без ключа блоб бесполезен: расшифровать его нечем.
    if (blobId.isEmpty || fileKey.isEmpty) return null;

    final expiresAt = (row['blob_expires_at_ms'] as num?)?.toInt();
    // 🔴 Отсутствие срока трактуем как ПРОСРОЧЕННОЕ. Иначе строка, записанная
    // без срока (старой сборкой или по ошибке), жила бы в кэше вечно и однажды
    // начала бы отдавать мёртвую ссылку — то есть ровно то, от чего срок и есть.
    if (expiresAt == null) return null;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (expiresAt - safetyMarginMs <= now) return null;

    return (
      blobId: blobId,
      fileKeyB64: fileKey,
      accessTokenB64: ((row['blob_access_token_b64'] as String?) ?? '').trim(),
    );
  }

  /// Запоминает выгруженный блоб стикера.
  ///
  /// 🔴 Точечным `UPDATE`: общий upsert стикера перечисляет столбцы вручную и
  /// снёс бы всё, чего не оказалось в вызове (класс `ConflictAlgorithm.replace`).
  ///
  /// 🔴 Без срока не записываем вовсе. Запись «на всякий случай» создала бы
  /// строку, которую нечем инвалидировать.
  Future<bool> stickerRememberBlob({
    required String packId,
    required int packVersion,
    required String stickerId,
    required String blobId,
    required String fileKeyB64,
    String accessTokenB64 = '',
    required int? expiresAtMs,
  }) async {
    final pid = packId.trim();
    final sid = stickerId.trim();
    final blob = blobId.trim();
    final key = fileKeyB64.trim();
    if (pid.isEmpty || sid.isEmpty || blob.isEmpty || key.isEmpty) return false;
    if (expiresAtMs == null || expiresAtMs <= 0) return false;
    final updated = await _db.update(
      'sticker_pack_stickers',
      <String, Object?>{
        'blob_id': blob,
        'blob_file_key_b64': key,
        'blob_access_token_b64': accessTokenB64.trim(),
        'blob_expires_at_ms': expiresAtMs,
      },
      where: 'pack_id = ? AND pack_version = ? AND sticker_id = ?',
      whereArgs: [pid, packVersion, sid],
    );
    return updated > 0;
  }

  /// Столбцы с АБСОЛЮТНЫМИ путями к картинкам, которые едут в копию.
  ///
  /// 🔴 Зачем перечень (13.09.2026). Снимок копии переносит пути целиком, а они
  /// указывают в каталог ЧУЖОГО контейнера: на iOS он меняет UUID при каждой
  /// переустановке, а при связке с компьютером это вообще другая машина.
  /// Строки ложатся, файлы ложатся рядом — и всё равно везде инициалы, потому
  /// что указатель ведёт в никуда. Ровно та же болезнь, что была у стикеров
  /// (`local_path`) и у своего фото (`my_avatar_path_v1`), вылеченная там
  /// поимённой перепривязкой.
  static const Map<String, List<String>> _restorableImagePathColumns =
      <String, List<String>>{
        'contacts': <String>['avatar_path'],
        'profile_meta': <String>['avatar_path', 'cover_path'],
        'group_settings': <String>['avatar_path'],
        'message_reactions': <String>['actor_avatar_path'],
      };

  /// Переписывает пути к картинкам под нынешний каталог приложения.
  ///
  /// [resolve] получает сохранённый путь и возвращает новый — или null, если
  /// менять нечего. Возвращает число переписанных строк.
  Future<int> rebaseImagePaths(String? Function(String stored) resolve) async {
    var fixed = 0;
    for (final entry in _restorableImagePathColumns.entries) {
      final table = entry.key;
      for (final column in entry.value) {
        final List<Map<String, Object?>> rows;
        try {
          rows = await _db.query(
            table,
            distinct: true,
            columns: <String>[column],
            where: "$column IS NOT NULL AND $column <> ''",
          );
        } catch (_) {
          // Таблицы может не быть в старой схеме — это не повод падать.
          continue;
        }
        for (final row in rows) {
          final stored = ((row[column] as String?) ?? '').trim();
          if (stored.isEmpty) continue;
          final next = resolve(stored);
          if (next == null || next == stored) continue;
          fixed += await _db.update(
            table,
            <String, Object?>{column: next},
            where: '$column = ?',
            whereArgs: <Object?>[stored],
          );
        }
      }
    }
    return fixed;
  }

  /// Все стикеры всех наборов — только те поля, что нужны перепривязке путей.
  ///
  /// 🔴 Нужен восстановлению из копии (08.08.2026): `local_path` абсолютный, а
  /// снимок приносит путь ЧУЖОГО контейнера, поэтому после восстановления
  /// указатели надо переписать под нынешний каталог приложения.
  Future<List<Map<String, Object?>>> stickerLocalPathRowsForRebase() async {
    return _db.query(
      'sticker_pack_stickers',
      columns: [
        'pack_id',
        'pack_version',
        'sticker_id',
        'file_name',
        'local_path',
      ],
    );
  }

  /// Переписывает путь к файлу стикера.
  Future<void> stickerUpdateLocalPath({
    required String packId,
    required int packVersion,
    required String stickerId,
    required String localPath,
  }) async {
    final pid = packId.trim();
    final sid = stickerId.trim();
    final path = localPath.trim();
    if (pid.isEmpty || sid.isEmpty || path.isEmpty) return;
    await _db.update(
      'sticker_pack_stickers',
      <String, Object?>{'local_path': path},
      where: 'pack_id = ? AND pack_version = ? AND sticker_id = ?',
      whereArgs: [pid, packVersion, sid],
    );
  }

  /// Remove a single sticker from a pack (for «изменить» pack editing).
  Future<void> deleteStickerPackSticker({
    required String packId,
    required int packVersion,
    required String stickerId,
  }) async {
    await _db.delete(
      'sticker_pack_stickers',
      where: 'pack_id = ? AND pack_version = ? AND sticker_id = ?',
      whereArgs: [packId.trim(), packVersion, stickerId.trim()],
    );
  }

  Future<void> deleteStickerCatalogPack({
    required String packId,
    required int packVersion,
  }) async {
    final normalizedPackId = packId.trim();
    if (normalizedPackId.isEmpty || packVersion <= 0) return;
    await _db.transaction((txn) async {
      await txn.delete(
        'sticker_pack_stickers',
        where: 'pack_id = ? AND pack_version = ?',
        whereArgs: [normalizedPackId, packVersion],
      );
      await txn.delete(
        'sticker_packs',
        where: 'pack_id = ? AND pack_version = ?',
        whereArgs: [normalizedPackId, packVersion],
      );
    });
  }

  Future<List<StickerPackCatalogRecord>> listStickerCatalogPacks() async {
    final rows = await _db.query(
      'sticker_packs',
      orderBy: 'installed DESC, featured_rank ASC, title COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (row) => (
            packId: ((row['pack_id'] as String?) ?? '').trim(),
            packVersion: (row['pack_version'] as num?)?.toInt() ?? 0,
            title: ((row['title'] as String?) ?? '').trim(),
            description: ((row['description'] as String?) ?? '').trim(),
            iconStickerId: ((row['icon_sticker_id'] as String?) ?? '').trim(),
            iconEmojiHint: ((row['icon_emoji_hint'] as String?) ?? '').trim(),
            featuredRank: (row['featured_rank'] as num?)?.toInt(),
            tags: _decodeStringListJson(row['tags_json']),
            installed: ((row['installed'] as num?)?.toInt() ?? 0) > 0,
            stickerCount: (row['sticker_count'] as num?)?.toInt() ?? 0,
            updatedAtMs: (row['updated_at_ms'] as num?)?.toInt() ?? 0,
            installedAtMs: (row['installed_at_ms'] as num?)?.toInt(),
            // Неизвестное значение читается как режим по умолчанию, а не роняет
            // чтение набора: столбец могла записать более новая сборка.
            shareMode: StickerShareMode.fromStorage(row['share_mode']),
          ),
        )
        .where(
          (record) =>
              record.packId.isNotEmpty &&
              record.packVersion > 0 &&
              record.title.isNotEmpty &&
              record.iconStickerId.isNotEmpty,
        )
        .toList(growable: false);
  }

  /// Все стикеры каталога разом, сгруппированные по набору.
  ///
  /// 🔴 ПОЧЕМУ (02.09.2026, замер холодного старта). Загрузка каталога брала
  /// список наборов одним запросом, а потом ходила за содержимым КАЖДОГО
  /// отдельно: сорок семь наборов — сорок восемь последовательных обращений к
  /// SQLCipher, где каждая страница ещё и расшифровывается. На устройстве это
  /// 339 мс из 776 мс холодного старта, то есть сорок четыре процента, — и всё
  /// это до того, как человек успел открыть приложение.
  ///
  /// Группировка в памяти дешевле, чем сорок семь обходов: строк порядка
  /// двенадцати тысяч, и они всё равно поднимались целиком, просто по частям.
  ///
  /// Порядок внутри набора сохранён прежний (`sticker_id` без учёта регистра),
  /// иначе панель стикеров переставила бы содержимое у всех сразу.
  Future<Map<({String packId, int packVersion}), List<StickerPackStickerRecord>>>
  listAllStickerCatalogStickersByPack() async {
    // 🔴 ТОЛЬКО НУЖНЫЕ КОЛОНКИ. Каталог строится из девяти полей; контрольная
    // сумма, размер и метки времени скачивания в нём не участвуют вовсе, а
    // читаются они для КАЖДОЙ из примерно двенадцати тысяч строк — и каждая
    // страница базы при этом расшифровывается. Поля, которых нет в выборке,
    // заполняются ниже нулями: этот метод существует ровно для построения
    // каталога, и другого потребителя у него нет.
    final rows = await _db.query(
      'sticker_pack_stickers',
      columns: const [
        'pack_id',
        'pack_version',
        'sticker_id',
        'file_name',
        'local_path',
        'format',
        'animated',
        'emoji_hint',
        'label',
        'keywords_json',
      ],
      orderBy: 'pack_id ASC, pack_version ASC, sticker_id COLLATE NOCASE ASC',
    );
    final grouped =
        <({String packId, int packVersion}), List<StickerPackStickerRecord>>{};
    for (final row in rows) {
      final packId = ((row['pack_id'] as String?) ?? '').trim();
      final packVersion = (row['pack_version'] as num?)?.toInt() ?? 0;
      final stickerId = ((row['sticker_id'] as String?) ?? '').trim();
      final fileName = ((row['file_name'] as String?) ?? '').trim();
      if (packId.isEmpty ||
          packVersion <= 0 ||
          stickerId.isEmpty ||
          fileName.isEmpty) {
        continue;
      }
      (grouped[(packId: packId, packVersion: packVersion)] ??=
              <StickerPackStickerRecord>[])
          .add((
            packId: packId,
            packVersion: packVersion,
            stickerId: stickerId,
            fileName: fileName,
            localPath: ((row['local_path'] as String?) ?? '').trim(),
            format: ((row['format'] as String?) ?? '').trim(),
            animated: ((row['animated'] as num?)?.toInt() ?? 0) != 0,
            emojiHint: ((row['emoji_hint'] as String?) ?? '').trim(),
            label: ((row['label'] as String?) ?? '').trim(),
            keywords: _decodeStringListJson(row['keywords_json']),
            // Не выбираются намеренно — см. пояснение к запросу выше.
            sha256B64: '',
            sizeBytes: 0,
            downloadedAtMs: null,
            lastAccessedAtMs: null,
          ));
    }
    return grouped;
  }

  Future<List<StickerPackStickerRecord>> listStickerCatalogStickers({
    required String packId,
    required int packVersion,
  }) async {
    final normalizedPackId = packId.trim();
    if (normalizedPackId.isEmpty || packVersion <= 0) {
      return const <StickerPackStickerRecord>[];
    }
    final rows = await _db.query(
      'sticker_pack_stickers',
      where: 'pack_id = ? AND pack_version = ?',
      whereArgs: [normalizedPackId, packVersion],
      orderBy: 'sticker_id COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (row) => (
            packId: ((row['pack_id'] as String?) ?? '').trim(),
            packVersion: (row['pack_version'] as num?)?.toInt() ?? 0,
            stickerId: ((row['sticker_id'] as String?) ?? '').trim(),
            fileName: ((row['file_name'] as String?) ?? '').trim(),
            localPath: ((row['local_path'] as String?) ?? '').trim(),
            format: ((row['format'] as String?) ?? '').trim(),
            animated: ((row['animated'] as num?)?.toInt() ?? 0) > 0,
            emojiHint: ((row['emoji_hint'] as String?) ?? '').trim(),
            label: ((row['label'] as String?) ?? '').trim(),
            keywords: _decodeStringListJson(row['keywords_json']),
            sha256B64: ((row['sha256_b64'] as String?) ?? '').trim(),
            sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
            downloadedAtMs: (row['downloaded_at_ms'] as num?)?.toInt(),
            lastAccessedAtMs: (row['last_accessed_at_ms'] as num?)?.toInt(),
          ),
        )
        .where(
          (record) =>
              record.packId.isNotEmpty &&
              record.packVersion > 0 &&
              record.stickerId.isNotEmpty &&
              record.fileName.isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<void> setStickerPackInstalled({
    required String packId,
    required int packVersion,
    required bool installed,
    int? installedAtMs,
  }) async {
    final normalizedPackId = packId.trim();
    if (normalizedPackId.isEmpty || packVersion <= 0) return;
    await _db.update(
      'sticker_packs',
      {
        'installed': installed ? 1 : 0,
        'installed_at_ms': installed ? installedAtMs : null,
      },
      where: 'pack_id = ? AND pack_version = ?',
      whereArgs: [normalizedPackId, packVersion],
    );
  }

  Future<void> updateStickerLocalAsset({
    required String packId,
    required int packVersion,
    required String stickerId,
    required String localPath,
    int? downloadedAtMs,
    int? lastAccessedAtMs,
  }) async {
    final normalizedPackId = packId.trim();
    final normalizedStickerId = stickerId.trim();
    if (normalizedPackId.isEmpty ||
        normalizedStickerId.isEmpty ||
        packVersion <= 0) {
      return;
    }
    await _db.update(
      'sticker_pack_stickers',
      {
        'local_path': localPath.trim(),
        'downloaded_at_ms': downloadedAtMs,
        'last_accessed_at_ms': lastAccessedAtMs,
      },
      where: 'pack_id = ? AND pack_version = ? AND sticker_id = ?',
      whereArgs: [normalizedPackId, packVersion, normalizedStickerId],
    );
  }

  Future<void> resetStickerPackInstallState({
    String? packId,
    int? packVersion,
  }) async {
    final normalizedPackId = (packId ?? '').trim();
    await _db.transaction((txn) async {
      if (normalizedPackId.isEmpty || packVersion == null || packVersion <= 0) {
        await txn.update('sticker_packs', {
          'installed': 0,
          'installed_at_ms': null,
        });
        await txn.update('sticker_pack_stickers', {
          'local_path': '',
          'downloaded_at_ms': null,
          'last_accessed_at_ms': null,
        });
        return;
      }
      await txn.update(
        'sticker_packs',
        {'installed': 0, 'installed_at_ms': null},
        where: 'pack_id = ? AND pack_version = ?',
        whereArgs: [normalizedPackId, packVersion],
      );
      await txn.update(
        'sticker_pack_stickers',
        {
          'local_path': '',
          'downloaded_at_ms': null,
          'last_accessed_at_ms': null,
        },
        where: 'pack_id = ? AND pack_version = ?',
        whereArgs: [normalizedPackId, packVersion],
      );
    });
  }

  /// LRU / size-cap eviction of downloaded sticker assets.
  ///
  /// The `sticker_pack_stickers.last_accessed_at_ms` column is already stamped
  /// on use but was never read for eviction, so the on-disk `stickers/` cache
  /// grew unbounded. This evicts the least-recently-accessed *downloaded*
  /// stickers (those with a non-empty `local_path`) once the cache exceeds
  /// EITHER [maxBytes] or [maxCount], deleting the on-disk file and clearing the
  /// row's asset columns (`local_path`/`downloaded_at_ms`/`last_accessed_at_ms`)
  /// so the sticker re-downloads transparently on next use. The catalog row
  /// itself is preserved.
  ///
  /// Safe + idempotent: touches only `sticker_pack_stickers`, never deletes a
  /// catalog/pack row, and a no-op when already within the caps. Rows with a
  /// null `last_accessed_at_ms` are treated as oldest (evicted first), so legacy
  /// rows that pre-date access-tracking still get reclaimed. Best-effort — file
  /// deletion failures are swallowed and the DB row is still cleared.
  ///
  /// Returns the number of stickers evicted.
  Future<int> evictStickerCacheIfNeeded({
    int maxBytes = 64 * 1024 * 1024,
    int maxCount = 600,
  }) async {
    if (maxBytes <= 0 && maxCount <= 0) return 0;
    // Newest first so we keep the most-recently-used and drop from the tail.
    final rows = await _db.query(
      'sticker_pack_stickers',
      columns: [
        'pack_id',
        'pack_version',
        'sticker_id',
        'local_path',
        'size_bytes',
        'last_accessed_at_ms',
      ],
      where: "local_path IS NOT NULL AND local_path != ''",
      orderBy: 'last_accessed_at_ms IS NULL ASC, last_accessed_at_ms DESC',
    );
    if (rows.isEmpty) return 0;

    var keptBytes = 0;
    var keptCount = 0;
    final victims = <Map<String, Object?>>[];
    for (final row in rows) {
      final size = (row['size_bytes'] as num?)?.toInt() ?? 0;
      final overCount = maxCount > 0 && keptCount >= maxCount;
      final overBytes = maxBytes > 0 && keptBytes + size > maxBytes;
      if (overCount || overBytes) {
        victims.add(row);
      } else {
        keptCount += 1;
        keptBytes += size;
      }
    }
    if (victims.isEmpty) return 0;

    for (final victim in victims) {
      final localPath = ((victim['local_path'] as String?) ?? '').trim();
      if (localPath.isNotEmpty) {
        try {
          final f = File(localPath);
          if (await f.exists()) await f.delete();
        } catch (_) {
          // Best-effort: clear the row even if the file can't be removed.
        }
      }
    }

    await _db.transaction((txn) async {
      for (final victim in victims) {
        await txn.update(
          'sticker_pack_stickers',
          {
            'local_path': '',
            'downloaded_at_ms': null,
            'last_accessed_at_ms': null,
          },
          where: 'pack_id = ? AND pack_version = ? AND sticker_id = ?',
          whereArgs: [
            victim['pack_id'],
            victim['pack_version'],
            victim['sticker_id'],
          ],
        );
      }
    });
    return victims.length;
  }

  Future<void> groupMembershipStateUpsert({
    required String groupId,
    required String profileId,
    required String status,
    String role = 'member',
    String? sourceLinkId,
    String? tag,
    int? createdAtMs,
    int? updatedAtMs,
    bool preserveExistingCreatedAt = true,
  }) async {
    final cleanedGroupId = groupId.trim();
    final cleanedProfileId = profileId.trim();
    final cleanedStatus = status.trim();
    final cleanedRole = role.trim().isEmpty ? 'member' : role.trim();
    if (cleanedGroupId.isEmpty ||
        cleanedProfileId.isEmpty ||
        cleanedStatus.isEmpty) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.query(
      'group_memberships',
      columns: ['created_at_ms'],
      where: 'group_id = ? AND profile_id = ?',
      whereArgs: [cleanedGroupId, cleanedProfileId],
      limit: 1,
    );
    final existingCreatedAtMs = existing.isEmpty
        ? null
        : (existing.first['created_at_ms'] as num?)?.toInt();
    final effectiveCreatedAtMs =
        preserveExistingCreatedAt && existingCreatedAtMs != null
        ? existingCreatedAtMs
        : (createdAtMs ?? now);
    await _db.transaction((txn) async {
      await txn.insert('group_memberships', {
        'group_id': cleanedGroupId,
        'profile_id': cleanedProfileId,
        'status': cleanedStatus,
        'role': cleanedRole,
        'source_link_id': (sourceLinkId ?? '').trim().isEmpty
            ? null
            : (sourceLinkId ?? '').trim(),
        'tag': (tag ?? '').trim().isEmpty ? null : tag!.trim(),
        'created_at_ms': effectiveCreatedAtMs,
        'updated_at_ms': updatedAtMs ?? now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _syncActiveGroupMembersFromMemberships(
        txn,
        groupId: cleanedGroupId,
      );
    });
  }

  Future<void> groupMembershipStatesReplace({
    required String groupId,
    required List<GroupMembershipStateRecord> states,
  }) async {
    final cleanedGroupId = groupId.trim();
    if (cleanedGroupId.isEmpty) return;
    final normalizedByProfileId = <String, GroupMembershipStateRecord>{};
    for (final state in states) {
      final cleanedProfileId = state.profileId.trim();
      final cleanedStatus = state.status.trim();
      if (cleanedProfileId.isEmpty || cleanedStatus.isEmpty) continue;
      normalizedByProfileId[cleanedProfileId] = (
        profileId: cleanedProfileId,
        status: cleanedStatus,
        role: state.role.trim().isEmpty ? 'member' : state.role.trim(),
        sourceLinkId: state.sourceLinkId?.trim().isEmpty == true
            ? null
            : state.sourceLinkId?.trim(),
        tag: state.tag?.trim().isEmpty == true ? null : state.tag?.trim(),
        createdAtMs: state.createdAtMs,
        updatedAtMs: state.updatedAtMs,
      );
    }

    await _db.transaction((txn) async {
      await txn.delete(
        'group_memberships',
        where: 'group_id = ?',
        whereArgs: [cleanedGroupId],
      );
      for (final state in normalizedByProfileId.values) {
        await txn.insert('group_memberships', {
          'group_id': cleanedGroupId,
          'profile_id': state.profileId,
          'status': state.status,
          'role': state.role,
          'source_link_id': state.sourceLinkId,
          'tag': state.tag,
          'created_at_ms': state.createdAtMs,
          'updated_at_ms': state.updatedAtMs,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await _syncActiveGroupMembersFromMemberships(
        txn,
        groupId: cleanedGroupId,
      );
    });
  }

  // ───────────── Список тем комнаты (общий, переживает окно ленты) ─────────

  bool _roomTopicsReady = false;

  /// 🔴 ТАБЛИЦА СОЗДАЁТСЯ ЛЕНИВО, БЕЗ ПОДЪЁМА ВЕРСИИ СХЕМЫ — как и заметки.
  ///
  /// Ветка в цепочке миграций ради списка тем несоразмерна риску: у человека,
  /// чья база не открылась, нет истории и вернуть её нечем. `IF NOT EXISTS` на
  /// уже открытом соединении повторный вызов не замечает, а номер версии
  /// остаётся прежним — значит откатившаяся сборка не увидит версию из
  /// будущего.
  Future<void> _ensureRoomTopics() async {
    if (_roomTopicsReady) return;
    await _db.execute(
      'CREATE TABLE IF NOT EXISTS room_topics ('
      '  room_id TEXT PRIMARY KEY,'
      '  topics_json TEXT NOT NULL,'
      '  synced_at_ms INTEGER NOT NULL'
      ');',
    );
    _roomTopicsReady = true;
  }

  /// Сохранённый список тем комнаты и отметка времени сообщения, из которого
  /// он принят. `null` — про эту комнату мы тем ещё не видели.
  ///
  /// 🔴 ЗАЧЕМ ХРАНИТЬ ТО, ЧТО И ТАК ЕСТЬ В ЛЕНТЕ (15.09.2026).
  ///
  /// Список тем приходит скрытым сообщением внутри переписки, и до сих пор
  /// каждое устройство собирало его заново из ЗАГРУЖЕННОГО ОКНА — последних
  /// двухсот событий. Стоило накопиться двум сотням новых сообщений, и темы
  /// пропадали у всех сразу, а сообщения с их `topic_id` уезжали в «Общий».
  /// Устройство, у которого комната не была открыта в нужный момент, тем не
  /// видело вовсе — это и есть «на компьютере тем нет».
  Future<({String topicsJson, int syncedAtMs})?> roomTopicsGet(
    String roomId,
  ) async {
    final id = roomId.trim();
    if (id.isEmpty) return null;
    await _ensureRoomTopics();
    final rows = await _db.query(
      'room_topics',
      columns: ['topics_json', 'synced_at_ms'],
      where: 'room_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (
      topicsJson: (rows.first['topics_json'] as String?) ?? '',
      syncedAtMs: (rows.first['synced_at_ms'] as int?) ?? 0,
    );
  }

  /// Запоминает список тем. Побеждает БОЛЕЕ СВЕЖЕЕ сообщение: это та же
  /// «последний выиграл», что и у самой рассылки, и она не даёт старому
  /// повтору из ленты отменить свежую правку.
  Future<void> roomTopicsSet({
    required String roomId,
    required String topicsJson,
    required int syncedAtMs,
  }) async {
    final id = roomId.trim();
    if (id.isEmpty) return;
    await _ensureRoomTopics();
    final existing = await _db.query(
      'room_topics',
      columns: ['synced_at_ms'],
      where: 'room_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final known = (existing.first['synced_at_ms'] as int?) ?? 0;
      if (syncedAtMs < known) return;
    }
    await _db.insert('room_topics', {
      'room_id': id,
      'topics_json': topicsJson,
      'synced_at_ms': syncedAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ───────────── Личные заметки по разговору (только десктоп) ─────────────

  /// Создана ли уже таблица заметок в ЭТОМ соединении.
  bool _desktopNotesReady = false;

  /// 🔴 ТАБЛИЦА СОЗДАЁТСЯ ЛЕНИВО, БЕЗ ПОДЪЁМА ВЕРСИИ СХЕМЫ.
  ///
  /// Цепочка миграций этой базы — самое дорогое место в проекте: у человека,
  /// чья база отказалась открыться, нет истории и вернуть её нечем. Заводить
  /// там ветку ради заметок в окне созвона — несоразмерный риск, и это была бы
  /// ещё и дверь в одну сторону: телефон, откатившийся на прежнюю сборку,
  /// увидел бы версию схемы из будущего.
  ///
  /// Поэтому `IF NOT EXISTS` на уже открытом соединении: повторный вызов
  /// ничего не делает, номер версии не меняется, а телефон сюда не заходит
  /// вовсе — на нём этих заметок нет.
  Future<void> _ensureDesktopRoomNotes() async {
    if (_desktopNotesReady) return;
    await _db.execute(
      'CREATE TABLE IF NOT EXISTS desktop_room_notes ('
      '  convo_id TEXT PRIMARY KEY,'
      '  body TEXT NOT NULL,'
      '  updated_at_ms INTEGER NOT NULL'
      ');',
    );
    _desktopNotesReady = true;
  }

  /// Заметка по разговору. Пусто — заметки нет.
  ///
  /// Лежит В ЭТОЙ ЖЕ базе, а значит под тем же ключом, что и переписка. Это не
  /// мелочь: заметка с созвона — запись того же разговора, и держать её в
  /// обычных настройках, открытым текстом рядом с зашифрованной историей,
  /// значило бы обойти собственное обещание с чёрного хода.
  Future<String> desktopRoomNote(String convoId) async {
    final id = convoId.trim();
    if (id.isEmpty) return '';
    await _ensureDesktopRoomNotes();
    final rows = await _db.query(
      'desktop_room_notes',
      columns: ['body'],
      where: 'convo_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return '';
    return (rows.first['body'] as String?) ?? '';
  }

  /// Сохраняет заметку. Пустая строка УДАЛЯЕТ запись, а не хранит пустоту:
  /// иначе «стёр всё» оставляло бы за собой строку в базе.
  Future<void> setDesktopRoomNote({
    required String convoId,
    required String body,
    required int updatedAtMs,
  }) async {
    final id = convoId.trim();
    if (id.isEmpty) return;
    await _ensureDesktopRoomNotes();
    if (body.trim().isEmpty) {
      await _db.delete(
        'desktop_room_notes',
        where: 'convo_id = ?',
        whereArgs: [id],
      );
      return;
    }
    await _db.insert(
      'desktop_room_notes',
      {'convo_id': id, 'body': body, 'updated_at_ms': updatedAtMs},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> groupSettingsGet(String groupId) async {
    final rows = await _db.query(
      'group_settings',
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, Map<String, Object?>>> groupSettingsGetForGroups(
    List<String> groupIds,
  ) async {
    if (groupIds.isEmpty) return const <String, Map<String, Object?>>{};
    final out = <String, Map<String, Object?>>{};
    for (final chunk in AppDb.chunkIds(groupIds)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _db.rawQuery(
        'SELECT * FROM group_settings WHERE group_id IN ($placeholders)',
        chunk,
      );
      for (final row in rows) {
        final groupId = row['group_id'] as String?;
        if (groupId == null || groupId.isEmpty) continue;
        out[groupId] = row;
      }
    }
    return out;
  }

  /// Number of groups OWNED by [ownerProfileId] (monetization §C-3 group cap).
  Future<int> groupOwnedCount(String ownerProfileId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM group_settings WHERE owner_profile_id = ?',
      [ownerProfileId],
    );
    return (rows.isEmpty ? 0 : (rows.first['n'] as num?)?.toInt()) ?? 0;
  }

  /// Number of groups [profileId] is an ACTIVE member of (includes owned).
  Future<int> groupJoinedActiveCount(String profileId) async {
    final rows = await _db.rawQuery(
      "SELECT COUNT(*) AS n FROM group_memberships "
      "WHERE profile_id = ? AND status = 'active'",
      [profileId],
    );
    return (rows.isEmpty ? 0 : (rows.first['n'] as num?)?.toInt()) ?? 0;
  }

  Future<void> groupSettingsUpsert({
    required String groupId,
    required String ownerProfileId,
    String? description,
    String? avatarPath,
    String? avatarHash,
    String? pinnedMessageEventId,
    String? coverId,
    String? frameId,
    String? nameEmoji,
    required String reactionsMode,
    required bool allowText,
    required bool allowMedia,
    required bool allowAddMembers,
    required bool allowPinMessages,
    required bool allowChangeGroupInfo,
    required bool allowChangeTag,
    required bool joinApprovalRequired,
    required int slowModeSeconds,
    required bool chatHistoryVisible,
    required int membershipVersion,
    required int stateVersion,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await groupSettingsGet(groupId);
    await _db.insert('group_settings', {
      'group_id': groupId,
      'owner_profile_id': ownerProfileId,
      'description': description,
      'avatar_path': avatarPath,
      'avatar_hash': avatarHash,
      'pinned_message_event_id': pinnedMessageEventId,
      'cover_id': coverId,
      'frame_id': frameId,
      'name_emoji': nameEmoji,
      'reactions_mode': reactionsMode,
      'allow_text': allowText ? 1 : 0,
      'allow_media': allowMedia ? 1 : 0,
      'allow_add_members': allowAddMembers ? 1 : 0,
      'allow_pin_messages': allowPinMessages ? 1 : 0,
      'allow_change_group_info': allowChangeGroupInfo ? 1 : 0,
      'allow_change_tag': allowChangeTag ? 1 : 0,
      'join_approval_required': joinApprovalRequired ? 1 : 0,
      'slow_mode_seconds': slowModeSeconds,
      'chat_history_visible': chatHistoryVisible ? 1 : 0,
      'membership_version': membershipVersion < 0 ? 0 : membershipVersion,
      'state_version': stateVersion < 0 ? 0 : stateVersion,
      'created_at_ms': existing != null ? existing['created_at_ms'] : now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<RoomCallStateRecord?> roomCallSnapshotGet(String groupId) async {
    final cleanedGroupId = groupId.trim();
    if (cleanedGroupId.isEmpty) return null;
    final rows = await _db.query(
      'room_call_sessions',
      where: 'group_id = ?',
      whereArgs: [cleanedGroupId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final callId = ((row['call_id'] as String?) ?? '').trim();
    final participantRows = callId.isEmpty
        ? const <Map<String, Object?>>[]
        : await _db.query(
            'room_call_participants',
            where: 'group_id = ? AND call_id = ?',
            whereArgs: [cleanedGroupId, callId],
            orderBy: 'joined_at_ms ASC, profile_id ASC, device_id ASC',
          );
    final participants = participantRows
        .map(
          (participantRow) => (
            profileId: ((participantRow['profile_id'] as String?) ?? '').trim(),
            deviceId: ((participantRow['device_id'] as String?) ?? '').trim(),
            joinState:
                ((participantRow['join_state'] as String?) ?? '').trim().isEmpty
                ? 'joined'
                : ((participantRow['join_state'] as String?) ?? '').trim(),
            supportsVideo:
                ((participantRow['supports_video'] as num?)?.toInt() ?? 0) != 0,
            supportsScreenShare:
                ((participantRow['supports_screen_share'] as num?)?.toInt() ??
                    0) !=
                0,
            muted: ((participantRow['muted'] as num?)?.toInt() ?? 0) != 0,
            deafened: ((participantRow['deafened'] as num?)?.toInt() ?? 0) != 0,
            videoEnabled:
                ((participantRow['video_enabled'] as num?)?.toInt() ?? 0) != 0,
            screenShareEnabled:
                ((participantRow['screen_share_enabled'] as num?)?.toInt() ??
                    0) !=
                0,
            speaking: ((participantRow['speaking'] as num?)?.toInt() ?? 0) != 0,
            joinedAtMs: (participantRow['joined_at_ms'] as num?)?.toInt() ?? 0,
            leftAtMs: (participantRow['left_at_ms'] as num?)?.toInt(),
            updatedAtMs:
                (participantRow['updated_at_ms'] as num?)?.toInt() ?? 0,
          ),
        )
        .where(
          (participant) =>
              participant.profileId.isNotEmpty &&
              participant.deviceId.isNotEmpty,
        )
        .toList(growable: false);
    return (
      groupId: cleanedGroupId,
      callId: callId,
      state: ((row['state'] as String?) ?? '').trim().isEmpty
          ? 'active'
          : ((row['state'] as String?) ?? '').trim(),
      mediaType: ((row['media_type'] as String?) ?? '').trim().isEmpty
          ? 'audio'
          : ((row['media_type'] as String?) ?? '').trim(),
      createdByProfileId: ((row['created_by_profile_id'] as String?) ?? '')
          .trim(),
      createdByDeviceId: ((row['created_by_device_id'] as String?) ?? '')
          .trim(),
      stateVersion: (row['state_version'] as num?)?.toInt() ?? 0,
      startedAtMs: (row['started_at_ms'] as num?)?.toInt() ?? 0,
      updatedAtMs: (row['updated_at_ms'] as num?)?.toInt() ?? 0,
      endedAtMs: (row['ended_at_ms'] as num?)?.toInt(),
      expiresAtMs: (row['expires_at_ms'] as num?)?.toInt() ?? 0,
      participants: participants,
    );
  }

  Future<List<String>> roomCallActiveGroupIdsList() async {
    final rows = await _db.query(
      'room_call_sessions',
      columns: <String>['group_id'],
      where: 'state = ? AND ended_at_ms IS NULL',
      whereArgs: const <Object?>['active'],
      orderBy: 'updated_at_ms DESC, group_id ASC',
    );
    return rows
        .map((row) => ((row['group_id'] as String?) ?? '').trim())
        .where((groupId) => groupId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> roomCallSnapshotReplace({
    required String groupId,
    required String callId,
    required String state,
    required String mediaType,
    required String createdByProfileId,
    required String createdByDeviceId,
    required int stateVersion,
    required int startedAtMs,
    required int updatedAtMs,
    int? endedAtMs,
    required int expiresAtMs,
    required List<RoomCallParticipantStateRecord> participants,
  }) async {
    final cleanedGroupId = groupId.trim();
    final cleanedCallId = callId.trim();
    if (cleanedGroupId.isEmpty) return;
    if (cleanedCallId.isEmpty) {
      await roomCallSnapshotDelete(cleanedGroupId);
      return;
    }
    final normalizedParticipants = <String, RoomCallParticipantStateRecord>{};
    for (final participant in participants) {
      final cleanedProfileId = participant.profileId.trim();
      final cleanedDeviceId = participant.deviceId.trim();
      if (cleanedProfileId.isEmpty || cleanedDeviceId.isEmpty) {
        continue;
      }
      final cleanedJoinState = participant.joinState.trim().isEmpty
          ? 'joined'
          : participant.joinState.trim();
      normalizedParticipants['$cleanedProfileId|$cleanedDeviceId'] = (
        profileId: cleanedProfileId,
        deviceId: cleanedDeviceId,
        joinState: cleanedJoinState,
        supportsVideo: participant.supportsVideo,
        supportsScreenShare: participant.supportsScreenShare,
        muted: participant.muted,
        deafened: participant.deafened,
        videoEnabled: participant.videoEnabled,
        screenShareEnabled: participant.screenShareEnabled,
        speaking: participant.speaking,
        joinedAtMs: participant.joinedAtMs < 0 ? 0 : participant.joinedAtMs,
        leftAtMs: participant.leftAtMs,
        updatedAtMs: participant.updatedAtMs < 0 ? 0 : participant.updatedAtMs,
      );
    }

    await _db.transaction((txn) async {
      await txn.delete(
        'room_call_participants',
        where: 'group_id = ?',
        whereArgs: [cleanedGroupId],
      );
      await txn.delete(
        'room_call_sessions',
        where: 'group_id = ?',
        whereArgs: [cleanedGroupId],
      );
      await txn.insert('room_call_sessions', {
        'group_id': cleanedGroupId,
        'call_id': cleanedCallId,
        'state': state.trim().isEmpty ? 'active' : state.trim(),
        'media_type': mediaType.trim().isEmpty ? 'audio' : mediaType.trim(),
        'created_by_profile_id': createdByProfileId.trim(),
        'created_by_device_id': createdByDeviceId.trim(),
        'state_version': stateVersion < 0 ? 0 : stateVersion,
        'started_at_ms': startedAtMs < 0 ? 0 : startedAtMs,
        'updated_at_ms': updatedAtMs < 0 ? 0 : updatedAtMs,
        'ended_at_ms': endedAtMs,
        'expires_at_ms': expiresAtMs < 0 ? 0 : expiresAtMs,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final participant in normalizedParticipants.values) {
        await txn.insert('room_call_participants', {
          'group_id': cleanedGroupId,
          'call_id': cleanedCallId,
          'profile_id': participant.profileId,
          'device_id': participant.deviceId,
          'join_state': participant.joinState,
          'supports_video': participant.supportsVideo ? 1 : 0,
          'supports_screen_share': participant.supportsScreenShare ? 1 : 0,
          'muted': participant.muted ? 1 : 0,
          'deafened': participant.deafened ? 1 : 0,
          'video_enabled': participant.videoEnabled ? 1 : 0,
          'screen_share_enabled': participant.screenShareEnabled ? 1 : 0,
          'speaking': participant.speaking ? 1 : 0,
          'joined_at_ms': participant.joinedAtMs,
          'left_at_ms': participant.leftAtMs,
          'updated_at_ms': participant.updatedAtMs,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> roomCallSnapshotDelete(String groupId) async {
    final cleanedGroupId = groupId.trim();
    if (cleanedGroupId.isEmpty) return;
    await _db.transaction((txn) async {
      await txn.delete(
        'room_call_participants',
        where: 'group_id = ?',
        whereArgs: [cleanedGroupId],
      );
      await txn.delete(
        'room_call_sessions',
        where: 'group_id = ?',
        whereArgs: [cleanedGroupId],
      );
    });
  }

  Future<void> groupAdminsReplace({
    required String groupId,
    required List<String> profileIds,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleaned = profileIds
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList(growable: false);
    await _db.transaction((txn) async {
      await txn.delete(
        'group_admins',
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      for (final profileId in cleaned) {
        await txn.insert('group_admins', {
          'group_id': groupId,
          'profile_id': profileId,
          'created_at_ms': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<List<Map<String, Object?>>> groupAdminsList(String groupId) {
    return _db.query(
      'group_admins',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'created_at_ms ASC',
    );
  }

  Future<void> groupInviteLinkUpsert({
    required String linkId,
    required String groupId,
    required String slug,
    required String createdByProfileId,
    required int createdAtMs,
    required int updatedAtMs,
    int? expiresAtMs,
    int? maxUses,
    int useCount = 0,
    bool requiresApproval = false,
    String allowedRole = 'member',
    required bool revoked,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.query(
      'group_invite_links',
      columns: ['created_at_ms'],
      where: 'link_id = ?',
      whereArgs: [linkId],
      limit: 1,
    );
    await _db.insert('group_invite_links', {
      'link_id': linkId,
      'group_id': groupId,
      'slug': slug,
      'created_by_profile_id': createdByProfileId,
      'expires_at_ms': expiresAtMs != null && expiresAtMs > 0
          ? expiresAtMs
          : null,
      'max_uses': maxUses != null && maxUses > 0 ? maxUses : null,
      'use_count': useCount < 0 ? 0 : useCount,
      'requires_approval': requiresApproval ? 1 : 0,
      'allowed_role': allowedRole.trim().isEmpty
          ? 'member'
          : allowedRole.trim(),
      'is_revoked': revoked ? 1 : 0,
      'created_at_ms': createdAtMs > 0
          ? createdAtMs
          : (existing.isNotEmpty ? existing.first['created_at_ms'] : now),
      'updated_at_ms': updatedAtMs > 0 ? updatedAtMs : now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> groupInviteLinksDeleteForGroup(String groupId) async {
    await _db.delete(
      'group_invite_links',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  Future<List<Map<String, Object?>>> groupInviteLinksList(String groupId) {
    return _db.query(
      'group_invite_links',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'updated_at_ms DESC',
    );
  }

  Future<Map<String, Object?>?> groupInviteLinkGet(String linkId) async {
    final rows = await _db.query(
      'group_invite_links',
      where: 'link_id = ?',
      whereArgs: [linkId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, Object?>?> groupInviteLinkGetBySlug({
    required String slug,
    String? createdByProfileId,
  }) async {
    final cleanedSlug = slug.trim();
    if (cleanedSlug.isEmpty) return null;
    final createdBy = (createdByProfileId ?? '').trim();
    final rows = await _db.query(
      'group_invite_links',
      where: createdBy.isEmpty
          ? 'slug = ?'
          : 'slug = ? AND created_by_profile_id = ?',
      whereArgs: createdBy.isEmpty
          ? <Object?>[cleanedSlug]
          : <Object?>[cleanedSlug, createdBy],
      orderBy: 'updated_at_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> groupInviteLinkSetRevoked({
    required String linkId,
    required bool revoked,
  }) async {
    await _db.update(
      'group_invite_links',
      {
        'is_revoked': revoked ? 1 : 0,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'link_id = ?',
      whereArgs: [linkId],
    );
  }

  Future<void> groupInviteLinkIncrementUseCount(String linkId) async {
    await _db.rawUpdate(
      'UPDATE group_invite_links SET use_count = use_count + 1 WHERE link_id = ?',
      <Object?>[linkId],
    );
  }

  Future<void> convoResetLastEvent({required String convoId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {'last_event_at_ms': 0, 'updated_at_ms': now},
      where: 'convo_id = ?',
      whereArgs: [convoId],
    );
  }

  /// Какие из [eventIds] лежат в переписке [convoId]. Порциями: выделение
  /// может быть длиннее предела параметров SQLite.
  Future<List<String>> eventIdsInConvo({
    required String convoId,
    required List<String> eventIds,
  }) async {
    if (eventIds.isEmpty) return const <String>[];
    final out = <String>[];
    for (final chunk in AppDb.chunkIds(eventIds)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _db.rawQuery(
        'SELECT event_id FROM events '
        'WHERE convo_id = ? AND event_id IN ($placeholders)',
        <Object?>[convoId, ...chunk],
      );
      for (final row in rows) {
        final id = row['event_id'] as String?;
        if (id != null) out.add(id);
      }
    }
    return out;
  }

  Future<List<Map<String, Object?>>> listEventsChronological(
    String convoId, {
    int limit = 500,
  }) {
    return _db.query(
      'events',
      where: 'convo_id = ?',
      whereArgs: [convoId],
      orderBy: 'created_at_ms ASC, rowid ASC',
      limit: limit,
    );
  }

  Future<int?> groupLatestOwnPostAtMs({
    required String groupId,
    required String senderDeviceId,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT created_at_ms FROM events '
      'WHERE convo_id = ? AND sender_device_id = ? '
      'AND event_id LIKE ? AND type IN (?, ?) '
      'ORDER BY created_at_ms DESC, rowid DESC LIMIT 1',
      <Object?>[groupId, senderDeviceId, 'local:%', 'msg', 'att'],
    );
    if (rows.isEmpty) return null;
    return (rows.first['created_at_ms'] as num?)?.toInt();
  }

  /// Most-recent OUTBOUND event time in [convoId], i.e. the latest event whose
  /// `sender_device_id` is our own [senderDeviceId]. Returns `null` when we have
  /// never sent into this conversation. Used by the proactive silence-driven
  /// delivery recovery (FIX E) to tell "we sent, then went quiet" from "this
  /// peer was simply never messaged". Unlike [groupLatestOwnPostAtMs] this is
  /// not constrained to `local:%` ids or msg/att types — any of our own outbound
  /// events (including the empty session-reset wires we mirror) counts as
  /// "we have engaged this peer".
  Future<int?> latestOwnEventAtMsForConvo({
    required String convoId,
    required String senderDeviceId,
  }) async {
    final cid = convoId.trim();
    final sid = senderDeviceId.trim();
    if (cid.isEmpty || sid.isEmpty) return null;
    final rows = await _db.rawQuery(
      'SELECT created_at_ms FROM events '
      'WHERE convo_id = ? AND sender_device_id = ? '
      'ORDER BY created_at_ms DESC, rowid DESC LIMIT 1',
      <Object?>[cid, sid],
    );
    if (rows.isEmpty) return null;
    return (rows.first['created_at_ms'] as num?)?.toInt();
  }

  Future<int?> groupPostingStateNextAllowedAtMs({
    required String groupId,
    required String profileId,
  }) async {
    final cleanedGroupId = groupId.trim();
    final cleanedProfileId = profileId.trim();
    if (cleanedGroupId.isEmpty || cleanedProfileId.isEmpty) {
      return null;
    }
    final rows = await _db.query(
      'group_posting_state',
      columns: ['next_allowed_at_ms'],
      where: 'group_id = ? AND profile_id = ?',
      whereArgs: [cleanedGroupId, cleanedProfileId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['next_allowed_at_ms'] as num?)?.toInt();
  }

  Future<void> groupPostingStateUpsert({
    required String groupId,
    required String profileId,
    int? lastAdmittedAtMs,
    int? nextAllowedAtMs,
    required int updatedAtMs,
  }) async {
    final cleanedGroupId = groupId.trim();
    final cleanedProfileId = profileId.trim();
    if (cleanedGroupId.isEmpty || cleanedProfileId.isEmpty) {
      return;
    }
    await _db.insert('group_posting_state', {
      'group_id': cleanedGroupId,
      'profile_id': cleanedProfileId,
      'last_admitted_at_ms': lastAdmittedAtMs,
      'next_allowed_at_ms': nextAllowedAtMs,
      'updated_at_ms': updatedAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteConversationData({
    required String convoId,
    required bool keepConversationRow,
  }) async {
    await _db.transaction((txn) async {
      // Delete outbox entries linked to local events in this conversation.
      await txn.rawDelete(
        "DELETE FROM outbox WHERE event_id_ref IN (SELECT event_id FROM events WHERE convo_id = ?)",
        [convoId],
      );

      await txn.delete(
        'message_reactions',
        where: 'convo_id = ?',
        whereArgs: [convoId],
      );
      await txn.delete(
        'group_members',
        where: 'group_id = ?',
        whereArgs: [convoId],
      );

      await txn.delete('events', where: 'convo_id = ?', whereArgs: [convoId]);

      if (keepConversationRow) {
        await txn.update(
          'conversations',
          {
            'last_event_at_ms': 0,
            'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'convo_id = ?',
          whereArgs: [convoId],
        );
      } else {
        await txn.delete(
          'conversations',
          where: 'convo_id = ?',
          whereArgs: [convoId],
        );
        // 🔴 НАДГРОБИЕ — в той же транзакции, что и само удаление.
        //
        // Иначе есть окно, в котором чат уже стёрт, а памяти об этом нет, и
        // восстановление вернёт его как ни в чём не бывало. Именно так
        // выглядела полевая жалоба «восстанавливаются чаты, которые я давно
        // удалил»: удаление жёсткое, восстановление — полная замена, и
        // отличить «я это удалил» от «этого не было» было нечем.
        await txn.insert('deletions', {
          'kind': 'convo',
          'target_id': convoId,
          'deleted_at_ms': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        // A fully deleted chat should leave any custom folders it was in.
        await txn.delete(
          'chat_folder_members',
          where: 'convo_id = ?',
          whereArgs: [convoId],
        );
      }
    });
  }

  Future<void> clearConversationHistoryUpTo({
    required String convoId,
    required int cutoffCreatedAtMs,
  }) async {
    await _db.transaction((txn) async {
      final doomed = await txn.query(
        'events',
        columns: ['event_id'],
        where: 'convo_id = ? AND created_at_ms <= ?',
        whereArgs: [convoId, cutoffCreatedAtMs],
      );

      if (doomed.isNotEmpty) {
        final ids = doomed
            .map((r) => r['event_id'] as String)
            .toList(growable: false);
        // Порциями: `doomed` собран без `limit`, поэтому в активном чате с
        // включённым автоудалением он легко перевалит за предел параметров
        // SQLite. Все порции — внутри той же транзакции, поэтому свойство
        // «удалилось всё или ничего» сохраняется.
        for (final chunk in AppDb.chunkIds(ids)) {
          final placeholders = List.filled(chunk.length, '?').join(',');
          await txn.rawDelete(
            'DELETE FROM outbox WHERE event_id_ref IN ($placeholders)',
            chunk,
          );
          await txn.rawDelete(
            'DELETE FROM message_reactions WHERE event_id IN ($placeholders)',
            chunk,
          );
          await txn.rawDelete(
            'DELETE FROM events WHERE event_id IN ($placeholders)',
            chunk,
          );
        }
      }

      final latestRows = await txn.query(
        'events',
        columns: ['created_at_ms'],
        where: 'convo_id = ?',
        whereArgs: [convoId],
        orderBy: 'created_at_ms DESC',
        limit: 1,
      );

      final latestAtMs = latestRows.isNotEmpty
          ? (latestRows.first['created_at_ms'] as num?)?.toInt() ?? 0
          : 0;
      await txn.update(
        'conversations',
        {
          'last_event_at_ms': latestAtMs,
          'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'convo_id = ?',
        whereArgs: [convoId],
      );
    });
  }

  Future<void> deleteRoomLocalData({
    required String groupId,
    required bool keepConversationRow,
  }) async {
    final cleanedGroupId = groupId.trim();
    if (cleanedGroupId.isEmpty) return;
    await _db.transaction((txn) async {
      await txn.rawDelete(
        "DELETE FROM outbox WHERE event_id_ref IN (SELECT event_id FROM events WHERE convo_id = ?)",
        [cleanedGroupId],
      );
      await txn.delete(
        'message_reactions',
        where: 'convo_id = ?',
        whereArgs: [cleanedGroupId],
      );
      await txn.delete(
        'group_members',
        where: 'group_id = ?',
        whereArgs: [cleanedGroupId],
      );
      await txn.delete(
        'events',
        where: 'convo_id = ?',
        whereArgs: [cleanedGroupId],
      );
      await txn.delete(
        'group_admins',
        where: 'group_id = ?',
        whereArgs: [cleanedGroupId],
      );
      await txn.delete(
        'group_memberships',
        where: 'group_id = ?',
        whereArgs: [cleanedGroupId],
      );
      await txn.delete(
        'group_invite_links',
        where: 'group_id = ?',
        whereArgs: [cleanedGroupId],
      );
      await txn.delete(
        'room_call_participants',
        where: 'group_id = ?',
        whereArgs: [cleanedGroupId],
      );
      await txn.delete(
        'room_call_sessions',
        where: 'group_id = ?',
        whereArgs: [cleanedGroupId],
      );
      await txn.delete(
        'group_settings',
        where: 'group_id = ?',
        whereArgs: [cleanedGroupId],
      );

      if (keepConversationRow) {
        await txn.update(
          'conversations',
          {
            'last_event_at_ms': 0,
            'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'convo_id = ?',
          whereArgs: [cleanedGroupId],
        );
      } else {
        await txn.delete(
          'conversations',
          where: 'convo_id = ?',
          whereArgs: [cleanedGroupId],
        );
      }
    });
  }

  Future<void> pruneConversationEventsOlderThan({
    required String convoId,
    required int cutoffCreatedAtMs,
  }) async {
    await _db.transaction((txn) async {
      final doomed = await txn.query(
        'events',
        columns: ['event_id'],
        where: 'convo_id = ? AND created_at_ms < ?',
        whereArgs: [convoId, cutoffCreatedAtMs],
      );

      if (doomed.isNotEmpty) {
        final ids = doomed
            .map((r) => r['event_id'] as String)
            .toList(growable: false);
        // Порциями: `doomed` собран без `limit`, поэтому в активном чате с
        // включённым автоудалением он легко перевалит за предел параметров
        // SQLite. Все порции — внутри той же транзакции, поэтому свойство
        // «удалилось всё или ничего» сохраняется.
        for (final chunk in AppDb.chunkIds(ids)) {
          final placeholders = List.filled(chunk.length, '?').join(',');
          await txn.rawDelete(
            'DELETE FROM outbox WHERE event_id_ref IN ($placeholders)',
            chunk,
          );
          await txn.rawDelete(
            'DELETE FROM message_reactions WHERE event_id IN ($placeholders)',
            chunk,
          );
          await txn.rawDelete(
            'DELETE FROM events WHERE event_id IN ($placeholders)',
            chunk,
          );
        }
      }

      final latestRows = await txn.query(
        'events',
        columns: ['created_at_ms'],
        where: 'convo_id = ?',
        whereArgs: [convoId],
        orderBy: 'created_at_ms DESC',
        limit: 1,
      );

      final latestAtMs = latestRows.isNotEmpty
          ? (latestRows.first['created_at_ms'] as num).toInt()
          : 0;
      await txn.update(
        'conversations',
        {
          'last_event_at_ms': latestAtMs,
          'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'convo_id = ?',
        whereArgs: [convoId],
      );
    });
  }

  Future<Map<String, Object?>?> lastEventForConvo(String convoId) async {
    final rows = await _db.query(
      'events',
      where: 'convo_id = ?',
      whereArgs: [convoId],
      orderBy: 'created_at_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<String?> deviceProfileCached(String deviceId) async {
    final rows = await _db.query(
      'device_profiles',
      columns: ['profile_id'],
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['profile_id'] as String?;
  }

  /// Reverse lookup: the contact profile that owns [deviceId], resolved from
  /// `contact_devices` (populated for every device we have resolved as a send
  /// target). Used by the outbox stuck-recovery watchdog to attribute a stuck
  /// GROUP outbox row — which carries no peer profile on the row (group
  /// sendControlMessage stores a NULL convo_id) — back to its recipient so the
  /// same session-reset recovery that heals 1:1 can target the right peer.
  Future<String?> contactProfileForDeviceId(String deviceId) async {
    final did = deviceId.trim();
    if (did.isEmpty) return null;
    final rows = await _db.query(
      'contact_devices',
      columns: ['contact_profile_id'],
      where: 'device_id = ?',
      whereArgs: [did],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['contact_profile_id'] as String?)?.trim();
  }

  /// Кому принадлежат эти устройства ПО ПЕРЕПИСКЕ — одним запросом.
  ///
  /// `contact_devices` заполняется только тогда, когда устройство разрешено
  /// как ПОЛУЧАТЕЛЬ: мы ему что-то отправляли. Это самое сильное «это не я»,
  /// какое есть у клиента, — сильнее, чем `device_profiles`, куда попадает и
  /// прежний профиль самого владельца после смены удостоверения.
  ///
  /// Возвращает только найденное: отсутствие записи — не ответ «чужое», а
  /// «неизвестно», и обращаться с ним нужно как с неизвестным.
  Future<Map<String, String>> contactProfilesForDeviceIds(
    Iterable<String> deviceIds,
  ) async {
    final ids = deviceIds
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const <String, String>{};
    final marks = List<String>.filled(ids.length, '?').join(',');
    final rows = await _db.query(
      'contact_devices',
      columns: ['device_id', 'contact_profile_id'],
      where: 'device_id IN ($marks)',
      whereArgs: ids,
    );
    final out = <String, String>{};
    for (final row in rows) {
      final did = ((row['device_id'] as String?) ?? '').trim();
      final pid = ((row['contact_profile_id'] as String?) ?? '').trim();
      if (did.isEmpty || pid.isEmpty) continue;
      out[did] = pid;
    }
    return out;
  }

  Future<List<String>> deviceIdsForProfile(String profileId) async {
    final pid = profileId.trim();
    if (pid.isEmpty) return const <String>[];
    final rows = await _db.query(
      'device_profiles',
      columns: ['device_id'],
      where: 'profile_id = ?',
      whereArgs: [pid],
      orderBy: 'updated_at_ms DESC',
    );
    return rows
        .map((r) => ((r['device_id'] as String?) ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<void> deviceProfileUpsert({
    required String deviceId,
    required String profileId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert('device_profiles', {
      'device_id': deviceId,
      'profile_id': profileId,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Best-effort migration when a device_id is re-bound to a new profile_id on the server.
  ///
  /// This can happen when switching servers/APKs or after a server reset.
  /// If we keep the old mapping, we end up with chats that cannot send (profile not found).
  ///
  /// This migrates local rows only when it is safe (i.e., destination does not already exist).
  Future<bool> rebindProfileId({
    required String oldProfileId,
    required String newProfileId,
  }) async {
    if (oldProfileId == newProfileId) return true;

    final oldReq = 'req:$oldProfileId';
    final newReq = 'req:$newProfileId';

    return _db.transaction((txn) async {
      Future<bool> exists(
        String table,
        String where,
        List<Object?> args,
      ) async {
        final rows = await txn.query(
          table,
          columns: ['1'],
          where: where,
          whereArgs: args,
          limit: 1,
        );
        return rows.isNotEmpty;
      }

      // Avoid collisions.
      final newContactExists = await exists(
        'contacts',
        'contact_profile_id = ?',
        [newProfileId],
      );
      final newReqExists = await exists('requests', 'contact_profile_id = ?', [
        newProfileId,
      ]);
      final newConvoExists = await exists('conversations', 'convo_id = ?', [
        newProfileId,
      ]);
      final newReqConvoExists = await exists('conversations', 'convo_id = ?', [
        newReq,
      ]);
      final newMetaExists = await exists('profile_meta', 'profile_id = ?', [
        newProfileId,
      ]);

      if (newContactExists ||
          newReqExists ||
          newConvoExists ||
          newReqConvoExists ||
          newMetaExists) {
        return false;
      }

      // Contacts + cached device keys.
      await txn.rawUpdate(
        'UPDATE contacts SET contact_profile_id = ? WHERE contact_profile_id = ?',
        [newProfileId, oldProfileId],
      );
      await txn.rawUpdate(
        'UPDATE contact_devices SET contact_profile_id = ? WHERE contact_profile_id = ?',
        [newProfileId, oldProfileId],
      );

      // Requests.
      await txn.rawUpdate(
        'UPDATE requests SET contact_profile_id = ? WHERE contact_profile_id = ?',
        [newProfileId, oldProfileId],
      );

      // Conversations + events.
      await txn.rawUpdate(
        'UPDATE conversations SET convo_id = ?, peer_profile_id = ? WHERE convo_id = ?',
        [newProfileId, newProfileId, oldProfileId],
      );
      await txn.rawUpdate(
        'UPDATE conversations SET convo_id = ?, peer_profile_id = ? WHERE convo_id = ?',
        [newReq, newProfileId, oldReq],
      );

      await txn.rawUpdate('UPDATE events SET convo_id = ? WHERE convo_id = ?', [
        newProfileId,
        oldProfileId,
      ]);
      await txn.rawUpdate('UPDATE events SET convo_id = ? WHERE convo_id = ?', [
        newReq,
        oldReq,
      ]);

      await txn.rawUpdate(
        'UPDATE pending_no_device_send SET profile_id = ? WHERE profile_id = ?',
        [newProfileId, oldProfileId],
      );

      // Profile meta cache.
      await txn.rawUpdate(
        'UPDATE profile_meta SET profile_id = ? WHERE profile_id = ?',
        [newProfileId, oldProfileId],
      );

      return true;
    });
  }

  Future<Map<String, Object?>?> sessionGet(String peerDeviceId) async {
    final rows = await _db.query(
      'sessions',
      where: 'peer_device_id = ?',
      whereArgs: [peerDeviceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> sessionUpsert({
    required String peerDeviceId,
    required String rootKeyB64,
    required String sendChainKeyB64,
    required String recvChainKeyB64,
    required int sendCount,
    required int recvCount,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await sessionGet(peerDeviceId);
    await _db.insert('sessions', {
      'peer_device_id': peerDeviceId,
      'root_key_b64': rootKeyB64,
      'send_chain_key_b64': sendChainKeyB64,
      'recv_chain_key_b64': recvChainKeyB64,
      'send_count': sendCount,
      'recv_count': recvCount,
      'created_at_ms': existing?['created_at_ms'] ?? now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> sessionDelete(String peerDeviceId) async {
    await _db.delete(
      'sessions',
      where: 'peer_device_id = ?',
      whereArgs: [peerDeviceId],
    );
  }

  Future<bool> inboxHasSeen(String msgId) async {
    final rows = await _db.query(
      'inbox_seen',
      columns: ['msg_id'],
      where: 'msg_id = ?',
      whereArgs: [msgId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> inboxMarkSeen(String msgId) async {
    await _db.insert('inbox_seen', {
      'msg_id': msgId,
      'seen_at_ms': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // ---- Inbound quarantine (session-recovery hardening) ----------------------
  // Park an inbound ciphertext that could not be decrypted yet so it can be
  // re-decrypted after the session with [senderDeviceId] heals. Idempotent on
  // msg_id (re-delivery of the same message keeps the original row/attempts).
  /// Кладёт сигнал звонка в очередь, переживающую смерть изолята.
  ///
  /// Зовётся ТОЛЬКО фоновым изолятом: главный обрабатывает сигнал сам и в
  /// очереди не нуждается.
  ///
  /// `INSERT OR REPLACE` по `signal_id`: повторный пуш того же сигнала — не
  /// повод для второй строки. Дедуп на стороне обработки всё равно есть, но
  /// пусть очередь не пухнет.
  Future<void> pendingCallSignalUpsert({
    required String signalId,
    required String callId,
    required String callAttemptId,
    required String action,
    required String fromProfileId,
    required String? fromDeviceId,
    required String payloadJson,
    required int createdAtMs,
    required int nowMs,
  }) async {
    final id = signalId.trim();
    if (id.isEmpty) return;
    await _db.insert('pending_call_signals', {
      'signal_id': id,
      'call_id': callId.trim(),
      'call_attempt_id': callAttemptId.trim(),
      'action': action.trim(),
      'from_profile_id': fromProfileId.trim(),
      'from_device_id': (fromDeviceId ?? '').trim().isEmpty
          ? null
          : fromDeviceId!.trim(),
      'payload_json': payloadJson,
      'created_at_ms': createdAtMs,
      'stored_at_ms': nowMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Отдаёт очередь сигналов звонка и СРАЗУ удаляет отданное.
  ///
  /// 🔴 Порядок — по времени записи: приглашение обязано примениться раньше
  /// предложения, иначе соединение не соберётся (К-6 ТЗ).
  ///
  /// 🔴 Удаление именно здесь, а не после успешной обработки. Строка, которую
  /// не удалили, воскресает фантомным звонком на каждом запуске; повторно
  /// обработать сигнал безвредно (дедуп по `signalId`), а вот вечно звонящий
  /// призрак — нет.
  Future<List<Map<String, Object?>>> pendingCallSignalsDrain() async {
    final rows = await _db.query(
      'pending_call_signals',
      orderBy: 'stored_at_ms ASC, rowid ASC',
    );
    if (rows.isEmpty) return const <Map<String, Object?>>[];
    await _db.delete('pending_call_signals');
    return rows;
  }

  /// Чистит очередь от строк старше [olderThanMs].
  Future<void> pendingCallSignalsPrune(int olderThanMs) async {
    await _db.delete(
      'pending_call_signals',
      where: 'stored_at_ms < ?',
      whereArgs: <Object?>[olderThanMs],
    );
  }

  Future<void> inboxQuarantineUpsert({
    required String msgId,
    required String? senderDeviceId,
    required String ciphertextB64,
    required int nowMs,
    String? attestedFromDeviceId,
  }) async {
    final attested = (attestedFromDeviceId ?? '').trim();
    final row = <String, Object?>{
      'msg_id': msgId,
      'sender_device_id': (senderDeviceId ?? '').trim().isEmpty
          ? null
          : senderDeviceId!.trim(),
      'ciphertext_b64': ciphertextB64,
      'created_at_ms': nowMs,
      'attempts': 0,
      'last_attempt_at_ms': 0,
    };
    if (attested.isEmpty) {
      await _db.insert('inbox_quarantine', row,
          conflictAlgorithm: ConflictAlgorithm.ignore);
      return;
    }
    try {
      await _db.insert(
        'inbox_quarantine',
        {...row, 'attested_from_device_id': attested},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (_) {
      // Парковка не имеет права упасть (это путь «без потерь»): база без новой
      // колонки — паркуем без слова реле, как до 17.09.
      await _db.insert('inbox_quarantine', row,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<int> inboxQuarantineCountForSender(String senderDeviceId) async {
    final sid = senderDeviceId.trim();
    if (sid.isEmpty) return 0;
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM inbox_quarantine WHERE sender_device_id = ?',
      [sid],
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<int> inboxQuarantineCountAll() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM inbox_quarantine',
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  /// Compact delivery-health snapshot for the diagnostics screen.
  ///
  /// Every number is derived from tables we already maintain, so this costs one
  /// round of COUNTs and adds no bookkeeping. These are exactly the figures
  /// that were missing during the 2026-07-19 investigation, when the only way
  /// to tell whether the self-healing machinery had EVER fired was to attach a
  /// USB syslog and hope the user could reproduce live.
  ///
  /// - `quarantined`  — wires parked because they would not decrypt.
  /// - `nacked`       — of those, how many the sender has been told about
  ///                    (Epic A). `quarantined > 0` with `nacked == 0` is the
  ///                    exact silent-stall this work fixed.
  /// - `receipts_queued` — receipts (incl. NACKs) still waiting to flush.
  /// - `outbox_pending`  — our own messages not yet handed to the relay.
  Future<Map<String, int>> deliveryHealthCounters() async {
    Future<int> countOf(String sql) async {
      try {
        final rows = await _db.rawQuery(sql);
        if (rows.isEmpty) return 0;
        final v = rows.first.values.first;
        return v is num ? v.toInt() : 0;
      } catch (_) {
        // A missing table on an odd migration path must not break diagnostics.
        return 0;
      }
    }

    return <String, int>{
      'quarantined': await countOf('SELECT COUNT(*) FROM inbox_quarantine'),
      'nacked': await countOf(
        'SELECT COUNT(*) FROM inbox_quarantine WHERE nacked_at_ms > 0',
      ),
      'receipts_queued': await countOf(
        'SELECT COUNT(*) FROM pending_receipts',
      ),
      'outbox_pending': await countOf(
        "SELECT COUNT(*) FROM outbox WHERE state = 'pending'",
      ),
      // И-2c: lifetime count of messages the inbound journal RESCUED — a
      // ciphertext that could no longer decrypt (ratchet advanced) whose
      // plaintext survived in the journal. After И-2 the journal's put is
      // atomic with the advance, so this measures the residual advance→
      // event-insert (attribution) gap the journal still legitimately covers.
      'journal_recovered_total': await localKvCounterGet('i2_journal_recovered'),
    };
  }

  Future<List<Map<String, Object?>>> inboxQuarantineListForSender(
    String senderDeviceId, {
    int limit = 200,
  }) async {
    final sid = senderDeviceId.trim();
    if (sid.isEmpty) return const <Map<String, Object?>>[];
    return _db.query(
      'inbox_quarantine',
      where: 'sender_device_id = ?',
      whereArgs: [sid],
      orderBy: 'created_at_ms ASC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> inboxQuarantineListAll({
    int limit = 500,
  }) async {
    return _db.query(
      'inbox_quarantine',
      orderBy: 'created_at_ms ASC',
      limit: limit,
    );
  }

  /// Distinct (non-null) sender device IDs that currently have at least one
  /// quarantined message, each with the timestamp of its OLDEST parked entry
  /// and the parked count. Rows with a null/empty sender are excluded (they
  /// can't be re-pinged — there is no device to reset a session with). Used by
  /// the self-healing recovery sweep (FIX D) to decide which peers are stuck.
  /// Returned as `{sender_device_id, oldest_ms, cnt}`, oldest-stuck first.
  ///
  /// PHANTOM-CHURN FIX (2026-06-25): parked rows whose `attempts` have reached
  /// [maxForcePingAttempts] are EXCLUDED from the result, so the recovery sweep
  /// stops proactively force-reset-pinging a peer whose only stuck messages are
  /// permanently dead (a genuine ratchet bad-state encrypted under a lost chain
  /// can NEVER decrypt no matter how many handshakes we send — re-pinging it just
  /// churns reset/confirm frames the user sees as constant notifications). A
  /// sender that still has at least one recoverable (attempts < cap) parked entry
  /// is still returned, so a genuine TRANSIENT desync is still healed. The dead
  /// rows keep being replayed SILENTLY by the sweep (no proactive ping) until
  /// [inboxQuarantinePrune] ages them out.
  Future<List<Map<String, Object?>>> inboxQuarantineSendersWithOldest({
    int maxForcePingAttempts = kInboxQuarantineForcePingMaxAttempts,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT sender_device_id, '
      'MIN(created_at_ms) AS oldest_ms, '
      'COUNT(*) AS cnt '
      'FROM inbox_quarantine '
      'WHERE sender_device_id IS NOT NULL AND sender_device_id != \'\' '
      'AND attempts < ? '
      'GROUP BY sender_device_id '
      'ORDER BY oldest_ms ASC',
      [maxForcePingAttempts],
    );
    return rows;
  }

  /// Снимает провод с парковки. Возвращает `true`, если строка там была —
  /// вызывающему это нужно, чтобы отличить снятие настоящей парковки от
  /// холостого вызова и не засорять журнал (см. `quarantine_orphan_cleared`).
  Future<bool> inboxQuarantineDelete(String msgId) async {
    final removed = await _db.delete(
      'inbox_quarantine',
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    return removed > 0;
  }

  Future<void> inboxQuarantineMarkAttempt({
    required String msgId,
    required int nowMs,
  }) async {
    await _db.rawUpdate(
      'UPDATE inbox_quarantine SET attempts = attempts + 1, last_attempt_at_ms = ? WHERE msg_id = ?',
      [nowMs, msgId],
    );
  }

  /// Atomically claims the right to send a `nack_undecryptable` for a wire that
  /// is parked in quarantine. Returns true ONLY to the caller that won the
  /// claim; everyone else gets false and stays silent.
  ///
  /// The claim is the UPDATE itself (guarded by `nacked_at_ms <= cutoff`), so
  /// two concurrent sweeps cannot both emit. [reNackAfterMs] re-arms the claim
  /// after a long interval — a NACK can be lost in transit, and a wire that is
  /// STILL undecryptable much later deserves one more nudge — but it is long
  /// enough that the periodic replay sweep can never turn into a NACK storm.
  ///
  /// Persistent by design: a wire sits quarantined across launches, so an
  /// in-memory marker would re-NACK the whole backlog on every cold start.
  /// STAGE 5 of TZ_INVARIANTS_2026-07-20 — bound the recovery time.
  ///
  /// [reNackAfterMs] was 24 hours. Combined with the per-device gate (one NACK
  /// per 10 minutes) that made a stuck backlog unrecoverable for a day: a live
  /// capture showed 18 wires re-failing every second with ZERO NACKs, because
  /// every one had already been claimed and the claim does not expire until
  /// tomorrow. "Recovery happens eventually" was, in practice, "never today".
  ///
  /// It is now the same 10 minutes as the device gate, which is the guard that
  /// actually paces this path. One NACK per peer per 10 minutes still cannot
  /// storm — and one NACK already makes the sender resend EVERY stuck wire for
  /// that peer, so the ceiling on recovery becomes ~10 minutes instead of a day.
  Future<bool> inboxQuarantineClaimNack({
    required String msgId,
    required int nowMs,
    int reNackAfterMs = 10 * 60 * 1000,
  }) async {
    final cutoff = nowMs - reNackAfterMs;
    // `nacked_at_ms = 0` (never NACKed) is ALWAYS claimable and is checked
    // explicitly: relying on `0 <= cutoff` would silently refuse the very first
    // claim whenever `cutoff` is negative.
    final changed = await _db.rawUpdate(
      'UPDATE inbox_quarantine SET nacked_at_ms = ? '
      'WHERE msg_id = ? AND (nacked_at_ms = 0 OR nacked_at_ms <= ?)',
      [nowMs, msgId, cutoff],
    );
    return changed > 0;
  }

  // Bound the table: drop rows that have exhausted their replay budget (PHANTOM-
  // CHURN FIX 2026-06-25), then rows older than [maxAgeMs], then trim to the
  // newest [maxRows] if still over capacity. Returns the number of rows removed.
  Future<int> inboxQuarantinePrune({
    required int nowMs,
    int maxAgeMs = 30 * 24 * 60 * 60 * 1000,
    int maxRows = 2000,
    int maxAttempts = kInboxQuarantineMaxReplayAttempts,
  }) async {
    var removed = 0;
    // Drop rows that have failed replay [maxAttempts] times — a ciphertext only
    // accrues that many failures if it can never decrypt (permanently dead /
    // old-chain). For a genuine bad-state failure it was already ACKed at park
    // time, so nothing recoverable is lost; the cap is generous enough that a
    // transient desync heals long before reaching it.
    removed += await _db.delete(
      'inbox_quarantine',
      where: 'attempts >= ?',
      whereArgs: [maxAttempts],
    );
    removed += await _db.delete(
      'inbox_quarantine',
      where: 'created_at_ms < ?',
      whereArgs: [nowMs - maxAgeMs],
    );
    final countRows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM inbox_quarantine',
    );
    final count = (countRows.first['c'] as num?)?.toInt() ?? 0;
    if (count > maxRows) {
      removed += await _db.rawDelete(
        'DELETE FROM inbox_quarantine WHERE msg_id IN ('
        'SELECT msg_id FROM inbox_quarantine ORDER BY created_at_ms ASC LIMIT ?)',
        [count - maxRows],
      );
    }
    return removed;
  }

  // ---- Durable ACK queue ----------------------------------------------------
  // Park an ACK that could not be delivered to the relay so it is retried on
  // the next connection. Keyed by msg_id (idempotent).
  Future<void> pendingAckUpsert({
    required String msgId,
    required int seq,
    required int nowMs,
  }) async {
    await _db.insert('pending_acks', {
      'msg_id': msgId,
      'seq': seq,
      'created_at_ms': nowMs,
      // Keep the original enqueue time on a repeated failed attempt (the seq
      // for a given msg_id is fixed), so age-ordering stays stable.
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> pendingAckDelete(String msgId) async {
    await _db.delete('pending_acks', where: 'msg_id = ?', whereArgs: [msgId]);
  }

  Future<List<Map<String, Object?>>> pendingAckList({int limit = 500}) async {
    return _db.query(
      'pending_acks',
      orderBy: 'created_at_ms ASC',
      limit: limit,
    );
  }

  Future<int> pendingAckCount() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM pending_acks');
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<void> attachmentUpsert({
    required String blobId,
    required String fileKeyB64,
    required String accessTokenB64,
    required String? mime,
    required int plaintextSizeBytes,
    required int ciphertextSizeBytes,
    required int expiresAtMs,
    required int createdAtMs,
  }) async {
    await _db.insert('attachments', {
      'blob_id': blobId,
      'file_key_b64': fileKeyB64,
      'access_token_b64': accessTokenB64,
      'mime': mime,
      'plaintext_size_bytes': plaintextSizeBytes,
      'ciphertext_size_bytes': ciphertextSizeBytes,
      'expires_at_ms': expiresAtMs,
      'created_at_ms': createdAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>?> attachmentGet(String blobId) async {
    final rows = await _db.query(
      'attachments',
      where: 'blob_id = ?',
      whereArgs: [blobId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Every attachment `blob_id` we hold metadata for — i.e. the set of media
  /// that a real chat message references. The attachment-cache prune uses this
  /// as a PROTECTED SET so it can never evict media the user actually has in
  /// their history (the local file is the only copy once the relay drops the
  /// blob past its TTL, and for own-sent media there is no re-download at all).
  /// Populated on both send and receive; never cascade-deleted, so it survives
  /// as a durable "keep this" list. Only truly orphaned files may be pruned.
  Future<Set<String>> attachmentAllBlobIds() async {
    final rows = await _db.query('attachments', columns: ['blob_id']);
    return rows
        .map((r) => (r['blob_id'] as String?)?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  /// Blob ids whose ciphertext is still fetchable from the relay: a real
  /// remote blob (`local:` ids never touch the relay) whose TTL has not
  /// expired yet. A cached file for one of these is genuinely re-downloadable;
  /// everything else referenced by history is the ONLY copy (TZ E0 — the
  /// manual "clear cache" must never delete those). `expires_at_ms = 0`
  /// (unknown expiry, e.g. inbound metadata upserts) is treated as NOT live —
  /// conservative by construction.
  Future<Set<String>> attachmentLiveRemoteBlobIds({required int nowMs}) async {
    final rows = await _db.query(
      'attachments',
      columns: ['blob_id'],
      where: "expires_at_ms > ? AND blob_id NOT LIKE 'local:%'",
      whereArgs: [nowMs],
    );
    return rows
        .map((r) => (r['blob_id'] as String?)?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> insertEvent({
    required String eventId,
    required String convoId,
    required String type,
    required String senderDeviceId,
    required String ciphertextB64,
    String? localCiphertextB64,
    required int createdAtMs,
    String localState = 'received',
    String? payloadEventId,
    int? scheduledAtMs,
    // When set, the row is inserted already-read (read_at_ms). Used for my own
    // messages that arrive from another device so they never count as unread.
    int? readAtMs,
  }) async {
    await _db.insert('events', {
      'event_id': eventId,
      'convo_id': convoId,
      'type': type,
      'sender_device_id': senderDeviceId,
      'ciphertext_b64': ciphertextB64,
      'local_ciphertext_b64': localCiphertextB64,
      'created_at_ms': createdAtMs,
      'local_state': localState,
      'payload_event_id': payloadEventId,
      'read_at_ms': readAtMs,
      'scheduled_at_ms': scheduledAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> callJournalUpsert({required CallJournalEntry entry}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.query(
      'call_journal',
      columns: ['created_at_ms', 'acknowledged_at_ms'],
      where: 'call_attempt_id = ?',
      whereArgs: [entry.callAttemptId],
      limit: 1,
    );
    final existingRow = existing.isEmpty ? null : existing.first;
    final createdAtMs = ((existingRow?['created_at_ms'] as num?) ?? nowMs)
        .toInt();
    final acknowledgedAtMs = (existingRow?['acknowledged_at_ms'] as num?)
        ?.toInt();
    await _db.insert(
      'call_journal',
      entry.toDbMap(
        nowMs: nowMs,
        createdAtMs: createdAtMs,
        acknowledgedAtMs: acknowledgedAtMs,
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CallJournalEntry?> callJournalGetByAttemptId(
    String callAttemptId,
  ) async {
    final rows = await _db.query(
      'call_journal',
      where: 'call_attempt_id = ?',
      whereArgs: [callAttemptId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CallJournalEntry.fromDbRow(rows.first);
  }

  Future<void> callJournalMarkMissedAcknowledged({String? convoId}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final where = <String>[
      'result = ?',
      '(acknowledged_at_ms IS NULL OR acknowledged_at_ms <= 0)',
    ];
    final whereArgs = <Object?>[CallRecordResult.missed.value];
    final trimmedConvoId = convoId?.trim() ?? '';
    if (trimmedConvoId.isNotEmpty) {
      where.add('convo_id = ?');
      whereArgs.add(trimmedConvoId);
    }
    await _db.update(
      'call_journal',
      {'acknowledged_at_ms': nowMs, 'updated_at_ms': nowMs},
      where: where.join(' AND '),
      whereArgs: whereArgs,
    );
  }

  Future<List<Map<String, Object?>>> callJournalList({
    String? convoId,
    int limit = 100,
  }) {
    if (convoId == null || convoId.trim().isEmpty) {
      return _db.query(
        'call_journal',
        orderBy: 'ended_at_ms DESC',
        limit: limit,
      );
    }
    return _db.query(
      'call_journal',
      where: 'convo_id = ?',
      whereArgs: [convoId.trim()],
      orderBy: 'ended_at_ms DESC',
      limit: limit,
    );
  }

  Future<void> updateEventLocalCiphertext({
    required String eventId,
    required String localCiphertextB64,
  }) async {
    await _db.update(
      'events',
      {'local_ciphertext_b64': localCiphertextB64},
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
  }

  Future<void> updateEventEnvelope({
    required String eventId,
    required String ciphertextB64,
    String? localCiphertextB64,
    required int createdAtMs,
    required String localState,
    String? payloadEventId,
  }) async {
    await _db.update(
      'events',
      {
        'ciphertext_b64': ciphertextB64,
        'local_ciphertext_b64': localCiphertextB64,
        'created_at_ms': createdAtMs,
        'local_state': localState,
        'payload_event_id': payloadEventId,
      },
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
  }

  Future<void> updateEventLocalState({
    required String eventId,
    required String localState,
    String? reasonCode,
  }) async {
    final row = await _db.query(
      'events',
      columns: ['event_id', 'convo_id', 'local_state'],
      where: 'event_id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    if (row.isEmpty) return;
    final previousState = row.first['local_state'] as String?;
    final convoId = row.first['convo_id'] as String?;
    // 🔴 ЗАЩИТА ОТ ОТКАТА (02.09.2026, полевая жалоба: «галочка сменилась на
    // часики снова»). Этот метод писал состояние БЕЗУСЛОВНО, и он же —
    // единственный путь, которым `outboxMarkSending` двигает индикатор. Копия
    // сообщения для второго устройства собеседника продолжает свои попытки
    // уже после того, как первая копия подтверждена, и откатывала галочку
    // обратно в часы. Проверка направления теперь здесь, в одном месте для
    // всех вызывающих, а не самодельная в каждом.
    if (!MessageLocalState.canPromote(
      from: previousState ?? '',
      to: localState,
    )) {
      return;
    }
    await _db.update(
      'events',
      {'local_state': localState},
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
    await _recordMessageStateTransition(
      localEventId: eventId,
      previousState: previousState,
      newState: localState,
      reasonCode: reasonCode,
      convoId: convoId,
    );
  }

  Future<void> updateLocalStateByPayloadEventId({
    required String payloadEventId,
    required String localState,
    String? reasonCode,
  }) async {
    final rows = await _db.query(
      'events',
      columns: ['event_id', 'convo_id', 'local_state'],
      where: 'payload_event_id = ?',
      whereArgs: [payloadEventId],
    );
    for (final row in rows) {
      final eventId = row['event_id'] as String?;
      if (eventId == null || eventId.isEmpty) continue;
      final previousState = row['local_state'] as String? ?? '';
      if (!MessageLocalState.canPromote(from: previousState, to: localState)) {
        continue;
      }
      final convoId = row['convo_id'] as String?;
      await _db.update(
        'events',
        {'local_state': localState},
        where: 'event_id = ?',
        whereArgs: [eventId],
      );
      await _recordMessageStateTransition(
        localEventId: eventId,
        previousState: previousState,
        newState: localState,
        reasonCode: reasonCode,
        convoId: convoId,
      );
    }
  }

  /// Есть ли в переписке [convoId] сообщение с логическим id [payloadEventId].
  ///
  /// Строже, чем [convoIdForPayloadEventId]: та ищет по всем перепискам и
  /// берёт первую попавшуюся, а синхронизации истории нужен ответ ровно про
  /// ЭТУ переписку. Индекс `events_payload_id_idx` делает запрос дешёвым.
  Future<bool> eventExistsForPayload({
    required String convoId,
    required String payloadEventId,
  }) async {
    final id = payloadEventId.trim();
    if (id.isEmpty) return false;
    final rows = await _db.query(
      'events',
      columns: ['event_id'],
      where: 'payload_event_id = ? AND convo_id = ?',
      whereArgs: [id, convoId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Сколько дублей убрала миграция 68 в этом процессе — для журнала.
  static int? debugLastPayloadDedupeRemoved;

  /// Убирает строки, которые описывают ОДНО И ТО ЖЕ сообщение.
  ///
  /// Одно сообщение — это одинаковые переписка, логический id и тип. Такие
  /// строки появлялись, когда синхронизация истории приносила копию под
  /// другим `event_id`.
  ///
  /// Остаётся строка, вставленная ПЕРВОЙ (наименьший `rowid`): обычно это
  /// принятая вживую — у неё отметка прочтения и всё, что приложение
  /// успело к ней привязать. Если отметки прочтения у неё нет, а у дубля
  /// есть, она переносится: иначе прочитанное снова стало бы непрочитанным.
  /// Реакции, вложения и квитанции привязаны к логическому id или к блобу,
  /// а не к строке, поэтому удаление дубля их не задевает.
  ///
  /// 🔴 Без оконных функций: на Android 7 (minSdk 24) системный SQLite 3.9,
  /// а они появились в 3.25.
  static Future<int> dedupeEventsByPayload(DatabaseExecutor db) async {
    final groups = await db.rawQuery('''
SELECT convo_id, payload_event_id, type,
       MIN(rowid) AS keep_rowid,
       MAX(read_at_ms) AS max_read
FROM events
WHERE payload_event_id IS NOT NULL AND payload_event_id <> ''
GROUP BY convo_id, payload_event_id, type
HAVING COUNT(*) > 1;
''');
    var removed = 0;
    for (final g in groups) {
      final keep = (g['keep_rowid'] as num).toInt();
      final maxRead = (g['max_read'] as num?)?.toInt();
      if (maxRead != null) {
        await db.rawUpdate(
          'UPDATE events SET read_at_ms = ? WHERE rowid = ? AND read_at_ms IS NULL;',
          [maxRead, keep],
        );
      }
      removed += await db.rawDelete(
        'DELETE FROM events WHERE convo_id = ? AND payload_event_id = ? '
        'AND type = ? AND rowid <> ?;',
        [g['convo_id'], g['payload_event_id'], g['type'], keep],
      );
    }
    return removed;
  }

  Future<String?> convoIdForPayloadEventId(String payloadEventId) async {
    final cleanedPayloadEventId = payloadEventId.trim();
    if (cleanedPayloadEventId.isEmpty) return null;
    final rows = await _db.query(
      'events',
      columns: ['convo_id'],
      where: 'payload_event_id = ?',
      whereArgs: [cleanedPayloadEventId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['convo_id'] as String?;
  }

  Future<void> roomMessageReceiptUpsert({
    required String payloadEventId,
    required String readerProfileId,
    String? readerDeviceId,
    required String status,
    required int updatedAtMs,
  }) async {
    final cleanedPayloadEventId = payloadEventId.trim();
    final cleanedReaderProfileId = readerProfileId.trim();
    final normalizedStatus = MessageReceiptState.normalize(status);
    if (cleanedPayloadEventId.isEmpty || cleanedReaderProfileId.isEmpty) {
      return;
    }
    if (normalizedStatus != MessageReceiptState.delivered &&
        normalizedStatus != MessageReceiptState.read) {
      return;
    }

    final existing = await _db.query(
      'room_message_receipts',
      columns: ['status', 'updated_at_ms'],
      where: 'payload_event_id = ? AND reader_profile_id = ?',
      whereArgs: [cleanedPayloadEventId, cleanedReaderProfileId],
      limit: 1,
    );

    var effectiveStatus = normalizedStatus;
    var effectiveUpdatedAtMs = updatedAtMs;
    if (existing.isNotEmpty) {
      final existingRow = existing.first;
      final existingStatus = MessageReceiptState.normalize(
        (existingRow['status'] as String?) ?? '',
      );
      final existingUpdatedAtMs =
          (existingRow['updated_at_ms'] as num?)?.toInt() ?? 0;
      if (!MessageReceiptState.canPromote(
        from: existingStatus,
        to: normalizedStatus,
      )) {
        effectiveStatus = existingStatus;
      }
      if (existingUpdatedAtMs > effectiveUpdatedAtMs) {
        effectiveUpdatedAtMs = existingUpdatedAtMs;
      }
    }

    final cleanedReaderDeviceId = readerDeviceId?.trim();
    await _db.insert('room_message_receipts', {
      'payload_event_id': cleanedPayloadEventId,
      'reader_profile_id': cleanedReaderProfileId,
      'reader_device_id':
          cleanedReaderDeviceId == null || cleanedReaderDeviceId.isEmpty
          ? null
          : cleanedReaderDeviceId,
      'status': effectiveStatus,
      'updated_at_ms': effectiveUpdatedAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RoomMessageReceiptRecord>> roomMessageReceiptList(
    String payloadEventId,
  ) async {
    final cleanedPayloadEventId = payloadEventId.trim();
    if (cleanedPayloadEventId.isEmpty) {
      return const <RoomMessageReceiptRecord>[];
    }
    final rows = await _db.query(
      'room_message_receipts',
      columns: [
        'payload_event_id',
        'reader_profile_id',
        'reader_device_id',
        'status',
        'updated_at_ms',
      ],
      where: 'payload_event_id = ?',
      whereArgs: [cleanedPayloadEventId],
      orderBy: 'updated_at_ms DESC, reader_profile_id ASC',
    );
    return rows
        .map(
          (row) => (
            payloadEventId: ((row['payload_event_id'] as String?) ?? '').trim(),
            readerProfileId: ((row['reader_profile_id'] as String?) ?? '')
                .trim(),
            readerDeviceId: (row['reader_device_id'] as String?)?.trim(),
            status: MessageReceiptState.normalize(
              (row['status'] as String?) ?? '',
            ),
            updatedAtMs: (row['updated_at_ms'] as num?)?.toInt() ?? 0,
          ),
        )
        .where(
          (row) =>
              row.payloadEventId.isNotEmpty && row.readerProfileId.isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<RoomMessageReceiptSummary> roomMessageReceiptSummary(
    String payloadEventId,
  ) async {
    final rows = await roomMessageReceiptList(payloadEventId);
    final deliveredByProfileIds = <String>[];
    final deliveredSeen = <String>{};
    final readByProfileIds = <String>[];
    final readSeen = <String>{};

    for (final row in rows) {
      if (deliveredSeen.add(row.readerProfileId)) {
        deliveredByProfileIds.add(row.readerProfileId);
      }
      if (row.status == MessageReceiptState.read &&
          readSeen.add(row.readerProfileId)) {
        readByProfileIds.add(row.readerProfileId);
      }
    }

    return (
      deliveredCount: deliveredByProfileIds.length,
      readCount: readByProfileIds.length,
      deliveredByProfileIds: List<String>.unmodifiable(deliveredByProfileIds),
      readByProfileIds: List<String>.unmodifiable(readByProfileIds),
    );
  }

  Future<void> messageStateLogAppend({
    required String localEventId,
    required String newState,
    String? previousState,
    String? reasonCode,
    String? correlationId,
    String? convoId,
  }) async {
    await _recordMessageStateTransition(
      localEventId: localEventId,
      previousState: previousState,
      newState: newState,
      reasonCode: reasonCode,
      correlationId: correlationId,
      convoId: convoId,
    );
  }

  Future<void> _recordMessageStateTransition({
    required String localEventId,
    required String newState,
    String? previousState,
    String? reasonCode,
    String? correlationId,
    String? convoId,
  }) async {
    final normalizedPrev = previousState == null
        ? null
        : MessageLocalState.normalize(previousState);
    final normalizedNext = MessageLocalState.normalize(newState);
    if (normalizedPrev == normalizedNext) {
      await _upsertMessageDiagSnapshot(
        localEventId: localEventId,
        correlationId: correlationId,
        convoId: convoId,
        messageState: normalizedNext,
      );
      return;
    }
    final resolvedCorrelationId =
        correlationId ?? await _lookupCorrelationIdForEvent(localEventId);
    final resolvedConvoId =
        convoId ?? await _lookupConvoIdForEvent(localEventId);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert('message_state_log', {
      'correlation_id': resolvedCorrelationId,
      'local_event_id': localEventId,
      'previous_state': normalizedPrev,
      'new_state': normalizedNext,
      'reason_code': reasonCode,
      'created_at_ms': now,
    });
    await _upsertMessageDiagSnapshot(
      localEventId: localEventId,
      correlationId: resolvedCorrelationId,
      convoId: resolvedConvoId,
      messageState: normalizedNext,
    );
  }

  Future<String?> _lookupCorrelationIdForEvent(String localEventId) async {
    final rows = await _db.query(
      'outbox',
      columns: ['correlation_id'],
      where:
          'event_id_ref = ? AND correlation_id IS NOT NULL AND correlation_id != ?',
      whereArgs: [localEventId, ''],
      orderBy: 'created_at_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['correlation_id'] as String?;
  }

  Future<String?> _lookupConvoIdForEvent(String localEventId) async {
    final rows = await _db.query(
      'events',
      columns: ['convo_id'],
      where: 'event_id = ?',
      whereArgs: [localEventId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['convo_id'] as String?;
  }

  Future<void> _upsertMessageDiagSnapshot({
    required String localEventId,
    String? correlationId,
    String? convoId,
    String? messageState,
  }) async {
    final eventRows = await _db.query(
      'events',
      columns: ['convo_id', 'local_state'],
      where: 'event_id = ?',
      whereArgs: [localEventId],
      limit: 1,
    );
    final outboxRows = await _db.query(
      'outbox',
      columns: [
        'state',
        'last_error_code',
        'last_error_message_redacted',
        'correlation_id',
        'convo_id',
      ],
      where: 'event_id_ref = ?',
      whereArgs: [localEventId],
      orderBy: 'created_at_ms DESC, msg_id DESC',
    );
    final summary = <String, int>{};
    String? lastErrorCode;
    String? lastErrorMessage;
    var resolvedCorrelationId = correlationId;
    var resolvedConvoId = convoId;
    for (final row in outboxRows) {
      final state = OutboxSendState.normalize(row['state'] as String? ?? '');
      if (state.isNotEmpty) {
        summary[state] = (summary[state] ?? 0) + 1;
      }
      resolvedCorrelationId ??= row['correlation_id'] as String?;
      resolvedConvoId ??= row['convo_id'] as String?;
      lastErrorCode ??= row['last_error_code'] as String?;
      lastErrorMessage ??= row['last_error_message_redacted'] as String?;
    }
    if (eventRows.isNotEmpty) {
      resolvedConvoId ??= eventRows.first['convo_id'] as String?;
      messageState ??= eventRows.first['local_state'] as String?;
    }
    final outboxStateSummary = summary.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join(',');
    await _db.insert('message_diag_snapshot', {
      'local_event_id': localEventId,
      'correlation_id': resolvedCorrelationId,
      'convo_id': resolvedConvoId,
      'message_state': messageState == null
          ? null
          : MessageLocalState.normalize(messageState),
      'outbox_state_summary': outboxStateSummary,
      'last_error_code': lastErrorCode,
      'last_error_message_redacted': lastErrorMessage,
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Размер списка задаёт вызывающий, поэтому дробление обязательно: метод
  /// публичный и ограничения на вход у него нет.
  Future<void> deleteEventsByIds(List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    await _db.transaction((txn) async {
      for (final chunk in AppDb.chunkIds(eventIds)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        await txn.rawDelete(
          'DELETE FROM outbox WHERE event_id_ref IN ($placeholders)',
          chunk,
        );
        await txn.rawDelete(
          'DELETE FROM message_reactions WHERE event_id IN ($placeholders)',
          chunk,
        );
        await txn.rawDelete(
          'DELETE FROM events WHERE event_id IN ($placeholders)',
          chunk,
        );
      }
    });
  }

  Future<Map<String, Object?>?> messageReactionGetForProfile({
    required String eventId,
    required String profileId,
  }) async {
    final rows = await _db.query(
      'message_reactions',
      where: 'event_id = ? AND profile_id = ?',
      whereArgs: [eventId, profileId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<bool> messageReactionUpsert({
    required String eventId,
    required String convoId,
    required String profileId,
    required String emoji,
    String? actorName,
    String? actorAvatarPath,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await messageReactionGetForProfile(
      eventId: eventId,
      profileId: profileId,
    );
    final existingConvoId = (existing?['convo_id'] as String?) ?? '';
    final existingEmoji = (existing?['emoji'] as String?) ?? '';
    final existingActorName = existing?['actor_name'] as String?;
    final existingActorAvatarPath = existing?['actor_avatar_path'] as String?;
    if (existing != null &&
        existingConvoId == convoId &&
        existingEmoji == emoji &&
        existingActorName == actorName &&
        existingActorAvatarPath == actorAvatarPath) {
      return false;
    }
    await _db.insert('message_reactions', {
      'event_id': eventId,
      'convo_id': convoId,
      'profile_id': profileId,
      'actor_name': actorName,
      'actor_avatar_path': actorAvatarPath,
      'emoji': emoji,
      'created_at_ms': existing != null ? existing['created_at_ms'] : now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  Future<void> messageReactionDelete({
    required String eventId,
    required String profileId,
  }) async {
    await _db.delete(
      'message_reactions',
      where: 'event_id = ? AND profile_id = ?',
      whereArgs: [eventId, profileId],
    );
  }

  Future<List<Map<String, Object?>>> messageReactionsForEventIds(
    List<String> eventIds,
  ) async {
    if (eventIds.isEmpty) return const [];
    // Порциями: окно ленты растёт при прокрутке вверх, и список может выйти
    // за предел параметров SQLite. Сортировка применяется к склеенному
    // результату, иначе порядок был бы верным только внутри порции.
    final out = <Map<String, Object?>>[];
    for (final chunk in AppDb.chunkIds(eventIds)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      out.addAll(
        await _db.rawQuery(
          'SELECT event_id, convo_id, profile_id, actor_name, actor_avatar_path, emoji, created_at_ms, updated_at_ms '
          'FROM message_reactions WHERE event_id IN ($placeholders)',
          chunk,
        ),
      );
    }
    out.sort((l, r) {
      final lu = (l['updated_at_ms'] as num?)?.toInt() ?? 0;
      final ru = (r['updated_at_ms'] as num?)?.toInt() ?? 0;
      return ru.compareTo(lu);
    });
    return out;
  }

  Future<Map<String, Object?>?> eventGet(String eventId) async {
    final rows = await _db.query(
      'events',
      where: 'event_id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Returns local *group* placeholder events whose scheduled send time has
  /// arrived (`local_state = 'scheduled'` AND `scheduled_at_ms <= nowMs`),
  /// restricted to group conversations.
  ///
  /// 1:1 scheduled sends are intentionally NOT returned here — those are held
  /// in the outbox (`next_retry_at_ms`) and fired by the relay lease, so a
  /// group-only sweep must not touch them. Oldest scheduled-time first so a
  /// backlog (e.g. several due after the app was closed) fires in order.
  Future<List<Map<String, Object?>>> listDueScheduledGroupEvents({
    required int nowMs,
    int limit = 50,
  }) async {
    return _db.query(
      'events',
      where:
          "local_state = ? AND scheduled_at_ms IS NOT NULL "
          "AND scheduled_at_ms <= ? AND convo_id LIKE 'group:%'",
      whereArgs: [MessageLocalState.scheduled, nowMs],
      orderBy: 'scheduled_at_ms ASC, rowid ASC',
      limit: limit,
    );
  }

  /// Returns local *1:1* placeholder events whose scheduled send time has
  /// arrived (`local_state = 'scheduled'` AND `scheduled_at_ms <= nowMs`),
  /// restricted to direct conversations (excludes group + request threads).
  ///
  /// Mirrors [listDueScheduledGroupEvents]. Direct scheduled sends are held as
  /// a local `scheduled` placeholder (NOT eagerly enqueued into the outbox) and
  /// fired by [_sweepDueScheduledDirectMessages] at their due time — the same
  /// pattern as groups. This is what makes "send later" survive an app restart
  /// and stay editable/cancellable before it fires. Oldest scheduled-time first
  /// so a backlog (several due after the app was closed) fires in order.
  /// SERVER-SIDE SCHEDULED DELIVERY (2026-07-17): a scheduled 1:1 placeholder
  /// whose ciphertext was successfully uploaded to the relay (which now owns
  /// release at T) is flipped out of the local sweep's due set by moving it to
  /// `sent`. It KEEPS `scheduled_at_ms`, so the on-bubble scheduled-time badge
  /// still shows T; only the client fire-sweep (which selects `local_state =
  /// 'scheduled'`) stops considering it, preventing a duplicate send when the
  /// phone wakes.
  Future<void> markScheduledDirectUploaded(String localEventId) async {
    await _db.update(
      'events',
      {'local_state': MessageLocalState.sent},
      where: 'event_id = ? AND local_state = ?',
      whereArgs: [localEventId, MessageLocalState.scheduled],
    );
  }

  Future<List<Map<String, Object?>>> listDueScheduledDirectEvents({
    required int nowMs,
    int limit = 50,
  }) async {
    return _db.query(
      'events',
      where:
          "local_state = ? AND scheduled_at_ms IS NOT NULL "
          "AND scheduled_at_ms <= ? AND convo_id NOT LIKE 'group:%' "
          "AND convo_id NOT LIKE 'req:%'",
      whereArgs: [MessageLocalState.scheduled, nowMs],
      orderBy: 'scheduled_at_ms ASC, rowid ASC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> eventsByPayloadEventId({
    required String convoId,
    required String payloadEventId,
  }) async {
    final cleanedConvoId = convoId.trim();
    final cleanedPayloadEventId = payloadEventId.trim();
    if (cleanedConvoId.isEmpty || cleanedPayloadEventId.isEmpty) {
      return const <Map<String, Object?>>[];
    }
    return _db.query(
      'events',
      where: 'convo_id = ? AND payload_event_id = ?',
      whereArgs: [cleanedConvoId, cleanedPayloadEventId],
      orderBy: 'created_at_ms ASC, rowid ASC',
    );
  }

  /// Переписки, где лежит сообщение с этим ключом реакции: `payload_event_id`,
  /// а у старых записей без него — `event_id` (тот же выбор, что у ленты).
  Future<Set<String>> convoIdsForMessageKey(String messageKey) async {
    final key = messageKey.trim();
    if (key.isEmpty) return const <String>{};
    final rows = await _db.rawQuery(
      'SELECT DISTINCT convo_id FROM events '
      'WHERE payload_event_id = ? OR event_id = ? LIMIT 16',
      [key, key],
    );
    return rows
        .map((r) => ((r['convo_id'] as String?) ?? '').trim())
        .where((convoId) => convoId.isNotEmpty)
        .toSet();
  }

  List<String> _normalizeUnreadExcludedSenderDeviceIds({
    required String selfDeviceId,
    Iterable<String> excludedSenderDeviceIds = const <String>[],
  }) {
    final normalized = <String>{};
    final selfDid = selfDeviceId.trim();
    if (selfDid.isNotEmpty) {
      normalized.add(selfDid);
    }
    for (final deviceId in excludedSenderDeviceIds) {
      final clean = deviceId.trim();
      if (clean.isNotEmpty) {
        normalized.add(clean);
      }
    }
    return normalized.toList(growable: false);
  }

  ({String sql, List<Object> args}) _buildUnreadExcludedSenderFilter({
    required String selfDeviceId,
    Iterable<String> excludedSenderDeviceIds = const <String>[],
  }) {
    final excluded = _normalizeUnreadExcludedSenderDeviceIds(
      selfDeviceId: selfDeviceId,
      excludedSenderDeviceIds: excludedSenderDeviceIds,
    );
    if (excluded.isEmpty) {
      return (sql: '', args: const <Object>[]);
    }
    final placeholders = List.filled(excluded.length, '?').join(',');
    return (
      sql: 'sender_device_id NOT IN ($placeholders)',
      args: List<Object>.from(excluded),
    );
  }

  // Only user-visible message-like events count toward "unread" (chat-list
  // badge, nav badge, notification title). Excludes group 'sys' events
  // (membership add/remove, rename, permission/avatar changes — frequent in
  // rooms, essentially absent in 1:1) and call-signaling ('offer'/'answer'),
  // which otherwise inflate the room badge and can skew the notification title.
  // Applied IDENTICALLY to the count paths and the clear path
  // (listUnreadIncomingForConvo) so counted == cleared and the badge can never
  // stick > 0. Safe for 1:1: these are exactly the types that already counted.
  static const String _unreadMessageTypeSql =
      "type IN ('msg', 'att', 'sticker', 'call')";

  /// Returns the number of unread incoming messages for a given conversation.
  /// Uses read_at_ms to match markEventsReadByIds/listUnreadIncomingForConvo.
  Future<int> countUnreadForConvo({
    required String convoId,
    required String selfDeviceId,
    Iterable<String> excludedSenderDeviceIds = const <String>[],
  }) async {
    final senderFilter = _buildUnreadExcludedSenderFilter(
      selfDeviceId: selfDeviceId,
      excludedSenderDeviceIds: excludedSenderDeviceIds,
    );
    final whereSql = senderFilter.sql.isEmpty
        ? 'convo_id = ? AND read_at_ms IS NULL AND $_unreadMessageTypeSql'
        : 'convo_id = ? AND ${senderFilter.sql} AND read_at_ms IS NULL '
              'AND $_unreadMessageTypeSql';
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM events WHERE $whereSql',
      <Object>[convoId, ...senderFilter.args],
    );
    if (result.isEmpty) return 0;
    return (result.first['cnt'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, int>> countUnreadForConvos({
    required List<String> convoIds,
    required String selfDeviceId,
    Iterable<String> excludedSenderDeviceIds = const <String>[],
  }) async {
    if (convoIds.isEmpty) return const <String, int>{};
    final senderFilter = _buildUnreadExcludedSenderFilter(
      selfDeviceId: selfDeviceId,
      excludedSenderDeviceIds: excludedSenderDeviceIds,
    );
    // Порциями. Счётчик агрегируется по convo_id, а каждый чат целиком
    // помещается в одну порцию, поэтому склейка результатов даёт тот же
    // ответ, что и один запрос: пересечений между порциями нет.
    final rows = <Map<String, Object?>>[];
    for (final chunk in AppDb.chunkIds(convoIds)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final whereSql = senderFilter.sql.isEmpty
          ? 'convo_id IN ($placeholders) AND read_at_ms IS NULL '
                'AND $_unreadMessageTypeSql'
          : 'convo_id IN ($placeholders) AND ${senderFilter.sql} '
                'AND read_at_ms IS NULL AND $_unreadMessageTypeSql';
      rows.addAll(
        await _db.rawQuery(
          'SELECT convo_id, COUNT(*) AS cnt FROM events '
          'WHERE $whereSql '
          'GROUP BY convo_id',
          <Object>[...chunk, ...senderFilter.args],
        ),
      );
    }
    final out = <String, int>{};
    for (final row in rows) {
      final convoId = row['convo_id'] as String?;
      if (convoId == null || convoId.isEmpty) continue;
      out[convoId] = (row['cnt'] as num?)?.toInt() ?? 0;
    }
    return out;
  }

  /// Total unread incoming messages across ALL conversations (1:1 + rooms).
  /// Drives the iOS app-icon badge; uses the SAME predicate + sender filter as
  /// countUnreadForConvo(s) so the icon number matches the in-app nav badges and
  /// can never stick above the sum of the per-chat badges.
  Future<int> countUnreadTotal({
    required String selfDeviceId,
    Iterable<String> excludedSenderDeviceIds = const <String>[],
  }) async {
    final senderFilter = _buildUnreadExcludedSenderFilter(
      selfDeviceId: selfDeviceId,
      excludedSenderDeviceIds: excludedSenderDeviceIds,
    );
    final whereSql = senderFilter.sql.isEmpty
        ? 'read_at_ms IS NULL AND $_unreadMessageTypeSql'
        : '${senderFilter.sql} AND read_at_ms IS NULL AND $_unreadMessageTypeSql';
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM events WHERE $whereSql',
      <Object>[...senderFilter.args],
    );
    if (result.isEmpty) return 0;
    return (result.first['cnt'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, int>> profileMetaGetLastSeenForProfiles(
    List<String> profileIds,
  ) async {
    if (profileIds.isEmpty) return const <String, int>{};
    final rows = <Map<String, Object?>>[];
    for (final chunk in AppDb.chunkIds(profileIds)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      rows.addAll(
        await _db.rawQuery(
          'SELECT profile_id, last_seen_at_ms FROM profile_meta WHERE profile_id IN ($placeholders)',
          chunk,
        ),
      );
    }
    final out = <String, int>{};
    for (final row in rows) {
      final profileId = row['profile_id'] as String?;
      if (profileId == null || profileId.isEmpty) continue;
      final ts = (row['last_seen_at_ms'] as num?)?.toInt();
      if (ts == null) continue;
      out[profileId] = ts;
    }
    return out;
  }

  Future<List<Map<String, Object?>>> listUnreadIncomingForConvo({
    required String convoId,
    required String selfDeviceId,
    Iterable<String> excludedSenderDeviceIds = const <String>[],
    int limit = 100,
  }) {
    final senderFilter = _buildUnreadExcludedSenderFilter(
      selfDeviceId: selfDeviceId,
      excludedSenderDeviceIds: excludedSenderDeviceIds,
    );
    final whereSql = senderFilter.sql.isEmpty
        ? 'convo_id = ? AND read_at_ms IS NULL AND $_unreadMessageTypeSql'
        : 'convo_id = ? AND ${senderFilter.sql} AND read_at_ms IS NULL '
              'AND $_unreadMessageTypeSql';
    return _db.query(
      'events',
      columns: [
        'event_id',
        'sender_device_id',
        'payload_event_id',
        'created_at_ms',
      ],
      where: whereSql,
      whereArgs: <Object>[convoId, ...senderFilter.args],
      orderBy: 'created_at_ms DESC, rowid DESC',
      limit: limit,
    );
  }

  Future<void> markEventsReadByIds(
    List<String> eventIds, {
    required int readAtMs,
  }) async {
    if (eventIds.isEmpty) return;
    for (final chunk in AppDb.chunkIds(eventIds)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      await _db.rawUpdate(
        'UPDATE events SET read_at_ms = ? WHERE event_id IN ($placeholders) AND read_at_ms IS NULL',
        [readAtMs, ...chunk],
      );
    }
  }

  Future<({String payloadEventId, String senderDeviceId})?>
  latestUnreadIncomingForConvo({
    required String convoId,
    required String selfDeviceId,
    Iterable<String> excludedSenderDeviceIds = const <String>[],
  }) async {
    final senderFilter = _buildUnreadExcludedSenderFilter(
      selfDeviceId: selfDeviceId,
      excludedSenderDeviceIds: excludedSenderDeviceIds,
    );
    final whereSql = senderFilter.sql.isEmpty
        ? 'convo_id = ? AND read_at_ms IS NULL AND $_unreadMessageTypeSql'
        : 'convo_id = ? AND ${senderFilter.sql} AND read_at_ms IS NULL '
              'AND $_unreadMessageTypeSql';
    final rows = await _db.query(
      'events',
      columns: ['payload_event_id', 'sender_device_id'],
      where: whereSql,
      whereArgs: <Object>[convoId, ...senderFilter.args],
      orderBy: 'created_at_ms DESC, rowid DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final pid = (rows.first['payload_event_id'] as String?)?.trim() ?? '';
    final sid = rows.first['sender_device_id'] as String?;
    if (sid == null || sid.isEmpty) return null;
    return (payloadEventId: pid, senderDeviceId: sid);
  }

  Future<void> markConvoIncomingRead({
    required String convoId,
    required String selfDeviceId,
    Iterable<String> excludedSenderDeviceIds = const <String>[],
  }) async {
    final senderFilter = _buildUnreadExcludedSenderFilter(
      selfDeviceId: selfDeviceId,
      excludedSenderDeviceIds: excludedSenderDeviceIds,
    );
    final whereSql = senderFilter.sql.isEmpty
        ? "convo_id = ? AND local_state != '${MessageLocalState.read}'"
        : "convo_id = ? AND ${senderFilter.sql} AND local_state != '${MessageLocalState.read}'";
    await _db.rawUpdate(
      "UPDATE events SET local_state = '${MessageLocalState.read}' WHERE $whereSql",
      <Object>[convoId, ...senderFilter.args],
    );
  }

  Future<List<Map<String, Object?>>> listEvents(
    String convoId, {
    int limit = 100,
    int? beforeCreatedAtMs,
  }) {
    // PR7: optional `beforeCreatedAtMs` filter for the desktop
    // "Load older" affordance. When provided, returns only events
    // strictly older than the cursor (still ordered newest-first so
    // the caller can reverse to chronological just like before).
    final where = StringBuffer('convo_id = ?');
    final args = <Object>[convoId];
    if (beforeCreatedAtMs != null && beforeCreatedAtMs > 0) {
      where.write(' AND created_at_ms < ?');
      args.add(beforeCreatedAtMs);
    }
    return _db.query(
      'events',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'created_at_ms DESC, rowid DESC',
      limit: limit,
    );
  }

  /// Lists a room's system events (membership changes, settings edits, etc.)
  /// newest-first — the backing data for the admin audit log.
  Future<List<Map<String, Object?>>> listRoomSystemEvents({
    required String convoId,
    int limit = 200,
  }) {
    return _db.query(
      'events',
      where: "convo_id = ? AND type = 'sys'",
      whereArgs: [convoId],
      orderBy: 'created_at_ms DESC, rowid DESC',
      limit: limit,
    );
  }

  /// Used by the PR5 peer-history responder (`AppController` → mobile side).
  /// Lists the most recent events across **1-to-1 conversations only**,
  /// newest first. Group / temporary `dev:` convos are skipped — group
  /// history is shipped via [listRecentEventsForPeerSync] (PR6).
  ///
  /// Kept as a thin shim for backwards compatibility with existing
  /// callers; new code should prefer [listRecentEventsForPeerSync].
  Future<List<Map<String, Object?>>> listRecentDirectEventsForPeerSync({
    int? beforeCreatedAtMs,
    String? convoId,
    int limit = 50,
  }) {
    return listRecentEventsForPeerSync(
      beforeCreatedAtMs: beforeCreatedAtMs,
      convoId: convoId,
      limit: limit,
      includeGroups: false,
    );
  }

  /// PR6 extension of [listRecentDirectEventsForPeerSync].
  ///
  /// [includeGroups] = true makes the helper page over both 1-to-1 AND
  /// group events; `dev:` convos remain filtered out because they're
  /// short-lived stubs that get merged into real convos as soon as the
  /// device→profile mapping resolves.
  ///
  /// [convoId] (optional) narrows the result to a single conversation —
  /// useful when the desktop wants "older events in *this* room".
  ///
  /// [beforeCreatedAtMs] excludes rows ≥ the supplied timestamp. Pass
  /// the `created_at_ms` of the oldest event in the previous page to
  /// step backwards through the archive.
  Future<List<Map<String, Object?>>> listRecentEventsForPeerSync({
    int? beforeCreatedAtMs,
    String? convoId,
    int limit = 50,
    bool includeGroups = true,
  }) {
    final where = StringBuffer("convo_id NOT LIKE 'dev:%'");
    final args = <Object>[];
    if (!includeGroups) {
      where.write(" AND convo_id NOT LIKE 'group:%'");
    }
    if (convoId != null && convoId.isNotEmpty) {
      where.write(' AND convo_id = ?');
      args.add(convoId);
    }
    if (beforeCreatedAtMs != null && beforeCreatedAtMs > 0) {
      where.write(' AND created_at_ms < ?');
      args.add(beforeCreatedAtMs);
    }
    return _db.query(
      'events',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'created_at_ms DESC, rowid DESC',
      limit: limit,
    );
  }

  /// PR6: list group_memberships rows for one group, with every column
  /// (status, role, tag, etc.) preserved. The peer-history responder
  /// uses this to build a [PeerHistoryGroupMember] snapshot.
  ///
  /// Note: unlike [groupMembersList] (which returns the simplified
  /// `group_members` projection), this returns the full membership
  /// state row so revoked / pending entries can be replayed verbatim.
  Future<List<Map<String, Object?>>> groupMembershipsListForSync(
    String groupId,
  ) {
    return _db.query(
      'group_memberships',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'created_at_ms ASC',
    );
  }

  Future<void> outboxUpsert({
    required String msgId,
    required String toDeviceId,
    required String ciphertextB64,
    required int ttlSeconds,
    required String state,
    required int attemptCount,
    required int nextRetryAtMs,
    required int createdAtMs,
    String? correlationId,
    String? payloadEventId,
    String? convoId,
    String? transportMetaJson,
    int? expiresAtMs,
    int? priority,
    String? transportHint,
    String? retryBucket,
    String? eventIdRef,
    // SERVER-SIDE SCHEDULED DELIVERY (2026-07-17): relay release time; 0 =
    // immediate. Uploaded to the relay in the Send frame.
    int deliverAtMs = 0,
  }) async {
    await _db.insert('outbox', {
      'msg_id': msgId,
      'to_device_id': toDeviceId,
      'ciphertext_b64': ciphertextB64,
      'ttl_seconds': ttlSeconds,
      'state': state,
      'attempt_count': attemptCount,
      'next_retry_at_ms': nextRetryAtMs,
      'created_at_ms': createdAtMs,
      'deliver_at_ms': deliverAtMs,
      'correlation_id': correlationId,
      'payload_event_id': payloadEventId,
      'convo_id': convoId,
      'transport_meta_json': transportMetaJson,
      'expires_at_ms': expiresAtMs,
      'priority': priority ?? 0,
      'transport_hint': transportHint,
      'retry_bucket': retryBucket ?? '',
      'event_id_ref': eventIdRef,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> messageStateLogAdd({
    String? correlationId,
    String? localEventId,
    String? previousState,
    required String newState,
    String? reasonCode,
    int? createdAtMs,
  }) async {
    await _db.insert('message_state_log', {
      'correlation_id': correlationId,
      'local_event_id': localEventId,
      'previous_state': previousState,
      'new_state': newState,
      'reason_code': reasonCode,
      'created_at_ms': createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> messageAttemptLogAdd({
    String? correlationId,
    String? localEventId,
    String? msgId,
    String? toDeviceId,
    required int startedAtMs,
    int? finishedAtMs,
    required int attemptIndex,
    String? transport,
    String? result,
    String? errorCode,
    String? errorMessageRedacted,
    int? latencyMs,
  }) async {
    await _db.insert('message_attempt_log', {
      'correlation_id': correlationId,
      'local_event_id': localEventId,
      'msg_id': msgId,
      'to_device_id': toDeviceId,
      'started_at_ms': startedAtMs,
      'finished_at_ms': finishedAtMs,
      'attempt_index': attemptIndex,
      'transport': transport,
      'result': result,
      'error_code': errorCode,
      'error_message_redacted': errorMessageRedacted,
      'latency_ms': latencyMs,
    });
  }

  Future<void> messageDiagSnapshotUpsert({
    required String localEventId,
    String? correlationId,
    String? convoId,
    String? messageState,
    String? outboxStateSummary,
    String? lastErrorCode,
    String? lastErrorMessageRedacted,
    int? updatedAtMs,
  }) async {
    await _db.insert('message_diag_snapshot', {
      'local_event_id': localEventId,
      'correlation_id': correlationId,
      'convo_id': convoId,
      'message_state': messageState,
      'outbox_state_summary': outboxStateSummary,
      'last_error_code': lastErrorCode,
      'last_error_message_redacted': lastErrorMessageRedacted,
      'updated_at_ms': updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, int>> outboxStateCounts() async {
    final rows = await _db.rawQuery(
      'SELECT state, COUNT(*) AS cnt FROM outbox GROUP BY state',
    );
    final out = <String, int>{};
    for (final row in rows) {
      final state = (row['state'] as String? ?? '').trim();
      if (state.isEmpty) continue;
      out[state] = (row['cnt'] as num?)?.toInt() ?? 0;
    }
    return out;
  }

  Future<List<Map<String, Object?>>> messageDiagSnapshots({
    int limit = 20,
    bool actionableOnly = false,
  }) async {
    if (!actionableOnly) {
      return _db.query(
        'message_diag_snapshot',
        orderBy: 'updated_at_ms DESC',
        limit: limit,
      );
    }
    return _db.query(
      'message_diag_snapshot',
      where:
          "message_state IN ('${MessageLocalState.pending}','${MessageLocalState.sending}','${MessageLocalState.retry}','${MessageLocalState.failed}') OR outbox_state_summary LIKE ? OR outbox_state_summary LIKE ? OR outbox_state_summary LIKE ?",
      whereArgs: ['%pending:%', '%sending:%', '%retry:%'],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> messageStateLogList({
    String? localEventId,
    String? correlationId,
    int limit = 50,
  }) async {
    final whereParts = <String>[];
    final args = <Object?>[];
    if (localEventId != null && localEventId.trim().isNotEmpty) {
      whereParts.add('local_event_id = ?');
      args.add(localEventId.trim());
    }
    if (correlationId != null && correlationId.trim().isNotEmpty) {
      whereParts.add('correlation_id = ?');
      args.add(correlationId.trim());
    }
    return _db.query(
      'message_state_log',
      where: whereParts.isEmpty ? null : whereParts.join(' OR '),
      whereArgs: whereParts.isEmpty ? null : args,
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> messageAttemptLogList({
    String? localEventId,
    String? correlationId,
    int limit = 50,
  }) async {
    final whereParts = <String>[];
    final args = <Object?>[];
    if (localEventId != null && localEventId.trim().isNotEmpty) {
      whereParts.add('local_event_id = ?');
      args.add(localEventId.trim());
    }
    if (correlationId != null && correlationId.trim().isNotEmpty) {
      whereParts.add('correlation_id = ?');
      args.add(correlationId.trim());
    }
    return _db.query(
      'message_attempt_log',
      where: whereParts.isEmpty ? null : whereParts.join(' OR '),
      whereArgs: whereParts.isEmpty ? null : args,
      orderBy: 'started_at_ms DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> outboxDue({int limit = 20}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.query(
      'outbox',
      where:
          "state IN ('${OutboxSendState.pending}','${OutboxSendState.retry}','${OutboxSendState.sending}') AND next_retry_at_ms <= ?",
      whereArgs: [now],
      orderBy: 'priority DESC, created_at_ms ASC',
      limit: limit,
    );
  }

  Future<int> outboxRecoverStaleLeases({required int olderThanMs}) async {
    return _db.rawUpdate(
      'UPDATE outbox SET locked_by_worker = NULL, locked_at_ms = NULL WHERE locked_at_ms IS NOT NULL AND locked_at_ms <= ?',
      [olderThanMs],
    );
  }

  /// ANDROID WORKMANAGER (2026-07-17): due, unsent outbox rows for the headless
  /// background flush. No worker-lease columns — the WorkManager task is gated
  /// to run only when the foreground app is NOT active (main-isolate heartbeat),
  /// so there is no concurrent leaser to coordinate with; and even a stray
  /// double-send is deduped by the relay's UNIQUE(device_id, msg_id).
  Future<List<Map<String, Object?>>> rawQueryOutboxDueForBackground({
    required int nowMs,
    int limit = 50,
  }) async {
    return _db.query(
      'outbox',
      where:
          "state IN ('${OutboxSendState.pending}','${OutboxSendState.retry}','${OutboxSendState.sending}') "
          "AND next_retry_at_ms <= ?",
      whereArgs: [nowMs],
      orderBy: 'priority DESC, created_at_ms ASC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> outboxLeaseDue({
    required String workerId,
    required int nowMs,
    int limit = 20,
    int staleLeaseBeforeMs = 0,
  }) async {
    if (staleLeaseBeforeMs > 0) {
      await outboxRecoverStaleLeases(olderThanMs: staleLeaseBeforeMs);
    }

    final candidates = await _db.query(
      'outbox',
      where:
          "state IN ('${OutboxSendState.pending}','${OutboxSendState.retry}','${OutboxSendState.sending}') AND next_retry_at_ms <= ? AND (locked_at_ms IS NULL OR locked_by_worker = ?)",
      whereArgs: [nowMs, workerId],
      orderBy: 'priority DESC, created_at_ms ASC',
      limit: limit,
    );

    final leased = <Map<String, Object?>>[];
    for (final row in candidates) {
      final msgId = row['msg_id'] as String?;
      if (msgId == null || msgId.isEmpty) continue;
      final updated = await _db.rawUpdate(
        'UPDATE outbox SET locked_by_worker = ?, locked_at_ms = ? WHERE msg_id = ? AND (locked_at_ms IS NULL OR locked_by_worker = ?)',
        [workerId, nowMs, msgId, workerId],
      );
      if (updated <= 0) continue;
      leased.add({...row, 'locked_by_worker': workerId, 'locked_at_ms': nowMs});
    }
    return leased;
  }

  Future<void> outboxReleaseLease({
    required String msgId,
    String? workerId,
  }) async {
    if (workerId != null && workerId.trim().isNotEmpty) {
      await _db.rawUpdate(
        'UPDATE outbox SET locked_by_worker = NULL, locked_at_ms = NULL WHERE msg_id = ? AND locked_by_worker = ?',
        [msgId, workerId],
      );
      return;
    }
    await _db.rawUpdate(
      'UPDATE outbox SET locked_by_worker = NULL, locked_at_ms = NULL WHERE msg_id = ?',
      [msgId],
    );
  }

  Future<int> outboxRescheduleStalledSends({
    required int nowMs,
    required int stalledBeforeMs,
    required int retryAtMs,
    int limit = 32,
    String reasonCode = MessageFailureReason.sendStallTimeout,
  }) async {
    final rows = await _db.query(
      'outbox',
      columns: [
        'msg_id',
        'event_id_ref',
        'correlation_id',
        'convo_id',
        'to_device_id',
        'attempt_count',
        'transport_hint',
        'last_attempt_at_ms',
        'created_at_ms',
      ],
      where:
          "state IN ('${OutboxSendState.sending}','${OutboxSendState.retry}') AND COALESCE(last_attempt_at_ms, created_at_ms) <= ? AND next_retry_at_ms <= ?",
      whereArgs: [stalledBeforeMs, nowMs],
      orderBy: 'COALESCE(last_attempt_at_ms, created_at_ms) ASC',
      limit: limit,
    );
    if (rows.isEmpty) return 0;

    final recoveredEventIds = <String>{};
    var updatedCount = 0;
    for (final row in rows) {
      final msgId = row['msg_id'] as String?;
      if (msgId == null || msgId.isEmpty) continue;
      final localEventId = row['event_id_ref'] as String?;
      final correlationId = row['correlation_id'] as String?;
      final convoId = row['convo_id'] as String?;
      final toDeviceId = row['to_device_id'] as String?;
      final attemptIndex = (row['attempt_count'] as num?)?.toInt() ?? 0;
      final transport = row['transport_hint'] as String?;
      final startedAtMs =
          (row['last_attempt_at_ms'] as num?)?.toInt() ??
          (row['created_at_ms'] as num?)?.toInt() ??
          nowMs;
      final affected = await _db.update(
        'outbox',
        {
          'state': OutboxSendState.retry,
          'next_retry_at_ms': retryAtMs,
          'locked_by_worker': null,
          'locked_at_ms': null,
          'last_error_code': reasonCode,
          'last_error_message_redacted':
              'send attempt stalled; scheduled retry',
        },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      if (affected <= 0) continue;
      updatedCount += affected;
      await messageAttemptLogAppend(
        correlationId: correlationId,
        localEventId: localEventId,
        msgId: msgId,
        toDeviceId: toDeviceId,
        startedAtMs: startedAtMs,
        finishedAtMs: nowMs,
        attemptIndex: attemptIndex,
        transport: transport ?? 'recovery',
        result: 'stalled_recovered',
        errorCode: reasonCode,
        errorMessageRedacted: 'send attempt stalled; scheduled retry',
        latencyMs: nowMs - startedAtMs,
      );
      if (localEventId != null &&
          localEventId.isNotEmpty &&
          recoveredEventIds.add(localEventId)) {
        await updateEventLocalState(
          eventId: localEventId,
          localState: MessageLocalState.retry,
          reasonCode: reasonCode,
        );
      } else if (localEventId != null && localEventId.isNotEmpty) {
        await _upsertMessageDiagSnapshot(
          localEventId: localEventId,
          correlationId: correlationId,
          convoId: convoId,
        );
      }
    }
    return updatedCount;
  }

  /// S1 (2026-06-29): re-arm outbox rows STUCK in 'pending' — a row whose pump
  /// never advanced because the SENDER was frozen (doze/MIUI) right after
  /// enqueue, or whose lease left a stale lock. [outboxLeaseDue] already covers
  /// 'pending', but ONLY for rows that are due (`next_retry_at_ms <= now`) and
  /// unlocked — so a row pushed to a future retry or left locked by a dead
  /// worker is silently skipped forever (the unconditional stall sweep above
  /// only touches 'sending'/'retry'). This resets exactly those skipped rows to
  /// due + clears the stale lock so the next pump kick leases them. No
  /// attempt/error mutation — the row never actually attempted a send.
  /// Returns the number of rows re-armed (caller pumps the outbox if > 0).
  Future<int> outboxRekickStuckPending({
    required int nowMs,
    required int stuckBeforeMs,
  }) async {
    // SCHEDULED-SEND SAFETY (2026-07-14): a row whose linked event is still
    // `scheduled` is NOT stuck — it is intentionally deferred to a future send
    // time. Re-arming it to `now` here was the "scheduled message sends
    // immediately" bug (the only 'pending' rows with next_retry_at_ms > now
    // were scheduled sends, and this watchdog fired them ~90 s after they were
    // scheduled). Direct scheduled sends no longer create an outbox row at all
    // (they are held as a `scheduled` placeholder and fired by the sweep), so
    // this exclusion is defence-in-depth that also neutralises any legacy row.
    return _db.update(
      'outbox',
      {'next_retry_at_ms': nowMs, 'locked_by_worker': null, 'locked_at_ms': null},
      where:
          "state = '${OutboxSendState.pending}' AND created_at_ms <= ? "
          "AND (next_retry_at_ms > ? OR locked_at_ms IS NOT NULL) "
          "AND (event_id_ref IS NULL OR event_id_ref NOT IN "
          "(SELECT event_id FROM events WHERE local_state = ?))",
      whereArgs: [stuckBeforeMs, nowMs, MessageLocalState.scheduled],
    );
  }

  Future<void> outboxMarkSending(
    String msgId, {
    required int retryAfterMs,
    String? reasonCode,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _db.query(
      'outbox',
      columns: ['attempt_count', 'event_id_ref', 'correlation_id', 'convo_id'],
      where: 'msg_id = ?',
      whereArgs: [msgId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final currentAttemptCount =
        (rows.first['attempt_count'] as num?)?.toInt() ?? 0;
    final ref = rows.first['event_id_ref'] as String?;
    final correlationId = rows.first['correlation_id'] as String?;
    final convoId = rows.first['convo_id'] as String?;
    final nextState = currentAttemptCount <= 0
        ? OutboxSendState.sending
        : OutboxSendState.retry;

    await _db.rawUpdate(
      'UPDATE outbox SET state = ?, attempt_count = attempt_count + 1, next_retry_at_ms = ?, last_attempt_at_ms = ? WHERE msg_id = ?',
      [nextState, now + retryAfterMs, now, msgId],
    );
    if (ref != null && ref.isNotEmpty) {
      final eventRows = await _db.query(
        'events',
        columns: ['local_state'],
        where: 'event_id = ?',
        whereArgs: [ref],
        limit: 1,
      );
      final currentEventState = eventRows.isEmpty
          ? null
          : eventRows.first['local_state'] as String?;
      final canAdvance =
          currentEventState == null ||
          !MessageLocalState.isTerminal(currentEventState) &&
              MessageLocalState.normalize(currentEventState) !=
                  MessageLocalState.delivered;
      if (canAdvance) {
        await updateEventLocalState(
          eventId: ref,
          localState: nextState,
          reasonCode: reasonCode,
        );
      } else {
        await _upsertMessageDiagSnapshot(
          localEventId: ref,
          correlationId: correlationId,
          convoId: convoId,
        );
      }
    }
  }

  Future<void> messageAttemptLogAppend({
    String? correlationId,
    String? localEventId,
    String? msgId,
    String? toDeviceId,
    required int startedAtMs,
    int? finishedAtMs,
    required int attemptIndex,
    String? transport,
    String? result,
    String? errorCode,
    String? errorMessageRedacted,
    int? latencyMs,
  }) async {
    await _db.insert('message_attempt_log', {
      'correlation_id': correlationId,
      'local_event_id': localEventId,
      'msg_id': msgId,
      'to_device_id': toDeviceId,
      'started_at_ms': startedAtMs,
      'finished_at_ms': finishedAtMs,
      'attempt_index': attemptIndex,
      'transport': transport,
      'result': result,
      'error_code': errorCode,
      'error_message_redacted': errorMessageRedacted,
      'latency_ms': latencyMs,
    });
    if (localEventId != null && localEventId.isNotEmpty) {
      await _upsertMessageDiagSnapshot(
        localEventId: localEventId,
        correlationId: correlationId,
      );
    }
  }

  /// Map a relay/transport `msg_id` back to the local outbound event it carried
  /// (2026-07-23, undecryptable-recovery). The msg_id is end-to-end: the id in a
  /// peer's NACK IS our outbox PK, and `outboxMarkSent` never deletes the row,
  /// so a NACKed wire can be re-encrypted from `event_id_ref` regardless of its
  /// delivered/read state. Returns null if we no longer hold the row.
  Future<Map<String, String>?> outboxEventRefByMsgId(String msgId) async {
    final id = msgId.trim();
    if (id.isEmpty) return null;
    final rows = await _db.query(
      'outbox',
      columns: ['event_id_ref', 'payload_event_id'],
      where: 'msg_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final ref = ((rows.first['event_id_ref'] as String?) ?? '').trim();
    if (ref.isEmpty) return null;
    return {
      'event_id_ref': ref,
      'payload_event_id':
          ((rows.first['payload_event_id'] as String?) ?? '').trim(),
    };
  }

  Future<void> outboxMarkSent(String msgId) async {
    final rows = await _db.query(
      'outbox',
      columns: ['event_id_ref', 'correlation_id', 'convo_id'],
      where: 'msg_id = ?',
      whereArgs: [msgId],
      limit: 1,
    );
    final ref = rows.isNotEmpty ? rows.first['event_id_ref'] as String? : null;
    await _db.update(
      'outbox',
      {
        'state': OutboxSendState.sent,
        'server_acked_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    if (ref != null && ref.isNotEmpty) {
      // 🔴 ПЕРВОЕ подтверждение реле, а не последнее (06.08.2026).
      //
      // Раньше здесь считались строки очереди и событие переходило в `sent`
      // только когда не осталось ни одной неподтверждённой. Сообщение 1:1
      // разлетается по ВСЕМ устройствам собеседника — их бывает до восьми, — и
      // часы на пузыре держала самая медленная копия: одна попытка, ушедшая на
      // повтор, добавляла секунды к индикатору у сообщения, которое уже лежало
      // на реле и уже читалось. Полевая жалоба: «пришло на второе устройство, а
      // часики всё крутятся».
      //
      // Правило теперь одно на всех ступенях: побеждает ПЕРВЫЙ успех. Так уже
      // работает `delivered` (ставится по первой квитанции), и ранняя ступень
      // не имеет права быть строже поздней. Неполнота рассылки не пропадает —
      // она видна там, где ей и место: в снимке диагностики
      // (`outbox_state_summary`), а досылкой занимается очередь.
      final eventRows = await _db.query(
        'events',
        columns: ['local_state'],
        where: 'event_id = ?',
        whereArgs: [ref],
        limit: 1,
      );
      final currentState = eventRows.isEmpty
          ? null
          : (eventRows.first['local_state'] as String?);
      // 🔴 Проверка направления — не украшение. `updateEventLocalState` пишет
      // состояние БЕЗУСЛОВНО, без `canPromote`. Подтверждение копии для второго
      // устройства спокойно приходит ПОСЛЕ квитанции о доставке от первого — и
      // без этой проверки оно откатило бы `delivered`/`read` обратно в `sent`,
      // то есть галочки прыгали бы назад.
      final promote =
          currentState != null &&
          currentState != MessageLocalState.sent &&
          MessageLocalState.canPromote(
            from: currentState,
            to: MessageLocalState.sent,
          );
      if (promote) {
        await updateEventLocalState(
          eventId: ref,
          localState: MessageLocalState.sent,
        );
      }
      // Снимок диагностики обновляется на КАЖДОМ подтверждении, а не только
      // когда рассылка неполна: сводка по строкам очереди — единственное место,
      // где после этой правки видно, что часть копий ещё в пути.
      await _upsertMessageDiagSnapshot(localEventId: ref);
    }
  }

  /// Провода, ещё не принятые реле: ждут отправки, повтора или уже в пути.
  Future<List<String>> outboxUnsentMsgIds() async {
    final rows = await _db.query(
      'outbox',
      columns: ['msg_id'],
      where:
          "state IN ('${OutboxSendState.pending}','${OutboxSendState.retry}','${OutboxSendState.sending}')",
    );
    return <String>[
      for (final row in rows)
        if (((row['msg_id'] as String?) ?? '').isNotEmpty)
          row['msg_id'] as String,
    ];
  }

  Future<void> outboxMarkFailed(
    String msgId, {
    String? reasonCode,
    String? errorCode,
    String? errorMessageRedacted,
  }) async {
    final rows = await _db.query(
      'outbox',
      columns: ['event_id_ref', 'correlation_id', 'convo_id'],
      where: 'msg_id = ?',
      whereArgs: [msgId],
      limit: 1,
    );
    final ref = rows.isNotEmpty ? rows.first['event_id_ref'] as String? : null;
    final correlationId = rows.isNotEmpty
        ? rows.first['correlation_id'] as String?
        : null;
    final convoId = rows.isNotEmpty ? rows.first['convo_id'] as String? : null;
    await _db.update(
      'outbox',
      {
        'state': OutboxSendState.failed,
        'last_error_code': errorCode,
        'last_error_message_redacted': errorMessageRedacted,
      },
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    if (ref != null && ref.isNotEmpty) {
      final eventRows = await _db.query(
        'events',
        columns: ['local_state'],
        where: 'event_id = ?',
        whereArgs: [ref],
        limit: 1,
      );
      final currentEventState = eventRows.isEmpty
          ? null
          : eventRows.first['local_state'] as String?;
      if (currentEventState == null ||
          MessageLocalState.isOutgoingInFlight(currentEventState)) {
        await updateEventLocalState(
          eventId: ref,
          localState: MessageLocalState.failed,
          reasonCode: reasonCode,
        );
      } else {
        await _upsertMessageDiagSnapshot(
          localEventId: ref,
          correlationId: correlationId,
          convoId: convoId,
        );
      }
    }
  }

  Future<List<Map<String, Object?>>> outboxListForEventRef(
    String eventIdRef,
  ) async {
    return _db.query(
      'outbox',
      where: 'event_id_ref = ?',
      whereArgs: [eventIdRef],
      orderBy: 'created_at_ms ASC, msg_id ASC',
    );
  }

  /// "Send later" wires the relay has ACCEPTED and still HOLDS (release time
  /// in the future). These are exactly the rows whose ciphertext can go stale
  /// if the session to `to_device_id` rotates before release — the sweep
  /// re-encrypts them under the fresh session (2026-07-19).
  Future<List<Map<String, Object?>>> outboxHeldScheduledRows({
    required int nowMs,
  }) async {
    return _db.query(
      'outbox',
      columns: [
        'msg_id',
        'to_device_id',
        'event_id_ref',
        'deliver_at_ms',
        'convo_id',
        'transport_meta_json',
        'created_at_ms',
        'correlation_id',
        'payload_event_id',
      ],
      where: "deliver_at_ms > ? AND state = ?",
      whereArgs: [nowMs, OutboxSendState.sent],
      orderBy: 'deliver_at_ms ASC',
      limit: 100,
    );
  }

  /// Session-generation birth stamp for the CURRENT outbound session to
  /// [peerDeviceId] (Epic B `epoch`, stamped at handshake and preserved across
  /// every ratchet advance). 0 = no session / pre-epoch legacy session. A held
  /// wire created BEFORE this instant was encrypted under a dead session.
  Future<int> sessionV3EpochFor(String peerDeviceId) async {
    final rows = await _db.query(
      'sessions_v3',
      columns: ['epoch'],
      where: 'peer_device_id = ?',
      whereArgs: [peerDeviceId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['epoch'] as num?)?.toInt() ?? 0;
  }

  Future<void> outboxDeleteByMsgId(String msgId) async {
    await _db.delete('outbox', where: 'msg_id = ?', whereArgs: [msgId]);
  }

  Future<void> outboxDeleteForEventRef(String eventIdRef) async {
    await _db.delete(
      'outbox',
      where: 'event_id_ref = ?',
      whereArgs: [eventIdRef],
    );
  }

  /// Delete all PENDING outbox rows targeted at a specific peer device. Used
  /// after the local ratchet session is reset (e.g. responder side received a
  /// prekey wire) — any rows still in pending were encrypted under the now-
  /// stale state and would just keep failing on the receiver's side.
  /// Already-sent rows are kept for retry/receipt accounting.
  /// Returns the number of rows deleted.
  Future<int> outboxDeletePendingForDevice(String toDeviceId) async {
    if (toDeviceId.isEmpty) return 0;
    return _db.delete(
      'outbox',
      where: "to_device_id = ? AND state = 'pending'",
      whereArgs: [toDeviceId],
    );
  }

  Future<void> outboxResetForEventRef(String eventIdRef) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      "UPDATE outbox SET state = 'pending', attempt_count = 0, next_retry_at_ms = ? WHERE event_id_ref = ?",
      [now, eventIdRef],
    );
  }

  Future<int> outboxCountByState(String state) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM outbox WHERE state = ?',
      [state],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

  Future<int> outboxCountForEventRef(String eventIdRef) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM outbox WHERE event_id_ref = ?',
      [eventIdRef],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

  /// Sprint 2 C4: enumerate outbox rows that are still in `pending` or
  /// `sending` state and whose `created_at_ms` is older than
  /// `olderThanMs`. Used by the outbox-stuck watchdog to surface UI
  /// warnings and to auto-trigger ratchet recovery for genuinely
  /// stuck destinations.
  ///
  /// Returns lightweight rows (`msg_id`, `to_device_id`, `convo_id`,
  /// `created_at_ms`, `state`) — no ciphertext is loaded.
  /// Сколько раз этому человеку показали «номер безопасности изменился».
  ///
  /// 🔴 ЗАЧЕМ ЭТО ЗАПРОС, А НЕ НОВЫЙ СЧЁТЧИК. Решение по слою 2 (один номер на
  /// человека вместо номера на устройство)
  /// было отложено 06.08.2026 с условием «неделю считать события». Условие
  /// оказалось неизмеримым: `new_device_seen` и `identity_rotated_accepted`
  /// живут только в логе устройства, а он кольцевой и чистится.
  ///
  /// Но сама плашка вставляется в переписку ПОСТОЯННЫМ событием с предсказуемым
  /// идентификатором `local:safetynum:<пир>:<окно 10 мин>`. То есть история уже
  /// записана — ждать неделю не нужно, достаточно посмотреть.
  ///
  /// Возвращает `(всего, пиров)` за последние [windowMs].
  Future<({int total, int peers})> safetyNumberNoticeStats({
    required int windowMs,
    required int nowMs,
  }) async {
    final rows = await _db.rawQuery(
      "SELECT event_id FROM events "
      "WHERE event_id LIKE 'local:safetynum:%' AND created_at_ms > ?",
      [nowMs - windowMs],
    );
    final peers = <String>{};
    for (final r in rows) {
      final id = (r['event_id'] as String?) ?? '';
      // local:safetynum:<peer>:<bucket> — пир между вторым и последним ':'
      final parts = id.split(':');
      if (parts.length >= 4) peers.add(parts[2]);
    }
    return (total: rows.length, peers: peers.length);
  }

  /// Строки исходящих, помеченные `failed`, вместе с судьбой их сообщения.
  ///
  /// 🔴 ЗАЧЕМ. `failed` — КОНЕЧНОЕ состояние: очередь на отправку берёт только
  /// `pending`, `retry` и `sending`, значит такая строка не уйдёт никогда.
  /// В поле 12.08.2026 их оказалось восемь, и по одному числу нельзя понять,
  /// потерянные это смс или мусор: переотправка минтит НОВЫЙ msg_id при том же
  /// payload, поэтому содержимое могло уехать другим конвертом, а строка
  /// осталась. Ответ даёт состояние САМОГО СОБЫТИЯ.
  ///
  /// Ключ связи — `event_id_ref`, тот же, на котором работает
  /// [outboxListForEventRef]. Своего соединения не сочиняем: сочинённое
  /// 12.08 вернуло в поле пустоту и стоило трёх замеров.
  ///
  /// `event_id_ref` возвращается отдельной колонкой: без неё служебный конверт
  /// (пинг сессии, ссылки нет вовсе) неотличим от осиротевшего СООБЩЕНИЯ — у
  /// обоих `event_state` пуст, но первое норма, а второе след потери.
  Future<List<Map<String, Object?>>> outboxFailedWithEventState({
    int limit = 20,
  }) async {
    return _db.rawQuery(
      "SELECT o.msg_id AS msg_id, o.to_device_id AS to_device_id, "
      "o.last_error_code AS last_error_code, o.created_at_ms AS created_at_ms, "
      "o.attempt_count AS attempt_count, o.event_id_ref AS event_id_ref, "
      "(SELECT e.local_state FROM events e WHERE e.event_id = o.event_id_ref) "
      "  AS event_state "
      "FROM outbox o WHERE o.state = ? "
      "ORDER BY o.created_at_ms DESC LIMIT ?",
      [OutboxSendState.failed, limit],
    );
  }

  Future<List<Map<String, Object?>>> outboxListStuck({
    required int olderThanMs,
    int limit = 200,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT msg_id, to_device_id, convo_id, created_at_ms, state '
      'FROM outbox '
      'WHERE state IN (?, ?) AND created_at_ms < ? '
      'ORDER BY created_at_ms ASC '
      'LIMIT ?',
      [
        OutboxSendState.pending,
        OutboxSendState.sending,
        olderThanMs,
        limit,
      ],
    );
    return rows;
  }

  Future<void> pendingReceiptUpsert({
    required String peerDeviceId,
    String? peerProfileId,
    required String payloadEventId,
    String? convoId,
    required String status,
    required int createdAtMs,
    required int updatedAtMs,
  }) async {
    final cleanedPeerDeviceId = peerDeviceId.trim();
    final cleanedPayloadEventId = payloadEventId.trim();
    final cleanedPeerProfileId = peerProfileId?.trim();
    final cleanedConvoId = convoId?.trim();
    final normalizedStatus = MessageReceiptState.normalize(status);
    if (cleanedPeerDeviceId.isEmpty || cleanedPayloadEventId.isEmpty) {
      return;
    }
    if (normalizedStatus != MessageReceiptState.delivered &&
        normalizedStatus != MessageReceiptState.read) {
      return;
    }

    final existing = await _db.query(
      'pending_receipts',
      columns: [
        'peer_profile_id',
        'convo_id',
        'status',
        'created_at_ms',
        'updated_at_ms',
      ],
      where: 'peer_device_id = ? AND payload_event_id = ?',
      whereArgs: [cleanedPeerDeviceId, cleanedPayloadEventId],
      limit: 1,
    );

    var effectivePeerProfileId =
        cleanedPeerProfileId == null || cleanedPeerProfileId.isEmpty
        ? null
        : cleanedPeerProfileId;
    var effectiveConvoId = cleanedConvoId == null || cleanedConvoId.isEmpty
        ? null
        : cleanedConvoId;
    var effectiveStatus = normalizedStatus;
    var effectiveCreatedAtMs = createdAtMs;
    var effectiveUpdatedAtMs = updatedAtMs;

    if (existing.isNotEmpty) {
      final existingRow = existing.first;
      final existingPeerProfileId = (existingRow['peer_profile_id'] as String?)
          ?.trim();
      final existingConvoId = (existingRow['convo_id'] as String?)?.trim();
      final existingStatus = MessageReceiptState.normalize(
        (existingRow['status'] as String?) ?? '',
      );
      final existingCreatedAtMs =
          (existingRow['created_at_ms'] as num?)?.toInt() ?? createdAtMs;
      final existingUpdatedAtMs =
          (existingRow['updated_at_ms'] as num?)?.toInt() ?? updatedAtMs;

      if (!MessageReceiptState.canPromote(
        from: existingStatus,
        to: normalizedStatus,
      )) {
        effectiveStatus = existingStatus;
      }
      if (effectivePeerProfileId == null || effectivePeerProfileId.isEmpty) {
        effectivePeerProfileId =
            existingPeerProfileId == null || existingPeerProfileId.isEmpty
            ? null
            : existingPeerProfileId;
      }
      if (effectiveConvoId == null || effectiveConvoId.isEmpty) {
        effectiveConvoId = existingConvoId == null || existingConvoId.isEmpty
            ? null
            : existingConvoId;
      }
      if (existingCreatedAtMs < effectiveCreatedAtMs) {
        effectiveCreatedAtMs = existingCreatedAtMs;
      }
      if (existingUpdatedAtMs > effectiveUpdatedAtMs) {
        effectiveUpdatedAtMs = existingUpdatedAtMs;
      }
    }

    await _db.insert('pending_receipts', {
      'peer_device_id': cleanedPeerDeviceId,
      'payload_event_id': cleanedPayloadEventId,
      'peer_profile_id': effectivePeerProfileId,
      'convo_id': effectiveConvoId,
      'status': effectiveStatus,
      'created_at_ms': effectiveCreatedAtMs,
      'updated_at_ms': effectiveUpdatedAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PendingReceiptRecord>> pendingReceiptList({
    int limit = 256,
  }) async {
    final rows = await _db.query(
      'pending_receipts',
      orderBy: 'updated_at_ms ASC, peer_device_id ASC, payload_event_id ASC',
      limit: limit,
    );
    return rows
        .map(
          (row) => (
            peerDeviceId: ((row['peer_device_id'] as String?) ?? '').trim(),
            peerProfileId: (row['peer_profile_id'] as String?)?.trim(),
            payloadEventId: ((row['payload_event_id'] as String?) ?? '').trim(),
            convoId: (row['convo_id'] as String?)?.trim(),
            status: MessageReceiptState.normalize(
              (row['status'] as String?) ?? '',
            ),
            createdAtMs: (row['created_at_ms'] as num?)?.toInt() ?? 0,
            updatedAtMs: (row['updated_at_ms'] as num?)?.toInt() ?? 0,
          ),
        )
        .where(
          (row) => row.peerDeviceId.isNotEmpty && row.payloadEventId.isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<int> pendingReceiptCount() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM pending_receipts',
    );
    if (rows.isEmpty) return 0;
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

  /// Recent INBOUND events of [convoId] from [peerDeviceId]'s owner, with
  /// their local read marks — the source for RE-EMITTING receipt state after a
  /// session heal (2026-07-19).
  ///
  /// Why this exists: a flushed receipt wire deletes its pending_receipts rows
  /// atomically with entering the outbox, so a wire that lands in a session
  /// rotation dies WITH its receipt content — the NACK heals the session and
  /// resends events, but receipts are not events and nobody re-emitted them.
  /// Result: the peer read everything, the sender shows one tick forever.
  Future<List<Map<String, Object?>>> recentInboundReceiptTargets({
    required String convoId,
    required String selfDeviceId,
    int limit = 200,
  }) async {
    return _db.query(
      'events',
      columns: ['payload_event_id', 'read_at_ms'],
      where: "convo_id = ? AND sender_device_id IS NOT NULL "
          "AND sender_device_id != '' AND sender_device_id != ? "
          "AND payload_event_id IS NOT NULL AND payload_event_id != '' "
          "AND type IN ('msg','att','sticker')",
      whereArgs: [convoId, selfDeviceId],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
  }

  /// 1:1 convo ids where we READ inbound messages recently — the candidates for
  /// read-receipt reconciliation (2026-07-23). A read receipt is one encrypted
  /// wire per message; if it dies undecryptable and no NACK fires, the sender is
  /// stranded on one tick forever with no periodic safety net. The reader-side
  /// backstop re-emits read state for these; bounded + distinct so it stays
  /// cheap, group convos excluded (they use room_message_receipts).
  Future<List<String>> convoIdsWithRecentInboundReads({
    required String selfDeviceId,
    required int readAfterMs,
    int limit = 64,
  }) async {
    final rows = await _db.rawQuery(
      "SELECT DISTINCT convo_id FROM events "
      "WHERE sender_device_id IS NOT NULL AND sender_device_id != '' "
      "AND sender_device_id != ? "
      "AND read_at_ms IS NOT NULL AND read_at_ms > ? "
      "AND payload_event_id IS NOT NULL AND payload_event_id != '' "
      "AND type IN ('msg','att','sticker') "
      "AND convo_id NOT LIKE 'group:%' AND convo_id NOT LIKE 'dev:%' "
      "AND convo_id NOT LIKE 'req:%' "
      "ORDER BY read_at_ms DESC LIMIT ?",
      [selfDeviceId, readAfterMs, limit],
    );
    return rows
        .map((r) => ((r['convo_id'] as String?) ?? '').trim())
        .where((c) => c.isNotEmpty)
        .toList(growable: false);
  }

  /// Payload ids of inbound messages in [convoId] READ after [readAfterMs],
  /// newest-read first and hard-capped (2026-07-23). The reader-side backstop
  /// re-emits READ receipts only for this bounded, recently-read set — never the
  /// full history — so periodic reconciliation cannot turn into a receipt storm.
  Future<List<String>> recentReadReceiptTargets({
    required String convoId,
    required String selfDeviceId,
    required int readAfterMs,
    int limit = 16,
  }) async {
    final rows = await _db.query(
      'events',
      columns: ['payload_event_id'],
      where: "convo_id = ? AND sender_device_id IS NOT NULL "
          "AND sender_device_id != '' AND sender_device_id != ? "
          "AND payload_event_id IS NOT NULL AND payload_event_id != '' "
          "AND read_at_ms IS NOT NULL AND read_at_ms > ? "
          "AND type IN ('msg','att','sticker')",
      whereArgs: [convoId, selfDeviceId, readAfterMs],
      orderBy: 'read_at_ms DESC',
      limit: limit,
    );
    return rows
        .map((r) => ((r['payload_event_id'] as String?) ?? '').trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
  }

  /// Room counterpart of [recentReadReceiptTargets]: messages I read recently
  /// in rooms, WITH the device that wrote each one.
  ///
  /// The 1:1 query can take the peer from the conversation id; a room has one
  /// conversation and many authors, so the author has to come from the row. The
  /// reconcile backstop skipped rooms entirely because of that shape difference
  /// — which meant a room receipt lost to an undecryptable wire had no periodic
  /// safety net at all, and the author stayed convinced the member never got
  /// the message. That is now the very signal the convergence backstop acts on,
  /// so the gap had to close.
  Future<List<({String roomId, String senderDeviceId, String payloadEventId})>>
  roomReadReceiptReconcileTargets({
    required String selfDeviceId,
    required int readAfterMs,
    Iterable<String> excludedSenderDeviceIds = const <String>[],
    int limit = 64,
  }) async {
    final excluded = <String>{selfDeviceId.trim(), ...excludedSenderDeviceIds}
      ..removeWhere((e) => e.isEmpty);
    final placeholders = List.filled(excluded.length, '?').join(',');
    final rows = await _db.query(
      'events',
      columns: ['convo_id', 'sender_device_id', 'payload_event_id'],
      where:
          "convo_id LIKE 'group:%' AND sender_device_id IS NOT NULL "
          "AND sender_device_id != '' "
          "${excluded.isEmpty ? '' : 'AND sender_device_id NOT IN ($placeholders) '}"
          "AND payload_event_id IS NOT NULL AND payload_event_id != '' "
          "AND read_at_ms IS NOT NULL AND read_at_ms > ? "
          "AND type IN ('msg','att','sticker')",
      whereArgs: [...excluded, readAfterMs],
      orderBy: 'read_at_ms DESC',
      limit: limit,
    );
    return rows
        .map(
          (r) => (
            roomId: ((r['convo_id'] as String?) ?? '').trim(),
            senderDeviceId: ((r['sender_device_id'] as String?) ?? '').trim(),
            payloadEventId: ((r['payload_event_id'] as String?) ?? '').trim(),
          ),
        )
        .where(
          (r) =>
              r.roomId.isNotEmpty &&
              r.senderDeviceId.isNotEmpty &&
              r.payloadEventId.isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<void> pendingReceiptQueueOutbox({
    required String msgId,
    required String toDeviceId,
    required String ciphertextB64,
    required int ttlSeconds,
    required int nextRetryAtMs,
    required int createdAtMs,
    Iterable<PendingReceiptRecord> pendingReceipts =
        const <PendingReceiptRecord>[],
    String? convoId,
    int priority = 0,
    String transportHint = 'receipt',
    String retryBucket = 'receipt',
  }) async {
    final cleanedToDeviceId = toDeviceId.trim();
    if (cleanedToDeviceId.isEmpty) return;
    final dedupedReceiptKeys = <String>{};
    final receiptRows = pendingReceipts
        .where((record) {
          final key = '${record.peerDeviceId}\n${record.payloadEventId}';
          if (record.peerDeviceId.isEmpty || record.payloadEventId.isEmpty) {
            return false;
          }
          return dedupedReceiptKeys.add(key);
        })
        .toList(growable: false);
    await _db.transaction((txn) async {
      await txn.insert('outbox', {
        'msg_id': msgId,
        'to_device_id': cleanedToDeviceId,
        'ciphertext_b64': ciphertextB64,
        'ttl_seconds': ttlSeconds,
        'state': OutboxSendState.pending,
        'attempt_count': 0,
        'next_retry_at_ms': nextRetryAtMs,
        'created_at_ms': createdAtMs,
        'convo_id': convoId,
        'priority': priority,
        'transport_hint': transportHint,
        'retry_bucket': retryBucket,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (receiptRows.isEmpty) {
        return;
      }
      final batch = txn.batch();
      for (final row in receiptRows) {
        batch.delete(
          'pending_receipts',
          where: 'peer_device_id = ? AND payload_event_id = ?',
          whereArgs: [row.peerDeviceId, row.payloadEventId],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> pendingNoDeviceSendUpsert({
    required String localEventId,
    required String profileId,
    required Uint8List payloadBytes,
    String? transportMetaJson,
    required int createdAtMs,
  }) async {
    await _db.insert('pending_no_device_send', {
      'local_event_id': localEventId,
      'profile_id': profileId,
      'payload_b64': base64Encode(payloadBytes),
      'transport_meta_json': transportMetaJson,
      'created_at_ms': createdAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> pendingNoDeviceSendDelete(String localEventId) async {
    await _db.delete(
      'pending_no_device_send',
      where: 'local_event_id = ?',
      whereArgs: [localEventId],
    );
  }

  Future<List<Map<String, Object?>>> pendingNoDeviceSendListAll() async {
    return _db.query(
      'pending_no_device_send',
      orderBy: 'created_at_ms ASC, local_event_id ASC',
    );
  }

  // ── A1 ZERO-LOSS: deferred room (group) inbound ────────────────────────────
  // A DECRYPTED group message whose sender is not yet in our local roster is
  // parked here — NOT the wire ciphertext (the double-ratchet key is consumed on
  // decrypt, so a re-decrypt of the same wire would fail). It is re-applied on
  // membership convergence and TTL-pruned if the sender is never confirmed.
  // Keyed by the same synthetic id as the events table ('grp:<msgId>:<devId>')
  // so parking + eventual normal delivery stay idempotent.

  Future<void> deferredRoomInboundUpsert({
    required String syntheticEventId,
    required String groupId,
    required String senderProfileId,
    String? senderDeviceId,
    required String commandText,
    String? msgId,
    String? ciphertextB64,
    required int createdAtMs,
  }) async {
    await _db.insert('deferred_room_inbound', {
      'synthetic_event_id': syntheticEventId,
      'group_id': groupId,
      'sender_profile_id': senderProfileId,
      'sender_device_id': (senderDeviceId ?? '').trim().isEmpty
          ? null
          : senderDeviceId!.trim(),
      'command_text': commandText,
      'msg_id': (msgId ?? '').trim().isEmpty ? null : msgId!.trim(),
      'ciphertext_b64': ciphertextB64,
      'created_at_ms': createdAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, Object?>>> deferredRoomInboundListForGroup(
    String groupId,
  ) async {
    final gid = groupId.trim();
    if (gid.isEmpty) return const <Map<String, Object?>>[];
    return _db.query(
      'deferred_room_inbound',
      where: 'group_id = ?',
      whereArgs: [gid],
      orderBy: 'created_at_ms ASC, synthetic_event_id ASC',
    );
  }

  Future<List<String>> deferredRoomInboundGroupIds() async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT group_id FROM deferred_room_inbound',
    );
    return rows
        .map((r) => ((r['group_id'] as String?) ?? '').trim())
        .where((g) => g.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> deferredRoomInboundDelete(String syntheticEventId) async {
    await _db.delete(
      'deferred_room_inbound',
      where: 'synthetic_event_id = ?',
      whereArgs: [syntheticEventId],
    );
  }

  Future<int> deferredRoomInboundPrune({required int olderThanMs}) async {
    return _db.delete(
      'deferred_room_inbound',
      where: 'created_at_ms <= ?',
      whereArgs: [olderThanMs],
    );
  }

  Future<int> deferredRoomInboundCountAll() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM deferred_room_inbound',
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  // ===========================================================================
  // ZERO-LOSS inbound journal (see `inbound_journal` in _ensureCriticalTables).
  // ===========================================================================

  /// Durably capture the decrypted [plaintextB64] for [msgId] BEFORE the ratchet
  /// advance is persisted. `replace` so a re-decrypt of the same wire overwrites
  /// cleanly. Keyed by msg_id (unique per delivered message).
  Future<void> inboundJournalPut({
    required String msgId,
    String? senderDeviceId,
    required String plaintextB64,
    required int createdAtMs,
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).insert('inbound_journal', {
      'msg_id': msgId,
      'sender_device_id': (senderDeviceId ?? '').trim().isEmpty
          ? null
          : senderDeviceId!.trim(),
      'plaintext_b64': plaintextB64,
      'created_at_ms': createdAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Return the journaled row for [msgId], or null. Used to recover a message
  /// that decrypted successfully once but was killed before it could be applied
  /// — its ciphertext is now undecryptable (ratchet advanced) but the plaintext
  /// is safe here.
  Future<Map<String, Object?>?> inboundJournalGet(String msgId) async {
    final rows = await _db.query(
      'inbound_journal',
      where: 'msg_id = ?',
      whereArgs: [msgId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Drop the journal entry for [msgId] once it has been durably applied.
  Future<void> inboundJournalDelete(String msgId) async {
    await _db.delete(
      'inbound_journal',
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
  }

  /// TTL-prune orphaned journal entries (applied rows are deleted eagerly; this
  /// only sweeps entries stranded by a crash that never re-delivered).
  Future<int> inboundJournalPrune({required int olderThanMs}) async {
    return _db.delete(
      'inbound_journal',
      where: 'created_at_ms <= ?',
      whereArgs: [olderThanMs],
    );
  }

  Future<int> inboundJournalCountAll() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM inbound_journal',
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<int> requestsCountPending() async {
    final rows = await _db.rawQuery(
      "SELECT COUNT(*) AS n FROM requests WHERE status = 'pending'",
    );
    if (rows.isEmpty) return 0;
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, List<Map<String, Object?>>>> exportTables(
    List<String> tableNames, {
    Map<String, Set<String>>? allowedColumnsByTable,
  }) async {
    final out = <String, List<Map<String, Object?>>>{};
    for (final table in tableNames) {
      final t = table.trim();
      if (t.isEmpty) continue;
      final allowedColumns = allowedColumnsByTable?[t];
      if (allowedColumnsByTable != null && allowedColumns == null) {
        throw StateError('Unsupported snapshot table: $t');
      }
      final rows = await _db.query(t);
      // 🔴 Осознанно исключённые столбцы отбрасываются ДО проверки (09.08.2026).
      //
      // Проверка падает на столбце, которого нет в контракте, и это правильная
      // защита: она заставляет решить про каждый новый столбец, вместо того чтобы
      // тот молча уехал в копию. Но у решения «не переносить» не было способа
      // выразиться — столбец, про который решили «не надо», выглядел как забытый
      // и валил СОЗДАНИЕ КОПИИ целиком. Именно так и сломался экспорт после
      // добавления кэша блоба стикеров (v66).
      //
      // Различие теперь явное: нет ни в одном списке — ошибка; в списке
      // исключений — не едет. Защита сохранена, копия не ломается.
      final excludedColumns = kSafeBackupSnapshotExcludedColumnsByTable[t];
      out[t] = rows
          .map((row) {
            final mapped = <String, Object?>{};
            for (final entry in row.entries) {
              if (excludedColumns != null &&
                  excludedColumns.contains(entry.key)) {
                continue;
              }
              mapped[entry.key] = entry.value;
            }
            _validateSnapshotRow(
              table: t,
              row: mapped,
              allowedColumns: allowedColumns,
            );
            return mapped;
          })
          .toList(growable: false);
    }
    return out;
  }

  Future<void> importTables(
    Map<String, List<Map<String, Object?>>> snapshot, {
    Map<String, Set<String>>? allowedColumnsByTable,
  }) async {
    if (snapshot.isEmpty) return;
    await _db.transaction((txn) async {
      for (final entry in snapshot.entries) {
        final table = entry.key.trim();
        if (table.isEmpty) continue;
        final allowedColumns = allowedColumnsByTable?[table];
        if (allowedColumnsByTable != null && allowedColumns == null) {
          throw StateError('Unsupported snapshot table: $table');
        }
        final rows = entry.value;
        for (final row in rows) {
          _validateSnapshotRow(
            table: table,
            row: row,
            allowedColumns: allowedColumns,
          );
        }
        await txn.delete(table);
        for (final row in rows) {
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  static void _validateSnapshotRow({
    required String table,
    required Map<String, Object?> row,
    Set<String>? allowedColumns,
  }) {
    for (final entry in row.entries) {
      final column = entry.key.trim();
      if (column.isEmpty) {
        throw StateError('Invalid snapshot row for $table');
      }
      if (allowedColumns != null && !allowedColumns.contains(column)) {
        throw StateError('Unsupported snapshot column $table.$column');
      }
      if (!isValidSafeBackupSnapshotScalar(entry.value)) {
        throw StateError('Invalid snapshot value for $table.$column');
      }
    }
  }

  Future<void> close() => _db.close();

  /// Whether the underlying sqflite handle is still open. sqflite's
  /// `singleInstance: true` (the default we run with) means a second
  /// `AppDb.open` of the same path shares ONE native handle — so a `close()`
  /// anywhere (a re-init race, an import flow, a disposed controller) silently
  /// kills every live reference. Ops then throw
  /// `DatabaseException(error_database_closed)` forever ("chat is empty until I
  /// restart the app"). The controller watchdog polls this to self-heal by
  /// reopening. Best-effort: an errored probe counts as closed.
  bool get isOpen {
    try {
      return _db.isOpen;
    } catch (_) {
      return false;
    }
  }

  /// Whether a REAL operation reports the handle closed. `isOpen` above trusts
  /// sqflite's Dart-side flag, which stays `true` after another singleInstance
  /// reference calls `close()` — so the zombie-DB watchdog, gated on `!isOpen`,
  /// never fired while every actual query threw `error_database_closed` in a
  /// tight loop (captured live on an iPhone 2026-07-23: 97 failures/2 min, chat
  /// frozen, self-heal silent). Probe with a trivial query instead: only a
  /// genuine "closed" verdict returns true, so a transient/other error never
  /// triggers a spurious reopen.
  Future<bool> probeClosed() async {
    try {
      await _db.rawQuery('SELECT 1;');
      return false;
    } catch (e) {
      return e.toString().toLowerCase().contains('database_closed');
    }
  }
}
