// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../../profile_fx.dart';

// ───────────── Поток ─────────────
class _Flow extends CoverSim {
  @override
  bool get persistent => true;
  late List<List<double>> p;
  Offset? v;
  double vt = -9;
  @override
  void init(Size s) => p = List.generate(520, (_) => [_rnd() * s.width, _rnd() * s.height, _rnd() * 6, 3 + _rnd() * 4]);
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    fade(c, s, dark ? const Color(0x13070710) : const Color(0x17FAF8F4), _c(dark, 0xFF070710, 0xFFFAF8F4));
    if (tap != null) {
      v = tap;
      vt = t;
    }
    final vo = t - vt < 2.6 ? v : null, vs = vo != null ? math.exp(-(t - vt) * 0.9) : 0.0;
    const bins = 16;
    final paths = List.generate(bins, (_) => Path());
    for (final q in p) {
      final a = (math.sin(q[0] * 0.008 + t * 0.21) + math.sin(q[1] * 0.011 - t * 0.16) + math.sin((q[0] + q[1]) * 0.004 + t * 0.1)) * 1.7;
      var vx = math.cos(a) * 42, vy = math.sin(a) * 42;
      if (vo != null) {
        final dx = q[0] - vo.dx, dy = q[1] - vo.dy, d2 = dx * dx + dy * dy, k = math.exp(-d2 / 9000) * vs * 260, ds = math.sqrt(d2 + 1);
        vx += -dy / ds * k - dx * 0.4 * vs; // вихрь
        vy += dx / ds * k - dy * 0.4 * vs;
      }
      final nx = q[0] + vx * dt, ny = q[1] + vy * dt;
      final bi = _clamp((q[0] / w * bins).floorToDouble(), 0, bins - 1).toInt();
      paths[bi]
        ..moveTo(q[0], q[1])
        ..lineTo(nx, ny);
      q[0] = nx;
      q[1] = ny;
      q[2] += dt;
      if (q[2] > q[3] || nx < -5 || nx > w + 5 || ny < -5 || ny > h + 5) {
        q[0] = _rnd() * w;
        q[1] = _rnd() * h;
        q[2] = 0;
      }
    }
    for (var i = 0; i < bins; i++) {
      final hue = (190 + (i + 0.5) / bins * 130 + math.sin(t * 0.2) * 20) % 360;
      final col = dark ? HSLColor.fromAHSL(0.55, hue, 0.95, 0.66).toColor() : HSLColor.fromAHSL(0.45, hue, 0.7, 0.46).toColor();
      c.drawPath(paths[i], _stroke(col, 1.3));
    }
  }
}

