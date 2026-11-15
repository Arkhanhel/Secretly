// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../../profile_fx.dart';

// Переделанные старые обложки (13.11.2026), дизайн-референс fx-engine.js + fx-covers-2.js.
//
// Формулы, константы пружин и цвета тёмной темы — один в один с референсом.
// Что сделано иначе и почему:
// • Сотни мелких свечений и точек (костёр, салют, галактика, звёзды) идут
//   пакетом через drawRawAtlas: белый спрайт × цвет точки (BlendMode.modulate).
//   Картинка та же, что у спрайта референса, но один вызов вместо сотен.
// • Первый кадр «прогревается» (warmSecs): неподвижная плитка выбора рисует
//   один кадр, и без прогрева костёр, салют и радуга были бы пустым небом.
// • Смена размера (поворот, окно ПК) не пересоздаёт сцену, а растягивает её —
//   иначе звёзды «мигали» бы на каждом кадре перетаскивания края окна.
// • Светлая тема — только у дневных сцен (волны, иконки, золотая дымка,
//   наши иконки, мишки, радуга). Ночные сцены остаются ночью в обеих темах.

/// Сцена набора → симуляция; null — не из этого файла.
CoverSim? _createClassicCover(ProfileCoverStyle style) => switch (style) {
      ProfileCoverStyle.classicSpace => _CSpace(),
      ProfileCoverStyle.classicWaves => _CWaves(),
      ProfileCoverStyle.classicMeteors => _CMeteors(),
      ProfileCoverStyle.classicMarks => _CMarks(),
      ProfileCoverStyle.classicGoldHaze => _CGoldHaze(),
      ProfileCoverStyle.classicLogos => _CLogos(),
      ProfileCoverStyle.classicFire => _CFire(),
      ProfileCoverStyle.classicFog => _CFog(),
      ProfileCoverStyle.classicBears => _CBears(),
      ProfileCoverStyle.classicRainbow => _CRainbow(),
      ProfileCoverStyle.classicFireflies => _CFireflies(),
      ProfileCoverStyle.classicFireworks => _CFireworks(),
      ProfileCoverStyle.classicGoldWillow => _CGoldWillow(),
      ProfileCoverStyle.classicReef => _CReef(),
      ProfileCoverStyle.classicGalaxy => _CGalaxy(),
      ProfileCoverStyle.classicAuroraSky => _CAuroraSky(),
      _ => null,
    };

// ───────────── Общее ─────────────

int _clArgb(int rgb, double a) => ((255 * _clamp(a, 0, 1)).round() << 24) | (rgb & 0xFFFFFF);
Color _cla(int rgb, double a) => Color(_clArgb(rgb, a));

/// Результат [_clPush] — без замыкания на каждую частицу.
double _clKx = 0, _clKy = 0;

/// JS `push(tap, x, y, radius, force)`: true и толчок в [_clKx]/[_clKy].
bool _clPush(Offset? tap, double x, double y, double radius, double force) {
  if (tap == null) return false;
  final dx = x - tap.dx, dy = y - tap.dy, d = math.sqrt(dx * dx + dy * dy);
  if (d >= radius) return false;
  final k = (1 - d / radius) * force / (d == 0 ? 1 : d);
  _clKx = dx * k;
  _clKy = dy * k;
  return true;
}

double _clSign(double d) => d < 0 ? -1 : 1;

/// JS `stars(w, h, n, k)`: тройки x, y, фаза.
Float32List _clStars(double w, double h, int n, [double k = 0.7]) {
  final a = Float32List(n * 3);
  for (var i = 0; i < n; i++) {
    a[i * 3] = _rnd() * w;
    a[i * 3 + 1] = _rnd() * h * k;
    a[i * 3 + 2] = _rnd() * 9;
  }
  return a;
}

void _clScale(Float32List a, int stride, double sx, double sy) {
  for (var i = 0; i + 1 < a.length; i += stride) {
    a[i] *= sx;
    a[i + 1] *= sy;
  }
}

/// JS `drawStars`: квадратики 1.1 с мерцанием.
void _clStarsDraw(_ClAtlas q, Float32List st, double t, double amp,
    {double base = 0.12, double freq = 1.3, double size = 1.1}) {
  for (var i = 0; i < st.length; i += 3) {
    q.sq(st[i], st[i + 1], size, 0xFFFFFF, base + amp * math.max(0.0, math.sin(t * freq + st[i + 2])));
  }
}

ui.Image? _clSqImg;
ui.Image _clSquare() {
  final cached = _clSqImg;
  if (cached != null) return cached;
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = const Color(0xFFFFFFFF));
  return _clSqImg = rec.endRecording().toImageSync(4, 4);
}

final Paint _clAtlasPaint = Paint()..filterQuality = FilterQuality.low;

/// Пакет одинаковых спрайтов (свечение или квадрат) разного цвета и размера.
class _ClAtlas {
  _ClAtlas(this.isGlow);
  final bool isGlow;
  Float32List _t = Float32List(512), _r = Float32List(512);
  Int32List _c = Int32List(128);
  int n = 0;

  void _add(double s, double tx, double ty, double src, int argb) {
    if (n == _c.length) {
      final t = Float32List(_t.length * 2)..setAll(0, _t);
      final r = Float32List(_r.length * 2)..setAll(0, _r);
      final c = Int32List(_c.length * 2)..setAll(0, _c);
      _t = t;
      _r = r;
      _c = c;
    }
    final i = n * 4;
    _t[i] = s;
    _t[i + 1] = 0;
    _t[i + 2] = tx;
    _t[i + 3] = ty;
    _r[i] = 0;
    _r[i + 1] = 0;
    _r[i + 2] = src;
    _r[i + 3] = src;
    _c[n++] = argb;
  }

  /// Свечение радиуса [r] (как `glow` референса).
  void glow(double x, double y, double r, int rgb, double op) {
    if (op <= 0.003 || r <= 0.5) return;
    _add(r / 32, x - r, y - r, 64, _clArgb(rgb, op));
  }

  /// Квадрат со стороной [size], левый верхний угол (x, y) (как `fillRect`).
  void sq(double x, double y, double size, int rgb, double a) {
    if (a <= 0.003) return;
    _add(size / 4, x, y, 4, _clArgb(rgb, a));
  }

  void flush(Canvas c, [bool add = false]) {
    if (n == 0) return;
    final img = isGlow ? _glowSprite(const Color(0xFFFFFFFF)) : _clSquare();
    _clAtlasPaint.blendMode = add ? BlendMode.plus : BlendMode.srcOver;
    c.drawRawAtlas(img, Float32List.sublistView(_t, 0, n * 4), Float32List.sublistView(_r, 0, n * 4),
        Int32List.sublistView(_c, 0, n), BlendMode.modulate, null, _clAtlasPaint);
    n = 0;
  }
}

final Paint _clGlS = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 0.9
  ..strokeCap = StrokeCap.round;
final Paint _clGlF = Paint();

/// `glint` референса, с цветом и сложением света.
void _clGlint(Canvas c, double x, double y, double s, double a, [int rgb = 0xFFFFFF, bool add = false]) {
  if (a <= 0.02) return;
  final col = _cla(rgb, a), m = add ? BlendMode.plus : BlendMode.srcOver;
  _clGlS
    ..color = col
    ..blendMode = m;
  _clGlF
    ..color = col
    ..blendMode = m;
  c.drawLine(Offset(x - s, y), Offset(x + s, y), _clGlS);
  c.drawLine(Offset(x, y - s), Offset(x, y + s), _clGlS);
  c.drawCircle(Offset(x, y), s * 0.22, _clGlF);
}

/// Универсальная частица (поля по смыслу сцены).
class _ClP {
  _ClP({
    this.x = 0,
    this.y = 0,
    this.vx = 0,
    this.vy = 0,
    this.life = 1,
    this.r = 1,
    this.sd = 0,
    this.z = 0,
    this.ph = 0,
    this.a = 0,
    this.v = 0,
    this.col = 0xFFFFFF,
    this.flag = false,
  })  : px = x,
        py = y;
  double x, y, vx, vy, px, py, ox = 0, oy = 0, age = 0, life, r, sd, z, ph, a, v;
  int col;
  bool flag, dead = false;
}

/// Стебель (водоросль, трава).
class _ClStem {
  _ClStem(this.x, this.h, this.ph, this.col);
  double x, h;
  final double ph;
  final Color col;
  final s = Spring();
}

/// Общая база: смена размера, прогрев первого кадра, фон-градиент с кэшем.
abstract class _CBase extends CoverSim {
  double _w = 0, _h = 0;
  bool _warmed = false;
  Paint? _bgP;
  Size _bgS = Size.zero;
  bool _bgD = true;

  /// Сколько секунд прожить до первого показанного кадра и каким шагом.
  double get warmSecs => 0;
  double get warmStep => 1 / 30;
  void setup(Size s);

  /// По умолчанию — заново; сцены с частицами растягивают их на месте.
  void resize(Size s, double sx, double sy) => setup(s);
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr);

  @override
  void init(Size s) {
    _w = s.width;
    _h = s.height;
    setup(s);
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    if (s.isEmpty) return;
    if (_w <= 0 || _h <= 0) {
      init(s);
    } else if (s.width != _w || s.height != _h) {
      final sx = s.width / _w, sy = s.height / _h;
      _w = s.width;
      _h = s.height;
      resize(s, sx, sy);
    }
    if (!_warmed) {
      _warmed = true;
      final ws = warmSecs;
      if (ws > 0) {
        final step = warmStep;
        final rec = ui.PictureRecorder(), wc = Canvas(rec), n = (ws / step).ceil();
        for (var i = 0; i < n; i++) {
          paint(wc, s, t - ws + i * step, step, dark, null, null);
        }
        rec.endRecording().dispose();
      }
    }
    paint(c, s, t, dt, dark, tap, pointer);
  }

  void bg(Canvas c, Size s, bool dark, List<Color> cols, [List<double>? stops, bool diag = false]) {
    var p = _bgP;
    if (p == null || _bgS != s || _bgD != dark) {
      p = _bgP = Paint()
        ..shader = ui.Gradient.linear(
            Offset.zero, diag ? Offset(s.width, s.height) : Offset(0, s.height), cols, stops ?? _even(cols.length));
      _bgS = s;
      _bgD = dark;
    }
    c.drawRect(Offset.zero & s, p);
  }
}

// ───────────── Космос (Space) ─────────────
class _CSpace extends _CBase {
  final px = Spring();
  late List<_ClP> st;
  final _g = _ClAtlas(true), _q = _ClAtlas(false), _gl = <double>[];
  final _ring = _stroke(const Color(0xBFFFD6A3), 1, StrokeCap.butt);
  Paint? _planet;
  double _pr = -1;
  static const _bgc = [Color(0xFF04050D), Color(0xFF0B0E26), Color(0xFF161033)];
  static const _nc = [Color(0xFF5B3BD6), Color(0xFF1F6BD6), Color(0xFFC43B9A)];
  static const _nx = [0.22, 0.7, 0.9], _ny = [0.35, 0.75, 0.15], _nr = [0.9, 0.8, 0.55];

