// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// УВЕДОМЛЕНИЯ НА КОМПЬЮТЕРЕ: КНОПКИ В БАННЕРЕ И ЗНАЧОК В DOCK.
//
// 🔴 ЧЕГО НЕ ХВАТАЛО. У телефона в уведомлении с самого начала есть «Ответить»
// и «Прочитано» (`DarwinNotificationCategory` в `app_controller.dart`), а на
// компьютере их не было. Окно при этом живёт в трее — и короткое «ок» требовало
// развернуть приложение, найти переписку и только потом написать.
//
// Непрочитанное тоже было видно ровно один раз: в баннере. Число считалось, но
// уходило лишь в подсказку значка в трее — её надо навести мышью и подождать, а
// у спрятанного окна нет и заголовка. Пропустил баннер — следов не осталось.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_dock_badge_service.dart';
import 'package:secretly_app/ui/desktop/services/desktop_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('кому можно отвечать прямо из баннера', () {
    test('🔴 при скрытом отправителе кнопок НЕТ', () {
      // Уровень 0 — баннер не говорит, кто написал. Поле ответа на нём дало бы
      // любому, кто проходит мимо, отправить сообщение в неназванную переписку.
      expect(
        notificationActionsAllowed(previewLevel: 0, convoId: 'P-1'),
        isFalse,
      );
    });

    test('когда отправитель назван — кнопки есть', () {
      expect(
        notificationActionsAllowed(previewLevel: 1, convoId: 'P-1'),
        isTrue,
      );
      expect(
        notificationActionsAllowed(previewLevel: 2, convoId: 'group:R-1'),
        isTrue,
      );
    });

    test('🔴 «запросу» отвечать нечем — кнопок нет', () {
      expect(
        notificationActionsAllowed(previewLevel: 2, convoId: 'req:P-9'),
        isFalse,
      );
    });

    test('пустая переписка — кнопок нет', () {
      expect(notificationActionsAllowed(previewLevel: 2, convoId: '  '), isFalse);
    });
  });

  group('значок непрочитанного в Dock', () {
    late List<MethodCall> calls;
    late DesktopDockBadgeService badge;

    setUp(() {
      calls = <MethodCall>[];
      const channel = MethodChannel('secretly/dock_badge');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      badge = DesktopDockBadgeService(channel: channel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('secretly/dock_badge'),
            null,
          );
    });

    test('число уходит в систему, повтор — нет', () async {
      await badge.set(3);
      await badge.set(3);
      await badge.set(5);
      // Площадку дёргаем только на изменение: значок перерисовывается системой,
      // и дёргать его на каждом пересчёте списка чатов незачем.
      expect(calls.map((c) => c.arguments['count']).toList(), [3, 5]);
    });

    test('🔴 отрицательное не уходит как отрицательное', () async {
      await badge.set(-4);
      expect(calls.single.arguments['count'], 0);
    });

    test('снятие значка', () async {
      await badge.set(7);
      await badge.clear();
      expect(calls.last.arguments['count'], 0);
    });
  });
}
