// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;
import 'dart:ui';

/// Какие углы плитки альбома скругляются: только те, что лежат на внешнем
/// краю всего альбома. Внутренние углы — прямые, между плитками узкий шов.
class MediaTileCorners {
  const MediaTileCorners({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  static const MediaTileCorners all = MediaTileCorners(
    topLeft: true,
    topRight: true,
    bottomLeft: true,
    bottomRight: true,
  );

  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  @override
  bool operator ==(Object other) =>
      other is MediaTileCorners &&
      other.topLeft == topLeft &&
      other.topRight == topRight &&
      other.bottomLeft == bottomLeft &&
      other.bottomRight == bottomRight;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomLeft, bottomRight);

  @override
  String toString() =>
      'MediaTileCorners(${topLeft ? 'TL' : ''}${topRight ? 'TR' : ''}'
      '${bottomLeft ? 'BL' : ''}${bottomRight ? 'BR' : ''})';
}

/// Место одной плитки в альбоме.
class MediaTileLayout {
  const MediaTileLayout(this.rect, this.corners);

  final Rect rect;
  final MediaTileCorners corners;

  @override
  String toString() => 'MediaTileLayout($rect, $corners)';
}

/// Раскладка альбома — тот же алгоритм, что у Telegram на всех устройствах
/// (`LayoutMediaGroup` в Telegram Desktop, `GroupedMessages` на Android).
///
/// 🔴 ЗАЧЕМ ИМЕННО ОН. Указание владельца 16.09.2026: медиа «ровно так же,
/// как в телеграме». Сетка «по рядам» выглядит похоже только на квадратных
/// снимках; на смеси вертикальных скриншотов и широких фото Telegram
/// подбирает раскладку по пропорциям: широкие — друг над другом, узкий
/// слева — высокой колонкой, пять и больше — перебором разбиений на ряды с
/// наименьшим отклонением от целевой высоты.
///
/// [sizes] — размеры снимков в пикселях (важны только пропорции),
/// [maxWidth] — ширина альбома, [minWidth] — наименьшая ширина плитки,
/// [spacing] — шов между плитками. Размеры плиток целые, как у Telegram:
/// дробные давали бы полупиксельные швы.
List<MediaTileLayout> layoutMediaGroup(
  List<Size> sizes, {
  required double maxWidth,
  required double minWidth,
  required double spacing,
}) {
  if (sizes.isEmpty) return const <MediaTileLayout>[];
  final ratios = <double>[
    for (final s in sizes)
      (s.width > 0 && s.height > 0) ? s.width / s.height : 1.0,
  ];
  return _Layouter(
    ratios: ratios,
    maxWidth: maxWidth.floorToDouble(),
    minWidth: minWidth,
    spacing: spacing,
  ).layout();
}

double _round(double v) => v.roundToDouble();

class _Layouter {
  _Layouter({
    required this.ratios,
    required this.maxWidth,
    required this.minWidth,
    required this.spacing,
  }) : maxHeight = maxWidth,
       averageRatio = ratios.fold<double>(1, (a, b) => a + b) / ratios.length,
       proportions = ratios
           .map((r) => r > 1.2 ? 'w' : (r < 0.8 ? 'n' : 'q'))
           .join();

  final List<double> ratios;
  final double maxWidth;

  /// Как у Telegram: для простых случаев целевая область — квадрат.
  final double maxHeight;
  final double minWidth;
  final double spacing;

  /// У Telegram сумма начинается с единицы — это не ошибка переноса, а его
  /// поведение, от которого зависит выбор раскладки.
  final double averageRatio;
  final String proportions;

  int get count => ratios.length;
  double get maxSizeRatio => maxWidth / maxHeight;

  List<MediaTileLayout> layout() {
    if (count == 1) return _one();
    if (count >= 5 || ratios.any((r) => r > 2)) {
      return _ComplexLayouter(
        ratios: ratios,
        averageRatio: averageRatio,
        maxWidth: maxWidth,
        minWidth: minWidth,
        spacing: spacing,
      ).layout();
    }
    if (count == 2) return _two();
    if (count == 3) return _three();
    return _four();
  }

  List<MediaTileLayout> _one() {
    final width = maxWidth;
    final height = _round(width / ratios[0]);
    return [
      MediaTileLayout(
        Rect.fromLTWH(0, 0, width, height),
        MediaTileCorners.all,
      ),
    ];
  }

