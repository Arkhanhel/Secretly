// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// ГДЕ ЗВУЧАТ ПРОВЕРКИ ИЗ НАСТРОЕК ЗВОНКОВ: в ВЫБРАННЫХ динамиках.
///
/// 🔴 ЗАЧЕМ ТАК СЛОЖНО (30.09.2026). Проверка динамиков, которая играет «куда
/// придётся», хуже её отсутствия: человек выбрал наушники, нажал «Проверить»,
/// услышал звук из колонок и решил, что выбор работает. Проигрыватель
/// приложения (`just_audio`) устройство выбирать не умеет ни на одной
/// системе, а модуль звука звонков (`flutter_webrtc`) проигрывает только
/// собеседника. Поэтому у каждой системы свой путь:
///
///  * **Windows** — старый добрый waveOut: у каждого его устройства система
///    сообщает идентификатор конечной точки, тот самый, что звонки получают у
///    `flutter_webrtc` (`{0.0.0.00000000}.{GUID}`). Без нового кода раннера,
///    через `win32` (см. `desktop_wave_out.dart`).
///  * **macOS** — `AVAudioPlayer.currentDevice` в раннере
///    (`MainFlutterWindow.swift`, канал `secretly/audio_test`).
///  * не вышло ни то, ни другое — звучит в устройстве системы по умолчанию,
///    и интерфейс ГОВОРИТ об этом ([DesktopPlayback.targeted]), а не делает
///    вид, что проверил выбранное.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../../calls/call_log.dart';
import 'desktop_audio_pcm.dart';
import 'desktop_wave_out.dart';

/// На какой системе работают проверки звука.
enum DesktopAudioPlatform { windows, macos, other }

/// Подмена системы — для тестов обеих половин на любой машине сборки.
@visibleForTesting
DesktopAudioPlatform? debugDesktopAudioPlatformOverride;

DesktopAudioPlatform get currentDesktopAudioPlatform {
  final forced = debugDesktopAudioPlatformOverride;
  if (forced != null) return forced;
  if (kIsWeb) return DesktopAudioPlatform.other;
  if (Platform.isWindows) return DesktopAudioPlatform.windows;
  if (Platform.isMacOS) return DesktopAudioPlatform.macos;
  return DesktopAudioPlatform.other;
}

/// Идущее проигрывание.
class DesktopPlayback {
  DesktopPlayback({
    required this.targeted,
    required this.done,
    required void Function() cancel,
  }) : _cancel = cancel;

  /// Звук ушёл ИМЕННО в выбранное устройство. `false` — в устройство системы
  /// по умолчанию: выбранное не нашлось, или система не дала его выбрать.
  final bool targeted;

  /// Завершается, когда звук доиграл или его остановили.
  final Future<void> done;

  final void Function() _cancel;

  void cancel() => _cancel();
}

/// Проигрыватель проверок.
abstract class DesktopAudioOutput {
  /// Проиграть PCM 16 бит моно в устройство [outputDeviceId] — идентификатор
  /// из списка `flutter_webrtc`; пустой — «как в системе». [outputLabel] —
  /// имя устройства: по нему macOS находит его, если идентификатор другой
  /// формы. `null` — проиграть не удалось совсем.
  Future<DesktopPlayback?> play(
    Uint8List pcm, {
    required int sampleRate,
    required String outputDeviceId,
    String outputLabel = '',
  });

  Future<void> dispose();

  /// Проигрыватель своей системы.
  factory DesktopAudioOutput.forPlatform(DesktopAudioPlatform platform) =>
      switch (platform) {
        DesktopAudioPlatform.windows => WaveOutAudioOutput(
          api: createWin32WaveOutApi(),
        ),
        DesktopAudioPlatform.macos => MacAudioOutput(),
        DesktopAudioPlatform.other => FallbackAudioOutput(),
      };
}

// ── Windows ────────────────────────────────────────────────────────────────

