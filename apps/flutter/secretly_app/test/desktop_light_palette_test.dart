// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// · Светлая тема: сверять её с макетом не с чем, но держать в строю — можно.
//
// В файле макета все четыре артборда тёмные, светлых значений нет ни одного.
// Пункт ТЗ так и назывался — «kDColorsLight не сверить», и закрыть его правкой
// цветов нельзя: сверять не с чем.
//
// Закрывается он иначе. Светлый набор — ПРОИЗВОДНАЯ тёмного, и опасность у
// него ровно одна: тёмную палитру поправили, а светлую забыли, и окно в
// светлой схеме осталось жить со старым акцентом. Раньше это ловилось только
// глазами и только если кто-то вообще включал светлую тему.
//
// Теперь наборы связаны здесь: одни и те же поля и ни одного буквально
// скопированного значения. Буквальная копия — это и есть «забыли вывести»:
// именно так в светлой теме однажды оказался тёмный пузырь, на котором белые
// буквы стояли на грани читаемости.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

/// Разбирает `const DColorSet kDColors… = DColorSet(...)` в карту «поле → ARGB».
///
/// Через исходник, а не через объект: у `DColorSet` четыре десятка полей, и
/// перечислять их в тесте руками значит завести тот же список третьим местом,
/// которое снова забудут обновить.
Map<String, String> paletteFields(String name) {
  final src = File(
    'lib/ui/desktop/design/colors.dart',
  ).readAsStringSync();
  final start = src.indexOf('const DColorSet $name = DColorSet(');
  if (start < 0) throw StateError('набор $name не найден в colors.dart');
  final end = src.indexOf('\n);', start);
  final body = src.substring(start, end);
  final out = <String, String>{};
  for (final m in RegExp(
    r'^\s*(\w+): (?:const )?Color\((0x[0-9A-Fa-f]+)\)',
    multiLine: true,
  ).allMatches(body)) {
    out[m.group(1)!] = m.group(2)!.toLowerCase();
  }
  return out;
}

void main() {
  final dark = paletteFields('kDColorsDark');
  final light = paletteFields('kDColorsLight');

  test('· разбор нашёл оба набора целиком', () {
    expect(dark.length, greaterThan(35));
    expect(dark.length, light.length);
  });

  test('🔴 поля наборов совпадают', () {
    // Не «конструктор соберётся» — он и так требует все поля, — а «ни одно
    // поле не осталось на значении по умолчанию из соседнего набора».
    expect(light.keys.toSet().difference(dark.keys.toSet()), isEmpty);
    expect(dark.keys.toSet().difference(light.keys.toSet()), isEmpty);
  });

  test('🔴 ни одно значение не скопировано буквально', () {
    final copied = <String>[
      for (final k in dark.keys)
        if (dark[k] == light[k]) k,
    ];
    expect(
      copied,
      isEmpty,
      reason:
          'эти поля светлой темы буквально равны тёмным — значит их не '
          'выводили, а забыли: $copied',
    );
  });

  test('· светлая тема темнее по акценту, а не просто «другая»', () {
    // Приём 1 из докстринга: на белом тот же синий слепит.
    expect(
      HSVColor.fromColor(kDColorsLight.accentPrimary).value,
      lessThan(HSVColor.fromColor(kDColorsDark.accentPrimary).value),
    );
    expect(
      HSVColor.fromColor(kDColorsLight.success).value,
      lessThan(HSVColor.fromColor(kDColorsDark.success).value),
    );
  });

  test('· прозрачные слои светлой заданы по чёрному, тёмной — по белому', () {
    // Приём 2: наведение, границы и выделение — это доля подложки, а не цвет.
    for (final c in [
      kDColorsLight.hover,
      kDColorsLight.pressed,
      kDColorsLight.borderHairline,
      kDColorsLight.borderSubtle,
    ]) {
      expect(c.a, lessThan(1.0), reason: 'слой должен быть прозрачным');
      expect((c.r + c.g + c.b), 0.0, reason: 'доля по чёрному');
    }
    for (final c in [kDColorsDark.hover, kDColorsDark.pressed]) {
      expect(c.a, lessThan(1.0));
      expect(c.r + c.g + c.b, closeTo(3.0, 0.01), reason: 'доля по белому');
    }
  });

  test('🔴 своё правило непрочитанного действует в ОБЕИХ схемах', () {
    // Голубой — личные, фиолетовый — комнаты, красный — рейка и фильтры.
    for (final set in [kDColorsDark, kDColorsLight]) {
      expect(set.unreadDot, isNot(set.unreadRoom));
      expect(set.unreadRail, isNot(set.unreadDot));
      expect(set.unreadRail, isNot(set.unreadRoom));
      // Красный именно красный: у рейки он читается как «ждут ответа».
      final rail = HSVColor.fromColor(set.unreadRail);
      expect(rail.hue < 20 || rail.hue > 340, isTrue);
    }
  });

  test('· причина «сверять не с чем» записана рядом с набором', () {
    final src = File(
      'lib/ui/desktop/design/colors.dart',
    ).readAsStringSync();
    expect(src.contains('СВЕТЛАЯ ТЕМА — ПРОИЗВОДНАЯ, А НЕ ОТДЕЛЬНЫЙ МАКЕТ'),
        isTrue);
    expect(src.contains('все четыре артборда тёмные'), isTrue);
  });

  test('🔴 у счётчика непрочитанного больше не написано «красный»', () {
    // Комментарий пережил смену значений и утверждал обратное тому, что
    // стояло строкой ниже.
    final src = File(
      'lib/ui/desktop/design/colors.dart',
    ).readAsStringSync();
    expect(src.contains('Счётчик непрочитанного — КРАСНЫЙ'), isFalse);
  });
}
