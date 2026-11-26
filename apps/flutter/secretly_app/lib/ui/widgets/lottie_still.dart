// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui show Image, PictureRecorder;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

/// Неподвижные кадры Lottie картинками (24.11.2026, разбор подтормаживаний
/// панели стикеров и соло-эмодзи в чате).
///
/// На Impeller нет кэша растра: вектор Lottie заново строится и
/// растеризуется на каждом кадре, даже когда стоит. Замер Xiaomi 14 Pro:
/// два десятка стоящих стикеров на вкладке давали 9–10 мс растра на кадр
/// (при 120 Гц бюджет 8,3 мс) и рывки сборки до 200 мс. Картинка рисуется
/// один раз при первом показе, дальше это копия текстуры.
///
/// - кэш LRU по ключу «источник|кадр|пиксели»: не больше [capacity] картинок и
///   [maxBytes] байт (стикер в ленте — до 1,4 МБ, счёт одними штуками съел бы
///   память);
/// - каждый показ держит свой `clone()`: вытеснение из кэша не ломает уже
///   показанную картинку;
/// - отрисовка по очереди, не больше [_perFrame] за кадр, — новая страница
///   стикеров не превращается в один длинный кадр.
class LottieStillCache {
  LottieStillCache._();

  static const int capacity = 160;
  static const int maxBytes = 32 * 1024 * 1024;
  static const int _perFrame = 2;

  static final LinkedHashMap<String, ui.Image> _cache =
      LinkedHashMap<String, ui.Image>();
  static final Map<String, Future<void>> _pending = <String, Future<void>>{};
  static int _inFrame = 0;
  static int _bytes = 0;

  static int _sizeOf(ui.Image i) => i.width * i.height * 4;

  static void _drop(String key) {
    final i = _cache.remove(key);
    if (i == null) return;
    _bytes -= _sizeOf(i);
    i.dispose();
  }

  static String keyFor(String id, double progress, int px) =>
      '$id|${progress.toStringAsFixed(3)}|$px';

  /// Готовый кадр (клон — освобождает тот, кто взял) или `null`.
  static ui.Image? take(String key) {
    final hit = _cache.remove(key);
    if (hit == null) return null;
    _cache[key] = hit;
    return hit.clone();
  }

  /// Нарисовать кадр (если ещё нет) и отдать клон; `null` — не вышло.
  static Future<ui.Image?> obtain(
    LottieProvider provider,
    String key, {
    required double progress,
    required int px,
  }) async {
    final ready = take(key);
    if (ready != null) return ready;
    // Тело в скобках: `remove` вернул бы сам этот Future, а whenComplete
    // ждёт возвращённый Future — вышло бы ожидание самого себя (так 758
    // и показывала пустые стикеры).
    await (_pending[key] ??= _render(
      provider,
      key,
      progress,
      px,
    ).whenComplete(() {
      _pending.remove(key);
    }));
    return take(key);
  }

  static Future<void> _render(
    LottieProvider provider,
    String key,
    double progress,
    int px,
  ) async {
    try {
      final composition = await provider.load();
      await _slot();
      final drawable = LottieDrawable(composition)..setProgress(progress);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      drawable.draw(
        canvas,
        Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()),
        fit: BoxFit.contain,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(px, px);
      picture.dispose();
      _drop(key);
      _cache[key] = image;
      _bytes += _sizeOf(image);
      while (_cache.length > 1 &&
          (_cache.length > capacity || _bytes > maxBytes)) {
        _drop(_cache.keys.first);
      }
    } catch (_) {
      // Нет файла, битая анимация — покажем запасной вид.
    }
  }

  static Future<void> _slot() async {
    final binding = SchedulerBinding.instance;
    while (_inFrame >= _perFrame) {
      await binding.endOfFrame;
    }
    if (_inFrame++ == 0) {
      binding.addPostFrameCallback((_) => _inFrame = 0);
      binding.ensureVisualUpdate();
    }
  }

  /// Для тестов.
  @visibleForTesting
  static int get length => _cache.length;

  @visibleForTesting
  static void clear() {
    _cache.keys.toList().forEach(_drop);
  }
}

/// Кадр [progress] анимации [provider] картинкой размером [size].
/// Пока картинки нет — [fallback] (по умолчанию пусто).
class LottieStillImage extends StatefulWidget {
  const LottieStillImage({
    super.key,
    required this.provider,
    required this.id,
    required this.size,
    this.progress = 0.0,
    this.fit = BoxFit.contain,
    this.fallback,
    this.errorBuilder,
  });

  final LottieProvider provider;

  /// Постоянное имя источника для кэша (путь файла или ассета).
  final String id;
  final double size;
  final double progress;
  final BoxFit fit;
  final WidgetBuilder? fallback;

  /// Кадр не получился (нет файла, битая анимация); `null` — [fallback].
  final WidgetBuilder? errorBuilder;

  @override
  State<LottieStillImage> createState() => _LottieStillImageState();
}

class _LottieStillImageState extends State<LottieStillImage> {
  ui.Image? _image;
  String _key = '';
  bool _failed = false;

  void _resolve() {
    final px = (widget.size * MediaQuery.devicePixelRatioOf(context)).ceil();
    if (px <= 0) return;
    final key = LottieStillCache.keyFor(widget.id, widget.progress, px);
    if (key == _key) return;
    _key = key;
    _failed = false;
    final ready = LottieStillCache.take(key);
    if (ready != null) {
      _set(ready);
      return;
    }
    LottieStillCache.obtain(
      widget.provider,
      key,
      progress: widget.progress,
      px: px,
    ).then((img) {
      if (!mounted || _key != key) {
        img?.dispose();
        return;
      }
      setState(() {
        _set(img);
        _failed = img == null;
      });
    });
  }

  void _set(ui.Image? img) {
    _image?.dispose();
    _image = img;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant LottieStillImage old) {
    super.didUpdateWidget(old);
    // Другой стикер в той же клетке — прежний не показываем ни кадра.
    if (old.id != widget.id) _set(null);
    _resolve();
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: img == null
          ? ((_failed ? widget.errorBuilder : null) ??
                    widget.fallback)
                ?.call(context) ??
                const SizedBox.shrink()
          : RawImage(
              image: img,
              width: widget.size,
              height: widget.size,
              fit: widget.fit,
              filterQuality: FilterQuality.medium,
            ),
    );
  }
}
