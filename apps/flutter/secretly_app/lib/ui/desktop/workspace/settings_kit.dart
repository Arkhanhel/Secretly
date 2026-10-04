// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../primitives/desktop_switch.dart';
import '../primitives/hover_listener.dart';
import 'settings_style.dart';

/// Набор настроек по макету владельца (29.09.2026): заголовок раздела,
/// сегменты, ползунок, вкладки, спокойная кнопка, строка-карточка с
/// переключателем. Все размеры — из макета «Настройки внешнего вида».
///
/// Цвета берутся из [SettingsScope]: страница серая, акцент — выбранный
/// человеком.

/// Заголовок раздела: КАПСОМ 12/700, справа — значение (необязательно).
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(
    this.text, {
    super.key,
    this.trailing,
    this.badge,
  });

  final String text;

  /// Справа в той же строке: текущий выбор («Неон», «Blurple · #5865F2»).
  final Widget? trailing;

  /// Плашка сразу за заголовком («только для живых обоев»).
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final title = Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: DType.family,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.48,
        color: p.muted,
      ),
    );
    final badgeChip = badge == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: p.ter,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                fontFamily: DType.family,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: p.faint,
              ),
            ),
          );
    // Заголовок с плашкой занимает всё место слева, значение прижато к
    // правому краю раздела — как в макете (`justify-content: space-between`).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(child: title),
              if (badgeChip != null) ...[
                const SizedBox(width: 8),
                Flexible(child: badgeChip),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

/// Пояснение под заголовком раздела — 13, третьим тоном.
class SettingsDescription extends StatelessWidget {
  const SettingsDescription(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    return Text(
      text,
      style: TextStyle(
        fontFamily: DType.family,
        fontSize: 13,
        height: 1.4,
        color: p.faint,
      ),
    );
  }
}

/// Раздел страницы: поля 20 сверху и снизу, черта снизу, как в макете.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.title,
    this.titleTrailing,
    this.badge,
    this.description,
    required this.child,
    this.divider = true,
  });

  final String? title;
  final Widget? titleTrailing;
  final String? badge;
  final String? description;
  final Widget child;

  /// Черта под разделом. У последнего раздела страницы её можно снять.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: p.border)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            SettingsSectionTitle(title!, trailing: titleTrailing, badge: badge),
          if (description != null) ...[
            const SizedBox(height: 4),
            SettingsDescription(description!),
          ],
          if (title != null || description != null) const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Сегменты макета: тёмная подложка с полем 3, выбранный — светлее.
///
/// [expand] — сегменты делят ширину поровну (плотность, форма пузыря);
/// иначе каждый по своей подписи.
class SettingsSegmented<T> extends StatelessWidget {
  const SettingsSegmented({
    super.key,
    required this.values,
    required this.labels,
    required this.value,
    required this.onChanged,
    this.icons,
    this.leading,
    this.counts,
    this.expand = true,
    this.enabled = true,
  });

  final List<T> values;
  final List<String> labels;
  final T? value;
  final ValueChanged<T> onChanged;

  /// Значок перед подписью; той же длины, что [values].
  final List<IconData>? icons;

  /// Свой рисунок перед подписью (например, образец скругления).
  final List<Widget Function(Color color)>? leading;

