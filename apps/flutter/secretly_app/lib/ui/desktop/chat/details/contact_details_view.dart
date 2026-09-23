// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../../app/app_controller.dart';
import '../../app/contact_rename.dart';
import '../../../verify_contact_screen.dart';
import '../../../report_abuse_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../app/desktop_app_view_model.dart';
import '../../app/desktop_selector.dart';
import '../../../../calls/call_manager.dart';
import '../../../premium/cosmetics_catalog.dart'
    show coverBackWidgetFor, coverFrontWidgetFor;
import '../../design/tokens.dart';
import '../../primitives/avatar.dart';
import '../../primitives/context_menu.dart';
import '../../primitives/hover_listener.dart';
import '../../services/desktop_deleted_chats.dart';
import '../clear_history_dialog.dart';
import 'avatar_preview_dialog.dart';
import 'desktop_media_gallery.dart';
import 'details_action_row.dart';
import 'details_headline.dart';
import 'details_info_section.dart';
import 'details_tabs.dart';

/// Details view for a 1:1 conversation. Renders inside the third-column
/// drawer. Lays out (top-down):
///   • [DetailsHeadline] — обложка с кнопками (× слева, share и ⋮ справа),
///     портрет, имя и присутствие

///   • [DetailsActionRow] — Audio / Video / Mute / Block
///   • Info section — Secretly ID (copy on tap), auto-delete row
///   • [DesktopMediaGallery] — Photos / Videos / Files / Music
class ContactDetailsView extends StatefulWidget {
  const ContactDetailsView({
    super.key,
    required this.vm,
    required this.conversation,
    required this.onClose,
  });

  /// The controller seam. [controller] is derived from it, so every
  /// `widget.controller` use site below keeps working unchanged.
  final DesktopAppViewModel vm;
  AppController get controller => vm.controller;
  final Conversation conversation;
  final VoidCallback onClose;

  @override
  State<ContactDetailsView> createState() => _ContactDetailsViewState();
}

class _ContactDetailsViewState extends State<ContactDetailsView> {
  /// Подписи экрана контакта.
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool _muted = false;
  bool _blocked = false;

  /// Сверены ли коды безопасности с этим человеком — галочка у имени.
  bool _verified = false;
  bool _pinned = false;

  /// Выбранная вкладка панели: 0 — «Инфо», 1 — «Медиа».
  int _tab = 0;
  bool _archived = false;
  int? _autoDeleteSeconds;

  /// Blocked flag + disappearing-message timer, reloaded once per settled
  /// burst of controller ticks and republished only when either moved.
  ///
  /// This used to run `isProfileBlocked` AND `getChatAutoDeleteSeconds` on
  /// every `changed` tick — two database reads, on a bus that fires on the
  /// outbox pump and presence heartbeats, for two values that change when the
  /// user acts on this chat.
  late final DesktopSelector<({bool blocked, int? autoDeleteSeconds})> _status;

  String get _peerProfileId => widget.conversation.peerProfileId ?? '';

  /// Имя, под которым человек показан в переписке.
  ///
  /// Прочерка здесь нет намеренно: он годится для ПОКАЗА в шапке, но в поле
  /// переименования подставился бы как имя, и человек сохранил бы контакт с
  /// именем «—».
  String get _titleName => widget.conversation.title.trim();
  String get _convoId => widget.conversation.convoId;

  @override
  void initState() {
    super.initState();
    _muted = widget.conversation.muted;
    _autoDeleteSeconds = widget.conversation.autoDeleteSeconds;
    _pinned = widget.conversation.pinnedAtMs != null;
    _archived = widget.conversation.archivedAtMs != null;
    _status = widget.vm.select<({bool blocked, int? autoDeleteSeconds})>(
      debugName: 'contactStatus',
      initial: (blocked: false, autoDeleteSeconds: null),
      load: _loadStatus,
    )..addListener(_onStatus);
    unawaited(_loadVerified());
  }