/// То, что нужно от waveOut. Настоящая половина — `desktop_wave_out.dart`,
/// в тестах — подставная.
abstract class WaveOutApi {
  /// Идентификатор конечной точки у каждого устройства waveOut, по порядку
  /// номеров; `null` — система не ответила.
  List<String?> endpointIds();

  /// Какое устройство вывода Windows считает основным (роль «Консоль» — то,
  /// что человек видит у значка громкости). Тот же ответ, что берут звонки
  /// для «Как в системе».
  String? systemDefaultEndpointId();

  /// Начать проигрывание. `null` — устройство не открылось.
  WaveOutVoice? open({
    required int device,
    required Uint8List pcm,
    required int sampleRate,
  });
}

/// Одно открытое проигрывание waveOut.
abstract class WaveOutVoice {
  /// Буфер доигран.
  bool get done;

  /// Остановить (если ещё играет) и освободить устройство и память.
  void close();
}

/// «Устройство по умолчанию» waveOut (`WAVE_MAPPER`).
const int kWaveMapper = 0xFFFFFFFF;

/// Какое устройство waveOut открыть для [outputDeviceId]. Чистая функция.
///
/// «Как в системе» — основное устройство Windows, найденное по его
/// идентификатору: тот же выбор, что делают звонки. Не нашлось — `WAVE_MAPPER`,
/// то есть тоже устройство системы. Выбранное человеком не нашлось — тоже
/// `WAVE_MAPPER`, но уже с честным `targeted: false`.
({int device, bool targeted}) resolveWaveOutDevice({
  required List<String?> endpointIds,
  required String outputDeviceId,
  required String? systemDefaultId,
}) {
  int? indexOf(String id) {
    final want = id.trim().toLowerCase();
    if (want.isEmpty) return null;
    for (var i = 0; i < endpointIds.length; i++) {
      if ((endpointIds[i] ?? '').trim().toLowerCase() == want) return i;
    }
    return null;
  }

  final wanted = outputDeviceId.trim();
  if (wanted.isEmpty) {
    final i = indexOf(systemDefaultId ?? '');
    return (device: i ?? kWaveMapper, targeted: true);
  }
  final i = indexOf(wanted);
  return i == null
      ? (device: kWaveMapper, targeted: false)
      : (device: i, targeted: true);
}

/// Проигрыватель Windows поверх waveOut.
class WaveOutAudioOutput implements DesktopAudioOutput {
  WaveOutAudioOutput({
    required this.api,
    this.pollInterval = const Duration(milliseconds: 40),
    DesktopAudioOutput? fallback,
  }) : _fallback = fallback;

  final WaveOutApi api;
  final Duration pollInterval;
  DesktopAudioOutput? _fallback;

  WaveOutVoice? _voice;
  Timer? _poll;
  Completer<void>? _done;

  @override
  Future<DesktopPlayback?> play(
    Uint8List pcm, {
    required int sampleRate,
    required String outputDeviceId,
    String outputLabel = '',
  }) async {
    _finishCurrent();
    List<String?> ids;
    String? systemDefault;
    try {
      ids = api.endpointIds();
      systemDefault = outputDeviceId.trim().isEmpty
          ? api.systemDefaultEndpointId()
          : null;
    } catch (e) {
      callLog('DesktopAudioCheck', 'waveOut enumerate failed: $e');
      ids = const <String?>[];
    }
    var pick = resolveWaveOutDevice(
      endpointIds: ids,
      outputDeviceId: outputDeviceId,
      systemDefaultId: systemDefault,
    );
    var voice = _open(pick.device, pcm, sampleRate);
    if (voice == null && pick.device != kWaveMapper) {
      // Нашлось, но не открылось (занято в монопольном режиме, отключили
      // мгновение назад) — звучим в системном и говорим об этом.
      pick = (device: kWaveMapper, targeted: false);
      voice = _open(kWaveMapper, pcm, sampleRate);
    }
    if (voice == null) {
      final fallback = _fallback ??= FallbackAudioOutput();
      return fallback.play(
        pcm,
        sampleRate: sampleRate,
        outputDeviceId: outputDeviceId,
        outputLabel: outputLabel,
      );
    }
    final opened = voice;
    final done = Completer<void>();
    _voice = opened;
    _done = done;
    _poll = Timer.periodic(pollInterval, (_) {
      if (opened.done) _finish(opened);
    });
    return DesktopPlayback(
      targeted: pick.targeted,
      done: done.future,
      cancel: () => _finish(opened),
    );
  }

