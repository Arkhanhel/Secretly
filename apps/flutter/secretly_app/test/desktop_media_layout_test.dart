// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 РАСКЛАДКА АЛЬБОМА — АЛГОРИТМ TELEGRAM.
//
// Указание владельца 16.09.2026: медиа «ровно так же, как в телеграме».
// Числа ниже посчитаны по формулам `Telegram/SourceFiles/ui/grouped_layout.cpp`
// (Telegram Desktop) с параметрами альбома в ленте: ширина 430, наименьшая
// плитка 100, шов 4.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/media_group_layout.dart';
import 'package:secretly_app/ui/desktop/chat/message_media.dart';

List<MediaTileLayout> _lay(List<Size> sizes, {double width = 430}) =>
    layoutMediaGroup(sizes, maxWidth: width, minWidth: 100, spacing: 4);

const _phone = Size(1170, 2532); // вертикальный скриншот
const _wide = Size(1600, 900);
const _square = Size(1000, 1000);

void _expectOuterCornersOnce(List<MediaTileLayout> tiles) {
  int count(bool Function(MediaTileCorners c) f) =>
      tiles.where((t) => f(t.corners)).length;
  expect(count((c) => c.topLeft), 1, reason: 'верхний левый угол');
  expect(count((c) => c.topRight), 1, reason: 'верхний правый угол');
  expect(count((c) => c.bottomLeft), 1, reason: 'нижний левый угол');
  expect(count((c) => c.bottomRight), 1, reason: 'нижний правый угол');
}

