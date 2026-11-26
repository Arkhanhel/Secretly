// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Анимированные галочки по макету «Verified Badges» (21.11.2026).
///
/// Знак «важного пользователя» — именно **H2 «Хамелеон-перламутр»** (решение
/// владельца): розетка из 12 лучей, цвет непрерывно течёт по спектру
/// (градиент из трёх точек, каждая обходит круг оттенков OKLCH за 7 с,
/// сам градиент поворачивается за 5,25 с), тонкое перламутровое кольцо,
/// блик проходит по розетке раз в 2 с, галочка раз в 4 с перетекает в «S»
/// и обратно, на каждой смене — лёгкий «щелчок» масштаба.
///
/// Остальные варианты макета (H1, H3, B1, B5, A1, A2) — тут же, на будущее;
/// сейчас нигде не показываются.
///
/// Вся картинка — один [CustomPainter] на одном тикере; при «уменьшении
/// движения» и вне экрана ([TickerMode]) — неподвижный первый кадр.
library;

import 'dart:math' as math;

import '../motion/decoration_pacer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../thermal_guard.dart';

enum VerifiedBadgeStyle {
  /// Хамелеон-морф: цвет течёт + галочка ⇄ S.
  h1,

  /// Хамелеон-перламутр: + кольцо и блик. Знак «важного пользователя».
  h2,

  /// Хамелеон-неон: тёмная плашка, светящийся контур.
  h3,

  /// Морф: синяя розетка, галочка ⇄ S, отскок.
  b1,

  /// Золотая печать: тёмная, волна на каждой смене.
  b5,

  /// Пульс: волна и прорисовка галочки.
  a1,

  /// Золотой блик.
  a2,
}

/// Строка с сервера (`elite_badge`) → вид. Неизвестное — `null` (не рисуем).
VerifiedBadgeStyle? verifiedBadgeStyleFromSlug(String? slug) {
  final s = slug?.trim().toLowerCase() ?? '';
  for (final v in VerifiedBadgeStyle.values) {
    if (v.name == s) return v;
  }
  return null;
}

class VerifiedBadge extends StatefulWidget {
  const VerifiedBadge({
    super.key,
    this.style = VerifiedBadgeStyle.h2,
    this.size = 18,
    this.animate = true,
    this.semanticLabel,
  });

  final VerifiedBadgeStyle style;
  final double size;
  final bool animate;
  final String? semanticLabel;

  @override
  State<VerifiedBadge> createState() => _VerifiedBadgeState();
}

class _VerifiedBadgeState extends State<VerifiedBadge>
    with PacedTickerProviderStateMixin {
  @override
  bool get restsWhenIdle => true;

  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);

  Duration _lastPaint = Duration.zero;

  /// 🔴 22.11.2026 (разбор): знак рисовался каждый кадр (60–120 раз в
  /// секунду), пока виден. Его волна медленная — 30 кадров хватает; при
  /// перегреве и в спрятанных слоях (TickerMode) знак стоит.
  void _onTick(Duration elapsed) {
    if (elapsed - _lastPaint < const Duration(microseconds: 33000)) return;
    _lastPaint = elapsed;
    _seconds.value = elapsed.inMicroseconds / 1e6;
  }

  bool get _shouldRun {
    if (!widget.animate) return false;
    if (!ThermalGuard.effectsAllowed.value) return false;
    final mq = MediaQuery.maybeOf(context);
    return !(mq?.disableAnimations ?? false);
  }

  @override
  void initState() {
    super.initState();
    ThermalGuard.effectsAllowed.addListener(_onThermal);
  }

  void _onThermal() {
    if (mounted) _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(VerifiedBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_shouldRun) {
      if (!_ticker.isActive) _ticker.start();
    } else if (_ticker.isActive) {
      _ticker.stop();
      _lastPaint = Duration.zero;
      _seconds.value = 0;
    }
  }

  @override
  void dispose() {
    ThermalGuard.effectsAllowed.removeListener(_onThermal);
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.semanticLabel;
    final paint = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: VerifiedBadgePainter(style: widget.style, seconds: _seconds),
      ),
    );
    if (label == null) return ExcludeSemantics(child: paint);
    return Semantics(label: label, image: true, child: paint);
  }
}

