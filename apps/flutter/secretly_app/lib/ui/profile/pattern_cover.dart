// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Живые обложки-узоры профиля (макет «Profile Motion», 21.11.2026).
///
/// Десять узоров подчиняются одной системе движения: тянешь вниз — узор
/// расходится (внешние кольца с запаздыванием — шесть пружинных «полос»),
/// фото раскрывается — узор разлетается и гаснет, прокрутка вверх —
/// стягивается к аватару. Края мягко затемнены цветом фона темы, подсветка
/// за аватаром — из его цвета.
///
/// Знаки — свои, не замочки макета (владелец: «из нашей буквы С в виде
/// отпечатка и т. д.»): [PatternGlyph.print] — буква S гребнями отпечатка,
/// [PatternGlyph.bubble] — облачко сообщения, [PatternGlyph.spark] —
/// четырёхлучевая искра, ромб и точка.
///
/// Правила макета: один цвет узора (белый в тёмной теме, тёмно-синий в
/// светлой), прозрачность 5–20 %, вокруг аватара пустое кольцо ~70,
/// скорость в покое ≤ 4 px/с. Всё — один [CustomPainter].
///
/// Вторая волна (22.11.2026) — одиннадцать узоров из макета: светлячки,
/// буква S, газировка, бургеры, самолётики, шарики, кофе, пончики,
/// мороженое, попкорн, масти. Они цветные наклейки или знаки темы; рисуются
/// листом спрайтов за один вызов — см. pattern_cover_extra.dart.
///
/// Одиннадцатый узор — [PatternCoverStyle.fingerprint] «Отпечаток ключа»:
/// дуги трёх колец и точки внешнего кольца строятся из SHA-256 ключа
/// личности человека ([KeyFingerprintLayout]), у каждого свой. Байты ключа
/// приходят в рисовальщик полем [PatternCoverPainter.keyBytes] (на экране —
/// из `PatternCoverKey`, lib/ui/profile/key_fingerprint.dart).
library;

import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';

import 'pattern_cover_extra.dart';
import 'pattern_cover_staff.dart';

export 'pattern_cover_staff.dart'
    show
        kNewYearPatternCoverStyles,
        kStaffPatternCoverStyles,
        patternCoverOwnTint;

enum PatternCoverStyle {
  orbits,
  monogram,
  bubbles,
  constellation,
  ripples,
  rays,
  halftone,
  spiral,
  rain,
  honeycomb,

  /// «Отпечаток ключа»: узор из ключа шифрования. 🔴 Стоит ПОСЛЕДНИМ в
  /// перечислении (по номеру ничего не хранится, но порядок прежних не
  /// трогаем); в каталоге он первый.
  fingerprint,

  // ── Вторая волна (макет «Profile Motion», 22.11.2026) ──
  // 🔴 Только дописывать в конец: id хранится по имени (`pattern_<имя>`),
  // но порядок прежних не трогаем. Рисуются в pattern_cover_extra.dart.

  /// «Светлячки»: рой огоньков складывается в букву S логотипа.
  fireflies,

  /// «Отпечаток S»: буква S логотипа в шахматном порядке с точками.
  smark,

  /// «Газировка»: бутылки с красной этикеткой и пузырьки.
  soda,

  /// «Бургеры»: наклейки по трём орбитам.
  burgers,

  /// «Самолётики»: бумажные самолётики с пунктирным следом.
  planes,

  /// «Шарики»: воздушные шарики на ниточках.
  balloons,

  /// «Кофе с собой»: стаканчики с паром.
  coffee,

  /// «Пончики»: наклейки по орбитам, четыре глазури.
  donuts,

  /// «Мороженое»: рожки, три вкуса.
  icecream,

  /// «Попкорн»: полосатые стаканы.
  popcorn,

  /// «Масти»: пики, черви, бубны, трефы рядами.
  suits,

  // ── Третья волна (макет «Covers», 23.11.2026) ──
  // 🔴 Только дописывать в конец. Рисуются в pattern_cover_staff.dart; у
  // каждой свой глубокий фон ([patternCoverOwnTint]). Первые десять — для
  // сотрудников ([kStaffPatternCoverStyles]), вторые — новогодние
  // ([kNewYearPatternCoverStyles]).

  /// «Шампанское»: бокалы-купе с пузырьками, чокаются, на кромке искра.
  champagne,

  /// «Камни»: бриллиант, изумруд, сапфир и рубин медленно поворачиваются.
  gems,

  /// «Парфюм»: флаконы с цветным стеклом выпускают облачко аромата.
  perfume,

  /// «Макаруны»: пять вкусов, верхняя половинка подпрыгивает.
  macarons,

  /// «Часы»: стрелки идут по-настоящему, у каждых — свой город.
  watches,

  /// «Механизм»: зубчатое кольцо, колёса с рубинами и балансир (линии).
  movement,

  /// «Армиллярная сфера»: бронзовые кольца вращаются, по эклиптике идёт
  /// медная бусина (линии).
  armillary,

  /// «Металлическая карта»: карты переворачиваются, по металлу — блик.
  cards,

  // «Гран-при» (cars) убрана 23.11.2026 по слову владельца: id
  // `pattern_cars` больше ничего не рисует (у выбравшего — без обложки).

  /// «Подарки»: крышка подскакивает, из коробки вылетают искры.
  gifts,

