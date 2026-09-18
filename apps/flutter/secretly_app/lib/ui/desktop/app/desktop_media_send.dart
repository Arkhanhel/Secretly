// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../../app/pending_attachment_upload.dart';
import '../chat/attachment_kinds.dart';
import '../chat/media_albums.dart';
import '../chat/message_bubble.dart';
import '../chat/outgoing_media.dart';
import '../chat/send_media_dialog.dart';

// 🔴 КАК РЕШЕНИЕ ОКНА ОТПРАВКИ ПРЕВРАЩАЕТСЯ В СООБЩЕНИЯ.
//
// Каждая группа ([planOutgoingGroups]) — одна пачка в ОБЩЕЙ очереди
// контроллера (`enqueueAttachmentBatchUpload`): внутри переписки отправки идут
// строго по одной (цепочка шифрования не терпит наложений), заготовки
// переживают переход между чатами, у каждой есть прогресс и отмена.
//
// Снимки и ролики уходят БЕЗ имени файла — у получателя (и на телефоне) это
// фото и видео, альбом склеивается по общему номеру группы. Документы и
// песни — с именами: это строки файлов.

/// Отправляет решение окна в переписку [convoId].
///
/// [enqueue] — постановка пачки в очередь контроллера
/// (`AppController.enqueueAttachmentBatchUpload`); сам контроллер сюда не
/// передаётся — файлу хватает одного этого действия.
///
/// [peerProfileId] — собеседник; `null` — комната. [sendText] отправляет
/// подпись отдельным сообщением, когда сообщений несколько (как в Telegram:
/// подпись под последним из пяти несгруппированных снимков читалась бы как
/// подпись к нему одному).
Future<void> enqueueDesktopMediaSend({
  required void Function(PendingAttachmentBatchUpload batch) enqueue,
  required SendMediaResult result,
  required String convoId,
  required String? peerProfileId,
  String? topicId,
  String? replyToPayloadEventId,
  required Future<void> Function(String text, String? replyToPayloadEventId)
  sendText,
}) async {
  final groups = result.groups;
  if (groups.isEmpty) return;
  final isGroup = peerProfileId == null;
  final caption = result.caption.trim();
  var reply = replyToPayloadEventId;
  final separate = caption.isNotEmpty && captionTravelsSeparately(groups);
  if (separate) {
    await sendText(caption, reply);
    reply = null;
  }
  // Номер альбома — как у телефона: микросекунды отправки.
  final base = DateTime.now().microsecondsSinceEpoch;
  for (var i = 0; i < groups.length; i++) {
    final group = groups[i];
    final batchId = '${base + i}';
    final mediaGroupId = group.files.length > 1 ? batchId : null;
    final items = <PendingPhotoUpload>[];
    final hints = <PendingUploadHints>[];
    for (var j = 0; j < group.files.length; j++) {
      final f = group.files[j];
      final asMedia = group.asMedia;
      final mime = (asMedia ? f.mediaSendMime : f.mime) ??
          'application/octet-stream';
      items.add(
        PendingPhotoUpload(
          id: '${batchId}_$j',
          filePath: asMedia ? f.mediaSendPath : f.path,
          mime: mime,
          caption: (j == 0 && !separate) ? caption : '',
          totalBytes: asMedia ? f.mediaSendSize : f.sizeBytes,
          replyToPayloadEventId: j == 0 ? reply : null,
          mediaGroupId: mediaGroupId,
          // Имя — только у документов: по нему получатель рисует строку
          // файла, а не снимок.
          filename: asMedia ? null : f.name,
          asFile: !asMedia,
        ),
      );
      final size = f.size;
      hints.add(
        PendingUploadHints(
          width: size?.width.round(),
          height: size?.height.round(),
          durationMs: f.durationMs,
          thumbB64: f.thumbB64,
          musicTitle: f.musicTitle,
          musicArtist: f.musicArtist,
        ),
      );
    }
    enqueue(
      PendingAttachmentBatchUpload(
        id: batchId,
        items: items,
        hints: hints,
        convoId: convoId,
        targetId: peerProfileId ?? '',
        isGroup: isGroup,
        topicId: isGroup ? topicId : null,
      ),
    );
    reply = null;
  }
}

/// Вид вложения по типу — для заготовки, у которой ещё нет сообщения.
MessageAttachmentKind desktopKindForMime(String mime) {
  final lower = mime.trim().toLowerCase();
  if (lower.startsWith('image/')) return MessageAttachmentKind.image;
  if (lower.startsWith('video/')) return MessageAttachmentKind.video;
  if (lower.startsWith('audio/')) return MessageAttachmentKind.audio;
  return MessageAttachmentKind.file;
}

/// Префикс строк-заготовок в ленте.
const String kUploadRowPrefix = 'upload:';

