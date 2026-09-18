// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../diagnostics/diag_log.dart';
import '../../app/app_controller.dart';
import '../../media/music_tags.dart';
import '../../media/video_thumbnail_cache.dart';
import '../../models/e2e_payload_v1.dart';
import '../animations/shimmer_skeletons.dart';
import '../chat_message_mentions.dart' show extractChatMessageLinks;
import '../chat_screen_l10n.dart';
import '../icons/app_icons.dart';
import '../l10n.dart';
import 'attachment_actions.dart';
import 'media_viewer.dart';
import '../secretly_snackbar.dart';
import '../wave1_l10n.dart';
import 'full_bleed_zoom.dart';
import 'broken_media_box.dart';

class ConversationMediaGalleryVm {
  const ConversationMediaGalleryVm({
    required this.photos,
    required this.videos,
    required this.files,
    required this.music,
    this.links = const <ConversationLinkItem>[],
  });

  final List<ConversationAttachmentItem> photos;
  final List<ConversationAttachmentItem> videos;
  final List<ConversationAttachmentItem> files;
  final List<ConversationAttachmentItem> music;

  /// Ссылки, встреченные в переписке, — новейшие первыми.
  ///
  /// 🔴 Считаются ТУТ ЖЕ, за тот же единственный проход по событиям. Отдельный
  /// проход ради них означал бы второе чтение пяти тысяч событий и второй
  /// разбор каждого payload — ровно та цена, из-за которой эта выборка и
  /// сделана ленивой.
  ///
  /// Поле необязательное: телефон его не читает и ведёт себя как прежде.
  final List<ConversationLinkItem> links;
}

/// Одна ссылка из переписки.
class ConversationLinkItem {
  const ConversationLinkItem({
    required this.url,
    required this.messageText,
    required this.createdAtMs,
    required this.senderDeviceId,
  });

  final String url;

  /// Текст сообщения, в котором ссылка встретилась: по одному адресу часто не
  /// вспомнить, о чём был разговор.
  final String messageText;
  final int createdAtMs;
  final String senderDeviceId;
}

class ConversationAttachmentItem {
  const ConversationAttachmentItem({
    required this.event,
    required this.attachment,
    required this.createdAtMs,
    required this.senderDeviceId,
  });

  /// The chat event this attachment came from. Carried so the gallery can hand
  /// the shared viewer a MediaViewerItem, and so a later "show in chat" has the
  /// payload id to jump to — the item used to drop it, which is why the gallery
  /// could only ever show a picture and nothing else.
  final ChatEvent event;
  final AttachmentEventV1 attachment;
  final int createdAtMs;
  final String senderDeviceId;
}

Future<ConversationMediaGalleryVm> loadConversationMediaFiles(
  AppController controller,
  String convoId, {
  int eventLimit = 5000,
}) async {
  final events = await controller.loadEventsAll(convoId, limit: eventLimit);
  final photos = <ConversationAttachmentItem>[];
  final videos = <ConversationAttachmentItem>[];
  final files = <ConversationAttachmentItem>[];
  final music = <ConversationAttachmentItem>[];

  final links = <ConversationLinkItem>[];
  final seenUrls = <String>{};

  for (final event in events) {
    final payload = await controller.payloadEventForChatEvent(event);
    if (payload is MsgEventV1) {
      final text = payload.text;
      // Управляющие сообщения — не переписка: в них бывает base64, и искать
      // там ссылки значит показывать человеку мусор.
      if (text.startsWith('__secretly')) continue;
      for (final link in extractChatMessageLinks(text)) {
        // Один и тот же адрес, присланный пять раз, — это одна ссылка.
        if (!seenUrls.add(link.uri.toString())) continue;
        links.add(
          ConversationLinkItem(
            url: link.text,
            messageText: text.trim(),
            createdAtMs: event.createdAtMs,
            senderDeviceId: event.senderDeviceId,
          ),
        );
      }
      continue;
    }
    if (payload is! AttachmentEventV1) continue;
    final mime = (payload.mime ?? '').toLowerCase();
    final item = ConversationAttachmentItem(
      event: event,
      attachment: payload,
      createdAtMs: event.createdAtMs,
      senderDeviceId: event.senderDeviceId,
    );
    if (mime.startsWith('image/')) {
      photos.add(item);
    } else if (mime.startsWith('video/')) {
      videos.add(item);
    } else if (mime.startsWith('audio/')) {
      music.add(item);
    } else {
      files.add(item);
    }
  }

  photos.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  videos.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  files.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  music.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

  links.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

  return ConversationMediaGalleryVm(
    photos: photos,
    videos: videos,
    files: files,
    music: music,
    links: links,
  );
}

