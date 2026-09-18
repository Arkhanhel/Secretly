// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// MEASUREMENT: can a profile page just DRAW the frame every vsync?
//
// Baked textures exist because a chat list can show twenty frames at once. A
// profile page shows ONE, at three times the size — the size where a 116px
// baked texture is stretched 3x (visible softness) and where a thinned frame
// budget turns into visible stutter. So the question is whether the vector
// painter is cheap enough to run live at that size: if a frame costs a
// millisecond or two, a showcase avatar can have full resolution and full
// smoothness for free, and the atlas can stay lean for the lists.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';

void main() {
  testWidgets('cost of painting one frame live at profile size',
      (tester) async {
    // A profile avatar: ~120dp on a 3x screen, plus the overscan margin.
    const size = Size(400, 400);
    final rows = (await tester.runAsync(() async {
      final out = <String, ({double record, double raster})>{};
      for (final f in kAvatarFrames) {
        for (var i = 0; i < 3; i++) {
          final rec = ui.PictureRecorder();
          debugLiveFramePainter(f.id, 0.1 * i, size)!(ui.Canvas(rec));
          rec.endRecording().dispose();
        }
        const reps = 10;
        final pics = <ui.Picture>[];
        final sw = Stopwatch()..start();
        for (var i = 0; i < reps; i++) {
          final rec = ui.PictureRecorder();
          debugLiveFramePainter(f.id, i / reps, size)!(ui.Canvas(rec));
          pics.add(rec.endRecording());
        }
        sw.stop();
        final sw2 = Stopwatch()..start();
        for (final p in pics) {
          (await p.toImage(400, 400)).dispose();
          p.dispose();
        }
        sw2.stop();
        out[f.id] = (
          record: sw.elapsedMicroseconds / reps / 1000.0,
          raster: sw2.elapsedMicroseconds / reps / 1000.0,
        );
      }
      return out;
    }))!;

    final ranked = rows.entries.toList()
      ..sort((a, b) => (b.value.raster + b.value.record)
          .compareTo(a.value.raster + a.value.record));
    debugPrint('kind          record ms  raster ms');
    for (final e in ranked) {
      debugPrint('${e.key.padRight(12)}  ${e.value.record.toStringAsFixed(2).padLeft(8)}  '
          '${e.value.raster.toStringAsFixed(2).padLeft(9)}');
    }
  });
}
