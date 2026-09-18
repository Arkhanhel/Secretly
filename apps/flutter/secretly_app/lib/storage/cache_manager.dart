// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Per-category disk usage snapshot (all values in bytes).
///
/// Categories mirror the on-disk cache layout audited in
/// `docs/AUDIT_2026-06-18_OFFLINE_PERF_CACHE_FREEMIUM.md` §D. Each field is the
/// total size of the files under that cache directory; [total] is their sum.
class CacheUsage {
  const CacheUsage({
    this.attachmentsBytes = 0,
    this.attachmentsIrreplaceableBytes = 0,
    this.contactAvatarsBytes = 0,
    this.coverCacheBytes = 0,
    this.notoEmojiBytes = 0,
    this.voiceTranscriptsBytes = 0,
    this.whisperModelBytes = 0,
    this.recentAttachmentsBytes = 0,
    this.stickersBytes = 0,
    this.profileMediaBytes = 0,
  });

  /// Cached decrypted chat media (`<docs>/attachments/`). Partially
  /// re-fetchable — see [attachmentsIrreplaceableBytes].
  final int attachmentsBytes;

  /// TZ E0 (2026-07-18): the subset of [attachmentsBytes] that is the ONLY
  /// copy (referenced by chat history with no live relay blob to re-download
  /// from — own-sent `local:` media and anything past the blob TTL).
  /// [clearMediaCache] never deletes these, so [clearableBytes] excludes them.
  /// 0 when the caller didn't supply the protected set (then the whole
  /// attachments dir is treated as protected instead — see computeUsage).
  final int attachmentsIrreplaceableBytes;

  /// Cached peer avatars (`<docs>/contact_avatars/`). Re-fetchable.
  final int contactAvatarsBytes;

  /// Cached peer cosmetic covers (`<docs>/cover_cache_*.png`). Re-fetchable.
  final int coverCacheBytes;

  /// Downloaded animated-emoji Lottie JSON (`<temp>/noto_emoji_*.json`).
  /// Re-fetchable.
  final int notoEmojiBytes;

  /// On-device voice transcripts (`<support>/voice_transcripts/`).
  /// Re-derivable (re-transcribed on demand).
  final int voiceTranscriptsBytes;

  /// The Whisper speech model (`<support>/whisper/`, ~140 MB). Re-downloadable,
  /// but big — only removed via [deleteWhisperModel], never by [clearMediaCache].
  final int whisperModelBytes;

  /// User's durable «recents» re-send copies (`<support>/recent_attachments/`).
  /// NOT re-fetchable — protected.
  final int recentAttachmentsBytes;

  /// Installed sticker assets (`<docs>/stickers/`). Managed by the sticker LRU,
  /// never blanket-wiped by [clearMediaCache].
  final int stickersBytes;

  /// User's OWN published gallery / avatars (`<docs>/profile_media/`,
  /// `<docs>/profile_avatars/`, `<docs>/my_avatar.png`). NOT re-fetchable —
  /// protected.
  final int profileMediaBytes;

  /// Total of everything reported above.
  int get total =>
      attachmentsBytes +
      contactAvatarsBytes +
      coverCacheBytes +
      notoEmojiBytes +
      voiceTranscriptsBytes +
      whisperModelBytes +
      recentAttachmentsBytes +
      stickersBytes +
      profileMediaBytes;

  /// Bytes that [clearMediaCache] would reclaim (the re-fetchable caches only,
  /// minus chat media that has no re-download path — never over-promise).
  int get clearableBytes =>
      (attachmentsBytes - attachmentsIrreplaceableBytes) +
      contactAvatarsBytes +
      coverCacheBytes +
      notoEmojiBytes +
      voiceTranscriptsBytes;

  /// "Media" bucket for the UI: cached media + peer avatars/covers.
  int get mediaBytes =>
      attachmentsBytes + contactAvatarsBytes + coverCacheBytes;
}

/// Computes and clears the app's on-disk caches by walking the known cache
/// directories directly (no DB / controller dependency, so it is safe to call
/// from any screen).
///
/// SAFETY (this ships in a release): [clearMediaCache] deletes ONLY
/// re-fetchable caches. It NEVER touches the SQLCipher database, secure
/// storage / encryption keys, the user's OWN published gallery & avatars
/// (`profile_media/`, `profile_avatars/`, `my_avatar.png`), the durable
/// «recents» copies, the installed sticker assets, or the Whisper model.
/// Cleared media simply re-downloads (or re-derives) the next time it is shown.
class CacheManager {
  CacheManager._();
  static final CacheManager instance = CacheManager._();

  // ---- known cache directory names ---------------------------------------

