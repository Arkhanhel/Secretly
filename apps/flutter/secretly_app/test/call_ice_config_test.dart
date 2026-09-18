// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_ice_config.dart';

void main() {
  group('CallIceConfigSnapshot', () {
    test('reports empty config when no ICE servers are present', () {
      const snapshot = CallIceConfigSnapshot.empty();

      expect(snapshot.hasConfiguredIceServers, isFalse);
      expect(snapshot.toRtcIceServers(), isEmpty);
    });

    test('orders relay servers first for relayPreferred', () {
      final snapshot = CallIceConfigSnapshot(
        policy: CallNetworkPolicy.relayPreferred,
        iceServers: const <CallIceServerConfig>[
          CallIceServerConfig(urls: <String>['stun:stun.secretly.test:3478']),
          CallIceServerConfig(
            urls: <String>['turns:turn.secretly.test:5349?transport=tcp'],
            username: 'u',
            credential: 'c',
          ),
        ],
      );

      final rtc = snapshot.toRtcIceServers();
      expect(rtc, hasLength(2));
      expect((rtc.first['urls'] as String), startsWith('turns:'));
      expect(snapshot.rtcIceTransportPolicy, 'all');
    });

    test('relayOnly exports only TURN servers to WebRTC config', () {
      final snapshot = CallIceConfigSnapshot(
        policy: CallNetworkPolicy.relayOnly,
        iceServers: const <CallIceServerConfig>[
          CallIceServerConfig(urls: <String>['stun:stun.secretly.test:3478']),
          CallIceServerConfig(
            urls: <String>['turns:turn.secretly.test:5349?transport=tcp'],
            username: 'u',
            credential: 'c',
          ),
        ],
      );

      final rtc = snapshot.toRtcIceServers();
      expect(rtc, hasLength(1));
      expect((rtc.single['urls'] as String), startsWith('turns:'));
      expect(snapshot.hasUsableRelayServers, isTrue);
    });

    test('relayOnly fails closed when TURN credentials expire', () {
      final snapshot = CallIceConfigSnapshot(
        policy: CallNetworkPolicy.relayOnly,
        expiresAtMs: 100,
        iceServers: const <CallIceServerConfig>[
          CallIceServerConfig(urls: <String>['stun:stun.secretly.test:3478']),
          CallIceServerConfig(
            urls: <String>['turns:turn.secretly.test:5349?transport=tcp'],
            username: 'u',
            credential: 'c',
          ),
        ],
      );

      final pruned = snapshot.pruneExpiredCredentials(nowMs: 200);
      expect(pruned.policy, CallNetworkPolicy.relayOnly);
      expect(pruned.iceServers, isEmpty);
      expect(pruned.hasUsableRelayServers, isFalse);
    });

    test('relayPreferred may still degrade to STUN-only after expiry', () {
      final snapshot = CallIceConfigSnapshot(
        policy: CallNetworkPolicy.relayPreferred,
        expiresAtMs: 100,
        iceServers: const <CallIceServerConfig>[
          CallIceServerConfig(urls: <String>['stun:stun.secretly.test:3478']),
          CallIceServerConfig(
            urls: <String>['turns:turn.secretly.test:5349?transport=tcp'],
            username: 'u',
            credential: 'c',
          ),
        ],
      );

      final pruned = snapshot.pruneExpiredCredentials(nowMs: 200);
      expect(pruned.policy, CallNetworkPolicy.p2pPreferred);
      expect(pruned.iceServers, hasLength(1));
      expect(pruned.iceServers.single.isStun, isTrue);
    });
  });
}