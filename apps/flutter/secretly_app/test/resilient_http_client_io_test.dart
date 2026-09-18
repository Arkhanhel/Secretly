// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/transport/resilient_http_client_io.dart'
    as transport;

void main() {
  group('resilient IO transport ports', () {
    test('enables websocket DNS fallback by default', () {
      // DELIVERY FIX (2026-06-19): the WebSocket transport now defaults to the
      // IP DNS fallback so a failed host lookup during reconnect (Android
      // background/transition window) does not strand the realtime channel.
      // Overridable via SECRETLY_ENABLE_HTTP_DNS_FALLBACKS_FOR_WEBSOCKETS=false.
      expect(
        transport.debugHttpDnsFallbacksForWebSocketsEnabledForTest(),
        isTrue,
      );
    });

    test('uses scheme defaults when no port is explicit', () {
      expect(
        transport.debugEffectiveConnectionPortForTest(
          Uri.parse('http://relay.example.com/health'),
        ),
        80,
      );
      expect(
        transport.debugEffectiveConnectionPortForTest(
          Uri.parse('https://relay.example.com/health'),
        ),
        443,
      );
      expect(
        transport.debugEffectiveConnectionPortForTest(
          Uri.parse('ws://relay.example.com/ws'),
        ),
        80,
      );
      expect(
        transport.debugEffectiveConnectionPortForTest(
          Uri.parse('wss://relay.example.com/ws'),
        ),
        443,
      );
    });

    test('treats explicit zero ports as scheme defaults', () {
      expect(
        transport.debugEffectiveConnectionPortForTest(
          Uri(scheme: 'https', host: 'relay.example.com', port: 0, path: '/ws'),
        ),
        443,
      );
      expect(
        transport.debugEffectiveConnectionPortForTest(
          Uri(scheme: 'wss', host: 'relay.example.com', port: 0, path: '/ws'),
        ),
        443,
      );
      expect(
        transport.debugEffectiveConnectionPortForTest(
          Uri(scheme: 'ws', host: 'relay.example.com', port: 0, path: '/ws'),
        ),
        80,
      );
    });

    test('preserves explicit ports', () {
      expect(
        transport.debugEffectiveConnectionPortForTest(
          Uri.parse('https://relay.example.com:8443/health'),
        ),
        8443,
      );
      expect(
        transport.debugEffectiveConnectionPortForTest(
          Uri.parse('wss://relay.example.com:9443/ws'),
        ),
        9443,
      );
    });

    test('IP fallback engages on connect-timeout / unreachable, not just DNS', () {
      // DNS lookup failure — original behaviour.
      expect(
        transport.debugShouldTryIpFallbackForTest(
          const SocketException('Failed host lookup: relay.example.com'),
        ),
        isTrue,
      );
      // MIUI cold-connect stall (ETIMEDOUT) — the new behaviour that lets the
      // blob upload race the known-good IPv4 fallback instead of hanging.
      expect(
        transport.debugShouldTryIpFallbackForTest(
          const SocketException('Connection timed out', osError: OSError('', 110)),
        ),
        isTrue,
      );
      // Network unreachable (no IPv6 route).
      expect(
        transport.debugShouldTryIpFallbackForTest(
          const SocketException(
            'Network is unreachable',
            osError: OSError('', 101),
          ),
        ),
        isTrue,
      );
      // An unrelated socket error must NOT trigger the IP fallback.
      expect(
        transport.debugShouldTryIpFallbackForTest(
          const SocketException('Broken pipe', osError: OSError('', 32)),
        ),
        isFalse,
      );
    });
  });
}
