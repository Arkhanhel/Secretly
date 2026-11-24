// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Вторая волна обложек-узоров (макет «Profile Motion», 22.11.2026):
/// «Светлячки», «Отпечаток S», «Газировка», «Бургеры», «Самолётики»,
/// «Шарики», «Кофе с собой», «Пончики», «Мороженое», «Попкорн», «Масти».
///
/// Движение то же, что у первых десяти ([PatternCoverInput] и шесть полос
/// [PatternCoverBands]): тянешь — расходятся, раскрыл фото — разлетаются и
/// гаснут, прокрутка — стягиваются к аватару; вокруг аватара пустое кольцо,
/// ниже линии кнопок узор гаснет.
///
/// Скорость. Каждый узор рисуется ОДНИМ вызовом `drawRawAtlas` (кроме
/// самолётиков — их 11, и пузырьков газировки): все знаки, бутылки,
/// стаканчики, наклейки и светлячки заранее отрисованы в «лист спрайтов»
/// (один раз на узор и тему, `Picture.toImageSync`), а за кадр заполняются
/// только готовые числовые буферы. Ни `saveLayer`, ни построения путей за
/// кадр. Светлячков до 1300; если расчёт кадра дороже ~1,5 мс, их число само
/// уменьшается (не ниже 450).
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/painting.dart';

import '../gpu_image_guard.dart';
import 'pattern_cover.dart';
import 's_mark_shape.dart';

// ── Кадр ──────────────────────────────────────────────────────────────────

/// Всё, что нужно узору на кадр (координаты макета 390 по ширине).
class PatternExtraFrame {
  PatternExtraFrame({
    required this.t,
    required this.bands,
    required this.cx,
    required this.cy,
    required this.fadeY,
    required this.p,
    required this.ga,
    required this.k,
    required this.ink,
  }) : dark = ink.r + ink.g + ink.b > 1.5;

  /// Секунды с начала.
  final double t;
  final List<double> bands;
  final double cx, cy;

  /// Линия, ниже которой узор гаснет за 50 px.
  final double fadeY;

  /// Натяжение 0…(pull/240).
  final double p;

  /// Общая видимость (раскрытие фото и прокрутка).
  final double ga;

  /// Сила цвета темы (светлая — 0,7).
  final double k;
  final Color ink;
  final bool dark;

  /// Строка имени (макет: имя на 75 px выше линии затухания).
  double get nameY => fadeY - 75;

  double fy(double y) => _cl((fadeY - y) / 50);

  /// Прозрачность знака на высоте [y] (как `alpha()` макета).
  double alpha(double y, double a) {
    final al = a * ga * k * fy(y);
    if (al <= 0.003) return 0;
    return al > 1 ? 1 : al;
  }

  /// Под именем знаки прозрачнее (макет: `textGap`).
  double textGap(double x, double y) {
    final hx = 1 - (x - cx).abs() / 130;
    if (hx <= 0) return 1;
    final hy = _cl(1 - ((y - (nameY + 22)).abs() - 26) / 22);
    return 1 - 0.75 * hx * hy;
  }

  double band(double d) => bands[_bandOf(d)];
}

