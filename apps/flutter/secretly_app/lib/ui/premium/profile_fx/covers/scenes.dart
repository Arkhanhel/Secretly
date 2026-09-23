// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../../profile_fx.dart';

const _white = Color(0xFFFFFFFF);
Color _c(bool dark, int d, int l) => Color(dark ? d : l);

// ───────────── Снегопад ─────────────
class _Flake {
  _Flake(this.x, this.y, this.z, this.s);
  double x, y, z, s, vx = 0, vy = 0;
}

void _push(Offset? tap, double x, double y, double radius, double force, void Function(double, double) apply) {
  if (tap == null) return;
  final dx = x - tap.dx, dy = y - tap.dy, d = math.sqrt(dx * dx + dy * dy);
  if (d >= radius) return;
  final k = (1 - d / radius) * force / (d == 0 ? 1 : d);
  apply(dx * k, dy * k);
}

class _Snow extends CoverSim {
  late List<_Flake> f;
  @override
  void init(Size s) => f = List.generate(120, (_) => _Flake(_rnd() * s.width, _rnd() * s.height, _rnd(), _rnd() * 6));
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    _vFill(c, s, _c(dark, 0xFF0A1120, 0xFFC5D5EC), _c(dark, 0xFF172440, 0xFFE9EFF8));
    final wind = math.sin(t * 0.25) * 12, p = Paint();
    for (final q in f) {
      _push(tap, q.x, q.y, 110, 260, (ax, ay) {
        q.vx += ax;
        q.vy += ay;
      });
      q.vx *= 1 - dt * 2.2;
      q.vy *= 1 - dt * 2.2;
      q.y += ((10 + q.z * 34) + q.vy) * dt;
      q.x += (math.sin(t * 0.6 + q.s) * (4 + q.z * 10) + wind * q.z + q.vx) * dt;
      if (q.y > h + 4) {
        q.y = -4;
        q.x = _rnd() * w;
      }
      if (q.x > w + 4) q.x = -4;
      if (q.x < -4) q.x = w + 4;
      p.color = _op(_white, dark ? 0.2 + q.z * 0.7 : 0.55 + q.z * 0.45);
      c.drawCircle(Offset(q.x, q.y), 0.6 + q.z * 2.1, p);
    }
  }
}

// ───────────── Сияние ─────────────
class _Aurora extends CoverSim {
  final sp = Spring();
  late List<List<double>> stars;
  @override
  void init(Size s) => stars = List.generate(60, (_) => [_rnd(), _rnd() * 0.7, _rnd()]);
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    if (tap != null) sp.v += 6;
    sp.step(dt, 40, 6);
    _vFill(c, s, _c(dark, 0xFF040C16, 0xFFEAF7F4), _c(dark, 0xFF0B1B2B, 0xFFF2EEFF));
    if (dark) {
      for (final st in stars) {
        c.drawRect(Rect.fromLTWH(st[0] * w, st[1] * h, 1.2, 1.2), _fill(_op(_white, 0.25 + 0.5 * math.max(0.0, math.sin(t * 1.5 + st[2] * 9)))));
      }
    }
    const cols = [Color(0xFF19C3A6), Color(0xFF2F8FE0), Color(0xFF8A5CF0)];
    for (var k = 0; k < 3; k++) {
      final pts = <Offset>[
        for (double x = -20; x <= w + 20; x += 10)
          Offset(x, h * (0.3 + k * 0.08) + math.sin(x * 0.011 + t * 0.32 * (1 + k * 0.35) + k * 2) * 24 + math.sin(x * 0.028 - t * 0.55 + k) * 9)
      ];
      final path = _smoothOpen(pts);
      for (final l in const [[18.0, 0.35, 23.0], [5.0, 0.6, 7.0]]) {
        c.drawPath(
            path,
            _stroke(_op(cols[k], l[1] * (dark ? 1.2 : 0.8) * (1 + sp.x * 0.25)), l[0] * (1 + sp.x * 0.15))
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, l[2])
              ..blendMode = dark ? BlendMode.plus : BlendMode.srcOver);
      }
    }
  }
}

// ───────────── Угли ─────────────
class _Em {
  double x = 0, y = 0, vy = 0, vx = 0, age = 0, life = 4, r = 1, sd = 0;
}

class _Embers extends CoverSim {
  late List<_Em> p;
  int bi = 0;
  void _reset(_Em e, Size s) => e
    ..x = _rnd() * s.width
    ..y = s.height + 6
    ..vy = -18 - _rnd() * 40
    ..vx = 0
    ..age = 0
    ..life = 3 + _rnd() * 3;
  @override
  void init(Size s) => p = List.generate(
      70,
      (_) => _Em()
        ..x = _rnd() * s.width
        ..y = _rnd() * s.height
        ..vy = -20 - _rnd() * 40
        ..age = _rnd() * 4
        ..life = 3 + _rnd() * 3
        ..r = 0.6 + _rnd() * 1.6
        ..sd = _rnd() * 6);
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = ui.Gradient.radial(Offset(w / 2, h * 1.1), h * 1.2,
              dark ? const [Color(0xFF5A1E0A), Color(0xFF221008), Color(0xFF0E0705)] : const [Color(0xFFFFD2B0), Color(0xFFFFEDE0), Color(0xFFFFF6EE)], [0.0, dark ? 0.55 : 0.6, 1.0]));
    if (tap != null) {
      for (var i = 0; i < 18; i++) {
        p[bi = (bi + 1) % p.length]
          ..x = tap.dx
          ..y = tap.dy
          ..vy = -60 - _rnd() * 90
          ..vx = (_rnd() - 0.5) * 140
          ..age = 0
          ..life = 1.2 + _rnd() * 1.5;
      }
    }
    final mode = dark ? BlendMode.plus : BlendMode.srcOver;
    for (final e in p) {
      e.age += dt;
      e.vx *= 1 - dt * 1.5;
      e.x += (math.sin(e.age * 2 + e.sd) * 14 + e.vx) * dt;
      e.y += e.vy * dt;
      if (e.age > e.life || e.y < -10) _reset(e, s);
      final u = e.age / e.life, fl = 0.7 + 0.3 * math.sin(t * 12 + e.sd * 5);
      _glow(c, Offset(e.x, e.y), e.r * 7 * (1 - u * 0.5), dark ? const Color(0xFFFF963C) : const Color(0xFFEB6428),
          math.max(0.0, u < 0.1 ? u / 0.1 : 1 - u) * fl * (dark ? 1 : 0.8), mode);
    }
  }
}

