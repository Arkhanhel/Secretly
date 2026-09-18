// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../models/e2e_payload_v1.dart' show AttachmentEventV1;
import '../transport/blob_client.dart' show BlobUploadCancelToken;

/// In-progress attachment uploads, owned by [AppController] so a bubble stays
/// visible (with live progress) when the user leaves and re-enters the chat
/// mid-upload — the chat screen only reads/renders them. Moving these OUT of the
/// chat-screen State (where they died on dispose) is what fixes "the file
/// disappears when I leave and come back".
///
/// The models below are byte-for-byte the old private `_Pending*` classes from
/// chat_screen, made public and given routing fields (`convoId` / `isGroup` /
/// `topicId` / `targetId`) so the controller's single serialized worker can run
/// the send without any screen context.

/// A single photo / video / document / audio-file upload in flight.
class PendingPhotoUpload {
  PendingPhotoUpload({
    required this.id,
    required this.filePath,
    required this.mime,
    required this.caption,
    required this.totalBytes,
    this.convoId = '',
    this.targetId = '',
    this.isGroup = false,
    this.topicId,
    this.replyToPayloadEventId,
    this.mediaGroupId,
    this.filename,
    this.asFile = false,
    this.reuseBlobFrom,
    this.musicTitle,
    this.musicArtist,
    this.waveform,
    this.durationMs,
    this.videoNote = false,
  }) : createdAtMs = DateTime.now().millisecondsSinceEpoch;

  final String id;
  final String filePath;
  final String mime;
  final String caption;
  final int createdAtMs;

  /// Routing (set on top-level items; album items leave these at defaults — the
  /// album carries the routing instead).
  final String convoId;
  final String targetId;
  final bool isGroup;
  final String? topicId;

  final String? replyToPayloadEventId;
  final String? mediaGroupId;

  /// Original document name — set when a photo/video/document was sent through
  /// the FILE path (renders as a document row); null for inline photos/videos.
  final String? filename;

  /// True when this upload was picked via the FILE tab (render as a document
  /// bubble even for image/video mimes, instead of an inline preview).
  final bool asFile;

  /// 🔴 ПЕРЕСЫЛКА НА СВОИ УСТРОЙСТВА БЕЗ ПОВТОРНОЙ ЗАЛИВКИ (14.08.2026).
  ///
  /// Заполняется ТОЛЬКО когда получатель — я сам: тогда пересылка отдаёт тот же
  /// blob и тот же ключ, вместо того чтобы шифровать и заливать файл заново.
  ///
  /// Почему только себе: сервер увидит, что один и тот же blob запрошен из двух
  /// разных чатов, — это метаданные «файл переслан из A в B». Между СВОИМИ
  /// устройствами связывать нечего, оба конца мои. Содержимое защищено
  /// одинаково в обоих случаях: файл лежит зашифрованным XChaCha20-Poly1305, и
  /// ключа у сервера нет ни в каком виде.
  final AttachmentEventV1? reuseBlobFrom;

  /// Название и исполнитель пересылаемой песни — из исходного сообщения.
  /// Без них пересланная песня приходила подписанной именем файла.
  final String? musicTitle;
  final String? musicArtist;

  /// Волна и длительность пересылаемого голосового. Голосовое — `audio/mp4`,
  /// как музыка, и без волны у получателя становилось песней «Неизвестен».
  final List<int>? waveform;
  final int? durationMs;

  /// Пересылаемый «кружок» остаётся кружком (17.09.2026, K-a). Без признака
  /// он уходил обычным видео — и пересжимался, хотя исходная отправка кружок
  /// не пережимает.
  final bool videoNote;

  final BlobUploadCancelToken cancelToken = BlobUploadCancelToken();
  String? payloadEventId;
  int sentBytes = 0;
  int totalBytes;
  double speedBytesPerSec = 0;
  int? etaSeconds;

  /// True once the user cancelled THIS item from an album (per-photo ✕). The
  /// item stays in [PendingPhotoAlbumUpload.items] so live progress callbacks
  /// keep their index alignment, but the collage hides it and the send worker
  /// skips it — cancelling one photo must NOT cancel the whole album.
  bool canceled = false;
  int _lastSentBytes = 0;
  int _lastTickMs = DateTime.now().millisecondsSinceEpoch;
  int _lastUiTickMs = 0;

