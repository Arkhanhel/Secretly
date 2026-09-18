// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

/// Procedural "live sticker" motion effects applied to a static cutout. Kept
/// transform-only (scale / rotate / translate) so every effect preserves the
/// cutout's alpha and loops seamlessly — no per-pixel work, no external assets.
enum StickerMotionEffect { pulse, bounce, wobble, tada }

extension StickerMotionEffectMeta on StickerMotionEffect {
  String get id => name;
  String get labelRu => switch (this) {
    StickerMotionEffect.pulse => 'Пульс',
    StickerMotionEffect.bounce => 'Прыжок',
    StickerMotionEffect.wobble => 'Качание',
    StickerMotionEffect.tada => 'Та-да',
  };

  static StickerMotionEffect? fromId(String raw) {
    for (final e in StickerMotionEffect.values) {
      if (e.name == raw) return e;
    }
    return null;
  }
}

/// Turns a static cutout PNG into an animated WebP ("live" sticker) entirely
/// on-device: render N transform frames with [dart:ui], then encode a looping,
/// full-alpha animated WebP via ffmpeg. Returns null on ANY failure (decode,
/// or ffmpeg without libwebp) so the caller falls back to the static sticker —
/// creation never hard-fails.
class StickerAnimationService {
  StickerAnimationService._();
  static final StickerAnimationService instance = StickerAnimationService._();

  static const int _frameCount = 24;
  static const int _fps = 20;
  static const int _maxSide = 320;
  // All frames render at this base inset so a rotate/translate effect has
  // headroom and never clips the cutout against the square edge.
  static const double _baseScale = 0.9;

  Future<File?> animate({
    required File cutoutPng,
    required StickerMotionEffect effect,
    double speed = 1.0,
  }) async {
    // Higher speed → higher playback fps → a shorter, snappier loop.
    final fps = (_fps * speed).round().clamp(8, 36);
    Directory? work;
    try {
      final bytes = await cutoutPng.readAsBytes();
      if (bytes.isEmpty) return null;
      final src = await _decode(bytes);

      final longest = math.max(src.width, src.height);
      if (longest <= 0) return null;
      final scale = longest > _maxSide ? _maxSide / longest : 1.0;
      final canvasSize = math.max(1, (longest * scale).round());

      final tmp = await getTemporaryDirectory();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      work = await Directory(
        '${tmp.path}/sticker_anim_$stamp',
      ).create(recursive: true);

      for (var i = 0; i < _frameCount; i++) {
        final phase = (i / _frameCount) * 2 * math.pi;
        final png = await _renderFrame(
          src,
          canvasSize.toDouble(),
          effect,
          phase,
        );
        await File(
          '${work.path}/f${i.toString().padLeft(3, '0')}.png',
        ).writeAsBytes(png, flush: true);
      }
      src.dispose();

      final out = File('${work.path}/out.webp');
      // image2 sequence → animated WebP (libwebp): looping, lossy q72, alpha kept.
      final cmd =
          "-y -framerate $fps -i '${work.path}/f%03d.png' "
          "-vcodec libwebp -lossless 0 -q:v 72 -compression_level 5 "
          "-loop 0 -an -vsync 0 '${out.path}'";
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (!ReturnCode.isSuccess(rc) ||
          !out.existsSync() ||
          await out.length() < 64) {
        return null;
      }

      // Copy out of the work dir before it's cleaned, into a stable temp path.
      final persisted = File('${tmp.path}/live_sticker_$stamp.webp');
      await out.copy(persisted.path);
      return persisted;
    } catch (_) {
      return null;
    } finally {
      if (work != null) {
        try {
          await work.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<Uint8List> _renderFrame(
    ui.Image src,
    double size,
    StickerMotionEffect effect,
    double phase,
  ) async {
    // 0..1 eased oscillation (seamless: sin returns to start at 2π).
    final osc = 0.5 + 0.5 * math.sin(phase);
    var scale = _baseScale;
    var dx = 0.0;
    var dy = 0.0;
    var rot = 0.0;
    switch (effect) {
      case StickerMotionEffect.pulse:
        scale = _baseScale * (0.94 + 0.06 * osc);
      case StickerMotionEffect.bounce:
        dy = -size * 0.05 * osc;
      case StickerMotionEffect.wobble:
        rot = 0.10 * math.sin(phase);
      case StickerMotionEffect.tada:
        scale = _baseScale * (0.95 + 0.05 * (0.5 + 0.5 * math.sin(phase * 2)));
        rot = 0.06 * math.sin(phase * 3);
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final center = size / 2;
    canvas.translate(center + dx, center + dy);
    canvas.rotate(rot);
    canvas.scale(scale);
    canvas.translate(-center, -center);
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true;
    canvas.drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, size, size),
      paint,
    );
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.round(), size.round());
    picture.dispose();
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    if (data == null) {
      throw StateError('frame encode failed');
    }
    return data.buffer.asUint8List();
  }
}
