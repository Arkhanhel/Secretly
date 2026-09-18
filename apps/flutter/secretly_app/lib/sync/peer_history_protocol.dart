// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Peer-to-device history-sync wire protocol (PR5, 2026-05-19).
//
// SCOPE & NON-GOALS
// -----------------
// PR4 already gave desktop a 7-day catch-up via the relay's per-device
// mailbox (`/v1/pending` + WS `Welcome→FetchPending`). That covers the
// "I closed my laptop for the weekend" case. PR5 covers the *other*
// case: the user pairs a fresh desktop via QR (or hasn't opened it in
// >7 days), and the relay has already aged-out the mailbox. The new
// device's local DB is empty, but mobile is sitting on the full
// archive. So mobile sends desktop a recent window directly, over the
// already-existing e2ee channel.
//
// This is *not* a generic "sync everything" protocol — that would
// reintroduce the unbounded-bandwidth concern flagged in
// SPRINT2_AUDIT §16. PR5 v1 caps a single request at
// [kPeerHistoryMaxEventsPerChunk] × [kPeerHistoryMaxChunksPerRequest] =
// 250 events ≈ a few weeks of normal usage. Pagination via
// [PeerHistoryRequest.cursor] is wired in but the desktop side only
// asks for the first window; PR6 will add the "load older" UX trigger.
//
// SECURITY MODEL
// --------------
// Both directions ride on `AppController.sendControlMessage`, which
// means:
//   • Transport is the existing per-device ratchet — already e2ee,
//     forward-secret, with replay protection at the WS layer.
//   • Receive handler in `AppController` MUST gate every parse on
//     `isOwnDeviceId(senderDeviceId) || senderProfileId == myPid`
//     before acting. Anything else lets a peer impersonate "you" and
//     inject forged history into your own DB. The receive handlers in
//     this PR copy the same gate pattern that
//     `_parseSelfMirrorMessageCommand` uses (`app_controller.dart`
//     ≈ line 26580).
//   • Payload-level integrity rides on the wrapped E2ePayloadV1 bytes
//     — desktop never trusts the plaintext "type" / "senderDeviceId"
//     fields directly, it decodes the inner payload via the same
//     pipeline as a normal incoming relay event.
//
// WHY A NEW PREFIX AND NOT REUSING `__secretly_self_mirror_msg_v1__:`
// -------------------------------------------------------------------
// The self-mirror prefix is for *near-real-time* mirroring of a
// message I just sent on another device: it carries one envelope, no
// pagination, no request/response correlation. History sync is bulky,
// request-scoped, and needs flow control. Sharing the prefix would
// force every self-mirror receive to also accept a chunk array,
// blurring the parser. Keeping them separate also makes it cheap to
// disable history-sync independently if we hit a bug.

import 'dart:convert';

/// Prefix for desktop→mobile "please send me a history window" command.
/// Carries an encoded [PeerHistoryRequest]. Receive handler lives on
/// mobile; gated on `isOwnDeviceId(senderDid)`.
const String kPeerHistoryRequestCmdPrefix = '__secretly_history_req_v1__:';

/// Prefix for mobile→desktop chunk response. Carries an encoded
/// [PeerHistoryChunk]. Receive handler lives on desktop; gated on
/// `isOwnDeviceId(senderDid)`.
const String kPeerHistoryChunkCmdPrefix = '__secretly_history_chunk_v1__:';

/// Hard cap on events per chunk. Picked so a single chunk fits
/// comfortably under the relay's `MAX_EVENT_BYTES` after b64+ratchet
/// overhead even with attachment-heavy payloads (typical text event
/// is ~400 B encoded; we budget 4 KB/event worst case → 200 KB chunk).
const int kPeerHistoryMaxEventsPerChunk = 50;

/// Hard cap on chunks per logical request. 5 × 50 = 250 events,
/// enough to cover ~2–4 weeks of typical usage for a freshly-paired
/// device. PR6 will let the desktop request additional pages via
/// [PeerHistoryRequest.cursor].
const int kPeerHistoryMaxChunksPerRequest = 5;

/// Desktop-side in-flight cap. The orchestrator (PR5's
/// `PeerHistoryService`) keeps a token bucket so a misbehaving server
/// or a flapping link can't pile up unbounded outstanding requests.
const int kPeerHistoryMaxRequestsInFlight = 4;

