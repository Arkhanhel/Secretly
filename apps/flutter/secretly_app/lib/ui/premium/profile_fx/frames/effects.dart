// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../../profile_fx.dart';

// ───────────── 05 Слайм ─────────────
class _Drip {
  _Drip(this.a, this.wait);
  final double a;
  double wait, len = 0, x = 0, y = 0, v = 0, sa = 0, bx = 0, by = 0;
  int ph = 0; // 0 ждёт · 1 растёт · 2 падает · 3 шлёп
  final ls = Spring();
}

class _Slime extends FrameSim {
  _Slime() : super(100, 94, 62, 55, const [Color(0xFFC4F56B), Color(0xFF4FD68A), Color(0xFF1FB5A8)]) {
    ringWidth = 10;
  }
  static const _g = Color(0xFF4FD68A);
  final j = Spring();
  final drips = [_Drip(math.pi, 0.3), _Drip(math.pi + 0.5, 1.8), _Drip(math.pi - 0.55, 3.1)];

  @override
  Path ringPath() => _blob(cx, cy, R, (a) => 1.1 * math.sin(3 * a + t * 1.4) + 0.7 * math.sin(5 * a - t * 2) + j.x * 5 * math.sin(3 * a + 1));

  @override
  void update(double dt) {
    if (edge()) j.v += 10;
    j.step(dt, 110, 4.5); // желе: низкое затухание
    final sx = 1 - j.x * 0.035, sy = 1 + j.x * 0.035;
    body(sx, sy);
    for (final d in drips) {
      final b0 = _pt(cx, cy, R + 2, d.a);
      d.bx = cx + (b0.dx - cx) * sx;
      d.by = cy + (b0.dy - cy) * sy;
      switch (d.ph) {
        case 0:
          d.wait -= dt;
          if (d.wait <= 0) {
            d.ph = 1;
            d.len = 0;
          }
        case 1:
          d.len += dt * (active ? 15 : 6) * (1 - d.len / 40);
          if (d.len >= 20) {
            d
              ..ph = 2
              ..x = d.bx
              ..y = d.by + d.len
              ..v = 0;
            d.ls
              ..x = d.len
              ..v = 0
              ..t = 0;
          }
        default:
          d.ls.step(dt, 220, 7); // шея пружинит обратно
          if (d.ph == 2) {
            d.v += 560 * dt;
            d.y += d.v * dt;
            if (d.y >= 190) {
              d.ph = 3;
              d.sa = 0;
            }
          } else {
            d.sa += dt;
            if (d.sa > 0.6) {
              d.ph = 0;
              d.wait = (active ? 0.15 : 0.8) + _rnd() * (active ? 0.5 : 2.4);
            }
          }
      }
    }
  }

  @override
  void back(Canvas c, FramePalette p) {
    for (final d in drips) {
      final ls = d.ph == 1 ? d.len : (d.ph == 0 ? 0.0 : math.max(0.0, d.ls.x));
      final neg = d.ph >= 2 ? math.min(0.0, d.ls.x) : 0.0;
      if (ls > 0.4 || neg < -0.3) {
        c.drawLine(Offset(d.bx, d.by - 3), Offset(d.bx, d.by + ls), _stroke(_g, math.max(3.0, 9 - ls * 0.28 + neg)));
      }
      final br = d.ph == 1 ? 3.5 + ls * 0.13 : math.max(0.0, ls * 0.18);
      if (br > 0) c.drawCircle(Offset(d.bx, d.by + ls), br, _fill(_g));
      if (d.ph == 2) c.drawOval(_ov(d.x, d.y, 5.8 - math.min(1.5, d.v * 0.004), 6 + math.min(4.0, d.v * 0.008)), _fill(_g));
      if (d.ph == 3) {
        final u = d.sa / 0.6;
        c.drawOval(_ov(d.x, 192, 6 + math.sqrt(u) * 11, math.max(0.6, 3.2 - u * 3)), _fill(_op(_g, 1 - u)));
      }
    }
  }