// ───────────── Голограмма ─────────────
class _Holo extends CoverSim {
  late List<List<double>> sp;
  final shocks = <List<double>>[];
  final hx = Spring(0.5), hy = Spring(0.5);
  @override
  void init(Size s) => sp = List.generate(140, (_) => [_rnd() * s.width, _rnd() * s.height, _rnd()]);
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    hx.t = pointer != null ? pointer.dx / w : 0.5 + 0.32 * math.sin(t * 0.37);
    hy.t = pointer != null ? pointer.dy / h : 0.5 + 0.3 * math.cos(t * 0.29);
    hx.step(dt, 40, 10);
    hy.step(dt, 40, 10);
    final sh = hx.x * 0.7 + hy.x * 0.4;
    c.drawRect(Offset.zero & s, _fill(_c(dark, 0xFF100E1A, 0xFFECEEF4)));
    final cols = dark
        ? const [Color(0xFFFF5FA8), Color(0xFFFFD66B), Color(0xFF6BFFD1), Color(0xFF6BB8FF), Color(0xFFB98CFF)]
        : const [Color(0xFFFFA3CF), Color(0xFFFFE59A), Color(0xFF9FFFE0), Color(0xFFA6D4FF), Color(0xFFD4B8FF)];
    final st = [for (var k = 0; k < 10; k++) (((k / 10 + sh) % 1 + 1) % 1, cols[k % 5])]..sort((a, b) => a.$1.compareTo(b.$1));
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, dark ? 0.5 : 0.75)
          ..shader = _linG(Offset.zero, Offset(w, h * 0.8), [for (final e in st) e.$2], [for (final e in st) e.$1]));
    final bo = Offset(hx.x * w, hy.x * h);
    c.drawRect(Offset.zero & s, Paint()..shader = ui.Gradient.radial(bo, w * 0.55, [_op(_white, dark ? 0.35 : 0.7), _op(_white, 0)]));
    final hatch = Path();
    for (var x = -h; x < w; x += 5) {
      hatch
        ..moveTo(x, h)
        ..lineTo(x + h, 0);
    }
    c.drawPath(hatch, _stroke(dark ? const Color(0x0DFFFFFF) : const Color(0x0D282850), 1, StrokeCap.butt));
    for (final q in sp) {
      final b = _pow(math.max(0.0, math.cos(((q[0] * 0.7 + q[1] * 0.35) / w) * 9 - sh * 14 + q[2] * 2)), 24);
      if (b < 0.05) continue;
      final l = 2 + b * 6, pp = _stroke(_op(_white, b), 1.2);
      c.drawLine(Offset(q[0] - l, q[1]), Offset(q[0] + l, q[1]), pp);
      c.drawLine(Offset(q[0], q[1] - l), Offset(q[0], q[1] + l), pp);
    }
    if (tap != null) shocks.add([tap.dx, tap.dy, t]);
    shocks.removeWhere((q) => t - q[2] >= 1.2);
    for (final q in shocks) {
      final u = (t - q[2]) / 1.2;
      c.drawCircle(Offset(q[0], q[1]), u * w * 0.6, _stroke(_op(_white, (1 - u) * 0.8), 6 * (1 - u) + 1));
    }
  }
}

// ───────────── Точечный океан ─────────────
class _DotWave extends CoverSim {
  final rip = <List<double>>[];
  @override
  void init(Size s) {}
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height, hz = h * 0.26, f = h * 0.62;
    const cam = 1.25;
    _vFill(c, s, _c(dark, 0xFF04060F, 0xFFF7F8FC), _c(dark, 0xFF0B1024, 0xFFECEFFA));
    if (tap != null && tap.dy > hz + 4) {
      final z = f * cam / (tap.dy - hz);
      rip.add([(tap.dx - w / 2) * z / (w * 0.42), z, t]);
    }
    rip.removeWhere((r) => t - r[2] >= 4);
    final c0 = dark ? const Color(0xFF3DD6FF) : const Color(0xFF4650DC), c1 = dark ? const Color(0xFFFF4F9A) : const Color(0xFFE6468C);
    const bins = 6;
    for (var iz = 26; iz >= 0; iz--) {
      final z = 1 + iz * 0.27, rows = List.generate(bins, (_) => <double>[]);
      for (var ix = -24; ix <= 24; ix++) {
        final x = ix * 0.13 * (0.6 + z * 0.4);
        var y = 0.22 * math.sin(x * 1.4 + t * 1.1) + 0.2 * math.sin(z * 1.2 - t * 1.4) + 0.08 * math.sin((x + z) * 3 + t * 2);
        for (final r in rip) {
          final a = t - r[2], dx = x - r[0], dz = z - r[1], d = math.sqrt(dx * dx + dz * dz);
          if (d < a * 1.8) y += 0.45 * math.sin(d * 4.5 - a * 7) * math.exp(-a * 0.8) * math.exp(-d * 0.35);
        }
        final sx = w / 2 + x * w * 0.42 / z, sy = hz + (cam - y) * f / z;
        if (sx < -4 || sx > w + 4 || sy > h + 4) continue;
        final u = _clamp(y * 1.4 + 0.5, 0, 1);
        rows[_clamp((u * bins).floorToDouble(), 0, bins - 1).toInt()]
          ..add(sx)
          ..add(sy);
      }
      final alpha = _clamp(1.25 - z / 8.5, 0, 1), r = math.max(0.5, 2.6 / z);
      for (var b = 0; b < bins; b++) {
        if (rows[b].isEmpty) continue;
        c.drawRawPoints(
            ui.PointMode.points,
            Float32List.fromList(rows[b]),
            Paint()
              ..color = _op(Color.lerp(c0, c1, (b + 0.5) / bins)!, alpha)
              ..strokeWidth = r * 2
              ..strokeCap = StrokeCap.round);
      }
    }
  }
}

