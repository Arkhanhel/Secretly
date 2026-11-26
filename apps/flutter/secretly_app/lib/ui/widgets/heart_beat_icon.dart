// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Красное бьющееся сердце для меню (25.11.2026): тонкий контур той же
/// толщины, что у соседних знаков меню, двойной удар, от удара — тающий
/// отсвет. Системное «уменьшить движение» — сердце стоит.
class HeartBeatIcon extends StatefulWidget {
  const HeartBeatIcon({super.key, this.size = 22});

  final double size;

  static const Color red = Color(0xFFFF3B4E);

  @override
  State<HeartBeatIcon> createState() => _HeartBeatIconState();
}

class _HeartBeatIconState extends State<HeartBeatIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _beat.stop();
      _beat.value = 0;
    } else if (!_beat.isAnimating) {
      _beat.repeat();
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: HeartBeatPainter(_beat),
    ),
  );
}

@visibleForTesting
class HeartBeatPainter extends CustomPainter {
  HeartBeatPainter(this.beat) : super(repaint: beat);

  final Animation<double> beat;

  /// Удар с вершиной в [at]: 0 вне удара, 1 на вершине.
  static double _hit(double t, double at, double width) {
    final d = (t - at).abs() / width;
    return d >= 1 ? 0 : math.pow(math.cos(d * math.pi / 2), 2).toDouble();
  }

  static Path heart(Size s) {
    final w = s.width, h = s.height;
    Offset p(double x, double y) => Offset(w * x, h * y);
    final tip = p(0.5, 0.90), dip = p(0.5, 0.30);
    final path = Path()..moveTo(tip.dx, tip.dy);
    void c(Offset a, Offset b, Offset to) =>
        path.cubicTo(a.dx, a.dy, b.dx, b.dy, to.dx, to.dy);
    c(p(0.20, 0.70), p(0.06, 0.54), p(0.06, 0.36));
    c(p(0.06, 0.20), p(0.17, 0.10), p(0.29, 0.10));
    c(p(0.38, 0.10), p(0.46, 0.17), dip);
    c(p(0.54, 0.17), p(0.62, 0.10), p(0.71, 0.10));
    c(p(0.83, 0.10), p(0.94, 0.20), p(0.94, 0.36));
    c(p(0.94, 0.54), p(0.80, 0.70), tip);
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = beat.value;
    final hit = math.max(_hit(t, 0.12, 0.11), 0.65 * _hit(t, 0.34, 0.12));
    final path = heart(size);
    final center = size.center(Offset.zero);
    void scaled(double k, VoidCallback draw) {
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..scale(k)
        ..translate(-center.dx, -center.dy);
      draw();
      canvas.restore();
    }

    // Отсвет удара: контур расходится и тает.
    final wave = ((t - 0.14) / 0.5).clamp(0.0, 1.0);
    if (wave > 0 && wave < 1) {
      scaled(
        1.0 + 0.30 * wave,
        () => canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = HeartBeatIcon.red.withValues(alpha: 0.38 * (1 - wave)),
        ),
      );
    }
    scaled(0.92 + 0.12 * hit, () {
      canvas
        ..drawPath(
          path,
          Paint()
            ..color = HeartBeatIcon.red.withValues(alpha: 0.10 + 0.42 * hit),
        )
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.7
            ..strokeJoin = StrokeJoin.round
            ..color = HeartBeatIcon.red,
        );
    });
  }

  @override
  bool shouldRepaint(HeartBeatPainter old) => old.beat != beat;
}
