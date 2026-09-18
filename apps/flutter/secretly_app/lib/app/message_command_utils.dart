// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

const String kSecretlyHiddenCommandPrefix = '__secretly_';
const String kDeleteForAllCommandPrefix = '__secretly_delete__:';
const String kEditMessageCommandPrefix = '__secretly_edit_v1__:';
// Self-mirror control prefixes (TZ §21.1 — multi-device sender fan-out).
//
// When the user sends an attachment / sticker / reaction from device A, the
// app *also* posts a self-mirror control message to all of the user's OTHER
// registered devices using these prefixes. The mirror travels over the same
// E2E ratchet as a regular control message — but the recipient end (which is
// always one of the user's own devices) detects the prefix and reconstructs a
// local event as if the message had been received from the peer.
//
// Naming convention matches `__secretly_self_mirror_msg_v1__:` which already
// exists in `app_controller.dart` for plain-text mirror. Using the same
// `__secretly_self_mirror_*_v1__:` family keeps version negotiation simple:
// older builds that don't recognize a prefix treat the carrier message as
// hidden control (via `isHiddenMessageControlText`) and skip it — no crashes,
// no UI corruption, just "feature not yet on this device".
const String kSelfMirrorAttachmentCommandPrefix =
    '__secretly_self_mirror_att_v1__:';
const String kSelfMirrorStickerCommandPrefix =
    '__secretly_self_mirror_sticker_v1__:';
const String kSelfMirrorReactionCommandPrefix =
    '__secretly_self_mirror_reaction_v1__:';
// 2026-05-20 PR-B (BUG-10): the existing self-mirror family covered msg /
// attachment / sticker / reaction / edit, but **read-receipts** had no
// equivalent. Effect: peer reads my mobile-sent message → mobile flips its
// own row to `read` (✓✓), but my desktop never finds out. New prefix
// carries a list of payload-event-ids + status the receiving own-device
// should bump locally. Same `__secretly_self_mirror_*_v1__:` family so
// older builds harmlessly skip via `isHiddenMessageControlText`.
const String kSelfMirrorReceiptCommandPrefix =
    '__secretly_self_mirror_receipt_v1__:';
// 2026-09-08: the receipt mirror above carries ONE direction — "the peer read
// my outgoing message", so the ✓✓ matches on all my devices. The opposite
// direction had nothing at all: reading a chat on the phone marked rows read
// LOCALLY and told the peer, but never told my own other devices, so every
// device counted as unread whatever it had received and nobody had opened ON
// IT. Reported from a live account: "десктоп показывает кучу непрочитанных,
// хотя я прочитал их на телефоне".
//
// Carries a WATERMARK, not a list of ids: local row ids differ per device, and
// a per-message list would go stale the moment one mirror is lost. "Everything
// in convo X at or before sender-timestamp T is read" is idempotent, survives a
// dropped delivery (the next watermark covers the gap), and stays one small
// payload no matter how many messages were read.
//
// The timestamp is the EVENT's `created_at_ms` — assigned by the sender and
// identical on every device — never the reader's wall clock, which would drift
// between devices and mark too much or too little.
const String kSelfMirrorReadCommandPrefix =
    '__secretly_self_mirror_read_v1__:';

// 2026-09-08: per-conversation state — mute, pin, archive, personal, the
// disappearing-message timer — was written to the local database and nowhere
// else. Muting a chat on the phone left it unmuted on the desktop forever.
//
// ONE command for all five rather than five prefixes: they are set from the
// same screens, they mean nothing apart from each other, and five prefixes
// would be five places to forget the sixth field.
//
// Every field is OPTIONAL and only the ones present are applied. That is what
// makes it a patch instead of a snapshot: a mirror that carried the whole
// state would overwrite a field the sending device happened to know nothing
// about.
const String kSelfMirrorConvoStateCommandPrefix =
    '__secretly_self_mirror_convo_v1__:';

// 2026-09-08: custom chat folders live ONLY in the local database — there is
// no server copy to fall back on, unlike the nickname (keys server) or the
// blocked list (relay). A folder made on the phone therefore never existed on
// the desktop at all.
//
// Carries the whole folder — id, name, emoji and its full membership — rather
// than a delta, because a folder IS its membership: "chat X was added" makes no
// sense to a device that never heard of the folder. Deletion is the one case
// with no body, marked by `deleted`.
const String kSelfMirrorFolderCommandPrefix =
    '__secretly_self_mirror_folder_v1__:';
// AUD-2026-04-25 D1: hidden control message that the QR scanner sends to the
// scanned peer so the peer auto-adds the scanner as a regular contact instead
// of routing the first inbound message into the request inbox. The token
// payload is informational only — authenticity comes from the surrounding
// E2E ratchet (the message decrypts only with the sender device's identity
// material that the keys server vouches for), so we never trust the token
// alone for sensitive decisions.
const String kQrPairingIntroductionCommandPrefix = '__secretly_qr_pair__:';

// ── Polls (room feature) ──────────────────────────────────────────────────
// A poll is carried as a normal group message whose text is the poll spec
// command. Unlike most `__secretly_*` control texts it is NOT hidden — the
// chat renders it as an interactive poll card (see `isHiddenMessageControlText`
// which excludes this prefix, mirroring delete-for-all).
//
// Votes are carried as a SEPARATE hidden control message (`*_vote_*`). Each
// vote message reports the voter's profile id + chosen option indices; the
// timeline tallies the latest vote per voter per poll from the events it
// already holds — so no extra DB table or receive handler is needed (same
// derive-from-events model delete-for-all uses).
const String kPollCommandPrefix = '__secretly_poll_v1__:';
const String kPollVoteCommandPrefix = '__secretly_poll_vote_v1__:';
const String kPollCloseCommandPrefix = '__secretly_poll_close_v1__:';

class PollCommand {
  const PollCommand({
    required this.pollId,
    required this.question,
    required this.options,
    required this.multiple,
    required this.anonymous,
  });

  final String pollId;
  final String question;
  final List<String> options;
  final bool multiple;
  final bool anonymous;
}

