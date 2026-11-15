// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// «Новая тема» на компьютере: открытая или закрытая
/// (docs/TZ_ROOM_PRIVATE_TOPICS_2026-10-06.md). Тот же выбор, что на
/// телефоне (`ui/room_private_topic_ui.dart`), но в окне компьютера.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../rooms/room_models.dart';
import '../../room_private_topic_ui.dart' show NewRoomTopicChoice;
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../primitives/avatar.dart';
import '../primitives/desktop_dialog.dart';
import '../primitives/desktop_segmented.dart';
import '../primitives/desktop_text_field.dart';

Future<NewRoomTopicChoice?> showDesktopNewTopicDialog(
  BuildContext context, {
  required List<RoomMember> members,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final title = TextEditingController();
  final picked = <String>{};
  var isPrivate = false;

  NewRoomTopicChoice? build() {
    final t = title.text.trim();
    if (t.isEmpty) return null;
    return NewRoomTopicChoice(
      title: t,
      isPrivate: isPrivate,
      memberProfileIds: isPrivate
          ? picked.toList(growable: false)
          : const <String>[],
    );
  }

  final result = await DesktopDialog.show<NewRoomTopicChoice>(
    context,
    title: l10n.roomPrivateTopicNew,
    size: DDialogSize.small,
    body: StatefulBuilder(
      builder: (ctx, setLocal) {
        final c = DColors.of(ctx);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopTextField(
              controller: title,
              hintText: l10n.roomPrivateTopicTitleHint,
              autofocus: true,
              maxLength: 64,
              onSubmitted: (_) {
                final choice = build();
                if (choice != null) Navigator.of(ctx).maybePop(choice);
              },
            ),
            const SizedBox(height: DSpace.m),
            DesktopSegmented<bool>(
              values: const <bool>[false, true],
              labels: <String>[
                l10n.roomPrivateTopicOpen,
                l10n.roomPrivateTopicClosed,
              ],
              value: isPrivate,
              onChanged: (v) => setLocal(() => isPrivate = v),
            ),
            const SizedBox(height: DSpace.s),
            Text(
              isPrivate
                  ? l10n.roomPrivateTopicClosedHint
                  : l10n.roomPrivateTopicOpenHint,
              style: DType.caption.copyWith(color: c.textSecondary),
            ),
            if (isPrivate) ...[
              const SizedBox(height: DSpace.m),
              Text(
                picked.isEmpty
                    ? l10n.roomPrivateTopicOnlyYou
                    : l10n.roomPrivateTopicMembers,
                style: DType.label.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: DSpace.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in members)
                      InkWell(
                        onTap: () => setLocal(() {
                          if (!picked.remove(m.profileId)) {
                            picked.add(m.profileId);
                          }
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: DSpace.xs,
                          ),
                          child: Row(
                            children: [
                              Avatar(
                                name: m.displayName,
                                seed: m.profileId,
                                size: 28,
                                image: _avatarImage(m.avatarPath),
                              ),
                              const SizedBox(width: DSpace.s),
                              Expanded(
                                child: Text(
                                  m.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DType.body.copyWith(
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                              Checkbox(
                                value: picked.contains(m.profileId),
                                onChanged: (v) => setLocal(() {
                                  if (v ?? false) {
                                    picked.add(m.profileId);
                                  } else {
                                    picked.remove(m.profileId);
                                  }
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    ),
    primary: DDialogAction(
      label: l10n.roomPrivateTopicCreate,
      onPressed: () {
        final choice = build();
        if (choice != null) Navigator.of(context).maybePop(choice);
      },
    ),
    secondary: DDialogAction(
      label: l10n.cancel,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
  title.dispose();
  return result;
}

ImageProvider? _avatarImage(String? path) {
  final p = (path ?? '').trim();
  if (p.isEmpty || !File(p).existsSync()) return null;
  return FileImage(File(p));
}
