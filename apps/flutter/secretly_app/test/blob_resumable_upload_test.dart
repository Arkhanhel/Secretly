// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Отправка частями с докачкой (разбор медиа 15.11.2026): клиент против
// настоящего HTTP-сервера на loopback, который ведёт себя как реле — помнит
// смещение, отвечает 409 на не то место и рвёт соединение посреди куска.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:secretly_app/attachments/attachment_failure.dart';
import 'package:secretly_app/transport/blob_client.dart';

class _FakeRelay {
  _FakeRelay._(this.server);
  final HttpServer server;
  final Map<String, BytesBuilder> parts = {};
  final Map<String, int> lengths = {};
  final Map<String, String> shas = {};
  int puts = 0;
  int statusCalls = 0;
  bool sessionsSupported = true;
  // Сколько раз ещё оборвать соединение посреди куска.
  int dropNextPuts = 0;
  Uint8List? finished;

  static Future<_FakeRelay> start() async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final r = _FakeRelay._(s);
    s.listen(r._handle);
    return r;
  }

  Uri get base => Uri.parse('http://127.0.0.1:${server.port}');

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    if (!sessionsSupported && path.startsWith('/v1/blob/upload/session')) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }
    if (req.method == 'POST' && path == '/v1/blob/upload/session') {
      final id = 's${parts.length + 1}';
      parts[id] = BytesBuilder();
      lengths[id] = int.parse(req.headers.value('x-secretly-upload-length')!);
      shas[id] = req.headers.value('x-secretly-body-sha256-b64')!;
      await req.drain<void>();
      req.response.write(jsonEncode({
        'session_id': id,
        'offset': 0,
        'max_chunk_bytes': 8 << 20,
      }));
      await req.response.close();
      return;
    }
    final id = path.split('/').last;
    final part = parts[id];
    if (part == null) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }
    if (req.method == 'GET') {
      statusCalls++;
      req.response.write(jsonEncode({'offset': part.length, 'upload_length': lengths[id]}));
      await req.response.close();
      return;
    }
    puts++;
    final offset = int.parse(req.headers.value('x-secretly-upload-offset')!);
    if (offset != part.length) {
      await req.drain<void>();
      req.response.statusCode = 409;
      req.response.write(jsonEncode({'offset': part.length}));
      await req.response.close();
      return;
    }
    if (dropNextPuts > 0) {
      dropNextPuts--;
      // Рвём соединение посреди отправки куска — как обрыв связи. Реле
      // кусок целиком проверяет до записи, так что недошедшее не хранится.
      final sock = await req.response.detachSocket(writeHeaders: false);
      sock.destroy();
      return;
    }
    final chunk = BytesBuilder();
    await for (final c in req) {
      chunk.add(c);
    }
    final bytes = chunk.takeBytes();
    final sha = base64Encode(sha256.convert(bytes).bytes);
    if (sha != req.headers.value('x-secretly-chunk-sha256-b64')) {
      req.response.statusCode = 422;
      await req.response.close();
      return;
    }
    part.add(bytes);
    final done = part.length >= lengths[id]!;
    if (done) {
      finished = part.toBytes();
      if (base64Encode(sha256.convert(finished!).bytes) != shas[id]) {
        req.response.statusCode = 401;
        await req.response.close();
        return;
      }
    }
    req.response.write(jsonEncode({
      'offset': part.length,
      'complete': done,
      if (done) 'blob_id': 'b-$id',
      if (done) 'size_bytes': part.length,
      if (done) 'expires_at_ms': 1,
    }));
    await req.response.close();
  }
}

