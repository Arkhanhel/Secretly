// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Telegram-style outgoing-video compression.
///
/// A raw phone capture (4K / 50-60 Mbps HEVC or H.264) is huge, so on a slow
/// uplink it "sends forever". Telegram re-encodes to H.264 at a capped
/// resolution + sane bitrate before upload — visually very close, a fraction of
/// the bytes. We do the same: cap the LONGER edge at 1920 (1080p), CRF 25,
/// `veryfast`, AAC 128k, `+faststart`. Rotation is baked into pixels by the
/// re-encode so the receiver sees it upright.
class VideoCompressor {
  VideoCompressor._();

  /// Skip files already this small — re-encoding them saves little and only
  /// costs CPU/time. Public so the upload worker can predict whether a compress
  /// phase will run (and thus reserve the first half of the progress ring).
  static const int skipBelowBytes = 3 * 1024 * 1024; // 3 MB

  /// Video duration in ms (via ffprobe), or 0 if unknown. Used to turn ffmpeg's
  /// per-frame statistics into a 0..1 compression fraction for the UI ring.
  static Future<int> _probeDurationMs(String sourcePath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(sourcePath);
      final secs = double.tryParse(
        session.getMediaInformation()?.getDuration() ?? '',
      );
      if (secs != null && secs > 0) return (secs * 1000).round();
    } catch (_) {}
    return 0;
  }

  /// Compresses [sourcePath] for sending. Returns the compressed file path, or
  /// the ORIGINAL path if compression is skipped, fails, or doesn't shrink the
  /// file (never makes it larger). Never throws.
  ///
  /// [onProgress] reports the re-encode's completion fraction (0..1) as it runs
  /// — the caller drives the upload ring with it so a long compress of a big
  /// video no longer looks frozen at 0%. Fires only when the duration is known.
  static Future<String> compressForSend(
    String sourcePath, {
    void Function(double fraction)? onProgress,
  }) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return sourcePath;
      final srcLen = await src.length();
      if (srcLen <= skipBelowBytes) return sourcePath;

      final tmpDir = await getTemporaryDirectory();
      final outDir = Directory(p.join(tmpDir.path, 'vsend'));
      await outDir.create(recursive: true);
      final outPath = p.join(
        outDir.path,
        '${p.basenameWithoutExtension(sourcePath)}_c.mp4',
      );
      final outFile = File(outPath);
      if (await outFile.exists()) {
        try {
          await outFile.delete();
        } catch (_) {}
      }

      final durationMs = await _probeDurationMs(sourcePath);

      // scale: fit inside 1920x1920 keeping aspect, downscale only (never
      // upscale), and force even dimensions (libx264 requires them).
      const cmd =
          '-y -i {SRC} '
          "-vf \"scale='min(1920,iw)':'min(1920,ih)':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2\" "
          '-c:v libx264 -preset veryfast -crf 25 -pix_fmt yuv420p '
          '-c:a aac -b:a 128k -movflags +faststart {OUT}';
      final full = cmd
          .replaceAll('{SRC}', "'$sourcePath'")
          .replaceAll('{OUT}', "'$outPath'");

      // Async execution so the statistics callback can stream progress; the
      // complete callback resolves the completer with the return code.
      final completer = Completer<ReturnCode?>();
      await FFmpegKit.executeAsync(
        full,
        (session) async {
          try {
            if (!completer.isCompleted) {
              completer.complete(await session.getReturnCode());
            }
          } catch (_) {
            if (!completer.isCompleted) completer.complete(null);
          }
        },
        null,
        (stats) {
          if (onProgress != null && durationMs > 0) {
            final t = stats.getTime();
            if (t > 0) onProgress((t / durationMs).clamp(0.0, 1.0));
          }
        },
      );
      final rc = await completer.future;
      if (!ReturnCode.isSuccess(rc) ||
          !await outFile.exists() ||
          await outFile.length() <= 0) {
        return sourcePath;
      }
      // Only use the re-encode if it actually shrank the file.
      if (await outFile.length() >= srcLen) {
        try {
          await outFile.delete();
        } catch (_) {}
        return sourcePath;
      }
      onProgress?.call(1.0);
      return outPath;
    } catch (_) {
      return sourcePath;
    }
  }

  static bool isVideoMime(String mime) => mime.toLowerCase().startsWith('video/');
}
