// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Запись видео-заметки (макет «Video Notes», 3b «Новая запись», 21.11.2026).
///
/// Тот же жест, что у голосовых ([RecordGestureTarget], [RecordDrag]):
///
///   idle ──держит 150 мс──▶ arming ──камера пишет──▶ holding
///   holding ──вверх ≥ lockDistance──▶ locked ⇄ paused («Пауза»/«Продолжить»)
///   holding ──отпустил──▶ отправка   (или удаление, если отмена взведена)
///   locked / paused ──«Стоп» или лимит──▶ preview (ролик по кругу, обрезка)
///   locked / paused / preview ──«Отправить»──▶ отправка
///   любая ──корзина──▶ cancelling;  preview ──«Переснять»──▶ idle
///
/// Что было не так и что здесь иначе:
/// * запись закреплялась сама и сразу — отмены пальцем не было, замка тоже;
///   теперь замок по жесту вверх, отмена — влево и только по отпусканию;
/// * лимит минуты обрывал запись и сразу отправлял — теперь контур желтеет за
///   10 секунд, а по лимиту открывается просмотр;
/// * ни паузы, ни просмотра — теперь пауза режет запись на части (каждая —
///   отрезок на контуре), просмотр по кругу с обрезкой и «Переснять»;
/// * свернули приложение посреди записи — запись пропадала; теперь снятое
///   остаётся и открывается просмотр;
/// * камера открывалась только через 220 мс после касания — теперь сразу при
///   касании (короткое касание её закрывает).
///
/// Приближение (22.11.2026, владелец: «во время записи нельзя приблизить»):
/// * два пальца по квадрату — щипок, пока камера живая (удержание, замок,
///   пауза);
/// * палец на кнопке, ещё не в замке: вверх до замка — как раньше; дальше
///   ВЫШЕ замка, не отпуская, — приближение ([zoomDeadZone] после замка, затем
///   [zoomSpan] до максимума); вниз в этой полосе — обратно, замок не
///   снимается; отпустил — замок и приближение остаются;
/// * в замке — палец вверх/вниз по квадрату (от приближения в начале жеста);
/// * смена камеры — снова 1×; пауза приближение хранит; в просмотре его нет.
/// Камере уходит не больше одного вызова за раз — всегда последнее значение.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'video_note_recorder.dart';
import 'voice_recorder_controller.dart' show RecordDrag, RecordGestureTarget;

enum VideoNotePhase {
  idle,
  arming,
  holding,
  locked,
  paused,
  preview,
  cancelling,
}

enum VideoNoteHint {
  /// Камера не открылась или запись не пошла.
  cameraFailed,

  /// Нет доступа к камере или микрофону.
  noPermission,

  /// Запись короче [VideoNoteController.minDuration].
  tooShort,

  /// Минута вышла — открыт просмотр.
  limitReached,

  /// «Переснять».
  retake,
}

/// Отрезок на контуре квадрата, секунды от начала записи.

/// Приближение «палец выше замка» (21.11.2026). Выключено словом владельца
/// 22.11.2026: сдвиг к замку не должен приближать; приближение — только
/// жестом по квадрату.
const bool kVideoNoteLiftZoom = false;

@immutable

class VideoNoteRange {
  const VideoNoteRange(this.from, this.to);
  final double from;
  final double to;

  @override
  bool operator ==(Object other) =>
      other is VideoNoteRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Обрезка в просмотре: от и до (в общей длине записи).
@immutable
class VideoNoteTrim {
  const VideoNoteTrim(this.start, this.end);
  final Duration start;
  final Duration end;
  Duration get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is VideoNoteTrim && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Диапазон приближения камеры (как его сообщает устройство).
@immutable
class VideoNoteZoomRange {
  const VideoNoteZoomRange(this.min, this.max);
  final double min;
  final double max;
}

/// Камера. Отдельно — чтобы автомат проверялся тестом без настоящей камеры.
abstract class VideoNoteCamera {
  /// Только проверка (без системного окна посреди жеста: доступ спрашивается
  /// при переходе в видеорежим).
  Future<bool> hasPermission();

  /// Открыть камеру (повторный вызов — ничего не делает).
  Future<void> open({required bool front});
  bool get isOpen;
  bool get isFront;
  bool get canFlip;

  Future<void> startSegment();

  /// Путь снятого отрезка или `null`.
  Future<String?> stopSegment();

  /// Сменить камеру. Вызывается, только когда запись не идёт.
  Future<void> flip();
  Future<void> setTorch(bool on);
  Future<void> close();

  /// Диапазон приближения открытой камеры; `null` — не узнать (тогда
  /// приближения нет).
  Future<VideoNoteZoomRange?> zoomRange();

  /// Приближение открытой камеры (в пределах [zoomRange]). Может бросить —
  /// автомат глотает.
  Future<void> setZoom(double level);

