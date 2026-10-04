// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// МИКРОФОН, ДИНАМИКИ И КАМЕРА ЗВОНКОВ НА ПК.
///
/// 🔴 ЗАЧЕМ (28.09.2026, владелец: «во время звонка он выбирает не
/// стандартные динамики, а первые по списку»). Общий код звонков выбирал
/// устройство вывода по английскому слову в названии и на компьютере уводил
/// звук в первое по алфавиту устройство. А микрофон и камера, выбранные в
/// настройках, доходили только до групповых звонков.
///
/// Здесь — то, чего нет в общем коде: выбор человека из настроек и ответ
/// Windows «какое устройство основное». Подключается к общему коду через
/// `DesktopCallDevices.hooks` (`lib/calls/call_audio_route.dart`); телефон
/// эту точку не заполняет и живёт по-прежнему.
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:win32/win32.dart' as win;

import '../../../calls/call_audio_route.dart';
import '../../../calls/call_log.dart';
import 'desktop_call_prefs.dart';
import 'desktop_sounds.dart';
import 'desktop_ui_prefs.dart';

/// Подключить устройства ПК к звонкам. Вызывается один раз при запуске окна.
void installDesktopCallDevices() {
  // Свои настройки звонков ПК (зеркало своего видео, громкость мелодии —
  // 30.09.2026) читаем здесь, заранее: к первому звонку они уже должны быть
  // на месте.
  unawaited(DesktopCallPrefs.load());
  DesktopCallDevices.hooks = DesktopCallDeviceHooks(
    preferredOutputId: () => DesktopUiPrefs.preferredSpeakerId.value,
    systemDefaultOutputId: () async =>
        windowsDefaultAudioEndpointId(capture: false),
    prepareCapture: prepareDesktopMicrophone,
    preferredCameraId: () => DesktopUiPrefs.preferredCameraId.value,
    ringtoneVolume: () => DesktopCallPrefs.ringtoneVolume.value,
    // Мелодия входящего — выбранная в настройках ПК (01.10.2026).
    ringtoneAsset: DesktopSounds.callRingtoneAssetFor,
  );
}

/// Какое устройство звука Windows считает основным — идентификатор конечной
/// точки. Это тот же идентификатор, что отдаёт `flutter_webrtc` в списке
/// устройств: модуль звука WebRTC на Windows берёт его у `IMMDevice::GetId`.
///
/// Роль `eConsole` — «Устройство по умолчанию» из настроек звука Windows,
/// то самое, что человек видит у значка громкости. На macOS и Linux `null`:
/// там модуль звука сам даёт пункт «default (…)».
String? windowsDefaultAudioEndpointId({required bool capture}) {
  if (!Platform.isWindows) return null;
  final init = win.CoInitializeEx(nullptr, win.COINIT_APARTMENTTHREADED);
  // S_OK/S_FALSE — надо снять своё; RPC_E_CHANGED_MODE — COM уже поднят в
  // другом режиме, работать можно, снимать нельзя.
  final balance = init == win.S_OK || init == win.S_FALSE;
  final ppDevice = calloc<Pointer<win.COMObject>>();
  final ppId = calloc<Pointer<Utf16>>();
  win.MMDeviceEnumerator? enumerator;
  try {
    enumerator = win.MMDeviceEnumerator.createInstance();
    final hr = enumerator.getDefaultAudioEndpoint(
      capture ? win.eCapture : win.eRender,
      win.eConsole,
      ppDevice,
    );
    if (win.FAILED(hr) || ppDevice.value == nullptr) return null;
    final device = win.IMMDevice(ppDevice.value);
    try {
      if (win.FAILED(device.getId(ppId)) || ppId.value == nullptr) return null;
      final id = ppId.value.toDartString();
      win.CoTaskMemFree(ppId.value);
      return id.isEmpty ? null : id;
    } finally {
      device.release();
    }
  } catch (e) {
    callLog('DesktopAudio', 'default endpoint lookup failed: $e');
    return null;
  } finally {
    enumerator?.release();
    calloc.free(ppDevice);
    calloc.free(ppId);
    if (balance) win.CoUninitialize();
  }
}

/// Какой микрофон взять. Чистая функция.
///
/// Выбранный в настройках, если он подключён; иначе системный: пункт модуля
/// «default (…)» (macOS) или устройство, которое Windows назвала основным.
/// Не удалось узнать — `null`: оставляем модуль как есть.
String? resolveDesktopMicrophone({
  required Iterable<MediaDeviceInfo> inputs,
  required String preferredId,
  required String? systemDefaultId,
}) {
  final ids = <String>[];
  String? moduleDefault;
  for (final d in inputs) {
    final id = d.deviceId.trim();
    if (id.isEmpty) continue;
    if (isSystemDefaultAudioDevice(deviceId: id, label: d.label)) {
      moduleDefault ??= id;
      continue;
    }
    ids.add(id);
  }
  final preferred = preferredId.trim();
  if (preferred.isNotEmpty && ids.contains(preferred)) return preferred;
  if (moduleDefault != null) return moduleDefault;
  final system = systemDefaultId?.trim();
  if (system != null && ids.contains(system)) return system;
  return null;
}

