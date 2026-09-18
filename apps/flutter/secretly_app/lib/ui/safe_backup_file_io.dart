// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const secretlyBackupFileExtension = 'secretly-backup';

enum SafeBackupFileCandidateLocation { appLocal, downloads, externalFolder }

class SafeBackupFileCandidate {
  const SafeBackupFileCandidate({
    required this.path,
    required this.displayName,
    required this.location,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  final String path;
  final String displayName;
  final SafeBackupFileCandidateLocation location;
  final DateTime modifiedAt;
  final int sizeBytes;
}

String safeBackupSuggestedFileName({DateTime? now}) {
  final dt = (now ?? DateTime.now()).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return 'Secretly_Backup_${dt.year}-${two(dt.month)}-${two(dt.day)}_${two(dt.hour)}-${two(dt.minute)}.$secretlyBackupFileExtension';
}

Future<String?> pickSafeBackupPayloadFromFile({String? dialogTitle}) async {
  // 🔴 `withData: false` — НЕ втягивать копию в память через плагин
  // (06.08.2026, полевой отказ восстановления).
  //
  // Было `true`, и это убивало приложение на копии с медиа. Плагин выбора
  // файла читает файл целиком в байтовый массив на СТОРОНЕ JAVA, а её куча
  // ограничена `dalvik.vm.heapgrowthlimit` — на телефоне из отчёта это 256 МБ
  // при копии в 278 МБ. Выделение больше всей кучи не может удаться никогда:
  //
  //   java.lang.OutOfMemoryError: Failed to allocate a 291669464 byte
  //   allocation ... growth limit 268435456        (размер файла + 15 байт)
  //
  // Процесс падал ДО того, как что-либо успевало произойти в Dart, — человек
  // видел просто исчезнувшее приложение, без единого слова об ошибке.
  //
  // И эти байты были не нужны: ветка ниже предпочитает ПУТЬ и перечитывает
  // файл сама. То есть 278 МБ выделялись, чтобы быть выброшенными.
  //
  // Чтение по пути идёт средствами Dart, а его память — не ART-куча, и под
  // этот потолок не попадает.
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: dialogTitle,
    allowMultiple: false,
    type: FileType.custom,
    allowedExtensions: const <String>[secretlyBackupFileExtension, 'secretly'],
    withData: false,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  final path = file.path;
  if (path != null && path.trim().isNotEmpty) {
    return readSafeBackupPayloadFromPath(path);
  }

  // Запасной путь: платформа не дала пути (выбор через поставщика документов
  // без файла на диске). Байты тут появятся только если плагин их всё же
  // приложил; просить их заранее нельзя — см. выше.
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) return null;
  final raw = utf8.decode(bytes);
  return raw.trim().isEmpty ? null : raw.trim();
}

Future<String?> readSafeBackupPayloadFromPath(String path) async {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) return null;
  final raw = await File(normalizedPath).readAsString();
  return raw.trim().isEmpty ? null : raw.trim();
}

Future<List<SafeBackupFileCandidate>> discoverSafeBackupFilesOnDevice({
  int limit = 24,
}) async {
  final candidatesByPath = <String, SafeBackupFileCandidate>{};

  Future<void> addFile(
    File file,
    SafeBackupFileCandidateLocation location,
  ) async {
    final name = p.basename(file.path);
    if (!_looksLikeSafeBackupFileName(name)) return;
    final key = file.absolute.path;
    if (candidatesByPath.containsKey(key)) return;
    try {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file || stat.size <= 0) return;
      candidatesByPath[key] = SafeBackupFileCandidate(
        path: file.path,
        displayName: name,
        location: location,
        modifiedAt: stat.modified,
        sizeBytes: stat.size,
      );
    } catch (_) {}
  }

  Future<void> scanDirectory(
    Directory directory,
    SafeBackupFileCandidateLocation location, {
    int depth = 0,
  }) async {
    if (candidatesByPath.length >= limit * 3) return;
    try {
      if (!await directory.exists()) return;
      await for (final entity in directory.list(followLinks: false)) {
        if (candidatesByPath.length >= limit * 3) break;
        if (entity is File) {
          await addFile(entity, location);
        } else if (depth > 0 && entity is Directory) {
          final name = p.basename(entity.path);
          if (name.startsWith('.')) continue;
          await scanDirectory(entity, location, depth: depth - 1);
        }
      }
    } catch (_) {}
  }

  try {
    final docs = await getApplicationDocumentsDirectory();
    await scanDirectory(
      Directory(p.join(docs.path, 'safe_backups')),
      SafeBackupFileCandidateLocation.appLocal,
    );
    await scanDirectory(docs, SafeBackupFileCandidateLocation.appLocal);
  } catch (_) {}

  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      await scanDirectory(
        downloads,
        SafeBackupFileCandidateLocation.downloads,
        depth: 2,
      );
    }
  } catch (_) {}

  if (Platform.isAndroid) {
    for (final path in const <String>[
      '/storage/emulated/0/Download',
      '/sdcard/Download',
    ]) {
      await scanDirectory(
        Directory(path),
        SafeBackupFileCandidateLocation.downloads,
        depth: 2,
      );
    }
  }

  final candidates = candidatesByPath.values.toList(growable: false)
    ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  if (candidates.length <= limit) return candidates;
  return candidates.take(limit).toList(growable: false);
}

Future<bool> exportSafeBackupFile({
  required String sourcePath,
  required String suggestedFileName,
  Future<void> Function(String savedPath)? onSavedPath,
}) async {
  final source = File(sourcePath);
  if (!await source.exists()) {
    throw StateError('Backup file is missing');
  }

  try {
    final pickedPath = await FilePicker.platform.saveFile(
      fileName: suggestedFileName,
    );
    if (pickedPath != null && pickedPath.isNotEmpty) {
      final targetPath = _withBackupExtension(pickedPath);
      final target = File(targetPath);
      await target.parent.create(recursive: true);
      await source.copy(target.path);
      await onSavedPath?.call(target.path);
      return true;
    }
    return false;
  } catch (_) {
    final docs = await getApplicationDocumentsDirectory();
    final target = File(
      p.join(
        docs.path,
        'safe_backups',
        _withBackupExtension(suggestedFileName),
      ),
    );
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    await onSavedPath?.call(target.path);
    return true;
  }
}

String _withBackupExtension(String path) {
  final ext = p.extension(path).toLowerCase();
  if (ext == '.$secretlyBackupFileExtension' || ext == '.secretly') {
    return path;
  }
  return '$path.$secretlyBackupFileExtension';
}

bool _looksLikeSafeBackupFileName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.$secretlyBackupFileExtension') ||
      lower.endsWith('.secretly');
}
