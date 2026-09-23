// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../profile_fx.dart';

// 🔴 НАШИ персонажи внутри библиотеки набора.
//
// Второй — после `bridge.dart` — файл, написанный не генератором. Он здесь по
// той же причине: помощники набора (`_blob`, `_pt`, `_stroke`, `_linG`)
// закрыты, а выносить их наружу ради двух рамок значило бы раздуть открытую
// часть. Сами файлы выгрузки при этом остаются нетронутыми, и следующая
// выгрузка их спокойно заменит.

/// «Слайм», переписанный под настоящее стекание.
///
/// 🔴 ЧЕМ ОТЛИЧАЕТСЯ ОТ НАБОРНОГО. Там кольцо ровной толщины, а капли просто
/// висят в трёх заданных точках и падают по очереди. Здесь у кольца есть
/// МАССА: она набирается сверху, сползает по бокам вниз — быстрее там, где
/// круче, — скапливается внизу и уже оттуда срывается каплей. Поэтому кольцо
/// живое: сверху тоньше, книзу толще, и толщина ходит волной.
///
/// Течение считается по кольцу из 48 ячеек. Это не украшение формулой:
/// скорость берётся от крутизны (|sin| угла), поэтому на самом верху и на
/// самом низу масса стоит, а по бокам бежит — ровно так ведёт себя тягучая
/// капля на стекле.
class SlimeFrame extends FrameSim {
  SlimeFrame()
    : super(100, 94, 62, 55, const [
        Color(0xFFC4F56B),
        Color(0xFF4FD68A),
        Color(0xFF1FB5A8),
      ]) {
    ringWidth = 10;
  }

  static const Color _g = Color(0xFF4FD68A);
  static const int _n = 48;

  /// Масса в ячейках кольца, 0 — сверху, дальше по часовой стрелке.
  final List<double> _m = List<double>.filled(_n, 0.6);
  final List<double> _tmp = List<double>.filled(_n, 0);

  /// Желе: общий толчок при нажатии, затухает медленно.
  final Spring _jelly = Spring();

  final List<_SlimeDrop> _drops = <_SlimeDrop>[];
  double _nextDrop = 0.9;

  @override
  Path ringPath() => _blob(
    cx,
    cy,
    R,
    (a) =>
        1.1 * math.sin(3 * a + t * 1.4) +
        0.7 * math.sin(5 * a - t * 2) +
        _jelly.x * 5 * math.sin(3 * a + 1),
  );

  double _massAt(double a) {
    final u = (a % (math.pi * 2)) / (math.pi * 2) * _n;
    final i = u.floor() % _n;
    final f = u - u.floorToDouble();
    return _m[i] * (1 - f) + _m[(i + 1) % _n] * f;
  }

  /// Толщина кольца в точке — от массы. Клампы не вкусовые: тоньше 5 линия
  /// рвётся на маленьком портрете, толще 22 кольцо перестаёт быть кольцом.
  double _widthAt(double a) => (5.0 + _massAt(a) * 5).clamp(4.5, 12.5);

  /// 🔴 Куда растёт лента — не вкус, а два жёстких края.
  ///
  /// Внутрь нельзя дальше `av`: там начинается фотография, и слайм ушёл бы под
  /// неё, а между ними встал бы тёмный ободок — видно было бы кольцо грязи, а
  /// не каплю. Наружу нельзя дальше габарита рамки: кольцо и так проходит
  /// почти по стороне квадрата.
  ///
  /// При R = 62, av = 55 и толщине до 12.5 оба края сходятся: 0.6 наружу даёт
  /// внешний 71.5 (в габарите) и внутренний ровно 55 — впритык к фотографии,
  /// ни пикселя под неё.
  static const double _outward = 0.6;