double _cl(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

int _bandOf(double d) {
  final b = (d / 55).floor();
  return b < 0 ? 0 : (b > 5 ? 5 : b);
}

double _halo(double d, double a, double b, double f) =>
    _cl((d - a) / 40) * (1 - _cl((d - b) / f));

double _hyp(double x, double y) => math.sqrt(x * x + y * y);

/// Генератор макета (`seed = seed·16807 mod 2³¹−1`, начало 7) — раскладки
/// совпадают с макетом.
class _Rnd {
  _Rnd([this.seed = 7]);
  int seed;
  double call() {
    seed = (seed * 16807) % 2147483647;
    return seed / 2147483647;
  }
}

// ── Лист спрайтов ─────────────────────────────────────────────────────────

/// Плотность спрайтов: пикселей листа на логический пиксель (экраны до 3×).
const double _kSpriteDensity = 3;

class _Cell {
  _Cell(this.l, this.t, this.r, this.b, this.ux, this.uy, this.ppu);

  /// Прямоугольник в листе, px.
  final double l, t, r, b;

  /// Точка привязки (начало координат рисунка) от левого верхнего угла.
  final double ux, uy;

  /// Пикселей листа на единицу рисунка.
  final double ppu;
}

class _Atlas {
  _Atlas(this.image, this.cells);
  final ui.Image image;
  final List<_Cell> cells;
}

typedef _Draw = void Function(Canvas c);

class _AtlasBuilder {
  final List<(Rect, double, _Draw)> _items = [];

  /// Ячейка: [bounds] — рамка рисунка в его единицах, [ppu] — пикселей на
  /// единицу. Возвращает номер ячейки.
  int add(Rect bounds, double ppu, _Draw draw) {
    _items.add((bounds, ppu, draw));
    return _items.length - 1;
  }

  _Atlas build() {
    const pad = 2.0;
    const maxW = 1024.0;
    var x = 0.0, y = 0.0, rowH = 0.0, w = 1.0;
    final placed = <(double, double, double, double)>[];
    for (final (b, ppu, _) in _items) {
      final cw = (b.width * ppu).ceilToDouble() + pad * 2;
      final ch = (b.height * ppu).ceilToDouble() + pad * 2;
      if (x + cw > maxW && x > 0) {
        x = 0;
        y += rowH;
        rowH = 0;
      }
      placed.add((x, y, cw, ch));
      x += cw;
      rowH = math.max(rowH, ch);
      w = math.max(w, x);
    }
    final h = math.max(1.0, y + rowH);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final cells = <_Cell>[];
    for (var i = 0; i < _items.length; i++) {
      final (b, ppu, draw) = _items[i];
      final (px, py, cw, ch) = placed[i];
      final ux = pad - b.left * ppu, uy = pad - b.top * ppu;
      c.save();
      c.clipRect(Rect.fromLTWH(px + pad, py + pad, cw - pad * 2, ch - pad * 2));
      c.translate(px + ux, py + uy);
      c.scale(ppu);
      draw(c);
      c.restore();
      cells.add(_Cell(px, py, px + cw, py + ch, ux, uy, ppu));
    }
    final pic = rec.endRecording();
    final img = pic.toImageSync(w.ceil(), h.ceil());
    pic.dispose();
    return _Atlas(img, cells);
  }
}

/// Готовые листы: по узору и цвету темы. Небольшой кэш — старые
/// освобождаются (картинка живёт, пока её держит уже записанный кадр).
final Map<String, _Atlas> _atlases = {};
const int _kAtlasCache = 8;
bool _atlasesGuarded = false;

_Atlas _atlas(PatternCoverStyle style, PatternExtraFrame f) {
  final key = '${style.index}:${f.ink.toARGB32()}';
  final hit = _atlases.remove(key);
  if (hit != null) {
    _atlases[key] = hit;
    return hit;
  }
  if (!_atlasesGuarded) {
    _atlasesGuarded = true;
    GpuImageGuard.register(_atlases.clear);
  }
  final built = _buildAtlas(style, f.ink, f.dark);
  _atlases[key] = built;
  while (_atlases.length > _kAtlasCache) {
    // Без dispose: лист может держать уже записанный кадр.
    _atlases.remove(_atlases.keys.first);
  }
  return built;
}

/// Буферы одного вызова `drawRawAtlas`: растут один раз, за кадр не
/// создаются.
class _Batch {
  Float32List _xf = Float32List(0);
  Float32List _rc = Float32List(0);
  Int32List _col = Int32List(0);
  int n = 0;

  void _grow(int cap) {
    final xf = Float32List(cap * 4), rc = Float32List(cap * 4);
    final col = Int32List(cap);
    xf.setRange(0, n * 4, _xf);
    rc.setRange(0, n * 4, _rc);
    col.setRange(0, n, _col);
    _xf = xf;
    _rc = rc;
    _col = col;
  }

  /// Спрайт [c] с началом рисунка в ([x], [y]); [unit] — логических px на
  /// единицу рисунка, [rot] — поворот, [alpha] — прозрачность.
  void add(_Cell c, double x, double y, double unit, double rot, double alpha) {
    if (alpha <= 0.003 || unit <= 0) return;
    if (n >= _col.length) _grow(math.max(64, _col.length * 2));
    final s = unit / c.ppu;
    var sc = s, ss = 0.0;
    if (rot != 0) {
      sc = s * math.cos(rot);
      ss = s * math.sin(rot);
    }
    final o = n * 4;
    _xf[o] = sc;
    _xf[o + 1] = ss;
    _xf[o + 2] = x - sc * c.ux + ss * c.uy;
    _xf[o + 3] = y - ss * c.ux - sc * c.uy;
    _rc[o] = c.l;
    _rc[o + 1] = c.t;
    _rc[o + 2] = c.r;
    _rc[o + 3] = c.b;
    final a = ((alpha > 1 ? 1.0 : alpha) * 255).round();
    _col[n] = (a << 24) | 0x00FFFFFF;
    n++;
  }

  void flush(Canvas canvas, ui.Image img, Paint paint) {
    if (n == 0) return;
    canvas.drawRawAtlas(
      img,
      Float32List.sublistView(_xf, 0, n * 4),
      Float32List.sublistView(_rc, 0, n * 4),
      Int32List.sublistView(_col, 0, n),
      BlendMode.modulate,
      null,
      paint,
    );
    n = 0;
  }
}

final _Batch _batch = _Batch();
final Paint _atlasPaint = Paint()..filterQuality = FilterQuality.low;
final Paint _atlasPlus = Paint()
  ..filterQuality = FilterQuality.low
  ..blendMode = BlendMode.plus;

// ── Рисунки (один раз, в лист) ────────────────────────────────────────────

Color _rgb(int r, int g, int b, [double a = 1]) => Color.fromRGBO(r, g, b, a);

Paint _fillP(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Paint _strokeP(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = true;

void _shape(Canvas c, Path p, Color fill, Color line, [double lw = 5]) {
  c.drawPath(p, _fillP(fill));
  c.drawPath(p, _strokeP(line, lw));
}

void _shine(Canvas c, double x, double y, double rx, double ry, double r) {
  c.save();
  c.translate(x, y);
  c.rotate(r);
  c.drawOval(
    Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
    _fillP(const Color(0x8CFFFFFF)),
  );
  c.restore();
}

Path _rr(double x, double y, double w, double h, double r) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
  );

/// Буква S логотипа (контуры из `s_mark_shape.dart`, высота 1).
final Path _sMarkPath = () {
  final p = Path()..fillType = PathFillType.evenOdd;
  for (final c in kSMarkContours) {
    p.moveTo(c[0], c[1]);
    for (var i = 2; i + 1 < c.length; i += 2) {
      p.lineTo(c[i], c[i + 1]);
    }
    p.close();
  }
  return p;
}();

final Rect _sMarkBounds = Rect.fromLTRB(
  -kSMarkAspect / 2 - 0.03,
  -0.53,
  kSMarkAspect / 2 + 0.03,
  0.53,
);

int _addDot(_AtlasBuilder b, Color ink) => b.add(
  const Rect.fromLTRB(-1.2, -1.2, 1.2, 1.2),
  6,
  (c) => c.drawCircle(Offset.zero, 1, _fillP(ink)),
);

/// Масти в квадрате 1×1 (как `glyph()` макета при s = 1).
Path _suitPath(int i) {
  final p = Path();
  switch (i) {
    case 0: // пики
      p
        ..moveTo(0, -0.4)
        ..cubicTo(-0.56, 0.02, -0.26, 0.38, 0, 0.12)
        ..cubicTo(0.26, 0.38, 0.56, 0.02, 0, -0.4)
        ..close()
        ..moveTo(0, 0.06)
        ..lineTo(0.14, 0.42)
        ..lineTo(-0.14, 0.42)
        ..close();
    case 1: // черви
      p
        ..moveTo(0, 0.36)
        ..cubicTo(-0.56, -0.04, -0.3, -0.5, 0, -0.2)
        ..cubicTo(0.3, -0.5, 0.56, -0.04, 0, 0.36)
        ..close();
    case 2: // бубны
      const h = 0.24;
      p
        ..moveTo(0, -h)
        ..lineTo(h, 0)
        ..lineTo(0, h)
        ..lineTo(-h, 0)
        ..close();
    default: // трефы
      const r = 0.17;
      for (final (a, b) in const [(0.0, -0.2), (-0.19, 0.06), (0.19, 0.06)]) {
        p.addOval(Rect.fromCircle(center: Offset(a, b), radius: r));
      }
      p
        ..moveTo(0, 0)
        ..lineTo(0.14, 0.42)
        ..lineTo(-0.14, 0.42)
        ..close();
  }
  return p;
}

/// Бутылка газировки (единицы макета: высота 100). Прозрачности частей
/// запечены относительно этикетки-полосок (×3,2 в макете).
void _drawBottle(Canvas c, Color ink, bool dark) {
  const m = 3.2;
  final red = dark ? _rgb(224, 74, 64) : _rgb(204, 46, 42);
  final body = Path()
    ..moveTo(-5.5, -44)
    ..lineTo(-5.5, -30)
    ..cubicTo(-5.5, -19, -15, -18, -15, -6)
    ..lineTo(-15, 40)
    ..quadraticBezierTo(-15, 48, -7, 48)
    ..lineTo(7, 48)
    ..quadraticBezierTo(15, 48, 15, 40)
    ..lineTo(15, -6)
    ..cubicTo(15, -18, 5.5, -19, 5.5, -30)
    ..lineTo(5.5, -44);
  final line = ink.withValues(alpha: 1 / m);
  c.drawPath(body, _strokeP(line, 2.6));
  c.drawRect(const Rect.fromLTWH(-7.5, -50, 15, 6), _fillP(line));
  c.drawLine(
    const Offset(-9.5, 30),
    const Offset(-9.5, 41),
    _strokeP(ink.withValues(alpha: 0.7 / m), 2.6),
  );
  c.drawRect(
    const Rect.fromLTWH(-15, 4, 30, 21),
    _fillP(red.withValues(alpha: 2.4 / m)),
  );
  final stripes = _strokeP(const Color(0xFFFFFFFF), 2.2);
  const hs = [7.0, 11.0, 6.0, 12.0, 9.0, 6.0];
  for (var i = 0; i < hs.length; i++) {
    final xx = -10.5 + i * 4.2;
    c.drawLine(
      Offset(xx, 14.5 - hs[i] / 2),
      Offset(xx + 1.2, 14.5 + hs[i] / 2),
      stripes,
    );
  }
}

/// Стаканчик кофе без пара (единицы макета: высота 100). Прозрачности
/// запечены относительно точек на держателе (×2 в макете).
void _drawCup(Canvas c, Color ink, bool dark) {
  const m = 2.0;
  final sleeve = dark ? _rgb(176, 120, 80) : _rgb(150, 95, 55);
  final body = Path()
    ..moveTo(-24, -34)
    ..lineTo(24, -34)
    ..lineTo(18, 46)
    ..lineTo(-18, 46)
    ..close();
  c.drawPath(body, _strokeP(ink.withValues(alpha: 1 / m), 2.6));
  final lid = _fillP(ink.withValues(alpha: 1.3 / m));
  c.drawPath(_rr(-28, -42, 56, 9, 3), lid);
  c.drawPath(_rr(-19, -49, 38, 7, 3), lid);
  c.drawPath(
    Path()
      ..moveTo(-21.6, -4)
      ..lineTo(21.6, -4)
      ..lineTo(19.7, 22)
      ..lineTo(-19.7, 22)
      ..close(),
    _fillP(sleeve.withValues(alpha: 1.6 / m)),
  );
  final dots = _fillP(const Color(0xFFFFFFFF));
  for (var i = -2; i <= 2; i++) {
    c.drawCircle(Offset(i * 7.0, 9), 1.8, dots);
  }
}

const int _kSteamFrames = 24;

/// Струйка пара: основание в (0, 0), вверх на 34. Кадр [k] из
/// [_kSteamFrames] — фаза волны.
void _drawSteam(Canvas c, Color ink, int k) {
  final ph = k / _kSteamFrames * math.pi * 2;
  final p = Path();
  for (var yy = 0; yy <= 34; yy += 2) {
    final px = 4 * math.sin(yy * 0.22 - ph);
    yy == 0 ? p.moveTo(px, 0) : p.lineTo(px, -yy.toDouble());
  }
  c.drawPath(p, _strokeP(ink, 2.2));
}

const List<List<int>> _kBalloonDark = [
  [236, 100, 100],
  [244, 182, 84],
  [100, 180, 236],
  [140, 210, 130],
  [190, 146, 240],
];
const List<List<int>> _kBalloonLight = [
  [222, 72, 72],
  [232, 156, 40],
  [50, 146, 214],
  [86, 170, 86],
  [150, 100, 220],
];
const int _kStringLevels = 17;

/// Шарик (единица — радиус): тело, узелок, блик. Прозрачности относительно
/// тела (×2,6 в макете).
void _drawBalloon(Canvas c, Color col) {
  final body = _fillP(col);
  c.drawOval(
    Rect.fromCenter(center: Offset.zero, width: 1.72, height: 2),
    body,
  );
  c.drawPath(
    Path()
      ..moveTo(-0.13, 1.08)
      ..lineTo(0.13, 1.08)
      ..lineTo(0, 0.94)
      ..close(),
    body,
  );
  c.save();
  c.translate(-0.34, -0.42);
  c.rotate(-0.5);
  c.drawOval(
    Rect.fromCenter(center: Offset.zero, width: 0.28, height: 0.52),
    _fillP(Color.fromRGBO(255, 255, 255, 2.2 / 2.6)),
  );
  c.restore();
}

/// Ниточка шарика при покачивании [sway] (единица — радиус).
void _drawString(Canvas c, Color ink, double sway) {
  c.drawPath(
    Path()
      ..moveTo(0, 1.08)
      ..cubicTo(sway * 2, 1.8, -sway * 2, 2.4, sway, 3.2),
    _strokeP(ink, 1 / 13),
  );
}

/// Наклейки (единицы макета: лист 130×130, центр в нуле).
void _drawToon(Canvas g, PatternCoverStyle mode, int c) {
  switch (mode) {
    case PatternCoverStyle.burgers:
      const l = Color(0xFF5A2E14);
      _shape(g, _rr(-40, 14, 80, 22, 11), const Color(0xFFE9A24A), l);
      _shape(g, _rr(-45, 2, 90, 17, 8.5), const Color(0xFF7B4126), l);
      _shape(
        g,
        Path()
          ..moveTo(-43, -1)
          ..lineTo(43, -1)
          ..lineTo(39, 8)
          ..lineTo(25, 8)
          ..quadraticBezierTo(19, 22, 13, 8)
          ..lineTo(-18, 8)
          ..quadraticBezierTo(-24, 17, -30, 8)
          ..lineTo(-40, 8)
          ..close(),
        const Color(0xFFFFC83A),
        l,
        4,
      );
      final lettuce = Path()..moveTo(-47, -2);
      for (var i = 0; i < 8; i++) {
        lettuce.quadraticBezierTo(
          -47 + i * 11.75 + 5.9,
          i.isOdd ? 6 : -9,
          -47 + (i + 1) * 11.75,
          -2,
        );
      }
      lettuce
        ..lineTo(47, -6)
        ..lineTo(-47, -6)
        ..close();
      _shape(g, lettuce, const Color(0xFF63C95A), const Color(0xFF2F6B2A), 4);
      _shape(
        g,
        Path()
          ..moveTo(-45, -4)
          ..cubicTo(-45, -50, 45, -50, 45, -4)
          ..close(),
        const Color(0xFFF4B259),
        l,
      );
      _shine(g, -17, -28, 12, 5, -0.4);
      final seed = _fillP(const Color(0xFFFFF3D9));
      for (final (x, y, r) in const [
        (-4.0, -34.0, 0.3),
        (14.0, -27.0, -0.5),
        (-24.0, -17.0, 0.6),
        (4.0, -18.0, -0.2),
        (26.0, -14.0, 0.4),
        (-10.0, -24.0, -0.6),
      ]) {
        g.save();
        g.translate(x, y);
        g.rotate(r);
        g.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 8, height: 4.4),
          seed,
        );
        g.restore();
      }
    case PatternCoverStyle.donuts:
      const glaze = [
        Color(0xFFFF7EB6),
        Color(0xFF6B3B2A),
        Color(0xFF7FE0C4),
        Color(0xFFB79CFF),
      ];
      const gl = [
        Color(0xFFC2407A),
        Color(0xFF3A1E14),
        Color(0xFF2F9C80),
        Color(0xFF6F52C8),
      ];
      final dough = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: 42))
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: 14));
      _shape(g, dough, const Color(0xFFE9A866), const Color(0xFF7A4A22));
      final icing = Path()..fillType = PathFillType.evenOdd;
      for (var i = 0; i <= 64; i++) {
        final a = i / 64 * math.pi * 2;
        final r = 35 + 3.5 * math.sin(a * 9) + 2 * math.sin(a * 4 + 1);
        i == 0
            ? icing.moveTo(math.cos(a) * r, math.sin(a) * r)
            : icing.lineTo(math.cos(a) * r, math.sin(a) * r);
      }
      icing
        ..close()
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: 18));
      _shape(g, icing, glaze[c], gl[c], 3.5);
      const cols = [
        Color(0xFFFFFFFF),
        Color(0xFFFFD84D),
        Color(0xFF5CC8FF),
        Color(0xFF7CF29A),
        Color(0xFFFF5A5A),
        Color(0xFFFFFFFF),
      ];
      for (var i = 0; i < 14; i++) {
        final a = i * 2.39996 + c, r = 22.0 + (i * 37 % 10);
        final x = math.cos(a) * r, y = math.sin(a) * r, o = i * 1.3;
        g.drawLine(
          Offset(x - math.cos(o) * 3.5, y - math.sin(o) * 3.5),
          Offset(x + math.cos(o) * 3.5, y + math.sin(o) * 3.5),
          _strokeP(cols[i % cols.length], 4.5),
        );
      }
      g.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 29),
        math.pi * 1.08,
        math.pi * 0.34,
        false,
        _strokeP(const Color(0x99FFFFFF), 4),
      );
    case PatternCoverStyle.icecream:
      const fl = [
        [
          Color(0xFFFF9EC4),
          Color(0xFFC2457A),
          Color(0xFF9BE7D0),
          Color(0xFF2F9C80),
        ],
        [
          Color(0xFFFFE6A8),
          Color(0xFFB98A2E),
          Color(0xFF8B5A3C),
          Color(0xFF4A2A18),
        ],
        [
          Color(0xFFB9A4FF),
          Color(0xFF6A50C8),
          Color(0xFFFF9EC4),
          Color(0xFFC2457A),
        ],
      ];
      final f = fl[c];
      final cone = Path()
        ..moveTo(-23, 2)
        ..lineTo(23, 2)
        ..lineTo(0, 56)
        ..close();
      g.save();
      _shape(g, cone, const Color(0xFFEDB06A), const Color(0xFF7A4A22));
      g.clipPath(cone);
      final waffle = _strokeP(const Color(0xFFB97A3A), 2.5);
      for (var i = -6; i <= 6; i++) {
        g.drawLine(Offset(i * 9.0 - 30, 0), Offset(i * 9.0 + 30, 60), waffle);
        g.drawLine(Offset(i * 9.0 + 30, 0), Offset(i * 9.0 - 30, 60), waffle);
      }
      g.restore();
      g.drawPath(cone, _strokeP(const Color(0xFF7A4A22), 5));
      void scoop(double y, double r, Color fill, Color line) {
        final s = Path()
          ..arcTo(
            Rect.fromCircle(center: Offset(0, y), radius: r),
            math.pi * 0.92,
            math.pi * 1.16,
            true,
          );
        const n = 5;
        for (var i = 0; i <= n; i++) {
          final x = r * 0.98 - (2 * r * 0.98) * i / n;
          s.quadraticBezierTo(
            x + r * 0.2,
            y + r * 0.62 + (i.isOdd ? 7 : 0),
            x,
            y + r * 0.42,
          );
        }
        s.close();
        _shape(g, s, fill, line, 4.5);
      }

      scoop(-8, 25, f[0], f[1]);
      scoop(-34, 19, f[2], f[3]);
      _shine(g, -10, -16, 7, 4, -0.5);
      _shine(g, -7, -40, 5, 3, -0.5);
      g.drawPath(
        Path()
          ..moveTo(3, -56)
          ..quadraticBezierTo(8, -66, 16, -68),
        _strokeP(const Color(0xFF3F6B2A), 3.5),
      );
      _shape(
        g,
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(2, -52), radius: 7)),
        const Color(0xFFFF4B5C),
        const Color(0xFF9A1F2E),
        3.5,
      );
      _shine(g, 0, -54, 2.2, 1.5, 0);
    case PatternCoverStyle.popcorn:
      const l = Color(0xFF8A1F2B);
      for (final (x, y, r) in const [
        (-20.0, -16.0, 12.0),
        (0.0, -22.0, 14.0),
        (20.0, -16.0, 12.0),
        (-10.0, -32.0, 12.0),
        (11.0, -33.0, 12.0),
        (0.0, -45.0, 11.0),
        (-26.0, -4.0, 9.0),
        (26.0, -4.0, 9.0),
      ]) {
        _shape(
          g,
          Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r)),
          const Color(0xFFFFF4CC),
          const Color(0xFFC79A3A),
          3.5,
        );
        g.drawCircle(
          Offset(x + r * 0.25, y + r * 0.3),
          r * 0.42,
          _fillP(const Color(0xB3FFD66B)),
        );
      }
      final cup = Path()
        ..moveTo(-30, -6)
        ..lineTo(30, -6)
        ..lineTo(21, 50)
        ..lineTo(-21, 50)
        ..close();
      g.save();
      g.drawPath(cup, _fillP(const Color(0xFFFFF8F0)));
      g.clipPath(cup);
      final stripe = _fillP(const Color(0xFFFF4B5C));
      for (var i = -3; i <= 3; i += 2) {
        g.drawPath(
          Path()
            ..moveTo(i * 8.6 - 4.3, -6)
            ..lineTo(i * 8.6 + 4.3, -6)
            ..lineTo(i * 6.0 + 3, 50)
            ..lineTo(i * 6.0 - 3, 50)
            ..close(),
          stripe,
        );
      }
      g.restore();
      g.drawPath(cup, _strokeP(l, 5));
      _shape(g, _rr(-33, -11, 66, 9, 4.5), const Color(0xFFFF4B5C), l, 4.5);
      _shine(g, -17, 14, 3, 12, 0.15);
    default:
      break;
  }
}

