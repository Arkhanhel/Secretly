// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../../profile_fx.dart';

// ───────────── 15 Аура ─────────────
class _Aura extends FrameSim {
  _Aura() : super(100, 100, 62, 56);
  static const _pal = [
    [Color(0xFFFF4FD8), Color(0xFF7A5CFF), Color(0xFF3DD6FF), Color(0xFFFFB23F), Color(0xFFFF5F6D)],
    [Color(0xFF3DFFB2), Color(0xFF3DD6FF), Color(0xFF1FB5A8), Color(0xFFC4F56B), Color(0xFF7A5CFF)],
    [Color(0xFFFF5F6D), Color(0xFFFFB23F), Color(0xFFFFE08A), Color(0xFFFF4F9A), Color(0xFFFF8A3D)],
  ];
  static final _blur = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8);
  int k = 0;
  final pulse = Spring();
  final _cur = List<Color>.generate(6, (i) => _pal[0][i % 5]);
  final _o = List<Offset>.filled(6, Offset.zero);
  final _r = List<double>.filled(6, 0);

  @override
  void update(double dt) {
    if (edge()) {
      k++;
      pulse.v += 40;
    }
    pulse.step(dt, 60, 7);
    final pal = _pal[k % 3];
    for (var i = 0; i < 6; i++) {
      final ang = i / 6 * _tau + t * (0.35 + i * 0.07) * (i.isOdd ? -1 : 1);
      _o[i] = _pt(cx, cy, R - 6 + math.sin(t * 1.3 + i * 2) * 6 + pulse.x * 0.5, ang);
      _r[i] = 26 + 6 * math.sin(t * 1.7 + i) + pulse.x * 0.3;
      _cur[i] = Color.lerp(_cur[i], pal[i % 5], math.min(1.0, dt * 2.5))!; // плавная смена палитры
    }
    final br = math.sin(t * 1.2) * 0.008;
    body(1 + br, 1 + br);
  }

  @override
  void back(Canvas c, FramePalette p) {
    c.saveLayer(const Rect.fromLTWH(-40, -40, 280, 280), Paint()..imageFilter = _blur);
    for (var i = 0; i < 6; i++) {
      c.drawCircle(_o[i], _r[i], _fill(_cur[i]));
    }
    c.restore();
  }
}

// ───────────── 16 Глитч ─────────────
class _Glitch extends FrameSim {
  _Glitch() : super(100, 100, 62, 56);
  double burst = 0, next = 1.2, jt = 0;
  List<double> jv = List<double>.filled(16, 0);

  @override
  Path ringPath() => _blob(cx, cy, R, (a) => 0.6 * math.sin(3 * a + t * 1.4));

  @override
  void update(double dt) {
    if (edge()) burst = 0.9;
    if (t > next) {
      burst = math.max(burst, 0.15 + _rnd() * 0.2);
      next = t + 1.6 + _rnd() * 2.8;
    }
    burst -= dt;
    jt -= dt;
    if (jt <= 0) {
      jv = List<double>.generate(16, (_) => _rnd() - 0.5); // 20 Гц, «цифровой» джиттер
      jt = 0.05;
    }
    final on = burst > 0 ? 1.0 : 0.0;
    body(1, 1, 0, on * jv[5] * 5, 0);
    bodyOpacity = on > 0 && jv[6] > 0.25 ? 0.72 : 1.0;
  }

  double get _on => burst > 0 ? 1.0 : 0.0;

  @override
  void back(Canvas c, FramePalette p) {
    final a = _on, path = ringPath(), mode = p.dark ? BlendMode.screen : BlendMode.multiply;
    c.drawPath(path.shift(Offset(-1.5 - a * (2 + jv[0] * 8), a * jv[1] * 4)), _stroke(const Color(0xFF00E5FF), 6)..blendMode = mode);
    c.drawPath(path.shift(Offset(1.5 + a * (2 + jv[2] * 8), a * jv[3] * 4)), _stroke(const Color(0xFFFF2BD6), 6)..blendMode = mode);
    c.drawPath(path.shift(Offset(a * jv[4] * 3, 0)), _stroke(p.ink, 4));
  }

