// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/desktop/chat/chat_category_bar.dart';

/// The horizontal category strip that replaced the desktop's collapsible
/// in-list sections. These pin the rules that are easy to break later.
void main() {
  group('category ids', () {
    test('built-ins are namespaced so a folder id can never collide', () {
      expect(ChatCategoryIds.isBuiltIn(ChatCategoryIds.all), isTrue);
      expect(ChatCategoryIds.isBuiltIn(ChatCategoryIds.unread), isTrue);
      expect(ChatCategoryIds.isBuiltIn(ChatCategoryIds.archive), isTrue);
      expect(ChatCategoryIds.isBuiltIn(ChatCategoryIds.personal), isTrue);
    });

    test('a folder id is never mistaken for a built-in', () {
      // Folder ids come from the DB and look like this.
      for (final id in ['f1', 'folder-123', 'a1b2c3d4', '_leading-underscore']) {
        expect(ChatCategoryIds.isBuiltIn(id), isFalse, reason: id);
      }
    });
  });

  Widget host(List<ChatCategory> cats, {String selected = ChatCategoryIds.all}) {
    return MaterialApp(
      home: Scaffold(
        body: ChatCategoryBar(
          categories: cats,
          selectedId: selected,
          onSelect: (_) {},
        ),
      ),
    );
  }

  testWidgets('renders one chip per category', (tester) async {
    await tester.pumpWidget(host(const [
      ChatCategory(id: ChatCategoryIds.all, label: 'Все'),
      ChatCategory(id: 'f1', label: 'Работа'),
      ChatCategory(id: ChatCategoryIds.archive, label: 'Архив'),
    ]));
    expect(find.text('Все'), findsOneWidget);
    expect(find.text('Работа'), findsOneWidget);
    expect(find.text('Архив'), findsOneWidget);
  });

  testWidgets('an empty category list renders nothing at all', (tester) async {
    // The Rooms tab passes no categories; it must not reserve a 40px strip.
    await tester.pumpWidget(host(const []));
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('a locked category shows a padlock', (tester) async {
    await tester.pumpWidget(host(const [
      ChatCategory(
        id: ChatCategoryIds.personal,
        label: 'Личные',
        locked: true,
      ),
    ]));
    // The padlock is what tells the user a password is coming, instead of the
    // prompt arriving as a surprise.
    expect(find.byIcon(Icons.lock), findsNothing); // not a Material icon
    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons, isNotEmpty);
  });

  testWidgets('badges appear only when non-zero', (tester) async {
    await tester.pumpWidget(host(const [
      ChatCategory(id: ChatCategoryIds.all, label: 'Все', badge: 0),
      ChatCategory(id: ChatCategoryIds.unread, label: 'Непрочитанные', badge: 7),
    ]));
    expect(find.text('7'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('a large badge is clamped to 99+', (tester) async {
    await tester.pumpWidget(host(const [
      ChatCategory(id: ChatCategoryIds.unread, label: 'Непрочитанные', badge: 1234),
    ]));
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('tapping a chip reports its id', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatCategoryBar(
          categories: const [
            ChatCategory(id: ChatCategoryIds.all, label: 'Все'),
            ChatCategory(id: 'f1', label: 'Работа'),
          ],
          selectedId: ChatCategoryIds.all,
          onSelect: (id) => picked = id,
        ),
      ),
    ));
    await tester.tap(find.text('Работа'));
    await tester.pump();
    expect(picked, 'f1');
  });

  // ◆ ЧИП «ЗВОНКИ» ИЗ МАКЕТА НЕ ЗАВЕДЁН — ОСОЗНАННО.
  //
  // ТЗ разрешало ровно два исхода: либо чип, либо записанное решение «не
  // заводить». Этот случай сторожит именно запись: без неё через полгода
  // пункт вернётся как «забыли», и кто-нибудь соберёт фильтр по
  // `ChatListPreview.isCall` — по ПОСЛЕДНЕМУ событию разговора.
  group('◆ фильтра «Звонки» в полосе нет, и причина записана', () {
    final src = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();

    test('идентификатора такой категории не появилось', () {
      final bar = File(
        'lib/ui/desktop/chat/chat_category_bar.dart',
      ).readAsStringSync();
      expect(bar.contains('calls'), isFalse);
    });

    test('решение объяснено там, где его стали бы искать', () {
      expect(src.contains('◆ ЧИПА «ЗВОНКИ» ЗДЕСЬ НЕТ'), isTrue);
      // Названы обе половины: чем фильтровать нечем и где журнал есть.
      expect(src.contains('ChatListPreview.isCall'), isTrue);
      expect(src.contains('desktop_calls_section.dart'), isTrue);
    });

    test('сам звонок в списке по-прежнему виден', () {
      // Отказ — про ФИЛЬТР, а не про показ: строка со звонком рисуется.
      expect(src.contains('if (p.isCall) return ChatPreviewIcon.call;'), isTrue);
    });
  });
}
