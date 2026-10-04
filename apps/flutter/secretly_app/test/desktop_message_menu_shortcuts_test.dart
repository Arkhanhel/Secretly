// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 МЕНЮ СООБЩЕНИЯ НЕ ОБЕЩАЕТ НЕСУЩЕСТВУЮЩИХ КЛАВИШ (01.10.2026).
//
// «Cmd R», «Cmd E» и «Cmd C» у «Копировать текст» ничего не делали. Осталась
// одна подсказка — у «Скопировать выделенное», и она своя у каждой системы.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/chat/message_context_menu.dart';
import 'package:secretly_app/ui/desktop/primitives/context_menu.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('ru'));

  List<CtxMenuItem> items({bool withSelection = true}) =>
      MessageContextMenu.sections(
        l10n: l10n,
        isSelf: true,
        canEdit: true,
        canDelete: true,
        canPin: true,
        onReply: () {},
        onForward: () {},
        onCopySelection: withSelection ? () {} : null,
        onCopy: () {},
        onEdit: () {},
        onPin: () {},
        onDelete: () {},
      ).expand((section) => section).toList();

  test('подсказка есть только у копирования выделенного', () {
    final withHint = items().where((i) => i.shortcut != null).toList();
    expect(withHint, hasLength(1));
    expect(withHint.single.label, l10n.desktopMenuCopySelection);
    expect(
      withHint.single.shortcut,
      Platform.isMacOS ? '⌘C' : 'Ctrl+C',
    );
  });

  test('без выделения подсказок нет вовсе', () {
    expect(items(withSelection: false).where((i) => i.shortcut != null), isEmpty);
  });

  // 01.10.2026: `secretly://msg/{id}` не открывает ни компьютер, ни телефон —
  // пункт, ведущий в никуда, убран.
  test('«Копировать ссылку» на сообщение в меню нет', () {
    expect(
      items().map((i) => i.label),
      isNot(contains(l10n.desktopMenuCopyLink)),
    );
    final panel = File(
      'lib/ui/desktop/chat/chat_thread_panel.dart',
    ).readAsStringSync();
    expect(panel.contains("'secretly://msg/"), isFalse);
  });
}