/// Итог попытки достать вложение: файл или КОД причины отказа.
///
/// ◆ Причина нужна окну, а не только журналу: «нет связи» и «файла больше нет
/// на сервере» требуют от человека разного — в первом случае повторить, во
/// втором ждать нечего.
typedef AttachmentFetch = ({File? file, String? failure});

/// Та же загрузка, но с причиной отказа. Старая [loadConversationAttachmentFile]
/// осталась для тех, кому причина не нужна.
Future<AttachmentFetch> fetchConversationAttachmentFile(
  AppController controller,
  AttachmentEventV1 attachment,
) async {
  final cached = await controller.cachedAttachmentFile(attachment);
  if (cached != null) return (file: cached, failure: null);
  try {
    final f = await controller.ensureCachedAttachmentFile(attachment);
    return (file: f, failure: null);
  } catch (e) {
    final code = _attachmentFailureCode(e);
    DiagLog.event('media', 'attachment_fetch_failed', {
      'blob': DiagLog.pfx(attachment.blobId),
      'mime': (attachment.mime ?? '').split(';').first,
      'err': e.runtimeType.toString(),
      'why': code,
      'ready': controller.attachmentsReady,
      'keylen': attachment.fileKeyB64.trim().length,
      'blobsz': attachment.sizeBytes,
    });
    return (file: null, failure: code);
  }
}

/// Файла больше нет на сервере: хранилище ответило 404.
///
/// 🔴 НАЙДЕНО 16.09.2026 ПО ЖАЛОБЕ «плитки пустые». Снимки августа в комнате
/// не загружались НИКОГДА — и не загрузятся: реле не хранит вложения вечно, а
/// это устройство подняли из резервной копии, в которой самих байтов нет.
/// Окно об этом молчало и предлагало «повторить» там, где повторять нечего.
const String kAttachmentGoneCode = 'blob_gone';

Future<File?> loadConversationAttachmentFile(
  AppController controller,
  AttachmentEventV1 attachment,
) async {
  return (await fetchConversationAttachmentFile(controller, attachment)).file;
}

/// Короткий код причины отказа — из закрытого списка, а не текст ошибки.
///
/// В журнал не должно уходить ничего, что мы не выбрали сами: сообщения
/// исключений здесь литеральные, но правило одно на весь проект — в лог идут
/// только известные слова.
String _attachmentFailureCode(Object e) {
  if (e is! StateError) return 'other';
  final m = e.message.toString();
  if (m.contains('Attachments not ready')) return 'not_ready';
  if (m.contains('bad file_key')) return 'bad_key';
  if (m.contains('unsupported attachment version')) return 'bad_version';
  if (m.contains('bad chunk size')) return 'bad_chunk';
  if (m.contains('truncated attachment')) return 'truncated';
  if (m.contains('ciphertext too short')) return 'ciphertext_short';
  // Хранилище вложений: «нет на сервере» — самый частый и самый важный для
  // человека случай, его надо называть отдельно от прочих отказов.
  if (m.contains('blob download failed: 404')) return 'blob_gone';
  if (m.contains('blob download failed')) return 'blob_http';
  if (m.contains('bad blob access token')) return 'blob_token';
  if (m.contains('BlobClient auth')) return 'blob_auth';
  return 'state';
}

/// Resolves an attachment ONLY from the local blob cache — never downloads.
///
/// The counterpart to [loadConversationAttachmentFile], for places that want to
/// enrich a cell if the bytes happen to be here already but must not pay for
/// them: showing a video's poster frame is not worth pulling the video.
Future<File?> cachedConversationAttachmentFile(
  AppController controller,
  AttachmentEventV1 attachment,
) async {
  try {
    return await controller.cachedAttachmentFile(attachment);
  } catch (_) {
    return null;
  }
}

/// "Show in chat": ask the chat to jump to this attachment, then get out of its
/// way.
///
/// Every host of this gallery sits directly ON TOP of the chat it lists — the
/// peer profile, the room profile and the chat's own "Media and files" sheet
/// are all one pop away from it — so we hand the request to the controller (the
/// chat listens) and pop. There is no push to route this through.
///
/// A miss is silent by design. Where no such chat is underneath — a room
/// member's profile reached from the member list has the ROOM below it, not the
/// 1:1 this gallery lists — nobody consumes the request and the user simply
/// lands back where popping takes them.
Future<void> showAttachmentInChat(
  BuildContext context,
  AppController controller,
  String convoId,
  AttachmentEventV1 attachment,
) async {
  controller.requestChatFocus(
    convoId: convoId,
    // AttachmentEventV1.eventId IS the payload event id the chat's own reply
    // and pin jumps use — no new plumbing needed to address the row.
    payloadEventId: attachment.eventId,
  );
  final navigator = Navigator.of(context);
  if (navigator.canPop()) navigator.pop();
}

