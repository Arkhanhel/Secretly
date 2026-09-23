// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'hover_listener.dart';

/// Переключатель окна — 36×20, как в макете.
///
/// 🔴 ПОЧЕМУ НЕ МАТЕРИАЛЬНЫЙ `Switch`.
///
/// Материальный переключатель вместе с обязательными полями занимает около
/// 52×32 точек. В строке высотой в текст он становился самым крупным
/// предметом панели: глаз находил сначала его, а потом уже подпись, которая
/// говорит, ЧТО он переключает. В макете ровно наоборот — переключатель
/// маленький и спокойный, дорожка почти не видна, пока не включат.
///
/// Второе: материальный красится темой Material, а не палитрой окна. Он один
/// в интерфейсе жил по чужим правилам и не следовал за выбранным акцентом.
///
/// Размеры из макета: дорожка 36×20 радиусом 10, поля 2, кружок 16.
/// Выключенный кружок — цвета второго тона текста, а не белый: белый на
/// тёмной дорожке читается как включённый.
class DesktopSwitch extends StatelessWidget {
  const DesktopSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticsLabel,
  });

  /// Что именно переключает. Без этого экранный диктор объявляет «включено»,
  /// не сказав чего: сам переключатель нарисован, подпись живёт в соседней
  /// строке и в его узел семантики не попадает.
  final String? semanticsLabel;

  final bool value;

  /// `null` — переключатель недоступен: гаснет и не отвечает на нажатие.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final enabled = onChanged != null;
    final track = value
        ? c.accentPrimary
        : Colors.white.withValues(alpha: 0.12);
    // 🔴 ОДИН УЗЕЛ, А НЕ ДВА. [MergeSemantics] сводит подпись, состояние и
    // нажатие в один предмет обхода. Без него диктор находил бы отдельно
    // «переключатель» без имени и отдельно подпись — и не связал бы их.
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        enabled: enabled,
        label: semanticsLabel,
        child: Opacity(
      opacity: enabled ? 1 : 0.45,
      child: HoverListener(
        onTap: enabled ? () => onChanged!(!value) : null,
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (ctx, hovered, pressed) => AnimatedContainer(
          duration: DMotion.base,
          curve: DMotion.easeOutCubic,
          width: 36,
          height: 20,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: hovered && enabled && !value
                ? Colors.white.withValues(alpha: 0.18)
                : track,
            borderRadius: BorderRadius.circular(10),
          ),
          child: AnimatedAlign(
            duration: DMotion.base,
            curve: DMotion.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: value ? Colors.white : c.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
          ),
        ),
      ),
    );
  }
}