  // Under getApplicationDocumentsDirectory():
  static const String _attachmentsDir = 'attachments'; // re-fetchable
  static const String _contactAvatarsDir = 'contact_avatars'; // re-fetchable
  static const String _stickersDir = 'stickers'; // protected (LRU-managed)
  static const String _profileMediaDir = 'profile_media'; // protected (own)
  static const String _profileAvatarsDir = 'profile_avatars'; // protected (own)
  static const String _myAvatarFile = 'my_avatar.png'; // protected (own)
  static const String _coverCachePrefix = 'cover_cache_'; // re-fetchable

  // Under getApplicationSupportDirectory():
  static const String _whisperDir = 'whisper'; // big, explicit delete only
  static const String _voiceTranscriptsDir = 'voice_transcripts'; // re-derivable
  static const String _recentAttachmentsDir =
      'recent_attachments'; // protected (durable)

  // Under getTemporaryDirectory():
  static const String _notoEmojiPrefix = 'noto_emoji_'; // re-fetchable
  static const String _notoEmojiSuffix = '.json';

  /// Extracts the blob id a cached attachment file was named after
  /// (`<blobId><ext>` — see the prune in app_controller). Files with no
  /// extension are their own id.
  static String _blobIdOfFileName(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  static bool _isIrreplaceableAttachmentFile(
    String name,
    Set<String> irreplaceable,
  ) {
    return irreplaceable.contains(_blobIdOfFileName(name)) ||
        irreplaceable.contains(name);
  }

  /// Bytes under `<docs>/attachments/` whose file is protected per
  /// [irreplaceable]. `null` set = the answer is unknown → the WHOLE dir
  /// counts as protected (fail-safe: never promise to reclaim what
  /// [clearMediaCache] would then refuse to delete).
  Future<int> _attachmentsProtectedBytes(
    Directory? docs,
    Set<String>? irreplaceable,
  ) async {
    final dir = _sub(docs, _attachmentsDir);
    if (dir == null) return 0;
    if (irreplaceable == null) return _dirSize(dir);
    var total = 0;
    try {
      if (!await dir.exists()) return 0;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!_isIrreplaceableAttachmentFile(name, irreplaceable)) continue;
        try {
          total += await entity.length();
        } catch (_) {}
      }
    } catch (_) {}
    return total;
  }

  /// Sums the sizes of every cache category. Best-effort — any unreadable
  /// directory contributes 0 rather than throwing.
  ///
  /// [irreplaceableAttachmentBlobIds] (TZ E0) marks which cached chat-media
  /// files have NO re-download path (from
  /// `AppController.irreplaceableAttachmentBlobIds()`); pass null when
  /// unknown — the whole attachments dir is then reported protected.
  Future<CacheUsage> computeUsage({
    Set<String>? irreplaceableAttachmentBlobIds,
  }) async {
    Directory? docs;
    Directory? support;
    Directory? temp;
    try {
      docs = await getApplicationDocumentsDirectory();
    } catch (_) {}
    try {
      support = await getApplicationSupportDirectory();
    } catch (_) {}
    try {
      temp = await getTemporaryDirectory();
    } catch (_) {}

    final attachments = await _dirSize(_sub(docs, _attachmentsDir));
    final attachmentsProtected = await _attachmentsProtectedBytes(
      docs,
      irreplaceableAttachmentBlobIds,
    );
    final contactAvatars = await _dirSize(_sub(docs, _contactAvatarsDir));
    final stickers = await _dirSize(_sub(docs, _stickersDir));
    final profileMedia =
        (await _dirSize(_sub(docs, _profileMediaDir))) +
        (await _dirSize(_sub(docs, _profileAvatarsDir))) +
        (await _fileSize(_file(docs, _myAvatarFile)));
    final coverCache = await _matchingFilesSize(
      docs,
      prefix: _coverCachePrefix,
    );

    final whisper = await _dirSize(_sub(support, _whisperDir));
    final voiceTranscripts = await _dirSize(_sub(support, _voiceTranscriptsDir));
    final recents = await _dirSize(_sub(support, _recentAttachmentsDir));

    final noto = await _matchingFilesSize(
      temp,
      prefix: _notoEmojiPrefix,
      suffix: _notoEmojiSuffix,
    );

    return CacheUsage(
      attachmentsBytes: attachments,
      attachmentsIrreplaceableBytes: attachmentsProtected,
      contactAvatarsBytes: contactAvatars,
      coverCacheBytes: coverCache,
      notoEmojiBytes: noto,
      voiceTranscriptsBytes: voiceTranscripts,
      whisperModelBytes: whisper,
      recentAttachmentsBytes: recents,
      stickersBytes: stickers,
      profileMediaBytes: profileMedia,
    );
  }

  /// Deletes ONLY the re-fetchable caches, then clears the in-memory image
  /// cache. Safe to run at any time — cleared media re-downloads/re-derives on
  /// next view. Explicitly does NOT delete: the DB, keys/secure storage,
  /// `profile_media/`, `profile_avatars/`, `my_avatar.png`, `recent_attachments/`,
  /// `stickers/`, the Whisper model — or (TZ E0, 2026-07-18) any cached chat
  /// media that is the ONLY copy ([irreplaceableAttachmentBlobIds]; the local
  /// file for own-sent / TTL-expired blobs cannot be re-downloaded — deleting
  /// it here was silent permanent data loss, contradicting the auto-prune's
  /// protected-set guarantee).
  ///
  /// Pass the set from `AppController.irreplaceableAttachmentBlobIds()`.
  /// `null` (unknown) = fail-safe: the attachments dir is left untouched.
  Future<void> clearMediaCache({
    Set<String>? irreplaceableAttachmentBlobIds,
  }) async {
    Directory? docs;
    Directory? support;
    Directory? temp;
    try {
      docs = await getApplicationDocumentsDirectory();
    } catch (_) {}
    try {
      support = await getApplicationSupportDirectory();
    } catch (_) {}
    try {
      temp = await getTemporaryDirectory();
    } catch (_) {}

    // Chat media: delete ONLY files with a live re-download path (orphans +
    // still-fetchable remote blobs). Unknown protected set → skip entirely.
    if (irreplaceableAttachmentBlobIds != null) {
      await _deleteAttachmentFilesExcept(
        _sub(docs, _attachmentsDir),
        irreplaceableAttachmentBlobIds,
      );
    }
    // Fully re-fetchable directory caches.
    await _deleteDir(_sub(docs, _contactAvatarsDir));
    await _deleteDir(_sub(support, _voiceTranscriptsDir));

    // Re-fetchable loose files in the docs root / temp.
    await _deleteMatchingFiles(docs, prefix: _coverCachePrefix);
    await _deleteMatchingFiles(
      temp,
      prefix: _notoEmojiPrefix,
      suffix: _notoEmojiSuffix,
    );

    // Drop decoded bitmaps so freed disk isn't masked by RAM-resident images.
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
  }

  /// Removes the on-device Whisper model (~140 MB). The model re-downloads
  /// lazily on the next transcription. Does not affect any other cache.
  Future<void> deleteWhisperModel() async {
    Directory? support;
    try {
      support = await getApplicationSupportDirectory();
    } catch (_) {}
    await _deleteDir(_sub(support, _whisperDir));
  }

  // ---- helpers -----------------------------------------------------------

  Directory? _sub(Directory? base, String name) =>
      base == null ? null : Directory(p.join(base.path, name));

  File? _file(Directory? base, String name) =>
      base == null ? null : File(p.join(base.path, name));

  Future<int> _dirSize(Directory? dir) async {
    if (dir == null) return 0;
    var total = 0;
    try {
      if (!await dir.exists()) return 0;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<int> _fileSize(File? file) async {
    if (file == null) return 0;
    try {
      if (await file.exists()) return await file.length();
    } catch (_) {}
    return 0;
  }

  /// Sums sizes of loose files directly under [dir] matching [prefix]/[suffix].
  Future<int> _matchingFilesSize(
    Directory? dir, {
    required String prefix,
    String? suffix,
  }) async {
    if (dir == null) return 0;
    var total = 0;
    try {
      if (!await dir.exists()) return 0;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith(prefix)) continue;
        if (suffix != null && !name.endsWith(suffix)) continue;
        try {
          total += await entity.length();
        } catch (_) {}
      }
    } catch (_) {}
    return total;
  }

  Future<void> _deleteDir(Directory? dir) async {
    if (dir == null) return;
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// Deletes attachment files EXCEPT those protected by [irreplaceable]
  /// (TZ E0). Per-file best-effort so one bad file never aborts the sweep.
  Future<void> _deleteAttachmentFilesExcept(
    Directory? dir,
    Set<String> irreplaceable,
  ) async {
    if (dir == null) return;
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (_isIrreplaceableAttachmentFile(name, irreplaceable)) continue;
        try {
          await entity.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _deleteMatchingFiles(
    Directory? dir, {
    required String prefix,
    String? suffix,
  }) async {
    if (dir == null) return;
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith(prefix)) continue;
        if (suffix != null && !name.endsWith(suffix)) continue;
        try {
          await entity.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }
}
