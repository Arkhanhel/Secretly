// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Чем кончилось «Сохранить как…».
enum AttachmentSaveResult {
  /// Файл записан туда, куда попросили.
  saved,

  /// Человек закрыл диалог — это не ошибка и говорить о ней не нужно.
  cancelled,

  /// Файла нет на диске (ещё не подкачали или вложение битое).
  unavailable,

  /// Не удалось записать; текст в [AttachmentSaveOutcome.error].
  failed,
}

class AttachmentSaveOutcome {
  const AttachmentSaveOutcome(this.result, [this.error]);

  final AttachmentSaveResult result;
  final String? error;

  bool get isSaved => result == AttachmentSaveResult.saved;
}

/// «Сохранить как…» для вложения — ОДНА реализация на всё окно.
///
/// 🔴 Почему отдельным файлом. Сохранение жило внутри состояния просмотрщика
/// фотографий, и из ленты его было не достать: снимок можно было сохранить,
/// только открыв его на весь экран. Первый же второй вызов породил бы вторую
/// копию диалога — с другим заголовком, другим именем по умолчанию и,
/// вероятно, без `copy` в try.
///
/// Функция НИЧЕГО не показывает человеку: у просмотрщика свои всплывашки, у
/// ленты свои. Она отвечает, что случилось, и молчит.
Future<AttachmentSaveOutcome> saveAttachmentAs({
  required File? file,
  required String suggestedName,
  String dialogTitle = 'Сохранить',
  FileType type = FileType.any,
}) async {
  if (file == null || !await file.exists()) {
    return const AttachmentSaveOutcome(AttachmentSaveResult.unavailable);
  }
  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: suggestedName,
      type: type,
    );
    if (path == null) {
      return const AttachmentSaveOutcome(AttachmentSaveResult.cancelled);
    }
    await file.copy(path);
    return const AttachmentSaveOutcome(AttachmentSaveResult.saved);
  } catch (e) {
    return AttachmentSaveOutcome(AttachmentSaveResult.failed, e.toString());
  }
}

/// Имя по умолчанию для вложения.
///
/// Настоящее имя файла лучше любого придуманного: человек ищет снимок в
/// «Загрузках» по тому имени, под которым его прислали. Придумываем только
/// когда имени нет вовсе — тогда из идентификатора и типа.
String suggestedAttachmentFileName({
  required String? fileName,
  required String? mime,
  required String blobId,
  String fallbackPrefix = 'secretly',
}) {
  final name = (fileName ?? '').trim();
  if (name.isNotEmpty) return name;
  final m = (mime ?? '').toLowerCase();
  var ext = 'bin';
  const known = <String, String>{
    'image/png': 'png',
    'image/jpeg': 'jpg',
    'image/jpg': 'jpg',
    'image/gif': 'gif',
    'image/webp': 'webp',
    'image/heic': 'heic',
    'video/mp4': 'mp4',
    'video/quicktime': 'mov',
    'audio/opus': 'opus',
    'audio/ogg': 'ogg',
    'audio/mpeg': 'mp3',
    'application/pdf': 'pdf',
  };
  ext = known[m] ?? (m.startsWith('image/') ? 'jpg' : 'bin');
  final clean = blobId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
  final short = clean.length > 12 ? clean.substring(0, 12) : clean;
  return '$fallbackPrefix-$short.$ext';
}

/// Имя файла, пригодное для записи на диск.
///
/// 🔴 ИМЯ ПРИСЛАЛ ДРУГОЙ ЧЕЛОВЕК. «../../.ssh/authorized_keys» или имя с
/// двоеточием не должны вывести запись за пределы папки. Оставляем только
/// последнюю часть пути, без разделителей и управляющих знаков, без точки в
/// начале (скрытый файл) и не длиннее 120 знаков.
String safeDownloadFileName(String name) {
  var clean = p.basename(name.replaceAll('\\', '/'));
  clean = clean.replaceAll(RegExp(r'[/:*?"<>|\x00-\x1F]'), '_').trim();
  while (clean.startsWith('.')) {
    clean = clean.substring(1);
  }
  if (clean.isEmpty) clean = 'file';
  if (clean.length > 120) {
    final ext = p.extension(clean);
    final keep = ext.length < 16 ? ext : '';
    clean = clean.substring(0, 120 - keep.length) + keep;
  }
  return clean;
}

