// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:secretly_app/ui/apple_glass.dart';
import '../motion/motion.dart';
import '../widgets/apple_menu.dart';

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
  // iPhone: меню «⋯» вырастает из угла кнопки, как `UIMenu` — масштаб
  // 0,6 → 1 по кривой Telegram, проявление в первой половине; закрытие —
  // короткое (0,9 и затухание). Android: окна — `EmphasizedDecelerate`.
  final ios = appleMenusEnabled(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'frosted_popup',
    barrierColor: Colors.black.withValues(alpha: ios ? 0.08 : 0.12),
    transitionDuration: ios ? const Duration(milliseconds: 320) : duration,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (ios) {
        final reduced = motionReduced(context);
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final t = animation.value;
            final forward = animation.status != AnimationStatus.reverse;
            final k = forward
                ? TgCurves.ios.transform(t)
                : Curves.easeIn.transform(t);
            final scale = reduced
                ? 1.0
                : (forward ? 0.6 + 0.4 * k : 0.9 + 0.1 * k);
            return Opacity(
              opacity: forward ? (t / 0.45).clamp(0.0, 1.0) : k,
              child: Transform.scale(
                scale: scale,
                alignment: alignment,
                child: child,
              ),
            );
          },
        );
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Motion.sheet,
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
        curve: Motion.pop,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Motion.fade),
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
    this.padding = _menuPadding,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final EdgeInsetsGeometry padding;

  static const EdgeInsetsGeometry _menuPadding = EdgeInsets.symmetric(
    vertical: 6,
  );

  @override
  Widget build(BuildContext context) {
    // iPhone: одна панель меню iOS на все всплывающие меню. Строки меню
    // (AppMenuRow) — во всю ширину, без отступов сверху и снизу; свой
    // отступ (окно ввода имени папки) сохраняется.
    if (appleMenusEnabled(context)) {
      return AppleMenuPanel(
        child: padding == _menuPadding
            ? child
            : Padding(padding: padding, child: child),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        // iPhone (20.11.2026): меню — стекло iOS со светлой кромкой.
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: appleGlassPanelsEnabled
              ? ShapeDecoration(
                  shape: AppleGlassBorder(
                    radius: borderRadius,
                    dark: Theme.of(context).brightness == Brightness.dark,
                  ),
                )
              : const BoxDecoration(),
          child: DecoratedBox(
          decoration: BoxDecoration(
            color: appleBlurredFillOr(
              context,
              cs.surface.withValues(alpha: 0.76),
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: appleGlassPanelsEnabled
                ? null
                : Border.all(color: cs.outlineVariant.withValues(alpha: 0.34)),
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
      ),
    );
  }
}
