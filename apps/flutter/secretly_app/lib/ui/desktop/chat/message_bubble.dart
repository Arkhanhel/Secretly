// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../app/app_controller.dart' show SharedAudioPlaybackState;
import '../../../calls/call_event.dart';
import '../../../stickers/sticker_catalog.dart' show SecretlyStickerDescriptor;
import '../../widgets/secretly_sticker_widgets.dart'
    show SecretlyStickerAssetView;
import '../app/desktop_file_match.dart' show formatAttachmentSize;
import '../design/tokens.dart';
import 'desktop_event_tally.dart';
import 'desktop_poll_tally.dart';
import 'event_card.dart';
import 'poll_card.dart';
import '../../widgets/avatar_initials.dart';
import '../primitives/avatar.dart';
import '../services/desktop_ui_prefs.dart';
import '../primitives/desktop_tooltip.dart';
import '../primitives/hover_listener.dart';
import 'link_preview_card.dart';
import 'media_albums.dart';
import 'media_group_layout.dart' show mediaGroupSize;
import 'message_media.dart';
import 'message_selection.dart';
import '../../../models/e2e_payload_v1.dart';
import 'message_rich_text.dart';
import 'noto_emoji_lottie.dart';
import 'screen_gradient.dart';

enum DeliveryStatus { sending, scheduled, sent, delivered, read, failed }

/// How wide a bubble is allowed to get, as a fraction of the thread pane and
/// as a hard cap.
///
/// These were 0.92 and 720, which is a phone habit applied to a desktop pane:
/// on a wide window a sentence stretched into one 700px line, and the eye has
/// to travel the full width to find the start of the next one. Every desktop
/// messenger keeps the measure short — Telegram's bubbles hug their content and
/// long text wraps well before the pane edge. The fraction does the work on
/// normal windows; the cap stops a maximised window from undoing it.
const double kBubbleWidthFactor = 0.72;

/// · ШИРИНА ПУЗЫРЯ РАЗНАЯ ПО СТОРОНАМ (макет): свой до 600, чужой до 660.
///
/// Было одно число 560 на оба. Чужой пузырь при этом обрезался раньше своего,
/// хотя у него слева ещё стоит портрет — то есть места ему остаётся МЕНЬШЕ, а
/// не больше. Длинное чужое сообщение ломалось на лишние строки там, где своё
/// того же размера умещалось.
const double kBubbleMaxWidthSelf = 600.0;
const double kBubbleMaxWidthPeer = 660.0;

/// U-14: one RED tick means "never reached the relay" — the user-specified
/// signal for a message that permanently failed to send. Same value the mobile
/// timeline uses, so a message looks identical on both surfaces.
const Color kDesktopUnsentTickColor = Color(0xFFE53935);

/// Single source of truth for the delivery tick glyph.
///
/// Top-level on purpose: the bubble and the media "meta pill" are separate
/// widgets, and when each owned its own copy they drifted — the pill rendered a
/// blue second tick and a pink error circle while the bubble did something
/// else. Both now call this.
/// Яркость галочки «отправлено» относительно «доставлено» — как у телефона.
const double kDesktopSentTickAlpha = 0.55;

Widget deliveryTickGlyph(DeliveryStatus s, Color col) {
  switch (s) {
    case DeliveryStatus.sending:
      return Icon(FluentIcons.clock_24_regular, size: 12, color: col);
    case DeliveryStatus.scheduled:
      return Icon(FluentIcons.calendar_clock_24_regular, size: 12, color: col);
    case DeliveryStatus.sent:
      // 🔴 Три ступени, как на телефоне (`chatDeliveryTickStyle`, 17.09.2026):
      // «отправлено» — одна ПРИГЛУШЁННАЯ галочка, «доставлено» — одна яркая,
      // «прочитано» — две яркие. Раньше «ушло на сервер» и «дошло до
      // человека» здесь выглядели одинаково. 0,55 — та же ступень, что у
      // телефона; от цвета, а не абсолютом: мета-строка бывает полупрозрачной.
      return Icon(
        FluentIcons.checkmark_24_regular,
        size: 12,
        color: col.withValues(alpha: col.a * kDesktopSentTickAlpha),
      );
    case DeliveryStatus.delivered:
      return Icon(FluentIcons.checkmark_24_regular, size: 12, color: col);
    case DeliveryStatus.read:
      return SizedBox(
        width: 20,
        height: 12,
        child: Stack(children: [
          Icon(FluentIcons.checkmark_24_regular, size: 12, color: col),
          Padding(
            padding: const EdgeInsets.only(left: 5),
            // Same colour as the first tick — the COUNT carries the meaning.
            child: Icon(FluentIcons.checkmark_24_regular, size: 12, color: col),
          ),
        ]),
      );
    case DeliveryStatus.failed:
      return const Icon(FluentIcons.checkmark_24_regular,
          size: 12, color: kDesktopUnsentTickColor);
  }
}

class ReplyPreview {
  const ReplyPreview({
    required this.authorName,
    required this.text,
    this.isImage = false,
    this.targetPayloadId,
    this.authorSeed = '',
  });
  final String authorName;

  /// Ключ цвета автора цитаты — устройство, с которого пришло цитируемое
  /// сообщение. ТОТ ЖЕ ключ, по которому красит телефон (`authorSeed` у
  /// `_ReplyQuoteStrip`), иначе один и тот же человек в одной и той же цитате
  /// был бы на двух устройствах разного цвета.
  final String authorSeed;

  final String text;
  final bool isImage;

  /// Logical payload-event id of the quoted message, so tapping the quote can
  /// jump to the original. Null when the target isn't resolvable.
  final String? targetPayloadId;
}

/// Кто поставил реакцию — столько, сколько нужно полоске портретов.
///
/// 🔴 Без этого фишка отвечала только «сколько», а на телефоне она отвечает и
/// «кто»: до трёх портретов прямо в фишке. Сводка `(эмодзи, число, моя ли)`
/// эти имена теряла ещё в разделе чатов, и восстановить их в пузыре было не из
/// чего.
class ReactionActor {
  const ReactionActor({
    required this.profileId,
    this.name,
    this.avatarPath,
  });

  final String profileId;
  final String? name;
  final String? avatarPath;
}

class MessageReaction {
  const MessageReaction({
    required this.emoji,
    required this.count,
    this.byMe = false,
    this.actors = const <ReactionActor>[],
  });
  final String emoji;
  final int count;
  final bool byMe;

  /// По порядку появления: первый поставивший — первый в полоске.
  final List<ReactionActor> actors;
}

/// Sprint 2 PR8 (2026-05-19): the bubble previously knew only how to render
/// plain text — every attachment ended up as `📷 Фото` / `🎵 Аудио` /
/// `📎 Файл` placeholder text generated by [_attachmentLabel]. To render
/// real photos, voice notes and files we now carry the decoded
/// [AttachmentEventV1] alongside the message in a thin view-model
/// ([MessageAttachment]) — the bubble dispatches on [kind] and the
/// caller (`desktop_chats_section`) populates [filePath] once the
/// blob has been decrypted to disk via [AppController.ensureCachedAttachmentFile].
enum MessageAttachmentKind { image, voice, audio, video, file }

class MessageAttachment {
  const MessageAttachment({
    required this.kind,
    required this.blobId,
    required this.payloadEventId,
    this.filePath,
    this.mime,
    this.fileName,
    this.sizeBytes = 0,
    this.durationMs,
    this.waveform,
    this.loading = false,
    this.failed = false,
    this.width,
    this.height,
    this.thumbnail,
    this.sentAsFile = false,
    this.videoNote = false,
    this.musicTitle,
    this.musicArtist,
    this.downloadProgress,
    this.uploadProgress,
  });

  final MessageAttachmentKind kind;
  final String blobId;

  /// The original payload event id (used as the stable track id for the
  /// shared audio player so all bubbles referring to the same voice note
  /// share play state).
  final String payloadEventId;

  /// Decrypted file on local disk. Null until [AppController.ensureCachedAttachmentFile]
  /// resolves — the bubble shows a placeholder spinner / icon in the meantime.
  final String? filePath;
  final String? mime;
  final String? fileName;
  final int sizeBytes;

  /// For voice/audio attachments, set when the embedded payload carried a
  /// duration hint. The player still re-detects this on load.
  final int? durationMs;

  /// Огибающая громкости голосового — то, из чего рисуются столбики.
  ///
  /// 🔴 Данные были В ПРОТОКОЛЕ и не доходили до окна. Телефон рисует по ним
  /// волну с первого дня (`payload.waveform`), а десктоп показывал ровную
  /// полоску: одно и то же сообщение выглядело на двух устройствах по-разному
  /// не потому, что так решили, а потому, что поле не прокинули.
  ///
  /// Значения 0..100. `null` или пусто — рисуем ровный узор: волна без данных
  /// была бы выдумкой.
  final List<int>? waveform;

  /// True while we're fetching the blob in the background. Shows a spinner
  /// in the bubble.
  final bool loading;

  /// True if decryption / download failed. Bubble shows a retry hint.
  final bool failed;

  /// Размеры снимка в пикселях — от ОТПРАВИТЕЛЯ. По ним место под снимок
  /// занимается сразу, до загрузки: лента не прыгает, когда картинка
  /// приходит.
  final int? width;
  final int? height;

  /// Крошечная миниатюра от отправителя (`thumb_b64`, до 32 точек) — её
  /// размытую версию видно, пока сам снимок не скачан.
  final Uint8List? thumbnail;

  /// Отправлено ФАЙЛОМ (у вложения есть имя): рисуется строкой документа,
  /// а не картинкой, и в альбом с фото не склеивается. Так же решает
  /// телефон (`_attachmentRendersAsPhoto`).
  final bool sentAsFile;

  /// Видеосообщение-«кружок».
  final bool videoNote;

  final String? musicTitle;
  final String? musicArtist;

  /// Доля скачанного файла (0..1), пока его качают по нажатию. `null` — не
  /// качается.
  final double? downloadProgress;

  /// Доля ОТПРАВЛЕННОГО (0..1), пока вложение уходит с этого компьютера.
  /// `null` — это уже настоящее сообщение, а не заготовка отправки.
  final double? uploadProgress;

  /// Размер снимка для раскладки: от отправителя, а если его нет — квадрат.
  Size get mediaSize => (width != null && height != null && width! > 0 && height! > 0)
      ? Size(width!.toDouble(), height!.toDouble())
      : const Size(1, 1);

  /// 🔴 КОПИЯ НЕСЁТ ВСЕ ПОЛЯ. Здесь терялась волна голосового: после
  /// фоновой догрузки файла столбики пропадали.
  MessageAttachment copyWith({
    String? filePath,
    bool? loading,
    bool? failed,
    int? durationMs,
    double? downloadProgress,
    bool clearDownloadProgress = false,
    String? musicTitle,
    String? musicArtist,
  }) {
    return MessageAttachment(
      kind: kind,
      blobId: blobId,
      payloadEventId: payloadEventId,
      filePath: filePath ?? this.filePath,
      mime: mime,
      fileName: fileName,
      sizeBytes: sizeBytes,
      durationMs: durationMs ?? this.durationMs,
      waveform: waveform,
      loading: loading ?? this.loading,
      failed: failed ?? this.failed,
      width: width,
      height: height,
      thumbnail: thumbnail,
      sentAsFile: sentAsFile,
      videoNote: videoNote,
      musicTitle: musicTitle ?? this.musicTitle,
      musicArtist: musicArtist ?? this.musicArtist,
      downloadProgress: clearDownloadProgress
          ? null
          : (downloadProgress ?? this.downloadProgress),
      uploadProgress: uploadProgress,
    );
  }
}

class MessageData {
  const MessageData({
    required this.id,
    this.payloadId,
    required this.authorName,
    this.authorRole,
    this.authorProfileId,
    this.authorSeed,
    required this.text,
    required this.time,
    this.isSelf = false,
    this.delivery = DeliveryStatus.delivered,
    this.reply,
    this.reactions = const <MessageReaction>[],
    this.edited = false,
    this.continuation = false,
    this.hasMention = false,
    this.attachment,
    this.callEvent,
    this.poll,
    this.eventCard,
    this.isSystemEvent = false,
    this.mentions = const <MsgMentionV1>[],
    this.timestampMs = 0,
    this.isRu = true,
    this.isTextMessage = false,
    this.senderAvatarPath,
    this.forwardedFrom,
    this.sticker,
    this.linkPreview,
    this.ownLinkPreviewTarget,
    this.mediaGroupId,
    this.albumItems,
  });

  final String id;

  /// Logical payload-event id (the id the *peer* knows the message by), used
  /// to target reply / edit / delete-for-everyone. Resolves to
  /// `event.payloadEventId ?? event.eventId`. The wrapper [id] (local DB row
  /// event id) is what delete-for-me removes locally; [payloadId] is what the
  /// reply/edit/delete-for-all control commands reference so both devices
  /// agree on the same message. Null only for demo/synthetic rows.
  final String? payloadId;
  final String authorName;
  /// Роль автора в комнате: `owner`, `admin`, `moderator`, `member`,
  /// `restricted`, `guest`. `null` — роль неизвестна или это личная переписка.
  ///
  /// 🔴 Имя автора красилось ПО ХЕШУ ИМЕНИ — то есть случайным, но устойчивым
  /// цветом. В личной переписке это верно (цвет только различает людей), а в
  /// комнате цвет мог бы говорить больше: кто здесь владелец, а кто гость. В
  /// макете имена окрашены именно по роли.
  ///
  /// Когда роль неизвестна, цвет остаётся прежним — по хешу: иначе в личных
  /// чатах и в комнатах без загруженного состава имена потеряли бы
  /// различимость разом.
  final String? authorRole;

  /// Профиль автора. По нему считается ОТТЕНОК заглушки портрета — тот же
  /// ключ, что у телефона; по имени было бы иначе, и переименование меняло бы
  /// цвет только на компьютере.
  final String? authorProfileId;

  /// Ключ цвета имени автора — устройство отправителя.
  ///
  /// 🔴 ИМЕННО УСТРОЙСТВО, А НЕ ПРОФИЛЬ И НЕ ИМЯ, — потому что так красит
  /// телефон (`groupAuthorSeed: entry.event.senderDeviceId`). Считать по
  /// другому ключу значило бы, что Игорь на телефоне зелёный, а на компьютере
  /// сиреневый, — и узнавать людей по цвету пришлось бы заново на каждом
  /// устройстве.
  final String? authorSeed;
  final String text;
  final String time;
  final bool isSelf;
  final DeliveryStatus delivery;
  final ReplyPreview? reply;
  final List<MessageReaction> reactions;
  final bool edited;

  /// When true: same author as previous within 60s — skip avatar/name, tight gap.
  final bool continuation;
  final bool hasMention;

  /// Разметка упоминаний из payload: смещения и, у поимённых, профиль.
  ///
  /// 🔴 Признак `hasMention` красил ФОН пузыря, а сами фишки не рисовались:
  /// «@Игорь» на компьютере выглядел обычным словом. Список нужен, чтобы
  /// нарисовать их так же, как телефон.
  final List<MsgMentionV1> mentions;

  /// PR8 (SPRINT2_AUDIT §20): when non-null this message carries a media
  /// attachment that the bubble renders as an image / voice / file widget
  /// instead of the plain `Text(text)` body. [text] is then treated as an
  /// optional caption — empty in the common case where the user just
  /// shared a photo without typing anything.
  final MessageAttachment? attachment;