// ───────────── Меш ─────────────
class _Mesh extends CoverSim {
  final b = List.generate(4, (i) => [_rnd() * 6, 0.13 + i * 0.04, 0.11 + i * 0.05]);
  final ox = List.generate(4, (_) => Spring()), oy = List.generate(4, (_) => Spring());
  @override
  void init(Size s) {}
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    c.drawRect(Offset.zero & s, _fill(_c(dark, 0xFF0E0B1E, 0xFFF7F3FF)));
    final cols = dark
        ? const [Color(0xFFFF3D8B), Color(0xFF6A4DFF), Color(0xFF1FC8FF), Color(0xFFFF9F3D)]
        : const [Color(0xFFFFB3D1), Color(0xFFC7B8FF), Color(0xFFA8E6FF), Color(0xFFFFD8A8)];
    for (var i = 0; i < 4; i++) {
      if (tap != null) {
        ox[i].v += (tap.dx / w - 0.5) * 3;
        oy[i].v += (tap.dy / h - 0.5) * 3;
      }
      ox[i].step(dt, 20, 3);
      oy[i].step(dt, 20, 3);
      final o = Offset((0.5 + math.sin(t * b[i][1] + b[i][0]) * 0.38 + ox[i].x * 0.3) * w, (0.5 + math.cos(t * b[i][2] + b[i][0] * 1.3) * 0.36 + oy[i].x * 0.3) * h);
      final a = dark ? 0.85 : 0.9;
      c.drawRect(Offset.zero & s, Paint()..shader = ui.Gradient.radial(o, w * 0.55, [_op(cols[i], a), _op(cols[i], 0)]));
    }
  }
}

// ───────────── Звездопад ─────────────
class _Shoot {
  _Shoot(this.x, this.y) : vx = 360 + _rnd() * 120, vy = 150 + _rnd() * 60;
  double x, y, vx, vy, age = 0;
}

class _Stars extends CoverSim {
  late List<List<double>> st;
  final sh = <_Shoot>[];
  double next = 1;
  @override
  void init(Size s) => st = List.generate(150, (_) => [_rnd() * s.width, _rnd() * s.height, _rnd() < 0.1 ? 1.4 : 0.5 + _rnd() * 0.6, _rnd() * 6, 0.5 + _rnd() * 2]);
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    _vFill(c, s, _c(dark, 0xFF050716, 0xFFC9D3FF), _c(dark, 0xFF171C3E, 0xFFF1E8FF));
    final col = _c(dark, 0xFFFFFFFF, 0xFF5B4BC8);
    for (final q in st) {
      c.drawCircle(Offset(q[0], q[1]), q[2], _fill(_op(col, (dark ? 0.3 : 0.25) + (dark ? 0.7 : 0.45) * _pow(math.max(0.0, math.sin(t * q[4] + q[3])), 2))));
    }
    if (t > next) {
      sh.add(_Shoot(_rnd() * w * 0.6, _rnd() * h * 0.3));
      next = t + 2.5 + _rnd() * 3;
    }
    if (tap != null) sh.add(_Shoot(tap.dx - 60, tap.dy - 25));
    sh.removeWhere((q) => q.age >= 0.9);
    for (final q in sh) {
      q.age += dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      final n = math.sqrt(q.vx * q.vx + q.vy * q.vy), a = math.sin(math.pi * q.age / 0.9);
      final end = Offset(q.x - q.vx / n * 70, q.y - q.vy / n * 70);
      c.drawLine(Offset(q.x, q.y), end, _stroke(_white, 1.8)..shader = _linG(Offset(q.x, q.y), end, [_op(col, a), _op(col, 0)]));
    }
  }
}