  @override
  void setup(Size s) {
    final w = s.width, h = s.height;
    st = List.generate((w * h / 420).round(), (_) => _ClP(x: _rnd() * w, y: _rnd() * h, z: _pow(_rnd(), 1.6), ph: _rnd() * 9));
  }

  @override
  void resize(Size s, double sx, double sy) {
    for (final q in st) {
      q.x *= sx;
      q.y *= sy;
    }
  }

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width, h = s.height;
    bg(c, s, dark, _bgc);
    px.t = ptr != null ? ptr.dx / w - 0.5 : math.sin(t * 0.15) * 0.3;
    px.step(dt, 30, 8);
    final par = px.x;
    for (var i = 0; i < 3; i++) {
      _glowS(c, Offset(_nx[i] * w + math.sin(t * 0.1 + i * 2) * 14 - par * 12, _ny[i] * h + math.cos(t * 0.13 + i) * 8),
          h * _nr[i], _nc[i], 0.3, true);
    }
    _gl.clear();
    for (final q in st) {
      if (_clPush(tap, q.x + q.ox, q.y + q.oy, 130, 340)) {
        q.vx += _clKx;
        q.vy += _clKy;
      }
      q.vx += (-q.ox * 16 - q.vx * 3.2) * dt;
      q.vy += (-q.oy * 16 - q.vy * 3.2) * dt;
      q.ox += q.vx * dt;
      q.oy += q.vy * dt;
      q.x -= (1.5 + q.z * 7) * dt;
      if (q.x < -4) q.x = w + 4;
      final x = q.x + q.ox - par * q.z * 36, y = q.y + q.oy;
      final a = (0.25 + q.z * 0.75) * (0.55 + 0.45 * math.sin(t * (1 + q.z * 2) + q.ph));
      if (q.z > 0.82) {
        _g.glow(x, y, 5, 0xBFD0FF, a * 0.6);
        _gl
          ..add(x)
          ..add(y)
          ..add(a);
      } else {
        _q.sq(x, y, 0.7 + q.z * 1.2, 0xFFFFFF, a);
      }
    }
    _q.flush(c);
    _g.flush(c, true);
    for (var i = 0; i < _gl.length; i += 3) {
      _clGlint(c, _gl[i], _gl[i + 1], 2.6, _gl[i + 2]);
    }
    final ppx = w * 0.84 - par * 26, ppy = h * 0.3 + math.sin(t * 0.5) * 3, r = math.min(17.0, h * 0.13);
    if (_pr != r || _planet == null) {
      _pr = r;
      _planet = Paint()
        ..shader = ui.Gradient.radial(Offset.zero, r, const [Color(0xFFFFC79A), Color(0xFFC85A7A), Color(0xFF3A1E5C)],
            const [0.0, 0.55, 1.0], TileMode.clamp, null, Offset(-r * 0.4, -r * 0.4), r * 0.1);
    }
    c.save();
    c.translate(ppx, ppy);
    _half(c, r, math.pi);
    c.drawCircle(Offset.zero, r, _planet!);
    _half(c, r, 0);
    c.restore();
  }

  void _half(Canvas c, double r, double a0) {
    c.save();
    c.rotate(-0.38);
    _ring.strokeWidth = r * 0.16;
    c.drawArc(Rect.fromCenter(center: Offset.zero, width: r * 3.8, height: r * 0.9), a0, math.pi, false, _ring);
    c.restore();
  }
}

// ───────────── Костёр (Campfire) ─────────────
class _CFire extends _CBase {
  final fl = <_ClP>[], sp = <_ClP>[];
  final wind = Spring();
  double acc = 0;
  late Float32List st;
  final _g = _ClAtlas(true), _q = _ClAtlas(false);
  final _ground = Paint()..color = const Color(0xFF0A0706);
  final _log = Paint()..color = const Color(0xFF2A1810);
  final _ember = Paint();
  static const _bgc = [Color(0xFF070A18), Color(0xFF141026), Color(0xFF2A120C)];

  @override
  double get warmSecs => 1.2;

  @override
  void setup(Size s) => st = _clStars(s.width, s.height, 34, 0.6);

  @override
  void resize(Size s, double sx, double sy) => _clScale(st, 3, sx, sy);

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width, h = s.height, fx = w * 0.76, fy = h * 0.84, sc = _clamp(h / 200, 0.5, 1.2);
    bg(c, s, dark, _bgc);
    _clStarsDraw(_q, st, t, 0.45, base: 0.2, freq: 1.4);
    _q.flush(c);
    final f = 0.85 + 0.15 * math.sin(t * 11) * math.sin(t * 7.3);
    _glowS(c, Offset(fx, fy), h * 1.15, const Color(0xFFFF7A2A), 0.42 * f, true);
    c.drawOval(_ov(w / 2, h * 1.06, w * 0.8, h * 0.2), _ground);
    if (tap != null) {
      wind.v += (fx > tap.dx ? 1 : -1) * 150;
      for (var i = 0; i < 16; i++) {
        sp.add(_ClP(
            x: fx + (_rnd() - 0.5) * 16,
            y: fy - 8,
            vx: (_rnd() - 0.5) * 80,
            vy: -(60 + _rnd() * 110) * sc,
            life: 1 + _rnd() * 1.4,
            sd: _rnd() * 6));
      }
    }
    wind.t = math.sin(t * 0.5) * 7;
    wind.step(dt, 26, 4);
    acc += dt * 75;
    while (acc > 1) {
      acc -= 1;
      fl.add(_ClP(
          x: fx + (_rnd() - 0.5) * 24 * sc,
          y: fy - 3,
          vy: -(36 + _rnd() * 48) * sc,
          r: (9 + _rnd() * 8) * sc,
          life: 0.65 + _rnd() * 0.5,
          sd: _rnd() * 6));
    }
    if (_rnd() < dt * 9) {
      sp.add(_ClP(
          x: fx + (_rnd() - 0.5) * 14,
          y: fy - 10,
          vx: (_rnd() - 0.5) * 20,
          vy: -(40 + _rnd() * 60) * sc,
          life: 1.4 + _rnd() * 1.8,
          sd: _rnd() * 6));
    }
    _ember.color = _cla(0xFF6A2A, 0.5 * f);
    for (var k = 0; k < 2; k++) {
      c.save();
      c.translate(fx + (k == 0 ? -9 : 9) * sc * 0.3, fy + 3 * sc);
      c.rotate(k == 0 ? -0.32 : 0.3);
      c.drawRRect(_rr(-22 * sc, -4 * sc, 44 * sc, 8 * sc, 4 * sc), _log);
      c.drawRect(Rect.fromLTWH(-18 * sc, -4 * sc, 36 * sc, 1.4), _ember);
      c.restore();
    }
    for (final q in fl) {
      q.age += dt;
      final u = q.age / q.life;
      q.x += (wind.x * u * 4 + math.sin(q.age * 9 + q.sd) * 9) * dt * sc;
      q.y += q.vy * dt;
      _g.glow(q.x, q.y, q.r * (1 - u * 0.8), u < 0.28 ? 0xFFE9A8 : (u < 0.6 ? 0xFF9A2E : 0xD8401A), (1 - u) * 0.55);
    }
    fl.removeWhere((q) => q.age >= q.life);
    for (final q in sp) {
      q.age += dt;
      q.vx += (wind.x * 3 - q.vx) * dt;
      q.x += (q.vx + math.sin(q.age * 3 + q.sd) * 12) * dt;
      q.y += q.vy * dt;
      q.vy *= 1 - dt * 0.5;
      final u = q.age / q.life;
      _g.glow(q.x, q.y, 3.2, 0xFFB45A, (u < 0.1 ? u * 10 : 1 - u) * (0.7 + 0.3 * math.sin(t * 14 + q.sd)));
    }
    sp.removeWhere((q) => q.age >= q.life || q.y <= -8);
    _g.flush(c, true);
  }
}

// ───────────── Подводный мир (Reef) ─────────────
class _CReef extends _CBase {
  double sc = 1, _rayH = -1;
  late List<_ClP> fish, bub;
  final weed = <_ClStem>[];
  final _path = Path(), _fp = Paint(), _rayP = Paint()..blendMode = BlendMode.plus;
  final _bubS = _stroke(const Color(0x80FFFFFF), 0.8), _bubF = Paint()..color = const Color(0xCCFFFFFF);
  final _hl = Paint()..color = const Color(0x59FFFFFF), _eye = Paint()..color = const Color(0xFF0B1E33);
  final _bed = Paint()..color = const Color(0xFF04142A);
  final _wp = _stroke(const Color(0xFF1FB58A), 3.4);
  static final Path _tail = Path()
    ..moveTo(0, 0)
    ..lineTo(-6, -4)
    ..lineTo(-4.5, 0)
    ..lineTo(-6, 4)
    ..close();
  static const _fc = [0xFFB84A, 0xFF7A6B, 0x7FE0FF, 0xFFE08A];
  static const _wc = [Color(0xFF1FB58A), Color(0xFF2FD6A0), Color(0xFF0F8C7A)];
  static const _bgc = [Color(0xFF1FA7B8), Color(0xFF0A3A6B), Color(0xFF06203F)];

  void _weeds(double w) {
    final n = (w / 34).round();
    while (weed.length > n) {
      weed.removeLast();
    }
    for (var i = weed.length; i < n; i++) {
      weed.add(_ClStem((i + 0.5 + (_rnd() - 0.5) * 0.6) * 34, (26 + _rnd() * 46) * sc, _rnd() * 9, _wc[i % 3]));
    }
  }

  @override
  void setup(Size s) {
    final w = s.width, h = s.height;
    sc = _clamp(h / 200, 0.55, 1.2);
    fish = List.generate(
        11,
        (i) => _ClP(
            x: _rnd() * w,
            y: h * (0.15 + _rnd() * 0.55),
            vx: (_rnd() < 0.5 ? -1 : 1) * (12 + _rnd() * 14),
            r: (0.7 + _rnd() * 0.8) * sc,
            col: _fc[i % 4],
            ph: _rnd() * 9));
    weed.clear();
    _weeds(w);
    bub = List.generate(14, (_) => _ClP(x: _rnd() * w, y: _rnd() * h, r: 1 + _rnd() * 2.6, sd: _rnd() * 9, v: 10 + _rnd() * 16));
  }

