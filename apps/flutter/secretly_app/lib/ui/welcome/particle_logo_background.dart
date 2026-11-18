// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Настроение фона — как в макете «Secretly Kit» (17.11.2026).
///
/// Знак из частиц отвечает на то, что происходит на экране: чёткий на
/// приветствии, уходит на второй план под формами, ускоряется, пока идёт
/// работа, и рассыпается в момент успеха.
enum WelcomeBackgroundMood { hero, calm, work, success }

/// В проверках (`flutter test`) бесконечные анимации входа стоят: иначе
/// нельзя было бы дождаться конца переходов (`pumpAndSettle`).
abstract final class WelcomeBackdropTesting {
  static final bool still =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
}

/// Путь к точкам знака. Готовит их `tool/gen_welcome_logo_field.py`.
const String kWelcomeLogoFieldAsset = 'assets/welcome/logo_field.bin';

/// Фон приветственных экранов: знак Secretly, собранный из светящихся точек.
///
/// Все точки рисуются одним вызовом `drawRawAtlas` — это несколько тысяч
/// спрайтов за кадр без нагрузки на процессор. Когда в системе выключены
/// анимации, фон замирает на одном кадре и не тикает вовсе.
class ParticleLogoBackground extends StatefulWidget {
  const ParticleLogoBackground({
    super.key,
    this.mood = WelcomeBackgroundMood.calm,
    this.particleCount,
    this.brightness,
  });

  final WelcomeBackgroundMood mood;

  /// Светлый или тёмный фон. По умолчанию — как у темы приложения.
  final Brightness? brightness;

  /// Сколько точек брать (по умолчанию: телефон — 2600, остальное — 3400).
  final int? particleCount;

  @override
  State<ParticleLogoBackground> createState() => _ParticleLogoBackgroundState();
}

class _MoodTarget {
  const _MoodTarget({
    required this.blur,
    required this.dim,
    required this.scale,
    required this.centerY,
    required this.speed,
    required this.conv,
    required this.glow,
  });

  final double blur, dim, scale, centerY, speed, conv, glow;
}

_MoodTarget _targetFor(WelcomeBackgroundMood mood, {required bool compact}) {
  switch (mood) {
    case WelcomeBackgroundMood.hero:
      return _MoodTarget(
        blur: 0.6,
        dim: 0,
        scale: compact ? 0.9 : 0.72,
        centerY: compact ? 0.3 : 0.36,
        speed: 1,
        conv: 1,
        glow: 1,
      );
    case WelcomeBackgroundMood.calm:
      return _MoodTarget(
        blur: 3,
        dim: compact ? 0.62 : 0.58,
        scale: compact ? 1.05 : 1.0,
        centerY: 0.5,
        speed: 0.55,
        conv: 1,
        glow: 0.9,
      );
    case WelcomeBackgroundMood.work:
      return _MoodTarget(
        blur: 0.8,
        dim: 0.05,
        scale: compact ? 0.72 : 0.6,
        centerY: compact ? 0.33 : 0.38,
        speed: 3.6,
        conv: 0.15,
        glow: 1.2,
      );
    case WelcomeBackgroundMood.success:
      return _MoodTarget(
        blur: 0.6,
        dim: 0,
        scale: compact ? 0.8 : 0.78,
        centerY: compact ? 0.3 : 0.36,
        speed: 1.2,
        conv: 1,
        glow: 1.4,
      );
  }
}

/// Текущее (сглаженное) состояние фона. Меняется каждый кадр.
class _FieldState extends ChangeNotifier {
  double blur = 0.6, dim = 0, scale = 0.8, centerY = 0.42;
  double speed = 1, conv = 1, glow = 1, scatter = 0, phase = 0;
  bool initialized = false;

  void tick() => notifyListeners();
}

