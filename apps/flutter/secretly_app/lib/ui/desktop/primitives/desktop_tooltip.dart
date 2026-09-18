// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../design/tokens.dart';

class DesktopTooltip extends StatelessWidget {
  const DesktopTooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 500),
    this.preferBelow = false,
  });

  final String message;
  final Widget child;
  final Duration waitDuration;
  final bool preferBelow;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Tooltip(
      message: message,
      waitDuration: waitDuration,
      preferBelow: preferBelow,
      // Tooltips render in the root overlay, ABOVE the app's Material, so they
      // cannot rely on it for the ambient text style — the decoration is
      // pinned here as well as in the token.
      textStyle: DType.caption.copyWith(
        color: c.textPrimary,
        decoration: TextDecoration.none,
      ),
      padding: const EdgeInsets.symmetric(horizontal: DSpace.m, vertical: DSpace.xs),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(DRadii.sm),
        border: Border.all(color: c.borderSubtle),
        boxShadow: DShadows.popover,
      ),
      child: child,
    );
  }
}
