// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Откуда панель берёт стикеры и GIF.
///
/// Панель не знает про [AppController] напрямую: ей отдают источник. Боевой
/// источник — тонкая обёртка над теми же вызовами, что у прежнего листа
/// (`SecretlyStickerPickerTab`, `_GifPickerView` в `chat_screen.dart`), тест —
/// подделку без базы и сети.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http_pkg;

import '../../../app/app_controller.dart';
import '../../../gifs/gif_query.dart';
import '../../../stickers/sticker_catalog.dart';
import '../../widgets/secretly_sticker_widgets.dart'
    show showSecretlyStickerPackEditor;

// ─── Стикеры ────────────────────────────────────────────────────────────────

/// Всё, что панели нужно от стикеров.
abstract class EmojiPanelStickerSource {
  /// Профиль: свои наборы — `user:<profileId>:…`, «Избранное» —
  /// `user:<profileId>:favorites`.
  String get profileId;

  String get favoritesPackId => 'user:$profileId:favorites';

  Future<List<SecretlyStickerDescriptor>> loadRecent();

  /// Наборы панели — те же, что у прежнего листа (флаги закрытых наборов и
  /// установленных учитывает сам контроллер).
  Future<List<SecretlyStickerPack>> loadPacks({bool refresh = true});

  /// Поиск по словам стикеров (общий каталог).
  List<SecretlyStickerDescriptor> search(String query) =>
      SecretlyStickerCatalog.search(query);

  bool isFavorite(String stickerId);
  bool isPackBusy(SecretlyStickerPack pack);
  Future<void> addFavorite(
    SecretlyStickerDescriptor sticker, {
    required String favoritesTitle,
  });
  Future<void> removeFavorite(String stickerId);
  Future<void> setCover({required String packId, required String stickerId});
  Future<void> deleteFromPack({
    required String packId,
    required String stickerId,
  });
  Future<void> uninstallPack(SecretlyStickerPack pack);
  Future<void> deleteUserPack(String packId);

  /// ⚙ своего набора — окно набора целиком.
  Future<void> openPackEditor(
    BuildContext context,
    SecretlyStickerPack pack, {
    VoidCallback? onAddSticker,
  });
}

/// Боевой источник: те же вызовы контроллера, что у ленты стикеров.
class AppControllerStickerSource extends EmojiPanelStickerSource {
  AppControllerStickerSource(this.controller);

  final AppController controller;

  @override
  String get profileId => controller.profileId;

  @override
  Future<List<SecretlyStickerDescriptor>> loadRecent() =>
      controller.loadRecentStickers(limit: 20);

  @override
  Future<List<SecretlyStickerPack>> loadPacks({bool refresh = true}) =>
      controller.loadStickerPickerPacks(refresh: refresh);

  @override
  bool isFavorite(String stickerId) => controller.isStickerFavorite(stickerId);

  @override
  bool isPackBusy(SecretlyStickerPack pack) =>
      controller.isStickerPackBusy(packId: pack.id, packVersion: pack.version);

  @override
  Future<void> addFavorite(
    SecretlyStickerDescriptor sticker, {
    required String favoritesTitle,
  }) => controller.addStickerToFavorites(
    sticker,
    favoritesTitle: favoritesTitle,
  );

  @override
  Future<void> removeFavorite(String stickerId) =>
      controller.removeStickerFromFavorites(stickerId);

  @override
  Future<void> setCover({required String packId, required String stickerId}) =>
      controller.setUserStickerPackCover(packId: packId, stickerId: stickerId);

  @override
  Future<void> deleteFromPack({
    required String packId,
    required String stickerId,
  }) => controller.deleteUserStickerFromPack(
    packId: packId,
    stickerId: stickerId,
  );

  @override
  Future<void> uninstallPack(SecretlyStickerPack pack) => controller
      .uninstallStickerPack(packId: pack.id, packVersion: pack.version);

  @override
  Future<void> deleteUserPack(String packId) =>
      controller.deleteUserStickerPack(packId);

  @override
  Future<void> openPackEditor(
    BuildContext context,
    SecretlyStickerPack pack, {
    VoidCallback? onAddSticker,
  }) => showSecretlyStickerPackEditor(
    context,
    controller: controller,
    pack: pack,
    onAddSticker: onAddSticker,
  );
}

// ─── GIF ────────────────────────────────────────────────────────────────────

/// Одна гифка панели: превью для сетки, полная — для отправки, пропорция.
class PanelGif {
  const PanelGif({
    required this.previewUrl,
    required this.fullUrl,
    this.aspect,
  });

  final String previewUrl;
  final String fullUrl;

  /// Ширина / высота превью из данных GIPHY; `null` — неизвестна (недавние).
  final double? aspect;
}

/// Страница выдачи.
class PanelGifPage {
  const PanelGifPage({
    required this.items,
    required this.hasMore,
    required this.returned,
  }) : failed = false;

  const PanelGifPage.failed()
    : items = const <PanelGif>[],
      hasMore = false,
      returned = 0,
      failed = true;

  static const PanelGifPage empty = PanelGifPage(
    items: <PanelGif>[],
    hasMore: false,
    returned: 0,
  );

  final List<PanelGif> items;
  final bool hasMore;

  /// Сколько записей отдал GIPHY — курсор двигается по нему, а не по длине
  /// [items] (часть записей отбрасывается, см. `_GifPage` в `chat_screen`).
  final int returned;

  /// «Нет связи» — не то же, что «ничего не нашлось».
  final bool failed;
}

/// Всё, что панели нужно от GIF.
abstract class EmojiPanelGifSource {
  /// Без ключа GIPHY сетка просто пуста.
  bool get available;

