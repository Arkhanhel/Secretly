// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/avatar_initials.dart';
import '../design/tokens.dart';
import '../primitives/avatar.dart';
import '../primitives/hover_listener.dart';
import '../services/desktop_file_probe.dart';

/// Приглашение в комнату — для пузыря (29.09.2026).
///
/// 🔴 Жалоба владельца: «ссылки-приглашения в группы выглядят не так, как в
/// мобильной версии». ПК показывал голый адрес `links.secretlyapp.com/…` и
/// под ним карточку ссылки-заглушки «Join room in Secretly» — по-английски
/// при любом языке, а щелчок по ней открывал браузер. Телефон рисует карточку
/// комнаты с кнопкой «Вступить» (`_RoomInviteBubble`); здесь — она же.
///
/// Лента о контроллере не знает: данные сюда кладёт хозяин переписки, он же
/// их и подгружает у нашего реле (`resolveRoomInviteTarget`).
class DesktopRoomInviteView {
  const DesktopRoomInviteView({
    required this.slug,
    required this.inviterProfileId,
    this.groupIdHint,
    this.loaded = false,
    this.groupId,
    this.title = '',
    this.memberCount = 0,
    this.inviterName = '',
    this.alreadyMember = false,
    this.approvalRequired = false,
    this.requestPending = false,
    this.historyVisible = false,
    this.avatarBytes,
    this.avatarPath,
  });

  final String slug;
  final String inviterProfileId;
  final String? groupIdHint;

  /// Данные комнаты пришли. Пока нет — карточка с общей подписью.
  final bool loaded;
  final String? groupId;
  final String title;
  final int memberCount;
  final String inviterName;
  final bool alreadyMember;
  final bool approvalRequired;
  final bool requestPending;
  final bool historyVisible;

  /// Фото комнаты для того, кто в ней ещё не состоит: реле отдаёт байты.
  final Uint8List? avatarBytes;

  /// Фото комнаты, в которой я уже состою: лежит в кэше.
  final String? avatarPath;

  /// Ключ кэша: одна и та же ссылка в ленте встречается много раз.
  String get cacheKey => '$inviterProfileId|$slug';

  /// Семя цвета полоски и заглушки — как у телефона.
  String get seed => (groupId ?? groupIdHint ?? slug).trim();
}

/// Карточка приглашения — вид телефона (`_RoomInviteBubble`), размеры ПК.
class DesktopRoomInviteCard extends StatelessWidget {
  const DesktopRoomInviteCard({
    super.key,
    required this.invite,
    required this.isSelf,
    required this.foreground,
    this.onOpen,
  });

  final DesktopRoomInviteView invite;
  final bool isSelf;
  final Color foreground;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final fg = foreground;
    final title = invite.loaded && invite.title.trim().isNotEmpty
        ? invite.title.trim()
        : l10n.desktopRoomInviteCardTitle;
    final subtitle = invite.loaded
        ? <String>[
            l10n.desktopRoomMembersCount(invite.memberCount),
            invite.alreadyMember
                ? l10n.desktopRoomInviteAlreadyMember
                : (invite.approvalRequired
                      ? l10n.desktopRoomInviteApprovalRequired
                      : l10n.desktopRoomInviteDirectJoin),
            invite.historyVisible
                ? l10n.desktopRoomInviteWithHistory
                : l10n.desktopRoomInviteWithoutHistory,
          ].join(' • ')
        : l10n.desktopRoomInviteCardHint;
    final detail = invite.loaded
        ? <String>[
            if (invite.inviterName.trim().isNotEmpty)
              l10n.desktopRoomInviteInvitedBy(invite.inviterName.trim()),
            invite.historyVisible
                ? l10n.desktopRoomInviteHistoryOn
                : l10n.desktopRoomInviteHistoryOff,
          ].join(' • ')
        : '';
    final button = invite.alreadyMember
        ? l10n.desktopRoomInviteOpenRoom
        : invite.requestPending
        ? l10n.desktopRoomInviteOpenRequest
        : invite.approvalRequired
        ? l10n.desktopRoomInviteRequestAccess
        : l10n.desktopRoomInviteJoin;

    final labelColor = fg.withValues(alpha: isSelf ? 0.72 : 0.64);
    final detailColor = fg.withValues(alpha: isSelf ? 0.78 : 0.72);
    final panelColor = isSelf
        ? Colors.white.withValues(alpha: 0.16)
        : c.elevated.withValues(alpha: 0.82);
    final panelBorder = isSelf
        ? Colors.white.withValues(alpha: 0.12)
        : c.borderSubtle;
    final divider = isSelf
        ? Colors.white.withValues(alpha: 0.14)
        : c.borderSubtle;
    final accent = isSelf
        ? Colors.white.withValues(alpha: 0.92)
        : AvatarInitials.nicknameColor(
            seed: invite.seed,
          ).withValues(alpha: 0.88);
    final ImageProvider? photo = invite.avatarBytes != null
        ? MemoryImage(invite.avatarBytes!)
        : ((invite.avatarPath ?? '').isNotEmpty &&
                  DesktopFileProbe.exists(invite.avatarPath!)
              ? FileImage(File(invite.avatarPath!))
              : null);

    return Container(
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                Avatar(
                  name: title,
                  seed: invite.seed,
                  size: 40,
                  shape: AvatarShape.room,
                  image: photo,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DType.body.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DType.caption.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (detail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                detail,
                style: DType.caption.copyWith(
                  color: detailColor,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: divider,
          ),
          Semantics(
            button: true,
            label: button,
            excludeSemantics: true,
            child: HoverListener(
              onTap: onOpen,
              builder: (ctx, hovered, pressed) => Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hovered
                      ? fg.withValues(alpha: 0.06)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Text(
                  button.toUpperCase(),
                  style: DType.caption.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.55,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
