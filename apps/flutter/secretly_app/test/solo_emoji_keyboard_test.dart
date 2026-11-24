// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Владелец, 24.11.2026: «после того как я отправляю соло эмодзи в чат, у меня
// обратно открывается клавиатура, скрывая эмодзи». Причина — после отправки
// поле ввода всегда забирало фокус, панель эмодзи уступала место клавиатуре.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat_screen.dart';

void main() {
  test('из панели эмодзи — панель остаётся, клавиатура не поднимается', () {
    expect(
      composerKeepsKeyboardDownAfterSend(
        soloEmoji: true, keyboardWasUp: false, emojiPanelOpen: true),
      isTrue,
    );
    expect(
      composerKeepsKeyboardDownAfterSend(
        soloEmoji: false, keyboardWasUp: false, emojiPanelOpen: true),
      isTrue,
    );
  });

  test('соло-эмодзи при опущенной клавиатуре — клавиатура не поднимается', () {
    expect(
      composerKeepsKeyboardDownAfterSend(
        soloEmoji: true, keyboardWasUp: false, emojiPanelOpen: false),
      isTrue,
    );
  });

  test('обычный текст с клавиатуры — клавиатура остаётся, как раньше', () {
    expect(
      composerKeepsKeyboardDownAfterSend(
        soloEmoji: false, keyboardWasUp: true, emojiPanelOpen: false),
      isFalse,
    );
    // Соло-эмодзи, набранный при поднятой клавиатуре: её не прячем —
    // эффект и так встаёт в видимую часть над ней.
    expect(
      composerKeepsKeyboardDownAfterSend(
        soloEmoji: true, keyboardWasUp: true, emojiPanelOpen: false),
      isFalse,
    );
  });

  test('🔴 подключено: после отправки фокус — только через правило', () {
    final src = File('lib/ui/chat_screen.dart').readAsStringSync();
    expect(src, contains('final keyboardWasUp = _messageInputFocusNode.hasFocus;'));
    expect(src, contains('!composerKeepsKeyboardDownAfterSend('));
  });
}
