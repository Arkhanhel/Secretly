// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../../profile_fx.dart';

// Эксклюзивная коллекция обложек (13.11.2026), дизайн-референс fx-premium-covers.js.
//
// Тёмная тема — как в референсе: формулы, константы, цвета, число частиц.
// Светлая: ночные сцены (притяжение, гроза, чернила, гиперпрыжок) остаются
// тёмными; дневные (полотно, шарики, хаос, жизнь, компасы, плюш) получают
// свою светлую палитру, сложение света там заменено обычным наложением.
//
// Что сделано иначе, чем в JS, и почему:
// • Полотно и «Жизнь» рисуются одной сеткой вершин (`drawVertices`) вместо
//   картинки по пикселям / тысячи прямоугольников: цвет в вершинах
//   интерполируется так же, как сглаженное растяжение `drawImage`.
// • Чернила — одним `drawRawAtlas` из спрайта свечения на все капли.
// • Компасы — стрелки собраны в 16 уровней яркости, по одному вызову на уровень.
// • Притяжение, хаос, чернила, компасы прогреваются до первого кадра, а гроза
//   стартует с бледным следом молнии — неподвижный кадр сразу содержательный.
// • Центр притяжения и гиперпрыжка — настоящее положение портрета (`av`).

/// Сцена набора → симуляция; null — не из этого файла.
CoverSim? _createCollectionCover(ProfileCoverStyle style) => switch (style) {
      ProfileCoverStyle.cloth => _XCloth(),
      ProfileCoverStyle.balls => _XBalls(),
      ProfileCoverStyle.orbits => _XOrbits(),
      ProfileCoverStyle.chaos => _XChaos(),
      ProfileCoverStyle.life => _XLife(),
      ProfileCoverStyle.compass => _XCompass(),
      ProfileCoverStyle.plush => _XPlush(),
      ProfileCoverStyle.storm => _XStorm(),
      ProfileCoverStyle.ink => _XInk(),
      ProfileCoverStyle.warp => _XWarp(),
      _ => null,
    };

final Paint _xF = Paint();
final Paint _xS = Paint()..style = PaintingStyle.stroke;

Paint _xFill(Color c, [BlendMode m = BlendMode.srcOver]) => _xF
  ..color = c
  ..shader = null
  ..blendMode = m;

Paint _xLine(Color c, double w,
        [StrokeCap cap = StrokeCap.round, StrokeJoin join = StrokeJoin.round, BlendMode m = BlendMode.srcOver]) =>
    _xS
      ..color = c
      ..shader = null
      ..strokeWidth = w
      ..strokeCap = cap
      ..strokeJoin = join
      ..blendMode = m;

/// `vfill` референса: вертикальный градиент с равными стопами.
void _xBg(Canvas c, Size s, List<Color> stops) =>
    c.drawRect(Offset.zero & s, _xFill(_white)..shader = _linG(Offset.zero, Offset(0, s.height), stops));

double _xTanh(double x) {
  if (x > 10) return 1;
  if (x < -10) return -1;
  final e = math.exp(2 * x);
  return (e - 1) / (e + 1);
}

int _x8(double v) => v <= 0 ? 0 : (v >= 255 ? 255 : v.round());

/// Много свечений одним вызовом: белый спрайт, окрашенный цветом каждой капли.
class _XAtlas {
  Float32List _xf = Float32List(0), _rc = Float32List(0);
  Int32List _cl = Int32List(0);
  int n = 0;
  final Paint _p = Paint()..filterQuality = FilterQuality.low;

  void add(double x, double y, double r, Color col, double op) {
    if (op <= 0.003 || r <= 0.5) return;
    if ((n + 1) * 4 > _xf.length) _grow();
    final i = n * 4, s = r / 32;
    _xf[i] = s;
    _xf[i + 1] = 0;
    _xf[i + 2] = x - r;
    _xf[i + 3] = y - r;
    _cl[n] = _op(col, op).toARGB32();
    n++;
  }

  void _grow() {
    final m = math.max(64, n * 2), xf = Float32List(m * 4), rc = Float32List(m * 4), cl = Int32List(m);
    xf.setRange(0, n * 4, _xf);
    cl.setRange(0, n, _cl);
    for (var i = 0; i < m; i++) {
      rc[i * 4 + 2] = 64;
      rc[i * 4 + 3] = 64;
    }
    _xf = xf;
    _rc = rc;
    _cl = cl;
  }

  void flush(Canvas c, bool add) {
    if (n == 0) return;
    _p.blendMode = add ? BlendMode.plus : BlendMode.srcOver;
    c.drawRawAtlas(_glowSprite(_white), Float32List.sublistView(_xf, 0, n * 4), Float32List.sublistView(_rc, 0, n * 4),
        Int32List.sublistView(_cl, 0, n), BlendMode.modulate, null, _p);
    n = 0;
  }
}

// ───────────── Полотно ─────────────
// Складки шёлка заданы бегущими диагональными волнами; касание добавляет рябь
// мембраны; свет — плавная кривая без отсечек.
class _XCloth extends CoverSim {
  int cs = 4, gw = 0, gh = 0;
  Float32List z = Float32List(0), v = Float32List(0), pos = Float32List(0);
  Float32List cr = Float32List(0), cg = Float32List(0), cb = Float32List(0);
  Int32List col = Int32List(0);
  Uint16List idx = Uint16List(0);
  Size _sz = Size.zero;

  @override
  void init(Size s) => _build(s);

  void _build(Size s) {
    _sz = s;
    // Шаг сетки 4 px, как в референсе; на очень большом холсте крупнее —
    // индексы вершин 16-битные.
    cs = 4;
    while (((s.width / cs).ceil() + 1) * ((s.height / cs).ceil() + 1) > 65000) {
      cs++;
    }
    gw = (s.width / cs).ceil() + 1;
    gh = (s.height / cs).ceil() + 1;
    final n = gw * gh;
    z = Float32List(n);
    v = Float32List(n);
    col = Int32List(n);
    pos = Float32List(n * 2);
    final sx = s.width / math.max(1, gw - 1), sy = s.height / math.max(1, gh - 1);
    for (var j = 0; j < gh; j++) {
      for (var i = 0; i < gw; i++) {
        final k = j * gw + i;
        pos[k * 2] = i * sx;
        pos[k * 2 + 1] = j * sy;
      }
    }
    idx = Uint16List(math.max(0, (gw - 1) * (gh - 1)) * 6);
    var o = 0;
    for (var j = 0; j < gh - 1; j++) {
      for (var i = 0; i < gw - 1; i++) {
        final a = j * gw + i, b = a + 1, c = a + gw, d = c + 1;
        idx[o++] = a;
        idx[o++] = b;
        idx[o++] = c;
        idx[o++] = b;
        idx[o++] = d;
        idx[o++] = c;
      }
    }
    cr = Float32List(gw);
    cg = Float32List(gw);
    cb = Float32List(gw);
    for (var i = 0; i < gw; i++) {
      final u = i / gw;
      cr[i] = u < 0.5 ? _lerp(74, 150, u * 2) : _lerp(150, 255, u * 2 - 1);
      cg[i] = u < 0.5 ? _lerp(107, 92, u * 2) : _lerp(92, 107, u * 2 - 1);
      cb[i] = u < 0.5 ? _lerp(255, 245, u * 2) : _lerp(245, 214, u * 2 - 1);
    }
  }

