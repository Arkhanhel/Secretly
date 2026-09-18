// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🔴 ПРИБОР ЗВОНКА ОБЯЗАН БЫТЬ ПОДКЛЮЧЁН, А НЕ ПРОСТО НАПИСАН.
///
/// Аудит 15.08 показал: сбой звонка был неразбираем не по сложности, а потому
/// что все интересные решения молчали. Из 114 `catch`-блоков пути звонка в
/// релизе были видны 12; приём звонка выходил первой строкой без следа; отказ
/// отправки ответа писался свободным текстом, который в релизе отбрасывается.
///
/// Тест проверяет ПРОВОДКУ по исходнику, а не поведение: правило может быть
/// верным, а вызов — не подключённым. Ровно так сегодня уже случилось дважды
/// (пауза переигровки стояла в одном заходе из двух).
void main() {
  final callManager = File('lib/calls/call_manager.dart').readAsStringSync();

  String bodyOf(String signature, {String? until}) {
    final start = callManager.indexOf(signature);
    expect(start, greaterThan(0), reason: 'не найдено: $signature');
    final end = until == null
        ? start + 4000
        : callManager.indexOf(until, start);
    expect(end, greaterThan(start), reason: 'не найден конец: $until');
    return callManager.substring(start, end);
  }

  test('🔴 приём звонка не выходит молча', () {
    // Молчаливый выход из acceptIncoming — ведущая версия сбоя 15.08:
    // CallKit показывает живой звонок, а состояние Dart ещё не «звонит
    // входящий», и нажатие не оставляет следа.
    final body = bodyOf('Future<void> acceptIncoming() async {', until: 'try {');
    expect(
      body.contains('callOpLog('),
      isTrue,
      reason: 'выход по несовпадению фазы обязан печататься',
    );
    expect(
      body.indexOf('callOpLog('),
      lessThan(body.indexOf('return;')),
      reason: 'печать обязана стоять ДО выхода, иначе она недостижима',
    );
  });

  test('🔴 отказ отправки ответа виден так же, как успех', () {
    final start = callManager.indexOf('await controller.sendCallAnswer(');
    expect(start, greaterThan(0));
    final region = callManager.substring(start, start + 1600);
    final okAt = region.indexOf("'local_answer_sent'");
    final failAt = region.indexOf("'local_answer_send_failed'");
    expect(okAt, greaterThan(0), reason: 'успех печатался и раньше');
    expect(
      failAt,
      greaterThan(0),
      reason: 'отказ обязан печататься операционным событием, а не свободным '
          'текстом: в релизе свободный текст отбрасывается',
    );
  });

  test('🔴 судьба нажатия видна во всех трёх исходах', () {
    for (final event in <String>[
      'native_call_action_buffered', // легло в буфер
      'native_call_action_dropped_stale', // отброшено как устаревшее
      'native_call_action_no_op_phase', // принято, но фаза не та — ничего
      'buffered_native_action_flushed', // буфер разобран
      'buffered_native_action_mismatch', // буфер потерян: чужой звонок
    ]) {
      expect(
        callManager.contains("'$event'"),
        isTrue,
        reason: 'исход «$event» обязан быть наблюдаем: без него нажатие в '
            'пустоту неотличимо от успешного приёма',
      );
    }
  });

  test('🔴 переотправка ответа сообщает о своих неудачах', () {
    expect(callManager.contains("'answer_resend_failed'"), isTrue);
  });

  group('флаг диагностики собирает то, что обещает', () {
    // 🔴 `--call-logs` ставил ОДНУ переменную из двух и не менял ничего:
    // операционные события всё равно вычёркивались, свободный текст всё равно
    // отбрасывался. Разбор сбоя 15.08 тянулся именно за этот рычаг.
    for (final script in <String>[
      '../../../tools/macos_build_android_release.sh',
      '../../../tools/macos_build_ios_release.sh',
    ]) {
      // Скрипты сборки лежат в tools/ и в публичную выкладку не входят — там
      // проверять нечего, и тест честно пропускается, а не падает.
      test(script.split('/').last, () {
        final s = File(script).readAsStringSync();
        final start = s.indexOf(r'if [ "$call_logs" -eq 1 ]; then');
        expect(start, greaterThan(0), reason: 'блок --call-logs не найден');
        final block = s.substring(start, s.indexOf('\nfi', start));
        expect(
          block.contains('SECRETLY_ENABLE_CALL_LOGS_IN_RELEASE=true'),
          isTrue,
        );
        expect(
          block.contains('SECRETLY_REDACT_CALL_LOGS_IN_RELEASE=false'),
          isTrue,
          reason: 'без второй переменной флаг не включает НИЧЕГО',
        );
      },
          skip: File(script).existsSync()
              ? null
              : 'release build scripts live in tools/, which is not part of the '
                  'public repository');
    }
  });
}
