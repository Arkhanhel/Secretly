// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// telegram_wallpaper.dart
// Telegram-style animated chat wallpaper: black background, a thin doodle
// pattern-mask, and a four-point gradient that drifts through the mask.
//
// Two motion regimes:
//  - CONTINUOUS: the 4 colour blobs drift smoothly and constantly along a closed
//    loop (a repeating controller), so it never pulses. Auto-pauses in the
//    background to save battery.
//  - DISCRETE (onEnter / tap / send / style change): a single eased "shimmer"
//    step, then a fully static frame (zero repaints — costs nothing).
//
// Vendored from the supplied `telegram_wallpaper_flutter` package and extended
// with [ChatWallpaperAnimMode] + a continuous smooth-drift mode.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'wallpaper_blur.dart';

/// How the animated wallpaper behaves in an open chat. One global setting.
enum ChatWallpaperAnimMode {
  /// Drifts smoothly and constantly on its own (auto-pauses in background).
  continuous,

  /// One shimmer when the chat opens, then static.
  onEnter,

  /// Static until you tap an empty area of the chat (driven by the chat).
  tap,

  /// Never animates — a fully static frame.
  off,
}

/// Stable string for persistence.
extension ChatWallpaperAnimModeStorage on ChatWallpaperAnimMode {
  String get storageKey => name;
}

ChatWallpaperAnimMode parseChatWallpaperAnimMode(
  String? raw, {
  ChatWallpaperAnimMode fallback = ChatWallpaperAnimMode.onEnter,
}) {
  switch (raw?.trim()) {
    case 'continuous':
      return ChatWallpaperAnimMode.continuous;
    case 'onEnter':
      return ChatWallpaperAnimMode.onEnter;
    case 'tap':
      return ChatWallpaperAnimMode.tap;
    case 'off':
      return ChatWallpaperAnimMode.off;
    default:
      return fallback;
  }
}

/// A palette: 4 colour points + blob opacity.
class WallpaperStyle {
  // colors must have exactly 4 entries (one per gradient blob).
  const WallpaperStyle(this.key, this.name, this.colors,
      {this.blobOpacity = 1.0});

  /// Stable id fragment used in the `anim:<key>` wallpaper id.
  final String key;
  final String name;
  final List<Color> colors; // exactly 4
  final double blobOpacity;
}

/// The four bundled animated styles.
///
/// Neon Dusk and Cold Steel are two-colour gradients laid out as top/bottom
/// zones — [A, A, B, B], exactly like Tempered Metal's warm/cool split — with
/// CONTRASTING hues (pink ↔ blue-violet / cyan ↔ indigo) so both colours stay
/// visible as the pair rotates clockwise, instead of blending into one tone.
/// Tempered Metal and Aurora keep the muted 4-point palettes sampled from the
/// supplied reference renders. Radius 0.66 + full opacity (see the painter).
abstract final class WallpaperStyles {
  static const neonDusk = WallpaperStyle('neon_dusk', 'Neon Dusk', [
    Color(0xFFD25F92), Color(0xFFD25F92), Color(0xFF5A55C8), Color(0xFF5A55C8),
  ]);
  static const coldSteel = WallpaperStyle('cold_steel', 'Cold Steel', [
    Color(0xFF30C0DA), Color(0xFF30C0DA), Color(0xFF4E54C2), Color(0xFF4E54C2),
  ]);
  static const temperedMetal = WallpaperStyle('tempered_metal', 'Tempered Metal', [
    Color(0xFFA69055), Color(0xFFA96842), Color(0xFF7550A0), Color(0xFF4D6198),
  ]);
  static const aurora = WallpaperStyle('aurora', 'Aurora', [
    Color(0xFF4DA27F), Color(0xFF3D95A7), Color(0xFF5382AB), Color(0xFF4264A3),
  ]);

