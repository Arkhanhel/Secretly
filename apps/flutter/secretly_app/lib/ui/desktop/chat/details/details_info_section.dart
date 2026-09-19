// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../design/tokens.dart';
import '../../primitives/desktop_button.dart';
import '../../primitives/desktop_switch.dart';
import '../../primitives/hover_listener.dart';

/// A grouped info section — section title + a vertical stack of rows.
/// Mirrors Telegram's "Info" block in the right-side panel.
class DetailsInfoSection extends StatelessWidget {
  const DetailsInfoSection({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final c = DColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DSpace.m,
        DSpace.s,
        DSpace.m,
        DSpace.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null && title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DSpace.s,
                0,
                DSpace.s,
                DSpace.xs,
              ),
              // Моноширинный ярлык раздела — как в макете и как у заголовков
              // в списке чатов. См. [DType.meta].
              child: Text(
                title!.toUpperCase(),
                style: DType.meta.copyWith(color: c.textDisabled),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: c.elevated,
              border: Border.all(color: c.borderSubtle),
              borderRadius: BorderRadius.circular(DRadii.lg),
            ),
            child: Column(children: _intersperse(children, c)),
          ),
        ],
      ),
    );
  }

  List<Widget> _intersperse(List<Widget> rows, DColorSet c) {
    if (rows.length <= 1) return rows;
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      out.add(rows[i]);
      if (i != rows.length - 1) {
        out.add(Container(height: 1, color: c.borderSubtle));
      }
    }
    return out;
  }
}

/// A single info row: icon + (label / value) + optional trailing.
/// If [copyValue] != null, clicking the row copies it to clipboard.
class DetailsInfoRow extends StatelessWidget {
  const DetailsInfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.copyValue,
    this.onTap,
    this.trailing,
    this.multiline = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? copyValue;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool multiline;

  /// «links.secretlyapp.com/room-invite/…» вместо ста двадцати знаков ссылки.
  ///
  /// 🔴 Ссылка-приглашение занимала В ПАНЕЛИ ПЯТЬ СТРОК — больше, чем всё
  /// остальное в разделе «Информация» вместе взятое. Читать её целиком
  /// незачем: её копируют и отправляют. Поэтому показываем узнаваемое начало,
  /// а в буфер уходит ссылка полностью — [copyValue] не сокращается.
  static String shortUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    u = u.replaceFirst(RegExp(r'^https?://'), '');
    // Отрезаем параметры: у приглашения их два, и они длиннее самой ссылки.
    final q = u.indexOf('?');
    if (q > 0) u = u.substring(0, q);
    const maxLen = 38;
    if (u.length <= maxLen) return u;
    return '${u.substring(0, maxLen)}…';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final effectiveOnTap =
        onTap ??
        (copyValue != null && copyValue!.isNotEmpty
            ? () {
                Clipboard.setData(ClipboardData(text: copyValue!));
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text(l10n.copied),
                    duration: const Duration(seconds: 1),
                    backgroundColor: c.elevated,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            : null);

    return HoverListener(
      onTap: effectiveOnTap,
      cursor: effectiveOnTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) {
        final bg = effectiveOnTap == null
            ? Colors.transparent
            : (pressed ? c.pressed : (hovered ? c.hover : Colors.transparent));
        return AnimatedContainer(
          duration: DMotion.fast,
          color: bg,
          padding: const EdgeInsets.symmetric(
            horizontal: DSpace.m,
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: c.textSecondary),
              const SizedBox(width: DSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (value != null && value!.isNotEmpty)
                      Text(
                        value!,
                        maxLines: multiline ? 6 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: DType.body.copyWith(color: c.textPrimary),
                      ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: (value != null && value!.isNotEmpty) ? 2 : 0,
                      ),
                      child: Text(
                        label,
                        style: DType.caption.copyWith(color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              // · ЗНАЧОК КОПИРОВАНИЯ РИСУЕТСЯ САМ, когда строку есть чем
              // копировать и своего значка справа не задано.
              //
              // Копирование работало по нажатию на всю строку — и узнать об
              // этом было нельзя ниоткуда: ни курсор, ни вид не отличали
              // «Secretly ID», который копируется, от «Участников», которые
              // просто число. Люди выделяли текст мышью.
              //
              // Значок считается ЗДЕСЬ, а не передаётся из трёх мест вызова:
              // иначе подсказка разъедется — в одном месте её поставят, в
              // другом забудут.
              if (trailing != null) ...[
                const SizedBox(width: DSpace.s),
                trailing!,
              ] else if ((copyValue ?? '').isNotEmpty) ...[
                const SizedBox(width: DSpace.s),
                Icon(
                  FluentIcons.copy_24_regular,
                  size: 16,
                  color: hovered ? c.textSecondary : c.textTertiary,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A toggle row — leading icon, label/sub, trailing Switch.
class DetailsToggleRow extends StatelessWidget {
  const DetailsToggleRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Нажатие на саму строку. Есть у настроек, где «включено» — это ещё и
  /// «насколько»: у исчезающих сообщений переключатель отвечает за вкл/выкл,
  /// а строка открывает выбор срока.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: DSpace.m, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textSecondary),
          const SizedBox(width: DSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: DType.body.copyWith(color: c.textPrimary)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: DType.caption.copyWith(color: c.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: DSpace.s),
          // Тот же переключатель, что во всей остальной части окна: см.
          // [DesktopSwitch]. Материальный был вдвое крупнее строки и красился
          // темой Material мимо палитры окна.
          DesktopSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
    if (onTap == null) return row;
    return HoverListener(
      onTap: onTap,
      cursor: SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        color: pressed
            ? c.pressed
            : (hovered ? c.hover : Colors.transparent),
        child: row,
      ),
    );
  }
}

/// Раздел-СПИСОК: моношрифтовый заголовок с линией и действием, а под ним
/// строки БЕЗ карточки и без разделителей.
///
/// 🔴 Чем отличается от [DetailsInfoSection] и почему это второй виджет.
///
/// «Информация» — это карточка фактов: обведённый блок, строки разделены
/// линиями, каждая строка сама по себе. Список тем устроен иначе: это
/// НАВИГАЦИЯ. Обведённая карточка с разделителями превращала пять тем в
/// таблицу, в которой выбранная строка почти не выделялась, а линии между
/// темами спорили с той вертикальной линией, которой темы обозначены в левой
/// панели.
///
/// В макете у такого раздела заголовок с линией на остаток ширины и значком
/// действия справа («＋» у тем), а строки идут подряд с зазором 3 и без единой
/// рамки. Подгонять под это [DetailsInfoSection] нельзя — его вид нужен
/// «Информации» как есть.
class DetailsListSection extends StatelessWidget {
  const DetailsListSection({
    super.key,
    required this.title,
    required this.children,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
  });

  final String title;
  final List<Widget> children;

  /// Значок действия в заголовке. Нет действия — нет и значка.
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    if (children.isEmpty && onAction == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DSpace.m,
        DSpace.s,
        DSpace.m,
        DSpace.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DSpace.s, 0, 0, DSpace.xs),
            child: Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: DType.meta.copyWith(color: c.textDisabled),
                ),
                const SizedBox(width: DSpace.s),
                Expanded(child: Container(height: 1, color: c.borderSubtle)),
                if (onAction != null && actionIcon != null)
                  DesktopIconButton(
                    icon: actionIcon!,
                    tooltip: actionTooltip ?? '',
                    size: 24,
                    iconSize: 15,
                    onPressed: onAction,
                  ),
              ],
            ),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            children[i],
          ],
        ],
      ),
    );
  }
}
