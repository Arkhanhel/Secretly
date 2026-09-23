// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../../app/message_command_utils.dart' show RoomTopicRef;
import '../../room_topic_marks.dart';
import '../design/colors.dart';
import '../design/radii.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../primitives/hover_listener.dart';

/// Темы комнаты для десктопа.
///
/// 🔴 Вертикальная рейка удалена 13.09.2026. Она отнимала у переписки 200 точек
/// ширины постоянно — ради списка из трёх-пяти строк, — а на столе ширина
/// переписки и есть главная ценность окна. Её заменила [RoomTopicsStrip]:
/// 36 точек высоты вместо 200 точек ширины.
///
/// Держать обе было бы хуже, чем выбрать: два вида одного списка расходятся при
/// первой же правке, и тогда «почему на узком окне по-другому» становится
/// отдельным вопросом без ответа.
/// Темы комнаты ГОРИЗОНТАЛЬНОЙ полосой под шапкой чата.
///
/// **Почему полоса, а не рейка.** Вертикальная рейка отнимала у переписки 200
/// точек ширины постоянно — ради списка из трёх-пяти строк. На столе ширина
/// переписки это и есть главная ценность окна: в неё помещается длинное
/// сообщение без переносов через каждые пять слов. Полоса занимает 36 точек
/// высоты, которых не жалко, и возвращает переписке всю ширину.
///
/// Когда тем становится больше, чем помещается, полоса прокручивается вбок —
/// а не переносится на вторую строку: прыгающая высота шапки при каждом
/// переключении чата читается как дёрганье интерфейса.
///
/// **Данные те же.** Это [RoomTopicRef] из общей модели, синхронизируемой
/// управляющим сообщением `__secretly_topics_v1__`. Тема, созданная на
/// телефоне, появляется здесь, и наоборот. Меняется только вид — путь синхрона
/// не тронут ни на строку.
class RoomTopicsStrip extends StatelessWidget {
  const RoomTopicsStrip({
    super.key,
    required this.topics,
    required this.selectedTopicId,
    required this.onSelect,
    this.unreadByTopicId = const <String, int>{},
    this.canManage = false,
    this.onCreate,
    this.onManage,
    this.onManageBase,
    this.baseMark = '',
    this.trailing,
  });

  final List<RoomTopicRef> topics;

  /// null = «Общий», поток комнаты по умолчанию. Там лежит всё, что написано
  /// без темы, включая историю до появления тем вообще.
  final String? selectedTopicId;
  final ValueChanged<String?> onSelect;

  /// По идентификатору темы; пустая строка — это «Общий».
  final Map<String, int> unreadByTopicId;

  final bool canManage;
  final VoidCallback? onCreate;
  final ValueChanged<RoomTopicRef>? onManage;

  /// ◆ У «Основы» меняется только значок: переименовать главный поток нельзя,
  /// удалить — тем более.
  final VoidCallback? onManageBase;

  /// Знак «Основы». Пусто — решётка.
  final String baseMark;

