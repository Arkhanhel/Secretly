// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared premium visual language (TZ-MONETIZE-01 §C-4 polish):
/// — [ShimmerGoldText] : slowly-flowing molten-gold text (Premium wordmark),
/// — [GoldPremiumBadge]: the home-screen "Premium" pill next to the app name,
/// — [GetPremiumChip]  : a compact gold "Получить премиум" CTA shown at limits,
/// — [PremiumGlassCard]: the matte liquid-glass plate used by the paywall cards,
///   matching the app's frosted "islands" (blur + white gradient + specular rim).

/// The app's premium gold (matches settings icon tint 0xFFE8A33D).
const Color kPremiumGold = Color(0xFFE8A33D);

/// Rich molten-gold stops for the shimmer sweep (deep → bright → deep).
const List<Color> kGoldShimmerColors = [
  Color(0xFFB9791E),
  Color(0xFFE8A33D),
  Color(0xFFFFF3C8),
  Color(0xFFE8A33D),
  Color(0xFFB9791E),
];

class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.shift);

  /// 0→1 translates the gradient by one full width (seamless with mirror tiling).
  final double shift;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * shift, 0.0, 0.0);
}

/// Text painted with a slowly-moving gold gradient — a premium wordmark.
class ShimmerGoldText extends StatefulWidget {
  const ShimmerGoldText(
    this.text, {
    super.key,
    this.style,
    this.period = const Duration(milliseconds: 3400),
    this.colors,
  });

  final String text;
  final TextStyle? style;
  final Duration period;

  /// Shimmer gradient colors. Null → premium gold. Pass a theme-derived set for
  /// an animated label that matches the app accent instead of gold.
  final List<Color>? colors;

  @override
  State<ShimmerGoldText> createState() => _ShimmerGoldTextState();
}

class _ShimmerGoldTextState extends State<ShimmerGoldText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = (widget.style ?? const TextStyle()).copyWith(color: Colors.white);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: widget.colors ?? kGoldShimmerColors,
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          tileMode: TileMode.mirror,
          transform: _SlideGradientTransform(_c.value),
        ).createShader(rect),
        child: child,
      ),
      child: Text(widget.text, style: base),
    );
  }
}

/// Home-screen "Premium" badge: a faint gold glass pill + shimmering wordmark.
/// Place to the right of the app name when the user holds a paid tier.
/// Animated-shimmer colors derived from the current theme accent — for premium
/// labels that should match the app theme instead of gold. Same shimmer motion.
List<Color> premiumShimmerColors(BuildContext context) {
  final c = Theme.of(context).colorScheme.primary;
  final hi = Color.lerp(c, Colors.white, 0.7)!;
  return [c.withValues(alpha: 0.55), c, hi, c, c.withValues(alpha: 0.55)];
}