// ───────────── Калейдоскоп ─────────────
class _Kaleido extends CoverSim {
  final rot = Spring();
  int pal = 0;
  final sh = List.generate(14, (i) => [_rnd() * 6, _rnd() * 6, 0.15 + _rnd() * 0.3, 0.3 + _rnd() * 0.5, 0.018 + _rnd() * 0.045, (i % 3).toDouble(), i.toDouble()]);
  static const _pd = [
    [Color(0xFFFF4F9A), Color(0xFFFFB23F), Color(0xFF3DD6FF), Color(0xFF7A5CFF), Color(0xFF3DFFB2)],
    [Color(0xFFFF5F6D), Color(0xFFFFD23F), Color(0xFFFF8A3D), Color(0xFFB048E8), Color(0xFFFF3D8B)],
    [Color(0xFF3DFFB2), Color(0xFF3DD6FF), Color(0xFF4F8CFF), Color(0xFFC4F56B), Color(0xFF7A5CFF)],
  ];
  static const _pl = [
    [Color(0xFFF06292), Color(0xFFFFB74D), Color(0xFF4FC3F7), Color(0xFF9575CD), Color(0xFF4DB6AC)],
    [Color(0xFFE57373), Color(0xFFFFD54F), Color(0xFFFF8A65), Color(0xFFBA68C8), Color(0xFFF48FB1)],
    [Color(0xFF4DB6AC), Color(0xFF4FC3F7), Color(0xFF7986CB), Color(0xFFAED581), Color(0xFF9575CD)],
  ];
  @override
  void init(Size s) {}
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    if (tap != null) {
      rot.v += 1.6;
      pal++;
    }
    rot.t += dt * 0.06;
    rot.step(dt, 8, 3);
    c.drawRect(Offset.zero & s, _fill(_c(dark, 0xFF0B0914, 0xFFFBF8F2)));
    final p = (dark ? _pd : _pl)[pal % 3], rr = math.sqrt(w * w + h * h) / 2;
    const n = 12;
    final sector = Path()
      ..moveTo(0, 0)
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: rr), -math.pi / n - 0.002, _tau / n + 0.004, false)
      ..close();
    final mode = dark ? BlendMode.plus : BlendMode.multiply;
    for (var k = 0; k < n; k++) {
      c.save();
      c.translate(w / 2, h / 2);
      c.rotate(k * _tau / n + rot.x);
      if (k.isOdd) c.scale(1, -1); // зеркало
      c.clipPath(sector);
      for (final q in sh) {
        final r = rr * (0.08 + 0.85 * (0.5 + 0.5 * math.sin(t * q[2] + q[0]))), a = math.sin(t * q[3] + q[1]) * 0.3;
        final x = math.cos(a) * r, y = math.sin(a) * r, z = rr * q[4] * (0.8 + 0.4 * math.sin(t + q[0]));
        final paint = _fill(_op(p[q[6].toInt() % 5], dark ? 0.55 : 0.45))..blendMode = mode;
        switch (q[5].toInt()) {
          case 0:
            c.drawCircle(Offset(x, y), z, paint);
          case 1:
            final path = Path();
            for (var j = 0; j < 3; j++) {
              final qq = t * 0.5 + q[0] + j * _tau / 3, pp = Offset(x + math.cos(qq) * z, y + math.sin(qq) * z);
              j == 0 ? path.moveTo(pp.dx, pp.dy) : path.lineTo(pp.dx, pp.dy);
            }
            c.drawPath(path..close(), paint);
          default:
            c.save();
            c.translate(x, y);
            c.rotate(t * 0.4 + q[0]);
            c.drawOval(_ov(0, 0, z * 1.6, z * 0.35), paint);
            c.restore();
        }
      }
      c.restore();
    }
  }
}

