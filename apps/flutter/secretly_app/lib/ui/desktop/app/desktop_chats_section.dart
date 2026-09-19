// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_controller.dart';
import '../../../app/pending_attachment_upload.dart';
import '../../../attachments/attachment_failure.dart';
import '../../attachment_error_text.dart';
import '../../room_topic_marks.dart';
import '../primitives/hover_listener.dart';
import '../primitives/desktop_tooltip.dart';
import '../../../app/message_command_utils.dart'
    show
        buildDeleteForAllCommand,
        buildForwardCommand,
        isDeleteForAllCommandText,
        parseDeleteForAllCommand,
        parseForwardCommand,
        parsePollCommand,
        kPollCommandPrefix,
        kPollVoteCommandPrefix,
        kPollCloseCommandPrefix,
        kEventCommandPrefix,
        kEventRsvpCommandPrefix,
        parseEventCommand,
        isTopicsSyncCommandText,
        parseTopicsSyncCommand,
        RoomTopicRef;
import '../../../calls/call_event.dart' show buildCallEventPreviewText;
import '../../../calls/call_manager.dart';
import '../../../calls/call_signal_codec.dart';
import '../../../messages/message_delivery_state.dart';
import '../../../links/link_preview_draft.dart';
import '../../../links/link_preview_policy.dart'
    show acceptIncomingLinkPreview, linkPreviewTargetFor;
import '../../../media/music_tags.dart';
import '../../../models/e2e_payload_v1.dart';
import '../../../security/app_security_manager.dart' show SecurityLockScope;
import '../../security_lock_flow.dart' show ensureSecurityScopeUnlocked;
import '../../../stickers/sticker_catalog.dart'
    show SecretlyStickerCatalog, SecretlyStickerDescriptor;
import '../../new_group_screen.dart';
import '../../verify_contact_screen.dart';
import '../../direct_message_error_text.dart';
import '../../room_policy_error_text.dart' show tryRoomPolicyErrorText;
// Подписи шапки — те же, что на телефоне: «был(а) …» и «N участников».
import '../../chat_screen_l10n.dart'
    show chatLastSeenText, chatLocaleIsRussian, chatRoomInviteMembersText;
import '../../../l10n/app_localizations.dart';
import '../calls/room_call_window.dart';
import '../chat/new_chat_picker.dart';
import '../../../rooms/room_call_state.dart' show CachedRoomCall;
import '../../../rooms/room_system_event_text.dart' show formatSystemEventText;
import '../../room_l10n_bridge.dart' show roomLocaleTagFromContext;
import '../../room_invite_join_screen.dart' show RoomInviteJoinScreen;
import '../chat/room_call_banner.dart';
import '../chat/attachment_kinds.dart';
import '../chat/outgoing_media.dart';
import '../chat/send_media_dialog.dart';
import '../chat/media_albums.dart';
import '../chat/attachment_save.dart';
import '../chat/desktop_event_tally.dart';
import '../chat/forward_blob_reuse.dart';
import '../chat/event_composer_dialog.dart';
import '../chat/poll_composer_dialog.dart';
import '../chat/desktop_poll_tally.dart';
import '../chat/desktop_pdf_bridge.dart';
import '../chat/document_viewer.dart';
import '../chat/document_viewer_kind.dart';
import '../chat/chat_list_footer.dart';
import '../chat/chat_list_panel.dart';
import '../chat/chat_time_label.dart';
import '../chat/desktop_mentions.dart';
import '../chat/chat_thread_panel.dart';
import '../chat/desktop_photo_viewer.dart';
import '../chat/desktop_video_viewer.dart';
import '../chat/forward_target_dialog.dart';
import '../chat/room_topics_strip.dart';
import '../chat/clear_history_dialog.dart';
import '../chat/schedule_send_dialog.dart' show formatScheduleMoment;
import '../shell/list_thread_split.dart';
import '../primitives/desktop_snackbar.dart';
import '../chat/details/desktop_selection_store.dart';
import '../chat/details/room_details_view.dart' show roomMemberRoleSubtitle;
// Aliased so the bubble's `MessageReaction` (count+byMe view-model) doesn't
// collide with the controller's `MessageReaction` (per-actor DB row) — both
// are needed inside `_aggregateReactions`.
import '../chat/message_bubble.dart' hide MessageReaction;
import '../chat/message_bubble.dart' as bubble
    show MessageReaction, ReactionActor;
import '../chat/recent_reactions_store.dart';
import '../../../app/chat_read_target.dart';
import '../services/desktop_deleted_chats.dart';
import '../services/desktop_ui_prefs.dart';
import 'desktop_absence_notice.dart';
import 'desktop_media_send.dart';
import 'desktop_app_view_model.dart';
import 'desktop_selector.dart';
import '../design/tokens.dart';
import '../primitives/desktop_button.dart' show DButtonKind, DesktopButton;
import '../primitives/context_menu.dart';
import '../primitives/desktop_dialog.dart';
import '../primitives/desktop_text_field.dart';
import '../shell/desktop_shell.dart' show DesktopShellApi;
import 'desktop_sync_status.dart';
import '../services/desktop_window_activity.dart';

/// Итог отправки копии сообщения при пересылке или сохранении.
enum _CopyOutcome { sent, noFile, empty }

/// Подпись своего сообщения — одна на файл: и у пузыря в ленте, и у автора
/// в превью списка. Две копии этой строки однажды разошлись бы.
const String _kSelfAuthorRu = 'Вы';

/// Filter mode for [DesktopChatsSection].
enum ConversationFilter {
  /// Direct (1:1) chats only.
  directs,

  /// Group / room conversations only.
  groups,

  /// No filter — every conversation.
  all,
}

/// Chats section wiring (Slice 1 + Slice 2; Slice 4 added [filter]).
///
/// Slice 1: lists conversations from [AppController.listConversations] and
/// reacts to the `changed` stream (debounced).
///
/// Slice 2: opens [_ChatThreadHost] for the selected conversation. The host
/// loads + decrypts [ChatEvent]s into [MessageData], filters control/system
/// traffic, marks the chat read, and sends new messages back through
/// [AppController.sendMessage].
///
/// Slice 4: same widget is reused for the «Комнаты» section by passing
/// [ConversationFilter.groups]. Sending / calling into groups still falls
/// through the existing thread-host guards (no group send/call on desktop
/// in this slice).
/// Пуст ли чат на самом деле — или мы просто ещё не разобрали входящий ящик.
///
/// Пустой список сообщений значит «переписки нет» ТОЛЬКО после того, как реле
/// отдало всё накопленное. До этого сообщение может лежать на реле, и показывать
/// пустой чат — значит выдавать незнание за знание (долг паритета d69fe6b3,
/// полевой отчёт 03.08.2026: человек нажал на уведомление, попал в чат, увидел
/// пустоту, и лишь через пятнадцать секунд появилось сообщение).
///
/// 🔴 [relayOnline] — страховка от вечного кружка, и убирать её нельзя. Если
/// связи нет, разбора не будет никогда, ждать нечего: пустота настоящая, и
/// человек должен увидеть чат, а не кружок до конца времён.
bool chatEmptinessStillUnknown({
  required bool firstDrainDone,
  required bool relayOnline,
}) => !firstDrainDone && relayOnline;

class DesktopChatsSection extends StatefulWidget {
  const DesktopChatsSection({
    super.key,
    required this.vm,
    required this.shellApi,
    this.selection,
    this.syncStatus,
    this.filter = ConversationFilter.directs,
    this.emptyTitleNoItems = 'Чатов пока нет',
    this.emptySubtitleNoItems =
        'Начните общение с телефона — чаты автоматически синхронизируются на десктопе.',
    this.emptyTitleSelect = 'Выберите чат слева',
  });

  /// The controller seam. [controller] is derived from it, so every
  /// `widget.controller` use site below keeps working unchanged.
  final DesktopAppViewModel vm;
  AppController get controller => vm.controller;
  final DesktopShellApi shellApi;

  /// PR4 (SPRINT2_AUDIT §16): drives the connection/backfill strip
  /// rendered above the chat list. Optional — null hides the banner
  /// entirely (useful for tests, screenshots, etc).
  final DesktopSyncStatusController? syncStatus;

  /// Optional shared store. If provided, the section publishes the currently
  /// selected [Conversation] here so the right-column `detailsBuilder` of
  /// [DesktopShell] can render the matching details view. The store is also
  /// updated when the chat list refreshes (e.g. presence change) so the
  /// details panel stays in sync with the list.
  final DesktopChatSelectionStore? selection;
  final ConversationFilter filter;
  final String emptyTitleNoItems;
  final String emptySubtitleNoItems;
  final String emptyTitleSelect;

  @override
  State<DesktopChatsSection> createState() => _DesktopChatsSectionState();
}

class _DesktopChatsSectionState extends State<DesktopChatsSection> {
  Timer? _previewRefresh;

  /// The chat list, loaded once per settled burst of controller ticks and
  /// republished only when a row actually looks different.
  ///
  /// This was the hottest path in the desktop tree. `changed` fires constantly
  /// on a paired client, and every tick ran `listConversations()` **plus one
  /// `lastMessagePreviewRich()` per conversation** — fifty-odd database reads
  /// for a list that had not moved — and then rebuilt the whole list
  /// unconditionally. The signature ([_chatListSignature]) is derived from the
  /// rendered [ChatListItem]s, so it tracks exactly what a row shows rather
  /// than a hand-picked subset of `Conversation` that would silently drift.
  late final DesktopSelector<List<Conversation>> _convos;

