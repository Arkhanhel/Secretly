// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show MethodChannel;
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// One detected subject in a photo: a **full-frame** PNG with only this subject
/// visible (the rest transparent, aligned to the source image) plus its pixel
/// [bounds] in the source (for tap hit-testing + the selection highlight).
class StickerSubject {
  const StickerSubject({required this.maskedPngPath, required this.bounds});

  final String maskedPngPath;
  final Rect bounds;
}

/// Result of segmenting a photo: source dimensions + every detected subject.
class StickerSegmentation {
  const StickerSegmentation({
    required this.srcWidth,
    required this.srcHeight,
    required this.subjects,
  });

  final int srcWidth;
  final int srcHeight;
  final List<StickerSubject> subjects;

  bool get isEmpty => subjects.isEmpty;
}

/// On-device AI subject cutout for the sticker maker.
///
/// Fully **on-device** (ML Kit Subject Segmentation on Android, Vision
/// `VNGenerateForegroundInstanceMaskRequest` on iOS 17+) — the photo never
/// leaves the phone, consistent with Secretly's privacy model. Detects every
/// subject so the editor can let the user pick which ones to keep.
class StickerSegmentationService {
  StickerSegmentationService._();
  static final StickerSegmentationService instance =
      StickerSegmentationService._();

  /// Sticker canvas longest side (App Store / Telegram parity is 512).
  static const int _canvas = 512;

  /// Native cutout channel — iOS uses Vision (the ML Kit Subject Segmentation
  /// pod is Android-only). See ios/Runner/AppDelegate.swift.
  static const MethodChannel _channel = MethodChannel('secretly/sticker_ai');

  SubjectSegmenter? _segmenter;

  SubjectSegmenter get _ensureSegmenter =>
      _segmenter ??= SubjectSegmenter(
        options: SubjectSegmenterOptions(
          // Per-subject bitmaps (for multi-select); we compose the foreground
          // ourselves, so the combined foreground bitmap isn't needed.
          enableForegroundBitmap: false,
          enableForegroundConfidenceMask: false,
          enableMultipleSubjects: SubjectResultOptions(
            enableConfidenceMask: false,
            enableSubjectBitmap: true,
          ),
        ),
      );

  /// Detect every subject in [sourcePath]. Each is a full-frame masked PNG +
  /// bounds. Returns null on failure / no subjects (caller keeps the original).
  Future<StickerSegmentation?> segment(String sourcePath) async {
    try {
      final src = img.decodeImage(await File(sourcePath).readAsBytes());
      if (src == null) return null;
      final srcW = src.width;
      final srcH = src.height;

      final framePaths = Platform.isIOS
          ? await _segmentIosFrames(sourcePath)
          : await _segmentAndroidFrames(sourcePath, srcW, srcH);
      if (framePaths.isEmpty) return null;

      final subjects = <StickerSubject>[];
      for (final path in framePaths) {
        final bounds =
            await _nonTransparentBounds(path) ??
            Rect.fromLTWH(0, 0, srcW.toDouble(), srcH.toDouble());
        subjects.add(StickerSubject(maskedPngPath: path, bounds: bounds));
      }
      if (subjects.isEmpty) return null;
      return StickerSegmentation(
        srcWidth: srcW,
        srcHeight: srcH,
        subjects: subjects,
      );
    } catch (_) {
      return null;
    }
  }

  /// Convenience single-shot cutout (all subjects combined) for callers that
  /// don't need per-subject selection. Returns the final sticker PNG path.
  Future<String?> cutoutToPng(String sourcePath) async {
    final seg = await segment(sourcePath);
    if (seg == null || seg.isEmpty) return null;
    return composeSticker(
      seg.subjects.map((s) => s.maskedPngPath).toList(growable: false),
    );
  }

  /// iOS: ask Vision for one full-frame masked PNG per detected instance.
  Future<List<String>> _segmentIosFrames(String sourcePath) async {
    final res = await _channel.invokeMethod<List<dynamic>>('segment', {
      'path': sourcePath,
    });
    if (res == null) return const <String>[];
    return res.whereType<String>().where((p) => p.isNotEmpty).toList();
  }