  @override
  void resize(Size s, double sx, double sy) {
    final nsc = _clamp(s.height / 200, 0.55, 1.2), k = nsc / sc;
    sc = nsc;
    for (final f in fish) {
      f.x *= sx;
      f.y *= sy;
      f.r *= k;
    }
    for (final b in bub) {
      b.x *= sx;
      b.y *= sy;
    }
    for (final w in weed) {
      w.h *= k;
    }
    _weeds(s.width);
  }

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width, h = s.height;
    bg(c, s, dark, _bgc);
    if (_rayH != h) {
      _rayH = h;
      _rayP.shader = _linG(Offset.zero, Offset(0, h), const [Color(0x29A0F0FF), Color(0x00A0F0FF)]);
    }
    for (var i = 0; i < 4; i++) {
      final x = w * (0.12 + i * 0.25) + math.sin(t * 0.3 + i * 2) * 18, spw = 14.0 + i * 5;
      _path
        ..reset()
        ..moveTo(x - spw, 0)
        ..lineTo(x + spw, 0)
        ..lineTo(x + spw * 3 - 50, h)
        ..lineTo(x - spw * 3 - 50, h)
        ..close();
      c.drawPath(_path, _rayP);
    }
    if (tap != null) {
      for (var i = 0; i < 9; i++) {
        bub.add(_ClP(
            x: tap.dx + (_rnd() - 0.5) * 18,
            y: tap.dy + (_rnd() - 0.5) * 10,
            r: 1 + _rnd() * 3,
            sd: _rnd() * 9,
            v: 22 + _rnd() * 30,
            flag: true));
      }
    }
    for (final b in bub) {
      b.y -= b.v * dt;
      final x = b.x + math.sin(t * 2 + b.sd) * 4;
      if (b.y < -6) {
        if (b.flag) {
          b.dead = true;
          continue;
        }
        b.y = h + 6;
        b.x = _rnd() * w;
      }
      c.drawCircle(Offset(x, b.y), b.r, _bubS);
      c.drawCircle(Offset(x - b.r * 0.35, b.y - b.r * 0.35), b.r * 0.22, _bubF);
    }
    bub.removeWhere((b) => b.dead);
    for (final f in fish) {
      if (_clPush(tap, f.x, f.y, 150, 420)) {
        f.vx += _clKx;
        f.vy += _clKy;
      }
      final dir = f.vx >= 0 ? 1.0 : -1.0, cruise = dir * (13 + f.r * 9);
      f.vx += (cruise - f.vx) * dt * 1.4;
      f.vy += (-f.vy * 2 + math.sin(t * 1.3 + f.ph) * 7) * dt;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      f.y = _clamp(f.y, 8, h * 0.82);
      if (f.x > w + 20) f.x = -18;
      if (f.x < -20) f.x = w + 18;
      final spd = math.min(3.0, f.vx.abs() / 20), wag = math.sin(t * (7 + spd * 5) + f.ph) * 0.5;
      c.save();
      c.translate(f.x, f.y);
      c.scale(dir * f.r, f.r);
      c.rotate(_clamp(f.vy / 60, -0.5, 0.5));
      _fp.color = Color(0xFF000000 | f.col);
      c.drawOval(_ov(0, 0, 7, 3.4), _fp);
      c.save();
      c.translate(-6, 0);
      c.rotate(wag);
      c.drawPath(_tail, _fp);
      c.restore();
      c.drawOval(_ov(0.5, -1.2, 4, 1), _hl);
      c.drawCircle(const Offset(4, -0.7), 0.9, _eye);
      c.restore();
    }
    c.drawOval(_ov(w / 2, h * 1.08, w * 0.75, h * 0.18), _bed);
    _wp.strokeWidth = 3.4 * sc;
    for (final k in weed) {
      if (ptr != null) {
        final d = k.x - ptr.dx;
        if (d.abs() < 46 && ptr.dy > h - k.h - 30) k.s.v += _clSign(d) * (1 - d.abs() / 46) * 60 * dt * 8;
      }
      if (_clPush(tap, k.x, h - k.h / 2, 90, 10)) k.s.v += _clKx * 4;
      k.s.step(dt, 34, 3.2);
      _path
        ..reset()
        ..moveTo(k.x, h + 2);
      for (var j = 1; j <= 6; j++) {
        final u = j / 6;
        _path.lineTo(k.x + (math.sin(t * 1.2 + k.ph + j * 0.7) * 5 + k.s.x * 1.6) * u * u * sc * 2, h - k.h * u);
      }
      _wp.color = k.col;
      c.drawPath(_path, _wp);
    }
  }
}

// ───────────── Салют (Fireworks) ─────────────
class _ClRk {
  _ClRk(this.sx, this.tx, this.ty, this.dur);
  final double sx, tx, ty, dur;
  double t = 0;
  bool dead = false;
}

class _CFireworks extends _CBase {
  final r = <_ClRk>[], p = <_ClP>[], fl = <_ClP>[];
  double tm = 0.3, sc = 1;
  late Float32List st;
  final _g = _ClAtlas(true), _q = _ClAtlas(false);
  final _rl = _stroke(const Color(0x8CFFDCAA), 1.2), _lp = _stroke(const Color(0xFFFFFFFF), 1.3);
  static const _pal = [
    [0xFFD36B, 0xFFF3C8],
    [0xFF6B9A, 0xFFC2D6],
    [0x6BE0FF, 0xD6F6FF],
    [0xB48CFF, 0xE6D8FF],
    [0x7CFFB0, 0xE0FFE9],
  ];
  static const _bgc = [Color(0xFF05061A), Color(0xFF0F0B2A), Color(0xFF1E1030)];

  @override
  double get warmSecs => 1.7;

  @override
  void setup(Size s) {
    st = _clStars(s.width, s.height, 40, 0.7);
    sc = _clamp(s.height / 200, 0.55, 1.2);
  }

  @override
  void resize(Size s, double sx, double sy) {
    _clScale(st, 3, sx, sy);
    sc = _clamp(s.height / 200, 0.55, 1.2);
  }

  void _launch(double x, double y) => r.add(_ClRk(x + (_rnd() - 0.5) * 50, x, y, 0.6 + _rnd() * 0.3));

  void _boom(double x, double y) {
    final pal = _pal[math.min(4, (_rnd() * 5).floor())], ringy = _rnd() < 0.35;
    const n = 56;
    for (var i = 0; i < n; i++) {
      final a = i / n * _tau + _rnd() * 0.1, s = (ringy ? 78 : 30 + _rnd() * 62) * sc;
      p.add(_ClP(
          x: x,
          y: y,
          vx: math.cos(a) * s,
          vy: math.sin(a) * s,
          life: 1 + _rnd() * 0.7,
          col: pal[i % 5 == 0 ? 1 : 0],
          sd: _rnd() * 9));
    }
    fl.add(_ClP(x: x, y: y, a: 1, col: pal[0]));
  }

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width, h = s.height;
    bg(c, s, dark, _bgc);
    _clStarsDraw(_q, st, t, 0.35, base: 0.15, freq: 1.2, size: 1);
    _q.flush(c);
    _glowS(c, Offset(w / 2, h * 1.25), h * 0.9, const Color(0xFF7A3BD6), 0.35, true);
    tm -= dt;
    if (tm <= 0) {
      _launch(w * (0.1 + _rnd() * 0.8), h * (0.18 + _rnd() * 0.36));
      tm = 0.6 + _rnd() * 1.1;
    }
    if (tap != null) _launch(tap.dx, tap.dy);
    for (final f in fl) {
      _g.glow(f.x, f.y, 70 * sc, f.col, f.a * 0.5);
      f.a -= dt * 3;
    }
    fl.removeWhere((f) => f.a <= 0);
    _g.flush(c, true);
    for (final q in r) {
      q.t += dt;
      final u = math.min(1.0, q.t / q.dur), e = 1 - (1 - u) * (1 - u), x = _lerp(q.sx, q.tx, e), y = _lerp(h + 4, q.ty, e);
      c.drawLine(Offset(x, y), Offset(_lerp(x, q.sx, 0.12), y + 16 * (1 - u) + 3), _rl);
      _g.glow(x, y, 5, 0xFFE9C0, 1);
      if (u >= 1) {
        _boom(x, y);
        q.dead = true;
      }
    }
    r.removeWhere((q) => q.dead);
    _g.flush(c, true);
    for (final q in p) {
      q.age += dt;
      final dr = 1 - dt * 1.7;
      q.vx *= dr;
      q.vy = q.vy * dr + 42 * sc * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      q.px += (q.x - q.px) * math.min(1.0, dt * 11);
      q.py += (q.y - q.py) * math.min(1.0, dt * 11);
      final u = q.age / q.life, a = (1 - u) * (u > 0.6 ? 0.5 + 0.5 * math.sin(t * 30 + q.sd) : 1);
      if (a > 0.003) {
        _lp.color = _cla(q.col, a * 0.7);
        c.drawLine(Offset(q.px, q.py), Offset(q.x, q.y), _lp);
      }
      _g.glow(q.x, q.y, 3.4, q.col, a);
    }
    p.removeWhere((q) => q.age >= q.life);
    _g.flush(c, true);
  }
}

// ───────────── Наши иконки (Logos) ─────────────
ui.Image? _clLogoImg;
bool _clLogoAsked = false;

/// Знак грузится один раз на всё приложение; без ассета (тесты) — просто нет знака.
void _clLoadLogo() {
  if (_clLogoAsked) return;
  _clLogoAsked = true;
  rootBundle.load('assets/app_ui/icons/png/premium_logo.png').then((data) async {
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), targetWidth: 160);
    final fr = await codec.getNextFrame();
    codec.dispose();
    _clLogoImg = fr.image;
  }).catchError((Object _) {});
}

/// Загрузить знак обложки «Наши иконки» заранее. Экран выбора зовёт это при
/// открытии: неподвижная плитка рисуется один раз и сама дорисовать знак,
/// пришедший позже, не может.
void precacheProfileFxAssets() => _clLoadLogo();

class _CLogos extends _CBase {
  late List<_ClP> it; // a — поворот, v — скорость поворота
  final _disc = <Paint>[];
  bool _discDark = true, _discDirty = true;
  final _ring = _stroke(const Color(0x4DFFFFFF), 0.8), _img = Paint()..filterQuality = FilterQuality.medium;
  static const _bgd = [Color(0xFF0A0F2E), Color(0xFF17246E), Color(0xFF2A1A66)];
  static const _bgl = [Color(0xFFEEF2FF), Color(0xFFD4DCFF), Color(0xFFE2D8FF)];
  // Светлая тема: белый знак на светлом стекле не читается — красим в индиго.
  static const _tint = ColorFilter.mode(Color(0xFF4A5BC4), BlendMode.srcIn);

  @override
  void setup(Size s) {
    final w = s.width, h = s.height, sc = _clamp(h / 200, 0.5, 1.1);
    it = List.generate(10, (_) {
      final z = _rnd();
      return _ClP(
          x: _rnd() * w,
          y: _rnd() * h,
          vx: (_rnd() - 0.5) * 16,
          vy: (_rnd() - 0.5) * 12,
          r: (11 + z * 15) * sc,
          z: z,
          a: (_rnd() - 0.5) * 0.6,
          v: (_rnd() - 0.5) * 0.3);
    })
      ..sort((a, b) => a.z.compareTo(b.z));
    _discDirty = true;
    _clLoadLogo();
  }

