// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 НЕОБРАБОТАННЫЕ ОШИБКИ ПК — В ЖУРНАЛ, С ПЕРВОЙ СТРОКИ (30.09.2026).
//
// В журнал ПК попадали только ошибки сборки виджетов, и только после того,
// как приложение открыло файл журнала. Ошибка таймера или Future без
// обработчика уходила в консоль, которой у выпускной сборки нет.

import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_crash_log.dart';
import 'package:secretly_app/ui/desktop/services/desktop_diag_file_log.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sly_crash_');
    await DesktopDiagFileLog.resetForTest();
    DesktopCrashLog.debugReset();
  });

  tearDown(() async {
    await DesktopDiagFileLog.resetForTest();
    DesktopCrashLog.debugReset();
    await dir.delete(recursive: true);
  });

  String readLog() => File('${dir.path}/logs/diag.log').readAsStringSync();

  group('место падения', () {
    test('свои кадры — первыми и без имени пакета; пути диска не берутся', () {
      final stack = StackTrace.fromString(
        '#0      _rootRun (dart:async/zone.dart:1525:13)\n'
        '#1      Foo.bar (package:flutter/src/widgets/framework.dart:100:7)\n'
        '#2      Baz.qux (file:///Users/someone/secret/y.dart:3:4)\n'
        '#3      A.b (package:secretly_app/app/app_controller.dart:42:7)\n'
        '#4      C.d (package:secretly_app/ui/desktop/x.dart:9)\n',
      );
      final at = DesktopCrashLog.stackTop(stack);
      expect(at, 'app/app_controller.dart:42<ui/desktop/x.dart:9');
      expect(at, isNot(contains('Users')));
    });

    test('своих кадров нет — первые чужие пакеты; стека нет — «-»', () {
      final stack = StackTrace.fromString(
        '#0      Foo.bar (package:flutter/src/widgets/framework.dart:100:7)\n',
      );
      expect(
        DesktopCrashLog.stackTop(stack),
        'flutter/src/widgets/framework.dart:100',
      );
      expect(DesktopCrashLog.stackTop(null), '-');
      expect(DesktopCrashLog.stackTop(StackTrace.fromString('')), '-');
    });
  });

  test(
    '🔴 PlatformDispatcher.onError: тип и место — в журнал, текста ошибки нет; '
    'прежний обработчик зовётся',
    () async {
      final dispatcher = PlatformDispatcher.instance;
      final saved = dispatcher.onError;
      addTearDown(() => dispatcher.onError = saved);
      final seen = <Object>[];
      dispatcher.onError = (error, stack) {
        seen.add(error);
        return true;
      };

      await DesktopDiagFileLog.start(directoryForTest: dir);
      DesktopCrashLog.install();
      DesktopCrashLog.install(); // второй вызов не встаёт в цепочку ещё раз
      final handled = dispatcher.onError!(
        StateError('секретный текст сообщения'),
        StackTrace.fromString(
          '#0      A.b (package:secretly_app/app/app_controller.dart:42:7)',
        ),
      );
      await DesktopDiagFileLog.settleForTest();

      expect(handled, isTrue, reason: 'ответ прежнего обработчика');
      expect(seen, hasLength(1));
      final log = readLog();
      expect('event=crash.platform'.allMatches(log).length, 1);
      expect(log, contains('type=StateError'));
      expect(log, contains('at=app/app_controller.dart:42'));
      expect(log, isNot(contains('секретный')));
    },
  );

  test('без прежнего обработчика ошибка остаётся необработанной', () {
    final dispatcher = PlatformDispatcher.instance;
    final saved = dispatcher.onError;
    addTearDown(() => dispatcher.onError = saved);
    dispatcher.onError = null;
    DesktopCrashLog.install();
    expect(
      dispatcher.onError!(StateError('x'), StackTrace.empty),
      isFalse,
      reason: 'движок сам напечатает её, как и раньше',
    );
  });

  test('🔴 строки до открытия файла не теряются и ложатся первыми', () async {
    DesktopDiagFileLog.captureEarly();
    DesktopCrashLog.record(
      'zone',
      ArgumentError('x'),
      StackTrace.fromString(
        '#0      f (package:secretly_app/main_desktop.dart:9)',
      ),
    );
    await DesktopDiagFileLog.start(directoryForTest: dir);
    await DesktopDiagFileLog.settleForTest();

    final log = readLog();
    final early = log.indexOf('event=crash.zone');
    final started = log.indexOf('event=diag.file_log_started');
    expect(early, greaterThanOrEqualTo(0));
    expect(early, lessThan(started));
    expect(log, contains('at=main_desktop.dart:9'));
  });

  test('main_desktop: журнал ставится первым, файл открывается за замком', () {
    final src = File('lib/main_desktop.dart').readAsStringSync();
    final init = src.indexOf('WidgetsFlutterBinding.ensureInitialized();');
    final early = src.indexOf('DesktopDiagFileLog.captureEarly();');
    final crash = src.indexOf('DesktopCrashLog.install();');
    final guard = src.indexOf('  _installDesktopErrorGuard();');
    expect(init, greaterThan(0));
    expect(early, greaterThan(init));
    expect(crash, greaterThan(early));
    expect(guard, greaterThan(crash));

    final exitAt = src.indexOf('exit(0);');
    final start = src.indexOf('await DesktopDiagFileLog.start();');
    final window = src.indexOf('await windowManager.ensureInitialized();');
    expect(start, greaterThan(exitAt), reason: 'второй экземпляр не пишет');
    expect(window, greaterThan(start));

    expect(src, contains("'at': DesktopCrashLog.stackTop(details.stack)"));
    expect(
      src.contains('runZonedGuarded'),
      isFalse,
      reason: 'своя зона забирала бы ошибки раньше PlatformDispatcher',
    );
  });
}
