// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// wallpaper_blur.dart
//
// «Матовое стекло» входящих пузырей — подход Telegram iOS.
//
// Telegram НЕ делает настоящий backdrop-blur на каждый пузырь (это saveLayer
// на элемент списка и падение FPS; в этом приложении он к тому же принципиально
// не работает — таймлайн живёт внутри edge-fade ShaderMask, чей saveLayer
// изолирует backdrop-сэмплинг). Вместо этого:
//
//  1. Обои ОДИН раз рендерятся в крошечную текстуру (даунскейл ~16×), к ней
//     применяется blur + буст насыщенности; результат кэшируется здесь.
//  2. Каждый входящий пузырь — «окно» в эту общую текстуру: он рисует участок,
//     соответствующий его глобальной позиции (текстура привязана к вьюпорту).
//  3. Поверх участка — полупрозрачная серая заливка, затем контент.
//  4. При скролле ничего не переразмывается — меняется только смещение выборки.
//
// Сам painter «окна» живёт рядом с пузырями в chat_screen.dart
// (_FrostedWindowPainter) и переиспользует механизм привязки к вьюпорту
// исходящих градиентных пузырей (_BubbleGradientResolver).

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Все параметры эффекта в одном месте — единая точка тюнинга.
class WallpaperBlurConfig {
  // Тюнинг 2026-07-05/06 (анимированные обои).
  // Полный разбор артефактов стекла:
  //  • «кружки» = слишком яркие цветовые пятна anim-обоев → animGlow 0.34→0.28
  //    и blurSigma 40→46;
  //  • «соты»/сетка = билинейный апскейл мини-текстуры (тенты интерполяции)
  //    + отсутствие пре-блюра у anim-кадров → бикубическая выборка окна
  //    (_FrostedWindowPainter) + пре-блюр textureSigma в pushAnimatedFrame;
  //  • заливка тёмной темы плотнее: #282830 55%→61% (0x8D→0x9C) — глубже
  //    матовость, отражение фона мягче.
  const WallpaperBlurConfig({
    this.blurSigma = 46.0,
    this.saturation = 1.5,
    this.downscaleFactor = 16.0,
    this.darkTint = const Color(0x9C282830),
    this.lightTint = const Color(0x9AFFFFFF),
    this.animGlow = 0.28,
    this.maxTextureDimension = 256,
    this.animFrameThrottle = const Duration(milliseconds: 33),
  });

  /// Сигма блюра в ФИЗИЧЕСКИХ пикселях полного разрешения (эквивалент
  /// telegram-овских ~30–50px); к мини-текстуре применяется
  /// [textureSigma] = blurSigma / downscaleFactor.
  final double blurSigma;

  /// Буст насыщенности размытых обоев (1.0 = без изменения).
  final double saturation;

  /// Во сколько раз мини-текстура меньше вьюпорта в физических пикселях.
  final double downscaleFactor;

  /// Серая полупрозрачная заливка пузыря в тёмной теме — rgba(40,40,48,0.5),
  /// как в Telegram iOS.
  final Color darkTint;

  /// Светлая заливка в светлой теме — rgba(255,255,255,~0.55).
  final Color lightTint;

  /// Яркость синтетических цветовых пятен для `anim:`-обоев: дудл-маска
  /// в среднем гасит цвет примерно до трети, это её эквивалент после блюра.
  final double animGlow;

  /// Страховка на размер текстуры (длинная сторона, px).
  final int maxTextureDimension;

  /// Минимальный интервал перерисовки мини-текстуры для анимированных обоев
  /// (~30 к/с; сам битмап крошечный, это дёшево).
  final Duration animFrameThrottle;

  double get textureSigma => blurSigma / downscaleFactor;
}

const WallpaperBlurConfig kWallpaperBlurConfig = WallpaperBlurConfig();

/// Позиция цветового пятна анимированных обоев на замкнутой петле — общая
/// математика для полноэкранного painter'а (telegram_wallpaper.dart) и
/// синтетического мини-рендера здесь. Формулы обязаны совпадать, иначе
/// подкраска пузырей разъедется с обоями.
Offset wallpaperLoopAnchor({
  required List<Offset> loop,
  required double phase,
  required int blob,
  required Size size,
}) {
  final base = phase + blob * 2.0;
  final i = base.floor();
  final f = base - i;
  final p = Offset.lerp(
    loop[i % loop.length],
    loop[(i + 1) % loop.length],
    f,
  )!;
  return Offset(p.dx * size.width, p.dy * size.height);
}

