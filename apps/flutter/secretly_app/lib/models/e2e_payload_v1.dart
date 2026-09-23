// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import '../calls/call_failure.dart';
import '../calls/call_event.dart';
import 'link_preview_v1.dart';

export 'link_preview_v1.dart' show LinkPreviewV1;

/// E2E payload format v1.
///
/// This is encrypted end-to-end and opaque to the relay.
///
/// NOTE: JSON is used for now for fast iteration. The structure is versioned so
/// we can switch to CBOR/Protobuf later without changing transport semantics.
class E2ePayloadV1 {
  E2ePayloadV1({
    required this.senderDeviceId,
    required this.createdAtMs,
    required this.events,
    this.caps = const <String>[],
  });

  final String senderDeviceId;
  final int createdAtMs;
  final List<E2eEventV1> events;

  /// Возможности устройства-отправителя (17.09.2026). Сборки до этого поля
  /// его не шлют и, получив, пропускают.
  final List<String> caps;

  /// «Общий ключ комнаты версии 2»: подписанные сообщения (К-1) и сырой провод
  /// `SKR1` (К-2). Только таким устройствам выдаётся ключ комнаты и
  /// запечатанные сообщения — выпущенные сборки остаются на попарной рассылке.
  static const String capRoomKeyV2 = 'rk2';

  static const int version = 1;

  List<int> encode() {
    final map = <String, Object?>{
      'v': version,
      'sender_device_id': senderDeviceId,
      'created_at_ms': createdAtMs,
      'events': events.map((e) => e.toJson()).toList(growable: false),
      if (caps.isNotEmpty) 'caps': caps,
    };
    return utf8.encode(jsonEncode(map));
  }

  static E2ePayloadV1 decode(List<int> bytes) {
    final text = utf8.decode(bytes);
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('e2e payload: root is not a JSON object');
    }
    final map = decoded;
    final v = (map['v'] as num?)?.toInt();
    if (v != version) {
      throw StateError('unsupported payload version: $v');
    }
    // Defensive parsing: this JSON is decrypted peer input. A missing/wrong-typed
    // field (e.g. a newer client stamping an unexpected shape, or a buggy peer)
    // must NOT throw out of decode — the caller treats a throw here as a decrypt
    // failure and quarantines/acks the message AND forces a needless session
    // reset, even though decryption SUCCEEDED. Instead we tolerate bad fields and
    // SKIP a single malformed event rather than dropping the whole payload.
    // Use `is` (not `as X?`): a wrong TYPE — e.g. created_at_ms sent as a
    // String — makes `as num?` throw, not return null, which would defeat the
    // whole point and re-introduce the drop-and-reset bug.
    final senderRaw = map['sender_device_id'];
    final sender = senderRaw is String ? senderRaw : '';
    final createdRaw = map['created_at_ms'];
    final createdAt = createdRaw is num ? createdRaw.toInt() : 0;
    final rawEvents = map['events'];
    final events = <E2eEventV1>[];
    if (rawEvents is List) {
      for (final item in rawEvents) {
        if (item is! Map) continue;
        try {
          events.add(E2eEventV1.fromJson(item.cast<String, dynamic>()));
        } catch (_) {
          // Skip just this event; keep the rest of the payload intact.
        }
      }
    }
    final rawCaps = map['caps'];
    final caps = rawCaps is List
        ? rawCaps.whereType<String>().take(16).toList(growable: false)
        : const <String>[];
    return E2ePayloadV1(
      senderDeviceId: sender,
      createdAtMs: createdAt,
      events: events,
      caps: caps,
    );
  }
}

abstract class E2eEventV1 {
  Map<String, Object?> toJson();