  @override
  void front(Canvas c, FramePalette p) {
    if (_on == 0) return;
    final cols = [const Color(0xFF00E5FF), const Color(0xFFFF2BD6), p.ink, const Color(0xFF00E5FF)];
    final mode = p.dark ? BlendMode.screen : BlendMode.multiply;
    for (var i = 0; i < 4; i++) {
      if (jv[7 + i] <= -0.2) continue;
      c.drawRect(
          Rect.fromLTWH(cx - R - 14 + jv[11 + i] * 40 + 20, cy + jv[8 + i] * R * 2.1, 34 + jv[12 - i].abs() * 70, 2 + jv[9 + i].abs() * 8),
          _fill(_op(cols[i], 0.85))..blendMode = mode);
    }
  }
}

// ───────────── 17 Соцбатарейка ─────────────
class _Battery extends FrameSim {
  _Battery() : super(96, 98, 62, 56);
  final lv = Spring(0.64), bolt = Spring(), pop = Spring(1);
  double goal = 0.64, ch = 0;
  Color _col = const Color(0xFF3DDC84);
  static final _boltP = Path()
    ..moveTo(1.5, -7)
    ..lineTo(-4, 1)
    ..lineTo(-0.5, 1)
    ..lineTo(-1.5, 7)
    ..lineTo(4, -1)
    ..lineTo(0.5, -1)
    ..close();

  @override
  void update(double dt) {
    if (edge()) {
      ch = 1.6;
      pop.v += 10;
    }
    if (inputs.battery != null && ch <= 0) {
      goal = _clamp(inputs.battery!, 0, 1);
    } else if (ch > 0) {
      ch -= dt;
      goal = math.min(1.0, goal + dt * 0.8);
    } else {
      goal = math.max(0.06, goal - dt * 0.014); // заряд тает
    }
    bolt.t = ch > 0 ? 1.0 : 0.0;
    lv.t = goal;
    lv.step(dt, 90, 14);
    bolt.step(dt, 220, 11);
    pop.step(dt, 300, 12);
    final l = _clamp(lv.x, 0, 1);
    final target = l > 0.5 ? const Color(0xFF3DDC84) : (l > 0.2 ? const Color(0xFFFFC83D) : const Color(0xFFFF4D4D));
    _col = Color.lerp(_col, target, math.min(1.0, dt * 5))!;
    breathe();
  }

  @override
  void back(Canvas c, FramePalette p) {
    final l = _clamp(lv.x, 0, 1);
    c.drawCircle(Offset(cx, cy), R, _stroke(p.track, 8));
    c.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: R), -math.pi / 2, l * _tau, false,
        _stroke(_col, 8 + (ch > 0 ? math.sin(t * 12) * 1.5 + 1.5 : 0.0)));
  }

  @override
  void front(Canvas c, FramePalette p) {
    final l = _clamp(lv.x, 0, 1);
    final shake = l < 0.2 && t % 1.4 < 0.35 ? math.sin(t * 55) * 7 : 0.0;
    c.save();
    c.translate(cx + 44, cy + 50);
    c.rotate(shake * _deg);
    c.scale(pop.x);
    final r = _rr(-28, -12, 56, 24, 12);
    c.drawRRect(r, _fill(p.chip));
    c.drawRRect(r, _stroke(p.bg, 3));
    c.drawRRect(_rr(-20, -5.5, 17, 11, 2.8), _stroke(Colors.white, 1.6));
    c.drawRRect(_rr(-2.4, -2.2, 2, 4.4, 1), _fill(Colors.white));
    c.drawRRect(_rr(-18.2, -3.7, 13.4 * l, 7.4, 1.3), _fill(_col));
    final bs = math.max(0.0, bolt.x);
    if (bs > 0.01) {
      c.save();
      c.translate(-11.2, 0);
      c.scale(bs);
      c.drawPath(_boltP, _fill(const Color(0xFFFFD23F)));
      c.drawPath(_boltP, _stroke(p.chip, 1.4));
      c.restore();
    }
    _text(c, '${(l * 100).round()}%', const Offset(12, 0), 11, Colors.white);
    c.restore();
  }
}

// ───────────── 18 Печатает… ─────────────
class _Typing extends FrameSim {
  _Typing() : super(94, 106, 62, 56, const [Color(0xFF3DD6FF), Color(0xFF7A5CFF), Color(0xFFFF4F9A)]);
  bool typing = true;
  double pt = 0, fly = 0;
  final w = Spring(40), sc = Spring();