  void _poke(double cx, double cy, double f, double rad) {
    final j0 = math.max(0, (cy - rad).floor()), j1 = math.min(gh - 1, (cy + rad).floor());
    final i0 = math.max(0, (cx - rad).floor()), i1 = math.min(gw - 1, (cx + rad).floor());
    for (var j = j0; j <= j1; j++) {
      for (var i = i0; i <= i1; i++) {
        final d = _qHyp(i - cx, j - cy);
        if (d < rad) v[j * gw + i] += f * (1 - d / rad);
      }
    }
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    if (s != _sz) _build(s);
    if (gw < 2 || gh < 2) return;
    final sd = math.min(dt, 1 / 30) / 2;
    if (tap != null) _poke(tap.dx / cs, tap.dy / cs, -420, 7);
    if (pointer != null) _poke(pointer.dx / cs, pointer.dy / cs, -2000 * dt, 6);
    final n = gw * gh;
    for (var st = 0; st < 2; st++) {
      for (var j = 0; j < gh; j++) {
        for (var i = 0; i < gw; i++) {
          final k = j * gw + i,
              l = z[i > 0 ? k - 1 : k],
              r = z[i < gw - 1 ? k + 1 : k],
              u = z[j > 0 ? k - gw : k],
              d = z[j < gh - 1 ? k + gw : k];
          v[k] += (520 * (l + r + u + d - 4 * z[k]) - 9 * z[k] - 2.2 * v[k]) * sd;
        }
      }
      for (var k = 0; k < n; k++) {
        z[k] += v[k] * sd;
      }
    }
    final q = cs / 6;
    for (var j = 0; j < gh; j++) {
      final wj = 1.4 * math.sin(j * 0.05 * q + t * 0.4), y = j * q;
      for (var i = 0; i < gw; i++) {
        final k = j * gw + i, x = i * q;
        final fold = 0.9 * math.cos(x * 0.2 + y * 0.075 - t * 1.7 + wj) +
            0.5 * math.cos(x * 0.11 - y * 0.05 - t * 1.1 + 2) +
            0.25 * math.cos(x * 0.41 + y * 0.16 - t * 2.6);
        final tx = z[i < gw - 1 ? k + 1 : k] - z[i > 0 ? k - 1 : k], ty = z[j < gh - 1 ? k + gw : k] - z[j > 0 ? k - gw : k];
        final li = 0.5 + 0.5 * _xTanh((fold * 0.75 + tx * 0.5 - ty * 0.6) * 1.1), l2 = li * li, l4 = l2 * l2;
        final sp = 95 * l4 * l2 * li;
        double r, g, b;
        if (dark) {
          final sh = (0.16 + 0.84 * li) * 0.88;
          r = cr[i] * sh + sp * 0.8;
          g = cg[i] * sh + sp * 0.72;
          b = cb[i] * sh + sp;
        } else {
          // Дневной атлас: те же оттенки, разбавленные белым, тени мягче.
          final sh = 0.62 + 0.38 * li;
          r = (cr[i] * 0.62 + 97) * sh + sp * 0.55;
          g = (cg[i] * 0.62 + 97) * sh + sp * 0.5;
          b = (cb[i] * 0.62 + 97) * sh + sp * 0.62;
        }
        col[k] = (0xFF000000 | (_x8(r) << 16) | (_x8(g) << 8) | _x8(b)).toSigned(32);
      }
    }
    final vx = ui.Vertices.raw(VertexMode.triangles, pos, colors: col, indices: idx);
    c.drawVertices(vx, BlendMode.dst, _xFill(_white));
    vx.dispose();
  }
}

// ───────────── Шарики ─────────────
// Твёрдые тела с гравитацией и столкновениями; «пол» наклоняется за пальцем, касание — взрыв.
class _XBall {
  _XBall(this.x, this.y, this.vx, this.r, this.c)
      : sh = ui.Gradient.radial(Offset.zero, r, [_white, c, _op(c, 0.62)], const [0.0, 0.28, 1.0], TileMode.clamp,
            null, Offset(-r * 0.35, -r * 0.4), r * 0.08);
  double x, y, vx, vy = 0;
  final double r;
  final Color c;
  final ui.Gradient sh;
}

class _XBalls extends CoverSim {
  double sc = 1;
  List<_XBall> b = [];
  Size _sz = Size.zero;
  static const List<Color> _cs = [
    Color(0xFFFF5F6D),
    Color(0xFFFFB23F),
    Color(0xFF3DD6FF),
    Color(0xFF7A5CFF),
    Color(0xFF3DFFB2),
    Color(0xFFFF4FD8),
    Color(0xFFFFE08A),
  ];

  @override
  void init(Size s) {
    final w = s.width, h = s.height;
    _sz = s;
    sc = _clamp(h / 200, 0.5, 1.1);
    final n = _clamp(w * h / 2700, 12, 28).round();
    b = List<_XBall>.generate(n, (i) {
      final r = (9 + _rnd() * 9) * sc;
      return _XBall(r + _rnd() * (w - 2 * r), _rnd() * h * 0.6, (_rnd() - 0.5) * 60, r, _cs[i % 7]);
    });
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    if (s != _sz) {
      // Новый размер: шарики переезжают пропорционально, стены сделают остальное.
      for (final q in b) {
        q.x *= w / _sz.width;
        q.y *= h / _sz.height;
      }
      _sz = s;
    }
    _xBg(c, s, dark ? const [Color(0xFF0E1020), Color(0xFF1A1430)] : const [Color(0xFFEEF0F8), Color(0xFFDADCEE)]);
    _glowS(c, Offset(w * 0.5, h * 1.1), h, dark ? const Color(0xFF4A3A9A) : const Color(0xFF8C7CE0), dark ? 0.4 : 0.3,
        dark);
    final gx = pointer != null ? (pointer.dx / w - 0.5) * 620 : math.sin(t * 0.35) * 60,
        gy = 520 * sc,
        sd = math.min(dt, 1 / 30) / 2;
    if (tap != null) {
      for (final q in b) {
        _push(tap, q.x, q.y, 170, 700, (ax, ay) {
          q.vx += ax;
          q.vy += ay - 120;
        });
      }
    }
    for (var st = 0; st < 2; st++) {
      for (final q in b) {
        q.vx += gx * sd;
        q.vy += gy * sd;
        q.x += q.vx * sd;
        q.y += q.vy * sd;
        if (q.x < q.r) {
          q.x = q.r;
          q.vx = q.vx.abs() * 0.6;
        }
        if (q.x > w - q.r) {
          q.x = w - q.r;
          q.vx = -q.vx.abs() * 0.6;
        }
        if (q.y > h - q.r) {
          q.y = h - q.r;
          q.vy = -q.vy.abs() * 0.55;
          q.vx *= 0.985;
        }
        if (q.y < q.r - 60) {
          q.y = q.r - 60;
          q.vy = q.vy.abs() * 0.5;
        }
      }
      for (var i = 0; i < b.length; i++) {
        for (var j = i + 1; j < b.length; j++) {
          final a = b[i], o = b[j], dx = o.x - a.x, dy = o.y - a.y, m = a.r + o.r, d2 = dx * dx + dy * dy;
          if (d2 >= m * m || d2 == 0) continue;
          final d = math.sqrt(d2), nx = dx / d, ny = dy / d, ov = (m - d) / 2, ma = a.r * a.r, mb = o.r * o.r;
          a.x -= nx * ov;
          a.y -= ny * ov;
          o.x += nx * ov;
          o.y += ny * ov;
          final rv = (o.vx - a.vx) * nx + (o.vy - a.vy) * ny;
          if (rv < 0) {
            final jj = -1.55 * rv / (1 / ma + 1 / mb);
            a.vx -= jj / ma * nx;
            a.vy -= jj / ma * ny;
            o.vx += jj / mb * nx;
            o.vy += jj / mb * ny;
          }
        }
      }
    }
    final shadow = dark ? 0.35 : 0.16;
    for (final q in b) {
      _glowS(c, Offset(q.x, q.y + q.r * 0.5), q.r * 1.7, const Color(0xFF000008), shadow);
      c.save();
      c.translate(q.x, q.y);
      c.drawCircle(Offset.zero, q.r, _xFill(_white)..shader = q.sh);
      c.restore();
    }
  }
}

