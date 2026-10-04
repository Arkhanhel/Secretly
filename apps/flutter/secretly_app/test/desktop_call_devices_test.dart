// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// 🔴 «ВО ВРЕМЯ ЗВОНКА ОН ВЫБИРАЕТ НЕ СТАНДАРТНЫЕ ДИНАМИКИ, А ПЕРВЫЕ ПО СПИСКУ»
// (владелец, 28.09.2026).
//
// Правило телефона — тип устройства по английскому слову в названии и
// порядок BT → проводные → динамики — на компьютере выбирало первое по
// алфавиту: «Динамики (Realtek)» не содержит «speaker», и звук уходил в
// латинское имя монитора. Здесь стережётся новое правило ПК: ничего не
// угадывать — «как в системе» или выбор человека.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:secretly_app/calls/call_audio_route.dart';
import 'package:secretly_app/calls/webrtc_call_session.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/calls/call_device_menu.dart';
import 'package:secretly_app/ui/desktop/services/desktop_call_devices.dart';

MediaDeviceInfo out(String id, String label) =>
    MediaDeviceInfo(deviceId: id, label: label, kind: 'audiooutput');
MediaDeviceInfo mic(String id, String label) =>
    MediaDeviceInfo(deviceId: id, label: label, kind: 'audioinput');

// Настоящая подборка русской Windows: монитор по HDMI — латиницей, поэтому
// «первый по алфавиту».
// Порядок — как отдаёт Windows: монитор первым. И по алфавиту он тоже
// первый: латиница раньше кириллицы.
final russianWindows = <MediaDeviceInfo>[
  out('{0.0.0.00000000}.{bbbb}', 'DELL U2719D (NVIDIA High Definition Audio)'),
  out('{0.0.0.00000000}.{cccc}', 'Наушники (WH-1000XM4)'),
  out('{0.0.0.00000000}.{aaaa}', 'Динамики (Realtek(R) Audio)'),
];