  @override
  void resize(Size s, double sx, double sy) {
    final k = _clamp(s.height / 200, 0.5, 1.1) / _clamp((s.height / sy) / 200, 0.5, 1.1);
    for (final a in it) {
      a.x *= sx;
      a.y *= sy;
      a.r *= k;
    }
    _discDirty = true;
  }

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width, h = s.height;
    bg(c, s, dark, dark ? _bgd : _bgl, const [0.0, 0.6, 1.0], true);
    if (dark) {
      _glowS(c, Offset(w * 0.25 + math.sin(t * 0.2) * 20, h * 0.3), h * 0.9, const Color(0xFF4A6BFF), 0.4, true);
      _glowS(c, Offset(w * 0.8, h * 0.8 + math.cos(t * 0.17) * 10), h * 0.8, const Color(0xFF8A5CF0), 0.35, true);
    } else {
      _glowS(c, Offset(w * 0.25 + math.sin(t * 0.2) * 20, h * 0.3), h * 0.9, const Color(0xFF7A93FF), 0.3);
      _glowS(c, Offset(w * 0.8, h * 0.8 + math.cos(t * 0.17) * 10), h * 0.8, const Color(0xFFA98BF2), 0.25);
    }
    if (_discDirty || _discDark != dark) {
      _discDirty = false;
      _discDark = dark;
      _disc
        ..clear()
        ..addAll(it.map((a) {
          final ga = 0.5 + a.z * 0.5;
          return Paint()
            ..shader = _linG(Offset(0, -a.r), Offset(0, a.r),
                dark ? [_cla(0xFFFFFF, 0.16 * ga), _cla(0xFFFFFF, 0.05 * ga)] : [_cla(0xFFFFFF, 0.75 * ga), _cla(0xFFFFFF, 0.4 * ga)]);
        }));
    }
    final logo = _clLogoImg;
    for (var i = 0; i < it.length; i++) {
      final a = it[i];
      if (_clPush(tap, a.x, a.y, 150, 380)) {
        a.vx += _clKx;
        a.vy += _clKy;
        a.v += (_rnd() - 0.5) * 9;
      }
      for (var j = i + 1; j < it.length; j++) {
        final b = it[j], dx = b.x - a.x, dy = b.y - a.y, m = a.r + b.r + 6;
        var d = math.sqrt(dx * dx + dy * dy);
        if (d == 0) d = 1;
        if (d < m) {
          final f = (m - d) * 14 * dt;
          a.vx -= dx / d * f;
          a.vy -= dy / d * f;
          b.vx += dx / d * f;
          b.vy += dy / d * f;
        }
      }
      final sp = math.sqrt(a.vx * a.vx + a.vy * a.vy), cr = 7 + a.z * 9;
      if (sp > cr) {
        final k = 1 - dt * 1.6;
        a.vx *= k;
        a.vy *= k;
      } else if (sp > 0.01) {
        a.vx *= 1 + dt * 0.4;
        a.vy *= 1 + dt * 0.4;
      }
      a.v += (-a.a * 3 - a.v * 1.4) * dt;
      a.a += a.v * dt;
      a.x += a.vx * dt;
      a.y += a.vy * dt;
      if (a.x < a.r) a.vx += (a.r - a.x) * 8 * dt;
      if (a.x > w - a.r) a.vx -= (a.x - w + a.r) * 8 * dt;
      if (a.y < a.r) a.vy += (a.r - a.y) * 8 * dt;
      if (a.y > h - a.r) a.vy -= (a.y - h + a.r) * 8 * dt;
      _glowS(c, Offset(a.x, a.y + a.r * 0.5), a.r * 1.9, dark ? const Color(0xFF050718) : const Color(0xFF1A2350), dark ? 0.4 : 0.14);
      final ga = 0.5 + a.z * 0.5;
      c.save();
      c.translate(a.x, a.y + math.sin(t * 1.1 + i) * 2);
      c.rotate(a.a);
      c.drawCircle(Offset.zero, a.r, _disc[i]);
      _ring.color = dark ? _cla(0xFFFFFF, 0.3 * ga) : _cla(0x3B4BA8, 0.22 * ga);
      c.drawCircle(Offset.zero, a.r, _ring);
      if (logo != null) {
        _img
          ..color = Color.fromRGBO(0, 0, 0, ga)
          ..colorFilter = dark ? null : _tint;
        c.drawImageRect(logo, Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
            Rect.fromLTWH(-a.r * 0.68, -a.r * 0.68, a.r * 1.36, a.r * 1.36), _img);
      }
      c.restore();
    }
  }
}

// ───────────── Волны (Waves) ─────────────
class _ClLayer {
  _ClLayer(int n, this.base, this.ph, this.sp)
      : y = Float32List(n),
        v = Float32List(n);
  Float32List y, v;
  double base;
  final double ph, sp;
}

class _CWaves extends _CBase {
  int n = 0;
  final layers = <_ClLayer>[];
  Offset? lp;
  Float32List _yy = Float32List(0);
  final _fill = Path(), _line = Path(), _fp = Paint(), _sp = _stroke(const Color(0xFFFFFFFF), 1.2, StrokeCap.butt);
  static const _cd = [0x6C8BFF, 0x5566F0, 0x6A48E0, 0x3A2A9A];
  static const _cl = [0xA9BCFF, 0x8C9CF6, 0x9A86EE, 0x6F5CD2];
  static const _bgd = [Color(0xFF141C55), Color(0xFF0A0F2E)];
  static const _bgl = [Color(0xFFDCE4FF), Color(0xFFF5F7FF)];

  @override
  void setup(Size s) {
    n = (s.width / 6).ceil() + 2;
    _yy = Float32List(n);
    layers
      ..clear()
      ..addAll(List.generate(4, (i) => _ClLayer(n, s.height * (0.36 + i * 0.17), _rnd() * 9, 0.5 + i * 0.22)));
    lp = null;
  }

  @override
  void resize(Size s, double sx, double sy) {
    final nn = (s.width / 6).ceil() + 2;
    for (var i = 0; i < layers.length; i++) {
      final l = layers[i];
      l.base = s.height * (0.36 + i * 0.17);
      if (nn != n) {
        final y = Float32List(nn), v = Float32List(nn), m = math.min(n, nn);
        y.setRange(0, m, l.y);
        v.setRange(0, m, l.v);
        l
          ..y = y
          ..v = v;
      }
    }
    n = nn;
    _yy = Float32List(nn);
    lp = null;
  }

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width, h = s.height;
    bg(c, s, dark, dark ? _bgd : _bgl);
    if (dark) {
      _glowS(c, Offset(w * 0.75, h * 0.1), h * 0.9, const Color(0xFF8A5CF0), 0.35, true);
    } else {
      _glowS(c, Offset(w * 0.75, h * 0.1), h * 0.9, const Color(0xFFC2AEFF), 0.45);
    }
    final sd = dt / 2, amp = _clamp(h / 200, 0.5, 1);
    for (var li = 0; li < 4; li++) {
      final l = layers[li], y = l.y, v = l.v;
      if (tap != null) {
        final i0 = (tap.dx / 6).round();
        for (var k = -5; k <= 5; k++) {
          final j = i0 + k;
          if (j >= 0 && j < n) v[j] += 260 * amp * (1 - k.abs() / 6) * (0.5 + li * 0.25);
        }
      }
      final last = lp;
      if (ptr != null && last != null) {
        final i0 = (ptr.dx / 6).round(), dy = ptr.dy - last.dy;
        if (i0 >= 0 && i0 < n && (ptr.dy - l.base - y[i0]).abs() < 16) {
          for (var k = -2; k <= 2; k++) {
            final j = i0 + k;
            if (j >= 0 && j < n) v[j] += dy * 9;
          }
        }
      }
      for (var st = 0; st < 2; st++) {
        for (var i = 1; i < n - 1; i++) {
          v[i] += (900 * (y[i - 1] + y[i + 1] - 2 * y[i]) - 7 * y[i] - 1.5 * v[i]) * sd;
        }
        for (var i = 1; i < n - 1; i++) {
          y[i] += v[i] * sd;
        }
        y[0] = y[1];
        y[n - 1] = y[n - 2];
      }
      for (var i = 0; i < n; i++) {
        _yy[i] = l.base + y[i] + (math.sin(i * 0.13 + t * l.sp + l.ph) * 7 + math.sin(i * 0.05 - t * l.sp * 0.6) * 5) * amp;
      }
      _fill
        ..reset()
        ..moveTo(0, h);
      _line.reset();
      for (var i = 0; i < n; i++) {
        _fill.lineTo(i * 6, _yy[i]);
        if (i == 0) {
          _line.moveTo(0, _yy[0]);
        } else {
          _line.lineTo(i * 6, _yy[i]);
        }
      }
      _fill
        ..lineTo(w, h)
        ..close();
      _fp.color = _cla(dark ? _cd[li] : _cl[li], 0.88);
      c.drawPath(_fill, _fp);
      _sp.color = _cla(0xFFFFFF, dark ? 0.32 - li * 0.06 : 0.7 - li * 0.1);
      c.drawPath(_line, _sp);
    }
    lp = ptr;
  }
}

// ───────────── Метеоры (Meteors) ─────────────
class _CMeteors extends _CBase {
  late Float32List st;
  final m = <_ClP>[], sp = <_ClP>[], fl = <_ClP>[]; // m: flag — болид, ph — высота цели
  double tm = 0.4, sc = 1, cx = 0, pr = 1, cy = 0;
  final _g = _ClAtlas(true), _q = _ClAtlas(false);
  final _tail = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _planet = Paint()..color = const Color(0xFF05071A);
  final _rim1 = _stroke(const Color(0x2178AAFF), 14, StrokeCap.butt), _rim2 = _stroke(const Color(0xB396C3FF), 1.3, StrokeCap.butt);
  static const _bgc = [Color(0xFF03040C), Color(0xFF0A1030), Color(0xFF1E1C55)];
  static const _tc = [Color(0xF2FFF0D2), Color(0x80FFAA5A), Color(0x007896FF)];

  void _geo(Size s) {
    sc = _clamp(s.height / 200, 0.55, 1.2);
    cx = s.width / 2;
    pr = s.width * 1.7;
    cy = s.height * 0.86 + pr;
  }

  @override
  double get warmSecs => 1.2;

  // Искры хвоста рождаются с вероятностью dt·45: на шаге 1/30 они шли бы ровным пунктиром.
  @override
  double get warmStep => 1 / 60;

  @override
  void setup(Size s) {
    st = _clStars(s.width, s.height, 70, 0.8);
    _geo(s);
  }

  @override
  void resize(Size s, double sx, double sy) {
    _clScale(st, 3, sx, sy);
    _geo(s);
  }

  double _hy(double x) => cy - math.sqrt(math.max(0.0, pr * pr - (x - cx) * (x - cx)));

