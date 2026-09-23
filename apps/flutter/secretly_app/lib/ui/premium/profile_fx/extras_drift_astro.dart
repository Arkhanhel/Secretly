// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../profile_fx.dart';

// 🔴 «Дрифт» и «Космонавт» пришли ОТДЕЛЬНЫМ набором со своей библиотекой:
// там свой `FrameSim`, своя палитра `FrameTheme` и свои помощники. Держать в
// приложении две почти одинаковые библиотеки значило бы дважды платить за одно
// и то же и ждать, когда они разойдутся. Поэтому сюда перенесены только
// симуляции, а устройство — общее с остальными двадцатью четырьмя.
//
// Что при переносе изменено, и только это:
//   * `FrameTheme` → `FramePalette`; недостающие цвета добавлены расширением
//     ниже — их ровно два;
//   * вызовы `gap()` убраны: непрозрачный круг под фото закрыл бы лицо, у нас
//     вместо него ободок кольцевой полоской, и рисует его общий слой;
//   * имена приведены к нашим, чтобы не столкнуться с уже занятыми.

/// Скруглённый прямоугольник с заливкой и обводкой — единственный помощник
/// набора, которого нет в общей части.
void _rrFS(Canvas c, RRect r, Color fill, Color stroke, double w) {
  c.drawRRect(r, _fill(fill));
  c.drawRRect(r, _stroke(stroke, w));
}


/// Два цвета, которых нет в палитре набора: след шин и трос.
extension _DriftAstroInk on FramePalette {
  /// Дым из-под колёс. В общей палитре `smoke` есть у обложек, но не у рамок.
  Color get smoke =>
      dark ? const Color(0xFF50535F) : const Color(0xFFC9CCD6);
  Color get skid => dark ? const Color(0xFF050507) : const Color(0xFF2A2D3A);
  Color get rope => dark ? const Color(0xFFC9CCD6) : const Color(0xFF8A8E99);
}

/// Клубы дыма из-под колёс.
class _DriftPuff {
  double x = 0, y = 0, vx = 0, vy = 0, age = 9;
}

class DriftFrame extends FrameSim {
  DriftFrame() : super(100, 100, 58, 52);

  double a = 0, np = 0, nf = 2.5, _flame = 0, _tl = 1;
  int pi = 0;
  final v = Spring(1.25), da = Spring(34);
  final trail = [<Offset>[], <Offset>[]];
  final puffs = List<_DriftPuff>.generate(24, (_) => _DriftPuff());
  Offset _pos = Offset.zero;
  double _ang = 0;

  static const _bodyGrad = [Color(0xFFFF6076), Color(0xFFF0263F), Color(0xFFB8142E)];

  @override
  void update(double dt) {
    if (edge()) {
      v.v += 3;
      da.v += 70;
    }
    v.t = active ? 2.6 : 1.25 + math.sin(t * 0.7) * 0.12;
    v.step(dt, 8, 4); // мягкий разгон, как с инерцией
    if (t > nf) {
      da.v -= 170; // «перекладка» из заноса в занос
      nf = t + 2.5 + _rnd() * 3;
    }
    da.t = (active ? 44 : 32) + math.sin(t * 1.3) * 4;
    da.step(dt, 40, 6);
    a += v.x * dt;
    final r = R + 18 + math.sin(a * 2) * 2.5;
    _pos = _pt(cx, cy, r, a);
    _ang = a * 57.3 + da.x; // касательная + угол заноса
    final rad = _ang * _deg, co = math.cos(rad), si = math.sin(rad);
    Offset wheel(double s) => Offset(_pos.dx - 13.5 * co - s * 10.2 * si, _pos.dy - 13.5 * si + s * 10.2 * co);
    for (var wi = 0; wi < 2; wi++) {
      final tr = trail[wi]..add(wheel(wi == 0 ? -1 : 1));
      if (tr.length > 84) tr.removeAt(0);
    }
    if (t > np) {
      for (final s in const [-1.0, 1.0]) {
        final w = wheel(s);
        puffs[pi++ % puffs.length]
          ..x = w.dx
          ..y = w.dy
          ..age = 0
          ..vx = (_rnd() - 0.5) * 12 - co * 14 - s * si * 8
          ..vy = (_rnd() - 0.5) * 12 - si * 14 + s * co * 8;
      }
      np = t + (active ? 0.03 : 0.055);
    }
    for (final p in puffs) {
      p.age += dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 1 - dt * 2.2;
      p.vy *= 1 - dt * 2.2;
    }
    _flame = active ? 9 + math.sin(t * 40) * 2.5 + math.sin(t * 23) * 1.5 : 0.0;
    _tl = 0.75 + 0.25 * math.sin(t * 9);
    body(1, 1, active ? math.sin(t * 50) * 0.4 : 0.0);
  }

