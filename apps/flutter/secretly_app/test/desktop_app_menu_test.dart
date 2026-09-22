// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Строка меню macOS: подписи из переводов, у каждого пункта есть дело.
//
// 🔴 ЗАЧЕМ ПРОВЕРЯТЬ ДЕРЕВО, А НЕ НАЖАТИЕ. Меню рисует система, и нажать по
// нему из теста нельзя. Зато можно взять то, что приложение системе ОТДАЁТ:
// подписи, сочетания, обработчики. Обработчик вызывается здесь напрямую —
// значит проверяется не «пункт есть», а «пункт делает».
//
// До 21.09.2026 меню было флаттеровским из `MainMenu.xib` и только
// по-английски: окно на восьми языках, строка меню над ним — на английском.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/shell/desktop_app_menu.dart';

/// Собирает все листья дерева меню в порядке обхода.
List<PlatformMenuItem> _leaves(List<PlatformMenuItem> items) {
  final out = <PlatformMenuItem>[];
  void walk(List<PlatformMenuItem> list) {
    for (final i in list) {
      if (i is PlatformMenu) {
        walk(i.menus);
      } else if (i is PlatformMenuItemGroup) {
        walk(i.members);
      } else {
        out.add(i);
      }
    }
  }
  walk(items);
  return out;
}

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('🔴 верхний ряд меню — на языке ОКНА, а не системы', () {
    List<String> top(AppLocalizations l) => DesktopAppMenu(
          child: const SizedBox(),
          onOpenSettings: () {},
          onOpenShortcuts: () {},
          onOpenAbout: () {},
        ).menus(l).whereType<PlatformMenu>().map((m) => m.label).toList();

    expect(top(ru), ['Secretly', 'Правка', 'Вид', 'Окно', 'Справка']);
    expect(top(en), ['Secretly', 'Edit', 'View', 'Window', 'Help']);
  });

  test('🔴 «Настройки… ⌘,» открывает настройки', () {
    var opened = 0;
    final items = _leaves(DesktopAppMenu(
      child: const SizedBox(),
      onOpenSettings: () => opened++,
    ).menus(ru));
    final settings = items.firstWhere((i) => i.label == 'Настройки…');
    expect(
      settings.shortcut,
      const SingleActivator(LogicalKeyboardKey.comma, meta: true),
    );
    settings.onSelected!();
    expect(opened, 1);
  });

  test('«О программе» и «Горячие клавиши» ведут в свои разделы', () {
    final seen = <String>[];
    final items = _leaves(DesktopAppMenu(
      child: const SizedBox(),
      onOpenAbout: () => seen.add('about'),
      onOpenShortcuts: () => seen.add('shortcuts'),
    ).menus(ru));
    items.firstWhere((i) => i.label == 'О программе').onSelected!();
    items.firstWhere((i) => i.label == 'Горячие клавиши').onSelected!();
    expect(seen, ['about', 'shortcuts']);
  });

  test('🔴 без обработчика пункта НЕТ, а не есть и молчит', () {
    // Пункт меню, который ничего не открывает, хуже отсутствующего: меню —
    // это перечень того, что приложение умеет.
    final items = _leaves(DesktopAppMenu(child: const SizedBox()).menus(ru));
    expect(items.map((i) => i.label), isNot(contains('Настройки…')));
    expect(items.map((i) => i.label), isNot(contains('Горячие клавиши')));
    // «О программе» при этом остаётся — системным пунктом macOS.
    expect(
      items.whereType<PlatformProvidedMenuItem>().map((i) => i.type),
      contains(PlatformProvidedMenuItemType.about),
    );
  });

  test('🔴 «Проверить обновления» НЕ обещано: автообновления нет', () {
    final labels = _leaves(DesktopAppMenu(
      onOpenSettings: () {},
      child: const SizedBox(),
    ).menus(ru)).map((i) => i.label).join(' ').toLowerCase();
    expect(labels.contains('обновл'), isFalse);
    expect(labels.contains('update'), isFalse);
  });

  test('у каждого СВОЕГО пункта есть обработчик', () {
    final items = _leaves(DesktopAppMenu(
      child: const SizedBox(),
      onOpenSettings: () {},
      onOpenShortcuts: () {},
      onOpenAbout: () {},
    ).menus(ru));
    for (final i in items) {
      if (i is PlatformProvidedMenuItem) continue; // их делает система
      expect(i.onSelected, isNotNull,
          reason: 'пункт «${i.label}» ничего не делает');
    }
  });

  testWidgets('🔴 «Копировать» из меню действительно копирует', (t) async {
    // Самая содержательная проверка файла: пункт «Правки» идёт тем же путём,
    // что и ⌘C внутри поля, — через `Actions` вокруг редактируемого текста.
    // Если этот путь однажды разойдётся, пункт станет молчащим, и увидеть это
    // снаружи будет нечем.
    Object? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied = call.arguments;
        return null;
      },
    );
    addTearDown(() => t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final ctrl = TextEditingController(text: 'Привет');
    addTearDown(ctrl.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(controller: ctrl, focusNode: focus),
      ),
    ));
    focus.requestFocus();
    await t.pump();
    ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 6);
    await t.pump();

    final copy = _leaves(DesktopAppMenu(
      child: const SizedBox(),
      onOpenSettings: () {},
    ).menus(ru)).firstWhere((i) => i.label == 'Копировать');
    copy.onSelected!();
    await t.pump();

    expect(copied, isNotNull, reason: 'пункт «Копировать» ничего не скопировал');
    expect((copied! as Map)['text'], 'Привет');
  });
}
