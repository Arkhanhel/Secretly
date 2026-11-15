// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';

/// Общие часы украшений на ПК (14.11.2026).
///
/// 🔴 ПРИЧИНА «ПК ЖРЁТ 25–35 % ЯДРА В ПРОСТОЕ». Живая рамка вела себя
/// тикером, то есть просила кадр на КАЖДОМ обновлении экрана (60–144 раз в
/// секунду). Её собственный шаг ограничен 60 в секунду, но кадр всё равно
/// заказан: Flutter на macOS при этом заново собирает и компонует всё окно
/// (Skia, без частичной перерисовки). Замер демо-копии: одна рамка у своего
/// портрета в углу — 26 % ядра, окно свёрнуто — 0,4 %; профиль показал
/// `LiveFramePainter.paint` и непрерывный `Rasterizer::DoDraw`.
///
/// Здесь — один таймер на все украшения окна: он шагает их разом, и кадр
/// заказывает только перерисовка, которую шаг вызвал. Частота — [interval];
/// `null` значит «как раньше, тикером» и оставлено телефону (мобильная
/// сборка не должна меняться). Включает только вход ПК.
class DecorationClock {
  DecorationClock._();

  /// Шаг часов. `null` — часы выключены, украшения идут своими тикерами.
  static Duration? interval;

  static final Set<VoidCallback> _subscribers = <VoidCallback>{};
  static Timer? _timer;

  static bool get enabled => interval != null;

  /// Подписка. Часы идут, пока есть хоть один подписчик.
  static void subscribe(VoidCallback onTick) {
    final step = interval;
    if (step == null) return;
    _subscribers.add(onTick);
    _timer ??= Timer.periodic(step, (_) => _tick());
  }

  static void unsubscribe(VoidCallback onTick) {
    _subscribers.remove(onTick);
    if (_subscribers.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  static void _tick() {
    // Копия: подписчик может отписаться прямо в своём шаге.
    for (final cb in List<VoidCallback>.of(_subscribers)) {
      cb();
    }
  }

  @visibleForTesting
  static int get debugSubscriberCount => _subscribers.length;

  @visibleForTesting
  static bool get debugRunning => _timer != null;

  @visibleForTesting
  static void debugReset() {
    _timer?.cancel();
    _timer = null;
    _subscribers.clear();
    interval = null;
  }
}