// ───────────── Салют ─────────────
class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.life, this.c) : px = x, py = y;
  double x, y, px, py, vx, vy, age = 0;
  final double life;
  final Color c;
}

class _Fireworks extends CoverSim {
  @override
  bool get persistent => true;
  final rk = <List<double>>[];
  final pp = <_Spark>[];
  double next = 0.3;
  @override
  void init(Size s) {}
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    fade(c, s, dark ? const Color(0x33060612) : const Color(0x38F8F4EE), _c(dark, 0xFF060612, 0xFFF8F4EE));
    final pal = dark
        ? const [Color(0xFFFF4F9A), Color(0xFFFFD23F), Color(0xFF3DD6FF), Color(0xFFB98CFF), Color(0xFF7CFFB2), Color(0xFFFF8A3D)]
        : const [Color(0xFFE0306A), Color(0xFFE8901A), Color(0xFF2C7BE5), Color(0xFF8A3FE0), Color(0xFF1FA878), Color(0xFFE0501F)];
    void burst(double x, double y) {
      final c1 = pal[(_rnd() * 6).floor()], c2 = pal[(_rnd() * 6).floor()], big = 70 + _rnd() * 60;
      for (var i = 0; i < 70; i++) {
        final a = i / 70 * _tau + _rnd() * 0.1, sp = big * (0.55 + _rnd() * 0.45);
        pp.add(_Spark(x, y, math.cos(a) * sp, math.sin(a) * sp, 1.3 + _rnd() * 0.9, i % 3 == 0 ? c2 : c1));
      }
    }

    if (t > next) {
      rk.add([w * (0.15 + _rnd() * 0.7), h + 4, -(h * 0.9 + _rnd() * h * 0.4), h * (0.14 + _rnd() * 0.32)]);
      next = t + 0.9 + _rnd() * 1.1;
    }
    if (tap != null) burst(tap.dx, tap.dy);
    final mode = dark ? BlendMode.plus : BlendMode.srcOver;
    rk.removeWhere((r) {
      final py = r[1];
      r[2] += h * 0.5 * dt;
      r[1] += r[2] * dt;
      c.drawLine(Offset(r[0], py), Offset(r[0] + math.sin(t * 30) * 0.5, r[1]), _stroke(dark ? const Color(0xE6FFDCAA) : const Color(0xCCA06E3C), 2)..blendMode = mode);
      if (r[1] <= r[3] || r[2] >= 0) {
        burst(r[0], r[1]);
        return true;
      }
      return false;
    });
    pp.removeWhere((q) {
      q.age += dt;
      if (q.age > q.life) return true;
      q
        ..px = q.x
        ..py = q.y;
      q.vx *= 1 - dt * 1.6;
      q.vy = q.vy * (1 - dt * 1.6) + 55 * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      final u = q.age / q.life, fl = u > 0.6 ? (math.sin(t * 40 + q.x) > 0 ? 1.0 : 0.3) : 1.0;
      c.drawLine(Offset(q.px, q.py), Offset(q.x, q.y), _stroke(_op(q.c, (1 - u) * fl), 1.8)..blendMode = mode);
      return false;
    });
  }
}

// ═════════════ Одно целое с фото ═════════════