  Future<PanelGifPage> fetch({String? query, String lang = 'en', int offset = 0});

  Future<List<PanelGif>> loadRecents();

  /// Запомнить выбранную — в момент выбора, как прежний лист.
  Future<void> remember(PanelGif gif);

  /// Картинка превью для сетки (по умолчанию — из сети).
  ImageProvider previewImage(PanelGif gif) => NetworkImage(gif.previewUrl);
}

/// Сколько просим за раз, потолок списка, запас до подгрузки — те же числа,
/// что у прежнего листа (`_gifPageSize`, `_gifMaxItems`, `_gifPrefetchExtent`).
const int kPanelGifPageSize = 30;
const int kPanelGifMaxItems = 180;
const double kPanelGifPrefetchExtent = 700;

/// Тот же ключ, что у прежнего листа (`--dart-define=GIPHY_API_KEY=…`).
const String _panelGiphyKey = String.fromEnvironment(
  'GIPHY_API_KEY',
  defaultValue: '',
);

/// Боевой источник: GIPHY + недавние из шифрованной базы профиля.
class GiphyPanelGifSource extends EmojiPanelGifSource {
  GiphyPanelGifSource(this.controller);

  final AppController controller;

  /// Пропорции гифок, увиденных в этой сессии, — по ним недавние тоже
  /// ложатся своими размерами.
  static final Map<String, double> _aspectByUrl = <String, double>{};

  @override
  bool get available => _panelGiphyKey.isNotEmpty;

  @override
  Future<List<PanelGif>> loadRecents() async {
    final recents = await controller.loadRecentGifs();
    return [
      for (final r in recents)
        PanelGif(
          previewUrl: r.previewUrl,
          fullUrl: r.fullUrl,
          aspect: _aspectByUrl[r.fullUrl],
        ),
    ];
  }

  @override
  Future<void> remember(PanelGif gif) => controller.rememberPickedGif(
    previewUrl: gif.previewUrl,
    fullUrl: gif.fullUrl,
  );

  @override
  Future<PanelGifPage> fetch({
    String? query,
    String lang = 'en',
    int offset = 0,
  }) async {
    if (!available) return PanelGifPage.empty;
    final page = await fetchGiphyPanelPage(
      apiKey: _panelGiphyKey,
      query: query,
      lang: lang,
      offset: offset,
    );
    for (final g in page.items) {
      final a = g.aspect;
      if (a != null) _aspectByUrl[g.fullUrl] = a;
    }
    return page;
  }
}

/// Запрос к GIPHY — как `_fetchGifPage` прежнего листа, но ещё с размерами
/// превью: без них «тетрис» не уложить.
Future<PanelGifPage> fetchGiphyPanelPage({
  required String apiKey,
  String? query,
  String lang = 'en',
  int offset = 0,
  int limit = kPanelGifPageSize,
  http_pkg.Client? client,
}) async {
  if (apiKey.isEmpty) return PanelGifPage.empty;
  final q = (query ?? '').trim();
  final base = q.isEmpty
      ? 'https://api.giphy.com/v1/gifs/trending'
      : 'https://api.giphy.com/v1/gifs/search';
  final uri = Uri.parse(base).replace(
    queryParameters: {
      'api_key': apiKey,
      'limit': '$limit',
      if (offset > 0) 'offset': '$offset',
      'rating': 'pg-13',
      'lang': lang,
      if (q.isNotEmpty) 'q': q,
    },
  );
  try {
    final get = client?.get ?? http_pkg.get;
    final resp = await get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) return const PanelGifPage.failed();
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = (body['data'] as List?) ?? const <Object?>[];
    final out = <PanelGif>[];
    for (final item in results) {
      final parsed = parseGiphyPanelItem(item);
      if (parsed != null) out.add(parsed);
    }
    int? total;
    int? count;
    final pagination = body['pagination'];
    if (pagination is Map) {
      total = (pagination['total_count'] as num?)?.toInt();
      count = (pagination['count'] as num?)?.toInt();
    }
    final returned = count ?? results.length;
    final hasMore = (total != null && total > 0)
        ? (offset + returned) < total
        : results.length >= limit;
    return PanelGifPage(items: out, hasMore: hasMore, returned: returned);
  } catch (_) {
    return const PanelGifPage.failed();
  }
}

/// Одна запись GIPHY → [PanelGif] (те же исполнения, что у прежнего листа).
PanelGif? parseGiphyPanelItem(Object? item) {
  try {
    final images = (item as Map)['images'] as Map?;
    if (images == null) return null;
    ({String url, double? aspect})? pick(String key) {
      final r = images[key];
      if (r is! Map) return null;
      final u = r['url'];
      if (u is! String || u.isEmpty) return null;
      final w = double.tryParse('${r['width'] ?? ''}');
      final h = double.tryParse('${r['height'] ?? ''}');
      final a = (w != null && h != null && w > 0 && h > 0) ? w / h : null;
      return (url: u, aspect: a);
    }

    final preview =
        pick('fixed_width_downsampled') ??
        pick('fixed_width_small') ??
        pick('preview_gif') ??
        pick('fixed_width');
    final full =
        pick('downsized_medium') ??
        pick('downsized') ??
        pick('original') ??
        pick('fixed_width');
    if (preview == null || full == null) return null;
    return PanelGif(
      previewUrl: preview.url,
      fullUrl: full.url,
      aspect: preview.aspect ?? full.aspect,
    );
  } catch (_) {
    return null;
  }
}

/// План запроса (слово → английский/русский индекс) — тот же, что у листа.
List<GifQueryAttempt> panelGifQueryPlan(String raw) => gifQueryPlan(raw);
