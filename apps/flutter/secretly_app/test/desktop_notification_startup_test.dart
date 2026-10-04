// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// ЗАПУСК СЛУЖБЫ УВЕДОМЛЕНИЙ НА КОМПЬЮТЕРЕ (30.09.2026).
//
// 🔴 Два дефекта запуска:
// * macOS, первый запуск: `initialize` с запросом разрешения отвечает только
//   после ответа человека на системный вопрос, а запуск этого ждал — заставка
//   висела;
// * язык системы вне восьми переводов (итальянский, польский, японский…):
//   `lookupAppLocalizations` бросал, и уведомлений не было вовсе.

import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/ui/desktop/services/desktop_notification_service.dart';

void main() {
  // `AppController` в конструкторе поднимает проигрыватель и его канал.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('macOS: запуск не ждёт ответа на вопрос о разрешении', () {
    test('🔴 initialize не спрашивает разрешений', () {
      final settings = desktopMacNotificationInitSettings(
        const <DarwinNotificationCategory>[],
      );
      expect(settings.requestAlertPermission, isFalse);
      expect(settings.requestBadgePermission, isFalse);
      expect(settings.requestSoundPermission, isFalse);
    });

    test('разрешение спрашивается отдельно и без ожидания', () {
      final src = File(
        'lib/ui/desktop/services/desktop_notification_service.dart',
      ).readAsStringSync();
      expect(
        src.contains('desktopMacNotificationInitSettings(_macCategories())'),
        isTrue,
      );
      final request = src.indexOf('.requestPermissions(alert: true');
      expect(request, greaterThan(0));
      // Запрос — внутри `unawaited(`, а не под `await`.
      final wrapper = src.lastIndexOf('unawaited(', request);
      expect(src.substring(wrapper, request).contains('await '), isFalse);
    });
  });

  group('язык уведомлений', () {
    final resolve = AppController().resolveAppUiLocale;

    test('🔴 язык вне восьми — английский, а не исключение', () {
      for (final code in const ['it', 'pl', 'ja', 'zh', 'tr', 'nl']) {
        final l10n = desktopNotificationStrings(
          resolve: resolve,
          deviceLocales: <Locale>[Locale(code)],
        );
        expect(l10n.localeName, 'en', reason: code);
      }
    });

    test('знакомый язык системы — он и есть', () {
      final ru = desktopNotificationStrings(
        resolve: resolve,
        deviceLocales: const <Locale>[Locale('ru', 'RU')],
      );
      expect(ru.localeName, 'ru');
      final br = desktopNotificationStrings(
        resolve: resolve,
        deviceLocales: const <Locale>[Locale('pt', 'BR')],
      );
      expect(br.localeName, 'pt_BR');
    });

    test('второй язык системы выручает первый', () {
      final l10n = desktopNotificationStrings(
        resolve: resolve,
        deviceLocales: const <Locale>[Locale('it'), Locale('uk')],
      );
      expect(l10n.localeName, 'uk');
    });

    test('сбой выбора языка — всё равно английский', () {
      final l10n = desktopNotificationStrings(
        resolve: (_) => const Locale('xx'),
        deviceLocales: const <Locale>[Locale('it')],
      );
      expect(l10n.localeName, 'en');
    });

    test('служба больше не берёт язык системы в обход выбора', () {
      final src = File(
        'lib/ui/desktop/services/desktop_notification_service.dart',
      ).readAsStringSync();
      expect(
        src.contains(
          'lookupAppLocalizations(PlatformDispatcher.instance.locale)',
        ),
        isFalse,
      );
      expect(src.contains('resolve: controller.resolveAppUiLocale'), isTrue);
    });
  });
}
