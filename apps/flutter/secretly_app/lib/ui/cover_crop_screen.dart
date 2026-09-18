// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import 'secretly_snackbar.dart';
import 'widgets/frosted_top_bar.dart';

/// Lets the user pan/zoom an image inside a banner-shaped frame and saves the
/// framed result as a PNG. Returns the saved file path via [Navigator.pop].
///
/// [aspectRatio] is the cover banner ratio (width / height). The frame matches
/// how the cover is shown on the profile, so what you see is what others get.
class CoverCropScreen extends StatefulWidget {
  const CoverCropScreen({
    super.key,
    required this.imagePath,
    this.aspectRatio = 2.0,
    this.circle = false,
    this.title = 'Подгоните обложку',
  });

  final String imagePath;
  final double aspectRatio;

  /// When true the frame is a 1:1 square with a circular guide overlay — used
  /// for fitting a round profile avatar.
  final bool circle;
  final String title;

  @override
  State<CoverCropScreen> createState() => _CoverCropScreenState();
}

class _CoverCropScreenState extends State<CoverCropScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _tc = TransformationController();
  bool _saving = false;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('encode failed');
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/cover_custom_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      Navigator.of(context).pop(path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(content: Text('Не удалось сохранить: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A6BFF),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0C0D11),
    );
    // The pan/zoom crop surface (captured by _boundaryKey on save). The circle
    // guide/scrim sits OUTSIDE the RepaintBoundary so it is never baked into the
    // saved image.
    final cropStack = Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          key: _boundaryKey,
          child: ColoredBox(
            color: Colors.black,
            child: InteractiveViewer(
              transformationController: _tc,
              minScale: 1,
              maxScale: 6,
              clipBehavior: Clip.hardEdge,
              child: Image.file(
                File(widget.imagePath),
                // Round avatar: show the WHOLE photo (letterboxed) so the user
                // positions the circle over the full image and zooms in to
                // taste. Cover banners keep the fill behaviour.
                fit: widget.circle ? BoxFit.contain : BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white38,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.circle)
          IgnorePointer(child: CustomPaint(painter: _CircleGuidePainter())),
      ],
    );
    final hint = Text(
      widget.circle
          ? 'Двигайте и приближайте фото — в круг попадёт то, что увидят другие.'
          : 'Двигайте и масштабируйте изображение в рамке, затем «Готово».',
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white70, fontSize: 13),
    );
    return Theme(
      data: dark,
      child: Scaffold(
        appBar: frostedAppBar(
          title: Text(widget.title),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Готово',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: widget.circle
              // FIX (2026-07-13): full-WIDTH crop area for round avatars (was a
              // small centred square inside 16px padding + a rounded card). The
              // circle guide is inscribed in the full-width square and the user
              // pans/zooms the whole photo. The photo is applied ONLY via
              // "Готово" (this screen pops null on back; callers must not fall
              // back to the original bytes).
              ? Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Full screen width; clamp to height so a tall square
                            // never overflows on short viewports.
                            final side =
                                constraints.maxWidth <= constraints.maxHeight
                                ? constraints.maxWidth
                                : constraints.maxHeight;
                            return SizedBox(
                              width: side,
                              height: side,
                              child: cropStack,
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: hint,
                    ),
                  ],
                )
              // Cover banner keeps the padded, rounded, aspect-ratio frame.
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: AspectRatio(
                            aspectRatio: widget.aspectRatio,
                            child: cropStack,
                          ),
                        ),
                        const SizedBox(height: 14),
                        hint,
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Runs picked image [bytes] through the round-avatar crop screen — the SAME
/// full-image pan/zoom flow used for your own profile photo and room avatars —
/// and returns the cropped PNG bytes. Returns the original [bytes] if the user
/// cancels (so the caller still sets a photo), or null if the context went away
/// mid-flow. Shared by the profile / room / contact avatar flows so every place
/// that sets a round photo gets the same "position over the full image" UX.
Future<Uint8List?> cropCircleAvatarBytes(
  BuildContext context,
  Uint8List bytes, {
  String title = 'Подгоните фото',
}) async {
  File tmp;
  try {
    tmp = File(
      '${Directory.systemTemp.path}/avatar_crop_src_'
      '${DateTime.now().microsecondsSinceEpoch}.img',
    );
    await tmp.writeAsBytes(bytes, flush: true);
  } catch (_) {
    return null; // couldn't stage the crop — do NOT apply an uncropped photo
  }
  if (!context.mounted) {
    try {
      await tmp.delete();
    } catch (_) {}
    return null;
  }
  // CoverCropScreen pops the cropped path on "Готово", or null on back/cancel.
  final croppedPath = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) =>
          CoverCropScreen(imagePath: tmp.path, circle: true, title: title),
    ),
  );
  Uint8List? result;
  if (croppedPath != null) {
    try {
      result = await File(croppedPath).readAsBytes();
    } catch (_) {
      result = null;
    }
  }
  try {
    await tmp.delete();
  } catch (_) {}
  // FIX (2026-07-13): null unless the user pressed "Готово" — on back/cancel the
  // caller must NOT apply the photo (was falling back to the raw picked bytes).
  return result;
}

/// Dims everything outside an inscribed circle and outlines it — the round crop
/// guide shown over the square avatar frame.
class _CircleGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      scrim,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white70,
    );
  }

  @override
  bool shouldRepaint(_CircleGuidePainter oldDelegate) => false;
}
