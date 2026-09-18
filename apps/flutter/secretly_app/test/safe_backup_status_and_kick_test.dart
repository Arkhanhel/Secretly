// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secretly_app/app/app_controller.dart';

/// FIELD REPORT (2026-07-21): "включил авторезервную копию, указал пароль — и
/// тишина", plus "после ручного создания копии всё равно пишет «копия ещё не
/// создана»".
///
/// Two independent defects behind that:
///  1. the status header read ONLY the automatic-success stamp, so a backup the
///     user made by hand left the header claiming nothing existed;
///  2. enabling auto-backup stamped nothing and forced nothing, so the first
///     run waited out the whole 24 h interval — and the "password is not set"
///     branch had already stamped the attempt clock, so supplying the password
///     did not release it either.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('status counts every kind of backup', () {
    test('a manual DEVICE save alone means the user is protected', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'safe_backup_auto_enabled_v1': true,
        // no auto success ever — only a hand-made device copy
        'safe_backup_last_device_saved_at_ms_v1':
            DateTime.now().millisecondsSinceEpoch,
      });
      final c = AppController();
      await c.loadSafeBackupPrefsForTesting();

      expect(c.safeBackupLastAnySuccessAtMs, greaterThan(0));
      expect(
        c.safeBackupHealth,
        isNot(SafeBackupHealth.pending),
        reason: 'a real backup exists — the header must not say "not created"',
      );
    });

    test('a manual SERVER upload alone also counts', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'safe_backup_auto_enabled_v1': true,
        'safe_backup_last_server_saved_at_ms_v1':
            DateTime.now().millisecondsSinceEpoch,
      });
      final c = AppController();
      await c.loadSafeBackupPrefsForTesting();

      expect(c.safeBackupLastAnySuccessAtMs, greaterThan(0));
      expect(c.safeBackupHealth, isNot(SafeBackupHealth.pending));
    });

    test('no backup of any kind is still honestly reported as pending',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'safe_backup_auto_enabled_v1': true,
      });
      final c = AppController();
      await c.loadSafeBackupPrefsForTesting();

      expect(c.safeBackupLastAnySuccessAtMs, 0);
      expect(c.safeBackupHealth, SafeBackupHealth.pending);
    });

    test('auto disabled reads as off regardless of past backups', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'safe_backup_auto_enabled_v1': false,
        'safe_backup_last_device_saved_at_ms_v1':
            DateTime.now().millisecondsSinceEpoch,
      });
      final c = AppController();
      await c.loadSafeBackupPrefsForTesting();

      expect(c.safeBackupHealth, SafeBackupHealth.off);
    });
  });

  group('enabling auto-backup does not stay silent', () {
    test('enabling clears the attempt clock that would delay the first run',
        () async {
      // The state the user was actually stuck in: auto on, a stale attempt
      // stamped minutes ago by the "password is not set" bail-out, and the
      // error it wrote. With a 24 h interval that stamp alone means silence.
      final staleAttempt =
          DateTime.now().millisecondsSinceEpoch - 60 * 1000;
      SharedPreferences.setMockInitialValues(<String, Object>{
        'safe_backup_auto_enabled_v1': false,
        'safe_backup_last_auto_attempt_at_ms_v1': staleAttempt,
        'safe_backup_last_auto_error_v1': 'Auto-backup password is not set',
      });
      final c = AppController();
      await c.loadSafeBackupPrefsForTesting();

      await c.setSafeBackupAutoEnabled(true);
      final prefs = await SharedPreferences.getInstance();

      expect(
        prefs.getInt('safe_backup_last_auto_attempt_at_ms_v1'),
        isNull,
        reason: 'the stale attempt clock must not hold the first run hostage',
      );
      expect(
        prefs.getString('safe_backup_last_auto_error_v1'),
        isNull,
        reason: 'the "password is not set" error is stale once re-enabled',
      );
    });

    test('disabling still clears the error and leaves auto off', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'safe_backup_auto_enabled_v1': true,
        'safe_backup_last_auto_error_v1': 'boom',
      });
      final c = AppController();
      await c.loadSafeBackupPrefsForTesting();

      await c.setSafeBackupAutoEnabled(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('safe_backup_auto_enabled_v1'), isFalse);
      expect(prefs.getString('safe_backup_last_auto_error_v1'), isNull);
      expect(c.safeBackupHealth, SafeBackupHealth.off);
    });
  });
}
