// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// MEASUREMENT: what does each frame kind LOSE if its texture is baked at half
// resolution and scaled up at draw time?
//
// Texture memory is the last big lever left for the five colourful kinds that
// cannot be channel-packed. Blurred art carries no high-resolution detail by
// definition, so for those kinds a half-size bake is free; art with crisp lines
// (a hairline ring, a sharp shard) would go soft. Measure, don't assume: bake
// at full size, bake at half and scale it back up, and diff.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';

const int _kFull = 116;

Future<Uint8List> _pixels(ui.Image img) async {
  final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  return d!.buffer.asUint8List();
}

/// Bakes at [contentPx] and rescales the result to the full texture size the
/// same way the widget would (FilterQuality.low).
Future<Uint8List> _atScale(String kind, int index, int contentPx, int w, int h) async {
  final small = await debugBakeLoopFrame(kind, index, contentPx: contentPx);
  if (contentPx == _kFull) {
    final px = await _pixels(small);
    small.dispose();
    return px;
  }
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawImageRect(
    small,
    Rect.fromLTWH(0, 0, small.width.toDouble(), small.height.toDouble()),
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..filterQuality = FilterQuality.low,
  );
  final pic = rec.endRecording();
  small.dispose();
  final up = await pic.toImage(w, h);
  pic.dispose();
  final px = await _pixels(up);
  up.dispose();
  return px;
}

void main() {
  testWidgets('detail lost when a kind is baked at half resolution',
      (tester) async {
    final rows = (await tester.runAsync(() async {
      final out = <String, ({double half, double three})>{};
      for (final f in kAvatarFrames) {
        final n = debugFrameCount(f.id);
        final ref = await debugBakeLoopFrame(f.id, 0, contentPx: _kFull);
        final w = ref.width, h = ref.height;
        ref.dispose();
        var half = 0.0, three = 0.0;
        var count = 0;
        for (final i in <int>[0, n ~/ 3, (2 * n) ~/ 3]) {
          final ref = await _atScale(f.id, i, _kFull, w, h);
          final at50 = await _atScale(f.id, i, _kFull ~/ 2, w, h);
          final at75 = await _atScale(f.id, i, (_kFull * 3) ~/ 4, w, h);
          for (var k = 0; k < ref.length; k++) {
            half += (ref[k] - at50[k]).abs();
            three += (ref[k] - at75[k]).abs();
            count++;
          }
        }
        out[f.id] = (half: half / count, three: three / count);
      }
      return out;
    }))!;

    final ranked = rows.entries.toList()
      ..sort((a, b) => a.value.three.compareTo(b.value.three));
    debugPrint('kind          loss@75%  loss@50%  (0-255)');
    for (final e in ranked) {
      debugPrint('${e.key.padRight(12)}  ${e.value.three.toStringAsFixed(2).padLeft(7)}  '
          '${e.value.half.toStringAsFixed(2).padLeft(8)}');
    }
  });
}
