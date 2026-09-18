// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'desktop_tooltip.dart';
import 'hover_listener.dart';

enum DButtonKind { filled, tonal, ghost, danger }

enum DButtonSize { small, medium, large }

class DesktopButton extends StatelessWidget {
  const DesktopButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.kind = DButtonKind.filled,
    this.size = DButtonSize.medium,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final DButtonKind kind;
  final DButtonSize size;
  final bool expand;

  EdgeInsets get _padding {
    switch (size) {
      case DButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case DButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 9);
      case DButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    }
  }

  double get _iconSize {
    switch (size) {
      case DButtonSize.small:
        return 14;
      case DButtonSize.medium:
        return 16;
      case DButtonSize.large:
        return 18;
    }
  }

  TextStyle get _textStyle {
    switch (size) {
      case DButtonSize.small:
        return DType.caption.copyWith(fontWeight: FontWeight.w600);
      case DButtonSize.medium:
        return DType.label.copyWith(fontWeight: FontWeight.w600);
      case DButtonSize.large:
        return DType.bodyStrong;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final disabled = onPressed == null;

    Color bg, fg, hoverOverlay, pressOverlay;
    switch (kind) {
      case DButtonKind.filled:
        bg = disabled ? c.borderDivider : c.accentPrimary;
        fg = disabled ? c.textDisabled : Colors.white;
        hoverOverlay = const Color(0x14FFFFFF);
        pressOverlay = const Color(0x29000000);
        break;
      case DButtonKind.tonal:
        bg = c.selected;
        fg = disabled ? c.textDisabled : c.accentPrimary;
        hoverOverlay = c.hover;
        pressOverlay = c.pressed;
        break;
      case DButtonKind.ghost:
        bg = Colors.transparent;
        fg = disabled ? c.textDisabled : c.textPrimary;
        hoverOverlay = c.hover;
        pressOverlay = c.pressed;
        break;
      case DButtonKind.danger:
        bg = disabled ? c.borderDivider : c.danger;
        fg = disabled ? c.textDisabled : Colors.white;
        hoverOverlay = const Color(0x14FFFFFF);
        pressOverlay = const Color(0x29000000);
        break;
    }

    final child = HoverListener(
      onTap: onPressed,
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (context, hovered, pressed) {
        Color overlay = Colors.transparent;
        if (!disabled) {
          if (pressed) {
            overlay = pressOverlay;
          } else if (hovered) {
            overlay = hoverOverlay;
          }
        }
        return AnimatedContainer(
          duration: DMotion.fast,
          curve: DMotion.easeOutCubic,
          padding: _padding,
          decoration: BoxDecoration(
            color: Color.alphaBlend(overlay, bg),
            borderRadius: BorderRadius.circular(DRadii.sm),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: _iconSize, color: fg),
                const SizedBox(width: DSpace.s),
              ],
              Text(label, style: _textStyle.copyWith(color: fg)),
            ],
          ),
        );
      },
    );

    if (expand) return SizedBox(width: double.infinity, child: child);
    return child;
  }
}

/// Icon-only button with hover state. Pill shape.
class DesktopIconButton extends StatelessWidget {
  const DesktopIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 36,
    this.iconSize = 18,
    this.color,
    this.bgColor,
    this.kind = DIconButtonKind.ghost,
    this.radius,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? bgColor;
  final DIconButtonKind kind;

  /// Скругление подложки под значком. По умолчанию таблетка — так значок в
  /// ряду других читается кружком.
  ///
  /// · В макете часть значков сидит в скруглённых КВАДРАТАХ (26×26 радиусом 8
  /// у закрытия карточки ответа, 32×32 радиусом 10 у кнопок поля ввода): там,
  /// где значок стоит внутри другой формы, кружок спорит с ней. Параметр
  /// добавочный, умолчание прежнее — ни одно существующее место не меняется.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final disabled = onPressed == null;

    Widget btn = HoverListener(
      onTap: onPressed,
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (context, hovered, pressed) {
        // 🔴 СЛУЖЕБНЫЙ ЗНАЧОК ПРИГЛУШЁН, И ЭТО ОДНО ПРАВИЛО НА ВСЁ ОКНО.
        //
        // Значки в шапке, у поля ввода и в списке рисовались основным цветом
        // текста, а те же по смыслу значки на рейке — вторичным. Получался
        // ряд одинаково ярких кружков, в котором глазу не за что зацепиться,
        // и рейка, выглядящая тусклее остального окна без причины.
        //
        // Теперь одинаково: покой — вторичный цвет, наведение — основной.
        // Яркость означает «сюда сейчас можно нажать», а не «здесь кнопка».
        final fg =
            color ??
            (disabled
                ? c.textDisabled
                : ((hovered || pressed) ? c.textPrimary : c.textSecondary));
        Color bg = bgColor ?? Colors.transparent;
        if (!disabled) {
          if (pressed) {
            bg = Color.alphaBlend(c.pressed, bg);
          } else if (hovered) {
            bg = Color.alphaBlend(c.hover, bg);
          }
        }
        if (kind == DIconButtonKind.danger && (hovered || pressed)) {
          bg = c.danger.withValues(alpha: pressed ? 0.30 : 0.18);
        }
        return AnimatedContainer(
          duration: DMotion.fast,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius ?? DRadii.pill),
          ),
          child: Icon(icon, size: iconSize, color: fg),
        );
      },
    );
    if (tooltip != null) btn = DesktopTooltip(message: tooltip!, child: btn);
    return btn;
  }
}

enum DIconButtonKind { ghost, danger }
