// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Превью камеры и «Зеркалить моё видео» (ТЗ «ПК как Telegram», §1.4).
//
// 🔴 Камера включается ТОЛЬКО кнопкой: её огонёк видно через всю комнату, и
// приложение для тайной переписки не должно зажигать его оттого, что человек
// зашёл в настройки. Гаснет, когда раздел уходит с экрана или начинается
// звонок. Зеркало — только своё изображение, и во ВСЕХ звонках ПК.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:secretly_app/calls/webrtc_call_session.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_audio_output.dart';
import 'package:secretly_app/ui/desktop/services/desktop_call_prefs.dart';
import 'package:secretly_app/ui/desktop/services/desktop_camera_preview.dart';
import 'package:secretly_app/ui/desktop/services/desktop_mic_check.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/workspace/media_check_rows.dart';
import 'package:secretly_app/ui/desktop/workspace/media_devices_pane.dart';
import 'package:secretly_app/ui/desktop/workspace/workspace_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCameraEngine implements DesktopCameraPreviewEngine {
  int starts = 0;
  int stops = 0;
  bool disposed = false;
  bool on = false;
  bool fail = false;
  String? lastId;

  /// Держит открытие камеры, пока тест не отпустит.
  Completer<void>? gate;

  @override
  Future<void> start(String cameraId) async {
    final g = gate;
    if (g != null) await g.future;
    if (fail) throw StateError('camera busy');
    starts++;
    lastId = cameraId;
    on = true;
  }

  @override
  Future<void> stop() async {
    if (on) stops++;
    on = false;
  }

  @override
  Widget view({required bool mirror}) =>
      SizedBox(key: ValueKey<String>('preview-mirror-$mirror'));

  @override
  Future<void> dispose() async {
    await stop();
    disposed = true;
  }
}

class _SilentMic implements DesktopMicCapture {
  @override
  Future<bool> hasPermission({required bool request}) async => false;

  @override
  Future<DesktopMicStream> open({
    required String webrtcDeviceId,
    required String label,
    required int sampleRate,
  }) async => throw StateError('not used');

  @override
  Future<void> close() async {}

  @override
  Future<void> dispose() async {}
}

class _SilentOutput implements DesktopAudioOutput {
  @override
  Future<DesktopPlayback?> play(
    pcm, {
    required int sampleRate,
    required String outputDeviceId,
    String outputLabel = '',
  }) async => null;

  @override
  Future<void> dispose() async {}
}

