// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Пустой чат — не всегда «переписки нет».
//
// Долг паритета d69fe6b3. Полевой отчёт мобильной версии 03.08.2026: пришло
// уведомление, человек нажал на него, попал в чат — а там пусто, и лишь секунд
// через пятнадцать появилось сообщение. Сообщение в тот момент лежало на реле:
// до первого разбора входящего ящика мы ещё НЕ ЗНАЕМ, пуст чат или нет, а
// показывали знание.
//
// Здесь закреплено правило и — главное — страховка от вечного кружка.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/app/desktop_chats_section.dart';

void main() {
  test('до первого разбора ящика пустота ещё неизвестна', () {
    expect(
      chatEmptinessStillUnknown(firstDrainDone: false, relayOnline: true),
      isTrue,
      reason: 'сообщение может лежать на реле — показывать «пусто» рано',
    );
  });

  test('после разбора ящика пустота настоящая', () {
    expect(
      chatEmptinessStillUnknown(firstDrainDone: true, relayOnline: true),
      isFalse,
      reason: 'реле отдало всё накопленное — теперь пусто значит пусто',
    );
  });

  test('🔴 без связи НЕ ждём — иначе кружок навсегда', () {
    expect(
      chatEmptinessStillUnknown(firstDrainDone: false, relayOnline: false),
      isFalse,
      reason: 'разбора не будет никогда, ждать нечего: человек должен увидеть '
          'чат, а не кружок до конца времён',
    );
  });

  test('связи нет и разбор прошёл — тем более не ждём', () {
    expect(
      chatEmptinessStillUnknown(firstDrainDone: true, relayOnline: false),
      isFalse,
    );
  });
}
