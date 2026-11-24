// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Эффект в корневом Overlay, привязанный к экрану, который его запустил
/// (Н-10, 22.11.2026).
///
/// Полёт реакции и эффект эмодзи на весь экран живут в корневом Overlay —
/// поверх клавиатуры, шапки и уходящего меню реакций. Но экран чата могли
/// закрыть посреди эффекта, и 👻 ⚡ 🎂 💀 доигрывали (и затемняли) поверх
/// списка чатов. Теперь эффект снимается, как только его экран:
/// - ушёл из навигатора (назад, свайп, замена) — `isActive == false`;
/// - накрыт новой страницей, открытой ПОСЛЕ запуска (профиль, просмотр
///   медиа) — у экрана поехала вторичная анимация.
///
/// То, что уже накрывало экран в миг запуска (уходящее меню реакций),
/// эффект не снимает. Без маршрута (тесты, ПК без навигатора) — как раньше.
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class RouteBoundFx extends StatefulWidget {
  const RouteBoundFx({
    super.key,
    required this.route,
    required this.onCancel,
    required this.child,
  });

  /// Экран, на котором запущен эффект (`ModalRoute.of(context)`).
  final ModalRoute<dynamic>? route;

  /// Снять эффект (убрать запись Overlay, освободить состояние).
  final VoidCallback onCancel;
  final Widget child;

  @override
  State<RouteBoundFx> createState() => _RouteBoundFxState();
}

class _RouteBoundFxState extends State<RouteBoundFx>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  bool _coveredAtStart = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    if (route == null) return;
    _coveredAtStart = routeCoveredByPage(route);
    // Эффект и так рисует каждый кадр — проверка раз в кадр ничего не стоит.
    _ticker = createTicker((_) => _check())..start();
  }

  void _check() {
    final route = widget.route;
    if (_cancelled || route == null) return;
    final covered = routeCoveredByPage(route);
    if (!covered) _coveredAtStart = false;
    if (!route.isActive || (covered && !_coveredAtStart)) {
      _cancelled = true;
      _ticker?.stop();
      widget.onCancel();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Экран накрыт другим маршрутом, который въезжает или уже встал поверх.
@visibleForTesting
bool routeCoveredByPage(ModalRoute<dynamic> route) {
  if (route.isCurrent) return false;
  final secondary = route.secondaryAnimation;
  if (secondary == null) return false;
  final s = secondary.status;
  return s == AnimationStatus.forward || s == AnimationStatus.completed;
}