String buildPollCommand({
  required String pollId,
  required String question,
  required List<String> options,
  required bool multiple,
  required bool anonymous,
}) {
  final payload = <String, Object?>{
    'v': 1,
    'pollId': pollId.trim(),
    'q': question,
    'opts': options,
    'multi': multiple,
    'anon': anonymous,
  };
  return '$kPollCommandPrefix${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

bool isPollCommandText(String text) =>
    text.trimLeft().startsWith(kPollCommandPrefix);

PollCommand? parsePollCommand(String text) {
  final normalized = text.trimLeft();
  if (!normalized.startsWith(kPollCommandPrefix)) return null;
  final raw = normalized.substring(kPollCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final pollId = (json['pollId'] as String?)?.trim() ?? '';
    final question = (json['q'] as String?) ?? '';
    final options = ((json['opts'] as List?) ?? const <Object?>[])
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (pollId.isEmpty || options.length < 2) return null;
    return PollCommand(
      pollId: pollId,
      question: question,
      options: options,
      multiple: (json['multi'] as bool?) ?? false,
      anonymous: (json['anon'] as bool?) ?? false,
    );
  } catch (_) {
    return null;
  }
}

// ── Pinned-message sync (room feature) ────────────────────────────────────
// When a member with pin rights pins/unpins, they broadcast the FULL pin set
// as a hidden control message. Every member derives the shared pin list from
// the most-recent pin-sync command in the conversation (latest-wins, same
// derive-from-events model as poll votes / delete-for-all). Hidden via the
// generic `__secretly_` rule so it never shows as a message.
const String kPinSyncCommandPrefix = '__secretly_pin_v1__:';

class PinnedRef {
  const PinnedRef({
    required this.eventId,
    this.previewText = '',
    this.pinnedAtMs = 0,
  });

  final String eventId;
  final String previewText;
  final int pinnedAtMs;
}

class PinSyncCommand {
  const PinSyncCommand({required this.pins});
  final List<PinnedRef> pins;
}

String buildPinSyncCommand(List<PinnedRef> pins) {
  final payload = <String, Object?>{
    'v': 1,
    'pins': pins
        .where((pin) => pin.eventId.trim().isNotEmpty)
        .map(
          (pin) => <String, Object?>{
            'eventId': pin.eventId.trim(),
            if (pin.previewText.trim().isNotEmpty)
              'previewText': pin.previewText.trim(),
            'pinnedAtMs': pin.pinnedAtMs,
          },
        )
        .toList(growable: false),
  };
  return '$kPinSyncCommandPrefix${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

bool isPinSyncCommandText(String text) =>
    text.trimLeft().startsWith(kPinSyncCommandPrefix);

PinSyncCommand? parsePinSyncCommand(String text) {
  final normalized = text.trimLeft();
  if (!normalized.startsWith(kPinSyncCommandPrefix)) return null;
  final raw = normalized.substring(kPinSyncCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final pins = ((json['pins'] as List?) ?? const <Object?>[])
        .whereType<Map>()
        .map((entry) {
          final map = entry.cast<String, Object?>();
          final eventId = (map['eventId'] as String?)?.trim() ?? '';
          if (eventId.isEmpty) return null;
          final pinnedAtRaw = map['pinnedAtMs'];
          final pinnedAtMs = switch (pinnedAtRaw) {
            final int value => value,
            final num value => value.toInt(),
            final String value => int.tryParse(value) ?? 0,
            _ => 0,
          };
          return PinnedRef(
            eventId: eventId,
            previewText: (map['previewText'] as String?)?.trim() ?? '',
            pinnedAtMs: pinnedAtMs,
          );
        })
        .whereType<PinnedRef>()
        .toList(growable: false);
    return PinSyncCommand(pins: pins);
  } catch (_) {
    return null;
  }
}

// ── Topics / threads (room feature) ───────────────────────────────────────
// A room can have several topics (forum-style sub-channels). The topic LIST is
// synced room-wide via a hidden control message carrying the full set
// (latest-wins, same model as pins). Individual messages carry their `topicId`
// in the payload; the UI filters the timeline by the selected topic.
const String kTopicsSyncCommandPrefix = '__secretly_topics_v1__:';

class RoomTopicRef {
  const RoomTopicRef({
    required this.id,
    required this.title,
    this.emoji = '',
    this.mark = '',
    this.createdAtMs = 0,
  });

  final String id;
  final String title;
  final String emoji;

  /// Отличительный знак темы из общего набора — см. `ui/room_topic_marks.dart`.
  ///
  /// Пусто — только «#». Это НЕ эмодзи: знак берётся из закрытого набора, у
  /// него один вид на всех устройствах и свой цвет (звонок зелёный, «!»
  /// красный, остальные серые). Эмодзи рядом остаётся: его ставит тот, кому
  /// набора мало.
  final String mark;

  final int createdAtMs;

  RoomTopicRef copyWith({String? title, String? emoji, String? mark}) =>
      RoomTopicRef(
        id: id,
        title: title ?? this.title,
        emoji: emoji ?? this.emoji,
        mark: mark ?? this.mark,
        createdAtMs: createdAtMs,
      );
}

/// Одна тема в виде карты — общая форма для передачи по сети и для хранения.
Map<String, Object?> roomTopicToMap(RoomTopicRef topic) => <String, Object?>{
  'id': topic.id.trim(),
  'title': topic.title,
  if (topic.emoji.trim().isNotEmpty) 'emoji': topic.emoji.trim(),
  if (topic.mark.trim().isNotEmpty) 'mark': topic.mark.trim(),
  'createdAtMs': topic.createdAtMs,
};

RoomTopicRef? roomTopicFromMap(Map<String, Object?> map) {
  final id = (map['id'] as String?)?.trim() ?? '';
  final title = (map['title'] as String?)?.trim() ?? '';
  if (id.isEmpty || title.isEmpty) return null;
  final createdRaw = map['createdAtMs'];
  final createdAtMs = switch (createdRaw) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value) ?? 0,
    _ => 0,
  };
  return RoomTopicRef(
    id: id,
    title: title,
    emoji: (map['emoji'] as String?)?.trim() ?? '',
    mark: (map['mark'] as String?)?.trim() ?? '',
    createdAtMs: createdAtMs,
  );
}

/// 🔴 СПИСОК ТЕМ ХРАНИТСЯ, А НЕ ВЫЧИСЛЯЕТСЯ ИЗ ВИДИМЫХ СООБЩЕНИЙ.
///
/// До 15.09.2026 список жил ТОЛЬКО в скрытом сообщении внутри ленты, и каждое
/// устройство собирало его заново из загруженного окна (последние ~200
/// событий). Отсюда обе жалобы владельца сразу: на компьютере тем «нет»
/// (сообщение со списком не попало в окно), а в самой теме «пустой чат»
/// (сообщения с неизвестным `topic_id` уезжают в «Общий»). Через двести
/// сообщений темы пропадали у ВСЕХ.
///
/// Эти две функции — формат хранения. Тот же набор полей, что и у сообщения
/// синхронизации, поэтому принятое по сети и сохранённое на диске не могут
/// разойтись.
String encodeRoomTopicsJson(List<RoomTopicRef> topics) =>
    encodeRoomTopicsState(RoomTopicsState(topics: topics));

List<RoomTopicRef> decodeRoomTopicsJson(String raw) =>
    decodeRoomTopicsState(raw).topics;

/// 🔴 «ОСНОВА» — ТОЖЕ ТЕМА, И ЕЙ ТОЖЕ МЕНЯЮТ ЗНАЧОК (указание владельца
/// 15.09.2026).
///
/// Общий поток комнаты раньше назывался «Общий» и был исключением: без
/// решётки, без значка, переименовать нечего. Но для человека это такая же
/// ветка, просто первая, — и правило «значок перед названием» обязано
/// действовать и на неё.
///
/// Хранить её как обычную запись в списке тем нельзя: у сообщений основы нет
/// `topic_id`, и запись с выдуманным идентификатором развела бы фильтр ленты
/// и список тем. Поэтому у основы едет ровно ОДНО поле — её знак.
class RoomTopicsState {
  const RoomTopicsState({
    this.topics = const <RoomTopicRef>[],
    this.baseMark = '',
  });

  final List<RoomTopicRef> topics;