  @override
  void front(Canvas c, FramePalette p) => withBody(c, () {
        c.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: R), -1.2 - math.pi / 2, 0.65, false, _stroke(const Color(0x99FFFFFF), 3));
      });
}

// ───────────── 08 Лава-лампа ─────────────
class _Lava extends FrameSim {
  _Lava() : super(100, 100, 62, 55);
  static const _b = [
    [0.0, 0.25, 0.7, 12.0], [1.1, -0.18, 0.9, 9.0], [2.3, 0.3, 0.55, 13.0],
    [3.4, -0.22, 0.8, 8.5], [4.4, 0.2, 1.1, 10.5], [5.4, -0.28, 0.65, 12.0],
  ];
  // Метаболы: размытие + порог альфы (значения смещения — в шкале 0..255).
  static final _goo = ui.ImageFilter.compose(
    outer: const ui.ColorFilter.matrix(<double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 22, -2550]),
    inner: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
  );
  final amp = Spring(1), spd = Spring(1);
  double ph = 0;
  final _pos = List<Offset>.filled(6, Offset.zero);
  final _rad = List<double>.filled(6, 0);

  @override
  void update(double dt) {
    amp.t = active ? 1.45 : 1.0;
    spd.t = active ? 2.6 : 1.0;
    amp.step(dt, 30, 9);
    spd.step(dt, 30, 9);
    ph += dt * spd.x;
    for (var i = 0; i < 6; i++) {
      final b = _b[i], ang = b[0] + ph * b[1];
      final d = R + 1 + (0.5 - 0.5 * math.cos(ph * b[2] + i * 1.3)) * 25 * amp.x;
      _rad[i] = b[3] * (0.85 + 0.15 * math.sin(ph * 1.7 + i)) * (1 - (d - R) / 90);
      _pos[i] = _pt(cx, cy, d, ang);
    }
    breathe(1.4, 0.008);
  }

  @override
  void back(Canvas c, FramePalette p) {
    final a = (ph * 25 % 360) * _deg, co = math.cos(a), si = math.sin(a);
    Offset rot(double x, double y) => Offset(100 + x * co - y * si, 100 + x * si + y * co);
    final shader = _linG(rot(-70, -70), rot(70, 70), const [Color(0xFFFF3D7F), Color(0xFFFF8A3D), Color(0xFFFFD24D)]);
    c.saveLayer(const Rect.fromLTWH(-20, -20, 240, 240), Paint()..imageFilter = _goo);
    c.drawCircle(Offset(cx, cy), R, _stroke(Colors.white, 10)..shader = shader);
    final f = Paint()..shader = shader;
    for (var i = 0; i < 6; i++) {
      c.drawCircle(_pos[i], _rad[i], f);
    }
    c.restore();
  }
}

// ───────────── 10 Стрик ─────────────
class _Ember {
  double age, life = 1.2, x = 100, sd = 0;
  _Ember(this.age);
}

class _Fire extends FrameSim {
  _Fire() : super(100, 106, 60, 55, const [Color(0xFFFFD23F), Color(0xFFFF8A1F), Color(0xFFFF3D2E)]);
  static const _cols = [Color(0xFFFF3D2E), Color(0xFFFF8A1F), Color(0xFFFFD23F)];
  static final _flame = Path()
    ..moveTo(0, -7)
    ..cubicTo(3, -3, 5, -1, 5, 2)
    ..cubicTo(5, 5, 2.5, 7, 0, 7)
    ..cubicTo(-2.5, 7, -5, 5, -5, 2)
    ..cubicTo(-5, -1, -2, -2, 0, -7)
    ..close();
  final hgt = Spring(1), pop = Spring(1);
  int n = 12;
  double boost = 0;
  final em = List<_Ember>.generate(7, (i) => _Ember(i * 0.25));

