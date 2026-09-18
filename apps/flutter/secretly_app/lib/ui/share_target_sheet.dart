// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/platform_share_target.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/secretly_glass_sheet.dart';
import 'widgets/broken_media_box.dart';

Future<Conversation?> showShareTargetConversationSheet({
  required BuildContext context,
  required AppController controller,
  required PlatformSharePayload payload,
}) {
  return showModalBottomSheet<Conversation>(
    context: context,
    isScrollControlled: true,
    // Лист уходит ЗА системную панель; отступ под неё даёт список внутри.
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (context) =>
        _ShareTargetConversationSheet(controller: controller, payload: payload),
  );
}

class _ShareTargetConversationSheet extends StatefulWidget {
  const _ShareTargetConversationSheet({
    required this.controller,
    required this.payload,
  });

  final AppController controller;
  final PlatformSharePayload payload;

  @override
  State<_ShareTargetConversationSheet> createState() =>
      _ShareTargetConversationSheetState();
}

class _ShareTargetConversationSheetState
    extends State<_ShareTargetConversationSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _payloadSummary(widget.payload);

    return FractionallySizedBox(
      heightFactor: 0.88,
      alignment: Alignment.bottomCenter,
      child: SecretlyGlassSheetSurface(
        flushToEdges: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Отправить в Secretly',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(FluentIcons.dismiss_24_regular),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Поиск',
                  prefixIcon: const Icon(FluentIcons.search_24_regular),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.62),
                ),
              ),
            ),
            Flexible(
              child: StreamBuilder<void>(
                stream: widget.controller.changed,
                builder: (context, _) {
                  return FutureBuilder<List<Conversation>>(
                    future: widget.controller.listConversations(),
                    builder: (context, snapshot) {
                      final conversations = _filterConversations(
                        snapshot.data ?? const <Conversation>[],
                      );
                      if (conversations.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                          child: Text(
                            'Нет подходящих чатов',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          18 + MediaQuery.paddingOf(context).bottom,
                        ),
                        itemCount: conversations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          final isRoom = conversation.convoId.startsWith(
                            'group:',
                          );
                          final seed =
                              conversation.peerProfileId ??
                              conversation.convoId;
                          return ListTile(
                            minLeadingWidth: 44,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: _ShareTargetAvatar(
                              title: conversation.title,
                              seed: seed,
                              avatarPath: conversation.avatarPath,
                            ),
                            title: Text(
                              conversation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(isRoom ? 'Комната' : 'Чат'),
                            trailing: Icon(
                              FluentIcons.send_24_regular,
                              color: theme.colorScheme.primary,
                            ),
                            onTap: () =>
                                Navigator.of(context).pop(conversation),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Conversation> _filterConversations(List<Conversation> conversations) {
    final query = _query.toLowerCase();
    return conversations
        .where((conversation) {
          if (conversation.archivedAtMs != null) return false;
          if (conversation.convoId.startsWith('req:')) return false;
          if (query.isEmpty) return true;
          return conversation.title.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }
}

class _ShareTargetAvatar extends StatelessWidget {
  const _ShareTargetAvatar({
    required this.title,
    required this.seed,
    this.avatarPath,
  });

  final String title;
  final String seed;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    const size = 42.0;
    final path = avatarPath?.trim();
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipOval(
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) =>
              const BrokenMediaBox(iconSize: 16, rounded: true),
        ),
      );
    }

    return AvatarInitials.fallbackBubble(
      context: context,
      radius: size / 2,
      seed: seed,
      displayName: title,
      fallbackId: seed,
      labelStyle: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontSize: size * 0.34),
    );
  }
}

String _payloadSummary(PlatformSharePayload payload) {
  final files = payload.files.length;
  final hasText = (payload.text ?? '').trim().isNotEmpty;
  if (files == 0 && hasText) return 'Текст';
  if (files == 1 && !hasText) return payload.files.first.name ?? '1 файл';
  if (files == 1 && hasText) {
    return '${payload.files.first.name ?? '1 файл'} и текст';
  }
  if (files > 1 && !hasText) return '$files файла';
  if (files > 1 && hasText) return '$files файла и текст';
  return '';
}