  static E2eEventV1 fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'msg' => MsgEventV1(
        eventId: json['event_id'] as String,
        text: json['text'] as String,
        replyToEventId: json['reply_to_event_id'] as String?,
        mentions: ((json['mentions'] as List?) ?? const <Object?>[])
            .map(MsgMentionV1.fromJson)
            .whereType<MsgMentionV1>()
            .toList(growable: false),
        topicId: (json['topic_id'] as String?)?.trim(),
        // Испорченное превью не роняет сообщение: [LinkPreviewV1.fromJson]
        // вернёт null, и текст придёт без карточки.
        linkPreview: LinkPreviewV1.fromJson(json['link_preview']),
      ),
      'sys' => SystemEventV1(
        eventId: json['event_id'] as String,
        text: (json['text'] as String?) ?? '',
        action: (json['action'] as String?)?.trim(),
        actorProfileId: (json['actor_profile_id'] as String?)?.trim(),
        actorDisplayName: (json['actor_display_name'] as String?)?.trim(),
        targetProfileId: (json['target_profile_id'] as String?)?.trim(),
        targetDisplayName: (json['target_display_name'] as String?)?.trim(),
        changedKeys: ((json['changed_keys'] as List?) ?? const <Object?>[])
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
      ),
      'rcpt' => ReceiptEventV1(
        eventId: json['event_id'] as String,
        refEventId: json['ref_event_id'] as String,
        status: json['status'] as String,
        refKind: json['ref_kind'] as String?,
      ),
      'att' => AttachmentEventV1(
        eventId: json['event_id'] as String,
        blobId: json['blob_id'] as String,
        fileKeyB64: json['file_key_b64'] as String,
        blobAccessTokenB64: json['blob_access_token_b64'] as String?,
        sizeBytes: (json['size_bytes'] as num).toInt(),
        mime: json['mime'] as String?,
        replyToEventId: json['reply_to_event_id'] as String?,
        mediaGroupId: json['media_group_id'] as String?,
        waveform: (json['waveform'] as List?)
            ?.map((e) => (e as num).toInt().clamp(0, 100))
            .toList(growable: false),
        topicId: (json['topic_id'] as String?)?.trim(),
        caption: json['caption'] as String?,
        filename: json['filename'] as String?,
        videoNote: json['video_note'] == true,
        durationMs: (json['duration_ms'] as num?)?.toInt(),
        musicTitle: (json['music_title'] as String?)?.trim(),
        musicArtist: (json['music_artist'] as String?)?.trim(),
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        thumbB64: json['thumb_b64'] as String?,
      ),
      'sticker' => StickerEventV1(
        eventId: json['event_id'] as String,
        packId: (json['pack_id'] as String?) ?? '',
        packVersion: (json['pack_version'] as num?)?.toInt() ?? 1,
        stickerId: (json['sticker_id'] as String?) ?? '',
        emojiHint: (json['emoji_hint'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
        animated: json['animated'] == true,
        format: (json['format'] as String?) ?? 'png',
        replyToEventId: json['reply_to_event_id'] as String?,
        topicId: (json['topic_id'] as String?)?.trim(),
        blobId: json['blob_id'] as String?,
        fileKeyB64: json['file_key_b64'] as String?,
        blobAccessTokenB64: json['blob_access_token_b64'] as String?,
        sizeBytes: (json['size_bytes'] as num?)?.toInt(),
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        inlinePngB64: json['inline_png_b64'] as String?,
        packTitle: json['pack_title'] as String?,
        packStickerCount: (json['pack_sticker_count'] as num?)?.toInt(),
        packOriginPid: json['pack_origin_pid'] as String?,
      ),
      'call' => CallEventV1(
        eventId: json['event_id'] as String,
        callId: json['call_id'] as String,
        callAttemptId: json['call_attempt_id'] as String,
        convoId: json['convo_id'] as String,
        direction: CallRecordDirection.fromValue(
          json['direction'] as String? ?? 'outgoing',
        ),
        scope: CallRecordScope.fromValue(
          json['scope'] as String? ?? 'one_to_one',
        ),
        mediaType: CallRecordMediaType.fromValue(
          json['media_type'] as String? ?? 'audio',
        ),
        result: CallRecordResult.fromValue(
          json['result'] as String? ?? 'completed',
        ),
        startedAtMs: (json['started_at_ms'] as num).toInt(),
        connectedAtMs: (json['connected_at_ms'] as num?)?.toInt(),
        endedAtMs: (json['ended_at_ms'] as num).toInt(),
        durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
        endReason: json['end_reason'] as String?,
        failureCode: parseCallFailureCode(json['failure_code'] as String?),
        participantCount: (json['participant_count'] as num?)?.toInt() ?? 2,
        hadVideo: json['had_video'] == true,
        hadScreenShare: json['had_screen_share'] == true,
        qualitySummary: json['quality_summary'],
      ),
      // Room sender key (ТЗ фаза 2). Older clients fall through to
      // UnknownEventV1 and stay inert, which is what makes coexistence work.
      'gkey' => RoomKeyEventV1.fromJson(json),
      'gmsg' => RoomMessageEventV1.fromJson(json),
      'gkeyreq' => RoomKeyRequestEventV1.fromJson(json),
      'gkeyack' => RoomKeyAckEventV1.fromJson(json),
      _ => UnknownEventV1(raw: json),
    };
  }
}

