// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Places the generated alternate-icon masters into the iOS asset catalog
// (AltIcon*.appiconset, 120/180 px) and Android mipmaps (48..192 px) per variant.
// Run after gen_app_icons.dart:  dart run tool/place_app_icons.dart
// ignore_for_file: avoid_print — this is a dev-only CLI placement script.
import 'dart:io';
import 'package:image/image.dart' as img;

const variants = ['midnight', 'ocean', 'sunset', 'emerald', 'graphite'];

String _cap(String s) => s[0].toUpperCase() + s.substring(1);

void main() {
  for (final v in variants) {
    final master = img.decodeImage(
      File('tool/generated_app_icons/icon_$v.png').readAsBytesSync(),
    )!;

    // ---- iOS: AltIcon{Cap}.appiconset with 60pt @2x (120) + @3x (180) ----
    final iosDir = Directory(
      'ios/Runner/Assets.xcassets/AltIcon${_cap(v)}.appiconset',
    )..createSync(recursive: true);
    for (final (scale, px) in [(2, 120), (3, 180)]) {
      File('${iosDir.path}/icon_$v@${scale}x.png').writeAsBytesSync(
        img.encodePng(img.copyResize(master, width: px, height: px)),
      );
    }
    File('${iosDir.path}/Contents.json').writeAsStringSync('''
{
  "images" : [
    { "size" : "60x60", "idiom" : "iphone", "filename" : "icon_$v@2x.png", "scale" : "2x" },
    { "size" : "60x60", "idiom" : "iphone", "filename" : "icon_$v@3x.png", "scale" : "3x" }
  ],
  "info" : { "version" : 1, "author" : "secretly" }
}
''');

    // ---- Android: ic_launcher_{v}.png in each density mipmap ----
    const densities = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    densities.forEach((d, px) {
      final dir = Directory('android/app/src/main/res/mipmap-$d')
        ..createSync(recursive: true);
      File('${dir.path}/ic_launcher_$v.png').writeAsBytesSync(
        img.encodePng(img.copyResize(master, width: px, height: px)),
      );
    });
    print('placed $v');
  }
  print('done');
}
