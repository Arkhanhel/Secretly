// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:secretly_app/transport/blob_client.dart';

void main() {
  test('uploadCiphertext without auth does not send x-secretly headers', () async {
    late http.Request captured;
    late Uint8List capturedBody;

    final mock = MockClient((req) async {
      captured = req;
      capturedBody = Uint8List.fromList(captured.bodyBytes);
      return http.Response(
        jsonEncode({'blob_id': 'b1', 'size_bytes': 3, 'expires_at_ms': 123}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final c = BlobClient(
      baseUrl: Uri.parse('https://example.test'),
      httpClient: mock,
    );

    final bytes = Uint8List.fromList([1, 2, 3]);
    final token = base64Encode(List<int>.generate(32, (i) => i + 1));
    final r = await c.uploadCiphertext(
      bytes,
      ttlSeconds: 60,
      accessTokenB64: token,
    );
    expect(r.blobId, 'b1');

    expect(captured.method, 'POST');
    expect(captured.url.path, '/v1/blob/upload');
    expect(captured.url.queryParameters['ttl_seconds'], '60');

    expect(captured.headers['content-type'], 'application/octet-stream');
    expect(
      captured.headers['x-secretly-blob-access-token-sha256-b64'],
      isNotEmpty,
    );
    expect(captured.headers.containsKey('x-secretly-device-id'), isFalse);
    expect(captured.headers.containsKey('x-secretly-ts-ms'), isFalse);
    expect(captured.headers.containsKey('x-secretly-nonce-b64'), isFalse);
    expect(captured.headers.containsKey('x-secretly-signature-b64'), isFalse);

    expect(capturedBody, bytes);
  });

  test('uploadCiphertext with auth override sends x-secretly headers', () async {
    late http.Request captured;

    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({'blob_id': 'b2', 'size_bytes': 4, 'expires_at_ms': 456}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final kp = await Ed25519().newKeyPair();

    final c = BlobClient(
      baseUrl: Uri.parse('https://example.test'),
      deviceId: 'D1',
      selfProfileId: 'P1',
      identityKeyPairOverride: kp,
      httpClient: mock,
    );

    final bytes = Uint8List.fromList([9, 8, 7, 6]);
    final token = base64Encode(List<int>.generate(32, (i) => 255 - i));
    final r = await c.uploadCiphertext(
      bytes,
      ttlSeconds: 3600,
      accessTokenB64: token,
    );
    expect(r.blobId, 'b2');

    expect(captured.headers['x-secretly-blob-access-token-sha256-b64'], isNotEmpty);
    expect(captured.headers['x-secretly-device-id'], 'D1');
    expect(int.parse(captured.headers['x-secretly-ts-ms']!), greaterThan(0));
    expect(captured.headers['x-secretly-nonce-b64'], isNotEmpty);
    expect(captured.headers['x-secretly-signature-b64'], isNotEmpty);
  });

  test('downloadCiphertext sends access token when provided', () async {
    final mock = MockClient((req) async {
      expect(req.method, 'GET');
      expect(req.url.path, '/v1/blob/abc');
      expect(req.headers['x-secretly-blob-access-token-b64'], isNotEmpty);
      return http.Response.bytes([5, 6, 7], 200);
    });

    final c = BlobClient(
      baseUrl: Uri.parse('https://example.test'),
      httpClient: mock,
    );

    final token = base64Encode(List<int>.generate(32, (i) => i));
    final b = await c.downloadCiphertext('abc', accessTokenB64: token);
    expect(b, Uint8List.fromList([5, 6, 7]));
  });

  test('downloadCiphertextToFile writes response body to file', () async {
    final dir = await Directory.systemTemp.createTemp('secretly_blob_test_');
    try {
      final mock = MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, '/v1/blob/xyz');
        expect(req.headers['x-secretly-blob-access-token-b64'], isNotEmpty);
        return http.Response.bytes([8, 9, 10, 11], 200);
      });

      final c = BlobClient(
        baseUrl: Uri.parse('https://example.test'),
        httpClient: mock,
      );

      final token = base64Encode(List<int>.generate(32, (i) => 31 - i));
      final file = await c.downloadCiphertextToFile(
        'xyz',
        outputFile: File('${dir.path}/cipher.bin'),
        accessTokenB64: token,
      );

      expect(await file.readAsBytes(), Uint8List.fromList([8, 9, 10, 11]));
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  });
}