  /// «Ёлочные шары»: стеклянные шары на нитках качаются; идёт снег.
  ornaments,

  /// «Снежинки»: три вида, вращаются и дышат; идёт снег.
  snowflakes,

  /// «Снеговики»: машут рукой-веткой, моргают; идёт снег.
  snowman,

  /// «Мандарины»: мандарины с листиком и дольки; идёт снег.
  tangerines,

  /// «Пряничные человечки»: танцуют; идёт снег.
  gingerbread,

  /// «Бенгальские огни»: искры ветвятся, падают угольки; идёт снег.
  sparkler,

  /// «Колокольчики»: звонят, расходятся волны звука; идёт снег.
  bells,

  /// «Какао»: кружки с зефирками и паром; идёт снег.
  cocoa,

  /// «Ёлочки»: гирлянда бежит по кругу, звезда светится; идёт снег.
  tree,

  /// «Снежные шары»: встряхиваются, снег взлетает и оседает; идёт снег.
  snowglobe,
}

/// Идентификатор обложки в профиле: `pattern_<узор>`.
const String kPatternCoverPrefix = 'pattern_';

PatternCoverStyle? patternCoverStyleFromId(String? coverId) {
  final id = coverId?.trim() ?? '';
  if (!id.startsWith(kPatternCoverPrefix)) return null;
  final name = id.substring(kPatternCoverPrefix.length);
  for (final s in PatternCoverStyle.values) {
    if (s.name == name) return s;
  }
  return null;
}

String patternCoverId(PatternCoverStyle style) =>
    '$kPatternCoverPrefix${style.name}';

enum PatternGlyph { print, bubble, spark, diamond, dot }

// ── Состояние движения ────────────────────────────────────────────────────

/// Что происходит со страницей сейчас — из экрана профиля.
@immutable
class PatternCoverInput {
  const PatternCoverInput({
    this.pull = 0,
    this.collapse = 0,
    this.expanded = 0,
    this.avatarCenterY = 111,
    this.fadeY = 260,
  });

  /// Сколько потянули вниз, px (после резинки).
  final double pull;

  /// Прокрутка вверх 0…1 (0–170 px макета).
  final double collapse;

  /// Фото раскрыто 0…1 (пружина).
  final double expanded;

  /// Центр аватара в координатах обложки (без прокрутки).
  final double avatarCenterY;

  /// Ниже этой линии узор гаснет (за 50 px) — под ним кнопки и карточки.
  final double fadeY;
}

/// Шесть пружин-«полос»: ближние к аватару откликаются быстрее, дальние —
/// с запаздыванием (k = 210 − 26·i, затухание 0,8 от критического).
class PatternCoverBands {
  final List<double> x = List<double>.filled(6, 1);
  final List<double> v = List<double>.filled(6, 0);

  /// Цель растяжения: прокрутка стягивает, натяжение раздвигает, раскрытие
  /// разбрасывает.
  static double target(PatternCoverInput i) =>
      (1 - 0.8 * i.collapse) * (1 + 1.5 * (i.pull / 240)) +
      i.expanded.clamp(0.0, 1.0) * 1.4;

  void step(double dt, double target) {
    for (var i = 0; i < 6; i++) {
      final k = 210.0 - i * 26;
      final d = 2 * math.sqrt(k) * 0.8;
      v[i] += (k * (target - x[i]) - d * v[i]) * dt;
      x[i] += v[i] * dt;
    }
  }

  bool get settled {
    for (var i = 0; i < 6; i++) {
      if (v[i].abs() > 0.002) return false;
    }
    return true;
  }
}

// ── Раскладка знаков (один раз на узор) ───────────────────────────────────

class _Item {
  _Item({
    this.x = 0,
    this.y = 0,
    this.d = 0,
    this.band = 0,
    this.size = 12,
    this.glyph = PatternGlyph.dot,
    this.phase = 0,
    this.speed = 0,
    this.radius = 0,
    this.angle = 0,
    this.ring = 0,
    this.z = 0,

  });

  double x, y, d, size, phase, speed, radius, angle, z;
  int band, ring;
  PatternGlyph glyph;
  bool big = false;
}

class _Layout {
  _Layout(this.items, this.links);
  final List<_Item> items;
  final List<(int, int, double)> links;
}

final Map<PatternCoverStyle, _Layout> _layouts = {};

_Layout _layoutFor(PatternCoverStyle style) =>
    _layouts.putIfAbsent(style, () => _build(style));