  @override
  void update(double dt) {
    if (edge()) {
      n++;
      pop.v += 14;
      hgt.v += 5;
      boost = 1.3;
    }
    boost -= dt;
    hgt.t = boost > 0 ? 1.65 : 1.0;
    hgt.step(dt, 60, 8);
    pop.step(dt, 300, 12);
    for (final e in em) {
      e.age += dt;
      if (e.age > e.life) {
        e
          ..age = 0
          ..life = 0.9 + _rnd() * 0.8
          ..x = cx + (_rnd() - 0.5) * 56
          ..sd = _rnd() * 6;
      }
    }
    breathe();
  }

  @override
  void back(Canvas c, FramePalette p) {
    final h = hgt.x;
    const sc = [1.0, 0.7, 0.42];
    for (var l = 0; l < 3; l++) {
      c.drawPath(
          _blob(cx, cy, R - 2, (a) {
            final up = _pow(math.cos(a) * 0.5 + 0.5, 2.2);
            return sc[l] * (3 + up * h * (13 + 12 * _pow(math.sin(5 * a + t * 1.8 + l * 0.7).abs(), 2) + 4.5 * math.sin(8 * a - t * 8 + l * 1.3))) +
                1.5 * math.sin(11 * a + t * 6 + l);
          }, 64),
          _fill(_cols[l]));
    }
    for (final e in em) {
      final u = e.age / e.life;
      final o = Offset(e.x + math.sin(e.age * 6 + e.sd) * 4, cy - R - 12 - e.age * 42 * h + (e.x - cx).abs() * 0.3);
      c.drawCircle(o, 2.3 * (1 - u), _fill(_op(const Color(0xFFFFB23F), u < 0.15 ? u / 0.15 : 1 - u)));
    }
  }

  @override
  void front(Canvas c, FramePalette p) {
    c.save();
    c.translate(cx + 44, cy + 48);
    c.scale(pop.x);
    final r = _rr(-23, -12, 46, 24, 12);
    c.drawRRect(r, _fill(p.chip));
    c.drawRRect(r, _stroke(p.bg, 3));
    c.save();
    c.translate(-10, 0);
    c.scale(1.05);
    c.drawPath(_flame, _fill(const Color(0xFFFF8A1F)));
    c.restore();
    c.save();
    c.translate(-10, 1.8);
    c.scale(0.5);
    c.drawPath(_flame, _fill(const Color(0xFFFFD23F)));
    c.restore();
    _text(c, '${inputs.streak ?? n}', const Offset(6, 0), 13, Colors.white);
    c.restore();
  }
}

// ───────────── 11 Level Up ─────────────
class _Confetti {
  double age = 9, x = 0, y = 0, vx = 0, vy = 0, r = 0, vr = 0;
}

class _Xp extends FrameSim {
  _Xp() : super(100, 98, 62, 56);
  static const _grad = [Color(0xFF7CFFB2), Color(0xFF3DD6FF), Color(0xFF7A5CFF)];
  static const _cc = [Color(0xFF7CFFB2), Color(0xFF3DD6FF), Color(0xFF7A5CFF), Color(0xFFFF4F9A), Color(0xFFFFD23F)];
  final xp = Spring(0.35), bp = Spring(1);
  double goal = 0.35, fl = 0, pl = 9;
  int lvl = 7;
  final cf = List<_Confetti>.generate(16, (_) => _Confetti());

  void _levelUp() {
    lvl++;
    goal = 0.02;
    xp
      ..x = 0
      ..v = 0;
    fl = 1;
    bp.v += 18;
    for (final p in cf) {
      final a = -1.2 + _rnd() * 2.4, o = _pt(cx, cy, R, a), s = 70 + _rnd() * 80;
      p
        ..age = 0
        ..x = o.dx
        ..y = o.dy
        ..vx = math.sin(a) * s
        ..vy = -math.cos(a) * s - 40
        ..r = _rnd() * 360
        ..vr = (_rnd() - 0.5) * 900;
    }
  }

