// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_manager.dart';

// Сигналы звонка едут через ящик реле и приходят в ЛЮБОМ порядке. Отбой может
// обогнать приглашение — и тогда телефон звонил по звонку, который звонящий уже
// отменил. Владелец описал это как «островок не уходит после отмены».
void main() {
  test('🔴 отбой с ПУСТЫМ состоянием не совпадает — его нельзя терять', () {
    // Именно из-за этого отбой раньше молча отбрасывался: сверять было не с чем.
    // Значит его обязаны ЗАПОМНИТЬ как завершённую попытку, а не выкинуть.
    expect(
      CallManager.shouldAcceptSignalForCurrentCall(
        currentCallId: '',
        currentCallAttemptId: '',
        signalCallId: 'call-1',
        signalCallAttemptId: 'att-1',
      ),
      isFalse,
    );
  });

  test('отбой по своему звонку принимается', () {
    expect(
      CallManager.shouldAcceptSignalForCurrentCall(
        currentCallId: 'call-1',
        currentCallAttemptId: 'att-1',
        signalCallId: 'call-1',
        signalCallAttemptId: 'att-1',
      ),
      isTrue,
    );
  });

  test('отбой по ЧУЖОМУ звонку не принимается', () {
    // Иначе отбой одного звонка гасил бы другой.
    expect(
      CallManager.shouldAcceptSignalForCurrentCall(
        currentCallId: 'call-1',
        currentCallAttemptId: 'att-1',
        signalCallId: 'call-2',
        signalCallAttemptId: 'att-2',
      ),
      isFalse,
    );
  });

  test('🔴 ключ завершённой попытки устойчив и различает попытки', () {
    // На этом ключе держится подавление опоздавшего приглашения. Пустой callId
    // ключа не даёт — иначе одна пустая строка «завершила» бы все звонки разом.
    expect(
      CallManager.endedCallAttemptKey(callId: '', callAttemptId: 'a'),
      isEmpty,
    );
    final k1 = CallManager.endedCallAttemptKey(
      callId: 'call-1',
      callAttemptId: 'att-1',
    );
    final k2 = CallManager.endedCallAttemptKey(
      callId: 'call-1',
      callAttemptId: 'att-2',
    );
    expect(k1, isNotEmpty);
    expect(k1, isNot(equals(k2)), reason: 'разные попытки — разные ключи');
    // Пустая попытка приравнивается к callId — иначе отбой без attemptId не
    // сошёлся бы с приглашением, у которого он есть.
    expect(
      CallManager.endedCallAttemptKey(callId: 'call-1', callAttemptId: ''),
      CallManager.endedCallAttemptKey(
        callId: 'call-1',
        callAttemptId: 'call-1',
      ),
    );
  });
}
