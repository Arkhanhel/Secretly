// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Рейка, сверенная с макетом: одна колонка, а не набор разных кнопок.
//
// Три мелочи и один переезд:
//  · кнопки внизу были 48×48 радиусом 10 — крупнее и угловатее всех плиток
//    над ними, низ рейки выглядел приклеенным;
//  · у активного раздела не было белой полоски у края;
//  · бейдж непрочитанного сидел НА плитке и накрывал её значок;
//  · состояние связи висело отдельной точкой, которая ничему не принадлежала.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/shell/sidebar.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: SizedBox(height: 900, child: child)),
  ),
);

Widget rail({
  DesktopSection active = DesktopSection.chats,
  ConnectionStatus status = ConnectionStatus.connected,
  Map<DesktopSection, int> unread = const {},
}) => DesktopSidebar(
  active: active,
  onSelect: (_) {},
  connectionStatus: status,
  selfName: 'Yurii',
  unreadByTab: unread,
);

void main() {
  test('· плитка рейки одного размера и скругления по всей колонке', () {
    final src = File(
      'lib/ui/desktop/shell/sidebar.dart',
    ).readAsStringSync();
    expect(kRailTileSize, 44);
    expect(kRailTileRadius, 15);
    // Кнопка «Настройки» больше не своего размера.
    expect(src.contains('width: 48,\n            height: 48,'), isFalse);
    final i = src.indexOf('class _SidebarBottom');
    // Границей служит следующий класс, а не «плюс 1600 знаков»: окно по числу
    // знаков сползало с проверяемого места от любой добавленной строки — и
    // тест падал не потому, что плитка стала другой.
    final next = src.indexOf('\nclass ', i + 1);
    final body = src.substring(i, next < 0 ? src.length : next);
    expect(body.contains('width: kRailTileSize'), isTrue);
    expect(body.contains('BorderRadius.circular(kRailTileRadius)'), isTrue);
    expect(body.contains('size: 21'), isTrue);
  });

  testWidgets('· у активного раздела есть И заливка, И полоска у края', (
    t,
  ) async {
    await t.pumpWidget(host(rail()));
    // Полоска 4×18, скруглена только справа: вырастает из края окна.
    final strip = find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      if (d is! BoxDecoration) return false;
      return d.color == Colors.white &&
          d.borderRadius ==
              const BorderRadius.horizontal(right: Radius.circular(4));
    });
    expect(strip, findsOneWidget);
    expect(t.getSize(strip), const Size(4, 18));
  });

  testWidgets('полоска ровно одна — у ВЫБРАННОГО раздела', (t) async {
    await t.pumpWidget(host(rail(active: DesktopSection.calls)));
    final strip = find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      if (d is! BoxDecoration) return false;
      return d.color == Colors.white;
    });
    expect(strip, findsOneWidget);
  });

  group('состояние связи на портрете', () {
    final src = File(
      'lib/ui/desktop/shell/sidebar.dart',
    ).readAsStringSync();

    test('· отдельной точки над «Настройками» больше нет', () {
      expect(src.contains('class _StatusDot'), isFalse);
      expect(src.contains('_StatusDot(status: connectionStatus)'), isFalse);
    });

    test('🔴 значение осталось прежним — СОЕДИНЕНИЕ, а не «я в сети»', () {
      // Это единственное место, где десктоп вообще говорит «нет соединения».
      expect(src.contains('ConnectionStatus.offline => (c.danger, '), isTrue);
      expect(src.contains('ConnectionStatus.connecting => (c.warning, '), isTrue);
      expect(src.contains('final ConnectionStatus connectionStatus;'), isTrue);
    });

    test('подсказка не потерялась вместе с точкой', () {
      expect(src.contains('message: l10n.desktopRailProfile(statusLabel)'), isTrue);
    });

    testWidgets('нет связи — точка красная', (t) async {
      await t.pumpWidget(host(rail(status: ConnectionStatus.offline)));
      final dot = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        if (d is! BoxDecoration) return false;
        return d.shape == BoxShape.circle && d.color == kDColorsDark.danger;
      });
      expect(dot, findsOneWidget);
      expect(t.getSize(dot), const Size(12, 12));
    });
  });

  test('🔴 градиента «есть упоминания» на бейдже нет: данных для него нет', () {
    // В `RailSpace`/`RailSnapshot` лежит одно число — сколько непрочитано, —
    // и отличить «звали лично» от «просто много» нечем. Крашеный по догадке
    // бейдж обещал бы личное обращение там, где его может не быть.
    final src = File(
      'lib/ui/desktop/shell/sidebar.dart',
    ).readAsStringSync();
    final i = src.indexOf('class _UnreadBadge');
    final body = src.substring(i, (i + 3400).clamp(0, src.length));
    final code = body
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(code.contains('gradient'), isFalse);
    // А геометрия — по макету: 19, обводка 2.5, вес 800.
    expect(body.contains('minWidth: 19, minHeight: 19'), isTrue);
    expect(body.contains('width: 2.5'), isTrue);
    expect(body.contains('FontWeight.w800'), isTrue);
  });

  // 🔴 ОТМЕТКА У ЗАКРЕПЛЁННОЙ ПЛИТКИ СЧИТАЛАСЬ НЕ ПО ТОМУ РАЗДЕЛУ.
  //
  // Сюда всегда шёл выбор КОМНАТ, независимо от того, где человек стоит:
  //  1. открыл комнату, вернулся в «Чаты» — обводка у её плитки осталась, и
  //     на рейке горели две отметки сразу;
  //  2. закреплённая переписка с ЧЕЛОВЕКОМ выбирается в складе чатов, а
  //     сравнивалась со складом комнат — её плитка не подсвечивалась никогда.
  group('отметка закреплённой плитки', () {
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();

    test('🔴 считается по ТЕКУЩЕМУ разделу', () {
      expect(app.contains('activeSpaceConvoId: switch (active) {'), isTrue);
      expect(
        app.contains('DesktopSection.rooms => _roomsSelection.selectedConvoId'),
        isTrue,
      );
      expect(
        app.contains('DesktopSection.chats => _chatsSelection.selectedConvoId'),
        isTrue,
      );
      expect(app.contains('activeSpaceConvoId: _roomsSelection.selectedConvoId,'), isFalse);
    });

    test('в разделах без переписок отметки нет вовсе', () {
      // «Звонки» и «Контакты» ничего на рейке не выбирают: висящая там
      // обводка показывала бы выбор, которого сейчас нет.
      expect(app.contains('_ => null,'), isTrue);
    });
  });

  test('· наведение на плитку пространства сжимает радиус, а не растит её', () {
    // Плитка росла до 1.06 — портрет под курсором становился крупнее
    // соседних, и колонка «дышала» при каждом проносе мыши.
    final src = File(
      'lib/ui/desktop/shell/sidebar.dart',
    ).readAsStringSync();
    final i = src.indexOf('class _SpaceTile');
    final body = src.substring(i, (i + 2600).clamp(0, src.length));
    expect(body.contains('(hovered ? 12 : kRailTileRadius) + 2'), isTrue);
    expect(body.contains('scale: pressed ? 0.92 : (hovered ? 1.06 : 1.0)'), isFalse);
    // Нажатие сжимает по-прежнему: это отклик на действие, а не на пронос.
    expect(body.contains('scale: pressed ? 0.92 : 1.0'), isTrue);
  });
}