/// Вариантов наклейки у узора (макет: `TOON`).
int _toonVariants(PatternCoverStyle s) => switch (s) {
  PatternCoverStyle.donuts => 4,
  PatternCoverStyle.icecream => 3,
  _ => 1,
};

/// Светлячок: мягкое пятно (тёмная тема — тёплый свет, светлая — янтарь).
void _drawGlow(Canvas c, bool dark) {
  final shader = ui.Gradient.radial(
    Offset.zero,
    1,
    dark
        ? const [
            Color.fromRGBO(255, 250, 228, 1),
            Color.fromRGBO(255, 224, 150, 0.85),
            Color.fromRGBO(255, 192, 84, 0.3),
            Color.fromRGBO(255, 184, 64, 0),
          ]
        : const [
            Color.fromRGBO(176, 98, 0, 1),
            Color.fromRGBO(204, 128, 24, 0.6),
            Color.fromRGBO(222, 150, 40, 0),
          ],
    dark ? const [0, 0.28, 0.55, 1] : const [0, 0.3, 1],
  );
  c.drawCircle(Offset.zero, 1, Paint()..shader = shader);
}

_Atlas _buildAtlas(PatternCoverStyle style, Color ink, bool dark) {
  final b = _AtlasBuilder();
  const d = _kSpriteDensity;
  switch (style) {
    case PatternCoverStyle.smark:
      // 0 — S (высота 1; на экране до ~21 px), 1 — точка.
      b.add(_sMarkBounds, 22 * d, (c) => c.drawPath(_sMarkPath, _fillP(ink)));
      _addDot(b, ink);
    case PatternCoverStyle.suits:
      for (var i = 0; i < 4; i++) {
        final path = _suitPath(i);
        b.add(
          const Rect.fromLTRB(-0.5, -0.5, 0.5, 0.5),
          15 * d,
          (c) => c.drawPath(path, _fillP(ink)),
        );
      }
    case PatternCoverStyle.soda:
      b.add(
        const Rect.fromLTRB(-17, -51, 17, 50),
        0.4 * d,
        (c) => _drawBottle(c, ink, dark),
      );
      _addDot(b, ink);
    case PatternCoverStyle.coffee:
      b.add(
        const Rect.fromLTRB(-30, -51, 30, 48),
        0.4 * d,
        (c) => _drawCup(c, ink, dark),
      );
      _addDot(b, ink);
      for (var k = 0; k < _kSteamFrames; k++) {
        b.add(
          const Rect.fromLTRB(-6, -36, 6, 1.2),
          0.4 * d,
          (c) => _drawSteam(c, ink, k),
        );
      }
    case PatternCoverStyle.balloons:
      final cols = dark ? _kBalloonDark : _kBalloonLight;
      for (final col in cols) {
        b.add(
          const Rect.fromLTRB(-0.9, -1.04, 0.9, 1.12),
          18 * d,
          (c) => _drawBalloon(c, _rgb(col[0], col[1], col[2])),
        );
      }
      for (var j = 0; j < _kStringLevels; j++) {
        final sway = -0.25 + 0.5 * j / (_kStringLevels - 1);
        b.add(
          const Rect.fromLTRB(-0.62, 1.0, 0.62, 3.28),
          14 * d,
          (c) => _drawString(c, ink, sway),
        );
      }
    case PatternCoverStyle.burgers ||
        PatternCoverStyle.donuts ||
        PatternCoverStyle.icecream ||
        PatternCoverStyle.popcorn:
      // Лист макета: 160 px на 130 единиц — на экране до ~51 px (×3).
      for (var v = 0; v < _toonVariants(style); v++) {
        b.add(
          const Rect.fromLTRB(-65, -65, 65, 65),
          160 / 130,
          (c) => _drawToon(c, style, v),
        );
      }
      // Искорка между наклейками (цвет темы).
      b.add(
        const Rect.fromLTRB(-1, -1, 1, 1),
        5 * d,
        (c) => c.drawPath(
          Path()
            ..moveTo(0, -1)
            ..quadraticBezierTo(0, 0, 1, 0)
            ..quadraticBezierTo(0, 0, 0, 1)
            ..quadraticBezierTo(0, 0, -1, 0)
            ..quadraticBezierTo(0, 0, 0, -1)
            ..close(),
          _fillP(ink),
        ),
      );
    case PatternCoverStyle.fireflies:
      b.add(const Rect.fromLTRB(-1, -1, 1, 1), 32, (c) => _drawGlow(c, dark));
    default:
      _addDot(b, ink);
  }
  return b.build();
}