  @override
  void update(double dt) {
    if (edge() && active) _jelly.v += 11;
    _jelly.step(dt, 110, 4.5); // желе: низкое затухание
    final sx = 1 - _jelly.x * 0.035, sy = 1 + _jelly.x * 0.035;
    body(sx, sy);

    final speed = (active ? 2.6 : 1.0) * dt;
    // 1) Приток сверху. Слайм не берётся ниоткуда: он «намокает» у верхушки,
    //    поэтому и кажется, что стекает именно оттуда.
    for (var i = 0; i < _n; i++) {
      final a = i / _n * math.pi * 2;
      _m[i] += (0.5 + 0.5 * math.cos(a)) * 0.9 * speed;
    }
    // 2) Течение вниз. Крутизна — |sin(a)|: наверху и внизу склона нет, и
    //    масса там стоит, как настоящая капля на стекле.
    for (var i = 0; i < _n; i++) {
      _tmp[i] = 0;
    }
    for (var i = 0; i < _n; i++) {
      final a = i / _n * math.pi * 2;
      final down = math.sin(a) >= 0 ? 1 : -1; // куда «ниже» по кольцу
      final flow = (_m[i] * math.sin(a).abs() * 2.6 * speed).clamp(0.0, _m[i]);
      _tmp[i] -= flow;
      _tmp[(i + down + _n) % _n] += flow;
    }
    var bottom = 0.0;
    for (var i = 0; i < _n; i++) {
      _m[i] = (_m[i] + _tmp[i]).clamp(0.0, 3.2);
      final a = i / _n * math.pi * 2;
      if (math.cos(a) < -0.55) bottom += _m[i];
    }

    // 3) Срыв капли. Отрывается не по таймеру, а когда внизу накопилось: пока
    //    масса не набралась, капли просто нет, и это видно.
    _nextDrop -= dt;
    if (bottom > 9 && _nextDrop <= 0) {
      final k = _n ~/ 2 + (_rnd() * 7).round() - 3;
      final a = (k % _n) / _n * math.pi * 2;
      final p = _pt(cx, cy, R + 2, a);
      _drops.add(_SlimeDrop(cx + (p.dx - cx) * sx, cy + (p.dy - cy) * sy));
      for (var d = -2; d <= 2; d++) {
        _m[(k + d + _n) % _n] = math.max(0, _m[(k + d + _n) % _n] - 0.9);
      }
      _nextDrop = (active ? 0.22 : 0.9) + _rnd() * (active ? 0.4 : 1.6);
    }

    for (final d in _drops) {
      d.step(dt, active);
    }
    _drops.removeWhere((d) => d.dead);
  }

  @override
  void back(Canvas c, FramePalette p) {
    for (final d in _drops) {
      d.paint(c);
    }
  }

  @override
  void paintRing(Canvas c, [List<Color>? colors, double opacity = 1]) {
    // 🔴 Кольцо рисуется ЛЕНТОЙ между двумя радиусами, а не линией заданной
    // толщины: обводка одной ширины по всему кругу не умеет быть тоньше
    // сверху и толще снизу, а в этом вся затея.
    final path = Path();
    // 🔴 Края ЗАЖАТЫ жёстко, а не «подобраны с запасом». Волна на кольце и
    // желе при нажатии добавляют к радиусу до трёх единиц, и начальная фаза у
    // каждой рамки СЛУЧАЙНАЯ — без потолка лента иногда вылезала за габарит, а
    // иногда нет, и проверка падала через раз. Потолок 1.25·av, а не ровно
    // сторона квадрата (1.30): у сглаживания есть своя ширина, и впритык к
    // границе оно выплёскивает несколько точек наружу. Внутрь — не ближе
    // самой фотографии.
    final maxOut = av * 1.25, minIn = av;
    Offset at(double a, double sign) {
      final w = _widthAt(a) * (sign > 0 ? _outward : 1 - _outward);
      final wob =
          1.1 * math.sin(3 * a + t * 1.4) +
          0.7 * math.sin(5 * a - t * 2) +
          _jelly.x * 5 * math.sin(3 * a + 1);
      final r = R + wob + sign * w;
      return _pt(cx, cy, sign > 0 ? math.min(r, maxOut) : math.max(r, minIn), a);
    }

    for (var i = 0; i <= _n; i++) {
      final a = i / _n * math.pi * 2;
      final o = at(a, 1);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    for (var i = _n; i >= 0; i--) {
      final a = i / _n * math.pi * 2;
      final o = at(a, -1);
      path.lineTo(o.dx, o.dy);
    }
    path.close();
    c.drawPath(
      path,
      _fill(Colors.white)
        ..shader = _linG(
          Offset(cx - R, cy - R),
          Offset(cx + R, cy + R),
          colors ?? ringColors,
        ),
    );
  }

  @override
  void front(Canvas c, FramePalette p) => withBody(c, () {
    // Блик — он же подсказка, где кольцо тоньше.
    c.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: R),
      -1.2 - math.pi / 2,
      0.65,
      false,
      _stroke(const Color(0x99FFFFFF), 3),
    );
  });
}

/// Одна капля: тянется шеей, отрывается, падает, расплющивается.
class _SlimeDrop {
  _SlimeDrop(this.bx, this.by);

  final double bx, by;

  /// 0 — тянется, 1 — падает, 2 — шлёпнулась.
  int ph = 0;
  double len = 0, y = 0, v = 0, splash = 0;
  final Spring neck = Spring();
  bool dead = false;

  void step(double dt, bool active) {
    switch (ph) {
      case 0:
        // Шея тянется с замедлением: чем длиннее, тем труднее.
        len += dt * (active ? 26 : 13) * (1 - len / 30);
        if (len >= 17) {
          ph = 1;
          y = by + len;
          v = 0;
          neck
            ..x = len
            ..v = 0
            ..t = 0;
        }
      case 1:
        neck.step(dt, 220, 7); // отпущенная шея пружинит обратно
        v += 560 * dt;
        y += v * dt;
        if (y >= 190) {
          ph = 2;
          splash = 0;
        }
      default:
        neck.step(dt, 220, 7);
        splash += dt;
        if (splash > 0.6) dead = true;
    }
  }

