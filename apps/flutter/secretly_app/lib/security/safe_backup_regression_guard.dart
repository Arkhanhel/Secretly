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
}