/// Bare single-image viewer, kept for DESKTOP only.
///
/// Desktop must not use [openConversationMediaViewer]: that viewer localises via
/// chatText/context.l10n, and the desktop MaterialApp registers no
/// AppLocalizations — it would throw. Desktop keeps this simple dialog until it
/// gets its own localisation; mobile uses the real viewer below.
Future<void> openConversationAttachmentImage(
  BuildContext context,
  AppController controller,
  AttachmentEventV1 attachment,
) async {
  final file = await loadConversationAttachmentFile(controller, attachment);
  if (!context.mounted || file == null || !file.existsSync()) return;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (dialogCtx) {
      return GestureDetector(
        onTap: () => Navigator.of(dialogCtx).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: FullBleedZoom(
            child: Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 40, onDarkSurface: true),
            ),
          ),
        ),
      );
    },
  );
}

/// Opens the SHARED fullscreen viewer (the one the chat uses) on [items] at
/// [index] — swipe paging, zoom, video playback and the action menu, instead of
/// the bare single-image dialog this used to be.
///
/// Thumbnails for the filmstrip are cheap stills here on purpose: the chat
/// injects a live player surface for video, which a gallery cannot afford.
Future<void> openConversationMediaViewer(
  BuildContext context,
  AppController controller, {
  required List<ConversationAttachmentItem> items,
  required int index,
  required String title,
  required String convoId,
}) async {
  if (items.isEmpty) return;
  final viewerItems = items
      .map((i) => MediaViewerItem(event: i.event, attachment: i.attachment))
      .toList(growable: false);
  // Captured up front: the actions run AFTER the viewer pops itself, so its
  // own context is gone by then.
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  Future<void> withResolvedFile(
    MediaViewerItem item,
    Future<void> Function(File source) action,
  ) async {
    try {
      final source = await controller.ensureCachedAttachmentFile(
        item.attachment,
      );
      await action(source);
    } catch (e) {
      messenger.showSnackBar(
        SecretlySnackBar(content: Text(l10n.downloadFailed(e.toString()))),
      );
    }
  }

  await showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (dialogCtx) => Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: MediaViewerDialog(
        items: viewerItems,
        initialIndex: index.clamp(0, viewerItems.length - 1),
        chatTitle: title,
        loadImageFile: (attachment) async {
          final f = await loadConversationAttachmentFile(
            controller,
            attachment,
          );
          if (f == null) throw StateError('attachment file unavailable');
          return f;
        },
        // Reply/forward/delete stay absent on purpose: they belong to a chat we
        // are not inside, and deletion additionally needs the room's
        // permissions. The viewer hides whatever it isn't given.
        onShowInChat: (item) async =>
            showAttachmentInChat(context, controller, convoId, item.attachment),
        onSaveToGallery: (item) => withResolvedFile(item, (source) async {
          // GALLERY SAVE FIX (2026-07-17): media goes through the system
          // media store (visible in Gallery/Photos immediately); the
          // app-folder copy remains the fallback for non-media / denied
          // permission. The label is resolved BEFORE the await — the context
          // must not be touched across the async gap.
          final savedToGalleryLabel = chatText(
            context,
            ru: 'Сохранено в галерею',
            en: 'Saved to gallery',
            uk: 'Збережено в галерею',
            es: 'Guardado en la galeria',
            pt: 'Guardado na galeria',
            ptBr: 'Salvo na galeria',
            fr: 'Enregistre dans la galerie',
            de: 'In der Galerie gespeichert',
          );
          final inGallery = await saveMediaToSystemGallery(
            attachment: item.attachment,
            createdAtMs: item.event.createdAtMs,
            source: source,
          );
          if (inGallery) {
            messenger.showSnackBar(
              SecretlySnackBar(content: Text(savedToGalleryLabel)),
            );
            return;
          }
          final saved = await saveAttachmentToDownloads(
            attachment: item.attachment,
            createdAtMs: item.event.createdAtMs,
            source: source,
          );
          messenger.showSnackBar(
            SecretlySnackBar(content: Text(l10n.savedTo(saved.path))),
          );
        }),
        onShare: (item) => withResolvedFile(
          item,
          (source) => shareAttachmentFile(
            attachment: item.attachment,
            createdAtMs: item.event.createdAtMs,
            source: source,
          ),
        ),
        thumbnailBuilder: (context, file, mime, {bool forStrip = false}) =>
            _GalleryViewerThumbnail(
              file: file,
              mime: mime,
              showPlayGlyph: !forStrip,
            ),
      ),
    ),
  );
}

/// Filmstrip/grid cell inside the viewer: a still frame for photos, a play
/// glyph for video. Deliberately does NOT spin up a video player — see the
/// thumbnailBuilder note above.
class _GalleryViewerThumbnail extends StatelessWidget {
  const _GalleryViewerThumbnail({
    required this.file,
    required this.mime,
    this.showPlayGlyph = true,
  });