/// Копия вложения в «Загрузки/Secretly» — для «Показать в Finder».
///
/// Как в Telegram: скачанный файл лежит в «Загрузках» под своим именем. Сам
/// расшифрованный файл при этом остаётся в хранилище приложения, а копия
/// появляется только по нажатию. Если такой же файл (того же размера) там уже
/// лежит — берём его, а не плодим «(1)», «(2)».
Future<File> exportAttachmentToDownloads(
  File source,
  String fileName, {
  Directory? downloadsOverride,
}) async {
  final downloads =
      downloadsOverride ??
      await getDownloadsDirectory() ??
      Directory(p.join(Platform.environment['HOME'] ?? '', 'Downloads'));
  final dir = Directory(p.join(downloads.path, 'Secretly'));
  await dir.create(recursive: true);
  final safe = safeDownloadFileName(fileName);
  final stem = p.basenameWithoutExtension(safe);
  final ext = p.extension(safe);
  final sourceLength = await source.length();
  var target = File(p.join(dir.path, safe));
  var index = 1;
  while (await target.exists()) {
    if (await target.length() == sourceLength) return target;
    target = File(p.join(dir.path, '$stem ($index)$ext'));
    index++;
  }
  return source.copy(target.path);
}

/// Папка временных копий, которые открывает внешняя программа.
Directory attachmentOpenCopyDir({Directory? root}) => Directory(
  p.join((root ?? Directory.systemTemp).path, 'secretly_open'),
);

/// Временная копия вложения под НАСТОЯЩИМ именем — её и открывает система.
///
/// 🔴 ЗАЧЕМ КОПИЯ (17.09.2026). Из кэша файл уходил как есть, а там он лежит
/// под именем `<идентификатор>.bin`: система не понимала, чем его открыть, и
/// человек получал либо «выберите программу», либо ничего. Вдобавок чужая
/// программа получала путь ВНУТРЬ нашего расшифрованного кэша и могла
/// переписать файл, которым мы же и пользуемся.
///
/// Копия лежит в отдельной папке во временных файлах, по подпапке на вложение
/// (одинаковые имена от разных людей не затирают друг друга) и стирается при
/// следующем запуске — см. [clearAttachmentOpenCopies].
Future<File> attachmentOpenCopy({
  required File file,
  required String suggestedName,
  required String blobId,
  Directory? root,
}) async {
  final clean = blobId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
  final bucket = clean.isEmpty
      ? 'x'
      : (clean.length > 16 ? clean.substring(0, 16) : clean);
  final dir = Directory(
    p.join(attachmentOpenCopyDir(root: root).path, bucket),
  );
  await dir.create(recursive: true);
  final target = File(p.join(dir.path, safeDownloadFileName(suggestedName)));
  // Повторное открытие того же вложения не копирует его заново.
  if (await target.exists() &&
      await target.length() == await file.length()) {
    return target;
  }
  return file.copy(target.path);
}

/// Стирает временные копии, оставшиеся от прошлых запусков.
///
/// Это расшифрованные файлы: держать их дольше сеанса незачем.
Future<void> clearAttachmentOpenCopies({Directory? root}) async {
  final dir = attachmentOpenCopyDir(root: root);
  try {
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {
    // Занятый файл (программа ещё открыта) — не повод падать при запуске.
  }
}

/// Показать файл в Finder (Проводнике, файловом менеджере).
Future<void> revealInFileManager(String path) async {
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', path]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', ['/select,', path]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [File(path).parent.path]);
  } else {
    await launchUrl(Uri.file(File(path).parent.path));
  }
}
