// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../../profile_fx.dart';

// Переделанные старые рамки (13.11.2026), дизайн-референс fx-engine.js + fx-frames-2.js.
//
// Перенос один к одному: формулы, пружины, цвета и размеры — из референса.
// Холст 200 × 200, центр (100, 100), кольцо R = 58, фото av = 52.
//
// 🔴 ЧЕМ ОТЛИЧАЕТСЯ ОТ JS, И ПОЧЕМУ.
// • `edge()` здесь срабатывает на любое переключение, в JS — только на
//   включение. Поэтому действие запускает [_CfSim.up] = `edge() && active`.
// • `bs` / `bdy` / `brot` референса — равномерный масштаб: [_CfSim.bs],
//   а не `breathe()` базы (та сжимает по одной оси и растягивает по другой).
// • Свечения в циклах (сотни пятен у пламени, дыма, хвоста кометы) рисуются
//   одним `drawRawAtlas` на слой — [_CfGlows]. Порядок пятен внутри слоя тот
//   же, что в JS, поэтому картинка не меняется, а вызовов рисования — один.
// • Следы кометы и орбит пишутся с частотой 60 Гц, а не на каждый кадр:
//   на экране 120 Гц иначе вдвое гуще и вдвое ярче, чем в референсе.
// • Статические пути и шейдеры (перья феникса, крылья бабочек, звезда, грани
//   призмы, свип-градиенты) построены один раз; вращение — поворотом холста.

/// id старой рамки → новая живая симуляция; null — не из этого набора.
FrameSim? createClassicFrameSim(String id) => switch (id) {
      'cosmic' => _CfCosmic(),
      'gold' => _CfGold(),
      'orbit' => _CfOrbit(),
      'neon' => _CfNeon(),
      'stars' => _CfStars(),
      'aurora' => _CfAurora(),
      'pulse' => _CfPulse(),
      'ember' => _CfEmber(),
      'nebula' => _CfNebula(),
      'electric' => _CfElectric(),
      'flame' => _CfFlame(),
      'smoke' => _CfSmoke(),
      'bears' => _CfBear(),
      'rainbow' => _CfRainbow(),
      'butterfly' => _CfButterfly(),
      'comet' => _CfComet(),
      'sakura' => _CfSakura(),
      'phoenix' => _CfPhoenix(),
      'frost' => _CfFrost(),
      'prism' => _CfPrism(),
      _ => null,
    };

// ───────────── Общее ─────────────

const Offset _cfC = Offset(100, 100);
const Color _cfWhite = Color(0xFFFFFFFF);

/// Общие кисти: рисование синхронное, и `Paint` копируется в момент вызова,
/// так что одну кисть безопасно перенастраивать от вызова к вызову.
final Paint _cfFill = Paint();
final Paint _cfPenP = Paint()..style = PaintingStyle.stroke;

Paint _cfInk(Color col) => _cfFill..color = col;

Paint _cfPen(Color col, double w, [StrokeCap cap = StrokeCap.butt, StrokeJoin join = StrokeJoin.miter]) => _cfPenP
  ..color = col
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = join;

void _cfDisc(Canvas c, Offset o, double r, Color col) {
  if (r <= 0) return;
  c.drawCircle(o, r, _cfInk(col));
}

/// Окружность вокруг центра или дуга: [a0] — угол холста (0 — вправо, по часовой).
void _cfRing(Canvas c, double r, Paint p, [double a0 = 0, double sweep = _tau]) {
  if (sweep >= _tau) {
    c.drawCircle(_cfC, r, p);
  } else {
    c.drawArc(Rect.fromCircle(center: _cfC, radius: r), a0, sweep, false, p);
  }
}

/// Поворот холста вокруг центра рамки.
void _cfSpin(Canvas c, double a) {
  c.translate(100, 100);
  c.rotate(a);
  c.translate(-100, -100);
}

/// Матрица «повернуть на [a], затем сдвинуть на ([tx], [ty])» для `Path.transform`.
Float64List _cfAffine(double a, double tx, double ty) {
  final co = math.cos(a), si = math.sin(a);
  return Float64List(16)
    ..[0] = co
    ..[1] = si
    ..[4] = -si
    ..[5] = co
    ..[10] = 1
    ..[12] = tx
    ..[13] = ty
    ..[15] = 1;
}

/// Поворот на [a] вокруг центра рамки — локальная матрица шейдера.
Float64List _cfRotAbout(double a) {
  final co = math.cos(a), si = math.sin(a);
  return _cfAffine(a, 100 - co * 100 + si * 100, 100 - si * 100 - co * 100);
}

/// Пачка свечений одним `drawRawAtlas`: белый спрайт [_glowSprite], цвет и
/// прозрачность — модуляцией. То же, что серия [_glowS] в том же порядке.
class _CfGlows {
  Float32List _xf = Float32List(0), _src = Float32List(0);
  Int32List _col = Int32List(0);
  int _n = 0;
  final Paint _p = Paint()..filterQuality = FilterQuality.low;

  void add(Offset o, double r, Color col, double op) {
    if (op <= 0.003 || r <= 0.5) return;
    if (_n >= _col.length) _grow();
    final i = _n * 4;
    _xf[i] = r / 32;
    _xf[i + 1] = 0;
    _xf[i + 2] = o.dx - r;
    _xf[i + 3] = o.dy - r;
    _col[_n] = ((255 * (op > 1 ? 1 : op)).round() << 24) | (col.toARGB32() & 0xFFFFFF);
    _n++;
  }

  void _grow() {
    final cap = math.max(64, _col.length * 2);
    final xf = Float32List(cap * 4)..setRange(0, _xf.length, _xf);
    final src = Float32List(cap * 4);
    for (var i = 0; i < cap; i++) {
      src[i * 4 + 2] = 64;
      src[i * 4 + 3] = 64;
    }
    _xf = xf;
    _src = src;
    _col = Int32List(cap)..setRange(0, _col.length, _col);
  }

  void flush(Canvas c, [bool add = true]) {
    if (_n == 0) return;
    _p.blendMode = add ? BlendMode.plus : BlendMode.srcOver;
    c.drawRawAtlas(
        _glowSprite(_cfWhite),
        Float32List.sublistView(_xf, 0, _n * 4),
        Float32List.sublistView(_src, 0, _n * 4),
        Int32List.sublistView(_col, 0, _n),
        BlendMode.modulate,
        null,
        _p);
    _n = 0;
  }
}

final _CfGlows _cfG = _CfGlows();

/// Частица общего вида: искра, лепесток, осколок, перо пепла.
class _CfP {
  _CfP(this.x, this.y, this.vx, this.vy, this.life, [this.r = 0, this.sd = 0]);
  double x, y, vx, vy, life, r, sd;
  double age = 0, rot = 0, vr = 0, s = 0;
  Color c = _cfWhite;
  bool f = false;
  Offset get o => Offset(x, y);
}

/// Расходящееся кольцо: радиус и сила.
class _CfRg {
  _CfRg(this.r, this.a);
  double r, a;
}

/// База переделанных рамок: геометрия референса и его семантика.
abstract class _CfSim extends FrameSim {
  _CfSim([List<Color> cols = const []]) : super(100, 100, 58, 52, cols);

  /// Действие: `edge()` референса — только включение [active].
  bool up() => edge() && active;

  /// `bs` / `brot` / `bdy` референса: равномерный масштаб тела.
  void bs(double s, [double rot = 0, double dy = 0]) => body(s, s, rot, 0, dy);

  /// `breathe()` референса: равномерное «дыхание».
  void breatheU([double f = 1.6, double amp = 0.006, double dy = 0]) => bs(1 + math.sin(t * f) * amp, 0, dy);

  double _smp = 0;

  /// Сколько отсчётов по 60 Гц пришлось на кадр [dt] (для следов).
  int samples60(double dt) {
    _smp += dt * 60;
    var n = 0;
    while (_smp >= 0.75) {
      _smp -= 1;
      n++;
    }
    if (_smp < 0) _smp = 0;
    return n;
  }

  Paint? _ringPaint;

  /// Кольцо по умолчанию (`ringDraw` референса) — кисть с шейдером одна на рамку.
  @override
  void paintRing(Canvas c, [List<Color>? colors, double opacity = 1]) {
    if (colors != null || opacity < 1) {
      super.paintRing(c, colors, opacity);
      return;
    }
    final p = _ringPaint ??= (_stroke(_cfWhite, ringWidth, StrokeCap.butt)
      ..shader = _linG(const Offset(42, 42), const Offset(158, 158), ringColors));
    c.drawPath(ringPath(), p);
  }
}

// ───────────── Космос ─────────────
// Пояс пыли с кеплеровским вращением; действие — ударная волна по поясу.

class _CfDust {
  _CfDust(this.a, this.r, this.s, this.ph, this.c) : w = 0.5 * _pow(60 / r, 1.5);
  double a, d = -1;
  final double r, s, ph, w;
  final Color c;
  final Spring o = Spring();
}

class _CfCosmic extends _CfSim {
  _CfCosmic() : super(const [Color(0xFF2B1E6B), Color(0xFF7A5CFF), Color(0xFF3DD6FF)]) {
    ringWidth = 4;
    for (var i = 0; i < 84; i++) {
      _p.add(_CfDust(_rnd() * _tau, 61 + _pow(_rnd(), 1.5) * 25, 0.5 + _rnd() * 1.3, _rnd() * 9,
          _cols[(_rnd() * 4).floor()]));
    }
  }
  static const _cols = [Color(0xFFFFFFFF), Color(0xFFBFD0FF), Color(0xFFD9BFFF), Color(0xFF7FE0FF)];
  final List<_CfDust> _p = [];
  double _wave = -1;

  @override
  void update(double dt) {
    if (up()) {
      _wave = 0;
      for (final q in _p) {
        q.d = (q.r - 58) / 95;
      }
    }
    if (_wave >= 0) {
      _wave += dt * 95;
      if (_wave > 46) _wave = -1;
    }
    for (final q in _p) {
      q.a += dt * q.w;
      if (q.d >= 0) {
        q.d -= dt;
        if (q.d < 0) q.o.v += 80;
      }
      q.o.step(dt, 55, 4.5);
    }
    breatheU();
  }

