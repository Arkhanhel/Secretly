// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../../profile_fx.dart';

/// Все рамки коллекции. Порядок и названия — как в дизайн-макете.
enum AvatarFrame {
  ryzhik('Рыжик'),
  coder('Кодер'),
  music('Меломан'),
  aquarium('Аквариум'),
  slime('Слайм'),
  octopus('Осьминожка'),
  bird('Птичка'),
  lavaLamp('Лава-лампа'),
  ghost('Призрачок'),
  streak('Стрик'),
  levelUp('Level Up'),
  live('В эфире'),
  bubbleGum('Бабл-гам'),
  stickers('Стикерпак'),
  aura('Аура'),
  glitch('Глитч'),
  socialBattery('Соцбатарейка'),
  typing('Печатает…'),
  saturn('Сатурн'),
  vinyl('Винил'),
  weather('Тучка'),
  sleep('Не беспокоить'),
  pixel('8-бит'),
  chrome('Жидкий хром');

  const AvatarFrame(this.title);
  final String title;

  FrameSim _create() => switch (this) {
        AvatarFrame.ryzhik => _Cat(),
        AvatarFrame.coder => _Coder(),
        AvatarFrame.music => _Music(),
        AvatarFrame.aquarium => _Fish(),
        AvatarFrame.slime => _Slime(),
        AvatarFrame.octopus => _Octo(),
        AvatarFrame.bird => _Bird(),
        AvatarFrame.lavaLamp => _Lava(),
        AvatarFrame.ghost => _Ghost(),
        AvatarFrame.streak => _Fire(),
        AvatarFrame.levelUp => _Xp(),
        AvatarFrame.live => _Live(),
        AvatarFrame.bubbleGum => _Gum(),
        AvatarFrame.stickers => _Stickers(),
        AvatarFrame.aura => _Aura(),
        AvatarFrame.glitch => _Glitch(),
        AvatarFrame.socialBattery => _Battery(),
        AvatarFrame.typing => _Typing(),
        AvatarFrame.saturn => _Saturn(),
        AvatarFrame.vinyl => _Vinyl(),
        AvatarFrame.weather => _Weather(),
        AvatarFrame.sleep => _Sleep(),
        AvatarFrame.pixel => _Pixel(),
        AvatarFrame.chrome => _Chrome(),
      };
}

/// Живые данные для рамок со счётчиками. Всё необязательно:
/// без значений рамка работает в демо-режиме.
@immutable
class FrameInputs {
  const FrameInputs({this.streak, this.level, this.xp, this.viewers, this.battery, this.typingText});

  /// Стрик: дней подряд.
  final int? streak;

  /// Level Up: уровень и прогресс 0..1.
  final int? level;
  final double? xp;

  /// В эфире: число зрителей.
  final int? viewers;

  /// Соцбатарейка: 0..1.
  final double? battery;

  /// Печатает…: текст отправленного сообщения.
  final String? typingText;
}

@immutable
class FramePalette {
  const FramePalette(this.dark, this.bg);
  final bool dark;
  final Color bg;
  Color get ink => dark ? const Color(0xFFD8D8DE) : const Color(0xFF2A2A30);
  Color get band => dark ? const Color(0xFF5A5A6C) : const Color(0xFF2C2C34);
  Color get glove => const Color(0xFF2A2D3A);
  Color get sleeve => dark ? const Color(0xFFFFA852) : const Color(0xFFFF9F43);
  Color get track => dark ? const Color(0xFF2A2A30) : const Color(0xFFECEAE5);
  Color get chip => dark ? const Color(0xFF2C2E3A) : const Color(0xFF1B1D27);
  Color get cloud => dark ? const Color(0xFF6A7185) : const Color(0xFFD5DBE6);
  double get shadow => dark ? 0.4 : 0.14;
  double get bubbleAlpha => dark ? 0.18 : 0.12;

  @override
  bool operator ==(Object other) =>
      other is FramePalette && other.dark == dark && other.bg == bg;
  @override
  int get hashCode => Object.hash(dark, bg);
}

/// Живая рамка вокруг круглого фото профиля.
///
/// Холст рамки — [size] × [size]; фото занимает ~55–58% по центру,
/// остальное место — для ушей, рук, нот и т. п.
class AnimatedAvatarFrame extends StatefulWidget {
  const AnimatedAvatarFrame({
    super.key,
    required this.frame,
    required this.child,
    this.size = 160,
    this.gapColor,
    this.animate = true,
    this.active,
    this.onActiveChanged,
    this.inputs = const FrameInputs(),
    this.tapToToggle = true,
  });

  final AvatarFrame frame;

  /// Фото профиля. Обрезается в круг автоматически.
  final Widget child;
  final double size;

  /// Цвет зазора между кольцом и фото. По умолчанию — фон Scaffold.
  final Color? gapColor;

  /// false → статичный кадр (для списка чатов, < 48 px).
  final bool animate;

  /// Внешнее управление «особым» состоянием (погладить, дедлайн, пауза…).
  /// null → переключается тапом.
  final bool? active;
  final ValueChanged<bool>? onActiveChanged;
  final FrameInputs inputs;
  final bool tapToToggle;

  /// Диаметр фото внутри холста рамки размера [size].
  static double photoDiameter(AvatarFrame frame, double size) => frame._create().av * 2 / 200 * size;

  @override
  State<AnimatedAvatarFrame> createState() => _AnimatedAvatarFrameState();
}

