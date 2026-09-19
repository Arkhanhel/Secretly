// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../../app/app_controller.dart';
import '../../../../rooms/room_call_state.dart'
    show CachedRoomCall, CachedRoomCallParticipant;
import '../../../report_abuse_sheet.dart';
import '../../../room_policy_error_text.dart' show tryRoomPolicyErrorText;
import '../../../room_membership_error_text.dart'
    show tryRoomMembershipErrorText;
import '../../../../l10n/app_localizations.dart';
import '../../app/desktop_app_view_model.dart';
import '../../app/desktop_selector.dart';
import '../../../room_topic_marks.dart';
import '../../design/tokens.dart';
import '../chat_time_label.dart';
import '../../services/demo_rooms.dart';
import '../../primitives/avatar.dart';
import '../../primitives/context_menu.dart';
import '../../primitives/desktop_button.dart';
import '../../primitives/desktop_dialog.dart';
import '../../primitives/desktop_popover.dart';
import '../../primitives/hover_listener.dart';
import 'avatar_preview_dialog.dart';
import 'desktop_media_gallery.dart';
import 'details_action_row.dart';
import 'details_headline.dart';
import 'details_info_section.dart';
import 'room_notes_pane.dart';
import 'details_tabs.dart';
import 'member_profile_card.dart';
import 'room_invite_share.dart';
import '../../../../app/message_command_utils.dart' show RoomTopicRef;
import '../../../premium/cosmetics_catalog.dart' show coverWidgetFor;

/// Панель подробностей комнаты.
///
/// Мета, список участников с поиском, галерея, темы, безопасные действия
/// (звук, закрепить, архив, очистить, выйти) — и, с 13.09.2026, УПРАВЛЕНИЕ
/// УЧАСТНИКАМИ.
///
/// 🔴 Раньше здесь стояло «member management is mobile-only by design», и это
/// было не решением, а долгом: человек, у которого стучатся в комнату, не
/// узнавал об этом за компьютером вовсе — заявку можно было увидеть и принять
/// только с телефона. Владелец это отменил прямо.
///
/// Что делается отсюда: роль участника, исключение, блокировка и её снятие,
/// передача владения, заявки на вступление, ссылка-приглашение (включая
/// создание). Каждое действие показывается только тому, кому комната его
/// разрешает (`RoomPolicyState`), а отказ говорится словами — теми же, что на
/// телефоне (`tryRoomPolicyErrorText`, `tryRoomMembershipErrorText`).
///
/// Чего здесь по-прежнему нет: правка прав комнаты целиком (кто может писать,
/// медленный режим) и отзыв ссылок — это отдельные экраны телефона.
/// Всё, что панель читает о комнате одним запросом.
///
/// Одной записью, а не пятью полями состояния: шов `DesktopSelector` сравнивает
/// подпись целиком, и разъехавшиеся между собой куски (список участников новый,
/// права старые) дали бы набор действий, которого у человека уже нет.
typedef _RoomPane = ({
  RoomSettings? settings,
  List<RoomMember> members,
  List<RoomMember> pending,
  List<RoomMember> banned,
  RoomPolicyState? policy,
});

class RoomDetailsView extends StatefulWidget {
  const RoomDetailsView({
    super.key,
    required this.vm,
    required this.conversation,
    required this.onClose,
    this.topics = const <RoomTopicRef>[],
    this.currentTopicId,
    this.baseTopicMark = '',
    this.topicUnread = const <String, int>{},
    this.topicLastActivityMs = const <String, int>{},
    this.onSelectTopic,
    this.onCreateTopic,
    this.onOpenProfileChat,
  });

  /// Открыть личную переписку с участником (заведя её при необходимости).
  /// `null` — кнопка «Написать» в карточке участника не показывается.
  final ValueChanged<String>? onOpenProfileChat;

  /// The controller seam. [controller] is derived from it, so every
  /// `widget.controller` use site below keeps working unchanged.
  final DesktopAppViewModel vm;
  AppController get controller => vm.controller;
  final Conversation conversation;
  final VoidCallback onClose;

  /// Темы комнаты — ВТОРОЙ вход к ним, рядом с полосой под шапкой чата.
  ///
  /// Полоса отвечает на вопрос «куда я пишу», а этот список — на «что вообще
  /// происходит в комнате»: здесь видно все темы сразу, со счётчиком
  /// непрочитанного у каждой. Данные те же самые, из общего склада; второго
  /// разбора управляющих сообщений нет.
  final List<RoomTopicRef> topics;
  final String? currentTopicId;

  /// Знак «Основы» — общего потока комнаты. Пусто — решётка.
  final String baseTopicMark;
  final Map<String, int> topicUnread;

  /// Время последнего сообщения по теме; пустая строка ключа — «Общий».
  ///
  /// Считается по ЗАГРУЖЕННОЙ ленте: ключа может не быть вовсе, и тогда время
  /// не рисуется. Отсутствие — «не знаем», а не «давно».
  final Map<String, int> topicLastActivityMs;
  final void Function(String? topicId)? onSelectTopic;

  /// Завести тему. `null` — у этого человека нет такого права, и раздел тем
  /// у комнаты без тем не показывается вовсе.
  final VoidCallback? onCreateTopic;

  @override
  State<RoomDetailsView> createState() => _RoomDetailsViewState();
}

class _RoomDetailsViewState extends State<RoomDetailsView> {
  /// Подписи экрана комнаты.
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool _muted = false;
  bool _pinned = false;
  bool _archived = false;
  RoomSettings? _settings;
  List<RoomMember> _members = const [];

  /// Выбранная вкладка панели: 0 — «Инфо», 1 — «Участники», 2 — «Медиа».
  int _tab = 0;

  /// Заявки на вступление и заблокированные — те же участники, другой статус.
  List<RoomMember> _pending = const [];
  List<RoomMember> _banned = const [];

  /// Что мне здесь позволено. Пункты действий рисуются только по нему: меню,
  /// которое всегда отвечает отказом, — не меню.
  RoomPolicyState? _policy;

  /// Room settings + member list, loaded once per settled burst of controller
  /// ticks and republished only when either actually differs.
  ///
  /// This used to run `getRoomSettings` AND `listRoomMembersDetailed` on every
  /// `changed` tick — for a large room, the whole member list re-read on every
  /// presence heartbeat.
  late final DesktopSelector<_RoomPane> _room;

  // Search over members.
  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';

  // Invite links (lazily loaded once).
  List<RoomInviteLink> _inviteLinks = const [];
  bool _inviteLoading = false;

  /// Вправе ли я заводить ссылки-приглашения. Пункт «Пригласить» появляется
  /// только тогда: кнопка, которая всегда отвечает отказом, — не кнопка.
  bool _canManageInvites = false;

  String get _groupId => widget.conversation.convoId;

  @override
  void initState() {
    super.initState();
    _muted = widget.conversation.muted;
    _pinned = widget.conversation.pinnedAtMs != null;
    _archived = widget.conversation.archivedAtMs != null;
    _searchCtl.addListener(_onSearchChanged);
    _room = widget.vm.select<_RoomPane>(
      debugName: 'roomDetails',
      initial: (
        settings: null,
        members: const <RoomMember>[],
        pending: const <RoomMember>[],
        banned: const <RoomMember>[],
        policy: null,
      ),
      load: _loadRoom,
      signature: _roomSignature,
    )..addListener(_onRoom);
    // 🔴 СНИМОК СОЗВОНА — ТОТ ЖЕ, ЧТО У ПЛАШКИ И У ОКНА СОЗВОНА.
    //
    // Раньше группы «В СОЗВОНЕ» здесь не было с объяснением «признаки живут в
    // состоянии LiveKit и существуют только внутри идущего созвона». Это
    // оказалось неправдой: `muted`, `screenShareEnabled` и `joinState` лежат в
    // `CachedRoomCall` — снимке, который видит ВСЯ комната, а не только
    // подключившиеся. Из LiveKit приходит только «говорит», и его здесь
    // по-прежнему нет.
    _callSel = widget.vm.select<CachedRoomCall?>(
      debugName: 'roomDetailsCall',
      initial: null,
      load: () async {
        final gid = _groupId;
        if (gid.isEmpty) return null;
        final call = await widget.controller.getCachedRoomCall(gid);
        return (call != null && call.isActive) ? call : null;
      },
      // Перерисовываем на смене созвона или его версии: снимок обновляется
      // чаще, чем меняется то, что видно в списке.
      signature: (call) =>
          call == null ? '' : '${call.callId}/${call.stateVersion}',
    )..addListener(_onRoom);
    _loadInviteLinks();
  }

