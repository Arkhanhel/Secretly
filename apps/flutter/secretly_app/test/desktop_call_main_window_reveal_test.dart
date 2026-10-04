// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 Невидимый созвон с живым микрофоном (30.09.2026).
//
// Окно созвона закрыли крестиком или свернули, а главное окно спрятано в
// трей: созвон шёл дальше, а мини-окно и полоса «Вернуться» жили в скрытом
// главном окне — на экране не оставалось ничего. Теперь главное окно выходит
// вперёд тем же путём, что пункт трея «Открыть».

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/calls/call_main_window_reveal.dart';
import 'package:secretly_app/ui/desktop/calls/room_call_window_host.dart';
import 'package:secretly_app/ui/desktop/services/desktop_tray_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var hidden = false;
  var shown = 0;

  setUp(() {
    hidden = false;
    shown = 0;
    DesktopMainWindowReveal.isHidden = () async => hidden;
    DesktopMainWindowReveal.show = () async => shown++;
  });

  tearDown(DesktopMainWindowReveal.debugReset);

  test('главное окно спрятано — выводим', () async {
    hidden = true;
    await DesktopMainWindowReveal.revealIfHidden();
    expect(shown, 1);
  });

  test('главное окно на экране — не трогаем', () async {
    await DesktopMainWindowReveal.revealIfHidden();
    expect(shown, 0);
  });

  test('ОС не ответила — закрытие окна созвона не падает', () async {
    DesktopMainWindowReveal.isHidden = () async => throw StateError('no os');
    await DesktopMainWindowReveal.revealIfHidden();
    expect(shown, 0);
  });

  test('🔴 крестик окна созвона при окне в трее выводит главное', () async {
    hidden = true;
    await DesktopRoomCallWindows.minimize();
    expect(shown, 1);
    expect(DesktopRoomCallWindows.openRoomId, isNull);
  });

  test('трей: окно показывается путём пункта «Открыть»', () async {
    final tray = DesktopTrayService.forTest(TargetPlatform.macOS);
    var opened = 0;
    tray.bind(
      DesktopTrayActions(
        show: () async => opened++,
        hide: () async {},
        quit: () async {},
      ),
    );
    await tray.showMainWindow();
    expect(opened, 1);
    // Тот же путь, что у пункта меню.
    await tray.handleMenuKey(DesktopTrayMenuKeys.open);
    expect(opened, 2);
  });

  group('🔴 подключено', () {
    final host = File(
      'lib/ui/desktop/calls/room_call_window_host.dart',
    ).readAsStringSync();
    final window = File(
      'lib/ui/desktop/calls/room_call_window.dart',
    ).readAsStringSync();

    test('крестик и «Свернуть» своего окна выводят главное окно', () {
      final minimize = host.substring(
        host.indexOf('static Future<void> minimize() async {'),
      );
      expect(
        minimize.indexOf('await close();'),
        lessThan(minimize.indexOf('revealIfHidden()')),
      );
      expect(host.contains('leaveRelayRoomCall'), isFalse);
      final body = window.substring(window.indexOf('void _minimize() {'));
      final end = body.indexOf('\n  }\n');
      final own = body.substring(0, end);
      expect(own.contains('if (widget.ownWindow != null) {'), isTrue);
      expect(own.contains('DesktopMainWindowReveal.revealIfHidden()'), isTrue);
    });

    test('после выхода из созвона главное окно не выдёргиваем', () {
      final leave = window.substring(
        window.indexOf('Future<void> _leave() {'),
      );
      final end = leave.indexOf('\n  }\n');
      expect(leave.substring(0, end).contains('revealIfHidden'), isFalse);
    });
  });
}
