// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Место открытия чата (23.11.2026, как у Telegram): чистые правила, без
/// виджетов — экран берёт их отсюда, тесты проверяют здесь.
library;

/// Строка ленты для выбора первого непрочитанного.
typedef OpenPositionRow = ({
  String rowId,
  bool isMe,

  /// Все id строки: событие, payload, кадры альбома.
  List<String> ids,
});

/// Самая СТАРАЯ входящая строка, у которой хоть один id — среди
/// непрочитанных [unreadIds]. [rowsNewestFirst] — лента как на экране
/// (новые первыми). `null` — непрочитанных в ленте нет.
String? firstUnreadRowId(
  List<OpenPositionRow> rowsNewestFirst,
  Set<String> unreadIds,
) {
  if (unreadIds.isEmpty) return null;
  for (var t = rowsNewestFirst.length - 1; t >= 0; t--) {
    final row = rowsNewestFirst[t];
    if (row.isMe) continue;
    for (final id in row.ids) {
      if (id.isNotEmpty && unreadIds.contains(id)) return row.rowId;
    }
  }
  return null;
}

/// Смещение списка с `reverse: true`, при котором верх строки (сейчас на
/// [rowTop]) встанет на [desiredTop]. Больше смещение — лента ниже (видно
/// старое), поэтому строку, стоящую ниже нужного, поднимает МЕНЬШЕЕ
/// смещение. Результат зажат в [0, maxExtent]: строка у самого низа чата
/// просто остаётся там, где может.
double reversedListOffsetForRowTop({
  required double offset,
  required double rowTop,
  required double desiredTop,
  required double maxExtent,
}) {
  final target = offset - (rowTop - desiredTop);
  if (target < 0) return 0;
  if (target > maxExtent) return maxExtent;
  return target;
}
