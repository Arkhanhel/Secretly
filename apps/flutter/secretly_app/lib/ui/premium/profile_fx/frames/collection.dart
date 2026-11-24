// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../../profile_fx.dart';

// Эксклюзивная коллекция рамок (13.11.2026), дизайн-референс fx-premium-frames.js.
//
// Формулы, константы пружин, цвета и размеры перенесены из референса как есть.
// Отличия от JS, все намеренные:
// • `edge()` в Dart срабатывает на любое переключение — здесь `on()` = только
//   включение, как в референсе.
// • Сложение света (`'lighter'`) — только в тёмной теме; на светлом фоне сложение
//   с белым ничего не рисует, поэтому там обычное наложение.
// • Сплошные заливки кольца (ферро, желе, шестерня) вырезаны по кругу фото
//   (even-odd): у нас фото лежит ПОД накладкой, а в референсе его рисуют сверху.
// • Где референс красит цветом фона `#0C0D11` — цвет фона палитры.

/// id рамки коллекции → симуляция; null — не из этого набора.
FrameSim? createCollectionFrameSim(String id) => switch (id) {
      'dragon' => _QDragon(),
      'ferro' => _QFerro(),
      'jelly' => _QJelly(),
      'beads' => _QBeads(),
      'liquid' => _QLiquid(),
      'gears' => _QGears(),
      'flow' => _QFlow(),
      'flock' => _QFlock(),
      'pwave' => _QPWave(),
      'spiro' => _QSpiro(),
      _ => null,
    };

const Offset _qC = Offset(100, 100);
const Color _qWhite = Color(0xFFFFFFFF);

// Общие кисти: Canvas копирует их в момент вызова, так что одну можно менять
// от вызова к вызову без новых объектов в кадре.
final Paint _qF = Paint();
final Paint _qS = Paint()..style = PaintingStyle.stroke;

Paint _qFill(Color c, [BlendMode m = BlendMode.srcOver]) => _qF
  ..color = _day(c)
  ..shader = null
  ..blendMode = _fxDay && m == BlendMode.plus ? BlendMode.srcOver : m;

Paint _qLine(Color c, double w,
        [StrokeCap cap = StrokeCap.round, StrokeJoin join = StrokeJoin.round, BlendMode m = BlendMode.srcOver]) =>
    _qS
      ..color = _day(c)
      ..shader = null
      ..strokeWidth = w
      ..strokeCap = cap
      ..strokeJoin = join
      ..blendMode = _fxDay && m == BlendMode.plus ? BlendMode.srcOver : m;

double _qHyp(double x, double y) => math.sqrt(x * x + y * y);

void _qDisc(Canvas c, double x, double y, double r, Color col) => c.drawCircle(Offset(x, y), r, _qFill(col));

void _qSeg(Canvas c, double x0, double y0, double x1, double y1, Color col, double w) =>
    c.drawLine(Offset(x0, y0), Offset(x1, y1), _qLine(col, w));

/// `ring()` референса: дуга вокруг центра холста, углы холста (0 — вправо, по часовой).
void _qRing(Canvas c, double r, Paint p, [double a0 = 0, double a1 = _tau]) {
  if (a1 - a0 >= _tau) {
    c.drawCircle(_qC, r, p);
  } else {
    c.drawArc(Rect.fromCircle(center: _qC, radius: r), a0, a1 - a0, false, p);
  }
}

/// Путь [src] с вырезанным кругом фото — для сплошных заливок кольца.
Path _qHoled(Path src, double r) => Path.from(src)
  ..fillType = PathFillType.evenOdd
  ..addOval(Rect.fromCircle(center: _qC, radius: r));

abstract class _QFrame extends FrameSim {
  _QFrame([List<Color> cols = const []]) : super(100, 100, 58, 52, cols);

  /// `edge()` референса: true только в кадр включения [active].
  bool on() => edge() && active;

  /// `breathe()` референса — равномерный масштаб тела.
  void bre([double f = 1.6, double amp = 0.006]) {
    final b = 1 + math.sin(t * f) * amp;
    body(b, b);
  }
}

class _QSpark {
  _QSpark(this.x, this.y, this.vx, this.vy, this.life, this.f);
  double x, y, vx, vy, age = 0;
  final double life;
  final bool f;
}

// ───────────── Дракон ─────────────
// Тело-цепочка извивается по наклонной орбите, уходит за портрет; тап — рывок и огонь.
class _QDragon extends _QFrame {
  _QDragon() : super(const [Color(0xFFFFB23F), Color(0xFFFF5A3C), Color(0xFF7A1E12)]) {
    ringWidth = 4;
    _geom();
  }
  double th = _rnd() * _tau, tl = -20 * _deg, ha = 0;
  final Spring v = Spring(1.1);
  final List<_QSpark> sp = [];
  final Float64List xs = Float64List(26), ys = Float64List(26);
  final List<bool> fr = List<bool>.filled(26, false);
  final Path _wh = Path();
  static final Float64List _r =
      Float64List.fromList(List<double>.generate(26, (i) => 1.4 + 6 * math.pow(1 - i / 25, 0.7).toDouble()));

  Offset e(double th, [double k = 1]) {
    final x = 84 * k * math.cos(th), y = 30 * k * math.sin(th), c = math.cos(tl), s = math.sin(tl);
    return Offset(100 + x * c - y * s, 100 + x * s + y * c);
  }

