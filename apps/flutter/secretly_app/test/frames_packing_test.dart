// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Proves the channel-packed path is LOSSLESS for the kinds that use it.
//
// A packed loop stores three frames in the R/G/B channels of one texture and
// tints the chosen channel back at draw time. That is only allowed to ship if
// the pixels it produces match an ordinary bake of the same phase — so this
// test runs the whole packed path (pack → read channel → tint) and diffs it
// against the unpacked bake, pixel for pixel.
//
// It also guards the tint table: if a painter's colour is edited and
// _packedTintFor is not, the reconstruction drifts and this test fails.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';

Future<Uint8List> _pixels(ui.Image img) async {
  final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  return d!.buffer.asUint8List();
}

void main() {
  testWidgets('packed frames reconstruct their unpacked originals',
      (tester) async {
    final packedKinds =
        kAvatarFrames.map((f) => f.id).where(debugIsPacked).toList();
    expect(packedKinds, isNotEmpty, reason: 'some kind must take the fast path');

    final report = (await tester.runAsync(() async {
      final out = <String, ({double mean, int worst})>{};
      for (final kind in packedKinds) {
        final n = debugFrameCount(kind);
        var sum = 0.0;
        var worst = 0;
        var count = 0;
        // Three groups spread around the loop, all three channels of each.
        for (final base in <int>[0, n ~/ 3, (2 * n) ~/ 3]) {
          final indices = <int>[for (var k = 0; k < 3; k++) (base + k) % n];
          for (var c = 0; c < 3; c++) {
            final viaPack = await debugBakePackedFrame(kind, indices, c);
            final direct = await debugBakeLoopFrame(kind, indices[c]);
            final a = await _pixels(viaPack);
            final b = await _pixels(direct);
            viaPack.dispose();
            direct.dispose();
            for (var i = 0; i < a.length; i++) {
              final d = (a[i] - b[i]).abs();
              sum += d;
              if (d > worst) worst = d;
            }
            count += a.length;
          }
        }
        out[kind] = (mean: sum / count, worst: worst);
      }
      return out;
    }))!;

    debugPrint('kind          mean diff  worst pixel');
    for (final e in report.entries) {
      debugPrint('${e.key.padRight(12)}  ${e.value.mean.toStringAsFixed(3).padLeft(9)}  '
          '${e.value.worst.toString().padLeft(11)}');
    }

    for (final e in report.entries) {
      expect(e.value.mean, lessThan(1.0),
          reason: '"${e.key}" loses colour when packed — either it is not a '
              'single-colour kind (drop it from _isPackedKind) or its tint in '
              '_packedTintFor no longer matches what it paints');
      expect(e.value.worst, lessThanOrEqualTo(24),
          reason: '"${e.key}" has a pixel that packing changed by '
              '${e.value.worst}/255');
    }
  });
}
