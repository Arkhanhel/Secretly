// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Автомат видео-заметки (макет 3b): каждая ветка жеста и каждая прежняя
// беда — отдельным сторожем.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/video_note_controller.dart';
import 'package:secretly_app/ui/chat/video_note_recorder.dart';

class FakeCamera implements VideoNoteCamera {
  bool permission = true;
  bool failOpen = false;
  bool open_ = false;
  bool front_ = true;
  bool recording = false;
  bool torch = false;
  int opened = 0;
  int closed = 0;
  int segments = 0;
  final List<String> log = [];
  final ValueNotifier<Widget?> _preview = ValueNotifier(null);

  /// Диапазон приближения (`null` — устройство не отвечает).
  VideoNoteZoomRange? range = const VideoNoteZoomRange(1, 120);
  final List<double> zoomCalls = [];
  bool zoomThrows = false;

  /// Пока не завершён — вызов приближения «висит» (проверка очереди).
  Completer<void>? zoomGate;
  int zoomInFlight = 0;
  int zoomMaxInFlight = 0;

  @override
  Future<VideoNoteZoomRange?> zoomRange() async => open_ ? range : null;

  @override
  Future<void> setZoom(double level) async {
    zoomCalls.add(level);
    zoomInFlight++;
    if (zoomInFlight > zoomMaxInFlight) zoomMaxInFlight = zoomInFlight;
    try {
      final gate = zoomGate;
      if (gate != null) await gate.future;
      if (zoomThrows) throw StateError('zoom not supported');
    } finally {
      zoomInFlight--;
    }
  }

  @override
  ValueListenable<Widget?> get preview => _preview;
  @override
  bool get isOpen => open_;
  @override
  bool get isFront => front_;
  @override
  bool get canFlip => true;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> open({required bool front}) async {
    if (failOpen) return;
    opened++;
    open_ = true;
    front_ = front;
    _preview.value = const SizedBox();
  }

  @override
  Future<void> startSegment() async {
    if (!open_) throw StateError('closed');
    recording = true;
    log.add('start');
  }

  @override
  Future<String?> stopSegment() async {
    if (!recording) return null;
    recording = false;
    segments++;
    log.add('stop');
    return '/tmp/seg$segments.mp4';
  }

  @override
  Future<void> flip() async {
    front_ = !front_;
    log.add('flip');
  }

  @override
  Future<void> setTorch(bool on) async => torch = on;
  @override
  Future<void> close() async {
    if (open_) closed++;
    open_ = false;
    _preview.value = null;
  }
}

class FakePlayer implements VideoNotePreviewPlayer {
  final ValueNotifier<Duration> _pos = ValueNotifier(Duration.zero);
  final ValueNotifier<Widget?> _view = ValueNotifier(null);
  bool playing = false;
  Duration? start;
  Duration? end;
  List<Duration>? real;

  @override
  Future<List<Duration>> load(List<VideoNoteSegment> segments) async =>
      real ?? segments.map((s) => s.length).toList();
  @override
  Future<void> play() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> setRange(Duration s, Duration e) async {
    start = s;
    end = e;
  }

  @override
  Future<void> seek(Duration p) async => _pos.value = p;
  @override
  ValueListenable<Duration> get position => _pos;
  @override
  ValueListenable<Widget?> get view => _view;
  @override
  Future<void> dispose() async {}
}

class H {
  H({this.smoothZoom = false}) {
    c = VideoNoteController(
      camera: cam,
      canStart: () async => true,
      onSend: (r) async => sent.add(r),
      onHint: hints.add,
      previewPlayer: () => player,
      produce: (segs, {trimStart, trimEnd}) async {
        produced.add((segs, trimStart, trimEnd));
        return '/tmp/out.mp4';
      },
      deleteFile: (p) async => deleted.add(p),
      haptics: false,
      smoothZoom: smoothZoom,
    );
  }
  final cam = FakeCamera();
  final player = FakePlayer();
  final bool smoothZoom;
  late final VideoNoteController c;
  final sent = <VideoNoteRecorderResult>[];
  final hints = <VideoNoteHint>[];
  final deleted = <String>[];
  final produced = <(List<VideoNoteSegment>, Duration?, Duration?)>[];
}

const _o = Offset(350, 790);

Future<void> _hold(WidgetTester t, H h, [Duration d = const Duration(seconds: 3)]) async {
  h.c.pointerDown(_o);
  await t.pump(const Duration(milliseconds: 160));
  await t.pump();
  expect(h.c.phase.value, VideoNotePhase.holding);
  await t.pump(d);
}

