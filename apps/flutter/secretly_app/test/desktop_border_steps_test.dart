// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// · Ступени границ и наведения, сверенные с исходником макета.
//
// ЧТО БЫЛО. Ступеней границы было ДВЕ: 0x0F (≈5.9 %) и 0x1A (≈10.2 %). В
// макете их четыре, и самая частая — .07 (49 вхождений, обводка контролов) —
// выражалась через 5.9 %, а разделитель панели (.05, 33 вхождения) — через
// 10.2 %, то есть ВДВОЕ ярче нужного: тонкая черта, которая должна лишь
// намекать на край, рисовалась заметнее обводки кнопки рядом.
//
// Наведение было ≈5.1 % при нажатии 10.2 %: наведение едва читалось, а
// нажатие било вдвое. В макете наведение — единая величина .07.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';

double alphaOf(int argb) => ((argb >> 24) & 0xFF) / 255.0;

void main() {
  test('· волосяная линия тише обводки контрола', () {
    expect(alphaOf(kDColorsDark.borderHairline.toARGB32()), closeTo(0.05, 0.005));
    expect(alphaOf(kDColorsDark.borderSubtle.toARGB32()), closeTo(0.07, 0.005));
    expect(
      kDColorsDark.borderHairline.toARGB32() <
          kDColorsDark.borderSubtle.toARGB32(),
      isTrue,
    );
  });

  test('· рамка меню — самая заметная ступень', () {
    // Меню всплывает поверх чужого содержимого: это единственная граница,
    // которая обязана быть видна сама по себе.
    expect(alphaOf(kDColorsDark.borderMenu.toARGB32()), closeTo(0.12, 0.005));
    expect(
      kDColorsDark.borderMenu.toARGB32() >
          kDColorsDark.borderSubtle.toARGB32(),
      isTrue,
    );
  });

  test('ступени заведены и в светлой теме', () {
    // Иначе светлая тема осталась бы на двух ступенях, а тёмная на четырёх —
    // и правка одной перестала бы значить что-либо для другой.
    expect(
      kDColorsLight.borderHairline.toARGB32() <
          kDColorsLight.borderSubtle.toARGB32(),
      isTrue,
    );
    expect(
      kDColorsLight.borderMenu.toARGB32() >
          kDColorsLight.borderSubtle.toARGB32(),
      isTrue,
    );
  });

  test('· наведение — .07, шаг до нажатия мягкий, а не двукратный', () {
    final hover = alphaOf(kDColorsDark.hover.toARGB32());
    final pressed = alphaOf(kDColorsDark.pressed.toARGB32());
    expect(hover, closeTo(0.07, 0.005));
    expect(pressed, greaterThan(hover));
    // Было вдвое (5.1 -> 10.2). Стало меньше полутора.
    expect(pressed / hover, lessThan(1.5));
  });

  test('названные места переведены на волосяную линию', () {
    final chrome = File(
      'lib/ui/desktop/shell/window_chrome.dart',
    ).readAsStringSync();
    final list = File(
      'lib/ui/desktop/chat/chat_list_panel.dart',
    ).readAsStringSync();
    final menu = File(
      'lib/ui/desktop/primitives/context_menu.dart',
    ).readAsStringSync();
    expect(chrome.contains('color: c.borderHairline'), isTrue);
    expect(list.contains('color: colors.borderHairline'), isTrue);
    expect(menu.contains('Border.all(color: c.borderMenu)'), isTrue);
  });
}
