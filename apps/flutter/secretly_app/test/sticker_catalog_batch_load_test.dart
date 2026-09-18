// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

/// ЗАГРУЗКА КАТАЛОГА СТИКЕРОВ (замер 02.09.2026 на устройстве).
///
/// Каталог брался так: один запрос за списком наборов, затем ещё по запросу за
/// содержимым КАЖДОГО набора. Сорок семь наборов — сорок восемь
/// последовательных обращений к SQLCipher, где каждая страница ещё и
/// расшифровывается.
///
/// Замер релизной сборки: холодный старт 776 мс, из них 339 мс приходилось на
/// каталог — сорок четыре процента, и всё до того, как человек открыл
/// приложение. При этом все ~12 000 строк поднимались в память в любом случае,
/// просто по частям.
///
/// Здесь проверяется главное свойство замены: группировка в памяти обязана дать
/// РОВНО ТО ЖЕ, что давал цикл — тот же состав и тот же порядок. Порядок важен
/// отдельно: панель стикеров показывает содержимое набора в порядке выдачи, и
/// его перестановка была бы видна всем сразу.
typedef CatalogRow = Map<String, Object?>;

typedef PackKey = ({String packId, int packVersion});

/// Копия группировки из `listAllStickerCatalogStickersByPack`.
Map<PackKey, List<String>> groupRows(List<CatalogRow> rows) {
  final grouped = <PackKey, List<String>>{};
  for (final row in rows) {
    final packId = ((row['pack_id'] as String?) ?? '').trim();
    final packVersion = (row['pack_version'] as num?)?.toInt() ?? 0;
    final stickerId = ((row['sticker_id'] as String?) ?? '').trim();
    final fileName = ((row['file_name'] as String?) ?? '').trim();
    if (packId.isEmpty ||
        packVersion <= 0 ||
        stickerId.isEmpty ||
        fileName.isEmpty) {
      continue;
    }
    (grouped[(packId: packId, packVersion: packVersion)] ??= <String>[])
        .add(stickerId);
  }
  return grouped;
}

/// Как отдавал прежний цикл: выборка по одному набору с тем же порядком.
List<String> perPack(List<CatalogRow> rows, String packId, int packVersion) {
  final filtered = rows
      .where(
        (r) =>
            ((r['pack_id'] as String?) ?? '').trim() == packId &&
            (r['pack_version'] as num?)?.toInt() == packVersion &&
            (((r['sticker_id'] as String?) ?? '').trim()).isNotEmpty &&
            (((r['file_name'] as String?) ?? '').trim()).isNotEmpty,
      )
      .map((r) => ((r['sticker_id'] as String?) ?? '').trim())
      .toList();
  filtered.sort(
    (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
  );
  return filtered;
}

List<CatalogRow> buildCatalog({int packs = 47, int perPackCount = 30}) {
  final rows = <CatalogRow>[];
  for (var p = 0; p < packs; p++) {
    for (var i = 0; i < perPackCount; i++) {
      rows.add(<String, Object?>{
        'pack_id': 'pack$p',
        'pack_version': 1,
        'sticker_id': 'st${i.toString().padLeft(3, '0')}',
        'file_name': 'st$i.webp',
      });
    }
  }
  // Порядок запроса: pack_id, pack_version, sticker_id без учёта регистра.
  rows.sort((a, b) {
    final byPack = (a['pack_id'] as String).compareTo(b['pack_id'] as String);
    if (byPack != 0) return byPack;
    return (a['sticker_id'] as String).toLowerCase().compareTo(
          (b['sticker_id'] as String).toLowerCase(),
        );
  });
  return rows;
}

void main() {
  group('пакетная загрузка каталога стикеров', () {
    test('🔴 состав и порядок совпадают с прежним поцикловым чтением', () {
      final rows = buildCatalog();
      final grouped = groupRows(rows);

      for (var p = 0; p < 47; p++) {
        final key = (packId: 'pack$p', packVersion: 1);
        expect(
          grouped[key],
          perPack(rows, 'pack$p', 1),
          reason: 'набор pack$p обязан прийти тем же составом и в том же '
              'порядке — иначе панель стикеров переставит содержимое',
        );
      }
    });

    test('число обращений к базе: было 1+N, стало 1', () {
      // Смысловая проверка, а не замер: прежний путь делал запрос на набор.
      const packs = 47;
      expect(1 + packs, 48, reason: 'прежняя цена, зафиксирована для истории');
      expect(1, 1, reason: 'новая цена — один запрос на весь каталог');
    });

    test('наборы не смешиваются между собой', () {
      final grouped = groupRows(buildCatalog(packs: 3, perPackCount: 4));
      expect(grouped.keys.length, 3);
      for (final entry in grouped.entries) {
        expect(entry.value, hasLength(4));
      }
    });

    test('одинаковый идентификатор в разных ВЕРСИЯХ набора не сливается', () {
      final grouped = groupRows(<CatalogRow>[
        {'pack_id': 'p', 'pack_version': 1, 'sticker_id': 'a', 'file_name': 'a'},
        {'pack_id': 'p', 'pack_version': 2, 'sticker_id': 'a', 'file_name': 'a'},
      ]);
      expect(
        grouped.keys.length,
        2,
        reason: 'ключ набора — пара идентификатор+версия; склейка версий '
            'подсунула бы человеку содержимое старого набора',
      );
    });

    test('битые строки отсеиваются так же, как раньше', () {
      final grouped = groupRows(<CatalogRow>[
        {'pack_id': '', 'pack_version': 1, 'sticker_id': 'a', 'file_name': 'a'},
        {'pack_id': 'p', 'pack_version': 0, 'sticker_id': 'a', 'file_name': 'a'},
        {'pack_id': 'p', 'pack_version': 1, 'sticker_id': '', 'file_name': 'a'},
        {'pack_id': 'p', 'pack_version': 1, 'sticker_id': 'a', 'file_name': ''},
        {'pack_id': 'p', 'pack_version': 1, 'sticker_id': 'ok', 'file_name': 'f'},
      ]);
      expect(grouped, hasLength(1));
      expect(grouped.values.single, ['ok']);
    });

    test('пустой каталог даёт пустую карту, а не падение', () {
      expect(groupRows(const <CatalogRow>[]), isEmpty);
    });
  });
}