  @override
  void back(Canvas c, FramePalette p) {
    _glowS(c, _cfC, 96, const Color(0xFF5B3BD6), 0.3, true);
    for (final q in _p) {
      final o = _pt(100, 100, q.r + q.o.x, q.a), a = 0.3 + 0.7 * math.sin(t * (0.8 + q.s) + q.ph).abs();
      if (q.s > 1.55) {
        _glowS(c, o, 5, q.c, a * 0.7, true);
        _glint(c, o, 2.6, a);
      } else {
        _cfDisc(c, o, q.s * 0.75, _op(q.c, a));
      }
    }
  }

  @override
  void front(Canvas c, FramePalette p) {
    if (_wave >= 0) _cfRing(c, 58 + _wave, _cfPen(_op(const Color(0xFFBFD0FF), (1 - _wave / 46) * 0.7), 1.6));
  }
}

// ───────────── Золото ─────────────
// Литое кольцо, блик ходит по инерции, редкие искры; действие — «звон монеты».

class _CfGold extends _CfSim {
  _CfGold() : _rot = _rnd() * _tau;
  double _rot, _acc = 0;
  final Spring _w = Spring(0.55), _hit = Spring();
  final List<_CfP> _sp = [];
  static const _cols = [
    Color(0xFFFFF3C8), Color(0xFFE8A33D), Color(0xFFB9791E), Color(0xFF7A4A10), Color(0xFFB9791E),
    Color(0xFFE8A33D), Color(0xFFFFE9A8), Color(0xFFE8A33D), Color(0xFFB9791E), Color(0xFF7A4A10),
    Color(0xFFB9791E), Color(0xFFE8A33D), Color(0xFFFFF3C8),
  ];
  static final List<double> _stops = List<double>.generate(13, (i) => i / 12);
  final Paint _rp = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8.5;

  @override
  bool get drawRing => true;

  void _spark(double a, double sp) {
    final o = _pt(100, 100, 59, a);
    _sp.add(_CfP(o.dx, o.dy, math.sin(a) * sp + (_rnd() - 0.5) * 16, -math.cos(a) * sp - 8, 0.7 + _rnd() * 0.7,
        0.8 + _rnd() * 1.3));
  }

  @override
  void update(double dt) {
    if (up()) {
      _hit.v += 9;
      _w.v += 16;
      for (var i = 0; i < 26; i++) {
        _spark(i / 26 * _tau + _rnd() * 0.2, 40 + _rnd() * 60);
      }
    }
    _w.step(dt, 18, 3);
    _rot += _w.x * dt;
    _hit.step(dt, 220, 7);
    _acc += dt;
    if (_acc > 0.22) {
      _acc = 0;
      _spark(_rot + (_rnd() - 0.5) * 0.5, 6 + _rnd() * 10);
    }
    for (final q in _sp) {
      q.age += dt;
      q.vy += 110 * dt;
      q.vx *= 1 - dt * 1.2;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
    }
    _sp.removeWhere((q) => q.age >= q.life);
    bs(1 + _hit.x * 0.012 + math.sin(t * 1.6) * 0.006);
  }

  @override
  void back(Canvas c, FramePalette p) =>
      _glowS(c, _cfC, 92, const Color(0xFFE8A33D), 0.2 + _hit.x.abs() * 0.25, true);

  @override
  void paintRing(Canvas c, [List<Color>? colors, double opacity = 1]) {
    _rp.shader = ui.Gradient.sweep(_cfC, _cols, _stops, TileMode.clamp, 0, _tau, _cfRotAbout(_rot - math.pi / 2));
    c.drawPath(ringPath(), _rp);
    c.drawCircle(_cfC, 62, _cfPen(const Color.fromRGBO(255, 243, 200, .6), 1));
    c.drawCircle(_cfC, 54.3, _cfPen(const Color.fromRGBO(70, 38, 6, .65), 1));
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (final q in _sp) {
      final u = _clamp(1 - q.age / q.life, 0, 1);
      _glowS(c, q.o, q.r * 4, const Color(0xFFFFD36B), u * 0.9, true);
      _cfDisc(c, q.o, q.r * 0.6 * u, Color.fromRGBO(255, 248, 220, u));
    }
    final a = _pt(100, 100, 59, _rot), b = _pt(100, 100, 59, _rot + math.pi);
    final tw = 0.7 + 0.3 * math.sin(t * 5);
    _glowS(c, a, 12, const Color(0xFFFFF3C8), 0.8, true);
    _glint(c, a, 7 * tw + _hit.x.abs() * 3, 0.95);
    _glint(c, b, 3.5 * tw, 0.6);
  }
}

// ───────────── Орбита ─────────────
// Модель атома: три наклонные орбиты, электроны уходят за фото; действие — разгон.

class _CfOrb {
  _CfOrb(this.tilt, this.th, this.w, this.col);
  final double tilt, w;
  double th;
  final Color col;
  final List<double> tr = [];
}

class _CfOrbit extends _CfSim {
  _CfOrbit() : super(const [Color(0xFF4A6BFF), Color(0xFF8A5CF0)]) {
    ringWidth = 4;
    for (var i = 0; i < 3; i++) {
      _o.add(_CfOrb(i * 60 * _deg + 0.3, _rnd() * _tau, (1.6 + i * 0.5) * (i.isOdd ? -1 : 1), _cols[i]));
    }
  }
  static const _cols = [Color(0xFF7FE0FF), Color(0xFFB69CFF), Color(0xFFFF9ACB)];
  final Spring _sp = Spring(1);
  double _pre = 0;
  final List<_CfOrb> _o = [];

  Offset _e(_CfOrb o, double th) {
    final x = 85 * math.cos(th), y = 22 * math.sin(th), a = o.tilt + _pre, co = math.cos(a), si = math.sin(a);
    return Offset(100 + x * co - y * si, 100 + x * si + y * co);
  }

  @override
  void update(double dt) {
    edge();
    _sp.t = active ? 3.6 : 1;
    _sp.step(dt, 40, 7);
    _pre += dt * 0.12 * _sp.x;
    final n = samples60(dt);
    for (final o in _o) {
      final th0 = o.th;
      o.th += o.w * _sp.x * dt;
      for (var j = 1; j <= n; j++) {
        o.tr.add(th0 + (o.th - th0) * j / n);
      }
      if (o.tr.length > 18) o.tr.removeRange(0, o.tr.length - 18);
    }
    breatheU();
  }

  void _half(Canvas c, bool front) {
    for (final o in _o) {
      final path = Path();
      for (var k = 0; k <= 22; k++) {
        final q = _e(o, (front ? 0 : math.pi) + math.pi * k / 22);
        k == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
      }
      c.drawPath(path, _cfPen(_op(o.col, front ? 0.38 : 0.22), 1.1));
      final n = o.tr.length;
      for (var i = 0; i < n; i++) {
        final th = o.tr[i];
        if ((math.sin(th) > 0) != front) continue;
        final u = i / n;
        _cfG.add(_e(o, th), 2 + u * 5, o.col, u * 0.5);
      }
      final head = (math.sin(o.th) > 0) == front;
      final h = _e(o, o.th);
      if (head) _cfG.add(h, 11, o.col, 0.95);
      _cfG.flush(c);
      if (head) _cfDisc(c, h, 2.8, _cfWhite);
    }
  }

  @override
  void back(Canvas c, FramePalette p) {
    _glowS(c, _cfC, 90, const Color(0xFF4A6BFF), 0.18, true);
    _half(c, false);
  }

  @override
  void front(Canvas c, FramePalette p) => _half(c, true);
}

// ───────────── Неон ─────────────
// Газовая трубка с разрывом, изредка мигает; действие — гаснет и зажигается заново.

class _CfNeon extends _CfSim {
  final Spring _on = Spring(1);
  double _fl = 1, _nf = 2 + _rnd() * 3, _ft = 0, _off = 0, _k = 0;
  final List<_CfP> _sp = [];
  static const double _g = math.pi * 0.28;
  static final ui.Gradient _sh =
      _linG(const Offset(42, 42), const Offset(158, 158), const [Color(0xFF5C8BFF), Color(0xFFB36BFF)]);
  final Paint _gp = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.4
    ..strokeCap = StrokeCap.round
    ..shader = _sh;

  @override
  bool get drawRing => true;

  @override
  void update(double dt) {
    if (up()) {
      _off = 0.35;
      _on.t = 0;
    }
    if (_off > 0) {
      _off -= dt;
      if (_off <= 0) {
        _on.t = 1;
        _ft = 0.55;
      }
    }
    _on.step(dt, 140, 9);
    _nf -= dt;
    if (_nf <= 0) {
      _ft = 0.18 + _rnd() * 0.25;
      _nf = 2.5 + _rnd() * 5;
    }
    if (_ft > 0) {
      _ft -= dt;
      _fl = _rnd() < 0.45 ? 0.2 : 1;
      if (_rnd() < dt * 40) {
        _sp.add(_CfP(100 + 58 * math.cos(_g), 100 + 58 * math.sin(_g), (_rnd() - 0.3) * 50, (_rnd() - 0.6) * 50,
            0.2 + _rnd() * 0.3));
      }
    } else {
      _fl = 1;
    }
    for (final q in _sp) {
      q.age += dt;
      q.vy += 180 * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
    }
    _sp.removeWhere((q) => q.age >= q.life);
    _k = _clamp(_on.x, 0, 1.3) * _fl;
    breatheU();
  }

  @override
  void back(Canvas c, FramePalette p) {
    _glowS(c, _cfC, 98, const Color(0xFF4A6BFF), 0.34 * _k, true);
    _glowS(c, const Offset(104, 108), 80, const Color(0xFFB36BFF), 0.22 * _k, true);
  }

