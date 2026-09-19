// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import '../../../l10n/app_localizations.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, setEquals, visibleForTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderMetaData;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../app/app_controller.dart'
    show AppController, SharedAudioPlaybackState;
import '../../../stickers/sticker_catalog.dart' show SecretlyStickerDescriptor;
import '../design/tokens.dart';
import '../primitives/avatar.dart';
import '../primitives/context_menu.dart';
import '../primitives/desktop_button.dart';
import '../primitives/hover_listener.dart';
import 'chat_list_panel.dart' show ChatKind, unreadColorFor;
import '../primitives/verified_badge.dart';
import '../../widgets/telegram_wallpaper.dart'
    show ChatWallpaperAnimMode, TelegramWallpaperState;
import '../../../links/link_preview_draft.dart';
import '../../../models/link_preview_v1.dart';
import 'attachments_drop_zone.dart';
import 'composer.dart';
import 'desktop_wallpaper.dart';
import '../primitives/desktop_snackbar.dart';
import '../services/desktop_translation_prefs.dart';
import '../services/desktop_translation_service.dart';
import 'emoji_popover.dart';
import 'schedule_send_dialog.dart';
import 'message_bubble.dart';
import 'desktop_mentions.dart';
import 'message_context_menu.dart';
import 'media_albums.dart';
import 'message_selection.dart';
import 'outgoing_media.dart';
import 'send_media_dialog.dart';
import 'reactions_popover.dart';

class ChatHeader {
  const ChatHeader({
    required this.name,
    this.status,
    this.online = false,
    this.verified = false,
    this.muted = false,
    this.disappearingSeconds,
    this.avatarPath,
    this.frameId,
    this.emojiStatus,
    this.premiumBadge = false,
    this.description,
  });
  final String name;
  final String? status;

  /// Описание комнаты — то, ради чего она заведена.
  ///
  /// 🔴 Оно жило ТОЛЬКО в подробностях, отдельной секцией, куда надо было
  /// сперва открыть панель. В макете описание стоит прямо в шапке, за
  /// вертикальной чертой: «Релиз 1.4 │ Всё про сборку · дедлайн 30.09».
  /// Комнату заводят ради темы, и напоминать о ней надо там, где на неё
  /// смотрят, — а не через два нажатия.
  ///
  /// Пусто или `null` — строки нет вовсе: пустая черта делает шапку выше без
  /// содержания.
  final String? description;
  final bool online;
  final bool verified;
  final bool muted;

  /// Local file path of the chat's avatar photo (peer/group), or null → initials.
  final String? avatarPath;

  /// Peer premium cosmetics (rendered regardless of the local user's tier).
  final String? frameId;
  final String? emojiStatus;
  final bool premiumBadge;

  /// E9: when non-null and > 0, disappearing messages are on for this chat —
  /// the header shows a timer chip. Security feature: always surfaced, never
  /// gated.
  final int? disappearingSeconds;
}

/// Callback used when the user picks a reaction emoji for a particular
/// message — either by clicking one of the quick-emoji buttons in the
/// hover toolbar, or by picking from the full emoji popover, or by tapping
/// an existing reaction chip on the bubble (which on mobile toggles the
/// reaction off).
typedef MessageReactionCallback =
    void Function(MessageData message, String emoji);

/// What the composer emits on send. Carries the trimmed [text] plus, when the
/// composer had an active reply/edit context, the logical payload-event id of
/// the target message. The host ([DesktopChatsSection]) branches on these:
///   • [editPayloadEventId] != null  → `editTextMessage(payloadEventId: …)`
///   • [replyToPayloadEventId] != null → `sendMessage(replyToPayloadEventId: …)`
///   • both null                       → plain `sendMessage`
/// At most one of the two ids is ever non-null.
class DesktopComposerSubmission {
  const DesktopComposerSubmission({
    required this.text,
    this.replyToPayloadEventId,
    this.editPayloadEventId,
    this.scheduledAtMs,
    this.linkPreview,
  });

  final String text;
  final String? replyToPayloadEventId;
  final String? editPayloadEventId;

  /// Момент отправки, если человек выбрал «позже». `null` — сейчас.
  ///
  /// Дальше это уходит прямо в `sendMessage`/`sendGroupMessage`: контроллер
  /// сам кладёт местную заготовку и отпускает её в срок, переживая перезапуск.
  final int? scheduledAtMs;

  /// Карточка первой ссылки текста — её готовит отправитель, и уходит она
  /// внутри сообщения. У правки всегда `null`: карточка остаётся от
  /// исходного сообщения.
  final LinkPreviewV1? linkPreview;

  bool get isEdit => editPayloadEventId != null;
}

class ChatThreadPanel extends StatefulWidget {
  const ChatThreadPanel({
    super.key,
    required this.header,
    required this.messages,
    this.onSend,
    this.onDeleteMessage,
    this.onForwardMessage,
    this.onSaveMessage,
    this.onDeleteMessages,
    this.onForwardMessages,
    this.onSaveMessages,
    this.onSendMedia,
    this.onPickAttachments,
    this.attachmentMaxBytes = 0,
    this.onCancelUpload,
    this.onTypingActivity,
    this.onSendVoice,
    this.stickerController,
    this.onSendSticker,
    this.initialDraft,
    this.onDraftChanged,
    this.linkPreviewDraft,
    this.onToggleDetails,
    this.onNearLatestChanged,
    this.onCall,
    this.onVideoCall,
    this.detailsOpen = false,
    this.searchOpen = false,
    this.unreadCount = 0,
    this.onToggleSearch,
    this.onHeaderMenu,
    this.wallpaperId,
    this.topicsStrip,
    this.callBanner,
    this.pinnedPayloadEventId,
    this.onTogglePinMessage,
    this.composerTopicTitle,
    this.wallpaperAnimMode = ChatWallpaperAnimMode.onEnter,
    this.wallpaperConduct = false,
    this.onReactToMessage,
    this.onTapExistingReaction,
    this.onContinueInTopic,
    this.typingLabel,
    this.mentionTargets = const <DesktopMentionTarget>[],
    this.selfProfileId = '',
    this.canReceiveAdminMentions = false,
    this.onOpenProfile,
    this.onSetVoiceSpeed,
    this.onLoadOlder,
    this.onOpenImage,
    this.onOpenVideo,
    this.onOpenFile,
    this.onOpenStickerPack,
    this.onPollVote,
    this.onPollClose,
    this.onEventRsvp,
    this.onComposePoll,
    this.onComposeEvent,
    this.onToggleVoice,
    this.onSeekVoice,
    this.onSaveAttachment,
    this.onDownloadAttachment,
    this.onRevealAttachment,
    this.sharedAudio,
    this.isDirect = false,
  });

  /// True for a 1:1 conversation, false for a room.
  ///
  /// Drives whether incoming bubbles carry the sender's portrait and name:
  /// in a 1:1 there is only one other person and the header already says who,
  /// so repeating it on every bubble is noise. Defaults to false — a room
  /// showing identity is the safe wrong answer; a 1:1 that hides who is
  /// speaking would not be.
  final bool isDirect;

  final ChatHeader header;
  final List<MessageData> messages;

  /// Fired when the user sends from the composer. Carries text plus any active
  /// reply/edit target — see [DesktopComposerSubmission].
  final ValueChanged<DesktopComposerSubmission>? onSend;

  /// Fired when the user picks «Удалить» from a message's context menu. The
  /// host shows the for-me / for-everyone confirm and performs the deletion.
  final ValueChanged<MessageData>? onDeleteMessage;

  /// F-01/F-03: «Переслать». Host resolves the message payload, asks for a
  /// target and re-sends it there. Null → the menu item is omitted entirely
  /// (no dead affordances).
  final ValueChanged<MessageData>? onForwardMessage;

  /// «Сохранить» — переслать сообщение в переписку с самим собой.
  final ValueChanged<MessageData>? onSaveMessage;

  /// 🔴 ДЕЙСТВИЯ НАД НЕСКОЛЬКИМИ СООБЩЕНИЯМИ СРАЗУ (16.09.2026).
  ///
  /// На телефоне сообщения выделяются долгим нажатием и копируются,
  /// пересылаются и удаляются пачкой. На компьютере пункт «Выделить» в меню
  /// был написан, но не подключён — то есть не показывался вовсе, и десять
  /// сообщений приходилось пересылать десятью заходами в меню.
  ///
  /// Список приходит в порядке переписки (от старых к новым). `null` —
  /// действия нет, и его кнопки в панели выделения тоже.
  final ValueChanged<List<MessageData>>? onDeleteMessages;
  final ValueChanged<List<MessageData>>? onForwardMessages;
  final ValueChanged<List<MessageData>>? onSaveMessages;

  /// 🔴 ОТПРАВКА ФАЙЛОВ — ЧЕРЕЗ ОКНО, КАК В TELEGRAM (16.09.2026).
  ///
  /// Брошенные в ленту файлы, вставленные из буфера картинки и файлы, выбор
  /// через «+» — всё открывает окно отправки ([showSendMediaDialog]) с
  /// подписью; хозяин получает уже готовое решение человека. `null` — файлы
  /// отправлять нельзя: нет ни перетаскивания, ни пунктов меню.
  final Future<void> Function(
    SendMediaResult result, {
    String? replyToPayloadEventId,
  })?
  onSendMedia;

  /// Системный выбор файлов: [media] — только снимки и ролики. Пусто —
  /// человек передумал.
  final Future<List<String>> Function({required bool media})?
  onPickAttachments;

  /// Предел размера вложения (байты). 0 — без предела.
  final int attachmentMaxBytes;

  /// Отменить отправку уходящего вложения.
  final ValueChanged<MessageData>? onCancelUpload;

  /// E9: fired while the user is typing, so the host can signal the peer.
  final VoidCallback? onTypingActivity;

  /// E7: a recorded voice note (opus temp path + duration ms) is ready to send.
  final void Function(String path, int durationMs)? onSendVoice;

  /// P2b: shared controller for the in-composer sticker picker (loads packs +
  /// recents). When null, the sticker tab stays a «скоро» stub.
  final AppController? stickerController;

  /// P2b: fired when the user picks a sticker to send.
  final ValueChanged<SecretlyStickerDescriptor>? onSendSticker;

  /// E9 drafts: text to prefill the composer with on open (the saved draft for
  /// this conversation), and a callback reporting every edit so the host can
  /// persist it. The host (keyed per conversation) owns the per-convo store.
  final String? initialDraft;
  final ValueChanged<String>? onDraftChanged;

  /// Превью ссылки, которую человек набирает. `null` — превью выключены в
  /// настройках: поле ввода не показывает карточку и не ходит за страницей.
  final OutgoingLinkPreviewDraft? linkPreviewDraft;
  final VoidCallback? onToggleDetails;

  /// Видны ли свежие сообщения — лента не отлистана вверх (17.09.2026).
  /// Хозяин по нему решает, можно ли отметить новое прочитанным.
  final ValueChanged<bool>? onNearLatestChanged;
  final VoidCallback? onCall;
  final VoidCallback? onVideoCall;
  final bool detailsOpen;
  final bool searchOpen;

  /// Unread messages at the moment this chat was opened. Drives the «новые
  /// сообщения» divider — without it a long thread gives no clue where you
  /// stopped reading, which is the whole reason people scroll up hunting.
  ///
  /// Captured once on open rather than tracked live: a counter that ticks down
  /// as you read would move the line under your eyes.
  final int unreadCount;
  final VoidCallback? onToggleSearch;

  /// Меню чата из шапки. `null` — кнопки «…» нет.
  ///
  /// 🔴 Те же действия, что и по правому щелчку в списке: беззвучный режим,
  /// закрепление, архив, очистка, удаление. Раньше, чтобы отключить звук у
  /// ОТКРЫТОГО чата, надо было вернуться к его строке в списке и щёлкнуть
  /// правой кнопкой — то есть уйти оттуда, где ты сейчас читаешь.
  final void Function(Offset globalPosition)? onHeaderMenu;

  /// Wallpaper id resolved through `chat_wallpapers.dart`. Null means use the
  /// default surface (no image) — keeps the existing look for callers that
  /// haven't been migrated yet.
  final String? wallpaperId;

  /// Background animation behaviour and the «проводит сообщение» switch, both
  /// read from the shared controller — a choice made on the phone applies here.
  /// Название темы, в которую человек пишет прямо сейчас.
  ///
  /// 🔴 Это не украшение. Самая дорогая ошибка в мессенджере с темами —
  /// написать не туда: сообщение уходит трём десяткам человек в «Общий»
  /// вместо пяти в «Багрепорты», и отменить это уже нельзя. Подпись у поля
  /// ввода отвечает на вопрос «куда я пишу» в тот момент, когда человек
  /// смотрит на поле, а не на полосу тем наверху.
  ///
  /// `null` — личная переписка или «Общий»: там подпись не нужна, лишний текст
  /// в пустом поле только шумит.
  final String? composerTopicTitle;

  /// Полоса тем комнаты под шапкой ([RoomTopicsStrip]).
  ///
  /// Панель её НЕ СТРОИТ и про темы ничего не знает: состояние тем живёт в
  /// секции чатов, вместе с выбором темы и фильтром сообщений. Панель только
  /// отводит ей место — так полоса появляется ровно там, где её ждёт глаз
  /// (сразу под именем собеседника), и при этом панель не обрастает десятком
  /// сквозных параметров.
  ///
  /// `null` — комната без тем или личная переписка: места не занимает.
  final Widget? topicsStrip;

  /// Плашка «Идёт обсуждение», когда в комнате идёт созвон. `null` — созвона
  /// нет, и места плашка не занимает.
  ///
  /// Панель её не строит и о созвонах не знает: живое состояние читает секция
  /// чатов, у которой есть контроллер. Здесь только место в разметке.
  final Widget? callBanner;

  /// Логический идентификатор закреплённого в комнате сообщения.
  ///
  /// 🔴 Закрепление в комнатах работало ровно наполовину: состояние комнаты
  /// его несёт и телефон его ставит, а на компьютере не было ни плашки, ни
  /// пункта меню. То есть закреплённое на телефоне сообщение на компьютере
  /// просто НЕ СУЩЕСТВОВАЛО — а это ровно то сообщение, которое просили
  /// заметить в первую очередь.
  ///
  /// `null` — ничего не закреплено (или это личная переписка).
  final String? pinnedPayloadEventId;

