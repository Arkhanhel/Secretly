// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../design/tokens.dart';
import '../../primitives/avatar.dart';
import '../../primitives/hover_listener.dart';

/// Карточка участника комнаты — всплывает по щелчку в списке.
///
/// 🔴 ПО УЧАСТНИКУ НЕЛЬЗЯ БЫЛО ЩЁЛКНУТЬ ВООБЩЕ.
///
/// В строке был только правый щелчок с меню управления: левым не открывалось
/// НИЧЕГО, и курсор над строкой был принудительно обычной стрелкой — то есть
/// список честно сообщал, что нажимать тут не на что. Узнать, кто этот
/// человек, и написать ему из комнаты было нечем: приходилось искать его имя
/// в общем списке чатов, а если переписки ещё нет — там его и не было.
///
/// 🔴 ЧЕГО ЗДЕСЬ НЕТ, ХОТЯ В МАКЕТЕ ЕСТЬ, И ПОЧЕМУ.
///
/// В макете у карточки строка «@nathan · CORE» моноширинным, галочка проверки
/// у имени, чипы «relay» и «Рамка «Неон»», кнопки звонка и видео.
///
///   • `@handle` в проекте НЕТ НИ У КОГО — ни в одной модели профиля нет
///     такого поля. Вместо выдуманного псевдонима стоит настоящий
///     идентификатор: он и есть то, чем человек делится.
///   • Галочка проверки означала бы «я сверил ключи с этим человеком», а у
///     участника комнаты этого признака в модели нет. Рисовать её по чему-то
///     другому — ложное обещание безопасности, и ровно за это её уже снимали
///     с признака подписки.
///   • Чипы «relay» и «Рамка» — украшения профиля, которых состав комнаты не
///     знает: `RoomMember` несёт имя, портрет, роль и присутствие.
///   • Кнопок звонка и видео нет намеренно. Позвонить можно только В
///     ПЕРЕПИСКЕ, а её с этим человеком может ещё не существовать: кнопка
///     сперва завела бы чат и всё равно привела бы туда же, куда «Написать».
///     Две кнопки с одним исходом — это не выбор, а путаница.
///
/// Управление участником (роль, исключить, забанить) сюда НЕ дублируется: оно
/// уже есть в самой строке — видимым многоточием и правым щелчком.
class MemberProfileCard extends StatelessWidget {
  const MemberProfileCard({
    super.key,
    required this.name,
    required this.profileId,
    required this.avatarPath,
    required this.isOnline,
    this.roleLabel,
    this.statusNote,
    required this.onWrite,
    required this.onCopyId,
  });

  final String name;
  final String profileId;
  final String? avatarPath;
  final bool isOnline;

  /// «Владелец», «Админ»… У обычного участника — `null`, и строка роли не
  /// рисуется: подпись «участник» в списке участников ничего не добавляет.
  final String? roleLabel;

  /// «Ждёт одобрения», «Заблокирован» — состояние членства, если оно не
  /// обычное. Молчать о нём нельзя: карточка предлагает написать человеку,
  /// которого в комнате, строго говоря, ещё (или уже) нет.
  final String? statusNote;

  final VoidCallback onWrite;
  final VoidCallback onCopyId;

  /// Ширина из макета — её же передаёт вызывающий в [DesktopPopover].
  static const double width = 296;

  static const double _kCoverHeight = 84;
  static const double _kAvatarSize = 64;

  /// Насколько портрет свешивается ниже обложки.
  static const double _kAvatarOverlap = 32;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final displayName = name.trim().isEmpty ? profileId : name.trim();
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.chatList,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderSubtle),
        boxShadow: DShadows.dialog,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Обложка — ГРАДИЕНТ ИНТЕРФЕЙСА, а не чужая картинка.
          //
          // Своей обложки у участника комнаты в модели нет. Показать здесь
          // что-то похожее на его фон значило бы выдать оформление окна за
          // его профиль; спокойная акцентная полоса такого не обещает.
          //
          // Портрет ВЫХОДИТ за нижний край обложки — это [Stack] с
          // `Clip.none`, а не сдвиг готовой колонки: сдвиг не меняет разметку
          // и оставлял бы у карточки снизу пустую полосу в те же 26 точек.
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: _kCoverHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        c.accentPrimary.withValues(alpha: 0.35),
                        c.accentPrimaryAlt.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                top: _kCoverHeight - _kAvatarOverlap,
                child: Avatar(
                  name: displayName,
                  image: Avatar.fileImage(avatarPath),
                  size: _kAvatarSize,
                  // Без точки: «в сети» написано строкой ниже — как и в
                  // профиле собеседника (указание владельца 16.09.2026).
                  online: false,
                  ringColor: c.chatList,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              // Ровно столько, сколько портрет свесил вниз, плюс дыхание.
              _kAvatarOverlap + DSpace.s,
              14,
              14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DType.bodyStrong.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                // Идентификатор моноширинным — как все технические значения
                // в макете. Рядом роль, если она есть.
                Text(
                  roleLabel == null
                      ? profileId
                      : '$profileId · ${roleLabel!.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DType.mono.copyWith(color: c.textTertiary),
                ),
                const SizedBox(height: 3),
                Text(
                  isOnline ? l10n.desktopChatsOnline : l10n.desktopContactOffline,
                  style: DType.caption.copyWith(
                    color: isOnline ? c.voice : c.textSecondary,
                  ),
                ),
                if (statusNote != null && statusNote!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _StatusNote(text: statusNote!),
                ],
                const SizedBox(height: DSpace.m),
                Container(height: 1, color: c.borderSubtle),
                const SizedBox(height: DSpace.m),
                Row(
                  children: [
                    Expanded(child: _WriteButton(onTap: onWrite)),
                    const SizedBox(width: DSpace.s),
                    _CardIconButton(
                      icon: FluentIcons.copy_24_regular,
                      tooltip: l10n.desktopContactCopyIdShort,
                      onTap: onCopyId,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «Ждёт одобрения» / «Заблокирован» — предупреждение, а не подпись.
class _StatusNote extends StatelessWidget {
  const _StatusNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: DType.tiny.copyWith(
          fontSize: 10.5,
          color: c.warning,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// «Написать» — градиентом из макета: это главное действие карточки.
class _WriteButton extends StatelessWidget {
  const _WriteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      cursor: SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // 150° из макета: сверху-справа вниз-влево.
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [c.accentPrimary, c.accentPrimaryAlt],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: hovered
              ? [
                  BoxShadow(
                    color: c.accentPrimary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              FluentIcons.chat_24_regular,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 7),
            Text(
              l10n.desktopMemberWrite,
              style: DType.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: HoverListener(
        onTap: onTap,
        cursor: SystemMouseCursors.click,
        builder: (ctx, hovered, pressed) => Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovered ? c.hover : c.elevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.borderSubtle),
          ),
          child: Icon(icon, size: 17, color: c.textPrimary),
        ),
      ),
    );
  }
}