  /// Сегменты `sg(i)` считаются раз за кадр, а не в каждом из двух слоёв.
  void _geom() {
    for (var i = 0; i < 26; i++) {
      final a = th - i * 0.082, p = e(a, 1 + math.sin(a * 5 - t * 4) * 0.035 * (0.4 + i / 26));
      xs[i] = p.dx;
      ys[i] = p.dy;
      fr[i] = math.sin(a) > 0;
    }
    final n = e(th + 0.04);
    ha = math.atan2(n.dy - ys[0], n.dx - xs[0]);
  }

  @override
  void update(double dt) {
    v.t = active ? 4.4 : 1.1;
    v.step(dt, 30, 7);
    th += v.x * dt;
    tl = (-20 + math.sin(t * 0.35) * 6) * _deg;
    if (active && _rnd() < dt * 70) {
      final h = e(th), n = e(th + 0.05), dx = n.dx - h.dx, dy = n.dy - h.dy, m0 = _qHyp(dx, dy);
      final m = m0 == 0 ? 1.0 : m0, s = 60 + _rnd() * 70;
      sp.add(_QSpark(h.dx + dx / m * 9, h.dy + dy / m * 9, dx / m * s + (_rnd() - 0.5) * 34,
          dy / m * s + (_rnd() - 0.5) * 34, 0.3 + _rnd() * 0.3, math.sin(th) > 0));
    }
    for (final q in sp) {
      q.age += dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
    }
    sp.removeWhere((q) => q.age >= q.life);
    bre();
    _geom();
  }

  void _layer(Canvas c, bool front, bool add) {
    for (var i = 25; i >= 1; i--) {
      if (fr[i] != front) continue;
      final r = _r[i], x = xs[i], y = ys[i];
      if (i % 3 == 0) {
        final dx = x - 100, dy = y - 100, m0 = _qHyp(dx, dy), m = m0 == 0 ? 1.0 : m0;
        _qSeg(c, x + dx / m * r * 0.6, y + dy / m * r * 0.6, x + dx / m * (r + 3.4), y + dy / m * (r + 3.4),
            const Color(0xFFFFD36B), 1.7);
      }
      _qDisc(c, x, y, r, i.isOdd ? const Color(0xFFE0352B) : const Color(0xFFF04A30));
      _qDisc(c, x, y + r * 0.28, r * 0.55, const Color.fromRGBO(255, 190, 90, 0.55));
    }
    for (final q in sp) {
      if (q.f != front) continue;
      final u = 1 - q.age / q.life;
      _glowS(c, Offset(q.x, q.y), 4 + (1 - u) * 7, u > 0.6 ? const Color(0xFFFFE9A8) : const Color(0xFFFF7A2A), u,
          add);
    }
    if (fr[0] != front) return;
    c.save();
    c.translate(xs[0], ys[0]);
    c.rotate(ha);
    for (final s in const [-1.0, 1.0]) {
      _wh
        ..reset()
        ..moveTo(7, s * 3)
        ..quadraticBezierTo(0, s * (9 + math.sin(t * 5) * 2), -10, s * (7 + math.sin(t * 4 + 1) * 3));
      c.drawPath(_wh, _qLine(const Color(0xFFFFD36B), 0.9));
      _qSeg(c, -2, s * 4, -9, s * 8.5, const Color(0xFFFFE9A8), 1.7);
    }
    c.drawOval(_ov(2, 0, 9, 6.2), _qFill(const Color(0xFFF04A30)));
    c.drawOval(_ov(8.5, 0, 5, 4), _qFill(const Color(0xFFE0352B)));
    for (final s in const [-1.0, 1.0]) {
      _qDisc(c, 4, s * 3.2, 1.8, const Color(0xFFFFF3C8));
      _qDisc(c, 4.6, s * 3.2, 0.85, const Color(0xFF1A0A06));
    }
    if (active) _glowS(c, const Offset(14, 0), 7, const Color(0xFFFFD27A), 0.9, add);
    c.restore();
  }

  @override
  void back(Canvas c, FramePalette p) {
    _glowS(c, _qC, 92, const Color(0xFFFF5A3C), 0.16, p.dark);
    _layer(c, false, p.dark);
  }

  @override
  void front(Canvas c, FramePalette p) => _layer(c, true, p.dark);
}

// ───────────── Феррофлюид ─────────────
// Шипы магнитной жидкости тянутся за «магнитом» — он идёт по кругу или следует за перетаскиванием.
class _QFerro extends _QFrame {
  _QFerro() : super();
  static const int n = 44;
  final List<Spring> s = List<Spring>.generate(n, (_) => Spring());
  double ma = _rnd() * _tau, pw = 0;
  final Spring kick = Spring();
  final Path _poly = Path();

  @override
  bool get drawRing => true;

  @override
  void update(double dt) {
    if (on()) kick.v += 10;
    kick.step(dt, 70, 5);
    final m = _qHyp(ivx, ivy);
    var tg = t * 0.7;
    if (m > 5) tg = math.atan2(-ivx, ivy);
    var d = tg - ma;
    d = math.atan2(math.sin(d), math.cos(d));
    ma += d * math.min(1, dt * (m > 5 ? 10 : 3));
    pw += ((m > 5 ? _clamp(m / 50, 0.6, 1.6) : 1) - pw) * math.min(1, dt * 6);
    final kx = math.max(0.0, kick.x) * 9;
    for (var i = 0; i < n; i++) {
      final a = i / n * _tau, cc = math.max(0.0, math.cos(a - ma));
      s[i].t = 3 + 19 * cc * cc * cc * pw + kx + 1.6 * math.sin(t * 3 + i * 1.7);
      s[i].step(dt, 170, 9);
    }
    bre();
  }

