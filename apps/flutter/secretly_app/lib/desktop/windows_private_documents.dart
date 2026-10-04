// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// «Документы» приложения на Windows — своя папка, а не общие «Документы».
///
/// 🔴 ЗАЧЕМ (30.09.2026). `getApplicationDocumentsDirectory()` на Windows
/// отвечает папкой «Документы» самого человека (FOLDERID_Documents), и
/// приложение раскладывало прямо в неё:
///   · `attachments\` — РАСШИФРОВАННЫЕ вложения;
///   · `contact_avatars\<полный ID профиля>.png` — список контактов в именах
///     файлов, `cover_cache_<ID>_….png` — обложки собеседников;
///   · свои фото и видео профиля, переписку с поддержкой, журнал личности.
/// На Windows 11 «Документы» по умолчанию синхронизирует OneDrive, то есть
/// расшифрованные вложения уезжали в облако. На телефонах и Mac «Документы» —
/// личный контейнер приложения, там этой беды нет. База уехала в папку
/// приложения 26.09.2026 (`AppDb.databaseDirectory`), медиа — остались.
///
/// КАК. Общий код продолжает звать `getApplicationDocumentsDirectory()` — его
/// тридцать мест не трогаются (телефон заморожен). На Windows ответ подменяется
/// на `%APPDATA%\<компания>\<продукт>\documents` — рядом с базой и ключом.
/// Прежнее содержимое переносится ОДИН раз и только то, что создал сам
/// Secretly: по точным именам папок и шаблонам имён файлов. Чужие файлы
/// человека в «Документах» не трогаются никогда.
///
/// ЧТО ОСТАЁТСЯ НА МЕСТЕ И ПОЧЕМУ. `stickers\` и `cosmetics\` — общедоступные
/// картинки каталога; пути к наборам лежат в базе абсолютными, а
/// перепривязка путей наборов в общем коде идёт только после восстановления
/// из копии. Перенесённые, они перестали бы рисоваться. Приватного в них нет.
/// Пути к фото собеседников и своим медиа после переноса чинит сам
/// контроллер: `_rebaseRestoredImagePaths` и `_rebaseOwnMediaPointers`
/// переписывают мёртвые указатели по имени файла на КАЖДОМ запуске.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Имя своей папки «Документов» внутри папки приложения.
const String kWindowsPrivateDocumentsDirName = 'documents';

/// Метка «перенос уже сделан» — в новой папке.
const String kWindowsDocumentsMigratedMarker = '.moved_from_user_documents_v1';

/// Папки, которые Secretly создавал в «Документах» (см. `CacheManager` и
/// `_restorableImageSubDirs` в контроллере).
const List<String> kLegacyDocumentsDirs = <String>[
  'attachments',
  'contact_avatars',
  'room_avatars',
  'profile_avatars',
  'profile_media',
  'demo_avatars',
  'safe_backups',
];

/// Файлы, которые Secretly клал в корень «Документов». Шаблоны точные:
/// «my_avatar.jpg» человека совпасть с ними не может.
final List<RegExp> kLegacyDocumentsFilePatterns = <RegExp>[
  RegExp(r'^my_avatar\.png$'),
  RegExp(r'^my_avatar_(original_)?\d+\.(png|img)$'),
  RegExp(r'^cover_custom_\d+\.png$'),
  RegExp(r'^cover_video_(still_)?\d+\.(mp4|png)$'),
  RegExp(r'^avatar_video_(still_)?\d+\.(mp4|png)$'),
  RegExp(r'^cover_cache_[A-Za-z0-9_-]+_\d+\.png$'),
  RegExp(r'^support_thread_[A-Za-z0-9_-]*\.json$'),
  RegExp(r'^secretly_identity_journal\.jsonl$'),
];

/// Принадлежит ли запись корня «Документов» самому Secretly.
bool isLegacySecretlyDocumentsEntry(String name, {required bool isDirectory}) {
  if (isDirectory) return kLegacyDocumentsDirs.contains(name);
  return kLegacyDocumentsFilePatterns.any((re) => re.hasMatch(name));
}

/// Подменяет только «Документы»; всё остальное — как у настоящей реализации.
class _PrivateDocumentsPathProvider extends PathProviderPlatform {
  _PrivateDocumentsPathProvider(this._inner, this._documentsPath);

  final PathProviderPlatform _inner;
  final String _documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    final dir = Directory(_documentsPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    return _documentsPath;
  }

  @override
  Future<String?> getTemporaryPath() => _inner.getTemporaryPath();

  @override
  Future<String?> getApplicationSupportPath() =>
      _inner.getApplicationSupportPath();

  @override
  Future<String?> getLibraryPath() => _inner.getLibraryPath();

  @override
  Future<String?> getApplicationCachePath() => _inner.getApplicationCachePath();

  @override
  Future<String?> getExternalStoragePath() => _inner.getExternalStoragePath();

  @override
  Future<List<String>?> getExternalCachePaths() =>
      _inner.getExternalCachePaths();

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) =>
      _inner.getExternalStoragePaths(type: type);

  @override
  Future<String?> getDownloadsPath() => _inner.getDownloadsPath();
}

/// Что сделал перенос — для журнала.
class WindowsDocumentsMigration {
  const WindowsDocumentsMigration({
    required this.moved,
    required this.skipped,
    required this.failed,
  });