  @override
  void back(Canvas c, FramePalette p) {
    // следы шин: 6 отрезков с растущей прозрачностью
    for (final tr in trail) {
      final n = tr.length;
      if (n < 2) continue;
      final per = (n / 6).ceil();
      for (var k = 0; k < 6; k++) {
        final s = k * per, e = math.min(n, (k + 1) * per + 1);
        if (e - s < 2) continue;
        final path = Path()..moveTo(tr[s].dx, tr[s].dy);
        for (var i = s + 1; i < e; i++) {
          path.lineTo(tr[i].dx, tr[i].dy);
        }
        c.drawPath(path, _stroke(_op(p.skid, (k + 1) / 6 * 0.5), 2.6));
      }
    }
    for (final puff in puffs) {
      final u = puff.age / 0.95;
      if (u >= 1) continue;
      c.drawCircle(
        Offset(puff.x, puff.y),
        2.4 + math.sqrt(math.max(0, u)) * 13,
        _fill(_op(p.smoke, 0.45 * (1 - u))),
      );
    }
    withBody(c, () {
      final o = Offset(cx, cy), rect = Rect.fromCircle(center: o, radius: R);
      c.drawCircle(o, R, _stroke(const Color(0xFFFF3D5A), 7, StrokeCap.butt));
      final kerb = _stroke(Colors.white, 7, StrokeCap.butt);
      for (var k = 0; k < 24; k++) {
        c.drawArc(rect, k * _tau / 24, _tau / 48, false, kerb); // кербы
      }
    });
  }

  @override
  void front(Canvas c, FramePalette p) {
    c.save();
    c.translate(_pos.dx, _pos.dy);
    c.rotate(_ang * _deg);
    c.scale(1.35);
    c.drawPath(
        Path()
          ..moveTo(15, -6)
          ..lineTo(44, -15)
          ..lineTo(44, 15)
          ..lineTo(15, 6)
          ..close(),
        Paint()..shader = ui.Gradient.linear(const Offset(15, 0), const Offset(44, 0), const [Color(0x59FFF3B0), Color(0x00FFF3B0)]));
    final l = _flame;
    if (l > 0.5) {
      c.drawPath(
          Path()
            ..moveTo(-17, -2.4)
            ..quadraticBezierTo(-17 - l * 0.6, -3, -17 - l, 0)
            ..quadraticBezierTo(-17 - l * 0.6, 3, -17, 2.4)
            ..close(),
          _fill(const Color(0xFF5AB8FF)));
      c.drawPath(
          Path()
            ..moveTo(-17, -1.1)
            ..quadraticBezierTo(-17 - l * 0.35, -1.3, -17 - l * 0.55, 0)
            ..quadraticBezierTo(-17 - l * 0.35, 1.3, -17, 1.1)
            ..close(),
          _fill(Colors.white));
    }
    const tire = Color(0xFF15161B);
    for (final y in const [-7.6, 7.6]) {
      c.drawRRect(_rr(-9.5 - 3.6, y - 1.9, 7.2, 3.8, 1.3), _fill(tire));
      c.save();
      c.translate(9, y);
      c.rotate(-da.x * 0.55 * _deg); // контрруль
      c.drawRRect(_rr(-3.6, -1.9, 7.2, 3.8, 1.3), _fill(tire));
      c.restore();
    }
    c.drawRRect(_rr(-14, -6, 31, 16, 5), _fill(const Color(0x38000000)));
    final bodyR = _rr(-15.5, -7.6, 31, 15.2, 5.2);
    c.drawRRect(bodyR, Paint()..shader = ui.Gradient.linear(const Offset(0, -7.6), const Offset(0, 7.6), _bodyGrad, const [0, 0.5, 1]));
    c.drawRRect(bodyR, _stroke(const Color(0xFF7A0F22), 1));
    final stripe = _fill(const Color(0xEBFFFFFF));
    c.drawRRect(_rr(-14.5, -2.4, 29, 1.7, 0.8), stripe);
    c.drawRRect(_rr(-14.5, 0.7, 29, 1.7, 0.8), stripe);
    c.drawRRect(_rr(-7.5, -6.2, 13.5, 12.4, 3.6), _fill(const Color(0xFF1B1D27)));
    c.drawRRect(_rr(2.6, -5.3, 2.6, 10.6, 1.1), _fill(const Color(0xBF7DB4FF)));
    c.drawRRect(_rr(-6.8, -5, 1.8, 10, 0.9), _fill(const Color(0xFF4A5570)));
    c.drawRRect(_rr(-18, -7.2, 3.2, 14.4, 1.2), _fill(const Color(0xFF1B1D27)));
    for (final y in const [-6.4, 3.4]) {
      c.drawRRect(_rr(13.2, y, 2.6, 3, 1), _fill(const Color(0xFFFFF3B0)));
      c.drawRRect(_rr(-15.8, y, 1.9, 3, 0.8), _fill(_op(const Color(0xFFFF2D2D), _tl)));
    }
    c.restore();
  }
}

