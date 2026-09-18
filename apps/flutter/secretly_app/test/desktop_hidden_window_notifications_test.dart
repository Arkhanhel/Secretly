// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

// 🔴 СКРЫТОЕ ОКНО КОМПЬЮТЕРА МОЛЧАЛО О СООБЩЕНИЯХ (17.09.2026).
//
// После честного присутствия (`54dc73b2`) скрытое или свёрнутое окно — это
// «приложение в фоне». Для фона контроллер выбирал системное уведомление, а
// на компьютере этого пути нет (на macOS он выключен), служба же компьютера
// слушает только поток баннеров. Итог: пока окно скрыто, ни одного
// уведомления. Здесь сторожится, что компьютер получает событие, а телефон
// ведёт себя как раньше.

({bool inAppCue, bool inAppBanner, bool systemNotification}) _decide({
  required bool foreground,
  bool activeConvo = false,
  bool cardEnabled = true,
  bool pushWake = false,
  bool desktop = false,
}) => AppController.decideIncomingNotificationChannelsForTesting(
  appInForeground: foreground,
  isActiveConvo: activeConvo,
  foregroundNotificationUxEnabled: true,
  playSound: true,
  vibrate: false,
  suppressSystemNotificationForRecentPushWake: pushWake,
  backgroundNotificationCardEnabled: cardEnabled,
  desktopHostedNotifications: desktop,
);

void main() {
  group('компьютер, окно скрыто', () {
    test('🔴 сообщение уходит в поток службы компьютера', () {
      final d = _decide(foreground: false, desktop: true);
      expect(d.inAppBanner, isTrue);
      expect(d.systemNotification, isFalse);
      expect(d.inAppCue, isFalse, reason: 'звук играет системное уведомление');
    });

    test('открытая переписка не исключение: окна не видно', () {
      final d = _decide(foreground: false, activeConvo: true, desktop: true);
      expect(d.inAppBanner, isTrue);
    });

    test('выключенные карточки в фоне уважаются', () {
      final d = _decide(foreground: false, cardEnabled: false, desktop: true);
      expect(d.inAppBanner, isFalse);
      expect(d.systemNotification, isFalse);
    });

    test('окно на экране — как раньше', () {
      expect(_decide(foreground: true, desktop: true).inAppBanner, isTrue);
      expect(
        _decide(foreground: true, activeConvo: true, desktop: true).inAppBanner,
        isFalse,
      );
    });
  });

  group('телефон — без изменений', () {
    test('в фоне — системное уведомление, баннера нет', () {
      final d = _decide(foreground: false);
      expect(d.systemNotification, isTrue);
      expect(d.inAppBanner, isFalse);
    });

    test('недавний пуш гасит системное уведомление, как и раньше', () {
      final d = _decide(foreground: false, pushWake: true);
      expect(d.systemNotification, isFalse);
      expect(d.inAppBanner, isFalse);
    });

    test('телефонная точка входа флаг не ставит', () {
      final src = File('lib/main.dart').readAsStringSync();
      expect(src.contains('setDesktopHostedNotifications'), isFalse);
    });
  });

  group('подключение', () {
    test('🔴 контроллер передаёт флаг в решение', () {
      final src = File('lib/app/app_controller.dart').readAsStringSync();
      expect(
        src.contains(
          'desktopHostedNotifications: _desktopHostedNotifications,',
        ),
        isTrue,
      );
    });

    test('🔴 приложение компьютера ставит флаг до запуска службы', () {
      final src = File(
        'lib/ui/desktop/app/desktop_production_app.dart',
      ).readAsStringSync();
      final setAt = src.indexOf('_controller.setDesktopHostedNotifications(true);');
      final svcAt = src.indexOf(
        'final svc = DesktopNotificationService(controller: _controller);',
      );
      expect(setAt, greaterThan(0));
      expect(setAt, lessThan(svcAt));
    });

    test('трей прячет окно тем же путём, что и кнопка закрытия', () {
      final app = File(
        'lib/ui/desktop/app/desktop_production_app.dart',
      ).readAsStringSync();
      expect(app.contains('DesktopWindowActivity.hideHandler = _hideToTray;'),
          isTrue);
      expect(app.contains('await _hideToTray();'), isTrue);
      final tray = File('lib/main_desktop.dart').readAsStringSync();
      final hideCase = tray.substring(
        tray.indexOf("case 'hide':"),
        tray.indexOf("case 'quit':"),
      );
      expect(hideCase.contains('DesktopWindowActivity.hideHandler'), isTrue);
    });
  });
}
