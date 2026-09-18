// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../icons/app_icons.dart';
import '../wave1_l10n.dart';
import 'broken_media_box.dart';

class ChatListSubtitlePreview extends StatefulWidget {
  const ChatListSubtitlePreview({
    super.key,
    required this.controller,
    required this.convoId,
    required this.previewVersion,
    required this.subtitleFallback,
  });

  final AppController controller;
  final String convoId;
  final int previewVersion;
  final String subtitleFallback;

  @override
  State<ChatListSubtitlePreview> createState() =>
      _ChatListSubtitlePreviewState();
}

class _ChatListSubtitlePreviewState extends State<ChatListSubtitlePreview> {
  static const int _previewCacheMaxEntries = 160;
  static final Map<String, ChatListPreview> _previewCache =
      <String, ChatListPreview>{};
  // Last resolved preview per conversation (version-independent). Used as the
  // initialData fallback so a versioned cache-miss shows the previous real
  // preview during the brief async re-resolve, never the raw-id fallback — this
  // is what kills the "peer id flashes in the subtitle" flicker.
  static final Map<String, ChatListPreview> _lastByConvo =
      <String, ChatListPreview>{};

  ChatListPreview? _preview;
  Future<ChatListPreview>? _future;
  int _loadSeq = 0;

  ChatListPreview? _seedPreview(String convoId, int previewVersion) =>
      _exactCached(convoId, previewVersion) ?? _lastByConvo[convoId];

  /// Точное попадание в кэш — и одновременно продление жизни записи.
  ///
  /// Ключ включает `previewVersion`, поэтому попадание означает, что запрос
  /// вернёт ровно эти же данные. Раньше запрос всё равно уходил, и один кадр
  /// списка стоил ~40 расшифровок и несколько запросов в БД НА КАЖДУЮ строку —
  /// при том, что ответ уже лежал рядом.
  ///
  /// `remove` + повторная вставка держат порядок ключей как LRU: выселение
  /// (`_previewCache.keys.first`) иначе выбрасывало бы самые ранние по вставке
  /// записи, то есть в длинном списке — те самые, что видны на экране.
  ChatListPreview? _exactCached(String convoId, int previewVersion) {
    final key = _cacheKey(convoId, previewVersion);
    final hit = _previewCache.remove(key);
    if (hit == null) return null;
    _previewCache[key] = hit;
    return hit;
  }

  @override
  void initState() {
    super.initState();
    _preview = _seedPreview(widget.convoId, widget.previewVersion);
    _future = _futureFor(widget.convoId, widget.previewVersion);
  }

