// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../profile_fx.dart';

math.Random _rng = math.Random();

/// Тесты (25.09.2026): закрепить случайность эффектов рамок, чтобы проверки
/// рисования давали один и тот же кадр. Без зерна рыбки «аквариума» и прочие
/// частицы вставали каждый раз по-новому, и проверка «рамка не закрывает лицо»
/// то проходила, то падала. В приложении не вызывается — поведение прежнее.
@visibleForTesting
void debugSeedProfileFxRandom(int seed) => _rng = math.Random(seed);
double _rnd() => _rng.nextDouble();
const double _tau = math.pi * 2;
const double _deg = math.pi / 180;

double _clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
double _lerp(double a, double b, double u) => a + (b - a) * u;
double _pow(double x, double e) => math.pow(x, e).toDouble();
double _hash(num a, [num b = 0, num c = 0]) {
  final x = math.sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453;
  return x - x.floorToDouble();
}

double _backOut(double u) {
  final q = u - 1;
  return 1 + 2.7 * q * q * q + 1.7 * q * q;
}

/// Недодемпфированная пружина: цель → перелёт → затухание.
/// Основа «живого» движения во всех рамках.
class Spring {
  Spring([double initial = 0])
      : x = initial,
        t = initial;
  double x, t, v = 0;
  void step(double dt, [double k = 180, double c = 11]) {
    final a = -k * (x - t) - c * v;
    v += a * dt;
    x += v * dt;
  }
}

/// Точка на окружности: угол 0 — вверх, по часовой стрелке.
Offset _pt(double cx, double cy, double r, double a) =>
    Offset(cx + r * math.sin(a), cy - r * math.cos(a));

Path _smoothClosed(List<Offset> p) {
  final n = p.length;
  final path = Path()..moveTo(p[0].dx, p[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = p[(i - 1 + n) % n], p1 = p[i], p2 = p[(i + 1) % n], p3 = p[(i + 2) % n];
    path.cubicTo(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6, p2.dx, p2.dy);
  }
  return path..close();
}

/// Замкнутая гладкая «капля» вокруг центра с радиусом r + f(угол).
Path _blob(double cx, double cy, double r, double Function(double a) f, [int n = 36]) =>
    _smoothClosed(List<Offset>.generate(n, (i) {
      final a = i / n * _tau;
      return _pt(cx, cy, r + f(a), a);
    }));

Path _smoothOpen(List<Offset> p) {
  final path = Path()..moveTo(p[0].dx, p[0].dy);
  for (var j = 1; j < p.length - 1; j++) {
    final m = (p[j] + p[j + 1]) / 2;
    path.quadraticBezierTo(p[j].dx, p[j].dy, m.dx, m.dy);
  }
  return path..lineTo(p.last.dx, p.last.dy);
}

Paint _fill(Color c) => Paint()..color = c;
Paint _stroke(Color c, double w, [StrokeCap cap = StrokeCap.round]) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = StrokeJoin.round;

/// Непрозрачный цвет → цвет с заданной прозрачностью.
Color _op(Color c, double o) => c.withAlpha((255 * _clamp(o, 0, 1)).round());

List<double> _even(int n) => List<double>.generate(n, (i) => n == 1 ? 0.0 : i / (n - 1));
ui.Gradient _linG(Offset a, Offset b, List<Color> c, [List<double>? s]) =>
    ui.Gradient.linear(a, b, c, s ?? _even(c.length));

void _vFill(Canvas c, Size s, Color top, Color bottom) => c.drawRect(
    Offset.zero & s, Paint()..shader = _linG(Offset.zero, Offset(0, s.height), [top, bottom]));

/// Мягкое круглое свечение (аналог радиального спрайта).
void _glow(Canvas c, Offset o, double r, Color col, double op, [BlendMode mode = BlendMode.srcOver]) {
  if (op <= 0.003 || r <= 0.5) return;
  c.drawCircle(
      o,
      r,
      Paint()
        ..blendMode = mode
        ..shader = ui.Gradient.radial(
            o, r, [_op(col, op), _op(col, op * 0.55), _op(col, 0)], const [0.0, 0.35, 1.0]));
}

RRect _rr(double x, double y, double w, double h, double r) =>
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

Rect _ov(double cx, double cy, double rx, double ry) =>
    Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);

final Map<String, TextPainter> _tpCache = {};

/// Текст по центру точки. Кэшируется — безопасно вызывать каждый кадр.
void _text(Canvas c, String s, Offset center, double size, Color color,
    [FontWeight w = FontWeight.w700, double alpha = 1, double spacing = 0]) {
  if (alpha <= 0.01) return;
  final key = '$s|$size|${color.hashCode}|${w.value}|$spacing';
  var tp = _tpCache[key];
  if (tp == null) {
    if (_tpCache.length > 256) _tpCache.clear();
    tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, fontWeight: w, color: color, letterSpacing: spacing, height: 1.0)),
      textDirection: TextDirection.ltr,
    )..layout();
    _tpCache[key] = tp;
  }
  final o = center - Offset(tp.width / 2, tp.height / 2);
  if (alpha >= 0.99) {
    tp.paint(c, o);
  } else {
    c.saveLayer(o & tp.size, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    tp.paint(c, o);
    c.restore();
  }
}

Path _heart([double s = 1]) => Path()
  ..moveTo(0, 6 * s)
  ..cubicTo(0, 6 * s, -7 * s, 1.5 * s, -7 * s, -2.5 * s)
  ..cubicTo(-7 * s, -5.5 * s, -4.5 * s, -7 * s, -2.5 * s, -7 * s)
  ..cubicTo(-1 * s, -7 * s, 0, -6 * s, 0, -4.5 * s)
  ..cubicTo(0, -6 * s, 1 * s, -7 * s, 2.5 * s, -7 * s)
  ..cubicTo(4.5 * s, -7 * s, 7 * s, -5.5 * s, 7 * s, -2.5 * s)
  ..cubicTo(7 * s, 1.5 * s, 0, 6 * s, 0, 6 * s)
  ..close();

String _fmtInt(int v) {
  final s = v.toString(), b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('\u2009');
    b.write(s[i]);
  }
  return b.toString();
}