  /// Живой кадр для экрана (`null` — камера ещё не готова).
  ValueListenable<Widget?> get preview;
}

/// Просмотр перед отправкой: части подряд, по кругу, в пределах обрезки.
abstract class VideoNotePreviewPlayer {
  /// Загрузить части; вернуть их настоящие длины (по файлам).
  Future<List<Duration>> load(List<VideoNoteSegment> segments);
  Future<void> play();
  Future<void> pause();
  Future<void> setRange(Duration start, Duration end);
  Future<void> seek(Duration position);

  /// Позиция в общей длине.
  ValueListenable<Duration> get position;

  /// Кадр для квадрата (`null` — ещё грузится).
  ValueListenable<Widget?> get view;
  Future<void> dispose();
}

/// Кадры ленты обрезки.
typedef VideoNoteFrameExtractor =
    Future<List<String?>> Function(
      List<VideoNoteSegment> segments,
      List<Duration> lengths,
      int count,
    );

/// Итоговый файл из частей (с обрезкой). В приложении — [produceVideoNoteFile].
typedef VideoNoteProducer =
    Future<String?> Function(
      List<VideoNoteSegment> segments, {
      Duration? trimStart,
      Duration? trimEnd,
    });

class VideoNoteController implements RecordGestureTarget {
  VideoNoteController({
    required VideoNoteCamera camera,
    required Future<bool> Function() canStart,
    required Future<void> Function(VideoNoteRecorderResult result) onSend,
    required void Function(VideoNoteHint hint) onHint,
    VideoNotePreviewPlayer Function()? previewPlayer,
    VideoNoteFrameExtractor? frames,
    VideoNoteProducer? produce,
    Future<void> Function(String path)? deleteFile,
    this.lockDistance = 90,
    this.cancelDistance = 120,
    this.armDelay = const Duration(milliseconds: 150),
    this.minDuration = const Duration(milliseconds: 800),
    this.maxDuration = const Duration(seconds: 60),
    this.warnBefore = const Duration(seconds: 10),
    this.minTrim = const Duration(seconds: 1),
    this.frameCount = 8,
    this.haptics = true,
    this.zoomDeadZone = 36,
    this.zoomSpan = 220,
    this.smoothZoom = true,
    this.maxZoomCap = 10,
  }) : _camera = camera,
       _canStart = canStart,
       _onSend = onSend,
       _onHint = onHint,
       _previewFactory = previewPlayer,
       _frames = frames,
       _produce = produce ?? produceVideoNoteFile,
       _deleter = deleteFile ?? _deleteFromDisk;

  final VideoNoteCamera _camera;
  final Future<bool> Function() _canStart;
  final Future<void> Function(VideoNoteRecorderResult result) _onSend;
  final void Function(VideoNoteHint hint) _onHint;
  final VideoNotePreviewPlayer Function()? _previewFactory;
  final VideoNoteFrameExtractor? _frames;
  final VideoNoteProducer _produce;
  final Future<void> Function(String path) _deleter;

