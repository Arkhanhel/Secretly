// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Mac: закрытое окно — не выход из приложения.
//
// 🔴 ЗАЧЕМ (30.09.2026). Крестик и ⌘W прячут окно в строку меню
// (`windowManager.hide()` = `orderOut`). Шаблонный AppDelegate Flutter
// отвечал `true` на «завершаться после закрытия последнего окна», и AppKit,
// считающий спрятанное последнее окно закрытым, гасил процесс через ~30 мс.
// Снаружи это выглядело как «приложение в строке меню», а на деле не
// приходило ничего: ни сообщений, ни уведомлений, ни звонков. Проверка
// исходника — единственная возможная здесь: виджет-тест не поднимает AppKit.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final swift = File('macos/Runner/AppDelegate.swift').readAsStringSync();

  String bodyOf(String signature) {
    final start = swift.indexOf(signature);
    expect(start, greaterThanOrEqualTo(0), reason: 'нет $signature');
    final open = swift.indexOf('{', start);
    var depth = 0;
    for (var i = open; i < swift.length; i++) {
      if (swift[i] == '{') depth++;
      if (swift[i] == '}') {
        depth--;
        if (depth == 0) return swift.substring(open, i + 1);
      }
    }
    fail('не закрыта скобка у $signature');
  }

  test('спрятанное окно не завершает приложение', () {
    final body = bodyOf('applicationShouldTerminateAfterLastWindowClosed');
    expect(body.contains('return false'), isTrue);
    expect(body.contains('return true'), isFalse);
  });

  test('щелчок по значку в Dock возвращает спрятанное окно', () {
    final body = bodyOf('applicationShouldHandleReopen');
    expect(body.contains('mainFlutterWindow'), isTrue);
    expect(body.contains('makeKeyAndOrderFront'), isTrue);
    // Свёрнутое в Dock окно оставляем AppKit: он разворачивает его сам.
    expect(body.contains('isMiniaturized'), isTrue);
  });

  test('выход по-прежнему явный — через quitDesktopApp', () {
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    // Крестик при выключенном «Закрывать в трей» и системная просьба закрыть
    // уже спрятанное окно — выход; всё остальное прячет окно.
    expect(app.contains('await quitDesktopApp();'), isTrue);
    expect(app.contains('await _hideToTray();'), isTrue);
  });
}
