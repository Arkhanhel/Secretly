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

    final req = http.StreamedRequest('POST', uri);
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
    // stream immediately, then feed chunks into it. This ties the feed loop's
    // pace (and therefore `onProgress`) to the actual NETWORK transmission via
    // backpressure. The previous order — fill the whole sink, THEN send —
    // buffered the entire file in memory and reported progress as sink-fill,
    // so the bar jumped to 100% instantly while the real upload was still
    // crawling ("138/138 but stuck"), and large files spiked RAM.
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

    var sent = 0;
    try {
      await for (final chunk in ciphertextFile.openRead()) {
        if (cancelToken?.isCanceled == true) {
          throw AttachmentFailure(AttachmentFailureCode.uploadCanceled);
        }
        req.sink.add(chunk);
        sent += chunk.length;
        onProgress?.call(sent, len);
      }
    } finally {
      await req.sink.close();
    }

    if (cancelToken?.isCanceled == true) {
      throw AttachmentFailure(AttachmentFailureCode.uploadCanceled);
    }

    final streamed = await responseFuture;
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
  }) async {
    final uri = baseUrl.resolve('/v1/blob/$blobId');
    final request = http.Request('GET', uri);
    request.headers.addAll(
      await _buildBlobDownloadHeaders(blobId, accessTokenB64: accessTokenB64),
    );
    // 🔴 ТАЙМАУТ НА ЗАГОЛОВКИ (02.09.2026, аудит передачи файлов). Здесь не
    // было предела вовсе: зависшая TCP-сессия держала вызывающего в состоянии
    // «загружается» бесконечно. Предзагрузка вложений с её четырьмя попытками
    // при таком зависании не доходила даже до второй.
    final response = await _http
        .send(request)
        .timeout(downloadHeadersTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('blob download failed: ${response.statusCode}');
    }
    await outputFile.parent.create(recursive: true);
    final sink = outputFile.openWrite();
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
      }
      await sink.flush();
      return outputFile;
    } catch (_) {
      try {
        if (await outputFile.exists()) {
          await outputFile.delete();
        }
      } catch (_) {}
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