  @override
  void update(double dt) {
    pt += dt;
    final e = edge();
    if ((e || pt > 4.5) && typing) {
      typing = false;
      pt = 0;
      sc.v += 4;
    }
    fly = 0;
    if (typing) {
      w.t = 40;
      sc.t = 1;
    } else {
      w.t = 60;
      if (pt > 1.3) fly = _clamp((pt - 1.3) / 0.45, 0, 1);
      if (pt > 1.75) {
        typing = true;
        pt = 0;
        sc
          ..x = 0
          ..v = 0;
        w.x = 40;
      }
    }
    w.step(dt, 200, 12);
    sc.step(dt, 180, 10);
    breathe();
  }

  @override
  void front(Canvas c, FramePalette p) {
    final tv = _clamp(sc.x, 0, 1) * (1 - fly);
    if (tv > 0.01) {
      for (final (o, r) in const [(Offset(146, 56), 3.2), (Offset(153, 46), 4.8)]) {
        c.drawCircle(o, r, _fill(_op(p.chip, tv)));
        c.drawCircle(o, r, _stroke(_op(p.bg, tv), 2));
      }
    }
    final op = 1 - fly;
    if (op <= 0.01) return;
    c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, op));
    c.translate(166, 28 - fly * 20);
    c.scale(math.max(0.0, sc.x) * (1 + math.sin(t * 2) * 0.02));
    final r = _rr(-w.x / 2, -13, w.x, 26, 13);
    c.drawRRect(r, _fill(p.chip));
    c.drawRRect(r, _stroke(p.bg, 2.5));
    if (typing) {
      for (var i = 0; i < 3; i++) {
        final b = _pow(math.max(0.0, math.sin(t * 7 - i * 0.9)), 2);
        c.drawCircle(Offset(-10 + i * 10.0, -b * 4), 3.3, _fill(_op(Colors.white, 0.45 + 0.55 * b)));
      }
    } else {
      _text(c, inputs.typingText ?? 'привет!', Offset.zero, 11.5, Colors.white, FontWeight.w700, _clamp(pt * 5, 0, 1));
    }
    c.restore();
  }
}

// ───────────── 19 Сатурн ─────────────
class _Saturn extends FrameSim {
  _Saturn() : super(100, 100, 58, 52, const [Color(0xFFFFD6A3), Color(0xFFFF9ACB), Color(0xFF7A5CFF)]);
  static const _n = 40;
  static const _cols = [Color(0xFFFFD6A3), Color(0xFFFF9ACB), Color(0xFFB69CFF), Color(0xFF7FE0FF)];
  double a = 0, _tl = 0, _rx = 84, _ry = 20;
  final v = Spring(0.45), ex = Spring();
  final _p = List<Offset>.filled(_n, Offset.zero);
  final _r = List<double>.filled(_n, 0);
  final _f = List<bool>.filled(_n, false);

  Offset _e(double th, [double k = 1]) {
    final x = _rx * k * math.cos(th), y = _ry * k * math.sin(th);
    return Offset(cx + x * math.cos(_tl) - y * math.sin(_tl), cy + x * math.sin(_tl) + y * math.cos(_tl));
  }

  @override
  void update(double dt) {
    v.t = active ? 1.8 : 0.45;
    ex.t = active ? 1.0 : 0.0;
    v.step(dt, 30, 8);
    ex.step(dt, 70, 6);
    a += v.x * dt;
    final e = ex.x;
    _tl = (-16 + math.sin(t * 0.45) * 5) * _deg;
    _rx = 84 + e * 8;
    _ry = 20 + e * 7;
    for (var i = 0; i < _n; i++) {
      final th = i / _n * _tau + a + math.sin(i * 7.3) * 0.05;
      _p[i] = _e(th, 1 + math.sin(i * 7.3) * 0.06 + e * math.sin(i * 3.1 + t * 2) * 0.1);
      _f[i] = math.sin(th) > 0;
      _r[i] = (1.5 + (i % 3) * 0.8) * (0.8 + 0.25 * (math.sin(th) * 0.5 + 0.5));
    }
    breathe();
  }

