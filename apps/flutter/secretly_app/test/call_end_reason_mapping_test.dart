// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/calls/call_event.dart';
import 'package:secretly_app/calls/call_failure.dart';
import 'package:secretly_app/calls/call_state.dart';

void main() {
  group('callRecordResultFromEndReason', () {
    test('maps remote superseded attempts to failed result', () {
      expect(
        callRecordResultFromEndReason(
          reason: CallEndReason.remoteSuperseded,
          didConnect: false,
          direction: CallRecordDirection.outgoing,
        ),
        CallRecordResult.failed,
      );
    });

    test('keeps remote hangup semantics unchanged', () {
      expect(
        callRecordResultFromEndReason(
          reason: CallEndReason.remoteHangup,
          didConnect: true,
          direction: CallRecordDirection.outgoing,
        ),
        CallRecordResult.completed,
      );
    });

    // 🔴 Чья это лента (07.08.2026, поле: «есть пузырь о "Отменённом звонке",
    // а не пропущенном»). Один и тот же обрыв означает разное с разных сторон,
    // и раньше обе стороны получали точку зрения звонившего.
    test('входящий без соединения — ПРОПУЩЕННЫЙ, кто бы ни оборвал', () {
      for (final reason in const [
        CallEndReason.remoteHangup, // звонивший передумал
        CallEndReason.localHangup, // я убрал звонок, не приняв
      ]) {
        expect(
          callRecordResultFromEndReason(
            reason: reason,
            didConnect: false,
            direction: CallRecordDirection.incoming,
          ),
          CallRecordResult.missed,
          reason: '$reason',
        );
      }
    });

    test('исходящий без соединения остаётся ОТМЕНЁННЫМ', () {
      // Обратная защёлка: «отменил» — это про того, кто звонил. Утащить сюда
      // «пропущенный» значило бы сказать человеку, что он пропустил свой
      // собственный звонок.
      expect(
        callRecordResultFromEndReason(
          reason: CallEndReason.localHangup,
          didConnect: false,
          direction: CallRecordDirection.outgoing,
        ),
        CallRecordResult.canceled,
      );
    });

    test('осознанный отказ остаётся ОТКЛОНЁННЫМ, а не пропущенным', () {
      // Граница правки: «Отклонить» приходит своей причиной и обязано остаться
      // отказом. Иначе разница между «не услышал» и «не захотел» исчезает.
      expect(
        callRecordResultFromEndReason(
          reason: CallEndReason.localDecline,
          didConnect: false,
          direction: CallRecordDirection.incoming,
        ),
        CallRecordResult.declined,
      );
    });
  });

  group('call reason parsers', () {
    test('parseCallEndReason accepts known values and rejects unknown ones', () {
      expect(parseCallEndReason('timeout'), CallEndReason.timeout);
      expect(parseCallEndReason('remoteHangup'), CallEndReason.remoteHangup);
      expect(parseCallEndReason(''), isNull);
      expect(parseCallEndReason('not-a-reason'), isNull);
    });

    test('parseCallFailureCode accepts known values and rejects unknown ones', () {
      expect(
        parseCallFailureCode('connectionInterrupted'),
        CallFailureCode.connectionInterrupted,
      );
      expect(
        parseCallFailureCode('signalingConflict'),
        CallFailureCode.signalingConflict,
      );
      expect(parseCallFailureCode(''), isNull);
      expect(parseCallFailureCode('not-a-code'), isNull);
    });
  });
}