  @override
  void update(double dt) {
    if (inputs.xp != null) {
      goal = inputs.xp!;
    } else {
      goal += dt * 0.035;
    }
    if (edge()) {
      goal += 0.25;
      pl = 0;
      bp.v += 5;
    }
    xp.t = goal;
    xp.step(dt, 70, 13);
    if (xp.x >= 1 && inputs.xp == null) _levelUp();
    bp.step(dt, 300, 12);
    fl = math.max(0.0, fl - dt * 2.2);
    for (final p in cf) {
      p.age += dt;
      p.vy += 240 * dt;
      p.vx *= 1 - dt * 1.2;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.r += p.vr * dt;
    }
    pl += dt;
    final br = math.sin(t * 1.6) * 0.005;
    body(1 + br + fl * 0.02, 1 - br + fl * 0.02);
  }

  @override
  void back(Canvas c, FramePalette p) {
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: R);
    c.drawCircle(Offset(cx, cy), R, _stroke(p.track, 8));
    c.drawArc(rect, -math.pi / 2, _clamp(xp.x, 0, 1) * _tau, false, _stroke(Colors.white, 8)..shader = _linG(rect.topLeft, rect.bottomRight, _grad));
    if (fl > 0.01) c.drawCircle(Offset(cx, cy), R, _stroke(_op(Colors.white, fl), 8 + (1 - fl) * 8));
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (var i = 0; i < cf.length; i++) {
      final q = cf[i];
      if (q.age >= 1.3) continue;
      c.save();
      c.translate(q.x, q.y);
      c.rotate(q.r * _deg);
      c.scale(1, math.cos(q.r * 0.05));
      c.drawRRect(_rr(-3, -1.8, 6, 3.6, 1), _fill(_op(_cc[i % 5], 1 - q.age / 1.3)));
      c.restore();
    }
    c.save();
    c.translate(cx, cy + R + 2);
    c.scale(bp.x);
    final r = _rr(-25, -11, 50, 22, 11);
    c.drawRRect(r, Paint()..shader = _linG(const Offset(-25, 0), const Offset(25, 0), _grad));
    c.drawRRect(r, _stroke(p.bg, 3));
    _text(c, 'LVL ${inputs.level ?? lvl}', Offset.zero, 11.5, const Color(0xFF10131F), FontWeight.w800, 1, 0.4);
    c.restore();
    if (pl < 1) {
      c.save();
      c.translate(cx + 40, cy - R - 2 - pl * 26);
      c.scale(pl < 0.15 ? _backOut(pl / 0.15) : 1.0);
      _text(c, '+25 XP', Offset.zero, 12, p.ink, FontWeight.w800, pl < 0.15 ? pl / 0.15 : 1 - (pl - 0.15) / 0.85);
      c.restore();
    }
  }
}

// ───────────── 12 В эфире ─────────────
class _Heart {
  double age = 9, life = 2, x = 0, sd = 0, s = 1;
}

class _Live extends FrameSim {
  _Live() : super(100, 100, 62, 56, const [Color(0xFFFF2D55), Color(0xFFFF6A3D), Color(0xFFFF2D55)]);
  static const _hc = [Color(0xFFFF2D55), Color(0xFFFF6AA0), Color(0xFFB048E8), Color(0xFFFF8A3D)];
  static final _hp = _heart();
  final hs = List<_Heart>.generate(14, (_) => _Heart());
  int hi = 0, burst = 0, v = 1204;
  double nh = 0.6, bt = 0, nv = 1;

  void _spawn() => hs[hi++ % hs.length]
    ..age = 0
    ..life = 1.7 + _rnd() * 0.6
    ..x = cx + 44 + (_rnd() - 0.5) * 8
    ..sd = _rnd() * 6
    ..s = 0.85 + _rnd() * 0.5;

