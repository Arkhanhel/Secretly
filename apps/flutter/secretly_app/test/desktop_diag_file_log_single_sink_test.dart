// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ЖУРНАЛ ПК: ОДНА ЗАПИСЬ НА СОБЫТИЕ И ОЧИСТКА НА КАЖДОЙ СТРОКЕ (30.09.2026).
//
// Событие `DiagLog` доходило до файла двумя путями: через `callLog` (там
// значения `…id=` скрываются) и через `DiagLog.sink` (там — нет). Каждое
// событие лежало в файле дважды, и одна из копий несла идентификаторы.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_log.dart';
import 'package:secretly_app/diagnostics/diag_log.dart';
import 'package:secretly_app/ui/desktop/services/desktop_diag_file_log.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sly_diag_single_');
    await DesktopDiagFileLog.resetForTest();
  });

  tearDown(() async {
    await DesktopDiagFileLog.resetForTest();
    await dir.delete(recursive: true);
  });

  String readLog() => File('${dir.path}/logs/diag.log').readAsStringSync();

  test(
    '🔴 событие DiagLog ложится в файл ОДИН раз и без идентификаторов',
    () async {
      await DesktopDiagFileLog.start(directoryForTest: dir);
      expect(DiagLog.sink, isNull, reason: 'второй приёмник не ставится');
      expect(callLogFileSink, isNotNull);

      DiagLog.event('filelog', 'single_sink', {
        'peer_id': 'abcdef0123456789',
        'convo': DiagLog.pfx('ABCD-EFGH-IJKL'),
        'marked': 3,
      });
      await DesktopDiagFileLog.settleForTest();

      final log = readLog();
      expect(
        'event=filelog.single_sink'.allMatches(log).length,
        1,
        reason: 'одно событие — одна строка',
      );
      expect(log, contains('peer_id=<redacted>'));
      expect(log, isNot(contains('abcdef0123456789')));
      expect(log, contains('convo=ABCDEFGH'));
      expect(log, contains('marked=3'));
    },
  );

  test('🔴 прямая запись тоже чистится и остаётся одной строкой', () async {
    await DesktopDiagFileLog.start(directoryForTest: dir);
    DesktopDiagFileLog.write(
      'event=x.y device_id=0f0f0f0f0f sdp=v=0 nonce=QUJD\nsecond line',
    );
    await DesktopDiagFileLog.settleForTest();

    final line = readLog()
        .split('\n')
        .firstWhere((l) => l.contains('event=x.y'));
    expect(line, contains('device_id=<redacted>'));
    expect(line, contains('sdp=<redacted>'));
    expect(line, contains('nonce=<redacted>'));
    expect(line, contains('second line'), reason: 'перевод строки — пробел');
    expect(line, isNot(contains('0f0f0f0f0f')));
  });

  test('очистка не трогает обычные поля', () {
    expect(
      DesktopDiagFileLog.redact('event=a.b convo=ABCDEFGH count=2'),
      'event=a.b convo=ABCDEFGH count=2',
    );
    expect(
      DesktopDiagFileLog.redact('msgId=12345 signature=zzz'),
      'msgId=<redacted> signature=<redacted>',
    );
  });
}
