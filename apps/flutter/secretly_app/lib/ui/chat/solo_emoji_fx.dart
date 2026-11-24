// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Эмодзи отдельным сообщением: эффект на весь экран (макет «Solo Emoji»,
/// 21.11.2026; 63 эмодзи — 23.11.2026).
///
/// Правила владельца:
/// * крупная анимация (Lottie + эффект) играет ОДИН РАЗ у человека — на
///   каждое сообщение — и снова по касанию пальцем;
/// * без «статичной» анимации (парение, дыхание тени по кругу) — она грузила
///   бы систему: уже виденный эмодзи стоит неподвижно;
/// * эмодзи отдельным сообщением — чуть меньше прежнего (160 → 132).
///
/// У 63 эмодзи макета — свой эффект (❤️ удары сердца и розовые волны, 🔥
/// раскалённый низ и искры, 🎉 конфетти-пушки, 😂 слёзы дугами, 👻 гаснет
/// свет, ⚡ молнии, 🤣 «HA-HA» и качка чата, 😢 тучка и серый мир, 🤡
/// «HONK!», 😬 трещины, 🌈 радуга, 🏆 салюты…); любой другой — эффект
/// реакции. Все частицы — один [CustomPainter] (как у реакций), один эффект
/// за раз. Движение эмодзи и всего чата (тряска, качка, перекос) — дорожки
/// [SoloEmojiTrack], окраска эмодзи (краснеет, вспыхивает) — [SoloEmojiTint].
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reaction_burst.dart';
import 'route_bound_fx.dart';

/// Размер эмодзи отдельным сообщением (было 160).
const double kSoloEmojiSize = 132;

/// Окраска эмодзи во время эффекта (CSS `filter` макета): цепочка
/// `sepia → saturate → hue-rotate → brightness`; сила — `v` кадров.
class SoloEmojiTint {
  const SoloEmojiTint({
    this.sepia = 0,
    this.saturate = 1,
    this.hue = 0,
    this.brightness = 1,
  });

  final double sepia;
  final double saturate;
  final double hue;
  final double brightness;

  /// Матрица 4×5 для [ColorFilter.matrix] при силе [v] (0…1): параметры
  /// растут от «без фильтра», как интерполирует CSS.
  List<double> matrix(double v) {
    final k = v.clamp(0.0, 1.0);
    final sp = sepia * k, st = 1 + (saturate - 1) * k;
    final hu = hue * k * math.pi / 180, br = 1 + (brightness - 1) * k;
    final q = 1 - sp;
    final sep = [
      0.393 + 0.607 * q, 0.769 - 0.769 * q, 0.189 - 0.189 * q, //
      0.349 - 0.349 * q, 0.686 + 0.314 * q, 0.168 - 0.168 * q, //
      0.272 - 0.272 * q, 0.534 - 0.534 * q, 0.131 + 0.869 * q,
    ];
    final sat = [
      0.213 + 0.787 * st, 0.715 - 0.715 * st, 0.072 - 0.072 * st, //
      0.213 - 0.213 * st, 0.715 + 0.285 * st, 0.072 - 0.072 * st, //
      0.213 - 0.213 * st, 0.715 - 0.715 * st, 0.072 + 0.928 * st,
    ];
    final c = math.cos(hu), s = math.sin(hu);
    final hue3 = [
      0.213 + c * 0.787 - s * 0.213,
      0.715 - c * 0.715 - s * 0.715,
      0.072 - c * 0.072 + s * 0.928,
      0.213 - c * 0.213 + s * 0.143,
      0.715 + c * 0.285 + s * 0.140,
      0.072 - c * 0.072 - s * 0.283,
      0.213 - c * 0.213 - s * 0.787,
      0.715 - c * 0.715 + s * 0.715,
      0.072 + c * 0.928 + s * 0.072,
    ];
    List<double> mul(List<double> a, List<double> b) => [
      for (var i = 0; i < 3; i++)
        for (var j = 0; j < 3; j++)
          a[i * 3] * b[j] + a[i * 3 + 1] * b[3 + j] + a[i * 3 + 2] * b[6 + j],
    ];
    final m = mul(hue3, mul(sat, sep));
    return [
      m[0] * br, m[1] * br, m[2] * br, 0, 0, //
      m[3] * br, m[4] * br, m[5] * br, 0, 0, //
      m[6] * br, m[7] * br, m[8] * br, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }
}

/// Дорожка движения (эмодзи или всего чата): кадры от покоя, задержка,
/// сглаживание; вне своего отрезка — покой (как `fill: none` макета).
class SoloEmojiTrack {
  SoloEmojiTrack({
    required List<ReactionFrame> frames,
    required double ms,
    double delay = 0,
    Curve curve = Curves.linear,
    this.pivot = Offset.zero,
    this.tint,
  }) : _p = ReactionParticle(
         shape: ReactionShape.dot,
         frames: frames,
         duration: ms,
         delay: delay,
         curve: curve,
       );

  final ReactionParticle _p;

  /// Точка поворота и масштаба: у эмодзи — доля его размера от центра
  /// (макет: `transform-origin: 50% 85%`), у чата — точка экрана.
  final Offset pivot;

  /// Окраска эмодзи (дорожка без движения, сила — `v` кадров).
  final SoloEmojiTint? tint;

  List<ReactionFrame> get frames => _p.frames;
  double get ms => _p.duration;
  double get delay => _p.delay;
  double get end => _p.end;
  ReactionFrame? at(double t) => _p.at(t);
}

/// Эффект целиком: частицы на экране, движение эмодзи и всего чата.
class SoloEmojiEffect {
  SoloEmojiEffect({
    required this.particles,
    this.cards = const [],
    this.tints = const [],
    this.screen = const [],
  });

  final List<ReactionParticle> particles;

  /// Движение эмодзи (поздняя дорожка перекрывает раннюю, как в WAAPI).
  final List<SoloEmojiTrack> cards;

  /// Окраска эмодзи.
  final List<SoloEmojiTrack> tints;

  /// Движение всего чата (тряска, качка, перекос, приближение).
  final List<SoloEmojiTrack> screen;

  /// Все кадры движения эмодзи подряд.
  List<ReactionFrame> get card => [for (final t in cards) ...t.frames];

  double get cardMs => [
    ...cards,
    ...tints,
  ].fold<double>(0, (a, t) => math.max(a, t.end));

  double get screenMs => screen.fold<double>(0, (a, t) => math.max(a, t.end));

  /// Сколько живёт слой эффекта (частицы и движение чата).
  double get layerMs =>
      math.max(reactionBurstDuration(particles), screenMs);

  double get durationMs => math.max(layerMs, cardMs);
}

/// 63 эмодзи макета и 🌞 (у остальных — эффект реакции).
const Set<String> kSoloEmojiWithEffect = {
  '❤️', '🔥', '🎉', '😂', '😘', '👻', '🤯', '⚡', '🚀', '🥶', //
  '👍', '😭', '🙏', '🥰', '😍', '😊', '🥺', '😅', '🤔', '👏', //
  '😎', '😡', '💯', '🤗', '💩', '🎂', '🌹', '👋', '💀', '🥳', //
  '🤣', '😢', '😁', '😉', '😋', '🤪', '🙄', '😴', '😱', '😳', //
  '🤩', '😇', '🤡', '🤮', '😏', '😔', '😬', '🫠', '😈', '🤑', //
  '💔', '❤️‍🔥', '💪', '🙌', '🫶', '👀', '✨', '🌈', '☀️', '🎁', //
  '🏆', '🍾', '🌚', //
  // У Noto нет анимации ☀️ (её нельзя отправить крупным эмодзи) — эффект
  // «Солнце» получает и 🌞, у которого анимация есть (23.11.2026).
  '🌞', //
};

/// Без знака варианта U+FE0F (❤ и ❤️, ❤‍🔥 и ❤️‍🔥 — один эмодзи).
final Map<String, String> _soloByBare = {
  for (final e in kSoloEmojiWithEffect) e.replaceAll('\u{FE0F}', ''): e,
};

/// Эмодзи макета для [e] (с U+FE0F или без), `null` — не из макета.
String? _soloKey(String e) {
  final t = e.trim();
  if (kSoloEmojiWithEffect.contains(t)) return t;
  return _soloByBare[t.replaceAll('\u{FE0F}', '')];
}

/// У эмодзи [e], отправленного отдельным сообщением, есть свой эффект на
/// весь экран (а не общий эффект реакции). Панель эмодзи помечает такие
/// серой точкой.
bool hasSoloEmojiEffect(String e) => _soloKey(e) != null;

SoloEmojiEffect soloEmojiEffect(
  String e, {
  required Size screen,
  required Offset origin,
  math.Random? random,
}) => _SoloBuilder(random ?? math.Random(), screen, origin)
    .buildSolo(_soloKey(e) ?? e);

typedef _F = ReactionFrame;

Color _c(int r, int g, int b, double a) => Color.fromRGBO(r, g, b, a);

/// Тот же цвет, прозрачный (CSS `transparent` без тёмной каймы в градиенте).
Color _clr(Color c) => c.withValues(alpha: 0);

class _SoloBuilder extends ReactionFxBuilder {
  _SoloBuilder(math.Random rnd, this.size, this.o) : super(rnd, 1);

  final Size size;
  final Offset o;
  final List<SoloEmojiTrack> cards = [];
  final List<SoloEmojiTrack> tints = [];
  final List<SoloEmojiTrack> screen = [];

  double get W => size.width;
  double get H => size.height;

  /// Высота макета (844): точки «снизу» пересчитываются к настоящему экрану.
  double fromBottom(double y) => H - (844 - y);

  static const _outC = Cubic(0.15, 0.75, 0.35, 1);
  static const _spring = Cubic(0.2, 1.4, 0.4, 1);
  static const _waapiOut = Cubic(0.33, 1, 0.68, 1);
  static const _sq2 = math.sqrt2;

  /// Точка поворота эмодзи: `transform-origin: 50% 85%` макета.
  static const _pivot = Offset(0, 0.35);

  static const _conf = [
    Color(0xFFFFD43B),
    Color(0xFFFF6B9A),
    Color(0xFF4DABF7),
    Color(0xFF69DB7C),
    Color(0xFFB197FC),
    Color(0xFFFF922B),
  ];

  // ── Помощники макета (`fx()`): точка (x, y) — абсолютная на экране ──

  List<_F> _abs(double x, double y, List<_F> f) => [
    for (final k in f) k.shift(x - o.dx, y - o.dy),
  ];

  void g(
    String ch,
    double sz,
    double x,
    double y,
    List<_F> f,
    double d, [
    double dl = 0,
    Curve cv = Curves.linear,
  ]) => glyph(ch, sz, _abs(x, y, f), d, dl, cv);

  void dt(
    double sz,
    Color c,
    double x,
    double y,
    List<_F> f,
    double d, [
    double dl = 0,
    Curve cv = Curves.linear,
    bool shine = false,
  ]) => dot(sz, c, _abs(x, y, f), d, dl, cv, shine);

  void rc(
    double w,
    double h,
    Color c,
    double x,
    double y,
    List<_F> f,
    double d, [
    double dl = 0,
    Curve cv = Curves.linear,
    double radius = 2,
  ]) => rect(w, h, c, _abs(x, y, f), d, dl, cv, radius);

  /// Прямоугольник с градиентом (сверху вниз, если [vertical]).
  void rcg(
    double w,
    double h,
    List<Color> cols,
    double x,
    double y,
    List<_F> f,
    double d,
    double dl,
    Curve cv, {
    double radius = 2,
    bool vertical = true,
    List<double>? stops,
    Color? glowColor,
    double blur = 0,
  }) => add(
    ReactionParticle(
      shape: ReactionShape.rect,
      width: w,
      height: h,
      colors: cols,
      stops: stops,
      vertical: vertical,
      radius: radius,
      glowColor: glowColor,
      blur: blur,
      frames: _abs(x, y, f),
      duration: d,
      delay: dl,
      curve: cv,
    ),
  );

  void dr(
    double sz,
    double x,
    double y,
    List<_F> f,
    double d, [
    double dl = 0,
    Curve cv = Curves.linear,
    List<Color>? cols,
  ]) => drop(sz, _abs(x, y, f), d, dl, cv, cols);

  /// Пятно (CSS-блок с фоном): овал/скруглённый прямоугольник, радиальный
  /// градиент, обводка, тень.
  void blob(
    double w,
    double h,
    double x,
    double y,
    List<_F> f,
    double d, {
    double dl = 0,
    Curve cv = Curves.linear,
    Color color = const Color(0x00000000),
    List<Color>? cols,
    List<double>? stops,
    double gradR = 1,
    Alignment gradCenter = Alignment.center,
    bool oval = true,
    double radius = 0,
    double border = 0,
    Color? borderColor,
    Color? glowColor,
    double blur = 0,
    double shadowDy = 0,
  }) => add(
    ReactionParticle(
      shape: ReactionShape.blob,
      width: w,
      height: h,
      color: color,
      colors: cols,
      stops: stops,
      gradR: gradR,
      gradCenter: gradCenter,
      oval: oval,
      radius: radius,
      border: border,
      borderColor: borderColor,
      glowColor: glowColor,
      blur: blur,
      shadowDy: shadowDy,
      frames: _abs(x, y, f),
      duration: d,
      delay: dl,
      curve: cv,
    ),
  );

  /// Свечение макета: `radial-gradient(circle, c 0%, transparent 68%)`.
  void glw(Color c, double sz, double d, [double dl = 0]) => blob(
    sz,
    sz,
    o.dx,
    o.dy,
    const [
      _F(s: 0.3, o: 0),
      _F(s: 1.05, at: 0.3),
      _F(o: 0),
    ],
    d,
    dl: dl,
    cv: Curves.easeOut,
    cols: [c, _clr(c)],
    stops: const [0, 0.68],
    gradR: _sq2,
  );

  /// Круглое свечение-пятно [sz] с [c] в центре (`transparent` на [stop]).
  void spot(
    double sz,
    Color c,
    double x,
    double y,
    List<_F> f,
    double d, [
    double dl = 0,
    Curve cv = Curves.linear,
    double stop = 0.65,
  ]) => blob(
    sz,
    sz,
    x,
    y,
    f,
    d,
    dl: dl,
    cv: cv,
    cols: [c, _clr(c)],
    stops: [0, stop],
    gradR: _sq2,
  );

  /// Кольцо с растяжением по осям (круги на «полу» 😢).
  void ringF(Color c, double sz, double bw, double x, double y, List<_F> f,
          double d, [double dl = 0, Curve cv = Curves.linear]) =>
      add(
        ReactionParticle(
          shape: ReactionShape.ring,
          size: sz,
          border: bw,
          color: c,
          frames: _abs(x, y, f),
          duration: d,
          delay: dl,
          curve: cv,
        ),
      );

  void lay(
    ReactionLayer l,
    List<_F> f,
    double d, [
    double dl = 0,
    Curve cv = Curves.linear,
  ]) => add(
    ReactionParticle(
      shape: ReactionShape.screen,
      layer: l,
      frames: f,
      duration: d,
      delay: dl,
      curve: cv,
    ),
  );

  /// CSS `box-shadow: inset 0 0 [blur]px [spread]px c` на весь экран.
  void inset(
    Color c,
    double blur,
    double spread,
    List<_F> f,
    double d, [
    double dl = 0,
    Curve cv = Curves.linear,
  ]) => lay(
    ReactionLayer(
      kind: ReactionLayerKind.inset,
      colors: [c],
      spread: spread,
      blur: blur,
    ),
    f,
    d,
    dl,
    cv,
  );

  /// Сплошное затемнение с просветом у эмодзи и обесцвечиванием под ним.
  void dim(Color c, double gray, List<_F> f, double d,
          [double dl = 0, Curve cv = Curves.linear, bool hole = true]) =>
      lay(ReactionLayer(colors: [c], hole: hole, gray: gray), f, d, dl, cv);

  /// Темнота вокруг эмодзи: прозрачно до [r0], цвет [c] с [r1].
  void dark(Color c, double r0, double r1, List<_F> f, double d,
          [double dl = 0, Curve cv = Curves.linear]) =>
      lay(
        ReactionLayer(
          kind: ReactionLayerKind.radial,
          center: o,
          r1: r1,
          colors: [_clr(c), c],
          stops: [r0 / r1, 1],
        ),
        f,
        d,
        dl,
        cv,
      );

  /// `radial-gradient(circle at fx% fy%, a, b)` до дальнего угла.
  void wash(List<Color> cols, List<_F> f, double d,
          {double fx = 0.5, double fy = 0.5, List<double>? stops,
          double dl = 0, Curve cv = Curves.linear}) =>
      lay(
        ReactionLayer(
          kind: ReactionLayerKind.radial,
          center: Offset(W * fx, H * fy),
          colors: cols,
          stops: stops,
        ),
        f,
        d,
        dl,
        cv,
      );

  void linear(List<Color> cols, List<_F> f, double d,
          {Alignment begin = Alignment.topCenter,
          Alignment end = Alignment.bottomCenter,
          List<double>? stops,
          Rect? area,
          bool hue = false,
          double dl = 0,
          Curve cv = Curves.linear}) =>
      lay(
        ReactionLayer(
          kind: ReactionLayerKind.linear,
          colors: cols,
          stops: stops,
          begin: begin,
          end: end,
          area: area,
          hue: hue,
        ),
        f,
        d,
        dl,
        cv,
      );

  static List<_F> op(List<double> o, [List<double>? at]) => [
    for (var i = 0; i < o.length; i++)
      _F(o: o[i], at: at == null ? null : at[i]),
  ];

  void fl(Color c, [double d = 260, double dl = 0, double peak = 1]) => add(
    ReactionParticle(
      shape: ReactionShape.flash,
      color: c,
      frames: [const _F(o: 0), _F(o: peak, at: 0.15), const _F(o: 0)],
      duration: d,
      delay: dl,
      curve: Curves.easeOut,
    ),
  );

  /// Тряска всего чата (макет `shake`): 11 кадров, размах гаснет.
  void shake(double amp, double d, [double dl = 0]) {
    scr([
      for (var i = 0; i <= 10; i++)
        i == 0 || i == 10
            ? const _F()
            : _F(
                x: (i.isOdd ? 1 : -1) * amp * (1 - i / 10),
                y: (i % 3 - 1) * amp * (1 - i / 10) * 0.5,
              ),
    ], d, dl);
  }

