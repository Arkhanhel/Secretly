// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// MEASUREMENT + REGRESSION GUARD for the animated avatar-frame loop seam.
//
// A baked loop plays frame 0 → frameCount-1 → frame 0 forever. For that wrap to
// be invisible, the step from the LAST frame back to the FIRST must be no
// bigger than an ordinary step between two neighbouring frames. So we do not
// assert "the seam is small" (small compared to what?) — we bake a few
// neighbouring PAIRS around the loop, take their mean pixel difference as the
// natural per-step motion of that kind, and compare the seam against it:
//
//     seamRatio = diff(last, first) / mean(diff(i, i+1))
//
// seamRatio ≈ 1 → the wrap looks like any other step: seamless.
// seamRatio ≫ 1 → the wrap jumps: the visible "restart" judder.
//
// The ratio is self-normalising, so a fast kind and a slow kind are judged by
// the same number, and re-timing a loop can't silently move the goalposts.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';

const int _kContentPx = 116; // production bake resolution

/// A wrap may be up to this much worse than the loop's busiest ordinary frame
/// before the eye reads it as a restart.
const double _kSeamLimit = 2.0;

/// RATCHET. Kinds whose loop still doesn't close, with the ceiling they sit at
/// today: they may not get WORSE, and each one drops off this list (and under
/// [_kSeamLimit]) as it is fixed. Every entry here needs a loop long enough to
/// hold whole cycles of BOTH its slow and its fast motion, which today collides
/// with the 96-frame bake cap — see docs/TZ_FRAMES_LOOP_AND_OPTIMIZATION.
const Map<String, double> _kSeamDebt = {};

Future<Uint8List> _pixels(ui.Image img) async {
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

/// Mean absolute per-channel difference, 0…1.
double _diff(Uint8List a, Uint8List b) {
  var sum = 0;
  for (var i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]).abs();
  }
  return sum / a.length / 255.0;
}

Future<Uint8List> _frame(String kind, int index, int count) async {
  final img = await debugBakeLoopFrame(kind, index, contentPx: _kContentPx);
  final px = await _pixels(img);
  img.dispose();
  return px;
}

/// Walks the WHOLE loop: every neighbouring pair plus the wrap pair, so the
/// seam is judged against the real distribution of steps — not against an
/// average that a kind with bursty motion (a firework, a lightning strike)
/// would blow past on ordinary frames too.
Future<({double seam, double mean, double p95, double ratio})> _measure(
    String kind) async {
  final n = debugFrameCount(kind);
  final first = await _frame(kind, 0, n);
  var prev = first;
  final steps = <double>[];
  for (var i = 1; i < n; i++) {
    final cur = await _frame(kind, i, n);
    steps.add(_diff(prev, cur));
    prev = cur;
  }
  final seam = _diff(prev, first); // last → first, the wrap
  steps.sort();
  final mean = steps.reduce((a, b) => a + b) / steps.length;
  final p95 = steps[(steps.length * 0.95).floor().clamp(0, steps.length - 1)];
  // Judge against p95, not the mean: a seam is invisible when it is no worse
  // than the loop's own busiest ordinary frame.
  return (seam: seam, mean: mean, p95: p95, ratio: p95 == 0 ? 0.0 : seam / p95);
}

void main() {
  testWidgets('loop seam: every frame kind wraps as smoothly as it steps',
      (tester) async {
    // `toImage` is a REAL engine future — inside testWidgets' fake async zone it
    // never completes, so the bake has to run through runAsync.
    final rows = (await tester.runAsync(() async {
      final out = <String, ({double seam, double mean, double p95, double ratio})>{};
      for (final f in kAvatarFrames) {
        out[f.id] = await _measure(f.id);
      }
      return out;
    }))!;

    final ranked = rows.entries.toList()
      ..sort((a, b) => b.value.ratio.compareTo(a.value.ratio));
    debugPrint('kind          seam      mean      p95       seam/p95');
    for (final e in ranked) {
      debugPrint('${e.key.padRight(12)}  '
          '${e.value.seam.toStringAsFixed(5)}  '
          '${e.value.mean.toStringAsFixed(5)}  '
          '${e.value.p95.toStringAsFixed(5)}  '
          '${e.value.ratio.toStringAsFixed(1)}x');
    }

    for (final e in ranked) {
      final limit = _kSeamDebt[e.key] ?? _kSeamLimit;
      expect(e.value.ratio, lessThanOrEqualTo(limit),
          reason: 'frame "${e.key}" wraps ${e.value.ratio.toStringAsFixed(1)}x '
              'harder than its own p95 step (limit ${limit}x). Every t-driven '
              'term must complete a WHOLE number of cycles per loop.');
    }
    // Frame budget: the step between neighbouring frames is what "smooth"
    // means. Too big and the loop stutters; far too small and the loop is
    // paying memory for frames the eye cannot separate.
    for (final e in ranked) {
      expect(e.value.mean, lessThan(0.0075),
          reason: 'frame "${e.key}" steps ${e.value.mean.toStringAsFixed(5)} '
              'between frames — choppy; raise its budget in _maxFramesFor');
    }

    for (final fixed in _kSeamDebt.keys) {
      expect(rows[fixed]!.ratio, greaterThan(_kSeamLimit),
          reason: 'frame "$fixed" now closes its loop — drop it from '
              '_kSeamDebt so the ratchet keeps it there.');
    }
  });
}
