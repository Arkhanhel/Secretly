// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// «Проверить микрофон» и индикатор уровня (ТЗ «ПК как Telegram», §1.4).
//
// Выбрать микрофон было можно, а убедиться, что выбран тот, — нет: о немом
// микрофоне человек узнавал от собеседника, посреди звонка. Здесь стережётся:
//  * уровень считается из настоящих отсчётов и живёт в децибелах;
//  * разрешение само не спрашивается — только по кнопке;
//  * запись ровно 5 секунд и проигрывается в ВЫБРАННЫЕ динамики, а если это
//    невозможно — интерфейс говорит, где прозвучало;
//  * микрофон закрывается, когда раздел уходит с экрана или начинается
//    звонок;
//  * проигрыватель Windows (waveOut) и macOS (мост раннера) — обе половины,
//    на любой машине сборки.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:secretly_app/l10n/app_localizations.dart';
import 'package:secretly_app/ui/desktop/design/colors.dart';
import 'package:secretly_app/ui/desktop/services/desktop_audio_output.dart';
import 'package:secretly_app/ui/desktop/services/desktop_audio_pcm.dart';
import 'package:secretly_app/ui/desktop/services/desktop_mic_check.dart';
import 'package:secretly_app/ui/desktop/services/desktop_ui_prefs.dart';
import 'package:secretly_app/ui/desktop/workspace/media_check_rows.dart';
import 'package:secretly_app/ui/desktop/workspace/media_devices_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PCM 16 бит: [samples] отсчётов одного значения [value].
Uint8List pcm(int samples, int value) {
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    data.setInt16(i * 2, value, Endian.little);
  }
  return data.buffer.asUint8List();
}

class FakeMicCapture implements DesktopMicCapture {
  bool permission = true;
  bool grantOnRequest = true;
  bool failOpen = false;
  bool exact = true;
  int opens = 0;
  int closes = 0;
  int permissionRequests = 0;
  String? openedId;
  StreamController<Uint8List>? _ctrl;

  bool get isOpen => _ctrl != null;

  @override
  Future<bool> hasPermission({required bool request}) async {
    if (request) {
      permissionRequests++;
      if (grantOnRequest) permission = true;
    }
    return permission;
  }

  @override
  Future<DesktopMicStream> open({
    required String webrtcDeviceId,
    required String label,
    required int sampleRate,
  }) async {
    if (failOpen) throw StateError('device busy');
    opens++;
    openedId = webrtcDeviceId;
    final ctrl = _ctrl = StreamController<Uint8List>();
    return DesktopMicStream(pcm: ctrl.stream, exact: exact);
  }

  void push(Uint8List chunk) => _ctrl?.add(chunk);

  /// Система сама закрыла поток: микрофон выдернули или его забрали.
  Future<void> endFromSystem() async {
    final ctrl = _ctrl;
    _ctrl = null;
    await ctrl?.close();
  }

  @override
  Future<void> close() async {
    final ctrl = _ctrl;
    _ctrl = null;
    if (ctrl != null) {
      closes++;
      await ctrl.close();
    }
  }

  @override
  Future<void> dispose() => close();
}

class FakeOutput implements DesktopAudioOutput {
  final plays = <({Uint8List pcm, String outputId, String label})>[];
  bool targeted = true;
  bool fail = false;
  Completer<void>? done;
  int cancels = 0;

  @override
  Future<DesktopPlayback?> play(
    Uint8List pcm, {
    required int sampleRate,
    required String outputDeviceId,
    String outputLabel = '',
  }) async {
    if (fail) return null;
    plays.add((pcm: pcm, outputId: outputDeviceId, label: outputLabel));
    final d = done = Completer<void>();
    return DesktopPlayback(
      targeted: targeted,
      done: d.future,
      cancel: () {
        cancels++;
        if (!d.isCompleted) d.complete();
      },
    );
  }

  void finish() {
    final d = done;
    if (d != null && !d.isCompleted) d.complete();
  }

  @override
  Future<void> dispose() async {}
}

