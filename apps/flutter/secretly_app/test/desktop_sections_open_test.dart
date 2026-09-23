// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 КАЖДЫЙ РАЗДЕЛ ОКНА ОТКРЫВАЕТСЯ, А НЕ ТОЛЬКО ЧИСЛИТСЯ В РЕЙКЕ.
//
// 🔴 ЗАЧЕМ. На компьютере падение при отрисовке выглядит НЕ как падение:
// `_installDesktopErrorGuard` в `main_desktop.dart` гасит красное полотно, и
// человек видит просто пустую правую половину окна — неотличимо от «здесь пока
// ничего нет». На этом уже теряли день (см. шапку
// `desktop_settings_sections_render_test.dart`), и для настроек такая проверка
// с тех пор есть.
//
// Для ЧЕТЫРЁХ ГЛАВНЫХ разделов её не было вовсе: существовала лишь сверка
// текста исходника («в файле написано `DesktopCallsSection(vm: vm …)`»), а она
// не отличает работающий раздел от падающего.
//
// Модель окна живая, но профиля нет — это самая хрупкая ветка: данных ещё нет,
// и именно в ней раздел обычно и разваливается.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/app/desktop_app_view_model.dart';
import 'package:secretly_app/ui/desktop/app/desktop_calls_section.dart';
import 'package:secretly_app/ui/desktop/app/desktop_chats_section.dart';
import 'package:secretly_app/ui/desktop/app/desktop_contacts_section.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/shell/desktop_shell.dart';
import 'package:secretly_app/ui/desktop/shell/sidebar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DesktopAppViewModel vm;

  setUp(() => vm = DesktopAppViewModel(controller: AppController()));
  tearDown(() => vm.dispose());

  DesktopShellApi api() => DesktopShellApi(
    detailsOpen: false,
    toggleDetails: () {},
    openDetails: () {},
    closeDetails: () {},
    selectSection: (_) {},
    listWidth: 320,
    onListResize: (_) {},
    findRequests: ValueNotifier<int>(0),
    chatCycle: ValueNotifier<int>(0),
  );

  Widget host(Widget child) => MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DColors(colors: kDColorsDark, child: Scaffold(body: child)),
  );

  Future<void> opens(WidgetTester t, String name, Widget section) async {
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(host(section));
    await t.pump(const Duration(milliseconds: 300));
    expect(
      t.takeException(),
      isNull,
      reason: '$name не отрисовался — в живом окне это выглядело бы пустотой',
    );
  }

  testWidgets('раздел «Чаты» открывается', (t) async {
    await opens(t, 'Чаты', DesktopChatsSection(vm: vm, shellApi: api()));
  });

  testWidgets('раздел «Комнаты» открывается', (t) async {
    await opens(
      t,
      'Комнаты',
      DesktopChatsSection(
        vm: vm,
        shellApi: api(),
        filter: ConversationFilter.groups,
      ),
    );
  });

  testWidgets('раздел «Звонки» открывается', (t) async {
    await opens(t, 'Звонки', DesktopCallsSection(vm: vm, shellApi: api()));
  });

  testWidgets('раздел «Контакты» открывается', (t) async {
    await opens(t, 'Контакты', DesktopContactsSection(vm: vm, shellApi: api()));
  });

  testWidgets('рейка показывает ровно четыре раздела', (t) async {
    // Число стоит нарочно: если раздел добавят или уберут, проверка заставит
    // подумать, а не молча проверит меньше.
    expect(DesktopSection.values, hasLength(4));
  });
}
