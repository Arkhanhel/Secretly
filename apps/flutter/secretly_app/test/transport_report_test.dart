// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/transport/transport_report.dart';

// Э1: отчёт о путях доставки обезличен по построению. Главный тест здесь —
// сторож ключей: ни один новый ключ не попадёт в отчёт незамеченным.

void main() {
  test('🔴 в отчёте только разрешённые ключи и никаких идентификаторов', () {
    const r = TransportReport(
      build: 655,
      platform: 'android',
      netKind: 'cellular',
      pathUsed: 'mirror',
      pathsFailed: <String>['direct', 'ip'],
      countryHint: 'UA',
    );
    final json = r.toJson();
    expect(json.keys.toSet(), TransportReport.allowedKeys);
    final text = jsonEncode(json).toLowerCase();
    for (final forbidden in <String>['profile', 'device', 'ip_addr', 'ssid', 'signature']) {
      expect(text.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test('тип сети и страна нормализуются', () {
    expect(TransportReport.netKindFrom('WIFI'), 'wifi');
    expect(TransportReport.netKindFrom('cellular'), 'cellular');
    expect(TransportReport.netKindFrom('ethernet'), 'ethernet');
    expect(TransportReport.netKindFrom('vpn'), 'vpn');
    expect(TransportReport.netKindFrom(null), 'other');
    expect(TransportReport.countryFromLocale('ua'), 'UA');
    expect(TransportReport.countryFromLocale('419'), '');
    expect(TransportReport.countryFromLocale(null), '');
  });

  test('падавшие пути — только за сутки и только на этой сети', () {
    final paths = <Object?>[
      <String, Object?>{'kind': 'direct'},
      <String, Object?>{'kind': 'ip'},
      <String, Object?>{'kind': 'proxy', 'host': 'x'},
    ];
    const now = 10 * 86400000;
    final memory = jsonEncode(<String, Object?>{
      'networks': <String, Object?>{
        'cell:a': <String, Object?>{
          'last_ok': 2,
          'last_ok_at_ms': now,
          'failed_at_ms': <String, Object?>{
            '0': now - 1000,
            '1': now - 2 * 86400000,
            '9': now,
          },
        },
        'wifi:b': <String, Object?>{
          'failed_at_ms': <String, Object?>{'2': now},
        },
      },
    });
    expect(
      TransportReport.failedKindsFromMemory(
        memoryJson: memory,
        networkId: 'cell:a',
        paths: paths,
        nowMs: now,
      ),
      <String>['direct'],
    );
    expect(
      TransportReport.failedKindsFromMemory(
        memoryJson: 'garbage',
        networkId: 'cell:a',
        paths: paths,
        nowMs: now,
      ),
      isEmpty,
    );
    expect(TransportReport.dayIndex(now + 5), 10);
  });
}