  /// Число за подписью приглушённо («Статичные 11»).
  final List<int>? counts;
  final bool expand;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    assert(values.length == labels.length);
    final segments = <Widget>[
      for (var i = 0; i < values.length; i++)
        _segment(context, p, i),
    ];
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: p.ter,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              expand ? Expanded(child: segments[i]) : segments[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, SettingsPalette p, int i) {
    final active = values[i] == value;
    return Semantics(
      button: true,
      selected: active,
      enabled: enabled,
      label: labels[i],
      excludeSemantics: true,
      child: HoverListener(
        onTap: enabled ? () => onChanged(values[i]) : null,
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (ctx, hovered, pressed) {
          final fg = active || (hovered && enabled) ? p.head : p.muted;
          return AnimatedContainer(
            duration: DMotion.fast,
            constraints: const BoxConstraints(minHeight: 30),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? p.sel : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading![i](fg),
                  const SizedBox(width: 8),
                ] else if (icons != null) ...[
                  Icon(icons![i], size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: DType.family,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
                if (counts != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${counts![i]}',
                    style: TextStyle(
                      fontFamily: DType.family,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: fg.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Ползунок макета: дорожка 4, кружок акцента, без «лужи» вокруг кружка.
class SettingsSlider extends StatelessWidget {
  const SettingsSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.semanticLabel,
    this.semanticValue,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String? semanticLabel;
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final accent = DColors.of(context).accentPrimary;
    return Semantics(
      label: semanticLabel,
      value: semanticValue,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          activeTrackColor: accent,
          inactiveTrackColor: p.dark ? p.ter : p.sel,
          thumbColor: Colors.white,
          overlayColor: accent.withValues(alpha: 0.14),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          thumbShape: const _SettingsThumb(),
          tickMarkShape: SliderTickMarkShape.noTickMark,
          showValueIndicator: ShowValueIndicator.never,
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Кружок ползунка: белый с кольцом акцента — виден на любой дорожке.
class _SettingsThumb extends SliderComponentShape {
  const _SettingsThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(16);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center.translate(0, 1),
      8,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(center, 8, Paint()..color = sliderTheme.thumbColor!);
    canvas.drawCircle(
      center,
      4,
      Paint()..color = sliderTheme.activeTrackColor ?? const Color(0xFF5865F2),
    );
  }
}

/// Вкладка шапки раздела.
@immutable
class SettingsTab {
  const SettingsTab({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Вкладки под заголовком: подчёркивание акцентом у выбранной.
class SettingsTabs extends StatelessWidget {
  const SettingsTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<SettingsTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final accent = DColors.of(context).accentPrimary;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Wrap(
        spacing: 22,
        children: [
          for (var i = 0; i < tabs.length; i++)
            Semantics(
              button: true,
              selected: i == index,
              label: tabs[i].label,
              excludeSemantics: true,
              child: HoverListener(
                onTap: () => onChanged(i),
                cursor: SystemMouseCursors.click,
                builder: (ctx, hovered, pressed) {
                  final active = i == index;
                  final fg = active || hovered ? p.head : p.faint;
                  return AnimatedContainer(
                    duration: DMotion.fast,
                    padding: const EdgeInsets.fromLTRB(2, 10, 2, 9),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: active ? accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tabs[i].icon, size: 18, color: fg),
                        const SizedBox(width: 6),
                        Text(
                          tabs[i].label,
                          style: TextStyle(
                            fontFamily: DType.family,
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Спокойная кнопка макета («По умолчанию», «Входящее»): серая подложка,
/// подпись 13/600, значок слева.
class SettingsSoftButton extends StatelessWidget {
  const SettingsSoftButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.small = false,
    this.tooltip,
    this.iconOnly = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  /// Кнопка шапки предпросмотра: 26 точек вместо 32.
  final bool small;
  final String? tooltip;

  /// Только значок (подпись уходит в подсказку): при крупном тексте кнопки
  /// шапки предпросмотра иначе не помещаются рядом.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final enabled = onTap != null;
    // Без значка подпись остаётся всегда: пустая кнопка — не кнопка.
    final showLabel = !iconOnly || icon == null;
    final button = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: HoverListener(
        onTap: onTap,
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (ctx, hovered, pressed) => AnimatedContainer(
          duration: DMotion.fast,
          height: small ? 26 : 32,
          padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12),
          decoration: BoxDecoration(
            color: hovered && enabled
                ? Color.lerp(p.sel, p.head, pressed ? 0.16 : 0.08)
                : p.sel,
            borderRadius: BorderRadius.circular(small ? 5 : 6),
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  Icon(icon, size: small ? 15 : 17, color: p.text),
                if (icon != null && showLabel)
                  SizedBox(width: small ? 4 : 6),
                if (showLabel)
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: DType.family,
                      fontSize: small ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final hint = tooltip ?? (iconOnly ? label : null);
    if (hint == null) return button;
    return Tooltip(message: hint, child: button);
  }
}

/// Переключатель настроек — 40×24 по макету; сам рисунок у [DesktopSwitch].
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticsLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    return DesktopSwitch(
      value: value,
      onChanged: onChanged,
      semanticsLabel: semanticsLabel,
      width: 40,
      height: 24,
      offTrackColor: p.dark ? const Color(0xFF80848E) : const Color(0xFFB5BAC1),
      offKnobColor: Colors.white,
    );
  }
}

/// Строка-карточка с переключателем («Обои провожают сообщение»): нажатие по
/// всей строке переключает.
class SettingsToggleCard extends StatelessWidget {
  const SettingsToggleCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = SettingsScope.paletteOf(context);
    final enabled = onChanged != null;
    return HoverListener(
      onTap: enabled ? () => onChanged!(!value) : null,
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hovered && enabled ? p.hover : p.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: p.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: DType.family,
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: p.head,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: DType.family,
                        fontSize: 12.5,
                        height: 1.35,
                        color: p.faint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            SettingsSwitch(
              value: value,
              onChanged: onChanged,
              semanticsLabel: title,
            ),
          ],
        ),
      ),
    );
  }
}

/// Кольцо выбора вокруг кружка цвета: провал цветом страницы, затем цвет.
List<BoxShadow> settingsSwatchRing({
  required bool selected,
  required Color color,
  required Color page,
}) {
  if (!selected) return const <BoxShadow>[];
  // Тени рисуются по порядку, каждая ПОВЕРХ прежней: широкое кольцо цвета
  // первым, узкий провал цветом страницы — на нём.
  return [
    BoxShadow(color: color, spreadRadius: 4),
    BoxShadow(color: page, spreadRadius: 2),
  ];
}

/// Обводка выбранной карточки: 2 точки акцента; невыбранной — черта страницы.
List<BoxShadow> settingsCardRing({
  required bool selected,
  required Color accent,
  required Color border,
}) =>
    [BoxShadow(color: selected ? accent : border, spreadRadius: selected ? 2 : 1)];