// ───────────── Притяжение ─────────────
// Сотни тел на орбитах вокруг портрета; палец — вторая масса, касание — гравитационная праща.
class _XBody {
  _XBody(this.x, this.y, this.vx, this.vy, this.c);
  double x, y, vx, vy;
  final Color c;
  // След в координатах от центра портрета (y уже сжат наклоном), до 18 точек.
  final Float32List tr = Float32List(36);
  int n = 0;
}

class _XOrbits extends CoverSim {
  static const double gm = 2.4e5, tilt = 0.42;
  List<_XBody> p = [];
  double slx = 0, sly = 0, sla = 0;
  bool sl = false;
  final Path _path = Path();
  static const List<Color> _cs = [Color(0xFFBFD0FF), Color(0xFFFFFFFF), Color(0xFFFFB8E0), Color(0xFF9AD8FF), Color(0xFFFFE9C0)];

  _XBody mk(double w) {
    final r = 44 + math.pow(_rnd(), 1.3).toDouble() * w * 0.46, a = _rnd() * _tau, v = math.sqrt(gm / r) * (0.92 + _rnd() * 0.16);
    return _XBody(math.cos(a) * r, math.sin(a) * r, -math.sin(a) * v, math.cos(a) * v, _cs[(_rnd() * 5).floor()]);
  }

  @override
  void init(Size s) {
    p = List<_XBody>.generate(_clamp(s.width / 2, 120, 220).round(), (_) => mk(s.width));
    // Прогрев 1 с: следы уже есть в первом кадре.
    for (var k = 0; k < 60; k++) {
      _sim(s.width, 1 / 120, false, 0, 0, 0, false, 0, 0, 0);
    }
  }

  /// Один кадр физики всех тел (два подшага) и запись следа.
  void _sim(double w, double sd, bool h2, double m2x, double m2y, double m2g, bool h3, double m3x, double m3y, double m3g) {
    for (var i = 0; i < p.length; i++) {
      var q = p[i];
      for (var st = 0; st < 2; st++) {
        var ax = 0.0, ay = 0.0;
        var dx = -q.x, dy = -q.y, r2 = dx * dx + dy * dy + 500, k = gm / (r2 * math.sqrt(r2));
        ax += dx * k;
        ay += dy * k;
        if (h2) {
          dx = m2x - q.x;
          dy = m2y - q.y;
          r2 = dx * dx + dy * dy + 500;
          k = m2g / (r2 * math.sqrt(r2));
          ax += dx * k;
          ay += dy * k;
        }
        if (h3) {
          dx = m3x - q.x;
          dy = m3y - q.y;
          r2 = dx * dx + dy * dy + 500;
          k = m3g / (r2 * math.sqrt(r2));
          ax += dx * k;
          ay += dy * k;
        }
        q.vx += ax * sd;
        q.vy += ay * sd;
        q.x += q.vx * sd;
        q.y += q.vy * sd;
      }
      final r = _qHyp(q.x, q.y);
      if (r > w * 0.75 || r < 30) q = p[i] = mk(w);
      final tx = q.x, ty = q.y * tilt, m = q.n;
      if (m == 0 || _qHyp(tx - q.tr[m - 2], ty - q.tr[m - 1]) >= 3.5) {
        if (m == 36) {
          q.tr.setRange(0, 34, q.tr, 2);
          q.tr[34] = tx;
          q.tr[35] = ty;
        } else {
          q.tr[m] = tx;
          q.tr[m + 1] = ty;
          q.n = m + 2;
        }
      }
    }
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, cx = av.dx, cy = av.dy, sd = math.min(dt, 1 / 30) / 2;
    _xBg(c, s, const [Color(0xFF05050F), Color(0xFF0C0A22), Color(0xFF070612)]);
    _glowS(c, av, w * 0.3, const Color(0xFF7A5CFF), 0.3, true);
    _glowS(c, av, w * 0.16, const Color(0xFFFFD9A0), 0.45, true);
    if (tap != null) {
      slx = tap.dx - cx;
      sly = (tap.dy - cy) / tilt;
      sla = 1;
      sl = true;
    }
    if (sl) {
      sla -= dt * 1.1;
      if (sla <= 0) sl = false;
    }
    _sim(w, sd, pointer != null, pointer == null ? 0 : pointer.dx - cx, pointer == null ? 0 : (pointer.dy - cy) / tilt, gm * 0.4,
        sl, slx, sly, gm * 1.5 * sla);
    c.save();
    c.translate(cx, cy);
    for (final q in p) {
      final n = q.n;
      if (n < 4) continue;
      final r = _qHyp(q.x, q.y), al = _clamp(0.3 + 50 / r, 0.3, 0.9), h2 = (n / 4).floor() * 2;
      _path.reset();
      _path.moveTo(q.tr[0], q.tr[1]);
      for (var k = 2; k <= h2; k += 2) {
        _path.lineTo(q.tr[k], q.tr[k + 1]);
      }
      c.drawPath(_path, _xLine(_op(q.c, al * 0.35), 0.8, StrokeCap.round, StrokeJoin.miter, BlendMode.plus));
      _path.reset();
      _path.moveTo(q.tr[h2], q.tr[h2 + 1]);
      for (var k = h2 + 2; k < n; k += 2) {
        _path.lineTo(q.tr[k], q.tr[k + 1]);
      }
      _path.lineTo(q.x, q.y * tilt);
      c.drawPath(_path, _xLine(_op(q.c, al), 1.2, StrokeCap.round, StrokeJoin.miter, BlendMode.plus));
    }
    c.restore();
    if (pointer != null) {
      _glowS(c, pointer, 20, const Color(0xFF9AD8FF), 0.6, true);
      c.drawCircle(pointer, 2.4, _xFill(_white));
    }
    if (sl) {
      final x = cx + slx, y = cy + sly * tilt, rr = (1 - sla) * 60 + 4;
      _glowS(c, Offset(x, y), 34, const Color(0xFFFFB8E0), sla * 0.8, true);
      c.drawOval(_ov(x, y, rr, rr * tilt), _xLine(_op(_white, sla * 0.6), 1));
    }
  }
}

// ───────────── Хаос ─────────────
// Двойные маятники — честные уравнения движения; два почти одинаковых старта расходятся на глазах.
class _XPend {
  _XPend(this.fx, this.a1, this.ci) : a2 = a1 + 0.6;
  final double fx; // доля ширины для точки подвеса
  double a1, a2, w1 = 0, w2 = 0;
  final int ci;
  // След конца второго плеча — от точки подвеса, до 180 точек.
  final Float32List tr = Float32List(360);
  int n = 0;
}

class _XChaos extends CoverSim {
  double ln = 30, g = 1000;
  List<_XPend> p = [];
  Size _sz = Size.zero;
  final Path _path = Path();
  static const List<Color> _dk = [Color(0xFFFF6BD6), Color(0xFF7FE0FF), Color(0xFFFFD36B), Color(0xFFB69CFF)];
  static const List<Color> _lt = [Color(0xFFD63FA8), Color(0xFF1E9CC8), Color(0xFFD9961A), Color(0xFF7A5CE0)];