  /// Закрепить/открепить сообщение. `null` — действие недоступно (личная
  /// переписка или у человека нет на это права), и пункт меню не рисуется.
  final void Function(MessageData message, bool pin)? onTogglePinMessage;

  final ChatWallpaperAnimMode wallpaperAnimMode;
  final bool wallpaperConduct;

  /// Called when the user picks a reaction emoji for [message]. Emitted from
  /// either the bubble's hover quick-reaction bar OR the "+ more" emoji
  /// popover anchored to the bubble. The host is expected to call into the
  /// AppController (`toggleMessageReaction` + `broadcastReactionUpdate`) so
  /// the reaction lands on this device and fans out to peer + own other
  /// devices (TZ §21.1).
  final MessageReactionCallback? onReactToMessage;

  /// Called when the user clicks an existing reaction chip on [message].
  /// Mirrors mobile behaviour: clicking the chip you already added removes
  /// your reaction; clicking someone else's chip adds your own reaction with
  /// the same emoji (toggle semantics handled inside the controller).
  final MessageReactionCallback? onTapExistingReaction;

  /// «Продолжить в теме»: показать выбор ветки у точки [globalPosition] и
  /// переключиться в выбранную. Возвращает `true`, если ветку выбрали — тогда
  /// панель сама откроет поле ввода с цитатой сообщения.
  ///
  /// `null` — веток в этом чате нет, и кнопки в строке наведения тоже.
  ///
  /// 🔴 Темы живут в секции чатов, а поле ввода — здесь. Поэтому работа
  /// поделена по месту хранения: выбор ветки спрашиваем у хозяина, цитату
  /// ставим сами. Иначе секции пришлось бы дотягиваться до состояния панели.
  final Future<bool> Function(Offset globalPosition)? onContinueInTopic;

  /// · «Игорь печатает» ПЛАШКОЙ В САМОЙ ЛЕНТЕ (макет), а не только подписью
  /// в шапке.
  ///
  /// Подпись в шапке видна лишь тому, кто туда смотрит, а смотрят в низ ленты —
  /// туда, где сообщение вот-вот появится. Готовый текст, а не признак: кто
  /// печатает, знает хозяин — в личной переписке это собеседник по имени, в
  /// комнате имени нет вовсе (протокол его не передаёт), и там плашка говорит
  /// просто «печатает».
  ///
  /// `null` — никто не печатает, плашки нет.
  final String? typingLabel;

  /// Кого можно позвать через «@» в этом чате. Пусто у личной переписки.
  final List<DesktopMentionTarget> mentionTargets;

  /// Свой профиль — чтобы фишка «@…» читалась как обращение КО МНЕ.
  final String selfProfileId;

  /// Достаётся ли мне «@admins».
  final bool canReceiveAdminMentions;

  /// Нажатие по фишке поимённого упоминания: открыть профиль человека.
  final ValueChanged<String>? onOpenProfile;

  /// Сменить скорость воспроизведения голосового.
  final ValueChanged<double>? onSetVoiceSpeed;

  /// PR7: fired when the user has scrolled to the very top of the
  /// thread and we need to fetch an older page. Returns a future that
  /// completes when the page has been loaded — the panel uses this to
  /// suppress duplicate triggers and (optionally) show a small
  /// «Loading older…» strip above the topmost bubble.
  ///
  /// `null` (default) ⇒ no pagination wired; the user just hits the
  /// top of the local DB and stops there.
  final Future<void> Function()? onLoadOlder;

  /// PR8: bubble's image tap. Host opens the fullscreen photo viewer.
  final ValueChanged<MessageData>? onOpenImage;

  /// PR8: bubble's video tap. Host opens the fullscreen video player.
  final ValueChanged<MessageData>? onOpenVideo;

  /// PR8: bubble's generic-file tap. Host reveals in Finder / opens
  /// with the default app.
  final ValueChanged<MessageData>? onOpenFile;

  /// Нажали на стикер — показать набор, из которого он.
  final ValueChanged<MessageData>? onOpenStickerPack;

  /// Нажали вариант опроса.
  final void Function(MessageData message, int optionIndex)? onPollVote;

  /// Создатель опроса нажал «Завершить опрос».
  final ValueChanged<MessageData>? onPollClose;

  /// Ответили на событие.
  final void Function(MessageData message, String status)? onEventRsvp;

  /// Нажали «Опрос» в меню вложений. `null` — опрос здесь невозможен
  /// (личная переписка: опрос живёт в комнате).
  final Future<void> Function()? onComposePoll;

  /// Нажали «Событие» в меню вложений. `null` — как у опроса.
  final Future<void> Function()? onComposeEvent;

  /// PR8: bubble's voice-note play/pause tap. Host hands off to
  /// `AppController.toggleSharedAudioTrack`.
  final ValueChanged<MessageData>? onToggleVoice;

  /// Перемотка голосового долей 0..1 — см. `MessageBubble.onSeekVoice`.
  final void Function(MessageData message, double fraction)? onSeekVoice;

  /// «Сохранить как…» прямо из ленты — см. `MessageBubble.onSaveAttachment`.
  final ValueChanged<MessageData>? onSaveAttachment;

  /// «Загрузить» у файла и повтор неудавшейся загрузки снимка.
  final ValueChanged<MessageData>? onDownloadAttachment;

  /// «Показать в Finder» у скачанного файла.
  final ValueChanged<MessageData>? onRevealAttachment;

  /// PR8: shared audio player snapshot. We rebuild each bubble with the
  /// current value via [ValueListenableBuilder] so the bubble knows whether
  /// it's the active track + its current position/duration. `null` means
  /// "no shared player wired" (legacy tests / screenshots).
  final ValueListenable<SharedAudioPlaybackState>? sharedAudio;

  @override
  State<ChatThreadPanel> createState() => _ChatThreadPanelState();
}

class _ChatThreadPanelState extends State<ChatThreadPanel> {
  final _composer = TextEditingController();

  /// Выделенные сообщения — по `MessageData.id`. Пусто — режима выделения
  /// нет.
  final Set<String> _selected = <String>{};

  /// Узел фокуса всей ленты: через него идут её горячие клавиши.
  final FocusNode _panelFocus = FocusNode(debugLabel: 'chat-thread-panel');

  bool get _selecting => _selected.isNotEmpty;

  void _toggleSelected(MessageData m) {
    // Уходящее вложение ещё не сообщение: пересылать и удалять нечего.
    if (m.isUploading) return;
    final starting = _selected.isEmpty;
    setState(() {
      if (!_selected.remove(m.id)) _selected.add(m.id);
    });
    if (starting) _focusPanelForSelection();
  }

  /// Escape должен снимать выделение, а до ленты он доходит, только если
  /// фокус внутри неё. После щелчка по сообщению или закрытого меню фокуса
  /// там может не быть — ставим его сами. Поле ввода, если курсор в нём,
  /// не трогаем: оно и так внутри ленты.
  ///
  /// Выделенный в пузыре ТЕКСТ при этом снимается: в режиме выделения
  /// сообщений текст не выделяется, и старая подсветка вводила бы в
  /// заблуждение.
  void _focusPanelForSelection() {
    if (_textSelection != null) {
      _dropTextSelection();
    } else if (!_panelFocus.hasFocus) {
      _panelFocus.requestFocus();
    }
  }

  // ── Выделение сообщений протягиванием ─────────────────────────────────
  //
  // 🔴 Указание владельца 16.09.2026: «выделение работает очень криво!
  // Пузыри должны выделяться, если я нажал ЛКМ и даже чуть-чуть провёл на
  // пустом месте от пузыря, и при ведении дальше вверх или вниз также должны
  // выделяться другие».
  //
  // Было только удержание: полсекунды неподвижно, и лишь одно сообщение за
  // раз. Теперь, как в телеграме: нажал рядом с пузырём, повёл — отмечается
  // всё между первым сообщением и тем, над которым курсор. Повёл обратно —
  // отметки снимаются. Начал на уже отмеченном — протягивание снимает
  // отметки. У края ленты она сама прокручивается дальше.
  //
  // Жест один на всю ленту ([RowDragSelectRecognizer]): строка под курсором
  // узнаётся проверкой попадания по метке строки ([DesktopMessageRowTag]).

  final GlobalKey _listKey = GlobalKey(debugLabel: 'thread-list');

  /// Сообщение, с которого начали вести. `null` — протягивания нет.
  String? _dragAnchorId;

  /// Отметки до начала протягивания: диапазон ложится поверх них.
  Set<String> _dragBase = const <String>{};

  /// Протягивание снимает отметки (начато на отмеченном сообщении).
  bool _dragDeselect = false;

  /// Сообщение, отмеченное удержанием в этом же нажатии: протягивание после
  /// удержания продолжает отмечать, а не снимает только что поставленное.
  String? _longPressId;

  Offset? _dragPointer;
  Timer? _autoScrollTimer;
  double _autoScrollSpeed = 0;

  List<MessageData>? _indexedMessages;
  Map<String, int> _indexById = const <String, int>{};

  int _indexOf(String id) {
    if (!identical(_indexedMessages, widget.messages)) {
      _indexedMessages = widget.messages;
      _indexById = <String, int>{
        for (var i = 0; i < widget.messages.length; i++)
          widget.messages[i].id: i,
      };
    }
    return _indexById[id] ?? -1;
  }

