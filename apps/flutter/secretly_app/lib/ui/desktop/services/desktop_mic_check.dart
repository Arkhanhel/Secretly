// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// ПРОВЕРКА МИКРОФОНА В НАСТРОЙКАХ ЗВОНКОВ: индикатор уровня и «записать
/// 5 секунд — проиграть».
///
/// 🔴 ЗАЧЕМ (ТЗ «ПК как Telegram», §1.4). Выбрать микрофон было можно, а
/// убедиться, что выбран тот, — нет: человек узнавал о немом микрофоне от
/// собеседника, посреди звонка. Индикатор отвечает на «слышит ли меня
/// компьютер», запись — на «как меня слышно».
///
/// Микрофон читает пакет `record` (он уже пишет голосовые сообщения ПК на
/// обеих системах). Модуль звука звонков для этого не годится: он общий на
/// процесс, и проверка переключала бы микрофон идущего звонка.
///
/// 🔴 ЧТО ОБЕЩАЕМ ЧЕЛОВЕКУ И ДЕРЖИМ:
///  * микрофон открыт, только пока раздел на экране (окно спрятано, раздел
///    закрыт, начался звонок — закрываем);
///  * разрешение на микрофон отсюда само не спрашивается: открыть настройки
///    не значит согласиться на системный запрос — только по кнопке;
///  * звук никуда не уходит и не сохраняется: запись живёт в памяти до конца
///    проигрывания.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../../calls/call_log.dart';
import 'desktop_audio_output.dart';
import 'desktop_audio_pcm.dart';

/// Открытый микрофон: поток PCM 16 бит моно.
class DesktopMicStream {
  const DesktopMicStream({required this.pcm, required this.exact});

  final Stream<Uint8List> pcm;

  /// Открыт именно выбранный микрофон. `false` — микрофон системы: выбранный
  /// не нашёлся среди устройств, которые умеет открывать пакет записи.
  final bool exact;
}

/// Микрофон для проверки. Настоящая половина — [RecordMicCapture], в тестах
/// — подставная.
abstract class DesktopMicCapture {
  /// Есть ли разрешение; [request] — спросить систему, если ещё не решено.
  Future<bool> hasPermission({required bool request});

  /// Открыть микрофон [webrtcDeviceId] (идентификатор из списка звонков;
  /// пустой — микрофон системы).
  Future<DesktopMicStream> open({
    required String webrtcDeviceId,
    required String label,
    required int sampleRate,
  });

  /// Закрыть микрофон. Повторный вызов безвреден.
  Future<void> close();

  Future<void> dispose();
}

/// Какое устройство пакета записи — тот микрофон, что выбран для звонков.
/// Чистая функция.
///
/// Идентификаторы совпадают на обеих системах: на Windows это строка
/// конечной точки (`{0.0.1.00000000}.{GUID}`) и у `flutter_webrtc`, и у
/// Media Foundation; на macOS — UID устройства Core Audio. Имя — запасной
/// путь на случай иной формы идентификатора. Не нашлось — `null`, и
/// открывается микрофон системы (об этом скажет [DesktopMicStream.exact]).
({String id, String label})? resolveRecorderInput({
  required Iterable<({String id, String label})> candidates,
  required String webrtcDeviceId,
  required String label,
}) {
  final wantId = webrtcDeviceId.trim().toLowerCase();
  if (wantId.isEmpty) return null;
  final wantName = label.trim().toLowerCase();
  ({String id, String label})? byName;
  for (final c in candidates) {
    if (c.id.trim().toLowerCase() == wantId) return c;
    if (byName == null &&
        wantName.isNotEmpty &&
        c.label.trim().toLowerCase() == wantName) {
      byName = c;
    }
  }
  return byName;
}

/// Микрофон через пакет `record`: поток PCM, без файлов на диске.
class RecordMicCapture implements DesktopMicCapture {
  AudioRecorder? _recorder;

  /// 🔴 Записывающий создаётся в своей зоне ошибок. Конструктор пакета сам
  /// заводит запись на платформе и ответа не ждёт: нет модуля (прогон тестов,
  /// сборка без плагина) — ошибка улетела бы в никуда и уронила бы весь
  /// раздел. Здесь она попадает в журнал, а следующие вызовы отвечают
  /// ошибкой, которую [DesktopMicCheck] показывает как «не удалось открыть».
  AudioRecorder get _rec => _recorder ??= runZonedGuarded(
    AudioRecorder.new,
    (Object e, StackTrace _) =>
        callLog('DesktopAudioCheck', 'recorder init failed: $e'),
  )!;

