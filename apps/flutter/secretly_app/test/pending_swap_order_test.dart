// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// М1–М4 (разбор медиа 22.11.2026): заготовка отправки и настоящий пузырь.
//
// Было: строка сообщения писалась в историю раньше, чем заготовка узнавала
// её номер (номер приходил только после всей рассылки) — лента на это время
// показывала ДВА пузыря, потом заготовка пропадала, а настоящий пузырь
// прыгал и заново играл появление. Теперь номер, blobId и копия в кэше
// приходят обратным вызовом ПРЯМО ПЕРЕД записью; лента прячет строку под
// заготовкой с первого кадра, и подмена — одна перерисовка.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/app/pending_attachment_upload.dart';
import 'package:secretly_app/crypto/dart_crypto_provider.dart';
import 'package:secretly_app/media/image_header_dims.dart';
import 'package:secretly_app/models/e2e_payload_v1.dart';
import 'package:secretly_app/storage/app_db.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

class _Owner {
  _Owner(this.db, this.crypto, this.controller);

  final AppDb db;
  final DartCryptoProvider crypto;
  final AppController controller;

  static Future<_Owner> open() async {
    final db = await AppDb.openForTesting();
    addTearDown(db.close);
    final crypto = DartCryptoProvider(
      Uint8List.fromList(List<int>.generate(32, (i) => i)),
    );
    final controller = AppController();
    controller.seedRoomRuntimeForTesting(
      db: db,
      profileId: 'owner-1',
      deviceId: 'owner-device',
      crypto: crypto,
    );
    return _Owner(db, crypto, controller);
  }

  /// (payloadEventId, вложение) всех строк переписки — как в базе.
  Future<List<(String, AttachmentEventV1)>> rows(String convoId) async {
    final out = <(String, AttachmentEventV1)>[];
    for (final row in await db.listEventsChronological(convoId, limit: 50)) {
      final local = ((row['local_ciphertext_b64'] as String?) ?? '').trim();
      final stored = local.isNotEmpty
          ? local
          : ((row['ciphertext_b64'] as String?) ?? '').trim();
      if (stored.isEmpty) continue;
      final payload = E2ePayloadV1.decode(
        await crypto.decrypt(base64Decode(stored)),
      );
      for (final e in payload.events) {
        if (e is AttachmentEventV1) {
          out.add(((row['payload_event_id'] as String?) ?? '', e));
        }
      }
    }
    return out;
  }
}

