// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// «Назад» на главном экране (21.11.2026, владелец: «Чаты — главная
/// страница; все жесты и кнопки назад ведут обратно в Чаты, и только потом
/// выход из приложения»).
///
/// Одно нажатие «Назад» Flutter отдаёт ВСЕМ `PopScope` маршрута сразу —
/// и оболочке, и разделу (выделение в Чатах/Контактах). Чтобы одно нажатие
/// не делало два дела (снять выделение И уйти в Чаты), раздел отмечает, что
/// нажатие он забрал, а оболочка смотрит на отметку после всех обработчиков.
library;

import 'dart:async';

class HomeBackGuard {
  HomeBackGuard._();

  static bool _consumed = false;

  /// Раздел обработал «Назад» сам (снял выделение, закрыл поиск…).
  static void markConsumed() => _consumed = true;

  /// Оболочка: выполнить [action], если раздел нажатие не забрал. Решает
  /// после всех синхронных обработчиков этого нажатия.
  static void runIfUnclaimed(void Function() action) {
    scheduleMicrotask(() {
      final consumed = _consumed;
      _consumed = false;
      if (!consumed) action();
    });
  }
}
