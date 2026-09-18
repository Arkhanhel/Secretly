// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import 'frosted_header_island.dart';

/// A neutral frosted-glass round icon button — the floating "island" control
/// (back / search / action) used in the app's iOS-style screens instead of a
/// solid top app bar. Liquid glass: blur + translucent gradient + specular
/// highlight, no solid colour.
///
/// Shared so every redesigned screen (profile icon picker, new chat, create
/// room, …) renders an identical floating control.
class GlassIconIsland extends StatelessWidget {
  const GlassIconIsland({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 44,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget island = FrostedHeaderIsland(
      radius: size / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: cs.onSurface),
        ),
      ),
    );
    if (tooltip != null) {
      island = Tooltip(message: tooltip!, child: island);
    }
    return island;
  }
}
