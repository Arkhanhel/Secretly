// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../profile_fx.dart';

math.Random _rng = math.Random();

/// Тесты (25.09.2026): закрепить случайность эффектов рамок, чтобы проверки
/// рисования давали один и тот же кадр. Без зерна рыбки «аквариума» и прочие
/// частицы вставали каждый раз по-новому, и проверка «рамка не закрывает лицо»
/// то проходила, то падала. В приложении не вызывается — поведение прежнее.
@visibleForTesting
void debugSeedProfileFxRandom(int seed) => _rng = math.Random(seed);
double _rnd() => _rng.nextDouble();
const double _tau = math.pi * 2;
const double _deg = math.pi / 180;

double _clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
double _lerp(double a, double b, double u) => a + (b - a) * u;
double _pow(double x, double e) => math.pow(x, e).toDouble();
double _hash(num a, [num b = 0, num c = 0]) {
  final x = math.sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453;
  return x - x.floorToDouble();
}

double _backOut(double u) {
  final q = u - 1;
  return 1 + 2.7 * q * q * q + 1.7 * q * q;
}

/// Недодемпфированная пружина: цель → перелёт → затухание.
/// Основа «живого» движения во всех рамках.
class Spring {
  Spring([double initial = 0])
      : x = initial,
        t = initial;
  double x, t, v = 0;
  void step(double dt, [double k = 180, double c = 11]) {
    final a = -k * (x - t) - c * v;
    v += a * dt;
    x += v * dt;
  }
}

/// Точка на окружности: угол 0 — вверх, по часовой стрелке.
Offset _pt(double cx, double cy, double r, double a) =>
    Offset(cx + r * math.sin(a), cy - r * math.cos(a));

