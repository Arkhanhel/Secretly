// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// MEASUREMENT: how far past the ring does each frame kind actually draw?
//
// The baked texture is square and the transparent margin around the ring is one
// shared constant, so anything drawn beyond it is hard-clipped at the texture
// edge — the "square border around the frame" seen on Smoke. Reading the
// painters to guess the reach is unreliable (blur radii, seeded offsets), so we
// bake into a deliberately oversized canvas and look at the pixels: the
// bounding box of everything non-transparent IS the reach.
//
// Output is per SIDE, as a fraction of the ring size, because the art is not
// symmetric — smoke rises, so it needs headroom at the top and nothing extra
// at the bottom. A square margin sized for the top would pay for three sides
// that don't need it.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/cosmetic_animation_scope.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';

const int _kContentPx = 116;
const double _kProbe = 0.6; // margin per side while probing
const int _kAlphaFloor = 3; // ignore dithering-level noise

Future<({double l, double t, double r, double b})> _reach(
    String kind, double phase) async {
  final img = await debugBakeProbe(kind, phase,
      contentPx: _kContentPx, probe: _kProbe);
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final px = data!.buffer.asUint8List();
  final w = img.width, h = img.height;
  img.dispose();

  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (px[(y * w + x) * 4 + 3] < _kAlphaFloor) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) return (l: 0.0, t: 0.0, r: 0.0, b: 0.0);

  final margin = (_kContentPx * _kProbe).round();
  double frac(int pxFromRing) => pxFromRing / _kContentPx;
  return (
    l: frac(margin - minX).clamp(0.0, 1.0),
    t: frac(margin - minY).clamp(0.0, 1.0),
    r: frac(maxX - (margin + _kContentPx - 1)).clamp(0.0, 1.0),
    b: frac(maxY - (margin + _kContentPx - 1)).clamp(0.0, 1.0),
  );
}

/// Max alpha anywhere on the outermost ring of pixels of [img]. Non-zero means
/// the art ran into the texture edge and was hard-clipped there — the visible
/// "square border around the frame".
Future<int> _edgeAlpha(ui.Image img) async {
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final px = data!.buffer.asUint8List();
  final w = img.width, h = img.height;
  var worst = 0;
  int a(int x, int y) => px[(y * w + x) * 4 + 3];
  for (var x = 0; x < w; x++) {
    worst = [worst, a(x, 0), a(x, h - 1)].reduce((p, q) => p > q ? p : q);
  }
  for (var y = 0; y < h; y++) {
    worst = [worst, a(0, y), a(w - 1, y)].reduce((p, q) => p > q ? p : q);
  }
  return worst;
}

