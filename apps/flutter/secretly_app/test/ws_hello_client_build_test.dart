// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Замер раскатки обязан видеть СОКЕТ-ЖИТЕЛЕЙ.
//
// Номер сборки ездил только в заголовке подписанных HTTP-запросов, а активность
// устройства отмечается ещё и на WebSocket-путях. Устройство, которое держит
// сокет и не делает HTTP-pump, отмечалось активным и никогда не называло
// сборку — 29% парка попадали в «версии нет», и по этой графе нельзя было
// отличить необновившегося от обычного пользователя на свежей сборке.
//
// Тест держит границу с обеих сторон: поле есть, когда сборка известна, и его
// НЕТ, когда она пуста (иначе сервер записал бы пустую строку поверх реальной).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/transport/relay_protocol.dart';

void main() {
  test('hello_auth называет сборку, когда она известна', () {
    final msg = jsonDecode(
      ClientMsg.helloAuth(
        deviceId: 'dev-1',
        tsMs: 1700000000000,
        nonceB64: 'bm9uY2U=',
        signatureB64: 'c2ln',
        clientBuild: '544',
      ),
    ) as Map<String, dynamic>;

    expect(msg['type'], 'hello_auth');
    expect(msg['client_build'], '544');
    // Подписываемая часть не изменилась ни на поле: она общая с сервером, и
    // менять её ради счётчика значило бы сломать все существующие сборки.
    expect(msg['device_id'], 'dev-1');
    expect(msg['ts_ms'], 1700000000000);
    expect(msg['nonce_b64'], 'bm9uY2U=');
    expect(msg['signature_b64'], 'c2ln');
  });

  test('без известной сборки поля нет вовсе', () {
    final msg = jsonDecode(
      ClientMsg.helloAuth(
        deviceId: 'dev-1',
        tsMs: 1,
        nonceB64: 'bm9uY2U=',
        signatureB64: 'c2ln',
      ),
    ) as Map<String, dynamic>;

    expect(msg.containsKey('client_build'), isFalse,
        reason: 'пустая строка перезаписала бы реальную сборку на сервере');
  });

  test('legacy hello тоже умеет назвать сборку', () {
    final withBuild =
        jsonDecode(ClientMsg.hello(deviceId: 'dev-1', clientBuild: '544'))
            as Map<String, dynamic>;
    expect(withBuild['client_build'], '544');

    final without = jsonDecode(ClientMsg.hello(deviceId: 'dev-1'))
        as Map<String, dynamic>;
    expect(without.containsKey('client_build'), isFalse);
    expect(without['type'], 'hello');
  });
}
