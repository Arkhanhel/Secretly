// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Плитка значка раздела настроек в одном из одиннадцати стилей.
///
/// Вся плитка — один `CustomPainter`: подложка, блики, тени и знак рисуются
/// за один проход, без слоёв размытия (`BackdropFilter`) и без картинок.
/// `RepaintBoundary` вокруг держит готовую плитку в кеше, поэтому прокрутка
/// списка её не перерисовывает.
///
/// Числа (градиенты, тени, доля знака в плитке) — из макета владельца
/// «Secretly · 10 стилей иконок», где они заданы в CSS. Внутренние тени CSS
/// (`inset`) Flutter не умеет — они воспроизведены градиентами по краю.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'settings_glyphs.dart';
import 'settings_icon_style.dart';

class SettingsGlyphTile extends StatelessWidget {
  const SettingsGlyphTile({
    super.key,
    required this.glyph,
    required this.style,
    this.size = 30,
    this.brightness,
  });

  final SettingsGlyph glyph;
  final SettingsIconStyle style;
  final double size;

  /// Тема, под которую рисовать (для «Пастели» и «Стекла» она важна).
  /// `null` — тема окружения.
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final dark =
        (brightness ?? Theme.of(context).brightness) == Brightness.dark;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: SettingsGlyphTilePainter(
            glyph: glyph,
            style: style,
            dark: dark,
            textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
          ),
        ),
      ),
    );
  }
}

/// Плитка, которая сама следит за выбранным стилем ([SettingsIconStylePrefs]).
class SettingsSectionIcon extends StatelessWidget {
  const SettingsSectionIcon(this.glyph, {super.key, this.size = 30});

  final SettingsGlyph glyph;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SettingsIconStyleBuilder(
      builder: (context, style) =>
          SettingsGlyphTile(glyph: glyph, style: style, size: size),
    );
  }
}

Color _a(Color c, double alpha) => c.withValues(alpha: alpha);

/// Направление CSS-градиента `linear-gradient(<deg>, …)` в выравниваниях
/// Flutter: 0° — вверх, отсчёт по часовой стрелке.
(Alignment, Alignment) _cssAngle(double deg) {
  final r = deg * math.pi / 180;
  final dx = math.sin(r);
  final dy = -math.cos(r);
  return (Alignment(-dx, -dy), Alignment(dx, dy));
}

class SettingsGlyphTilePainter extends CustomPainter {
  SettingsGlyphTilePainter({
    required this.glyph,
    required this.style,
    required this.dark,
    this.textDirection = TextDirection.ltr,
  });

  final SettingsGlyph glyph;
  final SettingsIconStyle style;
  final bool dark;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size.square(s);
    final c = glyph.palette;

    var radius = (s * 0.26).roundToDouble();
    var glyphScale = 0.58;
    Color fill = Colors.white;
    Shader? glyphShader;
    // Тень/свечение знака: цвет, сдвиг, размытие.
    Color? glyphShadow;
    var glyphShadowOffset = Offset.zero;
    var glyphShadowBlur = 0.0;

    RRect rr() => RRect.fromRectAndRadius(rect, Radius.circular(radius));

    void outerShadow(
      Color color,
      Offset offset,
      double blur, {
      double spread = 0,
    }) {
      final r = rr().inflate(spread).shift(offset);
      canvas.drawRRect(
        r,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
      );
    }

    void base(Paint paint) => canvas.drawRRect(rr(), paint);

    Paint gradient(double deg, List<Color> colors, [List<double>? stops]) {
      final (b, e) = _cssAngle(deg);
      return Paint()
        ..shader = LinearGradient(
          begin: b,
          end: e,
          colors: colors,
          stops: stops,
        ).createShader(rect);
    }

