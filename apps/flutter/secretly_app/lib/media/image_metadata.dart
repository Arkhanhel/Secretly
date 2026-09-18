// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// TZ E1 (2026-07-18, privacy): pixel-lossless JPEG metadata strip.
///
/// Rewrites ONLY the EXIF APP1 segment (`injectJpgExif` — the entropy-coded
/// image data is untouched, so pixels stay byte-identical) dropping GPS
/// coordinates, capture timestamps, device serials and every other tag —
/// EXCEPT `Orientation`, which stays: without it a portrait photo renders
/// sideways on the receiving side.
///
/// Returns the ORIGINAL bytes unchanged when there is nothing to strip or on
/// ANY failure — callers may rely on "never throws, never corrupts".
Uint8List stripJpegMetadataKeepOrientation(Uint8List bytes) {
  try {
    final exif = img.decodeJpgExif(bytes);
    if (exif == null || exif.isEmpty) return bytes; // nothing to strip
    final minimal = img.ExifData();
    final orientation = exif.imageIfd['Orientation'];
    if (orientation != null) {
      minimal.imageIfd['Orientation'] = orientation;
    }
    final rewritten = img.injectJpgExif(bytes, minimal);
    if (rewritten == null || rewritten.isEmpty) return bytes;
    return rewritten;
  } catch (_) {
    return bytes;
  }
}