// ── цвет ──────────────────────────────────────────────────────────────────

/// OKLCH → sRGB (как `oklch()` в CSS), с обрезкой по гамме.
Color oklch(double l, double c, double hDeg, [double opacity = 1]) {
  final h = hDeg * math.pi / 180;
  final a = c * math.cos(h);
  final b = c * math.sin(h);
  final l1 = l + 0.3963377774 * a + 0.2158037573 * b;
  final m1 = l - 0.1055613458 * a - 0.0638541728 * b;
  final s1 = l - 0.0894841775 * a - 1.2914855480 * b;
  final l3 = l1 * l1 * l1, m3 = m1 * m1 * m1, s3 = s1 * s1 * s1;
  final r = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3;
  final g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
  final bl = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3;
  double enc(double x) {
    final v = x <= 0.0031308
        ? 12.92 * x
        : 1.055 * math.pow(x, 1 / 2.4).toDouble() - 0.055;
    return v.clamp(0.0, 1.0);
  }

  return Color.from(
    alpha: opacity.clamp(0.0, 1.0),
    red: enc(r),
    green: enc(g),
    blue: enc(bl),
  );
}

final Color _blue = oklch(0.62, 0.19, 255);

// ── геометрия (viewBox 24×24, как в макете) ───────────────────────────────

Path _rosette(int k, double ro, double ri) {
  final p = Path();
  for (var i = 0; i < 2 * k; i++) {
    final r = i.isOdd ? ri : ro;
    final t = -math.pi / 2 + i * math.pi / k;
    final x = 12 + r * math.cos(t), y = 12 + r * math.sin(t);
    i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
  }
  return p..close();
}

/// Галочка макета как 6 кубических отрезков (7 опорных точек на прямых).
const List<Offset> _checkPts = [
  Offset(8.1, 12.3),
  Offset(9.45, 13.65),
  Offset(10.8, 15),
  Offset(12.075, 13.625),
  Offset(13.35, 12.25),
  Offset(14.625, 10.875),
  Offset(15.9, 9.5),
];

List<Offset> _checkCubic() {
  final out = <Offset>[_checkPts.first];
  for (var i = 1; i < _checkPts.length; i++) {
    final a = _checkPts[i - 1], b = _checkPts[i];
    out
      ..add(Offset.lerp(a, b, 1 / 3)!)
      ..add(Offset.lerp(a, b, 2 / 3)!)
      ..add(b);
  }
  return out;
}

final List<Offset> _mc = _checkCubic();

/// Буква «S» макета — те же 6 отрезков.
const List<Offset> _ms = [
  Offset(8.7, 15.3),
  Offset(9.3, 16.4), Offset(10.5, 17), Offset(12, 17),
  Offset(13.8, 17), Offset(15.2, 16.1), Offset(15.2, 14.6),
  Offset(15.2, 13), Offset(13.7, 12.5), Offset(12, 12.1),
  Offset(10.4, 11.7), Offset(8.9, 11.2), Offset(8.9, 9.5),
  Offset(8.9, 8), Offset(10.2, 7), Offset(12, 7),
  Offset(13.4, 7), Offset(14.6, 7.5), Offset(15.3, 8.7),
];

Path _morphPath(double k) {
  final pts = [
    for (var i = 0; i < _mc.length; i++) Offset.lerp(_mc[i], _ms[i], k)!,
  ];
  final p = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (var i = 1; i + 2 < pts.length; i += 3) {
    p.cubicTo(
      pts[i].dx,
      pts[i].dy,
      pts[i + 1].dx,
      pts[i + 1].dy,
      pts[i + 2].dx,
      pts[i + 2].dy,
    );
  }
  return p;
}

