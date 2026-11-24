// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Журнал нагрева проверочных сборок (24.11.2026): стекло включено по
// умолчанию на iPhone — замер нагрева при долгой работе.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/diagnostics/heat_log.dart';

void main() {
  test('🔴 в обычной сборке журнала нет', () {
    expect(kHeatLog, isFalse);
    HeatLog.start(); // ничего не делает
  });

  test('строка: все колонки заголовка, числа и пустые поля на месте', () {
    final row = heatLogRow(
      time: DateTime(2026, 11, 24, 10, 0, 0),
      uptimeMin: 12.25,
      life: 'resumed',
      probe: const {
        'thermal': 1,
        'battery': 0.83,
        'charging': false,
        'lowPower': false,
        'batteryTempC': 36.4,
        'brightness': 0.5,
      },
      cpuPct: '14.2',
      glassOn: true,
      glassEngine: true,
      glassQuality: 'balanced',
      frames: 120,
      rasterUs: List<int>.generate(100, (i) => (i + 1) * 200),
    );
    final cols = row.split(',');
    expect(cols.length, HeatLog.header.split(',').length);
    expect(cols[2], 'resumed');
    expect(cols[3], '1');
    expect(cols[4], '0.83');
    expect(cols[7], '36.4');
    expect(cols[8], '14.2');
    expect(cols[12], 'balanced');
    expect(cols[14], '18.0'); // p90 из 0,2…20 мс
    expect(cols[15], '17'); // дольше 16,7 мс: 16,8…20,0 — 17 кадров
  });

  test('пустая проба (iOS без температуры батареи) — пустые поля, не сбой', () {
    final row = heatLogRow(
      time: DateTime(2026),
      uptimeMin: 0,
      life: 'paused',
      probe: const {},
      cpuPct: '',
      glassOn: false,
      glassEngine: false,
      glassQuality: 'full',
      frames: 0,
      rasterUs: const [],
    );
    expect(row.split(',').length, HeatLog.header.split(',').length);
  });

  test('🔴 подключено: запуск, проба на iOS и Android, выгрузка из настроек', () {
    expect(File('lib/main.dart').readAsStringSync(), contains('HeatLog.start();'));
    expect(File('ios/Runner/AppDelegate.swift').readAsStringSync(),
        contains('attachHeatProbeChannel(messenger)'));
    expect(
      File('android/app/src/main/kotlin/com/secretly/secretly_app/MainActivity.kt')
          .readAsStringSync(),
      contains('"secretly/heat_probe"'),
    );
    expect(File('lib/ui/settings_screen.dart').readAsStringSync(),
        contains('HeatLog.logFile()'));
  });
}
