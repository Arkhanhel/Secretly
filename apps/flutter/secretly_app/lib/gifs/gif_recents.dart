// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// Недавно выбранные гифки — «последние выбранные вверху, не больше восьми».
///
/// 🔴 ГДЕ ЭТО ЛЕЖИТ И ПОЧЕМУ. В `local_kv` шифрованной базы, а не в системных
/// настройках. Список выбранных гифок — это по сути список отправленных
/// сообщений: он говорит, что человек посылал и кому мог посылать. Держать такое
/// в открытом виде рядом с мессенджером, который шифрует всё остальное, было бы
/// непоследовательно. Недавние стикеры лежат в базе по той же причине.
///
/// Новой таблицы нет намеренно: миграция схемы ради восьми ссылок — риск,
/// несоразмерный задаче, а в проекте уже есть решение «храним в `local_kv`,
/// а не отдельной таблицей».
library;

import 'dart:convert';

/// Одна запомненная гифка.
class RecentGif {
  const RecentGif({required this.previewUrl, required this.fullUrl});

  /// Маленькая анимированная превьюшка для сетки.
  final String previewUrl;

  /// Полная гифка — то, что уедет сообщением.
  final String fullUrl;

  @override
  bool operator ==(Object other) =>
      other is RecentGif &&
      other.previewUrl == previewUrl &&
      other.fullUrl == fullUrl;

  @override
  int get hashCode => Object.hash(previewUrl, fullUrl);
}

/// Сколько недавних держим. Столько же и показываем.
const int kRecentGifLimit = 8;

/// Ключ в `local_kv`. Профиль в ключе обязателен: база одна на все профили
/// устройства, и без профиля недавние одного человека показались бы другому.
String recentGifsKvKey(String profileId) => 'gifrec:${profileId.trim()}';

/// Только `https` и только непустое.
///
/// Проверка не паранойя, а граница: значение приходит из хранилища, а всё, что
/// пришло из хранилища, могло быть записано старой сборкой или испорчено. Отдать
/// такую строку в загрузчик картинок или в отправку значило бы доверять данным
/// больше, чем коду.
bool _looksUsable(String url) {
  final u = url.trim();
  if (u.isEmpty || u.length > 2048) return false;
  return u.startsWith('https://');
}

/// Разбирает то, что лежит в хранилище.
///
/// 🔴 НИКОГДА НЕ БРОСАЕТ. Недавние — украшение; испорченная запись обязана
/// стоить пустой полосы «Недавние», а не неоткрывающегося подборщика.
List<RecentGif> decodeRecentGifs(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return const <RecentGif>[];
  try {
    final decoded = jsonDecode(text);
    if (decoded is! List) return const <RecentGif>[];
    final out = <RecentGif>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final preview = (entry['p'] as String?) ?? '';
      final full = (entry['f'] as String?) ?? '';
      if (!_looksUsable(preview) || !_looksUsable(full)) continue;
      final gif = RecentGif(previewUrl: preview.trim(), fullUrl: full.trim());
      if (out.contains(gif)) continue;
      out.add(gif);
      if (out.length >= kRecentGifLimit) break;
    }
    return List<RecentGif>.unmodifiable(out);
  } catch (_) {
    return const <RecentGif>[];
  }
}

/// Собирает то, что положим в хранилище.
String encodeRecentGifs(List<RecentGif> gifs) {
  final list = <Map<String, String>>[];
  for (final gif in gifs) {
    if (!_looksUsable(gif.previewUrl) || !_looksUsable(gif.fullUrl)) continue;
    list.add(<String, String>{
      'p': gif.previewUrl.trim(),
      'f': gif.fullUrl.trim(),
    });
    if (list.length >= kRecentGifLimit) break;
  }
  return jsonEncode(list);
}

/// Новый список после выбора гифки.
///
/// Выбранная встаёт первой; повтор поднимается наверх, а не заводит вторую
/// запись — иначе восемь мест займут четыре любимые гифки, и полоса перестанет
/// показывать недавнее.
///
/// Одинаковыми считаем по полной ссылке: превьюшку GIPHY может отдать в разных
/// размерах для одной и той же гифки, и тогда дубли прошли бы мимо проверки.
List<RecentGif> withRecentGif(
  List<RecentGif> current,
  RecentGif picked, {
  int max = kRecentGifLimit,
}) {
  if (!_looksUsable(picked.previewUrl) || !_looksUsable(picked.fullUrl)) {
    // Нечего запоминать — отдаём список без изменений, а не роняем выбор.
    return List<RecentGif>.unmodifiable(current);
  }
  final normalized = RecentGif(
    previewUrl: picked.previewUrl.trim(),
    fullUrl: picked.fullUrl.trim(),
  );
  final out = <RecentGif>[normalized];
  for (final gif in current) {
    if (gif.fullUrl.trim() == normalized.fullUrl) continue;
    if (!_looksUsable(gif.previewUrl) || !_looksUsable(gif.fullUrl)) continue;
    out.add(gif);
    if (out.length >= max) break;
  }
  return List<RecentGif>.unmodifiable(out);
}