  @override
  void didUpdateWidget(covariant ContactDetailsView old) {
    super.didUpdateWidget(old);
    if (old.conversation.convoId != widget.conversation.convoId) {
      _muted = widget.conversation.muted;
      _autoDeleteSeconds = widget.conversation.autoDeleteSeconds;
      _pinned = widget.conversation.pinnedAtMs != null;
      _archived = widget.conversation.archivedAtMs != null;
      _refreshStatus();
    } else if (old.conversation.pinnedAtMs != widget.conversation.pinnedAtMs ||
        old.conversation.archivedAtMs != widget.conversation.archivedAtMs) {
      // Re-sync from external changes (selection store refresh after action
      // taken in the chat list).
      _pinned = widget.conversation.pinnedAtMs != null;
      _archived = widget.conversation.archivedAtMs != null;
    }
  }

  @override
  void dispose() {
    _status.removeListener(_onStatus);
    _status.dispose();
    super.dispose();
  }

  /// A record, so `==` does the diffing — no hand-written signature needed
  /// and nothing to forget when a field is added.
  Future<void> _loadVerified() async {
    final pid = _peerProfileId;
    if (pid.isEmpty) return;
    try {
      final v = await widget.controller.contactWasEverVerified(pid);
      if (mounted && v != _verified) setState(() => _verified = v);
    } catch (_) {
      // best-effort: не сверили — значит галочки нет, и это честно
    }
  }

  Future<({bool blocked, int? autoDeleteSeconds})> _loadStatus() async {
    final pid = _peerProfileId;
    final blocked = pid.isEmpty
        ? false
        : await widget.controller.isProfileBlocked(pid);
    final secs = await widget.controller.getChatAutoDeleteSeconds(_convoId);
    return (blocked: blocked, autoDeleteSeconds: secs);
  }

  void _onStatus() {
    if (!mounted) return;
    setState(() {
      _blocked = _status.value.blocked;
      _autoDeleteSeconds = _status.value.autoDeleteSeconds;
    });
  }

  /// Reloads now, for a change this pane just caused.
  Future<void> _refreshStatus() => _status.refresh();

  Future<void> _toggleMute() async {
    final next = !_muted;
    setState(() => _muted = next);
    try {
      await widget.controller.setChatMuted(convoId: _convoId, muted: next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _muted = !next);
    }
  }

