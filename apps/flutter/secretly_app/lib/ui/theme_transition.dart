// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Provides access to [ThemeTransitionLayerState] from any descendant widget.
class ThemeTransitionScope extends InheritedWidget {
  const ThemeTransitionScope({
    super.key,
    required this.state,
    required super.child,
  });

  final ThemeTransitionLayerState state;

  static ThemeTransitionLayerState? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ThemeTransitionScope>()
        ?.state;
  }

  @override
  bool updateShouldNotify(ThemeTransitionScope oldWidget) =>
      state != oldWidget.state;
}

/// Wraps the entire app and intercepts theme toggles to play a scale-zoom
/// animation: the old UI briefly zooms away from the tap origin while fading
/// out, revealing the new theme underneath.
///
/// Usage — place around your root content in [MaterialApp.builder]:
/// ```dart
/// builder: (context, child) => ThemeTransitionLayer(
///   onToggle: (v) => controller.setDarkMode(v),
///   child: YourRootContent(child: child),
/// ),
/// ```
///
/// Trigger from any widget:
/// ```dart
/// ThemeTransitionScope.of(context)?.triggerTransition(tapCenter, newValue);
/// ```
class ThemeTransitionLayer extends StatefulWidget {
  const ThemeTransitionLayer({
    super.key,
    required this.onToggle,
    required this.child,
  });

  /// Called after the screenshot is taken — should change the actual theme.
  final ValueChanged<bool> onToggle;
  final Widget child;

  @override
  State<ThemeTransitionLayer> createState() => ThemeTransitionLayerState();
}

class ThemeTransitionLayerState extends State<ThemeTransitionLayer>
    with SingleTickerProviderStateMixin {
  final _repaintKey = GlobalKey();

  ui.Image? _snapshot;
  Alignment _alignment = Alignment.center;
  bool _animating = false;

  late final AnimationController _ctrl;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        final img = _snapshot;
        setState(() {
          _animating = false;
          _snapshot = null;
        });
        _ctrl.reset();
        img?.dispose();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  /// Call this instead of directly calling [onToggle].
  /// [tapCenter] — global screen coordinates of the switch/button.
  /// [newDarkMode] — the new value to pass to [onToggle].
  Future<void> triggerTransition(Offset tapCenter, bool newDarkMode) async {
    // If already mid-animation, finish immediately and apply new value.
    if (_animating) {
      widget.onToggle(newDarkMode);
      return;
    }

    // Capture the current rendered frame.
    final boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      widget.onToggle(newDarkMode);
      return;
    }

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final ui.Image snapshot;
    try {
      snapshot = await boundary.toImage(pixelRatio: pixelRatio);
    } catch (_) {
      widget.onToggle(newDarkMode);
      return;
    }

    if (!mounted) {
      snapshot.dispose();
      return;
    }

    final size = MediaQuery.sizeOf(context);
    final alignment = Alignment(
      (((tapCenter.dx / size.width) * 2) - 1).clamp(-1.0, 1.0),
      (((tapCenter.dy / size.height) * 2) - 1).clamp(-1.0, 1.0),
    );

    setState(() {
      _snapshot = snapshot;
      _alignment = alignment;
      _animating = true;
    });

    widget.onToggle(newDarkMode);

    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeTransitionScope(
      state: this,
      child: RepaintBoundary(
        key: _repaintKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_animating && _snapshot != null)
              AnimatedBuilder(
                animation: _progress,
                builder: (_, __) {
                  final zoom = Curves.easeOutCubic.transform(_progress.value);
                  final fade = Curves.easeOutQuart.transform(_progress.value);
                  return Opacity(
                    opacity: (1.0 - fade).clamp(0.0, 1.0),
                    child: Transform.scale(
                      alignment: _alignment,
                      scale: ui.lerpDouble(1.0, 1.12, zoom) ?? 1.0,
                      child: RawImage(
                        image: _snapshot,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