  @override
  Future<bool> hasPermission({required bool request}) =>
      _rec.hasPermission(request: request);

  @override
  Future<DesktopMicStream> open({
    required String webrtcDeviceId,
    required String label,
    required int sampleRate,
  }) async {
    final rec = _rec;
    await _stopQuietly(rec);
    InputDevice? device;
    var exact = webrtcDeviceId.trim().isEmpty;
    if (!exact) {
      try {
        final list = await rec.listInputDevices();
        final match = resolveRecorderInput(
          candidates: [for (final d in list) (id: d.id, label: d.label)],
          webrtcDeviceId: webrtcDeviceId,
          label: label,
        );
        if (match != null) {
          device = InputDevice(id: match.id, label: match.label);
          exact = true;
        }
      } catch (e) {
        callLog('DesktopAudioCheck', 'mic list failed: $e');
      }
    }
    RecordConfig config(InputDevice? d) => RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
      device: d,
    );
    try {
      final pcm = await rec.startStream(config(device));
      return DesktopMicStream(pcm: pcm, exact: exact);
    } catch (e) {
      if (device == null) rethrow;
      // Выбранный не открылся (на macOS движок звука иногда не даёт взять
      // вход, отличный от системного). Лучше честно показать микрофон
      // системы с пометкой, чем пустую строку «не удалось».
      callLog('DesktopAudioCheck', 'selected mic failed, using default: $e');
      await _stopQuietly(rec);
      final pcm = await rec.startStream(config(null));
      return DesktopMicStream(pcm: pcm, exact: false);
    }
  }

  static Future<void> _stopQuietly(AudioRecorder rec) async {
    try {
      if (await rec.isRecording()) await rec.stop();
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    final rec = _recorder;
    if (rec != null) await _stopQuietly(rec);
  }

  @override
  Future<void> dispose() async {
    final rec = _recorder;
    _recorder = null;
    if (rec == null) return;
    await _stopQuietly(rec);
    try {
      await rec.dispose();
    } catch (_) {}
  }
}

/// Что с индикатором.
enum MicCheckStatus {
  /// Выключен: раздел не на экране, идёт звонок или ещё не включали.
  off,

  /// Разрешения ещё не давали — нужна кнопка, сами не спрашиваем.
  needsPermission,

  /// Разрешение запрещено — поможет только настройка системы.
  denied,

  /// Микрофон слушается, полоска живая.
  live,

  /// Открыть не удалось: занят, отключён, закрыт доступ на уровне системы.
  failed,
}

/// Что с проверкой «записать — проиграть».
enum MicTestPhase { idle, recording, playing }

/// Индикатор уровня и проверка записи — одно состояние на раздел.
class DesktopMicCheck extends ChangeNotifier {
  DesktopMicCheck({
    required DesktopMicCapture capture,
    required DesktopAudioOutput output,
    this.sampleRate = kDesktopCheckSampleRate,
    this.testLength = const Duration(seconds: 5),
    this.levelInterval = const Duration(milliseconds: 50),
  }) : _capture = capture,
       _output = output;

  final DesktopMicCapture _capture;
  final DesktopAudioOutput _output;
  final int sampleRate;

  /// Сколько записывает проверка.
  final Duration testLength;

  /// Как часто двигается полоска. Микрофон присылает куски по 10–20 мс;
  /// перерисовывать полоску на каждый — работа, которой глаз не увидит.
  final Duration levelInterval;

  /// Положение полоски, 0…1.
  final ValueNotifier<double> level = ValueNotifier<double>(0);

  MicCheckStatus _status = MicCheckStatus.off;
  MicCheckStatus get status => _status;

  MicTestPhase _phase = MicTestPhase.idle;
  MicTestPhase get phase => _phase;

  int _secondsLeft = 0;

  /// Сколько секунд записи осталось.
  int get secondsLeft => _secondsLeft;

  bool _exact = true;

  /// Открыт именно выбранный микрофон (см. [DesktopMicStream.exact]).
  bool get micExact => _exact;

  bool? _playbackTargeted;

