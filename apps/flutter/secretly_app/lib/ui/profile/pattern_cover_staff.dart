// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Третья волна обложек-узоров (макет «Covers», 23.11.2026): десять для
/// сотрудников — «Шампанское», «Камни», «Парфюм», «Макаруны», «Часы»,
/// «Механизм», «Армиллярная сфера», «Металлическая карта», «Гран-при»,
/// «Подарки» — и десять новогодних: «Ёлочные шары», «Снежинки»,
/// «Снеговики», «Мандарины», «Пряничные человечки», «Бенгальские огни»,
/// «Колокольчики», «Какао», «Ёлочки», «Снежные шары».
///
/// Движение то же, что у прежних узоров ([PatternCoverInput], шесть полос
/// [PatternCoverBands], кадр [PatternExtraFrame]): тянешь — расходятся,
/// раскрыл фото — разлетаются и гаснут, прокрутка — стягиваются к аватару;
/// ниже линии кнопок узор гаснет, под именем — прозрачнее.
///
/// Раскладка — как `build()` макета (генератор с началом 11): три кольца
/// r 92/136/180 по 6/9/12 наклеек (размер 30/27/24, прозрачность 1/0,88/0,7)
/// и искорка между соседними; у «Гран-при» 3/4/5 машинок, быстрее и без
/// искорок; новогодние — ещё 46 падающих снежинок. «Механизм» и
/// «Армиллярная сфера» — не наклейки, а тонкие линии вокруг аватара.
///
/// У каждой обложки свой глубокий фон ([patternCoverOwnTint]) — его рисует
/// [PatternCoverBackdrop] вместо подсветки из цвета аватара.
///
/// Скорость (Xiaomi 120 Гц, iPhone). Без `saveLayer` и без `clipPath`:
/// вырезы макета (вино в бокале, жидкость во флаконе, блик карты) считаются
/// отсечением выпуклого многоугольника, неподвижные (тень снеговика, поры
/// мандарина, полоса на шаре) — один раз через `Path.combine`. Все
/// неподвижные контуры, градиенты и пунктиры строятся один раз; за кадр —
/// только движущиеся части в переиспользуемые `Path` и `Paint`. Наклейка с
/// прозрачностью < 0,01 пропускается до любого рисования. Линии механизма,
/// сферы и трасс собираются по уровням прозрачности — десятки вызовов
/// вместо сотен.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'pattern_cover.dart';
import 'pattern_cover_extra.dart' show PatternExtraFrame;

// ── Наборы (для каталога) ─────────────────────────────────────────────────

/// Десять обложек для сотрудников — в порядке макета.
const Set<PatternCoverStyle> kStaffPatternCoverStyles = {
  PatternCoverStyle.champagne,
  PatternCoverStyle.gems,
  PatternCoverStyle.perfume,
  PatternCoverStyle.macarons,
  PatternCoverStyle.watches,
  PatternCoverStyle.movement,
  PatternCoverStyle.armillary,
  PatternCoverStyle.cards,
  PatternCoverStyle.gifts,
};

/// Десять новогодних обложек — в порядке макета.
const Set<PatternCoverStyle> kNewYearPatternCoverStyles = {
  PatternCoverStyle.ornaments,
  PatternCoverStyle.snowflakes,
  PatternCoverStyle.snowman,
  PatternCoverStyle.tangerines,
  PatternCoverStyle.gingerbread,
  PatternCoverStyle.sparkler,
  PatternCoverStyle.bells,
  PatternCoverStyle.cocoa,
  PatternCoverStyle.tree,
  PatternCoverStyle.snowglobe,
};

// ── Палитра (макет `PAL`) ─────────────────────────────────────────────────

class _Pal {
  const _Pal(this.tint, this.ink, this.acc);

  /// Глубокий фон вокруг аватара.
  final Color tint;

  /// Цвет снега, искорок и линий.
  final Color ink;

  /// Акцент (бусина сферы, камни механизма).
  final Color acc;
}

const Map<PatternCoverStyle, (_Pal, _Pal)> _kPal = {
  PatternCoverStyle.champagne: (
    _Pal(Color(0xFF1D2C29), Color(0xFFFFFFFF), Color(0xFFF7D98A)),
    _Pal(Color(0xFFE1EBE6), Color(0xFF5E6A66), Color(0xFFE9C566)),
  ),
  PatternCoverStyle.gems: (
    _Pal(Color(0xFF151A2C), Color(0xFFFFFFFF), Color(0xFF4472E6)),
    _Pal(Color(0xFFE1E5F1), Color(0xFF5E6478), Color(0xFF2FB97A)),
  ),
  PatternCoverStyle.perfume: (
    _Pal(Color(0xFF2B1B25), Color(0xFFFFFFFF), Color(0xFFF7A8C4)),
    _Pal(Color(0xFFF1E2E8), Color(0xFF6E5A64), Color(0xFFB9A2FF)),
  ),
  PatternCoverStyle.macarons: (
    _Pal(Color(0xFF2A211F), Color(0xFFFFFFFF), Color(0xFFBFE3A0)),
    _Pal(Color(0xFFF3E8E1), Color(0xFF6E5F58), Color(0xFFF7A1BE)),
  ),
  PatternCoverStyle.watches: (
    _Pal(Color(0xFF1A2126), Color(0xFFFFFFFF), Color(0xFF9A5A32)),
    _Pal(Color(0xFFE3E8EB), Color(0xFF5A646C), Color(0xFF1F4D3A)),
  ),
  PatternCoverStyle.movement: (
    _Pal(Color(0xFF1B1E23), Color(0xFFBCC5CF), Color(0xFFD2354F)),
    _Pal(Color(0xFFE2E5E9), Color(0xFF47515D), Color(0xFFB3243E)),
  ),
  PatternCoverStyle.armillary: (
    _Pal(Color(0xFF12292A), Color(0xFFA9D0C1), Color(0xFFCC8B5C)),
    _Pal(Color(0xFFDAE9E3), Color(0xFF2C6A5C), Color(0xFF9C5C31)),
  ),
  PatternCoverStyle.cards: (
    _Pal(Color(0xFF141518), Color(0xFFFFFFFF), Color(0xFF7E848C)),
    _Pal(Color(0xFFE5E5E8), Color(0xFF5E6066), Color(0xFF1A1C21)),
  ),
  PatternCoverStyle.gifts: (
    _Pal(Color(0xFF2A1419), Color(0xFFFFFFFF), Color(0xFF1F5E45)),
    _Pal(Color(0xFFF2E1E4), Color(0xFF6E5A5E), Color(0xFF6E1C2C)),
  ),
  PatternCoverStyle.ornaments: (
    _Pal(Color(0xFF14213A), Color(0xFFFFFFFF), Color(0xFFD2303F)),
    _Pal(Color(0xFFE3E9F3), Color(0xFF8497AE), Color(0xFFD2303F)),
  ),
  PatternCoverStyle.snowflakes: (
    _Pal(Color(0xFF0F2136), Color(0xFFFFFFFF), Color(0xFFEAF6FF)),
    _Pal(Color(0xFFE2ECF5), Color(0xFF8497AE), Color(0xFFEAF6FF)),
  ),
  PatternCoverStyle.snowman: (
    _Pal(Color(0xFF16243A), Color(0xFFFFFFFF), Color(0xFFD2303F)),
    _Pal(Color(0xFFE6EEF6), Color(0xFF8497AE), Color(0xFFD2303F)),
  ),
  PatternCoverStyle.tangerines: (
    _Pal(Color(0xFF1E2A22), Color(0xFFFFFFFF), Color(0xFFF5962A)),
    _Pal(Color(0xFFEEF0E6), Color(0xFF8497AE), Color(0xFFF5962A)),
  ),
  PatternCoverStyle.gingerbread: (
    _Pal(Color(0xFF2A1D18), Color(0xFFFFFFFF), Color(0xFFC47D3E)),
    _Pal(Color(0xFFF3E9E0), Color(0xFF8497AE), Color(0xFFC47D3E)),
  ),
  PatternCoverStyle.sparkler: (
    _Pal(Color(0xFF141826), Color(0xFFFFFFFF), Color(0xFFFFC857)),
    _Pal(Color(0xFFE5E7EE), Color(0xFF8497AE), Color(0xFFFFC857)),
  ),
  PatternCoverStyle.bells: (
    _Pal(Color(0xFF2A1218), Color(0xFFFFFFFF), Color(0xFF2F8F4E)),
    _Pal(Color(0xFFF2E2E5), Color(0xFF8497AE), Color(0xFF2F8F4E)),
  ),
  PatternCoverStyle.cocoa: (
    _Pal(Color(0xFF24191A), Color(0xFFFFFFFF), Color(0xFF6B3F2A)),
    _Pal(Color(0xFFF2E8E4), Color(0xFF8497AE), Color(0xFF6B3F2A)),
  ),
  PatternCoverStyle.tree: (
    _Pal(Color(0xFF10261C), Color(0xFFFFFFFF), Color(0xFF2E8B57)),
    _Pal(Color(0xFFE1ECE5), Color(0xFF8497AE), Color(0xFF2E8B57)),
  ),
  PatternCoverStyle.snowglobe: (
    _Pal(Color(0xFF151F33), Color(0xFFFFFFFF), Color(0xFFC8283C)),
    _Pal(Color(0xFFE3E8F2), Color(0xFF8497AE), Color(0xFFC8283C)),
  ),
};

_Pal? _palOf(PatternCoverStyle s, bool dark) {
  final p = _kPal[s];
  if (p == null) return null;
  return dark ? p.$1 : p.$2;
}

/// Свой глубокий фон обложки (макет `applyTint`: цвет вокруг аватара,
/// переходящий в цвет страницы). `null` — у прежних узоров: им подсветка
/// из цвета аватара ([patternCoverTint]).
Color? patternCoverOwnTint(PatternCoverStyle s, ui.Brightness b) =>
    _palOf(s, b == ui.Brightness.dark)?.tint;

// ── Раскладка (макет `build()`, генератор с началом 11) ───────────────────

/// Сколько вариантов рисунка у наклеек (макет `STK`); 0 — не наклейки.
int _variants(PatternCoverStyle s) => switch (s) {
  PatternCoverStyle.champagne => 1,
  PatternCoverStyle.gems => 4,
  PatternCoverStyle.perfume => 4,
  PatternCoverStyle.macarons => 5,
  PatternCoverStyle.watches => 4,
  PatternCoverStyle.cards => 4,
  PatternCoverStyle.gifts => 4,
  PatternCoverStyle.ornaments => 4,
  PatternCoverStyle.snowflakes => 3,
  PatternCoverStyle.snowman => 3,
  PatternCoverStyle.tangerines => 2,
  PatternCoverStyle.gingerbread => 1,
  PatternCoverStyle.sparkler => 1,
  PatternCoverStyle.bells => 3,
  PatternCoverStyle.cocoa => 3,
  PatternCoverStyle.tree => 1,
  PatternCoverStyle.snowglobe => 2,
  _ => 0,
};

class _It {
  const _It(
    this.band,
    this.a,
    this.r,
    this.sz,
    this.al,
    this.sp,
    this.ph,
    this.rot,
    this.c,
    this.tz,
    this.spark,
  );

  final int band;

  /// Угол на кольце, радиус, размер, прозрачность, скорость, фаза, наклон.
  final double a, r, sz, al, sp, ph, rot;

  /// Вариант рисунка и сдвиг часового пояса (часы).
  final int c, tz;

  /// Искорка между наклейками.
  final bool spark;
}

class _Flake {
  const _Flake(this.x0, this.y0, this.r, this.sp, this.ph, this.a);
  final double x0, y0, r, sp, ph, a;
}

class _Lay {
  const _Lay(this.items, this.snow);
  final List<_It> items;
  final List<_Flake> snow;
}

final Map<PatternCoverStyle, _Lay> _lays = {};

_Lay _layOf(PatternCoverStyle s) => _lays.putIfAbsent(s, () => _buildLay(s));

_Lay _buildLay(PatternCoverStyle s) {
  var seed = 11;
  double rnd() {
    seed = (seed * 16807) % 2147483647;
    return seed / 2147483647;
  }

  final items = <_It>[];
  final snow = <_Flake>[];
  final nv = _variants(s);
  if (nv > 0) {
    const rings = [
      (92.0, 6, 30.0, 1.0),
      (136.0, 9, 27.0, 0.88),
      (180.0, 12, 24.0, 0.7),
    ];
    for (var i = 0; i < rings.length; i++) {
      final (r, n, sz, al) = rings[i];
      final step = math.pi * 2 / n;
      final sp = (i.isOdd ? -1 : 1) * 0.03;
      for (var k = 0; k < n; k++) {
        final ph = rnd() * 6.283;
        final rot = (rnd() - 0.5) * 0.5;
        items.add(
          _It(
            i * 2,
            k * step + i * 0.35,
            r,
            sz,
            al,
            sp,
            ph,
            rot,
            (k + i) % nv,
            (k * 5 + i * 3) % 12,
            false,
          ),
        );
        final sr = r + (rnd() - 0.5) * 14;
        final ssz = 7 + rnd() * 3;
        final sph = rnd() * 6;
        items.add(
          _It(
            i * 2,
            (k + 0.5) * step + i * 0.35,
            sr,
            ssz,
            0,
            sp,
            sph,
            0,
            0,
            0,
            true,
          ),
        );
      }
    }
    if (kNewYearPatternCoverStyles.contains(s)) {
      for (var k = 0; k < 46; k++) {
        final x0 = rnd() * 390;
        final y0 = rnd() * 500;
        final r = 0.8 + rnd() * 1.8;
        final sp = 8 + rnd() * 14;
        final ph = rnd() * 6;
        final a = 0.25 + rnd() * 0.35;
        snow.add(_Flake(x0, y0, r, sp, ph, a));
      }
    }
  }
  return _Lay(List<_It>.unmodifiable(items), List<_Flake>.unmodifiable(snow));
}

