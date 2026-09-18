// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/app/desktop_chats_section.dart';

// 🔴 НОВОЕ В ОТКРЫТОЙ ПЕРЕПИСКЕ ОСТАВАЛОСЬ НЕПРОЧИТАННЫМ (17.09.2026).
//
// Компьютер отмечал переписку прочитанной только при открытии. Сообщение,
// пришедшее, пока человек смотрит в чат, висело непрочитанным, а собеседник не
// получал «прочитано». Теперь — как на телефоне: окно в фокусе и лента внизу.

void main() {
  test('окно в фокусе и лента внизу — прочитано', () {
    expect(
      desktopShouldMarkOpenChatRead(windowFocused: true, nearLatest: true),
      isTrue,
    );
  });

  test('окно без фокуса — ещё не прочитано', () {
    expect(
      desktopShouldMarkOpenChatRead(windowFocused: false, nearLatest: true),
      isFalse,
    );
  });

  test('лента отлистана вверх — новое внизу не видно', () {
    expect(
      desktopShouldMarkOpenChatRead(windowFocused: true, nearLatest: false),
      isFalse,
    );
  });

  group('подключение', () {
    final host = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    final panel = File(
      'lib/ui/desktop/chat/chat_thread_panel.dart',
    ).readAsStringSync();

    test('🔴 новые данные, фокус и возврат вниз ставят отметку', () {
      final tick = host.substring(
        host.indexOf('  void _onTick() {'),
        host.indexOf('}', host.indexOf('  void _onTick() {')),
      );
      expect(tick.contains('_scheduleMarkRead();'), isTrue);
      expect(
        host.contains(
          'DesktopWindowActivity.focused.addListener(_onHostWindowFocusChanged);',
        ),
        isTrue,
      );
      expect(
        host.contains(
          'DesktopWindowActivity.focused.removeListener(_onHostWindowFocusChanged);',
        ),
        isTrue,
      );
      expect(host.contains('onNearLatestChanged: _onNearLatestChanged,'), isTrue);
    });

    test('лента сообщает, что её отлистали', () {
      expect(panel.contains('widget.onNearLatestChanged?.call(!up);'), isTrue);
    });

    test('отметка проходит через правило, а не напрямую', () {
      final schedule = host.substring(
        host.indexOf('  void _scheduleMarkRead() {'),
        host.indexOf('  void _onHostWindowFocusChanged() {'),
      );
      expect(schedule.contains('desktopShouldMarkOpenChatRead('), isTrue);
      expect(schedule.contains('Duration(milliseconds: 450)'), isTrue);
    });
  });
}
