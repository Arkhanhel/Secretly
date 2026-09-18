// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';

/// The «Enter отправляет сообщение» setting used to be a dead switch: it wrote
/// to a local bool that nothing read and that reset on restart, while the
/// composer always sent on plain Enter regardless. These tests pin both halves
/// of making it real — the rule, and the fact that it survives a restart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
  });

  group('send chord', () {
    test('Enter sends and Shift+Enter breaks the line when enabled', () {
      expect(shouldSendOnEnter(enterToSend: true, shiftPressed: false), isTrue);
      expect(shouldSendOnEnter(enterToSend: true, shiftPressed: true), isFalse);
    });

    test('the roles swap when disabled', () {
      expect(shouldSendOnEnter(enterToSend: false, shiftPressed: false), isFalse);
      expect(shouldSendOnEnter(enterToSend: false, shiftPressed: true), isTrue);
    });

    test('exactly one of the two chords ever sends', () {
      for (final enabled in [true, false]) {
        final sends = [
          shouldSendOnEnter(enterToSend: enabled, shiftPressed: false),
          shouldSendOnEnter(enterToSend: enabled, shiftPressed: true),
        ].where((x) => x).length;
        expect(sends, 1,
            reason: 'with enterToSend=$enabled there must be exactly one '
                'sending chord — otherwise Enter either always sends or never '
                'does');
      }
    });
  });

  group('persistence', () {
    test('defaults to Enter-sends', () async {
      await DesktopUiPrefs.load();
      expect(DesktopUiPrefs.enterToSend.value, isTrue);
    });

    test('a change survives a restart', () async {
      await DesktopUiPrefs.load();
      await DesktopUiPrefs.setEnterToSend(false);
      expect(DesktopUiPrefs.enterToSend.value, isFalse);

      // Simulate relaunch: fresh in-memory state, same stored preferences.
      DesktopUiPrefs.resetForTest();
      expect(DesktopUiPrefs.enterToSend.value, isTrue, reason: 'reset to default');
      await DesktopUiPrefs.load();
      expect(DesktopUiPrefs.enterToSend.value, isFalse,
          reason: 'the stored choice must win over the default');
    });

    test('notifies listeners so an open chat picks the change up', () async {
      await DesktopUiPrefs.load();
      var notified = 0;
      void listener() => notified++;
      DesktopUiPrefs.enterToSend.addListener(listener);
      addTearDown(() => DesktopUiPrefs.enterToSend.removeListener(listener));

      await DesktopUiPrefs.setEnterToSend(false);

      expect(notified, greaterThan(0),
          reason: 'the composer reads this notifier — without a notification '
              'the setting would not reach an already-open chat');
    });
  });
}
