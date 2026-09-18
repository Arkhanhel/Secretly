// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({
    super.key,
    required this.child,
    this.enabled = true,
    this.onTap,
  });

  final Widget child;
  final bool enabled;

  /// Optional extra callback fired when an empty area is tapped, in addition to
  /// dismissing the keyboard (used to shimmer the animated chat wallpaper in
  /// "on tap" mode).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onTap?.call();
      },
      child: child,
    );
  }
}