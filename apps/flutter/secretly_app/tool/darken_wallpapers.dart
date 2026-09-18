// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Darkens the colourful doodle wallpaper masters to match the dark Telegram
// reference: background luminance -> ~27, doodle outlines only ~11 brighter,
// keeping each image's own hue/saturation and its gradient.
//   dart run tool/darken_wallpapers.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const root = '/Users/yuriiarkhangelsky/dev/Secretly-code';

// Target tones measured from the reference screenshot (clean bands).
const double kBgTarget = 27.0; // background luminance
const double kDoodleTarget = 38.0; // doodle-outline luminance (ΔL ≈ 11)

double lum(num r, num g, num b) => 0.2126 * r + 0.7152 * g + 0.0722 * b;

List<int> avgRegion(img.Image im, {int step = 3}) {
  num r = 0, g = 0, b = 0;
  int n = 0;
  for (int y = 0; y < im.height; y += step) {
    for (int x = 0; x < im.width; x += step) {
      final p = im.getPixel(x, y);
      r += p.r;
      g += p.g;
      b += p.b;
      n++;
    }
  }
  return [(r / n).round(), (g / n).round(), (b / n).round()];
}

// Mean of the brightest [pct] of pixels — the doodle-outline tone.
double brightLum(img.Image im, {int step = 3, double pct = 0.08}) {
  final ls = <double>[];
  for (int y = 0; y < im.height; y += step) {
    for (int x = 0; x < im.width; x += step) {
      final p = im.getPixel(x, y);
      ls.add(lum(p.r, p.g, p.b));
    }
  }
  ls.sort((a, b) => b.compareTo(a));
  final take = (ls.length * pct).round().clamp(1, ls.length);
  double s = 0;
  for (int i = 0; i < take; i++) {
    s += ls[i];
  }
  return s / take;
}

void main() {
  final outDir = Directory('$root/ops/wallpaper_work/darkened')
    ..createSync(recursive: true);
  for (int i = 1; i <= 13; i++) {
    final f = File('$root/originals_backup/secure$i.png');
    if (!f.existsSync()) continue;
    final im = img.decodeImage(f.readAsBytesSync())!;

    final bg = avgRegion(im);
    final bgL = lum(bg[0], bg[1], bg[2]);
    final dL = brightLum(im);
    final span = (dL - bgL).abs() < 1.0 ? 1.0 : (dL - bgL);
    final slope = (kDoodleTarget - kBgTarget) / span;

    // Per-pixel luminance remap, preserving hue+saturation by scaling RGB.
    for (final p in im) {
      final li = lum(p.r, p.g, p.b);
      double lo = kBgTarget + (li - bgL) * slope;
      if (lo < 5) lo = 5;
      if (lo > 140) lo = 140;
      double factor = li < 1 ? 0 : lo / li;
      if (factor > 6) factor = 6;
      p.r = (p.r * factor).round().clamp(0, 255);
      p.g = (p.g * factor).round().clamp(0, 255);
      p.b = (p.b * factor).round().clamp(0, 255);
    }

    File('${outDir.path}/secure$i.png').writeAsBytesSync(img.encodePng(im));
    stdout.writeln('secure$i: bgL ${bgL.round()}→${kBgTarget.round()}  '
        'doodleL ${dL.round()}→${kDoodleTarget.round()}  slope ${slope.toStringAsFixed(3)}');
  }
  stdout.writeln('done → ${outDir.path}');
}