void main() {
  testWidgets('measured reach past the ring, per kind, per side',
      (tester) async {
    final rows = (await tester.runAsync(() async {
      final out = <String, ({double l, double t, double r, double b})>{};
      for (final f in kAvatarFrames) {
        var acc = (l: 0.0, t: 0.0, r: 0.0, b: 0.0);
        // Eight phases: particles are at their furthest at different points of
        // the loop, and the worst case is what has to fit.
        for (var i = 0; i < 8; i++) {
          final r = await _reach(f.id, i / 8);
          acc = (
            l: acc.l > r.l ? acc.l : r.l,
            t: acc.t > r.t ? acc.t : r.t,
            r: acc.r > r.r ? acc.r : r.r,
            b: acc.b > r.b ? acc.b : r.b,
          );
        }
        out[f.id] = acc;
      }
      return out;
    }))!;

    final ranked = rows.entries.toList()
      ..sort((a, b) {
        double m(({double l, double t, double r, double b}) v) =>
            [v.l, v.t, v.r, v.b].reduce((x, y) => x > y ? x : y);
        return m(b.value).compareTo(m(a.value));
      });
    debugPrint('kind          left    top     right   bottom   (of ring size)');
    for (final e in ranked) {
      debugPrint('${e.key.padRight(12)}  '
          '${e.value.l.toStringAsFixed(3)}   '
          '${e.value.t.toStringAsFixed(3)}   '
          '${e.value.r.toStringAsFixed(3)}   '
          '${e.value.b.toStringAsFixed(3)}');
    }
  });

  testWidgets('no kind is clipped by the edge of its baked texture',
      (tester) async {
    // Alpha at the texture edge, over the whole loop of every kind. The margin
    // exists so blur and particles fade to nothing INSIDE the texture; anything
    // still visible when the pixels run out is a cut-off edge.
    final worst = (await tester.runAsync(() async {
      final out = <String, int>{};
      for (final f in kAvatarFrames) {
        var w = 0;
        final n = debugFrameCount(f.id);
        for (var i = 0; i < 8; i++) {
          final img = await debugBakeLoopFrame(f.id, (n * i) ~/ 8,
              contentPx: _kContentPx);
          final e = await _edgeAlpha(img);
          img.dispose();
          if (e > w) w = e;
        }
        out[f.id] = w;
      }
      return out;
    }))!;

    final ranked = worst.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    debugPrint('edge alpha (0 = nothing touches the texture edge):');
    for (final e in ranked.take(6)) {
      debugPrint('  ${e.key.padRight(12)} ${e.value}');
    }

    for (final e in ranked) {
      expect(e.value, lessThanOrEqualTo(2),
          reason: 'frame "${e.key}" still paints ${e.value}/255 alpha at its '
              'texture edge — widen _overscanFor("${e.key}") on the side the '
              'probe test reports.');
    }
  });

  testWidgets('an asymmetric margin still centres the RING on the avatar',
      (tester) async {
    // The texture is no longer symmetric, so it has to be shifted against its
    // own margins or the ring drifts off the avatar. Measured on the real
    // widget: 'gold' (symmetric) must stay centred, and 'smoke' must reach up,
    // not down — a sign error here would park the smoke below the avatar.
    const size = 100.0;
    const box = 300.0;
    const key = ValueKey('frame-under-test');

    Future<({double l, double t, double r, double b})> render(String id) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: box,
                  height: box,
                  // Animations off → the STATIC texture path, which draws
                  // through the same overscan geometry but starts no ticker and
                  // no background bake (whose timers would outlive the test).
                  child: CosmeticAnimationScope(
                    enabled: false,
                    child: Center(
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: frameById(id)!.builder(size),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      return (await tester.runAsync(() async {
        final img = await boundary.toImage();
        final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final px = data!.buffer.asUint8List();
        final w = img.width, h = img.height;
        final scale = w / box; // device pixel ratio of the test surface
        img.dispose();
        var minX = w, minY = h, maxX = -1, maxY = -1;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            if (px[(y * w + x) * 4 + 3] < 8) continue;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
        // Reach from the centre of the box, in units of the avatar size.
        final c = w / 2;
        double reach(num from, num to) => ((to - from) / scale / size).toDouble();
        return (
          l: reach(minX, c),
          t: reach(minY, c),
          r: reach(c, maxX),
          b: reach(c, maxY),
        );
      }))!;
    }

    final gold = await render('gold');
    debugPrint('gold  l=${gold.l.toStringAsFixed(2)} t=${gold.t.toStringAsFixed(2)} '
        'r=${gold.r.toStringAsFixed(2)} b=${gold.b.toStringAsFixed(2)}');
    expect((gold.l - gold.r).abs(), lessThan(0.06),
        reason: 'a symmetric frame must stay horizontally centred');
    expect((gold.t - gold.b).abs(), lessThan(0.06),
        reason: 'a symmetric frame must stay vertically centred');

    final smoke = await render('smoke');
    debugPrint('smoke l=${smoke.l.toStringAsFixed(2)} t=${smoke.t.toStringAsFixed(2)} '
        'r=${smoke.r.toStringAsFixed(2)} b=${smoke.b.toStringAsFixed(2)}');
    expect((smoke.l - smoke.r).abs(), lessThan(0.10),
        reason: 'smoke drifts sideways: the horizontal shift is wrong');
    expect(smoke.t, greaterThan(smoke.b + 0.15),
        reason: 'smoke must reach ABOVE the avatar — if it reaches below, the '
            'vertical shift has the wrong sign');
    expect(smoke.b, lessThan(0.75),
        reason: 'smoke hangs below the avatar: the texture was not shifted up '
            'against its own top margin');
  });
}