  final int moved;
  final int skipped;
  final int failed;
}

/// Ставит подмену и переносит прежнее содержимое. Вызывать один раз, в
/// `main` до `runApp` и ПОСЛЕ замка единственного экземпляра: переносить
/// файлы из-под работающей копии нельзя. Не бросает никогда: запуск важнее.
///
/// [onWindows] — подмена площадки для тестов (CI гоняет их на Linux).
Future<WindowsDocumentsMigration?> installWindowsPrivateDocuments({
  @visibleForTesting bool? onWindows,
  @visibleForTesting PathProviderPlatform? platform,
}) async {
  if (!(onWindows ?? (!kIsWeb && Platform.isWindows))) return null;
  try {
    final inner = platform ?? PathProviderPlatform.instance;
    if (inner is _PrivateDocumentsPathProvider) return null;
    final support = await inner.getApplicationSupportPath();
    final userDocs = await inner.getApplicationDocumentsPath();
    if (support == null || support.isEmpty) return null;
    final privateDocs = p.join(support, kWindowsPrivateDocumentsDirName);
    PathProviderPlatform.instance = _PrivateDocumentsPathProvider(
      inner,
      privateDocs,
    );
    if (userDocs == null || userDocs.isEmpty) return null;
    return await migrateLegacyDocuments(
      from: Directory(userDocs),
      to: Directory(privateDocs),
    );
  } catch (_) {
    return null;
  }
}

/// Переносит записи Secretly из [from] в [to] один раз.
///
/// Файл за файлом и без перезаписи: если в новой папке уже лежит файл с тем
/// же именем, он новее — старый остаётся на месте. Переименование, а не
/// копирование: на одном диске оно мгновенно и атомарно; на разных дисках
/// (редкость — «Документы» перенесены на D:) — копия, и исходник удаляется
/// только после удачной копии.
@visibleForTesting
Future<WindowsDocumentsMigration> migrateLegacyDocuments({
  required Directory from,
  required Directory to,
}) async {
  var moved = 0;
  var skipped = 0;
  var failed = 0;
  final marker = File(p.join(to.path, kWindowsDocumentsMigratedMarker));
  if (await marker.exists()) {
    return const WindowsDocumentsMigration(moved: 0, skipped: 0, failed: 0);
  }
  await to.create(recursive: true);
  if (await from.exists() &&
      p.normalize(p.absolute(from.path)) != p.normalize(p.absolute(to.path))) {
    final entries = await from.list(followLinks: false).toList();
    for (final entity in entries) {
      final name = p.basename(entity.path);
      final isDir = entity is Directory;
      if (entity is! File && !isDir) continue;
      if (!isLegacySecretlyDocumentsEntry(name, isDirectory: isDir)) continue;
      final r = await _moveEntry(entity, p.join(to.path, name));
      moved += r.moved;
      skipped += r.skipped;
      failed += r.failed;
    }
  }
  // Метка ставится и при частичной неудаче: повтор на каждом запуске не
  // вылечит файл, который не переносится (занят, нет места), а лишь
  // затормозит старт. Оставшееся лежит на старом месте и не теряется.
  try {
    await marker.writeAsString(
      'moved=$moved skipped=$skipped failed=$failed\n',
      flush: true,
    );
  } catch (_) {}
  return WindowsDocumentsMigration(
    moved: moved,
    skipped: skipped,
    failed: failed,
  );
}

Future<({int moved, int skipped, int failed})> _moveEntry(
  FileSystemEntity entity,
  String target,
) async {
  if (entity is File) {
    if (await FileSystemEntity.type(target, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return (moved: 0, skipped: 1, failed: 0);
    }
    try {
      await entity.rename(target);
      return (moved: 1, skipped: 0, failed: 0);
    } on FileSystemException {
      try {
        await entity.copy(target);
        await entity.delete();
        return (moved: 1, skipped: 0, failed: 0);
      } catch (_) {
        // Недокопированный хвост не оставляем: иначе при следующем запуске
        // он выглядел бы «уже перенесённым», а исходник — лишним.
        try {
          final partial = File(target);
          if (await partial.exists()) await partial.delete();
        } catch (_) {}
        return (moved: 0, skipped: 0, failed: 1);
      }
    }
  }
  if (entity is Directory) {
    // Целиком — если в новой папке такой ещё нет (обычный случай).
    if (await FileSystemEntity.type(target, followLinks: false) ==
        FileSystemEntityType.notFound) {
      try {
        await entity.rename(target);
        return (moved: 1, skipped: 0, failed: 0);
      } on FileSystemException {
        // Другой диск — ниже, по одному файлу.
      }
    }
    var moved = 0;
    var skipped = 0;
    var failed = 0;
    await Directory(target).create(recursive: true);
    final children = await entity.list(followLinks: false).toList();
    for (final child in children) {
      if (child is! File && child is! Directory) continue;
      final r = await _moveEntry(child, p.join(target, p.basename(child.path)));
      moved += r.moved;
      skipped += r.skipped;
      failed += r.failed;
    }
    // Пустая старая папка не нужна; непустая (пропущенное) — остаётся.
    try {
      if (await entity.list().isEmpty) await entity.delete();
    } catch (_) {}
    return (moved: moved, skipped: skipped, failed: failed);
  }
  return (moved: 0, skipped: 0, failed: 0);
}
