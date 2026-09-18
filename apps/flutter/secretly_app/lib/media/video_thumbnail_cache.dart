// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A still frame lifted out of a video, plus how long the video runs.
class VideoThumbnail {
  const VideoThumbnail({required this.file, this.durationMs});

  /// The extracted JPEG, already on disk.
  final File file;

  /// Playback length, probed at extraction time. Null when ffprobe couldn't
  /// tell — do NOT read [AttachmentEventV1.durationMs] instead: despite its
  /// name that field is only ever filled in for video notes and voice, so a
  /// normal video sent from the picker carries nothing.
  final int? durationMs;
}

/// Extracts (once, then forever from disk) a poster frame for a video so
/// galleries and bubbles can show a real preview instead of a blank card.
///
/// Keyed by blob id, which is content-addressed — the same video reached from
/// the chat, the peer's profile and the room's profile shares one cached frame.
///
/// Deliberately NOT built on `VideoPlayerController`: a player per cell means a
/// hardware decoder per cell, and the media grids lay out every cell at once.
class VideoThumbnailCache {
  VideoThumbnailCache._();

  /// Longest edge of the cached frame. Comfortably covers both a grid cell and
  /// a desktop video bubble, so one cache entry serves every surface.
  static const int _maxEdge = 536;

  /// Each extraction is a native ffmpeg session. A media grid has no viewport
  /// virtualization (shrinkWrap + NeverScrollableScrollPhysics), so it builds
  /// ALL of its cells at once — an ungated fan-out would start a hundred
  /// decoders on a chat with a hundred videos. Extractions queue through this
  /// gate instead and cells show their placeholder until a frame lands.
  static const int _maxConcurrent = 2;

  static int _running = 0;
  static final Queue<Completer<void>> _waiting = Queue<Completer<void>>();

  /// In-flight/among-rebuild memo, so a FutureBuilder never re-runs ffmpeg.
  static final Map<String, Future<VideoThumbnail?>> _memo =
      <String, Future<VideoThumbnail?>>{};

  /// Completed results, readable SYNCHRONOUSLY. A FutureBuilder always spends
  /// at least one frame without data even when the future is long done — in a
  /// scrolling chat that frame is the black blink between the placeholder and
  /// the poster. Callers check [peek] first and skip the async path entirely.
  static final Map<String, VideoThumbnail> _done = <String, VideoThumbnail>{};

  static VideoThumbnail? peek(String key) => _done[key];

  /// Poster frame for [videoPath], cached under [key] (pass the blob id).
  ///
  /// Returns null when the frame can't be produced — a missing/rejected file is
  /// never memoised as a failure, so a later call retries once the blob lands.
  static Future<VideoThumbnail?> forVideo({
    required String key,
    required String videoPath,
  }) {
    if (key.isEmpty || videoPath.isEmpty) {
      return Future<VideoThumbnail?>.value(null);
    }
    return _memo.putIfAbsent(key, () => _resolve(key, videoPath));
  }

  static Future<void> _acquire() {
    if (_running < _maxConcurrent) {
      _running++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    return waiter.future;
  }

  static void _release() {
    // Hand the slot straight to the next waiter rather than dropping and
    // re-taking it, so _running can never dip and let an extra session in.
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
      return;
    }
    _running--;
  }

  static Future<Directory> _cacheDir() async {
    // getTemporaryDirectory(), not Directory.systemTemp: on mobile the latter
    // is not dependably the app's own cache.
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'vthumb'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<VideoThumbnail?> _resolve(String key, String videoPath) async {
    try {
      if (!File(videoPath).existsSync()) {
        _memo.remove(key); // blob not downloaded yet — allow a retry
        return null;
      }
      final dir = await _cacheDir();
      final safeKey = key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final jpg = File(p.join(dir.path, '$safeKey.jpg'));
      // Duration rides alongside the frame so a cache hit costs one small read
      // instead of another ffprobe session.
      final durFile = File(p.join(dir.path, '$safeKey.dur'));

      if (await _isUsable(jpg)) {
        final hit = VideoThumbnail(file: jpg, durationMs: await _readDur(durFile));
        _done[key] = hit;
        return hit;
      }

      await _acquire();
      try {
        // Another cell may have produced it while we sat in the queue.
        if (await _isUsable(jpg)) {
          final hit = VideoThumbnail(
            file: jpg,
            durationMs: await _readDur(durFile),
          );
          _done[key] = hit;
          return hit;
        }

        final durationMs = await _probeDurationMs(videoPath);
        // Seek ~0.5s in: the opening frame of a phone capture is very often
        // black. `-ss` before `-i` keeps it a cheap keyframe seek. Clips
        // shorter than that have nothing at 0.5s, so start at zero instead.
        final seekLate = durationMs == null || durationMs > 1000;
        var ok = await _extract(videoPath, jpg, atSeconds: seekLate ? 0.5 : 0);
        if (!ok && seekLate) {
          // Duration unknown and the seek landed past the end — retry at zero
          // rather than leave a short clip permanently without a preview.
          ok = await _extract(videoPath, jpg, atSeconds: 0);
        }
        if (!ok) {
          _memo.remove(key);
          return null;
        }
        if (durationMs != null && durationMs > 0) {
          try {
            await durFile.writeAsString('$durationMs');
          } catch (_) {
            // A missing sidecar only costs the badge, not the frame.
          }
        }
        final made = VideoThumbnail(file: jpg, durationMs: durationMs);
        _done[key] = made;
        return made;
      } finally {
        _release();
      }
    } catch (_) {
      _memo.remove(key);
      return null;
    }
  }

  static Future<bool> _extract(
    String videoPath,
    File out, {
    required double atSeconds,
  }) async {
    try {
      if (await out.exists()) await out.delete();
    } catch (_) {}
    // Downscale only — never blow a small video up to _maxEdge.
    final cmd =
        '-y -ss $atSeconds -i \'$videoPath\' -frames:v 1 '
        "-vf \"scale='min($_maxEdge,iw)':-1\" -q:v 4 '${out.path}'";
    try {
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) return false;
      return await _isUsable(out);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isUsable(File f) async {
    try {
      return await f.exists() && await f.length() > 0;
    } catch (_) {
      return false;
    }
  }

  static Future<int?> _readDur(File f) async {
    try {
      if (!await f.exists()) return null;
      return int.tryParse((await f.readAsString()).trim());
    } catch (_) {
      return null;
    }
  }

  static Future<int?> _probeDurationMs(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final secs = double.tryParse(
        session.getMediaInformation()?.getDuration() ?? '',
      );
      if (secs != null && secs > 0) return (secs * 1000).round();
    } catch (_) {}
    return null;
  }
}

/// `mm:ss` (or `h:mm:ss`) for a duration badge.
String formatVideoDuration(int durationMs) {
  final total = (durationMs / 1000).round().clamp(0, 359999);
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}
