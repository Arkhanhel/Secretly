// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/transport/server_clock.dart';

/// 🔴 ПОДПИСЬ ЗАПРОСОВ К РЕЛЕ ИДЁТ ИСПРАВЛЕННЫМ ВРЕМЕНЕМ.
///
/// Механизм поправки жил с 26.08, но применялся только на пути сервера ключей,
/// и то не везде. Путь реле подписывал СЫРЫМ временем устройства — поэтому
/// телефон с отставшими часами регистрировался на ключах и не мог ничего на
/// реле. Обращение в поддержку 12.09: «System errors», HTTP 401, три сброса
/// профиля впустую.
///
/// Замер того же дня: 13 отказов подряд, ВСЕ «отстаёт», спешащих ноль.
void main() {
  setUp(() => ServerClock.instance.resetForTest());
  tearDown(() => ServerClock.instance.resetForTest());

  test('🔴 без расхождения поправка НИЧЕГО не меняет — правка безопасна', () {
    // Главное свойство: для здорового устройства новое поведение тождественно
    // старому. Именно оно делает замену в двадцати двух местах безопасной.
    final before = DateTime.now().millisecondsSinceEpoch;
    final signed = ServerClock.instance.nowMs();
    final after = DateTime.now().millisecondsSinceEpoch;
    expect(signed, greaterThanOrEqualTo(before));
    expect(signed, lessThanOrEqualTo(after));
    expect(ServerClock.instance.offsetMs, 0);
  });

  test('отставшие часы исправляются в плюс', () {
    // Сервер на десять минут впереди — устройство отстаёт.
    final serverNow = DateTime.now().toUtc().add(const Duration(minutes: 10));
    expect(ServerClock.instance.observeServerDate(serverNow), isTrue);

    final corrected = ServerClock.instance.nowMs();
    final raw = DateTime.now().millisecondsSinceEpoch;
    final gapMin = (corrected - raw) / 60000.0;
    expect(gapMin, closeTo(10, 0.5),
        reason: 'подпись обязана уехать вперёд на величину расхождения');
  });

  test('🔴 исправленное время укладывается в пятиминутное окно сервера', () {
    // Ровно тот случай, что ломал людей: часы отстают на одиннадцать минут.
    final serverNow = DateTime.now().toUtc().add(const Duration(minutes: 11));
    ServerClock.instance.observeServerDate(serverNow);

    final serverMs = serverNow.millisecondsSinceEpoch;
    final signedMs = ServerClock.instance.nowMs();
    final driftMin = (signedMs - serverMs).abs() / 60000.0;
    expect(driftMin, lessThan(5),
        reason: 'без поправки здесь было бы 11 минут и отказ 401');
  });

  test('🔴 дикое расхождение отбрасывается — лекарство не хуже болезни', () {
    // Больше недели: это не сбитые часы, а неизвестная ситуация. Слепо
    // доверять такой поправке нельзя — она сделала бы недействительными и те
    // запросы, которые сейчас проходят. (Граница была сутки; с 17.09 — неделя:
    // в поле дата «на день вперёд» оказалась за прежней границей.)
    final wild = DateTime.now().toUtc().add(const Duration(days: 8));
    expect(ServerClock.instance.observeServerDate(wild), isFalse);
    expect(ServerClock.instance.offsetMs, 0);
  });

  test('сетевой шум поправкой не считается', () {
    final noise = DateTime.now().toUtc().add(const Duration(seconds: 3));
    ServerClock.instance.observeServerDate(noise);
    expect(ServerClock.instance.offsetMs, 0,
        reason: 'меньше десяти секунд — это задержка сети, а не часы');
  });

  test('поправка пересматривается, когда человек починил часы', () {
    ServerClock.instance.observeServerDate(
      DateTime.now().toUtc().add(const Duration(minutes: 30)),
    );
    expect(ServerClock.instance.hasSkew, isTrue);

    // Человек включил автоматическое время — расхождения больше нет.
    ServerClock.instance.observeServerDate(DateTime.now().toUtc());
    expect(ServerClock.instance.hasSkew, isFalse,
        reason: 'застрявшая поправка была бы хуже отсутствия поправки');
  });
}