class MsgMentionV1 {
  const MsgMentionV1({
    required this.type,
    required this.start,
    required this.end,
    this.profileId,
  });

  static const String profileType = 'profile';
  static const String allType = 'all';
  static const String adminsType = 'admins';

  final String type;
  final int start;
  final int end;
  final String? profileId;

  bool get isProfile => type == profileType;
  bool get isAll => type == allType;
  bool get isAdmins => type == adminsType;

  Map<String, Object?> toJson() => {
    'type': type,
    'start': start,
    'end': end,
    if (profileId != null) 'profile_id': profileId,
  };

  static MsgMentionV1? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, Object?>();
    final type = ((json['type'] as String?) ?? '').trim();
    final start = (json['start'] as num?)?.toInt() ?? -1;
    final end = (json['end'] as num?)?.toInt() ?? -1;
    final profileId = (json['profile_id'] as String?)?.trim();
    if (start < 0 || end <= start) return null;
    if (type != profileType && type != allType && type != adminsType) {
      return null;
    }
    if (type == profileType && (profileId == null || profileId.isEmpty)) {
      return null;
    }
    return MsgMentionV1(
      type: type,
      start: start,
      end: end,
      profileId: (profileId == null || profileId.isEmpty) ? null : profileId,
    );
  }
}

class MsgEventV1 extends E2eEventV1 {
  MsgEventV1({
    required this.eventId,
    required this.text,
    this.replyToEventId,
    this.mentions = const <MsgMentionV1>[],
    this.topicId,
    this.linkPreview,
  });

  final String eventId;
  final String text;
  final String? replyToEventId;
  final List<MsgMentionV1> mentions;

  /// Optional room topic this message belongs to. Null/empty = the default
  /// "General" topic. Only meaningful in group conversations.
  final String? topicId;

  /// Превью первой ссылки текста, приготовленное ОТПРАВИТЕЛЕМ (16.09.2026).
  ///
  /// Необязательное поле: прежние версии его не знают и просто пропускают —
  /// разбор `msg` не требует лишних ключей. См. [LinkPreviewV1].
  final LinkPreviewV1? linkPreview;

  @override
  Map<String, Object?> toJson() => {
    'type': 'msg',
    'event_id': eventId,
    'text': text,
    if (replyToEventId != null) 'reply_to_event_id': replyToEventId,
    if (mentions.isNotEmpty)
      'mentions': mentions
          .map((mention) => mention.toJson())
          .toList(growable: false),
    if (topicId != null && topicId!.isNotEmpty) 'topic_id': topicId,
    if (linkPreview != null) 'link_preview': linkPreview!.toJson(),
  };
}

class SystemEventV1 extends E2eEventV1 {
  SystemEventV1({
    required this.eventId,
    required this.text,
    this.action,
    this.actorProfileId,
    this.actorDisplayName,
    this.targetProfileId,
    this.targetDisplayName,
    this.changedKeys = const <String>[],
  });

  final String eventId;
  final String text;
  final String? action;
  final String? actorProfileId;
  final String? actorDisplayName;
  final String? targetProfileId;
  final String? targetDisplayName;
  final List<String> changedKeys;

  @override
  Map<String, Object?> toJson() => {
    'type': 'sys',
    'event_id': eventId,
    'text': text,
    if (action != null) 'action': action,
    if (actorProfileId != null) 'actor_profile_id': actorProfileId,
    if (actorDisplayName != null) 'actor_display_name': actorDisplayName,
    if (targetProfileId != null) 'target_profile_id': targetProfileId,
    if (targetDisplayName != null) 'target_display_name': targetDisplayName,
    if (changedKeys.isNotEmpty) 'changed_keys': changedKeys,
  };
}

