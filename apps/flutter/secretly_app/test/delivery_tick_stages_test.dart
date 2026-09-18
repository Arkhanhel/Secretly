// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';
import 'package:secretly_app/ui/chat_screen.dart';

/// ТРИ СТУПЕНИ ИНДИКАТОРА ДОСТАВКИ (задано владельцем продукта 02.09.2026).
///
///   отправлено  → одна приглушённая галочка
///   доставлено  → одна яркая галочка
///   прочитано   → две яркие галочки
///
/// До этой правки «отправлено» и «доставлено» рисовались ОДИНАКОВО — одной и
/// той же галочкой одного и того же цвета. Разница между «ушло на сервер» и
/// «дошло до человека» на экране не читалась вовсе, хотя в данных эти
/// состояния всегда были разными.
void main() {
  group('ступени индикатора доставки', () {
    test('отправлено — одна приглушённая галочка', () {
      final style = chatDeliveryTickStyle(MessageLocalState.sent);
      expect(style, isNotNull);
      expect(style!.doubled, isFalse, reason: 'на этой ступени галочка одна');
      expect(
        style.alpha,
        lessThan(1.0),
        reason: 'приглушённость — единственное, чем «отправлено» отличается '
            'от «доставлено»: обе ступени рисуют по одной галочке',
      );
    });

    test('доставлено — одна яркая галочка', () {
      final style = chatDeliveryTickStyle(MessageLocalState.delivered);
      expect(style, isNotNull);
      expect(style!.doubled, isFalse);
      expect(style.alpha, 1.0);
    });

    test('прочитано — две яркие галочки', () {
      final style = chatDeliveryTickStyle(MessageLocalState.read);
      expect(style, isNotNull);
      expect(style!.doubled, isTrue);
      expect(style.alpha, 1.0);
    });

    test('🔴 отправлено и доставлено обязаны различаться на экране', () {
      final sent = chatDeliveryTickStyle(MessageLocalState.sent)!;
      final delivered = chatDeliveryTickStyle(MessageLocalState.delivered)!;
      expect(
        sent.alpha == delivered.alpha && sent.doubled == delivered.doubled,
        isFalse,
        reason: 'ровно этот дефект и правился: два разных состояния '
            'выглядели одинаково',
      );
    });

    test('доставлено и прочитано различаются количеством, а не яркостью', () {
      final delivered = chatDeliveryTickStyle(MessageLocalState.delivered)!;
      final read = chatDeliveryTickStyle(MessageLocalState.read)!;
      expect(read.doubled, isNot(delivered.doubled));
      expect(
        read.alpha,
        delivered.alpha,
        reason: 'обе ступени яркие; глаз считает галочки, а не оттенок',
      );
    });

    test('приглушённая ступень остаётся читаемой', () {
      final sent = chatDeliveryTickStyle(MessageLocalState.sent)!;
      expect(
        sent.alpha,
        greaterThanOrEqualTo(0.5),
        reason: 'ниже половины галочка тонет в фоне пузыря, особенно на '
            'светлых обоях чата',
      );
    });

    test('состояния без галочек не получают стиль', () {
      // Отправка в процессе рисуется часами, провал — красной галочкой,
      // отложенная отправка — своим значком. Ни одно из них не должно
      // случайно провалиться в обычную ветку галочек.
      for (final state in <String>[
        MessageLocalState.pending,
        MessageLocalState.sending,
        MessageLocalState.retry,
        MessageLocalState.failed,
        MessageLocalState.scheduled,
        MessageLocalState.received,
        '',
        'какая-то-чушь',
      ]) {
        expect(
          chatDeliveryTickStyle(state),
          isNull,
          reason: 'состояние "$state" галочками не рисуется',
        );
      }
    });

    test('регистр и пробелы не меняют ступень', () {
      expect(
        chatDeliveryTickStyle('  DELIVERED  '),
        chatDeliveryTickStyle(MessageLocalState.delivered),
        reason: 'состояние приходит из базы и из сети — нормализация обязана '
            'работать так же, как в остальном коде',
      );
    });
  });
}
