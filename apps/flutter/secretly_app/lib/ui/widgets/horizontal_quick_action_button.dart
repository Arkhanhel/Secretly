// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/material.dart';

class HorizontalQuickActionButton extends StatelessWidget {
  const HorizontalQuickActionButton({
    super.key,
    required this.title,
    required this.onTap,
    required this.iconTint,
    this.assetPath,
    this.icon,
    this.fallbackIcon,
  }) : assert(assetPath != null || icon != null || fallbackIcon != null);

  final String title;
  final FutureOr<void> Function() onTap;
  final Color iconTint;
  final String? assetPath;
  final IconData? icon;
  final IconData? fallbackIcon;

  Widget _buildIcon() {
    final iconData = icon ?? fallbackIcon;
    if (assetPath != null) {
      return Image.asset(
        assetPath!,
        width: 20,
        height: 20,
        color: iconTint,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, __, ___) {
          if (iconData == null) {
            return const SizedBox.shrink();
          }
          return Icon(iconData, size: 20, color: iconTint);
        },
      );
    }
    return Icon(iconData, size: 20, color: iconTint);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          await onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: iconTint.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Center(child: _buildIcon()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.08,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
