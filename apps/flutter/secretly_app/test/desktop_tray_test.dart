// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 ЗНАЧОК В ТРЕЕ WINDOWS (28.09.2026, владелец: «нет мини-иконки справа
// для фоновой работы»).
//
// Цепочка была такая: значок ставился из PNG → `tray_manager` на Windows
// читает только ICO → значок пустой, но плагин отвечает «успех» → приложение
// считает трей рабочим и прячет окно по крестику → повторный запуск
// Secretly.exe ничего не показывал. Приложение оставалось живым и
// недоступным. Тесты ниже стерегут каждое звено.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support_public_tree.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/services/desktop_notification_service.dart';
import 'package:secretly_app/ui/desktop/services/desktop_tray_service.dart';
import 'package:tray_manager/tray_manager.dart';

final _ru = lookupAppLocalizations(const Locale('ru'));

List<MenuItem> _flat(Menu menu) => [
      for (final item in menu.items ?? const <MenuItem>[]) ...[
        item,
        if (item.submenu != null) ..._flat(item.submenu!),
      ],
    ];

void main() {
  group('файлы значков', () {
    test('на Windows — настоящие ICO, на macOS — шаблон PNG', () {
      for (final v in DesktopTrayIconVariant.values) {
        final asset = desktopTrayIconAsset(TargetPlatform.windows, v);
        expect(asset, endsWith('.ico'), reason: '$v');
        expect(desktopTrayIconFileLooksValid(asset), isTrue,
            reason: '$asset — Windows строит значок трея только из ICO');
      }
      final mac = desktopTrayIconAsset(
        TargetPlatform.macOS,
        DesktopTrayIconVariant.normal,
      );
      expect(File(mac).existsSync(), isTrue);
      expect(mac, endsWith('.png'));
    }, skip: skipInPublicTree('значков ICO'));

    test('в ICO есть размеры маленького значка 16…32 (100…200 %)', () {
      final bytes = File('assets/desktop/tray/tray.ico').readAsBytesSync();
      final count = bytes[4] | (bytes[5] << 8);
      final sizes = [
        for (var i = 0; i < count; i++)
          bytes[6 + i * 16] == 0 ? 256 : bytes[6 + i * 16],
      ];
      expect(sizes, containsAll(<int>[16, 20, 24, 32]));
    }, skip: skipInPublicTree('значков ICO'));

    test('PNG и пустое место — не значок: трей не считается готовым', () {
      expect(
        desktopTrayIconFileLooksValid('assets/app_ui/icons/app_icon.png'),
        isFalse,
        reason: 'ровно тот PNG, из-за которого значок был пустым',
      );
      expect(desktopTrayIconFileLooksValid('assets/нет/такого.ico'), isFalse);
    });

    test('папка значков объявлена в pubspec — иначе в сборку не попадёт', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/desktop/tray/'));
    });

    test('путь — тот, который склеит сам tray_manager', () {
      final path = desktopTrayIconFilePath(
        'assets/desktop/tray/tray.ico',
        executable: r'C:\Program Files\Secretly\Secretly.exe'
            .replaceAll(r'\', '/'),
      );
      expect(path, endsWith('data/flutter_assets/assets/desktop/tray/tray.ico'));
    });

    test('🔴 без файла значка в сборке трей НЕ готов — крестик выходит',
        () async {
      // В тестовом прогоне рядом с исполняемым файлом нет data/flutter_assets
      // — ровно положение сборки, в которую значок не попал.
      final svc = DesktopTrayService.forTest(TargetPlatform.windows);
      final ready = await svc.install(
        actions: DesktopTrayActions(
          show: () async {},
          hide: () async {},
          quit: () async {},
        ),
        l10n: _ru,
      );
      expect(ready, isFalse);
    });
  });

  group('вид значка', () {
    test('без звука важнее непрочитанного', () {
      expect(desktopTrayIconVariantFor(unread: 0, muted: false),
          DesktopTrayIconVariant.normal);
      expect(desktopTrayIconVariantFor(unread: 3, muted: false),
          DesktopTrayIconVariant.unread);
      expect(desktopTrayIconVariantFor(unread: 3, muted: true),
          DesktopTrayIconVariant.muted);
    });
  });

  group('меню', () {
    test('на языке приложения: открыть, непрочитанные, без звука, выйти', () {
      final menu = buildDesktopTrayMenu(l10n: _ru, unread: 5, muted: false);
      final labels = _flat(menu).map((i) => i.label).whereType<String>();
      expect(labels, containsAll(<String>[
        'Открыть Secretly',
        'Непрочитанных: 5',
        'Без звука',
        'На 1 час',
        'На 8 часов',
        'Пока не включу',
        'Выйти из Secretly',
      ]));
      final unread = _flat(menu)
          .firstWhere((i) => i.key == DesktopTrayMenuKeys.unread);
      expect(unread.disabled, isTrue, reason: 'строка-сводка, не кнопка');
    });

    test('без звука — показывает срок и «Включить уведомления»', () {
      final menu = buildDesktopTrayMenu(
        l10n: _ru,
        unread: 0,
        muted: true,
        mutedUntilLabel: '14:30',
      );
      final labels = _flat(menu).map((i) => i.label).whereType<String>();
      expect(labels, contains('Без звука до 14:30'));
      expect(labels, contains('Включить уведомления'));
      expect(labels, isNot(contains('На 1 час')));
      expect(labels, isNot(contains('Непрочитанных: 0')));
    });

    test('в меню нет зашитого русского — только переводы', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final labels = _flat(buildDesktopTrayMenu(l10n: en, unread: 2, muted: false))
          .map((i) => i.label)
          .whereType<String>();
      expect(labels, containsAll(<String>['Open Secretly', 'Quit Secretly']));
    });
  });

  group('нажатия', () {
    late List<String> calls;
    late bool front;
    late DesktopTrayService svc;

    setUp(() {
      calls = <String>[];
      front = false;
      svc = DesktopTrayService.forTest(TargetPlatform.windows)
        ..bind(DesktopTrayActions(
          show: () async => calls.add('show'),
          hide: () async => calls.add('hide'),
          quit: () async => calls.add('quit'),
          isWindowInFront: () => front,
          mute: (d) async => calls.add('mute:${d?.inHours ?? 'forever'}'),
          unmute: () async => calls.add('unmute'),
        ));
    });

    test('Windows: окно не впереди — нажатие по значку его показывает',
        () async {
      await svc.handlePrimaryClick();
      expect(calls, ['show']);
    });

    test('Windows: окно впереди — нажатие прячет, как у Telegram', () async {
      front = true;
      await svc.handlePrimaryClick();
      expect(calls, ['hide']);
    });

    test('пункты меню ведут куда обещают', () async {
      for (final key in [
        DesktopTrayMenuKeys.open,
        DesktopTrayMenuKeys.muteHour,
        DesktopTrayMenuKeys.muteEightHours,
        DesktopTrayMenuKeys.muteForever,
        DesktopTrayMenuKeys.unmute,
        DesktopTrayMenuKeys.quit,
      ]) {
        await svc.handleMenuKey(key);
      }
      expect(calls, [
        'show',
        'mute:1',
        'mute:8',
        'mute:forever',
        'unmute',
        'quit',
      ]);
    });
  });

  group('«Не беспокоить» на срок', () {
    test('насовсем — молчим всегда', () {
      expect(
        desktopDoNotDisturbActive(forever: true, untilMs: 0, nowMs: 1),
        isTrue,
      );
    });

    test('на час — молчим до срока и не дольше', () {
      const until = 1000000;
      expect(
        desktopDoNotDisturbActive(forever: false, untilMs: until, nowMs: 999),
        isTrue,
      );
      expect(
        desktopDoNotDisturbActive(
          forever: false,
          untilMs: until,
          nowMs: until,
        ),
        isFalse,
        reason: '«на час» не должно переживать этот час',
      );
    });
  });

  group('🔴 повторный запуск выводит окно (раннер Windows)', () {
    final main = File('windows/runner/main.cpp').readAsStringSync();
    final window = File('windows/runner/flutter_window.cpp').readAsStringSync();
    final single = File('windows/runner/single_instance.cpp').readAsStringSync();
    final cmake = File('windows/runner/CMakeLists.txt').readAsStringSync();

    test('проверка — до запуска Flutter', () {
      final handOff = main.indexOf('HandOffToRunningInstance()');
      final project = main.indexOf('flutter::DartProject project');
      expect(handOff, greaterThan(0));
      expect(handOff, lessThan(project),
          reason: 'второй движок не должен даже подниматься');
    });

    test('окно ищется по нашей метке, а не по общему классу Flutter', () {
      expect(single, contains('GetPropW(hwnd, kSecretlyMainWindowProp)'));
      expect(single, contains('AllowSetForegroundWindow'));
      expect(window, contains('SetPropW(GetHandle(), kSecretlyMainWindowProp'));
    });

    test('сигнал «покажись» разбирается раньше плагинов', () {
      final handled = window.indexOf('message == SecretlyShowWindowMessage()');
      final frame = window.indexOf('case WM_NCCALCSIZE');
      expect(handled, greaterThan(0));
      expect(handled, lessThan(frame));
      expect(window, contains('SetForegroundWindow(hwnd)'));
    });

    test('модуль входит в сборку', () {
      expect(cmake, contains('"single_instance.cpp"'));
    });
  });

  test('🔴 запуск ставит трей службой, а не PNG', () {
    final src = File('lib/main_desktop.dart').readAsStringSync();
    expect(src, isNot(contains("setIcon('assets/app_ui/icons/app_icon.png')")));
    expect(src, contains('DesktopTrayService.instance.install('));
    expect(src, contains('DesktopWindowActivity.trayReady ='));
  });

  test('сдвиг окна больше не отменяет обновление значка трея', () {
    final src = File('lib/ui/desktop/app/desktop_production_app.dart')
        .readAsStringSync();
    final save = src.indexOf('void _saveWindowGeometryDebounced()');
    final body = src.substring(save, src.indexOf('}', save + 200));
    expect(body, isNot(contains('_trayDebounce?.cancel()')));
  });
}