_Layout _build(PatternCoverStyle style) {
  var seed = 7;
  double rnd() {
    seed = (seed * 16807) % 2147483647;
    return seed / 2147483647;
  }

  _Item rel(double x, double y) {
    final d = math.sqrt(x * x + y * y);
    return _Item(x: x, y: y, d: d, band: math.min(5, (d / 55).floor()));
  }

  final items = <_Item>[];
  final links = <(int, int, double)>[];
  switch (style) {
    case PatternCoverStyle.orbits:
      const rings = [(92.0, 8, 14.0), (134.0, 12, 12.0), (178.0, 16, 11.0)];
      for (var i = 0; i < rings.length; i++) {
        final (r, n, sz) = rings[i];
        for (var k = 0; k < n; k++) {
          items.add(
            _Item(
              ring: i,
              band: i * 2,
              angle: math.pi * 2 * k / n + i * 0.35,
              radius: r,
              size: sz,
              glyph: (k + i).isOdd
                  ? PatternGlyph.dot
                  : (i == 1 ? PatternGlyph.spark : PatternGlyph.print),
              phase: k * 1.7,
              speed: (i.isOdd ? -1 : 1) * 0.02,
            ),
          );
        }
      }
    case PatternCoverStyle.monogram:
      for (var j = -6; j <= 9; j++) {
        for (var i = -6; i <= 6; i++) {
          final m = ((i + j) % 3 + 3) % 3;
          items.add(
            rel(i * 46.0 + (j & 1) * 23, j * 40.0)
              ..size = 12
              ..glyph = m == 0
                  ? PatternGlyph.print
                  : (m == 1 ? PatternGlyph.diamond : PatternGlyph.dot),
          );
        }
      }
    case PatternCoverStyle.bubbles:
      for (var k = 0; k < 28; k++) {
        final z = rnd();
        items.add(
          _Item(
            x: rnd() * 390,
            y: rnd() * 480,
            z: z,
            band: math.min(5, ((1 - z) * 6).floor()),
            size: 12 + z * 12,
            speed: 5 + z * 12,
            phase: rnd() * 6,
          ),
        );
      }
    case PatternCoverStyle.constellation:
      while (items.length < 46) {
        final a = rnd() * math.pi * 2;
        final r = 84 + rnd() * 170;
        items.add(
          rel(math.cos(a) * r, math.sin(a) * r * 0.95)
            ..phase = rnd() * 6
            ..big = rnd() < 0.2,
        );
      }
      for (var i = 0; i < items.length; i++) {
        for (var j = i + 1; j < items.length; j++) {
          final dx = items[i].x - items[j].x;
          final dy = items[i].y - items[j].y;
          final d = math.sqrt(dx * dx + dy * dy);
          if (d < 62) links.add((i, j, d));
        }
      }
    case PatternCoverStyle.ripples:
      for (var i = 0; i < 5; i++) {
        items.add(_Item(ring: i));
      }
    case PatternCoverStyle.rays:
      for (var i = 0; i < 48; i++) {
        items.add(
          _Item(
            angle: math.pi * 2 * i / 48,
            phase: rnd() * 6,
            band: 1 + (i % 3),
          ),
        );
      }
    case PatternCoverStyle.halftone:
      for (var y = -200.0; y <= 300; y += 16) {
        for (var x = -200.0; x <= 200; x += 16) {
          final d = math.sqrt(x * x + y * y);
          if (d > 70 && d < 290) {
            items.add(rel(x + ((y / 16).floor() & 1) * 8, y));
          }
        }
      }
    case PatternCoverStyle.spiral:
      for (var i = 0; i < 130; i++) {
        final r = 74 + 9.5 * math.sqrt(i * 2.2);
        items.add(
          _Item(
            radius: r,
            angle: i * 2.39996,
            band: math.min(5, ((r - 70) / 32).floor()),
            glyph: i % 3 == 0 ? PatternGlyph.print : PatternGlyph.dot,
            size: 15 - math.min(7, r / 40),
          ),
        );
      }
    case PatternCoverStyle.rain:
      for (var c = -6; c <= 6; c++) {
        final sp = 5 + rnd() * 6;
        final off = rnd() * 40;
        for (var k = 0; k < 12; k++) {
          items.add(
            _Item(
              x: c * 30.0,
              y: k * 40 + off,
              speed: sp,
              band: math.min(5, c.abs()),
              glyph: (k + c) % 4 == 0 ? PatternGlyph.bubble : PatternGlyph.dot,
              size: 11,
            ),
          );
        }
      }
    case PatternCoverStyle.honeycomb:
      const r = 17.0;
      final dx = r * math.sqrt(3);
      const dy = r * 1.5;
      for (var j = -9; j <= 13; j++) {
        for (var i = -8; i <= 8; i++) {
          items.add(rel(i * dx + (j & 1) * dx / 2, j * dy)..radius = r);
        }
      }
    case PatternCoverStyle.fingerprint:
      // Раскладка зависит от ключа — см. [KeyFingerprintLayout].
      break;
    case PatternCoverStyle.fireflies ||
        PatternCoverStyle.smark ||
        PatternCoverStyle.soda ||
        PatternCoverStyle.burgers ||
        PatternCoverStyle.planes ||
        PatternCoverStyle.balloons ||
        PatternCoverStyle.coffee ||
        PatternCoverStyle.donuts ||
        PatternCoverStyle.icecream ||
        PatternCoverStyle.popcorn ||
        PatternCoverStyle.suits:
      // Свои раскладки — в pattern_cover_extra.dart.
      break;
    case PatternCoverStyle.champagne ||
        PatternCoverStyle.gems ||
        PatternCoverStyle.perfume ||
        PatternCoverStyle.macarons ||
        PatternCoverStyle.watches ||
        PatternCoverStyle.movement ||
        PatternCoverStyle.armillary ||
        PatternCoverStyle.cards ||
        PatternCoverStyle.gifts ||
        PatternCoverStyle.ornaments ||
        PatternCoverStyle.snowflakes ||
        PatternCoverStyle.snowman ||
        PatternCoverStyle.tangerines ||
        PatternCoverStyle.gingerbread ||
        PatternCoverStyle.sparkler ||
        PatternCoverStyle.bells ||
        PatternCoverStyle.cocoa ||
        PatternCoverStyle.tree ||
        PatternCoverStyle.snowglobe:
      // Третья волна — раскладки в pattern_cover_staff.dart.
      break;
  }
  return _Layout(items, links);
}