// ── Раскладки (один раз на узор) ──────────────────────────────────────────

/// Решётка: x, y, вид (0/1/2/3), наклон, фаза — по 5 чисел.
class _Grid {
  _Grid(this.v);
  final Float32List v;
  int get length => v.length ~/ 5;
}

final Map<PatternCoverStyle, Object> _extraLayouts = {};

T _layout<T extends Object>(PatternCoverStyle s, T Function() build) =>
    _extraLayouts.putIfAbsent(s, build) as T;

_Grid _gridSmark() {
  final out = <double>[];
  for (var j = -6; j <= 9; j++) {
    for (var i = -6; i <= 6; i++) {
      out.addAll([
        i * 44.0 + (j & 1) * 22,
        j * 44.0,
        ((i + j) & 1) == 1 ? 1 : 0,
        0,
        0,
      ]);
    }
  }
  return _Grid(Float32List.fromList(out));
}

_Grid _gridSuits() {
  final out = <double>[];
  for (var j = -7; j <= 10; j++) {
    for (var i = -10; i <= 9; i++) {
      out.addAll([
        i * 40.0 + (j & 1) * 20,
        j * 40.0,
        (((i + 2 * j) % 4) + 4) % 4 + 0.0,
        0,
        0,
      ]);
    }
  }
  return _Grid(Float32List.fromList(out));
}