class _AnimatedAvatarFrameState extends State<AnimatedAvatarFrame> with SingleTickerProviderStateMixin {
  late FrameSim _sim = widget.frame._create();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  late bool _active = widget.active ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant AnimatedAvatarFrame old) {
    super.didUpdateWidget(old);
    if (old.frame != widget.frame) {
      _sim.dispose();
      _sim = widget.frame._create();
    }
    if (widget.active != null) _active = widget.active!;
    _sync();
  }

  bool get _animating => widget.animate && !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  void _sync() {
    _sim
      ..active = _active
      ..inputs = widget.inputs;
    if (_animating) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else {
      if (_ticker.isActive) _ticker.stop();
      _sim.settle();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _clamp((elapsed - _last).inMicroseconds / 1e6, 0, 1 / 30);
    _last = elapsed;
    _sim
      ..active = _active
      ..inputs = widget.inputs
      ..tick(dt);
  }

  void _toggle() {
    setState(() => _active = !_active);
    widget.onActiveChanged?.call(_active);
    if (!_animating) {
      _sim.active = _active;
      _sim.settle();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = FramePalette(theme.brightness == Brightness.dark, widget.gapColor ?? theme.scaffoldBackgroundColor);
    final s = _sim;
    Widget frame = RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: FittedBox(
          child: SizedBox(
            width: 200,
            height: 200,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: CustomPaint(painter: _FramePainter(s, pal, false))),
              Positioned(
                left: s.cx - s.av,
                top: s.cy - s.av,
                width: s.av * 2,
                height: s.av * 2,
                child: AnimatedBuilder(
                  animation: s,
                  builder: (_, child) => Opacity(
                    opacity: s.bodyOpacity,
                    child: Transform(alignment: Alignment.center, transform: s.bodyMatrix, child: child),
                  ),
                  child: ClipOval(child: SizedBox.expand(child: widget.child)),
                ),
              ),
              Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _FramePainter(s, pal, true)))),
            ]),
          ),
        ),
      ),
    );
    if (widget.tapToToggle) {
      frame = GestureDetector(onTap: _toggle, behavior: HitTestBehavior.opaque, child: frame);
    }
    return frame;
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.sim, this.pal, this.front) : super(repaint: sim);
  final FrameSim sim;
  final FramePalette pal;
  final bool front;
  @override
  void paint(Canvas c, Size size) => front ? sim.paintFront(c, pal) : sim.paintBack(c, pal);
  @override
  bool shouldRepaint(_FramePainter o) => o.sim != sim || o.pal != pal || o.front != front;
}

/// Базовая симуляция рамки. Координаты — холст 200 × 200.
abstract class FrameSim extends ChangeNotifier {
  FrameSim(this.cx, this.cy, this.R, this.av, [this.ringColors = const []]);

  final double cx, cy, R, av;
  final List<Color> ringColors;
  double t = _rnd() * 2;
  bool active = false;
  bool? _edgePrev;
  FrameInputs inputs = const FrameInputs();
  double bsx = 1, bsy = 1, brot = 0, bdx = 0, bdy = 0, bodyOpacity = 1;
  double ringWidth = 7;
  bool get drawRing => ringColors.isNotEmpty;

  /// true один раз — в кадр, когда [active] переключился.
  bool edge() {
    final ch = _edgePrev != null && _edgePrev != active;
    _edgePrev = active;
    return ch;
  }

  void tick(double dt) {
    t += dt;
    update(dt);
    notifyListeners();
  }

  /// Прогон 1.5 с симуляции — для статичного кадра.
  void settle() {
    for (var i = 0; i < 90; i++) {
      t += 1 / 60;
      update(1 / 60);
    }
    notifyListeners();
  }

  void update(double dt);
  void back(Canvas c, FramePalette p) {}
  void front(Canvas c, FramePalette p) {}

  /// «Дышащее» кольцо: деформация ±1.5 px.
  Path ringPath() =>
      _blob(cx, cy, R, (a) => 0.9 * math.sin(3 * a + t * 1.6) + 0.6 * math.sin(5 * a - t * 2.3));

  void body(double sx, double sy, [double rot = 0, double dx = 0, double dy = 0]) {
    bsx = sx;
    bsy = sy;
    brot = rot;
    bdx = dx;
    bdy = dy;
  }

  void breathe([double f = 1.6, double amp = 0.006]) {
    final b = math.sin(t * f) * amp;
    body(1 + b, 1 - b);
  }

  Matrix4 get bodyMatrix => Matrix4.translationValues(bdx, bdy, 0)
    ..multiply(Matrix4.rotationZ(brot * _deg))
    ..multiply(Matrix4.diagonal3Values(bsx, bsy, 1));

  void withBody(Canvas c, VoidCallback f) {
    c.save();
    c.translate(cx + bdx, cy + bdy);
    c.rotate(brot * _deg);
    c.scale(bsx, bsy);
    c.translate(-cx, -cy);
    f();
    c.restore();
  }

  void paintRing(Canvas c, [List<Color>? colors, double opacity = 1]) {
    final cols = colors ?? ringColors;
    final p = _stroke(Colors.white, ringWidth, StrokeCap.butt)
      ..shader = _linG(Offset(cx - R, cy - R), Offset(cx + R, cy + R), cols);
    if (opacity < 1) p.color = Color.fromRGBO(255, 255, 255, opacity);
    c.drawPath(ringPath(), p);
  }

  void paintBack(Canvas c, FramePalette p) {
    back(c, p);
    withBody(c, () {
      if (drawRing) paintRing(c);
      c.drawCircle(Offset(cx, cy), av + 3, _fill(p.bg));
    });
  }

  void paintFront(Canvas c, FramePalette p) => front(c, p);
}
