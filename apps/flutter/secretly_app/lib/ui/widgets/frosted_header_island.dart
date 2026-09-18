// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../liquid_glass_flags.dart';
import '../thermal_guard.dart';
import 'app_background.dart';
import 'island_backdrop.dart';

/// True when island surfaces should render as liquid glass (iOS + flag; the
/// live thermal check happens per-build via [ThermalGuard.effectsAllowed]).
bool get liquidGlassIslandsEnabled =>
    kLiquidGlassNavBar && Platform.isIOS && GlassPrefs.enabled.value;

/// The ONE liquid-glass island material (owner-tuned [secretlyIslandGlass]).
///
/// Own-layer per island — the same isolation the (owner-approved) nav bar
/// uses, so each island refracts the LIVE content behind it. A shared
/// screen-wide layer was tried (build 336) but it refracts the screen
/// BACKDROP, not the scroll list, so the top islands went flat; own-layer is
/// what actually shows the lens.
///
/// Deliberately paints NO [GlassHighlightBorderPainter] and NO
/// [IslandOuterShadowPainter]: the owner wants zero specular strokes around
/// glass islands — the shader's own (near-zero) edge light is the only rim.
/// Marks a subtree whose islands share ONE glass layer.
///
/// Each island normally owns its layer (`useOwnLayer: true`), which is what
/// makes it refract the live scroll behind it — but it also means one backdrop
/// capture and one shader pass PER ISLAND, every frame. Three stacked islands
/// on the main screen therefore cost three times what Apple pays for the same
/// look: their compositor draws many shapes in a single pass.
///
/// Wrapping those islands in an [AdaptiveLiquidGlassLayer] plus this scope
/// makes them shapes inside that one layer instead of three layers. Quality
/// stays premium, so the depth is unchanged; only the number of passes drops.
///
/// NB: the enclosing layer must sit ABOVE the scrolling content in paint order
/// (as the pinned island column does). A screen-wide layer refracts the screen
/// backdrop rather than the list and the islands go flat — that is what went
/// wrong in build 336.
class SecretlyGlassGroup extends InheritedWidget {
  const SecretlyGlassGroup({
    super.key,
    required this.grouped,
    required super.child,
  });

  final bool grouped;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SecretlyGlassGroup>()
          ?.grouped ??
      false;

  @override
  bool updateShouldNotify(SecretlyGlassGroup oldWidget) =>
      oldWidget.grouped != grouped;
}

class LiquidGlassIslandSurface extends StatelessWidget {
  const LiquidGlassIslandSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.height,
    this.padding = EdgeInsets.zero,
    this.clipContent = false,
  });

  final Widget child;
  final double radius;
  final double? height;
  final EdgeInsetsGeometry padding;

  /// Round the CONTENT to the plate's radius.
  ///
  /// The content is painted as a sibling ABOVE the glass plate (see build), so
  /// by default it is not clipped — which is correct for icons/labels that must
  /// stay crisp. But content that paints its own full-bleed surface (the glued
  /// call+music rows) then shows SQUARE corners past the rounded plate. Those
  /// callers opt in here.
  final bool clipContent;

  @override
  Widget build(BuildContext context) {
    // The glass is a BACKDROP PLATE with an EMPTY child; the real content is a
    // sibling painted ABOVE it. A GlassContainer treats its own child as part
    // of the refracted/tinted glass shape (glassColor + saturation + the 0.39
    // visibility dim it), which is why icons and labels kept going
    // "полупрозрачными и затенёнными". Painting them as a sibling over the
    // plate keeps them fully opaque and crisp while the plate still refracts
    // the live scroll behind it.
    // Fill the given height and CENTRE the content — the plain GlassContainer
    // used to lay its child out centered, so splitting glass/content into a
    // Stack shifted labels/icons to the top-left ("сместились надписи и
    // иконки" on the profile action islands). Align.center restores it.
    Widget content = Padding(padding: padding, child: child);
    if (clipContent) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      );
    }
    if (height != null) {
      content = SizedBox(height: height, child: content);
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          // Isolate the plate from the rest of the tree. Without this ANY
          // repaint that reaches this subtree re-runs the glass shader — and
          // the shader is by far the most expensive thing on the screen. The
          // plate's own content never changes, so it should redraw only when
          // the scroll behind it actually moves (2026-07-20).
          child: RepaintBoundary(
            // Only two states: full glass, or the classic material. The
            // thermal guard flips ThermalGuard.effectsAllowed, which the
            // callers gate on — there is no reduced-quality tier in between.
            child: GlassContainer(
              shape: LiquidRoundedSuperellipse(borderRadius: radius),
              // Inside a SecretlyGlassGroup this island is a SHAPE in the
              // enclosing layer rather than a layer of its own.
              useOwnLayer: !SecretlyGlassGroup.of(context),
              // DEPTH IS PREMIUM-ONLY (2026-07-20). Do NOT drop this to
              // `standard` to save power: premium is not "standard plus
              // highlights", it selects an entirely different renderer —
              // `glass_effect.dart` gates the native Impeller path on
              // `quality == premium` ("Path B: Native Impeller (Premium
              // only)"). That path is what displaces pixels and gives the
              // lens its volume; `standard` falls through to a flatter
              // approximation and the effect reads as plain frosted glass.
              //
              // The cost must come from rendering FEWER premium layers
              // (grouping the stacked islands into one), never from a cheaper
              // per-layer quality — a flat tier still pays for a backdrop
              // read, so it looked worse for almost the same power.
              quality: GlassQuality.premium,
              settings: secretlyIslandGlass(Theme.of(context).brightness),
              clipBehavior: Clip.antiAlias,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        content,
      ],
    );
  }
}