  @override
  void init(Size s) {
    _sz = s;
    ln = s.height * 0.15;
    g = 5.2 * s.height;
    p = [_XPend(0.2, 2.2, 0), _XPend(0.2, 2.21, 1), _XPend(0.8, -2.4, 2), _XPend(0.8, -2.41, 3)];
    // Прогрев 1.5 с: следы видны с первого кадра.
    for (var k = 0; k < 90; k++) {
      for (final q in p) {
        _step(q, 1 / 360);
      }
    }
  }

  void _step(_XPend q, double sd) {
    for (var st = 0; st < 6; st++) {
      final d = q.a1 - q.a2, den = 3 - math.cos(2 * d), sdd = math.sin(d), cdd = math.cos(d);
      final a1 = (-3 * g * math.sin(q.a1) - g * math.sin(q.a1 - 2 * q.a2) - 2 * sdd * (q.w2 * q.w2 * ln + q.w1 * q.w1 * ln * cdd)) /
          (ln * den);
      final a2 = (2 * sdd * (q.w1 * q.w1 * ln * 2 + 2 * g * math.cos(q.a1) + q.w2 * q.w2 * ln * cdd)) / (ln * den);
      q.w1 += a1 * sd;
      q.w2 += a2 * sd;
      q.a1 += q.w1 * sd;
      q.a2 += q.w2 * sd;
    }
    if (q.w1.abs() + q.w2.abs() < 0.4 && math.sin(q.a1).abs() < 0.2) q.w1 += (_rnd() < 0.5 ? -1 : 1) * 7;
    q.w1 = _clamp(q.w1, -22, 22);
    q.w2 = _clamp(q.w2, -30, 30);
    final x2 = math.sin(q.a1) * ln + math.sin(q.a2) * ln, y2 = math.cos(q.a1) * ln + math.cos(q.a2) * ln;
    if (q.n == 360) {
      q.tr.setRange(0, 358, q.tr, 2);
      q.tr[358] = x2;
      q.tr[359] = y2;
    } else {
      q.tr[q.n] = x2;
      q.tr[q.n + 1] = y2;
      q.n += 2;
    }
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    if (s != _sz) {
      // Другой размер: длины плеч и следы масштабируются, движение не теряется.
      final k = (h * 0.15) / ln;
      for (final q in p) {
        for (var i = 0; i < q.n; i++) {
          q.tr[i] *= k;
        }
      }
      ln = h * 0.15;
      g = 5.2 * h;
      _sz = s;
    }
    _xBg(c, s, dark ? const [Color(0xFF07080F), Color(0xFF12101E)] : const [Color(0xFFF4F2FA), Color(0xFFE4E0F0)]);
    final sd = math.min(dt, 1 / 30) / 6, py = h * 0.36;
    if (tap != null) {
      for (final q in p) {
        final px = w * q.fx;
        if ((tap.dx - px).abs() < w * 0.33) {
          final sg = tap.dx < px ? 1 : -1;
          q.w1 += sg * 6;
          q.w2 -= sg * 4;
        }
      }
    }
    final cols = dark ? _dk : _lt, mode = dark ? BlendMode.plus : BlendMode.srcOver;
    final arm = dark ? const Color.fromRGBO(255, 255, 255, 0.55) : const Color.fromRGBO(42, 42, 64, 0.55);
    final piv = dark ? const Color.fromRGBO(255, 255, 255, 0.7) : const Color.fromRGBO(42, 42, 64, 0.7);
    final joint = dark ? const Color(0xFFE8EEFF) : const Color(0xFF5A5E78);
    for (final q in p) {
      _step(q, sd);
      final px = w * q.fx, x1 = px + math.sin(q.a1) * ln, y1 = py + math.cos(q.a1) * ln;
      final x2 = x1 + math.sin(q.a2) * ln, y2 = y1 + math.cos(q.a2) * ln, col = cols[q.ci];
      final n = q.n;
      const ch = 12;
      c.save();
      c.translate(px, py);
      for (var cc = 0; cc < ch; cc++) {
        final i0 = (n / 2 * cc / ch).floor() * 2, i1 = math.min(n - 2, (n / 2 * (cc + 1) / ch).floor() * 2 + 2);
        if (i1 - i0 < 4) continue;
        final u = (cc + 1) / ch;
        _path.reset();
        _path.moveTo(q.tr[i0], q.tr[i0 + 1]);
        for (var i = i0 + 2; i <= i1; i += 2) {
          _path.lineTo(q.tr[i], q.tr[i + 1]);
        }
        c.drawPath(_path, _xLine(_op(col, u * u * 0.85), 0.6 + u * 1.3, StrokeCap.round, StrokeJoin.round, mode));
      }
      c.restore();
      _path.reset();
      _path
        ..moveTo(px, py)
        ..lineTo(x1, y1)
        ..lineTo(x2, y2);
      c.drawPath(_path, _xLine(arm, 1.3));
      c.drawCircle(Offset(px, py), 2, _xFill(piv));
      c.drawCircle(Offset(x1, y1), 2.6, _xFill(joint));
      _glowS(c, Offset(x2, y2), 10, col, dark ? 0.9 : 0.55, dark);
      // На светлом фоне белый груз пропадает — там он цвета своего следа.
      c.drawCircle(Offset(x2, y2), 3, _xFill(dark ? _white : col));
    }
  }
}

// ───────────── Жизнь ─────────────
// Клеточный автомат Конвея, шаг 0.1 с; палец «рисует» живые клетки, касание запускает планеры.
class _XLife extends CoverSim {
  int cs = 5, gw = 0, gh = 0;
  Uint8List a = Uint8List(0), b = Uint8List(0);
  Float32List ht = Float32List(0), pos = Float32List(0);
  Int32List col = Int32List(0);
  Uint16List idx = Uint16List(0);
  List<int> _cd = const [], _cl = const [];
  double acc = 0;
  Size _sz = Size.zero;

  @override
  void init(Size s) {
    _build(s);
    for (var i = 0; i < a.length; i++) {
      a[i] = _rnd() < 0.24 ? 1 : 0;
      // Клетки сразу видны: неподвижный кадр не «проявляется» с нуля.
      ht[i] = a[i].toDouble();
    }
  }

  void _build(Size s) {
    final oa = a, oh = ht, ow = gw, og = gh;
    _sz = s;
    cs = math.max(5, (s.height / 28).round());
    while ((s.width / cs).ceil() * (s.height / cs).ceil() > 16000) {
      cs++;
    }
    gw = math.max(1, (s.width / cs).ceil());
    gh = math.max(1, (s.height / cs).ceil());
    final n = gw * gh;
    a = Uint8List(n);
    b = Uint8List(n);
    ht = Float32List(n);
    // Прежнее поле переносится в новое — смена размера не стирает узор.
    for (var y = 0; y < math.min(gh, og); y++) {
      for (var x = 0; x < math.min(gw, ow); x++) {
        a[y * gw + x] = oa[y * ow + x];
        ht[y * gw + x] = oh[y * ow + x];
      }
    }
    pos = Float32List(n * 8);
    idx = Uint16List(n * 6);
    col = Int32List(n * 4);
    for (var y = 0; y < gh; y++) {
      for (var x = 0; x < gw; x++) {
        final i = y * gw + x, l = x * cs + 0.5, t = y * cs + 0.5, r = l + cs - 1, bt = t + cs - 1, o = i * 8, v = i * 4;
        pos[o] = l;
        pos[o + 1] = t;
        pos[o + 2] = r;
        pos[o + 3] = t;
        pos[o + 4] = l;
        pos[o + 5] = bt;
        pos[o + 6] = r;
        pos[o + 7] = bt;
        idx.setAll(i * 6, [v, v + 1, v + 2, v + 1, v + 3, v + 2]);
      }
    }
    _cd = List<int>.generate(gw, (i) {
      final u = i / gw;
      return (_lerp(61, 179, u).round() << 16) | (_lerp(255, 107, u).round() << 8) | _lerp(178, 255, u).round();
    });
    _cl = List<int>.generate(gw, (i) {
      final u = i / gw;
      return (_lerp(20, 128, u).round() << 16) | (_lerp(168, 64, u).round() << 8) | _lerp(118, 224, u).round();
    });
  }

