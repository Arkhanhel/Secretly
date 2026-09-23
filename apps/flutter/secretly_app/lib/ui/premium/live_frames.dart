// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// 🔴 ЖИВЫЕ РАМКИ — три персонажа из макета «Живые рамки» (23.09.2026).
//
// Чем они отличаются от двадцати рамок в `cosmetics_catalog.dart`. Те —
// ПЕТЛИ: у каждой есть период, кадры пекутся в атлас один раз и потом просто
// показываются. Эти петли не имеют: движение здесь считают пружины, а моменты
// подёргивания уха и рывки рук берутся из случайных чисел. Ничего не
// повторяется одинаково — ради этого макет и написан («неровный ритм»).
//
// Поэтому они НЕ идут через атлас и не участвуют в проверках шва петли: печь
// нечего. Живут они на своём тикере, который считает настоящее `dt`.
//
// 🔴 ДВА СЛОЯ БЕЗ ДВУХ СЛОЁВ. Макет просит класть уши, хвост и волну ПОД фото,
// а кольцо и лапки — поверх. Фото рисует вызывающая сторона (`FramedAvatar` и
// три экрана телефона), рамка — только накладка сверху, и перекраивать их
// ради этого нельзя: телефон выпущен. Выход тот же, что на бумаге: задние
// части рисуются с вырезанным кругом фотографии. Видно ровно то же самое —
// ухо, выходящее из-за головы, — но порядок слоёв у вызывающей стороны не
// меняется ни на строчку.
//
// 🔴 СИСТЕМА КООРДИНАТ. Макет нарисован на холсте 200×200, круг аватара в нём
// r = 58 (у «Меломана» 54) с центром (100, 112). У нас квадрат `size`, фото
// занимает 0.86 от него, то есть r = 0.43·size. Значит холст рамки шире
// квадрата примерно в полтора раза и СОЗНАТЕЛЬНО вылезает за него: в нём живут
// уши, руки и ноты. `CustomPaint` не обрезает, `FramedAvatar` складывает слои
// с `Clip.none` — рисунок доходит целиком.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../thermal_guard.dart';
import 'cosmetic_animation_scope.dart';
import 'cosmetic_motion_gate.dart';

/// Идентификаторы живых рамок. Отдельно от `kAvatarFrames`, потому что всё
/// остальное про рамки (атлас, упаковка, шов петли) к ним неприменимо.
const List<String> kLiveFrameIds = <String>['cat', 'coder', 'music'];

bool isLiveFrameId(String? id) => id != null && kLiveFrameIds.contains(id);

/// Ниже этого размера персонаж превращается в кашу: на 40 точках ухо занимает
/// три пикселя, а обводка в 2 точки мерцает. Макет говорит об этом прямо —
/// «до 48 px показывайте статичный кадр или только „дыхание“ кольца».
const double kLiveFrameMinAnimatedPx = 56;

/// 🔴 Ниже этого размера рисуется ОДНО КОЛЬЦО, без ушей, рук и нот.
///
/// Дело не только в разборчивости. Холст персонажа почти вдвое шире круга
/// портрета, и в строке списка чатов наушники «Меломана» легли бы прямо на имя
/// собеседника. Кольцо же помещается в квадрат: 64/58 от радиуса фотографии —
/// это 0.95 от стороны. Порог — тот самый из макета.
const double kLiveFrameFullPx = 48;

// ─────────────────────────── пружина ───────────────────────────

/// Пружина из макета: один шаг Эйлера, жёсткость `k`, затухание `c`.
///
/// 🔴 Перелёт — не украшение, а весь смысл: элемент проскакивает цель и
/// возвращается, поэтому движение читается как рисованное, а не как
/// интерполяция. Отсюда же «докачивание» кончика уха: у него своя пружина,
/// которая отстаёт от основания.
class LiveSpring {
  LiveSpring([double value = 0]) : x = value, v = 0, target = value;

  double x;
  double v;
  double target;

  void step(double dt, [double k = 180, double c = 11]) {
    final a = -k * (x - target) - c * v;
    v += a * dt;
    x += v * dt;
  }
}

double _clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);

Offset _pt(double cx, double cy, double r, double a) =>
    Offset(cx + r * math.sin(a), cy - r * math.cos(a));

