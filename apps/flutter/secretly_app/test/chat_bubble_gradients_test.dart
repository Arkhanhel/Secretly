// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// НОВЫЙ НАБОР ГРАДИЕНТОВ ПУЗЫРЕЙ (23.09.2026, страница дизайна владельца).
//
// 🔴 ГЛАВНОЕ, ЧТО ЗДЕСЬ СТЕРЕЖЁТСЯ — ЧУЖОЙ ВЫБОР. Набор заменён целиком, а у
// людей выбранный градиент сохранён по опознавателю. Опознаватель, который
// больше ни на что не указывает, тихо откатил бы человека на первый в списке —
// он бы решил, что настройка слетела сама.
//
// Поэтому каждый прежний опознаватель обязан вести на живой новый.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/theme_presets.dart';

/// Опознаватели, которые существовали до замены (19 наборов + 7 прежних
/// псевдонимов). Список записан здесь НАМЕРЕННО: он и есть обещание, данное
/// людям, которые эти градиенты выбрали.
const _oldIds = <String>[
  'flutter_dash', 'ocean', 'graphite', 'amethyst', 'sunset', 'aurora',
  'rosewood', 'toplenoe_moloko', 'noch_na_marse', 'mint_aqua', 'deep_plum',
  'coral_pink', 'royal_magenta', 'cyan_violet', 'pink_violet', 'sunset_coral',
  'sky_cobalt', 'midnight_indigo', 'electric_lilac',
  'forest_teal', 'graphite_cool', 'mint_ink', 'aurora_steel', 'violet_night',
  'sunset_fusion', 'arctic_glow',
];

void main() {
  test('новых наборов двадцать, опознаватели не повторяются', () {
    expect(kChatBubbleStylePresets, hasLength(20));
    final ids = kChatBubbleStylePresets.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('🔴 КАЖДЫЙ прежний опознаватель ведёт на живой набор', () {
    final live = kChatBubbleStylePresets.map((p) => p.id).toSet();
    for (final old in _oldIds) {
      final resolved = normalizeChatBubbleStylePresetId(old);
      expect(
        live.contains(resolved),
        isTrue,
        reason: '«$old» ведёт на «$resolved», которого нет — выбор сбросится',
      );
    }
  });

  test('🔴 пустой опознаватель даёт существующий набор, а не пустоту', () {
    final id = normalizeChatBubbleStylePresetId('');
    expect(kChatBubbleStylePresets.map((p) => p.id), contains(id));
  });

  test('неизвестный опознаватель не роняет приложение', () {
    expect(resolveChatBubbleStylePreset('такого-нет'), isNotNull);
  });

  group('цвета перехода', () {
    test('порядок точек: верх → середины → низ', () {
      for (final p in kChatBubbleStylePresets) {
        for (final dark in [true, false]) {
          final c = p.colorsFor(dark);
          expect(c.length, inInclusiveRange(2, 4), reason: p.id);
          expect(c.first, dark ? p.darkTop : p.lightTop);
          expect(c.last, dark ? p.darkBottom : p.lightBottom);
        }
      }
    });

    test('🔴 помощник НЕ изменил поведение двух- и трёхцветных наборов', () {
      // Он заменил пятнадцать рукописных троек. Для наборов без второй
      // середины список обязан совпадать с тем, что собирали руками, —
      // иначе замена молча перекрасила бы переписки.
      for (final p in kChatBubbleStylePresets) {
        for (final dark in [true, false]) {
          final mid = dark ? p.darkMid : p.lightMid;
          final mid2 = dark ? p.darkMid2 : p.lightMid2;
          if (mid2 != null) continue;
          final top = dark ? p.darkTop : p.lightTop;
          final bottom = dark ? p.darkBottom : p.lightBottom;
          final byHand = mid != null
              ? <Color>[top, mid, bottom]
              : <Color>[top, bottom];
          expect(p.colorsFor(dark), byHand, reason: p.id);
        }
      }
    });

    test('четырёхцветные наборы и правда несут четыре точки', () {
      final four = kChatBubbleStylePresets
          .where((p) => p.colorsFor(true).length == 4)
          .map((p) => p.id)
          .toList();
      // «Нефтяная плёнка», «Синтвейв», «Ртуть» — ради четвёртой точки их и
      // рисовали; свести их к трём значило бы выбросить смысл перехода.
      expect(four, hasLength(3), reason: 'четырёхцветные: $four');
    });
  });

  test('у каждого набора есть название на обоих языках', () {
    for (final p in kChatBubbleStylePresets) {
      expect(p.nameRu.trim(), isNotEmpty, reason: p.id);
      expect(p.nameEn.trim(), isNotEmpty, reason: p.id);
    }
  });
}
