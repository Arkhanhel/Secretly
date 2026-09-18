// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Recent-reactions cache for the desktop reactions picker.
//
// PR3.9 (2026-05-19, SPRINT2_AUDIT §14): the expanded reactions picker
// renders a Telegram-style top section labelled «Недавние» that surfaces
// the most-recently-used emojis. Persistence lives in SharedPreferences
// (key `secretly_desktop_recent_reactions`) so the row survives app
// restarts and is shared across every chat thread on this device.
//
// PR3.10 (2026-05-19, SPRINT2_AUDIT §15): the store now extends
// [ChangeNotifier] and exposes a [ValueListenable<List<String>>] so the
// expanded picker (and anything else that cares) rebuilds in-place when a
// new emoji is recorded. The previous PR3.9 design re-snapshotted
// `current` each time the picker opened — that worked but felt stale
// within a single open session. With the listener model, picking the same
// emoji twice in a row visibly bumps it to the front of «Недавние».
//
// The store is intentionally tiny: a singleton holding a most-recent-first
// list capped at [kRecentReactionsMax] entries. `record()` is called from
// `chat_thread_panel._applyReaction` after a successful toggle; `load()`
// is fired from app boot in `app_controller` so the prefs read latency is
// amortised before the user has a chance to right-click their first bubble.
//
// Mobile (lib/ui/chat_screen.dart) is untouched per project rule.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPrefsKey = 'secretly_desktop_recent_reactions';

/// Maximum number of emojis kept in the «Недавние» section.
const int kRecentReactionsMax = 32;

/// Persistent most-recent-first cache of emoji reactions the local user
/// has applied. Safe to call before [load] — read APIs return an empty
/// list until the prefs read completes. Implements [ValueListenable] so UI
/// can listen for live updates within a single picker session.
class DesktopRecentReactionsStore extends ChangeNotifier
    implements ValueListenable<List<String>> {
  DesktopRecentReactionsStore._();

  /// Process-wide singleton. Keeping it as a singleton avoids passing the
  /// instance through every widget constructor in the chat tree.
  static final DesktopRecentReactionsStore instance =
      DesktopRecentReactionsStore._();

  SharedPreferences? _prefs;
  List<String> _cache = const <String>[];
  Future<void>? _loadFuture;

  /// In-memory snapshot of the cache. Safe to call synchronously: if the
  /// store hasn't loaded yet returns an empty list and the picker simply
  /// won't render the «Недавние» section that frame.
  List<String> get current => List<String>.unmodifiable(_cache);

  /// [ValueListenable] alias for [current] so `ValueListenableBuilder` and
  /// `AnimatedBuilder` work directly against the store.
  @override
  List<String> get value => current;

  /// Ensures the SharedPreferences-backed cache is loaded. Idempotent —
  /// callers that just want to be safe can `await store.load()` at picker
  /// open time without worrying about repeated I/O.
  Future<void> load() {
    return _loadFuture ??= _doLoad();
  }

  Future<void> _doLoad() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final list = _prefs!.getStringList(_kPrefsKey);
      if (list != null && list.isNotEmpty) {
        _cache = list.take(kRecentReactionsMax).toList(growable: false);
        notifyListeners();
      }
    } catch (_) {
      // Best-effort: missing recents are a non-fatal UX regression.
    }
  }

  /// Moves [emoji] to the front of the recent list and persists. Drops
  /// duplicates and trims to [kRecentReactionsMax]. Safe before [load] —
  /// will lazy-load first, so the recorded value survives a cold start
  /// even on the user's very first reaction. Notifies listeners on
  /// success so the picker rebuilds in place.
  Future<void> record(String emoji) async {
    final trimmed = emoji.trim();
    if (trimmed.isEmpty) return;
    await load();
    // Skip the notify when the move is a no-op (already at the front).
    if (_cache.isNotEmpty && _cache.first == trimmed) return;
    final next = <String>[trimmed];
    for (final e in _cache) {
      if (e == trimmed) continue;
      next.add(e);
      if (next.length >= kRecentReactionsMax) break;
    }
    _cache = List<String>.unmodifiable(next);
    notifyListeners();
    try {
      await _prefs?.setStringList(_kPrefsKey, _cache);
    } catch (_) {
      // Best-effort persistence; in-memory cache is still updated.
    }
  }
}
