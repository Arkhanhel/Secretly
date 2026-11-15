// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../attachments/attachment_failure.dart';
import '../security/auth_signer.dart';
import '../security/device_keys.dart';
import 'resilient_http_client.dart';
import 'server_clock.dart';

class BlobClient {
  BlobClient({
    required this.baseUrl,
    this.deviceId,
    this.selfProfileId,
    this.deviceKeys,
    http.Client? httpClient,
    SimpleKeyPair? identityKeyPairOverride,
  }) : _http = httpClient ?? createResilientHttpClient(),
       _ownsHttpClient = httpClient == null,
       _identityKeyPairOverride = identityKeyPairOverride;

  final Uri baseUrl;
  final String? deviceId;
  final String? selfProfileId;
  final DeviceKeys? deviceKeys;

  final http.Client _http;
  final bool _ownsHttpClient;
  final SimpleKeyPair? _identityKeyPairOverride;

  SimpleKeyPair? _identityKeyPair;

  void close() {
    if (_ownsHttpClient) {
      _http.close();
    }
  }

  bool get _authConfigured {
    final did = deviceId;
    final pid = selfProfileId;
    if (did == null || did.isEmpty || pid == null || pid.isEmpty) return false;
    return deviceKeys != null || _identityKeyPairOverride != null;
  }

  Future<SimpleKeyPair> _loadIdentityKeyPair() async {
    final ov = _identityKeyPairOverride;
    if (ov != null) return ov;
    final cached = _identityKeyPair;
    if (cached != null) return cached;
    final dk = deviceKeys;
    final pid = selfProfileId;
    final did = deviceId;
    if (dk == null || pid == null || did == null) {
      throw StateError('BlobClient auth is not configured');
    }
    final kp = await dk.loadIdentityKeyPair(profileId: pid, deviceId: did);
    _identityKeyPair = kp;
    return kp;
  }

  /// Сколько времени отводить на заливку блоба такого размера.
  ///
  /// 🔴 ПОЧЕМУ (02.09.2026, аудит передачи файлов). Здесь стояли жёсткие 90
  /// секунд, и ни один вызывающий их не переопределял. Порог буферного пути
  /// для видео — 24 МБ, а сжатое видео обычно как раз 5–25 МБ, то есть почти
  /// всегда попадало сюда. По собственной оценке проекта «медленный
  /// мобильный» — это 250 КБ/с; 24 МБ на такой скорости идут около 98 секунд.
  /// Гарантированный таймаут на арифметике, без единого сбоя сети. Докачки
  /// нет: повтор начинается с нуля, то есть снова упирается в те же 90 секунд.
  ///
  /// Расчёт от размера тот же, что у копии переписки
  /// (`backupUploadTimeoutFor`): 250 КБ/с и потолок 10 минут, чтобы зависшая
  /// сеть не держала отправку вечно.
  ///
  /// 🔴 ПОЛ РАВЕН ПРЕЖНИМ 90 СЕКУНДАМ, А НЕ 30, КАК У КОПИИ ПЕРЕПИСКИ.
  /// Первая редакция этой правки взяла пол в 30 секунд по образцу бэкапа — и
  /// тем самым УХУДШИЛА всё, что меньше двадцати мегабайт: голосовое, снимок,
  /// короткое видео получали 30–70 секунд вместо прежних 90. То есть на очень
  /// плохой связи снимок, который раньше кое-как уходил, стал срываться втрое
  /// раньше. Разбор по размерам это и показал: правка, задуманная против
  /// срывов, вводила новые.
  ///
  /// Пол в 90 секунд делает изменение строго односторонним: ни один размер не
  /// получает МЕНЬШЕ, чем получал до правки, а большие файлы получают больше.
  /// У копии переписки пол ниже потому, что там прежним поведением был не
  /// таймаут в полторы минуты, а восемь секунд.
  static Duration uploadTimeoutFor(int bodyBytes) {
    const bytesPerSecond = 250 * 1024;
    const floor = Duration(seconds: 90);
    const ceiling = Duration(minutes: 10);
    final needed = Duration(seconds: (bodyBytes / bytesPerSecond).ceil() + 10);
    if (needed < floor) return floor;
    if (needed > ceiling) return ceiling;
    return needed;
  }

