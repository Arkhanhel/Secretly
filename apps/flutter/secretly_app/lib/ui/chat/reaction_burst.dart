// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Эффекты приземления реакции (макет «Reactions Animation», 21.11.2026).
///
/// У каждой реакции свой эффект: ❤️ — сердечки и розовое кольцо, 🔥 — искры
/// и огоньки вверх, 😁 — конфетти с гравитацией, 👍 — лучи и звёздочки,
/// 👎 — пыль, 🥰 — сердечки всплывают, 👏 — три хлопка и конфетти; у 47
/// эмодзи раскрытой панели — свои (слёзы, пар, взрыв, снег, Zzz, нимб,
/// радуга, фонтан, дым, купюры…); любой другой — мини-копии разлетаются.
///
/// Один [CustomPainter] на все частицы (один слой, без виджета на частицу) —
/// не лагает и на слабых Android. Эмодзи-частицы рисуются из растров,
/// снятых один раз (прозрачность работает и для цветных эмодзи).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../gpu_image_guard.dart';

/// Пружина макета (CSS `linear(...)`): перелёт до 1,09 и успокоение.
class ReactionSpringCurve extends Curve {
  const ReactionSpringCurve();

  static const _pts = <(double, double)>[
    (0, 0),
    (0.09, 0.36),
    (0.20, 0.84),
    (0.30, 1.08),
    (0.36, 1.09),
    (0.48, 1.02),
    (0.60, 0.985),
    (0.78, 1.002),
    (1, 1),
  ];

  @override
  double transformInternal(double t) {
    for (var i = 1; i < _pts.length; i++) {
      final (x1, y1) = _pts[i];
      if (t <= x1) {
        final (x0, y0) = _pts[i - 1];
        return y0 + (y1 - y0) * ((t - x0) / (x1 - x0));
      }
    }
    return 1;
  }
}

/// Кадр частицы: положение от центра, поворот (градусы), масштаб, прозрачность.
class ReactionFrame {
  const ReactionFrame({
    this.x = 0,
    this.y = 0,
    this.r = 0,
    this.s,
    this.sx,
    this.sy,
    this.o = 1,
    this.at,
    this.curve,
    this.kx = 0,
    this.ky = 0,
    this.v = 0,
  });

  final double x;
  final double y;
  final double r;
  final double? s;
  final double? sx;
  final double? sy;
  final double o;

  /// Доля времени (как `offset` у WAAPI); `null` — равномерно.
  final double? at;

  /// Сглаживание отрезка ОТ этого кадра до следующего.
  final Curve? curve;

  /// Перекос (градусы, как CSS `skewX`/`skewY`) — для качки всего чата.
  final double kx;
  final double ky;

  /// Свободное значение кадра: доля прорисовки дуги, поворот оттенка слоя,
  /// сила окраски эмодзи (эффекты «эмодзи отдельным сообщением»).
  final double v;

  double get scaleX => sx ?? s ?? 1;
  double get scaleY => sy ?? s ?? 1;

  /// Тот же кадр, сдвинутый на ([dx], [dy]).
  ReactionFrame shift(double dx, double dy) => ReactionFrame(
    x: x + dx,
    y: y + dy,
    r: r,
    s: s,
    sx: sx,
    sy: sy,
    o: o,
    at: at,
    curve: curve,
    kx: kx,
    ky: ky,
    v: v,
  );
}

enum ReactionShape {
  glyph,
  dot,
  rect,
  drop,
  glow,
  ring,
  flash,

  /// Края экрана светятся внутрь цветом [ReactionParticle.color]
  /// (толщина — [ReactionParticle.size]).
  vignette,

  /// Снизу вверх градиент высотой [ReactionParticle.size].
  band,

  /// Затемнение всего экрана с прозрачным пятном вокруг начала
  /// (радиус пятна — [ReactionParticle.size]).
  spotlight,

  /// Заливка всего экрана: от прозрачного в центре к цвету по краям.
  wash,

  // ── Эмодзи отдельным сообщением (макет «Solo Emoji», 23.11.2026) ──

  /// Слово-звукоподражание («HA-HA», «HONK!», «Zzz») — текст [glyph]
  /// цвета [color] высотой [size], с тёмной обводкой.
  word,

  /// Луч света: от точки вниз на [height], ширина [width], градиент
  /// [colors] сверху вниз; поворот кадра — наклон луча.
  beam,

  /// Лепесток (скруглены два противоположных угла), [width]×[height].
  petal,

  /// Пятно [width]×[height]: овал ([oval]) или скруглённый прямоугольник;
  /// заливка [color] или радиальный градиент [colors]/[stops]; обводка
  /// [borderColor]; тень/свечение [glowColor].
  blob,

  /// Верхняя половина кольца (радуга), прорисовывается слева направо:
  /// доля — `v` кадра.
  arc,

  /// Солнечные лучи вокруг: [size] — поперечник.
  sunburst,

  /// Слой на весь экран по описанию [ReactionParticle.layer].
  screen,
}

/// Вид слоя на весь экран.
enum ReactionLayerKind {
  /// Сплошная заливка (с [ReactionLayer.hole] — с просветом у эмодзи).
  solid,

  /// Линейный градиент от [ReactionLayer.begin] к [ReactionLayer.end].
  linear,

  /// Радиальный градиент вокруг [ReactionLayer.center] до [ReactionLayer.r1].
  radial,

  /// Свечение с краёв внутрь, как CSS `box-shadow: inset 0 0 blur spread`.
  inset,

  /// Свечение только слева и справа (🤗 «объятие»).
  sides,
}

/// Описание слоя на весь экран (как `layer(...)` макета).
class ReactionLayer {
  const ReactionLayer({
    this.kind = ReactionLayerKind.solid,
    this.colors = const [Color(0x00000000)],
    this.stops,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
    this.center,
    this.r1,
    this.area,
    this.hole = false,
    this.gray = 0,
    this.hue = false,
    this.spread = 0,
    this.blur = 0,
  });

  final ReactionLayerKind kind;
  final List<Color> colors;
  final List<double>? stops;
  final Alignment begin;
  final Alignment end;

  /// Центр радиального (координаты слоя); `null` — середина.
  final Offset? center;

  /// Радиус радиального; `null` — до дальнего угла (как в CSS).
  final double? r1;

  /// Часть экрана (полоса снизу, столб света); `null` — весь.
  final Rect? area;

  /// Просвет вокруг эмодзи: прозрачно до 78 px, полностью — с 135 px.
  final bool hole;

  /// Обесцвечивание того, что под слоем (0…1, как `grayscale()`).
  final double gray;

  /// `v` кадра — поворот оттенка (градусы, как `hue-rotate()`).
  final bool hue;

  /// Для [ReactionLayerKind.inset]/[ReactionLayerKind.sides]: размах и
  /// размытие тени (px).
  final double spread;
  final double blur;
}

/// Одна частица эффекта.
class ReactionParticle {
  ReactionParticle({
    required this.shape,
    required this.frames,
    required this.duration,
    this.delay = 0,
    this.curve = Curves.linear,
    this.glyph,
    this.size = 10,
    this.width = 6,
    this.height = 10,
    this.color = Colors.white,
    this.colors,
    this.radius = 1.5,
    this.border = 2,
    this.shine = false,
    this.textColor,
    this.layer,
    this.stops,
    this.vertical = false,
    this.blur = 0,
    this.glowColor,
    this.shadowDy = 0,
    this.clip,
    this.oval = false,
    this.borderColor,
    this.gradR = 1,
    this.gradCenter = Alignment.center,
  });

  /// Слой на весь экран ([ReactionShape.screen]).
  final ReactionLayer? layer;

  /// Остановки градиента [colors] (`null` — равномерно).
  final List<double>? stops;

  /// Градиент прямоугольника сверху вниз (иначе слева направо).
  final bool vertical;

  /// Размытие (px, как CSS `blur()`); у [glowColor] — размытие тени.
  final double blur;

  /// Свечение/тень под фигурой ([ReactionShape.rect], [ReactionShape.blob]).
  final Color? glowColor;

  /// Сдвиг тени вниз (px).
  final double shadowDy;

  /// Обрезка эмодзи многоугольником (доли квадрата 0…1) — половинки 💔.
  final List<Offset>? clip;

  /// [ReactionShape.blob]: овал (иначе — скругление [radius]).
  final bool oval;

  /// [ReactionShape.blob]: цвет обводки толщиной [border].
  final Color? borderColor;

  /// Радиус радиального градиента [ReactionShape.blob] в долях половины
  /// размера (1 — до ближней стороны, √2 — до угла квадрата).
  final double gradR;

  /// Центр радиального градиента [ReactionShape.blob].
  final Alignment gradCenter;

  final ReactionShape shape;
  final List<ReactionFrame> frames;

  /// Миллисекунды.
  final double duration;
  final double delay;
  final Curve curve;
  final String? glyph;
  final double size;
  final double width;
  final double height;
  final Color color;
  final List<Color>? colors;
  final double radius;
  final double border;
  final bool shine;

  /// Цвет текста-символа (у 🤬 — «#@!»). `null` — эмодзи.
  final Color? textColor;

  double get end => delay + duration;

