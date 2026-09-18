// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ПОПРАВКА К ЧАСАМ УСТРОЙСТВА.
//
// Запросы к серверу ключей подписываются вместе с временной меткой, и сервер
// отвергает метку, разошедшуюся с его часами больше чем на пять минут. Защита
// от повторного воспроизведения запроса — правильная.
//
// 🔴 Но человеку со сбитыми часами она закрывает всё: подписанные запросы не
// принимаются, список устройств собеседника не получить, а без него сообщение
// некуда отправить. Поле 26.08.2026: шесть устройств дали около четырёх тысяч
// отказов `timestamp out of range` за трое суток, у одного — двадцать восемь в
// час непрерывно. Их владельцы видели только, что сообщения не уходят.
//
// Поправка берётся из заголовка `Date` обычных ответов. Тесты ниже сторожат не
// столько её применение, сколько ГРАНИЦЫ: неверная поправка сделает
// недействительными и те запросы, которые сейчас проходят.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/transport/server_clock.dart';

void main() {
  setUp(() => ServerClock.instance.resetForTest());
  tearDown(() => ServerClock.instance.resetForTest());

  test('без сверки поправки нет — метка остаётся своей', () {
    final own = DateTime.now().millisecondsSinceEpoch;
    expect(ServerClock.instance.offsetMs, 0);
    expect((ServerClock.instance.nowMs() - own).abs(), lessThan(1000));
  });

  test('🔴 расхождение в минуты компенсируется', () {
    // Часы устройства отстали на три минуты — как у тех, кто не может писать.
    final serverTime = DateTime.now().toUtc().add(const Duration(minutes: 3));
    ServerClock.instance.observeServerDate(serverTime);

    final signed = ServerClock.instance.nowMs();
    final serverMs = serverTime.millisecondsSinceEpoch;
    expect(
      (signed - serverMs).abs(),
      lessThan(2000),
      reason: 'подписанная метка не совпала со временем сервера — запрос '
          'по-прежнему будет отвергнут',
    );
  });

  test('сетевой шум поправкой не считается', () {
    // Секунда разницы — это дорога до сервера, а не сбитые часы. Реагировать на
    // неё значит дёргать метку на каждом запросе без всякой пользы.
    ServerClock.instance.observeServerDate(
      DateTime.now().toUtc().add(const Duration(seconds: 1)),
    );
    expect(ServerClock.instance.offsetMs, 0);
    expect(ServerClock.instance.hasSkew, isFalse);
  });

  test('🔴 нелепой разнице не доверяем', () {
    // Больше недели — это не сбитые часы, а что-то, чего мы не понимаем.
    // Принять такую поправку значит сломать и те запросы, что сейчас проходят.
    ServerClock.instance.observeServerDate(
      DateTime.now().toUtc().add(const Duration(days: 8)),
    );
    expect(
      ServerClock.instance.offsetMs,
      0,
      reason: 'поправка в восемь суток принята вслепую',
    );
  });

  test('🔴 дата на день вперёд — поправка применяется (поле 17.09)', () {
    // Устройство спешит на 24 ч 03,6 мин: при прежней границе в сутки такой
    // человек не мог ничего, и новая сборка его бы не вылечила.
    final serverTime = DateTime.now().toUtc().subtract(
      const Duration(hours: 24, minutes: 3, seconds: 36),
    );
    ServerClock.instance.observeServerDate(serverTime);
    expect(
      (ServerClock.instance.nowMs() - serverTime.millisecondsSinceEpoch).abs(),
      lessThan(2000),
      reason: 'сдвиг чуть больше суток должен компенсироваться',
    );
  });

  test('поправка работает в обе стороны', () {
    ServerClock.instance.observeServerDate(
      DateTime.now().toUtc().subtract(const Duration(minutes: 4)),
    );
    expect(
      ServerClock.instance.offsetMs,
      lessThan(0),
      reason: 'часы устройства спешат — поправка обязана быть отрицательной',
    );
  });

  test('поправка обновляется, когда часы поправили', () {
    ServerClock.instance.observeServerDate(
      DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
    expect(ServerClock.instance.hasSkew, isTrue);

    // Человек включил автоматическое время — расхождение исчезло.
    ServerClock.instance.observeServerDate(DateTime.now().toUtc());
    expect(
      ServerClock.instance.offsetMs,
      0,
      reason: 'старая поправка продолжает применяться после того, как часы '
          'выправились — теперь она сама и ломает метку',
    );
  });
}