/// Газировка: решётка бутылок + 34 пузырька (x, y, r, скорость, фаза).
class _Soda {
  _Soda(this.grid, this.bubbles);
  final _Grid grid;
  final Float32List bubbles;
}

_Soda _buildSoda() {
  final rnd = _Rnd();
  final out = <double>[];
  for (var j = -5; j <= 8; j++) {
    for (var i = -5; i <= 5; i++) {
      out.addAll([
        i * 54.0 + (j & 1) * 27,
        j * 60.0,
        (((i * 3 + j * 5) % 4) + 4) % 4 == 0 ? 1 : 0,
        (((i + j) & 1) == 1 ? 1 : -1) * 0.2,
        0,
      ]);
    }
  }
  final bub = Float32List(34 * 5);
  for (var k = 0; k < 34; k++) {
    bub[k * 5] = rnd() * 390;
    bub[k * 5 + 1] = rnd() * 460;
    bub[k * 5 + 2] = 1.2 + rnd() * 2;
    bub[k * 5 + 3] = 6 + rnd() * 10;
    bub[k * 5 + 4] = rnd() * 6;
  }
  return _Soda(_Grid(Float32List.fromList(out)), bub);
}

_Grid _gridCoffee() {
  final rnd = _Rnd();
  final out = <double>[];
  for (var j = -5; j <= 8; j++) {
    for (var i = -5; i <= 5; i++) {
      out.addAll([
        i * 50.0 + (j & 1) * 25,
        j * 62.0,
        (((i * 3 + j * 5) % 4) + 4) % 4 == 0 ? 1 : 0,
        (((i + j) & 1) == 1 ? 1 : -1) * 0.12,
        rnd() * 6,
      ]);
    }
  }
  return _Grid(Float32List.fromList(out));
}

/// Шарики: x, y, z, r, скорость, фаза, цвет — по 7 чисел, от дальних к
/// ближним.
Float32List _buildBalloons() {
  final rnd = _Rnd();
  final rows = <List<double>>[];
  for (var k = 0; k < 22; k++) {
    final z = rnd();
    rows.add([
      rnd() * 390,
      rnd() * 540,
      z,
      9 + z * 9,
      7 + z * 9,
      rnd() * 6,
      (k % 5).toDouble(),
    ]);
  }
  rows.sort((a, b) => a[2].compareTo(b[2]));
  return Float32List.fromList([for (final r in rows) ...r]);
}

/// Наклейки по трём орбитам: кольцо, угол, радиус, размер, прозрачность,
/// скорость, фаза, наклон, вариант, искорка(1) — по 10 чисел.
Float32List _buildToon(PatternCoverStyle style) {
  final rnd = _Rnd();
  final nv = _toonVariants(style);
  final out = <double>[];
  const rings = [
    (92.0, 6, 30.0, 1.0),
    (136.0, 9, 27.0, 0.85),
    (180.0, 12, 24.0, 0.65),
  ];
  for (var i = 0; i < rings.length; i++) {
    final (r, n, sz, al) = rings[i];
    final step = math.pi * 2 / n, sp = (i.isOdd ? -1 : 1) * 0.03;
    for (var k = 0; k < n; k++) {
      final ph = rnd() * 6, rot = (rnd() - 0.5) * 0.6;
      out.addAll([
        i.toDouble(),
        k * step + i * 0.35,
        r,
        sz,
        al,
        sp,
        ph,
        rot,
        ((k + i) % nv).toDouble(),
        0,
      ]);
      final sr = r + (rnd() - 0.5) * 14, ssz = 7 + rnd() * 3, sph = rnd() * 6;
      out.addAll([
        i.toDouble(),
        (k + 0.5) * step + i * 0.35,
        sr,
        ssz,
        0,
        sp,
        sph,
        0,
        0,
        1,
      ]);
    }
  }
  return Float32List.fromList(out);
}

// ── Светлячки ─────────────────────────────────────────────────────────────

const int _kFireflyMax = 1300;
const int _kFireflyMin = 450;
const int _kFF = 13;

class _Fireflies {
  _Fireflies(this.p, this.w);

  /// x, y (доли буквы), z, s, a, tw, ph, ax, fx, fy, px, py, искра.
  final Float32List p;

  /// Одиночные огоньки: r, a, sp, wob, s, ph.
  final Float32List w;
}

/// Сколько светлячков рисуем сейчас (уменьшается, если кадр дорогой).
int _fireflyCount = _kFireflyMax;
double _fireflyCostMs = 0;
final Stopwatch _fireflyWatch = Stopwatch();

/// Для проверок: сколько светлячков рисуется сейчас.
int get patternCoverFireflyCount => _fireflyCount;

_Fireflies _buildFireflies() {
  // Точки внутри штрихов S — выборкой с отказом (как пиксели макета).
  final pick = _Rnd(11);
  final pts = Float32List(_kFireflyMax * 2);
  var n = 0;
  var guard = 0;
  while (n < _kFireflyMax && guard < 200000) {
    guard++;
    final x = (pick() - 0.5) * kSMarkAspect, y = pick() - 0.5;
    if (_sMarkPath.contains(Offset(x, y))) {
      pts[n * 2] = x;
      pts[n * 2 + 1] = y;
      n++;
    }
  }
  final rnd = _Rnd();
  final p = Float32List(_kFireflyMax * _kFF);
  for (var k = 0; k < _kFireflyMax; k++) {
    final q = n == 0 ? 0 : (rnd() * n).floor() % n;
    final o = k * _kFF;
    p[o] = pts[q * 2] + (rnd() - 0.5) * 0.008;
    p[o + 1] = pts[q * 2 + 1] + (rnd() - 0.5) * 0.008;
    p[o + 2] = rnd() * 2 - 1;
    p[o + 3] = 1.6 + rnd() * 2.2;
    p[o + 4] = 0.35 + rnd() * 0.4;
    p[o + 5] = 0.6 + rnd() * 1.6;
    p[o + 6] = rnd() * 6;
    p[o + 7] = 1.5 + rnd() * 4;
    p[o + 8] = 0.3 + rnd() * 0.5;
    p[o + 9] = 0.25 + rnd() * 0.5;
    p[o + 10] = rnd() * 6;
    p[o + 11] = rnd() * 6;
    p[o + 12] = rnd() < 0.12 ? 1 : 0;
  }
  final w = Float32List(36 * 6);
  for (var k = 0; k < 36; k++) {
    w[k * 6] = 90 + rnd() * 120;
    w[k * 6 + 1] = rnd() * 6.28;
    w[k * 6 + 2] = (rnd() - 0.5) * 0.12;
    w[k * 6 + 3] = rnd() * 6;
    w[k * 6 + 4] = 3 + rnd() * 3;
    w[k * 6 + 5] = rnd() * 6;
  }
  return _Fireflies(p, w);
}

