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
  spotlight('Прожектор', true),
  // Переделанные старые обложки (13.11.2026) — classic.dart.
  classicSpace('Космос'),
  classicWaves('Волны'),
  classicMeteors('Метеоры'),
  classicMarks('Иконки'),
  classicGoldHaze('Золотая дымка'),
  classicLogos('Наши иконки'),
  classicFire('Костёр'),
  classicFog('Дым'),
  classicBears('Мишки'),
  classicRainbow('Радуга'),
  classicFireflies('Светлячки'),
  classicFireworks('Салют'),
  classicGoldWillow('Золотой салют'),
  classicReef('Подводный мир'),
  classicGalaxy('Галактика', true),
  classicAuroraSky('Северное сияние'),
  // Эксклюзивная коллекция обложек (13.11.2026) — collection.dart.
  cloth('Полотно'),
  balls('Шарики'),
  orbits('Притяжение', true),
  chaos('Хаос'),
  life('Жизнь'),
  compass('Компасы'),
  plush('Плюш'),
  storm('Гроза'),
  ink('Чернила'),
  warp('Гиперпрыжок', true);

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
        _ => _createClassicCover(this) ?? _createCollectionCover(this) ?? _Snow(),
      };
}

/// Касания, переданные обложке со стороны: превью «Рамки и обложки» ставит
/// портрет поверх сцены, и палец на портрете до сцены не доходит. Экран
/// зовёт [poke] с глобальной точкой касания — обложка отвечает так же, как
/// на прямое касание (вспышка, круги, волна вокруг рамки).
class CoverPokes extends ChangeNotifier {
  Offset? _last;

  /// Последняя точка касания в глобальных координатах.
  Offset? get last => _last;

  void poke(Offset global) {
    _last = global;
    notifyListeners();
  }
}

/// Раздаёт [CoverPokes] живым обложкам ниже по дереву.
class CoverPokeScope extends InheritedWidget {
  const CoverPokeScope({super.key, required this.pokes, required super.child});

  final CoverPokes pokes;

  static CoverPokes? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CoverPokeScope>()?.pokes;

  @override
  bool updateShouldNotify(CoverPokeScope oldWidget) => oldWidget.pokes != pokes;
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
  CoverPokes? _pokes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pokes = CoverPokeScope.of(context);
    if (!identical(pokes, _pokes)) {
      _pokes?.removeListener(_onPoke);
      _pokes = pokes?..addListener(_onPoke);
    }
    _sync();
  }

  void _onPoke() {
    final g = _pokes?.last;
    if (g == null || !widget.interactive || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    _tap = box.globalToLocal(g);
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
    _pokes?.removeListener(_onPoke);
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
          // 🔴 13.11.2026: палец отпустили — касание кончилось. Без этого на
          // телефоне последняя точка жила вечно: вмятина на «Полотне», вторая
          // масса в «Притяжении», магнит в «Компасах». Мышь остаётся: над
          // сценой она «наводится», и её ведёт onHover.
          onPointerUp: (e) {
            if (e.kind != ui.PointerDeviceKind.mouse) _ptr = null;
          },
          onPointerCancel: (e) {
            if (e.kind != ui.PointerDeviceKind.mouse) _ptr = null;
          },
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
