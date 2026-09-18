// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Пустой снимок конфигурации ICE обязан считаться ИСТЁКШИМ.
//
// Кэш ICE живёт только в памяти: после каждого холодного старта он пуст. У
// пустого снимка нет срока годности, и прежняя проверка отвечала на это «не
// истёк» — `AppController.getCallIceConfig` честно возвращала пустую
// конфигурацию, НЕ обращаясь к реле. Дальше подмешивались запасные STUN, и
// звонок уходил без единого TURN.
//
// Замер поля 22.08.2026, первый звонок после запуска:
//   call.ice_no_turn_servers policy=p2pPreferred totalIceServers=2 stunOnly=true
// хотя реле отдаёт relay_preferred и три TURN-адреса. Между двумя NAT такой
// звонок либо не соединяется, либо соединяется без звука.
//
// Это ТОТ ЖЕ класс дефекта, что чинили 29.05 для просроченного снимка
// (`expiresAtMs: null` = «вечно свежий») — тогда пустой случай пропустили.

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_ice_config.dart';

void main() {
  test('пустой снимок истёк — иначе за настоящим никто не сходит', () {
    const empty = CallIceConfigSnapshot.empty();
    expect(empty.iceServers, isEmpty);
    expect(empty.isExpired(), isTrue,
        reason: 'пустая конфигурация — это «её ещё нет», а не «она свежая»');
  });

  test('снимок с серверами и без срока по-прежнему свежий', () {
    // Реле может не прислать срок для STUN-только конфигурации: такой снимок
    // пригоден и перезапрашивать его каждый раз незачем.
    const snapshot = CallIceConfigSnapshot(
      policy: CallNetworkPolicy.p2pPreferred,
      iceServers: <CallIceServerConfig>[
        CallIceServerConfig(urls: <String>['stun:relay.example:3478']),
      ],
    );
    expect(snapshot.isExpired(), isFalse);
  });

  test('срок годности продолжает работать', () {
    final snapshot = CallIceConfigSnapshot(
      policy: CallNetworkPolicy.relayPreferred,
      iceServers: const <CallIceServerConfig>[
        CallIceServerConfig(urls: <String>['turn:relay.example:3478']),
      ],
      expiresAtMs: 1000,
    );
    expect(snapshot.isExpired(nowMs: 999), isFalse);
    expect(snapshot.isExpired(nowMs: 1000), isTrue);
  });

  test('обрезка просроченных данных не ломается о пустой снимок', () {
    const empty = CallIceConfigSnapshot.empty();
    final pruned = empty.pruneExpiredCredentials(nowMs: 5000);
    expect(pruned.iceServers, isEmpty);
    expect(pruned.isExpired(nowMs: 5000), isTrue,
        reason: 'обрезанный пустой снимок обязан остаться истёкшим');
  });
}