  void _arc(Canvas c, double a0, double a1, double op) =>
      c.drawPath(_smoothOpen([for (var k = 0; k <= 20; k++) _e(a0 + (a1 - a0) * k / 20)]), _stroke(_op(const Color(0xFFB69CFF), op), 1.5));

  void _dots(Canvas c, bool front) {
    for (var i = 0; i < _n; i++) {
      if (_f[i] == front) c.drawCircle(_p[i], _r[i], _fill(_cols[i % 4]));
    }
  }

  @override
  void back(Canvas c, FramePalette p) {
    _arc(c, math.pi, _tau, 0.35);
    _dots(c, false);
  }

  @override
  void front(Canvas c, FramePalette p) {
    _arc(c, 0, math.pi, 0.45);
    _dots(c, true);
  }
}

// ───────────── 20 Винил ─────────────
class _Vinyl extends FrameSim {
  _Vinyl() : super(92, 106, 64, 48);
  double rot = 0, scr = 0;
  final w = Spring(3.4), arm = Spring();

  Path _sector(double a0, double a1, double r0, double r1) {
    final c0 = Offset(cx, cy);
    return Path()
      ..moveTo(_pt(cx, cy, r0, a0).dx, _pt(cx, cy, r0, a0).dy)
      ..lineTo(_pt(cx, cy, r1, a0).dx, _pt(cx, cy, r1, a0).dy)
      ..arcTo(Rect.fromCircle(center: c0, radius: r1), a0 - math.pi / 2, a1 - a0, false)
      ..lineTo(_pt(cx, cy, r0, a1).dx, _pt(cx, cy, r0, a1).dy)
      ..arcTo(Rect.fromCircle(center: c0, radius: r0), a1 - math.pi / 2, a0 - a1, false)
      ..close();
  }

  @override
  void update(double dt) {
    if (edge()) scr = 1.1;
    arm.t = 1;
    arm.step(dt, 30, 7);
    if (scr > 0) {
      scr -= dt;
      w.t = math.sin(scr * 20) * 10; // скретч туда-обратно
    } else {
      w.t = 3.4;
    }
    w.step(dt, 200, 16);
    rot += w.x * dt;
    final beat = scr > 0 ? 0.0 : _pow(math.max(0.0, math.sin(t * math.pi * 2 * 1.1)), 8) * 0.012;
    body(1 + beat, 1 + beat);
  }

  @override
  void back(Canvas c, FramePalette p) {
    final o = Offset(cx, cy);
    c.drawCircle(o, R + 2, _fill(const Color(0xFF111216)));
    for (final r in const [55.0, 59.0, 63.0]) {
      c.drawCircle(o, r, _stroke(const Color(0xFF2A2C33), 1));
    }
    final hl = _fill(const Color(0x1AFFFFFF));
    c.drawPath(_sector(-1.05, -0.45, av + 4, R + 1), hl); // блики статичны, как у настоящего винила
    c.drawPath(_sector(-1.05 + math.pi, -0.45 + math.pi, av + 4, R + 1), hl);
    c.drawCircle(_pt(cx, cy, 61, rot), 2.6, _fill(const Color(0xFFFF4F9A)));
  }

  @override
  void front(Canvas c, FramePalette p) {
    if (scr > 0) {
      final sw = _stroke(_op(p.ink, 0.5 + 0.5 * math.sin(t * 30)), 2.2);
      c.drawPath(Path()..moveTo(160, 58)..quadraticBezierTo(166, 64, 162, 72), sw);
      c.drawPath(Path()..moveTo(167, 54)..quadraticBezierTo(175, 63, 169, 75), sw);
    }
    final on = _clamp(arm.x, 0, 1.1);
    final ang = (10 + (-31.6 - 10) * on + math.sin(t * 9) * 0.5 * on + (scr > 0 ? math.sin(t * 40) * 1.2 : 0.0)) * _deg;
    const l = 61.0;
    final hx = 180 + l * math.sin(ang), hy = 22 + l * math.cos(ang);
    final mx = (180 + hx) / 2 + 6 * math.cos(ang), my = (22 + hy) / 2 - 6 * math.sin(ang);
    c.drawPath(Path()..moveTo(180, 22)..quadraticBezierTo(mx, my, hx, hy), _stroke(const Color(0xFFC9CCD4), 3.5));
    c.save();
    c.translate(hx, hy);
    c.rotate(-ang + 20 * _deg);
    c.drawRRect(_rr(-4, -6, 8, 12, 2), _fill(const Color(0xFF8A8E99)));
    c.drawRect(const Rect.fromLTWH(-1, 5, 2, 3), _fill(const Color(0xFFC9CCD4)));
    c.restore();
    c.drawCircle(const Offset(180, 22), 7, _fill(const Color(0xFFC9CCD4)));
    c.drawCircle(const Offset(180, 22), 7, _stroke(const Color(0xFF8A8E99), 2));
  }
}

