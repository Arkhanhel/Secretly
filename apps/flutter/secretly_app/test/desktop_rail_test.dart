// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Рейка: счётчики, закреплённые комнаты, свой портрет.
//
// 🔴 Счётчики на рейке не показывались НИКОГДА.
//
// Поддержка значков в рейке была с самого начала, но `unreadByTab` никто не
// заполнял — параметр существовал со значением по умолчанию, и рейка честно
// рисовала нули. Заметить это по коду нельзя: и объявление, и отрисовка
// выглядят рабочими, не хватало только вызывающей стороны.
//
// Поэтому проверка идёт от ДАННЫХ к тому, что видно, а не от наличия параметра.

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/shell/sidebar.dart';

Widget _host({
  Map<DesktopSection, int> unread = const <DesktopSection, int>{},
  List<RailSpace> spaces = const <RailSpace>[],
  String? activeSpace,
  ValueChanged<String>? onOpenSpace,
  String selfName = 'Юрий',
}) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DColors(
      colors: kDColorsDark,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: 700,
          child: DesktopSidebar(
            active: DesktopSection.chats,
            onSelect: (_) {},
            unreadByTab: unread,
            spaces: spaces,
            activeSpaceConvoId: activeSpace,
            onOpenSpace: onOpenSpace,
            selfName: selfName,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  group('счётчики', () {
    testWidgets('🔴 непрочитанное видно на рейке', (t) async {
      await t.pumpWidget(
        _host(
          unread: const {DesktopSection.chats: 12, DesktopSection.rooms: 3},
        ),
      );
      await t.pump();

      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('ноль значка не рисует', (t) async {
      await t.pumpWidget(_host(unread: const {DesktopSection.chats: 0}));
      await t.pump();

      expect(find.text('0'), findsNothing);
    });

    testWidgets('больше сотни — «99+»', (t) async {
      await t.pumpWidget(_host(unread: const {DesktopSection.chats: 1234}));
      await t.pump();

      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('закреплённые комнаты', () {
    const family = RailSpace(convoId: 'group:1', title: 'Family', unread: 0);
    const core = RailSpace(convoId: 'group:2', title: 'Core', unread: 5);

    testWidgets('без закреплённых раздела нет', (t) async {
      await t.pumpWidget(_host());
      await t.pump();

      // Разделитель появляется только вместе с плитками: одна черта посреди
      // пустой рейки ничего не сообщает.
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.text('Family'), findsNothing);
    });

    testWidgets('🔴 нажатие сообщает комнату', (t) async {
      final opened = <String>[];
      await t.pumpWidget(
        _host(spaces: const [family, core], onOpenSpace: opened.add),
      );
      await t.pumpAndSettle();

      // Портреты подписаны инициалами — по ним и ищем.
      await t.tap(find.text('CO'));
      await t.pump();

      expect(opened, ['group:2']);
    });

    testWidgets('непрочитанное комнаты видно на плитке', (t) async {
      await t.pumpWidget(_host(spaces: const [core]));
      await t.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });
  });

  testWidgets('внизу рейки — СВОЙ портрет, а не безликий значок', (t) async {
    // Рейка единственное, что видно всегда, и собственный портрет отвечает на
    // вопрос «под кем я вошёл». У человека с несколькими профилями это не
    // праздный вопрос.
    await t.pumpWidget(_host(selfName: 'Юрий Архангельский'));
    await t.pumpAndSettle();

    expect(find.text('ЮА'), findsOneWidget);
  });
}