/// Замкнутая гладкая кривая через точки — та же формула, что в макете
/// (касательная в точке равна шестой части отрезка между соседями).
Path _smooth(List<Offset> p) {
  final n = p.length;
  final path = Path()..moveTo(p[0].dx, p[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = p[(i - 1 + n) % n];
    final p1 = p[i];
    final p2 = p[(i + 1) % n];
    final p3 = p[(i + 2) % n];
    path.cubicTo(
      p1.dx + (p2.dx - p0.dx) / 6,
      p1.dy + (p2.dy - p0.dy) / 6,
      p2.dx - (p3.dx - p1.dx) / 6,
      p2.dy - (p3.dy - p1.dy) / 6,
      p2.dx,
      p2.dy,
    );
  }
  return path..close();
}

/// Круг, радиус которого ходит по углу: `fn(угол)` добавляется к `r`.
Path _blob(
  double cx,
  double cy,
  double r,
  double Function(double a) fn, [
  int n = 36,
]) {
  final pts = <Offset>[
    for (var i = 0; i < n; i++)
      () {
        final a = i / n * math.pi * 2;
        return _pt(cx, cy, r + fn(a), a);
      }(),
  ];
  return _smooth(pts);
}

/// Линейный переход как в SVG: координаты заданы долями рамки фигуры.
Shader _linear(Rect box, List<Color> colors, [double x2 = 1, double y2 = 1]) =>
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment(-1 + 2 * x2, -1 + 2 * y2),
      colors: colors,
    ).createShader(box);

// ─────────────────────────── персонажи ───────────────────────────

/// Цвета окружения, которые рамка берёт у темы: подложка под фотографией и
/// цвет «чернил» для нот. Остальное у персонажа своё — он узнаётся по цвету.
class LiveFrameTheme {
  const LiveFrameTheme({
    required this.bg,
    required this.ink,
    required this.band,
    required this.glove,
    required this.sleeve,
  });

  /// Светлая и тёмная из макета. Берутся по яркости поверхности, а не по
  /// `Theme.of(context).brightness`: у нас есть темы оформления, где светлая
  /// схема стоит на тёмной поверхности.
  factory LiveFrameTheme.of(Color surface) {
    final dark =
        ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;
    return dark
        ? LiveFrameTheme(
            bg: surface,
            ink: const Color(0xFFD8D8DE),
            band: const Color(0xFF5A5A6C),
            glove: const Color(0xFF2A2D3A),
            sleeve: const Color(0xFFFFA852),
          )
        : LiveFrameTheme(
            bg: surface,
            ink: const Color(0xFF2A2A30),
            band: const Color(0xFF2C2C34),
            glove: const Color(0xFF2A2D3A),
            sleeve: const Color(0xFFFF9F43),
          );
  }

  final Color bg;
  final Color ink;
  final Color band;
  final Color glove;
  final Color sleeve;
}

/// Один персонаж: где у него центр, какого радиуса кольцо и фотография,
/// как он считает своё состояние и как рисуется.
abstract class LiveFrameCharacter {
  double get cx;
  double get cy;
  double get ringR;
  double get avatarR;

  /// Насколько холст персонажа шире круга аватара. Нужен вызывающей стороне,
  /// чтобы не обрезать уши и ноты.
  double get canvasOverflow => 200 / (avatarR * 2);

  /// Шаг времени. [pressed] — единственный вход макета (погладить, дедлайн,
  /// пауза); у нас его пока некому нажимать, но ветка сохранена целиком.
  void tick(double t, double dt, bool pressed);

  /// Части, которые в макете лежат ПОД фотографией.
  void paintBack(Canvas canvas, LiveFrameTheme th, double t);

  /// Кольцо и всё, что поверх фотографии.
  void paintFront(Canvas canvas, LiveFrameTheme th, double t);

  /// Цвета кольца — они же определяют, каким увидят персонажа в списке чатов,
  /// где рисуется одно неподвижное кольцо.
  List<Color> get ringColors;

  /// Только кольцо и ободок — для маленьких портретов.
  void paintRingOnly(Canvas canvas, LiveFrameTheme th, double t) {
    paintRim(canvas, th);
    paintRing(canvas, t);
  }

