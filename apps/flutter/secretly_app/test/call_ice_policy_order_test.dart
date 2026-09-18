// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ПОРЯДОК ПРОВЕРКИ ПОЛИТИКИ ICE (SEC-10).
//
// `validateIceConfigForSession` отвергает политику «только через сервер»
// (`relayOnly`), когда TURN-серверов нет: без них скрыть адрес невозможно, и
// звонок должен честно не состояться, а не пойти напрямую.
//
// 🔴 Проверка не срабатывала. Она стояла ПОСЛЕ
// `_augmentIceConfigWithFallback`, а подстановка сама переписывает `relayOnly`
// на `p2pPreferred` и добавляет запасные серверы — к моменту проверки
// конфигурация выглядела исправной. Человек, которому назначено скрывать
// адрес, молча звонил напрямую и не узнавал об этом.
//
// Это третий случай одного класса за два дня: страховка повторов, включавшаяся
// только при успехе (24.08), проверка приватности на стороне клиента (SEC-07),
// и вот этот. Поэтому порядок сторожится тестом по исходнику: перестановка
// строк беззвучна — ничего не падает и не печатает ошибку.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_ice_config.dart';
import 'package:secretly_app/calls/call_manager.dart';

void main() {
  final source = File('lib/calls/call_manager.dart').readAsStringSync();

  group('порядок в исходнике', () {
    test('🔴 проверка политики стоит ДО подстановки запасных серверов', () {
      // Каждое место, где вызывается и проверка, и подстановка, обязано
      // вызывать их именно в этом порядке.
      final lines = source.split('\n');
      final validateAt = <int>[];
      final augmentAt = <int>[];
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (l.contains('validateIceConfigForSession(') &&
            !l.contains('static String?')) {
          validateAt.add(i);
        }
        if (l.contains('_augmentIceConfigWithFallback(') &&
            !l.contains('static CallIceConfigSnapshot') &&
            !l.trimLeft().startsWith('//')) {
          augmentAt.add(i);
        }
      }

      expect(validateAt, isNotEmpty, reason: 'проверка политики исчезла');
      expect(augmentAt, isNotEmpty, reason: 'подстановка исчезла');

      // Для каждой проверки ищем ближайшую подстановку в пределах её функции.
      for (final v in validateAt) {
        final nearby = augmentAt.where((a) => (a - v).abs() < 30).toList();
        for (final a in nearby) {
          expect(
            v,
            lessThan(a),
            reason: 'строка ${v + 1}: проверка политики стоит ПОСЛЕ подстановки '
                '(строка ${a + 1}). Подстановка переписывает relayOnly на '
                'прямое соединение, и проверка перестаёт срабатывать — адрес '
                'раскроется вопреки политике',
          );
        }
      }
    });

    test('подстановка не осталась без всякой проверки', () {
      // Единственное место, где подстановка идёт первой, — путь восстановления
      // связи: там проверка требует именно TURN, которого подстановка не даёт.
      expect(
        source.contains('hasUsableRelayServers'),
        isTrue,
        reason: 'путь восстановления связи лишился проверки наличия TURN',
      );
    });
  });

  group('поведение проверки', () {
    test('🔴 relayOnly без TURN отвергается', () {
      const config = CallIceConfigSnapshot(
        policy: CallNetworkPolicy.relayOnly,
        iceServers: [
          CallIceServerConfig(urls: ['stun:stun.example.com:3478']),
        ],
      );
      expect(
        CallManager.validateIceConfigForSession(config),
        isNotNull,
        reason: 'политика «скрывать адрес» принята без TURN — скрывать нечем, '
            'звонок пойдёт напрямую',
      );
    });

    test('relayOnly с TURN проходит', () {
      const config = CallIceConfigSnapshot(
        policy: CallNetworkPolicy.relayOnly,
        iceServers: [
          CallIceServerConfig(urls: ['turn:turn.example.com:3478']),
        ],
      );
      expect(CallManager.validateIceConfigForSession(config), isNull);
    });

    test('обычная политика без серверов проходит — их подставят', () {
      const config = CallIceConfigSnapshot(
        policy: CallNetworkPolicy.p2pPreferred,
        iceServers: <CallIceServerConfig>[],
      );
      expect(CallManager.validateIceConfigForSession(config), isNull);
    });
  });
}