  List<MediaTileLayout> _two() {
    if (proportions == 'ww' &&
        averageRatio > 1.4 * maxSizeRatio &&
        ratios[1] - ratios[0] < 0.2) {
      return _twoTopBottom();
    }
    if (proportions == 'ww' || proportions == 'qq') {
      return _twoLeftRightEqual();
    }
    return _twoLeftRight();
  }

  List<MediaTileLayout> _twoTopBottom() {
    final width = maxWidth;
    final height = _round(
      math.min(
        width / ratios[0],
        math.min(width / ratios[1], (maxHeight - spacing) / 2),
      ),
    );
    return [
      MediaTileLayout(
        Rect.fromLTWH(0, 0, width, height),
        const MediaTileCorners(topLeft: true, topRight: true),
      ),
      MediaTileLayout(
        Rect.fromLTWH(0, height + spacing, width, height),
        const MediaTileCorners(bottomLeft: true, bottomRight: true),
      ),
    ];
  }

  List<MediaTileLayout> _twoLeftRightEqual() {
    final width = ((maxWidth - spacing) / 2).floorToDouble();
    final height = _round(
      math.min(width / ratios[0], math.min(width / ratios[1], maxHeight)),
    );
    return [
      MediaTileLayout(
        Rect.fromLTWH(0, 0, width, height),
        const MediaTileCorners(topLeft: true, bottomLeft: true),
      ),
      MediaTileLayout(
        Rect.fromLTWH(width + spacing, 0, width, height),
        const MediaTileCorners(topRight: true, bottomRight: true),
      ),
    ];
  }

  List<MediaTileLayout> _twoLeftRight() {
    final minimalWidth = _round(minWidth * 1.5);
    final secondWidth = math.min(
      _round(
        math.max(
          0.4 * (maxWidth - spacing),
          (maxWidth - spacing) /
              ratios[0] /
              (1 / ratios[0] + 1 / ratios[1]),
        ),
      ),
      maxWidth - spacing - minimalWidth,
    );
    final firstWidth = maxWidth - secondWidth - spacing;
    final height = math.min(
      maxHeight,
      _round(math.min(firstWidth / ratios[0], secondWidth / ratios[1])),
    );
    return [
      MediaTileLayout(
        Rect.fromLTWH(0, 0, firstWidth, height),
        const MediaTileCorners(topLeft: true, bottomLeft: true),
      ),
      MediaTileLayout(
        Rect.fromLTWH(firstWidth + spacing, 0, secondWidth, height),
        const MediaTileCorners(topRight: true, bottomRight: true),
      ),
    ];
  }

  List<MediaTileLayout> _three() {
    if (proportions[0] == 'n') return _threeLeftAndOther();
    return _threeTopAndOther();
  }

  List<MediaTileLayout> _threeLeftAndOther() {
    final firstHeight = maxHeight;
    final thirdHeight = _round(
      math.min(
        (maxHeight - spacing) / 2,
        ratios[1] * (maxWidth - spacing) / (ratios[2] + ratios[1]),
      ),
    );
    final secondHeight = firstHeight - thirdHeight - spacing;
    final rightWidth = math.max(
      minWidth,
      _round(
        math.min(
          (maxWidth - spacing) / 2,
          math.min(thirdHeight * ratios[2], secondHeight * ratios[1]),
        ),
      ),
    );
    final leftWidth = math.min(
      _round(firstHeight * ratios[0]),
      maxWidth - spacing - rightWidth,
    );
    return [
      MediaTileLayout(
        Rect.fromLTWH(0, 0, leftWidth, firstHeight),
        const MediaTileCorners(topLeft: true, bottomLeft: true),
      ),
      MediaTileLayout(
        Rect.fromLTWH(leftWidth + spacing, 0, rightWidth, secondHeight),
        const MediaTileCorners(topRight: true),
      ),
      MediaTileLayout(
        Rect.fromLTWH(
          leftWidth + spacing,
          secondHeight + spacing,
          rightWidth,
          thirdHeight,
        ),
        const MediaTileCorners(bottomRight: true),
      ),
    ];
  }