// ───────────── 21 Тучка ─────────────
class _Rain {
  double x = 0, y = 0, v = 0, age = 9, stop = 0;
}

class _Weather extends FrameSim {
  _Weather() : super(100, 112, 60, 54, const [Color(0xFFAFC0DA), Color(0xFF6C85B0), Color(0xFF46628F)]);
  static const _warm = [Color(0xFFFFE08A), Color(0xFFFFB23F), Color(0xFFFF7A59)];
  final m = Spring();
  final dr = List<_Rain>.generate(10, (_) => _Rain());
  int di = 0;
  double nd = 0, _clx = 0, _cly = 0;

  @override
  void update(double dt) {
    m.t = active ? 1.0 : 0.0;
    m.step(dt, 40, 9);
    final mm = _clamp(m.x, 0, 1);
    _clx = cx - 34 - m.x * 80;
    _cly = cy - 70 + math.sin(t * 1.3) * 2.5;
    if (mm < 0.25 && t > nd) {
      final x = _clx + (_rnd() - 0.5) * 34;
      dr[di++ % dr.length]
        ..x = x
        ..y = _cly + 12
        ..v = 60
        ..age = 0
        ..stop = cy - math.sqrt(math.max(0.0, R * R - (x - cx) * (x - cx))) - 2; // падает точно на кольцо
      nd = t + 0.1 + _rnd() * 0.08;
    }
    for (final d in dr) {
      d.age += dt;
      d.v += 300 * dt;
      d.y += d.v * dt;
    }
    breathe();
  }

  @override
  void back(Canvas c, FramePalette p) {
    final rv = _clamp((_clamp(m.x, 0, 1) - 0.25) / 0.75, 0, 1);
    const cols = [Color(0xFFFF5F6D), Color(0xFFFFD23F), Color(0xFF3DD6FF)], rad = [10.0, 15.5, 21.0];
    for (var k = 0; k < 3; k++) {
      final pr = _clamp(rv * 1.3 - k * 0.15, 0, 1);
      if (pr > 0.001) c.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: R + rad[k]), -1.3 - math.pi / 2, 2.6 * pr, false, _stroke(cols[k], 4.5));
    }
  }

  @override
  void front(Canvas c, FramePalette p) {
    final mm = _clamp(m.x, 0, 1);
    if (mm > 0.01) withBody(c, () => paintRing(c, _warm, mm));
    for (final d in dr) {
      if (d.age > 3) continue;
      final landed = d.y >= d.stop;
      final op = landed ? math.max(0.0, 1 - (d.y - d.stop) / 25) : 0.9;
      if (op <= 0.01) continue;
      c.drawOval(_ov(d.x, math.min(d.y, d.stop), landed ? 3.2 : 1.7, landed ? 1.0 : 3.6), _fill(_op(const Color(0xFF6FB6F0), op)));
    }
    final ss = math.max(0.0, m.x);
    if (ss > 0.01) {
      c.save();
      c.translate(cx + 52, cy - 60 + (1 - m.x) * 34);
      c.rotate(t * 25 * _deg);
      c.scale(ss);
      for (var i = 0; i < 8; i++) {
        c.save();
        c.rotate(i * 45 * _deg);
        c.drawRRect(_rr(-1.6, -24, 3.2, 6, 1.6), _fill(const Color(0xFFFFB23F)));
        c.restore();
      }
      c.drawCircle(Offset.zero, 13, _fill(const Color(0xFFFFD23F)));
      c.restore();
    }
    final co = _clamp(1 - mm * 1.4, 0, 1);
    if (co > 0.01) {
      final sq = math.sin(t * 1.3) * 0.03, f = _fill(_op(p.cloud, co));
      c.save();
      c.translate(_clx, _cly);
      c.scale(1 + sq, 1 - sq);
      final cl = Path()
        ..addOval(Rect.fromCircle(center: const Offset(-12, 3), radius: 10))
        ..addOval(Rect.fromCircle(center: const Offset(1, -4), radius: 13))
        ..addOval(Rect.fromCircle(center: const Offset(14, 3), radius: 9.5))
        ..addRRect(_rr(-22, 2, 45, 11, 5.5));
      c.drawPath(cl, f);
      c.restore();
    }
  }
}