  /// Куда прозвучала последняя запись: `true` — в выбранные динамики,
  /// `false` — в системные (выбранные открыть не удалось), `null` — ещё не
  /// проигрывали.
  bool? get playbackTargeted => _playbackTargeted;

  bool _playbackFailed = false;

  /// Последнюю запись проиграть не удалось совсем.
  bool get playbackFailed => _playbackFailed;

  String _micId = '';
  String _micLabel = '';

  /// Какой микрофон открыт (или открывается).
  String get micId => _micId;

  StreamSubscription<Uint8List>? _sub;
  BytesBuilder? _take;
  int _takeLimit = 0;
  Timer? _testTimer;
  DesktopPlayback? _playback;
  double _pendingPeak = 0;
  final Stopwatch _levelClock = Stopwatch();

  /// Растёт при каждом включении и выключении: ответы системы на прежний
  /// запрос опаздывают и не должны перетирать новое состояние.
  int _generation = 0;
  bool _disposed = false;

  /// Включить индикатор для микрофона [micId] ('' — системный).
  ///
  /// Разрешение НЕ спрашивается: нет его — [MicCheckStatus.needsPermission],
  /// и человек решает сам, нажав кнопку.
  Future<void> start({required String micId, String micLabel = ''}) async {
    if (_disposed) return;
    final gen = ++_generation;
    _cancelTest(notify: false);
    await _closeStream();
    if (gen != _generation || _disposed) return;
    _micId = micId;
    _micLabel = micLabel;
    bool allowed;
    try {
      allowed = await _capture.hasPermission(request: false);
    } catch (_) {
      allowed = false;
    }
    if (gen != _generation || _disposed) return;
    if (!allowed) {
      _setStatus(MicCheckStatus.needsPermission);
      return;
    }
    await _open(gen);
  }

  /// Спросить разрешение (по кнопке) и включить индикатор.
  Future<void> requestPermission() async {
    if (_disposed) return;
    final gen = ++_generation;
    bool allowed;
    try {
      allowed = await _capture.hasPermission(request: true);
    } catch (_) {
      allowed = false;
    }
    if (gen != _generation || _disposed) return;
    if (!allowed) {
      _setStatus(MicCheckStatus.denied);
      return;
    }
    await _open(gen);
  }

  Future<void> _open(int gen) async {
    try {
      final opened = await _capture.open(
        webrtcDeviceId: _micId,
        label: _micLabel,
        sampleRate: sampleRate,
      );
      if (gen != _generation || _disposed) {
        await _capture.close();
        return;
      }
      _exact = opened.exact;
      _levelClock
        ..reset()
        ..start();
      void lost(String why) {
        if (gen != _generation || _disposed) return;
        callLog('DesktopAudioCheck', 'mic stream $why');
        _cancelTest(notify: false);
        level.value = 0;
        _setStatus(MicCheckStatus.failed);
      }

      _sub = opened.pcm.listen(
        _onChunk,
        onError: (Object e) => lost('error: $e'),
        // Сами мы отписываемся раньше, чем закрыть поток, — значит, конец
        // пришёл от системы (микрофон выдернули, его забрала другая
        // программа). Застывшая полоска соврала бы, что всё в порядке.
        onDone: () => lost('ended by the system'),
      );
      _setStatus(MicCheckStatus.live);
    } catch (e) {
      if (gen != _generation || _disposed) return;
      callLog('DesktopAudioCheck', 'mic open failed: $e');
      level.value = 0;
      _setStatus(MicCheckStatus.failed);
    }
  }

  void _onChunk(Uint8List chunk) {
    _pendingPeak = math.max(_pendingPeak, pcm16Peak(chunk));
    if (_levelClock.elapsed >= levelInterval) {
      level.value = smoothLevel(level.value, levelFromPeak(_pendingPeak));
      _pendingPeak = 0;
      _levelClock
        ..reset()
        ..start();
    }
    final take = _take;
    if (take == null) return;
    final room = _takeLimit - take.length;
    if (room <= 0) return;
    take.add(
      room >= chunk.length ? chunk : Uint8List.sublistView(chunk, 0, room),
    );
  }