  /// Near-black with faint lavender line-art (owner reference, 2026-08-01).
  ///
  /// The quiet one. Two close violets laid out [A, A, B, B] so the drift reads
  /// as a slow shift of one tone rather than two colours chasing each other,
  /// and a REDUCED [WallpaperStyle.blobOpacity] — the whole point of this style
  /// is that the doodles stay dim and the background stays black. At the full
  /// opacity the other four use, four additive layers saturate and it stops
  /// being a dark wallpaper.
  static const midnight = WallpaperStyle('midnight', 'Midnight', [
    Color(0xFF6E6BA8), Color(0xFF6E6BA8), Color(0xFF4A4878), Color(0xFF4A4878),
  ], blobOpacity: 0.8);

  static const all = <WallpaperStyle>[
    neonDusk,
    coldSteel,
    temperedMetal,
    aurora,
    midnight,
  ];

  static WallpaperStyle? byKey(String key) {
    for (final s in all) {
      if (s.key == key) return s;
    }
    return null;
  }
}

/// Strength of the top/bottom shading painted over every animated wallpaper.
///
/// One knob for the whole effect: 0 disables it entirely and restores the
/// previous look exactly. Kept low on purpose — this is depth under the chat
/// header and the composer, not a vignette that swallows the artwork.
const double kWallpaperEdgeShade = 0.38;

/// Bundled mask asset (thin doodle line-art on alpha).
const String kTelegramWallpaperMaskAsset = 'assets/wallpaper_fx/pattern_mask.png';

/// Запечённое поле геодезических расстояний ВДОЛЬ СЕТИ ДУДЛОВ: канал R —
/// расстояние от нижнего края, канал G — от верхнего.
///
/// Это то, что отличает «обои проводят сообщение» от бегущей полоски: волна
/// идёт по линиям узора, огибает дудлы и запаздывает в дальних углах. Поле
/// гладкое, поэтому 270x480 достаточно — ошибка восстановления ТАМ, ГДЕ ОНО
/// ЧИТАЕТСЯ (на линиях), не превышает 1/255, а весит оно 49 КБ вместо 486 КБ,
/// которых стоило бы упаковать те же данные в саму маску.
///
/// Пересобирается `tools/bake_wallpaper_field.py` — нужно ТОЛЬКО если поменялся
/// рисунок дудлов.
const String kWallpaperFieldAsset = 'assets/wallpaper_fx/pattern_field.png';

const String kWallpaperPulseShaderAsset = 'assets/shaders/wallpaper_pulse.frag';

/// Сколько летит один импульс. 1.6 с — из эталонной демонстрации: заметно, но
/// заканчивается раньше, чем успевает надоесть при живой переписке.
const Duration kWallpaperPulseDuration = Duration(milliseconds: 1600);

/// Общая сила волны. Один регулятор на весь эффект: 0 выключает его целиком и
/// возвращает прежний вид попиксельно.
const double kWallpaperPulseGain = 1.0;

/// Сколько волн может лететь одновременно.
///
/// Если писать быстро, вторая волна НЕ ЖДЁТ первую — они идут друг за другом,
/// как и выглядит поток сообщений. Четыре, а не «сколько угодно»: столько
/// помещается в один вектор uniform'а, а на экране больше четырёх фронтов уже
/// не читаются как поток и превращаются в мерцание. Пятая волна вытесняет
/// самую старую — ту, что и так почти догорела.
const int kWallpaperMaxConcurrentPulses = 4;


class TelegramWallpaper extends StatefulWidget {
  const TelegramWallpaper({
    super.key,
    this.style = WallpaperStyles.neonDusk,
    this.mask = const AssetImage(kTelegramWallpaperMaskAsset),
    this.mode = ChatWallpaperAnimMode.onEnter,
    this.conduct = false,
    this.shimmerDuration = const Duration(milliseconds: 1100),
    this.loopDuration = const Duration(seconds: 20),
    this.blurController,
  });

  final WallpaperStyle style;
  final ImageProvider mask;
  final ChatWallpaperAnimMode mode;