  /// Общая часть всех трёх: кольцо-«капля», которое дышит, и преобразование
  /// тела (сжатие на удар, покачивание).
  @protected
  void paintRing(
    Canvas canvas,
    double t, {
    double sx = 1,
    double sy = 1,
    double rot = 0,
    double dx = 0,
    double dy = 0,
  }) {
    canvas.save();
    canvas.translate(cx + dx, cy + dy);
    canvas.rotate(rot * math.pi / 180);
    canvas.scale(sx, sy);
    canvas.translate(-cx, -cy);
    final path = _blob(
      cx,
      cy,
      ringR,
      (a) => 0.9 * math.sin(3 * a + t * 1.6) + 0.6 * math.sin(5 * a - t * 2.3),
    );
    final box = Rect.fromCircle(center: Offset(cx, cy), radius: ringR + 1);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..shader = _linear(box, ringColors),
    );
    canvas.restore();
  }

  /// Ободок между фотографией и кольцом. В макете это сплошной круг подложки
  /// ПОД аватаром; у нас фотографию рисует вызывающая сторона, поэтому тот же
  /// круг рисуется кольцевой полоской — видно одно и то же.
  @protected
  void paintRim(
    Canvas canvas,
    LiveFrameTheme th, {
    double sx = 1,
    double sy = 1,
  }) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(sx, sy);
    canvas.translate(-cx, -cy);
    canvas.drawCircle(
      Offset(cx, cy),
      avatarR + 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = th.bg,
    );
    canvas.restore();
  }
}

const Color _orange = Color(0xFFEE9446);
const Color _pink = Color(0xFFF9BDB2);

/// «Рыжик»: круглые уши на пружинах, ленивый хвост, лапки на нижнем крае.
class CatFrame extends LiveFrameCharacter {
  CatFrame([math.Random? rnd]) : _rnd = rnd ?? math.Random();

  final math.Random _rnd;

  @override
  double get cx => 100;
  @override
  double get cy => 112;
  @override
  double get ringR => 64;
  @override
  double get avatarR => 58;
  @override
  List<Color> get ringColors => const [
    Color(0xFFFFC06B),
    Color(0xFFF07A3A),
    Color(0xFFE0507A),
  ];

  final LiveSpring earL = LiveSpring();
  final LiveSpring earR = LiveSpring();
  final LiveSpring earY = LiveSpring(1);
  final LiveSpring sx = LiveSpring(1);
  final LiveSpring sy = LiveSpring(1);
  double next = 1.2;

  // Посчитанное в tick — рисование только читает.
  double _tailX0 = 0, _tailY0 = 0, _tipX = 0, _tipY = 0, _tailCx = 0;
  final List<double> _pawX = [0, 0], _pawY = [0, 0], _pawK = [0, 0];
  double _ringSx = 1, _ringSy = 1, _ringDx = 0;

  @override
  void tick(double t, double dt, bool pressed) {
    earL.target = pressed ? -58 : 0;
    earR.target = pressed ? 58 : 0;
    earY.target = pressed ? 0.62 : 1;
    // 🔴 Ухо дёргается в СЛУЧАЙНЫЙ момент раз в 2–5.5 секунды, и дёргается не
    // всегда то же самое. Ровный интервал глаз замечает за три повтора и
    // перестаёт верить, что рамка живая.
    if (!pressed && t > next) {
      final r = _rnd.nextDouble();
      if (r < 0.45 || r > 0.8) earL.v += 340;
      if (r >= 0.45) earR.v -= 340;
      next = t + 2 + _rnd.nextDouble() * 3.5;
    }
    earL.step(dt, 220, 9);
    earR.step(dt, 220, 9);
    earY.step(dt, 160, 10);

    sx.target = pressed ? 1.04 : 1;
    sy.target = pressed ? 0.955 : 1;
    sx.step(dt, 200, 10);
    sy.step(dt, 200, 10);
    final b = math.sin(t * 1.8) * 0.006;
    _ringSx = sx.x + b;
    _ringSy = sy.x - b;
    _ringDx = pressed ? math.sin(t * 75) * 0.45 : 0;

    final fq = pressed ? 6.5 : 1.4;
    final am = pressed ? 1.0 : 0.7;
    final t0 = _pt(cx, cy, ringR - 2, 2.2);
    final sw = math.sin(t * fq);
    _tailX0 = t0.dx;
    _tailY0 = t0.dy;
    _tipX = t0.dx + 26 + sw * 7 * am;
    _tipY = t0.dy - 40 + math.cos(t * fq * 0.9) * 4 * am;
    _tailCx = _tipX + 12 + sw * 10 * am;

    for (var i = 0; i < 2; i++) {
      final k = pressed ? math.max(0.0, math.sin(t * 6.5 + i * math.pi)) : 0.0;
      _pawK[i] = k;
      _pawX[i] = cx + (i == 1 ? 23 : -23) * sx.x;
      _pawY[i] = cy + ringR * sy.x - 1 - k * 5;
    }
  }