  List<MediaTileLayout> _threeTopAndOther() {
    final firstWidth = maxWidth;
    final firstHeight = _round(
      math.min(firstWidth / ratios[0], (maxHeight - spacing) * 0.66),
    );
    final secondWidth = ((maxWidth - spacing) / 2).floorToDouble();
    final secondHeight = math.min(
      maxHeight - firstHeight - spacing,
      _round(math.min(secondWidth / ratios[1], secondWidth / ratios[2])),
    );
    final thirdWidth = firstWidth - secondWidth - spacing;
    return [
      MediaTileLayout(
        Rect.fromLTWH(0, 0, firstWidth, firstHeight),
        const MediaTileCorners(topLeft: true, topRight: true),
      ),
      MediaTileLayout(
        Rect.fromLTWH(0, firstHeight + spacing, secondWidth, secondHeight),
        const MediaTileCorners(bottomLeft: true),
      ),
      MediaTileLayout(
        Rect.fromLTWH(
          secondWidth + spacing,
          firstHeight + spacing,
          thirdWidth,
          secondHeight,
        ),
        const MediaTileCorners(bottomRight: true),
      ),
    ];
  }

  List<MediaTileLayout> _four() {
    if (proportions[0] == 'w') return _fourTopAndOther();
    return _fourLeftAndOther();
  }

  List<MediaTileLayout> _fourTopAndOther() {
    final w = maxWidth;
    final h0 = _round(math.min(w / ratios[0], (maxHeight - spacing) * 0.66));
    final h = _round(
      (maxWidth - 2 * spacing) / (ratios[1] + ratios[2] + ratios[3]),
    );
    final w0 = math.max(
      minWidth,
      _round(math.min((maxWidth - 2 * spacing) * 0.4, h * ratios[1])),
    );
    final w2 = _round(
      math.max(
        math.max(minWidth, (maxWidth - 2 * spacing) * 0.33),
        h * ratios[3],
      ),
    );
    final w1 = w - w0 - w2 - 2 * spacing;
    final h1 = math.min(maxHeight - h0 - spacing, h);
    return [
      MediaTileLayout(
        Rect.fromLTWH(0, 0, w, h0),
        const MediaTileCorners(topLeft: true, topRight: true),
      ),
      MediaTileLayout(
        Rect.fromLTWH(0, h0 + spacing, w0, h1),
        const MediaTileCorners(bottomLeft: true),
      ),
      MediaTileLayout(
        Rect.fromLTWH(w0 + spacing, h0 + spacing, w1, h1),
        const MediaTileCorners(),
      ),
      MediaTileLayout(
        Rect.fromLTWH(w0 + spacing + w1 + spacing, h0 + spacing, w2, h1),
        const MediaTileCorners(bottomRight: true),
      ),
    ];
  }

  List<MediaTileLayout> _fourLeftAndOther() {
    final h = maxHeight;
    final w0 = _round(math.min(h * ratios[0], (maxWidth - spacing) * 0.6));
    final w = _round(
      (maxHeight - 2 * spacing) /
          (1 / ratios[1] + 1 / ratios[2] + 1 / ratios[3]),
    );
    final h0 = _round(w / ratios[1]);
    final h1 = _round(w / ratios[2]);
    final h2 = h - h0 - h1 - 2 * spacing;
    final w1 = math.max(minWidth, math.min(maxWidth - w0 - spacing, w));
    return [
      MediaTileLayout(
        Rect.fromLTWH(0, 0, w0, h),
        const MediaTileCorners(topLeft: true, bottomLeft: true),
      ),
      MediaTileLayout(
        Rect.fromLTWH(w0 + spacing, 0, w1, h0),
        const MediaTileCorners(topRight: true),
      ),
      MediaTileLayout(
        Rect.fromLTWH(w0 + spacing, h0 + spacing, w1, h1),
        const MediaTileCorners(),
      ),
      MediaTileLayout(
        Rect.fromLTWH(w0 + spacing, h0 + h1 + 2 * spacing, w1, h2),
        const MediaTileCorners(bottomRight: true),
      ),
    ];
  }
}

class _Attempt {
  const _Attempt(this.lineCounts, this.heights);
  final List<int> lineCounts;
  final List<double> heights;
}

/// Пять и больше снимков (или очень широкий среди них): перебор разбиений на
/// 2–4 ряда, лучший — с высотой ближе всего к целевой (4/3 ширины).
class _ComplexLayouter {
  _ComplexLayouter({
    required List<double> ratios,
    required this.averageRatio,
    required this.maxWidth,
    required this.minWidth,
    required this.spacing,
  }) : ratios = [
         // Как в Telegram Desktop (`ui/grouped_layout.cpp`): при широком
         // наборе пропорции прижимаются к [1; 2,75], иначе — к [2/3; 1].
         for (final r in ratios)
           (averageRatio > 1.1 ? r.clamp(1.0, 2.75) : r.clamp(0.6667, 1.0))
               .toDouble(),
       ],
       maxHeight = (maxWidth * 4 / 3).floorToDouble();

