// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretly_app/transport/relay_client.dart';
import 'package:secretly_app/transport/sticker_catalog_client.dart';

void main() {
  group('StickerCatalogClient', () {
    const manifestBody =
        '{"schema_version":1,"generated_at_ms":123,"packs":[{"pack_id":"studio_pack","pack_version":1,"title":"Studio","description":"Design pack","icon_sticker_id":"studio_palette","icon_emoji_hint":"🎨","featured_rank":7,"tags":["remote","design"],"stickers":[{"sticker_id":"studio_palette","file_name":"studio_palette.png","format":"png","animated":false,"emoji_hint":"🎨","label":"Palette","keywords":["palette","design"],"sha256_b64":"aGFzaA==","size_bytes":128}]}]}';
    const manifestSignatureB64 =
        'uWlnkhaHWYYCObofT1BqFvt4n4ArOYy4WllmhYHT8dE9EodxVxTS7pqGjTmY1aX4W/b0eBCzuER4Lv3nZryQCg==';

    StickerCatalogClient buildClient({required MockClient httpClient}) {
      return StickerCatalogClient(
        baseUrl: Uri.parse('https://relay.example'),
        httpClient: httpClient,
      );
    }

    test('fetchManifest verifies detached signature header', () async {
      final client = buildClient(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/sticker-catalog/manifest');
          return http.Response.bytes(
            utf8.encode(manifestBody),
            200,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
              'x-secretly-sticker-catalog-signature-b64': manifestSignatureB64,
            },
          );
        }),
      );

      final manifest = await client.fetchManifest();

      expect(manifest.schemaVersion, 1);
      expect(manifest.generatedAtMs, 123);
      expect(manifest.packs, hasLength(1));
      expect(manifest.packs.single.packId, 'studio_pack');
      expect(manifest.packs.single.stickers.single.sizeBytes, 128);
    });

    test('fetchManifest rejects missing signature header', () async {
      final client = buildClient(
        httpClient: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(manifestBody),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }),
      );

      await expectLater(
        client.fetchManifest(),
        throwsA(isA<RelayHttpException>()),
      );
    });

    test('fetchManifest rejects invalid signature header', () async {
      final client = buildClient(
        httpClient: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(manifestBody),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
              'x-secretly-sticker-catalog-signature-b64': 'bad-signature',
            },
          );
        }),
      );

      await expectLater(
        client.fetchManifest(),
        throwsA(isA<RelayHttpException>()),
      );
    });
  });
}