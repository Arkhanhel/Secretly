// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

const String _sourceIconPath = '../../../1.png';

const Map<String, int> _androidIcons = <String, int>{
  'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
  'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
  'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
  'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
};

const Map<String, int> _iosIcons = <String, int>{
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': 120,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': 120,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': 180,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': 152,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png': 167,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png': 1024,
};

const String _windowsIconPath = 'windows/runner/resources/app_icon.ico';
const int _windowsIconSize = 256;

void main() {
  final rootPath = Directory.current.path;
  final sourceFile = File(p.join(rootPath, _sourceIconPath));
  if (!sourceFile.existsSync()) {
    stderr.writeln('Source icon not found: ${sourceFile.path}');
    exitCode = 1;
    return;
  }

  final sourceImage = img.decodeImage(sourceFile.readAsBytesSync());
  if (sourceImage == null) {
    stderr.writeln('Unable to decode source icon: ${sourceFile.path}');
    exitCode = 1;
    return;
  }

  for (final entry in _androidIcons.entries) {
    _writePng(
      path: p.join(rootPath, entry.key),
      sourceImage: sourceImage,
      size: entry.value,
    );
  }

  for (final entry in _iosIcons.entries) {
    _writePng(
      path: p.join(rootPath, entry.key),
      sourceImage: sourceImage,
      size: entry.value,
    );
  }

  _writeIco(
    path: p.join(rootPath, _windowsIconPath),
    sourceImage: sourceImage,
    size: _windowsIconSize,
  );

  stdout.writeln('Launcher icons generated from $_sourceIconPath');
}

void _writePng({
  required String path,
  required img.Image sourceImage,
  required int size,
}) {
  final resized = img.copyResize(
    sourceImage,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(resized, level: 6), flush: true);
}

void _writeIco({
  required String path,
  required img.Image sourceImage,
  required int size,
}) {
  final resized = img.copyResize(
    sourceImage,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
  final pngBytes = Uint8List.fromList(img.encodePng(resized, level: 6));
  final buffer = BytesBuilder(copy: false);

  buffer.add(const <int>[0, 0, 1, 0, 1, 0]);
  buffer.add(<int>[
    size >= 256 ? 0 : size,
    size >= 256 ? 0 : size,
    0,
    0,
    1,
    0,
    32,
    0,
  ]);

  final imageSizeBytes = ByteData(4)
    ..setUint32(0, pngBytes.lengthInBytes, Endian.little);
  final imageOffsetBytes = ByteData(4)
    ..setUint32(0, 22, Endian.little);
  buffer.add(imageSizeBytes.buffer.asUint8List());
  buffer.add(imageOffsetBytes.buffer.asUint8List());
  buffer.add(pngBytes);

  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(buffer.takeBytes(), flush: true);
}