/// A single request issued by a desktop device asking one of the
/// user's other devices (typically mobile) to ship recent events.
///
/// The convention: omit [convoId] for "all convos, newest first".
/// `sinceMs == null` means "from now backwards"; mobile fills events
/// in DESC `createdAtMs` order so the most recent stuff shows up
/// first. [cursor] is opaque to desktop — mobile picks the format
/// (currently the oldest `createdAtMs` of the previous chunk).
class PeerHistoryRequest {
  const PeerHistoryRequest({
    required this.requestId,
    this.convoId,
    this.sinceMs,
    this.untilMs,
    this.limit = kPeerHistoryMaxEventsPerChunk,
    this.cursor,
  });

  /// UUID-style identifier so the responder can echo it in every
  /// chunk and the desktop can match chunks → requests (and discard
  /// orphans from a request we've already given up on).
  final String requestId;

  /// Optional convo filter. PR5 v1 sends `null` (all convos).
  final String? convoId;

  /// Inclusive lower bound on `createdAtMs`. `null` = no lower bound.
  final int? sinceMs;

  /// Exclusive upper bound on `createdAtMs`. `null` = "now".
  final int? untilMs;

  /// Soft cap per response chunk. Clamped server-side to
  /// [kPeerHistoryMaxEventsPerChunk].
  final int limit;

  /// Pagination token. Opaque to the requester; mobile echoes the
  /// `nextCursor` from the previous chunk to resume.
  final String? cursor;

  Map<String, Object?> toJson() => {
        'requestId': requestId,
        if (convoId != null) 'convoId': convoId,
        if (sinceMs != null) 'sinceMs': sinceMs,
        if (untilMs != null) 'untilMs': untilMs,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      };

  static PeerHistoryRequest? fromJson(Map<String, Object?> j) {
    final id = j['requestId'];
    if (id is! String || id.isEmpty) return null;
    int? asInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    final lim = asInt(j['limit']) ?? kPeerHistoryMaxEventsPerChunk;
    return PeerHistoryRequest(
      requestId: id,
      convoId: j['convoId'] is String ? j['convoId'] as String : null,
      sinceMs: asInt(j['sinceMs']),
      untilMs: asInt(j['untilMs']),
      limit: lim.clamp(1, kPeerHistoryMaxEventsPerChunk),
      cursor: j['cursor'] is String ? j['cursor'] as String : null,
    );
  }
}

/// One event inside a [PeerHistoryChunk].
///
/// [payloadB64] is the base64-encoded canonical bytes of an
/// [E2ePayloadV1] (i.e. the same shape as `ciphertext_b64` in the
/// `events` table *before* the local-crypto re-encryption pass).
/// Desktop's receive handler runs the standard inbound pipeline on
/// these bytes: validate → assign `payloadEventId` → re-encrypt with
/// the device-local crypto key → insert with
/// `ConflictAlgorithm.ignore` so a duplicate from the relay path
/// becomes a no-op.
class PeerHistoryChunkEvent {
  const PeerHistoryChunkEvent({
    required this.eventId,
    required this.convoId,
    required this.type,
    required this.senderDeviceId,
    required this.createdAtMs,
    required this.payloadB64,
    this.payloadEventId,
    this.localState,
  });

  final String eventId;
  final String convoId;
  final String type;
  final String senderDeviceId;
  final int createdAtMs;
  final String payloadB64;

  /// Threading key for reactions / replies; mobile copies the value
  /// straight out of its own DB row.
  final String? payloadEventId;

  /// Optional override. When mobile is reshipping an event *I* sent
  /// (i.e. `senderDeviceId` is one of my own devices but not this
  /// desktop), the row should land as `localState='sent'` so the
  /// bubble renders on the right with a "sent" tick rather than as
  /// an incoming message. `null` = let the receiver derive it.
  final String? localState;

  Map<String, Object?> toJson() => {
        'eventId': eventId,
        'convoId': convoId,
        'type': type,
        'senderDeviceId': senderDeviceId,
        'createdAtMs': createdAtMs,
        'payloadB64': payloadB64,
        if (payloadEventId != null) 'payloadEventId': payloadEventId,
        if (localState != null) 'localState': localState,
      };

