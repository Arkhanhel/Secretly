// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_signal_codec.dart';
import 'package:secretly_app/calls/call_signal_transport.dart';

void main() {
  group('CallSignalCommandCodec', () {
    test('normalizes outbound payload with signalId and callAttemptId', () {
      final normalized = CallSignalCommandCodec.normalizeOutgoingPayload(
        <String, Object?>{'action': 'INVITE', 'callId': 'call-1'},
        fallbackSignalId: 'signal-1',
        createdAtMs: 1234,
      );

      expect(normalized['action'], 'invite');
      expect(normalized['callId'], 'call-1');
      expect(normalized['callAttemptId'], 'call-1');
      expect(normalized['signalId'], 'signal-1');
      expect(normalized['createdAtMs'], 1234);
    });

    test('encodes and decodes call command payloads', () {
      final payload = <String, Object?>{
        'action': 'offer',
        'callId': 'call-2',
        'callAttemptId': 'attempt-2',
        'signalId': 'signal-2',
        'createdAtMs': 5678,
      };

      final encoded = CallSignalCommandCodec.encode(payload);
      final decoded = CallSignalCommandCodec.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!['action'], 'offer');
      expect(decoded['signalId'], 'signal-2');
      expect(decoded['callAttemptId'], 'attempt-2');
    });

    test('builds stable legacy fallback signalId for inbound old payloads', () {
      final signalId = CallSignalCommandCodec.resolveInboundSignalId(
        <String, Object?>{
          'action': 'answer',
          'callId': 'call-3',
          'callAttemptId': 'attempt-3',
          'createdAtMs': 9999,
        },
        senderProfileId: 'peer-1',
        senderDeviceId: 'device-1',
      );

      expect(signalId, 'legacy:peer-1:device-1:call-3:attempt-3:answer:9999');
    });
  });

  group('CallSignalDeliveryPolicy', () {
    test('treats need_offer and ice as critical call signals', () {
      final needOffer = CallSignalDeliveryPolicy.forAction('need_offer');
      final ice = CallSignalDeliveryPolicy.forAction('ice');
      final recoveryIce = CallSignalDeliveryPolicy.forAction(
        'ice',
        recovery: true,
      );

      expect(needOffer.isCritical, isTrue);
      expect(needOffer.strictQueueing, isTrue);
      expect(needOffer.forceRelayFlush, isTrue);
      expect(needOffer.relayFlushTimeoutMs, 1200);
      expect(needOffer.retryBucket, 'call_critical');

      expect(ice.isCritical, isTrue);
      expect(ice.strictQueueing, isTrue);
      expect(ice.forceRelayFlush, isTrue);
      expect(ice.relayFlushTimeoutMs, 1500);
      expect(ice.retryBucket, 'call_critical');

      expect(recoveryIce.isCritical, isTrue);
      expect(recoveryIce.strictQueueing, isTrue);
      expect(recoveryIce.forceRelayFlush, isTrue);
      expect(recoveryIce.relayFlushTimeoutMs, 900);
      expect(recoveryIce.retryBucket, 'call_ice_recovery');
    });

    test('builds call transport metadata json', () {
      final json = CallSignalDeliveryPolicy.buildTransportMetaJson(
        action: 'offer',
        callId: 'call-4',
        callAttemptId: 'attempt-4',
        signalId: 'signal-4',
        createdAtMs: 1111,
        deliveryMode: 'recovery',
      );

      expect(json, contains('call_signal_v1'));
      expect(json, contains('call-4'));
      expect(json, contains('signal-4'));
      expect(json, contains('recovery'));
    });

    test('rejects empty transport signal id', () {
      expect(
        () => CallSignalDeliveryPolicy.buildTransportMetaJson(
          action: 'ice',
          callId: 'call-5',
          callAttemptId: 'attempt-5',
          signalId: '',
          createdAtMs: 1234,
        ),
        throwsArgumentError,
      );
    });
  });
}