  /// 2026-05-20 PR-A: when non-null this message is a finished call record.
  /// The bubble renders a Telegram/Signal-style call card (direction icon +
  /// «Исходящий звонок · 0:32» / «Пропущенный» / «Отклонённый» etc) instead
  /// of a regular text bubble. Mirrors mobile's `_CallEventBubble` look.
  final CallEventV1? callEvent;

  /// Опрос: вопрос, варианты и уже подсчитанные голоса.
  ///
  /// Считает лента (`desktopTallyPolls`) — сам опрос, голоса и закрытие лежат
  /// в переписке отдельными сообщениями. Раньше компьютер показывал вместо
  /// карточки строку «📊 Опрос: …», и проголосовать было нечем.
  final DesktopPollView? poll;

  /// Событие с ответами «иду / возможно / не иду».
  ///
  /// Как и опрос, считается по ленте: приглашение и ответы — обычные
  /// сообщения. Раньше компьютер показывал строку «📅 Название».
  final DesktopEventView? eventCard;

  /// Служебное сообщение комнаты (вошёл, вышел, сменили название и т. п.).
  ///
  /// Такое сообщение рисуется плашкой по центру, как разделитель даты: у него
  /// нет автора, стороны, галочек и реакций. Текст уже собран общей с
  /// телефоном функцией `formatSystemEventText`. Раньше компьютер эти события
  /// просто выбрасывал, и комната молчала о себе.
  final bool isSystemEvent;

  /// Raw wall-clock timestamp of the bubble's underlying event in ms. Used
  /// by [callEvent] rendering to compose the meta line (time + duration).
  /// Defaults to 0; regular text bubbles continue to read [time].
  final int timestampMs;

  /// Locale flag for the few labels the bubble formats locally (e.g. call
  /// duration "5 мин." vs "5m"). Mirrors mobile's `chatLocaleIsRussian`.
  final bool isRu;

  /// True only for a real text message (MsgEventV1). Attachments, stickers and
  /// call cards are false. Gates the «Редактировать» action — mobile refuses to
  /// edit non-text payloads (`payload is! MsgEventV1`).
  final bool isTextMessage;

  /// Local file path of the message author's avatar photo, used for the
  /// group-thread sender avatar slot (and self). Null → initials fallback.
  final String? senderAvatarPath;

  /// When non-null, this message was forwarded; the bubble shows a
  /// «↪ Переслано от X» header above the body. Mirrors mobile's forward chrome.
  final String? forwardedFrom;

  /// When non-null, this message is a sticker; the bubble renders the resolved
  /// artwork (catalog or user blob) borderless instead of a text/attachment
  /// body. Resolved by the host (resolveEvent + ensureUserStickerCached).
  final SecretlyStickerDescriptor? sticker;

  /// Карточка ссылки, которую приготовил ОТПРАВИТЕЛЬ, — уже сверенная с
  /// текстом (`acceptIncomingLinkPreview`). За ней никто не ходит в сеть.
  final LinkPreviewV1? linkPreview;

  /// Своё сообщение со ссылкой, но без карточки (написано до того, как
  /// карточки стали ездить в сообщении): её можно загрузить самим — свою
  /// ссылку человек выбрал сам. У чужих сообщений всегда `null`.
  final Uri? ownLinkPreviewTarget;

  /// Номер группы вложений, отправленных вместе (`media_group_id`).
  final String? mediaGroupId;

  /// Альбом: сообщения, отправленные вместе и показанные одной строкой —
  /// сеткой снимков или стопкой файлов. У строки альбома это поле непусто, а
  /// сама она описывает ПЕРВОЕ сообщение группы (время, ответ, реакции,
  /// подпись). Действия над строкой — пересылка, удаление, выделение —
  /// относятся ко всем её сообщениям.
  final List<MessageData>? albumItems;

  /// Все сообщения строки: у альбома — его снимки, у обычной — она сама.
  List<MessageData> get expanded => albumItems ?? <MessageData>[this];

  /// Заготовка отправки: вложение ещё уходит с этого компьютера. У такой
  /// строки нет ни меню, ни реакций, ни ответа — отвечать пока не на что.
  bool get isUploading =>
      expanded.any((m) => m.attachment?.uploadProgress != null);

  /// Returns a copy with selected fields overridden. Used by the host's
  /// in-place row patches (attachment rehydrate, reaction add/rollback) so
  /// identity fields ([payloadId], [timestampMs], [callEvent], [isRu],
  /// [isTextMessage]) are never silently dropped during a field-by-field
  /// rebuild.
  ///
  /// 🔴 КОПИЯ ОБЯЗАНА НЕСТИ ВСЕ ПОЛЯ, А НЕ ТЕ, ЧТО БЫЛИ, КОГДА ЕЁ ПИСАЛИ.
  ///
  /// Найдено 16.09.2026: здесь не было `authorRole`, `authorProfileId` и
  /// `mentions`. А зовётся копия на КАЖДОМ втором сообщении подряд от одного
  /// автора (`m.copyWith(continuation: true)` в ленте), при каждой
  /// поставленной реакции и когда догружается вложение. То есть у всех этих
  /// сообщений молча пропадали фишки упоминаний («@Игорь» становился обычным
  /// словом), метка роли и оттенок заглушки портрета — и возвращались только
  /// после перезагрузки ленты.
  ///
  /// Добавляя поле в класс, добавь его и сюда: `desktop_message_copy_test`
  /// сверяет оба списка и упадёт, если они разойдутся.
  MessageData copyWith({
    String? id,
    String? payloadId,
    String? authorName,
    String? authorRole,
    String? authorProfileId,
    String? authorSeed,
    String? text,
    String? time,
    bool? isSelf,
    DeliveryStatus? delivery,
    ReplyPreview? reply,
    List<MessageReaction>? reactions,
    bool? edited,
    bool? continuation,
    bool? hasMention,
    List<MsgMentionV1>? mentions,
    MessageAttachment? attachment,
    CallEventV1? callEvent,
    DesktopPollView? poll,
    DesktopEventView? eventCard,
    bool? isSystemEvent,
    int? timestampMs,
    bool? isRu,
    bool? isTextMessage,
    String? senderAvatarPath,
    String? forwardedFrom,
    SecretlyStickerDescriptor? sticker,
    LinkPreviewV1? linkPreview,
    Uri? ownLinkPreviewTarget,
    String? mediaGroupId,
    List<MessageData>? albumItems,
  }) {
    return MessageData(
      id: id ?? this.id,
      payloadId: payloadId ?? this.payloadId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      authorProfileId: authorProfileId ?? this.authorProfileId,
      authorSeed: authorSeed ?? this.authorSeed,
      text: text ?? this.text,
      time: time ?? this.time,
      isSelf: isSelf ?? this.isSelf,
      delivery: delivery ?? this.delivery,
      reply: reply ?? this.reply,
      reactions: reactions ?? this.reactions,
      edited: edited ?? this.edited,
      continuation: continuation ?? this.continuation,
      hasMention: hasMention ?? this.hasMention,
      mentions: mentions ?? this.mentions,
      attachment: attachment ?? this.attachment,
      callEvent: callEvent ?? this.callEvent,
      poll: poll ?? this.poll,
      eventCard: eventCard ?? this.eventCard,
      isSystemEvent: isSystemEvent ?? this.isSystemEvent,
      timestampMs: timestampMs ?? this.timestampMs,
      isRu: isRu ?? this.isRu,
      isTextMessage: isTextMessage ?? this.isTextMessage,
      senderAvatarPath: senderAvatarPath ?? this.senderAvatarPath,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
      sticker: sticker ?? this.sticker,
      linkPreview: linkPreview ?? this.linkPreview,
      ownLinkPreviewTarget: ownLinkPreviewTarget ?? this.ownLinkPreviewTarget,
      mediaGroupId: mediaGroupId ?? this.mediaGroupId,
      albumItems: albumItems ?? this.albumItems,
    );
  }
}

/// Sentinel value `MessageBubble.onReact` passes when the user clicks the
/// "+ more emoji" button — the host (`ChatThreadPanel._onReactPicked`) is
/// responsible for opening the full picker. Anything else is an actual
/// emoji to fan out.
const String kReactionPickerSentinel = '+';