  static Future<void> _deleteFromDisk(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  final double lockDistance;
  final double cancelDistance;
  final Duration armDelay;
  final Duration minDuration;
  final Duration maxDuration;

  /// За столько до конца контур желтеет.
  final Duration warnBefore;
  final Duration minTrim;
  final int frameCount;
  final bool haptics;

  /// Палец на кнопке, уже в замке: столько ещё вверх — ничего (чтобы
  /// закрепившие запись не приближали случайно), дальше — приближение.
  final double zoomDeadZone;

  /// За столько точек пальца приближение проходит от начального до
  /// максимума (и по квадрату в замке — весь диапазон).
  final double zoomSpan;

  /// Камере — плавно, долями (22.11.2026, Android «поддёргивал»). `false` —
  /// сразу в цель (тесты, проверяющие точные значения).
  final bool smoothZoom;

  /// Потолок приближения: устройства сообщают огромное цифровое (×100+).
  final double maxZoomCap;

  // ── Состояние для экрана ─────────────────────────────────────────────────
  final ValueNotifier<VideoNotePhase> phase = ValueNotifier(
    VideoNotePhase.idle,
  );

  /// Общее снятое время (через все части и смены камеры).
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  /// Отрезки на контуре (новый — после каждой паузы).
  final ValueNotifier<List<VideoNoteRange>> ranges = ValueNotifier(const []);
  final ValueNotifier<bool> nearLimit = ValueNotifier(false);

  /// Сдвиг пальца: dx ≤ 0, dy ≤ 0.
  final ValueNotifier<Offset> drag = ValueNotifier(Offset.zero);
  final ValueNotifier<bool> cancelArmed = ValueNotifier(false);

  /// Фронтальная камера (кадр зеркальный).
  final ValueNotifier<bool> front = ValueNotifier(true);

  /// Подсветка: у фронтальной — белый экран вокруг квадрата, у основной —
  /// фонарик.
  final ValueNotifier<bool> light = ValueNotifier(false);

  /// Камера меняется — квадрат показывает переход.
  final ValueNotifier<bool> flipping = ValueNotifier(false);

  /// Приближение (1 — без него). Меняется только при живой камере.
  final ValueNotifier<double> zoom = ValueNotifier(1);

  /// Диапазон камеры узнан — приближать можно.
  final ValueNotifier<bool> zoomEnabled = ValueNotifier(false);

  /// Просмотр.
  final ValueNotifier<VideoNoteTrim> trim = ValueNotifier(
    const VideoNoteTrim(Duration.zero, Duration.zero),
  );
  final ValueNotifier<Duration> total = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> previewPosition = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> previewPlaying = ValueNotifier(false);
  final ValueNotifier<List<String?>> frames = ValueNotifier(const []);
  final ValueNotifier<Widget?> previewView = ValueNotifier(null);

  ValueListenable<Widget?> get cameraView => _camera.preview;
  bool get canFlip => _camera.canFlip;

  // ── Внутреннее ───────────────────────────────────────────────────────────
  final List<VideoNoteSegment> _segments = <VideoNoteSegment>[];
  List<Duration> _lengths = const [];
  Offset? _origin;
  Timer? _armTimer;
  Timer? _ticker;
  Timer? _cancelTimer;
  Future<void>? _opening;
  DateTime? _segStartedAt;
  Duration _banked = Duration.zero;
  bool _recording = false;
  bool _busy = false;
  bool _releasedEarly = false;
  bool _interruptedEarly = false;
  bool _tapSend = false;
  bool _disposed = false;
  VideoNotePreviewPlayer? _player;
  int _session = 0;

  // Приближение.
  double _minZoom = 1;
  double _maxZoom = 1;
  int _zoomGen = 0;

  /// Что камера уже получила (`null` — неизвестно, отправить заново).
  double? _zoomApplied = 1;
  bool _zoomInFlight = false;

  /// Палец, закрепивший запись, ещё на экране: его ход выше замка приближает.
  Offset? _liftOrigin;
  double _liftBase = 1;

  /// Жест по квадрату: приближение в его начале.
  double? _gestureBase;

  bool get isActive => phase.value != VideoNotePhase.idle;
  List<VideoNoteSegment> get segmentsForTest => List.unmodifiable(_segments);

  double get lockProgress =>
      (-drag.value.dy / lockDistance).clamp(0.0, 1.0).toDouble();
  double get cancelProgress =>
      (-drag.value.dx / cancelDistance).clamp(0.0, 1.0).toDouble();

  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;

  void _buzz(Future<void> Function() f) {
    if (haptics) unawaited(f());
  }

  // ── Жест ─────────────────────────────────────────────────────────────────

  @override
  void pointerDown(Offset position) {
    final p = phase.value;
    if (p == VideoNotePhase.locked ||
        p == VideoNotePhase.paused ||
        p == VideoNotePhase.preview) {
      _tapSend = true;
      return;
    }
    if (p != VideoNotePhase.idle) return;
    _origin = position;
    _releasedEarly = false;
    _interruptedEarly = false;
    // Камера открывается сразу — к концу задержки она уже почти готова.
    _opening ??= _open();
    _armTimer?.cancel();
    _armTimer = Timer(armDelay, () {
      _armTimer = null;
      unawaited(_arm());
    });
  }

  @override
  void pointerMove(Offset position) {
    if (_liftOrigin != null) {
      _liftZoom(position);
      return;
    }
    final origin = _origin;
    if (origin == null || phase.value != VideoNotePhase.holding) return;
    final d = RecordDrag.evaluate(
      position - origin,
      lockDistance: lockDistance,
      cancelDistance: cancelDistance,
    );
    if (d.lock) {
      lock();
      // 🔴 22.11.2026 (владелец): сдвиг пальца вверх к замку больше НЕ
      // приближает — приближение только жестом по самому квадрату (щипок или
      // палец вверх/вниз по видео). Выключатель [kVideoNoteLiftZoom].
      if (kVideoNoteLiftZoom && phase.value == VideoNotePhase.locked) {
        // Палец ещё на экране: дальше вверх — приближение.
        _liftOrigin = origin;
        _liftBase = zoom.value;
        _liftZoom(position);
      }
      return;
    }
    if (d.cancelArmed != cancelArmed.value) {
      _buzz(
        d.cancelArmed
            ? HapticFeedback.mediumImpact
            : HapticFeedback.selectionClick,
      );
      cancelArmed.value = d.cancelArmed;
    }
    drag.value = d.offset;
  }

  @override
  bool pointerUp() {
    _liftOrigin = null;
    if (_tapSend) {
      _tapSend = false;
      unawaited(send());
      return false;
    }
    if (_origin == null) return false;
    _origin = null;
    if (_armTimer != null) {
      // Короткое касание: камеру, открытую впрок, закрываем.
      _armTimer!.cancel();
      _armTimer = null;
      unawaited(_closeCamera());
      return true;
    }
    switch (phase.value) {
      case VideoNotePhase.arming:
        _releasedEarly = true;
      case VideoNotePhase.holding:
        unawaited(_release());
      default:
        break;
    }
    return false;
  }

  /// Касание прервано системой: запись не теряется, а закрепляется.
  @override
  void pointerCancel() {
    _tapSend = false;
    _liftOrigin = null;
    if (_origin == null) return;
    _origin = null;
    if (_armTimer != null) {
      _armTimer!.cancel();
      _armTimer = null;
      unawaited(_closeCamera());
      return;
    }
    switch (phase.value) {
      case VideoNotePhase.arming:
        _interruptedEarly = true;
      case VideoNotePhase.holding:
        lock();
      default:
        break;
    }
  }

  Future<void> _open() async {
    try {
      await _camera.open(front: front.value);
    } catch (_) {
      // Разберётся _arm: камера не открыта — подсказка.
    }
  }

  Future<void> _closeCamera() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) await opening;
    // Пока ждали — могли начать новую запись.
    if (phase.value != VideoNotePhase.idle || _origin != null) return;
    light.value = false;
    try {
      await _camera.close();
    } catch (_) {}
  }