  void paint(Canvas c) {
    final g = SlimeFrame._g;
    final ls = ph == 0 ? len : math.max(0.0, neck.x);
    final neg = ph >= 1 ? math.min(0.0, neck.x) : 0.0;
    if (ls > 0.4 || neg < -0.3) {
      c.drawLine(
        Offset(bx, by - 3),
        Offset(bx, by + ls),
        _stroke(g, math.max(3.0, 9 - ls * 0.28 + neg)),
      );
    }
    final br = ph == 0 ? 3.5 + ls * 0.13 : math.max(0.0, ls * 0.18);
    if (br > 0) c.drawCircle(Offset(bx, by + ls), br, _fill(g));
    if (ph == 1) {
      // Падая, капля вытягивается — это и читается как скорость.
      c.drawOval(
        _ov(bx, y, 5.8 - math.min(1.5, v * 0.004), 6 + math.min(4.0, v * 0.008)),
        _fill(g),
      );
    }
    if (ph == 2) {
      final u = splash / 0.6;
      c.drawOval(
        _ov(bx, 192, 6 + math.sqrt(u) * 11, math.max(0.6, 3.2 - u * 3)),
        _fill(_op(g, 1 - u)),
      );
    }
  }
}

/// «Не беспокоить» с полумесяцем, который не пачкает обложку.
///
/// 🔴 ЧТО БЫЛО НЕ ТАК. В наборе полумесяц получается так: жёлтый круг, а
/// поверх него круг ЦВЕТОМ ФОНА. На своём фоне это незаметно, но обложка —
/// чужая картинка, и на светлой сцене поверх луны ложилась тёмная клякса.
/// Здесь та же луна вырезана по контуру: `Path.combine`, никакой заливки
/// фоном — под вырезом видно обложку.
class SleepFrame extends FrameSim {
  SleepFrame()
    : super(98, 108, 60, 54, const [
        Color(0xFFB69CFF),
        Color(0xFF7654DB),
        Color(0xFF2A3A9A),
      ]);

  double _alarm = 0;
  final Spring _shake = Spring(), _zzz = Spring(1), _mark = Spring();

  @override
  void update(double dt) {
    if (edge() && active) {
      _alarm = 2.2;
      _shake.v += 500;
      _mark
        ..x = 0
        ..v = 0;
    }
    _alarm -= dt;
    final awake = _alarm > 0;
    if (_alarm > 1.3) _shake.v += math.sin(t * 70) * 60; // будильник звенит
    _zzz.t = awake ? 0.0 : 1.0;
    _mark.t = awake ? 1.0 : 0.0;
    _shake.step(dt, 250, 6);
    _zzz.step(dt, 60, 10);
    _mark.step(dt, 200, 10);
    final br = math.sin(t * 1.1) * 0.012 * _clamp(_zzz.x, 0, 1);
    body(1 + br, 1 + br, _shake.x * 0.3);
  }

  @override
  void back(Canvas c, FramePalette p) {
    const st = [
      Offset(26, 34),
      Offset(168, 150),
      Offset(22, 170),
      Offset(70, 22),
    ];
    for (var i = 0; i < 4; i++) {
      c.drawCircle(
        st[i],
        1.8,
        _fill(
          _op(
            p.ink,
            0.2 +
                0.8 *
                    _pow(math.max(0.0, math.sin(t * (1.1 + i * 0.3) + i * 2)), 2),
          ),
        ),
      );
    }
  }

  @override
  void front(Canvas c, FramePalette p) {
    c.save();
    c.translate(cx + 50, cy - 52);
    c.rotate((math.sin(t * 0.8) * 8 + _shake.x * 0.5) * _deg);
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 15)),
      Path()..addOval(Rect.fromCircle(center: const Offset(7, -6), radius: 13)),
    );
    c.drawPath(moon, _fill(const Color(0xFFFFD66B)));
    c.restore();

    final z = _clamp(_zzz.x, 0, 1);
    for (var i = 0; i < 3; i++) {
      final u = (t * 0.33 + i / 3) % 1;
      c.save();
      c.translate(cx + 30 + u * 28 + math.sin(u * 6 + i) * 5, cy - 50 - u * 50);
      c.rotate((-10 + u * 20) * _deg);
      _text(
        c,
        'z',
        Offset.zero,
        9 + u * 11,
        p.ink,
        FontWeight.w800,
        (u < 0.15 ? u / 0.15 : 1 - u) * z,
      );
      c.restore();
    }
    final e = math.max(0.0, _mark.x);
    if (e > 0.01) {
      c.save();
      c.translate(cx - 6, cy - R - 10);
      c.rotate(math.sin(t * 30) * 8 * (_alarm > 1 ? 1.0 : 0.0) * _deg);
      c.scale(e);
      _text(
        c,
        '!',
        Offset.zero,
        30,
        const Color(0xFFFF4D4D),
        FontWeight.w800,
        _clamp(e, 0, 1),
      );
      c.restore();
    }
  }
}
