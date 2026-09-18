// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import 'relay_client.dart' show RelayHttpException;
import 'resilient_http_client.dart';

const _stickerCatalogSignatureHeader =
    'x-secretly-sticker-catalog-signature-b64';
const _stickerCatalogPublicKeyB64 =
    'rDfK+tfKZg3/1YFDjuX+cp0KBZAS4D0qvZuE6Pee3ag=';

class RemoteStickerCatalogManifest {
  const RemoteStickerCatalogManifest({
    required this.schemaVersion,
    required this.generatedAtMs,
    required this.packs,
  });

  final int schemaVersion;
  final int generatedAtMs;
  final List<RemoteStickerPackManifest> packs;

  factory RemoteStickerCatalogManifest.fromJson(Map<String, dynamic> json) {
    final packsJson = json['packs'];
    return RemoteStickerCatalogManifest(
      schemaVersion: _jsonInt(json['schema_version']) ?? 1,
      generatedAtMs: _jsonInt(json['generated_at_ms']) ?? 0,
      packs: packsJson is List
          ? packsJson
                .whereType<Map>()
                .map(
                  (item) => RemoteStickerPackManifest.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.packId.isNotEmpty && item.packVersion > 0)
                .toList(growable: false)
          : const <RemoteStickerPackManifest>[],
    );
  }
}

class RemoteStickerPackManifest {
  const RemoteStickerPackManifest({
    required this.packId,
    required this.packVersion,
    required this.title,
    required this.description,
    required this.iconStickerId,
    required this.iconEmojiHint,
    required this.featuredRank,
    required this.tags,
    required this.stickers,
  });

  final String packId;
  final int packVersion;
  final String title;
  final String description;
  final String iconStickerId;
  final String iconEmojiHint;
  final int? featuredRank;
  final List<String> tags;
  final List<RemoteStickerManifest> stickers;

  factory RemoteStickerPackManifest.fromJson(Map<String, dynamic> json) {
    final stickersJson = json['stickers'];
    return RemoteStickerPackManifest(
      packId: _jsonString(json['pack_id']),
      packVersion: _jsonInt(json['pack_version']) ?? 0,
      title: _jsonString(json['title']),
      description: _jsonString(json['description']),
      iconStickerId: _jsonString(json['icon_sticker_id']),
      iconEmojiHint: _jsonString(json['icon_emoji_hint']),
      featuredRank: _jsonInt(json['featured_rank']),
      tags: _jsonStringList(json['tags']),
      stickers: stickersJson is List
          ? stickersJson
                .whereType<Map>()
                .map(
                  (item) => RemoteStickerManifest.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.stickerId.isNotEmpty)
                .toList(growable: false)
          : const <RemoteStickerManifest>[],
    );
  }
}

class RemoteStickerManifest {
  const RemoteStickerManifest({
    required this.stickerId,
    required this.fileName,
    required this.format,
    required this.animated,
    required this.emojiHint,
    required this.label,
    required this.keywords,
    required this.sha256B64,
    required this.sizeBytes,
  });

  final String stickerId;
  final String fileName;
  final String format;
  final bool animated;
  final String emojiHint;
  final String label;
  final List<String> keywords;
  final String sha256B64;
  final int sizeBytes;

  factory RemoteStickerManifest.fromJson(Map<String, dynamic> json) {
    return RemoteStickerManifest(
      stickerId: _jsonString(json['sticker_id']),
      fileName: _jsonString(json['file_name']),
      format: _jsonString(json['format']),
      animated: _jsonBool(json['animated']),
      emojiHint: _jsonString(json['emoji_hint']),
      label: _jsonString(json['label']),
      keywords: _jsonStringList(json['keywords']),
      sha256B64: _jsonString(json['sha256_b64']),
      sizeBytes: _jsonInt(json['size_bytes']) ?? 0,
    );
  }
}

class StickerCatalogClient {
  StickerCatalogClient({required Uri baseUrl, http.Client? httpClient})
    : _baseUrl = _normalizeBaseUrl(baseUrl),
      _http = httpClient ?? createResilientHttpClient(),
      _ownsHttpClient = httpClient == null;

  final Uri _baseUrl;
  final http.Client _http;
  final bool _ownsHttpClient;

  void close() {
    if (_ownsHttpClient) {
      _http.close();
    }
  }

  static Uri _normalizeBaseUrl(Uri value) {
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      throw ArgumentError.value(value, 'baseUrl', 'must not be empty');
    }
    return Uri.parse(raw.endsWith('/') ? raw : '$raw/');
  }

  Future<RemoteStickerCatalogManifest> fetchManifest() async {
    final response = await _http.get(
      _baseUrl.resolve('v1/sticker-catalog/manifest'),
    );
    if (response.statusCode != 200) {
      throw RelayHttpException(
        operation: 'fetchStickerCatalogManifest',
        message: 'unexpected response',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
    final signatureB64 =
        response.headers[_stickerCatalogSignatureHeader]?.trim() ?? '';
    if (signatureB64.isEmpty) {
      throw const RelayHttpException(
        operation: 'fetchStickerCatalogManifest',
        message: 'missing sticker catalog signature header',
      );
    }
    await _verifyStickerCatalogManifestSignature(
      bodyBytes: response.bodyBytes,
      signatureB64: signatureB64,
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const RelayHttpException(
        operation: 'fetchStickerCatalogManifest',
        message: 'invalid catalog response body',
      );
    }
    return RemoteStickerCatalogManifest.fromJson(decoded);
  }

  Future<Uint8List> downloadAsset({
    required String packId,
    required int packVersion,
    required String stickerId,
  }) async {
    final response = await _http.get(
      _baseUrl.resolve(
        'v1/sticker-catalog/assets/$packId/$packVersion/$stickerId',
      ),
    );
    if (response.statusCode != 200) {
      throw RelayHttpException(
        operation: 'downloadStickerAsset',
        message: 'unexpected response',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
    return response.bodyBytes;
  }
}

Future<void> _verifyStickerCatalogManifestSignature({
  required Uint8List bodyBytes,
  required String signatureB64,
}) async {
  try {
    final publicKey = SimplePublicKey(
      base64Decode(_stickerCatalogPublicKeyB64),
      type: KeyPairType.ed25519,
    );
    final signature = Signature(
      base64Decode(signatureB64),
      publicKey: publicKey,
    );
    final verified = await Ed25519().verify(bodyBytes, signature: signature);
    if (!verified) {
      throw const RelayHttpException(
        operation: 'fetchStickerCatalogManifest',
        message: 'invalid sticker catalog signature',
      );
    }
  } on RelayHttpException {
    rethrow;
  } catch (_) {
    throw const RelayHttpException(
      operation: 'fetchStickerCatalogManifest',
      message: 'invalid sticker catalog signature',
    );
  }
}

String _jsonString(Object? value) => (value as String? ?? '').trim();

int? _jsonInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

bool _jsonBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return false;
}

List<String> _jsonStringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => (item as String? ?? '').trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