  Future<void> _arm() async {
    if (_disposed || phase.value != VideoNotePhase.idle) return;
    final session = ++_session;
    phase.value = VideoNotePhase.arming;
    _segments.clear();
    _banked = Duration.zero;
    elapsed.value = Duration.zero;
    ranges.value = const [];
    nearLimit.value = false;
    drag.value = Offset.zero;
    cancelArmed.value = false;
    try {
      if (!await _canStart()) {
        await _abort();
        return;
      }
      if (!await _camera.hasPermission()) {
        await _abort();
        _onHint(VideoNoteHint.noPermission);
        return;
      }
      await (_opening ??= _open());
      if (_disposed || session != _session) return;
      if (!_camera.isOpen) {
        await _abort();
        _onHint(VideoNoteHint.cameraFailed);
        return;
      }
      front.value = _camera.isFront;
      await _camera.startSegment();
      if (_disposed || session != _session) return;
    } catch (_) {
      await _abort();
      _onHint(VideoNoteHint.cameraFailed);
      return;
    }
    _recording = true;
    _segStartedAt = clock.now();
    ranges.value = const [VideoNoteRange(0, 0)];
    _startTicker();
    phase.value = VideoNotePhase.holding;
    _buzz(HapticFeedback.lightImpact);
    // Камера уже пишет — диапазон точно известен. Не ждём: запись не держим.
    _resetZoom();
    if (_interruptedEarly) {
      _interruptedEarly = false;
      lock();
    } else if (_releasedEarly) {
      _releasedEarly = false;
      await _release();
    }
  }

  Future<void> _abort() async {
    _reset();
    await _closeCamera();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
  }

  Duration _now() {
    final t0 = _segStartedAt;
    if (!_recording || t0 == null) return _banked;
    return _banked + clock.now().difference(t0);
  }

  void _tick() {
    final now = _now();
    final capped = now > maxDuration ? maxDuration : now;
    elapsed.value = capped;
    final list = ranges.value;
    if (list.isNotEmpty && _recording) {
      final last = list.last;
      final to = capped.inMicroseconds / 1e6;
      if (to != last.to) {
        ranges.value = [
          ...list.take(list.length - 1),
          VideoNoteRange(last.from, to),
        ];
      }
    }
    final warn = capped >= maxDuration - warnBefore;
    if (warn != nearLimit.value) {
      nearLimit.value = warn;
      if (warn) _buzz(HapticFeedback.lightImpact);
    }
    if (capped >= maxDuration && _recording && !_busy) {
      _buzz(HapticFeedback.heavyImpact);
      _onHint(VideoNoteHint.limitReached);
      unawaited(stopToPreview());
    }
  }

  /// Закрыть идущую часть и положить её в список.
  Future<void> _closeSegment() async {
    if (!_recording) return;
    final t0 = _segStartedAt;
    final live = t0 == null ? Duration.zero : clock.now().difference(t0);
    _banked += live;
    if (_banked > maxDuration) _banked = maxDuration;
    _recording = false;
    _segStartedAt = null;
    final isFront = _camera.isFront;
    String? path;
    try {
      path = await _camera.stopSegment();
    } catch (_) {
      path = null;
    }
    if (path != null && path.isNotEmpty) {
      _segments.add(VideoNoteSegment(path, isFront: isFront, length: live));
    }
    elapsed.value = _banked;
  }

  Future<void> _openSegment() async {
    await _camera.startSegment();
    _recording = true;
    _segStartedAt = clock.now();
  }

  Future<void> _release() async {
    if (phase.value != VideoNotePhase.holding) return;
    if (cancelArmed.value) {
      await cancel();
      return;
    }
    if (_now() < minDuration) {
      await _discardAll();
      _onHint(VideoNoteHint.tooShort);
      return;
    }
    await send();
  }