Path _smoothClosed(List<Offset> p) {
  final n = p.length;
  final path = Path()..moveTo(p[0].dx, p[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = p[(i - 1 + n) % n], p1 = p[i], p2 = p[(i + 1) % n], p3 = p[(i + 2) % n];
    path.cubicTo(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6, p2.dx, p2.dy);
  }
  return path..close();
}

/// Замкнутая гладкая «капля» вокруг центра с радиусом r + f(угол).
Path _blob(double cx, double cy, double r, double Function(double a) f, [int n = 36]) =>
    _smoothClosed(List<Offset>.generate(n, (i) {
      final a = i / n * _tau;
      return _pt(cx, cy, r + f(a), a);
    }));

Path _smoothOpen(List<Offset> p) {
  final path = Path()..moveTo(p[0].dx, p[0].dy);
  for (var j = 1; j < p.length - 1; j++) {
    final m = (p[j] + p[j + 1]) / 2;
    path.quadraticBezierTo(p[j].dx, p[j].dy, m.dx, m.dy);
  }
  return path..lineTo(p.last.dx, p.last.dy);
}

// ───────────── Светлая тема: «дневной тон» (24.11.2026) ─────────────
//
// 🔴 ПОЧЕМУ ЗДЕСЬ, А НЕ В КАЖДОЙ РАМКЕ. Рамки и обложки рисовались под тёмный
// фон: свечения шли сложением света (`BlendMode.plus`), блики и пыль — белым,
// подсветка — пастелью. На светлой странице сложение с почти белым ничего не
// даёт (свечение пропадает или ложится серым пятном), белое исчезает, пастель
// выглядит грязной. Все рисующие помощники проходят через [_day]/[_dayGlow],
// поэтому одна правка чинит все 56 рамок и дневные обложки разом:
// • цвет: насыщеннее, светлые пастели опущены к чистому среднему тону;
//   серые, белые и почти чёрные не трогаются (ободок, глаза, контуры);
// • свечение: не сложение света, а мягкая цветная тень — обычное наложение
//   более глубоким тоном той же краски;
// • блик: белый крест получает тонкую подложку, чтобы читаться на белом.
// Включается только на время рисования в светлой теме ([paintFxDay]).
// Откат одной строкой — [kFxDayTone].

const bool kFxDayTone = true;

/// Насыщенность слоя рамки/обложки в светлой теме (1 — как есть). Серые и
/// белые цвета матрица не меняет, поэтому ободок цвета страницы остаётся
/// своим (сдвиг на светлых тонированных страницах — 1–3 единицы канала).
const double kFxDaySaturation = 1.18;

bool _fxDay = false;

/// Править ли и краску (не только свечения). Рамки — да: они рисовались под
/// тёмный фон целиком. Обложки — нет: у дневных сцен светлая палитра своя,
/// и трогать её фоны нельзя; там чинятся только свечения и сложение света.
bool _fxInk = false;

/// Рисует [paint] в «дневном тоне», если [day] (светлая тема). [ink] —
/// править и краску (рамки). Вызывают художники рамок и обложек;
/// вложенные вызовы безопасны.
void paintFxDay(bool day, void Function() paint, {bool ink = true}) {
  final prev = _fxDay, prevInk = _fxInk;
  _fxDay = kFxDayTone && day;
  _fxInk = _fxDay && ink;
  try {
    paint();
  } finally {
    _fxDay = prev;
    _fxInk = prevInk;
  }
}

/// Сейчас идёт рисование в дневном тоне.
bool get fxDayActive => _fxDay;

/// Матрица насыщенности (яркость по Rec. 709 сохраняется, серые неподвижны).
ColorFilter fxDaySaturationFilter([double s = kFxDaySaturation]) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final r = (1 - s) * lr, g = (1 - s) * lg, b = (1 - s) * lb;
  return ColorFilter.matrix(<double>[
    r + s, g, b, 0, 0, //
    r, g + s, b, 0, 0, //
    r, g, b + s, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

/// Кисть слоя: `saveLayer(bounds, fxDayLayerPaint)` вокруг рисования в
/// светлой теме. Одна на всё приложение.
final Paint fxDayLayerPaint = Paint()..colorFilter = fxDaySaturationFilter();

final Map<int, int> _dayInkCache = <int, int>{};
final Map<int, int> _dayGlowCache = <int, int>{};

/// Хрома 0..1 (размах каналов). Насыщенность HSL для этого не годится: у почти
/// белого фона вроде #FAF8F4 она 0.37, хотя цвета там нет.
double _chroma(int argb) {
  final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  return (math.max(r, math.max(g, b)) - math.min(r, math.min(g, b))) / 255;
}

/// Цвет краски в дневном тоне. Вне [paintFxDay] (или без `ink`) — без изменений.
Color _day(Color c) {
  if (!_fxInk) return c;
  final k = c.toARGB32();
  final hit = _dayInkCache[k];
  if (hit != null) return Color(hit);
  var out = c;
  if (_chroma(k) >= 0.12) {
    final hsl = HSLColor.fromColor(c);
    final l = hsl.lightness;
    // Пастель выше L 0.68 — к чистому тону: на белом она читается «грязью».
    final l2 = l > 0.68 ? 0.68 + (l - 0.68) * 0.45 : l;
    final s2 = math.min(1.0, hsl.saturation * 1.12 + 0.04);
    out = hsl.withLightness(l2).withSaturation(s2).toColor();
  }
  if (_dayInkCache.length > 4096) _dayInkCache.clear();
  _dayInkCache[k] = out.toARGB32();
  return out;
}

/// Цвет свечения в дневном тоне: та же краска глубже — мягкая цветная тень
/// вместо света. Белые и серые свечения остаются (на тонированных страницах
/// они ещё видны и не должны становиться грязными).
Color _dayGlow(Color c) {
  if (!_fxDay) return c;
  final k = c.toARGB32() | 0xFF000000;
  final hit = _dayGlowCache[k];
  if (hit != null) return Color(hit).withAlpha(c.toARGB32() >>> 24);
  var out = Color(k);
  if (_chroma(k) >= 0.08) {
    final hsl = HSLColor.fromColor(out);
    out = hsl
        .withLightness(_clamp(hsl.lightness, 0.42, 0.6))
        .withSaturation(math.min(1.0, hsl.saturation * 1.1 + 0.1))
        .toColor();
  }
  if (_dayGlowCache.length > 1024) _dayGlowCache.clear();
  _dayGlowCache[k] = out.toARGB32();
  return out.withAlpha(c.toARGB32() >>> 24);
}

/// Множитель силы свечения в дневном тоне: тень мягче, чем свет.
double get _dayGlowK => _fxDay ? 0.8 : 1.0;

Paint _fill(Color c) => Paint()..color = _day(c);
Paint _stroke(Color c, double w, [StrokeCap cap = StrokeCap.round]) => Paint()
  ..color = _day(c)
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = StrokeJoin.round;

/// Непрозрачный цвет → цвет с заданной прозрачностью.
Color _op(Color c, double o) => c.withAlpha((255 * _clamp(o, 0, 1)).round());

List<double> _even(int n) => List<double>.generate(n, (i) => n == 1 ? 0.0 : i / (n - 1));
ui.Gradient _linG(Offset a, Offset b, List<Color> c, [List<double>? s]) =>
    ui.Gradient.linear(a, b, _fxInk ? c.map(_day).toList(growable: false) : c, s ?? _even(c.length));

void _vFill(Canvas c, Size s, Color top, Color bottom) => c.drawRect(
    Offset.zero & s, Paint()..shader = _linG(Offset.zero, Offset(0, s.height), [top, bottom]));

/// Мягкое круглое свечение (аналог радиального спрайта).
void _glow(Canvas c, Offset o, double r, Color col, double op, [BlendMode mode = BlendMode.srcOver]) {
  if (op <= 0.003 || r <= 0.5) return;
  if (_fxDay) {
    col = _dayGlow(col);
    op *= _dayGlowK;
    if (mode == BlendMode.plus || mode == BlendMode.screen) mode = BlendMode.srcOver;
  }
  c.drawCircle(
      o,
      r,
      Paint()
        ..blendMode = mode
        ..shader = ui.Gradient.radial(
            o, r, [_op(col, op), _op(col, op * 0.55), _op(col, 0)], const [0.0, 0.35, 1.0]));
}

RRect _rr(double x, double y, double w, double h, double r) =>
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

Rect _ov(double cx, double cy, double rx, double ry) =>
    Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);

final Map<String, TextPainter> _tpCache = {};

/// Текст по центру точки. Кэшируется — безопасно вызывать каждый кадр.
void _text(Canvas c, String s, Offset center, double size, Color color,
    [FontWeight w = FontWeight.w700, double alpha = 1, double spacing = 0]) {
  if (alpha <= 0.01) return;
  final key = '$s|$size|${color.hashCode}|${w.value}|$spacing';
  var tp = _tpCache[key];
  if (tp == null) {
    if (_tpCache.length > 256) _tpCache.clear();
    tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, fontWeight: w, color: color, letterSpacing: spacing, height: 1.0)),
      textDirection: TextDirection.ltr,
    )..layout();
    _tpCache[key] = tp;
  }
  final o = center - Offset(tp.width / 2, tp.height / 2);
  if (alpha >= 0.99) {
    tp.paint(c, o);
  } else {
    c.saveLayer(o & tp.size, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    tp.paint(c, o);
    c.restore();
  }
}

