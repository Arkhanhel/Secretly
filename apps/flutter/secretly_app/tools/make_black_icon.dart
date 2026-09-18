// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// One-off: build the app launcher icon = the Secretly logo (extracted from the
// brand master, its teal background removed) centred on a PURE BLACK square.
//
// Run from the app dir:  dart run tools/make_black_icon.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const _repo = '/Users/yuriiarkhangelsky/dev/Secretly-code';
const _src = '$_repo/1.png'; // 1024px white logo on teal
const _resDir = '$_repo/apps/flutter/secretly_app/android/app/src/main/res';

// density -> legacy ic_launcher.png px size
const _mipmaps = <String, int>{
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

void main() {
  final src = img.decodeImage(File(_src).readAsBytesSync());
  if (src == null) {
    stderr.writeln('cannot decode $_src');
    exitCode = 2;
    return;
  }
  final w = src.width, h = src.height;

  // 1) Map to white-logo-on-black via luminance: teal bg -> black, white logo
  //    stays white, with smooth anti-aliased edges.
  double lumAt(int x, int y) {
    final p = src.getPixel(x, y);
    return 0.299 * p.r + 0.587 * p.g + 0.114 * p.b; // 0..255
  }

  double tAt(int x, int y) {
    final l = lumAt(x, y);
    return ((l - 55.0) / (205.0 - 55.0)).clamp(0.0, 1.0);
  }

  // 2) Bounding box of the logo (t above a small threshold).
  int minX = w, minY = h, maxX = 0, maxY = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (tAt(x, y) > 0.14) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX <= minX || maxY <= minY) {
    stderr.writeln('logo bbox not found');
    exitCode = 2;
    return;
  }

  // 3) Tight square crop of the logo (centered, square side = max dimension).
  final bw = maxX - minX + 1, bh = maxY - minY + 1;
  final side = bw > bh ? bw : bh;
  final cx = (minX + maxX) ~/ 2, cy = (minY + maxY) ~/ 2;
  final sx = cx - side ~/ 2, sy = cy - side ~/ 2;

  // 4) Compose onto a PURE BLACK master; logo occupies ~74% (15% margin each
  //    side) so the full-bleed adaptive icon stays inside common mask shapes.
  const masterSize = 1024;
  final logoFrac = 0.74;
  final logoPx = (masterSize * logoFrac).round();
  final off = (masterSize - logoPx) ~/ 2;
  final master = img.Image(width: masterSize, height: masterSize);
  img.fill(master, color: img.ColorRgb8(0, 0, 0)); // pure black

  for (var oy = 0; oy < logoPx; oy++) {
    for (var ox = 0; ox < logoPx; ox++) {
      // source pixel within the tight square crop
      final fx = sx + (ox * side / logoPx).floor();
      final fy = sy + (oy * side / logoPx).floor();
      if (fx < 0 || fy < 0 || fx >= w || fy >= h) continue;
      final t = tAt(fx, fy);
      if (t <= 0.0) continue;
      final v = (255 * t).round();
      // white logo over black: blend toward white by t
      master.setPixelRgb(off + ox, off + oy, v, v, v);
    }
  }

  // 5) Write the 1024 master (brand default) + the legacy mipmaps.
  File(
    '$_repo/apps/flutter/secretly_app/assets/app_icons/default.png',
  ).writeAsBytesSync(img.encodePng(master));
  for (final e in _mipmaps.entries) {
    final resized = img.copyResize(
      master,
      width: e.value,
      height: e.value,
      interpolation: img.Interpolation.average,
    );
    final out = File('$_resDir/${e.key}/ic_launcher.png');
    out.writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('wrote ${out.path} (${e.value}px)');
  }

  // 6) Adaptive FOREGROUND: the white logo on a TRANSPARENT canvas (108dp at
  //    each density), logo ~64% so it sits inside the adaptive safe zone. The
  //    adaptive-icon XML must reference THIS (@mipmap/ic_launcher_foreground),
  //    never @mipmap/ic_launcher — on API 26+ the latter resolves to the
  //    adaptive XML itself (self-reference) and the launcher falls back to the
  //    stock Android robot icon. The solid background is supplied by the XML's
  //    <background> colour layer, so the foreground stays transparent.
  const fgMipmaps = <String, int>{
    'mipmap-mdpi': 108,
    'mipmap-hdpi': 162,
    'mipmap-xhdpi': 216,
    'mipmap-xxhdpi': 324,
    'mipmap-xxxhdpi': 432,
  };
  // The launcher only shows the inner ~72dp viewport of the 108dp adaptive
  // canvas, so a 0.64 logo filled ~95% of the visible icon ("stretched to full
  // width"). 0.42 of 108dp ≈ 63% of the visible 72dp viewport — a harmonious,
  // balanced glyph with comfortable margin.
  const fgFrac = 0.42;
  for (final e in fgMipmaps.entries) {
    final canvas = e.value;
    final lp = (canvas * fgFrac).round();
    final fgOff = (canvas - lp) ~/ 2;
    final fg = img.Image(width: canvas, height: canvas, numChannels: 4);
    for (var oy = 0; oy < lp; oy++) {
      for (var ox = 0; ox < lp; ox++) {
        final fx = sx + (ox * side / lp).floor();
        final fy = sy + (oy * side / lp).floor();
        if (fx < 0 || fy < 0 || fx >= w || fy >= h) continue;
        final t = tAt(fx, fy);
        if (t <= 0.0) continue;
        final a = (255 * t).round();
        fg.setPixelRgba(fgOff + ox, fgOff + oy, 255, 255, 255, a);
      }
    }
    final out = File('$_resDir/${e.key}/ic_launcher_foreground.png');
    out.writeAsBytesSync(img.encodePng(fg));
    stdout.writeln(
      'wrote ${out.path} ($canvas px, logo $lp px on transparent)',
    );
  }
  stdout.writeln(
    'done: logo on pure black, ${logoPx}px logo in ${masterSize}px',
  );
}
