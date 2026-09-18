// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/webrtc_call_session.dart';

void main() {
  group('WebRtcCallSession.normalizeIceTransportPolicy', () {
    test('defaults blank and unknown values to all', () {
      expect(WebRtcCallSession.normalizeIceTransportPolicy(''), 'all');
      expect(WebRtcCallSession.normalizeIceTransportPolicy('  weird  '), 'all');
    });

    test('keeps relay policy after trimming', () {
      expect(WebRtcCallSession.normalizeIceTransportPolicy(' relay '), 'relay');
    });
  });

  group('WebRtcCallSession.buildPeerConnectionConfiguration', () {
    test('normalizes ICE servers and policy for peer connection config', () {
      final configuration = WebRtcCallSession.buildPeerConnectionConfiguration(
        iceServers: <Map<String, Object?>>[
          <String, Object?>{
            'urls': <String>[' stun:stun.secretly.test:3478 '],
          },
          <String, Object?>{
            'urls': <String>[
              ' turns:turn.secretly.test:5349?transport=tcp ',
              ' turn:turn.secretly.test:3478?transport=udp ',
            ],
            'username': ' user ',
            'credential': ' cred ',
          },
        ],
        iceTransportPolicy: ' relay ',
      );

      expect(configuration['sdpSemantics'], 'unified-plan');
      expect(configuration['iceTransportPolicy'], 'relay');

      final iceServers =
          (configuration['iceServers'] as List).cast<Map<String, Object?>>();
      expect(iceServers, hasLength(2));
      expect(iceServers.first['urls'], 'stun:stun.secretly.test:3478');
      expect(iceServers.last['urls'], <String>[
        'turns:turn.secretly.test:5349?transport=tcp',
        'turn:turn.secretly.test:3478?transport=udp',
      ]);
      expect(iceServers.last['username'], 'user');
      expect(iceServers.last['credential'], 'cred');
    });
  });

  group('WebRtcCallSession.shouldApplyRuntimeIceConfiguration', () {
    test('skips runtime reconfigure for equivalent normalized config', () {
      expect(
        WebRtcCallSession.shouldApplyRuntimeIceConfiguration(
          currentIceServers: <Map<String, Object?>>[
            <String, Object?>{'urls': 'turn:turn.secretly.test:3478'},
          ],
          currentIceTransportPolicy: ' relay ',
          nextIceServers: <Map<String, Object?>>[
            <String, Object?>{
              'urls': <String>[' turn:turn.secretly.test:3478 '],
            },
          ],
          nextIceTransportPolicy: 'relay',
        ),
        isFalse,
      );
    });

    test('requests runtime reconfigure when ICE servers change', () {
      expect(
        WebRtcCallSession.shouldApplyRuntimeIceConfiguration(
          currentIceServers: <Map<String, Object?>>[
            <String, Object?>{'urls': 'stun:stun.secretly.test:3478'},
          ],
          currentIceTransportPolicy: 'all',
          nextIceServers: <Map<String, Object?>>[
            <String, Object?>{'urls': 'turn:turn.secretly.test:3478'},
          ],
          nextIceTransportPolicy: 'all',
        ),
        isTrue,
      );
    });

    test('requests runtime reconfigure when transport policy changes', () {
      expect(
        WebRtcCallSession.shouldApplyRuntimeIceConfiguration(
          currentIceServers: <Map<String, Object?>>[
            <String, Object?>{'urls': 'turn:turn.secretly.test:3478'},
          ],
          currentIceTransportPolicy: 'all',
          nextIceServers: <Map<String, Object?>>[
            <String, Object?>{'urls': 'turn:turn.secretly.test:3478'},
          ],
          nextIceTransportPolicy: 'relay',
        ),
        isTrue,
      );
    });
  });
}