const Cubic _morphEase = Cubic(0.75, 0, 0.25, 1);

/// Доля «S» в цикле 4 с: держим галочку 0–40 %, перетекаем до 50 %,
/// держим «S» до 90 %, обратно к 100 %.
double morphAt(double seconds) {
  final f = (seconds / 4) % 1;
  if (f < 0.4) return 0;
  if (f < 0.5) return _morphEase.transform((f - 0.4) / 0.1);
  if (f < 0.9) return 1;
  return 1 - _morphEase.transform((f - 0.9) / 0.1);
}

/// «Щелчок» масштаба (vbPop, 2 с): 1 до 78 %, 1,12 на 90 %, обратно.
double popAt(double seconds) {
  final f = (seconds / 2) % 1;
  if (f < 0.78) return 1;
  final t = f < 0.9 ? (f - 0.78) / 0.12 : 1 - (f - 0.9) / 0.1;
  return 1 + 0.12 * Curves.easeInOut.transform(t.clamp(0.0, 1.0));
}

/// Блик (vbSweep2, 2 с): стоит слева до 74 %, проходит к 100 %.
double sweepAt(double seconds) {
  final f = (seconds / 2) % 1;
  if (f < 0.74) return -14;
  return -14 + 40 * Curves.easeInOut.transform((f - 0.74) / 0.26);
}

class VerifiedBadgePainter extends CustomPainter {
  VerifiedBadgePainter({required this.style, required this.seconds})
    : super(repaint: seconds);

  final VerifiedBadgeStyle style;
  final ValueListenable<double> seconds;

  static final Path _r12 = _rosette(12, 10.6, 9.0);
  static final Path _r12clip = _rosette(12, 11.2, 9.4);
  static final Path _r10 = _rosette(10, 10.6, 8.9);
  static final Path _r24 = _rosette(24, 11.2, 10.1);

