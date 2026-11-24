// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Уровни качества стекла SecretlyGlass вместо «всё или ничего» (план
/// стекла, 23.11.2026).
///
/// | Условие                                  | Уровень  |
/// |------------------------------------------|----------|
/// | nominal, кадры укладываются              | Full     |
/// | fair или пропуски кадров                 | Balanced |
/// | serious                                  | Edge     |
/// | critical / «Понижение прозрачности»      | Flat     |
///
/// Понижается сразу, повышается только после 20 с спокойствия — иначе на
/// границе вид переключался бы каждые несколько секунд.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../thermal_guard.dart';

enum GlassQuality { flat, edge, balanced, full }

/// Уровень по температуре и пропускам кадров — чистое правило для проверок.
GlassQuality glassQualityFor({
  required int thermalState,
  required bool framesDropping,
}) {
  if (thermalState >= 3) return GlassQuality.flat;
  if (thermalState == 2) return GlassQuality.edge;
  if (thermalState == 1 || framesDropping) return GlassQuality.balanced;
  return GlassQuality.full;
}

abstract final class GlassQualityController {
  static final ValueNotifier<GlassQuality> quality = ValueNotifier(
    GlassQuality.full,
  );

  static bool _started = false;
  static bool _framesDropping = false;
  static int _calmSinceMs = 0;
  static Timer? _recoverTimer;
  static const int _recoverMs = 20 * 1000;

  /// Подключиться к температуре и замеру кадров. Повторный вызов — ничего.
  static void ensureStarted() {
    if (_started) return;
    _started = true;
    try {
      ThermalGuard.thermalState.addListener(_update);
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    } catch (_) {
      // Вне приложения (чистые проверки) — уровень остаётся Full.
    }
  }

  static void _onTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    // Пропуск — дольше 1,5 бюджета 60 Гц на рисовании.
    var slow = 0;
    for (final t in timings) {
      if (t.rasterDuration.inMicroseconds > 25000) slow++;
    }
    final dropping = slow * 10 > timings.length; // > 10 % кадров
    if (dropping != _framesDropping) {
      _framesDropping = dropping;
      _update();
    }
  }

  static void _update() {
    final target = glassQualityFor(
      thermalState: ThermalGuard.thermalState.value,
      framesDropping: _framesDropping,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    if (target.index < quality.value.index) {
      quality.value = target; // хуже — сразу
      _calmSinceMs = 0;
      return;
    }
    if (target.index > quality.value.index) {
      if (_calmSinceMs == 0) _calmSinceMs = now;
      if (now - _calmSinceMs >= _recoverMs) {
        quality.value = target;
        _calmSinceMs = 0;
      } else {
        // Проверить ещё раз, когда спокойствие наберёт 20 с.
        _recoverTimer?.cancel();
        _recoverTimer = Timer(
          Duration(milliseconds: _recoverMs - (now - _calmSinceMs) + 50),
          _update,
        );
      }
    } else {
      _calmSinceMs = 0;
    }
  }

  @visibleForTesting
  static void debugReset() {
    quality.value = GlassQuality.full;
    _recoverTimer?.cancel();
    _framesDropping = false;
    _calmSinceMs = 0;
  }
}