  @override
  void paintRing(Canvas c, [List<Color>? colors, double opacity = 1]) {
    final k = _k;
    const a0 = _g + 0.13, sw = _tau - 0.26;
    _cfRing(c, 58, _cfPen(const Color(0xFF1A1F3A), 7, StrokeCap.round), a0, sw);
    _cfRing(c, 58, _cfPen(_op(const Color(0xFF6C8BFF), 0.3 * k), 10, StrokeCap.round), a0, sw);
    final ga = _clamp(k, 0, 1);
    if (ga > 0) {
      _gp.color = Color.fromRGBO(255, 255, 255, ga);
      _cfRing(c, 58, _gp, a0, sw);
      _cfRing(c, 58, _cfPen(Color.fromRGBO(255, 255, 255, 0.9 * ga), 1.1, StrokeCap.round), a0, sw);
    }
    final k2 = _clamp(k * (0.75 + 0.25 * math.sin(t * 23)), 0, 1);
    if (k2 > 0) {
      for (final s in const [(1.05, 0.55), (0.5, 0.4)]) {
        final s0 = math.pi * s.$1, ss = math.pi * s.$2;
        _cfRing(c, 65, _cfPen(_op(const Color(0xFFFF6BD6), 0.3 * k2), 6, StrokeCap.round), s0, ss);
        _cfRing(c, 65, _cfPen(_op(const Color(0xFFFF8BE0), k2), 1.8, StrokeCap.round), s0, ss);
      }
    }
    for (final a in const [a0, a0 + sw]) {
      _cfDisc(c, Offset(100 + 58 * math.cos(a), 100 + 58 * math.sin(a)), 2.6, const Color(0xFF8A8E99));
    }
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (final q in _sp) {
      _glowS(c, q.o, 4.5, const Color(0xFFDDE6FF), 1 - q.age / q.life, true);
    }
  }
}

// ───────────── Звёзды ─────────────
// Девять звёзд на пружинах, по кругу бежит волна; действие — подпрыгивают.

class _CfStar {
  _CfStar(this.a, this.big);
  final double a;
  final bool big;
  final Spring x = Spring(), y = Spring(), sc = Spring(1), rot = Spring();
}

class _CfStars extends _CfSim {
  _CfStars() : super(const [Color(0xFFFFE08A), Color(0xFFFFB23F), Color(0xFFFF7AB0)]) {
    ringWidth = 4;
  }
  double _wv = _rnd() * _tau;
  final List<_CfStar> _s = List<_CfStar>.generate(9, (i) => _CfStar(i / 9 * _tau, i % 3 == 0));

  /// Пятиконечная звезда единичного радиуса, внутренний радиус 0.45.
  static final Path _star = () {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isOdd ? 0.45 : 1.0, a = i * math.pi / 5;
      i == 0 ? p.moveTo(r * math.sin(a), -r * math.cos(a)) : p.lineTo(r * math.sin(a), -r * math.cos(a));
    }
    return p..close();
  }();
  static final Paint _fillP = Paint()
    ..shader = _linG(const Offset(0, -1), const Offset(0, 1), const [Color(0xFFFFF6D0), Color(0xFFFFAA2E)]);

  @override
  void update(double dt) {
    if (up()) {
      for (final s in _s) {
        s.x.v += (_rnd() - 0.5) * 260;
        s.y.v -= 90 + _rnd() * 170;
        s.rot.v += (_rnd() - 0.5) * 34;
      }
    }
    _wv += dt * 2.2;
    for (final s in _s) {
      s.sc.t = 1 + 0.42 * _pow(math.max(0, math.cos(_wv - s.a)), 8);
      s.sc.step(dt, 200, 8);
      s.x.step(dt, 70, 5);
      s.y.step(dt, 70, 5);
      s.rot.step(dt, 60, 5);
    }
    breatheU();
  }

  @override
  void back(Canvas c, FramePalette p) => _glowS(c, _cfC, 92, const Color(0xFFFFB23F), 0.16, true);

  @override
  void front(Canvas c, FramePalette p) {
    for (final s in _s) {
      final q = _pt(100, 100, 67, s.a), R = (s.big ? 7.5 : 5.2) * s.sc.x;
      final o = Offset(q.dx + s.x.x, q.dy + s.y.x);
      _glowS(c, o, R * 2.6, const Color(0xFFFFD36B), 0.3 + (s.sc.x - 1) * 1.6, true);
      if (R <= 0) continue;
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(s.a * 0.3 + s.rot.x + math.sin(t * 1.4 + s.a) * 0.12);
      c.scale(R);
      c.drawPath(_star, _fillP);
      c.restore();
    }
  }
}

// ───────────── Аврора ─────────────
// Занавес из 100 лучей вокруг кольца; действие — магнитная буря.

class _CfAurora extends _CfSim {
  _CfAurora() : super(const [Color(0xFF19C3A6), Color(0xFF2F8FE0), Color(0xFF8A5CF0)]) {
    ringWidth = 4;
  }
  final Spring _st = Spring();
  static const _cols = [Color(0xFF19C3A6), Color(0xFF2F8FE0), Color(0xFF8A5CF0)];
  final Paint _ln = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;

  @override
  void update(double dt) {
    if (up()) _st.v += 7;
    _st.step(dt, 30, 4);
    breatheU();
  }

  @override
  void back(Canvas c, FramePalette p) {
    final k = 1 + _clamp(_st.x, -0.5, 2) * 0.55;
    for (var i = 0; i < 100; i++) {
      final a = i / 100 * _tau;
      final n = _clamp(
          0.5 + 0.5 * math.sin(a * 3 + t * 0.9) * math.sin(a * 5 - t * 0.6 + 1.3) + 0.25 * math.sin(a * 11 + t * 1.7),
          0,
          1.3);
      final L = (5 + 19 * n) * k;
      final col = _cols[((math.sin(a * 2 + t * 0.3) * 0.5 + 0.5) * 2.99).floor()];
      final bend = math.sin(t * 0.7 + a * 4) * 0.06;
      final p0 = _pt(100, 100, 59, a), p1 = _pt(100, 100, 59 + L * 0.55, a + bend * 0.5);
      final p2 = _pt(100, 100, 59 + L, a + bend);
      _ln
        ..color = _op(col, 0.5 * n + 0.1)
        ..strokeWidth = 3.2;
      c.drawLine(p0, p1, _ln);
      _ln
        ..color = _op(col, 0.2 * n + 0.04)
        ..strokeWidth = 2.4;
      c.drawLine(p1, p2, _ln);
    }
  }
}

// ───────────── Пульс ─────────────
// Сонар: кольца расходятся, луч обходит круг и подсвечивает цели; действие — сильный импульс.

class _CfBlip {
  _CfBlip(this.a, this.r);
  final double a, r;
  double l = 0;
}

class _CfPulse extends _CfSim {
  _CfPulse() : super(const [Color(0xFF3DFFB2), Color(0xFF1FB5A8)]) {
    ringWidth = 3;
  }
  final List<_CfRg> _rings = [];
  double _tm = 0.2, _sw = _rnd() * _tau;
  final Spring _th = Spring();
  final List<_CfBlip> _bl = List<_CfBlip>.generate(5, (_) => _CfBlip(_rnd() * _tau, 66 + _rnd() * 22));
  static final Path _ann = Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: _cfC, radius: 95))
    ..addOval(Rect.fromCircle(center: _cfC, radius: 58));

  /// Луч: свип от востока, яркий край на 1 рад; поворачивается холстом.
  static final Paint _beam = Paint()
    ..shader = ui.Gradient.sweep(_cfC, const [
      Color.fromRGBO(61, 255, 178, 0),
      Color.fromRGBO(61, 255, 178, .42),
      Color.fromRGBO(61, 255, 178, 0),
      Color.fromRGBO(61, 255, 178, 0),
    ], const [
      0,
      1 / _tau,
      1 / _tau + 0.001,
      1,
    ]);

  void _ping(double s) {
    _rings.add(_CfRg(58, s));
    _th.v += s * 2.4;
  }

  @override
  void update(double dt) {
    if (up()) _ping(1.7);
    _tm -= dt;
    if (_tm <= 0) {
      _ping(1);
      _tm = 1.5;
    }
    for (final q in _rings) {
      q.r += dt * (74 - (q.r - 58) * 1.25);
    }
    _rings.removeWhere((q) => q.r >= 95);
    _th.step(dt, 300, 14);
    _sw += dt * 1.8;
    for (final b in _bl) {
      if ((_sw - b.a) % _tau < 0.14) b.l = 1;
      b.l = math.max(0, b.l - dt * 0.9);
    }
    bs(1 + _th.x * 0.01);
  }

  @override
  void back(Canvas c, FramePalette p) {
    _glowS(c, _cfC, 96, const Color(0xFF1FB5A8), 0.2, true);
    c.drawCircle(_cfC, 72, _cfPen(const Color.fromRGBO(61, 255, 178, .09), 0.8));
    c.drawCircle(_cfC, 86, _cfPen(const Color.fromRGBO(61, 255, 178, .07), 0.8));
    c.save();
    _cfSpin(c, _sw - 1 - math.pi / 2);
    c.drawPath(_ann, _beam);
    c.restore();
    for (final q in _rings) {
      c.drawCircle(
          _cfC, q.r, _cfPen(_op(const Color(0xFF7CFFD0), math.min(1, q.a) * (1 - (q.r - 58) / 37) * 0.85), 1 + q.a * 0.9));
    }
    for (final b in _bl) {
      final o = _pt(100, 100, b.r, b.a);
      _glowS(c, o, 8, const Color(0xFF7CFFD0), b.l * 0.9, true);
      _cfDisc(c, o, 1.6, _op(const Color(0xFFEFFFF8), b.l));
    }
  }
}

// ───────────── Угли ─────────────
// 48 тлеющих сегментов, жар перетекает; действие — «подуть», угли вспыхивают.

class _CfEmber extends _CfSim {
  final List<double> _h = List<double>.generate(48, (_) => _rnd() * 0.6);
  final Spring _blow = Spring();
  final List<_CfP> _p = [];
  double _acc = 0, _hb = 0;
  static const Rect _r58 = Rect.fromLTWH(42, 42, 116, 116);

  @override
  bool get drawRing => true;

  void _em(double k) {
    final a = (_rnd() - 0.5) * math.pi * 1.7, o = _pt(100, 100, 60, a);
    _p.add(_CfP(o.dx, o.dy, (_rnd() - 0.5) * 22 * k, -(18 + _rnd() * 30) * k, 1 + _rnd() * 1.3, 0, _rnd() * 9));
  }

