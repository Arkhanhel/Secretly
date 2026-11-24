// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Запись голосового (макет «Voice Recording», 1b «Новая запись», 21.11.2026).
///
/// Конечный автомат вместо набора флагов:
///
///   idle ──держит 150 мс──▶ arming ──рекордер запущен──▶ holding
///   holding ──вверх ≥ lockDistance──▶ locked ──«Стоп»──▶ preview
///   holding ──отпустил──▶ отправка   (или удаление, если отмена взведена)
///   locked / preview ──«Отправить»──▶ отправка;  ──корзина──▶ cancelling
///
/// Что было сломано и что здесь иначе:
/// * отмена срабатывала сразу при пересечении порога — теперь только по
///   ОТПУСКАНИЮ, вернул палец — отмена снята;
/// * гонка при старте: отпускание, пока рекордер ещё запускался, терялось и
///   запись висела без кнопки — теперь оно запоминается и обрабатывается после
///   старта;
/// * системное прерывание (звонок, жест) теряло запись — теперь закрепляет её;
/// * отмена и фиксация решаются по ДОМИНИРУЮЩЕЙ оси;
/// * таймер и громкость — через [ValueNotifier], без перестройки экрана чата;
/// * короткое касание и слишком короткая запись — подсказка, а не молчание.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

enum VoicePhase { idle, arming, holding, locked, preview, cancelling }

/// Жест записи — общий у голосовых и видео-заметок: одна кнопка, один
/// слушатель касаний ([VoiceRecordGestureArea]) на всё время жеста.
abstract interface class RecordGestureTarget {
  void pointerDown(Offset position);
  void pointerMove(Offset position);

  /// `true` — это было короткое касание (запись не началась).
  bool pointerUp();
  void pointerCancel();
}

/// Куда тянет палец: единое правило для голосовых и видео-заметок.
///
/// Решает ДОМИНИРУЮЩАЯ ось: вверх дальше [lockDistance] — замок, влево
/// дальше [cancelDistance] — отмена взведена (сработает по отпусканию).
/// Косое движение не делает ни того, ни другого. Вправо и вниз не тянется.
@immutable
class RecordDrag {
  const RecordDrag._(this.offset, this.vertical, this.lock, this.cancelArmed);

  factory RecordDrag.evaluate(
    Offset raw, {
    required double lockDistance,
    required double cancelDistance,
  }) {
    final dx = math.min(0.0, raw.dx);
    final dy = math.min(0.0, raw.dy);
    final vertical = dy.abs() > dx.abs();
    return RecordDrag._(
      Offset(dx, dy),
      vertical,
      vertical && dy <= -lockDistance,
      !vertical && dx <= -cancelDistance,
    );
  }

  /// Сдвиг: dx ≤ 0, dy ≤ 0.
  final Offset offset;
  final bool vertical;
  final bool lock;
  final bool cancelArmed;
}

/// Подсказки, которые показывает экран.
enum VoiceHint {
  /// Короткое касание микрофона.
  holdToRecord,

  /// Запись короче [VoiceRecorderController.minDuration].
  tooShort,

  /// Нет доступа к микрофону.
  noPermission,

  /// Рекордер не запустился или не отдал файл.
  failed,
}

/// Готовая запись.
@immutable
class VoiceTake {
  const VoiceTake({
    required this.path,
    required this.duration,
    required this.waveform,
  });

  final String path;
  final Duration duration;

  /// Огибающая громкости: столбики 0…100.
  final List<int> waveform;
}

/// Что умеет микрофон. Отдельно — чтобы автомат проверялся тестом без
/// настоящего рекордера.
abstract class VoiceRecorderBackend {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<String?> stop();
  Future<void> cancel();

  /// Громкость 0…1 примерно раз в 90 мс.
  Stream<double> levels();
}

/// Настоящий микрофон (`record`).
class RecordVoiceBackend implements VoiceRecorderBackend {
  RecordVoiceBackend(this._recorder);

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
    ),
    path: path,
  );

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 90))
      // dBFS: ~0 громко, ~-60 тишина; речь — [-45, 0] → [0, 1].
      .map((a) => ((a.current + 45) / 45).clamp(0.0, 1.0).toDouble());
}

