// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/security/safe_backup_regression_guard.dart';

/// The server stores ONE backup per profile and every upload overwrites it. On
/// 2026-07-20 a device re-keyed itself and came up empty; with automatic backup
/// on, that empty state would have replaced the last good copy. These pin the
/// rule that stops it.
void main() {
  _barIntegrity();
  bool allows(int previous, int next) =>
      SafeBackupRegressionGuard.allowsOverwrite(
        previousEvents: previous,
        nextEvents: next,
      );

  group('refuses to overwrite a good backup with a broken device', () {
    test('an emptied database never overwrites history', () {
      expect(allows(4000, 0), isFalse);
      expect(allows(1, 0), isFalse);
    });

    test('losing most of the history is held back', () {
      expect(allows(4000, 100), isFalse);
      expect(allows(1000, 499), isFalse);
    });
  });

  group('never blocks a legitimate backup', () {
    test('first backup of a device is always allowed', () {
      expect(allows(0, 0), isTrue);
      expect(allows(0, 5000), isTrue);
    });

    test('growth and steady state are allowed', () {
      expect(allows(4000, 4000), isTrue);
      expect(allows(4000, 4001), isTrue);
    });

    test('ordinary attrition is allowed', () {
      // Disappearing messages and a cleared chat shrink the count gently.
      expect(allows(1000, 900), isTrue);
      expect(allows(1000, 500), isTrue); // exactly at the floor
    });
  });

  test('refusalReason explains the numbers, and is null when allowed', () {
    expect(
      SafeBackupRegressionGuard.refusalReason(
        previousEvents: 4000,
        nextEvents: 0,
      ),
      allOf(contains('4000'), contains('0')),
    );
    expect(
      SafeBackupRegressionGuard.refusalReason(
        previousEvents: 4000,
        nextEvents: 4000,
      ),
      isNull,
    );
  });
}

/// The guard is only as good as the number it compares against.
///
/// 🔴 2026-07-31: the bar was recorded with `AppDb.countEvents()`, which answers
/// 0 on a query failure — indistinguishable from a genuinely empty database. A
/// stored 0 makes `previousEvents <= 0` true, and the guard deliberately fails
/// OPEN there ("nothing worth protecting yet"). So one transient hiccup in the
/// bookkeeping silently DISARMED the protection, and the next damaged backup
/// would have gone straight over the user's last good copy.
///
/// The fix is `countEventsOrNull()` plus "leave the previous bar alone when the
/// count is unknown". These tests state why a zero bar is not a safe default.
void _barIntegrity() {
  group('a zero bar disarms the guard — so it must never be written blindly',
      () {
    test('REGRESSION: a zero bar allows an EMPTY device to overwrite', () {
      // This is the whole reason a failed count must not be stored.
      expect(
        SafeBackupRegressionGuard.allowsOverwrite(
          previousEvents: 0,
          nextEvents: 0,
        ),
        isTrue,
        reason: 'documented fail-open at zero — harmless as a first backup, '
            'catastrophic if it got there by a failed count',
      );
    });

    test('while the real bar would have refused the same write', () {
      // Same device, same emptiness, but the bar survived. The only difference
      // is whether the bookkeeping wrote a number it could not vouch for.
      expect(
        SafeBackupRegressionGuard.allowsOverwrite(
          previousEvents: 5000,
          nextEvents: 0,
        ),
        isFalse,
      );
    });

    test('keeping a STALE bar is never MORE permissive than the true one', () {
      // The property that makes "leave the old bar alone" the right response to
      // an unknown count: a bar that is too HIGH can only refuse more often
      // than the truth. It can never let through a write the truth would block.
      for (final trueBar in <int>[1, 100, 5000]) {
        for (final staleBar in <int>[trueBar, trueBar + 1, trueBar * 3]) {
          for (final next in <int>[0, 1, 50, 99, 100, 5000, 20000]) {
            final staleSays = SafeBackupRegressionGuard.allowsOverwrite(
              previousEvents: staleBar,
              nextEvents: next,
            );
            final truthSays = SafeBackupRegressionGuard.allowsOverwrite(
              previousEvents: trueBar,
              nextEvents: next,
            );
            if (staleSays) {
              expect(
                truthSays,
                isTrue,
                reason: 'stale=$staleBar allowed next=$next while the true bar '
                    '$trueBar would have refused it',
              );
            }
          }
        }
      }
    });

    test('a stale bar cannot wedge backups off forever', () {
      // The counterweight to the property above: growth still gets through, so
      // being conservative is a delay, never a dead end.
      expect(
        SafeBackupRegressionGuard.allowsOverwrite(
          previousEvents: 5000,
          nextEvents: 5001,
        ),
        isTrue,
      );
    });
  });
}