  @override
  void update(double dt) {
    if (edge()) {
      burst += 9;
      v += 30 + (_rnd() * 40).floor();
    }
    bt -= dt;
    if (burst > 0 && bt <= 0) {
      _spawn();
      burst--;
      bt = 0.07;
    }
    if (t > nh) {
      _spawn();
      nh = t + 1 + _rnd() * 1.2;
    }
    for (final h in hs) {
      h.age += dt;
    }
    if (t > nv) {
      v += 1 + (_rnd() * 5).floor();
      nv = t + 0.5 + _rnd() * 1.3;
    }
    breathe();
  }

  @override
  void back(Canvas c, FramePalette p) {
    for (var k = 0; k < 3; k++) {
      final u = (t * 0.5 + k / 3) % 1;
      c.drawCircle(Offset(cx, cy), R + 3 + u * 28, _stroke(_op(const Color(0xFFFF2D55), (1 - u) * 0.55), 3.2 * (1 - u) + 0.4));
    }
  }

  @override
  void front(Canvas c, FramePalette p) {
    for (var i = 0; i < hs.length; i++) {
      final h = hs[i], u = h.age / h.life;
      if (u >= 1) continue;
      final pop = u < 0.12 ? _backOut(u / 0.12) : 1.0;
      c.save();
      c.translate(h.x + math.sin(u * 7 + h.sd) * 8 - u * 12, cy + 44 - u * 96);
      c.rotate(math.sin(u * 6 + h.sd) * 16 * _deg);
      c.scale(h.s * pop * 1.1);
      c.drawPath(_hp, _fill(_op(_hc[i % 4], u > 0.6 ? 1 - (u - 0.6) / 0.4 : 1.0)));
      c.restore();
    }
    c.save();
    c.translate(cx + 40, cy - 58);
    final vr = _rr(-24, -9.5, 48, 19, 9.5);
    c.drawRRect(vr, _fill(p.chip));
    c.drawRRect(vr, _stroke(p.bg, 2.5));
    c.drawOval(_ov(-13, 0, 4, 2.6), _stroke(Colors.white, 1.4));
    c.drawCircle(const Offset(-13, 0), 1.3, _fill(Colors.white));
    _text(c, _fmtInt(inputs.viewers ?? v), const Offset(5, 0), 9.5, Colors.white);
    c.restore();
    c.save();
    c.translate(cx, cy + R + 1);
    c.scale(1 + math.sin(t * 3.2) * 0.035);
    final lr = _rr(-23, -10.5, 46, 21, 7);
    c.drawRRect(lr, _fill(const Color(0xFFFF2D55)));
    c.drawRRect(lr, _stroke(p.bg, 3));
    c.drawCircle(const Offset(-12, 0), 3, _fill(_op(Colors.white, (t % 1.1) < 0.65 ? 1.0 : 0.25)));
    _text(c, 'LIVE', const Offset(4.5, 0), 11, Colors.white, FontWeight.w800, 1, 0.6);
    c.restore();
  }
}

// ───────────── 13 Бабл-гам ─────────────
class _Drop {
  double x = 0, y = 0, vx = 0, vy = 0, age = 9;
}

class _Gum extends FrameSim {
  _Gum() : super(98, 98, 62, 56, const [Color(0xFFFFB3D9), Color(0xFFFF5FA8), Color(0xFFC94BD8)]);
  static const _a = 2.3;
  int ph = 0; // 0 отдых · 1 надувается · 2 лопнул
  double wait = 0.8, rt = 0, pa = 9, res = 0, bx = 0, by = 0, br = 0;
  final r = Spring(), sq = Spring(1);
  final drops = List<_Drop>.generate(7, (_) => _Drop());

  void _pop() {
    ph = 2;
    pa = 0;
    res = 1;
    sq.v += 4;
    for (final d in drops) {
      final a = _rnd() * _tau, s = 70 + _rnd() * 90;
      d
        ..x = bx
        ..y = by
        ..vx = math.sin(a) * s
        ..vy = -math.cos(a) * s
        ..age = 0;
    }
    br = r.x;
    r
      ..x = 0
      ..v = 0;
    rt = 0;
  }

