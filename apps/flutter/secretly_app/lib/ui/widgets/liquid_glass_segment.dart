// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'frosted_header_island.dart';

/// Android island geometry — deliberately identical to the music island
/// (`kSharedAudioIslandRowHeight` / `_NowPlayingIsland._radius`) so the folder
/// strip and the Personal switcher match the island stacked below them.
const double _kIslandHeight = 38;
const double _kIslandRadius = 16;

/// A segmented switch (Personal↔Archive, chat folders) whose PLATE is the exact
/// same [LiquidGlassIslandSurface] as the main-page islands — same refraction,
/// same recipe, no grey — with an accent pill that slides between segments on
/// selection, like the bottom nav bar (2026-07-19).
///
/// Two layouts:
///  - [scrollable] false → equal-width segments on ONE glass plate, sliding
///    accent pill (Personal↔Archive; folders while few).
///  - [scrollable] true  → each segment is its OWN glass pill in a horizontal
///    scroller, the active one filled with the accent (folders once there are
///    more than fit the width).
///
/// Key lesson (owner: "нет преломления… серый"): the plate is glass, the pill
/// is a plain coloured highlight ABOVE it — never glass nested in glass, which
/// renders flat/transparent.
class LiquidGlassSegment extends StatelessWidget {
  const LiquidGlassSegment({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.badges,
    this.onLongPress,
    this.scrollable = false,
    this.height = 40,
    this.radius = 20,
  });

  final List<String> labels;

  /// Optional per-segment unread count; appended to the label when > 0.
  final List<int>? badges;
  final int selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<int>? onLongPress;

  /// Equal-width up to a few items; horizontal scroll of individual pills once
  /// they no longer fit (chat folders: > 4).
  final bool scrollable;
  final double height;
  final double radius;

  String _labelAt(int i) {
    final b = (badges != null && i < badges!.length) ? badges![i] : 0;
    return b > 0 ? '${labels[i]}  $b' : labels[i];
  }

  Color _textColor(BuildContext context, bool active) {
    final cs = Theme.of(context).colorScheme;
    if (active) return cs.primary;
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    return scrollable ? _buildScrollable(context, n) : _buildEqual(context, n);
  }

  // ── Equal-width: one plate + sliding JELLY (same engine as the nav bar) ────
  Widget _buildEqual(BuildContext context, int n) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetX = n <= 1 ? 0.0 : -1.0 + selected * (2.0 / (n - 1));

