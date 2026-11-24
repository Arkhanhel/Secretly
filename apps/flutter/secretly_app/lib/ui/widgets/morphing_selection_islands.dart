// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../home/home_top_islands.dart' show HomeSectionIsland;
import 'frosted_header_island.dart';

/// Seamless "bubble morph" for the top list app-bar islands.
///
/// Renders TWO PERSISTENT frosted frames (left + right). Because the frames are
/// the same widgets in every state, the glass never disappears — only the
/// CONTENT layers inside cross-fade and the right frame's WIDTH lerps, so the
/// bubbles physically reshape between the normal, search and selection states
/// (e.g. logo ⇄ "✕ count", search/menu ⇄ bulk actions) instead of one island
/// set fading in on top of another.
///
/// Drive [searchReveal] (`s`, 0→1) and [selectionReveal] (`sel`, 0→1) from the
/// host screen's animations (a controller or a TweenAnimationBuilder). `sel` may
/// overshoot slightly above 1.0 (easeOutBack "bubble pop") — it is clamped for
/// opacity internally and used raw for the width lerp.
class MorphingSelectionIslands extends StatelessWidget {
  const MorphingSelectionIslands({
    super.key,
    required this.searchReveal,
    required this.selectionReveal,
    required this.leftNormalContent,
    required this.leftSelectionContent,
    required this.rightCompactContent,
    required this.rightSelectionContent,
    required this.islandRadius,
    required this.islandHeight,
    this.rightSearchContent,
    this.leftPadding = 14,
    this.compactRightWidth = 56,
    this.selectionActionsWidth = 256,
    this.centerLeftNormal = true,
    this.compactLeft = false,
    this.centerTitle,
  });

  final double searchReveal;
  final double selectionReveal;

  /// Left frame content in the normal state (logo / screen title).
  final Widget leftNormalContent;

  /// Left frame content in the selection state ("✕ count").
  final Widget leftSelectionContent;

  /// Right frame content in the normal, search-closed state (search + menu).
  final Widget rightCompactContent;

  /// Right frame content while the search field is open. Null on screens with
  /// no search (the search layer + width-to-full lerp are skipped).
  final Widget? rightSearchContent;

  /// Right frame content in the selection state (bulk actions).
  final Widget rightSelectionContent;

  final double islandRadius;
  final double islandHeight;
  final double leftPadding;

  /// Right frame width when compact (search closed, not selecting).
  final double compactRightWidth;

  /// Right frame width in the selection state — must comfortably fit the bulk
  /// action icons at full size.
  final double selectionActionsWidth;

  /// Whether the normal left content is centered (logo) vs left-aligned (title).
  final bool centerLeftNormal;

  /// Острова v3: левый островок по размеру содержимого (название приложения),
  /// правый прижат вправо. `false` — прежняя раскладка во всю ширину.
  final bool compactLeft;

  /// Острова v3: название раздела в отдельном островке посередине (только
  /// при [compactLeft]). Гаснет в поиске и выделении.
  final String? centerTitle;

  @override
  Widget build(BuildContext context) {
    final s = searchReveal.clamp(0.0, 1.0);
    final selO = selectionReveal.clamp(0.0, 1.0);
    final hasSearch = rightSearchContent != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final normalRightW = hasSearch
            ? lerpDouble(compactRightWidth, total, s)!
            : compactRightWidth;
        // 🔴 22.11.2026: место слева под «✕ + число» (≈92) на любом экране.
        final selRightW = compactLeft
            ? math.min(selectionActionsWidth, total - 92)
            : selectionActionsWidth;
        final rightW = lerpDouble(
          normalRightW,
          selRightW,
          selO,
        )!.clamp(0.0, total);
        // 🔴 21.11.2026: левому островку — только то, что ОСТАЛОСЬ от правого
        // (не больше половины). Раньше «до половины» без оглядки на правый:
        // в выделении правый растёт до ширины действий, и вместе они не
        // помещались — острова переставали перетекать друг в друга.
        final leftMax = math.max(
          0.0,
          math.min(total * 0.5, total - rightW - 8),
        );
        Widget leftFrame(Widget frame) => compactLeft
            // Левый островок — по содержимому, но не больше оставшегося.
            ? ConstrainedBox(
                constraints: BoxConstraints(maxWidth: leftMax),
                child: frame,
              )
            : Expanded(child: frame);
        // Сжимаемое содержимое левого островка обрезается, а не «вылезает».
        Widget fit(Widget child) => compactLeft
            ? UnconstrainedBox(
                alignment: Alignment.centerLeft,
                constrainedAxis: Axis.vertical,
                clipBehavior: Clip.hardEdge,
                child: child,
              )
            : child;
        final centerFade = ((1 - s) * (1 - selO)).clamp(0.0, 1.0);
        return Row(
          children: [
            // LEFT frame — persistent (logo/title ⇄ ✕count).
            leftFrame(FrostedHeaderIsland(
                radius: islandRadius,
                height: islandHeight,
                padding: EdgeInsets.symmetric(horizontal: leftPadding),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Opacity(
                      opacity: ((1 - s) * (1 - selO)).clamp(0.0, 1.0),
                      child: IgnorePointer(
                        ignoring: selO > 0.5,
                        // Обычное состояние: надпись сжимается, а не
                        // обрезается (обрезка — только у слоя выделения).
                        child: compactLeft
                            ? Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: 1,
                                child: leftNormalContent,
                              )
                            : (centerLeftNormal
                                  ? Center(child: leftNormalContent)
                                  : leftNormalContent),
                      ),
                    ),
                    Opacity(
                      opacity: selO,
                      child: IgnorePointer(
                        ignoring: selO < 0.5,
                        child: fit(leftSelectionContent),
                      ),
                    ),
                  ],
                ),
              )),
            if (compactLeft)
              Expanded(
                child: centerTitle == null || centerFade <= 0.01
                    ? const SizedBox.shrink()
                    : Opacity(
                        opacity: centerFade,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: HomeSectionIsland(
                            title: centerTitle!,
                            island: (child) => FrostedHeaderIsland(
                              radius: islandRadius,
                              height: islandHeight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: child,
                            ),
                          ),
                        ),
                      ),
              )
            else
              SizedBox(width: 8 * (1 - s)),
            // RIGHT frame — persistent (search/menu ⇄ actions); width morphs.
            SizedBox(
              width: rightW,
              height: islandHeight,
              child: FrostedHeaderIsland(
                radius: islandRadius,
                height: islandHeight,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Opacity(
                      opacity: ((1 - s) * (1 - selO)).clamp(0.0, 1.0),
                      child: IgnorePointer(
                        ignoring: s > 0.5 || selO > 0.5,
                        child: rightCompactContent,
                      ),
                    ),
                    if (hasSearch)
                      Opacity(
                        opacity: (s * (1 - selO)).clamp(0.0, 1.0),
                        child: IgnorePointer(
                          ignoring: s < 0.5 || selO > 0.5,
                          child: rightSearchContent!,
                        ),
                      ),
                    Opacity(
                      opacity: selO,
                      child: IgnorePointer(
                        ignoring: selO < 0.5,
                        // Пока остров растёт — действия обрезаются, а не
                        // «вылезают» за край.
                        child: UnconstrainedBox(
                          alignment: Alignment.centerRight,
                          constrainedAxis: Axis.vertical,
                          clipBehavior: Clip.hardEdge,
                          child: compactLeft
                              ? SizedBox(
                                  width: math.max(0.0, selRightW - 12),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: rightSelectionContent,
                                  ),
                                )
                              : rightSelectionContent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
