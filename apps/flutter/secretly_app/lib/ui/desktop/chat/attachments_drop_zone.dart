// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../design/tokens.dart';

/// Overlay that appears when files are dragged over the thread.
/// Pure visual — wire actual drop callbacks at the caller using your
/// preferred drag-drop plugin (desktop_drop, super_drag_and_drop, etc.).
class AttachmentsDropZone extends StatelessWidget {
  const AttachmentsDropZone({super.key, required this.visible, this.message});

  final bool visible;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: DMotion.fast,
        child: Container(
          color: c.accentPrimary.withValues(alpha: 0.10),
          padding: const EdgeInsets.all(DSpace.l),
          child: _DashedBorderBox(
            color: c.accentPrimary,
            radius: DRadii.r16,
            dash: 8,
            gap: 6,
            strokeWidth: 2,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.arrow_download_24_regular,
                      size: 56, color: c.accentPrimary),
                  const SizedBox(height: DSpace.m),
                  Text(
                    message ?? 'Отпустите, чтобы отправить',
                    style: DType.title.copyWith(color: c.accentPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Файлы будут зашифрованы перед отправкой',
                    style: DType.caption.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderBox extends StatelessWidget {
  const _DashedBorderBox({
    required this.child,
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });
  final Widget child;
  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: color,
        radius: radius,
        dash: dash,
        gap: gap,
        strokeWidth: strokeWidth,
      ),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });
  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double dist = 0;
      while (dist < m.length) {
        final next = (dist + dash).clamp(0.0, m.length);
        final segment = m.extractPath(dist, next);
        canvas.drawPath(segment, paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dash != dash ||
      old.gap != gap ||
      old.strokeWidth != strokeWidth;
}
