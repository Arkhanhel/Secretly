// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../../profile_fx.dart';

// ───────────── 01 Рыжик ─────────────
class _Cat extends FrameSim {
  _Cat() : super(100, 112, 64, 58, const [Color(0xFFFFC06B), Color(0xFFF07A3A), Color(0xFFE0507A)]);
  static const _o = Color(0xFFEE9446), _pink = Color(0xFFF9BDB2), _tipC = Color(0xFFFFD6A3);
  final eL = Spring(), eR = Spring(), ey = Spring(1), sx = Spring(1), sy = Spring(1);
  double next = 1.2;
  final _eb = [Offset.zero, Offset.zero], _pp = [Offset.zero, Offset.zero];
  final _er = [0.0, 0.0], _es = [1.0, 1.0], _et = [0.0, 0.0], _pk = [0.0, 0.0];
  Offset _t0 = Offset.zero, _c1 = Offset.zero, _c2 = Offset.zero, _tip = Offset.zero;

  @override
  void update(double dt) {
    final p = active;
    eL.t = p ? -58.0 : 0.0;
    eR.t = p ? 58.0 : 0.0;
    ey.t = p ? 0.62 : 1.0;
    if (!p && t > next) {
      final r = _rnd();
      if (r < 0.45 || r > 0.8) eL.v += 340;
      if (r >= 0.45) eR.v -= 340;
      next = t + 2 + _rnd() * 3.5;
    }
    eL.step(dt, 220, 9);
    eR.step(dt, 220, 9);
    ey.step(dt, 160, 10);
    for (var i = 0; i < 2; i++) {
      final a = i == 0 ? -0.68 : 0.68, e = i == 0 ? eL : eR, sg = i == 0 ? -1.0 : 1.0;
      _eb[i] = _pt(cx, cy, R - 8, a);
      _er[i] = a * 57.3 * 0.85 + e.x;
      _es[i] = ey.x * (1 + math.sin(t * 1.8 + sg) * 0.015);
      _et[i] = _clamp(-e.v * 0.022, -10, 10); // кончик уха отстаёт
    }
    sx.t = p ? 1.04 : 1.0;
    sy.t = p ? 0.955 : 1.0;
    sx.step(dt, 200, 10);
    sy.step(dt, 200, 10);
    final b = math.sin(t * 1.8) * 0.006;
    body(sx.x + b, sy.x - b, 0, p ? math.sin(t * 75) * 0.45 : 0.0); // мурчание
    final fq = p ? 6.5 : 1.4, am = p ? 1.0 : 0.7, sw = math.sin(t * fq);
    _t0 = _pt(cx, cy, R - 2, 2.2);
    _tip = Offset(_t0.dx + 26 + sw * 7 * am, _t0.dy - 40 + math.cos(t * fq * 0.9) * 4 * am);
    _c1 = Offset(_t0.dx + 20, _t0.dy + 6);
    _c2 = Offset(_tip.dx + 12 + sw * 10 * am, _tip.dy + 24);
    for (var i = 0; i < 2; i++) {
      final k = p ? math.max(0.0, math.sin(t * 6.5 + i * math.pi)) : 0.0; // месит лапками
      _pk[i] = k;
      _pp[i] = Offset(cx + (i == 1 ? 23 : -23) * sx.x, cy + R * sy.x - 1 - k * 5);
    }
  }

  Path _outer(double tx) => Path()
    ..moveTo(-21, 6)
    ..cubicTo(-21, -14, -10, -38, tx - 2, -45)
    ..quadraticBezierTo(tx, -47, tx + 2, -45)
    ..cubicTo(10, -38, 21, -14, 21, 6)
    ..close();
  Path _inner(double tx) => Path()
    ..moveTo(-11, 4)
    ..cubicTo(-11, -8, -5, -26, tx * 0.8 - 1, -32)
    ..quadraticBezierTo(tx * 0.8, -33.5, tx * 0.8 + 1, -32)
    ..cubicTo(5, -26, 11, -8, 11, 4)
    ..close();