  @override
  void update(double dt) {
    if (up()) {
      _blow.v += 6;
      for (var i = 0; i < 22; i++) {
        _em(1.8);
      }
    }
    _blow.step(dt, 20, 3);
    final b = _clamp(_blow.x, 0, 1.5);
    for (var i = 0; i < 48; i++) {
      final tg = 0.36 + 0.36 * math.sin(t * 1.3 + i * 0.7) * math.sin(t * 0.37 + i * 1.9) + b * 0.6 + (_rnd() - 0.5) * 0.3;
      _h[i] += (tg - _h[i]) * dt * 5;
    }
    _acc += dt * (4 + b * 26);
    while (_acc > 1) {
      _acc--;
      _em(1);
    }
    for (final q in _p) {
      q.age += dt;
      q.vy -= 12 * dt;
      q.x += (q.vx + math.sin(q.age * 5 + q.sd) * 10 + ivx) * dt;
      q.y += (q.vy + ivy) * dt;
    }
    _p.removeWhere((q) => q.age >= q.life);
    _hb = b;
    breatheU();
  }

  @override
  void back(Canvas c, FramePalette p) => _glowS(c, _cfC, 94, const Color(0xFFFF5A1E), 0.2 + _hb * 0.3, true);

  @override
  void paintRing(Canvas c, [List<Color>? colors, double opacity = 1]) {
    c.drawCircle(_cfC, 58, _cfPen(const Color(0xFF17100E), 9));
    const sw = _tau / 48 - 0.024;
    for (var i = 0; i < 48; i++) {
      final a0 = i / 48 * _tau + 0.012, h = _clamp(_h[i], 0, 1.4);
      if (h > 0) c.drawArc(_r58, a0, sw, false, _cfPen(_op(const Color(0xFFFF5A1E), h * 0.95), 7));
      if (h > 0.55) c.drawArc(_r58, a0, sw, false, _cfPen(_op(const Color(0xFFFFD27A), (h - 0.55) * 2), 3.2));
    }
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (final q in _p) {
      final u = q.age / q.life;
      _cfG.add(q.o, 4, const Color(0xFFFF963C), (u < 0.1 ? u * 10 : 1 - u) * (0.7 + 0.3 * math.sin(t * 13 + q.sd)));
    }
    _cfG.flush(c);
  }
}

// ───────────── Туманность ─────────────
// Спиральные рукава; действие — сжатие к кольцу с ускорением (сохранение момента) и разлёт.

class _CfNeb {
  _CfNeb(this.arm, this.u, this.j, this.jr, this.s, this.ph, this.c);
  final int arm;
  final double u, j, jr, s, ph;
  final Color c;
}

class _CfNebula extends _CfSim {
  _CfNebula() : super(const [Color(0xFFFF4FD8), Color(0xFF7A5CFF), Color(0xFF3DD6FF)]) {
    ringWidth = 3;
  }
  static const _pc = [Color(0xFFFF8AE2), Color(0xFFB69CFF), Color(0xFF7FE0FF), Color(0xFFFFFFFF)];
  static const _cc = [Color(0xFFFF4FD8), Color(0xFF7A5CFF), Color(0xFF3DD6FF)];
  double _rot = _rnd() * 9, _cz = 0;
  final Spring _k = Spring(1);
  final List<_CfNeb> _p = List<_CfNeb>.generate(
      120,
      (i) => _CfNeb(i % 2, _rnd(), (_rnd() - 0.5) * 0.55, (_rnd() - 0.5) * 6, 0.5 + _rnd() * 1.2, _rnd() * 9,
          _pc[(_rnd() * 4).floor()]));
  final List<_CfNeb> _cl = List<_CfNeb>.generate(10, (i) => _CfNeb(i % 2, 0.1 + i / 10 * 0.85, 0, 0, 0, 0, _cc[i % 3]));

  Offset _pos(_CfNeb q) {
    final k = math.max(0.05, _k.x);
    return _pt(100, 100, 59 + (3 + q.u * 26 + q.jr) * k, _rot * (1.5 - q.u * 0.7) + q.arm * math.pi + q.u * 3.6 + q.j);
  }

  @override
  void update(double dt) {
    if (up()) {
      _k.t = 0.12;
      _cz = 0.4;
    }
    if (_cz > 0) {
      _cz -= dt;
      if (_cz <= 0) _k.t = 1;
    }
    _k.step(dt, 60, 5.5);
    final k = _clamp(_k.x, 0.3, 1.6);
    _rot += dt * 0.28 / (k * k);
    breatheU();
  }

  @override
  void back(Canvas c, FramePalette p) {
    for (final q in _cl) {
      _glowS(c, _pos(q), 22, q.c, 0.3, true);
    }
    for (final q in _p) {
      final o = _pos(q), a = 0.35 + 0.65 * math.sin(t * (0.7 + q.s) + q.ph).abs();
      if (q.s > 1.55) {
        _glint(c, o, 2.4, a);
      } else {
        _cfDisc(c, o, q.s * 0.7, _op(q.c, a));
      }
    }
  }
}

// ───────────── Пламя ─────────────
// Огонь по всему кольцу, языки тянутся вверх и отстают при перетаскивании; действие — вспышка.

class _CfFlame extends _CfSim {
  _CfFlame() : super(const [Color(0xFFFFE9A8), Color(0xFFFF9A2E), Color(0xFFD8401A)]) {
    ringWidth = 5;
  }
  final List<_CfP> _p = [], _s = [];
  double _acc = 0;
  final Spring _f = Spring();

  @override
  void update(double dt) {
    if (up()) _f.v += 5;
    _f.step(dt, 24, 3.5);
    final k = 1 + _clamp(_f.x, 0, 2);
    _acc += dt * 85 * k;
    while (_acc > 1) {
      _acc--;
      final a = _rnd() * _tau, o = _pt(100, 100, 58, a);
      final vx = math.sin(a) * 8 + (_rnd() - 0.5) * 10, vy = -(15 + _rnd() * 26) * k - math.cos(a) * 6;
      final r = (5 + _rnd() * 5) * (0.8 + 0.25 * k);
      _p.add(_CfP(o.dx, o.dy, vx, vy, 0.45 + _rnd() * 0.5, r, _rnd() * 9));
    }
    if (_rnd() < dt * 7 * k) {
      final a = (_rnd() - 0.5) * 2.4, o = _pt(100, 100, 62, a);
      _s.add(_CfP(o.dx, o.dy, (_rnd() - 0.5) * 30, -(30 + _rnd() * 40), 0.7 + _rnd() * 0.8, 0, _rnd() * 9));
    }
    for (final q in _p) {
      q.age += dt;
      q.x += (q.vx + math.sin(q.age * 10 + q.sd) * 8 + ivx) * dt;
      q.y += (q.vy + ivy) * dt;
    }
    _p.removeWhere((q) => q.age >= q.life);
    for (final q in _s) {
      q.age += dt;
      q.x += (q.vx + math.sin(q.age * 6 + q.sd) * 12 + ivx) * dt;
      q.y += (q.vy + ivy) * dt;
    }
    _s.removeWhere((q) => q.age >= q.life);
    breatheU(2.4, 0.007);
  }

  @override
  void back(Canvas c, FramePalette p) {
    _glowS(c, const Offset(100, 96), 96, const Color(0xFFFF7A2A), 0.26 + _clamp(_f.x, 0, 1) * 0.3, true);
    for (final q in _p) {
      final u = q.age / q.life;
      _cfG.add(q.o, q.r * (1 - u * 0.75),
          u < 0.25 ? const Color(0xFFFFE9A8) : (u < 0.6 ? const Color(0xFFFF9A2E) : const Color(0xFFD8401A)), (1 - u) * 0.6);
    }
    _cfG.flush(c);
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (final q in _s) {
      _cfG.add(q.o, 3, const Color(0xFFFFC870), 1 - q.age / q.life);
    }
    _cfG.flush(c);
  }
}

// ───────────── Дым ─────────────
// Закрученные струйки поднимаются; действие — дымовое кольцо.

class _CfSmoke extends _CfSim {
  _CfSmoke() : super(const [Color(0xFFC9CCD4), Color(0xFF5A5E6C), Color(0xFF8A8E99)]) {
    ringWidth = 4;
  }
  final List<_CfP> _p = [];
  final List<_CfRg> _rg = [];
  double _acc = 0;

  @override
  void update(double dt) {
    if (up()) _rg.add(_CfRg(58, 1));
    _acc += dt * 28;
    while (_acc > 1) {
      _acc--;
      final a = _rnd() * _tau, o = _pt(100, 100, 60, a);
      final vx = (_rnd() - 0.5) * 6, vy = -(8 + _rnd() * 13), r = 6 + _rnd() * 5;
      _p.add(_CfP(o.dx, o.dy, vx, vy, 1.6 + _rnd() * 1.5, r, _rnd() * 9));
    }
    for (final q in _p) {
      q.age += dt;
      q.vx += math.sin(q.y * 0.07 + t * 0.9 + q.sd) * 16 * dt;
      q.x += (q.vx + ivx) * dt;
      q.y += (q.vy + ivy) * dt;
      q.r += 5 * dt;
    }
    _p.removeWhere((q) => q.age >= q.life);
    for (final q in _rg) {
      q.r += dt * (48 - (q.r - 58) * 0.95);
      q.a -= dt * 0.75;
    }
    _rg.removeWhere((q) => q.a <= 0);
    breatheU();
  }

  // 🔴 Светлая тема — своя палитра. Рамка бесплатная и стоит и на белом:
  // светлые клубы референса (#E4E7EE) на белом пропадают, остаётся одна
  // тёмная тень. На светлом — средне-тёмные холодные серые, та же структура
  // (тень + клуб + кольцо) и та же кривая прозрачности. Тёмная — как в JS.
  static const _shadeD = Color(0xFF20232C), _puffD = Color(0xFFE4E7EE), _ringD = Color(0xFFDADDE6);
  static const _shadeL = Color(0xFF4A505E), _puffL = Color(0xFF9AA1AF), _ringL = Color(0xFF8C93A2);

  @override
  void back(Canvas c, FramePalette p) {
    final shade = p.dark ? _shadeD : _shadeL, puff = p.dark ? _puffD : _puffL, ring = p.dark ? _ringD : _ringL;
    final ks = p.dark ? 0.2 : 0.12;
    for (final q in _p) {
      final a = math.sin(q.age / q.life * math.pi);
      _cfG.add(Offset(q.x + 1, q.y + 1.5), q.r * 1.8, shade, a * ks);
      _cfG.add(q.o, q.r * 1.7, puff, a * 0.27);
    }
    for (final q in _rg) {
      for (var i = 0; i < 30; i++) {
        final o = _pt(100, 100, q.r + math.sin(i * 2.3 + t * 3) * 1.5, i / 30 * _tau);
        _cfG.add(o, 9 + (q.r - 58) * 0.28, ring, q.a * 0.22);
      }
    }
    _cfG.flush(c, false);
  }
}