  static PeerHistoryChunkEvent? fromJson(Map<String, Object?> j) {
    final id = j['eventId'];
    final convo = j['convoId'];
    final type = j['type'];
    final sender = j['senderDeviceId'];
    final pb64 = j['payloadB64'];
    final created = j['createdAtMs'];
    if (id is! String || id.isEmpty) return null;
    if (convo is! String || convo.isEmpty) return null;
    if (type is! String || type.isEmpty) return null;
    if (sender is! String || sender.isEmpty) return null;
    if (pb64 is! String || pb64.isEmpty) return null;
    int? createdMs;
    if (created is int) {
      createdMs = created;
    } else if (created is num) {
      createdMs = created.toInt();
    } else if (created is String) {
      createdMs = int.tryParse(created);
    }
    if (createdMs == null || createdMs <= 0) return null;
    return PeerHistoryChunkEvent(
      eventId: id,
      convoId: convo,
      type: type,
      senderDeviceId: sender,
      createdAtMs: createdMs,
      payloadB64: pb64,
      payloadEventId: j['payloadEventId'] is String
          ? j['payloadEventId'] as String
          : null,
      localState:
          j['localState'] is String ? j['localState'] as String : null,
    );
  }
}

/// Group membership snapshot row — one per (groupId, profileId).
/// Mirrors the public columns of the `group_memberships` table.
class PeerHistoryGroupMember {
  const PeerHistoryGroupMember({
    required this.profileId,
    required this.status,
    this.role = 'member',
    this.tag,
    this.createdAtMs,
    this.updatedAtMs,
  });

  final String profileId;
  final String status;
  final String role;
  final String? tag;
  final int? createdAtMs;
  final int? updatedAtMs;

  Map<String, Object?> toJson() => {
        'profileId': profileId,
        'status': status,
        'role': role,
        if (tag != null) 'tag': tag,
        if (createdAtMs != null) 'createdAtMs': createdAtMs,
        if (updatedAtMs != null) 'updatedAtMs': updatedAtMs,
      };

  static PeerHistoryGroupMember? fromJson(Map<String, Object?> j) {
    final pid = j['profileId'];
    final st = j['status'];
    if (pid is! String || pid.isEmpty) return null;
    if (st is! String || st.isEmpty) return null;
    int? asInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    final r = j['role'];
    final t = j['tag'];
    return PeerHistoryGroupMember(
      profileId: pid,
      status: st,
      role: (r is String && r.isNotEmpty) ? r : 'member',
      tag: (t is String && t.isNotEmpty) ? t : null,
      createdAtMs: asInt(j['createdAtMs']),
      updatedAtMs: asInt(j['updatedAtMs']),
    );
  }
}

/// Per-group metadata snapshot shipped alongside group events in a
/// [PeerHistoryChunk] (PR6). For groups we need this because the
/// receiving device can't render the chat list without a `conversations`
/// row, the room title, owner identity, and at least the active-member
/// roster.
///
/// Optional fields default to mobile-side defaults so a `groupSettings`
/// table row can be roundtripped without surprises.
class PeerHistoryGroupMeta {
  const PeerHistoryGroupMeta({
    required this.groupId,
    required this.title,
    required this.ownerProfileId,
    this.description,
    this.pinnedMessageEventId,
    this.reactionsMode = 'all',
    this.allowText = true,
    this.allowMedia = true,
    this.allowAddMembers = true,
    this.allowPinMessages = true,
    this.allowChangeGroupInfo = true,
    this.allowChangeTag = false,
    this.joinApprovalRequired = false,
    this.slowModeSeconds = 0,
    this.chatHistoryVisible = false,
    this.membershipVersion = 0,
    this.stateVersion = 0,
    this.createdAtMs,
    this.updatedAtMs,
    this.members = const <PeerHistoryGroupMember>[],
  });

  final String groupId;
  final String title;
  final String ownerProfileId;
  final String? description;
  final String? pinnedMessageEventId;
  final String reactionsMode;
  final bool allowText;
  final bool allowMedia;
  final bool allowAddMembers;
  final bool allowPinMessages;
  final bool allowChangeGroupInfo;
  final bool allowChangeTag;
  final bool joinApprovalRequired;
  final int slowModeSeconds;
  final bool chatHistoryVisible;
  final int membershipVersion;
  final int stateVersion;
  final int? createdAtMs;
  final int? updatedAtMs;
  final List<PeerHistoryGroupMember> members;