  bool updateProgress(int sent, int total) {
    final previousPercent = totalBytes <= 0
        ? 0
        : ((sentBytes / totalBytes) * 100).floor();
    sentBytes = sent;
    totalBytes = total;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dtMs = (nowMs - _lastTickMs).clamp(1, 60000);
    final delta = sent - _lastSentBytes;
    if (delta > 0) {
      final inst = (delta * 1000) / dtMs;
      speedBytesPerSec = speedBytesPerSec <= 0
          ? inst
          : ((speedBytesPerSec * 0.72) + (inst * 0.28));
      final remain = totalBytes - sentBytes;
      if (speedBytesPerSec > 1 && remain > 0) {
        etaSeconds = (remain / speedBytesPerSec).ceil();
      } else {
        etaSeconds = null;
      }
    }
    _lastSentBytes = sent;
    _lastTickMs = nowMs;

    final nextPercent = totalBytes <= 0
        ? 0
        : ((sentBytes / totalBytes) * 100).floor();
    final reachedTerminal =
        sentBytes <= 0 || (totalBytes > 0 && sentBytes >= totalBytes);
    final shouldRebuild =
        reachedTerminal ||
        nextPercent != previousPercent ||
        nowMs - _lastUiTickMs >= 80;
    if (shouldRebuild) {
      _lastUiTickMs = nowMs;
    }
    return shouldRebuild;
  }
}

/// A grouped photo album (shared `mediaGroupId`) uploaded as one unit.
class PendingPhotoAlbumUpload {
  PendingPhotoAlbumUpload({
    required this.id,
    required this.items,
    this.convoId = '',
    this.targetId = '',
    this.isGroup = false,
    this.topicId,
  }) : createdAtMs = DateTime.now().millisecondsSinceEpoch;

  final String id;
  final List<PendingPhotoUpload> items;
  final int createdAtMs;

  final String convoId;
  final String targetId;
  final bool isGroup;
  final String? topicId;

  List<String> payloadEventIds = const <String>[];

  String? get mediaGroupId {
    final groupId = items.isEmpty ? null : items.first.mediaGroupId;
    final trimmed = groupId?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Items the user has NOT cancelled — what the collage renders.
  List<PendingPhotoUpload> get activeItems =>
      items.where((item) => !item.canceled).toList(growable: false);

  /// Every item is cancelled → the whole album should be dropped.
  bool get allCanceled => items.isNotEmpty && items.every((i) => i.canceled);

  /// Full-length, index-aligned with the worker's file list — DO NOT filter by
  /// [PendingPhotoUpload.canceled] here, or the send worker's per-index cancel
  /// checks (`cancelTokens[index]`) would target the wrong upload.
  List<BlobUploadCancelToken> get cancelTokens =>
      items.map((item) => item.cancelToken).toList(growable: false);

  int get sentBytes =>
      activeItems.fold<int>(0, (sum, item) => sum + item.sentBytes);
  int get totalBytes =>
      activeItems.fold<int>(0, (sum, item) => sum + item.totalBytes);
  double get speedBytesPerSec =>
      activeItems.fold<double>(0, (sum, item) => sum + item.speedBytesPerSec);
  int? get etaSeconds {
    final speed = speedBytesPerSec;
    final remaining = totalBytes - sentBytes;
    if (speed <= 1 || remaining <= 0) return null;
    return (remaining / speed).ceil();
  }

  bool updateProgress(int index, int sent, int total) {
    if (index < 0 || index >= items.length) return false;
    return items[index].updateProgress(sent, total);
  }

  /// Cancels a SINGLE item (per-photo ✕). Returns true if, after this, every
  /// item is cancelled (caller should drop the whole album).
  bool cancelItem(int index) {
    if (index < 0 || index >= items.length) return allCanceled;
    items[index].canceled = true;
    items[index].cancelToken.cancel();
    return allCanceled;
  }

  void cancel() {
    for (final item in items) {
      item.canceled = true;
      item.cancelToken.cancel();
    }
  }
}

/// 🔴 ПАЧКА ИЗ ОКНА ОТПРАВКИ КОМПЬЮТЕРА (16.09.2026).
///
/// Указание владельца: перетащил файлы — появилось окно, там подпись, и
/// отправленное выглядит как в Telegram. От [PendingPhotoAlbumUpload] пачка
/// отличается двумя вещами:
///   • у документов есть ИМЯ — у получателя они рисуются строкой файла, а не
///     снимком;
///   • к каждому файлу приложены подсказки ([PendingUploadHints]): размеры и
///     длительность ролика, миниатюра по его кадру.
///
/// Отправка всегда идёт ПАКЕТНЫМ путём, даже для одного файла: одна дорога
/// для всего окна — снимок очищается от метаданных (геометки), получает
/// размеры и миниатюру, а в комнате уходит в открытую тему.
/// Телефон этот класс не использует.
class PendingAttachmentBatchUpload extends PendingPhotoAlbumUpload {
  PendingAttachmentBatchUpload({
    required super.id,
    required super.items,
    required this.hints,
    super.convoId,
    super.targetId,
    super.isGroup,
    super.topicId,
  }) : assert(hints.length == items.length);