  void put(int x, int y) => a[(y % gh + gh) % gh * gw + (x % gw + gw) % gw] = 1;

  void step() {
    final aa = a, bb = b;
    var pop = 0;
    for (var y = 0; y < gh; y++) {
      final yu = (y + gh - 1) % gh * gw, yd = (y + 1) % gh * gw, y0 = y * gw;
      for (var x = 0; x < gw; x++) {
        final xl = (x + gw - 1) % gw, xr = (x + 1) % gw;
        final n = aa[yu + xl] + aa[yu + x] + aa[yu + xr] + aa[y0 + xl] + aa[y0 + xr] + aa[yd + xl] + aa[yd + x] + aa[yd + xr];
        final v = n == 3 || (n == 2 && aa[y0 + x] == 1) ? 1 : 0;
        bb[y0 + x] = v;
        pop += v;
      }
    }
    a = bb;
    b = aa;
    if (pop < gw * gh * 0.04) {
      for (var i = 0; i < 40; i++) {
        final x = (_rnd() * gw).floor(), y = (_rnd() * gh).floor();
        put(x, y);
        put(x + 1, y);
        put(x, y + 1);
        put(x - 1, y);
        put(x, y - 1 + (_rnd() < 0.5 ? 2 : 0));
      }
    }
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    if (s != _sz) _build(s);
    c.drawRect(Offset.zero & s, _xFill(dark ? const Color(0xFF06080E) : const Color(0xFFF5F6FA)));
    if (pointer != null) {
      final x = (pointer.dx / cs).floor(), y = (pointer.dy / cs).floor();
      put(x, y);
      put(x + 1, y);
      put(x, y + 1);
    }
    if (tap != null) {
      final x = (tap.dx / cs).floor(), y = (tap.dy / cs).floor();
      for (final d in const [
        [1, 1],
        [-1, 1],
        [1, -1],
        [-1, -1]
      ]) {
        final ox = x + d[0] * 3, oy = y + d[1] * 3;
        for (final q in const [
          [1, 0],
          [2, 1],
          [0, 2],
          [1, 2],
          [2, 2]
        ]) {
          put(ox + q[0] * d[0], oy + q[1] * d[1]);
        }
      }
    }
    acc += dt;
    if (acc > 0.1) {
      acc = 0;
      step();
    }
    final k = math.min(1.0, dt * 7), kOn = math.min(1.0, dt * 18), cols = dark ? _cd : _cl;
    final dead = dark ? 0x3A4A8A : 0xA8B2DA;
    for (var y = 0; y < gh; y++) {
      for (var x = 0; x < gw; x++) {
        final i = y * gw + x, on = a[i] == 1;
        final h = ht[i] += ((on ? 1 : 0) - ht[i]) * (on ? kOn : k * 0.45);
        final v = i * 4;
        if (h < 0.03) {
          col[v] = col[v + 1] = col[v + 2] = col[v + 3] = 0;
          continue;
        }
        final argb = ((_x8(math.min(1.0, h) * 255) << 24) | (on ? cols[x] : dead)).toSigned(32);
        col[v] = col[v + 1] = col[v + 2] = col[v + 3] = argb;
      }
    }
    final vx = ui.Vertices.raw(VertexMode.triangles, pos, colors: col, indices: idx);
    c.drawVertices(vx, BlendMode.dst, _xFill(_white));
    vx.dispose();
  }
}

// ───────────── Компасы ─────────────
// Поле стрелок с инерцией; палец — магнит, касание меняет полюса, и разворот идёт волной.
class _XCompass extends CoverSim {
  double sp = 17;
  double pol = 1;
  Float64List nx = Float64List(0), ny = Float64List(0), na = Float64List(0), nw = Float64List(0);
  final Float64List _px = Float64List(3), _py = Float64List(3), _pq = Float64List(3);
  int _np = 2;
  bool _warm = false;
  Size _sz = Size.zero;
  static const int _lv = 16;
  final List<Float32List> _tb = List<Float32List>.generate(_lv, (_) => Float32List(0));
  final List<Float32List> _hb = List<Float32List>.generate(_lv, (_) => Float32List(0));
  final List<int> _cnt = List<int>.filled(_lv, 0);
  final Paint _lp = Paint()
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;

  @override
  void init(Size s) => _build(s);

