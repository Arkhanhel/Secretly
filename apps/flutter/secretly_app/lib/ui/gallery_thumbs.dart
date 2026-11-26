// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Миниатюры галереи для скрепки (25.11.2026).
///
/// Владелец: у человека с большой фототекой галерея первые секунды сильно
/// тормозит, потом отпускает. На iPhone плагин фототеки отдаёт картинку в
/// главном потоке и там же сжимает её в JPEG, а интерфейс Flutter живёт в том
/// же потоке: каждая миниатюра отнимала кадр. Здесь:
/// - iPhone — свой канал: сжатие в фоне, сперва быстрая картинка, чёткая
///   следом; нет канала (старая нативная часть) или он не справился — прежний
///   путь плагина;
/// - очередь: не больше [maxFast] быстрых и [maxFull] чётких сразу; ушедшее с
///   экрана не грузится;
/// - память [maxBytes]: второе открытие — сразу.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import 'icons/app_icons.dart';

typedef GalleryThumbResult = ({Uint8List? data, bool degraded});

/// Получить миниатюру: [full] — чёткую (можно из iCloud), иначе быструю.
typedef GalleryThumbFetch = Future<GalleryThumbResult> Function(
  AssetEntity asset, {
  required bool full,
});

class _Entry {
  _Entry(this.asset);

  final AssetEntity asset;
  Uint8List? data;
  bool full = false;
  bool failed = false;
  bool busy = false;
  bool queued = false;
  Future<Uint8List?>? future;
  final Set<VoidCallback> watchers = <VoidCallback>{};
  final List<Completer<Uint8List?>> waiters = <Completer<Uint8List?>>[];

  bool get wanted => watchers.isNotEmpty || waiters.isNotEmpty;
}

class GalleryThumbs {
  GalleryThumbs({required this.fetch, this.maxBytes = 16 * 1024 * 1024});

  static final GalleryThumbs instance = GalleryThumbs(
    fetch: fetchGalleryThumb,
  );

  static const int maxFast = 4;
  static const int maxFull = 2;

  final GalleryThumbFetch fetch;
  final int maxBytes;

  /// Быстрых больше не ждём (замер открытия).
  VoidCallback? onFastIdle;

  // Порядок — от давно не виденных к свежим (LRU).
  final LinkedHashMap<String, _Entry> _entries =
      LinkedHashMap<String, _Entry>();
  final Queue<_Entry> _fast = Queue<_Entry>();
  final Queue<_Entry> _slow = Queue<_Entry>();
  int _fastNow = 0;
  int _slowNow = 0;
  int _bytes = 0;

  static String _key(AssetEntity a) => '${a.id}|${a.modifiedDateSecond ?? 0}';

  _Entry _entry(AssetEntity a) {
    final key = _key(a);
    final e = _entries.remove(key) ?? _Entry(a);
    _entries[key] = e;
    return e;
  }

  /// Что уже есть (быстрая или чёткая).
  Uint8List? peek(AssetEntity a) => _entries[_key(a)]?.data;

  bool failed(AssetEntity a) => _entries[_key(a)]?.failed ?? false;

  /// Клетка на экране: [onChange] — картинка появилась или стала чётче.
  void watch(AssetEntity a, VoidCallback onChange) {
    final e = _entry(a);
    e.watchers.add(onChange);
    _enqueue(e);
  }

  void unwatch(AssetEntity a, VoidCallback onChange) {
    _entries[_key(a)]?.watchers.remove(onChange);
    _trim();
  }

  /// Одна картинка (просмотр, лента выбранных). Пока данные те же, future
  /// один и тот же — FutureBuilder не мигает на перестройках.
  Future<Uint8List?> bytes(AssetEntity a) {
    final e = _entry(a);
    final ready = e.data;
    if (ready != null) return e.future ??= Future<Uint8List?>.value(ready);
    final waiting = e.future;
    if (waiting != null) return waiting;
    final c = Completer<Uint8List?>();
    e.waiters.add(c);
    e.future = c.future;
    _enqueue(e);
    return c.future;
  }

  void _enqueue(_Entry e) {
    if (e.busy || e.queued || e.full) return;
    e.queued = true;
    // Быстрая уже есть — осталась чёткая.
    (e.data == null && !e.failed ? _fast : _slow).add(e);
    e.failed = false;
    _pump();
  }

  void _pump() {
    while (_fastNow < maxFast && _fast.isNotEmpty) {
      final e = _fast.removeFirst()..queued = false;
      if (!e.wanted || e.busy || e.data != null) continue;
      _fastNow++;
      unawaited(_run(e, full: false));
    }
    // Чёткие — только когда быстрым уже ничего не ждать.
    while (_fast.isEmpty && _fastNow == 0 && _slowNow < maxFull && _slow.isNotEmpty) {
      final e = _slow.removeFirst()..queued = false;
      if (!e.wanted || e.busy || e.full) continue;
      _slowNow++;
      unawaited(_run(e, full: true));
    }
  }

