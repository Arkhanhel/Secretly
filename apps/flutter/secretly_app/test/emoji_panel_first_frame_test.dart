// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Панель стикеров не «моргает» при открытии: первый кадр уже полный
// (24.11.2026, снимки владельца).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/stickers/premium_sticker_packs.dart';
import 'package:secretly_app/stickers/sticker_catalog.dart';
import 'package:secretly_app/ui/chat/emoji_panel/emoji_panel_sources.dart';
import 'package:secretly_app/ui/chat/emoji_panel/emoji_panel_stickers.dart';

class _Source extends EmojiPanelStickerSource {
  _Source(this.key);

  final String key;
  List<SecretlyStickerPack> packs = [kidsStickerPack];
  List<SecretlyStickerDescriptor> recent = [kidsStickerPack.stickers.first];
  Completer<void>? network;
  int loads = 0;

  @override
  String get profileId => key;
  @override
  String? get cacheKey => key;
  @override
  List<SecretlyStickerPack>? packsNow() => packs;
  @override
  List<SecretlyStickerPack> premiumPacks() => premiumStickerPacks;
  @override
  Future<List<SecretlyStickerDescriptor>> loadRecent() async => recent;
  @override
  Future<List<SecretlyStickerPack>> loadPacks({bool refresh = true}) async {
    loads++;
    if (refresh) await network?.future;
    return packs;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('🔴 недавние прочитаны заранее — первый кадр полный, сеть не ждём', () async {
    final src = _Source('P1')..network = Completer<void>();
    await StickerTabModel.warmUp(src);
    final m = StickerTabModel(source: src, canCreate: true);
    // Ни одного ожидания: ровно то, что увидит первый кадр.
    expect(m.recents, hasLength(1));
    expect(m.packs.map((p) => p.id), [kidsStickerPack.id]);
    expect(m.premium, hasLength(2));
    expect(m.loading, isFalse);

    var updates = 0;
    m.addListener(() => updates++);
    await pumpEventQueue();
    expect(updates, 1, reason: 'одно обновление из локального');
    src.network!.complete();
    await pumpEventQueue();
    expect(updates, 1, reason: 'каталог тот же — сетку не трогаем');
    m.dispose();
    await pumpEventQueue();
  });

  test('с сервера пришёл новый набор — он появляется, недавние не '
      'переставляются', () async {
    final src = _Source('P2')..network = Completer<void>();
    await StickerTabModel.warmUp(src);
    final m = StickerTabModel(source: src, canCreate: true);
    await pumpEventQueue();
    src
      ..recent = [kidsStickerPack.stickers[1], kidsStickerPack.stickers.first]
      ..packs = const <SecretlyStickerPack>[];
    src.network!.complete();
    await pumpEventQueue();
    expect(m.packs, isEmpty);
    expect(m.recents, hasLength(1));
    m.dispose();
    await pumpEventQueue();
    // Закрыли — следующий показ начнётся с новых недавних.
    final next = StickerTabModel(source: src, canCreate: true);
    expect(next.recents, hasLength(2));
    next.dispose();
  });

  test('первое открытие без подготовки: наборы сразу, недавние — следом', () async {
    final src = _Source('P3');
    final m = StickerTabModel(source: src, canCreate: true);
    expect(m.packs, hasLength(1));
    await pumpEventQueue();
    expect(m.recents, hasLength(1));
    m.dispose();
    await pumpEventQueue();
  });
}