  void _build(Size s) {
    final w = s.width, h = s.height;
    _sz = s;
    sp = 17 * _clamp(h / 200, 0.7, 1);
    final cols = math.max(1, (w / sp).floor()), rows = math.max(1, (h / sp).floor());
    final ox = (w - (cols - 1) * sp) / 2, oy = (h - (rows - 1) * sp) / 2, n = cols * rows;
    nx = Float64List(n);
    ny = Float64List(n);
    na = Float64List(n);
    nw = Float64List(n);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        nx[i] = ox + c * sp;
        ny[i] = oy + r * sp;
        na[i] = _rnd() * _tau;
      }
    }
    for (var l = 0; l < _lv; l++) {
      _tb[l] = Float32List(n * 4);
      _hb[l] = Float32List(n * 4);
    }
    _warm = false;
  }

  void _poles(Size s, double t, Offset? pointer) {
    final w = s.width, h = s.height;
    _px[0] = w * 0.24 + math.sin(t * 0.31) * w * 0.12;
    _py[0] = h * 0.4 + math.cos(t * 0.27) * h * 0.25;
    _pq[0] = 1;
    _px[1] = w * 0.76 + math.cos(t * 0.23) * w * 0.12;
    _py[1] = h * 0.6 + math.sin(t * 0.33) * h * 0.25;
    _pq[1] = -1;
    _np = 2;
    if (pointer != null) {
      _px[2] = pointer.dx;
      _py[2] = pointer.dy;
      _pq[2] = 3.5;
      _np = 3;
    }
  }

  /// Физика стрелок; с [draw] = true — ещё и раскладка по уровням яркости.
  void _sim(double sd, double ln, bool draw) {
    if (draw) _cnt.fillRange(0, _lv, 0);
    for (var i = 0; i < nx.length; i++) {
      var bx = 0.0, by = 0.0;
      for (var k = 0; k < _np; k++) {
        final dx = nx[i] - _px[k], dy = ny[i] - _py[k], r2 = dx * dx + dy * dy + 120, q = _pq[k] * pol / (r2 * math.sqrt(r2));
        bx += dx * q;
        by += dy * q;
      }
      final m = _qHyp(bx, by), st = _clamp(m * 9000, 0.15, 1);
      nw[i] += (math.sin(math.atan2(by, bx) - na[i]) * 70 * (0.3 + st) - nw[i] * 4.5) * sd;
      na[i] += nw[i] * sd;
      if (!draw) continue;
      final cx = math.cos(na[i]) * ln, cy = math.sin(na[i]) * ln, al = 0.3 + 0.7 * st;
      final l = ((al - 0.3) / 0.7 * (_lv - 1)).round(), o = _cnt[l] * 4, tb = _tb[l], hb = _hb[l];
      tb[o] = nx[i] - cx;
      tb[o + 1] = ny[i] - cy;
      tb[o + 2] = nx[i];
      tb[o + 3] = ny[i];
      hb[o] = nx[i];
      hb[o + 1] = ny[i];
      hb[o + 2] = nx[i] + cx;
      hb[o + 3] = ny[i] + cy;
      _cnt[l]++;
    }
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    if (s != _sz) _build(s);
    _xBg(c, s, dark ? const [Color(0xFF0A0C18), Color(0xFF141A33)] : const [Color(0xFFEEF1F8), Color(0xFFDCE2F0)]);
    if (tap != null) pol *= -1;
    _poles(s, t, pointer);
    if (!_warm) {
      // Прогрев 0.75 с — стрелки уже выстроены по полю в первом кадре.
      _warm = true;
      for (var k = 0; k < 45; k++) {
        _sim(1 / 60, 0, false);
      }
    }
    for (var k = 0; k < _np; k++) {
      _glowS(c, Offset(_px[k], _py[k]), 38, _pq[k] * pol > 0 ? const Color(0xFFFF5A7A) : const Color(0xFF6C8BFF),
          dark ? 0.4 : 0.3, dark);
    }
    _sim(math.min(dt, 1 / 30), sp * 0.38, true);
    final tail = dark ? const Color(0xFFC9D4FF) : const Color(0xFF5A6688), head = dark ? const Color(0xFFFF5A7A) : const Color(0xFFE0405F);
    for (var l = 0; l < _lv; l++) {
      final n = _cnt[l];
      if (n == 0) continue;
      final al = 0.3 + 0.7 * l / (_lv - 1);
      _lp.color = _op(tail, al * 0.75);
      c.drawRawPoints(ui.PointMode.lines, Float32List.sublistView(_tb[l], 0, n * 4), _lp);
    }
    for (var l = 0; l < _lv; l++) {
      final n = _cnt[l];
      if (n == 0) continue;
      _lp.color = _op(head, 0.3 + 0.7 * l / (_lv - 1));
      c.drawRawPoints(ui.PointMode.lines, Float32List.sublistView(_hb[l], 0, n * 4), _lp);
    }
  }
}

// ───────────── Плюш ─────────────
// Ворс можно гладить — ворсинки ложатся по движению пальца и медленно поднимаются обратно.
class _XPlush extends CoverSim {
  int n = 0;
  Float32List x = Float32List(0), y = Float32List(0), ox = Float32List(0), oy = Float32List(0);
  Float32List vx = Float32List(0), vy = Float32List(0);
  double len = 9;
  Offset? lp;
  Size _sz = Size.zero;
  final List<Float32List> _bk = List<Float32List>.generate(4, (_) => Float32List(0));
  final List<int> _cnt = [0, 0, 0, 0];
  final Paint _lp = Paint()
    ..strokeWidth = 2.3
    ..strokeCap = StrokeCap.round;
  static const List<Color> _dk = [Color(0xFF5A2E9A), Color(0xFF8A4FD6), Color(0xFFB37BFF), Color(0xFFE6CCFF)];
  static const List<Color> _lt = [Color(0xFF9A70D0), Color(0xFFB690EA), Color(0xFFD2B4F6), Color(0xFFF7EEFF)];

  @override
  void init(Size s) {
    const sp = 6.5;
    _sz = s;
    final cols = (s.width / sp).ceil() + 1, rows = (s.height / sp).ceil() + 1;
    n = cols * rows;
    x = Float32List(n);
    y = Float32List(n);
    ox = Float32List(n);
    oy = Float32List(n);
    vx = Float32List(n);
    vy = Float32List(n);
    len = 9 * _clamp(s.height / 200, 0.7, 1);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        x[i] = c * sp + (_rnd() - 0.5) * 4;
        y[i] = r * sp + (_rnd() - 0.5) * 4 - 4;
      }
    }
    for (var b = 0; b < 4; b++) {
      _bk[b] = Float32List(n * 4);
    }
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    if (s != _sz) init(s);
    _xBg(c, s, dark ? const [Color(0xFF2A1648), Color(0xFF3A1E5C)] : const [Color(0xFFE6D6F5), Color(0xFFD8C2EE)]);
    final ll = len, sd = math.min(dt, 1 / 30), last = lp;
    final pvx = pointer != null && last != null ? _clamp((pointer.dx - last.dx) / math.max(dt, 0.008), -900, 900) : 0.0;
    final pvy = pointer != null && last != null ? _clamp((pointer.dy - last.dy) / math.max(dt, 0.008), -900, 900) : 0.0;
    _cnt.fillRange(0, 4, 0);
    for (var i = 0; i < n; i++) {
      final px = x[i], py = y[i];
      if (pointer != null) {
        final d = _qHyp(px - pointer.dx, py - pointer.dy);
        if (d < 44) {
          final k = (1 - d / 44) * sd * 0.5;
          vx[i] += pvx * k;
          vy[i] += pvy * k;
        }
      }
      if (tap != null) {
        final dx = px - tap.dx, dy = py - tap.dy, d0 = _qHyp(dx, dy), d = d0 == 0 ? 1.0 : d0;
        if (d < 110) {
          final k = (1 - d / 110) * 70 / d;
          vx[i] += dx * k;
          vy[i] += dy * k;
        }
      }
      final br = math.sin(px * 0.03 + py * 0.02 - t * 1.3) * 1.3;
      vx[i] += (-ox[i] * 5 - vx[i] * 5.5) * sd;
      vy[i] += (-oy[i] * 5 - vy[i] * 5.5) * sd;
      ox[i] = _clamp(ox[i] + vx[i] * sd, -1.6, 1.6);
      oy[i] = _clamp(oy[i] + vy[i] * sd, -1.6, 1.6);
      final ex = (0.28 + ox[i]) * ll + br, ey = (0.85 + oy[i] * 0.9) * ll;
      final li = _clamp(0.5 + (ex * -0.06 + (ll - ey) * 0.1), 0, 0.999), b = (li * 4).floor(), o = _cnt[b] * 4, q = _bk[b];
      q[o] = px;
      q[o + 1] = py;
      q[o + 2] = px + ex;
      q[o + 3] = py + ey;
      _cnt[b]++;
    }
    final cs = dark ? _dk : _lt;
    for (var b = 0; b < 4; b++) {
      if (_cnt[b] == 0) continue;
      _lp.color = cs[b];
      c.drawRawPoints(ui.PointMode.lines, Float32List.sublistView(_bk[b], 0, _cnt[b] * 4), _lp);
    }
    lp = pointer;
  }
}

// ───────────── Гроза ─────────────
// Ветвящаяся молния бьёт точно в точку касания, вспышка освещает тучи, дождь сносит порывом.
class _XCloud {
  _XCloud(this.x, this.y, this.r, this.v);
  double x, y, r;
  final double v;
}

class _XBranch {
  _XBranch(this.p, this.w);
  final Path p;
  final double w;
}

class _XBolt {
  _XBolt(this.bs, this.end);
  final List<_XBranch> bs;
  final Offset end;
  double life = 0.6;
}

class _XSpk {
  _XSpk(this.x, this.y, this.vx, this.vy, this.life);
  double x, y, vx, vy, age = 0;
  final double life;
}

