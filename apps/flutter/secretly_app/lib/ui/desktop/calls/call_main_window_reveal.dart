// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../services/desktop_tray_service.dart';

/// Вывести главное окно, если оно спрятано в трей или свёрнуто (30.09.2026).
///
/// 🔴 ЗАЧЕМ. Окно созвона закрыли крестиком или свернули (Esc, «Свернуть»),
/// а главное окно в это время спрятано в трей: созвон идёт дальше, микрофон
/// слушает — а на экране ни одного окна. Мини-окно и полоса «Вернуться»
/// живут В главном окне и тоже не видны: человек не знает, что он ещё в
/// эфире, и выйти из созвона ему не из чего.
///
/// Поэтому главное окно выходит вперёд — тем же путём, что пункт трея
/// «Открыть» ([DesktopTrayService.showMainWindow]): приложение при этом
/// отмечает окно видимым (присутствие, анимации), а не узнаёт об этом
/// случайно.
abstract final class DesktopMainWindowReveal {
  /// Спрятано ли главное окно. Подменяют тесты: настоящий ответ даёт ОС.
  @visibleForTesting
  static Future<bool> Function() isHidden = _mainWindowHidden;

  /// Как показать главное окно. Подменяют тесты.
  @visibleForTesting
  static Future<void> Function() show =
      DesktopTrayService.instance.showMainWindow;

  /// Показать главное окно, если оно спрятано. Отказ ОС — не повод ронять
  /// закрытие окна созвона.
  static Future<void> revealIfHidden() async {
    try {
      if (!await isHidden()) return;
      await show();
    } catch (_) {}
  }

  /// На Windows свёрнутое окно ОС считает видимым — спрашиваем и то и другое.
  static Future<bool> _mainWindowHidden() async =>
      !await windowManager.isVisible() || await windowManager.isMinimized();

  @visibleForTesting
  static void debugReset() {
    isHidden = _mainWindowHidden;
    show = DesktopTrayService.instance.showMainWindow;
  }
}