  final File? file;
  final String mime;

  /// Suppressed in the viewer's filmstrip: the strip overlays its own tiny
  /// bare play triangle (2026-07-17).
  final bool showPlayGlyph;

  @override
  Widget build(BuildContext context) {
    final isVideo = mime.trim().toLowerCase().startsWith('video/');
    if (file == null || !file!.existsSync() || isVideo) {
      return DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28)),
        child: Center(
          child: Icon(
            isVideo ? AppIcons.playCircle : AppIcons.photoSolid,
            color: Colors.white.withValues(alpha: 0.85),
            size: 22,
          ),
        ),
      );
    }
    return Image.file(
      file!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const BrokenMediaBox(),
    );
  }
}

class ConversationMediaGrid extends StatelessWidget {
  const ConversationMediaGrid({
    super.key,
    required this.items,
    required this.loadFile,
    required this.fetchFile,
    required this.cachedFile,
    required this.onItemTap,
    required this.emptyLabel,
    this.maxItems,
  });

  final List<ConversationAttachmentItem> items;

  /// Resolves an attachment, DOWNLOADING it when it isn't cached yet.
  final Future<File?> Function(AttachmentEventV1 attachment) loadFile;

  /// Та же загрузка, но с причиной отказа: плитке нужно отличить «нет связи»
  /// от «файла больше нет».
  final Future<AttachmentFetch> Function(AttachmentEventV1 attachment)
  fetchFile;

  /// Resolves an attachment only if its blob is already on disk. Used for
  /// video: a poster frame must never be worth a download.
  final Future<File?> Function(AttachmentEventV1 attachment) cachedFile;

  /// Tapped cell, by index into [items] — the viewer pages across the whole
  /// tab, so it needs the position, not just one attachment. Fires for VIDEO
  /// too: video taps used to be silently ignored.
  final Future<void> Function(int index) onItemTap;
  final String emptyLabel;

  /// Inline cap: the grid lays out ALL its cells at once (no viewport
  /// virtualization in shrinkWrap mode), so huge galleries are truncated to
  /// the newest [maxItems].
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(child: Text(emptyLabel)),
      );
    }

    final cap = maxItems;
    final count = cap == null ? items.length : math.min(cap, items.length);
    return GridView.builder(
      // INLINE mode: the grid is a plain block inside the page's own scroll —
      // it must never scroll by itself (a nested scrollable used to trap the
      // page scroll, making it impossible to scroll back to the page top).
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _MediaGridCell(
          // Identity is the blob, not the slot: without this a reload that
          // shifts items would leave each cell showing the previous one's
          // picture (same index, reused State, no re-resolve).
          key: ValueKey<String>(item.attachment.blobId),
          item: item,
          fetchFile: fetchFile,
          cachedFile: cachedFile,
          onTap: () => onItemTap(index),
        );
      },
    );
  }
}

/// One grid cell. Stateful so the blob is resolved EXACTLY once per cell: the
/// old version started `loadFile` from inside `build`, so every rebuild kicked
/// off another resolve — and for an uncached blob, another download.
class _MediaGridCell extends StatefulWidget {
  const _MediaGridCell({
    super.key,
    required this.item,
    required this.fetchFile,
    required this.cachedFile,
    required this.onTap,
  });

  final ConversationAttachmentItem item;
  final Future<AttachmentFetch> Function(AttachmentEventV1 attachment)
  fetchFile;
  final Future<File?> Function(AttachmentEventV1 attachment) cachedFile;
  final VoidCallback onTap;

  @override
  State<_MediaGridCell> createState() => _MediaGridCellState();
}

/// Что сейчас с плиткой: тянем, показали, не смогли.
///
/// 🔴 ДО 15.09.2026 СОСТОЯНИЕ БЫЛО ОДНО — «нет картинки», и серый значок
/// означал сразу три разные вещи: «ещё качаю», «не скачалось» и «файла нет
/// вовсе». Владелец увидел ровно это: сетка пустых плиток без объяснения.
/// Причина в тот раз была внешняя — связь на телефоне отваливалась, — но
/// узнать об этом из окна было нельзя, и повторить попытку тоже.
enum _CellPhase { loading, ready, failed, gone }

class _MediaGridCellState extends State<_MediaGridCell> {
  File? _file;
  VideoThumbnail? _thumb;
  _CellPhase _phase = _CellPhase.loading;

