// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 Выбор камеры при выключенной камере её включал (30.09.2026).
//
// Выключенная камера в LiveKit — приглушённая дорожка, а переключение
// устройства у неё заново открывает камеру: горел индикатор, кадры уходили в
// созвон, окно писало «камера выключена». Теперь выбор при выключенной
// камере только запоминается и применяется, когда камеру включат.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:secretly_app/rooms/room_call_media_controller.dart';
import 'package:secretly_app/rooms/room_call_media_state.dart';
import 'package:secretly_app/transport/relay_client.dart';
import 'package:secretly_app/ui/desktop/calls/room_call_media_guard.dart';

/// Движок, у которого можно включить и выключить камеру и который помнит,
/// какие камеры у него просили.
class _FakeMedia implements RoomCallMediaController {
  final ValueNotifier<RoomCallLocalMediaState> _state = ValueNotifier(
    const RoomCallLocalMediaState.idle(),
  );
  final List<String> switches = <String>[];
  String? _selected;

  void setCamera({required bool on}) =>
      _state.value = _state.value.copyWith(videoCaptureActive: on);

  @override
  ValueListenable<RoomCallLocalMediaState> get state => _state;

  @override
  String? get selectedVideoInputId => _selected;

  @override
  Future<void> selectVideoInput(String deviceId) async {
    switches.add(deviceId);
    _selected = deviceId;
  }

  @override
  RTCVideoRenderer? get localRenderer => null;

  @override
  bool hasParticipantCameraView(String deviceId) => false;

  @override
  bool hasParticipantScreenShareView(String deviceId) => false;

  @override
  bool isParticipantSpeaking(String deviceId) => false;

  @override
  Widget? buildParticipantVideoView({
    required String deviceId,
    bool mirror = false,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) => null;

  @override
  Future<void> syncSession({
    required RelayRoomCallMediaSession session,
  }) async {}

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {}

  @override
  Future<void> switchCamera() async {}

  @override
  Future<List<RoomCallVideoDevice>> videoInputs() async =>
      const <RoomCallVideoDevice>[];

  @override
  Future<List<RoomCallVideoDevice>> audioInputs() async =>
      const <RoomCallVideoDevice>[];

  @override
  String? get selectedAudioInputId => null;

  @override
  Future<void> selectAudioInput(String deviceId) async {}

  @override
  Future<RoomCallVideoStats?> videoStats({
    required String deviceId,
    RoomCallVideoKind kind = RoomCallVideoKind.auto,
  }) async => null;

  @override
  double participantAudioLevel(String deviceId) => 0;

  @override
  Future<void> dispose() async => _state.dispose();
}

void main() {
  test('🔴 камера выключена — выбор только запоминается', () async {
    final media = _FakeMedia();
    await DesktopRoomCallMediaGuard.chooseCamera(media, 'cam-2');
    await pumpEventQueue();
    expect(media.switches, isEmpty, reason: 'камеру не открываем');
    expect(DesktopRoomCallMediaGuard.chosenCamera(media), 'cam-2');
  });

  test('включили камеру — идёт запомненная, один раз', () async {
    final media = _FakeMedia();
    await DesktopRoomCallMediaGuard.chooseCamera(media, 'cam-2');
    await DesktopRoomCallMediaGuard.chooseCamera(media, 'cam-3');
    media.setCamera(on: true);
    await pumpEventQueue();
    expect(media.switches, <String>['cam-3']);
    // Дальнейшие изменения камеры запомненное не повторяют.
    media.setCamera(on: false);
    media.setCamera(on: true);
    await pumpEventQueue();
    expect(media.switches, <String>['cam-3']);
    expect(DesktopRoomCallMediaGuard.chosenCamera(media), 'cam-3');
  });

  test('включили и сразу выключили — ждём следующего включения', () async {
    final media = _FakeMedia();
    await DesktopRoomCallMediaGuard.chooseCamera(media, 'cam-2');
    media.setCamera(on: true);
    media.setCamera(on: false);
    await pumpEventQueue();
    expect(media.switches, isEmpty, reason: 'выключенную не открываем');
    media.setCamera(on: true);
    await pumpEventQueue();
    expect(media.switches, <String>['cam-2']);
  });

  test('камера идёт — переключаем сразу; ту же камеру — не трогаем', () async {
    final media = _FakeMedia()..setCamera(on: true);
    await DesktopRoomCallMediaGuard.chooseCamera(media, 'cam-2');
    expect(media.switches, <String>['cam-2']);
    await DesktopRoomCallMediaGuard.chooseCamera(media, 'cam-2');
    expect(media.switches, <String>['cam-2']);
  });

  test('камера из настроек — один раз на движок, а не на каждое окно', () async {
    final media = _FakeMedia()..setCamera(on: true);
    await DesktopRoomCallMediaGuard.applyPreferredCamera(media, 'pref');
    expect(media.switches, <String>['pref']);
    // Человек выбрал в доке другую; окно пересоздали (возврат из мини-окна).
    await DesktopRoomCallMediaGuard.chooseCamera(media, 'dock');
    await DesktopRoomCallMediaGuard.applyPreferredCamera(media, 'pref');
    expect(media.switches, <String>['pref', 'dock']);
    // Новый выбор в настройках — применяется.
    await DesktopRoomCallMediaGuard.applyPreferredCamera(media, 'pref-2');
    expect(media.switches, <String>['pref', 'dock', 'pref-2']);
  });

  test('🔴 камера из настроек при выключенной камере её не включает', () async {
    final media = _FakeMedia();
    await DesktopRoomCallMediaGuard.applyPreferredCamera(media, 'pref');
    await DesktopRoomCallMediaGuard.applyPreferredCamera(media, 'pref');
    await pumpEventQueue();
    expect(media.switches, isEmpty);
    media.setCamera(on: true);
    await pumpEventQueue();
    expect(media.switches, <String>['pref']);
  });

  group('🔴 подключено', () {
    final window = File(
      'lib/ui/desktop/calls/room_call_window.dart',
    ).readAsStringSync();
    final pane = File(
      'lib/ui/desktop/workspace/media_devices_pane.dart',
    ).readAsStringSync();

    test('окно созвона и настройки не переключают камеру мимо сторожа', () {
      expect(window.contains('media.selectVideoInput('), isFalse);
      expect(pane.contains('.selectVideoInput('), isFalse);
      expect(window.contains('DesktopRoomCallMediaGuard.chooseCamera('), isTrue);
      expect(window.contains('DesktopRoomCallMediaGuard.chosenCamera(media)'), isTrue);
    });
  });
}