  List<Conversation> _conversations = const [];
  final Map<String, ChatListPreview> _previews = {};
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    // Смена фокуса окна не приходит тиком контроллера, а от неё зависит
    // режим обоев ([desktopWallpaperAnimModeFor]). Случается редко, поэтому
    // обычная перерисовка секции здесь дешевле любой точечной подписки.
    DesktopWindowActivity.focused.addListener(_onWindowFocusChanged);
    // Общий замок снова запер «Личные» (окно было скрыто дольше срока) —
    // спрятать их сразу, а не когда человек сам уйдёт из категории.
    _securitySub = widget.controller.security.changed.listen(
      (_) => _onSecurityChanged(),
    );
    _convos = widget.vm.select<List<Conversation>>(
      debugName: 'chatList:${widget.filter.name}',
      initial: const <Conversation>[],
      load: _loadConversations,
      signature: _chatListSignature,
    )..addListener(_onConversations);
    // Alt+Arrow walks the list from anywhere in the window.
    widget.shellApi.chatCycle.addListener(_onChatCycle);
    DesktopDraftStore.revision.addListener(_onDraftsChanged);
    _lastCycle = widget.shellApi.chatCycle.value;
    // Relative timestamps ("вчера", "5 мин") go stale without any controller
    // change, so the list still needs a slow heartbeat of its own. It goes
    // through the selector, so a tick that changes nothing costs one query
    // and no rebuild.
    _previewRefresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_convos.refresh()),
    );
    widget.selection?.addListener(_onExternalSelection);
    // If the store already has a pre-set selection (e.g. driven by the
    // Cmd+K spotlight palette before this section mounted), pick it up
    // so the chat thread opens on mount.
    final pre = widget.selection?.selected;
    if (pre != null && _matchesFilter(pre)) {
      _selectedId = pre.convoId;
    }
  }

  @override
  void didUpdateWidget(covariant DesktopChatsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.selection, widget.selection)) {
      oldWidget.selection?.removeListener(_onExternalSelection);
      widget.selection?.addListener(_onExternalSelection);
    }
  }

  /// Listener for [widget.selection] changes initiated by external callers
  /// (e.g. the Cmd+K spotlight palette). Reflects the requested conversation
  /// into [_selectedId] so the chat-thread host opens for the requested chat.
  /// No-op when the store already matches our local selection (prevents
  /// feedback loops when we are the writer).
  void _onExternalSelection() {
    final store = widget.selection;
    if (store == null) return;
    final wanted = store.selected;
    final wantedId = wanted?.convoId;
    if (wantedId == _selectedId) return;
    if (wanted != null && !_matchesFilter(wanted)) {
      // Conversation type doesn't belong to this section's filter (e.g.
      // a group was selected while we are the Chats tab). The shell will
      // have switched sections; we just ignore here.
      return;
    }
    setState(() => _selectedId = wantedId);
  }

  void _onWindowFocusChanged() {
    if (mounted) setState(() {});
  }

  StreamSubscription<void>? _securitySub;

  void _onSecurityChanged() {
    if (!mounted) return;
    final relocked = _personalUnlocked &&
        widget.controller.security.isLocked(SecurityLockScope.personal);
    if (!relocked) {
      setState(() {});
      return;
    }
    setState(() {
      _personalUnlocked = false;
      if (_category == ChatCategoryIds.personal) {
        _category = ChatCategoryIds.all;
      }
    });
  }

  @override
  void dispose() {
    DesktopWindowActivity.focused.removeListener(_onWindowFocusChanged);
    unawaited(_securitySub?.cancel());
    widget.shellApi.chatCycle.removeListener(_onChatCycle);
    DesktopDraftStore.revision.removeListener(_onDraftsChanged);
    _convos.removeListener(_onConversations);
    _convos.dispose();
    _previewRefresh?.cancel();
    widget.selection?.removeListener(_onExternalSelection);
    // Clear selection on section unmount (e.g. switching to Rooms tab while
    // this is Chats). The shell already auto-closes details on tab switch,
    // but clearing here makes sure stale info never flashes if a future
    // detailsBuilder reads the store outside of an open state.
    //
    // 🔴 ПОСЛЕ КАДРА, А НЕ ЗДЕСЬ (16.09.2026, ловушка ошибок в журнале:
    // «setState() or markNeedsBuild() called when widget tree was locked» —
    // шесть раз подряд при переходе из «Чатов» с открытой перепиской).
    // `dispose` идёт, пока дерево снимается и заперто; очистка тут же будит
    // слушателей хранилища — панель подробностей, хлебные крошки, — а те
    // просят перестройку посреди разборки. В отладочной сборке это ошибка,
    // в выпуске — перестройка в неподходящий момент.
    final selection = widget.selection;
    if (selection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => selection.clear());
    }
    super.dispose();
  }

  void _onDraftsChanged() {
    if (mounted) setState(() {});
  }

  /// Last observed cycle value, so a tick's DIRECTION can be recovered from
  /// the difference rather than needing a second signal.
  int _lastCycle = 0;

  /// Moves the selection one chat up or down, within the visible category.
  ///
  /// Clamped rather than wrapping: silently jumping from the last chat to the
  /// first looks like the list lost your place. Stopping at the end is the
  /// behaviour every list in the OS has.
  void _onChatCycle() {
    if (!mounted) return;
    final now = widget.shellApi.chatCycle.value;
    final delta = now - _lastCycle;
    _lastCycle = now;
    if (delta == 0) return;

    final visible = widget.filter == ConversationFilter.groups
        ? _conversations
        : _conversations.where(_matchesCategory).toList(growable: false);
    if (visible.isEmpty) return;

    final current = visible.indexWhere((c) => c.convoId == _selectedId);
    final next = current < 0
        ? 0
        : (current + delta.sign).clamp(0, visible.length - 1);
    final picked = visible[next];
    if (picked.convoId == _selectedId) return;

    setState(() => _selectedId = picked.convoId);
    widget.selection?.select(picked);
  }

  /// Файлы, брошенные на строку списка, — в ту переписку, НЕ открывая её.
  ///
  /// Открывать чат ради броска не нужно: куда он пойдёт, человек уже
  /// показал. Но сразу файл больше не уходит — открывается то же окно
  /// отправки, что и в открытой переписке (подпись, «файлами», группировка),
  /// и в заголовке написано, КУДА уйдёт.
  ///
  /// Цель передаётся явно, а не берётся из открытого чата: бросок не должен
  /// попасть туда, что случайно выделено. Файл, отправленный не тому, не
  /// вернуть.
  Future<void> _dropOntoConversation(
    Conversation convo,
    List<String> paths,
  ) async {
    final limit = widget.controller.effectiveAttachmentMaxBytes;
    final intake = intakeOutgoingPaths(paths, maxBytes: limit);
    final notice = intake.rejectionText(maxBytes: limit);
    if (intake.files.isEmpty) {
      if (notice != null && mounted) {
        DesktopSnackbar.show(
          context,
          message: notice,
          kind: DSnackKind.warning,
        );
      }
      return;
    }
    final outcome = await showSendMediaDialog(
      context,
      files: intake.files,
      maxBytes: limit,
      destinationTitle: convo.title,
      notice: notice,
      onPickMore: () => pickDesktopAttachments(media: false),
    );
    if (outcome is! SendMediaResult || !mounted) return;
    final peer = (convo.peerProfileId ?? '').trim();
    try {
      await enqueueDesktopMediaSend(
        enqueue: widget.controller.enqueueAttachmentBatchUpload,
        result: outcome,
        convoId: convo.convoId,
        peerProfileId: peer.isEmpty ? null : peer,
        sendText: (text, reply) async {
          if (peer.isEmpty) {
            await widget.controller.sendGroupMessage(
              groupId: convo.convoId,
              text: text,
              replyToPayloadEventId: reply,
            );
          } else {
            await widget.controller.sendMessage(
              peerProfileId: peer,
              text: text,
              replyToPayloadEventId: reply,
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Не удалось отправить: $e',
        kind: DSnackKind.error,
      );
      return;
    }
    if (!mounted) return;
    // Подтверждаем, КУДА ушло: после броска на строку иначе непонятно,
    // попал ли он в нужную.
    DesktopSnackbar.show(
      context,
      message: 'Отправляется в «${convo.title}»',
      kind: DSnackKind.success,
    );
  }

  bool _matchesFilter(Conversation c) {
    switch (widget.filter) {
      case ConversationFilter.directs:
        return c.peerProfileId != null;
      case ConversationFilter.groups:
        return c.peerProfileId == null;
      case ConversationFilter.all:
        return true;
    }
  }

  // ---------------------------------------------------------------------
  // Categories (horizontal strip above the list).
  //
  // Replaces the collapsible in-list sections. Everything below reuses the
  // SHARED controller model so desktop and mobile agree on what a folder,
  // an archive and a personal chat are:
  //   • folders   — controller.customChatFolders + folderMemberConvoIds
  //   • archive   — Conversation.archivedAtMs
  //   • personal  — controller.isPersonalChat, gated by SecurityLockScope.personal
  // ---------------------------------------------------------------------

  /// Active category id. Screen-local, exactly like mobile's folder tab.
  String _category = ChatCategoryIds.all;

  /// Есть ли что-то в архиве — по нему решается, рисовать ли кнопку архива в
  /// подвале панели. Считается по тому же списку переписок, что и чип
  /// «Архив» в полосе фильтров, чтобы два входа в одно место не расходились.
  bool get _hasArchivedChats =>
      _conversations.any((c) => c.archivedAtMs != null);

  /// convoId sets per custom folder. There is no reverse lookup in the
  /// controller, so we materialise membership once per folder and refresh it
  /// when the folder set changes.
  final Map<String, Set<String>> _folderMembers = <String, Set<String>>{};
  String _folderSig = '';

  /// Personal chats stay hidden until the security scope is actually
  /// unlocked. This mirrors mobile, where the personal list lives behind
  /// `ensureSecurityScopeUnlocked` — the older desktop surface filtered on
  /// `isPersonalChat` with NO gate at all, which made the password decorative.
  bool _personalUnlocked = false;

  bool get _personalLockEnabled =>
      widget.controller.security.isEnabled(SecurityLockScope.personal);

  /// True while personal chats may be shown.
  bool get _personalVisible => !_personalLockEnabled || _personalUnlocked;

  Future<void> _syncFolders() async {
    final folders = widget.controller.customChatFolders;
    final sig = folders.map((f) => f.id).join('|');
    if (sig == _folderSig) return;
    _folderSig = sig;
    final next = <String, Set<String>>{};
    for (final f in folders) {
      try {
        next[f.id] = (await widget.controller.folderMemberConvoIds(
          f.id,
        )).toSet();
      } catch (_) {
        next[f.id] = <String>{};
      }
    }
    if (!mounted) return;
    setState(() {
      _folderMembers
        ..clear()
        ..addAll(next);
      // A folder can disappear (deleted on this device); never leave the strip
      // pointing at something that no longer exists.
      if (!ChatCategoryIds.isBuiltIn(_category) &&
          !_folderMembers.containsKey(_category)) {
        _category = ChatCategoryIds.all;
      }
    });
  }

  /// Applies the active category. Archive and personal are EXCLUSIVE views:
  /// an archived or personal chat must not leak into "Все", which is the
  /// whole point of putting it away.
  bool _matchesCategory(Conversation c) {
    final archived = c.archivedAtMs != null;
    final personal = widget.controller.isPersonalChat(c.convoId);
    switch (_category) {
      case ChatCategoryIds.archive:
        return archived;
      case ChatCategoryIds.personal:
        return personal && _personalVisible;
      case ChatCategoryIds.unread:
        return !archived && !personal && c.unreadCount > 0;
      case ChatCategoryIds.groups:
        // Комната, группа, канал — по тому же признаку, по которому им
        // достаётся квадратный портрет: отсутствию собеседника.
        return !archived && !personal && c.peerProfileId == null;
      case ChatCategoryIds.all:
        return !archived && !personal;
      default:
        final members = _folderMembers[_category];
        if (members == null) return !archived && !personal;
        return !archived && !personal && members.contains(c.convoId);
    }
  }

  List<ChatCategory> _buildCategories() {
    final convos = _conversations;
    var unread = 0;
    var archiveUnread = 0;
    var personalUnread = 0;
    // 🔴 ФИЛЬТР СЧИТАЕТ РАЗГОВОРЫ, А НЕ СООБЩЕНИЯ (15.09.2026, указание
    // владельца).
    //
    // Складывалась сумма непрочитанных сообщений. «Непрочит. 19» читалось как
    // девятнадцать сообщений, а означать должно было «девятнадцать разговоров
    // ждут ответа» — и это ровно то число, ради которого на фильтр и
    // нажимают: сколько строк покажет список.
    //
    // Сумма сообщений здесь вдобавок врала на порядок: один шумный чат на сто
    // сообщений давал «100» там, где ждёт ровно один разговор.
    for (final c in convos) {
      if (c.unreadCount <= 0) continue;
      final archived = c.archivedAtMs != null;
      final personal = widget.controller.isPersonalChat(c.convoId);
      if (archived) {
        archiveUnread += 1;
      } else if (personal) {
        personalUnread += 1;
      } else {
        unread += 1;
      }
    }
    var groupUnread = 0;
    var hasGroups = false;
    for (final c in convos) {
      if (c.peerProfileId != null) continue;
      if (c.archivedAtMs != null) continue;
      if (widget.controller.isPersonalChat(c.convoId)) continue;
      hasGroups = true;
      if (c.unreadCount > 0) groupUnread += 1;
    }
    final hasArchived = convos.any((c) => c.archivedAtMs != null);
    final hasPersonal = convos.any(
      (c) => widget.controller.isPersonalChat(c.convoId),
    );

    return <ChatCategory>[
      ChatCategory(
        id: ChatCategoryIds.all,
        label: 'Все',
        icon: FluentIcons.chat_24_regular,
      ),
      if (unread > 0)
        ChatCategory(
          id: ChatCategoryIds.unread,
          // Сокращение — решение владельца от 13.09.
          //
          // Замер на живом окне: чип с подписью «Непрочитанные» занимал 131
          // точку из 320, с «Непрочит.» — 106. Двадцать пять точек переводят
          // третий фильтр из «видна четверть» в «видно больше половины».
          // Целиком он всё равно не помещается — четыре фильтра в 320 точек
          // не влезают ни при какой подписи.
          //
          // Ширину панели по умолчанию с тех пор подняли до макетных 322 —
          // двух точек на длинную подпись не хватает, замер в силе.
          //
          // 🔴 Точку в конце не убирать: без неё «Непрочит» читается как
          // опечатка, а не как сокращение.
          //
          // Полоса переживает и длинную подпись — она прокручивается, и
          // выбранный фильтр сам подтягивается в видимую часть
          // (`chat_category_bar.dart`). Это про удобство с первого взгляда,
          // а не про работоспособность.
          label: 'Непрочит.',
          icon: FluentIcons.mail_unread_24_regular,
          badge: unread,
        ),
      // «Группы» стоит сразу после «Непрочитанных» и ДО папок человека:
      // встроенные категории идут вместе, иначе полоса читается как случайный
      // набор. Чипа нет, когда комнат нет вовсе, — фильтр, который всегда
      // отдаёт пустоту, только занимает место.
      if (hasGroups)
        ChatCategory(
          id: ChatCategoryIds.groups,
          label: 'Группы',
          icon: FluentIcons.people_24_regular,
          badge: groupUnread,
        ),
      // ◆ ЧИПА «ЗВОНКИ» ЗДЕСЬ НЕТ, И ЭТО РЕШЕНИЕ, А НЕ ЗАБЫВЧИВОСТЬ
      // (макет design_clean.html:155 — четвёртый чип полосы).
      //
      // Фильтровать было бы нечем, кроме `ChatListPreview.isCall`, а это
      // «ПОСЛЕДНЕЕ событие разговора — звонок». Человек прочтёт подпись как
      // «разговоры, где были звонки», а получит только те, где после звонка
      // никто ничего не написал: одна строка «прости, не успел» — и чат из
      // фильтра пропал. Фильтр, теряющий записи от чужого ответа, хуже
      // отсутствующего.
      //
      // Настоящий журнал звонков в приложении есть, со временем, направлением
      // и кнопкой перезвонить, — это раздел «Звонки» на рейке
      // (`desktop_calls_section.dart`, `CallJournalEntry`). Чип вёл бы в ту же
      // комнату второй дверью, и дверь эта была бы хуже: список чатов про
      // звонок знает одну строку превью.
      //
      // Сам звонок из списка при этом виден: последним событием он рисуется
      // зелёной трубкой и подписью «Входящий звонок · 01:13»
      // (`_previewIcon`), — показывать его список умеет, врать про полноту
      // выборки не станет.
      for (final f in widget.controller.customChatFolders)
        ChatCategory(id: f.id, label: f.name, emoji: f.emoji),
      // Archive and Personal live at the END of the strip: they are places
      // you go deliberately, not views you flick between.
      if (hasArchived)
        ChatCategory(
          id: ChatCategoryIds.archive,
          label: 'Архив',
          icon: FluentIcons.archive_24_regular,
          badge: archiveUnread,
        ),
      if (hasPersonal || _personalLockEnabled)
        ChatCategory(
          id: ChatCategoryIds.personal,
          label: 'Личные',
          icon: FluentIcons.lock_closed_24_regular,
          // Only count what the user is allowed to see; a badge on a locked
          // category would leak how much is hidden behind the password.
          badge: _personalVisible ? personalUnread : 0,
          locked: _personalLockEnabled && !_personalUnlocked,
        ),
    ];
  }

  /// Switching category. Personal asks for the password first.
  Future<void> _selectCategory(String id) async {
    if (id == ChatCategoryIds.personal &&
        _personalLockEnabled &&
        !_personalUnlocked) {
      final ok = await ensureSecurityScopeUnlocked(
        context: context,
        controller: widget.controller,
        scope: SecurityLockScope.personal,
        forcePrompt: true,
      );
      if (!mounted) return;
      if (!ok) return; // stay where we are; the list never flashes open
      setState(() {
        _personalUnlocked = true;
        _category = id;
      });
      return;
    }
    // Leaving the personal category re-locks it, matching mobile's
    // "lock on exit" convention — an unlocked scope must not outlive the view.
    if (_category == ChatCategoryIds.personal &&
        id != ChatCategoryIds.personal &&
        _personalLockEnabled) {
      _personalUnlocked = false;
      unawaited(widget.controller.security.lockNow(SecurityLockScope.personal));
    }
    if (!mounted) return;
    setState(() => _category = id);
  }

  /// Right-click on a folder chip: rename or delete. Built-in categories have
  /// nothing to manage, so they get no menu at all (P-5).
  Future<void> _folderChipMenu(ChatCategory cat, Offset at) async {
    if (ChatCategoryIds.isBuiltIn(cat.id)) return;
    await ContextMenu.show(
      context,
      globalPosition: at,
      sections: [
        [
          CtxMenuItem(
            label: 'Переименовать папку',
            icon: FluentIcons.edit_24_regular,
            onTap: () => unawaited(_renameFolder(cat)),
          ),
          CtxMenuItem(
            label: 'Удалить папку',
            icon: FluentIcons.delete_24_regular,
            isDanger: true,
            onTap: () => unawaited(_deleteFolder(cat)),
          ),
        ],
      ],
    );
  }

  Future<void> _renameFolder(ChatCategory cat) async {
    final name = await _promptFolderName(initial: cat.label);
    if (name == null || !mounted) return;
    try {
      // updateChatFolder REPLACES membership, so the current members must be
      // passed back or a rename would silently empty the folder.
      final members =
          _folderMembers[cat.id]?.toList() ??
          await widget.controller.folderMemberConvoIds(cat.id);
      await widget.controller.updateChatFolder(
        id: cat.id,
        name: name,
        emoji: cat.emoji,
        convoIds: members,
      );
      _folderSig = ''; // force a membership refresh
      await _syncFolders();
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Не удалось переименовать: $e',
        kind: DSnackKind.error,
      );
    }
  }

  Future<void> _deleteFolder(ChatCategory cat) async {
    final ok = await DesktopDialog.show<bool>(
      context,
      title: 'Удалить папку «${cat.label}»?',
      size: DDialogSize.small,
      body: Text(
        'Чаты останутся на месте — удалится только папка.',
        style: DType.body.copyWith(color: DColors.of(context).textSecondary),
      ),
      primary: DDialogAction(
        label: 'Удалить',
        kind: DButtonKind.danger,
        onPressed: () => Navigator.of(context).maybePop(true),
      ),
      secondary: DDialogAction(
        label: 'Отмена',
        onPressed: () => Navigator.of(context).maybePop(false),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.controller.deleteChatFolder(cat.id);
      if (!mounted) return;
      setState(() {
        _folderMembers.remove(cat.id);
        if (_category == cat.id) _category = ChatCategoryIds.all;
      });
      _folderSig = '';
      await _syncFolders();
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Не удалось удалить: $e',
        kind: DSnackKind.error,
      );
    }
  }

  /// Adds or removes a single chat from a folder. Read-modify-write, because
  /// the controller exposes no per-chat primitive.
  Future<void> _toggleChatInFolder(String convoId, ChatFolder folder) async {
    try {
      final members =
          (_folderMembers[folder.id] ??
                  (await widget.controller.folderMemberConvoIds(
                    folder.id,
                  )).toSet())
              .toSet();
      final adding = !members.contains(convoId);
      adding ? members.add(convoId) : members.remove(convoId);
      await widget.controller.updateChatFolder(
        id: folder.id,
        name: folder.name,
        emoji: folder.emoji,
        convoIds: members.toList(),
      );
      if (!mounted) return;
      setState(() => _folderMembers[folder.id] = members);
      DesktopSnackbar.show(
        context,
        message: adding
            ? 'Добавлено в «${folder.name}»'
            : 'Убрано из «${folder.name}»',
        kind: DSnackKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Не удалось изменить папку: $e',
        kind: DSnackKind.error,
      );
    }
  }

  Future<void> _createFolderWith(String convoId) async {
    final name = await _promptFolderName();
    if (name == null || !mounted) return;
    try {
      await widget.controller.createChatFolder(
        name: name,
        convoIds: <String>[convoId],
      );
      _folderSig = '';
      await _syncFolders();
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Папка «$name» создана',
        kind: DSnackKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Не удалось создать папку: $e',
        kind: DSnackKind.error,
      );
    }
  }

  Future<String?> _promptFolderName({String? initial}) async {
    final ctl = TextEditingController(text: initial ?? '');
    final result = await DesktopDialog.show<String>(
      context,
      title: initial == null ? 'Новая папка' : 'Переименовать папку',
      size: DDialogSize.small,
      body: DesktopTextField(
        controller: ctl,
        hintText: 'Название папки',
        autofocus: true,
        onSubmitted: (v) => Navigator.of(context).maybePop(v.trim()),
      ),
      primary: DDialogAction(
        label: 'Сохранить',
        onPressed: () => Navigator.of(context).maybePop(ctl.text.trim()),
      ),
      secondary: DDialogAction(
        label: 'Отмена',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
    ctl.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  /// Extra rows appended to a chat's right-click menu: folder membership and
  /// the two "put it away" destinations. Built per chat so the checkmarks
  /// reflect where that chat actually lives.
  List<List<CtxMenuItem>> _chatFolderActions(String convoId) {
    final folders = widget.controller.customChatFolders;
    final isPersonal = widget.controller.isPersonalChat(convoId);
    return <List<CtxMenuItem>>[
      <CtxMenuItem>[
        for (final f in folders)
          CtxMenuItem(
            label: (_folderMembers[f.id]?.contains(convoId) ?? false)
                ? 'Убрать из «${f.name}»'
                : 'В папку «${f.name}»',
            icon: FluentIcons.folder_24_regular,
            onTap: () => unawaited(_toggleChatInFolder(convoId, f)),
          ),
        CtxMenuItem(
          label: 'Новая папка с этим чатом…',
          icon: FluentIcons.folder_add_24_regular,
          onTap: () => unawaited(_createFolderWith(convoId)),
        ),
      ],
      <CtxMenuItem>[
        // 🔴 Архива здесь БОЛЬШЕ НЕТ, и это исправление, а не упрощение.
        //
        // Было два пункта «В архив» в одном меню — этот и тот, что идёт выше
        // вместе с закреплением и беззвучным режимом. Одинаковые подписи, но
        // РАЗНЫЕ обработчики: один снимал признак «личное», другой закрывал
        // открытый чат. Что именно произойдёт, зависело от того, в какую из
        // двух одинаковых строк человек попал.
        //
        // Теперь архив живёт в одном месте (`_toggleArchived`) и делает оба
        // дела сразу. «В личные» остаётся здесь: это другое место назначения,
        // и путать их не с чем.
        CtxMenuItem(
          label: isPersonal ? 'Убрать из личных' : 'В личные',
          icon: FluentIcons.lock_closed_24_regular,
          onTap: () => unawaited(_setPersonal(convoId, !isPersonal)),
        ),
      ],
    ];
  }

  Future<void> _setPersonal(String convoId, bool personal) async {
    try {
      await widget.controller.setChatPersonal(
        convoId: convoId,
        personal: personal,
      );
      if (personal) {
        // Moving into Personal must clear Archive, or the chat would vanish
        // from both views at once.
        await widget.controller.setChatArchived(
          convoId: convoId,
          archived: false,
        );
      }
      await _convos.refresh();
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Не удалось: $e',
        kind: DSnackKind.error,
      );
    }
  }

  String? _emptyCategoryText() {
    switch (_category) {
      case ChatCategoryIds.archive:
        return 'В архиве пусто';
      case ChatCategoryIds.personal:
        return _personalVisible
            ? 'Личных чатов нет'
            : 'Личные чаты защищены паролем';
      case ChatCategoryIds.unread:
        return 'Всё прочитано';
      case ChatCategoryIds.all:
        return null;
      default:
        return 'В этой папке пока пусто';
    }
  }

  /// Loads the conversations for this section and their previews.
  ///
  /// Throwing is fine and deliberate: [DesktopSelector] keeps the last good
  /// value on a failed load, which is what the old `catch` did by hand — the
  /// local database can be locked or mid-migration, and blanking the list over
  /// a transient read is worse than showing what we had.
  /// Комнаты, в которых ПРЯМО СЕЙЧАС идёт созвон, и сколько человек внутри.
  ///
  /// 🔴 Один запрос на всю ленту, а не по запросу на строку: активных созвонов
  /// в норме ноль или один, а строк в списке бывают сотни.
  Map<String, int> _activeCalls = const <String, int>{};

  /// С кем сверены коды безопасности. Галочка у имени висит на ЭТОМ, а не на
  /// оплаченной подписке — см. `chat_list_panel.dart`.
  ///
  /// Читается один раз на собеседника и запоминается: запись в базе меняется
  /// только руками человека на экране сверки.
  final Map<String, bool> _verifiedByProfile = <String, bool>{};

  Future<List<Conversation>> _loadConversations() async {
    try {
      final calls = await widget.controller.listCachedActiveRoomCalls();
      _activeCalls = <String, int>{
        for (final call in calls)
          call.roomId: call.joinedParticipantCount,
      };
    } catch (_) {
      _activeCalls = const <String, int>{};
    }
    final all = await widget.controller.listConversations();
    for (final c in all) {
      final pid = (c.peerProfileId ?? '').trim();
      if (pid.isEmpty || _verifiedByProfile.containsKey(pid)) continue;
      try {
        _verifiedByProfile[pid] = await widget.controller
            .contactWasEverVerified(pid);
      } catch (_) {
        _verifiedByProfile[pid] = false;
      }
    }
    final convos = all
        .where(_matchesFilter)
        // A chat deleted HERE must not come back just because the boot-time
        // history sync re-materialised its row — see [DesktopDeletedChats].
        // Anything genuinely newer than the deletion passes and clears the
        // tombstone, so a fresh message always brings the chat back.
        .where(
          (c) => !DesktopDeletedChats.isSuppressed(
            convoId: c.convoId,
            lastEventAtMs: c.lastEventAtMs,
          ),
        )
        .toList(growable: false);
    await Future.wait<void>(<Future<void>>[
      for (final c in convos) _refreshPreview(c.convoId),
    ]);
    return convos;
  }

  /// A row's rendered appearance, reduced to a string.
  ///
  /// Built from [_toItem] — the one function that turns a [Conversation] into
  /// what the list actually draws — so the signature cannot drift away from
  /// the view the way a hand-picked list of `Conversation` fields would. Add a
  /// field to [ChatListItem] and render it, and it belongs here too.
  ///
  /// The category strip reads things a row does not — `isPersonalChat` per
  /// conversation and the set of custom folders — so those ride along. The
  /// folder set especially: a folder created on the phone changes no row at
  /// all, and without it here the strip would never learn about it.
  String _chatListSignature(List<Conversation> convos) {
    final buffer = StringBuffer()
      ..write(convos.length)
      ..write('\u001e')
      ..write(widget.controller.customChatFolders.map((f) => f.id).join('|'));
    for (final c in convos) {
      final item = _toItem(c);
      buffer
        // Unit separator: cannot occur inside an id or a preview.
        ..write('\u001f')
        ..write(item.id)
        ..write(item.name)
        ..write(item.preview)
        ..write(item.time)
        ..write(item.unread)
        ..write(item.kind.index)
        ..write(item.online)
        ..write(item.muted)
        ..write(item.verified)
        ..write(item.pinned)
        ..write(item.archived)
        ..write(item.typing)
        ..write(item.draft)
        ..write(item.previewAuthor ?? '')
        ..write(item.mention)
        ..write(item.avatarPath ?? '')
        ..write(item.frameId ?? '')
        ..write(item.emojiStatus ?? '')
        ..write(item.premiumBadge)
        // Идущий созвон меняет саму строку — без него в подписи список не
        // перерисовался бы, пока в комнате не напишут.
        ..write(item.roomCall?.participants ?? -1)
        ..write(item.previewIcon.index)
        ..write(item.previewIsMine)
        // Category strip inputs.
        ..write(widget.controller.isPersonalChat(c.convoId));
    }
    return buffer.toString();
  }

  /// Reflects a republished list into the widget tree.
  void _onConversations() {
    if (!mounted) return;
    final convos = _convos.value;
    setState(() {
      _conversations = convos;
      // Folder membership is refreshed off the same load that brings the
      // conversations, so a folder created on this device shows up without a
      // manual refresh.
      unawaited(_syncFolders());
    });
    _republishSelection(convos);
  }

  /// Re-publish the currently-selected Conversation to the [selection] store
  /// after a reload, so the right-column details panel picks up presence /
  /// unread / mute changes for the open chat. If the selected chat has been
  /// removed (e.g. archived out of the filter), clears the selection so the
  /// details panel returns to its empty state.
  void _republishSelection(List<Conversation> convos) {
    final store = widget.selection;
    if (store == null) return;
    final id = _selectedId;
    if (id == null) return;
    Conversation? match;
    for (final c in convos) {
      if (c.convoId == id) {
        match = c;
        break;
      }
    }
    if (match == null) {
      _selectedId = null;
      store.clear();
    } else {
      store.refresh(match);
    }
  }

  Future<void> _refreshPreview(String convoId) async {
    try {
      final p = await widget.controller.lastMessagePreviewRich(convoId);
      _previews[convoId] = p;
    } catch (_) {
      // ignore — preview falls back to ''
    }
  }

  // ── Кнопки шапки списка ──────────────────────────────────────────────────

  /// Меню кнопки «Создать».
  ///
  /// 🔴 Комнату заводит МОБИЛЬНЫЙ экран, подключённый целиком и без правок.
  /// Это многошаговая форма — название, участники, автоудаление, — и вторая
  /// её реализация под десктоп разошлась бы с первой на первой же правке.
  /// Тем же приёмом здесь уже открывается экран созвона комнаты.
  void _composeMenu(Offset at) {
    ContextMenu.show(
      context,
      globalPosition: at,
      sections: [
        [
          CtxMenuItem(
            label: 'Новый чат',
            icon: FluentIcons.person_add_24_regular,
            onTap: () => unawaited(_startNewChat()),
          ),
          CtxMenuItem(
            label: 'Новая комната',
            icon: FluentIcons.people_add_24_regular,
            onTap: _startNewRoom,
          ),
          CtxMenuItem(
            label: AppLocalizations.of(context)!.desktopJoinRoomByLink,
            icon: FluentIcons.link_24_regular,
            onTap: () => unawaited(_joinRoomByLink()),
          ),
        ],
      ],
    );
  }

  Future<void> _startNewChat() async {
    final profileId = await showNewChatPicker(
      context,
      // Окно получает готовый список: контроллер живёт здесь, а не в нём,
      // чтобы шов «десктоп ↔ приложение» остался одним.
      loadContacts: () async {
        final contacts = await widget.controller.listContacts();
        return <NewChatCandidate>[
          for (final c in contacts)
            NewChatCandidate(
              profileId: c.profileId,
              name: (c.displayName ?? '').trim().isEmpty
                  ? c.profileId
                  : c.displayName!.trim(),
              avatarPath: c.avatarPath,
            ),
        ];
      },
    );
    if (profileId == null || profileId.isEmpty || !mounted) return;
    String? convoId;
    try {
      // Тот же путь, которым чат открывается из раздела «Контакты»: заводит
      // переписку, если её ещё нет, и возвращает её идентификатор.
      convoId = await widget.controller.prepareSharedProfileConversation(
        profileId,
      );
    } catch (_) {
      convoId = null;
    }
    if (!mounted) return;

    // 🔴 Отказ ОБЯЗАН быть слышен.
    //
    // `prepareSharedProfileConversation` возвращает null, когда профиля нет на
    // сервере ключей или переписку не удалось подготовить к отправке. Молчание
    // в этом месте — худший из возможных ответов: человек выбрал собеседника,
    // окно закрылось, и НИЧЕГО не произошло. Он повторит выбор, решит, что
    // сломано приложение, и будет прав — сломано именно сообщение о причине.
    if (convoId == null || convoId.isEmpty) {
      DesktopSnackbar.show(
        context,
        message: 'Не удалось начать чат: профиль недоступен',
        kind: DSnackKind.error,
      );
      return;
    }

    await _convos.refresh();
    if (!mounted) return;
    setState(() => _selectedId = convoId);
  }

  /// 🔴 ВХОД В КОМНАТУ ПО ССЫЛКЕ (17.09.2026). На телефоне ссылка открывает
  /// экран входа с проверкой и понятными отказами, а на компьютере она была
  /// тупиком: приглашение уходило во внешний браузер, и человек возвращался
  /// ни с чем. Разбор ссылки и сам экран — общие с телефоном; здесь только
  /// окно для вставки и открытие комнаты в панели вместо мобильного экрана.
  Future<void> _joinRoomByLink() async {
    final l10n = AppLocalizations.of(context)!;
    final ctl = TextEditingController();
    final raw = await DesktopDialog.show<String>(
      context,
      title: l10n.desktopJoinRoomByLink,
      size: DDialogSize.small,
      body: DesktopTextField(
        controller: ctl,
        hintText: l10n.desktopJoinRoomLinkHint,
        autofocus: true,
        onSubmitted: (v) => Navigator.of(context).maybePop(v.trim()),
      ),
      primary: DDialogAction(
        label: l10n.continueAction,
        onPressed: () => Navigator.of(context).maybePop(ctl.text.trim()),
      ),
      secondary: DDialogAction(
        label: l10n.cancel,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
    ctl.dispose();
    if (!mounted) return;
    final text = (raw ?? '').trim();
    if (text.isEmpty) return;
    final uri = Uri.tryParse(text);
    final target = uri == null ? null : tryParseRoomInviteUri(uri);
    if (target == null) {
      DesktopSnackbar.show(
        context,
        message: l10n.desktopJoinRoomLinkInvalid,
        kind: DSnackKind.error,
      );
      return;
    }
    await openRoomInvite(target);
  }

  /// Открывает экран входа в комнату (он же на телефоне) и, если вход удался,
  /// показывает комнату в панели. Зовётся и из меню, и по ссылке от системы.
  Future<void> openRoomInvite(RoomInviteTarget target) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomInviteJoinScreen(
          controller: widget.controller,
          target: target,
          onJoined: (groupId) async {
            await _convos.refresh();
            if (!mounted) return;
            setState(() => _selectedId = groupId);
          },
        ),
      ),
    );
  }

  void _startNewRoom() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NewGroupScreen(controller: widget.controller),
      ),
    );
  }

  /// Меню кнопки «Папки».
  ///
  /// Папки работали и раньше, но попасть в них можно было только правым
  /// щелчком по строке чата или по чипу — то есть никак, если не знать
  /// заранее. Меню не добавляет возможностей, оно перестаёт их прятать.
  void _filtersMenu(Offset at) {
    final folders = widget.controller.customChatFolders;
    ContextMenu.show(
      context,
      globalPosition: at,
      sections: [
        [
          CtxMenuItem(
            label: 'Новая папка',
            icon: FluentIcons.folder_add_24_regular,
            onTap: () => unawaited(_createEmptyFolder()),
          ),
        ],
        if (folders.isNotEmpty)
          [
            for (final f in folders)
              CtxMenuItem(
                label: f.name,
                icon: FluentIcons.folder_24_regular,
                onTap: () => unawaited(_selectCategory(f.id)),
              ),
          ],
      ],
    );
  }

  Future<void> _createEmptyFolder() async {
    final name = await _promptFolderName();
    if (name == null || !mounted) return;
    try {
      await widget.controller.createChatFolder(name: name, convoIds: const []);
      // Та же подготовка, что у «Новой папки с этим чатом»: без сброса подписи
      // список папок считает, что ничего не изменилось.
      _folderSig = '';
      await _syncFolders();
      if (!mounted) return;
      setState(() {});
      DesktopSnackbar.show(
        context,
        message: 'Папка «$name» создана',
        kind: DSnackKind.success,
      );
    } catch (_) {
      // Молча: список папок перечитается на следующем тике.
    }
  }

  ChatListItem _toItem(Conversation c) {
    final preview = _previews[c.convoId];
    final previewText = _previewText(preview);
    return ChatListItem(
      id: c.convoId,
      // Ключ оттенка — тот же, что у телефона: у человека профиль, у комнаты
      // сама комната. По имени считать нельзя: переименование меняло бы цвет
      // только на компьютере.
      seed: c.peerProfileId ?? c.convoId,
      name: c.title.isEmpty ? '—' : c.title,
      preview: previewText,
      time: _formatTime(c.lastEventAtMs),
      unread: c.unreadCount,
      kind: c.peerProfileId == null ? ChatKind.group : ChatKind.direct,
      online: c.isOnline,
      muted: c.muted,
      pinned: c.pinnedAtMs != null,
      archived: c.archivedAtMs != null,
      previewAuthor: _previewAuthorLabel(preview),
      previewAuthorSeed: preview?.senderDeviceId,
      avatarPath: c.avatarPath,
      typing: widget.controller.isConversationTyping(c.convoId),
      // Field existed and was never set — a chat with an unfinished message
      // looked identical to one without.
      draft: DesktopDraftStore.has(c.convoId),
      draftText: DesktopDraftStore.get(c.convoId),
      frameId: c.frameId,
      emojiStatus: c.emojiStatus,
      premiumBadge: c.premiumBadge,
      verified: _verifiedByProfile[(c.peerProfileId ?? '').trim()] ?? false,
      timestampMs: c.lastEventAtMs,
      roomCall: _activeCalls[c.convoId] == null
          ? null
          : RoomCallHint(participants: _activeCalls[c.convoId]!),
      previewIcon: _previewIcon(preview),
      // Своё сообщение узнаём по устройству отправителя. Общая с телефоном
      // подпись автора для личной переписки возвращает null — и правильно
      // делает; сравнение здесь ничего общего не трогает.
      previewIsMine:
          preview?.senderDeviceId != null &&
          preview!.senderDeviceId == widget.controller.deviceId,
      delivery: _deliveryForRow(preview, unread: c.unreadCount),
      // 🔴 Признак СУЩЕСТВОВАЛ И НИКОГДА НЕ СТАВИЛСЯ: плашка «@» в строке была
      // написана, но `mention:` не присваивался нигде — значит показать её не
      // мог ни один чат. Считает его теперь склад превью (`mentionsSelf`),
      // который payload и так расшифровывает.
      mention: preview?.mentionsSelf ?? false,
    );
  }

  /// Автор превью комнаты.
  ///
  /// 🔴 СВОЁ СООБЩЕНИЕ С ДРУГОГО СВОЕГО УСТРОЙСТВА ПОДПИСЫВАЛОСЬ «ИЗБРАННОЕ»
  /// (16.09.2026, найдено вживую). Общий склад превью отвечает «Вы» только для
  /// ЭТОГО устройства, а для телефона того же человека находит контакт-себя —
  /// и берёт его имя, то есть название чата с самим собой. Общий код не
  /// трогаем (телефон выпущен), поправляем подпись здесь: любое своё
  /// устройство — это «Вы», как и в самой ленте (`isOwnDeviceId`).
  String? _previewAuthorLabel(ChatListPreview? p) {
    final name = p?.senderName;
    final deviceId = p?.senderDeviceId;
    if (name == null || deviceId == null) return name;
    return widget.controller.isOwnDeviceId(deviceId) ? _kSelfAuthorRu : name;
  }

  /// Знак доставки для СТРОКИ списка.
  ///
  /// 🔴 Три правила, и все три из смысла строки, а не из макета:
  ///
  /// * знак рисуется только у СВОЕГО последнего сообщения — чужое доставлять
  ///   нам некуда;
  /// * при непрочитанном знака нет: непрочитанное значит, что последним писал
  ///   не ты, и два знака справа спорили бы за одно место;
  /// * «отправляется», «по расписанию» и «не ушло» в строке не показываются.
  ///   Строка — это анонс, а сделать с невышедшим сообщением что-то можно
  ///   только внутри чата, где эти состояния и показаны.
  ChatDelivery _deliveryForRow(ChatListPreview? p, {required int unread}) {
    if (p == null || unread > 0) return ChatDelivery.none;
    final mine =
        p.senderDeviceId != null &&
        p.senderDeviceId == widget.controller.deviceId;
    if (!mine) return ChatDelivery.none;
    switch (deliveryStatusFor(p.senderLocalState ?? '', isSelf: true)) {
      case DeliveryStatus.read:
        return ChatDelivery.read;
      case DeliveryStatus.delivered:
        return ChatDelivery.delivered;
      case DeliveryStatus.sent:
        return ChatDelivery.sent;
      case DeliveryStatus.sending:
      case DeliveryStatus.scheduled:
      case DeliveryStatus.failed:
        return ChatDelivery.none;
    }
  }

  /// Текст превью БЕЗ эмодзи: вид вложения теперь показывает значок строки.
  ///
  /// 🔴 Эмодзи был частью текста — попадал в обрезку по ширине и в поиск по
  /// превью, светился на тёмном фоне и выбивался кеглем. Значок в цвете
  /// подписи ведёт себя как оформление, которым и является; см.
  /// `ChatPreviewIcon` в панели списка.
  String _previewText(ChatListPreview? p) {
    if (p == null) return '';
    final text = p.text?.trim() ?? '';
    switch (p.kind) {
      case ChatListPreviewKind.empty:
        return '';
      case ChatListPreviewKind.text:
        return text;
      case ChatListPreviewKind.photo:
        return text.isNotEmpty ? text : 'Фото';
      case ChatListPreviewKind.music:
        return text.isNotEmpty ? text : 'Аудио';
      case ChatListPreviewKind.voice:
        return text.isNotEmpty ? text : 'Голосовое сообщение';
      case ChatListPreviewKind.file:
        return text.isNotEmpty ? text : 'Файл';
      case ChatListPreviewKind.link:
        return text.isNotEmpty ? text : 'Ссылка';
    }
  }

  static ChatPreviewIcon _previewIcon(ChatListPreview? p) {
    if (p == null) return ChatPreviewIcon.none;
    // Звонок проверяем ПЕРВЫМ: по виду превью он неотличим от текста — там и
    // лежит готовая подпись «Входящий звонок · 01:13».
    if (p.isCall) return ChatPreviewIcon.call;
    switch (p.kind) {
      case ChatListPreviewKind.empty:
      case ChatListPreviewKind.text:
        return ChatPreviewIcon.none;
      case ChatListPreviewKind.photo:
        return ChatPreviewIcon.photo;
      case ChatListPreviewKind.music:
        return ChatPreviewIcon.music;
      case ChatListPreviewKind.voice:
        return ChatPreviewIcon.voice;
      case ChatListPreviewKind.file:
        return ChatPreviewIcon.file;
      case ChatListPreviewKind.link:
        return ChatPreviewIcon.link;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Chat-list context-menu actions. Each looks up the Conversation by id,
  // calls the corresponding AppController method, then refreshes (the
  // controller fires `changed` which our debounced reload already listens to,
  // so explicit reload is only needed when the change isn't observable
  // through `changed` — currently all of these do fire it).
  // ─────────────────────────────────────────────────────────────────────────

  Conversation? _findById(String id) {
    for (final c in _conversations) {
      if (c.convoId == id) return c;
    }
    return null;
  }

  /// Меню открытого чата из шапки переписки.
  ///
  /// 🔴 Те же действия, что по правому щелчку в списке, и намеренно те же
  /// обработчики — не копия. Раньше, чтобы отключить звук у ОТКРЫТОГО чата,
  /// надо было вернуться к его строке в списке и щёлкнуть правой кнопкой: уйти
  /// оттуда, где сейчас читаешь, ради действия над тем, что перед глазами.
  void _chatHeaderMenu(String convoId, Offset at) {
    Conversation? convo;
    for (final c in _conversations) {
      if (c.convoId == convoId) {
        convo = c;
        break;
      }
    }
    if (convo == null) return;
    final pinned = convo.pinnedAtMs != null;
    final muted = convo.muted;
    final archived = convo.archivedAtMs != null;
    final unread = convo.unreadCount > 0;

    ContextMenu.show(
      context,
      globalPosition: at,
      sections: [
        [
          // То же действие и то же слово, что в меню строки списка: два имени
          // у одного действия — это два действия в голове человека.
          CtxMenuItem(
            label: pinned ? 'Убрать из избранного' : 'В избранное',
            icon: pinned
                ? FluentIcons.star_off_24_regular
                : FluentIcons.star_24_regular,
            onTap: () => unawaited(_togglePinned(convoId)),
          ),
          CtxMenuItem(
            label: muted ? 'Включить звук' : 'Без звука',
            icon: muted
                ? FluentIcons.alert_24_regular
                : FluentIcons.alert_off_24_regular,
            onTap: () => unawaited(_toggleMuted(convoId)),
          ),
          CtxMenuItem(
            label: 'Отметить прочитанным',
            icon: FluentIcons.checkmark_circle_24_regular,
            enabled: unread,
            onTap: () => unawaited(_markRead(convoId)),
          ),
          CtxMenuItem(
            label: archived ? 'Из архива' : 'В архив',
            icon: archived
                ? FluentIcons.archive_arrow_back_24_regular
                : FluentIcons.archive_24_regular,
            onTap: () => unawaited(_toggleArchived(convoId)),
          ),
        ],
        ..._chatFolderActions(convoId),
        [
          CtxMenuItem(
            label: 'Очистить историю',
            icon: FluentIcons.broom_24_regular,
            isDanger: true,
            onTap: () => unawaited(_clearHistory(convoId)),
          ),
          CtxMenuItem(
            label: 'Удалить',
            icon: FluentIcons.delete_24_regular,
            isDanger: true,
            onTap: () => unawaited(_deleteChat(convoId)),
          ),
        ],
      ],
    );
  }

  Future<void> _togglePinned(String id) async {
    final c = _findById(id);
    if (c == null) return;
    final next = c.pinnedAtMs == null;
    try {
      await widget.controller.setChatPinned(convoId: id, pinned: next);
    } catch (e) {
      _toast('Не удалось: $e', danger: true);
    }
  }

  Future<void> _toggleMuted(String id) async {
    final c = _findById(id);
    if (c == null) return;
    final next = !c.muted;
    try {
      await widget.controller.setChatMuted(convoId: id, muted: next);
    } catch (e) {
      _toast('Не удалось: $e', danger: true);
    }
  }

  /// Единственный путь в архив и обратно.
  ///
  /// 🔴 Делает ОБА дела, которые раньше были разнесены по двум одинаково
  /// подписанным пунктам меню: снимает признак «личное» (архив и личные —
  /// взаимоисключающие места, телефон обеспечивает это порядком вызовов) и
  /// закрывает переписку, если убрали в архив именно открытую, — иначе человек
  /// продолжает смотреть в чат, которого больше нет в списке.
  Future<void> _toggleArchived(String id) async {
    final c = _findById(id);
    if (c == null) return;
    final next = c.archivedAtMs == null;
    try {
      await widget.controller.setChatArchived(convoId: id, archived: next);
      if (next) {
        await widget.controller.setChatPersonal(convoId: id, personal: false);
      }
      // 🔴 ПОСЛЕ `await` РАЗДЕЛ МОЖЕТ БЫТЬ УЖЕ СНЯТ С ДЕРЕВА. Запись в базу
      // занимает время, а человек за это время успевает уйти на другой раздел
      // рейки — и `setState` у снятого состояния бросает исключение. Видно
      // это не было бы никак: ошибка в асинхронном коде Flutter не показывает
      // себя ничем, кроме несработавшего действия.
      if (!mounted) return;
      if (next && _selectedId == id) {
        setState(() => _selectedId = null);
        widget.selection?.clear();
      }
      await _convos.refresh();
    } catch (e) {
      _toast('Не удалось: $e', danger: true);
    }
  }

  Future<void> _markRead(String id) async {
    final c = _findById(id);
    if (c == null) return;
    // This used to refuse for rooms and tell the user to open the room
    // instead — advice that did not work either, because opening a room did
    // not mark it read on desktop. Both halves are fixed; the shared resolver
    // addresses a room by its `group:` convo id, exactly as mobile does.
    final target = resolveChatMarkReadPeerProfileId(
      convoId: c.convoId,
      peerProfileIdForSend: c.peerProfileId,
    );
    if (target == null || target.isEmpty) return;
    try {
      await widget.controller.markChatRead(peerProfileId: target);
      // Don't wait out the debounce for something the user just asked for.
      await _convos.refresh();
    } catch (e) {
      _toast('Не удалось: $e', danger: true);
    }
  }

  /// Peer whose history can also be cleared from here, or null when the option
  /// does not apply.
  ///
  /// Offered for 1:1 chats only. A room's "clear for everyone" is an ADMIN
  /// action that wipes history for every member — putting that behind a
  /// checkbox in a routine delete dialog is how someone destroys a room's
  /// history by muscle memory. Rooms keep the local-only path; the room's own
  /// settings are the place for that decision.
  String? _clearForPeerTarget(Conversation c) {
    final peer = (c.peerProfileId ?? '').trim();
    if (peer.isEmpty) return null;
    final myPid = widget.controller.profileId.trim();
    // The saved-messages chat is a conversation with oneself: there is no
    // "other side" to clear.
    if (myPid.isNotEmpty && peer == myPid) return null;
    return peer;
  }

  Future<void> _clearHistory(String id) async {
    final c = _findById(id);
    if (c == null) return;
    final title = c.title.isEmpty ? '—' : c.title;
    final peer = _clearForPeerTarget(c);
    final result = await confirmClearWithPeer(
      context,
      title: 'Очистить историю?',
      body: 'Все сообщения чата «$title» на этом устройстве будут удалены.',
      okLabel: 'Очистить',
      peerTitle: peer == null ? null : title,
    );
    if (result == null) return;
    try {
      if (result.alsoForPeer && peer != null) {
        await widget.controller.clearChatHistoryEverywhere(
          convoId: id,
          directPeerProfileId: peer,
        );
        _toast('История очищена у обоих');
      } else {
        await widget.controller.clearChatHistory(convoId: id);
        _toast('История очищена');
      }
      await _convos.refresh();
    } catch (e) {
      _toast('Не удалось: $e', danger: true);
    }
  }

  Future<void> _deleteChat(String id) async {
    final c = _findById(id);
    if (c == null) return;
    final title = c.title.isEmpty ? '—' : c.title;
    final peer = _clearForPeerTarget(c);
    final result = await confirmClearWithPeer(
      context,
      title: 'Удалить чат?',
      body: 'Чат «$title» полностью удалится с этого устройства.',
      okLabel: 'Удалить',
      peerTitle: peer == null ? null : title,
    );
    if (result == null) return;
    try {
      // Clear first, delete second: clearing sends the tombstone that the peer
      // and the user's other devices act on, and it needs the conversation to
      // still exist locally to compute its cutoff.
      if (result.alsoForPeer && peer != null) {
        await widget.controller.clearChatHistoryEverywhere(
          convoId: id,
          directPeerProfileId: peer,
        );
      } else {
        // 🔴 УДАЛИЛ — ЗНАЧИТ УДАЛИЛ, А НЕ СПРЯТАЛ (жалоба владельца
        // 16.09.2026: «удаление должно реально удалить, а не просто исчезнуть,
        // а потом внезапно взяться откуда-то после синхронизации»).
        //
        // Удаление стирало строки здесь и молчало. Но при следующем запуске
        // окно просит у телефона окно недавней переписки, и приёмник чанка
        // кладёт события обратно: сам чат в списке прячет метка сноса
        // (`DesktopDeletedChats`), а СООБЩЕНИЯ возвращаются в базу — их видно
        // в поиске, в галерее, и они всплывут целиком, стоит собеседнику
        // написать одну строку.
        //
        // Отсечка очистки — это и есть то место, где приёмник уже умеет
        // отказывать (`_shouldDropConversationEventByClearCutoff`). Ставим её
        // перед сносом: всё, что было, назад не поедет, а новое — поедет.
        await widget.controller.clearChatHistory(convoId: id);
      }
      await widget.controller.deleteChat(convoId: id);
      // Remember it locally: the row itself will be re-created by the next
      // history sync, and without this the chat reappears with its messages.
      await DesktopDeletedChats.remember(id);
      // Тот же довод, что у архива: снос чата — это несколько записей в базу,
      // и раздел может не дожить до их конца.
      if (!mounted) return;
      if (_selectedId == id) {
        setState(() => _selectedId = null);
        widget.selection?.clear();
      }
      await _convos.refresh();
    } catch (e) {
      _toast('Не удалось: $e', danger: true);
    }
  }

  /// Confirmation with an optional "clear on the other side too" checkbox.
  ///
  /// Returns null when the user cancels. The checkbox is unticked by default
  /// and never remembered between openings: reaching into someone else's
  /// device is a decision to make each time, not a preference to inherit.
  void _toast(String message, {bool danger = false}) {
    if (!mounted) return;
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

  /// Та же подпись, что у темы в подробностях комнаты, — см.
  /// [desktopTimeLabel]. Одна на весь десктоп: две разошлись бы на первой же
  /// правке, а человек читает их рядом.
  String _formatTime(int ms) => desktopTimeLabel(ms);

  @override
  Widget build(BuildContext context) {
    // The Rooms tab has no category strip, so it must not be filtered by one.
    final scoped = widget.filter == ConversationFilter.groups
        ? _conversations
        : _conversations.where(_matchesCategory).toList(growable: false);
    final items = scoped.map(_toItem).toList(growable: false);
    Conversation? selected;
    if (_selectedId != null) {
      for (final convo in _conversations) {
        if (convo.convoId == _selectedId) {
          selected = convo;
          break;
        }
      }
    }

    // 🔴 Смена тем перерисовывает ТОЛЬКО список, а не всю секцию.
    //
    // Темы публикуются в общий склад, и если подписать на него секцию целиком,
    // каждое изменение тем пересобирало бы и переписку — вместе со всей лентой
    // сообщений. Подписка стоит вокруг одного списка: он единственный, кому
    // темы нужны.
    final selectionStore = widget.selection;
    Widget buildListPanel(DesktopChatSelectionStore? topicStore) {
      return ChatListPanel(
        // Width lives in the shell so it survives a section switch and is
        // persisted once, rather than each section keeping its own idea.
        width: widget.shellApi.listWidth,
        // Свёрнут ли список в столбик портретов — решает оболочка: край
        // тянут через неё, и во всех разделах вид один.
        compact: widget.shellApi.listCompact,
        onExpand: widget.shellApi.onListExpand,
        title: widget.filter == ConversationFilter.groups ? 'Комнаты' : 'Чаты',
        onCompose: _composeMenu,
        // Папки — понятие раздела «Чаты». В комнатах полосы категорий нет
        // вовсе, и кнопка вела бы в пустоту.
        onFilters: widget.filter == ConversationFilter.groups
            ? null
            : _filtersMenu,
        items: items,
        selectedId: _selectedId,
        // ◆ ВЕТКИ ОТКРЫТОЙ КОМНАТЫ — ПОД ЕЁ СТРОКОЙ (указание владельца).
        //
        // Берём из того же склада, что и полоса в шапке, поэтому список и
        // полоса не могут разойтись. Только у ОТКРЫТОЙ комнаты: у всех подряд
        // это растянуло бы список чужими ветками — ровно то, из-за чего
        // подстроки однажды и убрали.
        topics: topicStore?.topics ?? const <RoomTopicRef>[],
        baseTopicMark: topicStore?.baseTopicMark ?? '',
        currentTopicId: topicStore?.currentTopicId,
        topicUnread: topicStore?.topicUnread ?? const <String, int>{},
        onSelectTopic: topicStore?.onSelectTopic,
        // 🔴 ТЕМЫ В СПИСОК БОЛЬШЕ НЕ УХОДЯТ (14.09.2026). Панель раскрывала
        // их подстроками под открытой комнатой — ровно те же темы в тот же
        // момент показывала полоса в шапке переписки, с теми же счётчиками и
        // тем же выбором. Один выбор в двух местах окна. В макете у открытой
        // комнаты в списке нет ни одной подстроки; склад тем остаётся —
        // его читает правая панель, где темами управляют.
        // Categories only make sense on the Chats tab. Rooms already IS a
        // category, so an extra strip there would just repeat the sidebar.
        categories: widget.filter == ConversationFilter.groups
            ? const <ChatCategory>[]
            : _buildCategories(),
        selectedCategoryId: _category,
        onSelectCategory: (id) => unawaited(_selectCategory(id)),
        onCategoryContextMenu: (cat, at) => unawaited(_folderChipMenu(cat, at)),
        emptyCategoryText: _emptyCategoryText(),
        // Подвал панели из макета: состояние связи и вход в архив. Кнопка
        // архива появляется, только когда в архиве что-то есть.
        footer: ChatListFooter(
          compact: widget.shellApi.listCompact,
          sync: widget.syncStatus,
          archiveActive: _category == ChatCategoryIds.archive,
          onOpenArchive: _hasArchivedChats
              ? () => unawaited(
                  _selectCategory(
                    _category == ChatCategoryIds.archive
                        ? ChatCategoryIds.all
                        : ChatCategoryIds.archive,
                  ),
                )
              : null,
        ),
        extraChatActions: _chatFolderActions,
        onDropOnChat: (convoId, paths) async {
          final convo = _conversations
              .where((c) => c.convoId == convoId)
              .cast<Conversation?>()
              .firstWhere((c) => c != null, orElse: () => null);
          if (convo == null) return;
          await _dropOntoConversation(convo, paths);
        },
        onSelect: (id) {
          setState(() => _selectedId = id);
          final store = widget.selection;
          if (store != null) {
            Conversation? picked;
            for (final c in _conversations) {
              if (c.convoId == id) {
                picked = c;
                break;
              }
            }
            store.select(picked);
          }
        },
        onPin: _togglePinned,
        onMute: _toggleMuted,
        onArchive: _toggleArchived,
        onMarkRead: _markRead,
        onClear: _clearHistory,
        onDelete: _deleteChat,
      );
    }

    // Край списка тянется — см. [ListThreadSplit]: там же объяснено, почему
    // до 16.09.2026 он не тянулся вовсе.
    final row = ListThreadSplit.fromApi(
      widget.shellApi,
      list: selectionStore == null
          ? buildListPanel(null)
          : ListenableBuilder(
              listenable: selectionStore,
              builder: (ctx, _) => buildListPanel(selectionStore),
            ),
      thread: selected == null
          ? _EmptyThread(
              loading: !_convos.hasLoaded,
              hasItems: items.isNotEmpty,
              titleNoItems: widget.emptyTitleNoItems,
              subtitleNoItems: widget.emptySubtitleNoItems,
              titleSelect: widget.emptyTitleSelect,
            )
          : _ChatThreadHost(
              key: ValueKey('thread-${selected.convoId}'),
              vm: widget.vm,
              conversation: selected,
              shellApi: widget.shellApi,
              selection: widget.selection,
              // Меню строит СЕКЦИЯ: у неё живут обработчики закрепления,
              // архива, очистки и удаления — те же, что у правого щелчка
              // в списке. Копия этих действий разошлась бы с оригиналом.
              onHeaderMenu: (at) => _chatHeaderMenu(selected!.convoId, at),
            ),
    );

    // PR4 (SPRINT2_AUDIT §16): collapse to the bare row when no sync
    // controller was wired (tests, screenshots, legacy callers).
    final syncStatus = widget.syncStatus;
    if (syncStatus == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Пропущенная почта — факт о прошлом, и он остаётся полосой поверх
        // секции: его читают один раз и закрывают.
        const DesktopAbsenceNotice(),
        // 🔴 Полосы состояния связи здесь БОЛЬШЕ НЕТ.
        //
        // Она говорила ровно то же, что теперь говорит подвал панели списка
        // (`ChatListFooter`), и при этом умела только половину: в спокойном
        // состоянии рисовала пустую строку с прозрачностью ноль, то есть
        // «Синхронизировано» человек не видел никогда. Два места про одно
        // состояние хуже одного, а из двух выживает то, которое работает во
        // всех четырёх состояниях.
        //
        // 🔴 Здесь же стояла ручка края списка — в столбце, где у неё не было
        // высоты. Теперь она в [ListThreadSplit], на самом шве.
        Expanded(child: row),
      ],
    );
  }
}

/// Owns the active chat thread: loads + decrypts events, sends messages,
/// reacts to controller changes. One instance per selected conversation
/// (keyed by convoId so switching chats triggers a fresh state).
class _ChatThreadHost extends StatefulWidget {
  const _ChatThreadHost({
    super.key,
    required this.vm,
    required this.conversation,
    required this.shellApi,
    this.selection,
    this.onHeaderMenu,
  });

  /// Меню чата из шапки переписки. Строит секция — см. `_chatHeaderMenu`.
  final void Function(Offset globalPosition)? onHeaderMenu;

  /// The controller seam. [controller] is derived from it, so every
  /// `widget.controller` use site below keeps working unchanged.
  final DesktopAppViewModel vm;
  AppController get controller => vm.controller;
  final Conversation conversation;
  final DesktopShellApi shellApi;

  /// Общий с панелью подробностей склад: туда публикуются темы комнаты.
  final DesktopChatSelectionStore? selection;

  @override
  State<_ChatThreadHost> createState() => _ChatThreadHostState();
}
/// Как читать `local_state` строки события — ОДНО место на весь десктоп.
///
/// 🔴 Было методом хоста переписки, и список чатов до него не доставал: чтобы
/// нарисовать галочку в строке, пришлось бы завести вторую такую же таблицу
/// соответствий. Две таблицы про одно расходятся — так уже разошлись сами
/// галочки, о чём написано в шапке `deliveryTickGlyph`.

/// U-14: maps a persisted local state onto the tick model.
///
/// Normalised through the SHARED [MessageLocalState] so desktop and mobile
/// read the same rows the same way. The previously hand-rolled string switch
/// missed `pending`, `retry` and `scheduled`, which all fell through to the
/// `default` and rendered as a plain "sent" tick — a queued or still-retrying
/// message looked delivered, and a scheduled one looked already sent.
DeliveryStatus deliveryStatusFor(String localState, {required bool isSelf}) {
  if (!isSelf) return DeliveryStatus.read;
  final state = MessageLocalState.normalize(localState);
  switch (state) {
    case MessageLocalState.pending:
    case MessageLocalState.sending:
    case MessageLocalState.retry:
      return DeliveryStatus.sending;
    case MessageLocalState.scheduled:
      return DeliveryStatus.scheduled;
    case MessageLocalState.failed:
      return DeliveryStatus.failed;
    case MessageLocalState.read:
      return DeliveryStatus.read;
    case MessageLocalState.delivered:
      return DeliveryStatus.delivered;
    default:
      return DeliveryStatus.sent;
  }
}


class _ChatThreadHostState extends State<_ChatThreadHost> {
  /// Превью ссылки в поле ввода — своё у каждой открытой переписки (хост
  /// создаётся заново при смене чата). Отключено в настройках — панель его
  /// не получает вовсе, и окно не открывает страниц.
  final OutgoingLinkPreviewDraft _linkDraft = OutgoingLinkPreviewDraft();

  void _onLinkPreviewsPref() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------
  // Room topics («ветки»).
  //
  // Reuses the SHARED room-topic protocol verbatim: the list is broadcast as
  // the hidden `__secretly_topics_v1__` control message (latest-wins), and an
  // individual message carries its `topicId` inside the encrypted payload. A
  // branch created on the phone therefore shows up here, and vice versa.
  // ---------------------------------------------------------------------

  List<RoomTopicRef> _roomTopics = const <RoomTopicRef>[];

  /// null = «Общий» — everything without a topic, including all history from
  /// before the room had branches.
  String? _currentTopicId;

  /// Newest topics-sync we have applied, so an older control message replayed
  /// from the mailbox cannot resurrect a deleted branch.
  int _topicsSyncAtMs = 0;

  /// Знак «Основы» — общего потока комнаты. Пусто — решётка.
  String _baseTopicMark = '';

  /// payloadId → topic id ('' = Общий). Built while mapping events so the
  /// timeline filter never has to decrypt anything twice.
  final Map<String, String> _topicOfEvent = <String, String>{};

  bool _canManageTopics = false;

  bool get _topicsVisible => !_isDirect && _roomTopics.isNotEmpty;

  /// Отдаёт состояние тем панели подробностей.
  ///
  /// Секция остаётся ЕДИНСТВЕННЫМ местом, где темы разбираются из управляющих
  /// сообщений; панель получает готовый список через общий склад. Второго
  /// разбора нет — значит двум спискам не с чем разойтись.
  void _publishTopics() {
    final store = widget.selection;
    if (store == null) return;
    store.onSelectTopic = (id) {
      if (!mounted) return;
      setState(() => _currentTopicId = id);
      _publishTopics();
    };
    store.onCreateTopic = _canManageTopics
        ? () {
            if (mounted) unawaited(_createTopic());
          }
        : null;
    store.publishTopics(
      topics: _topicsVisible ? _roomTopics : const <RoomTopicRef>[],
      currentTopicId: _currentTopicId,
      unread: _topicsVisible ? _topicUnreadCounts() : const <String, int>{},
      lastActivityMs: _topicLastActivityMs(),
      canManage: _canManageTopics,
      baseMark: _baseTopicMark,
    );
  }

  /// Records a topics-sync control message. Returns true when it changed the
  /// set, so the caller can rebuild.
  bool _adoptTopicsSync(String rawText, int createdAtMs) {
    final parsed = parseTopicsSyncCommand(rawText);
    if (parsed == null) return false;
    if (createdAtMs < _topicsSyncAtMs) return false; // stale replay
    _topicsSyncAtMs = createdAtMs;
    _roomTopics = parsed.topics;
    _baseTopicMark = parsed.baseMark;
    // 🔴 Принятое кладём в базу: список тем приходит скрытым сообщением, и
    // через двести новых сообщений оно выпадает из окна ленты — до 15.09.2026
    // вместе с ним пропадали и сами темы, а их сообщения уезжали в «Общий».
    unawaited(
      widget.controller.rememberRoomTopics(
        groupId: widget.conversation.convoId,
        topics: _roomTopics,
        syncedAtMs: createdAtMs,
        baseMark: _baseTopicMark,
      ),
    );
    scheduleMicrotask(_publishTopics);
    // A branch can be deleted while we are standing in it.
    if (_currentTopicId != null &&
        !_roomTopics.any((t) => t.id == _currentTopicId)) {
      _currentTopicId = null;
    }
    return true;
  }

  /// Topic a rendered message belongs to; '' means «Общий».
  String _topicKeyFor(MessageData m) =>
      _topicOfEvent[m.payloadId ?? m.id] ?? '';

  // ── Альбомы ───────────────────────────────────────────────────────────
  //
  // Лента хранит сообщения по одному (так их читает база), а показывает —
  // строками: снимки, отправленные вместе, склеиваются в альбом (см.
  // [groupMediaAlbums]). Склейка запоминается, пока не сменились сами
  // сообщения или тема: иначе панель получала бы НОВЫЙ список на каждой
  // перерисовке и заново перебирала бы поиск и выделение.

  List<MessageData>? _rowsSource;
  Object? _rowsKey;
  List<MessageData> _rows = const <MessageData>[];

  List<MessageData> get _threadRows {
    final key = (_currentTopicId, _topicsVisible, _roomTopics);
    if (!identical(_rowsSource, _messages) || _rowsKey != key) {
      _rowsSource = _messages;
      _rowsKey = key;
      _rows = groupMediaAlbums(_applyTopicFilter(_messages));
    }
    return _rows;
  }

  List<MessageData> _applyTopicFilter(List<MessageData> src) {
    if (!_topicsVisible) return src;
    final want = _currentTopicId ?? '';
    // Unknown ids fall back to Общий rather than vanishing — a message must
    // never be hidden just because its branch was deleted.
    final known = _roomTopics.map((t) => t.id).toSet();
    return src
        .where((m) {
          final k = _topicKeyFor(m);
          final resolved = known.contains(k) ? k : '';
          return resolved == want;
        })
        .toList(growable: false);
  }

  Map<String, int> _topicUnreadCounts() {
    // Deliberately simple: unread-per-branch is in-memory on mobile too, and
    // a wrong number is worse than none. Show nothing until there is a real
    // per-topic read cursor to compute it from.
    return const <String, int>{};
  }

  /// Время последнего сообщения по темам; пустой ключ — «Общий».
  ///
  /// ◆ В МАКЕТЕ У ТЕМЫ СПРАВА СТОИТ ВРЕМЯ. Правая половина строки темы пустует
  /// всегда: счётчик непрочитанного по темам честно не считается (см.
  /// [_topicUnreadCounts]), и отличить живую тему от заброшенной было нечем —
  /// список выглядел одинаково и через минуту, и через месяц.
  ///
  /// 🔴 ЧЕСТНАЯ ГРАНИЦА: считаем по ЗАГРУЖЕННОЙ ленте, а не по всей истории.
  /// Отдельного «когда в теме писали в последний раз» протокол не передаёт, а
  /// лента подгружается страницами. Поэтому у темы, чьи сообщения остались за
  /// краем загруженного, времени не будет вовсе — и это лучше, чем показать
  /// время, которое старше настоящего: пустое место ничего не обещает, а
  /// неверная дата обещает и врёт.
  Map<String, int> _topicLastActivityMs() {
    if (!_topicsVisible) return const <String, int>{};
    final out = <String, int>{};
    for (final m in _messages) {
      final ms = m.timestampMs;
      if (ms <= 0) continue;
      final key = _topicKeyFor(m);
      final prev = out[key];
      if (prev == null || ms > prev) out[key] = ms;
    }
    return out;
  }

  /// Описание комнаты для шапки переписки.
  ///
  /// 🔴 Оно жило только в подробностях, отдельной секцией: чтобы вспомнить, о
  /// чём комната, надо было открыть панель. В макете описание стоит прямо в
  /// шапке, за вертикальной чертой.
  ///
  /// Перечитывается на тике контроллера вместе с остальным: описание меняют
  /// редко, но если его поменяли в подробностях — шапка обязана догнать, а не
  /// ждать переоткрытия чата.
  Future<void> _refreshRoomDescription() async {
    if (_isDirect) return;
    try {
      final settings = await widget.controller.getRoomSettings(_convoId);
      final next = settings.description?.trim() ?? '';
      if (!mounted || next == _roomDescription) return;
      setState(() => _roomDescription = next);
    } catch (_) {
      // Нет настроек — нет описания; шапка просто останется без строки.
    }
  }

  Future<void> _refreshTopicPolicy() async {
    if (_isDirect) return;
    try {
      final policy = await widget.controller.getRoomPolicyState(_convoId);
      if (!mounted) return;
      setState(() => _canManageTopics = policy.canChangeGroupInfo);
      // Право заводить темы — часть состояния тем: от него зависит, есть ли у
      // комнаты без тем вход, чтобы создать первую.
      _publishTopics();
    } catch (_) {
      if (!mounted) return;
      setState(() => _canManageTopics = false);
      _publishTopics();
    }
  }

  /// «Продолжить в теме» из строки наведения над сообщением.
  ///
  /// ◆ В МАКЕТЕ ЭТО КНОПКА `forum` РЯДОМ С «ОТВЕТИТЬ», и подписана она была
  /// «вынести в тему». Вынести — нельзя: тема лежит ВНУТРИ запечатанного
  /// payload, и переписать её у уже разосланного сообщения не может никто —
  /// ни отправитель, ни сервер. Поэтому переносится не сообщение, а РАЗГОВОР:
  /// выбираем ветку, переключаемся в неё, и панель ставит в поле ввода цитату
  /// исходного сообщения. Само оно остаётся на своём месте, а цитата ведёт
  /// к нему обратно.
  ///
  /// Возвращает `true`, если ветку выбрали.
  Future<bool> _continueInTopic(Offset globalPosition) async {
    if (!_topicsVisible || !mounted) return false;
    String? picked;
    var pickedGeneral = false;
    await ContextMenu.show(
      context,
      globalPosition: globalPosition,
      width: 240,
      sections: <List<CtxMenuItem>>[
        <CtxMenuItem>[
          CtxMenuItem(
            label: 'Общий',
            icon: FluentIcons.chat_24_regular,
            // Ветку, в которой стоим, выбирать незачем — переключать нечего.
            enabled: _currentTopicId != null,
            onTap: () => pickedGeneral = true,
          ),
          for (final t in _roomTopics)
            CtxMenuItem(
              label: t.title,
              icon: FluentIcons.number_symbol_24_regular,
              enabled: t.id != _currentTopicId,
              onTap: () => picked = t.id,
            ),
        ],
        if (_canManageTopics)
          <CtxMenuItem>[
            CtxMenuItem(
              label: 'Новая тема…',
              icon: FluentIcons.add_24_regular,
              onTap: () => picked = _kNewTopicSentinel,
            ),
          ],
      ],
    );
    if (!mounted) return false;
    if (pickedGeneral) {
      setState(() => _currentTopicId = null);
      _publishTopics();
      return true;
    }
    if (picked == null) return false;
    if (picked == _kNewTopicSentinel) {
      final before = _currentTopicId;
      await _createTopic();
      // Ветку могли не завести — тогда и продолжать негде.
      return mounted && _currentTopicId != before;
    }
    setState(() => _currentTopicId = picked);
    _publishTopics();
    return true;
  }

  /// Пункт «Новая тема…» не может назваться идентификатором ветки — его и не
  /// существует, пока ветку не завели.
  static const String _kNewTopicSentinel = '__new__';

  Future<void> _createTopic() async {
    final title = await _promptTopicTitle();
    if (title == null || !mounted) return;
    final id =
        'topic-${DateTime.now().millisecondsSinceEpoch}-'
        '${_convoId.hashCode.abs() % 0xFFFF}';
    final next = <RoomTopicRef>[
      ..._roomTopics,
      RoomTopicRef(
        id: id,
        // Решётку рисует фишка — в названии её не храним, иначе «#релиз»
        // стал бы «##релиз».
        title: normalizeRoomTopicTitle(title),
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    await _broadcastTopics(next, selectAfter: id);
  }

  /// ◆ У «Основы» меняется только значок: переименовать главный поток нельзя,
  /// удалить — тем более.
  Future<void> _manageBaseTopic() async {
    final picked = await _pickTopicMark(current: _baseTopicMark);
    if (picked == null || !mounted) return;
    final next = picked == '-' ? '' : picked;
    if (next == _baseTopicMark) return;
    setState(() => _baseTopicMark = next);
    await _broadcastTopics(_roomTopics);
  }

  Future<void> _manageTopic(RoomTopicRef topic) async {
    final action = await DesktopDialog.show<String>(
      context,
      title: 'Ветка «${roomTopicDisplayTitle(topic)}»',
      size: DDialogSize.small,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopButton(
            label: 'Переименовать',
            kind: DButtonKind.tonal,
            expand: true,
            onPressed: () => Navigator.of(context).maybePop('rename'),
          ),
          const SizedBox(height: DSpace.s),
          // ◆ Знак ветки — тот же набор, что и на телефоне, и меняется с
          // обеих сторон: знак едет в той же рассылке, что имя.
          DesktopButton(
            label: 'Значок',
            icon: FluentIcons.number_symbol_24_regular,
            kind: DButtonKind.tonal,
            expand: true,
            onPressed: () => Navigator.of(context).maybePop('mark'),
          ),
          const SizedBox(height: DSpace.s),
          DesktopButton(
            label: 'Удалить ветку',
            kind: DButtonKind.danger,
            expand: true,
            onPressed: () => Navigator.of(context).maybePop('delete'),
          ),
        ],
      ),
      secondary: DDialogAction(
        label: 'Отмена',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'mark') {
      final picked = await _pickTopicMark(current: topic.mark);
      if (picked == null || !mounted) return;
      final next = _roomTopics
          .map(
            (t) => t.id == topic.id
                ? t.copyWith(mark: picked == '-' ? '' : picked)
                : t,
          )
          .toList(growable: false);
      await _broadcastTopics(next);
      return;
    }
    if (action == 'rename') {
      final title = await _promptTopicTitle(initial: topic.title);
      if (title == null || !mounted) return;
      final next = _roomTopics
          .map(
            (t) => t.id == topic.id
                ? t.copyWith(title: normalizeRoomTopicTitle(title))
                : t,
          )
          .toList(growable: false);
      await _broadcastTopics(next);
      return;
    }
    // Delete. Messages already sent into it are NOT lost — they fall back to
    // «Общий», which is why the filter resolves unknown ids that way.
    final next = _roomTopics
        .where((t) => t.id != topic.id)
        .toList(growable: false);
    await _broadcastTopics(next, selectAfter: null, clearIfCurrent: topic.id);
  }

  /// ◆ Выбор знака ветки. `'-'` — снять знак, `null` — передумали.
  ///
  /// Сетка, а не список: знаки узнают глазами, и три десятка строк с
  /// подписями читались бы дольше, чем разглядывается вся сетка.
  Future<String?> _pickTopicMark({required String current}) async {
    final c = DColors.of(context);
    return DesktopDialog.show<String>(
      context,
      title: 'Значок ветки',
      size: DDialogSize.medium,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: DSpace.m),
            child: Text(
              'Значок заменяет решётку перед названием. Цветные обещают, что '
              'внутри: зелёный — созвон, красный — срочное. Остальные серые, '
              'чтобы не спорить с именем.',
              style: DType.caption.copyWith(
                color: c.textTertiary,
                height: 1.4,
              ),
            ),
          ),
          Wrap(
            spacing: DSpace.s,
            runSpacing: DSpace.s,
            children: [
              _MarkCell(
                icon: kRoomTopicHashIcon,
                color: null,
                tooltip: 'Решётка',
                selected: current.trim().isEmpty,
                onTap: () => Navigator.of(context).maybePop('-'),
              ),
              for (final mark in kRoomTopicMarks)
                _MarkCell(
                  icon: mark.icon,
                  color: mark.color,
                  tooltip: mark.labelRu,
                  selected: current.trim() == mark.id,
                  onTap: () => Navigator.of(context).maybePop(mark.id),
                ),
            ],
          ),
        ],
      ),
      secondary: DDialogAction(
        label: 'Отмена',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Future<void> _broadcastTopics(
    List<RoomTopicRef> topics, {
    String? selectAfter,
    String? clearIfCurrent,
  }) async {
    try {
      await widget.controller.broadcastRoomTopics(
        groupId: _convoId,
        topics: topics,
        baseMark: _baseTopicMark,
      );
      if (!mounted) return;
      setState(() {
        _roomTopics = topics;
        _topicsSyncAtMs = DateTime.now().millisecondsSinceEpoch;
        if (selectAfter != null) _currentTopicId = selectAfter;
        if (clearIfCurrent != null && _currentTopicId == clearIfCurrent) {
          _currentTopicId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      // The controller enforces the room policy; a member without rights gets
      // a real error here rather than a silently-ignored tap.
      DesktopSnackbar.show(
        context,
        message: 'Не удалось изменить ветки: $e',
        kind: DSnackKind.error,
      );
    }
  }

  Future<String?> _promptTopicTitle({String? initial}) async {
    final ctl = TextEditingController(text: initial ?? '');
    final result = await DesktopDialog.show<String>(
      context,
      // «Тема», а не «ветка»: во всём остальном окне — полосе под шапкой,
      // разделе правой панели, подписи у поля ввода — сказано «тема». Два
      // названия одного предмета человек читает как два разных предмета.
      title: initial == null ? 'Новая тема' : 'Переименовать тему',
      size: DDialogSize.small,
      body: DesktopTextField(
        controller: ctl,
        hintText: 'Название темы',
        autofocus: true,
        onSubmitted: (v) => Navigator.of(context).maybePop(v.trim()),
      ),
      primary: DDialogAction(
        label: 'Сохранить',
        onPressed: () => Navigator.of(context).maybePop(ctl.text.trim()),
      ),
      secondary: DDialogAction(
        label: 'Отмена',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
    ctl.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  List<MessageData> _messages = const [];

  /// Опросы ленты: сам опрос, голоса и закрытие — обычные сообщения, поэтому
  /// итог считается по ним заново (`desktopTallyPolls`).
  final Map<String, DesktopCardSource> _pollSourceByEventId =
      <String, DesktopCardSource>{};
  final Map<String, String> _pollIdByMessageId = <String, String>{};
  final Map<String, String> _eventIdByMessageId = <String, String>{};
  bool _loading = true;
  String? _sendError;

  /// Сверены ли коды безопасности с собеседником — галочка в шапке.
  bool _peerVerified = false;

  /// Закреплённое в комнате сообщение и право его менять — см.
  /// [_loadPinnedMessage].
  String? _pinnedPayloadEventId;
  bool _canPinMessages = false;
  bool _searchOpen = false;

  /// Opens the in-chat search. Idempotent on purpose: pressing Cmd+F while
  /// the bar is already open should focus it, never toggle it shut.
  void _onFindRequested() {
    if (!mounted || _searchOpen) return;
    setState(() => _searchOpen = true);
  }

  // E9 typing-out state: throttle «typing» signals (re-send at most every 2s
  // while active) and stop 3s after the last keystroke.
  Timer? _typingStopTimer;
  int _lastTypingSentMs = 0;
  bool _typingActive = false;

  // E9: disappearing-messages timer for this chat (null/0 = off). Loaded async
  // and refreshed with the thread.
  int? _autoDeleteSeconds;

  // PR7 pagination state ----------------------------------------------
  /// `created_at_ms` of the oldest message currently in [_messages].
  /// Used as the cursor when the user scrolls to the top and we ask
  /// for an older page. 0 = unknown / list is empty.
  int _oldestLoadedMs = 0;

  /// How far back the timeline reads on every reload.
  ///
  /// 🔴 ПОЧЕМУ ОКНО РАСТЁТ (11.09.2026, жалоба «не показывает половину смс»).
  ///
  /// `_load()` перечитывает ленту и пересобирает `_messages`, и вызывается он
  /// на КАЖДЫЙ тик контроллера — а тик на спаренном клиенте приходит
  /// постоянно. Пока лимит был фиксированными новейшими 200, каждая такая
  /// пересборка ВЫБРАСЫВАЛА всё, что пользователь подгрузил прокруткой вверх:
  /// старые сообщения появлялись и через секунду исчезали сами.
  ///
  /// Мобильный чат чинил ровно это и тем же приёмом — см. комментарий
  /// «TIMELINE WINDOW» у `AppController.loadEvents`: «previously the window
  /// was a fixed newest-200, so every new message pushed the oldest visible
  /// one out ("старые смс исчезают сверху"). The rows were never deleted —
  /// just outside the window.» Десктоп остался на старом поведении.
  ///
  /// Растёт ровно на столько, сколько пользователь реально подгрузил, и
  /// сбрасывается при смене беседы — иначе открытие короткого чата после
  /// длинного читало бы тысячи строк без нужды.
  int _timelineLimit = _kTimelineInitialLimit;

  /// Стартовое окно — столько же, сколько по умолчанию у `loadEvents`.
  static const int _kTimelineInitialLimit = 200;

  /// Шаг роста. Совпадает с размером страницы «загрузить старые», чтобы окно
  /// после перезагрузки содержало ровно то, что человек уже видел.
  static const int _kTimelinePageSize = 100;

  /// True until [_loadOlder] hits a local DB page that comes back
  /// empty. Flips to false then to gate further local-DB queries (we
  /// only fall through to the peer-history-request path once).
  bool _hasMoreLocal = true;

  /// True while a peer-history request fired by [_loadOlder] is
  /// pending. Suppresses repeat requests during the same scroll burst.
  bool _peerHistoryInFlight = false;
  // -------------------------------------------------------------------

  // PR8 attachment state ----------------------------------------------
  /// Decoded payloads for messages with `AttachmentEventV1` payloads,
  /// keyed by the wrapper event id (== `MessageData.id`). Populated lazily
  /// by [_toMessageData] and consumed by [_openImage] / [_openFile] /
  /// [_toggleVoice] when the user taps a media bubble.
  final Map<String, AttachmentEventV1> _attachmentsByMessageId =
      <String, AttachmentEventV1>{};

  /// Tracks in-flight `ensureCachedAttachmentFile` background fetches so
  /// we don't kick a second download for the same blob when [_load] runs
  /// multiple times in quick succession (e.g. `changed` stream debounce).
  final Set<String> _attachmentFetchInFlight = <String>{};
  // -------------------------------------------------------------------

  /// Maps the wrapper `event.eventId` (used as `MessageData.id`) to the
  /// `payloadEventId ?? eventId` used as the reaction key on the DB side.
  /// Mobile uses the same `(entry.payloadEventId ?? entry.event.eventId)`
  /// fallback (see `lib/ui/chat_screen.dart` `_payloadEventId`), and the
  /// fan-out command from `broadcastReactionUpdate` carries `eventId` as the
  /// payload event id — so keeping the desktop convention identical is what
  /// makes reactions show up on both devices for the same message.
  final Map<String, String> _reactionKeyByMessageId = <String, String>{};

  /// 2026-05-20 PR-B (BUG-10.5): payload-event-ids that a delete-for-everyone
  /// command has tombstoned. Populated by [_collectDeletedPayloadEventIds]
  /// before each list build pass; consumed when filtering events into
  /// [_messages]. Mobile applies the same filter in `chat_screen.dart`
  /// around line 8807 — without it the desktop kept showing messages that
  /// mobile and the peer had already tombstoned.
  final Set<String> _deletedPayloadEventIds = <String>{};

  /// E6: device-id → resolved display name cache for GROUP sender attribution.
  /// Cleared on conversation change. 1:1 chats never populate it (the sender is
  /// always the peer or self). Mirrors mobile's per-call `senderNameCache`.
  /// device-id → resolved display name. Only SUCCESSFULLY-resolved names are
  /// cached; unknown senders fall back to a distinct per-device stub and are
  /// NOT cached, so a name that becomes known mid-conversation resolves on the
  /// next reload instead of sticking on the stub.
  final Map<String, String> _senderNameCache = <String, String>{};

  /// deviceId → group sender's avatar file path. Cached (non-empty only) to
  /// avoid two async lookups per group message on every thread rebuild; an
  /// avatar that lands later resolves on the next reload, like names.
  final Map<String, String> _senderAvatarCache = <String, String>{};

  /// profileId → display name for the current room's members, loaded lazily
  /// once per conversation (the primary attribution source — most senders are
  /// room members but not saved contacts). Null until loaded; reset on convo
  /// change.
  Map<String, String>? _roomMemberNamesByProfileId;

  /// Когда этот перечень прочитан. Загружался он РОВНО ОДИН РАЗ на переписку,
  /// и это ломало самоисцеление: участник, чьё имя приехало через минуту,
  /// оставался безымянным до перехода в другую комнату и обратно.
  int _roomMemberNamesAtMs = 0;

  /// Сколько в комнате действующих участников — для подписи в шапке.
  int? _roomMemberCount;

  /// Участники по профилю — чтобы показать ЛИЦА тех, кто сейчас в созвоне.
  Map<String, RoomMember> _roomMembersById = const <String, RoomMember>{};

  /// Кого можно позвать через «@». Пусто у личной переписки и пока состав
  /// комнаты не загружен.
  ///
  /// 🔴 Десктоп умел ПОКАЗЫВАТЬ упоминания и не умел их СТАВИТЬ: подсветка,
  /// счётчик и уведомление на входе работали, а `sendGroupMessage` уходил без
  /// `mentions`, и «@Игорь, посмотри» с компьютера приходило обычным текстом.
  /// Человек, которого позвали с компьютера, об этом не узнавал.
  List<DesktopMentionTarget> _mentionTargets = const <DesktopMentionTarget>[];

  /// E6: payloadEventId → quote preview, accumulated as messages are mapped so
  /// a reply can render the quoted author + snippet. Mirrors mobile's
  /// `previewByPayloadId`. Rebuilt on each full [_load]; «load older» adds to
  /// it. A reply whose target isn't in the map (deleted / not yet paged in)
  /// simply renders without a quote rather than failing.
  final Map<String, ReplyPreview> _replyPreviewByPayloadId =
      <String, ReplyPreview>{};

  @override
  void didUpdateWidget(covariant _ChatThreadHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.convoId != widget.conversation.convoId) {
      // Close the in-chat search bar and drop per-conversation caches so a
      // different chat can't inherit the previous one's sender names / quote
      // previews.
      if (_searchOpen) _searchOpen = false;
      _senderNameCache.clear();
      _senderAvatarCache.clear();
      _roomMemberNamesByProfileId = null;
      _roomMemberNamesAtMs = 0;
      _roomMemberCount = null;
      _replyPreviewByPayloadId.clear();
      // A different conversation starts from the default window: carrying a
      // grown one over would read thousands of rows for a chat the user has
      // not scrolled at all.
      _timelineLimit = _kTimelineInitialLimit;
      _hasMoreLocal = true;
      // Созвон принадлежит комнате: показать его над другой перепиской —
      // это предложить присоединиться не туда, куда написано в шапке.
      _activeRoomCall = null;
      unawaited(_refreshActiveRoomCall());
      // Reset typing state for the new conversation (don't fire a stray «stop»
      // into the new convo; the old peer's indicator expires via its TTL).
      _typingStopTimer?.cancel();
      _typingActive = false;
      _lastTypingSentMs = 0;
      // Темы принадлежат ДРУГОЙ комнате — сбрасываем и читаем сохранённые.
      _roomTopics = const <RoomTopicRef>[];
      _baseTopicMark = '';
      _topicsSyncAtMs = 0;
      _currentTopicId = null;
      unawaited(_loadStoredRoomTopics());
      // Заготовки отправки — свои у каждой переписки.
      _resetUploadsForConvo();
    }
  }

  /// Читает сохранённый список тем комнаты.
  ///
  /// Лента остаётся каналом доставки: если в ней найдётся СВЕЖЕЕ сообщение со
  /// списком, [_adoptTopicsSync] его примет — сравнение идёт по той же
  /// отметке времени.
  Future<void> _loadStoredRoomTopics() async {
    final convoId = widget.conversation.convoId;
    final stored = await widget.controller.loadRoomTopics(convoId);
    final atMs = await widget.controller.roomTopicsSyncedAtMs(convoId);
    if (!mounted) return;
    if (convoId != widget.conversation.convoId) return; // успели переключиться
    if (atMs <= _topicsSyncAtMs) return;
    setState(() {
      _topicsSyncAtMs = atMs;
      _roomTopics = stored.topics;
      _baseTopicMark = stored.baseMark;
      if (_currentTopicId != null &&
          !stored.topics.any((topic) => topic.id == _currentTopicId)) {
        _currentTopicId = null;
      }
    });
    _publishTopics();
  }

  /// Живой созвон открытой комнаты, `null` — созвона нет.
  ///
  /// Тот же снимок, по которому живёт баннер на телефоне: читается из
  /// `getCachedRoomCall`, обновляется на общем тике ленты. Отдельного
  /// опроса сети здесь нет — снимок в базу кладёт слой комнат.
  CachedRoomCall? _activeRoomCall;

  String get _convoId => widget.conversation.convoId;
  String? get _peerProfileId => widget.conversation.peerProfileId;
  bool get _isDirect => _peerProfileId != null;

  /// Описание открытой комнаты — показывается в шапке. Пусто у личной
  /// переписки и у комнаты без описания.
  String _roomDescription = '';

  @override
  void initState() {
    super.initState();
    // Reload on the shared, debounced tick instead of a subscription of this
    // widget's own.
    //
    // NOT diffed, deliberately. What a thread renders reaches into nested
    // objects — attachment download state, reaction sets, reply previews,
    // sender names and avatars that resolve into caches later — and a
    // signature that missed one of those would leave a bubble frozen with no
    // way to notice. A rebuild that was not needed costs a frame; a bubble
    // that stops updating is the app lying about a message. The debounce and
    // the single subscription are the win here; the diff belongs to the list,
    // where [_toItem] makes the rendered state nameable.
    widget.vm.ticks.addListener(_onTick);
    // Cmd+F reaches the open conversation through the shell, so the shortcut
    // works without the shell knowing which chat is open.
    widget.shellApi.findRequests.addListener(_onFindRequested);
    DesktopUiPrefs.linkPreviews.addListener(_onLinkPreviewsPref);
    _load();
    _markRead();
    // Новое при открытой переписке — прочитано, когда его видно; см.
    // [_scheduleMarkRead].
    DesktopWindowActivity.focused.addListener(_onHostWindowFocusChanged);
    // Who may add or rename a branch. Resolved once per open room; without it
    // the create control would be offered to members who cannot use it.
    unawaited(_refreshTopicPolicy());
    unawaited(_refreshRoomDescription());
    unawaited(_refreshActiveRoomCall());
    // Темы — из базы, а не только из видимой ленты: см. [_loadStoredRoomTopics].
    unawaited(_loadStoredRoomTopics());
    // Уходящие файлы и ошибки их отправки.
    _subscribeUploads();
  }

  @override
  void dispose() {
    // The notifier outlives this widget (it belongs to the shell), so failing
    // to detach would keep a disposed State reachable on every Cmd+F.
    widget.shellApi.findRequests.removeListener(_onFindRequested);
    widget.vm.ticks.removeListener(_onTick);
    DesktopUiPrefs.linkPreviews.removeListener(_onLinkPreviewsPref);
    DesktopWindowActivity.focused.removeListener(_onHostWindowFocusChanged);
    _markReadDebounce?.cancel();
    // Панель с полем ввода снята раньше хоста — слушателей у черновика уже
    // нет.
    _linkDraft.dispose();
    // Best-effort «stop typing» so the peer's indicator clears if we close the
    // chat mid-compose, then drop the timer.
    _stopTyping();
    _typingStopTimer?.cancel();
    unawaited(_uploadsSub?.cancel());
    unawaited(_uploadErrorsSub?.cancel());
    _uploadTickTimer?.cancel();
    _landingTimer?.cancel();
    _uploadTick.dispose();
    super.dispose();
  }

  void _onTick() {
    if (mounted) unawaited(_load());
    _scheduleMarkRead();
    unawaited(_refreshActiveRoomCall());
    // Описание комнаты правят в подробностях — шапка обязана догнать, а не
    // ждать переоткрытия чата. `setState` идёт только при ИЗМЕНЕНИИ строки.
    unawaited(_refreshRoomDescription());
  }

  /// Перечитывает снимок созвона комнаты.
  ///
  /// Перерисовываем только при СМЕНЕ созвона или его версии: снимок
  /// обновляется чаще, чем меняется то, что видно в плашке, а лишний setState
  /// здесь перестраивает всю переписку.
  Future<void> _refreshActiveRoomCall() async {
    if (_isDirect) {
      if (_activeRoomCall != null && mounted) {
        setState(() => _activeRoomCall = null);
      }
      return;
    }
    final convoId = _convoId;
    final call = await widget.controller.getCachedRoomCall(convoId);
    if (!mounted || _convoId != convoId) return;
    final next = (call != null && call.isActive) ? call : null;
    if (next?.callId != _activeRoomCall?.callId ||
        next?.stateVersion != _activeRoomCall?.stateVersion) {
      setState(() => _activeRoomCall = next);
    }
  }

  /// Лица тех, кто СЕЙЧАС в созвоне — для плашки.
  ///
  /// Берём из уже загруженного состава комнаты: отдельного запроса на это не
  /// делаем, а участник, которого в составе ещё нет (только что вошёл по
  /// ссылке), просто не получает лица — плашка от этого не ломается.
  List<RoomCallFace> _callFaces(CachedRoomCall call) {
    final out = <RoomCallFace>[];
    for (final p in call.participants) {
      if (!p.isJoined) continue;
      final member = _roomMembersById[p.profileId];
      final name = (member?.displayName ?? '').trim();
      out.add(
        RoomCallFace(
          name: name.isEmpty ? p.profileId : name,
          avatarPath: member?.avatarPath,
        ),
      );
      // Больше четырёх лиц в полосе шириной с окно не читаются, а счётчик
      // рядом всё равно называет точное число.
      if (out.length >= 4) break;
    }
    return out;
  }

  /// Видны ли свежие сообщения (лента не отлистана вверх).
  bool _nearLatest = true;
  Timer? _markReadDebounce;

  /// 🔴 НОВОЕ В ОТКРЫТОЙ ПЕРЕПИСКЕ — ПРОЧИТАНО, КОГДА ЕГО ВИДНО (17.09.2026).
  ///
  /// Отметка ставилась только при открытии. Сообщение, пришедшее, пока
  /// человек смотрит в чат, оставалось непрочитанным: значок висел, а
  /// собеседник не получал «прочитано», хотя его читали. Как на телефоне
  /// (`_scheduleMarkRead` в `chat_screen.dart`, те же 450 мс): отмечаем, когда
  /// окно в фокусе и лента внизу. Отлистал вверх — новое внизу не видно, и
  /// отметка ждёт возврата вниз.
  void _scheduleMarkRead() {
    _markReadDebounce?.cancel();
    _markReadDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      if (!desktopShouldMarkOpenChatRead(
        windowFocused: DesktopWindowActivity.focused.value,
        nearLatest: _nearLatest,
      )) {
        return;
      }
      unawaited(_markRead());
    });
  }

  void _onHostWindowFocusChanged() {
    if (DesktopWindowActivity.focused.value) _scheduleMarkRead();
  }

  void _onNearLatestChanged(bool near) {
    _nearLatest = near;
    if (near) _scheduleMarkRead();
  }

  Future<void> _markRead() async {
    // Rooms were never marked read here: this used `_peerProfileId`, which is
    // null for a group, and bailed — so a room's unread badge stayed forever
    // on the desktop no matter how many times it was opened.
    //
    // `markChatRead` has always accepted a room: it branches on a `group:`
    // prefix and sends room read-receipts. The addressing is what differs, and
    // the shared resolver mobile already uses returns exactly the right thing
    // for both kinds.
    final target = resolveChatMarkReadPeerProfileId(
      convoId: _convoId,
      peerProfileIdForSend: _peerProfileId,
    );
    if (target == null || target.isEmpty) return;
    try {
      await widget.controller.markChatRead(peerProfileId: target);
    } catch (_) {
      // best-effort
    }
  }

  /// E9: load the chat's disappearing-messages timer for the header chip.
  Future<void> _loadPeerVerified() async {
    final pid = (_peerProfileId ?? '').trim();
    if (pid.isEmpty) return;
    try {
      final v = await widget.controller.contactWasEverVerified(pid);
      if (mounted && v != _peerVerified) setState(() => _peerVerified = v);
    } catch (_) {
      // best-effort: не сверили — галочки нет, и это честно
    }
  }

  Future<void> _loadAutoDelete() async {
    try {
      final s = await widget.controller.getChatAutoDeleteSeconds(_convoId);
      if (mounted && s != _autoDeleteSeconds) {
        setState(() => _autoDeleteSeconds = s);
      }
    } catch (_) {
      // best-effort; chip just stays hidden
    }
  }

  /// Что закреплено в комнате и вправе ли я это менять.
  Future<void> _loadPinnedMessage() async {
    try {
      final settings = await widget.controller.getRoomSettings(_convoId);
      final policy = await widget.controller.getRoomPolicyState(_convoId);
      final pinned = (settings.pinnedMessageEventId ?? '').trim();
      final next = pinned.isEmpty ? null : pinned;
      if (!mounted) return;
      if (next != _pinnedPayloadEventId ||
          policy.canPinMessages != _canPinMessages) {
        setState(() {
          _pinnedPayloadEventId = next;
          _canPinMessages = policy.canPinMessages;
        });
      }
    } catch (_) {
      // best-effort: нет данных — нет плашки, а не сломанный экран
    }
  }

  /// Закрепить или открепить сообщение.
  ///
  /// Отказ комнаты («закреплять могут только админы») приходит сюда
  /// `RoomPolicyFailure` и показывается словами — см. [_humanError].
  Future<void> _togglePinMessage(MessageData m, bool pin) async {
    final target = (m.payloadId ?? m.id).trim();
    if (target.isEmpty) return;
    try {
      await widget.controller.setRoomPinnedMessage(
        groupId: _convoId,
        messageEventId: pin ? target : null,
      );
      if (!mounted) return;
      setState(() {
        _pinnedPayloadEventId = pin ? target : null;
        _sendError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = _humanError(e));
    }
    unawaited(_loadPinnedMessage());
  }

  Future<void> _load() async {
    unawaited(_loadAutoDelete());
    if (_isDirect) unawaited(_loadPeerVerified());
    // Состав комнаты нужен шапке («N участников») даже там, где все имена уже
    // в кэше и разбор отправителей до перечня не доходит. Перечитывается не
    // чаще раза в полминуты — см. [_roomMemberNames].
    if (!_isDirect) {
      unawaited(
        _roomMemberNames().then((_) {
          if (mounted) setState(() {});
        }),
      );
      unawaited(_loadPinnedMessage());
    }
    // PR-B BUG-10.5: reset the tombstone set on every full reload —
    // otherwise switching to a different conversation in the same State
    // instance (the panel reuses [_ChatThreadHostState] across widget
    // updates) would carry deletes from the previous chat over.
    _deletedPayloadEventIds.clear();
    try {
      // PR3.8 (SPRINT2_AUDIT §13) message-ordering fix:
      //   `controller.loadEvents` ultimately calls `db.listEvents` which
      //   orders rows `created_at_ms DESC, rowid DESC` (newest first). But
      //   `ChatThreadPanel` renders with `ListView.builder(reverse: true)`
      //   and `msgIdx = widget.messages.length - 1 - idx` — i.e. it expects
      //   the list to be chronological (oldest first, newest last) so that
      //   the bottom row (idx 0 in a reverse list) maps to messages.last
      //   (the newest message).
      //   Before this fix, with DESC-ordered events, the bottom of the chat
      //   ended up showing the OLDEST message and freshly-sent messages were
      //   placed at the TOP — the user-reported "сообщения которые я пишу
      //   появляются выше других пузырей" bug.
      //   We materialize events into chronological order here so the
      //   downstream presentation can stay unchanged.
      final eventsDesc = await widget.controller.loadEvents(
        _convoId,
        limit: _timelineLimit,
      );
      final events = eventsDesc.reversed.toList(growable: false);
      // PR7: stash the oldest cursor for "Load older" pagination.
      // After `reverse`, events[0] is the chronologically-earliest
      // row we've loaded. Empty list = no events yet → cursor stays 0
      // so a stray scroll-up doesn't fire a request for `before: 0`.
      if (events.isNotEmpty) {
        _oldestLoadedMs = events.first.createdAtMs;
        _hasMoreLocal = true;
      }
      // First pass: figure out which payload-event-id to use for reaction
      // lookup per message. We do this BEFORE building MessageData so we can
      // batch-load all reactions in a single DB call rather than N round
      // trips on every reload.
      final reactionKeyByMessageId = <String, String>{};
      for (final event in events) {
        reactionKeyByMessageId[event.eventId] = desktopTimelineRowId(
          event.payloadEventId,
          event.eventId,
        );
      }
      final reactionKeys = reactionKeyByMessageId.values.toSet().toList();
      Map<String, List<MessageReaction>> reactionsByKey = const {};
      if (reactionKeys.isNotEmpty) {
        try {
          reactionsByKey = await widget.controller.loadMessageReactions(
            eventIds: reactionKeys,
          );
        } catch (_) {
          // Reactions are cosmetic — failing to load them must not block the
          // thread from rendering.
          reactionsByKey = const {};
        }
      }

      // PR-B BUG-10.5: pre-scan events for delete-for-everyone commands so
      // we can skip the tombstoned rows when building [_messages]. The
      // helper decodes each MsgEventV1.text once and adds matching
      // payload-event-ids to [_deletedPayloadEventIds]. Mobile does the
      // same pre-scan in `chat_screen.dart:8807-8841`.
      await _collectDeletedPayloadEventIds(events);

      // E6: rebuild the quote-preview map for this full reload. «Load older»
      // (which prepends) keeps adding to it rather than clearing.
      _replyPreviewByPayloadId.clear();
      final mapped = <MessageData>[];
      for (final event in events) {
        final pid = event.payloadEventId;
        if (pid != null && _deletedPayloadEventIds.contains(pid)) {
          continue;
        }
        final reactionKey =
            reactionKeyByMessageId[event.eventId] ?? event.eventId;
        final raw = reactionsByKey[reactionKey] ?? const <MessageReaction>[];
        final bubbleReactions = _aggregateReactions(raw);
        final msg = await _toMessageData(event, bubbleReactions);
        if (msg != null) mapped.add(msg);
      }
      if (!mounted) return;
      final withPolls = _withPolls(mapped);
      setState(() {
        _messages = withPolls;
        _reactionKeyByMessageId
          ..clear()
          ..addAll(reactionKeyByMessageId);
        _loading = false;
      });
      // 🔴 Публикуем темы ПОСЛЕ каждой загрузки ленты, а не только когда
      // человек нажмёт на тему.
      //
      // Раньше публикация висела ровно на двух обработчиках нажатия. Значит,
      // пока темы никто не трогал, ни правая панель, ни список чатов о них не
      // знали вовсе — темы, приехавшие с телефона, появлялись только после
      // первого тычка в полосу. Разбор при этом работал исправно, и потому
      // выглядело это как «иногда не показывает».
      //
      // Публикация дешёвая: склад сравнивает состав и молчит, когда ничего не
      // изменилось, — а меняется оно куда реже, чем тикает лента.
      _publishTopics();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// PR7: «Load older» — wired into [ChatThreadPanel.onLoadOlder]. Walks
  /// in two phases:
  ///   1. Try to read a deeper page from the local SQLite cache
  ///      (`controller.loadOlderEvents(... beforeCreatedAtMs)`).
  ///   2. If the local DB is dry, fire a single peer-history request
  ///      asking mobile for older content, anchored on the same
  ///      cursor. The next pump of the chunk applier will trigger
  ///      `_load()` via the `changed` stream, which reads the freshly
  ///      inserted rows.
  ///
  /// Idempotent against fast-repeat scroll triggers — the panel-level
  /// `_loadingOlder` guard plus this state's [_peerHistoryInFlight]
  /// short-circuit duplicate requests.
  Future<void> _loadOlder() async {
    if (_oldestLoadedMs <= 0) return;
    final controller = widget.controller;

    // Phase 1: dig deeper into the local cache.
    if (_hasMoreLocal) {
      try {
        final olderDesc = await controller.loadOlderEvents(
          _convoId,
          beforeCreatedAtMs: _oldestLoadedMs,
          limit: 100,
        );
        if (olderDesc.isEmpty) {
          _hasMoreLocal = false;
        } else {
          final older = olderDesc.reversed.toList(growable: false);
          // Re-map reactions for the new page. Single batched DB call
          // matching the pattern in [_load].
          final keyByMessageId = <String, String>{};
          for (final event in older) {
            keyByMessageId[event.eventId] = desktopTimelineRowId(
              event.payloadEventId,
              event.eventId,
            );
          }
          final keys = keyByMessageId.values.toSet().toList();
          Map<String, List<MessageReaction>> reactionsByKey = const {};
          if (keys.isNotEmpty) {
            try {
              reactionsByKey = await controller.loadMessageReactions(
                eventIds: keys,
              );
            } catch (_) {
              reactionsByKey = const {};
            }
          }
          // PR-B BUG-10.5: extend the tombstone set with delete commands
          // discovered in the older page (a delete authored before the
          // current load window can still tombstone a row we just paged in).
          await _collectDeletedPayloadEventIds(older);

          final prepended = <MessageData>[];
          for (final event in older) {
            final pid = event.payloadEventId;
            if (pid != null && _deletedPayloadEventIds.contains(pid)) {
              continue;
            }
            final reactionKey = keyByMessageId[event.eventId] ?? event.eventId;
            final raw =
                reactionsByKey[reactionKey] ?? const <MessageReaction>[];
            final msg = await _toMessageData(event, _aggregateReactions(raw));
            if (msg != null) prepended.add(msg);
          }
          if (!mounted) return;
          setState(() {
            // 🔴 СТАРЫЕ — В НАЧАЛО. Лента хронологическая (старые первыми),
            // а здесь страница дописывалась в КОНЕЦ: подгруженное прошлое на
            // миг оказывалось ниже свежих сообщений, пока полная перезагрузка
            // не расставит всё по местам. Со склейкой альбомов такая путаница
            // рвала бы альбомы.
            _messages = _withPolls(<MessageData>[...prepended, ..._messages]);
            _oldestLoadedMs = older.first.createdAtMs;
            // Keep what the user just paged in across the next reload.
            _timelineLimit += _kTimelinePageSize;
            _reactionKeyByMessageId.addAll(keyByMessageId);
          });
          return;
        }
      } catch (_) {
        // Local probe failed (e.g. DB closed mid-shutdown). Don't fall
        // through to a peer-history request — let the next user scroll
        // try again from scratch.
        return;
      }
    }

    // Phase 2: local cache is exhausted — ask mobile for the next
    // window if we haven't already. Single in-flight request keyed
    // per host instance; the controller's own request-id machinery
    // dedupes against repeated cursor values.
    if (_peerHistoryInFlight) return;
    _peerHistoryInFlight = true;
    try {
      await controller.requestPeerHistory(
        requestId: 'older-${DateTime.now().millisecondsSinceEpoch}',
        cursor: _oldestLoadedMs.toString(),
        // Room-scoped: don't drag 250 events from other chats just
        // because this one ran out of local history. Mobile honors
        // the convoId filter in `listRecentEventsForPeerSync`.
        convoId: _convoId,
      );
      // Don't poll here — the shared tick will trigger a fresh `_load()`
      // once chunks land. If nothing comes back within 25s the cycle
      // times out silently and `_peerHistoryInFlight` stays true for
      // another 8s (below) to avoid a re-storm.
      await Future<void>.delayed(const Duration(seconds: 8));
    } catch (_) {
      // ignore — see class-level peer-history comments.
    } finally {
      if (mounted) _peerHistoryInFlight = false;
    }
  }

  /// Collapses the controller's per-actor reaction rows into the count+byMe
  /// shape `MessageBubble` expects. Order is stable: emojis appear in the
  /// order they were first seen, so the row layout doesn't shuffle when a
  /// new reactor joins.
  /// Сводка реакций для пузыря: по эмодзи — сколько, моя ли, и КТО.
  ///
  /// 🔴 Имена с портретами раньше терялись здесь (16.09.2026). Сводка
  /// схлопывала список в `(эмодзи, число, моя ли)`, и полоске портретов в
  /// фишке — той самой, что есть на телефоне, — брать их было неоткуда.
  ///
  /// Порядок фишек — как на телефоне: сначала те, кого больше, при равенстве
  /// раньше поставленная. Порядок портретов внутри фишки — по времени.
  List<bubble.MessageReaction> _aggregateReactions(List<MessageReaction> raw) {
    if (raw.isEmpty) return const [];
    final selfPid = widget.controller.profileId;
    final byEmoji = <String, List<MessageReaction>>{};
    final order = <String>[];
    for (final r in raw) {
      final emoji = r.emoji.trim();
      if (emoji.isEmpty) continue;
      final bucket = byEmoji.putIfAbsent(emoji, () {
        order.add(emoji);
        return <MessageReaction>[];
      });
      bucket.add(r);
    }
    for (final bucket in byEmoji.values) {
      bucket.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    }
    final sorted = order.toList(growable: false)
      ..sort((a, b) {
        final byCount = byEmoji[b]!.length.compareTo(byEmoji[a]!.length);
        if (byCount != 0) return byCount;
        return byEmoji[a]!.first.createdAtMs.compareTo(
          byEmoji[b]!.first.createdAtMs,
        );
      });
    return [
      for (final emoji in sorted)
        bubble.MessageReaction(
          emoji: emoji,
          count: byEmoji[emoji]!.length,
          byMe: byEmoji[emoji]!.any((r) => r.profileId == selfPid),
          actors: [
            for (final r in byEmoji[emoji]!)
              bubble.ReactionActor(
                profileId: r.profileId,
                name: r.actorName,
                avatarPath: r.actorAvatarPath,
              ),
          ],
        ),
    ];
  }

  /// Упомянули ли ЗДЕСЬ меня.
  ///
  /// 🔴 Пузырь умеет подсвечивать упоминание (`c.mentionBg`) с самого начала,
  /// но признак ему никто не передавал — то есть «@Yurii, посмотри» в комнате
  /// выглядело на компьютере обычным текстом, ничем не отличаясь от болтовни
  /// вокруг. Правило берём то же, что у уведомлений: обращение ко всем или
  /// поимённо ко мне.
  bool _mentionsMe(List<MsgMentionV1> mentions) {
    if (mentions.isEmpty) return false;
    final myPid = widget.controller.profileId.trim();
    for (final mention in mentions) {
      if (mention.isAll) return true;
      if (mention.isProfile &&
          myPid.isNotEmpty &&
          mention.profileId == myPid) {
        return true;
      }
    }
    return false;
  }

  Future<MessageData?> _toMessageData(
    ChatEvent event,
    List<bubble.MessageReaction> reactions,
  ) async {
    // Язык интерфейса читаем ДО первого `await`: после него трогать `context`
    // нельзя (виджет мог уйти с экрана).
    final localeTag = roomLocaleTagFromContext(context);
    final payload = await widget.controller.payloadEventForChatEvent(event);
    final isSelf = widget.controller.isOwnDeviceId(event.senderDeviceId);
    // 🔴 У ЗАПЛАНИРОВАННОГО СООБЩЕНИЯ ПИШЕМ ДЕНЬ, А НЕ ТОЛЬКО ЧАСЫ.
    //
    // У такой заготовки `created_at_ms` — это момент БУДУЩЕЙ отправки, и
    // подвал показывал бы «09:00» ровно так же, как у отправленного в девять
    // утра. Для сообщения, которое уйдёт завтра, это неправда: значок
    // календаря рядом говорит «позже», а время говорит «уже». Показываем
    // «завтра в 9:00» — тем же счётчиком, каким подписан выбор времени.
    final time = event.localState == MessageLocalState.scheduled
        ? formatScheduleMoment(
            DateTime.fromMillisecondsSinceEpoch(event.createdAtMs),
          )
        : _hhmm(event.createdAtMs);
    // E6: in a ROOM the incoming author is the real sender (resolved from the
    // sender device-id), NOT the conversation title — previously every inbound
    // group message was attributed to the room name. 1:1 keeps the peer title.
    final String author;
    if (isSelf) {
      author = _kSelfAuthorRu;
    } else if (_isDirect) {
      author = widget.conversation.title.isEmpty
          ? '—'
          : widget.conversation.title;
    } else {
      author = await _resolveGroupSenderName(event.senderDeviceId);
    }
    final senderAvatarPath = await _resolveSenderAvatarPath(
      isSelf: isSelf,
      senderDeviceId: event.senderDeviceId,
    );
    // Роль автора в комнате — ею красится имя и, у владельца с админами,
    // рисуется метка. В личной переписке роли нет и цвет остаётся по хешу.
    final authorRole = _isDirect
        ? null
        : await _resolveGroupSenderRole(event.senderDeviceId);
    final authorProfileId = isSelf
        ? widget.controller.profileId
        : (_isDirect
              ? widget.conversation.peerProfileId
              : await _resolveSenderProfileId(event.senderDeviceId));
    // Logical id the peer knows this message by — reply/edit/delete-for-all
    // target this, NOT the wrapper `event.eventId` (which is the local DB row
    // and is what delete-for-me removes). Mirrors the reaction-key resolution.
    // Пустой номер — не номер (17.09.2026): `??` ловит только null, и сообщения
    // с пустым `payloadEventId` делили один ключ — тему, удаление для всех.
    final payloadId = desktopTimelineRowId(event.payloadEventId, event.eventId);

    // Remember which branch this event belongs to before any early return —
    // the timeline filter reads this map, and a message whose topic was not
    // recorded would silently land in «Общий».
    final topicOf = payload is MsgEventV1
        ? payload.topicId
        : (payload is AttachmentEventV1
              ? payload.topicId
              : (payload is StickerEventV1 ? payload.topicId : null));
    _topicOfEvent[payloadId] = (topicOf ?? '').trim();

    if (payload is MsgEventV1) {
      final raw = payload.text;
      // 🔴 Опрос считается по ВСЕЙ ленте: сам опрос, голоса и закрытие — это
      // отдельные сообщения, и голоса с закрытием ниже отбрасываются как
      // служебные. Собираем их здесь, до отбрасывания.
      if (raw.startsWith(kPollCommandPrefix) ||
          raw.startsWith(kPollVoteCommandPrefix) ||
          raw.startsWith(kPollCloseCommandPrefix) ||
          raw.startsWith(kEventCommandPrefix) ||
          raw.startsWith(kEventRsvpCommandPrefix)) {
        _pollSourceByEventId[event.eventId] = DesktopCardSource(
          text: raw,
          authorProfileId: authorProfileId ?? '',
          createdAtMs: event.createdAtMs,
        );
      }
      // Room topic list arrives as a hidden control message. Adopt it here,
      // before the control-text gate swallows it, then keep it hidden.
      if (isTopicsSyncCommandText(raw)) {
        if (_adoptTopicsSync(raw, event.createdAtMs)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
        return null;
      }
      // CRITICAL (parity audit P0): forwarded messages, polls and events are
      // real content wrapped in a `__secretly_…` command. The blunt
      // _isHiddenControlText below would drop them as control noise (silent
      // data loss). Handle them HERE, before that gate; true control commands
      // (delete / vote / call-signal) stay hidden.
      final fwd = parseForwardCommand(raw);
      if (fwd != null) {
        final shown = fwd.text;
        _registerReplyPreview(
          payloadId,
          author,
          shown,
          isImage: false,
          authorSeed: event.senderDeviceId,
        );
        return MessageData(
          id: event.eventId,
          payloadId: payloadId,
          authorName: author,
        authorRole: authorRole,
        authorSeed: event.senderDeviceId,
        authorProfileId: authorProfileId,
          text: shown,
          time: time,
          timestampMs: event.createdAtMs,
          isSelf: isSelf,
          delivery: deliveryStatusFor(event.localState, isSelf: isSelf),
          reactions: reactions,
          forwardedFrom: fwd.authorName.isNotEmpty
              ? fwd.authorName
              : 'неизвестно',
          senderAvatarPath: senderAvatarPath,
        );
      }
      // Polls / events: readable placeholder so nothing is silently lost
      // (full interactive cards are a later phase).
      final poll = parsePollCommand(raw);
      if (poll != null) {
        _pollIdByMessageId[event.eventId] = poll.pollId;
        // Подпись остаётся для ответов и списка чатов: карточку рисует пузырь,
        // а цитата и строка чата — это текст.
        final label = '📊 Опрос: ${poll.question}';
        _registerReplyPreview(
          payloadId,
          author,
          label,
          isImage: false,
          authorSeed: event.senderDeviceId,
        );
        return MessageData(
          id: event.eventId,
          payloadId: payloadId,
          authorName: author,
        authorRole: authorRole,
        authorSeed: event.senderDeviceId,
        authorProfileId: authorProfileId,
          text: label,
          time: time,
          timestampMs: event.createdAtMs,
          isSelf: isSelf,
          delivery: deliveryStatusFor(event.localState, isSelf: isSelf),
          reactions: reactions,
          senderAvatarPath: senderAvatarPath,
        );
      }
      final ev = parseEventCommand(raw);
      if (ev != null) {
        _eventIdByMessageId[event.eventId] = ev.eventId;
        // Подпись остаётся для цитат и списка чатов; карточку рисует пузырь.
        final label = '📅 ${ev.title}';
        _registerReplyPreview(
          payloadId,
          author,
          label,
          isImage: false,
          authorSeed: event.senderDeviceId,
        );
        return MessageData(
          id: event.eventId,
          payloadId: payloadId,
          authorName: author,
        authorRole: authorRole,
        authorSeed: event.senderDeviceId,
        authorProfileId: authorProfileId,
          text: label,
          time: time,
          timestampMs: event.createdAtMs,
          isSelf: isSelf,
          delivery: deliveryStatusFor(event.localState, isSelf: isSelf),
          reactions: reactions,
          senderAvatarPath: senderAvatarPath,
        );
      }
      if (_isHiddenControlText(raw)) return null;
      // Register this message so later replies can quote it, then resolve our
      // own reply target (an earlier message already registered above).
      _registerReplyPreview(
        payloadId,
        author,
        raw,
        isImage: false,
        authorSeed: event.senderDeviceId,
      );
      // 🔴 Карточка ссылки — только та, что приехала в сообщении и относится
      // к ссылке из его же текста. Чужие ссылки окно не открывает никогда.
      final carriedPreview = acceptIncomingLinkPreview(payload.linkPreview, raw);
      return MessageData(
        id: event.eventId,
        payloadId: payloadId,
        authorName: author,
        authorRole: authorRole,
        authorSeed: event.senderDeviceId,
        authorProfileId: authorProfileId,
        text: raw,
        time: time,
        timestampMs: event.createdAtMs,
        isSelf: isSelf,
        delivery: deliveryStatusFor(event.localState, isSelf: isSelf),
        reactions: reactions,
        reply: _resolveReplyPreview(payload.replyToEventId),
        isTextMessage: true,
        hasMention: _mentionsMe(payload.mentions),
        // 🔴 Сама разметка, а не только признак: без неё пузырь красил фон, но
        // «@Игорь» рисовал обычным словом — фишки не было.
        mentions: payload.mentions,
        senderAvatarPath: senderAvatarPath,
        linkPreview: carriedPreview,
        // Своё прежнее сообщение без карточки — её можно загрузить самим:
        // свою ссылку человек выбрал сам.
        ownLinkPreviewTarget: (isSelf && carriedPreview == null)
            ? linkPreviewTargetFor(raw)
            : null,
      );
    }

    if (payload is AttachmentEventV1) {
      // PR8 (SPRINT2_AUDIT §20): render real photos / voice notes / files
      // instead of an emoji placeholder. We carry the [AttachmentEventV1]
      // alongside the message so the host can resolve / play / open the
      // blob without re-decoding the payload on every tap.
      _attachmentsByMessageId[event.eventId] = payload;
      final mime = (payload.mime ?? '').toLowerCase();
      final kind = desktopAttachmentKind(payload);
      final sentAsFile = (payload.filename ?? '').trim().isNotEmpty;
      // Probe the on-disk cache synchronously — if the blob is already there
      // (common for own outgoing messages we just sent, or for inbound media
      // that was pre-fetched by the «Подкачать вложения» pass), the bubble
      // can render the photo / play the voice note immediately. If not, we
      // schedule a background fetch and re-render when it lands.
      final cached = await widget.controller.cachedAttachmentFile(payload);
      // 🔴 ФАЙЛ КАЧАЕТСЯ ПО НАЖАТИЮ, как в Telegram: в строке файла стоит
      // «Загрузить». Сами качаются только снимки, ролики и голосовые — то,
      // что показывается прямо в ленте.
      final autoDownload = desktopAutoDownloads(kind, sentAsFile: sentAsFile);
      var attachment = MessageAttachment(
        kind: kind,
        blobId: payload.blobId,
        payloadEventId: payload.eventId,
        filePath: cached?.path,
        mime: payload.mime,
        fileName: payload.filename,
        sizeBytes: payload.sizeBytes,
        // Огибающая громкости голосового — из того же запечатанного payload,
        // по которому телефон рисует волну с первого дня. Поле лежало в
        // протоколе и до окна не доходило: одно сообщение выглядело на двух
        // устройствах по-разному без всякого решения.
        durationMs: payload.durationMs,
        waveform: payload.waveform,
        loading: cached == null && autoDownload,
        width: payload.width,
        height: payload.height,
        thumbnail: decodeAttachmentThumb(payload.thumbB64),
        sentAsFile: sentAsFile,
        videoNote: payload.videoNote,
        // Имя файла в поле названия — не тег (см. `taggedMusicTitle`).
        musicTitle: taggedMusicTitle(payload),
        musicArtist: taggedMusicArtist(payload),
      );
      attachment = _withProbedMusicTags(
        attachment,
        payload,
        messageId: event.eventId,
        cachedPath: cached?.path,
      );
      if (cached == null && autoDownload) {
        _kickAttachmentFetch(event.eventId, payload);
      }
      final isImage = mime.startsWith('image/');
      _registerReplyPreview(
        payloadId,
        author,
        isImage
            ? 'Фото'
            : mime.startsWith('video/')
            ? 'Видео'
            : mime.startsWith('audio/')
            ? 'Голосовое сообщение'
            : 'Файл',
        isImage: isImage,
        authorSeed: event.senderDeviceId,
      );
      return MessageData(
        id: event.eventId,
        payloadId: payloadId,
        authorName: author,
        authorRole: authorRole,
        authorSeed: event.senderDeviceId,
        authorProfileId: authorProfileId,
        // 🔴 ПОДПИСЬ — ИЗ САМОГО ВЛОЖЕНИЯ. Здесь стояла пустая строка, и
        // подписи, набранные на телефоне, на компьютере не показывались
        // вовсе.
        text: (payload.caption ?? '').trim(),
        time: time,
        isSelf: isSelf,
        delivery: deliveryStatusFor(event.localState, isSelf: isSelf),
        reactions: reactions,
        attachment: attachment,
        timestampMs: event.createdAtMs,
        reply: _resolveReplyPreview(payload.replyToEventId),
        senderAvatarPath: senderAvatarPath,
        mediaGroupId: payload.mediaGroupId,
      );
    }

    if (payload is StickerEventV1) {
      final label = payload.emojiHint.isNotEmpty
          ? payload.emojiHint
          : (payload.label.isNotEmpty ? payload.label : 'Стикер');
      // Resolve real artwork: catalog stickers resolve synchronously; user
      // stickers (E2EE blob) are downloaded + decrypted on demand. A missing
      // descriptor still renders the emoji/label fallback in the bubble.
      var descriptor = SecretlyStickerCatalog.resolveEvent(payload);
      if (!descriptor.isRenderable && descriptor.hasInlineBlob) {
        try {
          final cached = await widget.controller.ensureUserStickerCached(
            payload,
          );
          if (cached != null) descriptor = cached;
        } catch (_) {}
      }
      _registerReplyPreview(
        payloadId,
        author,
        'Стикер $label',
        isImage: false,
        authorSeed: event.senderDeviceId,
      );
      return MessageData(
        id: event.eventId,
        payloadId: payloadId,
        authorName: author,
        authorRole: authorRole,
        authorSeed: event.senderDeviceId,
        authorProfileId: authorProfileId,
        text: '',
        sticker: descriptor,
        time: time,
        timestampMs: event.createdAtMs,
        isSelf: isSelf,
        delivery: deliveryStatusFor(event.localState, isSelf: isSelf),
        reactions: reactions,
        reply: _resolveReplyPreview(payload.replyToEventId),
        senderAvatarPath: senderAvatarPath,
      );
    }

    // 2026-05-20 PR-A: call-history cards. Mobile (`_CallEventBubble` in
    // chat_screen.dart) already renders these; on desktop the event was
    // landing in `_toMessageData` but falling through to the `return null`
    // below, so every finished call was invisible in the thread. We map
    // the payload into a `MessageData` with `callEvent` populated — the
    // bubble's `_callBubble` branch (message_bubble.dart) takes care of
    // the actual rendering, including direction arrow, duration suffix,
    // and self-delivery ticks. The visible preview text is derived via
    // `buildCallEventPreviewText` so chat-list snippets stay consistent
    // with mobile.
    if (payload is CallEventV1) {
      return MessageData(
        id: event.eventId,
        payloadId: payloadId,
        authorName: author,
        authorRole: authorRole,
        authorSeed: event.senderDeviceId,
        authorProfileId: authorProfileId,
        text: buildCallEventPreviewText(
          isRu: true,
          result: payload.result,
          direction: payload.direction,
          isVideo: payload.hadVideo,
          durationMs: payload.durationMs,
        ),
        time: time,
        isSelf: isSelf,
        delivery: deliveryStatusFor(event.localState, isSelf: isSelf),
        reactions: reactions,
        callEvent: payload,
        timestampMs: event.createdAtMs,
        isRu: true,
        senderAvatarPath: senderAvatarPath,
      );
    }

    // 🔴 СЛУЖЕБНЫЕ СООБЩЕНИЯ КОМНАТЫ (17.09.2026). «Вошёл», «вышел»,
    // «сменили название» телефон показывает плашкой, а компьютер отбрасывал
    // здесь же, где раньше терялись карточки звонков: комната молчала о себе,
    // и человек не понимал, откуда взялся новый участник. Текст собирает та
    // же общая функция, что и на телефоне, — на всех восьми языках.
    if (payload is SystemEventV1) {
      final text = formatSystemEventText(
        payload,
        isRu: localeTag.startsWith('ru'),
        selfProfileId: widget.controller.profileId,
        localeTag: localeTag,
      );
      if (text.trim().isEmpty) return null;
      return MessageData(
        id: event.eventId,
        payloadId: payloadId,
        authorName: author,
        authorSeed: event.senderDeviceId,
        authorProfileId: authorProfileId,
        text: text,
        time: time,
        timestampMs: event.createdAtMs,
        isSelf: isSelf,
        isSystemEvent: true,
      );
    }

    // ReceiptEventV1, UnknownEventV1, null → skip in Slice 2.
    return null;
  }

  /// Досчитывает опросы: карточка знает свои голоса только вместе со всей
  /// лентой, поэтому итог накладывается на уже собранные строки.
  List<MessageData> _withPolls(List<MessageData> rows) {
    final hasCards =
        _pollIdByMessageId.isNotEmpty || _eventIdByMessageId.isNotEmpty;
    if (!hasCards || _pollSourceByEventId.isEmpty) return rows;
    final sources = _pollSourceByEventId.values.toList()
      ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    final me = widget.controller.profileId;
    final polls = desktopTallyPolls(entries: sources, myProfileId: me);
    final events = desktopTallyEvents(entries: sources, myProfileId: me);
    if (polls.isEmpty && events.isEmpty) return rows;
    return <MessageData>[
      for (final row in rows)
        () {
          final poll = polls[_pollIdByMessageId[row.id]];
          if (poll != null) return row.copyWith(poll: poll);
          final event = events[_eventIdByMessageId[row.id]];
          return event == null ? row : row.copyWith(eventCard: event);
        }(),
    ];
  }

  /// Собрать и отправить опрос. Только в комнате: опрос — комнатная штука,
  /// и контроллер отправляет его через `sendGroupMessage`.
  Future<void> _composePoll() async {
    if (!_convoId.startsWith('group:')) return;
    final draft = await showDesktopPollComposer(context);
    if (draft == null || !mounted) return;
    try {
      await widget.controller.sendGroupPoll(
        groupId: _convoId,
        question: draft.question.trim(),
        options: draft.cleanOptions,
        multiple: draft.multiple,
        anonymous: draft.anonymous,
        topicId: _currentTopicId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = _humanError(e));
    }
  }

  /// Собрать и отправить событие. Только в комнате — как опрос.
  Future<void> _composeEvent() async {
    if (!_convoId.startsWith('group:')) return;
    final draft = await showDesktopEventComposer(context);
    if (draft == null || !mounted) return;
    try {
      await widget.controller.sendGroupEvent(
        groupId: _convoId,
        title: draft.title.trim(),
        startMs: draft.startMs,
        description: draft.description.trim(),
        location: draft.location.trim(),
        topicId: _currentTopicId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = _humanError(e));
    }
  }

  /// Ответ на приглашение: «иду», «возможно», «не иду».
  Future<void> _rsvpEvent(MessageData message, String status) async {
    final event = message.eventCard;
    if (event == null) return;
    if (!_convoId.startsWith('group:')) return;
    try {
      await widget.controller.rsvpGroupEvent(
        groupId: _convoId,
        eventId: event.eventId,
        status: status,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = _humanError(e));
    }
  }

  /// Голос за вариант опроса. Повторное нажатие снимает свой голос там, где
  /// можно выбрать несколько.
  Future<void> _votePoll(MessageData message, int index) async {
    final poll = message.poll;
    if (poll == null || poll.closed) return;
    if (!_convoId.startsWith('group:')) return;
    final picked = <int>{...poll.myOptionIndices};
    if (poll.multiple) {
      if (!picked.remove(index)) picked.add(index);
    } else {
      picked
        ..clear()
        ..add(index);
    }
    try {
      await widget.controller.voteGroupPoll(
        groupId: _convoId,
        pollId: poll.pollId,
        optionIndices: picked.toList()..sort(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = _humanError(e));
    }
  }

  /// Завершить свой опрос: голосовать больше нельзя.
  Future<void> _closePoll(MessageData message) async {
    final poll = message.poll;
    if (poll == null || poll.closed || !poll.isCreator) return;
    if (!_convoId.startsWith('group:')) return;
    try {
      await widget.controller.closeGroupPoll(
        groupId: _convoId,
        pollId: poll.pollId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = _humanError(e));
    }
  }

  /// Resolves the avatar file path of a message's author: self → своё фото,
  /// 1:1 → the conversation avatar, group → the sender's cached profile avatar
  /// (cached per device, non-empty only). Null → the bubble falls back to
  /// initials.
  Future<String?> _resolveSenderAvatarPath({
    required bool isSelf,
    required String senderDeviceId,
  }) async {
    // Своё фото на компьютере лежит не в настройках, а в кэше собственных
    // метаданных: связка по QR фотографию не везёт.
    if (isSelf) return widget.controller.resolvedOwnAvatarPath();
    if (_isDirect) return widget.conversation.avatarPath;
    final hit = _senderAvatarCache[senderDeviceId];
    if (hit != null) return hit;
    try {
      final pid = await widget.controller.cachedProfileIdByDeviceId(
        senderDeviceId,
      );
      // Нет профиля — нет и фотографии; будим тот же прогрев, что и у имени.
      if (pid == null || pid.isEmpty) {
        widget.controller.warmProfileIdForDeviceSoon(senderDeviceId);
      }
      if (pid != null && pid.isNotEmpty) {
        final path = await widget.controller.cachedProfileAvatarPath(pid);
        if (path != null && path.isNotEmpty) {
          _senderAvatarCache[senderDeviceId] = path;
          return path;
        }
      }
    } catch (_) {}
    return null;
  }

  /// E6: resolves the display name of a ROOM message's sender from its
  /// device-id (cached per conversation). Falls back to «Участник» when the
  /// contact isn't known locally yet. Mirrors mobile's `resolveSenderName`.
  /// Роль отправителя в открытой комнате, если она известна.
  ///
  /// Соответствие «устройство → профиль» и состав комнаты уже загружены ради
  /// имени и портрета — роль берётся из них же, без единого лишнего запроса.
  Future<String?> _resolveGroupSenderRole(String senderDeviceId) async {
    if (_isDirect) return null;
    // Загружает состав, если он ещё не загружен, и наполняет
    // `_roomMembersById`.
    await _roomMemberNames();
    final profileId = await _resolveSenderProfileId(senderDeviceId);
    if (profileId == null || profileId.isEmpty) return null;
    return _roomMembersById[profileId]?.role.value;
  }

  /// Профиль отправителя по устройству. Нужен не только роли: по нему
  /// считается ОТТЕНОК заглушки портрета — тот же ключ, что у телефона.
  Future<String?> _resolveSenderProfileId(String senderDeviceId) async {
    try {
      return await widget.controller.cachedProfileIdByDeviceId(senderDeviceId);
    } catch (_) {
      return null;
    }
  }

  Future<String> _resolveGroupSenderName(String senderDeviceId) async {
    final hit = _senderNameCache[senderDeviceId];
    if (hit != null) return hit;

    // Primary source: the room member's display name (most participants are
    // members but not saved contacts). Mirrors mobile chat_screen.dart.
    final memberNames = await _roomMemberNames();
    String? name;
    String? profileId;
    try {
      profileId = await widget.controller.cachedProfileIdByDeviceId(
        senderDeviceId,
      );
    } catch (_) {}
    if (profileId == null || profileId.isEmpty) {
      // 🔴 БЕЗ ЭТОГО УЧАСТНИК КОМНАТЫ ОСТАЁТСЯ ШЕСТНАДЦАТЕРИЧНЫМ ОГРЫЗКОМ
      // НАВСЕГДА (13.09.2026).
      //
      // Соответствие «устройство → профиль» наполняется на приёме личных
      // сообщений. Участник комнаты, который никогда не писал нам лично, в
      // этот кэш не попадает — а без профиля нет ни имени, ни фотографии, и
      // над сообщением стоит «83cc23…4ec2». Телефон эту дыру закрывает ровно
      // так же (chat_screen.dart), десктоп не закрывал никак.
      //
      // Запрос дросселирован пятью минутами на устройство и ничего не ждёт:
      // имя появится на следующей перерисовке ленты.
      widget.controller.warmProfileIdForDeviceSoon(senderDeviceId);
    }
    if (profileId != null && profileId.isNotEmpty) {
      final m = memberNames[profileId];
      if (m != null && m.isNotEmpty) name = m;
    }
    // Secondary: a saved contact for this device.
    if (name == null || name.isEmpty) {
      try {
        final contact = await widget.controller.contactByDeviceId(
          senderDeviceId,
        );
        final dn = (contact?.displayName ?? '').trim();
        if (dn.isNotEmpty) name = dn;
      } catch (_) {}
    }
    if (name != null && name.isNotEmpty) {
      _senderNameCache[senderDeviceId] = name; // cache only resolved names
      return name;
    }
    // Unknown sender → DISTINCT per-device stub (not a shared «Участник»), and
    // NOT cached so it can resolve to a real name later.
    return _deviceFallbackName(senderDeviceId);
  }

  /// Перечень имён участников, перечитываемый не чаще раза в полминуты.
  Future<Map<String, String>> _roomMemberNames() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cached = _roomMemberNamesByProfileId;
    if (cached != null && nowMs - _roomMemberNamesAtMs < 30000) return cached;
    final map = await _loadRoomMemberNames();
    _roomMemberNamesByProfileId = map;
    _roomMemberNamesAtMs = nowMs;
    return map;
  }

  /// Loads the current room's members into a profileId → displayName map.
  Future<Map<String, String>> _loadRoomMemberNames() async {
    final map = <String, String>{};
    try {
      final members = await widget.controller.listRoomMembersDetailed(_convoId);
      _roomMemberCount = members.length;
      _roomMembersById = <String, RoomMember>{
        for (final member in members) member.profileId: member,
      };
      for (final member in members) {
        final dn = member.displayName.trim();
        if (dn.isNotEmpty) map[member.profileId] = dn;
      }
      _mentionTargets = desktopMentionTargets(
        members: members.map(
          (m) => (
            profileId: m.profileId,
            displayName: m.displayName,
            avatarPath: m.avatarPath,
            // Подпись роли только тем, у кого она вправду есть: «участник»
            // у каждого второго — шум, который топит владельца и админов.
            role: roomMemberRoleSubtitle(m.role),
          ),
        ),
        selfProfileId: widget.controller.profileId,
        // «@admins» даём только там, где администраторы есть: пункт, который
        // никого не позовёт, — это обещание, а не пункт.
        withAdmins: members.any((m) => m.isAdmin),
      );
    } catch (_) {
      // best-effort: empty map → callers fall back to contact / device stub
    }
    return map;
  }

  /// Distinct, stable per-device stub for an unidentifiable sender (e.g.
  /// `ab12cd… ef90`). Mirrors mobile's `_authorFallbackFromDevice` so unknown
  /// senders stay visually separable instead of collapsing to one label.
  String _deviceFallbackName(String deviceId) {
    final t = deviceId.trim();
    if (t.isEmpty) return 'Участник';
    if (t.length <= 10) return t;
    return '${t.substring(0, 6)}…${t.substring(t.length - 4)}';
  }

  /// E6: records a message's quote preview so a later reply targeting it can
  /// render «author: snippet». Keyed by the logical [payloadId].
  void _registerReplyPreview(
    String payloadId,
    String author,
    String preview, {
    required bool isImage,
    String authorSeed = '',
  }) {
    _replyPreviewByPayloadId[payloadId] = ReplyPreview(
      authorName: author,
      text: preview,
      isImage: isImage,
      // Цвет цитаты — по устройству автора цитируемого сообщения, тем же
      // ключом, что у телефона.
      authorSeed: authorSeed,
    );
  }

  /// E6: looks up the quote preview for a reply's target payload-event id.
  /// Null (no quote) when the target isn't loaded — graceful, never throws.
  ReplyPreview? _resolveReplyPreview(String? replyToPayloadEventId) {
    if (replyToPayloadEventId == null || replyToPayloadEventId.isEmpty) {
      return null;
    }
    final base = _replyPreviewByPayloadId[replyToPayloadEventId];
    if (base == null) return null;
    // Carry the target id so tapping the quote can jump to the original.
    return ReplyPreview(
      authorName: base.authorName,
      text: base.text,
      isImage: base.isImage,
      targetPayloadId: replyToPayloadEventId,
      // Без этого цитата теряла цвет автора ровно на пути в пузырь.
      authorSeed: base.authorSeed,
    );
  }

  /// Handler for both the bubble's quick-reaction bar and the existing-chip
  /// tap. Mirrors mobile's `_applyReaction` flow: flip locally first
  /// (`toggleMessageReaction`), then broadcast to peer + own other devices
  /// (`broadcastReactionUpdate`).
  ///
  /// PR3.7 (SPRINT2_AUDIT §12): rewritten to skip the slow before/after
  /// `loadMessageReactions` pair we had in PR3.6. We now:
  ///   • Derive `removed` from the in-memory bubble state (`m.reactions`
  ///     already carries `byMe`) — no DB round trip needed to know whether
  ///     the toggle just deleted or just added a row.
  ///   • Optimistically update [_messages] BEFORE the DB write so the chip
  ///     scales in immediately. Mobile's controller-driven `changed` stream
  ///     does this for free; on desktop we have to nudge it ourselves
  ///     because the bubble's pop-in animation is keyed on a count change,
  ///     not on a stream tick.
  ///   • If the DB call throws, we roll back the optimistic update.
  Future<void> _applyReaction(MessageData m, String emoji) async {
    final trimmed = emoji.trim();
    if (trimmed.isEmpty) return;
    final reactionKey = _reactionKeyByMessageId[m.id] ?? m.id;
    final originalReactions = m.reactions;
    final wasMine = originalReactions.any((r) => r.emoji == trimmed && r.byMe);
    // PR3.9 (SPRINT2_AUDIT §14): record this emoji in the «Недавние»
    // SharedPreferences cache so it shows up at the top of the next
    // expanded picker open. Fire-and-forget; persistence failures must
    // not block the reaction itself. Skip when we're _removing_ a
    // reaction (`wasMine` true) — the recents row should reflect what
    // the user actively chose, not what they unchose.
    if (!wasMine) {
      unawaited(DesktopRecentReactionsStore.instance.record(trimmed));
    }
    final optimistic = _withTogglingReaction(originalReactions, trimmed);
    // Optimistic UI: replace the message in-place so the chip appears /
    // disappears instantly. The full _load() at the end will re-sync.
    _replaceMessage(m.id, (cur) => cur.copyWith(reactions: optimistic));
    try {
      await widget.controller.toggleMessageReaction(
        convoId: _convoId,
        eventId: reactionKey,
        emoji: trimmed,
      );
    } catch (e) {
      // Roll back the optimistic change so the UI matches storage.
      if (mounted) {
        _replaceMessage(
          m.id,
          (cur) => cur.copyWith(reactions: originalReactions),
        );
        setState(() => _sendError = 'Не удалось сохранить реакцию: $e');
      }
      return;
    }
    try {
      await widget.controller.broadcastReactionUpdate(
        convoId: _convoId,
        eventId: reactionKey,
        emoji: trimmed,
        removed: wasMine,
      );
    } catch (e) {
      // Broadcast can fail (offline, group policy) without invalidating the
      // local toggle — show a soft banner so the user knows the peer hasn't
      // seen the reaction yet, but keep the local change.
      if (!mounted) return;
      setState(
        () => _sendError =
            'Реакция применена локально, '
            'но не доставлена собеседнику: $e',
      );
    }
    // Full re-sync from storage to pick up authoritative counts (covers
    // peer reactions that arrived while we were toggling).
    unawaited(_load());
  }

  /// Computes the next reactions list after a self-toggle of [emoji]:
  ///   • Already mine → decrement count, drop chip if it hits 0.
  ///   • Not mine → either bump count + flip byMe, or add a brand-new chip.
  /// Preserves order so the row doesn't shuffle.
  List<bubble.MessageReaction> _withTogglingReaction(
    List<bubble.MessageReaction> current,
    String emoji,
  ) {
    final out = <bubble.MessageReaction>[];
    var matched = false;
    for (final r in current) {
      if (r.emoji != emoji) {
        out.add(r);
        continue;
      }
      matched = true;
      if (r.byMe) {
        if (r.count > 1) {
          out.add(
            bubble.MessageReaction(
              emoji: r.emoji,
              count: r.count - 1,
              byMe: false,
            ),
          );
        }
        // count == 1 → my reaction was the only one; drop the chip.
      } else {
        out.add(
          bubble.MessageReaction(
            emoji: r.emoji,
            count: r.count + 1,
            byMe: true,
          ),
        );
      }
    }
    if (!matched) {
      out.add(bubble.MessageReaction(emoji: emoji, count: 1, byMe: true));
    }
    return out;
  }

  void _replaceMessage(String id, MessageData Function(MessageData) update) {
    final idx = _messages.indexWhere((x) => x.id == id);
    if (idx < 0) return;
    final next = List<MessageData>.from(_messages);
    next[idx] = update(_messages[idx]);
    setState(() => _messages = next);
  }

  bool _isHiddenControlText(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    if (t.startsWith('__secretly_')) return true;
    if (CallSignalCommandCodec.isEncodedText(t)) return true;
    return false;
  }

  /// 2026-05-20 PR-B (BUG-10.5): walk a list of [ChatEvent]s, decrypt
  /// each MsgEventV1, and add any `__secretly_delete__:` referenced
  /// payload-event-ids to [_deletedPayloadEventIds]. Subsequent rendering
  /// passes skip rows whose payloadEventId is in the set so a delete-for-
  /// everyone command authored on mobile (or fanned out via self-mirror)
  /// actually tombstones the messages on desktop too. The helper is
  /// additive — it never removes ids that a previous pass found — which
  /// is what allows "Load older" pages to correctly drop messages that a
  /// later delete command already tombstoned in the current window.
  ///
  /// Cost note: each call walks every event and re-decrypts the payload,
  /// duplicating the work `_toMessageData` will do shortly after.
  /// Acceptable for chat-open and incremental pagination (50-100 events
  /// per call). If profiling ever flags this as hot, refactor `_load` to
  /// resolve payloads once into a map and thread them into both passes.
  Future<void> _collectDeletedPayloadEventIds(List<ChatEvent> events) async {
    for (final event in events) {
      final payload = await widget.controller.payloadEventForChatEvent(event);
      if (payload is! MsgEventV1) continue;
      final text = payload.text.trim();
      if (text.isEmpty) continue;
      if (!isDeleteForAllCommandText(text)) continue;
      final ids = parseDeleteForAllCommand(text);
      if (ids.isEmpty) continue;
      _deletedPayloadEventIds.addAll(ids);
    }
  }

  /// PR8: map a MIME type to the bubble's attachment kind. Mirrors mobile's
  /// `_isVoiceMessageMime` so voice notes (recorded inside the app) render
  /// as the play-button bubble, while shared mp3 / m4a tracks fall through
  /// to the generic audio / file bubble.

  /// 🔴 ТЕГИ ПЕСНИ ИЗ СКАЧАННОГО ФАЙЛА (17.09.2026).
  ///
  /// В прежних сообщениях — и во всех песнях с iPhone, где теги не читались,
  /// — названия и исполнителя нет, и песня была подписана именем файла. Когда
  /// файл уже скачан, их можно прочитать из него самого, как это делает
  /// телефон. Ключ — blobId; `null` — читали, тегов нет (второй раз не читаем).
  final Map<String, MusicTags?> _probedMusicTags = <String, MusicTags?>{};

  MessageAttachment _withProbedMusicTags(
    MessageAttachment attachment,
    AttachmentEventV1 payload, {
    required String messageId,
    String? cachedPath,
  }) {
    if (attachment.kind != MessageAttachmentKind.audio ||
        attachment.musicTitle != null) {
      return attachment;
    }
    final probed = _probedMusicTags[payload.blobId];
    if (probed != null) {
      return attachment.copyWith(
        musicTitle: probed.title,
        musicArtist: probed.artist,
      );
    }
    if (cachedPath != null) {
      _probeMusicTagsIfUntagged(messageId, payload, cachedPath);
    }
    return attachment;
  }

  void _probeMusicTagsIfUntagged(
    String messageId,
    AttachmentEventV1 payload,
    String path,
  ) {
    if (desktopAttachmentKind(payload) != MessageAttachmentKind.audio ||
        taggedMusicTitle(payload) != null) {
      return;
    }
    final blobId = payload.blobId;
    if (_probedMusicTags.containsKey(blobId)) return;
    _probedMusicTags[blobId] = null;
    unawaited(() async {
      final tags = await MusicTagReader.read(path);
      if (tags == null || !mounted) return;
      _probedMusicTags[blobId] = tags;
      _replaceMessage(messageId, (cur) {
        final att = cur.attachment;
        if (att == null || att.blobId != blobId) return cur;
        return cur.copyWith(
          attachment: att.copyWith(
            musicTitle: tags.title,
            musicArtist: tags.artist,
          ),
        );
      });
    }());
  }

  /// PR8: kick a background download/decrypt for an attachment whose blob
  /// is not yet on disk. Once the file lands we patch the corresponding
  /// [MessageData] in [_messages] so the bubble flips from spinner →
  /// rendered image / playable voice note without a full thread reload.
  void _kickAttachmentFetch(String messageId, AttachmentEventV1 a) {
    final key = a.blobId;
    if (_attachmentFetchInFlight.contains(key)) return;
    _attachmentFetchInFlight.add(key);
    unawaited(() async {
      File? file;
      try {
        file = await widget.controller.ensureCachedAttachmentFile(a);
      } catch (_) {
        file = null;
      }
      if (!mounted) {
        _attachmentFetchInFlight.remove(key);
        return;
      }
      _attachmentFetchInFlight.remove(key);
      final fetched = file;
      if (fetched != null) {
        _probeMusicTagsIfUntagged(messageId, a, fetched.path);
      }
      _replaceMessage(messageId, (cur) {
        final att = cur.attachment;
        if (att == null || att.blobId != key) return cur;
        // copyWith preserves payloadId / timestampMs / callEvent / isRu /
        // isTextMessage — a field-by-field rebuild here silently dropped them,
        // breaking date separators and reply/edit/delete targeting for
        // lazily-rehydrated attachments.
        return cur.copyWith(
          attachment: att.copyWith(
            filePath: file?.path,
            loading: false,
            failed: file == null,
          ),
        );
      });
    }());
  }

  /// «Загрузить» у файла или повтор неудавшейся загрузки снимка.
  void _downloadAttachment(MessageData m) {
    final payload = _attachmentsByMessageId[m.id];
    if (payload == null) return;
    _replaceMessage(m.id, (cur) {
      final att = cur.attachment;
      if (att == null) return cur;
      return cur.copyWith(
        attachment: att.copyWith(loading: true, failed: false),
      );
    });
    _kickAttachmentFetch(m.id, payload);
  }

  /// «Показать в Finder»: копия в «Загрузки/Secretly» и Finder на ней.
  Future<void> _revealAttachment(MessageData m) async {
    final payload = _attachmentsByMessageId[m.id];
    if (payload == null) return;
    try {
      final cached = await widget.controller.ensureCachedAttachmentFile(
        payload,
      );
      final name = suggestedAttachmentFileName(
        fileName: payload.filename,
        mime: payload.mime,
        blobId: payload.blobId,
      );
      final copy = await exportAttachmentToDownloads(cached, name);
      await revealInFileManager(copy.path);
    } catch (_) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Не удалось показать файл в Finder',
        kind: DSnackKind.error,
      );
    }
  }

  /// PR8: build the ordered voice-note queue for this thread so tapping
  /// any voice bubble plays through to the next note (Telegram parity).
  /// Returns the queue and the index of [messageId] inside it. If the
  /// message id isn't in the queue (e.g. payload no longer cached) we
  /// return `(queue: [single], index: 0)` so playback at least starts.
  /// Display title for a shared-audio track: voice notes are «Голосовое»;
  /// music/audio files use their filename (or «Аудио»).
  String _audioTrackTitle(AttachmentEventV1 payload) {
    final kind = desktopAttachmentKind(payload);
    if (kind == MessageAttachmentKind.audio) {
      final probed = _probedMusicTags[payload.blobId];
      final title = taggedMusicTitle(payload) ?? probed?.title ?? '';
      final artist = taggedMusicArtist(payload) ?? probed?.artist ?? '';
      if (title.isNotEmpty) {
        return artist.isNotEmpty ? '$artist — $title' : title;
      }
      final fn = (payload.filename ?? '').trim();
      return fn.isNotEmpty ? fn : 'Аудио';
    }
    return 'Голосовое';
  }

  ({List<SharedAudioTrack> queue, int index}) _buildVoiceQueueFor(
    String messageId,
  ) {
    final tracks = <SharedAudioTrack>[];
    var targetIndex = -1;
    for (final msg in _messages) {
      final att = msg.attachment;
      // Queue both voice notes and music/audio files so seek-next/prev jumps
      // between any playable audio in the thread.
      if (att == null ||
          (att.kind != MessageAttachmentKind.voice &&
              att.kind != MessageAttachmentKind.audio)) {
        continue;
      }
      final payload = _attachmentsByMessageId[msg.id];
      if (payload == null) continue;
      if (msg.id == messageId) targetIndex = tracks.length;
      final controller = widget.controller;
      tracks.add(
        SharedAudioTrack(
          trackId: att.payloadEventId,
          kind: SharedAudioTrackKind.attachment,
          title: _audioTrackTitle(payload),
          artist: msg.authorName,
          sourceBlobId: att.blobId,
          sourceConvoId: _convoId,
          resolveFilePath: () async {
            final f = await controller.ensureCachedAttachmentFile(payload);
            return f.path;
          },
        ),
      );
    }
    if (targetIndex < 0) {
      // Standalone fallback — single-track queue with the tapped note.
      final att = _attachmentsByMessageId[messageId];
      if (att != null) {
        final controller = widget.controller;
        return (
          queue: <SharedAudioTrack>[
            SharedAudioTrack(
              trackId: att.eventId,
              kind: SharedAudioTrackKind.attachment,
              title: _audioTrackTitle(att),
              artist: '',
              sourceBlobId: att.blobId,
              sourceConvoId: _convoId,
              resolveFilePath: () async {
                final f = await controller.ensureCachedAttachmentFile(att);
                return f.path;
              },
            ),
          ],
          index: 0,
        );
      }
      return (queue: const <SharedAudioTrack>[], index: 0);
    }
    return (queue: tracks, index: targetIndex);
  }

  /// PR8: bubble's `onOpenImage` callback. Walks every image attachment in
  /// the current thread to build a swipe-able gallery, finds the tapped
  /// message inside it, and opens the fullscreen viewer at that index.
  Future<void> _openImage(MessageData tapped) async {
    final att = tapped.attachment;
    if (att == null || att.kind != MessageAttachmentKind.image) return;
    final items = <DesktopPhotoItem>[];
    var targetIndex = -1;
    for (final msg in _messages) {
      final a = msg.attachment;
      if (a == null || a.kind != MessageAttachmentKind.image) continue;
      final payload = _attachmentsByMessageId[msg.id];
      if (payload == null) continue;
      if (msg.id == tapped.id) targetIndex = items.length;
      items.add(
        DesktopPhotoItem(
          messageId: msg.id,
          attachment: payload,
          authorName: msg.authorName,
          timeLabel: msg.time,
          caption: msg.text,
        ),
      );
    }
    if (items.isEmpty || targetIndex < 0) return;
    if (!mounted) return;
    await DesktopPhotoViewer.show(
      context: context,
      controller: widget.controller,
      items: items,
      initialIndex: targetIndex,
    );
  }

  /// Bubble's video tap → fullscreen desktop video player. Resolves (fetching
  /// if needed) the cached blob, then hands the File to [DesktopVideoViewer].
  Future<void> _openVideo(MessageData tapped) async {
    final att = tapped.attachment;
    if (att == null || att.kind != MessageAttachmentKind.video) return;
    final payload = _attachmentsByMessageId[tapped.id];
    if (payload == null) return;
    File file;
    try {
      file = await widget.controller.ensureCachedAttachmentFile(payload);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = 'Не удалось открыть видео: $e');
      return;
    }
    if (!mounted) return;
    if (!file.existsSync()) {
      setState(() => _sendError = 'Видео недоступно');
      return;
    }
    await DesktopVideoViewer.show(
      context: context,
      file: file,
      authorName: tapped.authorName,
      timeLabel: tapped.time,
      filename: payload.filename,
    );
  }

  /// PR8: bubble's `onOpenFile` callback. Falls back to the system default
  /// app via `launchUrl(Uri.file(...))`. If the blob isn't cached yet we
  /// trigger a fetch + show a "Загрузка…" hint.
  /// «Сохранить как…» для вложения из ленты.
  ///
  /// Диалог и запись — общая `saveAttachmentAs`, та же, что у просмотрщика
  /// фотографий. Здесь только доставание файла (его может ещё не быть на
  /// диске) и рассказ о результате тем же способом, каким эта секция
  /// рассказывает об остальных неудачах.
  Future<void> _saveAttachment(MessageData tapped) async {
    final att = tapped.attachment;
    final payload = _attachmentsByMessageId[tapped.id];
    if (att == null || payload == null) return;
    File? file;
    try {
      file = await widget.controller.ensureCachedAttachmentFile(payload);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = 'Не удалось получить файл: $e');
      return;
    }
    if (!mounted) return;
    final outcome = await saveAttachmentAs(
      file: file,
      suggestedName: suggestedAttachmentFileName(
        fileName: att.fileName,
        mime: att.mime,
        blobId: att.blobId,
      ),
      dialogTitle: 'Сохранить вложение',
    );
    if (!mounted) return;
    switch (outcome.result) {
      case AttachmentSaveResult.unavailable:
        setState(() => _sendError = 'Файл недоступен');
      case AttachmentSaveResult.failed:
        setState(() => _sendError = 'Не удалось сохранить: ${outcome.error}');
      case AttachmentSaveResult.saved:
      case AttachmentSaveResult.cancelled:
        break;
    }
  }

  Future<void> _openFile(MessageData tapped) async {
    final att = tapped.attachment;
    if (att == null) return;
    final payload = _attachmentsByMessageId[tapped.id];
    if (payload == null) return;
    File? file;
    try {
      file = await widget.controller.ensureCachedAttachmentFile(payload);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = 'Не удалось открыть файл: $e');
      return;
    }
    if (!mounted) return;
    if (!file.existsSync()) {
      setState(() => _sendError = 'Файл недоступен');
      return;
    }
    // 🔴 СВОЙ ПРОСМОТР ВПЕРЕДИ ЧУЖОЙ ПРОГРАММЫ (19.09.2026). Отдать документ
    // наружу значит отдать РАСШИФРОВАННЫЙ файл другому приложению: он попадёт
    // в его список недавних и в его кэш. PDF и простой текст показываем сами;
    // «Открыть в программе» остаётся кнопкой, то есть решением человека.
    final shownName = suggestedAttachmentFileName(
      fileName: att.fileName,
      mime: att.mime,
      blobId: att.blobId,
    );
    final kind = desktopViewerKindFor(
      mime: att.mime,
      fileName: shownName,
      sizeBytes: att.sizeBytes,
      canRenderPdf: DesktopPdfBridge.isAvailable,
    );
    if (kind != DesktopViewerKind.external_) {
      final opened = file;
      await DesktopDocumentViewer.show(
        context: context,
        file: opened,
        title: shownName,
        kind: kind,
        onOpenExternally: () => _openFileExternally(att, opened),
        onSaveAs: () => _saveAttachment(tapped),
      );
      return;
    }
    await _openFileExternally(att, file);
  }

  /// Отдать файл внешней программе — временной копией под настоящим именем.
  Future<void> _openFileExternally(MessageAttachment att, File file) async {
    try {
      // Внешней программе отдаём временную копию под настоящим именем, а не
      // файл из кэша: у кэшированного имя вида `<идентификатор>.bin`, и
      // система не знала, чем его открыть (см. `attachmentOpenCopy`).
      final opening = await attachmentOpenCopy(
        file: file,
        suggestedName: suggestedAttachmentFileName(
          fileName: att.fileName,
          mime: att.mime,
          blobId: att.blobId,
        ),
        blobId: att.blobId,
      );
      if (!mounted) return;
      final ok = await launchUrl(
        Uri.file(opening.path),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        setState(() => _sendError = 'Не удалось открыть файл');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = 'Не удалось открыть: $e');
    }
  }

  /// Перемотка звучащего голосового долей 0..1.
  ///
  /// Длину берём у САМОГО ПЛЕЕРА, а не из подсказки во вложении: подсказка
  /// приходит от отправителя и может разойтись с файлом на пару секунд, и
  /// тогда нажатие в конец волны уезжало бы мимо конца записи.
  Future<void> _seekVoice(double fraction) async {
    final state = widget.controller.sharedAudioPlayback.value;
    final total = state.duration;
    if (total <= Duration.zero) return;
    final f = fraction.clamp(0.0, 1.0);
    await widget.controller.seekSharedAudio(
      Duration(milliseconds: (total.inMilliseconds * f).round()),
    );
  }

  /// PR8: bubble's `onToggleVoice` callback. Builds the convo's full voice
  /// queue (so seekprev / seeknext jump between notes) and forwards to the
  /// shared audio player. Errors are surfaced via [_sendError].
  Future<void> _toggleVoice(MessageData tapped) async {
    final att = tapped.attachment;
    if (att == null ||
        (att.kind != MessageAttachmentKind.voice &&
            att.kind != MessageAttachmentKind.audio)) {
      return;
    }
    final built = _buildVoiceQueueFor(tapped.id);
    if (built.queue.isEmpty) return;
    try {
      await widget.controller.toggleSharedAudioTrack(
        queue: built.queue,
        index: built.index,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = 'Не удалось воспроизвести: $e');
    }
  }

  String _hhmm(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// E11: group/room call — reuse the real LiveKit [RoomCallScreen] (the same
  /// screen mobile uses) instead of a desktop mockup. Pushed as a route over
  /// the shell.
  void _startRoomCall() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DesktopRoomCallWindow(
          vm: widget.vm,
          groupId: _convoId,
          title: widget.conversation.title,
        ),
      ),
    );
  }

  Future<void> _startCall({required bool video}) async {
    final pid = _peerProfileId;
    if (pid == null || pid.isEmpty || !_isDirect) {
      // Groups/rooms route through the LiveKit room call instead.
      if (!_isDirect) {
        _startRoomCall();
        return;
      }
      setState(() {
        _sendError = 'Не удалось определить собеседника для звонка.';
      });
      return;
    }
    final cm = CallManager.instance;
    if (cm == null) {
      setState(() => _sendError = 'Сервис звонков не готов.');
      return;
    }
    if (cm.state.value.isActive) {
      setState(() => _sendError = 'Звонок уже идёт.');
      return;
    }
    setState(() => _sendError = null);
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
      setState(() => _sendError = e.toString());
    }
  }

  /// E9 typing-out: emit a throttled «typing» signal to the peer (1:1 only —
  /// the controller's sendTypingState is peer-addressed). Re-sends at most once
  /// per 2s while the user keeps typing; arms a 3s idle timer to send «stop».
  void _onTypingActivity() {
    if (!_isDirect) return;
    final pid = _peerProfileId;
    if (pid == null || pid.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTypingSentMs > 2000) {
      _lastTypingSentMs = now;
      _typingActive = true;
      unawaited(
        widget.controller.sendTypingState(
          peerProfileId: pid,
          convoId: _convoId,
          typing: true,
        ),
      );
    }
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  /// Sends «stop typing» if we'd announced typing. Safe to call repeatedly.
  void _stopTyping() {
    _typingStopTimer?.cancel();
    _typingStopTimer = null;
    if (!_typingActive) return;
    _typingActive = false;
    _lastTypingSentMs = 0;
    final pid = _peerProfileId;
    if (_isDirect && pid != null && pid.isNotEmpty) {
      unawaited(
        widget.controller.sendTypingState(
          peerProfileId: pid,
          convoId: _convoId,
          typing: false,
        ),
      );
    }
  }

  Future<void> _send(DesktopComposerSubmission submission) async {
    // Stop the typing indicator the moment we send.
    _stopTyping();
    final trimmed = submission.text.trim();
    if (trimmed.isEmpty) return;

    // Edit path: route through editTextMessage (mutates the existing message +
    // broadcasts the edit) instead of sending a brand-new message. Works for
    // 1:1 here; group editing rides the same controller call and is unblocked
    // once group send lands (E8).
    final editId = submission.editPayloadEventId;
    if (editId != null && editId.isNotEmpty) {
      setState(() => _sendError = null);
      try {
        final ok = await widget.controller.editTextMessage(
          convoId: _convoId,
          payloadEventId: editId,
          text: trimmed,
          // 🔴 Разметку упоминаний надо пересобрать и при правке. Без неё
          // изменённое сообщение уходило с ПУСТЫМ списком: подсветка и
          // значок пропадали и здесь, и на телефоне (правка зеркалится на
          // свои устройства). Тот же разбор, что у нового сообщения ниже.
          mentions: desktopResolveMentions(
            text: trimmed,
            targets: _mentionTargets,
          ),
        );
        if (!ok && mounted) {
          setState(() => _sendError = 'Не удалось изменить сообщение.');
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _sendError = e.toString());
      }
      return;
    }

    setState(() => _sendError = null);
    try {
      if (_isDirect) {
        final pid = _peerProfileId;
        if (pid == null || pid.isEmpty) {
          setState(() => _sendError = 'Не удалось определить получателя.');
          return;
        }
        await widget.controller.sendMessage(
          peerProfileId: pid,
          text: trimmed,
          replyToPayloadEventId: submission.replyToPayloadEventId,
          // 🔴 «Отправить позже» — тем же вызовом (16.09.2026). Контроллер
          // сам кладёт местную заготовку и отпускает её в срок, переживая
          // перезапуск окна; здесь нечего добавлять, кроме самого времени.
          scheduledAtMs: submission.scheduledAtMs,
          // Карточку ссылки готовит отправитель — и уходит она в сообщении.
          linkPreview: submission.linkPreview,
        );
      } else {
        // Group / room send (E8): same controller path mobile uses. Room
        // policy (read-only rooms, non-membership) is enforced inside
        // sendGroupMessage and surfaces here as a thrown error → _sendError.
        await widget.controller.sendGroupMessage(
          groupId: _convoId,
          text: trimmed,
          replyToPayloadEventId: submission.replyToPayloadEventId,
          // 🔴 Разметка упоминаний — ТЕМ ЖЕ разбором, что у телефона
          // (`resolveChatMessageMentions`), то есть смещения и правила границ
          // совпадают по определению. Без неё «@Игорь» уходил обычным
          // текстом: ни подсветки, ни значка, ни уведомления у того, кого
          // позвали.
          mentions: desktopResolveMentions(
            text: trimmed,
            targets: _mentionTargets,
          ),
          // Send into the branch the user is standing in. null = «Общий»,
          // which is also what every pre-topics message carries.
          topicId: _currentTopicId,
          scheduledAtMs: submission.scheduledAtMs,
          linkPreview: submission.linkPreview,
        );
      }
      // controller.changed will refresh _messages.
    } catch (e) {
      if (!mounted) return;
      await _handleSendFailure(
        e,
        text: trimmed,
        replyToPayloadEventId: submission.replyToPayloadEventId,
        linkPreview: submission.linkPreview,
      );
    }
  }

  /// Непроверенный собеседник — это РАЗГОВОР, а не строка ошибки.
  ///
  /// 🔴 До 13.09 на десктопе это был тупик. Настройка «блокировать отправку
  /// непроверенным» на десктопе ЕСТЬ, а способа проверить контакта не было ни
  /// одного: человек включал переключатель у себя же в настройках и терял
  /// возможность писать, получая «Bad state: Contact is unverified».
  ///
  /// Разговор и экран проверки берём у телефона целиком: `VerifyContactScreen`
  /// принимает только контроллер и сам себе Scaffold. Своя реализация сверки
  /// кодов безопасности — последнее, что стоит писать дважды.
  ///
  Future<void> _handleSendFailure(
    Object error, {
    required String text,
    String? replyToPayloadEventId,
    LinkPreviewV1? linkPreview,
  }) async {
    final peer = _peerProfileId;
    final unverified =
        error is StateError &&
        error.message.toString().startsWith('Contact is unverified');
    if (!unverified || peer == null || peer.isEmpty) {
      if (mounted) setState(() => _sendError = _humanError(error));
      return;
    }

    // 🔴 Подписи берём из ОБЩЕЙ локализации, а не пишем свои.
    //
    // Эти строки уже существуют и переведены — телефон показывает ровно их.
    // Написать рядом свои означало бы: второй перевод, второй тон, и
    // расхождение на первой же правке текста. Плюс десктоп получил бы русский
    // текст в английском интерфейсе.
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      setState(() => _sendError = _humanError(error));
      return;
    }
    final strict = widget.controller.blockUnverified;
    final choice = await DesktopDialog.show<String>(
      context,
      title: strict ? l10n.verifyRequired : l10n.safetyNumberChangedTitle,
      size: DDialogSize.small,
      body: Text(
        strict ? l10n.safetyNumberStrictBody : l10n.safetyNumberChangedBody,
        style: DType.body.copyWith(color: DColors.of(context).textSecondary),
      ),
      primary: DDialogAction(
        label: l10n.verify,
        onPressed: () => Navigator.of(context).maybePop('verify'),
      ),
      // «Отправить всё равно» НЕ предлагается в строгом режиме: человек сам
      // включил блокировку, и кнопка, обходящая её, обессмыслила бы настройку.
      // Правило повторяется за телефоном дословно.
      secondary: strict
          ? null
          : DDialogAction(
              label: l10n.sendAnyway,
              onPressed: () => Navigator.of(context).maybePop('send'),
            ),
    );
    if (!mounted) return;

    if (choice == 'verify') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VerifyContactScreen(
            controller: widget.controller,
            peerProfileId: peer,
            title: widget.conversation.title,
          ),
        ),
      );
      return;
    }
    if (choice != 'send') return;

    try {
      await widget.controller.approveUnverifiedContactDevices(peer);
      await widget.controller.sendMessage(
        peerProfileId: peer,
        text: text,
        replyToPayloadEventId: replyToPayloadEventId,
        linkPreview: linkPreview,
      );
    } catch (retryError) {
      if (!mounted) return;
      setState(() => _sendError = _humanError(retryError));
    }
  }

  /// Человеческий текст ошибки вместо `e.toString()`.
  ///
  /// Тот же переводчик, что и на телефоне: «Bad state: Contact is unverified»
  /// человеку ничего не сообщает, а показывалось именно это.
  String _humanError(Object error) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return error.toString();
    try {
      // 🔴 ОТКАЗ КОМНАТЫ — ЭТО НЕ «ошибка отправки» (13.09.2026).
      //
      // Комната отказывает по правилам: писать могут только админы, текст
      // выключен, медленный режим, вас исключили. Общий разборщик про эти
      // причины не знает и сводил их все к `sendFailed(error.toString())` —
      // то есть человек видел под полем ввода текст исключения Dart вместо
      // ответа, что именно ему нельзя. Разбор уже написан и переведён, им же
      // пользуется телефон.
      final policy = tryRoomPolicyErrorText(l10n, error);
      if (policy != null) return policy;
      return directMessageErrorText(l10n, error);
    } catch (_) {
      return error.toString();
    }
  }

  /// Deletes [m] after a for-me / for-everyone confirm.
  ///
  /// • **Delete for me** removes the local DB row by its wrapper [MessageData.id]
  ///   via `deleteEventsLocal` — desktop-local only.
  /// • **Delete for everyone** (own messages, 1:1) additionally sends the
  ///   `__secretly_delete__` control command (`buildDeleteForAllCommand`) over
  ///   the normal message path so the peer tombstones it too — mirroring
  ///   `chat_screen.dart` mobile semantics. Own-other-device mirroring is the
  ///   E18 sync-correctness item and is tracked separately.
  Future<void> _deleteMessage(MessageData m) => _deleteMessages([m]);

  /// Удаляет [messages] после одного вопроса «у меня / у всех».
  ///
  /// 🔴 ПАЧКОЙ — ОДНИМ ВОПРОСОМ И ОДНОЙ КОМАНДОЙ (16.09.2026). «У всех»
  /// касается только СВОИХ сообщений: их идентификаторы уходят одной
  /// командой удаления (`buildDeleteForAllCommand` принимает список — так же
  /// удаляет пачку телефон). Чужие при этом удаляются только здесь, о чём
  /// диалог говорит прямо.
  Future<void> _deleteMessages(List<MessageData> messages) async {
    if (messages.isEmpty) return;
    final pid = _peerProfileId;
    final isGroup = !_isDirect;
    final ownPayloadIds = <String>[
      for (final m in messages)
        if (m.isSelf) m.payloadId ?? m.id,
    ];
    final canForEveryone =
        ownPayloadIds.isNotEmpty &&
        ((_isDirect && pid != null && pid.isNotEmpty) || isGroup);
    final single = messages.length == 1;
    final mixed = canForEveryone && ownPayloadIds.length < messages.length;

    final choice = await DesktopDialog.show<String>(
      context,
      title: single ? 'Удалить сообщение?' : 'Удалить выбранные сообщения?',
      size: DDialogSize.small,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mixed) ...[
            Text(
              'Чужие сообщения удалятся только у вас.',
              style: DType.caption.copyWith(
                color: DColors.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: DSpace.m),
          ],
          if (canForEveryone) ...[
            DesktopButton(
              label: 'Удалить у всех',
              kind: DButtonKind.danger,
              expand: true,
              onPressed: () => Navigator.of(context).maybePop('all'),
            ),
            const SizedBox(height: DSpace.s),
          ],
          DesktopButton(
            label: canForEveryone ? 'Удалить только у меня' : 'Удалить у меня',
            kind: DButtonKind.tonal,
            expand: true,
            onPressed: () => Navigator.of(context).maybePop('me'),
          ),
        ],
      ),
      secondary: DDialogAction(
        label: 'Отмена',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );

    if (choice != 'me' && choice != 'all') return;
    if (!mounted) return;

    try {
      if (choice == 'all' && canForEveryone) {
        // Broadcast the tombstone FIRST. If the send is rejected (e.g. a
        // read-only room throws), we bail before the local delete so the
        // message doesn't vanish for the sender only.
        final cmd = buildDeleteForAllCommand(ownPayloadIds);
        if (isGroup) {
          await widget.controller.sendGroupMessage(
            groupId: _convoId,
            text: cmd,
          );
        } else {
          await widget.controller.sendMessage(peerProfileId: pid!, text: cmd);
        }
      }
      await widget.controller.deleteEventsLocal(
        convoId: _convoId,
        eventIds: [for (final m in messages) m.id],
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = e.toString());
    }
  }

  /// F-01/F-03: forwards [m] into another conversation.
  ///
  /// Wire format is the shared `__secretly_forward__` command
  /// (`buildForwardCommand`) — the SAME one mobile emits — so the recipient
  /// (mobile or desktop) renders it with a proper "переслано от …" attribution
  /// instead of a bare copy. Re-forwarding something that already arrived as a
  /// forward keeps the ORIGINAL author, so the chain never rewrites authorship.
  ///
  /// Text-only for now; the context menu gates the item accordingly (media
  /// forwards need the blob re-uploaded into the target conversation, which is
  /// a later slice).
  /// «Сохранить» — переслать сообщение В ПЕРЕПИСКУ С САМИМ СОБОЙ.
  ///
  /// 🔴 Отдельного хранилища «сохранённых» в проекте нет и не нужно:
  /// «Избранное» — обычная переписка с собой, она уже синхронизируется с
  /// телефоном и умеет всё, что умеет чат (поиск, вложения, закрепление).
  /// Заводить рядом вторую сущность значило бы держать два списка, которые
  /// разойдутся.
  ///
  /// Путь тот же, что у пересылки, — включая проверку приватности источника:
  /// человек, запретивший пересылать свои сообщения, запретил это и «себе в
  /// закладки». Отличие ровно одно: получателя не спрашивают.
  /// «Сохранить» — та же пересылка, но получатель всегда я.
  ///
  /// Виды сообщений те же, что у пересылки (16.09.2026): текст, наклейка,
  /// вложение. Раньше сохранялся только текст — и «Избранное» на компьютере
  /// не могло принять ни снимка, ни голосового, хотя на телефоне принимает.
  Future<void> _saveMessage(MessageData m) => _saveMessages([m]);

  /// «Сохранить» для пачки: каждое сообщение — себе, в порядке переписки.
  Future<void> _saveMessages(List<MessageData> messages) async {
    final myPid = widget.controller.profileId.trim();
    if (myPid.isEmpty) return;
    final r = await _forwardableOf(messages);
    if (!mounted) return;
    if (r.allowed.isEmpty) {
      if (r.blocked > 0) {
        DesktopSnackbar.show(
          context,
          message:
              'Это сообщение нельзя сохранить из-за ограничений приватности.',
          kind: DSnackKind.warning,
        );
      }
      return;
    }
    var noFile = 0;
    try {
      for (final m in r.allowed) {
        final sent = await _sendForwardedCopy(m, peerProfileId: myPid);
        if (sent == _CopyOutcome.noFile) noFile++;
      }
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Не удалось сохранить: $e',
        kind: DSnackKind.error,
      );
      return;
    }
    if (!mounted) return;
    if (noFile == r.allowed.length) {
      DesktopSnackbar.show(
        context,
        message: 'Вложение не скачано — сохранять нечего',
        kind: DSnackKind.warning,
      );
      return;
    }
    final partial = noFile > 0 || r.blocked > 0;
    DesktopSnackbar.show(
      context,
      message: partial
          ? 'Сохранено в «Избранное», но не всё'
          : 'Сохранено в «Избранное»',
      kind: partial ? DSnackKind.warning : DSnackKind.success,
    );
  }

  /// 🔴 ПЕРЕСЫЛАЛСЯ ТОЛЬКО ТЕКСТ (до 16.09.2026).
  ///
  /// Пункт «Переслать» просто НЕ ПОКАЗЫВАЛСЯ у снимка, голосового, файла и
  /// наклейки — правило «не показывать то, что всё равно откажет» соблюдено,
  /// но на телефоне всё это пересылается давно. То есть одно и то же меню на
  /// двух устройствах предлагало разное, и человек, привыкший пересылать
  /// фотографии с телефона, на компьютере молча не находил пункта.
  ///
  /// Теперь три случая, и каждый уходит своим путём:
  ///   • текст — командой пересылки, с подписью «от кого» (как было);
  ///   • наклейка — тем же вызовом, что и отправка новой;
  ///   • вложение — файлом из кэша, тем же путём, что перетаскивание.
  ///
  /// 🔴 ВЛОЖЕНИЕ ПЕРЕЗАЛИВАЕТСЯ, А НЕ ПЕРЕССЫЛАЕТСЯ ССЫЛКОЙ НА ТОТ ЖЕ БЛОБ, И
  /// ЭТО НАМЕРЕННО. Отдать чужому получателю тот же blob значило бы показать
  /// серверу один файл в двух переписках — то есть сам факт пересылки. Телефон
  /// экономит на этом ровно в одном случае: пересылка САМОМУ СЕБЕ. Здесь такой
  /// оптимизации пока нет, и это честнее оставить так, чем угадать.
  Future<void> _forwardMessage(MessageData m) => _forwardMessages([m]);

  /// Пересылка пачки: получатель выбирается ОДИН раз, сообщения уходят в
  /// порядке переписки.
  Future<void> _forwardMessages(List<MessageData> messages) async {
    final r = await _forwardableOf(messages);
    if (!mounted) return;
    if (r.allowed.isEmpty) {
      // Проверка приватности — ДО выбора получателя: спросить «куда» и потом
      // отказать было бы хуже, чем отказать сразу.
      if (r.blocked > 0) {
        DesktopSnackbar.show(
          context,
          message:
              'Это сообщение нельзя переслать из-за ограничений приватности.',
          kind: DSnackKind.warning,
        );
      }
      return;
    }

    final target = await ForwardTargetDialog.show(
      context,
      controller: widget.controller,
      excludeConvoId: _convoId,
    );
    if (target == null || !mounted) return;

    final targetPid = target.peerProfileId;
    final toGroup = targetPid == null || targetPid.isEmpty;
    var noFile = 0;
    try {
      for (final m in r.allowed) {
        final sent = await _sendForwardedCopy(
          m,
          peerProfileId: toGroup ? null : targetPid,
          groupId: toGroup ? target.convoId : null,
        );
        if (sent == _CopyOutcome.noFile) noFile++;
      }
    } catch (e) {
      if (!mounted) return;
      DesktopSnackbar.show(
        context,
        message: 'Не удалось переслать: $e',
        kind: DSnackKind.error,
      );
      return;
    }
    if (!mounted) return;
    if (noFile == r.allowed.length) {
      // Файла на этом устройстве нет и достать его неоткуда — сказать об
      // этом честнее, чем отправить пустоту.
      DesktopSnackbar.show(
        context,
        message: 'Вложение не скачано — переслать нечего',
        kind: DSnackKind.warning,
      );
      return;
    }
    final partial = noFile > 0 || r.blocked > 0;
    DesktopSnackbar.show(
      context,
      message: partial
          ? 'Переслано в «${target.title}», но не всё'
          : 'Переслано в «${target.title}»',
      kind: partial ? DSnackKind.warning : DSnackKind.success,
    );
  }

  /// Чьё сообщение пересылают — для проверки приватности источника.
  ///
  /// Своё — `null`. Чужое в личной переписке — собеседник. В КОМНАТЕ — автор
  /// самого сообщения: раньше здесь для комнаты стоял `null`, то есть «моё», и
  /// запрет автора на пересылку в комнатах не проверялся вовсе. Телефон
  /// проверяет именно автора (`resolveSourceProfileId`).
  String? _sourceProfileIdOf(MessageData m) {
    if (m.isSelf) return null;
    if (_isDirect) return _peerProfileId;
    final pid = (m.authorProfileId ?? '').trim();
    return pid.isEmpty ? null : pid;
  }

  /// Что из [messages] можно переслать: есть что слать, и автор не запретил.
  Future<({List<MessageData> allowed, int blocked})> _forwardableOf(
    List<MessageData> messages,
  ) async {
    final allowed = <MessageData>[];
    var blocked = 0;
    for (final m in messages) {
      final hasBody =
          m.text.trim().isNotEmpty || m.sticker != null || m.attachment != null;
      if (!hasBody) continue;
      try {
        if (!await widget.controller.canForwardFromProfile(
          _sourceProfileIdOf(m),
        )) {
          blocked++;
          continue;
        }
      } catch (_) {
        // Gate unavailable → fail open, same as mobile's best-effort behaviour.
      }
      allowed.add(m);
    }
    return (allowed: allowed, blocked: blocked);
  }

  /// Отправить копию [m] — в личную переписку ([peerProfileId]; для
  /// «Сохранить» это я сам) или в комнату ([groupId]).
  ///
  /// Три случая, и каждый уходит своим путём:
  ///   • текст — командой пересылки, с подписью «от кого»;
  ///   • наклейка — тем же вызовом, что и отправка новой;
  ///   • вложение — файлом из кэша, тем же путём, что перетаскивание; подпись
  ///     под ним — отдельным сообщением.
  Future<_CopyOutcome> _sendForwardedCopy(
    MessageData m, {
    String? peerProfileId,
    String? groupId,
  }) async {
    final text = m.text.trim();
    final sticker = m.sticker;
    final attachment = m.attachment;
    final toGroup = groupId != null;
    final forwardedFrom = m.forwardedFrom?.trim() ?? '';
    final originAuthor = forwardedFrom.isNotEmpty
        ? forwardedFrom
        : m.authorName;
    final sourcePid = _sourceProfileIdOf(m);

    Future<void> sendText(String body) => toGroup
        ? widget.controller.sendGroupMessage(groupId: groupId, text: body)
        : widget.controller.sendMessage(
            peerProfileId: peerProfileId!,
            text: body,
          );

    if (sticker != null) {
      await widget.controller.sendSticker(
        peerProfileId: toGroup ? desktopRoomAddress(groupId) : peerProfileId!,
        sticker: sticker,
      );
      return _CopyOutcome.sent;
    }
    if (attachment != null) {
      final path = await _forwardableAttachmentPath(attachment);
      if (path == null) return _CopyOutcome.noFile;
      // Имя отправителя — если оно было. Имя файла из КЭША («a1b2c3.bin»)
      // получателю не отправляется (17.09.2026): оно ничего не говорит, а
      // получатель без имени сам назовёт файл по виду. Для угадывания типа
      // годится и оно.
      final givenName = (attachment.fileName ?? '').trim();
      final name = givenName.isNotEmpty
          ? givenName
          : path.split(Platform.pathSeparator).last;
      final mime = (attachment.mime ?? '').trim().isNotEmpty
          ? attachment.mime!.trim()
          : _guessMimeForName(name);
      // 🔴 СНИМОК ОСТАЁТСЯ СНИМКОМ. Имя файла у вложения значит «отправлено
      // файлом» (так читает и телефон): пересланное фото с именем из кэша
      // превращалось у получателя в строку документа «a1b2c3.jpg».
      final asMedia =
          !attachment.sentAsFile &&
          (attachment.kind == MessageAttachmentKind.image ||
              attachment.kind == MessageAttachmentKind.video);
      // Подпись едет ВМЕСТЕ со снимком — как у самого сообщения.
      final caption = text.isEmpty ? null : text;
      // Песня уходит с названием и исполнителем — иначе у получателя она
      // подписана именем файла.
      if (toGroup) {
        await widget.controller.sendGroupAttachmentFile(
          groupId: groupId,
          filePath: path,
          mime: mime,
          filename: (asMedia || givenName.isEmpty) ? null : givenName,
          caption: caption,
          musicTitle: attachment.musicTitle,
          musicArtist: attachment.musicArtist,
          // Голосовое остаётся голосовым: его отличает от песни только волна.
          waveform: attachment.waveform,
          durationMs: attachment.durationMs,
          videoNote: attachment.videoNote,
        );
      } else {
        await widget.controller.sendAttachmentFile(
          peerProfileId: peerProfileId!,
          filePath: path,
          mime: mime,
          filename: (asMedia || givenName.isEmpty) ? null : givenName,
          caption: caption,
          musicTitle: attachment.musicTitle,
          musicArtist: attachment.musicArtist,
          waveform: attachment.waveform,
          durationMs: attachment.durationMs,
          videoNote: attachment.videoNote,
          // Себе — тот же файл без новой заливки; чужому нельзя (сервер увидел
          // бы один файл в двух переписках). Правило — общее с телефоном.
          reuseBlobFrom: desktopReusableBlobForForward(
            source: _attachmentPayloadOf(attachment),
            toGroup: toGroup,
            targetProfileId: peerProfileId,
            myProfileId: widget.controller.profileId,
          ),
        );
      }
      return _CopyOutcome.sent;
    }
    if (text.isEmpty) return _CopyOutcome.empty;
    await sendText(
      buildForwardCommand(
        authorName: originAuthor,
        text: text,
        authorProfileId: sourcePid,
        sourceConvoId: _convoId,
      ),
    );
    return _CopyOutcome.sent;
  }

  /// Файл вложения на диске: готовый из ленты или скачанный сейчас.
  ///
  /// `filePath` у пузыря заполняется лениво — снимок, который ещё не
  /// открывали, его не имеет. Молча отправить в таком случае нечего, поэтому
  /// пробуем достать; не вышло — возвращаем `null`, и вызывающий говорит об
  /// этом вслух.
  /// Запечатанный конверт вложения, который лента уже разобрала.
  ///
  /// Искать по ключу СОБЫТИЯ правильнее, чем по номеру сообщения: у своих
  /// отправленных они совпадают, у пришедших — нет.
  AttachmentEventV1? _attachmentPayloadOf(MessageAttachment attachment) {
    final payloadId = attachment.payloadEventId.trim();
    if (payloadId.isEmpty) return null;
    for (final candidate in _attachmentsByMessageId.values) {
      if (candidate.eventId == payloadId) return candidate;
    }
    return null;
  }

  Future<String?> _forwardableAttachmentPath(
    MessageAttachment attachment,
  ) async {
    final ready = (attachment.filePath ?? '').trim();
    if (ready.isNotEmpty && File(ready).existsSync()) return ready;
    final payloadId = attachment.payloadEventId.trim();
    if (payloadId.isEmpty) return null;
    // Сам запечатанный payload лента уже разобрала — он лежит в
    // `_attachmentsByMessageId`. Разбирать второй раз незачем, а искать по
    // ключу события правильнее, чем по идентификатору сообщения: у своих
    // отправленных они совпадают, у пришедших — нет.
    final payload = _attachmentPayloadOf(attachment);
    if (payload == null) return null;
    try {
      final file = await widget.controller.ensureCachedAttachmentFile(payload);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// E7: a voice note recorded in the composer (opus). 1:1 reads the bytes
  /// (sendAttachment); groups hand the path to sendGroupAttachmentFile. The mime
  /// `audio/opus` classifies it as a voice note on both desktop and mobile.
  Future<void> _onSendVoice(String path, int durationMs) async {
    try {
      if (_isDirect) {
        final pid = _peerProfileId;
        if (pid == null || pid.isEmpty) return;
        final bytes = await File(path).readAsBytes();
        if (!mounted) return;
        setState(() => _sendError = null);
        await widget.controller.sendAttachment(
          peerProfileId: pid,
          bytes: bytes,
          mime: 'audio/opus',
          durationMs: durationMs,
        );
      } else {
        setState(() => _sendError = null);
        await widget.controller.sendGroupAttachmentFile(
          groupId: _convoId,
          topicId: _currentTopicId,
          filePath: path,
          mime: 'audio/opus',
          durationMs: durationMs,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = e.toString());
    }
  }

  /// P2b: a sticker picked from the composer popover. 1:1 sends to the peer
  /// profile id; groups use the `group:<convoId>` form sendSticker forwards to
  /// sendGroupSticker.
  Future<void> _onSendSticker(SecretlyStickerDescriptor sticker) async {
    try {
      final String target;
      if (_isDirect) {
        final pid = _peerProfileId;
        if (pid == null || pid.isEmpty) return;
        target = pid;
      } else {
        target = desktopRoomAddress(_convoId);
      }
      if (mounted) setState(() => _sendError = null);
      await widget.controller.sendSticker(
        peerProfileId: target,
        sticker: sticker,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = e.toString());
    }
  }

  // ── Отправка файлов — через окно отправки ───────────────────────────
  //
  // 🔴 Указание владельца 16.09.2026: брошенные, вставленные и выбранные
  // файлы больше не уходят сразу и без подписи — сперва окно, как в Telegram
  // (см. `send_media_dialog.dart`). Сюда приходит уже решение человека.

  Future<void> _sendMedia(
    SendMediaResult result, {
    String? replyToPayloadEventId,
  }) async {
    _stopTyping();
    setState(() => _sendError = null);
    try {
      await enqueueDesktopMediaSend(
        enqueue: widget.controller.enqueueAttachmentBatchUpload,
        result: result,
        convoId: _convoId,
        peerProfileId: _isDirect ? _peerProfileId : null,
        // В ту ветку, где человек стоит, — как и текст.
        topicId: _isDirect ? null : _currentTopicId,
        replyToPayloadEventId: replyToPayloadEventId,
        // Подпись отдельным сообщением идёт обычной отправкой: с темой,
        // упоминаниями и разбором отказов.
        sendText: (text, reply) => _send(
          DesktopComposerSubmission(text: text, replyToPayloadEventId: reply),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _sendError = _humanError(e));
    }
  }

  void _cancelUpload(MessageData m) {
    final batchId = uploadBatchIdOfRow(m);
    if (batchId == null) return;
    widget.controller.cancelPendingAttachmentBatchUpload(_convoId, batchId);
  }

  // ── Уходящие пачки в ленте ───────────────────────────────────────────
  //
  // Прогресс приходит своим потоком (`pendingUploadsChanged`), а не общим
  // тиком ленты: перечитывать базу на каждый процент незачем. Перерисовывается
  // только панель переписки ([_uploadTick]), а не весь хост.

  StreamSubscription<String>? _uploadsSub;
  StreamSubscription<AttachmentUploadErrorEvent>? _uploadErrorsSub;
  final ValueNotifier<int> _uploadTick = ValueNotifier<int>(0);
  Timer? _uploadTickTimer;

  /// Пачки, которые очередь уже отпустила, а их сообщения ещё не дочитаны в
  /// ленту. Держим заготовку до четырёх секунд — иначе строка на мгновение
  /// пропадала бы и появлялась снова.
  final Map<String, PendingAttachmentBatchUpload> _seenBatches =
      <String, PendingAttachmentBatchUpload>{};
  final Map<String, ({PendingAttachmentBatchUpload batch, int atMs})>
  _landingBatches = <String, ({PendingAttachmentBatchUpload batch, int atMs})>{};
  Timer? _landingTimer;

  void _subscribeUploads() {
    _uploadsSub = widget.controller.pendingUploadsChanged.listen((convoId) {
      if (!mounted || convoId != _convoId) return;
      _trackLanding();
      _scheduleUploadTick();
    });
    _uploadErrorsSub = widget.controller.attachmentUploadErrors.listen(
      _onUploadError,
    );
    _trackLanding();
  }

  void _resetUploadsForConvo() {
    _seenBatches.clear();
    _landingBatches.clear();
    _landingTimer?.cancel();
    _trackLanding();
    _uploadTick.value++;
  }

  void _scheduleUploadTick() {
    if (_uploadTickTimer?.isActive ?? false) return;
    _uploadTickTimer = Timer(const Duration(milliseconds: 60), () {
      if (mounted) _uploadTick.value++;
    });
  }

  void _trackLanding() {
    final live = <String, PendingAttachmentBatchUpload>{
      for (final b in widget.controller.pendingAttachmentBatchUploadsFor(
        _convoId,
      ))
        b.id: b,
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in _seenBatches.entries) {
      if (live.containsKey(entry.key)) continue;
      final gone = entry.value;
      // Отменённую или неудавшуюся держать незачем — её сообщений не будет.
      if (gone.payloadEventIds.isNotEmpty && !gone.allCanceled) {
        _landingBatches[entry.key] = (batch: gone, atMs: now);
      }
    }
    _seenBatches
      ..clear()
      ..addAll(live);
    _armLandingTimer();
  }

  void _armLandingTimer() {
    _landingTimer?.cancel();
    if (_landingBatches.isEmpty) return;
    _landingTimer = Timer(const Duration(milliseconds: 400), _sweepLanding);
  }

  void _sweepLanding() {
    if (!mounted) return;
    final ids = _messagePayloadIds();
    final now = DateTime.now().millisecondsSinceEpoch;
    final before = _landingBatches.length;
    _landingBatches.removeWhere(
      (_, v) => now - v.atMs > 4000 || _batchLanded(v.batch, ids),
    );
    if (_landingBatches.length != before) _uploadTick.value++;
    _armLandingTimer();
  }

  List<MessageData>? _payloadIdsSource;
  Set<String> _payloadIds = const <String>{};

  Set<String> _messagePayloadIds() {
    if (!identical(_payloadIdsSource, _messages)) {
      _payloadIdsSource = _messages;
      _payloadIds = <String>{
        for (final m in _messages)
          if (m.payloadId != null) m.payloadId!,
      };
    }
    return _payloadIds;
  }

  bool _batchLanded(PendingAttachmentBatchUpload b, Set<String> ids) =>
      b.payloadEventIds.isNotEmpty && b.payloadEventIds.any(ids.contains);

  bool _batchInCurrentTopic(PendingAttachmentBatchUpload b) {
    if (!_topicsVisible) return true;
    final want = _currentTopicId ?? '';
    final known = _roomTopics.map((t) => t.id).toSet();
    final k = (b.topicId ?? '').trim();
    return (known.contains(k) ? k : '') == want;
  }

  List<MessageData> _uploadRows() {
    final ids = _messagePayloadIds();
    final convoId = _convoId;
    // Старые первыми: сперва дочитываемые, затем очередь (у контроллера
    // она новыми вперёд).
    final batches = <PendingAttachmentBatchUpload>[
      for (final v in _landingBatches.values)
        if (v.batch.convoId == convoId &&
            !_batchLanded(v.batch, ids) &&
            _batchInCurrentTopic(v.batch))
          v.batch,
      for (final b in widget.controller
          .pendingAttachmentBatchUploadsFor(convoId)
          .reversed)
        if (!_batchLanded(b, ids) && _batchInCurrentTopic(b)) b,
    ];
    if (batches.isEmpty) return const <MessageData>[];
    return desktopUploadRows(
      batches,
      selfName: _kSelfAuthorRu,
      timeLabel: _hhmm,
      replyPreview: _resolveReplyPreview,
    );
  }

  List<MessageData>? _withUploadsSource;
  int _withUploadsTick = -1;
  List<MessageData> _withUploads = const <MessageData>[];

  /// Лента вместе с уходящими пачками — снизу, где и появятся сообщения.
  /// Один и тот же список, пока ничего не поменялось: панель по нему
  /// перестраивает поиск и выделение.
  List<MessageData> _threadRowsWithUploads() {
    final rows = _threadRows;
    final tick = _uploadTick.value;
    if (identical(_withUploadsSource, rows) && _withUploadsTick == tick) {
      return _withUploads;
    }
    _withUploadsSource = rows;
    _withUploadsTick = tick;
    final uploads = _uploadRows();
    _withUploads = uploads.isEmpty
        ? rows
        : List<MessageData>.unmodifiable(<MessageData>[...rows, ...uploads]);
    return _withUploads;
  }

  void _onUploadError(AttachmentUploadErrorEvent event) {
    if (!mounted) return;
    final text = _attachmentErrorMessage(event.error);
    DesktopSnackbar.show(
      context,
      message: event.convoId == _convoId
          ? text
          : 'Файл в другую переписку не отправлен: $text',
      kind: DSnackKind.error,
    );
  }

  /// Текст ошибки вложения — тот же, что у телефона.
  String _attachmentErrorMessage(Object error) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return 'Не удалось отправить файл.';
    var text = attachmentErrorText(l10n, error);
    final failure = describeAttachmentFailure(error);
    if (failure.code == AttachmentFailureCode.tooLarge) {
      final bytes = failure.bytes ?? parseAttachmentFailureBytes(error) ?? 0;
      if (bytes > 0 && widget.controller.attachmentTooLargeUpsell(bytes)) {
        text = '$text С Premium можно отправлять файлы до 1 ГБ.';
      }
    }
    return text;
  }

  /// Подпись под названием переписки в шапке.
  String? _chatHeaderStatus(
    BuildContext context, {
    required Conversation convo,
    required bool typing,
  }) {
    if (typing) return 'печатает…';
    if (!_isDirect) {
      final count = _roomMemberCount;
      if (count == null || count <= 0) return null;
      // Общий с телефоном текст склонять не умеет — там он стоит в месте, где
      // «3 участников» не бросается в глаза. В шапке бросается, поэтому
      // по-русски считаем по-русски, а всем остальным отдаём общий текст.
      return chatLocaleIsRussian(context)
          ? formatParticipantsRu(count)
          : chatRoomInviteMembersText(context, memberCount: count);
    }
    if (convo.isOnline) return 'в сети';
    return chatLastSeenText(
      context,
      timestampMs: convo.peerLastSeenAtMs,
      now: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final convo = widget.conversation;
    // E9 typing-in: show «печатает…» while the peer is typing (updates live via
    // the controller.changed subscription this host already listens to).
    final peerTyping = widget.controller.isConversationTyping(_convoId);
    final header = ChatHeader(
      name: convo.title.isEmpty ? '—' : convo.title,
      online: convo.isOnline,
      muted: convo.muted,
      // Галочка в шапке — про сверенные коды безопасности, не про подписку.
      verified: _peerVerified,
      // 🔴 ПОДПИСЬ В ШАПКЕ БЫЛА ПУСТОЙ ВЕЗДЕ, КРОМЕ «в сети» (13.09.2026).
      //
      // У личной переписки это значило, что человек не в сети сейчас — и
      // больше ничего: ни когда он был, ни что это вообще известно. Телефон в
      // том же месте пишет «был(а) в 19:40». Берём ТОТ ЖЕ общий текст, а не
      // свой: он уже знает, что ноль и null — это «недавно», а не 1970 год,
      // и переведён на все языки приложения.
      //
      // У комнаты подписи не было вовсе, хотя «сколько нас» — первое, что о
      // комнате спрашивают. Текст тоже общий с телефоном.
      status: _chatHeaderStatus(context, convo: convo, typing: peerTyping),
      disappearingSeconds: _autoDeleteSeconds,
      avatarPath: convo.avatarPath,
      frameId: convo.frameId,
      emojiStatus: convo.emojiStatus,
      premiumBadge: convo.premiumBadge,
      // Только у комнаты: у личной переписки описания нет, а пустая черта
      // сделала бы шапку выше без содержания.
      description: _isDirect ? null : _roomDescription,
    );

    // 🔴 ПУСТОЙ ЧАТ — ЭТО НЕ ВСЕГДА «ПЕРЕПИСКИ НЕТ».
    //
    // Долг паритета d69fe6b3. Полевой отчёт мобильной версии 03.08.2026:
    // пришло уведомление, человек нажал на него, попал в чат — а там пусто, и
    // лишь секунд через пятнадцать появилось сообщение. Пустота была «честной»
    // только формально: сообщение в тот момент лежало на реле, и до первого
    // разбора входящего ящика мы ещё НЕ ЗНАЕМ, пуст чат или нет. А показывали
    // знание — то же враньё, что «был(а) 01.01 03:00».
    //
    // Здесь загрузка из своей базы (`_loading`) закончилась, а разбор ящика мог
    // и не начаться, поэтому одного `_loading` мало.
    //
    // ПРЯМАЯ СТРАХОВКА ОТ ВЕЧНОГО КРУЖКА: ждём, только пока реле НА СВЯЗИ. Нет
    // связи — ждать нечего, пустота настоящая, и человек видит обычный чат.
    //
    // Вторая тонкость: если ящик окажется пуст, доставок не будет, а значит и
    // перерисовки — кружок завис бы до чужого события. Этого не случится:
    // контроллер шлёт перерисовку по завершении первого разбора отдельно
    // (`onFirstDrainCompleted` → `changed`), и десктопная модель на неё
    // подписана.
    final emptinessStillUnknown = chatEmptinessStillUnknown(
      firstDrainDone: widget.controller.inboundFirstDrainDone,
      relayOnline: widget.controller.relayOnline,
    );

    if ((_loading || emptinessStillUnknown) && _messages.isEmpty) {
      return Container(
        color: c.thread,
        alignment: Alignment.center,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(c.accentPrimary),
          ),
        ),
      );
    }

    // «Ветки» rail sits between the chat list and the conversation, so the
    // branches of a room are all visible at once — the point of a wide screen.
    // Hidden entirely when the room has none, so a plain room is unchanged.
    // 🔴 ТЕМЫ ПЕРЕЕХАЛИ ИЗ ВЕРТИКАЛЬНОЙ РЕЙКИ В ГОРИЗОНТАЛЬНУЮ ПОЛОСУ.
    //
    // Рейка отнимала у переписки 200 точек ширины постоянно — ради списка из
    // трёх-пяти строк. На столе ширина переписки и есть главная ценность окна.
    // Полоса занимает 36 точек высоты, которых не жалко, и возвращает ширину.
    //
    // Состояние тем остаётся ЗДЕСЬ, вместе с выбором темы и фильтром сообщений;
    // панель переписки про темы по-прежнему ничего не знает и лишь отводит
    // полосе место. Путь синхронизации с телефоном
    // (`__secretly_topics_v1__`) не тронут.
    final topicsStrip = _topicsVisible
        ? RoomTopicsStrip(
            topics: _roomTopics,
            selectedTopicId: _currentTopicId,
            onSelect: (id) {
              setState(() => _currentTopicId = id);
              _publishTopics();
            },
            unreadByTopicId: _topicUnreadCounts(),
            canManage: _canManageTopics,
            onCreate: () => unawaited(_createTopic()),
            onManage: (t) => unawaited(_manageTopic(t)),
            onManageBase: () => unawaited(_manageBaseTopic()),
            baseMark: _baseTopicMark,
          )
        : null;

    // Подпись у поля ввода — только когда человек в НЕ-общей теме: в «Общем»
    // и в личной переписке писать больше некуда, и подпись была бы шумом.
    final currentTopicTitle = _currentTopicId == null
        ? null
        : _roomTopics
              .where((t) => t.id == _currentTopicId)
              .map((t) => t.title)
              .firstOrNull;

    // Плашка «Идёт обсуждение» — только по настоящему снимку созвона.
    // Кнопка ведёт в тот же экран, что и кнопка звонка в шапке комнаты.
    final callBanner = _activeRoomCall == null
        ? null
        : DesktopRoomCallBanner(
            call: _activeRoomCall!,
            onJoin: _startRoomCall,
            faces: _callFaces(_activeRoomCall!),
          );

    // Панель перестраивается и на прогресс отправки — отдельно от хоста.
    final thread = ValueListenableBuilder<int>(
      valueListenable: _uploadTick,
      builder: (context, _, _) => ChatThreadPanel(
      topicsStrip: topicsStrip,
      callBanner: callBanner,
      pinnedPayloadEventId: _isDirect ? null : _pinnedPayloadEventId,
      // Закреплять — только тому, кому комната это позволяет: пункт меню,
      // который всегда отвечает отказом, пунктом меню не является.
      onNearLatestChanged: _onNearLatestChanged,
      onTogglePinMessage: (!_isDirect && _canPinMessages)
          ? (m, pin) => unawaited(_togglePinMessage(m, pin))
          : null,
      composerTopicTitle: currentTopicTitle,
      // Звать через «@» можно только в комнате: в личной переписке звать
      // некого, собеседник и так один.
      mentionTargets: _isDirect
          ? const <DesktopMentionTarget>[]
          : _mentionTargets,
      selfProfileId: widget.controller.profileId,
      // «@admins» достаётся владельцу и администраторам: у обычного участника
      // такая фишка — чужое обращение, и красить её как «зовут меня» было бы
      // неправдой.
      canReceiveAdminMentions:
          _roomMembersById[widget.controller.profileId]?.isAdmin ?? false,
      header: header,
      isDirect: _isDirect,
      messages: _threadRowsWithUploads(),
      detailsOpen: widget.shellApi.detailsOpen,
      onToggleDetails: widget.shellApi.toggleDetails,
      onSend: _send,
      onDeleteMessage: _deleteMessage,
      onForwardMessage: _forwardMessage,
      onSaveMessage: _saveMessage,
      onDeleteMessages: _deleteMessages,
      onForwardMessages: _forwardMessages,
      onSaveMessages: _saveMessages,
      // Кнопка «Продолжить в теме» есть только там, где есть ветки.
      onContinueInTopic: _topicsVisible ? _continueInTopic : null,
      // · «Игорь печатает» — плашкой в самой ленте, а не только подписью в
      // шапке. Имя знаем только в личной переписке: в комнате протокол
      // передаёт сам признак, но не автора, и плашка там без имени.
      typingLabel: !peerTyping
          ? null
          : (_isDirect && convo.title.trim().isNotEmpty
                ? '${convo.title.trim()} печатает'
                : 'печатает'),
      onSetVoiceSpeed: (v) =>
          unawaited(widget.controller.setSharedAudioSpeed(v)),
      onTypingActivity: _onTypingActivity,
      onSendVoice: _onSendVoice,
      stickerController: widget.controller,
      onSendSticker: _onSendSticker,
      initialDraft: DesktopDraftStore.get(_convoId),
      onDraftChanged: (t) => DesktopDraftStore.set(_convoId, t),
      linkPreviewDraft: DesktopUiPrefs.linkPreviews.value ? _linkDraft : null,
      onSendMedia: _sendMedia,
      onPickAttachments: pickDesktopAttachments,
      attachmentMaxBytes: widget.controller.effectiveAttachmentMaxBytes,
      onCancelUpload: _cancelUpload,
      onCall: _isDirect ? () => _startCall(video: false) : _startRoomCall,
      onVideoCall: _isDirect ? () => _startCall(video: true) : _startRoomCall,
      // Unread at open time drives the «новые сообщения» line.
      unreadCount: widget.conversation.unreadCount,
      searchOpen: _searchOpen,
      onToggleSearch: () => setState(() => _searchOpen = !_searchOpen),
      onHeaderMenu: widget.onHeaderMenu,
      // Global default wallpaper from the shared preset. Per-chat overrides
      // are kept on mobile via SharedPreferences and will be plumbed
      // through in Sprint 2 once the chat-context menu has a "Wallpaper…"
      // entry on desktop.
      wallpaperId: widget.controller.defaultChatWallpaperId,
      // Both read from the shared controller, so the animation mode and
      // the «проводит сообщение» switch chosen on the phone apply here.
      wallpaperAnimMode: desktopWallpaperAnimModeFor(
        setting: widget.controller.chatWallpaperAnimMode,
        windowFocused: DesktopWindowActivity.focused.value,
      ),
      wallpaperConduct: widget.controller.chatWallpaperConduct,
      onReactToMessage: (m, emoji) {
        unawaited(_applyReaction(m, emoji));
      },
      onTapExistingReaction: (m, emoji) {
        // Mirror mobile semantics: tapping any existing reaction chip
        // calls `toggleMessageReaction` with that emoji, which removes
        // your reaction if it was yours and otherwise adds your reaction
        // alongside the others.
        unawaited(_applyReaction(m, emoji));
      },
      // PR7: "Load older" wired to the chat-panel scroll-to-top
      // detector. Fetches the next 100 events older than our oldest
      // local row from the SQLite cache; when that runs dry, asks
      // mobile for the next page over the peer-history protocol.
      onLoadOlder: _loadOlder,
      // PR8 (SPRINT2_AUDIT §20): photo / file / voice-note taps.
      // The bubble surfaces these as callbacks so the host can open
      // the fullscreen viewer, reveal in Finder, and drive the
      // shared audio player.
      onOpenImage: (m) => unawaited(_openImage(m)),
      onOpenVideo: (m) => unawaited(_openVideo(m)),
      onOpenFile: (m) => unawaited(_openFile(m)),
      onPollVote: (m, index) => unawaited(_votePoll(m, index)),
      onPollClose: (m) => unawaited(_closePoll(m)),
      onEventRsvp: (m, status) => unawaited(_rsvpEvent(m, status)),
      onComposePoll: _convoId.startsWith('group:') ? _composePoll : null,
      onComposeEvent: _convoId.startsWith('group:') ? _composeEvent : null,
      onToggleVoice: (m) => unawaited(_toggleVoice(m)),
      onSeekVoice: (m, fraction) => unawaited(_seekVoice(fraction)),
      onSaveAttachment: (m) => unawaited(_saveAttachment(m)),
      onDownloadAttachment: _downloadAttachment,
      onRevealAttachment: (m) => unawaited(_revealAttachment(m)),
      sharedAudio: widget.controller.sharedAudioPlayback,
      ),
    );

    return Stack(
      children: [
        thread,
        if (_sendError != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SendErrorBanner(
              message: _sendError!,
              onDismiss: () => setState(() => _sendError = null),
            ),
          ),
      ],
    );
  }
}

class _SendErrorBanner extends StatelessWidget {
  const _SendErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(DSpace.m),
        padding: const EdgeInsets.symmetric(
          horizontal: DSpace.m,
          vertical: DSpace.s,
        ),
        decoration: BoxDecoration(
          color: c.elevated,
          borderRadius: BorderRadius.circular(DRadii.md),
          border: Border.all(color: c.danger),
        ),
        child: Row(
          children: [
            Icon(
              FluentIcons.error_circle_24_regular,
              size: 18,
              color: c.danger,
            ),
            const SizedBox(width: DSpace.s),
            Expanded(
              child: Text(
                message,
                style: DType.caption.copyWith(color: c.textPrimary),
              ),
            ),
            const SizedBox(width: DSpace.s),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                FluentIcons.dismiss_24_regular,
                size: 16,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread({
    required this.loading,
    required this.hasItems,
    required this.titleNoItems,
    required this.subtitleNoItems,
    required this.titleSelect,
  });

  final bool loading;
  final bool hasItems;
  final String titleNoItems;
  final String subtitleNoItems;
  final String titleSelect;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      color: c.thread,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: c.elevated,
              shape: BoxShape.circle,
              border: Border.all(color: c.borderSubtle),
            ),
            child: loading
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(c.accentPrimary),
                      ),
                    ),
                  )
                : Icon(
                    FluentIcons.chat_24_regular,
                    size: 30,
                    color: c.textSecondary,
                  ),
          ),
          const SizedBox(height: DSpace.l),
          Text(
            loading ? 'Загрузка…' : (hasItems ? titleSelect : titleNoItems),
            style: DType.title.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: DSpace.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              loading
                  ? 'Подтягиваем список из локального хранилища.'
                  : (hasItems
                        ? 'Сообщения и звонки появятся здесь, как только вы откроете чат.'
                        : subtitleNoItems),
              textAlign: TextAlign.center,
              style: DType.body.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Best-effort MIME from a filename extension.
///
/// Top-level so BOTH the section (dropping onto a list row) and the open
/// conversation use one table — two copies would drift and the same file
/// would arrive typed differently depending on where it was dropped.
String? _guessMimeForName(String name) => desktopMimeForName(name);

/// Плитка знака ветки в окне выбора.
class _MarkCell extends StatelessWidget {
  const _MarkCell({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;

  /// `null` — серый: знак помогает узнать ветку, а не спорит с именем.
  final Color? color;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return DesktopTooltip(
      message: tooltip,
      child: HoverListener(
        onTap: onTap,
        cursor: SystemMouseCursors.click,
        builder: (ctx, hovered, pressed) => AnimatedContainer(
          duration: DMotion.fast,
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? c.selected
                : (hovered ? c.hover : c.elevated),
            borderRadius: BorderRadius.circular(DRadii.md),
            border: Border.all(
              color: selected ? c.accentPrimary : c.borderSubtle,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Icon(icon, size: 20, color: color ?? c.textSecondary),
        ),
      ),
    );
  }
}

/// Можно ли отметить новое в открытой переписке прочитанным (17.09.2026).
///
/// Окно в фокусе — человек смотрит на приложение (видимое, но неактивное окно
/// рядом с чужим — ещё не «прочитал»). Лента внизу — новое сообщение на
/// экране. Отдельной функцией, чтобы правило проверялось напрямую.
bool desktopShouldMarkOpenChatRead({
  required bool windowFocused,
  required bool nearLatest,
}) => windowFocused && nearLatest;

/// Адрес комнаты для `sendSticker` (17.09.2026).
///
/// Номер переписки комнаты УЖЕ начинается с `group:`. Компьютер дописывал
/// приставку ещё раз, получался `group:group:…`, комната не находилась, и
/// наклейка в комнату не уходила ни отправкой, ни пересылкой.
String desktopRoomAddress(String convoId) {
  final id = convoId.trim();
  return id.startsWith('group:') ? id : 'group:$id';
}

/// Под каким номером сообщение знают собеседники — правило телефона
/// (`timelineRowId` в `chat_screen.dart`, `62a4da97`).
///
/// `payloadEventId ?? eventId` ловил только `null`: пустая строка проходила как
/// полноценный номер, и такие сообщения делили один ключ — попадали не в свою
/// тему, а «удалить для всех» целилось в пустой номер. Одно правило для
/// реакций, тем и команд (17.09.2026).
String desktopTimelineRowId(String? payloadEventId, String eventId) {
  final pid = (payloadEventId ?? '').trim();
  return pid.isEmpty ? eventId : pid;
}
