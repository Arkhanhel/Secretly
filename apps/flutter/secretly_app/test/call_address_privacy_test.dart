// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/app/app_controller.dart';
import 'package:secretly_app/calls/call_ice_config.dart';
import 'package:secretly_app/calls/call_manager.dart';

// SEC-10② и SEC-10③ (26.08.2026).
//
// ② Запасные STUN были зашиты на публичные серверы Google. На проде они не
//   использовались — релей отдаёт свои, — но в том единственном случае, ради
//   которого запасной вариант и существует, Google видел бы адрес звонящего,
//   время и факт звонка.
//
// ③ Механизм «только через сервер» существовал, но человеку был недоступен:
//   политику назначал сервер, а по умолчанию соединение прямое — то есть
//   собеседник видит IP-адрес.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SEC-10② запасной STUN', () {
    test('🔴 берётся из адреса релея, а не зашит', () {
      final servers = CallManager.fallbackStunServersFor(
        Uri.parse('https://relay.example.org'),
      );
      expect(servers, hasLength(1));
      expect(servers.single.urls.single, 'stun:relay.example.org:3478');
    });

    test('🔴 чужая установка не шлёт адреса своих людей нам', () {
      // Проект открыт под AGPL. Зашитый `relay.secretlyapp.com` означал бы,
      // что форк молча отправляет метаданные СВОИХ пользователей НАМ — та же
      // ошибка, что с Google, только теперь мы в роли третьей стороны.
      final servers = CallManager.fallbackStunServersFor(
        Uri.parse('https://relay.chuzhoy-forkgo.example'),
      );
      expect(servers.single.urls.single, contains('chuzhoy-forkgo.example'));
      expect(servers.single.urls.single, isNot(contains('secretlyapp')));
    });

    test('пустой адрес даёт пустой список, а не выдуманный сервер', () {
      expect(CallManager.fallbackStunServersFor(Uri.parse('')), isEmpty);
    });

    test('🔴 чужих STUN в коде звонков не осталось', () {
      // Сторож «не возвращаться»: строка ищется по частям, иначе тест поймал
      // бы собственный текст.
      final needle = 'l.' 'google' '.com';
      for (final entity in Directory('lib/calls').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        expect(
          entity.readAsStringSync(),
          isNot(contains(needle)),
          reason: '${entity.path}: чужой STUN вернулся',
        );
      }
    });
  });

  group('SEC-10③ скрывать адрес', () {
    const direct = CallIceConfigSnapshot(
      policy: CallNetworkPolicy.p2pPreferred,
      iceServers: <CallIceServerConfig>[],
    );

    test('🔴 выключено — политика сервера не трогается', () {
      final out = AppController.applyCallAddressPrivacy(
        direct,
        hideAddress: false,
      );
      expect(out.policy, CallNetworkPolicy.p2pPreferred);
    });

    test('🔴 включено — политика поднимается до «только через сервер»', () {
      final out = AppController.applyCallAddressPrivacy(
        direct,
        hideAddress: true,
      );
      expect(out.policy, CallNetworkPolicy.relayOnly);
    });

    test('🔴 настройка только ПОДНИМАЕТ защиту, никогда не снимает', () {
      // Обратная защёлка. Если сервер уже назначил `relayOnly`, выключенная
      // настройка не имеет права вернуть прямое соединение: человек её не
      // включал, но и отказываться от назначенной защиты не просил.
      const assigned = CallIceConfigSnapshot(
        policy: CallNetworkPolicy.relayOnly,
        iceServers: <CallIceServerConfig>[],
      );
      expect(
        AppController.applyCallAddressPrivacy(
          assigned,
          hideAddress: false,
        ).policy,
        CallNetworkPolicy.relayOnly,
      );
    });

    test('серверы и срок годности переносятся без потерь', () {
      const withServers = CallIceConfigSnapshot(
        policy: CallNetworkPolicy.p2pPreferred,
        iceServers: <CallIceServerConfig>[
          CallIceServerConfig(urls: <String>['turn:t.example:3478']),
        ],
        expiresAtMs: 1234,
      );
      final out = AppController.applyCallAddressPrivacy(
        withServers,
        hideAddress: true,
      );
      expect(out.iceServers.single.urls.single, 'turn:t.example:3478');
      expect(out.expiresAtMs, 1234);
    });
  });
}
