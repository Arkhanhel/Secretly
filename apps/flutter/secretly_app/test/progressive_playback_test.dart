// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// В-2 (разбор медиа 22.11.2026): ролик играет до конца скачивания.
// Локальный HTTP отдаёт растущий файл открытого текста: длина, Range, ожидание
// расшифровки, закрытие; порядок коробок MP4; длина открытого текста по
// шифротексту; запасной путь, если `moov` в конце.
// М3: размеры ролика по `tkhd`. С-13: уборка расшифрованных копий.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/attachments/attachment_service.dart';
import 'package:secretly_app/attachments/streaming_attachment_decrypt.dart';
import 'package:secretly_app/media/decrypted_temp_cleanup.dart';
import 'package:secretly_app/media/progressive_playback.dart';
import 'package:secretly_app/media/video_header_dims.dart';
import 'package:secretly_app/transport/blob_client.dart';

Uint8List _u32(int v) =>
    (ByteData(4)..setUint32(0, v, Endian.big)).buffer.asUint8List();

Uint8List _box(String type, List<int> body) {
  final b = BytesBuilder()
    ..add(_u32(8 + body.length))
    ..add(ascii.encode(type))
    ..add(body);
  return b.toBytes();
}

/// tkhd v0: version/flags, 5×u32, 16 байт, матрица 9×i32, ширина, высота.
Uint8List _tkhd(int w, int h, {bool rotate90 = false}) {
  final b = BytesBuilder()..add(Uint8List(4)); // version 0 + flags
  b.add(Uint8List(20)); // creation, modification, track id, reserved, duration
  b.add(Uint8List(16)); // reserved, layer, alt group, volume, reserved
  final m = rotate90
      ? <int>[0, 0x10000, 0, -0x10000, 0, 0, 0, 0, 0x40000000]
      : <int>[0x10000, 0, 0, 0, 0x10000, 0, 0, 0, 0x40000000];
  for (final v in m) {
    b.add((ByteData(4)..setInt32(0, v, Endian.big)).buffer.asUint8List());
  }
  b.add(_u32(w << 16));
  b.add(_u32(h << 16));
  return _box('tkhd', b.toBytes());
}

Uint8List _hdlr(String kind) =>
    _box('hdlr', [...Uint8List(8), ...ascii.encode(kind), ...Uint8List(12)]);

Uint8List _trak(int w, int h, String kind, {bool rotate90 = false}) => _box(
  'trak',
  [..._tkhd(w, h, rotate90: rotate90), ..._box('mdia', _hdlr(kind))],
);