  /// Правый край полосы — например значок сквозного шифрования.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          // · ПОДПИСИ «ТЕМЫ» В МАКЕТЕ НЕТ — полоса начинается сразу чипом
          // «Общий». Она и не нужна: чипы с «#» и есть темы, а слово перед
          // ними отнимало ширину у самих тем в полосе, которая и так узкая.
          //
          // 🔴 ФИЛЬТРА «ТОЛЬКО МОИ ТЕМЫ» (макет, правый край) ЗДЕСЬ НЕТ
          // НАМЕРЕННО. Ответить на «мои» честно нечем: отдельного признака
          // «я писал в этой теме» протокол не хранит, а посчитать его можно
          // только по ЗАГРУЖЕННОЙ ленте — она подгружается страницами. Такой
          // фильтр СПРЯТАЛ БЫ тему, в которой человек писал раньше, чем
          // дотянулась подгрузка, и человек прочитал бы это как «я туда не
          // писал». Пустое место врёт меньше, чем спрятанная ветка.
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // ◆ «ОСНОВА», А НЕ «ОБЩИЙ» (указание владельца). «Общий»
                // звучит как «остальное, что никуда не подошло»; на деле это
                // главный поток комнаты, от которого ветки и отходят.
                _TopicChip(
                  label: kRoomBaseTopicTitleRu,
                  markIcon: roomTopicIconFor(baseMark),
                  markColor: roomTopicIconColorFor(baseMark),
                  selected: selectedTopicId == null,
                  unread: unreadByTopicId[''] ?? 0,
                  colors: c,
                  onTap: () => onSelect(null),
                  onSecondaryTap: canManage && onManageBase != null
                      ? onManageBase
                      : null,
                ),
                for (final t in topics)
                  _TopicChip(
                    // Формат темы: ЗНАЧОК, потом название. По умолчанию значок
                    // — решётка; выбранный знак её ЗАМЕНЯЕТ.
                    markIcon: roomTopicIcon(t),
                    markColor: roomTopicIconColor(t),
                    label: normalizeRoomTopicTitle(t.title),
                    emoji: t.emoji.isEmpty ? null : t.emoji,
                    selected: selectedTopicId == t.id,
                    unread: unreadByTopicId[t.id] ?? 0,
                    colors: c,
                    onTap: () => onSelect(t.id),
                    onSecondaryTap: canManage && onManage != null
                        ? () => onManage!(t)
                        : null,
                  ),
                if (canManage && onCreate != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Semantics(
                      button: true,
                      label: AppLocalizations.of(context)!.desktopChatsNewTopic,
                      child: HoverListener(
                        onTap: onCreate,
                        builder: (ctx, hovered, pressed) => Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: hovered ? c.hover : Colors.transparent,
                            borderRadius: BorderRadius.circular(DRadii.md),
                            border: Border.all(
                              color: c.borderDivider,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Icon(
                            FluentIcons.add_24_regular,
                            size: 15,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: DSpace.s), trailing!],
        ],
      ),
    );
  }
}

/// Одна тема в горизонтальной полосе.
///
/// Непрочитанное показывается числом, а не точкой: в теме «сколько именно»
/// решает, идти туда сейчас или потом, и это ровно тот вопрос, ради которого
/// человек и смотрит на полосу.
class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.label,
    required this.selected,
    required this.unread,
    required this.colors,
    required this.onTap,
    this.emoji,
    this.markIcon,
    this.markColor,
    this.onSecondaryTap,
  });

  final String label;
  final bool selected;
  final int unread;
  final DColorSet colors;
  final VoidCallback onTap;
  final String? emoji;

  /// ◆ Значок перед названием: решётка или заменивший её знак. `null` — у
  /// «Общего»: общий поток не ветка, значка у него нет.
  final IconData? markIcon;

  /// Цвет значка. `null` — серый.
  final Color? markColor;

  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: HoverListener(
        onTap: onTap,
        onSecondaryTapDown: onSecondaryTap == null
            ? null
            : (_) => onSecondaryTap!(),
        builder: (ctx, hovered, pressed) => Container(
          height: 28,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? c.pressed
                : (hovered ? c.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(DRadii.md),
            border: Border.all(
              color: selected ? c.borderDivider : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ◆ ЗНАЧОК, ПОТОМ ИМЯ — один порядок с телефоном.
              //
              // Значок ровно один: решётка или то, чем её заменили. Раньше
              // решётку подменял эмодзи — и тема с эмодзи переставала
              // читаться веткой; теперь эмодзи идёт ПОСЛЕ значка и ничего не
              // отменяет.
              if (markIcon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    markIcon,
                    size: 14,
                    color: markColor ?? c.textTertiary,
                  ),
                ),
              if (emoji != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(emoji!, style: const TextStyle(fontSize: 13)),
                ),
              Text(
                label,
                style: DType.label.copyWith(
                  color: selected ? c.textPrimary : c.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 17,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accentPrimary,
                    borderRadius: BorderRadius.circular(DRadii.pill),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: DType.tiny.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
