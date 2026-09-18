// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Два последних «·» закрыты РЕШЕНИЕМ, а не правкой — и решение записано.
//
// Оба пункта ТЗ прямо допускали такой исход: «зафиксировать это как осознанное
// отличие», «решение владельца, а не правка». Опасность у записанного решения
// одна: через полгода оно читается как «забыли». Поэтому причина лежит там,
// где её станут искать — в самом коде, — а этот файл следит, чтобы она не
// исчезла вместе с очередной правкой соседней строки.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/shell/sidebar.dart';

void main() {
  group('· состав и порядок разделов рейки', () {
    final src = File(
      'lib/ui/desktop/shell/sidebar.dart',
    ).readAsStringSync();

    test('разделов по-прежнему четыре, и в своём порядке', () {
      expect(DesktopSection.values, [
        DesktopSection.chats,
        DesktopSection.rooms,
        DesktopSection.calls,
        DesktopSection.contacts,
      ]);
    });

    test('🔴 причина расхождения с макетом записана', () {
      expect(src.contains('СОСТАВ И ПОРЯДОК РАЗДЕЛОВ — РЕШЕНИЕ'), isTrue);
      // Названы обе половины: чего нет из макета и что есть сверх него.
      expect(src.contains('«Сохранённого» нет, потому что сохранять НЕКУДА'),
          isTrue);
      expect(src.contains('отдельный склад'), isTrue);
    });

    test('сказано, почему порядок НЕ переставлен', () {
      // ТЗ предлагало «минимум» — чаты → звонки → люди → комнаты. Отказ
      // должен быть объяснён, иначе это просто невыполненный пункт.
      expect(src.contains('ПОРЯДОК ОСТАВЛЕН СВОЙ'), isTrue);
      expect(src.contains('Cmd 1..4'), isTrue);
    });

    test('подписи горячих клавиш совпадают с порядком плиток', () {
      // Если порядок однажды поменяют, подписи обязаны поехать следом:
      // «Cmd 2» на третьей плитке хуже, чем отсутствие подсказки.
      final order = <String>[];
      for (final m in RegExp(r"'(Cmd \d)',").allMatches(src)) {
        order.add(m.group(1)!);
      }
      expect(order, ['Cmd 1', 'Cmd 2', 'Cmd 3', 'Cmd 4']);
    });
  });

  group('· рисование поверх демонстрации', () {
    final src = File(
      'lib/ui/desktop/calls/room_call_window.dart',
    ).readAsStringSync();

    test('чипа «Рисовать» нет', () {
      expect(src.contains("'Рисовать'"), isFalse);
    });

    test('🔴 прежняя причина отказа исправлена как неверная', () {
      // В ТЗ стояло «канала данных в протоколе нет». Созвон идёт через
      // настоящую lk.Room, у которой есть publishData: канал есть, и врать
      // про его отсутствие нельзя даже в свою пользу.
      expect(src.contains('ОКАЗАЛАСЬ НЕВЕРНОЙ'), isTrue);
      expect(src.contains('publishData'), isTrue);
    });

    test('названа настоящая причина — проверить с одной машины нельзя', () {
      expect(src.contains('ПРОВЕРИТЬ ЭТО С ОДНОЙ МАШИНЫ НЕЛЬЗЯ'), isTrue);
    });

    test('🔴 местного рисования «для себя» тоже нет', () {
      // Подпись обещает общий холст. Чип, который рисует только у тебя, —
      // обещание, нарушенное при первом же «где?» от собеседника.
      expect(src.contains('Локальное рисование «для себя» поэтому тоже не'),
          isTrue);
    });
  });
}
