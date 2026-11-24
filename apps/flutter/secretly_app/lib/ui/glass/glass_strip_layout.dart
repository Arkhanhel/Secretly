// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Раскладка полосы категорий во всю ширину (план стекла, 23.11.2026).
///
/// Пластина всегда занимает всю ширину, сколько бы ни было пунктов:
/// 1. **поровну**, если самый широкий пункт помещается в свою долю (две папки →
///    две половины);
/// 2. **по содержимому**, если поровну не влезает, а все вместе влезают: каждый
///    получает свою ширину плюс равную долю остатка — без пустоты справа;
/// 3. **прокрутка** внутри пластины, если не влезает ничего: пункты по
///    содержимому, пластина по-прежнему во всю ширину.
library;

import 'dart:math' as math;
import 'dart:ui' show Rect;

enum GlassStripMode { equal, content, scroll }

class GlassStripLayout {
  const GlassStripLayout({
    required this.mode,
    required this.lefts,
    required this.widths,
    required this.contentWidth,
  });

  final GlassStripMode mode;

  /// Левый край и ширина каждого пункта внутри содержимого полосы.
  final List<double> lefts;
  final List<double> widths;

  /// Ширина всего содержимого (в режиме прокрутки больше видимой).
  final double contentWidth;

  int get length => widths.length;

  Rect rectOf(int i, double top, double height) =>
      Rect.fromLTWH(lefts[i], top, widths[i], height);
}

/// [available] — ширина содержимого (пластина минус внутренние поля),
/// [natural] — естественная ширина каждого пункта.
GlassStripLayout computeGlassStripLayout({
  required double available,
  required List<double> natural,
}) {
  final n = natural.length;
  if (n == 0 || available <= 0) {
    return const GlassStripLayout(
      mode: GlassStripMode.equal,
      lefts: [],
      widths: [],
      contentWidth: 0,
    );
  }
  final share = available / n;
  final widest = natural.reduce(math.max);
  final total = natural.fold<double>(0, (a, b) => a + b);
  final GlassStripMode mode;
  final List<double> widths;
  if (widest <= share + 0.01) {
    mode = GlassStripMode.equal;
    widths = List<double>.filled(n, share);
  } else if (total <= available + 0.01) {
    mode = GlassStripMode.content;
    final extra = (available - total) / n;
    widths = [for (final w in natural) w + extra];
  } else {
    mode = GlassStripMode.scroll;
    widths = List<double>.of(natural);
  }
  final lefts = <double>[];
  var x = 0.0;
  for (final w in widths) {
    lefts.add(x);
    x += w;
  }
  return GlassStripLayout(
    mode: mode,
    lefts: lefts,
    widths: widths,
    contentWidth: mode == GlassStripMode.scroll ? x : available,
  );
}

/// Рамка капли при дробной позиции [p] (например 1,37 — между вторым и
/// третьим пунктом). Внутри перехода левый край держится ближе к левому
/// пункту, правый — к правому: капля вытягивается на оба и стягивается к
/// цели — в какую бы сторону она ни ехала, передний край уходит первым, задний
/// догоняет. На целых позициях рамка в точности равна пункту.
Rect glassThumbRect({
  required GlassStripLayout layout,
  required double p,
  required double top,
  required double height,
  bool stretch = true,
}) {
  final n = layout.length;
  if (n == 0) return Rect.zero;
  final clamped = p.clamp(0.0, (n - 1).toDouble());
  final i = clamped.floor().clamp(0, n - 1);
  final j = math.min(i + 1, n - 1);
  final f = clamped - i;
  final a = layout.rectOf(i, top, height);
  final b = layout.rectOf(j, top, height);
  final tLeft = stretch ? math.pow(f, 2.2).toDouble() : f;
  final tRight = stretch ? 1 - math.pow(1 - f, 2.2).toDouble() : f;
  final left = a.left + (b.left - a.left) * tLeft;
  final right = a.right + (b.right - a.right) * tRight;
  // По ходу капля чуть сплющивается поперёк (как жидкость).
  final squash = stretch ? 1.5 * math.sin(math.pi * f) : 0.0;
  return Rect.fromLTRB(left, top + squash, right, top + height - squash);
}
