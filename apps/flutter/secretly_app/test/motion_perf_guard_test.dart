// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// М7: сторожа производительности движения.
// * Анимации нажатия, перестановки строк и появления плашек НЕ
//   перестраивают содержимое — двигается только Transform/Opacity.
// * Сводка счётчика кадров считает бюджет экрана верно.
// * «Фотограф»: `SECRETLY_SHOTS=папка` снимает середину анимаций (меню,
//   окно, новая строка списка) — для глазной проверки.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/ui/chat_wallpapers.dart' show chatWallpaperDecodeWidth;
import 'package:secretly_app/ui/motion/app_dialogs.dart';
import 'package:secretly_app/ui/motion/entrance.dart';
import 'package:secretly_app/ui/motion/frame_stats.dart';
import 'package:secretly_app/ui/motion/list_motion.dart';
import 'package:secretly_app/ui/motion/press_feedback.dart';
import 'package:secretly_app/ui/animations/page_transitions.dart';
import 'package:secretly_app/ui/widgets/apple_menu.dart';
import 'package:secretly_app/ui/widgets/covered_route_media_freeze.dart';
import 'package:secretly_app/ui/widgets/telegram_wallpaper.dart';

final String? _shots = Platform.environment['SECRETLY_SHOTS'];
final GlobalKey _shotKey = GlobalKey();