  void _spawn(double w, Offset? tg) {
    final a = math.pi * 0.3 + (_rnd() - 0.5) * 0.25, s = (190 + _rnd() * 130) * sc, vx = -math.cos(a) * s, vy = math.sin(a) * s;
    if (tg != null) {
      m.add(_ClP(x: tg.dx - vx * 0.7, y: tg.dy - vy * 0.7, vx: vx, vy: vy, ph: tg.dy, flag: true));
    } else {
      m.add(_ClP(x: w * (0.25 + _rnd()), y: -12, vx: vx, vy: vy, ph: 1e9, flag: _rnd() < 0.3));
    }
  }

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width;
    bg(c, s, dark, _bgc);
    _clStarsDraw(_q, st, t, 0.5);
    _q.flush(c);
    tm -= dt;
    if (tm <= 0) {
      _spawn(w, null);
      tm = 0.5 + _rnd() * 1.3;
    }
    if (tap != null) _spawn(w, tap);
    for (final q in m) {
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      final spd = math.sqrt(q.vx * q.vx + q.vy * q.vy), ux = q.vx / spd, uy = q.vy / spd, len = (q.flag ? 62 : 40) * sc;
      final a = Offset(q.x, q.y), b = Offset(q.x - ux * len, q.y - uy * len);
      _tail
        ..shader = ui.Gradient.linear(a, b, _tc, const [0.0, 0.3, 1.0])
        ..strokeWidth = (q.flag ? 2.6 : 1.6) * sc;
      c.drawLine(a, b, _tail);
      _g.glow(q.x, q.y, (q.flag ? 11 : 7) * sc, 0xFFE2B0, 1);
      if (_rnd() < dt * 45) {
        sp.add(_ClP(x: q.x, y: q.y, vx: -ux * 20 + (_rnd() - 0.5) * 34, vy: -uy * 20 + (_rnd() - 0.5) * 34, life: 0.3 + _rnd() * 0.35));
      }
      if (q.y >= q.ph || q.y > _hy(q.x) - 2) {
        q.dead = true;
        fl.add(_ClP(x: q.x, y: q.y, a: 1));
        for (var i = 0; i < 18; i++) {
          final an = _rnd() * _tau, v = (30 + _rnd() * 90) * sc;
          sp.add(_ClP(x: q.x, y: q.y, vx: math.cos(an) * v, vy: math.sin(an) * v - 20, life: 0.4 + _rnd() * 0.6));
        }
      }
    }
    m.removeWhere((q) => q.dead || q.x <= -80);
    for (final f in fl) {
      _g.glow(f.x, f.y, 46 * sc, 0xFFD9A0, f.a * 0.7);
      f.a -= dt * 3.5;
    }
    fl.removeWhere((f) => f.a <= 0);
    for (final q in sp) {
      q.age += dt;
      q.vy += 60 * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      _g.glow(q.x, q.y, 3 * sc, 0xFFC27A, 1 - q.age / q.life);
    }
    sp.removeWhere((q) => q.age >= q.life);
    _g.flush(c, true);
    final o = Offset(cx, cy);
    c.drawCircle(o, pr, _planet);
    _rim1.strokeWidth = 14 * sc;
    c.drawCircle(o, pr, _rim1);
    c.drawCircle(o, pr, _rim2);
  }
}

// ───────────── Иконки (Marks) ─────────────
class _ClMark {
  _ClMark(this.x, this.y, this.ri, this.ph);
  final double x, y, ph;
  final int ri;
  final sc = Spring(1), rot = Spring();
  double d = -1;
}

Path _clMarkPath(double r) => Path()
  ..moveTo(0, -r)
  ..quadraticBezierTo(r * 0.2, -r * 0.2, r, 0)
  ..quadraticBezierTo(r * 0.2, r * 0.2, 0, r)
  ..quadraticBezierTo(-r * 0.2, r * 0.2, -r, 0)
  ..quadraticBezierTo(-r * 0.2, -r * 0.2, 0, -r)
  ..close();

class _CMarks extends _CBase {
  double s = 34;
  final g = <_ClMark>[];
  final _paths = <Path>[];
  final _mp = Paint();
  static const _bgd = [Color(0xFF0B1030), Color(0xFF1B2A7A)];
  static const _bgl = [Color(0xFFEEF1FF), Color(0xFFD6DDFF)];

  @override
  void setup(Size sz) {
    final w = sz.width, h = sz.height;
    s = 34 * _clamp(h / 200, 0.62, 1);
    final cols = (w / s).ceil() + 1, rows = (h / s).ceil() + 1;
    _paths
      ..clear()
      ..addAll(List.generate(4, (i) => _clMarkPath(s * (0.16 + i * 0.035))));
    g.clear();
    // Фаза мерцания — из хэша клетки, а не случайная: при смене размера сетка
    // строится заново и не должна «перемигнуть».
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        g.add(_ClMark((c + (r % 2) * 0.5) * s, (r + 0.5) * s - 4, (r * 3 + c * 5) % 4, _hash(r, c) * 9));
      }
    }
  }

  @override
  void paint(Canvas c, Size sz, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = sz.width, h = sz.height;
    bg(c, sz, dark, dark ? _bgd : _bgl, null, true);
    if (dark) {
      _glowS(c, Offset(w * 0.2, h * 0.2), h, const Color(0xFF4A6BFF), 0.35, true);
      _glowS(c, Offset(w * 0.85, h * 0.9), h * 0.9, const Color(0xFF8A5CF0), 0.3, true);
    } else {
      _glowS(c, Offset(w * 0.2, h * 0.2), h, const Color(0xFF8FA4FF), 0.3);
      _glowS(c, Offset(w * 0.85, h * 0.9), h * 0.9, const Color(0xFFB9A2F5), 0.25);
    }
    final mc = dark ? 0xB8C4FF : 0x4A5BC4, hot = dark ? const Color(0xFFB8C4FF) : const Color(0xFF7D8EF5);
    for (final q in g) {
      if (tap != null) q.d = math.sqrt((q.x - tap.dx) * (q.x - tap.dx) + (q.y - tap.dy) * (q.y - tap.dy)) / 300;
      if (q.d >= 0) {
        q.d -= dt;
        if (q.d < 0) {
          q.sc.v += 7;
          q.rot.v += (_rnd() - 0.5) * 9;
        }
      }
      var near = 0.0;
      if (ptr != null) {
        final dx = q.x - ptr.dx, dy = q.y - ptr.dy;
        near = math.max(0.0, 1 - math.sqrt(dx * dx + dy * dy) / 64);
      }
      q.sc.t = 1 + near * 0.6 + 0.08 * math.sin(t * 1.2 - (q.x + q.y) * 0.02);
      q.sc.step(dt, 150, 7);
      q.rot.step(dt, 80, 6);
      final a = 0.22 + 0.25 * math.max(0.0, math.sin(t * 1.4 + q.ph)) + 0.55 * _clamp(q.sc.x - 1, 0, 1);
      final r = s * (0.16 + q.ri * 0.035);
      c.save();
      c.translate(q.x, q.y);
      c.rotate(q.rot.x);
      c.scale(q.sc.x, q.sc.x);
      if (q.sc.x > 1.25) _glowS(c, Offset.zero, r * 2.6, hot, (q.sc.x - 1.25) * 0.8, dark);
      _mp.color = _cla(mc, dark ? math.min(1.0, a) : math.min(1.0, a * 0.9));
      c.drawPath(_paths[q.ri], _mp);
      c.restore();
    }
  }
}

// ───────────── Золотая дымка (GoldHaze) ─────────────
class _CGoldHaze extends _CBase {
  late List<_ClP> p, bk;
  Offset? lp;
  final _g = _ClAtlas(true), _q = _ClAtlas(false), _gl = <double>[];
  final _sheen = Paint();
  static const _bgd = [Color(0xFF1C1407), Color(0xFF2E1F08), Color(0xFF0E0A04)];
  static const _bgl = [Color(0xFFFFF8E8), Color(0xFFFBEBCB), Color(0xFFFFF4E0)];

  @override
  void setup(Size s) {
    final w = s.width, h = s.height;
    lp = null;
    p = List.generate((w * h / 480).round(), (_) => _ClP(x: _rnd() * w, y: _rnd() * h, z: _rnd(), ph: _rnd() * 9));
    bk = List.generate(7, (_) => _ClP(x: _rnd() * w, y: _rnd() * h, r: h * (0.16 + _rnd() * 0.22), ph: _rnd() * 9));
  }

  @override
  void resize(Size s, double sx, double sy) {
    for (final q in p) {
      q.x *= sx;
      q.y *= sy;
    }
    for (final b in bk) {
      b.x *= sx;
      b.y *= sy;
      b.r *= sy;
    }
    lp = null;
  }

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width, h = s.height;
    bg(c, s, dark, dark ? _bgd : _bgl);
    for (final b in bk) {
      _g.glow(b.x + math.sin(t * 0.2 + b.ph) * 16, b.y + math.cos(t * 0.17 + b.ph) * 8, b.r, dark ? 0xE8A33D : 0xF0B455,
          dark ? 0.16 + 0.08 * math.sin(t * 0.6 + b.ph) : 0.14 + 0.06 * math.sin(t * 0.6 + b.ph));
    }
    _g.flush(c, dark);
    final sx = ((t * 0.12) % 1.6 - 0.3) * w, sh = dark ? 0xFFF3C8 : 0xFFFFFF, sa = dark ? 0.1 : 0.4;
    _sheen.shader = _linG(Offset(sx - 60, 0), Offset(sx + 60, h * 0.4), [_cla(sh, 0), _cla(sh, sa), _cla(sh, 0)]);
    c.drawRect(Offset.zero & s, _sheen);
    final last = lp;
    final pvx = ptr != null && last != null ? (ptr.dx - last.dx) / math.max(dt, 0.008) : 0.0;
    final pvy = ptr != null && last != null ? (ptr.dy - last.dy) / math.max(dt, 0.008) : 0.0;
    _gl.clear();
    for (final q in p) {
      if (_clPush(tap, q.x, q.y, 120, 300)) {
        q.vx += _clKx;
        q.vy += _clKy;
      }
      if (ptr != null) {
        final dx = q.x - ptr.dx, dy = q.y - ptr.dy, d = math.sqrt(dx * dx + dy * dy);
        if (d < 70) {
          final k = (1 - d / 70) * dt * 5;
          q.vx += pvx * k;
          q.vy += pvy * k;
        }
      }
      final n = math.sin(q.x * 0.012 + t * 0.3) * 2 + math.cos(q.y * 0.02 - t * 0.2) * 2, spd = 6 + q.z * 12;
      q.vx += (math.cos(n) * spd - q.vx) * dt * 1.3;
      q.vy += (math.sin(n) * spd - 5 - q.z * 6 - q.vy) * dt * 1.3;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      if (q.y < -4) q.y = h + 4;
      if (q.y > h + 4) q.y = -4;
      if (q.x < -4) q.x = w + 4;
      if (q.x > w + 4) q.x = -4;
      final tw = 0.5 + 0.5 * math.sin(t * (1 + q.z * 3) + q.ph);
      if (q.z > 0.88) {
        _g.glow(q.x, q.y, 6, dark ? 0xFFD36B : 0xE8A33D, dark ? tw * 0.8 : tw * 0.45);
        _gl
          ..add(q.x)
          ..add(q.y)
          ..add(tw);
      } else {
        final col = dark ? (q.z > 0.5 ? 0xFFE9A8 : 0xE8A33D) : (q.z > 0.5 ? 0xC98A2E : 0xB0701A);
        _q.sq(q.x, q.y, 0.8 + q.z * 1.4, col, dark ? 0.22 + 0.6 * tw : 0.25 + 0.55 * tw);
      }
    }
    _q.flush(c);
    _g.flush(c, dark);
    for (var i = 0; i < _gl.length; i += 3) {
      _clGlint(c, _gl[i], _gl[i + 1], 2.8 * _gl[i + 2], _gl[i + 2], dark ? 0xFFFFFF : 0xB8741A);
    }
    lp = ptr;
  }
}

