// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Backs up the current live dark-theme wallpapers, then writes the darkened
// masters into assets/Background/secureN.jpg (high quality to preserve the
// very subtle doodle outlines).
//   dart run tool/apply_wallpapers.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const root = '/Users/yuriiarkhangelsky/dev/Secretly-code';

void main() {
  final assetsDir = Directory('$root/apps/flutter/secretly_app/assets/Background');
  final backup = Directory('$root/ops/wallpaper_work/live_backup')
    ..createSync(recursive: true);
  int n = 0;
  for (int i = 1; i <= 13; i++) {
    final dark = File('$root/ops/wallpaper_work/darkened/secure$i.png');
    if (!dark.existsSync()) continue;
    final target = File('${assetsDir.path}/secure$i.jpg');
    if (target.existsSync()) {
      target.copySync('${backup.path}/secure$i.jpg');
    }
    final im = img.decodeImage(dark.readAsBytesSync())!;
    target.writeAsBytesSync(img.encodeJpg(im, quality: 92));
    n++;
    stdout.writeln('applied secure$i.jpg (${target.lengthSync() ~/ 1024} KB)');
  }
  stdout.writeln('done: $n wallpapers applied; live backup → ${backup.path}');
}
