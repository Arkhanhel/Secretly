// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// The rule behind the "this computer was offline for N days" notice.
//
// Two server windows make a silent desktop lose mail (server/keys/src/store.rs):
// the relay mailbox TTL of 7 days, after which mail expires unread, and the
// 14-day device-liveness window, after which senders stop encrypting to it at
// all. The desktop TZ raised this as DLV-3 and left it open — nothing on
// screen ever said the device had fallen behind.
//
// The rule is separated from storage and from the clock precisely so these
// cases can be pinned: they are the ones where a warning would be wrong.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_absence.dart';

const int _dayMs = Duration.millisecondsPerDay;

int? warn({required int lastSeenMs, required int nowMs}) =>
    DesktopAbsence.absenceDaysToWarnAbout(
      lastSeenMs: lastSeenMs,
      nowMs: nowMs,
    );

void main() {
  const now = 1800000000000;

  test('a first run says nothing', () {
    // No previous mark means a fresh install or a fresh pairing. Its history
    // arrived in the pairing bundle, so it missed nothing — telling it that it
    // was "away" would be a lie on the very first launch.
    expect(warn(lastSeenMs: 0, nowMs: now), isNull);
  });

  test('a short absence says nothing', () {
    for (final days in <int>[0, 1, 3, 6]) {
      expect(
        warn(lastSeenMs: now - days * _dayMs, nowMs: now),
        isNull,
        reason: '$days days is inside the mailbox TTL',
      );
    }
  });

  test('the warning starts exactly at the mailbox TTL', () {
    // Seven days is where mail has provably begun expiring — the first real
    // loss, and therefore the first honest moment to say so. Warning at the
    // 14-day fanout window instead would be warning after the fact.
    expect(DesktopAbsence.mailboxTtlDays, 7);
    expect(warn(lastSeenMs: now - 7 * _dayMs, nowMs: now), 7);
    expect(warn(lastSeenMs: now - 13 * _dayMs, nowMs: now), 13);
  });

  test('a long absence reports the real number of days', () {
    expect(DesktopAbsence.fanoutWindowDays, 14);
    expect(warn(lastSeenMs: now - 14 * _dayMs, nowMs: now), 14);
    expect(warn(lastSeenMs: now - 90 * _dayMs, nowMs: now), 90);
  });

  test('a clock that went backwards is not an absence', () {
    // Timezone edits and NTP corrections move the clock both ways. A negative
    // gap must not be reported at all — and must not become a huge positive
    // one when the clock comes back.
    expect(warn(lastSeenMs: now + 5 * _dayMs, nowMs: now), isNull);
    expect(warn(lastSeenMs: now, nowMs: now), isNull);
  });

  test('partial days do not round up into a warning', () {
    // 6 days 23 hours is still less than the TTL; reporting "7 days" there
    // would warn before anything was lost.
    expect(
      warn(lastSeenMs: now - (7 * _dayMs - 1), nowMs: now),
      isNull,
    );
  });

  test('dismissing clears the notice', () {
    DesktopAbsence.resetForTest();
    DesktopAbsence.awayDays.value = 9;
    DesktopAbsence.dismiss();
    expect(DesktopAbsence.awayDays.value, isNull);
  });
}
