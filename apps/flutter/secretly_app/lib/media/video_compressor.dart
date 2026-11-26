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
import '../build_variant.dart';
import 'h264_encoder.dart';

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
  ///
  /// 🔴 В облегчённой сборке порог поднят выше любого файла. Это ОДНА точка, по
  /// которой отправщик (`app_controller`) решает, будет ли фаза сжатия: иначе
  /// он честно зарезервировал бы под неё первую половину кольца, а она так и
  /// простояла бы на нуле — сжимать нечем.
  static const int skipBelowBytes = kVideoToolsAvailable
      ? 3 * 1024 * 1024 // 3 MB
      : 0x7fffffffffffffff;

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
  /// [maxSide] — длинная сторона (SendFlow 24.11.2026: 480 → 854,
  /// 720 → 1280, 1080 → 1920); [mute] — без звуковой дорожки (`-an`).
  /// С выбранным качеством ниже 1080p или без звука файл пережимается и
  /// когда он меньше [skipBelowBytes] — иначе выбор человека не сработал бы.
  static Future<String> compressForSend(
    String sourcePath, {
    void Function(double fraction)? onProgress,
    int maxSide = 1920,
    bool mute = false,
  }) async {
    // Облегчённая сборка: FFmpeg нет — файл уходит как снят, без сжатия.
    if (!kVideoToolsAvailable) return sourcePath;
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return sourcePath;
      final srcLen = await src.length();
      final forced = mute || maxSide < 1920;
      if (srcLen <= skipBelowBytes && !forced) return sourcePath;

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
      // upscale), and force even dimensions (H.264 encoders require them).
      final side = maxSide.clamp(320, 1920);
      final audio = mute ? '-an' : '-c:a aac -b:a 128k';
      final cmd =
          '-y -i {SRC} '
          "-vf \"scale='min($side,iw)':'min($side,ih)':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2\" "
          '{VIDEO} '
          '$audio -movflags +faststart {OUT}';

      // Кодер — по лицензии сборки FFmpeg (04.10.2026): на телефоне
      // системный H.264, на компьютере libx264. Запасной MPEG-4 на Android
      // здесь не нужен: картинку до 1920 iPhone в нём не покажет, а при
      // сбое и так уходит оригинал.
      final variants = H264Encoder.variants(
        crf: side <= 854 ? 28 : (side <= 1280 ? 26 : 25),
        kbps: side <= 854 ? 1000 : (side <= 1280 ? 2200 : 4000),
        fallback: H264Encoder.platform != H264Platform.android,
      );
      ReturnCode? rc;
      for (final videoArgs in variants) {
        final full = cmd
            .replaceAll('{VIDEO}', videoArgs)
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
        rc = await completer.future;
        if (ReturnCode.isSuccess(rc) &&
            await outFile.exists() &&
            await outFile.length() > 0) {
          break;
        }
      }
      if (!ReturnCode.isSuccess(rc) ||
          !await outFile.exists() ||
          await outFile.length() <= 0) {
        return sourcePath;
      }
      // Only use the re-encode if it actually shrank the file (без звука —
      // всегда: дорожку надо убрать, даже если файл не стал меньше).
      if (!mute && await outFile.length() >= srcLen) {
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

  /// Длинная сторона для качества «480/720/1080p» (SendFlow).
  static int maxSideForQuality(int quality) => switch (quality) {
    <= 480 => 854,
    <= 720 => 1280,
    _ => 1920,
  };

  static bool isVideoMime(String mime) => mime.toLowerCase().startsWith('video/');
}