  bool get _isVideo =>
      (widget.item.attachment.mime ?? '').toLowerCase().startsWith('video/');

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    if (mounted && _phase != _CellPhase.loading) {
      setState(() => _phase = _CellPhase.loading);
    }
    final att = widget.item.attachment;
    if (_isVideo) {
      // Cache-ONLY. This tab used to call the downloading loader for every
      // cell and then throw the bytes away behind a static icon — opening
      // "Videos" pulled down every video in the conversation, in full, to show
      // nothing. A video the user has never opened simply keeps its placeholder
      // until they tap it.
      final f = await widget.cachedFile(att);
      // Пусто у видео — это НЕ отказ: ролик, который ещё не открывали, мы
      // намеренно не тянем целиком ради одной картинки. Плитка ждёт нажатия.
      if (!mounted) return;
      if (f == null) {
        setState(() => _phase = _CellPhase.ready);
        return;
      }
      final thumb = await VideoThumbnailCache.forVideo(
        key: att.blobId,
        videoPath: f.path,
      );
      if (!mounted) return;
      setState(() {
        _file = f;
        _thumb = thumb;
        _phase = _CellPhase.ready;
      });
      return;
    }
    final got = await widget.fetchFile(att);
    if (!mounted) return;
    setState(() {
      _file = got.file;
      _phase = got.file != null
          ? _CellPhase.ready
          // Файла больше нет на сервере — «повторить» тут ничего не даст, и
          // звать на это нажимать нечестно.
          : (got.failure == kAttachmentGoneCode
                ? _CellPhase.gone
                : _CellPhase.failed);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Не смогли — нажатие ПОВТОРЯЕТ попытку, а не открывает пустоту: до сих
    // пор плитка вела в просмотрщик, которому нечего было показать.
    final failed = !_isVideo && _phase == _CellPhase.failed;
    return InkWell(
      onTap: failed ? () => unawaited(_resolve()) : widget.onTap,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: _isVideo ? _buildVideo(context) : _buildImage(context),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final f = _file;
    if (f != null && f.existsSync()) return _decoded(context, f);
    final cs = Theme.of(context).colorScheme;
    if (_phase == _CellPhase.gone) {
      // Перечёркнутая картинка: файла больше нет, и нажимать некуда.
      return Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      );
    }
    if (_phase == _CellPhase.loading) {
      // Пока тянем — тихий кружок, а не «сломанная картинка»: ожидание и
      // отказ выглядели одинаково, и по сетке нельзя было понять, ждать ли.
      return Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
    }
    // Не скачалось: стрелка вниз вместо значка фотографии — она обещает
    // действие, и нажатие его выполняет.
    return Center(
      child: Icon(
        Icons.download_rounded,
        color: cs.onSurfaceVariant.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _buildVideo(BuildContext context) {
    final frame = _thumb?.file;
    final durationMs = _thumb?.durationMs;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (frame != null && frame.existsSync())
          _decoded(context, frame)
        else
          _placeholder(AppIcons.video),
        if (frame != null)
          // Keeps the play glyph and the badge legible over a bright frame.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x59000000)],
              ),
            ),
          ),
        Center(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.42),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
        if (durationMs != null && durationMs > 0)
          Positioned(
            right: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text(
                  formatVideoDuration(durationMs),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Decodes to the grid-cell footprint (px = cell edge × DPR), not the full
  /// source image. Cells are ~square, so the longer edge keeps cover crisp.
  Widget _decoded(BuildContext context, File f) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final longestEdge = constraints.biggest.longestSide;
        final cacheDim = longestEdge.isFinite && longestEdge > 0
            ? (longestEdge * dpr).round()
            : null;
        return Image.file(
          f,
          fit: BoxFit.cover,
          cacheWidth: cacheDim,
          cacheHeight: cacheDim,
          errorBuilder: (_, _, _) => const BrokenMediaBox(),
        );
      },
    );
  }

  Widget _placeholder(IconData icon) => Center(
    child: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

/// True when this attachment is a recording made with the mic button rather
/// than a music file. In-app AAC recordings share `audio/mp4` with real music,
/// so the captured waveform is what tells them apart — same rule as the bubble.
bool _isVoiceItem(ConversationAttachmentItem item) =>
    isVoiceAttachmentMime(item.attachment.mime ?? '') ||
    (item.attachment.waveform?.isNotEmpty ?? false);

String _voiceLabel(BuildContext context) => wave1Text(
  context,
  ru: 'Голосовое сообщение',
  en: 'Voice message',
  uk: 'Голосове повідомлення',
  es: 'Mensaje de voz',
  pt: 'Mensagem de voz',
  fr: 'Message vocal',
  de: 'Sprachnachricht',
);

/// Best name we can put on an audio row: the tags the sender read off the file,
/// then the original filename, then a generic label. The filename fallback
/// matters — every track sent before the tags travelled in the payload has none.
String _musicTitle(BuildContext context, ConversationAttachmentItem item) {
  if (_isVoiceItem(item)) return _voiceLabel(context);
  // Имя файла в поле названия — не тег: такой песне лучше имя без расширения.
  final tagged = taggedMusicTitle(item.attachment);
  if (tagged != null) return tagged;
  final filename = item.attachment.filename?.trim();
  if (filename != null && filename.isNotEmpty) {
    final stem = p.basenameWithoutExtension(filename).trim();
    if (stem.isNotEmpty) return stem;
  }
  return context.l10n.music;
}

String _musicArtist(BuildContext context, ConversationAttachmentItem item) {
  if (_isVoiceItem(item)) return '';
  final artist = item.attachment.musicArtist?.trim();
  if (artist != null && artist.isNotEmpty) return artist;
  return wave1Text(
    context,
    ru: 'Неизвестен',
    en: 'Unknown artist',
    uk: 'Невідомий',
    es: 'Desconocido',
    pt: 'Desconhecido',
    fr: 'Inconnu',
    de: 'Unbekannt',
  );
}

String _hhmm(int atMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(atMs);
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

class ConversationFilesList extends StatelessWidget {
  const ConversationFilesList({
    super.key,
    required this.items,
    required this.loadFile,
    required this.emptyLabel,
    this.maxItems,
  });

  final List<ConversationAttachmentItem> items;
  final Future<File?> Function(AttachmentEventV1 attachment) loadFile;
  final String emptyLabel;

  /// Inline cap — see [ConversationMediaGrid.maxItems].
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(child: Text(emptyLabel)),
      );
    }

    final cap = maxItems;
    final count = cap == null ? items.length : math.min(cap, items.length);
    return ListView.separated(
      // INLINE mode — scrolls with the page, never by itself.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final att = item.attachment;
        // The real file name, not the MIME type: this row used to be titled
        // "application/pdf" and sized "3355443 B".
        final filename = att.filename?.trim();
        final title = (filename != null && filename.isNotEmpty)
            ? filename
            : ((att.mime ?? '').isEmpty ? l10n.file : att.mime!);

        return ListTile(
          leading: const Icon(AppIcons.fileOutline),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${formatAttachmentBytes(att.sizeBytes)} • ${_hhmm(item.createdAtMs)}',
          ),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final savedTo = l10n.savedTo;
            final file = await loadFile(att);
            if (file == null) return;
            messenger.showSnackBar(
              SecretlySnackBar(content: Text(savedTo(file.path))),
            );
          },
        );
      },
    );
  }
}