// ───────────── Мишки ─────────────
// Мишка выглядывает сверху, держится лапами, два медвежонка на кольце;
// действие — прячется, выныривает, машет, сердечко.

class _CfBear extends _CfSim {
  _CfBear() : super(const [Color(0xFFFFD27A), Color(0xFFE58A2E), Color(0xFF8A4B1E)]);
  final Spring _pop = Spring(), _tilt = Spring(), _wave = Spring();
  final List<Spring> _ears = [Spring(), Spring()];
  double _blink = 0, _nb = 1 + _rnd() * 3, _nt = 1 + _rnd() * 2, _duck = 0, _wt = 0;
  final List<_CfP> _hearts = [];

  static const _fur = Color(0xFF9C6B3F), _dark = Color(0xFF4A2F18), _face = Color(0xFFAD7A4A);
  static const _muzzle = Color(0xFFE8C9A0);
  static final Paint _head =
      Paint()..shader = _linG(const Offset(0, -27), const Offset(0, 27), const [Color(0xFFAD7A4A), Color(0xFF8A5A32)]);
  static final Path _claws = Path()
    ..moveTo(-4, -8)
    ..lineTo(-4, -4.5)
    ..moveTo(0, -8)
    ..lineTo(0, -4.5)
    ..moveTo(4, -8)
    ..lineTo(4, -4.5);

  @override
  void update(double dt) {
    if (up()) {
      _duck = 0.5;
      _pop.t = 36;
    }
    if (_duck > 0) {
      _duck -= dt;
      if (_duck <= 0) {
        _pop.t = 0;
        _wave.t = 1;
        _wt = 1.3;
        _hearts.add(_CfP(126, 24, 0, 0, 1.6, 0, _rnd() * 6));
      }
    }
    if (_wt > 0) {
      _wt -= dt;
      if (_wt <= 0) _wave.t = 0;
    }
    _pop.step(dt, 150, 9);
    _wave.step(dt, 120, 10);
    _nt -= dt;
    if (_nt <= 0) {
      _ears[_rnd() < 0.5 ? 0 : 1].v += 220;
      _nt = 1.4 + _rnd() * 3;
    }
    for (final e in _ears) {
      e.step(dt, 260, 9);
    }
    _nb -= dt;
    if (_nb <= 0) {
      _blink = 0.14;
      _nb = 2 + _rnd() * 3.5;
    }
    _blink = math.max(0, _blink - dt);
    _tilt.t = math.sin(t * 0.7) * 3.5;
    _tilt.step(dt, 40, 8);
    for (final h in _hearts) {
      h.age += dt;
    }
    _hearts.removeWhere((h) => h.age >= 1.6);
    breatheU();
  }

  @override
  void back(Canvas c, FramePalette p) {
    c.save();
    c.translate(100, 36 + _pop.x);
    c.rotate(_tilt.x * _deg);
    for (var i = 0; i < 2; i++) {
      final s = i == 0 ? -1.0 : 1.0;
      c.save();
      c.translate(s * 23, -19);
      c.rotate(s * _ears[i].x * _deg);
      _cfDisc(c, const Offset(0, -3), 11, _fur);
      _cfDisc(c, const Offset(0, -2), 6, _dark);
      c.restore();
    }
    c.drawOval(_ov(0, 0, 31, 27), _head);
    for (final s in const [-1.0, 1.0]) {
      _cfDisc(c, Offset(s * 19, -1), 4.6, const Color.fromRGBO(255, 140, 120, .38));
      if (_blink > 0) {
        c.drawLine(Offset(s * 11 - 3, -8), Offset(s * 11 + 3, -8), _cfPen(_dark, 1.6, StrokeCap.round));
      } else {
        _cfDisc(c, Offset(s * 11, -8), 3.1, _dark);
        _cfDisc(c, Offset(s * 11 - 1, -9), 1, _cfWhite);
      }
    }
    c.drawOval(_ov(0, 2, 10, 7), _cfInk(_muzzle));
    c.drawOval(_ov(0, -2.2, 4, 2.8), _cfInk(_dark));
    c.restore();
  }

  @override
  void front(Canvas c, FramePalette p) {
    final w = _clamp(_wave.x, 0, 1.2);
    for (final s in const [-1.0, 1.0]) {
      final q = _pt(100, 100, 58, s * 34 * _deg);
      c.save();
      c.translate(q.dx, q.dy + _pop.x * 0.08);
      if (s > 0) {
        c.translate(7 * w, -22 * w);
        c.rotate(math.sin(t * 14) * 0.4 * w);
      }
      c.rotate(s * 34 * _deg);
      c.drawOval(_ov(0, -2, 9.5, 7.5), _cfInk(_fur));
      c.drawPath(_claws, _cfPen(_dark, 1.3, StrokeCap.round));
      c.restore();
    }
    for (final s in const [-1.0, 1.0]) {
      final q = _pt(100, 100, 60, s * 128 * _deg);
      c.save();
      c.translate(q.dx, q.dy + math.sin(t * 2 + s) * 1.5);
      c.rotate(s * -0.25 + math.sin(t * 1.3 + s * 2) * 0.08);
      _cfDisc(c, const Offset(-5.5, -5.5), 3.3, _fur);
      _cfDisc(c, const Offset(5.5, -5.5), 3.3, _fur);
      _cfDisc(c, Offset.zero, 7.8, _face);
      c.drawOval(_ov(0, 2.2, 3.6, 2.6), _cfInk(_muzzle));
      _cfDisc(c, const Offset(-2.9, -1.2), 0.95, _dark);
      _cfDisc(c, const Offset(2.9, -1.2), 0.95, _dark);
      _cfDisc(c, const Offset(0, 1.2), 1.1, _dark);
      c.restore();
    }
    for (final h in _hearts) {
      final u = h.age / 1.6;
      c.save();
      c.translate(h.x + math.sin(h.age * 4 + h.sd) * 5, h.y - h.age * 22);
      c.drawPath(_heart(0.9 + math.min(1, h.age * 5) * 0.5), _cfInk(_op(const Color(0xFFFF7A8A), 1 - u * u)));
      c.restore();
    }
  }
}

// ───────────── Радуга ─────────────
// Семь колышущихся лент; действие — веер раскрывается и схлопывается.

class _CfRainbow extends _CfSim {
  final Spring _fan = Spring();
  final List<_CfP> _sp = [];
  static const _c = [
    Color(0xFFAF52DE), Color(0xFF007AFF), Color(0xFF00C7BE), Color(0xFF34C759),
    Color(0xFFFFCC00), Color(0xFFFF9500), Color(0xFFFF3B30),
  ];

  @override
  bool get drawRing => true;

  @override
  void update(double dt) {
    if (up()) {
      _fan.v += 9;
      for (var i = 0; i < 16; i++) {
        final a = _rnd() * _tau, o = _pt(100, 100, 64, a);
        _sp.add(_CfP(o.dx, o.dy, math.sin(a) * (30 + _rnd() * 50), -math.cos(a) * (30 + _rnd() * 50), 0.6 + _rnd() * 0.5)
          ..c = _c[i % 7]);
      }
    }
    _fan.step(dt, 90, 6);
    for (final q in _sp) {
      q.age += dt;
      q.vx *= 1 - dt * 2;
      q.vy *= 1 - dt * 2;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
    }
    _sp.removeWhere((q) => q.age >= q.life);
    breatheU();
  }

  @override
  void back(Canvas c, FramePalette p) => _glowS(c, _cfC, 92, _cfWhite, 0.1, true);

  @override
  void paintRing(Canvas c, [List<Color>? colors, double opacity = 1]) {
    final f = math.max(-0.3, _fan.x);
    for (var i = 0; i < 7; i++) {
      final path = _blob(100, 100, 56.6 + i * 1.6 + f * i * 1.4,
          (a) => 1.2 * math.sin(3 * a + t * 1.8 - i * 0.45) + 0.8 * math.sin(5 * a - t * 2.4 + i * 0.3));
      c.drawPath(path, _cfPen(_c[i], 1.75));
    }
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (final q in _sp) {
      final u = 1 - q.age / q.life;
      _glowS(c, q.o, 5, q.c, u, true);
      _glint(c, q.o, 2.6 * u, u);
    }
  }
}

// ───────────── Бабочки ─────────────
// Четыре бабочки летают за целью с инерцией и присаживаются на кольцо; действие — спугнуть.

class _CfBfly {
  _CfBfly(this.x, this.y, this.a, this.w, this.ph, this.col, this.nr);
  double x, y, a, nr, vx = 0, vy = 0, hd = 0, rest = 0;
  final double w, ph;
  final Color col;
}

class _CfButterfly extends _CfSim {
  _CfButterfly() : super(const [Color(0xFFFF6FD8), Color(0xFF7AC7FF), Color(0xFFFFD166)]) {
    ringWidth = 3;
    for (var i = 0; i < 4; i++) {
      final a = i / 4 * _tau + _rnd(), q = _pt(100, 100, 70, a);
      _b.add(_CfBfly(q.dx, q.dy, a, (0.45 + _rnd() * 0.3) * (i.isOdd ? -1 : 1), _rnd() * 9, _cols[i], 1.5 + _rnd() * 5));
    }
  }
  static const _cols = [Color(0xFFFF6FD8), Color(0xFF7AC7FF), Color(0xFFFFD166), Color(0xFFB69CFF)];
  double _sc = 0;
  final List<_CfBfly> _b = [];
  static final Path _w1 = (Path()..addOval(_ov(0, 0, 5.6, 4.6))).transform(_cfAffine(-0.4, 5, -2.6));
  static final Path _w2 = (Path()..addOval(_ov(0, 0, 3.7, 3.1))).transform(_cfAffine(0.5, 4, 3.2));
  static final Path _ant = Path()
    ..moveTo(0, -4)
    ..lineTo(-2, -7.5)
    ..moveTo(0, -4)
    ..lineTo(2, -7.5);
  static const _ink = Color(0xFF2A1A30);

