// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
enum CallLifecycleState {
  idle,
  outgoingInviting,
  incomingRinging,
  accepting,
  offerNegotiation,
  answerNegotiation,
  connectingMedia,
  connected,
  reconnecting,
  ending,
  ended,
}

enum CallLifecycleEvent {
  localStartCall,
  remoteInviteReceived,
  localAccept,
  localDecline,
  remoteDecline,
  localHangup,
  remoteHangup,
  localOfferCreated,
  remoteOfferReceived,
  localAnswerCreated,
  remoteAnswerReceived,
  remoteIceReceived,
  transportReconnected,
  transportLost,
  peerconnectionConnected,
  peerconnectionFailed,
  mediaEstablished,
  connectTimeout,
  ringTimeout,
  fatalError,
  cleanupCompleted,
  reset,
}

CallLifecycleState? reduceCallLifecycle({
  required CallLifecycleState current,
  required CallLifecycleEvent event,
  required bool wasEverConnected,
}) {
  switch (current) {
    case CallLifecycleState.idle:
      switch (event) {
        case CallLifecycleEvent.localStartCall:
          return CallLifecycleState.outgoingInviting;
        case CallLifecycleEvent.remoteInviteReceived:
        case CallLifecycleEvent.remoteOfferReceived:
          return CallLifecycleState.incomingRinging;
        case CallLifecycleEvent.reset:
          return CallLifecycleState.idle;
        default:
          return null;
      }
    case CallLifecycleState.outgoingInviting:
      switch (event) {
        case CallLifecycleEvent.localOfferCreated:
          return CallLifecycleState.offerNegotiation;
        case CallLifecycleEvent.remoteAnswerReceived:
          return CallLifecycleState.connectingMedia;
        case CallLifecycleEvent.localHangup:
        case CallLifecycleEvent.remoteHangup:
        case CallLifecycleEvent.remoteDecline:
        case CallLifecycleEvent.ringTimeout:
        case CallLifecycleEvent.connectTimeout:
        case CallLifecycleEvent.fatalError:
          return CallLifecycleState.ending;
        default:
          return null;
      }
    case CallLifecycleState.incomingRinging:
      switch (event) {
        case CallLifecycleEvent.localAccept:
          return CallLifecycleState.accepting;
        case CallLifecycleEvent.remoteInviteReceived:
        case CallLifecycleEvent.remoteOfferReceived:
        case CallLifecycleEvent.remoteIceReceived:
          return CallLifecycleState.incomingRinging;
        case CallLifecycleEvent.localDecline:
        case CallLifecycleEvent.remoteHangup:
        case CallLifecycleEvent.remoteDecline:
        case CallLifecycleEvent.ringTimeout:
        case CallLifecycleEvent.fatalError:
          return CallLifecycleState.ending;
        default:
          return null;
      }
    case CallLifecycleState.accepting:
      switch (event) {
        case CallLifecycleEvent.remoteOfferReceived:
          return CallLifecycleState.answerNegotiation;
        case CallLifecycleEvent.localAnswerCreated:
          return CallLifecycleState.connectingMedia;
        case CallLifecycleEvent.localHangup:
        case CallLifecycleEvent.remoteHangup:
        case CallLifecycleEvent.remoteDecline:
        case CallLifecycleEvent.connectTimeout:
        case CallLifecycleEvent.fatalError:
          return CallLifecycleState.ending;
        default:
          return null;
      }
    case CallLifecycleState.offerNegotiation:
      switch (event) {
        case CallLifecycleEvent.localOfferCreated:
        case CallLifecycleEvent.remoteIceReceived:
          return CallLifecycleState.offerNegotiation;
        case CallLifecycleEvent.remoteAnswerReceived:
          return CallLifecycleState.connectingMedia;
        case CallLifecycleEvent.localHangup:
        case CallLifecycleEvent.remoteHangup:
        case CallLifecycleEvent.remoteDecline:
        case CallLifecycleEvent.ringTimeout:
        case CallLifecycleEvent.connectTimeout:
        case CallLifecycleEvent.fatalError:
          return CallLifecycleState.ending;
        default:
          return null;
      }
    case CallLifecycleState.answerNegotiation:
      switch (event) {
        case CallLifecycleEvent.remoteOfferReceived:
        case CallLifecycleEvent.remoteIceReceived:
          return CallLifecycleState.answerNegotiation;
        case CallLifecycleEvent.localAnswerCreated:
          return CallLifecycleState.connectingMedia;
        case CallLifecycleEvent.localHangup:
        case CallLifecycleEvent.remoteHangup:
        case CallLifecycleEvent.remoteDecline:
        case CallLifecycleEvent.connectTimeout:
        case CallLifecycleEvent.fatalError:
          return CallLifecycleState.ending;
        default:
          return null;
      }
    case CallLifecycleState.connectingMedia:
      switch (event) {
        case CallLifecycleEvent.peerconnectionConnected:
        case CallLifecycleEvent.mediaEstablished:
        case CallLifecycleEvent.transportReconnected:
          return CallLifecycleState.connected;
        case CallLifecycleEvent.remoteOfferReceived:
        case CallLifecycleEvent.localAnswerCreated:
        case CallLifecycleEvent.remoteAnswerReceived:
        case CallLifecycleEvent.remoteIceReceived:
        case CallLifecycleEvent.transportLost:
        case CallLifecycleEvent.peerconnectionFailed:
          return wasEverConnected
              ? CallLifecycleState.reconnecting
              : CallLifecycleState.connectingMedia;
        case CallLifecycleEvent.localHangup:
        case CallLifecycleEvent.remoteHangup:
        case CallLifecycleEvent.remoteDecline:
        case CallLifecycleEvent.connectTimeout:
        case CallLifecycleEvent.fatalError:
          return CallLifecycleState.ending;
        default:
          return null;
      }
    case CallLifecycleState.connected:
      switch (event) {
        case CallLifecycleEvent.peerconnectionConnected:
        case CallLifecycleEvent.mediaEstablished:
        case CallLifecycleEvent.transportReconnected:
        case CallLifecycleEvent.localOfferCreated:
        case CallLifecycleEvent.remoteOfferReceived:
        case CallLifecycleEvent.localAnswerCreated:
        case CallLifecycleEvent.remoteAnswerReceived:
        case CallLifecycleEvent.remoteIceReceived:
          return CallLifecycleState.connected;
        case CallLifecycleEvent.transportLost:
        case CallLifecycleEvent.peerconnectionFailed:
          return CallLifecycleState.reconnecting;
        case CallLifecycleEvent.localHangup:
        case CallLifecycleEvent.remoteHangup:
        case CallLifecycleEvent.remoteDecline:
        case CallLifecycleEvent.connectTimeout:
        case CallLifecycleEvent.fatalError:
          return CallLifecycleState.ending;
        default:
          return null;
      }
    case CallLifecycleState.reconnecting:
      switch (event) {
        case CallLifecycleEvent.peerconnectionConnected:
        case CallLifecycleEvent.mediaEstablished:
        case CallLifecycleEvent.transportReconnected:
          return CallLifecycleState.connected;
        case CallLifecycleEvent.localOfferCreated:
        case CallLifecycleEvent.localAnswerCreated:
          return CallLifecycleState.reconnecting;
        case CallLifecycleEvent.transportLost:
        case CallLifecycleEvent.peerconnectionFailed:
        case CallLifecycleEvent.remoteOfferReceived:
        case CallLifecycleEvent.remoteAnswerReceived:
        case CallLifecycleEvent.remoteIceReceived:
          return CallLifecycleState.reconnecting;
        case CallLifecycleEvent.localHangup:
        case CallLifecycleEvent.remoteHangup:
        case CallLifecycleEvent.remoteDecline:
        case CallLifecycleEvent.connectTimeout:
        case CallLifecycleEvent.fatalError:
          return CallLifecycleState.ending;
        default:
          return null;
      }
    case CallLifecycleState.ending:
      switch (event) {
        case CallLifecycleEvent.cleanupCompleted:
          return CallLifecycleState.ended;
        case CallLifecycleEvent.localHangup:
        case CallLifecycleEvent.remoteHangup:
        case CallLifecycleEvent.remoteDecline:
        case CallLifecycleEvent.localDecline:
        case CallLifecycleEvent.connectTimeout:
        case CallLifecycleEvent.ringTimeout:
        case CallLifecycleEvent.fatalError:
          return CallLifecycleState.ending;
        default:
          return null;
      }
    case CallLifecycleState.ended:
      switch (event) {
        case CallLifecycleEvent.reset:
          return CallLifecycleState.idle;
        case CallLifecycleEvent.cleanupCompleted:
        case CallLifecycleEvent.localHangup:
        case CallLifecycleEvent.remoteHangup:
        case CallLifecycleEvent.remoteDecline:
        case CallLifecycleEvent.localDecline:
        case CallLifecycleEvent.connectTimeout:
        case CallLifecycleEvent.ringTimeout:
        case CallLifecycleEvent.fatalError:
          return CallLifecycleState.ended;
        default:
          return null;
      }
  }
}