class ReceiptEventV1 extends E2eEventV1 {
  ReceiptEventV1({
    required this.eventId,
    required this.refEventId,
    required this.status,
    this.refKind,
  });

  /// Receipt event id (unique).
  final String eventId;

  /// Refers to the original payload event_id of the message — EXCEPT for
  /// `nack_undecryptable` receipts (TZ Epic A), where decrypt never happened
  /// so no payload event id exists: there it carries the RELAY `msg_id` and
  /// [refKind] says so.
  final String refEventId;

  /// "delivered" | "read" | "nack_undecryptable" (Epic A). Unknown values are
  /// ignored by consumers (explicit-branch switch — old clients stay inert).
  final String status;

  /// TZ Epic A (2026-07-18): what [refEventId] refers to. Absent/null = legacy
  /// payload event id; `'msg_id'` = relay msg_id (NACK). Optional so older
  /// clients (which never read it) are byte-compatible.
  final String? refKind;

  @override
  Map<String, Object?> toJson() => {
    'type': 'rcpt',
    'event_id': eventId,
    'ref_event_id': refEventId,
    'status': status,
    if (refKind != null && refKind!.isNotEmpty) 'ref_kind': refKind,
  };
}

// ───────────────────────── ROOM SENDER KEY ─────────────────────────
// Nothing emits these yet.
//
// An older client that receives one of these parses it as [UnknownEventV1] and
// ignores it — which is exactly the coexistence behaviour the migration needs.
//
// All three validate at the boundary. A malformed field THROWS, and
// `E2ePayloadV1.decode` skips just that event: a member who misses a key asks
// again (`gkeyreq`) and recovers, whereas a bad key accepted into storage
// poisons the chain silently. Recoverable failure over silent corruption.

int _requirePositionField(Object? raw, String name) {
  if (raw is! num) throw FormatException('$name: not a number');
  final v = raw.toInt();
  if (v < 0) throw FormatException('$name: negative');
  return v;
}

String _requireRoomId(Object? raw) {
  final id = raw is String ? raw.trim() : '';
  if (id.isEmpty) throw const FormatException('room_id: empty');
  return id;
}

/// Необязательное поле байтов: нет — null; есть, но не той длины — ошибка
/// (К-1: испорченная подпись или ключ подписи — повод не верить проводу).
Uint8List? _optionalBytes(Object? raw, String name, {required int exactLen}) {
  if (raw == null) return null;
  return _requireBytes(raw, name, exactLen: exactLen);
}

Uint8List _requireBytes(Object? raw, String name, {required int exactLen}) {
  if (raw is! String) throw FormatException('$name: not a string');
  final Uint8List bytes;
  try {
    bytes = base64Decode(raw);
  } catch (_) {
    throw FormatException('$name: not base64');
  }
  if (bytes.length != exactLen) {
    throw FormatException('$name: expected $exactLen bytes, got ${bytes.length}');
  }
  return bytes;
}

/// Hands a room chain key to ONE peer device over the existing pairwise
/// channel. Never broadcast — the pairwise envelope is what protects it.
class RoomKeyEventV1 extends E2eEventV1 {
  RoomKeyEventV1({
    required this.roomId,
    required this.epoch,
    required this.counter,
    required this.chainKey,
    required this.issuedAtMs,
    this.signingPub,
  });

  final String roomId;
  final int epoch;

  /// Where the chain stands when handed over. A member who joins mid-generation
  /// gets the CURRENT position, not zero — they must not be able to derive keys
  /// for messages sent before they joined.
  final int counter;

  final Uint8List chainKey;
  final int issuedAtMs;

  static RoomKeyEventV1 fromJson(Map<String, dynamic> json) => RoomKeyEventV1(
    roomId: _requireRoomId(json['room_id']),
    epoch: _requirePositionField(json['epoch'], 'epoch'),
    counter: _requirePositionField(json['counter'], 'counter'),
    chainKey: _requireBytes(json['chain_key_b64'], 'chain_key_b64', exactLen: 32),
    issuedAtMs: (json['issued_at_ms'] as num?)?.toInt() ?? 0,
    signingPub: _optionalBytes(
      json['signing_pub_b64'],
      'signing_pub_b64',
      exactLen: 32,
    ),
  );

