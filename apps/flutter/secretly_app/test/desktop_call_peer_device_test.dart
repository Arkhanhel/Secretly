// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ЗВОНОК — ЭТО ДВА УСТРОЙСТВА, А НЕ ДВА ПРОФИЛЯ (28.09.2026, ПК).
//
// Владелец: «постоянно ошибки соединения, а во время звонка просто
// выключался звонок с „Ошибка связи“». В таблице звонков реле за 28.09
// остались незакрытые «ноги» на устройствах, которые в разговоре не
// участвовали: Android собеседника получил от ПК владельца `offer` и звонил
// «входящим от того, с кем уже говоришь»; iPhone владельца получал ICE по
// звонкам, принятым на ПК. «Отклонить» на таком фантоме уходило всем
// устройствам другой стороны и обрывало живой разговор.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_manager.dart';

bool ignore({
  bool enabled = true,
  String bound = 'dev-peer-pc',
  String current = 'call-1',
  String signal = 'call-1',
  String? from = 'dev-peer-phone',
  String action = 'decline',
}) =>
    CallManager.shouldIgnoreSignalFromForeignDevice(
      enabled: enabled,
      boundPeerDeviceId: bound,
      currentCallId: current,
      signalCallId: signal,
      signalFromDeviceId: from,
      action: action,
    );

void main() {
  group('сигнал по текущему звонку с чужого устройства', () {
    test('🔴 «Отклонить» с фантомного звонка НЕ рвёт живой разговор', () {
      expect(ignore(action: 'decline'), isTrue);
      expect(ignore(action: 'hangup'), isTrue);
    });

    test('SDP и ICE с третьего устройства тоже не наши', () {
      for (final a in ['offer', 'answer', 'ice', 'need_offer']) {
        expect(ignore(action: a), isTrue, reason: a);
      }
    });

    test('сигнал от самого собеседника — принимаем', () {
      expect(ignore(from: 'dev-peer-pc'), isFalse);
    });

    test('не знаем устройства — прежнее поведение', () {
      expect(ignore(bound: ''), isFalse,
          reason: 'исходящий до ответа: любое устройство может ответить');
      expect(ignore(from: null), isFalse,
          reason: 'конверт без отправителя — не наш повод что-то менять');
    });

    test('другой звонок и приглашение — у них свои правила', () {
      expect(ignore(signal: 'call-2'), isFalse);
      expect(ignore(action: 'invite'), isFalse);
    });

    test('на телефоне правило выключено', () {
      expect(ignore(enabled: false), isFalse);
    });
  });

  group('🔴 наши сигналы идут одному устройству собеседника', () {
    final manager = File('lib/calls/call_manager.dart').readAsStringSync();
    final controller = File('lib/app/app_controller.dart').readAsStringSync();

    test('каждая отправка, кроме приглашения, адресована', () {
      final sends = RegExp(
        r'\.sendCall(Offer|Answer|IceCandidate|Hangup|NeedOffer|Decline)\(',
      ).allMatches(manager).length;
      final targeted = RegExp(
        r'toDeviceIds: (_peerTargets|_busyDeclineTargets\(sig\)),',
      ).allMatches(manager).length;
      expect(sends, 16);
      expect(targeted, sends,
          reason: 'забытая отправка снова уйдёт всем устройствам профиля');
    });

    test('«занят» по чужому звонку — тому, кто этот звонок прислал', () {
      expect(
        RegExp(r'toDeviceIds: _busyDeclineTargets\(sig\),')
            .allMatches(manager)
            .length,
        2,
      );
    });

    test('контроллер шлёт точно на заданное устройство, без сверки с кешем',
        () {
      expect(controller, contains('Set<String>? exactTargetDeviceIds,'));
      expect(
        controller,
        contains('final resolvedTargets = (exact != null && exact.isNotEmpty)'),
      );
      expect(
        RegExp(r'exactTargetDeviceIds: toDeviceIds,')
            .allMatches(controller)
            .length,
        6,
        reason: 'offer, answer, ice, hangup, need_offer, decline',
      );
    });

    test('устройство собеседника запоминается при приглашении и при ответе',
        () {
      expect(
        manager,
        contains("_boundPeerDeviceId = (sig.fromDeviceId ?? '').trim();"),
      );
      expect(manager, contains('_boundPeerDeviceId = answeredDevice;'));
      // Новый исходящий начинается с чистого листа.
      final start = manager.indexOf('Future<void> startCall({');
      expect(
        manager.indexOf("_boundPeerDeviceId = '';", start),
        greaterThan(start),
      );
    });

    test('offer без приглашения на ПК придерживается, а не звонит', () {
      final held = manager.indexOf("'offer_before_invite_held'");
      final synthesized = manager.indexOf(
        'offer arrived before invite; synthesized incoming ringing state',
      );
      expect(held, greaterThan(0));
      expect(held, lessThan(synthesized),
          reason: 'ветка ПК обязана выйти раньше, чем телефонная нарисует звонок');
    });
  });
}
