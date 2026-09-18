// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/app/app_controller.dart';

Uint8List _smallSquareAvatarBytes() {
  final image = img.Image(width: 48, height: 48);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(
        x,
        y,
        0x24 + x * 2,
        0x6C + y,
        0x8F + ((x + y) ~/ 2),
        255,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _photoLikeAvatarBytes() {
  final image = img.Image(width: 768, height: 768);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final red = (x * 37 + y * 17 + ((x * y) ~/ 13)) & 0xff;
      final green = (x * 11 + y * 29 + (((x + y) * 7) ~/ 5)) & 0xff;
      final blue = ((x * 23) ^ (y * 19) ^ (((x * 13) + (y * 7)) ~/ 3)) & 0xff;
      image.setPixelRgba(x, y, red, green, blue, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

int _distinctRgbCount(img.Image image, {int stopAfter = 257}) {
  final seen = <int>{};
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      seen.add(
        (pixel.r.toInt() << 16) | (pixel.g.toInt() << 8) | pixel.b.toInt(),
      );
      if (seen.length >= stopAfter) {
        return seen.length;
      }
    }
  }
  return seen.length;
}

void main() {
  test('avatar encoder keeps already valid square PNG bytes unchanged', () {
    final input = _smallSquareAvatarBytes();

    final output = AppController.encodeProfileMetaAvatarPngForTesting(input);

    expect(output, isNotNull);
    expect(output, orderedEquals(input));
  });

  test(
    'avatar encoder stays within server cap without reducing opaque photos to 256 colors',
    () {
      final input = _photoLikeAvatarBytes();

      final output = AppController.encodeProfileMetaAvatarPngForTesting(input);

      expect(output, isNotNull);
      expect(output!.length, lessThanOrEqualTo(512000));

      final decoded = img.decodePng(output);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(1024));
      expect(decoded.height, equals(decoded.width));
      expect(_distinctRgbCount(decoded), greaterThan(256));
    },
  );
}