  @override
  void paintBack(Canvas canvas, LiveFrameTheme th, double t) {
    // Хвост и его кончик.
    final tail = Path()
      ..moveTo(_tailX0, _tailY0)
      ..cubicTo(_tailX0 + 20, _tailY0 + 6, _tailCx, _tipY + 24, _tipX, _tipY);
    canvas.drawPath(
      tail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..color = _orange,
    );
    canvas.drawCircle(
      Offset(_tipX, _tipY),
      5.6,
      Paint()..color = const Color(0xFFFFD6A3),
    );

    // Уши. Кончик отстаёт от основания — у него своя скорость, поэтому ухо
    // «гнётся», а не поворачивается целиком.
    for (final side in const [(-0.68, -1.0, true), (0.68, 1.0, false)]) {
      final a = side.$1;
      final sg = side.$2;
      final e = side.$3 ? earL : earR;
      final base = _pt(cx, cy, ringR - 8, a);
      final breathe = 1 + math.sin(t * 1.8 + sg) * 0.015;
      final tx = _clamp(-e.v * 0.022, -10, 10);
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate((a * 57.3 * 0.85 + e.x) * math.pi / 180);
      canvas.scale(1, earY.x * breathe);
      final outer = Path()
        ..moveTo(-21, 6)
        ..cubicTo(-21, -14, -10, -38, tx - 2, -45)
        ..quadraticBezierTo(tx, -47, tx + 2, -45)
        ..cubicTo(10, -38, 21, -14, 21, 6)
        ..close();
      canvas.drawPath(outer, Paint()..color = _orange);
      final inner = Path()
        ..moveTo(-11, 4)
        ..cubicTo(-11, -8, -5, -26, tx * 0.8 - 1, -32)
        ..quadraticBezierTo(tx * 0.8, -33.5, tx * 0.8 + 1, -32)
        ..cubicTo(5, -26, 11, -8, 11, 4)
        ..close();
      canvas.drawPath(inner, Paint()..color = _pink);
      canvas.restore();
    }
  }

  @override
  void paintFront(Canvas canvas, LiveFrameTheme th, double t) {
    paintRim(canvas, th, sx: _ringSx, sy: _ringSy);
    paintRing(canvas, t, sx: _ringSx, sy: _ringSy, dx: _ringDx);
    for (var i = 0; i < 2; i++) {
      final k = _pawK[i];
      canvas.save();
      canvas.translate(_pawX[i], _pawY[i]);
      canvas.scale(1 + k * 0.08, 1 - k * 0.12);
      final r = Rect.fromCenter(center: Offset.zero, width: 26, height: 19);
      canvas.drawOval(r, Paint()..color = _orange);
      canvas.drawOval(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = th.bg,
      );
      final pad = Paint()..color = _pink;
      canvas.drawCircle(const Offset(-6, -3), 2.3, pad);
      canvas.drawCircle(const Offset(0, -5), 2.3, pad);
      canvas.drawCircle(const Offset(6, -3), 2.3, pad);
      canvas.restore();
    }
  }
}

/// «Кодер»: гибкие руки выныривают из-за кольца, печатают и машут.
class CoderFrame extends LiveFrameCharacter {
  CoderFrame([math.Random? rnd]) : _rnd = rnd ?? math.Random();

  final math.Random _rnd;

  @override
  double get cx => 100;
  @override
  double get cy => 94;
  @override
  double get ringR => 64;
  @override
  double get avatarR => 58;
  @override
  List<Color> get ringColors => const [
    Color(0xFF3FC8FF),
    Color(0xFF7A5CFF),
    Color(0xFFF0478F),
  ];

  final LiveSpring out = LiveSpring();
  final LiveSpring lap = LiveSpring();
  final List<LiveSpring> jitter = [LiveSpring(), LiveSpring()];
  final LiveSpring wave = LiveSpring();
  double glow = 0;
  final List<double> _prev = [0, 0];

  double _glowOpacity = 0, _logoOpacity = 0.5, _lapScaleX = 1, _lapScaleY = 1;
  double _ringSx = 1, _ringSy = 1, _ringRot = 0;
  final List<Offset> _handAt = [Offset.zero, Offset.zero];
  final List<double> _handScale = [0, 0], _handRot = [0, 0];
  final List<Path> _arms = [Path(), Path()];
  final List<bool> _armVisible = [false, false];