void main() {
  group('ограничения превью — те же, что у звонка 1:1', () {
    Map<String, dynamic> videoOf(Map<String, dynamic> c) =>
        (c['video'] as Map).cast<String, dynamic>();

    for (final id in const ['', 'cam-usb']) {
      test('камера «$id»: те же ключи выбора, что в звонке', () {
        final preview = desktopCameraPreviewConstraints(id);
        final call = WebRtcCallSession.buildVideoCaptureConstraints(
          withAudio: false,
          preset: CallVideoQualityPreset.low,
          cameraDeviceId: id,
        );
        expect(preview['audio'], isFalse, reason: 'превью не слушает');
        for (final key in const ['deviceId', 'optional', 'facingMode']) {
          expect(
            videoOf(preview)[key],
            videoOf(call)[key],
            reason: 'иначе превью показало бы одну камеру, а звонок — другую',
          );
        }
      });
    }
  });

  group('DesktopCameraPreviewController', () {
    test('включается по просьбе и гаснет по просьбе', () async {
      final engine = FakeCameraEngine();
      final c = DesktopCameraPreviewController(engine: engine);
      expect(c.status, CameraPreviewStatus.off);
      await c.show('cam-1');
      expect(c.status, CameraPreviewStatus.on);
      expect(engine.lastId, 'cam-1');
      await c.hide();
      expect(c.status, CameraPreviewStatus.off);
      expect(engine.on, isFalse);
      c.dispose();
    });

    test('выбрали другую камеру — превью идёт за ней', () async {
      final engine = FakeCameraEngine();
      final c = DesktopCameraPreviewController(engine: engine);
      await c.follow('cam-2');
      expect(engine.starts, 0, reason: 'выключенное превью само не включается');
      await c.show('cam-1');
      await c.follow('cam-2');
      expect(engine.lastId, 'cam-2');
      expect(engine.starts, 2);
      c.dispose();
    });

    test('камера занята — «не удалось включить»', () async {
      final engine = FakeCameraEngine()..fail = true;
      final c = DesktopCameraPreviewController(engine: engine);
      await c.show('');
      expect(c.status, CameraPreviewStatus.failed);
      expect(c.active, isFalse);
      c.dispose();
    });

    test('🔴 «Скрыть» раньше, чем камера открылась, — она не остаётся гореть', () async {
      final engine = FakeCameraEngine()..gate = Completer<void>();
      final c = DesktopCameraPreviewController(engine: engine);
      final showing = c.show('cam-1');
      final hiding = c.hide();
      engine.gate!.complete();
      await showing;
      await hiding;
      expect(c.status, CameraPreviewStatus.off);
      expect(engine.on, isFalse);
      c.dispose();
    });

    test('раздел закрыли — камера погашена', () async {
      final engine = FakeCameraEngine();
      final c = DesktopCameraPreviewController(engine: engine);
      await c.show('cam-1');
      c.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(engine.on, isFalse);
      expect(engine.disposed, isTrue);
    });
  });

  group('DesktopCallPrefs', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DesktopCallPrefs.resetForTest();
    });

    test('по умолчанию зеркалим, выбор переживает перезапуск', () async {
      expect(DesktopCallPrefs.mirrorSelfView.value, isTrue);
      await DesktopCallPrefs.setMirrorSelfView(false);
      DesktopCallPrefs.resetForTest();
      await DesktopCallPrefs.load();
      expect(DesktopCallPrefs.mirrorSelfView.value, isFalse);
    });

    test('ключ свой, ПК: на телефон не едет', () {
      final src = File(
        'lib/ui/desktop/services/desktop_call_prefs.dart',
      ).readAsStringSync();
      expect(src.contains("'desktop_call_mirror_self_v1'"), isTrue);
      final ctrl = File('lib/app/app_controller.dart').readAsStringSync();
      expect(ctrl.contains('desktop_call_mirror_self_v1'), isFalse);
    });

    test('настройки звонков ПК читаются при запуске окна', () {
      final src = File(
        'lib/ui/desktop/services/desktop_call_devices.dart',
      ).readAsStringSync();
      final i = src.indexOf('void installDesktopCallDevices() {');
      expect(
        src.substring(i, i + 400).contains('DesktopCallPrefs.load()'),
        isTrue,
      );
    });
  });

  group('🔴 зеркало — во всех звонках ПК, только своё', () {
    String read(String path) => File(path).readAsStringSync();

    test('звонок 1:1: своё окошко', () {
      final src = read('lib/ui/desktop/calls/one_to_one_call_screen.dart');
      expect(src.contains('valueListenable: DesktopCallPrefs.mirrorSelfView'), isTrue);
      expect(src.contains('mirror: s.isFrontCamera && mirrorSelf'), isTrue);
    });

    test('созвон: плитка, лента и сцена — только своя камера', () {
      final src = read('lib/ui/desktop/calls/room_call_window.dart');
      expect(src.contains('mirror: runtime.isSelf && _mirrorSelf'), isTrue);
      expect(
        src.contains('mirror: found.isSelf && !pick.screenShare && _mirrorSelf'),
        isTrue,
        reason: 'демонстрация экрана зеркальной не бывает ни у кого',
      );
      expect(src.contains('(_runtimeFor(p.deviceId)?.isSelf ?? false) &&'), isTrue);
      expect(
        src.contains('DesktopCallPrefs.mirrorSelfView.addListener(_onMirrorPref)'),
        isTrue,
      );
      expect(
        src.contains('DesktopCallPrefs.mirrorSelfView.removeListener(_onMirrorPref)'),
        isTrue,
      );
    });

    test('мини-окно созвона', () {
      final src = read('lib/ui/desktop/calls/call_mini_host.dart');
      expect(src.contains('DesktopCallPrefs.mirrorSelfView.value'), isTrue);
      expect(src.contains('!pick.screenShare &&'), isTrue);
    });
  });

  group('раздел: камера', () {
    // Карточка камеры — последняя: в окне по умолчанию она ниже края, и
    // нажатие ушло бы мимо.
    void tall(WidgetTester t) {
      t.view.physicalSize = const Size(900, 2400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DesktopUiPrefs.resetForTest();
      DesktopCallPrefs.resetForTest();
    });

    Widget host(
      FakeCameraEngine engine, {
      ValueNotifier<bool>? busy,
      DesktopAudioPlatform platform = DesktopAudioPlatform.windows,
      bool noCameras = false,
    }) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: MediaDevicesPane(
            enumerate: () async => [
              if (!noCameras) ...[
                MediaDeviceInfo(deviceId: 'cam-1', label: 'FaceTime HD', kind: 'videoinput'),
                MediaDeviceInfo(deviceId: 'cam-2', label: 'Logitech C920', kind: 'videoinput'),
              ],
            ],
            checks: MediaCheckServices(
              platform: platform,
              micCapture: _SilentMic.new,
              audioOutput: _SilentOutput.new,
              cameraEngine: () => engine,
              callActive: busy ?? ValueNotifier<bool>(false),
            ),
            body: (children) => ListView(children: children),
          ),
        ),
      ),
    );

    testWidgets('🔴 зашёл в раздел — камера НЕ включилась', (t) async {
      final engine = FakeCameraEngine();
      tall(t);
      await t.pumpWidget(host(engine));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.desktopCameraPreview), findsOneWidget);
      expect(engine.starts, 0);
    });

    testWidgets('«Показать» — выбранная камера; зеркало меняется сразу', (t) async {
      DesktopUiPrefs.preferredCameraId.value = 'cam-2';
      final engine = FakeCameraEngine();
      tall(t);
      await t.pumpWidget(host(engine));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      await t.tap(find.text(l10n.desktopCameraPreviewShow));
      await t.pumpAndSettle();
      expect(engine.lastId, 'cam-2');
      expect(find.byKey(const ValueKey('preview-mirror-true')), findsOneWidget);
      expect(find.text(l10n.desktopCameraPreviewHide), findsOneWidget);

      await t.tap(find.byType(WorkspaceSwitch));
      await t.pumpAndSettle();
      expect(DesktopCallPrefs.mirrorSelfView.value, isFalse);
      expect(find.byKey(const ValueKey('preview-mirror-false')), findsOneWidget);

      // Выбрали другую камеру — превью идёт за ней.
      await t.tap(find.text('FaceTime HD'));
      await t.pumpAndSettle();
      expect(engine.lastId, 'cam-1');

      await t.tap(find.text(l10n.desktopCameraPreviewHide));
      await t.pumpAndSettle();
      expect(engine.on, isFalse);
    });

    testWidgets('начался звонок — камера погасла', (t) async {
      final engine = FakeCameraEngine();
      final busy = ValueNotifier<bool>(false);
      tall(t);
      await t.pumpWidget(host(engine, busy: busy));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      await t.tap(find.text(l10n.desktopCameraPreviewShow));
      await t.pumpAndSettle();
      expect(engine.on, isTrue);
      busy.value = true;
      await t.pumpAndSettle();
      expect(engine.on, isFalse);
      expect(find.text(l10n.desktopMediaBusyInCall), findsWidgets);
    });

    testWidgets('ушёл из раздела — камера погасла', (t) async {
      final engine = FakeCameraEngine();
      tall(t);
      await t.pumpWidget(host(engine));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      await t.tap(find.text(l10n.desktopCameraPreviewShow));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      expect(engine.on, isFalse);
      expect(engine.disposed, isTrue);
    });

    testWidgets('камер нет — «Показать» не предлагаем, зеркало остаётся', (t) async {
      final engine = FakeCameraEngine();
      tall(t);
      await t.pumpWidget(host(engine, noCameras: true));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.desktopDevicesNoCameras), findsOneWidget);
      expect(find.text(l10n.desktopCameraPreview), findsNothing);
      expect(find.text(l10n.desktopCameraMirror), findsOneWidget);
    });

    testWidgets('камера не включилась — сказано и есть путь к доступу', (t) async {
      final engine = FakeCameraEngine()..fail = true;
      tall(t);
      await t.pumpWidget(host(engine));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      await t.tap(find.text(l10n.desktopCameraPreviewShow));
      await t.pumpAndSettle();
      expect(find.text(l10n.desktopCameraPreviewFailed), findsOneWidget);
      expect(find.text(l10n.desktopMediaOpenPrivacy), findsOneWidget);
      // Можно попробовать ещё раз.
      expect(find.text(l10n.desktopCameraPreviewShow), findsOneWidget);
    });

    testWidgets('зеркало есть и там, где превью нет', (t) async {
      final engine = FakeCameraEngine();
      tall(t);
      await t.pumpWidget(host(engine, platform: DesktopAudioPlatform.other));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.desktopCameraPreview), findsNothing);
      expect(find.text(l10n.desktopCameraMirror), findsOneWidget);
    });
  });
}