/// Telegram-style bubble. Tail-corner on sender side, max-width 62% capped at 720pt.
/// Group stacking: when continuation==true, avatar+name omitted and outer gap collapses.
///
/// Sprint 2 PR3.7 (2026-05-19, SPRINT2_AUDIT §12):
///   • Hover bar no longer disappears the moment the cursor crosses the
///     bubble's top edge — both the bubble and the bar share a hover-state
///     register, so moving onto the bar to click an emoji keeps it visible.
///   • New reactions pop in with a Curves.easeOutBack scale tween (mobile
///     parity for the "react animation").
///   • Solo Noto-animatable emoji messages render bubble-free at 144 px via
///     [NotoEmojiLottie] — tap replays the animation.
///   • Quick-react click burst: the chosen emoji briefly scales 2.4× and
///     fades while the popover closes, so the user feels the reaction land.
class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onReply,
    this.onReplyTap,
    this.onReact,
    this.onMoreActions,
    this.onContinueInTopic,
    this.selfProfileId = '',
    this.canReceiveAdminMentions = false,
    this.onProfileMentionTap,
    this.onSetVoiceSpeed,
    this.onAvatarTap,
    this.onReactionTap,
    this.onOpenImage,
    this.onSaveAttachment,
    this.onOpenVideo,
    this.onOpenFile,
    this.onToggleVoice,
    this.onSeekVoice,
    this.onPollVote,
    this.onPollClose,
    this.onEventRsvp,
    this.sharedAudio,
    this.showPeerIdentity = true,
    this.showAvatar = true,
    this.translatedText,
    this.translating = false,
    this.onTextSelectionChanged,
    this.onDownloadAttachment,
    this.onRevealAttachment,
    this.onCancelUpload,
  });

  /// Скачать вложение по нажатию («Загрузить») или повторить неудавшуюся
  /// загрузку.
  final ValueChanged<MessageData>? onDownloadAttachment;

  /// Отменить отправку заготовки (кольцо с крестиком).
  final ValueChanged<MessageData>? onCancelUpload;

  /// «Показать в Finder»: положить копию файла в «Загрузки» и показать её.
  final ValueChanged<MessageData>? onRevealAttachment;

  /// Выделенный мышью текст сообщения (или перевода, или подписи к медиа).
  /// Пустая строка — выделения больше нет. Лента кладёт его в пункт меню
  /// «Копировать выделенное».
  final ValueChanged<String>? onTextSelectionChanged;

  /// Портрет собеседника — только у ПОСЛЕДНЕГО сообщения серии.
  ///
  /// 🔴 КАК НА ТЕЛЕФОНЕ И В ТЕЛЕГРАМЕ (16.09.2026). Портрет стоял у ПЕРВОГО
  /// сообщения серии, и у серии из трёх он висел над двумя пузырями, которые
  /// ниже, будто подписывал только верхний. Телефон (`showGroupAvatar`) и
  /// телеграм ставят его внизу серии, у самого свежего сообщения: имя
  /// открывает серию сверху, портрет закрывает её снизу. Где портрета нет,
  /// остаётся пустое место той же ширины — столбик пузырей не прыгает.
  final bool showAvatar;

  /// Перевод считается прямо сейчас.
  ///
  /// 🔴 БЕЗ ЭТОГО НАЖАТИЕ ВЫГЛЯДЕЛО БЫ ПРОВАЛОМ В ПУСТОТУ. Системная служба
  /// отвечает не мгновенно (а иногда, как выяснилось 16.09.2026, не отвечает
  /// вовсе — на этот случай стоит срок). Пока ответа нет, в пузыре должно быть
  /// видно, что просьбу услышали.
  final bool translating;

  /// 🔴 ПЕРЕВОД ЖИВЁТ НЕ В [MessageData], И ЭТО НАМЕРЕННО.
  ///
  /// `MessageData` — снимок ТОГО, ЧТО ПРИШЛО: текст, время, автор, вложение.
  /// Перевод же — состояние ПРОСМОТРА: его включают и выключают на этом
  /// устройстве, он ничего не меняет в сообщении и никуда не отправляется.
  /// Положить его в снимок значило бы пересобирать весь снимок при каждом
  /// нажатии «Перевести» — и однажды перепутать переведённое с полученным.
  ///
  /// Считает перевод сам компьютер, системным переводчиком macOS; текст
  /// сообщения никуда не уходит — см. `desktop_translation_service.dart`.
  final String? translatedText;

  /// Whether an incoming bubble carries the sender's portrait and name.
  ///
  /// False in a 1:1 conversation: there is exactly one other person, the
  /// header already names them, and repeating the label on every bubble is
  /// noise that also costs 40px of measure per line. True in rooms, where
  /// "who said this" is the whole point.
  ///
  /// Only affects the PEER side — your own bubbles never carry either.
  final bool showPeerIdentity;

  final MessageData message;
  final VoidCallback? onReply;

  /// Tapping the reply quote jumps to the quoted message. Receives the quoted
  /// message's payload-event id (from [ReplyPreview.targetPayloadId]).
  final ValueChanged<String>? onReplyTap;
  final ValueChanged<String>? onReact;
  final void Function(Offset globalPosition)? onMoreActions;

  /// Свой профиль — чтобы понять, что «@…» обращено ко мне, и подсветить
  /// фишку как обращение, а не как чужое имя.
  final String selfProfileId;

  /// Достаётся ли мне «@admins». У обычного участника фишка «@admins» — это
  /// чужое обращение, и красить её как «зовут меня» было бы неправдой.
  final bool canReceiveAdminMentions;

  /// Нажатие по фишке поимённого упоминания: открыть профиль.
  final ValueChanged<String>? onProfileMentionTap;

  /// Сменить скорость воспроизведения голосового. `null` — плеер её не умеет.
  final ValueChanged<double>? onSetVoiceSpeed;

  /// «Продолжить в теме»: выбрать ветку и открыть поле ввода с цитатой этого
  /// сообщения. `null` — веток в этом чате нет (личная переписка или комната
  /// без тем), и кнопки тоже нет.
  ///
  /// 🔴 ИМЕННО «ПРОДОЛЖИТЬ», А НЕ «ВЫНЕСТИ». Перетегировать отправленное
  /// сообщение нельзя в принципе: тема лежит ВНУТРИ запечатанного payload, и
  /// переписать её у уже разосланного сообщения не может никто — ни отправитель,
  /// ни сервер. Кнопка «вынести в тему» обещала бы то, чего протокол не умеет;
  /// эта переносит не сообщение, а РАЗГОВОР, и называется соответственно.
  final void Function(Offset globalPosition)? onContinueInTopic;
  final VoidCallback? onAvatarTap;
  final ValueChanged<String>? onReactionTap;

  /// Tap-to-fullscreen image / video preview. Receives the bubble's own
  /// [MessageData] so the host can resolve the carrier attachment and any
  /// sibling media for swipe navigation.
  final ValueChanged<MessageData>? onOpenImage;

  /// «Сохранить как…» прямо из ленты.
  ///
  /// 🔴 Сохранить снимок было можно ТОЛЬКО открыв его на весь экран. В макете
  /// под кадром стоит строка «имя файла · размер» со значком скачивания — то
  /// есть сохранение доступно оттуда, откуда на него смотрят.
  final ValueChanged<MessageData>? onSaveAttachment;

  /// Tapping a video attachment opens the fullscreen desktop video player.
  final ValueChanged<MessageData>? onOpenVideo;

  /// Tap on a generic file attachment — host opens / reveals in Finder.
  final ValueChanged<MessageData>? onOpenFile;

  /// Нажали вариант опроса.
  final void Function(MessageData message, int optionIndex)? onPollVote;

  /// Создатель опроса нажал «Завершить опрос».
  final ValueChanged<MessageData>? onPollClose;

  /// Ответили на событие: «иду», «возможно», «не иду».
  final void Function(MessageData message, String status)? onEventRsvp;

  /// Tap on the voice-note play/pause button. Host wires this to
  /// [AppController.toggleSharedAudioTrack] for the bubble's voice payload.
  final ValueChanged<MessageData>? onToggleVoice;

  /// Перемотка голосового долей 0..1 по нажатию на волну.
  ///
  /// Отдельным колбэком, а не `Duration`: длину знает пузырь (она приходит и
  /// из плеера, и из подсказки во вложении), а перематывает проигрыватель —
  /// пусть каждый считает то, что знает.
  final void Function(MessageData message, double fraction)? onSeekVoice;

  /// Snapshot of the shared audio player (track + position) used to decide
  /// whether THIS bubble is the active voice note and which icon to show.
  /// `null` while the listener hasn't fired yet — bubble renders the
  /// default "paused at 0" state in that case.
  final SharedAudioPlaybackState? sharedAudio;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  // Two MouseRegions share this state: the bubble itself, and the hover
  // bar positioned above it. Either one being entered keeps the bar visible.
  bool _bubbleHovered = false;
  bool _barHovered = false;
  Timer? _hideBarTimer;

  /// 🔴 СТРОКА ДЕЙСТВИЙ ЖИВЁТ В НАЛОЖЕНИИ, А НЕ В `Stack` ПУЗЫРЯ.
  ///
  /// Она рисуется НАД пузырём, за его верхним краем, — и во Flutter это значит
  /// «не нажимается вовсе». Проверка попадания у `RenderBox` начинается с
  /// `size.contains(position)`: точка вне рамки родителя до детей просто не
  /// доходит, сколько бы `Clip.none` ни стояло — он снимает обрезку РИСОВАНИЯ,
  /// а не проверку попадания.
  ///
  /// Измерено: строка занимала 99…127 по вертикали, а `Stack` пузыря —
  /// 132…208. Они не пересекались НИ В ОДНОЙ точке. То есть 👍, 🔥, «Ещё
  /// реакции», «Ответить» и «Ещё» появлялись при наведении и не делали ничего:
  /// нажатие уходило в сообщение снизу.
  ///
  /// 🔴 И ЭТО НЕ `CompositedTransformFollower`, ХОТЯ СНАЧАЛА БЫЛ ОН.
  ///
  /// ЖАЛОБА ВЛАДЕЛЬЦА 16.09.2026: «при наведении на пузыри высвечивается мини
  /// менюшка, на которую нельзя нажать, ибо она быстро пропадает, а при её
  /// появлении МОРГАЕТ ЭКРАН КРАСНЫМ ЦВЕТОМ».
  ///
  /// Красное — это `ErrorWidget`, подменивший собой упавшее поддерево. Ловушка
  /// в `main_desktop.dart` назвала виновника дословно:
  ///
  ///     rendering_library / during performLayout()
  ///     The paint transform cannot be reliably computed because of
  ///     RenderFollowerLayer(s)
  ///
  /// У кнопок строки есть подсказки (`Tooltip`), а `Tooltip` показывает себя
  /// через `OverlayPortal`. Тот при раскладке спрашивает у предков путь до
  /// слоя наложения — и натыкается на `RenderFollowerLayer`, который своё
  /// преобразование устанавливает ПОЗЖЕ, при композиции. Flutter роняет
  /// проверку (отладочная сборка — красный экран), строка перерисовывается
  /// пустышкой и исчезает. Отсюда ровно оба признака из жалобы: вспышка и
  /// «не успеть нажать».
  ///
  /// Подсказку в тексте той же ошибки Flutter даёт сам: заменить
  /// `CompositedTransformFollower` на `OverlayPortal.overlayChildLayoutBuilder`.
  /// Так и сделано. Портал отдаёт в построитель готовое преобразование пузыря
  /// в координатах слоя — место строка держит не хуже прежнего и так же едет с
  /// лентой, — а между ним и слоем нет ни одного «ленивого» преобразования,
  /// поэтому подсказки внутри работают.
  ///
  /// Побочная выгода: наложенный ребёнок портала — ребёнок ЭТОГО виджета в
  /// дереве, а не слоя наложения. Значит `DColors.of` внутри строки находит ту
  /// же палитру, что и пузырь; прежняя запись наложения этого не умела, и
  /// кнопки молча брали палитру по яркости системы.
  final OverlayPortalController _barCtl = OverlayPortalController();

  /// Per-emoji animation token. Incremented when a new reaction appears (or
  /// a count grows) so the chip replays its scale-in bounce. Mirrors the
  /// mobile token map driven by `_assignReactionPlayToken`.
  final Map<String, int> _reactionTokens = <String, int>{};

  /// Previous reaction snapshot keyed by emoji, used by `didUpdateWidget`
  /// to detect "newly appeared / increased" reactions and bump their token.
  Map<String, int> _prevReactionCounts = const <String, int>{};

  @override
  void initState() {
    super.initState();
    _syncReactionTokens(initial: true);
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_reactionsListsMatch(
      oldWidget.message.reactions,
      widget.message.reactions,
    )) {
      _syncReactionTokens();
    }
  }

  @override
  void dispose() {
    _hideBarTimer?.cancel();
    // Строку снимать вручную больше не нужно: наложенный ребёнок портала
    // уходит из дерева вместе с пузырём. Прежняя запись наложения его
    // переживала — и оставалась висеть поверх окна.
    super.dispose();
  }

  bool _reactionsListsMatch(
    List<MessageReaction> a,
    List<MessageReaction> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].emoji != b[i].emoji ||
          a[i].count != b[i].count ||
          a[i].byMe != b[i].byMe) {
        return false;
      }
    }
    return true;
  }

  /// Walk the current reactions list, bumping per-emoji tokens for any
  /// emoji that appears for the first time or whose count went up.
  void _syncReactionTokens({bool initial = false}) {
    final next = <String, int>{};
    for (final r in widget.message.reactions) {
      next[r.emoji] = r.count;
      if (initial) continue;
      final prev = _prevReactionCounts[r.emoji];
      if (prev == null || r.count > prev) {
        _reactionTokens.update(
          r.emoji,
          (v) => v + 1,
          ifAbsent: () => 1,
        );
      }
    }
    _prevReactionCounts = next;
  }

  void _onBubbleHoverChange(bool hovered) {
    if (hovered == _bubbleHovered) return;
    // `setState` здесь не нужен: от наведения в самом пузыре не зависит
    // ничего — строка действий рисуется наложением.
    _bubbleHovered = hovered;
    if (hovered) {
      _showBarOverlay();
    } else {
      _scheduleHideBar();
    }
  }

  void _onBarHoverChange(bool hovered) {
    if (hovered == _barHovered) return;
    _barHovered = hovered;
    if (!hovered) _scheduleHideBar();
  }

  /// Показывает строку действий. Повторный вызов ничего не делает.
  ///
  /// Выключенная в настройках строка не показывается вовсе — см.
  /// `DesktopUiPrefs.messageHoverBar`.
  void _showBarOverlay() {
    if (!mounted || _barCtl.isShowing) return;
    if (!DesktopUiPrefs.messageHoverBar.value) return;
    // У уходящего сообщения действий нет: ответить или отреагировать пока не
    // на что.
    if (widget.message.isUploading) return;
    _barCtl.show();
  }

  void _hideBarOverlay() {
    if (!mounted || !_barCtl.isShowing) return;
    _barCtl.hide();
  }

  /// Строка в координатах слоя наложения.
  ///
  /// `info.childPaintTransform` переводит точки пузыря в точки слоя — отсюда и
  /// берётся место.
  ///
  /// 🔴 СТРОКА — ЦЕЛИКОМ НАД ПУЗЫРЁМ (указание владельца 16.09.2026). По макету
  /// она была надвинута на верх пузыря (−14 по вертикали) и закрывала первую
  /// строку сообщения — ту самую, которую человек в этот момент читает. Теперь
  /// её НИЖНИЙ край стоит на [_barGap] выше пузыря: высоту строки знать не
  /// нужно, и пузырь не закрыт ни на точку. От своего края — те же 8.
  Widget _barOverlayChild(
    BuildContext ctx,
    OverlayChildLayoutInfo info,
    bool isSelf,
  ) {
    final c = DColors.of(ctx);
    final m = info.childPaintTransform;
    final topLeft = MatrixUtils.transformPoint(m, Offset.zero);
    final topRight = MatrixUtils.transformPoint(
      m,
      Offset(info.childSize.width, 0),
    );
    final bubbleTop = isSelf ? topRight.dy : topLeft.dy;
    // Снизу вверх: нижний край строки — на зазор выше пузыря.
    final bottom = info.overlaySize.height - (bubbleTop - _barGap);
    final bar = MouseRegion(
      onEnter: (_) => _onBarHoverChange(true),
      onExit: (_) => _onBarHoverChange(false),
      child: _hoverActions(c, isSelf),
    );
    // Своё сообщение прижимаем ПРАВЫМ краем: ширина строки зависит от того,
    // есть ли у комнаты ветки, и считать её заранее нечем.
    return isSelf
        ? Positioned(
            right: info.overlaySize.width - (topRight.dx - 8),
            bottom: bottom,
            child: bar,
          )
        : Positioned(left: topLeft.dx + 8, bottom: bottom, child: bar);
  }

  /// Зазор между строкой действий и пузырём. Курсор проходит его за доли
  /// секунды, а строка гаснет не сразу (см. [_scheduleHideBar]) — поэтому
  /// дотянуться до кнопок зазор не мешает.
  static const double _barGap = 4;

  /// 120 ms grace so the cursor can briefly leave both regions (e.g. when
  /// crossing the 0-px sliver between them) without the bar flickering out.
  void _scheduleHideBar() {
    _hideBarTimer?.cancel();
    _hideBarTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      if (_bubbleHovered || _barHovered) return;
      _hideBarOverlay();
    });
  }

  /// Which side of the thread this message belongs on.
  ///
  /// For everything except a call it is simply "did I send it".
  ///
  /// 🔴 ЗВОНКИ — ИСКЛЮЧЕНИЕ, И БЕЗ НЕГО ВСЕ ОНИ УЕЗЖАЮТ ВПРАВО (11.09.2026,
  /// жалоба владельца: «все почему-то справа, как будто мои, хотя там есть и
  /// собеседников»).
  ///
  /// Запись о звонке создаётся ЛОКАЛЬНО тем устройством, которое звонок
  /// обслужило — и входящий, и исходящий. Поэтому `senderDeviceId` у неё
  /// всегда своё, `isSelf` всегда true, и общее правило «кто отправитель»
  /// ставит справа даже звонки собеседника.
  ///
  /// Сторону задаёт НАПРАВЛЕНИЕ звонка. Мобильный экран делает ровно это —
  /// `final displayAsOutgoing = callEvent.direction == CallRecordDirection.outgoing;`
  /// и передаёт его как `isMe` (chat_screen.dart, `_CallEventBubble`), — а
  /// десктоп передавал `isSelf` как есть.
  /// Плашка служебного сообщения — той же формы, что разделитель даты в
  /// ленте: чип без рамки, текст по центру. Пузырём его делать нельзя — это
  /// не чья-то реплика, и ни автора, ни галочек у него нет.
  Widget _buildSystemEvent(DColorSet c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DSpace.xl2, DSpace.s, DSpace.xl2, 0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(DRadii.r9),
          ),
          child: Text(
            widget.message.text,
            textAlign: TextAlign.center,
            style: DType.caption.copyWith(
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  bool _sideIsSelf(MessageData m) {
    final call = m.callEvent;
    if (call == null) return m.isSelf;
    return call.direction == CallRecordDirection.outgoing;
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final m = widget.message;
    if (m.isSystemEvent) return _buildSystemEvent(c);
    final isSelf = _sideIsSelf(m);

    // Bubble-free solo emoji: when the text is exactly one Noto-animatable
    // emoji and there's no reply, render the big Lottie variant. Mirrors
    // mobile's `_SoloEmojiMessage`.
    if (m.reply == null && isSoloNotoEmoji(m.text)) {
      return _buildSoloEmoji(c, isSelf);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        // · Боковой отступ ленты — 24 (макет), а не 20. Пузырь стоял ближе
        // к краю окна, чем к соседнему столбцу, и лента читалась прижатой.
        DSpace.xl2,
        m.continuation ? 2 : DSpace.m,
        DSpace.xl2,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isSelf && widget.showPeerIdentity) _avatarSlot(c),
          if (!isSelf && widget.showPeerIdentity) const SizedBox(width: DSpace.s),
          Flexible(
            child: LayoutBuilder(builder: (ctx, constraints) {
              final cap = isSelf ? kBubbleMaxWidthSelf : kBubbleMaxWidthPeer;
              final maxW = constraints.maxWidth.isFinite
                  ? (constraints.maxWidth * kBubbleWidthFactor)
                      .clamp(120.0, cap)
                  : 480.0;
              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW.toDouble()),
                child: Column(
                  crossAxisAlignment: isSelf
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Реакции больше НЕ здесь: они внутри пузыря, в подвале
                    // ([_metaRow]) — как в мобильной версии.
                    _bubbleStack(c, isSelf, maxW.toDouble()),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Only the peer gets a portrait.
  ///
  /// Your own avatar next to your own messages is a mobile-list habit: in a
  /// conversation you already know who you are, side and colour say it, and the
  /// portrait costs 40px of measure on every outgoing line. No desktop
  /// messenger shows it.
  Widget _avatarSlot(DColorSet c) {
    if (!widget.showAvatar) {
      return const SizedBox(width: 32);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Avatar(
        name: widget.message.authorName,
        seed: widget.message.authorProfileId,
        image: Avatar.fileImage(widget.message.senderAvatarPath),
        size: 32,
        onTap: widget.onAvatarTap,
      ),
    );
  }

  /// Solo emoji bubble-free variant. Bubble is replaced by a 144 px Lottie
  /// emoji; tap replays the animation (uses a unique ValueKey so the inner
  /// state remounts and the controller restarts).
  Widget _buildSoloEmoji(DColorSet c, bool isSelf) {
    final m = widget.message;
    return MouseRegion(
      onEnter: (_) => _onBubbleHoverChange(true),
      onExit: (_) => _onBubbleHoverChange(false),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DSpace.xl2,
          m.continuation ? 2 : DSpace.m,
          DSpace.xl2,
          0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isSelf && widget.showPeerIdentity) _avatarSlot(c),
            if (!isSelf && widget.showPeerIdentity)
              const SizedBox(width: DSpace.s),
            SecondaryClickArea(
              onSecondaryClick: widget.onMoreActions,
              child: _mediaZone(Column(
              crossAxisAlignment: isSelf
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _SoloEmojiPlayer(emoji: m.text.trim()),
                // Большое эмодзи рисуется без пузыря, значит и без подвала —
                // слот реакций ему нужен свой, иначе реакция на такое
                // сообщение видна на телефоне и не видна здесь.
                _reactionsSlot(c, isSelf),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m.time,
                        style: DType.tiny.copyWith(color: c.textSecondary),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 4),
                        _deliveryIcon(m.delivery, isSelf, c),
                      ],
                    ],
                  ),
                ),
              ],
            )),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔴 РЕАКЦИИ СНОВА ВНУТРИ ПУЗЫРЯ — КАК НА ТЕЛЕФОНЕ.
  ///
  /// 14.09.2026 фишки вынесли отдельной строкой ПОД пузырь: так нарисовано в
  /// макете, и так у них один набор цветов вместо двух. 16.09.2026 владелец
  /// указал обратное и прямо: «реакции на смс были такие же как в мобильной
  /// версии ВНУТРИ пузырей и с анимацией». Указание новее — оно и главнее.
  ///
  /// Цена возврата честная: под своей фишкой опять живой переход, поэтому
  /// цветов снова два набора (см. [_ReactionChip]). Взамен ушло расхождение с
  /// телефоном, из-за которого одно и то же сообщение выглядело на двух
  /// устройствах по-разному.
  ///
  /// Само место одно на все семь видов пузыря — [_metaRow], где стоит время:
  /// иначе слот пришлось бы вставлять в каждый вид отдельно и не забывать про
  /// него в следующем. Исключение — снимок без подписи: там подвала нет вовсе,
  /// время лежит пилюлей поверх кадра, и слот добавлен рядом с ним.
  Widget _bubbleStack(DColorSet c, bool isSelf, double maxWidth) =>
      _bubbleWithBar(c, isSelf, maxWidth);

  /// Слот реакций: пустой, пока их нет, и раскрывающийся под первую.
  ///
  /// Слот есть ВСЕГДА, и в этом весь смысл: пузырь дорастает до первой
  /// реакции, а не прыгает. Числа те же, что на телефоне (260 мс,
  /// `easeOutCubic`).
  ///
  /// 🔴 `Clip.none` — не украшение. `AnimatedSize` растит обе стороны и по
  /// умолчанию обрезает ребёнка по текущей рамке: пока слот раскрывается,
  /// фишку резало пополам по вертикали. На телефоне это уже чинили
  /// (01.08.2026, поле: «реакция разрезана пополам, пока идёт рост»).
  /// 🔴 ПОЛЯ — ВНУТРИ СЛОТА, А НЕ СНАРУЖИ, И ЭТО НЕ ПРИДИРКА.
  ///
  /// Снаружи они занимали бы место всегда: под каждым снимком без подписи
  /// оставалась бы пустая полоса в семь точек. Обойти это условием «показывать
  /// слот, только когда реакции есть» значит убить сам смысл слота — пузырь
  /// переставал бы ДОРАСТАТЬ до первой реакции и прыгал бы, как раньше.
  /// Внутри пустой слот не занимает ничего и растёт плавно.
  ///
  /// [inset] — боковые поля для тех видов пузыря, где содержимое идёт от края
  /// (снимок, ролик): там реакции нельзя прижимать к самому краю кадра.
  Widget _reactionsSlot(DColorSet c, bool isSelf, {bool inset = false}) {
    final reactions = widget.message.reactions;
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: isSelf ? Alignment.topRight : Alignment.topLeft,
      clipBehavior: Clip.none,
      child: reactions.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: inset
                  ? const EdgeInsets.fromLTRB(13, 5, 13, 7)
                  : const EdgeInsets.only(top: 5, bottom: 1),
              child: _reactionsRow(c, isSelf),
            ),
    );
  }

  Widget _bubbleWithBar(DColorSet c, bool isSelf, double maxWidth) {
    return MouseRegion(
      onEnter: (_) => _onBubbleHoverChange(true),
      onExit: (_) => _onBubbleHoverChange(false),
      // Сама строка действий живёт в наложении, иначе её не нажать — см.
      // [_barCtl]. Пузырь здесь — `child` портала, то есть и якорь места.
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _barCtl,
        overlayChildBuilder: (ctx, info) =>
            _barOverlayChild(ctx, info, isSelf),
        // Правый щелчок — одной обёрткой на все виды пузыря: он должен
        // забирать нажатие раньше выделяемого текста (см.
        // [SecondaryClickArea]).
        child: SecondaryClickArea(
          onSecondaryClick: widget.message.isUploading
              ? null
              : widget.onMoreActions,
          child: _bubble(c, isSelf, maxWidth),
        ),
      ),
    );
  }

  Widget _bubble(DColorSet c, bool isSelf, double maxWidth) {
    final m = widget.message;
    final att = m.attachment;
    final fg = isSelf ? Colors.white : c.textPrimary;
    final fgSoft = isSelf
        ? Colors.white.withValues(alpha: 0.78)
        : c.textSecondary;
    // · У ПРОДОЛЖЕНИЯ ГРУППЫ СЖИМАЕТСЯ И ВЕРХНИЙ УГОЛ СО СТОРОНЫ ХВОСТА
    // (макет: второй пузырь подряд от того же автора — 6 16 16 6).
    //
    // Хвост у пузыря один, снизу. Пока верхний угол оставался круглым, между
    // пузырями одного автора оставалась светлая щель, и группа из трёх
    // сообщений читалась как три отдельных. Сжатый угол склеивает их в
    // столбик, не добавляя ни линии, ни фона.
    final tail = m.continuation
        ? const Radius.circular(DRadii.sm)
        : const Radius.circular(DRadii.r16);
    final br = isSelf
        ? BorderRadius.only(
            topLeft: const Radius.circular(DRadii.r16),
            topRight: tail,
            bottomLeft: const Radius.circular(DRadii.r16),
            bottomRight: const Radius.circular(DRadii.sm),
          )
        : BorderRadius.only(
            topLeft: tail,
            topRight: const Radius.circular(DRadii.r16),
            bottomLeft: const Radius.circular(DRadii.sm),
            bottomRight: const Radius.circular(DRadii.r16),
          );

    // Цвета перехода берём у темы как раньше; трёхточечный вариант нужен
    // потому, что несколько пресетов без средней точки читаются плоско.
    final selfColors = c.bubbleSelfMid == null
        ? <Color>[c.bubbleSelfStart, c.bubbleSelfEnd]
        : <Color>[c.bubbleSelfStart, c.bubbleSelfMid!, c.bubbleSelfEnd];

    // 🔴 Свой пузырь БОЛЬШЕ НЕ НОСИТ ГРАДИЕНТ В ДЕКОРАЦИИ.
    //
    // Раньше каждый красился собственным переходом от своего верхнего угла к
    // своему нижнему: у длинного сообщения переход успевал пройти весь путь, у
    // короткого «ок» — тот же путь на высоте в двадцать точек. Подряд это
    // читалось как набор одинаковых полосок, и при прокрутке заливка ехала
    // вместе с пузырём.
    //
    // Теперь переход один на всю видимую область, а пузырь берёт из него свой
    // участок — этим занимается [ScreenGradientBox] ниже. Здесь у своего
    // пузыря остаётся только форма.
    final decoration = isSelf
        // 🔴 Своё свечение из макета (0 12px 30px rgba(84,96,224,.26)). Это не
        // украшение: им макет отделяет СВОЁ от чужого, не рисуя ни одной
        // линии. Заливки у своего пузыря здесь нет (её даёт общий переход
        // ниже), и без тени он лежал на холсте совсем плоско.
        ? BoxDecoration(
            borderRadius: br,
            boxShadow: DShadows.glowSelfBubble(c),
          )
        : BoxDecoration(
            borderRadius: br,
            color: m.hasMention ? c.mentionBg : c.bubblePeer,
          );

    // Наклейка рисуется без подложки вообще — заливать под ней нечего.
    if (m.sticker != null) {
      return _mediaZone(_stickerBubble(c, isSelf, fgSoft, m.sticker!));
    }

    // 🔴 КАК В TELEGRAM (указание владельца 16.09.2026): снимки и ролики
    // без подписи, ответа и имени автора лежат ПРЯМО НА ЛЕНТЕ, без пузыря;
    // отправленное вместе — одной сеткой; файлы — стопкой в одном пузыре.
    final Widget body;
    var hasBubble = true;
    final album = m.albumItems;
    final shelf = album != null ? albumShelfOf(album.first) : null;
    if (album != null && shelf == AlbumShelf.visual) {
      body = _visualMessage(c, isSelf, fg, fgSoft, br, decoration, maxWidth);
      hasBubble = _mediaNeedsBubble(isSelf);
    } else if (album != null && shelf == AlbumShelf.music) {
      body = _audioBubble(c, isSelf, fg, fgSoft, decoration, maxWidth);
    } else if (album != null) {
      body = _filesMessage(c, isSelf, fg, fgSoft, decoration, maxWidth);
    } else if (att != null &&
        att.videoNote &&
        att.kind == MessageAttachmentKind.video) {
      body = _videoNoteMessage(c, isSelf);
      hasBubble = false;
    } else if (att != null &&
        !att.sentAsFile &&
        (att.kind == MessageAttachmentKind.image ||
            att.kind == MessageAttachmentKind.video)) {
      body = _visualMessage(c, isSelf, fg, fgSoft, br, decoration, maxWidth);
      hasBubble = _mediaNeedsBubble(isSelf);
    } else if (att != null && att.kind == MessageAttachmentKind.voice) {
      body = _voiceBubble(c, isSelf, fg, fgSoft, br, decoration, att);
    } else if (att != null && att.kind == MessageAttachmentKind.audio) {
      body = _audioBubble(c, isSelf, fg, fgSoft, decoration, maxWidth);
    } else if (att != null) {
      body = _filesMessage(c, isSelf, fg, fgSoft, decoration, maxWidth);
    } else if (m.callEvent != null) {
      body = _callBubble(c, isSelf, fg, fgSoft, br, decoration, m.callEvent!);
    } else if (m.poll != null) {
      body = _pollBubble(c, isSelf, fg, fgSoft, decoration, m.poll!);
    } else if (m.eventCard != null) {
      body = _eventBubble(c, isSelf, fg, fgSoft, decoration, m.eventCard!);
    } else {
      body = _textBubble(c, isSelf, fg, fgSoft, br, decoration);
    }
    final zoned = att != null || m.callEvent != null ? _mediaZone(body) : body;

    // Заливка своего пузыря — только там, где пузырь есть.
    if (!isSelf || !hasBubble) return zoned;
    return ScreenGradientBox(
      colors: selfColors,
      borderRadius: br,
      child: zoned,
    );
  }

  /// Вложение, звонок, наклейка: у них свои жесты (перемотка голосового,
  /// открытие снимка), и протягивание с них выделение сообщений не начинает.
  static Widget _mediaZone(Widget child) => MetaData(
    metaData: DesktopBubbleZone.media,
    behavior: HitTestBehavior.translucent,
    child: child,
  );

  /// Цвет выделения текста: на своём залитом пузыре — белый, на чужом —
  /// служебный синий ленты.
  Color _selectionColor(DColorSet c, bool isSelf) => isSelf
      ? Colors.white.withValues(alpha: 0.32)
      : c.deliveryIndicator.withValues(alpha: 0.32);

  /// Выделенное в основном тексте и в переводе. Одновременно непусто только
  /// одно: выделение в одном месте снимает выделение в другом (фокус).
  String _selectedMain = '';
  String _selectedTranslation = '';

  void _onMainSelection(String text) {
    _selectedMain = text;
    _reportSelection();
  }

  void _onTranslationSelection(String text) {
    _selectedTranslation = text;
    _reportSelection();
  }

  void _reportSelection() {
    widget.onTextSelectionChanged?.call(
      _selectedMain.isNotEmpty ? _selectedMain : _selectedTranslation,
    );
  }

  /// Текст сообщения, который можно выделять мышью.
  Widget _selectable(
    DColorSet c,
    bool isSelf,
    Widget child, {
    bool translation = false,
  }) => MessageSelectableText(
    selectionColor: _selectionColor(c, isSelf),
    onChanged: translation ? _onTranslationSelection : _onMainSelection,
    child: child,
  );

  /// 2026-05-20 PR-A: call-history card. Mirrors mobile's `_CallEventBubble`
  /// from `chat_screen.dart:12978` — same title (`«Исходящий звонок»`,
  /// `«Пропущенный»` etc), same direction-arrow + phone-or-camera icon, same
  /// duration suffix for completed calls. Layout uses desktop tokens so it
  /// sits naturally next to other bubbles and follows the dark/light theme.
  /// Sticker bubble: borderless artwork (catalog or resolved user blob) with
  /// the group sender name above and a compact meta row below. Mirrors mobile's
  /// _StickerBubble look.
  Widget _stickerBubble(
    DColorSet c,
    bool isSelf,
    Color fgSoft,
    SecretlyStickerDescriptor sticker,
  ) {
    final m = widget.message;
    return HoverListener(
      builder: (ctx, hovered, pressed) => IntrinsicWidth(
        // 🔴 IntrinsicWidth — ради ВРЕМЕНИ У ПРАВОГО КРАЯ. Без него `Align` в
        // подвале растянулся бы на всю доступную ширину и раздул бы пузырь до
        // предела; с ним ширина колонки — по самому широкому ребёнку, а короткое
        // сообщение расширяется ровно настолько, чтобы вместить время. Так в
        // телеграме.
        child: Column(
        crossAxisAlignment:
            isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isSelf && !m.continuation && widget.showPeerIdentity) ...[
            _authorLine(c),
            const SizedBox(height: 3),
          ],
          SecretlyStickerAssetView(sticker: sticker, size: 140),
          const SizedBox(height: 2),
          _metaRow(c, isSelf, fgSoft),
        ],
        ),
      ),
    );
  }

  /// Пузырь с карточкой опроса — той же ширины и формы, что карточка звонка.
  Widget _pollBubble(
    DColorSet c,
    bool isSelf,
    Color fg,
    Color fgSoft,
    BoxDecoration decoration,
    DesktopPollView poll,
  ) {
    final m = widget.message;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 9),
        decoration: decoration,
        child: DesktopPollCard(
          poll: poll,
          foreground: fg,
          foregroundSoft: fgSoft,
          onVote: widget.onPollVote == null
              ? null
              : (index) => widget.onPollVote!(m, index),
          onClose: widget.onPollClose == null
              ? null
              : () => widget.onPollClose!(m),
        ),
      ),
    );
  }

  /// Пузырь с карточкой события — той же формы, что опрос и звонок.
  Widget _eventBubble(
    DColorSet c,
    bool isSelf,
    Color fg,
    Color fgSoft,
    BoxDecoration decoration,
    DesktopEventView event,
  ) {
    final m = widget.message;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 9),
        decoration: decoration,
        child: DesktopEventCard(
          event: event,
          foreground: fg,
          foregroundSoft: fgSoft,
          onRsvp: widget.onEventRsvp == null
              ? null
              : (status) => widget.onEventRsvp!(m, status),
        ),
      ),
    );
  }

  Widget _callBubble(
    DColorSet c,
    bool isSelf,
    Color fg,
    Color fgSoft,
    BorderRadius br,
    BoxDecoration decoration,
    CallEventV1 ev,
  ) {
    final m = widget.message;
    // For calls, the bubble side follows the call direction (mobile parity:
    // outgoing rolls right, incoming rolls left) — independent of which of
    // your own devices logged it. `isSelf` already reflects that on the
    // sender path; for inbound mirrors we trust `ev.direction`.
    final outgoing = ev.direction == CallRecordDirection.outgoing;
    final title = callRecordResultLabel(
      ev.result,
      l10n: null,
      isRu: m.isRu,
      direction: ev.direction,
      isVideo: ev.hadVideo,
    );
    final accent = _callAccentColor(ev.result);
    final mediaIcon = ev.hadVideo
        ? Icons.videocam_rounded
        : Icons.call_rounded;
    final dirIcon = ev.direction == CallRecordDirection.incoming
        ? Icons.call_received_rounded
        : Icons.call_made_rounded;

    return HoverListener(
      builder: (ctx, hovered, pressed) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 9),
            decoration: decoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isSelf && !m.continuation && widget.showPeerIdentity) ...[
                  _authorLine(c),
                  const SizedBox(height: 2),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DType.label.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      mediaIcon,
                      size: 18,
                      color: outgoing
                          ? Colors.white.withValues(alpha: 0.96)
                          : c.accentPrimary.withValues(alpha: 0.98),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(dirIcon, size: 14, color: accent),
                    const SizedBox(width: 5),
                    // Текст забирает всю середину — галочки уходят к правому
                    // краю пузыря, как у любого другого сообщения.
                    Expanded(
                      child: Text(
                        _callMetaText(ev, m),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DType.caption.copyWith(
                          color: fgSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      _deliveryIcon(m.delivery, isSelf, c),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Accent color for the call result. Green = OK / ongoing; red = missed /
  /// declined / busy / canceled; orange = transport failure. Matches mobile's
  /// `_callEventAccentColor` (`chat_screen.dart:13101`) — kept as literal
  /// hex values rather than design tokens because these colors are
  /// semantically about *call outcome*, not the desktop theme.
  Color _callAccentColor(CallRecordResult result) {
    switch (result) {
      case CallRecordResult.completed:
      case CallRecordResult.ongoing:
        return const Color(0xFF55C26A);
      case CallRecordResult.failed:
        return const Color(0xFFD9822B);
      case CallRecordResult.missed:
      case CallRecordResult.declined:
      case CallRecordResult.busy:
      case CallRecordResult.canceled:
        return const Color(0xFFE25555);
    }
  }

  /// "12:34" by itself for incomplete calls, or "12:34, 0:32" with the
  /// duration suffix for completed calls. Mirrors mobile's `_callMetaText`.
  String _callMetaText(CallEventV1 ev, MessageData m) {
    if (ev.durationMs <= 0 || ev.result != CallRecordResult.completed) {
      return m.time;
    }
    return '${m.time}, ${formatCallDurationShort(ev.durationMs)}';
  }

  // -------------------------------------------------------------------------
  // Bubble variants
  // -------------------------------------------------------------------------

  /// «↪ Переслано от X» chrome shown above a forwarded message's body.
  Widget _forwardedHeader(DColorSet c, String from) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(FluentIcons.arrow_forward_16_regular,
            size: 13, color: c.accentPrimary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'Переслано от $from',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DType.caption.copyWith(
              color: c.accentPrimary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _textBubble(
    DColorSet c,
    bool isSelf,
    Color fg,
    Color fgSoft,
    BorderRadius br,
    BoxDecoration decoration,
  ) {
    final m = widget.message;
    return HoverListener(
      // Поля пузыря ничего не делают по щелчку — рука-указатель над ними
      // обещала бы действие. Над текстом курсор станет «палочкой» сам.
      cursor: MouseCursor.defer,
      builder: (ctx, hovered, pressed) => Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
        decoration: decoration,
        child: IntrinsicWidth(
          // 🔴 IntrinsicWidth — ради ВРЕМЕНИ У ПРАВОГО КРАЯ. Без него `Align` в
          // подвале растянулся бы на всю доступную ширину и раздул бы пузырь до
          // предела; с ним ширина колонки — по самому широкому ребёнку, а короткое
          // сообщение расширяется ровно настолько, чтобы вместить время. Так в
          // телеграме.
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.reply != null) _replyQuote(c, isSelf, m.reply!),
            if (!isSelf && !m.continuation && widget.showPeerIdentity) ...[
              _authorLine(c),
              const SizedBox(height: 2),
            ],
            if (m.forwardedFrom != null) ...[
              _forwardedHeader(c, m.forwardedFrom!),
              const SizedBox(height: 3),
            ],
            // 🔴 ТЕМ ЖЕ РАЗБОРОМ, ЧТО У ТЕЛЕФОНА: разметка, упоминания фишками
            // и ссылки. Здесь стоял `LinkifiedText` — только ссылки, — и
            // сообщение, набранное на телефоне жирным, на компьютере читалось
            // «**жирным**» со звёздочками, которых человек не писал, а спойлер
            // показывался открытым. См. [MessageRichText].
            _textWithMeta(c, isSelf, fg, fgSoft),
          ],
          ),
        ),
      ),
    );
  }

  // ── Снимки, ролики, альбомы, файлы — как в Telegram ─────────────────────

  bool _showsAuthor(bool isSelf) =>
      !isSelf && !widget.message.continuation && widget.showPeerIdentity;

  bool _hasMediaHeader(bool isSelf) {
    final m = widget.message;
    return m.reply != null || m.forwardedFrom != null || _showsAuthor(isSelf);
  }

  /// Нужен ли медиа пузырь. Как в Telegram (`needsBubble` у снимка): только
  /// ради подписи, ответа, пересылки или имени автора. Иначе снимок лежит
  /// прямо на ленте.
  bool _mediaNeedsBubble(bool isSelf) =>
      widget.message.text.trim().isNotEmpty || _hasMediaHeader(isSelf);

  /// Шапка медиа в пузыре: цитата, имя автора, «Переслано от».
  Widget _mediaHeader(DColorSet c, bool isSelf) {
    final m = widget.message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (m.reply != null) _replyQuote(c, isSelf, m.reply!),
        if (_showsAuthor(isSelf)) ...[
          _authorLine(c),
          const SizedBox(height: 2),
        ],
        if (m.forwardedFrom != null) _forwardedHeader(c, m.forwardedFrom!),
      ],
    );
  }

  /// Время с галочками поверх медиа — в правом нижнем углу, в 4 точках от
  /// краёв. Нажатия проходят сквозь него к снимку.
  Widget _mediaTimeBadge(bool isSelf) {
    final m = widget.message;
    return IgnorePointer(
      child: _MetaPill(
        time: m.time,
        edited: m.edited,
        isSelf: isSelf,
        delivery: m.delivery,
      ),
    );
  }

  /// Открыть снимок или ролик — у каждой плитки альбома своё сообщение.
  VoidCallback? _openFor(MessageData item) {
    final a = item.attachment;
    if (a == null) return null;
    if (a.kind == MessageAttachmentKind.video) {
      final open = widget.onOpenVideo;
      return open == null ? null : () => open(item);
    }
    if (a.kind == MessageAttachmentKind.image) {
      final open = widget.onOpenImage;
      return open == null ? null : () => open(item);
    }
    final open = widget.onOpenFile;
    return open == null ? null : () => open(item);
  }

  VoidCallback? _downloadFor(MessageData item) {
    final download = widget.onDownloadAttachment;
    return download == null ? null : () => download(item);
  }

  VoidCallback? _cancelFor(MessageData item) {
    final cancel = widget.onCancelUpload;
    if (cancel == null || item.attachment?.uploadProgress == null) return null;
    return () => cancel(item);
  }

  /// Снимок, ролик или альбом из них.
  ///
  /// Без подписи, ответа и имени автора — прямо на ленте, со скруглением
  /// пузыря и временем поверх кадра. С ними — в пузыре: шапка сверху, медиа
  /// во всю ширину пузыря, подпись снизу; углы, к которым примыкает шапка
  /// или подпись, прямые.
  Widget _visualMessage(
    DColorSet c,
    bool isSelf,
    Color fg,
    Color fgSoft,
    BorderRadius br,
    BoxDecoration decoration,
    double maxWidth,
  ) {
    final m = widget.message;
    final items = m.albumItems ?? <MessageData>[m];
    final inBubble = _mediaNeedsBubble(isSelf);
    final hasHeader = _hasMediaHeader(isSelf);
    final hasCaption = m.text.trim().isNotEmpty;
    final outer = !inBubble
        ? br
        : BorderRadius.only(
            topLeft: hasHeader ? Radius.zero : br.topLeft,
            topRight: hasHeader ? Radius.zero : br.topRight,
            bottomLeft: hasCaption ? Radius.zero : br.bottomLeft,
            bottomRight: hasCaption ? Radius.zero : br.bottomRight,
          );

    final Widget media;
    final double mediaWidth;
    if (items.length == 1) {
      final item = items.first;
      final att = item.attachment!;
      var size = singleMediaSize(
        att.mediaSize,
        maxWidth: maxWidth,
        inBubble: inBubble,
      );
      if (inBubble) {
        // В пузыре снимок занимает всю его ширину, а высота подрастает,
        // чтобы срезалось меньше.
        final src = att.mediaSize;
        final h = (size.width * src.height / src.width)
            .clamp(DMedia.minSize, DMedia.maxSize)
            .roundToDouble();
        size = Size(size.width, h);
      }
      mediaWidth = size.width;
      media = DesktopMediaTile(
        key: ValueKey('tile_${item.id}'),
        attachment: att,
        size: size,
        radius: outer,
        onOpen: _openFor(item),
        onRetry: _downloadFor(item),
        onCancelUpload: _cancelFor(item),
        placeholder: c.elevated,
      );
    } else {
      final sizes = [for (final it in items) it.attachment!.mediaSize];
      mediaWidth = mediaGroupSize(albumLayout(sizes, width: maxWidth)).width;
      media = DesktopMediaGrid(
        attachments: [for (final it in items) it.attachment!],
        width: maxWidth,
        outerRadius: outer,
        tileBuilder: (i, size, radius, fullWidth) => DesktopMediaTile(
          key: ValueKey('tile_${items[i].id}'),
          attachment: items[i].attachment!,
          size: size,
          radius: radius,
          showVideoBadge: fullWidth,
          onOpen: _openFor(items[i]),
          onRetry: _downloadFor(items[i]),
          onCancelUpload: _cancelFor(items[i]),
          placeholder: c.elevated,
        ),
      );
    }

    final withBadge = Stack(
      children: [
        media,
        Positioned(right: 4, bottom: 4, child: _mediaTimeBadge(isSelf)),
      ],
    );

    if (!inBubble) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isSelf
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          withBadge,
          // Реакции — под снимком, на ленте (у снимка без пузыря нет
          // подвала, куда их положить).
          SizedBox(width: mediaWidth, child: _reactionsSlot(c, isSelf)),
        ],
      );
    }
    return Container(
      width: mediaWidth,
      decoration: decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 6),
              child: _mediaHeader(c, isSelf),
            ),
          if (hasCaption) media else withBadge,
          if (hasCaption)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 6, 13, 8),
              child: _textWithMeta(c, isSelf, fg, fgSoft),
            )
          else
            _reactionsSlot(c, isSelf, inset: true),
        ],
      ),
    );
  }

  /// Видеосообщение-«кружок»: круг 240 без пузыря, как в Telegram.
  Widget _videoNoteMessage(DColorSet c, bool isSelf) {
    final m = widget.message;
    final att = m.attachment!;
    const side = 240.0;
    final duration = att.durationMs;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isSelf
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            DesktopMediaTile(
              key: ValueKey('note_${m.id}'),
              attachment: att,
              size: const Size.square(side),
              radius: BorderRadius.circular(side / 2),
              showVideoBadge: false,
              onOpen: _openFor(m),
              onRetry: _downloadFor(m),
              placeholder: c.elevated,
            ),
            if (duration != null && duration > 0)
              Positioned(
                left: 20,
                bottom: 14,
                child: IgnorePointer(
                  child: MediaBadge(child: Text(formatMediaDuration(duration))),
                ),
              ),
            Positioned(right: 14, bottom: 14, child: _mediaTimeBadge(isSelf)),
          ],
        ),
        SizedBox(width: side, child: _reactionsSlot(c, isSelf)),
      ],
    );
  }

  /// Файл или стопка файлов — в одном пузыре, как в Telegram для macOS:
  /// миниатюра или круг со стрелкой, имя, «2,6 МБ — Загрузить».
  Widget _filesMessage(
    DColorSet c,
    bool isSelf,
    Color fg,
    Color fgSoft,
    BoxDecoration decoration,
    double maxWidth,
  ) {
    final m = widget.message;
    final items = m.albumItems ?? <MessageData>[m];
    final grouped = items.length > 1;
    final hasCaption = m.text.trim().isNotEmpty;
    final link = isSelf ? Colors.white : c.deliveryIndicator;
    final iconBg = isSelf
        ? Colors.white.withValues(alpha: 0.22)
        : c.accentPrimary;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 13, 8),
      decoration: decoration,
      constraints: BoxConstraints(
        minWidth: math.min(DMedia.fileMinWidth, maxWidth),
        maxWidth: math.min(DMedia.maxSize, maxWidth),
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasMediaHeader(isSelf)) ...[
              _mediaHeader(c, isSelf),
              const SizedBox(height: 4),
            ],
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              DesktopFileRow(
                key: ValueKey('file_${items[i].id}'),
                attachment: items[i].attachment!,
                fg: fg,
                fgSoft: fgSoft,
                accent: link,
                iconBg: iconBg,
                iconFg: Colors.white,
                grouped: grouped,
                onDownload: _downloadFor(items[i]),
                onOpen: _openFor(items[i]),
                onReveal: widget.onRevealAttachment == null
                    ? null
                    : () => widget.onRevealAttachment!(items[i]),
                onCancelUpload: _cancelFor(items[i]),
              ),
            ],
            if (hasCaption) ...[
              const SizedBox(height: 6),
              _textWithMeta(c, isSelf, fg, fgSoft),
            ] else ...[
              const SizedBox(height: 4),
              _metaRow(c, isSelf, fgSoft),
            ],
          ],
        ),
      ),
    );
  }

  /// Voice-note bubble. Play/pause + progress + duration.
  /// The bubble's "active" state (live progress, animated waveform-ish
  /// bars) is driven by `widget.sharedAudio` — the host listens to
  /// [AppController.sharedAudioPlayback] and rebuilds when needed.
  Widget _voiceBubble(
    DColorSet c,
    bool isSelf,
    Color fg,
    Color fgSoft,
    BorderRadius br,
    BoxDecoration decoration,
    MessageAttachment att,
  ) {
    final m = widget.message;
    final shared = widget.sharedAudio;
    final isActive =
        shared?.currentTrack?.trackId == att.payloadEventId &&
        shared?.currentTrack != null;
    final isPlaying = isActive && (shared?.playing ?? false);
    final isLoading = shared?.loadingTrackId == att.payloadEventId;
    final position = isActive ? shared!.position : Duration.zero;
    final duration = isActive && shared!.duration > Duration.zero
        ? shared.duration
        : (att.durationMs != null
              ? Duration(milliseconds: att.durationMs!)
              : Duration.zero);
    final progress = duration > Duration.zero
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final btnBg = isSelf
        ? Colors.white.withValues(alpha: 0.22)
        : c.accentPrimary.withValues(alpha: 0.18);
    final btnIcon = isSelf ? Colors.white : c.accentPrimary;
    final barBg = isSelf
        ? Colors.white.withValues(alpha: 0.25)
        : c.borderSubtle;
    final barFill = isSelf ? Colors.white : c.accentPrimary;

    return HoverListener(
      builder: (ctx, hovered, pressed) => Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 13, 8),
        decoration: decoration,
        constraints: const BoxConstraints(minWidth: 230, maxWidth: 320),
        child: IntrinsicWidth(
          // 🔴 IntrinsicWidth — ради ВРЕМЕНИ У ПРАВОГО КРАЯ. Без него `Align` в
          // подвале растянулся бы на всю доступную ширину и раздул бы пузырь до
          // предела; с ним ширина колонки — по самому широкому ребёнку, а короткое
          // сообщение расширяется ровно настолько, чтобы вместить время. Так в
          // телеграме.
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.reply != null) _replyQuote(c, isSelf, m.reply!),
            if (!isSelf && !m.continuation && widget.showPeerIdentity) ...[
              _authorLine(c),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                _VoicePlayButton(
                  isPlaying: isPlaying,
                  isLoading: isLoading,
                  background: btnBg,
                  iconColor: btnIcon,
                  onTap: () => widget.onToggleVoice?.call(m),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _VoiceProgressBar(
                        progress: progress,
                        background: barBg,
                        fill: barFill,
                        waveform: att.waveform,
                        // Перемотка только у ЗВУЧАЩЕЙ записи: ткнуть в волну
                        // неоткрытого голосового значит «начни отсюда», а
                        // плеер такого не умеет — обещать нечего.
                        onSeek: isActive && widget.onSeekVoice != null
                            ? (f) => widget.onSeekVoice!(m, f)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        duration > Duration.zero
                            ? '${_fmtMmSs(isActive ? position : Duration.zero)} / ${_fmtMmSs(duration)}'
                            : (att.sizeBytes > 0
                                  ? _fmtBytes(att.sizeBytes)
                                  : 'Голосовое'),
                        // Моноширинным, как в макете: секунды одинаковой
                        // ширины не дёргают соседние знаки при каждом тике.
                        style: DType.mono.copyWith(fontSize: 11, color: fgSoft),
                      ),
                    ],
                  ),
                ),
                // · ПЕРЕКЛЮЧАТЕЛЬ СКОРОСТИ «1×» (макет).
                //
                // Голосовые на компьютере слушают за работой, и минутное
                // сообщение на полутора скоростях — это сорок секунд, а не
                // минута.
                //
                // 🔴 Показан только у ЗВУЧАЩЕЙ записи: у молчащей менять
                // нечего, а кнопка рядом с каждым голосовым в ленте — это
                // тридцать кнопок, из которых работает одна.
                if (isActive && widget.onSetVoiceSpeed != null) ...[
                  const SizedBox(width: 8),
                  _SpeedButton(
                    speed: shared?.speed ?? 1.0,
                    color: fgSoft,
                    onTap: () => widget.onSetVoiceSpeed!(
                      _nextVoiceSpeed(shared?.speed ?? 1.0),
                    ),
                  ),
                ],
              ],
            ),
            if (m.text.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(m.text, style: DType.body.copyWith(color: fg)),
            ],
            const SizedBox(height: 4),
            _metaRow(c, isSelf, fgSoft),
          ],
          ),
        ),
      ),
    );
  }

  /// Music / audio-file attachment — play/pause + filename + progress + time,
  /// driven by the same shared-audio player as voice notes.
  /// Песня или стопка песен в одном пузыре.
  Widget _audioBubble(
    DColorSet c,
    bool isSelf,
    Color fg,
    Color fgSoft,
    BoxDecoration decoration,
    double maxWidth,
  ) {
    final m = widget.message;
    final items = m.albumItems ?? <MessageData>[m];
    return HoverListener(
      cursor: MouseCursor.defer,
      builder: (ctx, hovered, pressed) => Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 13, 8),
        decoration: decoration,
        constraints: BoxConstraints(
          minWidth: math.min(240, maxWidth),
          maxWidth: math.min(DMedia.maxSize, maxWidth),
        ),
        child: IntrinsicWidth(
          // 🔴 IntrinsicWidth — ради ВРЕМЕНИ У ПРАВОГО КРАЯ. Без него `Align` в
          // подвале растянулся бы на всю доступную ширину и раздул бы пузырь до
          // предела; с ним ширина колонки — по самому широкому ребёнку, а короткое
          // сообщение расширяется ровно настолько, чтобы вместить время. Так в
          // телеграме.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasMediaHeader(isSelf)) ...[
                _mediaHeader(c, isSelf),
                const SizedBox(height: 4),
              ],
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _audioRow(c, isSelf, fg, fgSoft, items[i]),
              ],
              if (m.text.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                _textWithMeta(c, isSelf, fg, fgSoft),
              ] else ...[
                const SizedBox(height: 4),
                _metaRow(c, isSelf, fgSoft),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Строка песни: кнопка, «Исполнитель — Название», время.
  Widget _audioRow(
    DColorSet c,
    bool isSelf,
    Color fg,
    Color fgSoft,
    MessageData item,
  ) {
    final att = item.attachment!;
    final shared = widget.sharedAudio;
    final isActive =
        shared?.currentTrack?.trackId == att.payloadEventId &&
        shared?.currentTrack != null;
    final isPlaying = isActive && (shared?.playing ?? false);
    final isLoading = shared?.loadingTrackId == att.payloadEventId;
    final position = isActive ? shared!.position : Duration.zero;
    final duration = isActive && shared!.duration > Duration.zero
        ? shared.duration
        : (att.durationMs != null
              ? Duration(milliseconds: att.durationMs!)
              : Duration.zero);
    final progress = duration > Duration.zero
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final songTitle = (att.musicTitle ?? '').trim();
    final artist = (att.musicArtist ?? '').trim();
    final title = songTitle.isNotEmpty
        ? (artist.isNotEmpty ? '$artist – $songTitle' : songTitle)
        : ((att.fileName ?? '').trim().isNotEmpty
              ? att.fileName!.trim()
              : 'Аудиофайл');
    // Как в Telegram: пока не играет — «03:25, 4,5 МБ»; играет — «01:02 /
    // 03:25»; уходит — «1.2 МБ / 4.5 МБ».
    final uploading = att.uploadProgress != null;
    final String status;
    if (uploading) {
      status = uploadStatusText(att);
    } else if (isActive && duration > Duration.zero) {
      status = '${_fmtMmSs(position)} / ${_fmtMmSs(duration)}';
    } else {
      final parts = <String>[
        if (duration > Duration.zero) _fmtMmSs(duration),
        if (att.filePath == null && att.sizeBytes > 0) _fmtBytes(att.sizeBytes),
      ];
      status = parts.isEmpty ? 'Аудио' : parts.join(', ');
    }

    final btnBg = isSelf
        ? Colors.white.withValues(alpha: 0.22)
        : c.accentPrimary;
    const btnIcon = Colors.white;
    final barBg = isSelf
        ? Colors.white.withValues(alpha: 0.25)
        : c.borderSubtle;
    final barFill = isSelf ? Colors.white : c.accentPrimary;

    return Row(
      children: [
        if (uploading)
          MediaUploadRing(
            progress: att.uploadProgress!,
            onCancel: _cancelFor(item),
            diameter: 36,
            background: btnBg,
            foreground: btnIcon,
          )
        else
          _VoicePlayButton(
            isPlaying: isPlaying,
            isLoading: isLoading,
            background: btnBg,
            iconColor: btnIcon,
            onTap: () => widget.onToggleVoice?.call(item),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              MiddleEllipsisText(
                title,
                style: DType.bodyStrong.copyWith(color: fg),
              ),
              if (isActive) ...[
                const SizedBox(height: 5),
                _VoiceProgressBar(
                  progress: progress,
                  background: barBg,
                  fill: barFill,
                  waveform: att.waveform,
                ),
              ],
              const SizedBox(height: 3),
              Text(status, style: DType.caption.copyWith(color: fgSoft)),
            ],
          ),
        ),
      ],
    );
  }

  /// Подвал пузыря: время и галочки, а под ними — реакции, ВНУТРИ пузыря.
  ///
  /// Раньше реакции висели отдельной строкой ПОД пузырём — их добавляла
  /// внешняя колонка в [build]. В мобильной версии они лежат внутри:
  /// последним ребёнком колонки пузыря, в слоте с анимацией роста, поэтому
  /// пузырь «прорастает» в первую реакцию, а не дёргается скачком.
  ///
  /// Правка сделана здесь, а не в каждом из восьми видов пузыря, потому что
  /// подвал у них общий: наклейка, голос, аудио, файл, звонок, текст и оба
  /// медиа-пузыря с подписью — все зовут этот метод. Исключение — снимок и
  /// видео БЕЗ подписи: у них вместо подвала накладная плашка поверх кадра,
  /// поэтому реакции им добавлены отдельно, в [_visualMessage].
  /// Перевод под оригиналом — тем же видом, что на телефоне.
  ///
  /// Черта, затем подпись «Перевод», затем текст чуть бледнее: он вторичен по
  /// отношению к тому, что человек НАПИСАЛ, и не должен с ним спорить.
  /// Оригинал остаётся на месте всегда — подменять сказанное переводом нельзя.
  Widget _translationBlock(DColorSet c, bool isSelf, Color fg) {
    final translated = widget.translatedText?.trim() ?? '';
    if (translated.isEmpty && !widget.translating) {
      return const SizedBox.shrink();
    }
    if (translated.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: fg.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Переводим…',
              style: DType.tiny.copyWith(color: fg.withValues(alpha: 0.55)),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 5),
            color: fg.withValues(alpha: 0.14),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              'ПЕРЕВОД',
              style: DType.tiny.copyWith(
                color: fg.withValues(alpha: 0.55),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _selectable(
            c,
            isSelf,
            MessageRichText(
              text: translated,
              mentions: const <MsgMentionV1>[],
              style: DType.body.copyWith(color: fg.withValues(alpha: 0.86)),
              isSelf: isSelf,
              selfProfileId: widget.selfProfileId,
              canReceiveAdminMentions: widget.canReceiveAdminMentions,
              onProfileMentionTap: widget.onProfileMentionTap,
            ),
            translation: true,
          ),
        ],
      ),
    );
  }

  /// Текст сообщения и подвал под ним — с телеграмным «время в той же
  /// строке, если влезло».
  ///
  /// 🔴 В ТЕЛЕГРАМЕ КОРОТКОЕ СООБЩЕНИЕ — ОДНА СТРОКА. «го 21:07 ✓✓» занимает
  /// ровно строку, а не две (16.09.2026, скриншот владельца). У нас время
  /// всегда уходило вниз, и каждое «ок», «го», «да» стоило пузырю лишнего
  /// роста — при десятке коротких ответов подряд разница в ленте огромная.
  ///
  /// Условия «если текст короче N» тут нет и быть не может: подпись времени
  /// разной ширины, шрифт разный, ширина пузыря разная. Вместо этого в конец
  /// текста вставлен НЕВИДИМЫЙ пролёт ровно той ширины, что и подпись, а сама
  /// подпись лежит поверх, в правом нижнем углу. Дальше всё решает обычный
  /// перенос строк: влез пролёт — время рядом, не влез — абзац перенёс его
  /// вниз вместе с собой, и подпись оказалась под текстом. Так это устроено и
  /// в телеграме.
  ///
  /// 🔴 ДВА СЛУЧАЯ ИДУТ СТАРЫМ ПУТЁМ, и оба по делу:
  ///   • есть реакции — подвал уже занят фишками, и время стоит в их строке;
  ///   • показан перевод — он идёт ПОД текстом, и время, приклеенное к низу
  ///     абзаца, налезло бы на него;
  ///   • есть карточка ссылки — время стоит под ней, как в телеграме.
  Widget _textWithMeta(
    DColorSet c,
    bool isSelf,
    Color fg,
    Color fgSoft,
  ) {
    final m = widget.message;
    final own = m.ownLinkPreviewTarget;
    if (m.linkPreview == null && own != null) {
      // Своё прежнее сообщение без карточки: загружаем её здесь, если это
      // не выключено в настройках. Чужие сообщения сюда не попадают никогда.
      return ValueListenableBuilder<bool>(
        valueListenable: DesktopUiPrefs.linkPreviews,
        builder: (ctx, enabled, _) => enabled
            ? DesktopOwnLinkPreview(
                target: own,
                builder: (ctx, preview) =>
                    _textBody(c, isSelf, fg, fgSoft, preview),
              )
            : _textBody(c, isSelf, fg, fgSoft, null),
      );
    }
    return _textBody(c, isSelf, fg, fgSoft, m.linkPreview);
  }

  Widget _textBody(
    DColorSet c,
    bool isSelf,
    Color fg,
    Color fgSoft,
    LinkPreviewV1? preview,
  ) {
    final m = widget.message;
    final style = DType.body.copyWith(color: fg);
    final translated = (widget.translatedText ?? '').trim();
    final inline = m.reactions.isEmpty && translated.isEmpty &&
        !widget.translating && preview == null;

    Widget text({InlineSpan? trailing}) => MessageRichText(
          text: m.text,
          mentions: m.mentions,
          style: style,
          isSelf: isSelf,
          selfProfileId: widget.selfProfileId,
          canReceiveAdminMentions: widget.canReceiveAdminMentions,
          onProfileMentionTap: widget.onProfileMentionTap,
          trailingSpan: trailing,
        );

    if (!inline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _selectable(c, isSelf, text()),
          _translationBlock(c, isSelf, fg),
          if (preview != null)
            DesktopLinkPreviewCard(preview: preview, isSelf: isSelf),
          const SizedBox(height: 4),
          _metaRow(c, isSelf, fgSoft),
        ],
      );
    }

    final meta = _metaInline(c, isSelf, fgSoft);
    // 🔴 ВРЕМЯ И ГАЛОЧКИ — В ПРАВОМ НИЖНЕМ УГЛУ ПУЗЫРЯ, А НЕ ТЕКСТА
    // (указание владельца 16.09.2026).
    //
    // Слой занимал ширину ТЕКСТА: если пузырь шире (подпись под файлами или
    // снимком, короткий ответ под длинной цитатой, имя автора длиннее
    // «ок»), время вставало сразу за словами, посреди пузыря. Теперь слой
    // во всю ширину пузыря. На ширину самого пузыря это не влияет: для
    // подсчёта ширины `SizedBox` с бесконечной шириной отдаёт ширину текста.
    return SizedBox(
      width: double.infinity,
      child: Stack(
      children: [
        _selectable(
          c,
          isSelf,
          text(
            trailing: WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              // Невидимая копия подписи — единственный способ занять РОВНО
              // столько, сколько она займёт: считать ширину по буквам значит
              // промахнуться на первом же другом шрифте. Из выделения она
              // исключена: иначе «14:19» уезжало бы в копию вместе с текстом.
              child: SelectionContainer.disabled(
                child: Opacity(
                  opacity: 0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: DSpace.s),
                    child: meta,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(right: 0, bottom: 0, child: meta),
      ],
      ),
    );
  }

  /// Подпись времени без выравнивания и без слота реакций — для случая, когда
  /// она лежит поверх текста.
  Widget _metaInline(DColorSet c, bool isSelf, Color fgSoft) {
    final m = widget.message;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(m.time, style: DType.tiny.copyWith(color: fgSoft)),
        if (m.edited) ...[
          const SizedBox(width: 6),
          Text('изменено', style: DType.tiny.copyWith(color: fgSoft)),
        ],
        if (isSelf) ...[
          const SizedBox(width: 4),
          _deliveryIcon(m.delivery, isSelf, c),
        ],
      ],
    );
  }

  Widget _metaRow(DColorSet c, bool isSelf, Color fgSoft) {
    final m = widget.message;
    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // · СНАЧАЛА ВРЕМЯ, ПОТОМ «ИЗМЕНЕНО» — и словом целиком (макет).
        //
        // «изм.» перед временем сдвигало время с места: в столбике подвалов
        // оно оказывалось то у левого края, то правее на ширину сокращения, и
        // взгляд, ищущий время, каждый раз искал заново. Само сокращение
        // экономило три буквы там, где места хватает.
        Text(m.time, style: DType.tiny.copyWith(color: fgSoft)),
        if (m.edited) ...[
          const SizedBox(width: 6),
          Text('изменено', style: DType.tiny.copyWith(color: fgSoft)),
        ],
        if (isSelf) ...[
          const SizedBox(width: 4),
          _deliveryIcon(m.delivery, isSelf, c),
        ],
      ],
    );
    // 🔴 РЕАКЦИИ И ВРЕМЯ — ОДНА СТРОКА, А НЕ ДВЕ (16.09.2026).
    //
    // Жалоба владельца: «реакции почему-то находятся НАД датой». Так и было:
    // подвал был столбиком — сверху фишки, снизу время. В телеграме это одна
    // строка: фишки прижаты влево, время с галочками — вправо, и подвал
    // занимает один рост вместо двух.
    //
    // Пустой слот не занимает ничего, поэтому у сообщения без реакций строка
    // выглядит ровно как раньше — только время теперь у правого края.
    // 🔴 И ВРЕМЯ СТОИТ У ПРАВОГО КРАЯ ПУЗЫРЯ, А НЕ У ЛЕВОГО.
    //
    // Так в телеграме, и так у времени есть постоянное место: взгляд ищет его
    // в одном углу, а не по ширине сообщения. Раньше подвал был прижат влево
    // вслед за текстом, и у широкого сообщения время оказывалось посреди
    // пузыря.
    //
    // Держится это на [IntrinsicWidth] у колонки самого пузыря: без него
    // `Align` растянул бы подвал на всю доступную ширину и раздул бы каждый
    // пузырь до предела. С ним ширина колонки — по самому широкому ребёнку,
    // и короткое сообщение расширяется ровно настолько, чтобы вместить время,
    // — тоже как в телеграме.
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        // По нижнему краю: фишка выше подписи времени, и выравнивание по верху
        // подняло бы время над серединой фишки.
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _reactionsSlot(c, isSelf)),
          const SizedBox(width: DSpace.s),
          meta,
        ],
      ),
    );
  }


  static String _fmtMmSs(Duration d) {
    final s = d.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Widget _replyQuote(DColorSet c, bool isSelf, ReplyPreview r) {
    // 🔴 ЦИТАТА — КАК НА ТЕЛЕФОНЕ И В ТЕЛЕГРАМЕ: подложка цветом автора,
    // полоска, имя, одна строка текста (16.09.2026).
    //
    // 14.09 подложку убрали «по макету»: цитату держала одна полоска, и цвет
    // был один на всех — акцентный. Владелец прислал скриншот телеграма, а у
    // телефона цитата давно такая (`_ReplyQuoteStrip`): подложка оттенка
    // АВТОРА цитаты, полоска и имя того же цвета. Без подложки цитата сливалась
    // с самим сообщением; без цвета автора было не понять с первого взгляда,
    // КОГО цитируют.
    //
    // Числа — телефонные: подложка 12 % (18 % на своём пузыре), полоска 3,
    // радиус 10, поля 8×6.
    final seed = r.authorSeed.trim().isNotEmpty ? r.authorSeed : r.authorName;
    final accent = AvatarInitials.nicknameColor(seed: seed);
    final panel = AvatarInitials.replyPanelColor(seed: seed, isMe: isSelf);
    // На своём залитом пузыре имя белое: цветное имя поверх перехода от синего
    // к фиолетовому читается хуже белого — так же делает и телефон.
    final nameColor = isSelf ? Colors.white : accent;
    final barColor = isSelf ? Colors.white.withValues(alpha: 0.85) : accent;
    final textColor = isSelf
        ? Colors.white.withValues(alpha: 0.9)
        : c.textPrimary.withValues(alpha: 0.9);
    final quote = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      // Ширину ограничиваем, иначе длинная цитата растягивает пузырь на всю
      // доступную ширину ради строки, которая всё равно усечётся.
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DType.caption.copyWith(
                      color: nameColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (r.isImage)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        FluentIcons.image_24_regular,
                        size: 12,
                        color: textColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Фото',
                        style: DType.caption.copyWith(color: textColor),
                      ),
                    ])
                  else
                    Text(
                      r.text,
                      style: DType.caption.copyWith(color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // E9 jump-to-reply: tapping the quote scrolls to the original message.
    if (widget.onReplyTap == null || (r.targetPayloadId ?? '').isEmpty) {
      return quote;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onReplyTap!(r.targetPayloadId!),
        child: quote,
      ),
    );
  }

  /// U-14: delivery ticks, matching the mobile timeline exactly.
  ///
  /// The model is user-specified and deliberately count-based:
  ///   • in the send pipeline (queued / sending / retrying) → clock
  ///   • permanently failed                                 → ONE RED tick
  ///   • sent or delivered but unread                       → ONE tick
  ///   • read                                               → TWO ticks
  ///   • scheduled (deliberately deferred, not an error)    → its own glyph
  ///
  /// Count alone separates read from unread; colour is reserved for "not
  /// sent". Desktop previously diverged twice — an error circle for failed and
  /// an accent-coloured second tick for read — which made the same message
  /// look different depending on which device you opened it on.
  Widget _deliveryIcon(DeliveryStatus s, bool isSelf, DColorSet c) {
    // Ticks take the palette's indicator colour, which the «Цвета
    // индикаторов» preset drives. On our own bubble the accent would fight the
    // filled background, so there the tick stays white — same rule mobile
    // uses, and the preset still shows wherever the bubble is not accent-filled.
    final col = isSelf
        ? Colors.white.withValues(alpha: 0.85)
        : c.deliveryIndicator;
    return deliveryTickGlyph(s, col);
  }

  /// Фишки реакций — отдельной строкой ПОД пузырём, по стороне сообщения.
  /// Почему не внутри пузыря — расписано в [_bubbleStack].
  Widget _reactionsRow(DColorSet c, bool isSelf) {
    final m = widget.message;
    // Просветы 6 на 6 — телефонные: отступ сверху даёт слот, второй здесь был
    // бы двойным.
    return Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: isSelf ? WrapAlignment.end : WrapAlignment.start,
        children: m.reactions.map((r) {
          final token = _reactionTokens[r.emoji] ?? 0;
          return _ReactionChip(
            // Including the token in the key forces an internal restart of
            // the chip's pop animation when a new reactor joins.
            key: ValueKey('${m.id}|${r.emoji}|$token'),
            reaction: r,
            playToken: token,
            mine: isSelf,
            onTap: () => widget.onReactionTap?.call(r.emoji),
          );
        }).toList(),
      );
  }

  /// Строка действий при наведении: 👍 🔥 · реакция · ответить · ещё.
  ///
  /// 🔴 ДВЕ БЫСТРЫЕ РЕАКЦИИ ВЕРНУЛИСЬ (14.09.2026, по макету владельца).
  ///
  /// Здесь стоял один значок «добавить реакцию», и комментарий объяснял это
  /// тем, что ряд эмодзи, всплывающий на каждое наведение, — шум. Это верно
  /// про ШЕСТЬ эмодзи; про две самые частые — нет. В макете их ровно две, и
  /// цена ошибки разная: чтобы поставить «палец», нужно было открыть выбор,
  /// найти его глазами и нажать второй раз — три действия там, где в макете
  /// одно.
  ///
  /// Выбор никуда не делся: значок `emoji_add` рядом и открывает полный
  /// список тем же путём ([kReactionPickerSentinel]), что и раньше.
  /// Обе быстрые кнопки дёргают тот же `onReact`, что и `QuickReactionRow` в
  /// контекстном меню, — второго пути к реакции не появилось.
  Widget _hoverActions(DColorSet c, bool isSelf) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          // Своя поверхность, а не тон всплывающих карточек: строка надвинута
          // на пузырь и читается НА нём — см. [DColorSet.hoverBar].
          color: c.hoverBar,
          borderRadius: BorderRadius.circular(DRadii.md),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          boxShadow: DShadows.popover,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final e in kDesktopQuickReactions)
            _MiniEmojiBtn(
              emoji: e,
              onTap: () => widget.onReact?.call(e),
            ),
          _MiniIconBtn(
            icon: FluentIcons.emoji_add_24_regular,
            tooltip: 'Ещё реакции',
            onTap: () => widget.onReact?.call(kReactionPickerSentinel),
          ),
          Container(
            width: 1,
            height: 18,
            color: c.borderSubtle,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          _MiniIconBtn(
            icon: FluentIcons.arrow_reply_24_regular,
            tooltip: 'Ответить',
            onTap: widget.onReply,
          ),
          // Четвёртая кнопка строки — из макета, рядом с «Ответить». Её нет
          // вовсе там, где нет веток: пункт, который всегда отвечает отказом,
          // пунктом не является.
          if (widget.onContinueInTopic != null)
            Builder(
              builder: (ctx) => _MiniIconBtn(
                icon: FluentIcons.comment_multiple_24_regular,
                tooltip: 'Продолжить в теме',
                onTap: () {
                  final rb = ctx.findRenderObject() as RenderBox?;
                  final pos = rb?.localToGlobal(Offset.zero) ?? Offset.zero;
                  widget.onContinueInTopic!(pos);
                },
              ),
            ),
          Builder(builder: (ctx) {
            return _MiniIconBtn(
              icon: FluentIcons.more_horizontal_24_regular,
              tooltip: 'Ещё',
              onTap: () {
                final rb = ctx.findRenderObject() as RenderBox?;
                final pos = rb?.localToGlobal(Offset.zero) ?? Offset.zero;
                widget.onMoreActions?.call(pos);
              },
            );
          }),
        ]),
      ),
    );
  }

  /// Имя автора и, если роль того стоит, короткая метка роли.
  ///
  /// Одним виджетом на все восемь видов пузыря: имя рисовалось в восьми
  /// местах одинаковым `Text`, и добавить рядом что-либо значило повторить это
  /// восемь раз — а потом восемь раз не забыть при следующей правке.
  Widget _authorLine(DColorSet c) {
    final color = _authorColor(c);
    final chip = _roleChipLabel(widget.message.authorRole);
    final name = Text(
      widget.message.authorName,
      style: DType.label.copyWith(color: color, fontWeight: FontWeight.w700),
    );
    if (chip == null) return name;
    // 🔴 МЕТКА РОЛИ — У ПРАВОГО КРАЯ, «ТАБЛЕТКОЙ» БЕЗ РАМКИ (16.09.2026,
    // скриншот телеграма от владельца).
    //
    // Раньше это была фишка в рамке сразу за именем. В телеграме «админ»
    // стоит в противоположном углу той же строки — на бледной подложке своего
    // цвета, без обводки: отвечает на вопрос, который задают редко, и не
    // спорит с именем, которое читают всегда.
    //
    // Цвет — цвет АВТОРА, как на телефоне (`_GroupAuthorInlineHeader` пишет
    // роль тем же цветом, что имя): метка принадлежит человеку, а не висит
    // отдельным знаком.
    //
    // Растягивается строка за счёт [IntrinsicWidth] у колонки пузыря: без
    // него `MainAxisSize.max` раздул бы пузырь до предела.
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(child: name),
        const SizedBox(width: DSpace.s),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            chip,
            style: DType.caption.copyWith(
              fontSize: 11,
              height: 14 / 11,
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Цвет имени автора — ПО ЧЕЛОВЕКУ, как на телефоне и в телеграме.
  ///
  /// 🔴 РАНЬШЕ ЦВЕТ ЗАВИСЕЛ ОТ РОЛИ (16.09.2026, скриншот телеграма от
  /// владельца). Владелец был янтарным, все админы — одинаково сиреневыми. В
  /// комнате с тремя админами их имена переставали различаться между собой, а
  /// различать людей — ровно то, для чего цвет имени и существует. В
  /// телеграме цвет закреплён за человеком, роль говорится словом рядом.
  ///
  /// Ключ — тот же, что у телефона (устройство отправителя, см.
  /// [MessageData.authorSeed]): один и тот же человек обязан быть одного цвета
  /// на обоих устройствах. Если ключа нет, считаем по имени — так делает и
  /// телефон.
  Color _authorColor(DColorSet c) {
    final m = widget.message;
    final seed = (m.authorSeed ?? '').trim();
    return AvatarInitials.nicknameColor(
      seed: seed.isNotEmpty ? seed : m.authorName,
    );
  }

  /// Короткая метка роли рядом с именем — только у тех, чья роль МЕНЯЕТ вес
  /// сказанного: владелец и администраторы. Чип у каждого второго превращается
  /// в шум и перестаёт что-либо значить.
  static String? _roleChipLabel(String? role) {
    switch ((role ?? '').trim()) {
      // Строчными, как в телеграме: прописные читаются как крик, а роль
      // сообщают, а не выкрикивают.
      case 'owner':
        return 'владелец';
      case 'admin':
        return 'админ';
      case 'moderator':
        return 'модер';
      default:
        return null;
    }
  }
}

/// Две реакции, до которых в макете можно дотянуться одним нажатием.
///
/// 🔴 Список короткий НАМЕРЕННО. Полный набор живёт в
/// `roomSelectedReactionEmojis` и открывается значком «ещё» рядом; эти две —
/// то, что в макете нарисовано прямо в строке наведения. Держать их здесь, а
/// не брать первые два элемента общего списка, — чтобы перестановка в общем
/// списке не меняла молча кнопки под пальцем.
const List<String> kDesktopQuickReactions = <String>['👍', '🔥'];

/// Кнопка-эмодзи в строке наведения — та же геометрия, что у [_MiniIconBtn],
/// чтобы ряд не прыгал по высоте.
class _MiniEmojiBtn extends StatefulWidget {
  const _MiniEmojiBtn({required this.emoji, this.onTap});
  final String emoji;
  final VoidCallback? onTap;
  @override
  State<_MiniEmojiBtn> createState() => _MiniEmojiBtnState();
}

class _MiniEmojiBtnState extends State<_MiniEmojiBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _h ? c.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(DRadii.r8),
          ),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 13)),
        ),
      ),
    );
  }
}

