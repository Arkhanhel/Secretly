// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Переделанные старые обложки (classic.dart): каждая сцена поднимается в обеих
// темах, переживает касание, перетаскивание, смену размера и неподвижный кадр.
// Заодно печатает цену кадра (запись + раскладка в тестовой среде, без GPU).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/profile_fx.dart';
import 'art_assets_availability.dart';

const _styles = [
  ProfileCoverStyle.classicSpace,
  ProfileCoverStyle.classicWaves,
  ProfileCoverStyle.classicMeteors,
  ProfileCoverStyle.classicMarks,
  ProfileCoverStyle.classicGoldHaze,
  ProfileCoverStyle.classicLogos,
  ProfileCoverStyle.classicFire,
  ProfileCoverStyle.classicFog,
  ProfileCoverStyle.classicBears,
  ProfileCoverStyle.classicRainbow,
  ProfileCoverStyle.classicFireflies,
  ProfileCoverStyle.classicFireworks,
  ProfileCoverStyle.classicGoldWillow,
  ProfileCoverStyle.classicReef,
  ProfileCoverStyle.classicGalaxy,
  ProfileCoverStyle.classicAuroraSky,
];

const _frame = Duration(milliseconds: 16);

Widget _host(Widget child, {required bool dark, double w = 390, double h = 220}) => MaterialApp(
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      home: Center(child: SizedBox(width: w, height: h, child: child)),
    );

Future<int> _timedPumps(WidgetTester tester, int n) async {
  final sw = Stopwatch()..start();
  for (var i = 0; i < n; i++) {
    await tester.pump(_frame);
  }
  sw.stop();
  return sw.elapsedMicroseconds ~/ n;
}

void main() {
  for (final dark in const [true, false]) {
    testWidgets('classic covers run without errors (${dark ? 'dark' : 'light'})', (tester) async {
      debugSeedProfileFxRandom(11);
      // Базовая цена кадра пустого виджета — вычитается из цены сцены.
      await tester.pumpWidget(_host(const ColoredBox(color: Colors.black), dark: dark));
      final base = await _timedPumps(tester, 60);
      final rows = <String>[];
      for (final style in _styles) {
        await tester.pumpWidget(_host(ProfileCover(key: ValueKey(style), style: style), dark: dark));
        await _timedPumps(tester, 20); // разогрев
        final us = await _timedPumps(tester, 100);
        final center = tester.getCenter(find.byType(ProfileCover));
        await tester.tapAt(center);
        await tester.pump(_frame);
        final g = await tester.startGesture(center - const Offset(120, 30));
        for (var i = 0; i < 12; i++) {
          await g.moveBy(const Offset(20, 5));
          await tester.pump(_frame);
        }
        await g.up();
        await _timedPumps(tester, 30);
        expect(tester.takeException(), isNull, reason: style.name);
        rows.add('${style.name.padRight(20)} ${(us - base).toString().padLeft(6)} µs');
      }
      debugPrint('classic covers, ${dark ? 'dark' : 'light'}, net µs/frame (base $base µs):\n${rows.join('\n')}');
    },
      // Публичная копия без настоящих картинок (см. art_assets_availability).
      skip: artAssetsArePlaceholders,
    );
  }

  testWidgets('raster cost at 3x (CPU, relative)', (tester) async {
    debugSeedProfileFxRandom(3);
    final dump = Platform.environment['CLASSIC_COVERS_PNG_DIR'];
    final rows = <String>[], sheet = <ui.Image>[];
    for (final dark in const [true, false]) {
      for (final style in _styles) {
        final key = GlobalKey();
        Future<ui.Image> snap() async {
          final rb = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          return (await tester.runAsync(() => rb.toImage(pixelRatio: 3)))!;
        }

        await tester.pumpWidget(_host(
            RepaintBoundary(key: key, child: ProfileCover(key: ValueKey('$style-still'), style: style, animate: false)),
            dark: dark));
        await tester.pump();
        // Знак «наших иконок» грузится из ассетов асинхронно — дать ему догрузиться.
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump();
        if (dump != null) sheet.add(await snap());
        await tester.pumpWidget(_host(RepaintBoundary(key: key, child: ProfileCover(key: ValueKey(style), style: style)), dark: dark));
        for (var i = 0; i < 90; i++) {
          await tester.pump(_frame);
        }
        if (dump != null) sheet.add(await snap());
        if (!dark) continue;
        final sw = Stopwatch()..start();
        for (var i = 0; i < 6; i++) {
          await tester.pump(_frame);
          (await snap()).dispose();
        }
        sw.stop();
        rows.add('${style.name.padRight(20)} ${(sw.elapsedMicroseconds ~/ 6).toString().padLeft(7)} µs');
      }
    }
    if (dump != null) {
      // Лист: строка — сцена; столбцы — тёмная неподвижная, тёмная живая, светлая неподвижная, светлая живая.
      for (var part = 0; part < 2; part++) {
        final rec = ui.PictureRecorder(), c = Canvas(rec);
        for (var r = 0; r < 8; r++) {
          final si = part * 8 + r;
          for (var col = 0; col < 4; col++) {
            final img = sheet[(col ~/ 2) * 32 + si * 2 + col % 2];
            c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
                Rect.fromLTWH(col * 392.0, r * 222.0, 390, 220), Paint()..filterQuality = FilterQuality.medium);
          }
        }
        await _png(rec.endRecording().toImageSync(392 * 4, 222 * 8), '$dump/sheet$part.png', tester);
      }
    }
    debugPrint('classic covers, record + CPU raster of 1170x660 px:\n${rows.join('\n')}');
    expect(tester.takeException(), isNull);
  },
      // Публичная копия без настоящих картинок (см. art_assets_availability).
      skip: artAssetsArePlaceholders,
    );

  testWidgets('classic covers survive resize and render a still frame', (tester) async {
    debugSeedProfileFxRandom(5);
    for (final style in _styles) {
      for (final size in const [Size(390, 220), Size(640, 160), Size(220, 300), Size(390, 220)]) {
        await tester.pumpWidget(_host(ProfileCover(key: ValueKey(style), style: style), dark: true, w: size.width, h: size.height));
        for (var i = 0; i < 8; i++) {
          await tester.pump(_frame);
        }
      }
      expect(tester.takeException(), isNull, reason: '${style.name}: resize');
      await tester.pumpWidget(_host(ProfileCover(key: ValueKey('${style.name}-still'), style: style, animate: false), dark: false));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${style.name}: still');
    }
  },
      // Публичная копия без настоящих картинок (см. art_assets_availability).
      skip: artAssetsArePlaceholders,
    );
}

Future<void> _png(ui.Image img, String path, WidgetTester tester) async {
  final bytes = await tester.runAsync(() => img.toByteData(format: ui.ImageByteFormat.png));
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  img.dispose();
}
