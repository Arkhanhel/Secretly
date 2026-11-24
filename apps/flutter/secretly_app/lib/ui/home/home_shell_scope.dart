// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Связь разделов главного экрана с оболочкой островов v3.
///
/// Шапки разделов (Чаты, Комнаты, Контакты) спрашивают отсюда, стоят ли они
/// в оболочке с островами: если да — справа «+» и «Контакты», название
/// приложения открывает меню, а поиск живёт внизу. Нет оболочки (планшет,
/// ПК, тесты) — шапки прежние.
library;

import 'package:flutter/widgets.dart';

import 'home_islands.dart';

class HomeShellScope extends InheritedWidget {
  const HomeShellScope({
    super.key,
    required this.tab,
    required this.select,
    required this.islands,
    required super.child,
  });

  /// Текущий раздел.
  final HomeTab tab;

  /// Перейти в раздел.
  final ValueChanged<HomeTab> select;

  final HomeIslandsController islands;

  static HomeShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeShellScope>();

  @override
  bool updateShouldNotify(HomeShellScope old) =>
      tab != old.tab || islands != old.islands;
}

/// Что сделать в «Контактах», когда до них дойдёт очередь: «+» в Чатах
/// («Добавить контакт») переключает раздел и оставляет здесь просьбу.
enum HomeContactsAction { add, scanQr }

final ValueNotifier<HomeContactsAction?> homeContactsRequest =
    ValueNotifier<HomeContactsAction?>(null);

/// Слой раздела главного экрана (ряд Чаты|Комнаты, Контакты, Профиль).
///
/// 🔴 Порядок важен (баг 702, 21.11): гашение (`AnimatedOpacity`) — СНАРУЖИ
/// `TickerMode`. Внутри выключенного `TickerMode` останавливается и сама
/// анимация гашения — слой замирал непрозрачным: за профилем оставались чаты,
/// после возврата висел профиль. Спрятанный слой не рисуется (прозрачность 0),
/// не принимает касаний и не тикает, но хранит состояние.
class HomeTabLayer extends StatelessWidget {
  const HomeTabLayer({super.key, required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !on,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        opacity: on ? 1 : 0,
        child: TickerMode(enabled: on, child: child),
      ),
    );
  }
}
