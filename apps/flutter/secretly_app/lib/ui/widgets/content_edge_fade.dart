// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

/// Telegram-style edge fade for a scrolling list: the CONTENT dissolves to
/// transparent near the top and/or bottom of the viewport, revealing whatever
/// sits behind it — it does NOT paint any shading of its own. Wrap a scroll
/// view in this and (optionally) keep an existing top/bottom shading layer on
/// top; the two compose.
///
/// Mirrors the in-chat content fade (`_chatContentFadeShader` in
/// `chat_screen.dart`): a vertical transparent→opaque→opaque→transparent
/// gradient applied with [BlendMode.dstIn], so the child's alpha is multiplied
/// by the gradient. The top fade ends (content fully opaque) exactly at
/// [topFadeEndPx] from the top — pass the bottom edge of the header islands so
/// content dissolves behind them rather than in a band lower down.
class ContentEdgeFade extends StatelessWidget {
  const ContentEdgeFade({
    super.key,
    required this.child,
    this.topFadeEndPx = 0.0,
    this.bottomFadeFraction = 0.07,
  });

  final Widget child;

  /// Distance (px from the top of the viewport) at which the top fade reaches
  /// full opacity. `0` disables the top fade entirely (e.g. pages with a cover
  /// at the top, where the top must stay fully visible).
  final double topFadeEndPx;

  /// Fraction of the viewport height that fades out at the bottom. `0` disables
  /// the bottom fade.
  final double bottomFadeFraction;

  @override
  Widget build(BuildContext context) {
    final hasTop = topFadeEndPx > 0.0;
    final hasBottom = bottomFadeFraction > 0.0;
    if (!hasTop && !hasBottom) return child;

    return ShaderMask(
      shaderCallback: (rect) {
        final h = rect.height <= 0 ? 1.0 : rect.height;
        final topStop = hasTop
            ? (topFadeEndPx / h).clamp(0.02, 0.4).toDouble()
            : 0.0;
        final bottomStop = hasBottom
            ? (1.0 - bottomFadeFraction).clamp(0.5, 1.0).toDouble()
            : 1.0;
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            hasTop ? Colors.transparent : Colors.white,
            Colors.white,
            Colors.white,
            hasBottom ? Colors.transparent : Colors.white,
          ],
          stops: [0.0, topStop, bottomStop, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
