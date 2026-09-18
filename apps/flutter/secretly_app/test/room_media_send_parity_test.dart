// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/app/pending_attachment_upload.dart';
import 'package:secretly_app/attachments/attachment_service.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/transport/blob_client.dart';

// 🔴 ДВЕ ОШИБКИ ТЕЛЕФОНА В КОМНАТАХ (найдены 16.09.2026, исправлены
// 17.09.2026 по указанию владельца).
//
// 1. Альбом из темы комнаты уходил в «Общий»: экран клал тему в альбом, а
//    очередь отправки её не передавала. Одиночный снимок из той же темы шёл
//    куда надо.
// 2. Одиночный снимок в комнату уходил с геометкой и прочими метаданными
//    камеры — их видит каждый участник. Тот же снимок в личный чат и любой
//    альбом очищались.
//
// Отправка здесь настоящая: шифрование, заливка (сервер файлов подставной),
// запись в базу. Проверяется то, что расшифрует получатель.

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

/// JPEG с геометкой, производителем камеры и поворотом «портрет».
Uint8List _jpegWithGps({int width = 24, int height = 16}) {
  final im = img.Image(width: width, height: height);
  img.fill(im, color: img.ColorRgb8(200, 30, 60));
  final jpg = Uint8List.fromList(img.encodeJpg(im, quality: 90));
  final exif = img.ExifData();
  exif.imageIfd['Orientation'] = 6;
  exif.imageIfd['Make'] = 'SecretlyTestCam';
  exif.gpsIfd['GPSLatitude'] = [55, 30, 10];
  exif.gpsIfd['GPSLongitude'] = 37.5;
  final out = img.injectJpgExif(jpg, exif);
  expect(out, isNotNull, reason: 'снимок для проверки должен собраться');
  final probe = img.decodeJpgExif(out!)!;
  expect(
    probe.imageIfd.sub.containsKey('gps'),
    isTrue,
    reason: 'в исходном снимке геометка обязана быть',
  );
  return out;
}

/// Сервер файлов в памяти: хранит то, что ему залили, — шифртекст.
class _BlobStore {
  final Map<String, Uint8List> uploads = <String, Uint8List>{};

  late final AttachmentService service = AttachmentService(
    blobClient: BlobClient(
      baseUrl: Uri.parse('http://blob.test'),
      httpClient: MockClient((request) async {
        final id = 'blob-${uploads.length + 1}';
        uploads[id] = request.bodyBytes;
        return http.Response(
          jsonEncode(<String, Object?>{
            'blob_id': id,
            'size_bytes': request.bodyBytes.length,
            'expires_at_ms': DateTime.now().millisecondsSinceEpoch + 86400000,
          }),
          200,
        );
      }),
    ),
  );

  /// То, что получит участник, расшифровав файл по ключу из сообщения.
  Future<Uint8List> openFor(AttachmentEventV1 att) =>
      service.decryptDownloaded(uploads[att.blobId]!, fileKeyB64: att.fileKeyB64);
}

class _Room {
  _Room(this.db, this.crypto, this.controller, this.blobs, this.groupId);

  final AppDb db;
  final DartCryptoProvider crypto;
  final AppController controller;
  final _BlobStore blobs;
  final String groupId;

  /// Своё сообщение с вложением — так, как оно лежит в базе отправителя.
  Future<AttachmentEventV1> localAttachment(String payloadEventId) async {
    final rows = await db.listEventsChronological(groupId, limit: 50);
    for (final row in rows) {
      if (row['payload_event_id'] != payloadEventId) continue;
      final local = ((row['local_ciphertext_b64'] as String?) ?? '').trim();
      final stored = local.isNotEmpty
          ? local
          : ((row['ciphertext_b64'] as String?) ?? '').trim();
      final payload = E2ePayloadV1.decode(
        await crypto.decrypt(base64Decode(stored)),
      );
      return payload.events.single as AttachmentEventV1;
    }
    fail('в базе нет сообщения $payloadEventId');
  }
}

