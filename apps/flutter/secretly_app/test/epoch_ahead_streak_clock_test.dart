// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

/// 🔴 ЧАСЫ ПОЛОСЫ `epoch_ahead` — ТО, ЧЕГО НЕ ПРОВЕРЯЛ НИ ОДИН ТЕСТ.
///
/// Правило реактивного сброса покрыто шестнадцатью тестами, но все они подают
/// `epochAheadStuckMs` числом напрямую. Дефект жил ровно в незакрытом месте:
/// правило верное, а часы обнулялись каждой успешной расшифровкой от того же
/// устройства — и двухминутный порог не достигался никогда.
///
/// Полевой замер 12.09.2026: сообщения пришли в 08:42, починка сессии ушла в
/// 09:30 — час сорок восемь вместо двух минут.
void main() {
  const gap = 5 * 60 * 1000; // разрыв, закрывающий полосу
  const t0 = 1_800_000_000_000;

  EpochAheadStreakClock clock() => EpochAheadStreakClock(gapMs: gap);

  test('🔴 успех ПОСРЕДИ полосы её не закрывает — тот самый дефект', () {
    final c = clock();
    // Отказ в нулевую секунду — полоса началась.
    expect(c.onEpochAheadFailure('peer', t0), 0);

    // Через минуту успешно расшифровался конверт под СТАРОЙ эпохой.
    c.onDecryptSuccess('peer', t0 + 60_000);

    // Ещё через минуту снова отказ. Полоса обязана продолжаться, а не начаться
    // заново: раньше здесь возвращался 0, и порог не достигался никогда.
    expect(
      c.onEpochAheadFailure('peer', t0 + 120_000),
      120_000,
      reason: 'успех под старой эпохой ничего не говорит про новую',
    );
  });

  test('порог в две минуты достигается при чередовании успехов и отказов', () {
    final c = clock();
    c.onEpochAheadFailure('peer', t0);
    // Жизнь, как она есть: успех, отказ, успех, отказ — каждые 20 секунд.
    var stuck = 0;
    for (var i = 1; i <= 7; i++) {
      final at = t0 + i * 20_000;
      c.onDecryptSuccess('peer', at);
      stuck = c.onEpochAheadFailure('peer', at);
    }
    expect(stuck, greaterThanOrEqualTo(120_000),
        reason: 'после 140 секунд полоса обязана перевалить за две минуты');
  });

  test('🔴 тишина дольше разрыва закрывает полосу — защита от вечной записи', () {
    final c = clock();
    c.onEpochAheadFailure('peer', t0);
    // Отказов больше нет, а через час приходит успех.
    c.onDecryptSuccess('peer', t0 + 3600_000);
    expect(c.hasStreak('peer'), isFalse, reason: 'полоса закрыта тишиной');
  });

  test('🔴 отказ после долгой тишины начинает НОВУЮ полосу, а не продолжает', () {
    final c = clock();
    c.onEpochAheadFailure('peer', t0);
    // Неделю ничего. Если бы запись просто висела, здесь вернулась бы неделя —
    // и сброс ударил бы мгновенно вместо положенных двух минут.
    expect(
      c.onEpochAheadFailure('peer', t0 + 7 * 24 * 3600_000),
      0,
      reason: 'разрыв обязан начинать отсчёт заново',
    );
  });

  test('сброс сессии закрывает полосу безусловно', () {
    final c = clock();
    c.onEpochAheadFailure('peer', t0);
    c.clear('peer');
    expect(c.hasStreak('peer'), isFalse);
    expect(c.onEpochAheadFailure('peer', t0 + 1000), 0,
        reason: 'после сброса отсчёт начинается заново');
  });

  test('устройства не путаются между собой', () {
    final c = clock();
    c.onEpochAheadFailure('a', t0);
    c.onEpochAheadFailure('b', t0 + 60_000);
    expect(c.onEpochAheadFailure('a', t0 + 90_000), 90_000);
    expect(c.onEpochAheadFailure('b', t0 + 90_000), 30_000);
  });

  test('пустой идентификатор не заводит запись', () {
    final c = clock();
    expect(c.onEpochAheadFailure('', t0), 0);
    expect(c.hasStreak(''), isFalse);
  });
}
