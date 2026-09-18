// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ESCAPE ОТМЕНЯЕТ ОТВЕТ И ПРАВКУ.
//
// ЧТО БЫЛО. Отменить их можно было только крестиком в карточке — крохотной
// мишенью в дальнем углу поля. Escape — первое, что жмёт человек, передумавший
// отвечать, и до сих пор он не делал НИЧЕГО: карточка оставалась, и следующее
// сообщение уходило ответом на то, на что отвечать уже расхотелось.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final panel = File(
    'lib/ui/desktop/chat/chat_thread_panel.dart',
  ).readAsStringSync();

  test('🔴 Escape снимает карточку ответа', () {
    expect(
      panel.contains(
        'if (_ctx != null && event.logicalKey == LogicalKeyboardKey.escape)',
      ),
      isTrue,
    );
  });

  test('🔴 сперва закрывается ПОИСК, если он открыт', () {
    // Закрывать надо то, что человек открыл последним. Проверка поиска стоит
    // выше по коду, то есть срабатывает первой.
    final search = panel.indexOf(
      'if (widget.searchOpen && event.logicalKey == LogicalKeyboardKey.escape)',
    );
    final ctx = panel.indexOf(
      'if (_ctx != null && event.logicalKey == LogicalKeyboardKey.escape)',
    );
    expect(search, greaterThan(0));
    expect(ctx, greaterThan(search));
  });

  test('🔴 у ПРАВКИ текст в поле стирается, у ОТВЕТА — нет', () {
    // У правки текст подставлен приложением: без карточки он превратился бы в
    // новое сообщение, которое человек не писал. У ответа поле он набирал сам.
    expect(panel.contains('if (_ctxWasEdit) _composer.clear();'), isTrue);
    expect(panel.contains('bool _ctxWasEdit = false;'), isTrue);
  });

  test('признак правки ставится и снимается вместе с карточкой', () {
    // Иначе Escape после «ответить» стёр бы набранное — по памяти о прошлой
    // правке.
    expect(panel.contains('_ctxWasEdit = true;'), isTrue);
    // Снимается во всех местах, где открывается ОТВЕТ, и при крестике.
    expect('_ctxWasEdit = false;'.allMatches(panel).length, greaterThanOrEqualTo(4));
  });
}
