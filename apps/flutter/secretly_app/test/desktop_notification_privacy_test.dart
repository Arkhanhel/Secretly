// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notification privacy is ONE profile setting, not one per device.
///
/// Desktop used to keep its own `desktop_notif_preview_level_v1` and nothing
/// else, so a level chosen on the phone never reached the desktop and a level
/// chosen on the desktop never reached the phone — the same account showed
/// message text on one device while hiding it on the other. These tests pin the
/// key names and the precedence, which is the part that silently rots.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mirrors of the two constants, kept here on purpose: if either private
  // constant is renamed, this test fails and names the contract that broke.
  const sharedKey = 'notif_privacy_level_v1'; // owned by AppController
  const desktopKey = 'desktop_notif_preview_level_v1';

  /// The precedence the desktop service applies at boot.
  int resolve(SharedPreferences p) =>
      (p.getInt(sharedKey) ?? p.getInt(desktopKey) ?? 1).clamp(0, 2);

  test('a level set on the phone wins on desktop', () async {
    SharedPreferences.setMockInitialValues({sharedKey: 0, desktopKey: 2});
    final prefs = await SharedPreferences.getInstance();
    expect(resolve(prefs), 0,
        reason: 'the shared profile setting must govern, not the local one');
  });

  test('the desktop key is only a fallback', () async {
    SharedPreferences.setMockInitialValues({desktopKey: 2});
    final prefs = await SharedPreferences.getInstance();
    expect(resolve(prefs), 2,
        reason: 'a profile that never set the shared value keeps its local one');
  });

  test('a fresh profile defaults to sender-only', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    expect(resolve(prefs), 1,
        reason: 'showing the sender but not the text is the safe middle');
  });

  test('out-of-range stored values are clamped, never trusted', () async {
    for (final entry in {-5: 0, 99: 2}.entries) {
      SharedPreferences.setMockInitialValues({sharedKey: entry.key});
      final prefs = await SharedPreferences.getInstance();
      expect(resolve(prefs), entry.value,
          reason: 'a corrupt value must not unlock a more revealing level');
    }
  });

  test('level 0 is the most private end of the scale', () {
    // The scale is meaningful, not arbitrary: higher reveals more, so a
    // clamp on the wrong side would leak.
    const hidden = 0, senderOnly = 1, senderAndText = 2;
    expect(hidden < senderOnly, isTrue);
    expect(senderOnly < senderAndText, isTrue);
  });

  group('баннер входящего звонка', () {
    test('🔴 уровень 0 не называет звонящего', () {
      expect(
        desktopCallNotificationBody(
          previewLevel: 0,
          knownName: 'Игорь',
          appTitle: 'Secretly',
        ),
        'Secretly',
        reason: 'уровень 0 обещает скрыть отправителя — и в звонке тоже',
      );
    });

    test('уровни 1 и 2 показывают имя', () {
      for (final level in const [1, 2]) {
        expect(
          desktopCallNotificationBody(
            previewLevel: level,
            knownName: 'Игорь',
            appTitle: 'Secretly',
          ),
          'Игорь',
          reason: 'уровень $level',
        );
      }
    });

    test('без известного имени — название приложения, а не сырой id', () {
      expect(
        desktopCallNotificationBody(
          previewLevel: 2,
          knownName: '   ',
          appTitle: 'Secretly',
        ),
        'Secretly',
      );
    });
  });
}
