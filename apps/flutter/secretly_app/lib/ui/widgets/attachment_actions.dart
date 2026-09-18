// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show MethodChannel;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../attachments/attachment_naming.dart';
import '../../diagnostics/diag_log.dart';
import '../../models/e2e_payload_v1.dart';

/// Save / share / naming for a chat attachment, shared by every surface that
/// offers them.
///
/// The chat owned all of this privately, so the galleries in the peer/room
/// profiles could offer nothing at all — their viewer menu came up with a
/// single item. Living here, one definition of the download-name convention
/// serves both, and a file saved from a profile lands exactly like one saved
/// from the chat.

/// True for recordings made with the mic button, as opposed to a music file.
///
/// `audio/mp4` is deliberately absent: in-app AAC recordings share it with real
/// music, and only the captured waveform tells them apart. Callers that have
/// the payload should also treat a non-empty `waveform` as voice.
bool isVoiceAttachmentMime(String mime) {
  final m = mime.trim().toLowerCase();
  return m == 'audio/ogg' ||
      m == 'audio/opus' ||
      m.startsWith('audio/webm') ||
      m == 'audio/3gpp' ||
      m == 'audio/amr';
}

/// Имя, под которым вложение уходит наружу.
///
/// 🔴 ИМЯ ОТПРАВИТЕЛЯ ИДЁТ ПЕРВЫМ (14.08.2026). Раньше имя собиралось здесь
/// заново: вид — из mime, расширение — из имени ЛОКАЛЬНОГО кэша. Кэш зовётся
/// `<blobId><ext-по-mime>`, а таблица mime→расширение знала два десятка типов и
/// на всё прочее отвечала `.bin`. Поэтому `app-release.apk` уезжал другу как
/// `music_20260814_193500.bin`: ни имени, ни расширения, и ни одна система на
/// свете не могла понять, что это.
///
/// Имя при этом У НАС БЫЛО — отправитель кладёт его в `filename`, и чат его
/// показывает. Мы его просто выбрасывали. Порядок источников теперь описан в
/// одном месте: [attachmentExportFileName].
String attachmentDownloadSuggestedName(
  AttachmentEventV1 attachment,
  int createdAtMs,
  File source,
) {
  final mime = (attachment.mime ?? '').toLowerCase();
  // Вид нужен ТОЛЬКО когда имени нет: для снимка с камеры и голосового его и
  // правда не бывает. «music» для документов и пакетов больше не существует.
  final kindStem = mime.startsWith('image/')
      ? 'photo'
      : mime.startsWith('video/')
      ? 'video'
      : isVoiceAttachmentMime(mime)
      ? 'voice_message'
      : mime.startsWith('audio/')
      ? 'music'
      : 'file';
  final resolved = attachmentExportFileName(
    filename: attachment.filename,
    // Расширение из локального файла — последний довод: у кэша оно взято из
    // того же mime, но иногда точнее (например у сконвертированного видео).
    mime: (attachment.mime ?? '').trim().isEmpty
        ? _mimeFromPathExtension(source.path)
        : attachment.mime,
    createdAtMs: createdAtMs,
    kindStem: kindStem,
  );
  // 🔴 ЗАМЕР ИМЕНИ (14.08.2026). Первый заход этой правки я делал БЕЗ ЛОГА — и
  // когда владелец сказал «всё равно .bin», сказать было нечего: где именно
  // теряется имя, по логу не видно. Строка дешёвая, одна на выгрузку.
  DiagLog.event('media', 'attachment_export_name', <String, Object?>{
    'has_filename': (attachment.filename ?? '').trim().isNotEmpty,
    'mime': (attachment.mime ?? '').trim(),
    'cache_ext': p.extension(source.path),
    'out_ext': p.extension(resolved),
  });
  return resolved;
}

String? _mimeFromPathExtension(String path) {
  final ext = p.extension(path);
  if (ext.isEmpty) return null;
  final guessed = attachmentMimeFor(filename: 'x$ext');
  return guessed == kUnknownAttachmentMime ? null : guessed;
}