  Future<void> _togglePinned() async {
    final next = !_pinned;
    setState(() => _pinned = next);
    try {
      await widget.controller.setChatPinned(convoId: _convoId, pinned: next);
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
        convoId: _convoId,
        archived: next,
      );
      if (!mounted) return;
      if (next) {
        // Чат уехал в архив — закроем панель деталей, иначе пользователь
        // смотрит на «отсутствующий» чат.
        widget.onClose();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _archived = !next);
      _toast(l10n.desktopFailedWith('$e'), danger: true);
    }
  }

  Future<void> _toggleBlock() async {
    final pid = _peerProfileId;
    if (pid.isEmpty) return;
    final next = !_blocked;
    final confirm = await _confirm(
      title: next ? l10n.desktopContactBlockTitle : l10n.desktopContactUnblockTitle,
      body: next
          ? l10n.desktopContactBlockBody
          : l10n.desktopContactUnblockBody,
      okLabel: next ? l10n.desktopContactBlock : l10n.desktopUnblockAction,
      danger: next,
    );
    if (confirm != true) return;
    try {
      await widget.controller.setProfileBlocked(
        profileId: pid,
        blocked: next,
        deleteChatHistory: false,
      );
      if (!mounted) return;
      setState(() => _blocked = next);
    } catch (e) {
      if (!mounted) return;
      _toast(l10n.desktopFailedWith('$e'), danger: true);
    }
  }

  /// Жалоба на собеседника.
  ///
  /// 🔴 Окно берём у телефона ЦЕЛИКОМ, как и сверку кодов. Причин две, и обе
  /// важнее вида: список причин с переводами на восемь языков и разбор письма
  /// (`buildAbuseReportPayload`) уже написаны и выверены, а жалоба — это
  /// юридически значимый текст, который нельзя иметь в двух редакциях.
  ///
  /// Заодно закрывается пустая ветка: окно умеет жаловаться и на ПРОФИЛЬ, но
  /// на телефоне вход был только у комнаты, и профильная половина не звалась
  /// ниоткуда.
  Future<void> _report() async {
    final pid = _peerProfileId;
    if (pid.isEmpty) return;
    final result = await showReportAbuseSheet(
      context: context,
      target: ReportAbuseTarget(
        type: ReportAbuseTargetType.profile,
        id: pid,
        title: widget.conversation.title,
        conversationId: _convoId,
      ),
      buildMarker: widget.controller.buildMarker,
      reporterDeviceId: widget.controller.deviceId,
      reporterProfileId: widget.controller.profileId,
      additionalTechnicalLines:
          widget.controller.pushRegistrationTechnicalLines,
      allowBlockTarget: true,
      targetAlreadyBlocked: _blocked,
    );
    if (!mounted || result == null) return;
    // Блокировку выполняет ТОТ, КТО ПОЗВАЛ: окно только возвращает согласие.
    if (result.blockTarget && !_blocked) {
      try {
        await widget.controller.setProfileBlocked(
          profileId: pid,
          blocked: true,
          deleteChatHistory: false,
        );
        if (mounted) setState(() => _blocked = true);
      } catch (e) {
        // Жалоба уже ушла — молчать о неудавшейся блокировке нельзя, но и
        // отменять из-за неё жалобу незачем. Текст тот же, что у блокировки
        // из меню: это и есть она.
        if (mounted) _toast(l10n.desktopFailedWith('$e'), danger: true);
      }
    }
    if (!mounted) return;
    _toast(reportAbuseDeliveryMessage(context, result));
  }

  Future<void> _startCall({required bool video}) async {
    final pid = _peerProfileId;
    if (pid.isEmpty) return;
    final cm = CallManager.instance;
    if (cm == null) {
      _toast(l10n.desktopContactCallsNotReady, danger: true);
      return;
    }
    if (cm.state.value.isActive) {
      _toast(l10n.desktopContactCallInProgress);
      return;
    }
    try {
      await cm.startCall(
        peerProfileId: pid,
        peerName: widget.conversation.title.isEmpty
            ? pid
            : widget.conversation.title,
        peerAvatarPath: widget.conversation.avatarPath,
        video: video,
      );
    } catch (e) {
      if (!mounted) return;
      _toast(l10n.desktopContactCallFailed('$e'), danger: true);
    }
  }

  Future<void> _setAutoDelete(int? seconds) async {
    try {
      await widget.controller.setChatAutoDeleteSeconds(
        convoId: _convoId,
        autoDeleteSeconds: seconds,
      );
      if (!mounted) return;
      setState(() => _autoDeleteSeconds = seconds);
    } catch (e) {
      if (!mounted) return;
      _toast(l10n.desktopFailedWith('$e'), danger: true);
    }
  }

  Future<void> _pickAutoDelete() async {
    final picked = await showDialog<_AutoDeleteChoice>(
      context: context,
      builder: (ctx) {
        final cc = DColors.of(ctx);
        return AlertDialog(
          backgroundColor: cc.elevated,
          title: Text(
            l10n.desktopContactAutoDelete,
            style: DType.title.copyWith(color: cc.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in _autoDeleteOptions(l10n).entries)
                ListTile(
                  title: Text(
                    entry.key,
                    style: DType.body.copyWith(color: cc.textPrimary),
                  ),
                  trailing: _autoDeleteSeconds == entry.value
                      ? Icon(Icons.check, color: cc.accentPrimary)
                      : null,
                  onTap: () =>
                      Navigator.of(ctx).pop(_AutoDeleteChoice(entry.value)),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null) return; // dismissed
    if (picked.seconds == _autoDeleteSeconds) return; // unchanged
    await _setAutoDelete(picked.seconds);
    if (!mounted) return;
    _toast(l10n.desktopContactAutoDeleteUpdated);
  }

  /// 🔴 ТА ЖЕ ГАЛОЧКА, ЧТО В МЕНЮ СПИСКА (16.09.2026).
  ///
  /// «Очистить историю» в меню списка чатов предлагала стереть переписку и у
  /// собеседника, а та же кнопка здесь — нет. Подпись одна, делают разное, и о
  /// второй возможности человек, нажавший её отсюда, просто не узнавал. Диалог
  /// теперь общий — см. [confirmClearWithPeer].
  Future<void> _clearHistory() async {
    final peer = _peerProfileId.trim();
    final myPid = widget.controller.profileId.trim();
    // Себе самому чистить «у собеседника» нечего: собеседник — я же.
    final canClearPeer = peer.isNotEmpty && peer != myPid;
    final title = widget.conversation.title.trim();
    final result = await confirmClearWithPeer(
      context,
      title: l10n.desktopChatsClearHistoryTitle,
      body: l10n.desktopContactClearBody,
      okLabel: l10n.desktopChatsClear,
      peerTitle: canClearPeer ? (title.isEmpty ? '—' : title) : null,
    );
    if (result == null || !mounted) return;
    try {
      if (result.alsoForPeer && canClearPeer) {
        await widget.controller.clearChatHistoryEverywhere(
          convoId: _convoId,
          directPeerProfileId: peer,
        );
        if (!mounted) return;
        _toast(l10n.desktopChatsHistoryClearedBoth);
      } else {
        await widget.controller.clearChatHistory(convoId: _convoId);
        if (!mounted) return;
        _toast(l10n.desktopChatsHistoryCleared);
      }
    } catch (e) {
      if (!mounted) return;
      _toast(l10n.desktopFailedWith('$e'), danger: true);
    }
  }

  Future<void> _deleteChat() async {
    final ok = await _confirm(
      title: l10n.desktopChatsDeleteChatTitle,
      body: l10n.desktopContactDeleteBody,
      okLabel: l10n.delete,
      danger: true,
    );
    if (ok != true) return;
    try {
      // 🔴 Тот же порядок, что и в списке чатов: отсечка, снос, метка сноса.
      //
      // Здесь не было ни первого, ни третьего — то есть удаление из карточки
      // собеседника было слабее удаления из списка: чат возвращался на
      // следующей синхронизации вместе со всеми сообщениями. Две кнопки с
      // одним названием обязаны делать одно и то же.
      await widget.controller.clearChatHistory(convoId: _convoId);
      await widget.controller.deleteChat(convoId: _convoId);
      await DesktopDeletedChats.remember(_convoId);
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

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  /// Открывает мобильный экран сверки кодов безопасности.
  ///
  /// Он принимает только контроллер и сам себе Scaffold — подключается как
  /// есть, ровно как экраны созвона комнаты и создания комнаты.
  void _openVerifyContact() {
    final pid = _peerProfileId;
    if (pid.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VerifyContactScreen(
          controller: widget.controller,
          peerProfileId: pid,
          title: widget.conversation.title,
        ),
      ),
    );
  }

  String _autoDeleteLabel() {
    final s = _autoDeleteSeconds;
    if (s == null || s <= 0) return l10n.desktopContactOff;
    if (s == 86400) return l10n.desktopContactDay1;
    if (s == 86400 * 7) return l10n.desktopContactDays7;
    if (s == 86400 * 30) return l10n.desktopContactDays30;
    if (s == 3600) return l10n.desktopContactHour1;
    return l10n.desktopContactMinutes('${s ~/ 60}');
  }

  String _presenceText() {
    final convo = widget.conversation;
    if (convo.isOnline) return l10n.desktopChatsOnline;
    final ts = convo.peerLastSeenAtMs;
    // 🔴 Ноль — это «время неизвестно», а не «был в 1970-м». Без этой отсечки
    // панель показывала «был(а) 01.01» — тот же дефект, что нашёлся в шапке
    // чата 03.08.2026. Здесь «не в сети» уместно: выше уже проверено isOnline.
    if (ts == null || ts <= 0) return l10n.desktopContactOffline;
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return l10n.desktopContactSeenAt('$h:$m');
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return l10n.desktopContactSeenYesterday;
    }
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return l10n.desktopContactSeenOn('$d.$mo');
  }

  /// «Поделиться» на обложке — это ID собеседника в буфере.
  ///
  /// Ничего другого у человека для передачи третьему лицу нет: ссылки-
  /// приглашения бывают у комнаты, а визитки в проекте не существует. То же
  /// действие есть в меню «Дополнительно» — здесь это ярлык, как в макете.
  void _shareId() {
    Clipboard.setData(ClipboardData(text: _peerProfileId));
    _toast(l10n.desktopRoomIdCopied);
  }

  List<List<CtxMenuItem>> _menuSections() {
    return <List<CtxMenuItem>>[
      [
        CtxMenuItem(
          label: l10n.desktopContactCopyId,
          icon: FluentIcons.copy_24_regular,
          onTap: () {
            Clipboard.setData(ClipboardData(text: _peerProfileId));
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
          // Одно название на оба входа: в панели строка называется так же.
          // Два имени у одной настройки человек читает как две разные.
          label: l10n.desktopContactDisappearing,
          icon: FluentIcons.timer_24_regular,
          onTap: _pickAutoDelete,
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
          label: _blocked ? l10n.desktopUnblockAction : l10n.desktopContactBlock,
          icon: _blocked
              ? FluentIcons.shield_24_regular
              : FluentIcons.shield_dismiss_24_regular,
          onTap: _toggleBlock,
          isDanger: !_blocked,
        ),
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
          label: l10n.desktopContactDeleteChat,
          icon: FluentIcons.delete_24_regular,
          onTap: _deleteChat,
          isDanger: true,
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final convo = widget.conversation;
    final displayName = convo.title.isEmpty ? '—' : convo.title;
    final presence = _presenceText();
    final avatarPath = convo.avatarPath?.trim() ?? '';
    final hasAvatarFile =
        avatarPath.isNotEmpty && File(avatarPath).existsSync();
    // Premium profile cover (обложка) banner behind the avatar, when the peer
    // has one. Rendered regardless of the local user's tier.
    // 🔴 Два слоя, как на телефоне: задний — сцена без ближнего края диска,
    // передний — сам край, он проходит ПЕРЕД лицом.
    final cover = coverBackWidgetFor(convo.coverId);
    final coverFront = coverFrontWidgetFor(convo.coverId);

    return Column(
      children: [
        // Строки-шапки над обложкой больше нет: закрыть, «поделиться» и
        // «дополнительно» лежат на самой обложке, а имя пишется один раз —
        // под портретом. См. [DetailsHeadline].
        //
        // Портрет с именем НЕ уезжают при прокрутке: они отвечают на вопрос
        // «с кем я», а он не зависит от выбранной вкладки. См. [DetailsTabs].
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DetailsHeadline(
                name: displayName,
                avatarDiameter: 88,
                cover: cover,
                coverFront: coverFront,
                presence: presence,
                presenceIsOnline: convo.isOnline,
                emojiStatus: convo.emojiStatus,
                premiumBadge: convo.premiumBadge,
                verified: _verified,
                frameId: convo.frameId,
                onClose: widget.onClose,
                onShare: _peerProfileId.isEmpty ? null : _shareId,
                shareTooltip: l10n.desktopContactCopyIdShort,
                menuSections: _menuSections(),
                avatar: HoverListener(
                  onTap: () => showAvatarPreviewDialog(
                    context,
                    name: displayName,
                    imagePath: hasAvatarFile ? avatarPath : null,
                  ),
                  cursor: SystemMouseCursors.click,
                  builder: (ctx, hovered, pressed) => AnimatedScale(
                    scale: pressed ? 0.97 : 1.0,
                    duration: DMotion.fast,
                    child: Avatar(
                      name: displayName,
                      // Оттенок по профилю, а не по имени — как на телефоне.
                      seed: _peerProfileId,
                      image: hasAvatarFile
                          ? Avatar.fileImage(avatarPath)
                          : null,
                      frameId: convo.frameId,
                      allowAnimatedFrame: true,
                      size: 88,
                      // 🔴 БЕЗ ЗЕЛЁНОЙ ТОЧКИ (указание владельца 16.09.2026).
                      // Под портретом и так написано «в сети» — точка на
                      // фото повторяла ту же строку второй раз и заслоняла
                      // угол снимка. В списке и в шапке, где подписи нет,
                      // точка остаётся.
                      online: false,
                    ),
                  ),
                ),
              ),
              DetailsActionRow(
                items: [
                  DetailsActionItem(
                    icon: FluentIcons.call_24_regular,
                    label: l10n.desktopContactCall,
                    onPressed: () => _startCall(video: false),
                  ),
                  DetailsActionItem(
                    icon: FluentIcons.video_24_regular,
                    label: l10n.desktopChatsVideo,
                    onPressed: () => _startCall(video: true),
                  ),
                  DetailsActionItem(
                    icon: _muted
                        ? FluentIcons.alert_off_24_regular
                        : FluentIcons.alert_24_regular,
                    label: _muted ? l10n.desktopChatsSoundOff : l10n.desktopRoomSound,
                    onPressed: _toggleMute,
                    active: _muted,
                  ),
                  DetailsActionItem(
                    icon: _blocked
                        ? FluentIcons.shield_24_regular
                        : FluentIcons.shield_dismiss_24_regular,
                    // Без точки: «Блок.» с точкой читается как оборванное
                    // слово, а места в плитке 56 хватает обоим.
                    label: _blocked ? l10n.desktopUnblockAction : l10n.desktopContactBlockShort,
                    onPressed: _toggleBlock,
                    danger: !_blocked,
                    active: _blocked,
                  ),
                ],
              ),
              const SizedBox(height: DSpace.s),
              DetailsTabs(
                tabs: [l10n.desktopRoomTabInfo, l10n.desktopRoomTabMedia],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  sizing: StackFit.expand,
                  children: [_infoTab(), _mediaTab()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Вкладка «Инфо»: сведения о человеке и переключатели чата.
  Widget _infoTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: DSpace.s),
          const SizedBox(height: DSpace.s),
          DetailsInfoSection(
            title: l10n.desktopRoomInformation,
            children: [
              if (_peerProfileId.isNotEmpty)
                DetailsInfoRow(
                  icon: FluentIcons.person_24_regular,
                  label: 'Secretly ID',
                  value: _peerProfileId,
                  copyValue: _peerProfileId,
                ),
              // 🔴 ПЕРЕИМЕНОВАТЬ МОЖНО И ОТСЮДА (21.09.2026).
              //
              // Своё имя контакту на компьютере не давалось НИГДЕ; когда оно
              // появилось в разделе «Контакты», сюда его пришлось добавить
              // сразу же. Человек, который смотрит на карточку собеседника
              // ПРЯМО ИЗ ПЕРЕПИСКИ, не пойдёт искать его же в другом разделе:
              // он решит, что переименовать нельзя.
              //
              // Окно — то же самое (`showRenameContactDialog`), а не похожее:
              // две копии одного действия расходятся текстами и обещают
              // разное.
              if (_peerProfileId.isNotEmpty)
                DetailsInfoRow(
                  icon: FluentIcons.tag_24_regular,
                  label: l10n.contactEditNameLabel,
                  value: _titleName.isEmpty ? '—' : _titleName,
                  onTap: () => unawaited(showRenameContactDialog(
                    context: context,
                    vm: widget.vm,
                    profileId: _peerProfileId,
                    // Подставляем показанное имя — ровно как на телефоне
                    // (`edit_contact_screen.dart`, `initialName`). Пустое
                    // поле снимает своё имя и возвращает то, которым человек
                    // назвался сам.
                    currentName: _titleName,
                  )),
                ),
              // · «ИСЧЕЗАЮЩИЕ СООБЩЕНИЯ» — НАСТРОЙКА, А НЕ ФАКТ (макет).
              //
              // Строка называлась «Автоудаление» и была устроена как строка
              // фактов: сверху значение («Выкл.»), снизу подпись. Но это не
              // факт о собеседнике — это то, что человек ВКЛЮЧАЕТ, и в такой
              // строке сверху должно стоять НАЗВАНИЕ, а снизу состояние.
              //
              // Переключатель отвечает за вкл/выкл, а нажатие на строку
              // открывает выбор срока: возможность выбрать «1 час» или
              // «30 дней» у нас шире макета, и урезать её до двух положений
              // было бы потерей.
              DetailsToggleRow(
                icon: FluentIcons.timer_24_regular,
                label: l10n.desktopContactDisappearing,
                subtitle: _autoDeleteLabel(),
                value: (_autoDeleteSeconds ?? 0) > 0,
                onChanged: (on) => unawaited(
                  on ? _pickAutoDelete() : _setAutoDelete(null),
                ),
                onTap: _pickAutoDelete,
              ),
              // 🔴 Проверка контакта — защитная функция, и до 13.09 на
              // десктопе её не было НИ ОДНОЙ точки входа.
              //
              // При этом переключатель «блокировать отправку
              // непроверенным» в десктопных настройках был: человек
              // включал его у себя же и терял возможность писать,
              // получая «Bad state: Contact is unverified» без единого
              // выхода. Настройка, которую нельзя отработать, хуже
              // отсутствующей.
              //
              // Экран сверки кодов берём у телефона целиком — писать
              // свою сверку кодов безопасности второй раз нельзя.
              if (_peerProfileId.isNotEmpty)
                DetailsInfoRow(
                  icon: FluentIcons.shield_checkmark_24_regular,
                  // Подписи из общей локализации: те же слова, что на
                  // телефоне, и сразу на всех языках.
                  //
                  // Порядок как у соседних строк: сверху ДЕЙСТВИЕ, снизу
                  // название поля. «Проверить / Проверить контакт»
                  // читалось бы как заикание.
                  label: _l10n?.securityTitle ?? l10n.desktopContactSecurity,
                  value: _l10n?.verifyContact ?? l10n.desktopContactVerify,
                  onTap: _openVerifyContact,
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
                subtitle: l10n.desktopContactArchiveHint,
                value: _archived,
                onChanged: (_) => _toggleArchived(),
              ),
            ],
          ),
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
          DesktopMediaGallery(controller: widget.controller, convoId: _convoId),
          const SizedBox(height: DSpace.l),
        ],
      ),
    );
  }
}

/// Сроки автоудаления. Подписи приходят из переводов, поэтому это функция, а
/// не постоянная: у постоянной нет доступа к языку окна.
Map<String, int?> _autoDeleteOptions(AppLocalizations l10n) => <String, int?>{
  l10n.desktopContactDisable: null,
  l10n.desktopContactHour1: 3600,
  l10n.desktopContactDay1: 86400,
  l10n.desktopContactDays7: 86400 * 7,
  l10n.desktopContactDays30: 86400 * 30,
};

class _AutoDeleteChoice {
  const _AutoDeleteChoice(this.seconds);
  final int? seconds;
}