  late final DesktopSelector<CachedRoomCall?> _callSel;

  /// Кто сейчас В СОЗВОНЕ, по профилю. Пусто — созвона нет.
  ///
  /// Один профиль может сидеть с двух устройств; берём первое вошедшее —
  /// признаки микрофона и показа у них общие по смыслу, а рисуем мы один
  /// значок на человека.
  Map<String, CachedRoomCallParticipant> get _inCall {
    final call = _callSel.value;
    if (call == null) return const <String, CachedRoomCallParticipant>{};
    final out = <String, CachedRoomCallParticipant>{};
    for (final p in call.participants) {
      if (!p.isJoined) continue;
      out.putIfAbsent(p.profileId, () => p);
    }
    return out;
  }

  @override
  void didUpdateWidget(covariant RoomDetailsView old) {
    super.didUpdateWidget(old);
    if (old.conversation.convoId != widget.conversation.convoId) {
      _muted = widget.conversation.muted;
      _pinned = widget.conversation.pinnedAtMs != null;
      _archived = widget.conversation.archivedAtMs != null;
      _searchCtl.clear();
      _query = '';
      _inviteLinks = const [];
      _refresh();
      _loadInviteLinks();
    } else if (old.conversation.pinnedAtMs != widget.conversation.pinnedAtMs ||
        old.conversation.archivedAtMs != widget.conversation.archivedAtMs) {
      _pinned = widget.conversation.pinnedAtMs != null;
      _archived = widget.conversation.archivedAtMs != null;
    }
  }

  @override
  void dispose() {
    _searchCtl.removeListener(_onSearchChanged);
    _searchCtl.dispose();
    _room.removeListener(_onRoom);
    _room.dispose();
    _callSel.removeListener(_onRoom);
    _callSel.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchCtl.text.trim();
    if (next == _query) return;
    setState(() => _query = next);
  }

  Future<_RoomPane> _loadRoom() async {
    final settings = await widget.controller.getRoomSettings(_groupId);
    final members = await widget.controller.listRoomMembersDetailed(_groupId);
    // Заявки и заблокированные — отдельные срезы того же списка. Управление
    // ими на десктопе не существовало вовсе: человек видел, что «кто-то
    // стучится», только с телефона.
    final pending = await widget.controller.listRoomJoinRequestsDetailed(
      _groupId,
    );
    final banned = await widget.controller.listRoomBannedMembersDetailed(
      _groupId,
    );
    final policy = await widget.controller.getRoomPolicyState(_groupId);
    return (
      settings: settings,
      members: members,
      pending: pending,
      banned: banned,
      policy: policy,
    );
  }

  /// `RoomSettings` and `RoomMember` are plain classes with no `==`, so a
  /// record's structural equality would still compare them by identity and
  /// report a change on every reload.
  ///
  /// Every field of both is written out. Not a curated subset: the pane
  /// renders the permission flags, the slow-mode delay, the member roles and
  /// the online dots, and a field left out here is a control that silently
  /// stops reflecting reality. Both classes are small enough that "all of
  /// them" is verifiable by eye against the model.
  String _roomSignature(_RoomPane value) {
    final buffer = StringBuffer();
    final s = value.settings;
    if (s == null) {
      buffer.write('-');
    } else {
      buffer
        ..write(s.ownerProfileId)
        ..write(':')
        ..write(s.avatarPath ?? '')
        ..write(':')
        ..write(s.avatarHash ?? '')
        ..write(':')
        ..write(s.pinnedMessageEventId ?? '')
        ..write(':')
        ..write(s.coverId ?? '')
        ..write(':')
        ..write(s.frameId ?? '')
        ..write(':')
        ..write(s.nameEmoji ?? '')
        ..write(':')
        ..write(s.description)
        ..write(':')
        ..write(s.reactionsMode)
        ..write(':')
        ..write(s.allowTextMessages)
        ..write(s.allowMedia)
        ..write(s.allowAddMembers)
        ..write(s.allowPinMessages)
        ..write(s.allowChangeGroupInfo)
        ..write(s.allowChangeTag)
        ..write(s.joinApprovalRequired)
        ..write(':')
        ..write(s.slowModeSeconds)
        ..write(':')
        ..write(s.chatHistoryVisible)
        ..write(':')
        ..write(s.membershipVersion)
        ..write(':')
        ..write(s.stateVersion);
    }
    // Права меняются вне списка (сняли админа, комната сменила настройки) —
    // без них панель показывала бы вчерашний набор действий.
    final policy = value.policy;
    buffer
      ..write('\u001e')
      ..write(policy == null ? '-' : policy.role.value)
      ..write(policy?.canRemoveMembers ?? false)
      ..write(policy?.canBanMembers ?? false)
      ..write(policy?.canManageMemberRoles ?? false)
      ..write(policy?.canApproveJoinRequests ?? false)
      ..write(policy?.canManageInviteLinks ?? false);
    buffer
      // Record separator between the settings and the roster.
      ..write('\u001e')
      ..write(value.members.length)
      ..write(':')
      ..write(value.pending.length)
      ..write(':')
      ..write(value.banned.length);
    for (final m in <RoomMember>[
      ...value.members,
      ...value.pending,
      ...value.banned,
    ]) {
      buffer
        // Unit separator: cannot occur inside an id or a name.
        ..write('\u001f')
        ..write(m.profileId)
        ..write(':')
        ..write(m.displayName)
        ..write(':')
        ..write(m.avatarPath ?? '')
        ..write(':')
        ..write(m.tag ?? '')
        ..write(':')
        ..write(m.role)
        ..write(':')
        ..write(m.isOnline)
        ..write(':')
        ..write(m.membershipStatus)
        ..write(':')
        ..write(m.membershipCreatedAtMs)
        ..write(':')
        ..write(m.membershipUpdatedAtMs);
    }
    return buffer.toString();
  }

  void _onRoom() {
    if (!mounted) return;
    setState(() {
      _settings = _room.value.settings;
      _members = _room.value.members;
      _pending = _room.value.pending;
      _banned = _room.value.banned;
      _policy = _room.value.policy;
    });
  }

  /// Reloads now, for a change this pane just caused.
  Future<void> _refresh() => _room.refresh();