// ── Самолётики (своё состояние: рули и след) ──────────────────────────────

class _Plane {
  _Plane(
    this.x,
    this.y,
    this.th,
    this.z,
    this.sp,
    this.f1,
    this.f2,
    this.p1,
    this.p2,
  );
  double x, y, th;
  final double z, sp, f1, f2, p1, p2;
  double tt = 0, turn = 0;
  final Float32List trail = Float32List(18);
  int tn = 0;
}

class _Planes {
  _Planes(this.planes);
  final List<_Plane> planes;
  double lastT = double.nan;
}

_Planes _buildPlanes() {
  final rnd = _Rnd();
  final list = <_Plane>[
    for (var k = 0; k < 11; k++)
      _Plane(
        rnd() * 390,
        rnd() * 460,
        rnd() * 6.28,
        0.6 + rnd() * 0.45,
        18 + rnd() * 14,
        0.25 + rnd() * 0.3,
        0.6 + rnd() * 0.5,
        rnd() * 6,
        rnd() * 6,
      ),
  ]..sort((a, b) => a.z.compareTo(b.z));
  return _Planes(list);
}

/// Шаг полёта по макету: плавные случайные повороты, облёт аватара,
/// лёгкий снос вниз, выход за край — с другой стороны; точка следа раз в
/// 0,14 с.
void _stepPlanes(_Planes s, double t, double cx, double cy) {
  if (s.lastT.isNaN || t < s.lastT) {
    // Первый кадр или другие часы (превью) — без скачка.
    s.lastT = t;
    return;
  }
  var left = math.min(0.05, t - s.lastT);
  s.lastT = t;
  var tt = t - left;
  while (left > 1e-6) {
    final dt = math.min(left, 1 / 30);
    left -= dt;
    tt += dt;
    for (final pl in s.planes) {
      var turn =
          0.55 * math.sin(tt * pl.f1 + pl.p1) +
          0.3 * math.sin(tt * pl.f2 + pl.p2);
      final rx = pl.x - cx, ry = pl.y - cy, d0 = _hyp(rx, ry);
      if (d0 < 120) {
        var da = math.atan2(ry, rx) - pl.th;
        da = math.atan2(math.sin(da), math.cos(da));
        turn += da * 1.6 * (1 - d0 / 120);
      }
      pl.turn = turn;
      pl.th += turn * dt;
      final v = pl.sp * pl.z;
      pl.x += math.cos(pl.th) * v * dt;
      pl.y += (math.sin(pl.th) * v + 3) * dt;
      if (pl.x < -40) pl.x += 470;
      if (pl.x > 430) pl.x -= 470;
      if (pl.y < -40) pl.y += 540;
      if (pl.y > 500) pl.y -= 540;
      pl.tt += dt;
      if (pl.tt > 0.14) {
        pl.tt = 0;
        if (pl.tn == 9) {
          pl.trail.setRange(0, 16, pl.trail, 2);
          pl.tn = 8;
        }
        pl.trail[pl.tn * 2] = pl.x;
        pl.trail[pl.tn * 2 + 1] = pl.y;
        pl.tn++;
      }
    }
  }
}

final Path _planePath = Path();
final Paint _planeFill = Paint()..isAntiAlias = true;
final Paint _planeStroke = Paint()
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = true;
final Paint _trailPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeWidth = 1.4
  ..isAntiAlias = true;
final Float32List _trailPts = Float32List(24);
final Float32List _dashBuf = Float32List(256);

void _tri(double x0, double y0, double x1, double y1, double x2, double y2) {
  _planePath
    ..reset()
    ..moveTo(x0, y0)
    ..lineTo(x1, y1)
    ..lineTo(x2, y2)
    ..close();
}

/// Бумажный самолётик макета (`plane()`): три грани, крен меняет их ширину.
void _drawPlane(
  Canvas c,
  double x,
  double y,
  double s,
  double th,
  double bank,
  bool dark,
  double alpha,
) {
  c.save();
  c.translate(x, y);
  c.rotate(th);
  c.scale(s / 40);
  final sq = 1 - 0.4 * bank.abs();
  final yl = -15 * sq * (1 + 0.3 * bank), yr = 15 * sq * (1 - 0.3 * bank);
  final line = dark ? const Color(0xFF1E3A66) : const Color(0xFF2B4C7E);
  final under = bank > 0 ? const Color(0xFFC9DCF4) : const Color(0xFFDCE8F8);
  final side = bank > 0 ? const Color(0xFFE8F0FB) : const Color(0xFFB9CFEE);
  _planeStroke
    ..strokeWidth = 2.6
    ..color = line.withValues(alpha: alpha);
  void face(Color fill) {
    _planeFill.color = fill.withValues(alpha: alpha);
    c.drawPath(_planePath, _planeFill);
    c.drawPath(_planePath, _planeStroke);
  }

  _tri(22, 0, -16, yr, -9, 1.5);
  face(under);
  _tri(22, 0, -14, 5 * sq, -9, 1.5);
  face(side);
  _tri(22, 0, -16, yl, -9, 1.5);
  face(const Color(0xFFFFFFFF));
  _planeStroke
    ..strokeWidth = 1.4
    ..color = line.withValues(alpha: alpha * 0.5);
  c.drawLine(const Offset(16, -1.2), Offset(-8, yl * 0.55), _planeStroke);
  c.restore();
}

/// Пунктир [3, 5] по ломаной [pts] (n точек) — отрезками для drawRawPoints.
int _dash(Float32List pts, int n) {
  var out = 0;
  var on = true;
  var rem = 3.0;
  for (var i = 0; i + 1 < n; i++) {
    var x = pts[i * 2], y = pts[i * 2 + 1];
    final dx = pts[i * 2 + 2] - x, dy = pts[i * 2 + 3] - y;
    var len = _hyp(dx, dy);
    if (len < 1e-6) continue;
    final ux = dx / len, uy = dy / len;
    while (len > 1e-6) {
      final st = math.min(rem, len);
      if (on && out + 4 <= _dashBuf.length) {
        _dashBuf[out++] = x;
        _dashBuf[out++] = y;
        _dashBuf[out++] = x + ux * st;
        _dashBuf[out++] = y + uy * st;
      }
      x += ux * st;
      y += uy * st;
      len -= st;
      rem -= st;
      if (rem <= 1e-6) {
        on = !on;
        rem = on ? 3 : 5;
      }
    }
  }
  return out;
}

// ── Рисование ─────────────────────────────────────────────────────────────

/// Рисует узор второй волны. Холст уже в координатах макета (ширина 390).
void paintPatternCoverExtra(
  Canvas canvas,
  PatternCoverStyle style,
  PatternExtraFrame f,
) {
  switch (style) {
    case PatternCoverStyle.smark:
      _paintSmark(canvas, f);
    case PatternCoverStyle.suits:
      _paintSuits(canvas, f);
    case PatternCoverStyle.soda:
      _paintSoda(canvas, f);
    case PatternCoverStyle.coffee:
      _paintCoffee(canvas, f);
    case PatternCoverStyle.balloons:
      _paintBalloons(canvas, f);
    case PatternCoverStyle.burgers ||
        PatternCoverStyle.donuts ||
        PatternCoverStyle.icecream ||
        PatternCoverStyle.popcorn:
      _paintToon(canvas, style, f);
    case PatternCoverStyle.planes:
      _paintPlanes(canvas, f);
    case PatternCoverStyle.fireflies:
      _paintFireflies(canvas, f);
    default:
      break;
  }
}