  /// К-1 (17.09.2026): открытый ключ, которым автор подписывает сообщения
  /// этого поколения. null — ключ выдан сборкой без подписи.
  final Uint8List? signingPub;

  @override
  Map<String, Object?> toJson() => {
    'type': 'gkey',
    'room_id': roomId,
    'epoch': epoch,
    'counter': counter,
    'chain_key_b64': base64Encode(chainKey),
    'issued_at_ms': issuedAtMs,
    if (signingPub != null) 'signing_pub_b64': base64Encode(signingPub!),
  };

  /// Redacted on purpose. This object carries the room's secret, and the one
  /// place it must never appear is a log line — Dart interpolates with
  /// toString(), so the default (or a generated one) would leak the room.
  @override
  String toString() => 'RoomKeyEventV1($roomId, epoch=$epoch, counter=$counter, key=<redacted>)';
}

/// A room message: encrypted ONCE under the sender's chain instead of N×M times
/// under pairwise sessions.
///
/// [ciphertext] wraps an ordinary [E2ePayloadV1], so every existing feature —
/// text, attachments, reactions, replies, mentions — keeps working untouched.
///
/// There is no id field: `(room_id, sender_device_id, epoch, counter)` already
/// identifies the message uniquely, with the sender coming from the enclosing
/// payload. Adding one would create a second identity that could disagree.
class RoomMessageEventV1 extends E2eEventV1 {
  RoomMessageEventV1({
    required this.roomId,
    required this.epoch,
    required this.counter,
    required this.nonce,
    required this.ciphertext,
    this.signature,
  });

  /// К-1 (17.09.2026): подпись автора, см. `RoomMessageSignature`.
  final Uint8List? signature;

  final String roomId;
  final int epoch;
  final int counter;
  final Uint8List nonce;

  /// Ciphertext WITH the appended Poly1305 tag.
  final Uint8List ciphertext;

  static RoomMessageEventV1 fromJson(Map<String, dynamic> json) {
    final raw = json['ciphertext_b64'];
    if (raw is! String) {
      throw const FormatException('ciphertext_b64: not a string');
    }
    final Uint8List ct;
    try {
      ct = base64Decode(raw);
    } catch (_) {
      throw const FormatException('ciphertext_b64: not base64');
    }
    // Shorter than the tag alone cannot be a sealed message.
    if (ct.length < 16) {
      throw const FormatException('ciphertext_b64: shorter than the tag');
    }
    return RoomMessageEventV1(
      roomId: _requireRoomId(json['room_id']),
      epoch: _requirePositionField(json['epoch'], 'epoch'),
      counter: _requirePositionField(json['counter'], 'counter'),
      nonce: _requireBytes(json['nonce_b64'], 'nonce_b64', exactLen: 24),
      ciphertext: ct,
      signature: _optionalBytes(json['sig_b64'], 'sig_b64', exactLen: 64),
    );
  }

  @override
  Map<String, Object?> toJson() => {
    'type': 'gmsg',
    'room_id': roomId,
    'epoch': epoch,
    'counter': counter,
    'nonce_b64': base64Encode(nonce),
    'ciphertext_b64': base64Encode(ciphertext),
    if (signature != null) 'sig_b64': base64Encode(signature!),
  };
}

/// "I cannot open your room traffic" — sent privately to the author, the room
/// equivalent of a NACK. The author re-issues the key for [epoch].
class RoomKeyRequestEventV1 extends E2eEventV1 {
  RoomKeyRequestEventV1({required this.roomId, required this.epoch});

  final String roomId;

  /// The generation that is missing. Sent to the author only, so no sender id
  /// is needed — the recipient IS the sender being asked.
  final int epoch;

  static RoomKeyRequestEventV1 fromJson(Map<String, dynamic> json) =>
      RoomKeyRequestEventV1(
        roomId: _requireRoomId(json['room_id']),
        epoch: _requirePositionField(json['epoch'], 'epoch'),
      );

  @override
  Map<String, Object?> toJson() => {
    'type': 'gkeyreq',
    'room_id': roomId,
    'epoch': epoch,
  };
}