  /// «Обои проводят сообщение»: на отправку и на приход волна света идёт по
  /// сети дудлов — от вас вверх на исходящем, сверху к вам на входящем.
  ///
  /// Независимый переключатель, а НЕ пятый режим [ChatWallpaperAnimMode]: этот
  /// эффект событийный (кадры только пока летит импульс), а режим описывает
  /// фоновое поведение. Их можно и нужно комбинировать.
  ///
  /// Пока выключен, ни поле, ни шейдер даже не загружаются — см.
  /// [TelegramWallpaperState._ensurePulseAssets].
  final bool conduct;

  /// Контроллер «матового стекла» входящих пузырей: на каждый (троттленый)
  /// кадр анимации сюда пушится фаза, чтобы мини-текстура размытых обоев
  /// двигалась синхронно с полноэкранным painter'ом.
  final WallpaperBlurController? blurController;

  /// Duration of one eased discrete shimmer (onEnter / tap / send).
  final Duration shimmerDuration;

  /// Full-loop period for [ChatWallpaperAnimMode.continuous]: the blobs drift
  /// smoothly and constantly through the whole loop over this duration (no
  /// pulsing), then seamlessly repeat.
  final Duration loopDuration;

  @override
  State<TelegramWallpaper> createState() => TelegramWallpaperState();
}

