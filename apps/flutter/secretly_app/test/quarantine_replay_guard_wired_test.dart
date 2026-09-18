// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🔴 ПАУЗА ОБЯЗАНА СТОЯТЬ В КАЖДОМ ЗАХОДЕ ПЕРЕИГРОВКИ, А НЕ В ОДНОМ.
///
/// ЗАМЕР ПОЛЯ 15.08 (сборка 522, через час после выпуска): правило паузы было
/// верным, тест на правило — зелёным, а шторм лечения остался. Проверку
/// поставили в заход по отправителю и ЗАБЫЛИ в заходе по всей парковке; там
/// добавили только счётчик пропусков и печать. Счётчик навсегда остался нулём,
/// печать молчала — и это молчание неотличимо от «нечего было пропускать».
/// Поле: `replay_reset_ping dev=baecdd9f failures=6` — шесть мёртвых конвертов
/// одним заходом.
///
/// Тест на чистое правило такой дефект поймать НЕ МОЖЕТ: правило исправно, не
/// подключён вызов. Поэтому проверяется именно проводка — каждый вызов
/// переигровки обязан иметь паузу перед собой в той же функции.
void main() {
  test('🔴 у каждой переигровки карантина есть пауза перед ней', () {
    final src = File('lib/app/app_controller.dart').readAsStringSync();

    // Границы функций: от объявления до следующего объявления верхнего уровня
    // внутри класса (два пробела отступа + сигнатура).
    final replayCalls = 'fromQuarantineReplay: true'.allMatches(src).toList();
    expect(
      replayCalls.length,
      greaterThanOrEqualTo(2),
      reason: 'заходов переигровки меньше, чем было, — тест устарел, проверить',
    );

    for (final call in replayCalls) {
      // Ищем ближайшее объявление функции ВЫШЕ вызова и проверяем, что между
      // ними есть проверка паузы.
      final head = src.substring(0, call.start);
      final fnStart = head.lastIndexOf(RegExp(r'\n  (Future|void|bool)[<\s]'));
      expect(fnStart, greaterThan(0), reason: 'не нашли начало функции');
      final body = src.substring(fnStart, call.start);
      expect(
        body.contains('_quarantineReplayTooSoon('),
        isTrue,
        reason: 'переигровка без паузы — это и есть шторм лечения; '
            'позиция вызова: ${call.start}',
      );
    }
  });

  test('🔴 заход по молчанию отсеивает мертвецов ДО рассылки лечения', () {
    // ЗАМЕР 523: `_runSilenceRecoveryForPeer` слал лечение каждому устройству
    // из `contact_devices` — включая копию, молчащую пятые сутки, каждые 4,5
    // минуты. Проверка Л-4 стояла в `_scheduleSessionResetPing`, а этот заход
    // зовёт `_forceSessionResetPing` и проходил мимо неё.
    final src = File('lib/app/app_controller.dart').readAsStringSync();
    final start = src.indexOf('Future<void> _runSilenceRecoveryForPeer(');
    expect(start, greaterThan(0), reason: 'функция переименована — обновить тест');
    final end = src.indexOf('\n  /// Кого из устройств', start);
    expect(end, greaterThan(start));
    final body = src.substring(start, end);

    expect(
      body.contains('_forceSessionResetPing('),
      isTrue,
      reason: 'заход перестал лечить вовсе — это другая правка, проверить',
    );
    expect(
      body.indexOf('_healTargetsForSilenceRecovery('),
      lessThan(body.indexOf('_forceSessionResetPing(')),
      reason: 'отсев обязан идти ДО рассылки, иначе он ничего не отсекает',
    );
  });

  test('🔴 счётчик пропусков не печатается там, где его некому увеличить', () {
    // Печать без увеличения — «замер, который не умеет провалиться».
    final src = File('lib/app/app_controller.dart').readAsStringSync();
    final prints = "'quarantine_replay_throttled'".allMatches(src).length;
    final bumps = 'skippedHopeless += 1'.allMatches(src).length;
    expect(
      bumps,
      greaterThanOrEqualTo(prints),
      reason: 'на каждую печать пропусков обязан быть свой пропуск',
    );
  });
}