  @override
  void back(Canvas c, FramePalette p) {
    _glowS(c, _qC, 96, const Color(0xFF3A4AA8), 0.3, p.dark);
    _glowS(c, _pt(100, 100, 94, ma), 16, const Color(0xFF9FB4FF), 0.5 * pw, p.dark);
  }

  @override
  void paintRing(Canvas c, [List<Color>? colors, double opacity = 1]) {
    _poly.reset();
    for (var i = 0; i < n; i++) {
      final a = i / n * _tau, h = math.max(0.5, s[i].x), v = _pt(100, 100, 59, a - math.pi / n), tp = _pt(100, 100, 60 + h, a);
      i == 0 ? _poly.moveTo(v.dx, v.dy) : _poly.lineTo(v.dx, v.dy);
      _poly.lineTo(tp.dx, tp.dy);
    }
    _poly.close();
    c.drawPath(_qHoled(_poly, av), _qFill(const Color(0xFF06070C)));
    c.drawPath(_poly, _qLine(const Color.fromRGBO(120, 145, 255, 0.55), 0.8));
    for (var i = 0; i < n; i++) {
      final a = i / n * _tau, h = s[i].x;
      if (h < 5) continue;
      final b = _pt(100, 100, 60, a - math.pi / n * 0.45), tp = _pt(100, 100, 59 + h * 0.86, a - 0.012);
      c.drawLine(b, tp, _qLine(Color.fromRGBO(225, 232, 255, _clamp(h / 22, 0.15, 0.75)), 0.9));
    }
    _qRing(c, 57.5, _qLine(const Color.fromRGBO(160, 180, 255, 0.5), 0.8, StrokeCap.butt));
  }
}

// ───────────── Желе ─────────────
// Мягкое тело — узлы на пружинах с соседями; трясётся от перетаскивания, сплющивается от нажатия.
class _QJelly extends _QFrame {
  _QJelly() : super();
  static const int n = 30;
  final Float64List d = Float64List(n), vv = Float64List(n);
  static final Float64List _sin = Float64List.fromList(List<double>.generate(n, (i) => math.sin(i / n * _tau)));
  static final Float64List _cos = Float64List.fromList(List<double>.generate(n, (i) => math.cos(i / n * _tau)));
  static final ui.Gradient _g = ui.Gradient.radial(
      _qC,
      82,
      const [Color.fromRGBO(255, 170, 225, 0.95), Color.fromRGBO(230, 110, 235, 0.92), Color.fromRGBO(150, 90, 255, 0.92)],
      const [0.0, 0.7, 1.0],
      TileMode.clamp,
      null,
      const Offset(84, 78),
      30);

  @override
  bool get drawRing => true;

  double at(double a) {
    final u = ((a / _tau) % 1 + 1) % 1 * n, i = u.floor(), f = u - i;
    return d[i % n] * (1 - f) + d[(i + 1) % n] * f;
  }

  @override
  void update(double dt) {
    final acc = accel(dt), sd = dt / 2;
    if (on()) {
      for (var i = 0; i < n; i++) {
        vv[i] += 90 * math.cos(2 * i / n * _tau) - 30;
      }
    }
    for (var s = 0; s < 2; s++) {
      for (var i = 0; i < n; i++) {
        final l = d[(i + n - 1) % n], r = d[(i + 1) % n];
        vv[i] += (-70 * d[i] - 3.4 * vv[i] + 520 * (l + r - 2 * d[i]) - (acc.dx * _sin[i] - acc.dy * _cos[i]) * 0.05) * sd;
      }
      for (var i = 0; i < n; i++) {
        d[i] = _clamp(d[i] + vv[i] * sd, -7, 20);
      }
    }
    bre(1.8, 0.008);
  }

  @override
  void back(Canvas c, FramePalette p) => _glowS(c, const Offset(100, 104), 94, const Color(0xFFFF7AC8), 0.2, p.dark);

  @override
  void paintRing(Canvas c, [List<Color>? colors, double opacity = 1]) {
    double f(double a) => at(a) + 0.7 * math.sin(3 * a + t * 2);
    final outer = _blob(100, 100, 65, f, 48);
    c.drawPath(_qHoled(outer, av), _qFill(_qWhite)..shader = _g);
    c.drawPath(outer, _qLine(const Color.fromRGBO(255, 255, 255, 0.35), 1));
    c.drawPath(_blob(100, 100, 61.5, (a) => f(a) * 0.7, 48), _qLine(const Color.fromRGBO(255, 255, 255, 0.4), 1.4));
    final h = _pt(100, 100, 61 + at(-0.75) * 0.8, -0.75);
    c.save();
    c.translate(h.dx, h.dy);
    c.rotate(-0.75);
    c.drawOval(_ov(0, 0, 7, 2.2), _qFill(const Color.fromRGBO(255, 255, 255, 0.7)));
    c.restore();
    final h2 = _pt(100, 100, 61 + at(-1.15) * 0.8, -1.15);
    c.drawCircle(h2, 1.5, _qFill(const Color.fromRGBO(255, 255, 255, 0.75)));
  }
}