  /// Знак «Основы». Пусто — решётка.
  final String baseMark;
}

/// Хранимая форма: объект с темами и знаком основы.
///
/// Раньше это был голый список, и такие записи ещё лежат в базах. Разбор их
/// понимает: список — это темы без знака основы.
String encodeRoomTopicsState(RoomTopicsState state) => jsonEncode(
  <String, Object?>{
    'topics': state.topics
        .where((topic) => topic.id.trim().isNotEmpty)
        .map(roomTopicToMap)
        .toList(growable: false),
    if (state.baseMark.trim().isNotEmpty) 'baseMark': state.baseMark.trim(),
  },
);

RoomTopicsState decodeRoomTopicsState(String raw) {
  if (raw.trim().isEmpty) return const RoomTopicsState();
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      // Старая запись: голый список тем.
      return RoomTopicsState(topics: _topicsFromList(decoded));
    }
    if (decoded is! Map) return const RoomTopicsState();
    final json = decoded.cast<String, Object?>();
    return RoomTopicsState(
      topics: _topicsFromList((json['topics'] as List?) ?? const <Object?>[]),
      baseMark: (json['baseMark'] as String?)?.trim() ?? '',
    );
  } catch (_) {
    return const RoomTopicsState();
  }
}

List<RoomTopicRef> _topicsFromList(List<Object?> raw) => raw
    .whereType<Map>()
    .map((entry) => roomTopicFromMap(entry.cast<String, Object?>()))
    .whereType<RoomTopicRef>()
    .toList(growable: false);

class TopicsSyncCommand {
  const TopicsSyncCommand({required this.topics, this.baseMark = ''});
  final List<RoomTopicRef> topics;

  /// Знак «Основы». Пусто — решётка.
  final String baseMark;
}

