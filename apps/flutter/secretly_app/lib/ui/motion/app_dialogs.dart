// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// М6: окна и нижние листы (docs/TZ_MOTION_TELEGRAM_PARITY_2026-11-20.md).
///
/// * [showAppDialog] — замена `showDialog` с тем же поведением (тема,
///   барьер, корневой навигатор, безопасная зона), но с появлением как в
///   iOS/Telegram: окно чуть «опускается» из 1,08 в 1,0 и проявляется по
///   кривой Telegram за 0,3 с; на Android — растёт из 0,94 по
///   `EmphasizedDecelerate` за 0,25 с. Закрытие — короткое затухание.
///   У Material было только затухание за 0,15 с — окно «вспыхивало».
/// * [appSheetAnimationStyle] — длительности нижних листов: iPhone 0,4 с
///   (как пружина листа Telegram), Android 0,3 с; закрытие 0,25 с.
///
/// Компьютер, выключенный [kTelegramMotion] — ровно прежний `showDialog` и
/// прежние длительности листов.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'motion.dart';

bool get _tgDialogs =>
    kTelegramMotion &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// Длительности нижних листов. `null` — прежние Material (компьютер).
AnimationStyle? get appSheetAnimationStyle {
  if (!_tgDialogs) return null;
  return defaultTargetPlatform == TargetPlatform.iOS
      ? const AnimationStyle(
          duration: Duration(milliseconds: 400),
          reverseDuration: Duration(milliseconds: 250),
        )
      : const AnimationStyle(
          duration: Duration(milliseconds: 300),
          reverseDuration: Duration(milliseconds: 250),
        );
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool fullscreenDialog = false,
  bool? requestFocus,
  AnimationStyle? animationStyle,
}) {
  if (!_tgDialogs || animationStyle != null) {
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      anchorPoint: anchorPoint,
      traversalEdgeBehavior: traversalEdgeBehavior,
      fullscreenDialog: fullscreenDialog,
      requestFocus: requestFocus,
      animationStyle: animationStyle,
    );
  }
  final nav = Navigator.of(context, rootNavigator: useRootNavigator);
  final themes = InheritedTheme.capture(from: context, to: nav.context);
  return nav.push<T>(
    _AppDialogRoute<T>(
      context: context,
      builder: builder,
      barrierColor:
          barrierColor ??
          DialogTheme.of(context).barrierColor ??
          Theme.of(context).dialogTheme.barrierColor ??
          Colors.black54,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      settings: routeSettings,
      themes: themes,
      anchorPoint: anchorPoint,
      traversalEdgeBehavior:
          traversalEdgeBehavior ?? TraversalEdgeBehavior.closedLoop,
      requestFocus: requestFocus,
      fullscreenDialog: fullscreenDialog,
    ),
  );
}

class _AppDialogRoute<T> extends DialogRoute<T> {
  _AppDialogRoute({
    required super.context,
    required super.builder,
    super.themes,
    super.barrierColor,
    super.barrierDismissible,
    super.barrierLabel,
    super.useSafeArea,
    super.settings,
    super.requestFocus,
    super.anchorPoint,
    super.traversalEdgeBehavior,
    super.fullscreenDialog,
  });

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Duration get transitionDuration => _ios
      ? MotionDurations.standard
      : const Duration(milliseconds: 250);

  @override
  Duration get reverseTransitionDuration =>
      const Duration(milliseconds: 160);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final ios = _ios;
    final reduced = motionReduced(context);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        final forward = animation.status != AnimationStatus.reverse;
        final k = forward
            ? (ios ? TgCurves.ios : TgCurves.emphasizedDecelerate).transform(t)
            : Curves.easeIn.transform(t);
        final from = ios ? 1.08 : 0.94;
        final scale = reduced || !forward ? 1.0 : from + (1 - from) * k;
        return Opacity(
          opacity: forward ? (t / 0.6).clamp(0.0, 1.0) : k,
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}
