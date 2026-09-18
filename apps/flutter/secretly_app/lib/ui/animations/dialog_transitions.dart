// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui';
import 'package:flutter/material.dart';

/// Telegram-style frosted popup dialog with scale-in + fade animation.
///
/// Use instead of `showGeneralDialog` for popup menus and action sheets.
Future<T?> showFrostedPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Alignment alignment = Alignment.topRight,
  Duration duration = const Duration(milliseconds: 200),
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'frosted_popup',
    barrierColor: Colors.black.withValues(alpha: 0.12),
    transitionDuration: duration,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          alignment: alignment,
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
  );
}

/// Animated bottom sheet with smooth slide-up + bounce.
Future<T?> showSecretlyBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = false,
  double? heightFactor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    backgroundColor: Colors.transparent,
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 260),
    ),
    builder: builder,
  );
}

/// Telegram-style message reactions dialog — grows OUT of the tapped bubble.
///
/// [scaleAlignment] is the tap point in screen-normalized Alignment space
/// (-1..1), so the popup appears to emerge from the bubble the user pressed
/// rather than scaling from screen-center. The soft easeOutBack overshoot is the
/// "bubble pop"; a slightly longer duration keeps it smooth, not abrupt.
Future<T?> showReactionDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Duration duration = const Duration(milliseconds: 230),
  Alignment scaleAlignment = Alignment.center,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'reaction_dialog',
    barrierColor: Colors.black.withValues(alpha: 0.24),
    transitionDuration: duration,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.6, end: 1.0).animate(curved),
          alignment: scaleAlignment,
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
  );
}

/// Blurred background wrapper for popup content.
class FrostedPopupContainer extends StatelessWidget {
  const FrostedPopupContainer({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.blurSigma = 18,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.34)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