// ───────────── Синтвейв ─────────────
class _Grid extends CoverSim {
  final v = Spring(0.35);
  double z = 0;
  @override
  void init(Size s) {}
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    if (tap != null) v.x += 2.2;
    v.t = 0.35;
    v.step(dt, 6, 4);
    z += dt * v.x;
    final hz = h * 0.46, skyB = _c(dark, 0xFF4A0F55, 0xFFFFC6DF);
    c.drawRect(Rect.fromLTWH(0, 0, w, hz), Paint()..shader = _linG(Offset.zero, Offset(0, hz), [_c(dark, 0xFF10042A, 0xFFFFEAF4), skyB]));
    c.drawRect(Rect.fromLTWH(0, hz, w, h - hz), _fill(_c(dark, 0xFF0B0319, 0xFFF2E6FF)));
    final r = w * 0.2, cx = w / 2;
    c.save();
    c.clipRect(Rect.fromLTWH(0, 0, w, hz));
    c.drawCircle(Offset(cx, hz), r, Paint()..shader = _linG(Offset(0, hz - r), Offset(0, hz), [_op(const Color(0xFFFFD23F), dark ? 1 : 0.85), _op(const Color(0xFFFF3D8B), dark ? 1 : 0.85)]));
    for (var k = 0; k < 6; k++) {
      final y = hz - r * 0.55 + k * r * 0.1 + ((t * 6) % (r * 0.1));
      c.drawRect(Rect.fromLTWH(cx - r, y, r * 2, 1 + k * 0.7), _fill(skyB));
    }
    c.restore();
    final lc = _c(dark, 0xFFFF3DCB, 0xFFB04AD8);
    for (var i = -14; i <= 14; i++) {
      c.drawLine(Offset(cx + i * w * 0.018, hz), Offset(cx + i * w * 0.16, h), _stroke(_op(lc, dark ? 0.55 : 0.4), 1.2, StrokeCap.butt));
    }
    for (var k = 0; k < 12; k++) {
      final zz = ((k + z * 3) % 12) / 12, y = hz + (h - hz) * _pow(zz, 2.3);
      c.drawLine(Offset(0, y), Offset(w, y), _stroke(_op(lc, (dark ? 0.7 : 0.5) * zz), 1.2, StrokeCap.butt));
    }
  }
}

// ───────────── Боке ─────────────
class _Bk {
  double x = 0, y = 0, r = 0, vx = 0, vy = 0, ph = 0, age = -1;
  int ci = 0;
}

class _Bokeh extends CoverSim {
  late List<_Bk> b;
  int bi = 0;
  @override
  void init(Size s) => b = List.generate(
      22,
      (i) => _Bk()
        ..x = _rnd() * s.width
        ..y = _rnd() * s.height
        ..r = 12 + _rnd() * 34
        ..vx = (_rnd() - 0.5) * 8
        ..vy = (_rnd() - 0.5) * 6
        ..ci = i % 4
        ..ph = _rnd() * 6);
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    _vFill(c, s, _c(dark, 0xFF0D0914, 0xFFFFF4EA), _c(dark, 0xFF1E1328, 0xFFFBECF5));
    final cols = dark
        ? const [Color(0xFFFFC46B), Color(0xFFFF7AA8), Color(0xFFFF9F6B), Color(0xFFA68CFF)]
        : const [Color(0xFFF0A03C), Color(0xFFF05A8C), Color(0xFFF07846), Color(0xFF8264E6)];
    if (tap != null) {
      b[bi = (bi + 1) % b.length]
        ..x = tap.dx
        ..y = tap.dy
        ..r = 6
        ..age = 0;
    }
    for (final q in b) {
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      if (q.x < -60) q.x = w + 60;
      if (q.x > w + 60) q.x = -60;
      if (q.y < -60) q.y = h + 60;
      if (q.y > h + 60) q.y = -60;
      var r = q.r, a = (dark ? 0.35 : 0.22) * (0.6 + 0.4 * math.sin(t * 0.8 + q.ph));
      if (q.age >= 0) {
        q.age += dt;
        r = 6 + q.age * 50;
        a *= 1.6;
        if (q.age > 1) {
          q.age = -1;
          q.r = r;
        }
      }
      final o = Offset(q.x, q.y), col = cols[q.ci];
      c.drawCircle(o, r,
          Paint()
            ..blendMode = dark ? BlendMode.plus : BlendMode.srcOver
            ..shader = ui.Gradient.radial(o, r, [_op(col, a), _op(col, a * 0.8), _op(col, 0)], const [0.0, 0.75, 1.0]));
    }
  }
}

// ───────────── Океан ─────────────
class _Waves extends CoverSim {
  final rip = <List<double>>[];
  @override
  void init(Size s) {}
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    _vFill(c, s, _c(dark, 0xFF060E1D, 0xFFE4F1FF), _c(dark, 0xFF0C1E36, 0xFFF7FBFF));
    if (tap != null) rip.add([tap.dx, t]);
    rip.removeWhere((r) => t - r[1] >= 3);
    final cols = dark
        ? const [Color(0xFF0F3160), Color(0xFF154C8A), Color(0xFF1B68B4), Color(0xFF2A93DA)]
        : const [Color(0xFFCFE6FF), Color(0xFFA6D2FF), Color(0xFF76B6F2), Color(0xFF4C97E2)];
    for (var k = 0; k < 4; k++) {
      final y0 = h * (0.42 + k * 0.12), amp = 8 + k * 3.0, sp = (0.25 + k * 0.18) * (k.isOdd ? -1.0 : 1.0);
      final path = Path()..moveTo(0, h);
      for (double x = 0; x <= w + 6; x += 6) {
        var y = y0 + math.sin(x * (0.012 + k * 0.003) + t * sp * 2 + k) * amp + math.sin(x * 0.03 - t * 0.9 + k * 2) * 3;
        for (final r in rip) {
          final age = t - r[1], d = (x - r[0]).abs() - age * 120;
          y -= 16 * math.exp(-d * d / 900) * math.exp(-age * 1.1) * (1 - k * 0.15);
        }
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..close();
      c.drawPath(path, _fill(_op(cols[k], dark ? 0.9 : 0.85)));
    }
  }
}

// ───────────── Дождь по стеклу ─────────────
class _Slider {
  double x = 0, y = 0, r = 3, v = 0, vt = 0, sw = 0;
  final tr = <Offset>[];
}