// TickerProviderStateMixin, а НЕ Single: контроллера теперь два — дрейф и
// импульс «проводит сообщение». Они обязаны идти независимо, потому что
// событийная волна должна складываться с любым фоновым режимом, а не подменять
// его. Single бросает исключение при создании второго тикера.
class TelegramWallpaperState extends State<TelegramWallpaper>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // A closed 8-anchor loop (fractions of width/height); the colour blobs walk it
  // — continuously in continuous mode, or one eased step per discrete shimmer.
  static const _loop = <Offset>[
    Offset(0.18, 0.10), Offset(0.55, 0.06), Offset(0.86, 0.24),
    Offset(0.92, 0.60), Offset(0.80, 0.90), Offset(0.45, 0.94),
    Offset(0.12, 0.78), Offset(0.06, 0.40),
  ];

  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.shimmerDuration);
  // Ever-increasing step counter (indexed mod _loop.length). During a discrete
  // shimmer the phase eases from _prevStep to _step.
  int _step = 0, _prevStep = 0;
  ui.Image? _maskImage;
  ImageStreamListener? _listener;
  ImageStream? _stream;
  bool _appActive = true;

  // ── «Обои проводят сообщение» ─────────────────────────────────────────────
  // Свой тикер, а не AnimationController: волн бывает несколько сразу, у каждой
  // своя фаза и своё направление. Один контроллер на всех означал бы, что
  // вторая волна ждёт первую — ровно то, чего быть не должно.
  Ticker? _pulseTicker;
  Duration _pulseClock = Duration.zero;
  final List<_ConductPulse> _pulses = <_ConductPulse>[];
  ui.Image? _fieldImage;
  ImageStream? _fieldStream;
  ImageStreamListener? _fieldListener;
  ui.FragmentShader? _pulseShader;
  bool _pulseAssetsRequested = false;

  /// Программа шейдера одна на всё приложение: экземпляров обоев может быть
  /// несколько (чат + предпросмотр), компилировать её каждому незачем.
  static Future<ui.FragmentProgram>? _pulseProgramFuture;

  bool get _continuous => widget.mode == ChatWallpaperAnimMode.continuous;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyMode();
    if (widget.conduct) _ensurePulseAssets();
  }

  /// Грузит поле и шейдер — ОДИН раз и только если эффект включён.
  ///
  /// Выключенный эффект не стоит ничего: ни 49 КБ декода, ни компиляции
  /// шейдера, ни лишней текстуры в памяти. Именно поэтому это отдельный
  /// переключатель, а не всегда живой слой с нулевой яркостью.
  ///
  /// НАПРАВЛЕНИЕ ОТКАЗА: любой сбой оставляет [_pulseShader] или [_fieldImage]
  /// пустыми, а painter в этом случае просто не рисует слой — обои остаются
  /// ровно такими, какими были до этой правки, без исключений в UI.
  void _ensurePulseAssets() {
    if (_pulseAssetsRequested) return;
    _pulseAssetsRequested = true;

    _pulseProgramFuture ??= ui.FragmentProgram.fromAsset(
      kWallpaperPulseShaderAsset,
    );
    _pulseProgramFuture!.then((program) {
      if (!mounted) return;
      setState(() => _pulseShader = program.fragmentShader());
    }).catchError((Object error) {
      if (!kReleaseMode) {
        debugPrint('TelegramWallpaper: pulse shader unavailable: $error');
      }
    });

    // Поле читается шейдером как текстура, поэтому нужен именно ui.Image.
    // Ссылки на поток и слушателя держим, чтобы снять его в dispose: этот
    // виджет уже наступал на грабли накопления слушателей у маски.
    _fieldListener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() => _fieldImage = info.image);
      },
      onError: (error, _) {
        if (!kReleaseMode) {
          debugPrint('TelegramWallpaper: field asset failed: $error');
        }
      },
    );
    _fieldStream = const AssetImage(
      kWallpaperFieldAsset,
    ).resolve(const ImageConfiguration());
    _fieldStream!.addListener(_fieldListener!);
  }

  /// Провести сообщение через фон: [incoming] — свет стекает сверху к вам,
  /// иначе уходит от вас вверх.
  ///
  /// Новая волна НЕ ЖДЁТ предыдущую: если писать быстро, они идут друг за
  /// другом. Единственное ограничение — [kWallpaperMaxConcurrentPulses]: пятая
  /// волна вытесняет самую старую, ту, что и так почти догорела.
  ///
  /// Никакого «минимального зазора» между волнами СОЗНАТЕЛЬНО нет. Он выглядел
  /// экономией, но ею не был: шейдер всё равно считает все четыре слота на
  /// каждый пиксель, поэтому лишняя волна не стоит ни одной лишней операции на
  /// GPU. Зато зазор ровно и давал то, на что пожаловались, — «пишешь быстро,
  /// а анимации нет».
  void conductMessage({required bool incoming}) {
    if (!mounted || !widget.conduct || !_appActive) return;
    // Системное «меньше движения». Бегущая по экрану волна — ровно тот вид
    // движения, ради которого эту настройку и включают; сюда она относится
    // сильнее, чем к любой другой анимации в приложении.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;

    _ensurePulseAssets();
    if (_pulses.length >= kWallpaperMaxConcurrentPulses) {
      _pulses.removeAt(0);
    }
    _pulses.add(_ConductPulse(dirTop: incoming ? 1 : 0));
    _startPulseTicker();
  }

  void _startPulseTicker() {
    if (_pulses.isEmpty) return;
    _pulseTicker ??= createTicker(_onPulseTick);
    if (!_pulseTicker!.isActive) {
      _pulseClock = Duration.zero;
      _pulseTicker!.start();
    }
  }

  void _onPulseTick(Duration elapsed) {
    final dtUs = (elapsed - _pulseClock).inMicroseconds.toDouble();
    _pulseClock = elapsed;
    if (dtUs <= 0) return;

    final lifeUs = kWallpaperPulseDuration.inMicroseconds.toDouble();
    _pulses.removeWhere((p) => p.advance(dtUs, lifeUs));
    if (_pulses.isEmpty) {
      // Догорели все — тикер останавливается, дальше полная статика и ноль
      // кадров. Именно это делает эффект дешёвым.
      _pulseTicker?.stop();
    }
    if (mounted) setState(() {});
  }

  void _stopAllPulses() {
    if (_pulses.isEmpty && _pulseTicker?.isActive != true) return;
    _pulses.clear();
    _pulseTicker?.stop();
    if (mounted) setState(() {});
  }

  /// Летит ли сейчас волна. Швы для тестов: без них поведение проверяется
  /// только глазами, а именно этот эффект обязан МОЛЧАТЬ в большинстве
  /// ситуаций — а молчание глазами не проверишь.
  @visibleForTesting
  bool get isConducting => _pulses.isNotEmpty;

  /// Сколько волн летит прямо сейчас.
  @visibleForTesting
  int get conductingCount => _pulses.length;

  /// Направление ПОСЛЕДНЕЙ заведённой волны: 1 — сверху вниз, 0 — вверх.
  @visibleForTesting
  double get conductDirTop => _pulses.isEmpty ? 0 : _pulses.last.dirTop;

  /// Запрашивались ли уже поле и шейдер. Пока эффект выключен, обязано быть
  /// false — это и есть «выключенный не платит ничем».
  @visibleForTesting
  bool get pulseAssetsRequested => _pulseAssetsRequested;

  // 🔴 The mask is resolved HERE, not in initState: sizing it to the screen
  // needs MediaQuery, and reading an inherited widget from initState is not
  // allowed (it registers no dependency and asserts in debug). This is also
  // the callback that fires if the device metrics change, so a rotation or a
  // window resize re-resolves at the new width instead of keeping a stale one.
  bool _maskResolvedForSize = false;
  Size? _lastMaskSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.maybeOf(context);
    final size = media?.size;
    if (_maskResolvedForSize && size == _lastMaskSize) return;
    _maskResolvedForSize = true;
    _lastMaskSize = size;
    _resolveMask();
  }

  void _applyMode() {
    if (_continuous) {
      _c.duration = widget.loopDuration;
      if (_appActive) {
        _c.repeat(); // constant, smooth drift — no pulsing
      } else {
        _c.stop();
      }
    } else {
      _c.stop();
      _c.duration = widget.shimmerDuration;
      _c.value = 0; // settled static frame
      if (widget.mode != ChatWallpaperAnimMode.off) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_continuous) shimmer();
        });
      }
    }
  }

  void _resolveMask() {
    // MEMORY (2026-08-01): the mask asset is 1620x2880 — 17.8 MB decoded at
    // full size, held for as long as a chat is open. It is only ever painted
    // across the screen, so decoding wider than the screen buys nothing and
    // costs megabytes. `allowUpscaling: false` keeps a narrower device from
    // inflating it.
    //
    // Resolved HERE rather than in the constructor because the target size
    // depends on the device, and the constructor is const.
    final media = MediaQuery.maybeOf(context);
    final targetWidth = media == null
        ? null
        : (media.size.width * media.devicePixelRatio).round().clamp(360, 2160);
    final provider = targetWidth == null
        ? widget.mask
        : ResizeImage(widget.mask, width: targetWidth, allowUpscaling: false);
    // Re-resolving (rotation) must not leave the old stream listening, or the
    // widget accumulates a listener per orientation change for its lifetime.
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener(
      (info, _) {
        if (mounted) setState(() => _maskImage = info.image);
      },
      onError: (exception, stackTrace) {
        // Missing/undecodable mask asset: keep _maskImage null so the painter
        // falls back to the soft gradient instead of a flat black rectangle.
        if (!kReleaseMode) {
          debugPrint('TelegramWallpaper: mask failed to load: $exception');
        }
      },
    );
    _stream!.addListener(_listener!);
  }

  /// One eased discrete shimmer step. Called on appear, tap and by the chat on
  /// send / style change. No-op in continuous mode (which drifts on its own).
  void shimmer() {
    if (!mounted || _continuous) return;
    setState(() {
      _prevStep = _step;
      _step += 1;
    });
    _c.forward(from: 0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    if (!active) {
      // Кадры импульса в фоне — чистая потеря батареи: их никто не увидит, а
      // рисуются они на том же GPU. Гасим ВСЕ летящие волны мгновенно, а не
      // ждём, пока догорят.
      _stopAllPulses();
    }
    if (_continuous) {
      // Pause the constant drift in the background, resume in foreground.
      active ? _c.repeat() : _c.stop();
    }
  }

  @override
  void didUpdateWidget(covariant TelegramWallpaper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mask != widget.mask) {
      if (_listener != null) _stream?.removeListener(_listener!);
      _resolveMask();
    }
    if (oldWidget.conduct != widget.conduct) {
      if (widget.conduct) {
        _ensurePulseAssets();
      } else {
        // Эффект выключили посреди волны — гасим сейчас, а не «когда долетит».
        _stopAllPulses();
      }
    }
    if (oldWidget.mode != widget.mode) {
      _applyMode();
    } else if (oldWidget.style != widget.style && !_continuous) {
      shimmer(); // style change — shimmer (discrete modes only)
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_listener != null) _stream?.removeListener(_listener!);
    if (_fieldListener != null) _fieldStream?.removeListener(_fieldListener!);
    _c.dispose();
    _pulseTicker?.dispose();
    // Шейдер держит GPU-ресурс: экземпляр наш, программа общая.
    _pulseShader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Дрейф идёт контроллером, волны — своим тикером (он дёргает setState).
      animation: _c,
      builder: (_, __) {
        // Continuous: phase runs 0→loop.length and wraps seamlessly. Discrete:
        // phase eases from _prevStep to _step over the shimmer.
        //
        // In continuous mode the phase is quantised to ~30fps: the controller
        // still ticks at display refresh, but the painter's shouldRepaint
        // (old.phase != phase) then skips the expensive full-canvas blend +
        // saveLayer + mask on the in-between frames. For a slow ~20s drift this
        // is visually identical to 60fps but roughly halves the per-frame GPU
        // cost. The short discrete shimmer keeps full smoothness.
        final double phase;
        if (_continuous) {
          final int steps =
              (widget.loopDuration.inMilliseconds ~/ 33).clamp(1, 100000);
          final double quantized = (_c.value * steps).floorToDouble() / steps;
          phase = quantized * _loop.length;
        } else {
          phase = _prevStep + Curves.easeInOutCubic.transform(_c.value);
        }
        // Кадр для стекла пузырей (контроллер сам троттлит до ~30 к/с и
        // отсекает повторы фазы; нотификация уходит микротаском после build).
        widget.blurController?.pushAnimatedFrame(
          colors: widget.style.colors,
          blobOpacity: widget.style.blobOpacity,
          loop: _loop,
          phase: phase,
        );
        // Пустой список — painter не рисует слой ВООБЩЕ: обои остаются
        // попиксельно теми же, какими были до появления этой фичи.
        // Пустой список — ОДИН И ТОТ ЖЕ const-объект, чтобы shouldRepaint по
        // identical давал false и обои в покое не перерисовывались вообще.
        final pulses = (widget.conduct && _pulses.isNotEmpty)
            ? <_ConductPulse>[..._pulses]
            : const <_ConductPulse>[];

        return CustomPaint(
          size: Size.infinite,
          painter: _WallpaperPainter(
            mask: _maskImage,
            style: widget.style,
            loop: _loop,
            phase: phase,
            pulses: pulses,
            pulseShader: _pulseShader,
            field: _fieldImage,
          ),
        );
      },
    );
  }
}