// ── «Отпечаток ключа»: раскладка из байтов ключа ──────────────────────────

/// Дуга кольца отпечатка (координаты макета 390×460, углы в радианах).
@immutable
class KeyFingerprintArc {
  const KeyFingerprintArc({
    required this.ring,
    required this.band,
    required this.radius,
    required this.width,
    required this.alpha,
    required this.start,
    required this.sweep,
    required this.speed,
  });

  final int ring;
  final int band;
  final double radius;

  /// Толщина линии.
  final double width;
  final double alpha;
  final double start;
  final double sweep;

  /// Скорость вращения, рад/с (нечётные кольца — против часовой).
  final double speed;

  @override
  bool operator ==(Object other) =>
      other is KeyFingerprintArc &&
      other.ring == ring &&
      other.band == band &&
      other.radius == radius &&
      other.width == width &&
      other.alpha == alpha &&
      other.start == start &&
      other.sweep == sweep &&
      other.speed == speed;

  @override
  int get hashCode =>
      Object.hash(ring, band, radius, width, alpha, start, sweep, speed);
}

/// Точка внешнего кольца отпечатка.
@immutable
class KeyFingerprintDot {
  const KeyFingerprintDot({required this.start, required this.size});

  final double start;

  /// Радиус точки.
  final double size;

  @override
  bool operator ==(Object other) =>
      other is KeyFingerprintDot && other.start == start && other.size == size;

  @override
  int get hashCode => Object.hash(start, size);
}

/// Раскладка «Отпечатка ключа» по макету владельца: три кольца
/// (r 86/112/138, 24/32/40 отрезков) — отрезок пропускается, если его байт
/// < 0,18, иначе дуга длиной (0,3 + b·0,6) от своего сектора; плюс 56 точек
/// на r 164 (полоса 5) размером 0,8 + b·1,8.
///
/// Байты: [seed] (SHA-256 ключа, 32 байта), дальше — SHA-256(seed ‖ i) для
/// i = 1, 2, … (счётчиком), сколько нужно: раскладке нужно 96 + 56 байт.
/// Один и тот же ключ даёт ту же раскладку на любом устройстве и в любой
/// сборке — 🔴 поэтому формулу и порядок байтов НЕ МЕНЯТЬ: у людей, которые
/// сравнивают узоры при встрече, они разошлись бы.
///
/// Раскладка считается один раз на ключ и хранится в небольшом кэше —
/// каждый кадр её не строят.
class KeyFingerprintLayout {
  KeyFingerprintLayout._(this.arcs, this.dots);

  final List<KeyFingerprintArc> arcs;
  final List<KeyFingerprintDot> dots;

  static const List<(double, int, double, double)> rings = [
    (86, 24, 3, 0.22),
    (112, 32, 2.4, 0.17),
    (138, 40, 2, 0.13),
  ];
  static const int dotCount = 56;
  static const double dotRadius = 164;
  static const int dotBand = 5;
  static const double dotSpeed = 0.006;
  static const double dotAlpha = 0.16;
  static const double ringSpeed = 0.012;

  /// Ключ для превью и плиток выбора, когда настоящего ключа рядом нет.
  static final List<int> previewSeed = crypto.sha256
      .convert(utf8.encode('secretly-key-fingerprint-preview-v1'))
      .bytes;

  // Небольшой кэш по ключу: на экране обычно один-два профиля, в списке
  // выбора — превью.
  static final LinkedHashMap<String, KeyFingerprintLayout> _cache =
      LinkedHashMap<String, KeyFingerprintLayout>();
  static const int _cacheSize = 16;

  /// Раскладка для [seed] (SHA-256 ключа); `null` или пусто — превью.
  static KeyFingerprintLayout of(List<int>? seed) {
    final s = (seed == null || seed.isEmpty) ? previewSeed : seed;
    final id = base64Encode(s);
    final hit = _cache.remove(id);
    if (hit != null) {
      _cache[id] = hit;
      return hit;
    }
    final built = build(s);
    _cache[id] = built;
    while (_cache.length > _cacheSize) {
      _cache.remove(_cache.keys.first);
    }
    return built;
  }

  /// Строит раскладку без кэша (для проверок).
  static KeyFingerprintLayout build(List<int> seed) {
    final stream = <int>[...seed];
    var counter = 1;
    var pos = 0;
    double next() {
      while (pos >= stream.length) {
        stream.addAll(crypto.sha256.convert([...seed, counter & 0xff]).bytes);
        counter++;
      }
      return stream[pos++] / 255;
    }

    final arcs = <KeyFingerprintArc>[];
    for (var ri = 0; ri < rings.length; ri++) {
      final (r, n, w, al) = rings[ri];
      for (var i = 0; i < n; i++) {
        final b = next();
        if (b < 0.18) continue;
        arcs.add(
          KeyFingerprintArc(
            ring: ri,
            band: ri * 2,
            radius: r,
            width: w,
            alpha: al,
            start: i / n * math.pi * 2,
            sweep: (0.3 + b * 0.6) * (math.pi * 2 / n),
            speed: (ri.isOdd ? -1 : 1) * ringSpeed,
          ),
        );
      }
    }
    final dots = <KeyFingerprintDot>[
      for (var i = 0; i < dotCount; i++)
        KeyFingerprintDot(
          start: i / dotCount * math.pi * 2,
          size: 0.8 + next() * 1.8,
        ),
    ];
    return KeyFingerprintLayout._(
      List<KeyFingerprintArc>.unmodifiable(arcs),
      List<KeyFingerprintDot>.unmodifiable(dots),
    );
  }
}