  WaveOutVoice? _open(int device, Uint8List pcm, int sampleRate) {
    try {
      return api.open(device: device, pcm: pcm, sampleRate: sampleRate);
    } catch (e) {
      callLog('DesktopAudioCheck', 'waveOut open failed device=$device: $e');
      return null;
    }
  }

  void _finish(WaveOutVoice voice) {
    if (!identical(voice, _voice)) return;
    _poll?.cancel();
    _poll = null;
    _voice = null;
    try {
      voice.close();
    } catch (_) {}
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  void _finishCurrent() {
    final voice = _voice;
    if (voice != null) _finish(voice);
  }

  @override
  Future<void> dispose() async {
    _finishCurrent();
    await _fallback?.dispose();
    _fallback = null;
  }
}

// ── macOS ──────────────────────────────────────────────────────────────────

/// Проигрыватель macOS: `AVAudioPlayer` в раннере с выбранным устройством.
class MacAudioOutput implements DesktopAudioOutput {
  MacAudioOutput({
    MethodChannel? channel,
    DesktopAudioOutput? fallback,
  }) : _channel = channel ?? const MethodChannel(kDesktopAudioTestChannel),
       _fallback = fallback;

  final MethodChannel _channel;
  DesktopAudioOutput? _fallback;

  Timer? _timer;
  Completer<void>? _done;

  @override
  Future<DesktopPlayback?> play(
    Uint8List pcm, {
    required int sampleRate,
    required String outputDeviceId,
    String outputLabel = '',
  }) async {
    _complete();
    Map<String, Object?>? reply;
    try {
      reply = await _channel.invokeMapMethod<String, Object?>('play', {
        'wav': pcm16MonoWav(pcm, sampleRate),
        'deviceId': outputDeviceId,
        'label': outputLabel,
      });
    } catch (e) {
      // Старый раннер без моста или сбой проигрывателя — звучим хотя бы в
      // системном, и интерфейс скажет, что это не выбранное устройство.
      callLog('DesktopAudioCheck', 'mac audio test failed: $e');
      reply = null;
    }
    if (reply == null) {
      final fallback = _fallback ??= FallbackAudioOutput();
      return fallback.play(
        pcm,
        sampleRate: sampleRate,
        outputDeviceId: outputDeviceId,
        outputLabel: outputLabel,
      );
    }
    final length = (reply['durationMs'] as num?)?.toInt() ??
        pcm16MonoDuration(pcm.length, sampleRate).inMilliseconds;
    final done = Completer<void>();
    _done = done;
    // Небольшой запас: звук кончается на стороне системы чуть позже, чем
    // посчитано, и «Проверить» не должна вернуться раньше тишины.
    _timer = Timer(Duration(milliseconds: length + 150), () {
      if (identical(_done, done)) _complete();
    });
    return DesktopPlayback(
      targeted: reply['targeted'] == true,
      done: done.future,
      cancel: () {
        if (!identical(_done, done)) return;
        unawaited(_stopNative());
        _complete();
      },
    );
  }

  Future<void> _stopNative() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  void _complete() {
    _timer?.cancel();
    _timer = null;
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  @override
  Future<void> dispose() async {
    if (_done != null) await _stopNative();
    _complete();
    await _fallback?.dispose();
    _fallback = null;
  }
}

/// Канал моста проверок звука в раннере macOS.
const String kDesktopAudioTestChannel = 'secretly/audio_test';

// ── Запасной путь ──────────────────────────────────────────────────────────

/// Проигрыватель приложения (`just_audio`) — всегда в устройство системы по
/// умолчанию. Честно: [DesktopPlayback.targeted] истинно, только когда
/// выбрано «Как в системе».
class FallbackAudioOutput implements DesktopAudioOutput {
  AudioPlayer? _player;
  File? _file;
  Completer<void>? _done;
  StreamSubscription<PlayerState>? _sub;