class _ParticleLogoBackgroundState extends State<ParticleLogoBackground>
    with SingleTickerProviderStateMixin {
  static Future<Int16List>? _fieldFuture;

  final _state = _FieldState();
  Ticker? _ticker;
  Duration? _last;
  Float32List? _particles;
  int _count = 0;
  ui.Image? _sprite;

  static Future<Int16List> _loadField() {
    return _fieldFuture ??= rootBundle.load(kWelcomeLogoFieldAsset).then(
      (data) => data.buffer.asInt16List(
        data.offsetInBytes,
        data.lengthInBytes ~/ 2,
      ),
    );
  }

  bool get _compact {
    final size = MediaQuery.maybeSizeOf(context);
    return size == null || size.shortestSide < 600;
  }

  @override
  void initState() {
    super.initState();
    _sprite = _makeSprite();
    _ticker = createTicker(_onTick);
    _loadField().then((field) {
      if (!mounted) return;
      setState(() => _build(field));
    }, onError: (Object _) {
      // Без точек фон остаётся тёмным градиентом — экраны от этого не ломаются.
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant ParticleLogoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood &&
        widget.mood == WelcomeBackgroundMood.success) {
      _state.scatter = 1;
    }
    _syncTicker();
    if (!(_ticker?.isActive ?? false)) _snapToTarget();
  }

  void _syncTicker() {
    final reduce = WelcomeBackdropTesting.still ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final ticker = _ticker;
    if (ticker == null) return;
    if (reduce) {
      if (ticker.isActive) ticker.stop();
      _snapToTarget();
    } else if (!ticker.isActive) {
      _last = null;
      ticker.start();
    }
  }

  void _snapToTarget() {
    final t = _targetFor(widget.mood, compact: _compact);
    _state
      ..blur = t.blur
      ..dim = t.dim
      ..scale = t.scale
      ..centerY = t.centerY
      ..speed = t.speed
      ..conv = t.conv
      ..glow = t.glow
      ..scatter = 0
      ..initialized = true
      ..tick();
  }

  void _onTick(Duration elapsed) {
    final last = _last;
    _last = elapsed;
    var dt = last == null ? 0.016 : (elapsed - last).inMicroseconds / 1e6;
    if (dt > 0.05) dt = 0.05;
    final t = _targetFor(widget.mood, compact: _compact);
    if (!_state.initialized) _snapToTarget();
    final k = math.min(1.0, dt * 2.4);
    _state
      ..blur += (t.blur - _state.blur) * k
      ..dim += (t.dim - _state.dim) * k
      ..scale += (t.scale - _state.scale) * k
      ..centerY += (t.centerY - _state.centerY) * k
      ..speed += (t.speed - _state.speed) * k
      ..conv += (t.conv - _state.conv) * k
      ..glow += (t.glow - _state.glow) * k
      ..scatter += (0 - _state.scatter) * math.min(1.0, dt * 1.6)
      ..phase += dt * _state.speed;
    _state.tick();
  }

  void _build(Int16List field) {
    final available = field.length ~/ 3;
    final wanted =
        widget.particleCount ??
        (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS
            ? 2600
            : 3400);
    final n = math.min(available, wanted);
    final rnd = math.Random(17112026);
    final p = Float32List(n * _stride);
    for (var i = 0; i < n; i++) {
      final o = i * _stride;
      final wt = field[i * 3 + 2] / 32767.0;
      p[o] = field[i * 3] / 32767.0;
      p[o + 1] = field[i * 3 + 1] / 32767.0;
      p[o + 2] =
          0.0026 + 0.0021 * math.pow(rnd.nextDouble(), 1.1) * (0.6 + 0.7 * wt);
      p[o + 3] = math.min(
        1,
        0.58 + 0.32 * rnd.nextDouble() * (0.6 + 0.6 * wt),
      );
      p[o + 4] = 1.0 + rnd.nextInt(4);
      p[o + 5] = rnd.nextDouble();
      p[o + 6] = rnd.nextDouble() * 2 - 1;
      final amp = 0.0035 + 0.008 * rnd.nextDouble();
      final s1 = 0.55 + 0.3 * rnd.nextDouble();
      final s2 = 0.55 + 0.3 * rnd.nextDouble();
      p[o + 7] = amp * s1;
      p[o + 8] = 1.0 + rnd.nextInt(3);
      p[o + 9] = rnd.nextDouble();
      p[o + 10] = amp * (1 - s1);
      p[o + 11] = 2.0 + rnd.nextInt(3);
      p[o + 12] = rnd.nextDouble();
      p[o + 13] = amp * s2 * 0.9;
      p[o + 14] = 1.0 + rnd.nextInt(3);
      p[o + 15] = rnd.nextDouble();
      p[o + 16] = amp * (1 - s2) * 0.9;
      p[o + 17] = 2.0 + rnd.nextInt(3);
      p[o + 18] = rnd.nextDouble();
      p[o + 19] = (rnd.nextDouble() - 0.5) * 2.2;
      p[o + 20] = rnd.nextDouble();
    }
    _particles = p;
    _count = n;
  }

  static ui.Image _makeSprite() {
    const side = 64.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(side / 2, side / 2),
        side / 2,
        const [
          Color(0xFFFFFFFF),
          Color(0xD9FFFFFF),
          Color(0x4DFFFFFF),
          Color(0x00FFFFFF),
        ],
        const [0, 0.28, 0.55, 1],
      );
    canvas.drawCircle(const Offset(side / 2, side / 2), side / 2, paint);
    return recorder.endRecording().toImageSync(side.toInt(), side.toInt());
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _sprite?.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark =
        (widget.brightness ?? Theme.of(context).brightness) == Brightness.dark;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(
            state: _state,
            particles: _particles,
            count: _count,
            sprite: _sprite,
            dark: dark,
          ),
        ),
      ),
    );
  }
}