/// Строка под кадром: «installs_aug.png · 820 КБ» и значок скачивания.
///
/// Сам размер считает общая [formatAttachmentSize]: ту же строку показывает
/// выдача поиска по файлам, и разъехаться им нельзя.
String _fmtBytes(int n) => formatAttachmentSize(n);

class _MiniIconBtn extends StatefulWidget {
  const _MiniIconBtn({required this.icon, this.tooltip, this.onTap});
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;
  @override
  State<_MiniIconBtn> createState() => _MiniIconBtnState();
}

class _MiniIconBtnState extends State<_MiniIconBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          // 26×26 радиусом 8 — из макета. Пилюля здесь читалась как ряд
          // отдельных кружков, а это одна панель.
          width: 26, height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: _h ? c.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(DRadii.r8),
          ),
          child: Icon(widget.icon, size: 16, color: c.textPrimary),
        ),
      ),
    );
    if (widget.tooltip == null) return btn;
    return Tooltip(message: widget.tooltip!, child: btn);
  }
}

/// Pill-shaped reaction chip with a pop-in scale animation. The animation
/// fires on first mount AND whenever [playToken] changes — the parent
/// bumps the token when a new reactor joins so existing chips re-bounce.
class _ReactionChip extends StatefulWidget {
  const _ReactionChip({
    super.key,
    required this.reaction,
    required this.playToken,
    required this.onTap,
    required this.mine,
  });

