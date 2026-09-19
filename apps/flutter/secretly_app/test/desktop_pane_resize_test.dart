// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 ЛЕВАЯ ПАНЕЛЬ ТЯНЕТСЯ, КАК В ТЕЛЕГРАМЕ.
//
// Указание владельца 16.09.2026 со скриншотами узкой и растянутой левой
// панели телеграма: «в телеграме левая панель регулируется по размеру как и
// правая, а у нас только правая и то не сильно».
//
// ЧТО БЫЛО НЕ ТАК.
//   1. Край списка НЕ ТЯНУЛСЯ ВОВСЕ — с самого появления (07.08). Ручку
//      поставили в СТОЛБЕЦ над списком и перепиской, где у неё не было
//      высоты, а между колонками стояла обычная линия.
//   2. Потолок списка был 720 «на вкус», панели — 520. В телеграме список
//      растягивается почти на всё окно, и превью читается целиком.
//   3. Шаг перетаскивания прибавлялся к СОХРАНЁННОЙ ширине. Когда открытая
//      правая панель сжимала список, сохранённая была больше видимой, и край
//      не двигался.
//   4. Потолок списка считался от всего окна, без рейки: переписка могла уйти
//      под свой пол на ширину рейки.
//   5. «Звонки» и «Контакты» держали свою неподвижную колонку в 320 точек.

import 'dart:io';

import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/shell/desktop_shell.dart';
import 'package:secretly_app/ui/desktop/shell/details_panel.dart';
import 'package:secretly_app/ui/desktop/shell/list_thread_split.dart';
import 'package:secretly_app/ui/desktop/shell/pane_widths.dart';
import 'package:secretly_app/ui/desktop/shell/resizable_divider.dart';
import 'package:secretly_app/ui/desktop/shell/sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rail = kRailWidth;
const _floor = 460.0;
const _minList = 260.0;
const _minDetails = 260.0;

