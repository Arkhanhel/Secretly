// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../../app/app_controller.dart';

/// Значок поддержки: точка «обращение в работе» либо кружок с числом
/// непрочитанных ответов.
///
/// Запрос владельца (03.08.2026): «если открыта сессия тех поддержки — красный
/// кружок на странице настроек; если прислали ответ — кружок с цифрой; такой же
/// кружок на иконке Настройки внизу».
///
/// ТРИ СОСТОЯНИЯ, и правило выбрано так, чтобы значок ГАС САМ, а не висел вечно
/// после любого давнего обращения:
///   * число — есть непрочитанные ответы поддержки;
///   * точка — вы написали, ответа ещё нет («в работе»);
///   * ничего — переписки нет либо последний ответ прочитан.
///
/// Виджет один на оба места нарочно: значок в списке настроек и значок на
/// иконке нижней панели обязаны выглядеть одинаково, иначе человек не свяжет
/// их между собой.
class SupportBadge extends StatelessWidget {
  const SupportBadge({
    super.key,
    required this.count,
    required this.awaiting,
    this.compact = false,
  });

  /// Непрочитанные ответы поддержки.
  final int count;

  /// Обращение в работе: ответа ещё нет.
  final bool awaiting;

  /// Уменьшенный вариант — для наложения на иконку нижней панели.
  final bool compact;

  /// Красный, а не `colorScheme.error`: значок обязан читаться одинаково на
  /// всех палитрах приложения, а тема ошибки у некоторых из них приглушённая.
  static const Color _dotColor = Color(0xFFF4384A);

  bool get _visible => count > 0 || awaiting;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    // Точка «в работе» — без числа.
    if (count <= 0) {
      final d = compact ? 9.0 : 10.0;
      return Container(
        width: d,
        height: d,
        decoration: const BoxDecoration(
          color: _dotColor,
          shape: BoxShape.circle,
        ),
      );
    }

    // 99+ вместо трёхзначного числа: кружок не должен разъезжаться по строке.
    final label = count > 99 ? '99+' : '$count';
    final height = compact ? 15.0 : 19.0;
    // 🔴 БЕЗ `alignment`. Container с выравниванием РАЗДУВАЕТСЯ до всех
    // доступных размеров, а не обжимает содержимое: в строке настроек это
    // прошло бы незамеченным, но в стопке над иконкой нижней панели значок
    // растянулся бы на весь экран. Текст центрируется своим textAlign, а
    // минимальная ширина держит кружок круглым на однозначном числе.
    return Container(
      constraints: BoxConstraints(minWidth: height, minHeight: height),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: _dotColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 9.5 : 11.5,
          fontWeight: FontWeight.w800,
          height: 1.05,
        ),
      ),
    );
  }
}

/// Тот же значок, но подписанный на изменения контроллера — чтобы место
/// показа не заботилось о перерисовке.
class SupportBadgeListener extends StatelessWidget {
  const SupportBadgeListener({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final AppController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: controller.changed,
      builder: (context, _) => SupportBadge(
        count: controller.supportUnreadCount,
        awaiting: controller.supportAwaitingReply,
        compact: compact,
      ),
    );
  }
}
