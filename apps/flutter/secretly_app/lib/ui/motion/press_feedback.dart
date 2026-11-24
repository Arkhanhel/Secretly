// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Отклик нажатия как в Telegram (М2, docs/TZ_MOTION_TELEGRAM_PARITY_
/// 2026-11-20.md).
///
/// * iPhone (`PlainButtonComponent.swift`): палец лёг — кнопка за 0,2 с
///   сжимается до `(w − 8) / w` и тускнеет до 0,7; отпустил — за 0,13 с
///   перелетает до `(w + 2) / w` и за 0,1 с встаёт на место.
/// * Android (`ScaleStateListAnimator.java`, `ButtonBounce.java`): сжатие за
///   70 мс, отпускание 350 мс с перелётом `Overshoot(5)`. Волна Material
///   остаётся — прозрачность не трогаем.
///
/// Слушает касания через [Listener], а не через жесты: в борьбу жестов не
/// вступает, нажатие, долгое нажатие и прокрутку обрабатывает кнопка внутри,
/// как и раньше. Палец сдвинулся дальше порога прокрутки — отклик снимается
/// сразу (прокрутка списка не «мнёт» кнопки).
///
/// Дёшево: один контроллер, `Transform` + `Opacity` вокруг уже построенной
/// кнопки; кнопка не перестраивается. При 1,0 оба ничего не рисуют сверх
/// кнопки. На компьютере, при выключенном [kTelegramMotion] и при системной
/// настройке «Уменьшить движение» — просто возвращает [child].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kPrimaryButton, kTouchSlop;
import 'package:flutter/material.dart';

import 'motion.dart';

/// Перелёт Android `OvershootInterpolator(tension)`.
class _OvershootCurve extends Curve {
  const _OvershootCurve(this.tension);

  final double tension;

  @override
  double transformInternal(double t) {
    final u = t - 1.0;
    return u * u * ((tension + 1) * u + tension) + 1.0;
  }
}

bool get _platformWantsPress {
  if (!kTelegramMotion) return false;
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
}

class PressFeedback extends StatefulWidget {
  const PressFeedback({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// `false` — кнопка выключена: не сжимается (как в Telegram).
  final bool enabled;

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback>
    with SingleTickerProviderStateMixin {
  // Значение — масштаб. Без границ: перелёт уходит выше 1,0.
  AnimationController? _c;
  int? _pointer;
  Offset _downAt = Offset.zero;
  double _pressed = 0.94;
  double _overshoot = 1.0;
  int _seq = 0;

  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  AnimationController get _ctrl =>
      _c ??= AnimationController.unbounded(vsync: this, value: 1.0);

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PressFeedback old) {
    super.didUpdateWidget(old);
    // Кнопку выключили посреди нажатия — вернуть на место.
    if (!_enabled && _pointer != null) _cancel();
  }

  /// Выключенная кнопка не сжимается. Для обёрнутых кнопок Material это
  /// видно по самой кнопке — места вызова флажок не передают.
  bool get _enabled {
    if (!widget.enabled) return false;
    final c = widget.child;
    if (c is IconButton) return c.onPressed != null || c.onLongPress != null;
    if (c is ButtonStyleButton) return c.enabled;
    if (c is FloatingActionButton) return c.onPressed != null;
    return true;
  }

  void _down(PointerDownEvent e) {
    if (_pointer != null || !_enabled) return;
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton) {
      return;
    }
    if (motionReduced(context)) return;
    final size = context.size;
    final w = (size == null || size.width <= 0) ? 44.0 : size.width;
    // (w − 8) / w — как у Telegram; маленьким значкам не даём «схлопнуться»,
    // широким кнопкам — всё же заметно сжаться.
    _pressed = ((w - 8) / w).clamp(0.84, 0.97);
    _overshoot = (w + 2) / w;
    _pointer = e.pointer;
    _downAt = e.position;
    ++_seq;
    _ctrl.stop();
    _ctrl
        .animateTo(
          _pressed,
          duration: _ios
              ? MotionDurations.press
              : const Duration(milliseconds: 70),
          curve: _ios ? Curves.easeInOut : Curves.easeOut,
        )
        .orCancel
        .catchError((_) {});
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if ((e.position - _downAt).distance > kTouchSlop) _cancel();
  }

  Future<void> _up(PointerUpEvent e) async {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final seq = ++_seq;
    final c = _ctrl..stop();
    try {
      if (_ios) {
        await c
            .animateTo(
              _overshoot,
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOut,
            )
            .orCancel;
        if (seq != _seq || !mounted) return;
        await c
            .animateTo(
              1.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeIn,
            )
            .orCancel;
      } else {
        await c
            .animateTo(
              1.0,
              duration: const Duration(milliseconds: 350),
              curve: const _OvershootCurve(5.0),
            )
            .orCancel;
      }
    } on TickerCanceled {
      // Новое нажатие или закрытие экрана — продолжать нечего.
    }
  }

  void _cancelEvent(PointerCancelEvent e) {
    if (e.pointer == _pointer) _cancel();
  }

  void _cancel() {
    _pointer = null;
    ++_seq;
    _ctrl
      ..stop()
      ..animateTo(
        1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      ).orCancel.catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_platformWantsPress) return widget.child;
    final c = _ctrl;
    final ios = _ios;
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _cancelEvent,
      child: AnimatedBuilder(
        animation: c,
        child: widget.child,
        // 🔴 Дерево одной формы всегда: если бы при 1,0 возвращался голый
        // child, кнопка внутри пересоздавалась бы посреди нажатия и теряла
        // его. При 1,0 Transform и Opacity слой не создают.
        builder: (context, child) {
          final s = c.value;
          var opacity = 1.0;
          if (ios && s < 1.0) {
            // Прозрачность идёт вместе со сжатием: 1,0 → 0,7.
            final range = 1.0 - _pressed;
            final k = range <= 0 ? 0.0 : ((1.0 - s) / range).clamp(0.0, 1.0);
            opacity = 1.0 - 0.3 * k;
          }
          return Opacity(
            opacity: opacity,
            child: Transform.scale(scale: s, child: child),
          );
        },
      ),
    );
  }
}
