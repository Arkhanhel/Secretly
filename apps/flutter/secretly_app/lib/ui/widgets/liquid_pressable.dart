// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

/// Telegram-style "press the jelly" feedback for icons that live ON our liquid
/// glass (2026-07-19). On tap-down the child squishes to [pressedScale] fast;
/// on release it springs back with a slight overshoot (elastic) so it reads
/// like poking soft glass.
///
/// Deliberately CHEAP: one AnimationController driving a single Transform.scale
/// — no shader, no layer, no repaint of anything but this widget. Nothing like
/// the per-frame cost of the glass itself, so it is safe to wrap many icons.
class LiquidPressable extends StatefulWidget {
  const LiquidPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.86,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool enabled;

  @override
  State<LiquidPressable> createState() => _LiquidPressableState();
}

/// Drop-in replacement for an [IconButton] that sits on liquid glass: same
/// 48px hit target, but the icon squishes and springs on press (iOS feel)
/// instead of a material ripple.
class LiquidIconButton extends StatelessWidget {
  const LiquidIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 24,
    this.color,
  });

  final IconData icon;

  /// `null` disables the button — it dims and stops responding, matching
  /// [IconButton]'s contract. Passing a no-op closure instead would leave it
  /// looking tappable while silently doing nothing.
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final resolved = color ?? IconTheme.of(context).color;
    final btn = LiquidPressable(
      onTap: onPressed,
      enabled: enabled,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          size: size,
          color: enabled ? resolved : resolved?.withValues(alpha: 0.38),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class _LiquidPressableState extends State<LiquidPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90), // press-in
    reverseDuration: const Duration(milliseconds: 320), // spring-back
    value: 0,
  );

  late final Animation<double> _scale = _c.drive(
    Tween<double>(begin: 1.0, end: widget.pressedScale).chain(
      // Snappy press-in; elastic release for the "jelly" rebound.
      CurveTween(curve: Curves.easeOut),
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) {
    if (!widget.enabled) return;
    _c.stop();
    _c.animateTo(1.0, curve: Curves.easeOut);
  }

  void _up() {
    if (!widget.enabled) return;
    _c.animateBack(0.0, curve: Curves.elasticOut);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: (_) => _up(),
      onTapCancel: _up,
      onTap: widget.enabled ? widget.onTap : null,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