    // Блик по верхней кромке (замена CSS `inset 0 1px 0 white`).
    void topEdge(double alpha, {double width = 1.2}) {
      canvas.save();
      canvas.clipRRect(rr());
      canvas.drawRRect(
        rr().deflate(width / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_a(Colors.white, alpha), _a(Colors.white, 0)],
            stops: const [0, 0.22],
          ).createShader(rect),
      );
      canvas.restore();
    }

    void bottomShade(Color color, double alpha) {
      canvas.save();
      canvas.clipRRect(rr());
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [_a(color, alpha), _a(color, 0)],
            stops: const [0, 0.28],
          ).createShader(rect),
      );
      canvas.restore();
    }

    // Радиальный блик CSS `radial-gradient(rx ry at x y, color, transparent stop)`:
    // центр и радиусы — доли стороны плитки.
    void radialGlow(
      Offset at,
      double rx,
      double ry,
      Color color, {
      double stop = 1,
    }) {
      canvas.save();
      canvas.clipRRect(rr());
      canvas.translate(at.dx * s, at.dy * s);
      canvas.scale(rx * s, ry * s);
      canvas.drawRect(
        const Rect.fromLTRB(-4, -4, 4, 4),
        Paint()
          ..shader = RadialGradient(
            radius: 0.5,
            colors: [color, _a(color, 0)],
            stops: [0, stop],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1)),
      );
      canvas.restore();
    }

    switch (style) {
      case SettingsIconStyle.classic:
        base(Paint()..color = c.m);
      case SettingsIconStyle.glossy:
        outerShadow(_a(c.c2, 0.33), Offset(0, s * 0.07), s * 0.18);
        base(gradient(180, [c.c1, c.c2]));
        bottomShade(Colors.black, 0.16);
        // Блик на верхней половине.
        final hl = Rect.fromLTWH(s * 0.08, s * 0.03, s * 0.84, s * 0.48);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            hl,
            topLeft: Radius.circular(s * 0.22),
            topRight: Radius.circular(s * 0.22),
            bottomLeft: Radius.elliptical(hl.width / 2, hl.height * 0.3),
            bottomRight: Radius.elliptical(hl.width / 2, hl.height * 0.3),
          ),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_a(Colors.white, 0.5), _a(Colors.white, 0)],
            ).createShader(hl),
        );
        topEdge(0.55, width: 1.5);
        glyphShadow = _a(Colors.black, 0.28);
        glyphShadowOffset = Offset(0, s * 0.02);
        glyphShadowBlur = s * 0.025;
      case SettingsIconStyle.clay:
        radius = (s * 0.32).roundToDouble();
        outerShadow(
          _a(c.c2, 0.5),
          Offset(0, s * 0.12),
          s * 0.2,
          spread: -s * 0.06,
        );
        base(
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.44, -0.56),
              radius: 1.2,
              colors: [c.c1, c.c2],
            ).createShader(rect),
        );
        radialGlow(
          const Offset(0.18, 0.16),
          0.55,
          0.55,
          _a(Colors.white, 0.42),
          stop: 0.85,
        );
        radialGlow(
          const Offset(0.92, 0.96),
          0.6,
          0.6,
          _a(Colors.black, 0.24),
          stop: 0.85,
        );
        glyphScale = 0.56;
        glyphShadow = _a(Colors.black, 0.25);
        glyphShadowOffset = Offset(s * 0.02, s * 0.03);
        glyphShadowBlur = s * 0.02;
      case SettingsIconStyle.frost:
        outerShadow(_a(c.c2, 0.25), Offset.zero, s * 0.3);
        base(gradient(160, [_a(c.c1, 0.4), _a(c.c2, 0.25)]));
        canvas.drawRRect(
          rr().deflate(0.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = _a(c.c1, 0.5),
        );
        topEdge(0.28);
        glyphShadow = c.c1;
        glyphShadowBlur = s * 0.07;
      case SettingsIconStyle.pastel:
        base(Paint()..color = _a(c.c1, 0.2));
        fill = dark ? c.c1 : c.c2;
      case SettingsIconStyle.neon:
        outerShadow(_a(c.m, 0.45), Offset.zero, s * 0.22);
        base(Paint()..color = const Color(0xFF0A0C12));
        canvas.save();
        canvas.clipRRect(rr());
        canvas.drawRRect(
          rr(),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.16
            ..color = _a(c.m, 0.3)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08),
        );
        canvas.restore();
        canvas.drawRRect(
          rr().deflate(0.75),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = c.m,
        );
        fill = c.c1;
        glyphShadow = c.m;
        glyphShadowBlur = s * 0.07;
      case SettingsIconStyle.aurora:
        base(gradient(135, [c.m, c.p], const [0.1, 1]));
        radialGlow(
          const Offset(0.85, 0.1),
          0.6,
          0.6,
          _a(Colors.white, 0.45),
          stop: 0.7,
        );
        glyphShadow = _a(Colors.black, 0.2);
        glyphShadowOffset = Offset(0, s * 0.02);
        glyphShadowBlur = s * 0.04;
      case SettingsIconStyle.material:
        radius = s / 2;
        base(gradient(160, [c.c1, c.c2]));
        glyphScale = 0.54;
      case SettingsIconStyle.sticker:
        canvas.drawRRect(
          rr().shift(Offset(0, s * 0.06)),
          Paint()
            ..color = const Color(0x38141820)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08),
        );
        base(Paint()..color = Colors.white);
        final border = math.max(2.0, s * 0.07);
        canvas.drawRRect(rr().deflate(border), gradient(180, [c.c1, c.m]));
        glyphScale = 0.5;
      case SettingsIconStyle.mono:
        outerShadow(_a(Colors.black, 0.4), Offset(0, s * 0.04), s * 0.12);
        base(gradient(180, const [Color(0xFF2E2E31), Color(0xFF1A1A1C)]));
        topEdge(0.14);
        final g = Rect.fromCenter(
          center: rect.center,
          width: s * glyphScale,
          height: s * glyphScale,
        );
        glyphShader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.c1, c.c2],
        ).createShader(g);
      case SettingsIconStyle.glass:
        outerShadow(_a(c.c2, dark ? 0.47 : 0.33), Offset(0, s * 0.1), s * 0.32);
        base(
          gradient(160, [
            _a(c.c1, dark ? 0.76 : 0.85),
            _a(c.c2, dark ? 0.62 : 0.70),
          ]),
        );
        radialGlow(
          const Offset(0.25, -0.05),
          1.2,
          0.75,
          _a(Colors.white, 0.62),
          stop: 0.55,
        );
        radialGlow(
          const Offset(0.75, 1.08),
          0.7,
          0.45,
          _a(Colors.white, 0.45),
          stop: 0.7,
        );
        topEdge(0.95);
        canvas.drawRRect(
          rr().deflate(0.25),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..color = _a(Colors.white, 0.45),
        );
        glyphScale = 0.6;
        glyphShadow = _a(c.c2, 0.67);
        glyphShadowOffset = Offset(0, s * 0.03);
        glyphShadowBlur = s * 0.05;
    }

    _paintGlyph(
      canvas,
      s,
      glyphScale,
      fill: fill,
      shader: glyphShader,
      shadow: glyphShadow,
      shadowOffset: glyphShadowOffset,
      shadowBlur: glyphShadowBlur,
    );
  }

  void _paintGlyph(
    Canvas canvas,
    double s,
    double scale, {
    required Color fill,
    Shader? shader,
    Color? shadow,
    Offset shadowOffset = Offset.zero,
    double shadowBlur = 0,
  }) {
    final side = s * scale;
    final k = side / 24;
    final origin = Offset((s - side) / 2, (s - side) / 2);

    void pass({
      required Color color,
      Shader? shader,
      double blur = 0,
      Offset shift = Offset.zero,
    }) {
      canvas.save();
      canvas.translate(origin.dx + shift.dx, origin.dy + shift.dy);
      canvas.scale(k);
      if (glyph == SettingsGlyph.text) {
        final tp = TextPainter(
          text: TextSpan(
            text: kGlyphTextLabel,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              height: 1,
              foreground: Paint()
                ..color = color
                ..shader = shader
                ..maskFilter = blur > 0
                    ? MaskFilter.blur(BlurStyle.normal, blur / k)
                    : null,
            ),
          ),
          textDirection: textDirection,
        )..layout();
        tp.paint(canvas, Offset(12 - tp.width / 2, 12 - tp.height / 2));
      } else {
        for (final part in glyphParts(glyph)) {
          final paint = Paint()
            ..isAntiAlias = true
            ..color = color.withValues(alpha: color.a * part.opacity)
            ..shader = shader
            ..style = part.stroke ? PaintingStyle.stroke : PaintingStyle.fill
            ..strokeWidth = part.strokeWidth
            ..strokeCap = part.roundCap ? StrokeCap.round : StrokeCap.butt
            ..strokeJoin = StrokeJoin.round;
          if (blur > 0) {
            paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur / k);
          }
          canvas.drawPath(part.path, paint);
        }
      }
      canvas.restore();
    }

    if (shadow != null && (shadowBlur > 0 || shadowOffset != Offset.zero)) {
      pass(color: shadow, blur: shadowBlur, shift: shadowOffset);
    }
    pass(color: fill, shader: shader);
  }

  @override
  bool shouldRepaint(SettingsGlyphTilePainter old) =>
      old.glyph != glyph ||
      old.style != style ||
      old.dark != dark ||
      old.textDirection != textDirection;
}

/// Плитка картинкой — для проверочных снимков в тестах (сверка с макетом).
Future<ui.Image> renderSettingsGlyphTile({
  required SettingsGlyph glyph,
  required SettingsIconStyle style,
  required double size,
  bool dark = false,
  double pixelRatio = 3,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  // Поле вокруг — под тени и свечение, которые выходят за плитку.
  final pad = size * 0.4;
  canvas.translate(pad, pad);
  SettingsGlyphTilePainter(
    glyph: glyph,
    style: style,
    dark: dark,
  ).paint(canvas, Size.square(size));
  final picture = recorder.endRecording();
  final px = ((size + pad * 2) * pixelRatio).ceil();
  return picture.toImage(px, px);
}