/// Specular highlight stroke for the matte "glass islands" used across the app
/// (chat header, top-bar islands, bottom nav, music island).
///
/// Paints a bright-white edge that is strongest along the TOP and fades toward
/// the middle, so the plate reads as lit from above (convex). When
/// [bottomHighlight] is true it also paints a fainter rim light along the
/// BOTTOM edge — the SAME colour but **3× thinner** — for a subtle reflected
/// glow beneath the plate.
class GlassHighlightBorderPainter extends CustomPainter {
  const GlassHighlightBorderPainter({
    required this.radius,
    required this.strokeWidth,
    required this.color,
    this.bottomHighlight = true,
  });

  final double radius;
  final double strokeWidth;
  final Color color;

  /// Adds a bottom-edge rim light (3× thinner than the top edge). On by default
  /// so every island that shows the top highlight also gets the lower glow.
  final bool bottomHighlight;

  void _paintEdge(
    Canvas canvas,
    Rect rect,
    double width,
    Alignment begin,
    Alignment end,
  ) {
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(width / 2),
      Radius.circular(radius),
    );
    final shader = LinearGradient(
      begin: begin,
      end: end,
      colors: [color, color.withValues(alpha: 0.0)],
      stops: const [0.0, 0.55],
    ).createShader(rect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..isAntiAlias = true
      ..shader = shader;
    canvas.drawRRect(rrect, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Top specular edge (bright at top, fades to transparent by ~55%).
    _paintEdge(
      canvas,
      rect,
      strokeWidth,
      Alignment.topCenter,
      Alignment.bottomCenter,
    );
    // Bottom rim light: same colour, 3× thinner, fading upward.
    if (bottomHighlight) {
      _paintEdge(
        canvas,
        rect,
        strokeWidth / 3,
        Alignment.bottomCenter,
        Alignment.topCenter,
      );
    }
  }

  @override
  bool shouldRepaint(GlassHighlightBorderPainter old) =>
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.color != color ||
      old.bottomHighlight != bottomHighlight;
}

/// Paints a soft drop-shadow in the ring OUTSIDE a rounded-rect island only.
///
/// The island's interior is clipped away before the blurred plate is drawn, so
/// the grey halo lives strictly around the plate's perimeter and NEVER bleeds
/// underneath it. That matters for translucent ("glass") islands: a normal
/// [BoxShadow] blurs symmetrically across the edge, and the inner half shows
/// THROUGH the translucent fill and greys the glass. Clipping the interior out
/// keeps the fill clean and just separates the plate from the page background —
/// a light-theme-only lift.
class IslandOuterShadowPainter extends CustomPainter {
  const IslandOuterShadowPainter({
    required this.radius,
    required this.color,
    this.blur = 6,
    this.spread = 0,
    this.dy = 1.0,
  });

  final double radius;
  final Color color;

  /// Gaussian blur sigma of the halo.
  final double blur;

  /// How far the shadow rect grows beyond the plate before blurring.
  final double spread;

