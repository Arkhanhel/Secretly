// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/media/image_metadata.dart';

// TZ E1 (2026-07-18): the privacy contract of the send-side JPEG scrubber.
// GPS/timestamps must not survive; Orientation must; pixels must be identical.
void main() {
  Uint8List jpegWithGpsAndOrientation() {
    final im = img.Image(width: 24, height: 16);
    img.fill(im, color: img.ColorRgb8(200, 30, 60));
    final jpg = Uint8List.fromList(img.encodeJpg(im, quality: 90));
    final exif = img.ExifData();
    exif.imageIfd['Orientation'] = 6; // rotated-portrait marker
    exif.imageIfd['Make'] = 'SecretlyTestCam';
    // GPS coordinates travel as a sub-IFD hung off IFD0 via pointer tag 34853
    // (probed against image 4.8.0: values written through `gpsIfd` round-trip
    // into `imageIfd.sub['gps']`).
    exif.gpsIfd['GPSLatitude'] = [55, 30, 10];
    exif.gpsIfd['GPSLongitude'] = 37.5;
    final withExif = img.injectJpgExif(jpg, exif);
    expect(withExif, isNotNull, reason: 'test fixture must build');
    return withExif!;
  }

  test('strips GPS + make, keeps Orientation, pixels identical', () {
    final source = jpegWithGpsAndOrientation();
    final sourceExif = img.decodeJpgExif(source)!;
    expect(
      sourceExif.imageIfd.sub.containsKey('gps'),
      isTrue,
      reason: 'fixture must actually carry a GPS sub-IFD',
    );
    expect(sourceExif.imageIfd['Make'], isNotNull);

    final stripped = stripJpegMetadataKeepOrientation(source);
    final exif = img.decodeJpgExif(stripped);

    // GPS sub-IFD + identifying tags gone.
    expect(exif?.imageIfd.sub.containsKey('gps') ?? false, isFalse);
    expect(exif?.imageIfd['Make'], isNull);
    // Orientation survives (portrait photos must not flip on the receiver).
    expect(exif?.imageIfd['Orientation']?.toInt(), 6);

    // Pixel-lossless: decoded pixel bytes are identical.
    final a = img.decodeJpg(source)!;
    final b = img.decodeJpg(stripped)!;
    expect(b.width, a.width);
    expect(b.height, a.height);
    expect(b.toUint8List(), a.toUint8List());
  });

  test('no-exif jpeg passes through unchanged', () {
    final im = img.Image(width: 8, height: 8);
    img.fill(im, color: img.ColorRgb8(10, 20, 30));
    final plain = Uint8List.fromList(img.encodeJpg(im, quality: 85));
    final out = stripJpegMetadataKeepOrientation(plain);
    expect(identical(out, plain) || out.length == plain.length, isTrue);
    expect(img.decodeJpg(out), isNotNull);
  });

  test('garbage bytes never throw and pass through', () {
    final junk = Uint8List.fromList(List<int>.generate(64, (i) => i * 3));
    final out = stripJpegMetadataKeepOrientation(junk);
    expect(out, junk);
  });
}
