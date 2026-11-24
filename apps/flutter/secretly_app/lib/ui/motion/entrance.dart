// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Появление плашек и панелей (решение владельца 20.11.2026: «грамотные
/// анимации выскакивания плашек»).
///
/// * [MountEntrance] — панель, которая подменяет другую (поиск вместо поля
///   ввода и обратно, кнопка «вниз»): въезжает на 16 pt и проявляется по
///   кривой Telegram за 0,3 с. Только при появлении; если [animate] ложь —
///   просто стоит на месте.
/// * [PlateReveal] — плашка в списке или над ним, которая сама решает,
///   показываться ли (баннер звонка, предупреждения): место под неё
///   раскрывается плавно (0,4 с), а не прыгает весь экран.
///
/// Компьютер, выключенный [kTelegramMotion], «Уменьшить движение» — без
/// анимации.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';

bool get _enabled =>
    kTelegramMotion &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

class MountEntrance extends StatefulWidget {
  const MountEntrance({
    super.key,
    required this.child,
    this.animate = true,
    this.offset = const Offset(0, 16),
    this.scaleFrom = 1.0,
    this.alignment = Alignment.center,
    this.duration = MotionDurations.standard,
  });

  final Widget child;
  final bool animate;

  /// Откуда въезжает (в логических пикселях).
  final Offset offset;

  /// С какого масштаба «выскакивает» (1,0 — без масштаба).
  final double scaleFrom;
  final Alignment alignment;
  final Duration duration;

  @override
  State<MountEntrance> createState() => _MountEntranceState();
}

class _MountEntranceState extends State<MountEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: (_enabled && widget.animate) ? 0 : 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_c.value < 1) {
      if (motionReduced(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        final k = Motion.standard.transform(t);
        final s = widget.scaleFrom + (1 - widget.scaleFrom) * k;
        return Opacity(
          opacity: (t / 0.6).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: widget.offset * (1 - k),
            child: Transform.scale(
              scale: s,
              alignment: widget.alignment,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class PlateReveal extends StatelessWidget {
  const PlateReveal({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (!_enabled || motionReduced(context)) return child;
    return AnimatedSize(
      duration: MotionDurations.list,
      reverseDuration: MotionDurations.standard,
      curve: Motion.standard,
      alignment: alignment,
      child: child,
    );
  }
}
