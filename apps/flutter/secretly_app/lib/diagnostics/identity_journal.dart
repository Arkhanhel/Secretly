// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Why this install's Secretly identity changed — a breadcrumb that OUTLIVES
/// the change itself.
///
/// The problem it exists to solve: when a person's identity vanishes, they
/// become a new profile, everyone who ever added them keeps writing to the old
/// one, and their purchases stop being theirs. On 2026-07-30 we found 38 such
/// events on the relay — 19 of them identities that died less than an hour
/// after birth, nine within a MINUTE — and could not say why a single one
/// happened. The answer had to be reconstructed by joining two production
/// databases, and it still came out inconclusive.
///
/// Deliberately a FILE, not a preference. One of the live hypotheses is that
/// the preferences themselves lose the profile id; recording the evidence in
/// the very store under suspicion would be circular. This file survives a
/// profile reset, a database wipe and a preferences clear — everything short of
/// deleting the app.
///
/// Append-only and capped: it is evidence, so nothing here is ever rewritten,
/// and it can never grow without bound.
class IdentityJournal {
  const IdentityJournal._();

  static const String fileName = 'secretly_identity_journal.jsonl';

  /// Enough to cover a burst (we saw eight identities in one hour) with room to
  /// spare, while staying a few kilobytes.
  static const int maxEntries = 40;

  // ── Reasons. Each names WHO decided, so the next investigation starts from a
  // fact instead of a hypothesis. ──────────────────────────────────────────
  /// No profile id in preferences at startup. The `traces` field is what makes
  /// this entry worth having: a fresh install has none, whereas leftovers from
  /// a previous identity mean local state was PARTIALLY lost — the anomaly.
  static const String reasonNoLocalProfile = 'no_local_profile';

  /// The keys server answered that our profile does not exist, at startup.
  static const String reasonStartupProfileMissing = 'startup_profile_missing';

  /// The keys server answered that our profile does not exist, during the
  /// activity heartbeat or the inactivity settings sync.
  static const String reasonServerSaysDeleted = 'server_says_deleted';

  /// Another of our own devices revoked this one.
  static const String reasonSessionRevoked = 'session_revoked';

  /// The person asked for it: reset, delete account, new profile, restore.
  static const String reasonUserInitiated = 'user_initiated';

  /// Кто-то стёр `profile_id` из настроек. `detail['by']` называет МЕСТО.
  ///
  /// 🔴 ЗАЧЕМ ОТДЕЛЬНАЯ ПРИЧИНА. 09.08.2026 в журнале осталась запись
  /// `no_local_profile` с `had_device_id=true` и `db_file_present=true`: profile_id
  /// пропал, device_id остался. Собеседники увидели «номер безопасности
  /// изменился». Кто именно стёр — установить не удалось: журнал записал ФАКТ, но
  /// не ВИНОВНИКА, а стирающих мест семь, и два автоматических — десктопные.
  ///
  /// Смена личности — самая дорогая поломка в проекте (потеря истории, красные
  /// галочки у всех контактов). Она обязана называть свою причину сама, с первого
  /// случая. Ср. тот же урок с переотправкой: путь назвал только стек вызова.
  static const String reasonProfileIdCleared = 'profile_id_cleared';

  /// Записать, что `profile_id` стёрт, и КЕМ.
  ///
  /// [by] — короткое имя места в коде, не текст для человека.
  static Future<void> recordProfileIdCleared({
    required String by,
    required int nowMs,
    String? previousProfileId,
    String? previousDeviceId,
    bool deviceIdClearedToo = false,
  }) => record(
    reason: reasonProfileIdCleared,
    nowMs: nowMs,
    previousProfileId: previousProfileId,
    previousDeviceId: previousDeviceId,
    detail: <String, Object?>{
      'by': by,
      // Перекос «профиля нет, устройство есть» — это и есть аномалия 09.08.
      // Осознанный сброс стирает оба.
      'device_id_cleared_too': deviceIdClearedToo,
    },
  );

  /// Nothing here may hang its caller. The journal is read on the diagnostics
  /// screen and written on the startup path; a slow or unavailable filesystem
  /// must degrade to "no journal", never to a frozen screen or a stalled boot.
  static const Duration _ioTimeout = Duration(seconds: 2);

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory().timeout(_ioTimeout);
    return File(p.join(dir.path, fileName));
  }

  /// Appends one entry. Never throws: a diagnostic that can break the thing it
  /// is diagnosing is worse than no diagnostic.
  static Future<void> record({
    required String reason,
    required int nowMs,
    String? previousProfileId,
    String? previousDeviceId,
    Map<String, Object?> detail = const <String, Object?>{},
  }) async {
    try {
      final entry = <String, Object?>{
        'at_ms': nowMs,
        'reason': reason,
        // Prefixes only. Enough to correlate with a server-side record, not
        // enough to be a copy of the user's identity sitting in a log file.
        if (previousProfileId != null && previousProfileId.trim().isNotEmpty)
          'prev_profile': _prefix(previousProfileId),
        if (previousDeviceId != null && previousDeviceId.trim().isNotEmpty)
          'prev_device': _prefix(previousDeviceId),
        ...detail,
      };
      final file = await _file();
      final existing = await _readLines(file).timeout(_ioTimeout);
      existing.add(jsonEncode(entry));
      // Keep the newest; the oldest entry is the least useful once the file is
      // full, and dropping it is better than refusing to record the newest.
      final kept = existing.length > maxEntries
          ? existing.sublist(existing.length - maxEntries)
          : existing;
      await file
          .writeAsString('${kept.join('\n')}\n', flush: true)
          .timeout(_ioTimeout);
    } catch (_) {
      // best-effort by design
    }
  }

  /// Every entry, oldest first. Malformed lines are skipped rather than
  /// failing the read — a truncated write must not hide the entries around it.
  static Future<List<Map<String, Object?>>> read() async {
    try {
      final file = await _file();
      final out = <Map<String, Object?>>[];
      for (final line in await _readLines(file).timeout(_ioTimeout)) {
        try {
          final decoded = jsonDecode(line);
          if (decoded is Map<String, dynamic>) out.add(decoded);
        } catch (_) {
          // skip this line only
        }
      }
      return out;
    } catch (_) {
      return const <Map<String, Object?>>[];
    }
  }

  /// Compact, human-readable form for the diagnostics report the user can send.
  static Future<String> summarize() async {
    final entries = await read();
    if (entries.isEmpty) return 'identity_journal=empty';
    final lines = entries.map((e) {
      final at = (e['at_ms'] as num?)?.toInt() ?? 0;
      final when = at > 0
          ? DateTime.fromMillisecondsSinceEpoch(at).toIso8601String()
          : '?';
      final rest = Map<String, Object?>.from(e)
        ..remove('at_ms')
        ..remove('reason');
      return '  $when ${e['reason']} ${rest.isEmpty ? '' : jsonEncode(rest)}';
    });
    return 'identity_journal (${entries.length}):\n${lines.join('\n')}';
  }

  static Future<List<String>> _readLines(File file) async {
    if (!await file.exists()) return <String>[];
    final text = await file.readAsString();
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  static String _prefix(String value) {
    final v = value.trim();
    return v.length <= 8 ? v : v.substring(0, 8);
  }
}