// ───────────── Затмение ─────────────
class _Eclipse extends CoverSim {
  late List<List<double>> st;
  double dr = -9, da = 0, next = 3;
  @override
  void init(Size s) => st = List.generate(80, (_) => [_rnd(), _rnd(), _rnd()]);
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height, o = av, r = ar;
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = ui.Gradient.radial(o, w * 0.8, dark ? const [Color(0xFF1A1530), Color(0xFF040409)] : const [Color(0xFFFFE7C9), Color(0xFFE7DDF2)],
              [_clamp(r / (w * 0.8), 0, 0.99), 1.0]));
    if (dark) {
      for (final q in st) {
        c.drawRect(Rect.fromLTWH(q[0] * w, q[1] * h, 1.2, 1.2), _fill(_op(_white, 0.2 + 0.6 * math.max(0.0, math.sin(t * 1.3 + q[2] * 9)))));
      }
    }
    final cc = dark ? const Color(0xFFFFF0D7) : const Color(0xFFFF823C), mode = dark ? BlendMode.plus : BlendMode.srcOver;
    _glow(c, o, r * 3.4, cc, dark ? 0.55 : 0.45, mode);
    _glow(c, o, r * 1.7, cc, dark ? 0.9 : 0.8, mode);
    final ray = _c(dark, 0xFFFFF1DC, 0xFFFF8A3D);
    for (var i = 0; i < 72; i++) {
      final a = i / 72 * _tau + math.sin(t * 0.2 + i) * 0.03;
      final l = r * (0.25 + 1.3 * _pow(_hash(i), 3)) * (0.85 + 0.15 * math.sin(t * 0.7 + i * 1.7));
      final r0 = r * 1.02, bend = math.sin(t * 0.4 + i * 0.8) * 0.08;
      c.drawPath(
          Path()
            ..moveTo(o.dx + math.cos(a) * r0, o.dy + math.sin(a) * r0)
            ..quadraticBezierTo(o.dx + math.cos(a + bend) * (r0 + l * 0.5), o.dy + math.sin(a + bend) * (r0 + l * 0.5), o.dx + math.cos(a + bend * 2) * (r0 + l),
                o.dy + math.sin(a + bend * 2) * (r0 + l)),
          _stroke(_op(ray, dark ? 0.22 : 0.3), 1 + _hash(i, 2) * 1.6)..blendMode = mode);
    }
    if (tap != null) {
      dr = t;
      da = math.atan2(tap.dy - o.dy, tap.dx - o.dx);
    }
    if (t > next) {
      dr = t;
      da = -2.3 + _rnd() * 1.4;
      next = t + 6 + _rnd() * 4;
    }
    final u = (t - dr) / 1.4;
    if (u >= 0 && u < 1) {
      // «бриллиантовое кольцо»
      final e = math.sin(math.pi * u), b = Offset(o.dx + math.cos(da) * r, o.dy + math.sin(da) * r);
      _glow(c, b, r * 0.7, _white, e, mode);
      final sp = _stroke(_op(_white, e), 1.4);
      c.drawLine(b - Offset(r * 1.8 * e, 0), b + Offset(r * 1.8 * e, 0), sp);
      c.drawLine(b - Offset(0, r * 0.9 * e), b + Offset(0, r * 0.9 * e), sp);
    }
    c.drawCircle(o, r, _fill(const Color(0xFF050508)));
  }
}

