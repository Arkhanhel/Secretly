// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 СВЁРНУТЫЙ СПИСОК — СТОЛБИК ПОРТРЕТОВ, КАК В ТЕЛЕГРАМЕ.
//
// Указание владельца 16.09.2026: «Да, сделай режим с аватарками». В телеграме
// край левой панели, утянутый дальше минимума, сворачивает её в столбик
// портретов со счётчиками; вытянутый обратно — разворачивает.
//
// Что закреплено здесь:
//   · порог сворачивания — середина между минимумом (260) и столбиком (76);
//   · край меряется от курсора: упёршийся край не трогается, пока курсор не
//     вернётся к нему;
//   · свёрнутое состояние сохраняется, двойной щелчок его снимает;
//   · свернули одним жестом — развернётся к ширине, что была ДО жеста;
//   · в столбике нет ни поиска, ни папок, ни подписей — только портреты,
//     счётчики и подсказки; лупа разворачивает список и ставит курсор в поиск.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/chat_list_footer.dart';
import 'package:secretly_app/ui/desktop/chat/chat_list_panel.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/avatar.dart';
import 'package:secretly_app/ui/desktop/shell/desktop_shell.dart';
import 'package:secretly_app/ui/desktop/shell/list_thread_split.dart';
import 'package:secretly_app/ui/desktop/shell/pane_widths.dart';
import 'package:secretly_app/ui/desktop/shell/sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _minList = 260.0;
const _floor = 460.0;

