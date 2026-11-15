// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Where decrypted chat media lives on disk.
///
/// 🔴 WHY (media audit 15.11.2026, item П2). On iPhone, `Info.plist` turns on
/// `UIFileSharingEnabled` so «Save to Files» (`Documents/Secretly`) shows up in
/// the Files app. But that shows the WHOLE `Documents` folder, and decrypted
/// chat media lived in `Documents/attachments`. Anyone holding the unlocked
/// phone, or a Mac it is plugged into, could browse every received photo and
/// video in Files or Finder without passing the Secretly lock.
///
/// HOW. On iOS the cache moves to `Library/Application Support/attachments`,
/// which Files and Finder do not show. Nothing else changes: iCloud backup
/// still includes the folder as before (whether to exclude it is the owner's
/// call). Backup keys stay `attachments/<file>` and the file names stay the
/// same, so old and new builds read each other's backups.
///
/// Old files move by `rename` (same volume, atomic, no copy). It happens in two
/// ways, so nothing is ever unreachable:
///   · in bulk at startup, [migrateLegacyIosAttachmentCache];
///   · per file on demand, [resolveAttachmentCacheFile], in case a file is
///     needed before the bulk move has reached it, or a restore from an old
///     backup has just written it into the old place.
/// A file that exists in both places keeps the new copy; the old one is
/// removed when it has the same size, otherwise set aside into
/// [kAttachmentCacheConflictsDirName] (also hidden from Files) — never deleted.
///
/// ⚠ No way back: a build older than 676 on iOS looks only in
/// `Documents/attachments` and shows chat media as missing until the newer
/// build is installed again (the files are still on disk).
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../diagnostics/diag_log.dart';

/// Folder name, the same on every platform and in backup keys.
const String kAttachmentCacheDirName = 'attachments';

/// Next to the moved cache: old copies that differed from the new one.
const String kAttachmentCacheConflictsDirName = 'attachments_move_conflicts';

/// Does this platform keep the media cache outside `Documents`?
@visibleForTesting
bool attachmentCacheLivesInAppSupport(TargetPlatform platform) =>
    !kIsWeb && platform == TargetPlatform.iOS;

/// Parent of the `attachments` folder: Application Support on iOS,
/// `Documents` everywhere else (unchanged).
///
/// The answer cannot change while the app runs, and this is asked on every
/// media lookup, so it is asked of the platform once (a failed answer is not
/// remembered).
///
/// Only iOS remembers it: elsewhere the answer is exactly the old
/// `getApplicationDocumentsDirectory()` call, asked every time as before (tests
/// swap that folder between cases).
Future<Directory> attachmentCacheParentDirectory() {
  if (!attachmentCacheLivesInAppSupport(defaultTargetPlatform)) {
    return getApplicationDocumentsDirectory();
  }
  final known = _parent;
  if (known != null) return known;
  final next = getApplicationSupportDirectory();
  _parent = next;
  next.catchError((Object _) {
    if (identical(_parent, next)) _parent = null;
    return Directory('');
  });
  return next;
}

Future<Directory>? _parent;
Future<Directory?>? _legacy;

/// The `attachments` folder itself (not created).
Future<Directory> attachmentCacheDirectory() async =>
    Directory(p.join((await attachmentCacheParentDirectory()).path,
        kAttachmentCacheDirName));

/// The old `Documents/attachments` folder, or `null` where nothing moved.
Future<Directory?> legacyAttachmentCacheDirectory() {
  if (!attachmentCacheLivesInAppSupport(defaultTargetPlatform)) {
    return Future<Directory?>.value(null);
  }
  final known = _legacy;
  if (known != null) return known;
  final next = getApplicationDocumentsDirectory().then<Directory?>(
    (docs) => Directory(p.join(docs.path, kAttachmentCacheDirName)),
  );
  _legacy = next;
  next.catchError((Object _) {
    if (identical(_legacy, next)) _legacy = null;
    return null;
  });
  return next;
}

/// Returns [target]; if it is missing but the same name sits in [legacyDir],
/// moves it over first. Never throws: on any error the caller simply sees a
/// missing file, exactly as before.
Future<File> adoptLegacyAttachmentFile({
  required File target,
  required Directory? legacyDir,
}) async {
  if (legacyDir == null) return target;
  try {
    if (await target.exists()) return target;
    final legacy = File(p.join(legacyDir.path, p.basename(target.path)));
    if (!await legacy.exists()) return target;
    await target.parent.create(recursive: true);
    await legacy.rename(target.path);
  } catch (e) {
    DiagLog.event('media', 'attachment_cache_adopt_failed', {
      'err': e.runtimeType.toString(),
    });
  }
  return target;
}

/// Moves every file from [legacyDir] into [targetDir]. Returns how many moved.
/// Removes [legacyDir] once it is empty.
@visibleForTesting
Future<int> moveLegacyAttachmentFiles({
  required Directory legacyDir,
  required Directory targetDir,
}) async {
  if (!await legacyDir.exists()) return 0;
  await targetDir.create(recursive: true);
  var moved = 0;
  await for (final entity in legacyDir.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    final dest = File(p.join(targetDir.path, name));
    try {
      if (await dest.exists()) {
        // Already there (moved on demand, or downloaded again — downloads land
        // through a temp file and a rename, so [dest] is complete). The same
        // size: the same file, the old copy goes. A different size: one of the
        // two is damaged; keep [dest], and set the old one aside where Files
        // cannot see it rather than delete what might be the better copy.
        if (await dest.length() == await entity.length()) {
          await entity.delete();
        } else {
          final aside = Directory(
            p.join(p.dirname(targetDir.path), kAttachmentCacheConflictsDirName),
          );
          await aside.create(recursive: true);
          await entity.rename(p.join(aside.path, name));
        }
        continue;
      }
      await entity.rename(dest.path);
      moved++;
    } catch (_) {
      // Best effort per file; the on-demand path still finds it later.
    }
  }
  try {
    if (await legacyDir.list().isEmpty) await legacyDir.delete();
  } catch (_) {}
  return moved;
}

/// Bulk move on iOS; a no-op elsewhere and when there is nothing to move.
/// Safe to call on every launch: the check is one `exists`.
Future<void> migrateLegacyIosAttachmentCache() async {
  try {
    final legacy = await legacyAttachmentCacheDirectory();
    if (legacy == null || !await legacy.exists()) return;
    final moved = await moveLegacyAttachmentFiles(
      legacyDir: legacy,
      targetDir: await attachmentCacheDirectory(),
    );
    DiagLog.event('media', 'attachment_cache_moved', {
      'files': moved,
      'legacy_left': await legacy.exists(),
    });
  } catch (e) {
    DiagLog.event('media', 'attachment_cache_move_failed', {
      'err': e.runtimeType.toString(),
    });
  }
}
