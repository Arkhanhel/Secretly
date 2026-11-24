// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// М7: счётчик кадров на устройстве (docs/TZ_MOTION_TELEGRAM_PARITY_
/// 2026-11-20.md). Включается только сборкой с
/// `--dart-define=SECRETLY_FRAME_STATS=true` — в обычных сборках его нет
/// совсем (константа времени сборки).
///
/// Раз в 5 секунд пишет в журнал (`[FrameStats]`): сколько кадров, сколько
/// превысили бюджет экрана (8,3 мс при 120 Гц, 16,7 мс при 60 Гц), 50/90/99-й
/// процентили и худший кадр — отдельно сборка (UI-поток) и отрисовка
/// (растр). Данные — `FrameTiming` движка, то есть ровно то, что видит
/// человек, без отладочных надстроек.
library;

import 'dart:ui' show FramePhase, FrameTiming, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

const bool kFrameStats = bool.fromEnvironment('SECRETLY_FRAME_STATS');

abstract final class FrameStats {
  static final List<FrameTiming> _window = <FrameTiming>[];
  static bool _started = false;
  static DateTime _windowStart = DateTime.now();

  /// Подключить сбор. Ничего не делает, если сборка без флага.
  static void start() {
    if (!kFrameStats || _started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    _window.addAll(timings);
    final now = DateTime.now();
    if (now.difference(_windowStart) < const Duration(seconds: 5)) return;
    _windowStart = now;
    if (_window.isEmpty) return;
    // Частота — по самим кадрам: `display.refreshRate` Flutter узнаёт при
    // старте и не обновляет, а Xiaomi/HyperOS переключает 120↔60 на ходу
    // (низкая яркость, «умная» частота) — журнал врал «hz=60» при 120 к/с.
    final report = summarize(
      _window,
      refreshRate: measuredRefreshRate(_window) ?? _refreshRate(),
    );
    _window.clear();
    debugPrint('[FrameStats] $report');
  }

  static double _refreshRate() {
    try {
      final rate = PlatformDispatcher.instance.views.first.display.refreshRate;
      return rate > 0 ? rate : 60;
    } catch (_) {
      return 60;
    }
  }

  /// Частота экрана по промежуткам между соседними кадрами (медиана),
  /// приведённая к ближайшей из 30/40/60/90/120/144. `null` — кадров мало
  /// или они шли с паузами (покой), судить не по чему.
  @visibleForTesting
  static double? measuredRefreshRate(List<FrameTiming> frames) {
    final gaps = <int>[];
    for (var i = 1; i < frames.length; i++) {
      final d =
          frames[i].timestampInMicroseconds(FramePhase.vsyncStart) -
          frames[i - 1].timestampInMicroseconds(FramePhase.vsyncStart);
      if (d > 0 && d < 40000) gaps.add(d);
    }
    if (gaps.length < 10) return null;
    gaps.sort();
    final hz = 1e6 / gaps[gaps.length ~/ 2];
    const rates = [30.0, 40.0, 60.0, 90.0, 120.0, 144.0];
    var best = rates.first;
    for (final r in rates) {
      if ((r - hz).abs() < (best - hz).abs()) best = r;
    }
    return best;
  }

  /// Сводка по кадрам — отдельно, чтобы её можно было проверить тестом.
  @visibleForTesting
  static String summarize(List<FrameTiming> frames, {required double refreshRate}) {
    final budgetUs = 1e6 / refreshRate;
    final build = frames.map((f) => f.buildDuration.inMicroseconds).toList()
      ..sort();
    final raster = frames.map((f) => f.rasterDuration.inMicroseconds).toList()
      ..sort();
    final total = frames
        .map((f) => f.totalSpan.inMicroseconds)
        .toList()
      ..sort();
    int pct(List<int> xs, double p) =>
        xs[((xs.length - 1) * p).round().clamp(0, xs.length - 1)];
    String ms(int us) => (us / 1000).toStringAsFixed(1);
    final overBuild = build.where((x) => x > budgetUs).length;
    final overRaster = raster.where((x) => x > budgetUs).length;
    return 'frames=${frames.length} hz=${refreshRate.round()} '
        'budget=${ms(budgetUs.round())}ms '
        'build p50=${ms(pct(build, .5))} p90=${ms(pct(build, .9))} '
        'p99=${ms(pct(build, .99))} max=${ms(build.last)} over=$overBuild | '
        'raster p50=${ms(pct(raster, .5))} p90=${ms(pct(raster, .9))} '
        'p99=${ms(pct(raster, .99))} max=${ms(raster.last)} over=$overRaster | '
        'span p90=${ms(pct(total, .9))}';
  }
}