  Map<String, Object?> toJson() => {
        'groupId': groupId,
        'title': title,
        'ownerProfileId': ownerProfileId,
        if (description != null) 'description': description,
        if (pinnedMessageEventId != null)
          'pinnedMessageEventId': pinnedMessageEventId,
        'reactionsMode': reactionsMode,
        'allowText': allowText,
        'allowMedia': allowMedia,
        'allowAddMembers': allowAddMembers,
        'allowPinMessages': allowPinMessages,
        'allowChangeGroupInfo': allowChangeGroupInfo,
        'allowChangeTag': allowChangeTag,
        'joinApprovalRequired': joinApprovalRequired,
        'slowModeSeconds': slowModeSeconds,
        'chatHistoryVisible': chatHistoryVisible,
        'membershipVersion': membershipVersion,
        'stateVersion': stateVersion,
        if (createdAtMs != null) 'createdAtMs': createdAtMs,
        if (updatedAtMs != null) 'updatedAtMs': updatedAtMs,
        'members': members.map((m) => m.toJson()).toList(growable: false),
      };

  static PeerHistoryGroupMeta? fromJson(Map<String, Object?> j) {
    final gid = j['groupId'];
    final title = j['title'];
    final owner = j['ownerProfileId'];
    if (gid is! String || gid.isEmpty) return null;
    if (title is! String) return null;
    if (owner is! String || owner.isEmpty) return null;
    bool asBool(Object? v, bool fallback) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        if (v == 'true' || v == '1') return true;
        if (v == 'false' || v == '0') return false;
      }
      return fallback;
    }

    int asInt(Object? v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    int? asIntNullable(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    final rawMembers = j['members'];
    final members = <PeerHistoryGroupMember>[];
    if (rawMembers is List) {
      for (final raw in rawMembers) {
        if (raw is! Map) continue;
        final parsed = PeerHistoryGroupMember.fromJson(
          raw.cast<String, Object?>(),
        );
        if (parsed != null) members.add(parsed);
      }
    }

    final desc = j['description'];
    final pin = j['pinnedMessageEventId'];
    final reactionsMode = j['reactionsMode'];
    return PeerHistoryGroupMeta(
      groupId: gid,
      title: title,
      ownerProfileId: owner,
      description: (desc is String && desc.isNotEmpty) ? desc : null,
      pinnedMessageEventId: (pin is String && pin.isNotEmpty) ? pin : null,
      reactionsMode:
          (reactionsMode is String && reactionsMode.isNotEmpty)
              ? reactionsMode
              : 'all',
      allowText: asBool(j['allowText'], true),
      allowMedia: asBool(j['allowMedia'], true),
      allowAddMembers: asBool(j['allowAddMembers'], true),
      allowPinMessages: asBool(j['allowPinMessages'], true),
      allowChangeGroupInfo: asBool(j['allowChangeGroupInfo'], true),
      allowChangeTag: asBool(j['allowChangeTag'], false),
      joinApprovalRequired: asBool(j['joinApprovalRequired'], false),
      slowModeSeconds: asInt(j['slowModeSeconds'], 0),
      chatHistoryVisible: asBool(j['chatHistoryVisible'], false),
      membershipVersion: asInt(j['membershipVersion'], 0),
      stateVersion: asInt(j['stateVersion'], 0),
      createdAtMs: asIntNullable(j['createdAtMs']),
      updatedAtMs: asIntNullable(j['updatedAtMs']),
      members: List.unmodifiable(members),
    );
  }
}

/// One chunk in a (possibly paginated) response to a
/// [PeerHistoryRequest]. Multiple chunks share the same [requestId].
///
/// PR6: optional [groupMetas] carries one [PeerHistoryGroupMeta] per
/// unique group whose events appear in this chunk. Old PR5 clients
/// silently ignore the field — the JSON parser doesn't require it.
class PeerHistoryChunk {
  const PeerHistoryChunk({
    required this.requestId,
    required this.events,
    this.nextCursor,
    this.done = false,
    this.groupMetas = const <PeerHistoryGroupMeta>[],
  });

