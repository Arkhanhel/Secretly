// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_controller.dart';
import '../billing/show_paywall.dart';
import '../entitlements/feature_gate.dart';
import '../rooms/room_call_state.dart';
import '../rooms/room_membership_failure.dart';
import '../rooms/room_policy_failure.dart';
import '../calls/call_manager.dart';
import 'animations/animations.dart';
import 'call_error_text.dart';
import 'chat_screen.dart';
import 'contact_details_screen.dart';
import 'cover_crop_screen.dart';
import 'fullscreen_image_viewer.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'paywall_screen.dart' show PaywallTrigger;
import 'premium/cosmetic_animation_scope.dart';
import 'premium/cosmetics_catalog.dart';
import 'profile_icon_picker_screen.dart';
import 'report_abuse_sheet.dart';
import 'room_membership_error_text.dart';
import 'room_call_screen.dart';
import 'theme_presets.dart';
import 'room_invite_join_screen.dart';
import 'room_invite_share_sheet.dart';
import 'room_l10n_bridge.dart';
import 'room_policy_error_text.dart';
import 'share_utils.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/app_background.dart';
import 'widgets/conversation_media_gallery.dart';
import 'widgets/frosted_header_island.dart';
import 'widgets/frosted_top_bar.dart';
import 'widgets/secretly_glass_sheet.dart';
import 'widgets/broken_media_box.dart';
import 'haptics.dart';