// ───────────── Дым (Fog) ─────────────
class _CFog extends _CBase {
  late Float32List st;
  late List<_ClP> p; // ph — фаза, a — прозрачность; ox/oy — пружины ниже
  final _ox = <Spring>[], _oy = <Spring>[];
  final _g = _ClAtlas(true), _q = _ClAtlas(false);
  final _moon = Paint()..color = const Color(0xFFE8EEFF);
  static const _bgc = [Color(0xFF0B0E16), Color(0xFF1A2030), Color(0xFF0E1118)];

  @override
  void setup(Size s) {
    final w = s.width, h = s.height;
    st = _clStars(w, h, 30, 0.5);
    p = List.generate(
        28,
        (i) => _ClP(
            x: _rnd() * w,
            y: h * (0.25 + _rnd() * 0.8),
            r: h * (0.34 + _rnd() * 0.42),
            vx: (3 + _rnd() * 7) * (i.isOdd ? 1 : -1),
            a: 0.1 + _rnd() * 0.12,
            ph: _rnd() * 9));
    _ox
      ..clear()
      ..addAll(List.generate(28, (_) => Spring()));
    _oy
      ..clear()
      ..addAll(List.generate(28, (_) => Spring()));
  }

  @override
  void resize(Size s, double sx, double sy) {
    _clScale(st, 3, sx, sy);
    for (final q in p) {
      q.x *= sx;
      q.y *= sy;
      q.r *= sy;
    }
  }

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width, h = s.height;
    bg(c, s, dark, _bgc);
    _clStarsDraw(_q, st, t, 0.3);
    _q.flush(c);
    _glowS(c, Offset(w * 0.8, h * 0.26), h * 0.55, const Color(0xFFBFD0FF), 0.4, true);
    c.drawCircle(Offset(w * 0.8, h * 0.26), math.max(4.0, h * 0.045), _moon);
    for (var i = 0; i < p.length; i++) {
      final q = p[i], ox = _ox[i], oy = _oy[i];
      q.x += q.vx * dt;
      if (q.x > w + q.r) q.x = -q.r;
      if (q.x < -q.r) q.x = w + q.r;
      var tx = 0.0, ty = 0.0;
      if (ptr != null) {
        final dx = q.x - ptr.dx, dy = q.y - ptr.dy;
        var d = math.sqrt(dx * dx + dy * dy);
        if (d == 0) d = 1;
        final k = math.max(0.0, 1 - d / (q.r + 50)) * 52;
        tx = dx / d * k;
        ty = dy / d * k;
      }
      if (_clPush(tap, q.x, q.y, q.r + 90, 500)) {
        ox.v += _clKx;
        oy.v += _clKy;
      }
      ox
        ..t = tx
        ..step(dt, 14, 5);
      oy
        ..t = ty
        ..step(dt, 14, 5);
      _g.glow(q.x + ox.x, q.y + oy.x + math.sin(t * 0.3 + q.ph) * 6, q.r, 0xAEB8CC, q.a);
    }
    _g.flush(c);
  }
}

// ───────────── Мишки (Bears) ─────────────
class _ClBear {
  _ClBear(this.x, this.tg, this.tm, this.nb, this.s);
  double x, tm, nb, bl = 0, look = 0;
  int tg;
  final double s;
  final up = Spring(), tilt = Spring(), e = [Spring(), Spring()];
}

class _CBears extends _CBase {
  final b = <_ClBear>[], hs = <_ClP>[];
  double sc = 1;
  static final Path _heartP = _heart(1);
  static final Paint _ear = Paint()..color = const Color(0xFF9C6B3F),
      _dk = Paint()..color = const Color(0xFF4A2F18),
      _cheek = Paint()..color = const Color(0x61FF8C78),
      _wh = Paint()..color = const Color(0xFFFFFFFF),
      _muz = Paint()..color = const Color(0xFFE8C9A0),
      _head = Paint()..shader = _linG(const Offset(0, -27), const Offset(0, 27), const [Color(0xFFAD7A4A), Color(0xFF8A5A32)]),
      _lid = _stroke(const Color(0xFF4A2F18), 1.6);
  final _hp = Paint(), _ledge = Paint(), _lh = Paint();
  static const _bgd = [Color(0xFF3A1E12), Color(0xFF6B3A1A), Color(0xFF2A150C)];
  static const _bgl = [Color(0xFFFFE6BF), Color(0xFFFFD29A), Color(0xFFF7C487)];

  @override
  double get warmSecs => 1.5;

  @override
  void setup(Size s) {
    final w = s.width, n = math.max(4, (w / 72).round());
    sc = _clamp(s.height / 200, 0.5, 1.05);
    hs.clear();
    b
      ..clear()
      ..addAll(List.generate(n, (i) => _ClBear((i + 0.5) / n * w + (_rnd() - 0.5) * 14, i % 2, _rnd() * 2, 1 + _rnd() * 3, 0.8 + _rnd() * 0.35)));
  }

  @override
  void resize(Size s, double sx, double sy) {
    if (math.max(4, (s.width / 72).round()) != b.length) {
      setup(s);
      return;
    }
    sc = _clamp(s.height / 200, 0.5, 1.05);
    for (final q in b) {
      q.x *= sx;
    }
    for (final q in hs) {
      q.x *= sx;
      q.y *= sy;
    }
  }

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width, h = s.height;
    bg(c, s, dark, dark ? _bgd : _bgl);
    if (dark) {
      _glowS(c, Offset(w * 0.3, h * 0.2), h, const Color(0xFFFFB23F), 0.3, true);
      _glowS(c, Offset(w * 0.8, h * 0.5), h * 0.8, const Color(0xFFFF7A4A), 0.2, true);
    } else {
      _glowS(c, Offset(w * 0.3, h * 0.2), h, const Color(0xFFFFF3D6), 0.55);
      _glowS(c, Offset(w * 0.8, h * 0.5), h * 0.8, const Color(0xFFFFB48A), 0.2);
    }
    if (tap != null) hs.add(_ClP(x: tap.dx, y: tap.dy, sd: _rnd() * 9));
    if (_rnd() < dt * 0.8) hs.add(_ClP(x: _rnd() * w, y: h * (0.5 + _rnd() * 0.3), sd: _rnd() * 9));
    final hc = dark ? 0xFF8A9A : 0xFF6F88;
    for (final q in hs) {
      q.age += dt;
      final k = (0.7 + math.min(1.0, q.age * 5) * 0.5) * sc;
      _hp.color = _cla(hc, math.max(0.0, 1 - q.age / 2.2) * 0.9);
      c.save();
      c.translate(q.x + math.sin(q.age * 3 + q.sd) * 6, q.y - q.age * 24 * sc);
      c.scale(k, k);
      c.drawPath(_heartP, _hp);
      c.restore();
    }
    hs.removeWhere((q) => q.age >= 2.2);
    for (final q in b) {
      final k = q.s * sc * 1.1;
      q.tm -= dt;
      if (q.tm <= 0) {
        q.tg = q.tg == 1 ? 0 : 1;
        q.tm = q.tg == 1 ? 1.8 + _rnd() * 3.5 : 0.5 + _rnd() * 1.5;
      }
      if (tap != null) {
        if ((tap.dx - q.x).abs() < 38 * k && tap.dy > h * 0.4) {
          q.tg = 0;
          q.tm = 0.9 + _rnd();
          q.up.v -= 4;
        } else {
          q.e[_rnd() < 0.5 ? 0 : 1].v += 240;
        }
      }
      q.up
        ..t = q.tg.toDouble()
        ..step(dt, 110, 8);
      for (final e in q.e) {
        e.step(dt, 260, 9);
      }
      q.nb -= dt;
      if (q.nb <= 0) {
        q.bl = 0.14;
        q.nb = 2 + _rnd() * 3.5;
      }
      q.bl = math.max(0.0, q.bl - dt);
      final lk = ptr != null ? _clamp((ptr.dx - q.x) / 70, -1, 1) : math.sin(t * 0.6 + q.x) * 0.4;
      q.look += (lk - q.look) * math.min(1.0, dt * 6);
      q.tilt
        ..t = q.look * 9
        ..step(dt, 50, 7);
      c.save();
      c.translate(q.x, h + 36 * k - q.up.x * 54 * k);
      c.rotate(q.tilt.x * _deg);
      c.scale(k, k);
      _bearHead(c, q);
      c.restore();
    }
    final lh = 12 * sc;
    _ledge.color = dark ? const Color(0xFF1E0F08) : const Color(0xFF6B3A1A);
    _lh.color = dark ? const Color(0x40FFBE78) : const Color(0x8CFFECC8);
    c.drawRect(Rect.fromLTWH(0, h - lh, w, lh), _ledge);
    c.drawRect(Rect.fromLTWH(0, h - lh, w, 1.2), _lh);
  }

  void _bearHead(Canvas c, _ClBear b) {
    for (var i = 0; i < 2; i++) {
      final s = i == 0 ? -1.0 : 1.0;
      c.save();
      c.translate(s * 23, -19);
      c.rotate(s * b.e[i].x * _deg);
      c.drawCircle(const Offset(0, -3), 11, _ear);
      c.drawCircle(const Offset(0, -2), 6, _dk);
      c.restore();
    }
    c.drawOval(_ov(0, 0, 31, 27), _head);
    for (var i = 0; i < 2; i++) {
      final s = i == 0 ? -1.0 : 1.0;
      c.drawCircle(Offset(s * 19, -1), 4.6, _cheek);
      if (b.bl > 0) {
        c.drawLine(Offset(s * 11 - 3, -8), Offset(s * 11 + 3, -8), _lid);
      } else {
        c.drawCircle(Offset(s * 11 + b.look * 1.2, -8), 3.1, _dk);
        c.drawCircle(Offset(s * 11 - 1 + b.look * 1.2, -9), 1, _wh);
      }
    }
    c.drawOval(_ov(0, 2, 10, 7), _muz);
    c.drawOval(_ov(0, -2.2, 4, 2.8), _dk);
  }
}

// ───────────── Радуга (RainbowC) ─────────────
class _CRainbow extends _CBase {
  final g = Spring(0)..t = 1;
  double cx = 0;
  late List<_ClP> cl, dr;
  final _g = _ClAtlas(true);
  final _arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt;
  final _rain = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final _rp = Path();
  static const _rc = [0xFF3B30, 0xFF9500, 0xFFCC00, 0x34C759, 0x00C7BE, 0x007AFF, 0xAF52DE];
  static const _bgd = [Color(0xFF141E48), Color(0xFF3A4E9A), Color(0xFF8A7AC8)];
  static const _bgl = [Color(0xFF5E9CE6), Color(0xFF9CC6F2), Color(0xFFE4EEFA)];

  @override
  double get warmSecs => 1.5;

  @override
  void setup(Size s) {
    final w = s.width, h = s.height;
    cx = w * 0.5;
    cl = List.generate(9, (i) => _ClP(x: _rnd() * w, y: h * (0.7 + _rnd() * 0.3), r: h * (0.22 + _rnd() * 0.22), v: (2 + _rnd() * 5) * (i.isOdd ? 1 : -1)));
    dr = List.generate((w / 8).round(), (_) => _ClP(x: _rnd() * w, y: _rnd() * h, v: 70 + _rnd() * 70));
  }

