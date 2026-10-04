// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ЖУРНАЛ ЗВОНКОВ ПК (28.09.2026).
//
// На ПК канала `secretly/log` нет: события звонков падали в запасной `print`
// и не сохранялись нигде. Обрывы «с ошибкой связи» на Windows разбирать было
// не по чему — только по журналам сервера, где не видно, ЧТО решил клиент.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/calls/call_log.dart';
import 'package:secretly_app/ui/desktop/services/desktop_diag_file_log.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sly_diag_');
  });

  tearDown(() async {
    await DesktopDiagFileLog.resetForTest();
    await dir.delete(recursive: true);
  });

  test('событие звонка попадает в файл журнала ПК', () async {
    await DesktopDiagFileLog.start(directoryForTest: dir);
    callOpLog(
      'CallManager',
      'signal_from_foreign_device_ignored',
      fields: <String, Object?>{'action': 'decline'},
    );
    await DesktopDiagFileLog.settleForTest();
    final text = File('${dir.path}/logs/diag.log').readAsStringSync();
    expect(text, contains('call [CallManager]'));
    expect(text, contains('signal_from_foreign_device_ignored'));
  });

  test('хвост журнала — для письма в поддержку', () async {
    await DesktopDiagFileLog.start(directoryForTest: dir);
    callOpLog('WebRTC', 'media_established');
    final bytes = await DesktopDiagFileLog.recentBytes(maxBytes: 4096);
    expect(bytes, isNotNull);
    expect(utf8.decode(bytes!), contains('media_established'));
    final small = await DesktopDiagFileLog.recentBytes(maxBytes: 16);
    expect(small!.length, 16, reason: 'берём конец, не больше предела');
  });

  test('после остановки журнала приёмник снят; у телефона его нет', () async {
    expect(callLogFileSink, isNull);
    await DesktopDiagFileLog.start(directoryForTest: dir);
    expect(callLogFileSink, isNotNull);
    await DesktopDiagFileLog.stop();
    expect(callLogFileSink, isNull);
  });

  test('в форме поддержки есть «Приложить журнал»', () {
    final src = File('lib/ui/desktop/workspace/settings_workspace.dart')
        .readAsStringSync();
    expect(src, contains('label: l10n.desktopSupportAttachLog'));
    expect(src, contains('DesktopDiagFileLog.recentBytes()'));
  });
}