  Future<BlobUploadResult> uploadCiphertext(
    Uint8List ciphertext, {
    required int ttlSeconds,
    required String accessTokenB64,
    /// `null` — считать от размера. Явное значение по-прежнему уважается:
    /// тесты и особые случаи ничего не теряют.
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? uploadTimeoutFor(ciphertext.length);
    final uri = baseUrl.resolve('/v1/blob/upload?ttl_seconds=$ttlSeconds');

    final headers = <String, String>{
      'content-type': 'application/octet-stream',
    };
    final bodySha256B64 = await AuthSigner.sha256B64(ciphertext);
    final accessTokenSha256B64 = await _blobAccessTokenHashB64(accessTokenB64);
    headers['x-secretly-body-sha256-b64'] = bodySha256B64;
    headers['x-secretly-blob-access-token-sha256-b64'] = accessTokenSha256B64;
    final did = deviceId;
    if (did != null && _authConfigured) {
      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = AuthSigner.relayHttpBlobUploadMessage(
        deviceId: did,
        ttlSeconds: ttlSeconds,
        bodySha256B64: bodySha256B64,
        accessTokenSha256B64: accessTokenSha256B64,
        tsMs: tsMs,
        nonceB64: nonceB64,
      );
      final sigB64 = await AuthSigner.signEd25519B64(
        identityKeyPair: await _loadIdentityKeyPair(),
        message: msg,
      );
      headers.addAll({
        'x-secretly-device-id': did,
        'x-secretly-ts-ms': tsMs.toString(),
        'x-secretly-nonce-b64': nonceB64,
        'x-secretly-signature-b64': sigB64,
      });
    }

    final resp = await _http
        .post(uri, headers: headers, body: ciphertext)
        .timeout(effectiveTimeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('blob upload failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return BlobUploadResult(
      blobId: json['blob_id'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      expiresAtMs: (json['expires_at_ms'] as num).toInt(),
    );
  }

  Future<BlobUploadResult> uploadCiphertextFile(
    File ciphertextFile, {
    required int ttlSeconds,
    required String bodySha256B64,
    required String accessTokenB64,
    void Function(int sentBytes, int totalBytes)? onProgress,
    // Generous ceiling: large media on a slow uplink legitimately takes many
    // minutes (a 100 MB file at ~500 KB/s is ~3.5 min — the old 3 min cap timed
    // it out). The upload streams with backpressure and is cancellable, so this
    // only guards a truly dead connection.
    Duration timeout = const Duration(minutes: 30),
    BlobUploadCancelToken? cancelToken,
  }) async {
    final uri = baseUrl.resolve('/v1/blob/upload?ttl_seconds=$ttlSeconds');
    final len = await ciphertextFile.length();
    final accessTokenSha256B64 = await _blobAccessTokenHashB64(accessTokenB64);

    // 🔴 О3 (15.11.2026): тело — сам поток файла, его читает HTTP-клиент
    // (см. [_StreamBodyRequest]). Файл открывается, только когда клиент
    // начал отправку, и читается со скоростью сокета.
    var sent = 0;
    final bodyStream = ciphertextFile.openRead().map<List<int>>((chunk) {
      if (cancelToken?.isCanceled == true) {
        throw AttachmentFailure(AttachmentFailureCode.uploadCanceled);
      }
      sent += chunk.length;
      onProgress?.call(sent, len);
      return chunk;
    });
    final req = _StreamBodyRequest('POST', uri, bodyStream);
    req.headers['content-type'] = 'application/octet-stream';
    req.headers['x-secretly-body-sha256-b64'] = bodySha256B64;
    req.headers['x-secretly-blob-access-token-sha256-b64'] =
        accessTokenSha256B64;
    req.contentLength = len;

    final did = deviceId;
    if (did != null && _authConfigured) {
      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = AuthSigner.relayHttpBlobUploadMessage(
        deviceId: did,
        ttlSeconds: ttlSeconds,
        bodySha256B64: bodySha256B64,
        accessTokenSha256B64: accessTokenSha256B64,
        tsMs: tsMs,
        nonceB64: nonceB64,
      );
      final sigB64 = await AuthSigner.signEd25519B64(
        identityKeyPair: await _loadIdentityKeyPair(),
        message: msg,
      );
      req.headers.addAll({
        'x-secretly-device-id': did,
        'x-secretly-ts-ms': tsMs.toString(),
        'x-secretly-nonce-b64': nonceB64,
        'x-secretly-signature-b64': sigB64,
      });
    }

    // Start the request FIRST so the HTTP client begins consuming the body
    // stream immediately, then feed the file into it.
    //
    // 🔴 О3 (разбор медиа 15.11.2026). The comment here used to promise
    // backpressure, but the feed was `await for (chunk) req.sink.add(chunk)`:
    // `sink.add` never waits, so the whole ciphertext was read into the
    // request's buffer at disk speed. Measured: a 128 MB body pushed to a slow
    // server reached «100 %» in 0.7 s while the process held 1.29 GB; the real
    // upload then crawled on behind a full bar ("138/138 but stuck"), and a
    // 1 GB premium file risked the app. Now the HTTP client reads the file
    // stream itself ([_StreamBodyRequest]): only as fast as the socket takes
    // it (same test: flat memory, progress grows with what the server
    // receives), and a refused connection never even opens the file. Cancel
    // is checked per chunk inside the stream, so ✕ stops the transfer
    // mid-way.
    if (!kReleaseMode) {
      developer.log(
        'ATTACH_FLOW http.send.start len=$len timeoutMs=${timeout.inMilliseconds}',
        name: 'BlobClient',
      );
    }
    final responseFuture = _http
        .send(req)
        .timeout(
          timeout,
          onTimeout: () =>
              throw AttachmentFailure(AttachmentFailureCode.uploadTimedOut),
        );

    final http.StreamedResponse streamed;
    try {
      streamed = await responseFuture;
    } catch (_) {
      // ✕ посреди файла: ошибка из потока тела обрывает запрос — человеку
      // это «отменено», а не «сбой сети».
      if (cancelToken?.isCanceled == true) {
        throw AttachmentFailure(AttachmentFailureCode.uploadCanceled);
      }
      rethrow;
    }
    if (cancelToken?.isCanceled == true) {
      throw AttachmentFailure(AttachmentFailureCode.uploadCanceled);
    }
    if (!kReleaseMode) {
      developer.log(
        'ATTACH_FLOW http.send.headers status=${streamed.statusCode}',
        name: 'BlobClient',
      );
    }
    final body = await streamed.stream.bytesToString().timeout(
      timeout,
      onTimeout: () =>
          throw AttachmentFailure(AttachmentFailureCode.uploadTimedOut),
    );
    if (!kReleaseMode) {
      developer.log(
        'ATTACH_FLOW http.send.body.done status=${streamed.statusCode} bodyLen=${body.length}',
        name: 'BlobClient',
      );
    }
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw StateError('blob upload failed: ${streamed.statusCode} $body');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return BlobUploadResult(
      blobId: json['blob_id'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      expiresAtMs: (json['expires_at_ms'] as num).toInt(),
    );
  }

  // ── Отправка частями с докачкой (разбор медиа 15.11.2026) ─────────────
  //
  // Как у Signal и WhatsApp: один способ для любого размера. Реле открывает
  // сессию и помнит, сколько принято; кусок подписан устройством и сверен по
  // хешу; обрыв — переспросить смещение и продолжить с него. Прежняя заливка
  // одним запросом остаётся для доли устройств вне флага и для реле без
  // сессий (404 на открытие — [BlobResumableUnsupported]).

  /// Сколько продолжать после обрывов, прежде чем сдаться.
  static const Duration resumableRetryBudget = Duration(minutes: 3);

  /// Размер куска: ~1/8 файла, от 512 КБ до предела реле (8 МБ). Мало
  /// запросов на большой файл и плавная полоса внутри куска.
  @visibleForTesting
  static int resumableChunkSize(int length, int serverMax) {
    const minChunk = 512 * 1024;
    final cap = serverMax > 0 ? serverMax : 8 * 1024 * 1024;
    final want = (length / 8).ceil();
    return want.clamp(minChunk, cap < minChunk ? minChunk : cap);
  }

  Future<BlobUploadResult> uploadCiphertextResumable({
    required int length,
    required Future<List<int>> Function(int offset, int length) read,
    required int ttlSeconds,
    required String bodySha256B64,
    required String accessTokenB64,
    void Function(int sentBytes, int totalBytes)? onProgress,
    BlobUploadCancelToken? cancelToken,
  }) async {
    final accessTokenSha256B64 = await _blobAccessTokenHashB64(accessTokenB64);
    final deadline = DateTime.now().add(resumableRetryBudget);
    var reported = 0;
    void progress(int sent) {
      if (sent > reported) {
        reported = sent;
        onProgress?.call(sent, length);
      }
    }

    void checkCancel() {
      if (cancelToken?.isCanceled == true) {
        throw AttachmentFailure(AttachmentFailureCode.uploadCanceled);
      }
    }

    var reopened = false;
    while (true) {
      checkCancel();
      final session = await _openUploadSession(
        length: length,
        ttlSeconds: ttlSeconds,
        bodySha256B64: bodySha256B64,
        accessTokenSha256B64: accessTokenSha256B64,
      );
      final chunk = resumableChunkSize(length, session.maxChunkBytes);
      var offset = session.offset;
      var attempt = 0;
      try {
        while (true) {
          checkCancel();
          final n = (length - offset).clamp(0, chunk);
          final bytes = await read(offset, n);
          final _PutOutcome out;
          try {
            out = await _putChunk(
              sessionId: session.id,
              offset: offset,
              chunk: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
              onSent: (sent) => progress(offset + sent),
              cancelToken: cancelToken,
            );
          } on AttachmentFailure {
            rethrow;
          } on _SessionGone {
            rethrow;
          } on _FatalUploadStatus {
            rethrow;
          } catch (e) {
            // Обрыв, тайм-аут, 5xx: пауза, переспросить смещение, дальше.
            checkCancel();
            if (DateTime.now().isAfter(deadline)) rethrow;
            attempt++;
            await Future<void>.delayed(
              Duration(seconds: [1, 2, 4, 8, 15][(attempt - 1).clamp(0, 4)]),
            );
            checkCancel();
            final known = await _sessionOffsetOrNull(session.id);
            if (known != null) offset = known;
            continue;
          }
          attempt = 0;
          offset = out.offset;
          progress(offset);
          final result = out.result;
          if (result != null) return result;
        }
      } on _SessionGone {
        // Сессия истекла (сутки) или реле её не знает — одна новая попытка
        // с начала; вторая подряд — уже сбой.
        if (reopened) {
          throw StateError('blob upload failed: 404 upload session gone');
        }
        reopened = true;
        reported = 0;
        continue;
      } on _FatalUploadStatus catch (f) {
        throw StateError('blob upload failed: ${f.status} ${f.body}');
      }
    }
  }

  Future<({String id, int offset, int maxChunkBytes})> _openUploadSession({
    required int length,
    required int ttlSeconds,
    required String bodySha256B64,
    required String accessTokenSha256B64,
  }) async {
    final uri = baseUrl.resolve(
      '/v1/blob/upload/session?ttl_seconds=$ttlSeconds',
    );
    final headers = <String, String>{
      'x-secretly-body-sha256-b64': bodySha256B64,
      'x-secretly-blob-access-token-sha256-b64': accessTokenSha256B64,
      'x-secretly-upload-length': '$length',
    };
    final did = deviceId;
    if (did != null && _authConfigured) {
      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = utf8.encode(
        sessionCreateMessage(
          deviceId: did,
          ttlSeconds: ttlSeconds,
          uploadLength: length,
          bodySha256B64: bodySha256B64,
          accessTokenSha256B64: accessTokenSha256B64,
          tsMs: tsMs,
          nonceB64: nonceB64,
        ),
      );
      headers.addAll(await _signedHeaders(did, tsMs, nonceB64, msg));
    }
    final resp = await _http
        .post(uri, headers: headers)
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode == 404 || resp.statusCode == 405) {
      throw const BlobResumableUnsupported();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('blob upload failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return (
      id: json['session_id'] as String,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      maxChunkBytes: (json['max_chunk_bytes'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int?> _sessionOffsetOrNull(String sessionId) async {
    try {
      final uri = baseUrl.resolve('/v1/blob/upload/session/$sessionId');
      final headers = <String, String>{};
      final did = deviceId;
      if (did != null && _authConfigured) {
        final tsMs = ServerClock.instance.nowMs();
        final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
        final msg = utf8.encode(
          sessionStatusMessage(
            deviceId: did,
            sessionId: sessionId,
            tsMs: tsMs,
            nonceB64: nonceB64,
          ),
        );
        headers.addAll(await _signedHeaders(did, tsMs, nonceB64, msg));
      }
      final resp = await _http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 404) throw const _SessionGone();
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return (json['offset'] as num?)?.toInt();
    } on _SessionGone {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<_PutOutcome> _putChunk({
    required String sessionId,
    required int offset,
    required Uint8List chunk,
    required void Function(int sent) onSent,
    BlobUploadCancelToken? cancelToken,
  }) async {
    final uri = baseUrl.resolve('/v1/blob/upload/session/$sessionId');
    final chunkSha = await AuthSigner.sha256B64(chunk);
    // Тело — тот же поток с ожиданием сети, что у большой заливки: полоса
    // идёт по отправленному, ✕ рвёт кусок посреди.
    var sent = 0;
    Stream<List<int>> pieces() async* {
      const step = 64 * 1024;
      for (var i = 0; i < chunk.length; i += step) {
        if (cancelToken?.isCanceled == true) {
          throw AttachmentFailure(AttachmentFailureCode.uploadCanceled);
        }
        final end = (i + step).clamp(0, chunk.length);
        yield Uint8List.sublistView(chunk, i, end);
        sent = end;
        onSent(sent);
      }
    }

    final req = _StreamBodyRequest('PUT', uri, pieces());
    req.contentLength = chunk.length;
    req.headers['content-type'] = 'application/octet-stream';
    req.headers['x-secretly-upload-offset'] = '$offset';
    req.headers['x-secretly-chunk-sha256-b64'] = chunkSha;
    final did = deviceId;
    if (did != null && _authConfigured) {
      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = utf8.encode(
        sessionPutMessage(
          deviceId: did,
          sessionId: sessionId,
          offset: offset,
          chunkSha256B64: chunkSha,
          tsMs: tsMs,
          nonceB64: nonceB64,
        ),
      );
      req.headers.addAll(await _signedHeaders(did, tsMs, nonceB64, msg));
    }
    final http.StreamedResponse streamed;
    try {
      streamed = await _http
          .send(req)
          .timeout(uploadTimeoutFor(chunk.length));
    } catch (_) {
      if (cancelToken?.isCanceled == true) {
        throw AttachmentFailure(AttachmentFailureCode.uploadCanceled);
      }
      rethrow;
    }
    final body = await streamed.stream
        .bytesToString()
        .timeout(const Duration(seconds: 60));
    final status = streamed.statusCode;
    if (status == 404) throw const _SessionGone();
    if (status == 409) {
      // Кусок уже принят (ответ потерялся) или занят — смещение от реле.
      final json = _tryJson(body);
      final known = (json?['offset'] as num?)?.toInt();
      if (known == null) throw StateError('blob upload busy');
      return _PutOutcome(offset: known, result: null);
    }
    if (status >= 500 || status == 429) {
      throw StateError('blob upload retryable: $status');
    }
    if (status < 200 || status >= 300) {
      throw _FatalUploadStatus(status, body);
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final newOffset = (json['offset'] as num).toInt();
    if (json['complete'] == true) {
      return _PutOutcome(
        offset: newOffset,
        result: BlobUploadResult(
          blobId: json['blob_id'] as String,
          sizeBytes: (json['size_bytes'] as num).toInt(),
          expiresAtMs: (json['expires_at_ms'] as num).toInt(),
        ),
      );
    }
    return _PutOutcome(offset: newOffset, result: null);
  }

  /// Подписываемые сообщения сессий. ОБЯЗАНЫ совпадать с Rust
  /// `http_blob_session_*_auth_message` побайтово (оба теста держат один
  /// и тот же образец).
  @visibleForTesting
  static String sessionCreateMessage({
    required String deviceId,
    required int ttlSeconds,
    required int uploadLength,
    required String bodySha256B64,
    required String accessTokenSha256B64,
    required int tsMs,
    required String nonceB64,
  }) =>
      'SECRETLY-RELAY-HTTP-BLOB-SESSION-CREATE-V1\n'
      'device_id=$deviceId\nttl_seconds=$ttlSeconds\n'
      'upload_length=$uploadLength\nbody_sha256_b64=$bodySha256B64\n'
      'access_token_sha256_b64=$accessTokenSha256B64\n'
      'ts_ms=$tsMs\nnonce_b64=$nonceB64\n';

  @visibleForTesting
  static String sessionPutMessage({
    required String deviceId,
    required String sessionId,
    required int offset,
    required String chunkSha256B64,
    required int tsMs,
    required String nonceB64,
  }) =>
      'SECRETLY-RELAY-HTTP-BLOB-SESSION-PUT-V1\n'
      'device_id=$deviceId\nsession_id=$sessionId\noffset=$offset\n'
      'chunk_sha256_b64=$chunkSha256B64\nts_ms=$tsMs\nnonce_b64=$nonceB64\n';

  @visibleForTesting
  static String sessionStatusMessage({
    required String deviceId,
    required String sessionId,
    required int tsMs,
    required String nonceB64,
  }) =>
      'SECRETLY-RELAY-HTTP-BLOB-SESSION-STATUS-V1\n'
      'device_id=$deviceId\nsession_id=$sessionId\n'
      'ts_ms=$tsMs\nnonce_b64=$nonceB64\n';

  Future<Map<String, String>> _signedHeaders(
    String did,
    int tsMs,
    String nonceB64,
    List<int> msg,
  ) async {
    final sigB64 = await AuthSigner.signEd25519B64(
      identityKeyPair: await _loadIdentityKeyPair(),
      message: msg,
    );
    return {
      'x-secretly-device-id': did,
      'x-secretly-ts-ms': tsMs.toString(),
      'x-secretly-nonce-b64': nonceB64,
      'x-secretly-signature-b64': sigB64,
    };
  }

  static Map<String, dynamic>? _tryJson(String body) {
    try {
      final v = jsonDecode(body);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> downloadCiphertext(
    String blobId, {
    String? accessTokenB64,
  }) async {
    final uri = baseUrl.resolve('/v1/blob/$blobId');
    final headers = await _buildBlobDownloadHeaders(
      blobId,
      accessTokenB64: accessTokenB64,
    );
    final resp = await _http.get(uri, headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('blob download failed: ${resp.statusCode}');
    }
    // `bodyBytes` УЖЕ `Uint8List` и принадлежит только этому ответу — копия
    // здесь удваивала пик памяти на ровном месте: 24 МБ блоба означали 48 МБ
    // живых байтов, и оба куска доживали до расшифровки.
    return resp.bodyBytes;
  }

  /// Сколько ждать ЗАГОЛОВКОВ ответа. Сервер к этому моменту только открывает
  /// файл — если он молчит полминуты, ответа не будет вовсе.
  static const Duration downloadHeadersTimeout = Duration(seconds: 30);

  /// Сколько терпеть ТИШИНУ внутри тела ответа. Считается не от начала
  /// скачивания, а от последнего пришедшего куска, поэтому большой файл на
  /// медленной связи качается сколько нужно — лишь бы данные шли.
  static const Duration downloadStallTimeout = Duration(seconds: 45);

  Future<File> downloadCiphertextToFile(
    String blobId, {
    required File outputFile,
    String? accessTokenB64,
    // П5 (разбор медиа 15.11.2026): ход скачивания для пузыря. `total` —
    // длина из ответа сервера; `null`, если сервер её не назвал.
    void Function(int received, int? total)? onProgress,
    // О6/П5: [outputFile] — недокачанный кусок прежней попытки; докачать
    // с его конца (`Range`). Сервер без докачки ответит 200 — файл тогда
    // пишется заново, как раньше. При обрыве кусок НЕ удаляется.
    bool resume = false,
  }) async {
    final uri = baseUrl.resolve('/v1/blob/$blobId');
    final request = http.Request('GET', uri);
    request.headers.addAll(
      await _buildBlobDownloadHeaders(blobId, accessTokenB64: accessTokenB64),
    );
    var offset = 0;
    if (resume) {
      try {
        if (await outputFile.exists()) offset = await outputFile.length();
      } catch (_) {
        offset = 0;
      }
      if (offset > 0) request.headers['range'] = 'bytes=$offset-';
    }
    // 🔴 ТАЙМАУТ НА ЗАГОЛОВКИ (02.09.2026, аудит передачи файлов). Здесь не
    // было предела вовсе: зависшая TCP-сессия держала вызывающего в состоянии
    // «загружается» бесконечно. Предзагрузка вложений с её четырьмя попытками
    // при таком зависании не доходила даже до второй.
    final response = await _http
        .send(request)
        .timeout(downloadHeadersTimeout);
    // Кусок не совпал с файлом на сервере (416 — длиннее файла; 206 не с
    // того места) — выбрасываем его и качаем целиком.
    final partialOk =
        response.statusCode == 206 &&
        offset > 0 &&
        (response.headers['content-range'] ?? '').startsWith(
          'bytes $offset-',
        );
    if (offset > 0 && (response.statusCode == 416 ||
        (response.statusCode == 206 && !partialOk))) {
      await response.stream.drain<void>().catchError((Object _) {});
      try {
        await outputFile.delete();
      } catch (_) {}
      return downloadCiphertextToFile(
        blobId,
        outputFile: outputFile,
        accessTokenB64: accessTokenB64,
        onProgress: onProgress,
        resume: false,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('blob download failed: ${response.statusCode}');
    }
    await outputFile.parent.create(recursive: true);
    final sink = outputFile.openWrite(
      mode: partialOk ? FileMode.append : FileMode.write,
    );
    final base = partialOk ? offset : 0;
    final total = response.contentLength == null
        ? null
        : base + response.contentLength!;
    var received = base;
    try {
      // 🔴 СТОРОЖ ТИШИНЫ, А НЕ ОБЩИЙ ПРЕДЕЛ. Сервер не поддерживает докачку с
      // середины, поэтому обрыв на девяноста процентах означает качать всё
      // заново — общий таймаут на скачивание рубил бы честные большие файлы на
      // медленной связи. Ждём только паузу МЕЖДУ кусками: пока данные идут,
      // хоть по чуть-чуть, скачивание живо.
      await for (final chunk
          in response.stream.timeout(
            downloadStallTimeout,
            onTimeout: (sink) => sink.addError(
              TimeoutException(
                'blob download stalled',
                downloadStallTimeout,
              ),
            ),
          )) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      return outputFile;
    } catch (_) {
      // С докачкой кусок остаётся для следующей попытки.
      if (!resume) {
        try {
          if (await outputFile.exists()) {
            await outputFile.delete();
          }
        } catch (_) {}
      }
      rethrow;
    } finally {
      await sink.close();
    }
  }

  Future<Map<String, String>> _buildBlobDownloadHeaders(
    String blobId, {
    String? accessTokenB64,
  }) async {
    final headers = <String, String>{};
    String? accessTokenSha256B64;
    final normalizedAccessToken = accessTokenB64?.trim();
    if (normalizedAccessToken != null && normalizedAccessToken.isNotEmpty) {
      accessTokenSha256B64 = await _blobAccessTokenHashB64(
        normalizedAccessToken,
      );
      headers['x-secretly-blob-access-token-b64'] = normalizedAccessToken;
    }
    final did = deviceId;
    if (did != null && _authConfigured) {
      final tsMs = ServerClock.instance.nowMs();
      final nonceB64 = AuthSigner.randomNonceB64(bytes: 16);
      final msg = AuthSigner.relayHttpBlobGetMessage(
        deviceId: did,
        blobId: blobId,
        accessTokenSha256B64: accessTokenSha256B64,
        tsMs: tsMs,
        nonceB64: nonceB64,
      );
      final sigB64 = await AuthSigner.signEd25519B64(
        identityKeyPair: await _loadIdentityKeyPair(),
        message: msg,
      );
      headers.addAll({
        'x-secretly-device-id': did,
        'x-secretly-ts-ms': tsMs.toString(),
        'x-secretly-nonce-b64': nonceB64,
        'x-secretly-signature-b64': sigB64,
      });
    }
    return headers;
  }

  Future<String> _blobAccessTokenHashB64(String accessTokenB64) async {
    try {
      final raw = base64Decode(accessTokenB64);
      if (raw.isEmpty) throw const FormatException('empty');
      return await AuthSigner.sha256B64(raw);
    } on FormatException {
      throw StateError('bad blob access token');
    }
  }
}

/// Запрос, телом которого служит готовый поток (файл), а не буфер.
///
/// 🔴 О3 (разбор медиа 15.11.2026). Прежняя подача (`sink.add` в цикле)
/// не ждала сети: весь файл копился в памяти, полоса доходила до 100 % за
/// секунду. Подача через `sink.addStream` ждёт сети, но зависала навсегда,
/// если соединение не открылось вовсе (клиент так и не начинал читать). Здесь
/// клиент сам читает поток: со скоростью сокета, а при отказе соединения файл
/// даже не открывается.
///
/// Наследник [http.StreamedRequest] — чтобы обход блокировок
/// (`rewriteRequestToLoopback`) переносил его как обычный потоковый запрос.
class _StreamBodyRequest extends http.StreamedRequest {
  _StreamBodyRequest(super.method, super.url, this._body);

  final Stream<List<int>> _body;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_body);
  }
}

/// Реле не знает отправку частями (старое) — вызывающий отправляет прежним
/// способом.
class BlobResumableUnsupported implements Exception {
  const BlobResumableUnsupported();
}

class _SessionGone implements Exception {
  const _SessionGone();
}

class _FatalUploadStatus implements Exception {
  const _FatalUploadStatus(this.status, this.body);
  final int status;
  final String body;
}

class _PutOutcome {
  const _PutOutcome({required this.offset, required this.result});
  final int offset;
  final BlobUploadResult? result;
}

class BlobUploadCancelToken {
  bool _canceled = false;

  bool get isCanceled => _canceled;

  void cancel() {
    _canceled = true;
  }
}

class BlobUploadResult {
  const BlobUploadResult({
    required this.blobId,
    required this.sizeBytes,
    required this.expiresAtMs,
  });

  final String blobId;
  final int sizeBytes;
  final int expiresAtMs;
}