  @override
  void tick(double t, double dt, bool pressed) {
    final ph = t % 9;
    out.target = pressed ? 1 : (ph > 0.5 && ph < 7.5 ? 1 : 0);
    out.step(dt, 150, 9);
    final waving = !pressed && ph > 6.2 && ph < 7.5;
    wave.target = waving ? 1 : 0;
    wave.step(dt, 120, 10);

    final typing = out.x > 0.8 && (pressed || ph < 6.2);
    final rate = pressed ? 8.5 : 3.6;
    final lifts = <double>[0, 0];
    for (var i = 0; i < 2; i++) {
      if (!typing) continue;
      final s = math.sin(t * rate * math.pi * 2 + i * math.pi);
      // 🔴 Вспышка привязана к УДАРУ, а не к фазе синуса: клавиатуру закрывает
      // крышка, и единственное, по чему видно «печатает», — присевший ноутбук
      // и мигнувший экран ровно в момент нажатия.
      if (_prev[i] > 0 && s <= 0) {
        glow = 1;
        lap.v += 22;
        jitter[i].target = (_rnd.nextDouble() - 0.5) * 12;
      }
      _prev[i] = s;
      lifts[i] = math.pow(math.max(0.0, s), 1.4).toDouble() * 5;
    }
    glow = math.max(0, glow - dt * 4);
    lap.step(dt, 400, 18);
    for (final j in jitter) {
      j.step(dt, 260, 16);
    }

    final e = math.max(0.0, out.x);
    final onScreen = _clamp(e, 0, 1);
    _glowOpacity = onScreen * (0.55 + glow * 0.45);
    _logoOpacity = _clamp(0.5 + onScreen * 0.3 + glow * 0.2, 0, 1);

    for (var i = 0; i < 2; i++) {
      final s = _pt(cx, cy, ringR - 1, i == 1 ? 2.05 : -1.62);
      var tx = (i == 1 ? 104.0 : 58.0) + jitter[i].x;
      var ty = (i == 1 ? 137.0 : 144.0) - lifts[i];
      if (i == 1) {
        final w = wave.x;
        tx += (142 - tx) * w + math.sin(t * 13) * 6 * w;
        ty += (100 - ty) * w;
      }
      final hx = s.dx + (tx - s.dx) * e;
      final hy = s.dy + (ty - s.dy) * e;
      final mx = i == 1 ? s.dx + 2 * e : s.dx - 40 * e;
      final my = i == 1 ? s.dy + 64 * e : (s.dy + hy) / 2 + 4 * e;
      _arms[i] = Path()
        ..moveTo(s.dx, s.dy)
        ..quadraticBezierTo(mx, my, hx, hy);
      _armVisible[i] = e >= 0.04;
      _handAt[i] = Offset(hx, hy);
      _handScale[i] = _clamp(e * 1.1, 0, 1.2);
      _handRot[i] = i == 1 ? math.sin(t * 13) * 18 * wave.x : 0;
    }

    _lapScaleX = 1 + lap.x * 0.012;
    _lapScaleY = 1 - lap.x * 0.018;
    _ringSx = 1 + math.sin(t * 1.7) * 0.006;
    _ringSy = 1 - math.sin(t * 1.7) * 0.006;
    _ringRot = pressed ? math.sin(t * 38) * 0.7 : 0;
  }

  @override
  void paintBack(Canvas canvas, LiveFrameTheme th, double t) {
    // У кодера за фотографией нет ничего: и свет экрана, и руки, и ноутбук
    // лежат ПОВЕРХ — иначе не видно, что свет падает на лицо.
  }

  @override
  void paintFront(Canvas canvas, LiveFrameTheme th, double t) {
    paintRim(canvas, th);
    // Свет экрана на фотографии.
    final glowRect = Rect.fromCenter(
      center: const Offset(86, 122),
      width: 84,
      height: 48,
    );
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF9BE7FF).withValues(alpha: 0.6 * _glowOpacity),
            const Color(0x009BE7FF),
          ],
        ).createShader(glowRect),
    );
    paintRing(canvas, t, sx: _ringSx, sy: _ringSy, rot: _ringRot);

    final sleeve = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = th.sleeve;
    for (var i = 0; i < 2; i++) {
      if (_armVisible[i]) canvas.drawPath(_arms[i], sleeve);
    }
    for (var i = 0; i < 2; i++) {
      canvas.save();
      canvas.translate(_handAt[i].dx, _handAt[i].dy);
      canvas.rotate(_handRot[i] * math.pi / 180);
      canvas.scale(_handScale[i]);
      final white = Paint()..color = Colors.white;
      final glove = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = th.glove;
      final thumb = Offset(i == 0 ? 6 : -6, -5);
      canvas.drawCircle(thumb, 3.8, white);
      canvas.drawCircle(thumb, 3.8, glove);
      canvas.drawCircle(Offset.zero, 8.5, white);
      canvas.drawCircle(Offset.zero, 8.5, glove);
      canvas.restore();
    }

    // Ноутбук закрывает кисти — печать видно по свету, а не по пальцам.
    canvas.save();
    canvas.translate(86, 152);
    canvas.scale(_lapScaleX, _lapScaleY);
    canvas.drawRRect(
      RRect.fromLTRBR(-46, 13, 46, 23, const Radius.circular(5)),
      Paint()..color = const Color(0xFF5A5D63),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(-12, 13, 12, 16, const Radius.circular(1.5)),
      Paint()..color = const Color(0xFF3E4045),
    );
    final screen = RRect.fromLTRBR(-41, -31, 41, 21, const Radius.circular(7));
    canvas.drawRRect(
      screen,
      Paint()
        ..shader = _linear(
          screen.outerRect,
          const [Color(0xFF72757C), Color(0xFF484B51)],
          0.3,
          1,
        ),
    );
    canvas.drawRRect(
      screen,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF35373C),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(-35, -27.5, 35, -26, const Radius.circular(0.75)),
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      const Offset(0, -5),
      5.5,
      Paint()..color = const Color(0xFFD9DCE2).withValues(alpha: _logoOpacity),
    );
    canvas.restore();
  }
}

