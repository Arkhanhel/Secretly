// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which chats were deleted **on this desktop**, so re-imported
/// history does not resurrect them.
///
/// **Why this exists.** Deleting a chat is local: it removes the conversation
/// and its rows from this device's database and tells no one. Separately, the
/// desktop asks the phone for a recent-history window on boot
/// (`PeerHistoryService.maybeSyncOnBoot`), and applying a chunk deliberately
/// **materialises conversation rows** — the applier says so itself: "we
/// materialize the conversation row, settings, and membership roster so
/// subsequent `db.insertEvent` calls don't leave the chat list empty".
///
/// Put together, those two correct behaviours produce a wrong result: a chat
/// deleted on the desktop comes back on the next sync, carrying the very
/// messages the user got rid of. Reported as "постоянно то старые удалённые
/// чаты то ещё что-то".
///
/// **Why a tombstone and not a filter on everything.** A deletion should not
/// silence a conversation forever — if someone writes again, the chat must
/// come back, exactly as it would on the phone. So the tombstone records WHEN
/// the deletion happened and only hides events older than that moment. One
/// genuinely new message is newer than the tombstone, and the chat returns on
/// its own; the tombstone is then dropped so it can never hide anything again.
///
/// Desktop-only by construction: the timestamps live in this app's
/// preferences, nothing is sent anywhere, and the shared delivery code is
/// untouched. Syncing deletion between devices is a separate, destructive
/// decision that belongs to the owner — see
/// `docs/SYNC_PARITY_AUDIT_2026-09-08.md` §4.4.
class DesktopDeletedChats {
  DesktopDeletedChats._();

  static const String _kPrefix = 'desktop_deleted_chat_at_ms_v1:';

  /// convoId → when it was deleted here. Loaded once, kept in memory so the
  /// chat-list filter stays synchronous.
  static final Map<String, int> _deletedAtMs = <String, int>{};
  static bool _loaded = false;

  static Future<void> load({SharedPreferences? prefsForTest}) async {
    if (_loaded && prefsForTest == null) return;
    final prefs = prefsForTest ?? await SharedPreferences.getInstance();
    _deletedAtMs.clear();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_kPrefix)) continue;
      final convoId = key.substring(_kPrefix.length);
      final atMs = prefs.getInt(key) ?? 0;
      if (convoId.isEmpty || atMs <= 0) continue;
      _deletedAtMs[convoId] = atMs;
    }
    _loaded = true;
  }

  /// Records that [convoId] was deleted here, now.
  static Future<void> remember(
    String convoId, {
    int? atMs,
    SharedPreferences? prefsForTest,
  }) async {
    final id = convoId.trim();
    if (id.isEmpty) return;
    final ms = atMs ?? DateTime.now().millisecondsSinceEpoch;
    _deletedAtMs[id] = ms;
    try {
      final prefs = prefsForTest ?? await SharedPreferences.getInstance();
      await prefs.setInt('$_kPrefix$id', ms);
    } catch (_) {
      // In-memory is enough for this session; the next deletion re-records it.
    }
  }

  static Future<void> _forget(
    String convoId, {
    SharedPreferences? prefsForTest,
  }) async {
    if (_deletedAtMs.remove(convoId) == null) return;
    try {
      final prefs = prefsForTest ?? await SharedPreferences.getInstance();
      await prefs.remove('$_kPrefix$convoId');
    } catch (_) {
      // Dropped in memory already; a stale key only costs one comparison.
    }
  }

  /// Whether a conversation whose newest event is [lastEventAtMs] should stay
  /// hidden because it was deleted here afterwards.
  ///
  /// Returns false — and forgets the tombstone — as soon as the conversation
  /// carries something newer than the deletion, because that is real new
  /// activity and hiding it would be the worse bug.
  static bool isSuppressed({
    required String convoId,
    required int lastEventAtMs,
    SharedPreferences? prefsForTest,
  }) {
    final deletedAtMs = _deletedAtMs[convoId];
    if (deletedAtMs == null) return false;
    if (lastEventAtMs > deletedAtMs) {
      // New activity wins. Drop the tombstone so this cannot come back to
      // haunt a later, unrelated re-import.
      unawaited(_forget(convoId, prefsForTest: prefsForTest));
      return false;
    }
    return true;
  }

  @visibleForTesting
  static int get count => _deletedAtMs.length;

  @visibleForTesting
  static void resetForTest() {
    _deletedAtMs.clear();
    _loaded = false;
  }

  /// Local `unawaited` so this file needs no `dart:async` import just for it.
  static void unawaited(Future<void> future) {
    future.catchError((Object _) {});
  }
}
