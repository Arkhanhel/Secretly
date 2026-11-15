// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Дымовая проверка 20 переделанных старых рамок (13.11.2026): каждая создаётся,
// выходит в статичный кадр, отрабатывает действие и рисуется в тёмной и
// светлой палитре без исключений. Печатает среднее время записи кадра.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/live_frames.dart';
import 'package:secretly_app/ui/premium/profile_fx.dart';

const _ids = [
  'cosmic', 'gold', 'orbit', 'neon', 'stars', 'aurora', 'pulse', 'ember', 'nebula', 'electric',
  'flame', 'smoke', 'bears', 'rainbow', 'butterfly', 'comet', 'sakura', 'phoenix', 'frost', 'prism',
];

void main() {
  test('20 переделанных рамок: settle, действие, 300 кадров, обе палитры', () {
    debugSeedProfileFxRandom(1311);
    const dark = FramePalette(true, Color(0xFF0C0D11));
    const light = FramePalette(false, Colors.white);
    final rows = <String>[];
    for (final id in _ids) {
      final sim = createOwnFrameSim(id);
      expect(sim, isNotNull, reason: id);
      sim!.settle();
      final painters = [
        LiveFramePainter(sim: sim, palette: dark),
        LiveFramePainter(sim: sim, palette: light),
      ];
      final sw = Stopwatch();
      var n = 0;
      void paintAll() {
        for (final p in painters) {
          final rec = ui.PictureRecorder();
          final c = Canvas(rec);
          sw.start();
          p.paint(c, const Size(200, 200));
          sw.stop();
          n++;
          rec.endRecording().dispose();
        }
      }

      paintAll(); // статичный кадр сетки
      for (var i = 0; i < 300; i++) {
        if (i == 120) sim.active = true;
        if (i == 260) sim.active = false;
        sim.tick(1 / 60);
        paintAll();
      }
      rows.add('${id.padRight(10)} ${(sw.elapsedMicroseconds / n).toStringAsFixed(1).padLeft(7)} µs');
      sim.dispose();
    }
    debugPrint('Среднее время записи кадра (200×200):\n${rows.join('\n')}');
  });
}