// ── Знаки ─────────────────────────────────────────────────────────────────

/// Буква S гребнями отпечатка: три параллельные «S» со сдвигом — как
/// линии пальца. Задана в квадрате 1×1 с центром в (0,0).
final Path _printPath = () {
  final p = Path();
  for (final o in const [-0.12, 0.0, 0.12]) {
    final w = 0.30 + o;
    p
      ..moveTo(w, -0.30 - o * 0.4)
      ..cubicTo(w - 0.05, -0.44 - o, -w - 0.02, -0.46 - o, -w, -0.22)
      ..cubicTo(-w + 0.02, 0.02, w - 0.02, -0.04, w, 0.20)
      ..cubicTo(w + 0.02, 0.44 + o, -w + 0.05, 0.46 + o, -w, 0.30 + o * 0.4);
  }
  return p;
}();

/// Облачко сообщения с хвостиком.
final Path _bubblePath = () {
  final r = RRect.fromRectAndRadius(
    const Rect.fromLTWH(-0.42, -0.34, 0.84, 0.58),
    const Radius.circular(0.22),
  );
  return Path()
    ..addRRect(r)
    ..moveTo(-0.22, 0.22)
    ..lineTo(-0.30, 0.42)
    ..lineTo(-0.04, 0.24);
}();

final Path _sparkPath = () {
  // Четыре луча с вогнутыми сторонами.
  return Path()
    ..moveTo(0, -0.5)
    ..quadraticBezierTo(0.06, -0.06, 0.5, 0)
    ..quadraticBezierTo(0.06, 0.06, 0, 0.5)
    ..quadraticBezierTo(-0.06, 0.06, -0.5, 0)
    ..quadraticBezierTo(-0.06, -0.06, 0, -0.5)
    ..close();
}();

// ── Рисовальщик ───────────────────────────────────────────────────────────

class PatternCoverPainter extends CustomPainter {
  PatternCoverPainter({
    required this.style,
    required this.input,
    required this.bands,
    required this.time,
    required this.ink,
    this.inkStrength = 1,
    this.keyBytes,
    super.repaint,
  });

  final PatternCoverStyle style;
  final PatternCoverInput input;
  final List<double> bands;

  /// Секунды с начала (для «дыхания» узора).
  final double time;

  /// Цвет узора: белый в тёмной теме, тёмно-синий в светлой.
  final Color ink;

  /// Множитель прозрачности (светлая тема — 0,7).
  final double inkStrength;

  /// SHA-256 ключа личности — только для [PatternCoverStyle.fingerprint];
  /// `null` — превью ([KeyFingerprintLayout.previewSeed]).
  final List<int>? keyBytes;

