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
      builder: (_) => ListView(
        padding: const EdgeInsets.all(20),
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
    // 760 колонка минус боковые поля списка по 20 = 720 полезной ширины.
    expect(card.width, lessThanOrEqualTo(_kMaxContent));
    expect(card.width, closeTo(_kMaxContent - 40, 1));
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
    // Заголовок отодвинут от края колонки на плитку значка (34) плюс зазор.
    expect(titleX - cardX, closeTo(34 + 12, 1));
  });

  testWidgets('плитка значка рисуется и в колонке, и в шапке', (t) async {
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
    // Размеры разные намеренно: в списке плитка мельче строки, в шапке крупнее
    // заголовка. Одинаковые смотрелись бы как повтор, а не как «ты здесь».
    expect(plates.map((p) => p.size).toSet(), {28.0, 34.0});
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
