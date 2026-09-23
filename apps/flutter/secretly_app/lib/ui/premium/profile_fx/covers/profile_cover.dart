// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
part of '../../profile_fx.dart';

/// Все обложки коллекции.
enum ProfileCoverStyle {
  // Сцены
  snow('Снегопад'),
  aurora('Сияние'),
  embers('Угли'),
  mesh('Меш'),
  starfall('Звездопад'),
  synthwave('Синтвейв'),
  bokeh('Боке'),
  ocean('Океан'),
  rainGlass('Дождь по стеклу'),
  fireflies('Светлячки'),
  soapBubbles('Мыльные пузыри'),
  topography('Топография'),
  silk('Шёлк'),
  constellations('Созвездия'),
  sakura('Сакура'),
  galaxy('Галактика'),
  clouds('Облака'),
  nightCity('Ночной город'),
  // Незабываемые
  flow('Поток'),
  hologram('Голограмма'),
  dotOcean('Точечный океан'),
  kaleidoscope('Калейдоскоп'),
  fireworks('Салют'),
  // Одно целое с фото
  eclipse('Затмение', true),
  blackHole('Чёрная дыра', true),
  moonPath('Дорожка', true),
  ripples('Круги на воде', true),
  spotlight('Прожектор', true);

  const ProfileCoverStyle(this.title, [this.usesAvatar = false]);
  final String title;

  /// true — сцена построена вокруг фото профиля (фото = луна, солнце, камень…).
  /// Передайте реальное положение аватара через [ProfileCover.avatarCenter] и [ProfileCover.avatarRadius].
  final bool usesAvatar;

  CoverSim _create() => switch (this) {
        ProfileCoverStyle.snow => _Snow(),
        ProfileCoverStyle.aurora => _Aurora(),
        ProfileCoverStyle.embers => _Embers(),
        ProfileCoverStyle.mesh => _Mesh(),
        ProfileCoverStyle.starfall => _Stars(),
        ProfileCoverStyle.synthwave => _Grid(),
        ProfileCoverStyle.bokeh => _Bokeh(),
        ProfileCoverStyle.ocean => _Waves(),
        ProfileCoverStyle.rainGlass => _RainGlass(),
        ProfileCoverStyle.fireflies => _Fireflies(),
        ProfileCoverStyle.soapBubbles => _SoapBubbles(),
        ProfileCoverStyle.topography => _Topo(),
        ProfileCoverStyle.silk => _Silk(),
        ProfileCoverStyle.constellations => _Plexus(),
        ProfileCoverStyle.sakura => _Sakura(),
        ProfileCoverStyle.galaxy => _Galaxy(),
        ProfileCoverStyle.clouds => _Clouds(),
        ProfileCoverStyle.nightCity => _City(),
        ProfileCoverStyle.flow => _Flow(),
        ProfileCoverStyle.hologram => _Holo(),
        ProfileCoverStyle.dotOcean => _DotWave(),
        ProfileCoverStyle.kaleidoscope => _Kaleido(),
        ProfileCoverStyle.fireworks => _Fireworks(),
        ProfileCoverStyle.eclipse => _Eclipse(),
        ProfileCoverStyle.blackHole => _BlackHole(),
        ProfileCoverStyle.moonPath => _MoonPath(),
        ProfileCoverStyle.ripples => _Ripples(),
        ProfileCoverStyle.spotlight => _Spotlight(),
      };
}

/// Живая обложка профиля. Заполняет всё доступное место —
/// оберните в `AspectRatio(aspectRatio: 3 / 2)` или задайте высоту.
class ProfileCover extends StatefulWidget {
  const ProfileCover({
    super.key,
    required this.style,
    this.animate = true,
    this.speed = 1,
    this.avatarCenter = const Offset(0.5, 0.36),
    this.avatarRadius = 0.1,
    this.tilt,
    this.interactive = true,
  });

  final ProfileCoverStyle style;
  final bool animate;

  /// Множитель скорости всей анимации.
  final double speed;

  /// Центр аватара в долях размера обложки (0..1) — для обложек [ProfileCoverStyle.usesAvatar].
  final Offset avatarCenter;

  /// Радиус аватара в долях ширины обложки.
  final double avatarRadius;

  /// Наклон телефона −1..1 (например, из sensors_plus). Используется в «Голограмме».
  final Offset? tilt;

  /// Реакция на касание.
  final bool interactive;