void _paintSmark(Canvas canvas, PatternExtraFrame f) {
  final at = _atlas(PatternCoverStyle.smark, f);
  final g = _layout(PatternCoverStyle.smark, _gridSmark).v;
  final dx = (f.t * 3) % 44;
  final sCell = at.cells[0], dot = at.cells[1];
  for (var o = 0; o < g.length; o += 5) {
    final x = g[o] + dx, y = g[o + 1];
    final d = _hyp(x, y), hl = _halo(d, 74, 175, 115);
    if (hl <= 0) continue;
    final b = f.band(d), yy = f.cy + y * b;
    final isS = g[o + 2] == 0;
    final al = f.alpha(yy, (isS ? 0.2 : 0.14) * hl);
    if (al == 0) continue;
    // Макет: высота S = 0,92 от размера знака 22; точка — 0,1 от 14.
    _batch.add(
      isS ? sCell : dot,
      f.cx + x * b,
      yy,
      isS ? 22 * 0.92 : 1.4,
      0,
      al,
    );
  }
  _batch.flush(canvas, at.image, _atlasPaint);
}

void _paintSuits(Canvas canvas, PatternExtraFrame f) {
  final at = _atlas(PatternCoverStyle.suits, f);
  final g = _layout(PatternCoverStyle.suits, _gridSuits).v;
  final dx = (f.t * 4) % 160;
  for (var o = 0; o < g.length; o += 5) {
    var x = g[o] + dx;
    if (x > 400) x -= 800;
    final y = g[o + 1];
    final d = _hyp(x, y), hl = _halo(d, 74, 175, 115);
    if (hl <= 0) continue;
    final b = f.band(d), yy = f.cy + y * b;
    final al = f.alpha(yy, 0.17 * hl);
    if (al == 0) continue;
    _batch.add(at.cells[g[o + 2].toInt()], f.cx + x * b, yy, 15, 0, al);
  }
  _batch.flush(canvas, at.image, _atlasPaint);
}

final Paint _ringPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1
  ..isAntiAlias = true;

/// Пузырёк поднимается без состояния: положение — от времени; на новом
/// круге — новое место по горизонтали (макет брал случайное).
(double, double) _rise(
  double x0,
  double y0,
  double sp,
  double t,
  double top,
  double span,
) {
  final u = y0 - top - sp * t;
  final cyc = (u / span).floor();
  final y = u - cyc * span + top;
  final x = cyc == 0 ? x0 : ((x0 + cyc * 241.0) % 390 + 390) % 390;
  return (x, y);
}

void _paintSoda(Canvas canvas, PatternExtraFrame f) {
  final at = _atlas(PatternCoverStyle.soda, f);
  final soda = _layout(PatternCoverStyle.soda, _buildSoda);
  final g = soda.grid.v;
  final off = (f.t * 3) % 60;
  for (var o = 0; o < g.length; o += 5) {
    final x = g[o];
    var y = g[o + 1] - off;
    if (y < -300) y += 840;
    final d = _hyp(x, y), hl = _halo(d, 74, 180, 120);
    if (hl <= 0) continue;
    final b = f.band(d), xx = f.cx + x * b, yy = f.cy + y * b;
    if (g[o + 2] == 1) {
      _batch.add(at.cells[1], xx, yy, 1.6, 0, f.alpha(yy, 0.16 * hl));
      continue;
    }
    final al = f.alpha(yy, 0.2 * hl * f.textGap(xx, yy));
    // Части бутылки запечены относительно ×3,2 (этикетка-полоски).
    _batch.add(at.cells[0], xx, yy, 0.4, g[o + 3], al * 3.2);
  }
  _batch.flush(canvas, at.image, _atlasPaint);
  final bub = soda.bubbles;
  for (var o = 0; o < bub.length; o += 5) {
    final (bx, by) = _rise(bub[o], bub[o + 1], bub[o + 3], f.t, -20, 500);
    final x = bx + math.sin(f.t * 1.4 + bub[o + 4]) * 3;
    final hole = _cl((_hyp(x - f.cx, by - f.cy) - 66) / 30);
    final al = f.alpha(by, 0.14 * hole);
    if (al == 0) continue;
    _ringPaint.color = f.ink.withValues(alpha: al);
    canvas.drawCircle(Offset(x, by), bub[o + 2], _ringPaint);
  }
}

void _paintCoffee(Canvas canvas, PatternExtraFrame f) {
  final at = _atlas(PatternCoverStyle.coffee, f);
  final g = _layout(PatternCoverStyle.coffee, _gridCoffee).v;
  final off = (f.t * 3) % 50, t = f.t;
  const k = 0.4; // высота 40 из 100 единиц
  for (var o = 0; o < g.length; o += 5) {
    var x = g[o] - off;
    if (x < -290) x += 550;
    final y = g[o + 1];
    final d = _hyp(x, y), hl = _halo(d, 76, 180, 120);
    if (hl <= 0) continue;
    final b = f.band(d), xx = f.cx + x * b, yy = f.cy + y * b;
    if (g[o + 2] == 1) {
      _batch.add(at.cells[1], xx, yy, 1.6, 0, f.alpha(yy, 0.15 * hl));
      continue;
    }
    final al = f.alpha(yy, 0.2 * hl * f.textGap(xx, yy));
    if (al == 0) continue;
    final rot = g[o + 3], ph = g[o + 4];
    _batch.add(at.cells[0], xx, yy, k, rot, al * 2);
    // Пар: две струйки, кадр — фаза бегущей волны.
    final cr = math.cos(rot), sr = math.sin(rot);
    for (var n = 0; n < 2; n++) {
      final sx = n == 0 ? -7.0 : 7.0;
      final phase = t * 1.8 - ph - n * 2;
      final fr =
          ((phase / (math.pi * 2) * _kSteamFrames).round() % _kSteamFrames +
              _kSteamFrames) %
          _kSteamFrames;
      final bx = xx + k * (cr * sx - sr * -54),
          by = yy + k * (sr * sx + cr * -54);
      final tw = 0.6 + 0.4 * math.sin(t * 0.9 + ph + n);
      _batch.add(at.cells[2 + fr], bx, by, k, rot, al * 0.75 * tw);
    }
  }
  _batch.flush(canvas, at.image, _atlasPaint);
}

void _paintBalloons(Canvas canvas, PatternExtraFrame f) {
  final at = _atlas(PatternCoverStyle.balloons, f);
  final g = _layout(PatternCoverStyle.balloons, _buildBalloons);
  final t = f.t;
  for (var o = 0; o < g.length; o += 7) {
    final (bx, by) = _rise(g[o], g[o + 1], g[o + 4], t, -70, 600);
    final ph = g[o + 5];
    final sx = bx + math.sin(t * 0.5 + ph) * 8;
    final rx = sx - f.cx, ry = by - f.cy, d = _hyp(rx, ry), b = f.band(d);
    final xx = f.cx + rx * b, yy = f.cy + ry * b;
    final hole = _cl((d - 66) / 34);
    final al = f.alpha(yy, (0.08 + 0.12 * g[o + 2]) * hole * f.textGap(xx, yy));
    if (al == 0) continue;
    final sway = math.sin(t * 0.5 + ph + 0.6) * 0.25;
    final r = g[o + 3], rot = sway * 0.3;
    final lv = ((sway + 0.25) / 0.5 * (_kStringLevels - 1)).round().clamp(
      0,
      _kStringLevels - 1,
    );
    _batch.add(at.cells[5 + lv], xx, yy, r, rot, al);
    _batch.add(at.cells[g[o + 6].toInt()], xx, yy, r, rot, al * 2.6);
  }
  _batch.flush(canvas, at.image, _atlasPaint);
}