Path _heart([double s = 1]) => Path()
  ..moveTo(0, 6 * s)
  ..cubicTo(0, 6 * s, -7 * s, 1.5 * s, -7 * s, -2.5 * s)
  ..cubicTo(-7 * s, -5.5 * s, -4.5 * s, -7 * s, -2.5 * s, -7 * s)
  ..cubicTo(-1 * s, -7 * s, 0, -6 * s, 0, -4.5 * s)
  ..cubicTo(0, -6 * s, 1 * s, -7 * s, 2.5 * s, -7 * s)
  ..cubicTo(4.5 * s, -7 * s, 7 * s, -5.5 * s, 7 * s, -2.5 * s)
  ..cubicTo(7 * s, 1.5 * s, 0, 6 * s, 0, 6 * s)
  ..close();

String _fmtInt(int v) {
  final s = v.toString(), b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('\u2009');
    b.write(s[i]);
  }
  return b.toString();
}

// ───────────── Добавлено 13.11.2026 для переделки старых рамок и обложек ─────────────

/// Свечение — заранее испечённый радиальный спрайт 64 × 64 (стопы 1 / 0.55 / 0
/// на 0 / 0.35 / 1), как в дизайн-референсе.
///
/// 🔴 ЗАЧЕМ ВТОРОЕ СВЕЧЕНИЕ РЯДОМ С [_glow]. `_glow` строит градиентный шейдер
/// на каждый вызов. Для сцены с двумя-тремя пятнами это ничто, а у костра,
/// дыма и чернил вызовов сотни в кадре. Спрайт печётся один раз на цвет, а
/// дальше это одна текстура, растянутая под нужный радиус. Старые сцены
/// остаются на `_glow` — их картинка не меняется.
final Map<int, ui.Image> _glowSprites = <int, ui.Image>{};

