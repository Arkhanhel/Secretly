// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Эксклюзивная коллекция (13.11.2026): 10 рамок и 10 обложек.
// Проверка «не падает и рисует»: ветер перетаскивания, действие, обе темы,
// касание, палец, смена размера. Печатает время кадра для сравнения сцен.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/live_frames.dart';
import 'package:secretly_app/ui/premium/profile_fx.dart';

const _frameIds = ['dragon', 'ferro', 'jelly', 'beads', 'liquid', 'gears', 'flow', 'flock', 'pwave', 'spiro'];

const _covers = [
  ProfileCoverStyle.cloth,
  ProfileCoverStyle.balls,
  ProfileCoverStyle.orbits,
  ProfileCoverStyle.chaos,
  ProfileCoverStyle.life,
  ProfileCoverStyle.compass,
  ProfileCoverStyle.plush,
  ProfileCoverStyle.storm,
  ProfileCoverStyle.ink,
  ProfileCoverStyle.warp,
];

const _palettes = [FramePalette(true, Color(0xFF0C0D11)), FramePalette(false, Colors.white)];

/// Сколько пикселей кадра не прозрачны — «рамка что-то нарисовала».
Future<int> _inked(ui.Image img) async {
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  var n = 0;
  for (var i = 3; i < data.lengthInBytes; i += 4) {
    if (data.getUint8(i) > 8) n++;
  }
  return n;
}



void main() {
  testWidgets('collection frames: wind, action, both palettes, paint', (tester) async {
    debugSeedProfileFxRandom(13);
    const size = Size(200, 200);
    final rows = (await tester.runAsync(() async {
      final out = <String, ({double record, double raster, int still})>{};
      for (final id in _frameIds) {
        final sim = createOwnFrameSim(id);
        expect(sim, isNotNull, reason: id);
        sim!;
        sim.settle();

        // Неподвижный кадр сетки выбора: что-то видно в обеих темах.
        var still = 1 << 30;
        for (final pal in _palettes) {
          final rec = ui.PictureRecorder();
          LiveFramePainter(sim: sim, palette: pal).paint(Canvas(rec), size);
          final img = await rec.endRecording().toImage(200, 200);
          still = math.min(still, await _inked(img));
          img.dispose();
        }
        expect(still, greaterThan(2000), reason: '$id still frame is nearly empty');

        // 5 с жизни: ветер перетаскивания, включение и выключение действия.
        for (var i = 0; i < 300; i++) {
          if (i >= 30 && i < 150) {
            sim.ivx = -140 * math.sin(i / 9);
            sim.ivy = 60 * math.cos(i / 7);
          } else {
            sim.ivx = 0;
            sim.ivy = 0;
          }
          if (i == 60) sim.active = true;
          if (i == 200) sim.active = false;
          sim.tick(1 / 60);
        }

        // Время записи и растеризации кадра, обе темы.
        const reps = 20;
        final pics = <ui.Picture>[];
        final sw = Stopwatch()..start();
        for (var i = 0; i < reps; i++) {
          sim.tick(1 / 60);
          final rec = ui.PictureRecorder();
          LiveFramePainter(sim: sim, palette: _palettes[i % 2]).paint(Canvas(rec), size);
          pics.add(rec.endRecording());
        }
        sw.stop();
        final sw2 = Stopwatch()..start();
        for (final p in pics) {
          (await p.toImage(200, 200)).dispose();
          p.dispose();
        }
        sw2.stop();
        out[id] = (
          record: sw.elapsedMicroseconds / reps,
          raster: sw2.elapsedMicroseconds / reps,
          still: still,
        );
        sim.dispose();
      }
      return out;
    }))!;
    debugPrint('frame     record µs  raster µs  still px');
    for (final e in rows.entries) {
      debugPrint('${e.key.padRight(9)} ${e.value.record.toStringAsFixed(0).padLeft(9)}  '
          '${e.value.raster.toStringAsFixed(0).padLeft(9)}  ${e.value.still.toString().padLeft(8)}');
    }
  });

  testWidgets('collection covers: both themes, tap, drag, resize, still frame', (tester) async {
    debugSeedProfileFxRandom(29);
    final timings = <String, ({double pump, double raster})>{};
    Widget host(ProfileCoverStyle s, bool dark, Size box, {bool animate = true}) => MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(width: box.width, height: box.height, child: ProfileCover(style: s, animate: animate)),
            ),
          ),
        );
    for (final style in _covers) {
      for (final dark in [true, false]) {
        // Неподвижный кадр (сетка выбора): один рисунок без тикера.
        await tester.pumpWidget(host(style, dark, const Size(390, 220), animate: false));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$style still');

        await tester.pumpWidget(host(style, dark, const Size(390, 220)));
        final sw = Stopwatch()..start();
        for (var i = 0; i < 120; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        sw.stop();
        // Растеризация того же кадра обложки (2x), среднее из 5.
        final rb = tester.renderObject<RenderRepaintBoundary>(
            find.descendant(of: find.byType(ProfileCover), matching: find.byType(RepaintBoundary)).first);
        final raster = (await tester.runAsync(() async {
          final w = Stopwatch()..start();
          for (var i = 0; i < 5; i++) {
            (await rb.toImage(pixelRatio: 2)).dispose();
          }
          return w.elapsedMicroseconds / 5;
        }))!;
        final center = tester.getCenter(find.byType(ProfileCover));
        await tester.tapAt(center + const Offset(-60, 20));
        await tester.pump(const Duration(milliseconds: 16));
        final g = await tester.startGesture(center + const Offset(80, -30));
        for (var i = 0; i < 30; i++) {
          await g.moveBy(Offset(-6, 2.0 * math.sin(i / 3)));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await g.up();
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        // Смена размера на лету (поворот, другое окно) и обратно.
        await tester.pumpWidget(host(style, dark, const Size(300, 150)));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpWidget(host(style, dark, const Size(390, 220)));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.takeException(), isNull, reason: '$style dark=$dark');
        timings['${style.name}${dark ? '' : ' (light)'}'] = (pump: sw.elapsedMicroseconds / 120, raster: raster);
      }
    }
    await tester.pumpWidget(const SizedBox());
    debugPrint('cover              pump µs (sim + record)  raster µs @2x');
    for (final e in timings.entries) {
      debugPrint('${e.key.padRight(18)} ${e.value.pump.toStringAsFixed(0).padLeft(6)}  ${e.value.raster.toStringAsFixed(0).padLeft(16)}');
    }
  });
}
