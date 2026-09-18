// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/diagnostics/diag_log.dart';

/// 🔴 КЛЮЧ СШИВКИ КЛИЕНТА И РЕЛЕ. ФОРМАТ ОБЯЗАН СОВПАДАТЬ ДОСЛОВНО.
///
/// Реле обозначает устройство хешем (`log_fingerprint`,
/// `server/relay/src/main.rs:1399`), клиент — префиксом настоящего
/// идентификатора. Пространства имён разные, и, имея ОБА журнала, сшить их было
/// нельзя. Разбор сбоя звонка 15.08 из-за этого закончился ничем: серверные
/// строки не привязывались ни к одному устройству.
///
/// Значения ниже посчитаны независимо (python hashlib), а не сняты с этой же
/// реализации: снятый с себя эталон подтверждает только сам себя.
void main() {
  test('🔴 отпечаток совпадает с серверным до знака', () {
    // sha256("device-12345") = 21e8b3e1…, длина строки 12.
    // Тот же вектор закреплён в тесте реле log_fingerprint_is_stable_and_redacted.
    expect(DiagLog.relayRef('device-12345'), 'sha256:21e8b3e1:len=12');
  });

  test('🔴 идентификатор в отпечаток не просачивается', () {
    final ref = DiagLog.relayRef('device-12345');
    expect(ref.contains('device-12345'), isFalse);
    expect(ref.contains('12345'), isFalse);
  });

  test('пробелы обрезаются — иначе длина разойдётся с серверной', () {
    expect(DiagLog.relayRef('  device-12345  '), 'sha256:21e8b3e1:len=12');
  });

  test('пусто отдаёт «empty», как на сервере', () {
    expect(DiagLog.relayRef(''), 'empty');
    expect(DiagLog.relayRef(null), 'empty');
    expect(DiagLog.relayRef('   '), 'empty');
  });

  test('отпечаток устойчив — иначе сшивать нечем', () {
    expect(DiagLog.relayRef('abc'), DiagLog.relayRef('abc'));
    expect(DiagLog.relayRef('abc'), isNot(DiagLog.relayRef('abd')));
  });

  test('🔴 отпечаток НЕ вычёркивается фильтром релиза', () {
    // Фильтр `call_log.dart` стирает значение у полей, чьё имя кончается на
    // `id`. Ключ сшивки обязан пережить релиз, поэтому поле называется `ref`,
    // а не `device_id`, и значение не должно попадать под правило.
    final line = 'event=call.devices_ref self=${DiagLog.relayRef('dev-1')}';
    final redactor = RegExp(
      r'\b(sdp|candidate|nonce|signature|[A-Za-z_]*(?:id|Id|ID))=([^\s,;]+)',
      caseSensitive: false,
    );
    expect(
      line.replaceAllMapped(redactor, (m) => '${m.group(1)}=<redacted>'),
      line,
      reason: 'ключ сшивки не должен вычёркиваться в релизной сборке',
    );
  });
}