  @override
  void back(Canvas c, FramePalette p) {
    c.drawPath(Path()..moveTo(_t0.dx, _t0.dy)..cubicTo(_c1.dx, _c1.dy, _c2.dx, _c2.dy, _tip.dx, _tip.dy), _stroke(_o, 11));
    c.drawCircle(_tip, 5.6, _fill(_tipC));
    for (var i = 0; i < 2; i++) {
      c.save();
      c.translate(_eb[i].dx, _eb[i].dy);
      c.rotate(_er[i] * _deg);
      c.scale(1, _es[i]);
      c.drawPath(_outer(_et[i]), _fill(_o));
      c.drawPath(_inner(_et[i]), _fill(_pink));
      c.restore();
    }
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (var i = 0; i < 2; i++) {
      final k = _pk[i];
      c.save();
      c.translate(_pp[i].dx, _pp[i].dy);
      c.scale(1 + k * 0.08, 1 - k * 0.12);
      final r = _ov(0, 0, 13, 9.5);
      c.drawOval(r, _fill(_o));
      c.drawOval(r, _stroke(p.bg, 3));
      for (final o in const [Offset(-6, -3), Offset(0, -5), Offset(6, -3)]) {
        c.drawCircle(o, 2.3, _fill(_pink));
      }
      c.restore();
    }
  }
}

// ───────────── 02 Кодер ─────────────
class _Coder extends FrameSim {
  _Coder() : super(100, 94, 64, 58, const [Color(0xFF3FC8FF), Color(0xFF7A5CFF), Color(0xFFF0478F)]);
  @override
  bool get drawRing => false; // кольцо рисуется поверх фото, под руками
  final e = Spring(), lb = Spring(), wave = Spring();
  final jx = [Spring(), Spring()];
  final _prevS = [0.0, 0.0];
  double glow = 0, _glowOp = 0, _logoOp = 0.5, _ev = 0;
  final _s = [Offset.zero, Offset.zero], _m = [Offset.zero, Offset.zero], _h = [Offset.zero, Offset.zero];
  final _hs = [0.0, 0.0], _hr = [0.0, 0.0];

  @override
  void update(double dt) {
    final p = active, ph = t % 9;
    e.t = p ? 1.0 : (ph > 0.5 && ph < 7.5 ? 1.0 : 0.0); // выезд → печать → помахать → уход
    e.step(dt, 150, 9);
    wave.t = (!p && ph > 6.2 && ph < 7.5) ? 1.0 : 0.0;
    wave.step(dt, 120, 10);
    final typing = e.x > 0.8 && (p || ph < 6.2), rate = p ? 8.5 : 3.6;
    final lifts = [0.0, 0.0];
    for (var i = 0; i < 2; i++) {
      if (!typing) continue;
      final s = math.sin(t * rate * math.pi * 2 + i * math.pi);
      if (_prevS[i] > 0 && s <= 0) {
        glow = 1;
        lb.v += 22;
        jx[i].t = (_rnd() - 0.5) * 12;
      }
      _prevS[i] = s;
      lifts[i] = _pow(math.max(0.0, s), 1.4) * 5;
    }
    glow = math.max(0.0, glow - dt * 4);
    lb.step(dt, 400, 18);
    for (final j in jx) {
      j.step(dt, 260, 16);
    }
    final ev = math.max(0.0, e.x), on = _clamp(ev, 0, 1);
    _ev = ev;
    _glowOp = on * (0.55 + glow * 0.45);
    _logoOp = _clamp(0.5 + on * 0.3 + glow * 0.2, 0, 1);
    for (var i = 0; i < 2; i++) {
      final s = _pt(cx, cy, R - 1, i == 1 ? 2.05 : -1.62);
      var tx = (i == 1 ? 104.0 : 58.0) + jx[i].x, ty = (i == 1 ? 137.0 : 144.0) - lifts[i];
      if (i == 1) {
        final w = wave.x;
        tx += (142 - tx) * w + math.sin(t * 13) * 6 * w;
        ty += (100 - ty) * w;
      }
      final hh = Offset(s.dx + (tx - s.dx) * ev, s.dy + (ty - s.dy) * ev);
      _s[i] = s;
      _h[i] = hh;
      _m[i] = i == 1 ? Offset(s.dx + 2 * ev, s.dy + 64 * ev) : Offset(s.dx - 40 * ev, (s.dy + hh.dy) / 2 + 4 * ev);
      _hs[i] = _clamp(ev * 1.1, 0, 1.2);
      _hr[i] = i == 1 ? math.sin(t * 13) * 18 * wave.x : 0.0;
    }
    body(1 + math.sin(t * 1.7) * 0.006, 1 - math.sin(t * 1.7) * 0.006, p ? math.sin(t * 38) * 0.7 : 0.0);
  }

