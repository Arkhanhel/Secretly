// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 АВТОЗАПУСК «СВЁРНУТЫМ»: КОНТРОЛЛЕР НЕ УЗНАВАЛ, ЧТО ОКНА НЕТ (30.09.2026).
//
// Окно прячется в `initState` — раньше, чем подписан слушатель видимости, и
// задолго до готовности приложения, а сам слушатель молчит, пока `_ready`
// ложно. После готовности о скрытом окне не сообщал никто: присутствие «в
// сети» всю ночь, замки «в фоне» не взводились. Корень целиком в тесте не
// поднять (окно ОС, контроллер), поэтому сторожится порядок в `_boot`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final app = File(
    'lib/ui/desktop/app/desktop_production_app.dart',
  ).readAsStringSync();

  test('после готовности скрытое окно сообщается контроллеру', () {
    final boot = app.substring(
      app.indexOf('  Future<void> _boot() async {'),
      app.indexOf('  void _wireDeepLinks() {'),
    );
    final ready = boot.indexOf('_ready = true;');
    final report = boot.indexOf(
      'if (!_windowActivity.visible.value) _onWindowVisibilityChanged();',
    );
    expect(ready, greaterThan(0));
    expect(report, greaterThan(ready), reason: 'только после готовности');
  });

  test('сам обработчик по-прежнему молчит до готовности', () {
    final handler = app.substring(
      app.indexOf('  void _onWindowVisibilityChanged() {'),
      app.indexOf('  @override\n  void onWindowFocus()'),
    );
    expect(handler.contains('if (!_ready) return;'), isTrue);
    expect(handler.contains('_controller.setAppInForeground(visible)'), isTrue);
  });
}
