// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import 'relay_client.dart' show RelayHttpException;
import 'resilient_http_client.dart';

// Signed catalog of premium cosmetics (profile icons + chat wallpapers) served
// by the relay (`/v1/cosmetics/*`). Mirrors the sticker-catalog client: a JSON
// manifest + detached Ed25519 signature header. Dedicated cosmetics signing
// keypair (see tools/cosmetics_catalog_admin.dart).
const _cosmeticsCatalogSignatureHeader =
    'x-secretly-cosmetics-catalog-signature-b64';
const _cosmeticsCatalogPublicKeyB64 =
    'wVglSPPCfQ+r+rF0LzoDSxT+n3ewDCVFzfsQoMDuevw=';

class RemoteCosmeticsManifest {
  const RemoteCosmeticsManifest({
    required this.schemaVersion,
    required this.generatedAtMs,
    required this.items,
  });

  final int schemaVersion;
  final int generatedAtMs;
  final List<RemoteCosmeticItem> items;

  List<RemoteCosmeticItem> get icons =>
      items.where((i) => i.kind == 'icon').toList(growable: false);
  List<RemoteCosmeticItem> get wallpapers =>
      items.where((i) => i.kind == 'wallpaper').toList(growable: false);

  static const empty = RemoteCosmeticsManifest(
    schemaVersion: 1,
    generatedAtMs: 0,
    items: <RemoteCosmeticItem>[],
  );

  factory RemoteCosmeticsManifest.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'];
    return RemoteCosmeticsManifest(
      schemaVersion: _jsonInt(json['schema_version']) ?? 1,
      generatedAtMs: _jsonInt(json['generated_at_ms']) ?? 0,
      items: itemsJson is List
          ? itemsJson
                .whereType<Map>()
                .map(
                  (item) => RemoteCosmeticItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.id.isNotEmpty && item.kind.isNotEmpty)
                .toList(growable: false)
          : const <RemoteCosmeticItem>[],
    );
  }
}

class RemoteCosmeticItem {
  const RemoteCosmeticItem({
    required this.id,
    required this.kind,
    required this.thumbFile,
    required this.fullFile,
    required this.title,
    required this.sha256B64,
    required this.thumbSha256B64,
    required this.sizeBytes,
  });

  /// Stable catalog id (also the asset-route path segment).
  final String id;

  /// `'icon'` or `'wallpaper'`.
  final String kind;
  final String thumbFile;
  final String fullFile;
  final String title;

  /// Base64 SHA-256 of the FULL asset (client verifies the download).
  final String sha256B64;
  final String thumbSha256B64;
  final int sizeBytes;

  factory RemoteCosmeticItem.fromJson(Map<String, dynamic> json) {
    return RemoteCosmeticItem(
      id: _jsonString(json['id']),
      kind: _jsonString(json['kind']),
      thumbFile: _jsonString(json['thumb_file']),
      fullFile: _jsonString(json['full_file']),
      title: _jsonString(json['title']),
      sha256B64: _jsonString(json['sha256_b64']),
      thumbSha256B64: _jsonString(json['thumb_sha256_b64']),
      sizeBytes: _jsonInt(json['size_bytes']) ?? 0,
    );
  }
}

class CosmeticsCatalogClient {
  CosmeticsCatalogClient({required Uri baseUrl, http.Client? httpClient})
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

  /// Fetches + verifies the signed manifest. Returns [RemoteCosmeticsManifest.empty]
  /// when no catalog is deployed (server sends an empty signature) — that is a
  /// normal pre-launch state, not an error.
  Future<RemoteCosmeticsManifest> fetchManifest() async {
    final response = await _http.get(_baseUrl.resolve('v1/cosmetics/manifest'));
    if (response.statusCode != 200) {
      throw RelayHttpException(
        operation: 'fetchCosmeticsManifest',
        message: 'unexpected response',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
    final signatureB64 =
        response.headers[_cosmeticsCatalogSignatureHeader]?.trim() ?? '';
    if (signatureB64.isEmpty) {
      // No catalog deployed yet → ignore the body entirely (cannot be trusted
      // without a signature) and report empty.
      return RemoteCosmeticsManifest.empty;
    }
    await _verifyCosmeticsManifestSignature(
      bodyBytes: response.bodyBytes,
      signatureB64: signatureB64,
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const RelayHttpException(
        operation: 'fetchCosmeticsManifest',
        message: 'invalid catalog response body',
      );
    }
    return RemoteCosmeticsManifest.fromJson(decoded);
  }

  /// Downloads a single asset variant (`'thumb'` or `'full'`). Integrity is
  /// verified by the caller against the manifest sha256.
  Future<Uint8List> downloadAsset({
    required String itemId,
    required String variant,
  }) async {
    final response = await _http.get(
      _baseUrl.resolve('v1/cosmetics/assets/$itemId/$variant'),
    );
    if (response.statusCode != 200) {
      throw RelayHttpException(
        operation: 'downloadCosmeticAsset',
        message: 'unexpected response',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
    return response.bodyBytes;
  }
}

Future<void> _verifyCosmeticsManifestSignature({
  required Uint8List bodyBytes,
  required String signatureB64,
}) async {
  try {
    final publicKey = SimplePublicKey(
      base64Decode(_cosmeticsCatalogPublicKeyB64),
      type: KeyPairType.ed25519,
    );
    final signature = Signature(
      base64Decode(signatureB64),
      publicKey: publicKey,
    );
    final verified = await Ed25519().verify(bodyBytes, signature: signature);
    if (!verified) {
      throw const RelayHttpException(
        operation: 'fetchCosmeticsManifest',
        message: 'invalid cosmetics catalog signature',
      );
    }
  } on RelayHttpException {
    rethrow;
  } catch (_) {
    throw const RelayHttpException(
      operation: 'fetchCosmeticsManifest',
      message: 'invalid cosmetics catalog signature',
    );
  }
}

String _jsonString(Object? value) => (value as String? ?? '').trim();

int? _jsonInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