/// Комната без других участников: рассылать некому, поэтому отправка доходит
/// до конца без сети — всё остальное (очистка, шифрование, заливка, запись)
/// идёт по-настоящему.
Future<_Room> _soloRoom() async {
  final db = await AppDb.openForTesting();
  addTearDown(db.close);
  final crypto = DartCryptoProvider(
    Uint8List.fromList(List<int>.generate(32, (i) => i)),
  );
  final blobs = _BlobStore();
  final controller = AppController();
  controller.seedRoomRuntimeForTesting(
    db: db,
    profileId: 'owner-1',
    deviceId: 'owner-device',
    crypto: crypto,
    attachments: blobs.service,
  );
  final groupId = await controller.createGroup(
    title: 'Комната',
    memberProfileIds: const <String>[],
  );
  return _Room(db, crypto, controller, blobs, groupId);
}

Future<void> _until(bool Function() cond, {int tries = 600}) async {
  for (var i = 0; i < tries && !cond(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(cond(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('secretly-room-media-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (_) async {
          return tempDir.path;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('одиночный снимок в комнату', () {
    test('🔴 участник получает снимок без геометки, поворот цел', () async {
      final room = await _soloRoom();
      final source = _jpegWithGps();
      final file = File('${tempDir.path}/geo_single.jpg')
        ..writeAsBytesSync(source);

      final eventId = await room.controller.sendGroupAttachmentFile(
        groupId: room.groupId,
        filePath: file.path,
        mime: 'image/jpeg',
        topicId: 'topic-1',
      );

      final att = await room.localAttachment(eventId);
      expect(room.blobs.uploads, hasLength(1));
      final received = await room.blobs.openFor(att);
      final exif = img.decodeJpgExif(received);
      expect(exif?.imageIfd.sub.containsKey('gps') ?? false, isFalse);
      expect(exif?.imageIfd['Make'], isNull);
      expect(
        exif?.imageIfd['Orientation']?.toInt(),
        6,
        reason: 'без поворота портретный снимок ляжет набок',
      );
      // Пиксели те же — очистка не пережимает снимок.
      expect(
        img.decodeJpg(received)!.toUint8List(),
        img.decodeJpg(source)!.toUint8List(),
      );
      // Размер в сообщении — размер того, что реально ушло.
      expect(att.sizeBytes, received.length);
      expect(att.sizeBytes, lessThan(source.length));
      expect(att.topicId, 'topic-1');
    });

    test('🔴 размеры и размытый кадр — как у снимка в личный чат', () async {
      final room = await _soloRoom();
      final file = File('${tempDir.path}/geo_dims.jpg')
        ..writeAsBytesSync(_jpegWithGps(width: 40, height: 10));

      final eventId = await room.controller.sendGroupAttachmentFile(
        groupId: room.groupId,
        filePath: file.path,
        mime: 'image/jpeg',
      );

      final att = await room.localAttachment(eventId);
      expect(att.width, isNotNull);
      expect(att.height, isNotNull);
      expect(att.width! * att.height!, 40 * 10);
      expect(att.thumbB64, isNotNull);
      expect(img.decodeJpg(base64Decode(att.thumbB64!)), isNotNull);
    });

    test('документ уходит байт в байт, без размеров и кадра', () async {
      final room = await _soloRoom();
      final bytes = Uint8List.fromList(List<int>.generate(300, (i) => i % 251));
      final file = File('${tempDir.path}/report.pdf')..writeAsBytesSync(bytes);

      final eventId = await room.controller.sendGroupAttachmentFile(
        groupId: room.groupId,
        filePath: file.path,
        mime: 'application/pdf',
        filename: 'report.pdf',
      );

      final att = await room.localAttachment(eventId);
      expect(await room.blobs.openFor(att), bytes);
      expect(att.sizeBytes, bytes.length);
      expect(att.width, isNull);
      expect(att.height, isNull);
      expect(att.thumbB64, isNull);
      expect(att.filename, 'report.pdf');
    });

    test('нечитаемый «снимок» всё равно уходит — как есть', () async {
      final room = await _soloRoom();
      final junk = Uint8List.fromList(List<int>.generate(64, (i) => i * 3));
      final file = File('${tempDir.path}/broken.jpg')..writeAsBytesSync(junk);

      final eventId = await room.controller.sendGroupAttachmentFile(
        groupId: room.groupId,
        filePath: file.path,
        mime: 'image/jpeg',
      );

      final att = await room.localAttachment(eventId);
      expect(await room.blobs.openFor(att), junk);
      expect(att.sizeBytes, junk.length);
      expect(att.width, isNull);
      expect(att.thumbB64, isNull);
    });

    test('конверт участникам несёт то же, что и своё сообщение', () {
      final src = File('lib/app/app_controller.dart').readAsStringSync();
      final send = src.substring(
        src.indexOf('  Future<String> sendGroupAttachmentFile({'),
        src.indexOf(
          '  Future<Map<String, List<MessageReaction>>> loadMessageReactions({',
        ),
      );
      expect(send.contains("'sizeBytes': effectiveSize,"), isTrue);
      expect(
        send.contains(
          "if (bufferedImageDims != null) 'width': bufferedImageDims.width,",
        ),
        isTrue,
      );
      expect(
        send.contains(
          "if (bufferedImageDims != null) 'height': bufferedImageDims.height,",
        ),
        isTrue,
      );
      expect(
        send.contains("if (inlineThumbB64 != null) 'thumb_b64': inlineThumbB64,"),
        isTrue,
      );
      // Ключи — те, что приёмник комнаты уже читает (и в выпущенных сборках).
      expect(src.contains("(groupCmd['width'] as num?)?.toInt()"), isTrue);
      expect(src.contains("(groupCmd['height'] as num?)?.toInt()"), isTrue);
      expect(src.contains("(groupCmd['thumb_b64'] as String?)"), isTrue);
    });
  });

  group('альбом телефона в комнату', () {
    test('🔴 уходит в открытую тему, а не в «Общий»', () async {
      final room = await _soloRoom();
      final first = File('${tempDir.path}/album_0.jpg')
        ..writeAsBytesSync(_jpegWithGps());
      final second = File('${tempDir.path}/album_1.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 6, height: 4)));
      // Ровно так альбом собирает экран чата телефона.
      final album = PendingPhotoAlbumUpload(
        id: 'alb1',
        items: [
          PendingPhotoUpload(
            id: 'alb1_0',
            filePath: first.path,
            mime: 'image/jpeg',
            caption: 'Подпись',
            totalBytes: first.lengthSync(),
            mediaGroupId: 'alb1',
          ),
          PendingPhotoUpload(
            id: 'alb1_1',
            filePath: second.path,
            mime: 'image/png',
            caption: '',
            totalBytes: second.lengthSync(),
            mediaGroupId: 'alb1',
          ),
        ],
        convoId: room.groupId,
        targetId: room.groupId,
        isGroup: true,
        topicId: 'topic-7',
      );
      final errors = <AttachmentUploadErrorEvent>[];
      final sub = room.controller.attachmentUploadErrors.listen(errors.add);
      addTearDown(sub.cancel);

      room.controller.enqueuePhotoAlbumUpload(album);
      await _until(
        () => room.controller.pendingPhotoAlbumUploadsFor(room.groupId).isEmpty,
      );

      expect(errors, isEmpty, reason: '${errors.map((e) => e.error)}');
      expect(album.payloadEventIds, hasLength(2));
      final items = <AttachmentEventV1>[
        for (final id in album.payloadEventIds) await room.localAttachment(id),
      ];
      expect(items.map((a) => a.topicId), everyElement('topic-7'));
      expect(items.map((a) => a.mediaGroupId), everyElement('alb1'));
      expect(items.first.caption, 'Подпись');
      // Альбом и раньше чистил снимки — это не должно сломаться.
      final received = await room.blobs.openFor(items.first);
      expect(
        img.decodeJpgExif(received)?.imageIfd.sub.containsKey('gps') ?? false,
        isFalse,
      );
    });

    test('без темы альбом по-прежнему уходит в «Общий»', () async {
      final room = await _soloRoom();
      final a = File('${tempDir.path}/general_0.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 2, height: 2)));
      final b = File('${tempDir.path}/general_1.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 3, height: 3)));
      final album = PendingPhotoAlbumUpload(
        id: 'alb2',
        items: [
          for (final (i, f) in [a, b].indexed)
            PendingPhotoUpload(
              id: 'alb2_$i',
              filePath: f.path,
              mime: 'image/png',
              caption: '',
              totalBytes: f.lengthSync(),
              mediaGroupId: 'alb2',
            ),
        ],
        convoId: room.groupId,
        targetId: room.groupId,
        isGroup: true,
      );
      room.controller.enqueuePhotoAlbumUpload(album);
      await _until(
        () => room.controller.pendingPhotoAlbumUploadsFor(room.groupId).isEmpty,
      );
      expect(album.payloadEventIds, hasLength(2));
      for (final id in album.payloadEventIds) {
        expect((await room.localAttachment(id)).topicId, isNull);
      }
    });
  });
}
