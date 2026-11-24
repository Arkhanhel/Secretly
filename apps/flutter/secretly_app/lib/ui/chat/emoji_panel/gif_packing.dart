// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Укладка GIF «как тетрис» (слово владельца 22.11.2026): не две ровные
/// колонки, а три, где каждая гифка сохраняет свои пропорции, широкие
/// занимают две колонки, а плитки встают туда, где «горизонт» ниже всего.
///
/// Чистая функция без Flutter-виджетов — проверяется юнит-тестом
/// (`test/emoji_panel_test.dart`): плитки не пересекаются, не выходят за
/// края, широкие занимают ровно две колонки, высоты колонок выровнены.
library;

import 'dart:math' as math;
import 'dart:ui' show Rect;

/// Где лежит одна плитка.
class GifPlacement {
  const GifPlacement({
    required this.index,
    required this.column,
    required this.span,
    required this.rect,
  });

  /// Номер гифки во входном списке.
  final int index;

  /// Левая колонка плитки.
  final int column;

  /// Сколько колонок занимает (1 или 2).
  final int span;
  final Rect rect;
}

/// Итог укладки.
class GifPackResult {
  const GifPackResult({
    required this.tiles,
    required this.height,
    required this.columnHeights,
  });

  /// В порядке укладки (почти порядок выдачи — см. [packGifTiles]).
  final List<GifPlacement> tiles;

  /// Полная высота сетки.
  final double height;

  /// Низ каждой колонки (без последнего зазора).
  final List<double> columnHeights;

  static const GifPackResult empty = GifPackResult(
    tiles: <GifPlacement>[],
    height: 0,
    columnHeights: <double>[],
  );
}

/// С какой пропорции (ширина / высота) гифка считается широкой.
const double kGifWideAspect = 1.6;

