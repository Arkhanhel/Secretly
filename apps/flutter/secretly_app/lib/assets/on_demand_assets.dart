// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Украшения по требованию: файлы, которых облегчённая сборка не везёт (Э7).
///
/// Полный пакет Android весит 136 МиБ, и 22 из них — украшения: 366 значков
/// профиля и обои чатов. Человеку за раз нужен один значок и одни обои,
/// остальные 21,9 МиБ он носит в телефоне на всякий случай. Облегчённая сборка
/// их не везёт, а берёт по мере надобности и кладёт рядом.
///
/// 🔴 ЦЕЛОСТНОСТЬ — БЕЗ ПОДПИСИ, ПО СОДЕРЖИМОМУ. Файл запрашивается по
/// SHA-256, и этот же SHA-256 лежит в перечне ВНУТРИ подписанного пакета
/// приложения. Подменённый сервером файл не совпадёт с ожидаемым отпечатком и
/// будет выброшен; подпись каталога тут ничего не добавила бы. Поэтому и
/// раздача идёт без входа: это общедоступные украшения, как наклейки рядом.
///
/// 🔴 ОТКАЗ ДОЛЖЕН БЫТЬ ТИХИМ. Нет сети, сервер не выложил пакет, не совпал
/// отпечаток — на экране остаются буквы вместо значка и ровный цвет вместо
/// обоев. Ни одно украшение не стоит того, чтобы из-за него не открылся чат.
///
/// В полной сборке этот путь не работает вовсе: файл находится в пакете на
/// первом же шаге, и ни сети, ни диска здесь не касаются.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../diagnostics/diag_log.dart';

/// Запись перечня: чего ждать от файла.
@immutable
class OnDemandAssetEntry {
  const OnDemandAssetEntry({required this.sha256Hex, required this.bytes});

  /// 64 строчных шестнадцатеричных знака: и имя на сервере, и проверка.
  final String sha256Hex;

  /// Размер в байтах. Проверяется до подсчёта отпечатка — несовпадение
  /// размера отсекает мусор, не читая всё целиком.
  final int bytes;

  static OnDemandAssetEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final hex = (raw['sha256'] as String?)?.trim().toLowerCase() ?? '';
    final size = (raw['bytes'] as num?)?.toInt() ?? 0;
    if (!isSha256Hex(hex) || size <= 0) return null;
    return OnDemandAssetEntry(sha256Hex: hex, bytes: size);
  }

  /// Строгая проверка: имя файла на сервере строится из этого значения.
  static bool isSha256Hex(String value) {
    if (value.length != 64) return false;
    for (final code in value.codeUnits) {
      final isDigit = code >= 0x30 && code <= 0x39;
      final isLower = code >= 0x61 && code <= 0x66;
      if (!isDigit && !isLower) return false;
    }
    return true;
  }
}

/// Откуда взялись байты — для диагностики и тестов.
enum OnDemandAssetSource { bundle, cache, network, unavailable }

@immutable
class OnDemandAssetResult {
  const OnDemandAssetResult(this.bytes, this.source);
  final Uint8List? bytes;
  final OnDemandAssetSource source;
}

/// Загрузчик украшений по требованию.
class OnDemandAssets {
  OnDemandAssets({
    required Future<Uri?> Function() relayBaseUrl,
    required Future<Uint8List> Function(Uri url) fetch,
    AssetBundle? bundle,
    Future<Directory> Function()? cacheDirectory,
  }) : _relayBaseUrl = relayBaseUrl,
       _fetch = fetch,
       _bundle = bundle ?? rootBundle,
       _cacheDirectory = cacheDirectory ?? _defaultCacheDirectory;

  /// Единственный экземпляр на приложение; `null` — загрузчик не настроен.
  static OnDemandAssets? instance;

  static const String manifestAsset = 'assets/on_demand_manifest.json';
  static const int manifestVersion = 1;

  /// Потолок на файл: украшения — это значок или обои, а не видео. Защита от
  /// сервера, который в ответ на запрос отдаёт поток без конца.
  static const int maxAssetBytes = 8 * 1024 * 1024;

  final Future<Uri?> Function() _relayBaseUrl;
  final Future<Uint8List> Function(Uri url) _fetch;
  final AssetBundle _bundle;
  final Future<Directory> Function() _cacheDirectory;

  Map<String, OnDemandAssetEntry>? _manifest;
  Future<Map<String, OnDemandAssetEntry>>? _manifestInFlight;
  final Map<String, Future<OnDemandAssetResult>> _inFlight =
      <String, Future<OnDemandAssetResult>>{};
  final Set<String> _failed = <String>{};