// ───────────── 22 Не беспокоить ─────────────
class _Sleep extends FrameSim {
  _Sleep() : super(98, 108, 60, 54, const [Color(0xFFB69CFF), Color(0xFF7654DB), Color(0xFF2A3A9A)]);
  double al = 0;
  final sh = Spring(), zf = Spring(1), ex = Spring();

  @override
  void update(double dt) {
    if (edge()) {
      al = 2.2;
      sh.v += 500;
      ex
        ..x = 0
        ..v = 0;
    }
    al -= dt;
    final awake = al > 0;
    if (al > 1.3) sh.v += math.sin(t * 70) * 60; // будильник звенит
    zf.t = awake ? 0.0 : 1.0;
    ex.t = awake ? 1.0 : 0.0;
    sh.step(dt, 250, 6);
    zf.step(dt, 60, 10);
    ex.step(dt, 200, 10);
    final br = math.sin(t * 1.1) * 0.012 * _clamp(zf.x, 0, 1); // глубокое дыхание во сне
    body(1 + br, 1 + br, sh.x * 0.3);
  }

  @override
  void back(Canvas c, FramePalette p) {
    const st = [Offset(26, 34), Offset(168, 150), Offset(22, 170), Offset(70, 22)];
    for (var i = 0; i < 4; i++) {
      c.drawCircle(st[i], 1.8, _fill(_op(p.ink, 0.2 + 0.8 * _pow(math.max(0.0, math.sin(t * (1.1 + i * 0.3) + i * 2)), 2))));
    }
  }

  @override
  void front(Canvas c, FramePalette p) {
    c.save();
    c.translate(cx + 50, cy - 52);
    c.rotate((math.sin(t * 0.8) * 8 + sh.x * 0.5) * _deg);
    c.drawCircle(Offset.zero, 15, _fill(const Color(0xFFFFD66B)));
    c.drawCircle(const Offset(7, -6), 13, _fill(p.bg));
    c.restore();
    final z = _clamp(zf.x, 0, 1);
    for (var i = 0; i < 3; i++) {
      final u = (t * 0.33 + i / 3) % 1;
      c.save();
      c.translate(cx + 30 + u * 28 + math.sin(u * 6 + i) * 5, cy - 50 - u * 50);
      c.rotate((-10 + u * 20) * _deg);
      _text(c, 'z', Offset.zero, 9 + u * 11, p.ink, FontWeight.w800, (u < 0.15 ? u / 0.15 : 1 - u) * z);
      c.restore();
    }
    final e = math.max(0.0, ex.x);
    if (e > 0.01) {
      c.save();
      c.translate(cx - 6, cy - R - 10);
      c.rotate(math.sin(t * 30) * 8 * (al > 1 ? 1.0 : 0.0) * _deg);
      c.scale(e);
      _text(c, '!', Offset.zero, 30, const Color(0xFFFF4D4D), FontWeight.w800, _clamp(e, 0, 1));
      c.restore();
    }
  }
}

// ───────────── 23 8-бит ─────────────
class _Pixel extends FrameSim {
  _Pixel() : super(100, 100, 64, 54);
  static const _n = 36;
  static const _pal = [Color(0xFFFF4F9A), Color(0xFFFFD23F), Color(0xFF3DFFB2), Color(0xFF3DD6FF), Color(0xFF7A5CFF)];
  static const _heartMap = ['.XX.XX.', 'XXXXXXX', 'XXXXXXX', '.XXXXX.', '..XXX..', '...X...'];
  final ex = Spring(), hb = Spring(1);
  final _pp = List<Offset>.filled(_n, Offset.zero);
  int _shift = 0;
  double _beat = 1;