  final MessageReaction reaction;
  final int playToken;
  final VoidCallback onTap;

  /// Лежит ли фишка поверх своего пузыря с заливкой. От этого зависит только
  /// цвет: на заливке тёмная подложка темы читается как дыра.
  /// Своё сообщение — фишка берёт цвета из макета для своей стороны.
  final bool mine;

  @override
  State<_ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<_ReactionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  int _lastToken = -1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
    ]).animate(_ctrl);
    _lastToken = widget.playToken;
    if (widget.playToken > 0) {
      // Run-from-zero so the chip animates in even on first attach when
      // the host preloads reactions (e.g. reopening a chat that already
      // has reactions). Skipped when token is 0 (no animation has been
      // requested yet) so we don't pulse every chip on app launch.
      _ctrl.forward(from: 0.0);
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _ReactionChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playToken != _lastToken) {
      _lastToken = widget.playToken;
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final r = widget.reaction;
    // 🔴 ФИШКА СНОВА ЛЕЖИТ НА ПУЗЫРЕ, ПОЭТОМУ ЦВЕТА СНОВА ДВА НАБОРА.
    //
    // 16.09.2026 реакции вернулись ВНУТРЬ пузыря — как на телефоне, по прямому
    // указанию владельца. Значит под своей фишкой опять живой переход от
    // синего к фиолетовому, а под чужой — ровный тон чужого пузыря. Один
    // набор цветов на обе подложки читаться не может: то, что видно на тёмном
    // тоне, на заливке превращается в грязь, и наоборот.
    //
    // На СВОЁМ пузыре фишка белая на просвет: это единственный цвет, который
    // читается на любом участке перехода, каким бы его ни выбрали в темах.
    // На ЧУЖОМ — оттенок выбранного цвета, как на телефоне, где фишка красится
    // цветом индикаторов.
    //
    // Своя РЕАКЦИЯ (`byMe`) поверх этого добавляет насыщенности: ею отвечают
    // на вопрос «я уже ставил?», не читая портретов.
    final Color bg;
    final Color fg;
    final Color border;
    if (widget.mine) {
      bg = Colors.white.withValues(alpha: r.byMe ? 0.30 : 0.18);
      fg = Colors.white;
      border = Colors.white.withValues(alpha: r.byMe ? 0.55 : 0.30);
    } else {
      bg = c.accentPrimary.withValues(alpha: r.byMe ? 0.32 : 0.20);
      fg = r.byMe ? const Color(0xFFCFE2FF) : const Color(0xFFB9C6D6);
      border = c.accentPrimary.withValues(alpha: r.byMe ? 0.66 : 0.40);
    }
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          // · ГЕОМЕТРИЯ ФИШКИ — ТЕЛЕГРАМНАЯ (6 2 6 2, радиус 10).
          //
          // Жалоба владельца 16.09.2026: «реакции слишком большие». Так и
          // было: 18-й знак и поля 7×3 давали фишку в 24 точки высоты — она
          // спорила с самим текстом сообщения, рядом с которым стоит. В
          // телеграме фишка заметно мельче текста: знак 15-й, поля 6×2, весь
          // рост около 20.
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 15,
                height: 15,
                child: Center(
                  // 🔴 НЕ `looping` — это вечный цикл кадров.
                  //
                  // Зацикленная анимация заказывает кадр каждый вsync, и пока
                  // чат открыт, приложение не простаивает НИКОГДА: одна фишка
                  // реакции держит весь экран в непрерывной перерисовке.
                  // Мобильная версия за это уже заплатила — «NOT repeat()
                  // (31.07.2026, нагрев iOS)» и «каждая реакция проигрывается
                  // ровно один раз, и только пока видна на экране».
                  //
                  // `once` даёт то же самое ощущение: фишка оживает, когда
                  // реакция появилась или когда к ней присоединился ещё один
                  // человек — ключ виджета включает [playToken], поэтому такой
                  // случай перезапускает проигрывание сам. После этого она
                  // замирает на первом кадре и ничего не стоит.
                  child: isAnimatableNotoEmoji(r.emoji)
                      ? NotoEmojiLottie(
                          emoji: r.emoji,
                          size: 15,
                          mode: NotoLottieMode.once,
                        )
                      : Text(r.emoji, style: const TextStyle(fontSize: 12)),
                ),
              ),
              // · КТО ПОСТАВИЛ — ПОРТРЕТАМИ, КАК НА ТЕЛЕФОНЕ.
              //
              // Полоска показывается, пока людей немного: дальше портреты
              // перестают что-либо различать и превращаются в кашу, и число
              // говорит больше. Порог тот же, что на телефоне, — пять.
              if (r.actors.isNotEmpty && r.actors.length <= 5) ...[
                const SizedBox(width: 4),
                _ReactionAvatarStrip(actors: r.actors, onFill: widget.mine),
              ],
              // Одинокая реакция показывает только эмодзи: число зарабатывает
              // себе место, лишь когда присоединился кто-то ещё.
              if (r.count > 1) ...[
                const SizedBox(width: 4),
                Text(
                  '${r.count}',
                  style: DType.tiny.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// До трёх портретов тех, кто поставил эту реакцию, внахлёст.
///
/// Телеграмный размер: радиус 6, шаг 8, не больше трёх. Четвёртый и дальше
/// читаются числом рядом.
///
/// 🔴 МЕЛЬЧЕ, ЧЕМ НА ТЕЛЕФОНЕ (16.09.2026). На телефоне портрет в фишке — 14
/// точек, и там это уместно: палец и экран ближе к глазам. В окне фишка стоит
/// вплотную к тексту сообщения, и портрет в 14 точек делал её выше строки.
class _ReactionAvatarStrip extends StatelessWidget {
  const _ReactionAvatarStrip({required this.actors, required this.onFill});

  final List<ReactionActor> actors;

  /// Лежит ли фишка на своём залитом пузыре — от этого зависит только цвет
  /// ободка, которым портреты отделяются друг от друга.
  final bool onFill;

  @override
  Widget build(BuildContext context) {
    final visible = actors.take(3).toList(growable: false);
    final width = 12 + (visible.length - 1) * 8;
    return SizedBox(
      width: width.toDouble(),
      height: 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * 8.0,
              child: _ReactionAvatar(actor: visible[i], onFill: onFill),
            ),
        ],
      ),
    );
  }
}

