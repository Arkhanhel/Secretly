// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Сторож картинок видеокарты, которые кешируются надолго (23.11.2026).
///
/// 🔴 ЗАЧЕМ. Тестировщики видели, как статусы, рамки и эмодзи «моргают»
/// розово-фиолетовыми квадратами. Общее у всех — картинка, однажды сделанная
/// `Picture.toImageSync` и дальше тысячи раз рисуемая из долгого кеша
/// (кадры Lottie, «искры» рамок, глифы эффектов, листы обложек-узоров). На
/// iPhone (Impeller) у приложения в фоне нет доступа к видеокарте, и картинка,
/// сделанная в такой момент, остаётся испорченной навсегда — кеш раздаёт её
/// каждому, кто рисует.
///
/// Правила:
/// * кеш работает ВСЕГДА. 🔴 23.11.2026, сборка 725: первая версия не клала
///   картинку в кеш, пока [canSnapshot] ложно, и делала новую на каждый
///   вызов — сотни снимков за кадр. Если система не сообщает «на экране»
///   (так бывает со сценами iOS), рамки и обложки лагали и пропадали;
/// * [register] — кеш сбрасывается при каждом возвращении на экран, чтобы
///   ничто, сделанное в неудачный момент, не пережило его. Старые картинки
///   НЕ уничтожаются вручную: их может ещё держать записанный кадр, память
///   освободит сборщик.
library;

import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

abstract final class GpuImageGuard {
  static final List<VoidCallback> _resets = <VoidCallback>[];
  static _GuardObserver? _observer;

  /// Можно ли сейчас делать картинку видеокарты для долгого кеша.
  static bool get canSnapshot {
    final AppLifecycleState? state;
    try {
      state = SchedulerBinding.instance.lifecycleState;
    } catch (_) {
      // Рисование вне приложения (чистые проверки) — как на экране.
      return true;
    }
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Освободить картинку через два кадра (26.11.2026). Сразу нельзя:
  /// записанный кадр, который видеокарта ещё рисует, держит её — на её месте
  /// появлялся розово-фиолетовый квадрат (рамки-шейдеры, обложки со следами).
  static void disposeAfterFrames(ui.Image? image) {
    if (image == null) return;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      binding.addPostFrameCallback((_) => image.dispose());
      binding.scheduleFrame();
    });
    binding.scheduleFrame();
  }

  /// [reset] обнуляет кеш; вызывается при каждом возвращении на экран.
  static void register(VoidCallback reset) {
    _install();
    _resets.add(reset);
  }

  /// Для проверок: сбросить все кеши, как при возвращении на экран.
  @visibleForTesting
  static void debugResetAll() => _resetAll();

  static void _resetAll() {
    for (final r in List<VoidCallback>.of(_resets)) {
      r();
    }
  }

  static void _install() {
    if (_observer != null) return;
    final WidgetsBinding binding;
    try {
      binding = WidgetsBinding.instance;
    } catch (_) {
      return; // нет приложения — некому и возвращаться из фона
    }
    final o = _GuardObserver();
    _observer = o;
    binding.addObserver(o);
  }
}

class _GuardObserver with WidgetsBindingObserver {
  /// Побывало ли приложение в фоне с прошлого возвращения на экран. Путь
  /// назад идёт ступенями (фон → скрыто → неактивно → на экране), поэтому
  /// смотреть только на прошлое состояние нельзя.
  bool _wasAway = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _wasAway = true;
      case AppLifecycleState.inactive:
        // Шторка, переключатель приложений — не фон.
        break;
      case AppLifecycleState.resumed:
        if (_wasAway) {
          _wasAway = false;
          GpuImageGuard._resetAll();
        }
    }
  }
}