  @override
  void update(double dt) {
    final an = _pt(cx, cy, R + 1, _a), nx = math.sin(_a), ny = -math.cos(_a);
    if (edge()) {
      if (ph == 1 && r.x > 5) {
        _pop();
      } else if (ph == 0) {
        wait = 0;
      }
    }
    if (ph == 0) {
      wait -= dt;
      if (wait <= 0) {
        ph = 1;
        sq.v -= 3;
      }
    } else if (ph == 1) {
      rt += dt * (7.5 - rt * 0.18); // медленнее к концу, как выдох
      if (rt >= 30) _pop();
    } else {
      pa += dt;
      if (pa > 0.7) {
        ph = 0;
        wait = 0.9 + _rnd() * 1.8;
      }
    }
    r.t = rt * (1 + 0.035 * math.sin(t * 9));
    r.step(dt, 120, 9);
    sq.step(dt, 220, 8);
    final rr = math.max(0.0, r.x);
    bx = an.dx + nx * rr * 0.82;
    by = an.dy + ny * rr * 0.82;
    for (final d in drops) {
      d.age += dt;
      d.vy += 300 * dt;
      d.x += d.vx * dt;
      d.y += d.vy * dt;
    }
    res = math.max(0.0, res - dt * 0.4);
    final b = math.sin(t * 1.6) * 0.006;
    body(sq.x + b, 2 - sq.x - b);
  }

  @override
  void front(Canvas c, FramePalette p) {
    final an = _pt(cx, cy, R + 1, _a);
    if (res > 0.01) {
      c.drawPath(_blob(an.dx, an.dy, 6, (a) => 2.2 * math.sin(3 * a + 1) + 1.4 * math.sin(5 * a), 20), _fill(_op(const Color(0xFFFF7AB8), res * 0.9)));
    }
    final rr = math.max(0.0, r.x);
    if (rr > 0.6) {
      final wob = math.sin(t * 7) * 0.045;
      c.save();
      c.translate(bx, by);
      c.rotate(_a);
      c.scale(1 - wob, 1 + wob);
      c.drawCircle(Offset.zero, rr, _fill(const Color(0xD1FF8CC6)));
      c.drawCircle(Offset.zero, rr, _stroke(const Color(0xFFFF5FA8), 2));
      c.drawOval(_ov(-rr * 0.4, -rr * 0.3, rr * 0.16, rr * 0.28), _fill(const Color(0xBFFFFFFF)));
      c.restore();
    }
    if (pa < 0.22) {
      final rr2 = br * (1 + pa * 2.2);
      c.drawPath(_blob(bx, by, rr2 * 0.7, (a) => rr2 * 0.45 * _pow(math.sin(4 * a + 0.5).abs(), 3), 40), _fill(_op(const Color(0xFFFF8CC6), 1 - pa / 0.22)));
    }
    for (final d in drops) {
      if (d.age < 0.55) c.drawCircle(Offset(d.x, d.y), 2.6 * (1 - d.age / 0.55), _fill(const Color(0xFFFF7AB8)));
    }
  }
}

// ───────────── 14 Стикерпак ─────────────
class _Sticker {
  _Sticker(this.kind, this.a, this.tl);
  final String kind;
  final double a, tl;
  final rot = Spring(), out = Spring();
  double next = 1 + _rnd() * 3;
}

