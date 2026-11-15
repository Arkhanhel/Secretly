// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Refuses to let a degenerate backup overwrite a good one.
///
/// DATA LOSS (2026-07-20). The server keeps exactly ONE backup per profile —
/// `profile_backups` is `PRIMARY KEY (profile_id)` with `ON CONFLICT DO
/// UPDATE`, so every upload destroys the previous copy. On the same day a
/// device re-keyed itself and came up with an empty database. Those two facts
/// together are a trap: with automatic backup enabled, the empty state would
/// have been uploaded over the user's last good copy within the interval,
/// turning a recoverable incident into permanent loss.
///
/// So an unattended backup that has lost most of the history is treated as
/// evidence of a broken device, not as a new state to preserve. The user can
/// still overwrite deliberately — "back up now" passes `force`.
class SafeBackupRegressionGuard {
  const SafeBackupRegressionGuard._();

  /// Below this fraction of the previous event count, an automatic backup is
  /// held back. Normal attrition (disappearing messages, a cleared chat) moves
  /// the count gently; losing half of everything between two runs does not.
  static const double shrinkFloorFraction = 0.5;

  /// Whether [nextEvents] may overwrite a stored backup of [previousEvents].
  ///
  /// Fails OPEN when there is nothing to protect: an unknown or empty previous
  /// count always allows the write, so first-time and post-restore backups are
  /// never blocked.
  static bool allowsOverwrite({
    required int previousEvents,
    required int nextEvents,
  }) {
    if (previousEvents <= 0) return true; // nothing worth protecting yet
    if (nextEvents >= previousEvents) return true; // grew or held steady
    if (nextEvents <= 0) return false; // everything gone — never trust this
    return nextEvents >= previousEvents * shrinkFloorFraction;
  }

  /// Human-readable reason for a refusal, for the backup screen and the log.
  /// Returns null when the write is allowed.
  static String? refusalReason({
    required int previousEvents,
    required int nextEvents,
  }) {
    if (allowsOverwrite(
      previousEvents: previousEvents,
      nextEvents: nextEvents,
    )) {
      return null;
    }
    return 'Skipped: this device now holds $nextEvents messages but the last '
        'backup held $previousEvents. Refusing to overwrite it automatically.';
  }

  /// Сколько сообщений в снимке базы из копии (таблица `events`).
  /// `null` — снимка нет или он не того вида: сравнивать не с чем.
  static int? eventsInSnapshot(Map<String, Object?>? dbSnapshot) {
    final rows = dbSnapshot?['events'];
    return rows is List ? rows.length : null;
  }

  /// 🔴 Первая автокопия с устройства, которое ещё ни разу не писало копию
  /// (13.11.2026).
  ///
  /// Порог [allowsOverwrite] хранится на устройстве. У устройства, где
  /// личность восстановили ключом (история пустая) или порог стёрт, его нет —
  /// и защита «открыта»: включил автокопию → полная копия на сервере затёрта
  /// пустой. Поэтому перед первой записью смотрим на саму копию на сервере.
  ///
  /// Возвращает причину отказа или `null`, если писать можно:
  /// * копии на сервере нет — можно;
  /// * копия читается этим паролем — тот же порог, что и всегда;
  /// * копия есть, но этим паролем не открывается — не затираем: её мог
  ///   сделать сам человек со старым паролем. Ручное сохранение по-прежнему
  ///   доступно, после него автокопия пойдёт как обычно.
  static String? firstOverwriteRefusal({
    required bool serverHasBackup,
    required bool openedWithThisPassword,
    required int? serverEvents,
    required int nextEvents,
  }) {
    if (!serverHasBackup) return null;
    if (!openedWithThisPassword) {
      return 'Автокопия не сохранена: на сервере уже есть копия, сделанная '
          'с другим паролем. Чтобы не потерять её, автокопия её не затирает. '
          'Если она больше не нужна, сохраните копию вручную.';
    }
    final stored = serverEvents ?? 0;
    if (allowsOverwrite(previousEvents: stored, nextEvents: nextEvents)) {
      return null;
    }
    return 'Автокопия не сохранена: в копии на сервере $stored сообщений, '
        'а на этом устройстве $nextEvents. Чтобы не потерять историю, '
        'автокопия её не затирает. Восстановите копию или сохраните вручную.';
  }
}