/// Одна летящая волна. Живёт от 0 до 1 по своему возрасту, дальше умирает.
class _ConductPulse {
  _ConductPulse({required this.dirTop});

  /// 0 — свет идёт снизу вверх (исходящее), 1 — сверху вниз (входящее).
  final double dirTop;

  /// Возраст в микросекундах. Считается с ПЕРВОГО кадра после создания:
  /// Ticker по устройству сообщает elapsed = 0 в свой первый вызов, и это
  /// правильно — волна начинает лететь с первого нарисованного кадра.
  double ageUs = 0;

  double _k = 0;

  /// Продвигает волну; возвращает true, когда она догорела и её пора убрать.
  bool advance(double dtUs, double lifeUs) {
    ageUs += dtUs;
    _k = lifeUs <= 0 ? 1 : (ageUs / lifeUs);
    return _k >= 1;
  }

  /// Положение фронта, 0 → 1.35.
  ///
  /// Разгон у источника и замедление вдали (1-(1-k)^2.2) — так волна читается
  /// как ушедшая далеко, а не как равномерно ползущая полоса. Дотягиваем до
  /// 1.35, а не до 1.0: хвост обязан догореть за краем поля, иначе волна
  /// обрывается ровно в тот момент, когда на неё смотрят.
  double get position {
    final k = _k.clamp(0.0, 1.0);
    return (1 - math.pow(1 - k, 2.2).toDouble()) * 1.35;
  }
}

