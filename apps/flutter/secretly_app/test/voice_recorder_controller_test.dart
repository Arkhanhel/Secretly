// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// Автомат записи голосового: каждая ветка жеста и каждая прежняя поломка
// (отмена до отпускания, потерянное раннее отпускание, потеря записи при
// системном прерывании) — отдельным сторожем.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/ui/chat/voice_recorder_controller.dart';

class _FakeBackend implements VoiceRecorderBackend {
  _FakeBackend({this.startDelay = Duration.zero});

  final Duration startDelay;
  final StreamController<double> levelsCtl = StreamController<double>.broadcast();
  String? started;
  bool stopped = false;
  bool cancelled = false;
  bool permission = true;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> start(String path) async {
    if (startDelay > Duration.zero) await Future<void>.delayed(startDelay);
    started = path;
  }

  @override
  Future<String?> stop() async {
    stopped = true;
    return started;
  }

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Stream<double> levels() => levelsCtl.stream;
}

class _FakePlayer implements VoicePreviewPlayer {
  String? loaded;
  bool playing = false;
  final StreamController<Duration> pos = StreamController<Duration>.broadcast();
  final StreamController<bool> done = StreamController<bool>.broadcast();

  @override
  Future<void> load(String path) async => loaded = path;
  @override
  Future<void> play() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> seek(Duration position) async {}
  @override
  Stream<Duration> get position => pos.stream;
  @override
  Stream<bool> get completed => done.stream;
  @override
  Future<void> dispose() async {}
}

class _Harness {
  _Harness({Duration startDelay = Duration.zero})
    : backend = _FakeBackend(startDelay: startDelay) {
    controller = VoiceRecorderController(
      backend: backend,
      newTempPath: () async => '/tmp/voice_test.m4a',
      canStart: () async => true,
      onSend: (t) async => sent.add(t),
      onHint: hints.add,
      previewPlayer: () => player,
      deleteFile: (path) async => deleted.add(path),
      haptics: false,
    );
  }

  final _FakeBackend backend;
  final _FakePlayer player = _FakePlayer();
  late final VoiceRecorderController controller;
  final List<VoiceTake> sent = <VoiceTake>[];
  final List<VoiceHint> hints = <VoiceHint>[];
  final List<String> deleted = <String>[];
}

const _o = Offset(350, 790);

Future<void> _hold(WidgetTester t, _Harness h, {Duration speak = const Duration(seconds: 2)}) async {
  h.controller.pointerDown(_o);
  await t.pump(const Duration(milliseconds: 160));
  await t.pump();
  expect(h.controller.phase.value, VoicePhase.holding);
  for (var i = 0; i < 10; i++) {
    h.backend.levelsCtl.add(0.2 + i * 0.07);
  }
  await t.pump(speak);
}