  /// Состояние в момент [ms] от начала эффекта (`null` — ещё/уже не видна).
  ReactionFrame? at(double ms) {
    if (ms < delay || ms > end) return null;
    final p = curve.transform(((ms - delay) / duration).clamp(0.0, 1.0));
    final n = frames.length;
    final offs = <double>[
      for (var i = 0; i < n; i++) frames[i].at ?? (n == 1 ? 0 : i / (n - 1)),
    ];
    var i = 0;
    while (i < n - 2 && p > offs[i + 1]) {
      i++;
    }
    final a = frames[i];
    final b = frames[math.min(i + 1, n - 1)];
    final span = offs[math.min(i + 1, n - 1)] - offs[i];
    var t = span <= 0 ? 1.0 : ((p - offs[i]) / span).clamp(0.0, 1.0);
    t = (a.curve ?? Curves.linear).transform(t);
    double l(double x, double y) => x + (y - x) * t;
    return ReactionFrame(
      x: l(a.x, b.x),
      y: l(a.y, b.y),
      r: l(a.r, b.r),
      sx: l(a.scaleX, b.scaleX),
      sy: l(a.scaleY, b.scaleY),
      o: l(a.o, b.o).clamp(0.0, 1.0),
      kx: l(a.kx, b.kx),
      ky: l(a.ky, b.ky),
      v: l(a.v, b.v),
    );
  }
}

/// Рисует эффект целиком: [origin] — точка приземления в координатах слоя.
class ReactionBurstPainter extends CustomPainter {
  ReactionBurstPainter({
    required this.particles,
    required this.ms,
    required this.origin,
  });

  final List<ReactionParticle> particles;
  final double ms;
  final Offset origin;

  static final Map<String, ui.Image> _glyphs = {};
  static const double _raster = 72;

  /// Эмодзи один раз в растр — прозрачность и масштаб без перерисовки шрифта.
  static bool _glyphsGuarded = false;

  /// Крупные эмодзи (💥 140, 🚀 120, половинки 💔 124) — из растра крупнее,
  /// чтобы не мылились.
  static const double _rasterHi = 160;

  static ui.Image _glyph(String g, Color? color, [bool hi = false]) {
    final key = '$g|${color?.toARGB32()}|${hi ? 1 : 0}';
    final hit = _glyphs[key];
    if (hit != null) return hit;
    _guard();
    final img = _makeGlyph(g, color, hi ? _rasterHi : _raster);
    _glyphs[key] = img;
    return img;
  }

  static void _guard() {
    if (_glyphsGuarded) return;
    _glyphsGuarded = true;
    GpuImageGuard.register(_glyphs.clear);
  }