  @override
  void front(Canvas c, FramePalette p) {
    if (_glowOp > 0.01) {
      // свет экрана на фото
      c.save();
      c.translate(86, 122);
      c.scale(42, 24);
      c.drawCircle(Offset.zero, 1,
          Paint()..shader = ui.Gradient.radial(Offset.zero, 1, [_op(const Color(0xFF9BE7FF), 0.6 * _glowOp), _op(const Color(0xFF9BE7FF), 0)]));
      c.restore();
    }
    withBody(c, () => paintRing(c));
    if (_ev >= 0.04) {
      for (var i = 0; i < 2; i++) {
        c.drawPath(Path()..moveTo(_s[i].dx, _s[i].dy)..quadraticBezierTo(_m[i].dx, _m[i].dy, _h[i].dx, _h[i].dy), _stroke(p.sleeve, 8));
      }
    }
    for (var i = 0; i < 2; i++) {
      if (_hs[i] <= 0.001) continue;
      c.save();
      c.translate(_h[i].dx, _h[i].dy);
      c.rotate(_hr[i] * _deg);
      c.scale(_hs[i]);
      final thumb = Offset(i == 0 ? 6.0 : -6.0, -5);
      c.drawCircle(thumb, 3.8, _fill(Colors.white));
      c.drawCircle(thumb, 3.8, _stroke(p.glove, 2));
      c.drawCircle(Offset.zero, 8.5, _fill(Colors.white));
      c.drawCircle(Offset.zero, 8.5, _stroke(p.glove, 2));
      c.restore();
    }
    // ноутбук space gray, крышкой к зрителю — прячет кисти
    c.save();
    c.translate(86, 152);
    c.scale(1 + lb.x * 0.012, 1 - lb.x * 0.018);
    c.drawRRect(_rr(-46, 13, 92, 10, 5), _fill(const Color(0xFF5A5D63)));
    c.drawRRect(_rr(-12, 13, 24, 3, 1.5), _fill(const Color(0xFF3E4045)));
    final lid = _rr(-41, -31, 82, 52, 7);
    c.drawRRect(lid, Paint()..shader = _linG(const Offset(-41, -31), const Offset(-16.4, 21), const [Color(0xFF72757C), Color(0xFF484B51)]));
    c.drawRRect(lid, _stroke(const Color(0xFF35373C), 1.5, StrokeCap.butt));
    c.drawRRect(_rr(-35, -27.5, 70, 1.5, 0.75), _fill(const Color(0x40FFFFFF)));
    c.drawCircle(const Offset(0, -5), 5.5, _fill(_op(const Color(0xFFD9DCE2), _logoOp)));
    c.restore();
  }
}

// ───────────── 03 Меломан ─────────────
class _Music extends FrameSim {
  _Music() : super(100, 110, 60, 54, const [Color(0xFFF0478F), Color(0xFF9A5CFF), Color(0xFF2FB8F0)]);
  static const _wave = [Color(0xFFF0478F), Color(0xFF9A5CFF), Color(0xFF2FB8F0)];
  final amp = Spring(1), beat = Spring(), na = Spring(1);
  int bi = -1;

  @override
  void update(double dt) {
    final play = !active;
    amp.t = play ? 1.0 : 0.0;
    na.t = play ? 1.0 : 0.0;
    amp.step(dt, 50, 11);
    na.step(dt, 60, 12);
    final b = (t / 0.5).floor(); // 120 BPM
    if (play && b != bi) beat.v += b.isOdd ? 6 : 9; // сильная / слабая доля
    bi = b;
    beat.step(dt, 280, 13);
    body(1 + beat.x * 0.012, 1 - beat.x * 0.01, beat.x * 2.4); // кивок
  }

  Paint _wp(double op) => Paint()
    ..shader = _linG(Offset(cx - R - 20, 0), Offset(cx + R + 20, 0), _wave.map((e) => _op(e, op)).toList());