class GoldPremiumBadge extends StatelessWidget {
  const GoldPremiumBadge({super.key, this.fontSize = 12.5});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Theme-accent badge (not gold): faint accent glass pill + accent icon +
    // animated accent shimmer wordmark.
    final c = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 2.5, 9, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.14), c.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: c.withValues(alpha: 0.32), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: fontSize, color: c),
          const SizedBox(width: 4),
          ShimmerGoldText(
            'Premium',
            colors: premiumShimmerColors(context),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact gold CTA shown wherever a free-tier limit is hit ("Получить премиум").
class GetPremiumChip extends StatelessWidget {
  const GetPremiumChip({
    super.key,
    required this.onTap,
    this.label,
    this.icon = Icons.workspace_premium_rounded,
    this.dense = false,
  });

  final VoidCallback onTap;
  final String? label;
  final IconData icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final text = label ?? (ru ? 'Получить премиум' : 'Get Premium');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFFF0B65A), Color(0xFFE0922C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: kPremiumGold.withValues(alpha: 0.40),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 11 : 14,
              vertical: dense ? 6 : 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: dense ? 15 : 17, color: Colors.white),
                SizedBox(width: dense ? 5 : 7),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: dense ? 12.5 : 13.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Matte liquid-glass plate (paywall plan cards). Mirrors the app's frosted
/// islands: backdrop blur + translucent gradient + specular top edge. When
/// [highlighted] it gains a gold rim + warm gold glow.
class PremiumGlassCard extends StatelessWidget {
  const PremiumGlassCard({
    super.key,
    required this.child,
    this.highlighted = false,
    this.radius = 20,
    this.onTap,
    this.blurSigma = 22,
    this.accentColor,
    this.opaqueLight = false,
  });

  final Widget child;
  final bool highlighted;
  final double radius;
  final VoidCallback? onTap;
  final double blurSigma;

  /// LIGHT theme only: render as a SOLID white card (no translucency / blur),
  /// lifted by a soft shadow — for surfaces over a vivid backdrop (the purple
  /// paywall) where a see-through plate would look muddy. Dark theme unchanged.
  final bool opaqueLight;

  /// Accent for the highlighted rim + glow. Defaults to premium gold; pass the
  /// brand primary for a Telegram-style blue selection.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final br = BorderRadius.circular(radius);
    final accent = accentColor ?? kPremiumGold;
    // Opaque white card (paywall, light theme) — solid, lifted by a soft shadow,
    // accent rim when highlighted. No translucency / blur.
    if (opaqueLight && !isDark) {
      Widget solid = Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: br,
          border: highlighted
              ? Border.all(color: accent.withValues(alpha: 0.9), width: 1.6)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: highlighted ? 0.16 : 0.10),
              blurRadius: highlighted ? 24 : 16,
              spreadRadius: -1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: br, child: child),
      );
      if (onTap == null) return solid;
      return Material(
        color: Colors.transparent,
        borderRadius: br,
        child: InkWell(onTap: onTap, borderRadius: br, child: solid),
      );
    }
    // The plate is ALWAYS the app's neutral frosted island (white gradient +
    // specular blicks). Gold shows up only as an accent rim + soft glow when
    // [highlighted] — never as a gold fill.
    final fillTop = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.24);
    final fillBottom = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.white.withValues(alpha: 0.14);
    final borderColor = highlighted
        ? accent.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: isDark ? 0.14 : 0.5);
    final specular = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.42);

    Widget plate = ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [fillTop, fillBottom],
            ),
            borderRadius: br,
            border: Border.all(color: borderColor, width: highlighted ? 1.5 : 1),
          ),
          child: child,
        ),
      ),
    );

    plate = CustomPaint(
      foregroundPainter: _SpecularTopPainter(radius: radius, color: specular),
      child: plate,
    );

    plate = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 26,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: plate,
    );

    if (onTap == null) return plate;
    return Material(
      color: Colors.transparent,
      borderRadius: br,
      child: InkWell(onTap: onTap, borderRadius: br, child: plate),
    );
  }
}

/// Bright top edge + thin bottom rim (convex, lit-from-above) — same look as
/// the app's GlassHighlightBorderPainter, inlined to keep this widget standalone.
class _SpecularTopPainter extends CustomPainter {
  const _SpecularTopPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  void _edge(Canvas c, Rect r, double w, Alignment a, Alignment b) {
    final rr = RRect.fromRectAndRadius(r.deflate(w / 2), Radius.circular(radius));
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: a,
        end: b,
        colors: [color, color.withValues(alpha: 0.0)],
        stops: const [0.0, 0.55],
      ).createShader(r);
    c.drawRRect(rr, p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _edge(canvas, rect, 1.3, Alignment.topCenter, Alignment.bottomCenter);
    _edge(canvas, rect, 0.45, Alignment.bottomCenter, Alignment.topCenter);
  }

  @override
  bool shouldRepaint(_SpecularTopPainter old) =>
      old.radius != radius || old.color != color;
}

/// Animated "cosmic dust" — a detailed twinkling starfield with slow upward
/// drift, gentle sway and depth-based parallax (near particles are bigger,
/// brighter and drift faster). Telegram-style ambience behind the hero.
class CosmicDustField extends StatefulWidget {
  const CosmicDustField({super.key, this.count = 110});

  final int count;

