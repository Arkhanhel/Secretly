// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import 'app_background.dart';

/// Global flag that toggles the route-level fade overlay painted from
/// `main.dart`. It is driven by a counter of currently-mounted
/// [BottomSystemFadeVisibility] widgets that asked for the fade to be
/// suppressed — so nested or sequential disablers don't clobber each
/// other when one of them unmounts.
final ValueNotifier<bool> bottomSystemFadeEnabled = ValueNotifier<bool>(true);

int _bottomSystemFadeSuppressors = 0;

void _addSuppressor() {
  _bottomSystemFadeSuppressors++;
  if (_bottomSystemFadeSuppressors > 0 && bottomSystemFadeEnabled.value) {
    bottomSystemFadeEnabled.value = false;
  }
}

void _removeSuppressor() {
  if (_bottomSystemFadeSuppressors == 0) return;
  _bottomSystemFadeSuppressors--;
  if (_bottomSystemFadeSuppressors == 0 && !bottomSystemFadeEnabled.value) {
    bottomSystemFadeEnabled.value = true;
  }
}

class BottomSystemFadeVisibility extends StatefulWidget {
  const BottomSystemFadeVisibility({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<BottomSystemFadeVisibility> createState() =>
      _BottomSystemFadeVisibilityState();
}

class _BottomSystemFadeVisibilityState
    extends State<BottomSystemFadeVisibility> {
  bool _suppressing = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant BottomSystemFadeVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _sync();
    }
  }

  void _sync() {
    final shouldSuppress = !widget.enabled;
    if (shouldSuppress && !_suppressing) {
      _suppressing = true;
      _addSuppressor();
    } else if (!shouldSuppress && _suppressing) {
      _suppressing = false;
      _removeSuppressor();
    }
  }

  @override
  void dispose() {
    if (_suppressing) {
      _suppressing = false;
      _removeSuppressor();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Soft fade painted at the bottom of routes / panels. Dissolves into the page
/// background colour (theme-adaptive: darkest gradient shade on dark, page tint
/// on light) so it blends with the wallpaper/preset instead of a black band.
/// The ramp uses an ease-in curve so the top is barely visible and only the
/// lower half carries real opacity.
class SystemBottomFadeLayer extends StatelessWidget {
  const SystemBottomFadeLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Fade into the actual page background colour (theme-adaptive: darkest
    // gradient shade on dark, page tint on light) instead of pure black, so the
    // shading dissolves into the theme background rather than a black band.
    final tint = AppBackground.scrimColorOf(context);
    final maxAlpha = isDark ? 0.96 : 0.92;
    // Ease-in curve: alpha rises slowly at the top, accelerates toward the
    // bottom. The top ~30% is essentially invisible so the fade never reads
    // as a hard band creeping up over panels — it just thickens into the
    // system-nav edge.
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.30, 0.55, 0.78, 1.0],
            colors: [
              tint.withValues(alpha: 0.0),
              tint.withValues(alpha: maxAlpha * 0.04),
              tint.withValues(alpha: maxAlpha * 0.18),
              tint.withValues(alpha: maxAlpha * 0.55),
              tint.withValues(alpha: maxAlpha),
            ],
          ),
        ),
      ),
    );
  }
}
