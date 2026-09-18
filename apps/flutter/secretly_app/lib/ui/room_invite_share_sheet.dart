// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'wave1_l10n.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/secretly_glass_sheet.dart';
import 'widgets/broken_media_box.dart';

String _roomInviteText(
  BuildContext context, {
  required String ru,
  required String en,
  String? uk,
  String? es,
  String? pt,
  String? ptBr,
  String? fr,
  String? de,
}) {
  return wave1Text(
    context,
    ru: ru,
    en: en,
    uk: uk,
    es: es,
    pt: pt,
    ptBr: ptBr,
    fr: fr,
    de: de,
  );
}

Future<Conversation?> showRoomInviteShareSheet(
  BuildContext context, {
  required AppController controller,
  required String groupId,
  required String title,
  String? avatarPath,
}) {
  return showModalBottomSheet<Conversation>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (context) {
      return _RoomInviteShareSheet(
        controller: controller,
        groupId: groupId,
        title: title,
        avatarPath: avatarPath,
      );
    },
  );
}

class _RoomInviteShareSheet extends StatefulWidget {
  const _RoomInviteShareSheet({
    required this.controller,
    required this.groupId,
    required this.title,
    this.avatarPath,
  });

  final AppController controller;
  final String groupId;
  final String title;
  final String? avatarPath;

  @override
  State<_RoomInviteShareSheet> createState() => _RoomInviteShareSheetState();
}

class _RoomInviteShareSheetState extends State<_RoomInviteShareSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Future<_RoomInviteShareSheetVm> _vmFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _vmFuture = _loadVm();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_RoomInviteShareSheetVm> _loadVm() async {
    final conversations = await widget.controller.listConversations();
    final visible = conversations
        .where((conversation) => conversation.archivedAtMs == null)
        .where((conversation) => !conversation.convoId.startsWith('req:'))
        .where(
          (conversation) =>
              !widget.controller.isSavedMessagesConvo(conversation.convoId),
        )
        .toList(growable: false);

    final chats = visible
        .where((conversation) => !conversation.convoId.startsWith('group:'))
        .toList(growable: false);
    final rooms = visible
        .where((conversation) => conversation.convoId.startsWith('group:'))
        .where((conversation) => conversation.convoId != widget.groupId)
        .toList(growable: false);

    return _RoomInviteShareSheetVm(chats: chats, rooms: rooms);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, safeBottom > 0 ? 8 : 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 720),
          child: SecretlyGlassSheetSurface(
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Stack(
                    children: <Widget>[
                      const Align(
                        alignment: Alignment.topCenter,
                        child: SecretlyGlassSheetHandle(),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(AppIcons.close),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _RoomInviteHeader(
                    title: widget.title,
                    groupId: widget.groupId,
                    avatarPath: widget.avatarPath,
                  ),
                  const SizedBox(height: 16),
                  _RoomInviteTabs(tabController: _tabController),
                  const SizedBox(height: 12),
                  Flexible(
                    child: FutureBuilder<_RoomInviteShareSheetVm>(
                      future: _vmFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            ),
                          );
                        }

                        final vm = snapshot.data!;
                        return TabBarView(
                          controller: _tabController,
                          children: <Widget>[
                            _RoomInviteConversationTab(
                              conversations: vm.chats,
                              emptyLabel: context.l10n.noChatsYet,
                            ),
                            _RoomInviteConversationTab(
                              conversations: vm.rooms,
                              emptyLabel: _roomInviteText(
                                context,
                                ru: 'Других комнат пока нет',
                                en: 'No other rooms yet',
                                uk: 'Інших кімнат поки немає',
                                es: 'No hay otras salas todavia',
                                pt: 'Ainda nao ha outras salas',
                                fr: 'Aucun autre salon pour le moment',
                                de: 'Noch keine anderen Räume',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomInviteShareSheetVm {
  const _RoomInviteShareSheetVm({required this.chats, required this.rooms});

  final List<Conversation> chats;
  final List<Conversation> rooms;
}

class _RoomInviteHeader extends StatelessWidget {
  const _RoomInviteHeader({
    required this.title,
    required this.groupId,
    this.avatarPath,
  });

  final String title;
  final String groupId;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.2,
    );
    return Row(
      children: <Widget>[
        _RoomInviteConversationAvatar(
          title: title,
          avatarPath: avatarPath,
          seed: groupId,
          size: 46,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _roomInviteText(
                  context,
                  ru: 'Пригласить в комнату',
                  en: 'Invite to room',
                  uk: 'Запросити до кімнати',
                  es: 'Invitar a la sala',
                  pt: 'Convidar para a sala',
                  fr: 'Inviter au salon',
                  de: 'In Raum einladen',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: subtitleStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoomInviteTabs extends StatelessWidget {
  const _RoomInviteTabs({required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        tabs: <Widget>[
          Tab(
            text: _roomInviteText(context, ru: 'Чаты', en: 'Chats'),
          ),
          Tab(
            text: _roomInviteText(context, ru: 'Комнаты', en: 'Rooms'),
          ),
        ],
      ),
    );
  }
}

class _RoomInviteConversationTab extends StatelessWidget {
  const _RoomInviteConversationTab({
    required this.conversations,
    required this.emptyLabel,
  });

  final List<Conversation> conversations;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: conversations.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 68,
        endIndent: 8,
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.28),
      ),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final subtitle = conversation.convoId.startsWith('group:')
            ? _roomInviteText(context, ru: 'Комната', en: 'Room')
            : (conversation.peerLastSeenAtMs != null && conversation.isOnline
                  ? _roomInviteText(context, ru: 'Онлайн', en: 'Online')
                  : _roomInviteText(
                      context,
                      ru: 'Личный чат',
                      en: 'Private chat',
                      uk: 'Особистий чат',
                      es: 'Chat privado',
                      pt: 'Chat privado',
                      ptBr: 'Conversa privada',
                      fr: 'Chat prive',
                      de: 'Privater Chat',
                    ));
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          leading: _RoomInviteConversationAvatar(
            title: conversation.title,
            avatarPath: conversation.avatarPath,
            seed: conversation.peerProfileId ?? conversation.convoId,
          ),
          title: Text(
            conversation.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(AppIcons.send, size: 18),
          onTap: () => Navigator.of(context).pop(conversation),
        );
      },
    );
  }
}

class _RoomInviteConversationAvatar extends StatelessWidget {
  const _RoomInviteConversationAvatar({
    required this.title,
    required this.seed,
    this.avatarPath,
    this.size = 44,
  });

  final String title;
  final String seed;
  final String? avatarPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = avatarPath?.trim();
    final hasAvatar =
        path != null && path.isNotEmpty && File(path).existsSync();
    if (hasAvatar) {
      return ClipOval(
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 16, rounded: true),
        ),
      );
    }

    return AvatarInitials.fallbackBubble(
      context: context,
      radius: size / 2,
      seed: seed,
      displayName: title,
      fallbackId: seed,
      labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontSize: size * 0.34,
      ),
    );
  }
}