class _RainGlass extends CoverSim {
  late List<List<double>> lights, dots;
  late List<_Slider> sl;
  int bi = 0;
  static const _lc = [Color(0xFFFFB45A), Color(0xFFFF5A8C), Color(0xFF5AAAFF), Color(0xFFFFE696)];
  @override
  void init(Size s) {
    final w = s.width, h = s.height;
    lights = List.generate(16, (_) => [_rnd() * w, h * (0.35 + _rnd() * 0.6), 20 + _rnd() * 40, (_rnd() * 4).floorToDouble()]);
    dots = List.generate(110, (_) => [_rnd() * w, _rnd() * h, 0.6 + _rnd() * 1.8]);
    sl = List.generate(9, (_) => _Slider()
      ..x = _rnd() * w
      ..y = _rnd() * h
      ..r = 2.4 + _rnd() * 2);
  }

  void _drop(Canvas c, double x, double y, double r, bool dark) {
    c.drawOval(_ov(x, y, r, r * 1.08), _fill(dark ? const Color(0x29AAC8FF) : const Color(0x59FFFFFF)));
    c.drawArc(Rect.fromCircle(center: Offset(x, y), radius: r * 0.9), 0.2, math.pi - 0.4, false,
        _stroke(dark ? const Color(0x59000000) : const Color(0x483C506E), math.max(0.6, r * 0.28)));
    c.drawCircle(Offset(x - r * 0.35, y - r * 0.4), math.max(0.5, r * 0.25), _fill(const Color(0xD9FFFFFF)));
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    _vFill(c, s, _c(dark, 0xFF0A111D, 0xFFBFCCDD), _c(dark, 0xFF1A2437, 0xFFE6ECF3));
    for (var i = 0; i < lights.length; i++) {
      final l = lights[i];
      _glow(c, Offset(l[0], l[1]), l[2], _lc[l[3].toInt()], (dark ? 0.5 : 0.35) * (0.8 + 0.2 * math.sin(t * 0.7 + i)));
    }
    for (final d in dots) {
      _drop(c, d[0], d[1], d[2], dark);
    }
    if (tap != null) {
      sl[bi = (bi + 1) % sl.length]
        ..x = tap.dx
        ..y = tap.dy
        ..r = 5
        ..v = 0
        ..vt = 120
        ..sw = 0.4
        ..tr.clear();
    }
    for (final q in sl) {
      q.sw -= dt;
      if (q.sw <= 0) {
        q.vt = _rnd() < 0.45 ? 0.0 : 50 + _rnd() * 110; // замирает или срывается вниз
        q.sw = 0.15 + _rnd() * 0.7;
      }
      q.v += (q.vt - q.v) * math.min(1.0, dt * 10);
      q.y += q.v * dt;
      q.x += math.sin(t * 3 + q.r * 9) * q.v * 0.2 * dt;
      q.tr.add(Offset(q.x, q.y));
      if (q.tr.length > 40) q.tr.removeAt(0);
      if (q.y > h + 12) {
        q
          ..x = _rnd() * w
          ..y = -10
          ..r = 2.4 + _rnd() * 2
          ..tr.clear();
      }
      if (q.tr.length > 2) {
        final path = Path()..moveTo(q.tr[0].dx, q.tr[0].dy);
        for (final o in q.tr) {
          path.lineTo(o.dx, o.dy);
        }
        c.drawPath(path, _stroke(dark ? const Color(0x24AAC8FF) : const Color(0x73FFFFFF), q.r * 0.9));
      }
      _drop(c, q.x, q.y, q.r, dark);
    }
  }
}

// ───────────── Светлячки ─────────────
class _Fireflies extends CoverSim {
  late List<List<double>> f, g;
  Offset? att;
  double attT = -9;
  @override
  void init(Size s) {
    f = List.generate(42, (_) => [_rnd() * s.width, _rnd() * s.height * 0.9, _rnd() * _tau, 8 + _rnd() * 14, _rnd() * 6, 0.6 + _rnd() * 1.2]);
    g = List.generate(70, (i) => [i / 69, 0.12 + _rnd() * 0.2, _rnd() * 6]);
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    _vFill(c, s, _c(dark, 0xFF050B0A, 0xFFF4F1DC), _c(dark, 0xFF0F2118, 0xFFDDEBCF));
    if (tap != null) {
      att = tap;
      attT = t;
    }
    final at = t - attT < 2.5 ? att : null;
    final mode = dark ? BlendMode.plus : BlendMode.srcOver;
    for (final q in f) {
      q[2] += math.sin(t * 0.7 + q[4]) * 1.4 * dt;
      var vx = math.cos(q[2]) * q[3], vy = math.sin(q[2]) * q[3] * 0.7;
      if (at != null) {
        final dx = at.dx - q[0], dy = at.dy - q[1], d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
        vx += dx / d * 40;
        vy += dy / d * 40;
      }
      q[0] += vx * dt;
      q[1] += vy * dt;
      if (q[0] < -10) q[0] = w + 10;
      if (q[0] > w + 10) q[0] = -10;
      if (q[1] < -10) q[1] = h * 0.9;
      if (q[1] > h) q[1] = 0;
      final b = _pow(math.max(0.0, math.sin(t * q[5] + q[4])), 3), o = Offset(q[0], q[1]);
      _glow(c, o, 6 + b * 10, dark ? const Color(0xFFD2FF6E) : const Color(0xFFF0AA14), (0.15 + b * 0.85) * (dark ? 1 : 0.9), mode);
      c.drawCircle(o, 1.2, _fill(_op(_c(dark, 0xFFF4FFD0, 0xFF8A5A00), 0.4 + b * 0.6)));
    }
    final gp = _stroke(_c(dark, 0xFF081410, 0xFF8FB27E), 3);
    for (final q in g) {
      final x = q[0] * w, hh = q[1] * h, sw = math.sin(t * 1.1 + q[2]) * 6;
      c.drawPath(Path()..moveTo(x, h + 2)..quadraticBezierTo(x + sw * 0.3, h - hh * 0.5, x + sw, h - hh), gp);
    }
  }
}