/// Узел троса.
class _RopeNode {
  _RopeNode(this.x, this.y)
      : ox = x,
        oy = y;
  double x, y, ox, oy;
}

class AstronautFrame extends FrameSim {
  AstronautFrame() : super(100, 104, 60, 54);

  static const _n = 14, _len = 80.0;
  static const _k = Color(0xFF2A2D3A), _w = Colors.white;
  static const _stars = [Offset(24, 30), Offset(40, 172), Offset(178, 170), Offset(186, 104), Offset(62, 14)];
  final px = Spring(168), py = Spring(40), spin = Spring();
  List<_RopeNode>? rope; // ignore: library_private_types_in_public_api
  double rot = 0;

  Offset get _anchor => _pt(cx, cy, R + 3, 0.62);

  @override
  void update(double dt) {
    final a = _anchor;
    if (edge()) {
      px.v += (a.dx - px.x) * 4.2; // рывок к точке крепления
      py.v += (a.dy - py.x) * 4.2;
      spin.v += 460;
    }
    final tg = _pt(cx, cy, R + 44 + math.sin(t * 0.5) * 5, 0.72 + math.sin(t * 0.27) * 0.35);
    px.t = tg.dx;
    py.t = tg.dy;
    px.step(dt, 6, 2.2); // невесомость: очень мягкая пружина
    py.step(dt, 6, 2.2);
    final dx = px.x - a.dx, dy = py.x - a.dy, d = math.sqrt(dx * dx + dy * dy);
    if (d > _len - 4) {
      px
        ..x = a.dx + dx / d * (_len - 4)
        ..v *= 0.4;
      py
        ..x = a.dy + dy / d * (_len - 4)
        ..v *= 0.4;
    }
    spin.t = 0;
    spin.step(dt, 4, 1.6);
    rot = math.sin(t * 0.4) * 18 + spin.x;
    final rr = rot * _deg, bx = px.x - 7.8 * math.sin(rr), by = py.x + 7.8 * math.cos(rr);
    final r = rope ??= List.generate(_n, (i) {
      final u = i / (_n - 1);
      return _RopeNode(_lerp(a.dx, bx, u), _lerp(a.dy, by, u));
    });
    // Verlet-верёвка
    for (var i = 1; i < _n - 1; i++) {
      final p = r[i], vx = (p.x - p.ox) * 0.985, vy = (p.y - p.oy) * 0.985;
      p
        ..ox = p.x
        ..oy = p.y
        ..x += vx + math.sin(t * 1.3 + i) * 0.02
        ..y += vy + 0.004;
    }
    const seg = _len / (_n - 1);
    for (var it = 0; it < 8; it++) {
      r[0]
        ..x = a.dx
        ..y = a.dy;
      r[_n - 1]
        ..x = bx
        ..y = by;
      for (var i = 0; i < _n - 1; i++) {
        final p = r[i], q = r[i + 1], ex = q.x - p.x, ey = q.y - p.y, dd = math.sqrt(ex * ex + ey * ey);
        if (dd <= seg || dd == 0) continue; // сопротивляется только растяжению → провисает
        final k = (dd - seg) / dd * 0.5;
        if (i > 0) {
          p.x += ex * k;
          p.y += ey * k;
        }
        if (i + 1 < _n - 1) {
          q.x -= ex * k;
          q.y -= ey * k;
        }
      }
    }
    final br = math.sin(t * 1.4) * 0.006;
    body(1 + br, 1 - br);
  }