  static Future<Directory> _defaultCacheDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'on_demand_assets'));
  }

  /// Перечень читается один раз. Его отсутствие — не ошибка: сборка может
  /// везти все украшения с собой.
  Future<Map<String, OnDemandAssetEntry>> manifest() {
    final ready = _manifest;
    if (ready != null) return Future<Map<String, OnDemandAssetEntry>>.value(ready);
    return _manifestInFlight ??= _loadManifest().then((value) {
      _manifest = value;
      _manifestInFlight = null;
      return value;
    });
  }

  Future<Map<String, OnDemandAssetEntry>> _loadManifest() async {
    try {
      final raw = await _bundle.loadString(manifestAsset);
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['v'] != manifestVersion) {
        return const <String, OnDemandAssetEntry>{};
      }
      final assets = decoded['assets'];
      if (assets is! Map) return const <String, OnDemandAssetEntry>{};
      final out = <String, OnDemandAssetEntry>{};
      assets.forEach((key, value) {
        final path = key is String ? key.trim() : '';
        final entry = OnDemandAssetEntry.tryParse(value);
        if (path.isNotEmpty && entry != null) out[path] = entry;
      });
      return out;
    } catch (_) {
      return const <String, OnDemandAssetEntry>{};
    }
  }

  /// Байты украшения: из пакета, из копии рядом или из сети. `null` — не
  /// вышло, и звать повторно за этим же файлом в этом запуске бессмысленно.
  Future<OnDemandAssetResult> load(String assetPath) {
    final existing = _inFlight[assetPath];
    if (existing != null) return existing;
    final future = _load(assetPath).whenComplete(() {
      _inFlight.remove(assetPath);
    });
    _inFlight[assetPath] = future;
    return future;
  }

  Future<OnDemandAssetResult> _load(String assetPath) async {
    // 1. Пакет приложения. В полной сборке путь заканчивается здесь.
    try {
      final data = await _bundle.load(assetPath);
      return OnDemandAssetResult(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        OnDemandAssetSource.bundle,
      );
    } catch (_) {
      // Файла в пакете нет — это и есть облегчённая сборка.
    }

    final entry = (await manifest())[assetPath];
    if (entry == null || _failed.contains(assetPath)) {
      return const OnDemandAssetResult(null, OnDemandAssetSource.unavailable);
    }

    // 2. Копия рядом. Имя — отпечаток, поэтому подменить её незаметно нельзя:
    // проверка размера ловит обрезанную запись.
    final file = await _cacheFile(entry);
    try {
      if (await file.exists() && await file.length() == entry.bytes) {
        return OnDemandAssetResult(
          await file.readAsBytes(),
          OnDemandAssetSource.cache,
        );
      }
    } catch (_) {
      // Нечитаемая копия — просто скачаем заново.
    }

    // 3. Сеть. Через обычный путь приложения, то есть и через обходные пути.
    try {
      final base = await _relayBaseUrl();
      if (base == null) {
        return const OnDemandAssetResult(null, OnDemandAssetSource.unavailable);
      }
      if (entry.bytes > maxAssetBytes) {
        throw const FormatException('asset too large');
      }
      final bytes = await _fetch(
        base.resolve('/v1/app-assets/${entry.sha256Hex}'),
      );
      if (bytes.length != entry.bytes) {
        throw const FormatException('size mismatch');
      }
      final digest = sha256.convert(bytes).toString();
      if (digest != entry.sha256Hex) {
        throw const FormatException('digest mismatch');
      }
      await _writeCache(file, bytes);
      return OnDemandAssetResult(bytes, OnDemandAssetSource.network);
    } catch (e) {
      _failed.add(assetPath);
      DiagLog.event('assets', 'on_demand_failed', {
        'err': e.runtimeType.toString(),
      });
      return const OnDemandAssetResult(null, OnDemandAssetSource.unavailable);
    }
  }

  Future<File> _cacheFile(OnDemandAssetEntry entry) async {
    final dir = await _cacheDirectory();
    return File(p.join(dir.path, entry.sha256Hex));
  }

  /// Запись через временный файл: прерванное скачивание не должно оставить
  /// короткий файл под правильным именем.
  Future<void> _writeCache(File file, Uint8List bytes) async {
    try {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.part');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
    } catch (_) {
      // Не смогли сохранить — украшение всё равно показано, просто в
      // следующий раз придётся скачать снова.
    }
  }

  /// Сколько занимают скачанные украшения. Для экрана «Хранилище».
  Future<int> cacheSizeBytes() async {
    try {
      final dir = await _cacheDirectory();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearCache() async {
    try {
      final dir = await _cacheDirectory();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Нечего удалять или не дали — не повод для ошибки.
    }
    _failed.clear();
  }

  @visibleForTesting
  void resetFailuresForTesting() => _failed.clear();
}
