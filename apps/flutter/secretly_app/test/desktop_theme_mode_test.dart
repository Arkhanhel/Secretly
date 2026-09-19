// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Три состояния схемы вместо тумблера, и «Авто» — настоящее.
//
// 🔴 ПОЧЕМУ ЭТО МОЖНО БЫЛО СДЕЛАТЬ, НЕ ТРОГАЯ ТЕЛЕФОН.
//
// Сама схема живёт в общем `AppController.darkMode`, и это звучит как
// «настройка общая». Но `setDarkMode` пишет ТОЛЬКО локальные
// SharedPreferences и ничего не отправляет — значит десктоп волен решать сам,
// откуда брать значение. Третьего состояния в контроллере поэтому НЕ
// появилось: «Авто» живёт в десктопных настройках и просто ставит `darkMode`
// по системной теме.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/primitives/desktop_segmented.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';

Widget host(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(colors: kDColorsDark, child: Scaffold(body: child)),
    );

void main() {
  setUp(DesktopUiPrefs.resetForTest);

  group('настройка схемы', () {
    test('по умолчанию тёмная', () {
      expect(DesktopUiPrefs.themeMode.value, 'dark');
    });

    test('принимает только три значения, мусор считает тёмной', () async {
      await DesktopUiPrefs.setThemeMode('auto');
      expect(DesktopUiPrefs.themeMode.value, 'auto');
      await DesktopUiPrefs.setThemeMode('light');
      expect(DesktopUiPrefs.themeMode.value, 'light');
      await DesktopUiPrefs.setThemeMode('привет');
      expect(
        DesktopUiPrefs.themeMode.value,
        'dark',
        reason: 'испорченная настройка не должна менять вид на случайный',
      );
    });

    test('оповещает слушателей — иначе «Авто» не применится сразу', () async {
      var ticks = 0;
      void listener() => ticks++;
      DesktopUiPrefs.themeMode.addListener(listener);
      await DesktopUiPrefs.setThemeMode('auto');
      DesktopUiPrefs.themeMode.removeListener(listener);
      expect(ticks, 1);
    });
  });

  testWidgets('сегменты показывают выбранное и переключают', (t) async {
    var picked = 'dark';
    await t.pumpWidget(host(StatefulBuilder(
      builder: (ctx, setState) => DesktopSegmented<String>(
        values: const ['dark', 'light', 'auto'],
        labels: const ['Тёмная', 'Светлая', 'Авто'],
        value: picked,
        onChanged: (v) => setState(() => picked = v),
      ),
    )));
    expect(find.text('Авто'), findsOneWidget);
    await t.tap(find.text('Светлая'));
    await t.pumpAndSettle();
    expect(picked, 'light');
  });

  test('🔴 «Авто» реализовано в ОКНЕ, а не в контроллере', () {
    final ctl = File('lib/app/app_controller.dart').readAsStringSync();
    expect(
      ctl.contains('ThemeMode'),
      isFalse,
      reason: 'третьего состояния в общем контроллере быть не должно — это '
          'изменило бы поведение выпущенного телефона',
    );
    final app = File(
      'lib/ui/desktop/app/desktop_production_app.dart',
    ).readAsStringSync();
    expect(app.contains('_applyAutoThemeIfNeeded'), isTrue);
    expect(app.contains('MediaQuery.platformBrightnessOf'), isTrue);
    expect(
      app.contains("DesktopUiPrefs.themeMode.addListener"),
      isTrue,
      reason: 'без подписки переключение на «Авто» не применилось бы до '
          'следующей перерисовки по любому другому поводу',
    );
  });
}
