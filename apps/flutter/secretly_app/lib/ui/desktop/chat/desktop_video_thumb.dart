// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../media/video_thumbnail_cache.dart';

/// Desktop-facing name for the shared [VideoThumbnailCache].
///
/// The extraction, the disk cache and the concurrency gate all live in the
/// shared service now — this used to own a second copy of them, which meant the
/// mobile galleries could not reuse any of it. Kept as a thin alias so the
/// desktop bubble's call site stays exactly as it was.
class DesktopVideoThumb {
  DesktopVideoThumb._();

  static Future<String?> forVideo({
    required String key,
    required String videoPath,
  }) async {
    final thumb = await VideoThumbnailCache.forVideo(
      key: key,
      videoPath: videoPath,
    );
    return thumb?.file.path;
  }
}
