// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../diagnostics/diag_log.dart';
import '../security/auth_signer.dart';
import '../transport/cosmetics_catalog_client.dart';

export '../transport/cosmetics_catalog_client.dart'
    show RemoteCosmeticsManifest, RemoteCosmeticItem;

/// App-wide access to the server-hosted premium cosmetics catalog (icons +
/// wallpapers). Fetches + verifies the signed manifest (cached with a TTL) and
/// downloads + caches per-item thumbnail / full assets to disk, verifying each
/// download against the manifest SHA-256.
///
/// Everything here is BEST-EFFORT and fails OPEN: any network / parse / disk
/// error degrades to "no server cosmetics" rather than throwing into the UI.
class CosmeticsCatalogService {
  CosmeticsCatalogService._();
  static final CosmeticsCatalogService instance = CosmeticsCatalogService._();

  static const _manifestTtlMs = 6 * 60 * 60 * 1000; // 6h

  Uri? _baseUrl;
  CosmeticsCatalogClient? _client;
  Directory? _cacheRoot;

  RemoteCosmeticsManifest? _manifest;
  int _manifestFetchedAtMs = 0;
  Future<RemoteCosmeticsManifest>? _manifestInFlight;
  final Map<String, Future<File?>> _assetInFlight = <String, Future<File?>>{};

  // Bound concurrent asset downloads. A freshly-opened 750-icon grid otherwise
  // fires dozens of simultaneous thumb downloads that exhaust the HTTP
  // connection pool / time out, so most tiles fell back to the placeholder
  // glyph (and wallpaper previews stayed on the gradient). With a small ceiling
  // each download gets bandwidth and succeeds; the grid fills in progressively
  // but reliably. Tapping a single icon (one download) always worked — which is
  // exactly why "preview = glyph, but selecting it works".
  static const _maxConcurrentDownloads = 5;
  int _activeDownloads = 0;
  final List<Completer<void>> _downloadWaiters = <Completer<void>>[];

  Future<void> _acquireDownloadSlot() async {
    if (_activeDownloads < _maxConcurrentDownloads) {
      _activeDownloads++;
      return;
    }
    final waiter = Completer<void>();
    _downloadWaiters.add(waiter);
    await waiter.future; // slot handed over by _releaseDownloadSlot (count kept)
  }

  void _releaseDownloadSlot() {
    if (_downloadWaiters.isNotEmpty) {
      _downloadWaiters.removeAt(0).complete(); // hand the slot to the next waiter
    } else {
      _activeDownloads--;
    }
  }

  /// Wire the relay base URL (`AppController.relayHttpBaseUrl`). Idempotent;
  /// re-configuring with a different host resets the cached client + manifest.
  void configure(Uri relayBaseUrl) {
    if (_baseUrl == relayBaseUrl) return;
    _baseUrl = relayBaseUrl;
    _client?.close();
    _client = null;
    _manifest = null;
    _manifestFetchedAtMs = 0;
  }

  bool get isConfigured => _baseUrl != null;

  CosmeticsCatalogClient? _ensureClient() {
    final base = _baseUrl;
    if (base == null) return null;
    return _client ??= CosmeticsCatalogClient(baseUrl: base);
  }

  /// The signed manifest, cached for [_manifestTtlMs]. Fails open to the last
  /// good manifest (or empty) on any error.
  Future<RemoteCosmeticsManifest> manifest({bool force = false}) async {
    if (_baseUrl == null) return RemoteCosmeticsManifest.empty;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _manifest;
    if (!force &&
        cached != null &&
        now - _manifestFetchedAtMs < _manifestTtlMs) {
      return cached;
    }
    final existing = _manifestInFlight;
    if (existing != null) return existing;

    final client = _ensureClient();
    if (client == null) return cached ?? RemoteCosmeticsManifest.empty;

    final future = client
        .fetchManifest()
        .then((m) {
          _manifest = m;
          _manifestFetchedAtMs = DateTime.now().millisecondsSinceEpoch;
          DiagLog.event('cosmetics', 'manifest_loaded', {
            'items': m.items.length,
            'icons': m.icons.length,
            'wp': m.wallpapers.length,
          });
          return m;
        })
        .whenComplete(() => _manifestInFlight = null);
    _manifestInFlight = future;
    try {
      return await future;
    } catch (_) {
      return cached ?? RemoteCosmeticsManifest.empty;
    }
  }

