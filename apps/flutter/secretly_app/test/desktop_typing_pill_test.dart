// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// · «Игорь печатает» — плашкой в самой ленте.
//
// ЧТО БЫЛО. Печатание показывалось подписью в шапке переписки и строкой в
// списке чатов. И то и другое видно лишь тому, кто туда смотрит, — а смотрят
// в НИЗ ленты, туда, где сообщение вот-вот появится.
//
// В макете плашка стоит в самой ленте, слева, с отступом 42 — ровно под
// портретом чужого сообщения, то есть в том же столбике, что и текст, который
// она обещает.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final panel = File(
    'lib/ui/desktop/chat/chat_thread_panel.dart',
  ).readAsStringSync();
  final section = File(
    'lib/ui/desktop/app/desktop_chats_section.dart',
  ).readAsStringSync();

  test('· плашка есть и стоит первой в перевёрнутой ленте', () {
    // Первый элемент `reverse: true` — самый нижний на экране.
    expect(panel.contains('class _TypingPill extends StatefulWidget'), isTrue);
    expect(
      panel.contains('return _TypingPill(label: widget.typingLabel!);'),
      isTrue,
    );
    expect(panel.contains('if (idx == 0) {'), isTrue);
  });

  test('никто не печатает — плашка не занимает строку ленты', () {
    // Иначе лента считала бы на один элемент больше и последнее сообщение
    // отрывалось бы от поля ввода.
    expect(
      panel.contains("(widget.typingLabel == null ? 0 : 1)"),
      isTrue,
    );
  });

  test('геометрия из макета', () {
    expect(panel.contains('EdgeInsets.fromLTRB(42, 2, DSpace.xl, 6)'), isTrue);
    expect(panel.contains('height: 28,'), isTrue);
    expect(panel.contains('Colors.white.withValues(alpha: 0.05)'), isTrue);
    // Три точки по 5 точек.
    expect(panel.contains('for (var i = 0; i < 3; i++)'), isTrue);
    expect(panel.contains('width: 5,\n      height: 5,'), isTrue);
  });

  test('🔴 точки дышат только пока окно впереди', () {
    // Бесконечная анимация в ленте — это перерисовка кадр за кадром у окна,
    // на которое никто не смотрит; по той же причине останавливаются
    // украшения профиля.
    expect(panel.contains('WidgetsBindingObserver'), isTrue);
    expect(panel.contains('didChangeAppLifecycleState'), isTrue);
    expect(panel.contains('_ctrl.stop();'), isTrue);
    expect(panel.contains('WidgetsBinding.instance.removeObserver(this);'), isTrue);
  });

  test('🔴 в комнате плашка БЕЗ имени — автора протокол не передаёт', () {
    // Признак «кто-то печатает» комната шлёт, а кто именно — нет. Выдуманное
    // имя здесь было бы прямой ложью о том, кто сейчас пишет.
    // 19.09.2026: подписи уехали в переводы — проверяем ключи.
    expect(section.contains('desktopChatsSomeoneTyping('), isTrue);
    expect(section.contains('l10n.desktopListTyping'), isTrue);
    expect(section.contains('_isDirect && convo.title.trim().isNotEmpty'), isTrue);
  });

  test('подпись в шапке никуда не делась', () {
    // Плашка её не заменяет: в шапке видно и при прокрутке наверх.
    expect(
      section.contains('if (typing) return l10n.desktopChatsTypingEllipsis;'),
      isTrue,
    );
  });
}