  @override
  void back(Canvas c, FramePalette p) {
    final a = math.max(0.0, amp.x), b = beat.x;
    c.drawPath(
        _blob(cx, cy, R + 13, (x) => a * (4.5 * math.sin(3 * x + t * 2.1) + 3 * math.sin(5 * x - t * 3.3) + 2 * math.sin(9 * x + t * 4.6)) + b * 7 * a - (1 - a) * 9),
        _wp(0.22));
    c.drawPath(_blob(cx, cy, R + 7, (x) => a * (3 * math.sin(4 * x - t * 2.6 + 1) + 2.4 * math.sin(7 * x + t * 3.9)) + b * 4 * a - (1 - a) * 5), _wp(0.4));
  }

  @override
  void front(Canvas c, FramePalette p) {
    final b = beat.x, top = cy - 104 - b * 4;
    c.drawPath(Path()..moveTo(cx - 72, cy - 4)..cubicTo(cx - 74, top, cx + 74, top, cx + 72, cy - 4), _stroke(p.band, 10));
    for (var i = 0; i < 2; i++) {
      final sg = i == 0 ? -1.0 : 1.0;
      c.save();
      c.translate(cx + sg * 72, cy + 8);
      c.rotate(-sg * b * 5 * _deg);
      c.scale(1 + b * 0.1, 1 - b * 0.07);
      c.drawRRect(_rr(-14, -26, 28, 52, 14), _fill(i == 0 ? const Color(0xFFF0478F) : const Color(0xFF2FB8F0)));
      c.drawRRect(_rr(i == 0 ? 4.0 : -10.0, -18, 6, 36, 3), _fill(const Color(0x59FFFFFF)));
      c.restore();
    }
    final alpha = _clamp(na.x, 0, 1);
    for (var i = 0; i < 3; i++) {
      final u = ((t + i * 0.95) % 2.85) / 2.85;
      final x = cx + 50 + 16 * u + math.sin(u * 6 + i * 2) * 6, y = cy - 50 - 60 * u;
      final pop = u < 0.16 ? _backOut(u / 0.16) : 1.0;
      final op = (u < 0.1 ? u / 0.1 : 1 - (u - 0.1) / 0.9) * alpha;
      c.save();
      c.translate(x, y);
      c.rotate(math.sin(u * 5 + i) * 14 * _deg);
      c.scale(pop);
      _text(c, i == 1 ? '♫' : '♪', Offset.zero, 19, p.ink, FontWeight.w700, op);
      c.restore();
    }
  }
}

// ───────────── 04 Аквариум ─────────────
class _Bub {
  double age = 9, life = 1, x = 0, y = 0, sd = 0;
}

class _Fish extends FrameSim {
  _Fish() : super(100, 98, 64, 58, const [Color(0xFF6BE3D2), Color(0xFF2F9BF0), Color(0xFF3A5BE0)]);
  double a = 1.2, nextB = 0, hd = 0, sc = 1, wag = 0, wig = 0;
  int bi = 0;
  bool _front = true;
  Offset pos = Offset.zero;
  final w = Spring(0.8), fy = Spring(1);
  final bub = List<_Bub>.generate(9, (_) => _Bub());

  @override
  void update(double dt) {
    w.t = active ? 2.4 : 0.75;
    w.step(dt, 30, 8);
    a += w.x * dt;
    pos = Offset(cx + 84 * math.cos(a), cy + 30 + 22 * math.sin(a)); // наклонная орбита
    final vx = -84 * math.sin(a), vy = 22 * math.cos(a), sg = vx < 0 ? -1.0 : 1.0;
    _front = math.sin(a) > 0;
    fy.t = sg;
    fy.step(dt, 90, 11); // плавный разворот через сплющивание
    hd = math.atan2(vy, vx.abs()) * 57.3 * sg;
    sc = 1.25 * (0.8 + 0.2 * (math.sin(a) * 0.5 + 0.5));
    final wf = 7 + w.x * 4;
    wag = math.sin(t * wf) * 24;
    wig = math.sin(t * wf - 1) * 4;
    if (t > nextB) {
      bub[bi++ % bub.length]
        ..age = 0
        ..life = 1.6 + _rnd() * 1.2
        ..x = pos.dx + sg * 14 * sc
        ..y = pos.dy - 3
        ..sd = _rnd() * 6;
      nextB = t + (active ? 0.16 : 0.55) + _rnd() * 0.35;
    }
    for (final b in bub) {
      b.age += dt;
      b.y -= (16 + b.age * 6) * dt;
      b.x += math.sin(b.age * 5 + b.sd) * 10 * dt;
    }
    breathe();
  }