/// Строки ленты для уходящих пачек — старые сверху, как и сообщения.
///
/// [batches] — в порядке постановки (старые первыми); при одинаковом времени
/// этот порядок и сохраняется. Пачка одного альбома — одна строка (та же
/// склейка, что у настоящих сообщений), подпись — у первого файла.
List<MessageData> desktopUploadRows(
  Iterable<PendingAttachmentBatchUpload> batches, {
  required String selfName,
  required String Function(int ms) timeLabel,
  ReplyPreview? Function(String? payloadEventId)? replyPreview,
}) {
  final input = batches.toList();
  final order = <PendingAttachmentBatchUpload, int>{
    for (var i = 0; i < input.length; i++) input[i]: i,
  };
  final ordered = [...input]
    ..sort((a, b) {
      final byTime = a.createdAtMs.compareTo(b.createdAtMs);
      return byTime != 0 ? byTime : order[a]!.compareTo(order[b]!);
    });
  final rows = <MessageData>[];
  for (final batch in ordered) {
    final items = <MessageData>[];
    for (var j = 0; j < batch.items.length; j++) {
      final item = batch.items[j];
      if (item.canceled) continue;
      final hint = j < batch.hints.length ? batch.hints[j] : null;
      final total = item.totalBytes;
      final progress = total > 0
          ? (item.sentBytes / total).clamp(0.0, 1.0)
          : 0.0;
      final name = (item.filename ?? '').trim();
      items.add(
        MessageData(
          id: '$kUploadRowPrefix${item.id}',
          authorName: selfName,
          // Общий ключ пачки — чтобы её файлы склеились в альбом.
          authorSeed: '$kUploadRowPrefix${batch.id}',
          text: j == 0 ? item.caption.trim() : '',
          time: timeLabel(batch.createdAtMs),
          timestampMs: batch.createdAtMs,
          isSelf: true,
          delivery: DeliveryStatus.sending,
          mediaGroupId: batch.items.length > 1
              ? '$kUploadRowPrefix${batch.id}'
              : null,
          reply: j == 0 ? replyPreview?.call(item.replyToPayloadEventId) : null,
          attachment: MessageAttachment(
            kind: desktopKindForMime(item.mime),
            // Кадр ролика уже снят окном отправки — тот же ключ, второй раз
            // ffmpeg не нужен.
            blobId: item.asFile
                ? '$kUploadRowPrefix${item.id}'
                : (desktopKindForMime(item.mime) == MessageAttachmentKind.video
                      ? OutgoingMediaPrep.videoThumbKey(item.filePath)
                      : '$kUploadRowPrefix${item.id}'),
            payloadEventId: '$kUploadRowPrefix${item.id}',
            filePath: item.filePath,
            mime: item.mime,
            fileName: name.isEmpty
                ? (item.asFile ? p.basename(item.filePath) : null)
                : name,
            sizeBytes: total,
            width: hint?.width,
            height: hint?.height,
            durationMs: hint?.durationMs,
            musicTitle: hint?.musicTitle,
            musicArtist: hint?.musicArtist,
            thumbnail: decodeAttachmentThumb(hint?.thumbB64),
            sentAsFile: item.asFile,
            uploadProgress: progress,
          ),
        ),
      );
    }
    if (items.isEmpty) continue;
    rows.addAll(groupMediaAlbums(items));
  }
  return rows;
}

/// Пачка, к которой относится строка-заготовка, — или `null`.
String? uploadBatchIdOfRow(MessageData m) {
  if (!m.id.startsWith(kUploadRowPrefix)) return null;
  final seed = m.authorSeed ?? '';
  if (!seed.startsWith(kUploadRowPrefix)) return null;
  return seed.substring(kUploadRowPrefix.length);
}

/// Системный выбор файлов — сразу нескольких, как в Telegram. [media] —
/// только снимки и ролики. Пусто — человек передумал.
Future<List<String>> pickDesktopAttachments({required bool media}) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
      type: media ? FileType.custom : FileType.any,
      allowedExtensions: media ? kDesktopMediaPickExtensions : null,
      allowMultiple: true,
      lockParentWindow: true,
    );
    return <String>[
      for (final f in picked?.files ?? const <PlatformFile>[])
        if ((f.path ?? '').trim().isNotEmpty) f.path!,
    ];
  } catch (_) {
    // Системное окно не открылось — как будто человек передумал: без
    // необработанного исключения, которое в окне ничем не видно.
    return const <String>[];
  }
}

/// Что предлагает «Фото или видео».
const List<String> kDesktopMediaPickExtensions = <String>[
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'heic',
  'heif',
  'bmp',
  'tif',
  'tiff',
  'mp4',
  'mov',
  'm4v',
  'webm',
];
