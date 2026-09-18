// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../app/desktop_app_view_model.dart';
import '../../design/tokens.dart';
import 'contact_details_view.dart';
import 'desktop_selection_store.dart';
import 'member_profile_card.dart' show MemberProfileCard;
import 'room_details_view.dart';
import 'self_profile_view.dart';

/// Root of the third-column drawer.
///
/// Subscribes to [DesktopChatSelectionStore]. When there is no selection
/// (user opened the details panel without an active chat) renders a
/// friendly empty state. Otherwise routes to [ContactDetailsView] for 1:1
/// or [RoomDetailsView] for group conversations.
class DetailsDrawer extends StatelessWidget {
  const DetailsDrawer({
    super.key,
    required this.vm,
    required this.selection,
    required this.onClose,
    this.showSelfProfile = false,
    this.onCloseSelfProfile,
    this.onOpenDeviceSettings,
    this.onOpenProfileChat,
    this.onOpenAppearanceSettings,
  });

  /// The controller seam, handed down to the two detail views.
  final DesktopAppViewModel vm;
  final DesktopChatSelectionStore selection;
  final VoidCallback onClose;

  /// Показать МОЙ профиль вместо подробностей выбранной переписки.
  ///
  /// 🔴 Свой профиль — такой же профиль, как чужой, и открываться должен там
  /// же. Отдельная страница поверх окна закрывала переписку целиком ради
  /// того, чтобы поменять рамку.
  final bool showSelfProfile;
  final VoidCallback? onCloseSelfProfile;

  /// Открыть настройки на разделе устройств — см.
  /// [SelfProfileView.onOpenDeviceSettings].
  final VoidCallback? onOpenDeviceSettings;

  /// Открыть личную переписку с этим профилем, заведя её при необходимости.
  /// Нужен карточке участника комнаты — см. [MemberProfileCard].
  final ValueChanged<String>? onOpenProfileChat;

  /// Открыть настройки на разделе «Внешний вид» — см.
  /// [SelfProfileView.onOpenAppearanceSettings].
  final VoidCallback? onOpenAppearanceSettings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: selection,
      builder: (ctx, _) {
        final convo = selection.selected;
        Widget child;
        if (showSelfProfile) {
          child = SelfProfileView(
            key: const ValueKey('self-profile'),
            controller: vm.controller,
            onClose: onCloseSelfProfile ?? onClose,
            onOpenDeviceSettings: onOpenDeviceSettings,
            onOpenAppearanceSettings: onOpenAppearanceSettings,
          );
        } else if (convo == null) {
          child = const _DetailsEmpty(key: ValueKey('details-empty'));
        } else if (convo.peerProfileId == null) {
          child = RoomDetailsView(
            key: ValueKey('room-${convo.convoId}'),
            vm: vm,
            conversation: convo,
            onClose: onClose,
            topics: selection.topics,
            currentTopicId: selection.currentTopicId,
            baseTopicMark: selection.baseTopicMark,
            topicUnread: selection.topicUnread,
            topicLastActivityMs: selection.topicLastActivityMs,
            onSelectTopic: selection.onSelectTopic,
            onCreateTopic: selection.onCreateTopic,
            onOpenProfileChat: onOpenProfileChat,
          );
        } else {
          child = ContactDetailsView(
            key: ValueKey('contact-${convo.convoId}'),
            vm: vm,
            conversation: convo,
            onClose: onClose,
          );
        }
        return AnimatedSwitcher(
          duration: DMotion.fast,
          switchInCurve: DMotion.easeOutCubic,
          switchOutCurve: DMotion.easeInCubic,
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
          child: child,
        );
      },
    );
  }
}

class _DetailsEmpty extends StatelessWidget {
  const _DetailsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DSpace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.elevated,
                shape: BoxShape.circle,
                border: Border.all(color: c.borderSubtle),
              ),
              child: Icon(
                FluentIcons.info_24_regular,
                color: c.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(height: DSpace.m),
            Text(
              'Выберите чат',
              style: DType.title.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Сведения о собеседнике или комнате\nпоявятся здесь.',
              textAlign: TextAlign.center,
              style: DType.caption.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
