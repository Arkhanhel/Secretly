// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// MEASUREMENT: which frame kinds draw in a SINGLE colour?
//
// A one-colour kind can be stored as an 8-bit MASK (four frames packed into the
// four channels of one RGBA texture, 4x the memory) and tinted back at draw
// time. A kind that varies its hue per particle or along a gradient cannot —
// packing would flatten it. Reading the painters is not proof: a "single"
// Color.lerp or an accent-tinted glow is easy to miss, so measure the pixels.
//
// For every non-transparent pixel we un-premultiply to get its true colour and
// bucket it. A kind is packable when all its pixels share one hue+brightness.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';

void main() {
  testWidgets('mask+tint reconstruction error per frame kind', (tester) async {
    // The real question is not "how many colours" but "what is LOST if we keep
    // only the alpha mask and tint it". So: find each kind's alpha-weighted
    // average colour, rebuild every pixel as tint x alpha, and measure the
    // error against the true pixel — in premultiplied space, which is what the
    // screen actually shows. Error below ~2/255 is invisible; that kind can be
    // packed four-to-a-texture. Above it, packing would flatten real colour.
    final rows = (await tester.runAsync(() async {
      final out = <String, ({double err, double p99, String tint})>{};
      for (final f in kAvatarFrames) {
        var sr = 0.0, sg = 0.0, sb = 0.0, sa = 0.0;
        final frames = <List<int>>[];
        for (var p = 0; p < 4; p++) {
          final img = await debugBakeFrame(f.id, p / 4, contentPx: 116);
          final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
          img.dispose();
          final px = data!.buffer.asUint8List();
          frames.add(px);
          for (var i = 0; i < px.length; i += 4) {
            final a = px[i + 3];
            if (a == 0) continue;
            // premultiplied sums → alpha-weighted average colour
            sr += px[i];
            sg += px[i + 1];
            sb += px[i + 2];
            sa += a / 255.0;
          }
        }
        if (sa == 0) {
          out[f.id] = (err: 0.0, p99: 0.0, tint: '—');
          continue;
        }
        final tr = (sr / sa).clamp(0, 255);
        final tg = (sg / sa).clamp(0, 255);
        final tb = (sb / sa).clamp(0, 255);

        var sum = 0.0;
        var n = 0;
        final errs = <double>[];
        for (final px in frames) {
          for (var i = 0; i < px.length; i += 4) {
            final a = px[i + 3] / 255.0;
            if (a == 0) continue;
            final e = ((px[i] - tr * a).abs() +
                    (px[i + 1] - tg * a).abs() +
                    (px[i + 2] - tb * a).abs()) /
                3.0;
            sum += e;
            errs.add(e);
            n++;
          }
        }
        errs.sort();
        String hex(num v) => v.round().toRadixString(16).padLeft(2, '0');
        out[f.id] = (
          err: sum / n,
          p99: errs[(errs.length * 0.99).floor()],
          tint: '#${hex(tr)}${hex(tg)}${hex(tb)}',
        );
      }
      return out;
    }))!;

    final ranked = rows.entries.toList()
      ..sort((a, b) => a.value.err.compareTo(b.value.err));
    debugPrint('kind          mean err  p99 err  tint');
    for (final e in ranked) {
      debugPrint('${e.key.padRight(12)}  ${e.value.err.toStringAsFixed(2).padLeft(8)}  '
          '${e.value.p99.toStringAsFixed(1).padLeft(7)}  ${e.value.tint}');
    }
  });
}