const int _stride = 21;

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.state,
    required this.particles,
    required this.count,
    required this.sprite,
    required this.dark,
  }) : super(repaint: state);

  final _FieldState state;
  final Float32List? particles;
  final int count;
  final ui.Image? sprite;
  final bool dark;

  static const double _tau = math.pi * 2;
  static const double _period = 26;
  static const double _thick = 0.087;
  static const double _focus = 2.6;

  // Серебро макета: три чуть разных белых.
  static const _silver = [
    Color(0xFFFFFFFF),
    Color(0xFFF1F5FA),
    Color(0xFFFAFAF6),
  ];
  // На светлом фоне — графит.
  static const _graphite = [
    Color(0xFF1C1E24),
    Color(0xFF242833),
    Color(0xFF2A2A2E),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final cx = w * 0.5, cy = h * state.centerY;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          math.max(w, h) * 0.7,
          dark
              ? const [Color(0xFF18181B), Color(0xFF0A0A0B), Color(0xFF000000)]
              : const [Color(0xFFFFFFFF), Color(0xFFF4F4F6), Color(0xFFE9E9ED)],
          const [0, 0.55, 1],
        ),
    );

    final p = particles;
    final img = sprite;
    if (p != null && img != null && count > 0) {
      final t = (state.phase / _period) % 1.0;
      final span = math.min(w, h) * 0.69 * state.scale;
      final angY = 0.5 * math.sin(_tau * t);
      final angX = 0.08 * math.sin(_tau * t + 1.7);
      final cY = math.cos(angY), sY = math.sin(angY);
      final cX = math.cos(angX), sX = math.sin(angX);
      final conv = state.conv, sct = state.scatter, glow = state.glow;
      // Размытие макета (CSS blur) здесь — крупнее и бледнее точки: тот же
      // вид без фильтра на весь экран.
      final soften = 1 + state.blur * 0.55;
      final fade = 1 / (1 + state.blur * 0.32);
      final palette = dark ? _silver : _graphite;
      final xf = Float32List(count * 4);
      final rects = Float32List(count * 4);
      final colors = Int32List(count);
      final sw = img.width.toDouble();
      var drawn = 0;
      for (var i = 0; i < count; i++) {
        final o = i * _stride;
        final dx =
            conv *
            (p[o + 7] * math.sin(_tau * (p[o + 8] * t + p[o + 9])) +
                p[o + 10] * math.sin(_tau * (p[o + 11] * t + p[o + 12])));
        final dy =
            conv *
            (p[o + 13] * math.sin(_tau * (p[o + 14] * t + p[o + 15])) +
                p[o + 16] * math.sin(_tau * (p[o + 17] * t + p[o + 18])));
        final ex = 1 + sct * (0.35 + 0.25 * p[o + 19]);
        final lx = (p[o] + dx) * ex;
        final ly = (p[o + 1] + dy) * ex;
        final lz = p[o + 6] * _thick * (1 + sct * 6);
        final x1 = lx * cY + lz * sY;
        final z1 = lz * cY - lx * sY;
        final y2 = ly * cX - z1 * sX;
        final z2 = ly * sX + z1 * cX;
        final persp = _focus / (_focus - z2);
        final x = cx + x1 * span * persp;
        final y = cy + y2 * span * persp;
        var a =
            p[o + 3] * (0.66 + 0.34 * math.sin(_tau * (p[o + 4] * t + p[o + 5])));
        var dep = (z2 + 0.55) / 1.1;
        dep = dep < 0 ? 0 : (dep > 1 ? 1 : dep);
        a *= (0.4 + 0.6 * dep) * glow * fade;
        if (!dark) a *= 0.62;
        if (a < 0.012) continue;
        var s = p[o + 2] * span * persp * soften;
        if (s < 0.4) s = 0.4;
        final scale = (s * 2) / sw;
        final j = drawn * 4;
        xf[j] = scale;
        xf[j + 1] = 0;
        xf[j + 2] = x - s;
        xf[j + 3] = y - s;
        rects[j] = 0;
        rects[j + 1] = 0;
        rects[j + 2] = sw;
        rects[j + 3] = sw;
        final base = palette[(p[o + 20] * palette.length).floor() %
            palette.length];
        colors[drawn] = base
            .withValues(alpha: a > 1 ? 1.0 : a)
            .toARGB32();
        drawn++;
      }
      if (drawn > 0) {
        canvas.drawRawAtlas(
          img,
          Float32List.sublistView(xf, 0, drawn * 4),
          Float32List.sublistView(rects, 0, drawn * 4),
          Int32List.sublistView(colors, 0, drawn),
          BlendMode.modulate,
          null,
          Paint()
            ..blendMode = dark ? BlendMode.plus : BlendMode.srcOver
            ..filterQuality = FilterQuality.low,
        );
      }
    }

    if (state.dim > 0.01) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = (dark ? const Color(0xFF000000) : const Color(0xFFF4F4F6))
              .withValues(alpha: (dark ? state.dim : state.dim * 0.85)),
      );
    }
    // Виньетка макета: края темнее, середина открыта.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w / 2, h * 0.45),
          math.max(w, h) * 0.62,
          dark
              ? const [Color(0x00000000), Color(0x8C000000)]
              : const [Color(0x00FFFFFF), Color(0x40E4E4EA)],
          const [0.45, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.particles != particles ||
      old.sprite != sprite ||
      old.dark != dark ||
      old.count != count;
}