/// «Меломан»: наушники подпрыгивают на бит, вокруг ходит жидкая волна.
class MusicFrame extends LiveFrameCharacter {
  MusicFrame();

  @override
  double get cx => 100;
  @override
  double get cy => 110;
  @override
  double get ringR => 60;
  @override
  double get avatarR => 54;
  @override
  List<Color> get ringColors => const [
    Color(0xFFF0478F),
    Color(0xFF9A5CFF),
    Color(0xFF2FB8F0),
  ];

  final LiveSpring amp = LiveSpring(1);
  final LiveSpring beat = LiveSpring();
  final LiveSpring notes = LiveSpring(1);
  int beatIndex = -1;

  double _a = 1, _b = 0;

  @override
  void tick(double t, double dt, bool pressed) {
    final play = !pressed;
    amp.target = play ? 1 : 0;
    notes.target = play ? 1 : 0;
    amp.step(dt, 50, 11);
    notes.step(dt, 60, 12);
    // 120 ударов в минуту. Это ТОЛЧОК пружины, а не ключевой кадр: каждый
    // отскок чуть другой, потому что предыдущий ещё не успел затухнуть.
    final bi = (t / 0.5).floor();
    if (play && bi != beatIndex) beat.v += bi % 2 != 0 ? 6 : 9;
    beatIndex = bi;
    beat.step(dt, 280, 13);
    _a = math.max(0.0, amp.x);
    _b = beat.x;
  }

