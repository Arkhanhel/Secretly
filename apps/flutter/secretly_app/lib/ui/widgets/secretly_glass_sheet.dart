// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui';

import 'package:flutter/material.dart';

import 'island_backdrop.dart';

class SecretlyGlassSheetHandle extends StatelessWidget {
  const SecretlyGlassSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class SecretlyGlassSheetSurface extends StatelessWidget {
  const SecretlyGlassSheetSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(30)),
    this.blurSigma = 22,
    this.flushToEdges = false,
  });

  final Widget child;
  final BorderRadiusGeometry borderRadius;
  final double blurSigma;

  /// Лист занимает всю ширину и упирается в низ экрана.
  ///
  /// Тогда рамка нужна только сверху: слева, справа и снизу она легла бы на сами
  /// края экрана и читалась бы как случайная линия, а не как край листа.
  final bool flushToEdges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 🔴 НЕЙТРАЛЬНО, КАК ОСТРОВКИ. Раньше лист брал `topBarTop`/`topBarBottom` —
    // градиент шапки чата, то есть цвет акцента темы. На тонкой шапке это
    // читается как оттенок, а на листе в две трети экрана — как «покрашено в
    // цвет индикаторов». Островки же берут нейтральную плиту с намёком темы
    // всего в 6 процентов, и лист теперь берёт ту же плиту.
    final base = opaquePanelFill(context);
    final top = base;
    final bottom = isDark
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.14), base)
        : Color.alphaBlend(
            colors.surfaceContainerHighest.withValues(alpha: 0.55),
            base,
          );
    // Прозрачность выше прежней намеренно: нейтральный цвет укрывает хуже
    // насыщенного, и на тех же значениях сквозь лист просвечивали бы обои.
    final topAlpha = isDark ? 0.68 : 0.82;
    final bottomAlpha = isDark ? 0.62 : 0.76;

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.56);
    final border = flushToEdges
        ? Border(top: BorderSide(color: borderColor))
        : Border.all(color: borderColor);

    // Стекло выключено — рисуем плиту без блюра, как это делают островки. Это
    // ещё и самая дешёвая поверхность: один непрозрачный прямоугольник.
    if (!PanelPrefs.frostedEnabled.value) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: base,
              border: border,
              borderRadius: borderRadius,
            ),
            child: Material(color: Colors.transparent, child: child),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.14),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  top.withValues(alpha: topAlpha),
                  bottom.withValues(alpha: bottomAlpha),
                ],
              ),
              border: border,
              borderRadius: borderRadius,
            ),
            child: Material(color: Colors.transparent, child: child),
          ),
        ),
      ),
    );
  }
}