  @override
  Future<DesktopPlayback?> play(
    Uint8List pcm, {
    required int sampleRate,
    required String outputDeviceId,
    String outputLabel = '',
  }) async {
    await _release();
    try {
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'secretly-sound-check-${DateTime.now().microsecondsSinceEpoch}.wav',
      );
      await file.writeAsBytes(pcm16MonoWav(pcm, sampleRate), flush: true);
      _file = file;
      final player = _player = AudioPlayer();
      await player.setFilePath(file.path);
      final done = Completer<void>();
      _done = done;
      _sub = player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          unawaited(_release());
        }
      });
      unawaited(player.play());
      return DesktopPlayback(
        targeted: outputDeviceId.trim().isEmpty,
        done: done.future,
        cancel: () => unawaited(_release()),
      );
    } catch (e) {
      callLog('DesktopAudioCheck', 'fallback playback failed: $e');
      await _release();
      return null;
    }
  }

  Future<void> _release() async {
    await _sub?.cancel();
    _sub = null;
    final player = _player;
    _player = null;
    if (player != null) {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {}
    }
    final file = _file;
    _file = null;
    if (file != null) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  @override
  Future<void> dispose() => _release();
}

// ── «Проверить динамики» ───────────────────────────────────────────────────

/// Чем кончилась последняя проверка динамиков.
enum SpeakerCheckResult {
  /// Ещё не проверяли.
  none,

  /// Прозвучало в выбранном устройстве.
  targeted,

  /// Прозвучало в системном: выбранное открыть не удалось.
  systemOnly,

  /// Не прозвучало совсем.
  failed,
}

/// Проверочный сигнал в выбранных динамиках (ТЗ §1.4: «Проверить» — сигнал
/// на выбранное устройство).
class DesktopSpeakerCheck extends ChangeNotifier {
  DesktopSpeakerCheck({
    required DesktopAudioOutput output,
    Uint8List Function()? tone,
    this.sampleRate = kDesktopCheckSampleRate,
  }) : _output = output,
       _tone = tone ?? _defaultTone;

  final DesktopAudioOutput _output;
  final Uint8List Function() _tone;
  final int sampleRate;

  /// Сигнал один на все проверки: полторы секунды звука считаются раз.
  static Uint8List? _cachedTone;
  static Uint8List _defaultTone() => _cachedTone ??= buildSpeakerTestTone();

  DesktopPlayback? _playback;
  bool _starting = false;
  bool _disposed = false;

  bool get playing => _starting || _playback != null;

  SpeakerCheckResult _result = SpeakerCheckResult.none;
  SpeakerCheckResult get result => _result;

  /// Сыграть сигнал в устройство [outputId] ('' — «как в системе»).
  Future<void> play({required String outputId, String outputLabel = ''}) async {
    if (_disposed || playing) return;
    _starting = true;
    _result = SpeakerCheckResult.none;
    notifyListeners();
    final playback = await _output.play(
      _tone(),
      sampleRate: sampleRate,
      outputDeviceId: outputId,
      outputLabel: outputLabel,
    );
    _starting = false;
    if (_disposed) {
      playback?.cancel();
      return;
    }
    if (playback == null) {
      _result = SpeakerCheckResult.failed;
      notifyListeners();
      return;
    }
    _playback = playback;
    _result = playback.targeted
        ? SpeakerCheckResult.targeted
        : SpeakerCheckResult.systemOnly;
    notifyListeners();
    await playback.done;
    if (_disposed || !identical(_playback, playback)) return;
    _playback = null;
    notifyListeners();
  }

  /// Смолкнуть сейчас же: кнопка «Остановить», начался звонок, раздел ушёл
  /// с экрана.
  void stop() {
    final playback = _playback;
    _playback = null;
    playback?.cancel();
    if (playback != null && !_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final playback = _playback;
    _playback = null;
    playback?.cancel();
    super.dispose();
  }
}
