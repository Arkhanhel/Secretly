// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Telegram-style three-dot typing indicator.
///
/// Three dots bounce in a staggered loop (opacity + scale) driven by a single
/// [AnimationController], so it is cheap to mount in a chat header or list row.
/// No Lottie / asset dependency.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, required this.color, this.size = 6});

  /// Fill color of the dots (typically the accent / "Online" indicator color).
  final Color color;

  /// Diameter of a single dot in logical pixels.
  final double size;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // One full bounce cycle. Each dot is phase-shifted across the period so the
  // bounce visibly travels left → right.
  static const Duration _period = Duration(milliseconds: 1100);
  static const int _dotCount = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Eased 0→1→0 bounce for [t] (0..1) with a per-dot [phase] offset.
  double _bounce(double t, double phase) {
    var p = (t + phase) % 1.0;
    if (p < 0) p += 1.0;
    // Active for the first 60% of the cycle, resting (flat low) for the rest —
    // this is what gives the staggered "wave" rather than all dots pulsing.
    const active = 0.6;
    if (p >= active) return 0.0;
    final x = p / active; // 0..1 over the active window
    return math.sin(x * math.pi); // smooth up-and-down
  }

  @override
  Widget build(BuildContext context) {
    final dot = widget.size;
    final gap = (dot * 0.5).clamp(2.0, 5.0);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < _dotCount; i++) ...[
                if (i > 0) SizedBox(width: gap),
                _buildDot(_bounce(t, -i / _dotCount * 0.6)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDot(double b) {
    // b: 0 (resting) .. 1 (peak of bounce).
    final scale = 0.7 + (b * 0.5); // 0.7 .. 1.2
    final opacity = (0.4 + (b * 0.6)).clamp(0.0, 1.0); // 0.4 .. 1.0
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