  @override
  void update(double dt) {
    if (up()) {
      _sc = 0.9;
      for (final b in _b) {
        b.rest = 0;
      }
    }
    _sc = math.max(0, _sc - dt);
    for (final b in _b) {
      b.nr -= dt;
      if (b.nr <= 0 && b.rest <= 0) {
        b.rest = 1.5 + _rnd() * 1.8;
        b.nr = 4 + _rnd() * 5;
      }
      if (b.rest > 0) {
        b.rest -= dt;
      } else {
        b.a += b.w * dt;
      }
      final r = _sc > 0 ? 94.0 : (b.rest > 0 ? 61.0 : 71 + math.sin(t * 1.3 + b.ph) * 8);
      final tg = _pt(100, 100, r, b.a + (b.rest > 0 ? 0 : math.sin(t * 0.9 + b.ph) * 0.25));
      b.vx += ((tg.dx - b.x) * 24 - b.vx * 5) * dt;
      b.vy += ((tg.dy - b.y) * 24 - b.vy * 5 + (b.rest > 0 ? 0 : math.sin(t * 9 + b.ph) * 40)) * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      if (b.vx * b.vx + b.vy * b.vy > 16) {
        var d = math.atan2(b.vy, b.vx) - b.hd;
        d = math.atan2(math.sin(d), math.cos(d));
        b.hd += d * math.min(1, dt * 8);
      }
    }
    breatheU();
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (final b in _b) {
      final flap = b.rest > 0 && _sc <= 0
          ? 0.55 + 0.45 * math.sin(t * 3 + b.ph)
          : math.sin(t * 17 + b.ph).abs();
      final soft = _op(b.col, 0.8);
      c.save();
      c.translate(b.x, b.y);
      c.rotate(b.hd + math.pi / 2);
      for (final s in const [-1.0, 1.0]) {
        c.save();
        c.scale(s * (0.22 + 0.78 * flap), 1);
        c.drawPath(_w1, _cfInk(b.col));
        c.drawPath(_w2, _cfInk(soft));
        _cfDisc(c, const Offset(6, -3), 1.3, const Color.fromRGBO(255, 255, 255, .75));
        c.restore();
      }
      c.drawLine(const Offset(0, -4), const Offset(0, 4.5), _cfPen(_ink, 1.5, StrokeCap.round));
      c.drawPath(_ant, _cfPen(_ink, 0.6, StrokeCap.round));
      c.restore();
    }
  }
}

// ───────────── Комета ─────────────
// Наклонная орбита, хвост из частиц уходит ЗА портрет; действие — разгон.

class _CfTr {
  _CfTr(this.th);
  final double th;
  double age = 0;
}

class _CfComet extends _CfSim {
  _CfComet() : super(const [Color(0xFF7FE0FF), Color(0xFF7A5CFF), Color(0xFFFF9ACB)]) {
    ringWidth = 5;
    _lastS = _th;
  }
  double _th = _rnd() * _tau, _tl = -18 * _deg, _lastS = 0;
  final Spring _v = Spring(1.5);
  final List<_CfTr> _trail = [];
  final List<_CfP> _sp = [];
  final List<(double, double, double)> _stars =
      List<(double, double, double)>.generate(10, (_) => (_rnd() * _tau, 70 + _rnd() * 24, _rnd() * 9));

  Offset _e(double th, [double k = 1]) {
    final x = 86 * k * math.cos(th), y = 24 * k * math.sin(th), co = math.cos(_tl), si = math.sin(_tl);
    return Offset(100 + x * co - y * si, 100 + x * si + y * co);
  }

  @override
  void update(double dt) {
    edge();
    _v.t = active ? 5.4 : 1.5;
    _v.step(dt, 30, 8);
    final d = _v.x * dt;
    _tl = (-18 + math.sin(t * 0.4) * 5) * _deg;
    final th0 = _th;
    _th += d;
    final n = samples60(dt);
    for (var j = 1; j <= n; j++) {
      final e = th0 + d * j / n;
      _trail
        ..add(_CfTr(_lastS + (e - _lastS) * 0.5))
        ..add(_CfTr(e));
      _lastS = e;
    }
    for (final q in _trail) {
      q.age += dt;
    }
    var k = 0;
    while (k < _trail.length && _trail[k].age > 0.85) {
      k++;
    }
    if (k > 0) _trail.removeRange(0, k);
    if (_rnd() < dt * (6 + _v.x * 5)) {
      final h = _e(_th);
      _sp.add(_CfP(h.dx, h.dy, (_rnd() - 0.5) * 26, (_rnd() - 0.5) * 26, 0.5 + _rnd() * 0.5)..f = math.sin(_th) > 0);
    }
    for (final q in _sp) {
      q.age += dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
    }
    _sp.removeWhere((q) => q.age >= q.life);
    breatheU();
  }

  void _arc(Canvas c, double a0, double a1, double op) {
    final path = Path();
    for (var k = 0; k <= 24; k++) {
      final q = _e(a0 + (a1 - a0) * k / 24);
      k == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    c.drawPath(path, _cfPen(_op(const Color(0xFFB69CFF), op), 1.1));
  }

  void _layer(Canvas c, bool front) {
    for (final q in _trail) {
      if ((math.sin(q.th) > 0) != front) continue;
      final u = q.age / 0.85;
      final col = u < 0.35 ? const Color(0xFFCFF4FF) : (u < 0.7 ? const Color(0xFF7FB8FF) : const Color(0xFF9A7CFF));
      _cfG.add(_e(q.th, 1 + u * 0.02), 2 + (1 - u) * 6.5, col, (1 - u) * 0.55);
    }
    _cfG.flush(c);
    for (final q in _sp) {
      if (q.f != front) continue;
      final u = 1 - q.age / q.life;
      _glint(c, q.o, 2.4 * u, u);
    }
    if ((math.sin(_th) > 0) == front) {
      final h = _e(_th);
      _glowS(c, h, 16, const Color(0xFF9FE8FF), 0.95, true);
      _cfDisc(c, h, 3.3, _cfWhite);
    }
  }

  @override
  void back(Canvas c, FramePalette p) {
    for (final s in _stars) {
      _glint(c, _pt(100, 100, s.$2, s.$1), 2.2, 0.15 + 0.55 * math.max(0, math.sin(t * 1.7 + s.$3)));
    }
    _arc(c, math.pi, _tau, 0.22);
    _layer(c, false);
  }

  @override
  void front(Canvas c, FramePalette p) {
    _arc(c, 0, math.pi, 0.3);
    _layer(c, true);
  }
}

// ───────────── Сакура ─────────────
// Ветка с цветами на кольце, лепестки падают и кружатся; действие — порыв ветра.

class _CfBloom {
  _CfBloom(this.a, this.big, this.r);
  final double a, r;
  final bool big;
  final Spring s = Spring(1);
}

class _CfSakura extends _CfSim {
  _CfSakura() : super(const [Color(0xFFFFD1E3), Color(0xFFFF8FB8), Color(0xFFE85A8F)]) {
    ringWidth = 5;
    const deg = [-64.0, -40.0, -14.0, 20.0, 46.0];
    for (var i = 0; i < 5; i++) {
      _fl.add(_CfBloom(deg[i] * _deg, i % 2 == 0, _rnd() * 2));
    }
  }
  final Spring _wind = Spring();
  final List<_CfP> _p = [];
  final List<_CfBloom> _fl = [];
  double _acc = 0;
  static const Rect _branch = Rect.fromLTWH(37.5, 37.5, 125, 125);

  void _petal(double x, double y, double k) {
    _p.add(_CfP(x, y, (_rnd() - 0.5) * 14 * k, 12 + _rnd() * 14, 0)
      ..rot = _rnd() * _tau
      ..vr = (_rnd() - 0.5) * 6
      ..sd = _rnd() * 9
      ..f = _rnd() < 0.4
      ..c = _rnd() < 0.5 ? const Color(0xFFFFC2D9) : const Color(0xFFFF9CC0));
  }

  @override
  void update(double dt) {
    if (up()) {
      _wind.v += 210;
      for (final f in _fl) {
        f.s.v += 7;
        final q = _pt(100, 100, 63, f.a);
        _petal(q.dx, q.dy, 3);
        _petal(q.dx, q.dy, 3);
      }
    }
    _wind.step(dt, 12, 2.6);
    for (final f in _fl) {
      f.s.step(dt, 180, 7);
    }
    _acc += dt * 5;
    while (_acc > 1) {
      _acc--;
      _petal(15 + _rnd() * 170, 8 + _rnd() * 20, 1);
    }
    for (final q in _p) {
      q.age += dt;
      q.x += (q.vx + _wind.x * 0.55 + math.sin(q.age * 2.2 + q.sd) * 12 + ivx) * dt;
      q.y += (q.vy + math.cos(q.age * 2.2 + q.sd) * 5 + ivy) * dt;
      q.rot += (q.vr + _wind.x * 0.05) * dt;
    }
    _p.removeWhere((q) => !(q.y < 196 && q.x > -6 && q.x < 206));
    breatheU();
  }

  void _drawP(Canvas c, bool front) {
    for (final q in _p) {
      if (q.f != front) continue;
      final a = math.min(1.0, q.age * 3) * math.min(1.0, (196 - q.y) / 30);
      if (a <= 0) continue;
      c.save();
      c.translate(q.x, q.y);
      c.rotate(q.rot);
      c.scale(1, 0.45 + 0.55 * math.sin(q.age * 3 + q.sd).abs());
      c.drawOval(_ov(0, 0, 3.4, 2.1), _cfInk(_op(q.c, a)));
      c.restore();
    }
  }

  @override
  void back(Canvas c, FramePalette p) {
    _glowS(c, _cfC, 92, const Color(0xFFFF8FB8), 0.16, true);
    _drawP(c, false);
  }