  Future<void> _run(_Entry e, {required bool full}) async {
    e.busy = true;
    GalleryThumbResult r = (data: null, degraded: false);
    try {
      r = await fetch(e.asset, full: full).timeout(
        full ? const Duration(seconds: 30) : const Duration(seconds: 6),
      );
    } catch (_) {
      // Не вышло — ниже решим, пробовать ли чёткую.
    }
    e.busy = false;
    full ? _slowNow-- : _fastNow--;
    final data = r.data;
    if (data != null && data.isNotEmpty) {
      _bytes += data.length - (e.data?.length ?? 0);
      e.data = data;
      e.full = full || !r.degraded;
      e.failed = false;
      e.future = null;
      _done(e, data);
      if (!e.full) _queueFull(e);
    } else if (!full) {
      // Быстрой нет (снимок только в iCloud) — сразу за чёткой.
      _queueFull(e);
    } else {
      e.failed = e.data == null;
      e.full = e.data != null; // чёткой не будет — остаёмся при быстрой
      e.future = null;
      _done(e, e.data);
    }
    _trim();
    _pump();
    if (!full && _fastNow == 0 && _fast.isEmpty) onFastIdle?.call();
  }

  void _queueFull(_Entry e) {
    if (e.queued) return;
    e.queued = true;
    _slow.add(e);
  }

  void _done(_Entry e, Uint8List? data) {
    final waiters = List.of(e.waiters);
    e.waiters.clear();
    for (final w in waiters) {
      if (!w.isCompleted) w.complete(data);
    }
    for (final cb in List.of(e.watchers)) {
      cb();
    }
  }

  void _trim() {
    if (_bytes <= maxBytes) return;
    for (final key in List.of(_entries.keys)) {
      if (_bytes <= maxBytes) return;
      final e = _entries[key]!;
      if (e.wanted || e.busy) continue;
      _bytes -= e.data?.length ?? 0;
      e.data = null;
      _entries.remove(key);
    }
  }

  @visibleForTesting
  int get cachedBytes => _bytes;
}

const MethodChannel _thumbChannel = MethodChannel('secretly/gallery_thumbs');
bool _nativeThumbs = true;

/// Миниатюра снимка: iPhone — свой канал, иначе плагин.
Future<GalleryThumbResult> fetchGalleryThumb(
  AssetEntity asset, {
  required bool full,
}) async {
  if (Platform.isIOS && _nativeThumbs) {
    try {
      final r = await _thumbChannel.invokeMapMethod<String, Object?>('thumb', {
        'id': asset.id,
        'px': 320,
        'full': full,
      });
      final data = r?['data'];
      if (data is Uint8List && data.isNotEmpty) {
        return (data: data, degraded: r?['degraded'] == true);
      }
      // Быстрой нет — дальше попросят чёткую.
      if (!full) return (data: null, degraded: false);
    } on MissingPluginException {
      _nativeThumbs = false;
    } on PlatformException {
      if (!full) return (data: null, degraded: false);
    }
  }
  final data = await asset.thumbnailDataWithSize(
    const ThumbnailSize(320, 320),
    quality: 80,
  );
  return (data: data, degraded: false);
}

/// Подготовить снимки страницы одним запросом к фототеке (iPhone).
void prepareGalleryThumbs(Iterable<AssetEntity> assets) {
  if (!Platform.isIOS || !_nativeThumbs) return;
  unawaited(
    _thumbChannel
        .invokeMethod<void>('prepare', {
          'ids': [for (final a in assets) a.id],
        })
        .catchError((Object _) {}),
  );
}

/// Клетка сетки: картинка, а до неё — спокойная заливка (крутилка в каждой
/// из двадцати клеток рисовалась каждый кадр под размытием листа).
class GalleryThumbView extends StatefulWidget {
  const GalleryThumbView({super.key, required this.asset, this.thumbs});

  final AssetEntity asset;
  final GalleryThumbs? thumbs;

  @override
  State<GalleryThumbView> createState() => _GalleryThumbViewState();
}

class _GalleryThumbViewState extends State<GalleryThumbView> {
  GalleryThumbs get _t => widget.thumbs ?? GalleryThumbs.instance;

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _t.watch(widget.asset, _changed);
  }

  @override
  void didUpdateWidget(covariant GalleryThumbView old) {
    super.didUpdateWidget(old);
    if (GalleryThumbs._key(old.asset) != GalleryThumbs._key(widget.asset)) {
      _t.unwatch(old.asset, _changed);
      _t.watch(widget.asset, _changed);
    }
  }

  @override
  void dispose() {
    _t.unwatch(widget.asset, _changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _t.peek(widget.asset);
    if (data != null) {
      return Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: _t.failed(widget.asset)
          ? Icon(
              AppIcons.brokenImage,
              color: colors.onSurface.withValues(alpha: 0.6),
            )
          : null,
    );
  }
}