/// "I applied your room key for this generation" (F-ROOMSK-3/4).
///
/// Two jobs, one wire:
///
///  1. **Confirmed keying.** A key used to count as delivered the moment it was
///     ENQUEUED, so the author started sealing messages a member might never
///     have received. Now the author waits for this.
///  2. **Proof of capability.** Only a build that understands the sender-key
///     wire can produce this. Its ABSENCE is what keeps a room on the pairwise
///     path, which every build in existence can read — including the ones from
///     before this format existed, whose silence used to cost the room its
///     messages (1.7.4+416).
///
/// Sending it is safe for an old author too: an author that does not know
/// `gkeyack` treats it as an unknown event and ignores it.
class RoomKeyAckEventV1 extends E2eEventV1 {
  RoomKeyAckEventV1({
    required this.roomId,
    required this.epoch,
    this.rawV1 = false,
  });

  /// К-2 (17.09.2026): «умею принимать сырой провод комнаты» (`SKR1`,
  /// рассылка реле). Сборки до 17.09 поле не ставят — им шлют попарно.
  final bool rawV1;

  final String roomId;

  /// The generation just applied. Sent to the key's author only.
  final int epoch;

  static RoomKeyAckEventV1 fromJson(Map<String, dynamic> json) =>
      RoomKeyAckEventV1(
        roomId: _requireRoomId(json['room_id']),
        epoch: _requirePositionField(json['epoch'], 'epoch'),
        rawV1: json['raw_v1'] == true,
      );

  @override
  Map<String, Object?> toJson() => {
    'type': 'gkeyack',
    'room_id': roomId,
    'epoch': epoch,
    if (rawV1) 'raw_v1': true,
  };
}

class UnknownEventV1 extends E2eEventV1 {
  UnknownEventV1({required this.raw});

  final Map<String, dynamic> raw;

  @override
  Map<String, Object?> toJson() => raw;
}

class AttachmentEventV1 extends E2eEventV1 {
  AttachmentEventV1({
    required this.eventId,
    required this.blobId,
    required this.fileKeyB64,
    this.blobAccessTokenB64,
    required this.sizeBytes,
    this.mime,
    this.replyToEventId,
    this.mediaGroupId,
    this.waveform,
    this.topicId,
    this.caption,
    this.filename,
    this.videoNote = false,
    this.durationMs,
    this.musicTitle,
    this.musicArtist,
    this.width,
    this.height,
    this.thumbB64,
  });

  final String eventId;
  final String blobId;
  final String fileKeyB64;
  final String? blobAccessTokenB64;
  final int sizeBytes;
  final String? mime;
  final String? replyToEventId;
  final String? mediaGroupId;

  /// Original pixel dimensions of the image/video, stamped BY THE SENDER so the
  /// recipient can reserve the EXACT bubble height before the blob even starts
  /// downloading — no height "jump"/reflow when the file finally resolves (the
  /// Telegram/Signal approach to buttery media scrolling). Null for older
  /// clients / non-visual attachments (renderer falls back to async aspect
  /// resolve from the decoded file, i.e. the pre-existing behavior).
  final int? width;
  final int? height;

  /// TZ E2 (2026-07-18): tiny inline preview (a ~24px JPEG, base64, ≤4 KiB —
  /// same idea as StickerEventV1.inlinePngB64) stamped BY THE SENDER so the
  /// bubble shows a real blurred preview INSTANTLY, before the blob download
  /// even starts. Pairs with [width]/[height]: the box is already exact, this
  /// fills it. Null for older clients / non-images (renderer falls back to the
  /// flat placeholder).
  final String? thumbB64;

  /// Optional room topic this attachment belongs to (group conversations).
  final String? topicId;

  /// Optional caption/comment shown INSIDE the same bubble as the media
  /// (Telegram-style), instead of as a separate following text message. Null
  /// for older clients (renderer falls back to no caption).
  final String? caption;

  /// Original file name (e.g. "report_2024.pdf") so files show their real name
  /// + format, not just the MIME type. Null for older clients / voice.
  final String? filename;

  /// Music tags read from the file BY THE SENDER, carried in the payload.
  ///
  /// They must travel with the message: the settled bubble renders from this
  /// event, and re-reading tags off the local blob cache is not dependable —
  /// it fails on iOS outright (the tag reader is stubbed there) and can fail
  /// elsewhere, which made a sent track flip from its real title to the generic
  /// "Music / Unknown artist" the moment the upload settled. The recipient has
  /// no other way to learn them at all. Null for older clients / non-music.
  final String? musicTitle;
  final String? musicArtist;