void main() {
  testWidgets('короткое касание — подсказка, записи нет', (t) async {
    final h = _Harness();
    h.controller.pointerDown(_o);
    await t.pump(const Duration(milliseconds: 80));
    expect(h.controller.pointerUp(), isTrue);
    await t.pump(const Duration(milliseconds: 200));
    expect(h.hints, [VoiceHint.holdToRecord]);
    expect(h.backend.started, isNull);
    expect(h.controller.phase.value, VoicePhase.idle);
  });

  testWidgets('удержание и отпускание — отправка с волной', (t) async {
    final h = _Harness();
    await _hold(t, h);
    h.controller.pointerUp();
    await t.pump();
    expect(h.sent, hasLength(1));
    expect(h.sent.single.path, '/tmp/voice_test.m4a');
    expect(h.sent.single.waveform, hasLength(48));
    expect(h.sent.single.duration, greaterThan(const Duration(seconds: 1)));
    expect(h.controller.phase.value, VoicePhase.idle);
  });

  testWidgets('🔴 отпускание, пока рекордер запускается, не теряется', (t) async {
    final h = _Harness(startDelay: const Duration(milliseconds: 400));
    h.controller.pointerDown(_o);
    await t.pump(const Duration(milliseconds: 160));
    expect(h.controller.phase.value, VoicePhase.arming);
    // Палец поднят раньше, чем микрофон ожил.
    h.controller.pointerUp();
    await t.pump(const Duration(milliseconds: 500));
    await t.pump();
    // Запись не висит: слишком коротко — подсказка и покой.
    expect(h.controller.phase.value, VoicePhase.idle);
    expect(h.hints, contains(VoiceHint.tooShort));
    expect(h.sent, isEmpty);
  });

  testWidgets('🔴 отмена — только по отпусканию; вернул палец — снята', (t) async {
    final h = _Harness();
    await _hold(t, h);
    h.controller.pointerMove(_o + const Offset(-140, 5));
    expect(h.controller.cancelArmed.value, isTrue);
    // Отмена ещё НЕ случилась — запись идёт.
    expect(h.controller.phase.value, VoicePhase.holding);
    expect(h.backend.cancelled, isFalse);
    h.controller.pointerMove(_o + const Offset(-40, 0));
    expect(h.controller.cancelArmed.value, isFalse);
    h.controller.pointerMove(_o + const Offset(-150, 0));
    h.controller.pointerUp();
    await t.pump();
    expect(h.controller.phase.value, VoicePhase.cancelling);
    expect(h.backend.cancelled, isTrue);
    expect(h.sent, isEmpty);
    await t.pump(const Duration(seconds: 1));
    expect(h.controller.phase.value, VoicePhase.idle);
  });

  testWidgets('вверх — замок; отпускание не отправляет; «Отправить» — да', (
    t,
  ) async {
    final h = _Harness();
    await _hold(t, h);
    h.controller.pointerMove(_o + const Offset(-10, -95));
    expect(h.controller.phase.value, VoicePhase.locked);
    h.controller.pointerUp();
    await t.pump();
    expect(h.sent, isEmpty);
    // Касание «Отправить» в закреплённой записи.
    h.controller.pointerDown(_o);
    h.controller.pointerUp();
    await t.pump();
    expect(h.sent, hasLength(1));
  });

  testWidgets('доминирующая ось: косое движение не запирает', (t) async {
    final h = _Harness();
    await _hold(t, h);
    h.controller.pointerMove(_o + const Offset(-100, -95));
    expect(h.controller.phase.value, VoicePhase.holding);
    expect(h.controller.cancelArmed.value, isFalse);
    await h.controller.dispose();
  });

  testWidgets('🔴 системное прерывание закрепляет запись, а не теряет', (
    t,
  ) async {
    final h = _Harness();
    await _hold(t, h);
    h.controller.pointerCancel();
    expect(h.controller.phase.value, VoicePhase.locked);
    expect(h.backend.cancelled, isFalse);
    await h.controller.dispose();
    // Экран ушёл посреди записи — микрофон остановлен, файл удалён.
    expect(h.backend.cancelled, isTrue);
    expect(h.deleted, ['/tmp/voice_test.m4a']);
  });

  testWidgets('«Стоп» — прослушивание; отправка из прослушивания', (t) async {
    final h = _Harness();
    await _hold(t, h);
    h.controller.lock();
    await h.controller.stopToPreview();
    expect(h.controller.phase.value, VoicePhase.preview);
    expect(h.player.loaded, '/tmp/voice_test.m4a');
    await h.controller.togglePreview();
    expect(h.player.playing, isTrue);
    expect(h.controller.previewPlaying.value, isTrue);
    await h.controller.send();
    expect(h.sent, hasLength(1));
    expect(h.controller.phase.value, VoicePhase.idle);
  });

  testWidgets('корзина в закреплённой записи удаляет', (t) async {
    final h = _Harness();
    await _hold(t, h);
    h.controller.lock();
    await h.controller.cancel();
    expect(h.backend.cancelled, isTrue);
    expect(h.deleted, ['/tmp/voice_test.m4a']);
    expect(h.sent, isEmpty);
    await t.pump(const Duration(seconds: 1));
    expect(h.controller.phase.value, VoicePhase.idle);
  });

  testWidgets('нет доступа к микрофону — подсказка', (t) async {
    final h = _Harness()..backend.permission = false;
    h.controller.pointerDown(_o);
    await t.pump(const Duration(milliseconds: 160));
    await t.pump();
    expect(h.hints, [VoiceHint.noPermission]);
    expect(h.controller.phase.value, VoicePhase.idle);
  });

  testWidgets('🔴 Н-7: чат закрыли, пока микрофон запускался — рекордер остановлен, файл стёрт', (t) async {
    final h = _Harness(startDelay: const Duration(milliseconds: 300));
    h.controller.pointerDown(_o);
    await t.pump(const Duration(milliseconds: 160));
    expect(h.controller.phase.value, VoicePhase.arming);
    // Экран уходит посреди запуска.
    await h.controller.dispose();
    expect(h.backend.cancelled, isFalse);
    await t.pump(const Duration(milliseconds: 400));
    expect(h.backend.started, '/tmp/voice_test.m4a');
    expect(h.backend.cancelled, isTrue);
    expect(h.deleted, ['/tmp/voice_test.m4a']);
    expect(h.sent, isEmpty);
    expect(h.hints, isEmpty);
  });

  test('огибающая: число столбиков и нормировка', () {
    final w = voiceWaveformFrom([0.1, 0.2, 0.5, 0.25], 8);
    expect(w, hasLength(8));
    expect(w.reduce((a, b) => a > b ? a : b), 100);
    expect(voiceWaveformFrom(const [], 48), hasLength(48));
  });
}
