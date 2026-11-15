// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../desktop/windows_private_documents.dart'
    show kLegacyDocumentsDirs, kLegacyDocumentsFilePatterns;
import 'profile_space.dart';
import 'serialized_secure_storage.dart';

/// Стирание данных одного пространства профиля (Э2).
///
/// Работает по настоящим путям, минуя обёртку пространства, поэтому может
/// стереть `alt`, находясь в `main`, и наоборот. Сервер не трогается
/// намеренно: сетевой запрос в момент принуждения — утечка; устройство на
/// сервере отомрёт по неактивности.
///
/// 🔴 Записи замка (PIN, код принуждения, счётчик) здесь НЕ стираются: они
/// общие, и по ним выбирается пространство. Их снимает только
/// `AppSecurityManager.disableLock`.
class ProfileSpaceWipe {
  ProfileSpaceWipe._();

  static const List<String> _dbFileNames = <String>[
    'secretly.db',
    'secretly.db-wal',
    'secretly.db-shm',
    'secretly.db-journal',
  ];

  static const List<String> _dbBackupPrefixes = <String>[
    'secretly.db.unencrypted_backup_',
    'secretly.db.corrupt_backup_',
    'secretly.db.superseded_',
  ];

  /// Каталоги в Documents, которых нет в перечне Windows, но которые тоже
  /// принадлежат профилю.
  static const List<String> _extraDocumentsDirs = <String>['stickers'];

  static const List<String> _supportDirs = <String>[
    'voice_transcripts',
    'recent_attachments',
  ];

  static Future<void> wipe(ProfileSpace space) async {
    final inner = ProfileSpaceRuntime.innerPathProvider;
    final docs = await inner.getApplicationDocumentsPath();
    final support = await inner.getApplicationSupportPath();
    final temp = await inner.getTemporaryPath();

    if (space == ProfileSpace.alt) {
      for (final root in <String?>[docs, support, temp]) {
        if (root == null || root.isEmpty) continue;
        await _deleteDir(p.join(root, ProfileSpaceRuntime.altSubdir));
      }
      await _wipeSecrets(space);
      await _wipePrefs(space);
      return;
    }

    for (final root in <String?>[docs, support]) {
      if (root == null || root.isEmpty) continue;
      await _deleteDbFiles(root);
    }
    if (docs != null && docs.isNotEmpty) {
      for (final name in <String>[
        ...kLegacyDocumentsDirs,
        ..._extraDocumentsDirs,
      ]) {
        await _deleteDir(p.join(docs, name));
      }
      await _deleteMatchingFiles(docs, kLegacyDocumentsFilePatterns);
    }
    if (support != null && support.isNotEmpty) {
      for (final name in _supportDirs) {
        await _deleteDir(p.join(support, name));
      }
    }
    if (temp != null && temp.isNotEmpty) {
      await _deleteChildrenExcept(temp, except: <String>{'spaces'});
    }
    await _wipeSecrets(space);
    await _wipePrefs(space);
  }

  static Future<void> _wipeSecrets(ProfileSpace space) async {
    final altPrefix = ProfileSpaceRuntime.altSecureStoragePrefix;
    if (space == ProfileSpace.alt) {
      await SerializedSecureStorage.deleteRawKeysWhere(
        (k) => k.startsWith(altPrefix),
      );
      return;
    }
    await SerializedSecureStorage.deleteRawKeysWhere(
      (k) => !SerializedSecureStorage.isGlobalKey(k) && !k.startsWith('space/'),
    );
  }

  static Future<void> _wipePrefs(ProfileSpace space) async {
    if (ProfileSpaceRuntime.entered && ProfileSpaceRuntime.active == space) {
      try {
        await (await SharedPreferences.getInstance()).clear();
        return;
      } catch (_) {
        // Ниже — отложенное стирание.
      }
    }
    await ProfileSpaceRuntime.markPrefsWipePending(space);
  }

  static Future<void> _deleteDbFiles(String root) async {
    for (final name in _dbFileNames) {
      await _deleteFile(p.join(root, name));
    }
    try {
      await for (final e in Directory(root).list(followLinks: false)) {
        if (e is! File) continue;
        final name = p.basename(e.path);
        if (_dbBackupPrefixes.any(name.startsWith)) {
          await _deleteFile(e.path);
        }
      }
    } catch (_) {}
  }

  static Future<void> _deleteMatchingFiles(
    String root,
    List<RegExp> patterns,
  ) async {
    try {
      await for (final e in Directory(root).list(followLinks: false)) {
        if (e is! File) continue;
        final name = p.basename(e.path);
        if (patterns.any((re) => re.hasMatch(name))) {
          await _deleteFile(e.path);
        }
      }
    } catch (_) {}
  }

  static Future<void> _deleteChildrenExcept(
    String root, {
    required Set<String> except,
  }) async {
    try {
      await for (final e in Directory(root).list(followLinks: false)) {
        if (except.contains(p.basename(e.path))) continue;
        if (e is Directory) {
          await _deleteDir(e.path);
        } else if (e is File) {
          await _deleteFile(e.path);
        }
      }
    } catch (_) {}
  }

  static Future<void> _deleteDir(String path) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  static Future<void> _deleteFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