  /// Подсказки — в том же порядке, что и [items].
  final List<PendingUploadHints> hints;
}

/// Что окно отправки знает о файле сверх самих байтов.
class PendingUploadHints {
  const PendingUploadHints({
    this.width,
    this.height,
    this.durationMs,
    this.thumbB64,
    this.musicTitle,
    this.musicArtist,
  });

  final int? width;
  final int? height;
  final int? durationMs;
  final String? thumbB64;

  /// Теги песни, прочитанные окном отправки.
  final String? musicTitle;
  final String? musicArtist;
}

/// Сколько очередь ждёт теги песни перед отправкой. Обычно чтение занимает
/// доли секунды; не дождались — песня уходит без них, с именем файла.
const Duration kMusicTagsWait = Duration(seconds: 3);

/// A voice note or music file upload in flight.
class PendingAudioUpload {
  PendingAudioUpload({
    required this.id,
    required this.filePath,
    required this.mime,
    required this.totalBytes,
    required this.isVoice,
    this.convoId = '',
    this.targetId = '',
    this.isGroup = false,
    this.topicId,
    this.replyToPayloadEventId,
    this.title,
    this.waveform,
  }) : createdAtMs = DateTime.now().millisecondsSinceEpoch;

  final String id;
  final String filePath;
  final String mime;
  final int createdAtMs;

  final String convoId;
  final String targetId;
  final bool isGroup;
  final String? topicId;

  final String? replyToPayloadEventId;
  final bool isVoice;
  final List<int>? waveform;
  final BlobUploadCancelToken cancelToken = BlobUploadCancelToken();
  String? payloadEventId;

  /// Что показывать в заготовке, пока песня уходит. До чтения тегов — имя
  /// файла.
  String? title;
  String? artist;

  /// [title] и [artist] прочитаны из тегов файла. Только тогда они уходят в
  /// сообщение: имя файла, выданное за название, заслоняло у получателя
  /// настоящие теги (см. `taggedMusicTitle`).
  bool tagsFromFile = false;

  /// Чтение тегов, начатое вместе с постановкой в очередь.
  ///
  /// 🔴 Очередь стартует СИНХРОННО, прямо в `enqueueAudioUpload`, и забирала
  /// подписи раньше, чем теги успевали прочитаться: первая же песня уходила
  /// с именем файла вместо названия и без исполнителя (17.09.2026). Теперь
  /// очередь ждёт это чтение — не дольше `kMusicTagsWait`.
  Future<void>? tagsReady;

  int sentBytes = 0;
  int totalBytes;
  double speedBytesPerSec = 0;
  int? etaSeconds;
  int _lastSentBytes = 0;
  int _lastTickMs = DateTime.now().millisecondsSinceEpoch;
  int _lastUiTickMs = 0;

  bool updateProgress(int sent, int total) {
    final previousPercent = totalBytes <= 0
        ? 0
        : ((sentBytes / totalBytes) * 100).floor();
    sentBytes = sent;
    totalBytes = total;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dtMs = (nowMs - _lastTickMs).clamp(1, 60000);
    final delta = sent - _lastSentBytes;
    if (delta > 0) {
      final inst = (delta * 1000) / dtMs;
      speedBytesPerSec = speedBytesPerSec <= 0
          ? inst
          : ((speedBytesPerSec * 0.72) + (inst * 0.28));
      final remain = totalBytes - sentBytes;
      if (speedBytesPerSec > 1 && remain > 0) {
        etaSeconds = (remain / speedBytesPerSec).ceil();
      } else {
        etaSeconds = null;
      }
    }
    _lastSentBytes = sent;
    _lastTickMs = nowMs;

    final nextPercent = totalBytes <= 0
        ? 0
        : ((sentBytes / totalBytes) * 100).floor();
    final reachedTerminal =
        sentBytes <= 0 || (totalBytes > 0 && sentBytes >= totalBytes);
    final shouldRebuild =
        reachedTerminal ||
        nextPercent != previousPercent ||
        nowMs - _lastUiTickMs >= 80;
    if (shouldRebuild) {
      _lastUiTickMs = nowMs;
    }
    return shouldRebuild;
  }
}

/// Emitted by [AppController.attachmentUploadErrors] when a background upload
/// fails, so the matching chat screen can surface it (dialog / snackbar) exactly
/// as the old in-screen executor did.
class AttachmentUploadErrorEvent {
  const AttachmentUploadErrorEvent({required this.convoId, required this.error});
  final String convoId;
  final Object error;
}