class FakeWaveOutApi implements WaveOutApi {
  FakeWaveOutApi(this.ids, {this.systemDefault});

  final List<String?> ids;
  final String? systemDefault;
  final Set<int> failing = <int>{};
  final opened = <int>[];
  final voices = <FakeVoice>[];

  @override
  List<String?> endpointIds() => ids;

  @override
  String? systemDefaultEndpointId() => systemDefault;

  @override
  WaveOutVoice? open({
    required int device,
    required Uint8List pcm,
    required int sampleRate,
  }) {
    opened.add(device);
    if (failing.contains(device)) return null;
    final v = FakeVoice();
    voices.add(v);
    return v;
  }
}

class FakeVoice implements WaveOutVoice {
  bool finished = false;
  int closes = 0;

  @override
  bool get done => finished;

  @override
  void close() => closes++;
}

void main() {
  group('звук проверок — чистые функции', () {
    test('пик: тишина, половина и предел', () {
      expect(pcm16Peak(pcm(100, 0)), 0);
      expect(pcm16Peak(pcm(100, 16384)), closeTo(0.5, 0.001));
      expect(pcm16Peak(pcm(100, -32768)), 1);
      expect(pcm16Peak(Uint8List(0)), 0);
      expect(pcm16Peak(Uint8List(1)), 0, reason: 'битый кусок — тишина');
    });

    test('🔴 шкала в децибелах: обычная речь двигает полоску заметно', () {
      expect(levelFromPeak(0), 0);
      expect(levelFromPeak(1), 1);
      expect(
        levelFromPeak(0.001),
        closeTo(0, 1e-9),
        reason: '−60 дБ — тишина комнаты',
      );
      // −30 дБ (3 % от предела) — середина полоски. В линейной шкале это
      // были бы те самые 3 %, и индикатор казался бы мёртвым.
      expect(levelFromPeak(math.pow(10, -30 / 20).toDouble()), closeTo(0.5, 0.01));
      expect(levelFromPeak(double.nan), 0);
    });

    test('вверх — сразу, вниз — плавно', () {
      expect(smoothLevel(0.2, 0.9), 0.9);
      expect(smoothLevel(0.9, 0.0), closeTo(0.72, 0.001));
      expect(smoothLevel(0.5, double.nan), 0);
    });

    test('5 секунд при 48 кГц — ровно столько байт и обратно', () {
      final bytes = pcm16MonoBytes(const Duration(seconds: 5), 48000);
      expect(bytes, 480000);
      expect(pcm16MonoDuration(bytes, 48000), const Duration(seconds: 5));
    });

    test('WAV: заголовок PCM 16 бит моно', () {
      final wav = pcm16MonoWav(pcm(10, 1), 48000);
      final h = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(h.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(h.getUint16(22, Endian.little), 1, reason: 'моно');
      expect(h.getUint32(24, Endian.little), 48000);
      expect(h.getUint16(34, Endian.little), 16);
      expect(h.getUint32(40, Endian.little), 20);
      expect(wav.length, 44 + 20);
    });
  });

  group('какое устройство записи — выбранный микрофон', () {
    const windows = [
      (id: '{0.0.1.00000000}.{aaaa}', label: 'Микрофон (Realtek(R) Audio)'),
      (id: '{0.0.1.00000000}.{bbbb}', label: 'Гарнитура (WH-1000XM4)'),
    ];

    test('Windows: идентификатор конечной точки совпадает', () {
      final m = resolveRecorderInput(
        candidates: windows,
        webrtcDeviceId: '{0.0.1.00000000}.{BBBB}',
        label: '',
      );
      expect(m?.id, '{0.0.1.00000000}.{bbbb}');
    });

    test('другая форма идентификатора — находим по имени', () {
      final m = resolveRecorderInput(
        candidates: const [(id: 'BuiltInMicrophoneDevice', label: 'MacBook Pro Microphone')],
        webrtcDeviceId: '73',
        label: 'MacBook Pro Microphone',
      );
      expect(m?.id, 'BuiltInMicrophoneDevice');
    });

    test('не нашли или «как в системе» — микрофон системы', () {
      expect(
        resolveRecorderInput(candidates: windows, webrtcDeviceId: 'x', label: 'y'),
        isNull,
      );
      expect(
        resolveRecorderInput(candidates: windows, webrtcDeviceId: '', label: ''),
        isNull,
      );
    });
  });

  group('Windows: waveOut в выбранное устройство', () {
    const ids = <String?>['{0.0.0.00000000}.{hdmi}', null, '{0.0.0.00000000}.{phones}'];

    test('выбранное найдено — его номер', () {
      final r = resolveWaveOutDevice(
        endpointIds: ids,
        outputDeviceId: '{0.0.0.00000000}.{PHONES}',
        systemDefaultId: null,
      );
      expect(r.device, 2);
      expect(r.targeted, isTrue);
    });

    test('🔴 «Как в системе» — основное устройство Windows, как в звонке', () {
      final r = resolveWaveOutDevice(
        endpointIds: ids,
        outputDeviceId: '',
        systemDefaultId: '{0.0.0.00000000}.{phones}',
      );
      expect(r.device, 2);
      expect(r.targeted, isTrue);
      final unknown = resolveWaveOutDevice(
        endpointIds: ids,
        outputDeviceId: '',
        systemDefaultId: null,
      );
      expect(unknown.device, kWaveMapper);
      expect(unknown.targeted, isTrue, reason: 'WAVE_MAPPER и есть системное');
    });

    test('🔴 выбранного нет — системное, и честно «не то»', () {
      final r = resolveWaveOutDevice(
        endpointIds: ids,
        outputDeviceId: '{0.0.0.00000000}.{gone}',
        systemDefaultId: null,
      );
      expect(r.device, kWaveMapper);
      expect(r.targeted, isFalse);
    });

    test('проигрывание: открывает выбранное, ждёт конца, освобождает', () async {
      final api = FakeWaveOutApi(ids);
      final out = WaveOutAudioOutput(
        api: api,
        pollInterval: const Duration(milliseconds: 1),
      );
      final pb = await out.play(
        pcm(480, 100),
        sampleRate: 48000,
        outputDeviceId: '{0.0.0.00000000}.{phones}',
      );
      expect(pb, isNotNull);
      expect(pb!.targeted, isTrue);
      expect(api.opened, [2]);
      var finished = false;
      unawaited(pb.done.then((_) => finished = true));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(finished, isFalse);
      api.voices.single.finished = true;
      await pb.done.timeout(const Duration(seconds: 2));
      expect(api.voices.single.closes, 1);
      await out.dispose();
    });

    test('выбранное не открылось — системное, targeted = false', () async {
      final api = FakeWaveOutApi(ids)..failing.add(2);
      final out = WaveOutAudioOutput(
        api: api,
        pollInterval: const Duration(milliseconds: 1),
      );
      final pb = await out.play(
        pcm(480, 100),
        sampleRate: 48000,
        outputDeviceId: '{0.0.0.00000000}.{phones}',
      );
      expect(api.opened, [2, kWaveMapper]);
      expect(pb!.targeted, isFalse);
      pb.cancel();
      await pb.done.timeout(const Duration(seconds: 2));
      expect(api.voices.single.closes, 1);
      await out.dispose();
    });
  });

  group('macOS: мост раннера', () {
    const channel = MethodChannel(kDesktopAudioTestChannel);
    TestWidgetsFlutterBinding.ensureInitialized();

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('передаёт WAV, устройство и имя; «куда» берёт из ответа', () async {
      MethodCall? seen;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'play') {
          seen = call;
          return <String, Object?>{'targeted': false, 'durationMs': 20};
        }
        return null;
      });
      final out = MacAudioOutput();
      final pb = await out.play(
        pcm(960, 5),
        sampleRate: 48000,
        outputDeviceId: 'AppleUSBAudioEngine:1',
        outputLabel: 'USB Speakers',
      );
      final args = (seen!.arguments as Map).cast<String, Object?>();
      expect(args['deviceId'], 'AppleUSBAudioEngine:1');
      expect(args['label'], 'USB Speakers');
      final wav = args['wav']! as Uint8List;
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(pb!.targeted, isFalse);
      await pb.done.timeout(const Duration(seconds: 2));
      await out.dispose();
    });

    test('🔴 старый раннер без моста — запасной путь, а не тишина', () async {
      // Обработчика нет: MissingPluginException.
      final fallback = FakeOutput()..targeted = false;
      final out = MacAudioOutput(fallback: fallback);
      final pb = await out.play(
        pcm(10, 5),
        sampleRate: 48000,
        outputDeviceId: 'x',
      );
      expect(fallback.plays, hasLength(1));
      expect(pb!.targeted, isFalse);
      pb.cancel();
    });

    test('«Открыть настройки» — страница доступа своей системы', () {
      expect(
        systemPrivacySettingsUrl(
          DesktopAudioPlatform.windows,
          SystemPrivacyPane.microphone,
        ),
        'ms-settings:privacy-microphone',
      );
      expect(
        systemPrivacySettingsUrl(
          DesktopAudioPlatform.windows,
          SystemPrivacyPane.camera,
        ),
        'ms-settings:privacy-webcam',
      );
      expect(
        systemPrivacySettingsUrl(
          DesktopAudioPlatform.macos,
          SystemPrivacyPane.microphone,
        ),
        'x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone',
      );
      expect(
        systemPrivacySettingsUrl(
          DesktopAudioPlatform.macos,
          SystemPrivacyPane.camera,
        ),
        'x-apple.systempreferences:com.apple.preference.security?Privacy_Camera',
      );
      expect(
        systemPrivacySettingsUrl(
          DesktopAudioPlatform.other,
          SystemPrivacyPane.camera,
        ),
        isNull,
      );
    });

    test('система решает сама: платформу можно подменить', () {
      debugDesktopAudioPlatformOverride = DesktopAudioPlatform.windows;
      expect(currentDesktopAudioPlatform, DesktopAudioPlatform.windows);
      expect(
        DesktopAudioOutput.forPlatform(DesktopAudioPlatform.windows),
        isA<WaveOutAudioOutput>(),
      );
      debugDesktopAudioPlatformOverride = DesktopAudioPlatform.macos;
      expect(
        DesktopAudioOutput.forPlatform(currentDesktopAudioPlatform),
        isA<MacAudioOutput>(),
      );
      debugDesktopAudioPlatformOverride = null;
    });
  });

  group('DesktopMicCheck', () {
    DesktopMicCheck make(FakeMicCapture cap, FakeOutput out) => DesktopMicCheck(
      capture: cap,
      output: out,
      sampleRate: 1000,
      testLength: const Duration(seconds: 2),
      levelInterval: Duration.zero,
    );

    test('🔴 без разрешения — не спрашивает сам, ждёт кнопку', () async {
      final cap = FakeMicCapture()..permission = false;
      final check = make(cap, FakeOutput());
      await check.start(micId: '');
      expect(check.status, MicCheckStatus.needsPermission);
      expect(cap.permissionRequests, 0);
      expect(cap.opens, 0);
      await check.requestPermission();
      expect(cap.permissionRequests, 1);
      expect(check.status, MicCheckStatus.live);
      check.dispose();
    });

    test('отказали — «откройте настройки системы»', () async {
      final cap = FakeMicCapture()
        ..permission = false
        ..grantOnRequest = false;
      final check = make(cap, FakeOutput());
      await check.requestPermission();
      expect(check.status, MicCheckStatus.denied);
      check.dispose();
    });

    test('микрофон занят — «не удалось открыть»', () async {
      final cap = FakeMicCapture()..failOpen = true;
      final check = make(cap, FakeOutput());
      await check.start(micId: 'm1');
      expect(check.status, MicCheckStatus.failed);
      check.dispose();
    });

    test('полоска живая: голос двигает, тишина опускает', () async {
      final cap = FakeMicCapture();
      final check = make(cap, FakeOutput());
      await check.start(micId: 'm1', micLabel: 'USB');
      expect(cap.openedId, 'm1');
      cap.push(pcm(100, 8000));
      await Future<void>.delayed(Duration.zero);
      expect(check.level.value, greaterThan(0.6));
      for (var i = 0; i < 30; i++) {
        cap.push(pcm(100, 0));
      }
      await Future<void>.delayed(Duration.zero);
      expect(check.level.value, lessThan(0.01));
      check.dispose();
    });

    test('🔴 микрофон выдернули — не застывшая полоска, а «не удалось»', () async {
      final cap = FakeMicCapture();
      final check = make(cap, FakeOutput());
      await check.start(micId: 'm1');
      cap.push(pcm(100, 8000));
      await Future<void>.delayed(Duration.zero);
      await cap.endFromSystem();
      await Future<void>.delayed(Duration.zero);
      expect(check.status, MicCheckStatus.failed);
      expect(check.level.value, 0);
      check.dispose();
    });

    test('выбранный не открылся отдельно — об этом сказано', () async {
      final cap = FakeMicCapture()..exact = false;
      final check = make(cap, FakeOutput());
      await check.start(micId: 'm1');
      expect(check.micExact, isFalse);
      check.dispose();
    });

    test('🔴 запись ровно заданной длины и проигрывание в выбранные динамики', () {
      fakeAsync((async) {
        final cap = FakeMicCapture();
        final out = FakeOutput()..targeted = false;
        final check = make(cap, out);
        unawaited(check.start(micId: 'm1'));
        async.flushMicrotasks();
        expect(check.status, MicCheckStatus.live);
        unawaited(check.runTest(outputId: 'spk', outputLabel: 'Наушники'));
        async.flushMicrotasks();
        expect(check.phase, MicTestPhase.recording);
        expect(check.secondsLeft, 2);
        // 3 секунды звука при 1000 Гц — больше, чем длина проверки.
        for (var i = 0; i < 30; i++) {
          cap.push(pcm(100, 1000));
        }
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        expect(check.secondsLeft, 1);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(check.phase, MicTestPhase.playing);
        expect(out.plays, hasLength(1));
        expect(out.plays.single.pcm.length, 4000, reason: '2 с × 1000 Гц × 2 байта');
        expect(out.plays.single.outputId, 'spk');
        expect(out.plays.single.label, 'Наушники');
        expect(check.playbackTargeted, isFalse);
        out.finish();
        async.flushMicrotasks();
        expect(check.phase, MicTestPhase.idle);
        // Индикатор после проверки жив: микрофон тот же, не переоткрывался.
        expect(cap.opens, 1);
        expect(cap.isOpen, isTrue);
        check.dispose();
        async.flushMicrotasks();
      });
    });

    test('«Остановить» во время записи — запись выброшена, ничего не звучит', () {
      fakeAsync((async) {
        final cap = FakeMicCapture();
        final out = FakeOutput();
        final check = make(cap, out);
        unawaited(check.start(micId: ''));
        async.flushMicrotasks();
        unawaited(check.runTest(outputId: ''));
        async.flushMicrotasks();
        cap.push(pcm(100, 1000));
        check.cancelTest();
        expect(check.phase, MicTestPhase.idle);
        async.elapse(const Duration(seconds: 5));
        expect(out.plays, isEmpty);
        check.dispose();
        async.flushMicrotasks();
      });
    });

    test('проиграть не удалось — так и сказано', () {
      fakeAsync((async) {
        final cap = FakeMicCapture();
        final out = FakeOutput()..fail = true;
        final check = make(cap, out);
        unawaited(check.start(micId: ''));
        async.flushMicrotasks();
        unawaited(check.runTest(outputId: ''));
        async.flushMicrotasks();
        cap.push(pcm(100, 1000));
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(check.phase, MicTestPhase.idle);
        expect(check.playbackFailed, isTrue);
        check.dispose();
        async.flushMicrotasks();
      });
    });

    test('🔴 выключили — микрофон закрыт, полоска на нуле', () async {
      final cap = FakeMicCapture();
      final check = make(cap, FakeOutput());
      await check.start(micId: 'm1');
      cap.push(pcm(100, 8000));
      await Future<void>.delayed(Duration.zero);
      await check.stop();
      expect(cap.isOpen, isFalse);
      expect(check.status, MicCheckStatus.off);
      expect(check.level.value, 0);
      check.dispose();
    });
  });

  group('раздел: строки микрофона', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DesktopUiPrefs.resetForTest();
    });

    Widget host({
      required MediaCheckServices checks,
    }) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: MediaDevicesPane(
            enumerate: () async => [
              MediaDeviceInfo(deviceId: 'm1', label: 'USB Mic', kind: 'audioinput'),
              MediaDeviceInfo(deviceId: 'o1', label: 'Наушники', kind: 'audiooutput'),
            ],
            checks: checks,
            body: (children) => ListView(children: children),
          ),
        ),
      ),
    );

    testWidgets('🔴 звонок начался — микрофон отпущен; кончился — снова слушает', (t) async {
      final cap = FakeMicCapture();
      final busy = ValueNotifier<bool>(false);
      await t.pumpWidget(host(
        checks: MediaCheckServices(
          platform: DesktopAudioPlatform.macos,
          micCapture: () => cap,
          audioOutput: FakeOutput.new,
          callActive: busy,
        ),
      ));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.desktopMicLevel), findsOneWidget);
      expect(find.byType(MicLevelMeter), findsOneWidget);
      expect(cap.isOpen, isTrue);

      busy.value = true;
      await t.pumpAndSettle();
      expect(cap.isOpen, isFalse);
      // Уровень, проверка записи и сигнал динамиков — все молчат. (Камер в
      // этом списке нет, поэтому строки превью нет вовсе.)
      expect(find.text(l10n.desktopMediaBusyInCall), findsNWidgets(3));

      busy.value = false;
      await t.pumpAndSettle();
      expect(cap.isOpen, isTrue);
      expect(cap.opens, 2);

      // Раздел закрыли — микрофон отпущен вместе с ним.
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      expect(cap.isOpen, isFalse);
    });

    testWidgets('окно спрятано (TickerMode выключен) — микрофон отпущен', (t) async {
      final cap = FakeMicCapture();
      final visible = ValueNotifier<bool>(true);
      await t.pumpWidget(ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (ctx, v, _) => TickerMode(
          enabled: v,
          child: host(
            checks: MediaCheckServices(
              platform: DesktopAudioPlatform.windows,
              micCapture: () => cap,
              audioOutput: FakeOutput.new,
              callActive: ValueNotifier<bool>(false),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      expect(cap.isOpen, isTrue);
      visible.value = false;
      await t.pump();
      await t.pump();
      expect(cap.isOpen, isFalse);
      visible.value = true;
      await t.pumpAndSettle();
      expect(cap.isOpen, isTrue);
    });

    testWidgets('без разрешения — кнопка «Разрешить», сами не спрашиваем', (t) async {
      final cap = FakeMicCapture()..permission = false;
      await t.pumpWidget(host(
        checks: MediaCheckServices(
          platform: DesktopAudioPlatform.macos,
          micCapture: () => cap,
          audioOutput: FakeOutput.new,
          callActive: ValueNotifier<bool>(false),
        ),
      ));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.desktopMicNeedsAccess), findsOneWidget);
      expect(cap.permissionRequests, 0);
      await t.tap(find.text(l10n.desktopMicAllow));
      await t.pumpAndSettle();
      expect(cap.permissionRequests, 1);
      expect(find.byType(MicLevelMeter), findsOneWidget);
    });

    testWidgets('🔴 на других системах строк проверки нет вовсе', (t) async {
      await t.pumpWidget(host(
        checks: MediaCheckServices(
          platform: DesktopAudioPlatform.other,
          micCapture: FakeMicCapture.new,
          audioOutput: FakeOutput.new,
          callActive: ValueNotifier<bool>(false),
        ),
      ));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.desktopMicLevel), findsNothing);
      expect(find.text(l10n.desktopMicTest), findsNothing);
    });

    testWidgets('проверка записи: «Проверить» → запись со счётом → проигрывание', (t) async {
      final cap = FakeMicCapture();
      final out = FakeOutput();
      await t.pumpWidget(host(
        checks: MediaCheckServices(
          platform: DesktopAudioPlatform.windows,
          micCapture: () => cap,
          audioOutput: () => out,
          callActive: ValueNotifier<bool>(false),
        ),
      ));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      // Последняя «Проверить» — у микрофона (первая — у динамиков).
      await t.tap(find.text(l10n.desktopMediaCheck).last);
      await t.pump();
      expect(find.text(l10n.desktopMicTestRecording(5)), findsOneWidget);
      expect(find.text(l10n.desktopMediaCheckStop), findsOneWidget);
      cap.push(pcm(4800, 500));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.desktopMicTestRecording(4)), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
      await t.pump();
      expect(find.text(l10n.desktopMicTestPlaying), findsOneWidget);
      // Запись звучит в выбранных (здесь — «как в системе») динамиках.
      expect(out.plays.single.outputId, '');
      out.finish();
      await t.pumpAndSettle();
      expect(find.text(l10n.desktopMicTestHint), findsOneWidget);
    });
  });

  // ── «Проверить динамики» ─────────────────────────────────────────────────
  //
  // 🔴 Проверка, которая звучит «куда придётся», хуже её отсутствия: человек
  // выбрал наушники, услышал колонки и решил, что выбор работает. Сигнал идёт
  // в ВЫБРАННОЕ устройство, а если это невозможно — строка говорит, где он
  // прозвучал.

  group('проверочный сигнал', () {
    test('полторы секунды, не громче −6 дБ, без щелчков по краям', () {
      final tone = buildSpeakerTestTone(sampleRate: 48000);
      expect(tone.length, 48000 * 3, reason: '1,5 с × 48 кГц × 2 байта');
      expect(pcm16Peak(tone), lessThanOrEqualTo(0.51));
      expect(pcm16Peak(tone), greaterThan(0.3), reason: 'сигнал слышен');
      expect(pcm16Peak(Uint8List.sublistView(tone, 0, 20)), lessThan(0.05));
      expect(
        pcm16Peak(Uint8List.sublistView(tone, tone.length - 20)),
        lessThan(0.01),
      );
    });
  });

  group('DesktopSpeakerCheck', () {
    test('звучит в выбранном устройстве и говорит, куда прозвучало', () async {
      final out = FakeOutput();
      final check = DesktopSpeakerCheck(output: out, tone: () => pcm(10, 1));
      unawaited(check.play(outputId: 'spk', outputLabel: 'Наушники'));
      await Future<void>.delayed(Duration.zero);
      expect(check.playing, isTrue);
      expect(out.plays.single.outputId, 'spk');
      expect(out.plays.single.label, 'Наушники');
      expect(check.result, SpeakerCheckResult.targeted);
      out.finish();
      await Future<void>.delayed(Duration.zero);
      expect(check.playing, isFalse);
      check.dispose();
    });

    test('🔴 выбранное не открылось — «прозвучало в системном»', () async {
      final out = FakeOutput()..targeted = false;
      final check = DesktopSpeakerCheck(output: out, tone: () => pcm(10, 1));
      unawaited(check.play(outputId: 'gone'));
      await Future<void>.delayed(Duration.zero);
      expect(check.result, SpeakerCheckResult.systemOnly);
      check.stop();
      expect(out.cancels, 1);
      expect(check.playing, isFalse);
      check.dispose();
    });

    test('не прозвучало совсем — так и сказано', () async {
      final out = FakeOutput()..fail = true;
      final check = DesktopSpeakerCheck(output: out, tone: () => pcm(10, 1));
      await check.play(outputId: '');
      expect(check.result, SpeakerCheckResult.failed);
      expect(check.playing, isFalse);
      check.dispose();
    });
  });

  group('раздел: строка динамиков', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DesktopUiPrefs.resetForTest();
    });

    Widget host(MediaCheckServices checks) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DColors(
        colors: kDColorsDark,
        child: Scaffold(
          body: MediaDevicesPane(
            enumerate: () async => [
              MediaDeviceInfo(deviceId: 'm1', label: 'USB Mic', kind: 'audioinput'),
              MediaDeviceInfo(deviceId: 'o1', label: 'Колонки', kind: 'audiooutput'),
              MediaDeviceInfo(deviceId: 'o2', label: 'Наушники', kind: 'audiooutput'),
            ],
            checks: checks,
            body: (children) => ListView(children: children),
          ),
        ),
      ),
    );

    testWidgets('🔴 «Проверить» звучит в выбранных динамиках', (t) async {
      DesktopUiPrefs.preferredSpeakerId.value = 'o2';
      final out = FakeOutput()..targeted = false;
      await t.pumpWidget(host(MediaCheckServices(
        platform: DesktopAudioPlatform.windows,
        micCapture: FakeMicCapture.new,
        audioOutput: () => out,
        callActive: ValueNotifier<bool>(false),
      )));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.desktopSpeakerTest), findsOneWidget);
      // Первая «Проверить» — у динамиков: их карточка первая.
      await t.tap(find.text(l10n.desktopMediaCheck).first);
      await t.pump();
      expect(out.plays.single.outputId, 'o2');
      expect(out.plays.single.label, 'Наушники');
      expect(find.text(l10n.desktopSpeakerTestPlaying), findsOneWidget);
      out.finish();
      await t.pumpAndSettle();
      // Прозвучало не там — сказано прямо.
      expect(find.text(l10n.desktopMediaPlaybackSystemOnly), findsOneWidget);
    });

    testWidgets('выбранные отключены — проверяем «как в системе»', (t) async {
      DesktopUiPrefs.preferredSpeakerId.value = 'o-gone';
      final out = FakeOutput();
      await t.pumpWidget(host(MediaCheckServices(
        platform: DesktopAudioPlatform.macos,
        micCapture: FakeMicCapture.new,
        audioOutput: () => out,
        callActive: ValueNotifier<bool>(false),
      )));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      await t.tap(find.text(l10n.desktopMediaCheck).first);
      await t.pump();
      expect(out.plays.single.outputId, '');
      out.finish();
      await t.pumpAndSettle();
    });

    testWidgets('идёт звонок — сигнал не играет', (t) async {
      final out = FakeOutput();
      await t.pumpWidget(host(MediaCheckServices(
        platform: DesktopAudioPlatform.windows,
        micCapture: FakeMicCapture.new,
        audioOutput: () => out,
        callActive: ValueNotifier<bool>(true),
      )));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      await t.tap(find.text(l10n.desktopMediaCheck).first);
      await t.pump();
      expect(out.plays, isEmpty);
    });

    testWidgets('пока пишется проверка микрофона — сигнал ждёт', (t) async {
      final out = FakeOutput();
      await t.pumpWidget(host(MediaCheckServices(
        platform: DesktopAudioPlatform.windows,
        micCapture: FakeMicCapture.new,
        audioOutput: () => out,
        callActive: ValueNotifier<bool>(false),
      )));
      await t.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      // Вторая «Проверить» — у микрофона.
      await t.tap(find.text(l10n.desktopMediaCheck).last);
      await t.pump();
      expect(find.text(l10n.desktopMicTestRecording(5)), findsOneWidget);
      await t.tap(find.text(l10n.desktopMediaCheck).first);
      await t.pump();
      expect(out.plays, isEmpty, reason: 'сигнал попал бы в запись');
      await t.tap(find.text(l10n.desktopMediaCheckStop));
      await t.pumpAndSettle();
    });
  });
}