/// Папка, куда кладём файл, когда системного хранилища нет.
///
/// 🔴 НА iOS НЕЛЬЗЯ ЗВАТЬ `getDownloadsDirectory()` (14.08.2026, замер владельца:
/// «Не удалось скачать: PathAccessException: Creation failed, path =
/// '/var/mobile/.../Downloads' (OS Error: Operation not permitted, errno = 1)»).
///
/// Он возвращает НЕ null, а путь `<контейнер>/Downloads` — папку, которой на iOS
/// не существует и которую приложение создать не имеет права. Поэтому запасной
/// вариант `?? getApplicationDocumentsDirectory()` не срабатывал никогда:
/// подменять было нечего, значение приходило непустым и негодным, и падало уже
/// само создание.
Future<Directory> resolveMediaDownloadDirectory() async {
  Directory? downloads;
  if (!Platform.isIOS) {
    try {
      downloads = await getDownloadsDirectory();
    } catch (_) {
      downloads = null;
    }
  }
  final baseDir = downloads ?? await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(baseDir.path, 'Secretly'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// [suggestedName], suffixed `_2`, `_3`… until it names nothing that exists.
Future<File> uniqueDownloadTarget(Directory dir, String suggestedName) async {
  final ext = p.extension(suggestedName);
  final stem = ext.isEmpty
      ? suggestedName
      : suggestedName.substring(0, suggestedName.length - ext.length);
  var candidate = File(p.join(dir.path, suggestedName));
  var index = 2;
  while (await candidate.exists()) {
    candidate = File(p.join(dir.path, '${stem}_$index$ext'));
    index++;
  }
  return candidate;
}

/// Кладёт файл туда, где человек его найдёт — и возвращает путь для подписи
/// «сохранено в …».
///
/// 🔴 ANDROID ПИШЕТ В СИСТЕМНЫЕ «ЗАГРУЗКИ» (14.08.2026, жалоба владельца:
/// «скачивается в какую-то непонятную папку, в недавних в проводнике не
/// высвечивается»).
///
/// Раньше всё шло в [resolveMediaDownloadDirectory], а это на Android
/// `Android/data/<пакет>/files/Downloads` — ЛИЧНАЯ папка приложения. Проводник
/// туда не заглядывает, «Недавние» её не индексируют, и файл, формально
/// сохранённый, найти было нельзя. Тот же урок, что с «сохранением в галерею»
/// 17.07: сохранять надо ЧЕРЕЗ СИСТЕМНОЕ ХРАНИЛИЩЕ, а не рядом с ним.
///
/// Возвращает `null`, если системное хранилище отказало — вызывающий тогда
/// падает на [saveAttachmentToDownloads], и файл человек всё равно получает.
Future<String?> saveAttachmentToPublicDownloads({
  required String fileName,
  required File source,
  String? mime,
}) async {
  if (!Platform.isAndroid) return null;
  final resolvedMime = attachmentMimeFor(filename: fileName, mime: mime);
  try {
    final saved = await const MethodChannel(
      'secretly/media_store',
    ).invokeMethod<String>('saveToDownloads', <String, Object?>{
      'fileName': fileName,
      'sourcePath': source.path,
      'mimeType': resolvedMime,
    });
    DiagLog.event('media', 'attachment_saved_public', <String, Object?>{
      'mime': resolvedMime,
      'name_ext': p.extension(fileName),
      'saved_ext': p.extension(saved ?? ''),
    });
    return saved;
  } catch (e) {
    DiagLog.event('media', 'attachment_save_public_failed', <String, Object?>{
      'err': e.runtimeType.toString(),
    });
    return null;
  }
}

/// Сохраняет файл ТУДА, ГДЕ ЧЕЛОВЕК ЕГО НАЙДЁТ, и возвращает путь для подписи.
///
/// Android — системные «Загрузки» (видно в проводнике и «Недавних»); если
/// система отказала — личная папка приложения, чтобы файл не потерялся совсем.
/// Остальные платформы — папка Secretly в документах.
Future<String> saveAttachmentToUserVisibleLocation({
  required String fileName,
  required File source,
  String? mime,
}) async {
  final publicPath = await saveAttachmentToPublicDownloads(
    fileName: fileName,
    source: source,
    mime: mime,
  );
  if (publicPath != null && publicPath.trim().isNotEmpty) return publicPath;
  final dir = await resolveMediaDownloadDirectory();
  final target = await uniqueDownloadTarget(dir, fileName);
  final saved = await source.copy(target.path);
  return saved.path;
}

/// Copies an already-resolved [source] blob into the user's Secretly folder.
/// Returns the file it wrote, for the "saved to …" confirmation.
Future<File> saveAttachmentToDownloads({
  required AttachmentEventV1 attachment,
  required int createdAtMs,
  required File source,
}) async {
  final suggestedName = attachmentDownloadSuggestedName(
    attachment,
    createdAtMs,
    source,
  );
  final dir = await resolveMediaDownloadDirectory();
  final target = await uniqueDownloadTarget(dir, suggestedName);
  return source.copy(target.path);
}

/// GALLERY SAVE FIX (2026-07-17): "save to gallery" used to copy the blob into
/// the app-private download folder (`getDownloadsDirectory()` =
/// `Android/data/...` on Android) — a place the system Gallery and Files apps
/// NEVER look, so "saved" photos/videos were invisible. Real messengers write
/// through the platform media store; so do we now:
///   * Android → MediaStore inserts under `Pictures/Secretly` /
///     `Movies/Secretly` — appears in Gallery/Photos instantly, no reboot, no
///     scanner tricks.
///   * iOS → PHPhotoLibrary (add-only access level, so the permission prompt
///     is the softer "Allow adding to Photos").
///
/// Returns true when the media landed in the system gallery; false for
/// non-media mimes, denied permission, or a platform failure — callers fall
/// back to [saveAttachmentToDownloads] so the user still gets the file.
Future<bool> saveMediaToSystemGallery({
  required AttachmentEventV1 attachment,
  required int createdAtMs,
  required File source,
}) async {
  final mime = (attachment.mime ?? '').trim().toLowerCase();
  final isImage = mime.startsWith('image/');
  final isVideo = mime.startsWith('video/');
  if (!isImage && !isVideo) return false;

  try {
    final permission = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.addOnly,
      ),
    );
    if (!permission.hasAccess) return false;

    final title = attachmentDownloadSuggestedName(
      attachment,
      createdAtMs,
      source,
    );
    if (isImage) {
      await PhotoManager.editor.saveImageWithPath(
        source.path,
        title: title,
        relativePath: 'Pictures/Secretly',
      );
    } else {
      await PhotoManager.editor.saveVideo(
        source,
        title: title,
        relativePath: 'Movies/Secretly',
      );
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Hands an already-resolved [source] blob to the system share sheet.
Future<void> shareAttachmentFile({
  required AttachmentEventV1 attachment,
  required int createdAtMs,
  required File source,
  Rect? sharePositionOrigin,
}) async {
  final suggestedName = attachmentDownloadSuggestedName(
    attachment,
    createdAtMs,
    source,
  );
  // 🔴 Тип выводим ИЗ ИМЕНИ, когда сам тип обезличен. Принимающее приложение
  // выбирается системой именно по типу: с `application/octet-stream` установщик
  // пакетов не предложит поставить apk, а редактор — открыть документ.
  final mime = attachmentMimeFor(
    filename: suggestedName,
    mime: attachment.mime,
  );
  // Файл уходит наружу под правильным именем НА ДИСКЕ: принимающая сторона
  // читает имя файла, а не наши параметры.
  final exportFile = await prepareAttachmentFileForExport(
    source: source,
    filename: suggestedName,
    mime: mime,
    createdAtMs: createdAtMs,
  );
  DiagLog.event('media', 'attachment_share', <String, Object?>{
    'mime': mime,
    'out_ext': p.extension(exportFile.path),
    'copied': exportFile.path != source.path,
  });
  await SharePlus.instance.share(
    ShareParams(
      title: suggestedName,
      subject: suggestedName,
      files: [
        XFile(
          exportFile.path,
          mimeType: mime == kUnknownAttachmentMime ? null : mime,
          name: suggestedName,
        ),
      ],
      fileNameOverrides: [suggestedName],
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}

/// `1.44 MB` — fewer decimals as the number grows.
String formatAttachmentBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var idx = 0;
  while (value >= 1024 && idx < units.length - 1) {
    value /= 1024;
    idx++;
  }
  final decimals = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
  return '${value.toStringAsFixed(decimals)} ${units[idx]}';
}
