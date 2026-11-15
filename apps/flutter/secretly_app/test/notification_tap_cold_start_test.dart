// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 НАЖАТИЕ НА УВЕДОМЛЕНИЕ ПРИ ЗАКРЫТОМ ПРИЛОЖЕНИИ (13.11.2026, Т10, iPhone).
//
// Отметки с iPhone (сборка 661): нажатие дошло до Flutter раньше экрана и
// было отложено, но уже отмечено как «последнее открытое». Через 0,37 с экран
// забрал отложенный чат — и защита от двойного нажатия (1,5 с) выбросила его
// как повтор. Открывался главный экран вместо чата.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('отложенное до готовности экрана нажатие открывает чат', () async {
    final controller = AppController();
    controller.debugEmitNotificationTap('chat-1'); // экран ещё не готов
    final opened = <String>[];
    controller.setOnNotificationTap(opened.add); // экран готов через миг
    await Future<void>.delayed(Duration.zero);
    expect(opened, ['chat-1']);
  });

  test('одно нажатие, пришедшее двумя путями, открывает чат один раз', () async {
    final controller = AppController();
    final opened = <String>[];
    controller.setOnNotificationTap(opened.add);
    controller.debugEmitNotificationTap('chat-1');
    controller.debugEmitNotificationTap('chat-1');
    expect(opened, ['chat-1']);
  });

  test('отложенное нажатие и его повтор после готовности — один раз', () async {
    final controller = AppController();
    controller.debugEmitNotificationTap('chat-1');
    final opened = <String>[];
    controller.setOnNotificationTap(opened.add);
    controller.debugEmitNotificationTap('chat-1');
    await Future<void>.delayed(Duration.zero);
    expect(opened, ['chat-1']);
  });
}