class _Stickers extends FrameSim {
  _Stickers() : super(100, 100, 62, 56, const [Color(0xFFC8FF3D), Color(0xFF3DFFD8), Color(0xFFC77DFF)]);
  final s = [_Sticker('spark', 0.78, 12), _Sticker('heart', -1.0, -14), _Sticker('smile', -2.3, -8), _Sticker('pill', 2.35, 10)];
  double spin = 0, blink = 0, nb = 2;
  static final _star = Path()
    ..moveTo(0, -13)
    ..cubicTo(1.5, -4, 4, -1.5, 13, 0)
    ..cubicTo(4, 1.5, 1.5, 4, 0, 13)
    ..cubicTo(-1.5, 4, -4, 1.5, -13, 0)
    ..cubicTo(-4, -1.5, -1.5, -4, 0, -13)
    ..close();
  static final _hp = _heart(1.75);

  @override
  void update(double dt) {
    final p = active;
    if (edge()) {
      for (var i = 0; i < s.length; i++) {
        s[i].out.v += p ? 40 : -20;
        s[i].rot.v += (i.isOdd ? -1 : 1) * (p ? 520 : 300);
      }
    }
    spin += dt * (p ? 140 : 22);
    for (var i = 0; i < s.length; i++) {
      final q = s[i];
      if (t > q.next) {
        q.rot.v += (_rnd() - 0.5) * 300;
        q.next = t + 1.8 + _rnd() * 3.5;
      }
      q.out.t = p ? 17.0 : 0.0;
      q.rot.t = p ? (i.isOdd ? -10.0 : 10.0) : 0.0;
      q.out.step(dt, 140, 9);
      q.rot.step(dt, 90, 5); // маятник
    }
    if (t > nb) {
      blink = 0.14;
      nb = t + 1.8 + _rnd() * 3;
    }
    blink -= dt;
    breathe();
  }

  @override
  void front(Canvas c, FramePalette p) {
    final sh = _fill(_op(Colors.black, p.shadow));
    for (var i = 0; i < s.length; i++) {
      final q = s[i];
      final bob = active ? math.sin(t * 2.2 + i * 1.7) * 3 : 0.0;
      final o = _pt(cx, cy, R + 4 + q.out.x + bob, q.a + (active ? math.sin(t * 0.9 + i) * 0.06 : 0.0));
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate((q.tl + q.rot.x + (q.kind == 'spark' ? spin : 0.0)) * _deg);
      c.scale(1 + math.max(0.0, q.out.x) * 0.006);
      switch (q.kind) {
        case 'spark':
          c.drawPath(_star.shift(const Offset(1.5, 2.5)), sh);
          c.drawPath(_star, _stroke(Colors.white, 5));
          c.drawPath(_star, _fill(const Color(0xFFB8FF3D)));
        case 'heart':
          c.drawPath(_hp.shift(const Offset(1.5, 2.5)), sh);
          c.drawPath(_hp, _stroke(Colors.white, 5));
          c.drawPath(_hp, _fill(const Color(0xFFFF4F9A)));
        case 'smile':
          c.drawCircle(const Offset(1.5, 2.5), 13.5, sh);
          c.drawCircle(Offset.zero, 13.5, _fill(Colors.white));
          c.drawCircle(Offset.zero, 11, _fill(const Color(0xFFFFD23F)));
          final dk = _fill(const Color(0xFF1B1D27));
          c.drawOval(_ov(-4, -3, 1.6, blink > 0 ? 0.3 : 2.4), dk);
          c.drawOval(_ov(4, -3, 1.6, blink > 0 || active ? 0.3 : 2.4), dk);
          c.drawPath(Path()..moveTo(-5, 2)..quadraticBezierTo(0, 7.5, 5, 2), _stroke(const Color(0xFF1B1D27), 2));
        default:
          c.drawRRect(_rr(-19.5, -9, 42, 23, 11.5), sh);
          c.drawRRect(_rr(-21, -11.5, 42, 23, 11.5), _fill(Colors.white));
          c.drawRRect(_rr(-18.5, -9, 37, 18, 9), _fill(const Color(0xFF7A5CFF)));
          _text(c, 'вайб', Offset.zero, 10.5, Colors.white, FontWeight.w800);
      }
      c.restore();
    }
  }
}