/// Прослушивание перед отправкой. Отдельно — для тестов.
abstract class VoicePreviewPlayer {
  Future<void> load(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Stream<Duration> get position;
  Stream<bool> get completed;
  Future<void> dispose();
}

class JustAudioPreviewPlayer implements VoicePreviewPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> load(String path) => _player.setFilePath(path);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<bool> get completed => _player.processingStateStream
      .map((s) => s == ProcessingState.completed);

  @override
  Future<void> dispose() => _player.dispose();
}

class VoiceRecorderController implements RecordGestureTarget {
  VoiceRecorderController({
    required VoiceRecorderBackend backend,
    required Future<String> Function() newTempPath,
    required Future<bool> Function() canStart,
    required Future<void> Function(VoiceTake take) onSend,
    required void Function(VoiceHint hint) onHint,
    VoicePreviewPlayer Function()? previewPlayer,
    Future<void> Function(String path)? deleteFile,
    this.lockDistance = 90,
    this.cancelDistance = 120,
    this.armDelay = const Duration(milliseconds: 150),
    this.minDuration = const Duration(milliseconds: 500),
    this.waveformBars = 48,
    this.haptics = true,
  }) : _backend = backend,
       _newTempPath = newTempPath,
       _canStart = canStart,
       _onSend = onSend,
       _onHint = onHint,
       _previewFactory = previewPlayer ?? JustAudioPreviewPlayer.new,
       _deleter = deleteFile ?? _deleteFromDisk;

  final VoiceRecorderBackend _backend;
  final Future<String> Function() _newTempPath;
  final Future<bool> Function() _canStart;
  final Future<void> Function(VoiceTake take) _onSend;
  final void Function(VoiceHint hint) _onHint;
  final VoicePreviewPlayer Function() _previewFactory;
  final Future<void> Function(String path) _deleter;