  Future<List<RemoteCosmeticItem>> icons({bool force = false}) async =>
      (await manifest(force: force)).icons;

  Future<List<RemoteCosmeticItem>> wallpapers({bool force = false}) async {
    final list = (await manifest(force: force)).wallpapers;
    DiagLog.event('cosmetics', 'wallpapers_query', {
      'count': list.length,
      'configured': isConfigured,
    });
    return list;
  }

  Future<RemoteCosmeticItem?> itemById(String id) async {
    if (id.isEmpty) return null;
    for (final item in (await manifest()).items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Cached thumbnail file for [item] (downloads + verifies once). Null on any
  /// failure — callers fall back to a placeholder.
  Future<File?> thumbFile(RemoteCosmeticItem item) =>
      _ensureAsset(item, variant: 'thumb');

  /// Cached full-resolution file for [item] (downloads + verifies once).
  Future<File?> fullFile(RemoteCosmeticItem item) =>
      _ensureAsset(item, variant: 'full');

  Future<File?> _ensureAsset(
    RemoteCosmeticItem item, {
    required String variant,
  }) {
    final key = '${item.id}__$variant';
    final existing = _assetInFlight[key];
    if (existing != null) return existing;
    final future = _downloadAndCache(item, variant: variant).whenComplete(() {
      _assetInFlight.remove(key);
    });
    _assetInFlight[key] = future;
    return future;
  }

  Future<File?> _downloadAndCache(
    RemoteCosmeticItem item, {
    required String variant,
  }) async {
    final client = _ensureClient();
    if (client == null) return null;
    try {
      final dir = await _ensureKindDir(item.kind);
      final fileName = variant == 'thumb' ? item.thumbFile : item.fullFile;
      final expectedSha = variant == 'thumb'
          ? item.thumbSha256B64
          : item.sha256B64;
      final cached = File(
        p.join(dir.path, '${item.id}_$variant${_ext(fileName)}'),
      );
      if (await cached.exists() && await cached.length() > 0) {
        // Content-addressed validation: only reuse the cache if its bytes still
        // match the manifest's expected hash. When the catalog is regenerated
        // (e.g. wallpapers fixed from grayscale → colour) the hash changes, so a
        // stale cached file (keyed only by id+variant) must be discarded and
        // re-downloaded — otherwise the old asset is shown forever.
        if (expectedSha.isEmpty) return cached;
        try {
          final cachedSha = await AuthSigner.sha256B64(await cached.readAsBytes());
          if (cachedSha == expectedSha) return cached;
        } catch (_) {
          // unreadable cache → fall through and re-download
        }
      }

      await _acquireDownloadSlot();
      final bytes = await () async {
        try {
          return await client.downloadAsset(itemId: item.id, variant: variant);
        } finally {
          _releaseDownloadSlot();
        }
      }();
      if (bytes.isEmpty) {
        DiagLog.event('cosmetics', 'asset_empty', {
          'id': item.id,
          'variant': variant,
        });
        return null;
      }
      // Integrity: reject a download whose hash doesn't match the signed
      // manifest (when a hash is present).
      if (expectedSha.isNotEmpty) {
        final actual = await AuthSigner.sha256B64(bytes);
        if (actual != expectedSha) {
          DiagLog.event('cosmetics', 'asset_sha_mismatch', {
            'id': item.id,
            'variant': variant,
          });
          return null;
        }
      }
      final tmp = File('${cached.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(cached.path);
      return cached;
    } catch (e) {
      DiagLog.event('cosmetics', 'asset_download_failed', {
        'id': item.id,
        'variant': variant,
        'err': e.toString().replaceAll(RegExp(r'\s+'), '_'),
      });
      return null;
    }
  }

  Future<Directory> _ensureKindDir(String kind) async {
    final root =
        _cacheRoot ??= Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'cosmetics'),
        );
    final dir = Directory(
      p.join(root.path, kind == 'wallpaper' ? 'wallpapers' : 'icons'),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _ext(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '.webp';
    return fileName.substring(dot);
  }
}