bool _glowSpritesGuarded = false;

ui.Image _glowSprite(Color col) {
  final key = col.toARGB32() | 0xFF000000;
  final cached = _glowSprites[key];
  if (cached != null) return cached;
  if (!_glowSpritesGuarded) {
    _glowSpritesGuarded = true;
    GpuImageGuard.register(_glowSprites.clear);
  }
  if (_glowSprites.length > 64) {
    // Без dispose: спрайт может держать уже записанный кадр (23.11.2026).
    _glowSprites.clear();
  }
  final base = Color(key);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  const o = Offset(32, 32);
  c.drawRect(
      const Rect.fromLTWH(0, 0, 64, 64),
      Paint()
        ..shader = ui.Gradient.radial(
            o, 32, [_op(base, 1), _op(base, 0.55), _op(base, 0)], const [0.0, 0.35, 1.0]));
  final img = rec.endRecording().toImageSync(64, 64);
  _glowSprites[key] = img;
  return img;
}

const Rect _kGlowSrc = Rect.fromLTWH(0, 0, 64, 64);

/// То же, что [_glow], но спрайтом. [add] — сложение света (`'lighter'` в JS).
void _glowS(Canvas c, Offset o, double r, Color col, double op, [bool add = false]) {
  if (op <= 0.003 || r <= 0.5) return;
  if (_fxDay) {
    col = _dayGlow(col);
    op *= _dayGlowK;
    add = false;
  }
  final p = Paint()
    ..color = Color.fromRGBO(0, 0, 0, _clamp(op, 0, 1))
    ..filterQuality = FilterQuality.low;
  if (add) p.blendMode = BlendMode.plus;
  c.drawImageRect(_glowSprite(col), _kGlowSrc, Rect.fromCircle(center: o, radius: r), p);
}

/// Четырёхлучевой блик: крест из двух линий 0.9 длиной 2·[s] и точка 0.22·[s].
void _glint(Canvas c, Offset o, double s, double a) {
  if (a <= 0.02) return;
  if (_fxDay) {
    // Белый крест на белом не виден: под ним тонкая холодная подложка.
    final u = _stroke(Color.fromRGBO(70, 84, 120, _clamp(a * 0.28, 0, 1)), 1.8);
    c.drawLine(Offset(o.dx - s, o.dy), Offset(o.dx + s, o.dy), u);
    c.drawLine(Offset(o.dx, o.dy - s), Offset(o.dx, o.dy + s), u);
  }
  final col = Color.fromRGBO(255, 255, 255, _clamp(a, 0, 1));
  final p = _stroke(col, 0.9);
  c.drawLine(Offset(o.dx - s, o.dy), Offset(o.dx + s, o.dy), p);
  c.drawLine(Offset(o.dx, o.dy - s), Offset(o.dx, o.dy + s), p);
  c.drawCircle(o, s * 0.22, _fill(col));
}

/// Цвет из `#RRGGBB` с прозрачностью — аналог `C(hex, a)` референса.
Color _hex(int rgb, [double a = 1]) => Color((rgb & 0xFFFFFF) | 0xFF000000).withValues(alpha: _clamp(a, 0, 1));