enum _MusicMenuAction { play, showInChat, share, save }

/// The Music tab. A row per track with its real title, artist and a three-dot
/// menu — it used to be an untitled `ListTile` reading "Music" over a raw byte
/// count, and tapping it downloaded the file to show a snackbar with a path.
class ConversationMusicList extends StatelessWidget {
  const ConversationMusicList({
    super.key,
    required this.controller,
    required this.convoId,
    required this.items,
    required this.emptyLabel,
    this.onShowInChat,
    this.maxItems,
  });

  final AppController controller;
  final String convoId;
  final List<ConversationAttachmentItem> items;
  final String emptyLabel;

  /// Null where there is no chat to jump into (so the entry is hidden).
  final Future<void> Function(ConversationAttachmentItem item)? onShowInChat;

  /// Inline cap — see [ConversationMediaGrid.maxItems].
  final int? maxItems;

  SharedAudioTrack _trackFor(BuildContext context, int index) {
    final item = items[index];
    return SharedAudioTrack(
      trackId: item.attachment.blobId,
      kind: SharedAudioTrackKind.attachment,
      title: _musicTitle(context, item),
      artist: _musicArtist(context, item),
      sourceBlobId: item.attachment.blobId,
      sourceConvoId: convoId,
      resolveFilePath: () async {
        final f = await controller.ensureCachedAttachmentFile(item.attachment);
        return f.path;
      },
    );
  }

  Future<void> _play(BuildContext context, int index) async {
    // Hands the WHOLE tab to the player, not one track, so next/previous walk
    // the conversation's music the way they do from a bubble.
    final queue = <SharedAudioTrack>[
      for (var i = 0; i < items.length; i++) _trackFor(context, i),
    ];
    await controller.playSharedAudioQueue(queue: queue, index: index);
  }

