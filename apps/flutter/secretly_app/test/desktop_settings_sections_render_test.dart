// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Все семнадцать разделов настроек ОТКРЫВАЮТСЯ, а не только числятся в списке.
//
// 🔴 ЗАЧЕМ. Раздел, который падает при открытии, на компьютере выглядит не как
// падение: `_installDesktopErrorGuard` в `main_desktop.dart` глушит красное
// полотно, и человек видит просто пустую правую половину окна. Неотличимо от
// «раздел пока пустой». 13.09.2026 на этом дважды потерялся целый день: правка
// падала молча, и это считали за исправленный дефект.
//
// Здесь каждый раздел открывается по очереди. Любое исключение при отрисовке
// валит тест — молчать ему негде.
//
// Модель окна не подставлена намеренно: так проходит ветка «данных ещё нет»,
// самая хрупкая из двух. С живым контроллером те же панели проверяются
// отдельными тестами на свои настройки.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_workspace.dart';
import 'package:secretly_app/ui/desktop/workspace/workspace_layout.dart';

/// Разделов семнадцать. Число здесь стоит нарочно: если раздел добавят или
/// уберут, тест это заметит и заставит подумать, а не молча проверит меньше.
const int _kSections = 17;

void main() {
  testWidgets('🔴 каждый раздел настроек открывается без падения', (t) async {
    t.view.physicalSize = const Size(3440, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(const MaterialApp(
      locale: Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(body: SettingsWorkspace()),
      ),
    ));
    await t.pumpAndSettle();

    // Плиток на экране ровно на одну больше числа разделов: семнадцать в
    // боковой колонке плюс одна в шапке открытого.
    expect(find.byType(WorkspaceIconPlate), findsNWidgets(_kSections + 1));

    for (var i = 0; i < _kSections; i++) {
      await t.tap(find.byType(WorkspaceIconPlate).at(i));
      await t.pumpAndSettle();
      expect(
        find.byType(WorkspaceIconPlate),
        findsNWidgets(_kSections + 1),
        reason: 'раздел №$i не отрисовался целиком',
      );
    }
  });

  testWidgets('🔴 у каждого раздела свой цвет плитки, серых нет', (t) async {
    t.view.physicalSize = const Size(3440, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(const MaterialApp(
      locale: Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(body: SettingsWorkspace()),
      ),
    ));
    await t.pumpAndSettle();

    final plates = t
        .widgetList<WorkspaceIconPlate>(find.byType(WorkspaceIconPlate))
        .where((p) => p.size == 28)
        .toList();
    expect(plates.length, _kSections);
    expect(
      plates.where((p) => p.tint == null),
      isEmpty,
      reason: 'раздел без цвета рисуется серым значком и читается как сломанный',
    );
  });
}