void main() {
  group('правило выбора динамиков на ПК', () {
    test('🔴 русская Windows: берём системное, а не первое по алфавиту', () {
      final d = resolveDesktopAudioRoute(
        devices: russianWindows,
        inCallSelection: '',
        preferredId: '',
        systemDefaultId: '{0.0.0.00000000}.{aaaa}',
      );
      expect(d.selectedRouteId, kSystemDefaultAudioRouteId);
      expect(d.applyDeviceId, '{0.0.0.00000000}.{aaaa}',
          reason: 'звук обязан пойти в «Динамики», которые выбраны в Windows');
      expect(d.applyDeviceId, isNot('{0.0.0.00000000}.{bbbb}'),
          reason: 'монитор — ровно то, куда звук уходил раньше');
    });

    test('система не ответила — ничего не трогаем, а не угадываем', () {
      final d = resolveDesktopAudioRoute(
        devices: russianWindows,
        inCallSelection: '',
        preferredId: '',
        systemDefaultId: null,
      );
      expect(d.selectedRouteId, kSystemDefaultAudioRouteId);
      expect(d.applyDeviceId, isNull);
    });

    test('macOS: пункт модуля «default (…)» и есть «как в системе»', () {
      final d = resolveDesktopAudioRoute(
        devices: <MediaDeviceInfo>[
          out('dflt', 'default (AirPods Pro)'),
          out('mbp', 'MacBook Pro Speakers'),
          out('air', 'AirPods Pro'),
        ],
        inCallSelection: '',
        preferredId: '',
        systemDefaultId: null,
      );
      expect(d.applyDeviceId, 'dflt',
          reason: 'раньше выбирались встроенные динамики вместо AirPods');
      // Служебный пункт в меню не показываем: его роль — «Как в системе».
      expect(d.routes.map((r) => r.deviceId), [
        kSystemDefaultAudioRouteId,
        'mbp',
        'air',
      ]);
    });

    test('выбор в настройках важнее системы, выбор в звонке — важнее всех', () {
      final pref = resolveDesktopAudioRoute(
        devices: russianWindows,
        inCallSelection: '',
        preferredId: '{0.0.0.00000000}.{cccc}',
        systemDefaultId: '{0.0.0.00000000}.{aaaa}',
      );
      expect(pref.applyDeviceId, '{0.0.0.00000000}.{cccc}');
      final inCall = resolveDesktopAudioRoute(
        devices: russianWindows,
        inCallSelection: '{0.0.0.00000000}.{bbbb}',
        preferredId: '{0.0.0.00000000}.{cccc}',
        systemDefaultId: '{0.0.0.00000000}.{aaaa}',
      );
      expect(inCall.applyDeviceId, '{0.0.0.00000000}.{bbbb}');
      final backToSystem = resolveDesktopAudioRoute(
        devices: russianWindows,
        inCallSelection: kSystemDefaultAudioRouteId,
        preferredId: '{0.0.0.00000000}.{cccc}',
        systemDefaultId: '{0.0.0.00000000}.{aaaa}',
      );
      expect(backToSystem.applyDeviceId, '{0.0.0.00000000}.{aaaa}');
    });

    test('выбранное устройство отключили — возвращаемся к системному', () {
      final d = resolveDesktopAudioRoute(
        devices: russianWindows,
        inCallSelection: '',
        preferredId: '{gone}',
        systemDefaultId: '{0.0.0.00000000}.{aaaa}',
      );
      expect(d.selectedRouteId, kSystemDefaultAudioRouteId);
      expect(d.applyDeviceId, '{0.0.0.00000000}.{aaaa}');
    });
  });

  group('контроллер в режиме ПК', () {
    const channel = MethodChannel('FlutterWebRTC.Method');
    late List<String> selected;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      selected = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getSources':
            return <String, dynamic>{
              'sources': [
                for (final d in russianWindows)
                  <String, dynamic>{
                    'deviceId': d.deviceId,
                    'label': d.label,
                    'kind': d.kind,
                  },
              ],
            };
          case 'selectAudioOutput':
            selected.add((call.arguments as Map)['deviceId'] as String);
            return null;
        }
        return null;
      });
      DesktopCallDevices.hooks = DesktopCallDeviceHooks(
        preferredOutputId: () => '',
        systemDefaultOutputId: () async => '{0.0.0.00000000}.{aaaa}',
      );
    });

    tearDown(() {
      DesktopCallDevices.hooks = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('🔴 в начале звонка включаются системные «Динамики»', () async {
      final ctl = CallAudioRouteController(logTag: 'T', desktopMode: true);
      await ctl.ensureReady(preferSpeakerByDefault: false, reason: 'start');
      expect(selected, ['{0.0.0.00000000}.{aaaa}']);
      expect(ctl.state.value.selectedRouteId, kSystemDefaultAudioRouteId);
      expect(ctl.state.value.availableRoutes.first.deviceId,
          kSystemDefaultAudioRouteId);
      await ctl.dispose();
    });

    test('выбор в звонке включает устройство и переживает обновление',
        () async {
      final ctl = CallAudioRouteController(logTag: 'T', desktopMode: true);
      await ctl.ensureReady(preferSpeakerByDefault: false, reason: 'start');
      await ctl.selectRoute(
        routeId: '{0.0.0.00000000}.{cccc}',
        preferSpeakerByDefault: false,
        reason: 'user',
      );
      expect(selected.last, '{0.0.0.00000000}.{cccc}');
      expect(ctl.state.value.selectedRouteId, '{0.0.0.00000000}.{cccc}');
      await ctl.dispose();
    });

    test('телефонная ветка не тронута: без режима ПК правило прежнее',
        () async {
      final ctl = CallAudioRouteController(logTag: 'T', desktopMode: false);
      await ctl.ensureReady(preferSpeakerByDefault: false, reason: 'start');
      expect(
        ctl.state.value.availableRoutes
            .any((r) => r.deviceId == kSystemDefaultAudioRouteId),
        isFalse,
      );
      await ctl.dispose();
    });
  });

  group('микрофон', () {
    test('выбранный — если подключён, иначе системный', () {
      final inputs = [
        mic('{m1}', 'Микрофон (Realtek)'),
        mic('{m2}', 'Микрофон гарнитуры'),
      ];
      expect(
        resolveDesktopMicrophone(
          inputs: inputs,
          preferredId: '{m2}',
          systemDefaultId: '{m1}',
        ),
        '{m2}',
      );
      expect(
        resolveDesktopMicrophone(
          inputs: inputs,
          preferredId: '{gone}',
          systemDefaultId: '{m1}',
        ),
        '{m1}',
      );
      expect(
        resolveDesktopMicrophone(
          inputs: [mic('d', 'default (MacBook Pro Microphone)'), ...inputs],
          preferredId: '',
          systemDefaultId: null,
        ),
        'd',
      );
      expect(
        resolveDesktopMicrophone(
          inputs: inputs,
          preferredId: '',
          systemDefaultId: null,
        ),
        isNull,
        reason: 'не угадываем — оставляем модуль как есть',
      );
    });

    test('в списках нет служебного «default (…)» и нет пустых имён', () {
      final list = filterDesktopDevices(
        [
          mic('d', 'default (MacBook Pro Microphone)'),
          mic('{m1}', ''),
          mic('{m1}', 'дубль'),
          out('{o}', 'Динамики'),
        ],
        kind: 'audioinput',
        unnamed: 'Микрофон',
      );
      expect(list.map((d) => d.deviceId), ['{m1}']);
      expect(list.single.label, 'Микрофон');
    });
  });

  group('меню устройств в звонке', () {
    final ru = lookupAppLocalizations(const Locale('ru'));

    test('два раздела, «Как в системе» первым в каждом', () {
      final sections = buildCallDeviceMenuSections(
        l10n: ru,
        microphones: const [
          DesktopDevice(deviceId: '{m1}', label: 'Микрофон (Realtek)'),
        ],
        selectedMicrophoneId: '',
        outputs: CallAudioRouteState(
          availableRoutes: const [
            CallAudioRouteOption(
              deviceId: kSystemDefaultAudioRouteId,
              label: '',
              kind: CallAudioRouteKind.unknown,
            ),
            CallAudioRouteOption(
              deviceId: '{o1}',
              label: 'Наушники',
              kind: CallAudioRouteKind.unknown,
            ),
          ],
          selectedRouteId: kSystemDefaultAudioRouteId,
          selectedRouteKind: CallAudioRouteKind.unknown,
          preferSpeakerByDefault: false,
          userSelectionActive: false,
        ),
        onPickMicrophone: (_) {},
        onPickOutput: (_) {},
      );
      expect(sections, hasLength(2));
      expect(sections[0].map((i) => i.label), [
        'Микрофон',
        'Как выбрано в системе',
        'Микрофон (Realtek)',
      ]);
      expect(sections[0].first.enabled, isFalse, reason: 'заголовок раздела');
      expect(sections[1].map((i) => i.label), [
        'Динамики и наушники',
        'Как выбрано в системе',
        'Наушники',
      ]);
    });
  });

  group('звонок 1:1 берёт выбранные устройства', () {
    test('камера из настроек — по ключам и macOS, и Windows', () {
      final c = WebRtcCallSession.buildVideoCaptureConstraints(
        withAudio: true,
        preset: CallVideoQualityPreset.hd,
        cameraDeviceId: 'cam-2',
      );
      final video = c['video'] as Map<String, dynamic>;
      expect(video['deviceId'], 'cam-2');
      expect(video['optional'], [
        {'sourceId': 'cam-2'},
      ]);
      expect(video.containsKey('facingMode'), isFalse);
    });

    test('без выбора — как раньше', () {
      final c = WebRtcCallSession.buildVideoCaptureConstraints(
        withAudio: true,
        preset: CallVideoQualityPreset.hd,
      );
      expect((c['video'] as Map)['facingMode'], 'user');
    });

    test('микрофон выбирается ДО захвата звука', () {
      final src = File('lib/calls/webrtc_call_session.dart').readAsStringSync();
      final prep = src.indexOf('await _prepareDesktopCapture();');
      final gum = src.indexOf('local = await navigator.mediaDevices.getUserMedia(');
      expect(prep, greaterThan(0));
      expect(prep, lessThan(gum));
    });

    test('ПК подключает свои устройства при запуске окна', () {
      final app = File('lib/ui/desktop/app/desktop_production_app.dart')
          .readAsStringSync();
      expect(app, contains('installDesktopCallDevices();'));
    });
  });
}