String buildTopicsSyncCommand(
  List<RoomTopicRef> topics, {
  String baseMark = '',
}) {
  final payload = <String, Object?>{
    'v': 1,
    'topics': topics
        .where((topic) => topic.id.trim().isNotEmpty)
        .map(roomTopicToMap)
        .toList(growable: false),
    if (baseMark.trim().isNotEmpty) 'baseMark': baseMark.trim(),
  };
  return '$kTopicsSyncCommandPrefix${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

bool isTopicsSyncCommandText(String text) =>
    text.trimLeft().startsWith(kTopicsSyncCommandPrefix);

TopicsSyncCommand? parseTopicsSyncCommand(String text) {
  final normalized = text.trimLeft();
  if (!normalized.startsWith(kTopicsSyncCommandPrefix)) return null;
  final raw = normalized.substring(kTopicsSyncCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    // Разбор — через ту же общую форму, что и хранение: иначе поле, добавленное
    // в одном месте, молча терялось бы в другом (так чуть не случилось со
    // знаком темы).
    final topics = _topicsFromList(
      (json['topics'] as List?) ?? const <Object?>[],
    );
    return TopicsSyncCommand(
      topics: topics,
      baseMark: (json['baseMark'] as String?)?.trim() ?? '',
    );
  } catch (_) {
    return null;
  }
}

// ── Events / RSVP (room feature) ──────────────────────────────────────────
// Same model as polls: the event SPEC is a visible group message rendered as a
// card; RSVPs are hidden control messages tallied from the conversation events
// (latest-per-voter wins). Event spec is excluded from `isHiddenMessageControlText`.
const String kEventCommandPrefix = '__secretly_event_v1__:';
const String kEventRsvpCommandPrefix = '__secretly_event_rsvp_v1__:';

class EventCommand {
  const EventCommand({
    required this.eventId,
    required this.title,
    required this.startMs,
    this.description = '',
    this.location = '',
  });

  final String eventId;
  final String title;
  final int startMs;
  final String description;
  final String location;
}

String buildEventCommand({
  required String eventId,
  required String title,
  required int startMs,
  String description = '',
  String location = '',
}) {
  final payload = <String, Object?>{
    'v': 1,
    'eventId': eventId.trim(),
    'title': title,
    'startMs': startMs,
    if (description.trim().isNotEmpty) 'desc': description.trim(),
    if (location.trim().isNotEmpty) 'loc': location.trim(),
  };
  return '$kEventCommandPrefix${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

bool isEventCommandText(String text) =>
    text.trimLeft().startsWith(kEventCommandPrefix);

EventCommand? parseEventCommand(String text) {
  final normalized = text.trimLeft();
  if (!normalized.startsWith(kEventCommandPrefix)) return null;
  final raw = normalized.substring(kEventCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final eventId = (json['eventId'] as String?)?.trim() ?? '';
    final title = (json['title'] as String?)?.trim() ?? '';
    if (eventId.isEmpty || title.isEmpty) return null;
    final startRaw = json['startMs'];
    final startMs = switch (startRaw) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    return EventCommand(
      eventId: eventId,
      title: title,
      startMs: startMs,
      description: (json['desc'] as String?)?.trim() ?? '',
      location: (json['loc'] as String?)?.trim() ?? '',
    );
  } catch (_) {
    return null;
  }
}

class EventRsvpCommand {
  const EventRsvpCommand({
    required this.eventId,
    required this.status,
    required this.voterProfileId,
    this.voterName,
  });

  /// 'going' | 'maybe' | 'no'
  final String status;
  final String eventId;
  final String voterProfileId;
  final String? voterName;
}

String buildEventRsvpCommand({
  required String eventId,
  required String status,
  required String voterProfileId,
  String? voterName,
}) {
  final payload = <String, Object?>{
    'v': 1,
    'eventId': eventId.trim(),
    'status': status.trim(),
    'voter': voterProfileId.trim(),
    if (voterName != null && voterName.trim().isNotEmpty)
      'name': voterName.trim(),
  };
  return '$kEventRsvpCommandPrefix${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

bool isEventRsvpCommandText(String text) =>
    text.trimLeft().startsWith(kEventRsvpCommandPrefix);

EventRsvpCommand? parseEventRsvpCommand(String text) {
  final normalized = text.trimLeft();
  if (!normalized.startsWith(kEventRsvpCommandPrefix)) return null;
  final raw = normalized.substring(kEventRsvpCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final eventId = (json['eventId'] as String?)?.trim() ?? '';
    final voter = (json['voter'] as String?)?.trim() ?? '';
    final status = (json['status'] as String?)?.trim() ?? '';
    if (eventId.isEmpty ||
        voter.isEmpty ||
        (status != 'going' && status != 'maybe' && status != 'no')) {
      return null;
    }
    return EventRsvpCommand(
      eventId: eventId,
      status: status,
      voterProfileId: voter,
      voterName: (json['name'] as String?)?.trim(),
    );
  } catch (_) {
    return null;
  }
}

// ── Forwarded message ─────────────────────────────────────────────────────
// A forwarded text message is carried as a visible command so the bubble can
// render a proper «Переслано от <name>» header above the original text (instead
// of a flat 3-line string). Excluded from `isHiddenMessageControlText`.
const String kForwardCommandPrefix = '__secretly_fwd_v1__:';

class ForwardCommand {
  const ForwardCommand({
    required this.authorName,
    required this.text,
    this.authorProfileId,
    this.sourceConvoId,
  });
  final String authorName;
  final String text;

  /// Profile id of the original author, when known. Lets the receiver render
  /// the author's avatar and tap-through to the source chat. Optional for
  /// back-compat with older senders.
  final String? authorProfileId;

  /// Conversation id the message was forwarded FROM (the forwarder's local
  /// chat where the original lives). Only meaningful on the forwarder's own
  /// devices — used so tapping "Переслано от вы" jumps to the chat that holds
  /// the original message. Optional for back-compat.
  final String? sourceConvoId;
}

String buildForwardCommand({
  required String authorName,
  required String text,
  String? authorProfileId,
  String? sourceConvoId,
}) {
  final payload = <String, Object?>{
    'v': 1,
    'from': authorName,
    'text': text,
    if (authorProfileId != null && authorProfileId.trim().isNotEmpty)
      'pid': authorProfileId.trim(),
    if (sourceConvoId != null && sourceConvoId.trim().isNotEmpty)
      'cid': sourceConvoId.trim(),
  };
  return '$kForwardCommandPrefix${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

bool isForwardCommandText(String text) =>
    text.trimLeft().startsWith(kForwardCommandPrefix);

ForwardCommand? parseForwardCommand(String text) {
  final normalized = text.trimLeft();
  if (!normalized.startsWith(kForwardCommandPrefix)) return null;
  final raw = normalized.substring(kForwardCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final pid = (json['pid'] as String?)?.trim();
    final cid = (json['cid'] as String?)?.trim();
    return ForwardCommand(
      authorName: (json['from'] as String?)?.trim() ?? '',
      text: (json['text'] as String?) ?? '',
      authorProfileId: (pid != null && pid.isNotEmpty) ? pid : null,
      sourceConvoId: (cid != null && cid.isNotEmpty) ? cid : null,
    );
  } catch (_) {
    return null;
  }
}

class PollVoteCommand {
  const PollVoteCommand({
    required this.pollId,
    required this.optionIndices,
    required this.voterProfileId,
    this.voterName,
  });

  final String pollId;
  final List<int> optionIndices;
  final String voterProfileId;
  final String? voterName;
}

String buildPollVoteCommand({
  required String pollId,
  required List<int> optionIndices,
  required String voterProfileId,
  String? voterName,
}) {
  final payload = <String, Object?>{
    'v': 1,
    'pollId': pollId.trim(),
    'opts': optionIndices,
    'voter': voterProfileId.trim(),
    if (voterName != null && voterName.trim().isNotEmpty)
      'name': voterName.trim(),
  };
  return '$kPollVoteCommandPrefix${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

bool isPollVoteCommandText(String text) =>
    text.trimLeft().startsWith(kPollVoteCommandPrefix);

PollVoteCommand? parsePollVoteCommand(String text) {
  final normalized = text.trimLeft();
  if (!normalized.startsWith(kPollVoteCommandPrefix)) return null;
  final raw = normalized.substring(kPollVoteCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final pollId = (json['pollId'] as String?)?.trim() ?? '';
    final voter = (json['voter'] as String?)?.trim() ?? '';
    if (pollId.isEmpty || voter.isEmpty) return null;
    final optionIndices = ((json['opts'] as List?) ?? const <Object?>[])
        .map(
          (value) => switch (value) {
            final int v => v,
            final num v => v.toInt(),
            final String v => int.tryParse(v) ?? -1,
            _ => -1,
          },
        )
        .where((value) => value >= 0)
        .toList(growable: false);
    return PollVoteCommand(
      pollId: pollId,
      optionIndices: optionIndices,
      voterProfileId: voter,
      voterName: (json['name'] as String?)?.trim(),
    );
  } catch (_) {
    return null;
  }
}

/// Hidden control message that closes a poll to further votes. Every client
/// validates `closerProfileId` against the ORIGINAL poll spec's sender
/// before honouring it (see chat_screen.dart tally) — this mirrors the
/// existing client-derived room-policy trust model used for pins/roles,
/// there is no additional server-side enforcement.
class PollCloseCommand {
  const PollCloseCommand({
    required this.pollId,
    required this.closerProfileId,
    required this.closedAtMs,
  });

  final String pollId;
  final String closerProfileId;
  final int closedAtMs;
}

String buildPollCloseCommand({
  required String pollId,
  required String closerProfileId,
  required int closedAtMs,
}) {
  final payload = <String, Object?>{
    'v': 1,
    'pollId': pollId.trim(),
    'closer': closerProfileId.trim(),
    'closedAtMs': closedAtMs,
  };
  return '$kPollCloseCommandPrefix${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

bool isPollCloseCommandText(String text) =>
    text.trimLeft().startsWith(kPollCloseCommandPrefix);

PollCloseCommand? parsePollCloseCommand(String text) {
  final normalized = text.trimLeft();
  if (!normalized.startsWith(kPollCloseCommandPrefix)) return null;
  final raw = normalized.substring(kPollCloseCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final pollId = (json['pollId'] as String?)?.trim() ?? '';
    final closer = (json['closer'] as String?)?.trim() ?? '';
    if (pollId.isEmpty || closer.isEmpty) return null;
    final closedRaw = json['closedAtMs'];
    final closedAtMs = switch (closedRaw) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    return PollCloseCommand(
      pollId: pollId,
      closerProfileId: closer,
      closedAtMs: closedAtMs,
    );
  } catch (_) {
    return null;
  }
}

String buildDeleteForAllCommand(Iterable<String> payloadEventIds) {
  final normalizedIds = payloadEventIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  return '$kDeleteForAllCommandPrefix${normalizedIds.join(',')}';
}

bool isDeleteForAllCommandText(String text) {
  return text.startsWith(kDeleteForAllCommandPrefix);
}

List<String> parseDeleteForAllCommand(String text) {
  if (!text.startsWith(kDeleteForAllCommandPrefix)) return const [];
  final raw = text.substring(kDeleteForAllCommandPrefix.length).trim();
  if (raw.isEmpty) return const [];
  return raw
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

class EditMessageCommand {
  const EditMessageCommand({
    required this.convoId,
    required this.payloadEventId,
    required this.text,
    required this.editedAtMs,
    this.mentions = const <Map<String, Object?>>[],
  });

  final String convoId;
  final String payloadEventId;
  final String text;
  final int editedAtMs;
  final List<Map<String, Object?>> mentions;
}

String buildEditMessageCommand({
  required String convoId,
  required String payloadEventId,
  required String text,
  required int editedAtMs,
  List<Map<String, Object?>> mentions = const <Map<String, Object?>>[],
}) {
  final payload = <String, Object?>{
    'v': 1,
    'convoId': convoId.trim(),
    'payloadEventId': payloadEventId.trim(),
    'text': text,
    'editedAtMs': editedAtMs,
    if (mentions.isNotEmpty) 'mentions': mentions,
  };
  return '$kEditMessageCommandPrefix${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

EditMessageCommand? parseEditMessageCommand(String text) {
  if (!text.startsWith(kEditMessageCommandPrefix)) return null;
  final raw = text.substring(kEditMessageCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final convoId = (json['convoId'] as String?)?.trim() ?? '';
    final payloadEventId = (json['payloadEventId'] as String?)?.trim() ?? '';
    if (convoId.isEmpty || payloadEventId.isEmpty) return null;
    final editedAtRaw = json['editedAtMs'];
    final editedAtMs = switch (editedAtRaw) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    final mentions = ((json['mentions'] as List?) ?? const <Object?>[])
        .whereType<Map>()
        .map((value) => value.cast<String, Object?>())
        .toList(growable: false);
    return EditMessageCommand(
      convoId: convoId,
      payloadEventId: payloadEventId,
      text: (json['text'] as String?) ?? '',
      editedAtMs: editedAtMs,
      mentions: mentions,
    );
  } catch (_) {
    return null;
  }
}

bool isEditMessageCommandText(String text) {
  return parseEditMessageCommand(text) != null;
}

bool isHiddenMessageControlText(String text) {
  final normalized = text.trimLeft();
  if (!normalized.startsWith(kSecretlyHiddenCommandPrefix)) {
    return false;
  }
  // delete-for-all is interpreted (tombstones) and the poll SPEC renders as a
  // visible card — both must NOT be treated as hidden control noise. The poll
  // VOTE command stays hidden (handled by the generic rule below).
  if (isDeleteForAllCommandText(normalized)) return false;
  if (isPollCommandText(normalized)) return false;
  if (isEventCommandText(normalized)) return false;
  if (isForwardCommandText(normalized)) return false;
  return true;
}

/// AUD-2026-04-25 D1: build a QR pairing introduction command. The optional
/// [scannerDisplayName] is the scanner's chosen nickname so the recipient can
/// pre-populate the contact card. The pre-shared QR token (if any) is forwarded
/// for forensic/correlation purposes only and MUST NOT be treated as proof of
/// anything beyond what the E2E ratchet already establishes.
String buildQrPairingIntroductionCommand({
  String? scannerDisplayName,
  String? qrTokenB64,
}) {
  final name = (scannerDisplayName ?? '').trim();
  final token = (qrTokenB64 ?? '').trim();
  final encodedName = Uri.encodeComponent(name);
  final encodedToken = Uri.encodeComponent(token);
  return '$kQrPairingIntroductionCommandPrefix$encodedName|$encodedToken';
}

/// Returns `(scannerDisplayName, qrTokenB64)` when [text] is a QR pairing
/// introduction control text, or `null` when it is not.
({String? scannerDisplayName, String? qrTokenB64})?
parseQrPairingIntroductionCommand(String text) {
  final normalized = text.trimLeft();
  if (!normalized.startsWith(kQrPairingIntroductionCommandPrefix)) {
    return null;
  }
  final body = normalized.substring(kQrPairingIntroductionCommandPrefix.length);
  final parts = body.split('|');
  String? decodeOrNull(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final out = Uri.decodeComponent(trimmed);
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  return (
    scannerDisplayName: parts.isNotEmpty ? decodeOrNull(parts[0]) : null,
    qrTokenB64: parts.length >= 2 ? decodeOrNull(parts[1]) : null,
  );
}

bool isQrPairingIntroductionCommandText(String text) {
  return text.trimLeft().startsWith(kQrPairingIntroductionCommandPrefix);
}

// ---------------------------------------------------------------------------
// Self-mirror commands — TZ §21.1
// ---------------------------------------------------------------------------
//
// Each command is a JSON object base64Url-encoded and prefixed with the
// kSelfMirror*Prefix above. The carrier is a normal control message
// addressed to one or more of the sender's own devices.
//
// Schema rationale:
//   • All fields the receiving side needs to reconstruct a local event are
//     packed in. We don't re-derive anything on the receiver from app state
//     (which may be stale) — the mirror carries the full ground-truth blob
//     metadata, sticker id, emoji, etc.
//   • Optional fields use null/missing semantics (parser tolerates both).
//   • Lossy fields like `mime` default to `application/octet-stream` on the
//     receiver; we do NOT silently drop the carrier just because mime is
//     missing.
//   • All numeric fields are encoded as JSON numbers; the parsers accept
//     int / num / string fallback for forward-compat with future encoders.
//
// IMPORTANT: these are pure data — no I/O, no app state. That makes them
// trivially unit-testable in `test/message_command_utils_test.dart`.

class SelfMirrorAttachmentCommand {
  const SelfMirrorAttachmentCommand({
    required this.convoId,
    required this.msgEventId,
    required this.blobId,
    required this.fileKeyB64,
    required this.sizeBytes,
    required this.createdAtMs,
    this.blobAccessTokenB64,
    this.mime,
    this.replyToPayloadEventId,
    this.mediaGroupId,
    this.caption,
    this.filename,
    this.videoNote = false,
    this.durationMs,
    this.waveform,
    this.musicTitle,
    this.musicArtist,
  });

  final String convoId;
  final String msgEventId;
  final String blobId;
  final String fileKeyB64;
  final int sizeBytes;
  final int createdAtMs;
  final String? blobAccessTokenB64;
  final String? mime;
  final String? replyToPayloadEventId;
  final String? mediaGroupId;

  /// Caption shown inside the same bubble (Telegram-style). Optional/additive.
  final String? caption;

  /// Original file name so generic files mirror with their real name+format.
  final String? filename;

  /// True when this attachment is a "video note" / квадратик. Optional/additive
  /// — mirrors the AttachmentEventV1 flag so the receiving own-device renders it
  /// as a video note, not a generic video.
  final bool videoNote;

  /// Playback length in milliseconds (video notes + voice). Optional/additive.
  final int? durationMs;

  /// Voice-note amplitude envelope. Optional/additive — and not cosmetic: an
  /// in-app voice note is `audio/mp4` exactly like a music file, and only the
  /// waveform tells them apart. Without it the mirrored voice note rendered as
  /// a music track on my other device.
  final List<int>? waveform;

  /// Music tags the sender read off the file. Optional/additive.
  final String? musicTitle;
  final String? musicArtist;
}

String buildSelfMirrorAttachmentCommand({
  required String convoId,
  required String msgEventId,
  required String blobId,
  required String fileKeyB64,
  required int sizeBytes,
  required int createdAtMs,
  String? blobAccessTokenB64,
  String? mime,
  String? replyToPayloadEventId,
  String? mediaGroupId,
  String? caption,
  String? filename,
  bool videoNote = false,
  int? durationMs,
  List<int>? waveform,
  String? musicTitle,
  String? musicArtist,
}) {
  final payload = <String, Object?>{
    'v': 1,
    'convoId': convoId.trim(),
    'msgEventId': msgEventId.trim(),
    'blobId': blobId.trim(),
    'fileKeyB64': fileKeyB64,
    'sizeBytes': sizeBytes,
    'createdAtMs': createdAtMs,
    if (blobAccessTokenB64 != null && blobAccessTokenB64.trim().isNotEmpty)
      'blobAccessTokenB64': blobAccessTokenB64,
    if (mime != null && mime.trim().isNotEmpty) 'mime': mime.trim(),
    if (replyToPayloadEventId != null && replyToPayloadEventId.trim().isNotEmpty)
      'replyToPayloadEventId': replyToPayloadEventId.trim(),
    if (mediaGroupId != null && mediaGroupId.trim().isNotEmpty)
      'mediaGroupId': mediaGroupId.trim(),
    if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
    if (filename != null && filename.trim().isNotEmpty)
      'filename': filename.trim(),
    if (videoNote) 'videoNote': true,
    if (durationMs != null) 'durationMs': durationMs,
    if (waveform != null && waveform.isNotEmpty) 'waveform': waveform,
    if (musicTitle != null && musicTitle.trim().isNotEmpty)
      'musicTitle': musicTitle.trim(),
    if (musicArtist != null && musicArtist.trim().isNotEmpty)
      'musicArtist': musicArtist.trim(),
  };
  return '$kSelfMirrorAttachmentCommandPrefix'
      '${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

SelfMirrorAttachmentCommand? parseSelfMirrorAttachmentCommand(String text) {
  if (!text.startsWith(kSelfMirrorAttachmentCommandPrefix)) return null;
  final raw = text.substring(kSelfMirrorAttachmentCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final convoId = (json['convoId'] as String?)?.trim() ?? '';
    final msgEventId = (json['msgEventId'] as String?)?.trim() ?? '';
    final blobId = (json['blobId'] as String?)?.trim() ?? '';
    final fileKeyB64 = (json['fileKeyB64'] as String?) ?? '';
    if (convoId.isEmpty ||
        msgEventId.isEmpty ||
        blobId.isEmpty ||
        fileKeyB64.isEmpty) {
      return null;
    }
    final sizeRaw = json['sizeBytes'];
    final sizeBytes = switch (sizeRaw) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    final createdAtRaw = json['createdAtMs'];
    final createdAtMs = switch (createdAtRaw) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    return SelfMirrorAttachmentCommand(
      convoId: convoId,
      msgEventId: msgEventId,
      blobId: blobId,
      fileKeyB64: fileKeyB64,
      sizeBytes: sizeBytes,
      createdAtMs: createdAtMs,
      blobAccessTokenB64: (json['blobAccessTokenB64'] as String?)?.trim(),
      mime: (json['mime'] as String?)?.trim(),
      replyToPayloadEventId:
          (json['replyToPayloadEventId'] as String?)?.trim(),
      mediaGroupId: (json['mediaGroupId'] as String?)?.trim(),
      caption: (json['caption'] as String?)?.trim(),
      filename: (json['filename'] as String?)?.trim(),
      videoNote: json['videoNote'] == true,
      durationMs: switch (json['durationMs']) {
        final int value => value,
        final num value => value.toInt(),
        final String value => int.tryParse(value),
        _ => null,
      },
      waveform: _selfMirrorWaveform(json['waveform']),
      musicTitle: _selfMirrorLabel(json['musicTitle']),
      musicArtist: _selfMirrorLabel(json['musicArtist']),
    );
  } catch (_) {
    return null;
  }
}

List<int>? _selfMirrorWaveform(Object? raw) {
  if (raw is! List) return null;
  final bars = <int>[
    for (final value in raw)
      if (value is num) value.toInt().clamp(0, 100),
  ];
  return bars.isEmpty ? null : bars;
}

String? _selfMirrorLabel(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool isSelfMirrorAttachmentCommandText(String text) {
  return text.startsWith(kSelfMirrorAttachmentCommandPrefix);
}

class SelfMirrorStickerCommand {
  const SelfMirrorStickerCommand({
    required this.convoId,
    required this.msgEventId,
    required this.packId,
    required this.packVersion,
    required this.stickerId,
    required this.createdAtMs,
    this.emojiHint = '',
    this.label = '',
    this.animated = false,
    this.format = 'png',
    this.replyToPayloadEventId,
  });

  final String convoId;
  final String msgEventId;
  final String packId;
  final int packVersion;
  final String stickerId;
  final int createdAtMs;
  final String emojiHint;
  final String label;
  final bool animated;
  final String format;
  final String? replyToPayloadEventId;
}

String buildSelfMirrorStickerCommand({
  required String convoId,
  required String msgEventId,
  required String packId,
  required int packVersion,
  required String stickerId,
  required int createdAtMs,
  String emojiHint = '',
  String label = '',
  bool animated = false,
  String format = 'png',
  String? replyToPayloadEventId,
}) {
  final payload = <String, Object?>{
    'v': 1,
    'convoId': convoId.trim(),
    'msgEventId': msgEventId.trim(),
    'packId': packId.trim(),
    'packVersion': packVersion,
    'stickerId': stickerId.trim(),
    'createdAtMs': createdAtMs,
    if (emojiHint.trim().isNotEmpty) 'emojiHint': emojiHint.trim(),
    if (label.trim().isNotEmpty) 'label': label.trim(),
    'animated': animated,
    'format': format.trim().isEmpty ? 'png' : format.trim(),
    if (replyToPayloadEventId != null && replyToPayloadEventId.trim().isNotEmpty)
      'replyToPayloadEventId': replyToPayloadEventId.trim(),
  };
  return '$kSelfMirrorStickerCommandPrefix'
      '${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

SelfMirrorStickerCommand? parseSelfMirrorStickerCommand(String text) {
  if (!text.startsWith(kSelfMirrorStickerCommandPrefix)) return null;
  final raw = text.substring(kSelfMirrorStickerCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final convoId = (json['convoId'] as String?)?.trim() ?? '';
    final msgEventId = (json['msgEventId'] as String?)?.trim() ?? '';
    final packId = (json['packId'] as String?)?.trim() ?? '';
    final stickerId = (json['stickerId'] as String?)?.trim() ?? '';
    if (convoId.isEmpty ||
        msgEventId.isEmpty ||
        packId.isEmpty ||
        stickerId.isEmpty) {
      return null;
    }
    int parseInt(Object? v) => switch (v) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    return SelfMirrorStickerCommand(
      convoId: convoId,
      msgEventId: msgEventId,
      packId: packId,
      packVersion: parseInt(json['packVersion']),
      stickerId: stickerId,
      createdAtMs: parseInt(json['createdAtMs']),
      emojiHint: (json['emojiHint'] as String?)?.trim() ?? '',
      label: (json['label'] as String?)?.trim() ?? '',
      animated: (json['animated'] as bool?) ?? false,
      format: ((json['format'] as String?)?.trim().isEmpty ?? true)
          ? 'png'
          : (json['format'] as String).trim(),
      replyToPayloadEventId:
          (json['replyToPayloadEventId'] as String?)?.trim(),
    );
  } catch (_) {
    return null;
  }
}

bool isSelfMirrorStickerCommandText(String text) {
  return text.startsWith(kSelfMirrorStickerCommandPrefix);
}

class SelfMirrorReactionCommand {
  const SelfMirrorReactionCommand({
    required this.convoId,
    required this.targetPayloadEventId,
    required this.emoji,
    required this.removed,
    required this.createdAtMs,
    this.actorProfileId,
    this.actorName,
    this.actorAvatarPath,
  });

  final String convoId;
  final String targetPayloadEventId;
  final String emoji;
  final bool removed;
  final int createdAtMs;
  final String? actorProfileId;
  final String? actorName;
  final String? actorAvatarPath;
}

String buildSelfMirrorReactionCommand({
  required String convoId,
  required String targetPayloadEventId,
  required String emoji,
  required bool removed,
  required int createdAtMs,
  String? actorProfileId,
  String? actorName,
  String? actorAvatarPath,
}) {
  final payload = <String, Object?>{
    'v': 1,
    'convoId': convoId.trim(),
    'targetPayloadEventId': targetPayloadEventId.trim(),
    'emoji': emoji,
    'removed': removed,
    'createdAtMs': createdAtMs,
    if (actorProfileId != null && actorProfileId.trim().isNotEmpty)
      'actorProfileId': actorProfileId.trim(),
    if (actorName != null && actorName.trim().isNotEmpty)
      'actorName': actorName.trim(),
    if (actorAvatarPath != null && actorAvatarPath.trim().isNotEmpty)
      'actorAvatarPath': actorAvatarPath.trim(),
  };
  return '$kSelfMirrorReactionCommandPrefix'
      '${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

SelfMirrorReactionCommand? parseSelfMirrorReactionCommand(String text) {
  if (!text.startsWith(kSelfMirrorReactionCommandPrefix)) return null;
  final raw = text.substring(kSelfMirrorReactionCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final convoId = (json['convoId'] as String?)?.trim() ?? '';
    final target = (json['targetPayloadEventId'] as String?)?.trim() ?? '';
    final emoji = (json['emoji'] as String?) ?? '';
    if (convoId.isEmpty || target.isEmpty || emoji.isEmpty) return null;
    int parseInt(Object? v) => switch (v) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    return SelfMirrorReactionCommand(
      convoId: convoId,
      targetPayloadEventId: target,
      emoji: emoji,
      removed: (json['removed'] as bool?) ?? false,
      createdAtMs: parseInt(json['createdAtMs']),
      actorProfileId: (json['actorProfileId'] as String?)?.trim(),
      actorName: (json['actorName'] as String?)?.trim(),
      actorAvatarPath: (json['actorAvatarPath'] as String?)?.trim(),
    );
  } catch (_) {
    return null;
  }
}

bool isSelfMirrorReactionCommandText(String text) {
  return text.startsWith(kSelfMirrorReactionCommandPrefix);
}

// ---------------------------------------------------------------------------
// Self-mirror receipt — 2026-05-20 PR-B (BUG-10)
// ---------------------------------------------------------------------------
//
// Fires AFTER our device applies an inbound `ReceiptEventV1` from the peer
// (or after we send our own outbound receipt acknowledging a peer's msg).
// We forward the same `(refPayloadEventId, status)` mapping to all the
// user's other registered devices so they flip their copy of the row from
// `delivered` → `read` (or `sent` → `delivered`) in lock-step.
//
// Why this lives in a control message, not as a fresh `ReceiptEventV1`:
//   • `ReceiptEventV1` was deliberately tuned for *peer*↔*peer* receipts —
//     the receive path at `app_controller.dart` filters out own-device
//     receipts (`receiptFromOwnDevice` guard) to avoid receipt-loops. We
//     do not want to loosen that gate; the loop hazard is real.
//   • A separate prefix keeps the loop-prevention trivial: the receiver
//     accepts the mirror ONLY if the sender device id is one of ours, and
//     never re-mirrors what it just received.
//   • Older builds that don't know the prefix treat it as a hidden control
//     (`isHiddenMessageControlText`) and skip — no UI corruption.
//
// Schema:
//   {
//     "v": 1,
//     "refs": ["<payloadEventId>", ...],   // typically 1–8 ids per batch
//     "status": "delivered" | "read",
//     "appliedAtMs": <epochMs>,            // wall-clock of the local flip
//     "peerProfileId": "<originator>",     // optional, for diagnostics only
//   }
//
// Implementation notes for the receive side: apply each `ref` via
// `db.updateLocalStateByPayloadEventId`; do not call `db.pendingReceiptUpsert`
// or any outbound queueing — the mirror is **terminal**, never re-broadcast.

class SelfMirrorReceiptCommand {
  const SelfMirrorReceiptCommand({
    required this.refPayloadEventIds,
    required this.status,
    required this.appliedAtMs,
    this.peerProfileId,
  });

  /// payload-event-ids of the messages whose `local_state` should be bumped.
  final List<String> refPayloadEventIds;

  /// 'delivered' or 'read'. Receiver should normalize via
  /// `MessageReceiptState.normalize` before applying.
  final String status;

  /// Wall-clock ms when the originating own-device applied the flip
  /// locally. Used purely for tie-breaking / logging — DB state is
  /// derived from the receiving device's monotonic ordering.
  final int appliedAtMs;

  /// Profile id of the peer whose messages these receipts refer to.
  /// Optional and informational only — the receive path looks the
  /// convo up by `payloadEventId` so this is not required for
  /// correctness. Useful for trace/debug.
  final String? peerProfileId;
}

String buildSelfMirrorReceiptCommand({
  required Iterable<String> refPayloadEventIds,
  required String status,
  required int appliedAtMs,
  String? peerProfileId,
}) {
  final normalizedRefs = refPayloadEventIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  final payload = <String, Object?>{
    'v': 1,
    'refs': normalizedRefs,
    'status': status,
    'appliedAtMs': appliedAtMs,
    if (peerProfileId != null && peerProfileId.isNotEmpty)
      'peerProfileId': peerProfileId,
  };
  return '$kSelfMirrorReceiptCommandPrefix${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

SelfMirrorReceiptCommand? parseSelfMirrorReceiptCommand(String text) {
  if (!text.startsWith(kSelfMirrorReceiptCommandPrefix)) return null;
  final raw = text.substring(kSelfMirrorReceiptCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final refsRaw = json['refs'];
    final refs = (refsRaw is List)
        ? refsRaw
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    if (refs.isEmpty) return null;
    final status = (json['status'] as String?)?.trim() ?? '';
    if (status.isEmpty) return null;
    int parseInt(Object? v) => switch (v) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    return SelfMirrorReceiptCommand(
      refPayloadEventIds: refs,
      status: status,
      appliedAtMs: parseInt(json['appliedAtMs']),
      peerProfileId: (json['peerProfileId'] as String?)?.trim().isEmpty == true
          ? null
          : (json['peerProfileId'] as String?)?.trim(),
    );
  } catch (_) {
    return null;
  }
}

bool isSelfMirrorReceiptCommandText(String text) {
  return text.startsWith(kSelfMirrorReceiptCommandPrefix);
}

/// A read watermark mirrored from one of the user's own devices.
///
/// Means: in [convoId], every incoming message with `created_at_ms` at or
/// before [readUpToMs] has been read by the user (on another device).
class SelfMirrorReadCommand {
  const SelfMirrorReadCommand({
    required this.convoId,
    required this.readUpToMs,
    required this.appliedAtMs,
  });

  final String convoId;
  final int readUpToMs;
  final int appliedAtMs;
}

String buildSelfMirrorReadCommand({
  required String convoId,
  required int readUpToMs,
  required int appliedAtMs,
}) {
  final payload = <String, Object?>{
    'v': 1,
    'convoId': convoId.trim(),
    'readUpToMs': readUpToMs,
    'appliedAtMs': appliedAtMs,
  };
  return '$kSelfMirrorReadCommandPrefix'
      '${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

SelfMirrorReadCommand? parseSelfMirrorReadCommand(String text) {
  if (!text.startsWith(kSelfMirrorReadCommandPrefix)) return null;
  final raw = text.substring(kSelfMirrorReadCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final convoId = ((json['convoId'] as String?) ?? '').trim();
    if (convoId.isEmpty) return null;
    int parseInt(Object? v) => switch (v) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    final readUpToMs = parseInt(json['readUpToMs']);
    // A zero or negative watermark would mark nothing; treat it as malformed
    // rather than shipping a no-op that looks like it worked.
    if (readUpToMs <= 0) return null;
    return SelfMirrorReadCommand(
      convoId: convoId,
      readUpToMs: readUpToMs,
      appliedAtMs: parseInt(json['appliedAtMs']),
    );
  } catch (_) {
    return null;
  }
}

bool isSelfMirrorReadCommandText(String text) {
  return text.startsWith(kSelfMirrorReadCommandPrefix);
}

/// A per-conversation state patch mirrored from one of the user's own devices.
///
/// Only non-null fields were actually changed and should be applied;
/// [autoDeleteSet] distinguishes "the timer was turned off" (set, value null)
/// from "the timer was not part of this change" (not set).
class SelfMirrorConvoStateCommand {
  const SelfMirrorConvoStateCommand({
    required this.convoId,
    required this.appliedAtMs,
    this.muted,
    this.pinned,
    this.archived,
    this.personal,
    this.autoDeleteSet = false,
    this.autoDeleteSeconds,
  });

  final String convoId;
  final int appliedAtMs;
  final bool? muted;
  final bool? pinned;
  final bool? archived;
  final bool? personal;
  final bool autoDeleteSet;
  final int? autoDeleteSeconds;

  /// True when the patch would change nothing — worth not sending at all.
  bool get isEmpty =>
      muted == null &&
      pinned == null &&
      archived == null &&
      personal == null &&
      !autoDeleteSet;
}

String buildSelfMirrorConvoStateCommand({
  required String convoId,
  required int appliedAtMs,
  bool? muted,
  bool? pinned,
  bool? archived,
  bool? personal,
  bool autoDeleteSet = false,
  int? autoDeleteSeconds,
}) {
  final payload = <String, Object?>{
    'v': 1,
    'convoId': convoId.trim(),
    'appliedAtMs': appliedAtMs,
    if (muted != null) 'muted': muted,
    if (pinned != null) 'pinned': pinned,
    if (archived != null) 'archived': archived,
    if (personal != null) 'personal': personal,
    if (autoDeleteSet) 'autoDeleteSet': true,
    if (autoDeleteSet) 'autoDeleteSeconds': autoDeleteSeconds,
  };
  return '$kSelfMirrorConvoStateCommandPrefix'
      '${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

SelfMirrorConvoStateCommand? parseSelfMirrorConvoStateCommand(String text) {
  if (!text.startsWith(kSelfMirrorConvoStateCommandPrefix)) return null;
  final raw = text.substring(kSelfMirrorConvoStateCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final convoId = ((json['convoId'] as String?) ?? '').trim();
    if (convoId.isEmpty) return null;
    bool? readBool(String key) {
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      return null;
    }

    int parseInt(Object? v) => switch (v) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    final autoDeleteSet = readBool('autoDeleteSet') ?? false;
    final rawAutoDelete = json['autoDeleteSeconds'];
    final command = SelfMirrorConvoStateCommand(
      convoId: convoId,
      appliedAtMs: parseInt(json['appliedAtMs']),
      muted: readBool('muted'),
      pinned: readBool('pinned'),
      archived: readBool('archived'),
      personal: readBool('personal'),
      autoDeleteSet: autoDeleteSet,
      autoDeleteSeconds: (!autoDeleteSet || rawAutoDelete == null)
          ? null
          : parseInt(rawAutoDelete),
    );
    // A patch that changes nothing is malformed, not a no-op worth applying.
    if (command.isEmpty) return null;
    return command;
  } catch (_) {
    return null;
  }
}

bool isSelfMirrorConvoStateCommandText(String text) {
  return text.startsWith(kSelfMirrorConvoStateCommandPrefix);
}

/// A chat-folder change mirrored from one of the user's own devices.
///
/// [deleted] means the folder is gone and [name] / [convoIds] carry nothing.
class SelfMirrorFolderCommand {
  const SelfMirrorFolderCommand({
    required this.folderId,
    required this.appliedAtMs,
    this.deleted = false,
    this.name = '',
    this.emoji,
    this.position = 0,
    this.convoIds = const <String>[],
  });

  final String folderId;
  final int appliedAtMs;
  final bool deleted;
  final String name;
  final String? emoji;
  final int position;
  final List<String> convoIds;
}

String buildSelfMirrorFolderCommand({
  required String folderId,
  required int appliedAtMs,
  bool deleted = false,
  String name = '',
  String? emoji,
  int position = 0,
  Iterable<String> convoIds = const <String>[],
}) {
  final payload = <String, Object?>{
    'v': 1,
    'folderId': folderId.trim(),
    'appliedAtMs': appliedAtMs,
    if (deleted) 'deleted': true,
    if (!deleted) 'name': name.trim(),
    if (!deleted && (emoji ?? '').trim().isNotEmpty) 'emoji': emoji!.trim(),
    if (!deleted) 'position': position,
    if (!deleted)
      'convoIds': convoIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
  };
  return '$kSelfMirrorFolderCommandPrefix'
      '${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
}

SelfMirrorFolderCommand? parseSelfMirrorFolderCommand(String text) {
  if (!text.startsWith(kSelfMirrorFolderCommandPrefix)) return null;
  final raw = text.substring(kSelfMirrorFolderCommandPrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final jsonObj = jsonDecode(decoded);
    if (jsonObj is! Map) return null;
    final json = jsonObj.cast<String, Object?>();
    final folderId = ((json['folderId'] as String?) ?? '').trim();
    if (folderId.isEmpty) return null;
    int parseInt(Object? v) => switch (v) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    final deleted = json['deleted'] == true;
    if (deleted) {
      return SelfMirrorFolderCommand(
        folderId: folderId,
        appliedAtMs: parseInt(json['appliedAtMs']),
        deleted: true,
      );
    }
    final name = ((json['name'] as String?) ?? '').trim();
    // A nameless folder would render as a blank tab nobody can identify.
    if (name.isEmpty) return null;
    final rawConvoIds = json['convoIds'];
    return SelfMirrorFolderCommand(
      folderId: folderId,
      appliedAtMs: parseInt(json['appliedAtMs']),
      name: name,
      emoji: ((json['emoji'] as String?) ?? '').trim().isEmpty
          ? null
          : (json['emoji'] as String).trim(),
      position: parseInt(json['position']),
      convoIds: (rawConvoIds is List)
          ? rawConvoIds
                .whereType<String>()
                .map((id) => id.trim())
                .where((id) => id.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
    );
  } catch (_) {
    return null;
  }
}

bool isSelfMirrorFolderCommandText(String text) {
  return text.startsWith(kSelfMirrorFolderCommandPrefix);
}
