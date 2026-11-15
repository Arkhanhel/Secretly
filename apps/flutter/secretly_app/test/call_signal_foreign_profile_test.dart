// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 СИГНАЛ ПО ЧУЖОМУ ЗВОНКУ (11.11.2026, телефон и ПК).
//
// `callId` и `attemptId` реле видит открыто. Раньше телефон принимал
// `answer`/`ice`/`hangup` по совпадению этих двух чисел, не сверяя, кто
// прислал: любой контакт мог оборвать чужой разговор своим `hangup`.
// Теперь по текущему звонку принимаются сигналы только от собеседника или
// от моих же устройств.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_manager.dart';

void main() {
  bool ignored({
    String currentCallId = 'call-1',
    String peer = 'bob',
    String self = 'me',
    String signalCallId = 'call-1',
    required String from,
  }) => CallManager.shouldIgnoreSignalFromForeignProfile(
    currentCallId: currentCallId,
    currentPeerProfileId: peer,
    selfProfileId: self,
    signalCallId: signalCallId,
    signalFromProfileId: from,
  );

  test('сигнал собеседника по текущему звонку принимается', () {
    expect(ignored(from: 'bob'), isFalse);
    expect(ignored(from: ' bob '), isFalse);
  });

  test('сигнал с моего другого устройства принимается', () {
    expect(ignored(from: 'me'), isFalse);
  });

  test('🔴 чужой профиль по текущему звонку — игнорируется', () {
    expect(ignored(from: 'mallory'), isTrue);
  });

  test('другой звонок не судим — его разбирают обычные проверки', () {
    expect(ignored(signalCallId: 'call-2', from: 'mallory'), isFalse);
  });

  test('звонка нет — новое приглашение не трогаем', () {
    expect(ignored(currentCallId: '', from: 'mallory'), isFalse);
  });

  test('неизвестный отправитель или собеседник — как раньше, не судим', () {
    expect(ignored(from: ''), isFalse);
    expect(ignored(peer: '', from: 'mallory'), isFalse);
  });

  test('пустой свой профиль не делает чужого «своим»', () {
    expect(ignored(self: '', from: 'mallory'), isTrue);
  });
}
