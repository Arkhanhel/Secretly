// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Выделение текста в пузыре: слово под пальцем, меню, «Выбрать все»
// (24.11.2026).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/inline_text_selection.dart';

void main() {
  testWidgets('слово под пальцем, копируется именно оно; «Выбрать все»; '
      'пузырь перекрыт — как в режиме выделения', (t) async {
    final key = GlobalKey<InlineTextSelectionState>();
    var cleared = 0;
    String? copied;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AbsorbPointer(
              child: InlineTextSelection(
                key: key,
                onCleared: () => cleared++,
                menu: (s) => [
                  ContextMenuButtonItem(
                    label: 'Копировать',
                    onPressed: () => copied = s.selectedText,
                  ),
                  ContextMenuButtonItem(
                    label: 'Выбрать все',
                    onPressed: s.selectAll,
                  ),
                ],
                child: const Text('Привет дорогой друг'),
              ),
            ),
          ),
        ),
      ),
    );
    final box = t.getRect(find.text('Привет дорогой друг'));
    key.currentState!.selectWordAt(box.center);
    await t.pumpAndSettle();
    expect(key.currentState!.selectedText, 'дорогой');
    expect(find.text('Копировать'), findsOneWidget);
    await t.tap(find.text('Копировать'));
    expect(copied, 'дорогой');

    // Другое слово — долгим нажатием ещё раз.
    key.currentState!.selectWordAt(box.centerLeft + const Offset(6, 0));
    await t.pumpAndSettle();
    expect(key.currentState!.selectedText, 'Привет');

    await t.tap(find.text('Выбрать все'));
    await t.pumpAndSettle();
    expect(key.currentState!.selectedText, 'Привет дорогой друг');
    expect(cleared, 0, reason: 'смена выделения — не отмена');
  });

  testWidgets('палец мимо слов — выделяется весь текст', (t) async {
    final key = GlobalKey<InlineTextSelectionState>();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InlineTextSelection(
              key: key,
              onCleared: () {},
              menu: (_) => const [],
              child: const Text('Что именно'),
            ),
          ),
        ),
      ),
    );
    key.currentState!.selectWordAt(const Offset(2, 2));
    await t.pumpAndSettle();
    expect(key.currentState!.selectedText, 'Что именно');
  });
}