final Uint8List _ftyp = _box('ftyp', ascii.encode('isom\u0000\u0000\u0002\u0000isomiso2mp41'));

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('secretly_progressive_');
    ProgressiveMediaFeeds.clear();
  });

  tearDown(() async {
    ProgressiveMediaFeeds.clear();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  group('порядок коробок', () {
    test('moov раньше mdat — faststart', () {
      final head = Uint8List.fromList([
        ..._ftyp,
        ..._box('free', Uint8List(8)),
        ..._box('moov', Uint8List(100)),
        ..._box('mdat', Uint8List(10)),
      ]);
      expect(detectMp4Layout(head), Mp4Layout.faststart);
      // Решается уже по заголовку moov, тело не нужно.
      expect(
        detectMp4Layout(Uint8List.sublistView(head, 0, _ftyp.length + 16 + 8)),
        Mp4Layout.faststart,
      );
    });

    test('mdat раньше moov (QuickTime с wide) — не faststart', () {
      final head = Uint8List.fromList([
        ..._ftyp,
        ..._box('wide', const []),
        ..._box('mdat', Uint8List(64)),
      ]);
      expect(detectMp4Layout(head), Mp4Layout.notFaststart);
    });

    test('mdat с 64-битной длиной и mdat «до конца файла»', () {
      final big = BytesBuilder()
        ..add(_ftyp)
        ..add(_u32(1))
        ..add(ascii.encode('mdat'))
        ..add((ByteData(8)..setUint64(0, 1 << 33, Endian.big)).buffer.asUint8List());
      expect(detectMp4Layout(big.toBytes()), Mp4Layout.notFaststart);
      final toEnd = Uint8List.fromList([..._ftyp, ..._u32(0), ...ascii.encode('mdat')]);
      expect(detectMp4Layout(toEnd), Mp4Layout.notFaststart);
    });

    test('мало байт — ждать; не MP4 — нельзя', () {
      expect(detectMp4Layout(Uint8List.sublistView(_ftyp, 0, 6)), Mp4Layout.unknown);
      expect(detectMp4Layout(_ftyp), Mp4Layout.unknown);
      expect(
        detectMp4Layout(Uint8List.fromList([0x1a, 0x45, 0xdf, 0xa3, 0x9f, 0x42, 0x86, 0x81, 1, 2])),
        Mp4Layout.notMp4,
      );
      expect(detectMp4Layout(Uint8List.fromList([0, 0, 0, 4, ...ascii.encode('ftyp')])), Mp4Layout.notMp4);
    });
  });

  test('длина открытого текста по шифротексту = настоящая (с кусками впритык)', () async {
    final svc = AttachmentService(
      blobClient: BlobClient(baseUrl: Uri.parse('http://127.0.0.1:1')),
    );
    for (final size in [1, 1000, 64 * 1024, 64 * 1024 * 3, 64 * 1024 * 3 + 5, 1 << 20]) {
      final inFile = File('${dir.path}/in_$size.bin');
      await inFile.writeAsBytes(Uint8List(size), flush: true);
      final bundle = await svc.encryptFileForUpload(
        inFile,
        tempDir: dir,
        chunkSize: 64 * 1024,
        mime: 'video/mp4',
      );
      final ct = await bundle.ciphertextFile.length();
      expect(attachmentV1PlainLength(ct, 64 * 1024), size, reason: 'size $size');
    }
  });

  test('изолят В-1 сообщает «расшифровано N байт» и размер куска', () async {
    final svc = AttachmentService(
      blobClient: BlobClient(baseUrl: Uri.parse('http://127.0.0.1:1')),
    );
    final size = 700 * 1024 + 3;
    final inFile = File('${dir.path}/in.bin');
    await inFile.writeAsBytes(
      Uint8List.fromList(List<int>.generate(size, (i) => i % 251)),
      flush: true,
    );
    final bundle = await svc.encryptFileForUpload(
      inFile,
      tempDir: dir,
      chunkSize: 64 * 1024,
      mime: 'video/mp4',
    );
    final cipher = await bundle.ciphertextFile.readAsBytes();
    final part = File('${dir.path}/part.bin');
    await part.writeAsBytes(cipher, flush: true);
    final reports = <(int, int)>[];
    final s = StreamingAttachmentDecrypt.start(
      partPath: part.path,
      outPath: '${dir.path}/out.bin',
      fileKeyB64: bundle.fileKeyB64,
      onDecrypted: (n, c) => reports.add((n, c)),
    )!;
    s.notifyAvailable(cipher.length);
    final r = await s.finish(cipher.length);
    expect(r.ok, isTrue);
    expect(reports, isNotEmpty);
    expect(reports.last.$1, size);
    expect(reports.every((e) => e.$2 == 64 * 1024), isTrue);
    for (var i = 1; i < reports.length; i++) {
      expect(reports[i].$1, greaterThan(reports[i - 1].$1));
    }
  });

  group('локальный HTTP с растущим файлом', () {
    late File file;
    late ProgressiveMediaFeed feed;
    late LoopbackMediaServer server;
    late HttpClient client;
    final total = 300 * 1024;
    final content = Uint8List.fromList(
      List<int>.generate(total, (i) => (i * 7 + 3) % 256),
    );

    Future<void> grow(int upto) async {
      final raf = await file.open(mode: FileMode.append);
      final have = await file.length();
      if (upto > have) await raf.writeFrom(content, have, upto);
      await raf.close();
      feed.reportDecrypted(upto, 64 * 1024);
    }

    setUp(() async {
      file = File('${dir.path}/plain.tmp');
      await file.writeAsBytes(const <int>[]);
      feed = ProgressiveMediaFeed(
        blobId: 'b1',
        mime: 'video/mp4',
        path: file.path,
        declaredBytes: total,
        totalBytes: total,
      );
      server = await LoopbackMediaServer.start(feed);
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.close();
    });

    Future<HttpClientResponse> get(String? range, {Uri? url, String method = 'GET'}) async {
      final req = await client.openUrl(method, url ?? server.url);
      if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
      return req.close();
    }

    Future<Uint8List> body(HttpClientResponse r) async {
      final b = BytesBuilder();
      await for (final c in r) {
        b.add(c);
      }
      return b.toBytes();
    }

    test('только 127.0.0.1, случайный порт и метка в пути', () async {
      expect(server.url.host, '127.0.0.1');
      expect(server.url.port, greaterThan(0));
      expect(server.url.pathSegments.first.length, 32);
      final wrong = server.url.replace(path: '/nope/media.mp4');
      final r = await get(null, url: wrong);
      expect(r.statusCode, 404);
      await r.drain<void>();
    });

    test('HEAD и полный GET — длина целиком, Accept-Ranges', () async {
      await grow(total);
      final h = await get(null, method: 'HEAD');
      expect(h.statusCode, 200);
      expect(h.contentLength, total);
      expect(h.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
      expect(h.headers.contentType?.mimeType, 'video/mp4');
      await h.drain<void>();
      final g = await get(null);
      expect(g.statusCode, 200);
      expect(g.contentLength, total);
      expect(await body(g), content);
    });

    test('Range ждёт, пока расшифровка дойдёт до нужного байта', () async {
      await grow(1000);
      final r = await get('bytes=200000-200999');
      expect(r.statusCode, 206);
      expect(r.headers.value(HttpHeaders.contentRangeHeader), 'bytes 200000-200999/$total');
      expect(r.contentLength, 1000);
      final got = body(r);
      var done = false;
      unawaited(got.then((_) => done = true));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(done, isFalse, reason: 'байтов ещё нет — ответ ждёт');
      expect(server.waiting.value, isTrue);
      await grow(150000);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(done, isFalse);
      await grow(total);
      expect(await got, Uint8List.sublistView(content, 200000, 201000));
      expect(server.waiting.value, isFalse);
    });

    test('открытый конец, хвост «-N», за пределами — 416', () async {
      await grow(total);
      final a = await get('bytes=${total - 10}-');
      expect(a.statusCode, 206);
      expect(await body(a), Uint8List.sublistView(content, total - 10));
      final b = await get('bytes=-16');
      expect(b.headers.value(HttpHeaders.contentRangeHeader), 'bytes ${total - 16}-${total - 1}/$total');
      expect(await body(b), Uint8List.sublistView(content, total - 16));
      final c = await get('bytes=0-1');
      expect(c.contentLength, 2);
      expect(await body(c), Uint8List.sublistView(content, 0, 2));
      final d = await get('bytes=$total-');
      expect(d.statusCode, 416);
      expect(d.headers.value(HttpHeaders.contentRangeHeader), 'bytes */$total');
      await d.drain<void>();
    });

    test('после переименования в кэш читает новый путь', () async {
      await grow(total);
      final moved = File('${dir.path}/cache.mp4');
      await file.rename(moved.path);
      feed.complete(moved.path, length: total);
      final r = await get('bytes=100-199');
      expect(await body(r), Uint8List.sublistView(content, 100, 200));
    });

    test('сбой скачивания обрывает ждущий ответ', () async {
      await grow(1000);
      final r = await get('bytes=5000-5999');
      final got = body(r).then((b) => b.length, onError: (Object _) => -1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      feed.fail();
      final n = await got.timeout(const Duration(seconds: 5));
      expect(n, lessThan(1000));
    });

    test('закрытие сервера: ждущие соединения рвутся, новые не принимаются', () async {
      await grow(1000);
      final r = await get('bytes=9000-9999');
      final got = body(r).then((b) => b.length, onError: (Object _) => -1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final url = server.url;
      await server.close();
      expect(server.isClosed, isTrue);
      final n = await got.timeout(const Duration(seconds: 5));
      expect(n, lessThan(1000));
      final fresh = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      addTearDown(() => fresh.close(force: true));
      await expectLater(
        () async => (await fresh.getUrl(url)).close(),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('решение «играть по ходу»', () {
    Future<ProgressiveMediaFeed> feedWith(Uint8List head, {int total = 4096}) async {
      final f = File('${dir.path}/h_${head.length}_${head.hashCode}.tmp');
      await f.writeAsBytes(head, flush: true);
      final feed = ProgressiveMediaFeed(
        blobId: 'blob_${head.hashCode}',
        mime: 'video/mp4',
        path: f.path,
        declaredBytes: total,
        totalBytes: total,
      );
      ProgressiveMediaFeeds.register(feed);
      feed.reportDecrypted(head.length, 64 * 1024);
      return feed;
    }

    test('moov в конце — null: ждём полный файл, как раньше', () async {
      final feed = await feedWith(Uint8List.fromList([
        ..._ftyp,
        ..._box('mdat', Uint8List(200)),
      ]));
      final s = await openProgressivePlaybackForTest(
        feed.blobId,
        until: Completer<void>().future,
      );
      expect(s, isNull);
    });

    test('faststart — локальный адрес', () async {
      final feed = await feedWith(Uint8List.fromList([
        ..._ftyp,
        ..._box('moov', Uint8List(200)),
      ]));
      final s = await openProgressivePlaybackForTest(
        feed.blobId,
        until: Completer<void>().future,
      );
      expect(s, isNotNull);
      expect(s!.url.host, '127.0.0.1');
      await s.close();
    });

    test('файла нет и скачивание кончилось — null', () async {
      final s = await openProgressivePlaybackForTest(
        'missing',
        until: Future<void>.value(),
      );
      expect(s, isNull);
    });

    test('сбой до решения — null', () async {
      final feed = await feedWith(Uint8List.sublistView(_ftyp, 0, 12));
      final pending = openProgressivePlaybackForTest(
        feed.blobId,
        until: Completer<void>().future,
      );
      feed.fail();
      expect(await pending, isNull);
    });

    test('реестр: не ролик и не телефон — не регистрируется', () {
      expect(progressivePlaybackMime('video/webm'), isFalse);
      expect(progressivePlaybackMime('video/quicktime'), isTrue);
      // В тестах (macOS/Linux) платформа не телефон — В-2 не включается.
      expect(
        ProgressiveMediaFeeds.begin(
          blobId: 'x',
          mime: 'video/mp4',
          path: '${dir.path}/x',
          declaredBytes: 1,
        ),
        isNull,
      );
    });
  });

  test('parseByteRange', () {
    expect(parseByteRange(null, 100), (start: 0, end: 99, partial: false));
    expect(parseByteRange('bytes=10-', 100), (start: 10, end: 99, partial: true));
    expect(parseByteRange('bytes=10-500', 100), (start: 10, end: 99, partial: true));
    expect(parseByteRange('bytes=-200', 100), (start: 0, end: 99, partial: true));
    expect(parseByteRange('bytes=100-', 100), isNull);
    expect(parseByteRange('bytes=50-40', 100), isNull);
  });

  group('М3: размеры ролика по tkhd', () {
    Future<({int width, int height})?> dims(Uint8List bytes) async {
      final f = File('${dir.path}/v_${bytes.hashCode}.mp4');
      await f.writeAsBytes(bytes, flush: true);
      return readVideoHeaderDims(f.path);
    }

    test('moov в начале, дорожка звука первой', () async {
      final d = await dims(Uint8List.fromList([
        ..._ftyp,
        ..._box('moov', [..._trak(0, 0, 'soun'), ..._trak(1920, 1080, 'vide')]),
        ..._box('mdat', Uint8List(32)),
      ]));
      expect(d, (width: 1920, height: 1080));
    });

    test('moov в конце, поворот 90° — ширина и высота местами', () async {
      final d = await dims(Uint8List.fromList([
        ..._ftyp,
        ..._box('mdat', Uint8List(5000)),
        ..._box('moov', _trak(1920, 1080, 'vide', rotate90: true)),
      ]));
      expect(d, (width: 1080, height: 1920));
    });

    test('не MP4 — null', () async {
      expect(await dims(Uint8List.fromList(List<int>.filled(100, 7))), isNull);
      expect(await readVideoHeaderDims('${dir.path}/none.mp4'), isNull);
    });
  });

  group('С-13: уборка расшифрованных копий', () {
    test('старые копии буфера и выгрузки — удаляются, свежие и чужие — нет', () async {
      final now = DateTime.now();
      final old = now.subtract(const Duration(hours: 2));
      Future<File> make(String rel, DateTime at) async {
        final f = File('${dir.path}/$rel');
        await f.parent.create(recursive: true);
        await f.writeAsBytes([1, 2, 3]);
        await f.setLastModified(at);
        return f;
      }

      final oldPaste = await make('0f8fad5b-d9cb-469f-a165-70867728950e.png', old);
      final freshPaste = await make('7c9e6679-7425-40de-944b-e07fc1f90ae7.png', now);
      final oldEdited = await make('secretly_edited/photo_edited_1.jpg', old);
      final freshEdited = await make('secretly_edited/photo_edited_2.jpg', now);
      final userLike = await make('IMG_0001.png', old);
      final otherUuid = await make('image_picker_0f8fad5b-d9cb-469f-a165-70867728950e.png', old);

      final n = await sweepDecryptedTempCopies(tempDir: dir, now: now);
      expect(n, 2);
      expect(await oldPaste.exists(), isFalse);
      expect(await oldEdited.exists(), isFalse);
      expect(await freshPaste.exists(), isTrue);
      expect(await freshEdited.exists(), isTrue);
      expect(await userLike.exists(), isTrue);
      expect(await otherUuid.exists(), isTrue);

      // Перед новой записью в буфер — все прежние копии буфера.
      expect(await sweepPasteboardCopies(tempDir: dir), 1);
      expect(await freshPaste.exists(), isFalse);
      expect(await userLike.exists(), isTrue);
    });
  });
}