  void _fish(Canvas c) {
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate((hd + wig * fy.x) * _deg);
    c.scale(sc * fy.x, sc);
    c.save();
    c.translate(-9, 0);
    c.rotate(wag * _deg);
    c.translate(9, 0);
    c.drawPath(Path()..moveTo(-9, 0)..cubicTo(-14, -3, -19, -10, -23, -9)..cubicTo(-20, -4, -20, 4, -23, 9)..cubicTo(-19, 10, -14, 3, -9, 0)..close(), _fill(const Color(0xFFFF7A3D)));
    c.restore();
    c.drawPath(Path()..moveTo(-4, -7)..quadraticBezierTo(3, -14, 9, -6), _stroke(const Color(0xFFFF7A3D), 3.5));
    c.drawOval(_ov(0, 0, 13.5, 9), _fill(const Color(0xFFFF9A4A)));
    c.drawOval(_ov(2, 3.5, 7.5, 3.4), _fill(const Color(0xFFFFD2A6)));
    c.drawCircle(const Offset(7.5, -2), 2.3, _fill(const Color(0xFF1B1D27)));
    c.drawCircle(const Offset(8.2, -2.8), 0.8, _fill(Colors.white));
    c.restore();
  }

  @override
  void back(Canvas c, FramePalette p) {
    if (!_front) _fish(c);
  }

  @override
  void front(Canvas c, FramePalette p) {
    if (_front) _fish(c);
    for (final b in bub) {
      final u = b.age / b.life;
      final r = u < 1 ? 1.4 + math.min(u, 1.0) * 3 : 4.4 + (u - 1) * 30;
      final op = u < 0.08 ? u / 0.08 : (u < 1 ? 1.0 : math.max(0.0, 1 - (u - 1) * 10));
      if (op <= 0.01) continue;
      c.drawCircle(Offset(b.x, b.y), r, _fill(_op(const Color(0xFF6FCBEA), p.bubbleAlpha * op)));
      c.drawCircle(Offset(b.x, b.y), r, _stroke(_op(const Color(0xFF6FCBEA), op), 1.4));
    }
  }
}

// ───────────── 06 Осьминожка ─────────────
class _Octo extends FrameSim {
  _Octo() : super(100, 106, 62, 56, const [Color(0xFFFF9ACB), Color(0xFFB06BE8), Color(0xFF6B7BFF)]);
  static const _tn = [
    [1.75, 1.0, 30.0], [2.35, 1.0, 36.0], [2.9, 1.0, 32.0],
    [3.38, -1.0, 32.0], [3.93, -1.0, 36.0], [4.53, -1.0, 30.0],
  ];
  static const _oc = Color(0xFFB06BE8), _su = Color(0xFFF2C4F5), _dk = Color(0xFF1B1D27);
  final m = Spring(), lx = Spring(), ly = Spring();
  double nl = 1, blink = 0, nb = 2, mm = 0, bs = 1, headY = 0;
  final List<Path> _paths = [];
  final List<List<Offset>> _suck = [];