/// Какие устройства показывать в списках ПК.
enum DesktopDeviceKind { microphone, speakers, camera }

/// Устройство для списка: идентификатор и имя.
class DesktopDevice {
  const DesktopDevice({required this.deviceId, required this.label});

  final String deviceId;
  final String label;
}

/// Список устройств системы — без служебного пункта «default (…)»: его роль
/// в наших списках играет «Как в системе», и двух одинаковых строк быть не
/// должно. Безымянное устройство называется [unnamed]: пока не выдано
/// разрешение, система отдаёт пустые имена.
///
/// [enumerate] — откуда брать список; по умолчанию у системы. Подменяют
/// тесты раздела настроек.
Future<List<DesktopDevice>> desktopDeviceList(
  DesktopDeviceKind kind, {
  required String unnamed,
  Future<List<MediaDeviceInfo>> Function()? enumerate,
}) async {
  final wanted = switch (kind) {
    DesktopDeviceKind.microphone => 'audioinput',
    DesktopDeviceKind.speakers => 'audiooutput',
    DesktopDeviceKind.camera => 'videoinput',
  };
  try {
    final all = await (enumerate ?? navigator.mediaDevices.enumerateDevices)();
    return filterDesktopDevices(all, kind: wanted, unnamed: unnamed);
  } catch (_) {
    return const <DesktopDevice>[];
  }
}

/// Чистая часть [desktopDeviceList] — для тестов.
List<DesktopDevice> filterDesktopDevices(
  Iterable<MediaDeviceInfo> all, {
  required String kind,
  required String unnamed,
}) {
  final seen = <String>{};
  final out = <DesktopDevice>[];
  for (final d in all) {
    if (d.kind != kind) continue;
    final id = d.deviceId.trim();
    if (id.isEmpty || !seen.add(id)) continue;
    if (isSystemDefaultAudioDevice(deviceId: id, label: d.label)) continue;
    final label = d.label.trim();
    out.add(DesktopDevice(deviceId: id, label: label.isEmpty ? unnamed : label));
  }
  return out;
}

/// Какую камеру включить в идущем созвоне. Чистая функция.
///
/// Выбранную, если она подключена; иначе ту, что движок открывает сам, когда
/// выбора нет, — первую в списке системы (Windows открывает устройство №0,
/// macOS — первое из того же списка). Камер нет — `null`.
///
/// 🔴 ЗАЧЕМ (ТЗ §1.4): «Как в системе» во время созвона НИЧЕГО не меняло —
/// выбор пустой строки просто не доходил до звонка, и камера оставалась
/// прежней. Теперь «как в системе» — это конкретная камера, как и любой
/// другой выбор.
String? resolveDesktopCamera({
  required Iterable<MediaDeviceInfo> devices,
  required String preferredId,
}) {
  final ids = <String>[
    for (final d in devices)
      if (d.kind == 'videoinput' && d.deviceId.trim().isNotEmpty)
        d.deviceId.trim(),
  ];
  final preferred = preferredId.trim();
  if (preferred.isNotEmpty && ids.contains(preferred)) return preferred;
  return ids.isEmpty ? null : ids.first;
}

/// Какую камеру включить сейчас (см. [resolveDesktopCamera]); `null` — камер
/// нет или система не ответила.
Future<String?> desktopCameraTarget({
  Future<List<MediaDeviceInfo>> Function()? enumerate,
}) async {
  try {
    final devices =
        await (enumerate ?? navigator.mediaDevices.enumerateDevices)();
    return resolveDesktopCamera(
      devices: devices,
      preferredId: DesktopUiPrefs.preferredCameraId.value,
    );
  } catch (_) {
    return null;
  }
}

/// Какой микрофон включить сейчас: выбранный или системный; `null` — не
/// удалось узнать, оставляем как есть.
Future<String?> desktopMicrophoneTarget() async {
  final devices = await navigator.mediaDevices.enumerateDevices();
  return resolveDesktopMicrophone(
    inputs: devices.where((d) => d.kind == 'audioinput'),
    preferredId: DesktopUiPrefs.preferredMicId.value,
    systemDefaultId: windowsDefaultAudioEndpointId(capture: true),
  );
}

/// Выбрать микрофон перед захватом звука. Модуль звука WebRTC общий на
/// процесс и помнит прошлый выбор, поэтому «как в системе» тоже выбирается
/// явно — иначе после одного звонка с другим микрофоном следующий шёл бы
/// через него же.
Future<void> prepareDesktopMicrophone() async {
  final target = await desktopMicrophoneTarget();
  if (target == null) return;
  await Helper.selectAudioInput(target);
  callLog('DesktopAudio', 'microphone selected before capture');
}
