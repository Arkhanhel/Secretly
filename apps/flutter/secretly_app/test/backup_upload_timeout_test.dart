// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/transport/keys_client.dart';

// Полевой случай 14.08.2026: «Копия не создаётся», TimeoutException after
// 0:00:08, последняя удачная — 7 августа. Копия уходила через общий метод
// сервера ключей и наследовала его предел в 8 секунд, выбранный для мелких
// операций с ключами. Сервер при этом готов принять 200 МБ.
//
// Это не сбой, а АРИФМЕТИКА: копия растёт вместе с перепиской, предел стоял на
// месте. Поэтому «сначала работает, потом перестаёт у всех» — каждый в свой день.
void main() {
  test('🔴 мелкой копии дают не меньше пола', () {
    // Иначе на плохой связи упрётся даже крошечная копия.
    expect(
      KeysClient.backupUploadTimeoutFor(1024).inSeconds,
      greaterThanOrEqualTo(30),
    );
    expect(KeysClient.backupUploadTimeoutFor(0).inSeconds, 30);
  });

  test('🔴 предел растёт вместе с размером', () {
    // Суть правки: предел обязан следовать за копией, иначе завтра повторится
    // ровно то же самое.
    final small = KeysClient.backupUploadTimeoutFor(1 * 1024 * 1024);
    final large = KeysClient.backupUploadTimeoutFor(20 * 1024 * 1024);
    expect(large, greaterThan(small));
    // 20 МБ на скромных 250 КБ/с — около 80 с плюс запас.
    expect(large.inSeconds, greaterThan(70));
  });

  test('🔴 есть потолок: зависшая сеть не держит приложение вечно', () {
    expect(
      KeysClient.backupUploadTimeoutFor(500 * 1024 * 1024).inMinutes,
      10,
    );
  });

  test('восьми секунд не остаётся ни при каком размере', () {
    for (final bytes in [0, 1, 1024, 1024 * 1024, 100 * 1024 * 1024]) {
      expect(
        KeysClient.backupUploadTimeoutFor(bytes).inSeconds,
        greaterThan(8),
        reason: 'именно 8 с и убивали копию в поле',
      );
    }
  });
}