  @override
  void update(double dt) {
    m.t = active ? 1.0 : 0.0;
    m.step(dt, 60, 9);
    final mx = _clamp(m.x, -0.05, 1.08);
    if (t > nl) {
      lx.t = (_rnd() - 0.5) * 5;
      ly.t = (_rnd() - 0.5) * 4;
      nl = t + 0.8 + _rnd() * 2;
    }
    lx.step(dt, 120, 12);
    ly.step(dt, 120, 12);
    if (t > nb) {
      blink = 0.16;
      nb = t + 2 + _rnd() * 3;
    }
    blink -= dt;
    bs = blink > 0 ? 0.12 : 1;
    mm = _clamp(mx, 0, 1);
    headY = math.sin(t * 1.6) * 1.5 - mm * 3;
    _paths.clear();
    _suck.clear();
    const n = 12;
    for (var i = 0; i < _tn.length; i++) {
      final a = _tn[i][0], side = _tn[i][1], len = _tn[i][2];
      final pts = <Offset>[];
      var p0 = _pt(cx, cy, R - 8, a);
      var x = p0.dx, y = p0.dy;
      final stepL = len / (n - 1);
      for (var j = 0; j < n; j++) {
        final u = j / (n - 1);
        if (j > 0) {
          final phi = a + side * (u * (0.9 * math.sin(t * 1.2 + i * 1.3) + 0.4) + u * u * 1.5 * math.sin(t * 1.7 + i * 0.8));
          x += stepL * math.sin(phi);
          y -= stepL * math.cos(phi);
        }
        final rr = R - 8 + math.min(1.0, u / 0.12) * 15;
        final hg = _pt(cx, cy, rr, a - side * u * (0.95 + 0.08 * math.sin(t * 2 + i)));
        pts.add(Offset(_lerp(x, hg.dx, mx), _lerp(y, hg.dy, mx)));
      }
      final l = <Offset>[], r = <Offset>[], nrm = <List<double>>[];
      for (var j = 0; j < n; j++) {
        final a0 = pts[math.max(0, j - 1)], a1 = pts[math.min(n - 1, j + 1)];
        var dx = a1.dx - a0.dx, dy = a1.dy - a0.dy;
        final ln = math.sqrt(dx * dx + dy * dy);
        dx /= ln == 0 ? 1 : ln;
        dy /= ln == 0 ? 1 : ln;
        final w = 5.8 * (1 - j / (n - 1)) + 1.4;
        nrm.add([-dy, dx, w]);
        l.add(Offset(pts[j].dx - dy * w, pts[j].dy + dx * w));
        r.add(Offset(pts[j].dx + dy * w, pts[j].dy - dx * w));
      }
      _paths.add(_smoothClosed([...l, ...r.reversed]));
      _suck.add([for (final j in const [3, 5, 7]) Offset(pts[j].dx + nrm[j][0] * nrm[j][2] * 0.35 * side, pts[j].dy + nrm[j][1] * nrm[j][2] * 0.35 * side)]);
    }
    final br = math.sin(t * 1.6) * 0.006;
    body(1 + br - mm * 0.02, 1 - br - mm * 0.02);
  }

  @override
  void back(Canvas c, FramePalette p) {
    c.save();
    c.translate(0, headY);
    c.drawOval(_ov(100, 46, 40, 35), _fill(_oc));
    c.drawCircle(const Offset(74, 47), 4.2, _fill(const Color(0xCCFF8FC2)));
    c.drawCircle(const Offset(126, 47), 4.2, _fill(const Color(0xCCFF8FC2)));
    final eo = 1 - mm;
    if (eo > 0.01) {
      for (final ex in const [85.0, 115.0]) {
        c.drawOval(_ov(ex, 34, 7.5, 8 * bs), _fill(_op(Colors.white, eo)));
        c.drawOval(_ov(ex + lx.x, 34 + ly.x, 3.8, 3.8 * bs), _fill(_op(_dk, eo)));
      }
    }
    if (mm > 0.01) {
      final hp = _stroke(_op(_dk, mm), 3);
      c.drawPath(Path()..moveTo(78, 37)..quadraticBezierTo(85, 28, 92, 37), hp);
      c.drawPath(Path()..moveTo(108, 37)..quadraticBezierTo(115, 28, 122, 37), hp);
    }
    c.restore();
    for (var i = 0; i < _paths.length; i++) {
      c.drawPath(_paths[i], _fill(_oc));
      for (var k = 0; k < 3; k++) {
        c.drawCircle(_suck[i][k], 2.2 - k * 0.45, _fill(_su));
      }
    }
  }
}

// ───────────── 07 Птичка ─────────────
enum _BirdMode { idle, hop, peck, fly }

class _Bird extends FrameSim {
  _Bird() : super(100, 110, 62, 56, const [Color(0xFFFFD66B), Color(0xFFFF9F43), Color(0xFF4F8CFF)]);
  static const _b = Color(0xFF4F8CFF), _bd = Color(0xFF3468E0), _y = Color(0xFFFFD66B), _o = Color(0xFFFF9F43);
  double a = 0, from = 0, to = 0, mt = 0, dur = 1.2, blink = 0, nb = 2, _hgt = 0, _wing = 0, _peck = 0;
  _BirdMode mode = _BirdMode.idle;
  final face = Spring(1), sq = Spring(1), tilt = Spring(0), lean = Spring(0);

  double _ease(double u) => u * u * (3 - 2 * u);

