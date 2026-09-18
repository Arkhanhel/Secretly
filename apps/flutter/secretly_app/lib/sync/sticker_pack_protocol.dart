// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Peer sticker-pack share protocol (2026-06-29).
//
// SCOPE
// -----
// When a user taps a sticker someone sent them, they hold only that ONE
// sticker, not the sender's whole pack. This protocol lets the tapper pull the
// rest of the pack from the sender on demand and install it locally.
//
// It deliberately mirrors `peer_history_protocol.dart`: prefix-strip →
// base64Url-decode → utf8-decode → jsonDecode, both directions riding on
// `AppController.sendControlMessage` (the per-device ratchet — already e2ee,
// forward-secret, replay-protected at the WS layer).
//
// WHY INLINE PNG, NOT BLOB REFS
// -----------------------------
// The author's other pack stickers were never uploaded as blobs (only the one
// sticker they actually sent was). And the very network where this matters
// (carrier/MIUI) BLOCKS the HTTP blob upload while the WS message path works.
// So the responder ships each pack sticker as a small inline base64 PNG
// (≤~32 KB, reusing the same shrink the send fallback already does), chunked so
// each control message stays well under the relay's per-event byte cap.
//
// SECURITY MODEL
// --------------
// Unlike peer-history (own-device only), the pack-REQUEST handler must answer a
// PEER. The receive handler in AppController therefore gates differently:
//   • only answers for a `user:` packId it actually holds locally, and
//   • only to a known contact, and
//   • rate-limited per requester.
// The applier validates PNG magic bytes before writing anything to disk.

import 'dart:convert';
import 'dart:typed_data';

/// Recipient → author: "send me the stickers of this pack". Carries an encoded
/// [StickerPackRequest].
const String kStickerPackRequestCmdPrefix = '__secretly_sticker_pack_req_v1__:';

/// Author → recipient: one batch of inline-PNG stickers. Carries an encoded
/// [StickerPackChunk].
const String kStickerPackChunkCmdPrefix = '__secretly_sticker_pack_chunk_v1__:';

/// Max stickers per chunk. 3 inline PNGs (~30 KB each → ~40 KB base64) ≈ 120 KB
/// of JSON which, after ratchet + the relay's own base64 wrap, stays under the
/// 256 KiB per-event cap with margin.
const int kStickerPackMaxStickersPerChunk = 3;

/// Soft byte budget for the inline payload of one chunk (sum of base64 PNG
/// lengths). The responder closes a chunk early once it crosses this.
const int kStickerPackMaxInlineBytesPerChunk = 90 * 1024;

/// Hard cap on chunks per logical request → ≈ 60 stickers. Bigger packs are
/// truncated (the recipient still gets the first 60).
const int kStickerPackMaxChunksPerRequest = 20;

/// Responder-side in-flight / rate cap per requester.
const int kStickerPackMaxRequestsInFlight = 4;

/// PNG signature (first 8 bytes). Used to reject anything that isn't a PNG
/// before it touches disk or the catalog DB.
bool stickerPackBytesLookLikePng(Uint8List bytes) {
  if (bytes.length < 8) return false;
  const sig = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < sig.length; i++) {
    if (bytes[i] != sig[i]) return false;
  }
  return true;
}

/// A recipient's request for one pack.
class StickerPackRequest {
  const StickerPackRequest({required this.requestId, required this.packId});

  /// UUID so the responder echoes it in every chunk and the requester can match
  /// chunks → request (and drop orphans from a request it gave up on).
  final String requestId;

  /// The pack the recipient wants (the packId carried on the tapped sticker).
  final String packId;

  Map<String, Object?> toJson() => {'requestId': requestId, 'packId': packId};

  static StickerPackRequest? fromJson(Map<String, Object?> j) {
    final id = j['requestId'];
    final pack = j['packId'];
    if (id is! String || id.isEmpty) return null;
    if (pack is! String || pack.isEmpty) return null;
    return StickerPackRequest(requestId: id, packId: pack);
  }
}

/// One sticker inside a [StickerPackChunk] — its pixels carried inline.
class StickerPackChunkSticker {
  const StickerPackChunkSticker({
    required this.stickerId,
    required this.inlinePngB64,
    this.format = 'png',
    this.animated = false,
    this.emojiHint = '',
    this.label = '',
    this.blobId = '',
    this.fileKeyB64 = '',
    this.accessTokenB64 = '',
    this.sizeBytes,
  });

  final String stickerId;
  final String inlinePngB64;
  final String format;
  final bool animated;
  final String emojiHint;
  final String label;

  /// Ссылка на шифртекст вместо пикселей (08.08.2026).
  ///
  /// 🔴 ЗАЧЕМ. Порция везла ТОЛЬКО пиксели инлайном, а вложить можно не всё:
  /// `_buildInlineStickerB64` отказывает анимированным, Lottie и крупным. Такие
  /// стикеры МОЛЧА выбрасывались, и человек, поделившийся набором анимированных,
  /// не передавал ничего, не узнавая почему. Ссылка на блоб для анимированного
  /// стикера такая же маленькая, как для статичного, — то есть передаётся всё.
  ///
  /// 🔴 СОВМЕСТИМОСТЬ ПРОВЕРЕНА: старый разбор требует непустой `inline_png_b64`
  /// и иначе возвращает `null`, то есть пропускает стикер — ровно как пропускал
  /// его и раньше. Новые поля уехавшим сборкам не вредят.
  final String blobId;
  final String fileKeyB64;
  final String accessTokenB64;
  final int? sizeBytes;