  @override
  void paint(Canvas canvas, Size size) {
    final c = input.collapse.clamp(0.0, 1.0);
    final ec = input.expanded.clamp(0.0, 1.0);
    final ga = (1 - ec) * (1 - ((c - 0.3) / 0.6).clamp(0.0, 1.0));
    if (ga <= 0.002 || size.isEmpty) return;
    // Макет рисован на ширине 390 — масштабируем, центр по ширине.
    final scale = size.width / 390;
    canvas.save();
    canvas.scale(scale);
    final cx = 195.0;
    final cy = input.avatarCenterY / scale;
    final fadeY = input.fadeY / scale;
    final p = input.pull / 240;
    final t = time;
    final b = bands;
    final fill = Paint()
      ..color = ink
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    double alphaAt(double y, double a) {
      final fy = ((fadeY - y) / 50).clamp(0.0, 1.0);
      final al = a * ga * inkStrength * fy;
      return al <= 0.003 ? 0 : al.clamp(0.0, 1.0);
    }

    double halo(double d, [double a = 72, double bb = 170, double f = 110]) =>
        ((d - a) / 40).clamp(0.0, 1.0) * (1 - ((d - bb) / f).clamp(0.0, 1.0));

    void put(PatternGlyph g, double x, double y, double s, double a) {
      final al = alphaAt(y, a);
      if (al == 0) return;
      _glyph(canvas, g, x, y, s, al, fill, stroke);
    }

    final layout = _layoutFor(style);
    final items = layout.items;
    switch (style) {
      case PatternCoverStyle.orbits:
        for (final it in items) {
          final f = b[it.band];
          final a = it.angle + t * it.speed;
          final r = it.radius * f;
          final tw = 0.7 + 0.3 * math.sin(t * 0.9 + it.phase);
          put(
            it.glyph,
            cx + math.cos(a) * r,
            cy + math.sin(a) * r * 0.94,
            it.size * (1 + p * 0.3),
            (0.2 - it.ring * 0.04) * tw * (1 - p * 0.3 * it.ring),
          );
        }
      case PatternCoverStyle.monogram:
        final dx = (t * 4) % 46;
        for (final it in items) {
          final f = b[it.band];
          final x = it.x + dx;
          put(
            it.glyph,
            cx + x * f,
            cy + it.y * f,
            it.size,
            0.15 * halo(math.sqrt(x * x + it.y * it.y)),
          );
        }
      case PatternCoverStyle.bubbles:
        for (final it in items) {
          // Всплывают без состояния: положение — от времени.
          final span = 510.0;
          final yy = ((it.y - t * it.speed) % span + span) % span - 30;
          final f = b[it.band];
          final bx = it.x + math.sin(t * 0.6 + it.phase) * 6;
          final x = cx + (bx - cx) * f;
          final y = cy + (yy - cy) * f;
          final dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
          final hole = ((dist - 62) / 30).clamp(0.0, 1.0);
          final a = (0.05 + it.z * 0.13) * hole;
          put(PatternGlyph.print, x, y, it.size * 0.75, a);
          final al = alphaAt(y, a * 0.8);
          if (al > 0) {
            stroke
              ..strokeWidth = 1
              ..color = ink.withValues(alpha: al);
            canvas.drawCircle(
              Offset(x, y + it.size * 0.04),
              it.size * 0.55,
              stroke,
            );
          }
        }
      case PatternCoverStyle.constellation:
        final pts = [
          for (final it in items)
            Offset(cx + it.x * b[it.band], cy + it.y * b[it.band]),
        ];
        stroke.strokeWidth = 0.8;
        for (final (i, j, d) in layout.links) {
          final y = (pts[i].dy + pts[j].dy) / 2;
          final al = alphaAt(y, 0.1 * (1 - d / 62) + 0.03);
          if (al == 0) continue;
          stroke.color = ink.withValues(alpha: al);
          canvas.drawLine(pts[i], pts[j], stroke);
        }
        for (var i = 0; i < items.length; i++) {
          final it = items[i];
          final tw = 0.55 + 0.45 * math.sin(t * 1.3 + it.phase);
          final al = alphaAt(pts[i].dy, (it.big ? 0.32 : 0.2) * tw);
          if (al == 0) continue;
          if (it.big) {
            _glyph(canvas, PatternGlyph.spark, pts[i].dx, pts[i].dy, 9, al,
                fill, stroke);
          } else {
            fill.color = ink.withValues(alpha: al);
            canvas.drawCircle(pts[i], 1.4, fill);
          }
        }
      case PatternCoverStyle.ripples:
        stroke.strokeWidth = 1;
        for (final it in items) {
          final ph = (t * 0.09 + it.ring / 5) % 1;
          final r0 = 74 + ph * 220;
          final band = math.min(5, ((r0 - 70) / 45).floor());
          final r = r0 * b[band];
          final a = 0.2 * math.sin(ph * math.pi) * (1 - ph * 0.4);
          // Кольцо — дугами, чтобы гаснуть ниже линии кнопок.
          for (var k = 0; k < 48; k++) {
            final a0 = k / 48 * math.pi * 2;
            final y = cy + math.sin(a0) * r;
            final al = alphaAt(y, a * 0.7);
            if (al == 0) continue;
            stroke.color = ink.withValues(alpha: al);
            canvas.drawArc(
              Rect.fromCircle(center: Offset(cx, cy), radius: r),
              a0,
              math.pi * 2 / 48 + 0.004,
              false,
              stroke,
            );
          }
          for (var k = 0; k < 6; k++) {
            final ang =
                k / 6 * math.pi * 2 +
                t * 0.15 * (it.ring.isOdd ? 1 : -1) +
                it.ring;
            put(
              k == 0 ? PatternGlyph.print : PatternGlyph.dot,
              cx + math.cos(ang) * r,
              cy + math.sin(ang) * r,
              k == 0 ? 13 : 22,
              a * 1.4,
            );
          }
        }
      case PatternCoverStyle.rays:
        stroke.strokeWidth = 1.6;
        for (final it in items) {
          final f = b[it.band];
          final a = it.angle + t * 0.03;
          final len = 12 + 22 * (0.5 + 0.5 * math.sin(t * 0.8 + it.phase));
          final r1 = 84 * f;
          final r2 = (84 + len + it.band * 10) * f;
          final x1 = cx + math.cos(a) * r1, y1 = cy + math.sin(a) * r1;
          final x2 = cx + math.cos(a) * r2, y2 = cy + math.sin(a) * r2;
          final al = alphaAt((y1 + y2) / 2, 0.16 - it.band * 0.025);
          if (al > 0) {
            stroke.color = ink.withValues(alpha: al);
            canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stroke);
          }
          put(
            PatternGlyph.dot,
            cx + math.cos(a) * (r2 + 14 * f),
            cy + math.sin(a) * (r2 + 14 * f),
            18,
            0.12,
          );
        }
      case PatternCoverStyle.halftone:
        for (final it in items) {
          final f = b[it.band];
          final wave = 0.55 + 0.45 * math.sin(it.d * 0.045 - t * 1.1);
          final r = 2.3 * halo(it.d, 70, 150, 140) * wave;
          final x = cx + it.x * f, y = cy + it.y * f;
          if (r <= 0.25) continue;
          final al = alphaAt(y, 0.22);
          if (al == 0) continue;
          fill.color = ink.withValues(alpha: al);
          canvas.drawCircle(Offset(x, y), r, fill);
        }
      case PatternCoverStyle.spiral:
        for (final it in items) {
          final f = b[it.band];
          final a = it.angle + t * 0.025;
          final r = it.radius * f;
          put(
            it.glyph,
            cx + math.cos(a) * r,
            cy + math.sin(a) * r,
            it.size,
            0.19 * (1 - math.min(1, (it.radius - 74) / 220)),
          );
        }
      case PatternCoverStyle.rain:
        for (final it in items) {
          final yr = ((it.y + t * it.speed) % 480) - 170;
          final f = b[it.band];
          final x = cx + it.x * f, y = cy + yr * f;
          final d = math.sqrt(it.x * it.x + yr * yr);
          put(
            it.glyph,
            x,
            y,
            it.size,
            0.17 * halo(d, 70, 200, 120) * math.min(1, (yr + 170) / 60),
          );
        }
      case PatternCoverStyle.honeycomb:
        stroke.strokeWidth = 1;
        for (final it in items) {
          final hl = halo(it.d, 74, 160, 120);
          if (hl <= 0) continue;
          final f = b[it.band];
          final x = cx + it.x * f, y = cy + it.y * f;
          final br = 0.75 + 0.25 * math.sin(t * 0.9 - it.d * 0.03);
          final r = it.radius * 0.78 * br;
          final al = alphaAt(y, 0.15 * hl);
          if (al == 0) continue;
          stroke.color = ink.withValues(alpha: al);
          final hex = Path();
          for (var k = 0; k < 6; k++) {
            final a = math.pi / 6 + k * math.pi / 3;
            final px = x + math.cos(a) * r, py = y + math.sin(a) * r;
            k == 0 ? hex.moveTo(px, py) : hex.lineTo(px, py);
          }
          canvas.drawPath(hex..close(), stroke);
        }
      case PatternCoverStyle.fingerprint:
        final fp = KeyFingerprintLayout.of(keyBytes);
        final center = Offset(cx, cy);
        for (final arc in fp.arcs) {
          final f = b[arc.band];
          final a = arc.start + t * arc.speed;
          final r = arc.radius * f;
          final al = alphaAt(cy + math.sin(a + arc.sweep / 2) * r, arc.alpha);
          if (al == 0) continue;
          stroke
            ..strokeWidth = arc.width
            ..color = ink.withValues(alpha: al);
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: r),
            a,
            arc.sweep,
            false,
            stroke,
          );
        }
        final fd = b[KeyFingerprintLayout.dotBand];
        final rd = KeyFingerprintLayout.dotRadius * fd;
        for (final dot in fp.dots) {
          final a = dot.start + t * KeyFingerprintLayout.dotSpeed;
          final y = cy + math.sin(a) * rd;
          final al = alphaAt(y, KeyFingerprintLayout.dotAlpha);
          if (al == 0) continue;
          fill.color = ink.withValues(alpha: al);
          canvas.drawCircle(Offset(cx + math.cos(a) * rd, y), dot.size, fill);
        }
      case PatternCoverStyle.fireflies ||
          PatternCoverStyle.smark ||
          PatternCoverStyle.soda ||
          PatternCoverStyle.burgers ||
          PatternCoverStyle.planes ||
          PatternCoverStyle.balloons ||
          PatternCoverStyle.coffee ||
          PatternCoverStyle.donuts ||
          PatternCoverStyle.icecream ||
          PatternCoverStyle.popcorn ||
          PatternCoverStyle.suits:
        paintPatternCoverExtra(
          canvas,
          style,
          PatternExtraFrame(
            t: t,
            bands: b,
            cx: cx,
            cy: cy,
            fadeY: fadeY,
            p: p,
            ga: ga,
            k: inkStrength,
            ink: ink,
          ),
        );
      case PatternCoverStyle.champagne ||
          PatternCoverStyle.gems ||
          PatternCoverStyle.perfume ||
          PatternCoverStyle.macarons ||
          PatternCoverStyle.watches ||
          PatternCoverStyle.movement ||
          PatternCoverStyle.armillary ||
          PatternCoverStyle.cards ||
          PatternCoverStyle.gifts ||
          PatternCoverStyle.ornaments ||
          PatternCoverStyle.snowflakes ||
          PatternCoverStyle.snowman ||
          PatternCoverStyle.tangerines ||
          PatternCoverStyle.gingerbread ||
          PatternCoverStyle.sparkler ||
          PatternCoverStyle.bells ||
          PatternCoverStyle.cocoa ||
          PatternCoverStyle.tree ||
          PatternCoverStyle.snowglobe:
        paintPatternCoverStaff(
          canvas,
          style,
          PatternExtraFrame(
            t: t,
            bands: b,
            cx: cx,
            cy: cy,
            fadeY: fadeY,
            p: p,
            ga: ga,
            k: inkStrength,
            ink: ink,
          ),
        );
    }
    canvas.restore();
  }

  void _glyph(
    Canvas canvas,
    PatternGlyph g,
    double x,
    double y,
    double s,
    double alpha,
    Paint fill,
    Paint stroke,
  ) {
    final color = ink.withValues(alpha: alpha);
    switch (g) {
      case PatternGlyph.dot:
        fill.color = color;
        canvas.drawCircle(Offset(x, y), s * 0.1, fill);
      case PatternGlyph.diamond:
        fill.color = color;
        final h = s * 0.24;
        canvas.drawPath(
          Path()
            ..moveTo(x, y - h)
            ..lineTo(x + h, y)
            ..lineTo(x, y + h)
            ..lineTo(x - h, y)
            ..close(),
          fill,
        );
      case PatternGlyph.spark:
        fill.color = color;
        canvas.save();
        canvas.translate(x, y);
        canvas.scale(s * 0.62);
        canvas.drawPath(_sparkPath, fill);
        canvas.restore();
      case PatternGlyph.print:
      case PatternGlyph.bubble:
        canvas.save();
        canvas.translate(x, y);
        canvas.scale(s);
        stroke
          ..color = color
          ..strokeWidth = (g == PatternGlyph.print ? 1.1 : 1.2) / s;
        canvas.drawPath(
          g == PatternGlyph.print ? _printPath : _bubblePath,
          stroke,
        );
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(PatternCoverPainter old) =>
      old.time != time ||
      old.style != style ||
      old.input != input ||
      old.ink != ink ||
      old.inkStrength != inkStrength ||
      !_sameKey(old.keyBytes, keyBytes) ||
      !_sameBands(old.bands, bands);

  static bool _sameKey(List<int>? a, List<int>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameBands(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.0005) return false;
    }
    return true;
  }
}