  /// Vertical offset of the shadow (positive = down), for a lit-from-above feel.
  final double dy;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final plate = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    // Clip OUT the plate interior so only the outer ring of the blur is visible.
    final outer = Path()
      ..addRect(rect.inflate(blur * 3 + spread + dy.abs() + 4));
    final inner = Path()..addRRect(plate);
    canvas.save();
    canvas.clipPath(Path.combine(PathOperation.difference, outer, inner));
    final shadowRRect = RRect.fromRectAndRadius(
      rect.shift(Offset(0, dy)).inflate(spread),
      Radius.circular(radius + spread),
    );
    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawRRect(shadowRRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(IslandOuterShadowPainter old) =>
      old.radius != radius ||
      old.color != color ||
      old.blur != blur ||
      old.spread != spread ||
      old.dy != dy;
}

/// Soft top "scrim" gradient that dissolves into the page background colour
/// (theme-adaptive: darkest gradient shade on dark, page tint on light) and
/// fades downward. Place at the very top of a screen's body Stack so content
/// dissolves under the floating header islands.
class SystemTopFadeLayer extends StatelessWidget {
  const SystemTopFadeLayer({
    super.key,
    required this.height,
    this.blurSigma = 0,
  });

  final double height;

  /// Optional progressive blur: strongest right under the islands at the very
  /// top, fading to zero at the bottom — so scrolled content dissolves upward
  /// (Telegram-style). 0 = colour scrim only (default; existing call sites
  /// keep their look unchanged).
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    // Fade into the actual page background colour (theme-adaptive: darkest
    // gradient shade on dark, page tint on light) instead of pure black, so the
    // shading dissolves into the theme background rather than a black band.
    final base = AppBackground.scrimColorOf(context);
    final scrim = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Extra stops + a long, gentle tail so the fade eases out smoothly
          // (no hard edge where it meets the content) even on short bands.
          stops: const [0.0, 0.35, 0.62, 0.82, 1.0],
          colors: [
            base.withValues(alpha: 0.66),
            base.withValues(alpha: 0.42),
            base.withValues(alpha: 0.20),
            base.withValues(alpha: 0.07),
            base.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: blurSigma <= 0
            ? scrim
            : Stack(
                fit: StackFit.expand,
                children: [
                  // Blur the content behind, masked to fade out downward.
                  ClipRect(
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black, Colors.transparent],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: BackdropFilter(
                        // VIBRANCY TEST (2026-07-17): blur + saturation.
                        filter: islandBackdropFilter(
                          sigmaX: blurSigma,
                          sigmaY: blurSigma,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  scrim,
                ],
              ),
      ),
    );
  }
}

/// Reusable Telegram-style matte "glass island" — the same component used by the
/// chat header, now shared by the Chats / Rooms / Contacts / Settings top bars.
///
///  1) a big backdrop blur (matte — content behind stays recognizable but loses
///     sharpness),
///  2) a translucent white vertical gradient fill (lighter top → darker bottom)
///     for density,
///  3) a specular [GlassHighlightBorderPainter] highlight (bright top edge +
///     thin bottom rim light) for a convex, lit-from-above look.
class FrostedHeaderIsland extends StatelessWidget {
  const FrostedHeaderIsland({
    super.key,
    required this.child,
    this.radius = 24,
    this.height,
    this.padding = EdgeInsets.zero,
    this.showHighlight = true,
    this.blurSigma = 24,
  });

  final Widget child;
  final double radius;
  final double? height;
  final EdgeInsetsGeometry padding;
  final bool showHighlight;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    if (liquidGlassIslandsEnabled) {
      return ValueListenableBuilder<bool>(
        valueListenable: ThermalGuard.effectsAllowed,
        builder: (context, allowed, _) => allowed
            ? LiquidGlassIslandSurface(
                radius: radius,
                height: height,
                padding: padding,
                child: child,
              )
            : _buildClassic(context),
      );
    }
    return _buildClassic(context);
  }