  @override
  void update(double dt) {
    if (edge()) {
      ex.v += 110;
      hb.v += 8;
    }
    ex.step(dt, 70, 7);
    hb.step(dt, 200, 10);
    final tq = (t * 10).floor() / 10; // 10 fps, как на старой консоли
    for (var i = 0; i < _n; i++) {
      final a = i / _n * _tau + ex.x * 0.012 * (_hash(i + 3) - 0.5);
      final d = R + (math.sin(a * 3 - tq * 5) * 1.5).round() * 2 + ex.x * (0.4 + _hash(i)) * 0.9;
      final o = _pt(cx, cy, d, a);
      _pp[i] = Offset(((o.dx - 3.5) / 2).roundToDouble() * 2, ((o.dy - 3.5) / 2).roundToDouble() * 2);
    }
    _shift = (tq * 4).floor();
    _beat = (((t * 2.4).floor() % 2 == 1 ? 1.0 : 1.18) * hb.x * 8).roundToDouble() / 8;
    body(1, 1);
  }

  @override
  void back(Canvas c, FramePalette p) {
    for (var i = 0; i < _n; i++) {
      c.drawRect(_pp[i] & const Size(7, 7), _fill(_pal[(i + _shift) % 5])..isAntiAlias = false);
    }
  }

  @override
  void front(Canvas c, FramePalette p) {
    c.save();
    c.translate(cx + 46, cy + 46);
    c.scale(_beat);
    c.drawRect(const Rect.fromLTWH(-12, -11, 24, 22), _fill(p.bg)..isAntiAlias = false);
    for (var y = 0; y < _heartMap.length; y++) {
      for (var x = 0; x < 7; x++) {
        if (_heartMap[y][x] != 'X') continue;
        c.drawRect(Rect.fromLTWH((x - 3.5) * 3, (y - 3) * 3.0, 3, 3), _fill(x == 1 && y == 1 ? Colors.white : const Color(0xFFFF4F9A))..isAntiAlias = false);
      }
    }
    c.restore();
  }
}

// ───────────── 24 Жидкий хром ─────────────
class _Chrome extends FrameSim {
  _Chrome() : super(100, 100, 62, 55) {
    ringWidth = 12;
  }
  static const _stops = [Color(0xFFFFFFFF), Color(0xFF8A8F9C), Color(0xFFF4F5F8), Color(0xFF3E424C), Color(0xFFD9DCE3), Color(0xFF6B707C), Color(0xFFFFFFFF)];
  final List<double> rip = [];
  final sq = Spring(1);

  double _fn(double a) {
    var d = 1.6 * math.sin(3 * a + t * 1.3) + 1.1 * math.sin(4 * a - t * 1.9);
    for (final t0 in rip) {
      final tau = t - t0, fr = tau * 2.6, amp = 6 * math.exp(-tau * 1.2);
      for (final s in const [1.0, -1.0]) {
        final dd = math.atan2(math.sin(a - s * fr), math.cos(a - s * fr));
        d += amp * math.exp(-(dd * dd) / 0.05); // волна бежит в обе стороны
      }
    }
    return d;
  }

  @override
  void update(double dt) {
    if (edge()) {
      rip.add(t);
      sq.v += 3.5;
    }
    rip.removeWhere((t0) => t - t0 >= 2.4);
    sq.step(dt, 180, 7);
    body(2 - sq.x, sq.x);
  }

  ui.Gradient _chrome() {
    final a = (t * 30 % 360) * _deg, co = math.cos(a), si = math.sin(a);
    Offset r(double x, double y) => Offset(100 + x * co - y * si, 100 + x * si + y * co);
    return _linG(r(-70, -70), r(70, 70), _stops);
  }

  @override
  void back(Canvas c, FramePalette p) {
    final g = _chrome();
    withBody(c, () {
      c.drawPath(_blob(cx, cy, R, _fn, 48), _stroke(Colors.white, 12, StrokeCap.butt)..shader = g);
      c.drawPath(_blob(cx, cy, R - 3.5, (a) => _fn(a) * 0.9, 48), _stroke(const Color(0x99FFFFFF), 1.6));
    });
    for (var i = 0; i < 2; i++) {
      final o = _pt(cx, cy, R + 16 + math.sin(t * 2 + i * 2) * 3, t * (i == 1 ? -0.5 : 0.35) + i * 2.5);
      c.drawCircle(o, i == 0 ? 5.5 : 3.6, Paint()..shader = g);
    }
  }
}
