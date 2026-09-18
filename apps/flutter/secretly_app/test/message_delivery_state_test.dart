// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/messages/message_delivery_state.dart';

void main() {
  group('MessageLocalState', () {
    test('normalize trims and lowercases', () {
      expect(MessageLocalState.normalize('  SeNdInG  '), 'sending');
    });

    test('outgoing in-flight states are recognized', () {
      expect(MessageLocalState.isOutgoingInFlight(MessageLocalState.pending), isTrue);
      expect(MessageLocalState.isOutgoingInFlight(MessageLocalState.sending), isTrue);
      expect(MessageLocalState.isOutgoingInFlight(MessageLocalState.retry), isTrue);
      expect(MessageLocalState.isOutgoingInFlight(MessageLocalState.sent), isFalse);
    });

    test('outgoing actionable states are recognized', () {
      expect(MessageLocalState.isOutgoingActionable(MessageLocalState.pending), isTrue);
      expect(MessageLocalState.isOutgoingActionable(MessageLocalState.failed), isTrue);
      expect(MessageLocalState.isOutgoingActionable(MessageLocalState.delivered), isFalse);
    });

    test('terminal states are recognized', () {
      expect(MessageLocalState.isTerminal(MessageLocalState.failed), isTrue);
      expect(MessageLocalState.isTerminal(MessageLocalState.read), isTrue);
      expect(MessageLocalState.isTerminal(MessageLocalState.sent), isFalse);
    });

    test('can promote to sent only from in-flight states', () {
      expect(
        MessageLocalState.canPromote(
          from: MessageLocalState.pending,
          to: MessageLocalState.sent,
        ),
        isTrue,
      );
      expect(
        MessageLocalState.canPromote(
          from: MessageLocalState.delivered,
          to: MessageLocalState.sent,
        ),
        isFalse,
      );
    });

    test('can promote to delivered from sent and in-flight states', () {
      expect(
        MessageLocalState.canPromote(
          from: MessageLocalState.sent,
          to: MessageLocalState.delivered,
        ),
        isTrue,
      );
      expect(
        MessageLocalState.canPromote(
          from: MessageLocalState.read,
          to: MessageLocalState.delivered,
        ),
        isFalse,
      );
    });

    test('can promote to read from any non-read state', () {
      expect(
        MessageLocalState.canPromote(
          from: MessageLocalState.delivered,
          to: MessageLocalState.read,
        ),
        isTrue,
      );
      expect(
        MessageLocalState.canPromote(
          from: MessageLocalState.read,
          to: MessageLocalState.read,
        ),
        isTrue,
      );
    });
  });

  group('OutboxSendState', () {
    test('due states are recognized', () {
      expect(OutboxSendState.isDueState(OutboxSendState.pending), isTrue);
      expect(OutboxSendState.isDueState(OutboxSendState.sending), isTrue);
      expect(OutboxSendState.isDueState(OutboxSendState.retry), isTrue);
      expect(OutboxSendState.isDueState(OutboxSendState.sent), isFalse);
      expect(OutboxSendState.isDueState(OutboxSendState.failed), isFalse);
    });
  });
}