// ───────────── Бусины ─────────────
// Скользят по проволоке под настоящей гравитацией, упруго сталкиваются; качаются от перетаскивания.
class _QBeads extends _QFrame {
  _QBeads() : super(const [Color(0xFFE8EEFF), Color(0xFF8A8E99), Color(0xFFC9CCD4)]) {
    ringWidth = 1.8;
    for (var i = 0; i < n; i++) {
      a[i] = math.pi + (i - 5) * 0.215 + (_rnd() - 0.5) * 0.01;
    }
  }
  static const int n = 11;
  final Float64List a = Float64List(n), w = Float64List(n);
  static const List<Color> _cols = [
    Color(0xFFFF5F6D),
    Color(0xFFFFB23F),
    Color(0xFF3DD6FF),
    Color(0xFF7A5CFF),
    Color(0xFF3DFFB2),
    Color(0xFFFF4FD8),
  ];
  // Шейдер бусины в её собственных координатах: одна заготовка на цвет.
  static final List<ui.Gradient> _sh = [
    for (final c in _cols)
      ui.Gradient.radial(Offset.zero, 5.8, [_qWhite, c, _op(c, 0.75)], const [0.0, 0.3, 1.0], TileMode.clamp, null,
          const Offset(-1.8, -2), 0.5),
  ];

  @override
  void update(double dt) {
    final acc = accel(dt), sd = dt / 3;
    if (on()) {
      final dir = _rnd() < 0.5 ? -1 : 1;
      for (var i = 0; i < n; i++) {
        w[i] += dir * (6.5 + _rnd() * 3);
      }
    }
    for (var s = 0; s < 3; s++) {
      for (var i = 0; i < n; i++) {
        final ai = a[i];
        w[i] += (15 * math.sin(ai) + (acc.dx * math.cos(ai) + acc.dy * math.sin(ai)) / 58 * 0.8 - 0.4 * w[i]) * sd;
        a[i] += w[i] * sd;
      }
      for (var i = 0; i < n; i++) {
        final j = (i + 1) % n, gap = a[j] + (j == 0 ? _tau : 0) - a[i];
        if (gap < 0.2) {
          final o = (0.2 - gap) / 2;
          a[i] -= o;
          a[j] += o;
          if (w[i] > w[j]) {
            final wi = w[i], wj = w[j], m = (wi + wj) / 2, dv = (wi - wj) / 2 * 0.86;
            w[i] = m - dv;
            w[j] = m + dv;
          }
        }
      }
    }
    bre();
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (var i = 0; i < n; i++) {
      final q = _pt(100, 100, 58, a[i]);
      _glowS(c, Offset(q.dx, q.dy + 2), 9, const Color(0xFF000008), 0.35);
      c.save();
      c.translate(q.dx, q.dy);
      c.drawCircle(Offset.zero, 5.6, _qFill(_qWhite)..shader = _sh[i % 6]);
      c.restore();
    }
  }
}

// ───────────── Колба ─────────────
// Стеклянная трубка с жидкостью — плещется как маятник, пузыри всплывают; тап — встряхнуть.
class _QBub {
  _QBub(this.u, this.r, this.o);
  double u;
  final double r, o;
}

class _QDrop {
  _QDrop(this.x, this.y, this.vx, this.vy);
  double x, y, vx, vy, age = 0;
}

class _QLiquid extends _QFrame {
  _QLiquid() : super();
  double th = 0, w = 0;
  final Spring sl = Spring();
  final List<_QBub> b = [];
  final List<_QDrop> dr = [];

  /// Тема для [paintRing], у которого нет палитры: берётся из прошлого [back].
  bool _dark = true;

  @override
  bool get drawRing => true;

  @override
  void update(double dt) {
    final acc = accel(dt), sd = dt / 2;
    if (on()) {
      w += (_rnd() < 0.5 ? -1 : 1) * 7.5;
      for (var i = 0; i < 12; i++) {
        b.add(_QBub((_rnd() - 0.5) * 2, 0.8 + _rnd() * 1.6, (_rnd() - 0.5) * 4));
      }
      for (var i = 0; i < 8; i++) {
        final p = _pt(100, 100, 58, math.pi + th + (_rnd() - 0.5) * 2.4);
        dr.add(_QDrop(p.dx, p.dy, (_rnd() - 0.5) * 80, -40 - _rnd() * 70));
      }
    }
    for (var s = 0; s < 2; s++) {
      w += (-16 * math.sin(th) - (acc.dx * math.cos(th) - acc.dy * math.sin(th)) / 58 * 0.9 - 0.9 * w) * sd;
      th += w * sd;
    }
    sl.t = _clamp(-w * 0.09, -0.4, 0.4);
    sl.step(dt, 90, 5);
    if (_rnd() < dt * 2.5) b.add(_QBub((_rnd() - 0.5) * 1.6, 0.8 + _rnd() * 1.4, (_rnd() - 0.5) * 4));
    for (final q in b) {
      q.u += (q.u >= 0 ? 1 : -1) * dt * (0.5 + q.r * 0.25);
    }
    b.removeWhere((q) => q.u.abs() >= 1);
    for (final q in dr) {
      q.age += dt;
      q.vy += 260 * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
    }
    dr.removeWhere((q) => q.age >= 0.9);
    bre();
  }