void main() {
  late _FakeRelay relay;
  setUp(() async => relay = await _FakeRelay.start());
  tearDown(() => relay.server.close(force: true));

  Uint8List data(int n) =>
      Uint8List.fromList(List<int>.generate(n, (i) => (i * 13) % 251));

  Future<BlobUploadResult> upload(
    Uint8List body, {
    void Function(int, int)? onProgress,
    BlobUploadCancelToken? cancel,
  }) => BlobClient(baseUrl: relay.base, httpClient: http.Client())
      .uploadCiphertextResumable(
        length: body.length,
        read: (o, n) async => Uint8List.sublistView(body, o, o + n),
        ttlSeconds: 60,
        bodySha256B64: base64Encode(sha256.convert(body).bytes),
        accessTokenB64: 'AAAA',
        onProgress: onProgress,
        cancelToken: cancel,
      );

  test('🔴 файл уходит кусками, сервер собирает те же байты, ход растёт до '
      'конца', () async {
    final body = data(5 * 1024 * 1024 + 123);
    final seen = <int>[];
    final r = await upload(body, onProgress: (s, t) => seen.add(s));
    expect(r.blobId, 'b-s1');
    expect(relay.finished, body);
    expect(relay.puts, greaterThan(1), reason: 'кусками, а не одним запросом');
    expect(seen.last, body.length);
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i], greaterThanOrEqualTo(seen[i - 1]), reason: 'не назад');
    }
  });

  test('🔴 обрыв посреди куска — переспросить смещение и продолжить, а не с '
      'нуля', () async {
    final body = data(3 * 1024 * 1024);
    relay.dropNextPuts = 2;
    final r = await upload(body);
    expect(r.blobId, isNotEmpty);
    expect(relay.finished, body);
    expect(relay.statusCalls, greaterThanOrEqualTo(2));
    expect(relay.parts.length, 1, reason: 'та же сессия, не новая');
  });

  test('маленькое фото — тоже с ходом загрузки', () async {
    final body = data(300 * 1024);
    final seen = <int>[];
    await upload(body, onProgress: (s, t) => seen.add(s));
    expect(seen.length, greaterThan(2), reason: 'кольцо не прыгает 0→100');
    expect(relay.finished, body);
  });

  test('реле без сессий (старое) — понятный отказ для запасного пути',
      () async {
    relay.sessionsSupported = false;
    await expectLater(
      upload(data(1000)),
      throwsA(isA<BlobResumableUnsupported>()),
    );
  });

  test('✕ — отмена, а не «сбой сети»', () async {
    final body = data(4 * 1024 * 1024);
    final token = BlobUploadCancelToken();
    await expectLater(
      upload(
        body,
        cancel: token,
        onProgress: (s, t) {
          if (s > 600 * 1024) token.cancel();
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
    expect(relay.finished, isNull);
  });

  test('размер куска', () {
    expect(BlobClient.resumableChunkSize(100 * 1024, 8 << 20), 512 * 1024);
    expect(BlobClient.resumableChunkSize(16 << 20, 8 << 20), 2 << 20);
    expect(BlobClient.resumableChunkSize(1 << 30, 8 << 20), 8 << 20);
  });

  test('🔴 подписываемые сообщения — побайтово как у реле (тот же образец в '
      'тесте Rust)', () {
    expect(
      BlobClient.sessionCreateMessage(
        deviceId: 'd1',
        ttlSeconds: 60,
        uploadLength: 10,
        bodySha256B64: 'B',
        accessTokenSha256B64: 'A',
        tsMs: 5,
        nonceB64: 'N',
      ),
      'SECRETLY-RELAY-HTTP-BLOB-SESSION-CREATE-V1\ndevice_id=d1\nttl_seconds=60\n'
      'upload_length=10\nbody_sha256_b64=B\naccess_token_sha256_b64=A\nts_ms=5\n'
      'nonce_b64=N\n',
    );
    expect(
      BlobClient.sessionPutMessage(
        deviceId: 'd1',
        sessionId: 's1',
        offset: 7,
        chunkSha256B64: 'C',
        tsMs: 5,
        nonceB64: 'N',
      ),
      'SECRETLY-RELAY-HTTP-BLOB-SESSION-PUT-V1\ndevice_id=d1\nsession_id=s1\n'
      'offset=7\nchunk_sha256_b64=C\nts_ms=5\nnonce_b64=N\n',
    );
    expect(
      BlobClient.sessionStatusMessage(
        deviceId: 'd1',
        sessionId: 's1',
        tsMs: 5,
        nonceB64: 'N',
      ),
      'SECRETLY-RELAY-HTTP-BLOB-SESSION-STATUS-V1\ndevice_id=d1\nsession_id=s1\n'
      'ts_ms=5\nnonce_b64=N\n',
    );
  });
}