  /// Что под курсором: строка сообщения и место внутри пузыря.
  ({String? rowId, bool inText, bool inMedia}) _zonesAt(Offset global) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      global,
      View.of(context).viewId,
    );
    String? rowId;
    var inText = false;
    var inMedia = false;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderMetaData) continue;
      final data = target.metaData;
      if (data is DesktopMessageRowTag) {
        rowId ??= data.id;
      } else if (data == DesktopBubbleZone.text) {
        inText = true;
      } else if (data == DesktopBubbleZone.media) {
        inMedia = true;
      }
    }
    return (rowId: rowId, inText: inText, inMedia: inMedia);
  }

  /// Строка под курсором. С [clamp] курсор за пределами ленты (над шапкой,
  /// над полем ввода) прижимается к её видимому краю — так протягивание за
  /// край продолжает отмечать крайние сообщения.
  String? _rowIdAt(Offset global, {bool clamp = false}) {
    var probe = global;
    if (clamp) {
      final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final local = box.globalToLocal(global);
        final maxX = math.max(1.0, box.size.width - 16);
        final maxY = math.max(1.0, box.size.height - _composerHeight - 1);
        probe = box.localToGlobal(
          Offset(local.dx.clamp(1.0, maxX), local.dy.clamp(1.0, maxY)),
        );
      }
    }
    return _zonesAt(probe).rowId;
  }

  bool _canStartRowGesture(Offset global) {
    final zones = _zonesAt(global);
    if (zones.rowId == null) return false;
    // В режиме выделения содержимое пузырей не нажимается вовсе — строка
    // отмечается откуда угодно.
    if (_selecting) return true;
    return !zones.inText && !zones.inMedia;
  }

  bool _onRowClick(Offset global) {
    if (!_selecting) return false;
    final id = _rowIdAt(global);
    if (id == null) return false;
    final index = _indexOf(id);
    if (index < 0) return false;
    _toggleSelected(widget.messages[index]);
    return true;
  }

  void _onRowLongPress(Offset global) {
    final id = _rowIdAt(global);
    if (id == null) return;
    final index = _indexOf(id);
    if (index < 0) return;
    _longPressId = id;
    if (!_selected.contains(id)) _toggleSelected(widget.messages[index]);
  }

  void _onRowDragStart(Offset down) {
    final id = _rowIdAt(down);
    if (id == null) return;
    if (_textSelection != null) _dropTextSelection();
    _dragAnchorId = id;
    _dragBase = Set<String>.of(_selected);
    _dragDeselect = _longPressId != id && _selected.contains(id);
    _applyDragRange(id);
  }

  void _onRowDragUpdate(Offset global) {
    if (_dragAnchorId == null) return;
    _dragPointer = global;
    final id = _rowIdAt(global, clamp: true);
    if (id != null) _applyDragRange(id);
    _updateAutoScroll(global);
  }

  void _onRowDragEnd() {
    _dragAnchorId = null;
    _dragPointer = null;
    _longPressId = null;
    _dragBase = const <String>{};
    _stopAutoScroll();
  }

  /// Отмечает (или снимает) всё между начальным сообщением и [currentId].
  void _applyDragRange(String currentId) {
    final anchor = _dragAnchorId;
    if (anchor == null) return;
    final a = _indexOf(anchor);
    final b = _indexOf(currentId);
    if (a < 0 || b < 0) return;
    final next = Set<String>.of(_dragBase);
    for (var i = math.min(a, b); i <= math.max(a, b); i++) {
      if (widget.messages[i].isUploading) continue;
      final id = widget.messages[i].id;
      if (_dragDeselect) {
        next.remove(id);
      } else {
        next.add(id);
      }
    }
    if (setEquals(next, _selected)) return;
    final starting = _selected.isEmpty;
    setState(() {
      _selected
        ..clear()
        ..addAll(next);
    });
    if (starting && next.isNotEmpty) _focusPanelForSelection();
  }

  /// Полоса у края ленты, в которой она сама прокручивается дальше.
  static const double _autoScrollZone = 40;

  void _updateAutoScroll(Offset global) {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final y = box.globalToLocal(global).dy;
    // Низ ленты закрыт полем ввода — край там, где поле начинается.
    final bottom = box.size.height - _composerHeight;
    var speed = 0.0;
    if (y < _autoScrollZone) {
      // Вверх, к старым. Лента перевёрнута: старое — в сторону роста
      // смещения.
      speed = (_autoScrollZone - y) / _autoScrollZone;
    } else if (y > bottom - _autoScrollZone) {
      speed = -(y - (bottom - _autoScrollZone)) / _autoScrollZone;
    }
    _autoScrollSpeed = speed.clamp(-3.0, 3.0).toDouble();
    if (_autoScrollSpeed == 0) {
      _stopAutoScroll();
      return;
    }
    _autoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _autoScrollTick(),
    );
  }

  void _autoScrollTick() {
    if (!mounted || _dragAnchorId == null || !_scroll.hasClients) {
      _stopAutoScroll();
      return;
    }
    final pos = _scroll.position;
    final next = (pos.pixels + _autoScrollSpeed * 12)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent)
        .toDouble();
    if (next == pos.pixels) return;
    _scroll.jumpTo(next);
    // Под курсором теперь другое сообщение — но узнать это можно только
    // после раскладки нового кадра.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = _dragPointer;
      if (!mounted || p == null || _dragAnchorId == null) return;
      final id = _rowIdAt(p, clamp: true);
      if (id != null) _applyDragRange(id);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollSpeed = 0;
  }

  Widget _withRowDragSelect(Widget list) => Listener(
    onPointerDown: _onListPointerDown,
    child: RawGestureDetector(
      key: _listKey,
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        RowDragSelectRecognizer:
            GestureRecognizerFactoryWithHandlers<RowDragSelectRecognizer>(
              () => RowDragSelectRecognizer(debugOwner: this),
              (r) => r
                ..canStart = _canStartRowGesture
                ..onClick = _onRowClick
                ..onLongPress = _onRowLongPress
                ..onDragStart = _onRowDragStart
                ..onDragUpdate = _onRowDragUpdate
                ..onDragEnd = _onRowDragEnd,
            ),
      },
      child: list,
    ),
  );

  // ── Выделенный текст в пузыре ─────────────────────────────────────────

  /// Какое сообщение и что в нём выделено мышью. Одновременно — одно:
  /// выделение живёт, пока у его текста фокус.
  ({String id, String text})? _textSelection;

  void _onBubbleTextSelection(String id, String text) {
    if (text.isEmpty) {
      if (_textSelection?.id == id) _textSelection = null;
      return;
    }
    _textSelection = (id: id, text: text);
  }

  /// Снять выделение текста: фокус уходит на ленту, и выделяемый текст
  /// гасит подсветку сам.
  void _dropTextSelection() {
    _textSelection = null;
    _panelFocus.requestFocus();
  }

  void _onListPointerDown(PointerDownEvent event) {
    _longPressId = null;
    if (event.buttons != kPrimaryButton || _textSelection == null) return;
    // Щелчок мимо текста снимает выделение — как в любом текстовом окне.
    if (!_zonesAt(event.position).inText) _dropTextSelection();
  }

  void _clearSelection() {
    if (_selected.isEmpty) return;
    setState(_selected.clear);
  }

  /// Выделенное — в порядке переписки, от старых к новым: так его и
  /// пересылают, и копируют.
  ///
  /// Альбом раскрывается в свои сообщения: переслать, сохранить или удалить
  /// альбом — значит сделать это с каждым его снимком.
  List<MessageData> get _selectedMessages => [
    for (final m in widget.messages)
      if (_selected.contains(m.id) && !m.isUploading) ...m.expanded,
  ];

  /// Отдать выделенное действию и выйти из режима. Выходим ДО действия:
  /// диалог пересылки или удаления иначе открывался бы над лентой, где всё
  /// ещё горят галочки уже отданных сообщений.
  void _runOnSelected(ValueChanged<List<MessageData>> action) {
    final picked = _selectedMessages;
    _clearSelection();
    if (picked.isNotEmpty) action(picked);
  }

  /// Копия выделенного — «Автор: текст» построчно, как на телефоне.
  void _copySelected() {
    final lines = <String>[];
    for (final m in _selectedMessages) {
      final body = _copyableText(m);
      if (body.isEmpty) continue;
      lines.add('${m.authorName}: $body');
    }
    _clearSelection();
    if (lines.isEmpty) return;
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    DesktopSnackbar.show(
      context,
      message: 'Скопировано',
      kind: DSnackKind.success,
    );
  }

  /// Действие над строкой: у обычной — над ней, у альбома — над всеми его
  /// сообщениями сразу (если хозяин умеет пачкой), иначе над первым.
  void _onRowItems(
    MessageData row,
    ValueChanged<MessageData> single,
    ValueChanged<List<MessageData>>? many,
  ) {
    final items = row.albumItems;
    if (items != null && many != null) {
      many(items);
    } else {
      single(row);
    }
  }

  /// Текст сообщения для копии; у вложения без подписи — его вид.
  static String _copyableText(MessageData m) {
    final text = m.text.trim();
    if (text.isNotEmpty) return text;
    if (m.sticker != null) return 'Стикер';
    final att = m.attachment;
    if (att == null) return '';
    final name = (att.fileName ?? '').trim();
    switch (att.kind) {
      case MessageAttachmentKind.image:
        return 'Фото';
      case MessageAttachmentKind.video:
        return 'Видео';
      case MessageAttachmentKind.voice:
        return 'Голосовое сообщение';
      default:
        return name.isNotEmpty ? name : 'Файл';
    }
  }
  final _attachKey = GlobalKey();
  final _emojiKey = GlobalKey();
  final _scroll = ScrollController();

  /// Handle on the animated wallpaper so a sent or received message can send a
  /// light wave through it. Null-safe by construction: the key only resolves
  /// when an `anim:` wallpaper is actually mounted, so the static backgrounds
  /// simply never pulse.
  final GlobalKey<TelegramWallpaperState> _wallpaperKey =
      GlobalKey<TelegramWallpaperState>();

  /// Number of messages last seen, so an ARRIVING message can be told apart
  /// from a rebuild. Without this the wave would fire on every repaint.
  int _lastMessageCount = 0;

  /// Unread count latched when this conversation opened. Latched rather than
  /// read live so the divider stays put while you read past it.
  int _openedUnread = 0;

  /// Fires the «проводит сообщение» wave.
  ///
  /// Outgoing runs upward away from you, incoming downward toward you — the
  /// direction of the light is the direction of the conversation. Guarded on
  /// the setting so the shader and its 49 KB field are never even loaded when
  /// the effect is off.
  void _conductWallpaper({required bool incoming}) {
    if (!mounted || !widget.wallpaperConduct) return;
    _wallpaperKey.currentState?.conductMessage(incoming: incoming);
  }

  ComposerContext? _ctx;

  /// Была ли открытая карточка ПРАВКОЙ. Нужна на отмену по Escape: у правки
  /// текст в поле подставлен приложением и без карточки превратился бы в новое
  /// сообщение, у ответа — набран человеком, и стирать его нельзя.
  bool _ctxWasEdit = false;
  bool _dropVisible = false;
  bool _scrolledUp = false;

  /// Id of the message currently flashing (jump-to-reply highlight). Mirrors
  /// mobile's `_HighlightWrapper` — a brief accent-tinted fade so the user's
  /// eye finds the quoted message after the scroll-into-view animation.
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  /// Per-bubble anchor keys for the reactions popover. Allocated lazily on
  /// first hover/right-click for a given message id and reused for the life
  /// of this panel state so the popover lands on the same RenderObject every
  /// time (re-allocating on every rebuild would break `findRenderObject`
  /// during the popover open animation).
  final Map<String, GlobalKey> _bubbleAnchors = {};

  /// PR7: pagination state. `_loadingOlder` is the in-flight guard so a
  /// fast continuous scroll doesn't fire `onLoadOlder` repeatedly. Cleared
  /// when the host future resolves (success or error).
  bool _loadingOlder = false;

  GlobalKey _anchorForBubble(String messageId) {
    return _bubbleAnchors.putIfAbsent(messageId, () => GlobalKey());
  }

  // --- In-chat search state ---
  final TextEditingController _searchCtl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  // Indices into widget.messages where text matches the query.
  List<int> _matchIndices = const [];
  int _matchCursor = 0;

  @override
  void initState() {
    super.initState();
    // Latched here, not read live: a count that ticks down as you read would
    // slide the divider around under your eyes.
    _openedUnread = widget.unreadCount;
    _scroll.addListener(_onScroll);
    // E9 drafts: restore this conversation's saved draft, then report edits.
    final draft = widget.initialDraft;
    if (draft != null && draft.isNotEmpty) {
      _composer.text = draft;
      _composer.selection = TextSelection.collapsed(
        offset: _composer.text.length,
      );
    }
    _composer.addListener(_reportDraft);
    _composer.addListener(_syncLinkDraft);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toBottom(jump: true);
      // После кадра, а не прямо здесь: черновик будит слушателей, а во время
      // построения дерева будить чужие виджеты нельзя. Сохранённый черновик
      // со ссылкой получает карточку так же, как набранный.
      if (mounted) _syncLinkDraft();
    });
  }

  void _reportDraft() => widget.onDraftChanged?.call(_composer.text);

  /// Черновик превью следит за полем ввода. У правки своей карточки нет —
  /// остаётся карточка исходного сообщения, — поэтому на время правки
  /// черновик пуст и за страницей никто не ходит.
  void _syncLinkDraft() {
    final draft = widget.linkPreviewDraft;
    if (draft == null) return;
    draft.update((_ctx?.isEdit ?? false) ? '' : _composer.text);
  }

  @override
  void didUpdateWidget(covariant ChatThreadPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Превью включили или выключили в настройках.
    if (!identical(widget.linkPreviewDraft, oldWidget.linkPreviewDraft)) {
      final old = oldWidget.linkPreviewDraft;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old?.reset();
        if (mounted) _syncLinkDraft();
      });
    }

    // «Проводит сообщение»: one wave per newly-arrived message, keyed on the
    // list GROWING rather than on any rebuild — the panel repaints constantly
    // (typing, receipts, reactions) and each of those must not flash the
    // wallpaper. Direction comes from who wrote the newest message.
    final count = widget.messages.length;
    if (count > _lastMessageCount && widget.messages.isNotEmpty) {
      // LAST, not first: `messages` is chronological (index 0 is the oldest),
      // and the reversed ListView maps index 0 on screen to the last element.
      // Reading `.first` here took the direction from the conversation's very
      // OLDEST message, so the wave ran the wrong way about half the time.
      final newest = widget.messages.last;
      _conductWallpaper(incoming: !newest.isSelf);
    }
    _lastMessageCount = count;

    // Удалённое (здесь или на другом устройстве) из выделения уходит само:
    // иначе счётчик в панели обещал бы действие над тем, чего уже нет.
    if (_selected.isNotEmpty && !identical(widget.messages, oldWidget.messages)) {
      final alive = {for (final m in widget.messages) m.id};
      _selected.removeWhere((id) => !alive.contains(id));
    }

    // Auto-focus the field when the search banner opens.
    if (widget.searchOpen && !oldWidget.searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
    // Reset state when the search banner closes.
    if (!widget.searchOpen && oldWidget.searchOpen) {
      _searchCtl.clear();
      _searchQuery = '';
      _matchIndices = const [];
      _matchCursor = 0;
    }
    // Re-run an active search if the message list changed under us.
    if (widget.searchOpen &&
        _searchQuery.isNotEmpty &&
        !identical(widget.messages, oldWidget.messages)) {
      _runSearch(_searchQuery, preserveCursor: true);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // We use reverse ListView, so offset 0 = bottom.
    final up = _scroll.offset > 200;
    if (up != _scrolledUp) {
      setState(() => _scrolledUp = up);
      widget.onNearLatestChanged?.call(!up);
    }

    // PR7: "Load older" trigger. Because the list is reversed,
    // `maxScrollExtent` is the TOP of the chat (oldest message side).
    // Fire the host callback when we get within 240px of it — a small
    // buffer means the next page lands before the user actually hits
    // the edge. `_loadingOlder` blocks re-entry while the host is busy.
    final cb = widget.onLoadOlder;
    if (cb != null && !_loadingOlder) {
      final pos = _scroll.position;
      if (pos.maxScrollExtent > 0 && pos.pixels >= pos.maxScrollExtent - 240) {
        _loadingOlder = true;
        // Schedule on next frame so setState doesn't fight a build.
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await cb();
          } catch (_) {
            // host swallows its own errors; we just need to clear
            // the guard so a later scroll can retry.
          } finally {
            if (mounted) {
              setState(() => _loadingOlder = false);
            } else {
              _loadingOlder = false;
            }
          }
        });
      }
    }
  }

  void _toBottom({bool jump = false}) {
    if (!_scroll.hasClients) return;
    if (jump) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: DMotion.xslow,
        curve: DMotion.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _composer.removeListener(_reportDraft);
    _composer.removeListener(_syncLinkDraft);
    _scroll.dispose();
    _composer.dispose();
    _searchCtl.dispose();
    _searchFocus.dispose();
    _panelFocus.dispose();
    _highlightTimer?.cancel();
    _stopAutoScroll();
    super.dispose();
  }

  // --- In-chat search helpers ---

  void _runSearch(String raw, {bool preserveCursor = false}) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _searchQuery = '';
        _matchIndices = const [];
        _matchCursor = 0;
      });
      return;
    }
    final found = <int>[];
    for (var i = 0; i < widget.messages.length; i++) {
      if (widget.messages[i].text.toLowerCase().contains(q)) {
        found.add(i);
      }
    }
    setState(() {
      _searchQuery = q;
      _matchIndices = found;
      if (found.isEmpty) {
        _matchCursor = 0;
      } else if (preserveCursor && _matchCursor < found.length) {
        // keep cursor in range
      } else {
        // Start from the most recent (last) match so users see context near
        // the bottom of the conversation first.
        _matchCursor = found.length - 1;
      }
    });
    if (found.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  void _prevMatch() {
    if (_matchIndices.isEmpty) return;
    setState(() {
      _matchCursor =
          (_matchCursor - 1 + _matchIndices.length) % _matchIndices.length;
    });
    _scrollToCurrent();
  }

  void _nextMatch() {
    if (_matchIndices.isEmpty) return;
    setState(() {
      _matchCursor = (_matchCursor + 1) % _matchIndices.length;
    });
    _scrollToCurrent();
  }

  void _scrollToCurrent() {
    if (_matchIndices.isEmpty) return;
    final msgIdx = _matchIndices[_matchCursor];
    if (msgIdx < 0 || msgIdx >= widget.messages.length) return;
    final id = widget.messages[msgIdx].id;
    // Use the same anchor GlobalKey we attach to the bubble for popovers —
    // avoids allocating a parallel GlobalObjectKey set, which used to cause
    // re-parenting jitter when the list rebuilt during typing.
    final anchorKey = _bubbleAnchors[id];
    final ctx = anchorKey?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: DMotion.fast,
        curve: DMotion.easeOutCubic,
      );
    }
  }

  KeyEventResult _handleShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isMeta =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (isMeta && event.logicalKey == LogicalKeyboardKey.keyF) {
      widget.onToggleSearch?.call();
      return KeyEventResult.handled;
    }
    // Выделенный текст — тоже «открытое последним».
    if (_textSelection != null &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _dropTextSelection();
      return KeyEventResult.handled;
    }
    // Выделение — то, что открыли последним: Escape снимает его первым.
    if (_selecting && event.logicalKey == LogicalKeyboardKey.escape) {
      _clearSelection();
      return KeyEventResult.handled;
    }
    if (widget.searchOpen && event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onToggleSearch?.call();
      return KeyEventResult.handled;
    }
    // 🔴 ESCAPE ОТМЕНЯЕТ ОТВЕТ И ПРАВКУ.
    //
    // Отменить их можно было только крестиком в карточке — крохотной мишенью
    // в дальнем углу поля. Escape — первое, что жмёт человек, передумавший
    // отвечать, и до сих пор он не делал НИЧЕГО: карточка оставалась, и
    // следующее сообщение уходило ответом на то, на что отвечать уже
    // расхотелось.
    //
    // Порядок важен: пока открыт поиск, Escape закрывает его (проверка выше) —
    // закрывать надо то, что человек открыл последним.
    if (_ctx != null && event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _ctx = null;
        // Правка без карточки — это уже не правка, а новое сообщение: текст,
        // подставленный из правимого, надо убрать вместе с ней. У ответа поле
        // человек набирал сам, и стирать его нельзя.
        if (_ctxWasEdit) _composer.clear();
        _ctxWasEdit = false;
      });
      return KeyEventResult.handled;
    }
    if (widget.searchOpen &&
        _matchIndices.isNotEmpty &&
        event.logicalKey == LogicalKeyboardKey.f3) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _prevMatch();
      } else {
        _nextMatch();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final currentMatchMsgIdx = (widget.searchOpen && _matchIndices.isNotEmpty)
        ? _matchIndices[_matchCursor]
        : -1;
    final matchSet = (widget.searchOpen && _matchIndices.isNotEmpty)
        ? _matchIndices.toSet()
        : const <int>{};
    return Focus(
      focusNode: _panelFocus,
      autofocus: false,
      onKeyEvent: (_, e) => _handleShortcut(e),
      child: DropTarget(
        // 🔴 ТОЛЬКО ПОКА ЛЕНТА — ВЕРХНИЙ ЭКРАН. Цель броска слышит события
        // независимо от окон поверх неё (так устроен `desktop_drop`): без
        // этого файл, брошенный на любое окно, уходил бы в переписку под ним.
        enable:
            widget.onSendMedia != null &&
            (ModalRoute.isCurrentOf(context) ?? true),
        onDragEntered: (_) => setState(() => _dropVisible = true),
        onDragExited: (_) {
          if (_dropVisible) setState(() => _dropVisible = false);
        },
        onDragDone: (detail) {
          if (_dropVisible) setState(() => _dropVisible = false);
          _onDropPaths([for (final f in detail.files) f.path]);
        },
        child: DecoratedBox(
          // 🔴 ХОЛСТ ПЕРЕПИСКИ — НЕ ОДНА ЗАЛИВКА.
          //
          // В макете это радиальный градиент «130% 100% at 12% 0%»: светлее
          // всего в левом верхнем углу, темнее всего в правом нижнем. Плоская
          // заливка на большом экране выглядит именно плоской — переписка
          // читается как таблица, а не как поверхность, и свои пузыри внизу
          // справа теряют глубину ровно там, где взгляд задерживается дольше
          // всего.
          //
          // Радиус 1.3 по обеим осям при центре в (12%, 0) — это Alignment
          // (-0.76, -1.0) и radius ≈ 1.3 в системе координат Flutter, где
          // -1..1 покрывает всю сторону.
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.76, -1.0),
              radius: 1.3,
              colors: [c.threadGlow, c.thread, c.threadEdge],
              stops: const [0.0, 0.58, 1.0],
            ),
          ),
          child: Column(
            children: [
              if (_selecting)
                _SelectionBar(
                  count: _selected.length,
                  onCancel: _clearSelection,
                  onCopy: _copySelected,
                  onForward: widget.onForwardMessages == null
                      ? null
                      : () => _runOnSelected(widget.onForwardMessages!),
                  onSave: widget.onSaveMessages == null
                      ? null
                      : () => _runOnSelected(widget.onSaveMessages!),
                  onDelete: widget.onDeleteMessages == null
                      ? null
                      : () => _runOnSelected(widget.onDeleteMessages!),
                )
              else
                _Header(
                  header: widget.header,
                  isDirect: widget.isDirect,
                  onCall: widget.onCall,
                  onVideoCall: widget.onVideoCall,
                  onToggleSearch: widget.onToggleSearch,
                  onToggleDetails: widget.onToggleDetails,
                  detailsOpen: widget.detailsOpen,
                  onHeaderMenu: widget.onHeaderMenu,
                ),
              if (widget.topicsStrip != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(DSpace.l, 0, DSpace.l, 4),
                  child: widget.topicsStrip,
                ),
              Container(height: 1, color: c.borderSubtle),
              // Под разделителем, а не над: плашка относится к переписке, а не к
              // шапке, и подниматься вместе с темами ей незачем.
              if (widget.callBanner != null) widget.callBanner!,
              if (_pinnedMessage != null)
                _PinnedBar(
                  message: _pinnedMessage!,
                  onTap: () => _jumpToReply(widget.pinnedPayloadEventId!),
                  onUnpin: widget.onTogglePinMessage == null
                      ? null
                      : () => widget.onTogglePinMessage!(
                          _pinnedMessage!,
                          false,
                        ),
                ),
              AnimatedSize(
                duration: DMotion.fast,
                curve: DMotion.easeOutCubic,
                alignment: Alignment.topCenter,
                child: widget.searchOpen
                    ? _SearchBanner(
                        controller: _searchCtl,
                        focusNode: _searchFocus,
                        matches: _matchIndices.length,
                        current: _matchIndices.isEmpty ? 0 : _matchCursor + 1,
                        hasQuery: _searchQuery.isNotEmpty,
                        onChanged: _runSearch,
                        onPrev: _matchIndices.isEmpty ? null : _prevMatch,
                        onNext: _matchIndices.isEmpty ? null : _nextMatch,
                        onClose: widget.onToggleSearch,
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
              Expanded(
                child: Stack(
                  children: [
                    if (widget.wallpaperId != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: buildDesktopChatWallpaper(
                            context,
                            wallpaperId: widget.wallpaperId!,
                            palette: c,
                            animKey: _wallpaperKey,
                            animMode: widget.wallpaperAnimMode,
                            conduct: widget.wallpaperConduct,
                          ),
                        ),
                      ),
                    // 🔴 ПОЛЗУНОК НЕ ДОЛЖЕН УЕЗЖАТЬ ПОД ПОЛЕ ВВОДА
                    // (14.09.2026).
                    //
                    // Поле ввода теперь плавает над лентой, а полосу прокрутки
                    // рисует не разметка, а поведение прокрутки по умолчанию —
                    // и рисует её во всю высоту области. Нижняя треть ползунка
                    // оказалась под полем: взять его мышью там нельзя, и
                    // положение в переписке он показывает неверно.
                    //
                    // Свой `RawScrollbar` с отступом снизу — единственный
                    // способ это задать: `Scrollbar` отступа не принимает.
                    // Поэтому же рядом выключено поведение по умолчанию, иначе
                    // полос стало бы две.
                    ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: RawScrollbar(
                        controller: _scroll,
                        padding: EdgeInsets.only(
                          top: DSpace.s,
                          bottom: _composerHeight + DSpace.s,
                          right: 2,
                        ),
                        thickness: 6,
                        radius: const Radius.circular(3),
                        thumbColor: c.textDisabled.withValues(alpha: 0.55),
                        // Ползунок ТАЩАТ мышью — ради этого он и нужен;
                        // поведение по умолчанию мы только что выключили, и
                        // без этой строки осталась бы полоска-украшение.
                        interactive: true,
                        child: _withRowDragSelect(ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      // Снизу лента резервирует высоту поля ввода: в покое
                      // последнее сообщение стоит НАД ним, а при прокрутке
                      // уходит под него и гаснет в затенении.
                      padding: EdgeInsets.fromLTRB(
                        0,
                        DSpace.m,
                        0,
                        _composerHeight + DSpace.s,
                      ),
                      // Плашка «печатает» — ПЕРВЫЙ элемент перевёрнутой ленты,
                      // то есть самый нижний на экране: ровно там, где
                      // появится само сообщение.
                      itemCount:
                          widget.messages.length +
                          (widget.typingLabel == null ? 0 : 1),
                      // Sprint 2 UX fix (2026-05-18, SPRINT2_AUDIT §11):
                      //   `addRepaintBoundaries` is already true by default but
                      //   we set it explicitly here to make the intent clear —
                      //   each bubble must paint into its own layer so the chat
                      //   wallpaper background and unrelated bubbles don't repaint
                      //   when a single message changes (which used to cause the
                      //   "chaotic bubble appearance when typing" the user
                      //   reported).
                      addRepaintBoundaries: true,
                      addAutomaticKeepAlives: false,
                      itemBuilder: (ctx, idx) {
                        if (widget.typingLabel != null) {
                          if (idx == 0) {
                            return _TypingPill(label: widget.typingLabel!);
                          }
                          idx -= 1;
                        }
                        // reverse ordering — first item = newest
                        final msgIdx = widget.messages.length - 1 - idx;
                        final m = widget.messages[msgIdx];
                        final isCurrent = msgIdx == currentMatchMsgIdx;
                        final isMatch = matchSet.contains(msgIdx);
                        final anchorKey = _anchorForBubble(m.id);

                        // PR8: media bubbles (voice notes especially) need to
                        // see the live shared-audio state for play/pause +
                        // progress. Text bubbles don't, so we skip the
                        // ValueListenableBuilder for them to avoid rebuilding
                        // every text bubble on each audio position tick.
                        final hasMedia = m.attachment != null;
                        // E9: continuation grouping — collapse the author name
                        // and tighten the gap when this message follows one from
                        // the same author on the same calendar day (the phone's
                        // rule, see [_sameSeries]); the portrait moves to the
                        // series' last message. Render-time only; the wrapper id
                        // is unchanged so list-item keys stay stable.
                        final prevMsg = msgIdx > 0
                            ? widget.messages[msgIdx - 1]
                            : null;
                        final nextMsg = msgIdx < widget.messages.length - 1
                            ? widget.messages[msgIdx + 1]
                            : null;
                        final isContinuation =
                            prevMsg != null && _sameSeries(prevMsg, m);
                        // Портрет — у последнего сообщения серии, как на
                        // телефоне: следующее за ним уже чужое (или его нет).
                        final endsSeries =
                            nextMsg == null || !_sameSeries(m, nextMsg);
                        final mm = isContinuation
                            ? m.copyWith(continuation: true)
                            : m;
                        Widget buildBubble(SharedAudioPlaybackState? snap) {
                          return MessageBubble(
                            // ValueKey by id so the bubble's State (hover flag,
                            // scale tweens) survives ListView item recycling
                            // when the user scrolls.
                            key: ValueKey('bubble_${m.id}'),
                            message: mm,
                            showPeerIdentity: !widget.isDirect,
                            showAvatar: endsSeries,
                            translatedText: _translationShown.contains(m.id)
                                ? _translations[m.id]
                                : null,
                            translating: _translateInFlight.contains(m.id),
                            onTextSelectionChanged: (text) =>
                                _onBubbleTextSelection(m.id, text),
                            sharedAudio: snap,
                            onOpenImage: widget.onOpenImage,
                            onDownloadAttachment: widget.onDownloadAttachment,
                            onRevealAttachment: widget.onRevealAttachment,
                            onCancelUpload: widget.onCancelUpload,
                            onOpenVideo: widget.onOpenVideo,
                            onOpenFile: widget.onOpenFile,
                            onOpenStickerPack: widget.onOpenStickerPack,
                            onPollVote: widget.onPollVote,
                            onPollClose: widget.onPollClose,
                            onEventRsvp: widget.onEventRsvp,
                            onToggleVoice: widget.onToggleVoice,
                            onSeekVoice: widget.onSeekVoice,
                            onSaveAttachment: widget.onSaveAttachment,
                            onReply: () => setState(() {
                              _ctx = ComposerContext.reply(
                                authorName: m.authorName,
                                preview: m.text,
                                payloadEventId: m.payloadId ?? m.id,
                              );
                              _ctxWasEdit = false;
                            }),
                            onReplyTap: _jumpToReply,
                            // Своё имя — чтобы фишка «@…» читалась как
                            // обращение КО МНЕ, а не как чужое имя в тексте.
                            selfProfileId: widget.selfProfileId,
                            canReceiveAdminMentions:
                                widget.canReceiveAdminMentions,
                            onProfileMentionTap: widget.onOpenProfile,
                            onSetVoiceSpeed: widget.onSetVoiceSpeed,
                            onContinueInTopic:
                                widget.onContinueInTopic == null
                                ? null
                                : (pos) => unawaited(
                                    _continueInTopic(m, pos),
                                  ),
                            onReact: (e) => _onReactPicked(m, e, anchorKey),
                            onReactionTap: (emoji) =>
                                widget.onTapExistingReaction?.call(m, emoji),
                            onMoreActions: (globalPos) {
                              // Выделенное снимем СЕЙЧАС: меню заберёт фокус,
                              // и подсветка текста погаснет раньше, чем
                              // человек выберет пункт.
                              final selectedText =
                                  _textSelection?.id == m.id
                                  ? _textSelection!.text
                                  : '';
                              // PR3.8 (SPRINT2_AUDIT §13): the context menu now
                              // carries a QuickReactionRow as its header so the
                              // reactions float directly ABOVE the menu — exactly
                              // matching Telegram desktop's right-click flow.
                              // Picking an emoji from the row dismisses the menu
                              // and fans the reaction out; picking «+» dismisses
                              // the menu and opens the full in-place expandable
                              // picker anchored at the bubble.
                              ContextMenu.show(
                                context,
                                globalPosition: globalPos,
                                headerBuilder: (ctx, dismiss) {
                                  return QuickReactionRow(
                                    onPicked: (e) {
                                      dismiss();
                                      if (e == kQuickReactionsExpandSentinel) {
                                        // Defer to next frame so the menu pop
                                        // animation completes before the new
                                        // popover opens (avoids two overlapping
                                        // showGeneralDialog frames).
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) async {
                                              if (!mounted) return;
                                              final picked =
                                                  await ReactionsPopover.show(
                                                    context,
                                                    anchorKey: anchorKey,
                                                    startExpanded: true,
                                                  );
                                              if (picked == null ||
                                                  picked.isEmpty) {
                                                return;
                                              }
                                              widget.onReactToMessage?.call(
                                                m,
                                                picked,
                                              );
                                            });
                                      } else {
                                        widget.onReactToMessage?.call(m, e);
                                      }
                                    },
                                  );
                                },
                                sections: MessageContextMenu.sections(
                                  isSelf: m.isSelf,
                                  // Only real text messages are editable — mobile
                                  // refuses non-text payloads (payload is! MsgEventV1).
                                  canEdit: m.isSelf && m.isTextMessage,
                                  canDelete: true,
                                  canPin:
                                      (m.payloadId ?? m.id) !=
                                      widget.pinnedPayloadEventId,
                                  onPin: widget.onTogglePinMessage == null
                                      ? null
                                      : () => widget.onTogglePinMessage!(
                                          m,
                                          (m.payloadId ?? m.id) !=
                                              widget.pinnedPayloadEventId,
                                        ),
                                  onReply: () => setState(() {
                                    _ctx = ComposerContext.reply(
                                      authorName: m.authorName,
                                      preview: m.text,
                                      payloadEventId: m.payloadId ?? m.id,
                                    );
                                    _ctxWasEdit = false;
                                  }),
                                  onEdit: () => setState(() {
                                    _ctx = ComposerContext.edit(
                                      preview: m.text,
                                      payloadEventId: m.payloadId ?? m.id,
                                    );
                                    _ctxWasEdit = true;
                                    _composer.text = m.text;
                                  }),
                                  // PR3.9 (SPRINT2_AUDIT §14): wire Copy/Copy
                                  // link so the menu items are no longer dead
                                  // affordances. Copy puts the bubble's text on
                                  // the system clipboard; Copy link emits a
                                  // `secretly://msg/{id}` deeplink — the same
                                  // scheme already handled by the macOS
                                  // deep-link tray in Sprint 1.
                                  onCopySelection: selectedText.isEmpty
                                      ? null
                                      : () => Clipboard.setData(
                                          ClipboardData(text: selectedText),
                                        ),
                                  onCopy: () => _copyMessageText(m),
                                  onCopyLink: () => _copyMessageLink(m),
                                  // «Сохранить как…» — у одиночного вложения.
                                  onSaveAs:
                                      (m.attachment != null &&
                                          m.albumItems == null &&
                                          widget.onSaveAttachment != null)
                                      ? () => widget.onSaveAttachment!(m)
                                      : null,
                                  // 🔴 Перевод предлагаем только там, где он
                                  // осмыслен: чужое ТЕКСТОВОЕ сообщение. Своё
                                  // переводить незачем — человек сам его и
                                  // написал.
                                  onTranslate: (!m.isSelf && m.isTextMessage)
                                      ? () => unawaited(_toggleTranslate(m))
                                      : null,
                                  translationShown:
                                      _translationShown.contains(m.id),
                                  // E5: «Удалить» wired — host shows the for-me /
                                  // for-everyone confirm.
                                  // Альбом удаляется, пересылается и
                                  // сохраняется ЦЕЛИКОМ — как в Telegram.
                                  onDelete: widget.onDeleteMessage == null
                                      ? null
                                      : () => _onRowItems(
                                          m,
                                          widget.onDeleteMessage!,
                                          widget.onDeleteMessages,
                                        ),
                                  // 🔴 «ПЕРЕСЛАТЬ» ТЕПЕРЬ И У МЕДИА (16.09.2026).
                                  //
                                  // Пункт показывался только у текста: формат
                                  // пересылки несёт текст с подписью «от кого»,
                                  // а вложение надо заливать в переписку заново.
                                  // Правило «не показывать то, что откажет»
                                  // соблюдалось — но на телефоне снимки,
                                  // голосовые и наклейки пересылаются давно, и
                                  // одно меню на двух устройствах предлагало
                                  // разное. Заливку взял на себя хозяин окна.
                                  onForward: widget.onForwardMessage == null
                                      ? null
                                      : () => _onRowItems(
                                          m,
                                          widget.onForwardMessage!,
                                          widget.onForwardMessages,
                                        ),
                                  // «Сохранить» — та же пересылка, но без
                                  // выбора получателя: получатель всегда я.
                                  onSave: widget.onSaveMessage == null
                                      ? null
                                      : () => _onRowItems(
                                          m,
                                          widget.onSaveMessage!,
                                          widget.onSaveMessages,
                                        ),
                                  // Вход в выделение — с этого сообщения.
                                  onSelect: () => _toggleSelected(m),
                                  // Тот же выбор темы, что у кнопки строки
                                  // наведения, — от места щелчка.
                                  onContinueInTopic:
                                      widget.onContinueInTopic == null
                                      ? null
                                      : () => unawaited(
                                          _continueInTopic(m, globalPos),
                                        ),
                                ),
                              );
                            },
                          );
                        }

                        final Widget innerBubble =
                            (hasMedia && widget.sharedAudio != null)
                            ? ValueListenableBuilder<SharedAudioPlaybackState>(
                                valueListenable: widget.sharedAudio!,
                                builder: (ctx, snap, _) => buildBubble(snap),
                              )
                            : buildBubble(null);
                        final bubble = KeyedSubtree(
                          key: anchorKey,
                          child: innerBubble,
                        );
                        // Wrap in a stable RepaintBoundary keyed by message id so
                        // identity-comparison stays stable across the typing-driven
                        // setState bursts in `_ChatThreadHost`.
                        final isJumpHighlight = m.id == _highlightedMessageId;
                        final plainRow = RepaintBoundary(
                          key: ValueKey('rb_${m.id}'),
                          child: AnimatedContainer(
                            duration: isJumpHighlight
                                ? const Duration(milliseconds: 550)
                                : DMotion.fast,
                            curve: Curves.easeOutCubic,
                            // Без подсветки — НИКАКОЙ заливки, даже прозрачной:
                            // заливка ловит нажатия по всей ширине строки, и
                            // зажатие на пустом месте рядом с пузырём не
                            // доходило бы до подложки, начинающей выделение.
                            color: isJumpHighlight
                                ? c.accentPrimary.withValues(alpha: 0.16)
                                : (isCurrent
                                      ? c.accentPrimary.withValues(alpha: 0.10)
                                      : (isMatch
                                            ? c.accentPrimary.withValues(
                                                alpha: 0.04,
                                              )
                                            : null)),
                            child: bubble,
                          ),
                        );
                        // В режиме выделения нажатие по строке отмечает её, а
                        // не открывает снимок и не запускает голосовое.
                        // Обёртка стоит ВСЕГДА, меняется только признак: иначе
                        // вход в выделение пересоздавал бы каждый пузырь.
                        final Widget row = _SelectableRow(
                          id: m.id,
                          enabled: _selecting,
                          selected: _selected.contains(m.id),
                          child: plainRow,
                        );
                        // E9: date separator above the first message of each day.
                        // The chip rides with that message's item so the reverse
                        // ListView's index math stays untouched.
                        final showDate =
                            m.timestampMs > 0 &&
                            (msgIdx == 0 ||
                                !_sameDay(
                                  m.timestampMs,
                                  widget.messages[msgIdx - 1].timestampMs,
                                ));
                        // The unread run is the TAIL of the list, so the first
                        // unread sits `unreadCount` from the end. Own messages
                        // cannot be unread, so a thread whose tail is ours shows
                        // no line — as it should.
                        final firstUnreadIdx = _firstUnreadRow();
                        final showUnread =
                            _openedUnread > 0 &&
                            msgIdx == firstUnreadIdx &&
                            !m.isSelf;
                        if (!showDate && !showUnread) return row;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showDate)
                              _DateSeparator(
                                timestampMs: m.timestampMs,
                                palette: c,
                              ),
                            if (showUnread)
                              _UnreadSeparator(
                                palette: c,
                                count: _openedUnread,
                              ),
                            row,
                          ],
                        );
                      },
                        )),
                      ),
                    ),
                    // 🔴 ЗАТЕНЕНИЕ К НИЖНЕЙ ГРАНИЦЕ. Лежит НАД сообщениями и
                    // ПОД полем ввода: сообщение, уходящее вниз, не
                    // обрывается ровной чертой, а гаснет — как и просили в
                    // макете. Сквозное для мыши, иначе оно съедало бы
                    // нажатия по последнему пузырю.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: _composerHeight + 28,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                // Гасим В ЦВЕТ ДАЛЬНЕГО УГЛА холста, а не в
                                // средний тон: холст под затенением сам уже
                                // темнеет к низу (см. RadialGradient выше), и
                                // заливка средним тоном оставляла бы у самого
                                // края светлую полосу.
                                c.threadEdge.withValues(alpha: 0),
                                c.threadEdge.withValues(alpha: 0.75),
                                c.threadEdge,
                              ],
                              stops: const [0, 0.45, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _scrollToBottomFab(c),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _MeasuredComposer(
                        onHeight: _onComposerHeight,
                        child: _buildComposer(),
                      ),
                    ),
                    AttachmentsDropZone(visible: _dropVisible),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Высота поля ввода — её резервирует лента и по ней ставится затенение.
  ///
  /// Меняется живьём: появилась карточка ответа, текст стал многострочным,
  /// пошла запись голосового. Начальное значение — обычное однострочное поле,
  /// чтобы первый кадр не прыгал.
  double _composerHeight = 84;

  void _onComposerHeight(double h) {
    // Порог в точку: без него округление высоты дало бы бесконечный цикл
    // «перестроились — измерили — перестроились».
    if ((h - _composerHeight).abs() < 1) return;
    if (!mounted) return;
    setState(() => _composerHeight = h);
  }

  Widget _buildComposer() {
    return Composer(
                // Тема называется ЧИПОМ под полем, а не плейсхолдером:
                // плейсхолдер исчезает с первым символом. См. [Composer].
                placeholder: 'Сообщение…',
                topicTitle: widget.composerTopicTitle,
                mentionTargets: widget.mentionTargets,
                controller: _composer,
                // У правки карточка своя — от исходного сообщения.
                linkPreviewDraft: (_ctx?.isEdit ?? false)
                    ? null
                    : widget.linkPreviewDraft,
                attachAnchorKey: _attachKey,
                emojiAnchorKey: _emojiKey,
                onPasteImage: widget.onSendMedia == null
                    ? null
                    : (bytes) => unawaited(_onPasteImageBytes(bytes)),
                onPasteFiles: widget.onSendMedia == null ? null : _onDropPaths,
                onTypingActivity: widget.onTypingActivity,
                onSendVoice: widget.onSendVoice,
                context: _ctx,
                onClearContext: () => setState(() {
                  _ctx = null;
                  _ctxWasEdit = false;
                  _composer.clear();
                }),
                onSend: (txt) => _submitComposer(txt),
                onScheduleSend: widget.onSend == null
                    ? null
                    : (txt) => _submitLater(txt),
                onAttach: _openAttachMenu,
                onEmoji: _openEmoji,
                onVoice: () {},
    );
  }

  /// Закреплённое сообщение среди тех, что сейчас в ленте.
  ///
  /// Плашка показывает то, что человек может открыть нажатием. Сообщения,
  /// выпавшего из загруженного окна, здесь нет — и плашки тоже: обещать
  /// переход туда, куда перейти нельзя, хуже, чем промолчать.
  MessageData? get _pinnedMessage {
    final target = (widget.pinnedPayloadEventId ?? '').trim();
    if (target.isEmpty) return null;
    // Закреплённым может быть и снимок внутри альбома — плашка ведёт к
    // альбому целиком.
    final i = indexOfRowContaining(widget.messages, payloadId: target);
    return i < 0 ? null : widget.messages[i];
  }

  /// E9 jump-to-reply: scroll the thread to the message whose payload id the
  /// tapped quote references. Works for messages currently built in the list
  /// (reply targets are usually recent); a target paged out of view is a no-op.
  /// «Продолжить в теме»: спрашиваем ветку у хозяина, ставим цитату сами.
  ///
  /// Само сообщение НИКУДА НЕ ПЕРЕЕЗЖАЕТ — его тема запечатана в payload. В
  /// выбранной ветке появляется ответ на него, и разговор идёт дальше уже там;
  /// исходное сообщение остаётся на своём месте, и ссылка-цитата ведёт к нему.
  Future<void> _continueInTopic(MessageData m, Offset globalPosition) async {
    final picked = await widget.onContinueInTopic!(globalPosition);
    if (!picked || !mounted) return;
    setState(() {
      _ctx = ComposerContext.reply(
        authorName: m.authorName,
        preview: m.text,
        payloadEventId: m.payloadId ?? m.id,
      );
      _ctxWasEdit = false;
    });
  }

  void _jumpToReply(String targetPayloadId) {
    if (targetPayloadId.isEmpty) return;
    // Ответ мог быть на снимок внутри альбома — тогда ведём к альбому.
    final index = indexOfRowContaining(
      widget.messages,
      payloadId: targetPayloadId,
    );
    if (index < 0) return;
    final msg = widget.messages[index];
    final ctx = _bubbleAnchors[msg.id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: DMotion.medium,
        alignment: 0.3,
        curve: DMotion.easeOutCubic,
      );
    }
    _highlightTimer?.cancel();
    setState(() => _highlightedMessageId = msg.id);
    _highlightTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _highlightedMessageId = null);
    });
  }

  /// Строка, с которой начинаются непрочитанные. Счётчик считает СООБЩЕНИЯ,
  /// а альбом — одна строка из нескольких сообщений.
  int _firstUnreadRow() {
    if (_openedUnread <= 0) return -1;
    var remaining = _openedUnread;
    for (var i = widget.messages.length - 1; i >= 0; i--) {
      remaining -= widget.messages[i].expanded.length;
      if (remaining <= 0) return i;
    }
    return 0;
  }

  /// True when both epoch-ms timestamps fall on the same local calendar day.
  /// Идёт ли [b] в той же серии, что и [a], — сразу после него, от того же
  /// автора.
  ///
  /// 🔴 ПРАВИЛО ТЕЛЕФОНА, А НЕ СВОЁ (16.09.2026). Здесь было «тот же автор по
  /// ИМЕНИ и не дальше 60 секунд». Телефон собирает серию по УСТРОЙСТВУ
  /// отправителя и без окна по времени (`showGroupAvatar` в `chat_screen`):
  /// два ответа одного человека с разницей в две минуты на телефоне — одна
  /// серия, а на компьютере были две, с повтором имени и портрета. Имя к тому
  /// же не отличает двух «Участников» друг от друга.
  ///
  /// Граница дня серию рвёт: между такими сообщениями стоит плашка с датой, и
  /// склеенные через неё пузыри читались бы одной репликой.
  bool _sameSeries(MessageData a, MessageData b) {
    if (a.isSelf != b.isSelf) return false;
    final seedA = (a.authorSeed ?? '').trim();
    final seedB = (b.authorSeed ?? '').trim();
    final sameAuthor = seedA.isNotEmpty && seedB.isNotEmpty
        ? seedA == seedB
        : a.authorName == b.authorName;
    if (!sameAuthor) return false;
    if (a.timestampMs <= 0 || b.timestampMs <= 0) return false;
    return _sameDay(a.timestampMs, b.timestampMs);
  }

  bool _sameDay(int aMs, int bMs) {
    if (aMs <= 0 || bMs <= 0) return aMs == bMs;
    final a = DateTime.fromMillisecondsSinceEpoch(aMs);
    final b = DateTime.fromMillisecondsSinceEpoch(bMs);
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _scrollToBottomFab(DColorSet c) {
    // 🔴 СЧЁТЧИК У КНОПКИ «ВНИЗ» ВРАЛ (14.09.2026).
    //
    // Здесь считались ВСЕ чужие сообщения в загруженном окне ленты — то есть у
    // давно прочитанного чата на кнопке всё равно висела девятка. Счётчик,
    // который всегда показывает одно и то же, человек перестаёт читать, а
    // потом не замечает настоящую единицу.
    //
    // Непрочитанное на момент открытия у панели уже есть: по нему рисуется
    // черта «новые сообщения».
    final unread = _openedUnread.clamp(0, 99);
    return Positioned(
      right: DSpace.l,
      // Над полем ввода, а не под ним: поле теперь плавает поверх ленты.
      bottom: _composerHeight + DSpace.s,
      child: AnimatedOpacity(
        duration: DMotion.fast,
        opacity: _scrolledUp ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_scrolledUp,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.transparent,
                child: HoverListener(
                  onTap: () => _toBottom(),
                  builder: (ctx, hovered, pressed) => Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hovered ? c.elevated : c.chatList,
                      borderRadius: BorderRadius.circular(DRadii.pill),
                      border: Border.all(color: c.borderSubtle),
                      boxShadow: DShadows.card,
                    ),
                    child: Icon(
                      FluentIcons.arrow_down_24_regular,
                      size: 18,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ),
              if (_scrolledUp && unread > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // Счётчик у кнопки «вниз» — тот же красный, что и
                      // у остальных счётчиков непрочитанного.
                      // Цвет счётчика называет тип открытой переписки — тот
                      // же, что у её строки в списке.
                      color: unreadColorFor(
                        widget.isDirect ? ChatKind.direct : ChatKind.group,
                        c,
                      ),
                      borderRadius: BorderRadius.circular(DRadii.pill),
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(
                        fontFamily: DType.family,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Окно отправки файлов ─────────────────────────────────────────────

  bool _sendDialogOpen = false;

  /// Цель ответа из карточки над полем — её забирает первое, что уйдёт.
  String? get _replyTarget {
    final ctx = _ctx;
    return (ctx != null && !ctx.isEdit) ? ctx.payloadEventId : null;
  }

  void _consumeReply(String? target) {
    if (target == null || _ctx?.payloadEventId != target) return;
    setState(() => _ctx = null);
  }

  /// Файлы брошены в ленту или вставлены из буфера.
  void _onDropPaths(List<String> paths) {
    if (widget.onSendMedia == null) return;
    final limit = widget.attachmentMaxBytes;
    final intake = intakeOutgoingPaths(paths, maxBytes: limit);
    final notice = intake.rejectionText(maxBytes: limit);
    if (intake.files.isEmpty) {
      if (notice != null) {
        DesktopSnackbar.show(
          context,
          message: notice,
          kind: DSnackKind.warning,
        );
      }
      return;
    }
    unawaited(_openSendDialog(intake.files, notice: notice));
  }

  Future<void> _onPasteImageBytes(Uint8List bytes) async {
    OutgoingFile? staged;
    try {
      staged = await OutgoingMediaPrep.stagePastedImage(bytes);
    } catch (_) {
      staged = null;
    }
    if (!mounted) return;
    if (staged == null) {
      DesktopSnackbar.show(
        context,
        message: 'Не удалось вставить картинку',
        kind: DSnackKind.error,
      );
      return;
    }
    await _openSendDialog([staged]);
  }

  Future<void> _pickAndOpen({required bool media}) async {
    final pick = widget.onPickAttachments;
    if (pick == null) return;
    final paths = await pick(media: media);
    if (!mounted || paths.isEmpty) return;
    final limit = widget.attachmentMaxBytes;
    final intake = intakeOutgoingPaths(paths, maxBytes: limit);
    final notice = intake.rejectionText(maxBytes: limit);
    if (intake.files.isEmpty) {
      if (notice != null) {
        DesktopSnackbar.show(
          context,
          message: notice,
          kind: DSnackKind.warning,
        );
      }
      return;
    }
    // «Файл» в меню — значит файлом: снимки уходят без сжатия, как и на
    // телефоне из вкладки «Файл».
    await _openSendDialog(intake.files, notice: notice, sendAsFiles: !media);
  }

  /// 🔴 НАБРАННОЕ СТАНОВИТСЯ ПОДПИСЬЮ — как в Telegram. Закрыли окно —
  /// подпись возвращается в поле, ничего не теряется. У правки текст в поле —
  /// это правка, его не трогаем.
  Future<void> _openSendDialog(
    List<OutgoingFile> files, {
    String? notice,
    bool sendAsFiles = false,
  }) async {
    final send = widget.onSendMedia;
    if (send == null || files.isEmpty || _sendDialogOpen) return;
    _sendDialogOpen = true;
    final editing = _ctx?.isEdit ?? false;
    final draft = editing ? '' : _composer.text;
    if (draft.isNotEmpty) _composer.clear();
    final reply = _replyTarget;
    try {
      final outcome = await showSendMediaDialog(
        context,
        files: files,
        maxBytes: widget.attachmentMaxBytes,
        caption: draft,
        sendAsFiles: sendAsFiles,
        notice: notice,
        onPickMore: widget.onPickAttachments == null
            ? null
            : () => widget.onPickAttachments!(media: false),
      );
      if (!mounted) return;
      if (outcome is SendMediaResult) {
        _consumeReply(reply);
        await send(outcome, replyToPayloadEventId: reply);
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
        }
      } else if (outcome is SendMediaDismissed) {
        final back = outcome.caption;
        // Пока окно было открыто, в поле могли что-то набрать — не затираем.
        if (back.isNotEmpty && _composer.text.isEmpty) {
          _composer.value = TextEditingValue(
            text: back,
            selection: TextSelection.collapsed(offset: back.length),
          );
        }
      }
    } finally {
      _sendDialogOpen = false;
    }
  }

  /// Гифка из панели — сразу, без окна.
  Future<void> _sendGifNow(String path) async {
    final send = widget.onSendMedia;
    if (send == null) return;
    final intake = intakeOutgoingPaths(
      [path],
      maxBytes: widget.attachmentMaxBytes,
    );
    if (intake.files.isEmpty) return;
    final gif = intake.files.single;
    await OutgoingMediaPrep.prepare(gif);
    if (!mounted) return;
    final reply = _replyTarget;
    _consumeReply(reply);
    await send(
      SendMediaResult(
        files: [gif],
        sendAsFiles: false,
        grouped: true,
        caption: '',
      ),
      replyToPayloadEventId: reply,
    );
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
    }
  }

  Future<void> _openAttachMenu() async {
    final rb = _attachKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final canPick = widget.onPickAttachments != null && widget.onSendMedia != null;
    final sections = MessageContextMenu.attachSections(
      onPhoto: canPick ? () => unawaited(_pickAndOpen(media: true)) : null,
      onFile: canPick ? () => unawaited(_pickAndOpen(media: false)) : null,
      // Опрос (17.09.2026): пункт был заготовлен, но никуда не вёл. Карточка
      // «Контакт» и «Геопозиция» на компьютере по-прежнему не делаются —
      // геопозиции нет и на телефоне.
      onPoll: widget.onComposePoll == null
          ? null
          : () => unawaited(widget.onComposePoll!()),
      onEvent: widget.onComposeEvent == null
          ? null
          : () => unawaited(widget.onComposeEvent!()),
      eventLabel: AppLocalizations.of(context)?.desktopEventTitle,
    );
    // Nothing wired (e.g. the design demo passes no pickers) → don't pop an
    // empty menu card.
    if (sections.isEmpty) return;
    final pos = rb.localToGlobal(Offset.zero);
    await ContextMenu.show(
      context,
      globalPosition: pos.translate(0, rb.size.height + 6),
      sections: sections,
    );
  }

  /// Обычная отправка.
  ///
  /// Снимок ответа/правки берём ДО очистки и складываем в посылку, чтобы
  /// хозяин мог различить ответ, правку и обычное сообщение. Раньше состояние
  /// здесь терялось: ответ уходил без цели, а правка — новым сообщением.
  void _submitComposer(String txt, {int? scheduledAtMs}) {
    final ctx = _ctx;
    final isEdit = ctx != null && ctx.isEdit;
    // Карточку берём ДО очистки поля — очистку делает поле после этого
    // вызова. Не успела загрузиться — сообщение уходит без неё, не ждёт.
    final draft = widget.linkPreviewDraft;
    final linkPreview = isEdit ? null : draft?.takeFor(txt);
    draft?.reset();
    setState(() => _ctx = null);
    widget.onSend?.call(
      DesktopComposerSubmission(
        text: txt,
        replyToPayloadEventId:
            (ctx != null && !ctx.isEdit) ? ctx.payloadEventId : null,
        editPayloadEventId: isEdit ? ctx.payloadEventId : null,
        scheduledAtMs: scheduledAtMs,
        linkPreview: linkPreview,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  /// «Отправить позже»: спрашиваем время и отправляем тем же путём.
  ///
  /// 🔴 ПРАВКУ ОТЛОЖИТЬ НЕЛЬЗЯ, и это не придирка: правка меняет УЖЕ
  /// отправленное сообщение, у неё нет «потом». Молча превратить её в новое
  /// отложенное сообщение было бы подменой действия.
  Future<bool> _submitLater(String txt) async {
    if (_ctx != null && _ctx!.isEdit) {
      DesktopSnackbar.show(
        context,
        message: 'Правку нельзя отложить — она меняет уже отправленное',
        kind: DSnackKind.warning,
      );
      return false;
    }
    final at = await showScheduleSendDialog(context);
    if (at == null || !mounted) return false;
    _submitComposer(txt, scheduledAtMs: at.millisecondsSinceEpoch);
    DesktopSnackbar.show(
      context,
      message: 'Уйдёт ${formatScheduleMoment(at)}',
      kind: DSnackKind.success,
    );
    return true;
  }

  // ── Перевод сообщений ────────────────────────────────────────────────
  //
  // 🔴 СЧИТАЕТ САМ КОМПЬЮТЕР. Текст сообщения никуда не уходит: системный
  // переводчик macOS работает на устройстве, моделями, которые человек скачал
  // себе сам. Облачный переводчик исключён — он отдал бы наружу ровно то, что
  // приложение обещает не отдавать. Подробнее — в
  // `desktop_translation_service.dart`.
  //
  // Состояние держим ЗДЕСЬ, а не в `MessageData`: перевод — это состояние
  // просмотра, а не свойство пришедшего сообщения.

  /// id сообщения → перевод. Ключ есть, а значения нет — переводили и не
  /// вышло; повторять то же самое незачем.
  final Map<String, String?> _translations = <String, String?>{};

  /// Чей перевод сейчас показан.
  final Set<String> _translationShown = <String>{};

  /// Что переводится прямо сейчас — от двойного нажатия.
  final Set<String> _translateInFlight = <String>{};

  Future<void> _toggleTranslate(MessageData m) async {
    final id = m.id;
    if (id.isEmpty) return;
    // Показан — прячем. Оригинал на месте всегда, прятать нечего, кроме
    // добавленного.
    if (_translationShown.contains(id)) {
      setState(() => _translationShown.remove(id));
      return;
    }
    // Уже переводили — просто показываем.
    //
    // 🔴 ЗДЕСЬ ЛЕЖИТ ТОЛЬКО УДАВШЕЕСЯ. Отказ не запоминается ни тут, ни в
    // службе: «модель не скачана» человек чинит за минуту в системных
    // настройках, «не ответило в срок» проходит само. Запомненный отказ
    // ответил бы тем же и на второе нажатие — и человек, только что
    // поставивший язык, решил бы, что перевод сломан.
    final cached = _translations[id];
    if (cached != null && cached.isNotEmpty) {
      setState(() => _translationShown.add(id));
      return;
    }
    if (_translateInFlight.contains(id)) return;
    setState(() => _translateInFlight.add(id));

    final settings = await DesktopTranslationPrefs.load();
    final result = await DesktopTranslationService.instance.translate(
      text: m.text,
      targetBcp: settings.target,
      sourceBcp: settings.source,
      cacheKey: id,
    );
    if (!mounted) return;
    setState(() {
      _translateInFlight.remove(id);
      if (result.isOk) {
        _translations[id] = result.text;
        _translationShown.add(id);
      } else {
        _translations.remove(id);
      }
    });
    final complaint = result.userMessage;
    if (complaint != null) {
      DesktopSnackbar.show(
        context,
        message: complaint,
        kind: DSnackKind.warning,
      );
    }
  }

  Future<void> _openEmoji() async {
    final picked = await EmojiPopover.show(
      context,
      anchorKey: _emojiKey,
      stickerController: widget.stickerController,
      onStickerSelected: widget.onSendSticker,
      // 🔴 Гифку отправляет ТОТ ЖЕ путь, что и окно отправки файлов: он уже
      // различает личный чат и комнату, проставляет тему и умеет отвечать на
      // сообщение. Второй путь означал бы вторую правду о том, куда уходит
      // вложение, — и расхождение при первой же правке одной из них. Окна
      // для гифки нет — в Telegram она из панели уходит сразу.
      onGifFilePicked: widget.onSendMedia == null
          ? null
          : (path) => unawaited(_sendGifNow(path)),
    );
    if (picked != null) {
      final pos = _composer.selection.baseOffset.clamp(
        0,
        _composer.text.length,
      );
      _composer.text = _composer.text.replaceRange(pos, pos, picked);
      _composer.selection = TextSelection.collapsed(
        offset: pos + picked.length,
      );
    }
  }

  /// PR3.9 (SPRINT2_AUDIT §14): puts the message body on the system
  /// clipboard. Intentionally trims trailing whitespace — the bubble's
  /// rendered text already collapses inner whitespace runs, so paste
  /// targets get exactly what the user sees. Empty bodies (sticker / media
  /// only messages) silently no-op rather than nuke the clipboard.
  void _copyMessageText(MessageData m) {
    final body = m.text.trim();
    if (body.isEmpty) return;
    Clipboard.setData(ClipboardData(text: body));
  }

  /// PR3.9 (SPRINT2_AUDIT §14): writes a `secretly://msg/{id}` deeplink to
  /// the clipboard. The scheme handler is registered as part of the macOS
  /// tray / single-instance plumbing (Sprint 1) — pasting this URL into
  /// another Secretly window or the OS launcher jumps to that message.
  void _copyMessageLink(MessageData m) {
    if (m.id.isEmpty) return;
    Clipboard.setData(ClipboardData(text: 'secretly://msg/${m.id}'));
  }

  /// Routes a reaction pick from the bubble's hover bar to either:
  ///   • a direct emoji (e.g. "❤️", "👍") → fan out via `onReactToMessage`
  ///   • the "+ more" sentinel → open the new [ReactionsPopover] in
  ///     expanded mode anchored to the bubble. Replaces the legacy
  ///     `EmojiPopover.show` path so the user gets the same Telegram-style
  ///     in-place expandable grid they see for the right-click flow.
  Future<void> _onReactPicked(
    MessageData message,
    String emoji,
    GlobalKey bubbleAnchorKey,
  ) async {
    if (emoji != kReactionPickerSentinel) {
      widget.onReactToMessage?.call(message, emoji);
      return;
    }
    final picked = await ReactionsPopover.show(
      context,
      anchorKey: bubbleAnchorKey,
      side: ReactionsAnchorSide.above,
      startExpanded: true,
    );
    if (picked == null || picked.isEmpty) return;
    if (!mounted) return;
    widget.onReactToMessage?.call(message, picked);
  }
}

/// Compact Russian duration label for the disappearing-messages header chip.
String _formatDisappear(int s) {
  if (s < 60) return '$s с';
  if (s < 3600) return '${s ~/ 60} мин';
  if (s < 86400) return '${s ~/ 3600} ч';
  if (s < 604800) return '${s ~/ 86400} дн';
  return '${s ~/ 604800} нед';
}

/// Панель действий над выделенным — на месте шапки переписки.
///
/// Той же высоты, что шапка: лента под ней не прыгает, когда выделение
/// начинается и заканчивается.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onCancel,
    required this.onCopy,
    this.onForward,
    this.onSave,
    this.onDelete,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onCopy;
  final VoidCallback? onForward;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: DSpace.l),
      child: Row(
        children: [
          DesktopIconButton(
            icon: FluentIcons.dismiss_24_regular,
            tooltip: 'Отмена',
            size: 32,
            iconSize: 18,
            onPressed: onCancel,
          ),
          const SizedBox(width: DSpace.s),
          Expanded(
            child: Text(
              'Выбрано: $count',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DType.threadTitle.copyWith(
                color: c.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
          DesktopIconButton(
            icon: FluentIcons.copy_24_regular,
            tooltip: 'Копировать',
            size: 32,
            iconSize: 18,
            onPressed: onCopy,
          ),
          if (onForward != null)
            DesktopIconButton(
              icon: FluentIcons.share_24_regular,
              tooltip: 'Переслать',
              size: 32,
              iconSize: 18,
              onPressed: onForward,
            ),
          if (onSave != null)
            DesktopIconButton(
              icon: FluentIcons.bookmark_24_regular,
              tooltip: 'Сохранить',
              size: 32,
              iconSize: 18,
              onPressed: onSave,
            ),
          if (onDelete != null)
            DesktopIconButton(
              icon: FluentIcons.delete_24_regular,
              tooltip: 'Удалить',
              size: 32,
              iconSize: 18,
              color: c.danger,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

/// Строка переписки в режиме выделения: вся строка — одна кнопка, слева —
/// кружок-отметка, как в телеграме.
///
/// Пузырь под ней нажатий не получает (`AbsorbPointer`): иначе щелчок по
/// снимку открывал бы его вместо того, чтобы отметить, и над пузырём
/// всплывала бы строка действий.
///
/// 🔴 ВНЕ РЕЖИМА — ЗАЖАТИЕ НА ПУСТОМ МЕСТЕ СТРОКИ НАЧИНАЕТ ВЫДЕЛЕНИЕ
/// (указание владельца 16.09.2026). Как долгое нажатие на телефоне. Ловит его
/// подложка ПОД пузырём: сам пузырь нажатия получает как прежде — щелчок по
/// снимку открывает снимок, а выделение текста мышью не спорит с жестом.
class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.id,
    required this.enabled,
    required this.selected,
    required this.child,
  });

  final String id;

  /// Режим выделения включён. Выключен — строка ведёт себя как обычно.
  final bool enabled;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final on = enabled && selected;
    // Щелчки, удержание и протягивание ловит ОДИН жест на всю ленту
    // ([RowDragSelectRecognizer]); строка лишь метит себя, чтобы лента знала,
    // над каким сообщением мышь. Метка «сквозная»: она попадает в путь
    // нажатия и на пустом месте рядом с пузырём, ничего не перехватывая.
    return MetaData(
      metaData: DesktopMessageRowTag(id),
      behavior: HitTestBehavior.translucent,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: AnimatedContainer(
          duration: DMotion.fast,
          color: on
              ? c.accentPrimary.withValues(alpha: 0.10)
              : Colors.transparent,
          // Состав постоянный: пузырь первым, отметка — последней. Иначе
          // смена режима сдвигала бы пузырь в списке детей, и он строился бы
          // заново вместе со всем своим состоянием.
          child: Stack(
            children: [
              AbsorbPointer(absorbing: enabled, child: child),
              if (enabled)
                Positioned(
                  left: 4,
                  bottom: 8,
                  child: AnimatedContainer(
                    duration: DMotion.fast,
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? c.accentPrimary : Colors.transparent,
                      border: Border.all(
                        color: on ? c.accentPrimary : c.textTertiary,
                        width: 1.5,
                      ),
                    ),
                    child: on
                        ? const Icon(
                            FluentIcons.checkmark_12_filled,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.header,
    required this.isDirect,
    required this.onCall,
    required this.onVideoCall,
    required this.onToggleSearch,
    required this.onToggleDetails,
    required this.detailsOpen,
    required this.onHeaderMenu,
  });
  final ChatHeader header;

  /// Личная переписка или комната. Нужен ровно для формы портрета — остальное
  /// шапка берёт из [header].
  final bool isDirect;
  final VoidCallback? onCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onToggleSearch;
  final VoidCallback? onToggleDetails;
  final bool detailsOpen;
  final void Function(Offset globalPosition)? onHeaderMenu;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: DSpace.l),
      child: Row(
        children: [
          HoverListener(
            onTap: onToggleDetails,
            builder: (ctx, hovered, pressed) => Row(
              children: [
                Avatar(
                  name: header.name,
                  image: Avatar.fileImage(header.avatarPath),
                  frameId: header.frameId,
                  allowAnimatedFrame: true,
                  size: 36,
                  online: header.online,
                  // Шапка лежит на самом светлом углу холста переписки —
                  // вырез вокруг точки должен быть его цвета, а не цвета
                  // списка чатов слева.
                  ringColor: c.threadGlow,
                  verified: header.verified,
                  shape: isDirect ? AvatarShape.round : AvatarShape.room,
                ),
                const SizedBox(width: DSpace.m),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            header.name,
                            overflow: TextOverflow.ellipsis,
                            // Имя собеседника в макете 19/800: это главная
                            // надпись окна, и весом 600 она читалась как
                            // подпись строки списка.
                            style: DType.threadTitle.copyWith(
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        if (header.emojiStatus != null &&
                            header.emojiStatus!.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            header.emojiStatus!,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                        // Галочка = проверенный контакт (см. список чатов).
                        if (header.verified) ...[
                          const SizedBox(width: 4),
                          const DesktopVerifiedBadge(size: 14),
                        ],
                      ],
                    ),
                    if (header.status != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            header.status!,
                            style: DType.caption.copyWith(
                              color: header.online
                                  ? c.success
                                  : c.textSecondary,
                            ),
                          ),
                          // Описание комнаты за вертикальной чертой — как в
                          // макете. Ужимается ОНО, а не «3 участника»: счётчик
                          // короткий и терять его нельзя.
                          if ((header.description ?? '').trim().isNotEmpty) ...[
                            Container(
                              width: 1,
                              height: 11,
                              margin: const EdgeInsets.symmetric(
                                horizontal: DSpace.s,
                              ),
                              color: c.borderDivider,
                            ),
                            Flexible(
                              child: Text(
                                header.description!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DType.caption.copyWith(
                                  color: c.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          if ((header.disappearingSeconds ?? 0) > 0) ...[
            Tooltip(
              message: 'Исчезающие сообщения включены',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.elevated,
                  borderRadius: BorderRadius.circular(DRadii.pill),
                  border: Border.all(color: c.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      FluentIcons.timer_24_regular,
                      size: 13,
                      color: c.accentPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDisappear(header.disappearingSeconds!),
                      style: DType.caption.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: DSpace.s),
          ],
          if (header.muted)
            Padding(
              padding: const EdgeInsets.only(right: DSpace.s),
              child: Icon(
                FluentIcons.alert_off_24_regular,
                size: 16,
                color: c.textSecondary,
              ),
            ),
          // 🔴 Звонок — подписью, а не значком среди значков.
          //
          // Это главное действие шапки, и в ряду одинаковых кружков оно ничем
          // не выделялось: трубку приходилось ИСКАТЬ. Подпись называет
          // действие словом, а заливка отделяет его от служебных кнопок.
          //
          // В комнате слово другое: там не «позвонить кому-то», а войти в
          // общий созвон, и «Позвонить» обещало бы не то.
          if (onCall != null) ...[
            _CallButton(
              label: isDirect ? 'Позвонить' : 'Созвон',
              onTap: onCall!,
            ),
            const SizedBox(width: DSpace.xs),
          ],
          DesktopIconButton(
            icon: FluentIcons.video_24_regular,
            tooltip: 'Видеозвонок',
            onPressed: onVideoCall,
          ),
          // Разделитель отделяет разговор от работы с самим чатом: слева то,
          // что начинает связь, справа то, что управляет перепиской.
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: DSpace.s),
            color: c.borderSubtle,
          ),
          DesktopIconButton(
            icon: FluentIcons.search_24_regular,
            tooltip: 'Поиск в чате  Cmd F',
            onPressed: onToggleSearch,
          ),
          DesktopIconButton(
            icon: detailsOpen
                ? FluentIcons.panel_right_contract_24_regular
                : FluentIcons.panel_right_24_regular,
            tooltip: detailsOpen ? 'Скрыть детали' : 'Показать детали',
            onPressed: onToggleDetails,
          ),
          if (onHeaderMenu != null)
            Builder(
              builder: (btnCtx) => DesktopIconButton(
                icon: FluentIcons.more_horizontal_24_regular,
                tooltip: 'Ещё',
                onPressed: () {
                  final box = btnCtx.findRenderObject();
                  final at = box is RenderBox
                      ? box.localToGlobal(box.size.bottomLeft(Offset.zero))
                      : Offset.zero;
                  onHeaderMenu!(at);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Slim search bar that appears under the chat header when Cmd+F is pressed
/// or the toolbar search button is clicked.
/// Главное действие шапки: позвонить (личная переписка) или войти в созвон
/// (комната). Подписью, чтобы его не искали среди одинаковых значков.
class _CallButton extends StatelessWidget {
  const _CallButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      builder: (ctx, hovered, pressed) => AnimatedContainer(
        duration: DMotion.fast,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        // · ЗЕЛЁНАЯ ПЛЁНКА, А НЕ СПЛОШНАЯ ЗАЛИВКА (15.09.2026, решение
        // владельца по макету — оно ОТМЕНЯЕТ решение от 14.09).
        //
        // 14.09 кнопку залили сплошным зелёным с белой подписью: главное
        // действие шапки, видно боковым зрением. Сверка с исходником макета
        // показала плёнку в 14 % с зелёными значком и подписью — и владелец
        // подтвердил макет. Плёнка ставит кнопку в один ряд с остальными
        // значками шапки: звонок начинают осознанно, а не задев глазом.
        decoration: BoxDecoration(
          color: c.success.withValues(
            alpha: pressed ? 0.30 : (hovered ? 0.22 : 0.14),
          ),
          borderRadius: BorderRadius.circular(DRadii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.call_24_regular, size: 18, color: c.success),
            const SizedBox(width: 7),
            Text(
              label,
              style: DType.label.copyWith(
                fontSize: 12.5,
                // Подпись светлее самой плёнки: `success` на собственной
                // заливке в 14 % почти сливается с ней — та же причина, что у
                // `accentSoft` в полосе закреплённого.
                color: c.mintSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Обёртка, сообщающая ленте фактическую высоту поля ввода.
///
/// 🔴 Высота поля НЕ постоянна: карточка ответа, многострочный текст, полоса
/// записи голосового — каждая меняет её на десятки точек. Захардкоженный
/// отступ ленты означал бы либо дыру под последним сообщением, либо
/// сообщение, навсегда спрятанное под полем.
class _MeasuredComposer extends StatefulWidget {
  const _MeasuredComposer({required this.child, required this.onHeight});

  final Widget child;
  final ValueChanged<double> onHeight;

  @override
  State<_MeasuredComposer> createState() => _MeasuredComposerState();
}

class _MeasuredComposerState extends State<_MeasuredComposer> {
  final GlobalKey _key = GlobalKey();

  void _report() {
    final box = _key.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) widget.onHeight(box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

/// Плашка закреплённого сообщения под шапкой комнаты.
///
/// Нажатие — переход к самому сообщению (той же дорогой, что и по цитате
/// ответа), крестик — открепить. Крестика нет у того, кому закреплять нельзя:
/// кнопка, которая всегда отвечает отказом, — это не кнопка.
class _PinnedBar extends StatelessWidget {
  const _PinnedBar({required this.message, required this.onTap, this.onUnpin});

  final MessageData message;
  final VoidCallback onTap;
  final VoidCallback? onUnpin;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final preview = message.text.trim().isEmpty
        ? message.authorName
        : message.text.trim().replaceAll('\n', ' ');
    // · ЗАКРЕПЛЁННОЕ — ОСТРОВОК, А НЕ ПОЛОСА ВО ВСЮ ШИРИНУ (15.09.2026,
    // указание владельца).
    //
    // Сперва оно красилось `elevated` — тоном всплывающих карточек — и под
    // шапкой читалось как «ещё одна полоска интерфейса». Синяя плёнка это
    // поправила, но форма осталась полосой: закреплённое по-прежнему выглядело
    // частью оконной обвязки, а не сообщением, которое кто-то поднял НАД
    // разговором.
    //
    // Островок с полями и скруглением ставит его в один ряд с плашкой созвона
    // сверху: обе — «это лежит в комнате», обе одной формы и разного цвета по
    // смыслу (синий — закреплено, зелёный — говорят). Полосы во всю ширину
    // остались только у настоящей обвязки: шапки, полосы тем, поиска.
    return Padding(
      padding: const EdgeInsets.fromLTRB(DSpace.l, DSpace.m, DSpace.l, 0),
      child: Container(
      decoration: BoxDecoration(
        color: c.accentPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DRadii.lg),
        border: Border.all(color: c.accentPrimary.withValues(alpha: 0.24)),
      ),
      padding: const EdgeInsets.fromLTRB(DSpace.m, 6, DSpace.s, 6),
      child: Row(
        children: [
          Expanded(
            child: HoverListener(
              onTap: onTap,
              builder: (ctx, hovered, pressed) => Row(
                children: [
                  Container(
                    width: 3,
                    height: 26,
                    decoration: BoxDecoration(
                      color: c.accentPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: DSpace.s),
                  Icon(
                    FluentIcons.pin_24_filled,
                    size: 13,
                    color: c.accentSoft,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Закреплённое сообщение',
                          // Светлый акцент, а не сам акцент: на собственной
                          // заливке в 8 % он почти сливается с ней.
                          style: DType.tiny.copyWith(
                            fontSize: 11.5,
                            color: c.accentSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DType.caption.copyWith(
                            color: hovered ? c.textPrimary : c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 🔴 «1 ИЗ 2» И ПЕРЕКЛЮЧАТЕЛЬ ИЗ МАКЕТА НЕ РИСУЕМ: закреплённое
          // сообщение в комнате ОДНО. В настройках комнаты лежит одно поле
          // `pinned_message_event_id`, второго не бывает ни на телефоне, ни
          // на сервере — счётчик «1 из 2» и стрелка «следующее» обещали бы
          // список, которого нет.
          //
          // Вместо стрелки — «Открепить»: это настоящее действие, и оно есть
          // только у того, кому комната его позволяет.
          if (onUnpin != null)
            DesktopIconButton(
              icon: FluentIcons.dismiss_24_regular,
              tooltip: 'Открепить',
              onPressed: onUnpin,
            ),
        ],
      ),
      ),
    );
  }
}

class _SearchBanner extends StatelessWidget {
  const _SearchBanner({
    required this.controller,
    required this.focusNode,
    required this.matches,
    required this.current,
    required this.hasQuery,
    required this.onChanged,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int matches;
  final int current;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final String counter;
    if (!hasQuery) {
      counter = '';
    } else if (matches == 0) {
      counter = 'нет совпадений';
    } else {
      counter = '$current / $matches';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DSpace.l,
        vertical: DSpace.s,
      ),
      decoration: BoxDecoration(
        color: c.elevated,
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.search_24_regular, size: 18, color: c.textSecondary),
          const SizedBox(width: DSpace.s),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: (_) => onNext?.call(),
              textInputAction: TextInputAction.search,
              style: DType.body.copyWith(color: c.textPrimary),
              cursorColor: c.accentPrimary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Поиск в чате…',
                hintStyle: DType.body.copyWith(color: c.textSecondary),
              ),
            ),
          ),
          if (counter.isNotEmpty) ...[
            Text(
              counter,
              style: DType.caption.copyWith(
                color: matches == 0 && hasQuery
                    ? c.textSecondary
                    : c.textPrimary,
              ),
            ),
            const SizedBox(width: DSpace.s),
          ],
          DesktopIconButton(
            icon: FluentIcons.chevron_up_24_regular,
            tooltip: 'Предыдущее (Shift F3)',
            onPressed: onPrev,
          ),
          DesktopIconButton(
            icon: FluentIcons.chevron_down_24_regular,
            tooltip: 'Следующее (F3)',
            onPressed: onNext,
          ),
          DesktopIconButton(
            icon: FluentIcons.dismiss_24_regular,
            tooltip: 'Закрыть (Esc)',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// «Новые сообщения» line. Deliberately plainer than the day chip — it marks a
/// position, it does not label a section, so it should not compete with the
/// dates for attention.
class _UnreadSeparator extends StatelessWidget {
  const _UnreadSeparator({required this.palette, required this.count});

  final DColorSet palette;

  /// Сколько сообщений пришло, пока чат был закрыт.
  ///
  /// 🔴 ЧИСЛО ОБЯЗАТЕЛЬНО. Черта говорила «Новые сообщения» — и человек, увидев
  /// её, не знал, нужно ли прокручивать. Само число тут же рядом: им эта черта
  /// и позиционируется в ленте. Написать «три» вместо «есть» стоит одной
  /// строки и отвечает на вопрос, ради которого черту и ищут.
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = palette;
    // 🔴 Красная, а не синяя: в макете владельца эта черта того же цвета, что
    // счётчики непрочитанного, и по делу — она про то же самое. Синим она
    // сливалась с выделением строки и с акцентом кнопок.
    //
    // С 15.09 счётчик в строке списка стал ГОЛУБЫМ (тип разговора), и красный
    // остался сигналом «тут тебя ждут» — фильтрам, плиткам разделов и этой
    // черте. Поэтому она берёт `unreadRail`, а не `unreadDot`: иначе
    // покраснение ушло бы вместе с ним.
    final line = c.unreadRail;
    // Линии ЗАТУХАЮТ к краям, как в макете: ровная черта через всю ленту
    // режет переписку пополам, а затухающая только отмечает место.
    Widget fade({required bool toCenter}) => Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: toCenter ? Alignment.centerLeft : Alignment.centerRight,
                end: toCenter ? Alignment.centerRight : Alignment.centerLeft,
                colors: [
                  line.withValues(alpha: 0),
                  line.withValues(alpha: 0.45),
                ],
              ),
            ),
            child: const SizedBox(height: 1),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DSpace.l,
        vertical: DSpace.s,
      ),
      child: Row(
        children: [
          fade(toCenter: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DSpace.s),
            child: Text(
              unreadSeparatorLabelRu(count),
              style: DType.caption.copyWith(
                color: line,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          fade(toCenter: false),
        ],
      ),
    );
  }
}

/// «3 непрочитанных» с русским склонением.
///
/// Ноль и отрицательное — «Новые сообщения»: черта всё равно нарисована (её
/// поставили по месту последнего прочитанного), а врать числом нельзя.
String unreadSeparatorLabelRu(int count) {
  if (count <= 0) return 'Новые сообщения';
  final tens = count % 100;
  final ones = count % 10;
  if (tens >= 11 && tens <= 14) return '$count непрочитанных';
  if (ones == 1) return '$count непрочитанное';
  if (ones >= 2 && ones <= 4) return '$count непрочитанных';
  return '$count непрочитанных';
}

/// E9: centered day-separator chip ("Сегодня" / "Вчера" / "30 июня" /
/// "30 июня 2025") shown above the first message of each calendar day.
class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.timestampMs, required this.palette});

  final int timestampMs;
  final DColorSet palette;

  static const List<String> _monthsGenitive = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  String _label() {
    final d = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    final month = _monthsGenitive[d.month - 1];
    return d.year == now.year ? '${d.day} $month' : '${d.day} $month ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DSpace.s),
      child: Center(
        child: Container(
          // · Чип БЕЗ рамки на белом в 5 % (макет). Рамка поверх заливки
          // делала из даты кнопку: в ленте, где ничего больше не обведено,
          // обводка читается как «сюда можно нажать».
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(DRadii.r9),
          ),
          child: Text(
            _label(),
            style: DType.caption.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// E9 drafts: in-memory, per-conversation composer text that survives switching
/// chats within a session (the thread host is recreated per convoId, so the
/// draft can't live in widget state). Not persisted across app restarts — a
/// later slice can back this with the controller / SharedPreferences.
class DesktopDraftStore {
  DesktopDraftStore._();

  static const String _prefsKey = 'desktop_drafts_v1';

  /// Ключ в зашифрованной базе — тот же, что был в настройках.
  static const String storageKey = _prefsKey;

  /// 🔴 ЧЕРНОВИК — ЭТО НЕОТПРАВЛЕННОЕ СООБЩЕНИЕ (17.09.2026). Он лежал в
  /// настройках приложения ОТКРЫТЫМ ТЕКСТОМ, хотя сама переписка — в
  /// зашифрованной базе. Теперь хранилище подключает оболочка окна: читает и
  /// пишет через контроллер, то есть в ту же базу. Открытая копия в настройках
  /// стирается при первом запуске с этой правкой.
  static Future<void> Function(String json)? _writeStore;

  /// Подключает зашифрованное хранилище и переносит в него старые черновики.
  static Future<void> attachStorage({
    required Future<String?> Function() read,
    required Future<void> Function(String json) write,
  }) async {
    _writeStore = write;
    Map<String, String> fromStore = const <String, String>{};
    try {
      final raw = await read();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          fromStore = decoded.map((k, v) => MapEntry('$k', '$v'));
        }
      }
    } catch (_) {
      // Нечитаемое хранилище не должно стоить человеку черновиков.
    }
    if (fromStore.isNotEmpty) {
      _byConvo
        ..clear()
        ..addAll(fromStore);
      revision.value++;
    } else if (_byConvo.isNotEmpty) {
      // Перенос: `load()` прочитал старую открытую копию — сохраняем её уже
      // в базу.
      try {
        await write(jsonEncode(_byConvo));
      } catch (_) {}
    }
    // Открытая копия больше не нужна ни в каком случае.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  /// Только для тестов: отключить хранилище.
  @visibleForTesting
  static void detachStorageForTesting() {
    _writeStore = null;
    _byConvo.clear();
  }

  static final Map<String, String> _byConvo = <String, String>{};
  static Timer? _saveDebounce;

  /// Bumped whenever the set of chats WITH a draft changes, so the chat list
  /// can show its pencil without polling — and, once typing pauses, when the
  /// TEXT changes: the row shows it after «Черновик:». Never per keystroke:
  /// the list is not repainted while the person is still typing.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Текст черновика менялся, а список об этом ещё не знает.
  static bool _textChanged = false;

  /// Loads persisted drafts. Drafts used to live only in memory, so a
  /// half-written message was lost the moment the app closed — the one moment
  /// a draft is most worth keeping.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _byConvo
        ..clear()
        ..addAll(decoded.map((k, v) => MapEntry('$k', '$v')));
      revision.value++;
    } catch (_) {
      // A corrupt or unreadable store must not block the app; the user simply
      // starts with no drafts.
    }
  }

  static String? get(String convoId) {
    final d = _byConvo[convoId];
    return (d == null || d.isEmpty) ? null : d;
  }

  static bool has(String convoId) =>
      (_byConvo[convoId] ?? '').trim().isNotEmpty;

  static void set(String convoId, String text) {
    final hadDraft = has(convoId);
    final t = text.trim();
    if (t.isEmpty) {
      _byConvo.remove(convoId);
    } else {
      // Store the raw (untrimmed) text so the caret/whitespace is preserved.
      _byConvo[convoId] = text;
    }
    if (hadDraft != has(convoId)) {
      revision.value++;
    } else if (hadDraft) {
      _textChanged = true;
    }
    _persistSoon();
  }

  static void clear(String convoId) {
    final hadDraft = has(convoId);
    _byConvo.remove(convoId);
    if (hadDraft) revision.value++;
    _persistSoon();
  }

  /// Debounced: typing writes once when it settles, not once per keystroke.
  static void _persistSoon() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () async {
      // Набор затих — строка списка получает свежий текст черновика.
      if (_textChanged) {
        _textChanged = false;
        revision.value++;
      }
      final write = _writeStore;
      if (write == null) {
        // База ещё не подключена (самое начало запуска). В настройки черновик
        // больше не пишем: он останется в памяти до подключения.
        return;
      }
      try {
        await write(_byConvo.isEmpty ? '' : jsonEncode(_byConvo));
      } catch (_) {}
    });
  }
}

/// · «Игорь печатает» — плашкой в самой ленте (макет).
///
/// Подпись в шапке видна лишь тому, кто туда смотрит, а смотрят в НИЗ ленты —
/// туда, где сообщение вот-вот появится. Поэтому плашка стоит там же, где
/// встанет само сообщение: слева, с отступом под портрет.
///
/// 🔴 ТОЧКИ ДЫШАТ ТОЛЬКО ПОКА ОКНО ВПЕРЕДИ. Бесконечная анимация в ленте —
/// это перерисовка кадр за кадром у окна, на которое никто не смотрит; по той
/// же причине останавливаются украшения профиля.
class _TypingPill extends StatefulWidget {
  const _TypingPill({required this.label});

  final String label;

  @override
  State<_TypingPill> createState() => _TypingPillState();
}

class _TypingPillState extends State<_TypingPill>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncRunning();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncRunning();

  void _syncRunning() {
    final visible =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed ||
        WidgetsBinding.instance.lifecycleState == null;
    if (visible) {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Padding(
      // 42 слева — ровно под портретом чужого сообщения: плашка встаёт в тот
      // же столбик, что и текст, который она обещает.
      padding: const EdgeInsets.fromLTRB(42, 2, DSpace.xl, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(DRadii.lg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _ctrl,
                builder: (ctx, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 3),
                      _Dot(opacity: _dotOpacity(i)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: DType.caption.copyWith(
                  fontSize: 11.5,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Волна по трём точкам: у каждой своя фаза, значения — из макета
  /// (1 · .6 · .3), между ними плавный переход.
  double _dotOpacity(int i) {
    final t = (_ctrl.value - i * 0.18) % 1.0;
    // Треугольник 1 → .3 → 1, чтобы волна шла и обратно, а не прыгала.
    final wave = t < 0.5 ? 1 - t * 2 : (t - 0.5) * 2;
    return 0.3 + 0.7 * wave;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: c.textSecondary.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}
