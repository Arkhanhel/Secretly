// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Знак Secretly из светлячков для окна Premium (23.11.2026).
///
/// Те же точки буквы «S», что у фона приветствия
/// (`assets/welcome/logo_field.bin`, макет «Secretly Particle Logo»), но:
/// * светлячки РАЗНОЦВЕТНЫЕ (золото, голубой, розовый, бирюза, сирень);
/// * знак можно наклонять пальцем в любую сторону — настоящий поворот в 3D с
///   перспективой; отпустил — пружина возвращает его к спокойному покачиванию.
///
/// Все точки — один вызов `drawRawAtlas`. При выключенных анимациях (и в
/// `flutter test`) знак стоит одним кадром и не тикает.
library;

import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../gpu_image_guard.dart';
import '../welcome/particle_logo_background.dart' show kWelcomeLogoFieldAsset;

/// Цвета светлячков (из макета «Premium Hub»: конфетти и акценты).
const List<Color> kFireflyPalette = [
  Color(0xFFE8A33D), // золото
  Color(0xFFFFE3A0), // светлое золото
  Color(0xFF3390EC), // синий
  Color(0xFF84C8FF), // голубой
  Color(0xFFFF7FC3), // розовый
  Color(0xFF59E4CD), // бирюза
  Color(0xFFB69CFF), // сирень
  Color(0xFFFFFFFF), // белый
];

/// Более плотные цвета для светлой темы: сложение света на белом не видно.
const List<Color> kFireflyPaletteLight = [
  Color(0xFFC98316),
  Color(0xFFB8860B),
  Color(0xFF1F78D1),
  Color(0xFF2E9BE0),
  Color(0xFFE0479B),
  Color(0xFF17A890),
  Color(0xFF7B5CE6),
  Color(0xFF5B6470),
];

/// Наклон знака: сколько радиан даёт один логический пиксель пальца и
/// предел наклона в каждую сторону.
const double kFireflyTiltPerPx = 0.012;
const double kFireflyTiltMax = 1.15;

/// Наклон после движения пальца на ([dx], [dy]) из ([yaw], [pitch]).
/// Вправо — знак поворачивается правым краем от нас, вниз — верхом к нам.
({double yaw, double pitch}) fireflyTiltAfterDrag({
  required double yaw,
  required double pitch,
  required double dx,
  required double dy,
}) {
  double clamp(double v) =>
      v < -kFireflyTiltMax ? -kFireflyTiltMax : (v > kFireflyTiltMax ? kFireflyTiltMax : v);
  return (
    yaw: clamp(yaw + dx * kFireflyTiltPerPx),
    pitch: clamp(pitch - dy * kFireflyTiltPerPx),
  );
}

class PremiumFireflyLogo extends StatefulWidget {
  const PremiumFireflyLogo({
    super.key,
    this.size = 120,
    this.particleCount = 2600,
    this.interactive = true,
  });

  final double size;
  final int particleCount;

  /// Можно ли наклонять пальцем.
  final bool interactive;

  @override
  State<PremiumFireflyLogo> createState() => _PremiumFireflyLogoState();
}

class _LogoMotion extends ChangeNotifier {
  double phase = 0;

  /// Наклон от пальца (рад): вокруг вертикали и горизонтали.
  double yaw = 0, pitch = 0;
  double yawV = 0, pitchV = 0;
  bool dragging = false;

  void tick() => notifyListeners();
}

