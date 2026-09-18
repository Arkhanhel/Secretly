// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'hover_listener.dart';

/// Сегментированный переключатель из макета: несколько взаимоисключающих
/// значений в одной плашке.
///
/// 🔴 ЗАЧЕМ ОН, КОГДА ЕСТЬ ТУМБЛЕР.
///
/// Тумблер отвечает только «да/нет». Как только значений становится три —
/// «Тёмная», «Светлая», «Авто» — тумблер либо врёт (прячет третье), либо
/// плодит вторую строку «следовать системе», и человек остаётся гадать, что
/// победит при споре двух переключателей.
///
/// Сегменты показывают все значения сразу и то, какое выбрано, — одним
/// взглядом и без чтения.
///
/// Геометрия из макета: плашка с полем 3, радиус 9, сегмент высотой 22,
/// выбранный залит белым с альфой .12, подпись 11/700.
class DesktopSegmented<T> extends StatelessWidget {
  const DesktopSegmented({
    super.key,
    required this.values,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  /// Значения по порядку слева направо.
  final List<T> values;

  /// Подписи той же длины, что [values].
  final List<String> labels;

  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    assert(values.length == labels.length);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < values.length; i++)
            HoverListener(
              onTap: () => onChanged(values[i]),
              cursor: SystemMouseCursors.click,
              builder: (ctx, hovered, pressed) {
                final active = values[i] == value;
                return AnimatedContainer(
                  duration: DMotion.fast,
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.12)
                        : (hovered
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.transparent),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    labels[i],
                    style: DType.tiny.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active ? c.textPrimary : c.textSecondary,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
