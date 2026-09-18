// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Обращение к GIPHY: ключ, страница выдачи и сам запрос.
///
/// 🔴 ЗАЧЕМ ОТДЕЛЬНЫЙ ФАЙЛ, ЕСЛИ У ТЕЛЕФОНА ЭТО УЖЕ ЕСТЬ.
///
/// Есть — но внутри `lib/ui/chat_screen.dart`, приватным `_fetchGifPage` среди
/// тридцати двух тысяч строк. Мобильная версия ВЫПУЩЕНА и заморожена: её
/// правят только по прямому указанию владельца, и вытаскивать оттуда сотню
/// строк ради компьютера — риск, несоразмерный выгоде.
///
/// Поэтому здесь ТА ЖЕ логика, но общим кодом, и пользуется ею пока только
/// окно на компьютере. Когда телефон разморозят, его копию надо снести и
/// оставить эту одну — в том виде, в каком лежит здесь, разночтений между ними
/// нет: те же имена картинок, тот же счёт курсора, то же отличие «нет связи»
/// от «ничего не нашлось».
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Ключ GIPHY. Кладётся при сборке:
/// `--dart-define=GIPHY_API_KEY=…` (см. `tools/desktop_build_macos.sh`).
///
/// Без ключа сетка просто пуста — мёртвых запросов не шлём.
const String kGiphyApiKey = String.fromEnvironment(
  'GIPHY_API_KEY',
  defaultValue: '',
);

/// Одна гифка: мелкая для сетки, полная для отправки.
class GifItem {
  const GifItem({required this.previewUrl, required this.fullUrl});

  /// Небольшая анимированная картинка для сетки подборщика.
  final String previewUrl;

  /// Полная гифка — её и отправляют.
  final String fullUrl;
}

/// Одна страница выдачи.
class GifPage {
  const GifPage({
    required this.items,
    required this.hasMore,
    required this.returned,
  }) : failed = false;

  const GifPage.failed()
      : items = const <GifItem>[],
        hasMore = false,
        returned = 0,
        failed = true;

  static const GifPage empty = GifPage(
    items: <GifItem>[],
    hasMore: false,
    returned: 0,
  );

  final List<GifItem> items;

  /// Сколько записей отдал GIPHY — ВКЛЮЧАЯ отброшенные.
  ///
  /// 🔴 КУРСОР СЧИТАЕТСЯ ПО ЭТОМУ ЧИСЛУ, А НЕ ПО ДЛИНЕ [items]. Часть записей
  /// приходит без пригодных ссылок, и мы их выбрасываем. Сдвигать курсор по
  /// оставшимся значит начать следующую страницу раньше, чем кончилась
  /// предыдущая: выдача повторится, список перестанет расти, а запросы
  /// продолжатся.
  final int returned;

  /// Есть ли что грузить дальше.
  final bool hasMore;

  /// 🔴 ОТЛИЧАЕТСЯ ОТ ПУСТОГО РЕЗУЛЬТАТА НАМЕРЕННО. «Нет связи» и «ничего не
  /// нашлось» — разные причины и разные действия человека: первое лечится
  /// повтором, второе — другим словом. Одно сообщение на оба случая врёт.
  final bool failed;
}

/// Сколько просим за один раз.
const int kGifPageSize = 30;

/// Потолок накопленного списка. Каждая гифка в сетке — кадры в памяти.
const int kGifMaxItems = 180;

/// За сколько до конца начинаем подгружать следующую страницу — расстоянием,
/// а не «доскроллил до дна»: страница должна успеть приехать.
const double kGifPrefetchExtent = 700;

/// Страница выдачи: подборка дня без слова, поиск со словом.
Future<GifPage> fetchGifPage({
  String? query,
  String lang = 'en',
  int offset = 0,
  int limit = kGifPageSize,
  http.Client? client,
}) async {
  if (kGiphyApiKey.isEmpty) return GifPage.empty;
  final q = (query ?? '').trim();
  final base = q.isEmpty
      ? 'https://api.giphy.com/v1/gifs/trending'
      : 'https://api.giphy.com/v1/gifs/search';
  final uri = Uri.parse(base).replace(
    queryParameters: <String, String>{
      'api_key': kGiphyApiKey,
      'limit': '$limit',
      if (offset > 0) 'offset': '$offset',
      'rating': 'pg-13',
      // Язык запроса. Без него русское слово уходит в английский индекс и
      // возвращает пустоту — тот самый «поиск только на английском».
      'lang': lang,
      if (q.isNotEmpty) 'q': q,
    },
  );
  final http = client;
  try {
    final resp = http == null
        ? await _get(uri)
        : await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) return const GifPage.failed();
    return parseGifPage(resp.body, offset: offset, limit: limit);
  } catch (_) {
    return const GifPage.failed();
  }
}

Future<http.Response> _get(Uri uri) =>
    http.get(uri).timeout(const Duration(seconds: 8));

/// Разбор ответа отдельно от сети — это и есть то, что стоит проверять.
GifPage parseGifPage(String body, {required int offset, required int limit}) {
  final Map<String, dynamic> decoded;
  try {
    decoded = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return const GifPage.failed();
  }
  final results = (decoded['data'] as List?) ?? const [];
  final out = <GifItem>[];

  String? urlOf(Map images, String key) {
    final r = images[key];
    if (r is Map) {
      final u = r['url'];
      if (u is String && u.isNotEmpty) return u;
    }
    return null;
  }

  for (final item in results) {
    try {
      final images = (item as Map)['images'] as Map?;
      if (images == null) continue;
      final preview = urlOf(images, 'fixed_width_downsampled') ??
          urlOf(images, 'fixed_width_small') ??
          urlOf(images, 'preview_gif') ??
          urlOf(images, 'fixed_width');
      // Полная, но с потолком размера: `downsized_medium` ≈ до 5 МБ.
      final full = urlOf(images, 'downsized_medium') ??
          urlOf(images, 'downsized') ??
          urlOf(images, 'original') ??
          urlOf(images, 'fixed_width');
      if (preview == null || full == null) continue;
      out.add(GifItem(previewUrl: preview, fullUrl: full));
    } catch (_) {
      continue;
    }
  }

  int? total;
  int? count;
  final pagination = decoded['pagination'];
  if (pagination is Map) {
    total = (pagination['total_count'] as num?)?.toInt();
    count = (pagination['count'] as num?)?.toInt();
  }
  final returned = count ?? results.length;
  final hasMore = (total != null && total > 0)
      ? (offset + returned) < total
      : results.length >= limit;
  return GifPage(items: out, hasMore: hasMore, returned: returned);
}