// ── Подложка: подсветка из цвета аватара и виньетка из цвета фона ────────

/// Подсветка за аватаром (радиальный переход в цвет фона на 290 px) и
/// виньетка по бокам и снизу из цвета фона — узор растворяется в
/// странице, а не обрезается.
///
/// [ownTint] — у обложки свой глубокий фон ([patternCoverOwnTint], третья
/// волна): как `applyTint` макета — эллипс 120 % × 78 % обложки, цвет
/// сплошной до 46 % и дальше переходит в цвет страницы; виньетка чуть уже
/// (бока 22 %, верх 53 % → 0 за 16 %, низ с 60 %). Прежним узорам — как было.
class PatternCoverBackdrop extends StatelessWidget {
  const PatternCoverBackdrop({
    super.key,
    required this.tint,
    required this.background,
    required this.avatarCenterY,
    this.ownTint = false,
    required this.child,
  });

  final Color tint;
  final Color background;
  final double avatarCenterY;
  final bool ownTint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth.isFinite ? box.maxWidth : 390.0;
        final h = box.maxHeight.isFinite ? box.maxHeight : 460.0;
        final clear = background.withValues(alpha: 0);
        final Gradient glow;
        if (ownTint) {
          // Макет: центр на 26 % высоты (≈ на 9 px ниже центра аватара).
          final cy = avatarCenterY + 9;
          final ry = 0.78 * h;
          glow = RadialGradient(
            center: Alignment(0, (cy / h) * 2 - 1),
            radius: ry / math.min(w, h),
            colors: [tint, tint, background],
            stops: const [0, 0.46, 1],
            transform: _StretchX(Offset(w / 2, cy), 1.2 * w / ry),
          );
        } else {
          glow = RadialGradient(
            center: Alignment(0, (avatarCenterY / h) * 2 - 1),
            radius: 290 / math.max(w, h),
            colors: [tint, background],
          );
        }
        return ClipRect(
          child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(decoration: BoxDecoration(gradient: glow)),
            child,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [background, clear, clear, background],
                    stops: ownTint
                        ? const [0, 0.22, 0.78, 1]
                        : const [0, 0.24, 0.76, 1],
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      background.withValues(alpha: ownTint ? 0x88 / 255 : 0.6),
                      clear,
                      clear,
                      background,
                    ],
                    stops: ownTint
                        ? const [0, 0.16, 0.6, 1]
                        : const [0, 0.18, 0.62, 1],
                  ),
                ),
              ),
            ),
          ],
          ),
        );
      },
    );
  }
}