  /// Движение всего чата вокруг [pivot] (по умолчанию — середина экрана).
  void scr(List<_F> f, double d,
      [double dl = 0, Curve cv = Curves.linear, Offset? pivot]) {
    screen.add(
      SoloEmojiTrack(
        frames: f,
        ms: d,
        delay: dl,
        curve: cv,
        pivot: pivot ?? Offset(W / 2, H / 2),
      ),
    );
  }

  /// Движение эмодзи (макет `card`, по умолчанию `ease-in-out`).
  void card(List<_F> f, double d,
      [double dl = 0, Curve cv = Curves.easeInOut, Offset pivot = _pivot]) {
    cards.add(
      SoloEmojiTrack(frames: f, ms: d, delay: dl, curve: cv, pivot: pivot),
    );
  }

  /// Окраска эмодзи: `v` кадров — сила фильтра.
  void tint(SoloEmojiTint t, List<_F> f, double d,
      [double dl = 0, Curve cv = Curves.linear]) {
    tints.add(SoloEmojiTrack(frames: f, ms: d, delay: dl, curve: cv, tint: t));
  }

  /// Свечение вокруг эмодзи (CSS `drop-shadow` макета) — кольцом поверх.
  void halo(Color c, List<_F> f, double d,
          [double dl = 0, Curve cv = Curves.linear]) =>
      blob(
        kSoloEmojiSize * 1.3,
        kSoloEmojiSize * 1.3,
        o.dx,
        o.dy,
        f,
        d,
        dl: dl,
        cv: cv,
        cols: [_clr(c), _clr(c), c, _clr(c)],
        stops: const [0, 0.6, 0.72, 1],
      );

  /// Дрожь эмодзи (макет `shiver`): 17 кадров, сдвиг влево-вправо.
  void shiver(double amp, double d, [double dl = 0]) => card([
    for (var i = 0; i <= 16; i++)
      i == 0 || i == 16 ? const _F() : _F(x: (i.isOdd ? 1 : -1) * amp),
  ], d, dl, Curves.linear);

  /// Путь с покачиванием (макет `sway`): [mk] дополняет кадр.
  List<_F> sway(
    double x0,
    double y0,
    double x1,
    double y1,
    double amp,
    double ph, [
    int steps = 6,
    _F Function(double x, double y, double t, int j, int s)? mk,
  ]) => [
    for (var j = 0; j <= steps; j++)
      () {
        final t = j / steps;
        final x = x0 + (x1 - x0) * t + math.sin(ph + t * 5) * amp;
        final y = y0 + (y1 - y0) * t;
        return mk == null ? _F(x: x, y: y) : mk(x, y, t, j, steps);
      }(),
  ];

  /// Луч прожектора из точки (x, y) вниз, наклон a0 → a1 (градусы).
  void beam(double x, double y, double len, double w, Color c, double a0,
      double a1, double d, [double dl = 0]) {
    final da = a1 - a0;
    add(
      ReactionParticle(
        shape: ReactionShape.beam,
        width: w,
        height: len,
        colors: [c, _clr(c)],
        frames: _abs(x, y, [
          _F(r: a0, o: 0),
          _F(r: a0 + da * 0.2, at: 0.2),
          _F(r: a0 + da * 0.8, at: 0.8),
          _F(r: a1, o: 0),
        ]),
        duration: d,
        delay: dl,
        curve: Curves.easeInOut,
      ),
    );
  }

  void petal(double x, double y, List<_F> f, double d, double dl, Color c) =>
      add(
        ReactionParticle(
          shape: ReactionShape.petal,
          width: r(9, 13),
          height: r(13, 18),
          color: c,
          frames: _abs(x, y, f),
          duration: d,
          delay: dl,
        ),
      );

  /// Конфетти сверху на весь экран (макет `confettiRain`).
  void confettiRain(int cnt, List<Color> cols,
      [double d0 = 2200, double dl0 = 0]) {
    for (var i = 0; i < cnt; i++) {
      final x = r(0, W), rr = r(300, 900);
      rc(
        r(5, 9),
        r(9, 14),
        cols[i % cols.length],
        x,
        -20,
        sway(0, 0, r(-40, 40), H + 40, 26, r(0, 6), 6,
            (x, y, t, j, s) => _F(x: x, y: y, r: t * rr, o: j == s ? 0 : 1)),
        r(d0, d0 + 900),
        dl0 + r(0, 1200),
      );
    }
  }

  void popAt(String ch, double sz, double x, double y, double d, double dl,
          [double rot = 0]) =>
      g(ch, sz, x, y, [
        _F(s: 0, o: 0, r: rot),
        _F(s: 1.2, at: 0.25, r: rot, curve: _spring),
        _F(s: 1, at: 0.7, r: rot),
        _F(s: 0.6, o: 0, r: rot),
      ], d, dl);

  /// Взрыв мини-эмодзи от центра (с гравитацией).
  void burstG(List<String> chars, int cnt, double d0, double d1, double s0,
      double s1, [double dl = 0, double grav = 0]) {
    for (var i = 0; i < cnt; i++) {
      final a = r(0, 2 * math.pi), d = r(d0, d1);
      glyph(chars[i % chars.length], r(s0, s1), [
        const _F(s: 0.2, o: 0),
        _F(
          x: math.cos(a) * d * 0.6,
          y: math.sin(a) * d * 0.6,
          s: 1,
          r: r(-30, 30),
          at: 0.3,
        ),
        _F(
          x: math.cos(a) * d,
          y: math.sin(a) * d + grav,
          s: 0.6,
          o: 0,
          r: r(-90, 90),
        ),
      ], r(900, 1300), dl + r(0, 80), _outC);
    }
  }

  void twinkles(int cnt, [double dl0 = 0, double spread = 1600]) {
    for (var i = 0; i < cnt; i++) {
      final x = r(20, W - 20), y = r(80, H - 120);
      g('✨', r(12, 22), x, y, [
        const _F(s: 0, o: 0),
        _F(s: 1, r: r(-40, 40), at: 0.45),
        const _F(s: 0, o: 0),
      ], r(700, 1000), dl0 + r(0, spread), Curves.easeInOut);
    }
  }

  /// Чёрточка от точки наружу под углом [a] (макет `radial`): из r0 в r1.
  void rad(double a, double w, double h, Color c, double r0, double r1,
      double d, double dl, {double? x, double? y, List<Color>? cols}) {
    final th = (a + 90) * math.pi / 180;
    final bx = (x ?? o.dx) - o.dx, by = (y ?? o.dy) - o.dy;
    _F f(double rr, double sy, double op, [double? at]) => _F(
      x: bx + math.sin(th) * rr,
      y: by - math.cos(th) * rr,
      r: a + 90,
      sx: 1,
      sy: sy,
      o: op,
      at: at,
    );
    add(
      ReactionParticle(
        shape: ReactionShape.rect,
        width: w,
        height: h,
        color: c,
        colors: cols,
        vertical: true,
        radius: w,
        frames: [f(r0, 0.2, 0), f((r0 + r1) / 2, 1, 1, 0.4), f(r1, 0.3, 0)],
        duration: d,
        delay: dl,
        curve: const Cubic(0.2, 0.8, 0.3, 1),
      ),
    );
  }

  /// Слово-звукоподражание; не выходит за края экрана (как в макете).
  void word(String t, double sz, Color c, double x, double y, List<_F> f,
      double d, [double dl = 0, Curve cv = Curves.linear]) {
    final m = math.min(W / 2, t.length * sz * 0.34 + 12);
    final cx = x.clamp(m, math.max(m, W - m)).toDouble();
    add(
      ReactionParticle(
        shape: ReactionShape.word,
        glyph: t,
        size: sz,
        color: c,
        frames: _abs(cx, y, f),
        duration: d,
        delay: dl,
        curve: cv,
      ),
    );
  }

  /// Дождь косыми чёрточками (макет `rain`).
  void rainLines(int cnt, Color col, [double dl0 = 0, double spread = 1800]) {
    for (var i = 0; i < cnt; i++) {
      final x = r(-40, W + 120);
      rc(1.5, r(16, 28), col, x, -30, [
        const _F(r: 12, o: 0),
        _F(x: -8, y: 40, r: 12, o: 0.85, at: 0.06),
        _F(x: -H * 0.21, y: H + 60, r: 12, o: 0.85),
      ], r(700, 950), dl0 + r(0, spread));
    }
  }

  /// Отрезок (молния, трещина) от (x1, y1) до (x2, y2).
  void seg(double x1, double y1, double x2, double y2, double w, Color c,
      List<_F> kf, double d, double dl, {Color? glow, double blur = 0}) {
    final dx = x2 - x1, dy = y2 - y1;
    final len = math.sqrt(dx * dx + dy * dy);
    final ang = math.atan2(dy, dx) * 180 / math.pi - 90;
    add(
      ReactionParticle(
        shape: ReactionShape.rect,
        width: w,
        height: len + 2,
        color: c,
        radius: w,
        glowColor: glow,
        blur: blur,
        frames: _abs((x1 + x2) / 2, (y1 + y2) / 2, [
          for (final k in kf) _F(r: ang, o: k.o, at: k.at),
        ]),
        duration: d,
        delay: dl,
      ),
    );
  }

  /// Полёт по параболе: вверх на [up] к 35 % пути, затем вниз.
  static double Function(double) ballistic(double up) {
    final v = up / 0.175, gr = v / 0.7;
    return (t) => -v * t + gr * t * t;
  }

  double cos(double a) => math.cos(a);
  double sin(double a) => math.sin(a);

  // ═════════════════════════════════════════════════════════════════════
  //   Эффекты макета — по одному на эмодзи (порядок и числа как в макете)
  // ═════════════════════════════════════════════════════════════════════

