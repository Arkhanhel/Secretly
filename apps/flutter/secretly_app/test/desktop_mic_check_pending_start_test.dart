// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// 🔴 Проверка микрофона оставалась включённой в спрятанном окне (30.09.2026).
//
// Раздел «Звук и видео» включает индикатор микрофона сразу при открытии.
// Пока система отвечает (разрешение, открытие устройства — доли секунды),
// статус проверки ещё «выключен», а раздел гасил микрофон, только если
// статус НЕ «выключен». Окно, спрятанное в эту долю секунды, оставляло
// микрофон открытым.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_audio_output.dart';
import 'package:secretly_app/ui/desktop/services/desktop_mic_check.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/workspace/media_check_rows.dart';
import 'package:secretly_app/ui/desktop/workspace/media_devices_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Микрофон, который открывается только по команде теста.
class _GatedCapture implements DesktopMicCapture {
  Completer<void> gate = Completer<void>();
  StreamController<Uint8List>? _ctrl;
  int opens = 0;
  int closes = 0;

  bool get isOpen => _ctrl != null;

  @override
  Future<bool> hasPermission({required bool request}) async => true;

  @override
  Future<DesktopMicStream> open({
    required String webrtcDeviceId,
    required String label,
    required int sampleRate,
  }) async {
    await gate.future;
    opens++;
    final ctrl = _ctrl = StreamController<Uint8List>();
    return DesktopMicStream(pcm: ctrl.stream, exact: true);
  }

  @override
  Future<void> close() async {
    closes++;
    final ctrl = _ctrl;
    _ctrl = null;
    // Не ждём: у потока, который никто не слушал, `close()` не кончается.
    unawaited(ctrl?.close());
  }

  @override
  Future<void> dispose() => close();
}

class _SilentOutput implements DesktopAudioOutput {
  @override
  Future<DesktopPlayback?> play(
    Uint8List pcm, {
    required int sampleRate,
    required String outputDeviceId,
    String outputLabel = '',
  }) async => null;

  @override
  Future<void> dispose() async {}
}

void main() {
  group('DesktopMicCheck.stop', () {
    test('🔴 отменяет включение, которое ещё ждёт систему', () async {
      final cap = _GatedCapture();
      final check = DesktopMicCheck(capture: cap, output: _SilentOutput());
      final starting = check.start(micId: '');
      await pumpEventQueue();
      expect(check.status, MicCheckStatus.off, reason: 'ещё открывается');

      await check.stop();
      cap.gate.complete();
      await starting;
      await pumpEventQueue();

      expect(cap.opens, 1);
      expect(cap.isOpen, isFalse, reason: 'открылся — и сразу закрыт');
      expect(check.status, MicCheckStatus.off);
      check.dispose();
    });

    test('выключенному повторный вызов ничего не делает', () async {
      final cap = _GatedCapture();
      final check = DesktopMicCheck(capture: cap, output: _SilentOutput());
      var notified = 0;
      check.addListener(() => notified++);
      await check.stop();
      await check.stop();
      expect(notified, 0);
      expect(cap.closes, 0, reason: 'к системе лишний раз не ходим');
      check.dispose();
    });

    test('включённый — выключает, как раньше', () async {
      final cap = _GatedCapture()..gate.complete();
      final check = DesktopMicCheck(capture: cap, output: _SilentOutput());
      await check.start(micId: '');
      expect(check.status, MicCheckStatus.live);
      await check.stop();
      expect(cap.isOpen, isFalse);
      expect(check.status, MicCheckStatus.off);
      check.dispose();
    });
  });

  testWidgets('🔴 окно спрятали, пока микрофон открывался, — он закрыт', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    DesktopUiPrefs.resetForTest();
    final cap = _GatedCapture();
    final visible = ValueNotifier<bool>(true);
    await t.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (ctx, v, _) => TickerMode(
          enabled: v,
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DColors(
              colors: kDColorsDark,
              child: Scaffold(
                body: MediaDevicesPane(
                  enumerate: () async => [
                    MediaDeviceInfo(
                      deviceId: 'm1',
                      label: 'USB Mic',
                      kind: 'audioinput',
                    ),
                  ],
                  checks: MediaCheckServices(
                    platform: DesktopAudioPlatform.macos,
                    micCapture: () => cap,
                    audioOutput: _SilentOutput.new,
                    callActive: ValueNotifier<bool>(false),
                  ),
                  body: (children) => ListView(children: children),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Список устройств пришёл — включение ушло к системе и ждёт.
    await t.pump();
    await t.pump();
    expect(cap.opens, 0);

    visible.value = false;
    await t.pump();
    cap.gate.complete();
    await t.pump();
    await t.pump();

    expect(cap.opens, 1);
    expect(cap.isOpen, isFalse, reason: 'спрятанное окно не слушает');

    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
}