Future<void> _shoot(WidgetTester t, String name) async {
  final dir = _shots;
  if (dir == null || dir.isEmpty) return;
  await t.runAsync(() async {
    final b =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Считает, сколько раз его перестроили.
class _Counted extends StatelessWidget {
  const _Counted(this.counter, {this.height = 60, this.label = ''});
  final List<int> counter;
  final double height;
  final String label;
  @override
  Widget build(BuildContext context) {
    counter[0]++;
    return SizedBox(height: height, child: Text(label));
  }
}

Widget _app(Widget home) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Inter'),
  builder: (context, child) => RepaintBoundary(key: _shotKey, child: child),
  home: home,
);

ui.FrameTiming _frame(int buildUs, int rasterUs) => ui.FrameTiming(
  vsyncStart: 0,
  buildStart: 0,
  buildFinish: buildUs,
  rasterStart: buildUs,
  rasterFinish: buildUs + rasterUs,
  rasterFinishWallTime: buildUs + rasterUs,
);

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
  testWidgets('🔴 нажатие не перестраивает кнопку', (t) async {
    final n = [0];
    await t.pumpWidget(
      _app(
        Scaffold(
          body: Center(
            child: PressFeedback(
              child: GestureDetector(onTap: () {}, child: _Counted(n)),
            ),
          ),
        ),
      ),
    );
    final before = n[0];
    final g = await t.startGesture(t.getCenter(find.byType(_Counted)));
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await t.pumpAndSettle();
    expect(n[0], before);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('🔴 перестановка строк: каждая строка строится один раз', (
    t,
  ) async {
    final ctrl = ListMotionController();
    final counts = <String, List<int>>{
      for (final id in ['a', 'b', 'c', 'd']) id: [0],
    };
    Widget list(List<String> ids) {
      ctrl.update(ids);
      return _app(
        ListView.builder(
          itemCount: ids.length,
          findChildIndexCallback: (k) =>
              k is ValueKey<String> ? ctrl.indexOf(k.value) : null,
          itemBuilder: (_, i) => ListMotionItem(
            key: ValueKey<String>(ids[i]),
            controller: ctrl,
            id: ids[i],
            child: _Counted(counts[ids[i]]!, label: ids[i]),
          ),
        ),
      );
    }

    await t.pumpWidget(list(const ['a', 'b', 'c', 'd']));
    await t.pumpWidget(list(const ['d', 'a', 'b', 'c']));
    final afterReorder = {for (final e in counts.entries) e.key: e.value[0]};
    await t.pump(const Duration(milliseconds: 100));
    await _shoot(t, 'mid_list_move');
    await t.pumpAndSettle();
    // Во время переезда (≈ 24 кадра) содержимое строк не строилось ни разу.
    for (final e in counts.entries) {
      expect(e.value[0], afterReorder[e.key], reason: e.key);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('🔴 раскрытие плашки не перестраивает её содержимое', (t) async {
    final n = [0];
    var show = false;
    late StateSetter set;
    await t.pumpWidget(
      _app(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, s) {
              set = s;
              return Column(
                children: [
                  PlateReveal(
                    child: show ? _Counted(n, height: 80) : const SizedBox(),
                  ),
                  const Text('ниже'),
                ],
              );
            },
          ),
        ),
      ),
    );
    set(() => show = true);
    await t.pump();
    final built = n[0];
    await t.pump(const Duration(milliseconds: 150));
    final y = t.getTopLeft(find.text('ниже')).dy;
    expect(y, inExclusiveRange(0, 80));
    await t.pumpAndSettle();
    expect(n[0], built);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('сводка кадров: бюджет 120 Гц и 60 Гц', () {
    final frames = [
      for (var i = 0; i < 98; i++) _frame(4000, 5000),
      _frame(12000, 3000),
      _frame(3000, 20000),
    ];
    final s120 = FrameStats.summarize(frames, refreshRate: 120);
    expect(s120, contains('frames=100'));
    expect(s120, contains('budget=8.3ms'));
    expect(s120, contains('over=1 |')); // сборка: один кадр 12 мс
    expect(s120, contains('max=20.0 over=1')); // растр: один кадр 20 мс
    final s60 = FrameStats.summarize(frames, refreshRate: 60);
    expect(s60, contains('budget=16.7ms'));
    expect(s60, contains('over=0 |'));
  });

  test('частота экрана — по самим кадрам, а не по значению при старте', () {
    ui.FrameTiming at(int vsync) => ui.FrameTiming(
      vsyncStart: vsync,
      buildStart: vsync,
      buildFinish: vsync + 1000,
      rasterStart: vsync + 1000,
      rasterFinish: vsync + 6000,
      rasterFinishWallTime: vsync + 6000,
    );
    final at120 = [for (var i = 0; i < 60; i++) at(i * 8333)];
    expect(FrameStats.measuredRefreshRate(at120), 120);
    final at60 = [for (var i = 0; i < 60; i++) at(i * 16667)];
    expect(FrameStats.measuredRefreshRate(at60), 60);
    // Покой: редкие кадры — не судим.
    final idle = [for (var i = 0; i < 5; i++) at(i * 500000)];
    expect(FrameStats.measuredRefreshRate(idle), isNull);
  });

  testWidgets('фотограф: середина раскрытия меню и окна (iPhone)', (t) async {
    t.view.physicalSize = const Size(393, 852) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    late BuildContext ctx;
    await t.pumpWidget(
      _app(
        Scaffold(
          backgroundColor: const Color(0xFF1C1C1E),
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    showAppleMenu<void>(
      context: ctx,
      anchor: const Rect.fromLTWH(340, 60, 44, 44),
      children: [
        AppleMenuRow(title: 'Без звука', icon: Icons.notifications_off, onTap: () {}),
        AppleMenuRow(title: 'Удалить', destructive: true, separator: false, onTap: () {}),
      ],
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 110));
    expect(t.takeException(), isNull);
    await _shoot(t, 'mid_menu');
    await t.pumpAndSettle();
    Navigator.of(ctx, rootNavigator: true).pop();
    await t.pumpAndSettle();
    showAppDialog<void>(
      context: ctx,
      builder: (_) => const AlertDialog(title: Text('Удалить чат?')),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 90));
    await _shoot(t, 'mid_dialog');
    await t.pumpAndSettle();
    expect(find.text('Удалить чат?'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('🔴 клавиатура не перестраивает тех, кто считает размер обоев', (
    t,
  ) async {
    _WallpaperProbe.builds = 0;
    Widget app(double inset) => MediaQuery(
      data: MediaQueryData(
        size: const Size(393, 852),
        devicePixelRatio: 3,
        viewInsets: EdgeInsets.only(bottom: inset),
      ),
      child: const _WallpaperProbe(),
    );
    await t.pumpWidget(app(0));
    expect(_WallpaperProbe.builds, 1);
    for (final inset in [40.0, 120.0, 260.0, 300.0]) {
      await t.pumpWidget(app(inset));
    }
    // Зависимость от всего MediaQuery дала бы ещё 4 сборки.
    expect(_WallpaperProbe.builds, 1);
  });

  test('🔴 тема приложения не зависит от кадров клавиатуры', () {
    // Тема со всплывашками считалась из MediaQuery в корне приложения —
    // каждый кадр клавиатуры давал новую тему и перестраивал всё, что берёт
    // из неё цвета (20.11.2026, запись кадров Xiaomi).
    final src = File('lib/main.dart').readAsStringSync();
    expect(src.contains('_KeyboardSettledSnackTheme('), isTrue);
    final themeInBuilder = RegExp(
      r'Theme\(\s*data:\s*Theme\.of\(context\)\.copyWith\(\s*snackBarTheme',
    );
    expect(themeInBuilder.hasMatch(src), isFalse,
        reason: 'отступ всплывашек снова вшит в тему в каждом кадре');
  });

  for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('🔴 страница под чатом не перестраивается от клавиатуры ($p)', (
      t,
    ) async {
      _MediaProbe.builds = 0;
      final nav = GlobalKey<NavigatorState>();
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: const CoveredRouteMediaFreeze(child: _MediaProbe()),
        ),
      );
      await t.pumpAndSettle();
      nav.currentState!.push(
        SecretlyPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await t.pumpAndSettle();
      final settled = _MediaProbe.builds;
      // Кадры появления клавиатуры над верхней страницей.
      for (final inset in [60.0, 180.0, 300.0, 336.0]) {
        t.view.viewInsets = FakeViewPadding(bottom: inset * 3);
        await t.pump();
      }
      expect(_MediaProbe.builds, settled,
          reason: 'закрытая страница не должна знать о клавиатуре');
      t.view.resetViewInsets();
      await t.pump();
      // Возврат: заморозка снимается, страница снова живая.
      nav.currentState!.pop();
      await t.pumpAndSettle();
      final back = _MediaProbe.builds;
      t.view.viewInsets = const FakeViewPadding(bottom: 600);
      await t.pump();
      expect(_MediaProbe.builds, back + 1);
      t.view.resetViewInsets();
    }, variant: TargetPlatformVariant.only(p));
  }

  testWidgets('🔴 снимок MediaQuery в обработчике не подписывает экран', (
    t,
  ) async {
    _HandlerProbe.builds = 0;
    await t.pumpWidget(const MaterialApp(home: _HandlerProbe()));
    final state = t.state<_HandlerProbeState>(find.byType(_HandlerProbe));
    expect(state.readNow().size.width, greaterThan(0));
    for (final inset in [100.0, 200.0, 300.0]) {
      t.view.viewInsets = FakeViewPadding(bottom: inset * 3);
      await t.pump();
    }
    t.view.resetViewInsets();
    expect(_HandlerProbe.builds, 1);
  });

  testWidgets('🔴 непрерывные обои не просят кадров чаще 30 в секунду', (
    t,
  ) async {
    final key = GlobalKey<TelegramWallpaperState>();
    await t.pumpWidget(
      MaterialApp(
        home: TelegramWallpaper(
          key: key,
          mode: ChatWallpaperAnimMode.continuous,
        ),
      ),
    );
    final w = key.currentState!;
    final start = w.driftValue;
    final seen = <double>{};
    for (var ms = 0; ms < 1000; ms += 4) {
      await t.pump(const Duration(milliseconds: 4));
      seen.add(w.driftValue);
      // Тикер экрана просил бы кадр на КАЖДОМ кадре (120 в секунду).
      expect(w.driftOnScreenTicker, isFalse);
    }
    // За секунду ~30 шагов таймера, обои сдвинулись.
    expect(seen.length, inInclusiveRange(25, 35));
    expect(w.driftValue, isNot(start));
    await t.pumpWidget(const SizedBox());
  });
}

class _MediaProbe extends StatelessWidget {
  const _MediaProbe();
  static int builds = 0;
  @override
  Widget build(BuildContext context) {
    builds++;
    MediaQuery.of(context);
    return const SizedBox.expand();
  }
}

class _HandlerProbe extends StatefulWidget {
  const _HandlerProbe();
  static int builds = 0;
  @override
  State<_HandlerProbe> createState() => _HandlerProbeState();
}

class _HandlerProbeState extends State<_HandlerProbe> {
  MediaQueryData readNow() => mediaQueryNow(context);
  @override
  Widget build(BuildContext context) {
    _HandlerProbe.builds++;
    return const SizedBox();
  }
}

class _WallpaperProbe extends StatelessWidget {
  const _WallpaperProbe();
  static int builds = 0;
  @override
  Widget build(BuildContext context) {
    builds++;
    chatWallpaperDecodeWidth(context, preview: false);
    return const SizedBox();
  }
}
