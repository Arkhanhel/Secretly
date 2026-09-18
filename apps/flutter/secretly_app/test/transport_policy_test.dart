// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';

import 'package:secretly_app/transport/transport_policy.dart';

void main() {
  test('Release: allows HTTPS/WSS', () {
    final r = TransportPolicy.evaluate(
      keysBaseUrl: Uri.parse('https://keys.example.com'),
      relayHttpBaseUrl: Uri.parse('https://relay.example.com'),
      relayWsUrl: Uri.parse('wss://relay.example.com/ws'),
      isReleaseMode: true,
      allowInsecureTransport: false,
    );
    expect(r.allowed, true);
    expect(r.warning, isNull);
  });

  test('Release: blocks insecure non-loopback by default', () {
    final r = TransportPolicy.evaluate(
      keysBaseUrl: Uri.parse('http://192.168.1.10:8081'),
      relayHttpBaseUrl: Uri.parse('http://192.168.1.10:8082'),
      relayWsUrl: Uri.parse('ws://192.168.1.10:8082/ws'),
      isReleaseMode: true,
      allowInsecureTransport: false,
    );
    expect(r.allowed, false);
    expect(r.warning, isNotNull);
  });

  test('Release: allows insecure loopback (adb reverse/local)', () {
    final r = TransportPolicy.evaluate(
      keysBaseUrl: Uri.parse('http://127.0.0.1:8081'),
      relayHttpBaseUrl: Uri.parse('http://localhost:8082'),
      relayWsUrl: Uri.parse('ws://127.0.0.1:8082/ws'),
      isReleaseMode: true,
      allowInsecureTransport: false,
    );
    expect(r.allowed, true);
  });

  test('Debug/profile: allows insecure', () {
    final r = TransportPolicy.evaluate(
      keysBaseUrl: Uri.parse('http://192.168.1.10:8081'),
      relayHttpBaseUrl: Uri.parse('http://192.168.1.10:8082'),
      relayWsUrl: Uri.parse('ws://192.168.1.10:8082/ws'),
      isReleaseMode: false,
      allowInsecureTransport: false,
    );
    expect(r.allowed, true);
  });
}