  Future<void> _loadInviteLinks() async {
    if (_inviteLoading) return;
    setState(() => _inviteLoading = true);
    try {
      final links = await widget.controller.listRoomInviteLinks(_groupId);
      final policy = await widget.controller.getRoomPolicyState(_groupId);
      if (!mounted) return;
      setState(() {
        _inviteLinks = links;
        _canManageInvites = policy.canManageInviteLinks;
        _inviteLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _inviteLoading = false);
    }
  }

  /// Пригласить в комнату.
  ///
  /// 🔴 ЧЕГО НЕ ХВАТАЛО (13.09.2026). Ссылку-приглашение десктоп показывал —
  /// но только ГОТОВУЮ. У комнаты, где её ещё не заводили, строки не было
  /// вовсе, и позвать человека с компьютера было нельзя ничем: ни ссылки, ни
  /// кнопки, ни подсказки, что это делается с телефона.
  ///
  /// Порядок тот же, что на телефоне: берём годную ссылку, а если её нет —
  /// заводим (с тем же «нужно ли одобрение», что стоит у комнаты). Отказ
  /// комнаты придёт `RoomPolicyFailure` и будет сказан словами.
  /// Карточка участника — по левому щелчку в списке.
  ///
  /// 🔴 Раньше левый щелчок не делал НИЧЕГО: строка ловила только правый, а
  /// курсор над ней был принудительно обычной стрелкой. Узнать, кто этот
  /// человек, и написать ему из комнаты было нечем: приходилось искать его
  /// имя в общем списке чатов, а если переписки ещё нет — там его и не было.
  ///
  /// Карточка всплывает СЛЕВА от панели, как в макете; если слева не
  /// помещается, [DesktopPopover] сам перекладывает её на другую сторону.
  Future<void> _openMemberCard(BuildContext rowContext, RoomMember m) async {
    final name = m.displayName.trim().isEmpty
        ? m.profileId
        : m.displayName.trim();
    await DesktopPopover.showFrom<void>(
      rowContext,
      anchorContext: rowContext,
      side: PopoverSide.left,
      width: MemberProfileCard.width,
      maxHeight: 330,
      child: MemberProfileCard(
        name: name,
        profileId: m.profileId,
        avatarPath: m.avatarPath,
        isOnline: m.isOnline,
        roleLabel: roomMemberRoleSubtitle(m.role, l10n),
        statusNote: _membershipNote(m),
        onWrite: () {
          Navigator.of(rowContext).maybePop();
          final open = widget.onOpenProfileChat;
          if (open == null) {
            _toast(l10n.desktopRoomNoOpenHere, danger: true);
            return;
          }
          open(m.profileId);
        },
        onCopyId: () {
          Clipboard.setData(ClipboardData(text: m.profileId));
          _toast(l10n.desktopRoomIdCopied);
        },
      ),
    );
  }

  /// Состояние членства словами — но только когда оно НЕ обычное.
  ///
  /// Карточка предлагает написать человеку; если он ещё ждёт одобрения или
  /// уже заблокирован, молчать об этом нельзя.
  String? _membershipNote(RoomMember m) {
    if (m.isPending) return l10n.desktopRoomAwaiting;
    if (m.isBanned) return l10n.desktopRoomBlocked;
    return null;
  }

  Future<void> _invite() async {
    // Порядок действий — в общей [copyRoomInviteLink]: ту же
    // последовательность повторяет кнопка «Пригласить» в окне созвона, и
    // разъехаться им нельзя. Особенно в двух местах: сперва ищем УЖЕ годную
    // ссылку (иначе каждое нажатие плодит новую), и новая наследует
    // «вступление по подтверждению» комнаты.
    final hadLink = bestRoomInviteLink(_inviteLinks) != null;
    final result = await copyRoomInviteLink(
      controller: widget.controller,
      groupId: _groupId,
      requiresApproval: _settings?.joinApprovalRequired ?? false,
      known: _inviteLinks,
      describeError: _roomActionErrorText,
    );
    if (!hadLink && result.ok) unawaited(_loadInviteLinks());
    if (!mounted) return;
    if (!result.ok) {
      _toast(result.error ?? l10n.desktopCallFailed, danger: true);
      return;
    }
    // Та же подпись, что у копирования любой строки в этой панели.
    _toast(l10n.desktopRoomCopied);
  }

  /// Человеческий текст отказа — тем же разбором, что и на телефоне.
  ///
  /// Два разборщика, и порядок важен: правила комнаты («писать могут только
  /// админы») и действия с участниками («владельца нельзя удалить») — разные
  /// наборы кодов, и ни один не покрывает другой.
  String _roomActionErrorText(Object error) {
    final l10n = AppLocalizations.of(context);
    final policy = l10n == null ? null : tryRoomPolicyErrorText(l10n, error);
    return policy ??
        tryRoomMembershipErrorText(context, error) ??
        error.toString();
  }

  /// Общая обёртка для действий с участником.
  ///
  /// Успех — перечитать комнату (роль, состав и заявки меняются разом);
  /// отказ — сказать словами. Без этого отказ приходил бы текстом исключения,
  /// а список оставался бы вчерашним.
  Future<void> _runMemberAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      _toast(_roomActionErrorText(error), danger: true);
      return;
    }
    if (!mounted) return;
    unawaited(_refresh());
  }

  /// Какие роли я вправе выдать ЭТОМУ участнику.
  ///
  /// Правило то же, что на телефоне: владелец раздаёт любую, администратор —
  /// всё кроме администраторской и не трогает других администраторов, себя и
  /// владельца не трогает никто.
  List<RoomMemberRole> _assignableRoles(RoomMember member) {
    final policy = _policy;
    if (policy == null) return const <RoomMemberRole>[];
    if (!member.isActive ||
        member.isOwner ||
        member.profileId == widget.controller.profileId.trim()) {
      return const <RoomMemberRole>[];
    }
    if (!policy.canManageMemberRoles) return const <RoomMemberRole>[];
    if (policy.isOwner) {
      return const <RoomMemberRole>[
        RoomMemberRole.admin,
        RoomMemberRole.moderator,
        RoomMemberRole.member,
        RoomMemberRole.restricted,
        RoomMemberRole.guest,
      ];
    }
    if (policy.isAdmin && !member.isAdmin) {
      return const <RoomMemberRole>[
        RoomMemberRole.moderator,
        RoomMemberRole.member,
        RoomMemberRole.restricted,
        RoomMemberRole.guest,
      ];
    }
    return const <RoomMemberRole>[];
  }

  /// Меню действий с участником. Пустое — значит рисовать кнопку незачем.
  List<List<CtxMenuItem>> _memberMenuSections(RoomMember member) {
    final policy = _policy;
    if (policy == null) return const <List<CtxMenuItem>>[];
    final isSelf = member.profileId == widget.controller.profileId.trim();
    final roles = _assignableRoles(member);
    final canRemove = policy.canRemoveMembers && !isSelf && !member.isOwner;
    final canBan = policy.canBanMembers && !isSelf && !member.isOwner;
    final canTransfer = policy.isOwner && !isSelf && member.isActive;

    final sections = <List<CtxMenuItem>>[];
    if (roles.isNotEmpty) {
      sections.add(<CtxMenuItem>[
        CtxMenuItem(
          label: l10n.desktopRoomChangeRole,
          icon: FluentIcons.shield_24_regular,
          onTap: () => unawaited(_pickRole(member, roles)),
        ),
      ]);
    }
    final danger = <CtxMenuItem>[
      if (canTransfer)
        CtxMenuItem(
          label: l10n.desktopRoomTransfer,
          icon: FluentIcons.key_24_regular,
          onTap: () => unawaited(_transferOwnership(member)),
        ),
      if (canBan)
        CtxMenuItem(
          label: l10n.desktopRoomBlockMember,
          icon: FluentIcons.shield_dismiss_24_regular,
          onTap: () => unawaited(_banMember(member)),
          isDanger: true,
        ),
      if (canRemove)
        CtxMenuItem(
          label: l10n.desktopRoomKick,
          icon: FluentIcons.person_delete_24_regular,
          onTap: () => unawaited(_removeMember(member)),
          isDanger: true,
        ),
    ];
    if (danger.isNotEmpty) sections.add(danger);
    return sections;
  }

  Future<void> _pickRole(RoomMember member, List<RoomMemberRole> roles) async {
    final picked = await DesktopDialog.show<RoomMemberRole>(
      context,
      title: l10n.desktopRoomChangeRole,
      size: DDialogSize.small,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final role in roles) ...[
            DesktopButton(
              label: roomMemberRoleLabelRu(role, l10n),
              // Текущая роль выделена: человек должен видеть, где он стоит,
              // до того как нажмёт.
              kind: role == member.role
                  ? DButtonKind.filled
                  : DButtonKind.tonal,
              expand: true,
              onPressed: () => Navigator.of(context).maybePop(role),
            ),
            const SizedBox(height: DSpace.s),
          ],
        ],
      ),
      secondary: DDialogAction(
        label: l10n.cancel,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
    if (picked == null || picked == member.role) return;
    await _runMemberAction(
      () => widget.controller.setRoomMemberRole(
        groupId: _groupId,
        memberProfileId: member.profileId,
        role: picked,
      ),
    );
  }

  Future<void> _removeMember(RoomMember member) async {
    final ok = await _confirm(
      title: l10n.desktopRoomKickTitle,
      body:
          l10n.desktopRoomKickBody(_memberName(member)),
      okLabel: l10n.desktopRoomKick,
      danger: true,
    );
    if (ok != true) return;
    await _runMemberAction(
      () => widget.controller.removeGroupMember(
        groupId: _groupId,
        memberProfileId: member.profileId,
      ),
    );
  }

  Future<void> _banMember(RoomMember member) async {
    final ok = await _confirm(
      title: l10n.desktopRoomBlockTitle,
      body:
          l10n.desktopRoomBlockBody(_memberName(member)),
      okLabel: l10n.desktopRoomBlockMember,
      danger: true,
    );
    if (ok != true) return;
    await _runMemberAction(
      () => widget.controller.banRoomMember(
        groupId: _groupId,
        memberProfileId: member.profileId,
      ),
    );
  }

  Future<void> _unbanMember(RoomMember member) async {
    await _runMemberAction(
      () => widget.controller.unbanRoomMember(
        groupId: _groupId,
        memberProfileId: member.profileId,
      ),
    );
  }

  Future<void> _transferOwnership(RoomMember member) async {
    final ok = await _confirm(
      // 🔴 Единственное НЕОБРАТИМОЕ действие в этой панели: владельцем станет
      // другой человек, и вернуть себе комнату он должен будет сам.
      title: l10n.desktopRoomTransferTitle,
      body:
          l10n.desktopRoomTransferBody(_memberName(member)),
      okLabel: l10n.desktopRoomTransferAction,
      danger: true,
    );
    if (ok != true) return;
    await _runMemberAction(
      () => widget.controller.transferRoomOwnership(
        groupId: _groupId,
        nextOwnerProfileId: member.profileId,
      ),
    );
  }

  Future<void> _approveJoin(RoomMember member) async {
    await _runMemberAction(
      () => widget.controller.approveRoomJoinRequest(
        groupId: _groupId,
        memberProfileId: member.profileId,
      ),
    );
  }

  Future<void> _declineJoin(RoomMember member) async {
    await _runMemberAction(
      () => widget.controller.declineRoomJoinRequest(
        groupId: _groupId,
        memberProfileId: member.profileId,
      ),
    );
  }

  static String _memberName(RoomMember member) {
    final name = member.displayName.trim();
    return name.isEmpty ? member.profileId : name;
  }

  /// Pick the most usable invite to display (read-only on desktop):
  /// first non-revoked, non-expired link with remaining uses (if capped).
  /// Годная ссылка — общей [bestRoomInviteLink], чтобы правила пригодности
  /// (отозвана / просрочена / исчерпана) были описаны в одном месте.
  RoomInviteLink? _bestInviteLink() => bestRoomInviteLink(_inviteLinks);

  Future<void> _toggleMute() async {
    final next = !_muted;
    setState(() => _muted = next);
    try {
      await widget.controller.setChatMuted(convoId: _groupId, muted: next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _muted = !next);
    }
  }

  Future<void> _togglePinned() async {
    final next = !_pinned;
    setState(() => _pinned = next);
    try {
      await widget.controller.setChatPinned(convoId: _groupId, pinned: next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pinned = !next);
      _toast(l10n.desktopFailedWith('$e'), danger: true);
    }
  }

  Future<void> _toggleArchived() async {
    final next = !_archived;
    setState(() => _archived = next);
    try {
      await widget.controller.setChatArchived(
        convoId: _groupId,
        archived: next,
      );
      if (!mounted) return;
      if (next) widget.onClose();
    } catch (e) {
      if (!mounted) return;
      setState(() => _archived = !next);
      _toast(l10n.desktopFailedWith('$e'), danger: true);
    }
  }

  Future<void> _clearHistory() async {
    final ok = await _confirm(
      title: l10n.desktopRoomClearTitle,
      body: l10n.desktopRoomClearBody,
      okLabel: l10n.desktopChatsClear,
      danger: true,
    );
    if (ok != true) return;
    try {
      await widget.controller.clearChatHistory(convoId: _groupId);
      if (!mounted) return;
      _toast(l10n.desktopChatsHistoryCleared);
    } catch (e) {
      if (!mounted) return;
      _toast(l10n.desktopFailedWith('$e'), danger: true);
    }
  }

  Future<void> _leaveRoom() async {
    final ok = await _confirm(
      title: l10n.desktopRoomLeaveTitle,
      body:
          l10n.desktopRoomLeaveBody,
      okLabel: l10n.desktopRoomLeave,
      danger: true,
    );
    if (ok != true) return;
    try {
      await widget.controller.leaveRoom(_groupId);
      if (!mounted) return;
      widget.onClose();
    } catch (e) {
      if (!mounted) return;
      _toast(l10n.desktopFailedWith('$e'), danger: true);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String okLabel,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cc = DColors.of(ctx);
        return AlertDialog(
          backgroundColor: cc.elevated,
          title: Text(
            title,
            style: DType.title.copyWith(color: cc.textPrimary),
          ),
          content: Text(
            body,
            style: DType.body.copyWith(color: cc.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                l10n.cancel,
                style: DType.label.copyWith(color: cc.textPrimary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                okLabel,
                style: DType.label.copyWith(
                  color: danger ? cc.danger : cc.accentPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toast(String message, {bool danger = false}) {
    final c = DColors.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: danger ? c.danger : c.elevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Жалоба на комнату — тем же окном, что на телефоне.
  ///
  /// Единственная точка входа, которая на телефоне уже была: там она живёт в
  /// меню комнаты. На десктопе её не было вовсе — то есть у человека, которого
  /// травят в комнате, из компьютера не было ни одного выхода.
  Future<void> _report() async {
    final result = await showReportAbuseSheet(
      context: context,
      target: ReportAbuseTarget(
        type: ReportAbuseTargetType.room,
        id: _groupId,
        title: widget.conversation.title,
        conversationId: _groupId,
      ),
      buildMarker: widget.controller.buildMarker,
      reporterDeviceId: widget.controller.deviceId,
      reporterProfileId: widget.controller.profileId,
      additionalTechnicalLines:
          widget.controller.pushRegistrationTechnicalLines,
    );
    if (!mounted || result == null) return;
    _toast(reportAbuseDeliveryMessage(context, result));
  }

  List<List<CtxMenuItem>> _menuSections() {
    return <List<CtxMenuItem>>[
      [
        if (_canManageInvites)
          CtxMenuItem(
            label: l10n.desktopRoomInvite,
            icon: FluentIcons.person_add_24_regular,
            onTap: _invite,
          ),
        CtxMenuItem(
          label: l10n.desktopRoomCopyId,
          icon: FluentIcons.copy_24_regular,
          onTap: () {
            Clipboard.setData(ClipboardData(text: _groupId));
            _toast(l10n.desktopRoomIdCopied);
          },
        ),
        CtxMenuItem(
          label: _muted ? l10n.unmuteNotifications : l10n.desktopRoomMuteOff,
          icon: _muted
              ? FluentIcons.alert_24_regular
              : FluentIcons.alert_off_24_regular,
          onTap: _toggleMute,
        ),
        CtxMenuItem(
          label: _pinned ? l10n.desktopListRemoveFavourite : l10n.desktopListAddFavourite,
          icon: _pinned
              ? FluentIcons.pin_off_24_regular
              : FluentIcons.pin_24_regular,
          onTap: _togglePinned,
        ),
        CtxMenuItem(
          label: _archived ? l10n.desktopRoomUnarchive : l10n.desktopListArchive,
          icon: _archived
              ? FluentIcons.archive_arrow_back_24_regular
              : FluentIcons.archive_24_regular,
          onTap: _toggleArchived,
        ),
      ],
      [
        CtxMenuItem(
          // Подпись из общей локализации — те же слова, что на телефоне.
          label: reportAbuseMenuLabel(context),
          icon: FluentIcons.warning_24_regular,
          onTap: _report,
        ),
        CtxMenuItem(
          label: l10n.clearHistory,
          icon: FluentIcons.broom_24_regular,
          onTap: _clearHistory,
          isDanger: true,
        ),
        CtxMenuItem(
          label: l10n.desktopRoomLeaveRoom,
          icon: FluentIcons.sign_out_24_regular,
          onTap: _leaveRoom,
          isDanger: true,
        ),
      ],
    ];
  }

  List<RoomMember> _visibleMembers() {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _members;
    return _members
        .where((m) {
          final name = m.displayName.trim().toLowerCase();
          final pid = m.profileId.toLowerCase();
          return name.contains(q) || pid.contains(q);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final convo = widget.conversation;
    final title = convo.title.isEmpty ? l10n.desktopRoomUntitled : convo.title;
    final memberCount = _members.length;
    final memberText = _formatMemberCount(memberCount, l10n);
    final description = _settings?.description?.trim() ?? '';
    final avatarPath = convo.avatarPath?.trim() ?? '';
    final hasAvatarFile =
        avatarPath.isNotEmpty && File(avatarPath).existsSync();
    final invite = _bestInviteLink();
    final inviteUrl = invite == null
        ? null
        : buildRoomInviteShareLink(
            slug: invite.slug,
            createdByProfileId: invite.createdByProfileId,
            groupIdHint: invite.groupId,
          );
    final filteredMembers = _visibleMembers();

    return Column(
      children: [
        // Строки-шапки над обложкой больше нет: закрыть, «поделиться» и
        // «дополнительно» лежат на самой обложке, а имя пишется один раз —
        // под портретом. См. [DetailsHeadline].
        //
        // Портрет с именем НЕ уезжают при прокрутке: они отвечают на вопрос
        // «с кем я», а он не зависит от выбранной вкладки.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Обложка у комнаты не показывалась вовсе, хотя поле для неё
              // есть, — теперь тот же блок, что и у контакта.
              DetailsHeadline(
                name: title,
                cover: coverWidgetFor(widget.conversation.coverId),
                presence: !_room.hasLoaded ? l10n.desktopServerBackupLoading : memberText,
                emojiStatus: widget.conversation.emojiStatus,
                premiumBadge: widget.conversation.premiumBadge,
                frameId: widget.conversation.frameId,
                onClose: widget.onClose,
                // В демонстрационной комнате ссылки-приглашения не бывает:
                // на сервере такой комнаты нет, и запрос вернёт 404. Кнопки
                // там нет вовсе — см. [isDemoRoomId].
                onShare: isDemoRoomId(_groupId) ? null : _invite,
                shareTooltip: l10n.desktopRoomCopyInvite,
                menuSections: _menuSections(),
                avatar: HoverListener(
                  onTap: () => showAvatarPreviewDialog(
                    context,
                    name: title,
                    imagePath: hasAvatarFile ? avatarPath : null,
                    shape: AvatarShape.room,
                  ),
                  cursor: SystemMouseCursors.click,
                  builder: (ctx, hovered, pressed) => AnimatedScale(
                    scale: pressed ? 0.97 : 1.0,
                    duration: DMotion.fast,
                    child: Avatar(
                      name: title,
                      seed: _groupId,
                      image: hasAvatarFile
                          ? Avatar.fileImage(avatarPath)
                          : null,
                      frameId: widget.conversation.frameId,
                      allowAnimatedFrame: true,
                      size: 88,
                      // Это портрет САМОЙ комнаты. Участники ниже остаются
                      // круглыми — они люди.
                      shape: AvatarShape.room,
                    ),
                  ),
                ),
              ),
              DetailsActionRow(
                items: [
                  DetailsActionItem(
                    icon: _muted
                        ? FluentIcons.alert_off_24_regular
                        : FluentIcons.alert_24_regular,
                    label: _muted ? l10n.desktopChatsSoundOff : l10n.desktopRoomSound,
                    onPressed: _toggleMute,
                    active: _muted,
                  ),
                  DetailsActionItem(
                    icon: FluentIcons.broom_24_regular,
                    label: l10n.desktopChatsClear,
                    onPressed: _clearHistory,
                  ),
                  DetailsActionItem(
                    icon: FluentIcons.sign_out_24_regular,
                    label: l10n.desktopCallLeave,
                    onPressed: _leaveRoom,
                    danger: true,
                  ),
                ],
              ),
              const SizedBox(height: DSpace.s),
              // 🔴 ТЕЛО ПАНЕЛИ РАЗРЕЗАНО НА ВКЛАДКИ. Раньше это была одна лента
              // на три высоты окна, да ещё с галереей (у которой свои вкладки)
              // в самом низу: чтобы дойти до медиа, нужно было проехать мимо
              // всех участников. См. [DetailsTabs].
              DetailsTabs(
                tabs: [
                  l10n.desktopRoomTabInfo,
                  l10n.desktopRoomTabMembers,
                  l10n.desktopRoomTabMedia,
                ],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  sizing: StackFit.expand,
                  children: [
                    _infoTab(description, memberText, inviteUrl),
                    _membersTab(filteredMembers, memberCount),
                    _mediaTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Вкладка «Инфо»: темы, описание, сведения, переключатели чата.
  Widget _infoTab(String description, String memberText, String? inviteUrl) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: DSpace.s),
          const SizedBox(height: DSpace.s),
          // 🔴 Раздел виден и у комнаты БЕЗ тем — если их есть кому
          // завести.
          //
          // Полоса тем под шапкой появляется, только когда тема уже есть
          // хотя бы одна: иначе она отнимала бы 36 точек высоты у каждой
          // обычной комнаты. Но тогда у комнаты без тем не остаётся ни
          // одного входа, чтобы создать ПЕРВУЮ, и на десктопе темы
          // оказывались недостижимы, пока кто-нибудь не заведёт их с
          // телефона. Здесь этот вход и живёт.
          if (widget.topics.isNotEmpty || widget.onCreateTopic != null)
            // 🔴 Список, а не карточка фактов: см. [DetailsListSection].
            // Заголовок «ТЕМЫ · N» — из макета; «＋» переехал из
            // отдельной строки в конце списка в значок заголовка, где
            // его и ищут.
            DetailsListSection(
              title: widget.topics.isEmpty
                  ? l10n.desktopRoomTopics
                  : l10n.desktopRoomTopicsCount(widget.topics.length + 1),
              actionIcon: FluentIcons.add_24_regular,
              actionTooltip: l10n.desktopChatsNewTopic,
              // У комнаты БЕЗ тем значка в заголовке нет: там внизу стоит
              // строка со словами «Новая тема», и два входа в одно действие
              // рядом друг с другом читаются как два разных действия.
              onAction: widget.topics.isEmpty ? null : widget.onCreateTopic,
              children: [
                if (widget.topics.isNotEmpty) ...[
                  _TopicRow(
                    // ◆ «Основа», а не «Общий»: главный поток комнаты, от
                    // которого ветки и отходят.
                    title: kRoomBaseTopicTitleRu,
                    markIcon: roomTopicIconFor(widget.baseTopicMark),
                    markColor: roomTopicIconColorFor(widget.baseTopicMark),
                    selected: widget.currentTopicId == null,
                    unread: widget.topicUnread[''] ?? 0,
                    lastActivityMs: widget.topicLastActivityMs[''],
                    onTap: () => widget.onSelectTopic?.call(null),
                  ),
                  for (final t in widget.topics)
                    _TopicRow(
                      // Значок ровно один: решётка или то, чем её заменили.
                      markIcon: roomTopicIcon(t),
                      markColor: roomTopicIconColor(t),
                      title: normalizeRoomTopicTitle(t.title),
                      emoji: t.emoji.isEmpty ? null : t.emoji,
                      selected: widget.currentTopicId == t.id,
                      unread: widget.topicUnread[t.id] ?? 0,
                      lastActivityMs: widget.topicLastActivityMs[t.id],
                      onTap: () => widget.onSelectTopic?.call(t.id),
                    ),
                ] else if (widget.onCreateTopic != null)
                  // У комнаты без тем один значок в заголовке ничего не
                  // объясняет — здесь строка со словами и остаётся.
                  _CreateTopicRow(onTap: widget.onCreateTopic!),
              ],
            ),
          if (description.isNotEmpty)
            DetailsInfoSection(
              title: l10n.desktopRoomDescription,
              children: [
                DetailsInfoRow(
                  icon: FluentIcons.info_24_regular,
                  label: l10n.desktopRoomDescription,
                  value: description,
                  multiline: true,
                ),
              ],
            ),
          // ◆ ЗАМЕТКИ ПО КОМНАТЕ — ЗДЕСЬ, А НЕ ТОЛЬКО В СОЗВОНЕ.
          //
          // Вкладку «Заметки» просит макет панели созвона, но окно созвона
          // живёт ровно столько, сколько идёт разговор. Заметка, которую
          // видно только во время звонка, бесполезна именно тогда, когда за
          // ней приходят: через час, чтобы перечитать адрес.
          //
          // Это та же самая панель и та же самая запись — не копия.
          DetailsInfoSection(
            title: l10n.desktopRoomNotes,
            children: [
              RoomNotesPane(
                convoId: _groupId,
                load: widget.vm.localConvoNote,
                save: widget.vm.setLocalConvoNote,
                expand: false,
              ),
            ],
          ),
          DetailsInfoSection(
            title: l10n.desktopRoomInformation,
            children: [
              DetailsInfoRow(
                icon: FluentIcons.people_24_regular,
                label: l10n.desktopRoomTabMembers,
                value: memberText,
              ),
              DetailsInfoRow(
                // Ведущий значок называет, ЧТО это за строка, а не что с ней
                // делать: «копировать» теперь рисуется справа само, и два
                // одинаковых значка в одной строке читались бы как ошибка.
                icon: FluentIcons.people_team_24_regular,
                label: l10n.desktopRoomId,
                value: _groupId,
                copyValue: _groupId,
              ),
              if (inviteUrl != null && inviteUrl.isNotEmpty)
                DetailsInfoRow(
                  icon: FluentIcons.link_24_regular,
                  label: l10n.desktopRoomInviteLink,
                  // Показываем узнаваемое начало, копируем ссылку целиком:
                  // см. [DetailsInfoRow.shortUrl]. Полная ссылка занимала в
                  // панели пять строк — больше, чем весь остальной раздел.
                  value: DetailsInfoRow.shortUrl(inviteUrl),
                  copyValue: inviteUrl,
                ),
            ],
          ),
          const SizedBox(height: DSpace.s),
          DetailsInfoSection(
            title: l10n.contactDetailsChat,
            children: [
              DetailsToggleRow(
                icon: FluentIcons.pin_24_regular,
                label: l10n.desktopListAddFavourite,
                subtitle: l10n.desktopRoomFavouriteHint,
                value: _pinned,
                onChanged: (_) => _togglePinned(),
              ),
              DetailsToggleRow(
                icon: FluentIcons.archive_24_regular,
                label: l10n.desktopListArchive,
                subtitle: l10n.desktopRoomArchiveHint,
                value: _archived,
                onChanged: (_) => _toggleArchived(),
              ),
            ],
          ),
          const SizedBox(height: DSpace.s),
          const SizedBox(height: DSpace.l),
        ],
      ),
    );
  }

  /// Вкладка «Участники»: заявки, сам список, забаненные.
  Widget _membersTab(List<RoomMember> filteredMembers, int memberCount) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: DSpace.s),
          // 🔴 Заявки — ВЫШЕ списка участников и только когда они есть.
          // Человек, который стучится в комнату, ждёт ответа, а на
          // десктопе о нём нельзя было даже узнать.
          if (_pending.isNotEmpty && (_policy?.canApproveJoinRequests ?? false))
            _PendingSection(
              members: _pending,
              onApprove: (m) => unawaited(_approveJoin(m)),
              onDecline: (m) => unawaited(_declineJoin(m)),
            ),
          if (_pending.isNotEmpty && (_policy?.canApproveJoinRequests ?? false))
            const SizedBox(height: DSpace.s),
          _MembersSection(
            inCall: _inCall,
            onOpenMember: _openMemberCard,
            members: filteredMembers,
            totalCount: memberCount,
            loading: !_room.hasLoaded,
            searchController: _searchCtl,
            hasQuery: _query.isNotEmpty,
            menuFor: _memberMenuSections,
          ),
          if (_banned.isNotEmpty && (_policy?.canBanMembers ?? false)) ...[
            const SizedBox(height: DSpace.s),
            _BannedSection(
              members: _banned,
              onUnban: (m) => unawaited(_unbanMember(m)),
            ),
          ],
          const SizedBox(height: DSpace.l),
        ],
      ),
    );
  }

  /// Вкладка «Медиа»: галерея со своими четырьмя видами вложений.
  Widget _mediaTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopMediaGallery(controller: widget.controller, convoId: _groupId),
          const SizedBox(height: DSpace.l),
        ],
      ),
    );
  }

  /// 🔴 Русские формы числительного считались ЗДЕСЬ, вручную. Теперь их
  /// берёт правило множественного числа из переводов — в каждом языке своё,
  /// а не подогнанное под русское.
  String _formatMemberCount(int n, AppLocalizations l10n) =>
      n == 0 ? l10n.desktopRoomNoMembers : l10n.desktopRoomMembersCount(n);
}