// ── Общие помощники ───────────────────────────────────────────────────────

const double _pi = math.pi;
const Color _white = Color(0xFFFFFFFF);

double _cl(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

/// Плавный вход-выход (макет `ez`).
double _ez(double u) =>
    u < 0.5 ? 4 * u * u * u : 1 - math.pow(-2 * u + 2, 3).toDouble() / 2;

/// Свой цикл наклейки длиной [per] секунд, со сдвигом фазы (макет `cyc`).
double _cyc(double t, double ph, double per) {
  final v = (t + ph * per / 6.283) % per;
  return v < 0 ? v + per : v;
}

/// Смесь цветов по каналам с округлением (макет `mix`).
Color _mix(Color a, Color b, double k) {
  int ch(double x, double y) {
    final xa = (x * 255).round(), ya = (y * 255).round();
    return (xa + (ya - xa) * k).round().clamp(0, 255);
  }

  return Color.fromARGB(255, ch(a.r, b.r), ch(a.g, b.g), ch(a.b, b.b));
}

/// Под именем узор прозрачнее (макет `tg`).
double _tg(PatternExtraFrame f, double x, double y) {
  final hx = 1 - (x - f.cx).abs() / 130;
  if (hx <= 0) return 1;
  final hy = _cl(1 - ((y - (f.nameY + 22)).abs() - 26) / 22);
  return 1 - 0.7 * hx * hy;
}

/// Видимость линии с пустым кольцом радиуса [r0] вокруг аватара (макет `vis`).
double _vis(PatternExtraFrame f, double x, double y, double a, double r0) {
  final dx = x - f.cx, dy = y - f.cy;
  return a *
      f.ga *
      f.fy(y) *
      _tg(f, x, y) *
      _cl((math.sqrt(dx * dx + dy * dy) - r0) / 30);
}

// ── Холст наклейки: прозрачность, кисти, временные контуры ────────────────

late Canvas _c;

/// Прозрачность текущей наклейки (макет `globalAlpha`).
double _ga = 1;

final Paint _fill = Paint()..isAntiAlias = true;
final Paint _line = Paint()
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = true;

/// Временные контуры движущихся частей: за кадр только `reset()`.
final Path _tmp = Path();
final Path _tmp2 = Path();
final Path _tmp3 = Path();

Color _op(Color c, double k) => c.withValues(alpha: c.a * (k > 1 ? 1 : k));

void _f(Path p, Color c, [double k = 1]) {
  _fill.color = _op(c, _ga * k);
  _c.drawPath(p, _fill);
}

void _s(Path p, Color c, double w, [double k = 1]) {
  _line
    ..color = _op(c, _ga * k)
    ..strokeWidth = w;
  _c.drawPath(p, _line);
}

/// Заливка и обводка одного контура (макет `L`).
void _fs(Path p, Color fill, Color line, [double w = 5]) {
  _f(p, fill);
  _s(p, line, w);
}

void _dot(double x, double y, double r, Color c, [double k = 1]) {
  _fill.color = _op(c, _ga * k);
  _c.drawCircle(Offset(x, y), r, _fill);
}

void _ring(double x, double y, double r, Color c, double w, [double k = 1]) {
  _line
    ..color = _op(c, _ga * k)
    ..strokeWidth = w;
  _c.drawCircle(Offset(x, y), r, _line);
}

void _disc(double x, double y, double r, Color fill, Color line, double w) {
  _dot(x, y, r, fill);
  _ring(x, y, r, line, w);
}

void _seg(
  double x0,
  double y0,
  double x1,
  double y1,
  Color c,
  double w, [
  double k = 1,
]) {
  _line
    ..color = _op(c, _ga * k)
    ..strokeWidth = w;
  _c.drawLine(Offset(x0, y0), Offset(x1, y1), _line);
}

/// Заливка градиентом (готовым, в единицах наклейки).
void _shade(Path p, Shader sh, [double k = 1]) {
  _fill
    ..shader = sh
    ..color = _op(_white, _ga * k);
  _c.drawPath(p, _fill);
  _fill.shader = null;
}

/// Блик (макет `shine`): белый овал, прозрачность [k].
void _shine(Path p, [double k = 0.55]) => _f(p, _white, k);

/// Четырёхлучевая вспышка с вогнутыми сторонами (макет `star`).
final Path _starUnit = Path()
  ..moveTo(0, -1)
  ..quadraticBezierTo(0, 0, 1, 0)
  ..quadraticBezierTo(0, 0, 0, 1)
  ..quadraticBezierTo(0, 0, -1, 0)
  ..quadraticBezierTo(0, 0, 0, -1)
  ..close();

void _star(double x, double y, double sz, double a) {
  if (a <= 0.01) return;
  _c.save();
  _c.translate(x, y);
  _c.scale(sz);
  _fill.color = _op(_white, _ga * (a > 1 ? 1 : a));
  _c.drawPath(_starUnit, _fill);
  _c.restore();
}

// ── Построение неподвижных контуров (один раз) ────────────────────────────

Float64List _affine(double tx, double ty, [double rot = 0]) {
  final c = math.cos(rot), s = math.sin(rot);
  return Float64List.fromList([
    c,
    s,
    0,
    0,
    -s,
    c,
    0,
    0,
    0,
    0,
    1,
    0,
    tx,
    ty,
    0,
    1,
  ]);
}

/// Эллипс с центром (x, y), полуосями rx/ry, повёрнутый на [rot].
Path _ell(double x, double y, double rx, double ry, [double rot = 0]) {
  final p = Path()
    ..addOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
    );
  return p.transform(_affine(x, y, rot));
}

Path _circle(double x, double y, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

Path _rr(double x, double y, double w, double h, double r) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
  );

Path _rect(double x, double y, double w, double h) =>
    Path()..addRect(Rect.fromLTWH(x, y, w, h));

Path _poly(List<double> xy) {
  final p = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i + 1 < xy.length; i += 2) {
    p.lineTo(xy[i], xy[i + 1]);
  }
  return p..close();
}

Path _and(Path a, Path b) => Path.combine(PathOperation.intersect, a, b);

/// Пунктир [on]/[off] по контуру (макет `setLineDash`).
Path _dash(Path src, double on, double off) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, math.min(d + on, m.length)), Offset.zero);
      d += on + off;
    }
  }
  return out;
}

/// Многоугольник из кубических кривых (точки x, y подряд; первая — начало
/// первой кривой, замыкание — неявное).
Float64List _cubicPoly(List<List<double>> cubics, int steps) {
  final out = <double>[cubics.first[0], cubics.first[1]];
  for (final c in cubics) {
    for (var i = 1; i <= steps; i++) {
      final u = i / steps, v = 1 - u;
      final a = v * v * v, b = 3 * v * v * u, cc = 3 * v * u * u, d = u * u * u;
      out
        ..add(a * c[0] + b * c[2] + cc * c[4] + d * c[6])
        ..add(a * c[1] + b * c[3] + cc * c[5] + d * c[7]);
    }
  }
  return Float64List.fromList(out);
}

/// Скруглённый прямоугольник как выпуклый многоугольник (по [seg] отрезков
/// на угол).
Float64List _rrectPoly(
  double x,
  double y,
  double w,
  double h,
  double r,
  int seg,
) {
  final out = <double>[];
  void corner(double ccx, double ccy, double a0) {
    for (var i = 0; i <= seg; i++) {
      final a = a0 + i / seg * _pi / 2;
      out
        ..add(ccx + math.cos(a) * r)
        ..add(ccy + math.sin(a) * r);
    }
  }

  corner(x + w - r, y + r, -_pi / 2);
  corner(x + w - r, y + h - r, 0);
  corner(x + r, y + h - r, _pi / 2);
  corner(x + r, y + r, _pi);
  return Float64List.fromList(out);
}

// ── Отсечение выпуклого многоугольника (вместо clipPath) ──────────────────

final Float64List _bufA = Float64List(512);
final Float64List _bufB = Float64List(512);

/// Точки, где край отсечения пересёк многоугольник (для линии поверхности).
final Float64List _cut = Float64List(8);
int _cutN = 0;

/// Оставляет часть выпуклого многоугольника [src] ([n] точек), лежащую
/// справа по ходу прямой P→Q на экране (y вниз): `(Q−P)×(X−P) ≥ 0`.
int _clipEdge(
  Float64List src,
  int n,
  Float64List dst,
  double px,
  double py,
  double qx,
  double qy,
) {
  final ex = qx - px, ey = qy - py;
  var m = 0;
  _cutN = 0;
  var sx = src[(n - 1) * 2], sy = src[(n - 1) * 2 + 1];
  var ss = ex * (sy - py) - ey * (sx - px);
  for (var i = 0; i < n; i++) {
    final x = src[i * 2], y = src[i * 2 + 1];
    final s = ex * (y - py) - ey * (x - px);
    if ((s >= 0) != (ss >= 0)) {
      final u = ss / (ss - s);
      final ix = sx + (x - sx) * u, iy = sy + (y - sy) * u;
      dst[m * 2] = ix;
      dst[m * 2 + 1] = iy;
      m++;
      if (_cutN < 4) {
        _cut[_cutN * 2] = ix;
        _cut[_cutN * 2 + 1] = iy;
        _cutN++;
      }
    }
    if (s >= 0) {
      dst[m * 2] = x;
      dst[m * 2 + 1] = y;
      m++;
    }
    sx = x;
    sy = y;
    ss = s;
  }
  return m;
}

/// Точка внутри выпуклого многоугольника.
bool _inside(Float64List poly, double x, double y) {
  final n = poly.length ~/ 2;
  var pos = false, neg = false;
  for (var i = 0; i < n; i++) {
    final j = (i + 1) % n;
    final ax = poly[i * 2], ay = poly[i * 2 + 1];
    final cr =
        (poly[j * 2] - ax) * (y - ay) - (poly[j * 2 + 1] - ay) * (x - ax);
    if (cr > 0) pos = true;
    if (cr < 0) neg = true;
    if (pos && neg) return false;
  }
  return true;
}

/// Многоугольник из буфера → во временный контур [_tmp].
void _polyPath(Float64List buf, int n) {
  _tmp
    ..reset()
    ..moveTo(buf[0], buf[1]);
  for (var i = 1; i < n; i++) {
    _tmp.lineTo(buf[i * 2], buf[i * 2 + 1]);
  }
  _tmp.close();
}

// ── Линии по уровням прозрачности (механизм, сфера, трассы) ───────────────

const int _kQ = 127;

/// Отрезки с разной прозрачностью собираются в контуры по уровню (шаг 1/127)
/// и рисуются одним вызовом на уровень — вместо вызова на каждые три
/// отрезка, как в макете. Подряд идущие отрезки одного уровня — одна
/// ломаная (без «бусин» на стыках).
class _Lines {
  final List<Path> _p = List<Path>.generate(_kQ + 1, (_) => Path());
  final Float64List _lx = Float64List(_kQ + 1);
  final Float64List _ly = Float64List(_kQ + 1);
  final Uint8List _on = Uint8List(_kQ + 1);
  final Int32List _used = Int32List(_kQ + 1);
  int _n = 0;
  Color _col = _white;
  double _w = 1;

  void begin(Color col, double w) {
    if (col == _col && w == _w) return;
    flush();
    _col = col;
    _w = w;
  }

  void seg(double x0, double y0, double x1, double y1, double a) {
    if (a < 0.004) return;
    var q = (a * _kQ).round();
    if (q < 1) q = 1;
    if (q > _kQ) q = _kQ;
    final p = _p[q];
    if (_on[q] == 0) {
      _on[q] = 1;
      _used[_n++] = q;
      p.moveTo(x0, y0);
    } else if (_lx[q] != x0 || _ly[q] != y0) {
      p.moveTo(x0, y0);
    }
    p.lineTo(x1, y1);
    _lx[q] = x1;
    _ly[q] = y1;
  }

  void flush() {
    if (_n == 0) return;
    _line.strokeWidth = _w;
    for (var i = 0; i < _n; i++) {
      final q = _used[i];
      _line.color = _col.withValues(alpha: _col.a * q / _kQ);
      _c.drawPath(_p[q], _line);
      _p[q].reset();
      _on[q] = 0;
    }
    _n = 0;
  }
}

final _Lines _lines = _Lines();

