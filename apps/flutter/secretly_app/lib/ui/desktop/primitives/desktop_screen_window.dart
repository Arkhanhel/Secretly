// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Мобильный экран — окном посередине, а не во всё окно приложения.
///
/// 🔴 ТЗ «ПК как Telegram» §8 (30.09.2026). «Создать группу», «Вступить в
/// комнату», сверка кодов безопасности и набор восстановления открывались на
/// ПК страницей во всё окно: телефонный экран растягивался на 1600 точек,
/// список чатов пропадал, а назад вела стрелка в углу. У Telegram Desktop те
/// же вещи — окно посередине над затемнённым приложением.
///
/// Экраны подключаются ЦЕЛИКОМ, без правок: вторая реализация под ПК
/// разошлась бы с телефонной на первой же правке (решение 13.09). Поэтому
/// окно устроено так, чтобы экран не заметил разницы:
///   · маршрут — страница с `fullscreenDialog`: полоса экрана сама рисует
///     крестик, а не стрелку назад, и `Navigator.pop(результат)` экрана
///     закрывает окно с этим результатом;
///   · размер экрана в [MediaQuery] — размер окна: разметка, считающая от
///     ширины «телефона», считает от окна;
///   · щелчок мимо окна и Escape закрывают его, как любое окно ПК.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Открыть [builder] окном посередине. Результат — то, с чем экран закрылся.
Future<T?> showDesktopScreenWindow<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double width = 520,
  double height = 760,
  bool rootNavigator = false,
}) {
  // Палитра места вызова едет в окно — см. [DColors.carry].
  final palette = DColors.maybeOf(context);
  final barrierLabel = MaterialLocalizations.of(
    context,
  ).modalBarrierDismissLabel;
  return Navigator.of(context, rootNavigator: rootNavigator).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      fullscreenDialog: true,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      barrierLabel: barrierLabel,
      transitionDuration: DMotion.medium,
      reverseTransitionDuration: DMotion.fast,
      pageBuilder: (ctx, animation, secondary) => DColors.carry(
        palette,
        _ScreenWindowFrame(width: width, height: height, builder: builder),
      ),
      transitionsBuilder: (ctx, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: DMotion.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class _ScreenWindowFrame extends StatelessWidget {
  const _ScreenWindowFrame({
    required this.width,
    required this.height,
    required this.builder,
  });

  final double width;
  final double height;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Поля до краёв главного окна: окно экрана не упирается в рамку.
    final w = math.min(width, math.max(320.0, media.size.width - 48));
    final h = math.min(height, math.max(360.0, media.size.height - 64));
    return Center(
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: DShadows.popover,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: MediaQuery(
            data: media.copyWith(
              size: Size(w, h),
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
  }
}