void main() {
  group('арифметика края списка', () {
    ListDragResult drag(double dx, {double shown = 322, double? details}) =>
        dragListEdge(
          dx: dx,
          shownList: shown,
          available: 1600,
          rail: _rail,
          threadFloor: _floor,
          minList: _minList,
          desiredDetails: details,
          minDetails: _minDetails,
        );

    test('тянется вправо и влево на столько, на сколько тянут', () {
      expect(drag(300).listWidth, 622);
      expect(drag(-40).listWidth, 282);
      expect(drag(300).detailsWidth, isNull, reason: 'панель закрыта');
    });

    test('🔴 потолка «на вкус» нет — предел ставит пол переписки', () {
      // Было 720. Теперь — всё окно без рейки и пола переписки.
      expect(drag(5000).listWidth, 1600 - _rail - _floor);
      expect(drag(5000).listWidth, greaterThan(720));
    });

    test('ниже минимума не сужается', () {
      expect(drag(-5000).listWidth, _minList);
    });

    test('🔴 шаг считается от ВИДИМОЙ ширины', () {
      // Панель сжала список до 300, хотя сохранено 600: шаг в +50 обязан дать
      // 350, а не 650 (которые тут же снова ужались бы до 300).
      expect(drag(50, shown: 300, details: 330).listWidth, 350);
    });

    test('🔴 открытая панель уступает растущему списку — до своего минимума', () {
      // 1600 − 66 − 460 = 1074 на список и панель вместе.
      final r = drag(700, details: 330); // список 1022 → панели остаётся 52
      expect(r.listWidth, 1074 - _minDetails, reason: 'список упёрся');
      expect(r.detailsWidth, _minDetails);
      expect(1600 - _rail - r.listWidth - r.detailsWidth!, _floor);
    });

    test('сужаемый список возвращает панели желаемую ширину', () {
      final r = drag(-200, shown: 700, details: 330);
      expect(r.listWidth, 500);
      expect(r.detailsWidth, 330);
    });
  });

  group('арифметика края правой панели', () {
    double drag(double dx, {double shown = 330, double available = 1600}) =>
        dragDetailsEdge(
          dx: dx,
          shownDetails: shown,
          available: available,
          rail: _rail,
          threadFloor: _floor,
          minList: _minList,
          minDetails: _minDetails,
          maxDetails: 720,
        );

    test('влево — шире, вправо — уже', () {
      expect(drag(-100), 430);
      expect(drag(50), 280);
    });

    test('🔴 шире 520 — можно, до 720', () {
      expect(drag(-300), 630);
      expect(drag(-5000), 720);
    });

    test('ниже минимума не сужается', () {
      expect(drag(5000), _minDetails);
    });

    test('на узком окне потолок ставит пол переписки и минимум списка', () {
      // 1200 − 66 − 460 − 260 = 414.
      expect(drag(-5000, available: 1200), 414);
    });
  });

  group('шов «список | переписка»', () {
    Widget host({
      required ValueChanged<double> onResize,
      VoidCallback? onReset,
    }) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: ListThreadSplit(
            listWidth: 300,
            onResize: onResize,
            onReset: onReset,
            list: const ColoredBox(color: Colors.black),
            thread: const ColoredBox(color: Colors.grey),
          ),
        ),
      ),
    );

    testWidgets('🔴 ручка стоит НА ШВЕ и ловит перетаскивание', (t) async {
      final deltas = <double>[];
      await t.pumpWidget(host(onResize: deltas.add));

      final handle = t.getRect(find.byType(ResizableDivider));
      expect(handle.height, greaterThan(100), reason: 'ручка без высоты');
      expect(handle.left, lessThanOrEqualTo(300));
      expect(handle.right, greaterThan(301));

      await t.dragFrom(const Offset(301, 200), const Offset(150, 0));
      await t.pump();
      expect(deltas, isNotEmpty);
      // Отсчёт от точки нажатия: край идёт за курсором без отставания на
      // порог распознавания жеста.
      expect(deltas.reduce((a, b) => a + b), closeTo(150, 0.5));
    });

    testWidgets('ручка почти не заходит на список — там полоса прокрутки', (
      t,
    ) async {
      await t.pumpWidget(host(onResize: (_) {}));
      final handle = t.getRect(find.byType(ResizableDivider));
      expect(300 - handle.left, lessThanOrEqualTo(1));
    });

    testWidgets('двойной щелчок по шву — ширина по умолчанию', (t) async {
      var resets = 0;
      await t.pumpWidget(host(onResize: (_) {}, onReset: () => resets++));
      await t.tapAt(const Offset(301, 200));
      await t.pump(const Duration(milliseconds: 40));
      await t.tapAt(const Offset(301, 200));
      await t.pumpAndSettle();
      expect(resets, 1);
    });
  });

  group('оболочка целиком', () {
    late DesktopShellApi api;

    Future<void> pumpShell(WidgetTester t) async {
      t.view.physicalSize = const Size(1600, 1000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DColors(
            colors: kDColorsDark,
            child: DesktopShell(
              sidebarBuilder: (ctx, active, onSelect) =>
                  const SizedBox(width: kRailWidth),
              contentBuilder: (ctx, section, a) {
                api = a;
                return ListThreadSplit.fromApi(
                  a,
                  list: const ColoredBox(
                    key: ValueKey('list'),
                    color: Colors.black,
                  ),
                  thread: const ColoredBox(
                    key: ValueKey('thread'),
                    color: Colors.grey,
                  ),
                );
              },
              detailsBuilder: (ctx, section, a) => const ColoredBox(
                key: ValueKey('details'),
                color: Colors.blueGrey,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    double listW(WidgetTester t) =>
        t.getSize(find.byKey(const ValueKey('list'))).width;
    double threadW(WidgetTester t) =>
        t.getSize(find.byKey(const ValueKey('thread'))).width;
    double detailsW(WidgetTester t) =>
        t.getSize(find.byType(DetailsPanel)).width;
    Offset seam(WidgetTester t) => Offset(
      t.getRect(find.byKey(const ValueKey('list'))).right + 1,
      500,
    );

    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('🔴 край списка тянется на всю ширину, до пола переписки', (
      t,
    ) async {
      await pumpShell(t);
      expect(listW(t), 322, reason: 'ширина по умолчанию');

      await t.dragFrom(seam(t), const Offset(500, 0));
      await t.pumpAndSettle();
      expect(listW(t), closeTo(822, 2));

      await t.dragFrom(seam(t), const Offset(3000, 0));
      await t.pumpAndSettle();
      // Рейка, шов в точку — и ровно пол переписки.
      expect(listW(t), closeTo(1600 - kRailWidth - 1 - _floor, 0.5));
      expect(threadW(t), closeTo(_floor, 0.5));

      // Курсор отпущен левее минимума, но правее порога сворачивания (168):
      // край стоит на минимуме. Дальше порога список сворачивается в столбик —
      // см. desktop_list_compact_test.dart.
      await t.dragFrom(seam(t), Offset(200 - listW(t), 0));
      await t.pumpAndSettle();
      expect(listW(t), _minList);
    });

    testWidgets('ширина сохраняется, двойной щелчок её сбрасывает', (t) async {
      await pumpShell(t);
      await t.dragFrom(seam(t), const Offset(200, 0));
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 500));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('desktop_pane_list_w_v1'), closeTo(522, 2));

      final at = seam(t);
      await t.tapAt(at);
      await t.pump(const Duration(milliseconds: 40));
      await t.tapAt(at);
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 500));
      expect(listW(t), 322);
      expect(prefs.getDouble('desktop_pane_list_w_v1'), isNull);
    });

    testWidgets('🔴 при открытой панели край списка всё равно тянется', (
      t,
    ) async {
      await pumpShell(t);
      api.openDetails();
      await t.pumpAndSettle();
      final before = listW(t);

      await t.dragFrom(seam(t), const Offset(400, 0));
      await t.pumpAndSettle();
      expect(listW(t), greaterThan(before + 300));
      // Переписка при этом не уходит под свой пол: место отдала панель.
      expect(threadW(t), greaterThanOrEqualTo(_floor - 0.5));
      await t.dragFrom(seam(t), const Offset(3000, 0));
      await t.pumpAndSettle();
      expect(threadW(t), closeTo(_floor, 0.5));
      expect(detailsW(t), closeTo(_minDetails, 0.5), reason: 'панель потеснена');

      // 🔴 Сузили список — панель вернулась к ширине, которую выбрал человек,
      // а не осталась потеснённой.
      await t.dragFrom(seam(t), Offset(200 - listW(t), 0));
      await t.pumpAndSettle();
      expect(listW(t), _minList);
      expect(detailsW(t), closeTo(330, 0.5));

      // Сохраняется выбранная ширина, а не потеснённая.
      await t.pump(const Duration(milliseconds: 500));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('desktop_pane_details_w_v1'), 330);
    });
  });

  group('правила разделов', () {
    final chats = File(
      'lib/ui/desktop/app/desktop_chats_section.dart',
    ).readAsStringSync();

    test('🔴 в разделе чатов ручка — на шве, а не в столбце над ним', () {
      // Через оболочку целиком: ширина, шаг, сброс, начало и конец жеста.
      expect(chats.contains('ListThreadSplit.fromApi('), isTrue);
      expect(
        chats.contains('ResizableDivider(onDelta: widget.shellApi.onListResize)'),
        isFalse,
      );
    });

    test('«Звонки» и «Контакты» делят ту же левую колонку', () {
      for (final path in [
        'lib/ui/desktop/app/desktop_calls_section.dart',
        'lib/ui/desktop/app/desktop_contacts_section.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('ListThreadSplit.fromApi('), isTrue, reason: path);
      }
      final app = File(
        'lib/ui/desktop/app/desktop_production_app.dart',
      ).readAsStringSync();
      expect(app.contains('DesktopCallsSection(vm: vm, shellApi: api)'), isTrue);
      expect(app.contains('shellApi: api,'), isTrue);
    });
  });
}
