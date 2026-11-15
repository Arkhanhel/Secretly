// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// О3 (разбор медиа 15.11.2026): полоса загрузки большого файла идёт за
// сетью, а не за диском; ✕ останавливает передачу посреди файла.
//
// Настоящий HTTP-сервер на loopback, который читает тело медленно.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:secretly_app/attachments/attachment_failure.dart';
import 'package:secretly_app/transport/blob_client.dart';

void main() {
  late HttpServer server;
  late Directory tmp;
  late File body;
  var serverGot = 0;
  const total = 24 * 1024 * 1024;

  setUp(() async {
    serverGot = 0;
    tmp = Directory.systemTemp.createTempSync('bp_');
    body = File(p.join(tmp.path, 'cipher.bin'));
    final sink = body.openWrite();
    final chunk = List<int>.filled(1 << 20, 7);
    for (var i = 0; i < total >> 20; i++) {
      sink.add(chunk);
    }
    await sink.close();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      try {
        await for (final c in req) {
          serverGot += c.length;
          await Future<void>.delayed(const Duration(milliseconds: 15));
        }
        req.response
          ..headers.contentType = ContentType.json
          ..write('{"blob_id":"b1","size_bytes":$total,"expires_at_ms":1}');
        await req.response.close();
      } catch (_) {}
    });
  });

  tearDown(() async {
    await server.close(force: true);
    tmp.deleteSync(recursive: true);
  });

  BlobClient client() => BlobClient(
    baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
    httpClient: http.Client(),
  );

  test('🔴 «100 %» только когда сервер уже принял почти весь файл', () async {
    int? serverAtFull;
    final result = await client().uploadCiphertextFile(
      body,
      ttlSeconds: 60,
      bodySha256B64: 'x',
      accessTokenB64: 'AAAA',
      onProgress: (sent, len) {
        if (sent == len) serverAtFull ??= serverGot;
      },
    );
    expect(result.blobId, 'b1');
    expect(serverAtFull, isNotNull);
    // Замер 15.11: прежняя подача доходила до 100 % при 0,2 МБ из 24 МБ на
    // сервере, новая — при 20 МБ. Допуск — буферы ядра на loopback.
    expect(serverAtFull!, greaterThan(total ~/ 2),
        reason: 'server had $serverAtFull of $total at 100 %');
  });

  test('🔴 ✕ посреди файла — отказ «отменено», файл дальше не читается',
      () async {
    final token = BlobUploadCancelToken();
    var maxSent = 0;
    await expectLater(
      client().uploadCiphertextFile(
        body,
        ttlSeconds: 60,
        bodySha256B64: 'x',
        accessTokenB64: 'AAAA',
        cancelToken: token,
        onProgress: (sent, len) {
          maxSent = sent;
          if (sent >= 4 * 1024 * 1024) token.cancel();
        },
      ),
      throwsA(
        isA<AttachmentFailure>().having(
          (e) => e.code,
          'code',
          AttachmentFailureCode.uploadCanceled,
        ),
      ),
    );
    expect(maxSent, lessThan(total ~/ 2), reason: 'stopped at $maxSent');
  });

  test('П5: скачивание сообщает ход по длине из ответа', () async {
    final dl = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => dl.close(force: true));
    const n = 3 * 1024 * 1024;
    dl.listen((req) async {
      req.response.contentLength = n;
      for (var i = 0; i < 3; i++) {
        req.response.add(List<int>.filled(1 << 20, 1));
        await req.response.flush();
      }
      await req.response.close();
    });
    final seen = <int>[];
    int? total;
    final out = File(p.join(tmp.path, 'dl.bin'));
    await BlobClient(
      baseUrl: Uri.parse('http://127.0.0.1:${dl.port}'),
      httpClient: http.Client(),
    ).downloadCiphertextToFile(
      'b1',
      outputFile: out,
      onProgress: (r, t) {
        seen.add(r);
        total = t;
      },
    );
    expect(out.lengthSync(), n);
    expect(total, n);
    expect(seen.last, n);
    expect(seen.length, greaterThan(1), reason: 'ход, а не один скачок');
  });

  test('🔴 сервер недоступен — быстрый отказ, а не вечное ожидание', () async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = probe.port;
    await probe.close();
    final started = DateTime.now();
    await expectLater(
      BlobClient(
        baseUrl: Uri.parse('http://127.0.0.1:$deadPort'),
        httpClient: http.Client(),
      ).uploadCiphertextFile(
        body,
        ttlSeconds: 60,
        bodySha256B64: 'x',
        accessTokenB64: 'AAAA',
      ),
      throwsA(anything),
    );
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(seconds: 10)),
    );
  });

  test('🔴 О6/П5: обрыв посреди скачивания — следующая попытка докачивает '
      'с места обрыва (Range), файл совпадает байт в байт', () async {
    final full = List<int>.generate(3 << 20, (i) => i % 251);
    var attempt = 0;
    String? rangeSeen;
    // Сырой сокет: настоящий обрыв посреди тела после честных заголовков.
    final srv = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(srv.close);
    srv.listen((sock) async {
      final head = StringBuffer();
      await for (final data in sock) {
        head.write(String.fromCharCodes(data));
        if (head.toString().contains('\r\n\r\n')) break;
      }
      attempt++;
      final range = RegExp(r'range: *bytes=(\d+)-', caseSensitive: false)
          .firstMatch(head.toString());
      if (attempt == 1) {
        sock.add('HTTP/1.1 200 OK\r\ncontent-length: ${full.length}\r\n\r\n'
            .codeUnits);
        sock.add(full.sublist(0, 1 << 20));
        await sock.flush();
        sock.destroy();
        return;
      }
      final start = int.parse(range!.group(1)!);
      rangeSeen = 'bytes=$start-';
      sock.add(('HTTP/1.1 206 Partial Content\r\n'
              'content-range: bytes $start-${full.length - 1}/${full.length}\r\n'
              'content-length: ${full.length - start}\r\n'
              'connection: close\r\n\r\n')
          .codeUnits);
      sock.add(full.sublist(start));
      await sock.flush();
      await sock.close();
    });
    final out = File(p.join(tmp.path, 'part.bin'));
    final client = BlobClient(
      baseUrl: Uri.parse('http://127.0.0.1:${srv.port}'),
      httpClient: http.Client(),
    );
    await expectLater(
      client.downloadCiphertextToFile('b1', outputFile: out, resume: true),
      throwsA(anything),
    );
    expect(out.existsSync(), isTrue, reason: 'кусок остаётся');
    final kept = out.lengthSync();
    expect(kept, greaterThan(0));
    expect(kept, lessThan(full.length));
    int? lastTotal;
    await client.downloadCiphertextToFile(
      'b1',
      outputFile: out,
      resume: true,
      onProgress: (r, t) => lastTotal = t,
    );
    expect(rangeSeen, 'bytes=$kept-');
    expect(lastTotal, full.length);
    expect(out.readAsBytesSync(), full);
  });

  test('сервер без докачки (200 на Range) — файл пишется заново', () async {
    final full = List<int>.generate(4096, (i) => i % 7);
    final srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => srv.close(force: true));
    srv.listen((req) async {
      req.response
        ..contentLength = full.length
        ..add(full);
      await req.response.close();
    });
    final out = File(p.join(tmp.path, 'stale.bin'))
      ..writeAsBytesSync(List<int>.filled(1000, 9));
    await BlobClient(
      baseUrl: Uri.parse('http://127.0.0.1:${srv.port}'),
      httpClient: http.Client(),
    ).downloadCiphertextToFile('b1', outputFile: out, resume: true);
    expect(out.readAsBytesSync(), full);
  });
}
