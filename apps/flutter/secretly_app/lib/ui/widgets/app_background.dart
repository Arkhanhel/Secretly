// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

/// Carries the app's global background gradient down the widget tree so that
/// pushed routes can paint it themselves.
///
/// Every Scaffold in the app is transparent (`scaffoldBackgroundColor:
/// Colors.transparent`) and sits over a single gradient painted once in
/// `MyApp.builder`. That made pages bleed through each other during route
/// transitions: the incoming transparent page showed the outgoing page's
/// content, and when the (opaque) route finished the outgoing page was removed
/// abruptly — the background "popped in".
///
/// Wrapping each pushed page in [AppGradientBackdrop] gives it its own opaque
/// gradient that slides in *with* the page, so the transition stays clean.
class AppBackground extends InheritedWidget {
  const AppBackground({
    super.key,
    required this.gradient,
    required super.child,
  });

  final Gradient gradient;

  static Gradient? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppBackground>()?.gradient;

  /// The solid colour a cover/scrim should dissolve into so it blends with the
  /// actual page background on every theme: the darkest shade of the page
  /// gradient on dark themes, the page tint (gradient bottom) on light themes.
  /// Falls back to the surface colour when no [AppBackground] is in scope.
  static Color scrimColorOf(BuildContext context) {
    final colors = maybeOf(context)?.colors;
    final theme = Theme.of(context);
    if (colors != null && colors.isNotEmpty) {
      if (theme.brightness == Brightness.dark) {
        return colors.reduce(
          (a, b) => a.computeLuminance() <= b.computeLuminance() ? a : b,
        );
      }
      return colors.last;
    }
    return theme.colorScheme.surface;
  }

  @override
  bool updateShouldNotify(AppBackground oldWidget) =>
      oldWidget.gradient != gradient;
}

/// Paints the inherited [AppBackground] gradient behind [child]. No-op when no
/// [AppBackground] is in scope (e.g. routes outside the main app shell), so it
/// is always safe to wrap a page with it.
class AppGradientBackdrop extends StatelessWidget {
  const AppGradientBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gradient = AppBackground.maybeOf(context);
    if (gradient == null) return child;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: child,
    );
  }
}