class _XStorm extends CoverSim {
  double sc = 1, fl = 0, fx = 0, tm = 1.4;
  List<_XCloud> cl = [];
  Float32List dx = Float32List(0), dy = Float32List(0), dv = Float32List(0), _rain = Float32List(0);
  final List<_XBolt> bolts = [];
  List<_XBranch>? ghost;
  final Spring wind = Spring(-0.25);
  final List<_XSpk> sp = [];
  Size _sz = Size.zero;
  final Paint _rp = Paint()
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round;

  @override
  void init(Size s) {
    final w = s.width, h = s.height;
    _sz = s;
    sc = _clamp(h / 200, 0.55, 1.1);
    cl = List<_XCloud>.generate(16, (_) => _XCloud(_rnd() * w, h * (_rnd() * 0.3 - 0.05), h * (0.3 + _rnd() * 0.3), 4 + _rnd() * 8));
    final n = (w / 3.5).round();
    dx = Float32List(n);
    dy = Float32List(n);
    dv = Float32List(n);
    _rain = Float32List(n * 4);
    for (var i = 0; i < n; i++) {
      dx[i] = _rnd() * w;
      dy[i] = _rnd() * h;
      dv[i] = 260 + _rnd() * 160;
    }
    fx = w / 2;
    wind.t = -0.25;
    // Бледный след «прошлой» молнии — неподвижный кадр не пустой.
    ghost = _branches(w, h, w * (0.1 + _rnd() * 0.8), h * (0.6 + _rnd() * 0.35)).$1;
  }

  List<Offset> _path(double x0, double y0, double x1, double y1, double d) {
    var p = <Offset>[Offset(x0, y0), Offset(x1, y1)];
    for (var k = 0; k < 5; k++) {
      final q = <Offset>[p[0]], o = d / (1 << k);
      for (var i = 1; i < p.length; i++) {
        final a = p[i - 1], b = p[i];
        q.add(Offset((a.dx + b.dx) / 2 + (_rnd() - 0.5) * o, (a.dy + b.dy) / 2 + (_rnd() - 0.5) * o * 0.4));
        q.add(b);
      }
      p = q;
    }
    return p;
  }

  static Path _toPath(List<Offset> p) {
    final path = Path()..moveTo(p[0].dx, p[0].dy);
    for (var i = 1; i < p.length; i++) {
      path.lineTo(p[i].dx, p[i].dy);
    }
    return path;
  }

  (List<_XBranch>, Offset, double) _branches(double w, double h, double x, double y) {
    final sx = x + (_rnd() - 0.5) * 70, main = _path(sx, h * 0.1, x, y, 46 * sc), bs = [_XBranch(_toPath(main), 1)];
    for (var i = 0; i < 3; i++) {
      final k = 6 + (_rnd() * 16).floor(), o = main[k], len = (y - o.dy) * (0.3 + _rnd() * 0.4);
      bs.add(_XBranch(_toPath(_path(o.dx, o.dy, o.dx + (_rnd() - 0.5) * 90 * sc, o.dy + len, 22 * sc)), 0.5));
    }
    return (bs, main.last, sx);
  }

  void strike(double w, double h, double x, double y) {
    final (bs, end, sx) = _branches(w, h, x, y);
    bolts.add(_XBolt(bs, end));
    ghost = bs;
    fl = 1;
    fx = sx;
    wind.v += (_rnd() - 0.5) * 3;
    for (var i = 0; i < 14; i++) {
      sp.add(_XSpk(x, y, (_rnd() - 0.5) * 160, -_rnd() * 150, 0.3 + _rnd() * 0.4));
    }
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    if (s != _sz) {
      final kx = w / _sz.width, ky = h / _sz.height;
      for (final q in cl) {
        q.x *= kx;
        q.y *= ky;
        q.r *= ky;
      }
      for (var i = 0; i < dx.length; i++) {
        dx[i] *= kx;
        dy[i] *= ky;
      }
      _sz = s;
    }
    _xBg(c, s, const [Color(0xFF070A14), Color(0xFF101828), Color(0xFF1A2233)]);
    fl = math.max(0, fl - dt * 2.6);
    wind.step(dt, 8, 2.5);
    tm -= dt;
    if (tm <= 0) {
      strike(w, h, w * (0.1 + _rnd() * 0.8), h * (0.6 + _rnd() * 0.35));
      tm = 1.1 + _rnd() * 1.5;
    }
    if (tap != null) strike(w, h, tap.dx, math.max(tap.dy, h * 0.3));
    final fk = fl * (0.6 + 0.4 * math.sin(t * 70));
    if (fk > 0.02) {
      c.drawRect(Offset.zero & s, _xFill(Color.fromRGBO(190, 210, 255, fk * 0.16)));
      _glowS(c, Offset(fx, h * 0.1), h * 1.2, const Color(0xFFBFD0FF), fk * 0.6, true);
    }
    final wx = wind.x;
    for (var i = 0; i < dx.length; i++) {
      dy[i] += dv[i] * dt * sc;
      dx[i] += dv[i] * wx * dt * sc;
      if (dy[i] > h) {
        dy[i] = -10;
        dx[i] = _rnd() * (w + 80) - 40;
      }
      final o = i * 4;
      _rain[o] = dx[i];
      _rain[o + 1] = dy[i];
      _rain[o + 2] = dx[i] + wx * 9;
      _rain[o + 3] = dy[i] + 9;
    }
    _rp.color = Color.fromRGBO(190, 210, 255, 0.2 + fk * 0.3);
    if (_rain.isNotEmpty) c.drawRawPoints(ui.PointMode.lines, _rain, _rp);
    final g = ghost;
    if (g != null && bolts.isEmpty) {
      for (final br in g) {
        c.drawPath(br.p, _xLine(const Color.fromRGBO(170, 195, 255, 0.2), 1.6 * br.w));
      }
    }
    final flick = math.sin(t * 90) > -0.3 ? 1.0 : 0.35;
    for (final b in bolts) {
      b.life -= dt;
      final k = _clamp(b.life * 4, 0, 1) * flick;
      for (final br in b.bs) {
        c.drawPath(br.p, _xLine(Color.fromRGBO(140, 170, 255, 0.22 * k), 7 * br.w));
        c.drawPath(br.p, _xLine(Color.fromRGBO(210, 225, 255, 0.95 * k), 2.4 * br.w));
        c.drawPath(br.p, _xLine(Color.fromRGBO(255, 255, 255, k), 1 * br.w));
      }
      _glowS(c, b.end, 30 * sc, _white, k * 0.8, true);
    }
    bolts.removeWhere((b) => b.life <= 0);
    for (final q in sp) {
      q.age += dt;
      q.vy += 420 * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      _glowS(c, Offset(q.x, q.y), 3.5, const Color(0xFFDDE8FF), 1 - q.age / q.life, true);
    }
    sp.removeWhere((q) => q.age >= q.life);
    for (final q in cl) {
      q.x += q.v * dt;
      if (q.x > w + q.r) q.x = -q.r;
      _glowS(c, Offset(q.x, q.y), q.r, const Color(0xFF3A4664), 0.85);
      _glowS(c, Offset(q.x, q.y + q.r * 0.25), q.r * 0.7, const Color(0xFF6A7A9C), 0.22);
      if (fk > 0.02) {
        _glowS(c, Offset(q.x, q.y + q.r * 0.2), q.r * 0.8, const Color(0xFF9FB4FF),
            fk * 0.35 * _clamp(1 - (q.x - fx).abs() / (w * 0.5), 0, 1), true);
      }
    }
  }
}