  /// Закрепить: палец можно убрать.
  void lock() {
    if (phase.value != VideoNotePhase.holding) return;
    _origin = null;
    drag.value = Offset.zero;
    cancelArmed.value = false;
    phase.value = VideoNotePhase.locked;
    _buzz(HapticFeedback.mediumImpact);
  }

  /// «Пауза» / «Продолжить» в закреплённой записи.
  Future<void> togglePause() async {
    if (_busy) return;
    final p = phase.value;
    if (p == VideoNotePhase.locked) {
      _busy = true;
      try {
        _ticker?.cancel();
        await _closeSegment();
        _tick();
        phase.value = VideoNotePhase.paused;
        _reapplyZoom();
        _buzz(HapticFeedback.selectionClick);
      } finally {
        _busy = false;
      }
    } else if (p == VideoNotePhase.paused) {
      if (_banked >= maxDuration) return;
      _busy = true;
      try {
        await _openSegment();
        _reapplyZoom();
        final at = _banked.inMicroseconds / 1e6;
        ranges.value = [...ranges.value, VideoNoteRange(at, at)];
        _startTicker();
        phase.value = VideoNotePhase.locked;
        _buzz(HapticFeedback.selectionClick);
      } catch (_) {
        _onHint(VideoNoteHint.cameraFailed);
      } finally {
        _busy = false;
      }
    }
  }

  /// Смена камеры — и во время записи (часть закрывается, новая открывается
  /// на другой камере; на контуре отрезок не рвётся).
  Future<void> flip() async {
    final p = phase.value;
    if (_busy || !_camera.canFlip) return;
    if (p != VideoNotePhase.holding &&
        p != VideoNotePhase.locked &&
        p != VideoNotePhase.paused) {
      return;
    }
    _busy = true;
    flipping.value = true;
    final wasRecording = _recording;
    try {
      if (wasRecording) {
        _ticker?.cancel();
        await _closeSegment();
      }
      light.value = false;
      _liftOrigin = null;
      _disableZoom();
      await _camera.flip();
      front.value = _camera.isFront;
      _buzz(HapticFeedback.selectionClick);
      if (wasRecording && phase.value != VideoNotePhase.cancelling) {
        await _openSegment();
        _startTicker();
      }
      // У новой камеры свой диапазон — снова 1×.
      if (_zoomPhase(phase.value)) _resetZoom();
    } catch (_) {
      _onHint(VideoNoteHint.cameraFailed);
    } finally {
      flipping.value = false;
      _busy = false;
    }
  }

  /// Подсветка: фронтальная — белый экран, основная — фонарик.
  Future<void> toggleLight() async {
    final next = !light.value;
    if (!_camera.isFront) {
      try {
        await _camera.setTorch(next);
      } catch (_) {
        return;
      }
    }
    light.value = next;
    _buzz(HapticFeedback.selectionClick);
  }

  /// «Стоп» (или лимит): остановить и показать по кругу.
  Future<void> stopToPreview() async {
    final p = phase.value;
    if (p != VideoNotePhase.holding &&
        p != VideoNotePhase.locked &&
        p != VideoNotePhase.paused) {
      return;
    }
    if (_busy && p != VideoNotePhase.paused) {
      // Смена камеры ещё идёт — дождёмся её конца.
      while (_busy) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      if (phase.value != p) return;
    }
    _busy = true;
    try {
      _origin = null;
      _ticker?.cancel();
      _ticker = null;
      await _closeSegment();
      drag.value = Offset.zero;
      cancelArmed.value = false;
      if (_segments.isEmpty) {
        await _abort();
        _onHint(VideoNoteHint.cameraFailed);
        return;
      }
      light.value = false;
      _disableZoom();
      unawaited(_camera.close().catchError((_) {}));
      _opening = null;
      _lengths = _segments.map((s) => s.length).toList(growable: false);
      _setTotal();
      previewPosition.value = Duration.zero;
      frames.value = List<String?>.filled(frameCount, null);
      phase.value = VideoNotePhase.preview;
      _buzz(HapticFeedback.lightImpact);
      await _startPreview();
    } finally {
      _busy = false;
    }
  }

  void _setTotal() {
    final sum = _lengths.fold<Duration>(Duration.zero, (a, b) => a + b);
    total.value = sum;
    trim.value = VideoNoteTrim(Duration.zero, sum);
  }