  @override
  State<CosmicDustField> createState() => _CosmicDustFieldState();
}

class _CosmicDustFieldState extends State<CosmicDustField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 18))
        ..repeat();
  late final List<_DustParticle> _p;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(42); // fixed seed → stable, hand-tuned look
    _p = List.generate(widget.count, (i) {
      final depth = 0.35 + rnd.nextDouble() * 0.9;
      return _DustParticle(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        r: (0.6 + rnd.nextDouble() * 1.9) * depth,
        depth: depth,
        baseOpacity: 0.22 + rnd.nextDouble() * 0.6,
        twinklePhase: rnd.nextDouble() * math.pi * 2,
        twinkleSpeed: 0.6 + rnd.nextDouble() * 1.8,
        colorIndex: rnd.nextInt(3),
        big: rnd.nextDouble() < 0.12,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) =>
            CustomPaint(painter: _DustPainter(_p, _c.value), size: Size.infinite),
      ),
    );
  }
}

class _DustParticle {
  _DustParticle({
    required this.x,
    required this.y,
    required this.r,
    required this.depth,
    required this.baseOpacity,
    required this.twinklePhase,
    required this.twinkleSpeed,
    required this.colorIndex,
    required this.big,
  });

  final double x, y, r, depth, baseOpacity, twinklePhase, twinkleSpeed;
  final int colorIndex;
  final bool big;
}

class _DustPainter extends CustomPainter {
  _DustPainter(this.p, this.t);

  final List<_DustParticle> p;
  final double t; // 0..1

  static const _palette = [
    Color(0xFFFFFFFF),
    Color(0xFFBFD0FF),
    Color(0xFFD9BFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const tau = math.pi * 2;
    for (final d in p) {
      final drift = (t * d.depth * 0.6 + d.y) % 1.0;
      final dy = (1.0 - drift) * size.height; // upward
      final dx =
          (d.x + math.sin(t * tau + d.twinklePhase) * 0.012 * d.depth) * size.width;
      final twinkle = 0.45 + 0.55 * math.sin(t * tau * d.twinkleSpeed + d.twinklePhase);
      final op = (d.baseOpacity * twinkle).clamp(0.0, 1.0);
      final color = _palette[d.colorIndex].withValues(alpha: op);
      if (d.big) {
        canvas.drawCircle(
          Offset(dx, dy),
          d.r * 3.0,
          Paint()
            ..color = color.withValues(alpha: op * 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawCircle(Offset(dx, dy), d.r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => old.t != t;
}

/// Bottom CTA: the app's frosted glass island with a HALF-transparent gold
/// layer blended over it (golden frosted glass) + gold rim + soft gold glow.
class GoldGlassButton extends StatelessWidget {
  const GoldGlassButton({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = 18,
  });

  final Widget child;
  final VoidCallback onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final br = BorderRadius.circular(radius);
    final specular = isDark
        ? Colors.white.withValues(alpha: 0.30)
        : Colors.white.withValues(alpha: 0.5);
    // Neutral island glass base, then a ~50% gold overlay alpha-blended in.
    final baseTop = Colors.white.withValues(alpha: isDark ? 0.08 : 0.22);
    final baseBottom = Colors.white.withValues(alpha: isDark ? 0.04 : 0.14);
    Widget plate = ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: br,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(kPremiumGold.withValues(alpha: 0.50), baseTop),
                Color.alphaBlend(kPremiumGold.withValues(alpha: 0.34), baseBottom),
              ],
            ),
            border: Border.all(color: kPremiumGold.withValues(alpha: 0.60), width: 1.2),
          ),
          child: child,
        ),
      ),
    );
    plate = CustomPaint(
      foregroundPainter: _SpecularTopPainter(radius: radius, color: specular),
      child: plate,
    );
    plate = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: kPremiumGold.withValues(alpha: 0.30),
            blurRadius: 22,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: plate,
    );
    return Material(
      color: Colors.transparent,
      borderRadius: br,
      child: InkWell(onTap: onTap, borderRadius: br, child: plate),
    );
  }
}