  @override
  void resize(Size s, double sx, double sy) {
    cx *= sx;
    for (final q in cl) {
      q.x *= sx;
      q.y *= sy;
      q.r *= sy;
    }
    for (final q in dr) {
      q.x *= sx;
      q.y *= sy;
    }
  }

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width, h = s.height;
    bg(c, s, dark, dark ? _bgd : _bgl);
    if (dark) {
      _glowS(c, Offset(w * 0.85, h * 0.1), h * 0.9, const Color(0xFFFFD9A0), 0.4, true);
    } else {
      _glowS(c, Offset(w * 0.85, h * 0.1), h * 0.9, const Color(0xFFFFF4C8), 0.75);
    }
    if (tap != null) {
      cx = tap.dx;
      g
        ..x = 0
        ..v = 0;
    }
    g.step(dt, 26, 5);
    final gg = _clamp(g.x, 0, 1.08), cy = h * 1.06, rb = h * 0.84, bw = h * 0.036, sweep = math.pi * math.min(1.0, gg);
    if (sweep > 0) {
      _arc.strokeWidth = bw * 0.85;
      for (var i = 0; i < 7; i++) {
        final rr = rb * 1.34 + i * bw * 0.8;
        _arc.color = _cla(_rc[i], 0.16);
        c.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: rr), math.pi, sweep, false, _arc);
      }
      _arc.strokeWidth = bw + 0.6;
      for (var i = 0; i < 7; i++) {
        final rr = rb - i * bw;
        _arc.color = _cla(_rc[i], 0.82);
        c.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: rr), math.pi, sweep, false, _arc);
      }
    }
    if (g.v.abs() > 0.05 && gg < 1) {
      final a = math.pi + math.pi * gg, r = rb - 3 * bw;
      _glowS(c, Offset(cx + math.cos(a) * r, cy + math.sin(a) * r), bw * 6, const Color(0xFFFFFFFF), 0.8, true);
    }
    _rain.color = dark ? const Color(0x29FFFFFF) : const Color(0x59FFFFFF);
    _rp.reset();
    for (final d in dr) {
      d.y += d.v * dt;
      d.x -= d.v * 0.2 * dt;
      if (d.y > h) {
        d.y = -8;
        d.x = _rnd() * (w + 20);
      }
      _rp
        ..moveTo(d.x, d.y)
        ..lineTo(d.x - 1.6, d.y + 8);
    }
    c.drawPath(_rp, _rain);
    for (final q in cl) {
      q.x += q.v * dt;
      if (q.x > w + q.r) q.x = -q.r;
      if (q.x < -q.r) q.x = w + q.r;
      _g.glow(q.x, q.y + math.sin(t * 0.4 + q.r) * 3, q.r, 0xFFFFFF, dark ? 0.4 : 0.55);
    }
    _g.flush(c);
  }
}

// ───────────── Светлячки (Fireflies) ─────────────
class _CFireflies extends _CBase {
  double sc = 1;
  late List<_ClP> f; // ph — фаза вспышки, v — собственная частота
  final gr = <_ClStem>[];
  final _g = _ClAtlas(true);
  final _dot = Paint(), _gp = [_stroke(const Color(0xFF0A1A10), 1.8), _stroke(const Color(0xFF123420), 1.8)], _paths = [Path(), Path()];
  static const _bgc = [Color(0xFF050A14), Color(0xFF0A1A1E), Color(0xFF0E2416)];

  void _grass(double w) {
    final n = (w / 6).round();
    while (gr.length > n) {
      gr.removeLast();
    }
    for (var i = gr.length; i < n; i++) {
      gr.add(_ClStem(i * 6 + _rnd() * 5, (12 + _rnd() * 30) * sc, _rnd() * 9, i % 3 != 0 ? const Color(0xFF0A1A10) : const Color(0xFF123420)));
    }
  }

  @override
  void setup(Size s) {
    final w = s.width, h = s.height;
    sc = _clamp(h / 200, 0.55, 1.1);
    f = List.generate(_clamp(w / 15, 14, 30).round(),
        (_) => _ClP(x: _rnd() * w, y: h * (0.12 + _rnd() * 0.7), ph: _rnd() * _tau, v: 2.3 + _rnd() * 0.5, sd: _rnd() * 9));
    gr.clear();
    _grass(w);
  }

  @override
  void resize(Size s, double sx, double sy) {
    final nsc = _clamp(s.height / 200, 0.55, 1.1), k = nsc / sc;
    sc = nsc;
    for (final q in f) {
      q.x *= sx;
      q.y *= sy;
    }
    for (final g in gr) {
      g.h *= k;
    }
    _grass(s.width);
  }

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width, h = s.height;
    bg(c, s, dark, _bgc);
    _glowS(c, Offset(w * 0.2, h * 0.15), h * 0.8, const Color(0xFF3A6A8A), 0.3, true);
    var sx = 0.0, sy = 0.0;
    for (final q in f) {
      sx += math.cos(q.ph);
      sy += math.sin(q.ph);
    }
    sx /= f.length;
    sy /= f.length;
    for (final q in f) {
      if (tap != null) {
        q.ph = _rnd() * _tau;
        if (_clPush(tap, q.x, q.y, 160, 260)) {
          q.vx += _clKx;
          q.vy += _clKy;
        }
      }
      q.ph += (q.v + 0.95 * (sy * math.cos(q.ph) - sx * math.sin(q.ph))) * dt;
      var ax = math.cos(t * 0.5 + q.sd * 3) * 12, ay = math.sin(t * 0.43 + q.sd * 5) * 9;
      if (ptr != null) {
        final dx = ptr.dx - q.x, dy = ptr.dy - q.y;
        var d = math.sqrt(dx * dx + dy * dy);
        if (d == 0) d = 1;
        if (d > 18) {
          ax += dx / d * 26;
          ay += dy / d * 26;
        }
      }
      q.vx += (ax - q.vx * 0.9) * dt;
      q.vy += (ay - q.vy * 0.9) * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      if (q.x < 4) q.vx += 30 * dt;
      if (q.x > w - 4) q.vx -= 30 * dt;
      if (q.y < 4) q.vy += 30 * dt;
      if (q.y > h * 0.86) q.vy -= 30 * dt;
      q.a = _pow(math.max(0.0, math.sin(q.ph)), 6);
      _g.glow(q.x, q.y, (5 + 11 * q.a) * sc, 0xD8FF6B, 0.14 + 0.86 * q.a);
    }
    _g.flush(c, true);
    for (final q in f) {
      _dot.color = _cla(0xF6FFD0, 0.4 + 0.6 * q.a);
      c.drawCircle(Offset(q.x, q.y), 1.1 * sc, _dot);
    }
    _paths[0].reset();
    _paths[1].reset();
    for (var i = 0; i < gr.length; i++) {
      final k = gr[i];
      if (ptr != null && ptr.dy > h - k.h - 26) {
        final d = k.x - ptr.dx;
        if (d.abs() < 34) k.s.v += _clSign(d) * (1 - d.abs() / 34) * 400 * dt;
      }
      k.s.step(dt, 40, 4);
      final sw = math.sin(t * 1.1 + k.ph) * 3 + k.s.x;
      _paths[i % 3 != 0 ? 0 : 1]
        ..moveTo(k.x, h + 1)
        ..quadraticBezierTo(k.x + sw * 0.4, h - k.h * 0.6, k.x + sw * 2, h - k.h);
    }
    c.drawPath(_paths[0], _gp[0]);
    c.drawPath(_paths[1], _gp[1]);
  }
}

// ───────────── Золотой салют (GoldWillow) ─────────────
class _ClWp {
  _ClWp(this.x, this.y, this.vx, this.vy, this.life, this.sd);
  double x, y, vx, vy, age = 0, acc = 1 / 60;
  final double life, sd;
  final tr = Float32List(28);
  int tn = 0;

  /// Точка шлейфа раз в 1/60 с, как у референса на 60 Гц: на 120 Гц шлейф
  /// иначе стал бы вдвое короче, на 30 Гц — вдвое длиннее.
  void sample(double px, double py, double dt) {
    acc += dt;
    var k = math.min(2, (acc * 60).floor());
    acc -= k / 60;
    if (acc > 1 / 60) acc = 0;
    for (; k > 0; k--) {
      if (tn == 14) {
        for (var j = 0; j < 26; j++) {
          tr[j] = tr[j + 2];
        }
        tn = 13;
      }
      final u = k == 2 ? 0.5 : 1.0;
      tr[tn * 2] = _lerp(px, x, u);
      tr[tn * 2 + 1] = _lerp(py, y, u);
      tn++;
    }
  }
}

class _CGoldWillow extends _CBase {
  final r = <_ClRk>[], p = <_ClWp>[], fl = <_ClP>[];
  double tm = 0.3, sc = 1, wy = 0;
  late Float32List st;
  final _g = _ClAtlas(true), _q = _ClAtlas(false);
  final _water = Paint()..color = const Color(0xFF06050C), _line = Paint()..color = const Color(0x38E8A33D);
  final _tp = _stroke(const Color(0xFFE8A33D), 1.1)..blendMode = BlendMode.plus;
  final _dp = Paint()..blendMode = BlendMode.plus;
  final _path = Path();
  static const _bgc = [Color(0xFF070610), Color(0xFF14101E), Color(0xFF1E1608)];

  @override
  double get warmSecs => 1.8;

  @override
  void setup(Size s) {
    sc = _clamp(s.height / 200, 0.55, 1.2);
    wy = s.height * 0.8;
    st = _clStars(s.width, s.height, 36, 0.6);
  }

  @override
  void resize(Size s, double sx, double sy) {
    sc = _clamp(s.height / 200, 0.55, 1.2);
    wy = s.height * 0.8;
    _clScale(st, 3, sx, sy);
  }

  void _launch(double x, double y) => r.add(_ClRk(x + (_rnd() - 0.5) * 40, x, math.min(y, wy - 20 * sc), 0.65 + _rnd() * 0.3));

