// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Proves the showcase path (profile pages) draws at FULL resolution.
//
// The baked atlas caps textures at 116px because a chat list shows many frames
// at once. A profile avatar is drawn three times that size, where the stretch
// is visible as softness — the complaint that started this. Inside a
// CosmeticShowcaseScope the frame must instead paint live from vectors, i.e.
// match a direct painter pass at the same size almost exactly.
//
// Measured as pixel difference against the direct vector render: the showcase
// render must be far closer to it than the baked/stretched one.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/premium/cosmetic_animation_scope.dart';
import 'package:secretly_app/ui/premium/cosmetics_catalog.dart';
import 'package:secretly_app/ui/thermal_guard.dart';

const double _kAvatar = 300; // profile-sized
const Key _kBoundary = ValueKey('showcase-under-test');

Future<Uint8List> _render(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: _kBoundary,
            child: SizedBox(
              width: _kAvatar * 2,
              height: _kAvatar * 2,
              child: Center(
                child: SizedBox(
                  width: _kAvatar,
                  height: _kAvatar,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_kBoundary));
  return (await tester.runAsync(() async {
    final img = await boundary.toImage();
    final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    return d!.buffer.asUint8List();
  }))!;
}

double _diff(Uint8List a, Uint8List b) {
  var sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]).abs();
  }
  return sum / a.length;
}

void main() {
  testWidgets('a profile-sized frame is sharp, not a stretched texture',
      (tester) async {
    // 'aurora' is the kind that loses the most to resolution (measured 10.8/255
    // at half), so it is the honest case to test.
    const kind = 'aurora';
    // The baked render below starts a background bake; drop it with the tree.
    addTearDown(debugResetFrameAtlas);

    final showcase = await _render(
      tester,
      CosmeticShowcaseScope(child: frameById(kind)!.builder(_kAvatar)),
    );
    final baked = await _render(tester, frameById(kind)!.builder(_kAvatar));

    // Reference: what the art looks like when drawn straight at this size.
    final ref = (await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      // Same placement the widget uses: centred in the 2x box.
      canvas.translate(_kAvatar / 2, _kAvatar / 2);
      debugLiveFramePainter(kind, 0, const Size(_kAvatar, _kAvatar))!(canvas);
      final img = await rec.endRecording().toImage(
            (_kAvatar * 2).round(),
            (_kAvatar * 2).round(),
          );
      final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      return d!.buffer.asUint8List();
    }))!;

    final showcaseErr = _diff(showcase, ref);
    final bakedErr = _diff(baked, ref);
    debugPrint('showcase vs direct: ${showcaseErr.toStringAsFixed(2)}   '
        'baked vs direct: ${bakedErr.toStringAsFixed(2)}');

    expect(showcaseErr, lessThan(bakedErr),
        reason: 'a showcase frame must be closer to the direct vector render '
            'than the stretched baked texture is');

    await tester.pumpWidget(const SizedBox());
    debugResetFrameAtlas();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a showcase holds no atlas entry; a list does', (tester) async {
    // The showcase path costs a paint per vsync, which is right for one big
    // avatar and wrong for a list. The observable difference: a showcase must
    // not take an atlas entry at all — an entry means a baked loop and a shared
    // ticker running for a texture nothing draws.
    addTearDown(debugResetFrameAtlas);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: CosmeticShowcaseScope(
                child: frameById('gold')!.builder(120),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(debugAtlasEntryCount(), 0,
        reason: 'a showcase frame must paint live, not bake into the atlas');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              for (final f in kAvatarFrames.take(3))
                SizedBox(height: 64, child: f.builder(52)),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(debugAtlasEntryCount(), greaterThan(0),
        reason: 'list rows must share the baked atlas');

    await tester.pumpWidget(const SizedBox());
    debugResetFrameAtlas();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('every kind sits in the same place on a showcase as it does '
      'when painted directly', (tester) async {
    // The padded box around a frame is asymmetric (smoke needs headroom above,
    // none below), so the box has to be shifted for the RING to stay centred on
    // the avatar. Miss that shift and the frame hangs below the photo — which
    // is exactly what happened to 'phoenix'. Compare, for EVERY kind, where the
    // art lands on a showcase against where the painter puts it directly.
    const ring = 120.0;
    const box = 360.0;
    const key = ValueKey('geometry-under-test');

    // Freeze the animation so the live path stays at phase 0 and the reference
    // can be drawn at the same phase.
    final was = ThermalGuard.effectsAllowed.value;
    ThermalGuard.effectsAllowed.value = false;
    addTearDown(() => ThermalGuard.effectsAllowed.value = was);
    addTearDown(debugResetFrameAtlas);

    ({double l, double t, double r, double b}) bounds(
        Uint8List px, int w, int h, double scale) {
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
      final c = w / 2;
      return (
        l: (c - minX) / scale / ring,
        t: (c - minY) / scale / ring,
        r: (maxX - c) / scale / ring,
        b: (maxY - c) / scale / ring,
      );
    }

    final offenders = <String>[];
    for (final f in kAvatarFrames) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: box,
                  height: box,
                  child: Center(
                    child: SizedBox(
                      width: ring,
                      height: ring,
                      child: CosmeticShowcaseScope(child: f.builder(ring)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final live = (await tester.runAsync(() async {
        final img = await tester
            .renderObject<RenderRepaintBoundary>(find.byKey(key))
            .toImage();
        final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final w = img.width, h = img.height;
        img.dispose();
        return bounds(d!.buffer.asUint8List(), w, h, w / box);
      }))!;

      final ref = (await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        final canvas = ui.Canvas(rec);
        canvas.translate((box - ring) / 2, (box - ring) / 2);
        debugLiveFramePainter(f.id, 0, const Size(ring, ring))!(canvas);
        final img =
            await rec.endRecording().toImage(box.round(), box.round());
        final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        img.dispose();
        return bounds(d!.buffer.asUint8List(), box.round(), box.round(), 1);
      }))!;

      final dx = ((live.l - live.r) - (ref.l - ref.r)).abs() / 2;
      final dy = ((live.t - live.b) - (ref.t - ref.b)).abs() / 2;
      if (dx > 0.03 || dy > 0.03) {
        offenders.add('${f.id}: off by '
            '(${dx.toStringAsFixed(3)}, ${dy.toStringAsFixed(3)}) of the avatar');
      }
    }

    expect(offenders, isEmpty,
        reason: 'these kinds are drawn off-centre on a showcase — the padded '
            'box shift does not match their overscan:\n${offenders.join("\n")}');
  });
}