/// Ломаная из буфера [_bufA] ([count] точек) — тройками отрезков с
/// прозрачностью по середине тройки (макет `poly`).
void _polyLine(
  PatternExtraFrame f,
  int count,
  double a,
  double lw,
  Color col,
  double r0,
) {
  _lines.begin(col, lw);
  for (var i = 0; i < count - 1; i += 3) {
    final j = math.min(count - 1, i + 3), m = (i + j) >> 1;
    final al = _vis(f, _bufA[m * 2], _bufA[m * 2 + 1], a, r0);
    if (al < 0.004) continue;
    for (var k = i + 1; k <= j; k++) {
      _lines.seg(
        _bufA[(k - 1) * 2],
        _bufA[(k - 1) * 2 + 1],
        _bufA[k * 2],
        _bufA[k * 2 + 1],
        al,
      );
    }
  }
}

/// Окружность в координатах от аватара, каждая точка — со своей полосой
/// растяжения (макет `circ` + `map`).
void _circLine(
  PatternExtraFrame f,
  double lx,
  double ly,
  double r,
  double a,
  double lw,
  Color col,
  int n,
  double r0,
) {
  for (var k = 0; k <= n; k++) {
    final q = k / n * _pi * 2;
    final px = lx + math.cos(q) * r, py = ly + math.sin(q) * r;
    final b = f.band(math.sqrt(px * px + py * py));
    _bufA[k * 2] = f.cx + px * b;
    _bufA[k * 2 + 1] = f.cy + py * b;
  }
  _polyLine(f, n + 1, a, lw, col, r0);
}

// ── Рисование ─────────────────────────────────────────────────────────────

/// Рисует узор третьей волны. Холст уже в координатах макета (ширина 390).
void paintPatternCoverStaff(
  Canvas canvas,
  PatternCoverStyle style,
  PatternExtraFrame f,
) {
  final pal = _palOf(style, f.dark);
  if (pal == null) return;
  _c = canvas;
  _ga = 1;
  switch (style) {
    case PatternCoverStyle.armillary:
      _paintArmillary(f, pal);
    case PatternCoverStyle.movement:
      _paintMovement(f, pal);
    default:
      _paintStickers(style, f, pal);
  }
  _lines.flush();
}

void _paintStickers(PatternCoverStyle style, PatternExtraFrame f, _Pal pal) {
  final lay = _layOf(style);
  final t = f.t, cx = f.cx, cy = f.cy, ink = pal.ink;

  // Снег новогодних: не растягивается, гаснет ниже линии кнопок.
  for (final fl in lay.snow) {
    final y = ((fl.y0 + t * fl.sp) % 500) - 20;
    final al = f.ga * f.fy(y) * fl.a;
    if (al < 0.01) continue;
    final x = fl.x0 + math.sin(t * 0.6 + fl.ph) * 10;
    _fill.color = _op(ink, al);
    _c.drawCircle(Offset(x, y), fl.r, _fill);
  }

  if (style == PatternCoverStyle.watches) {
    final d = DateTime.now();
    _wSec = d.second + d.millisecond / 1000;
    _wMin = d.minute + _wSec / 60;
    _wHour = d.hour;
  }

  for (final it in lay.items) {
    final b = f.bands[it.band];
    final a = it.a + t * it.sp, rr = it.r * b;
    final x = cx + math.cos(a) * rr;
    final y = cy + math.sin(a) * rr * 0.94;
    if (it.spark) {
      final tw = 0.5 + 0.5 * math.sin(t * 1.6 + it.ph);
      final al = 0.26 * tw * f.ga * f.fy(y) * _tg(f, x, y);
      if (al <= 0.01) continue;
      final q = it.sz * (0.7 + 0.3 * tw) / 2;
      _c.save();
      _c.translate(x, y);
      _c.scale(q);
      _fill.color = _op(ink, al);
      _c.drawPath(_starUnit, _fill);
      _c.restore();
      continue;
    }
    // Прозрачность — до любого рисования: невидимые не рисуются вовсе.
    final al = it.al * f.ga * f.fy(y) * _tg(f, x, y);
    if (al < 0.01) continue;
    final sz = it.sz * (1 + f.p * 0.3);
    _c.save();
    _c.translate(x, y + math.sin(t * 1.2 + it.ph) * 2);
    _c.rotate(it.rot + math.sin(t * 0.7 + it.ph) * 0.12);
    _c.scale(sz / 100);
    _ga = al;
    _sticker(style, it, t, f.dark);
    _ga = 1;
    _c.restore();
  }
}

void _sticker(PatternCoverStyle style, _It it, double t, bool dark) {
  switch (style) {
    case PatternCoverStyle.champagne:
      _champagne(it, t);
    case PatternCoverStyle.gems:
      _gem(it, t);
    case PatternCoverStyle.perfume:
      _perfume(it, t);
    case PatternCoverStyle.macarons:
      _macaron(it, t);
    case PatternCoverStyle.watches:
      _watch(it);
    case PatternCoverStyle.cards:
      _card(it, t);
    case PatternCoverStyle.gifts:
      _gift(it, t);
    case PatternCoverStyle.ornaments:
      _ornament(it, t);
    case PatternCoverStyle.snowflakes:
      _snowflake(it, t);
    case PatternCoverStyle.snowman:
      _snowman(it, t);
    case PatternCoverStyle.tangerines:
      _tangerine(it, t);
    case PatternCoverStyle.gingerbread:
      _gingerbread(it, t);
    case PatternCoverStyle.sparkler:
      _sparkler(it, t, dark);
    case PatternCoverStyle.bells:
      _bell(it, t);
    case PatternCoverStyle.cocoa:
      _cocoa(it, t);
    case PatternCoverStyle.tree:
      _tree(it, t);
    case PatternCoverStyle.snowglobe:
      _snowglobe(it, t);
    default:
      break;
  }
}

// ── Шампанское ────────────────────────────────────────────────────────────

const Color _chO = Color(0xFF26323C);
const Color _chGlass = Color(0xFFE6EFF5);
final Path _chBase = _ell(0, 42, 20, 5);
final Path _chStem = _rr(-3.5, 6, 7, 36, 3);
final Path _chBowl = Path()
  ..moveTo(-38, -24)
  ..cubicTo(-36, 2, -14, 10, 0, 10)
  ..cubicTo(14, 10, 36, 2, 38, -24)
  ..close();
final Float64List _chBowlPoly = _cubicPoly(const [
  [-38, -24, -36, 2, -14, 10, 0, 10],
  [0, 10, 14, 10, 36, 2, 38, -24],
], 16);
final Path _chBand = _and(_chBowl, _rect(-40, 3, 80, 12));
final Path _chRim = _ell(0, -24, 38, 5);
final Path _chShine = _ell(-23, -11, 3.5, 8.5, 0.5);

void _champagne(_It it, double t) {
  final cc = _cyc(t, it.ph, 7);
  final tilt = cc < 0.8 ? math.sin(cc / 0.8 * _pi) * 0.32 : 0.0;
  if (tilt != 0) _c.rotate(tilt);
  _fs(_chBase, _chGlass, _chO, 4);
  _fs(_chStem, _chGlass, _chO, 4);
  _f(_chBowl, const Color.fromRGBO(230, 240, 246, 0.55));
  final lv = -13 + math.sin(t * 2.2 + it.ph) * 1.4;
  final sl = math.tan(tilt), wob = math.sin(t * 3 + it.ph) * 1.2;
  final y1 = lv + 40 * sl + wob, y2 = lv - 40 * sl - wob;
  // Вино — часть чаши ниже поверхности (вместо выреза по чаше).
  final n = _clipEdge(
    _chBowlPoly,
    _chBowlPoly.length ~/ 2,
    _bufA,
    -40,
    y1,
    40,
    y2,
  );
  final cuts = _cutN;
  final c0x = _cut[0], c0y = _cut[1], c1x = _cut[2], c1y = _cut[3];
  if (n >= 3) {
    _polyPath(_bufA, n);
    _f(_tmp, const Color(0xFFF7D98A));
  }
  _f(_chBand, const Color(0xFFE9BE5C), 0.6);
  _tmp.reset();
  var any = false;
  for (var k = 0; k < 6; k++) {
    final bx = -22 + k * 9 + math.sin(t * 3 + k) * 1.5;
    final by = 8 - ((t * 16 + k * 5.3 + it.ph * 7) % 20);
    if (by > lv - bx * sl + 1 && _inside(_chBowlPoly, bx, by)) {
      _tmp.addOval(
        Rect.fromCircle(center: Offset(bx, by), radius: 1.6 + (k % 2) * 0.6),
      );
      any = true;
    }
  }
  if (any) _f(_tmp, const Color(0xFFFFF7DE));
  if (cuts >= 2) _seg(c0x, c0y, c1x, c1y, const Color(0xFFFFF4CC), 2.4);
  _s(_chBowl, _chO, 5);
  _f(_chRim, const Color.fromRGBO(255, 255, 255, 0.28));
  _s(_chRim, _chO, 3.5);
  _shine(_chShine);
  _star(
    30,
    -32,
    13,
    cc > 0.25 && cc < 1 ? math.sin((cc - 0.25) / 0.75 * _pi) : 0,
  );
}

// ── Камни ─────────────────────────────────────────────────────────────────

const List<List<Color>> _gmV = [
  [Color(0xFFFFFFFF), Color(0xFFCFE6F5), Color(0xFF7FA9CC), Color(0xFF30506B)],
  [Color(0xFFB4F5D2), Color(0xFF2FB97A), Color(0xFF0B5E3B), Color(0xFF0A3523)],
  [Color(0xFFC2D6FF), Color(0xFF4472E6), Color(0xFF1B3488), Color(0xFF111E4A)],
  [Color(0xFFFFC0CB), Color(0xFFE0384F), Color(0xFF821226), Color(0xFF420914)],
];
final Path _gmSil = _poly(const [-18, -24, 18, -24, 34, -8, 0, 40, -34, -8]);
final Path _gmTable = _poly(const [-18, -24, 18, -24, 13, -28, -13, -28]);
final Path _gmGirdle = Path()
  ..moveTo(-34, -8)
  ..lineTo(34, -8);

Color _gmShade(List<Color> v, double l) =>
    l > 0.5 ? _mix(v[1], v[0], (l - 0.5) * 2) : _mix(v[2], v[1], l * 2);

void _gem(_It it, double t) {
  final v = _gmV[it.c];
  final rot = t * 0.7 + it.ph;
  const n = 8, step = 2 * _pi / n;
  _f(_gmSil, v[2]);
  for (var k = 0; k < n; k++) {
    final a0 = rot + k * step, a1 = a0 + step, m = (a0 + a1) / 2;
    if (math.sin(m) <= 0) continue;
    final l = 0.5 + 0.5 * math.cos(m - 2.1);
    final c0 = math.cos(a0), c1 = math.cos(a1);
    _tmp
      ..reset()
      ..moveTo(34 * c0, -8)
      ..lineTo(34 * c1, -8)
      ..lineTo(0, 40)
      ..close();
    _f(_tmp, _gmShade(v, l * 0.8));
    _s(_tmp, v[3], 1.2, 0.35);
    _tmp
      ..reset()
      ..moveTo(18 * c0, -24)
      ..lineTo(18 * c1, -24)
      ..lineTo(34 * c1, -8)
      ..lineTo(34 * c0, -8)
      ..close();
    _f(_tmp, _gmShade(v, math.min(1, l * 1.1 + 0.1)));
    _s(_tmp, v[3], 1.2, 0.35);
  }
  _f(_gmTable, v[0]);
  _s(_gmSil, v[3], 5);
  _s(_gmTable, v[3], 3);
  _s(_gmGirdle, v[3], 2.5);
  final cc = _cyc(t, it.ph, 3.4);
  _star(
    12 * math.cos(rot * 1.3),
    -14,
    15,
    cc < 0.55 ? math.sin(cc / 0.55 * _pi) : 0,
  );
  _star(
    -20,
    10,
    7,
    cc > 1.6 && cc < 2.1 ? math.sin((cc - 1.6) / 0.5 * _pi) : 0,
  );
}

// ── Парфюм ────────────────────────────────────────────────────────────────

const Color _pfO = Color(0xFF2A2530);
const List<(Color, Color)> _pfJ = [
  (Color(0xFFF7A8C4), Color(0xFFB8486F)),
  (Color(0xFFF0B46E), Color(0xFF9A5A1F)),
  (Color(0xFFB9A2FF), Color(0xFF5F45B8)),
  (Color(0xFF8EDDD6), Color(0xFF2E8A84)),
];
final Path _pfBottle = _rr(-28, -12, 56, 52, 9);
final Float64List _pfInner = _rrectPoly(-23, -7, 46, 42, 6, 6);
final Path _pfTint = _and(_rr(-23, -7, 46, 42, 6), _rect(8, -10, 20, 50));
final Path _pfShine = _ell(-16, 6, 3, 13);
final Path _pfLabel = _rr(-13, 12, 26, 14, 3);
final Path _pfLabelText = Path()
  ..addRect(const Rect.fromLTWH(-8, 17, 16, 1.6))
  ..addRect(const Rect.fromLTWH(-5, 21, 10, 1.4));
