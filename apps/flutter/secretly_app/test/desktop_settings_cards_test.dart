// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Карточки и выбор в настройках ПК (30.09.2026).
//
// Сверка всех 17 разделов со снимками нашла: у «О программе», «Удалить
// аккаунт» и «Поддержки» текст и поле ввода прилипали к краям рамки, а между
// ними шли черты, как между строками; строки с телефонным `DropdownButton`
// были на треть выше соседних; в «Сессиях» человеку показывалось
// «Bad state: …».

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/design/material_theme.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/workspace/settings_workspace.dart';
import 'package:secretly_app/ui/desktop/workspace/workspace_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: desktopMaterialTheme(kDColorsDark, dark: true),
  home: DColors(
    colors: kDColorsDark,
    child: Scaffold(body: child),
  ),
);

/// Черты между строками карточки — контейнеры высотой ровно 1.
Iterable<Container> _hairlines(WidgetTester t) => t
    .widgetList<Container>(find.byType(Container))
    .where((c) => c.constraints?.maxHeight == 1 && c.constraints?.minHeight == 1);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DesktopUiPrefs.resetForTest();
  });

  test('в настройках нет телефонного DropdownButton', () {
    for (final path in [
      'lib/ui/desktop/workspace/settings_workspace.dart',
      'lib/ui/desktop/workspace/appearance_pane.dart',
      'lib/ui/desktop/workspace/media_devices_pane.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(
        src.contains('DropdownButton<'),
        isFalse,
        reason: '$path: выбор в строке настроек — WorkspaceSelect',
      );
    }
  });

  testWidgets('свободная карточка: поля есть, черт нет', (t) async {
    await t.pumpWidget(
      _host(
        const Center(
          child: SizedBox(
            width: 500,
            child: WorkspaceCard(
              rows: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('первая', key: ValueKey('a')),
                  SizedBox(height: 8),
                  Text('вторая', key: ValueKey('b')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(_hairlines(t), isEmpty);
    final card = t.getRect(find.byType(WorkspaceCard));
    final first = t.getRect(find.byKey(const ValueKey('a')));
    expect(first.left - card.left, greaterThanOrEqualTo(14));
  });

  testWidgets('карточка строк по-прежнему ставит черты', (t) async {
    await t.pumpWidget(
      _host(
        const Center(
          child: SizedBox(
            width: 500,
            child: WorkspaceCard(
              child: Column(
                children: [
                  WorkspaceRow(label: 'раз'),
                  WorkspaceRow(label: 'два'),
                  WorkspaceRow(label: 'три'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(_hairlines(t).length, 2);
  });

  testWidgets('выбор: значение, меню с галочкой, смена', (t) async {
    String? picked;
    await t.pumpWidget(
      _host(
        Center(
          child: SizedBox(
            width: 500,
            child: WorkspaceCard(
              child: WorkspaceRow(
                label: 'Кто видит',
                trailing: WorkspaceSelect<String>(
                  value: 'contacts',
                  values: const ['nobody', 'contacts', 'everyone'],
                  labelOf: (v) => switch (v) {
                    'nobody' => 'Никто',
                    'contacts' => 'Контакты',
                    _ => 'Все',
                  },
                  onChanged: (v) => picked = v,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Строка с выбором — той же высоты, что и прочие (не 72, как с
    // телефонным списком).
    expect(t.getSize(find.byType(WorkspaceRow)).height, lessThan(60));
    expect(find.text('Никто'), findsNothing);

    await t.tap(find.text('Контакты'));
    await t.pumpAndSettle();
    expect(find.text('Никто'), findsOneWidget);
    expect(find.text('Все'), findsOneWidget);

    await t.tap(find.text('Все'));
    await t.pumpAndSettle();
    expect(picked, 'everyone');
    expect(find.text('Никто'), findsNothing);
  });

  testWidgets('выбор без обработчика меню не открывает', (t) async {
    await t.pumpWidget(
      _host(
        Center(
          child: WorkspaceSelect<int>(
            value: 1,
            values: const [0, 1, 2],
            labelOf: (v) => 'значение $v',
            onChanged: null,
          ),
        ),
      ),
    );
    await t.tap(find.text('значение 1'));
    await t.pumpAndSettle();
    expect(find.text('значение 0'), findsNothing);
  });

  testWidgets('«Сессии»: ошибка без «Bad state»', (t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final vm = DesktopAppViewModel(controller: AppController());
    addTearDown(vm.dispose);
    await t.pumpWidget(
      _host(SettingsWorkspace(vm: vm, initialSectionId: 'devices')),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Bad state'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