  /// Android: ML Kit returns per-subject cropped bitmaps + bounds; rebuild each
  /// as a full-frame masked PNG (subject placed at its source position).
  Future<List<String>> _segmentAndroidFrames(
    String sourcePath,
    int srcW,
    int srcH,
  ) async {
    final result = await _ensureSegmenter.processImage(
      InputImage.fromFilePath(sourcePath),
    );
    final out = <String>[];
    final dir = await getTemporaryDirectory();
    for (final subject in result.subjects) {
      final bmp = subject.bitmap;
      if (bmp == null || bmp.isEmpty) continue;
      final cropped = img.decodeImage(bmp);
      if (cropped == null) continue;
      final frame = img.Image(width: srcW, height: srcH, numChannels: 4);
      img.compositeImage(
        frame,
        cropped,
        dstX: subject.startX,
        dstY: subject.startY,
      );
      final path =
          '${dir.path}/sticker_subj_${out.length}_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(img.encodePng(frame), flush: true);
      out.add(path);
    }
    return out;
  }

  /// Compose the chosen subjects (full-frame masked PNGs) into one sticker:
  /// stack alpha-over → trim transparent → fit the 512px canvas → PNG path.
  Future<String?> composeSticker(List<String> subjectPngPaths) async {
    try {
      if (subjectPngPaths.isEmpty) return null;
      img.Image? canvas;
      for (final path in subjectPngPaths) {
        final layer = img.decodeImage(await File(path).readAsBytes());
        if (layer == null) continue;
        canvas ??= img.Image(
          width: layer.width,
          height: layer.height,
          numChannels: 4,
        );
        img.compositeImage(canvas, layer);
      }
      if (canvas == null) return null;
      final sized = _fitToCanvas(_trimTransparent(canvas));
      final out = Uint8List.fromList(img.encodePng(sized, level: 9));
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/sticker_compose_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(out, flush: true);
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Bounding box of the non-transparent pixels of [pngPath], in source pixels.
  Future<Rect?> _nonTransparentBounds(String pngPath) async {
    try {
      final im = img.decodeImage(await File(pngPath).readAsBytes());
      if (im == null) return null;
      var minX = im.width, minY = im.height, maxX = -1, maxY = -1;
      for (var y = 0; y < im.height; y++) {
        for (var x = 0; x < im.width; x++) {
          if (im.getPixel(x, y).a > 8) {
            if (x < minX) minX = x;
            if (y < minY) minY = y;
            if (x > maxX) maxX = x;
            if (y > maxY) maxY = y;
          }
        }
      }
      if (maxX < minX) return null;
      return Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Crop [src] to the bounding box of its non-transparent pixels (+ margin).
  img.Image _trimTransparent(img.Image src) {
    var minX = src.width, minY = src.height, maxX = -1, maxY = -1;
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        if (src.getPixel(x, y).a > 8) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < minX || maxY < minY) return src;
    const pad = 2;
    final x0 = (minX - pad).clamp(0, src.width - 1);
    final y0 = (minY - pad).clamp(0, src.height - 1);
    final x1 = (maxX + pad).clamp(0, src.width - 1);
    final y1 = (maxY + pad).clamp(0, src.height - 1);
    return img.copyCrop(
      src,
      x: x0,
      y: y0,
      width: x1 - x0 + 1,
      height: y1 - y0 + 1,
    );
  }

  /// Downscale [src] so its longest side is at most [_canvas] (preserve alpha).
  img.Image _fitToCanvas(img.Image src) {
    final longest = src.width >= src.height ? src.width : src.height;
    if (longest <= _canvas) return src;
    final tallest = src.height > src.width;
    return img.copyResize(
      src,
      width: tallest ? null : _canvas,
      height: tallest ? _canvas : null,
      interpolation: img.Interpolation.average,
    );
  }

  Future<void> dispose() async {
    await _segmenter?.close();
    _segmenter = null;
  }
}