  Future<void> _startPreview() async {
    final factory = _previewFactory;
    final session = _session;
    if (factory != null) {
      try {
        final player = factory();
        _player = player;
        final real = await player.load(List.of(_segments));
        if (session != _session || phase.value != VideoNotePhase.preview) {
          return;
        }
        // Настоящие длины файлов точнее часов: камера стартует не мгновенно.
        if (real.length == _segments.length &&
            real.every((d) => d > Duration.zero)) {
          for (var i = 0; i < _segments.length; i++) {
            _segments[i] = _segments[i].withLength(real[i]);
          }
          _lengths = real;
          _setTotal();
        }
        player.position.addListener(_onPreviewPosition);
        player.view.addListener(_onPreviewView);
        _onPreviewView();
        await player.setRange(trim.value.start, trim.value.end);
        previewPlaying.value = true;
        await player.play();
      } catch (_) {
        // Посмотреть не вышло — отправить и удалить всё равно можно.
      }
    }
    final extractor = _frames;
    if (extractor != null) {
      unawaited(() async {
        try {
          final list = await extractor(
            List.of(_segments),
            _lengths,
            frameCount,
          );
          if (session == _session && phase.value == VideoNotePhase.preview) {
            frames.value = list;
          }
        } catch (_) {}
      }());
    }
  }

  void _onPreviewPosition() {
    final player = _player;
    if (player != null) previewPosition.value = player.position.value;
  }

  void _onPreviewView() {
    previewView.value = _player?.view.value;
  }

  Future<void> togglePreviewPlay() async {
    final player = _player;
    if (phase.value != VideoNotePhase.preview || player == null) return;
    _buzz(HapticFeedback.selectionClick);
    if (previewPlaying.value) {
      previewPlaying.value = false;
      await player.pause();
    } else {
      previewPlaying.value = true;
      await player.play();
    }
  }

  /// Обрезка: края ленты (доли 0…1 общей длины).
  void setTrim({double? startFraction, double? endFraction}) {
    if (phase.value != VideoNotePhase.preview) return;
    final all = total.value;
    if (all <= Duration.zero) return;
    var s = trim.value.start;
    var e = trim.value.end;
    Duration at(double f) =>
        Duration(microseconds: (all.inMicroseconds * f.clamp(0.0, 1.0)).round());
    final minLen = minTrim < all ? minTrim : all;
    if (startFraction != null) {
      s = at(startFraction);
      if (e - s < minLen) s = e - minLen;
      if (s < Duration.zero) s = Duration.zero;
    }
    if (endFraction != null) {
      e = at(endFraction);
      if (e - s < minLen) e = s + minLen;
      if (e > all) e = all;
    }
    final next = VideoNoteTrim(s, e);
    if (next == trim.value) return;
    trim.value = next;
    final player = _player;
    if (player != null) {
      unawaited(player.setRange(s, e));
      // Тянешь край — видишь его кадр.
      unawaited(player.seek(startFraction != null ? s : e - const Duration(milliseconds: 1)));
    }
  }

  /// Края обрезки отпущены: играть с начала выбранного.
  void trimSettled() {
    final player = _player;
    if (player == null || phase.value != VideoNotePhase.preview) return;
    _buzz(HapticFeedback.selectionClick);
    unawaited(player.seek(trim.value.start));
    if (!previewPlaying.value) {
      previewPlaying.value = true;
      unawaited(player.play());
    }
  }

  /// «Переснять»: снятое удаляется, кнопка снова готова.
  Future<void> retake() async {
    if (phase.value != VideoNotePhase.preview) return;
    _buzz(HapticFeedback.selectionClick);
    await _discardAll();
    _onHint(VideoNoteHint.retake);
  }

