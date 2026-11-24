// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Новая тема комнаты на телефоне: открытая или закрытая
/// (docs/TZ_ROOM_PRIVATE_TOPICS_2026-10-06.md).
///
/// Закрытая тема — отдельная комната со своим составом и ключом: её
/// сообщения получают только приглашённые. Пригласить можно только
/// участников самой комнаты. Кто не может создавать закрытые темы (Р-2),
/// этого листа не видит — у него прежний вопрос о названии.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../rooms/room_models.dart';
import 'motion/app_dialogs.dart';
import 'motion/press_feedback.dart';
import 'widgets/avatar_initials.dart';
import 'package:secretly_app/ui/icons/adaptive_icons.dart';

/// Что выбрал человек.
class NewRoomTopicChoice {
  const NewRoomTopicChoice({
    required this.title,
    required this.isPrivate,
    this.memberProfileIds = const <String>[],
  });

  final String title;
  final bool isPrivate;
  final List<String> memberProfileIds;
}

/// Лист «Новая тема». [members] — действующие участники комнаты, кроме меня.
Future<NewRoomTopicChoice?> showNewRoomTopicSheet(
  BuildContext context, {
  required List<RoomMember> members,
}) {
  return showModalBottomSheet<NewRoomTopicChoice>(
  sheetAnimationStyle: appSheetAnimationStyle,
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _NewRoomTopicSheet(members: members),
  );
}

class _NewRoomTopicSheet extends StatefulWidget {
  const _NewRoomTopicSheet({required this.members});

  final List<RoomMember> members;

  @override
  State<_NewRoomTopicSheet> createState() => _NewRoomTopicSheetState();
}

class _NewRoomTopicSheetState extends State<_NewRoomTopicSheet> {
  final TextEditingController _title = TextEditingController();
  final Set<String> _picked = <String>{};
  bool _private = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      NewRoomTopicChoice(
        title: title,
        isPrivate: _private,
        memberProfileIds: _private
            ? _picked.toList(growable: false)
            : const <String>[],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                l10n.roomPrivateTopicNew,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _title,
                autofocus: true,
                maxLength: 64,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: l10n.roomPrivateTopicTitleHint,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 8),
            _KindTile(
              icon: AdaptiveIcons.tag_rounded,
              title: l10n.roomPrivateTopicOpen,
              hint: l10n.roomPrivateTopicOpenHint,
              selected: !_private,
              onTap: () => setState(() => _private = false),
            ),
            _KindTile(
              icon: AdaptiveIcons.lock_rounded,
              title: l10n.roomPrivateTopicClosed,
              hint: l10n.roomPrivateTopicClosedHint,
              selected: _private,
              onTap: () => setState(() => _private = true),
            ),
            if (_private) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  _picked.isEmpty
                      ? l10n.roomPrivateTopicOnlyYou
                      : l10n.roomPrivateTopicMembers,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final member in widget.members)
                      CheckboxListTile.adaptive(
                        value: _picked.contains(member.profileId),
                        onChanged: (checked) => setState(() {
                          if (checked ?? false) {
                            _picked.add(member.profileId);
                          } else {
                            _picked.remove(member.profileId);
                          }
                        }),
                        secondary: _MemberAvatar(member: member),
                        title: Text(
                          member.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                      ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: PressFeedback(child: FilledButton(
                onPressed: _title.text.trim().isEmpty ? null : _submit,
                child: Text(l10n.roomPrivateTopicCreate),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.icon,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(hint),
      trailing: Icon(
        selected
            ? AdaptiveIcons.radio_button_checked_rounded
            : AdaptiveIcons.radio_button_off_rounded,
        color: selected ? cs.primary : cs.onSurfaceVariant,
      ),
      selected: selected,
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member});

  final RoomMember member;

  @override
  Widget build(BuildContext context) {
    final path = member.avatarPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return CircleAvatar(radius: 18, backgroundImage: FileImage(File(path)));
    }
    return AvatarInitials.fallbackBubble(
      context: context,
      radius: 18,
      seed: member.profileId,
      displayName: member.displayName,
      fallbackId: member.profileId,
    );
  }
}