final Path _pfNeck = _rr(-8, -20, 16, 9, 2);
final Path _pfCap = _rr(-15, -48, 30, 29, 6);
final Path _pfCapShine = _ell(-7, -38, 2.4, 7);

void _perfume(_It it, double t) {
  final j = _pfJ[it.c];
  final cc = _cyc(t, it.ph, 5.5);
  final press = cc < 0.25 ? math.sin(cc / 0.25 * _pi) * 3 : 0.0;
  // Облачко аромата — за флаконом.
  if (cc < 1.8) {
    for (var k = 0; k < 12; k++) {
      final u = (cc - k * 0.045) / 1.3;
      if (u < 0 || u > 1) continue;
      _dot(
        -20 - u * 48,
        -38 - u * 8 + math.sin(k * 2.1) * u * 15,
        2 + u * 8,
        j.$1,
        (1 - u) * 0.6,
      );
    }
  }
  _fs(_pfBottle, const Color.fromRGBO(236, 242, 248, 0.55), _pfO);
  final lv = math.sin(t * 1.8 + it.ph) * 1.6;
  final tl = math.sin(t * 1.3 + it.ph) * 0.05;
  final n = _clipEdge(
    _pfInner,
    _pfInner.length ~/ 2,
    _bufA,
    -30,
    lv + 30 * tl,
    30,
    lv - 30 * tl,
  );
  if (n >= 3) {
    _polyPath(_bufA, n);
    _f(_tmp, j.$1);
  }
  _f(_pfTint, j.$2, 0.4);
  _shine(_pfShine, 0.6);
  _fs(_pfLabel, const Color(0xFFFBF7F0), _pfO, 2.5);
  _f(_pfLabelText, _pfO);
  _fs(_pfNeck, const Color(0xFFCDD3DA), _pfO, 4);
  _c.save();
  if (press != 0) _c.translate(0, press);
  _fs(_pfCap, const Color(0xFF1E2228), _pfO, 4);
  _shine(_pfCapShine, 0.45);
  _dot(-15, -38, 2.2, const Color(0xFFCDD3DA));
  _c.restore();
}

// ── Макаруны ──────────────────────────────────────────────────────────────

const List<(Color, Color)> _mcM = [
  (Color(0xFFBFE3A0), Color(0xFF5E8E40)),
  (Color(0xFFF7A1BE), Color(0xFFB5486F)),
  (Color(0xFFCDB8FF), Color(0xFF6A50C0)),
  (Color(0xFFF5E4C0), Color(0xFFA88A4E)),
  (Color(0xFFA5735F), Color(0xFF5A3328)),
];
const Color _mcCreamC = Color(0xFFFFF4E4);
final List<Color> _mcFeetC = [for (final m in _mcM) _mix(m.$1, m.$2, 0.22)];
final List<Color> _mcCreamLine = [
  for (final m in _mcM) _mix(_mcCreamC, m.$2, 0.45),
];
final Path _mcFeet = () {
  final p = Path()..moveTo(-41, 0);
  for (var i = 0; i < 10; i++) {
    p.quadraticBezierTo(-41 + i * 8.2 + 4.1, 6, -41 + (i + 1) * 8.2, 0);
  }
  return p
    ..lineTo(41, -3)
    ..lineTo(-41, -3)
    ..close();
}();
final Path _mcDome = Path()
  ..moveTo(-40, -2)
  ..cubicTo(-40, -28, 40, -28, 40, -2)
  ..close();
final Path _mcShine = _ell(-16, -15, 10, 3.6, -0.15);
final Path _mcCream = _rr(-35, -4, 70, 13, 6.5);

void _macShell(int c, double y, bool flip, double rot) {
  final m = _mcM[c];
  _c.save();
  _c.translate(0, y);
  if (rot != 0) _c.rotate(rot);
  if (flip) _c.scale(1, -1);
  _fs(_mcFeet, _mcFeetC[c], m.$2, 3);
  _fs(_mcDome, m.$1, m.$2, 4.5);
  if (!flip) _shine(_mcShine);
  _c.restore();
}

void _macaron(_It it, double t) {
  final c = it.c;
  final cc = _cyc(t, it.ph, 6);
  final hop = cc < 0.7 ? math.sin(cc / 0.7 * _pi) : 0.0;
  final land = cc > 0.7 && cc < 1.05 ? math.sin((cc - 0.7) / 0.35 * _pi) : 0.0;
  if (land != 0) {
    _c.translate(0, 10);
    _c.scale(1 + 0.08 * land, 1 - 0.1 * land);
    _c.translate(0, -10);
  }
  _macShell(c, 14, true, 0);
  _fs(_mcCream, _mcCreamC, _mcCreamLine[c], 3.5);
  _macShell(c, -6 - hop * 16, false, hop * 0.18 * (c.isOdd ? 1 : -1));
  _star(36, -6, 8, land);
  _star(-34, -2, 6, land * 0.8);
}

// ── Часы ──────────────────────────────────────────────────────────────────

const Color _wO = Color(0xFF2A2F36);
const Color _wSteel = Color(0xFFD7DCE2);
const Color _wRed = Color(0xFFE0384F);
const List<(Color, Color)> _wS = [
  (Color(0xFF2B2B2E), Color(0xFF16181C)),
  (Color(0xFF9A5A32), Color(0xFFF3EFE6)),
  (Color(0xFF22324F), Color(0xFF1E3360)),
  (Color(0xFF2F5A44), Color(0xFF1F4D3A)),
];
final Path _wStraps = Path()
  ..addPath(_rr(-17, -56, 34, 32, 7), Offset.zero)
  ..addPath(_rr(-17, 24, 34, 32, 7), Offset.zero);
final Path _wHoles = _circle(0, 36, 2)..addPath(_circle(0, 44, 2), Offset.zero);
final Path _wCrown = _rr(30, -6, 8, 12, 2);
Path _wTicks(bool major) {
  final p = Path();
  for (var k = 0; k < 12; k++) {
    if ((k % 3 == 0) != major) continue;
    final a = k / 12 * _pi * 2, r1 = major ? 16.0 : 19.0;
    p
      ..moveTo(math.cos(a) * r1, math.sin(a) * r1)
      ..lineTo(math.cos(a) * 22, math.sin(a) * 22);
  }
  return p;
}

final Path _wTicksMajor = _wTicks(true);
final Path _wTicksMinor = _wTicks(false);
final Path _wGlint = Path()
  ..addArc(
    Rect.fromCircle(center: Offset.zero, radius: 20),
    _pi * 1.1,
    _pi * 0.35,
  );

/// Время кадра (одно на все часы): секунды плавные, у каждых часов свой пояс.
double _wSec = 0, _wMin = 0;
int _wHour = 0;

void _hand(double a, double len, double w, Color col, double tail) {
  final q = a - _pi / 2, cq = math.cos(q), sq = math.sin(q);
  _seg(-cq * tail, -sq * tail, cq * len, sq * len, col, w);
}

void _watch(_It it) {
  final s = _wS[it.c];
  final ic = it.c == 1 ? _wO : const Color(0xFFE8ECF0);
  _fs(_wStraps, s.$1, _wO, 4);
  _f(_wHoles, _wO);
  _fs(_wCrown, _wSteel, _wO, 3.5);
  _disc(0, 0, 32, _wSteel, _wO, 5);
  _disc(0, 0, 25, s.$2, const Color(0xFF9AA3AD), 2);
  _s(_wTicksMajor, ic, 3);
  _s(_wTicksMinor, ic, 1.6);
  final hr = (_wHour + it.tz) % 12 + _wMin / 60;
  _hand(hr / 12 * _pi * 2, 11, 3.4, ic, 3);
  _hand(_wMin / 60 * _pi * 2, 17, 2.4, ic, 3);
  _hand(_wSec / 60 * _pi * 2, 21, 1.2, _wRed, 6);
  _dot(0, 0, 2.6, _wRed);
  _s(_wGlint, _white, 4, 0.32);
}

// ── Металлическая карта ───────────────────────────────────────────────────

const List<(Color, Color)> _cdC = [
  (Color(0xFF1A1C21), Color(0xFF3A3E47)),
  (Color(0xFF7E848C), Color(0xFFC3C8CE)),
  (Color(0xFF123227), Color(0xFF2E654F)),
  (Color(0xFF3E1019), Color(0xFF7A2C3F)),
];
final List<Shader> _cdShader = [
  for (final c in _cdC)
    ui.Gradient.linear(
      const Offset(-46, -29),
      const Offset(46, 29),
      [c.$1, c.$2, c.$1],
      const [0, 0.55, 1],
    ),
];
final Path _cdCard = _rr(-46, -29, 92, 58, 8);
final Float64List _cdPoly = _rrectPoly(-46, -29, 92, 58, 8, 6);
final Path _cdChip = _rr(-34, -13, 17, 13, 2.5);
final Path _cdChipLines = Path()
  ..moveTo(-34, -6.5)
  ..lineTo(-17, -6.5)
  ..moveTo(-25.5, -13)
  ..lineTo(-25.5, 0);
final Path _cdWaves = () {
  final p = Path();
  for (final r in const [4.0, 7.5, 11.0]) {
    p.addArc(
      Rect.fromCircle(center: const Offset(-8, -6.5), radius: r),
      -0.7,
      1.4,
    );
  }
  return p;
}();
final Path _cdDigits = () {
  final p = Path();
  for (var gi = 0; gi < 4; gi++) {
    for (var di = 0; di < 4; di++) {
      p.addOval(
        Rect.fromCircle(
          center: Offset(-33 + gi * 18 + di * 3.4, 12),
          radius: 1.15,
        ),
      );
    }
  }
  return p;
}();
final Path _cdName = _rect(-33, 19, 22, 1.6);
final Path _cdStripe = _rect(-46, -19, 92, 12);
final Path _cdSign = _rr(-36, 2, 50, 9, 2);
final Path _cdCvv = _rect(20, 4, 14, 5);
final Path _cdEdge = _rr(-43, -26, 86, 52, 6);

void _card(_It it, double t) {
  final cc = _cyc(t, it.ph, 6.5);
  final phi = cc < 1.2 ? _ez(cc / 1.2) * _pi * 2 : 0.0;
  final sx = math.cos(phi);
  final back = sx < 0;
  _c.scale(math.max(0.04, sx.abs()), 1 + 0.05 * math.sin(phi).abs());
  _shade(_cdCard, _cdShader[it.c]);
  _s(_cdCard, const Color(0xFF0A0B0D), 4);
  const w75 = Color.fromRGBO(255, 255, 255, 0.75);
  if (!back) {
    _fs(_cdChip, const Color(0xFFC7CDD4), const Color(0xFF6E757E), 1.6);
    _s(_cdChipLines, const Color(0xFF6E757E), 1);
    _s(_cdWaves, w75, 1.8);
    _f(_cdDigits, w75);
    _f(_cdName, const Color.fromRGBO(255, 255, 255, 0.55));
  } else {
    _f(_cdStripe, const Color(0xFF0B0C0E));
    _f(_cdSign, const Color.fromRGBO(255, 255, 255, 0.78));
    _f(_cdCvv, const Color.fromRGBO(255, 255, 255, 0.45));
  }
  // Блик по металлу — часть карты между краями косой полосы.
  final sw = -90 + ((t * 42 + it.ph * 30) % 240);
  if (sw - 20 < 46 && sw + 14 > -46) {
    var n = _clipEdge(
      _cdPoly,
      _cdPoly.length ~/ 2,
      _bufA,
      sw + 14,
      -32,
      sw - 6,
      32,
    );
    if (n >= 3) n = _clipEdge(_bufA, n, _bufB, sw - 20, 32, sw, -32);
    if (n >= 3) {
      _polyPath(_bufB, n);
      _f(_tmp, _white, 0.2);
    }
  }
  _s(_cdEdge, const Color.fromRGBO(255, 255, 255, 0.22), 1.5);
  _star(
    40,
    -24,
    12,
    cc > 1.1 && cc < 1.6 ? math.sin((cc - 1.1) / 0.5 * _pi) : 0,
  );
}

// ── Подарки ───────────────────────────────────────────────────────────────

const List<(Color, Color, Color)> _gfG = [
  (Color(0xFF1F5E45), Color(0xFFF3E6C8), Color(0xFF0F3526)),
  (Color(0xFF6E1C2C), Color(0xFFF2C9CF), Color(0xFF3A0C16)),
  (Color(0xFF1C1E22), Color(0xFFC9CED6), Color(0xFF08090B)),
  (Color(0xFFF1E7D6), Color(0xFF1C1E22), Color(0xFF8C7C62)),
];
final Path _gfBox = _rr(-32, -4, 64, 44, 5);
final Path _gfRibbon = _rect(-6, -2, 12, 40);
final Path _gfShine = _ell(-21, 8, 3, 10);
final Path _gfLid = _rr(-37, -18, 74, 15, 5);
final Path _gfLidRibbon = _rect(-6, -16, 12, 11);
final Path _gfBowL = _ell(-12, -25, 12, 7, -0.5);
final Path _gfBowR = _ell(12, -25, 12, 7, 0.5);
final Path _gfKnot = _circle(0, -21, 5.5);