/// Растягивает круговой градиент по ширине вокруг точки [center] (в
/// координатах рамки) — эллипс, как `radial-gradient(120% 78%)` макета.
class _StretchX extends GradientTransform {
  const _StretchX(this.center, this.sx);

  final Offset center;
  final double sx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.left + center.dx;
    return Matrix4(sx, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, cx * (1 - sx), 0, 0, 1);
  }
}

/// Подсветка из цвета аватара: в светлой теме — пастель, в тёмной —
/// глубокий тон.
Color patternCoverTint(Color avatar, Brightness brightness) {
  final hsl = HSLColor.fromColor(avatar);
  return brightness == Brightness.dark
      ? hsl.withSaturation(math.min(0.45, hsl.saturation)).withLightness(0.25).toColor()
      : hsl.withSaturation(math.min(0.55, hsl.saturation)).withLightness(0.9).toColor();
}

/// Цвет узора темы.
Color patternCoverInk(Brightness brightness) => brightness == Brightness.dark
    ? Colors.white
    : const Color(0xFF1F2D45);

double patternCoverInkStrength(Brightness brightness) =>
    brightness == Brightness.dark ? 1 : 0.7;

/// Резинка натяжения макета: `d·(1 − 1/(x·0,55/d + 1))`.
double profileRubber(double x, double d) =>
    x <= 0 ? 0 : d * (1 - 1 / (x * 0.55 / d + 1));
