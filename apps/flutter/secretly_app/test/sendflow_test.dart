// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// SendFlow (24.11.2026): окно отправки медиа из скрепки по макету.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/media/video_compressor.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/ui/media_viewer/media_edits.dart';

void main() {
  final sheet = File('lib/ui/chat_attachment_picker_sheet.dart').readAsStringSync();

  test('Э1: шапка, альбомы, лимит 10, подпись в листе, порядок выбора, '
      '«Отменить выбор?»', () {
    expect(sheet.contains('const int kSendFlowMaxSelection = 10;'), isTrue);
    expect(sheet.contains('enum _GalleryFilter { recent, favorites, videos, screenshots }'), isTrue);
    expect(sheet.contains('PMDarwinAssetCollectionSubtype.smartAlbumFavorites'), isTrue);
    expect(sheet.contains('PMDarwinAssetCollectionSubtype.smartAlbumScreenshots'), isTrue);
    expect(sheet.contains("ValueKey('sendflow:sheet-caption')"), isTrue);
    expect(sheet.contains('for (final id in _selectedPhotoIds)'), isTrue);
    expect(sheet.contains('canPop: _selectedPhotoIds.isEmpty'), isTrue);
    // Островок подписи — как поле ввода чата.
    expect(sheet.contains('child: ComposerDropSurface('), isTrue);
  });

  test('Э2: перелёт (Hero), смахивание вниз, стекло/мат из токенов, лента '
      'выбранных, строка сведений', () {
    expect(sheet.contains("tag: 'sendflow:\${asset.id}'"), isTrue);
    expect(sheet.contains("tag: 'sendflow:\${widget.asset.id}'"), isTrue);
    expect(sheet.contains('onVerticalDragUpdate: _zoomed ? null : _onDragUpdate'), isTrue);
    expect(sheet.contains('mediaViewerGlassFilter(20)'), isTrue);
    expect(sheet.contains('Widget _selectionStrip()'), isTrue);
    expect(sheet.contains("ValueKey('sendflow:info')"), isTrue);
    // Старое самодельное стекло ушло.
    expect(sheet.contains('ImageFilter.blur(sigmaX: 18, sigmaY: 18)'), isFalse);
  });

  test('Э3: качество видео → длинная сторона; HD/SD и звук идут в отправку', () {
    expect(VideoCompressor.maxSideForQuality(480), 854);
    expect(VideoCompressor.maxSideForQuality(720), 1280);
    expect(VideoCompressor.maxSideForQuality(1080), 1920);
    final c = File('lib/app/app_controller.dart').readAsStringSync();
    expect(c.contains('maxSide: videoSide,'), isTrue);
    expect(c.contains('mute: pending.muteVideo,'), isTrue);
    expect(c.contains('downscalePhotoForSend(sendPath, maxSide: photoSide)'), isTrue);
    expect(c.contains("if (sendPath != before) sendMime = 'image/jpeg';"), isTrue);
    final v = File('lib/media/video_compressor.dart').readAsStringSync();
    expect(v.contains("final audio = mute ? '-an'"), isTrue);
  });

  test('Э3: пропорции 3:2, 4:3, 9:16, 3:4 в редакторе', () {
    expect(cropAspectRatio(CropAspect.landscape32, 0, 1), 1.5);
    expect(cropAspectRatio(CropAspect.classic43, 0, 1), closeTo(4 / 3, 1e-9));
    expect(cropAspectRatio(CropAspect.tall916, 0, 1), closeTo(9 / 16, 1e-9));
    expect(cropAspectRatio(CropAspect.portrait34, 1, 1), closeTo(4 / 3, 1e-9));
  });

  test('Э3: стрелка рисуется (линия + наконечник)', () {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    paintStroke(
      canvas,
      const DrawStroke(
        id: 'a',
        tool: StrokeTool.arrow,
        color: Color(0xFFFF0000),
        width: 8,
        points: [Offset(10, 10), Offset(60, 40), Offset(140, 90)],
      ),
    );
    rec.endRecording().dispose();
    final round = DrawStroke.fromJson(
      const DrawStroke(
        id: 'a',
        tool: StrokeTool.arrow,
        color: Color(0xFFFF0000),
        width: 8,
        points: [Offset(1, 1), Offset(2, 2)],
      ).toJson(),
    );
    expect(round?.tool, StrokeTool.arrow);
  });

  test('Э4–Э5: новые поля сообщения — читаются, а старое сообщение без них '
      'остаётся как было', () {
    final a = AttachmentEventV1(
      eventId: 'e',
      blobId: 'b',
      fileKeyB64: 'k',
      sizeBytes: 1,
      mime: 'image/jpeg',
      caption: 'привет',
      captionAbove: true,
      spoiler: true,
      viewOnce: true,
    );
    final j = a.toJson();
    expect(j['cap_above'], true);
    expect(j['spoiler'], true);
    expect(j['view_once'], true);
    final plain = AttachmentEventV1(
      eventId: 'e',
      blobId: 'b',
      fileKeyB64: 'k',
      sizeBytes: 1,
    ).toJson();
    expect(plain.containsKey('cap_above'), isFalse);
    expect(plain.containsKey('spoiler'), isFalse);
    expect(plain.containsKey('view_once'), isFalse);
    final payload = E2ePayloadV1(senderDeviceId: 'd', createdAtMs: 1, events: [a]);
    final back = E2ePayloadV1.decode(payload.encode()).events.single as AttachmentEventV1;
    expect(back.captionAbove && back.spoiler && back.viewOnce, isTrue);
    // Обычные сообщения возможностей не несут (выравнивание 160 байт).
    expect(payload.caps, isEmpty);
    expect(E2ePayloadV1.ownCaps, contains('msx1'));
  });

  test('🔴 Э5: спойлер и одноразовое — только если все получатели умеют; '
      'одноразовое не пересылается, не сохраняется, не в галерее, не в альбоме', () {
    final c = File('lib/app/app_controller.dart').readAsStringSync();
    expect(c.contains('Future<bool> mediaSpoilerSupportedFor(String convoId)'), isTrue);
    expect(c.contains('cap: E2ePayloadV1.capMediaSpoilerOnce,'), isTrue);
    expect(c.contains('caps: E2ePayloadV1.ownCaps,'), isTrue);
    final chat = File('lib/ui/chat_screen.dart').readAsStringSync();
    expect(chat.contains('if (payload.viewOnce) continue;'), isTrue);
    expect(chat.contains('if (attachment.viewOnce) return;'), isTrue);
    expect(chat.contains('if (pa.viewOnce || pb.viewOnce) return false;'), isTrue);
    expect(chat.contains('!existingMediaItems.any((i) => i.viewOnce)'), isTrue);
    final g = File('lib/ui/widgets/conversation_media_gallery.dart').readAsStringSync();
    expect(g.contains('if (payload.viewOnce) continue;'), isTrue);
    expect(sheet.contains('_explainSpoilerUnavailable()'), isTrue);
  });

  test('Э6: «без звука» — флаг реле, беззвучный канал Android', () {
    final c = File('lib/app/app_controller.dart').readAsStringSync();
    expect(c.contains("if (silent) 'silent': true,"), isTrue);
    expect('silent: flags.silent,'.allMatches(c).length, 4);
    final kt = File('android/app/src/main/kotlin/com/secretly/secretly_app/MessageNotifier.kt').readAsStringSync();
    expect(kt.contains('SILENT_CHANNEL_ID = "secretly_messages_silent_v1"'), isTrue);
    final relay = File('../../../server/relay/src/main.rs').readAsStringSync();
    expect(relay.contains('"channel_id": "secretly_messages_silent_v1"'), isTrue);
    expect(relay.contains('if !payload.sound_off {'), isTrue);
  });

  test('🔴 разбор SendFlow: группы и ПК без спойлера/одноразового, одноразовое '
      'не скачивается заранее, не листается, не в цитате; «как файл» не снимает '
      'флаги молча; «без звука» у видео не уходит со звуком', () {
    final c = File('lib/app/app_controller.dart').readAsStringSync();
    expect(c.contains("if (id.startsWith('group:')) return false;"), isTrue);
    expect(c.contains('if (ev is AttachmentEventV1 && ev.viewOnce) continue;'), isTrue);
    expect(c.contains('if (pending.muteVideo && sendPath == pending.filePath) {'), isTrue);
    final m = File('lib/models/e2e_payload_v1.dart').readAsStringSync();
    expect(m.contains('defaultTargetPlatform == TargetPlatform.android))\n      capMediaSpoilerOnce'), isTrue);
    final chat = File('lib/ui/chat_screen.dart').readAsStringSync();
    expect(chat.contains('if (imageItem.attachment.viewOnce) continue;'), isTrue);
    expect(chat.contains('!payload.spoiler &&\n                !payload.viewOnce'), isTrue);
    expect(chat.contains("caption: item.viewOnce ? '' : item.caption,"), isTrue);
    expect(sheet.contains('_flowSpoiler ||\n              _selectedPhotoIds.any'), isTrue);
    expect(sheet.contains('_sendButtonKey.currentContext ?? context'), isTrue);
    final relay = File('../../../server/relay/src/main.rs').readAsStringSync();
    expect(relay.contains('const SILENT_CHANNEL_MIN_BUILD: i64 = 755;'), isTrue);
    expect(relay.contains('if payload.sound_off && payload.silent_channel_ok {'), isTrue);
  });
}