  /// Есть ли чем достать стикер: пиксели или ссылка.
  bool get hasInline => inlinePngB64.isNotEmpty;
  bool get hasBlob => blobId.isNotEmpty && fileKeyB64.isNotEmpty;

  Map<String, Object?> toJson() => {
    'sticker_id': stickerId,
    // Пишется всегда, даже пустым: так уехавшие сборки видят знакомую форму и
    // пропускают стикер тем же путём, что и до этой правки.
    'inline_png_b64': inlinePngB64,
    if (format.isNotEmpty && format != 'png') 'format': format,
    if (animated) 'animated': true,
    if (emojiHint.isNotEmpty) 'emoji_hint': emojiHint,
    if (label.isNotEmpty) 'label': label,
    if (blobId.isNotEmpty) 'blob_id': blobId,
    if (fileKeyB64.isNotEmpty) 'file_key_b64': fileKeyB64,
    if (accessTokenB64.isNotEmpty) 'access_token_b64': accessTokenB64,
    if (sizeBytes != null) 'size_bytes': sizeBytes,
  };

  static StickerPackChunkSticker? fromJson(Map<String, Object?> j) {
    final id = j['sticker_id'];
    if (id is! String || id.isEmpty) return null;

    final png = j['inline_png_b64'];
    final inline = png is String ? png : '';
    final blobId = j['blob_id'] is String ? (j['blob_id'] as String).trim() : '';
    final fileKey = j['file_key_b64'] is String
        ? (j['file_key_b64'] as String).trim()
        : '';

    // 🔴 Годится ЛИБО пиксели, ЛИБО полная пара блоба. Стикер без того и другого
    // достать нечем, а блоб без ключа нечем расшифровать — принять такой значило
    // бы записать в набор дыру, которую человек примет за поломку.
    final hasInline = inline.isNotEmpty;
    final hasBlob = blobId.isNotEmpty && fileKey.isNotEmpty;
    if (!hasInline && !hasBlob) return null;

    final size = j['size_bytes'];
    return StickerPackChunkSticker(
      stickerId: id,
      inlinePngB64: inline,
      format: (j['format'] as String?) ?? 'png',
      animated: j['animated'] == true,
      emojiHint: (j['emoji_hint'] as String?) ?? '',
      label: (j['label'] as String?) ?? '',
      blobId: hasBlob ? blobId : '',
      fileKeyB64: hasBlob ? fileKey : '',
      accessTokenB64: j['access_token_b64'] is String
          ? (j['access_token_b64'] as String).trim()
          : '',
      sizeBytes: size is num ? size.toInt() : null,
    );
  }
}

/// One response batch. `seq` is 0-based; `done` marks the last chunk so the
/// requester can finalise the install.
class StickerPackChunk {
  const StickerPackChunk({
    required this.requestId,
    required this.packId,
    required this.packTitle,
    required this.totalCount,
    required this.seq,
    required this.done,
    required this.stickers,
  });

  final String requestId;
  final String packId;
  final String packTitle;

  /// Count of inline-able stickers the responder will ship across all chunks
  /// (animated/oversized ones are skipped), so the requester can show progress.
  final int totalCount;
  final int seq;
  final bool done;
  final List<StickerPackChunkSticker> stickers;

  Map<String, Object?> toJson() => {
    'requestId': requestId,
    'packId': packId,
    if (packTitle.isNotEmpty) 'packTitle': packTitle,
    'totalCount': totalCount,
    'seq': seq,
    'done': done,
    'stickers': stickers.map((s) => s.toJson()).toList(growable: false),
  };

  static StickerPackChunk? fromJson(Map<String, Object?> j) {
    final id = j['requestId'];
    final pack = j['packId'];
    if (id is! String || id.isEmpty) return null;
    if (pack is! String || pack.isEmpty) return null;
    int asInt(Object? v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    final rawList = j['stickers'];
    final parsed = <StickerPackChunkSticker>[];
    if (rawList is List) {
      for (final e in rawList) {
        if (e is Map) {
          final s = StickerPackChunkSticker.fromJson(
            Map<String, Object?>.from(e),
          );
          if (s != null) parsed.add(s);
        }
      }
    }
    return StickerPackChunk(
      requestId: id,
      packId: pack,
      packTitle: (j['packTitle'] as String?) ?? '',
      totalCount: asInt(j['totalCount'], parsed.length),
      seq: asInt(j['seq'], 0),
      done: j['done'] == true,
      stickers: List.unmodifiable(parsed),
    );
  }
}

// ---------------------------------------------------------------------------
// Wire encode / decode — same dispatcher shape as peer_history_protocol.dart.
// ---------------------------------------------------------------------------

String encodeStickerPackRequest(StickerPackRequest req) =>
    '$kStickerPackRequestCmdPrefix'
    '${base64Url.encode(utf8.encode(jsonEncode(req.toJson())))}';

StickerPackRequest? parseStickerPackRequest(String text) {
  final m = _decode(text, kStickerPackRequestCmdPrefix);
  if (m == null) return null;
  return StickerPackRequest.fromJson(m);
}

String encodeStickerPackChunk(StickerPackChunk chunk) =>
    '$kStickerPackChunkCmdPrefix'
    '${base64Url.encode(utf8.encode(jsonEncode(chunk.toJson())))}';

StickerPackChunk? parseStickerPackChunk(String text) {
  final m = _decode(text, kStickerPackChunkCmdPrefix);
  if (m == null) return null;
  return StickerPackChunk.fromJson(m);
}

/// Cheap probe so the dispatcher routes to the right parser.
bool isStickerPackCommand(String text) =>
    text.startsWith(kStickerPackRequestCmdPrefix) ||
    text.startsWith(kStickerPackChunkCmdPrefix);

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
