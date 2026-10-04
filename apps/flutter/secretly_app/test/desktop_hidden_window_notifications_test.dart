// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/ui/desktop/services/desktop_notification_service.dart';

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

    test('окно на экране — событие идёт службе, как раньше', () {
      expect(_decide(foreground: true, desktop: true).inAppBanner, isTrue);
      // 01.10.2026: и об открытой переписке тоже — служба сама знает, какая
      // открыта (у ПК она до контроллера не доходит), и вместо уведомления
      // играет «звук в открытом чате».
      expect(
        _decide(foreground: true, activeConvo: true, desktop: true).inAppBanner,
        isTrue,
      );
    });

    // 01.10.2026: звук сообщения на ПК играет служба компьютера — выбранный
    // человеком и вместе со своим уведомлением. Звук контроллера давал второй
    // звук на то же сообщение.
    test('🔴 окно на экране: контроллер не звучит поверх уведомления', () {
      expect(_decide(foreground: true, desktop: true).inAppCue, isFalse);
    });

    test('открытая переписка: контроллер молчит и тут', () {
      final d = _decide(foreground: true, activeConvo: true, desktop: true);
      expect(d.inAppCue, isFalse);
      expect(d.systemNotification, isFalse);
    });

    test('🔴 открытая переписка в окне в фокусе — звук открытого чата, а не '
        'уведомление', () {
      expect(desktopIsOpenConvo(openConvoId: 'alice', convoId: 'alice'), isTrue);
      expect(desktopIsOpenConvo(openConvoId: ' alice ', convoId: 'alice'), isTrue);
      expect(desktopIsOpenConvo(openConvoId: 'alice', convoId: 'bob'), isFalse);
      expect(desktopIsOpenConvo(openConvoId: '', convoId: ''), isFalse);
      final src = File(
        'lib/ui/desktop/services/desktop_notification_service.dart',
      ).readAsStringSync();
      final i = src.indexOf('Future<void> _onChatEvent(');
      final block = src.substring(i, src.indexOf('final isRoom', i));
      expect(block.contains('desktopIsOpenConvo('), isTrue);
      expect(block.contains('await _playOpenChatSound(evt.convoId);'), isTrue);
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

    test('окно на экране: звук контроллера, как раньше; открытый чат — тишина',
        () {
      final d = _decide(foreground: true);
      expect(d.inAppCue, isTrue);
      expect(d.inAppBanner, isTrue);
      final open = _decide(foreground: true, activeConvo: true);
      expect(open.inAppCue, isFalse);
      expect(open.inAppBanner, isFalse);
      expect(open.systemNotification, isFalse);
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
      // 28.09.2026: меню трея — служба `DesktopTrayService`. До запуска
      // дерева она прячет окно через `hideHandler`, после — приложение
      // подставляет ей тот же `_hideToTray`.
      final tray = File('lib/main_desktop.dart').readAsStringSync();
      final hideAction = tray.substring(
        tray.indexOf('hide: () async {'),
        tray.indexOf('quit: quitDesktopApp,'),
      );
      expect(hideAction.contains('DesktopWindowActivity.hideHandler'), isTrue);
      expect(app.contains('hide: _hideToTray,'), isTrue);
    });
  });
}
