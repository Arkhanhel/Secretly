// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Чат из уведомления открывается на первом непрочитанном, как из списка
// (23.11.2026, владелец: «из уведомления показывает самый низ»).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat_screen.dart';

String _src(String p) => File(p).readAsStringSync();

void main() {
  test('ожидание догрузки включено и ограничено', () {
    expect(kNotificationUnreadWait, greaterThan(Duration.zero));
    expect(kNotificationUnreadWait, lessThanOrEqualTo(const Duration(seconds: 10)));
  });

  test('🔴 нажатие на уведомление открывает чат с признаком', () {
    final main = _src('lib/main.dart');
    expect(main.contains('_openConvoById(convoId, fromNotification: true)'), isTrue);
    expect(main.contains('openedFromNotification: fromNotification'), isTrue);
    // Повтор при неготовом навигаторе (холодный запуск) признак не теряет.
    expect(main.contains('fromNotification: fromNotification,'), isTrue);
    expect(_src('lib/ui/app_shell.dart').contains('openedFromNotification: true'), isTrue);
  });

  test('🔴 пустые непрочитанные из уведомления — ждём, а не встаём вниз', () {
    final s = _src('lib/ui/chat_screen.dart');
    final i = s.indexOf('Future<void> _resolveOpenPosition() async {');
    final body = s.substring(i, i + 1400);
    expect(
      body.contains('unread.isEmpty && widget.openedFromNotification'),
      isTrue,
    );
    expect(body.contains('_waitForNotifiedUnread(latest)'), isTrue);
    // Пока место выбирается, прочитанным ничего не помечается.
    expect(s.contains('if (_openPositionPending) return;'), isTrue);
  });
}