void main() {
  testWidgets('короткое касание: камера открыта впрок и закрыта, касание', (
    t,
  ) async {
    final h = H();
    h.c.pointerDown(_o);
    await t.pump(const Duration(milliseconds: 60));
    expect(h.cam.opened, 1, reason: 'камера открывается сразу при касании');
    expect(h.c.pointerUp(), isTrue);
    await t.pump();
    expect(h.cam.isOpen, isFalse);
    expect(h.c.phase.value, VideoNotePhase.idle);
    expect(h.cam.log, isEmpty);
  });

  testWidgets('удержание и отпускание — отправка, длина и камера', (t) async {
    final h = H();
    await _hold(t, h);
    h.c.pointerUp();
    await t.pump();
    expect(h.sent, hasLength(1));
    expect(h.sent.single.durationMs, inInclusiveRange(2900, 3200));
    expect(h.sent.single.firstSegmentIsFront, isTrue);
    expect(h.c.phase.value, VideoNotePhase.idle);
    expect(h.cam.isOpen, isFalse);
    await h.sent.single.prepare!();
    expect(h.produced.single.$2, isNull, reason: 'без обрезки');
  });

  testWidgets('🔴 отмена — только по отпусканию; вернул палец — снята', (t) async {
    final h = H();
    await _hold(t, h);
    h.c.pointerMove(_o + const Offset(-140, 4));
    expect(h.c.cancelArmed.value, isTrue);
    expect(h.cam.recording, isTrue, reason: 'запись идёт');
    h.c.pointerMove(_o + const Offset(-30, 0));
    expect(h.c.cancelArmed.value, isFalse);
    h.c.pointerMove(_o + const Offset(-150, 0));
    h.c.pointerUp();
    await t.pump();
    expect(h.c.phase.value, VideoNotePhase.cancelling);
    expect(h.sent, isEmpty);
    expect(h.deleted, ['/tmp/seg1.mp4']);
    await t.pump(const Duration(milliseconds: 500));
    expect(h.c.phase.value, VideoNotePhase.idle);
  });

  testWidgets('замок вверх; пауза режет на части; отправка из паузы', (t) async {
    final h = H();
    await _hold(t, h, const Duration(seconds: 2));
    h.c.pointerMove(_o + const Offset(-5, -95));
    expect(h.c.phase.value, VideoNotePhase.locked);
    h.c.pointerUp();
    await t.pump(const Duration(seconds: 1));
    expect(h.sent, isEmpty, reason: 'отпускание в замке не отправляет');
    await h.c.togglePause();
    expect(h.c.phase.value, VideoNotePhase.paused);
    final paused = h.c.elapsed.value;
    await t.pump(const Duration(seconds: 2));
    expect(h.c.elapsed.value, paused, reason: 'в паузе время стоит');
    await h.c.togglePause();
    expect(h.c.phase.value, VideoNotePhase.locked);
    await t.pump(const Duration(seconds: 1));
    expect(h.c.ranges.value, hasLength(2), reason: 'новый отрезок контура');
    await h.c.togglePause();
    // «Отправить» той же кнопкой.
    h.c.pointerDown(_o);
    h.c.pointerUp();
    await t.pump();
    expect(h.sent, hasLength(1));
    await h.sent.single.prepare!();
    expect(h.produced.single.$1, hasLength(2));
    expect(h.sent.single.durationMs, inInclusiveRange(3900, 4300));
  });

  testWidgets('смена камеры посреди записи: кусок закрыт, новый открыт', (
    t,
  ) async {
    final h = H();
    await _hold(t, h, const Duration(seconds: 2));
    h.c.lock();
    await h.c.flip();
    expect(h.cam.log, ['start', 'stop', 'flip', 'start']);
    expect(h.c.front.value, isFalse);
    expect(h.c.ranges.value, hasLength(1), reason: 'контур не рвётся');
    await t.pump(const Duration(seconds: 1));
    await h.c.send();
    final segs = h.produced.isEmpty
        ? (await h.sent.single.prepare!(), h.produced.single.$1).$2
        : h.produced.single.$1;
    expect(segs.map((s) => s.isFront), [true, false]);
  });

  testWidgets('🔴 лимит минуты: жёлтый за 10 с, потом просмотр, не отправка', (
    t,
  ) async {
    final h = H();
    await _hold(t, h, const Duration(seconds: 1));
    h.c.lock();
    await t.pump(const Duration(seconds: 48));
    expect(h.c.nearLimit.value, isFalse);
    await t.pump(const Duration(seconds: 2));
    expect(h.c.nearLimit.value, isTrue);
    await t.pump(const Duration(seconds: 10));
    await t.pump();
    expect(h.c.phase.value, VideoNotePhase.preview);
    expect(h.hints, contains(VideoNoteHint.limitReached));
    expect(h.sent, isEmpty);
    expect(h.c.elapsed.value, const Duration(seconds: 60));
    expect(h.player.playing, isTrue, reason: 'просмотр по кругу');
    expect(h.cam.isOpen, isFalse, reason: 'камера свободна в просмотре');
  });

  testWidgets('просмотр: обрезка уходит в итоговый файл и длину', (t) async {
    final h = H()..player.real = const [Duration(seconds: 10)];
    await _hold(t, h, const Duration(seconds: 9));
    h.c.lock();
    await h.c.stopToPreview();
    expect(h.c.total.value, const Duration(seconds: 10),
        reason: 'длина — по настоящему файлу');
    h.c.setTrim(startFraction: 0.2);
    h.c.setTrim(endFraction: 0.7);
    expect(h.c.trim.value.start, const Duration(seconds: 2));
    expect(h.c.trim.value.end, const Duration(seconds: 7));
    expect(h.player.start, const Duration(seconds: 2));
    // Края не сходятся ближе секунды.
    h.c.setTrim(startFraction: 0.69);
    expect(h.c.trim.value.length, const Duration(seconds: 1));
    h.c.setTrim(startFraction: 0.2);
    await h.c.send();
    expect(h.sent.single.durationMs, 5000);
    await h.sent.single.prepare!();
    expect(h.produced.single.$2, const Duration(seconds: 2));
    expect(h.produced.single.$3, const Duration(seconds: 7));
  });

  testWidgets('«Переснять» удаляет снятое и подсказывает', (t) async {
    final h = H();
    await _hold(t, h);
    h.c.lock();
    await h.c.stopToPreview();
    await h.c.retake();
    expect(h.c.phase.value, VideoNotePhase.idle);
    expect(h.deleted, ['/tmp/seg1.mp4']);
    expect(h.hints, [VideoNoteHint.retake]);
  });

  testWidgets('🔴 отпускание, пока камера открывается, не теряется', (t) async {
    final h = H();
    h.c.pointerDown(_o);
    await t.pump(const Duration(milliseconds: 155));
    // Фаза arming: палец уже поднят.
    h.c.pointerUp();
    await t.pump();
    await t.pump();
    expect(h.c.phase.value, VideoNotePhase.idle);
    expect(h.hints, [VideoNoteHint.tooShort]);
    expect(h.sent, isEmpty);
  });

  testWidgets('🔴 системное прерывание закрепляет запись', (t) async {
    final h = H();
    await _hold(t, h);
    h.c.pointerCancel();
    expect(h.c.phase.value, VideoNotePhase.locked);
    expect(h.cam.recording, isTrue);
    await h.c.dispose();
  });

  testWidgets('🔴 свернули приложение — снятое остаётся, открыт просмотр', (
    t,
  ) async {
    final h = H();
    await _hold(t, h);
    h.c.lock();
    await h.c.appHidden();
    expect(h.c.phase.value, VideoNotePhase.preview);
    expect(h.player.playing, isFalse);
    expect(h.deleted, isEmpty);
  });

  testWidgets('подсветка: фронтальная — экран, основная — фонарик', (t) async {
    final h = H();
    await _hold(t, h);
    await h.c.toggleLight();
    expect(h.c.light.value, isTrue);
    expect(h.cam.torch, isFalse);
    await h.c.flip();
    expect(h.c.light.value, isFalse, reason: 'новая камера — без подсветки');
    await h.c.toggleLight();
    expect(h.cam.torch, isTrue);
    await h.c.dispose();
  });

  testWidgets('нет доступа и сломанная камера — подсказки', (t) async {
    final h = H()..cam.permission = false;
    h.c.pointerDown(_o);
    await t.pump(const Duration(milliseconds: 160));
    await t.pump();
    expect(h.hints, [VideoNoteHint.noPermission]);
    final h2 = H()..cam.failOpen = true;
    h2.c.pointerDown(_o);
    await t.pump(const Duration(milliseconds: 160));
    await t.pump();
    expect(h2.hints, [VideoNoteHint.cameraFailed]);
    expect(h2.c.phase.value, VideoNotePhase.idle);
  });

  testWidgets('экран ушёл посреди записи — всё удалено, камера закрыта', (
    t,
  ) async {
    final h = H();
    await _hold(t, h);
    await h.c.dispose();
    expect(h.cam.isOpen, isFalse);
    expect(h.deleted, ['/tmp/seg1.mp4']);
  });

  // ── Приближение ─────────────────────────────────────────────────────────

  testWidgets('щипок: в пределах камеры, потолок 10×, камере — значения', (
    t,
  ) async {
    final h = H(smoothZoom: true);
    await _hold(t, h, const Duration(milliseconds: 500));
    expect(h.c.zoomEnabled.value, isTrue);
    expect(h.c.zoom.value, 1);
    expect(h.c.maxZoom, 10, reason: 'устройство сообщает ×120 — потолок 10');
    h.c.zoomGestureStart();
    h.c.zoomPinch(2);
    expect(h.c.zoom.value, closeTo(2, 1e-9));
    // Камера идёт к цели плавно (долями, 22.11.2026) и приходит в неё.
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(h.cam.zoomCalls.last, closeTo(2, 1e-9));
    for (var i = 1; i < h.cam.zoomCalls.length; i++) {
      expect(
        (h.cam.zoomCalls[i] - h.cam.zoomCalls[i - 1]).abs(),
        lessThanOrEqualTo(0.6),
        reason: 'без ступеней: шаг к цели — доля, а не прыжок',
      );
    }
    h.c.zoomPinch(50);
    expect(h.c.zoom.value, 10);
    h.c.zoomPinch(0.01);
    expect(h.c.zoom.value, 1);
    h.c.zoomGestureEnd();
    // Щипок не трогает ни отмену, ни замок.
    expect(h.c.phase.value, VideoNotePhase.holding);
    expect(h.c.cancelArmed.value, isFalse);
    expect(h.c.drag.value, Offset.zero);
    await h.c.dispose();
  });

  testWidgets('камере — не больше одного вызова за раз, последнее значение', (
    t,
  ) async {
    final h = H(smoothZoom: true);
    await _hold(t, h, const Duration(milliseconds: 500));
    h.cam.zoomGate = Completer<void>();
    h.c.zoomGestureStart();
    for (final s in [1.5, 2.0, 2.5, 3.0, 3.5]) {
      h.c.zoomPinch(s);
    }
    await t.pump();
    expect(h.cam.zoomCalls.length, 1, reason: 'остальные ждут первого');
    final gate = h.cam.zoomGate!;
    h.cam.zoomGate = null;
    gate.complete();
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(h.cam.zoomCalls.last, closeTo(3.5, 1e-9),
        reason: 'идёт к последнему значению, промежуточные цели пропущены');
    expect(h.cam.zoomMaxInFlight, 1);
    await h.c.dispose();
  });

  testWidgets('🔴 до замка палец не приближает (и отмена влево — как была)', (
    t,
  ) async {
    final h = H();
    await _hold(t, h, const Duration(seconds: 2));
    h.c.pointerMove(_o + const Offset(0, -60));
    h.c.pointerMove(_o + const Offset(-3, -89));
    expect(h.c.phase.value, VideoNotePhase.holding);
    h.c.pointerMove(_o + const Offset(-140, -20));
    expect(h.c.cancelArmed.value, isTrue);
    h.c.pointerMove(_o + const Offset(-30, -10));
    expect(h.c.cancelArmed.value, isFalse);
    await t.pump();
    expect(h.c.zoom.value, 1);
    expect(h.cam.zoomCalls, isEmpty);
    await h.c.dispose();
  });

  testWidgets('🔴 палец выше замка НЕ приближает (слово владельца 22.11)', (
    t,
  ) async {
    final h = H();
    await _hold(t, h, const Duration(seconds: 2));
    h.c.pointerMove(_o + const Offset(0, -95));
    expect(h.c.phase.value, VideoNotePhase.locked);
    h.c.pointerMove(_o + const Offset(0, -236));
    h.c.pointerMove(_o + const Offset(0, -600));
    expect(h.c.zoom.value, 1);
    expect(h.c.pointerUp(), isFalse);
    await t.pump(const Duration(seconds: 1));
    expect(h.c.phase.value, VideoNotePhase.locked);
    expect(h.c.zoom.value, 1);
    expect(h.sent, isEmpty);
    await h.c.dispose();
  });

  testWidgets('в замке палец по квадрату: вверх — ближе, вниз — дальше', (
    t,
  ) async {
    final h = H();
    await _hold(t, h, const Duration(seconds: 1));
    // В удержании один палец по квадрату не приближает.
    h.c.zoomGestureStart();
    h.c.zoomDrag(-110);
    h.c.zoomGestureEnd();
    expect(h.c.zoom.value, 1);
    h.c.lock();
    h.c.zoomGestureStart();
    h.c.zoomDrag(-110);
    expect(h.c.zoom.value, closeTo(3.1623, 1e-3));
    h.c.zoomGestureEnd();
    // Следующий жест — от достигнутого.
    h.c.zoomGestureStart();
    h.c.zoomDrag(55);
    expect(h.c.zoom.value, closeTo(math.pow(10, 0.25), 1e-3));
    h.c.zoomDrag(400);
    expect(h.c.zoom.value, 1);
    h.c.zoomGestureEnd();
    await h.c.dispose();
  });

  testWidgets('смена камеры — снова 1×; пауза хранит; в просмотре нет', (
    t,
  ) async {
    final h = H();
    await _hold(t, h, const Duration(seconds: 1));
    h.c.lock();
    h.c.zoomGestureStart();
    h.c.zoomPinch(2);
    h.c.zoomGestureEnd();
    await t.pump();
    // Пауза: приближение то же и отдаётся камере заново (Android
    // перестраивает камеру между частями).
    final before = h.cam.zoomCalls.length;
    await h.c.togglePause();
    await t.pump();
    expect(h.c.zoom.value, closeTo(2, 1e-9));
    await h.c.togglePause();
    await t.pump();
    expect(h.c.zoom.value, closeTo(2, 1e-9));
    expect(h.cam.zoomCalls.length, greaterThan(before));
    expect(h.cam.zoomCalls.last, closeTo(2, 1e-9));
    // Смена камеры.
    h.cam.range = const VideoNoteZoomRange(1, 4);
    await h.c.flip();
    expect(h.c.zoom.value, 1);
    await t.pump();
    expect(h.c.zoomEnabled.value, isTrue);
    expect(h.c.maxZoom, 4, reason: 'у новой камеры свой диапазон');
    h.c.zoomGestureStart();
    h.c.zoomPinch(9);
    expect(h.c.zoom.value, 4);
    h.c.zoomGestureEnd();
    // Просмотр — без приближения.
    await t.pump(const Duration(seconds: 1));
    await h.c.stopToPreview();
    expect(h.c.zoomEnabled.value, isFalse);
    expect(h.c.zoom.value, 1);
    final calls = h.cam.zoomCalls.length;
    h.c.zoomGestureStart();
    h.c.zoomPinch(3);
    h.c.setZoom(3);
    await t.pump();
    expect(h.c.zoom.value, 1);
    expect(h.cam.zoomCalls.length, calls);
    await h.c.dispose();
  });

  testWidgets('диапазон не узнать / камера бросает — тихо, запись идёт', (
    t,
  ) async {
    final h = H()..cam.range = null;
    await _hold(t, h, const Duration(milliseconds: 500));
    expect(h.c.zoomEnabled.value, isFalse);
    h.c.zoomGestureStart();
    h.c.zoomPinch(3);
    expect(h.c.zoom.value, 1);
    expect(h.cam.zoomCalls, isEmpty);
    await h.c.dispose();

    final h2 = H()..cam.zoomThrows = true;
    await _hold(t, h2, const Duration(seconds: 2));
    h2.c.zoomGestureStart();
    h2.c.zoomPinch(3);
    await t.pump();
    h2.c.zoomPinch(4);
    await t.pump();
    expect(h2.c.zoom.value, closeTo(4, 1e-9));
    expect(h2.cam.zoomCalls, hasLength(2));
    expect(h2.cam.recording, isTrue);
    h2.c.pointerUp();
    await t.pump();
    expect(h2.sent, hasLength(1), reason: 'ошибка приближения не мешает');
  });

  test('куски для обрезки', () {
    const a = VideoNoteSegment('a', isFront: true, length: Duration(seconds: 4));
    const b = VideoNoteSegment('b', isFront: false, length: Duration(seconds: 6));
    final all = videoNotePieces(const [a, b]);
    expect(all.every((p) => p.whole), isTrue);
    final cut = videoNotePieces(
      const [a, b],
      trimStart: const Duration(seconds: 5),
      trimEnd: const Duration(seconds: 8),
    );
    expect(cut, hasLength(1));
    expect(cut.single.segment.path, 'b');
    expect(cut.single.from, const Duration(seconds: 1));
    expect(cut.single.to, const Duration(seconds: 4));
    final both = videoNotePieces(
      const [a, b],
      trimStart: const Duration(seconds: 1),
      trimEnd: const Duration(seconds: 9),
    );
    expect(both.map((p) => p.segment.path), ['a', 'b']);
    expect(both.first.from, const Duration(seconds: 1));
    expect(both.first.to, isNull);
    expect(both.last.from, isNull);
    expect(both.last.to, const Duration(seconds: 5));
  });
}
