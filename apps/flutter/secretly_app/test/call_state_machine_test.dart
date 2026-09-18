// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/calls/call_state.dart';
import 'package:secretly_app/calls/call_state_machine.dart';

void main() {
  group('reduceCallLifecycle', () {
    test('supports the full outgoing lifecycle', () {
      var state = CallLifecycleState.idle;

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.localStartCall,
        wasEverConnected: false,
      )!;
      expect(state, CallLifecycleState.outgoingInviting);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.localOfferCreated,
        wasEverConnected: false,
      )!;
      expect(state, CallLifecycleState.offerNegotiation);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.remoteAnswerReceived,
        wasEverConnected: false,
      )!;
      expect(state, CallLifecycleState.connectingMedia);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.mediaEstablished,
        wasEverConnected: false,
      )!;
      expect(state, CallLifecycleState.connected);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.peerconnectionFailed,
        wasEverConnected: true,
      )!;
      expect(state, CallLifecycleState.reconnecting);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.transportReconnected,
        wasEverConnected: true,
      )!;
      expect(state, CallLifecycleState.connected);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.localHangup,
        wasEverConnected: true,
      )!;
      expect(state, CallLifecycleState.ending);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.cleanupCompleted,
        wasEverConnected: true,
      )!;
      expect(state, CallLifecycleState.ended);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.reset,
        wasEverConnected: true,
      )!;
      expect(state, CallLifecycleState.idle);
    });

    test('supports incoming accept and answer negotiation lifecycle', () {
      var state = CallLifecycleState.idle;

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.remoteOfferReceived,
        wasEverConnected: false,
      )!;
      expect(state, CallLifecycleState.incomingRinging);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.localAccept,
        wasEverConnected: false,
      )!;
      expect(state, CallLifecycleState.accepting);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.remoteOfferReceived,
        wasEverConnected: false,
      )!;
      expect(state, CallLifecycleState.answerNegotiation);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.localAnswerCreated,
        wasEverConnected: false,
      )!;
      expect(state, CallLifecycleState.connectingMedia);
    });

    test('keeps reconnect renegotiation inside reconnecting lifecycle', () {
      var state = CallLifecycleState.connected;

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.transportLost,
        wasEverConnected: true,
      )!;
      expect(state, CallLifecycleState.reconnecting);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.remoteOfferReceived,
        wasEverConnected: true,
      )!;
      expect(state, CallLifecycleState.reconnecting);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.localAnswerCreated,
        wasEverConnected: true,
      )!;
      expect(state, CallLifecycleState.reconnecting);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.transportReconnected,
        wasEverConnected: true,
      )!;
      expect(state, CallLifecycleState.connected);
    });

    test('keeps duplicate terminal events idempotent after call end', () {
      var state = CallLifecycleState.connected;

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.remoteHangup,
        wasEverConnected: true,
      )!;
      expect(state, CallLifecycleState.ending);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.cleanupCompleted,
        wasEverConnected: true,
      )!;
      expect(state, CallLifecycleState.ended);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.remoteHangup,
        wasEverConnected: true,
      )!;
      expect(state, CallLifecycleState.ended);

      state = reduceCallLifecycle(
        current: state,
        event: CallLifecycleEvent.remoteDecline,
        wasEverConnected: true,
      )!;
      expect(state, CallLifecycleState.ended);
    });

    test('treats connect timeout as terminal from connecting and reconnecting', () {
      var connectingState = CallLifecycleState.connectingMedia;
      connectingState = reduceCallLifecycle(
        current: connectingState,
        event: CallLifecycleEvent.connectTimeout,
        wasEverConnected: false,
      )!;
      expect(connectingState, CallLifecycleState.ending);

      var reconnectingState = CallLifecycleState.reconnecting;
      reconnectingState = reduceCallLifecycle(
        current: reconnectingState,
        event: CallLifecycleEvent.connectTimeout,
        wasEverConnected: true,
      )!;
      expect(reconnectingState, CallLifecycleState.ending);
    });

    test('rejects invalid transitions', () {
      expect(
        reduceCallLifecycle(
          current: CallLifecycleState.idle,
          event: CallLifecycleEvent.localAnswerCreated,
          wasEverConnected: false,
        ),
        isNull,
      );
      expect(
        reduceCallLifecycle(
          current: CallLifecycleState.incomingRinging,
          event: CallLifecycleEvent.remoteAnswerReceived,
          wasEverConnected: false,
        ),
        isNull,
      );
    });
  });

  group('callPhaseForLifecycle', () {
    test('maps detailed lifecycle states onto stable UI phases', () {
      expect(
        callPhaseForLifecycle(CallLifecycleState.outgoingInviting),
        CallPhase.ringingOutgoing,
      );
      expect(
        callPhaseForLifecycle(CallLifecycleState.accepting),
        CallPhase.connecting,
      );
      expect(
        callPhaseForLifecycle(CallLifecycleState.connected),
        CallPhase.connected,
      );
      expect(
        callPhaseForLifecycle(CallLifecycleState.ending),
        CallPhase.ended,
      );
    });
  });
}