    final labelsRow = Row(
      children: [
        for (var i = 0; i < n; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(i),
              onLongPress: onLongPress == null ? null : () => onLongPress!(i),
              child: Center(
                child: Text(
                  _labelAt(i),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textColor(context, i == selected),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (liquidGlassIslandsEnabled && n >= 2) {
      // TWO real layers, exactly like the bottom nav bar:
      //
      //   LAYER 1 — the island plate (LiquidGlassIslandSurface). This is the
      //   proven refracting glass the owner approved; it refracts the page
      //   behind it just like the top islands.
      //
      //   LAYER 2 — the package's real jelly drop (AnimatedGlassIndicator, the
      //   same "капля" widget GlassTabBar/GlassBottomBar use), sitting ON TOP
      //   and hopping between segments. We drive its alignment with a spring
      //   tween so it glides. paintGlass:false → it is a frosted dark-grey pill
      //   (paintBackground + innerBlur), NOT a second glass shader — that is
      //   what avoids the glass-on-glass grey (the build-350 regression). The
      //   plate does the refraction; the drop does the motion.
      return SizedBox(
        height: height,
        child: LiquidGlassIslandSurface(
          radius: radius,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: targetX, end: targetX),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    builder: (context, x, _) => Stack(
                      children: [
                        AnimatedGlassIndicator(
                          velocity: 0,
                          itemCount: n,
                          alignment: Alignment(x, 0),
                          thickness: 0,
                          quality: GlassQuality.premium,
                          indicatorColor: _selectedPillColor(isDark),
                          isBackgroundIndicator: false,
                          paintBackground: true,
                          paintGlass: false,
                          borderRadius: radius - 3,
                          innerBlur: 10,
                          padding: const EdgeInsets.all(4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              labelsRow,
            ],
          ),
        ),
      );
    }

    // Classic (Android / kill-switch): the SAME frosted island as the music
    // island — same 38px height, same radius 16, same blur + gradient plate and
    // specular rim — with a sliding accent pill inside.
    return _androidIsland(
      context,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<Alignment>(
                tween: Tween<Alignment>(
                  begin: Alignment(targetX, 0),
                  end: Alignment(targetX, 0),
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (context, alignment, _) => Align(
                  alignment: alignment,
                  child: FractionallySizedBox(
                    widthFactor: 1 / n,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: _accentPill(cs, _kIslandRadius - 4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          labelsRow,
        ],
      ),
    );
  }

  /// The app's Android island plate (mirrors `_NowPlayingIsland`'s classic
  /// look): 38px tall, radius 16, blurred backdrop + white gradient fill +
  /// specular rim. Used so the folder strip and the Personal switcher read as
  /// the same material as the music island sitting right below them.
  Widget _androidIsland(BuildContext context, {required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillTop = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.65);
    final fillBottom = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.white.withValues(alpha: 0.55);
    final br = BorderRadius.circular(_kIslandRadius);
    return SizedBox(
      height: _kIslandHeight,
      child: CustomPaint(
        foregroundPainter: GlassHighlightBorderPainter(
          radius: _kIslandRadius,
          strokeWidth: 1.2,
          color: isDark
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.40),
        ),
        child: ClipRRect(
          borderRadius: br,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [fillTop, fillBottom],
                ),
                borderRadius: br,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  // ── Scrollable: individual glass pills ────────────────────────────────────
  Widget _buildScrollable(BuildContext context, int n) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: liquidGlassIslandsEnabled ? height : _kIslandHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: n,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = i == selected;
          final label = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _labelAt(i),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textColor(context, active),
              ),
            ),
          );
          final inner = Stack(
            children: [
              if (active)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: liquidGlassIslandsEnabled
                        ? _darkPill(isDark)
                        : _accentPill(cs, _kIslandRadius - 4),
                  ),
                ),
              Center(child: label),
            ],
          );
          final pill = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(i),
            onLongPress: onLongPress == null ? null : () => onLongPress!(i),
            child: liquidGlassIslandsEnabled
                ? LiquidGlassIslandSurface(
                    radius: radius,
                    height: height,
                    child: inner,
                  )
                // Android: each folder chip is its own island, same material
                // and size as the music island.
                : _androidIsland(context, child: inner),
          );
          return SizedBox(
            height: liquidGlassIslandsEnabled ? height : _kIslandHeight,
            child: pill,
          );
        },
      ),
    );
  }

  Widget _accentPill(ColorScheme cs, double pillRadius) => DecoratedBox(
    decoration: BoxDecoration(
      color: cs.primary.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(pillRadius),
      border: Border.all(
        color: cs.primary.withValues(alpha: 0.30),
        width: 0.8,
      ),
    ),
  );

  /// The selected-segment pill tint — a DARK GREY a touch darker than the glass
  /// plate (matching the bottom nav bar's selected pill), never pure black.
  Color _selectedPillColor(bool isDark) => isDark
      ? const Color(0x73303030) // grey ~48 @ 45%
      : const Color(0x1F000000); // black @ 12% → reads grey on light glass

  /// Scrollable-mode active pill (its own glass island): same dark-grey tint.
  Widget _darkPill(bool isDark) => DecoratedBox(
    decoration: BoxDecoration(
      color: _selectedPillColor(isDark),
      borderRadius: BorderRadius.circular(radius - 5),
      border: Border.all(
        color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.06),
        width: 0.8,
      ),
    ),
  );
}
