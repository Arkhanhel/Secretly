// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ignore_for_file: use_super_parameters

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

const secretlySnackBarDuration = Duration(seconds: 2);

class SecretlySnackBar extends SnackBar {
  SecretlySnackBar({
    super.key,
    required Widget content,
    Color? backgroundColor,
    double? elevation,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    double? width,
    ShapeBorder? shape,
    HitTestBehavior? hitTestBehavior,
    SnackBarBehavior? behavior,
    SnackBarAction? action,
    double? actionOverflowThreshold,
    bool? showCloseIcon,
    Color? closeIconColor,
    Duration? duration,
    bool? persist,
    Animation<double>? animation,
    VoidCallback? onVisible,
    DismissDirection? dismissDirection,
    Clip clipBehavior = Clip.hardEdge,
  }) : super(
         content: _SecretlySnackBarContent(child: content),
         backgroundColor: backgroundColor ?? Colors.transparent,
         elevation: elevation ?? 0,
         margin: margin,
         padding: padding ?? EdgeInsets.zero,
         width: width,
         shape:
             shape ??
             const RoundedRectangleBorder(
               borderRadius: BorderRadius.all(Radius.circular(18)),
             ),
         hitTestBehavior: hitTestBehavior,
         behavior: behavior ?? SnackBarBehavior.floating,
         action: action,
         actionOverflowThreshold: actionOverflowThreshold,
         showCloseIcon: showCloseIcon,
         closeIconColor: closeIconColor,
         duration: _shortenedDuration(duration),
         persist: persist,
         animation: animation,
         onVisible: onVisible,
         dismissDirection: dismissDirection ?? DismissDirection.horizontal,
         clipBehavior: clipBehavior,
       );
}

Duration _shortenedDuration(Duration? duration) {
  if (duration == null) {
    return secretlySnackBarDuration;
  }
  final milliseconds = duration.inMilliseconds;
  if (milliseconds <= 0) {
    return duration;
  }
  return Duration(milliseconds: math.max(800, (milliseconds / 2).round()));
}

class _SecretlySnackBarContent extends StatelessWidget {
  const _SecretlySnackBarContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final fill = Color.alphaBlend(
      scheme.primary.withValues(alpha: isDark ? 0.10 : 0.07),
      scheme.surface.withValues(alpha: isDark ? 0.58 : 0.68),
    );
    final border = scheme.outlineVariant.withValues(
      alpha: isDark ? 0.36 : 0.46,
    );
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: 0,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.10),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: IconTheme(
              data: IconThemeData(color: scheme.onSurface, size: 20),
              child: DefaultTextStyle.merge(style: textStyle, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
