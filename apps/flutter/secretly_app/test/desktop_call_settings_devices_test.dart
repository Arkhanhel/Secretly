// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// «Настройки → Звонки», устройства: три дефекта из ТЗ §1.4 (30.09.2026).
//
//  1. Безымянная камера в меню созвона называлась по-русски на любом языке:
//     «Камера» и «Микрофон» были зашиты в общем с телефоном файле.
//  2. Список устройств не обновлялся, когда устройство подключали или
//     отключали, пока открыт раздел.
//  3. «Как в системе» во время созвона ничего не меняло: пустой выбор до
//     камеры не доходил.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/rooms/room_call_media_controller.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_call_devices.dart';
import 'package:secretly_app/ui/desktop/services/desktop_device_watch.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/workspace/media_devices_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

MediaDeviceInfo cam(String id, String label) =>
    MediaDeviceInfo(deviceId: id, label: label, kind: 'videoinput');
MediaDeviceInfo mic(String id, String label) =>
    MediaDeviceInfo(deviceId: id, label: label, kind: 'audioinput');
MediaDeviceInfo out(String id, String label) =>
    MediaDeviceInfo(deviceId: id, label: label, kind: 'audiooutput');

void main() {
  group('безымянные устройства созвона', () {
    test('🔴 телефон не ставит слов — у него всё как было', () {
      // Файл общий: мобильный экран созвона этих слов не задаёт, значит
      // умолчание обязано остаться прежним строка в строку.
      expect(RoomCallUnnamedDeviceLabels.camera, 'Камера');
      expect(RoomCallUnnamedDeviceLabels.microphone, 'Микрофон');
    });

    test('в движке созвона больше нет зашитых слов', () {
      final src = File(
        'lib/rooms/room_call_media_controller.dart',
      ).readAsStringSync();
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      // Единственное место со словами — умолчания держателя.
      expect("'Камера'".allMatches(code).length, 1);
      expect("'Микрофон'".allMatches(code).length, 1);
      expect(code.contains('RoomCallUnnamedDeviceLabels.camera'), isTrue);
      expect(code.contains('RoomCallUnnamedDeviceLabels.microphone'), isTrue);
    });

    test('окно созвона ПК ставит слова из переводов до списка камер', () {
      final win = File(
        'lib/ui/desktop/calls/room_call_window.dart',
      ).readAsStringSync();
      final i = win.indexOf('void didChangeDependencies()');
      expect(i, greaterThan(0));
      final body = win.substring(i, i + 900);
      expect(
        body.contains(
          'RoomCallUnnamedDeviceLabels.camera = _l10n.desktopDevicesCamera;',
        ),
        isTrue,
      );
      expect(
        body.contains(
          'RoomCallUnnamedDeviceLabels.microphone = '
          '_l10n.desktopDevicesMicrophone;',
        ),
        isTrue,
      );
    });
  });

  group('«Как в системе» для камеры — это конкретная камера', () {
    final devices = <MediaDeviceInfo>[
      mic('m1', 'Микрофон (USB)'),
      cam('c-built-in', 'FaceTime HD Camera'),
      cam('c-usb', 'Logitech C920'),
    ];

    test('без выбора — та, что движок открывает сам: первая в списке', () {
      expect(
        resolveDesktopCamera(devices: devices, preferredId: ''),
        'c-built-in',
      );
    });

    test('выбранная подключена — она', () {
      expect(
        resolveDesktopCamera(devices: devices, preferredId: 'c-usb'),
        'c-usb',
      );
    });

    test('выбранную отключили — системная, а не пустота', () {
      expect(
        resolveDesktopCamera(devices: devices, preferredId: 'c-gone'),
        'c-built-in',
      );
    });

    test('камер нет — ничего не переключаем', () {
      expect(
        resolveDesktopCamera(devices: [mic('m1', 'Mic')], preferredId: ''),
        isNull,
      );
    });

    test('🔴 пустой выбор доходит до созвона', () {
      final pane = File(
        'lib/ui/desktop/workspace/media_devices_pane.dart',
      ).readAsStringSync();
      final i = pane.indexOf('Future<void> _pickCamera(String id) async {');
      final body = pane.substring(i, i + 1200);
      // Было: `if (id.isNotEmpty) … selectVideoInput(id)` — «Как в системе»
      // до созвона не доходило вовсе.
      expect(body.contains('if (id.isNotEmpty)'), isFalse);
      expect(body.contains('desktopCameraTarget('), isTrue);
      // Через сторожа: выключенную камеру выбор не включает (30.09.2026).
      expect(
        body.contains('DesktopRoomCallMediaGuard.chooseCamera(media, target)'),
        isTrue,
      );
      expect(body.contains('media.selectVideoInput('), isFalse);
    });
  });

  group('отпечаток списка устройств', () {
    test('подключили, отключили, переименовали — отпечаток другой', () {
      final base = desktopDeviceSignature([mic('a', 'A'), out('b', 'B')]);
      expect(
        desktopDeviceSignature([mic('a', 'A'), out('b', 'B')]),
        base,
      );
      expect(
        desktopDeviceSignature([mic('a', 'A'), out('b', 'B'), cam('c', 'C')]),
        isNot(base),
      );
      expect(desktopDeviceSignature([mic('a', 'A')]), isNot(base));
      expect(
        desktopDeviceSignature([mic('a', 'A2'), out('b', 'B')]),
        isNot(base),
      );
    });
  });

  group('DesktopDeviceWatcher', () {
    test('первое прочтение не считается изменением', () async {
      var calls = 0;
      final w = DesktopDeviceWatcher(
        onChanged: () => calls++,
        enumerate: () async => [mic('a', 'A')],
      );
      await w.check();
      await w.check();
      expect(calls, 0);
      w.dispose();
    });

    test('подключили устройство — сообщает один раз', () async {
      var calls = 0;
      var list = [mic('a', 'A')];
      final w = DesktopDeviceWatcher(
        onChanged: () => calls++,
        enumerate: () async => list,
      );
      await w.check();
      list = [mic('a', 'A'), mic('b', 'USB')];
      await w.check();
      await w.check();
      expect(calls, 1);
      w.dispose();
    });

    test('система не ответила — не падаем и не сообщаем', () async {
      var calls = 0;
      var fail = false;
      final w = DesktopDeviceWatcher(
        onChanged: () => calls++,
        enumerate: () async {
          if (fail) throw StateError('no devices');
          return [mic('a', 'A')];
        },
      );
      await w.check();
      fail = true;
      await w.check();
      expect(calls, 0);
      w.dispose();
    });

    test('после остановки таймера нет', () {
      final w = DesktopDeviceWatcher(
        onChanged: () {},
        enumerate: () async => const [],
      );
      w.start();
      expect(w.running, isTrue);
      w.stop();
      expect(w.running, isFalse);
      w.dispose();
    });
  });

  group('раздел настроек', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DesktopUiPrefs.resetForTest();
    });

    Widget host(Future<List<MediaDeviceInfo>> Function() enumerate) =>
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DColors(
            colors: kDColorsDark,
            child: Scaffold(
              body: MediaDevicesPane(
                enumerate: enumerate,
                body: (children) => ListView(children: children),
              ),
            ),
          ),
        );

    testWidgets('🔴 подключили гарнитуру — она появляется сама', (t) async {
      var list = <MediaDeviceInfo>[
        mic('m1', 'Встроенный микрофон'),
        out('o1', 'Динамики'),
      ];
      await t.pumpWidget(host(() async => list));
      await t.pumpAndSettle();
      expect(find.text('Встроенный микрофон'), findsOneWidget);
      expect(find.text('Гарнитура USB'), findsNothing);

      list = [...list, mic('m2', 'Гарнитура USB')];
      // Опрос раз в три секунды — без ухода из раздела.
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(find.text('Гарнитура USB'), findsOneWidget);

      list = [mic('m1', 'Встроенный микрофон'), out('o1', 'Динамики')];
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(find.text('Гарнитура USB'), findsNothing);
    });

    testWidgets('выбранное отключено — отмечено «Как в системе»', (t) async {
      DesktopUiPrefs.preferredMicId.value = 'm-gone';
      await t.pumpWidget(
        host(() async => [mic('m1', 'Встроенный микрофон')]),
      );
      await t.pumpAndSettle();
      // Микрофонов один + «Как в системе» → ровно одна отметка на карточку
      // микрофонов, и она у системного пункта.
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      final systemRow = find.ancestor(
        of: find.text(l10n.desktopDevicesSystemDefault).first,
        matching: find.byType(Row),
      );
      expect(
        find.descendant(
          of: systemRow.first,
          matching: find.byIcon(FluentIcons.checkmark_circle_24_filled),
        ),
        findsOneWidget,
      );
    });
  });
}