// ───────────── Мыльные пузыри ─────────────
class _Sb {
  double x = 0, y = 0, r = 10, v = 12, ph = 0;
  bool grow = false;
}

class _SoapBubbles extends CoverSim {
  late List<_Sb> b;
  final pops = <List<double>>[];
  int bi = 0;
  static const _film = [Color(0xCCFF6EBE), Color(0xCCFFE678), Color(0xCC6EE6FF), Color(0xCCAA78FF), Color(0xCCFF6EBE)];
  void _reset(_Sb q, Size s) => q
    ..x = _rnd() * s.width
    ..y = s.height + 40
    ..r = 10 + _rnd() * 24
    ..v = 12 + _rnd() * 18;
  @override
  void init(Size s) => b = List.generate(13, (_) => _Sb()
    ..x = _rnd() * s.width
    ..y = _rnd() * s.height
    ..r = 10 + _rnd() * 24
    ..v = 12 + _rnd() * 18
    ..ph = _rnd() * 6);
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    _vFill(c, s, _c(dark, 0xFF0B0D1C, 0xFFF3EEFF), _c(dark, 0xFF1C1432, 0xFFE6F5FF));
    if (tap != null) {
      final hit = b.where((q) => (Offset(q.x, q.y) - tap).distance < q.r + 4).firstOrNull;
      if (hit != null) {
        pops.add([hit.x, hit.y, hit.r, 0]);
        _reset(hit, s);
      } else {
        b[bi = (bi + 1) % b.length]
          ..x = tap.dx
          ..y = tap.dy
          ..r = 6
          ..v = 20
          ..grow = true;
      }
    }
    for (final q in b) {
      if (q.grow) {
        q.r += dt * 40;
        if (q.r > 22) q.grow = false;
      }
      q.y -= q.v * dt;
      q.x += math.sin(t * 0.9 + q.ph) * 10 * dt;
      if (q.y < -q.r - 10) _reset(q, s);
      final sq = math.sin(t * 3 + q.ph) * 0.04;
      c.save();
      c.translate(q.x, q.y);
      c.scale(1 + sq, 1 - sq);
      c.drawCircle(Offset.zero, q.r, _fill(dark ? const Color(0x0FA0BEFF) : const Color(0x40FFFFFF)));
      c.save();
      c.rotate(t * 0.6 + q.ph);
      c.drawCircle(Offset.zero, q.r, _stroke(_white, 1.8)..shader = ui.Gradient.sweep(Offset.zero, _film, _even(5)));
      c.restore();
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: q.r * 0.72), math.pi * 1.1, math.pi * 0.35, false, _stroke(const Color(0xCCFFFFFF), 1.6));
      c.drawCircle(Offset(q.r * 0.4, q.r * 0.45), q.r * 0.08, _fill(const Color(0xE6FFFFFF)));
      c.restore();
    }
    pops.removeWhere((p) => p[3] >= 0.35);
    for (final p in pops) {
      p[3] += dt;
      final u = p[3] / 0.35, col = _op(_c(dark, 0xFFC8DCFF, 0xFF788CDC), (1 - u) * (dark ? 0.9 : 0.8));
      for (var k = 0; k < 10; k++) {
        final a = k / 10 * _tau;
        c.drawCircle(Offset(p[0] + math.cos(a) * p[2] * (1 + u * 0.8), p[1] + math.sin(a) * p[2] * (1 + u * 0.8)), 1.6 * (1 - u), _fill(col));
      }
    }
  }
}

// ───────────── Топография ─────────────
class _Topo extends CoverSim {
  final hills = <List<double>>[];
  Float64List _f = Float64List(0);
  @override
  void init(Size s) {}
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    c.drawRect(Offset.zero & s, _fill(_c(dark, 0xFF0A0E13, 0xFFF4EFE4)));
    if (tap != null) hills.add([tap.dx, tap.dy, t]);
    hills.removeWhere((q) => t - q[2] >= 4);
    const cs = 9.0;
    final nx = (w / cs).ceil() + 1, ny = (h / cs).ceil() + 1, tt = t * 0.35;
    if (_f.length != nx * ny) _f = Float64List(nx * ny);
    for (var j = 0; j < ny; j++) {
      for (var i = 0; i < nx; i++) {
        final x = i * cs, y = j * cs;
        var v = math.sin(x * 0.017 + tt) + math.sin(y * 0.021 - tt * 0.8) + 1.2 * math.sin((x + y) * 0.011 + tt * 0.5) +
            0.8 * math.sin(math.sqrt((x - w * 0.3) * (x - w * 0.3) + (y - h * 0.6) * (y - h * 0.6)) * 0.022 - tt);
        for (final q in hills) {
          final a = t - q[2], e = math.min(1.0, a * 2) * math.exp(-a * 0.7), d2 = (x - q[0]) * (x - q[0]) + (y - q[1]) * (y - q[1]);
          v += 2.6 * e * math.exp(-d2 / 2200);
        }
        _f[j * nx + i] = v;
      }
    }
    var li = 0;
    for (var lv = -3.2; lv <= 4.4; lv += 0.4, li++) {
      final major = li % 5 == 0;
      final col = dark
          ? (major ? const Color(0xFF5CF2C0) : HSLColor.fromAHSL(0.45, (160 + li * 6) % 360.0, 0.8, 0.65).toColor())
          : (major ? const Color(0xFF8A6440) : const Color(0x668A6440));
      final path = Path();
      for (var j = 0; j < ny - 1; j++) {
        for (var i = 0; i < nx - 1; i++) {
          final a = _f[j * nx + i], b = _f[j * nx + i + 1], cc = _f[(j + 1) * nx + i + 1], d = _f[(j + 1) * nx + i];
          final x0 = i * cs, y0 = j * cs, p = <Offset>[];
          if ((a > lv) != (b > lv)) p.add(Offset(x0 + cs * (lv - a) / (b - a), y0));
          if ((b > lv) != (cc > lv)) p.add(Offset(x0 + cs, y0 + cs * (lv - b) / (cc - b)));
          if ((cc > lv) != (d > lv)) p.add(Offset(x0 + cs * (1 - (lv - cc) / (d - cc)), y0 + cs));
          if ((d > lv) != (a > lv)) p.add(Offset(x0, y0 + cs * (1 - (lv - d) / (a - d))));
          for (var k = 0; k + 1 < p.length; k += 2) {
            path
              ..moveTo(p[k].dx, p[k].dy)
              ..lineTo(p[k + 1].dx, p[k + 1].dy);
          }
        }
      }
      c.drawPath(path, _stroke(col, major ? 1.6 : 1));
    }
  }
}

