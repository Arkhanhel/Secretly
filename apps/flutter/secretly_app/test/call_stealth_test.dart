// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/calls/call_ice_config.dart';

// Э5: звонок под цензурой — только через сервер, по возможности только TURN
// по TLS на 443. Скрытный режим защиту только поднимает.

const _servers = <CallIceServerConfig>[
  CallIceServerConfig(urls: <String>['stun:relay.example.com:3478']),
  CallIceServerConfig(
    urls: <String>[
      'turn:relay.example.com:3478?transport=udp',
      'turn:relay.example.com:3478?transport=tcp',
      'turns:relay.example.com:5349?transport=tcp',
    ],
    username: 'u',
    credential: 'c',
  ),
  CallIceServerConfig(
    urls: <String>['turns:t1.example.net:443?transport=tcp'],
    username: 'u2',
    credential: 'c2',
  ),
];

void main() {
  test('распознаётся только turns: с явным 443', () {
    expect(CallIceServerConfig.isTlsTurnOn443('turns:t1.example.net:443?transport=tcp'), isTrue);
    expect(CallIceServerConfig.isTlsTurnOn443('TURNS:t1.example.net:443'), isTrue);
    expect(CallIceServerConfig.isTlsTurnOn443('turns:t1.example.net'), isFalse,
        reason: 'без порта у turns: 5349');
    expect(CallIceServerConfig.isTlsTurnOn443('turns:t1.example.net:5349'), isFalse);
    expect(CallIceServerConfig.isTlsTurnOn443('turn:t1.example.net:443'), isFalse);
  });

  test('🔴 скрытный режим: только через сервер и только TLS на 443', () {
    const config = CallIceConfigSnapshot(
      policy: CallNetworkPolicy.relayPreferred,
      iceServers: _servers,
      expiresAtMs: 99,
    );
    final out = AppController.applyCallStealth(config, stealth: true);
    expect(out.policy, CallNetworkPolicy.relayOnly);
    expect(out.rtcIceTransportPolicy, 'relay');
    expect(out.iceServers.single.urls, <String>['turns:t1.example.net:443?transport=tcp']);
    expect(out.iceServers.single.username, 'u2');
    expect(out.expiresAtMs, 99);
  });

  test('без TLS на 443 — всё равно только через сервер, со всеми TURN', () {
    final config = CallIceConfigSnapshot(
      policy: CallNetworkPolicy.p2pPreferred,
      iceServers: _servers.sublist(0, 2),
      expiresAtMs: 1,
    );
    final out = AppController.applyCallStealth(config, stealth: true);
    expect(out.policy, CallNetworkPolicy.relayOnly);
    final urls = out.toRtcIceServers().expand((m) {
      final u = m['urls'];
      return u is List ? u.cast<String>() : <String>[u as String];
    }).toList();
    expect(urls.every((u) => u.startsWith('turn')), isTrue, reason: 'STUN отброшен');
  });

  test('без скрытного режима конфигурация не трогается', () {
    const config = CallIceConfigSnapshot(
      policy: CallNetworkPolicy.relayPreferred,
      iceServers: _servers,
    );
    expect(identical(AppController.applyCallStealth(config, stealth: false), config), isTrue);
  });
}