/// Матрица ColorFilter для насыщенности (стандартные лума-коэффициенты).
List<double> saturationColorMatrix(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final inv = 1.0 - s;
  final r = inv * lr, g = inv * lg, b = inv * lb;
  return <double>[
    r + s, g, b, 0, 0, //
    r, g + s, b, 0, 0, //
    r, g, b + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// Готовит и кэширует ОДНУ маленькую размытую текстуру обоев на весь чат.
///
/// Painter'ы пузырей подписываются на контроллер (repaint) и читают [texture].
/// Пересоздание — только при смене обоев / темы / размера вьюпорта (ключ
/// дедупликации внутри) или на троттленом кадре анимированных обоев.
class WallpaperBlurController extends ChangeNotifier {
  WallpaperBlurController({this.config = kWallpaperBlurConfig});

  final WallpaperBlurConfig config;

  ui.Image? _texture;

  /// Текущая размытая мини-текстура. Покрывает весь вьюпорт (cover),
  /// null — пока первая ещё готовится (пузыри рисуют фолбэк-плиту).
  ui.Image? get texture => _texture;

  Object? _syncKey;
  int _generation = 0;
  Size _viewportSize = Size.zero;
  double _dpr = 1.0;
  bool _animated = false;
  bool _disposed = false;
  bool _notifyScheduled = false;

  double? _lastAnimPhase;
  int _lastAnimFrameMs = 0;
  Timer? _animTrailingTimer;
  ({List<Color> colors, double blobOpacity, List<Offset> loop, double phase})?
  _pendingAnim;

  /// Обычные (статичные) обои из картинки: asset / file / server-файл.
  /// Асинхронно: даунскейл-декод → blur + saturation → toImageSync.
  void configureStill({
    required Object cacheKey,
    required ImageProvider provider,
    required Size viewportSize,
    required double devicePixelRatio,
  }) {
    if (!_configure(
      ('still', cacheKey),
      viewportSize,
      devicePixelRatio,
      animated: false,
    )) {
      return;
    }
    final gen = _generation;
    final (texW, _) = _textureSize();
    _decode(provider, math.max(64, texW * 2)).then((src) {
      if (_disposed || gen != _generation) {
        src?.dispose();
        return;
      }
      // Декод не удался — держим прежнюю текстуру (или фолбэк-плиту).
      if (src == null) return;
      final image = _renderStill(src);
      src.dispose();
      _swapTexture(image);
    });
  }

  /// Однотонные/градиентные обои ('default' / 'midnight'): блюр не нужен,
  /// текстура — тот же диагональный градиент, что рисует фон чата.
  void configureGradient({
    required Object cacheKey,
    required List<Color> colors,
    required Size viewportSize,
    required double devicePixelRatio,
  }) {
    if (colors.isEmpty) return;
    if (!_configure(
      ('gradient', cacheKey),
      viewportSize,
      devicePixelRatio,
      animated: false,
    )) {
      return;
    }
    final (texW, texH) = _textureSize();
    final rect = Rect.fromLTWH(0, 0, texW.toDouble(), texH.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      rect,
      ui.Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.length == 1
              ? <Color>[colors.first, colors.first]
              : colors,
        ).createShader(rect),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(texW, texH);
    picture.dispose();
    _swapTexture(image);
  }

  /// Анимированные обои (`anim:<style>`): кадры приходят снаружи через
  /// [pushAnimatedFrame] (их пушит TelegramWallpaper из своего билдера).
  void configureAnimated({
    required Object cacheKey,
    required Size viewportSize,
    required double devicePixelRatio,
  }) {
    if (_configure(
      ('anim', cacheKey),
      viewportSize,
      devicePixelRatio,
      animated: true,
    )) {
      _lastAnimPhase = null;
      _lastAnimFrameMs = 0;
      _pendingAnim = null;
      _animTrailingTimer?.cancel();
      _animTrailingTimer = null;
    }
  }

  /// Троттленый (≈30 к/с) синтетический кадр анимированных обоев: чёрный фон +
  /// 4 цветовых пятна на тех же позициях петли, что и у полноэкранного
  /// painter'а. Дудл-маску не рендерим: после 16× даунскейла + блюра от неё
  /// остаётся только общее приглушение цвета — его даёт [WallpaperBlurConfig.animGlow].
  void pushAnimatedFrame({
    required List<Color> colors,
    required double blobOpacity,
    required List<Offset> loop,
    required double phase,
  }) {
    if (_disposed || !_animated || _viewportSize.isEmpty) return;
    if (phase == _lastAnimPhase) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final waitMs =
        _lastAnimFrameMs + config.animFrameThrottle.inMilliseconds - nowMs;
    if (_lastAnimPhase != null && waitMs > 0) {
      // Трейлинг-кадр: последний шаг анимации не должен потеряться из-за
      // троттлинга, иначе подкраска пузырей замрёт на пол-шага от обоев.
      _pendingAnim = (
        colors: colors,
        blobOpacity: blobOpacity,
        loop: loop,
        phase: phase,
      );
      _animTrailingTimer ??= Timer(Duration(milliseconds: waitMs), () {
        _animTrailingTimer = null;
        final pending = _pendingAnim;
        _pendingAnim = null;
        if (pending != null && !_disposed) {
          pushAnimatedFrame(
            colors: pending.colors,
            blobOpacity: pending.blobOpacity,
            loop: pending.loop,
            phase: pending.phase,
          );
        }
      });
      return;
    }
    _pendingAnim = null;
    _lastAnimPhase = phase;
    _lastAnimFrameMs = nowMs;

    final (texW, texH) = _textureSize();
    final rect = Rect.fromLTWH(0, 0, texW.toDouble(), texH.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(rect, ui.Paint()..color = const Color(0xFF000000));
    canvas.saveLayer(
      rect,
      ui.Paint()
        // Пре-блюр как у статичных обоев: радиальные пятна и так гладкие,
        // но БЕЗ него шаги между соседними текселями оставались достаточно
        // крупными, чтобы билинейный/бикубический апскейл в пузыре читался
        // как сетка («соты»). Текстура крошечная и кадр ≤30 к/с — дёшево.
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: config.textureSigma,
          sigmaY: config.textureSigma,
          tileMode: TileMode.clamp,
        )
        ..colorFilter = ColorFilter.matrix(
          saturationColorMatrix(config.saturation),
        ),
    );
    final radius = rect.longestSide * 0.66;
    for (var i = 0; i < 4 && i < colors.length; i++) {
      final pos = wallpaperLoopAnchor(
        loop: loop,
        phase: phase,
        blob: i,
        size: rect.size,
      );
      canvas.drawRect(
        rect,
        ui.Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(pos, radius, <Color>[
            colors[i].withValues(alpha: blobOpacity * config.animGlow),
            colors[i].withValues(alpha: 0.0),
          ], const <double>[0.0, 1.0]),
      );
    }
    canvas.restore();
    final picture = recorder.endRecording();
    final image = picture.toImageSync(texW, texH);
    picture.dispose();
    _swapTexture(image);
  }

  bool _configure(
    Object cacheKey,
    Size viewportSize,
    double devicePixelRatio, {
    required bool animated,
  }) {
    if (viewportSize.isEmpty) return false;
    final key = (
      cacheKey,
      viewportSize.width.roundToDouble(),
      viewportSize.height.roundToDouble(),
      devicePixelRatio,
      animated,
    );
    if (_syncKey == key) return false;
    _syncKey = key;
    _viewportSize = viewportSize;
    _dpr = devicePixelRatio;
    _animated = animated;
    _generation++;
    // Старую текстуру намеренно держим до готовности новой — смена обоев/темы
    // проходит без мигания фолбэк-плитой.
    return true;
  }

  (int, int) _textureSize() {
    final scale = 1.0 / config.downscaleFactor;
    var w = (_viewportSize.width * _dpr * scale).round();
    var h = (_viewportSize.height * _dpr * scale).round();
    final longest = math.max(w, h);
    if (longest > config.maxTextureDimension) {
      final k = config.maxTextureDimension / longest;
      w = (w * k).round();
      h = (h * k).round();
    }
    return (math.max(8, w), math.max(8, h));
  }

  Future<ui.Image?> _decode(ImageProvider provider, int targetWidth) {
    final completer = Completer<ui.Image?>();
    // Даунскейл на этапе декода: полноразмерная картинка в память не попадает.
    final stream = ResizeImage.resizeIfNeeded(
      targetWidth,
      null,
      provider,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        stream.removeListener(listener);
        final image = info.image.clone();
        info.dispose();
        if (completer.isCompleted) {
          image.dispose();
          return;
        }
        completer.complete(image);
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!kReleaseMode) {
          debugPrint('WallpaperBlurController: decode failed: $error');
        }
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  ui.Image _renderStill(ui.Image src) {
    final (texW, texH) = _textureSize();
    final rect = Rect.fromLTWH(0, 0, texW.toDouble(), texH.toDouble());
    final sigma = config.textureSigma;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    // Blur + saturation одним saveLayer; исходник рисуется cover-фитом в
    // прямоугольник, раздутый на 2σ, чтобы блюр не темнил края текстуры.
    canvas.saveLayer(
      rect,
      ui.Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: ui.TileMode.clamp,
        )
        ..colorFilter = ColorFilter.matrix(
          saturationColorMatrix(config.saturation),
        ),
    );
    final dst = rect.inflate(sigma * 2);
    final sw = src.width.toDouble(), sh = src.height.toDouble();
    final coverScale = math.max(dst.width / sw, dst.height / sh);
    final srcW = dst.width / coverScale, srcH = dst.height / coverScale;
    canvas.drawImageRect(
      src,
      Rect.fromLTWH((sw - srcW) / 2, (sh - srcH) / 2, srcW, srcH),
      dst,
      ui.Paint()..filterQuality = FilterQuality.low,
    );
    canvas.restore();
    final picture = recorder.endRecording();
    final image = picture.toImageSync(texW, texH);
    picture.dispose();
    return image;
  }

  void _swapTexture(ui.Image image) {
    final old = _texture;
    _texture = image;
    old?.dispose();
    _notifySoon();
  }

  // pushAnimatedFrame зовётся из билдера виджета обоев (фаза build) —
  // notifyListeners откладываем в микротаск, чтобы не дёргать markNeedsPaint
  // подписанных painter'ов посреди построения дерева.
  void _notifySoon() {
    if (_notifyScheduled || _disposed) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _animTrailingTimer?.cancel();
    _animTrailingTimer = null;
    _pendingAnim = null;
    _texture?.dispose();
    _texture = null;
    super.dispose();
  }
}