class _ReactionAvatar extends StatelessWidget {
  const _ReactionAvatar({required this.actor, required this.onFill});

  final ReactionActor actor;
  final bool onFill;

  @override
  Widget build(BuildContext context) {
    final path = (actor.avatarPath ?? '').trim();
    final name = (actor.name ?? '').trim();
    // Ключ цвета — профиль, как у [Avatar] этого человека; по имени он выходил
    // в реакции другого цвета, чем в списке (17.09.2026, и так же на телефоне).
    final pid = actor.profileId.trim();
    final seed = pid.isNotEmpty ? pid : (name.isEmpty ? 'reaction' : name);
    // Ободок отделяет соседние портреты друг от друга: без него внахлёст они
    // сливаются в одно пятно.
    final ring = Border.all(
      color: onFill
          ? Colors.white.withValues(alpha: 0.55)
          : DColors.of(context).bubblePeer,
      width: 1,
    );
    final hasPhoto = path.isNotEmpty && File(path).existsSync();
    if (hasPhoto) {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: ring,
          image: DecorationImage(
            image: FileImage(File(path)),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return AvatarInitials.fallbackBubble(
      context: context,
      radius: 6,
      seed: seed,
      displayName: name,
      fallbackId: actor.profileId,
      border: ring,
      labelStyle: const TextStyle(fontSize: 6, height: 1),
      // Фон окна, а не тема Material: так заливка совпадает с [Avatar].
      background: DColors.of(context).bg,
    );
  }
}

/// Bubble-free animated emoji "message" — tap replays the Lottie animation
/// from frame 0 (matches mobile's `_SoloEmojiMessage` tap-to-replay).
class _SoloEmojiPlayer extends StatefulWidget {
  const _SoloEmojiPlayer({required this.emoji});
  final String emoji;

  @override
  State<_SoloEmojiPlayer> createState() => _SoloEmojiPlayerState();
}

class _SoloEmojiPlayerState extends State<_SoloEmojiPlayer> {
  int _replayKey = 0;

  void _replay() => setState(() => _replayKey++);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _replay,
      child: NotoEmojiLottie(
        key: ValueKey('${widget.emoji}#$_replayKey'),
        emoji: widget.emoji,
        size: 144,
        mode: NotoLottieMode.once,
      ),
    );
  }
}