void main() {
  group('порог сворачивания', () {
    ListDragResult at(double pointer, {double? details}) => listEdgeAt(
      pointer: pointer,
      available: 1600,
      rail: kRailWidth + 1,
      threadFloor: _floor,
      minList: _minList,
      desiredDetails: details,
      minDetails: 260,
      compactWidth: kCompactListWidth,
    );

    test('🔴 левее середины между минимумом и столбиком — столбик', () {
      final mid = (_minList + kCompactListWidth) / 2; // 168
      expect(at(mid - 1).compact, isTrue);
      expect(at(mid - 1).listWidth, kCompactListWidth);
      expect(at(mid + 1).compact, isFalse);
      // Между порогом и минимумом край стоит на минимуме — список полный.
      expect(at(mid + 1).listWidth, _minList);
    });

    test('без ширины столбика сворачиваться нельзя', () {
      final r = listEdgeAt(
        pointer: 10,
        available: 1600,
        rail: kRailWidth,
        threadFloor: _floor,
        minList: _minList,
      );
      expect(r.compact, isFalse);
      expect(r.listWidth, _minList);
    });

    test('свёрнутый список отдаёт место правой панели целиком', () {
      final r = at(20, details: 330);
      expect(r.compact, isTrue);
      expect(r.detailsWidth, 330);
    });
  });

  group('оболочка: свернуть и развернуть', () {
    late DesktopShellApi api;

    Future<void> pumpShell(WidgetTester t) async {
      t.view.physicalSize = const Size(1600, 1000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DColors(
            colors: kDColorsDark,
            child: DesktopShell(
              sidebarBuilder: (ctx, active, onSelect) =>
                  const SizedBox(width: kRailWidth),
              contentBuilder: (ctx, section, a) {
                api = a;
                return ListThreadSplit.fromApi(
                  a,
                  list: const ColoredBox(
                    key: ValueKey('list'),
                    color: Colors.black,
                  ),
                  thread: const ColoredBox(color: Colors.grey),
                );
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    double listW(WidgetTester t) =>
        t.getSize(find.byKey(const ValueKey('list'))).width;
    Offset seam(WidgetTester t) => Offset(
      t.getRect(find.byKey(const ValueKey('list'))).right + 1,
      500,
    );

    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('🔴 утянутый за минимум список сворачивается в столбик', (
      t,
    ) async {
      await pumpShell(t);
      expect(api.listCompact, isFalse);

      await t.dragFrom(seam(t), const Offset(-300, 0));
      await t.pumpAndSettle();
      expect(api.listCompact, isTrue);
      expect(listW(t), kCompactListWidth);

      // Сохраняется: после перезапуска список останется свёрнутым.
      await t.pump(const Duration(milliseconds: 500));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('desktop_pane_list_compact_v1'), isTrue);
    });

    testWidgets('🔴 край меряется от курсора: вернулся за порог — развернулся', (
      t,
    ) async {
      await pumpShell(t);
      final gesture = await t.startGesture(seam(t));
      // 322 → курсор на 150: левее порога, список свёрнут.
      await gesture.moveBy(const Offset(-172, 0));
      await t.pump();
      expect(api.listCompact, isTrue);
      // Курсор на 200: правее порога, но левее минимума — список полный,
      // край на минимуме.
      await gesture.moveBy(const Offset(50, 0));
      await t.pump();
      expect(api.listCompact, isFalse);
      expect(listW(t), _minList);
      // Курсор на 400 — край идёт за ним.
      await gesture.moveBy(const Offset(200, 0));
      await t.pump();
      expect(listW(t), closeTo(400, 0.5));
      await gesture.up();
      await t.pumpAndSettle();
    });

    testWidgets('из столбика — вытянуть обратно', (t) async {
      await pumpShell(t);
      await t.dragFrom(seam(t), const Offset(-300, 0));
      await t.pumpAndSettle();
      expect(api.listCompact, isTrue);

      // Новый жест начинается от края столбика (76).
      await t.dragFrom(seam(t), const Offset(300, 0));
      await t.pumpAndSettle();
      expect(api.listCompact, isFalse);
      expect(listW(t), closeTo(76 + 300, 0.5));
    });

    testWidgets('🔴 лупа разворачивает к ширине, что была ДО сворачивания', (
      t,
    ) async {
      await pumpShell(t);
      await t.dragFrom(seam(t), const Offset(200, 0)); // 522
      await t.pumpAndSettle();
      await t.dragFrom(seam(t), const Offset(-500, 0)); // через минимум — в столбик
      await t.pumpAndSettle();
      expect(api.listCompact, isTrue);

      api.onListExpand!();
      await t.pumpAndSettle();
      expect(api.listCompact, isFalse);
      expect(
        listW(t),
        closeTo(522, 0.5),
        reason: 'а не к минимуму, через который курсор прошёл по пути',
      );
    });

    testWidgets('🔴 потерянный конец жеста не ломает следующий', (t) async {
      // Конец жеста может не дойти (ручку перестроили посреди движения).
      // Начало нового жеста само сбрасывает отсчёт от курсора — иначе второй
      // жест продолжал бы первый и край «прилипал» бы к старому месту.
      t.view.physicalSize = const Size(1600, 1000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DColors(
            colors: kDColorsDark,
            child: DesktopShell(
              sidebarBuilder: (ctx, active, onSelect) =>
                  const SizedBox(width: kRailWidth),
              contentBuilder: (ctx, section, a) => ListThreadSplit(
                listWidth: a.listWidth,
                onResize: a.onListResize,
                onResizeStart: a.onListResizeStart,
                // onResizeEnd намеренно не подключён.
                list: const ColoredBox(
                  key: ValueKey('list'),
                  color: Colors.black,
                ),
                thread: const ColoredBox(color: Colors.grey),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.dragFrom(seam(t), const Offset(3000, 0));
      await t.pumpAndSettle();
      await t.dragFrom(seam(t), Offset(400 - listW(t), 0));
      await t.pumpAndSettle();
      expect(listW(t), closeTo(400, 0.5));
    });

    testWidgets('двойной щелчок снимает столбик и возвращает 322', (t) async {
      await pumpShell(t);
      await t.dragFrom(seam(t), const Offset(-300, 0));
      await t.pumpAndSettle();
      expect(api.listCompact, isTrue);

      final at = seam(t);
      await t.tapAt(at);
      await t.pump(const Duration(milliseconds: 40));
      await t.tapAt(at);
      await t.pumpAndSettle();
      expect(api.listCompact, isFalse);
      expect(listW(t), 322);
    });
  });

  group('столбик портретов в списке чатов', () {
    const items = [
      ChatListItem(
        id: 'a',
        name: 'Игорь',
        preview: 'Да, можно',
        time: '12:00',
        pinned: true,
      ),
      ChatListItem(
        id: 'b',
        name: 'Тест 2',
        preview: 'Ок',
        previewAuthor: 'Вы',
        time: '11:00',
        unread: 3,
        kind: ChatKind.group,
      ),
    ];

    Widget host({
      bool compact = true,
      String? selected,
      ValueChanged<String>? onSelect,
      VoidCallback? onExpand,
    }) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Как в окне: фокус уже держит оболочка (`Focus(autofocus: true)`).
      // Без этого `autofocus` поля срабатывал бы в тесте и не срабатывал бы
      // в приложении — ровно так 16.09 и было.
      home: Focus(
        autofocus: true,
        child: Scaffold(
        body: DColors(
          colors: kDColorsDark,
          child: SizedBox(
            width: compact ? kCompactListWidth : 322,
            height: 700,
            child: ChatListPanel(
              items: items,
              selectedId: selected,
              onSelect: onSelect ?? (_) {},
              compact: compact,
              onExpand: onExpand,
              width: compact ? kCompactListWidth : 322,
              onCompose: (_) {},
              categories: const [
                ChatCategory(id: ChatCategoryIds.all, label: 'Все'),
              ],
              footer: ChatListFooter(sync: null, compact: compact),
            ),
          ),
        ),
        ),
      ),
    );

    testWidgets('🔴 только портреты: ни имён, ни поиска, ни папок', (t) async {
      await t.pumpWidget(host());
      await t.pumpAndSettle();
      expect(find.byType(Avatar), findsNWidgets(2));
      expect(find.text('Игорь'), findsNothing);
      expect(find.text('Да, можно'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Все'), findsNothing);
      // Счётчик остаётся — ради него столбик и нужен.
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('имя и последнее сообщение — в подсказке', (t) async {
      await t.pumpWidget(host());
      await t.pumpAndSettle();
      expect(find.byTooltip('Игорь\nДа, можно'), findsOneWidget);
      // У комнаты — с автором, как в обычной строке.
      expect(find.byTooltip('Тест 2\nВы: Ок'), findsOneWidget);
    });

    testWidgets('нажатие выбирает чат, выбранный залит цветом окна', (t) async {
      String? picked;
      await t.pumpWidget(host(onSelect: (id) => picked = id));
      await t.pumpAndSettle();
      await t.tap(find.byType(Avatar).last);
      await t.pumpAndSettle();
      expect(picked, 'b');

      await t.pumpWidget(host(selected: 'b'));
      await t.pumpAndSettle();
      final fill = selectedChatRowFill(kDColorsDark.accentPrimary);
      final filled = find.byWidgetPredicate(
        (w) =>
            w is AnimatedContainer &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == fill,
      );
      expect(filled, findsOneWidget);
    });

    testWidgets('🔴 лупа разворачивает список и ставит курсор в поиск', (
      t,
    ) async {
      var expanded = false;
      await t.pumpWidget(host(onExpand: () => expanded = true));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Поиск'));
      await t.pumpAndSettle();
      expect(expanded, isTrue);

      // Оболочка развернула список — поле поиска появилось с курсором.
      await t.pumpWidget(host(compact: false, onExpand: () {}));
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      final editable = t.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);
    });

    testWidgets('без лупы-просьбы поле при развороте курсор не забирает', (
      t,
    ) async {
      await t.pumpWidget(host());
      await t.pumpAndSettle();
      await t.pumpWidget(host(compact: false));
      await t.pumpAndSettle();
      final editable = t.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isFalse);
    });

    testWidgets('подвал столбика — точка вместо надписи', (t) async {
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DColors(
              colors: kDColorsDark,
              child: SizedBox(
                width: kCompactListWidth,
                child: ChatListFooter(
                  sync: null,
                  compact: true,
                  onOpenArchive: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: 'подвал не влез в столбик');
      expect(find.byTooltip('Архив'), findsOneWidget);
    });
  });

  group('правила разделов', () {
    test('«Звонки» и «Контакты» тоже сворачиваются в столбик', () {
      final calls = File(
        'lib/ui/desktop/app/desktop_calls_section.dart',
      ).readAsStringSync();
      expect(calls.contains('widget.shellApi?.listCompact'), isTrue);
      expect(calls.contains('compact: compact,'), isTrue);
      final contacts = File(
        'lib/ui/desktop/app/desktop_contacts_section.dart',
      ).readAsStringSync();
      expect(contacts.contains('api.listCompact'), isTrue);
      expect(contacts.contains('compact: true,'), isTrue);
    });

    test('раздел чатов передаёт списку и подвалу свёрнутость', () {
      final chats = File(
        'lib/ui/desktop/app/desktop_chats_section.dart',
      ).readAsStringSync();
      expect(chats.contains('compact: widget.shellApi.listCompact,'), isTrue);
      expect(chats.contains('onExpand: widget.shellApi.onListExpand,'), isTrue);
      // Начало и конец жеста подключены вместе с шагом — через fromApi.
      expect(chats.contains('ListThreadSplit.fromApi('), isTrue);
    });
  });
}