  @override
  void back(Canvas c, FramePalette p) {
    for (var i = 0; i < _stars.length; i++) {
      c.drawCircle(_stars[i], 1.7, _fill(_op(p.ink, 0.15 + 0.85 * math.pow(math.max(0.0, math.sin(t * (1.2 + i * 0.3) + i * 1.9)), 2).toDouble())));
    }
    withBody(c, () {
      c.drawPath(
          _blob(cx, cy, R, (x) => 0.9 * math.sin(3 * x + t * 1.6) + 0.6 * math.sin(5 * x - t * 2.3)),
          _stroke(Colors.white, 7, StrokeCap.butt)
            ..shader = ui.Gradient.linear(Offset(cx - R, cy - R), Offset(cx + R, cy + R), const [Color(0xFFB69CFF), Color(0xFF5A6BE0), Color(0xFF1FB5A8)], const [0, 0.5, 1]));
    });
  }

  @override
  void front(Canvas c, FramePalette p) {
    final r = rope;
    if (r != null) c.drawPath(_smoothOpen([for (final p in r) Offset(p.x, p.y)]), _stroke(p.rope, 2));
    final a = _anchor;
    c.drawCircle(a, 2.6, _fill(const Color(0xFFC9CCD6)));
    c.drawCircle(a, 2.6, _stroke(_k, 1.2));

    c.save();
    c.translate(px.x, py.x);
    c.rotate(rot * _deg);
    c.scale(1.3);
    _rrFS(c, _rr(-10, -7, 20, 16, 5), const Color(0xFFD5D9E3), _k, 1.5); // ранец
    void limb(double px0, double py0, double ang, VoidCallback draw) {
      c.save();
      c.translate(px0, py0);
      c.rotate(ang * _deg);
      c.translate(-px0, -py0);
      draw();
      c.restore();
    }

    limb(-4, 7, math.sin(t * 0.8) * 10, () {
      _rrFS(c, _rr(-7.5, 6, 6.5, 11, 3.2), _w, _k, 1.5);
      _rrFS(c, _rr(-7.5, 14.5, 6.5, 3.8, 1.6), const Color(0xFF8A8E99), _k, 1.5);
    });
    limb(4, 7, -math.sin(t * 0.8 + 0.6) * 10, () {
      _rrFS(c, _rr(1, 6, 6.5, 11, 3.2), _w, _k, 1.5);
      _rrFS(c, _rr(1, 14.5, 6.5, 3.8, 1.6), const Color(0xFF8A8E99), _k, 1.5);
    });
    _rrFS(c, _rr(-8.5, -5, 17, 15, 6), _w, _k, 1.5);
    _rrFS(c, _rr(-4, 0, 8, 5, 1.5), const Color(0xFFE9ECF3), _k, 1);
    c.drawCircle(const Offset(-1.8, 2.5), 1, _fill(const Color(0xFFFF5F6D)));
    c.drawCircle(const Offset(1.8, 2.5), 1, _fill(const Color(0xFF3DD6FF)));
    for (final s in const [-1.0, 1.0]) {
      limb(10 * s, -3, s < 0 ? math.sin(t * 1.1) * 18 : -math.sin(t * 0.9 + 1) * 24, () {
        _rrFS(c, _rr(s < 0 ? -14.5 : 8.5, -4, 6, 11, 3), _w, _k, 1.5);
        final g = Offset(11.5 * s, 7.6);
        c.drawCircle(g, 2.7, _fill(const Color(0xFFFF9F43)));
        c.drawCircle(g, 2.7, _stroke(_k, 1.5));
      });
    }
    c.drawLine(const Offset(6, -20), const Offset(8.5, -25.5), _stroke(_k, 1.5));
    c.drawCircle(const Offset(8.5, -25.5), 1.7, _fill(_op(const Color(0xFFFF5F6D), (t % 1.4) < 0.3 ? 1.0 : 0.35)));
    c.drawCircle(const Offset(0, -12), 10, _fill(_w));
    c.drawCircle(const Offset(0, -12), 10, _stroke(_k, 1.5));
    final visor = Rect.fromCenter(center: const Offset(1, -12), width: 14, height: 11.2);
    c.drawOval(visor,
        Paint()..shader = ui.Gradient.linear(visor.topLeft, Offset(visor.left + visor.width * 0.4, visor.bottom), const [Color(0xFF3A4BB0), Color(0xFF1B2250), Color(0xFF7A5CFF)], const [0, 0.6, 1]));
    c.save();
    c.translate(-1.8, -14.2);
    c.rotate(-18 * _deg);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 5.6, height: 2.6), _fill(const Color(0xBFFFFFFF)));
    c.restore();
    c.drawCircle(const Offset(4.5, -9.6), 0.9, _fill(const Color(0xCCFFFFFF)));
    c.restore();
  }
}