// ───────────── Шёлк ─────────────
class _Silk extends CoverSim {
  final wv = <List<double>>[];
  @override
  void init(Size s) {}
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    _vFill(c, s, _c(dark, 0xFF0B0714, 0xFFFFF6F0), _c(dark, 0xFF170E24, 0xFFF6EEFF));
    if (tap != null) wv.add([tap.dx, t]);
    wv.removeWhere((q) => t - q[1] >= 3);
    final shader = _linG(Offset.zero, Offset(w, 0),
        dark ? const [Color(0xFF7A5CFF), Color(0xFFFF4F9A), Color(0xFFFFB23F)] : const [Color(0xFF8A6BE8), Color(0xFFE0508F), Color(0xFFE8902A)]);
    const n = 34;
    for (var i = 0; i < n; i++) {
      final u = i / (n - 1), path = Path();
      for (double x = -10; x <= w + 10; x += 8) {
        final env = math.sin(math.pi * _clamp(x / w, 0, 1));
        var y = h * (0.18 + u * 0.62) + math.sin(x * 0.007 + t * 0.35 + u * 2.4) * h * 0.2 * env + math.sin(x * 0.019 - t * 0.5 + u * 5) * 6 * env;
        for (final q in wv) {
          final a = t - q[1], d = x - q[0];
          y += 22 * math.exp(-d * d / 4000) * math.sin(a * 6 - u * 4) * math.exp(-a * 1.2);
        }
        x == -10 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      c.drawPath(path, _stroke(_op(_white, (dark ? 0.25 : 0.3) + 0.45 * math.sin(u * math.pi)), 1.1)..shader = shader);
    }
  }
}

// ───────────── Созвездия ─────────────
class _Plexus extends CoverSim {
  late List<List<double>> p;
  Offset? tp;
  double tpT = -9;
  @override
  void init(Size s) => p = List.generate(46, (_) => [_rnd() * s.width, _rnd() * s.height, (_rnd() - 0.5) * 16, (_rnd() - 0.5) * 12]);
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    _vFill(c, s, _c(dark, 0xFF060918, 0xFFEDF1FF), _c(dark, 0xFF121A38, 0xFFF9FAFF));
    if (tap != null) {
      tp = tap;
      tpT = t;
    }
    final col = _c(dark, 0xFF9FB7FF, 0xFF4B5BD8);
    for (final q in p) {
      q[0] += q[2] * dt;
      q[1] += q[3] * dt;
      if (q[0] < 0 || q[0] > w) q[2] *= -1;
      if (q[1] < 0 || q[1] > h) q[3] *= -1;
    }
    final pts = [for (final q in p) Offset(q[0], q[1])];
    final tpa = math.max(0.0, 1 - (t - tpT) / 2.5);
    final hasBig = tp != null && tpa > 0;
    if (hasBig) pts.add(tp!);
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        final big = hasBig && j == pts.length - 1, lim = big ? 140.0 : 88.0, d = (pts[i] - pts[j]).distance;
        if (d < lim) c.drawLine(pts[i], pts[j], _stroke(_op(col, (1 - d / lim) * (big ? tpa : 0.55)), 1, StrokeCap.butt));
      }
    }
    for (var i = 0; i < pts.length; i++) {
      final big = hasBig && i == pts.length - 1;
      c.drawCircle(pts[i], big ? 3 : 1.7, _fill(_op(col, big ? tpa : 0.9)));
    }
  }
}

// ───────────── Сакура ─────────────
class _Petal {
  double x = 0, y = 0, z = 1, r = 0, vr = 0, fl = 0, vf = 1, vx = 0, vy = 0, ph = 0;
}