  @override
  void update(double dt) {
    if (edge()) {
      mode = _BirdMode.fly;
      mt = 0;
      dur = 2;
      from = a;
      face.t = 1;
      sq.v -= 6;
    }
    mt += dt;
    _hgt = 0;
    _wing = math.sin(t * 2) * 3;
    _peck = 0;
    lean.t = 0;
    if (mode == _BirdMode.idle && mt > dur) {
      final r = _rnd();
      mt = 0;
      if (r < 0.5) {
        mode = _BirdMode.hop;
        dur = 0.48;
        from = a;
        var tt = a + (_rnd() < 0.5 ? -1.0 : 1.0) * (0.22 + _rnd() * 0.25);
        if (tt.abs() > 0.55) tt = a - (tt - a);
        to = tt;
        face.t = to > a ? 1.0 : -1.0;
        sq.v -= 4; // присед перед прыжком
      } else if (r < 0.75) {
        mode = _BirdMode.peck;
        dur = 0.75;
      } else {
        tilt.t = (_rnd() - 0.5) * 44;
        dur = 0.9 + _rnd() * 1.4;
      }
    }
    if (mode == _BirdMode.hop) {
      final u = _clamp(mt / dur, 0, 1);
      a = _lerp(from, to, _ease(u));
      _hgt = math.sin(math.pi * u) * 13;
      _wing = math.sin(mt * 34) * 30;
      if (u >= 1) {
        mode = _BirdMode.idle;
        mt = 0;
        dur = 0.7 + _rnd() * 1.6;
        sq.v -= 7; // присед при приземлении
      }
    } else if (mode == _BirdMode.peck) {
      _peck = 38 * math.max(0.0, math.sin(mt * math.pi / 0.3));
      tilt.t = 0;
      if (mt > 0.6) {
        mode = _BirdMode.idle;
        mt = 0;
        dur = 0.8 + _rnd() * 1.4;
      }
    } else if (mode == _BirdMode.fly) {
      final u = _clamp(mt / dur, 0, 1);
      a = from + _ease(u) * _tau;
      _hgt = math.sin(math.pi * u) * 24 + (u > 0 && u < 1 ? 4.0 : 0.0);
      _wing = math.sin(t * 42) * 55;
      lean.t = 22 * math.sin(math.pi * u);
      if (u >= 1) {
        a = from;
        mode = _BirdMode.idle;
        mt = 0;
        dur = 1.2;
        sq.v -= 9;
      }
    }
    face.step(dt, 140, 12);
    sq.step(dt, 280, 11);
    tilt.step(dt, 90, 10);
    lean.step(dt, 90, 12);
    if (t > nb) {
      blink = 0.14;
      nb = t + 1.8 + _rnd() * 3;
    }
    blink -= dt;
    breathe();
  }

  @override
  void front(Canvas c, FramePalette p) {
    final pos = _pt(cx, cy, R + 3.5 + _hgt, a);
    final s = sq.x + math.sin(t * 2.4) * 0.015;
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate((a * 57.3 + lean.x * face.x) * _deg);
    c.scale(face.x * (1 + (1 - s) * 0.9), s);
    final legs = _stroke(_o, 2.2);
    c.drawLine(const Offset(-2, -3), const Offset(-4, 1), legs);
    c.drawLine(const Offset(4, -3), const Offset(6, 1), legs);
    c.drawPath(Path()..moveTo(-9, -9)..quadraticBezierTo(-21, -12, -23, -5)..quadraticBezierTo(-17, -3, -8, -4)..close(), _fill(_bd));
    c.drawOval(_ov(0, -13, 13.5, 11.5), _fill(_b));
    c.drawOval(_ov(3.5, -9.5, 8, 6.5), _fill(_y));
    c.save();
    c.translate(0, -17);
    c.rotate(-_wing * _deg);
    c.translate(0, 17);
    c.drawOval(_ov(-4, -14, 8, 5.5), _fill(_bd));
    c.restore();
    c.save();
    c.translate(4, -18);
    c.rotate((tilt.x + _peck) * _deg);
    c.translate(-4, 18);
    c.drawCircle(const Offset(6, -25), 9, _fill(_b));
    c.drawCircle(const Offset(8.5, -23), 4.3, _fill(Colors.white));
    c.drawOval(_ov(9.5, -26.5, 1.9, blink > 0 ? 0.3 : 2.3), _fill(const Color(0xFF1B1D27)));
    final beak = Path()..moveTo(14, -26.5)..quadraticBezierTo(20.5, -24.5, 14, -22)..close();
    c.drawPath(beak, _fill(_o));
    c.drawPath(beak, _stroke(_o, 1.6));
    c.restore();
    c.restore();
  }
}

