// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';

/// 🔴 ЗАМЕР ВОССТАНОВЛЕНИЯ: ЧАСЫ + КАЛИТКА ВМЕСТЕ.
///
/// До сегодняшнего дня эти две части проверялись порознь, и дефект жил ровно
/// в шве: калитка (16 тестов) получала `epochAheadStuckMs` числом, а часы,
/// которые это число дают, не проверял никто. В жизни они обнулялись каждой
/// успешной расшифровкой, и калитка не открывалась НИКОГДА.
///
/// Полевой замер 12.09.2026: смс пришли в 08:42, починка сессии ушла в 09:30 —
/// **1 час 48 минут** вместо заложенных двух минут.
///
/// Здесь обе части соединены и время подаётся снаружи — это и есть замер.
void main() {
  const gap = 5 * 60 * 1000;
  const t0 = 1_800_000_000_000;
  const twoMin = 120_000;

  /// Прогон живого сценария: отказы `epoch_ahead` вперемешку с успешными
  /// расшифровками от того же устройства — ровно то, что было на аккаунте.
  /// Возвращает, через сколько миллисекунд калитка открылась (-1 — не открылась).
  int measureRecoveryMs({required int totalMs, required int stepMs}) {
    final clock = EpochAheadStreakClock(gapMs: gap);
    for (var t = 0; t <= totalMs; t += stepMs) {
      // На каждом шаге сначала успех по СТАРОЙ эпохе (другие сообщения от
      // того же устройства проходят нормально — так и было в поле),
      // затем отказ по НОВОЙ.
      clock.onDecryptSuccess('peer', t0 + t);
      final stuckMs = clock.onEpochAheadFailure('peer', t0 + t);
      final allowed = AppController.i4ReactiveResetAllowed(
        gateEnabled: true,
        isEpochAhead: true,
        isGenuineMac: false,
        consecutiveFailures: 10,
        epochAheadStuckMs: stuckMs,
      );
      if (allowed) return t;
    }
    return -1;
  }

  test('🔴 ЗАМЕР: восстановление укладывается в две минуты', () {
    // Успех и отказ каждые двадцать секунд — как в поле.
    final recoveredAtMs = measureRecoveryMs(
      totalMs: 30 * 60 * 1000, // даём полчаса
      stepMs: 20_000,
    );

    expect(recoveredAtMs, isNot(-1),
        reason: 'калитка обязана открыться — до правки она не открывалась НИКОГДА');
    expect(
      recoveredAtMs,
      lessThanOrEqualTo(twoMin + 20_000),
      reason: 'порог две минуты плюс один шаг; в поле было 1 ч 48 мин '
          '(${(recoveredAtMs / 1000).round()} с в этом замере)',
    );
  });

  test('частые сообщения не отодвигают восстановление', () {
    // Оживлённая переписка: успех и отказ каждые две секунды.
    final fast = measureRecoveryMs(totalMs: 10 * 60 * 1000, stepMs: 2000);
    expect(fast, isNot(-1));
    expect(fast, lessThanOrEqualTo(twoMin + 2000),
        reason: 'чем чаще успехи, тем раньше калитка закрывалась раньше — '
            'теперь частота не влияет вовсе');
  });

  test('🔴 раньше двух минут калитка НЕ открывается — спешка тоже вредна', () {
    final clock = EpochAheadStreakClock(gapMs: gap);
    clock.onEpochAheadFailure('peer', t0);
    // Полторы минуты — перешифровка может быть ещё в пути, дёргать рано.
    final stuckMs = clock.onEpochAheadFailure('peer', t0 + 90_000);
    expect(
      AppController.i4ReactiveResetAllowed(
        gateEnabled: true,
        isEpochAhead: true,
        isGenuineMac: false,
        consecutiveFailures: 10,
        epochAheadStuckMs: stuckMs,
      ),
      isFalse,
      reason: 'запас на доставку перешифровки обязан сохраниться',
    );
  });
}
