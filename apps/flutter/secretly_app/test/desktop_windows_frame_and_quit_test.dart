// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Три замечания владельца по версии для Windows (26.09.2026):
//   1. «везде по бокам какая-то рамка вокруг окна кроме верхней части»;
//   2. «если закрыть приложение и открыть заново, внизу „соединение“ мигает
//      вместе с „подключением“»;
//   3. «чтобы приложение было в диспетчере задач как и телеграм, и при
//      закрытии процесс закрывался профессионально».

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/app/desktop_sync_status.dart';
import 'package:secretly_app/ui/desktop/services/desktop_window_activity.dart';
import 'package:secretly_app/ui/desktop/shell/sidebar.dart'
    show ConnectionStatus;

void main() {
  group('рамка окна', () {
    final runner = File('windows/runner/flutter_window.cpp').readAsStringSync();

    test('🔴 рамку считаем сами — ДО плагина', () {
      // Плагин отвечает на эти два сообщения по-своему, и его ответ как раз и
      // рисует полосу по краям. Порядок здесь и есть исправление.
      final ours = runner.indexOf('HandleFrameMessage(hwnd, message');
      final plugin = runner.indexOf('HandleTopLevelWindowProc');
      expect(ours, greaterThan(0));
      expect(plugin, greaterThan(0));
      expect(ours, lessThan(plugin));
    });

    test('🔴 клиентская область не ужимается с боков и снизу', () {
      // Ровно эти три строки плагина и давали рамку.
      expect(runner.contains('rgrc[0].right -= 8'), isFalse);
      expect(runner.contains('rgrc[0].bottom -= 8'), isFalse);
      expect(runner.contains('rgrc[0].left -= -8'), isFalse);
      expect(runner.contains('case WM_NCCALCSIZE'), isTrue);
    });

    test('края можно тянуть: углы и стороны считаются сами', () {
      for (final code in [
        'HTTOPLEFT',
        'HTTOPRIGHT',
        'HTBOTTOMLEFT',
        'HTBOTTOMRIGHT',
        'HTLEFT',
        'HTRIGHT',
        'HTTOP',
        'HTBOTTOM',
      ]) {
        expect(runner.contains(code), isTrue, reason: code);
      }
      expect(runner.contains('case WM_NCHITTEST'), isTrue);
    });

    test('развёрнутое окно кладётся в рабочую часть экрана — края не срежет',
        () {
      expect(runner.contains('ClampToWorkArea'), isTrue);
      expect(runner.contains('IsZoomed'), isTrue);
    });

    test('полноэкранный режим определяется по стилю окна, а не по размеру', () {
      // Окно, растянутое человеком по размеру монитора, края терять не должно.
      expect(runner.contains('WS_THICKFRAME'), isTrue);
      expect(runner.contains('IsResizableWindow'), isTrue);
    });

    test('🔴 верхнюю строку Windows 10 не трогаем — она и не мешала', () {
      expect(runner.contains('IsWindows11OrLater()'), isTrue);
      expect(runner.contains('params->rgrc[0].top += 1'), isTrue);
    });
  });

  group('имя процесса в «Диспетчере задач»', () {
    final rc = File('windows/runner/Runner.rc').readAsStringSync();
    final cmake = File('windows/CMakeLists.txt').readAsStringSync();
    final iss = File('windows/installer/secretly.iss').readAsStringSync();

    test('🔴 процесс называется Secretly.exe, а не secretly_app.exe', () {
      expect(cmake.contains('set(BINARY_NAME "Secretly")'), isTrue);
      expect(rc.contains('"OriginalFilename", "Secretly.exe"'), isTrue);
      expect(rc.contains('"InternalName", "Secretly"'), isTrue);
      expect(rc.contains('secretly_app'), isFalse);
    });

    test('установщик ставит и запускает тот же файл', () {
      expect(iss.contains('#define AppExe "Secretly.exe"'), isTrue);
      // Старое имя — стереть при обновлении поверх, иначе в папке останутся
      // два исполняемых файла и человек запустит не тот.
      expect(iss.contains(r'Type: files; Name: "{app}\secretly_app.exe"'),
          isTrue);
    });

    test('подпись и название совпадают с тем, что показывает список задач', () {
      expect(rc.contains('"FileDescription", "Secretly"'), isTrue);
      expect(rc.contains('"ProductName", "Secretly"'), isTrue);
    });
  });

  group('выход из приложения', () {
    final runner = File('windows/runner/flutter_window.cpp').readAsStringSync();

    test('🔴 выключение компьютера не ждёт нас', () {
      expect(runner.contains('WM_ENDSESSION'), isTrue);
      expect(runner.contains('ExitProcess(0)'), isTrue);
    });

    test('🔴 процесс уходит наверняка, а не «как получится»', () {
      final main = File('windows/runner/main.cpp').readAsStringSync();
      expect(main.contains('ExitProcess(EXIT_SUCCESS)'), isTrue);
    });

    test('панель задач, ярлык и уведомления — одно имя приложения', () {
      final main = File('windows/runner/main.cpp').readAsStringSync();
      final iss = File('windows/installer/secretly.iss').readAsStringSync();
      final notif =
          File('lib/ui/desktop/services/desktop_notification_service.dart')
              .readAsStringSync();
      expect(main.contains('SetCurrentProcessExplicitAppUserModelID'), isTrue);
      expect(main.contains('L"Secretly"'), isTrue);
      expect(iss.contains('AppUserModelID: "Secretly"'), isTrue);
      expect(notif.contains("appName: 'Secretly'"), isTrue);
      // Имя должно стоять до создания окна: панель задач читает его один раз.
      expect(
        main.indexOf('SetCurrentProcessExplicitAppUserModelID'),
        lessThan(main.indexOf('window.Create(')),
      );
    });

    setUp(debugResetDesktopQuit);
    tearDown(debugResetDesktopQuit);

    test('обычный путь: окно разрушено, процесс не добивается', () {
      fakeAsync((async) {
        var destroyed = 0;
        var exited = 0;
        unawaited(
          quitDesktopApp(
            destroy: () async => destroyed++,
            exitProcess: () => exited++,
          ),
        );
        async.elapse(const Duration(milliseconds: 10));
        expect(destroyed, 1);
        expect(exited, 0);
        // Подстраховка не должна убивать процесс уже после нормального выхода.
        async.elapse(const Duration(seconds: 10));
        expect(exited, 0);
      });
    });

    test('🔴 окно не разрушилось — процесс всё равно уходит', () {
      fakeAsync((async) {
        var exited = 0;
        unawaited(
          quitDesktopApp(
            destroy: () => Completer<void>().future, // ответа не будет никогда
            exitProcess: () => exited++,
          ),
        );
        async.elapse(const Duration(seconds: 2));
        expect(exited, 0, reason: 'слишком рано — окно могло ещё закрываться');
        async.elapse(const Duration(seconds: 2));
        expect(exited, 1);
      });
    });

    test('ошибка при разрушении окна — уходим сразу, не ждём срока', () {
      fakeAsync((async) {
        var exited = 0;
        unawaited(
          quitDesktopApp(
            destroy: () async => throw StateError('нет платформенной стороны'),
            exitProcess: () => exited++,
          ),
        );
        async.elapse(const Duration(milliseconds: 10));
        expect(exited, 1);
        async.elapse(const Duration(seconds: 10));
        expect(exited, 1, reason: 'подстраховка снята');
      });
    });

    test('двойное нажатие «Выйти» не заводит второй выход', () {
      fakeAsync((async) {
        var destroyed = 0;
        unawaited(
          quitDesktopApp(
            destroy: () async => destroyed++,
            exitProcess: () {},
          ),
        );
        unawaited(
          quitDesktopApp(
            destroy: () async => destroyed++,
            exitProcess: () {},
          ),
        );
        async.elapse(const Duration(milliseconds: 10));
        expect(destroyed, 1);
      });
    });

    test('🔴 без значка в трее крестик обязан закрывать приложение', () {
      // Прятать окно можно только туда, откуда его достанут.
      final app = File('lib/ui/desktop/app/desktop_production_app.dart')
          .readAsStringSync();
      final i = app.indexOf('void onWindowClose()');
      expect(i, greaterThan(0));
      final body = app.substring(i, i + 1400);
      expect(body.contains('DesktopWindowActivity.trayReady'), isTrue);
      expect(body.contains('windowManager.isVisible()'), isTrue);
      expect(body.contains('quitDesktopApp()'), isTrue);
      final main = File('lib/main_desktop.dart').readAsStringSync();
      expect(main.contains('DesktopWindowActivity.trayReady = true'), isTrue);
      expect(main.contains('DesktopWindowActivity.trayReady = false'), isTrue);
    });
  });

  group('состояние связи внизу окна', () {
    late StreamController<bool> relay;
    late DesktopSyncStatusController status;

    void start({bool online = false}) {
      relay = StreamController<bool>.broadcast();
      status = DesktopSyncStatusController.fromRelay(
        changes: relay.stream,
        online: online,
      );
    }

    tearDown(() {
      status.dispose();
      unawaited(relay.close());
    });

    test('🔴 короткий обрыв не показывается вовсе', () {
      fakeAsync((async) {
        start();
        relay.add(true);
        async.elapse(const Duration(seconds: 4));
        expect(status.value.phase, DesktopSyncPhase.online);

        // Так выглядит повторный заход: relay.connect() начинается с
        // disconnect(), и пара «оборвалось / подключилось» умещается в
        // доли секунды. Показывать её человеку нечего.
        final seen = <DesktopSyncPhase>[];
        status.addListener(() => seen.add(status.value.phase));
        relay.add(false);
        async.elapse(const Duration(milliseconds: 300));
        relay.add(true);
        async.elapse(const Duration(seconds: 4));

        expect(
          seen.contains(DesktopSyncPhase.reconnecting),
          isFalse,
          reason: 'мигание: об обрыве сообщили, хотя он уже кончился',
        );
        expect(status.value.phase, DesktopSyncPhase.online);
      });
    });

    test('настоящий обрыв показывается — и переходит в «нет соединения»', () {
      fakeAsync((async) {
        start();
        relay.add(true);
        async.elapse(const Duration(seconds: 4));
        relay.add(false);
        async.elapse(const Duration(seconds: 1));
        expect(status.value.phase, DesktopSyncPhase.online,
            reason: 'выдержка ещё идёт');
        async.elapse(const Duration(seconds: 1));
        expect(status.value.phase, DesktopSyncPhase.reconnecting);
        async.elapse(const Duration(seconds: 30));
        expect(status.value.phase, DesktopSyncPhase.offline);
      });
    });

    test('череда неудачных попыток не отодвигает «нет соединения»', () {
      fakeAsync((async) {
        start();
        relay.add(true);
        async.elapse(const Duration(seconds: 4));
        relay.add(false);
        async.elapse(const Duration(seconds: 3));
        expect(status.value.phase, DesktopSyncPhase.reconnecting);
        // Каждая неудачная попытка снова сообщает «оборвалось». Если бы срок
        // отсчитывался заново, «Нет соединения» не наступило бы никогда.
        for (var i = 0; i < 15; i++) {
          relay.add(false);
          async.elapse(const Duration(seconds: 2));
        }
        expect(status.value.phase, DesktopSyncPhase.offline);
      });
    });

    test('холодный запуск: «Подключение…» сразу, без выдержки', () {
      fakeAsync((async) {
        start();
        expect(status.value.phase, DesktopSyncPhase.connecting);
        relay.add(false);
        async.elapse(const Duration(milliseconds: 10));
        expect(status.value.phase, DesktopSyncPhase.connecting,
            reason: 'на запуске «Переподключение…» было бы ложью');
      });
    });

    test('связь вернулась — «Нет соединения» сменяется без задержки', () {
      fakeAsync((async) {
        start();
        relay.add(true);
        async.elapse(const Duration(seconds: 4));
        relay.add(false);
        async.elapse(const Duration(seconds: 30));
        expect(status.value.phase, DesktopSyncPhase.offline);
        relay.add(true);
        async.elapse(const Duration(milliseconds: 10));
        expect(status.value.phase, DesktopSyncPhase.syncing);
      });
    });

    test('🔴 точка на портрете и пилюля берут одно и то же состояние', () {
      fakeAsync((async) {
        start();
        expect(status.connection, ConnectionStatus.connecting);
        relay.add(true);
        async.elapse(const Duration(milliseconds: 10));
        expect(status.connection, ConnectionStatus.connected,
            reason: 'пилюля уже «Синхронизация…» — точка не должна спорить');
        async.elapse(const Duration(seconds: 4));
        expect(status.connection, ConnectionStatus.connected);
        relay.add(false);
        async.elapse(const Duration(seconds: 30));
        expect(status.connection, ConnectionStatus.offline);
      });
    });


  });

  test('корень берёт состояние точки из выдержанного, а не из сокета', () {
    final app = File('lib/ui/desktop/app/desktop_production_app.dart')
        .readAsStringSync();
    // Прямая подписка на события сокета и была вторым, спорящим источником:
    // пилюля ждала выдержку, точка — нет. Сам поток в файле остался (по нему
    // идёт догон истории), а вот слушать его ради состояния точки нельзя.
    expect(
      app.contains('relayConnectionChanges.listen'),
      isFalse,
      reason: 'точка снова считает состояние по событиям сокета',
    );
    expect(app.contains('sync.connection'), isTrue);
    expect(app.contains('_syncStatus?.connection'), isTrue);
  });
}
