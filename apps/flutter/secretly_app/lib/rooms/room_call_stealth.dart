// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Групповой созвон под цензурой (Э5).
///
/// Звонок один на один уже умеет это: когда приложение дошло до сервера
/// обходным путём, `AppController.applyCallStealth` оставляет «только через
/// сервер» и, если сервер их дал, только TURN поверх TLS на 443 — снаружи
/// такой поток выглядит как обычный HTTPS.
///
/// У группового созвона своё сетевое хозяйство: соединение держит LiveKit, и
/// список серверов ему обычно выдаёт сам сервер созвонов. Поэтому решение
/// принимается здесь и отдаётся LiveKit настройкой соединения.
///
/// 🔴 ПОЧЕМУ БЕЗ TURN НА 443 МЫ НИЧЕГО НЕ МЕНЯЕМ. «Только через сервер» без
/// пригодного TURN — это не защита, а отсутствие связи: кандидатов не будет
/// вовсе, и созвон просто не соберётся. У звонка один на один такой запрет
/// честно обрывает попытку, и человек видит отказ; групповой созвон на
/// несколько человек оборвался бы у всех сразу. Поэтому пока сервер не выдаёт
/// `turns:…:443`, групповой созвон идёт как прежде. Как только выдаст —
/// обходной путь автоматически включает этот режим, без правки клиента.
library;

import 'package:livekit_client/livekit_client.dart' as lk;

import '../calls/call_ice_config.dart';

/// Что именно отдать LiveKit: соединяться только через эти серверы.
class RoomCallStealthPlan {
  const RoomCallStealthPlan({required this.iceServers});

  /// Только TURN поверх TLS на 443, с учётными данными сервера.
  final List<CallIceServerConfig> iceServers;

  bool get isEmpty => iceServers.isEmpty;
}

/// Решение по снимку настройки звонка.
///
/// [stealth] — приложение идёт к серверу обходным путём. [config] — настройка,
/// полученная через единственное горло `AppController.getCallIceConfig`.
/// Возвращает `null`, когда менять нечего.
RoomCallStealthPlan? roomCallStealthPlanFor({
  required bool stealth,
  required CallIceConfigSnapshot config,
}) {
  if (!stealth) return null;
  final servers = <CallIceServerConfig>[];
  for (final server in config.iceServers) {
    final urls = server.urls
        .where(CallIceServerConfig.isTlsTurnOn443)
        .toList(growable: false);
    if (urls.isEmpty) continue;
    servers.add(
      CallIceServerConfig(
        urls: urls,
        username: server.username,
        credential: server.credential,
      ),
    );
  }
  if (servers.isEmpty) return null;
  return RoomCallStealthPlan(iceServers: servers);
}

/// Настройка соединения LiveKit. Без плана — ровно то, что было до Э5.
lk.ConnectOptions roomCallConnectOptions({
  required RoomCallStealthPlan? plan,
  required bool autoSubscribe,
}) {
  if (plan == null || plan.isEmpty) {
    return lk.ConnectOptions(autoSubscribe: autoSubscribe);
  }
  return lk.ConnectOptions(
    autoSubscribe: autoSubscribe,
    rtcConfiguration: lk.RTCConfiguration(
      iceTransportPolicy: lk.RTCIceTransportPolicy.relay,
      iceServers: <lk.RTCIceServer>[
        for (final server in plan.iceServers)
          lk.RTCIceServer(
            urls: server.urls,
            username: server.username,
            credential: server.credential,
          ),
      ],
    ),
  );
}
