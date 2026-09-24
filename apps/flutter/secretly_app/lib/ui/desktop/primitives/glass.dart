// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../../widgets/frosted_header_island.dart'
    show GlassHighlightBorderPainter, IslandOuterShadowPainter;
import '../../widgets/island_backdrop.dart' show islandBackdropFilter;
import '../design/tokens.dart';

/// Матовое стекло компьютера — ТОТ ЖЕ рецепт, что у островков телефона.
///
/// 🔴 ЗАЧЕМ ОДИН ПРИМИТИВ (24.09.2026, указание владельца). Шапка переписки,
/// поле ввода, поиск и папки над списком чатов стали островками из матового
/// стекла, «как в мобильной версии». Рецепт телефона
/// (`FrostedIslandRowGroup` в `widgets/frosted_header_island.dart`):
/// размытие фона с насыщенностью, мягкая белая заливка сверху вниз, блик по
/// верхней кромке, в светлой теме — внешняя тень. Разойдись он по местам —
/// островки одного окна были бы из разного стекла.
///
/// Кисти блика и тени — те же, что у телефона, импортом, а не копией: так
/// стекло двух устройств не разъедется при следующей правке.
///
/// [grouped] — стекло внутри [BackdropGroup] читает фон ОДИН раз на всю
/// группу, а не на каждый островок: пять папок над списком иначе делали бы
/// пять проходов размытия на каждый кадр прокрутки.
class DesktopGlass extends StatelessWidget {
  const DesktopGlass({
    super.key,
    required this.child,
    this.radius = 16,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.blurSigma = 22,
    this.grouped = false,
    this.highlight = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Цвет поверх стекла — например, акцент у выбранной папки. `null` — только
  /// стекло.
  final Color? tint;
  final double blurSigma;
  final bool grouped;

  /// Блик по верхней кромке. Выключают у совсем мелких островков, где штрих
  /// толщиной в точку читается как рамка, а не как свет.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final dark = c.isDark;
    final fillTop = dark
        ? Colors.white.withValues(alpha: 0.085)
        : Colors.white.withValues(alpha: 0.62);
    final fillBottom = dark
        ? Colors.white.withValues(alpha: 0.045)
        : Colors.white.withValues(alpha: 0.50);
    final br = BorderRadius.circular(radius);
    final filter = islandBackdropFilter(sigmaX: blurSigma, sigmaY: blurSigma);

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillTop, fillBottom],
        ),
        borderRadius: br,
      ),
      child: tint == null
          ? Padding(padding: padding, child: child)
          : DecoratedBox(
              decoration: BoxDecoration(color: tint, borderRadius: br),
              child: Padding(padding: padding, child: child),
            ),
    );
    Widget glass = ClipRRect(
      borderRadius: br,
      child: grouped
          ? BackdropFilter.grouped(filter: filter, child: body)
          : BackdropFilter(filter: filter, child: body),
    );
    if (highlight) {
      glass = CustomPaint(
        foregroundPainter: GlassHighlightBorderPainter(
          radius: radius,
          strokeWidth: 1.1,
          color: dark
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.55),
        ),
        child: glass,
      );
    }
    // На светлом фоне стекло без тени растворяется: белое на белом. На тёмном
    // тень не видна и только стоит проходов.
    if (!dark) {
      glass = CustomPaint(
        painter: IslandOuterShadowPainter(
          radius: radius,
          color: const Color(0x14000000),
          blur: 8,
          dy: 1.5,
        ),
        child: glass,
      );
    }
    return glass;
  }
}

/// Затенение под плавающими островками: от цвета поверхности у края к полной
/// прозрачности.
///
/// Стекло над лентой без него читается хуже: светлые пузыри, проезжая под
/// островком, делают его то светлее, то темнее. Затенение даёт стеклу ровное
/// основание у самого края и сходит на нет туда, где лента уже видна целиком.
class DesktopEdgeShade extends StatelessWidget {
  const DesktopEdgeShade({
    super.key,
    required this.color,
    this.fromTop = true,
    this.strength = 1,
  });

  final Color color;
  final bool fromTop;

  /// Непрозрачность у самого края. Над лентой переписки — мягче: стекло шапки
  /// должно показывать проезжающие сообщения, а не сплошной цвет.
  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              color.withValues(alpha: strength),
              color.withValues(alpha: 0.82 * strength),
              color.withValues(alpha: 0.35 * strength),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.35, 0.72, 1],
          ),
        ),
      ),
    );
  }
}