  /// Хамелеон: три точки градиента, у каждой свой круг оттенков.
  Shader _chameleon(double s, double period) {
    final turn = (s / period) % 1;
    final colors = [
      for (var i = 0; i < 3; i++)
        oklch(i == 1 ? 0.76 : 0.66, 0.19, (i * 70 + turn * 360) % 360),
    ];
    final angle = 2 * math.pi * ((s / (period * 0.75)) % 1);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
      transform: GradientRotation(angle),
    ).createShader(const Rect.fromLTWH(0, 0, 24, 24));
  }

  void _shape(Canvas canvas, Path path, Paint fill, {double stroke = 1.6}) {
    canvas.drawPath(path, fill..style = PaintingStyle.fill);
    canvas.drawPath(
      path,
      Paint()
        ..shader = fill.shader
        ..color = fill.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _mark(Canvas canvas, double s, Color color, {double? width}) {
    final k = morphAt(s);
    canvas.drawPath(
      _morphPath(k),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width ?? (2.3 - 0.35 * k)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _shine(Canvas canvas, Path clip, double s, double width, double op) {
    canvas.save();
    canvas.clipPath(clip);
    canvas.translate(12, 12);
    canvas.rotate(22 * math.pi / 180);
    canvas.translate(-12, -12);
    canvas.drawRect(
      Rect.fromLTWH(sweepAt(s), -6, width, 36),
      Paint()..color = Colors.white.withValues(alpha: op),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = seconds.value;
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    void popped(VoidCallback body) {
      final k = popAt(s);
      canvas.save();
      canvas.translate(12, 12);
      canvas.scale(k);
      canvas.translate(-12, -12);
      body();
      canvas.restore();
    }

    switch (style) {
      case VerifiedBadgeStyle.h2:
        popped(() {
          _shape(canvas, _r12, Paint()..shader = _chameleon(s, 7));
          canvas.drawCircle(
            const Offset(12, 12),
            7.6,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.6
              ..color = Colors.white.withValues(alpha: 0.4),
          );
          _shine(canvas, _r12clip, s, 4, 0.6);
          _mark(canvas, s, Colors.white);
        });
      case VerifiedBadgeStyle.h1:
        popped(() {
          _shape(canvas, _r10, Paint()..shader = _chameleon(s, 6));
          _mark(canvas, s, Colors.white);
        });
      case VerifiedBadgeStyle.h3:
        final shader = _chameleon(s, 5);
        final plate = RRect.fromRectAndRadius(
          const Rect.fromLTWH(2, 2, 20, 20),
          const Radius.circular(6.5),
        );
        canvas.drawRRect(plate, Paint()..color = const Color(0xFF101016));
        canvas.drawRRect(
          plate.deflate(0.6),
          Paint()
            ..shader = shader
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7
            ..color = Colors.white.withValues(alpha: 0.6),
        );
        final k = morphAt(s);
        final glow = Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.3 - 0.35 * k
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(
          _morphPath(k),
          Paint()
            ..shader = shader
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.3 - 0.35 * k
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
        );
        canvas.drawPath(_morphPath(k), glow);
      case VerifiedBadgeStyle.b1:
        popped(() {
          _shape(canvas, _r10, Paint()..color = _blue);
          _mark(canvas, s, Colors.white);
        });
      case VerifiedBadgeStyle.b5:
        final gold = oklch(0.8, 0.14, 82);
        final f = ((s - 1.8) / 2) % 1;
        if (s >= 1.8 && f < 0.5) {
          final t = f / 0.5;
          canvas.drawCircle(
            const Offset(12, 12),
            10.5 + 4 * t,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = gold.withValues(alpha: 0.9 * (1 - t)),
          );
        }
        _shape(
          canvas,
          _r24,
          Paint()..color = const Color(0xFF1D1D22),
          stroke: 0.8,
        );
        canvas.drawCircle(
          const Offset(12, 12),
          8.3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = gold,
        );
        _mark(canvas, s, oklch(0.82, 0.14, 82));
      case VerifiedBadgeStyle.a1:
        final f = (s / 2) % 1;
        canvas.drawCircle(
          const Offset(12, 12),
          9.5 * (0.85 + 0.6 * Curves.easeOut.transform(f)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = _blue.withValues(alpha: 0.9 * (1 - f)),
        );
        _shape(canvas, _r10, Paint()..color = _blue);
        // Прорисовка галочки: 12–42 % цикла.
        final draw = f < 0.12
            ? 0.0
            : f < 0.42
            ? Curves.easeInOut.transform((f - 0.12) / 0.3)
            : 1.0;
        final check = _morphPath(0);
        final metric = check.computeMetrics().first;
        canvas.drawPath(
          metric.extractPath(0, metric.length * (s == 0 ? 1 : draw)),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.3
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      case VerifiedBadgeStyle.a2:
        _shape(
          canvas,
          _r12,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                oklch(0.9, 0.13, 92),
                oklch(0.78, 0.16, 75),
                oklch(0.66, 0.15, 60),
              ],
            ).createShader(const Rect.fromLTWH(0, 0, 24, 24)),
        );
        final f = (s / 2.8) % 1;
        final x = f < 0.35
            ? -14.0
            : f < 0.75
            ? -14 + 40 * Curves.easeInOut.transform((f - 0.35) / 0.4)
            : 26.0;
        canvas.save();
        canvas.clipPath(_r12clip);
        canvas.translate(12, 12);
        canvas.rotate(22 * math.pi / 180);
        canvas.translate(-12, -12);
        canvas.drawRect(
          Rect.fromLTWH(x, -6, 4.5, 36),
          Paint()..color = Colors.white.withValues(alpha: 0.7),
        );
        canvas.restore();
        _mark(canvas, 0, oklch(0.35, 0.08, 60), width: 2.3);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(VerifiedBadgePainter old) =>
      old.style != style || old.seconds != seconds;
}