class _PremiumFireflyLogoState extends State<PremiumFireflyLogo>
    with SingleTickerProviderStateMixin {
  static Future<Int16List>? _fieldFuture;
  static final bool _testing =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  final _motion = _LogoMotion();
  late final Ticker _ticker = createTicker(_onTick);
  Duration? _last;
  Float32List? _particles;
  int _count = 0;

  static Future<Int16List> _loadField() =>
      _fieldFuture ??= rootBundle.load(kWelcomeLogoFieldAsset).then(
        (d) => d.buffer.asInt16List(d.offsetInBytes, d.lengthInBytes ~/ 2),
      );

  @override
  void initState() {
    super.initState();
    _loadField().then((field) {
      if (!mounted) return;
      setState(() => _build(field));
    }, onError: (Object _) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  void _syncTicker() {
    final still =
        _testing || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final active = TickerMode.valuesOf(context).enabled && !still;
    if (active && !_ticker.isActive) {
      _last = null;
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final last = _last;
    _last = elapsed;
    var dt = last == null ? 0.016 : (elapsed - last).inMicroseconds / 1e6;
    if (dt > 0.05) dt = 0.05;
    final m = _motion..phase += dt;
    if (!m.dragging) {
      // Пружина к покою (критически не задемпфирована — лёгкий перелёт).
      const k = 38.0, d = 7.5;
      m.yawV += (-k * m.yaw - d * m.yawV) * dt;
      m.pitchV += (-k * m.pitch - d * m.pitchV) * dt;
      m.yaw += m.yawV * dt;
      m.pitch += m.pitchV * dt;
    }
    m.tick();
  }

  void _build(Int16List field) {
    final available = field.length ~/ 3;
    final n = math.min(available, widget.particleCount);
    // Равномерная выборка по всему полю, а не первые n точек.
    final step = available / n;
    final rnd = math.Random(23112026);
    final p = Float32List(n * _stride);
    for (var i = 0; i < n; i++) {
      final src = (i * step).floor();
      final o = i * _stride;
      final wt = field[src * 3 + 2] / 32767.0;
      p[o] = field[src * 3] / 32767.0;
      p[o + 1] = field[src * 3 + 1] / 32767.0;
      // Размер: светлячки покрупнее точек фона — знак маленький.
      p[o + 2] = 0.0046 + 0.0034 * math.pow(rnd.nextDouble(), 1.2) * (0.6 + 0.7 * wt);
      p[o + 3] = math.min(1, 0.62 + 0.3 * rnd.nextDouble() * (0.6 + 0.6 * wt));
      p[o + 4] = 0.6 + rnd.nextDouble() * 1.6; // частота мерцания, Гц
      p[o + 5] = rnd.nextDouble();
      p[o + 6] = rnd.nextDouble() * 2 - 1; // глубина
      final amp = 0.0022 + 0.0050 * rnd.nextDouble();
      p[o + 7] = amp;
      p[o + 8] = 0.05 + rnd.nextDouble() * 0.12; // частота дрейфа, Гц
      p[o + 9] = rnd.nextDouble();
      p[o + 10] = amp * 0.8;
      p[o + 11] = 0.05 + rnd.nextDouble() * 0.12;
      p[o + 12] = rnd.nextDouble();
      p[o + 13] = rnd.nextInt(kFireflyPalette.length).toDouble();
      // Редкие яркие вспышки, как у светлячков.
      p[o + 14] = rnd.nextDouble() < 0.16 ? 2.4 + 2.4 * rnd.nextDouble() : 0;
      p[o + 15] = 0.1 + rnd.nextDouble() * 0.25;
      p[o + 16] = rnd.nextDouble();
    }
    _particles = p;
    _count = n;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _onDown(PointerDownEvent e) {
    _motion
      ..dragging = true
      ..yawV = 0
      ..pitchV = 0;
    HapticFeedback.selectionClick();
  }

  void _onMove(PointerMoveEvent e) {
    final m = _motion;
    final next = fireflyTiltAfterDrag(
      yaw: m.yaw,
      pitch: m.pitch,
      dx: e.delta.dx,
      dy: e.delta.dy,
    );
    m
      ..yaw = next.yaw
      ..pitch = next.pitch;
    if (!_ticker.isActive) m.tick();
  }

  void _onUp(PointerEvent e) {
    _motion.dragging = false;
    if (!_ticker.isActive) {
      // Анимации выключены — сразу в покой.
      _motion
        ..yaw = 0
        ..pitch = 0
        ..tick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget logo = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _FireflyPainter(
          motion: _motion,
          particles: _particles,
          count: _count,
          dark: dark,
        ),
      ),
    );
    if (!widget.interactive) return ExcludeSemantics(child: logo);
    // Listener — сам наклон (сырые касания, без спора жестов); пустые
    // перетаскивания по обеим осям забирают жест у прокрутки страницы, пока
    // палец крутит знак.
    return ExcludeSemantics(
      child: Listener(
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onUp,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            _EagerPan: GestureRecognizerFactoryWithHandlers<_EagerPan>(
                  () => _EagerPan(),
                  (r) => r.onUpdate = (_) {},
                ),
          },
          child: logo,
        ),
      ),
    );
  }
}

/// Перетаскивание, которое сразу забирает жест у прокрутки страницы.
class _EagerPan extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Спрайт светлячка: один на всё приложение, делается, только пока
/// приложение на экране, и сбрасывается при возвращении из фона
/// ([GpuImageGuard]) — испорченная текстура не переживёт фон.
ui.Image? _fireflySprite;
bool _fireflySpriteGuarded = false;

ui.Image? _fireflySpriteNow() {
  final hit = _fireflySprite;
  if (hit != null) return hit;
  if (!_fireflySpriteGuarded) {
    _fireflySpriteGuarded = true;
    GpuImageGuard.register(() => _fireflySprite = null);
  }
  return _fireflySprite = _makeFireflySprite();
}

ui.Image _makeFireflySprite() {
  const side = 64.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawCircle(
    const Offset(side / 2, side / 2),
    side / 2,
    Paint()
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
      ),
  );
  return recorder.endRecording().toImageSync(side.toInt(), side.toInt());
}


