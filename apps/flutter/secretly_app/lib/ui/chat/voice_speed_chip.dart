// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Чип скорости на пузыре голосового (Н-8, 22.11.2026).
///
/// Было: видимый чип ~30×14 и ровно такая же зона касания, без подписи для
/// чтеца экрана, и чип был только во время игры — на паузе строка под волной
/// сдвигалась.
///
/// Стало:
/// - видимый чип того же размера, а касание принимается в зоне не меньше
///   [VoiceSpeedChip.minHitWidth] × [VoiceSpeedChip.minHitHeight] вокруг него
///   (зону держит [SpeedChipHitScope] — обёртка пузыря, поэтому раскладка
///   пузыря не меняется ни на пиксель);
/// - `Semantics(button)` с подписью «Скорость воспроизведения» и значением
///   «1,5×»;
/// - на паузе чип не исчезает из раскладки: место сохраняется (невидимый,
///   касания и чтец экрана его не видят) — строка стоит на месте.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class VoiceSpeedChip extends StatelessWidget {
  const VoiceSpeedChip({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.textStyle,
    required this.visible,
    this.onTap,
  });

  /// Наименьшая зона касания вокруг чипа.
  static const double minHitWidth = 36;
  static const double minHitHeight = 28;

  /// «1,5×».
  final String label;

  /// «Скорость воспроизведения».
  final String semanticLabel;
  final TextStyle textStyle;

  /// `false` — на паузе: место держится, чипа не видно.
  final bool visible;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: textStyle),
    );
    final active = visible && onTap != null;
    return _SpeedChipTarget(
      enabled: active,
      child: active
          ? Semantics(
              button: true,
              label: semanticLabel,
              value: label,
              excludeSemantics: true,
              onTap: onTap,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: chip,
              ),
            )
          : IgnorePointer(
              child: ExcludeSemantics(
                child: Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: chip,
                ),
              ),
            ),
    );
  }
}

/// Обёртка пузыря: касания рядом с [VoiceSpeedChip] (в зоне
/// [VoiceSpeedChip.minHitWidth] × [VoiceSpeedChip.minHitHeight]) достаются
/// чипу, а не волне или пузырю. Без чипа внутри — прозрачна.
class SpeedChipHitScope extends SingleChildRenderObjectWidget {
  const SpeedChipHitScope({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderSpeedChipHitScope();
}

@visibleForTesting
class RenderSpeedChipHitScope extends RenderProxyBox {
  _RenderSpeedChipTarget? _target;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final t = _target;
    if (t != null &&
        t.enabled &&
        t.attached &&
        t.hasSize &&
        size.contains(position)) {
      final inverse = Matrix4.tryInvert(t.getTransformTo(this));
      if (inverse != null) {
        final local = MatrixUtils.transformPoint(inverse, position);
        if (t.slopRect.contains(local)) {
          // Внутрь чипа: `Size.contains` не включает правый и нижний край.
          final inside = Offset(
            local.dx.clamp(0.0, t.size.width - .01),
            local.dy.clamp(0.0, t.size.height - .01),
          );
          final hit = result.addWithRawTransform(
            transform: inverse,
            position: position,
            hitTest: (r, _) => t.hitTest(r, position: inside),
          );
          if (hit) {
            result.add(BoxHitTestEntry(this, position));
            return true;
          }
        }
      }
    }
    return super.hitTest(result, position: position);
  }
}

class _SpeedChipTarget extends SingleChildRenderObjectWidget {
  const _SpeedChipTarget({required this.enabled, super.child});

  final bool enabled;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSpeedChipTarget(enabled);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSpeedChipTarget renderObject,
  ) {
    renderObject.enabled = enabled;
  }
}

class _RenderSpeedChipTarget extends RenderProxyBox {
  _RenderSpeedChipTarget(this.enabled);

  bool enabled;
  RenderSpeedChipHitScope? _scope;

  /// Зона касания в своих координатах: не меньше минимума. Вниз — не больше
  /// 6 px (там нижний отступ пузыря или подпись расшифровки), остальное —
  /// вверх, в просвет над строкой.
  Rect get slopRect {
    final dx = math.max(0.0, (VoiceSpeedChip.minHitWidth - size.width) / 2);
    final extraV = math.max(0.0, VoiceSpeedChip.minHitHeight - size.height);
    final down = math.min(extraV / 2, 6.0);
    final up = extraV - down;
    return Rect.fromLTRB(-dx, -up, size.width + dx, size.height + down);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    RenderObject? p = parent;
    while (p != null && p is! RenderSpeedChipHitScope) {
      p = p.parent;
    }
    if (p is RenderSpeedChipHitScope) {
      _scope = p;
      p._target = this;
    }
  }

  @override
  void detach() {
    final s = _scope;
    if (s != null && identical(s._target, this)) s._target = null;
    _scope = null;
    super.detach();
  }
}
