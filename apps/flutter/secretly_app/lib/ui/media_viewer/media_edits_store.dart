// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Где лежат правки фото (параметры, не пиксели) — на этом устройстве.
///
/// 🔴 Правки — ЛОКАЛЬНЫЕ: собеседнику они не уходят, протокол не меняется,
/// старые сборки ничего не замечают. Оригинал в кэше вложений не трогается;
/// лента чата, просмотр и миниатюры рисуют снимок через правки, а «Поделиться»,
/// «Сохранить» и «Копировать» выгружают уже правленый снимок.
///
/// Хранение — рядом с кэшем вложений (`attachmentCacheParentDirectory()`),
/// то есть на том же уровне защиты, что и сами расшифрованные снимки:
/// `media_edits_v1/index.json` — список ключей, у которых есть правки, и по
/// файлу на ключ. Список читается один раз; лента с сотней фото не делает
/// сотню обращений к диску — только к тем снимкам, у которых правки есть.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../storage/attachment_cache_location.dart';
import 'media_edits.dart';

/// 🔴 22.11.2026 (слово владельца): правки чужого (и своего) фото больше НЕ
/// ложатся поверх оригинала в ленте. Правка — это новая копия: «Отправить»
/// или «Отменить». Хранилище остаётся (старые правки на диске просто не
/// читаются); `true` вернёт прежнее «правки поверх оригинала».
const bool kMediaEditsOverlay = false;

class MediaEditsStore {
  MediaEditsStore._();

  static final MediaEditsStore instance = MediaEditsStore._();

  /// Папка для тестов.
  @visibleForTesting
  Future<Directory> Function()? directoryOverride;

  /// Для тестов самого хранилища: читать правки, даже когда
  /// [kMediaEditsOverlay] выключен.
  @visibleForTesting
  bool? overlayOverride;

  bool get _overlay => overlayOverride ?? kMediaEditsOverlay;

  final Map<String, ValueNotifier<MediaEdits?>> _notifiers =
      <String, ValueNotifier<MediaEdits?>>{};
  final Set<String> _loaded = <String>{};
  Set<String>? _index;
  Future<Set<String>>? _indexLoad;
  Future<void> _writeChain = Future<void>.value();

  Future<Directory> _dir() async {
    final override = directoryOverride;
    final base = override != null
        ? await override()
        : await attachmentCacheParentDirectory();
    return Directory(p.join(base.path, 'media_edits_v1'));
  }

  static String _fileKey(String id) =>
      sha1.convert(utf8.encode(id)).toString();

  Future<Set<String>> _ensureIndex() {
    final known = _index;
    if (known != null) return Future<Set<String>>.value(known);
    return _indexLoad ??= () async {
      final out = <String>{};
      try {
        final f = File(p.join((await _dir()).path, 'index.json'));
        if (await f.exists()) {
          final raw = jsonDecode(await f.readAsString());
          if (raw is List) {
            for (final v in raw) {
              if (v is String && v.isNotEmpty) out.add(v);
            }
          }
        }
      } catch (_) {
        // Повреждённый список — как пустой: снимки просто без правок.
      }
      _index = out;
      return out;
    }();
  }

  /// Текущие правки, если уже прочитаны (синхронно, без диска).
  MediaEdits? peek(String id) => _notifiers[id]?.value;

  /// Подписка на правки снимка [id] (blobId вложения или путь файла).
  /// Значение сначала null; правки с диска приходят следом одним кадром.
  ValueListenable<MediaEdits?> listen(String id) {
    final n = _notifiers.putIfAbsent(id, () => ValueNotifier<MediaEdits?>(null));
    if (_loaded.add(id)) unawaited(_load(id, n));
    return n;
  }

  /// Правки с ожиданием чтения (для выгрузки и открытия просмотра).
  Future<MediaEdits?> read(String id) async {
    final n = _notifiers.putIfAbsent(id, () => ValueNotifier<MediaEdits?>(null));
    if (_loaded.add(id)) {
      await _load(id, n);
    } else {
      await _ensureIndex();
    }
    return n.value;
  }

  Future<void> _load(String id, ValueNotifier<MediaEdits?> n) async {
    if (!_overlay) return;
    try {
      final index = await _ensureIndex();
      if (!index.contains(id)) return;
      final f = File(p.join((await _dir()).path, '${_fileKey(id)}.json'));
      if (!await f.exists()) return;
      final edits = MediaEdits.decode(await f.readAsString());
      if (edits != null && !edits.isIdentity && n.value == null) {
        n.value = edits;
      }
    } catch (_) {
      // Без правок — показываем оригинал.
    }
  }

  /// Сохранить правки; пустые или null — удалить.
  Future<void> save(String id, MediaEdits? edits) async {
    final clean = edits?.cleaned();
    final keep = clean != null && !clean.isIdentity;
    final n = _notifiers.putIfAbsent(id, () => ValueNotifier<MediaEdits?>(null));
    _loaded.add(id);
    n.value = keep ? clean : null;
    final index = await _ensureIndex();
    final changedIndex = keep ? index.add(id) : index.remove(id);
    final snapshot = List<String>.of(index);
    final body = keep ? clean.encode() : null;
    _writeChain = _writeChain.then((_) async {
      try {
        final dir = await _dir();
        await dir.create(recursive: true);
        final f = File(p.join(dir.path, '${_fileKey(id)}.json'));
        if (body != null) {
          final tmp = File('${f.path}.tmp');
          await tmp.writeAsString(body, flush: true);
          await tmp.rename(f.path);
        } else if (await f.exists()) {
          await f.delete();
        }
        if (changedIndex) {
          final idx = File(p.join(dir.path, 'index.json'));
          final tmp = File('${idx.path}.tmp');
          await tmp.writeAsString(jsonEncode(snapshot), flush: true);
          await tmp.rename(idx.path);
        }
      } catch (_) {
        // Не записалось — правки живут до перезапуска; оригинал цел.
      }
    });
    await _writeChain;
  }

  /// Снимок удалён — его правки больше не нужны.
  Future<void> forget(String id) => save(id, null);

  @visibleForTesting
  void resetForTest() {
    for (final n in _notifiers.values) {
      n.dispose();
    }
    _notifiers.clear();
    _loaded.clear();
    _index = null;
    _indexLoad = null;
    _writeChain = Future<void>.value();
  }
}