  /// True when this attachment is a "video note" / квадратик — a short
  /// rounded-square video message recorded like a voice note (front/back
  /// camera). Rendered by VideoNoteBubble instead of the generic video bubble;
  /// old clients ignore the flag and show it as a normal video attachment.
  final bool videoNote;

  /// Playback length in milliseconds (video notes + voice). Null when unknown.
  final int? durationMs;

  /// Optional captured amplitude envelope for voice messages — a list of
  /// per-bar levels in [0, 100], sampled at record time so playback can show
  /// the real waveform of the whole track. Null for non-voice attachments and
  /// for older clients that didn't capture it (renderer falls back gracefully).
  final List<int>? waveform;

  @override
  Map<String, Object?> toJson() => {
    'type': 'att',
    'event_id': eventId,
    'blob_id': blobId,
    'file_key_b64': fileKeyB64,
    if (blobAccessTokenB64 != null) 'blob_access_token_b64': blobAccessTokenB64,
    'size_bytes': sizeBytes,
    if (mime != null) 'mime': mime,
    if (replyToEventId != null) 'reply_to_event_id': replyToEventId,
    if (mediaGroupId != null) 'media_group_id': mediaGroupId,
    if (waveform != null && waveform!.isNotEmpty) 'waveform': waveform,
    if (topicId != null && topicId!.isNotEmpty) 'topic_id': topicId,
    if (caption != null && caption!.isNotEmpty) 'caption': caption,
    if (filename != null && filename!.isNotEmpty) 'filename': filename,
    if (videoNote) 'video_note': true,
    if (durationMs != null) 'duration_ms': durationMs,
    if (musicTitle != null && musicTitle!.isNotEmpty) 'music_title': musicTitle,
    if (musicArtist != null && musicArtist!.isNotEmpty)
      'music_artist': musicArtist,
    if (width != null && width! > 0) 'width': width,
    if (height != null && height! > 0) 'height': height,
    if (thumbB64 != null && thumbB64!.isNotEmpty) 'thumb_b64': thumbB64,
  };
}

class StickerEventV1 extends E2eEventV1 {
  StickerEventV1({
    required this.eventId,
    required this.packId,
    required this.packVersion,
    required this.stickerId,
    this.emojiHint = '',
    this.label = '',
    this.animated = false,
    this.format = 'png',
    this.replyToEventId,
    this.topicId,
    // USER-CREATED sticker pixels, delivered as an E2EE blob (XChaCha20 — the
    // same scheme as attachments) instead of a shared-catalog reference. When
    // [blobId] is set this is a user sticker: the recipient downloads+decrypts
    // it to a local file and renders via SecretlyStickerAssetSource.file. All
    // null for catalog/bundled stickers (fully backward-compatible; old clients
    // that don't read these fields just render the unknown pack as "missing").
    this.blobId,
    this.fileKeyB64,
    this.blobAccessTokenB64,
    this.sizeBytes,
    this.width,
    this.height,
    // FALLBACK pixels carried INLINE inside this encrypted event (base64 PNG),
    // used only when the HTTP blob upload is blocked (some carrier/MIUI networks
    // hang file uploads while the WS message path works). Kept small (≤~32KB).
    this.inlinePngB64,
    // Lightweight PACK metadata stamped on outgoing user stickers so a recipient
    // who taps a received sticker can show the pack header (title + total) and
    // offer "Install" BEFORE fetching the rest of the pack from the author.
    // All null for catalog/bundled stickers and for old clients (ignored).
    this.packTitle,
    this.packStickerCount,
    this.packOriginPid,
  });

  final String eventId;
  final String packId;
  final int packVersion;
  final String stickerId;
  final String emojiHint;
  final String label;
  final bool animated;
  final String format;
  final String? replyToEventId;

  /// Optional room topic this sticker belongs to (group conversations).
  final String? topicId;

  /// E2EE blob handle for a USER-CREATED sticker's pixels (XChaCha20, like an
  /// attachment). Null for catalog/bundled stickers. When set, [packId] is a
  /// user pack (e.g. `user:<profileId>`) and the pixels live only in the blob.
  final String? blobId;
  final String? fileKeyB64;
  final String? blobAccessTokenB64;
  final int? sizeBytes;
  final int? width;
  final int? height;

