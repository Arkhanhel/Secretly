// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/entitlements/entitlement_signature.dart';
import 'package:secretly_app/messages/transport_flags.dart';

// Э1 (11.10.2026): блок `transport` подписанного конфига.

void main() {
  test('🔴 строка подписи побайтово как на сервере', () {
    expect(
      transportSigningMessage(
        enabled: true,
        reportEnabled: false,
        torEnabled: false,
        endpointsVersion: 1700000000000,
        issuedAtMs: 42,
      ),
      'secretly-transport-v1|true|false|false|1700000000000|42',
    );
  });

  test('непроверенный блок — умолчания; проверенный — значения сервера', () {
    final config = <String, dynamic>{
      'transport': <String, dynamic>{
        'enabled': false,
        'report_enabled': false,
        'tor_enabled': true,
        'endpoints_version': 555,
        'issued_at_ms': 1,
      },
    };
    expect(
      TransportFlags.fromConfigResponse(config, verified: false),
      TransportFlags.defaults,
    );
    final flags = TransportFlags.fromConfigResponse(config, verified: true);
    expect(flags.enabled, isFalse);
    expect(flags.reportEnabled, isFalse);
    expect(flags.torEnabled, isTrue);
    expect(flags.endpointsVersion, 555);
    expect(
      TransportFlags.fromConfigResponse(<String, dynamic>{}, verified: true),
      TransportFlags.defaults,
      reason: 'старый сервер без блока — как было',
    );
  });

  test('умолчания: прокси и отчёты включены, Tor выключен', () {
    const d = TransportFlags.defaults;
    expect(d.enabled, isTrue);
    expect(d.reportEnabled, isTrue);
    expect(d.torEnabled, isFalse);
    expect(d.endpointsVersion, 0);
  });

  test('без ключа подписи блок не проверяется', () async {
    expect(
      await verifyTransportSignature(<String, dynamic>{
        'transport': <String, dynamic>{'enabled': true},
        'transport_signature': 'AAAA',
      }),
      isFalse,
    );
  });
}