  /// Выключить всё: индикатор, запись, проигрывание. Микрофон свободен.
  ///
  /// 🔴 Отменяет и включение, которое ещё ждёт ответа системы (30.09.2026):
  /// пока [start] ждёт разрешения или открытия микрофона, статус ещё
  /// [MicCheckStatus.off], и по нему одному не видно, что микрофон вот-вот
  /// откроется. Уже выключенному повторный вызов ничего не делает.
  Future<void> stop() async {
    if (_disposed) return;
    ++_generation;
    if (_sub == null &&
        _status == MicCheckStatus.off &&
        _phase == MicTestPhase.idle) {
      return;
    }
    _cancelTest(notify: false);
    await _closeStream();
    level.value = 0;
    _setStatus(MicCheckStatus.off);
  }

  Future<void> _closeStream() async {
    final sub = _sub;
    _sub = null;
    _levelClock.stop();
    _pendingPeak = 0;
    // Отписка действует сразу — после `cancel()` кусков больше не будет, —
    // поэтому микрофон закрываем, не дожидаясь её: чем раньше система
    // погасит значок микрофона, тем лучше.
    final cancelled = sub?.cancel();
    try {
      await _capture.close();
    } catch (_) {}
    await cancelled;
  }

  /// «Проверить микрофон»: записать [testLength] и проиграть в устройство
  /// [outputId] ('' — «как в системе»).
  Future<void> runTest({
    required String outputId,
    String outputLabel = '',
  }) async {
    if (_disposed || _phase != MicTestPhase.idle) return;
    if (_status == MicCheckStatus.needsPermission ||
        _status == MicCheckStatus.denied) {
      await requestPermission();
    }
    if (_disposed || _status != MicCheckStatus.live) return;
    final gen = _generation;
    _take = BytesBuilder(copy: true);
    _takeLimit = pcm16MonoBytes(testLength, sampleRate);
    _playbackTargeted = null;
    _playbackFailed = false;
    _secondsLeft = math.max(1, testLength.inSeconds);
    _phase = MicTestPhase.recording;
    notifyListeners();
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (gen != _generation || _disposed) {
        timer.cancel();
        return;
      }
      _secondsLeft -= 1;
      if (_secondsLeft > 0) {
        notifyListeners();
        return;
      }
      timer.cancel();
      _testTimer = null;
      unawaited(
        _playBack(gen, outputId: outputId, outputLabel: outputLabel),
      );
    });
  }

  Future<void> _playBack(
    int gen, {
    required String outputId,
    required String outputLabel,
  }) async {
    final take = _take;
    _take = null;
    if (take == null || gen != _generation || _disposed) return;
    final bytes = take.takeBytes();
    if (bytes.isEmpty) {
      _playbackFailed = true;
      _setPhase(MicTestPhase.idle);
      return;
    }
    _setPhase(MicTestPhase.playing);
    final playback = await _output.play(
      bytes,
      sampleRate: sampleRate,
      outputDeviceId: outputId,
      outputLabel: outputLabel,
    );
    if (gen != _generation || _disposed || _phase != MicTestPhase.playing) {
      playback?.cancel();
      return;
    }
    if (playback == null) {
      _playbackFailed = true;
      _setPhase(MicTestPhase.idle);
      return;
    }
    _playback = playback;
    _playbackTargeted = playback.targeted;
    notifyListeners();
    await playback.done;
    if (!identical(_playback, playback)) return;
    _playback = null;
    if (!_disposed) _setPhase(MicTestPhase.idle);
  }

  /// Прервать проверку: запись выбрасывается, проигрывание смолкает.
  void cancelTest() => _cancelTest(notify: true);

  void _cancelTest({required bool notify}) {
    _testTimer?.cancel();
    _testTimer = null;
    _take = null;
    final playback = _playback;
    _playback = null;
    playback?.cancel();
    if (_phase != MicTestPhase.idle) {
      _phase = MicTestPhase.idle;
      if (notify && !_disposed) notifyListeners();
    }
  }

  void _setStatus(MicCheckStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  void _setPhase(MicTestPhase phase) {
    if (_disposed) return;
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    ++_generation;
    _cancelTest(notify: false);
    _disposed = true;
    final sub = _sub;
    _sub = null;
    unawaited(() async {
      // Как и в [_closeStream]: микрофон отпускаем, не дожидаясь отписки.
      final cancelled = sub?.cancel();
      await _capture.dispose();
      await cancelled;
    }());
    level.dispose();
    super.dispose();
  }
}