  @override
  void back(Canvas c, FramePalette p) {
    _dark = p.dark;
    _glowS(c, _pt(100, 100, 60, math.pi + th), 60, const Color(0xFF3DD6FF), 0.3, p.dark);
  }

  @override
  void paintRing(Canvas c, [List<Color>? colors, double opacity = 1]) {
    // Стекло: белое в тёмной теме, как в референсе; на светлом фоне белое
    // исчезает, поэтому стенки трубки там тёмные. Блик остаётся белым.
    final ink = _dark ? _qWhite : const Color(0xFF2A2A40);
    final cc = math.pi / 2 + th, sp = 1.3, e1 = cc - sp + sl.x, e2 = cc + sp + sl.x;
    _qRing(c, 58, _qLine(_op(ink, 0.07), 9.5, StrokeCap.butt));
    final g = _linG(Offset(100 + math.cos(e1) * 58, 100 + math.sin(e1) * 58),
        Offset(100 + math.cos(e2) * 58, 100 + math.sin(e2) * 58), const [Color(0xFF3DD6FF), Color(0xFFB8C8FF), Color(0xFFFF6BD6)]);
    _qRing(c, 58, _qLine(_qWhite, 7.6)..shader = g, e1, e2);
    _qRing(c, 60.2, _qLine(_op(ink, 0.55), 1.3), e1 + 0.1, e2 - 0.1);
    _qRing(c, 55.6, _qLine(_op(ink, 0.3), 1), e1 + 0.1, e2 - 0.1);
    for (final a in [e1, e2]) {
      _qDisc(c, 100 + math.cos(a) * 58, 100 + math.sin(a) * 58, 2.2, _op(ink, 0.55));
    }
    final bp = _qLine(const Color.fromRGBO(255, 255, 255, 0.8), 0.6, StrokeCap.butt);
    for (final q in b) {
      final a = cc + q.u * sp + sl.x;
      c.drawCircle(Offset(100 + math.cos(a) * (58 + q.o * 0.5), 100 + math.sin(a) * (58 + q.o * 0.5)), q.r, bp);
    }
    _qRing(c, 62.9, _qLine(_op(ink, 0.4), 0.8, StrokeCap.butt));
    _qRing(c, 53.3, _qLine(_op(ink, 0.3), 0.8, StrokeCap.butt));
    _qRing(c, 61, _qLine(const Color.fromRGBO(255, 255, 255, 0.6), 1.2), -2.5, -1.5);
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (final q in dr) {
      _qDisc(c, q.x, q.y, 1.6, _op(const Color(0xFF9FE8FF), 1 - q.age / 0.9));
    }
  }
}

// ───────────── Механизм ─────────────
// Кольцо-шестерня и три ведомых в зацеплении, ход «тик-так»; тап — завод, раскрутка с выбегом.
Path _qGear(double r, int teeth, double th) {
  final st = _tau / teeth, p = Path();
  const prof = [0.0, 0.0, 0.24, 0.0, 0.34, 1.0, 0.66, 1.0, 0.76, 0.0];
  for (var k = 0; k < teeth; k++) {
    final a = k * st;
    for (var i = 0; i < 5; i++) {
      final aa = a + prof[i * 2] * st, rr = r + prof[i * 2 + 1] * th, x = math.cos(aa) * rr, y = math.sin(aa) * rr;
      (k == 0 && i == 0) ? p.moveTo(x, y) : p.lineTo(x, y);
    }
  }
  return p..close();
}

class _QGlint {
  _QGlint(this.x, this.y);
  final double x, y;
  double a = 1;
}

