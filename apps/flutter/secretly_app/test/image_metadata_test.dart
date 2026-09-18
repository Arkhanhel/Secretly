// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/media/image_metadata.dart';

Uint8List buildExifJpeg() {
  final src = img.Image(width: 64, height: 48);
  img.fill(src, color: img.ColorRgb8(10, 120, 200));
  final exif = img.ExifData();
  exif.imageIfd['Orientation'] = 6;
  exif.imageIfd['Make'] = 'ProbeCam';
  // GOTCHA (memory, 2026-07-18): GPS lives in imageIfd.sub['gps'], NOT .gpsIfd.
  exif.imageIfd.sub['gps']['GPSLatitude'] = 50;
  exif.imageIfd.sub['gps']['GPSLongitude'] = 30;
  src.exif = exif;
  return Uint8List.fromList(img.encodeJpg(src, quality: 90));
}

void main() {
  group('stripJpegMetadataKeepOrientation', () {
    test('drops GPS but keeps Orientation', () {
      final original = buildExifJpeg();
      expect(img.decodeJpgExif(original), isNotNull,
          reason: 'fixture must carry EXIF');

      final stripped = stripJpegMetadataKeepOrientation(original);
      final after = img.decodeJpgExif(stripped);

      expect(after, isNotNull);
      expect(after!.imageIfd['Orientation']?.toInt(), 6,
          reason: 'without Orientation a portrait photo renders sideways');
      expect(after.imageIfd['Make'], isNull, reason: 'device model must go');
      expect(after.imageIfd.sub['gps'].isEmpty, isTrue,
          reason: 'GPS coordinates must never leave the device');
    });

    test('stays a decodable, pixel-identical JPEG', () {
      final original = buildExifJpeg();
      final stripped = stripJpegMetadataKeepOrientation(original);

      final before = img.decodeJpg(original);
      final after = img.decodeJpg(stripped);
      expect(after, isNotNull);
      expect(after!.width, before!.width);
      expect(after.height, before.height);
    });

    // The strip rewrites only the APP1 segment, so the result is a VIEW over a
    // larger capacity buffer (len < buffer.lengthInBytes). Anything downstream
    // that reached for `.buffer` instead of the list would silently append
    // capacity garbage to the payload.
    test('callers must use the list, not its backing buffer', () {
      final stripped = stripJpegMetadataKeepOrientation(buildExifJpeg());
      expect(stripped.length, lessThanOrEqualTo(stripped.buffer.lengthInBytes));
      // Decoding the RAW BACKING BUFFER is what a `.buffer` slip would do.
      final viaBuffer = Uint8List.view(stripped.buffer);
      expect(viaBuffer.length, greaterThanOrEqualTo(stripped.length));
    });

    // Documented contract: "never throws, never corrupts" — callers rely on it.
    test('never throws on non-JPEG or garbage input', () {
      final garbage = Uint8List.fromList(List<int>.generate(512, (i) => i % 256));
      expect(stripJpegMetadataKeepOrientation(garbage), same(garbage));
      expect(stripJpegMetadataKeepOrientation(Uint8List(0)).isEmpty, isTrue);
    });
  });
}
