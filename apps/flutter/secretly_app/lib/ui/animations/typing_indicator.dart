// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated "typing…" indicator with three bouncing dots (iMessage/Telegram style).
///
/// Usage:
/// ```dart
/// const TypingIndicator()
/// ```
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({
    super.key,
    this.dotSize = 7.0,
    this.spacing = 4.0,
    this.color,
    this.duration = const Duration(milliseconds: 1200),
  });

  final double dotSize;
  final double spacing;
  final Color? color;
  final Duration duration;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(right: i < 2 ? widget.spacing : 0),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Each dot has a phase offset: 0.0, 0.2, 0.4
              final phase = (i * 0.2);
              final t = (_controller.value + phase) % 1.0;
              // Smooth bounce using sine
              final bounce = math.sin(t * math.pi).clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(0, -bounce * 5),
                child: child,
              );
            },
            child: Container(
              width: widget.dotSize,
              height: widget.dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Typing indicator wrapped in a chat bubble (shown in the message list).
class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key, this.peerName});

  final String? peerName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(18),
          ),
          child: TypingIndicator(
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