  SoloEmojiEffect buildSolo(String e) {
    final pi = math.pi;
    final ox = o.dx, oy = o.dy;
    switch (e) {
      case '❤️':
        for (final b in const [0.0, 560.0, 1120.0]) {
          card(const [
            _F(),
            _F(s: 1.22, at: 0.18),
            _F(s: 1.02, at: 0.38),
            _F(s: 1.12, at: 0.52),
            _F(),
          ], 520, b);
          ring(_c(255, 80, 120, .7), 900, 8, 1100, b + 60);
          inset(_c(255, 60, 110, .55), 120, 30, op(const [0, 1, 0], const [0, .2, 1]), 560, b);
          for (var i = 0; i < 8; i++) {
            final a = r(0, 2 * pi), d = r(80, 140);
            glyph('❤️', r(12, 20), [
              const _F(s: 0.2, o: 0),
              _F(x: cos(a) * d * .6, y: sin(a) * d * .6, s: 1, at: .3),
              _F(x: cos(a) * d, y: sin(a) * d - 20, s: .6, o: 0),
            ], 900, b + r(0, 60), _outC);
          }
        }
        for (var i = 0; i < 34; i++) {
          final x = r(0, W), top = r(300, 750);
          g(const ['❤️', '💖', '💗', '💕'][i % 4], r(16, 36), x, H + 30,
              sway(0, 0, r(-30, 30), -top, 18, r(0, 6), 6, (x, y, t, j, s) =>
                  _F(x: x, y: y, s: j == 0 ? .4 : 1, o: j == 0 || j == s ? 0 : 1)),
              r(2000, 2800), 1500 + r(0, 900), const Cubic(.3, .5, .5, 1));
        }
      case '🔥':
        linear([
          _c(255, 90, 20, .55),
          _c(255, 140, 40, .18),
          _c(255, 140, 40, 0),
        ], op(const [0, 1, .75, .95, .7, 0], const [0, .15, .4, .55, .8, 1]), 2800,
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: const [0, .55, 1],
            area: Rect.fromLTRB(0, H * .35, W, H));
        shiver(1.5, 1200, 100);
        glw(_c(255, 128, 32, .6), 260, 1200);
        for (var i = 0; i < 16; i++) {
          final x = r(10, W - 10), up = r(120, 380);
          g('🔥', r(28, 56), x, H + 20, [
            const _F(s: .5, o: 0),
            _F(x: r(-10, 10), y: -up * .5, s: 1.15, at: .4),
            _F(x: r(-20, 20), y: -up, s: .6, o: 0),
          ], r(1400, 2000), r(0, 900), const Cubic(.2, .6, .4, 1));
        }
        const fc = [Color(0xFFFFE066), Color(0xFFFFB02E), Color(0xFFFF7A1F), Color(0xFFFF4D1F)];
        for (var i = 0; i < 60; i++) {
          final x = r(0, W), up = r(300, 800);
          dt(r(3, 7), fc[i % 4], x, H,
              sway(0, 0, r(-40, 40), -up, 20, r(0, 6), 5, (x, y, t, j, s) =>
                  _F(x: x, y: y, s: 1 - t * .6, o: j == 0 || j == s ? 0 : 1)),
              r(1500, 2600), r(0, 1200), const Cubic(.2, .6, .4, 1), true);
        }
      case '🎉':
        card(const [_F(), _F(sx: 1.2, sy: .84, at: .2), _F(sx: .92, sy: 1.1, at: .5), _F()], 500);
        glw(_c(255, 205, 60, .5), 240, 900);
        for (final side in const [-1.0, 1.0]) {
          final x0 = side < 0 ? 10.0 : W - 10, y0 = H - 40;
          for (var i = 0; i < 40; i++) {
            final a = (side < 0 ? r(-82, -52) : r(-128, -98)) * pi / 180;
            final d = r(450, 800), tall = i % 7 == 0;
            rc(tall ? 3 : r(5, 9), tall ? r(28, 44) : r(9, 14), _conf[i % 6], x0, y0, [
              const _F(s: .4, curve: Cubic(.1, .75, .3, 1)),
              _F(x: cos(a) * d, y: sin(a) * d, r: r(200, 500), at: .42,
                  curve: const Cubic(.4, 0, .9, .6)),
              _F(x: cos(a) * d + r(-70, 70), y: sin(a) * d + r(320, 520),
                  r: r(700, 1300), o: 0),
            ], r(2100, 2900), r(0, 220) + (side > 0 ? 120 : 0));
          }
        }
        for (var i = 0; i < 18; i++) {
          final a = r(0, 2 * pi), d = r(70, 130);
          rc(r(5, 8), r(8, 12), _conf[i % 6], ox, oy, [
            const _F(s: .3),
            _F(x: cos(a) * d, y: sin(a) * d, r: r(120, 300), at: .4),
            _F(x: cos(a) * d, y: sin(a) * d + 120, r: r(400, 700), o: 0),
          ], 1300, r(0, 80), const Cubic(.2, .7, .4, 1));
        }
      case '😂':
        card(const [
          _F(),
          _F(r: -12, y: -6, at: .1),
          _F(r: 11, at: .22),
          _F(r: -10, y: -6, at: .34),
          _F(r: 9, at: .46),
          _F(r: -8, y: -4, at: .58),
          _F(r: 6, at: .7),
          _F(r: -3, at: .85),
          _F(),
        ], 1500);
        for (var i = 0; i < 30; i++) {
          final sd = i.isOdd ? 1.0 : -1.0;
          final tx = sd * r(80, 360), pk = -r(80, 220), ld = r(120, 420);
          dr(r(9, 14), ox + sd * 20, oy - 10, [
            const _F(s: .4, o: 0, curve: Cubic(.2, .7, .4, 1)),
            _F(x: tx * .5, y: pk, s: 1, at: .42, curve: const Cubic(.5, 0, .9, .5)),
            _F(x: tx, y: ld, s: .9, o: 0),
          ], r(1000, 1400), r(0, 900));
        }
        for (var i = 0; i < 16; i++) {
          final x = r(0, W);
          g('😂', r(22, 34), x, -40, [
            const _F(s: .6, o: 0),
            _F(y: r(200, 300), r: r(-90, 90), at: .35),
            _F(y: r(550, 900), r: r(-200, 200), o: 0),
          ], r(1800, 2400), r(600, 1400), const Cubic(.4, 0, .8, .6));
        }
      case '😘':
        card(const [_F(), _F(r: -10, s: 1.06, at: .3), _F(r: 4, s: .96, at: .55), _F()], 700);
        glyph('💋', 64, const [_F(s: .4, o: 0), _F(s: 1, at: .2), _F(y: -40, s: 7, o: 0)],
            1100, 260, const Cubic(.5, 0, .9, .6));
        inset(_c(255, 110, 170, .4), 120, 30, op(const [0, 1, 0], const [0, .3, 1]), 1600, 250);
        for (var i = 0; i < 26; i++) {
          final a = r(-150, -30) * pi / 180, d = r(250, 600), ph = r(0, 6);
          glyph(const ['❤️', '💕', '💗'][i % 3], r(14, 30), [
            for (var j = 0; j <= 5; j++)
              () {
                final t = j / 5, w = sin(ph + t * 6) * 26;
                return _F(
                  x: cos(a) * d * t + w * sin(a),
                  y: sin(a) * d * t - w * cos(a),
                  s: j == 0 ? .3 : 1 - t * .3,
                  o: j == 0 || j == 5 ? 0 : 1,
                );
              }(),
          ], r(1600, 2200), 300 + r(0, 900), const Cubic(.2, .6, .4, 1));
        }
      case '👻':
        dark(_c(8, 10, 28, .78), 70, 170,
            op(const [0, 1, .6, 1, .75, 1, 1, 0], const [0, .1, .2, .23, .4, .43, .85, 1]), 3200);
        card(const [
          _F(),
          _F(y: -12, s: 1.06, o: .4, at: .3),
          _F(y: -4, o: .9, at: .55),
          _F(y: -10, o: .5, at: .75),
          _F(),
        ], 2200);
        for (var i = 0; i < 7; i++) {
          final ltr = i.isEven;
          final x0 = ltr ? -80.0 : W + 80, x1 = ltr ? W + 80 : -80.0;
          final y0 = r(140, fromBottom(700)), y1 = y0 + r(-160, 160);
          g('👻', r(36, 72), 0, 0, sway(x0, y0, x1, y1, 40, r(0, 6), 8, (x, y, t, j, s) =>
              _F(x: x, y: y, sx: ltr ? -1 : 1, sy: 1, o: j == 0 || j == s ? 0 : .8)),
              r(2000, 2800), r(150, 1300));
        }
      case '🤯':
        // Макет: дрожь и раздувание одновременно (там дрожь перекрывалась
        // раздуванием — здесь обе в одной дорожке, как задумано: «дрожит,
        // накапливая давление»).
        card([
          const _F(),
          for (var i = 1; i < 16; i++)
            _F(x: (i.isOdd ? 1 : -1) * 3.0, s: 1 + .15 * (i / 16 * 500) / 990,
                at: i / 16 * 500 / 1100),
          const _F(s: 1 + .15 * 500 / 990, at: 500 / 1100),
          const _F(s: 1.15, at: .9),
          const _F(s: 1.3, at: .95),
          const _F(),
        ], 1100, 0, Curves.linear);
        fl(_c(255, 255, 255, .85), 360, 520);
        shake(12, 700, 520);
        ring(_c(255, 255, 255, .9), 1100, 12, 800, 520);
        ring(_c(255, 150, 50, .8), 700, 6, 700, 600);
        glyph('💥', 140, const [_F(s: .3, o: 0), _F(s: 1.2, at: .25), _F(s: 1.7, o: 0)],
            700, 500, Curves.easeOut);
        const bc = [Color(0xFFFFD43B), Color(0xFFFF922B), Color(0xFFFF6B6B), Color(0xFFADB5BD)];
        for (var i = 0; i < 40; i++) {
          final a = r(0, 2 * pi), d = r(150, 500);
          dot(r(4, 9), bc[i % 4], [
            const _F(s: .4, o: 0),
            _F(x: cos(a) * d * .6, y: sin(a) * d * .6, at: .3),
            _F(x: cos(a) * d, y: sin(a) * d + 60, s: .5, o: 0),
          ], r(900, 1300), 520 + r(0, 60), _outC, i % 4 != 3);
        }
        for (var i = 0; i < 18; i++) {
          final a = r(0, 2 * pi), d = r(60, 160);
          dot(r(30, 60), _c(170, 175, 185, .5), [
            const _F(s: .3, o: .9),
            _F(x: cos(a) * d * .6, y: sin(a) * d * .6, s: 1.2, o: .6, at: .4),
            _F(x: cos(a) * d, y: sin(a) * d - 30, s: 1.8, o: 0),
          ], r(1200, 1600), 540 + r(0, 80), _outC);
        }
      case '⚡':
        dark(_c(4, 8, 22, .78), 80, 200, op(const [0, 1, 1, 0], const [0, .1, .85, 1]), 2600);
        for (final (bi, b) in const [(0, 200.0), (1, 900.0), (2, 1300.0)]) {
          final x0 = r(40, W - 40), y0 = -10.0, x1 = ox + r(-50, 50), y1 = oy - 74;
          final pts = [
            for (var i = 0; i <= 7; i++)
              Offset(x0 + (x1 - x0) * i / 7 + (i > 0 && i < 7 ? r(-34, 34) : 0),
                  y0 + (y1 - y0) * i / 7),
          ];
          for (var i = 0; i < 7; i++) {
            final a = pts[i], c = pts[i + 1];
            final len = (c - a).distance;
            final ang = math.atan2(c.dy - a.dy, c.dx - a.dx) * 180 / pi - 90;
            rcg(5, len + 3, const [Color(0xFFFFF8D6), Color(0xFFFFF8D6)],
                (a.dx + c.dx) / 2, (a.dy + c.dy) / 2, [
              _F(r: ang, o: 0),
              _F(r: ang, at: .05),
              _F(r: ang, o: .25, at: .2),
              _F(r: ang, at: .3),
              _F(r: ang, o: 0),
            ], 460, b, Curves.linear,
                radius: 3, glowColor: _c(255, 225, 110, .9), blur: 14);
          }
          fl(_c(255, 255, 240, .55), 220, b);
          shake(4, 260, b);
          // Эмодзи вспыхивает: brightness(1.7) и жёлтое свечение.
          tint(const SoloEmojiTint(brightness: 1.7),
              const [_F(), _F(v: 1, at: .2), _F()], 500, b, _waapiOut);
          halo(const Color(0xFFFFE066), const [_F(o: 0), _F(at: .2), _F(o: 0)],
              500, b, _waapiOut);
          if (bi == 0) {
            for (var i = 0; i < 8; i++) {
              final a = r(0, 2 * pi), d = r(80, 130);
              glyph('⚡', r(14, 22), [
                const _F(s: .2, o: 0),
                _F(x: cos(a) * d * .6, y: sin(a) * d * .6, s: 1, at: .3),
                _F(x: cos(a) * d, y: sin(a) * d, s: .5, o: 0),
              ], 900, b + 40, _outC);
            }
          }
        }
      case '🚀':
        card(const [
          _F(),
          _F(sx: 1.1, sy: .85, y: 6, at: .18),
          _F(y: -20, o: 0, at: .25),
          _F(s: .3, o: 0, at: .8),
          _F(s: 1.08, at: .92),
          _F(),
        ], 1800, 0, Curves.linear);
        final p1 = Offset(W + 90 - ox, -130 - oy);
        const c1 = Offset(60, -260);
        Offset bz(double t) {
          final u = 1 - t;
          return c1 * (2 * u * t) + p1 * (t * t);
        }
        glyph('🚀', kSoloEmojiSize * .97, [
          const _F(o: 0),
          for (var i = 0; i <= 16; i++)
            _F(x: bz(i / 16).dx, y: bz(i / 16).dy, s: 1 - i / 16 * .35,
                at: .02 + .98 * i / 16),
        ], 1150, 300, const Cubic(.55, 0, .85, .45));
        shake(5, 400, 300);
        for (var i = 0; i <= 20; i++) {
          final t = i / 20, p = bz(t), dl = 300 + 1150 * math.sqrt(t) * .92;
          dt(r(24, 46), _c(210, 215, 225, .6), ox + p.dx - 24, oy + p.dy + 30, [
            const _F(s: .3, o: .9),
            const _F(s: 1.3, o: .5, at: .4),
            _F(y: r(10, 30), s: 2, o: 0),
          ], 1200, dl, Curves.easeOut);
          dt(r(5, 9), i.isOdd ? const Color(0xFFFFB02E) : const Color(0xFFFF7A1F),
              ox + p.dx - 20, oy + p.dy + 24,
              const [_F(), _F(y: 12, s: .2, o: 0)], 400, dl, Curves.easeOut, true);
        }
        for (var i = 0; i < 14; i++) {
          final x = r(0, W), y = r(0, H * .7);
          rc(2, r(24, 70), _c(255, 255, 255, .7), x, y, const [
            _F(r: 35, o: 0),
            _F(x: -30, y: 40, r: 35, at: .3),
            _F(x: -90, y: 120, r: 35, o: 0),
          ], r(500, 800), r(500, 1300));
        }
      case '🥶':
        inset(_c(200, 235, 255, .65), 140, 50, op(const [0, 1, 1, 0], const [0, .2, .8, 1]),
            3000, 0, Curves.easeInOut);
        shiver(2.5, 1800);
        glw(_c(140, 210, 255, .55), 240, 1600);
        ring(const Color(0xFFBDE6FF), 300, 3, 800);
        for (var i = 0; i < 50; i++) {
          final x = r(-20, W + 20), dy = H + 60;
          // Как в макете: поворот у каждого кадра свой — снежинка кувыркается.
          g('❄️', r(10, 24), x, -30, sway(0, 0, r(-30, 30), dy, 22, r(0, 6), 6,
              (x, y, t, j, s) => _F(x: x, y: y, r: t * r(-180, 180),
                  o: j == 0 || j == s ? 0 : 1)),
              r(2200, 3200), r(0, 1400));
        }
        for (var i = 0; i < 6; i++) {
          final a = r(0, 2 * pi), d = r(60, 90), x = cos(a) * d, y = sin(a) * d;
          glyph('✨', r(12, 18), [
            _F(x: x, y: y, s: 0, o: 0),
            _F(x: x, y: y, s: 1, at: .4),
            _F(x: x, y: y, s: 0, o: 0),
          ], 800, r(100, 900), Curves.easeInOut);
        }
      case '👍':
        card(const [
          _F(),
          _F(s: .82, y: 8, r: -8, at: .3),
          _F(s: 1.35, r: 6, at: .5),
          _F(s: .95, at: .7),
          _F(),
        ], 700, 0, Curves.easeOut);
        fl(_c(80, 160, 255, .25), 300, 330);
        ring(_c(83, 183, 244, .85), 900, 10, 900, 340);
        ring(_c(255, 255, 255, .6), 600, 4, 700, 420);
        for (var i = 0; i < 24; i++) {
          rad(i / 24 * 360 - 90 + r(-5, 5), 4, r(40, 90), Colors.white, 60, 480, 700, 340,
              cols: const [Colors.white, Color(0xFF53B7F4)]);
        }
        burstG(['👍'], 14, 140, 320, 20, 34, 360, 160);
        twinkles(10, 500, 800);
      case '😭':
        card([
          for (var i = 0; i <= 12; i++)
            i.isOdd ? const _F(y: 4, sx: 1.03, sy: .97) : const _F(),
        ], 1800, 0, Curves.linear);
        for (var i = 0; i < 64; i++) {
          final sd = i.isOdd ? 1.0 : -1.0, ex = ox + sd * 24, ey = oy - 10;
          final vx = sd * r(90, 200), pk = -r(40, 110), ld = H - 90 - ey;
          dr(r(8, 13), ex, ey, [
            const _F(s: .4, o: 0, curve: Cubic(.2, .7, .4, 1)),
            _F(x: vx * .45, y: pk, s: 1, at: .38, curve: const Cubic(.5, 0, .9, .5)),
            _F(x: vx, y: ld, s: 1, at: .97),
            _F(x: vx, y: ld, s: .6, o: 0),
          ], r(900, 1200), i * 28.0);
          if (i % 3 == 0) {
            final sx = ex + vx, dl = i * 28.0 + 1000;
            for (var j = 0; j < 3; j++) {
              dt(r(3, 5), const Color(0xFF8FD0FF), sx, H - 90, [
                const _F(s: .5, o: 0),
                _F(x: r(-18, 18), y: -r(10, 26), s: 1, at: .4,
                    curve: const Cubic(.2, .7, .4, 1)),
                _F(x: r(-26, 26), y: 4, s: .6, o: 0),
              ], 500, dl);
            }
          }
        }
        linear([
          _c(60, 150, 255, .5),
          _c(60, 150, 255, .15),
          _c(60, 150, 255, 0),
        ], const [
          _F(o: 0, y: 170),
          _F(y: 170 * .25, at: .5),
          _F(at: .8),
          _F(o: 0, y: 170 * .4),
        ], 3200,
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: const [0, .6, 1],
            area: Rect.fromLTWH(0, H - 170, W, 170),
            dl: 300,
            cv: Curves.easeInOut);
      case '🙏':
        card(const [
          _F(),
          _F(y: 6, sx: .96, sy: 1.02, at: .3),
          _F(y: 6, sx: .96, sy: 1.02, at: .6),
          _F(),
        ], 1400);
        // Столб света сверху до эмодзи (размытие 8 px, как в макете).
        add(ReactionParticle(
          shape: ReactionShape.beam,
          width: 140,
          height: oy,
          colors: [_c(255, 225, 140, .6), _c(255, 225, 140, 0)],
          blur: 8,
          frames: _abs(ox, 0, op(const [0, 1, 1, 0], const [0, .25, .75, 1])),
          duration: 2600,
        ));
        glw(_c(255, 215, 120, .6), 320, 2400);
        for (var i = 0; i < 12; i++) {
          final a = i * 30.0;
          add(ReactionParticle(
            shape: ReactionShape.beam,
            width: 22,
            height: 270,
            colors: [
              _c(255, 230, 150, 0),
              _c(255, 230, 150, 0),
              _c(255, 230, 150, .55),
              _c(255, 230, 150, 0),
            ],
            stops: const [0, 70 / 270, 95 / 270, 1],
            frames: [
              _F(r: a, o: 0),
              _F(r: a + 12, at: .25),
              _F(r: a + 36, at: .75),
              _F(r: a + 48, o: 0),
            ],
            duration: 2600,
          ));
        }
        for (var i = 0; i < 24; i++) {
          final x = r(20, W - 20), y0 = r(300, H - 80);
          g('✨', r(10, 18), x, y0, const [
            _F(s: 0, o: 0),
            _F(y: -60, s: 1, at: .3),
            _F(y: -160, s: .6, o: 0),
          ], r(1400, 2000), r(200, 1600), Curves.easeOut);
        }
      case '🥰':
        card(const [
          _F(),
          _F(r: -8, s: 1.05, at: .25),
          _F(r: 8, s: 1.05, at: .5),
          _F(r: -4, at: .75),
          _F(),
        ], 1600);
        wash([_c(255, 120, 170, 0), _c(255, 120, 170, .3)],
            op(const [0, 1, 0], const [0, .3, 1]), 2600);
        for (var i = 0; i < 8; i++) {
          final ph = i / 8 * 2 * pi;
          glyph('❤️', 22, [
            for (var j = 0; j <= 12; j++)
              _F(
                x: cos(ph + j / 12 * pi * 3) * (95 - j / 12 * 20),
                y: sin(ph + j / 12 * pi * 3) * (95 - j / 12 * 20) * .75,
                s: j == 0 ? .2 : 1,
                o: j == 0 ? 0 : 1,
              ),
            _F(x: cos(ph + pi * 3) * 420, y: sin(ph + pi * 3) * 420, s: .6, o: 0),
          ], 2000, i * 40.0);
        }
        for (var i = 0; i < 26; i++) {
          final x = r(0, W);
          g(const ['💕', '💗', '💖', '❤️'][i % 4], r(14, 30), x, H + 20,
              sway(0, 0, r(-30, 30), -r(300, 700), 20, r(0, 6), 6, (x, y, t, j, s) =>
                  _F(x: x, y: y, s: j == 0 ? .4 : 1, o: j == 0 || j == s ? 0 : .9)),
              r(2200, 3000), r(500, 1500), const Cubic(.3, .5, .5, 1));
        }
      case '😍':
        card(const [_F(), _F(s: 1.15, at: .2), _F(at: .4), _F(s: 1.15, at: .6), _F()], 1000);
        for (final sd in const [-1.0, 1.0]) {
          g('❤️', 40, ox + sd * 24, oy - 12, [
            const _F(s: .3, o: 0),
            const _F(s: 1.4, at: .2, curve: _spring),
            const _F(s: 1.1, at: .35),
            const _F(s: 1.6, at: .5),
            const _F(s: 1.2, at: .65),
            _F(x: sd * 40, y: -60, s: 5, o: 0),
          ], 1600, 100);
        }
        inset(_c(255, 70, 120, .45), 140, 40,
            op(const [0, 1, .4, 1, 0], const [0, .2, .35, .5, 1]), 1700, 100);
        burstG(['❤️', '💘', '💖'], 18, 140, 300, 16, 30, 1300, 80);
        twinkles(12, 1200, 900);
      case '😊':
        card(const [
          _F(),
          _F(y: -18, sx: .96, sy: 1.04, at: .2),
          _F(sx: 1.08, sy: .92, at: .4),
          _F(y: -10, at: .6),
          _F(at: .8),
          _F(),
        ], 1100);
        for (final sd in const [-1.0, 1.0]) {
          blob(34, 20, ox + sd * 36, oy + 14, const [
            _F(s: .4, o: 0),
            _F(s: 1.1, at: .3),
            _F(at: .75),
            _F(o: 0),
          ], 2000, dl: 200, cv: Curves.easeOut,
              cols: [_c(255, 110, 140, .75), _c(255, 110, 140, 0)]);
        }
        wash([_c(255, 210, 120, .35), _c(255, 210, 120, 0)],
            op(const [0, 1, 0], const [0, .3, 1]), 2600, fy: .3, stops: const [0, .7]);
        twinkles(22, 100, 1800);
        for (var i = 0; i < 10; i++) {
          final x = r(30, W - 30);
          g(const ['🌼', '🌸'][i % 2], r(16, 24), x, H + 10,
              sway(0, 0, r(-20, 20), -r(200, 400), 14, r(0, 6), 5, (x, y, t, j, s) =>
                  _F(x: x, y: y, r: t * 90, o: j == 0 || j == s ? 0 : 1)),
              r(2000, 2600), r(300, 1300), Curves.easeOut);
        }
      case '🥺':
        dark(_c(10, 14, 30, .6), 90, 220, op(const [0, 1, 1, 0], const [0, .2, .85, 1]), 2800);
        card([
          for (var i = 0; i <= 20; i++)
            () {
              final t = i / 20;
              final gg = math.min(1.0, t * 3) * (t < .85 ? 1 : (1 - t) / .15);
              return _F(
                s: 1 + .22 * gg,
                x: i == 0 || i == 20 ? 0 : (i.isOdd ? 1.2 : -1.2),
              );
            }(),
        ], 2400, 0, Curves.linear);
        for (final sd in const [-1.0, 1.0]) {
          for (var j = 0; j < 3; j++) {
            g('✨', r(12, 16), ox + sd * 24 + r(-6, 6), oy - 16 + r(-6, 6), const [
              _F(s: 0, o: 0),
              _F(s: 1, at: .4),
              _F(s: 0, o: 0),
            ], 600, 400 + j * 500 + (sd > 0 ? 150 : 0), Curves.easeInOut);
          }
          dr(9, ox + sd * 26, oy - 4, const [
            _F(s: .2, o: 0),
            _F(s: 1, y: 6, at: .4),
            _F(y: 40, s: .9, at: .9),
            _F(y: 50, o: 0),
          ], 1300, 1100 + (sd > 0 ? 200 : 0), const Cubic(.6, 0, .9, .6));
        }
        for (var i = 0; i < 16; i++) {
          final x = r(20, W - 20);
          dt(r(8, 22), _c(255, 255, 255, .18), x, H - 80, [
            const _F(s: .4, o: 0),
            _F(y: -r(150, 300), s: 1, at: .6),
            _F(y: -r(300, 500), s: 1.2, o: 0),
          ], r(2000, 2600), r(0, 1200), Curves.easeOut);
        }
      case '😅':
        card(const [
          _F(),
          _F(r: -6, at: .15),
          _F(r: 6, at: .3),
          _F(r: -5, at: .45),
          _F(r: 4, at: .6),
          _F(at: .8),
          _F(),
        ], 1400);
        dr(20, ox + 44, oy - 46, const [
          _F(s: .2, o: 0),
          _F(s: 1, at: .2),
          _F(y: 20, at: .5),
          _F(y: 90, s: .9, at: .85, curve: Cubic(.6, 0, .9, .6)),
          _F(y: 110, o: 0),
        ], 1600, 200, Curves.easeIn);
        for (var i = 0; i < 10; i++) {
          final a = r(-pi * .9, -pi * .1), d = r(80, 160);
          g('💦', r(14, 22), ox, oy - 20, [
            const _F(s: .2, o: 0, curve: Cubic(.1, .7, .3, 1)),
            _F(x: cos(a) * d, y: sin(a) * d, s: 1, r: r(-20, 20), at: .4,
                curve: const Cubic(.45, 0, .9, .6)),
            _F(x: cos(a) * d * 1.3, y: sin(a) * d + r(160, 260), s: .8, o: 0),
          ], r(1100, 1400), r(300, 700));
        }
        g('💨', 40, ox + 70, oy + 10, const [
          _F(s: .3, o: 0),
          _F(x: 30, s: 1, at: .3),
          _F(x: 90, y: -10, s: 1.4, o: 0),
        ], 900, 1500, Curves.easeOut);
        for (var i = 0; i < 20; i++) {
          final x = r(0, W);
          dr(r(5, 8), x, -20, [
            const _F(o: 0),
            _F(y: r(200, 400), o: .8, at: .3),
            _F(y: r(700, 900), o: 0),
          ], r(1300, 1800), r(400, 1400), const Cubic(.4, 0, .9, .6));
        }
      case '🤔':
        card(const [
          _F(),
          _F(r: -10, at: .15),
          _F(r: -10, at: .7),
          _F(s: 1.15, at: .8),
          _F(),
        ], 2400);
        final dir = ox > W / 2 ? -1.0 : 1.0;
        final cx = (ox + dir * 120).clamp(90.0, math.max(90.0, W - 90)).toDouble();
        final cy = oy - 215;
        const bub = [(60.0, -70.0, 12.0), (82.0, -100.0, 18.0), (100.0, -140.0, 26.0)];
        for (var i = 0; i < bub.length; i++) {
          final (dx, dy, sz) = bub[i];
          dt(sz, _c(255, 255, 255, .92), ox + dir * dx * .8, oy + dy, const [
            _F(s: 0, o: 0),
            _F(s: 1.15, at: .15, curve: _spring),
            _F(at: .25),
            _F(at: .85),
            _F(s: .6, o: 0),
          ], 2200, i * 140.0);
        }
        blob(150, 96, cx, cy, const [
          _F(s: 0, o: 0),
          _F(s: 1.1, at: .12, curve: _spring),
          _F(at: .2),
          _F(at: .86),
          _F(s: .6, o: 0),
        ], 2200, dl: 420, color: _c(255, 255, 255, .95), oval: false, radius: 48,
            glowColor: _c(0, 0, 0, .25), blur: 24, shadowDy: 8);
        g('❓', 34, cx, cy, const [
          _F(s: 0, o: 0),
          _F(s: 1, at: .1),
          _F(r: -15, at: .3),
          _F(r: 15, at: .45),
          _F(s: 1, at: .55),
          _F(s: 0, o: 0, at: .6),
          _F(s: 0, o: 0),
        ], 2000, 560);
        g('💡', 46, cx, cy, const [
          _F(s: 0, o: 0),
          _F(s: 0, o: 0, at: .55),
          _F(s: 1.4, at: .65, curve: _spring),
          _F(s: 1, at: .75),
          _F(s: 1, at: .92),
          _F(s: .6, o: 0),
        ], 2000, 560);
        spot(220, _c(255, 230, 100, .6), cx, cy, const [
          _F(s: .3, o: 0),
          _F(s: 1.2, at: .3),
          _F(o: 0),
        ], 900, 1700, Curves.easeOut);
        for (var i = 0; i < 12; i++) {
          rad(i / 12 * 360, 3, 16, const Color(0xFFFFE066), 40, 85, 600, 1720, x: cx, y: cy);
        }
      case '👏':
        for (final b in const [0.0, 260.0, 520.0, 780.0]) {
          card(const [_F(), _F(s: 1.16, at: .3), _F()], 240, b, Curves.easeOut);
          for (var j = 0; j < 10; j++) {
            rad(j < 5 ? r(-160, -110) : r(-70, -20), 3, r(14, 22),
                j.isOdd ? const Color(0xFFFFE27A) : Colors.white, 50, 115, 380, b,
                x: ox, y: oy - 20);
          }
        }
        beam(0, -10, 900, 150, _c(255, 240, 200, .35), -45, -12, 3000, 200);
        beam(W, -10, 900, 150, _c(255, 240, 200, .35), 45, 12, 3000, 280);
        for (var i = 0; i < 14; i++) {
          final x = r(20, W - 20), up = r(30, 90);
          g('👏', r(24, 36), x, H - 50, [
            const _F(y: 60, s: .6, o: 0),
            _F(y: -up, s: 1, at: .2, curve: _spring),
            _F(y: -up, s: 1.15, at: .32),
            _F(y: -up, s: 1, at: .44),
            _F(y: -up, s: 1.15, at: .56),
            _F(y: -up, s: 1, at: .68),
            _F(y: -up, s: 1.15, at: .8),
            const _F(y: 60, s: .8, o: 0),
          ], 1600, 900 + r(0, 800));
        }
        confettiRain(30, _conf, 2200, 900);
      case '😎':
        g('🕶️', 90, ox, oy - 14, const [
          _F(y: -420),
          _F(y: 0, at: .55, curve: Cubic(.3, 1.4, .5, 1)),
          _F(y: 0, at: .8),
          _F(y: 0, o: 0),
        ], 1000, 0, const Cubic(.5, 0, .9, .5));
        card(const [_F(), _F(sx: 1.12, sy: .9, at: .3), _F(sx: .96, sy: 1.05, at: .6), _F()],
            460, 560, Curves.easeOut);
        linear([_c(120, 60, 255, .28), _c(255, 60, 180, .22)],
            op(const [0, 1, 1, 0], const [0, .25, .75, 1]), 2400,
            begin: Alignment.topLeft, end: Alignment.bottomRight, dl: 600);
        // Блик через весь экран: полоса 140×1400 под 25°.
        final a25 = 25 * pi / 180, sy0 = 400 * H / 844;
        rcg(140, 1400, [
          _c(255, 255, 255, 0),
          _c(255, 255, 255, .38),
          _c(255, 255, 255, 0),
        ], -130, sy0, [
          const _F(r: 25),
          _F(x: 820 * math.cos(a25), y: 820 * math.sin(a25), r: 25),
        ], 900, 750, Curves.easeInOut, radius: 0, vertical: false);
        popAt('✨', 22, ox - 22, oy - 16, 600, 900);
        popAt('✨', 18, ox + 24, oy - 18, 600, 1080);
        twinkles(10, 900, 1200);
      case '😡':
        card([
          for (var i = 0; i <= 14; i++)
            i == 0 || i == 14
                ? const _F()
                : _F(x: (i.isOdd ? 1 : -1) * 3.0, s: 1 + .1 * sin(i / 14 * pi)),
        ], 1600, 0, Curves.linear);
        tint(const SoloEmojiTint(sepia: .6, saturate: 3, hue: -25, brightness: 1.05), [
          for (var i = 0; i <= 14; i++) _F(v: i == 0 || i == 14 ? 0 : 1),
        ], 1600);
        wash([_c(255, 40, 30, 0), _c(255, 40, 30, .38)],
            op(const [0, 1, .6, 1, 0], const [0, .2, .4, .6, 1]), 2000);
        for (final b in const [0.0, 500.0, 1000.0]) {
          shake(8, 300, b);
          for (final sd in const [-1.0, 1.0]) {
            for (var i = 0; i < 6; i++) {
              dt(r(14, 26), _c(240, 244, 248, .8), ox + sd * 52, oy - 50, [
                const _F(s: .3, o: 0),
                _F(x: sd * r(30, 60), y: -r(50, 90), s: 1.3, o: .85, at: .4),
                _F(x: sd * r(60, 110), y: -r(110, 170), s: 2, o: 0),
              ], r(700, 950), b + r(0, 160), Curves.easeOut);
            }
          }
          popAt('💢', r(26, 34), ox + r(-80, 80), oy - r(40, 100), 700, b + 100);
        }
      case '💯':
        // Прозрачность задана только в первом кадре — в макете она растёт
        // до 1 на всём отрезке.
        card(const [
          _F(s: 2.4, r: -12, o: 0),
          _F(s: .9, o: .35, at: .35),
          _F(s: 1.06, o: .55, at: .55),
          _F(),
        ], 700, 0, const Cubic(.6, 0, .9, .4));
        fl(_c(255, 60, 60, .3), 300, 240);
        shake(10, 400, 240);
        ring(const Color(0xFFFF3B3B), 800, 10, 700, 250);
        for (var i = 0; i < 20; i++) {
          rad(i / 20 * 360 + r(-5, 5), 4, r(30, 60),
              i.isOdd ? const Color(0xFFFF3B3B) : Colors.white, 70, 260, 600, 250);
        }
        for (var i = 0; i < 18; i++) {
          final a = r(0, 2 * pi), d = r(60, 140);
          dot(r(6, 14), const Color(0xFFE03131), [
            const _F(s: .3, o: 0),
            _F(x: cos(a) * d, y: sin(a) * d, s: 1, at: .3),
            _F(x: cos(a) * d * 1.1, y: sin(a) * d * 1.1 + 10, s: .8, o: 0),
          ], 900, 250, _outC);
        }
        for (var i = 0; i < 10; i++) {
          final x = r(40, W - 40), y = r(130, H - 170), rr = r(-25, 25);
          g('💯', r(30, 48), x, y, [
            _F(s: 2.4, o: 0, r: rr),
            _F(s: .95, at: .18, r: rr),
            _F(at: .3, r: rr),
            _F(at: .8, r: rr),
            _F(o: 0, r: rr),
          ], 1600, 500 + i * 120.0, Curves.easeOut);
        }
      case '🤗':
        lay(const ReactionLayer(
          kind: ReactionLayerKind.sides,
          colors: [Color.fromRGBO(255, 170, 90, .6)],
          spread: 90,
          blur: 120,
        ), const [
          _F(o: 0, sx: 1.3, sy: 1),
          _F(at: .3),
          _F(sx: .94, sy: 1, at: .5),
          _F(at: .7),
          _F(o: 0),
        ], 2200, 0, Curves.easeInOut);
        card(const [
          _F(),
          _F(s: 1.06, at: .25),
          _F(sx: .82, sy: 1.06, at: .5),
          _F(sx: .86, sy: 1.04, at: .65),
          _F(),
        ], 2000);
        glw(_c(255, 190, 110, .55), 300, 1400, 900);
        burstG(['💛', '🧡', '❤️'], 14, 100, 220, 14, 24, 1100);
        twinkles(8, 900, 1000);
      case '💩':
        card(const [
          _F(),
          _F(sx: 1.2, sy: .8, at: .15),
          _F(sx: .88, sy: 1.14, y: -14, at: .32),
          _F(sx: 1.08, sy: .92, at: .5),
          _F(sx: .97, sy: 1.03, at: .68),
          _F(),
        ], 1100, 0, Curves.easeOut);
        wash([_c(120, 170, 40, 0), _c(120, 170, 40, .28)],
            op(const [0, 1, 0], const [0, .3, 1]), 2600, fy: .6);
        for (var i = 0; i < 10; i++) {
          final x0 = ox + r(-40, 40);
          rc(4, r(18, 28), _c(150, 210, 80, .85), x0, oy - 60, const [
            _F(s: .5, o: 0),
            _F(x: 8, y: -40, s: 1, at: .3),
            _F(x: -8, y: -80, o: .8, at: .6),
            _F(x: 8, y: -130, o: 0),
          ], 1400, r(0, 1400));
        }
        for (var f = 0; f < 5; f++) {
          final rr = r(60, 110), ph = r(0, 6.28);
          dot(5, const Color(0xFF111111), [
            for (var j = 0; j <= 24; j++)
              () {
                final a = ph + j / 24 * pi * 5 * (f.isOdd ? 1 : -1);
                return _F(
                  x: cos(a) * rr + r(-10, 10),
                  y: sin(a) * rr * .6 - 30 + r(-10, 10),
                  o: j == 0 || j == 24 ? 0 : 1,
                );
              }(),
          ], 2600, f * 80.0);
        }
        for (var i = 0; i < 6; i++) {
          final sd = i.isOdd ? 1.0 : -1.0, x1 = sd * r(70, 170), fl0 = r(90, 140);
          g('💩', r(20, 28), ox, oy + 40, [
            const _F(s: .3, o: 0, curve: Cubic(.1, .7, .3, 1)),
            _F(x: x1 * .35, y: -r(80, 140), s: 1, at: .3, curve: const Cubic(.5, 0, .9, .6)),
            _F(x: x1 * .7, y: fl0, at: .6, curve: const Cubic(.1, .7, .3, 1)),
            _F(x: x1 * .85, y: fl0 - 40, at: .75, curve: const Cubic(.5, 0, .9, .6)),
            _F(x: x1, y: fl0, at: .9),
            _F(x: x1, y: fl0, o: 0),
          ], 1600, 200 + i * 60.0);
        }
      case '🎂':
        dark(_c(8, 8, 20, .72), 90, 230,
            op(const [0, 1, 1, 0, 0], const [0, .12, .38, .48, 1]), 3400, 0, Curves.easeInOut);
        spot(90, _c(255, 190, 80, .75), ox, oy - 58, const [
          _F(s: .6, o: 0),
          _F(s: 1, at: .1),
          _F(s: .85, o: .8, at: .18),
          _F(s: 1.05, at: .26),
          _F(s: .9, o: .85, at: .32),
          _F(s: .3, o: 0, at: .38),
          _F(s: .3, o: 0),
        ], 3400);
        g('💨', 44, ox - 110, oy - 60, const [
          _F(s: .4, o: 0),
          _F(s: .4, o: 0, at: .28),
          _F(x: 60, s: 1.1, at: .36),
          _F(x: 110, s: 1.4, o: 0, at: .44),
          _F(x: 110, o: 0),
        ], 3400, 0, Curves.easeOut);
        fl(_c(255, 230, 180, .4), 300, 1500);
        card(const [_F(), _F(y: -16, s: 1.06, at: .4), _F(sx: 1.05, sy: .95, at: .75), _F()],
            500, 1500, Curves.easeOut);
        confettiRain(60, _conf, 2200, 1500);
        burstG(['🎁', '🎊'], 6, 120, 200, 22, 30, 1500, 60);
        for (var i = 0; i < 8; i++) {
          final x = r(20, W - 20);
          g('🎈', r(30, 46), x, H + 40,
              sway(0, 0, r(-30, 30), -H - 120, 18, r(0, 6), 6, (x, y, t, j, s) =>
                  _F(x: x, y: y, r: sin(t * 8) * 8, o: j == 0 ? 0 : 1)),
              r(2600, 3400), 1500 + r(0, 700), const Cubic(.3, .2, .6, 1));
        }
      case '🌹':
        card(const [_F(), _F(r: -8, s: 1.05, at: .3), _F(r: 4, at: .6), _F()], 1400);
        inset(_c(200, 20, 60, .42), 140, 40, op(const [0, 1, 1, 0], const [0, .25, .75, 1]),
            3200, 0, Curves.easeInOut);
        const pc = [
          Color(0xFFE03152),
          Color(0xFFC2255C),
          Color(0xFFFF6B81),
          Color(0xFFF03E3E),
          Color(0xFFFFA8B8),
        ];
        for (var i = 0; i < 14; i++) {
          final a = r(-pi * .95, -pi * .05), d = r(60, 140);
          petal(ox, oy - 20, [
            const _F(s: .3, o: 0, curve: Cubic(.1, .7, .3, 1)),
            _F(x: cos(a) * d, y: sin(a) * d, s: 1, r: r(90, 200), at: .35,
                curve: const Cubic(.45, 0, .9, .6)),
            _F(x: cos(a) * d * 1.3 + r(-30, 30), y: sin(a) * d + r(160, 260),
                r: r(300, 500), s: .9, o: 0),
          ], r(1400, 1800), r(0, 150), pc[i % 5]);
        }
        for (var i = 0; i < 42; i++) {
          final x = r(-20, W + 20), rr = r(200, 600);
          petal(x, -20, sway(0, 0, r(-60, 60), H + 40, 40, r(0, 6), 8, (x, y, t, j, s) {
            final fx = math.cos(t * 12);
            return _F(x: x, y: y, r: t * rr, sx: fx == 0 ? .05 : fx, sy: 1,
                o: j == s ? 0 : .95);
          }), r(2600, 3600), r(200, 1800), pc[i % 5]);
        }
        twinkles(8, 400, 1600);
      case '👋':
        // `transform-origin: 70% 90%` — машет от запястья.
        card([
          for (var i = 0; i <= 8; i++)
            i == 0 || i == 8 ? const _F() : _F(r: i.isOdd ? -18 : 14),
        ], 1400, 0, Curves.easeInOut, const Offset(.2, .4));
        for (final (i, b) in const [(0, 0.0), (1, 350.0), (2, 700.0), (3, 1050.0)]) {
          ring(_c(255, 255, 255, .45), 460, 3, 900, b);
          final sd = i.isOdd ? 1.0 : -1.0;
          rc(3, 20, _c(255, 255, 255, .9), ox + sd * 70, oy - 52, [
            _F(r: sd * 30, s: .3, o: 0),
            _F(r: sd * 30, s: 1, at: .3),
            _F(x: sd * 8, r: sd * 30, o: 0),
          ], 320, b, Curves.easeOut, 3);
        }
        for (var i = 0; i < 12; i++) {
          g('👋', r(22, 34), r(30, W - 30), r(130, H - 150), const [
            _F(s: 0, o: 0),
            _F(s: 1.1, r: -15, at: .2),
            _F(r: 15, at: .4),
            _F(r: -15, at: .6),
            _F(s: 1, r: 10, at: .8),
            _F(s: .6, o: 0),
          ], 1000, 300 + i * 110.0, Curves.easeInOut);
        }
      case '💀':
        // grayscale(1) brightness(.6) + чёрная вуаль 10 % = серость и
        // затемнение на 46 %.
        dim(_c(0, 0, 0, .46), 1,
            op(const [0, 1, .6, 1, 1, 0], const [0, .12, .18, .22, .85, 1]), 3200, 0,
            Curves.linear, false);
        card([
          for (var i = 0; i <= 20; i++)
            i == 0 || i == 20
                ? const _F()
                : _F(y: i.isOdd ? 3 : -2, r: i.isOdd ? 3 : -3),
        ], 1600, 0, Curves.linear);
        fl(_c(255, 255, 255, .3), 200);
        g('👻', 80, ox, oy - 10, const [
          _F(s: .6, o: 0),
          _F(y: -60, s: 1, o: .8, at: .25),
          _F(x: 30, y: -260, s: 1.1, o: .7, at: .6),
          _F(x: -20, y: -520, s: 1.2, o: 0),
        ], 2400, 500, Curves.easeInOut);
        for (var i = 0; i < 12; i++) {
          final x = r(20, W - 20);
          g('🦴', r(20, 32), x, -30, [
            _F(o: 0, r: r(-90, 90)),
            _F(y: r(300, 500), r: r(-200, 200), at: .6),
            _F(y: r(700, 900), r: r(-300, 300), o: 0),
          ], r(1600, 2200), r(300, 1400), const Cubic(.4, 0, .9, .6));
        }
      case '🥳':
        dim(_c(10, 6, 30, .6), 0, op(const [0, 1, 1, 0], const [0, .08, .88, 1]), 3600, 0,
            Curves.linear, false);
        final bcs = [
          _c(255, 80, 180, .5),
          _c(80, 200, 255, .5),
          _c(255, 220, 80, .5),
          _c(140, 255, 120, .45),
        ];
        final bs = [(60.0, -30.0, 20.0), (W - 60, 30.0, -20.0), (W / 2 - 60, -15.0, 25.0),
            (W / 2 + 60, 15.0, -25.0)];
        for (var i = 0; i < 4; i++) {
          final (x, a0, a1) = bs[i];
          beam(x, -10, 900, 120, bcs[i], a0, a1, 3200, 100 + i * 80.0);
        }
        g('🪩', 64, W / 2, -50, const [
          _F(o: 0),
          _F(y: 130, at: .15, curve: Cubic(.3, 1.4, .5, 1)),
          _F(y: 130, r: 180, at: .85),
          _F(y: 0, o: 0),
        ], 3400);
        for (final b in const [0.0, 450.0, 900.0, 1350.0, 1800.0, 2250.0]) {
          card(const [_F(), _F(y: -14, s: 1.06, at: .4), _F(sx: 1.05, sy: .95, at: .75), _F()],
              420, b, Curves.easeOut);
        }
        burstG(['🎉', '🎊'], 6, 120, 220, 24, 32, 200, 60);
        confettiRain(56, _conf, 2200, 400);
      case '🤣':
        card(const [
          _F(),
          _F(x: -50, r: -200, at: .3),
          _F(x: 40, r: 160, at: .62),
          _F(r: -15, at: .85),
          _F(),
        ], 1900, 0, Curves.easeInOut, Offset.zero);
        // Весь чат качается от смеха.
        scr(const [_F(), _F(r: -2.5, at: .25), _F(r: 2.5, at: .55), _F(r: -1, at: .8), _F()],
            1900, 0, Curves.easeInOut);
        for (var i = 0; i < 26; i++) {
          final sd = i.isOdd ? 1.0 : -1.0, tx = sd * r(90, 340), pk = -r(60, 200);
          drop(r(8, 13), [
            const _F(s: .4, o: 0, curve: Cubic(.2, .7, .4, 1)),
            _F(x: tx * .5, y: pk, s: 1, at: .42, curve: const Cubic(.5, 0, .9, .5)),
            _F(x: tx, y: r(150, 420), s: .9, o: 0),
          ], r(1000, 1300), r(0, 1500));
        }
        const ha = ['HA', 'HAHA', 'HA-HA', 'LOL'];
        for (var i = 0; i < 10; i++) {
          final x = r(50, W - 50), y = r(140, math.max(160.0, oy - 120)), rr = r(-25, 25);
          word(ha[i % 4], r(22, 40), i.isOdd ? const Color(0xFFFFD43B) : Colors.white, x, y, [
            _F(s: 0, o: 0, r: rr),
            _F(s: 1.25, r: rr, at: .2, curve: _spring),
            _F(s: 1, r: rr - 6, at: .4),
            _F(s: 1.05, r: rr + 6, at: .6),
            _F(s: .8, o: 0, r: rr, y: -20),
          ], 1100, 200 + i * 150.0);
        }
      case '😢':
        card(const [
          _F(),
          _F(y: 8, sx: 1.03, sy: .95, at: .25),
          _F(y: 8, sx: 1.03, sy: .95, at: .85),
          _F(),
        ], 2800);
        dim(_c(40, 70, 130, .3), .7, op(const [0, 1, 1, 0], const [0, .15, .85, 1]), 3000);
        g('☁️', 110, ox, oy - 150, const [
          _F(y: -60, s: .6, o: 0),
          _F(y: 0, s: 1, at: .15, curve: Curves.easeOut),
          _F(x: -6, at: .5),
          _F(x: 6, at: .8),
          _F(y: -20, s: .9, o: 0),
        ], 3000, 0, Curves.easeInOut);
        for (var i = 0; i < 34; i++) {
          final x = ox + r(-46, 46);
          dr(r(5, 8), x, oy - 120, [
            const _F(o: 0, s: .6),
            const _F(y: 10, s: 1, at: .1),
            _F(y: r(190, 230), o: .9, at: .92),
            _F(y: r(200, 240), o: 0),
          ], r(550, 700), 300 + r(0, 2200), const Cubic(.5, 0, .9, .6));
        }
        for (var i = 0; i < 8; i++) {
          ringF(_c(150, 205, 255, .75), 130, 2, ox + r(-30, 30), oy + 76, const [
            _F(sx: .15, sy: .05),
            _F(sx: 1, sy: .28, o: 0),
          ], 900, 500 + i * 280.0, Curves.easeOut);
        }
      case '😁':
        card(const [
          _F(),
          _F(sx: 1.16, sy: .84, at: .14),
          _F(y: -30, sx: .92, sy: 1.1, at: .34),
          _F(sx: 1.12, sy: .88, at: .54),
          _F(y: -12, at: .7),
          _F(sx: 1.04, sy: .96, at: .84),
          _F(),
        ], 1300, 0, Curves.easeOut);
        wash([_c(255, 214, 80, .32), _c(255, 214, 80, 0)],
            op(const [0, 1, .5, 1, 0], const [0, .2, .45, .6, 1]), 2400,
            fy: .6, stops: const [0, .7]);
        for (final b in const [0.0, 420.0, 840.0]) {
          ring(_c(255, 212, 59, .8), 520, 6, 900, b + 150);
        }
        for (var i = 0; i < 4; i++) {
          rad(i * 90.0 + 45, 3, 18, Colors.white, 4, 26, 500, 450, x: ox + 4, y: oy + 22);
        }
        popAt('✨', 30, ox + 4, oy + 22, 700, 420);
        for (var i = 0; i < 14; i++) {
          final x = r(30, W - 30), hh = r(260, 520), dx = r(-60, 60);
          g('😁', r(24, 38), x, H + 30, [
            const _F(s: .8, curve: Cubic(.2, .7, .4, 1)),
            _F(x: dx * .5, y: -hh, r: r(-30, 30), at: .45, curve: const Cubic(.6, 0, .8, .3)),
            _F(x: dx, y: 40, r: r(-60, 60)),
          ], r(1300, 1700), 300 + r(0, 1200));
        }
      case '😉':
        card(const [
          _F(),
          _F(r: -14, s: 1.06, at: .2),
          _F(r: -14, s: 1.06, at: .6),
          _F(r: 4, at: .8),
          _F(),
        ], 1400);
        g('⭐', 30, ox + 24, oy - 12, const [
          _F(s: 0, o: 0),
          _F(s: 1.3, r: 40, at: .15, curve: _spring),
          _F(s: 1, r: 60, at: .3),
          _F(x: 20, y: -30, s: 9, r: 200, o: 0),
        ], 1300, 280, const Cubic(.55, 0, .9, .5));
        fl(_c(255, 240, 255, .55), 380, 1150);
        inset(_c(200, 90, 255, .38), 130, 30, op(const [0, 1, 1, 0], const [0, .25, .7, 1]),
            2600, 200);
        for (var i = 0; i < 30; i++) {
          final x = r(0, W);
          g(i % 3 != 0 ? '✨' : '⭐', r(10, 20), x, -20,
              sway(0, 0, r(-30, 30), H * r(.5, .95), 18, r(0, 6), 5, (x, y, t, j, s) =>
                  _F(x: x, y: y, r: t * 180, o: j == 0 || j == s ? 0 : 1)),
              r(1800, 2400), 1200 + r(0, 900));
        }
      case '😋':
        const food = ['🍕', '🍔', '🍩', '🍰', '🍓', '🍟', '🍫', '🍦', '🍪', '🌮', '🧁', '🍣'];
        card([
          for (var i = 0; i <= 16; i++)
            i == 0 || i == 16
                ? const _F()
                : (i.isOdd ? const _F(sx: 1.1, sy: .9) : const _F(sx: .97, sy: 1.04)),
        ], 2200, 300, Curves.linear);
        wash([_c(255, 170, 90, .28), _c(255, 170, 90, 0)],
            op(const [0, 1, 1, 0], const [0, .2, .8, 1]), 2800, fy: .7, stops: const [0, .7]);
        for (var i = 0; i < 18; i++) {
          final a = r(0, 2 * pi), d = r(260, 420), sx = cos(a) * d, sy = sin(a) * d * 1.2;
          g(food[i % food.length], r(28, 40), ox, oy + 16, [
            _F(x: sx, y: sy, s: 1, o: 0, r: r(-60, 60)),
            _F(x: sx * .8, y: sy * .8, s: 1, at: .15),
            _F(x: sx * .15, y: sy * .15, s: .6, r: r(-200, 200), at: .85,
                curve: const Cubic(.6, 0, .9, .4)),
            const _F(s: 0, o: 0),
          ], r(700, 900), 200 + i * 110.0, const Cubic(.5, 0, .9, .5));
        }
        const crumbs = [Color(0xFFF4A261), Color(0xFFE9C46A), Colors.white];
        for (var i = 0; i < 14; i++) {
          final a = r(0, 2 * pi), d = r(30, 80);
          dt(r(3, 6), crumbs[i % 3], ox, oy + 20, [
            const _F(s: .5, o: 0),
            _F(x: cos(a) * d, y: sin(a) * d - 20, s: 1, at: .3),
            _F(x: cos(a) * d * 1.2, y: sin(a) * d + 60, s: .6, o: 0),
          ], 800, 500 + r(0, 1800), const Cubic(.2, .7, .4, 1));
        }
        g('💖', 40, ox + 60, oy - 50, const [
          _F(s: 0, o: 0),
          _F(s: 1.2, at: .3, curve: _spring),
          _F(s: 1, y: -20, at: .7),
          _F(y: -50, s: .8, o: 0),
        ], 1000, 2500);
      case '🤪':
        // Весь чат перекашивает (поворот и перекос, как в макете).
        scr(const [
          _F(),
          _F(r: 2, kx: 5, at: .12),
          _F(r: -2, kx: -5, s: 1.02, at: .26),
          _F(r: 1.5, ky: 3, at: .4),
          _F(r: -1.5, ky: -3, at: .55),
          _F(r: 1, kx: 2, at: .7),
          _F(),
        ], 2200, 0, Curves.easeInOut);
        linear([_c(255, 0, 140, .28), _c(0, 200, 255, .28), _c(255, 230, 0, .28)], const [
          _F(o: 0),
          _F(v: 120, at: .2),
          _F(v: 360, at: .8),
          _F(o: 0, v: 480),
        ], 2600, begin: Alignment.topLeft, end: Alignment.bottomRight, hue: true);
        card(const [
          _F(),
          _F(r: 25, sx: 1.15, sy: .9, at: .12),
          _F(r: -30, sx: .9, sy: 1.15, at: .26),
          _F(r: 360, s: 1.1, at: .5),
          _F(r: 340, s: .95, at: .65),
          _F(r: 380, at: .8),
          _F(r: 360),
        ], 2000, 0, Curves.easeInOut, Offset.zero);
        for (var i = 0; i < 16; i++) {
          final x0 = r(30, W - 30), y0 = r(160, H - 200), vx = r(-5, 5), hh = r(60, 110);
          dt(r(14, 22), _conf[i % 6], x0, y0, [
            for (var j = 0; j <= 10; j++)
              _F(
                x: j * vx * 8,
                y: -(sin(j / 10 * pi * 3)).abs() * hh * (1 - j / 14),
                s: j == 0 ? 0 : 1,
                o: j == 10 ? 0 : 1,
              ),
          ], 1600, r(0, 900), Curves.linear, true);
        }
        for (var i = 0; i < 8; i++) {
          g('🤪', r(22, 34), r(30, W - 30), r(140, H - 180), const [
            _F(s: 0, o: 0),
            _F(s: 1.2, r: 180, at: .3),
            _F(s: 1, r: 360, at: .7),
            _F(s: 0, o: 0, r: 540),
          ], 1200, 300 + i * 170.0, Curves.easeInOut);
        }
      case '🙄':
        card(const [
          _F(),
          _F(y: -8, r: -14, at: .25),
          _F(y: -10, at: .45),
          _F(y: -8, r: 14, at: .65),
          _F(),
        ], 1800);
        dim(_c(30, 34, 40, .28), .8, op(const [0, 1, 1, 0], const [0, .2, .85, 1]), 3000);
        final dir = ox > W / 2 ? -1.0 : 1.0;
        final bx = (ox + dir * 110).clamp(70.0, math.max(70.0, W - 70)).toDouble();
        final by = oy - 120;
        blob(96, 52, bx, by, const [
          _F(s: 0, o: 0),
          _F(s: 1.1, at: .1, curve: _spring),
          _F(at: .16),
          _F(at: .9),
          _F(s: .6, o: 0),
        ], 2600, dl: 500, color: _c(255, 255, 255, .95), oval: false, radius: 26,
            glowColor: _c(0, 0, 0, .3), blur: 18, shadowDy: 6);
        for (var i = 0; i < 3; i++) {
          dt(10, const Color(0xFF5C6B7A), bx - 22 + i * 22, by, const [
            _F(s: 0, o: 0),
            _F(at: .08),
            _F(y: -6, at: .16),
            _F(at: .24),
            _F(y: -6, at: .48),
            _F(at: .56),
            _F(y: -6, at: .8),
            _F(at: .88),
            _F(s: 0, o: 0),
          ], 2400, 600 + i * 120.0, Curves.easeInOut);
        }
        g('💨', 38, ox - dir * 60, oy + 30, [
          _F(s: .3, o: 0, sx: -dir * .3, sy: .3),
          _F(x: -dir * 30, sx: -dir, sy: 1, at: .3),
          _F(x: -dir * 80, y: -10, sx: -dir * 1.4, sy: 1.4, o: 0),
        ], 1000, 1500, Curves.easeOut);
        // Тяжёлый вздох — чат проседает.
        scr(const [_F(), _F(y: 6, at: .4), _F(y: 6, at: .6), _F()], 1300, 1400, Curves.easeInOut);
      case '😴':
        linear([_c(10, 16, 48, .82), _c(20, 30, 80, .6)],
            op(const [0, 1, 1, 0], const [0, .15, .88, 1]), 3800, cv: Curves.easeInOut);
        g('🌙', 64, W - 70, 150, const [
          _F(y: 60, o: 0, r: -20),
          _F(y: 0, at: .25, curve: Curves.easeOut),
          _F(y: -6, at: .85),
          _F(y: -10, o: 0),
        ], 3600, 100, Curves.easeOut);
        for (var i = 0; i < 26; i++) {
          dt(r(2, 4), Colors.white, r(14, W - 14), r(70, math.max(100.0, oy - 160)), const [
            _F(o: 0, s: .5),
            _F(at: .3),
            _F(o: .3, at: .55),
            _F(at: .75),
            _F(o: 0),
          ], r(2200, 3000), r(200, 900), Curves.easeInOut, true);
        }
        card(const [
          _F(),
          _F(sx: 1.07, sy: 1.04, at: .25),
          _F(at: .5),
          _F(sx: 1.07, sy: 1.04, at: .75),
          _F(),
        ], 3200);
        blob(40, 40, ox + 22, oy + 18, const [
          _F(s: 0, o: 0),
          _F(at: .3),
          _F(s: .4, at: .5),
          _F(s: 1.3, at: .8),
          _F(s: 1.6, o: 0),
        ], 2800, dl: 300, cv: Curves.easeInOut,
            cols: [_c(255, 255, 255, .6), _c(160, 210, 255, .15)],
            gradCenter: const Alignment(-.4, -.4), gradR: 1.98,
            border: 2, borderColor: _c(200, 230, 255, .85));
        const zz = ['Z', 'Z', 'z', 'z'];
        for (var i = 0; i < 4; i++) {
          word(zz[i], 40 - i * 3.0, const Color(0xFFCFE3FF), ox + 40, oy - 40, [
            const _F(s: .3, o: 0),
            _F(x: 30 + i * 4.0, y: -60, s: 1, r: -12, at: .35),
            _F(x: 60 + i * 8.0, y: -150, s: 1.2, r: 12, o: 0),
          ], 1700, 300 + i * 600.0, Curves.easeOut);
        }
      case '😱':
        card([
          const _F(),
          for (var i = 1; i < 14; i++) _F(sx: .86, sy: 1.28, x: i.isOdd ? 3 : -3),
          const _F(),
        ], 1500, 0, Curves.linear);
        scr(const [
          _F(),
          _F(s: 1.05, at: .12),
          _F(s: 1.02, at: .3),
          _F(s: 1.05, at: .45),
          _F(s: 1.02, at: .6),
          _F(),
        ], 1500, 0, Curves.easeOut);
        fl(_c(200, 230, 255, .6), 260);
        dark(_c(20, 40, 90, .55), 120, 380, op(const [0, 1, 1, 0], const [0, .1, .8, 1]), 2200);
        for (var w = 0; w < 3; w++) {
          for (var i = 0; i < 32; i++) {
            rad(i / 32 * 360 + r(-4, 4), 2, r(70, 140), _c(255, 255, 255, .85),
                r(560, 640), r(180, 220), 420, w * 360 + r(0, 60));
          }
        }
        for (final b in const [0.0, 250.0, 500.0, 750.0]) {
          ring(_c(170, 215, 255, .85), 600, 5, 700, b);
        }
      case '😳':
        // Камера наезжает на эмодзи: весь чат приближается к нему.
        scr(const [_F(), _F(s: 1.12, at: .15), _F(s: 1.12, at: .75), _F()], 2200, 0,
            const Cubic(.3, 0, .2, 1), o);
        card(const [_F(), _F(s: .9, at: .2), _F(s: .92, y: 4, at: .8), _F()], 2200, 100);
        tint(const SoloEmojiTint(sepia: .45, saturate: 2.6, hue: -28, brightness: 1.02),
            const [_F(), _F(v: 1, at: .2), _F(v: 1, at: .8), _F()], 2200, 100, Curves.easeInOut);
        wash([_c(255, 80, 120, .12), _c(255, 80, 120, .35)],
            op(const [0, 1, .7, 1, 0], const [0, .2, .5, .7, 1]), 2400);
        word('!!', 56, const Color(0xFFFF4D6D), ox + 70, oy - 80, const [
          _F(s: 0, o: 0, r: 12),
          _F(s: 1.3, r: 12, at: .12, curve: _spring),
          _F(r: 12, at: .2),
          _F(r: 16, at: .3),
          _F(r: 8, at: .4),
          _F(r: 12, at: .85),
          _F(s: .6, o: 0, r: 12),
        ], 2000, 150);
        for (var i = 0; i < 4; i++) {
          rc(4, r(18, 28), _c(255, 140, 160, .8), ox - 36 + i * 24, oy - 80, const [
            _F(o: 0),
            _F(x: 6, y: -20, at: .3),
            _F(x: -6, y: -45, o: .8, at: .65),
            _F(x: 6, y: -70, o: 0),
          ], 1100, 300 + i * 160.0, Curves.linear, 3);
        }
        dr(14, ox - 58, oy - 40, const [
          _F(s: 0, o: 0),
          _F(s: 1, at: .2),
          _F(y: 40, s: .9, at: .85, curve: Cubic(.6, 0, .9, .6)),
          _F(y: 52, o: 0),
        ], 1500, 500, Curves.easeIn);
      case '🤩':
        beam(ox, -10, oy + 60, 200, _c(255, 220, 120, .45), 0, 0, 3000);
        glw(_c(255, 210, 80, .55), 300, 2200);
        for (final sd in const [-1.0, 1.0]) {
          g('⭐', 36, ox + sd * 24, oy - 14, [
            const _F(s: 0, o: 0),
            _F(s: 1.4, r: sd * 30, at: .2, curve: _spring),
            _F(s: 1.1, r: sd * 60, at: .4),
            _F(x: sd * 30, y: -40, s: 5, r: sd * 200, o: 0),
          ], 1400, 100, const Cubic(.4, 0, .8, .6));
        }
        for (var i = 0; i < 22; i++) {
          final ph = i / 22 * 2 * pi;
          glyph(i % 3 != 0 ? '⭐' : '🌟', r(14, 24), [
            for (var j = 0; j <= 8; j++)
              () {
                final t = j / 8, a = ph + t * pi * 1.6, rr = 40 + t * 300;
                return _F(
                  x: cos(a) * rr,
                  y: sin(a) * rr,
                  s: j == 0 ? .2 : 1 - t * .4,
                  r: t * 360,
                  o: j == 0 || j == 8 ? 0 : 1,
                );
              }(),
          ], 1600, 500 + r(0, 200), const Cubic(.2, .6, .4, 1));
        }
        for (var i = 0; i < 9; i++) {
          final x = r(30, W - 30), y = r(100, H - 160);
          blob(150, 150, x, y, const [_F(s: .2, o: 0), _F(at: .12), _F(s: 1.1, o: 0)], 380,
              dl: 700 + i * 230.0, cv: Curves.easeOut,
              cols: [_c(255, 255, 255, .95), _c(255, 255, 255, .4), _c(255, 255, 255, 0)],
              stops: const [0, .18, .55], gradR: _sq2);
          g('📸', 22, x, y + 40, const [_F(s: 0, o: 0), _F(at: .2), _F(at: .7), _F(s: 0, o: 0)],
              500, 650 + i * 230.0, Curves.easeOut);
        }
      case '😇':
        beam(ox, -10, oy + 80, 240, _c(255, 250, 230, .55), 0, 0, 3200);
        wash([_c(255, 250, 220, .4), _c(255, 250, 220, 0)],
            op(const [0, 1, 1, 0], const [0, .2, .8, 1]), 3200, fy: 0, stops: const [0, .6]);
        // Нимб опускается на голову.
        blob(100, 100, ox, oy - 66, [
          _F(y: -oy, sx: 1, sy: .3, o: 0),
          const _F(y: -60, sx: 1, sy: .3, at: .3, curve: Cubic(.3, 1.3, .5, 1)),
          const _F(sx: 1, sy: .3, at: .45),
          const _F(y: -4, sx: 1.04, sy: .31, at: .7),
          const _F(sx: 1, sy: .3, at: .88),
          const _F(y: -10, sx: 1.1, sy: .33, o: 0),
        ], 2800, cv: Curves.easeOut, border: 7, borderColor: const Color(0xFFFFD43B),
            glowColor: const Color(0xFFFFD43B), blur: 18);
        card(const [_F(), _F(y: -14, at: .4), _F(y: -14, at: .8), _F()], 2800);
        for (var i = 0; i < 16; i++) {
          final x = r(10, W - 10), rr = r(-40, 40);
          g('🪶', r(18, 30), x, -30,
              sway(0, 0, r(-40, 40), H * r(.6, 1), 40, r(0, 6), 8, (x, y, t, j, s) =>
                  _F(x: x, y: y, r: rr + sin(t * 10) * 35, o: j == 0 || j == s ? 0 : .95)),
              r(3000, 3800), r(0, 1400));
        }
        twinkles(14, 300, 2000);
      case '🤡':
        beam(30, -10, 900, 130, _c(255, 80, 80, .42), -30, 15, 3000);
        beam(W - 30, -10, 900, 130, _c(255, 220, 60, .42), 30, -15, 3000, 80);
        beam(W / 2, -10, 900, 130, _c(80, 180, 255, .42), -20, 20, 3000, 160);
        for (final (i, b) in const [(0, 300.0), (1, 1100.0)]) {
          final rr = i == 1 ? -12.0 : 10.0;
          card(const [_F(), _F(sx: 1.35, sy: .65, at: .25), _F(sx: .9, sy: 1.15, at: .55), _F()],
              450, b, Curves.easeOut);
          word(i == 1 ? 'HONK HONK!' : 'HONK!', i == 1 ? 40 : 34,
              i == 1 ? const Color(0xFFFF4D4D) : const Color(0xFFFFD43B),
              ox + (i == 1 ? -30 : 40), oy - 110 - i * 20, [
            _F(s: 0, o: 0, r: rr),
            _F(s: 1.3, at: .2, r: rr, curve: _spring),
            _F(at: .35, r: rr),
            _F(at: .8, r: rr),
            _F(s: .7, o: 0, r: rr, y: -20),
          ], 1000, b + 80);
          ring(_c(255, 255, 255, .7), 260, 4, 500, b + 100);
        }
        const jc = [Color(0xFFFF4D4D), Color(0xFF4DABF7), Color(0xFFFFD43B)];
        for (var b = 0; b < 3; b++) {
          dot(18, jc[b], [
            for (var j = 0; j <= 24; j++)
              () {
                final a = -pi / 2 + (j / 24 * 2 + b / 3) * 2 * pi;
                return _F(x: cos(a) * 70, y: -130 + sin(a) * 40, o: j == 0 || j == 24 ? 0 : 1);
              }(),
          ], 2400, 100, Curves.linear, true);
        }
        for (var i = 0; i < 8; i++) {
          g('🎈', r(30, 44), r(20, W - 20), H + 40,
              sway(0, 0, r(-30, 30), -H - 100, 16, r(0, 6), 6, (x, y, t, j, s) =>
                  _F(x: x, y: y, r: sin(t * 8) * 8, o: j == 0 ? 0 : 1)),
              r(2600, 3400), 600 + r(0, 900), const Cubic(.3, .2, .6, 1));
        }
        confettiRain(30, _conf, 2200, 900);
      case '🤮':
        // Чат мутит и перекашивает.
        scr(const [
          _F(),
          _F(kx: 3, x: -6, at: .2),
          _F(kx: -3, x: 6, at: .45),
          _F(kx: 2, x: -4, at: .7),
          _F(),
        ], 2600, 0, Curves.easeInOut);
        wash([_c(90, 200, 60, .1), _c(90, 200, 60, .38)],
            op(const [0, 1, .7, 1, 0], const [0, .2, .5, .7, 1]), 2800);
        card(const [
          _F(),
          _F(r: -8, s: .95, at: .2),
          _F(r: 6, sx: 1.05, sy: .95, at: .35),
          _F(sx: 1.15, sy: .85, y: 6, at: .45),
          _F(s: 1.05, at: .7),
          _F(),
        ], 1800);
        final dir = ox > W / 2 ? -1.0 : 1.0;
        for (var i = 0; i < 40; i++) {
          final vx = dir * r(80, 240), pk = -r(10, 70);
          dr(r(7, 12), ox + dir * 10, oy + 26, [
            const _F(s: .4, o: 0, curve: Cubic(.2, .7, .4, 1)),
            _F(x: vx * .5, y: pk, s: 1, at: .35, curve: const Cubic(.5, 0, .9, .5)),
            _F(x: vx, y: r(200, 320), s: .9, o: 0),
          ], r(900, 1200), 800 + r(0, 600), Curves.linear,
              const [Color(0xFFD8F5A2), Color(0xFF66A80F)]);
        }
        for (var i = 0; i < 2; i++) {
          g('🌀', 30, ox + (i == 1 ? 40 : -40), oy - 70, const [
            _F(s: 0, o: 0),
            _F(s: 1, r: 360, at: .3),
            _F(s: 1, r: 1080, at: .85),
            _F(s: 0, o: 0, r: 1260),
          ], 2200, i * 150.0);
        }
      case '😏':
        dark(_c(40, 10, 70, .6), 80, 300, op(const [0, 1, 1, 0], const [0, .25, .8, 1]), 3000,
            0, Curves.easeInOut);
        card(const [
          _F(),
          _F(x: -14, r: -6, at: .3),
          _F(x: -14, r: -6, at: .45),
          _F(x: 10, r: 8, s: 1.04, at: .7),
          _F(),
        ], 2400, 0, const Cubic(.45, 0, .2, 1));
        popAt('✨', 26, ox + 34, oy + 16, 700, 1500);
        for (var i = 0; i < 10; i++) {
          blob(r(18, 30), r(60, 100), ox + r(-60, 60), oy + 40, [
            const _F(s: .5, o: 0),
            _F(x: r(-20, 20), y: -80, s: 1, o: .8, at: .4),
            _F(x: r(-40, 40), y: -200, s: 1.6, o: 0),
          ], r(1800, 2400), dl: r(0, 1200), cv: Curves.easeOut,
              cols: [_c(190, 140, 255, .4), _c(190, 140, 255, 0)]);
        }
        word('hmm…', 30, const Color(0xFFE5DBFF), ox + (ox > W / 2 ? -90 : 90), oy - 90, const [
          _F(s: 0, o: 0, r: -6),
          _F(s: 1.1, r: -6, at: .2, curve: _spring),
          _F(r: -6, at: .3),
          _F(r: -6, at: .85),
          _F(s: .8, o: 0, r: -6),
        ], 1600, 700);
      case '😔':
        dim(_c(50, 70, 100, .35), .85, op(const [0, 1, 1, 0], const [0, .2, .85, 1]), 3800, 0,
            Curves.easeInOut);
        card(const [
          _F(),
          _F(y: 12, r: -6, s: .96, at: .35),
          _F(y: 12, r: -6, s: .96, at: .85),
          _F(),
        ], 3400);
        for (var i = 0; i < 22; i++) {
          final l = r(120, 320);
          rcg(3, r(26, 50), [_c(210, 225, 255, 0), _c(210, 225, 255, .6)],
              r(10, W - 10), r(60, H - 300), [
            const _F(o: 0),
            const _F(at: .1),
            _F(y: l * .3, at: .4),
            _F(y: l * .35, at: .55),
            _F(y: l, o: .7, at: .95),
            _F(y: l, o: 0),
          ], r(2400, 3200), r(0, 1200), Curves.easeIn, radius: 1.5);
        }
        g('🍂', 30, -30, oy - 260, [
          const _F(o: 0),
          _F(x: W * .3, y: 60, r: 120, at: .3),
          _F(x: W * .6, y: 120, r: 60, at: .6),
          _F(x: W + 60, y: 200, r: 220, o: 0),
        ], 3400, 200, Curves.easeInOut);
      case '😬':
        fl(_c(255, 255, 255, .45), 200, 150);
        shake(6, 300, 150);
        shiver(2, 1800, 150);
        // Трещины по «стеклу» экрана от эмодзи.
        const kf = [_F(o: 0), _F(at: .03), _F(at: .8), _F(o: 0)];
        for (var b = 0; b < 7; b++) {
          var a = b / 7 * 2 * pi + r(-.3, .3), rr = 70.0;
          var x = ox + cos(a) * rr, y = oy + sin(a) * rr;
          final nn = r(4, 6).floor();
          for (var s = 0; s < nn; s++) {
            final nr = rr + r(35, 70);
            a += r(-.35, .35);
            final nx = ox + cos(a) * nr, ny = oy + sin(a) * nr;
            seg(x, y, nx, ny, 2, _c(255, 255, 255, .9), kf, 2200, 150 + s * 25.0,
                glow: _c(180, 220, 255, .9), blur: 3);
            if (rnd.nextDouble() < .4) {
              final ba = a + r(.5, 1) * (rnd.nextDouble() < .5 ? -1 : 1), bl = r(20, 40);
              seg(nx, ny, nx + cos(ba) * bl, ny + sin(ba) * bl, 1.5, _c(255, 255, 255, .8),
                  kf, 2200, 170 + s * 25.0);
            }
            x = nx;
            y = ny;
            rr = nr;
          }
        }
        lay(ReactionLayer(
          kind: ReactionLayerKind.radial,
          center: o,
          colors: [_c(255, 255, 255, .12), _c(255, 255, 255, 0)],
          stops: const [0, .6],
        ), op(const [0, 1, 1, 0], const [0, .1, .8, 1]), 2400, 150);
        dr(13, ox + 50, oy - 44, const [
          _F(s: 0, o: 0),
          _F(s: 1, at: .2),
          _F(y: 34, at: .8, curve: Cubic(.6, 0, .9, .6)),
          _F(y: 44, o: 0),
        ], 1400, 600, Curves.easeIn);
        word('oops…', 30, Colors.white, ox - 70, oy - 100, const [
          _F(s: 0, o: 0, r: -8),
          _F(s: 1.1, r: -8, at: .2, curve: _spring),
          _F(r: -8, at: .3),
          _F(r: -8, at: .85),
          _F(s: .8, o: 0, r: -8),
        ], 1800, 500);
      case '🫠':
        g('☀️', 90, W / 2, 90, const [
          _F(y: -100, o: 0, s: .6),
          _F(y: 0, s: 1, at: .2, curve: Curves.easeOut),
          _F(r: 30, at: .8),
          _F(y: -40, o: 0, r: 40),
        ], 3400);
        linear([_c(255, 150, 40, .45), _c(255, 120, 30, .12), _c(255, 120, 30, 0)],
            op(const [0, 1, .8, 1, 0], const [0, .2, .5, .7, 1]), 3400,
            stops: const [0, .6, 1]);
        card(const [
          _F(),
          _F(sx: 1.04, sy: .96, at: .15),
          _F(sx: 1.12, sy: .78, y: 10, at: .4),
          _F(sx: 1.3, sy: .5, y: 26, at: .68),
          _F(sx: 1.3, sy: .5, y: 26, at: .78),
          _F(sx: .92, sy: 1.12, at: .9),
          _F(),
        ], 3000);
        blob(170, 40, ox, oy + 74, const [
          _F(sx: .3, sy: .3, o: 0),
          _F(sx: .6, sy: .6, o: .8, at: .3),
          _F(sx: 1.2, sy: 1, at: .7),
          _F(sx: 1.2, sy: 1, at: .8),
          _F(sx: .5, o: 0),
        ], 3000, cv: Curves.easeInOut,
            cols: [_c(255, 205, 60, .85), _c(255, 170, 30, .4), _c(255, 170, 30, 0)],
            stops: const [0, .7, 1]);
        for (var i = 0; i < 14; i++) {
          dr(r(7, 11), ox + r(-50, 50), oy + 60, [
            const _F(s: .2, o: 0),
            const _F(s: 1, y: 6, at: .25),
            _F(y: r(120, 220), s: .9, at: .9, curve: const Cubic(.6, 0, .9, .6)),
            _F(y: r(140, 240), o: 0),
          ], r(1100, 1500), 600 + r(0, 1500), Curves.easeIn,
              const [Color(0xFFFFE066), Color(0xFFF59F00)]);
        }
        for (var i = 0; i < 8; i++) {
          rc(4, r(30, 50), _c(255, 200, 120, .45), r(20, W - 20), r(150, math.max(150.0, oy)), const [
            _F(o: 0),
            _F(x: 8, y: -30, at: .3),
            _F(x: -8, y: -60, o: .6, at: .65),
            _F(x: 8, y: -100, o: 0),
          ], 1600, r(0, 1800), Curves.linear, 4);
        }
      case '😈':
        lay(ReactionLayer(
          kind: ReactionLayerKind.radial,
          center: o,
          r1: 320,
          colors: [_c(120, 0, 30, .15), _c(40, 0, 20, .75)],
          stops: const [60 / 320, 1],
        ), op(const [0, 1, 1, 0], const [0, .12, .88, 1]), 3400, 0, Curves.easeInOut);
        for (final b in const [300.0, 900.0]) {
          fl(_c(255, 30, 60, .4), 240, b);
          shake(6, 280, b);
        }
        card(const [
          _F(),
          _F(s: 1.25, at: .2),
          _F(s: 1.2, r: -4, at: .3),
          _F(s: 1.22, r: 4, at: .4),
          _F(s: 1.2, r: -4, at: .5),
          _F(s: 1.22, r: 4, at: .6),
          _F(s: 1.2, at: .8),
          _F(),
        ], 2600);
        // drop-shadow 16px красным — свечение вокруг эмодзи.
        halo(_c(255, 40, 80, .9), op(const [0, 1, 1, 0], const [0, .2, .8, 1]), 2600, 0,
            Curves.easeInOut);
        for (var i = 0; i < 10; i++) {
          final ltr = i.isEven;
          final x0 = ltr ? -60.0 : W + 60, x1 = ltr ? W + 60 : -60.0;
          final y0 = r(100, H - 200), y1 = y0 + r(-200, 120);
          g('🦇', r(24, 40), 0, 0, sway(x0, y0, x1, y1, 30, r(0, 6), 12, (x, y, t, j, s) =>
              _F(x: x, y: y, sx: ltr ? -1 : 1, sy: j.isOdd ? .6 : 1, o: j == 0 || j == s ? 0 : 1)),
              r(1500, 2200), r(200, 1800));
        }
        const mw = ['HA', 'HA-HA', 'MWAHAHA'];
        for (var i = 0; i < 3; i++) {
          word(mw[i], 28 + i * 6.0, const Color(0xFFFF4D6D), ox + r(-60, 60), oy - 110 - i * 50,
              const [
            _F(s: 0, o: 0),
            _F(s: 1.2, at: .2, curve: _spring),
            _F(at: .35),
            _F(at: .8),
            _F(s: .8, o: 0, y: -14),
          ], 1200, 400 + i * 400.0);
        }
        for (var i = 0; i < 30; i++) {
          dt(r(3, 6), i.isOdd ? const Color(0xFFFF4D4D) : const Color(0xFFC2255C), r(0, W), H, [
            const _F(o: 0),
            _F(y: -r(200, 500), x: r(-30, 30), at: .6),
            _F(y: -r(500, 700), o: 0),
          ], r(2000, 2800), r(0, 1200), Curves.easeOut, true);
        }
      case '🤑':
        wash([_c(255, 210, 60, .12), _c(80, 170, 60, .35)],
            op(const [0, 1, 1, 0], const [0, .2, .8, 1]), 3000);
        for (final b in const [200.0, 700.0, 1200.0]) {
          card(const [_F(), _F(y: -18, s: 1.08, at: .4), _F(sx: 1.06, sy: .94, at: .75), _F()],
              460, b, Curves.easeOut);
          popAt('✨', 24, ox + r(-30, 30), oy - r(10, 30), 500, b + 150);
        }
        fl(_c(255, 220, 80, .35), 300, 200);
        for (var i = 0; i < 36; i++) {
          final vx = r(-170, 170), yy = ballistic(r(180, 380));
          blob(16, 16, ox, oy - 20, [
            for (var j = 0; j <= 8; j++)
              _F(
                x: vx * j / 8,
                y: yy(j / 8),
                sx: (math.cos(j / 8 * 12)).abs() + .05,
                sy: 1,
                o: j == 8 ? 0 : 1,
              ),
          ], r(1300, 1700), dl: r(0, 1300),
              cols: const [Color(0xFFFFF3BF), Color(0xFFFAB005), Color(0xFFE67700)],
              stops: const [0, .55, 1], gradCenter: const Alignment(-.3, -.3), gradR: 1.84,
              glowColor: _c(255, 200, 0, .6), blur: 6);
        }
        for (var i = 0; i < 14; i++) {
          g(const ['💵', '💰', '💸'][i % 3], r(24, 36), r(10, W - 10), -30,
              sway(0, 0, r(-40, 40), H + 60, 30, r(0, 6), 6, (x, y, t, j, s) =>
                  _F(x: x, y: y, r: sin(t * 7) * 30, o: j == s ? 0 : 1)),
              r(2400, 3200), r(300, 1500));
        }
      case '💔':
        // Эмодзи пропадает: вместо него бьётся сердце и раскалывается.
        card(const [
          _F(o: 0),
          _F(o: 0, at: .82),
          _F(s: .5, at: .83),
          _F(s: 1.1, at: .92),
          _F(),
        ], 2800, 0, Curves.linear);
        glyph('❤️', kSoloEmojiSize, const [
          _F(),
          _F(s: 1.16, at: .18),
          _F(at: .36),
          _F(s: 1.16, at: .54),
          _F(at: .75),
          _F(at: .99),
          _F(o: 0),
        ], 800, 0, Curves.easeInOut);
        for (final sd in const [-1.0, 1.0]) {
          add(ReactionParticle(
            shape: ReactionShape.glyph,
            glyph: '❤️',
            size: kSoloEmojiSize,
            clip: sd < 0
                ? const [
                    Offset(0, 0), Offset(.52, 0), Offset(.44, .3), Offset(.58, .5), //
                    Offset(.42, .72), Offset(.5, 1), Offset(0, 1),
                  ]
                : const [
                    Offset(.52, 0), Offset(1, 0), Offset(1, 1), Offset(.5, 1), //
                    Offset(.42, .72), Offset(.58, .5), Offset(.44, .3),
                  ],
            frames: [
              const _F(o: 0),
              const _F(at: .01),
              _F(x: sd * 8, r: sd * 6, at: .12),
              _F(x: sd * 50, y: 80, r: sd * 28, at: .55, curve: const Cubic(.5, 0, .9, .6)),
              _F(x: sd * 80, y: 360, r: sd * 55, o: 0),
            ],
            duration: 1500,
            delay: 800,
            curve: Curves.easeIn,
          ));
        }
        fl(_c(255, 255, 255, .35), 200, 800);
        shake(5, 300, 800);
        dim(_c(30, 36, 48, .35), 1, op(const [0, 1, 1, 0], const [0, .3, .9, 1]), 3000, 800,
            Curves.easeInOut);
        rainLines(70, _c(190, 205, 230, .55), 1000, 2200);
        for (var i = 0; i < 10; i++) {
          final a = r(-pi * .9, -pi * .1), d = r(40, 90);
          rc(r(4, 7), r(5, 9), i.isOdd ? const Color(0xFFE03152) : const Color(0xFFFF6B81),
              ox, oy, [
            const _F(s: .5, o: 0),
            const _F(at: .02),
            _F(x: cos(a) * d, y: sin(a) * d, r: r(90, 200), at: .3),
            _F(x: cos(a) * d * 1.3, y: sin(a) * d + 200, r: r(300, 600), o: 0),
          ], 1300, 800, const Cubic(.3, .6, .6, 1));
        }
      case '❤️‍🔥':
        for (final b in const [0.0, 600.0, 1200.0]) {
          card(const [
            _F(),
            _F(s: 1.22, at: .18),
            _F(s: 1.02, at: .38),
            _F(s: 1.12, at: .52),
            _F(),
          ], 520, b);
          inset(_c(255, 70, 30, .55), 140, 40, op(const [0, 1, 0], const [0, .2, 1]), 600, b);
          ring(_c(255, 120, 40, .75), 520, 6, 800, b + 60);
        }
        glw(_c(255, 90, 40, .6), 300, 2000);
        for (var i = 0; i < 22; i++) {
          final a = r(-pi, 0), r0 = r(58, 78);
          g('🔥', r(20, 34), ox + cos(a) * r0, oy + sin(a) * r0 * .7 + 20, [
            const _F(s: .3, o: 0),
            _F(y: -r(30, 60), x: r(-10, 10), s: 1, at: .35),
            _F(y: -r(110, 170), x: r(-20, 20), s: .4, o: 0),
          ], r(900, 1300), r(0, 1800), const Cubic(.2, .6, .4, 1));
        }
        const hc = [Color(0xFFFFE066), Color(0xFFFFB02E), Color(0xFFFF7A1F), Color(0xFFFF4D6D)];
        for (var i = 0; i < 40; i++) {
          dt(r(3, 6), hc[i % 4], r(0, W), H,
              sway(0, 0, r(-30, 30), -r(300, 700), 16, r(0, 6), 5, (x, y, t, j, s) =>
                  _F(x: x, y: y, s: 1 - t * .6, o: j == 0 || j == s ? 0 : 1)),
              r(1600, 2400), r(0, 1600), Curves.easeOut, true);
        }
        for (var i = 0; i < 10; i++) {
          g(const ['❤️', '💖'][i % 2], r(14, 22), ox + r(-40, 40), oy, [
            const _F(s: .3, o: 0),
            _F(y: -r(100, 200), x: r(-60, 60), s: 1, at: .5),
            _F(y: -r(260, 360), x: r(-80, 80), s: .5, o: 0),
          ], r(1500, 2000), r(200, 1800), Curves.easeOut);
        }
      case '💪':
        for (final (i, b) in const [(0, 0.0), (1, 500.0), (2, 1000.0)]) {
          card([
            const _F(),
            const _F(s: .9, r: -10, at: .3),
            _F(s: 1.2 + i * .08, r: 6, at: .55),
            const _F(),
          ], 460, b, Curves.easeOut);
          for (var j = 0; j < 16; j++) {
            rad(j / 16 * 360 + r(-6, 6), 4, r(24, 40),
                j.isOdd ? const Color(0xFFFFD43B) : Colors.white, 70, 200 + i * 60.0, 500, b + 230);
          }
          ring(_c(255, 212, 59, .85), 420 + i * 120.0, 6, 600, b + 230);
          shake(4 + i * 3.0, 260, b + 230);
          popAt('💥', 40, ox + 52, oy - 40, 500, b + 230, r(-20, 20));
        }
        for (var i = 0; i < 24; i++) {
          rcg(3, r(30, 60), [_c(255, 230, 120, .9), _c(255, 212, 59, 0)], ox + r(-80, 80), oy + 60,
              const [_F(o: 0), _F(y: -60, at: .3), _F(y: -220, o: 0)],
              r(800, 1100), r(0, 1800), Curves.easeOut, radius: 3);
        }
        glw(_c(255, 200, 60, .5), 320, 2200);
        fl(_c(255, 240, 180, .4), 300, 1230);
      case '🙌':
        card(const [
          _F(),
          _F(y: 10, sx: 1.06, sy: .94, at: .15),
          _F(y: -30, sx: .96, sy: 1.06, at: .4),
          _F(y: -20, at: .7),
          _F(),
        ], 1400, 0, Curves.easeOut);
        beam(40, H + 10, 1000, 160, _c(255, 230, 150, .4), 200, 165, 3000);
        beam(W - 40, H + 10, 1000, 160, _c(255, 230, 150, .4), 160, 195, 3000, 100);
        for (var i = 0; i < 50; i++) {
          final vx = r(-150, 150), up = r(350, 650);
          rc(r(5, 9), r(9, 14), _conf[i % 6], ox, oy - 40, [
            const _F(s: .3, curve: Cubic(.1, .75, .3, 1)),
            _F(x: vx, y: -up, r: r(200, 500), at: .4, curve: const Cubic(.4, 0, .9, .6)),
            _F(x: vx * 1.4 + r(-40, 40), y: -up + r(300, 500), r: r(700, 1200), o: 0),
          ], r(2000, 2600), 300 + r(0, 500));
        }
        glw(_c(255, 230, 130, .55), 300, 2000, 200);
        for (var i = 0; i < 8; i++) {
          g(const ['🎶', '🎵'][i % 2], r(20, 30), ox + r(-90, 90), oy - 40, [
            const _F(s: .3, o: 0),
            _F(y: -r(100, 180), x: r(-40, 40), s: 1, r: r(-20, 20), at: .5),
            _F(y: -r(250, 350), x: r(-60, 60), s: .8, o: 0),
          ], r(1600, 2200), r(300, 1500), Curves.easeOut);
        }
      case '🫶':
        glw(_c(255, 110, 160, .5), 320, 2800);
        final hdx = ox.clamp(130.0, math.max(130.0, W - 130)).toDouble() - ox;
        const nh = 30;
        for (var i = 0; i < nh; i++) {
          final t = i / nh * 2 * pi;
          final st = sin(t);
          final hx = 16 * st * st * st * 7.5 + hdx;
          final hy = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)) * 7.5 - 10;
          final a0 = i * 40 / 2800;
          glyph('❤️', 16, [
            _F(x: hx, y: hy, s: 0, o: 0),
            _F(x: hx, y: hy, s: 0, o: 0, at: a0),
            _F(x: hx, y: hy, s: 1.3, at: a0 + .04),
            _F(x: hx, y: hy, s: 1, at: a0 + .08),
            _F(x: hx, y: hy, s: 1, at: .6),
            _F(x: hx * 1.1, y: hy * 1.1, s: 1.4, at: .66),
            _F(x: hx, y: hy, s: 1, at: .72),
            _F(x: hx * 1.1, y: hy * 1.1, s: 1.4, at: .78),
            _F(x: hx * 2.6, y: hy * 2.6, s: .5, o: 0),
          ], 2800);
        }
        inset(_c(255, 90, 150, .45), 130, 30,
            op(const [0, 0, 1, .4, 1, 0], const [0, .6, .68, .73, .79, 1]), 2800);
        card(const [
          _F(),
          _F(at: .6),
          _F(s: 1.12, at: .66),
          _F(at: .72),
          _F(s: 1.12, at: .78),
          _F(),
        ], 2800, 0, Curves.linear);
        for (var i = 0; i < 20; i++) {
          g(const ['💕', '💗', '💖'][i % 3], r(14, 28), r(0, W), H + 20,
              sway(0, 0, r(-30, 30), -r(300, 650), 18, r(0, 6), 6, (x, y, t, j, s) =>
                  _F(x: x, y: y, s: j == 0 ? .4 : 1, o: j == 0 || j == s ? 0 : .9)),
              r(2000, 2600), 2100 + r(0, 700), const Cubic(.3, .5, .5, 1));
        }
      case '👀':
        // Темнота, луч фонарика ищет по экрану и находит эмодзи.
        final pp = [
          Offset(-ox + 80, -oy + 180),
          Offset(W - ox - 90, -oy + 300),
          Offset(-ox + 120, H - oy - 260),
          Offset(W - ox - 120, -oy + 160),
        ];
        const dk = Color.fromRGBO(4, 6, 16, .82);
        lay(ReactionLayer(
          kind: ReactionLayerKind.radial,
          center: o,
          r1: 95,
          colors: [
            _clr(dk),
            _clr(dk),
            dk.withValues(alpha: .82 * .5),
            dk.withValues(alpha: .82 * .84),
            dk,
          ],
          stops: const [0, 35 / 95, 75 / 95, .99, 1],
        ), [
          _F(x: pp[0].dx, y: pp[0].dy, o: 0),
          _F(x: pp[0].dx, y: pp[0].dy, at: .08),
          _F(x: pp[1].dx, y: pp[1].dy, at: .28),
          _F(x: pp[2].dx, y: pp[2].dy, at: .46),
          _F(x: pp[3].dx, y: pp[3].dy, at: .62),
          const _F(at: .78),
          const _F(s: 1.25, at: .86),
          const _F(s: 3, o: 0),
        ], 3400, 0, Curves.easeInOut);
        card(const [
          _F(),
          _F(x: -12, at: .15),
          _F(x: 12, at: .35),
          _F(x: -12, at: .55),
          _F(at: .75),
          _F(s: 1.15, at: .82),
          _F(),
        ], 3400);
        final peek = [(0.0, 250.0, 1.0), (W, 420.0, -1.0), (0.0, 560.0, 1.0), (W, 180.0, -1.0)];
        for (var i = 0; i < 4; i++) {
          final (x, y, sd) = peek[i];
          g('👀', 40, x, y * H / 844, [
            _F(x: -sd * 40),
            _F(x: sd * 22, at: .25, curve: _spring),
            _F(x: sd * 22, at: .7),
            _F(x: -sd * 40),
          ], 1300, 400 + i * 600.0);
        }
        popAt('❗', 36, ox + (ox > W / 2 ? -60 : 60), oy - 80, 800, 2600, 10);
      case '✨':
        linear([_c(255, 180, 255, .25), _c(140, 200, 255, .25), _c(255, 240, 160, .25)], const [
          _F(o: 0),
          _F(v: 90, at: .3),
          _F(v: 200, at: .8),
          _F(o: 0, v: 260),
        ], 3200, begin: Alignment.topLeft, end: Alignment.bottomRight, hue: true);
        const sc = [Colors.white, Color(0xFFFFE066), Color(0xFFFFB3F0), Color(0xFFA5D8FF)];
        for (var i = 0; i < 60; i++) {
          final t = i / 60, a = t * pi * 5, rr = 30 + t * 170;
          final x = cos(a) * rr, y = sin(a) * rr * .8;
          dot(r(4, 7), sc[i % 4], [
            _F(x: x, y: y, s: 0, o: 0),
            _F(x: x, y: y, s: 1.4, at: .15),
            _F(x: x * 1.05, y: y * 1.05 + 20, s: .3, o: 0),
          ], 900, i * 22.0, Curves.easeOut, true);
        }
        card(const [_F(), _F(s: 1.15, r: 10, at: .3), _F(s: 1.05, r: -6, at: .6), _F()], 1500);
        twinkles(30, 300, 2400);
        burstG(['✨', '⭐', '💫'], 16, 140, 300, 14, 26, 1400);
        ring(_c(255, 255, 255, .8), 560, 4, 700, 1400);
        fl(_c(255, 255, 255, .3), 300, 1400);
      case '🌈':
        linear([_c(120, 200, 255, .3), _c(120, 200, 255, 0)],
            op(const [0, 1, 1, 0], const [0, .2, .8, 1]), 3600, stops: const [0, .7]);
        final cy = oy + 40;
        const rb = [
          Color(0xFFFF6B6B),
          Color(0xFFFFA94D),
          Color(0xFFFFE066),
          Color(0xFF69DB7C),
          Color(0xFF4DABF7),
          Color(0xFF9775FA),
        ];
        for (var j = 0; j < 6; j++) {
          add(ReactionParticle(
            shape: ReactionShape.arc,
            size: W * 1.08 - j * 26,
            border: 13,
            color: rb[j],
            frames: _abs(W / 2, cy, const [
              _F(o: .9),
              _F(o: .9, v: 1, at: .35),
              _F(o: .9, v: 1, at: .82),
              _F(o: 0, v: 1),
            ]),
            duration: 3400,
            delay: j * 60.0,
            curve: const Cubic(.4, 0, .2, 1),
          ));
        }
        for (final (x, y, dl) in [
          (W / 2 - W * .54 + 20, cy + 10, 0.0),
          (W / 2 + W * .54 - 20, cy + 10, 1100.0),
        ]) {
          g('☁️', 70, x, y, const [
            _F(s: 0, o: 0),
            _F(s: 1.1, at: .15, curve: _spring),
            _F(at: .25),
            _F(at: .85),
            _F(s: .6, o: 0),
          ], 3400 - dl, dl);
        }
        twinkles(16, 600, 2200);
        card(const [_F(), _F(y: -14, s: 1.06, at: .3), _F(at: .6), _F()], 1600, 0, Curves.easeOut);
      case '☀️' || '🌞':
        linear([_c(255, 170, 60, .5), _c(255, 210, 120, .2), _c(130, 200, 255, .15)],
            op(const [0, 1, 1, 0], const [0, .25, .8, 1]), 3400,
            begin: Alignment.bottomCenter, end: Alignment.topCenter, stops: const [0, .5, 1],
            cv: Curves.easeInOut);
        add(ReactionParticle(
          shape: ReactionShape.sunburst,
          size: 760,
          color: _c(255, 220, 110, .38),
          frames: const [
            _F(s: .3, o: 0),
            _F(s: 1, r: 25, at: .3),
            _F(s: 1.05, r: 70, at: .8),
            _F(s: 1.1, o: 0, r: 90),
          ],
          duration: 3400,
        ));
        glw(_c(255, 230, 120, .75), 280, 2600);
        final fx2 = W - ox;
        const fy2 = 140.0;
        final fcs = [
          _c(255, 240, 180, .35),
          _c(160, 220, 255, .22),
          _c(255, 200, 120, .4),
          _c(200, 255, 200, .15),
          _c(255, 180, 220, .25),
          _c(255, 255, 255, .35),
        ];
        const fsz = [30.0, 60.0, 22.0, 90.0, 40.0, 26.0];
        for (var i = 0; i < 6; i++) {
          final t = .3 + i * .16;
          blob(fsz[i], fsz[i], ox + (fx2 - ox) * t, oy + (fy2 - oy) * t, const [
            _F(s: .4, o: 0),
            _F(at: .3),
            _F(at: .8),
            _F(s: 1.1, o: 0),
          ], 2800, dl: 300 + i * 60.0, cv: Curves.easeOut, cols: [fcs[i], _clr(fcs[i])],
              stops: const [0, .7], gradR: _sq2, border: 1,
              borderColor: _c(255, 255, 255, .12));
        }
        card(const [_F(), _F(s: 1.12, at: .3), _F(s: 1.08, at: .8), _F()], 3000);
        tint(const SoloEmojiTint(brightness: 1.15),
            const [_F(), _F(v: 1, at: .3), _F(v: 1, at: .8), _F()], 3000, 0, Curves.easeInOut);
        halo(_c(255, 210, 80, .9), op(const [0, 1, 1, 0], const [0, .3, .8, 1]), 3000, 0,
            Curves.easeInOut);
        for (var i = 0; i < 20; i++) {
          dt(r(3, 5), const Color(0xFFFFF3BF), r(20, W - 20), r(120, H - 140), const [
            _F(o: 0, s: .5),
            _F(y: -20, at: .5),
            _F(o: 0, y: -40),
          ], r(1500, 2200), r(300, 1600), Curves.easeInOut, true);
        }
      case '🎁':
        const n = 18;
        card([
          for (var i = 0; i <= n; i++)
            _F(
              r: i == 0 ? 0 : (i.isOdd ? 1 : -1) * (4 + i / n * 14),
              s: i == 0 ? 1 : 1 + i / n * .12,
              at: i / n * .42,
            ),
          const _F(s: 1.4, at: .47),
          const _F(s: .2, o: 0, at: .5),
          const _F(s: .2, o: 0, at: .8),
          const _F(s: 1.1, at: .9),
          const _F(),
        ], 2600, 0, Curves.linear);
        const bb = 2600 * .48;
        fl(_c(255, 255, 255, .75), 360, bb);
        shake(8, 400, bb);
        ring(_c(255, 212, 59, .9), 700, 8, 700, bb);
        burstG(['🧸', '💎', '🎈', '⭐', '💝', '🍬'], 12, 150, 320, 26, 40, bb, 120);
        for (var i = 0; i < 14; i++) {
          final a = r(0, 2 * pi), d = r(150, 320);
          rc(4, r(30, 50), _conf[i % 6], ox, oy, [
            const _F(s: .3, o: 0),
            const _F(s: .5, at: .02),
            _F(x: cos(a) * d * .6, y: sin(a) * d * .6, r: r(180, 360), s: 1, at: .35),
            _F(x: cos(a) * d, y: sin(a) * d + 160, r: r(500, 900), o: 0),
          ], 1600, bb, _outC);
        }
        confettiRain(40, _conf, 2000, bb + 200);
      case '🏆':
        beam(ox, -10, oy + 70, 220, _c(255, 215, 90, .5), 0, 0, 3600);
        glw(_c(255, 210, 80, .6), 300, 2600);
        void fw(double x, double y, List<Color> cols, double dl) {
          dt(5, const Color(0xFFFFF3BF), x, H + 10, [
            const _F(),
            _F(y: y - H - 10, at: .95),
            _F(y: y - H - 10, o: 0),
          ], 600, dl, const Cubic(.2, .6, .4, 1), true);
          spot(180, cols[0], x, y, const [_F(s: .2, o: 0), _F(o: .8, at: .2), _F(s: 1.2, o: 0)],
              700, dl + 600, Curves.easeOut);
          for (var i = 0; i < 30; i++) {
            final a = i / 30 * 2 * pi, d = r(80, 120);
            dt(r(3, 5), cols[i % cols.length], x, y, [
              const _F(s: .4, o: 0),
              const _F(at: .02),
              _F(x: cos(a) * d * .85, y: sin(a) * d * .85, at: .4),
              _F(x: cos(a) * d, y: sin(a) * d + 60, s: .3, o: 0),
            ], 1400, dl + 600, _outC, true);
          }
        }
        fw(90, 200, const [Color(0xFFFFD43B), Color(0xFFFFF3BF)], 100);
        fw(W - 90, 170, const [Color(0xFFFF6B9A), Color(0xFFFFD43B)], 600);
        fw(W / 2, 260, const [Color(0xFF4DABF7), Colors.white], 1100);
        fw(110, 330, const [Color(0xFF69DB7C), Color(0xFFFFE066)], 1600);
        card(const [
          _F(),
          _F(y: -16, s: 1.1, at: .3),
          _F(y: -16, s: 1.1, r: -5, at: .5),
          _F(y: -16, s: 1.1, r: 5, at: .7),
          _F(),
        ], 2000);
        confettiRain(40, const [
          Color(0xFFFFD43B),
          Color(0xFFFCC419),
          Color(0xFFFFE066),
          Color(0xFFF59F00),
          Colors.white,
        ], 2200, 600);
      case '🍾':
        shiver(2.5, 800);
        const pp = 850.0;
        rcg(12, 16, const [Color(0xFFE9C46A), Color(0xFFB07D3A)], ox + 20, oy - 60, [
          const _F(o: 0),
          const _F(at: .01),
          _F(x: 60, y: -oy - 80, r: 720),
        ], 700, pp, const Cubic(.1, .6, .3, 1), radius: 4);
        fl(_c(255, 250, 220, .5), 260, pp);
        shake(6, 300, pp);
        ring(_c(255, 240, 200, .85), 300, 4, 500, pp);
        card(const [_F(), _F(sx: 1.15, sy: .85, at: .3), _F(sx: .95, sy: 1.08, at: .6), _F()],
            500, pp, Curves.easeOut);
        for (var i = 0; i < 60; i++) {
          final vx = r(-110, 110), yy = ballistic(r(250, 520));
          dt(r(4, 8), i % 3 != 0 ? const Color(0xFFFFF3BF) : Colors.white, ox + 20, oy - 60, [
            for (var j = 0; j <= 8; j++)
              _F(x: vx * j / 8, y: yy(j / 8), s: j == 0 ? .4 : 1, o: j == 8 ? 0 : 1),
          ], r(1300, 1700), pp + r(0, 700), Curves.linear, true);
        }
        for (var i = 0; i < 40; i++) {
          final sz = r(6, 14);
          blob(sz, sz, r(10, W - 10), H + 10,
              sway(0, 0, r(-10, 10), -r(400, 800), 10, r(0, 6), 5, (x, y, t, j, s) =>
                  _F(x: x, y: y, o: j == 0 || j == s ? 0 : 1)),
              r(2000, 2800), dl: pp + r(0, 1500), cv: Curves.easeOut,
              cols: [_c(255, 255, 255, .6), _c(255, 255, 255, 0)], stops: const [0, .6],
              gradCenter: const Alignment(-.4, -.4), gradR: 1.98,
              border: 1.5, borderColor: _c(255, 240, 190, .8));
        }
        g('🥂', 54, W / 2, 170, const [
          _F(s: 0, o: 0),
          _F(s: 1.2, at: .2, curve: _spring),
          _F(r: -8, at: .35),
          _F(r: 8, at: .5),
          _F(at: .85),
          _F(s: .6, o: 0),
        ], 1800, pp + 700);
        popAt('✨', 30, W / 2, 140, 600, pp + 950);
      case '🌚':
        linear([_c(6, 10, 36, .85), _c(16, 24, 64, .55)],
            op(const [0, 1, 1, 0], const [0, .15, .88, 1]), 3600, cv: Curves.easeInOut);
        spot(300, _c(200, 215, 255, .35), ox, oy, const [
          _F(s: .4, o: 0),
          _F(at: .3),
          _F(at: .85),
          _F(s: 1.1, o: 0),
        ], 3400, 0, Curves.easeOut);
        for (var i = 0; i < 34; i++) {
          dt(r(2, 4), Colors.white, r(14, W - 14), r(70, H - 180), const [
            _F(o: 0, s: .5),
            _F(at: .3),
            _F(o: .3, at: .55),
            _F(at: .75),
            _F(o: 0),
          ], r(2200, 3000), r(200, 900), Curves.easeInOut, true);
        }
        for (final (x, y, dx, dy, dl) in [
          (W + 40, 80.0, -W - 80, 260.0, 900.0),
          (W + 40, 200.0, -W * .7, 240.0, 2000.0),
        ]) {
          final ang = math.atan2(dy, dx) * 180 / pi;
          rcg(140, 3, [Colors.white, _c(255, 255, 255, 0)], x, y, [
            _F(r: ang - 180, o: 0),
            _F(x: dx * .1, y: dy * .1, r: ang - 180, at: .1),
            _F(x: dx, y: dy, r: ang - 180, o: 0),
          ], 900, dl, const Cubic(.3, 0, .7, 1),
              radius: 3, vertical: false, glowColor: Colors.white, blur: 6);
        }
        card(const [
          _F(),
          _F(x: -10, r: -6, at: .3),
          _F(x: -10, r: -6, at: .6),
          _F(x: 8, r: 4, at: .8),
          _F(),
        ], 3000);
      default:
        // Любой другой — эффект реакции (крупнее).
        out.addAll(reactionBurstFor(e, random: rnd, intensity: 1.4));
        card(const [
          _F(),
          _F(sx: 1.16, sy: .86, at: .22),
          _F(sx: .93, sy: 1.08, at: .5),
          _F(),
        ], 460, 0, Curves.linear, Offset.zero);
    }
    return SoloEmojiEffect(
      particles: out,
      cards: cards,
      tints: tints,
      screen: screen,
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
//   «Уже видел» — один раз у человека
// ═══════════════════════════════════════════════════════════════════════════

/// Какие сообщения-эмодзи уже сыграли крупную анимацию у этого человека.
class SoloEmojiSeen {
  SoloEmojiSeen._();
  static const _key = 'solo_emoji_fx_seen_v1';
  static const int _cap = 800;
  static final Set<String> _ids = <String>{};
  static Future<void>? _loading;
  static bool _ready = false;

  static bool get ready => _ready;

  static Future<void> ensureLoaded() => _loading ??= () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ids.addAll(prefs.getStringList(_key) ?? const []);
    } catch (_) {}
    _ready = true;
  }();