  static ui.Image _makeGlyph(String g, Color? color, double raster) {
    return () {
      final tp = TextPainter(
        text: TextSpan(
          text: g,
          style: TextStyle(
            fontSize: raster * 0.82,
            height: 1,
            color: color ?? Colors.white,
            fontWeight: color == null ? null : FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      tp.paint(
        c,
        Offset((raster - tp.width) / 2, (raster - tp.height) / 2),
      );
      return rec.endRecording().toImageSync(raster.toInt(), raster.toInt());
    }();
  }

  /// Высота шрифта растра слова (px).
  static const double _wordRaster = 64;

  /// Слово макета: жирный системный шрифт, обводка `rgba(20,24,40,.55)`
  /// под заливкой. Растр один раз — дальше только масштаб и прозрачность.
  static ui.Image _word(String text, Color color) {
    final key = 'w|$text|${color.toARGB32()}';
    final hit = _glyphs[key];
    if (hit != null) return hit;
    _guard();
    TextPainter tp(Paint? stroke) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: _wordRaster,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
          color: stroke == null ? color : null,
          foreground: stroke,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final fill = tp(null);
    final edge = tp(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0x8C141828),
    );
    const pad = 6.0;
    final w = (fill.width + pad * 2).ceil();
    final h = (fill.height + pad * 2).ceil();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    edge.paint(c, const Offset(pad, pad));
    fill.paint(c, const Offset(pad, pad));
    final img = rec.endRecording().toImageSync(w, h);
    _glyphs[key] = img;
    return img;
  }

  /// Слои на весь экран (рисуются без переноса в точку эмодзи).
  static const Set<ReactionShape> _layers = {
    ReactionShape.vignette,
    ReactionShape.band,
    ReactionShape.spotlight,
    ReactionShape.wash,
    ReactionShape.screen,
  };

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final f = p.at(ms);
      if (f == null || f.o <= 0.004) continue;
      if (p.shape == ReactionShape.flash) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = p.color.withValues(alpha: p.color.a * f.o),
        );
        continue;
      }
      if (_layers.contains(p.shape)) {
        if (p.shape == ReactionShape.screen) {
          _paintScreen(canvas, size, p, f);
        } else {
          _paintLayer(canvas, size, p, f);
        }
        continue;
      }
      canvas.save();
      canvas.translate(origin.dx + f.x, origin.dy + f.y);
      if (f.r != 0) canvas.rotate(f.r * math.pi / 180);
      canvas.scale(f.scaleX, f.scaleY);
      final paint = Paint()..isAntiAlias = true;
      switch (p.shape) {
        case ReactionShape.glyph:
          final s = p.size;
          final hi = s * math.max(f.scaleX.abs(), f.scaleY.abs()) > 90;
          final img = _glyph(p.glyph ?? '✨', p.textColor, hi);
          final rs = hi ? _rasterHi : _raster;
          paint
            ..filterQuality = FilterQuality.medium
            ..color = Color.fromRGBO(255, 255, 255, f.o);
          final dst = Rect.fromCenter(center: Offset.zero, width: s, height: s);
          final clip = p.clip;
          if (clip != null && clip.length > 2) {
            canvas.clipPath(
              Path()..addPolygon([
                for (final c in clip)
                  Offset(dst.left + c.dx * s, dst.top + c.dy * s),
              ], true),
            );
          }
          canvas.drawImageRect(img, Rect.fromLTWH(0, 0, rs, rs), dst, paint);
        case ReactionShape.word:
          final img = _word(p.glyph ?? '', p.color);
          final k = p.size / _wordRaster;
          paint
            ..filterQuality = FilterQuality.medium
            ..color = Color.fromRGBO(255, 255, 255, f.o);
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromCenter(
              center: Offset.zero,
              width: img.width * k,
              height: img.height * k,
            ),
            paint,
          );
        case ReactionShape.beam:
          final rect = Rect.fromLTWH(-p.width / 2, 0, p.width, p.height);
          final cs = p.colors ?? [p.color, p.color.withValues(alpha: 0)];
          paint.shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [for (final c in cs) c.withValues(alpha: c.a * f.o)],
            stops: p.stops,
          ).createShader(rect);
          if (p.blur > 0) {
            paint.maskFilter = MaskFilter.blur(BlurStyle.normal, p.blur);
          }
          canvas.drawRect(rect, paint);
        case ReactionShape.petal:
          final w = p.width, h = p.height;
          final rx = w * 0.6, ry = h * 0.6;
          final path = Path()
            ..moveTo(-w / 2 + rx, -h / 2)
            ..lineTo(w / 2, -h / 2)
            ..lineTo(w / 2, h / 2 - ry)
            ..arcToPoint(
              Offset(w / 2 - rx, h / 2),
              radius: Radius.elliptical(rx, ry),
            )
            ..lineTo(-w / 2, h / 2)
            ..lineTo(-w / 2, -h / 2 + ry)
            ..arcToPoint(
              Offset(-w / 2 + rx, -h / 2),
              radius: Radius.elliptical(rx, ry),
            )
            ..close();
          canvas.drawPath(
            path,
            paint..color = p.color.withValues(alpha: p.color.a * f.o),
          );
        case ReactionShape.blob:
          _paintBlob(canvas, p, f, paint);
        case ReactionShape.arc:
          final r = p.size / 2 - p.border / 2;
          final reveal = f.v.clamp(0.0, 1.0);
          if (reveal <= 0) break;
          canvas.clipRect(
            Rect.fromLTRB(-p.size / 2, -p.size / 2,
                -p.size / 2 + p.size * reveal, 0),
          );
          final c = p.color.withValues(alpha: p.color.a * f.o);
          canvas.drawCircle(
            Offset.zero,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = p.border + 8
              ..color = c.withValues(alpha: c.a * 0.22),
          );
          canvas.drawCircle(
            Offset.zero,
            r,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = p.border
              ..color = c,
          );
        case ReactionShape.sunburst:
          // 18 лучей по 8° через 20°, видимы до 12 %, гаснут к 62 % (маска).
          final big = p.size / 2 * math.sqrt2;
          final r0 = big * 0.12, r1 = big * 0.62;
          final c = p.color.withValues(alpha: p.color.a * f.o);
          final path = Path();
          for (var i = 0; i < 18; i++) {
            final a0 = (i * 20 - 90) * math.pi / 180;
            final a1 = a0 + 8 * math.pi / 180;
            path
              ..moveTo(0, 0)
              ..lineTo(math.cos(a0) * r1, math.sin(a0) * r1)
              ..lineTo(math.cos(a1) * r1, math.sin(a1) * r1)
              ..close();
          }
          paint.shader = ui.Gradient.radial(
            Offset.zero,
            r1,
            [c, c, c.withValues(alpha: 0)],
            [0, r0 / r1, 1],
          );
          canvas.drawPath(path, paint);
        case ReactionShape.dot:
          final c = p.color.withValues(alpha: p.color.a * f.o);
          if (p.shine) {
            canvas.drawCircle(
              Offset.zero,
              p.size * 1.3,
              Paint()
                ..color = c.withValues(alpha: c.a * 0.45)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.9),
            );
          }
          canvas.drawCircle(Offset.zero, p.size / 2, paint..color = c);
        case ReactionShape.rect:
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: p.width,
            height: p.height,
          );
          final cs = p.colors;
          final rr = RRect.fromRectAndRadius(rect, Radius.circular(p.radius));
          final glow = p.glowColor;
          if (glow != null) {
            // Свечение молнии/трещины (CSS `box-shadow: 0 0 14px 4px`).
            canvas.drawRRect(
              rr.inflate(p.blur * 0.3),
              Paint()
                ..color = glow.withValues(alpha: glow.a * f.o)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.blur / 2),
            );
          }
          if (cs != null) {
            paint.shader = LinearGradient(
              begin: p.vertical ? Alignment.topCenter : Alignment.centerLeft,
              end: p.vertical ? Alignment.bottomCenter : Alignment.centerRight,
              colors: [for (final c in cs) c.withValues(alpha: c.a * f.o)],
              stops: p.stops,
            ).createShader(rect);
          } else {
            paint.color = p.color.withValues(alpha: p.color.a * f.o);
          }
          canvas.drawRRect(rr, paint);
        case ReactionShape.drop:
          final w = p.size;
          final h = p.size * 1.35;
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: w,
            height: h,
          );
          final cs = p.colors ?? const [Color(0xFFBDE6FF), Color(0xFF3AA0FF)];
          paint.shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [for (final c in cs) c.withValues(alpha: c.a * f.o)],
          ).createShader(rect);
          final path = Path()
            ..moveTo(0, -h / 2)
            ..cubicTo(w * 0.5, -h * 0.1, w * 0.5, h / 2, 0, h / 2)
            ..cubicTo(-w * 0.5, h / 2, -w * 0.5, -h * 0.1, 0, -h / 2);
          canvas.drawPath(path, paint);
        case ReactionShape.glow:
          final r = p.size / 2;
          paint.shader = RadialGradient(
            colors: [
              p.color.withValues(alpha: p.color.a * f.o),
              p.color.withValues(alpha: 0),
            ],
            stops: const [0, 0.68],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
          canvas.drawCircle(Offset.zero, r, paint);
        case ReactionShape.ring:
          canvas.drawCircle(
            Offset.zero,
            p.size / 2 - p.border / 2,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = p.border
              ..color = p.color.withValues(alpha: p.color.a * f.o),
          );
        case ReactionShape.flash:
        case ReactionShape.vignette:
        case ReactionShape.band:
        case ReactionShape.spotlight:
        case ReactionShape.wash:
        case ReactionShape.screen:
          break;
      }
      canvas.restore();
    }
  }

  /// Пятно: тень/свечение, заливка (цвет или радиальный градиент), обводка.
  void _paintBlob(Canvas canvas, ReactionParticle p, ReactionFrame f, Paint paint) {
    final w = p.width, h = p.height;
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final rr = p.oval
        ? RRect.fromRectXY(rect, w / 2, h / 2)
        : RRect.fromRectAndRadius(rect, Radius.circular(p.radius));
    final glow = p.glowColor;
    final cs = p.colors;
    final hollow = cs == null && p.color.a == 0 && p.borderColor != null;
    if (glow != null) {
      final gp = Paint()
        ..color = glow.withValues(alpha: glow.a * f.o)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.blur / 2);
      if (hollow) {
        // Кольцо (нимб 😇): свечение вдоль обводки, а не сплошным пятном.
        gp
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.border * 1.6;
        canvas.drawRRect(rr.deflate(p.border / 2), gp);
      } else {
        canvas.drawRRect(rr.shift(Offset(0, p.shadowDy)), gp);
      }
    }
    if (cs != null) {
      // Радиальный градиент в единичных координатах: эллипс «closest-side»
      // растягивается вместе с пятном, как в CSS.
      canvas.save();
      canvas.scale(w / 2, h / 2);
      paint.shader = ui.Gradient.radial(
        Offset(p.gradCenter.x, p.gradCenter.y),
        p.gradR,
        [for (final c in cs) c.withValues(alpha: c.a * f.o)],
        p.stops,
      );
      canvas.drawRRect(
        p.oval
            ? RRect.fromRectXY(const Rect.fromLTRB(-1, -1, 1, 1), 1, 1)
            : RRect.fromRectXY(
                const Rect.fromLTRB(-1, -1, 1, 1),
                p.radius / (w / 2),
                p.radius / (h / 2),
              ),
        paint,
      );
      canvas.restore();
    } else if (p.color.a > 0) {
      canvas.drawRRect(
        rr,
        paint..color = p.color.withValues(alpha: p.color.a * f.o),
      );
    }
    final bc = p.borderColor;
    if (bc != null) {
      canvas.drawRRect(
        rr.deflate(p.border / 2),
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.border
          ..color = bc.withValues(alpha: bc.a * f.o),
      );
    }
  }

  /// Нормальное распределение (для тени `inset`, как в CSS).
  static double _phi(double z) {
    // Приближение Абрамовица — Стегуна, точности хватает для градиента.
    final t = 1 / (1 + 0.2316419 * z.abs());
    final d = 0.3989423 * math.exp(-z * z / 2);
    final q = d *
        t *
        (0.3193815 +
            t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
    return z >= 0 ? 1 - q : q;
  }

  /// Поворот оттенка цвета (матрица CSS `hue-rotate()`).
  static Color _hue(Color c, double deg) {
    if (deg == 0) return c;
    final a = deg * math.pi / 180, cs = math.cos(a), sn = math.sin(a);
    final r = c.r, g = c.g, b = c.b;
    double cl(double v) => v.clamp(0.0, 1.0);
    return Color.from(
      alpha: c.a,
      red: cl(r * (0.213 + cs * 0.787 - sn * 0.213) +
          g * (0.715 - cs * 0.715 - sn * 0.715) +
          b * (0.072 - cs * 0.072 + sn * 0.928)),
      green: cl(r * (0.213 - cs * 0.213 + sn * 0.143) +
          g * (0.715 + cs * 0.285 + sn * 0.140) +
          b * (0.072 - cs * 0.072 - sn * 0.283)),
      blue: cl(r * (0.213 - cs * 0.213 - sn * 0.787) +
          g * (0.715 - cs * 0.715 + sn * 0.715) +
          b * (0.072 + cs * 0.928 + sn * 0.072)),
    );
  }

  /// Слой на весь экран по описанию (как `layer(...)` макета): заливка,
  /// градиенты, свечение с краёв, просвет у эмодзи, обесцвечивание.
  void _paintScreen(Canvas canvas, Size size, ReactionParticle p, ReactionFrame f) {
    final l = p.layer;
    if (l == null) return;
    final all = Offset.zero & size;
    final area = l.area ?? all;
    final cols = [
      for (final c in l.colors)
        (l.hue ? _hue(c, f.v) : c).withValues(alpha: c.a * f.o),
    ];
    canvas.save();
    // Радиальный слой двигает центр и радиус (фонарик 👀), остальные —
    // сдвигаются и растягиваются целиком (лужа 😭, объятие 🤗).
    final radial = l.kind == ReactionLayerKind.radial;
    if (!radial && (f.x != 0 || f.y != 0)) canvas.translate(f.x, f.y);
    if (!radial && (f.scaleX != 1 || f.scaleY != 1)) {
      final c = area.center;
      canvas
        ..translate(c.dx, c.dy)
        ..scale(f.scaleX, f.scaleY)
        ..translate(-c.dx, -c.dy);
    }
    // Обесцвечивание того, что под слоем: режим «насыщенность» с серым
    // (как `backdrop-filter: grayscale()`), с тем же просветом у эмодзи.
    if (l.gray > 0) {
      final g = Color.fromRGBO(128, 128, 128, (l.gray * f.o).clamp(0.0, 1.0));
      final gp = Paint()..blendMode = BlendMode.saturation;
      if (l.hole) {
        gp.shader = ui.Gradient.radial(
          origin,
          135,
          [g.withValues(alpha: 0), g.withValues(alpha: 0), g],
          const [0, 78 / 135, 1],
        );
      } else {
        gp.color = g;
      }
      canvas.drawRect(area, gp);
    }
    final paint = Paint();
    switch (l.kind) {
      case ReactionLayerKind.solid:
        final c = cols.first;
        if (l.hole) {
          paint.shader = ui.Gradient.radial(
            origin,
            135,
            [c.withValues(alpha: 0), c.withValues(alpha: 0), c],
            const [0, 78 / 135, 1],
          );
        } else {
          paint.color = c;
        }
        canvas.drawRect(area, paint);
      case ReactionLayerKind.linear:
        paint.shader = LinearGradient(
          begin: l.begin,
          end: l.end,
          colors: cols,
          stops: l.stops,
        ).createShader(area);
        canvas.drawRect(area, paint);
      case ReactionLayerKind.radial:
        final c = (l.center ?? area.center).translate(f.x, f.y);
        final r = (l.r1 ??
                math.sqrt(
                  math.pow(math.max(c.dx - area.left, area.right - c.dx), 2) +
                      math.pow(math.max(c.dy - area.top, area.bottom - c.dy), 2),
                )) *
            f.scaleX.abs().clamp(0.01, 100.0);
        paint.shader = ui.Gradient.radial(c, r, cols, l.stops);
        canvas.drawRect(area, paint);
      case ReactionLayerKind.inset:
      case ReactionLayerKind.sides:
        // Тень внутрь: полоса [spread], дальше гаснет по Гауссу (σ = blur/2).
        final s = l.spread, sg = math.max(1.0, l.blur / 2);
        final t = math.max(1.0, s + sg * 2.2);
        final c = cols.first;
        final st = [0.0, 0.25, 0.5, 0.75, 1.0];
        final cc = [
          for (final k in st)
            c.withValues(alpha: c.a * (1 - _phi((k * t - s) / sg))),
        ];
        final w = size.width, h = size.height;
        final bands = <(Rect, Alignment, Alignment)>[
          (Rect.fromLTWH(0, 0, t, h), Alignment.centerLeft, Alignment.centerRight),
          (Rect.fromLTWH(w - t, 0, t, h), Alignment.centerRight, Alignment.centerLeft),
          if (l.kind == ReactionLayerKind.inset) ...[
            (Rect.fromLTWH(0, 0, w, t), Alignment.topCenter, Alignment.bottomCenter),
            (Rect.fromLTWH(0, h - t, w, t), Alignment.bottomCenter, Alignment.topCenter),
          ],
        ];
        for (final (rect, b, e) in bands) {
          paint.shader = LinearGradient(begin: b, end: e, colors: cc, stops: st)
              .createShader(rect);
          canvas.drawRect(rect, paint);
        }
    }
    canvas.restore();
  }

  /// Слои на весь экран (виньетка, свечение снизу, пятно света, заливка).
  void _paintLayer(Canvas canvas, Size size, ReactionParticle p, ReactionFrame f) {
    final c = p.color.withValues(alpha: p.color.a * f.o);
    final clear = p.color.withValues(alpha: 0);
    final all = Offset.zero & size;
    final paint = Paint();
    switch (p.shape) {
      case ReactionShape.vignette:
        final t = p.size;
        for (final (rect, begin, end) in [
          (Rect.fromLTWH(0, 0, size.width, t), Alignment.topCenter, Alignment.bottomCenter),
          (Rect.fromLTWH(0, size.height - t, size.width, t), Alignment.bottomCenter, Alignment.topCenter),
          (Rect.fromLTWH(0, 0, t, size.height), Alignment.centerLeft, Alignment.centerRight),
          (Rect.fromLTWH(size.width - t, 0, t, size.height), Alignment.centerRight, Alignment.centerLeft),
        ]) {
          paint.shader = LinearGradient(
            begin: begin,
            end: end,
            colors: [c, clear],
          ).createShader(rect);
          canvas.drawRect(rect, paint);
        }
      case ReactionShape.band:
        final rect = Rect.fromLTWH(
          0,
          size.height - p.size,
          size.width,
          p.size,
        );
        paint.shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [c, c.withValues(alpha: c.a * 0.33), clear],
          stops: const [0, 0.55, 1],
        ).createShader(rect);
        canvas.drawRect(rect, paint);
      case ReactionShape.spotlight:
        final r = math.max(size.width, size.height);
        paint.shader = RadialGradient(
          center: Alignment(
            origin.dx / size.width * 2 - 1,
            origin.dy / size.height * 2 - 1,
          ),
          radius: r / math.min(size.width, size.height),
          colors: [clear, clear, c],
          stops: [0, (p.size / r).clamp(0.0, 1.0), ((p.size * 2.4) / r).clamp(0.0, 1.0)],
        ).createShader(all);
        canvas.drawRect(all, paint);
      case ReactionShape.wash:
        paint.shader = RadialGradient(
          radius: 0.9,
          colors: [clear, c],
        ).createShader(all);
        canvas.drawRect(all, paint);
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(ReactionBurstPainter old) =>
      old.ms != ms || old.origin != origin;
}

/// Длительность эффекта целиком (мс).
double reactionBurstDuration(List<ReactionParticle> ps) =>
    ps.fold<double>(0, (a, p) => math.max(a, p.end));

/// Отклик сообщения на приземление.
enum ReactionLanding {
  /// Мягкое «прихлопывание» (по умолчанию).
  squash,

  /// Тяжёлое падение (👎, 💩).
  heavy,

  /// Удар (🤯, 💪).
  boom,
}

/// Как приземляется эмодзи и вздрагивает ли сообщение.
({ReactionLanding landing, bool shake, bool fallsDown}) reactionMeta(
  String e,
) {
  const down = {'👎', '💩'};
  const shake = {'👎', '🤯', '😡', '🤬', '💪', '💔'};
  const boom = {'🤯', '💪'};
  return (
    landing: down.contains(e)
        ? ReactionLanding.heavy
        : boom.contains(e)
        ? ReactionLanding.boom
        : ReactionLanding.squash,
    shake: shake.contains(e),
    fallsDown: down.contains(e),
  );
}

/// Частицы эффекта для [e]. [intensity] — множитель количества (0,4…1,8).
List<ReactionParticle> reactionBurstFor(
  String e, {
  math.Random? random,
  double intensity = 1,
}) => ReactionFxBuilder(random ?? math.Random(), intensity).build(e);

/// Строитель частиц (общий у реакций и эмодзи отдельным сообщением).
class ReactionFxBuilder {
  ReactionFxBuilder(this.rnd, this.intensity);

  final math.Random rnd;
  final double intensity;
  final List<ReactionParticle> out = [];

  static const pi = math.pi;
  static const _out = Cubic(0.15, 0.75, 0.35, 1);
  static const _rise = Cubic(0.2, 0.6, 0.4, 1);
  static const _ringCurve = Cubic(0.2, 0.8, 0.3, 1);
  static const _up = Cubic(0.1, 0.7, 0.3, 1);
  static const _down = Cubic(0.45, 0, 0.9, 0.6);
  static const _def = [
    Color(0xFFFFD43B),
    Color(0xFFFF6B9A),
    Color(0xFF4DABF7),
    Color(0xFF69DB7C),
    Color(0xFFB197FC),
    Color(0xFFFF922B),
  ];
  static const _gold = [
    Color(0xFFFFD43B),
    Color(0xFFFCC419),
    Color(0xFFFFE066),
    Color(0xFFF59F00),
    Color(0xFFFFF3BF),
  ];

  double r(double a, double b) => a + rnd.nextDouble() * (b - a);
  int n(num c) => math.max(1, (c * intensity).round());

  void add(ReactionParticle p) => out.add(p);

  void glyph(
    String ch,
    double size,
    List<ReactionFrame> f,
    double d, [
    double delay = 0,
    Curve curve = Curves.linear,
    Color? text,
  ]) => add(
    ReactionParticle(
      shape: ReactionShape.glyph,
      glyph: ch,
      size: size,
      frames: f,
      duration: d,
      delay: delay,
      curve: curve,
      textColor: text,
    ),
  );

  void dot(
    double size,
    Color c,
    List<ReactionFrame> f,
    double d, [
    double delay = 0,
    Curve curve = Curves.linear,
    bool shine = false,
  ]) => add(
    ReactionParticle(
      shape: ReactionShape.dot,
      size: size,
      color: c,
      frames: f,
      duration: d,
      delay: delay,
      curve: curve,
      shine: shine,
    ),
  );

  void rect(
    double w,
    double h,
    Color c,
    List<ReactionFrame> f,
    double d, [
    double delay = 0,
    Curve curve = Curves.linear,
    double radius = 1.5,
  ]) => add(
    ReactionParticle(
      shape: ReactionShape.rect,
      width: w,
      height: h,
      color: c,
      radius: radius,
      frames: f,
      duration: d,
      delay: delay,
      curve: curve,
    ),
  );

  void drop(
    double size,
    List<ReactionFrame> f,
    double d, [
    double delay = 0,
    Curve curve = Curves.linear,
    List<Color>? colors,
  ]) => add(
    ReactionParticle(
      shape: ReactionShape.drop,
      size: size,
      colors: colors,
      frames: f,
      duration: d,
      delay: delay,
      curve: curve,
    ),
  );

  void glow(Color c, double size, double d, [double delay = 0]) => add(
    ReactionParticle(
      shape: ReactionShape.glow,
      size: size,
      color: c,
      frames: const [
        ReactionFrame(s: 0.3, o: 0),
        ReactionFrame(s: 1.05, o: 1, at: 0.3),
        ReactionFrame(s: 1, o: 0),
      ],
      duration: d,
      delay: delay,
      curve: Curves.easeOut,
    ),
  );

  void pulsingGlow(Color c, double size, double d, List<ReactionFrame> f) =>
      add(
        ReactionParticle(
          shape: ReactionShape.glow,
          size: size,
          color: c,
          frames: f,
          duration: d,
        ),
      );

  void ring(Color c, double size, double bw, double d, [double delay = 0]) =>
      add(
        ReactionParticle(
          shape: ReactionShape.ring,
          size: size,
          border: bw,
          color: c,
          frames: const [ReactionFrame(s: 0.15), ReactionFrame(s: 1, o: 0)],
          duration: d,
          delay: delay,
          curve: _ringCurve,
        ),
      );

  /// Луч: от центра под углом [a] (градусы), из радиуса r0 в r1.
  void ray(
    double a,
    double len,
    double w,
    Color c,
    double r0,
    double r1,
    double d,
    double delay,
  ) {
    final rad = a * pi / 180;
    ReactionFrame f(double rr, double sy, double o, [double? at]) =>
        ReactionFrame(
          x: math.sin(rad) * rr,
          y: -math.cos(rad) * rr,
          r: a,
          sx: 1,
          sy: sy,
          o: o,
          at: at,
        );
    rect(
      w,
      len,
      c,
      [f(r0, 0.2, 0), f((r0 + r1) / 2, 1, 1, 0.4), f(r1, 0.3, 0)],
      d,
      delay,
      _ringCurve,
      w,
    );
  }

  void rays(
    int cnt,
    List<Color> cols,
    double r0,
    double r1,
    double w, [
    double delay = 0,
    double len = 16,
    double d = 520,
  ]) {
    final c = n(cnt);
    for (var i = 0; i < c; i++) {
      ray(
        i / c * 360 + r(-6, 6),
        r(len * 0.75, len * 1.25),
        w,
        cols[i % cols.length],
        r0,
        r1,
        d,
        delay,
      );
    }
  }

  void flash(Color c, [double d = 260]) => add(
    ReactionParticle(
      shape: ReactionShape.flash,
      color: c,
      frames: const [
        ReactionFrame(o: 0),
        ReactionFrame(o: 1, at: 0.15),
        ReactionFrame(o: 0),
      ],
      duration: d,
      curve: Curves.easeOut,
    ),
  );

  void spray(
    List<String> chars,
    int cnt,
    double d0,
    double d1,
    double s0,
    double s1, {
    double lift = 0,
    double spin = 1,
    double spread = 80,
  }) {
    for (var i = 0; i < n(cnt); i++) {
      final a = r(0, 2 * pi), d = r(d0, d1);
      glyph(chars[i % chars.length], r(s0, s1), [
        const ReactionFrame(s: 0.2, o: 0),
        ReactionFrame(
          x: math.cos(a) * d * 0.6,
          y: math.sin(a) * d * 0.6 - lift * 0.5,
          s: 1,
          r: r(-30, 30),
          at: 0.3,
        ),
        ReactionFrame(
          x: math.cos(a) * d,
          y: math.sin(a) * d - lift,
          s: 0.6,
          o: 0,
          r: r(-60, 60) * spin,
        ),
      ], r(800, 1150), r(0, spread), _out);
    }
  }

  void sparks(
    List<Color> cols,
    int cnt,
    double d0,
    double d1, [
    double sz0 = 3,
    double sz1 = 6,
    double delay = 0,
  ]) {
    for (var i = 0; i < n(cnt); i++) {
      final a = r(0, 2 * pi), d = r(d0, d1);
      dot(r(sz0, sz1), cols[i % cols.length], [
        const ReactionFrame(s: 0.3, o: 0),
        ReactionFrame(
          x: math.cos(a) * d * 0.7,
          y: math.sin(a) * d * 0.7,
          at: 0.35,
        ),
        ReactionFrame(x: math.cos(a) * d, y: math.sin(a) * d, s: 0.4, o: 0),
      ], r(600, 900), delay + r(0, 60), _out, true);
    }
  }

  void confetti(
    int cnt, [
    double delay = 0,
    List<Color> cols = _def,
    double w0 = 5,
    double w1 = 8,
    double h0 = 8,
    double h1 = 12,
  ]) {
    for (var i = 0; i < n(cnt); i++) {
      final a = r(-pi * 0.95, -pi * 0.05), d = r(70, 140);
      rect(r(w0, w1), r(h0, h1), cols[i % cols.length], [
        const ReactionFrame(s: 0.3, curve: _up),
        ReactionFrame(
          x: math.cos(a) * d,
          y: math.sin(a) * d,
          r: r(120, 300),
          at: 0.38,
          curve: _down,
        ),
        ReactionFrame(
          x: math.cos(a) * d * 1.3,
          y: math.sin(a) * d + r(110, 170),
          r: r(500, 900),
          s: 0.9,
          o: 0,
        ),
      ], r(1200, 1600), delay + r(0, 60));
    }
  }

  void rise(
    List<String> chars,
    int cnt, {
    double xs = 44,
    double h0 = 150,
    double h1 = 210,
    double s0 = 12,
    double s1 = 20,
    double spread = 500,
    double sway = 14,
  }) {
    for (var i = 0; i < n(cnt); i++) {
      final x0 = r(-xs, xs), y0 = r(-10, 20), top = r(h0, h1), ph = r(0, 6.28);
      final f = <ReactionFrame>[
        for (var j = 0; j <= 5; j++)
          ReactionFrame(
            x: x0 + math.sin(ph + j / 5 * 5) * sway,
            y: y0 - top * j / 5,
            s: j == 0 ? 0.3 : (j < 3 ? 1 : 0.7),
            o: j == 0 || j == 5 ? 0 : 1,
          ),
      ];
      glyph(
        chars[i % chars.length],
        r(s0, s1),
        f,
        r(1400, 2000),
        r(0, spread),
        const Cubic(0.3, 0.5, 0.5, 1),
      );
    }
  }

  void fall(List<String> chars, int cnt) {
    for (var i = 0; i < n(cnt); i++) {
      final x0 = r(-100, 100), y0 = -r(90, 150), ph = r(0, 6.28);
      final dy = r(200, 240), rr = r(-120, 120);
      glyph(chars[i % chars.length], r(10, 18), [
        for (var j = 0; j <= 5; j++)
          ReactionFrame(
            x: x0 + math.sin(ph + j / 5 * 4) * 16,
            y: y0 + j / 5 * dy,
            r: j / 5 * rr,
            s: j == 0 ? 0.4 : 1,
            o: j == 0 || j == 5 ? 0 : 1,
          ),
      ], r(1400, 1900), r(0, 600));
    }
  }

  void embers(List<Color> cols, int cnt) {
    for (var i = 0; i < n(cnt); i++) {
      final x0 = r(-34, 34), y0 = r(-6, 26), up = r(90, 180);
      dot(r(3, 7), cols[i % cols.length], [
        ReactionFrame(x: x0, y: y0, s: 0.5, o: 0),
        ReactionFrame(x: x0 + r(-20, 20), y: y0 - up * 0.4, at: 0.25),
        ReactionFrame(x: x0 + r(-30, 30), y: y0 - up * 0.75, o: 0.8, at: 0.65),
        ReactionFrame(x: x0 + r(-36, 36), y: y0 - up, s: 0.3, o: 0),
      ], r(900, 1500), r(0, 320), _rise, true);
    }
  }

  void puffs(
    Color c,
    int cnt, {
    double r0 = 60,
    double r1 = 120,
    double s0 = 12,
    double s1 = 24,
  }) {
    for (var i = 0; i < n(cnt); i++) {
      final a = r(0, 2 * pi), d = r(r0, r1);
      dot(r(s0, s1), c, [
        const ReactionFrame(s: 0.3, o: 0.9),
        ReactionFrame(
          x: math.cos(a) * d * 0.6,
          y: math.sin(a) * d * 0.6,
          s: 1.2,
          o: 0.6,
          at: 0.45,
        ),
        ReactionFrame(x: math.cos(a) * d, y: math.sin(a) * d, s: 1.7, o: 0),
      ], r(700, 1000), r(0, 60), _out);
    }
  }

  void tears(int cnt, bool big) {
    for (var i = 0; i < n(cnt); i++) {
      final sd = i.isOdd ? 1.0 : -1.0;
      final vx = sd * r(50, big ? 130 : 100), pk = -r(20, big ? 80 : 55);
      drop(r(6, 10), [
        ReactionFrame(x: sd * 18, y: -4, s: 0.4, o: 0, curve: _up),
        ReactionFrame(x: vx * 0.5, y: pk, s: 1, at: 0.4, curve: _down),
        ReactionFrame(x: vx, y: r(70, 120), s: 0.8, o: 0),
      ], r(700, 950), r(0, big ? 700 : 300));
    }
  }

  void hearts() {
    glow(const Color(0x8CFF486C), 180, 900);
    ring(const Color(0xFFFF5C7A), 160, 3, 620);
    for (var i = 0; i < n(14); i++) {
      final a = r(0, 2 * pi), d = r(70, 130);
      glyph(i % 5 == 0 ? '💖' : '❤️', r(10, 20), [
        const ReactionFrame(s: 0.2, o: 0),
        ReactionFrame(
          x: math.cos(a) * d * 0.6,
          y: math.sin(a) * d * 0.6 - 10,
          s: 1,
          r: r(-30, 30),
          at: 0.3,
        ),
        ReactionFrame(
          x: math.cos(a) * d,
          y: math.sin(a) * d - 30,
          s: 0.7,
          o: 0,
          r: r(-50, 50),
        ),
      ], r(800, 1150), r(0, 80), _out);
    }
    sparks(const [Color(0xFFFF8FA8)], 10, 50, 100, 4, 7);
  }

  void fire() {
    pulsingGlow(const Color(0x8CFF8020), 200, 1300, const [
      ReactionFrame(s: 0.4, o: 0),
      ReactionFrame(s: 1.1, o: 1, at: 0.15),
      ReactionFrame(s: 0.9, o: 0.8, at: 0.35),
      ReactionFrame(s: 1.05, o: 0.9, at: 0.55),
      ReactionFrame(s: 0.95, o: 0.6, at: 0.75),
      ReactionFrame(s: 1, o: 0),
    ]);
    embers(const [
      Color(0xFFFFE066),
      Color(0xFFFFB02E),
      Color(0xFFFF7A1F),
      Color(0xFFFF4D1F),
    ], 24);
    for (var i = 0; i < n(6); i++) {
      final x0 = r(-42, 42);
      glyph('🔥', r(14, 22), [
        ReactionFrame(x: x0, y: 20, s: 0.3, o: 0),
        ReactionFrame(x: x0 + r(-10, 10), y: -r(30, 60), s: 0.9, at: 0.4),
        ReactionFrame(x: x0 + r(-16, 16), y: -r(80, 130), s: 0.4, o: 0),
      ], r(1000, 1300), r(0, 260), _rise);
    }
  }

  List<ReactionParticle> build(String e) {
    switch (e) {
      case '❤️':
        hearts();
      case '🔥':
        fire();
      case '😁':
        glow(const Color(0x80FFCD3C), 180, 900);
        confetti(28);
        for (var i = 0; i < n(4); i++) {
          final a = r(0, 2 * pi), d = r(50, 80);
          glyph('✨', r(12, 18), [
            const ReactionFrame(s: 0, o: 0),
            ReactionFrame(
              x: math.cos(a) * d,
              y: math.sin(a) * d,
              s: 1,
              at: 0.4,
            ),
            ReactionFrame(
              x: math.cos(a) * d,
              y: math.sin(a) * d - 10,
              s: 0.4,
              o: 0,
            ),
          ], 900, r(60, 200), Curves.easeOut);
        }
      case '👍':
        ring(const Color(0xFF3390EC), 170, 3, 560);
        glow(const Color(0x7350A0FF), 160, 700);
        final c = n(12);
        for (var i = 0; i < c; i++) {
          ray(
            i / c * 360 + r(-6, 6),
            r(12, 20),
            3,
            i.isOdd ? Colors.white : const Color(0xFF8CC8FF),
            26,
            r(90, 110),
            520,
            40,
          );
        }
        spray(['⭐'], 6, 80, 120, 10, 14, spin: 1.5, spread: 140);
      case '👎':
        ring(const Color(0x59FFFFFF), 140, 2, 440);
        for (var i = 0; i < n(14); i++) {
          final dir = i.isOdd ? 1.0 : -1.0, x1 = dir * r(50, 120);
          dot(r(10, 22), const Color(0x8096A2B2), [
            ReactionFrame(x: dir * r(0, 16), y: 34, s: 0.4, o: 0.9),
            ReactionFrame(
              x: x1 * 0.7,
              y: 34 - r(0, 14),
              s: 1.2,
              o: 0.7,
              at: 0.45,
            ),
            ReactionFrame(x: x1, y: 34 - r(6, 22), s: 1.6, o: 0),
          ], r(600, 900), r(0, 60), _out);
        }
        glyph('💨', 22, const [
          ReactionFrame(x: -30, y: 30, sx: -0.5, sy: 0.5, o: 0),
          ReactionFrame(x: -70, y: 26, sx: -1, sy: 1, at: 0.4),
          ReactionFrame(x: -100, y: 22, sx: -1, sy: 1, o: 0),
        ], 700, 40, Curves.easeOut);
        glyph('💨', 22, const [
          ReactionFrame(x: 30, y: 30, s: 0.5, o: 0),
          ReactionFrame(x: 70, y: 26, s: 1, at: 0.4),
          ReactionFrame(x: 100, y: 22, s: 1, o: 0),
        ], 700, 40, Curves.easeOut);
      case '🥰':
        glow(const Color(0x73FF6EAA), 210, 1500);
        rise(['💕', '❤️', '💗', '💖'], 14);
      case '👏':
        for (var b = 0; b < 3; b++) {
          final delay = b * 200.0;
          glow(const Color(0x73FFDC64), 130, 280, delay);
          final c = n(8);
          for (var i = 0; i < c; i++) {
            final a = i < c / 2 ? r(-150, -110) : r(-70, -30);
            ray(
              a + 90,
              r(12, 16),
              2.5,
              i.isOdd ? const Color(0xFFFFE27A) : Colors.white,
              30,
              r(62, 74),
              360,
              delay,
            );
          }
        }
        confetti(16, 400);
      case '😂':
      case '🤣':
        glow(const Color(0x73FFCD3C), 170, 900);
        tears(18, false);
        if (e == '🤣') spray(['😂'], 4, 60, 100, 12, 16);
      case '😭':
        glow(const Color(0x5950AAFF), 170, 1400);
        tears(30, true);
      case '😢':
        glow(const Color(0x4D50AAFF), 150, 1400);
        for (var i = 0; i < n(8); i++) {
          final x0 = r(-16, 16);
          drop(r(6, 9), [
            ReactionFrame(x: x0, y: 8, s: 0.3, o: 0),
            ReactionFrame(x: x0, y: 20, s: 1, at: 0.2),
            ReactionFrame(x: x0 + r(-6, 6), y: r(80, 130), s: 0.9, o: 0),
          ], r(700, 900), i * 110.0, const Cubic(0.5, 0, 0.9, 0.6));
        }
      case '😮':
        ring(Colors.white, 120, 2, 500);
        ring(Colors.white, 170, 2, 600, 120);
        ring(const Color(0x99FFFFFF), 220, 2, 700, 240);
        sparks(const [Color(0xFFFFE066), Colors.white], 10, 50, 90);
      case '😱':
        glow(const Color(0x7378BEFF), 180, 900);
        rays(12, const [Color(0xFFBFE3FF), Colors.white], 34, 70, 2, 0, 10, 420);
        rays(
          12,
          const [Color(0xFFBFE3FF), Colors.white],
          34,
          70,
          2,
          220,
          10,
          420,
        );
        ring(const Color(0xFF9BD0FF), 150, 2, 500);
      case '🤯':
        flash(const Color(0x4DFFB450), 320);
        glow(const Color(0x99FF781E), 240, 900);
        puffs(const Color(0x8CAAAFB9), 16, s0: 14, s1: 28);
        sparks(
          const [Color(0xFFFFD43B), Color(0xFFFF922B), Color(0xFFFF6B6B)],
          22,
          70,
          150,
          3,
          7,
        );
        ring(Colors.white, 180, 3, 500);
        glyph('💥', 56, const [
          ReactionFrame(s: 0.2, o: 0),
          ReactionFrame(s: 1.2, at: 0.3),
          ReactionFrame(s: 1.5, o: 0),
        ], 600);
      case '😡':
      case '🤬':
        pulsingGlow(const Color(0x80FF3C28), 210, 1200, const [
          ReactionFrame(s: 0.4, o: 0),
          ReactionFrame(s: 1.1, o: 1, at: 0.2),
          ReactionFrame(s: 0.95, o: 0.7, at: 0.45),
          ReactionFrame(s: 1.08, o: 0.9, at: 0.65),
          ReactionFrame(s: 1, o: 0),
        ]);
        for (final sd in const [-1.0, 1.0]) {
          for (var i = 0; i < n(8); i++) {
            dot(r(10, 18), const Color(0xBFEBF0F5), [
              ReactionFrame(x: sd * 20, y: -34, s: 0.3, o: 0),
              ReactionFrame(
                x: sd * r(30, 50),
                y: -r(60, 90),
                s: 1.2,
                o: 0.8,
                at: 0.4,
              ),
              ReactionFrame(x: sd * r(45, 70), y: -r(100, 140), s: 1.8, o: 0),
            ], r(700, 1000), r(0, 500), Curves.easeOut);
          }
        }
        const pos = [(-44.0, -30.0), (46.0, -20.0), (30.0, -52.0)];
        for (var i = 0; i < pos.length; i++) {
          final (x, y) = pos[i];
          glyph('💢', r(16, 22), [
            ReactionFrame(x: x, y: y, s: 0, o: 0),
            ReactionFrame(
              x: x,
              y: y,
              s: 1.25,
              at: 0.25,
              curve: const Cubic(0.2, 1.4, 0.4, 1),
            ),
            ReactionFrame(x: x, y: y, s: 1, at: 0.7),
            ReactionFrame(x: x, y: y, s: 0.6, o: 0),
          ], 800, i * 160.0);
        }
        if (e == '🤬') {
          const sy = ['#', '@', '!', r'$', '%', '&', '!', '#'];
          for (var i = 0; i < n(10); i++) {
            final a = r(-pi * 0.95, -pi * 0.05), d = r(60, 110);
            glyph(
              sy[i % sy.length],
              r(14, 22),
              [
                const ReactionFrame(s: 0.2, o: 0),
                ReactionFrame(
                  x: math.cos(a) * d * 0.7,
                  y: math.sin(a) * d * 0.7,
                  s: 1,
                  r: r(-30, 30),
                  at: 0.35,
                ),
                ReactionFrame(
                  x: math.cos(a) * d,
                  y: math.sin(a) * d + 20,
                  s: 0.8,
                  o: 0,
                  r: r(-60, 60),
                ),
              ],
              r(800, 1100),
              r(0, 200),
              _out,
              i.isOdd ? const Color(0xFFFF6B6B) : Colors.white,
            );
          }
        }
      case '🎉':
      case '🎊':
      case '🥳':
        glow(const Color(0x73FFCD3C), 190, 900);
        confetti(40);
        confetti(8, 40, _def, 2.5, 3.5, 18, 28);
        if (e == '🥳') {
          rise(['🎈'], 2, xs: 60, h0: 160, h1: 200, s0: 20, s1: 26, spread: 200);
        }
      case '💯':
        ring(const Color(0xFFFF4D4D), 170, 3, 520);
        rays(14, const [Color(0xFFFF4D4D), Colors.white], 26, 100, 3, 40, 16);
        for (var i = 0; i < 3; i++) {
          final x = r(-70, 70), y = r(-70, -20);
          glyph('💯', r(16, 22), [
            ReactionFrame(x: x, y: y, s: 2.2, o: 0),
            ReactionFrame(
              x: x,
              y: y,
              s: 1,
              at: 0.25,
              curve: const Cubic(0.2, 1.4, 0.4, 1),
            ),
            ReactionFrame(x: x, y: y, s: 1, at: 0.75),
            ReactionFrame(x: x, y: y, s: 0.8, o: 0),
          ], 900, 150 + i * 140.0);
        }
      case '⚡':
        flash(const Color(0x66FFFAC8), 220);
        glow(const Color(0x8CFFE650), 200, 800);
        rays(8, const [Color(0xFFFFE066), Colors.white], 30, 110, 4, 0, 24, 420);
        spray(['⚡'], 6, 70, 120, 14, 20);
      case '🤩':
      case '✨':
        glow(const Color(0x80FFD250), 190, 1000);
        ring(const Color(0xFFFFD43B), 160, 3, 560);
        spray(['⭐', '✨', '🌟'], 14, 70, 130, 10, 20, spin: 2);
      case '😍':
        glow(const Color(0x73FF486C), 180, 900);
        spray(['❤️', '💖', '💕'], 16, 70, 130, 10, 20, lift: 20);
        sparks(const [Color(0xFFFF8FA8), Colors.white], 10, 40, 90);
      case '😘':
        glyph('💋', 24, const [
          ReactionFrame(s: 0.3, o: 0),
          ReactionFrame(x: 40, y: -20, s: 1.1, at: 0.3),
          ReactionFrame(x: 120, y: -80, s: 0.8, o: 0, r: 20),
        ], 900, 0, Curves.easeOut);
        for (var i = 0; i < n(10); i++) {
          glyph('❤️', r(10, 16), [
            const ReactionFrame(x: 10, s: 0.2, o: 0),
            ReactionFrame(x: r(40, 70), y: -r(10, 40), s: 1, at: 0.35),
            ReactionFrame(x: r(100, 150), y: -r(50, 110), s: 0.6, o: 0),
          ], r(800, 1100), r(60, 500), Curves.easeOut);
        }
      case '💔':
        glow(const Color(0x59FF3C5A), 160, 700);
        ring(const Color(0x4DFFFFFF), 120, 2, 400);
        for (var i = 0; i < n(14); i++) {
          final a = r(-pi * 0.9, -pi * 0.1), d = r(30, 70);
          rect(r(4, 8), r(6, 12), i % 3 == 0
              ? const Color(0xFFFF6B81)
              : const Color(0xFFE03152), [
            const ReactionFrame(s: 0.5, curve: _up),
            ReactionFrame(
              x: math.cos(a) * d,
              y: math.sin(a) * d,
              r: r(90, 200),
              at: 0.3,
              curve: _down,
            ),
            ReactionFrame(
              x: math.cos(a) * d * 1.4,
              y: math.sin(a) * d + r(120, 170),
              r: r(300, 600),
              o: 0,
            ),
          ], r(1000, 1300), r(0, 60), Curves.linear, 1);
        }
      case '❤️‍🔥':
        hearts();
        embers(const [
          Color(0xFFFFE066),
          Color(0xFFFFB02E),
          Color(0xFFFF7A1F),
          Color(0xFFFF4D1F),
        ], 14);
      case '🤔':
        glow(const Color(0x26FFFFFF), 150, 1200);
        for (var i = 0; i < 3; i++) {
          final x = r(-36, 36);
          glyph('❓', r(16, 22), [
            ReactionFrame(x: x, y: -20, s: 0.2, o: 0),
            ReactionFrame(
              x: x + r(-8, 8),
              y: -r(60, 80),
              s: 1,
              r: r(-15, 15),
              at: 0.35,
            ),
            ReactionFrame(x: x + r(-12, 12), y: -r(100, 130), s: 0.8, o: 0),
          ], 1200, i * 260.0, Curves.easeOut);
        }
        for (var i = 0; i < 3; i++) {
          final x = 40.0 + i * 12;
          dot(7, Colors.white, [
            ReactionFrame(x: x, y: -44, s: 0, o: 0),
            ReactionFrame(x: x, y: -44, s: 1, at: 0.25),
            ReactionFrame(x: x, y: -44, s: 1, at: 0.8),
            ReactionFrame(x: x, y: -44, s: 0, o: 0),
          ], 1000, i * 140.0, Curves.easeOut);
        }
      case '🙏':
      case '🫡':
      case '😇':
        glow(const Color(0x80FFDC78), 220, 1300);
        rays(
          16,
          const [Color(0xD9FFE696), Color(0xB3FFFFFF)],
          40,
          120,
          2,
          0,
          30,
          900,
        );
        spray(['✨'], 6, 60, 110, 10, 16);
        if (e == '😇') {
          add(
            ReactionParticle(
              shape: ReactionShape.ring,
              size: 90,
              border: 5,
              color: const Color(0xFFFFD43B),
              frames: const [
                ReactionFrame(y: -50, sx: 0.4, sy: 0.12, o: 0),
                ReactionFrame(y: -50, sx: 1, sy: 0.3, o: 1, at: 0.3),
                ReactionFrame(y: -56, sx: 1, sy: 0.3, o: 1, at: 0.75),
                ReactionFrame(y: -60, sx: 1.1, sy: 0.33, o: 0),
              ],
              duration: 1300,
              curve: Curves.easeOut,
            ),
          );
        }
      case '💩':
        for (var i = 0; i < n(6); i++) {
          final x0 = r(-26, 26);
          rect(3, r(14, 22), const Color(0xCC8CC850), [
            ReactionFrame(x: x0, y: -20, s: 0.5, o: 0),
            ReactionFrame(x: x0 + 6, y: -50, s: 1, at: 0.3),
            ReactionFrame(x: x0 - 6, y: -80, o: 0.8, at: 0.6),
            ReactionFrame(x: x0 + 6, y: -110, o: 0),
          ], 1200, r(0, 500), Curves.linear, 3);
        }
        for (var f = 0; f < n(3); f++) {
          final rr = r(40, 60), ph = r(0, 6.28);
          dot(4, const Color(0xFF1B1B1B), [
            for (var j = 0; j <= 10; j++)
              ReactionFrame(
                x: math.cos(ph + j / 10 * pi * 3) * rr,
                y: math.sin(ph + j / 10 * pi * 3) * rr * 0.6 - 20,
                o: j == 0 || j == 10 ? 0 : 1,
              ),
          ], 1500, f * 120.0);
        }
      case '🤮':
        for (var i = 0; i < n(16); i++) {
          final a = r(pi * 0.15, pi * 0.85), d = r(50, 110);
          drop(r(6, 10), [
            const ReactionFrame(y: 10, s: 0.3, o: 0),
            ReactionFrame(
              x: math.cos(a) * d * 0.6,
              y: math.sin(a) * d * 0.6 + 10,
              s: 1,
              at: 0.35,
            ),
            ReactionFrame(
              x: math.cos(a) * d,
              y: math.sin(a) * d + 40,
              s: 0.8,
              o: 0,
            ),
          ], r(600, 900), r(0, 200), const Cubic(0.3, 0.6, 0.6, 1), const [
            Color(0xFFB2F2BB),
            Color(0xFF40C057),
          ]);
        }
      case '🤡':
        confetti(26);
        rise(['🎈'], 3, xs: 60, h0: 160, h1: 210, s0: 18, s1: 24, spread: 300);
      case '👻':
        glow(const Color(0x59BEAAFF), 190, 1300);
        for (var i = 0; i < n(4); i++) {
          final sd = i.isOdd ? 1.0 : -1.0;
          glyph('👻', r(18, 28), [
            const ReactionFrame(s: 0.6, o: 0),
            ReactionFrame(
              x: sd * r(40, 90),
              y: -r(20, 70),
              s: 1,
              o: 0.55,
              at: 0.4,
            ),
            ReactionFrame(x: sd * r(80, 140), y: -r(40, 110), s: 1.1, o: 0),
          ], r(1100, 1500), i * 120.0, Curves.easeOut);
        }
      case '😴':
        glow(const Color(0x4D7896FF), 170, 1400);
        for (var i = 0; i < 3; i++) {
          glyph('💤', 16.0 + i * 4, [
            const ReactionFrame(x: 20, y: -20, s: 0.3, o: 0),
            ReactionFrame(
              x: 40.0 + i * 6,
              y: -60.0 - i * 10,
              s: 1,
              at: 0.35,
              r: -10,
            ),
            ReactionFrame(
              x: 60.0 + i * 10,
              y: -110.0 - i * 14,
              s: 1,
              o: 0,
              r: 10,
            ),
          ], 1400, i * 350.0, Curves.easeOut);
        }
      case '🥶':
        glow(const Color(0x808CD2FF), 200, 1300);
        ring(const Color(0xFFBDE6FF), 160, 2, 600);
        fall(['❄️'], 14);
      case '🥵':
        pulsingGlow(const Color(0x80FF5A28), 220, 1300, const [
          ReactionFrame(s: 0.4, o: 0),
          ReactionFrame(s: 1.1, o: 1, at: 0.2),
          ReactionFrame(s: 0.95, o: 0.7, at: 0.5),
          ReactionFrame(s: 1.05, o: 0.8, at: 0.75),
          ReactionFrame(s: 1, o: 0),
        ]);
        for (var i = 0; i < n(8); i++) {
          final x0 = r(-40, 40);
          rect(3, r(16, 24), const Color(0xB3FF8C3C), [
            ReactionFrame(x: x0, y: -10, s: 0.5, o: 0),
            ReactionFrame(x: x0 + 6, y: -40, s: 1, at: 0.3),
            ReactionFrame(x: x0 - 6, y: -70, o: 0.7, at: 0.65),
            ReactionFrame(x: x0 + 6, y: -100, o: 0),
          ], 1100, r(0, 400), Curves.linear, 3);
        }
        spray(['💦'], 6, 50, 100, 12, 18);
      case '💪':
        rays(12, const [Colors.white, Color(0xFFFFD43B)], 28, 110, 4, 0, 20);
        ring(const Color(0xFFFFD43B), 170, 3, 500);
        glyph('💥', 36, const [
          ReactionFrame(x: 44, y: -24, s: 0.2, o: 0),
          ReactionFrame(x: 44, y: -24, s: 1.2, at: 0.3),
          ReactionFrame(x: 50, y: -30, s: 1.4, o: 0),
        ], 520, 60);
      case '🤝':
        glow(const Color(0x59FFD278), 180, 1000);
        ring(const Color(0xFF69DB7C), 150, 3, 560);
        ring(Colors.white, 190, 2, 700, 120);
        spray(['✨'], 6, 60, 100, 12, 16);
      case '👀':
        ring(const Color(0x66FFFFFF), 140, 2, 500);
        for (var i = 0; i < n(5); i++) {
          final a = r(0, 2 * pi), d = r(55, 85);
          final x = math.cos(a) * d, y = math.sin(a) * d;
          glyph('✨', r(10, 16), [
            ReactionFrame(x: x, y: y, s: 0, o: 0),
            ReactionFrame(x: x, y: y, s: 1, at: 0.4),
            ReactionFrame(x: x, y: y, s: 0, o: 0),
          ], 700, r(0, 700), Curves.easeInOut);
        }
      case '😈':
        glow(const Color(0x809650FF), 210, 1200);
        embers(const [
          Color(0xFFB197FC),
          Color(0xFFFF6B6B),
          Color(0xFF845EF7),
        ], 18);
        spray(['🔥'], 4, 50, 90, 12, 16, lift: 30);
      case '😎':
        glow(const Color(0x4D8CC8FF), 170, 800);
        add(
          ReactionParticle(
            shape: ReactionShape.rect,
            width: 170,
            height: 4,
            colors: const [Color(0x00FFFFFF), Colors.white, Color(0x00FFFFFF)],
            radius: 2,
            frames: const [
              ReactionFrame(x: -80, y: -10, r: -20, o: 0),
              ReactionFrame(x: 0, y: -10, r: -20, o: 1, at: 0.5),
              ReactionFrame(x: 80, y: -10, r: -20, o: 0),
            ],
            duration: 600,
            delay: 100,
            curve: Curves.easeInOut,
          ),
        );
        glyph('✨', 20, const [
          ReactionFrame(x: 24, y: -18, s: 0, o: 0),
          ReactionFrame(x: 24, y: -18, s: 1.2, at: 0.4),
          ReactionFrame(x: 24, y: -18, s: 0, o: 0),
        ], 600, 380, Curves.easeInOut);
      case '🌚':
        glow(const Color(0x735064B4), 200, 1300);
        for (var i = 0; i < n(8); i++) {
          final a = i / 8 * 2 * pi, d = r(60, 90);
          final x = math.cos(a) * d, y = math.sin(a) * d;
          glyph(i.isOdd ? '⭐' : '✨', r(10, 16), [
            ReactionFrame(x: x, y: y, s: 0, o: 0),
            ReactionFrame(x: x, y: y, s: 1, r: r(-30, 30), at: 0.4),
            ReactionFrame(x: x, y: y, s: 0, o: 0),
          ], r(700, 900), r(0, 600), Curves.easeInOut);
        }
      case '🌈':
      case '🦄':
        const cols = [
          Color(0xFFFF6B6B),
          Color(0xFFFFA94D),
          Color(0xFFFFE066),
          Color(0xFF69DB7C),
          Color(0xFF4DABF7),
          Color(0xFF9775FA),
        ];
        for (var j = 0; j < 6; j++) {
          final rr = 48.0 + j * 9;
          for (var i = 0; i < 10; i++) {
            final a = pi + pi * i / 9;
            dot(6, cols[j], [
              ReactionFrame(
                x: math.cos(a) * rr * 0.3,
                y: math.sin(a) * rr * 0.3,
                s: 0.3,
                o: 0,
              ),
              ReactionFrame(
                x: math.cos(a) * rr,
                y: math.sin(a) * rr,
                s: 1,
                at: 0.3,
              ),
              ReactionFrame(
                x: math.cos(a) * rr,
                y: math.sin(a) * rr - 6,
                s: 0.6,
                o: 0,
              ),
            ], 1000, i * 40.0 + j * 20, Curves.easeOut);
          }
        }
        if (e == '🦄') spray(['✨'], 8, 70, 120, 10, 16);
      case '🍓':
        glow(const Color(0x59FF5A6E), 170, 900);
        for (var i = 0; i < n(8); i++) {
          final a = r(-pi * 0.9, -pi * 0.1), d = r(50, 100);
          glyph('🍓', r(12, 18), [
            const ReactionFrame(s: 0.3, o: 0, curve: _up),
            ReactionFrame(
              x: math.cos(a) * d,
              y: math.sin(a) * d,
              s: 1,
              r: r(-40, 40),
              at: 0.35,
              curve: _down,
            ),
            ReactionFrame(
              x: math.cos(a) * d * 1.3,
              y: math.sin(a) * d + r(110, 160),
              s: 0.9,
              o: 0,
              r: r(-120, 120),
            ),
          ], r(1100, 1400));
        }
      case '☕':
        glow(const Color(0x66C88C5A), 170, 1400);
        for (var i = 0; i < n(5); i++) {
          final x0 = r(-14, 14);
          rect(5, r(20, 30), const Color(0x8CFFFFFF), [
            ReactionFrame(x: x0, y: -30, s: 0.6, o: 0),
            ReactionFrame(x: x0 + 8, y: -60, s: 1, at: 0.3, o: 0.8),
            ReactionFrame(x: x0 - 8, y: -95, at: 0.65, o: 0.6),
            ReactionFrame(x: x0 + 6, y: -130, s: 1.2, o: 0),
          ], 1500, i * 180.0, Curves.linear, 4);
        }
      case '🍾':
        glow(const Color(0x73FFD250), 200, 1100);
        for (var i = 0; i < n(26); i++) {
          final vx = r(-60, 60), up = r(110, 180);
          dot(r(3, 6), _gold[i % 5], [
            const ReactionFrame(y: -30, s: 0.5, o: 0, curve: _up),
            ReactionFrame(x: vx * 0.6, y: -up, s: 1, at: 0.4, curve: _down),
            ReactionFrame(x: vx, y: -up + r(120, 170), s: 0.7, o: 0),
          ], r(1100, 1500), r(0, 350), Curves.linear, true);
        }
        confetti(14, 200, _gold);
      case '🚀':
        for (var i = 0; i < n(14); i++) {
          dot(r(12, 24), const Color(0x8CC8CDD7), [
            ReactionFrame(x: r(-6, 6) - 10, y: 30, s: 0.3, o: 0.9),
            ReactionFrame(
              x: r(-30, 30) - 16,
              y: r(70, 110),
              s: 1.3,
              o: 0.6,
              at: 0.5,
            ),
            ReactionFrame(x: r(-50, 50) - 20, y: r(110, 150), s: 1.8, o: 0),
          ], r(700, 1000), i * 35.0, Curves.easeOut);
        }
        for (var i = 0; i < n(10); i++) {
          dot(r(3, 6), i.isOdd ? const Color(0xFFFFB02E) : const Color(0xFFFF7A1F), [
            const ReactionFrame(x: -8, y: 26, s: 0.6, o: 0),
            ReactionFrame(x: r(-20, 10), y: r(50, 80), s: 1, at: 0.3),
            ReactionFrame(x: r(-30, 14), y: r(90, 120), s: 0.3, o: 0),
          ], r(500, 800), r(0, 400), Curves.easeOut, true);
        }
        spray(['✨'], 4, 70, 110, 12, 16);
      case '🏆':
      case '👑':
        glow(const Color(0x80FFD250), 220, 1000);
        ring(const Color(0xFFFFD43B), 180, 3, 560);
        rays(12, const [Color(0xFFFFE066), Colors.white], 30, 100, 3, 40, 14);
        confetti(24, 100, [..._gold, Colors.white]);
      case '💸':
        for (var i = 0; i < n(10); i++) {
          final a = r(-pi * 0.9, -pi * 0.1), d = r(50, 100);
          final bx = math.cos(a) * d, by = math.sin(a) * d;
          glyph('💵', r(16, 22), [
            const ReactionFrame(s: 0.3, o: 0),
            ReactionFrame(x: bx, y: by, s: 1, r: r(-30, 30), at: 0.3),
            ReactionFrame(
              x: bx + r(-20, 20),
              y: by + 60,
              r: r(-40, 40),
              at: 0.6,
            ),
            ReactionFrame(
              x: bx + r(-30, 30),
              y: by + r(140, 180),
              r: r(-60, 60),
              o: 0,
            ),
          ], r(1400, 1800), r(0, 200), Curves.easeOut);
        }
      case '🙈':
        glow(const Color(0x66FF8CAA), 190, 1100);
        glyph('🙉', 22, const [
          ReactionFrame(s: 0.2, o: 0),
          ReactionFrame(x: -70, y: -20, s: 1, r: -15, at: 0.35),
          ReactionFrame(x: -80, y: -30, s: 0.8, o: 0),
        ], 1000, 80, Curves.easeOut);
        glyph('🙊', 22, const [
          ReactionFrame(s: 0.2, o: 0),
          ReactionFrame(x: 70, y: -20, s: 1, r: 15, at: 0.35),
          ReactionFrame(x: 80, y: -30, s: 0.8, o: 0),
        ], 1000, 160, Curves.easeOut);
        spray(['✨'], 5, 50, 90, 10, 14);
      default:
        // Любой другой эмодзи — его мини-копии разлетаются вокруг.
        glow(const Color(0x4DFFFFFF), 170, 800);
        ring(const Color(0xFF3390EC), 160, 3, 560);
        spray([e], 12, 70, 130, 12, 20);
    }
    return out;
  }
}

/// 47 эмодзи раскрытой панели (по макету), по порядку.
const List<String> kReactionMoreEmoji = [
  '😂', '🤣', '😭', '😢', '😮', '😱', '🤯', '😡', '🤬', '🎉', '🎊', '🥳', //
  '💯', '⚡', '🤩', '✨', '😍', '😘', '💔', '❤️‍🔥', '🤔', '🙏', '🫡', '💩', //
  '🤮', '🤡', '👻', '😴', '🥶', '🥵', '💪', '🤝', '👀', '😇', '😈', '😎', //
  '🌚', '🌈', '🦄', '🍓', '☕', '🍾', '🚀', '🏆', '👑', '💸', '🙈', //
];
