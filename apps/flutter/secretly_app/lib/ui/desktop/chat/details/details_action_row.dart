// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../primitives/hover_listener.dart';

class DetailsActionItem {
  const DetailsActionItem({
    required this.icon,
    required this.label,
    this.onPressed,
    this.active = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Visual "on" state — e.g. Mute is currently active.
  final bool active;

  /// Use danger color (e.g. Block).
  final bool danger;
}

/// Horizontal row of round action buttons (icon over label), Telegram-style.
/// Distributes items with equal flex; items wrap labels in 2 lines if needed.
class DetailsActionRow extends StatelessWidget {
  const DetailsActionRow({super.key, required this.items});

  final List<DetailsActionItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 7));
      children.add(Expanded(child: _ActionTile(item: items[i])));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      // 🔴 НЕ `stretch`. Ряд лежит в колонке с прокруткой, то есть высота у
      // него неограниченная, а `stretch` требует от детей занять её целиком —
      // «BoxConstraints forces an infinite height», и вся правая панель
      // остаётся пустой. Плиткам растягиваться и не нужно: у них своя высота
      // 56, одна на всех.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.item});

  final DetailsActionItem item;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final disabled = item.onPressed == null;
    final accent = item.danger ? c.danger : c.accentPrimary;
    // 🔴 Значок в макете СИНИЙ по умолчанию, а не цвета текста: плитка
    // действия — это кнопка, и цвет отличает её от подписи под ней.
    // «Блокировать» — красная, потому что последствие красное.
    final fg = disabled ? c.textDisabled : accent;
    return HoverListener(
      onTap: item.onPressed,
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) {
        // Заливка плитки из макета: белый с альфой .05, на наведении .10, а
        // у опасного действия — красный с альфой .16.
        final baseBg = item.active
            ? accent.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.05);
        final hoverBg = item.danger
            ? accent.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.10);
        final bg = !disabled && (hovered || pressed) ? hoverBg : baseBg;
        return AnimatedContainer(
          duration: DMotion.fast,
          height: 56,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 19, color: fg),
              const SizedBox(height: 4),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DType.tiny.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: disabled
                      ? c.textDisabled
                      : (item.danger ? accent : c.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