/// Укладывает плитки с пропорциями [aspects] (ширина / высота) в [columns]
/// колонок общей шириной [width].
///
///  * Узкие и квадратные — одна колонка, широкие (≥ [wideAspect]) — две.
///  * «Горизонт» (skyline): плитка встаёт в самую низкую колонку, широкая —
///    в пару соседних колонок с самым низким верхом и наименьшей дырой под
///    собой.
///  * Из окна в [lookahead] следующих плиток встаёт та, что ляжет ниже всех
///    и без дыры: узкая, заполнившая низкую колонку, уходит вперёд. Порядок
///    выдачи сдвигается не дальше этого окна.
///  * Если третья колонка заметно ниже, а узких в окне нет, широкая ложится
///    в неё одна («другой стороной», чуть обрезана по бокам).
///  * Дыру под широкой плиткой закрывает вытянутая узкая соседка (не больше
///    чем на 35 % её высоты; картинка обрезается `BoxFit.cover`).
///  * Края «прилипают»: если низ плитки почти совпадает с низом соседней
///    колонки (ближе [snap]), высота чуть подгоняется (не больше ±12 %) —
///    картинка обрезается `BoxFit.cover`, а края встают ровно, как детали
///    пазла.
GifPackResult packGifTiles(
  List<double> aspects, {
  required double width,
  int columns = 3,
  double gap = 6,
  double wideAspect = kGifWideAspect,
  int lookahead = 3,
  double snap = 14,
}) {
  if (aspects.isEmpty || width <= 0 || columns <= 0) {
    return GifPackResult.empty;
  }
  final colW = (width - gap * (columns - 1)) / columns;
  // Верх свободного места в каждой колонке (с учётом зазора).
  final tops = List<double>.filled(columns, 0);
  final pending = <int>[for (var i = 0; i < aspects.length; i++) i];
  final out = <GifPlacement>[];

  int spanOf(int i) =>
      columns >= 2 && _sane(aspects[i]) >= wideAspect ? 2 : 1;

  double naturalHeight(int i, int span) {
    final w = colW * span + gap * (span - 1);
    // Очень высокие и очень плоские гифки обрезаются, а не ломают сетку.
    final a = _sane(aspects[i]).clamp(span == 2 ? 1.2 : 0.62, span == 2 ? 2.8 : 1.8);
    return w / a;
  }

  // Последняя узкая плитка каждой колонки (её можно чуть вытянуть, чтобы
  // закрыть дыру под широкой).
  final lastNarrow = List<int?>.filled(columns, null);

  // Насколько можно вытянуть последнюю узкую плитку колонки [k] до [y].
  bool canStretch(int k, double y) {
    final li = lastNarrow[k];
    if (li == null) return false;
    final r = out[li].rect;
    if ((r.bottom + gap - tops[k]).abs() > .5) return false;
    return (y - tops[k]) <= r.height * .35;
  }

  // Лучшее место для плитки: (колонка, верх, дыра под плиткой). Дыра, которую
  // закроет вытягивание соседки, дырой не считается.
  ({int col, double y, double waste, int span}) bestSlot(int span) {
    var bestCol = 0;
    var bestY = double.infinity;
    var bestWaste = double.infinity;
    for (var c = 0; c + span <= columns; c++) {
      var y = 0.0;
      for (var k = c; k < c + span; k++) {
        y = math.max(y, tops[k]);
      }
      var waste = 0.0;
      for (var k = c; k < c + span; k++) {
        final d = y - tops[k];
        if (d > .5 && !canStretch(k, y)) waste += d;
      }
      final score = y + waste;
      final best = bestY + bestWaste;
      if (score < best - 0.5 || (score - best).abs() <= 0.5 && y < bestY) {
        bestCol = c;
        bestY = y;
        bestWaste = waste;
      }
    }
    return (col: bestCol, y: bestY, waste: bestWaste, span: span);
  }

  ({int col, double y, double waste, int span}) slotFor(int i) =>
      bestSlot(spanOf(i));

  // Сколько раз первую в очереди обошли — дальше [lookahead] не обходим.
  final skipped = <int, int>{};

  while (pending.isNotEmpty) {
    // «Горизонт»: из окна очереди встаёт та плитка, что ляжет ниже всех и
    // без дыры; порядок выдачи сдвигается не дальше окна.
    var pick = 0;
    var slot = slotFor(pending[0]);
    if ((skipped[pending[0]] ?? 0) < lookahead) {
      final limit = math.min(pending.length, lookahead + 1);
      for (var j = 1; j < limit; j++) {
        final s = slotFor(pending[j]);
        if (s.y + s.waste < slot.y + slot.waste - 0.5) {
          pick = j;
          slot = s;
        }
      }
    }
    if (pick > 0) {
      for (var j = 0; j < pick; j++) {
        skipped[pending[j]] = (skipped[pending[j]] ?? 0) + 1;
      }
    }
    final i = pending.removeAt(pick);
    // Широкая, а одна колонка отстала больше чем на её высоту и узких в окне
    // нет (иначе встала бы узкая): широкая ложится в отставшую колонку одна —
    // «деталь, повёрнутая другой стороной», колонки не расходятся.
    if (slot.span == 2) {
      final low = tops.reduce(math.min);
      if (slot.y - low > naturalHeight(i, 2) * 1.1) slot = bestSlot(1);
    }
    final span = slot.span;
    // Дыры под широкой — закрываем, вытягивая узкую соседку.
    for (var k = slot.col; k < slot.col + span; k++) {
      if (slot.y - tops[k] > .5 && canStretch(k, slot.y)) {
        final li = lastNarrow[k]!;
        final r = out[li].rect;
        out[li] = GifPlacement(
          index: out[li].index,
          column: out[li].column,
          span: 1,
          rect: Rect.fromLTRB(r.left, r.top, r.right, slot.y - gap),
        );
        tops[k] = slot.y;
      }
    }
    final natural = naturalHeight(i, span);
    var bottom = slot.y + natural;
    // Прилипание к низу соседней колонки (слева или справа от плитки).
    final neighbours = <double>[
      if (slot.col > 0) tops[slot.col - 1] - gap,
      if (slot.col + span < columns) tops[slot.col + span] - gap,
    ];
    double? snapTo;
    for (final n in neighbours) {
      if (n <= slot.y) continue;
      final d = (bottom - n).abs();
      if (d <= snap &&
          (n - slot.y) >= natural * 0.88 &&
          (n - slot.y) <= natural * 1.12 &&
          (snapTo == null || d < (bottom - snapTo).abs())) {
        snapTo = n;
      }
    }
    if (snapTo != null) bottom = snapTo;
    final x = slot.col * (colW + gap);
    final w = colW * span + gap * (span - 1);
    out.add(
      GifPlacement(
        index: i,
        column: slot.col,
        span: span,
        rect: Rect.fromLTWH(x, slot.y, w, bottom - slot.y),
      ),
    );
    for (var k = slot.col; k < slot.col + span; k++) {
      tops[k] = bottom + gap;
      lastNarrow[k] = span == 1 ? out.length - 1 : null;
    }
  }

  final heights = [for (final t in tops) math.max(0.0, t - gap)];
  return GifPackResult(
    tiles: out,
    height: heights.fold<double>(0, math.max),
    columnHeights: heights,
  );
}

double _sane(double a) => a.isFinite && a > 0 ? a : 1.0;