  @override
  void front(Canvas c, FramePalette p) {
    c.drawArc(_branch, (-72 - 90) * _deg, 126 * _deg, false, _cfPen(const Color(0xFF6B3A2A), 2.2, StrokeCap.round));
    for (final f in _fl) {
      final q = _pt(100, 100, 63.5, f.a), R = (f.big ? 4.6 : 3.4) * f.s.x;
      c.save();
      c.translate(q.dx, q.dy);
      c.rotate(f.r + math.sin(t * 1.2 + f.a * 3) * 0.12);
      for (var i = 0; i < 5; i++) {
        c.rotate(_tau / 5);
        c.drawOval(_ov(0, -R, R * 0.72, R), _cfInk(i.isOdd ? const Color(0xFFFFD1E3) : const Color(0xFFFFBFD8)));
      }
      _cfDisc(c, Offset.zero, R * 0.42, const Color(0xFFFFD36B));
      c.restore();
    }
    _drawP(c, true);
  }
}

// ───────────── Феникс ─────────────
// Крылья из перьев-языков, взмах идёт по перьям цепочкой, хвост; действие — расправить крылья.

class _CfFeather {
  _CfFeather(double L, double w)
      : path = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(L * 0.45, -w, L, 0)
          ..quadraticBezierTo(L * 0.5, w * 0.55, 0, 0)
          ..close(),
        paint = Paint()
          ..shader = _linG(Offset.zero, Offset(L, 0), const [Color(0xFFE0352B), Color(0xFFFF8A3D), Color(0xFFFFE9A8)],
              const [0, 0.55, 1]),
        b = Offset(L * 0.9, -w * 0.12);
  final Path path;
  final Paint paint;
  final Offset b;

  void draw(Canvas c) {
    c.drawPath(path, paint);
    c.drawLine(const Offset(2, 0), b, _cfPen(const Color.fromRGBO(255, 240, 200, .5), 0.7));
  }
}

class _CfPhoenix extends _CfSim {
  _CfPhoenix() : super(const [Color(0xFFFFE08A), Color(0xFFFF8A3D), Color(0xFFE0352B)]) {
    ringWidth = 5;
  }
  final Spring _sp = Spring();
  final List<Spring> _f = List<Spring>.generate(9, (_) => Spring());
  final List<_CfP> _p = [];
  double _fl = 0;
  static final List<_CfFeather> _wing = List<_CfFeather>.generate(9, (i) => _CfFeather(24 + i * 5.6, 7 + i * 0.5));
  static final List<_CfFeather> _tail = [_CfFeather(36, 6.5), _CfFeather(27, 6.5)];
  static const _tailA = [0.95, 1.32];
  static final _CfFeather _crestS = _CfFeather(12, 4), _crestL = _CfFeather(17, 4);

  double _ang(int i) => -0.55 + i * 0.22 + _f[i].x * (0.5 + i * 0.1);
  double _len(int i) => 24 + i * 5.6;

  void _em(double x, double y, double k) =>
      _p.add(_CfP(x, y, (_rnd() - 0.5) * 30 * k, -(14 + _rnd() * 30) * k, 0.8 + _rnd(), 0, _rnd() * 9));

  @override
  void update(double dt) {
    if (up()) {
      _sp.v += 7;
      _fl = 1;
      for (var i = 0; i < 26; i++) {
        _em(100 + (_rnd() < 0.5 ? -1 : 1) * (60 + _rnd() * 30), 60 + _rnd() * 60, 2);
      }
    }
    _sp.step(dt, 36, 4.5);
    _fl = math.max(0, _fl - dt * 2);
    _f[0].t = math.sin(t * 2.2) * 0.11 + _clamp(_sp.x, -0.5, 1.5) * 0.35;
    for (var i = 1; i < 9; i++) {
      _f[i].t = _f[i - 1].x;
    }
    for (final f in _f) {
      f.step(dt, 120, 10);
    }
    if (_rnd() < dt * 12) {
      final s = _rnd() < 0.5 ? -1 : 1, i = 4 + (_rnd() * 5).floor(), a = _ang(i), L = _len(i);
      _em(100 + s * (40 + math.cos(a) * L), 110 - math.sin(a) * L, 1);
    }
    for (final q in _p) {
      q.age += dt;
      q.x += (q.vx + math.sin(q.age * 5 + q.sd) * 9 + ivx) * dt;
      q.y += (q.vy + ivy) * dt;
    }
    _p.removeWhere((q) => q.age >= q.life);
    breatheU(1.6, 0.006, -_f[0].x * 5);
  }

  @override
  void back(Canvas c, FramePalette p) {
    _glowS(c, _cfC, 98, const Color(0xFFFF6A2A), 0.26 + _fl * 0.4, true);
    for (final s in const [-1.0, 1.0]) {
      for (var i = 0; i < 2; i++) {
        c.save();
        c.translate(100 + s * 26, 148 + bdy);
        c.rotate(math.pi / 2 - s * (_tailA[i] + math.sin(t * 1.6 + i * 1.3) * 0.08 + _f[3].x * 0.25));
        _tail[i].draw(c);
        c.restore();
      }
    }
    for (final s in const [-1.0, 1.0]) {
      for (var i = 0; i < 9; i++) {
        c.save();
        c.translate(100 + s * 40, 110 + bdy);
        c.scale(s, 1);
        c.rotate(-_ang(i));
        _wing[i].draw(c);
        c.restore();
      }
    }
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(100, 44 + bdy);
      c.rotate(-math.pi / 2 + (i - 1) * 0.4 + math.sin(t * 2.2 + i) * 0.08);
      (i == 1 ? _crestL : _crestS).draw(c);
      c.restore();
    }
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (final q in _p) {
      final u = q.age / q.life;
      _cfG.add(q.o, 4, const Color(0xFFFFB45A), u < 0.1 ? u * 10 : 1 - u);
    }
    _cfG.flush(c);
  }
}

// ───────────── Иней ─────────────
// Кристаллы растут пружиной, морозная виньетка на фото; действие — раскалываются и отрастают.

class _CfCry {
  _CfCry(this.a, this.len, this.w);
  final double a, len, w;
  final Spring s = Spring(0)..t = 1;
  double d = 0;

  // Кэш формы: длина меняется только пока кристалл растёт.
  double _l = -1;
  late Path path, vein;
  late Paint fill;

  void shape(double L) {
    if ((L - _l).abs() < 0.05) return;
    _l = L;
    path = Path()
      ..moveTo(-w * 0.6, 0)
      ..lineTo(-w, -L * 0.35)
      ..lineTo(0, -L)
      ..lineTo(w, -L * 0.35)
      ..lineTo(w * 0.6, 0)
      ..close();
    vein = Path()
      ..moveTo(0, 0)
      ..lineTo(0, -L);
    if (len > 17) {
      vein
        ..moveTo(0, -L * 0.55)
        ..lineTo(-L * 0.3, -L * 0.8)
        ..moveTo(0, -L * 0.55)
        ..lineTo(L * 0.3, -L * 0.8);
    }
    fill = Paint()
      ..shader = _linG(Offset.zero, Offset(0, -L), const [Color.fromRGBO(160, 215, 255, .95), _cfWhite]);
  }
}

class _CfFrost extends _CfSim {
  _CfFrost() : super(const [Color(0xFFEAF8FF), Color(0xFF8FD0FF), Color(0xFF5A8CFF)]) {
    ringWidth = 6;
  }
  final List<_CfP> _sh = [];
  final List<_CfCry> _sp = List<_CfCry>.generate(
      20, (i) => _CfCry(i / 20 * _tau + (_rnd() - 0.5) * 0.12, (i.isOdd ? 9 : 17) + _rnd() * 9, 2.6 + _rnd() * 2.2));
  final List<(double, double, double)> _gl =
      List<(double, double, double)>.generate(9, (_) => (_rnd() * _tau, 50 + _rnd() * 34, _rnd() * 9));
  static final Paint _vig = Paint()
    ..shader = ui.Gradient.radial(
        _cfC, 52, const [Color.fromRGBO(220, 240, 255, 0), Color.fromRGBO(220, 240, 255, .46)], const [34 / 52, 1]);
  static final Path _shard = Path()
    ..moveTo(0, -1)
    ..lineTo(0.7, 0.6)
    ..lineTo(-0.7, 0.6)
    ..close();

  @override
  bool get hasMid => true;

  @override
  void update(double dt) {
    if (up()) {
      for (final k in _sp) {
        final tip = _pt(100, 100, 59 + k.len * 0.7, k.a), dx = math.sin(k.a), dy = -math.cos(k.a);
        for (var j = 0; j < 2; j++) {
          final vx = dx * (50 + _rnd() * 90) + (_rnd() - 0.5) * 40, vy = dy * (50 + _rnd() * 90) - 20;
          _sh.add(_CfP(tip.dx, tip.dy, vx, vy, 0.7 + _rnd() * 0.6)
            ..rot = _rnd() * _tau
            ..vr = (_rnd() - 0.5) * 14
            ..s = 2 + _rnd() * 3);
        }
        k.s
          ..x = 0
          ..v = 0
          ..t = 0;
        k.d = 0.35 + _rnd() * 0.7;
      }
    }
    for (final k in _sp) {
      if (k.d > 0) {
        k.d -= dt;
        if (k.d <= 0) k.s.t = 1;
      }
      k.s.step(dt, 90, 7);
    }
    for (final q in _sh) {
      q.age += dt;
      q.vy += 230 * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      q.rot += q.vr * dt;
    }
    _sh.removeWhere((q) => q.age >= q.life);
    breatheU(1.2, 0.005);
  }

  @override
  void back(Canvas c, FramePalette p) {
    _glowS(c, _cfC, 92, const Color(0xFF8FD8FF), 0.2, true);
    for (final k in _sp) {
      final L = k.len * math.max(0, k.s.x);
      if (L < 0.5) continue;
      k.shape(L);
      c.save();
      c.translate(100, 100);
      c.rotate(k.a);
      c.translate(0, -59);
      c.drawPath(k.path, k.fill);
      c.drawPath(k.path, _cfPen(const Color.fromRGBO(255, 255, 255, .75), 0.6));
      c.drawPath(k.vein, _cfPen(const Color.fromRGBO(90, 150, 230, .55), 0.6));
      c.restore();
    }
  }

  @override
  void mid(Canvas c, FramePalette p) {
    c.drawCircle(_cfC, 52, _vig);
    c.drawCircle(_cfC, 55.4, _cfPen(const Color.fromRGBO(255, 255, 255, .85), 0.8));
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (final s in _gl) {
      _glint(c, _pt(100, 100, s.$2, s.$1), 3, math.max(0, math.sin(t * 2.1 + s.$3)) * 0.9);
    }
    for (final q in _sh) {
      if (q.s <= 0) continue;
      c.save();
      c.translate(q.x, q.y);
      c.rotate(q.rot);
      c.scale(q.s);
      c.drawPath(_shard, _cfInk(_op(const Color(0xFFDDF2FF), 1 - q.age / q.life)));
      c.restore();
    }
  }
}

// ───────────── Электро ─────────────
// Дуги бегут по кольцу; действие — молнии наружу и встряска портрета.

