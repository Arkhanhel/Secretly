// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Ветки комнаты в списке — только у ОТКРЫТОЙ (указание владельца 15.09.2026).
//
// ЧТО БЫЛО ДО ЭТОГО И ПОЧЕМУ УБИРАЛИ. Список чатов раскрывал ветки подстроками
// у ЛЮБОЙ комнаты, и ровно те же ветки в тот же момент показывала полоса в
// шапке переписки — с теми же счётчиками и тем же выбором. Один выбор в двух
// местах окна: человек нажимал в одном, подсветка менялась в обоих, и было
// непонятно, какое из них главное.
//
// ЧТО ПРОСИТ ВЛАДЕЛЕЦ ТЕПЕРЬ. «В пк версии если есть новые темы в комнатах, то
// при нажатии на комнату на левой панели сразу под ней должны высвечиваться
// подкомнаты». То есть ветки в списке нужны — но у той комнаты, которую
// открыли, а не у всех сразу.
//
// Это и есть разница с прежним поведением, и её стережёт этот файл: ветки
// появляются под ОТКРЫТОЙ строкой и не появляются под соседними. Так список не
// растягивается чужими ветками, а полоса в шапке остаётся тем же выбором, а не
// вторым.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/message_command_utils.dart' show RoomTopicRef;
import 'package:secretly_app/ui/desktop/chat/chat_list_panel.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

const _rooms = <ChatListItem>[
  ChatListItem(
    id: 'r1',
    name: 'Secretly Core',
    preview: 'привет',
    time: '14:02',
    kind: ChatKind.group,
  ),
  ChatListItem(
    id: 'r2',
    name: 'Release Radar',
    preview: 'сборка 47',
    time: '13:58',
    kind: ChatKind.group,
  ),
];

const _topics = <RoomTopicRef>[
  RoomTopicRef(id: 't1', title: 'релиз', createdAtMs: 1),
  RoomTopicRef(id: 't2', title: 'созвон', mark: 'call', createdAtMs: 2),
];

Widget _host({
  required String? selectedId,
  List<RoomTopicRef> topics = _topics,
  ValueChanged<String?>? onSelectTopic,
  Map<String, int> unread = const <String, int>{},
}) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DColors(
      colors: kDColorsDark,
      child: SizedBox(
        width: 320,
        height: 600,
        child: ChatListPanel(
          items: _rooms,
          selectedId: selectedId,
          onSelect: (_) {},
          topics: topics,
          currentTopicId: null,
          topicUnread: unread,
          onSelectTopic: onSelectTopic ?? (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('◆ ветки видны под ОТКРЫТОЙ комнатой', (t) async {
    await t.pumpWidget(_host(selectedId: 'r1'));
    await t.pumpAndSettle();

    expect(find.text('Secretly Core'), findsOneWidget);
    expect(find.text('Release Radar'), findsOneWidget);
    // «Основа» — первая ветка, потом остальные по порядку.
    expect(find.text('Основа'), findsOneWidget);
    expect(find.text('релиз'), findsOneWidget);
    expect(find.text('созвон'), findsOneWidget);
  });

  testWidgets('🔴 под ЗАКРЫТОЙ комнатой веток нет', (t) async {
    // Именно из-за веток у всех подряд выбор однажды и раздвоился.
    await t.pumpWidget(_host(selectedId: 'r2'));
    await t.pumpAndSettle();
    // Открыта вторая комната — ветки показываются у неё, и ровно один раз.
    expect(find.text('Основа'), findsOneWidget);

    await t.pumpWidget(_host(selectedId: null));
    await t.pumpAndSettle();
    expect(
      find.text('Основа'),
      findsNothing,
      reason: 'ни одна комната не открыта — веток в списке быть не должно',
    );
  });

  testWidgets('без веток список выглядит как раньше', (t) async {
    await t.pumpWidget(
      _host(selectedId: 'r1', topics: const <RoomTopicRef>[]),
    );
    await t.pumpAndSettle();
    expect(find.text('Основа'), findsNothing);
    expect(find.text('Secretly Core'), findsOneWidget);
  });

  testWidgets('нажатие по ветке выбирает её', (t) async {
    final picked = <String?>[];
    await t.pumpWidget(
      _host(selectedId: 'r1', onSelectTopic: picked.add),
    );
    await t.pumpAndSettle();

    await t.tap(find.text('релиз'));
    await t.pump();
    expect(picked, ['t1']);

    await t.tap(find.text('Основа'));
    await t.pump();
    expect(picked.last, isNull, reason: '«Основа» — это отсутствие ветки');
  });

  testWidgets('счётчик непрочитанного у ветки', (t) async {
    await t.pumpWidget(
      _host(selectedId: 'r1', unread: const <String, int>{'t1': 3}),
    );
    await t.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
  });

  test('🔴 выбор остаётся ОДНИМ: список и полоса читают один склад', () {
    // Раздвоение возникало не от самих подстрок, а от второго источника
    // правды. Здесь список берёт темы из того же склада, что и полоса.
    final section = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();
    expect(section.contains('RoomTopicsStrip('), isTrue);
    expect(section.contains('topics: topicStore?.topics'), isTrue);
    expect(section.contains('onSelectTopic: topicStore?.onSelectTopic'), isTrue);
  });

  test('ветки в списке рисуются отдельной строкой, а не как чат', () {
    // Отступ и меньший рост — чтобы ветка читалась принадлежащей комнате, а
    // не соседним чатом.
    final panel = File(
      'lib/ui/desktop/chat/chat_list_panel.dart',
    ).readAsStringSync();
    expect(panel.contains('class _TopicSubRow'), isTrue);
    expect(panel.contains('EdgeInsets.fromLTRB(26, 1'), isTrue);
  });
}