// ───────────── Чёрная дыра ─────────────
class _BlackHole extends CoverSim {
  late List<List<double>> p, bg;
  double pull = 0;
  @override
  void init(Size s) {
    p = List.generate(1400, (_) => [ar * (1.2 + _pow(_rnd(), 1.8) * 2.6), _rnd() * _tau]);
    bg = List.generate(70, (_) => [_rnd(), _rnd(), _rnd()]);
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height, o = av, r = ar;
    c.drawRect(Offset.zero & s, _fill(_c(dark, 0xFF040308, 0xFFF1ECF8)));
    for (final q in bg) {
      final dx = q[0] * w - o.dx, dy = q[1] * h - o.dy, k = 1 + (r * r * 1.4) / (dx * dx + dy * dy + 1); // линзирование
      c.drawRect(Rect.fromLTWH(o.dx + dx * k, o.dy + dy * k, 1.2, 1.2), _fill(_op(_c(dark, 0xFFFFFFFF, 0xFF6A4CC8), 0.25 + 0.5 * math.max(0.0, math.sin(t + q[2] * 9)))));
    }
    if (tap != null) pull = 1.6;
    pull = math.max(0.0, pull - dt);
    const tilt = -0.18, bins = 6;
    final co = math.cos(tilt), si = math.sin(tilt), bk = List.generate(bins * 3, (_) => <double>[]);
    for (final q in p) {
      final qq = q[0] / r;
      q[1] += 1.5 / _pow(qq, 1.5) * dt; // внутри быстрее
      q[0] -= (pull > 0 ? 30 * _rnd() : 0.0) * dt + 2 * dt;
      if (q[0] < r * 1.05) {
        q[0] = r * (2.2 + _rnd() * 1.4);
        q[1] = _rnd() * _tau;
      }
      final x0 = math.cos(q[1]) * q[0], y0 = math.sin(q[1]) * q[0] * 0.24;
      final u = _clamp((qq - 1.2) / 2.4, 0, 1), dop = 0.65 + 0.35 * math.cos(q[1]); // доплеровская яркость
      final bi = _clamp((u * bins).floorToDouble(), 0, bins - 1).toInt() * 3 + _clamp(((dop - 0.3) / 0.7 * 3).floorToDouble(), 0, 2).toInt();
      bk[bi]
        ..add(o.dx + x0 * co - y0 * si)
        ..add(o.dy + x0 * si + y0 * co);
    }
    final mode = dark ? BlendMode.plus : BlendMode.srcOver;
    for (var i = 0; i < bk.length; i++) {
      if (bk[i].isEmpty) continue;
      final u = ((i ~/ 3) + 0.5) / bins, a = (0.45 + (i % 3) * 0.25) * (1 - u * 0.6) * (dark ? 0.9 : 0.7);
      final col = dark
          ? Color.fromARGB(255, 255, (240 - u * 150).round(), (210 - u * 190).round())
          : Color.fromARGB(255, (210 - u * 60).round(), (90 - u * 40).round(), (40 + u * 120).round());
      c.drawRawPoints(ui.PointMode.points, Float32List.fromList(bk[i]),
          Paint()
            ..color = _op(col, a)
            ..strokeWidth = 1.4
            ..blendMode = mode);
    }
    _glow(c, o, r * 1.9, _c(dark, 0xFFFFC88C, 0xFFDC6E3C), dark ? 0.9 : 0.7, mode);
    final ring = _c(dark, 0xFFFFE8C4, 0xFFF08040), ra = 0.85 + 0.15 * math.sin(t * 2);
    c.drawCircle(o, r * 1.07, _stroke(_op(ring, ra), 3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    c.drawCircle(o, r * 1.07, _stroke(_op(ring, ra), 2));
    c.drawCircle(o, r, _fill(Colors.black));
  }
}

// ───────────── Дорожка ─────────────
class _MoonPath extends CoverSim {
  late List<List<double>> st;
  final sw = <List<double>>[];
  @override
  void init(Size s) => st = List.generate(60, (_) => [_rnd(), _rnd() * 0.45, _rnd()]);
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height, o = av, r = ar, hy = o.dy + r * 1.7;
    c.drawRect(
        Rect.fromLTWH(0, 0, w, hy),
        Paint()
          ..shader = _linG(Offset.zero, Offset(0, hy),
              dark ? const [Color(0xFF070B22), Color(0xFF1D2150), Color(0xFF3A3468)] : const [Color(0xFF5B4FC4), Color(0xFFF2789A), Color(0xFFFFC46B)], dark ? const [0.0, 0.7, 1.0] : const [0.0, 0.55, 1.0]));
    if (dark) {
      for (final q in st) {
        c.drawRect(Rect.fromLTWH(q[0] * w, q[1] * h, 1.2, 1.2), _fill(_op(_white, 0.2 + 0.6 * math.max(0.0, math.sin(t * 1.2 + q[2] * 9)))));
      }
    }
    _glow(c, o, r * 4, _c(dark, 0xFFDCE6FF, 0xFFFFE6A0), dark ? 0.5 : 0.8);
    c.drawRect(Rect.fromLTWH(0, hy, w, h - hy),
        Paint()..shader = _linG(Offset(0, hy), Offset(0, h), dark ? const [Color(0xFF141A40), Color(0xFF05071A)] : const [Color(0xFF8A4E9E), Color(0xFF2C2466)]));
    final wl = _stroke(dark ? const Color(0x0DFFFFFF) : const Color(0x14FFFFFF), 1);
    for (var y = hy + 4; y < h; y += 7) {
      final path = Path();
      for (double x = 0; x <= w; x += 10) {
        final yy = y + math.sin(x * 0.04 + t * 1.2 + y) * 1.2;
        x == 0 ? path.moveTo(x, yy) : path.lineTo(x, yy);
      }
      c.drawPath(path, wl);
    }
    if (tap != null && tap.dy > hy) sw.add([tap.dx, tap.dy, t]);
    sw.removeWhere((q) => t - q[2] >= 2);
    final tq = (t * 7).floor(), gc = _c(dark, 0xFFE6ECFF, 0xFFFFE3A0);
    var row = 0;
    for (var y = hy + 2; y < h; y += 3.2, row++) {
      final f = (y - hy) / (h - hy), ww = r * (0.5 + f * 2.2);
      var boost = 0.0;
      for (final q in sw) {
        final a = t - q[2], d = (y - q[1]).abs();
        boost += math.exp(-d * d / 200) * math.max(0.0, 1 - a / 2);
      }
      for (var k = 0; k < 6; k++) {
        final h1 = _hash(row, k, tq), x = o.dx + (_hash(row, k) - 0.5) * 2 * ww + math.sin(t * 1.5 + row) * 3, l = 3 + h1 * (8 + f * 16);
        final a = math.min(1.0, (h1 > 0.45 ? h1 : 0.1) * (1 - f * 0.4) + boost * 0.4);
        c.drawRect(Rect.fromLTWH(x - l / 2, y, l, 1.4), _fill(_op(gc, a)));
      }
    }
    c.drawCircle(o, r, _fill(_c(dark, 0xFFEEF2FF, 0xFFFFF4D6)));
  }
}

// ───────────── Круги на воде ─────────────
class _Ripples extends CoverSim {
  final rings = <List<double>>[];
  late List<List<double>> lv;
  double next = 0;
  @override
  void init(Size s) => lv = List.generate(5, (_) => [_rnd() * s.width, s.height * (0.55 + _rnd() * 0.4), _rnd() * 6, 0.8 + _rnd() * 0.5]);
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    _vFill(c, s, _c(dark, 0xFF04161C, 0xFFCFEDEA), _c(dark, 0xFF082A31, 0xFFEAF7F4));
    for (var i = 0; i < 6; i++) {
      _glow(c, Offset((0.5 + 0.45 * math.sin(t * 0.13 + i * 2)) * w, (0.5 + 0.45 * math.cos(t * 0.11 + i * 1.3)) * h), 90, _c(dark, 0xFF78E6DC, 0xFFFFFFFF), dark ? 0.07 : 0.2);
    }
    if (t > next) {
      rings.add([av.dx, av.dy, ar, t]); // от фото, как от камня
      next = t + 1.5;
    }
    if (tap != null) {
      for (var k = 0; k < 3; k++) {
        rings.add([tap.dx, tap.dy, 2, t + k * 0.22]);
      }
    }
    rings.removeWhere((q) => t - q[3] >= 7);
    for (final q in rings) {
      final a = t - q[3];
      if (a < 0) continue;
      final rr = q[2] + a * 34, e = math.exp(-a * 0.45) * (q[2] > 3 ? 1.0 : 0.8);
      c.drawCircle(Offset(q[0], q[1]), rr, _stroke(_op(_c(dark, 0xFF9FF2E8, 0xFFFFFFFF), e * (dark ? 0.5 : 0.7)), 2));
      c.drawCircle(Offset(q[0], q[1]), rr + 5, _stroke(_op(_c(dark, 0xFF021014, 0xFF3F8C88), e * (dark ? 0.35 : 0.22)), 2.5));
    }
    for (final l in lv) {
      var bob = 0.0;
      for (final q in rings) {
        final a = t - q[3];
        if (a < 0) continue;
        final d = (Offset(l[0], l[1]) - Offset(q[0], q[1])).distance - (q[2] + a * 34);
        bob += math.exp(-d * d / 60) * math.exp(-a * 0.45);
      }
      l[0] += math.sin(t * 0.2 + l[2]) * 3 * dt;
      l[2] += dt * 0.08;
      c.save();
      c.translate(l[0], l[1] - bob * 2.5);
      c.rotate(l[2] + bob * 0.3);
      c.scale(l[3] * (1 + bob * 0.08), l[3]);
      c.drawOval(_ov(0, 0, 9, 4.2), _fill(_c(dark, 0xFF3FA86A, 0xFF6FBF73)));
      c.drawLine(const Offset(-8, 0), const Offset(8, 0), _stroke(_c(dark, 0xFF2A7A4B, 0xFF4C9A52), 1));
      c.restore();
    }
  }
}