void _gift(_It it, double t) {
  final g = _gfG[it.c];
  final cc = _cyc(t, it.ph, 6.5);
  final pop = cc < 0.35
      ? math.sin(cc / 0.35 * _pi / 2)
      : cc < 0.8
      ? 1.0
      : cc < 1.15
      ? 1 - _ez((cc - 0.8) / 0.35)
      : 0.0;
  final land = cc > 1.1 && cc < 1.4 ? math.sin((cc - 1.1) / 0.3 * _pi) : 0.0;
  if (land != 0) {
    _c.translate(0, 40);
    _c.scale(1 + 0.05 * land, 1 - 0.06 * land);
    _c.translate(0, -40);
  }
  _fs(_gfBox, g.$1, g.$3, 5);
  _fs(_gfRibbon, g.$2, g.$3, 2);
  _shine(_gfShine, 0.35);
  if (cc > 0.05 && cc < 1.9) {
    for (var k = 0; k < 7; k++) {
      final u = (cc - 0.08 - k * 0.07) / 1.2;
      if (u < 0 || u > 1) continue;
      _star(
        math.sin(k * 1.7 + 0.4) * u * 34,
        -8 - u * 50,
        6.5 * (1 - u * 0.4),
        1 - u,
      );
    }
  }
  _c.save();
  if (pop != 0) {
    _c.translate(0, -pop * 20);
    _c.rotate(-pop * 0.22);
  }
  _fs(_gfLid, g.$1, g.$3, 5);
  _f(_gfLidRibbon, g.$2);
  _fs(_gfBowL, g.$2, g.$3, 4);
  _fs(_gfBowR, g.$2, g.$3, 4);
  _fs(_gfKnot, g.$2, g.$3, 3.5);
  _c.restore();
}

// ── Ёлочные шары ──────────────────────────────────────────────────────────

const List<(Color, Color)> _orC = [
  (Color(0xFFD2303F), Color(0xFF7A0F1E)),
  (Color(0xFF21734F), Color(0xFF0C3A26)),
  (Color(0xFF3557B8), Color(0xFF14245A)),
  (Color(0xFFEDE8DF), Color(0xFF8C8273)),
];
const Color _orMetal = Color(0xFF8C949E);
final List<Color> _orBandC = [for (final c in _orC) _mix(c.$1, _white, 0.2)];
final Path _orBall = _circle(0, -2, 34);
final Path _orInner = _circle(0, -2, 32);
final Shader _orGloss = ui.Gradient.radial(
  const Offset(0, -2),
  36,
  const [
    Color.fromRGBO(255, 255, 255, 0.28),
    Color.fromRGBO(255, 255, 255, 0),
    Color.fromRGBO(0, 0, 0, 0.28),
  ],
  const [0, 0.6, 1],
  TileMode.clamp,
  null,
  const Offset(-12, -16),
  4,
);
final Path _orBand = _and(_rect(-40, -9, 80, 14), _orInner);

