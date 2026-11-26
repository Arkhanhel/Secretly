// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Галерея по скрепке: миниатюры очередью, память, слияние страниц
// (25.11.2026).

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:secretly_app/ui/chat_attachment_picker_sheet.dart';
import 'package:secretly_app/ui/gallery_thumbs.dart';

AssetEntity _a(int i, {int mod = 1}) => AssetEntity(
  id: 'id$i',
  typeInt: 1,
  width: 100,
  height: 100,
  modifiedDateSecond: mod,
);

class _Call {
  _Call(this.asset, this.full);
  final AssetEntity asset;
  final bool full;
  final Completer<GalleryThumbResult> done = Completer<GalleryThumbResult>();
  void ok({bool degraded = false, int size = 10}) =>
      done.complete((data: Uint8List(size)..[0] = 1, degraded: degraded));
  void none() => done.complete((data: null, degraded: false));
}

void main() {
  late List<_Call> calls;
  GalleryThumbs make({int maxBytes = 1 << 20}) {
    calls = [];
    return GalleryThumbs(
      maxBytes: maxBytes,
      fetch: (asset, {required full}) {
        final c = _Call(asset, full);
        calls.add(c);
        return c.done.future;
      },
    );
  }

  test('🔴 не больше четырёх сразу; ушедшее с экрана не грузится', () async {
    final t = make();
    void cb() {}
    for (var i = 0; i < 10; i++) {
      t.watch(_a(i), cb);
    }
    expect(calls, hasLength(4));
    // 4–8 прокрутили мимо.
    for (var i = 4; i < 9; i++) {
      t.unwatch(_a(i), cb);
    }
    calls[0].ok();
    await pumpEventQueue();
    expect(calls, hasLength(5));
    expect(calls.last.asset.id, 'id9');
    for (final c in calls.skip(1)) {
      c.ok();
    }
    await pumpEventQueue();
    expect(calls, hasLength(5));
  });

  test('🔴 быстрая сразу, чёткая — когда быстрые кончились', () async {
    final t = make();
    var changes = 0;
    t
      ..watch(_a(1), () => changes++)
      ..watch(_a(2), () {});
    calls[0].ok(degraded: true);
    await pumpEventQueue();
    expect(changes, 1);
    expect(t.peek(_a(1)), isNotNull);
    expect(calls.where((c) => c.full), isEmpty, reason: 'вторая ещё грузится');
    calls[1].ok();
    await pumpEventQueue();
    final full = calls.where((c) => c.full).single;
    expect(full.asset.id, 'id1');
    full.ok(size: 20);
    await pumpEventQueue();
    expect(changes, 2);
    expect(t.peek(_a(1))!.length, 20);
  });

  test('быстрой нет (только iCloud) — сразу чёткая; нет и её — «битая», но '
      'при новом показе пробуем снова', () async {
    final t = make();
    void cb() {}
    t.watch(_a(1), cb);
    calls.single.none();
    await pumpEventQueue();
    expect(calls.last.full, isTrue);
    calls.last.none();
    await pumpEventQueue();
    expect(t.failed(_a(1)), isTrue);
    t
      ..unwatch(_a(1), cb)
      ..watch(_a(1), cb);
    await pumpEventQueue();
    expect(calls, hasLength(3));
    calls.last.ok();
    await pumpEventQueue();
    expect(t.failed(_a(1)), isFalse);
  });

  test('ошибка и зависший ответ не занимают место в очереди навсегда', () async {
    final t = GalleryThumbs(
      fetch: (asset, {required full}) async =>
          asset.id == 'id1' ? throw StateError('x') : (data: Uint8List(3), degraded: false),
    );
    t.watch(_a(1), () {});
    for (var i = 2; i < 12; i++) {
      t.watch(_a(i), () {});
    }
    await pumpEventQueue();
    expect([for (var i = 2; i < 12; i++) t.peek(_a(i))], everyElement(isNotNull));
  });

  test('память: сверх предела уходит давнее, видимое остаётся; правка снимка '
      '— новая миниатюра', () async {
    final t = make(maxBytes: 25);
    void cb() {}
    for (var i = 0; i < 4; i++) {
      t.watch(_a(i), cb);
      calls.last.ok();
      await pumpEventQueue();
      if (i < 3) t.unwatch(_a(i), cb);
    }
    expect(t.cachedBytes, lessThanOrEqualTo(25));
    expect(t.peek(_a(0)), isNull);
    expect(t.peek(_a(3)), isNotNull);
    expect(t.peek(_a(3, mod: 2)), isNull);
  });

  test('bytes: один future на данные; ждущие получают картинку', () async {
    final t = make();
    final f = t.bytes(_a(1));
    expect(identical(f, t.bytes(_a(1))), isTrue);
    calls.single.ok();
    expect(await f, isNotNull);
    expect(identical(t.bytes(_a(1)), t.bytes(_a(1))), isTrue);
  });

  testWidgets('клетка: до картинки — заливка без крутилки', (t) async {
    final g = make();
    await t.pumpWidget(
      MaterialApp(home: GalleryThumbView(asset: _a(1), thumbs: g)),
    );
    expect(find.byType(ColoredBox), findsWidgets);
    expect(find.byType(Image), findsNothing);
    expect(t.hasRunningAnimations, isFalse);
    await t.pumpWidget(const SizedBox());
    calls.single.none();
    await t.pump(const Duration(seconds: 31));
  });

  group('страница из памяти', () {
    final old = [_a(1), _a(2), _a(3)];
    test('то же самое — сетку не трогаем', () {
      expect(
        mergeGalleryPages(shown: [...old, _a(9)], oldFirst: old, fresh: [...old]),
        isNull,
      );
    });
    test('новое — наверх, удалённое — вон, подгруженное ниже остаётся', () {
      final m = mergeGalleryPages(
        shown: [...old, _a(9)],
        oldFirst: old,
        fresh: [_a(0), _a(1), _a(3)],
      )!;
      expect(m.map((a) => a.id), ['id0', 'id1', 'id3', 'id9']);
    });
  });

  test('🔴 показ не ждёт альбомов и счётчиков; камера — после выезда листа', () {
    final s = File('lib/ui/chat_attachment_picker_sheet.dart').readAsStringSync();
    final at = s.indexOf('Future<void> _loadGalleryAssets()');
    final body = s.substring(at, s.indexOf('Future<void> _resolveFilterPaths()'));
    expect(body.contains('assetCountAsync'), isFalse);
    expect('getAssetPathList('.allMatches(body).length, 1);
    expect(s.contains('identical(_galleryAlbum, _lastRecentAlbum)'), isTrue);
    final init = s.substring(s.indexOf('  void initState() {'), s.indexOf('void _watchSheetSettled'));
    expect(init.contains('_initializeCameraPreview'), isFalse);
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final ch = swift.substring(swift.indexOf('private func attachGalleryThumbsChannel'));
    expect(ch.indexOf('work.async'), greaterThan(0));
    expect(swift.contains('attachGalleryThumbsChannel(messenger)'), isTrue);
  });
}