String _roomText(
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
  return roomText(
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

String _roomTextByLocale(
  String localeTag, {
  required String ru,
  required String en,
  String? uk,
  String? es,
  String? pt,
  String? ptBr,
  String? fr,
  String? de,
}) {
  return roomTextForLocale(
    localeTag,
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

String _roomLocaleTagForRuFlag(bool isRu) {
  if (isRu) return 'ru';
  return 'en';
}

/// Текст отказа при действии с участником.
///
/// 🔴 Тело переехало в `room_membership_error_text.dart` 13.09.2026, чтобы тот
/// же текст мог показывать десктоп. Фразы, языки и порядок разбора — те же:
/// здесь остался только вызов, ни одна строка не переписана.
String? _tryRoomMembershipErrorText(BuildContext context, Object error) =>
    tryRoomMembershipErrorText(context, error);

void _showRoomActionError(BuildContext context, Object error) {
  final text =
      tryRoomPolicyErrorText(context.l10n, error) ??
      _tryRoomMembershipErrorText(context, error) ??
      context.l10n.actionFailed(error.toString());
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SecretlySnackBar(content: Text(text)));
}

String _roomRoleLabel({
  required bool isRu,
  required RoomMemberRole role,
  String? localeTag,
}) {
  final resolvedLocaleTag = localeTag ?? _roomLocaleTagForRuFlag(isRu);
  return switch (role) {
    RoomMemberRole.owner => _roomTextByLocale(
      resolvedLocaleTag,
      ru: 'Владелец',
      en: 'Owner',
    ),
    RoomMemberRole.admin => _roomTextByLocale(
      resolvedLocaleTag,
      ru: 'Администратор',
      en: 'Admin',
    ),
    RoomMemberRole.moderator => _roomTextByLocale(
      resolvedLocaleTag,
      ru: 'Модератор',
      en: 'Moderator',
    ),
    RoomMemberRole.member => _roomTextByLocale(
      resolvedLocaleTag,
      ru: 'Участник',
      en: 'Member',
    ),
    RoomMemberRole.restricted => _roomTextByLocale(
      resolvedLocaleTag,
      ru: 'Ограниченный участник',
      en: 'Restricted member',
    ),
    RoomMemberRole.guest => _roomTextByLocale(
      resolvedLocaleTag,
      ru: 'Только чтение',
      en: 'Read-only member',
    ),
  };
}

String _roomMemberRoleLabel({
  required bool isRu,
  required RoomMember member,
  String? localeTag,
}) {
  return _roomRoleLabel(isRu: isRu, role: member.role, localeTag: localeTag);
}

String _roomMemberStatusLabel({
  required bool isRu,
  required RoomMember member,
  String? localeTag,
}) {
  final resolvedLocaleTag = localeTag ?? _roomLocaleTagForRuFlag(isRu);
  if (member.isPending) {
    return _roomTextByLocale(
      resolvedLocaleTag,
      ru: 'Ожидает одобрения',
      en: 'Pending approval',
    );
  }
  if (member.isBanned) {
    return _roomTextByLocale(
      resolvedLocaleTag,
      ru: 'Заблокирован',
      en: 'Banned',
    );
  }
  return _roomMemberRoleLabel(
    isRu: isRu,
    member: member,
    localeTag: resolvedLocaleTag,
  );
}

String? _roomMemberTag(RoomMember member) {
  final tag = member.tag?.trim();
  return tag == null || tag.isEmpty ? null : tag;
}

String _roomMemberSubtitle({
  required bool isRu,
  required RoomMember member,
  String? localeTag,
  bool includeProfileId = false,
}) {
  final resolvedLocaleTag = localeTag ?? _roomLocaleTagForRuFlag(isRu);
  final parts = <String>[
    _roomMemberStatusLabel(
      isRu: isRu,
      member: member,
      localeTag: resolvedLocaleTag,
    ),
  ];
  final tag = _roomMemberTag(member);
  if (tag != null) {
    parts.add(tag);
  }
  if (includeProfileId) {
    parts.add(member.profileId);
  }
  return parts.join(' • ');
}

String _roomRoleLabelForContext(BuildContext context, RoomMemberRole role) {
  return _roomRoleLabel(
    isRu: roomLocaleIsRussian(context),
    role: role,
    localeTag: roomLocaleTagFromContext(context),
  );
}

String _roomMemberSubtitleForContext(
  BuildContext context,
  RoomMember member, {
  bool includeProfileId = false,
}) {
  return _roomMemberSubtitle(
    isRu: roomLocaleIsRussian(context),
    member: member,
    localeTag: roomLocaleTagFromContext(context),
    includeProfileId: includeProfileId,
  );
}

bool _canManageRoomAdministration(RoomPolicyState policy) {
  return policy.canManageSettings ||
      policy.canManageInviteLinks ||
      policy.canManageAdmins ||
      policy.canManageMemberRoles;
}

int _roomPermissionsEnabledCount(RoomSettings settings) {
  final values = [
    settings.allowTextMessages,
    settings.allowMedia,
    settings.allowPinMessages,
    settings.allowAddMembers,
    settings.joinApprovalRequired,
    settings.chatHistoryVisible,
    settings.allowChangeGroupInfo,
    settings.allowChangeTag,
  ];
  return values.where((v) => v).length;
}

String _roomReactionModeLabel(RoomReactionsMode mode, bool ru) {
  final localeTag = _roomLocaleTagForRuFlag(ru);
  switch (mode) {
    case RoomReactionsMode.all:
      return _roomTextByLocale(localeTag, ru: 'Все', en: 'All');
    case RoomReactionsMode.selected:
      return _roomTextByLocale(
        localeTag,
        ru: 'Только выбранные',
        en: 'Selected only',
      );
    case RoomReactionsMode.none:
      return _roomTextByLocale(
        localeTag,
        ru: 'Без реакций',
        en: 'No reactions',
      );
  }
}

String _roomReactionModeLabelForContext(
  BuildContext context,
  RoomReactionsMode mode,
) {
  return _roomTextByLocale(
    roomLocaleTagFromContext(context),
    ru: _roomReactionModeLabel(mode, true),
    en: _roomReactionModeLabel(mode, false),
  );
}

Future<String?> _pickNextRoomOwnerDialog(
  BuildContext context, {
  required bool isRu,
  required List<RoomMember> members,
  required String currentProfileId,
}) async {
  final candidates = members
      .where(
        (member) => member.profileId != currentProfileId && member.isActive,
      )
      .toList(growable: false);
  if (candidates.isEmpty) {
    return null;
  }
  final localeTag = roomLocaleTagFromContext(context);
  var selectedProfileId = candidates.first.profileId;
  return showDialog<String>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: Text(
              _roomText(
                context,
                ru: 'Передать владение комнатой',
                en: 'Transfer room ownership',
              ),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _roomText(
                      context,
                      ru: 'Выберите нового владельца, затем можно будет покинуть комнату.',
                      en: 'Choose the next owner before leaving this room.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final candidate in candidates)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        candidate.profileId == selectedProfileId
                            ? AppIcons.radioChecked
                            : AppIcons.radioUnchecked,
                      ),
                      title: Text(candidate.displayName),
                      subtitle: Text(
                        _roomMemberRoleLabel(
                          isRu: isRu,
                          member: candidate,
                          localeTag: localeTag,
                        ),
                      ),
                      onTap: () {
                        setLocalState(() {
                          selectedProfileId = candidate.profileId;
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(_roomText(context, ru: 'Отмена', en: 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(selectedProfileId),
                child: Text(_roomText(context, ru: 'Передать', en: 'Transfer')),
              ),
            ],
          );
        },
      );
    },
  );
}

class RoomDetailsScreen extends StatefulWidget {
  const RoomDetailsScreen({
    super.key,
    required this.controller,
    required this.groupId,
    required this.initialTitle,
  });

  final AppController controller;
  final String groupId;
  final String initialTitle;

  @override
  State<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen>
    with TickerProviderStateMixin {
  /// Opens the full-screen member list (tap on the "N participants" label).
  /// Профиль участника — по нажатию на строку.
  ///
  /// 🔴 НЕ ЗВОНОК И НЕ ЧАТ ПО ОДИНОЧНОМУ НАЖАТИЮ. По списку людей ходят
  /// глазами, и промах не должен стоить звонка чужому человеку, который об
  /// этом узнает: строка ОТКРЫВАЕТ, а действия стоят отдельными значками.
  void _openMemberProfile(RoomMember m) {
    final pid = m.profileId.trim();
    if (pid.isEmpty || pid == widget.controller.profileId) return;
    final label = m.displayName.trim();
    Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => ContactDetailsScreen(
          controller: widget.controller,
          peerProfileId: pid,
          convoId: pid,
          initialTitle: label.isEmpty ? null : label,
          initialAvatarPath: m.avatarPath,
          openChatByPush: true,
        ),
      ),
    );
  }

  /// Личная переписка с участником — значком справа в строке.
  void _messageMember(RoomMember m) {
    final pid = m.profileId.trim();
    if (pid.isEmpty || pid == widget.controller.profileId) return;
    final label = m.displayName.trim();
    Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => ChatScreen(
          controller: widget.controller,
          convoId: pid,
          title: label.isEmpty ? pid : label,
          peerProfileIdForSend: pid,
        ),
      ),
    );
  }

  void _openRoomMembersList() {
    Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => RoomMembersScreen(
          controller: widget.controller,
          groupId: widget.groupId,
        ),
      ),
    );
  }

  /// ◆ Открытая вкладка страницы комнаты: 0 — сведения, 1 — участники,
  /// 2 — медиа. То же деление, что и в окне на компьютере.
  int _roomTab = 0;

  String? _roomTitleOverride;

  final ScrollController _scrollController = ScrollController();
  bool _collapseGestureActive = false;
  double _pullExpand = 0;
  double _avatarPullPx = 0;
  double _avatarFullscreenPullPx = 0;
  bool _avatarWasFullyExpanded = false;
  bool _avatarViewerOpening = false;
  // 240px finger travel for a full open → the photo expands at half the finger
  // speed (2× slower / more gradual) than a 1:1 drag. IDENTICAL to contacts.
  static const double _avatarPullMaxPx = 240;
  static const double _avatarSnapThreshold = 0.45;
  static const double _avatarFullscreenPullThreshold = 28;
  late final AnimationController _pullSnapController;
  Animation<double>? _pullSnapAnimation;

  @override
  void initState() {
    super.initState();
    _pullSnapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          final animation = _pullSnapAnimation;
          if (animation == null || !mounted) return;
          setState(() {
            _pullExpand = animation.value;
            _avatarPullPx = (_pullExpand * _avatarPullMaxPx).clamp(
              0.0,
              _avatarPullMaxPx,
            );
          });
          _updateAvatarPhotoFeedback();
        });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pullSnapController.dispose();
    super.dispose();
  }

  void _stopPullSnap() {
    if (_pullSnapController.isAnimating) {
      _pullSnapController.stop();
    }
  }

  void _updateAvatarPhotoFeedback() {
    final fullyOpen = _pullExpand >= 0.995;
    final fullyClosed = _pullExpand <= 0.001;
    if (fullyOpen && !_avatarWasFullyExpanded) {
      _avatarWasFullyExpanded = true;
      unawaited(widget.controller.triggerUiHaptic());
      return;
    }
    if (fullyClosed && _avatarWasFullyExpanded) {
      _avatarWasFullyExpanded = false;
      unawaited(widget.controller.triggerUiHaptic());
    }
  }

  void _animatePullTo(double target) {
    final clamped = target.clamp(0.0, 1.0);
    if ((_pullExpand - clamped).abs() < 0.001) {
      setState(() {
        _pullExpand = clamped;
        _avatarPullPx = (_pullExpand * _avatarPullMaxPx).clamp(
          0.0,
          _avatarPullMaxPx,
        );
      });
      _updateAvatarPhotoFeedback();
      return;
    }
    _stopPullSnap();
    _pullSnapAnimation = Tween<double>(begin: _pullExpand, end: clamped)
        .animate(
          CurvedAnimation(
            parent: _pullSnapController,
            curve: Curves.easeOutCubic,
          ),
        );
    _pullSnapController
      ..reset()
      ..forward();
  }

  String? _existingAvatarPath(String? rawPath) {
    final path = rawPath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    try {
      final file = File(path);
      if (!file.existsSync() || file.lengthSync() <= 0) {
        return null;
      }
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openAvatarFullScreen(_RoomVm vm) async {
    if (_avatarViewerOpening) return;
    final path = _existingAvatarPath(vm.settings.avatarPath);
    if (path == null) return;
    _avatarFullscreenPullPx = 0;
    _avatarViewerOpening = true;
    try {
      await openFullscreenImageViewer(
        context,
        imagePath: path,
        title: vm.title,
        heroTag: 'room-avatar-${widget.groupId}',
      );
    } finally {
      _avatarViewerOpening = false;
    }
  }

  void _handleAvatarSurfaceDragUpdate(
    DragUpdateDetails details, {
    required _RoomVm vm,
  }) {
    final delta = details.delta.dy;
    if (_pullExpand >= 0.995 && delta > 0) {
      _avatarFullscreenPullPx += delta;
      if (_avatarFullscreenPullPx >= _avatarFullscreenPullThreshold) {
        _avatarFullscreenPullPx = 0;
        unawaited(_openAvatarFullScreen(vm));
        return;
      }
    } else {
      _avatarFullscreenPullPx = 0;
    }
    _stopPullSnap();
    setState(() {
      _avatarPullPx = (_avatarPullPx + delta).clamp(0.0, _avatarPullMaxPx);
      _pullExpand = (_avatarPullPx / _avatarPullMaxPx).clamp(0.0, 1.0);
    });
    _updateAvatarPhotoFeedback();
  }

  void _handleAvatarSurfaceDragEnd(DragEndDetails _) {
    _avatarFullscreenPullPx = 0;
    _animatePullTo(_pullExpand >= _avatarSnapThreshold ? 1.0 : 0.0);
  }

  void _handleCollapseDrag(DragUpdateDetails details) {
    _stopPullSnap();
    _collapseGestureActive = true;
    setState(() {
      _avatarPullPx = (_avatarPullPx + details.delta.dy).clamp(
        0.0,
        _avatarPullMaxPx,
      );
      _pullExpand = (_avatarPullPx / _avatarPullMaxPx).clamp(0.0, 1.0);
    });
    _updateAvatarPhotoFeedback();
  }

  void _handleCollapseDragEnd(DragEndDetails _) {
    _collapseGestureActive = false;
    _animatePullTo(_pullExpand >= _avatarSnapThreshold ? 1.0 : 0.0);
  }

  bool _handleAvatarPull(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.depth != 0) return false;

    final atTop =
        notification.metrics.pixels <= 0.5 &&
        notification.metrics.extentBefore <= 0.5;

    if (notification is OverscrollNotification) {
      if (notification.dragDetails == null) return false;
      final delta = notification.overscroll;
      if (atTop && delta < 0) {
        _stopPullSnap();
        setState(() {
          _avatarPullPx = (_avatarPullPx + (-delta)).clamp(
            0.0,
            _avatarPullMaxPx,
          );
          _pullExpand = (_avatarPullPx / _avatarPullMaxPx).clamp(0.0, 1.0);
        });
        _updateAvatarPhotoFeedback();
      }
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null) return false;
      final delta = notification.scrollDelta ?? 0;
      if (atTop && delta < 0) {
        _stopPullSnap();
        setState(() {
          _avatarPullPx = (_avatarPullPx + (-delta)).clamp(
            0.0,
            _avatarPullMaxPx,
          );
          _pullExpand = (_avatarPullPx / _avatarPullMaxPx).clamp(0.0, 1.0);
        });
        _updateAvatarPhotoFeedback();
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      if (notification.dragDetails == null) return false;
      if (_avatarPullPx > 0.001) {
        _animatePullTo(_pullExpand >= _avatarSnapThreshold ? 1.0 : 0.0);
      }
      return false;
    }

    return false;
  }

  bool get _isRu => roomLocaleIsRussian(context);

  Future<_RoomVm> _load() async {
    final defaultRoomTitle = _roomText(context, ru: 'Комната', en: 'Room');
    final conversations = await widget.controller.listConversations();
    final convo = conversations
        .where((c) => c.convoId == widget.groupId)
        .cast<Conversation?>()
        .firstOrNull;
    final convoTitle = (convo?.title ?? '').trim();
    final roomTitleOverride = (_roomTitleOverride ?? '').trim();
    final effectiveTitle = roomTitleOverride.isNotEmpty
        ? roomTitleOverride
        : (convoTitle.isNotEmpty ? convoTitle : widget.initialTitle);
    final settings = await widget.controller.getRoomSettings(widget.groupId);
    final members = await widget.controller.listRoomMembersDetailed(
      widget.groupId,
    );
    final pendingMembers = await widget.controller.listRoomJoinRequestsDetailed(
      widget.groupId,
    );
    final bannedMembers = await widget.controller.listRoomBannedMembersDetailed(
      widget.groupId,
    );
    final myId = widget.controller.profileId;
    final isAdmin = await widget.controller.isRoomAdmin(
      widget.groupId,
      profileIdOverride: myId,
    );
    final policy = await widget.controller.getRoomPolicyState(
      widget.groupId,
      profileIdOverride: myId,
    );
    final links = policy.canManageInviteLinks
        ? await widget.controller.listRoomInviteLinks(widget.groupId)
        : const <RoomInviteLink>[];
    final activeCall = await widget.controller.getCachedRoomCall(
      widget.groupId,
    );

    return _RoomVm(
      title: effectiveTitle.trim().isEmpty ? defaultRoomTitle : effectiveTitle,
      muted: convo?.muted ?? false,
      autoDeleteSeconds: convo?.autoDeleteSeconds,
      settings: settings,
      members: members,
      pendingMembers: pendingMembers,
      bannedMembers: bannedMembers,
      inviteLinks: links,
      isAdmin: isAdmin,
      policy: policy,
      myProfileId: myId,
      activeCall: activeCall != null && activeCall.isActive ? activeCall : null,
    );
  }

  void _openRoomCallScreen(_RoomVm vm) {
    Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => RoomCallScreen(
          controller: widget.controller,
          groupId: widget.groupId,
          initialTitle: vm.title,
        ),
      ),
    );
  }

  Future<void> _openAutoDelete(_RoomVm vm) async {
    final options = <({int? secs, String label})>[
      (secs: null, label: _roomText(context, ru: 'Выкл.', en: 'Off')),
      (
        secs: 24 * 60 * 60,
        label: _roomText(context, ru: '1 день', en: '1 day'),
      ),
      (
        secs: 7 * 24 * 60 * 60,
        label: _roomText(context, ru: '7 дней', en: '7 days'),
      ),
      (
        secs: 30 * 24 * 60 * 60,
        label: _roomText(context, ru: '30 дней', en: '30 days'),
      ),
    ];
    final selected = await showDialog<int?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          _roomText(
            context,
            ru: 'Автоудаление у меня',
            en: 'Auto-delete for me',
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              _roomText(
                context,
                ru: 'Эта настройка влияет только на этот чат у вас и не меняет правила комнаты для других участников.',
                en: 'This setting only affects this chat for you and does not change the room rules for other members.',
                uk: 'Цей параметр впливає лише на цей чат у вас і не змінює правила кімнати для інших учасників.',
                es: 'Este ajuste solo afecta a este chat para ti y no cambia las reglas de la sala para otros miembros.',
                pt: 'Esta definicao afeta apenas este chat para si e nao altera as regras da sala para outros membros.',
                ptBr:
                    'Esta configuracao afeta apenas este chat para voce e nao altera as regras da sala para outros membros.',
                fr: 'Ce reglage ne concerne que ce chat pour vous et ne modifie pas les regles du salon pour les autres membres.',
                de: 'Diese Einstellung betrifft nur diesen Chat fuer dich und aendert die Raumregeln fuer andere Mitglieder nicht.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final opt in options)
            ListTile(
              leading: Icon(
                vm.autoDeleteSeconds == opt.secs
                    ? AppIcons.radioChecked
                    : AppIcons.radioUnchecked,
              ),
              title: Text(opt.label),
              onTap: () => Navigator.of(context).pop(opt.secs),
            ),
        ],
      ),
    );
    if (selected == vm.autoDeleteSeconds) return;
    await widget.controller.setChatAutoDeleteSeconds(
      convoId: widget.groupId,
      autoDeleteSeconds: selected,
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openAddMembers(_RoomVm vm) async {
    try {
      ensureRoomActionAllowed(vm.policy, RoomAction.addMembers);
    } catch (e) {
      if (!mounted) return;
      _showRoomActionError(context, e);
      return;
    }
    final contacts = (await widget.controller.listContacts())
        .where(
          (contact) =>
              !widget.controller.isSavedMessagesConvo(contact.profileId),
        )
        .toList(growable: false);
    // 🔴 КТО СЕЙЧАС В СЕТИ — берём из переписок: у самого контакта отметки
    // присутствия нет, а у беседы с ним есть `peerLastSeenAtMs`. Без этого
    // список отвечает «кто у меня записан», а спрашивают у него «кого
    // позвать прямо сейчас».
    final onlineByProfileId = <String, bool>{};
    try {
      for (final convo in await widget.controller.listConversations()) {
        final pid = (convo.peerProfileId ?? '').trim();
        if (pid.isEmpty) continue;
        onlineByProfileId[pid] = convo.isOnline;
      }
    } catch (_) {
      // Присутствие — украшение списка, а не условие его работы.
    }
    if (!mounted) return;
    final existing = vm.members.map((m) => m.profileId).toSet();
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        final picked = <String>{};
        final searchCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setLocal) {
            final cs = Theme.of(context).colorScheme;
            final query = searchCtrl.text.trim().toLowerCase();
            String nameOf(Contact c) =>
                (c.displayName ?? '').trim().isNotEmpty
                ? c.displayName!.trim()
                : c.profileId;
            final visible = contacts.where((c) {
              if (query.isEmpty) return true;
              return nameOf(c).toLowerCase().contains(query) ||
                  c.profileId.toLowerCase().contains(query);
            }).toList(growable: false);
            return AlertDialog(
              title: Text(
                _roomText(
                  context,
                  ru: 'Добавить участников',
                  en: 'Add participants',
                ),
              ),
              // ◆ БЫЛО «УБОГО»: строки без портретов, без присутствия, имя и
              // идентификатор одним весом. Выбирать человека из списка, где
              // все выглядят одинаково, приходилось по памяти.
              content: SizedBox(
                width: 380,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setLocal(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        hintText: _roomText(
                          context,
                          ru: 'Имя или Secretly ID',
                          en: 'Name or Secretly ID',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (picked.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _roomText(
                              context,
                              ru: 'Выбрано: ${picked.length}',
                              en: 'Selected: ${picked.length}',
                            ),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: cs.primary),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Text(
                                _roomText(
                                  context,
                                  ru: 'Никого не нашлось',
                                  en: 'Nobody found',
                                ),
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            )
                          : ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final c = visible[index];
                                final inRoom = existing.contains(c.profileId);
                                final title = nameOf(c);
                                final checked = picked.contains(c.profileId);
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  enabled: !inRoom,
                                  leading: _MiniAvatar(
                                    title: title,
                                    avatarPath: c.avatarPath,
                                    seed: c.profileId,
                                    radius: 20,
                                    online:
                                        onlineByProfileId[c.profileId] ?? false,
                                  ),
                                  title: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    inRoom
                                        ? _roomText(
                                            context,
                                            ru: 'Уже в комнате',
                                            en: 'Already in the room',
                                          )
                                        : c.profileId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                  ),
                                  trailing: inRoom
                                      ? Icon(
                                          Icons.check_circle_rounded,
                                          color: cs.onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                        )
                                      : Checkbox(
                                          value: checked,
                                          onChanged: (v) => setLocal(() {
                                            if (v == true) {
                                              picked.add(c.profileId);
                                            } else {
                                              picked.remove(c.profileId);
                                            }
                                          }),
                                        ),
                                  onTap: inRoom
                                      ? null
                                      : () => setLocal(() {
                                          if (checked) {
                                            picked.remove(c.profileId);
                                          } else {
                                            picked.add(c.profileId);
                                          }
                                        }),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(_roomText(context, ru: 'Отмена', en: 'Cancel')),
                ),
                FilledButton(
                  onPressed: picked.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(picked),
                  child: Text(_roomText(context, ru: 'Добавить', en: 'Add')),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null || selected.isEmpty) return;
    try {
      await widget.controller.addGroupMembers(
        groupId: widget.groupId,
        memberProfileIds: selected.toList(growable: false),
      );
    } catch (e) {
      if (!mounted) return;
      _showRoomActionError(context, e);
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _leaveRoomAndPop() async {
    final vm = await _load();
    if (!mounted) return;
    try {
      await widget.controller.leaveRoom(widget.groupId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      if (error is RoomMembershipFailure &&
          error.code == RoomMembershipFailureCode.ownerTransferRequired) {
        final nextOwnerProfileId = await _pickNextOwner(vm);
        if (!mounted) return;
        if (nextOwnerProfileId == null) {
          _showRoomActionError(context, error);
          return;
        }
        try {
          await widget.controller.transferRoomOwnership(
            groupId: widget.groupId,
            nextOwnerProfileId: nextOwnerProfileId,
          );
          await widget.controller.leaveRoom(widget.groupId);
          if (!mounted) return;
          Navigator.of(context).pop(true);
          return;
        } catch (transferError) {
          if (!mounted) return;
          _showRoomActionError(context, transferError);
          return;
        }
      }
      _showRoomActionError(context, error);
    }
  }

  Future<String?> _pickNextOwner(_RoomVm vm) async {
    return _pickNextRoomOwnerDialog(
      context,
      isRu: _isRu,
      members: vm.members,
      currentProfileId: vm.myProfileId,
    );
  }

  Future<void> _editRoomTitle(_RoomVm vm) async {
    try {
      ensureRoomActionAllowed(vm.policy, RoomAction.changeGroupInfo);
    } catch (e) {
      if (!mounted) return;
      _showRoomActionError(context, e);
      return;
    }
    final controller = TextEditingController(text: vm.title);
    final nextTitle = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          _roomText(context, ru: 'Название комнаты', en: 'Room name'),
        ),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 96,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: _roomText(
                context,
                ru: 'Например: Команда',
                en: 'For example: Team',
              ),
            ),
            onSubmitted: (_) => Navigator.of(dialogCtx).pop(controller.text),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: Text(_roomText(context, ru: 'Отмена', en: 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(controller.text),
            child: Text(_roomText(context, ru: 'Сохранить', en: 'Save')),
          ),
        ],
      ),
    );
    if (nextTitle == null) return;
    final cleaned = nextTitle.trim();
    if (cleaned.isEmpty || cleaned == vm.title.trim()) return;
    try {
      await widget.controller.updateRoomBasics(
        groupId: widget.groupId,
        title: cleaned,
        description: vm.settings.description,
      );
      if (!mounted) return;
      setState(() {
        _roomTitleOverride = cleaned;
      });
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
    }
  }

  Future<void> _editRoomDescription(_RoomVm vm) async {
    try {
      ensureRoomActionAllowed(vm.policy, RoomAction.changeGroupInfo);
    } catch (e) {
      if (!mounted) return;
      _showRoomActionError(context, e);
      return;
    }
    final controller = TextEditingController(
      text: vm.settings.description ?? '',
    );
    final next = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          _roomText(context, ru: 'Описание комнаты', en: 'Room description'),
        ),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            maxLength: 240,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: _roomText(
                context,
                ru: 'Коротко о чём комната',
                en: 'A short description',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: Text(_roomText(context, ru: 'Отмена', en: 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(controller.text),
            child: Text(_roomText(context, ru: 'Сохранить', en: 'Save')),
          ),
        ],
      ),
    );
    if (next == null) return;
    final cleaned = next.trim();
    if (cleaned == (vm.settings.description ?? '').trim()) return;
    try {
      await widget.controller.updateRoomBasics(
        groupId: widget.groupId,
        title: vm.title,
        description: cleaned.isEmpty ? null : cleaned,
      );
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
    }
  }

  // ─────────────── premium ROOM cosmetics (owner-only editor) ───────────────

  /// Premium gate for the room-cosmetics editor. All catalog ids are premium,
  /// so this single boolean decides every cosmetic action (mirrors the profile
  /// cosmetics screen). Fail-open / paid tiers report true.
  bool get _roomCosmeticsUnlocked => FeatureGate.isUnlocked(
    widget.controller.entitlementStateNow,
    GatedFeature.cosmetic,
  );

  /// Subtitle for a cosmetic row: the chosen item's localized name, or «Не
  /// задано» / "Not set" when nothing is selected.
  String _roomCosmeticSubtitle(String? selectedName) {
    if (selectedName != null && selectedName.trim().isNotEmpty) {
      return selectedName;
    }
    return _roomText(
      context,
      ru: 'Не задано',
      en: 'Not set',
      uk: 'Не задано',
      es: 'No establecido',
      pt: 'Não definido',
      ptBr: 'Não definido',
      fr: 'Non défini',
      de: 'Nicht festgelegt',
    );
  }

  /// Routes a non-premium owner to the paywall; returns true once the feature is
  /// unlocked (either it already was, or the user purchased in the paywall).
  Future<bool> _ensureRoomCosmeticsUnlocked() async {
    if (_roomCosmeticsUnlocked) return true;
    await showPaywall(context, PaywallTrigger.cosmetic);
    if (!mounted) return false;
    return _roomCosmeticsUnlocked;
  }

  Future<void> _pickRoomFrame(_RoomVm vm) async {
    if (!await _ensureRoomCosmeticsUnlocked()) return;
    if (!mounted) return;
    final picked = await _showRoomCosmeticPicker(
      title: _roomText(
        context,
        ru: 'Рамка комнаты',
        en: 'Room frame',
        uk: 'Рамка кімнати',
        es: 'Marco de la sala',
        pt: 'Moldura da sala',
        ptBr: 'Moldura da sala',
        fr: 'Cadre du salon',
        de: 'Raum-Rahmen',
      ),
      currentId: vm.settings.frameId,
      items: [
        for (final f in kAllAvatarFrames)
          _RoomCosmeticChoice(
            id: f.id,
            label: f.nameLocalized(context),
            preview: SizedBox(width: 60, height: 60, child: f.builder(60)),
          ),
      ],
    );
    if (picked == null || !mounted) return; // dismissed → no change
    try {
      await widget.controller.setRoomFrame(
        widget.groupId,
        picked.isEmpty ? null : picked,
      );
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
    }
  }

  Future<void> _pickRoomCover(_RoomVm vm) async {
    if (!await _ensureRoomCosmeticsUnlocked()) return;
    if (!mounted) return;
    final picked = await _showRoomCosmeticPicker(
      title: _roomText(
        context,
        ru: 'Обложка комнаты',
        en: 'Room cover',
        uk: 'Обкладинка кімнати',
        es: 'Portada de la sala',
        pt: 'Capa da sala',
        ptBr: 'Capa da sala',
        fr: 'Couverture du salon',
        de: 'Raum-Titelbild',
      ),
      currentId: vm.settings.coverId,
      items: [
        for (final c in kAllProfileCovers)
          _RoomCosmeticChoice(
            id: c.id,
            label: c.nameLocalized(context),
            preview: SizedBox(width: 60, height: 60, child: c.builder()),
          ),
      ],
    );
    if (picked == null || !mounted) return;
    try {
      await widget.controller.setRoomCover(
        widget.groupId,
        picked.isEmpty ? null : picked,
      );
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
    }
  }

  /// Bottom-sheet grid that reuses the shared cosmetic catalog previews. Resolves
  /// to a chosen id, an empty string for «Без рамки/обложки» (clear), or null if
  /// dismissed.
  Future<String?> _showRoomCosmeticPicker({
    required String title,
    required String? currentId,
    required List<_RoomCosmeticChoice> items,
  }) {
    final noneLabel = _roomText(
      context,
      ru: 'Без',
      en: 'None',
      uk: 'Без',
      es: 'Ninguno',
      pt: 'Nenhum',
      ptBr: 'Nenhum',
      fr: 'Aucun',
      de: 'Keine',
    );
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15171E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                    children: [
                      _RoomCosmeticTile(
                        label: noneLabel,
                        selected: (currentId ?? '').isEmpty,
                        // Empty string => clear the cosmetic.
                        onTap: () => Navigator.pop(ctx, ''),
                        preview: const Icon(
                          Icons.block_rounded,
                          color: Colors.white38,
                          size: 30,
                        ),
                      ),
                      for (final item in items)
                        _RoomCosmeticTile(
                          label: item.label,
                          selected: item.id == currentId,
                          onTap: () => Navigator.pop(ctx, item.id),
                          preview: item.preview,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyRoomId() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: widget.groupId));
    if (!mounted) return;
    messenger.showSnackBar(
      SecretlySnackBar(
        content: Text(
          _roomText(context, ru: 'ID комнаты скопирован', en: 'Room ID copied'),
        ),
      ),
    );
  }

  Future<void> _editOwnTag(_RoomVm vm) async {
    try {
      ensureRoomActionAllowed(vm.policy, RoomAction.changeOwnTag);
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
      return;
    }
    final currentTag = vm.members
        .where((member) => member.profileId == vm.myProfileId)
        .map(_roomMemberTag)
        .whereType<String>()
        .cast<String?>()
        .firstOrNull;
    final controller = TextEditingController(text: currentTag ?? '');
    final nextTag = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(_roomText(context, ru: 'Тег в комнате', en: 'Room tag')),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 32,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: _roomText(
                context,
                ru: 'Например: support',
                en: 'For example: support',
              ),
              helperText: _roomText(
                context,
                ru: 'Короткая подпись рядом с вашим именем в этой комнате.',
                en: 'A short label shown next to your name in this room.',
              ),
            ),
            onSubmitted: (_) => Navigator.of(dialogCtx).pop(controller.text),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: Text(_roomText(context, ru: 'Отмена', en: 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(''),
            child: Text(_roomText(context, ru: 'Очистить', en: 'Clear')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(controller.text),
            child: Text(_roomText(context, ru: 'Сохранить', en: 'Save')),
          ),
        ],
      ),
    );
    if (nextTag == null) return;
    try {
      await widget.controller.setOwnRoomTag(
        groupId: widget.groupId,
        tag: nextTag,
      );
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
    }
  }

  /// Runs picked image [bytes] through the round-avatar crop screen — the SAME
  /// pan/zoom flow as setting your own profile photo. Returns the cropped bytes
  /// ONLY when the user pressed "Готово"; returns null on back/cancel or if the
  /// widget went away mid-flow (the caller must NOT apply a photo on null).
  Future<Uint8List?> _cropRoomAvatarBytes(Uint8List bytes) async {
    File? tmp;
    try {
      tmp = File(
        '${Directory.systemTemp.path}/room_avatar_src_'
        '${DateTime.now().microsecondsSinceEpoch}.img',
      );
      await tmp.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Couldn't stage the crop — do NOT apply an uncropped photo.
      return null;
    }
    if (!mounted) return null;
    final croppedPath = await Navigator.of(context).push<String>(
      SecretlyPageRoute(
        builder: (_) => CoverCropScreen(
          imagePath: tmp!.path,
          circle: true,
          title: _roomText(context, ru: 'Подгоните фото', en: 'Adjust photo'),
        ),
      ),
    );
    Uint8List? result;
    if (croppedPath != null) {
      try {
        result = await File(croppedPath).readAsBytes();
      } catch (_) {
        result = null;
      }
    }
    try {
      await tmp.delete();
    } catch (_) {}
    // FIX (2026-07-13): null unless the user pressed "Готово" — the caller skips
    // on null, so back/cancel no longer applies the photo.
    return result;
  }

  Future<void> _changeRoomAvatar(_RoomVm vm) async {
    try {
      ensureRoomActionAllowed(vm.policy, RoomAction.changeGroupInfo);
    } catch (e) {
      if (!mounted) return;
      _showRoomActionError(context, e);
      return;
    }
    final hasPhoto = (vm.settings.avatarHash ?? '').trim().isNotEmpty;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        // Во всю ширину и до низа экрана; отступ под системную панель переехал
        // в содержимое, поверхность уходит за неё.
        final safeBottom = MediaQuery.paddingOf(sheetCtx).bottom;
        return SecretlyGlassSheetSurface(
          flushToEdges: true,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + safeBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: SecretlyGlassSheetHandle()),
                const SizedBox(height: 14),
                Text(
                  _roomText(context, ru: 'Аватар комнаты', en: 'Room avatar'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.photo),
                  title: Text(
                    _roomText(
                      context,
                      ru: 'Выбрать из галереи',
                      en: 'Choose from gallery',
                    ),
                  ),
                  onTap: () => Navigator.of(sheetCtx).pop('gallery'),
                ),
                if (Platform.isAndroid || Platform.isIOS)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.camera),
                    title: Text(
                      _roomText(
                        context,
                        ru: 'Сделать фото',
                        en: 'Take a photo',
                      ),
                    ),
                    onTap: () => Navigator.of(sheetCtx).pop('camera'),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.emoji),
                  title: Text(
                    _roomText(context, ru: 'Выбрать иконку', en: 'Choose icon'),
                  ),
                  onTap: () => Navigator.of(sheetCtx).pop('icon'),
                ),
                if (hasPhoto)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.delete),
                    title: Text(
                      _roomText(
                        context,
                        ru: 'Удалить аватар',
                        en: 'Remove avatar',
                      ),
                    ),
                    onTap: () => Navigator.of(sheetCtx).pop('remove'),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    try {
      if (selected == 'gallery') {
        final picked = await FilePicker.platform.pickFiles(
          withData: true,
          type: FileType.custom,
          allowedExtensions: const <String>[
            'jpg',
            'jpeg',
            'png',
            'webp',
            'heic',
            'heif',
          ],
        );
        final file = picked?.files.single;
        final bytes = file?.bytes;
        if (bytes == null || bytes.isEmpty) return;
        // Let the user pan/zoom the photo into the round avatar frame — same
        // flow as setting your OWN profile photo (CoverCropScreen).
        final cropped = await _cropRoomAvatarBytes(bytes);
        if (cropped == null || !mounted) return;
        await widget.controller.setRoomAvatarFromImageBytes(
          groupId: widget.groupId,
          bytes: cropped,
        );
      } else if (selected == 'camera') {
        final shot = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: 2048,
          maxHeight: 2048,
        );
        if (shot == null) return;
        final bytes = await shot.readAsBytes();
        if (bytes.isEmpty) return;
        final cropped = await _cropRoomAvatarBytes(bytes);
        if (cropped == null || !mounted) return;
        await widget.controller.setRoomAvatarFromImageBytes(
          groupId: widget.groupId,
          bytes: cropped,
        );
      } else if (selected == 'icon') {
        if (!mounted) return;
        await Navigator.of(context).push<bool>(
          SecretlyPageRoute(
            builder: (_) => ProfileIconPickerScreen(
              controller: widget.controller,
              title: _roomText(context, ru: 'Иконка комнаты', en: 'Room icon'),
              applyButtonLabel: _roomText(
                context,
                ru: 'Использовать',
                en: 'Use icon',
              ),
              onApplySelection: (selection) async {
                final iconBytes = selection.iconBytes;
                final avatarBytes = iconBytes != null
                    ? await widget.controller.buildAvatarBytesFromIconBytes(
                        iconBytes: iconBytes,
                        gradientStartArgb: selection.gradientStartArgb,
                        gradientEndArgb: selection.gradientEndArgb,
                        iconScale: selection.iconScale,
                        debugLabel: selection.assetPath,
                      )
                    : await widget.controller.buildAvatarBytesFromIconAsset(
                        assetPath: selection.assetPath,
                        gradientStartArgb: selection.gradientStartArgb,
                        gradientEndArgb: selection.gradientEndArgb,
                        iconScale: selection.iconScale,
                      );
                await widget.controller.setRoomAvatarFromImageBytes(
                  groupId: widget.groupId,
                  bytes: avatarBytes,
                );
              },
            ),
          ),
        );
      } else if (selected == 'remove') {
        await widget.controller.removeRoomAvatar(groupId: widget.groupId);
      }
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
    }
  }

  Future<void> _openRoomAdministration(_RoomVm vm) async {
    if (!_canManageRoomAdministration(vm.policy)) {
      return;
    }
    await Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => RoomAdministrationScreen(
          controller: widget.controller,
          groupId: widget.groupId,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleRoomMuted(_RoomVm vm) async {
    await widget.controller.setChatMuted(
      convoId: widget.groupId,
      muted: !vm.muted,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(
        content: Text(
          vm.muted
              ? (_roomText(context, ru: 'Звук включен', en: 'Sound enabled'))
              : (_roomText(context, ru: 'Звук отключен', en: 'Sound muted')),
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _openInviteLinks(_RoomVm vm) async {
    if (!vm.policy.canManageInviteLinks) return;
    await Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => RoomInviteLinksScreen(
          controller: widget.controller,
          groupId: widget.groupId,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  List<RoomInviteLink> _activeInviteLinksForShare(_RoomVm vm) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return vm.inviteLinks
        .where(
          (link) =>
              !link.revoked &&
              !link.isExpiredAt(nowMs) &&
              !link.isUsageLimitReached,
        )
        .toList(growable: false);
  }

  String _formatInviteShareDateTime(int timestampMs) {
    final material = MaterialLocalizations.of(context);
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal();
    final dateText = material.formatShortDate(date);
    final timeText = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return '$dateText, $timeText';
  }

  String _inviteLinkShareSubtitle(RoomInviteLink link) {
    final roleText = _roomRoleLabelForContext(context, link.allowedRole);
    final approvalText = link.requiresApproval
        ? _roomText(context, ru: 'нужно одобрение', en: 'approval required')
        : _roomText(context, ru: 'вход сразу', en: 'direct join');
    final remainingUses = link.remainingUses;
    final usageText = remainingUses == null
        ? (_roomText(context, ru: 'без лимита', en: 'unlimited'))
        : (_roomText(
            context,
            ru: 'осталось: $remainingUses',
            en: '$remainingUses uses left',
            uk: 'залишилося: $remainingUses',
            es: 'quedan: $remainingUses',
            pt: 'restam: $remainingUses',
            ptBr: 'restam: $remainingUses',
            fr: 'restants : $remainingUses',
            de: 'uebrig: $remainingUses',
          ));
    final expiresAtMs = link.expiresAtMs;
    final expiresAtText = expiresAtMs == null
        ? null
        : _formatInviteShareDateTime(expiresAtMs);
    final expiryText = expiresAtMs == null
        ? (_roomText(context, ru: 'без срока', en: 'no expiry'))
        : _roomText(
            context,
            ru: 'до $expiresAtText',
            en: 'until $expiresAtText',
            uk: 'до $expiresAtText',
            es: 'hasta $expiresAtText',
            pt: 'ate $expiresAtText',
            ptBr: 'ate $expiresAtText',
            fr: 'jusqu au $expiresAtText',
            de: 'bis $expiresAtText',
          );
    return '$roleText • $approvalText • $usageText • $expiryText';
  }

  Future<RoomInviteLink?> _pickInviteLinkForShare(
    List<RoomInviteLink> links,
  ) async {
    if (links.isEmpty) {
      return null;
    }
    if (links.length == 1) {
      return links.first;
    }
    return showDialog<RoomInviteLink>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _roomText(
            context,
            ru: 'Выберите ссылку для приглашения',
            en: 'Choose an invite link',
          ),
        ),
        content: SizedBox(
          width: 460,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: links.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final link = links[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    link.slug,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_inviteLinkShareSubtitle(link)),
                  onTap: () => Navigator.of(context).pop(link),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_roomText(context, ru: 'Отмена', en: 'Cancel')),
          ),
        ],
      ),
    );
  }

  Future<RoomInviteLink?> _ensureInviteLinkForShare(_RoomVm vm) async {
    if (!vm.policy.canManageInviteLinks) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            _roomText(
              context,
              ru: 'Ссылками-приглашениями могут управлять только владельцы и администраторы комнаты.',
              en: 'Only room owners and admins can manage and share invite links.',
              uk: 'Керувати посиланнями-запрошеннями можуть лише власники й адміністратори кімнати.',
              es: 'Solo los propietarios y administradores de la sala pueden gestionar y compartir enlaces de invitacion.',
              pt: 'Apenas proprietarios e administradores da sala podem gerir e partilhar links de convite.',
              ptBr:
                  'Somente proprietarios e administradores da sala podem gerenciar e compartilhar links de convite.',
              fr: 'Seuls les proprietaires et administrateurs du salon peuvent gerer et partager les liens d invitation.',
              de: 'Nur Raumbesitzer und Administratoren koennen Einladungslinks verwalten und teilen.',
            ),
          ),
        ),
      );
      return null;
    }
    final existing = await _pickInviteLinkForShare(
      _activeInviteLinksForShare(vm),
    );
    if (existing != null) {
      return existing;
    }
    try {
      final link = await widget.controller.createRoomInviteLink(
        widget.groupId,
        requiresApproval: vm.settings.joinApprovalRequired,
      );
      if (mounted) {
        setState(() {});
      }
      return link;
    } catch (error) {
      if (mounted) {
        _showRoomActionError(context, error);
      }
      return null;
    }
  }

  Future<void> _sendInviteToConversation(
    Conversation conversation, {
    required RoomInviteLink link,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final shareText = link.shareUrl;
      if (conversation.convoId.startsWith('group:')) {
        await widget.controller.sendGroupMessage(
          groupId: conversation.convoId,
          text: shareText,
        );
      } else {
        final rawProfileId =
            (conversation.peerProfileId ?? conversation.convoId).trim();
        final peerProfileId = rawProfileId.startsWith('req:')
            ? rawProfileId.substring(4)
            : rawProfileId;
        if (peerProfileId.isEmpty) {
          throw StateError('Missing peer profile id');
        }
        await widget.controller.sendMessage(
          peerProfileId: peerProfileId,
          text: shareText,
        );
      }
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SecretlySnackBar(
            content: Text(
              _roomText(
                context,
                ru: 'Приглашение отправлено в ${conversation.title}',
                en: 'Invite sent to ${conversation.title}',
                uk: 'Запрошення надіслано в ${conversation.title}',
                es: 'Invitacion enviada a ${conversation.title}',
                pt: 'Convite enviado para ${conversation.title}',
                ptBr: 'Convite enviado para ${conversation.title}',
                fr: 'Invitation envoyee dans ${conversation.title}',
                de: 'Einladung an ${conversation.title} gesendet',
              ),
            ),
          ),
        );
    } on RoomPolicyFailure catch (error) {
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SecretlySnackBar(
            content: Text(roomPolicyErrorText(context.l10n, error)),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SecretlySnackBar(
            content: Text(context.l10n.sendFailed(error.toString())),
          ),
        );
    }
  }

  Future<void> _inviteInsideSecretly(_RoomVm vm) async {
    final link = await _ensureInviteLinkForShare(vm);
    if (!mounted || link == null) return;
    final conversation = await showRoomInviteShareSheet(
      context,
      controller: widget.controller,
      groupId: widget.groupId,
      title: vm.title,
    );
    if (!mounted || conversation == null) return;
    await _sendInviteToConversation(conversation, link: link);
  }

  Future<void> _shareInviteExternally(_RoomVm vm) async {
    final link = await _ensureInviteLinkForShare(vm);
    if (link == null) return;
    await shareTextExternally(text: link.shareUrl);
  }

  Future<void> _showRoomPolicy() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _roomText(context, ru: 'Политика комнаты', en: 'Room policy'),
        ),
        content: Text(
          _roomText(
            context,
            ru: 'Сообщения и вложения в комнате защищены E2EE. Вложения хранятся на relay только временно по TTL. Владельцы управляют передачей прав и удалением комнаты, администраторы меняют настройки, роли и ссылки-приглашения, модераторы работают с очередью вступления и нарушениями, а возможности обычных, ограниченных и гостевых ролей задаются политикой комнаты.',
            en: 'Room messages and attachments are protected with E2EE. Attachments are stored on relay only temporarily by TTL. Owners handle ownership transfer and room deletion, admins manage settings, roles, and invite links, moderators handle join approvals and member moderation, and member, restricted, and guest capabilities follow the room policy.',
            uk: 'Повідомлення й вкладення в кімнаті захищені E2EE. Вкладення зберігаються на relay лише тимчасово за TTL. Власники керують передачею прав і видаленням кімнати, адміністратори змінюють налаштування, ролі та запрошення, модератори працюють із запитами на вступ і порушеннями, а можливості ролей визначає політика кімнати.',
            es: 'Los mensajes y adjuntos de la sala estan protegidos con E2EE. Los adjuntos se guardan en relay solo de forma temporal por TTL. Los propietarios gestionan transferencia y eliminacion, los administradores ajustes, roles e invitaciones, los moderadores aprobaciones y moderacion, y las capacidades de cada rol siguen la politica de la sala.',
            pt: 'As mensagens e anexos da sala estao protegidos com E2EE. Os anexos ficam no relay apenas temporariamente por TTL. Proprietarios gerem transferencia e eliminacao, administradores gerem definicoes, funcoes e convites, moderadores tratam aprovacoes e moderacao, e as capacidades das funcoes seguem a politica da sala.',
            ptBr:
                'As mensagens e anexos da sala sao protegidos com E2EE. Os anexos ficam no relay apenas temporariamente por TTL. Proprietarios gerenciam transferencia e exclusao, administradores gerenciam configuracoes, funcoes e convites, moderadores cuidam de aprovacoes e moderacao, e as capacidades de cada funcao seguem a politica da sala.',
            fr: 'Les messages et pieces jointes du salon sont proteges par E2EE. Les pieces jointes sont stockees sur le relay uniquement de facon temporaire selon le TTL. Les proprietaires gerent le transfert et la suppression, les administrateurs les reglages, roles et invitations, les moderateurs les demandes et la moderation, et les droits suivent la politique du salon.',
            de: 'Raumnachrichten und Anhaenge sind mit E2EE geschuetzt. Anhaenge liegen nur temporaer per TTL auf dem Relay. Besitzer verwalten Uebertragung und Loeschung, Administratoren Einstellungen, Rollen und Einladungen, Moderatoren Beitrittsanfragen und Moderation, und Rollenrechte folgen der Raumrichtlinie.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_roomText(context, ru: 'Закрыть', en: 'Close')),
          ),
        ],
      ),
    );
  }

  Future<void> _reportRoom(_RoomVm vm) async {
    final result = await showReportAbuseSheet(
      context: context,
      target: ReportAbuseTarget(
        type: ReportAbuseTargetType.room,
        id: widget.groupId,
        title: vm.title,
        conversationId: widget.groupId,
      ),
      buildMarker: widget.controller.buildMarker,
      reporterDeviceId: widget.controller.deviceId,
      reporterProfileId: widget.controller.profileId,
      additionalTechnicalLines:
          widget.controller.pushRegistrationTechnicalLines,
    );
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(
        content: Text(reportAbuseDeliveryMessage(context, result)),
      ),
    );
  }

  Future<void> _openMenu(_RoomVm vm) async {
    final action = await showFrostedPopup<String>(
      context: context,
      alignment: Alignment.topRight,
      builder: (context) {
        final topPad = MediaQuery.of(context).padding.top + kToolbarHeight - 8;
        final cs = Theme.of(context).colorScheme;
        final canShareInvite = vm.policy.canManageInviteLinks;
        final canClearHistory = vm.policy.canManageSettings;
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: topPad,
                right: 12,
                child: FrostedPopupContainer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 210,
                      maxWidth: 250,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _roomMenuAction(
                          icon: AppIcons.timer,
                          title: _roomText(
                            context,
                            ru: 'Автоудаление у меня',
                            en: 'Auto-delete for me',
                          ),
                          onTap: () => Navigator.of(context).pop('autodelete'),
                        ),
                        if (canShareInvite)
                          _roomMenuAction(
                            icon: AppIcons.personAdd,
                            title: _roomText(
                              context,
                              ru: 'Пригласить',
                              en: 'Invite',
                            ),
                            onTap: () => Navigator.of(context).pop('invite'),
                          ),
                        if (canShareInvite)
                          _roomMenuAction(
                            icon: AppIcons.reply,
                            title: _roomText(
                              context,
                              ru: 'Поделиться',
                              en: 'Share',
                            ),
                            onTap: () => Navigator.of(context).pop('share'),
                          ),
                        if (canShareInvite)
                          _roomMenuAction(
                            icon: Icons.link_rounded,
                            title: _roomText(
                              context,
                              ru: 'Управление ссылками',
                              en: 'Manage invite links',
                            ),
                            onTap: () =>
                                Navigator.of(context).pop('invite_links'),
                          ),
                        _roomMenuAction(
                          icon: AppIcons.search,
                          title: _roomText(
                            context,
                            ru: 'Поиск участников',
                            en: 'Search participants',
                          ),
                          onTap: () =>
                              Navigator.of(context).pop('search_members'),
                        ),
                        _roomMenuAction(
                          icon: AppIcons.shield,
                          title: _roomText(
                            context,
                            ru: 'Политика конфиденциальности',
                            en: 'Privacy policy',
                          ),
                          onTap: () => Navigator.of(context).pop('policy'),
                        ),
                        _roomMenuAction(
                          icon: AppIcons.copy,
                          title: _roomText(
                            context,
                            ru: 'Скопировать ID комнаты',
                            en: 'Copy room ID',
                          ),
                          onTap: () => Navigator.of(context).pop('copy_id'),
                        ),
                        if (canClearHistory)
                          _roomMenuAction(
                            icon: AppIcons.delete,
                            iconColor: cs.error,
                            textColor: cs.error,
                            title: _roomText(
                              context,
                              ru: 'Очистить историю',
                              en: 'Clear history',
                            ),
                            onTap: () =>
                                Navigator.of(context).pop('clear_history'),
                          ),
                        _roomMenuAction(
                          icon: AppIcons.errorOutline,
                          iconColor: cs.error,
                          textColor: cs.error,
                          title: reportAbuseMenuLabel(context),
                          onTap: () => Navigator.of(context).pop('report'),
                        ),
                        _roomMenuAction(
                          icon: AppIcons.delete,
                          iconColor: cs.error,
                          textColor: cs.error,
                          title: _roomText(
                            context,
                            ru: 'Покинуть комнату',
                            en: 'Leave room',
                          ),
                          onTap: () => Navigator.of(context).pop('leave'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'autodelete':
        await _openAutoDelete(vm);
        return;
      case 'invite':
        await _inviteInsideSecretly(vm);
        return;
      case 'invite_links':
        await _openInviteLinks(vm);
        return;
      case 'share':
        await _shareInviteExternally(vm);
        return;
      case 'policy':
        await _showRoomPolicy();
        return;
      case 'copy_id':
        await _copyRoomId();
        return;
      case 'clear_history':
        final okClear = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              _roomText(
                context,
                ru: 'Очистить историю комнаты?',
                en: 'Clear room history?',
              ),
            ),
            content: Text(
              _roomText(
                context,
                ru: 'История будет очищена у всех участников комнаты. Новые сообщения после очистки сохранятся.',
                en: 'History will be cleared for every room participant. New messages sent after the clear will remain.',
                uk: 'Історію буде очищено для всіх учасників кімнати. Нові повідомлення після очищення залишаться.',
                es: 'El historial se borrara para todos los participantes de la sala. Los mensajes nuevos enviados despues se conservaran.',
                pt: 'O historico sera limpo para todos os participantes da sala. As mensagens novas enviadas depois continuarao.',
                ptBr:
                    'O historico sera limpo para todos os participantes da sala. As novas mensagens enviadas depois permanecerao.',
                fr: 'L historique sera efface pour tous les participants du salon. Les nouveaux messages envoyes ensuite resteront.',
                de: 'Der Verlauf wird fuer alle Raumteilnehmer geloescht. Neue Nachrichten nach dem Loeschen bleiben erhalten.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(_roomText(context, ru: 'Отмена', en: 'Cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(_roomText(context, ru: 'Очистить', en: 'Clear')),
              ),
            ],
          ),
        );
        if (okClear != true) {
          return;
        }
        try {
          await widget.controller.clearChatHistoryEverywhere(
            convoId: widget.groupId,
          );
        } catch (error) {
          if (!mounted) {
            return;
          }
          _showRoomActionError(context, error);
        }
        return;
      case 'report':
        await _reportRoom(vm);
        return;
      case 'search_members':
        await showSearch<void>(
          context: context,
          delegate: _MemberSearchDelegate(members: vm.members),
        );
        return;
      case 'delete_leave':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              _roomText(context, ru: 'Покинуть комнату?', en: 'Leave room?'),
            ),
            content: Text(
              _roomText(
                context,
                ru: 'Вы действительно хотите удалить и покинуть комнату?',
                en: 'Do you really want to delete and leave this room?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(_roomText(context, ru: 'Отмена', en: 'Cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(_roomText(context, ru: 'Покинуть', en: 'Leave')),
              ),
            ],
          ),
        );
        if (ok == true) {
          await _leaveRoomAndPop();
        }
        return;
      case 'leave':
        final okLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              _roomText(context, ru: 'Покинуть комнату?', en: 'Leave room?'),
            ),
            content: Text(
              _roomText(
                context,
                ru: 'Вы действительно хотите покинуть эту комнату?',
                en: 'Do you really want to leave this room?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(_roomText(context, ru: 'Отмена', en: 'Cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(_roomText(context, ru: 'Покинуть', en: 'Leave')),
              ),
            ],
          ),
        );
        if (okLeave == true) {
          await _leaveRoomAndPop();
        }
        return;
    }
  }

  Widget _roomMenuAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      // Отклик для всех строк меню комнаты сразу: построитель используется 11
      // раз. В комнатах было 85 нажимаемых элементов и ни одного отклика.
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: iconColor ?? cs.onSurface.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: widget.controller.changed,
      builder: (context, _) {
        return FutureBuilder<_RoomVm>(
          future: _load(),
          builder: (context, snapshot) {
            final vm = snapshot.data;
            final canEditRoomProfile =
                vm != null &&
                vm.policy.isMember &&
                vm.policy.canChangeGroupInfo;
            final canOpenAdministration =
                vm != null && _canManageRoomAdministration(vm.policy);
            final screen = MediaQuery.of(context).size;
            final safeTop = MediaQuery.of(context).padding.top;
            final screenW = screen.width;
            final expandedImageHeight = (screen.height * 0.52).clamp(
              320.0,
              520.0,
            );
            // Animated-hero geometry — IDENTICAL formulas to contact_details:
            // avatar + name + status + buttons all live in a single
            // Stack(Clip.none) whose positions/sizes lerp on _pullExpand
            // (0 collapsed → 1 fully-expanded photo).
            final avatarSize = lerpDouble(112, screenW, _pullExpand)!;
            final avatarHeight = lerpDouble(
              112,
              expandedImageHeight,
              _pullExpand,
            )!;
            final avatarRadius = lerpDouble(56, 0, _pullExpand)!;
            final collapsedAvatarTop = safeTop + 8;
            const expandedAvatarTop = 0.0;
            final avatarTop = lerpDouble(
              collapsedAvatarTop,
              expandedAvatarTop,
              _pullExpand,
            )!;

            final collapsedNameTop = collapsedAvatarTop + 112 + 18;
            final expandedNameTop = expandedAvatarTop + avatarHeight - 126;
            final nameTop = lerpDouble(
              collapsedNameTop,
              expandedNameTop,
              _pullExpand,
            )!;

            final collapsedStatusTop = collapsedNameTop + 42;
            final expandedStatusTop = expandedNameTop + 38;
            final statusTop = lerpDouble(
              collapsedStatusTop,
              expandedStatusTop,
              _pullExpand,
            )!;

            final collapsedButtonsTop = collapsedStatusTop + 38;
            final expandedButtonsTop = expandedNameTop + 58;
            final buttonsTop = lerpDouble(
              collapsedButtonsTop,
              expandedButtonsTop,
              _pullExpand,
            )!;

            final collapsedHeroBottom = collapsedButtonsTop + 66 + 20;
            final expandedHeroBottom = expandedAvatarTop + avatarHeight + 18;
            final heroHeight = lerpDouble(
              collapsedHeroBottom,
              expandedHeroBottom,
              _pullExpand,
            )!;
            final titleScale = lerpDouble(1.0, 1.06, _pullExpand)!;
            final subtitleScale = lerpDouble(1.0, 1.04, _pullExpand)!;
            // 🔴 Раскрытая шапка без фото — это заливка заглушки, а в светлой
            // теме она почти белая: белые название, значок и число участников
            // по ней не читались (1,3–1,6 : 1). Там они остаются цветом темы;
            // над фото и над тёмной заливкой белеют, как раньше (17.09.2026).
            final heroPhoto = vm?.settings.avatarPath;
            final heroOnLightFallback =
                vm != null &&
                !(heroPhoto != null &&
                    heroPhoto.isNotEmpty &&
                    File(heroPhoto).existsSync()) &&
                AvatarInitials.fillIsLight(
                  context,
                  seed: widget.groupId.isNotEmpty ? widget.groupId : vm.title,
                );
            final heroTextWhite = _pullExpand > 0.35 && !heroOnLightFallback;
            // The room has no custom cover field — derive a soft cover backdrop
            // from the room avatar (blurred), guarded against a missing/empty
            // file.
            final coverAvatarPath = _existingAvatarPath(
              vm?.settings.avatarPath,
            );
            // Premium ROOM cosmetics (synced from the owner; viewing is never
            // gated). When a preset cover id is set it replaces the blurred-
            // avatar backdrop; the frame ring encircles the avatar; the name
            // emoji sits next to the title. All null-guarded.
            final roomCover = vm == null
                ? null
                : coverWidgetFor(vm.settings.coverId);
            final roomFrame = vm == null
                ? null
                : frameById(vm.settings.frameId);
            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: frostedAppBar(
                // No full top bar — it would crop the cover/photo. Suppress
                // frostedAppBar's default FrostedTopBarBackground; back + edit +
                // more live in floating islands so the cover/photo shows through.
                flexibleSpace: const SizedBox.shrink(),
                automaticallyImplyLeading: false,
                leadingWidth: 64,
                leading: Opacity(
                  opacity: (1.0 - _pullExpand * 2.0).clamp(0.0, 1.0),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                    child: FrostedHeaderIsland(
                      radius: 24,
                      height: 48,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  Opacity(
                    opacity: (1.0 - _pullExpand * 2.0).clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: FrostedHeaderIsland(
                        radius: 24,
                        height: 48,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: _roomText(
                              context,
                              ru: 'Управление комнатой',
                              en: 'Room administration',
                            ),
                            icon: const Icon(AppIcons.edit),
                            onPressed:
                                !canOpenAdministration || _pullExpand >= 1.0
                                ? null
                                : () => _openRoomAdministration(vm),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Opacity(
                    opacity: (1.0 - _pullExpand * 2.0).clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 8,
                        top: 4,
                        bottom: 4,
                      ),
                      child: FrostedHeaderIsland(
                        radius: 24,
                        height: 48,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: _roomText(context, ru: 'Меню', en: 'Menu'),
                            icon: const Icon(AppIcons.moreVert, size: 23),
                            onPressed: vm == null || _pullExpand >= 1.0
                                ? null
                                : () => _openMenu(vm),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: vm == null
                  ? const Center(child: CircularProgressIndicator())
                  : GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate:
                          (_pullExpand >= 1.0 || _collapseGestureActive)
                          ? _handleCollapseDrag
                          : null,
                      onVerticalDragEnd:
                          (_pullExpand >= 1.0 || _collapseGestureActive)
                          ? _handleCollapseDragEnd
                          : null,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleAvatarPull,
                        child: ListView(
                          controller: _scrollController,
                          physics:
                              (_pullExpand >= 1.0 || _collapseGestureActive)
                              ? const NeverScrollableScrollPhysics()
                              // Match own-profile's smooth pull (see contact_details).
                              : const ClampingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                          padding: EdgeInsets.only(
                            top: 0,
                            bottom: MediaQuery.of(context).padding.bottom + 40,
                          ),
                          children: [
                            // ANIMATED HERO — mirrors contact_details exactly: a
                            // SizedBox(heroHeight) holding a Stack(Clip.none) of
                            // cover + decoupled scrim + Positioned-lerp avatar /
                            // name / status / 4 action buttons. Pulling the avatar
                            // (or overscrolling the list) drives _pullExpand and
                            // the whole hero animates together.
                            SizedBox(
                              height: heroHeight,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  if (roomCover != null ||
                                      coverAvatarPath != null) ...[
                                    // 1) Cover backdrop — a premium preset COVER
                                    //    when the owner set one, otherwise the
                                    //    room avatar blurred + dimmed. Bottom-
                                    //    aligned to the buttons row; fades out as
                                    //    we pull-expand.
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      height: collapsedButtonsTop + 66,
                                      child: IgnorePointer(
                                        child: Opacity(
                                          opacity: (1.0 - _pullExpand * 2.0)
                                              .clamp(0.0, 1.0),
                                          child:
                                              (roomCover != null
                                                  ? CosmeticShowcaseScope(
                                                      child: roomCover,
                                                    )
                                                  : null) ??
                                              ClipRect(
                                                child: ImageFiltered(
                                                  imageFilter: ImageFilter.blur(
                                                    sigmaX: 38,
                                                    sigmaY: 38,
                                                  ),
                                                  child: Image.file(
                                                    File(coverAvatarPath!),
                                                    fit: BoxFit.cover,
                                                    filterQuality:
                                                        FilterQuality.low,
                                                    gaplessPlayback: true,
                                                    errorBuilder: (_, __, ___) =>
                                                        const SizedBox.shrink(),
                                                  ),
                                                ),
                                              ),
                                        ),
                                      ),
                                    ),
                                    // 2) Decoupled page-colour scrim — a SEPARATE
                                    //    layer running DOWN PAST the cover
                                    //    (Clip.none overflow) so the cover darkens
                                    //    into the page colour cleanly with no
                                    //    bright bleed.
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      height: collapsedHeroBottom + 16,
                                      child: IgnorePointer(
                                        child: Opacity(
                                          opacity: (1.0 - _pullExpand * 2.0)
                                              .clamp(0.0, 1.0),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              // Theme-background scrim so the room
                                              // cover blends on light + dark themes.
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                stops: const [0.0, 0.55, 1.0],
                                                colors: [
                                                  AppBackground.scrimColorOf(
                                                    context,
                                                  ).withValues(alpha: 0.4),
                                                  AppBackground.scrimColorOf(
                                                    context,
                                                  ).withValues(alpha: 0.2),
                                                  AppBackground.scrimColorOf(
                                                    context,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  Positioned(
                                    top: avatarTop,
                                    left: (screenW - avatarSize) / 2,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _openAvatarFullScreen(vm),
                                      onVerticalDragUpdate: (details) =>
                                          _handleAvatarSurfaceDragUpdate(
                                            details,
                                            vm: vm,
                                          ),
                                      onVerticalDragEnd:
                                          _handleAvatarSurfaceDragEnd,
                                      // Keep the footprint exactly avatarSize so
                                      // left:(screenW-avatarSize)/2 centers it; the
                                      // optional edit badge (+12) overflows
                                      // symmetrically via OverflowBox instead of
                                      // shifting the avatar off-centre.
                                      child: SizedBox(
                                        width: avatarSize,
                                        height: avatarHeight,
                                        child: OverflowBox(
                                          maxWidth: double.infinity,
                                          maxHeight: double.infinity,
                                          child: _RoomAvatar(
                                            title: vm.title,
                                            // 🔴 ТОТ ЖЕ КЛЮЧ, ЧТО В СПИСКЕ
                                            // КОМНАТ, — иначе заглушка на
                                            // этой странице другого цвета,
                                            // чем в списке и в шапке чата.
                                            seed: widget.groupId,
                                            avatarPath: vm.settings.avatarPath,
                                            heroTag:
                                                'room-avatar-${widget.groupId}',
                                            width: avatarSize,
                                            height: avatarHeight,
                                            borderRadius: avatarRadius,
                                            onEditTap:
                                                (canEditRoomProfile &&
                                                    _pullExpand < 0.01)
                                                ? () => _changeRoomAvatar(vm)
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (roomFrame != null)
                                    // Premium FRAME ring encircling the avatar —
                                    // box = avatarSize/0.86 (matches the gap used
                                    // in contact_details). Fades out on pull-
                                    // expand. Synced from the owner; viewing is
                                    // never gated.
                                    Positioned(
                                      top:
                                          avatarTop +
                                          avatarHeight / 2 -
                                          (avatarSize / 0.86) / 2,
                                      left: (screenW - avatarSize / 0.86) / 2,
                                      child: IgnorePointer(
                                        child: Opacity(
                                          opacity: (1.0 - _pullExpand * 3.0)
                                              .clamp(0.0, 1.0),
                                          child: SizedBox(
                                            width: avatarSize / 0.86,
                                            height: avatarSize / 0.86,
                                            // Showcase: same as a profile page
                                            // — one big avatar, painted live at
                                            // full resolution.
                                            child: CosmeticShowcaseScope(
                                              child: roomFrame.builder(
                                                avatarSize / 0.86,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: nameTop,
                                    left: 24,
                                    right: 24,
                                    child: Align(
                                      alignment: Alignment.lerp(
                                        Alignment.topCenter,
                                        Alignment.topLeft,
                                        _pullExpand,
                                      )!,
                                      child: Transform.scale(
                                        scale: titleScale,
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                vm.title,
                                                textAlign: _pullExpand > 0.35
                                                    ? TextAlign.left
                                                    : TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: heroTextWhite
                                                          ? Colors.white
                                                          : null,
                                                    ),
                                              ),
                                            ),
                                            // A person icon to the right of the room
                                            // name (mirrors the own-profile title
                                            // row's right-of-name icon).
                                            const SizedBox(width: 8),
                                            Icon(
                                              AppIcons.personOutline,
                                              size: 20,
                                              color: heroTextWhite
                                                  ? Colors.white
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                        .withValues(
                                                          alpha: 0.75,
                                                        ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: statusTop,
                                    left: 24,
                                    right: 24,
                                    child: Align(
                                      alignment: Alignment.lerp(
                                        Alignment.topCenter,
                                        Alignment.topLeft,
                                        _pullExpand,
                                      )!,
                                      child: Transform.scale(
                                        scale: subtitleScale,
                                        alignment: Alignment.centerLeft,
                                        // Tapping the participant count opens the
                                        // full-screen member list.
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: _openRoomMembersList,
                                          child: Text(
                                            _roomText(
                                              context,
                                              ru: '${vm.members.length}${_memberCapSuffix(vm.members.length)} участник${_pluralRu(vm.members.length)}',
                                              en: '${vm.members.length}${_memberCapSuffix(vm.members.length)} participant${vm.members.length == 1 ? '' : 's'}',
                                              uk: 'Учасників: ${vm.members.length}${_memberCapSuffix(vm.members.length)}',
                                              es: 'Participantes: ${vm.members.length}${_memberCapSuffix(vm.members.length)}',
                                              pt: 'Participantes: ${vm.members.length}${_memberCapSuffix(vm.members.length)}',
                                              ptBr:
                                                  'Participantes: ${vm.members.length}${_memberCapSuffix(vm.members.length)}',
                                              fr: 'Participants : ${vm.members.length}${_memberCapSuffix(vm.members.length)}',
                                              de: 'Teilnehmer: ${vm.members.length}${_memberCapSuffix(vm.members.length)}',
                                            ),
                                            textAlign: _pullExpand > 0.35
                                                ? TextAlign.left
                                                : TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: heroTextWhite
                                                      ? Colors.white.withValues(
                                                          alpha: 0.9,
                                                        )
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: buttonsTop,
                                    // Four equal-width action chips (chat / sound
                                    // / call / leave) — same chips/onTaps as
                                    // before, now animating with the hero. Tighter
                                    // horizontal padding (12) + gap (8) so four
                                    // chips fit a row without overflow.
                                    left: 12,
                                    right: 12,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _ActionChip(
                                            icon: AppIcons.chatBubbleSolid,
                                            label: _roomText(
                                              context,
                                              ru: 'Чат',
                                              en: 'Chat',
                                            ),
                                            onTap: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _ActionChip(
                                            icon: vm.muted
                                                ? AppIcons.bellOffSolid
                                                : AppIcons.bellSolid,
                                            label: _roomText(
                                              context,
                                              ru: 'Звук',
                                              en: 'Sound',
                                            ),
                                            onTap: () =>
                                                unawaited(_toggleRoomMuted(vm)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _ActionChip(
                                            icon: AppIcons.roomCallAction,
                                            iconColor: vm.activeCall == null
                                                ? null
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                            label: _roomText(
                                              context,
                                              ru: 'Звонок',
                                              en: 'Call',
                                            ),
                                            onTap: () =>
                                                _openRoomCallScreen(vm),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _ActionChip(
                                            icon: AppIcons.leaveRoomAction,
                                            iconColor: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                            labelColor: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                            label: _roomText(
                                              context,
                                              ru: 'Покинуть',
                                              en: 'Leave',
                                            ),
                                            onTap: () =>
                                                unawaited(_leaveRoomAndPop()),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // ◆ ТРИ ВКЛАДКИ, КАК В ОКНЕ НА КОМПЬЮТЕРЕ (указание владельца).
                            //
                            // Страница комнаты была одной лентой: настройки, потом «добавить
                            // участников», потом медиа — а САМОГО НУЖНОГО, списка людей, на ней
                            // не было вовсе, он прятался за нажатием по счётчику в шапке.
                            // Теперь то же деление, что и на компьютере: сведения, участники,
                            // медиа.
                            _RoomTabs(
                              index: _roomTab,
                              membersCount: vm.members.length,
                              onChanged: (i) => setState(() => _roomTab = i),
                            ),
                            if (_roomTab == 0) ...[
                            if (canEditRoomProfile) ...[
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: _SectionBlock(
                                  children: [
                                    ListTile(
                                      leading: const Icon(AppIcons.edit),
                                      title: Text(
                                        _roomText(
                                          context,
                                          ru: 'Изменить название',
                                          en: 'Change name',
                                        ),
                                      ),
                                      subtitle: Text(
                                        vm.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => _editRoomTitle(vm),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(Icons.notes_rounded),
                                      title: Text(
                                        _roomText(
                                          context,
                                          ru: 'Описание',
                                          en: 'Description',
                                        ),
                                      ),
                                      subtitle: Text(
                                        (vm.settings.description ?? '')
                                                .trim()
                                                .isEmpty
                                            ? _roomText(
                                                context,
                                                ru: 'Не задано',
                                                en: 'Not set',
                                              )
                                            : vm.settings.description!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => _editRoomDescription(vm),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Premium ROOM cosmetics — visible to the room OWNER only.
                            // A non-premium owner still sees the rows (so the feature
                            // is discoverable) but tapping opens the paywall; a
                            // premium owner gets the pickers. Members never see this
                            // editor — they only see the rendered result in the hero.
                            if (vm.settings.ownerProfileId ==
                                widget.controller.profileId) ...[
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: _SectionBlock(
                                  children: [
                                    ListTile(
                                      leading: const Icon(
                                        Icons.filter_frames_rounded,
                                      ),
                                      title: Text(
                                        _roomText(
                                          context,
                                          ru: 'Рамка',
                                          en: 'Frame',
                                          uk: 'Рамка',
                                          es: 'Marco',
                                          pt: 'Moldura',
                                          ptBr: 'Moldura',
                                          fr: 'Cadre',
                                          de: 'Rahmen',
                                        ),
                                      ),
                                      subtitle: Text(
                                        _roomCosmeticSubtitle(
                                          frameById(
                                            vm.settings.frameId,
                                          )?.nameLocalized(context),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => _pickRoomFrame(vm),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.wallpaper_rounded,
                                      ),
                                      title: Text(
                                        _roomText(
                                          context,
                                          ru: 'Обложка',
                                          en: 'Cover',
                                          uk: 'Обкладинка',
                                          es: 'Portada',
                                          pt: 'Capa',
                                          ptBr: 'Capa',
                                          fr: 'Couverture',
                                          de: 'Titelbild',
                                        ),
                                      ),
                                      subtitle: Text(
                                        _roomCosmeticSubtitle(
                                          coverById(
                                            vm.settings.coverId,
                                          )?.nameLocalized(context),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => _pickRoomCover(vm),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            // ◆ ID КОМНАТЫ ВИДЕН, А НЕ ТОЛЬКО КОПИРУЕТСЯ.
                            //
                            // На телефоне он был спрятан в меню «⋮» пунктом
                            // «Скопировать ID комнаты»: скопировать можно,
                            // ПОСМОТРЕТЬ — нельзя, а сверить с тем, что тебе
                            // прислали, тем более. В окне на компьютере он всё
                            // это время стоял строкой с кнопкой копирования.
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: _SectionBlock(
                                children: [
                                  ListTile(
                                    leading: const Icon(AppIcons.badge),
                                    title: Text(
                                      widget.groupId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    subtitle: Text(
                                      _roomText(
                                        context,
                                        ru: 'ID комнаты',
                                        en: 'Room ID',
                                      ),
                                    ),
                                    trailing: const Icon(AppIcons.copy),
                                    onTap: _copyRoomId,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: _SectionBlock(
                                children: [
                                  ListTile(
                                    leading: const Icon(AppIcons.tag),
                                    title: Text(
                                      _roomText(
                                        context,
                                        ru: 'Ваш тег в комнате',
                                        en: 'Your room tag',
                                      ),
                                    ),
                                    subtitle: Text(
                                      () {
                                        final myTag = vm.members
                                            .where(
                                              (m) =>
                                                  m.profileId == vm.myProfileId,
                                            )
                                            .map(_roomMemberTag)
                                            .whereType<String>()
                                            .cast<String?>()
                                            .firstOrNull;
                                        return (myTag ?? '').trim().isEmpty
                                            ? _roomText(
                                                context,
                                                ru: 'Не задан',
                                                en: 'Not set',
                                              )
                                            : myTag!;
                                      }(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: vm.policy.canChangeOwnTag
                                        ? const Icon(AppIcons.edit)
                                        : null,
                                    onTap: vm.policy.canChangeOwnTag
                                        ? () => _editOwnTag(vm)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            ],
                            if (_roomTab == 1)
                              _RoomMembersPanel(
                                controller: widget.controller,
                                members: vm.members,
                                myProfileId: vm.myProfileId,
                                ownerProfileId: vm.settings.ownerProfileId,
                                canAdd:
                                    vm.policy.isMember &&
                                    vm.policy.canAddMembers,
                                canInvite: vm.policy.isMember,
                                onAdd: () => unawaited(_openAddMembers(vm)),
                                onInvite: () =>
                                    unawaited(_inviteInsideSecretly(vm)),
                                onOpenAll: _openRoomMembersList,
                                onOpenMember: _openMemberProfile,
                                onMessageMember: _messageMember,
                              ),
                            if (_roomTab == 2) ...[
                            const SizedBox(height: 16),
                            // Media previews sit directly on the page (same
                            // presentation as the peer-profile screen) — no
                            // section card / header placeholder around them,
                            // and the section scrolls WITH the page.
                            ConversationMediaGallerySection(
                              controller: widget.controller,
                              convoId: widget.groupId,
                            ),
                            ],
                          ],
                        ),
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  /// " / 50" when the room is close to the member cap, empty otherwise.
  ///
  /// The cap already exists and is enforced by the SERVER (the owner's tier:
  /// group_members), but the app never mentioned it — so a room simply started
  /// refusing new people with a raw `group_member_limit_reached`. Showing the
  /// ceiling only as it comes into view keeps the normal case clean while making
  /// the wall visible before you hit it.
  ///
  /// Worth knowing: every room message is encrypted SEPARATELY for each device
  /// of each member (no group key), so the cost of a room grows with its size.
  /// Large rooms are expensive by construction, not by accident.
  String _memberCapSuffix(int count) {
    final cap = widget.controller.roomMemberCapNow;
    if (cap <= 0 || count <= 0) return ''; // <=0 means "no cap" on the server
    // Only surface it from 70% of the cap onwards, so ordinary rooms stay clean.
    if (count * 10 < cap * 7) return '';
    return ' / $cap';
  }

  String _pluralRu(int value) {
    final mod10 = value % 10;
    final mod100 = value % 100;
    if (mod10 == 1 && mod100 != 11) return '';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'а';
    return 'ов';
  }
}

class RoomAdministrationScreen extends StatefulWidget {
  const RoomAdministrationScreen({
    super.key,
    required this.controller,
    required this.groupId,
  });

  final AppController controller;
  final String groupId;

  @override
  State<RoomAdministrationScreen> createState() =>
      _RoomAdministrationScreenState();
}

class _RoomAdministrationScreenState extends State<RoomAdministrationScreen> {
  bool get _isRu => roomLocaleIsRussian(context);

  Future<_RoomAdministrationVm> _loadVm() async {
    final settingsFuture = widget.controller.getRoomSettings(widget.groupId);
    final membersFuture = widget.controller.listRoomMembersDetailed(
      widget.groupId,
    );
    final pendingFuture = widget.controller.listRoomJoinRequestsDetailed(
      widget.groupId,
    );
    final bannedFuture = widget.controller.listRoomBannedMembersDetailed(
      widget.groupId,
    );
    final myId = widget.controller.profileId;
    final policyFuture = widget.controller.getRoomPolicyState(
      widget.groupId,
      profileIdOverride: myId,
    );
    final settings = await settingsFuture;
    final members = await membersFuture;
    final pendingMembers = await pendingFuture;
    final bannedMembers = await bannedFuture;
    final policy = await policyFuture;
    final links = policy.canManageInviteLinks
        ? await widget.controller.listRoomInviteLinks(widget.groupId)
        : const <RoomInviteLink>[];
    return _RoomAdministrationVm(
      settings: settings,
      members: members,
      pendingMembers: pendingMembers,
      bannedMembers: bannedMembers,
      inviteLinks: links,
      policy: policy,
      myProfileId: myId,
    );
  }

  Future<void> _approveJoinRequest(String memberProfileId) async {
    try {
      await widget.controller.approveRoomJoinRequest(
        groupId: widget.groupId,
        memberProfileId: memberProfileId,
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
    }
  }

  Future<void> _declineJoinRequest(String memberProfileId) async {
    try {
      await widget.controller.declineRoomJoinRequest(
        groupId: widget.groupId,
        memberProfileId: memberProfileId,
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
    }
  }

  Future<void> _unbanMember(String memberProfileId) async {
    try {
      await widget.controller.unbanRoomMember(
        groupId: widget.groupId,
        memberProfileId: memberProfileId,
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
    }
  }

  Future<void> _banMember(String memberProfileId) async {
    try {
      await widget.controller.banRoomMember(
        groupId: widget.groupId,
        memberProfileId: memberProfileId,
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
    }
  }

  Future<void> _removeMember(String memberProfileId) async {
    try {
      await widget.controller.removeGroupMember(
        groupId: widget.groupId,
        memberProfileId: memberProfileId,
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
    }
  }

  Future<void> _transferOwnership(String memberProfileId) async {
    try {
      await widget.controller.transferRoomOwnership(
        groupId: widget.groupId,
        nextOwnerProfileId: memberProfileId,
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
    }
  }

  Widget? _buildAdminParticipantActions(
    _RoomAdministrationVm vm,
    RoomMember member,
  ) {
    final canRemove =
        vm.policy.canRemoveMembers &&
        member.profileId != vm.myProfileId &&
        !member.isOwner;
    final canBan =
        vm.policy.canBanMembers &&
        member.profileId != vm.myProfileId &&
        !member.isOwner;
    final canTransferOwnership =
        vm.policy.isOwner &&
        member.profileId != vm.myProfileId &&
        member.isActive;
    if (!canRemove && !canBan && !canTransferOwnership) {
      return null;
    }
    return PopupMenuButton<String>(
      tooltip: _roomText(
        context,
        ru: 'Действия с участником',
        en: 'Member actions',
      ),
      onSelected: (value) async {
        switch (value) {
          case 'transfer_owner':
            await _transferOwnership(member.profileId);
            return;
          case 'ban':
            await _banMember(member.profileId);
            return;
          case 'remove':
            await _removeMember(member.profileId);
            return;
        }
      },
      itemBuilder: (context) {
        return <PopupMenuEntry<String>>[
          if (canTransferOwnership)
            PopupMenuItem<String>(
              value: 'transfer_owner',
              child: Text(
                _roomText(
                  context,
                  ru: 'Передать владение',
                  en: 'Transfer ownership',
                ),
              ),
            ),
          if (canBan)
            PopupMenuItem<String>(
              value: 'ban',
              child: Text(_roomText(context, ru: 'Заблокировать', en: 'Ban')),
            ),
          if (canRemove)
            PopupMenuItem<String>(
              value: 'remove',
              child: Text(_roomText(context, ru: 'Удалить', en: 'Remove')),
            ),
        ];
      },
    );
  }

  Future<void> _ownerActionLeaveOrDelete(_RoomAdministrationVm vm) async {
    final otherActiveMembers = vm.members
        .where((m) => m.profileId != vm.myProfileId && m.isActive)
        .toList(growable: false);
    if (vm.policy.isOwner && otherActiveMembers.isNotEmpty) {
      final choice = await showDialog<String?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            _roomText(
              context,
              ru: 'Вы владелец комнаты',
              en: 'You are the room owner',
            ),
          ),
          content: Text(
            _roomText(
              context,
              ru: 'Передайте права другому участнику или удалите комнату сразу для всех. Это действие затронет всех участников.',
              en: 'Transfer ownership to another member or delete the room for everyone. This action affects every participant.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(_roomText(context, ru: 'Отмена', en: 'Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('transfer'),
              child: Text(
                _roomText(
                  context,
                  ru: 'Передать права',
                  en: 'Transfer ownership',
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('delete_all'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(
                _roomText(
                  context,
                  ru: 'Удалить комнату для всех',
                  en: 'Delete room for everyone',
                ),
              ),
            ),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == 'transfer') {
        final nextOwnerProfileId = await _pickNextRoomOwnerDialog(
          context,
          isRu: _isRu,
          members: vm.members,
          currentProfileId: vm.myProfileId,
        );
        if (!mounted) return;
        if (nextOwnerProfileId == null) return;
        try {
          await widget.controller.transferRoomOwnership(
            groupId: widget.groupId,
            nextOwnerProfileId: nextOwnerProfileId,
          );
          await widget.controller.leaveRoom(widget.groupId);
          if (!mounted) return;
          Navigator.of(context).pop(true);
        } catch (e) {
          if (!mounted) return;
          _showRoomActionError(context, e);
        }
        return;
      }
      if (choice == 'delete_all') {
        try {
          await widget.controller.deleteRoom(widget.groupId);
          if (!mounted) return;
          Navigator.of(context).pop(true);
        } catch (error) {
          if (!mounted) return;
          _showRoomActionError(context, error);
        }
        return;
      }
    }
    try {
      await widget.controller.leaveRoom(widget.groupId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
    }
  }

  String _ownerActionLabel(_RoomAdministrationVm vm) {
    final hasOtherActive = vm.members.any(
      (member) => member.profileId != vm.myProfileId && member.isActive,
    );
    if (!vm.policy.isOwner) {
      return _roomText(context, ru: 'Покинуть комнату', en: 'Leave room');
    }
    if (hasOtherActive) {
      return _roomText(
        context,
        ru: 'Передать права или удалить комнату',
        en: 'Transfer ownership or delete room',
      );
    }
    return _roomText(context, ru: 'Удалить комнату', en: 'Delete room');
  }

  /// Opens a room member's OWN profile (their avatar/name), from where "Chat"
  /// starts a real 1:1 with them — never the room. Tapping yourself is a no-op.
  void _openRoomMemberProfile(RoomMember member) {
    final pid = member.profileId.trim();
    if (pid.isEmpty || pid == widget.controller.profileId) return;
    final label = member.displayName.trim();
    Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => ContactDetailsScreen(
          controller: widget.controller,
          peerProfileId: pid,
          convoId: pid,
          initialTitle: label.isEmpty ? null : label,
          initialAvatarPath: member.avatarPath,
          openChatByPush: true,
        ),
      ),
    );
  }

  Widget _buildAdminMemberSection({
    required IconData icon,
    required String title,
    required List<RoomMember> members,
    required String emptyText,
    required Widget Function(RoomMember member) trailingBuilder,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _SectionBlock(
        children: [
          ListTile(
            leading: Icon(icon),
            title: Text(title),
            trailing: Text('${members.length}'),
          ),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  emptyText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (var index = 0; index < members.length; index++) ...[
              const Divider(height: 1),
              ListTile(
                leading: _MiniAvatar(
                  title: members[index].displayName,
                  avatarPath: members[index].avatarPath,
                  seed: members[index].profileId,
                ),
                title: Text(
                  members[index].displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _roomMemberSubtitleForContext(
                    context,
                    members[index],
                    includeProfileId: true,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: trailingBuilder(members[index]),
                onTap: () => _openRoomMemberProfile(members[index]),
              ),
            ],
        ],
      ),
    );
  }

  List<RoomMemberRole> _editableRoomRolesForMember(
    _RoomAdministrationVm vm,
    RoomMember member,
  ) {
    if (!member.isActive ||
        member.isOwner ||
        member.profileId == vm.myProfileId) {
      return <RoomMemberRole>[member.role];
    }
    if (vm.policy.isOwner) {
      return const <RoomMemberRole>[
        RoomMemberRole.admin,
        RoomMemberRole.moderator,
        RoomMemberRole.member,
        RoomMemberRole.restricted,
        RoomMemberRole.guest,
      ];
    }
    if (vm.policy.isAdmin && !member.isAdmin) {
      return const <RoomMemberRole>[
        RoomMemberRole.moderator,
        RoomMemberRole.member,
        RoomMemberRole.restricted,
        RoomMemberRole.guest,
      ];
    }
    return <RoomMemberRole>[member.role];
  }

  Future<RoomMemberRole?> _pickSingleMemberRole(
    RoomMember member,
    List<RoomMemberRole> roles,
    RoomMemberRole currentRole,
  ) {
    if (roles.isEmpty) {
      return Future<RoomMemberRole?>.value(null);
    }
    if (roles.length == 1) {
      return Future<RoomMemberRole?>.value(roles.first);
    }
    return showModalBottomSheet<RoomMemberRole>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final cs = theme.colorScheme;
        return SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Material(
              color: cs.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _roomText(
                        context,
                        ru: 'Изменить роль',
                        en: 'Change role',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final role in roles)
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: Icon(
                          currentRole == role
                              ? Icons.check_circle_rounded
                              : Icons.shield_outlined,
                          color: currentRole == role
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                        title: Text(_roomRoleLabelForContext(context, role)),
                        onTap: () => Navigator.of(sheetContext).pop(role),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickMemberRoles(_RoomAdministrationVm vm) async {
    final selected = await showDialog<Map<String, RoomMemberRole>>(
      context: context,
      builder: (context) {
        final picked = <String, RoomMemberRole>{
          for (final member in vm.members.where((member) => member.isActive))
            member.profileId: member.role,
        };
        return StatefulBuilder(
          builder: (context, setLocal) {
            final size = MediaQuery.sizeOf(context);
            final dialogWidth = (size.width - 24)
                .clamp(320.0, 860.0)
                .toDouble();
            final dialogHeight = (size.height * 0.82)
                .clamp(460.0, size.height - 32)
                .toDouble();
            final activeMembers = vm.members
                .where((member) => member.isActive)
                .toList(growable: false);
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              child: SizedBox(
                width: dialogWidth,
                height: dialogHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _roomText(
                                    context,
                                    ru: 'Роли участников',
                                    en: 'Participant roles',
                                  ),
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _roomText(
                                    context,
                                    ru: 'Выберите новую роль для участников комнаты.',
                                    en: 'Choose a new role for room participants.',
                                  ),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                            onPressed: () => Navigator.of(context).pop(null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: activeMembers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final member = activeMembers[index];
                            final availableRoles = _editableRoomRolesForMember(
                              vm,
                              member,
                            );
                            final memberTag = _roomMemberTag(member);
                            final currentRole =
                                picked[member.profileId] ?? member.role;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: _MiniAvatar(
                                      title: member.displayName,
                                      avatarPath: member.avatarPath,
                                      seed: member.profileId,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.displayName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _roomMemberSubtitleForContext(
                                            context,
                                            member,
                                            includeProfileId: true,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                        if (memberTag != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            memberTag,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 184,
                                    child: availableRoles.length > 1
                                        ? OutlinedButton(
                                            onPressed: () async {
                                              final next =
                                                  await _pickSingleMemberRole(
                                                    member,
                                                    availableRoles,
                                                    currentRole,
                                                  );
                                              if (next == null) return;
                                              setLocal(() {
                                                picked[member.profileId] = next;
                                              });
                                            },
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    _roomRoleLabelForContext(
                                                      context,
                                                      currentRole,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  size: 18,
                                                ),
                                              ],
                                            ),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                            ),
                                            child: Text(
                                              _roomRoleLabelForContext(
                                                context,
                                                currentRole,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: Text(
                              _roomText(context, ru: 'Отмена', en: 'Cancel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(picked),
                            child: Text(
                              _roomText(context, ru: 'Сохранить', en: 'Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (selected == null) return;
    final changedMembers = vm.members
        .where(
          (member) =>
              member.isActive &&
              selected[member.profileId] != null &&
              selected[member.profileId] != member.role,
        )
        .toList(growable: false);
    if (changedMembers.isEmpty) {
      return;
    }
    try {
      for (var index = 0; index < changedMembers.length; index++) {
        final member = changedMembers[index];
        await widget.controller.setRoomMemberRole(
          groupId: widget.groupId,
          memberProfileId: member.profileId,
          role: selected[member.profileId]!,
          syncSnapshot: index == changedMembers.length - 1,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: Text(
          _roomText(
            context,
            ru: 'Управление комнатой',
            en: 'Room administration',
          ),
        ),
      ),
      body: StreamBuilder<void>(
        stream: widget.controller.changed,
        builder: (context, _) {
          return FutureBuilder<_RoomAdministrationVm>(
            future: _loadVm(),
            builder: (context, snapshot) {
              final vm = snapshot.data;
              if (vm == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!_canManageRoomAdministration(vm.policy)) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      _roomText(
                        context,
                        ru: 'Этот экран доступен только владельцам и администраторам комнаты.',
                        en: 'Only room owners and admins can open this screen.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final adminTiles = <Widget>[];

              void addTile(Widget tile) {
                if (adminTiles.isNotEmpty) {
                  adminTiles.add(const Divider(height: 1));
                }
                adminTiles.add(tile);
              }

              if (vm.policy.canManageSettings) {
                addTile(
                  ListTile(
                    leading: const Icon(AppIcons.emoji),
                    title: Text(
                      _roomText(context, ru: 'Реакции', en: 'Reactions'),
                    ),
                    subtitle: Text(
                      _roomText(
                        context,
                        ru: 'Управляйте режимом реакций для всей комнаты.',
                        en: 'Control the reaction mode for the whole room.',
                      ),
                    ),
                    trailing: Text(
                      _roomReactionModeLabelForContext(
                        context,
                        vm.settings.reactionsMode,
                      ),
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        SecretlyPageRoute(
                          builder: (_) => RoomReactionsScreen(
                            controller: widget.controller,
                            groupId: widget.groupId,
                          ),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                );
                addTile(
                  ListTile(
                    leading: const Icon(AppIcons.lock),
                    title: Text(
                      _roomText(context, ru: 'Разрешения', en: 'Permissions'),
                    ),
                    subtitle: Text(
                      _roomText(
                        context,
                        ru: 'Сообщения, вступление, приватность и профиль комнаты.',
                        en: 'Messages, joining, privacy, and room profile rules.',
                      ),
                    ),
                    trailing: Text(
                      '${_roomPermissionsEnabledCount(vm.settings)}/8',
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        SecretlyPageRoute(
                          builder: (_) => RoomPermissionsScreen(
                            controller: widget.controller,
                            groupId: widget.groupId,
                          ),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                );
              }

              if (vm.policy.canManageInviteLinks) {
                addTile(
                  ListTile(
                    leading: const Icon(Icons.link_rounded),
                    title: Text(
                      _roomText(
                        context,
                        ru: 'Управление ссылками',
                        en: 'Manage invite links',
                      ),
                    ),
                    subtitle: Text(
                      _roomText(
                        context,
                        ru: 'История для новых участников задаётся одной настройкой комнаты.',
                        en: 'History visibility for new members stays under the room setting.',
                      ),
                    ),
                    trailing: Text('${vm.inviteLinks.length}'),
                    onTap: () async {
                      await Navigator.of(context).push(
                        SecretlyPageRoute(
                          builder: (_) => RoomInviteLinksScreen(
                            controller: widget.controller,
                            groupId: widget.groupId,
                          ),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                );
              }

              if (vm.policy.canManageAdmins || vm.policy.canManageMemberRoles) {
                addTile(
                  ListTile(
                    leading: const Icon(AppIcons.verified),
                    title: Text(_roomText(context, ru: 'Роли', en: 'Roles')),
                    subtitle: Text(
                      _roomText(
                        context,
                        ru: 'Назначайте роли и разграничивайте права участников.',
                        en: 'Assign roles and control participant access.',
                      ),
                    ),
                    trailing: Text(
                      '${vm.members.where((m) => m.role != RoomMemberRole.member).length}',
                    ),
                    onTap: () => _pickMemberRoles(vm),
                  ),
                );
              }

              final showJoinRequests =
                  vm.policy.canApproveJoinRequests ||
                  vm.pendingMembers.isNotEmpty;
              final showBanned =
                  vm.policy.canBanMembers || vm.bannedMembers.isNotEmpty;

              return ListView(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _roomText(
                        context,
                        ru: 'Глобальные правила комнаты, роли, ссылки-приглашения, запросы и блокировки.',
                        en: 'Room-wide rules, roles, invite links, join requests, and bans.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _SectionBlock(children: adminTiles),
                  ),
                  const SizedBox(height: 12),
                  _buildAdminMemberSection(
                    icon: AppIcons.groupOutline,
                    title: _roomText(
                      context,
                      ru: 'Участники',
                      en: 'Participants',
                    ),
                    members: vm.members
                        .where((m) => m.isActive)
                        .toList(growable: false),
                    emptyText: _roomText(
                      context,
                      ru: 'В комнате пока нет активных участников.',
                      en: 'There are no active participants in this room yet.',
                    ),
                    trailingBuilder: (member) =>
                        _buildAdminParticipantActions(vm, member) ??
                        const SizedBox.shrink(),
                  ),
                  if (showJoinRequests) ...[
                    const SizedBox(height: 12),
                    _buildAdminMemberSection(
                      icon: Icons.pending_actions_rounded,
                      title: _roomText(
                        context,
                        ru: 'Запросы на вступление',
                        en: 'Join requests',
                      ),
                      members: vm.pendingMembers,
                      emptyText: _roomText(
                        context,
                        ru: 'Нет ожидающих запросов.',
                        en: 'There are no pending join requests.',
                      ),
                      trailingBuilder: (member) {
                        if (!vm.policy.canApproveJoinRequests) {
                          return const SizedBox.shrink();
                        }
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: _roomText(
                                context,
                                ru: 'Одобрить',
                                en: 'Approve',
                              ),
                              icon: const Icon(Icons.check_rounded),
                              onPressed: () =>
                                  _approveJoinRequest(member.profileId),
                            ),
                            IconButton(
                              tooltip: _roomText(
                                context,
                                ru: 'Отклонить',
                                en: 'Decline',
                              ),
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () =>
                                  _declineJoinRequest(member.profileId),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                  if (showBanned) ...[
                    const SizedBox(height: 12),
                    _buildAdminMemberSection(
                      icon: AppIcons.block,
                      title: _roomText(
                        context,
                        ru: 'Заблокированные',
                        en: 'Banned members',
                      ),
                      members: vm.bannedMembers,
                      emptyText: _roomText(
                        context,
                        ru: 'Нет заблокированных участников.',
                        en: 'There are no banned members.',
                      ),
                      trailingBuilder: (member) {
                        if (!vm.policy.canBanMembers) {
                          return const SizedBox.shrink();
                        }
                        return IconButton(
                          tooltip: _roomText(
                            context,
                            ru: 'Снять бан',
                            en: 'Unban',
                          ),
                          icon: const Icon(Icons.undo_rounded),
                          onPressed: () => _unbanMember(member.profileId),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FilledButton.tonal(
                      onPressed: () => _ownerActionLeaveOrDelete(vm),
                      child: Text(
                        _ownerActionLabel(vm),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class RoomReactionsScreen extends StatefulWidget {
  const RoomReactionsScreen({
    super.key,
    required this.controller,
    required this.groupId,
  });

  final AppController controller;
  final String groupId;

  @override
  State<RoomReactionsScreen> createState() => _RoomReactionsScreenState();
}

class _RoomReactionsScreenState extends State<RoomReactionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: Text(_roomText(context, ru: 'Реакции', en: 'Reactions')),
      ),
      body: FutureBuilder<RoomSettings>(
        future: widget.controller.getRoomSettings(widget.groupId),
        builder: (context, snapshot) {
          final settings = snapshot.data;
          if (settings == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _SectionBlock(
                  children: [
                    _reactionRow(
                      settings,
                      RoomReactionsMode.all,
                      _roomText(
                        context,
                        ru: 'Все реакции',
                        en: 'All reactions',
                      ),
                    ),
                    const Divider(height: 1),
                    _reactionRow(
                      settings,
                      RoomReactionsMode.selected,
                      _roomText(
                        context,
                        ru: 'Только выбранные',
                        en: 'Selected only',
                      ),
                    ),
                    const Divider(height: 1),
                    _reactionRow(
                      settings,
                      RoomReactionsMode.none,
                      _roomText(context, ru: 'Без реакций', en: 'No reactions'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _reactionRow(
    RoomSettings settings,
    RoomReactionsMode target,
    String title,
  ) {
    final selected = settings.reactionsMode == target;
    return ListTile(
      title: Text(title),
      trailing: Icon(
        selected ? AppIcons.radioChecked : AppIcons.radioUnchecked,
      ),
      onTap: () async {
        try {
          await widget.controller.updateRoomSettings(
            groupId: widget.groupId,
            settings: settings.copyWith(reactionsMode: target),
          );
        } catch (e) {
          if (!mounted) return;
          _showRoomActionError(context, e);
          return;
        }
        if (!mounted) return;
        setState(() {});
      },
    );
  }
}

class RoomInviteLinksScreen extends StatefulWidget {
  const RoomInviteLinksScreen({
    super.key,
    required this.controller,
    required this.groupId,
  });

  final AppController controller;
  final String groupId;

  @override
  State<RoomInviteLinksScreen> createState() => _RoomInviteLinksScreenState();
}

class _RoomInviteLinksScreenState extends State<RoomInviteLinksScreen> {
  String _formatInviteDateTime(int timestampMs) {
    final material = MaterialLocalizations.of(context);
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal();
    final dateText = material.formatShortDate(date);
    final timeText = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return '$dateText, $timeText';
  }

  String _inviteStatusText(RoomInviteLink link, {required int nowMs}) {
    if (link.revoked) {
      return _roomText(context, ru: 'Статус: отозвана', en: 'Status: revoked');
    }
    if (link.isExpiredAt(nowMs)) {
      return _roomText(
        context,
        ru: 'Статус: срок истёк',
        en: 'Status: expired',
      );
    }
    if (link.isUsageLimitReached) {
      return _roomText(
        context,
        ru: 'Статус: лимит исчерпан',
        en: 'Status: join limit reached',
      );
    }
    return _roomText(context, ru: 'Статус: активна', en: 'Status: active');
  }

  Future<_RoomInviteLinksVm> _loadVm() async {
    final linksFuture = widget.controller.listRoomInviteLinks(widget.groupId);
    final settingsFuture = widget.controller.getRoomSettings(widget.groupId);
    return _RoomInviteLinksVm(
      links: await linksFuture,
      roomApprovalRequired: (await settingsFuture).joinApprovalRequired,
    );
  }

  String _invitePolicyText(
    RoomInviteLink link, {
    required bool roomApprovalRequired,
  }) {
    final roleText = _roomRoleLabelForContext(context, link.allowedRole);
    final requiresApproval = roomApprovalRequired || link.requiresApproval;
    final approvalText = requiresApproval
        ? _roomText(
            context,
            ru: 'по ссылке требуется одобрение',
            en: 'link requires approval',
          )
        : _roomText(
            context,
            ru: 'по ссылке можно вступить сразу',
            en: 'link allows direct join',
          );
    return _roomText(
      context,
      ru: 'Роль: $roleText, $approvalText.',
      en: 'Role: $roleText, $approvalText.',
      uk: 'Роль: $roleText, $approvalText.',
      es: 'Rol: $roleText, $approvalText.',
      pt: 'Funcao: $roleText, $approvalText.',
      ptBr: 'Funcao: $roleText, $approvalText.',
      fr: 'Role : $roleText, $approvalText.',
      de: 'Rolle: $roleText, $approvalText.',
    );
  }

  String _inviteUsageText(RoomInviteLink link) {
    final maxUses = link.maxUses;
    final remainingUses = link.remainingUses;
    if (maxUses == null || remainingUses == null) {
      return _roomText(
        context,
        ru: 'Использования по ссылке не ограничены.',
        en: 'This link has unlimited joins.',
        uk: 'Кількість вступів за посиланням не обмежена.',
        es: 'Este enlace no tiene limite de uniones.',
        pt: 'Este link nao tem limite de entradas.',
        ptBr: 'Este link nao tem limite de entradas.',
        fr: 'Ce lien n a pas de limite d adhesions.',
        de: 'Dieser Link hat keine Beitrittsbegrenzung.',
      );
    }
    return _roomText(
      context,
      ru: 'Использовано: ${link.useCount} из $maxUses. Осталось: $remainingUses.',
      en: 'Used: ${link.useCount} of $maxUses. Remaining: $remainingUses.',
      uk: 'Використано: ${link.useCount} з $maxUses. Залишилося: $remainingUses.',
      es: 'Usado: ${link.useCount} de $maxUses. Quedan: $remainingUses.',
      pt: 'Usado: ${link.useCount} de $maxUses. Restam: $remainingUses.',
      ptBr: 'Usado: ${link.useCount} de $maxUses. Restam: $remainingUses.',
      fr: 'Utilise : ${link.useCount} sur $maxUses. Restants : $remainingUses.',
      de: 'Verwendet: ${link.useCount} von $maxUses. Uebrig: $remainingUses.',
    );
  }

  String _inviteExpiryText(RoomInviteLink link) {
    final expiresAtMs = link.expiresAtMs;
    if (expiresAtMs == null) {
      return _roomText(
        context,
        ru: 'Срок действия по времени не ограничен.',
        en: 'This link does not expire by time.',
        uk: 'Це посилання не має обмеження за часом.',
        es: 'Este enlace no caduca por tiempo.',
        pt: 'Este link nao expira por tempo.',
        ptBr: 'Este link nao expira por tempo.',
        fr: 'Ce lien n expire pas dans le temps.',
        de: 'Dieser Link laeuft zeitlich nicht ab.',
      );
    }
    final dateText = _formatInviteDateTime(expiresAtMs);
    return _roomText(
      context,
      ru: 'Действует до: $dateText.',
      en: 'Valid until: $dateText.',
      uk: 'Діє до: $dateText.',
      es: 'Valido hasta: $dateText.',
      pt: 'Valido ate: $dateText.',
      ptBr: 'Valido ate: $dateText.',
      fr: 'Valide jusqu au : $dateText.',
      de: 'Gueltig bis: $dateText.',
    );
  }

  Future<void> _openInviteLink(RoomInviteLink link) async {
    final target = tryParseRoomInviteUri(Uri.parse(link.shareUrl));
    if (target == null) return;
    await Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) =>
            RoomInviteJoinScreen(controller: widget.controller, target: target),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _copyInviteLink(RoomInviteLink link) async {
    await Clipboard.setData(ClipboardData(text: link.shareUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SecretlySnackBar(
        content: Text(
          _roomText(context, ru: 'Ссылка скопирована', en: 'Link copied'),
        ),
      ),
    );
  }

  Future<void> _shareInviteLink(RoomInviteLink link) {
    return shareTextExternally(text: link.shareUrl);
  }

  Future<void> _handleInviteAction(RoomInviteLink link, String action) async {
    switch (action) {
      case 'copy':
        await _copyInviteLink(link);
        return;
      case 'share':
        await _shareInviteLink(link);
        return;
      case 'revoke':
        try {
          await widget.controller.setRoomInviteLinkRevoked(
            linkId: link.linkId,
            revoked: true,
          );
        } catch (e) {
          if (!mounted) return;
          _showRoomActionError(context, e);
        }
        return;
    }
  }

  Color _inviteDropdownSurface(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tint = cs.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.14 : 0.055,
    );
    return Color.alphaBlend(tint, cs.surfaceContainerHighest);
  }

  Color _inviteDropdownFieldFill(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tint = cs.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.10 : 0.04,
    );
    return Color.alphaBlend(tint, cs.surfaceContainerHigh);
  }

  InputDecoration _inviteDropdownDecoration(
    BuildContext context,
    String label,
  ) {
    final cs = Theme.of(context).colorScheme;
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.66)),
    );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _inviteDropdownFieldFill(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: enabledBorder,
      enabledBorder: enabledBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.72)),
      ),
    );
  }

  Widget _inviteDropdownField<T>({
    required BuildContext context,
    required T value,
    required String label,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 280,
      elevation: 14,
      dropdownColor: _inviteDropdownSurface(context),
      borderRadius: BorderRadius.circular(18),
      iconEnabledColor: cs.onSurfaceVariant,
      style: theme.textTheme.titleMedium?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      decoration: _inviteDropdownDecoration(context, label),
      items: items,
      onChanged: onChanged,
    );
  }

  Future<_RoomInviteDraft?> _showCreateInviteDialog({
    required bool roomApprovalRequired,
  }) {
    var expiryHours = 0;
    var maxUses = 0;
    var requiresApproval = false;
    var allowedRole = RoomMemberRole.member;
    return showDialog<_RoomInviteDraft>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(
                _roomText(context, ru: 'Новая ссылка', en: 'New invite link'),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _inviteDropdownField<int>(
                      context: context,
                      value: expiryHours,
                      label: _roomText(
                        context,
                        ru: 'Срок действия',
                        en: 'Expiry',
                      ),
                      items: <DropdownMenuItem<int>>[
                        DropdownMenuItem(
                          value: 0,
                          child: Text(
                            _roomText(
                              context,
                              ru: 'Без срока',
                              en: 'No expiry',
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text(
                            _roomText(context, ru: '1 час', en: '1 hour'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 24,
                          child: Text(
                            _roomText(context, ru: '24 часа', en: '24 hours'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 24 * 7,
                          child: Text(
                            _roomText(context, ru: '7 дней', en: '7 days'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 24 * 30,
                          child: Text(
                            _roomText(context, ru: '30 дней', en: '30 days'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setLocalState(() {
                          expiryHours = value ?? 0;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _inviteDropdownField<int>(
                      context: context,
                      value: maxUses,
                      label: _roomText(
                        context,
                        ru: 'Лимит вступлений',
                        en: 'Join limit',
                      ),
                      items: <DropdownMenuItem<int>>[
                        DropdownMenuItem(
                          value: 0,
                          child: Text(
                            _roomText(
                              context,
                              ru: 'Без лимита',
                              en: 'Unlimited',
                            ),
                          ),
                        ),
                        const DropdownMenuItem(value: 1, child: Text('1')),
                        const DropdownMenuItem(value: 5, child: Text('5')),
                        const DropdownMenuItem(value: 10, child: Text('10')),
                        const DropdownMenuItem(value: 25, child: Text('25')),
                      ],
                      onChanged: (value) {
                        setLocalState(() {
                          maxUses = value ?? 0;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _inviteDropdownField<RoomMemberRole>(
                      context: context,
                      value: allowedRole,
                      label: _roomText(
                        context,
                        ru: 'Роль при входе',
                        en: 'Join role',
                      ),
                      items: <DropdownMenuItem<RoomMemberRole>>[
                        DropdownMenuItem(
                          value: RoomMemberRole.member,
                          child: Text(
                            _roomRoleLabelForContext(
                              context,
                              RoomMemberRole.member,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: RoomMemberRole.restricted,
                          child: Text(
                            _roomRoleLabelForContext(
                              context,
                              RoomMemberRole.restricted,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: RoomMemberRole.guest,
                          child: Text(
                            _roomRoleLabelForContext(
                              context,
                              RoomMemberRole.guest,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() {
                          allowedRole = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (roomApprovalRequired)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _roomText(
                            context,
                            ru: 'В комнате уже включено обязательное одобрение новых участников. Эта ссылка всё равно будет входом по одобрению.',
                            en: 'Room-wide approval is already enabled for new members. This invite will still require approval.',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: requiresApproval,
                        title: Text(
                          _roomText(
                            context,
                            ru: 'Требовать одобрение по этой ссылке',
                            en: 'Require approval for this link',
                          ),
                        ),
                        onChanged: (value) {
                          setLocalState(() {
                            requiresApproval = value;
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(_roomText(context, ru: 'Отмена', en: 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final expiresAtMs = expiryHours <= 0
                        ? null
                        : DateTime.now()
                              .add(Duration(hours: expiryHours))
                              .millisecondsSinceEpoch;
                    Navigator.of(context).pop(
                      _RoomInviteDraft(
                        expiresAtMs: expiresAtMs,
                        maxUses: maxUses <= 0 ? null : maxUses,
                        requiresApproval: requiresApproval,
                        allowedRole: allowedRole,
                      ),
                    );
                  },
                  child: Text(_roomText(context, ru: 'Создать', en: 'Create')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInviteTile(
    RoomInviteLink link, {
    required String title,
    required int nowMs,
    required bool roomApprovalRequired,
  }) {
    final isActive =
        !link.revoked && !link.isExpiredAt(nowMs) && !link.isUsageLimitReached;
    return ListTile(
      onTap: isActive ? () => _openInviteLink(link) : null,
      leading: Icon(
        link.revoked
            ? Icons.link_off_rounded
            : (link.isExpiredAt(nowMs) || link.isUsageLimitReached)
            ? Icons.schedule_rounded
            : Icons.link_rounded,
      ),
      title: Text(title),
      subtitle: Text(
        <String>[
          link.shareUrl,
          _inviteStatusText(link, nowMs: nowMs),
          _invitePolicyText(link, roomApprovalRequired: roomApprovalRequired),
          _inviteUsageText(link),
          _inviteExpiryText(link),
          if (isActive)
            _roomText(
              context,
              ru: 'Нажмите, чтобы открыть приглашение.',
              en: 'Tap to open this invite.',
            ),
        ].join('\n'),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _handleInviteAction(link, value),
        itemBuilder: (context) => <PopupMenuEntry<String>>[
          PopupMenuItem(
            value: 'copy',
            child: Text(_roomText(context, ru: 'Скопировать', en: 'Copy')),
          ),
          PopupMenuItem(
            value: 'share',
            child: Text(_roomText(context, ru: 'Поделиться', en: 'Share')),
          ),
          if (!link.revoked)
            PopupMenuItem(
              value: 'revoke',
              child: Text(_roomText(context, ru: 'Отозвать', en: 'Revoke')),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: Text(
          _roomText(context, ru: 'Пригласительные ссылки', en: 'Invite links'),
        ),
      ),
      body: StreamBuilder<void>(
        stream: widget.controller.changed,
        builder: (context, _) {
          return FutureBuilder<_RoomInviteLinksVm>(
            future: _loadVm(),
            builder: (context, snapshot) {
              final vm =
                  snapshot.data ??
                  const _RoomInviteLinksVm(
                    links: <RoomInviteLink>[],
                    roomApprovalRequired: false,
                  );
              final links = vm.links;
              final nowMs = DateTime.now().millisecondsSinceEpoch;
              final active = links
                  .where(
                    (link) =>
                        !link.revoked &&
                        !link.isExpiredAt(nowMs) &&
                        !link.isUsageLimitReached,
                  )
                  .toList(growable: false);
              final inactive = links
                  .where(
                    (link) =>
                        link.revoked ||
                        link.isExpiredAt(nowMs) ||
                        link.isUsageLimitReached,
                  )
                  .toList(growable: false);
              return ListView(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      vm.roomApprovalRequired
                          ? _roomText(
                              context,
                              ru: 'В комнате уже включено одобрение новых участников. Ссылки ниже управляют сроком, лимитом и ролью при входе.',
                              en: 'Room-wide approval is already enabled. The links below only control expiry, join limit, and join role.',
                            )
                          : _roomText(
                              context,
                              ru: 'Каждая ссылка управляет только вступлением: сроком, лимитом и режимом входа. История сообщений для новых участников задается одной настройкой комнаты.',
                              en: 'Each invite link only controls access: expiry, join limit, and join mode. Message history for new members stays under one room setting.',
                            ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _SectionBlock(
                      children: [
                        if (active.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                            child: Text(
                              _roomText(
                                context,
                                ru: 'Сейчас нет активных приглашений. Создайте новую ссылку ниже.',
                                en: 'There is no active invite link right now. Create a new one below.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          )
                        else ...[
                          ListTile(
                            title: Text(
                              _roomText(
                                context,
                                ru: 'Активные приглашения',
                                en: 'Active invites',
                              ),
                            ),
                            subtitle: Text(
                              _roomText(
                                context,
                                ru: 'Любую активную ссылку можно сразу открыть, отправить или отозвать.',
                                en: 'Every active link can be opened, shared, or revoked immediately.',
                              ),
                            ),
                          ),
                          for (
                            var index = 0;
                            index < active.length;
                            index++
                          ) ...[
                            if (index > 0) const Divider(height: 1),
                            _buildInviteTile(
                              active[index],
                              title: _roomText(
                                context,
                                ru: 'Ссылка ${index + 1}',
                                en: 'Invite ${index + 1}',
                                uk: 'Посилання ${index + 1}',
                                es: 'Invitacion ${index + 1}',
                                pt: 'Convite ${index + 1}',
                                ptBr: 'Convite ${index + 1}',
                                fr: 'Invitation ${index + 1}',
                                de: 'Einladung ${index + 1}',
                              ),
                              nowMs: nowMs,
                              roomApprovalRequired: vm.roomApprovalRequired,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  if (inactive.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _SectionBlock(
                        children: [
                          ListTile(
                            title: Text(
                              _roomText(
                                context,
                                ru: 'Неактивные ссылки',
                                en: 'Inactive links',
                              ),
                            ),
                            subtitle: Text(
                              _roomText(
                                context,
                                ru: 'Здесь остаются истёкшие, исчерпанные и отозванные ссылки.',
                                en: 'Expired, exhausted, and revoked links remain here for auditability.',
                              ),
                            ),
                          ),
                          for (
                            var index = 0;
                            index < inactive.length;
                            index++
                          ) ...[
                            if (index > 0) const Divider(height: 1),
                            _buildInviteTile(
                              inactive[index],
                              title: _roomText(
                                context,
                                ru: 'Архивная ссылка ${index + 1}',
                                en: 'Archived link ${index + 1}',
                                uk: 'Архівне посилання ${index + 1}',
                                es: 'Enlace archivado ${index + 1}',
                                pt: 'Link arquivado ${index + 1}',
                                ptBr: 'Link arquivado ${index + 1}',
                                fr: 'Lien archive ${index + 1}',
                                de: 'Archivierter Link ${index + 1}',
                              ),
                              nowMs: nowMs,
                              roomApprovalRequired: vm.roomApprovalRequired,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final draft = await _showCreateInviteDialog(
                          roomApprovalRequired: vm.roomApprovalRequired,
                        );
                        if (draft == null) return;
                        try {
                          await widget.controller.createRoomInviteLink(
                            widget.groupId,
                            expiresAtMs: draft.expiresAtMs,
                            maxUses: draft.maxUses,
                            requiresApproval: draft.requiresApproval,
                            allowedRole: draft.allowedRole,
                          );
                        } catch (e) {
                          if (!mounted) return;
                          _showRoomActionError(this.context, e);
                          return;
                        }
                        if (!mounted) return;
                        setState(() {});
                      },
                      icon: const Icon(AppIcons.add),
                      label: Text(
                        _roomText(
                          context,
                          ru: 'Создать ссылку',
                          en: 'Create link',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _RoomInviteLinksVm {
  const _RoomInviteLinksVm({
    required this.links,
    required this.roomApprovalRequired,
  });

  final List<RoomInviteLink> links;
  final bool roomApprovalRequired;
}

class _RoomInviteDraft {
  const _RoomInviteDraft({
    required this.expiresAtMs,
    required this.maxUses,
    required this.requiresApproval,
    required this.allowedRole,
  });

  final int? expiresAtMs;
  final int? maxUses;
  final bool requiresApproval;
  final RoomMemberRole allowedRole;
}

class RoomPermissionsScreen extends StatefulWidget {
  const RoomPermissionsScreen({
    super.key,
    required this.controller,
    required this.groupId,
  });

  final AppController controller;
  final String groupId;

  @override
  State<RoomPermissionsScreen> createState() => _RoomPermissionsScreenState();
}

class _RoomPermissionsScreenState extends State<RoomPermissionsScreen> {
  RoomSettings? _settings;
  double _slowModeSliderValue = 0;
  bool _loading = true;
  bool _canManageSettings = false;

  static const List<int> _slowModeValues = [
    0,
    5,
    10,
    30,
    60,
    5 * 60,
    15 * 60,
    60 * 60,
  ];

  String _slowLabel(int seconds) {
    if (seconds == 0) return _roomText(context, ru: 'Нет', en: 'Off');
    if (seconds < 60) {
      final compactSeconds = _durationText(seconds, 's');
      return _roomText(
        context,
        ru: '$seconds сек',
        en: compactSeconds,
        uk: '$seconds с',
        es: compactSeconds,
        pt: compactSeconds,
        ptBr: compactSeconds,
        fr: compactSeconds,
        de: compactSeconds,
      );
    }
    if (seconds < 3600) {
      final mins = seconds ~/ 60;
      final compactMins = _durationText(mins, 'm');
      final spacedMins = _durationText(mins, ' min');
      final germanMins = _durationText(mins, ' Min.');
      return _roomText(
        context,
        ru: '$mins мин',
        en: compactMins,
        uk: '$mins хв',
        es: spacedMins,
        pt: spacedMins,
        ptBr: spacedMins,
        fr: spacedMins,
        de: germanMins,
      );
    }
    final hours = seconds ~/ 3600;
    final compactHours = _durationText(hours, 'h');
    final spacedHours = _durationText(hours, ' h');
    final germanHours = _durationText(hours, ' Std.');
    return _roomText(
      context,
      ru: '$hours ч',
      en: compactHours,
      uk: '$hours год',
      es: spacedHours,
      pt: spacedHours,
      ptBr: spacedHours,
      fr: spacedHours,
      de: germanHours,
    );
  }

  String _durationText(int value, String suffix) => '$value$suffix';

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  int _slowModeIndexFor(int seconds) {
    final index = _slowModeValues.indexOf(seconds);
    return index < 0 ? 0 : index;
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await widget.controller.getRoomSettings(widget.groupId);
      final policy = await widget.controller.getRoomPolicyState(widget.groupId);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _canManageSettings = policy.canManageSettings;
        _slowModeSliderValue = _slowModeIndexFor(
          settings.slowModeSeconds,
        ).toDouble();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      _showRoomActionError(context, error);
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _persistSettings(RoomSettings nextSettings) async {
    final previousSettings = _settings;
    final previousSliderValue = _slowModeSliderValue;
    setState(() {
      _settings = nextSettings;
      _slowModeSliderValue = _slowModeIndexFor(
        nextSettings.slowModeSeconds,
      ).toDouble();
    });
    try {
      await widget.controller.updateRoomSettings(
        groupId: widget.groupId,
        settings: nextSettings,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _settings = previousSettings;
        _slowModeSliderValue = previousSliderValue;
      });
      _showRoomActionError(context, error);
    }
  }

  Future<void> _selectSlowMode(int seconds) async {
    final settings = _settings;
    if (settings == null || settings.slowModeSeconds == seconds) {
      return;
    }
    await _persistSettings(settings.copyWith(slowModeSeconds: seconds));
  }

  Widget _buildSettingsSection({
    required String titleRu,
    required String titleEn,
    required String subtitleRu,
    required String subtitleEn,
    required List<Widget> children,
  }) {
    final items = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _roomText(context, ru: titleRu, en: titleEn),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          _roomText(context, ru: subtitleRu, en: subtitleEn),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ];
    for (var index = 0; index < children.length; index++) {
      if (index == 0) {
        items.add(const Divider(height: 1));
      }
      items.add(children[index]);
      if (index != children.length - 1) {
        items.add(const Divider(height: 1));
      }
    }
    return _SectionBlock(children: items);
  }

  Widget _buildSlowModeControls({
    required RoomSettings settings,
    required double maxSliderValue,
    required int previewSlowModeSeconds,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _roomText(context, ru: 'Медленный режим', en: 'Slow mode'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        SizedBox(
          height: 60,
          child: Slider(
            value: _slowModeSliderValue.clamp(0, maxSliderValue),
            min: 0,
            max: maxSliderValue,
            divisions: _slowModeValues.length - 1,
            label: _slowLabel(previewSlowModeSeconds),
            onChanged: _canManageSettings
                ? (raw) {
                    setState(() {
                      _slowModeSliderValue = raw.clamp(0, maxSliderValue);
                    });
                  }
                : null,
            onChangeEnd: _canManageSettings
                ? (raw) {
                    final nextIndex = raw.round().clamp(
                      0,
                      _slowModeValues.length - 1,
                    );
                    unawaited(_selectSlowMode(_slowModeValues[nextIndex]));
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final value in _slowModeValues)
                ChoiceChip(
                  label: Text(_slowLabel(value)),
                  selected: settings.slowModeSeconds == value,
                  onSelected: _canManageSettings
                      ? (_) => unawaited(_selectSlowMode(value))
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: Text(_roomText(context, ru: 'Разрешения', en: 'Permissions')),
      ),
      body: Builder(
        builder: (context) {
          if (_loading && settings == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (settings == null) {
            return Center(
              child: Text(
                _roomText(
                  context,
                  ru: 'Не удалось загрузить настройки комнаты.',
                  en: 'Could not load the room settings.',
                ),
              ),
            );
          }
          final maxSliderValue = (_slowModeValues.length - 1).toDouble();
          final roundedSliderIndex = _slowModeSliderValue.round().clamp(
            0,
            _slowModeValues.length - 1,
          );
          final previewSlowModeSeconds = _slowModeValues[roundedSliderIndex];

          return ListView(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
              bottom: MediaQuery.of(context).padding.bottom + 32,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _roomText(
                    context,
                    ru: 'Эти переключатели меняют правила для всей комнаты, а не только для вашего устройства.',
                    en: 'These switches change room-wide rules for everyone, not just for your device.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (!_canManageSettings) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _roomText(
                      context,
                      ru: 'Только владелец и админы комнаты могут менять эти настройки.',
                      en: 'Only the room owner and admins can change these settings.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildSettingsSection(
                  titleRu: 'Сообщения',
                  titleEn: 'Messages',
                  subtitleRu:
                      'Правила отправки, закрепления и частоты сообщений в комнате.',
                  subtitleEn:
                      'Rules for sending, pinning, and pacing messages in the room.',
                  children: [
                    _permissionSwitch(
                      titleRu: 'Отправка текстовых сообщений',
                      titleEn: 'Send text messages',
                      value: settings.allowTextMessages,
                      onChanged: (v) => settings.copyWith(allowTextMessages: v),
                    ),
                    _permissionSwitch(
                      titleRu: 'Отправка медиа',
                      titleEn: 'Send media',
                      value: settings.allowMedia,
                      onChanged: (v) => settings.copyWith(allowMedia: v),
                    ),
                    _permissionSwitch(
                      titleRu: 'Закреплять сообщения',
                      titleEn: 'Pin messages',
                      value: settings.allowPinMessages,
                      onChanged: (v) => settings.copyWith(allowPinMessages: v),
                    ),
                    _buildSlowModeControls(
                      settings: settings,
                      maxSliderValue: maxSliderValue,
                      previewSlowModeSeconds: previewSlowModeSeconds,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildSettingsSection(
                  titleRu: 'Вступление',
                  titleEn: 'Joining',
                  subtitleRu:
                      'Кто может приглашать и как новые участники попадают в комнату.',
                  subtitleEn:
                      'Who can invite and how new members enter the room.',
                  children: [
                    _permissionSwitch(
                      titleRu: 'Добавление участников',
                      titleEn: 'Add participants',
                      value: settings.allowAddMembers,
                      onChanged: (v) => settings.copyWith(allowAddMembers: v),
                    ),
                    _permissionSwitch(
                      titleRu: 'Вступление только после одобрения',
                      titleEn: 'Join only after approval',
                      value: settings.joinApprovalRequired,
                      onChanged: (v) =>
                          settings.copyWith(joinApprovalRequired: v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildSettingsSection(
                  titleRu: 'Приватность',
                  titleEn: 'Privacy',
                  subtitleRu:
                      'Что увидят новые участники после вступления в комнату.',
                  subtitleEn:
                      'What new members can see after joining the room.',
                  children: [
                    _permissionSwitch(
                      titleRu: 'Показывать историю новым участникам',
                      titleEn: 'Show history to new members',
                      value: settings.chatHistoryVisible,
                      onChanged: (v) =>
                          settings.copyWith(chatHistoryVisible: v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildSettingsSection(
                  titleRu: 'Профиль комнаты',
                  titleEn: 'Room profile',
                  subtitleRu:
                      'Кто может менять профиль комнаты и свой room tag.',
                  subtitleEn:
                      'Who can change the room profile and personal room tags.',
                  children: [
                    _permissionSwitch(
                      titleRu: 'Изменение профиля комнаты',
                      titleEn: 'Change room profile',
                      value: settings.allowChangeGroupInfo,
                      onChanged: (v) =>
                          settings.copyWith(allowChangeGroupInfo: v),
                    ),
                    _permissionSwitch(
                      titleRu: 'Изменение своего тега',
                      titleEn: 'Edit own room tag',
                      value: settings.allowChangeTag,
                      onChanged: (v) => settings.copyWith(allowChangeTag: v),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _permissionSwitch({
    required String titleRu,
    required String titleEn,
    required bool value,
    required RoomSettings Function(bool) onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      title: Text(_roomText(context, ru: titleRu, en: titleEn)),
      onChanged: _canManageSettings
          ? (next) {
              Haptics.tap();
              unawaited(_persistSettings(onChanged(next)));
            }
          // Отклика нет намеренно: у человека нет права менять настройку, и
          // отозваться на запрещённое нажатие значило бы подтвердить действие,
          // которого не будет.
          : null,
    );
  }
}

class _MemberSearchDelegate extends SearchDelegate<void> {
  _MemberSearchDelegate({required this.members});

  final List<RoomMember> members;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(onPressed: () => query = '', icon: const Icon(AppIcons.close)),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(AppIcons.arrowBack),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? members
        : members
              .where(
                (m) =>
                    m.displayName.toLowerCase().contains(q) ||
                    m.profileId.toLowerCase().contains(q) ||
                    (_roomMemberTag(m)?.toLowerCase().contains(q) ?? false),
              )
              .toList(growable: false);
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _roomText(context, ru: 'Ничего не найдено', en: 'No matches'),
        ),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final m = filtered[index];
        return ListTile(
          leading: _MiniAvatar(
            title: m.displayName,
            avatarPath: m.avatarPath,
            seed: m.profileId,
          ),
          title: Text(m.displayName),
          subtitle: Text(
            _roomMemberSubtitleForContext(context, m, includeProfileId: true),
          ),
        );
      },
    );
  }
}

class _RoomVm {
  const _RoomVm({
    required this.title,
    required this.muted,
    required this.autoDeleteSeconds,
    required this.settings,
    required this.members,
    this.pendingMembers = const <RoomMember>[],
    this.bannedMembers = const <RoomMember>[],
    required this.inviteLinks,
    required this.isAdmin,
    required this.policy,
    required this.myProfileId,
    required this.activeCall,
  });

  final String title;
  final bool muted;
  final int? autoDeleteSeconds;
  final RoomSettings settings;
  final List<RoomMember> members;
  final List<RoomMember> pendingMembers;
  final List<RoomMember> bannedMembers;
  final List<RoomInviteLink> inviteLinks;
  final bool isAdmin;
  final RoomPolicyState policy;
  final String myProfileId;
  final CachedRoomCall? activeCall;
}

class _RoomAdministrationVm {
  const _RoomAdministrationVm({
    required this.settings,
    required this.members,
    required this.pendingMembers,
    required this.bannedMembers,
    required this.inviteLinks,
    required this.policy,
    required this.myProfileId,
  });

  final RoomSettings settings;
  final List<RoomMember> members;
  final List<RoomMember> pendingMembers;
  final List<RoomMember> bannedMembers;
  final List<RoomInviteLink> inviteLinks;
  final RoomPolicyState policy;
  final String myProfileId;
}

class _RoomAvatar extends StatelessWidget {
  const _RoomAvatar({
    required this.title,
    required this.seed,
    required this.avatarPath,
    this.onEditTap,
    this.heroTag,
    this.width = 104,
    this.height = 104,
    this.borderRadius = 52,
  });

  final String title;

  /// Ключ цвета заглушки. Тот же, что в списке комнат (`convoId`), — иначе
  /// одна и та же комната красится на разных экранах по-разному.
  final String seed;

  final String? avatarPath;
  final VoidCallback? onEditTap;
  final String? heroTag;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final path = avatarPath;
    final has = path != null && path.isNotEmpty && File(path).existsSync();
    final visuals = Theme.of(context).extension<ChatVisualsThemeExtension>();
    final cs = Theme.of(context).colorScheme;
    final actionTop = visuals?.actionTop ?? cs.primary;
    final actionBottom = visuals?.actionBottom ?? cs.secondary;
    final smaller = width < height ? width : height;
    final fallbackFontSize = (smaller * 0.42).clamp(18.0, 96.0);
    // 🔴 ЗАГЛУШКА — ТА ЖЕ, ЧТО ВЕЗДЕ (15.09.2026, по жалобе владельца).
    //
    // Здесь стоял плоский `secondaryContainer` с тёмными буквами — то есть
    // серый кружок, — а в списке комнат и в шапке чата та же комната рисуется
    // цветным градиентом из общей палитры с белыми буквами. Одна комната
    // выглядела двумя разными на соседних экранах.
    //
    // Ключ цвета — `convoId`, ровно как в списке (`groups_screen.dart`), и
    // буквы берутся тем же `AvatarInitials.label`: две, а не одна. С 17.09
    // и сама заглушка общая с компьютером: приглушённая заливка оттенка и
    // цветные буквы вместо яркого градиента с белыми.
    final fallback = AvatarInitials.colors(
      context,
      seed: seed.isNotEmpty ? seed : title,
    );
    Widget avatar = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: has ? cs.surfaceContainerHighest : fallback.fill,
      ),
      clipBehavior: Clip.antiAlias,
      child: has
          ? Image.file(
              File(path),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  const BrokenMediaBox(iconSize: 28, rounded: true),
            )
          : Center(
              child: Text(
                AvatarInitials.label(displayName: title, fallbackId: seed),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: fallback.ink,
                  fontSize: fallbackFontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
    if (heroTag != null) {
      avatar = Hero(tag: heroTag!, child: avatar);
    }
    if (onEditTap == null) return avatar;
    return SizedBox(
      width: width + 12,
      height: height + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: Center(child: avatar)),
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onEditTap,
                child: Ink(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[actionTop, actionBottom],
                    ),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: actionBottom.withValues(alpha: 0.32),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, size: 20, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen room participant list, opened by tapping the "N participants"
/// label on the room page. Each row shows the member's photo, name, their
/// profile id (greyish, smaller) beneath it, and two trailing actions —
/// message (opens a 1:1) and call. Rows resolve identity from the room roster
/// (`listRoomMembersDetailed`, which carries profileId directly), so taps and
/// actions work even for members who never messaged you 1:1.
class RoomMembersScreen extends StatefulWidget {
  const RoomMembersScreen({
    super.key,
    required this.controller,
    required this.groupId,
  });

  final AppController controller;
  final String groupId;

  @override
  State<RoomMembersScreen> createState() => _RoomMembersScreenState();
}

class _RoomMembersScreenState extends State<RoomMembersScreen> {
  late Future<List<RoomMember>> _membersFuture;
  StreamSubscription<void>? _changedSub;
  Timer? _reloadDebounce;

  @override
  void initState() {
    super.initState();
    _membersFuture = widget.controller.listRoomMembersDetailed(widget.groupId);
    // Auto-refresh (debounced) so names/avatars that heal in the background —
    // e.g. an unknown member's published profile arriving — replace raw ids
    // without the user having to pull to refresh.
    _changedSub = widget.controller.changed.listen((_) {
      _reloadDebounce?.cancel();
      _reloadDebounce = Timer(const Duration(milliseconds: 800), () {
        if (mounted) _reload();
      });
    });
  }

  @override
  void dispose() {
    _changedSub?.cancel();
    _reloadDebounce?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final next = widget.controller.listRoomMembersDetailed(widget.groupId);
    setState(() => _membersFuture = next);
    await next;
  }

  bool _isSelf(RoomMember m) =>
      m.profileId.trim() == widget.controller.profileId;

  void _openProfile(RoomMember m) {
    final pid = m.profileId.trim();
    if (pid.isEmpty || _isSelf(m)) return;
    final label = m.displayName.trim();
    Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => ContactDetailsScreen(
          controller: widget.controller,
          peerProfileId: pid,
          convoId: pid,
          initialTitle: label.isEmpty ? null : label,
          initialAvatarPath: m.avatarPath,
          openChatByPush: true,
        ),
      ),
    );
  }

  void _message(RoomMember m) {
    final pid = m.profileId.trim();
    if (pid.isEmpty || _isSelf(m)) return;
    final label = m.displayName.trim();
    Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => ChatScreen(
          controller: widget.controller,
          convoId: pid,
          title: label.isEmpty ? pid : label,
          peerProfileIdForSend: pid,
        ),
      ),
    );
  }

  Future<void> _call(RoomMember m) async {
    final pid = m.profileId.trim();
    if (pid.isEmpty || _isSelf(m)) return;
    final messenger = ScaffoldMessenger.of(context);
    final cm = CallManager.instance;
    if (cm == null || cm.state.value.isActive) {
      messenger.showSnackBar(
        SecretlySnackBar(
          content: Text(
            _roomText(
              context,
              ru: 'Звонок сейчас недоступен',
              en: 'Call unavailable right now',
            ),
          ),
        ),
      );
      return;
    }
    final label = m.displayName.trim();
    try {
      await cm.startCall(
        peerProfileId: pid,
        peerName: label.isNotEmpty ? label : pid,
        peerAvatarPath: m.avatarPath,
        video: false,
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SecretlySnackBar(content: Text(callErrorText(context.l10n, e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: Text(_roomText(context, ru: 'Участники', en: 'Participants')),
      ),
      body: FutureBuilder<List<RoomMember>>(
        future: _membersFuture,
        builder: (context, snap) {
          final members = (snap.data ?? const <RoomMember>[])
              .where((m) => m.isActive)
              .toList(growable: false);
          if (snap.connectionState == ConnectionState.waiting &&
              members.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (members.isEmpty) {
            return Center(
              child: Text(
                _roomText(context, ru: 'Нет участников', en: 'No participants'),
                style: TextStyle(color: onSurfaceVariant),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: members.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = members[i];
                final self = _isSelf(m);
                return ListTile(
                  onTap: self ? null : () => _openProfile(m),
                  leading: _MiniAvatar(
                    title: m.displayName,
                    avatarPath: m.avatarPath,
                    seed: m.profileId,
                    online: m.isOnline,
                  ),
                  title: Text(
                    m.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    m.profileId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  trailing: self
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: _roomText(
                                context,
                                ru: 'Написать',
                                en: 'Message',
                              ),
                              icon: const Icon(AppIcons.chatBubbleSolid),
                              onPressed: () => _message(m),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: _roomText(
                                context,
                                ru: 'Позвонить',
                                en: 'Call',
                              ),
                              icon: const Icon(AppIcons.callSolid),
                              onPressed: () => _call(m),
                            ),
                          ],
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Портрет участника: фотография или цветная заглушка из ОБЩЕЙ палитры.
///
/// 🔴 ЗАГЛУШКА БЫЛА СЕРОЙ (15.09.2026, по жалобе владельца). Здесь стоял
/// плоский `secondaryContainer` с тёмной буквой, а в списках чатов и комнат
/// тот же человек рисуется цветным градиентом с белыми инициалами. Один и тот
/// же собеседник выглядел двумя разными людьми на соседних экранах.
///
/// ◆ Точка присутствия — здесь же: список участников без неё отвечает «кто
/// состоит», а спрашивают у него «с кем можно поговорить прямо сейчас».
class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({
    required this.title,
    required this.avatarPath,
    this.seed,
    this.radius = 16,
    this.online = false,
  });

  final String title;
  final String? avatarPath;

  /// Ключ цвета заглушки — обычно `profileId`. Пусто — по имени.
  final String? seed;

  final double radius;

  /// Показывать ли зелёную точку присутствия.
  final bool online;

  @override
  Widget build(BuildContext context) {
    final path = avatarPath;
    final has = path != null && path.isNotEmpty && File(path).existsSync();
    final key = (seed ?? '').trim().isNotEmpty ? seed!.trim() : title;
    final size = radius * 2;
    final Widget face = has
        ? ClipOval(
            child: Image.file(
              File(path),
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  const BrokenMediaBox(iconSize: 14, rounded: true),
            ),
          )
        : AvatarInitials.fallbackBubble(
            context: context,
            radius: radius,
            seed: key,
            displayName: title,
            fallbackId: seed,
          );
    if (!online) return face;
    final dot = (size * 0.30).clamp(9.0, 14.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: face),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                // Вырез цвета подложки: без него точка сливается с портретом.
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? cs.onSurface;
    final effectiveLabelColor = labelColor ?? iconColor ?? cs.onSurface;
    // Matches contact_details' _ActionChip: frosted glass island, icon + label
    // tinted with colorScheme.onSurface (theme-aware, not hard white).
    // Horizontal padding kept at 8 so four chips fit a row without overflow;
    // other metrics (radius 18, icon 22, w600) match contacts. iconColor /
    // labelColor stay overridable so the Leave chip keeps its error tint.
    return FrostedHeaderIsland(
      radius: 18,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: effectiveIconColor),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: effectiveLabelColor,
                    fontWeight: FontWeight.w600,
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

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(children: children),
    );
  }
}

/// A single choice in the room-cosmetic picker (frame or cover): a stable catalog
/// [id], its localized [label], and a small live [preview] widget built from the
/// shared cosmetic catalog.
class _RoomCosmeticChoice {
  const _RoomCosmeticChoice({
    required this.id,
    required this.label,
    required this.preview,
  });

  final String id;
  final String label;
  final Widget preview;
}

/// A selectable tile in the room-cosmetic picker grid (preview + label, with a
/// highlighted border + check when [selected]).
class _RoomCosmeticTile extends StatelessWidget {
  const _RoomCosmeticTile({
    required this.label,
    required this.preview,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Widget preview;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF22242E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? accent : Colors.white12,
                width: selected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: preview,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: selected ? accent : Colors.white70,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// ◆ Три вкладки страницы комнаты: сведения, участники, медиа.
///
/// Форма — та же, что у сегментов в окне на компьютере: одна дорожка, внутри
/// подсвечивается выбранный. Счётчик у «Участников» стоит прямо в подписи:
/// сколько людей в комнате — первое, что о ней спрашивают.
class _RoomTabs extends StatelessWidget {
  const _RoomTabs({
    required this.index,
    required this.membersCount,
    required this.onChanged,
  });

  final int index;
  final int membersCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labels = <String>[
      _roomText(context, ru: 'Инфо', en: 'Info'),
      membersCount > 0
          ? '${_roomText(context, ru: 'Участники', en: 'Members')} · $membersCount'
          : _roomText(context, ru: 'Участники', en: 'Members'),
      _roomText(context, ru: 'Медиа', en: 'Media'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 2),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == index
                          ? cs.surface.withValues(alpha: 0.95)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: i == index
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: i == index ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ◆ Вкладка «Участники»: люди комнаты прямо на странице.
///
/// 🔴 ЭТОГО НЕ БЫЛО ВОВСЕ. Список людей прятался за нажатием по счётчику в
/// шапке — то есть за жестом, о котором нельзя догадаться, — а на самой
/// странице лежали десятки настроек. Самое нужное оказалось самым
/// недоступным.
///
/// Здесь у каждого: портрет с точкой присутствия, имя, Secretly ID и роль.
/// Сверху — действие по правам: «Добавить» тому, кому комната это разрешает,
/// «Пригласить» — остальным участникам (ссылка, а не прямое добавление).
class _RoomMembersPanel extends StatelessWidget {
  const _RoomMembersPanel({
    required this.controller,
    required this.members,
    required this.myProfileId,
    required this.ownerProfileId,
    required this.canAdd,
    required this.canInvite,
    required this.onAdd,
    required this.onInvite,
    required this.onOpenAll,
    required this.onOpenMember,
    required this.onMessageMember,
  });

  final AppController controller;
  final List<RoomMember> members;
  final String? myProfileId;
  final String? ownerProfileId;

  /// Право добавлять людей напрямую — по роли в комнате.
  final bool canAdd;

  /// Право позвать ссылкой. Есть у любого участника, если комната не закрыта.
  final bool canInvite;

  final VoidCallback onAdd;
  final VoidCallback onInvite;
  final VoidCallback onOpenAll;

  /// Нажатие по строке — профиль участника.
  final ValueChanged<RoomMember> onOpenMember;

  /// Значок справа — личная переписка.
  final ValueChanged<RoomMember> onMessageMember;

  /// Сколько строк показываем на странице. Остальные — за «Показать всех»:
  /// комната на полсотни человек иначе превращает страницу в ленту имён.
  static const int _kInlineLimit = 12;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Сначала те, кто в сети: список участников отвечает на вопрос «с кем
    // можно поговорить прямо сейчас», а не «кто когда-то вступил».
    final sorted = List<RoomMember>.from(members.where((m) => m.isActive))
      ..sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });
    final shown = sorted.take(_kInlineLimit).toList(growable: false);
    final hidden = sorted.length - shown.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (canAdd)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(AppIcons.personAdd, size: 20),
                    label: Text(
                      _roomText(context, ru: 'Добавить', en: 'Add'),
                    ),
                  ),
                ),
              if (canAdd && canInvite) const SizedBox(width: 8),
              if (canInvite)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onInvite,
                    icon: const Icon(Icons.link_rounded, size: 20),
                    label: Text(
                      _roomText(context, ru: 'Пригласить', en: 'Invite'),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionBlock(
            children: [
              for (final m in shown)
                _RoomMemberTile(
                  member: m,
                  isSelf: m.profileId == myProfileId,
                  isOwner: m.profileId == ownerProfileId,
                  onTap: m.profileId == myProfileId
                      ? null
                      : () => onOpenMember(m),
                  onMessage: m.profileId == myProfileId
                      ? null
                      : () => onMessageMember(m),
                ),
              if (hidden > 0)
                ListTile(
                  leading: Icon(Icons.expand_more_rounded, color: cs.primary),
                  title: Text(
                    _roomText(
                      context,
                      ru: 'Показать всех · ещё $hidden',
                      en: 'Show all · $hidden more',
                    ),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: onOpenAll,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Строка участника: портрет с точкой присутствия, имя, Secretly ID и роль.
class _RoomMemberTile extends StatelessWidget {
  const _RoomMemberTile({
    required this.member,
    required this.isSelf,
    required this.isOwner,
    this.onTap,
    this.onMessage,
  });

  final RoomMember member;
  final bool isSelf;
  final bool isOwner;

  /// Нажатие по строке — профиль. `null` у себя: свой профиль открывают из
  /// другого места, и строка «вы» не должна вести в никуда.
  final VoidCallback? onTap;

  /// Личная переписка. `null` у себя.
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = member.displayName.trim().isEmpty
        ? member.profileId
        : member.displayName.trim();
    final tag = (member.tag ?? '').trim();
    final role = isOwner
        ? _roomText(context, ru: 'Владелец', en: 'Owner')
        : (member.role == RoomMemberRole.admin
              ? _roomText(context, ru: 'Админ', en: 'Admin')
              : '');
    return ListTile(
      leading: _MiniAvatar(
        title: name,
        avatarPath: member.avatarPath,
        seed: member.profileId,
        radius: 21,
        online: member.isOnline,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (isSelf) ...[
            const SizedBox(width: 6),
            Text(
              _roomText(context, ru: '· вы', en: '· you'),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
          if (role.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                role,
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      // Идентификатор — то, чем человек делится, чтобы с ним связались, и
      // единственное, что отличает двух тёзок в комнате.
      subtitle: Text(
        tag.isEmpty ? member.profileId : '$tag · ${member.profileId}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      onTap: onTap,
      trailing: onMessage == null
          ? null
          : IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: _roomText(context, ru: 'Написать', en: 'Message'),
              icon: const Icon(AppIcons.chatBubbleSolid, size: 20),
              onPressed: onMessage,
            ),
    );
  }
}