  Future<void> _handle(
    BuildContext context,
    _MusicMenuAction action,
    int index,
  ) async {
    final item = items[index];
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    switch (action) {
      case _MusicMenuAction.play:
        await _play(context, index);
      case _MusicMenuAction.showInChat:
        await onShowInChat?.call(item);
      case _MusicMenuAction.save:
        try {
          final source = await controller.ensureCachedAttachmentFile(
            item.attachment,
          );
          final saved = await saveAttachmentToDownloads(
            attachment: item.attachment,
            createdAtMs: item.createdAtMs,
            source: source,
          );
          messenger.showSnackBar(
            SecretlySnackBar(content: Text(l10n.savedTo(saved.path))),
          );
        } catch (e) {
          messenger.showSnackBar(
            SecretlySnackBar(content: Text(l10n.downloadFailed(e.toString()))),
          );
        }
      case _MusicMenuAction.share:
        try {
          final source = await controller.ensureCachedAttachmentFile(
            item.attachment,
          );
          await shareAttachmentFile(
            attachment: item.attachment,
            createdAtMs: item.createdAtMs,
            source: source,
          );
        } catch (e) {
          messenger.showSnackBar(
            SecretlySnackBar(content: Text(l10n.downloadFailed(e.toString()))),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(child: Text(emptyLabel)),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final cap = maxItems;
    final count = cap == null ? items.length : math.min(cap, items.length);
    return ListView.separated(
      // INLINE mode — scrolls with the page, never by itself.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final item = items[index];
        final isVoice = _isVoiceItem(item);
        final durationMs = item.attachment.durationMs;

        // Duration is only carried for voice — a music file sent from the
        // picker has none, so the size stands in rather than a blank.
        final meta = <String>[
          if (!isVoice) _musicArtist(context, item),
          if (durationMs != null && durationMs > 0)
            formatVideoDuration(durationMs),
          formatAttachmentBytes(item.attachment.sizeBytes),
          if (isVoice) _hhmm(item.createdAtMs),
        ];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isVoice ? AppIcons.mic : AppIcons.musicNote,
              size: 20,
              color: cs.primary.withValues(alpha: 0.9),
            ),
          ),
          title: Text(
            _musicTitle(context, item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            meta.join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          onTap: () => _play(context, index),
          trailing: PopupMenuButton<_MusicMenuAction>(
            tooltip: wave1Text(
              context,
              ru: 'Действия',
              en: 'Actions',
              uk: 'Дії',
              es: 'Acciones',
              pt: 'Ações',
              fr: 'Actions',
              de: 'Aktionen',
            ),
            icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
            onSelected: (action) => _handle(context, action, index),
            itemBuilder: (context) => [
              PopupMenuItem<_MusicMenuAction>(
                value: _MusicMenuAction.play,
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      wave1Text(
                        context,
                        ru: 'Воспроизвести',
                        en: 'Play',
                        uk: 'Відтворити',
                        es: 'Reproducir',
                        pt: 'Reproduzir',
                        fr: 'Lire',
                        de: 'Abspielen',
                      ),
                    ),
                  ],
                ),
              ),
              if (onShowInChat != null)
                PopupMenuItem<_MusicMenuAction>(
                  value: _MusicMenuAction.showInChat,
                  child: Row(
                    children: [
                      // Same glyph the fullscreen viewer uses for this action.
                      const Icon(Icons.visibility_outlined, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        wave1Text(
                          context,
                          ru: 'Показать в чате',
                          en: 'Show in chat',
                          uk: 'Показати в чаті',
                          es: 'Mostrar en el chat',
                          pt: 'Mostrar no chat',
                          fr: 'Afficher dans la discussion',
                          de: 'Im Chat anzeigen',
                        ),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem<_MusicMenuAction>(
                value: _MusicMenuAction.save,
                child: Row(
                  children: [
                    const Icon(AppIcons.cloudDownload, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      wave1Text(
                        context,
                        ru: 'Сохранить',
                        en: 'Save',
                        uk: 'Зберегти',
                        es: 'Guardar',
                        pt: 'Guardar',
                        fr: 'Enregistrer',
                        de: 'Speichern',
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<_MusicMenuAction>(
                value: _MusicMenuAction.share,
                child: Row(
                  children: [
                    const Icon(Icons.share_outlined, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      wave1Text(
                        context,
                        ru: 'Поделиться',
                        en: 'Share',
                        uk: 'Поділитися',
                        es: 'Compartir',
                        pt: 'Partilhar',
                        fr: 'Partager',
                        de: 'Teilen',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Composite widget rendering a 4-tab gallery (Photos / Videos / Files / Music)
/// for any conversation (DM or group).
///
/// INLINE: the section lays out at its natural height and scrolls together
/// with the page. The previous version put a TabBarView into a fixed
/// 0.62-screen box, so the grid scrolled independently — with many photos the
/// page itself could no longer be scrolled back to the top.
class ConversationMediaGallerySection extends StatefulWidget {
  const ConversationMediaGallerySection({
    super.key,
    required this.controller,
    required this.convoId,
    this.title = '',
  });

  final AppController controller;
  final String convoId;

  /// Shown in the fullscreen viewer's top bar. Optional so existing hosts keep
  /// working unchanged; pass the peer/room name to name the media's origin.
  final String title;

  @override
  State<ConversationMediaGallerySection> createState() =>
      _ConversationMediaGallerySectionState();
}

class _ConversationMediaGallerySectionState
    extends State<ConversationMediaGallerySection>
    with SingleTickerProviderStateMixin {
  static const int _gridCap = 120;
  static const int _listCap = 80;

  late final TabController _tabs = TabController(length: 4, vsync: this);
  Future<ConversationMediaGalleryVm>? _vmFuture;
  String _vmConvoId = '';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<ConversationMediaGalleryVm> _vmFor(String convoId) {
    // Memoized: rebuilds of the host page must not re-scan the conversation.
    final cached = _vmFuture;
    if (cached != null && _vmConvoId == convoId) return cached;
    final fut = loadConversationMediaFiles(widget.controller, convoId);
    _vmFuture = fut;
    _vmConvoId = convoId;
    return fut;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    final convoId = widget.convoId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(
              text: wave1Text(
                context,
                ru: 'Фото',
                en: 'Photos',
                uk: 'Фото',
                es: 'Fotos',
                pt: 'Fotos',
                fr: 'Photos',
                de: 'Fotos',
              ),
            ),
            Tab(
              text: wave1Text(
                context,
                ru: 'Видео',
                en: 'Videos',
                uk: 'Відео',
                es: 'Videos',
                pt: 'Videos',
                fr: 'Vidéos',
                de: 'Videos',
              ),
            ),
            Tab(text: l10n.contactDetailsFilesTab),
            Tab(
              text: wave1Text(
                context,
                ru: 'Музыка',
                en: 'Music',
                uk: 'Музика',
                es: 'Musica',
                pt: 'Musica',
                fr: 'Musique',
                de: 'Musik',
              ),
            ),
          ],
        ),
        FutureBuilder<ConversationMediaGalleryVm>(
          future: _vmFor(convoId),
          builder: (context, snap) {
            final vm = snap.data;
            if (vm == null) {
              // Compact loading strip — no full-screen placeholder box.
              return const SizedBox(height: 180, child: ShimmerMediaGrid());
            }
            Future<File?> loadFile(AttachmentEventV1 a) =>
                loadConversationAttachmentFile(controller, a);
            Future<AttachmentFetch> fetchFile(AttachmentEventV1 a) =>
                fetchConversationAttachmentFile(controller, a);
            Future<File?> cachedFile(AttachmentEventV1 a) =>
                cachedConversationAttachmentFile(controller, a);
            // The grid indexes into the FULL tab list (maxItems only caps
            // how many cells it lays out), so the index lines up and the
            // viewer can even page past the cap.
            Future<void> openAt(
              List<ConversationAttachmentItem> tabItems,
              int index,
            ) => openConversationMediaViewer(
              context,
              controller,
              items: tabItems,
              index: index,
              title: widget.title,
              convoId: convoId,
            );
            // Only the ACTIVE tab's content is built, inline at natural
            // height (TabBarView needs a bounded box, i.e. a nested scroll).
            return AnimatedBuilder(
              animation: _tabs,
              builder: (context, _) => switch (_tabs.index) {
                1 => ConversationMediaGrid(
                  items: vm.videos,
                  loadFile: loadFile,
                  fetchFile: fetchFile,
                  cachedFile: cachedFile,
                  onItemTap: (i) => openAt(vm.videos, i),
                  maxItems: _gridCap,
                  emptyLabel: wave1Text(
                    context,
                    ru: 'Нет видео',
                    en: 'No videos',
                    uk: 'Немає відео',
                    es: 'No hay videos',
                    pt: 'Sem videos',
                    fr: 'Aucune vidéo',
                    de: 'Keine Videos',
                  ),
                ),
                2 => ConversationFilesList(
                  items: vm.files,
                  loadFile: loadFile,
                  maxItems: _listCap,
                  emptyLabel: l10n.contactDetailsNoFiles,
                ),
                3 => ConversationMusicList(
                  controller: controller,
                  convoId: convoId,
                  items: vm.music,
                  onShowInChat: (item) => showAttachmentInChat(
                    context,
                    controller,
                    convoId,
                    item.attachment,
                  ),
                  maxItems: _listCap,
                  emptyLabel: wave1Text(
                    context,
                    ru: 'Нет музыки',
                    en: 'No music',
                    uk: 'Немає музики',
                    es: 'No hay musica',
                    pt: 'Sem musica',
                    fr: 'Aucune musique',
                    de: 'Keine Musik',
                  ),
                ),
                _ => ConversationMediaGrid(
                  items: vm.photos,
                  loadFile: loadFile,
                  fetchFile: fetchFile,
                  cachedFile: cachedFile,
                  onItemTap: (i) => openAt(vm.photos, i),
                  maxItems: _gridCap,
                  emptyLabel: wave1Text(
                    context,
                    ru: 'Нет фото',
                    en: 'No photos',
                    uk: 'Немає фото',
                    es: 'No hay fotos',
                    pt: 'Sem fotos',
                    fr: 'Aucune photo',
                    de: 'Keine Fotos',
                  ),
                ),
              },
            );
          },
        ),
      ],
    );
  }
}