  void _refl(double t, double x, double y, double a) =>
      _g.glow(x + math.sin(t * 5 + y) * 1.5, wy + (wy - y) * 0.3, 4 * sc, 0xE8A33D, a * 0.3);

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width, h = s.height;
    bg(c, s, dark, _bgc);
    _clStarsDraw(_q, st, t, 0.3);
    _q.flush(c);
    c.drawRect(Rect.fromLTWH(0, wy, w, h - wy), _water);
    c.drawRect(Rect.fromLTWH(0, wy, w, 1), _line);
    tm -= dt;
    if (tm <= 0) {
      _launch(w * (0.12 + _rnd() * 0.76), h * (0.16 + _rnd() * 0.26));
      tm = 1 + _rnd() * 1.3;
    }
    if (tap != null) _launch(tap.dx, tap.dy);
    for (final f in fl) {
      _g.glow(f.x, f.y, 80 * sc, 0xFFD36B, f.a * 0.5);
      _g.glow(f.x, wy + 6, 60 * sc, 0xE8A33D, f.a * 0.15);
      f.a -= dt * 2.6;
    }
    fl.removeWhere((f) => f.a <= 0);
    for (final q in r) {
      q.t += dt;
      final u = math.min(1.0, q.t / q.dur), e = 1 - (1 - u) * (1 - u), x = _lerp(q.sx, q.tx, e), y = _lerp(wy, q.ty, e);
      _g.glow(x, y, 5, 0xFFE9C0, 1);
      _refl(t, x, y, 1);
      if (u >= 1) {
        q.dead = true;
        fl.add(_ClP(x: x, y: y, a: 1));
        for (var i = 0; i < 46; i++) {
          final a = i / 46 * _tau + _rnd() * 0.14, v = (34 + _rnd() * 56) * sc;
          p.add(_ClWp(x, y, math.cos(a) * v, math.sin(a) * v - 12 * sc, 1.9 + _rnd() * 0.9, _rnd() * 9));
        }
      }
    }
    r.removeWhere((q) => q.dead);
    _g.flush(c, true);
    for (final q in p) {
      q.age += dt;
      final dr = 1 - dt * 2.1;
      q.vx *= dr;
      q.vy = q.vy * dr + 52 * sc * dt;
      final ox = q.x, oy = q.y, tr = q.tr;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      q.sample(ox, oy, dt);
      final u = q.age / q.life, a = 1 - u;
      if (a > 0.003 && q.tn > 1) {
        _path
          ..reset()
          ..moveTo(tr[0], tr[1]);
        for (var k = 1; k < q.tn; k++) {
          _path.lineTo(tr[k * 2], tr[k * 2 + 1]);
        }
        _tp.color = _cla(0xE8A33D, a * 0.55);
        c.drawPath(_path, _tp);
      }
      if (u > 0.35 && math.sin(t * 40 + q.sd * 7) > 0.55) {
        _clGlint(c, q.x, q.y, 2.4 * sc, a, 0xFFFFFF, true);
      } else if (a > 0.003) {
        _dp.color = _cla(0xFFF3C8, a);
        c.drawCircle(Offset(q.x, q.y), 0.9, _dp);
      }
      // Отражается примерно каждая третья искра — дешевле, а читается так же.
      if (q.sd < 3.2) _refl(t, q.x, q.y, a);
    }
    p.removeWhere((q) => q.age >= q.life || q.y >= wy);
    _g.flush(c, true);
  }
}

// ───────────── Галактика (Galaxy) ─────────────
class _CGalaxy extends _CBase {
  final tx = Spring(0.42), ty = Spring(-0.3);
  double rp = -1, rot = 0;
  int n = 0;
  late Float32List su, sa, ss, so, sov, sph, st;
  late Int32List scol;
  final _q = _ClAtlas(false);
  static const _arm = [Color(0xFF7A5CFF), Color(0xFFFF4FD8), Color(0xFF3DA5FF)];
  static const _c4 = [0xBFD0FF, 0xFFFFFF, 0xFFB8E0, 0x9AD8FF];
  static const _bgc = [Color(0xFF03030A), Color(0xFF0A0820), Color(0xFF05040E)];

  @override
  void setup(Size s) {
    final w = s.width, h = s.height;
    rot = _rnd() * 9;
    n = _clamp(w * h / 42, 500, 1500).round();
    su = Float32List(n);
    sa = Float32List(n);
    ss = Float32List(n);
    so = Float32List(n);
    sov = Float32List(n);
    sph = Float32List(n);
    scol = Int32List(n);
    for (var i = 0; i < n; i++) {
      final u = _pow(_rnd(), 0.75);
      su[i] = u;
      sa[i] = (i % 3) * _tau / 3 + u * 4.4 + (_rnd() - 0.5) * (0.45 + u * 0.6);
      scol[i] = u < 0.22 ? 0xFFE9C0 : _c4[math.min(3, (_rnd() * 4).floor())];
      ss[i] = 0.8 + _rnd() * 1.3;
      sph[i] = _rnd() * 9;
    }
    st = _clStars(w, h, 50, 1);
  }

  @override
  void resize(Size s, double sx, double sy) => _clScale(st, 3, sx, sy);

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final w = s.width, h = s.height;
    bg(c, s, dark, _bgc);
    _clStarsDraw(_q, st, t, 0.3);
    _q.flush(c);
    // Центр — сам портрет (в референсе w/2, h·0.46).
    final cx = av == Offset.zero ? w / 2 : av.dx, cy = av == Offset.zero ? h * 0.46 : av.dy, gr = w * 0.52;
    tx.t = ptr != null ? 0.22 + ptr.dy / h * 0.5 : 0.42;
    ty.t = ptr != null ? (ptr.dx / w - 0.5) * 0.9 : -0.3 + math.sin(t * 0.12) * 0.12;
    tx.step(dt, 30, 7);
    ty.step(dt, 30, 7);
    if (tap != null) rp = 0;
    if (rp >= 0) {
      rp += dt * 1.1;
      if (rp > 1.2) rp = -1;
    }
    rot += dt * 0.07;
    final co = math.cos(ty.x), si = math.sin(ty.x), sq = tx.x;
    for (var i = 0; i < 9; i++) {
      final u = 0.1 + i / 9 * 0.8, r = (0.2 + u * 0.8) * gr, a = (i % 3) * _tau / 3 + u * 4.4 + rot / (0.3 + u);
      final x = math.cos(a) * r, y = math.sin(a) * r * sq;
      _glowS(c, Offset(cx + x * co - y * si, cy + x * si + y * co), gr * 0.3, _arm[i % 3], 0.36, true);
    }
    _glowS(c, Offset(cx, cy), gr * 0.62, const Color(0xFFFFD9A0), 0.55, true);
    final wave = rp >= 0, win = dt * 1.2, tw = t * 1.5;
    for (var i = 0; i < n; i++) {
      final u = su[i];
      if (wave && (rp - u).abs() < win) sov[i] += 0.9;
      sov[i] += (-so[i] * 34 - sov[i] * 4) * dt;
      so[i] += sov[i] * dt;
      final r = (0.2 + u * 0.8 + so[i]) * gr, a = sa[i] + rot / (0.3 + u);
      final x = math.cos(a) * r, y = math.sin(a) * r * sq;
      _q.sq(cx + x * co - y * si, cy + x * si + y * co, ss[i], scol[i], (0.5 + 0.5 * (1 - u)) * (0.65 + 0.35 * math.sin(tw + sph[i])));
    }
    _q.flush(c);
    _glowS(c, Offset(cx, cy), gr * 0.26, const Color(0xFFFFFFFF), 0.9, true);
  }
}

// ───────────── Северное сияние (AuroraSky) ─────────────
ui.Image? _clRayImg;
ui.Image _clRay() {
  final cached = _clRayImg;
  if (cached != null) return cached;
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(
      const Rect.fromLTWH(0, 0, 4, 96),
      Paint()
        ..shader = _linG(Offset.zero, const Offset(0, 96), const [
          Color(0x008A5CF0),
          Color(0x808A5CF0),
          Color(0xF22FDCA0),
          Color(0x8019C3A6),
          Color(0x0019C3A6),
        ], const [
          0.0,
          0.28,
          0.62,
          0.86,
          1.0
        ]));
  return _clRayImg = rec.endRecording().toImageSync(4, 96);
}

class _CAuroraSky extends _CBase {
  int n = 0;
  late Float32List b, bv, st;
  final surge = Spring();
  final _mt = Path();
  final _rp = Paint()
    ..blendMode = BlendMode.plus
    ..filterQuality = FilterQuality.low;
  final _q = _ClAtlas(false);
  final _mf = Paint()..color = const Color(0xFF03070D), _ms = _stroke(const Color(0x292FDCA0), 1, StrokeCap.butt);
  static const _bgc = [Color(0xFF020814), Color(0xFF06142A), Color(0xFF0A2030)];
  static const _src = Rect.fromLTWH(0, 0, 4, 96);

  void _mount(Size s) {
    final w = s.width, h = s.height, m = (w / 12).ceil() + 2;
    _mt
      ..reset()
      ..moveTo(0, h);
    for (var i = 0; i < m; i++) {
      _mt.lineTo(i * 12 - 6, h * (0.78 - 0.2 * math.sin(i * 0.9).abs() * (0.45 + 0.55 * math.sin(i * 0.37 + 1).abs())));
    }
    _mt
      ..lineTo(w, h)
      ..close();
  }

  @override
  void setup(Size s) {
    n = (s.width / 4).ceil() + 1;
    b = Float32List(n);
    bv = Float32List(n);
    st = _clStars(s.width, s.height, 60, 0.7);
    _mount(s);
  }

  @override
  void resize(Size s, double sx, double sy) {
    final nn = (s.width / 4).ceil() + 1;
    if (nn != n) {
      final m = math.min(n, nn);
      b = Float32List(nn)..setRange(0, m, b);
      bv = Float32List(nn)..setRange(0, m, bv);
      n = nn;
    }
    _clScale(st, 3, sx, sy);
    _mount(s);
  }

  @override
  void paint(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? ptr) {
    final h = s.height;
    bg(c, s, dark, _bgc);
    _clStarsDraw(_q, st, t, 0.5);
    _q.flush(c);
    if (tap != null) {
      surge.v += 5;
      final i0 = (tap.dx / 4).round();
      for (var k = -6; k <= 6; k++) {
        final j = i0 + k;
        if (j >= 0 && j < n) bv[j] += (k < 0 ? -1 : 1) * 160 * (1 - k.abs() / 7);
      }
    }
    surge.step(dt, 20, 3);
    final k = 1 + _clamp(surge.x, -0.4, 2) * 0.6, img = _clRay();
    for (var i = 1; i < n - 1; i++) {
      var tg = 0.0;
      if (ptr != null && ptr.dy < h * 0.75) {
        final d = i * 4 - ptr.dx;
        if (d.abs() < 90) tg = _clSign(d) * (1 - d.abs() / 90) * 24;
      }
      bv[i] += ((tg - b[i]) * 38 - bv[i] * 4 + (b[i - 1] + b[i + 1] - 2 * b[i]) * 260) * dt;
    }
    for (var i = 0; i < n; i++) {
      b[i] += bv[i] * dt;
      final n1 = 0.5 + 0.5 * math.sin(i * 0.07 + t * 0.5) * math.sin(i * 0.023 - t * 0.21 + 2),
          n2 = 0.5 + 0.5 * math.sin(i * 0.19 - t * 0.9),
          n3 = 0.5 + 0.5 * math.sin(i * 0.41 + t * 1.3);
      final top = h * (0.04 + 0.2 * n2), bot = h * (0.46 + 0.2 * n1) * (0.9 + 0.1 * k);
      final a = _clamp((0.16 + 0.5 * n1 + 0.14 * n3) * k * 0.7, 0, 1);
      if (a <= 0.003) continue;
      _rp.color = Color.fromRGBO(0, 0, 0, a);
      c.drawImageRect(img, _src, Rect.fromLTWH(i * 4 + b[i] - 1, top, 6, bot - top), _rp);
    }
    c.drawPath(_mt, _mf);
    c.drawPath(_mt, _ms);
  }
}
