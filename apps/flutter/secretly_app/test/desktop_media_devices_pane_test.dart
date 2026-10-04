// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// ◆ Раздел настроек «Звук и видео».
//
// Его не было, и причина была ВЕРНОЙ: до 15.09.2026 движок не умел перечислять
// устройства, и пункт вышел бы мёртвой панелью. Теперь умеет — и панель
// собирается из настоящего списка системы.
//
// 🔴 ПЕРЕЧИСЛЕНИЕ НЕ ТРЕБУЕТ СЕССИИ. Первая редакция брала список у
// `DefaultRoomCallMediaController()` и честно показывала «Камер не найдено»:
// вне звонка у фасада нет делегата, и любой его метод отвечает «не знаю».
// Поймано живьём.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';

void main() {
  final pane = File(
    'lib/ui/desktop/workspace/media_devices_pane.dart',
  ).readAsStringSync();
  final media = File(
    'lib/rooms/room_call_media_controller.dart',
  ).readAsStringSync();
  final win = File(
    'lib/ui/desktop/calls/room_call_window.dart',
  ).readAsStringSync();

  test('🔴 список берётся у СИСТЕМЫ, а не у движка созвона', () {
    // 28.09.2026: список — `desktopDeviceList` (desktop_call_devices.dart):
    // тоже у системы, плюс динамики и без служебного «default (…)».
    expect(pane.contains('desktopDeviceList('), isTrue);
    expect(pane.contains('DesktopDeviceKind.camera'), isTrue);
    expect(pane.contains('DesktopDeviceKind.microphone'), isTrue);
    expect(pane.contains('DesktopDeviceKind.speakers'), isTrue);
    final devices = File(
      'lib/ui/desktop/services/desktop_call_devices.dart',
    ).readAsStringSync();
    expect(devices.contains('navigator.mediaDevices.enumerateDevices()'), isTrue);
    // В коде фасада больше нет — упоминание осталось только в объяснении,
    // почему его тут быть не должно.
    final code = pane
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');
    expect(code.contains('DefaultRoomCallMediaController()'), isFalse);
    // Отдельная функция, а не метод фасада — именно потому, что фасад вне
    // звонка пуст.
    expect(
      media.contains('Future<List<RoomCallVideoDevice>> roomCallSystemDevices('),
      isTrue,
    );
  });

  test('раздел зарегистрирован в настройках', () {
    final settings = File(
      'lib/ui/desktop/workspace/settings_workspace.dart',
    ).readAsStringSync();
    expect(settings.contains("id: 'media',"), isTrue);
    // 19.09.2026: названия разделов уехали в переводы.
    expect(settings.contains('label: l10n.desktopSettingsMediaLabel,'), isTrue);
    expect(settings.contains('MediaDevicesPane('), isTrue);
  });

  test('«Как выбрано в системе» — первым и достижимо после любого выбора', () {
    final i = pane.indexOf('final rows = <Widget>[');
    final body = pane.substring(i, (i + 500).clamp(0, pane.length));
    expect(body.contains('label: l10n.desktopDevicesSystemDefault'), isTrue);
    expect(
      body.indexOf('desktopDevicesSystemDefault') <
          body.indexOf('for (final d in devices)'),
      isTrue,
    );
    expect(body.contains("onTap: () => onPick('')"), isTrue);
  });

  test('🔴 хранится ИДЕНТИФИКАТОР, а не имя', () {
    // Имена меняются при переподключении, а пропавшее устройство должно
    // откатиться к системному, а не увести звонок в тишину.
    final prefs = File(
      'lib/ui/desktop/services/desktop_ui_prefs.dart',
    ).readAsStringSync();
    expect(prefs.contains('preferredCameraId'), isTrue);
    expect(prefs.contains('preferredMicId'), isTrue);
    expect(DesktopUiPrefs.preferredCameraId.value, '');
    expect(DesktopUiPrefs.preferredMicId.value, '');
  });

  test('🔴 настройка ДЕСКТОПНАЯ и не едет на телефон', () {
    // Камера у стола и камера в кармане — разные устройства; на телефоне
    // такого выбора нет вовсе.
    final ctrl = File('lib/app/app_controller.dart').readAsStringSync();
    expect(ctrl.contains('preferredCameraId'), isFalse);
    expect(ctrl.contains('preferredMicId'), isFalse);
  });

  test('🔴 выбор применяется к ЖИВОМУ звонку, а не «со следующего раза»', () {
    // Иначе раздел был бы списком без последствий: выбрал гарнитуру, начал
    // звонок — и говоришь во встроенный микрофон.
    expect(win.contains('Future<void> _applyPreferredDevices() async {'), isTrue);
    // Камера — через сторожа: выключенную не включает (30.09.2026).
    expect(
      win.contains(
        'await DesktopRoomCallMediaGuard.applyPreferredCamera(media, cam);',
      ),
      isTrue,
    );
    expect(win.contains('await media.selectAudioInput(mic);'), isTrue);
    // И применяется ОДИН раз: дальше человек может поменять камеру в доке, и
    // настройка не должна отматывать его выбор назад на каждом тике.
    expect(win.contains('if (_preferredDevicesApplied) return;'), isTrue);
    // Пустой выбор ничего не переключает — «как в системе» и значит «не лезь».
    expect(win.contains('if (cam.isNotEmpty)'), isTrue);
    expect(win.contains('if (mic.isNotEmpty)'), isTrue);
  });

  test('🔴 вывод звука выбирается и здесь — одна настройка со звонком', () {
    // 28.09.2026, владелец: «в настройках в разделе „Звонки“ нет настроек
    // устройств». Раньше вывод звука угадывал звонок сам — по слову в
    // названии — и на русской Windows уводил звук в монитор. Теперь по
    // умолчанию «Как выбрано в системе», а выбор отсюда и из меню звонка —
    // одна и та же `preferredSpeakerId`, так что двух хозяев нет.
    expect(pane.contains('l10n.desktopDevicesSpeakers'), isTrue);
    expect(pane.contains('DesktopUiPrefs.setPreferredSpeaker(id)'), isTrue);
    final menu = File(
      'lib/ui/desktop/calls/call_device_menu.dart',
    ).readAsStringSync();
    expect(menu.contains('DesktopUiPrefs.setPreferredSpeaker('), isTrue);
    // Прямого вызова модуля звука здесь нет: применяет звонок, по своему
    // правилу «как в системе» (call_audio_route.dart).
    expect(pane.contains('Helper.selectAudioOutput'), isFalse);
  });

  test('микрофон переключается У ДОРОЖКИ, как и камера', () {
    expect(media.contains('await track.setDeviceId(want);'), isTrue);
  });
}
