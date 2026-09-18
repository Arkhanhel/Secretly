// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notices that this desktop has been offline long enough to have missed mail,
/// and says so once.
///
/// **The hazard.** Two server-side windows decide what a silent device gets,
/// and both are documented in `server/keys/src/store.rs`:
///
///  * the relay **mailbox TTL is 7 days** — mail older than that is gone from
///    the server whether or not anyone is still encrypting to this device;
///  * the keys server's **device-liveness window is 14 days**, measured against
///    the profile's freshest device — past it, senders stop encrypting to this
///    one at all, "automatically, by design".
///
/// So a desktop closed for a fortnight while the phone is used daily quietly
/// stops being part of the conversation, and nothing on screen ever said so.
/// The desktop TZ raised this as DLV-3 and left it open: "предупреждения в
/// интерфейсе нет — остаётся задачей".
///
/// **Why the threshold is 7 and not 14.** The TZ framed it around the 14-day
/// fanout window, but that is the SECOND thing to go wrong. The first is the
/// mailbox: at seven days, mail has already begun expiring unread. Warning at
/// fourteen would be warning after the loss.
///
/// Entirely desktop-side by construction: it stores its own timestamp in this
/// app's preferences and compares it to the clock. It asks the controller
/// nothing and changes nothing about delivery — it only tells the truth about
/// a gap that already happened.
class DesktopAbsence {
  DesktopAbsence._();

  static const String _kLastSeenKey = 'desktop_last_seen_at_ms_v1';

  /// Relay mailbox TTL. The first point at which a silent device has provably
  /// lost mail.
  static const int mailboxTtlDays = 7;

  /// Keys-server device-liveness window: past this, senders drop the device
  /// from their fanout entirely.
  static const int fanoutWindowDays = 14;

  /// How long this desktop was away, in whole days, when the gap is long
  /// enough to have cost something. Null means there is nothing to say.
  ///
  /// A [ValueNotifier] rather than a one-shot value so the notice can be
  /// dismissed by setting it back to null.
  static final ValueNotifier<int?> awayDays = ValueNotifier<int?>(null);

  static Timer? _heartbeat;

  /// Reads the previous timestamp, decides whether to warn, and starts keeping
  /// the timestamp fresh.
  ///
  /// Call once, after the controller is up. Safe to call again — it restarts
  /// the heartbeat rather than stacking timers.
  static Future<void> start({
    DateTime? now,
    SharedPreferences? prefsForTest,
  }) async {
    final prefs = prefsForTest ?? await SharedPreferences.getInstance();
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final lastSeenMs = prefs.getInt(_kLastSeenKey) ?? 0;

    awayDays.value = absenceDaysToWarnAbout(
      lastSeenMs: lastSeenMs,
      nowMs: nowMs,
    );

    await prefs.setInt(_kLastSeenKey, nowMs);

    _heartbeat?.cancel();
    // Keep the mark fresh WHILE running: without this, an app left open for a
    // month would look — on its next launch — as though it had been away for a
    // month, and warn about mail it actually received.
    _heartbeat = Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        final p = prefsForTest ?? await SharedPreferences.getInstance();
        await p.setInt(
          _kLastSeenKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      } catch (_) {
        // Best-effort bookkeeping; never worth surfacing.
      }
    });
  }

  /// The rule, separated from storage and the clock so it can be tested.
  ///
  /// Returns whole days away when the gap is at least [mailboxTtlDays], and
  /// null otherwise — including for a first run, where there is no previous
  /// mark and therefore no absence to report.
  @visibleForTesting
  static int? absenceDaysToWarnAbout({
    required int lastSeenMs,
    required int nowMs,
  }) {
    // No mark yet: a fresh install or a fresh pairing. Its history came from
    // the pairing bundle, so it has not "missed" anything.
    if (lastSeenMs <= 0) return null;
    // A clock that went backwards (timezone edit, NTP correction) must not be
    // read as a negative absence — nor as a huge one on the way back.
    final gapMs = nowMs - lastSeenMs;
    if (gapMs <= 0) return null;
    final days = gapMs ~/ Duration.millisecondsPerDay;
    if (days < mailboxTtlDays) return null;
    return days;
  }

  /// Dismisses the notice for this absence. It will not reappear until the
  /// desktop is away that long again.
  static void dismiss() => awayDays.value = null;

  static void stop() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  @visibleForTesting
  static void resetForTest() {
    stop();
    awayDays.value = null;
  }
}