class _QGears extends _QFrame {
  _QGears() : super();
  final Spring rot = Spring(), w = Spring();
  double tg = 0, tm = 0;
  static final List<double> pc = [-52 * _deg, 128 * _deg, 215 * _deg];
  final List<_QGlint> gl = [];
  // Зубцы не меняются — контуры строятся один раз в своих координатах,
  // поворот делает холст.
  static final Path _big = _qGear(60.5, 40, 3.6);
  static final Path _bigFill = Path.from(_big)
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: 52));
  static final Path _small = _qGear(13, 10, 3.6);
  static const List<Color> _conic = [
    Color(0xFFF0CE7A),
    Color(0xFFB8862E),
    Color(0xFF7A5210),
    Color(0xFFB8862E),
    Color(0xFFF0CE7A),
    Color(0xFFB8862E),
    Color(0xFF7A5210),
    Color(0xFFB8862E),
    Color(0xFFF0CE7A),
  ];
  static const Color _edge = Color.fromRGBO(60, 36, 6, 0.7);

  @override
  bool get drawRing => true;

  @override
  void update(double dt) {
    w.t = active ? 3.2 : 0;
    w.step(dt, 14, 5.5);
    if (w.x.abs() > 0.25) {
      tg += w.x * dt;
      tm = 0.3;
    } else {
      tm -= dt;
      if (tm <= 0) {
        tg += _tau / 40;
        tm = 0.5;
        final a = pc[(_rnd() * 3).floor()];
        gl.add(_QGlint(100 + math.cos(a) * 62, 100 + math.sin(a) * 62));
      }
    }
    rot.t = tg;
    rot.step(dt, 380, 15);
    for (final g in gl) {
      g.a -= dt * 3;
    }
    gl.removeWhere((g) => g.a <= 0);
    bre();
  }

  @override
  void back(Canvas c, FramePalette p) {
    _glowS(c, _qC, 94, const Color(0xFFC9963C), 0.18, p.dark);
    final hole = _op(p.bg, 0.75);
    for (final a in pc) {
      final x = 100 + math.cos(a) * 77, y = 100 + math.sin(a) * 77, pr = -rot.x * 4 + a * 5 + math.pi / 10;
      final cs = math.cos(-pr), sn = math.sin(-pr);
      // Градиент неподвижен в мире: в повёрнутых координатах шестерни его
      // концы поворачиваются обратно.
      final g = _linG(Offset(-16 * cs + 16 * sn, -16 * sn - 16 * cs), Offset(16 * cs - 16 * sn, 16 * sn + 16 * cs),
          const [Color(0xFFE0B45A), Color(0xFF8A5E1E)]);
      c.save();
      c.translate(x, y);
      c.rotate(pr);
      c.drawPath(_small, _qFill(_qWhite)..shader = g);
      c.drawPath(_small, _qLine(_edge, 0.7, StrokeCap.butt, StrokeJoin.miter));
      for (var k = 0; k < 3; k++) {
        _qDisc(c, math.cos(k * _tau / 3) * 7, math.sin(k * _tau / 3) * 7, 2.6, hole);
      }
      c.restore();
      _qDisc(c, x, y, 3.4, const Color(0xFF5A3C12));
      _qDisc(c, x, y, 2, const Color(0xFFE0355A));
      _qDisc(c, x - 0.6, y - 0.6, 0.6, const Color.fromRGBO(255, 255, 255, 0.8));
    }
  }

  @override
  void paintRing(Canvas c, [List<Color>? colors, double opacity = 1]) {
    final r = rot.x;
    c.save();
    c.translate(100, 100);
    c.rotate(r);
    // Конический градиент референса начинается с угла r/2 в мире — в
    // координатах повёрнутой шестерни это −r/2.
    final g = ui.Gradient.sweep(Offset.zero, _conic, _even(9), TileMode.clamp, 0, _tau, Matrix4.rotationZ(-r * 0.5).storage);
    c.drawPath(_bigFill, _qFill(_qWhite)..shader = g);
    c.drawPath(_big, _qLine(_edge, 0.7, StrokeCap.butt, StrokeJoin.miter));
    c.drawCircle(Offset.zero, 58.2, _qLine(const Color.fromRGBO(60, 36, 6, 0.55), 0.8, StrokeCap.butt));
    c.drawCircle(Offset.zero, 55.6, _qLine(const Color.fromRGBO(255, 240, 200, 0.5), 0.8, StrokeCap.butt));
    for (var k = 0; k < 8; k++) {
      final a = k * _tau / 8;
      _qDisc(c, math.cos(a) * 57, math.sin(a) * 57, 0.9, const Color.fromRGBO(60, 36, 6, 0.8));
    }
    c.restore();
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (final g in gl) {
      _glint(c, Offset(g.x, g.y), 4 * g.a, g.a);
    }
  }
}

// ───────────── Поток ─────────────
// Потенциальное обтекание круга; тап добавляет циркуляцию — линии тока сносит вбок (эффект Магнуса).
class _QStream {
  _QStream(this.x, this.y, this.hi) : y0 = y;
  double x, y, s = 0;
  final double y0;
  final bool hi;
  // След — кольцевой буфер на 55 точек (в референсе массив с `splice`).
  final Float32List tr = Float32List(110);
  int head = 0, n = 0;
  void push() {
    int i;
    if (n < 55) {
      i = (head + n) % 55;
      n++;
    } else {
      i = head;
      head = (head + 1) % 55;
    }
    tr[i * 2] = x;
    tr[i * 2 + 1] = y;
  }
}

class _QFlow extends _QFrame {
  _QFlow() : super(const [Color(0xFFBFF2FF), Color(0xFF4A6BFF)]) {
    ringWidth = 3;
    for (var i = 0; i < 84; i++) {
      streams.add(_QStream(((i ~/ 21) + _rnd() * 0.6) * 52 - 6, (i % 21 + 0.5) * 200 / 21, i % 3 == 0));
    }
  }
  final Spring circ = Spring();
  final List<_QStream> streams = [];
  final Path _path = Path();

  @override
  void update(double dt) {
    circ.t = active ? 30000 : 0;
    circ.step(dt, 18, 5);
    const a2 = 62.0 * 62;
    final uu = 62 + _qHyp(ivx, ivy) * 0.3, g = circ.x / _tau;
    for (final q in streams) {
      final dx = q.x - 100, dy = q.y - 100, r2 = math.max(dx * dx + dy * dy, 900.0), k = a2 / (r2 * r2);
      final u = uu * (1 - k * (dx * dx - dy * dy)) - g * dy / r2, v = -uu * 2 * k * dx * dy + g * dx / r2;
      q.x += u * dt;
      q.y += v * dt;
      q.s = _qHyp(u, v);
      q.push();
      if (q.x > 250 || q.y < -40 || q.y > 240 || r2 < a2 * 0.92) {
        q.x = -6;
        q.y = q.y0;
        q.head = 0;
        q.n = 0;
      }
    }
    bre();
  }