  final String requestId;
  final List<PeerHistoryChunkEvent> events;

  /// Opaque token to feed into the next [PeerHistoryRequest.cursor].
  /// `null` + `done==true` ⇒ responder believes there is nothing else
  /// in the requested window.
  final String? nextCursor;

  /// Final-chunk marker. Set when the responder has either exhausted
  /// the window or hit [kPeerHistoryMaxChunksPerRequest] for this
  /// request.
  final bool done;

  /// Group metadata snapshots — one entry per distinct group whose
  /// events appear in [events]. Empty for 1-to-1-only chunks.
  final List<PeerHistoryGroupMeta> groupMetas;

  Map<String, Object?> toJson() => {
        'requestId': requestId,
        'events': events.map((e) => e.toJson()).toList(growable: false),
        if (nextCursor != null) 'nextCursor': nextCursor,
        'done': done,
        if (groupMetas.isNotEmpty)
          'groupMetas':
              groupMetas.map((g) => g.toJson()).toList(growable: false),
      };

  static PeerHistoryChunk? fromJson(Map<String, Object?> j) {
    final id = j['requestId'];
    final evs = j['events'];
    if (id is! String || id.isEmpty) return null;
    if (evs is! List) return null;
    final parsed = <PeerHistoryChunkEvent>[];
    for (final raw in evs) {
      if (raw is! Map) continue;
      final m = raw.cast<String, Object?>();
      final ev = PeerHistoryChunkEvent.fromJson(m);
      if (ev != null) parsed.add(ev);
    }
    final rawMetas = j['groupMetas'];
    final metas = <PeerHistoryGroupMeta>[];
    if (rawMetas is List) {
      for (final raw in rawMetas) {
        if (raw is! Map) continue;
        final m = PeerHistoryGroupMeta.fromJson(raw.cast<String, Object?>());
        if (m != null) metas.add(m);
      }
    }
    return PeerHistoryChunk(
      requestId: id,
      events: List.unmodifiable(parsed),
      nextCursor:
          j['nextCursor'] is String ? j['nextCursor'] as String : null,
      done: j['done'] == true,
      groupMetas: List.unmodifiable(metas),
    );
  }
}

// ---------------------------------------------------------------------------
// Wire encode / decode helpers.
//
// Mirrors the `_encodeCommandPayload` / `_decodeCommandPayload` pattern in
// `app_controller.dart` (≈ lines 28018–28042) so the receive side can use
// the same dispatcher shape: prefix-strip → base64Url-decode →
// utf8-decode → jsonDecode.
// ---------------------------------------------------------------------------

String encodePeerHistoryRequest(PeerHistoryRequest req) {
  return '$kPeerHistoryRequestCmdPrefix'
      '${base64Url.encode(utf8.encode(jsonEncode(req.toJson())))}';
}

PeerHistoryRequest? parsePeerHistoryRequest(String text) {
  final m = _decode(text, kPeerHistoryRequestCmdPrefix);
  if (m == null) return null;
  return PeerHistoryRequest.fromJson(m);
}

String encodePeerHistoryChunk(PeerHistoryChunk chunk) {
  return '$kPeerHistoryChunkCmdPrefix'
      '${base64Url.encode(utf8.encode(jsonEncode(chunk.toJson())))}';
}

PeerHistoryChunk? parsePeerHistoryChunk(String text) {
  final m = _decode(text, kPeerHistoryChunkCmdPrefix);
  if (m == null) return null;
  return PeerHistoryChunk.fromJson(m);
}

/// Cheap "is this string one of ours" probe for the dispatcher in
/// `AppController._handleIncomingControlMessage` so it can route to the
/// right parser without trying every prefix.
bool isPeerHistoryCommand(String text) {
  return text.startsWith(kPeerHistoryRequestCmdPrefix) ||
      text.startsWith(kPeerHistoryChunkCmdPrefix);
}

Map<String, Object?>? _decode(String text, String prefix) {
  if (!text.startsWith(prefix)) return null;
  final raw = text.substring(prefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Url.decode(raw));
    final obj = jsonDecode(decoded);
    if (obj is Map<String, dynamic>) return Map<String, Object?>.from(obj);
    if (obj is Map) return obj.cast<String, Object?>();
  } catch (_) {
    return null;
  }
  return null;
}