class _MembersSection extends StatelessWidget {
  const _MembersSection({
    required this.onOpenMember,
    required this.members,
    required this.totalCount,
    required this.loading,
    required this.searchController,
    required this.hasQuery,
    required this.menuFor,
    this.inCall = const <String, CachedRoomCallParticipant>{},
  });

  /// Кто сейчас в созвоне, по профилю. Пусто — созвона нет.
  final Map<String, CachedRoomCallParticipant> inCall;

  /// Действия с участником. Пустой список — строка без кнопки: показывать
  /// многоточие, за которым ничего нет, значит обещать несуществующее.
  final List<List<CtxMenuItem>> Function(RoomMember member) menuFor;

  /// Левый щелчок по строке: карточка участника. Якорь — сама строка.
  final void Function(BuildContext rowContext, RoomMember member) onOpenMember;

  /// Already filtered by the search query.
  final List<RoomMember> members;

  /// Pre-filter total — used to decide whether to render the search field.
  final int totalCount;
  final bool loading;
  final TextEditingController searchController;
  final bool hasQuery;

  /// Сколько имён показывать без запроса там, где счёт может быть
  /// трёхзначным. Кто в сети — показывается весь, без этого предела.
  static const int _kOfflinePreview = 8;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);

    // 🔴 УЧАСТНИКИ РАЗЛОЖЕНЫ ПО ПРИСУТСТВИЮ, А НЕ СЛОЖЕНЫ В ОДНУ КУЧУ.
    //
    // Раздел без запроса показывал первые восемь имён подряд и строку
    // «ещё N». В комнате на сто человек это восемь случайных имён: тех, кто
    // сейчас в сети — а разговор идёт именно с ними, — там могло не быть
    // вовсе, и увидеть их было нечем, кроме поиска по имени, которое ещё надо
    // знать.
    //
    // Теперь две группы со счётчиками, как в макете. Кто В СЕТИ —
    // ПОКАЗЫВАЕТСЯ ВЕСЬ, без обрезки: это короткий список и ровно тот,
    // ради которого раздел открывают. Обрезка осталась там, где счёт
    // трёхзначный, — у «не в сети».
    //
    // 🔴 ГРУППА «В СОЗВОНЕ» ПОЯВИЛАСЬ 15.09.2026.
    //
    // Раньше её здесь не было с объяснением «признаки живут в состоянии
    // LiveKit и существуют только внутри идущего созвона». Это оказалось
    // неправдой: `muted`, `screenShareEnabled` и `joinState` лежат в
    // `CachedRoomCall` — снимке, который видит ВСЯ комната, а не только
    // подключившиеся к медиа. Из LiveKit приходит только «говорит», и его
    // здесь по-прежнему нет — рамки говорящего в списке участников не будет,
    // пока за неё нечем отвечать вне созвона.
    //
    // Признака «отошёл» (#F59E0B в макете) тоже нет и не будет, пока поля нет
    // в модели: жёлтая точка у человека, которого никто не спрашивал,
    // сообщает о нём то, чего мы не знаем.
    final call = <RoomMember>[];
    final online = <RoomMember>[];
    final offline = <RoomMember>[];
    for (final m in members) {
      if (inCall.containsKey(m.profileId)) {
        call.add(m);
      } else {
        (m.isOnline ? online : offline).add(m);
      }
    }
    // При поиске группы не нужны: человек уже назвал, кого ищет, и разбивка
    // на два заголовка над двумя строками только мешает.
    // Группы нужны, когда их есть чем разделить: две непустых или созвон.
    final grouped =
        !hasQuery &&
        (call.isNotEmpty || (online.isNotEmpty && offline.isNotEmpty));
    final visibleOffline = hasQuery
        ? offline
        : offline.take(_kOfflinePreview).toList(growable: false);
    final hiddenTail = hasQuery
        ? 0
        : (grouped
              ? offline.length - visibleOffline.length
              : members.length - members.take(_kOfflinePreview).length);

    final children = <Widget>[];
    if (totalCount >= 6) {
      children.add(_SearchField(controller: searchController));
    }
    if (loading) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(DSpace.m),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation(c.accentPrimary),
              ),
            ),
          ),
        ),
      );
    } else if (members.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(DSpace.m),
          child: Text(
            hasQuery ? l10n.desktopRoomNobodyFound : l10n.desktopRoomMembersUnavailable,
            style: DType.caption.copyWith(color: c.textSecondary),
          ),
        ),
      );
    } else if (grouped) {
      if (call.isNotEmpty) {
        children.add(_GroupHeading(label: l10n.desktopRoomInCall, count: call.length));
        children.addAll(
          call.map(
            (m) => _MemberRow(
              member: m,
              menuSections: menuFor(m),
              onOpen: onOpenMember,
              call: inCall[m.profileId],
            ),
          ),
        );
      }
      if (online.isNotEmpty) {
        children.add(_GroupHeading(label: l10n.desktopRoomOnline, count: online.length));
        children.addAll(
          online.map(
            (m) => _MemberRow(
              member: m,
              menuSections: menuFor(m),
              onOpen: onOpenMember,
            ),
          ),
        );
      }
      if (offline.isNotEmpty) {
        children.add(_GroupHeading(label: l10n.desktopRoomOffline, count: offline.length));
        children.addAll(
          visibleOffline.map(
            (m) => _MemberRow(
              member: m,
              menuSections: menuFor(m),
              dimmed: true,
              onOpen: onOpenMember,
            ),
          ),
        );
      }
    } else {
      // Все в одном состоянии (или идёт поиск) — заголовок группы был бы
      // подписью к единственной куче.
      final flat = hasQuery
          ? members
          : members.take(_kOfflinePreview).toList(growable: false);
      children.addAll(
        flat.map(
          (m) => _MemberRow(
            member: m,
            menuSections: menuFor(m),
            onOpen: onOpenMember,
          ),
        ),
      );
    }
    if (hiddenTail > 0) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DSpace.m,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                FluentIcons.people_team_24_regular,
                size: 18,
                color: c.textSecondary,
              ),
              const SizedBox(width: DSpace.m),
              Expanded(
                child: Text(
                  // Было «управление с телефона» — с 13.09 это неправда:
                  // управление здесь же. Осталось сказать, как добраться до
                  // остальных, а не куда идти за возможностями.
                  l10n.desktopRoomMoreHidden(hiddenTail),
                  style: DType.caption.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Заголовка у раздела НЕТ: он лежит во вкладке «Участники», и подпись
    // «УЧАСТНИКИ» под одноимённой вкладкой повторяет её слово в слово.
    return DetailsInfoSection(children: children);
  }
}