  static Future<void> _deleteFromDisk(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Вверх на столько — запись закрепляется.
  final double lockDistance;

  /// Влево на столько — отмена взведена (сработает по отпусканию).
  final double cancelDistance;

  /// Удержание дольше — запись; короче — касание.
  final Duration armDelay;
  final Duration minDuration;
  final int waveformBars;
  final bool haptics;

  // ── Состояние для экрана ─────────────────────────────────────────────────
  final ValueNotifier<VoicePhase> phase = ValueNotifier(VoicePhase.idle);
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  /// Сглаженная громкость 0…1 — дыхание круга.
  final ValueNotifier<double> level = ValueNotifier(0);

  /// Растёт с каждым новым столбиком живой волны.
  final ValueNotifier<int> samplesVersion = ValueNotifier(0);

  /// Сдвиг пальца: dx ≤ 0, dy ≤ 0.
  final ValueNotifier<Offset> drag = ValueNotifier(Offset.zero);
  final ValueNotifier<bool> cancelArmed = ValueNotifier(false);

  /// Прослушивание: идёт ли и где (0…1).
  final ValueNotifier<bool> previewPlaying = ValueNotifier(false);
  final ValueNotifier<double> previewPosition = ValueNotifier(0);

  final List<double> _samples = <double>[];

  /// Живая огибающая (0…1), последние значения в конце.
  List<double> get samples => _samples;

  // ── Внутреннее ───────────────────────────────────────────────────────────
  Offset? _origin;
  Timer? _armTimer;
  Timer? _ticker;
  Timer? _cancelTimer;
  DateTime? _startedAt;
  StreamSubscription<double>? _levelSub;
  String? _path;
  bool _releasedEarly = false;
  bool _interruptedEarly = false;
  bool _tapSend = false;
  bool _disposed = false;
  Duration _takeDuration = Duration.zero;
  List<int>? _takeWave;
  VoicePreviewPlayer? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _doneSub;

  bool get isActive => phase.value != VoicePhase.idle;

  /// Отношение сдвига к порогам — для анимаций.
  double get lockProgress =>
      (-drag.value.dy / lockDistance).clamp(0.0, 1.0).toDouble();
  double get cancelProgress =>
      (-drag.value.dx / cancelDistance).clamp(0.0, 1.0).toDouble();

  void _buzz(Future<void> Function() f) {
    if (haptics) unawaited(f());
  }

  // ── Жест ─────────────────────────────────────────────────────────────────

  /// Палец на микрофоне (или на «Отправить» в закреплённой записи).
  @override
  void pointerDown(Offset position) {
    final p = phase.value;
    if (p == VoicePhase.locked || p == VoicePhase.preview) {
      _tapSend = true;
      return;
    }
    if (p != VoicePhase.idle) return;
    _origin = position;
    _releasedEarly = false;
    _interruptedEarly = false;
    _armTimer?.cancel();
    _armTimer = Timer(armDelay, () {
      _armTimer = null;
      unawaited(_arm());
    });
  }

  @override
  void pointerMove(Offset position) {
    final origin = _origin;
    if (origin == null) return;
    if (phase.value != VoicePhase.holding) return;
    final d = RecordDrag.evaluate(
      position - origin,
      lockDistance: lockDistance,
      cancelDistance: cancelDistance,
    );
    if (d.lock) {
      lock();
      return;
    }
    final armed = d.cancelArmed;
    if (armed != cancelArmed.value) {
      _buzz(armed ? HapticFeedback.mediumImpact : HapticFeedback.selectionClick);
      cancelArmed.value = armed;
    }
    drag.value = d.offset;
  }

  /// Палец поднят. Возвращает `true`, если это было короткое касание (экран
  /// может, например, переключить микрофон на камеру).
  @override
  bool pointerUp() {
    if (_tapSend) {
      _tapSend = false;
      unawaited(send());
      return false;
    }
    if (_origin == null) return false;
    _origin = null;
    if (_armTimer != null) {
      _armTimer!.cancel();
      _armTimer = null;
      _onHint(VoiceHint.holdToRecord);
      return true;
    }
    switch (phase.value) {
      case VoicePhase.arming:
        // Рекордер ещё запускается — отпускание обработаем после старта.
        _releasedEarly = true;
      case VoicePhase.holding:
        unawaited(_release());
      default:
        break;
    }
    return false;
  }

  /// Касание прервано системой (звонок, системный жест): запись не теряется,
  /// а закрепляется.
  @override
  void pointerCancel() {
    _tapSend = false;
    if (_origin == null) return;
    _origin = null;
    if (_armTimer != null) {
      _armTimer!.cancel();
      _armTimer = null;
      return;
    }
    switch (phase.value) {
      case VoicePhase.arming:
        _interruptedEarly = true;
      case VoicePhase.holding:
        lock();
      default:
        break;
    }
  }

  Future<void> _arm() async {
    if (_disposed || phase.value != VoicePhase.idle) return;
    phase.value = VoicePhase.arming;
    try {
      if (!await _canStart()) {
        _reset();
        return;
      }
      if (!await _backend.hasPermission()) {
        _reset();
        _onHint(VoiceHint.noPermission);
        return;
      }
      final path = await _newTempPath();
      // Экран закрыли, пока выясняли права и место, — микрофон не включаем.
      if (_disposed) return;
      await _backend.start(path);
      if (_disposed) {
        // Н-7 (22.11.2026): чат закрыли, пока микрофон запускался. `dispose`
        // уже прошёл и о записи не знал (`_path` ещё пуст) — раньше рекордер
        // так и писал дальше, а временный файл оставался на диске.
        await _abandonStarted(path);
        return;
      }
      _path = path;
    } catch (_) {
      if (_disposed) return;
      _reset();
      _onHint(VoiceHint.failed);
      return;
    }
    _samples.clear();
    samplesVersion.value = 0;
    level.value = 0;
    elapsed.value = Duration.zero;
    drag.value = Offset.zero;
    cancelArmed.value = false;
    _startedAt = clock.now();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final t0 = _startedAt;
      if (t0 != null) elapsed.value = clock.now().difference(t0);
    });
    _levelSub?.cancel();
    _levelSub = _backend.levels().listen((v) {
      level.value = level.value + (v - level.value) * 0.35;
      _samples.add(v);
      if (_samples.length > 1200) _samples.removeRange(0, 200);
      samplesVersion.value++;
    }, onError: (_) {});
    phase.value = VoicePhase.holding;
    _buzz(HapticFeedback.lightImpact);
    if (_interruptedEarly) {
      _interruptedEarly = false;
      lock();
    } else if (_releasedEarly) {
      _releasedEarly = false;
      await _release();
    }
  }

  Future<void> _release() async {
    if (phase.value != VoicePhase.holding) return;
    if (cancelArmed.value) {
      await cancel();
      return;
    }
    if (elapsed.value < minDuration) {
      await _discard();
      _onHint(VoiceHint.tooShort);
      return;
    }
    await send();
  }

  /// Закрепить: палец можно убрать, запись идёт.
  void lock() {
    if (phase.value != VoicePhase.holding) return;
    _origin = null;
    drag.value = Offset.zero;
    cancelArmed.value = false;
    phase.value = VoicePhase.locked;
    _buzz(HapticFeedback.mediumImpact);
  }

  /// «Стоп» в закреплённой записи: остановить и прослушать.
  Future<void> stopToPreview() async {
    if (phase.value != VoicePhase.locked) return;
    final take = await _stopRecorder();
    if (take == null) {
      _reset();
      _onHint(VoiceHint.failed);
      return;
    }
    _buzz(HapticFeedback.lightImpact);
    previewPlaying.value = false;
    previewPosition.value = 0;
    phase.value = VoicePhase.preview;
    try {
      final player = _previewFactory();
      _player = player;
      await player.load(take);
      _posSub = player.position.listen((pos) {
        final total = _takeDuration.inMilliseconds;
        if (total > 0) {
          previewPosition.value =
              (pos.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
        }
      });
      _doneSub = player.completed.listen((done) {
        if (!done) return;
        previewPlaying.value = false;
        previewPosition.value = 0;
        unawaited(player.pause());
        unawaited(player.seek(Duration.zero));
      });
    } catch (_) {
      // Прослушать не вышло — отправить и удалить всё равно можно.
    }
  }

  Future<void> togglePreview() async {
    final player = _player;
    if (phase.value != VoicePhase.preview || player == null) return;
    _buzz(HapticFeedback.selectionClick);
    if (previewPlaying.value) {
      previewPlaying.value = false;
      await player.pause();
    } else {
      previewPlaying.value = true;
      unawaited(player.play());
    }
  }

  /// Отправить: из удержания (отпускание), закреплённой записи или
  /// прослушивания.
  Future<void> send() async {
    final p = phase.value;
    String? path;
    if (p == VoicePhase.holding || p == VoicePhase.locked) {
      path = await _stopRecorder();
    } else if (p == VoicePhase.preview) {
      path = _path;
      await _closePlayer();
    } else {
      return;
    }
    final duration = _takeDuration;
    final wave = _takeWave ?? _waveform();
    _path = null;
    _reset();
    if (path == null || path.isEmpty) {
      _onHint(VoiceHint.failed);
      return;
    }
    if (duration < minDuration) {
      await _deleteFile(path);
      _onHint(VoiceHint.tooShort);
      return;
    }
    _buzz(HapticFeedback.mediumImpact);
    await _onSend(VoiceTake(path: path, duration: duration, waveform: wave));
  }

  /// Корзина / отпускание со взведённой отменой.
  Future<void> cancel() async {
    final p = phase.value;
    if (p == VoicePhase.idle || p == VoicePhase.cancelling) return;
    _buzz(HapticFeedback.heavyImpact);
    _origin = null;
    // 🔴 Идёт ли запись — решаем ДО смены фазы: иначе микрофон не
    // останавливался (фаза уже «удаляется»).
    final recording = p == VoicePhase.holding || p == VoicePhase.locked;
    phase.value = VoicePhase.cancelling;
    await _discard(keepPhase: true, recording: recording);
    _cancelTimer?.cancel();
    _cancelTimer = Timer(const Duration(milliseconds: 900), () {
      if (phase.value == VoicePhase.cancelling) _reset();
    });
  }

  // ── Служебное ────────────────────────────────────────────────────────────

  Future<String?> _stopRecorder() async {
    _ticker?.cancel();
    _ticker = null;
    final t0 = _startedAt;
    _takeDuration = t0 != null ? clock.now().difference(t0) : elapsed.value;
    _startedAt = null;
    elapsed.value = _takeDuration;
    // Отписка без ожидания: дожидаться нечего, а ожидание задерживало
    // остановку на неопределённый срок.
    unawaited(_levelSub?.cancel());
    _levelSub = null;
    _takeWave = _waveform();
    String? out;
    try {
      out = await _backend.stop();
    } catch (_) {
      out = null;
    }
    out ??= _path;
    _path = out;
    return out;
  }

  Future<void> _discard({bool keepPhase = false, bool? recording}) async {
    _ticker?.cancel();
    _ticker = null;
    // Отписка без ожидания: дожидаться нечего, а ожидание задерживало
    // остановку на неопределённый срок.
    unawaited(_levelSub?.cancel());
    _levelSub = null;
    await _closePlayer();
    final p = phase.value;
    if (recording ?? (p == VoicePhase.holding || p == VoicePhase.locked)) {
      try {
        await _backend.cancel();
      } catch (_) {
        try {
          await _backend.stop();
        } catch (_) {}
      }
    }
    final path = _path;
    _path = null;
    if (path != null) await _deleteFile(path);
    if (!keepPhase) _reset();
  }

  Future<void> _closePlayer() async {
    unawaited(_posSub?.cancel());
    unawaited(_doneSub?.cancel());
    _posSub = null;
    _doneSub = null;
    final player = _player;
    _player = null;
    previewPlaying.value = false;
    if (player != null) {
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  Future<void> _deleteFile(String path) => _deleter(path);

  /// Рекордер запустился уже после [dispose]: остановить и стереть файл.
  Future<void> _abandonStarted(String path) async {
    try {
      await _backend.cancel();
    } catch (_) {
      try {
        await _backend.stop();
      } catch (_) {}
    }
    await _deleteFile(path);
  }

  void _reset() {
    _armTimer?.cancel();
    _armTimer = null;
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    _origin = null;
    _releasedEarly = false;
    _interruptedEarly = false;
    _takeWave = null;
    drag.value = Offset.zero;
    cancelArmed.value = false;
    level.value = 0;
    previewPlaying.value = false;
    previewPosition.value = 0;
    if (!_disposed) phase.value = VoicePhase.idle;
  }

  /// Огибающая для пузыря: [waveformBars] столбиков 0…100, пик в корзине,
  /// нормировка по самому громкому — тихая запись тоже заполняет полосу.
  List<int> _waveform() => voiceWaveformFrom(_samples, waveformBars);

  /// Закрыть всё: экран чата уходит.
  Future<void> dispose() async {
    _disposed = true;
    _armTimer?.cancel();
    _cancelTimer?.cancel();
    if (phase.value == VoicePhase.holding ||
        phase.value == VoicePhase.locked ||
        phase.value == VoicePhase.arming) {
      await _discard(keepPhase: true);
    } else {
      await _closePlayer();
    }
    phase.dispose();
    elapsed.dispose();
    level.dispose();
    samplesVersion.dispose();
    drag.dispose();
    cancelArmed.dispose();
    previewPlaying.dispose();
    previewPosition.dispose();
  }
}

/// Огибающая записи: [bars] столбиков 0…100 (пик в корзине, нормировка по
/// самому громкому). Пусто — ровная невысокая волна, чтобы голосовое всё
/// равно распознавалось как голосовое.
List<int> voiceWaveformFrom(List<double> samples, int bars) {
  if (samples.isEmpty) {
    return List<int>.generate(bars, (i) => 18 + (i * 37 % 23), growable: false);
  }
  final out = List<double>.filled(bars, 0);
  for (var i = 0; i < bars; i++) {
    final start = (i * samples.length / bars).floor();
    final end = math.max(start + 1, ((i + 1) * samples.length / bars).floor());
    var peak = 0.0;
    for (var j = start; j < end && j < samples.length; j++) {
      if (samples[j] > peak) peak = samples[j];
    }
    out[i] = peak;
  }
  final maxV = out.fold<double>(0, math.max);
  final k = maxV > 0.05 ? 1 / maxV : 1.0;
  return out
      .map((v) => (v * k * 100).round().clamp(0, 100))
      .toList(growable: false);
}