class _CfArc {
  _CfArc(this.a, this.span, this.v);
  double a, tm = 0;
  final double span, v;
  Path? path;
}

class _CfBolt {
  _CfBolt(this.a, this.life);
  final double a;
  double life, tm = 0;
  Path? path;
}

class _CfElectric extends _CfSim {
  double _flash = 0;
  final Spring _shake = Spring();
  List<_CfBolt> _bolts = [];
  final List<_CfP> _sp = [];
  final List<_CfArc> _arcs = List<_CfArc>.generate(
      3, (i) => _CfArc(i * 2.1 + _rnd(), 0.9 + _rnd() * 0.6, (i.isOdd ? -1 : 1) * (0.7 + _rnd() * 0.6)));
  static final ui.Gradient _sh = _linG(const Offset(42, 42), const Offset(158, 158),
      const [Color(0xFF5CF2FF), Color(0xFF4A6BFF), Color(0xFFB36BFF)], const [0, 0.5, 1]);
  final Paint _gp = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..shader = _sh;
  final Paint _z = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.miter;

  @override
  bool get drawRing => true;

  Path _boltPath(double a) {
    final L = 26 + _rnd() * 18, path = Path();
    var off = 0.0;
    for (var k = 0; k <= 6; k++) {
      if (k > 0) off += (_rnd() - 0.5) * 0.16;
      final q = _pt(100, 100, 60 + L * k / 6, a + off);
      k == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    return path;
  }

  @override
  void update(double dt) {
    if (up()) {
      _flash = 1;
      _shake.v += 70;
      _bolts = List<_CfBolt>.generate(8, (i) => _CfBolt(i / 8 * _tau + _rnd() * 0.5, 0.22 + _rnd() * 0.2));
    }
    _flash = math.max(0, _flash - dt * 3.2);
    _shake.step(dt, 320, 12);
    for (final a in _arcs) {
      a.a += a.v * dt;
      a.tm -= dt;
      if (a.tm <= 0) {
        // jag(a, span, 12, 10): концы на кольце, середина дрожит ±5.
        final path = Path();
        Offset end = Offset.zero;
        for (var k = 0; k <= 12; k++) {
          final q = _pt(100, 100, 58 + (k == 0 || k == 12 ? 0 : (_rnd() - 0.5) * 10), a.a + a.span * k / 12);
          k == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
          if (k == (a.v > 0 ? 12 : 0)) end = q;
        }
        a.path = path;
        a.tm = 0.05 + _rnd() * 0.06;
        if (_rnd() < 0.35) _sp.add(_CfP(end.dx, end.dy, (_rnd() - 0.5) * 60, (_rnd() - 0.5) * 60, 0.25 + _rnd() * 0.3));
      }
    }
    for (final b in _bolts) {
      b.life -= dt;
      b.tm -= dt;
      if (b.tm <= 0) {
        b.path = _boltPath(b.a);
        b.tm = 0.04;
      }
    }
    _bolts.removeWhere((b) => b.life <= 0);
    for (final q in _sp) {
      q.age += dt;
      q.vy += 160 * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
    }
    _sp.removeWhere((q) => q.age >= q.life);
    bs(1 + _flash * 0.025 + math.sin(t * 1.6) * 0.005, _shake.x * 0.12);
  }

  @override
  void back(Canvas c, FramePalette p) => _glowS(c, _cfC, 94, const Color(0xFF3DA5FF), 0.18 + _flash * 0.5, true);

  @override
  void paintRing(Canvas c, [List<Color>? colors, double opacity = 1]) {
    c.drawCircle(_cfC, 58, _cfPen(const Color(0xFF141B3A), 8));
    _gp.color = Color.fromRGBO(255, 255, 255, _clamp(0.65 + 0.35 * math.sin(t * 7), 0, 1));
    c.drawCircle(_cfC, 58, _gp);
  }

  void _zap(Canvas c, Path? path, double k) {
    if (path == null || k <= 0) return;
    k = _clamp(k, 0, 1);
    _z
      ..strokeWidth = 6.5
      ..color = Color.fromRGBO(92, 242, 255, 0.22 * k);
    c.drawPath(path, _z);
    _z
      ..strokeWidth = 2.2
      ..color = Color.fromRGBO(189, 246, 255, 0.95 * k);
    c.drawPath(path, _z);
    _z
      ..strokeWidth = 0.9
      ..color = Color.fromRGBO(255, 255, 255, k);
    c.drawPath(path, _z);
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (final a in _arcs) {
      _zap(c, a.path, 1);
    }
    for (final b in _bolts) {
      _zap(c, b.path, math.min(1, b.life * 6));
    }
    for (final q in _sp) {
      _cfG.add(q.o, 4, const Color(0xFFBDF6FF), 1 - q.age / q.life);
    }
    _cfG.flush(c);
  }
}

// ───────────── Призма ─────────────
// Гранёное стекло, белый луч входит слева и выходит спектром; действие — луч качается, веер шире.

class _CfPrism extends _CfSim {
  double _rot = _rnd() * 9;
  final Spring _ang = Spring(), _spread = Spring(1);
  static const _c = [
    Color(0xFFFF3B30), Color(0xFFFF9500), Color(0xFFFFCC00), Color(0xFF34C759),
    Color(0xFF00C7BE), Color(0xFF007AFF), Color(0xFFAF52DE),
  ];
  // 🔴 Светлая тема. Стекло референса — белое и почти белое, лучи сложением
  // света: на белом от рамки оставалась одна волосяная линия. На светлом грани
  // и луч — холодным серо-синим, спектр — обычным наложением. Тёмная — как в JS.
  // `paintRing` палитру не получает, поэтому тема запоминается в [back]
  // (он рисуется раньше кольца); без [back] (режим «одно кольцо») — тёмная.
  bool _dark = true;

  static Paint _beam(int rgb, double al, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = w
    ..shader = _linG(const Offset(6, 0), const Offset(30, 0), [_hex(rgb, 0), _hex(rgb, al)]);
  static final Paint _beamW = _beam(0xFFFFFF, 0.2, 7), _beamN = _beam(0xFFFFFF, 0.95, 2);
  static final Paint _beamWL = _beam(0x78829B, 0.25, 7), _beamNL = _beam(0x78829B, 0.85, 2);

  static List<Paint> _rayPaints(BlendMode mode) => [
        for (final col in _c)
          Paint()
            ..blendMode = mode
            ..shader = _linG(Offset.zero, const Offset(39, 0), [_op(col, 0.9), _op(col, 0.7), _op(col, 0)], const [0, 0.6, 1]),
      ];

  /// Лучи спектра в своей системе: из (0, 0) вдоль оси x на 39.
  static final List<Paint> _rays = _rayPaints(BlendMode.plus), _raysL = _rayPaints(BlendMode.srcOver);

  /// 18 граней при повороте 0; поворот — холстом.
  static final List<Path> _facets = List<Path>.generate(18, (i) {
    final a0 = i / 18 * _tau, a1 = (i + 1) / 18 * _tau;
    final p0 = _pt(100, 100, 54.4, a0), p1 = _pt(100, 100, 62.4, a0);
    final p2 = _pt(100, 100, 62.4, a1), p3 = _pt(100, 100, 54.4, a1);
    return Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
  });
  static final Paint _conic = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3
    ..color = const Color.fromRGBO(255, 255, 255, .75)
    ..shader = ui.Gradient.sweep(_cfC, [..._c, _c[0]], List<double>.generate(8, (i) => i / 7));

  @override
  bool get drawRing => true;

  @override
  void update(double dt) {
    if (up()) {
      _ang.v += 3.5;
      _spread.v += 6;
    }
    _ang.t = math.sin(t * 0.5) * 0.18;
    _ang.step(dt, 30, 4);
    _spread.step(dt, 60, 6);
    _rot += dt * 0.25;
    breatheU();
  }

  @override
  void back(Canvas c, FramePalette p) {
    _dark = p.dark;
    final a = _ang.x, rays = _dark ? _rays : _raysL;
    c.drawLine(Offset(6, 100 + a * 60), const Offset(43, 100), _dark ? _beamW : _beamWL);
    c.drawLine(Offset(6, 100 + a * 60), const Offset(43, 100), _dark ? _beamN : _beamNL);
    final sp = math.max(0.2, _spread.x);
    for (var i = 0; i < 7; i++) {
      final g = -a * 0.6 + (i - 3) * 0.085 * sp, co = math.cos(g), si = math.sin(g);
      // Треугольник (157,100) → (e.x, e.y ∓ 2.4) в системе, повёрнутой на g.
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(39 - 2.4 * si, -2.4 * co)
        ..lineTo(39 + 2.4 * si, 2.4 * co)
        ..close();
      c.save();
      c.translate(157, 100);
      c.rotate(g);
      c.drawPath(path, rays[i]);
      c.restore();
    }
    if (!_dark) return; // белое сложением на белом ничего не даёт
    _glowS(c, const Offset(157, 100), 10, _cfWhite, 0.6, true);
    _glowS(c, const Offset(43, 100), 8, _cfWhite, 0.5, true);
  }

  @override
  void paintRing(Canvas c, [List<Color>? colors, double opacity = 1]) {
    c.save();
    _cfSpin(c, _rot * 0.3);
    for (var i = 0; i < 18; i++) {
      final b = math.sin(i * 1.9 + _rot * 3).abs();
      if (_dark) {
        c.drawPath(_facets[i], _cfInk(Color.fromRGBO(215, 232, 255, 0.14 + 0.55 * b)));
        c.drawPath(_facets[i], _cfPen(const Color.fromRGBO(255, 255, 255, .55), 0.5));
      } else {
        c.drawPath(_facets[i], _cfInk(Color.fromRGBO(120, 140, 180, 0.10 + 0.32 * b)));
        c.drawPath(_facets[i], _cfPen(const Color.fromRGBO(90, 105, 140, .5), 0.5));
      }
    }
    c.restore();
    c.save();
    _cfSpin(c, _rot);
    c.drawCircle(_cfC, 58.4, _conic);
    c.restore();
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (var i = 0; i < 3; i++) {
      _glint(c, _pt(100, 100, 58.4, _rot * 0.3 + i * 2.2 + 0.4), 4, 0.4 + 0.6 * math.sin(t * 1.7 + i * 2).abs());
    }
  }
}