/// Зигзаг по поясу шара, обрезанный по стеклу (концы — на r 31, чтобы
/// круглые концы линии не легли на обводку).
final Path _orZig = () {
  final pts = <Offset>[
    for (var i = 0, x = -36.0; x <= 36; x += 6, i++)
      Offset(x, i.isOdd ? 2 : -6),
  ];
  const c = Offset(0, -2), r = 31.0;
  bool inside(Offset p) => (p - c).distance <= r;
  Offset enter(Offset a, Offset b) {
    // Точка на отрезке a→b на окружности (a снаружи, b внутри).
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      if (inside(Offset.lerp(a, b, mid)!)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return Offset.lerp(a, b, hi)!;
  }

  final inner = [
    for (final p in pts)
      if (inside(p)) p,
  ];
  final first = enter(pts.first, inner.first);
  final last = enter(pts.last, inner.last);
  final p = Path()..moveTo(first.dx, first.dy);
  for (final q in inner) {
    p.lineTo(q.dx, q.dy);
  }
  return p..lineTo(last.dx, last.dy);
}();
final Path _orDotsEven = () {
  final p = Path();
  for (final x in const [-22.0, 0.0, 22.0]) {
    p
      ..addOval(Rect.fromCircle(center: Offset(x, -20), radius: 1.9))
      ..addOval(Rect.fromCircle(center: Offset(x, 16), radius: 1.9));
  }
  return p;
}();
final Path _orDotsOdd = () {
  const pts = [
    (-18.0, -14.0),
    (6.0, -20.0),
    (20.0, 2.0),
    (-6.0, 10.0),
    (-22.0, 8.0),
    (12.0, 20.0),
    (0.0, -4.0),
    (24.0, -14.0),
  ];
  final p = Path();
  for (var i = 0; i < pts.length; i++) {
    p.addOval(
      Rect.fromCircle(
        center: Offset(pts[i].$1, pts[i].$2),
        radius: i.isOdd ? 2.3 : 1.5,
      ),
    );
  }
  return p;
}();
final Path _orFlake = () {
  final p = Path();
  for (var k = 0; k < 3; k++) {
    final a = k * _pi / 3, ca = math.cos(a) * 6, sa = math.sin(a) * 6;
    p
      ..moveTo(4 + ca, -2 + sa)
      ..lineTo(4 - ca, -2 - sa);
  }
  return p;
}();
final Path _orCap = _rr(-9, -46, 18, 10, 2);
final Path _orRidges = () {
  final p = Path();
  for (var k = -5.0; k <= 5; k += 3.3) {
    p
      ..moveTo(k, -45)
      ..lineTo(k, -37);
  }
  return p;
}();
final Path _orShine1 = _ell(-13, -16, 9, 5.5, -0.7);
final Path _orShine2 = _ell(-21, -3, 2, 2);

void _ornament(_It it, double t) {
  final c = it.c, col = _orC[c];
  final cc = _cyc(t, it.ph, 5);
  final sw = 0.16 * math.sin(t * 1.5 + it.ph);
  _seg(0, -66, 0, -48, const Color(0xFFC9CED6), 1.6);
  _c.translate(0, -48);
  _c.rotate(sw);
  _c.translate(0, 48);
  _ring(0, -50, 3.2, _orMetal, 2);
  _fs(_orCap, const Color(0xFFD3D8DE), const Color(0xFF4A525C), 3);
  _s(_orRidges, _orMetal, 1);
  _fs(_orBall, col.$1, col.$2, 5);
  _shade(_orInner, _orGloss);
  final lite = c == 3 ? const Color(0xFFA8977A) : _white;
  if (c.isEven) {
    _f(_orBand, _orBandC[c]);
    _s(_orZig, lite, 2.2);
    _f(_orDotsEven, lite);
  } else {
    _f(_orDotsOdd, lite);
    _s(_orFlake, lite, 1.6);
  }
  _shine(_orShine1, 0.6);
  _shine(_orShine2, 0.6);
  _star(15, -22, 11, cc < 0.5 ? math.sin(cc / 0.5 * _pi) : 0);
}

// ── Снежинки ──────────────────────────────────────────────────────────────

const Color _sfO = Color(0xFF2B527F);
const Color _sfF = Color(0xFFEAF6FF);
const List<List<double>> _sfV = [
  [0.45, 13, 0.72, 9],
  [0.38, 10, 0.62, 13],
  [0.55, 15, 0.8, 7],
];
final List<Path> _sfArms = [
  for (final v in _sfV)
    () {
      final p = Path();
      for (var k = 0; k < 6; k++) {
        final a = k * _pi / 3, ca = math.cos(a), sa = math.sin(a);
        p
          ..moveTo(0, 0)
          ..lineTo(ca * 40, sa * 40);
        for (final (u, l) in [(v[0], v[1]), (v[2], v[3])]) {
          final px = ca * 40 * u, py = sa * 40 * u;
          for (final sg in const [1, -1]) {
            final b = a + sg * _pi / 3;
            p
              ..moveTo(px, py)
              ..lineTo(px + math.cos(b) * l, py + math.sin(b) * l);
          }
        }
      }
      return p;
    }(),
];
final Path _sfTips = () {
  final p = Path();
  for (var k = 0; k < 6; k++) {
    final a = k * _pi / 3, x = math.cos(a) * 42, y = math.sin(a) * 42;
    p
      ..moveTo(x + math.cos(a) * 5, y + math.sin(a) * 5)
      ..lineTo(x + math.cos(a + _pi / 2) * 3.5, y + math.sin(a + _pi / 2) * 3.5)
      ..lineTo(x - math.cos(a) * 4, y - math.sin(a) * 4)
      ..lineTo(x + math.cos(a - _pi / 2) * 3.5, y + math.sin(a - _pi / 2) * 3.5)
      ..close();
  }
  return p;
}();
final Path _sfHex = _poly([
  for (var k = 0; k < 6; k++) ...[
    math.cos(k * _pi / 3 + _pi / 6) * 10,
    math.sin(k * _pi / 3 + _pi / 6) * 10,
  ],
]);
final Path _sfShine = _ell(-3, -3, 3, 2, -0.5);

void _snowflake(_It it, double t) {
  final c = it.c;
  final rot = t * 0.25 * (c.isOdd ? 1 : -1) + it.ph;
  final br = 1 + 0.04 * math.sin(t * 1.3 + it.ph);
  _c.rotate(rot);
  _c.scale(br);
  _s(_sfArms[c], _sfO, 10);
  _s(_sfArms[c], _sfF, 5);
  _fs(_sfTips, _sfF, _sfO, 3);
  _fs(_sfHex, const Color(0xFFCFE8FA), _sfO, 3.5);
  _shine(_sfShine, 0.8);
  final cc = _cyc(t, it.ph, 4);
  _star(0, 0, 14, cc < 0.5 ? math.sin(cc / 0.5 * _pi) : 0);
  _star(42, 0, 8, cc > 2 && cc < 2.4 ? math.sin((cc - 2) / 0.4 * _pi) : 0);
}

// ── Снеговики ─────────────────────────────────────────────────────────────

const Color _smO = Color(0xFF5F7FA6);
const Color _smBr = Color(0xFF6A4326);
const Color _smCoal = Color(0xFF2A2E34);
const Color _smHatC = Color(0xFF1E2228);
const List<(Color, Color)> _smC = [
  (Color(0xFFD2303F), Color(0xFF7A0F1E)),
  (Color(0xFF21734F), Color(0xFF0C3A26)),
  (Color(0xFF3557B8), Color(0xFF14245A)),
];

/// Ком снега: обводка, тень снизу-справа и белое ядро — пересечения
/// с внутренним кругом считаются один раз (вместо выреза в макете).
(Path, Path, Path) _snowBall(double x, double y, double r) {
  final inner = _circle(x, y, r - 2.2);
  return (
    _circle(x, y, r),
    _and(inner, _circle(x + r * 0.4, y + r * 0.4, r)),
    _and(inner, _circle(x - r * 0.1, y - r * 0.1, r * 0.9)),
  );
}

final (Path, Path, Path) _smLow = _snowBall(0, 24, 25);
final (Path, Path, Path) _smHigh = _snowBall(0, -14, 18);
final Path _smArmL = Path()
  ..moveTo(-18, 14)
  ..lineTo(-40, 2)
  ..moveTo(-32, 7)
  ..lineTo(-36, -3);
final Path _smButtons = Path()
  ..addOval(Rect.fromCircle(center: const Offset(0, 16), radius: 2.4))
  ..addOval(Rect.fromCircle(center: const Offset(0, 26), radius: 2.4))
  ..addOval(Rect.fromCircle(center: const Offset(0, 36), radius: 2.4));
final Path _smScarf = _rr(-17, 0, 34, 8, 4);
final Path _smStripes = () {
  final p = Path();
  for (final x in const [-9.0, -3.0, 3.0, 9.0]) {
    p
      ..moveTo(x, 1.5)
      ..lineTo(x, 6.5);
  }
  return p;
}();
final Path _smEyesOpen = Path()
  ..addOval(Rect.fromCircle(center: const Offset(-6, -18), radius: 2.3))
  ..addOval(Rect.fromCircle(center: const Offset(6, -18), radius: 2.3));
final Path _smEyesShut = Path()
  ..moveTo(-8.4, -18)
  ..lineTo(-3.6, -18)
  ..moveTo(3.6, -18)
  ..lineTo(8.4, -18);
final Path _smNose = _poly(const [1, -13, 18, -10, 1, -8]);
final Path _smMouth = () {
  final p = Path();
  const xs = [-6.0, -3.0, 0.0, 3.0, 6.0];
  for (var i = 0; i < xs.length; i++) {
    p.addOval(
      Rect.fromCircle(
        center: Offset(xs[i], -4 + (i - 2).abs() * -0.8),
        radius: 1.1,
      ),
    );
  }
  return p;
}();
final Path _smBrim = _rr(-19, -33, 38, 5, 2.5);
final Path _smHat = _rr(-12, -54, 24, 22, 3);
final Path _smHatBand = _rect(-12, -38, 24, 4.5);
final Path _smHatShine = _ell(-7, -46, 1.6, 5);

void _snowBallDraw((Path, Path, Path) b) {
  _fs(b.$1, _white, _smO, 4.5);
  _f(b.$2, const Color(0xFFD6E4F3));
  _f(b.$3, _white);
}

void _snowman(_It it, double t) {
  final sc = _smC[it.c];
  final cc = _cyc(t, it.ph, 5.5);
  final wa =
      -0.7 + (cc < 1.8 ? 0.55 * math.sin(cc * 9) : 0.08 * math.sin(t * 2));
  _s(_smArmL, _smBr, 3.4);
  _tmp
    ..reset()
    ..moveTo(18, 12)
    ..lineTo(18 + math.cos(wa) * 24, 12 + math.sin(wa) * 24)
    ..moveTo(18 + math.cos(wa) * 16, 12 + math.sin(wa) * 16)
    ..lineTo(18 + math.cos(wa - 0.6) * 24, 12 + math.sin(wa - 0.6) * 24);
  _s(_tmp, _smBr, 3.4);
  _snowBallDraw(_smLow);
  _snowBallDraw(_smHigh);
  _f(_smButtons, _smCoal);
  final fl = 3 * math.sin(t * 4 + it.ph);
  _tmp
    ..reset()
    ..moveTo(9, 5)
    ..quadraticBezierTo(14 + fl * 0.5, 14, 13 + fl, 24);
  _s(_tmp, sc.$2, 10);
  _s(_tmp, sc.$1, 6);
  _fs(_smScarf, sc.$1, sc.$2, 3);
  _s(_smStripes, _white, 1.6);
  if (_cyc(t, it.ph, 3.7) < 0.12) {
    _s(_smEyesShut, _smHatC, 2);
  } else {
    _f(_smEyesOpen, _smHatC);
  }
  _fs(_smNose, const Color(0xFFF28C28), const Color(0xFF9A4A0E), 2);
  _f(_smMouth, _smCoal);
  _fs(_smBrim, _smHatC, _smO, 3);
  _fs(_smHat, _smHatC, _smO, 3);
  _f(_smHatBand, sc.$1);
  _shine(_smHatShine, 0.35);
}

// ── Мандарины ─────────────────────────────────────────────────────────────

const Color _tgO = Color(0xFF9A4A0E);
final Path _tgBody = _ell(0, 4, 33, 30);
final Path _tgInner = _ell(0, 4, 31, 28);
final Path _tgShade = _and(_tgInner, _ell(12, 14, 32, 30));
final Path _tgPores = _and(_tgInner, () {
  final p = Path();
  for (var k = 0; k < 16; k++) {
    p.addOval(
      Rect.fromCircle(
        center: Offset(
          math.cos(k * 2.4) * (8 + k * 1.3),
          4 + math.sin(k * 2.4) * (7 + k * 1.2),
        ),
        radius: 1,
      ),
    );
  }
  return p;
}());
final Path _tgShine = _ell(-12, -8, 8, 5, -0.6);
final Path _tgStem = _circle(0, -25, 3);
final Path _tgLeaf = Path()
  ..moveTo(0, 0)
  ..quadraticBezierTo(10, -14, 27, -10)
  ..quadraticBezierTo(14, 3, 0, 0);
final Path _tgVein = Path()
  ..moveTo(3, -1)
  ..quadraticBezierTo(13, -7, 24, -9);
final Path _tgSlice = Path()
  ..moveTo(-30, 10)
  ..quadraticBezierTo(0, -38, 30, 10)
  ..quadraticBezierTo(0, -4, -30, 10)
  ..close();
final Path _tgJuice = () {
  final p = Path();
  for (final x in const [-14.0, -5.0, 5.0, 14.0]) {
    p
      ..moveTo(x * 0.6, 0)
      ..quadraticBezierTo(x, -10, x * 1.2, -14 + x.abs() * 0.5);
  }
  return p;
}();
final Path _tgEdge = Path()
  ..moveTo(-26, 8)
  ..quadraticBezierTo(0, -3, 26, 8);
final Path _tgSliceShine = _ell(-8, -14, 7, 3, -0.3);

void _tangerine(_It it, double t) {
  final cc = _cyc(t, it.ph, 5);
  if (it.c == 0) {
    _fs(_tgBody, const Color(0xFFF5962A), _tgO, 5);
    _f(_tgShade, const Color.fromRGBO(170, 70, 0, 0.2));
    _f(_tgPores, const Color.fromRGBO(255, 255, 255, 0.22));
    _shine(_tgShine, 0.55);
    _fs(_tgStem, const Color(0xFF6B8E3A), const Color(0xFF2F4A1A), 2.5);
    _c.save();
    _c.translate(2, -26);
    _c.rotate(-0.5 + 0.14 * math.sin(t * 2 + it.ph));
    _fs(_tgLeaf, const Color(0xFF4CAF50), const Color(0xFF1F5A23), 3);
    _s(_tgVein, const Color(0xFF1F5A23), 1.4);
    _c.restore();
  } else {
    _c.rotate(0.15 * math.sin(t * 1.6 + it.ph));
    _fs(_tgSlice, const Color(0xFFFFB347), const Color(0xFFB5651D), 4.5);
    _s(_tgJuice, const Color.fromRGBO(255, 255, 255, 0.55), 1.4);
    _s(_tgEdge, const Color(0xFFFFF1D6), 2.4);
    _shine(_tgSliceShine, 0.6);
  }
  _star(-20, -16, 9, cc < 0.45 ? math.sin(cc / 0.45 * _pi) : 0);
}

// ── Пряничные человечки ───────────────────────────────────────────────────

const Color _gbO = Color(0xFF6A3A18);
const Color _gbF = Color(0xFFC47D3E);
const List<double> _gbRoots = [-8, -6, 8, -6, -7, 18, 7, 18];
final Float64List _gbEnds = Float64List(8);
final Path _gbBody = _ell(0, 8, 18, 22);
final Path _gbHead = _circle(0, -28, 15);
final Path _gbShine = _ell(-7, -34, 4, 2.5, -0.5);
final Path _gbEyes = Path()
  ..addOval(Rect.fromCircle(center: const Offset(-5, -30), radius: 2.2))
  ..addOval(Rect.fromCircle(center: const Offset(5, -30), radius: 2.2));
final Path _gbSmile = Path()
  ..addArc(
    Rect.fromCircle(center: const Offset(0, -26), radius: 6),
    0.3,
    _pi - 0.6,
  );
const List<(Color, Color, double)> _gbButtons = [
  (Color(0xFFE0384F), Color(0xFF7A0F1E), 0),
  (Color(0xFF3FA34D), Color(0xFF1F5A23), 9),
  (Color(0xFFFFFFFF), Color(0xFFB9A79A), 18),
];

void _gingerbread(_It it, double t) {
  final d = math.sin(t * 5 + it.ph);
  _c.translate(0, -d.abs() * 3);
  final e = _gbEnds;
  e[0] = -30;
  e[1] = -16 + 9 * d;
  e[2] = 30;
  e[3] = -16 - 9 * d;
  e[4] = -16;
  e[5] = 40 - 5 * math.max(0, d);
  e[6] = 16;
  e[7] = 40 - 5 * math.max(0, -d);
  _tmp.reset();
  for (var i = 0; i < 4; i++) {
    _tmp
      ..moveTo(_gbRoots[i * 2], _gbRoots[i * 2 + 1])
      ..lineTo(e[i * 2], e[i * 2 + 1]);
  }
  _s(_tmp, _gbO, 22);
  _fs(_gbBody, _gbF, _gbO, 5);
  _fs(_gbHead, _gbF, _gbO, 5);
  _s(_tmp, _gbF, 16);
  // Глазурь зигзагом у кончиков рук и ног.
  _tmp.reset();
  for (var i = 0; i < 4; i++) {
    final x = e[i * 2], y = e[i * 2 + 1];
    final a = math.atan2(y - _gbRoots[i * 2 + 1], x - _gbRoots[i * 2]);
    final ca = math.cos(a), sa = math.sin(a), nx = -sa, ny = ca;
    final bx = x - ca * 4, by = y - sa * 4;
    for (var k = -2; k <= 2; k++) {
      final o = k.isOdd ? 2.0 : -2.0;
      final px = bx + nx * k * 2.6 + ca * o, py = by + ny * k * 2.6 + sa * o;
      k == -2 ? _tmp.moveTo(px, py) : _tmp.lineTo(px, py);
    }
  }
  _s(_tmp, _white, 2.4);
  _shine(_gbShine, 0.4);
  _f(_gbEyes, const Color(0xFF3A1F0C));
  _s(_gbSmile, _white, 2.2);
  for (final (fc, oc, y) in _gbButtons) {
    _disc(0, y, 3.4, fc, oc, 1.8);
  }
}

// ── Бенгальские огни ──────────────────────────────────────────────────────

const double _skX = 12, _skY = -14;
final Shader _skGlowDark = ui.Gradient.radial(
  const Offset(_skX, _skY),
  36,
  const [Color.fromRGBO(255, 230, 150, 0.6), Color.fromRGBO(255, 200, 90, 0)],
);
final Shader _skGlowLight = ui.Gradient.radial(
  const Offset(_skX, _skY),
  36,
  const [Color.fromRGBO(255, 170, 60, 0.45), Color.fromRGBO(255, 200, 90, 0)],
);
final Path _skStick = Path()
  ..moveTo(-30, 44)
  ..lineTo(_skX, _skY);
final Path _skBurnt = Path()
  ..moveTo(-1, 3)
  ..lineTo(_skX, _skY);
final Path _skGlow = _circle(_skX, _skY, 36);

void _sparkler(_It it, double t, bool dark) {
  _s(_skStick, const Color(0xFF5A6068), 6);
  _s(_skStick, const Color(0xFFA9B0B8), 3);
  _s(_skBurnt, const Color(0xFF3A3E44), 5);
  final fl = 0.8 + 0.2 * math.sin(t * 31 + it.ph * 5);
  _shade(_skGlow, dark ? _skGlowDark : _skGlowLight, fl);
  // Лучи искр: три контура на 26 лучей (обводка светлой темы и два цвета).
  _tmp.reset();
  _tmp2.reset();
  _tmp3.reset();
  for (var k = 0; k < 26; k++) {
    final a = k * 2.39996 + (t * 14 + k).floorToDouble() * 0.7;
    final len = 10 + 24 * math.sin(t * 19 + k * 7.13).abs();
    final ca = math.cos(a), sa = math.sin(a);
    final x0 = _skX + ca * 4, y0 = _skY + sa * 4;
    final x1 = _skX + ca * len, y1 = _skY + sa * len;
    if (!dark) {
      _tmp
        ..moveTo(x0, y0)
        ..lineTo(x1, y1);
    }
    final p = k % 3 != 0 ? _tmp2 : _tmp3;
    p
      ..moveTo(x0, y0)
      ..lineTo(x1, y1);
    if (len > 22) {
      final fx = _skX + ca * len * 0.7, fy = _skY + sa * len * 0.7;
      p
        ..moveTo(fx, fy)
        ..lineTo(fx + math.cos(a + 0.6) * 6, fy + math.sin(a + 0.6) * 6)
        ..moveTo(fx, fy)
        ..lineTo(fx + math.cos(a - 0.6) * 6, fy + math.sin(a - 0.6) * 6);
    }
  }
  if (!dark) _s(_tmp, const Color(0xFFC26A10), 3);
  _s(_tmp2, const Color(0xFFFFF3B0), 1.6);
  _s(_tmp3, const Color(0xFFFFC857), 1.6);
  _dot(_skX, _skY, 4.2 * fl, _white);
  for (var k = 0; k < 6; k++) {
    final u = (t * 1.2 + k * 0.17 + it.ph) % 1;
    _dot(
      _skX + math.sin(k * 3.0) * 12 * u,
      _skY + u * 44,
      1.6 * (1 - u) + 0.4,
      const Color(0xFFFFC857),
      1 - u,
    );
  }
}

// ── Колокольчики ──────────────────────────────────────────────────────────

const List<(Color, Color)> _blC = [
  (Color(0xFFD9DEE4), Color(0xFF55606C)),
  (Color(0xFFD2303F), Color(0xFF7A0F1E)),
  (Color(0xFF21734F), Color(0xFF0C3A26)),
];
final List<Color> _blLipC = [for (final c in _blC) _mix(c.$1, c.$2, 0.25)];

/// Волны звона: справа и слева, по две.
final List<Path> _blWaves = [
  for (final side in const [0.0, _pi])
    for (final k in const [1, 2])
      Path()..addArc(
        Rect.fromCircle(center: const Offset(0, 8), radius: 36.0 + k * 9),
        side - 0.5,
        1,
      ),
];
final Path _blBell = Path()
  ..moveTo(-6, -30)
  ..cubicTo(-24, -28, -22, 0, -30, 22)
  ..quadraticBezierTo(0, 30, 30, 22)
  ..cubicTo(22, 0, 24, -28, 6, -30)
  ..close();
final Path _blLip = _ell(0, 23, 31, 6);
final Path _blLine = Path()
  ..moveTo(-25, 10)
  ..quadraticBezierTo(0, 16, 25, 10);
final Path _blShine = _ell(-12, -6, 3.5, 11, 0.25);
final List<Path> _blLeaves = [
  for (final (sd, r) in const [(-1.0, -0.5), (1.0, 0.5)])
    () {
      final p = Path()..moveTo(0, 0);
      for (var k = 0; k <= 4; k++) {
        p.lineTo(sd * k * 5, (k.isOdd ? -7 : -3) - (k == 4 ? -3 : 0));
      }
      for (var k = 4; k >= 0; k--) {
        p.lineTo(sd * k * 5, k.isOdd ? 6 : 3);
      }
      p.close();
      return p.transform(_affine(sd * 8, -34, r));
    }(),
];
const List<(double, double)> _blBerries = [(-4, -35), (4, -35), (0, -41)];
final List<Path> _blBerryShine = [
  for (final (x, y) in _blBerries) _ell(x - 1.2, y - 1.2, 1.1, 1.1),
];

void _bell(_It it, double t) {
  final bc = _blC[it.c];
  final cc = _cyc(t, it.ph, 4.5);
  final env = cc < 1.8 ? 1 - cc / 1.8 : 0.0;
  final sw = 0.45 * env * math.sin(cc * 10);
  if (env > 0.05) {
    for (var i = 0; i < 4; i++) {
      final k = i % 2 + 1;
      _s(_blWaves[i], _white, 2.6, env * 0.8 / k);
    }
  }
  _c.translate(0, -30);
  _c.rotate(sw);
  _c.translate(0, 30);
  _disc(
    math.sin(-sw * 1.6) * 9,
    28,
    6,
    const Color(0xFF8C949E),
    const Color(0xFF3A4048),
    3,
  );
  _fs(_blBell, bc.$1, bc.$2, 5);
  _fs(_blLip, _blLipC[it.c], bc.$2, 4);
  _s(_blLine, bc.$2, 2);
  _shine(_blShine, 0.6);
  for (final leaf in _blLeaves) {
    _fs(leaf, const Color(0xFF2F8F4E), const Color(0xFF123F27), 3);
  }
  for (var i = 0; i < _blBerries.length; i++) {
    final (x, y) = _blBerries[i];
    _disc(x, y, 4, const Color(0xFFE0384F), const Color(0xFF7A0F1E), 2.5);
    _shine(_blBerryShine[i], 0.8);
  }
}

// ── Какао ─────────────────────────────────────────────────────────────────

const List<(Color, Color, Color)> _ccM = [
  (Color(0xFFD2303F), Color(0xFF7A0F1E), Color(0xFFFFFFFF)),
  (Color(0xFFF1EBDF), Color(0xFF8C8273), Color(0xFFD2303F)),
  (Color(0xFF21734F), Color(0xFF0C3A26), Color(0xFFFFFFFF)),
];
final Path _ccCane =
    (Path()
          ..moveTo(0, 20)
          ..lineTo(0, -22)
          ..arcTo(
            Rect.fromCircle(center: const Offset(-7, -22), radius: 7),
            0,
            -_pi,
            false,
          )
          ..lineTo(-14, -17))
        .transform(_affine(12, -12, 0.35));
final Path _ccCaneDash = _dash(_ccCane, 4, 4);
final Path _ccHandle = Path()
  ..addArc(
    Rect.fromCircle(center: const Offset(24, 9), radius: 12),
    -_pi / 2,
    _pi,
  );
final Path _ccMug = _rr(-30, -18, 54, 54, 10);
final Path _ccKnit = () {
  final p = Path();
  for (var x = -26.0, i = 0; x <= 20; x += 5.75, i++) {
    final y = i.isOdd ? 16.0 : 10.0;
    i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
  }
  return p;
}();
final Path _ccDots = () {
  final p = Path();
  for (final x in const [-20.0, -10.0, 0.0, 10.0]) {
    p.addOval(Rect.fromCircle(center: Offset(x + 2, 24), radius: 1.6));
  }
  return p;
}();
final Path _ccSurface = _ell(-3, -18, 27, 6);
final Path _ccMallow = _rr(-5, -5, 10, 10, 3);
final Path _ccShine = _ell(-21, 6, 3, 11);
const List<(double, double, Color)> _ccMallows = [
  (-14, -20, Color(0xFFFFF7F2)),
  (-2, -23, Color(0xFFFFD6E0)),
  (10, -19, Color(0xFFFFF7F2)),
];

void _cocoa(_It it, double t) {
  final m = _ccM[it.c];
  // Пар — три струйки, каждая дышит своей прозрачностью.
  const sxs = [-14.0, -2.0, 10.0];
  for (var n = 0; n < 3; n++) {
    _tmp.reset();
    for (var yy = 0; yy <= 30; yy += 2) {
      final px = sxs[n] + 4 * math.sin(yy * 0.22 - t * 1.8 + it.ph + n * 2);
      yy == 0 ? _tmp.moveTo(px, -30) : _tmp.lineTo(px, -30.0 - yy);
    }
    _s(_tmp, _white, 2.4, 0.5 * (0.6 + 0.4 * math.sin(t * 0.9 + it.ph + n)));
  }
  _s(_ccCane, const Color(0xFF7A0F1E), 9.5);
  _s(_ccCane, _white, 6);
  _line.strokeCap = StrokeCap.butt;
  _s(_ccCaneDash, const Color(0xFFE0384F), 6);
  _line.strokeCap = StrokeCap.round;
  _s(_ccHandle, m.$2, 11);
  _s(_ccHandle, m.$1, 6);
  _fs(_ccMug, m.$1, m.$2, 5);
  _s(_ccKnit, m.$3, 2.4);
  _f(_ccDots, m.$3);
  _fs(_ccSurface, const Color(0xFF6B3F2A), m.$2, 4);
  for (var k = 0; k < _ccMallows.length; k++) {
    final (x, y, col) = _ccMallows[k];
    _c.save();
    _c.translate(x, y + math.sin(t * 2 + k + it.ph) * 1.5);
    _c.rotate(0.3 * (k - 1) + 0.1 * math.sin(t * 1.4 + k));
    _fs(_ccMallow, col, const Color(0xFFB79C94), 2.4);
    _c.restore();
  }
  _shine(_ccShine, 0.45);
}

// ── Ёлочки ────────────────────────────────────────────────────────────────

const Color _trO = Color(0xFF123F27);
const Color _trG = Color(0xFF2E8B57);
const List<Color> _trBulbC = [
  Color(0xFFFF4B5C),
  Color(0xFFFFD84D),
  Color(0xFF5CC8FF),
  Color(0xFF7CF29A),
];
const List<(double, double, double)> _trTierDims = [
  (-10, 34, 36),
  (-28, 12, 28),
  (-44, -8, 19),
];
final Path _trTrunk = _rr(-6, 30, 12, 13, 2);
final List<Path> _trTiers = [
  for (final (top, base, w) in _trTierDims)
    () {
      final p = Path()
        ..moveTo(0, top)
        ..lineTo(w, base);
      for (var k = 0; k < 4; k++) {
        final x0 = w - k * 2 * w / 4, x1 = w - (k + 1) * 2 * w / 4;
        p.quadraticBezierTo((x0 + x1) / 2, base + 6, x1, base);
      }
      return p..close();
    }(),
];
final List<Path> _trLit = [
  for (final (top, base, w) in _trTierDims)
    _poly([-2, top + 6, -w * 0.6, base - 2, -w * 0.35, base - 2]),
];
final Path _trGarland = () {
  final p = Path();
  for (final (_, base, w) in _trTierDims) {
    p
      ..moveTo(-w * 0.78, base - 4)
      ..quadraticBezierTo(0, base + 2, w * 0.78, base - 13);
  }
  return p;
}();

/// Лампочки: 15 мест (3 яруса × 5), у каждой свой цвет.
class _Bulb {
  const _Bulb(this.x, this.y, this.ci, this.k, this.ti);
  final double x, y;
  final int ci, k, ti;
}

final List<_Bulb> _trBulbs = [
  for (var ti = 0; ti < 3; ti++)
    for (var k = 0; k < 5; k++)
      () {
        final (_, base, w) = _trTierDims[ti];
        final ax = -w * 0.78, ay = base - 4, bx = w * 0.78, by = base - 13;
        const qx = 0.0;
        final qy = base + 2;
        final u = (k + 0.5) / 5, v = 1 - u;
        return _Bulb(
          v * v * ax + 2 * u * v * qx + u * u * bx,
          v * v * ay + 2 * u * v * qy + u * u * by,
          (k + ti) % 4,
          k,
          ti,
        );
      }(),
];
final List<Shader> _trGlow = [
  for (final b in _trBulbs)
    ui.Gradient.radial(Offset(b.x, b.y), 8, [
      _trBulbC[b.ci],
      const Color.fromRGBO(255, 255, 255, 0),
    ]),
];
final List<Path> _trGlowDisc = [for (final b in _trBulbs) _circle(b.x, b.y, 8)];
final List<Color> _trBulbOff = [
  for (final c in _trBulbC) _mix(c, const Color(0xFF000000), 0.45),
];

/// Огоньки бегут по кругу: состояние = такт mod 3. На каждое состояние —
/// готовые контуры лампочек по цвету (горит / не горит) и список горящих.
final List<List<Path?>> _trFills = [
  for (var s = 0; s < 3; s++)
    () {
      final out = List<Path?>.filled(8, null);
      for (final b in _trBulbs) {
        final on = (s + b.k + b.ti * 2) % 3 == 0;
        final slot = b.ci * 2 + (on ? 1 : 0);
        (out[slot] ??= Path()).addOval(
          Rect.fromCircle(center: Offset(b.x, b.y + 1.5), radius: 2.8),
        );
      }
      return out;
    }(),
];
final List<List<int>> _trOn = [
  for (var s = 0; s < 3; s++)
    [
      for (var i = 0; i < _trBulbs.length; i++)
        if ((s + _trBulbs[i].k + _trBulbs[i].ti * 2) % 3 == 0) i,
    ],
];
final Path _trRims = () {
  final p = Path();
  for (final b in _trBulbs) {
    p.addOval(Rect.fromCircle(center: Offset(b.x, b.y + 1.5), radius: 2.8));
  }
  return p;
}();
final Path _trStar = _poly([
  for (var k = 0; k < 10; k++) ...[
    math.cos(-_pi / 2 + k * _pi / 5) * (k.isOdd ? 4.2 : 10),
    -48 + math.sin(-_pi / 2 + k * _pi / 5) * (k.isOdd ? 4.2 : 10),
  ],
]);

void _tree(_It it, double t) {
  final st = (t * 4).floor() % 3;
  _fs(_trTrunk, const Color(0xFF7A4A2A), const Color(0xFF3E2414), 3.5);
  for (var i = 0; i < 3; i++) {
    _fs(_trTiers[i], _trG, _trO, 4.5);
    _f(_trLit[i], _white, 0.25);
  }
  _s(_trGarland, const Color(0xFFE9D9B0), 1.4);
  for (final i in _trOn[st]) {
    _shade(_trGlowDisc[i], _trGlow[i], 0.7);
  }
  final fills = _trFills[st];
  for (var slot = 0; slot < 8; slot++) {
    final p = fills[slot];
    if (p == null) continue;
    final ci = slot >> 1;
    _f(p, slot.isOdd ? _trBulbC[ci] : _trBulbOff[ci]);
  }
  _s(_trRims, _trO, 1.2);
  final pulse = 0.5 + 0.5 * math.sin(t * 2.4 + it.ph);
  _star(0, -49, 16 + 4 * pulse, 0.35 + 0.35 * pulse);
  _fs(_trStar, const Color(0xFFFFE6A0), const Color(0xFFA8731E), 3);
}

// ── Снежные шары ──────────────────────────────────────────────────────────

const double _sgR = 34, _sgY = -6;
const Color _sgDark = Color(0xFF5A1018);
final Path _sgBase = _poly(const [-28, 26, 28, 26, 36, 46, -36, 46]);
final Path _sgBand = _rect(-32, 34, 64, 4.5);
final Path _sgGlass = _circle(0, _sgY, _sgR);
final Path _sgGround = _and(_ell(0, _sgY + 28, 34, 12), _sgGlass);
final Path _sgHouse = _rect(-12, 6, 24, 16);
final Path _sgRoof = _poly(const [-16, 7, 0, -7, 16, 7]);
final Path _sgWindow = _rect(-8, 10, 6, 5);
final Path _sgDoor = _rect(3, 12, 5, 10);
final Path _sgTree = _poly(const [
  0,
  -12,
  12,
  4,
  6,
  4,
  15,
  18,
  -15,
  18,
  -6,
  4,
  -12,
  4,
]);
final Path _sgTrunk = _rect(-2.5, 18, 5, 4);
final Path _sgGlint = Path()
  ..addArc(
    Rect.fromCircle(center: const Offset(0, _sgY), radius: _sgR - 6),
    _pi * 1.1,
    _pi * 0.3,
  );
final Path _sgShine = _ell(14, _sgY - 18, 2.4, 2.4);

void _snowglobe(_It it, double t) {
  final cc = _cyc(t, it.ph, 7);
  final shake = cc < 0.7 ? math.sin(cc * 30) * 0.12 * (1 - cc / 0.7) : 0.0;
  if (shake != 0) _c.rotate(shake);
  _fs(_sgBase, const Color(0xFF7A4A2A), const Color(0xFF3E2414), 4.5);
  _f(_sgBand, const Color(0xFFD2303F));
  _f(_sgGlass, const Color.fromRGBO(190, 225, 255, 0.25));
  _f(_sgGround, _white);
  if (it.c == 0) {
    _fs(_sgHouse, const Color(0xFFC8283C), _sgDark, 2.5);
    _fs(_sgRoof, _white, _sgDark, 2.5);
    _f(
      _sgWindow,
      (0.8 + 0.2 * math.sin(t * 7 + it.ph)) > 0.7
          ? const Color(0xFFFFD84D)
          : const Color(0xFFE0B23A),
    );
    _f(_sgDoor, _sgDark);
  } else {
    _fs(_sgTree, const Color(0xFF2E8B57), const Color(0xFF123F27), 2.5);
    _f(_sgTrunk, const Color(0xFF7A4A2A));
    _dot(0, -13, 2.6, const Color(0xFFFFE6A0));
  }
  // Снег внутри: взлетает при встряске и оседает. Хлопья вне стекла не
  // рисуются (вместо выреза по стеклу) — одним контуром.
  _tmp.reset();
  var any = false;
  for (var k = 0; k < 18; k++) {
    final x0 = ((k * 37) % 60) - 30.0;
    final top = _sgY - _sgR + 8 + ((k * 13) % 22);
    final gr = _sgY + 22 - (k % 3) * 2;
    final u = cc < 0.7 ? 0.0 : math.min(1.0, (cc - 0.7) / (3 + (k % 4) * 0.8));
    final y = cc < 0.7
        ? gr + (top - gr) * (cc / 0.7)
        : top + (gr - top) * _ez(u);
    final x = x0 + math.sin(t * 1.5 + k) * 4 * (1 - u);
    final dy = y - _sgY;
    if (x * x + dy * dy >= _sgR * _sgR) continue;
    _tmp.addOval(
      Rect.fromCircle(center: Offset(x, y), radius: 1.5 + (k % 2) * 0.5),
    );
    any = true;
  }
  if (any) _f(_tmp, _white);
  _ring(0, _sgY, _sgR, const Color(0xFF3E5A74), 4.5);
  _s(_sgGlint, _white, 3.5, 0.55);
  _shine(_sgShine, 0.7);
}

// ── Армиллярная сфера (линии) ─────────────────────────────────────────────

double _aCp = 1, _aSp = 0, _aCs = 1, _aSs = 0, _aCx = 0, _aCy = 0;
double _px = 0, _py = 0, _pz = 0;

/// Проекция точки сферы на экран (макет `pr`): поворот вокруг оси и наклон.
void _proj(double x, double y, double z) {
  final x1 = x * _aCp + z * _aSp, z1 = -x * _aSp + z * _aCp;
  _px = _aCx + x1;
  _py = _aCy + y * _aCs - z1 * _aSs;
  _pz = y * _aSs + z1 * _aCs;
}

final Float64List _bufZ = Float64List(256);

void _armRing(
  PatternExtraFrame f,
  List<double> u,
  List<double> v,
  double r,
  double a,
  double lw,
  Color col,
) {
  for (var k = 0; k <= 96; k++) {
    final q = k / 96 * _pi * 2, cq = math.cos(q), sq = math.sin(q);
    _proj(
      r * (cq * u[0] + sq * v[0]),
      r * (cq * u[1] + sq * v[1]),
      r * (cq * u[2] + sq * v[2]),
    );
    _bufA[k * 2] = _px;
    _bufA[k * 2 + 1] = _py;
    _bufZ[k] = _pz;
  }
  _lines.begin(col, lw);
  for (var i = 0; i < 96; i++) {
    final x0 = _bufA[i * 2], y0 = _bufA[i * 2 + 1];
    final x1 = _bufA[i * 2 + 2], y1 = _bufA[i * 2 + 3];
    final depth = 0.3 + 0.7 * ((_bufZ[i] + _bufZ[i + 1]) / 2 / r + 1) / 2;
    final al = _vis(f, (x0 + x1) / 2, (y0 + y1) / 2, a * depth, 56);
    _lines.seg(x0, y0, x1, y1, al);
  }
}

void _paintArmillary(PatternExtraFrame f, _Pal pal) {
  final t = f.t, ink = pal.ink;
  final r = 146 * f.bands[2];
  final phi = t * 0.12;
  const psi = 0.38;
  _aCp = math.cos(phi);
  _aSp = math.sin(phi);
  _aCs = math.cos(psi);
  _aSs = math.sin(psi);
  _aCx = f.cx;
  _aCy = f.cy;
  const ex = [1.0, 0.0, 0.0], ez = [0.0, 0.0, 1.0];
  _armRing(f, ex, ez, r * 1.14, 0.2, 2.4, ink);
  // Деления горизонта: каждое третье длиннее.
  _lines.begin(ink, 1);
  for (var k = 0; k < 36; k++) {
    final q = k / 36 * _pi * 2, cq = math.cos(q), sq = math.sin(q);
    _proj(cq * r * 1.14, 0, sq * r * 1.14);
    final x0 = _px, y0 = _py, z0 = _pz;
    final r1 = r * (k % 3 != 0 ? 1.18 : 1.22);
    _proj(cq * r1, 0, sq * r1);
    final al = _vis(
      f,
      x0,
      y0,
      0.24 * (0.3 + 0.7 * (z0 / r / 1.14 + 1) / 2),
      56,
    );
    _lines.seg(x0, y0, _px, _py, al);
  }
  _armRing(f, ex, ez, r, 0.3, 1.3, ink);
  for (var k = 0; k < 3; k++) {
    final al = k * _pi / 3;
    _armRing(
      f,
      [math.cos(al), 0, math.sin(al)],
      const [0, 1, 0],
      r,
      0.28,
      1.2,
      ink,
    );
  }
  const ep = 0.41;
  final ev = [0.0, math.sin(ep), math.cos(ep)];
  _armRing(f, ex, ev, r * 0.97, 0.42, 1.1, pal.acc);
  _armRing(f, ex, ev, r * 1.03, 0.42, 1.1, pal.acc);
  // Ось — от полюса до аватара.
  _proj(0, -r * 1.32, 0);
  _lines.begin(ink, 1);
  _lines.seg(_px, _py, f.cx, f.cy - 66, f.ga * f.fy(_py) * 0.24);
  _lines.flush();
  // Медная бусина идёт по эклиптике.
  final bq = t * 0.3, cb = math.cos(bq), sb = math.sin(bq);
  _proj(
    r * (cb * ex[0] + sb * ev[0]),
    r * (cb * ex[1] + sb * ev[1]),
    r * (cb * ex[2] + sb * ev[2]),
  );
  final bal = _vis(f, _px, _py, 0.95 * (0.35 + 0.65 * (_pz / r + 1) / 2), 56);
  if (bal > 0.01) {
    _fill.color = _op(pal.acc, bal);
    _c.drawCircle(Offset(_px, _py), 4.2, _fill);
    _fill.color = _op(_white, bal * 0.7);
    _c.drawCircle(Offset(_px - 1.3, _py - 1.3), 1.3, _fill);
  }
}

// ── Механизм (линии) ──────────────────────────────────────────────────────

double _mx = 0, _my = 0;

/// Точка от центра аватара с растяжением своей полосы (макет `map`).
void _map(PatternExtraFrame f, double lx, double ly) {
  final b = f.band(math.sqrt(lx * lx + ly * ly));
  _mx = f.cx + lx * b;
  _my = f.cy + ly * b;
}

void _jewel(PatternExtraFrame f, _Pal pal, double gx, double gy, double r) {
  _map(f, gx, gy);
  final x = _mx, y = _my;
  final al = _vis(f, x, y, 1, 60);
  if (al < 0.01) return;
  _lines.flush();
  _fill.color = _op(pal.acc, al * 0.95);
  _c.drawCircle(Offset(x, y), r, _fill);
  _fill.color = _op(_white, al * 0.8);
  _c.drawCircle(Offset(x - r * 0.35, y - r * 0.35), r * 0.32, _fill);
  _line
    ..color = _op(pal.ink, al * 0.35)
    ..strokeWidth = 1;
  _c.drawCircle(Offset(x, y), r + 2.2, _line);
}

void _gear(
  PatternExtraFrame f,
  _Pal pal,
  double gx,
  double gy,
  double r,
  int n,
  double rot,
  int spokes,
) {
  final ink = pal.ink;
  _lines.begin(ink, 1.2);
  final w = _pi / n;
  for (var k = 0; k < n; k++) {
    final a0 = rot + k / n * _pi * 2;
    // Зуб: пять точек (подъём, вершина, спуск, впадина).
    const fr = [-0.5, -0.28, 0.28, 0.5, 1.5];
    for (var i = 0; i < 5; i++) {
      final a = a0 + w * fr[i], rr = (i == 1 || i == 2) ? r : r - 3.8;
      _map(f, gx + math.cos(a) * rr, gy + math.sin(a) * rr);
      _bufB[i * 2] = _mx;
      _bufB[i * 2 + 1] = _my;
    }
    final al = _vis(f, _bufB[2], _bufB[3], 0.36, 60);
    if (al < 0.004) continue;
    for (var i = 1; i < 5; i++) {
      _lines.seg(
        _bufB[i * 2 - 2],
        _bufB[i * 2 - 1],
        _bufB[i * 2],
        _bufB[i * 2 + 1],
        al,
      );
    }
  }
  if (spokes == 0) return;
  _circLine(f, gx, gy, r * 0.72, 0.3, 1.1, ink, 48, 60);
  _circLine(f, gx, gy, r * 0.2, 0.34, 1.1, ink, 24, 60);
  for (var k = 0; k < spokes; k++) {
    final a = rot + k / spokes * _pi * 2, ca = math.cos(a), sa = math.sin(a);
    _map(f, gx + ca * r * 0.2, gy + sa * r * 0.2);
    _bufA[0] = _mx;
    _bufA[1] = _my;
    _map(f, gx + ca * r * 0.72, gy + sa * r * 0.72);
    _bufA[2] = _mx;
    _bufA[3] = _my;
    _polyLine(f, 2, 0.3, 2.2, ink, 60);
  }
  _jewel(f, pal, gx, gy, 3.2);
}

void _paintMovement(PatternExtraFrame f, _Pal pal) {
  final t = f.t, ink = pal.ink;
  // Колёса идут шагами: пять в секунду, каждый с мягкой остановкой.
  final q = (t * 5) % 1;
  final e = 1 - math.pow(1 - math.min(1.0, q * 5), 3).toDouble();
  final th1 = ((t * 5).floorToDouble() + e) * (_pi * 2 / 300);
  _gear(f, pal, 0, 0, 106, 64, th1, 0);
  _circLine(f, 0, 0, 90, 0.28, 1.1, ink, 96, 60);
  _circLine(f, 0, 0, 97, 0.16, 1, ink, 96, 60);
  for (final a in const [0.6, 2.7, 4.6]) {
    _jewel(f, pal, math.cos(a + th1) * 93.5, math.sin(a + th1) * 93.5, 2.6);
  }
  _gear(f, pal, 137, 35, 40, 26, -th1 * 106 / 40 + _pi / 26, 5);
  _gear(f, pal, -128, -19, 30, 20, -th1 * 106 / 30, 4);
  _gear(f, pal, 149, 93, 22, 14, th1 * 106 / 22, 4);
  // Балансир: пять качаний в секунду, спираль дышит.
  final bal = 1.25 * math.sin(t * _pi * 2 * 2.5);
  const bx = -152.0, by = 66.0;
  _circLine(f, bx, by, 26, 0.4, 2.2, ink, 48, 60);
  _circLine(f, bx, by, 22, 0.18, 1, ink, 48, 60);
  for (var k = 0; k < 3; k++) {
    final a = bal + k / 3 * _pi * 2;
    _map(f, bx, by);
    _bufA[0] = _mx;
    _bufA[1] = _my;
    _map(f, bx + math.cos(a) * 22, by + math.sin(a) * 22);
    _bufA[2] = _mx;
    _bufA[3] = _my;
    _polyLine(f, 2, 0.34, 1.6, ink, 60);
  }
  for (var k = 0; k <= 90; k++) {
    final u = k / 90, a = u * _pi * 2 * 3.2 + bal * 0.6;
    final r = 3 + u * 13 * (1 + 0.06 * math.sin(bal));
    _map(f, bx + math.cos(a) * r, by + math.sin(a) * r);
    _bufA[k * 2] = _mx;
    _bufA[k * 2 + 1] = _my;
  }
  _polyLine(f, 91, 0.26, 0.9, ink, 60);
  _jewel(f, pal, bx, by, 2.6);
}