class _WallpaperPainter extends CustomPainter {
  _WallpaperPainter({
    required this.mask,
    required this.style,
    required this.loop,
    required this.phase,
    this.pulses = const <_ConductPulse>[],
    this.pulseShader,
    this.field,
  });

  final ui.Image? mask;
  final WallpaperStyle style;
  final List<Offset> loop;
  final double phase;

  /// Летящие волны — до [kWallpaperMaxConcurrentPulses] штук. Пусто = слой не
  /// рисуется вовсе.
  final List<_ConductPulse> pulses;

  final ui.FragmentShader? pulseShader;
  final ui.Image? field;

  bool get _pulseActive =>
      pulses.isNotEmpty && pulseShader != null && field != null;

  // Continuous position of [blob] along the loop at the current phase (linear
  // between anchors → constant velocity → smooth). Shared with the bubble-glass
  // mini-texture so the two renders stay in lockstep.
  Offset _anchor(int blob, Size size) =>
      wallpaperLoopAnchor(loop: loop, phase: phase, blob: blob, size: size);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Colors.black);

    // Layer: additive colour blobs, then — if the mask asset is available — the
    // pattern mask via dstIn so only the doodle lines keep the gradient. If the
    // mask hasn't loaded (or wasn't bundled) we still render the soft gradient
    // so the wallpaper is never a flat black rectangle.
    final img = mask;
    canvas.saveLayer(rect, Paint());
    // 0.66 balances full-canvas coverage (doodles tinted everywhere, like the
    // reference) with regional variation (warmer/cooler per corner). Larger →
    // one uniform wash; much smaller → dark, uncovered middle.
    final radius = size.longestSide * 0.66;
    for (var i = 0; i < 4; i++) {
      final pos = _anchor(i, size);
      final color = style.colors[i];
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(pos, radius, [
            color.withValues(alpha: style.blobOpacity),
            color.withValues(alpha: 0),
          ], const [0.0, 1.0]),
      );
    }

    // «Обои проводят сообщение»: прибавка света вдоль сети дудлов.
    //
    // 🔴 Рисуется ЗДЕСЬ — после пятен, но ДО маски — намеренно. Маска `dstIn`
    // ниже оставляет только линии узора, поэтому волна обрезается по дудлам
    // сама собой, без второго прохода. Нарисуй мы её после `restore`, свет
    // разлился бы по всему экрану сплошной полосой, и вся физика пропала бы.
    if (_pulseActive) {
      final fieldImage = field!;
      final shader = pulseShader!;
      // Поле обязано читаться той же математикой «cover», что и маска, иначе
      // волна поедет относительно линий, вдоль которых она идёт.
      final src = _coverSrc(fieldImage, size);
      final fw = fieldImage.width.toDouble();
      final fh = fieldImage.height.toDouble();
      final count = pulses.length.clamp(0, kWallpaperMaxConcurrentPulses);
      double posAt(int i) => i < count ? pulses[i].position : 0.0;
      double dirAt(int i) => i < count ? pulses[i].dirTop : 0.0;
      shader
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, src.width / fw)
        ..setFloat(3, src.height / fh)
        ..setFloat(4, src.left / fw)
        ..setFloat(5, src.top / fh)
        ..setFloat(6, count.toDouble())
        ..setFloat(7, posAt(0))
        ..setFloat(8, posAt(1))
        ..setFloat(9, posAt(2))
        ..setFloat(10, posAt(3))
        ..setFloat(11, dirAt(0))
        ..setFloat(12, dirAt(1))
        ..setFloat(13, dirAt(2))
        ..setFloat(14, dirAt(3))
        ..setFloat(15, kWallpaperPulseGain)
        ..setFloat(16, _tint.r)
        ..setFloat(17, _tint.g)
        ..setFloat(18, _tint.b)
        ..setImageSampler(0, fieldImage);
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = shader,
      );
    }

    if (img != null) {
      // Pattern mask over the blobs: only the lines remain (cover fill).
      final src = _coverSrc(img, size);
      canvas.drawImageRect(
        img, src, rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..filterQuality = FilterQuality.medium,
      );
    }
    canvas.restore();

    // Top/bottom shading (owner request, 2026-08-01).
    //
    // 🔴 Drawn AFTER `restore` on purpose. Inside the layer the `dstIn` mask
    // above keeps only the doodle lines, so a gradient painted there would be
    // masked away with everything else — it has to sit on the finished
    // wallpaper.
    //
    // Deliberately a plain `srcOver` gradient rather than anything additive:
    // everything above this line is built with `BlendMode.plus`, which is the
    // operation most sensitive to the renderer's colour space, and is the
    // suspect behind "on iOS I barely see the shading". An ordinary dark
    // gradient composites identically on both backends, so the depth is
    // DESIGNED instead of emerging from wherever the blobs happened not to
    // reach.
    //
    // The middle is left untouched so message text never sits on a gradient.
    if (kWallpaperEdgeShade > 0) {
      final shade = Colors.black.withValues(alpha: kWallpaperEdgeShade);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(rect.center.dx, rect.top),
            Offset(rect.center.dx, rect.bottom),
            [shade, const Color(0x00000000), const Color(0x00000000), shade],
            const [0.0, 0.16, 0.84, 1.0],
          ),
      );
    }
  }

  /// Прямоугольник-источник для отрисовки [image] «по покрытию» в [size] —
  /// одна математика для маски и для поля, чтобы они не разъезжались.
  static Rect _coverSrc(ui.Image image, Size size) {
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    final scale = (size.width / iw) > (size.height / ih)
        ? size.width / iw
        : size.height / ih;
    final srcW = size.width / scale, srcH = size.height / scale;
    return Rect.fromLTWH((iw - srcW) / 2, (ih - srcH) / 2, srcW, srcH);
  }

  /// Цвет волны вдали от ядра: средний тон палитры, подтянутый к белому.
  ///
  /// Берётся из стиля, а не задаётся константой, чтобы у каждых обоев свет был
  /// своим — иначе один и тот же белый импульс на пяти палитрах выглядит
  /// приклеенным сверху, а не растущим из самих обоев.
  Color get _tint {
    var r = 0.0, g = 0.0, b = 0.0;
    for (final c in style.colors) {
      r += c.r;
      g += c.g;
      b += c.b;
    }
    final n = style.colors.length.clamp(1, 100);
    return Color.from(
      alpha: 1,
      red: (r / n * 0.45 + 0.55).clamp(0.0, 1.0),
      green: (g / n * 0.45 + 0.55).clamp(0.0, 1.0),
      blue: (b / n * 0.45 + 0.55).clamp(0.0, 1.0),
    );
  }

  @override
  bool shouldRepaint(_WallpaperPainter old) =>
      old.phase != phase ||
      old.mask != mask ||
      old.style != style ||
      !identical(old.pulses, pulses) ||
      old.pulseShader != pulseShader ||
      old.field != field;
}