// ───────────── 09 Призрачок ─────────────
class _Ghost extends FrameSim {
  _Ghost() : super(100, 108, 62, 56, const [Color(0xFFD9CCFF), Color(0xFF8A7CFF), Color(0xFF5A6BE0)]);
  final e = Spring(), boo = Spring();
  double side = 1, cyc = 0, bt = 9, blink = 0, nb = 1.5;
  double _x = 0, _y = 0, _tilt = 0, _sc = 1, _bc = 0;

  @override
  void update(double dt) {
    cyc += dt;
    if (cyc >= 7) {
      cyc -= 7;
      side = _rnd() < 0.5 ? -1.0 : 1.0;
    }
    if (edge()) bt = 0;
    bt += dt;
    e.t = cyc > 0.8 && cyc < 5.6 ? 1.0 : 0.0;
    e.step(dt, 110, 9);
    boo.t = bt < 1.5 ? 1.0 : 0.0;
    boo.step(dt, 150, 9);
    final ee = e.x, b = boo.x, bc = _clamp(b, 0, 1), sd = side;
    var x = _lerp(cx + sd * 14, cx + sd * 74, ee), y = _lerp(cy - 8, cy - 36, ee);
    x = _lerp(x, cx, bc);
    y = _lerp(y, cy - 78, b) + math.sin(t * 2.2) * 3;
    _x = x;
    _y = y;
    _tilt = -sd * 14 * ee * (1 - bc) + math.sin(t * 1.7) * 4;
    _sc = 1.3 + b * 0.28;
    _bc = bc;
    if (t > nb) {
      blink = 0.15;
      nb = t + 1.6 + _rnd() * 2.6;
    }
    blink -= dt;
    breathe();
  }

  @override
  void back(Canvas c, FramePalette p) {
    final k = p.glove, bc = _bc, st = _stroke(k, 2);
    c.save();
    c.translate(_x, _y);
    c.rotate(_tilt * _deg);
    c.scale(_sc);
    c.scale(1 - math.sin(t * 2.2 + 1) * 0.025, 1 + math.sin(t * 2.2 + 1) * 0.035);
    final aw = math.sin(t * 5) * 14;
    for (final s in const [-1.0, 1.0]) {
      c.save();
      c.translate(15 * s, 0);
      c.rotate((s < 0 ? aw + bc * 70 : -aw - bc * 70) * _deg);
      c.translate(-15 * s, 0);
      final r = _ov(18 * s, 2, 4.2, 6.5);
      c.drawOval(r, _fill(Colors.white));
      c.drawOval(r, st);
      c.restore();
    }
    final d = Path()
      ..moveTo(-18, 6)
      ..cubicTo(-18, -13, -10, -24, 0, -24)
      ..cubicTo(10, -24, 18, -13, 18, 6)
      ..lineTo(18, 15);
    for (var i = 0; i < 4; i++) {
      final x0 = 18 - i * 9.0, x1 = x0 - 9;
      d.quadraticBezierTo((x0 + x1) / 2, 24 + math.sin(t * 5 + i * 1.4) * 2.8, x1, 15 + math.sin(t * 4 + i) * 0.8);
    }
    d.close();
    c.drawPath(d, _fill(Colors.white));
    c.drawPath(d, st);
    c.drawCircle(const Offset(-9.5, -3), 2.8, _fill(const Color(0xFFFFB3C7)));
    c.drawCircle(const Offset(9.5, -3), 2.8, _fill(const Color(0xFFFFB3C7)));
    final bs = blink > 0 && bc < 0.5 ? 0.12 : 1 + bc * 0.25, lx = -side * 1.6 * (1 - bc);
    for (final ex in const [-6.0, 6.0]) {
      c.drawOval(_ov(ex + lx, -9, 2.7, 3.7 * bs), _fill(const Color(0xFF1B1D27)));
    }
    c.drawOval(_ov(0, 1.5, 2 + bc * 2.6, 1.5 + bc * 4), _fill(const Color(0xFF1B1D27)));
    c.restore();
  }
}
