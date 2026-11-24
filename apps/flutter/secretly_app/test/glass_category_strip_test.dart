// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Полоса категорий во всю ширину (план стекла, 23.11.2026).

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/glass/glass_category_strip.dart';
import 'package:secretly_app/ui/glass/glass_strip_layout.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];

/// Настоящие шрифты приложения: у шрифта проверок по умолчанию каждая буква
/// шириной в кегль, и подписи выходили бы вдвое шире настоящих.
Future<void> _loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>)) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);
  group('раскладка', () {
    test('две папки — ровно две половины', () {
      final l = computeGlassStripLayout(available: 340, natural: [80, 120]);
      expect(l.mode, GlassStripMode.equal);
      expect(l.widths, [170, 170]);
      expect(l.lefts, [0, 170]);
      expect(l.contentWidth, 340);
    });

    test('один длинный — по содержимому, но всё равно во всю ширину', () {
      final l = computeGlassStripLayout(
        available: 340,
        natural: [60, 60, 200],
      );
      expect(l.mode, GlassStripMode.content);
      expect(l.widths.fold<double>(0, (a, b) => a + b), closeTo(340, 1e-9));
      expect(l.widths[2], greaterThan(l.widths[0]));
    });

    test('не влезает — прокрутка, пункты по содержимому', () {
      final l = computeGlassStripLayout(
        available: 340,
        natural: List<double>.filled(8, 90),
      );
      expect(l.mode, GlassStripMode.scroll);
      expect(l.contentWidth, 720);
    });

    test('капля: на целых — ровно пункт, посередине — тянется на оба', () {
      final l = computeGlassStripLayout(available: 300, natural: [50, 50, 50]);
      final at1 = glassThumbRect(layout: l, p: 1, top: 0, height: 34);
      expect(at1.left, closeTo(100, 1e-9));
      expect(at1.right, closeTo(200, 1e-9));
      final mid = glassThumbRect(layout: l, p: 0.5, top: 0, height: 34);
      expect(mid.width, greaterThan(100), reason: 'вытянута');
      expect(mid.left, lessThan(50));
      expect(mid.right, greaterThan(150));
      expect(mid.height, lessThan(34), reason: 'сплющена по ходу');
      final flat = glassThumbRect(
        layout: l,
        p: 0.5,
        top: 0,
        height: 34,
        stretch: false,
      );
      expect(flat.width, closeTo(100, 1e-9), reason: '«Уменьшение движения»');
    });
  });

  Widget host(Widget strip, {double width = 375, TextScaler? scaler}) =>
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Inter'),
        home: Scaffold(
          backgroundColor: const Color(0xFF15171E),
          body: Builder(
            builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: scaler ?? TextScaler.noScaling,
            ),
            child: Center(
              child: SizedBox(
                width: width,
                child: RepaintBoundary(child: strip),
              ),
            ),
          ),
          ),
        ),
      );

  GlassCategoryStripState stateOf(WidgetTester t) =>
      t.state<GlassCategoryStripState>(find.byType(GlassCategoryStrip));

  testWidgets('две папки: пластина во всю ширину, капля на половину', (
    t,
  ) async {
    var selected = 0;
    final taps = <int>[];
    final longs = <int>[];
    await t.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, set) => GlassCategoryStrip(
            items: const [
              GlassStripItem(label: 'Все'),
              GlassStripItem(label: 'Работа', badge: 3),
            ],
            selected: selected,
            onSelect: (i) {
              taps.add(i);
              set(() => selected = i);
            },
            onLongPress: longs.add,
          ),
        ),
      ),
    );
    final strip = t.getSize(find.byType(GlassCategoryStrip));
    expect(strip.width, 375);
    final layout = stateOf(t).debugLayout!;
    expect(layout.mode, GlassStripMode.equal);
    expect(layout.widths[0], closeTo(layout.widths[1], 1e-9));
    // Долгое нажатие на ВЫБРАННОМ (под каплей) — меню всё равно открывается.
    await t.longPress(find.text('Все').first);
    expect(longs, [0]);
    // Нажатие — капля переливается пружиной.
    await t.tap(find.text('Работа').first);
    expect(taps, [1]);
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    final mid = stateOf(t).thumbPosition;
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    await t.pumpAndSettle();
    expect(stateOf(t).thumbPosition, closeTo(1, 0.01));
  });

  testWidgets('каплю можно вести пальцем', (t) async {
    var selected = 0;
    await t.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, set) => GlassCategoryStrip(
            items: const [
              GlassStripItem(label: 'Фото'),
              GlassStripItem(label: 'Видео'),
              GlassStripItem(label: 'Файлы'),
              GlassStripItem(label: 'Музыка'),
            ],
            selected: selected,
            onSelect: (i) => set(() => selected = i),
          ),
        ),
      ),
    );
    final start = t.getCenter(find.text('Фото').first);
    final g = await t.startGesture(start);
    await g.moveBy(const Offset(30, 0));
    await g.moveBy(const Offset(150, 0));
    await t.pump();
    expect(stateOf(t).thumbPosition, greaterThan(1));
    await g.up();
    await t.pumpAndSettle();
    expect(selected, 2);
    expect(stateOf(t).thumbPosition, closeTo(2, 0.01));
  });

  testWidgets('внешняя позиция (свайп страницы) — капля идёт за ней', (
    t,
  ) async {
    final page = ValueNotifier<double>(0);
    await t.pumpWidget(
      host(
        GlassCategoryStrip(
          items: const [
            GlassStripItem(label: 'Личное'),
            GlassStripItem(label: 'Архив'),
          ],
          selected: 0,
          position: page,
          onSelect: (_) {},
        ),
      ),
    );
    page.value = 0.4;
    await t.pump();
    expect(stateOf(t).thumbPosition, closeTo(0.4, 1e-9));
  });

  testWidgets('много тем + закрытая ветка: прокрутка, капля к ветке не едет', (
    t,
  ) async {
    final taps = <int>[];
    await t.pumpWidget(
      host(
        GlassCategoryStrip(
          items: [
            for (var i = 0; i < 9; i++) GlassStripItem(label: 'Тема номер $i'),
            const GlassStripItem(
              label: 'Закрытая',
              icon: Icons.lock_rounded,
              action: true,
            ),
          ],
          selected: 0,
          onSelect: taps.add,
        ),
      ),
    );
    expect(stateOf(t).debugLayout!.mode, GlassStripMode.scroll);
    expect(t.takeException(), isNull);
  });

  testWidgets('узкий экран и крупный шрифт — ничего не вылезает', (t) async {
    for (final w in const [320.0, 375.0, 430.0]) {
      for (final s in const [1.0, 1.35]) {
        await t.pumpWidget(
          host(
            GlassCategoryStrip(
              items: const [
                GlassStripItem(label: 'Wiederherstellen'),
                GlassStripItem(label: 'Archiviert', badge: 128),
                GlassStripItem(label: 'Arbeit'),
              ],
              selected: 1,
              onSelect: (_) {},
            ),
            width: w,
            scaler: TextScaler.linear(s),
          ),
        );
        expect(t.takeException(), isNull, reason: '$w ×$s');
        expect(t.getSize(find.byType(GlassCategoryStrip)).width, w);
      }
    }
  });

  testWidgets('снимки (SECRETLY_SHOTS)', (t) async {
    final dir = _shots;
    if (dir == null) return;
    final key = GlobalKey();
    var n = 0;
    for (final items in const [
      ['Все', 'Работа'],
      ['Фото', 'Видео', 'Файлы', 'Музыка'],
      ['Все', 'Работа', 'Семья', 'Друзья', 'Проекты', 'Учёба'],
    ]) {
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Inter'),
          home: Scaffold(
            backgroundColor: const Color(0xFF1A2230),
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: Container(
                  color: const Color(0xFF1A2230),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: GlassCategoryStrip(
                    items: [for (final l in items) GlassStripItem(label: l)],
                    selected: 1,
                    onSelect: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await t.runAsync(() => b.toImage(pixelRatio: 2));
      final bytes = await t.runAsync(
        () => img!.toByteData(format: ui.ImageByteFormat.png),
      );
      File('$dir/strip_${n++}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    }
  });

  testWidgets('🔴 ползунок без цвета темы — общий тёмный, как у нижней панели', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'Inter',
          colorScheme: const ColorScheme.dark(primary: Color(0xFF8B5CF6)),
        ),
        home: Scaffold(
          body: GlassCategoryStrip(
            items: const [GlassStripItem(label: 'Все'), GlassStripItem(label: 'Дом')],
            selected: 0,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    final pills = t
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == const Color(0x73303030));
    expect(pills, isNotEmpty, reason: 'ползунок — тёмно-серый');
    final tinted = t
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color?.toARGB32() == const Color(0xFF8B5CF6).withValues(alpha: 0.20).toARGB32());
    expect(tinted, isEmpty, reason: 'без заливки цветом темы');
  });
}