void _paintToon(Canvas canvas, PatternCoverStyle style, PatternExtraFrame f) {
  final at = _atlas(style, f);
  final g = _layout(style, () => _buildToon(style));
  final spark = at.cells[_toonVariants(style)];
  final t = f.t;
  for (var o = 0; o < g.length; o += 10) {
    final b = f.bands[(g[o] * 2).toInt()];
    final a = g[o + 1] + t * g[o + 5], r = g[o + 2] * b;
    final xx = f.cx + math.cos(a) * r, yy = f.cy + math.sin(a) * r * 0.94;
    final ph = g[o + 6];
    if (g[o + 9] == 1) {
      final tw = 0.5 + 0.5 * math.sin(t * 1.6 + ph);
      final al = f.alpha(yy, 0.22 * tw * f.textGap(xx, yy));
      _batch.add(spark, xx, yy, g[o + 3] * (0.7 + 0.3 * tw) / 2, 0, al);
      continue;
    }
    // Наклейки цветные: прозрачность без «силы цвета темы» (как в макете).
    final al = g[o + 4] * f.ga * f.fy(yy) * f.textGap(xx, yy);
    if (al < 0.01) continue;
    final sz = g[o + 3] * (1 + f.p * 0.3);
    final yb = yy + math.sin(t * 1.2 + ph) * 2;
    final rot = g[o + 7] + math.sin(t * 0.7 + ph) * 0.14;
    // Лист 130 единиц рисуется размером sz·1,3.
    _batch.add(at.cells[g[o + 8].toInt()], xx, yb, sz / 100, rot, al);
  }
  _batch.flush(canvas, at.image, _atlasPaint);
}

void _paintPlanes(Canvas canvas, PatternExtraFrame f) {
  final s = _layout(PatternCoverStyle.planes, _buildPlanes);
  _stepPlanes(s, f.t, f.cx, f.cy);
  final cx = f.cx, cy = f.cy;
  for (final pl in s.planes) {
    final qx = pl.x - cx, qy = pl.y - cy, b = f.band(_hyp(qx, qy));
    final xx = cx + qx * b, yy = cy + qy * b;
    final hole = _cl((_hyp(xx - cx, yy - cy) - 64) / 30);
    final vis = f.ga * f.fy(yy) * hole * f.textGap(xx, yy);
    if (vis <= 0.01) continue;
    // След: точки не дальше 100 px (через край экрана — без линии).
    var n = 0;
    for (var i = 0; i < pl.tn; i++) {
      final tx = pl.trail[i * 2], ty = pl.trail[i * 2 + 1];
      if ((tx - pl.x).abs() >= 100 || (ty - pl.y).abs() >= 100) continue;
      final ux = tx - cx, uy = ty - cy, tb = f.band(_hyp(ux, uy));
      _trailPts[n * 2] = cx + ux * tb;
      _trailPts[n * 2 + 1] = cy + uy * tb;
      n++;
    }
    if (n > 1) {
      _trailPts[n * 2] = xx;
      _trailPts[n * 2 + 1] = yy;
      final m = _dash(_trailPts, n + 1);
      if (m > 0) {
        _trailPaint.color = f.ink.withValues(alpha: _cl(0.28 * vis * f.k));
        canvas.drawRawPoints(
          ui.PointMode.lines,
          Float32List.sublistView(_dashBuf, 0, m),
          _trailPaint,
        );
      }
    }
    final bank = (pl.turn * 1.3).clamp(-0.9, 0.9);
    _drawPlane(
      canvas,
      xx,
      yy,
      20 * pl.z,
      pl.th,
      bank,
      f.dark,
      _cl(vis * (0.75 + 0.25 * pl.z)),
    );
  }
}

void _paintFireflies(Canvas canvas, PatternExtraFrame f) {
  final at = _atlas(PatternCoverStyle.fireflies, f);
  final ff = _layout(PatternCoverStyle.fireflies, _buildFireflies);
  // Меряем только расчёт кадра (лист и раскладка строятся один раз).
  _fireflyWatch
    ..reset()
    ..start();
  final glow = at.cells[0];
  final t = f.t, cx = f.cx, cy = f.cy;
  final ph = t / 26 * math.pi * 2;
  final aY = 0.42 * math.sin(ph), aX = 0.08 * math.sin(ph + 1.7);
  final cY = math.cos(aY), sY = math.sin(aY);
  final cX = math.cos(aX), sX = math.sin(aX);
  const span = 290.0;
  final p = ff.p;
  final count = _fireflyCount;
  for (var k = 0; k < count; k++) {
    final o = k * _kFF;
    final ax = p[o + 7];
    final lx = p[o] * span + ax * math.sin(t * p[o + 8] + p[o + 10]);
    final ly = p[o + 1] * span + ax * math.sin(t * p[o + 9] + p[o + 11]);
    final lz = p[o + 2] * 26;
    final x1 = lx * cY + lz * sY, z1 = lz * cY - lx * sY;
    final y2 = ly * cX - z1 * sX, z2 = ly * sX + z1 * cX;
    final pr = 900 / (900 - z2);
    final b = f.band(_hyp(lx, ly));
    final xx = cx + x1 * pr * b, yy = cy + 6 + y2 * pr * b;
    final hole = _cl((_hyp(xx - cx, yy - cy) - 60) / 30);
    if (hole <= 0) continue;
    var a = p[o + 4] * (0.6 + 0.4 * math.sin(t * p[o + 5] + p[o + 6]));
    if (p[o + 12] == 1) {
      a += 0.35 * math.exp(3 * (math.cos(t * 0.7 + p[o + 6]) - 1));
    }
    a *= hole * (0.55 + 0.45 * _cl((z2 / 26 + 1) / 2));
    final al = f.alpha(yy, a);
    if (al == 0) continue;
    _batch.add(glow, xx, yy, p[o + 3] * pr, 0, al);
  }
  final w = ff.w, b2 = f.bands[2];
  for (var o = 0; o < w.length; o += 6) {
    final a = w[o + 1] + t * w[o + 2];
    final r = (w[o] + 10 * math.sin(t * 0.5 + w[o + 3])) * b2;
    final xx = cx + math.cos(a) * r, yy = cy + math.sin(a) * r * 0.9;
    final tw = math.max(0.0, math.sin(t * 0.8 + w[o + 5]));
    _batch.add(glow, xx, yy, w[o + 4], 0, f.alpha(yy, 0.55 * tw * tw));
  }
  _batch.flush(canvas, at.image, f.dark ? _atlasPlus : _atlasPaint);
  _fireflyWatch.stop();
  // В отладочной сборке код в разы медленнее — там число не трогаем.
  if (kDebugMode) return;
  // Сам себе бюджет: дорогой кадр — светлячков меньше, дешёвый — больше.
  final ms = _fireflyWatch.elapsedMicroseconds / 1000;
  _fireflyCostMs = _fireflyCostMs == 0 ? ms : _fireflyCostMs * 0.9 + ms * 0.1;
  if (_fireflyCostMs > 1.5 && _fireflyCount > _kFireflyMin) {
    _fireflyCount = math.max(_kFireflyMin, (_fireflyCount * 0.85).round());
    _fireflyCostMs *= 0.85;
  } else if (_fireflyCostMs < 0.6 && _fireflyCount < _kFireflyMax) {
    _fireflyCount = math.min(_kFireflyMax, _fireflyCount + 20);
  }
}