class _Sakura extends CoverSim {
  late List<_Petal> p;
  @override
  void init(Size s) => p = List.generate(46, (_) => _Petal()
    ..x = _rnd() * s.width
    ..y = _rnd() * s.height
    ..z = 0.5 + _rnd() * 0.7
    ..r = _rnd() * 6
    ..vr = (_rnd() - 0.5) * 3
    ..fl = _rnd() * 6
    ..vf = 1 + _rnd() * 2.5
    ..ph = _rnd() * 6);
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    _vFill(c, s, _c(dark, 0xFF170D1C, 0xFFFFF1F6), _c(dark, 0xFF2B1633, 0xFFFFE0EC));
    final mr = h * 0.22, mo = Offset(w * 0.78, h * 0.3);
    _glow(c, mo, mr * 1.6, _c(dark, 0xFFFFDCEB, 0xFFFFFFFF), dark ? 0.8 : 0.7);
    c.drawCircle(mo, mr * 0.55, _fill(_op(_c(dark, 0xFFFBE6EF, 0xFFFFFFFF), dark ? 0.9 : 0.7)));
    final wind = 14 + math.sin(t * 0.3) * 10;
    for (final q in p) {
      _push(tap, q.x, q.y, 120, 220, (ax, ay) {
        q.vx += ax;
        q.vy += ay - 60;
        q.vr += (_rnd() - 0.5) * 12;
      });
      q.vx *= 1 - dt * 1.8;
      q.vy *= 1 - dt * 1.8;
      q.vr *= 1 - dt * 0.6;
      q.x += (wind * q.z + math.sin(t * 0.8 + q.ph) * 12 + q.vx) * dt;
      q.y += (16 + q.z * 22 + q.vy) * dt;
      q.r += q.vr * dt;
      q.fl += q.vf * dt;
      if (q.y > h + 10) {
        q.y = -10;
        q.x = _rnd() * w - 40;
      }
      if (q.x > w + 12) q.x = -12;
      if (q.x < -12) q.x = w + 12;
      final sz = 5 * q.z;
      c.save();
      c.translate(q.x, q.y);
      c.rotate(q.r);
      c.scale(1, math.cos(q.fl)); // кувырок в объёме
      c.drawPath(
          Path()
            ..moveTo(0, sz)
            ..cubicTo(-sz * 1.2, sz * 0.2, -sz * 0.8, -sz, 0, -sz * 0.7)
            ..cubicTo(sz * 0.8, -sz, sz * 1.2, sz * 0.2, 0, sz),
          _fill(dark ? (q.z > 0.9 ? const Color(0xFFFF9CC2) : const Color(0xFFE583AE)) : (q.z > 0.9 ? const Color(0xFFFF8FB7) : const Color(0xFFFFB3CD))));
      c.restore();
    }
  }
}

// ───────────── Галактика ─────────────
class _Galaxy extends CoverSim {
  late List<List<double>> st, bg;
  double rot = 0;
  final w = Spring(0.08);
  @override
  void init(Size s) {
    st = List.generate(900, (i) {
      final r = _pow(_rnd(), 0.7);
      return [r, (i % 3) * _tau / 3 + r * 5.2 + (_rnd() - 0.5) * (0.5 + r * 0.9), r < 0.18 ? 0.0 : 1.0 + (i % 2), _rnd()];
    });
    bg = List.generate(70, (_) => [_rnd(), _rnd(), _rnd()]);
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final ww = s.width, h = s.height;
    _vFill(c, s, _c(dark, 0xFF04030D, 0xFFF3EEFF), _c(dark, 0xFF0E0A22, 0xFFFDF4FA));
    for (final q in bg) {
      c.drawRect(Rect.fromLTWH(q[0] * ww, q[1] * h, 1, 1), _fill(_op(_c(dark, 0xFFFFFFFF, 0xFF6A4CC8), 0.2 + 0.4 * math.max(0.0, math.sin(t + q[2] * 9)))));
    }
    if (tap != null) w.v += 1.4;
    w.t = 0.08;
    w.step(dt, 3, 2.5);
    rot += w.x * dt;
    final cx = ww * 0.5, cy = h * 0.5, rr = math.min(ww, h * 1.8) * 0.48, co = math.cos(-0.35), si = math.sin(-0.35);
    c.save();
    c.translate(cx, cy);
    c.scale(1, 0.6);
    _glow(c, Offset.zero, rr * 0.5, _c(dark, 0xFFFFDCBE, 0xFFFFBE96), dark ? 0.75 : 0.5);
    c.restore();
    final cols = dark ? const [Color(0xFFFFECD2), Color(0xFF8CAAFF), Color(0xFFFF82C8)] : const [Color(0xFFBE783C), Color(0xFF505ADC), Color(0xFFD24696)];
    // Звёзды пакетами: 3 цвета × 3 яркости × 2 размера → 18 вызовов вместо 900.
    final buckets = List.generate(18, (_) => <double>[]);
    for (final q in st) {
      final a = q[1] + rot * (1.4 - q[0] * 0.6), x0 = math.cos(a) * q[0] * rr, y0 = math.sin(a) * q[0] * rr * 0.42;
      final al = (0.35 + q[3] * 0.6) * (0.75 + 0.25 * math.sin(t * 2 + q[3] * 20));
      final bi = q[2].toInt() * 6 + _clamp((al * 3).floorToDouble(), 0, 2).toInt() * 2 + (q[3] > 0.93 ? 1 : 0);
      buckets[bi]
        ..add(cx + x0 * co - y0 * si)
        ..add(cy + x0 * si + y0 * co);
    }
    for (var i = 0; i < 18; i++) {
      if (buckets[i].isEmpty) continue;
      final ci = i ~/ 6, ai = (i % 6) ~/ 2, big = i.isOdd;
      c.drawRawPoints(
          ui.PointMode.points,
          Float32List.fromList(buckets[i]),
          Paint()
            ..color = _op(cols[ci], (0.3 + ai * 0.3) * (dark ? 1 : 0.75))
            ..strokeWidth = big ? 1.8 : 1
            ..strokeCap = StrokeCap.square
            ..blendMode = dark ? BlendMode.plus : BlendMode.srcOver);
    }
  }
}

