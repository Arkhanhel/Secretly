// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Measures background + doodle-outline tones of the target Telegram screenshot
// and each original wallpaper, so we can darken the originals to match.
//   dart run tool/analyze_wallpaper.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const root = '/Users/yuriiarkhangelsky/dev/Secretly-code';

double lum(num r, num g, num b) => 0.2126 * r + 0.7152 * g + 0.0722 * b;

List<int> avgRegion(img.Image im, int x0, int y0, int x1, int y1,
    {int step = 3}) {
  num r = 0, g = 0, b = 0;
  int n = 0;
  for (int y = y0; y < y1; y += step) {
    for (int x = x0; x < x1; x += step) {
      final p = im.getPixel(x, y);
      r += p.r;
      g += p.g;
      b += p.b;
      n++;
    }
  }
  return [(r / n).round(), (g / n).round(), (b / n).round()];
}

// Average colour of the brightest [pct] of pixels in a region — the doodle
// outlines are the lightest pixels over a near-uniform background.
List<int> brightAvg(img.Image im, int x0, int y0, int x1, int y1,
    {int step = 3, double pct = 0.08}) {
  final ls = <List<num>>[];
  for (int y = y0; y < y1; y += step) {
    for (int x = x0; x < x1; x += step) {
      final p = im.getPixel(x, y);
      ls.add([lum(p.r, p.g, p.b), p.r, p.g, p.b]);
    }
  }
  ls.sort((a, b) => b[0].compareTo(a[0]));
  final take = (ls.length * pct).round().clamp(1, ls.length);
  num r = 0, g = 0, b = 0;
  for (int i = 0; i < take; i++) {
    r += ls[i][1];
    g += ls[i][2];
    b += ls[i][3];
  }
  return [(r / take).round(), (g / take).round(), (b / take).round()];
}

String fmt(List<int> c) =>
    'rgb(${c[0]},${c[1]},${c[2]}) L=${lum(c[0], c[1], c[2]).round()}';

void main() {
  final shot = img.decodeImage(
    File('$root/ops/wallpaper_work/target_screenshot.jpg').readAsBytesSync(),
  )!;
  stdout.writeln('SCREENSHOT ${shot.width}x${shot.height}');
  // Clean wallpaper bands (avoid status bar/header ~0-235, the centre pill
  // ~980-1140, and the bottom button/nav ~2150+).
  for (final band in [
    [260, 430],
    [560, 940],
    [1200, 1650],
    [1750, 2120],
  ]) {
    final bg = avgRegion(shot, 40, band[0], shot.width - 40, band[1]);
    final d = brightAvg(shot, 40, band[0], shot.width - 40, band[1]);
    stdout.writeln(
        '  y${band[0]}-${band[1]}: bg=${fmt(bg)}  doodle=${fmt(d)}  '
        'doodleΔL=${(lum(d[0], d[1], d[2]) - lum(bg[0], bg[1], bg[2])).round()}');
  }
  stdout.writeln('ORIGINALS:');
  for (int i = 1; i <= 13; i++) {
    final f = File('$root/originals_backup/secure$i.png');
    if (!f.existsSync()) continue;
    final im = img.decodeImage(f.readAsBytesSync())!;
    final bg = avgRegion(im, 0, 0, im.width, im.height);
    final d = brightAvg(im, 0, 0, im.width, im.height);
    stdout.writeln(
        '  secure$i: bg=${fmt(bg)}  doodle=${fmt(d)}  '
        'doodleΔL=${(lum(d[0], d[1], d[2]) - lum(bg[0], bg[1], bg[2])).round()}');
  }
}