  @override
  void paintBack(Canvas canvas, LiveFrameTheme th, double t) {
    final a = _a, b = _b;
    final box = Rect.fromCircle(center: Offset(cx, cy), radius: ringR + 22);
    final shader = _linear(
      box,
      const [Color(0xFFF0478F), Color(0xFF9A5CFF), Color(0xFF2FB8F0)],
      1,
      0,
    );
    canvas.drawPath(
      _blob(
        cx,
        cy,
        ringR + 13,
        (x) =>
            a *
                (4.5 * math.sin(3 * x + t * 2.1) +
                    3 * math.sin(5 * x - t * 3.3) +
                    2 * math.sin(9 * x + t * 4.6)) +
            b * 7 * a -
            (1 - a) * 9,
      ),
      Paint()
        ..shader = shader
        ..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.drawPath(
      _blob(
        cx,
        cy,
        ringR + 7,
        (x) =>
            a *
                (3 * math.sin(4 * x - t * 2.6 + 1) +
                    2.4 * math.sin(7 * x + t * 3.9)) +
            b * 4 * a -
            (1 - a) * 5,
      ),
      Paint()
        ..shader = shader
        ..color = Colors.white.withValues(alpha: 0.4),
    );
  }

  @override
  void paintFront(Canvas canvas, LiveFrameTheme th, double t) {
    final b = _b;
    paintRim(canvas, th);
    paintRing(canvas, t, sx: 1 + b * 0.012, sy: 1 - b * 0.01, rot: b * 2.4);

    final top = cy - 104 - b * 4;
    final band = Path()
      ..moveTo(cx - 72, cy - 4)
      ..cubicTo(cx - 74, top, cx + 74, top, cx + 72, cy - 4);
    canvas.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = th.band,
    );

    for (var i = 0; i < 2; i++) {
      final sg = i == 1 ? 1.0 : -1.0;
      canvas.save();
      canvas.translate(cx + sg * 72, cy + 8);
      canvas.rotate(-sg * b * 5 * math.pi / 180);
      canvas.scale(1 + b * 0.1, 1 - b * 0.07);
      canvas.drawRRect(
        RRect.fromLTRBR(-14, -26, 14, 26, const Radius.circular(14)),
        Paint()
          ..color = i == 1 ? const Color(0xFF2FB8F0) : const Color(0xFFF0478F),
      );
      canvas.drawRRect(
        RRect.fromLTRBR(
          i == 0 ? 4 : -10,
          -18,
          i == 0 ? 10 : -4,
          18,
          const Radius.circular(3),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
      canvas.restore();
    }

    for (var i = 0; i < 3; i++) {
      final u = ((t + i * 0.95) % 2.85) / 2.85;
      final x = cx + 50 + 16 * u + math.sin(u * 6 + i * 2) * 6;
      final y = cy - 50 - 60 * u;
      // Нота ВЫСКАКИВАЕТ: первые 16 % пути она переросла свой размер и
      // возвращается к нему. Появление без этого читается как «включили».
      final pop = u < 0.16
          ? () {
              final q = u / 0.16 - 1;
              return 1 + 2.7 * q * q * q + 1.7 * q * q;
            }()
          : 1.0;
      final op =
          (u < 0.1 ? u / 0.1 : 1 - (u - 0.1) / 0.9) * _clamp(notes.x, 0, 1);
      if (op <= 0.01) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(u * 5 + i) * 14 * math.pi / 180);
      canvas.scale(pop);
      canvas.drawPath(
        _notePath(pair: i == 1),
        Paint()..color = th.ink.withValues(alpha: _clamp(op, 0, 1)),
      );
      canvas.restore();
    }
  }
}

/// Нота как ФИГУРА, а не как символ шрифта.
///
/// 🔴 Знаки ♪ и ♫ есть не в каждом шрифте: в нашем Onest их нет, и на месте
/// ноты получается пустой прямоугольник. Проверено на сборке 23.09.2026 —
/// именно так они и выглядели. Рисуем сами, заодно у ноты появляются
/// скруглённые концы, как просит макет («ни одного острого угла»).
Path _notePath({required bool pair}) {
  final p = Path();
  void head(double cx, double cy) {
    final m = Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..rotateZ(-0.35);
    p.addPath(
      Path()..addOval(
        Rect.fromCenter(center: Offset.zero, width: 8.6, height: 6.4),
      ),
      Offset.zero,
      matrix4: m.storage,
    );
  }

  if (pair) {
    head(-5.5, 6);
    head(5.5, 4);
    p.addRRect(
      RRect.fromLTRBR(-1.8, -8, -0.2, 6, const Radius.circular(0.8)),
    );
    p.addRRect(
      RRect.fromLTRBR(8.2, -10, 9.8, 4, const Radius.circular(0.8)),
    );
    // Перекладина между хвостиками — слегка наклонная, как в наборном знаке.
    p.addPath(
      Path()
        ..moveTo(-1.8, -8)
        ..lineTo(9.8, -10)
        ..lineTo(9.8, -6.4)
        ..lineTo(-1.8, -4.4)
        ..close(),
      Offset.zero,
    );
  } else {
    head(-4, 6);
    p.addRRect(
      RRect.fromLTRBR(-0.3, -9, 1.3, 6, const Radius.circular(0.8)),
    );
    // Флажок.
    p.addPath(
      Path()
        ..moveTo(1.3, -9)
        ..quadraticBezierTo(7.4, -6.4, 5.2, -0.6)
        ..quadraticBezierTo(6, -5.4, 1.3, -5.6)
        ..close(),
      Offset.zero,
    );
  }
  return p;
}

LiveFrameCharacter makeLiveFrame(String id, [math.Random? rnd]) {
  switch (id) {
    case 'cat':
      return CatFrame(rnd);
    case 'coder':
      return CoderFrame(rnd);
    case 'music':
      return MusicFrame();
  }
  throw ArgumentError('не живая рамка: $id');
}

// ─────────────────────────── показ ───────────────────────────

/// Рамка-персонаж на квадрате [size].
///
/// Рисуется в координатах макета (холст 200×200) и СОЗНАТЕЛЬНО выходит за
/// квадрат: там уши, руки и ноты. Вызывающая сторона не должна обрезать.
class LiveFrameView extends StatefulWidget {
  const LiveFrameView({
    super.key,
    required this.size,
    required this.id,
    this.pressed = false,
  });

  final double size;
  final String id;

  /// Единственный вход макета. Сейчас его некому нажимать — портрет всюду
  /// завёрнут в `IgnorePointer`, — но ветка живая и проверяется тестами.
  final bool pressed;

