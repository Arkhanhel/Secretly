// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 АВТОЗАПУСК И КРЕСТИК НА WINDOWS (28.09.2026).
//
// Автозапуск на ПК — условие доставки: не запущенное приложение не получает
// ничего. На macOS он был, на Windows переключателя не было вовсе. Крестик
// прятал окно в трей всегда — выключить это было нельзя.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_login_item_windows.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';

void main() {
  group('строка автозапуска', () {
    test('путь в кавычках и признак автозапуска', () {
      expect(
        windowsAutostartCommand(r'C:\Users\Я\AppData\Local\Programs\Secretly\Secretly.exe'),
        r'"C:\Users\Я\AppData\Local\Programs\Secretly\Secretly.exe" --autostart',
      );
    });

    test('«свёрнутым» — ещё и --minimized: его читает раннер', () {
      expect(
        windowsAutostartCommand(r'C:\S\Secretly.exe', minimized: true),
        r'"C:\S\Secretly.exe" --autostart --minimized',
      );
    });

    test('запись Run считается нашей, только если ведёт к этой программе', () {
      expect(
        windowsRunEntryPointsTo(r'"C:\S\SECRETLY.EXE" --autostart', r'C:\S\Secretly.exe'),
        isTrue,
      );
      expect(
        windowsRunEntryPointsTo(r'"D:\old\secretly_app.exe"', r'C:\S\Secretly.exe'),
        isFalse,
        reason: 'старая переносная копия — не наш автозапуск',
      );
      expect(windowsRunEntryPointsTo(null, r'C:\S\Secretly.exe'), isFalse);
    });

    test('выключено в «Диспетчере задач» — младший бит первого байта', () {
      expect(
        windowsStartupApprovedDisabled(Uint8List.fromList([2, 0, 0, 0])),
        isFalse,
      );
      expect(
        windowsStartupApprovedDisabled(Uint8List.fromList([3, 0, 0, 0])),
        isTrue,
      );
      expect(windowsStartupApprovedDisabled(null), isFalse);
    });
  });

  group('настройки по умолчанию — как у Telegram', () {
    setUp(DesktopUiPrefs.resetForTest);

    test('крестик прячет в трей, автозапуск — свёрнутым', () {
      expect(DesktopUiPrefs.closeToTray.value, isTrue);
      expect(DesktopUiPrefs.startMinimized.value, isTrue);
    });
  });

  group('🔴 подключено', () {
    test('служба автозапуска работает и на Windows', () {
      final src = File('lib/ui/desktop/services/desktop_login_item_service.dart')
          .readAsStringSync();
      expect(src, contains('Platform.isMacOS || Platform.isWindows'));
      expect(src, contains('windowsLoginItemSetEnabled('));
    });

    test('раннер не показывает окно при --minimized', () {
      final runner = File('windows/runner/flutter_window.cpp').readAsStringSync();
      expect(runner, contains('std::wcsstr(::GetCommandLineW(), L"--minimized")'));
      expect(runner, contains('if (!start_minimized) this->Show();'));
    });

    test('без значка в трее окно всё равно показывается', () {
      final main = File('lib/main_desktop.dart').readAsStringSync();
      final hidden = main.indexOf('if (startHidden) {\n      if (DesktopWindowActivity.trayReady)');
      expect(hidden, greaterThan(0));
      expect(main.indexOf('await _showMainWindow();', hidden), greaterThan(hidden));
    });

    test('крестик уважает «Закрывать в трей»', () {
      final app = File('lib/ui/desktop/app/desktop_production_app.dart')
          .readAsStringSync();
      final close = app.indexOf('void onWindowClose()');
      final body = app.substring(close, close + 1800);
      expect(body, contains('!DesktopUiPrefs.closeToTray.value'));
      expect(body, contains('await quitDesktopApp();'));
    });
  });
}