  @override
  void back(Canvas c, FramePalette p) {
    _glowS(c, _qC, 96, const Color(0xFF4A6BFF), 0.16, p.dark);
    final mode = p.dark ? BlendMode.plus : BlendMode.srcOver;
    // Белые линии тока на светлом фоне не видны — там они синие.
    final hiCol = p.dark ? _qWhite : const Color(0xFF4A6BFF);
    for (final q in streams) {
      final n = q.n;
      if (n < 2) continue;
      _path.reset();
      for (var j = 0; j < n; j++) {
        final i = ((q.head + j) % 55) * 2;
        j == 0 ? _path.moveTo(q.tr[i], q.tr[i + 1]) : _path.lineTo(q.tr[i], q.tr[i + 1]);
      }
      c.drawPath(
          _path,
          _qLine(_op(q.hi ? hiCol : const Color(0xFF7FD4FF), _clamp(0.3 + q.s / 160, 0.3, 0.85)), q.hi ? 1.8 : 1.2,
              StrokeCap.round, StrokeJoin.round, mode));
    }
  }
}

// ───────────── Стая ─────────────
// Настоящие «боиды» — держат дистанцию, равняются на соседей, кружат у кольца; тап — испуг.
class _QFlock extends _QFrame {
  _QFlock() : super(const [Color(0xFFFFD36B), Color(0xFFFF7AB0)]) {
    ringWidth = 3;
    for (var i = 0; i < n; i++) {
      final a = _rnd() * _tau, p = _pt(100, 100, 63 + _rnd() * 7, a);
      x[i] = p.dx;
      y[i] = p.dy;
      vx[i] = math.cos(a) * 34;
      vy[i] = math.sin(a) * 34;
    }
  }
  static const int n = 34;
  final Float64List x = Float64List(n), y = Float64List(n), vx = Float64List(n), vy = Float64List(n);
  double sc = 0;
  static const List<Color> _cs = [Color(0xFFFFD36B), Color(0xFFFF9A7A), Color(0xFFFF7AB0)];
  static final List<Color> _tail = [for (final c in _cs) _op(c, 0.35)];
  static final Path _arrow = Path()
    ..moveTo(4.2, 0)
    ..lineTo(-3, 2.5)
    ..lineTo(-1.6, 0)
    ..lineTo(-3, -2.5)
    ..close();

  @override
  void update(double dt) {
    if (on()) sc = 0.7;
    sc = math.max(0, sc - dt);
    // Как в референсе: боиды обновляются по очереди, следующие видят уже
    // сдвинутых предыдущих.
    for (var b = 0; b < n; b++) {
      var sx = 0.0, sy = 0.0, ax = 0.0, ay = 0.0, cx = 0.0, cy = 0.0, cnt = 0;
      for (var o = 0; o < n; o++) {
        if (o == b) continue;
        final dx = x[o] - x[b], dy = y[o] - y[b], d2 = dx * dx + dy * dy;
        if (d2 > 700) continue;
        cnt++;
        ax += vx[o];
        ay += vy[o];
        cx += dx;
        cy += dy;
        if (d2 < 110) {
          final d0 = math.sqrt(d2), d = d0 == 0 ? 1.0 : d0;
          sx -= dx / d * (10.5 - d);
          sy -= dy / d * (10.5 - d);
        }
      }
      var fx = sx * 30, fy = sy * 30;
      if (cnt > 0) {
        fx += (ax / cnt - vx[b]) * 1.6 + cx / cnt * 1.2;
        fy += (ay / cnt - vy[b]) * 1.6 + cy / cnt * 1.2;
      }
      final dx = x[b] - 100, dy = y[b] - 100, r0 = _qHyp(dx, dy), r = r0 == 0 ? 1.0 : r0, ux = dx / r, uy = dy / r;
      // 23.11.2026: стая ближе к портрету (было: держится у 78, край 94).
      final k = (r < 62 ? (62 - r) * 60 : (67 - r) * 2.4) + (sc > 0 ? 420 : 0) - (r > 76 ? (r - 76) * 40 : 0);
      fx += ux * k - uy * 26 + ivx * 2;
      fy += uy * k + ux * 26 + ivy * 2;
      vx[b] += fx * dt;
      vy[b] += fy * dt;
      final s0 = _qHyp(vx[b], vy[b]), s = s0 == 0 ? 1.0 : s0, lim = _clamp(s, 28, sc > 0 ? 130 : 62);
      vx[b] = vx[b] / s * lim;
      vy[b] = vy[b] / s * lim;
      x[b] += vx[b] * dt;
      y[b] += vy[b] * dt;
    }
    bre();
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (var b = 0; b < n; b++) {
      final ci = b % 3;
      c.save();
      c.translate(x[b], y[b]);
      c.rotate(math.atan2(vy[b], vx[b]));
      c.drawLine(const Offset(-3, 0), const Offset(-9, 0), _qLine(_tail[ci], 1));
      c.drawPath(_arrow, _qFill(_cs[ci]));
      c.restore();
    }
  }
}

// ───────────── Маятники ─────────────
// Тридцать грузиков с чуть разными периодами (24 / (20 + i) с) — узоры расходятся и снова сходятся каждые 24 с.
class _QPWave extends _QFrame {
  _QPWave() : super(const [Color(0xFFB69CFF), Color(0xFF7FE0FF)]) {
    ringWidth = 3;
  }
  static const int n = 30;
  double tt = _rnd() * 24;
  final Spring amp = Spring(1);
  final Path _path = Path();
  final Float64List _r = Float64List(n);
  static const List<Color> _cs = [Color(0xFFB69CFF), Color(0xFF7FE0FF), Color(0xFFFF9ACB)];
  static final List<Color> _rod = [for (final c in _cs) _op(c, 0.2)];

