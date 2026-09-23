// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// B-6: ПЕРЕХОД К ДАТЕ В ПЕРЕПИСКЕ.
//
// 🔴 На телефоне это барабан из трёх колёс (`search_date_carousel.dart`) — там
// он уместен, пальцем крутить удобно. На компьютере крутить колесо мышью
// мучительно, поэтому взят системный календарь: человек его уже знает, и он сам
// переведён на все наши языки.
//
// Проверяется здесь не календарь (он не наш), а выбор сообщения по дню —
// единственное место, где мы можем ошибиться.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/chat/chat_thread_panel.dart';

int _ms(int y, int m, int d, [int hh = 12]) =>
    DateTime(y, m, d, hh).millisecondsSinceEpoch;

void main() {
  final stamps = <int>[
    _ms(2026, 5, 28), // 0
    _ms(2026, 6, 3, 9), // 1 — первое сообщение 3 июня
    _ms(2026, 6, 3, 18), // 2
    _ms(2026, 6, 11), // 3
  ];

  test('выбранный день → ПЕРВОЕ сообщение этого дня', () {
    expect(indexForDate(stamps, DateTime(2026, 6, 3)), 1);
  });

  test('🔴 день без сообщений → ближайшее ПОЗЖЕ, а не раньше', () {
    // Человек, выбравший 1 июня, тянулся к началу разговора и готов читать
    // вниз. Прыжок назад, в 28 мая, выглядел бы промахом: он увидел бы
    // переписку, к которой не тянулся, и не понял бы, сработал ли выбор.
    expect(indexForDate(stamps, DateTime(2026, 6, 1)), 1);
  });

  test('день раньше всей переписки → самое первое сообщение', () {
    expect(indexForDate(stamps, DateTime(2020, 1, 1)), 0);
  });

  test('день позже всей переписки → последнее, а не пустота', () {
    // Честнее показать конец переписки, чем не сделать ничего и оставить
    // человека гадать, нажалась ли кнопка.
    expect(indexForDate(stamps, DateTime(2030, 1, 1)), stamps.length - 1);
  });

  test('пустая переписка — ничего', () {
    expect(indexForDate(const <int>[], DateTime(2026, 6, 3)), isNull);
  });

  test('🔴 время суток не влияет: день считается с полуночи', () {
    // 3 июня в 23:59 — всё ещё 3 июня, и прыгать надо к утреннему сообщению.
    expect(indexForDate(stamps, DateTime(2026, 6, 3, 23, 59)), 1);
  });
}