  @override
  State<ProfileCover> createState() => _ProfileCoverState();
}

class _ProfileCoverState extends State<ProfileCover> with SingleTickerProviderStateMixin {
  late CoverSim _sim = widget.style._create();
  late final Ticker _ticker = createTicker(_onTick);
  final _clock = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _t = _rnd() * 5, _dt = 0, _dpr = 2;
  Offset? _tap, _ptr;
  ui.Image? _acc;
  Size _accSize = Size.zero;
  bool _dark = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ProfileCover old) {
    super.didUpdateWidget(old);
    if (old.style != widget.style) {
      _sim = widget.style._create();
      _acc?.dispose();
      _acc = null;
    }
    _sync();
  }

  bool get _animating => widget.animate && !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  void _sync() {
    if (_animating) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else {
      if (_ticker.isActive) _ticker.stop();
      _dt = 1 / 60;
      _clock.value++;
    }
  }

  void _onTick(Duration e) {
    _dt = _clamp((e - _last).inMicroseconds / 1e6, 0, 1 / 30) * widget.speed;
    _last = e;
    _t += _dt;
    _clock.value++;
  }

  void _paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final s = _sim;
    s.av = Offset(widget.avatarCenter.dx * size.width, widget.avatarCenter.dy * size.height);
    s.ar = widget.avatarRadius * size.width;
    if (!s._ready) {
      s.init(size);
      s._ready = true;
    }
    if (s.size != size) {
      s.size = size;
      s._first = true;
    }
    final tap = _tap;
    _tap = null;
    final tilt = widget.tilt;
    final ptr = tilt != null ? Offset((tilt.dx * 0.5 + 0.5) * size.width, (tilt.dy * 0.5 + 0.5) * size.height) : _ptr;
    final dt = _dt;
    _dt = 0;
    if (!s.persistent) {
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      s.draw(canvas, size, _t, dt, _dark, tap, ptr);
      canvas.restore();
      return;
    }
    // Эффекты со следами: рисуем поверх прошлого кадра.
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(_dpr);
    final prev = _acc;
    if (prev != null && _accSize == size) {
      c.drawImageRect(prev, Rect.fromLTWH(0, 0, prev.width.toDouble(), prev.height.toDouble()), Offset.zero & size, Paint());
    } else {
      s._first = true;
    }
    s.draw(c, size, _t, dt, _dark, tap, ptr);
    final img = rec.endRecording().toImageSync((size.width * _dpr).ceil(), (size.height * _dpr).ceil());
    prev?.dispose();
    _acc = img;
    _accSize = size;
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _acc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _dark = Theme.of(context).brightness == Brightness.dark;
    _dpr = _clamp(MediaQuery.maybeDevicePixelRatioOf(context) ?? 2, 1, 2);
    Widget child = RepaintBoundary(
      child: CustomPaint(painter: _CoverPainter(this, _clock), child: const SizedBox.expand()),
    );
    if (widget.interactive) {
      child = MouseRegion(
        onHover: (e) => _ptr = e.localPosition,
        onExit: (_) => _ptr = null,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            _tap = e.localPosition;
            _ptr = e.localPosition;
          },
          onPointerMove: (e) => _ptr = e.localPosition,
          child: child,
        ),
      );
    }
    return child;
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.state, Listenable repaint) : super(repaint: repaint);
  final _ProfileCoverState state;
  @override
  void paint(Canvas canvas, Size size) => state._paint(canvas, size);
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Базовая симуляция обложки. Всё в логических пикселях.
abstract class CoverSim {
  Size size = Size.zero;
  bool _ready = false, _first = true;

  /// Положение и радиус аватара в пикселях обложки.
  Offset av = Offset.zero;
  double ar = 0;

  /// true — кадр рисуется поверх предыдущего (следы, шлейфы).
  bool get persistent => false;

  void init(Size s);

  /// [tap] не null только в кадр касания. [pointer] — палец/курсор/наклон.
  void draw(Canvas c, Size s, double t, double dt, bool dark, Offset? tap, Offset? pointer);

  /// Полупрозрачная заливка для эффекта следов.
  void fade(Canvas c, Size s, Color translucent, Color full) {
    if (_first) {
      c.drawRect(Offset.zero & s, _fill(full));
      _first = false;
    }
    c.drawRect(Offset.zero & s, _fill(translucent));
  }
}
