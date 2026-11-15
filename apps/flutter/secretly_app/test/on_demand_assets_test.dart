// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/assets/on_demand_assets.dart';

// Э7: украшения по требованию. Главное здесь — целостность и тишина при
// отказе: подменённый сервером файл не должен дойти до экрана, а недоступный
// не должен ничего ронять.

const String _path = 'assets/Background/wallpaper_dark_navy.jpg';
final Uri _relayBase = Uri.parse('https://relay.example.com');
final Uint8List _real = Uint8List.fromList(List<int>.generate(64, (i) => i));
final Uint8List _fake = Uint8List.fromList(List<int>.filled(64, 7));
final String _realHex = sha256.convert(_real).toString();

String _manifestJson({String? sha, int? bytes, int v = 1}) => jsonEncode({
  'v': v,
  'assets': <String, Object?>{
    _path: <String, Object?>{
      'sha256': sha ?? _realHex,
      'bytes': bytes ?? _real.length,
    },
  },
});

/// Пакет приложения, в котором украшения нет (облегчённая сборка).
class _BundleWithout extends CachingAssetBundle {
  _BundleWithout(this.manifest);
  final String manifest;

  @override
  Future<ByteData> load(String key) async {
    if (key == OnDemandAssets.manifestAsset) {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(manifest)));
    }
    throw FlutterError('not in bundle: $key');
  }
}

/// Пакет приложения, в котором украшение есть (полная сборка).
class _BundleWith extends _BundleWithout {
  _BundleWith(super.manifest);

  @override
  Future<ByteData> load(String key) async {
    if (key == _path) return ByteData.sublistView(_real);
    return super.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('secretly_on_demand_');
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  OnDemandAssets build({
    required AssetBundle bundle,
    required Future<Uint8List> Function(Uri) fetch,
    Uri? base,
    bool noBase = false,
  }) {
    return OnDemandAssets(
      relayBaseUrl: () async => noBase ? null : (base ?? _relayBase),
      fetch: fetch,
      bundle: bundle,
      cacheDirectory: () async => dir,
    );
  }

  test('🔴 в полной сборке до сети не доходим', () async {
    var calls = 0;
    final assets = build(
      bundle: _BundleWith(_manifestJson()),
      fetch: (_) async {
        calls++;
        return _real;
      },
    );
    final result = await assets.load(_path);
    expect(result.source, OnDemandAssetSource.bundle);
    expect(result.bytes, _real);
    expect(calls, 0, reason: 'файл в пакете — сеть не нужна');
  });

  test('🔴 скачанное проверяется по отпечатку и сохраняется рядом', () async {
    final urls = <Uri>[];
    final assets = build(
      bundle: _BundleWithout(_manifestJson()),
      fetch: (url) async {
        urls.add(url);
        return _real;
      },
    );
    final first = await assets.load(_path);
    expect(first.source, OnDemandAssetSource.network);
    expect(first.bytes, _real);
    expect(urls.single.path, '/v1/app-assets/$_realHex');
    expect(File('${dir.path}/$_realHex').existsSync(), isTrue,
        reason: 'имя копии — отпечаток');

    // Второй раз — уже с диска, сеть не трогаем.
    final second = await build(
      bundle: _BundleWithout(_manifestJson()),
      fetch: (_) async => throw StateError('сеть не должна была понадобиться'),
    ).load(_path);
    expect(second.source, OnDemandAssetSource.cache);
    expect(second.bytes, _real);
  });

  test('🔴 подменённый сервером файл не доходит до экрана', () async {
    final assets = build(
      bundle: _BundleWithout(_manifestJson()),
      fetch: (_) async => _fake,
    );
    final result = await assets.load(_path);
    expect(result.bytes, isNull);
    expect(result.source, OnDemandAssetSource.unavailable);
    expect(
      Directory(dir.path).listSync(),
      isEmpty,
      reason: 'непрошедшее проверку не сохраняется',
    );
  });

  test('🔴 неверный размер отвергается до подсчёта отпечатка', () async {
    final assets = build(
      bundle: _BundleWithout(_manifestJson(bytes: _real.length + 1)),
      fetch: (_) async => _real,
    );
    expect((await assets.load(_path)).bytes, isNull);
  });

  test('отказ сети — тихий, и повторно за тем же файлом не ходим', () async {
    var calls = 0;
    final assets = build(
      bundle: _BundleWithout(_manifestJson()),
      fetch: (_) async {
        calls++;
        throw const SocketException('нет сети');
      },
    );
    expect((await assets.load(_path)).bytes, isNull);
    expect((await assets.load(_path)).bytes, isNull);
    expect(calls, 1, reason: 'второй заход за тем же файлом бессмысленен');
    assets.resetFailuresForTesting();
    expect((await assets.load(_path)).bytes, isNull);
    expect(calls, 2);
  });

  test('без адреса реле и без перечня — молча ничего', () async {
    final noBase = build(
      bundle: _BundleWithout(_manifestJson()),
      fetch: (_) async => _real,
      noBase: true,
    );
    expect((await noBase.load(_path)).bytes, isNull);

    final otherVersion = build(
      bundle: _BundleWithout(_manifestJson(v: 2)),
      fetch: (_) async => _real,
    );
    expect((await otherVersion.load(_path)).bytes, isNull);
    expect(await otherVersion.manifest(), isEmpty);
  });

  test('запись перечня: только 64 строчных шестнадцатеричных знака', () {
    expect(OnDemandAssetEntry.isSha256Hex(_realHex), isTrue);
    expect(OnDemandAssetEntry.isSha256Hex(_realHex.toUpperCase()), isFalse);
    expect(OnDemandAssetEntry.isSha256Hex('abc'), isFalse);
    expect(OnDemandAssetEntry.isSha256Hex('../${'a' * 61}'), isFalse);
    expect(OnDemandAssetEntry.tryParse(<String, Object?>{}), isNull);
    expect(
      OnDemandAssetEntry.tryParse(<String, Object?>{
        'sha256': _realHex,
        'bytes': 0,
      }),
      isNull,
      reason: 'нулевой размер — испорченная запись',
    );
  });

  test('размер скачанного и очистка', () async {
    final assets = build(
      bundle: _BundleWithout(_manifestJson()),
      fetch: (_) async => _real,
    );
    expect(await assets.cacheSizeBytes(), 0);
    await assets.load(_path);
    expect(await assets.cacheSizeBytes(), _real.length);
    await assets.clearCache();
    expect(await assets.cacheSizeBytes(), 0);
  });
}
