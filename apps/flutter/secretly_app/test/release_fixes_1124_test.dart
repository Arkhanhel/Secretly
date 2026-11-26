// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Правки перед выпуском 24.11.2026: GIF отдельной вкладкой, миниатюра в
// цитате ответа, спокойная кнопка комнаты, листание и редактор в просмотре
// снимков из скрепки.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ui/widgets/conversation_media_gallery.dart';

AttachmentEventV1 _att({String? mime, String? filename}) => AttachmentEventV1(
  eventId: 'e',
  blobId: 'b',
  fileKeyB64: 'k',
  sizeBytes: 1,
  mime: mime,
  filename: filename,
);

void main() {
  test('🔴 GIF — своя вкладка: image/gif и файлы .gif, не фото и не видео', () {
    expect(isConversationGifAttachment(_att(mime: 'image/gif')), isTrue);
    expect(isConversationGifAttachment(_att(mime: 'IMAGE/GIF')), isTrue);
    expect(isConversationGifAttachment(_att(mime: 'video/mp4', filename: 'cat.gif.mp4')), isTrue);
    expect(isConversationGifAttachment(_att(mime: 'image/jpeg')), isFalse);
    expect(isConversationGifAttachment(_att(mime: 'video/mp4')), isFalse);
    final src = File('lib/ui/widgets/conversation_media_gallery.dart').readAsStringSync();
    expect(src.contains("TabController(length: 5"), isTrue);
    expect(src.contains("'GIF',"), isTrue);
    expect(src.contains('onItemTap: (i) => openAt(vm.gifs, i)'), isTrue);
  });

  test('🔴 цитата ответа на фото/видео — с миниатюрой (квадрат, обрезка)', () {
    final s = File('lib/ui/chat_screen.dart').readAsStringSync();
    expect(s.contains('final AttachmentEventV1? media;'), isTrue);
    expect(s.contains('if (snippet.media case final media?)'), isTrue);
    expect(s.contains('_replyThumbLoader = widget.controller.cachedAttachmentFile;'), isTrue);
    // Миниатюра — фиксированный квадрат 36×36 с BoxFit.cover.
    final i = s.indexOf('class _ReplyMediaThumbState');
    final body = s.substring(i, i + 2500);
    expect(body.contains('width: 36'), isTrue);
    expect(body.contains('height: 36'), isTrue);
    expect(body.contains('BoxFit.cover'), isTrue);
  });

  test('кнопка «Передать права или удалить» — красный на красноватом, без '
      'синей заливки', () {
    final s = File('lib/ui/room_details_screen.dart').readAsStringSync();
    expect(s.contains('style: _destructiveTonalStyle(context),'), isTrue);
    expect(s.contains("key: const ValueKey('room-admin:owner-action')"), isTrue);
  });

  test('🔴 просмотр снимков из скрепки: листание по галерее, новый редактор, '
      'правки и подписи не теряются, отправляется тот, что на экране', () {
    final s = File('lib/ui/chat_attachment_picker_sheet.dart').readAsStringSync();
    expect(s.contains('pageBuilder: (_, __, ___) => _AssetPreviewPager('), isTrue);
    expect(s.contains('PageView.builder('), isTrue);
    expect(s.contains('NeverScrollableScrollPhysics()'), isTrue);
    expect(s.contains('final edits = await openMediaEditor('), isTrue);
    expect(s.contains('exportEditedImageFile('), isTrue);
    expect(s.contains('initialEditedPath: _editedPathByAssetId[a.id],'), isTrue);
    expect(s.contains('assetId: widget.asset.id,'), isTrue);
    expect(s.contains('.where((a) => a.id == req.assetId)'), isTrue);
  });

  test('🔴 разбор перед выпуском: скрепка не раскрывает снимки целиком, видео '
      'и FFmpeg — только у снимка на экране, панели гаснут, а не уезжают', () {
    final s = File('lib/ui/chat_attachment_picker_sheet.dart').readAsStringSync();
    final load = s.substring(
      s.indexOf('  Future<void> _load() async {'),
      s.indexOf('  Timer? _videoStartTimer;'),
    );
    expect(load.contains('instantiateImageCodec'), isFalse);
    expect(load.contains('orientatedWidth'), isTrue);
    expect(s.contains('cacheWidth: _workW >= _workH ? _displayDecodeSide(context) : null'), isTrue);
    expect(s.contains('_scheduleVideoStart();'), isTrue);
    expect(s.contains('if (!mounted || !widget.active) return;'), isTrue);
    expect(s.contains('chromeOpacity: _chromeFor(i),'), isTrue);
    // 25.11.2026: миниатюры — общий загрузчик с памятью (gallery_thumbs.dart).
    expect(s.contains('thumbnail: GalleryThumbs.instance.bytes(a),'), isTrue);
    expect(s.contains('unawaited(_rotateBaked())'), isTrue);
  });

  test('🔴 стикеры в ленте: не чаще 60 к/с, 3 повтора, пауза вне экрана, '
      'разбор в фоне; «Избранное» у встроенных скрыто', () {
    final w = File('lib/ui/widgets/secretly_sticker_widgets.dart').readAsStringSync();
    expect(w.contains('with PacedTickerProviderStateMixin'), isTrue);
    // Разбор в фоне — и у ассета, и у файла своего набора.
    expect('backgroundLoading: true'.allMatches(w).length, 2);
    expect(w.contains('static const int defaultLoops = 3;'), isTrue);
    expect(w.contains('VisibilityDetector('), isTrue);
    final c = File('lib/app/app_controller.dart').readAsStringSync();
    expect(c.contains('if (isDesignerStickerPackId(sticker.packId)) return;'), isTrue);
    final chat = File('lib/ui/chat_screen.dart').readAsStringSync();
    expect(chat.contains('if (_skipLockedPremiumSticker(sticker)) continue;'), isTrue);
  });
}