/// Заголовок группы участников: «В СЕТИ · 11».
///
/// Моноширинный, как все служебные ярлыки в макете, и со СЧЁТЧИКОМ: без него
/// заголовок отвечает «какие», но не отвечает «сколько», а в комнате это
/// первый вопрос.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DSpace.m, 10, DSpace.m, 4),
      child: Text(
        '$label · $count',
        style: DType.meta.copyWith(color: c.textDisabled),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DSpace.m,
        DSpace.s,
        DSpace.m,
        DSpace.s,
      ),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: controller,
          style: DType.body.copyWith(color: c.textPrimary),
          cursorColor: c.accentPrimary,
          decoration: InputDecoration(
            hintText: l10n.desktopRoomSearchMember,
            hintStyle: DType.body.copyWith(color: c.textSecondary),
            prefixIcon: Icon(
              FluentIcons.search_24_regular,
              size: 18,
              color: c.textSecondary,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (ctx, v, _) {
                if (v.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  splashRadius: 16,
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: l10n.desktopChatsClear,
                  icon: Icon(
                    FluentIcons.dismiss_circle_24_regular,
                    color: c.textSecondary,
                  ),
                  onPressed: controller.clear,
                );
              },
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            filled: true,
            fillColor: c.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DRadii.md),
              borderSide: BorderSide(color: c.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DRadii.md),
              borderSide: BorderSide(color: c.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DRadii.md),
              borderSide: BorderSide(color: c.accentPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.onOpen,
    this.menuSections = const <List<CtxMenuItem>>[],
    this.dimmed = false,
    this.call,
  });

  /// Состояние этого человека в идущем созвоне. `null` — он не в созвоне, и
  /// признаков микрофона и показа у него нет вовсе.
  ///
  /// 🔴 Именно НЕТ, а не «выключено»: серый перечёркнутый микрофон у того, кто
  /// в созвоне не участвует, читался бы как «он там и молчит».
  final CachedRoomCallParticipant? call;

  /// 🔴 Левый щелчок ОТКРЫВАЕТ карточку участника.
  ///
  /// Раньше его не было вовсе: строка ловила только правый щелчок, а курсор
  /// над ней был принудительно обычной стрелкой — список честно сообщал, что
  /// нажимать не на что. Узнать, кто этот человек, и написать ему из комнаты
  /// было нечем.
  final void Function(BuildContext rowContext, RoomMember member) onOpen;

  final RoomMember member;

  /// Строка «не в сети» приглушена, как в макете: группа большая, и полный
  /// контраст у ста имён перетягивает взгляд с тех немногих, кто сейчас тут.
  final bool dimmed;

  /// Действия, доступные ИМЕННО МНЕ и ИМЕННО с этим участником.
  final List<List<CtxMenuItem>> menuSections;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final name = member.displayName.trim().isEmpty
        ? member.profileId
        : member.displayName.trim();
    final role = roomMemberRoleSubtitle(member.role, l10n);
    final hasMenu = menuSections.isNotEmpty;
    return HoverListener(
      cursor: SystemMouseCursors.click,
      // Карточка всплывает ОТ СТРОКИ. Якорь — контекст самой строки: у
      // `StatelessWidget` он находит ближайший внутренний `RenderBox`, то
      // есть ровно эту строку. `GlobalKey` тут был бы хуже — строки
      // перестраиваются, и новый ключ на каждой перестройке заново
      // пересаживал бы поддерево.
      onTap: () => onOpen(context, member),
      // Правой кнопкой — как везде в этом окне.
      onSecondaryTapDown: hasMenu
          ? (details) => unawaited(
              ContextMenu.show(
                context,
                globalPosition: details.globalPosition,
                sections: menuSections,
              ),
            )
          : null,
      builder: (ctx, hovered, pressed) => Opacity(
        opacity: dimmed ? 0.6 : 1,
        child: Container(
          // Строка того, кто в созвоне, подсвечена зелёной плёнкой — тем же
          // цветом, которым в этом окне отмечено всё звучащее.
          color: call != null
              ? c.success.withValues(alpha: hovered ? 0.14 : 0.08)
              : (hovered ? c.hover : Colors.transparent),
          padding: const EdgeInsets.symmetric(
            horizontal: DSpace.m,
            vertical: 6,
          ),
          child: Row(
            children: [
              Avatar(
                name: name,
                seed: member.profileId,
                image: Avatar.fileImage(member.avatarPath),
                size: 32,
                online: member.isOnline,
              ),
              const SizedBox(width: DSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DType.body.copyWith(color: c.textPrimary),
                    ),
                    // «Показывает экран» важнее роли: роль постоянна, а показ
                    // идёт прямо сейчас, и это то, ради чего в список и
                    // заглядывают во время созвона.
                    if (call?.screenShareEnabled ?? false)
                      Text(
                        l10n.desktopCallSharingShort,
                        style: DType.caption.copyWith(color: c.success),
                      )
                    else if (role != null)
                      Text(
                        role,
                        style: DType.caption.copyWith(color: c.textSecondary),
                      ),
                  ],
                ),
              ),
              // 🔴 Признаки ТОЛЬКО у тех, кто в созвоне. У остальных их нет
              // вовсе, а не «выключено»: серый перечёркнутый микрофон у того,
              // кто в созвоне не участвует, читался бы как «он там и молчит».
              if (call != null) ...[
                if (call!.screenShareEnabled) ...[
                  Icon(
                    FluentIcons.share_screen_start_24_filled,
                    size: 15,
                    color: c.success,
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(
                  call!.deafened
                      ? FluentIcons.speaker_off_24_filled
                      : (call!.muted
                            ? FluentIcons.mic_off_24_filled
                            : FluentIcons.mic_24_filled),
                  size: 15,
                  // Выключенный себе звук тревожит, выключенный микрофон —
                  // нет: красим отказ слышать, как и в окне созвона.
                  color: call!.deafened
                      ? c.warning
                      : (call!.muted ? c.textDisabled : c.voice),
                ),
                const SizedBox(width: 6),
              ],
              // 🔴 Многоточие видно ВСЕГДА, пусть и приглушённо.
              //
              // Первая редакция прятала его до наведения (`opacity: 0`), и
              // это было плохо дважды: управление участниками нельзя найти,
              // не водя мышью по строкам, а невидимая кнопка всё равно ловит
              // нажатия — `Opacity` прозрачность считает, а попадания нет.
              if (hasMenu)
                Opacity(
                  opacity: hovered ? 1 : 0.45,
                  child: _MemberMenuButton(sections: menuSections),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Многоточие в строке участника.
class _MemberMenuButton extends StatelessWidget {
  const _MemberMenuButton({required this.sections});

  final List<List<CtxMenuItem>> sections;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Builder(
      builder: (btnContext) => HoverListener(
        cursor: SystemMouseCursors.click,
        onTap: () {
          final box = btnContext.findRenderObject() as RenderBox?;
          if (box == null) return;
          final pos = box.localToGlobal(Offset(0, box.size.height));
          unawaited(
            ContextMenu.show(
              btnContext,
              globalPosition: pos,
              sections: sections,
            ),
          );
        },
        builder: (ctx, hovered, pressed) => Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovered ? c.elevated : Colors.transparent,
            borderRadius: BorderRadius.circular(DRadii.sm),
          ),
          child: Icon(
            FluentIcons.more_vertical_24_regular,
            size: 16,
            color: c.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Заявки на вступление.
///
/// 🔴 На десктопе их не было видно вовсе: человек стучался в комнату, а
/// владелец за компьютером об этом не узнавал — только с телефона.
class _PendingSection extends StatelessWidget {
  const _PendingSection({
    required this.members,
    required this.onApprove,
    required this.onDecline,
  });

  final List<RoomMember> members;
  final ValueChanged<RoomMember> onApprove;
  final ValueChanged<RoomMember> onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DetailsInfoSection(
      title: l10n.desktopRoomJoinRequests,
      children: <Widget>[
        for (final m in members)
          _DecisionRow(
            member: m,
            primaryLabel: l10n.desktopRoomAccept,
            secondaryLabel: l10n.desktopRoomDecline,
            onPrimary: () => onApprove(m),
            onSecondary: () => onDecline(m),
          ),
      ],
    );
  }
}

/// Заблокированные — чтобы блокировку можно было СНЯТЬ, а не только наложить.
class _BannedSection extends StatelessWidget {
  const _BannedSection({required this.members, required this.onUnban});

  final List<RoomMember> members;
  final ValueChanged<RoomMember> onUnban;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DetailsInfoSection(
      title: l10n.desktopBlockedTitle,
      children: <Widget>[
        for (final m in members)
          _DecisionRow(
            member: m,
            primaryLabel: l10n.desktopUnblockAction,
            onPrimary: () => onUnban(m),
          ),
      ],
    );
  }
}

/// Строка участника с кнопками решения.
class _DecisionRow extends StatelessWidget {
  const _DecisionRow({
    required this.member,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final RoomMember member;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final name = member.displayName.trim().isEmpty
        ? member.profileId
        : member.displayName.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DSpace.m, vertical: 6),
      child: Row(
        children: [
          Avatar(
            name: name,
            seed: member.profileId,
            image: Avatar.fileImage(member.avatarPath),
            size: 32,
          ),
          const SizedBox(width: DSpace.m),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DType.body.copyWith(color: c.textPrimary),
            ),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            DesktopButton(
              label: secondaryLabel!,
              kind: DButtonKind.ghost,
              onPressed: onSecondary,
            ),
            const SizedBox(width: DSpace.s),
          ],
          DesktopButton(
            label: primaryLabel,
            kind: DButtonKind.tonal,
            onPressed: onPrimary,
          ),
        ],
      ),
    );
  }
}

/// Название роли — для ВЫБОРА, где безымянных вариантов быть не может.
String roomMemberRoleLabelRu(RoomMemberRole role, AppLocalizations l10n) {
  switch (role) {
    case RoomMemberRole.owner:
      return l10n.desktopRoomRoleOwner;
    case RoomMemberRole.admin:
      return l10n.desktopRoomRoleAdmin;
    case RoomMemberRole.moderator:
      return l10n.desktopRoomRoleModerator;
    case RoomMemberRole.member:
      return l10n.desktopChatsMember;
    case RoomMemberRole.restricted:
      return l10n.desktopRoomRoleRestricted;
    case RoomMemberRole.guest:
      return l10n.desktopRoomRoleGuest;
  }
}

/// Подпись роли для СТРОКИ списка.
///
/// У обычного участника её нет намеренно: подписать «Участник» каждого значит
/// утопить в шуме тех немногих, у кого роль вправду есть.
String? roomMemberRoleSubtitle(RoomMemberRole role, AppLocalizations l10n) =>
    role == RoomMemberRole.member ? null : roomMemberRoleLabelRu(role, l10n);

/// Одна тема в списке правой панели.
///
/// Счётчик числом, а не точкой: «сколько именно» решает, идти туда сейчас или
/// потом, и это ровно тот вопрос, ради которого человек открывает список тем.
/// «Новая тема» — вход для комнаты, где тем ещё нет ни одной.
class _CreateTopicRow extends StatelessWidget {
  const _CreateTopicRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      cursor: SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DSpace.m,
          vertical: DSpace.s,
        ),
        color: hovered ? c.hover : Colors.transparent,
        child: Row(
          children: [
            Icon(FluentIcons.add_24_regular, size: 15, color: c.accentPrimary),
            const SizedBox(width: DSpace.s),
            Text(
              l10n.desktopChatsNewTopic,
              style: DType.body.copyWith(
                color: c.accentPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.title,
    required this.selected,
    required this.unread,
    this.markIcon,
    this.markColor,
    required this.onTap,
    this.emoji,
    this.lastActivityMs,
  });

  final String title;
  final bool selected;
  final int unread;
  final VoidCallback onTap;
  final String? emoji;

  /// ◆ Значок ветки: решётка или заменивший её знак из общего с телефоном
  /// набора. `null` — у «Общего»: общий поток не ветка.
  final IconData? markIcon;

  /// Цвет значка. `null` — серый.
  final Color? markColor;

  /// Время последнего сообщения темы. `null` — не знаем (сообщения темы
  /// остались за краем загруженной ленты), и тогда справа пусто.
  final int? lastActivityMs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final time = desktopTimeLabel(lastActivityMs ?? 0, l10n);
    return HoverListener(
      onTap: onTap,
      cursor: SystemMouseCursors.click,
      // Геометрия строки из макета: 8/10, радиус 11, выбранная — белый с
      // альфой .07. Раньше выбранная заливалась `c.pressed`, то есть тем же
      // цветом, что и строка ПОД пальцем: выбор и нажатие выглядели
      // одинаково.
      builder: (ctx, hovered, pressed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.07)
              : (hovered ? c.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            // ◆ Знак, потом «#» — тот же порядок, что в полосе тем и на
            // телефоне. Решётка стоит ВСЕГДА: она говорит «это ветка».
            Icon(
              markIcon ?? FluentIcons.chat_24_regular,
              size: 17,
              color:
                  markColor ??
                  (selected ? c.accentPrimaryAlt : c.textTertiary),
            ),
            if (emoji != null) ...[
              const SizedBox(width: 4),
              Text(emoji!, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(width: DSpace.p6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DType.label.copyWith(
                  fontSize: 13,
                  color: selected ? c.textPrimary : c.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // ◆ СПРАВА У ТЕМЫ — ВРЕМЯ ИЛИ СЧЁТЧИК, по приоритету макета:
            // непрочитанное важнее времени и занимает то же место.
            //
            // Голос по темам протокол не различает вовсе — признака «в теме
            // идёт разговор» из макета здесь нет намеренно: рисовать его было
            // бы не по чему.
            // Отступ висит на самих подписях, а не отдельной распоркой: у
            // темы без времени и без счётчика справа не должно оставаться
            // пустых точек, иначе название обрывается раньше, чем нужно.
            if (unread == 0 && time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: DSpace.s),
                child: Text(
                  time,
                  style: DType.tiny.copyWith(
                    fontSize: 10.5,
                    color: c.textTertiary,
                  ),
                ),
              ),
            if (unread > 0)
              Container(
                margin: const EdgeInsets.only(left: DSpace.s),
                constraints: const BoxConstraints(minWidth: 19),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // Тема живёт в КОМНАТЕ — и счётчик у неё того же цвета, что
                  // у комнаты в списке чатов. См. `unreadColorFor`.
                  color: c.unreadRoom,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: DType.tiny.copyWith(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
