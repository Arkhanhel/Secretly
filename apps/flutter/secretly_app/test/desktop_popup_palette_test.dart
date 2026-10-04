// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 БЕЛЫЕ ОКНА НА СВЕТЛОЙ WINDOWS (28.09.2026).
//
// Жалоба владельца: «эмодзи-статус, выбор эмодзи и GIF, плюсик — белый фон».
// Причина была одна на все окна: палитра `DColors` стояла ниже корневого
// навигатора, а диалоги, меню, всплывающие окна и плашки строятся его
// маршрутами и слоями — выше. Не найдя палитры, `DColors.of` брал яркость ОС,
// и на светлой Windows при тёмной теме приложения окна выходили белыми.
//
// Эти тесты воспроизводят именно это: ОС светлая, приложение тёмное.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/material_theme.dart';
import 'package:secretly_app/ui/desktop/primitives/context_menu.dart';
import 'package:secretly_app/ui/desktop/primitives/desktop_dialog.dart';
import 'package:secretly_app/ui/desktop/primitives/desktop_popover.dart';
import 'package:secretly_app/ui/desktop/primitives/desktop_snackbar.dart';

/// Приложение так же, как собирает его ПК: палитра — в `builder`, над
/// навигатором.
Widget app(DColorSet palette, Widget home) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: desktopMaterialTheme(palette, dark: palette == kDColorsDark),
      builder: (ctx, child) => DColors(colors: palette, child: child!),
      home: Scaffold(body: Center(child: home)),
    );

DColorSet paletteAt(WidgetTester t, Finder f) => DColors.of(t.element(f));

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .platformBrightnessTestValue = Brightness.light;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .clearPlatformBrightnessTestValue();
  });

  testWidgets('окно DesktopDialog тёмное при светлой ОС', (t) async {
    await t.pumpWidget(app(
      kDColorsDark,
      Builder(
        builder: (ctx) => TextButton(
          onPressed: () => DesktopDialog.show<void>(
            ctx,
            title: 'Эмодзи-статус',
            body: const Text('тело окна'),
          ),
          child: const Text('открыть'),
        ),
      ),
    ));
    await t.tap(find.text('открыть'));
    await t.pumpAndSettle();
    expect(paletteAt(t, find.text('тело окна')), same(kDColorsDark));
  });

  testWidgets('всплывающее окно (эмодзи, GIF) тёмное при светлой ОС',
      (t) async {
    final anchor = GlobalKey();
    await t.pumpWidget(app(
      kDColorsDark,
      Builder(
        builder: (ctx) => TextButton(
          key: anchor,
          onPressed: () => DesktopPopover.show<void>(
            ctx,
            anchorKey: anchor,
            child: const Text('эмодзи'),
          ),
          child: const Text('открыть'),
        ),
      ),
    ));
    await t.tap(find.text('открыть'));
    await t.pumpAndSettle();
    expect(paletteAt(t, find.text('эмодзи')), same(kDColorsDark));
  });

  testWidgets('меню «+» тёмное при светлой ОС', (t) async {
    await t.pumpWidget(app(
      kDColorsDark,
      Builder(
        builder: (ctx) => TextButton(
          onPressed: () => ContextMenu.show(
            ctx,
            globalPosition: const Offset(40, 40),
            sections: [
              [CtxMenuItem(label: 'Файл', onTap: () {})],
            ],
          ),
          child: const Text('открыть'),
        ),
      ),
    ));
    await t.tap(find.text('открыть'));
    await t.pumpAndSettle();
    expect(paletteAt(t, find.text('Файл')), same(kDColorsDark));
  });

  testWidgets('плашка снизу тёмная при светлой ОС', (t) async {
    await t.pumpWidget(app(
      kDColorsDark,
      Builder(
        builder: (ctx) => TextButton(
          onPressed: () => DesktopSnackbar.show(ctx, message: 'готово'),
          child: const Text('открыть'),
        ),
      ),
    ));
    await t.tap(find.text('открыть'));
    await t.pump(const Duration(milliseconds: 300));
    expect(paletteAt(t, find.text('готово')), same(kDColorsDark));
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets(
      'меню из принудительно тёмного звонка тёмное и в СВЕТЛОЙ теме '
      'приложения', (t) async {
    // Звонок рисуется своей тёмной палитрой поверх светлого приложения. Меню
    // устройств открывается из звонка, но строится корневым навигатором — и
    // должно остаться тёмным, как звонок.
    await t.pumpWidget(app(
      kDColorsLight,
      DColors(
        colors: kDColorsDark,
        child: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => ContextMenu.show(
              ctx,
              globalPosition: const Offset(40, 40),
              sections: [
                [CtxMenuItem(label: 'Динамики', onTap: () {})],
              ],
            ),
            child: const Text('устройства'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('устройства'));
    await t.pumpAndSettle();
    expect(paletteAt(t, find.text('Динамики')), same(kDColorsDark));
  });

  test('тема Material собрана из палитры: окна не белые и одной формы', () {
    final theme = desktopMaterialTheme(kDColorsDark, dark: true);
    expect(theme.dialogTheme.backgroundColor, kDColorsDark.elevated);
    expect(theme.popupMenuTheme.color, kDColorsDark.elevated);
    expect(theme.snackBarTheme.backgroundColor, kDColorsDark.elevated);
    expect(theme.datePickerTheme.backgroundColor, kDColorsDark.elevated);
    expect(theme.canvasColor, kDColorsDark.elevated);
    expect(theme.colorScheme.surfaceContainerHigh, kDColorsDark.elevated,
        reason: 'AlertDialog берёт surfaceContainerHigh');
    final tip = theme.tooltipTheme.decoration as BoxDecoration;
    expect(tip.color, kDColorsDark.elevated,
        reason: 'подсказка Material в тёмной теме была белой');
    expect(theme.tooltipTheme.textStyle?.color, kDColorsDark.textPrimary);
  });

  test('🔴 в окне ПК палитра стоит в builder, над навигатором', () {
    final src = File('lib/ui/desktop/app/desktop_production_app.dart')
        .readAsStringSync();
    final builderAt = src.indexOf('builder: (ctx, child) => DColors(');
    expect(builderAt, greaterThan(0),
        reason: 'палитра должна оборачивать навигатор в MaterialApp.builder');
    expect(src.indexOf('home:', builderAt), greaterThan(builderAt));
    expect(src.contains('theme: desktopMaterialTheme(colors'), isTrue);
  });

  test('🔴 все окна-примитивы несут палитру места вызова', () {
    for (final path in [
      'lib/ui/desktop/primitives/desktop_dialog.dart',
      'lib/ui/desktop/primitives/desktop_popover.dart',
      'lib/ui/desktop/primitives/context_menu.dart',
      'lib/ui/desktop/primitives/desktop_snackbar.dart',
      'lib/ui/desktop/chat/reactions_popover.dart',
      'lib/ui/desktop/calls/incoming_call_toast.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('DColors.maybeOf(context)'), isTrue, reason: path);
      expect(src.contains('DColors.carry('), isTrue, reason: path);
    }
  });
}
