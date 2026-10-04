// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Ширина колонки настроек и плитки значков — измерением, а не на глаз.
//
// 🔴 ЗАЧЕМ ИЗМЕРЯТЬ. Жалоба владельца 21.09.2026 звучала так: «страница
// настроек выглядит слишком огромной на весь экран». Причина была ровно одна и
// проверяемая числом — область содержимого занимала ВСЮ оставшуюся ширину, и
// на его мониторе (3440 точек) строка настройки растягивалась на три тысячи:
// подпись у одного края, переключатель у другого. Глаз перестаёт их связывать.
//
// Поэтому проверка идёт по ШИРИНЕ КАРТОЧКИ на широком окне, а не по наличию
// `ConstrainedBox` в дереве: обёртку легко оставить и обойти, а число врать не
// умеет.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_style.dart';
import 'package:secretly_app/ui/desktop/workspace/workspace_layout.dart';

const double _kMaxContent = 760;

Widget host(Widget child, {double width = 3440, double height = 1400}) =>
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

WorkspaceSection section(String id, String label, {Color? tint}) =>
    WorkspaceSection(
      id: id,
      icon: Icons.settings,
      label: label,
      subtitle: 'подпись $id',
      group: 'Приложение',
      tint: tint,
      // Поля — как у настоящих разделов (`_PaneScaffold`: 32 по бокам).
      builder: (_) => ListView(
        padding: const EdgeInsets.fromLTRB(32, 4, 32, 96),
        children: [
          Container(key: ValueKey('card-$id'), height: 80, color: Colors.blue),
        ],
      ),
    );

void main() {
  testWidgets('🔴 на мониторе 3440 карточка не шире предела', (t) async {
    t.view.physicalSize = const Size(3440, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(host(WorkspaceLayout(
      title: 'Настройки',
      contentMaxWidth: _kMaxContent,
      sections: [section('general', 'Общие', tint: DIconTint.amber)],
    )));
    await t.pumpAndSettle();

    final card = t.getSize(find.byKey(const ValueKey('card-general')));
    // 760 колонка минус боковые поля по 32 (макет) = 696 полезной ширины.
    expect(card.width, lessThanOrEqualTo(_kMaxContent));
    expect(card.width, closeTo(_kMaxContent - 64, 1));
  });

  testWidgets('без предела колонка по-прежнему во всю ширину', (t) async {
    // Предел — свойство НАСТРОЕК, а не всех окон-воркспейсов: другим окнам
    // ширина может быть нужна вся. Если бы он был вшит в разметку, это
    // ограничение пришло бы к ним молча.
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(host(WorkspaceLayout(
      title: 'Настройки',
      sections: [section('general', 'Общие')],
    ), width: 1600, height: 1000));
    await t.pumpAndSettle();
    final card = t.getSize(find.byKey(const ValueKey('card-general')));
    expect(card.width, greaterThan(_kMaxContent));
  });

  testWidgets('🔴 шапка раздела стоит РОВНО над карточкой', (t) async {
    // Поля шапки лежат внутри ограниченной колонки, а не снаружи неё: снаружи
    // заголовок вставал бы на 20 точек левее карточки, которую называет.
    t.view.physicalSize = const Size(3440, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(host(WorkspaceLayout(
      title: 'Настройки',
      contentMaxWidth: _kMaxContent,
      sections: [section('general', 'Общие', tint: DIconTint.amber)],
    )));
    await t.pumpAndSettle();
    final titleX = t.getTopLeft(find.text('Общие').last).dx;
    final cardX = t.getTopLeft(find.byKey(const ValueKey('card-general'))).dx;
    // Заголовок отодвинут от края колонки на плитку значка (36) плюс зазор.
    expect(titleX - cardX, closeTo(36 + 12, 1));
  });

  testWidgets('в колонке — голый цветной знак, в шапке — плитка', (t) async {
    // 🔴 Макет владельца (29.09.2026): строка раздела без плитки — знак 19 и
    // подпись; плитка 36 осталась только в шапке открытого раздела.
    await t.pumpWidget(host(WorkspaceLayout(
      title: 'Настройки',
      contentMaxWidth: _kMaxContent,
      sections: [section('general', 'Общие', tint: DIconTint.amber)],
    )));
    await t.pumpAndSettle();
    final plates = t.widgetList<WorkspaceIconPlate>(
      find.byType(WorkspaceIconPlate),
    ).toList();
    expect(plates.length, 2, reason: 'строка раздела и шапка содержимого');
    expect(plates.map((p) => p.tint).toSet(), {DIconTint.amber});
    expect(plates.map((p) => p.size).toSet(), {19.0, 36.0});
    expect(plates.firstWhere((p) => p.size == 19).plain, isTrue);
    expect(plates.firstWhere((p) => p.size == 36).plain, isFalse);
  });

  testWidgets('🔴 знаки колонки ЦВЕТНЫЕ — каждый своим цветом раздела',
      (t) async {
    // Владелец: «иконки должны быть сразу все цветные — это важно». В макете
    // цветной только выбранный; здесь — все, и не серым тоном подписи.
    await t.pumpWidget(host(WorkspaceLayout(
      title: 'Настройки',
      sections: [
        section('general', 'Общие', tint: DIconTint.amber),
        section('calls', 'Звонки', tint: DIconTint.cyan),
        section('privacy', 'Приватность', tint: DIconTint.green),
      ],
    )));
    await t.pumpAndSettle();
    const p = SettingsPalette.darkPalette;
    Color glyphOf(String label) {
      final row = find.ancestor(
        of: find.text(label).first,
        matching: find.byType(Row),
      ).first;
      final icon = t.widget<Icon>(
        find.descendant(of: row, matching: find.byType(Icon)).first,
      );
      return icon.color!;
    }

    // «Общие» — выбранный, остальные нет: цвет у всех свой, не серый.
    expect(glyphOf('Звонки'), p.glyph(DIconTint.cyan));
    expect(glyphOf('Приватность'), p.glyph(DIconTint.green));
    for (final label in ['Звонки', 'Приватность']) {
      expect(glyphOf(label), isNot(p.muted));
      expect(glyphOf(label), isNot(p.faint));
    }
    expect(glyphOf('Звонки'), isNot(glyphOf('Приватность')));
  });

  testWidgets('поиск в колонке сужает список и очищается крестиком', (t) async {
    await t.pumpWidget(host(WorkspaceLayout(
      title: 'Настройки',
      sections: [
        section('general', 'Общие', tint: DIconTint.amber),
        section('calls', 'Звонки', tint: DIconTint.cyan),
      ],
    )));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'звон');
    await t.pumpAndSettle();
    // «Общие» ушли из колонки, «Звонки» остались — и открыты справа.
    expect(find.text('Общие'), findsNothing);
    expect(find.text('Звонки'), findsNWidgets(2));
    await t.enterText(find.byType(TextField), 'нет такого');
    await t.pumpAndSettle();
    expect(find.text('Ничего не найдено'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Очистить'));
    await t.pumpAndSettle();
    expect(find.text('Общие'), findsOneWidget);
  });

  testWidgets('раздел без цвета рисует голый значок, а не пустую плитку',
      (t) async {
    await t.pumpWidget(host(WorkspaceLayout(
      title: 'Настройки',
      sections: [section('general', 'Общие')],
    )));
    await t.pumpAndSettle();
    expect(find.byType(WorkspaceIconPlate), findsNWidgets(2));
    expect(find.byIcon(Icons.settings), findsNWidgets(2));
  });
}
