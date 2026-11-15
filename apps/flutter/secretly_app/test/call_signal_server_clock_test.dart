// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ВОЗРАСТ СИГНАЛА ЗВОНКА — ПО СЕРВЕРНЫМ ЧАСАМ (13.11.2026).
//
// Получатель отбрасывает приглашение старше 45 с. Время ставил телефон
// звонящего, сверял — телефон получателя: при часах, сбитых на минуту у
// любого из двух, звонок молча не проходил. Теперь обе стороны берут время
// ServerClock (время телефона с поправкой по серверу).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final calls = File('lib/calls/call_manager.dart').readAsStringSync();
  final app = File('lib/app/app_controller.dart').readAsStringSync();

  test('возраст сигнала считается от ServerClock, а не от часов телефона', () {
    expect(
      calls.contains('DateTime.now().millisecondsSinceEpoch - sig.createdAtMs'),
      isFalse,
    );
    expect(
      RegExp(r'ServerClock\.instance\.nowMs\(\)\s*-\s*sig\.createdAtMs')
          .allMatches(calls)
          .length,
      greaterThanOrEqualTo(2),
    );
  });

  test('сигналы звонка помечаются временем ServerClock', () {
    for (final fn in const [
      'sendCallInvite',
      'sendCallDecline',
      'sendCallHangup',
      'sendCallOffer',
      'sendCallAnswer',
    ]) {
      final start = app.indexOf('  Future<');
      expect(start, greaterThanOrEqualTo(0));
      final at = app.indexOf(' $fn({');
      expect(at, greaterThan(0), reason: fn);
      final body = app.substring(at, app.indexOf('\n  }\n', at));
      expect(body.contains("'createdAtMs': ServerClock.instance.nowMs()"), isTrue,
          reason: fn);
    }
  });
}