// ───────────── Чернила ─────────────
// Капли расходятся клубами в вихревом поле без дивергенции; палец размешивает, касание — новая капля.
class _XInkP {
  _XInkP(this.x, this.y, this.vx, this.vy, this.r, this.life, this.c);
  double x, y, vx, vy, r, age = 0;
  final double life;
  final Color c;
}

class _XInk extends CoverSim {
  final List<_XInkP> p = [];
  int ci = 0;
  double tm = 0.2, sc = 1;
  Offset? lp;
  bool _warm = false;
  Size _sz = Size.zero;
  final _XAtlas _at = _XAtlas();
  static const List<Color> _cs = [Color(0xFFFF4FD8), Color(0xFF3DD6FF), Color(0xFFFFB23F), Color(0xFF7A5CFF), Color(0xFF3DFFB2)];

  @override
  void init(Size s) {
    _sz = s;
    sc = _clamp(s.height / 200, 0.55, 1.1);
    for (var i = 0; i < 3; i++) {
      drop(s.width * (0.2 + i * 0.3), s.height * (0.3 + _rnd() * 0.4));
    }
  }

  void drop(double x, double y) {
    final c = _cs[ci++ % 5];
    for (var i = 0; i < 46; i++) {
      final a = _rnd() * _tau, s = math.pow(_rnd(), 0.6).toDouble() * 85 * sc;
      p.add(_XInkP(x, y, math.cos(a) * s, math.sin(a) * s, (7 + _rnd() * 9) * sc, 5 + _rnd() * 4, c));
    }
    if (p.length > 460) p.removeRange(0, p.length - 460);
  }

  void _move(double t, double dt, Offset? pointer, double pvx, double pvy, bool draw) {
    const a = 0.021, b = 0.027;
    final kk = 950 * sc, dr = 1 - dt * 1.4;
    for (final q in p) {
      q.age += dt;
      if (pointer != null) {
        final d = _qHyp(q.x - pointer.dx, q.y - pointer.dy);
        if (d < 60) {
          final k = (1 - d / 60) * dt * 7;
          q.vx += pvx * k;
          q.vy += pvy * k;
        }
      }
      final sx = q.x * a + t * 0.2, sy = q.y * b - t * 0.15;
      final u = -math.sin(sx) * math.sin(sy) * b * kk, v = -math.cos(sx) * math.cos(sy) * a * kk;
      q.vx *= dr;
      q.vy *= dr;
      q.x += (q.vx + u) * dt;
      q.y += (q.vy + v - 3) * dt;
      q.r += 3.2 * dt * sc;
      if (draw) _at.add(q.x, q.y, q.r, q.c, math.sin(math.min(1.0, q.age / q.life) * math.pi) * 0.2);
    }
    p.removeWhere((q) => q.age >= q.life);
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final w = s.width, h = s.height;
    if (s != _sz) {
      for (final q in p) {
        q.x *= w / _sz.width;
        q.y *= h / _sz.height;
      }
      _sz = s;
    }
    if (!_warm) {
      // Прогрев 1.2 с: в первом кадре капли уже раскрылись (в момент
      // рождения они прозрачны).
      _warm = true;
      for (var k = 0; k < 72; k++) {
        _move(t - (72 - k) / 60, 1 / 60, null, 0, 0, false);
      }
    }
    _xBg(c, s, const [Color(0xFF05070F), Color(0xFF0A1020)]);
    tm -= dt;
    if (tm <= 0) {
      drop(w * (0.1 + _rnd() * 0.8), h * (0.2 + _rnd() * 0.6));
      tm = 2 + _rnd() * 1.5;
    }
    if (tap != null) drop(tap.dx, tap.dy);
    final last = lp;
    final pvx = pointer != null && last != null ? _clamp((pointer.dx - last.dx) / math.max(dt, 0.008), -700, 700) : 0.0;
    final pvy = pointer != null && last != null ? _clamp((pointer.dy - last.dy) / math.max(dt, 0.008), -700, 700) : 0.0;
    _move(t, dt, pointer, pvx, pvy, true);
    _at.flush(c, true);
    lp = pointer;
  }
}

// ───────────── Гиперпрыжок ─────────────
// Звёзды летят от портрета; пока палец на обложке — разгон, касание — прыжок со вспышкой.
class _XWarp extends CoverSim {
  final Spring sp = Spring(1);
  double fl = 0;
  final List<double> rg = [];
  Float64List a = Float64List(0), d = Float64List(0), z = Float64List(0);
  List<Color> col = const [];
  ui.Gradient? _bg;
  double _bx = -1, _by = -1, _bm = -1;

  @override
  void init(Size s) {
    final n = _clamp(s.width * 0.7, 160, 300).round();
    a = Float64List(n);
    d = Float64List(n);
    z = Float64List(n);
    col = List<Color>.generate(n, (i) {
      a[i] = _rnd() * _tau;
      d[i] = _rnd();
      z[i] = 0.5 + _rnd();
      return _rnd() < 0.3 ? const Color(0xFF9AD8FF) : (_rnd() < 0.5 ? const Color(0xFFD9BFFF) : _white);
    });
  }

  @override
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer) {
    final cx = av.dx, cy = av.dy, m = math.sqrt(s.width * s.width + s.height * s.height) / 2;
    if (_bg == null || cx != _bx || cy != _by || m != _bm) {
      _bx = cx;
      _by = cy;
      _bm = m;
      _bg = ui.Gradient.radial(av, m, const [Color(0xFF141A4A), Color(0xFF090B22), Color(0xFF030308)], const [0.0, 0.5, 1.0]);
    }
    c.drawRect(Offset.zero & s, _xFill(_white)..shader = _bg);
    if (tap != null) {
      sp.v += 16;
      fl = 1;
      rg.add(0);
    }
    sp.t = pointer != null ? 3.4 : 1;
    sp.step(dt, 30, 6);
    fl = math.max(0, fl - dt * 2.2);
    final k = math.max(0.2, sp.x);
    final pl = _xLine(_white, 1, StrokeCap.round, StrokeJoin.round, BlendMode.plus);
    for (var i = 0; i < a.length; i++) {
      d[i] += dt * (0.1 + 0.55 * d[i]) * z[i] * k;
      if (d[i] > 1.1) {
        d[i] = 0.04 + _rnd() * 0.1;
        a[i] = _rnd() * _tau;
      }
      final ux = math.cos(a[i]), uy = math.sin(a[i]) * 0.62, len = (0.006 + 0.05 * d[i]) * k * z[i], d0 = math.max(0.03, d[i] - len);
      pl
        ..color = _op(col[i], _clamp(d[i] * 1.4, 0, 1))
        ..strokeWidth = 0.5 + d[i] * 1.7;
      c.drawLine(Offset(cx + ux * d0 * m, cy + uy * d0 * m), Offset(cx + ux * d[i] * m, cy + uy * d[i] * m), pl);
    }
    for (var i = 0; i < rg.length; i++) {
      rg[i] += dt * 1.3;
      final r = rg[i];
      c.drawOval(_ov(cx, cy, r * m, r * m * 0.62),
          _xLine(_op(const Color(0xFFBFD0FF), (1 - r) * 0.7), 2 + r * 6, StrokeCap.round, StrokeJoin.round, BlendMode.plus));
    }
    rg.removeWhere((r) => r >= 1);
    _glowS(c, av, m * (0.3 + fl * 0.6), const Color(0xFF9FB4FF), 0.3 + fl * 0.7, true);
  }
}