/// Translucent rounded pill overlaid on the bottom-right of an image
/// bubble — carries the time + (for self messages) the delivery icon, so
/// the photo itself can bleed edge-to-edge. Matches Telegram's photo meta
/// rendering: the pill is dark with white text regardless of theme so it
/// stays legible on any photo content.
class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.time,
    required this.edited,
    required this.isSelf,
    required this.delivery,
  });

  final String time;
  final bool edited;
  final bool isSelf;
  final DeliveryStatus delivery;

  @override
  Widget build(BuildContext context) {
    const fg = Color(0xFFFFFFFF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(DRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Тот же порядок, что в подвале пузыря: время, потом «изменено».
          Text(
            time,
            style: const TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (edited) ...[
            const SizedBox(width: 6),
            const Text(
              'изменено',
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (isSelf) ...[
            const SizedBox(width: 4),
            _deliveryIconLight(delivery),
          ],
        ],
      ),
    );
  }

  /// Same U-14 tick model as [_deliveryIcon], on the light-on-media variant.
  /// Delegates so the two can never drift apart again.
  Widget _deliveryIconLight(DeliveryStatus s) {
    return deliveryTickGlyph(s, const Color(0xFFFFFFFF));
  }
}

/// 36 px round play/pause button used inside the voice bubble. Swaps to
/// a small spinner while the shared player is loading THIS track (decoded
/// from disk + decrypting, or fetching from relay).
class _VoicePlayButton extends StatefulWidget {
  const _VoicePlayButton({
    required this.isPlaying,
    required this.isLoading,
    required this.background,
    required this.iconColor,
    required this.onTap,
  });

  final bool isPlaying;
  final bool isLoading;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  State<_VoicePlayButton> createState() => _VoicePlayButtonState();
}

class _VoicePlayButtonState extends State<_VoicePlayButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.08 : 1.0,
          duration: DMotion.fast,
          curve: DMotion.easeOutBack,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.background,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: widget.isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(widget.iconColor),
                    ),
                  )
                : Icon(
                    widget.isPlaying
                        ? FluentIcons.pause_24_filled
                        : FluentIcons.play_24_filled,
                    color: widget.iconColor,
                    size: 18,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Thin horizontal progress bar for voice notes. Background line + a fill
/// strip whose width is the current playback fraction. We don't render a
/// waveform on desktop (yet) — a flat bar is enough to communicate
/// progress and is dramatically cheaper than the mobile per-sample
/// waveform.
/// Волна голосового — столбики, как в макете и как на телефоне.
///
/// 🔴 Была ровная полоска в четыре точки. Полоска сообщает ровно одно —
/// «сколько проиграно», — и ничем не отличается от полоски загрузки файла. По
/// волне же видно, ГДЕ в записи говорили, а где пауза: именно так люди ищут
/// нужное место в чужом голосовом, не переслушивая целиком.
///
/// Столбиков 14 (из макета) независимо от длины записи: огибающая приходит
/// произвольной длины, и её приходится сводить к постоянному числу — иначе
/// короткое голосовое рисовало бы три толстых столба, а длинное — сто
/// волосков.
///
/// Нажатие перематывает: волна занимает всю ширину пузыря и сама просится,
/// чтобы по ней ткнули.
class _VoiceProgressBar extends StatelessWidget {
  const _VoiceProgressBar({
    required this.progress,
    required this.background,
    required this.fill,
    this.waveform,
    this.onSeek,
  });

  /// Normalised 0..1 playback progress. Out-of-range values clamp.
  final double progress;
  final Color background;
  final Color fill;

  /// Огибающая громкости 0..100 произвольной длины; `null` — ровный узор.
  final List<int>? waveform;

  /// Перемотка: доля 0..1. `null` — волна просто рисуется.
  final ValueChanged<double>? onSeek;

  static const int _bars = 14;
  static const double _height = 26;

  /// Сводит огибающую любой длины к [_bars] столбикам. См.
  /// [voiceWaveformBars] — считает там, чтобы это можно было проверить без
  /// отрисовки пузыря.
  static List<double> bars(List<int>? raw) => voiceWaveformBars(raw);


  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final heights = bars(waveform);
    final wave = SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 160.0;
          final played = (p * _bars).floor();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < _bars; i++) ...[
                if (i > 0) const SizedBox(width: 2.5),
                Expanded(
                  child: Container(
                    height: (_height * heights[i]).clamp(3.0, _height),
                    decoration: BoxDecoration(
                      color: i < played ? fill : background,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
              // Ширина нужна только для перемотки; сама волна тянется сама.
              if (w.isNaN) const SizedBox.shrink(),
            ],
          );
        },
      ),
    );
    final seek = onSeek;
    if (seek == null) return wave;
    return LayoutBuilder(
      builder: (ctx, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          final w = constraints.maxWidth;
          if (w <= 0) return;
          seek((d.localPosition.dx / w).clamp(0.0, 1.0));
        },
        child: wave,
      ),
    );
  }
}