  /// Base64 PNG carried INLINE in the encrypted event (fallback delivery over
  /// the WS message path when the blob HTTP upload is blocked). Null normally.
  final String? inlinePngB64;

  /// Human-readable pack title, stamped on outgoing user stickers so the
  /// recipient's pack sheet has a header before fetching the pack.
  final String? packTitle;

  /// Total stickers in the source pack (lets the recipient show "N стикеров"
  /// and a fetch-progress count before the pack is pulled).
  final int? packStickerCount;

  /// profileId of the author that owns the source pack — the address the
  /// recipient sends the pack-fetch request back to. Null for catalog/bundled.
  final String? packOriginPid;

  /// True when this sticker carries its own pixels via [blobId] instead of a
  /// shared catalog reference.
  bool get hasInlineBlob => (blobId ?? '').isNotEmpty;

  /// True when this sticker carries its pixels INLINE (the WS fallback above).
  bool get hasInlinePng => (inlinePngB64 ?? '').isNotEmpty;

  @override
  Map<String, Object?> toJson() => {
    'type': 'sticker',
    'event_id': eventId,
    'pack_id': packId,
    'pack_version': packVersion,
    'sticker_id': stickerId,
    if (emojiHint.isNotEmpty) 'emoji_hint': emojiHint,
    if (label.isNotEmpty) 'label': label,
    'animated': animated,
    'format': format,
    if (replyToEventId != null) 'reply_to_event_id': replyToEventId,
    if (topicId != null && topicId!.isNotEmpty) 'topic_id': topicId,
    if (blobId != null && blobId!.isNotEmpty) 'blob_id': blobId,
    if (fileKeyB64 != null && fileKeyB64!.isNotEmpty) 'file_key_b64': fileKeyB64,
    if (blobAccessTokenB64 != null && blobAccessTokenB64!.isNotEmpty)
      'blob_access_token_b64': blobAccessTokenB64,
    if (sizeBytes != null) 'size_bytes': sizeBytes,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (inlinePngB64 != null && inlinePngB64!.isNotEmpty)
      'inline_png_b64': inlinePngB64,
    if (packTitle != null && packTitle!.isNotEmpty) 'pack_title': packTitle,
    if (packStickerCount != null && packStickerCount! > 0)
      'pack_sticker_count': packStickerCount,
    if (packOriginPid != null && packOriginPid!.isNotEmpty)
      'pack_origin_pid': packOriginPid,
  };
}

class CallEventV1 extends E2eEventV1 {
  CallEventV1({
    required this.eventId,
    required this.callId,
    required this.callAttemptId,
    required this.convoId,
    required this.direction,
    required this.scope,
    required this.mediaType,
    required this.result,
    required this.startedAtMs,
    required this.connectedAtMs,
    required this.endedAtMs,
    required this.durationMs,
    required this.endReason,
    this.failureCode,
    required this.participantCount,
    required this.hadVideo,
    required this.hadScreenShare,
    required this.qualitySummary,
  });

  final String eventId;
  final String callId;
  final String callAttemptId;
  final String convoId;
  final CallRecordDirection direction;
  final CallRecordScope scope;
  final CallRecordMediaType mediaType;
  final CallRecordResult result;
  final int startedAtMs;
  final int? connectedAtMs;
  final int endedAtMs;
  final int durationMs;
  final String? endReason;
  final CallFailureCode? failureCode;
  final int participantCount;
  final bool hadVideo;
  final bool hadScreenShare;
  final Object? qualitySummary;

  @override
  Map<String, Object?> toJson() => {
    'type': 'call',
    'event_id': eventId,
    'call_id': callId,
    'call_attempt_id': callAttemptId,
    'convo_id': convoId,
    'direction': direction.value,
    'scope': scope.value,
    'media_type': mediaType.value,
    'result': result.value,
    'started_at_ms': startedAtMs,
    'connected_at_ms': connectedAtMs,
    'ended_at_ms': endedAtMs,
    'duration_ms': durationMs,
    'end_reason': endReason,
    'failure_code': failureCode?.name,
    'participant_count': participantCount,
    'had_video': hadVideo,
    'had_screen_share': hadScreenShare,
    'quality_summary': qualitySummary,
  };
}
