// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Блок `calls` подписанного /v1/config (ТЗ E2EE созвонов, ЗВ-С6, ЗР-18).

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/messages/call_flags.dart';

void main() {
  test('🔴 подписываемое сообщение побайтово как у keys', () {
    expect(
      callsSigningMessage(
        groupCallsEnabled: true,
        e2eeCreatePercent: 0,
        e2eeRequired: false,
        maxParticipantsE2ee: 20,
        keySwitchDelayMs: 2000,
        joinRatchet: false,
        issuedAtMs: 1760000000000,
      ),
      'secretly-calls-v1|true|0|false|20|2000|false|1760000000000',
    );
  });

  test('без ключа в сборке подпись не проверяется — блок не принят', () async {
    final verified = await verifyCallsSignature(<String, dynamic>{
      'calls': <String, dynamic>{'e2ee_required': true},
      'calls_signature': 'AAAA',
    });
    expect(verified, isFalse);
  });

  test('непроверенный блок — всё как было', () {
    final flags = CallFlags.fromConfigResponse(<String, dynamic>{
      'calls': <String, dynamic>{
        'group_calls_enabled': false,
        'e2ee_create_percent': 100,
        'e2ee_required': true,
      },
    }, verified: false);
    expect(flags, CallFlags.defaults);
    expect(flags.groupCallsEnabled, isTrue);
    expect(flags.e2eeCreatePercent, 0);
    expect(flags.e2eeRequired, isFalse);
  });

  test('проверенный блок читается и зажимается', () {
    final flags = CallFlags.fromConfigResponse(<String, dynamic>{
      'calls': <String, dynamic>{
        'group_calls_enabled': true,
        'e2ee_create_percent': 250,
        'e2ee_required': false,
        'max_participants_e2ee': 500,
        'key_switch_delay_ms': 10,
        'join_ratchet': true,
      },
    }, verified: true);
    expect(flags.e2eeCreatePercent, 100);
    expect(flags.maxParticipantsE2ee, 50);
    expect(flags.keySwitchDelayMs, 500);
    expect(flags.joinRatchet, isTrue);
  });

  test('доля: 0 — никому, 100 — всем, флаг-день — всем, пустое '
      'устройство — никогда', () {
    const zero = CallFlags();
    const all = CallFlags(e2eeCreatePercent: 100);
    const required = CallFlags(e2eeRequired: true);
    expect(zero.e2eeCreateFor('dev-1'), isFalse);
    expect(all.e2eeCreateFor('dev-1'), isTrue);
    expect(all.e2eeCreateFor('  '), isFalse);
    expect(required.e2eeCreateFor('dev-1'), isTrue);
  });

  test('доля детерминирована по устройству и примерно равна заявленной', () {
    const half = CallFlags(e2eeCreatePercent: 50);
    var inRollout = 0;
    for (var i = 0; i < 2000; i++) {
      final id = 'device-$i';
      expect(half.e2eeCreateFor(id), half.e2eeCreateFor(id));
      if (half.e2eeCreateFor(id)) inRollout += 1;
    }
    expect(inRollout, inInclusiveRange(850, 1150));
  });
}
