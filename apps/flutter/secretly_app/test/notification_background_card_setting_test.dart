// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy in-app popup preference does not disable background notification cards',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settings_notif_in_app_popup_v1': false,
      });

      final prefs = await SharedPreferences.getInstance();

      expect(
        AppController.readBackgroundNotificationCardEnabledForTesting(prefs),
        isTrue,
      );
    },
  );

  test(
    'explicit background notification card preference is respected',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settings_notif_background_card_v1': false,
        'settings_notif_in_app_popup_v1': true,
      });

      final prefs = await SharedPreferences.getInstance();

      expect(
        AppController.readBackgroundNotificationCardEnabledForTesting(prefs),
        isFalse,
      );
    },
  );

  test('foreground notifications show in-app only outside active chat', () {
    final delivery = AppController.decideIncomingNotificationChannelsForTesting(
      appInForeground: true,
      isActiveConvo: false,
      foregroundNotificationUxEnabled: true,
      playSound: true,
      vibrate: false,
      suppressSystemNotificationForRecentPushWake: false,
      backgroundNotificationCardEnabled: true,
    );

    expect(delivery.inAppBanner, isTrue);
    expect(delivery.inAppCue, isTrue);
    expect(delivery.systemNotification, isFalse);
  });

  test('foreground active chat suppresses all notification channels', () {
    final delivery = AppController.decideIncomingNotificationChannelsForTesting(
      appInForeground: true,
      isActiveConvo: true,
      foregroundNotificationUxEnabled: true,
      playSound: true,
      vibrate: true,
      suppressSystemNotificationForRecentPushWake: false,
      backgroundNotificationCardEnabled: true,
    );

    expect(delivery.inAppBanner, isFalse);
    expect(delivery.inAppCue, isFalse);
    expect(delivery.systemNotification, isFalse);
  });

  test(
    'background recent push wake suppresses duplicate system notification',
    () {
      final delivery =
          AppController.decideIncomingNotificationChannelsForTesting(
            appInForeground: false,
            isActiveConvo: false,
            foregroundNotificationUxEnabled: true,
            playSound: true,
            vibrate: true,
            suppressSystemNotificationForRecentPushWake: true,
            backgroundNotificationCardEnabled: true,
          );

      expect(delivery.inAppBanner, isFalse);
      expect(delivery.inAppCue, isFalse);
      expect(delivery.systemNotification, isFalse);
    },
  );

  test('background notification card controls system notification', () {
    final shown = AppController.decideIncomingNotificationChannelsForTesting(
      appInForeground: false,
      isActiveConvo: false,
      foregroundNotificationUxEnabled: true,
      playSound: false,
      vibrate: false,
      suppressSystemNotificationForRecentPushWake: false,
      backgroundNotificationCardEnabled: true,
    );
    final hidden = AppController.decideIncomingNotificationChannelsForTesting(
      appInForeground: false,
      isActiveConvo: false,
      foregroundNotificationUxEnabled: true,
      playSound: false,
      vibrate: false,
      suppressSystemNotificationForRecentPushWake: false,
      backgroundNotificationCardEnabled: false,
    );

    expect(shown.systemNotification, isTrue);
    expect(hidden.systemNotification, isFalse);
  });
}