  final List<double> ratios;
  final double averageRatio;
  final double maxWidth;
  final double maxHeight;
  final double minWidth;
  final double spacing;

  int get count => ratios.length;

  double _multiHeight(int offset, int lineCount) {
    var sum = 0.0;
    for (var i = offset; i < offset + lineCount; i++) {
      sum += ratios[i];
    }
    return (maxWidth - (lineCount - 1) * spacing) / sum;
  }

  List<MediaTileLayout> layout() {
    final attempts = <_Attempt>[];
    void push(List<int> counts) {
      final heights = <double>[];
      var offset = 0;
      for (final c in counts) {
        heights.add(_multiHeight(offset, c));
        offset += c;
      }
      attempts.add(_Attempt(counts, heights));
    }

    for (var first = 1; first != count; first++) {
      final second = count - first;
      if (first > 3 || second > 3) continue;
      push([first, second]);
    }
    for (var first = 1; first < count - 1; first++) {
      for (var second = 1; second < count - first; second++) {
        final third = count - first - second;
        if (first > 3 ||
            second > (averageRatio < 0.85 ? 4 : 3) ||
            third > 3) {
          continue;
        }
        push([first, second, third]);
      }
    }
    for (var first = 1; first < count - 1; first++) {
      for (var second = 1; second < count - first; second++) {
        for (var third = 1; third < count - first - second; third++) {
          final fourth = count - first - second - third;
          if (first > 3 || second > 3 || third > 3 || fourth > 3) continue;
          push([first, second, third, fourth]);
        }
      }
    }

    // Больше 12 снимков в одном альбоме не бывает (предел — 10), но перебор
    // обязан что-то вернуть и на них: тогда — ряды по три.
    if (attempts.isEmpty) {
      final counts = <int>[];
      var left = count;
      while (left > 0) {
        final take = math.min(3, left);
        counts.add(take);
        left -= take;
      }
      push(counts);
    }

    _Attempt? best;
    var bestDiff = 0.0;
    for (final attempt in attempts) {
      final heights = attempt.heights;
      final counts = attempt.lineCounts;
      final lines = counts.length;
      final total =
          heights.fold<double>(0, (a, b) => a + b) + spacing * (lines - 1);
      final minLine = heights.reduce(math.min);
      final bad1 = minLine < minWidth ? 1.5 : 1.0;
      var bad2 = 1.0;
      for (var line = 1; line < lines; line++) {
        if (counts[line - 1] > counts[line]) {
          bad2 = 1.5;
          break;
        }
      }
      final diff = (total - maxHeight).abs() * bad1 * bad2;
      if (best == null || diff < bestDiff) {
        best = attempt;
        bestDiff = diff;
      }
    }

    final result = <MediaTileLayout>[];
    final counts = best!.lineCounts;
    final heights = best.heights;
    final rows = counts.length;
    var index = 0;
    var y = 0.0;
    for (var row = 0; row < rows; row++) {
      final cols = counts[row];
      final lineHeight = heights[row];
      final height = _round(lineHeight);
      var x = 0.0;
      for (var col = 0; col < cols; col++) {
        final width = col == cols - 1
            ? maxWidth - x
            : _round(ratios[index] * lineHeight);
        result.add(
          MediaTileLayout(
            Rect.fromLTWH(x, y, width, height),
            MediaTileCorners(
              topLeft: row == 0 && col == 0,
              topRight: row == 0 && col == cols - 1,
              bottomLeft: row == rows - 1 && col == 0,
              bottomRight: row == rows - 1 && col == cols - 1,
            ),
          ),
        );
        x += width + spacing;
        index++;
      }
      y += height + spacing;
    }
    return result;
  }
}

/// Размер всего альбома — по раскладке.
Size mediaGroupSize(List<MediaTileLayout> tiles) {
  var w = 0.0;
  var h = 0.0;
  for (final t in tiles) {
    w = math.max(w, t.rect.right);
    h = math.max(h, t.rect.bottom);
  }
  return Size(w, h);
}