/// Сводит огибающую громкости любой длины к 14 столбикам макета усреднением.
///
/// 🔴 Постоянное число столбиков — не прихоть: огибающая приходит произвольной
/// длины, и рисовать её «как есть» значит показывать у короткого голосового
/// три толстых столба, а у длинного — сотню волосков. Четырнадцать — из
/// макета.
///
/// Пустая огибающая даёт спокойный симметричный узор: он честно говорит
/// «данных о громкости нет», а не притворяется записью. Пол в 0,12 нужен
/// затем, что нулевой столбик читается как дыра в волне, тогда как тишина в
/// середине записи — это тишина, а не обрыв.
List<double> voiceWaveformBars(List<int>? raw) {
  const bars = 14;
  final src = raw ?? const <int>[];
  if (src.isEmpty) {
    return List<double>.generate(
      bars,
      (i) => 0.35 + 0.3 * (1 - (2 * i / (bars - 1) - 1).abs()),
    );
  }
  final out = <double>[];
  for (var i = 0; i < bars; i++) {
    final from = (src.length * i) ~/ bars;
    final to = (src.length * (i + 1)) ~/ bars;
    final hi = to > from ? to : from + 1;
    var sum = 0;
    var n = 0;
    for (var j = from; j < hi && j < src.length; j++) {
      sum += src[j];
      n++;
    }
    final avg = n == 0 ? 0.0 : sum / n / 100.0;
    out.add(avg.clamp(0.12, 1.0));
  }
  return out;
}

/// Следующая скорость по кругу: 1× → 1.5× → 2× → 1×.
///
/// Три ступени, а не плавный ползунок: скорость выбирают на слух и одним
/// нажатием, а ползунок в пузыре требовал бы прицеливания мышью.
double _nextVoiceSpeed(double current) {
  if (current < 1.25) return 1.5;
  if (current < 1.75) return 2.0;
  return 1.0;
}

/// Подпись скорости у голосового: «1×», «1.5×», «2×».
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.speed,
    required this.color,
    required this.onTap,
  });

  final double speed;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    // «1.5», а не «1.50»: лишний ноль в подписи шириной в три знака заметен.
    final label = speed == speed.roundToDouble()
        ? '${speed.toInt()}×'
        : '${speed.toStringAsFixed(1)}×';
    return DesktopTooltip(
      message: 'Скорость воспроизведения',
      child: HoverListener(
        onTap: onTap,
        cursor: SystemMouseCursors.click,
        builder: (ctx, hovered, pressed) => Container(
          height: 20,
          constraints: const BoxConstraints(minWidth: 30),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovered ? c.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(DRadii.r8),
          ),
          child: Text(
            label,
            style: DType.mono.copyWith(fontSize: 10, color: color),
          ),
        ),
      ),
    );
  }
}