  @override
  void update(double dt) {
    if (on()) {
      tt = 0;
      amp.x = 0.1;
      amp.v = 0;
    }
    amp.step(dt, 26, 5);
    tt += dt;
    bre();
  }

  @override
  void back(Canvas c, FramePalette p) {
    _glowS(c, _qC, 78, const Color(0xFF7A5CFF), 0.16, p.dark);
    final am = _clamp(amp.x, 0, 1.3);
    for (var k = 0; k < n; k++) {
      // 23.11.2026: уже (было 78 ± 13), ближе к кольцу.
      _r[k] = 67 + 6 * math.sin(_tau * (20 + k) / 24 * tt) * am;
    }
    _path.reset();
    for (var i = 0; i <= n; i++) {
      final k = i % n, q = _pt(100, 100, _r[k], k / n * _tau);
      i == 0 ? _path.moveTo(q.dx, q.dy) : _path.lineTo(q.dx, q.dy);
    }
    c.drawPath(_path, _qLine(const Color.fromRGBO(182, 156, 255, 0.28), 0.8, StrokeCap.butt, StrokeJoin.miter));
    for (var i = 0; i < n; i++) {
      final a = i / n * _tau, q = _pt(100, 100, _r[i], a), o = _pt(100, 100, 60, a), ci = i % 3;
      c.drawLine(o, q, _qLine(_rod[ci], 0.7, StrokeCap.butt));
      _glowS(c, q, 7, _cs[ci], 0.6, p.dark);
      c.drawCircle(q, 2.5, _qFill(_cs[ci]));
      _qDisc(c, q.dx - 0.7, q.dy - 0.7, 0.8, const Color.fromRGBO(255, 255, 255, 0.8));
    }
  }
}

// ───────────── Спирограф ─────────────
// Перо чертит розетку вокруг портрета; тап меняет «передаточное число» — узор перетекает в новый.
class _QSpiro extends _QFrame {
  _QSpiro() : super(const [Color(0xFFFF4FD8), Color(0xFF3DD6FF)]) {
    ringWidth = 2.5;
    // Узор прочерчен заранее (~4 оборота) — неподвижный кадр в сетке выбора
    // сразу содержательный.
    adv(26);
  }
  static const int cap = 1300;
  final Float32List _px = Float32List(cap * 2);
  int _h = 0, _n = 0;
  double th = _rnd() * 9;
  final Spring k = Spring(5), l = Spring(1);
  static const List<double> set = [5, 7, 3, 9, 4, 11];
  int _si = 0;
  final Path _path = Path();
  static const List<Color> _cs = [Color(0xFF3DD6FF), Color(0xFF7A8CFF), Color(0xFFB36BFF), Color(0xFFFF4FD8)];

  void adv(double d) {
    while (d > 0) {
      final st = math.min(d, 0.02);
      d -= st;
      th += st;
      final kk = k.x,
          // 23.11.2026: уже (было 79 + 12 + 5).
          r = 68 + (6 * math.cos(kk * th) + 2.5 * math.cos((2 * kk + 1) * th + t * 0.2)) * _clamp(l.x, 0.3, 1.25);
      int i;
      if (_n < cap) {
        i = (_h + _n) % cap;
        _n++;
      } else {
        i = _h;
        _h = (_h + 1) % cap;
      }
      _px[i * 2] = 100 + r * math.sin(th);
      _px[i * 2 + 1] = 100 - r * math.cos(th);
    }
  }

  int _at(int j) => ((_h + j) % cap) * 2;

  @override
  void update(double dt) {
    if (on()) {
      _si = (_si + 1) % set.length;
      k.t = set[_si];
      l.v += 2;
    }
    k.step(dt, 14, 5);
    l.step(dt, 40, 6);
    adv(dt * 1.7);
    bre();
  }

  @override
  void back(Canvas c, FramePalette p) {
    final n = _n;
    if (n < 4) return;
    final mode = p.dark ? BlendMode.plus : BlendMode.srcOver;
    const ch = 44;
    for (var cc = 0; cc < ch; cc++) {
      final j0 = (n * cc / ch).floor(), j1 = math.min(n - 1, (n * (cc + 1) / ch).floor() + 1);
      if (j1 - j0 < 2) continue;
      _path.reset();
      for (var j = j0; j <= j1; j++) {
        final i = _at(j);
        j == j0 ? _path.moveTo(_px[i], _px[i + 1]) : _path.lineTo(_px[i], _px[i + 1]);
      }
      final u = (cc + 1) / ch;
      c.drawPath(_path,
          _qLine(_op(_cs[(cc / ch * 3.99).floor()], 0.22 + u * 0.6), 0.8 + u * 0.7, StrokeCap.round, StrokeJoin.round, mode));
    }
    final e = _at(n - 1), o = Offset(_px[e], _px[e + 1]);
    _glowS(c, o, 9, const Color(0xFFFFB8F0), 0.95, p.dark);
    c.drawCircle(o, 1.8, _qFill(_qWhite));
  }
}