  /// Отправить: из удержания (отпускание), закреплённой, паузы, просмотра.
  Future<void> send() async {
    bool sendable(VideoNotePhase p) =>
        p == VideoNotePhase.holding ||
        p == VideoNotePhase.locked ||
        p == VideoNotePhase.paused ||
        p == VideoNotePhase.preview;
    if (!sendable(phase.value)) return;
    // Смена камеры или пауза ещё идут — дождёмся, иначе часть потеряется.
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    if (!sendable(phase.value)) return;
    _busy = true;
    try {
      _origin = null;
      _ticker?.cancel();
      _ticker = null;
      if (_recording) await _closeSegment();
      await _closePlayer();
      unawaited(_camera.close().catchError((_) {}));
      _opening = null;
      final segments = List<VideoNoteSegment>.of(_segments);
      _segments.clear();
      final all = segments.fold<Duration>(Duration.zero, (a, s) => a + s.length);
      final t = trim.value;
      final trimmed =
          phase.value == VideoNotePhase.preview &&
          t.end > t.start &&
          (t.start > Duration.zero || t.end < all);
      final duration = trimmed ? t.length : all;
      _reset();
      if (segments.isEmpty) {
        _onHint(VideoNoteHint.cameraFailed);
        return;
      }
      if (duration < minDuration) {
        for (final s in segments) {
          await _deleter(s.path);
        }
        _onHint(VideoNoteHint.tooShort);
        return;
      }
      _buzz(HapticFeedback.mediumImpact);
      final produce = _produce;
      await _onSend(
        VideoNoteRecorderResult(
          filePath: segments.first.path,
          durationMs: duration.inMilliseconds,
          firstSegmentIsFront: segments.first.isFront,
          prepare: () => produce(
            segments,
            trimStart: trimmed ? t.start : null,
            trimEnd: trimmed ? t.end : null,
          ),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  /// Корзина / отпускание со взведённой отменой.
  Future<void> cancel() async {
    final p = phase.value;
    if (p == VideoNotePhase.idle || p == VideoNotePhase.cancelling) return;
    _buzz(HapticFeedback.heavyImpact);
    _origin = null;
    phase.value = VideoNotePhase.cancelling;
    await _discardAll(keepPhase: true);
    _cancelTimer?.cancel();
    _cancelTimer = Timer(const Duration(milliseconds: 420), () {
      if (phase.value == VideoNotePhase.cancelling) _reset();
    });
  }

  /// Приложение ушло в фон: снятое не теряется — открывается просмотр.
  Future<void> appHidden() async {
    switch (phase.value) {
      case VideoNotePhase.arming:
        await cancel();
      case VideoNotePhase.holding:
      case VideoNotePhase.locked:
      case VideoNotePhase.paused:
        await stopToPreview();
        if (phase.value == VideoNotePhase.preview) {
          previewPlaying.value = false;
          await _player?.pause();
        }
      case VideoNotePhase.preview:
        previewPlaying.value = false;
        await _player?.pause();
      default:
        break;
    }
  }

  // ── Приближение ──────────────────────────────────────────────────────────

  static bool _zoomPhase(VideoNotePhase p) =>
      p == VideoNotePhase.holding ||
      p == VideoNotePhase.locked ||
      p == VideoNotePhase.paused;

  bool get _canZoomNow =>
      !_disposed &&
      zoomEnabled.value &&
      !flipping.value &&
      _zoomPhase(phase.value);

  /// Приближение [value] (обрезается диапазоном камеры). Отклик — на целых
  /// ступенях (2×, 3×…) и на краях.
  void setZoom(double value) {
    if (!_canZoomNow || !value.isFinite) return;
    final next = value.clamp(_minZoom, _maxZoom).toDouble();
    final prev = zoom.value;
    if ((next - prev).abs() < 0.001) return;
    final atEdge = next == _minZoom || next == _maxZoom;
    if (atEdge || prev.floor() != next.floor()) {
      _buzz(HapticFeedback.selectionClick);
    }
    zoom.value = next;
    _applyZoom();
  }

  /// Начало жеста по квадрату (щипок или сдвиг пальцем в замке).
  void zoomGestureStart() {
    _gestureBase = _canZoomNow ? zoom.value : null;
  }

  /// Щипок: [scale] — от начала жеста.
  void zoomPinch(double scale) {
    final base = _gestureBase;
    if (base == null || !scale.isFinite || scale <= 0) return;
    setZoom(base * scale);
  }

  /// Палец по квадрату в замке: [dy] — сдвиг от начала жеста (вверх < 0).
  /// Весь диапазон — за [zoomSpan] точек, равномерно по ступеням (2× → 4× —
  /// столько же пальца, что 1× → 2×).
  void zoomDrag(double dy) {
    final base = _gestureBase;
    final p = phase.value;
    if (base == null ||
        (p != VideoNotePhase.locked && p != VideoNotePhase.paused)) {
      return;
    }
    if (_maxZoom <= _minZoom) return;
    final ratio = _maxZoom / _minZoom;
    setZoom(base * math.pow(ratio, -dy / zoomSpan).toDouble());
  }

  void zoomGestureEnd() => _gestureBase = null;

  /// Палец, закрепивший запись, тянут выше замка: [zoomDeadZone] — ничего,
  /// дальше за [zoomSpan] — от приближения в миг замка до максимума.
  void _liftZoom(Offset position) {
    final origin = _liftOrigin;
    if (origin == null) return;
    final p = phase.value;
    if (p != VideoNotePhase.locked && p != VideoNotePhase.paused) {
      _liftOrigin = null;
      return;
    }
    if (!_canZoomNow) return;
    final up = origin.dy - position.dy;
    final t = ((up - lockDistance - zoomDeadZone) / zoomSpan)
        .clamp(0.0, 1.0)
        .toDouble();
    final base = _liftBase.clamp(_minZoom, _maxZoom).toDouble();
    if (_maxZoom <= base) return;
    setZoom(base * math.pow(_maxZoom / base, t).toDouble());
  }

  /// Камера сменилась или закрылась: приближение выключено до нового
  /// диапазона.
  void _disableZoom() {
    _zoomGen++;
    _gestureBase = null;
    _minZoom = 1;
    _maxZoom = 1;
    _zoomApplied = 1;
    if (_disposed) return;
    zoomEnabled.value = false;
    zoom.value = 1;
  }

  /// Узнать диапазон открытой камеры и встать на 1×. Не задерживает запись.
  void _resetZoom() {
    _disableZoom();
    final gen = _zoomGen;
    unawaited(() async {
      VideoNoteZoomRange? r;
      try {
        r = await _camera.zoomRange();
      } catch (_) {
        r = null;
      }
      if (_disposed || gen != _zoomGen || !_zoomPhase(phase.value)) return;
      if (r == null || !r.min.isFinite || !r.max.isFinite || r.min <= 0) {
        return;
      }
      final hi = math.min(r.max, math.max(maxZoomCap, r.min));
      if (hi - r.min < 0.01) return;
      _minZoom = r.min;
      _maxZoom = hi;
      // Новая камера сама стоит на 1×.
      _zoomApplied = 1;
      zoom.value = 1.0.clamp(_minZoom, _maxZoom).toDouble();
      zoomEnabled.value = true;
      _applyZoom();
    }());
  }

  /// Часть закрылась/открылась: на Android камера перестраивается и может
  /// забыть приближение — отдаём его заново.
  void _reapplyZoom() {
    if (!zoomEnabled.value || (zoom.value - 1).abs() < 0.001) return;
    _zoomApplied = null;
    _applyZoom();
  }

  /// Не больше одного вызова за раз; по его концу — последнее значение.
  /// Шаг плавного приближения (отменяется при закрытии).
  Timer? _zoomPace;
  bool _zoomClosed = false;

  void _applyZoom() {
    if (_zoomInFlight) return;
    _zoomInFlight = true;
    unawaited(() async {
      try {
        while (!_disposed && zoomEnabled.value) {
          final want = zoom.value;
          final done = _zoomApplied;
          if (done != null && (want - done).abs() < 0.001) break;
          final gen = _zoomGen;
          // 🔴 Плавно (22.11.2026, Android «поддёргивает»): камера Android
          // отвечает на setZoom за 30–60 мс, и прыжок сразу к цели давал
          // ступени. Идём к цели долями с шагом не чаще кадра — приближение
          // течёт, а не прыгает. Мелкий остаток — сразу в цель.
          final from = done ?? want;
          final gap = want - from;
          final next = !smoothZoom || gap.abs() <= 0.03
              ? want
              : from + gap * 0.35;
          final started = DateTime.now();
          try {
            await _camera.setZoom(next);
          } catch (_) {
            // Некоторые устройства бросают — не беда, запись идёт.
          }
          // Камеру сменили, пока шёл вызов: заново сверяемся с новой.
          if (gen != _zoomGen) continue;
          _zoomApplied = next;
          if (_disposed || _zoomClosed) break;
          final spent = DateTime.now().difference(started);
          const frame = Duration(milliseconds: 16);
          if (next != want && spent < frame) {
            final pace = Completer<void>();
            _zoomPace = Timer(frame - spent, pace.complete);
            await pace.future;
            _zoomPace = null;
          }
        }
      } finally {
        _zoomInFlight = false;
      }
    }());
  }

  // ── Служебное ────────────────────────────────────────────────────────────

  Future<void> _discardAll({bool keepPhase = false}) async {
    _ticker?.cancel();
    _ticker = null;
    _session++;
    if (_recording) {
      _recording = false;
      _segStartedAt = null;
      try {
        final path = await _camera.stopSegment();
        if (path != null) await _deleter(path);
      } catch (_) {}
    }
    await _closePlayer();
    final paths = _segments.map((s) => s.path).toList();
    _segments.clear();
    for (final path in paths) {
      await _deleter(path);
    }
    light.value = false;
    _opening = null;
    try {
      await _camera.close();
    } catch (_) {}
    if (!keepPhase) _reset();
  }

  Future<void> _closePlayer() async {
    final player = _player;
    _player = null;
    previewPlaying.value = false;
    previewView.value = null;
    if (player != null) {
      player.position.removeListener(_onPreviewPosition);
      player.view.removeListener(_onPreviewView);
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  void _reset() {
    _armTimer?.cancel();
    _armTimer = null;
    _ticker?.cancel();
    _ticker = null;
    _origin = null;
    _recording = false;
    _segStartedAt = null;
    _banked = Duration.zero;
    _releasedEarly = false;
    _interruptedEarly = false;
    _tapSend = false;
    _liftOrigin = null;
    _disableZoom();
    if (_disposed) return;
    drag.value = Offset.zero;
    cancelArmed.value = false;
    nearLimit.value = false;
    flipping.value = false;
    previewPlaying.value = false;
    previewPosition.value = Duration.zero;
    frames.value = const [];
    phase.value = VideoNotePhase.idle;
  }

  /// Экран чата уходит: всё снятое удаляется, камера закрывается.
  Future<void> dispose() async {
    _cancelTimer?.cancel();
    _zoomClosed = true;
    _zoomPace?.cancel();
    _zoomPace = null;
    await _discardAll(keepPhase: true);
    _disposed = true;
    _reset();
    for (final n in <ChangeNotifier>[
      phase,
      elapsed,
      ranges,
      nearLimit,
      drag,
      cancelArmed,
      front,
      light,
      flipping,
      zoom,
      zoomEnabled,
      trim,
      total,
      previewPosition,
      previewPlaying,
      frames,
      previewView,
    ]) {
      n.dispose();
    }
  }
}
