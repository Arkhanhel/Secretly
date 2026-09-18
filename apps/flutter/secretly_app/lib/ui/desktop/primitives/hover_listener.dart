// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

/// Reports hover state plus simple press state. Cursor defaults to click.
class HoverListener extends StatefulWidget {
  const HoverListener({
    super.key,
    required this.builder,
    this.onTap,
    this.onSecondaryTapDown,
    this.cursor = SystemMouseCursors.click,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget Function(BuildContext, bool hovered, bool pressed) builder;
  final VoidCallback? onTap;
  final void Function(TapDownDetails)? onSecondaryTapDown;
  final MouseCursor cursor;
  final HitTestBehavior behavior;

  @override
  State<HoverListener> createState() => _HoverListenerState();
}

class _HoverListenerState extends State<HoverListener> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
        onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: widget.builder(context, _hovered, _pressed),
      ),
    );
  }
}