Future<Uint8List> _png(int w, int h) async {
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF3366CC),
  );
  final img = await rec.endRecording().toImage(w, h);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('secretly-swap-');
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

  test('М3: размеры снимка — по заголовку файла', () async {
    final f = File('${tempDir.path}/header.png');
    await f.writeAsBytes(await _png(37, 91));
    final dims = await readImageHeaderDims(f.path);
    expect(dims, isNotNull);
    expect(dims!.width, 37);
    expect(dims.height, 91);
    expect(await readImageHeaderDims('${tempDir.path}/nope.png'), isNull);
    final txt = File('${tempDir.path}/not_image.txt')..writeAsStringSync('hi');
    expect(await readImageHeaderDims(txt.path), isNull);
  });

  test('М1: номер приходит ДО записи строки — документ', () async {
    final owner = await _Owner.open();
    final f = File('${tempDir.path}/doc.pdf')
      ..writeAsBytesSync(List<int>.generate(3000, (i) => i % 256));
    String? cbId;
    String? cbBlob;
    String? cbCache;
    Future<List<(String, AttachmentEventV1)>>? rowsAtCallback;
    final id = await owner.controller.sendAttachmentFile(
      peerProfileId: 'owner-1',
      filePath: f.path,
      mime: 'application/pdf',
      filename: 'doc.pdf',
      onLocalRowInserting: (eventId, blobId, cachePath) {
        cbId = eventId;
        cbBlob = blobId;
        cbCache = cachePath;
        // Запрос встаёт в очередь базы раньше записи строки.
        rowsAtCallback = owner.rows('owner-1');
      },
    );
    expect(cbId, id);
    expect(await rowsAtCallback!, isEmpty, reason: 'строки ещё нет');
    final rows = await owner.rows('owner-1');
    expect(rows.single.$1, id);
    expect(rows.single.$2.blobId, cbBlob);
    expect(cbCache, isNotNull);
    expect(File(cbCache!).existsSync(), isTrue);
  });

  test('М1: номер приходит ДО записи строки — снимок (короткий путь)', () async {
    final owner = await _Owner.open();
    final f = File('${tempDir.path}/photo.png')
      ..writeAsBytesSync(await _png(40, 30));
    String? cbId;
    Future<List<(String, AttachmentEventV1)>>? rowsAtCallback;
    final id = await owner.controller.sendAttachmentFile(
      peerProfileId: 'owner-1',
      filePath: f.path,
      mime: 'image/png',
      onLocalRowInserting: (eventId, _, _) {
        cbId = eventId;
        rowsAtCallback = owner.rows('owner-1');
      },
    );
    expect(cbId, id);
    expect(await rowsAtCallback!, isEmpty);
    expect((await owner.rows('owner-1')).single.$1, id);
  });

  test(
    'М1–М4: заготовка снимка знает номер, blobId, копию и размеры, '
    'пока строка видна — двух пузырей не бывает',
    () async {
      final owner = await _Owner.open();
      final f = File('${tempDir.path}/queued.png')
        ..writeAsBytesSync(await _png(60, 120));
      final pending = PendingPhotoUpload(
        id: 'p1',
        filePath: f.path,
        mime: 'image/png',
        caption: '',
        totalBytes: f.lengthSync(),
        convoId: 'owner-1',
        targetId: 'owner-1',
      );
      owner.controller.enqueuePhotoUpload(pending);
      var violations = 0;
      var sawRowWhilePending = false;
      // Лента строит строки из базы: как только строка видна, а заготовка
      // ещё на экране, у заготовки уже должен быть её номер — иначе строку
      // не спрятать и пузырей два.
      for (var i = 0; i < 1000; i++) {
        final stillPending = owner.controller
            .pendingPhotoUploadsFor('owner-1')
            .contains(pending);
        if (!stillPending) break;
        final rows = await owner.rows('owner-1');
        if (rows.isNotEmpty &&
            owner.controller.pendingPhotoUploadsFor('owner-1').contains(
              pending,
            )) {
          sawRowWhilePending = true;
          if (pending.payloadEventId != rows.single.$1) violations++;
        }
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(owner.controller.pendingPhotoUploadsFor('owner-1'), isEmpty);
      expect(violations, 0);
      final row = (await owner.rows('owner-1')).single;
      expect(pending.payloadEventId, row.$1);
      expect(pending.sentBlobId, row.$2.blobId);
      expect(pending.sentCachePath, isNotNull);
      expect(File(pending.sentCachePath!).existsSync(), isTrue);
      // М3: размеры по заголовку — те же, что ушли в сообщение.
      expect(pending.width, 60);
      expect(pending.height, 120);
      expect(row.$2.width, 60);
      expect(row.$2.height, 120);
      // Окно «строка уже есть, заготовка ещё на экране» короткое у отправки
      // себе; когда опрос в него попал — номер обязан уже быть (выше).
      debugPrint('строка видна при заготовке: $sawRowWhilePending');
    },
  );

  test('М1: альбом — номер каждого снимка до его записи', () async {
    final owner = await _Owner.open();
    final items = <PendingPhotoUpload>[
      for (var i = 0; i < 3; i++)
        PendingPhotoUpload(
          id: 'a$i',
          filePath: (File('${tempDir.path}/album_$i.png')
                ..writeAsBytesSync(await _png(20 + i, 20)))
              .path,
          mime: 'image/png',
          caption: i == 0 ? 'подпись' : '',
          totalBytes: 100,
          mediaGroupId: 'g1',
        ),
    ];
    final album = PendingPhotoAlbumUpload(
      id: 'album1',
      items: items,
      convoId: 'owner-1',
      targetId: 'owner-1',
    );
    owner.controller.enqueuePhotoAlbumUpload(album);
    var violations = 0;
    for (var i = 0; i < 1000; i++) {
      if (!owner.controller
          .pendingPhotoAlbumUploadsFor('owner-1')
          .contains(album)) {
        break;
      }
      final rows = await owner.rows('owner-1');
      if (owner.controller.pendingPhotoAlbumUploadsFor('owner-1').contains(
        album,
      )) {
        for (final r in rows) {
          if (!album.payloadEventIds.contains(r.$1)) violations++;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(violations, 0);
    final rows = await owner.rows('owner-1');
    expect(rows, hasLength(3));
    for (var i = 0; i < 3; i++) {
      final row = rows.firstWhere((r) => r.$1 == items[i].payloadEventId);
      expect(items[i].sentBlobId, row.$2.blobId);
    }
  });
}
