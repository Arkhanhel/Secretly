// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Каждый заказ сброса сессии обязан называть причину.
//
// Сброс инициируется из ЧЕТЫРНАДЦАТИ мест (карта — в
// docs/AUDIT_SESSION_RESET_SURFACE_2026-08-23.md), восемь из них обходят
// дебаунс, у четырёх нет ограничителя вовсе. При этом в логе было событие
// «сброс заказан» и ни слова о том, КТО его заказал: разбор петли «пинг самому
// себе» 23.08 занял час именно поэтому.
//
// Это шаг ① плана: пока только наблюдение, поведение не меняется. Но без него
// шаги ②–④ (замер, пределы, сокращение точек) были бы догадками, поэтому тест
// сторожит полноту: ни один вызов не имеет права остаться безымянным.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/app/app_controller.dart').readAsStringSync();

  test('ни один заказ сброса не остался без причины', () {
    // Вызовы вида `_scheduleSessionResetPing(x)` / `_forceSessionResetPing(x)`
    // с ОДНИМ аргументом — это точка, забывшая назвать себя.
    final anonymous = RegExp(
      r'_(?:schedule|force|dispatch)SessionResetPing\(\s*[^,)]+\s*\)',
    ).allMatches(source).map((m) => m.group(0)).toList();
    expect(anonymous, isEmpty,
        reason: 'эти вызовы не называют причину:\n${anonymous.join("\n")}');
  });

  test('причина доезжает до лога и до счётчиков', () {
    expect(source.contains("'cause': cause"), isTrue,
        reason: 'причина снова не попадает в reset_ping_enqueued');
    expect(source.contains('_sessionResetCauseCounts[cause]'), isTrue,
        reason: 'счётчик по причинам не ведётся — замер шага ② невозможен');
    expect(source.contains('sessionResetCauseCounts'), isTrue);
  });

  test('отказы тоже называют причину', () {
    // «Не сбросили» без указания, кто просил, так же слепо, как «сбросили».
    expect(source.contains("'debounce:\$cause'"), isTrue,
        reason: 'отказ по дебаунсу не говорит, чей заказ отклонён');
    expect(source.contains("'unreachable:\$cause'"), isTrue);
  });

  test('счётчики видны в диагностике', () {
    final diag = File('lib/ui/diagnostics_screen.dart').readAsStringSync();
    expect(diag.contains('session_resets:'), isTrue,
        reason: 'замер снова требует поднимать логи');
  });
}