  Widget _buildClassic(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Keep a clearly-visible matte plate even when there is nothing bright behind
    // the blur (e.g. a profile cover fading out under the action chips during a
    // pull) — so the islands always read as liquid glass, never see-through.
    //
    // LIGHT theme: the page background is near-white, so a faint translucent
    // veil vanishes into it. Use a denser near-white fill ("minimal
    // transparency") and lift the plate with a thin OUTER shadow (added below)
    // so each island reads as a distinct, lightly-raised plate. DARK unchanged.
    // 🔴 These fills only work ON TOP OF a blur. In dark mode they are white at
    // alpha 0.07–0.13 — enough to take the dirtiness off a blurred backdrop and
    // visually nothing on their own. With the blur off the island must paint a
    // SOLID plate instead, or it disappears (field report 2026-08-01).
    final frosted = PanelPrefs.frostedEnabled.value;
    final solid = opaquePanelFill(context);
    final fillTop = !frosted
        ? solid
        : isDark
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.white.withValues(alpha: 0.50);
    final fillBottom = !frosted
        ? solid
        : isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.40);
    final br = BorderRadius.circular(radius);
    Widget island = ClipRRect(
      borderRadius: br,
      child: _maybeBlur(
        frosted: frosted,
        sigma: blurSigma,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [fillTop, fillBottom],
            ),
            borderRadius: br,
          ),
          // Icons/labels inside an island default to the theme's onSurface, so
          // they are dark in light mode and light in dark mode (explicit colors
          // still win). Fixes white-on-white island controls in light theme.
          child: IconTheme.merge(
            data: IconThemeData(color: cs.onSurface),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
    if (showHighlight) {
      final highlight = isDark
          ? Colors.white.withValues(alpha: 0.24)
          : Colors.white.withValues(alpha: 0.42);
      island = CustomPaint(
        foregroundPainter: GlassHighlightBorderPainter(
          radius: radius,
          strokeWidth: 1.3,
          color: highlight,
        ),
        child: island,
      );
    }
    // LIGHT theme only: a very thin drop shadow painted ONLY in the ring OUTSIDE
    // the plate (interior clipped) so the soft grey never refracts through the
    // island's translucency — it just separates the plate from the page.
    if (!isDark) {
      island = CustomPaint(
        painter: IslandOuterShadowPainter(
          radius: radius,
          color: Colors.black.withValues(alpha: 0.07),
        ),
        child: island,
      );
    }
    return height == null ? island : SizedBox(height: height, child: island);
  }
}

/// ISLAND ROW GROUP (2026-07-17): one glass island wrapping several fixed-
/// height rows with hairline seams between them — the exact recipe the chat
/// uses to glue its pinned-message and now-playing strips into a single
/// island. Extracted here so the main screens can glue music + active-call
/// the same way. Visuals mirror the chat's local island: dense light fill,
/// plain 24px blur, specular highlight, light-only outer shadow.
class FrostedIslandRowGroup extends StatelessWidget {
  const FrostedIslandRowGroup({
    super.key,
    required this.rows,
    this.rowHeight = 38,
    this.rowHeights,
    this.radius = 16,
  });

  final List<Widget> rows;
  final double rowHeight;

  /// Per-row heights, when the rows are not all the same size (the call row is
  /// deliberately slimmer than the music row). Falls back to [rowHeight].
  final List<double>? rowHeights;
  final double radius;

  double _heightAt(int i) {
    final heights = rowHeights;
    if (heights != null && i < heights.length) return heights[i];
    return rowHeight;
  }

  @override
  Widget build(BuildContext context) {
    if (liquidGlassIslandsEnabled) {
      return ValueListenableBuilder<bool>(
        valueListenable: ThermalGuard.effectsAllowed,
        builder: (context, allowed, _) => allowed
            ? LiquidGlassIslandSurface(
                radius: radius,
                // The rows paint a full-bleed surface, so without this they
                // showed SQUARE bottom corners past the rounded glass plate.
                clipContent: true,
                child: _buildRowsColumn(context),
              )
            : _buildClassic(context),
      );
    }
    return _buildClassic(context);
  }

  Widget _buildRowsColumn(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seamColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.07);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Container(height: 0.5, color: seamColor),
          SizedBox(height: _heightAt(i), child: rows[i]),
        ],
      ],
    );
  }

  Widget _buildClassic(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillTop = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.65);
    final fillBottom = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.white.withValues(alpha: 0.55);
    final seamColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.07);
    final br = BorderRadius.circular(radius);

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Container(height: 0.5, color: seamColor),
          SizedBox(height: _heightAt(i), child: rows[i]),
        ],
      ],
    );

    Widget island = CustomPaint(
      foregroundPainter: GlassHighlightBorderPainter(
        radius: radius,
        strokeWidth: 1.3,
        color: isDark
            ? Colors.white.withValues(alpha: 0.24)
            : Colors.white.withValues(alpha: 0.42),
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
            child: column,
          ),
        ),
      ),
    );
    if (!isDark) {
      island = CustomPaint(
        painter: IslandOuterShadowPainter(
          radius: radius,
          color: const Color(0x12000000),
        ),
        child: island,
      );
    }
    return island;
  }
}


/// Blur only when frosted panels are on; otherwise hand the child straight
/// through, because it is already painting a solid plate.
Widget _maybeBlur({
  required bool frosted,
  required double sigma,
  required Widget child,
}) {
  if (!frosted) return child;
  // VIBRANCY TEST (2026-07-17): blur + saturation, see island_backdrop.
  return BackdropFilter(
    filter: islandBackdropFilter(sigmaX: sigma, sigmaY: sigma),
    child: child,
  );
}