/// Фон из частиц под несколькими экранами сразу (вход на ПК): один на все
/// шаги, чтобы точки не «перезапускались» на каждом переходе. Шаг может на
/// время сменить настроение — [WelcomeBackdrop.setMood], например «идёт
/// работа», пока создаётся аккаунт.
class WelcomeBackdrop extends StatefulWidget {
  const WelcomeBackdrop({super.key, required this.mood, required this.child});

  final WelcomeBackgroundMood mood;
  final Widget child;

  /// Поменять настроение на время (`null` — вернуть обычное).
  static void setMood(BuildContext context, WelcomeBackgroundMood? mood) {
    final scope = context
        .getInheritedWidgetOfExactType<_WelcomeMoodScope>()
        ?.notifier;
    if (scope != null && scope.value != mood) scope.value = mood;
  }

  @override
  State<WelcomeBackdrop> createState() => _WelcomeBackdropState();
}

class _WelcomeBackdropState extends State<WelcomeBackdrop> {
  final _override = ValueNotifier<WelcomeBackgroundMood?>(null);

  @override
  void dispose() {
    _override.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _WelcomeMoodScope(
      notifier: _override,
      child: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<WelcomeBackgroundMood?>(
              valueListenable: _override,
              builder: (_, override, __) =>
                  ParticleLogoBackground(mood: override ?? widget.mood),
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class _WelcomeMoodScope extends InheritedWidget {
  const _WelcomeMoodScope({required this.notifier, required super.child});

  final ValueNotifier<WelcomeBackgroundMood?> notifier;

  @override
  bool updateShouldNotify(_WelcomeMoodScope oldWidget) =>
      oldWidget.notifier != notifier;
}
