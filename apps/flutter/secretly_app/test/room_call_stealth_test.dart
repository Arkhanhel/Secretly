// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:secretly_app/calls/call_ice_config.dart';
import 'package:secretly_app/rooms/room_call_stealth.dart';

// Э5: групповой созвон под цензурой. Запрет прямого соединения включается
// ТОЛЬКО когда есть чем его заменить — иначе созвон не собрался бы вовсе.

const _tls443 = CallIceServerConfig(
  urls: <String>['turns:t1.example.net:443?transport=tcp'],
  username: 'u443',
  credential: 'c443',
);

const _plainTurn = CallIceServerConfig(
  urls: <String>[
    'turn:relay.example.com:3478?transport=udp',
    'turns:relay.example.com:5349?transport=tcp',
  ],
  username: 'u',
  credential: 'c',
);

const _stun = CallIceServerConfig(urls: <String>['stun:relay.example.com:3478']);

void main() {
  test('🔴 без TURN по TLS на 443 ничего не меняем', () {
    const config = CallIceConfigSnapshot(
      policy: CallNetworkPolicy.relayPreferred,
      iceServers: <CallIceServerConfig>[_stun, _plainTurn],
    );
    expect(roomCallStealthPlanFor(stealth: true, config: config), isNull);
  });

  test('без обходного пути ничего не меняем', () {
    const config = CallIceConfigSnapshot(
      policy: CallNetworkPolicy.relayPreferred,
      iceServers: <CallIceServerConfig>[_tls443],
    );
    expect(roomCallStealthPlanFor(stealth: false, config: config), isNull);
  });

  test('🔴 план оставляет только TLS на 443, с учётными данными', () {
    const config = CallIceConfigSnapshot(
      policy: CallNetworkPolicy.p2pPreferred,
      iceServers: <CallIceServerConfig>[_stun, _plainTurn, _tls443],
    );
    final plan = roomCallStealthPlanFor(stealth: true, config: config);
    expect(plan, isNotNull);
    expect(plan!.iceServers.single.urls, <String>[
      'turns:t1.example.net:443?transport=tcp',
    ]);
    expect(plan.iceServers.single.username, 'u443');
    expect(plan.iceServers.single.credential, 'c443');
  });

  test('🔴 настройка LiveKit: только через сервер, только наши адреса', () {
    const plan = RoomCallStealthPlan(iceServers: <CallIceServerConfig>[_tls443]);
    final options = roomCallConnectOptions(plan: plan, autoSubscribe: false);
    expect(options.autoSubscribe, isFalse);
    expect(
      options.rtcConfiguration.iceTransportPolicy,
      lk.RTCIceTransportPolicy.relay,
    );
    final servers = options.rtcConfiguration.iceServers;
    expect(servers, isNotNull);
    expect(servers!.single.urls, <String>[
      'turns:t1.example.net:443?transport=tcp',
    ]);
    expect(servers.single.username, 'u443');
  });

  test('без плана настройка соединения прежняя', () {
    final options = roomCallConnectOptions(plan: null, autoSubscribe: true);
    expect(options.autoSubscribe, isTrue);
    expect(options.rtcConfiguration.iceTransportPolicy, isNull);
    expect(options.rtcConfiguration.iceServers, isNull);
    // Пустой план равнозначен отсутствию плана: запрета без замены не бывает.
    final empty = roomCallConnectOptions(
      plan: const RoomCallStealthPlan(iceServers: <CallIceServerConfig>[]),
      autoSubscribe: false,
    );
    expect(empty.rtcConfiguration.iceTransportPolicy, isNull);
  });
}
