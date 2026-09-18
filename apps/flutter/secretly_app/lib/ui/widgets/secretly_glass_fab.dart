// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui';

import 'package:flutter/material.dart';

class SecretlyGlassFabButton extends StatelessWidget {
  const SecretlyGlassFabButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.dimension = 56,
    this.cornerRadius = 26,
    this.blurSigma = 20,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double dimension;
  final double cornerRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox.square(
      dimension: dimension,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withValues(alpha: 0.90),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.14),
                  blurRadius: 8,
                  spreadRadius: -2,
                  offset: const Offset(-1, -1),
                ),
              ],
            ),
            child: IconButton(
              tooltip: tooltip,
              color: colors.onPrimary,
              onPressed: onPressed,
              icon: icon,
            ),
          ),
        ),
      ),
    );
  }
}