  static bool isSeen(String id) => _ids.contains(id);

  static void markSeen(String id) {
    if (!_ids.add(id)) return;
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        var list = _ids.toList();
        if (list.length > _cap) list = list.sublist(list.length - _cap);
        await prefs.setStringList(_key, list);
      } catch (_) {}
    }());
  }

  @visibleForTesting
  static void resetForTest() {
    _ids.clear();
    _ready = true;
    _loading = Future<void>.value();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Слой эффекта на весь экран — один за раз
// ═══════════════════════════════════════════════════════════════════════════

bool _soloFxBusy = false;

/// Видимая часть экрана для эффекта: без клавиатуры. Берём отступ у окна,
/// а не у [MediaQuery] места вызова — `Scaffold` его у ленты уже убрал.
Size soloEmojiVisibleArea(BuildContext context, Size screen) {
  final view = View.maybeOf(context);
  final keyboard = view == null
      ? MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0
      : view.viewInsets.bottom / view.devicePixelRatio;
  return soloEmojiAreaAboveKeyboard(screen, keyboard);
}

/// Высота без клавиатуры (не меньше трети экрана — на всякий случай).
Size soloEmojiAreaAboveKeyboard(Size screen, double keyboard) {
  if (keyboard <= 0) return screen;
  final h = math.max(screen.height / 3, screen.height - keyboard);
  return Size(screen.width, h);
}

/// Сыграть эффект поверх всего экрана. `false` — уже идёт другой.
bool playSoloEmojiFx({
  required BuildContext context,
  required SoloEmojiEffect effect,
  required Offset origin,
}) {
  if (_soloFxBusy) return false;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return false;
  // Н-10: эффект привязан к экрану чата — вышли из чата посреди 👻 ⚡ 🎂 💀,
  // и он снимается, а не затемняет список чатов.
  final route = ModalRoute.of(context);
  _soloFxBusy = true;
  HapticFeedback.mediumImpact();
  late OverlayEntry entry;
  void done() {
    _soloFxBusy = false;
    if (entry.mounted) entry.remove();
  }
  entry = OverlayEntry(
    builder: (_) => RouteBoundFx(
      route: route,
      onCancel: done,
      child: _SoloFxLayer(effect: effect, origin: origin, onDone: done),
    ),
  );
  overlay.insert(entry);
  return true;
}

@visibleForTesting
void resetSoloFxForTest() => _soloFxBusy = false;

class _SoloFxLayer extends StatefulWidget {
  const _SoloFxLayer({
    required this.effect,
    required this.origin,
    required this.onDone,
  });

  final SoloEmojiEffect effect;
  final Offset origin;
  final VoidCallback onDone;

  @override
  State<_SoloFxLayer> createState() => _SoloFxLayerState();
}

class _SoloFxLayerState extends State<_SoloFxLayer>
    with SingleTickerProviderStateMixin {
  late final double _ms = widget.effect.layerMs;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _ms.round().clamp(1, 6000)),
  )..forward().whenComplete(() => widget.onDone());

  @override
  void initState() {
    super.initState();
    // Тряска и качка всего чата идут по тем же часам, что и частицы.
    if (widget.effect.screen.isNotEmpty) _c.addListener(_moveScreen);
  }

  void _moveScreen() {
    _soloScreenPose.value = soloEmojiScreenPoseAt(widget.effect, _c.value * _ms);
  }

  @override
  void dispose() {
    _c.dispose();
    _soloScreenPose.value = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Слой — только над клавиатурой: края (виньетка, полосы) у её кромки.
    final mq = MediaQuery.of(context);
    final area = soloEmojiAreaAboveKeyboard(mq.size, mq.viewInsets.bottom);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox.fromSize(
          size: area,
          child: ClipRect(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  size: area,
                  painter: ReactionBurstPainter(
                    particles: widget.effect.particles,
                    ms: _c.value * _ms,
                    origin: widget.origin,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Движение самого эмодзи во время эффекта.
/// Вокруг [pivot] — так задаёт CSS `transform-origin`.
Matrix4 _soloPose(ReactionFrame f, Offset pivot) {
  final m = Matrix4.identity()
    ..translateByDouble(pivot.dx + f.x, pivot.dy + f.y, 0, 1);
  if (f.r != 0) m.rotateZ(f.r * math.pi / 180);
  if (f.kx != 0 || f.ky != 0) {
    m.multiply(Matrix4.skew(f.kx * math.pi / 180, f.ky * math.pi / 180));
  }
  return m
    ..scaleByDouble(f.scaleX, f.scaleY, 1, 1)
    ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1);
}

/// Кадр последней идущей дорожки (поздняя перекрывает раннюю, как в WAAPI).
(SoloEmojiTrack, ReactionFrame)? _soloActive(List<SoloEmojiTrack> ts, double ms) {
  for (var i = ts.length - 1; i >= 0; i--) {
    final f = ts[i].at(ms);
    if (f != null) return (ts[i], f);
  }
  return null;
}

Matrix4 soloEmojiCardTransform(SoloEmojiEffect e, double ms) {
  final hit = _soloActive(e.cards, ms);
  if (hit == null) return Matrix4.identity();
  final (t, f) = hit;
  return _soloPose(f, t.pivot * kSoloEmojiSize);
}

/// Прозрачность эмодзи во время эффекта (🚀 улетает, 👻 мерцает, 💔 и 🎁
/// пропадают).
double soloEmojiCardOpacity(SoloEmojiEffect e, double ms) =>
    _soloActive(e.cards, ms)?.$2.o ?? 1;

/// Окраска эмодзи (😡 и 😳 краснеют, ⚡ и ☀️ вспыхивают); `null` — без неё.
ColorFilter? soloEmojiCardFilter(SoloEmojiEffect e, double ms) {
  final hit = _soloActive(e.tints, ms);
  if (hit == null) return null;
  final (t, f) = hit;
  final tint = t.tint;
  if (tint == null || f.v <= 0.004) return null;
  return ColorFilter.matrix(tint.matrix(f.v));
}

// ═══════════════════════════════════════════════════════════════════════════
//   Движение всего чата (тряска, качка, перекос) — макет `this.el.shake`
// ═══════════════════════════════════════════════════════════════════════════

/// Положение чата в координатах экрана (`null` — покой).
final ValueNotifier<Matrix4?> _soloScreenPose = ValueNotifier<Matrix4?>(null);

@visibleForTesting
ValueListenable<Matrix4?> get soloEmojiScreenPose => _soloScreenPose;

/// Положение чата в момент [ms] эффекта (`null` — покой).
Matrix4? soloEmojiScreenPoseAt(SoloEmojiEffect e, double ms) {
  final hit = _soloActive(e.screen, ms);
  if (hit == null) return null;
  final (t, f) = hit;
  return _soloPose(f, t.pivot);
}

/// Обёртка ленты чата: трясёт, качает и перекашивает её вместе с эффектом
/// эмодзи. В покое — без слоя и без перерисовки (единичное преобразование
/// рисует ребёнка как есть); слушает эффект напрямую, без перестройки.
class SoloEmojiScreenMotion extends SingleChildRenderObjectWidget {
  const SoloEmojiScreenMotion({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderScreenMotion();
}

class _RenderScreenMotion extends RenderTransform {
  _RenderScreenMotion() : super(transform: Matrix4.identity());

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _soloScreenPose.addListener(_onPose);
    _onPose();
  }

  @override
  void detach() {
    _soloScreenPose.removeListener(_onPose);
    super.detach();
  }

  void _onPose() {
    final p = _soloScreenPose.value;
    if (p == null || !attached || !hasSize) {
      transform = Matrix4.identity();
      return;
    }
    // Положение задано в координатах экрана — переводим в свои.
    final g = localToGlobal(Offset.zero);
    transform = Matrix4.translationValues(-g.dx, -g.dy, 0)
      ..multiply(p)
      ..translateByDouble(g.dx, g.dy, 0, 1);
  }
}