void main() {
  test('один снимок — во всю ширину, все углы скруглены', () {
    final t = _lay(const [Size(1000, 500)]);
    expect(t.single.rect, const Rect.fromLTWH(0, 0, 430, 215));
    expect(t.single.corners, MediaTileCorners.all);
  });

  test('🔴 два широких одинаковых — друг над другом', () {
    // ww, средняя пропорция (1 + 1,78 + 1,78) / 2 = 2,28 > 1,4, разница 0.
    final t = _lay(const [_wide, _wide]);
    expect(t[0].rect, const Rect.fromLTWH(0, 0, 430, 213));
    expect(t[1].rect, const Rect.fromLTWH(0, 217, 430, 213));
    expect(
      t[0].corners,
      const MediaTileCorners(topLeft: true, topRight: true),
    );
    expect(
      t[1].corners,
      const MediaTileCorners(bottomLeft: true, bottomRight: true),
    );
  });

  test('два квадратных — рядом, поровну', () {
    final t = _lay(const [_square, _square]);
    expect(t[0].rect, const Rect.fromLTWH(0, 0, 213, 213));
    expect(t[1].rect, const Rect.fromLTWH(217, 0, 213, 213));
    _expectOuterCornersOnce(t);
  });

  test('🔴 два вертикальных скриншота — рядом во всю высоту', () {
    // Как на скриншоте владельца: два снимка экрана телефона рядом.
    final t = _lay(const [_phone, _phone]);
    expect(t[0].rect, const Rect.fromLTWH(0, 0, 213, 430));
    expect(t[1].rect, const Rect.fromLTWH(217, 0, 213, 430));
    _expectOuterCornersOnce(t);
  });

  test('три, первый узкий — он слева во всю высоту, два справа', () {
    final t = _lay(const [_phone, _wide, _wide]);
    expect(t[0].rect.left, 0);
    expect(t[0].rect.height, 430);
    expect(t[1].rect.left, t[0].rect.right + 4);
    expect(t[2].rect.top, t[1].rect.bottom + 4);
    expect(t[2].rect.bottom, 430);
    _expectOuterCornersOnce(t);
  });

  test('три, первый широкий — он сверху, два снизу', () {
    final t = _lay(const [_wide, _square, _square]);
    expect(t[0].rect.width, 430);
    expect(t[1].rect.top, t[0].rect.bottom + 4);
    expect(t[1].rect.width, 213);
    expect(t[2].rect.right, 430);
    _expectOuterCornersOnce(t);
  });

  test('четыре, первый широкий — он сверху, три снизу', () {
    final t = _lay(const [_wide, _square, _square, _square]);
    expect(t[0].rect.width, 430);
    for (var i = 1; i < 4; i++) {
      expect(t[i].rect.top, t[0].rect.bottom + 4);
    }
    expect(t[3].rect.right, 430);
    _expectOuterCornersOnce(t);
  });

  test('четыре, первый узкий — он слева, три справа стопкой', () {
    final t = _lay(const [_phone, _square, _square, _square]);
    expect(t[0].rect.height, 430);
    expect(t[1].rect.left, t[0].rect.right + 4);
    expect(t[3].rect.bottom, 430);
    _expectOuterCornersOnce(t);
  });

  test('🔴 пять и больше — ряды, каждый упирается в правый край', () {
    for (final count in [5, 6, 7, 8, 9, 10]) {
      final sizes = [
        for (var i = 0; i < count; i++) i.isEven ? _wide : _square,
      ];
      final t = _lay(sizes);
      expect(t, hasLength(count));
      for (final tile in t) {
        expect(tile.rect.left, greaterThanOrEqualTo(0));
        expect(tile.rect.right, lessThanOrEqualTo(430));
        expect(tile.rect.width, greaterThan(0));
        expect(tile.rect.height, greaterThan(0));
      }
      // В каждом ряду последняя плитка кончается ровно на краю.
      final rows = <double, List<MediaTileLayout>>{};
      for (final tile in t) {
        rows.putIfAbsent(tile.rect.top, () => []).add(tile);
      }
      expect(rows.length, inInclusiveRange(2, 4), reason: '$count снимков');
      for (final row in rows.values) {
        expect(row.last.rect.right, 430);
      }
      _expectOuterCornersOnce(t);
      // Целевая высота сложной раскладки — 4/3 ширины.
      final size = mediaGroupSize(t);
      expect(size.height, lessThan(430 * 4 / 3 + 200), reason: '$count');
    }
  });

  test('очень широкий снимок уводит пару в сложную раскладку', () {
    final t = _lay(const [Size(3000, 1000), _square]);
    // Пропорция 3 > 2: два ряда по одному.
    expect(t[0].rect.width, 430);
    expect(t[1].rect.width, 430);
    expect(t[1].rect.top, t[0].rect.bottom + 4);
  });

  test('размеры плиток — целые: полупиксельных швов нет', () {
    final t = _lay(const [_phone, _wide, _square, Size(1234, 987)]);
    for (final tile in t) {
      for (final v in [tile.rect.left, tile.rect.top, tile.rect.width]) {
        expect(v, v.roundToDouble());
      }
    }
  });

  group('в ленте', () {
    test('одиночный снимок: не больше 430, не меньше 100', () {
      expect(
        singleMediaSize(const Size(4000, 3000), maxWidth: 800),
        const Size(430, 323),
      );
      // Высокий скриншот упирается в высоту 430.
      expect(
        singleMediaSize(_phone, maxWidth: 800),
        const Size(199, 430),
      );
      // Маленькая картинка не растягивается, но и не меньше 100.
      expect(
        singleMediaSize(const Size(60, 40), maxWidth: 800),
        const Size(100, 100),
      );
      // Узкое место — снимок сжимается по ширине.
      expect(singleMediaSize(const Size(4000, 3000), maxWidth: 300).width, 300);
      // В пузыре с подписью — не уже 200.
      expect(
        singleMediaSize(_phone, maxWidth: 800, inBubble: true).width,
        200,
      );
    });

    test('альбом в узком месте сжимается вместе со швом', () {
      final full = albumLayout(const [_square, _square], width: 430);
      final narrow = albumLayout(const [_square, _square], width: 215);
      expect(mediaGroupSize(full).width, 430);
      expect(mediaGroupSize(narrow).width, 215);
      // Шов 4 × 0,5 = 2.
      expect(narrow[1].rect.left - narrow[0].rect.right, 2);
    });

    test('обрезка: пропорции вдвое разные — снимок вписывается целиком', () {
      expect(
        LocalMediaImage.coverCut(const Size(100, 100), const Size(100, 100)),
        0,
      );
      expect(
        LocalMediaImage.coverCut(const Size(400, 100), const Size(100, 100)),
        closeTo(0.75, 1e-9),
      );
      // Квадрат в плитке 200×330 — срезается 40%: как в Telegram, заполняет.
      expect(
        LocalMediaImage.coverCut(const Size(100, 100), const Size(200, 330)),
        lessThan(0.5),
      );
      // Ровно вдвое — уже вписывается.
      expect(
        LocalMediaImage.coverCut(const Size(200, 100), const Size(100, 100)),
        closeTo(0.5, 1e-9),
      );
    });

    test('длительность ролика — минуты двумя цифрами', () {
      expect(formatMediaDuration(15000), '00:15');
      expect(formatMediaDuration(205000), '03:25');
      expect(formatMediaDuration(3725000), '1:02:05');
    });
  });
}
