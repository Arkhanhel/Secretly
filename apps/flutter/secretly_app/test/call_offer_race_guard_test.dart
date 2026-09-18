// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:secretly_app/calls/call_ice_config.dart';
import 'package:secretly_app/calls/call_manager.dart';
import 'package:secretly_app/calls/call_state.dart';
import 'package:secretly_app/calls/webrtc_call_session.dart';
import 'package:secretly_app/transport/relay_client.dart';

void main() {
  group('CallManager.shouldStartConnectingToneForRemoteAnswer', () {
    test('starts connecting tone only for initial answer flow', () {
      expect(
        CallManager.shouldStartConnectingToneForRemoteAnswer(
          phase: CallPhase.ringingOutgoing,
        ),
        isTrue,
      );
      expect(
        CallManager.shouldStartConnectingToneForRemoteAnswer(
          phase: CallPhase.reconnecting,
        ),
        isFalse,
      );
      expect(
        CallManager.shouldStartConnectingToneForRemoteAnswer(
          phase: CallPhase.connected,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldIgnoreIncomingOffer', () {
    test('ignores offer while outgoing call is ringing', () {
      expect(
        CallManager.shouldIgnoreIncomingOffer(
          phase: CallPhase.ringingOutgoing,
          awaitingRemoteAnswer: false,
        ),
        isTrue,
      );
    });

    test(
      'processes offer while incoming call is connecting and not awaiting answer',
      () {
        expect(
          CallManager.shouldIgnoreIncomingOffer(
            phase: CallPhase.connecting,
            awaitingRemoteAnswer: false,
          ),
          isFalse,
        );
      },
    );

    test('ignores offer in any phase when signaling awaits answer', () {
      expect(
        CallManager.shouldIgnoreIncomingOffer(
          phase: CallPhase.connecting,
          awaitingRemoteAnswer: true,
        ),
        isTrue,
      );
    });

    test('processes active-call glare offer while local answer is pending', () {
      expect(
        CallManager.shouldIgnoreIncomingOffer(
          phase: CallPhase.connected,
          awaitingRemoteAnswer: true,
        ),
        isFalse,
      );
      expect(
        CallManager.shouldResolveOfferGlareInActiveCall(
          phase: CallPhase.connected,
          awaitingRemoteAnswer: true,
        ),
        isTrue,
      );
    });

    test(
      'processes reconnect-time glare offer while local recovery offer awaits answer',
      () {
        expect(
          CallManager.shouldIgnoreIncomingOffer(
            phase: CallPhase.reconnecting,
            awaitingRemoteAnswer: true,
          ),
          isFalse,
        );
        expect(
          CallManager.shouldResolveOfferGlareInActiveCall(
            phase: CallPhase.reconnecting,
            awaitingRemoteAnswer: true,
          ),
          isTrue,
        );
      },
    );

    test(
      'allows reconnect-time renegotiation offer once local side is not awaiting answer',
      () {
        expect(
          CallManager.shouldIgnoreIncomingOffer(
            phase: CallPhase.reconnecting,
            awaitingRemoteAnswer: false,
          ),
          isFalse,
        );
      },
    );
  });

  group('CallManager.shouldApplyRemoteAnswer', () {
    test('applies answer while peer connection is awaiting it', () {
      expect(
        CallManager.shouldApplyRemoteAnswer(
          awaitingRemoteAnswer: true,
          hasRemoteDescription: false,
          hasPendingLocalOffer: false,
        ),
        isTrue,
      );
    });

    test(
      'applies answer when signaling drifted but remote description is missing',
      () {
        expect(
          CallManager.shouldApplyRemoteAnswer(
            awaitingRemoteAnswer: false,
            hasRemoteDescription: false,
            hasPendingLocalOffer: false,
          ),
          isTrue,
        );
      },
    );

    test(
      'applies upgrade answer when signaling drifted but local offer is still pending',
      () {
        expect(
          CallManager.shouldApplyRemoteAnswer(
            awaitingRemoteAnswer: false,
            hasRemoteDescription: true,
            hasPendingLocalOffer: true,
          ),
          isTrue,
        );
      },
    );

    test('ignores answer only after remote description already exists', () {
      expect(
        CallManager.shouldApplyRemoteAnswer(
          awaitingRemoteAnswer: false,
          hasRemoteDescription: true,
          hasPendingLocalOffer: false,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldSuppressDuplicateLocalOfferSend', () {
    test('suppresses identical offer for same attempt in short window', () {
      final sdp = 'same-offer-sdp';
      expect(
        CallManager.shouldSuppressDuplicateLocalOfferSend(
          previousCallId: 'call-1',
          previousCallAttemptId: 'attempt-1',
          previousFingerprint: '${sdp.length}:${sdp.hashCode}',
          previousSentAtMs: 1000,
          callId: 'call-1',
          callAttemptId: 'attempt-1',
          sdp: sdp,
          nowMs: 1500,
        ),
        isTrue,
      );
    });

    test('does not suppress same offer after window expires', () {
      final sdp = 'same-offer-sdp';
      expect(
        CallManager.shouldSuppressDuplicateLocalOfferSend(
          previousCallId: 'call-1',
          previousCallAttemptId: 'attempt-1',
          previousFingerprint: '${sdp.length}:${sdp.hashCode}',
          previousSentAtMs: 1000,
          callId: 'call-1',
          callAttemptId: 'attempt-1',
          sdp: sdp,
          nowMs: 2600,
        ),
        isFalse,
      );
    });

    test('does not suppress same offer for different attempt', () {
      final sdp = 'same-offer-sdp';
      expect(
        CallManager.shouldSuppressDuplicateLocalOfferSend(
          previousCallId: 'call-1',
          previousCallAttemptId: 'attempt-1',
          previousFingerprint: '${sdp.length}:${sdp.hashCode}',
          previousSentAtMs: 1000,
          callId: 'call-1',
          callAttemptId: 'attempt-2',
          sdp: sdp,
          nowMs: 1200,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldDeferNeedOfferDuringOutgoingBootstrap', () {
    test(
      'defers need_offer while initial outgoing offer bootstrap is in flight',
      () {
        expect(
          CallManager.shouldDeferNeedOfferDuringOutgoingBootstrap(
            phase: CallPhase.ringingOutgoing,
            outgoingOfferBootstrapInFlight: true,
          ),
          isTrue,
        );
        expect(
          CallManager.shouldDeferNeedOfferDuringOutgoingBootstrap(
            phase: CallPhase.connecting,
            outgoingOfferBootstrapInFlight: true,
          ),
          isTrue,
        );
      },
    );

    test('does not defer need_offer after bootstrap completes', () {
      expect(
        CallManager.shouldDeferNeedOfferDuringOutgoingBootstrap(
          phase: CallPhase.ringingOutgoing,
          outgoingOfferBootstrapInFlight: false,
        ),
        isFalse,
      );
    });

    test('does not defer need_offer for unrelated phases', () {
      expect(
        CallManager.shouldDeferNeedOfferDuringOutgoingBootstrap(
          phase: CallPhase.connected,
          outgoingOfferBootstrapInFlight: true,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldKeepNeedOfferRetriesRunning', () {
    test('keeps retries running during initial connecting offer recovery', () {
      expect(
        CallManager.shouldKeepNeedOfferRetriesRunning(
          phase: CallPhase.connecting,
          isActive: true,
          hasPendingOffer: false,
          awaitingRecoveryOffer: false,
        ),
        isTrue,
      );
    });

    test(
      'keeps retries running during reconnect only while recovery offer is awaited',
      () {
        expect(
          CallManager.shouldKeepNeedOfferRetriesRunning(
            phase: CallPhase.reconnecting,
            isActive: true,
            hasPendingOffer: false,
            awaitingRecoveryOffer: true,
          ),
          isTrue,
        );
        expect(
          CallManager.shouldKeepNeedOfferRetriesRunning(
            phase: CallPhase.reconnecting,
            isActive: true,
            hasPendingOffer: false,
            awaitingRecoveryOffer: false,
          ),
          isFalse,
        );
      },
    );

    test('stops retries after offer arrives or call is no longer active', () {
      expect(
        CallManager.shouldKeepNeedOfferRetriesRunning(
          phase: CallPhase.reconnecting,
          isActive: true,
          hasPendingOffer: true,
          awaitingRecoveryOffer: true,
        ),
        isFalse,
      );
      expect(
        CallManager.shouldKeepNeedOfferRetriesRunning(
          phase: CallPhase.connecting,
          isActive: false,
          hasPendingOffer: false,
          awaitingRecoveryOffer: false,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldHandleIncomingNeedOffer', () {
    test('handles need_offer for outgoing reconnect recovery phases', () {
      expect(
        CallManager.shouldHandleIncomingNeedOffer(
          direction: CallDirection.outgoing,
          phase: CallPhase.reconnecting,
        ),
        isTrue,
      );
      expect(
        CallManager.shouldHandleIncomingNeedOffer(
          direction: CallDirection.outgoing,
          phase: CallPhase.connected,
        ),
        isTrue,
      );
    });

    test('ignores need_offer for incoming call direction', () {
      expect(
        CallManager.shouldHandleIncomingNeedOffer(
          direction: CallDirection.incoming,
          phase: CallPhase.reconnecting,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldAcceptSignalForCurrentCall', () {
    test('accepts matching call id and attempt id', () {
      expect(
        CallManager.shouldAcceptSignalForCurrentCall(
          currentCallId: 'call-1',
          currentCallAttemptId: 'attempt-1',
          signalCallId: 'call-1',
          signalCallAttemptId: 'attempt-1',
        ),
        isTrue,
      );
    });

    test('rejects stale signal for same call id but different attempt id', () {
      expect(
        CallManager.shouldAcceptSignalForCurrentCall(
          currentCallId: 'call-1',
          currentCallAttemptId: 'attempt-new',
          signalCallId: 'call-1',
          signalCallAttemptId: 'attempt-old',
        ),
        isFalse,
      );
    });

    test('falls back to call id when attempt id is absent', () {
      expect(
        CallManager.shouldAcceptSignalForCurrentCall(
          currentCallId: 'call-1',
          currentCallAttemptId: '',
          signalCallId: 'call-1',
          signalCallAttemptId: '',
        ),
        isTrue,
      );
    });

    test('rejects signal with different call id', () {
      expect(
        CallManager.shouldAcceptSignalForCurrentCall(
          currentCallId: 'call-1',
          currentCallAttemptId: 'attempt-1',
          signalCallId: 'call-2',
          signalCallAttemptId: 'attempt-1',
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldIgnoreInviteForCurrentCall', () {
    test('ignores invite for the same active attempt', () {
      expect(
        CallManager.shouldIgnoreInviteForCurrentCall(
          currentCallId: 'call-1',
          currentCallAttemptId: 'attempt-1',
          inviteCallId: 'call-1',
          inviteCallAttemptId: 'attempt-1',
        ),
        isTrue,
      );
    });

    test('does not ignore invite for newer attempt on same call id', () {
      expect(
        CallManager.shouldIgnoreInviteForCurrentCall(
          currentCallId: 'call-1',
          currentCallAttemptId: 'attempt-old',
          inviteCallId: 'call-1',
          inviteCallAttemptId: 'attempt-new',
        ),
        isFalse,
      );
    });
  });

  group('CallManager.ended call attempt suppression', () {
    test('normalizes ended call attempt key with fallback to call id', () {
      expect(
        CallManager.endedCallAttemptKey(callId: 'call-1', callAttemptId: ''),
        'call-1::call-1',
      );
    });

    test('suppresses only the exact ended attempt', () {
      expect(
        CallManager.shouldSuppressSignalForEndedCallAttempt(
          endedCallAttemptKeys: {'call-1::attempt-old'},
          signalCallId: 'call-1',
          signalCallAttemptId: 'attempt-old',
        ),
        isTrue,
      );
    });

    test('does not suppress newer attempt that reuses the same call id', () {
      expect(
        CallManager.shouldSuppressSignalForEndedCallAttempt(
          endedCallAttemptKeys: {'call-1::attempt-old'},
          signalCallId: 'call-1',
          signalCallAttemptId: 'attempt-new',
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldRestartConnectingForIncomingOffer', () {
    test('restarts connecting for initial incoming offer flow', () {
      expect(
        CallManager.shouldRestartConnectingForIncomingOffer(
          CallPhase.ringingIncoming,
        ),
        isTrue,
      );
    });

    test('keeps connected phase during renegotiation', () {
      expect(
        CallManager.shouldRestartConnectingForIncomingOffer(
          CallPhase.connected,
        ),
        isFalse,
      );
    });

    test('keeps reconnecting phase during renegotiation', () {
      expect(
        CallManager.shouldRestartConnectingForIncomingOffer(
          CallPhase.reconnecting,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldBufferIncomingOfferUntilExplicitAccept', () {
    test('buffers incoming offer while the receiver is still ringing', () {
      expect(
        CallManager.shouldBufferIncomingOfferUntilExplicitAccept(
          CallPhase.ringingIncoming,
        ),
        isTrue,
      );
    });

    test(
      'allows offer processing only after explicit accept or active call',
      () {
        for (final phase in [
          CallPhase.connecting,
          CallPhase.connected,
          CallPhase.reconnecting,
        ]) {
          expect(
            CallManager.shouldBufferIncomingOfferUntilExplicitAccept(phase),
            isFalse,
          );
        }
      },
    );
  });

  group('CallManager.incomingRingtoneVolumeForSetting', () {
    test('plays every incoming ringtone at full player volume', () {
      for (final setting in ['default', 'beacon', 'chime', 'unknown']) {
        expect(CallManager.incomingRingtoneVolumeForSetting(setting), 1.0);
      }
    });
  });

  group('CallManager.shouldTerminateAfterMissingRelaySession', () {
    test('keeps reconnecting call alive on first missing session', () {
      expect(
        CallManager.shouldTerminateAfterMissingRelaySession(
          phase: CallPhase.reconnecting,
          consecutiveMisses: 1,
          wasEverConnected: true,
        ),
        isFalse,
      );
    });

    test('terminates reconnecting call after repeated missing sessions', () {
      expect(
        CallManager.shouldTerminateAfterMissingRelaySession(
          phase: CallPhase.reconnecting,
          consecutiveMisses: 4,
          wasEverConnected: true,
        ),
        isTrue,
      );
    });

    test(
      'keeps reconnecting call alive during recent connectivity handoff',
      () {
        expect(
          CallManager.shouldTerminateAfterMissingRelaySession(
            phase: CallPhase.reconnecting,
            consecutiveMisses: 3,
            wasEverConnected: true,
            recentConnectivityRecovery: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'keeps reconnecting call alive while connectivity follow-up is pending',
      () {
        expect(
          CallManager.shouldTerminateAfterMissingRelaySession(
            phase: CallPhase.reconnecting,
            consecutiveMisses: 3,
            wasEverConnected: true,
            pendingConnectivityRecovery: true,
          ),
          isFalse,
        );
      },
    );

    test('does not terminate initial connecting flow before media existed', () {
      expect(
        CallManager.shouldTerminateAfterMissingRelaySession(
          phase: CallPhase.connecting,
          consecutiveMisses: 3,
          wasEverConnected: false,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldTreatMissingRelaySessionAsTransient', () {
    test(
      'treats recent accepted relay authority for same attempt as transient gap',
      () {
        expect(
          CallManager.shouldTreatMissingRelaySessionAsTransient(
            callId: 'call-1',
            callAttemptId: 'attempt-1',
            lastObservedCallId: 'call-1',
            lastObservedCallAttemptId: 'attempt-1',
            lastObservedState: 'accepted',
            lastObservedAtMs: 1000,
            nowMs: 5000,
          ),
          isTrue,
        );
      },
    );

    test('does not treat stale relay authority as transient forever', () {
      expect(
        CallManager.shouldTreatMissingRelaySessionAsTransient(
          callId: 'call-1',
          callAttemptId: 'attempt-1',
          lastObservedCallId: 'call-1',
          lastObservedCallAttemptId: 'attempt-1',
          lastObservedState: 'reconnecting',
          lastObservedAtMs: 1000,
          nowMs: 32001,
        ),
        isFalse,
      );
    });

    test('does not treat different attempt as transient gap', () {
      expect(
        CallManager.shouldTreatMissingRelaySessionAsTransient(
          callId: 'call-1',
          callAttemptId: 'attempt-2',
          lastObservedCallId: 'call-1',
          lastObservedCallAttemptId: 'attempt-1',
          lastObservedState: 'accepted',
          lastObservedAtMs: 1000,
          nowMs: 5000,
        ),
        isFalse,
      );
    });

    test('does not treat terminal relay state as transient gap', () {
      expect(
        CallManager.shouldTreatMissingRelaySessionAsTransient(
          callId: 'call-1',
          callAttemptId: 'attempt-1',
          lastObservedCallId: 'call-1',
          lastObservedCallAttemptId: 'attempt-1',
          lastObservedState: 'ended',
          lastObservedAtMs: 1000,
          nowMs: 5000,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.relay lifecycle promotion policy', () {
    test(
      'promotes outgoing ringing call to connecting when relay says accepted',
      () {
        expect(
          CallManager.shouldPromoteConnectingFromRelayAccepted(
            direction: CallDirection.outgoing,
            phase: CallPhase.ringingOutgoing,
            snapshot: const RelayCallSessionSnapshot(
              exists: true,
              deviceId: 'self-device',
              callId: 'call-1',
              callAttemptId: 'attempt-1',
              state: 'accepted',
              lastAction: 'answer',
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      'does not promote connecting from accepted for incoming direction',
      () {
        expect(
          CallManager.shouldPromoteConnectingFromRelayAccepted(
            direction: CallDirection.incoming,
            phase: CallPhase.ringingOutgoing,
            snapshot: const RelayCallSessionSnapshot(
              exists: true,
              deviceId: 'self-device',
              callId: 'call-1',
              callAttemptId: 'attempt-1',
              state: 'accepted',
              lastAction: 'answer',
            ),
          ),
          isFalse,
        );
      },
    );

    test(
      'promotes connected call to reconnecting when relay says reconnecting',
      () {
        expect(
          CallManager.shouldPromoteReconnectingFromRelay(
            phase: CallPhase.connected,
            wasEverConnected: true,
            snapshot: const RelayCallSessionSnapshot(
              exists: true,
              deviceId: 'self-device',
              callId: 'call-1',
              callAttemptId: 'attempt-1',
              state: 'reconnecting',
              lastAction: 'need_offer',
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      'does not promote reconnecting from relay when local session already recovered',
      () {
        expect(
          CallManager.shouldPromoteReconnectingFromRelay(
            phase: CallPhase.connected,
            wasEverConnected: true,
            snapshot: const RelayCallSessionSnapshot(
              exists: true,
              deviceId: 'self-device',
              callId: 'call-1',
              callAttemptId: 'attempt-1',
              state: 'reconnecting',
              lastAction: 'need_offer',
            ),
            rtcState: RTCPeerConnectionState.RTCPeerConnectionStateConnected,
            iceState: RTCIceConnectionState.RTCIceConnectionStateConnected,
            mediaEstablished: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'promotes previously connected connecting phase to reconnecting on relay recovery truth',
      () {
        expect(
          CallManager.shouldPromoteReconnectingFromRelay(
            phase: CallPhase.connecting,
            wasEverConnected: true,
            snapshot: const RelayCallSessionSnapshot(
              exists: true,
              deviceId: 'self-device',
              callId: 'call-1',
              callAttemptId: 'attempt-1',
              state: 'ringing',
              lastAction: 'need_offer',
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      'does not promote initial connecting flow to reconnecting without prior connection',
      () {
        expect(
          CallManager.shouldPromoteReconnectingFromRelay(
            phase: CallPhase.connecting,
            wasEverConnected: false,
            snapshot: const RelayCallSessionSnapshot(
              exists: true,
              deviceId: 'self-device',
              callId: 'call-1',
              callAttemptId: 'attempt-1',
              state: 'reconnecting',
              lastAction: 'need_offer',
            ),
          ),
          isFalse,
        );
      },
    );
  });

  group('CallManager.shouldRecoverOfferProcessingFailure', () {
    test('recovers when renegotiation fails during connected phase', () {
      expect(
        CallManager.shouldRecoverOfferProcessingFailure(
          phase: CallPhase.connected,
          wasEverConnected: true,
        ),
        isTrue,
      );
    });

    test('recovers when renegotiation fails during reconnecting phase', () {
      expect(
        CallManager.shouldRecoverOfferProcessingFailure(
          phase: CallPhase.reconnecting,
          wasEverConnected: true,
        ),
        isTrue,
      );
    });

    test('recovers when lifecycle drifted to connecting after prior media', () {
      expect(
        CallManager.shouldRecoverOfferProcessingFailure(
          phase: CallPhase.connecting,
          wasEverConnected: true,
        ),
        isTrue,
      );
    });

    test('fails initial offer processing before any successful connection', () {
      expect(
        CallManager.shouldRecoverOfferProcessingFailure(
          phase: CallPhase.connecting,
          wasEverConnected: false,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.computeAutoRestartIceDelayMs', () {
    test('uses faster delay for active hard recovery', () {
      expect(
        CallManager.computeAutoRestartIceDelayMs(
          attemptNumber: 1,
          wasEverConnected: true,
          preferHardRecovery: true,
        ),
        0,
      );
      expect(
        CallManager.computeAutoRestartIceDelayMs(
          attemptNumber: 2,
          wasEverConnected: true,
          preferHardRecovery: true,
        ),
        200,
      );
      expect(
        CallManager.computeAutoRestartIceDelayMs(
          attemptNumber: 4,
          wasEverConnected: true,
          preferHardRecovery: true,
        ),
        600,
      );
    });

    test('starts initial-connect hard recovery on attempt 1 with no delay', () {
      expect(
        CallManager.computeAutoRestartIceDelayMs(
          attemptNumber: 1,
          wasEverConnected: false,
          preferHardRecovery: true,
        ),
        0,
      );
      expect(
        CallManager.computeAutoRestartIceDelayMs(
          attemptNumber: 2,
          wasEverConnected: false,
          preferHardRecovery: true,
        ),
        150,
      );
    });

    test('keeps soft retries conservative when no hard recovery requested', () {
      expect(
        CallManager.computeAutoRestartIceDelayMs(
          attemptNumber: 1,
          wasEverConnected: true,
          preferHardRecovery: false,
        ),
        600,
      );
    });
  });

  group('CallManager.computeRelayReconcileBudgetMs', () {
    test('timeboxes relay reconcile for active hard recovery', () {
      expect(
        CallManager.computeRelayReconcileBudgetMs(
          wasEverConnected: true,
          preferHardRecovery: true,
        ),
        250,
      );
    });

    test('keeps relay reconcile unbounded for non-fast recovery paths', () {
      expect(
        CallManager.computeRelayReconcileBudgetMs(
          wasEverConnected: false,
          preferHardRecovery: true,
        ),
        isNull,
      );
      expect(
        CallManager.computeRelayReconcileBudgetMs(
          wasEverConnected: true,
          preferHardRecovery: false,
        ),
        isNull,
      );
    });
  });

  group('CallManager.shouldScheduleAdditionalConnectivityFollowUpRecovery', () {
    test('schedules one more pass while transport is still degraded', () {
      expect(
        CallManager.shouldScheduleAdditionalConnectivityFollowUpRecovery(
          phase: CallPhase.reconnecting,
          wasEverConnected: true,
          rtcState: RTCPeerConnectionState.RTCPeerConnectionStateDisconnected,
          iceState: RTCIceConnectionState.RTCIceConnectionStateDisconnected,
          mediaEstablished: false,
          hasUsableConnectivity: true,
          attemptsSoFar: 1,
        ),
        isTrue,
      );
    });

    test('does not schedule extra pass once follow-up budget is exhausted', () {
      expect(
        CallManager.shouldScheduleAdditionalConnectivityFollowUpRecovery(
          phase: CallPhase.reconnecting,
          wasEverConnected: true,
          rtcState: RTCPeerConnectionState.RTCPeerConnectionStateDisconnected,
          iceState: RTCIceConnectionState.RTCIceConnectionStateDisconnected,
          mediaEstablished: false,
          hasUsableConnectivity: true,
          attemptsSoFar: 2,
        ),
        isFalse,
      );
    });

    test('does not schedule extra pass after transport already recovered', () {
      expect(
        CallManager.shouldScheduleAdditionalConnectivityFollowUpRecovery(
          phase: CallPhase.reconnecting,
          wasEverConnected: true,
          rtcState: RTCPeerConnectionState.RTCPeerConnectionStateConnected,
          iceState: RTCIceConnectionState.RTCIceConnectionStateConnected,
          mediaEstablished: false,
          hasUsableConnectivity: true,
          attemptsSoFar: 0,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldPromoteConnectedFromSession', () {
    test(
      'does not promote a still-ringing incoming call from prewarmed media',
      () {
        expect(
          CallManager.shouldPromoteConnectedFromSession(
            phase: CallPhase.ringingIncoming,
            wasEverConnected: false,
            rtcState: RTCPeerConnectionState.RTCPeerConnectionStateConnected,
            iceState: RTCIceConnectionState.RTCIceConnectionStateConnected,
            mediaEstablished: true,
          ),
          isFalse,
        );
      },
    );

    test('does not promote initial connection on transport alone', () {
      expect(
        CallManager.shouldPromoteConnectedFromSession(
          phase: CallPhase.connecting,
          wasEverConnected: false,
          rtcState: RTCPeerConnectionState.RTCPeerConnectionStateConnected,
          iceState: RTCIceConnectionState.RTCIceConnectionStateConnected,
          mediaEstablished: false,
        ),
        isFalse,
      );
    });

    test('does not promote connected on stale media without transport', () {
      expect(
        CallManager.shouldPromoteConnectedFromSession(
          phase: CallPhase.connected,
          wasEverConnected: true,
          rtcState: RTCPeerConnectionState.RTCPeerConnectionStateDisconnected,
          iceState: RTCIceConnectionState.RTCIceConnectionStateDisconnected,
          mediaEstablished: true,
        ),
        isFalse,
      );
    });

    test('promotes connected only when media truth and transport agree', () {
      expect(
        CallManager.shouldPromoteConnectedFromSession(
          phase: CallPhase.connecting,
          wasEverConnected: false,
          rtcState: RTCPeerConnectionState.RTCPeerConnectionStateConnected,
          iceState: RTCIceConnectionState.RTCIceConnectionStateConnected,
          mediaEstablished: true,
        ),
        isTrue,
      );
    });

    test(
      'promotes previously connected reconnecting call on recovered transport without waiting for fresh media stats',
      () {
        expect(
          CallManager.shouldPromoteConnectedFromSession(
            phase: CallPhase.reconnecting,
            wasEverConnected: true,
            rtcState: RTCPeerConnectionState.RTCPeerConnectionStateConnected,
            iceState: RTCIceConnectionState.RTCIceConnectionStateConnected,
            mediaEstablished: false,
          ),
          isTrue,
        );
      },
    );

    test('keeps reconnect gate strict before a call was ever connected', () {
      expect(
        CallManager.shouldPromoteConnectedFromSession(
          phase: CallPhase.reconnecting,
          wasEverConnected: false,
          rtcState: RTCPeerConnectionState.RTCPeerConnectionStateConnected,
          iceState: RTCIceConnectionState.RTCIceConnectionStateConnected,
          mediaEstablished: false,
        ),
        isFalse,
      );
    });
  });

  group('WebRtcCallSession.shouldDeclareMediaEstablished', () {
    test('declares media on peer connection connected before stats arrive', () {
      expect(
        WebRtcCallSession.shouldDeclareMediaEstablished(
          peerConnectionState:
              RTCPeerConnectionState.RTCPeerConnectionStateConnected,
          iceConnectionState:
              RTCIceConnectionState.RTCIceConnectionStateChecking,
          hasSelectedCandidatePair: false,
          hasInboundRemoteMedia: false,
        ),
        isTrue,
      );
    });

    test('declares media on selected ICE pair when peer state is stale', () {
      expect(
        WebRtcCallSession.shouldDeclareMediaEstablished(
          peerConnectionState:
              RTCPeerConnectionState.RTCPeerConnectionStateConnecting,
          iceConnectionState:
              RTCIceConnectionState.RTCIceConnectionStateConnected,
          hasSelectedCandidatePair: true,
          hasInboundRemoteMedia: false,
        ),
        isTrue,
      );
    });

    test(
      'does not declare media on ICE connected without selected pair proof',
      () {
        expect(
          WebRtcCallSession.shouldDeclareMediaEstablished(
            peerConnectionState:
                RTCPeerConnectionState.RTCPeerConnectionStateConnecting,
            iceConnectionState:
                RTCIceConnectionState.RTCIceConnectionStateConnected,
            hasSelectedCandidatePair: false,
            hasInboundRemoteMedia: false,
          ),
          isFalse,
        );
      },
    );
  });

  group('CallManager transport degradation helpers', () {
    test(
      'treats ICE failed as transport failure even if peer state did not fail',
      () {
        expect(
          CallManager.hasTransportFailureState(
            rtcState: RTCPeerConnectionState.RTCPeerConnectionStateConnected,
            iceState: RTCIceConnectionState.RTCIceConnectionStateFailed,
          ),
          isTrue,
        );
      },
    );

    test('treats ICE disconnected as transport disconnection', () {
      expect(
        CallManager.hasTransportDisconnectionState(
          rtcState: RTCPeerConnectionState.RTCPeerConnectionStateConnected,
          iceState: RTCIceConnectionState.RTCIceConnectionStateDisconnected,
        ),
        isTrue,
      );
    });

    test('does not classify failure state as plain disconnection', () {
      expect(
        CallManager.hasTransportDisconnectionState(
          rtcState: RTCPeerConnectionState.RTCPeerConnectionStateFailed,
          iceState: RTCIceConnectionState.RTCIceConnectionStateDisconnected,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.shouldAttemptTransportRecoveryOnRelayReconnect', () {
    test('retries reconnecting call when transport is still degraded', () {
      expect(
        CallManager.shouldAttemptTransportRecoveryOnRelayReconnect(
          phase: CallPhase.reconnecting,
          wasEverConnected: true,
          rtcState: RTCPeerConnectionState.RTCPeerConnectionStateDisconnected,
          iceState: RTCIceConnectionState.RTCIceConnectionStateDisconnected,
          mediaEstablished: false,
        ),
        isTrue,
      );
    });

    test(
      'retries previously connected call after relay reconnect if ICE is still disconnected',
      () {
        expect(
          CallManager.shouldAttemptTransportRecoveryOnRelayReconnect(
            phase: CallPhase.connected,
            wasEverConnected: true,
            rtcState: RTCPeerConnectionState.RTCPeerConnectionStateConnected,
            iceState: RTCIceConnectionState.RTCIceConnectionStateDisconnected,
            mediaEstablished: false,
          ),
          isTrue,
        );
      },
    );

    test(
      'skips recovery on relay reconnect when session is already healthy',
      () {
        expect(
          CallManager.shouldAttemptTransportRecoveryOnRelayReconnect(
            phase: CallPhase.connected,
            wasEverConnected: true,
            rtcState: RTCPeerConnectionState.RTCPeerConnectionStateConnected,
            iceState: RTCIceConnectionState.RTCIceConnectionStateConnected,
            mediaEstablished: true,
          ),
          isFalse,
        );
      },
    );

    test('does not treat first connecting attempt as reconnect recovery', () {
      expect(
        CallManager.shouldAttemptTransportRecoveryOnRelayReconnect(
          phase: CallPhase.connecting,
          wasEverConnected: false,
          rtcState: RTCPeerConnectionState.RTCPeerConnectionStateDisconnected,
          iceState: RTCIceConnectionState.RTCIceConnectionStateDisconnected,
          mediaEstablished: false,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.validateIceConfigForSession', () {
    test('allows empty ICE config before fallback STUN augmentation', () {
      expect(
        CallManager.validateIceConfigForSession(
          const CallIceConfigSnapshot.empty(),
        ),
        isNull,
      );
    });

    test('accepts STUN-backed p2pPreferred config', () {
      expect(
        CallManager.validateIceConfigForSession(
          const CallIceConfigSnapshot(
            policy: CallNetworkPolicy.p2pPreferred,
            iceServers: <CallIceServerConfig>[
              CallIceServerConfig(
                urls: <String>['stun:stun.secretly.test:3478'],
              ),
            ],
          ),
        ),
        isNull,
      );
    });

    test('rejects relayOnly config without usable TURN servers', () {
      expect(
        CallManager.validateIceConfigForSession(
          const CallIceConfigSnapshot(
            policy: CallNetworkPolicy.relayOnly,
            iceServers: <CallIceServerConfig>[
              CallIceServerConfig(
                urls: <String>['stun:stun.secretly.test:3478'],
              ),
            ],
          ),
        ),
        'relay_only policy active but no usable TURN servers are available',
      );
    });
  });

  group('CallManager.selectRemoteVideoRecoveryStep', () {
    test('starts waiting-track failure with renegotiation recovery', () {
      expect(
        CallManager.selectRemoteVideoRecoveryStep(
          reason: RemoteVideoFailureReason.waitingForTrackTimeout,
          attemptsSoFar: 0,
        ),
        RemoteVideoRecoveryStep.renegotiate,
      );
    });

    test(
      'escalates waiting-track failure to ICE restart on second attempt',
      () {
        expect(
          CallManager.selectRemoteVideoRecoveryStep(
            reason: RemoteVideoFailureReason.waitingForTrackTimeout,
            attemptsSoFar: 1,
          ),
          RemoteVideoRecoveryStep.restartIce,
        );
      },
    );

    test('starts renderer failure with local renderer recovery', () {
      expect(
        CallManager.selectRemoteVideoRecoveryStep(
          reason: RemoteVideoFailureReason.rendererNoFrames,
          attemptsSoFar: 0,
        ),
        RemoteVideoRecoveryStep.reattachRenderer,
      );
    });

    test('escalates renderer-no-frames failure after repeated attempts', () {
      expect(
        CallManager.selectRemoteVideoRecoveryStep(
          reason: RemoteVideoFailureReason.rendererNoFrames,
          attemptsSoFar: 1,
        ),
        RemoteVideoRecoveryStep.restartIce,
      );
      expect(
        CallManager.selectRemoteVideoRecoveryStep(
          reason: RemoteVideoFailureReason.rendererNoFrames,
          attemptsSoFar: 2,
        ),
        RemoteVideoRecoveryStep.renegotiate,
      );
    });

    test(
      'escalates renderer-binding failure through ICE restart and renegotiation',
      () {
        expect(
          CallManager.selectRemoteVideoRecoveryStep(
            reason: RemoteVideoFailureReason.rendererBindingTimeout,
            attemptsSoFar: 1,
          ),
          RemoteVideoRecoveryStep.restartIce,
        );
        expect(
          CallManager.selectRemoteVideoRecoveryStep(
            reason: RemoteVideoFailureReason.rendererBindingTimeout,
            attemptsSoFar: 2,
          ),
          RemoteVideoRecoveryStep.renegotiate,
        );
      },
    );

    test(
      'fails call after renderer-no-frames recovery ladder is exhausted',
      () {
        expect(
          CallManager.selectRemoteVideoRecoveryStep(
            reason: RemoteVideoFailureReason.rendererNoFrames,
            attemptsSoFar: 3,
          ),
          RemoteVideoRecoveryStep.failCall,
        );
      },
    );

    test('fails call after renderer-binding recovery ladder is exhausted', () {
      expect(
        CallManager.selectRemoteVideoRecoveryStep(
          reason: RemoteVideoFailureReason.rendererBindingTimeout,
          attemptsSoFar: 3,
        ),
        RemoteVideoRecoveryStep.failCall,
      );
    });
  });

  group('CallManager.shouldUseFreshTransportRecovery', () {
    test(
      'prefers fresh transport rebuild for active reconnect after relay return',
      () {
        expect(
          CallManager.shouldUseFreshTransportRecovery(
            phase: CallPhase.reconnecting,
            wasEverConnected: true,
            isVideo: false,
            isCameraOff: false,
            isScreenSharing: false,
            priorIceRestartAttempts: 0,
            preferHardRecovery: true,
          ),
          isTrue,
        );
      },
    );

    test(
      'escalates to fresh transport after repeated ICE restart attempts',
      () {
        expect(
          CallManager.shouldUseFreshTransportRecovery(
            phase: CallPhase.reconnecting,
            wasEverConnected: true,
            isVideo: false,
            isCameraOff: false,
            isScreenSharing: false,
            priorIceRestartAttempts: 2,
          ),
          isTrue,
        );
      },
    );

    test('does not use fresh rebuild for initial connecting flow', () {
      expect(
        CallManager.shouldUseFreshTransportRecovery(
          phase: CallPhase.connecting,
          wasEverConnected: false,
          isVideo: false,
          isCameraOff: false,
          isScreenSharing: false,
          priorIceRestartAttempts: 3,
        ),
        isFalse,
      );
    });

    test('avoids fresh rebuild while screen share is active', () {
      expect(
        CallManager.shouldUseFreshTransportRecovery(
          phase: CallPhase.reconnecting,
          wasEverConnected: true,
          isVideo: true,
          isCameraOff: false,
          isScreenSharing: true,
          priorIceRestartAttempts: 3,
        ),
        isFalse,
      );
    });

    test(
      'avoids fresh rebuild for video call with camera intentionally off',
      () {
        expect(
          CallManager.shouldUseFreshTransportRecovery(
            phase: CallPhase.reconnecting,
            wasEverConnected: true,
            isVideo: true,
            isCameraOff: true,
            isScreenSharing: false,
            priorIceRestartAttempts: 3,
          ),
          isFalse,
        );
      },
    );
  });

  group('CallManager connectivity recovery policy', () {
    test('detects usable connectivity from non-none transport', () {
      expect(
        CallManager.hasUsableConnectivity(const <ConnectivityResult>[
          ConnectivityResult.wifi,
        ]),
        isTrue,
      );
      expect(
        CallManager.hasUsableConnectivity(const <ConnectivityResult>[
          ConnectivityResult.none,
        ]),
        isFalse,
      );
    });

    test('detects path change between different usable transports', () {
      expect(
        CallManager.hasConnectivityPathChanged(
          previousResults: const <ConnectivityResult>[ConnectivityResult.wifi],
          currentResults: const <ConnectivityResult>[ConnectivityResult.mobile],
        ),
        isTrue,
      );
      expect(
        CallManager.hasConnectivityPathChanged(
          previousResults: const <ConnectivityResult>[ConnectivityResult.wifi],
          currentResults: const <ConnectivityResult>[ConnectivityResult.wifi],
        ),
        isFalse,
      );
    });

    test('parses native network path events into connectivity transports', () {
      expect(
        CallManager.connectivityResultsFromNativePathEvent({
          'available': true,
          'transports': ['wifi', 'vpn'],
        }),
        containsAll(const <ConnectivityResult>[
          ConnectivityResult.wifi,
          ConnectivityResult.vpn,
        ]),
      );
      expect(
        CallManager.connectivityResultsFromNativePathEvent({
          'available': false,
          'transports': const <String>[],
        }),
        const <ConnectivityResult>[ConnectivityResult.none],
      );
    });

    test('attempts active-call recovery when connectivity returns', () {
      expect(
        CallManager.shouldAttemptTransportRecoveryOnConnectivityChange(
          phase: CallPhase.reconnecting,
          wasEverConnected: true,
          hasUsableConnectivity: true,
          connectivityRestored: true,
          connectivityPathChanged: false,
        ),
        isTrue,
      );
      expect(
        CallManager.shouldAttemptTransportRecoveryOnConnectivityChange(
          phase: CallPhase.connected,
          wasEverConnected: true,
          hasUsableConnectivity: true,
          connectivityRestored: false,
          connectivityPathChanged: true,
        ),
        isTrue,
      );
    });

    test(
      'does not start connectivity recovery for first connection attempt',
      () {
        expect(
          CallManager.shouldAttemptTransportRecoveryOnConnectivityChange(
            phase: CallPhase.connecting,
            wasEverConnected: false,
            hasUsableConnectivity: true,
            connectivityRestored: true,
            connectivityPathChanged: false,
          ),
          isFalse,
        );
      },
    );

    test('does not recover on duplicate usable connectivity event', () {
      expect(
        CallManager.shouldAttemptTransportRecoveryOnConnectivityChange(
          phase: CallPhase.connected,
          wasEverConnected: true,
          hasUsableConnectivity: true,
          connectivityRestored: false,
          connectivityPathChanged: false,
        ),
        isFalse,
      );
    });

    test('does not recover while still offline', () {
      expect(
        CallManager.shouldAttemptTransportRecoveryOnConnectivityChange(
          phase: CallPhase.reconnecting,
          wasEverConnected: true,
          hasUsableConnectivity: false,
          connectivityRestored: false,
          connectivityPathChanged: false,
        ),
        isFalse,
      );
    });
  });

  group('CallManager.relayTerminalEndReason', () {
    test('maps superseded relay attempt to dedicated end reason', () {
      expect(
        CallManager.relayTerminalEndReason(
          const RelayCallSessionSnapshot(
            exists: true,
            deviceId: 'self-device',
            callId: 'call-1',
            callAttemptId: 'attempt-2',
            state: 'ended',
            lastAction: 'superseded',
          ),
        ),
        CallEndReason.remoteSuperseded,
      );
    });

    test('maps declined relay attempt to remote decline', () {
      expect(
        CallManager.relayTerminalEndReason(
          const RelayCallSessionSnapshot(
            exists: true,
            deviceId: 'self-device',
            callId: 'call-1',
            callAttemptId: 'attempt-1',
            state: 'ended',
            lastAction: 'decline',
          ),
        ),
        CallEndReason.remoteDecline,
      );
    });

    test('maps timed out relay attempt to timeout', () {
      expect(
        CallManager.relayTerminalEndReason(
          const RelayCallSessionSnapshot(
            exists: true,
            deviceId: 'self-device',
            callId: 'call-1',
            callAttemptId: 'attempt-1',
            state: 'ended',
            lastAction: 'timeout',
            endedAtMs: 456,
          ),
        ),
        CallEndReason.timeout,
      );
    });

    test('treats ended relay attempt without explicit action as hangup', () {
      expect(
        CallManager.relayTerminalEndReason(
          const RelayCallSessionSnapshot(
            exists: true,
            deviceId: 'self-device',
            callId: 'call-1',
            callAttemptId: 'attempt-1',
            state: 'ended',
            lastAction: 'accepted',
            endedAtMs: 123,
          ),
        ),
        CallEndReason.remoteHangup,
      );
    });

    test('keeps active reconnect session alive when relay is not terminal', () {
      expect(
        CallManager.relayTerminalEndReason(
          const RelayCallSessionSnapshot(
            exists: true,
            deviceId: 'self-device',
            callId: 'call-1',
            callAttemptId: 'attempt-1',
            state: 'reconnecting',
            lastAction: 'need_offer',
          ),
        ),
        isNull,
      );
    });
  });

  group('CallManager.relay offer recovery policy', () {
    test(
      'requests offer recovery only for incoming connecting flow awaiting offer',
      () {
        expect(
          CallManager.shouldRequestOfferRecoveryFromRelay(
            direction: CallDirection.incoming,
            phase: CallPhase.connecting,
            awaitingRemoteOfferLocally: true,
            snapshot: const RelayCallSessionSnapshot(
              exists: true,
              deviceId: 'self-device',
              callId: 'call-1',
              callAttemptId: 'attempt-1',
              state: 'ringing',
              lastAction: 'invite',
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      'does not request offer recovery once remote offer is already present',
      () {
        expect(
          CallManager.shouldRequestOfferRecoveryFromRelay(
            direction: CallDirection.incoming,
            phase: CallPhase.connecting,
            awaitingRemoteOfferLocally: false,
            snapshot: const RelayCallSessionSnapshot(
              exists: true,
              deviceId: 'self-device',
              callId: 'call-1',
              callAttemptId: 'attempt-1',
              state: 'ringing',
              lastAction: 'invite',
            ),
          ),
          isFalse,
        );
      },
    );

    test(
      'requests offer recovery during reconnect when relay still says accepted',
      () {
        expect(
          CallManager.shouldRequestOfferRecoveryFromRelay(
            direction: CallDirection.incoming,
            phase: CallPhase.reconnecting,
            awaitingRemoteOfferLocally: true,
            snapshot: const RelayCallSessionSnapshot(
              exists: true,
              deviceId: 'self-device',
              callId: 'call-1',
              callAttemptId: 'attempt-1',
              state: 'accepted',
              lastAction: 'answer',
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      'does not request reconnect offer recovery without authoritative relay recovery state',
      () {
        expect(
          CallManager.shouldRequestOfferRecoveryFromRelay(
            direction: CallDirection.incoming,
            phase: CallPhase.reconnecting,
            awaitingRemoteOfferLocally: true,
            snapshot: const RelayCallSessionSnapshot(
              exists: true,
              deviceId: 'self-device',
              callId: 'call-1',
              callAttemptId: 'attempt-1',
              state: 'ringing',
              lastAction: 'invite',
            ),
          ),
          isFalse,
        );
      },
    );

    test('resends offer for outgoing reconnect relay state', () {
      expect(
        CallManager.shouldResendOfferRecoveryFromRelay(
          direction: CallDirection.outgoing,
          phase: CallPhase.reconnecting,
          awaitingRemoteAnswerLocally: false,
          snapshot: const RelayCallSessionSnapshot(
            exists: true,
            deviceId: 'self-device',
            callId: 'call-1',
            callAttemptId: 'attempt-1',
            state: 'reconnecting',
            lastAction: 'offer',
          ),
        ),
        isTrue,
      );
    });

    test('resends offer for outgoing relay need_offer action', () {
      expect(
        CallManager.shouldResendOfferRecoveryFromRelay(
          direction: CallDirection.outgoing,
          phase: CallPhase.connecting,
          awaitingRemoteAnswerLocally: false,
          snapshot: const RelayCallSessionSnapshot(
            exists: true,
            deviceId: 'self-device',
            callId: 'call-1',
            callAttemptId: 'attempt-1',
            state: 'ringing',
            lastAction: 'need_offer',
          ),
        ),
        isTrue,
      );
    });

    test(
      'does not resend offer for incoming flow even if relay asks need_offer',
      () {
        expect(
          CallManager.shouldResendOfferRecoveryFromRelay(
            direction: CallDirection.incoming,
            phase: CallPhase.connecting,
            awaitingRemoteAnswerLocally: false,
            snapshot: const RelayCallSessionSnapshot(
              exists: true,
              deviceId: 'self-device',
              callId: 'call-1',
              callAttemptId: 'attempt-1',
              state: 'reconnecting',
              lastAction: 'need_offer',
            ),
          ),
          isFalse,
        );
      },
    );

    test(
      'resends offer when relay says accepted but answer is still missing locally',
      () {
        expect(
          CallManager.shouldResendOfferRecoveryFromRelay(
            direction: CallDirection.outgoing,
            phase: CallPhase.ringingOutgoing,
            awaitingRemoteAnswerLocally: true,
            snapshot: const RelayCallSessionSnapshot(
              exists: true,
              deviceId: 'self-device',
              callId: 'call-1',
              callAttemptId: 'attempt-1',
              state: 'accepted',
              lastAction: 'answer',
              acceptedAtMs: 123,
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      'does not resend accepted-state recovery once answer is already present locally',
      () {
        expect(
          CallManager.shouldResendOfferRecoveryFromRelay(
            direction: CallDirection.outgoing,
            phase: CallPhase.connecting,
            awaitingRemoteAnswerLocally: false,
            snapshot: const RelayCallSessionSnapshot(
              exists: true,
              deviceId: 'self-device',
              callId: 'call-1',
              callAttemptId: 'attempt-1',
              state: 'accepted',
              lastAction: 'answer',
            ),
          ),
          isFalse,
        );
      },
    );

    test('resends offer during reconnect when relay still says accepted', () {
      expect(
        CallManager.shouldResendOfferRecoveryFromRelay(
          direction: CallDirection.outgoing,
          phase: CallPhase.reconnecting,
          awaitingRemoteAnswerLocally: false,
          snapshot: const RelayCallSessionSnapshot(
            exists: true,
            deviceId: 'self-device',
            callId: 'call-1',
            callAttemptId: 'attempt-1',
            state: 'accepted',
            lastAction: 'answer',
            acceptedAtMs: 123,
          ),
        ),
        isTrue,
      );
    });
  });
}