const int _stride = 17;

class _FireflyPainter extends CustomPainter {
  _FireflyPainter({
    required this.motion,
    required this.particles,
    required this.count,
    required this.dark,
  }) : super(repaint: motion);

  final _LogoMotion motion;
  final Float32List? particles;
  final int count;
  final bool dark;

  static const double _tau = math.pi * 2;
  static const double _thick = 0.16; // толще фона — наклон читается как 3D
  static const double _focus = 2.4;

  @override
  void paint(Canvas canvas, Size size) {
    final p = particles;
    final img = _fireflySpriteNow();
    if (p == null || img == null || count == 0) return;
    final w = size.width, h = size.height;
    final cx = w / 2, cy = h / 2;
    final t = motion.phase;
    // Спокойное покачивание + наклон пальцем.
    final angY = 0.32 * math.sin(_tau * t / 9) + motion.yaw;
    final angX = 0.08 * math.sin(_tau * t / 9 + 1.7) + motion.pitch;
    final cY = math.cos(angY), sY = math.sin(angY);
    final cX = math.cos(angX), sX = math.sin(angX);
    final span = math.min(w, h) * 0.86;
    final palette = dark ? kFireflyPalette : kFireflyPaletteLight;
    final xf = Float32List(count * 4);
    final rects = Float32List(count * 4);
    final colors = Int32List(count);
    final sw = img.width.toDouble();
    var drawn = 0;
    for (var i = 0; i < count; i++) {
      final o = i * _stride;
      final dx = p[o + 7] * math.sin(_tau * (p[o + 8] * t + p[o + 9]));
      final dy = p[o + 10] * math.sin(_tau * (p[o + 11] * t + p[o + 12]));
      final lx = p[o] + dx, ly = p[o + 1] + dy, lz = p[o + 6] * _thick;
      final x1 = lx * cY + lz * sY;
      final z1 = lz * cY - lx * sY;
      final y2 = ly * cX - z1 * sX;
      final z2 = ly * sX + z1 * cX;
      final persp = _focus / (_focus - z2);
      final x = cx + x1 * span * persp;
      final y = cy + y2 * span * persp;
      var a = p[o + 3] * (0.6 + 0.4 * math.sin(_tau * (p[o + 4] * t + p[o + 5])));
      final flash = p[o + 14];
      if (flash > 0) {
        final tw = math.exp(flash * (math.cos(_tau * (p[o + 15] * t + p[o + 16])) - 1));
        if (tw > 0.01) a = math.min(1, a + 0.4 * tw);
      }
      var dep = (z2 + 0.55) / 1.1;
      dep = dep < 0 ? 0 : (dep > 1 ? 1 : dep);
      a *= 0.45 + 0.55 * dep;
      // На светлом фоне сложения света нет — точки плотнее и крупнее.
      if (!dark) a = math.min(1, a * 1.35);
      if (a < 0.02) continue;
      var s = p[o + 2] * span * persp * (dark ? 1 : 1.25);
      if (s < 0.6) s = 0.6;
      final j = drawn * 4;
      xf[j] = (s * 2) / sw;
      xf[j + 1] = 0;
      xf[j + 2] = x - s;
      xf[j + 3] = y - s;
      rects[j] = 0;
      rects[j + 1] = 0;
      rects[j + 2] = sw;
      rects[j + 3] = sw;
      colors[drawn] = palette[p[o + 13].toInt() % palette.length]
          .withValues(alpha: a > 1 ? 1.0 : a)
          .toARGB32();
      drawn++;
    }
    if (drawn == 0) return;
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

  @override
  bool shouldRepaint(_FireflyPainter old) =>
      old.particles != particles ||
      old.dark != dark ||
      old.count != count;
}