  @override
  State<LiveFrameView> createState() => _LiveFrameViewState();
}

class _LiveFrameViewState extends State<LiveFrameView>
    with SingleTickerProviderStateMixin {
  // Не `late final`: тикер, созданный лениво, был бы построен уже внутри
  // dispose(), а createTicker смотрит TickerMode на умершем элементе.
  Ticker? _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  late LiveFrameCharacter _ch = makeLiveFrame(widget.id);
  double _t = 0;
  double _last = 0;
  bool _animated = false;

  @override
  void initState() {
    super.initState();
    // Разные рамки в одном списке не должны шагать в ногу.
    _t = math.Random().nextDouble() * 2;
    _ch.tick(_t, 0, widget.pressed);
  }

  @override
  void didUpdateWidget(covariant LiveFrameView old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      _ch = makeLiveFrame(widget.id);
      _ch.tick(_t, 0, widget.pressed);
    }
    if (old.size != widget.size) _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  void _syncTicker() {
    // 🔴 Четыре условия, и каждое стоило отдельного разбора:
    // настройка «украшения собеседников» (списки и чат), немой тикер под
    // закрытым маршрутом, «меньше движения» в системе и размер. Ниже 56 точек
    // персонаж превращается в кашу, и макет прямо велит показывать кадр.
    final allowed =
        CosmeticAnimationScope.of(context) &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        widget.size >= kLiveFrameMinAnimatedPx;
    if (allowed == _animated) return;
    _animated = allowed;
    if (allowed) {
      _last = DateTime.now().millisecondsSinceEpoch / 1000.0;
      (_ticker ??= createTicker(_onTick)).start();
    } else {
      _ticker?.stop();
    }
  }

  void _onTick(Duration _) {
    // Держим картинку, пока устройство греется или пока список летит: в эти
    // мгновения каждая миллисекунда принадлежит прокрутке.
    if (!ThermalGuard.effectsAllowed.value) return;
    if (CosmeticMotionGate.holdAnimations) return;
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    // Тот же потолок, что у петель: пружинам 60 кадров в секунду достаточно,
    // а на 120-герцевом экране это ровно вдвое меньше работы.
    final dt = now - _last;
    if (dt < 1 / 60) return;
    _last = now;
    // Шаг Эйлера разваливается на длинном кадре: ограничение в 33 мс — то же,
    // что в макете, и оно же спасает после возвращения из фона.
    final step = dt > 0.033 ? 0.033 : dt;
    _t += step;
    _ch.tick(_t, step, widget.pressed);
    _repaint.value++;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = LiveFrameTheme.of(Theme.of(context).colorScheme.surface);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: LiveFramePainter(
            character: _ch,
            theme: th,
            time: () => _t,
            ringOnly: widget.size < kLiveFrameFullPx,
            repaint: _repaint,
          ),
        ),
      ),
    );
  }
}

/// Рисует персонажа в координатах макета, подгоняя круг аватара под наш.
class LiveFramePainter extends CustomPainter {
  LiveFramePainter({
    required this.character,
    required this.theme,
    required this.time,
    this.ringOnly = false,
    super.repaint,
  });

  final LiveFrameCharacter character;
  final LiveFrameTheme theme;
  final double Function() time;

  /// Рисовать одно кольцо — см. [kLiveFrameFullPx].
  final bool ringOnly;

  /// Доля квадрата, которую занимает фотография у `FramedAvatar`.
  static const double avatarFraction = 0.86;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time();
    final k = (size.width * avatarFraction / 2) / character.avatarR;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(k);
    canvas.translate(-character.cx, -character.cy);

    if (ringOnly) {
      character.paintRingOnly(canvas, theme, t);
      canvas.restore();
      return;
    }

    // Задние части — с вырезанным кругом фотографии: в макете их закрывает
    // подложка под аватаром, у нас закрывает сама фотография.
    canvas.save();
    canvas.clipPath(photoHole(character));
    character.paintBack(canvas, theme, t);
    canvas.restore();

    character.paintFront(canvas, theme, t);
    canvas.restore();
  }

  /// Весь холст МИНУС круг фотографии. Задние части персонажа рисуются
  /// только здесь — это и заменяет второй слой под аватаром.
  static Path photoHole(LiveFrameCharacter ch) => Path.combine(
    PathOperation.difference,
    Path()..addRect(const Rect.fromLTRB(-260, -260, 460, 460)),
    Path()..addOval(
      Rect.fromCircle(center: Offset(ch.cx, ch.cy), radius: ch.avatarR),
    ),
  );

  @override
  bool shouldRepaint(covariant LiveFramePainter old) =>
      old.character != character ||
      old.theme != theme ||
      old.ringOnly != ringOnly;
}
