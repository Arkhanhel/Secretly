// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

/// Animated scan-line overlay for QR code scanning.
///
/// Shows a horizontal glowing line that sweeps vertically
/// across the scan area, like a real barcode scanner.
class ScanLineOverlay extends StatefulWidget {
  const ScanLineOverlay({
    super.key,
    this.lineColor,
    this.scanDuration = const Duration(milliseconds: 2400),
    this.lineThickness = 2.5,
    this.glowRadius = 12.0,
  });

  final Color? lineColor;
  final Duration scanDuration;
  final double lineThickness;
  final double glowRadius;

  @override
  State<ScanLineOverlay> createState() => _ScanLineOverlayState();
}

class _ScanLineOverlayState extends State<ScanLineOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.scanDuration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.lineColor ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ScanLinePainter(
            progress: _controller.value,
            color: color,
            lineThickness: widget.lineThickness,
            glowRadius: widget.glowRadius,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter({
    required this.progress,
    required this.color,
    required this.lineThickness,
    required this.glowRadius,
  });

  final double progress;
  final Color color;
  final double lineThickness;
  final double glowRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // Linear sweep top-to-bottom
    final linearY = size.height * progress;

    // Corner brackets
    _paintCornerBrackets(canvas, size);

    // Glow
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.4),
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromCenter(
        center: Offset(size.width / 2, linearY),
        width: size.width,
        height: glowRadius * 2,
      ));
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, linearY),
        width: size.width * 0.85,
        height: glowRadius * 2,
      ),
      glowPaint,
    );

    // Main scan line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = lineThickness
      ..strokeCap = StrokeCap.round;

    final margin = size.width * 0.1;
    canvas.drawLine(
      Offset(margin, linearY),
      Offset(size.width - margin, linearY),
      linePaint,
    );
  }

  void _paintCornerBrackets(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = 28.0;
    const margin = 16.0;

    // Top-left
    canvas.drawLine(const Offset(margin, margin + len), const Offset(margin, margin), paint);
    canvas.drawLine(const Offset(margin, margin), const Offset(margin + len, margin), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - margin - len, margin), Offset(size.width - margin, margin), paint);
    canvas.drawLine(Offset(size.width - margin, margin), Offset(size.width - margin, margin + len), paint);

    // Bottom-left
    canvas.drawLine(Offset(margin, size.height - margin - len), Offset(margin, size.height - margin), paint);
    canvas.drawLine(Offset(margin, size.height - margin), Offset(margin + len, size.height - margin), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - margin, size.height - margin - len), Offset(size.width - margin, size.height - margin), paint);
    canvas.drawLine(Offset(size.width - margin - len, size.height - margin), Offset(size.width - margin, size.height - margin), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => progress != old.progress;
}

/// Animated QR code reveal — fades in + subtle scale.
class AnimatedQrReveal extends StatefulWidget {
  const AnimatedQrReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;

  @override
  State<AnimatedQrReveal> createState() => _AnimatedQrRevealState();
}

class _AnimatedQrRevealState extends State<AnimatedQrReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
