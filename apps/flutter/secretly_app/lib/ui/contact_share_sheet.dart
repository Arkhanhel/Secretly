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

String _contactShareText(
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

class ContactShareSheetAction {
  const ContactShareSheetAction._({
    this.conversation,
    this.externalShare = false,
  });

  const ContactShareSheetAction.externalShare() : this._(externalShare: true);

  const ContactShareSheetAction.sendToConversation(Conversation conversation)
    : this._(conversation: conversation);

  final Conversation? conversation;
  final bool externalShare;
}

Future<ContactShareSheetAction?> showContactShareSheet(
  BuildContext context, {
  required AppController controller,
  required String profileId,
  required String title,
  String? avatarPath,
}) {
  return showModalBottomSheet<ContactShareSheetAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (context) {
      return _ContactShareSheet(
        controller: controller,
        profileId: profileId,
        title: title,
        avatarPath: avatarPath,
      );
    },
  );
}

class _ContactShareSheet extends StatefulWidget {
  const _ContactShareSheet({
    required this.controller,
    required this.profileId,
    required this.title,
    this.avatarPath,
  });

  final AppController controller;
  final String profileId;
  final String title;
  final String? avatarPath;

  @override
  State<_ContactShareSheet> createState() => _ContactShareSheetState();
}

class _ContactShareSheetState extends State<_ContactShareSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Future<_ContactShareSheetVm> _vmFuture;

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

  Future<_ContactShareSheetVm> _loadVm() async {
    final conversations = await widget.controller.listConversations();
    final visible = conversations
        .where((conversation) => conversation.archivedAtMs == null)
        .where((conversation) => !conversation.convoId.startsWith('req:'))
        .toList(growable: false);

    final chats = visible
        .where((conversation) => !conversation.convoId.startsWith('group:'))
        .toList(growable: false);
    final rooms = visible
        .where((conversation) => conversation.convoId.startsWith('group:'))
        .toList(growable: false);

    return _ContactShareSheetVm(chats: chats, rooms: rooms);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    // Во всю ширину и до низа экрана. Ограничение по ширине в 720 остаётся: на
    // планшете и десктопе лист во весь экран читался бы хуже, чем колонка.
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 720),
        child: SecretlyGlassSheetSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          flushToEdges: true,
          child: Padding(
            // Отступ под системную панель переехал СЮДА: поверхность уходит за
            // неё, а содержимое обязано остаться выше.
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + safeBottom),
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
                _SharedContactHeader(
                  title: widget.title,
                  profileId: widget.profileId,
                  avatarPath: widget.avatarPath,
                ),
                const SizedBox(height: 16),
                _ExternalShareButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop(const ContactShareSheetAction.externalShare());
                  },
                ),
                const SizedBox(height: 14),
                _ShareSheetTabs(tabController: _tabController),
                const SizedBox(height: 12),
                Flexible(
                  child: FutureBuilder<_ContactShareSheetVm>(
                    future: _vmFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        );
                      }

                      final vm = snapshot.data!;
                      return TabBarView(
                        controller: _tabController,
                        children: <Widget>[
                          _ConversationTab(
                            conversations: vm.chats,
                            emptyLabel: context.l10n.noChatsYet,
                          ),
                          _ConversationTab(
                            conversations: vm.rooms,
                            emptyLabel: _contactShareText(
                              context,
                              ru: 'Комнат пока нет',
                              en: 'No rooms yet',
                              uk: 'Кімнат поки немає',
                              es: 'Aun no hay salas',
                              pt: 'Ainda nao ha salas',
                              fr: 'Aucun salon pour le moment',
                              de: 'Noch keine Räume',
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
    );
  }
}

class _ContactShareSheetVm {
  const _ContactShareSheetVm({required this.chats, required this.rooms});

  final List<Conversation> chats;
  final List<Conversation> rooms;
}

class _SharedContactHeader extends StatelessWidget {
  const _SharedContactHeader({
    required this.title,
    required this.profileId,
    this.avatarPath,
  });

  final String title;
  final String profileId;
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
        _ConversationAvatar(
          title: title,
          avatarPath: avatarPath,
          seed: profileId,
          size: 46,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.contactDetailsShareContact,
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

class _ExternalShareButton extends StatelessWidget {
  const _ExternalShareButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(AppIcons.forward),
        label: Text(context.l10n.chatMenuForward),
      ),
    );
  }
}

class _ShareSheetTabs extends StatelessWidget {
  const _ShareSheetTabs({required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: TabBar(
        controller: tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        labelColor: colors.onSurface,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        tabs: <Widget>[
          Tab(text: context.l10n.tabChats),
          Tab(text: context.l10n.tabGroups),
        ],
      ),
    );
  }
}

class _ConversationTab extends StatelessWidget {
  const _ConversationTab({
    required this.conversations,
    required this.emptyLabel,
  });

  final List<Conversation> conversations;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _ConversationTile(conversation: conversation);
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final subtitle = conversation.convoId.startsWith('group:')
        ? _contactShareText(context, ru: 'Комната', en: 'Room')
        : _contactShareText(context, ru: 'Чат', en: 'Chat');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(
            context,
          ).pop(ContactShareSheetAction.sendToConversation(conversation));
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: <Widget>[
              _ConversationAvatar(
                title: conversation.title,
                avatarPath: conversation.avatarPath,
                seed: conversation.peerProfileId ?? conversation.convoId,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 1, style: subtitleStyle),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.forward, size: 18, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({
    required this.title,
    required this.seed,
    required this.size,
    this.avatarPath,
  });

  final String title;
  final String seed;
  final double size;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final resolvedPath = avatarPath?.trim();
    final hasAvatar =
        resolvedPath != null &&
        resolvedPath.isNotEmpty &&
        File(resolvedPath).existsSync();
    if (hasAvatar) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: FileImage(File(resolvedPath)),
      );
    }

    return AvatarInitials.fallbackBubble(
      context: context,
      radius: size / 2,
      seed: seed,
      displayName: title,
      fallbackId: seed,
      labelStyle: Theme.of(context).textTheme.titleSmall,
    );
  }
}