  @override
  void didUpdateWidget(covariant ChatListSubtitlePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.convoId != widget.convoId ||
        oldWidget.previewVersion != widget.previewVersion) {
      _preview = _seedPreview(widget.convoId, widget.previewVersion);
      _future = _futureFor(widget.convoId, widget.previewVersion);
      setState(() {});
    }
  }

  /// `null` при точном попадании: `FutureBuilder` с `future: null` показывает
  /// `initialData`, то есть тот же самый кэшированный результат, только без
  /// похода в базу.
  Future<ChatListPreview>? _futureFor(String convoId, int previewVersion) {
    if (_previewCache.containsKey(_cacheKey(convoId, previewVersion))) {
      return null;
    }
    return _loadFor(convoId, previewVersion);
  }

  String _cacheKey(String convoId, int previewVersion) =>
      '$convoId#$previewVersion';

  Future<ChatListPreview> _loadFor(String convoId, int previewVersion) async {
    final requestSeq = ++_loadSeq;
    // Свип удаления не нужен: `listConversations`, который построил этот
    // список, уже прогнал его по всем чатам разом. Иначе на экране из
    // двенадцати строк он выполнялся бы двенадцать раз подряд.
    final preview = await widget.controller.lastMessagePreviewRich(
      convoId,
      applyRetention: false,
    );
    final key = _cacheKey(convoId, previewVersion);
    if (!_previewCache.containsKey(key) &&
        _previewCache.length >= _previewCacheMaxEntries) {
      _previewCache.remove(_previewCache.keys.first);
    }
    _previewCache[key] = preview;
    _lastByConvo[convoId] = preview;
    if (!mounted ||
        requestSeq != _loadSeq ||
        convoId != widget.convoId ||
        previewVersion != widget.previewVersion) {
      return preview;
    }
    setState(() {
      _preview = preview;
    });
    return preview;
  }

  String _formatLabel(BuildContext context, ChatListPreview preview) {
    switch (preview.kind) {
      case ChatListPreviewKind.photo:
        return wave1Text(context, ru: 'Фотография', en: 'Photo');
      case ChatListPreviewKind.music:
        return wave1Text(context, ru: 'Музыка', en: 'Music');
      case ChatListPreviewKind.voice:
        return wave1Text(
          context,
          ru: 'Голосовое сообщение',
          en: 'Voice message',
          uk: 'Голосове повідомлення',
          es: 'Mensaje de voz',
          pt: 'Mensagem de voz',
          ptBr: 'Mensagem de voz',
          fr: 'Message vocal',
          de: 'Sprachnachricht',
        );
      case ChatListPreviewKind.file:
        return wave1Text(context, ru: 'Файл', en: 'File');
      case ChatListPreviewKind.link:
        return wave1Text(context, ru: 'Ссылка', en: 'Link');
      case ChatListPreviewKind.text:
        return (preview.text ?? '').trim();
      case ChatListPreviewKind.empty:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatListPreview>(
      future: _future,
      initialData: _preview,
      builder: (context, snap) {
        final preview = snap.data;
        final subStyle = TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
        if (preview == null || preview.kind == ChatListPreviewKind.empty) {
          return Text(
            widget.subtitleFallback,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: subStyle,
          );
        }

        final label = _formatLabel(context, preview);
        final sn = (preview.senderName ?? '').trim();
        final isRoom = widget.convoId.startsWith('group:');
        Widget? senderPrefix;
        if (isRoom && sn.isNotEmpty) {
          senderPrefix = Text(
            '$sn: ',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          );
        }

        if (preview.kind == ChatListPreviewKind.text) {
          final text = label.isNotEmpty ? label : widget.subtitleFallback;
          if (senderPrefix != null) {
            return Row(
              children: [
                senderPrefix,
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subStyle,
                  ),
                ),
              ],
            );
          }
          return Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: subStyle,
          );
        }

        Widget leading;
        if (preview.kind == ChatListPreviewKind.photo &&
            preview.imageBlobIds.isNotEmpty) {
          leading = Padding(
            padding: const EdgeInsets.only(top: 1),
            child: _StraightPhotoMiniPreview(
              controller: widget.controller,
              blobIds: preview.imageBlobIds,
            ),
          );
        } else {
          final icon = switch (preview.kind) {
            ChatListPreviewKind.music => AppIcons.musicNote,
            ChatListPreviewKind.file => AppIcons.fileOutline,
            ChatListPreviewKind.link => AppIcons.attach,
            _ => AppIcons.attach,
          };
          leading = Icon(icon, size: 16);
        }

        final text = label.isNotEmpty ? label : widget.subtitleFallback;
        final accentColor = Theme.of(context).colorScheme.primary;
        return Row(
          children: [
            if (senderPrefix != null) senderPrefix,
            IconTheme(
              data: IconThemeData(color: accentColor, size: 16),
              child: leading,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DefaultTextStyle.of(
                  context,
                ).style.copyWith(fontSize: 14, color: accentColor),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StraightPhotoMiniPreview extends StatelessWidget {
  const _StraightPhotoMiniPreview({
    required this.controller,
    required this.blobIds,
  });

  final AppController controller;
  final List<String> blobIds;

  @override
  Widget build(BuildContext context) {
    final unique = blobIds
        .map((blobId) => blobId.trim())
        .where((blobId) => blobId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final ids = unique.take(3).toList(growable: false);
    if (ids.isEmpty) {
      return const Icon(AppIcons.photo, size: 16);
    }

    const thumbSize = 16.0;
    const gap = 1.25;
    final width = (thumbSize * ids.length) + (gap * (ids.length - 1));

    return SizedBox(
      width: width,
      height: thumbSize,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < ids.length; index++) ...[
            if (index > 0) const SizedBox(width: gap),
            _PhotoMiniCircle(
              controller: controller,
              blobId: ids[index],
              size: thumbSize,
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoMiniCircle extends StatefulWidget {
  const _PhotoMiniCircle({
    required this.controller,
    required this.blobId,
    required this.size,
  });

  final AppController controller;
  final String blobId;
  final double size;

  @override
  State<_PhotoMiniCircle> createState() => _PhotoMiniCircleState();
}

class _PhotoMiniCircleState extends State<_PhotoMiniCircle> {
  static final Map<String, File?> _fileCache = <String, File?>{};

  File? _file;
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _file = _fileCache[widget.blobId];
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _PhotoMiniCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blobId != widget.blobId) {
      _file = _fileCache[widget.blobId];
      _future = _load();
    }
  }

  Future<File?> _load() async {
    final file = await widget.controller.cachedAttachmentFileByBlobId(
      widget.blobId,
    );
    _fileCache[widget.blobId] = file;
    if (mounted) {
      setState(() {
        _file = file;
      });
    }
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: widget.size,
      height: widget.size,
      padding: const EdgeInsets.all(0.45),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surface.withValues(alpha: 0.96),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.42),
          width: 0.5,
        ),
      ),
      child: ClipOval(
        child: FutureBuilder<File?>(
          future: _future,
          initialData: _file,
          builder: (context, snap) {
            final file = snap.data;
            if (file == null || !file.existsSync()) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
                ),
                child: Icon(
                  AppIcons.photo,
                  size: widget.size * 0.58,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.76),
                ),
              );
            }
            return Image.file(
              file,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, _, _) => const BrokenMediaBox(iconSize: 10),
            );
          },
        ),
      ),
    );
  }
}