// ───────────── Облака ─────────────
class _Cloud {
  double x = 0, y = 0, s = 1;
  late List<List<double>> puffs;
}

class _Clouds extends CoverSim {
  late List<List<_Cloud>> layers;
  final boost = Spring(1);
  @override
  void init(Size s) => layers = List.generate(
      3,
      (k) => List.generate(
          4,
          (_) => _Cloud()
            ..x = _rnd() * (s.width + 200) - 100
            ..y = s.height * (0.2 + k * 0.22 + _rnd() * 0.12)
            ..s = (0.6 + k * 0.3) * (0.8 + _rnd() * 0.5)
            ..puffs = List.generate(6, (i) => [(i - 2.5) * 16 + _rnd() * 8, -_rnd() * 14 * (1 - (i - 2.5).abs() / 3), 14 + _rnd() * 12])));
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    _vFill(c, s, _c(dark, 0xFF0C1430, 0xFF6EA9EE), _c(dark, 0xFF2A3A68, 0xFFCFE5FF));
    final so = Offset(w * 0.2, h * 0.28);
    _glow(c, so, 70, _c(dark, 0xFFDCE6FF, 0xFFFFF5C8), dark ? 0.55 : 0.8);
    c.drawCircle(so, 20, _fill(_c(dark, 0xFFE9EEFF, 0xFFFFF6D8)));
    if (tap != null) boost.v += 18;
    boost.t = 1;
    boost.step(dt, 5, 3);
    final cols = dark ? const [Color(0xFF26345E), Color(0xFF34457A), Color(0xFF46598F)] : const [Color(0xFFE6F1FF), Color(0xFFF4F9FF), Color(0xFFFFFFFF)];
    for (var k = 0; k < 3; k++) {
      final paint = _fill(_op(cols[k], dark ? 0.92 : 0.95));
      for (final cl in layers[k]) {
        cl.x += (5 + k * 7) * boost.x * dt;
        if (cl.x - 90 * cl.s > w) cl.x = -90 * cl.s;
        final path = Path();
        for (var i = 0; i < cl.puffs.length; i++) {
          final pf = cl.puffs[i], r = pf[2] * cl.s * (1 + math.sin(t * 0.8 + i + k) * 0.04);
          path.addOval(Rect.fromCircle(center: Offset(cl.x + pf[0] * cl.s, cl.y + pf[1] * cl.s), radius: r));
        }
        c.drawPath(path, paint);
      }
    }
  }
}

// ───────────── Ночной город ─────────────
class _Win {
  _Win(this.x, this.y, this.on, this.nt);
  final double x, y;
  bool on, to = false;
  double nt, flip = 0;
}

class _Bld {
  _Bld(this.x, this.w, this.h, this.win);
  final double x, w, h;
  final List<_Win> win;
}

class _City extends CoverSim {
  late List<_Bld> back, front;
  double px = -40;
  List<_Bld> _mk(Size s, bool fr) {
    final out = <_Bld>[];
    var x = -10.0;
    while (x < s.width + 10) {
      final w = 22 + _rnd() * 34, h = s.height * (fr ? 0.22 + _rnd() * 0.32 : 0.35 + _rnd() * 0.35);
      final win = <_Win>[];
      for (double yy = 8; yy < h - 6; yy += 9) {
        for (double xx = 5; xx < w - 5; xx += 7) {
          win.add(_Win(xx, yy, _rnd() < 0.4, _rnd() * 8));
        }
      }
      out.add(_Bld(x, w, h, win));
      x += w + 2 + _rnd() * 5;
    }
    return out;
  }

  @override
  void init(Size s) {
    back = _mk(s, false);
    front = _mk(s, true);
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    _vFill(c, s, _c(dark, 0xFF0A0D27, 0xFFFFD6A8), _c(dark, 0xFF43204F, 0xFFFF9E9E));
    if (tap != null) {
      for (final b in [...back, ...front]) {
        if (tap.dx >= b.x && tap.dx <= b.x + b.w) {
          final on = !b.win.any((q) => q.on);
          for (final q in b.win) {
            q.flip = t + (b.h - q.y) * 0.004; // свет волной снизу вверх
            q.to = on;
          }
        }
      }
    }
    px += 28 * dt;
    if (px > w + 40) px = -40;
    final py = h * 0.16 + math.sin(px * 0.01) * 4;
    c.drawCircle(Offset(px, py), 1.6, _fill((t % 1.2) < 0.15 ? const Color(0xFFFF4D4D) : _op(_c(dark, 0xFFFFFFFF, 0xFF5A2A4A), dark ? 0.9 : 0.6)));
    for (final (bs, col, wa) in [(back, _c(dark, 0xFF1E1A3E, 0xFFE88A92), 0.55), (front, _c(dark, 0xFF0A0A1A, 0xFF6A3558), 1.0)]) {
      final wp = _fill(_op(_c(dark, 0xFFFFD27A, 0xFFFFECBE), wa));
      for (final b in bs) {
        final y0 = h - b.h;
        c.drawRect(Rect.fromLTWH(b.x, y0, b.w, b.h), _fill(col));
        for (final q in b.win) {
          if (q.flip > 0 && t >= q.flip) {
            q.on = q.to;
            q.flip = 0;
          }
          if (t > q.nt) {
            if (_rnd() < 0.3) q.on = !q.on;
            q.nt = t + 3 + _rnd() * 10;
          }
          if (q.on) c.drawRect(Rect.fromLTWH(b.x + q.x, y0 + q.y, 3, 4), wp);
        }
      }
    }
  }
}
