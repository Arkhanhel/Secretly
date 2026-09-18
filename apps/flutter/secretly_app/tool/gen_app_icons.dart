// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Generates premium alternate app-icon masters (1024²) by compositing the
// transparent Secretly mark on styled backgrounds. Output: tool/generated_app_icons/.
// Run: dart run tool/gen_app_icons.dart
// ignore_for_file: avoid_print — this is a dev-only CLI generator script.
import 'dart:io';
import 'package:image/image.dart' as img;

const int kSize = 1024;

int _c(num v) => v.round().clamp(0, 255);

(int, int, int) _lerp(List<List<int>> stops, double t) {
  t = t.clamp(0.0, 1.0);
  final seg = 1.0 / (stops.length - 1);
  var i = (t / seg).floor();
  if (i > stops.length - 2) i = stops.length - 2;
  final lt = (t - i * seg) / seg;
  final a = stops[i], b = stops[i + 1];
  return (
    _c(a[0] + (b[0] - a[0]) * lt),
    _c(a[1] + (b[1] - a[1]) * lt),
    _c(a[2] + (b[2] - a[2]) * lt),
  );
}

void gen(img.Image mark, String name, List<List<int>> stops) {
  final canvas = img.Image(width: kSize, height: kSize);
  for (var y = 0; y < kSize; y++) {
    for (var x = 0; x < kSize; x++) {
      final (r, g, b) = _lerp(stops, (x + y) / (2.0 * kSize));
      canvas.setPixelRgb(x, y, r, g, b);
    }
  }
  final scaled = img.copyResize(mark, width: (kSize * 0.60).round());
  img.compositeImage(
    canvas,
    scaled,
    dstX: (kSize - scaled.width) ~/ 2,
    dstY: (kSize - scaled.height) ~/ 2,
  );
  final dir = Directory('tool/generated_app_icons')
    ..createSync(recursive: true);
  File('${dir.path}/icon_$name.png').writeAsBytesSync(img.encodePng(canvas));
  print('wrote icon_$name.png ${canvas.width}x${canvas.height}');
}

void main() {
  final mark = img.decodeImage(
    File('assets/app_ui/icons/png/premium_logo.png').readAsBytesSync(),
  )!;
  gen(mark, 'midnight', [[12, 13, 17], [12, 13, 17]]);
  gen(mark, 'ocean', [[74, 107, 255], [142, 91, 255]]);
  gen(mark, 'sunset', [[226, 26, 0], [255, 122, 0], [255, 213, 74]]);
  gen(mark, 'emerald', [[15, 81, 50], [0, 199, 190]]);
  gen(mark, 'graphite', [[42, 45, 52], [12, 13, 17]]);
}