// ───────────── Прожектор ─────────────
class _Spotlight extends CoverSim {
  int gel = 0;
  Color cur = const Color(0xFFFFE2AA);
  late List<List<double>> dust;
  static const _gels = [Color(0xFFFFE2AA), Color(0xFFFF78BE), Color(0xFF78D2FF), Color(0xFFB496FF)];
  @override
  void init(Size s) => dust = List.generate(90, (_) => [_rnd(), _rnd(), _rnd(), _rnd() * 6]);
  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final h = s.height, o = av, r = ar;
    if (tap != null) gel++;
    cur = Color.lerp(cur, _gels[gel % 4], math.min(1.0, dt * 3))!;
    final fl = 0.94 + 0.06 * math.sin(t * 13) * math.sin(t * 7.3); // мерцание лампы
    _vFill(c, s, _c(dark, 0xFF050507, 0xFFCFC7BC), _c(dark, 0xFF0E0D12, 0xFFDCD5CB));
    final fy = h * 0.9, w0 = s.width * 0.035, w1 = r * 1.9;
    final beam = Path()
      ..moveTo(o.dx - w0, 0)
      ..lineTo(o.dx + w0, 0)
      ..lineTo(o.dx + w1, fy)
      ..lineTo(o.dx - w1, fy)
      ..close();
    c.drawPath(beam, Paint()..shader = _linG(Offset.zero, Offset(0, fy), [_op(cur, (dark ? 0.4 : 0.55) * fl), _op(cur, (dark ? 0.1 : 0.2) * fl)]));
    c.save();
    c.translate(o.dx, fy);
    c.scale(1, (r * 0.5) / (w1 * 1.3));
    _glow(c, Offset.zero, w1 * 1.3, cur, 0.9 * fl);
    c.restore();
    _glow(c, o, r * 2.2, cur, (dark ? 0.55 : 0.75) * fl);
    c.save();
    c.clipPath(beam);
    for (final q in dust) {
      q[1] -= dt * 0.012 * (0.5 + q[2]);
      q[0] += math.sin(t * 0.5 + q[3]) * dt * 0.01;
      if (q[1] < 0) q[1] = 1;
      final y = q[1] * fy, hw = w0 + (w1 - w0) * (y / fy), x = o.dx + (q[0] - 0.5) * 2 * hw;
      c.drawCircle(Offset(x, y), 0.6 + q[2] * 1.2, _fill(_op(dark ? cur : _white, (0.25 + 0.6 * math.max(0.0, math.sin(t * 1.5 + q[3]))) * fl)));
    }
    c.restore();
    c.drawCircle(o, r, _fill(_c(dark, 0xFF1A1820, 0xFF8C8478)));
  }
}
