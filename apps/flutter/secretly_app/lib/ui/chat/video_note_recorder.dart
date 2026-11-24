// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Видео-заметка: камера, просмотр и итоговый файл.
///
/// Автомат записи — [VideoNoteController] (`video_note_controller.dart`), вид —
/// `video_note_ui.dart`. Здесь — то, что трогает настоящие камеру, плеер и
/// FFmpeg: [CameraVideoNoteCamera], [VideoPlayerNotePreview],
/// [extractVideoNoteFrames], [produceVideoNoteFile].
///
/// 🔴 FFmpeg — только при `kVideoToolsAvailable` (облегчённая сборка его не
/// везёт): заслонка у входа в возможность — в чате кнопка видеорежима не
/// появляется, `canStart` отказывает; здесь — вторая, у самих вызовов FFmpeg.
library;

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../../build_variant.dart';
import '../../media/h264_encoder.dart';
import 'video_note_controller.dart';

/// Готовая видео-заметка — уходит в очередь отправки.
class VideoNoteRecorderResult {
  const VideoNoteRecorderResult({
    required this.filePath,
    required this.durationMs,
    this.prepare,
    this.firstSegmentIsFront = false,
  });

  /// Первый кусок снят фронтальной камерой — для кадра в пузыре очереди.
  final bool firstSegmentIsFront;

  /// Первый сырой кусок: годится для кадра пузыря, пока делается итоговый
  /// файл. Вызывающий отвечает за удаление.
  final String filePath;

  /// Длина в миллисекундах (после обрезки).
  final int durationMs;

  /// Скорость отправки (15.11.2026, владелец: «после зелёной стрелки
  /// несколько секунд ничего не происходит»): склейка, зеркало и обрезка
  /// (FFmpeg) идут уже в очереди отправки, пока в чате виден пузырь с кольцом.
  /// Возвращает путь итогового `.mp4` (сырые куски удаляет сама) или `null`.
  final Future<String?> Function()? prepare;
}

/// Один кусок записи: между паузами и сменами камеры. `isFront` решает,
/// отзеркалить ли его в итоговом файле (фронтальная камера пишет кадр НЕ
/// зеркальным — наоборот тому, что человек видел при съёмке).
@immutable
class VideoNoteSegment {
  const VideoNoteSegment(
    this.path, {
    required this.isFront,
    this.length = Duration.zero,
  });

  final String path;
  final bool isFront;
  final Duration length;

  VideoNoteSegment withLength(Duration value) =>
      VideoNoteSegment(path, isFront: isFront, length: value);
}

/// Кусок с обрезкой: [from]/[to] — внутри файла, `null` — без края.
@immutable
class VideoNotePiece {
  const VideoNotePiece(this.segment, {this.from, this.to});
  final VideoNoteSegment segment;
  final Duration? from;
  final Duration? to;
  bool get whole => from == null && to == null;
}

/// Какие куски и с какими краями попадают в итоговый файл при обрезке
/// [trimStart]…[trimEnd] (в общей длине записи). Без обрезки — все целиком.
List<VideoNotePiece> videoNotePieces(
  List<VideoNoteSegment> segments, {
  Duration? trimStart,
  Duration? trimEnd,
}) {
  if (trimStart == null && trimEnd == null) {
    return [for (final s in segments) VideoNotePiece(s)];
  }
  final out = <VideoNotePiece>[];
  var offset = Duration.zero;
  for (var i = 0; i < segments.length; i++) {
    final s = segments[i];
    final start = offset;
    final end = offset + s.length;
    final last = i == segments.length - 1;
    offset = end;
    final a = trimStart ?? Duration.zero;
    final b = trimEnd;
    if (b != null && start >= b) break;
    // Последний кусок не отбрасываем по длине: часы записи чуть отстают
    // от настоящего файла.
    if (!last && end <= a) continue;
    final from = a > start ? a - start : null;
    final to = (b != null && b < end) ? b - start : null;
    out.add(VideoNotePiece(s, from: from, to: to));
  }
  return out;
}

/// Итоговый файл заметки из кусков записи (с обрезкой). Вызывается из
/// очереди отправки.
///
/// * один кусок с основной камеры, без обрезки → копия (поворот уже зашит
///   камерой, квадрат даёт кадрирование пузыря);
/// * фронтальная камера или обрезка → перекодирование в квадрат (+ зеркало);
/// * несколько кусков → склейка фильтром concat: каждый приводится к одному
///   квадрату, фронтальные зеркалятся, края обрезки — у каждого входа.
Future<String?> produceVideoNoteFile(
  List<VideoNoteSegment> segments, {
  Duration? trimStart,
  Duration? trimEnd,
}) async {
  if (segments.isEmpty) return null;
  if (!kVideoToolsAvailable) {
    // Без FFmpeg: первый кусок как есть (сюда не попадаем — заслонка в чате).
    return _persistSingleSegment(segments.first.path);
  }
  final pieces = videoNotePieces(
    segments,
    trimStart: trimStart,
    trimEnd: trimEnd,
  );
  String? produced;
  if (pieces.isEmpty) {
    produced = null;
  } else if (pieces.length == 1) {
    final only = pieces.single;
    produced = (!only.segment.isFront && only.whole)
        ? await _persistSingleSegment(only.segment.path)
        : await _encodeSquareSingle(only);
  } else {
    produced = await _concatPieces(pieces);
  }
  for (final seg in segments) {
    if (produced == null || p.normalize(seg.path) != p.normalize(produced)) {
      await _deleteIfAny(seg.path);
    }
  }
  if (produced == null || produced.isEmpty) return null;
  return produced;
}

Future<String> _newNotePath() async {
  final dir = await getTemporaryDirectory();
  return p.join(
    dir.path,
    'video_note_${DateTime.now().microsecondsSinceEpoch}.mp4',
  );
}

Future<String> _persistSingleSegment(String path) async {
  try {
    final dest = await _newNotePath();
    final src = File(path);
    if (await src.exists() && p.normalize(path) != p.normalize(dest)) {
      await src.copy(dest);
      return dest;
    }
  } catch (_) {}
  return path;
}

/// Квадрат, общий у всех заметок: чётный (H.264) и как в пузыре.
const int _kSquareEdge = 480;

/// Любой кадр → настоящий квадрат [_kSquareEdge]²: (зеркало для фронтальной,)
/// центр-кроп, масштаб, квадратные пиксели, общая частота. FFmpeg ≥ 5 сам
/// поворачивает вход по метке поворота, так что кроп видит кадр уже стоя.
String _squareVideoChain(VideoNoteSegment seg) {
  final flip = seg.isFront ? 'hflip,' : '';
  return '${flip}crop=min(iw\\,ih):min(iw\\,ih),'
      'scale=$_kSquareEdge:$_kSquareEdge,setsar=1,fps=30';
}

String _sec(Duration d) => (d.inMicroseconds / 1e6).toStringAsFixed(3);

/// Края обрезки для входа: `-ss`/`-to` ПЕРЕД `-i` — точно (с перекодированием).
String _inputTrim(VideoNotePiece piece) {
  final b = StringBuffer();
  if (piece.from != null) b.write('-ss ${_sec(piece.from!)} ');
  if (piece.to != null) b.write('-to ${_sec(piece.to!)} ');
  return b.toString();
}

Future<String?> _encodeSquareSingle(VideoNotePiece piece) async {
  final out = await _newNotePath();
  await _deleteIfAny(out);
  String cmd(String v) =>
      '-y ${_inputTrim(piece)}-i "${piece.segment.path}" '
      '-vf "${_squareVideoChain(piece.segment)}" '
      '$v '
      '-c:a aac -movflags +faststart '
      '"$out"';
  try {
    final session = await H264Encoder.execute(cmd, crf: 23, kbps: 1200);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc) && File(out).existsSync()) return out;
  } catch (_) {}
  await _deleteIfAny(out);
  return _persistSingleSegment(piece.segment.path);
}

Future<String?> _concatPieces(List<VideoNotePiece> pieces) async {
  final out = await _newNotePath();
  await _deleteIfAny(out);
  final n = pieces.length;
  final inputs = StringBuffer();
  final filter = StringBuffer();
  final refs = StringBuffer();
  for (var i = 0; i < n; i++) {
    inputs.write('${_inputTrim(pieces[i])}-i "${pieces[i].segment.path}" ');
    filter.write(
      '[$i:v]${_squareVideoChain(pieces[i].segment)}[v$i];'
      '[$i:a]anull[a$i];',
    );
    refs.write('[v$i][a$i]');
  }
  filter.write('${refs}concat=n=$n:v=1:a=1[outv][outa]');
  String cmd(String v) =>
      '-y ${inputs.toString().trim()} '
      '-filter_complex "$filter" '
      '-map "[outv]" -map "[outa]" '
      '$v '
      '-c:a aac -movflags +faststart '
      '"$out"';
  try {
    final session = await H264Encoder.execute(cmd, crf: 23, kbps: 1200);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc) && File(out).existsSync()) return out;
  } catch (_) {}
  // Склейка не вышла — хотя бы первый кусок, но правильный квадрат.
  await _deleteIfAny(out);
  return _encodeSquareSingle(pieces.first);
}

Future<void> _deleteIfAny(String? path) async {
  if (path == null || path.isEmpty) return;
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

/// Кадры ленты обрезки: [count] равных шагов по всей записи. Фронтальные —
/// зеркально, как человек их и снимал.
Future<List<String?>> extractVideoNoteFrames(
  List<VideoNoteSegment> segments,
  List<Duration> lengths,
  int count,
) async {
  final total = lengths.fold<Duration>(Duration.zero, (a, b) => a + b);
  if (!kVideoToolsAvailable ||
      segments.isEmpty ||
      total <= Duration.zero ||
      count <= 0) {
    return List<String?>.filled(count, null);
  }
  final dir = await getTemporaryDirectory();
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final out = <String?>[];
  for (var k = 0; k < count; k++) {
    final at = total * ((k + 0.5) / count);
    var offset = Duration.zero;
    var i = 0;
    while (i < segments.length - 1 && offset + lengths[i] <= at) {
      offset += lengths[i];
      i++;
    }
    final seg = segments[i];
    final local = at - offset;
    final path = p.join(dir.path, 'vn_frame_${stamp}_$k.jpg');
    final flip = seg.isFront ? 'hflip,' : '';
    final cmd =
        '-y -ss ${_sec(local)} -i "${seg.path}" -frames:v 1 '
        '-vf "${flip}crop=min(iw\\,ih):min(iw\\,ih),scale=96:96" '
        '-q:v 6 "$path"';
    try {
      final session = await FFmpegKit.execute(cmd);
      final ok = ReturnCode.isSuccess(await session.getReturnCode());
      out.add(ok && File(path).existsSync() ? path : null);
    } catch (_) {
      out.add(null);
    }
  }
  return out;
}

/// Кадр камеры, обрезанный по центру до квадрата.
class VideoNoteCameraView extends StatelessWidget {
  const VideoNoteCameraView({super.key, required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final preview = controller.value.previewSize;
    if (preview == null) return CameraPreview(controller);
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          // previewSize — в ландшафте; на экране — портрет.
          width: preview.height,
          height: preview.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

/// Настоящая камера (`camera`).
///
/// Переключает только ОСНОВНУЮ заднюю (1×) и основную фронтальную — не
/// сверхширокую и не телевик, даже если устройство их показывает. Действия
/// идут строго по очереди: закрытие посреди открытия не оставит камеру
/// включённой.
class CameraVideoNoteCamera implements VideoNoteCamera {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _index = -1;
  int _back = -1;
  int _front = -1;
  Future<void> _queue = Future<void>.value();
  final ValueNotifier<Widget?> _preview = ValueNotifier(null);

  Future<T> _serial<T>(Future<T> Function() op) {
    final next = _queue.then((_) => op());
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  @override
  ValueListenable<Widget?> get preview => _preview;

  @override
  bool get isOpen => _controller?.value.isInitialized ?? false;

  @override
  bool get isFront =>
      _index >= 0 &&
      _index < _cameras.length &&
      _cameras[_index].lensDirection == CameraLensDirection.front;

  @override
  bool get canFlip => _back >= 0 && _front >= 0;

  @override
  Future<bool> hasPermission() async =>
      await Permission.camera.isGranted && await Permission.microphone.isGranted;

  Future<void> _ensureCameras() async {
    if (_cameras.isNotEmpty) return;
    _cameras = await availableCameras();
    _back = _pickMainBack(_cameras);
    _front = _pickPrimaryFront(_cameras);
  }

  static int _pickMainBack(List<CameraDescription> cams) {
    final backs = [
      for (var i = 0; i < cams.length; i++)
        if (cams[i].lensDirection == CameraLensDirection.back) i,
    ];
    if (backs.isEmpty) return -1;
    for (final i in backs) {
      if (cams[i].lensType == CameraLensType.wide) return i;
    }
    for (final i in backs) {
      final t = cams[i].lensType;
      if (t != CameraLensType.ultraWide && t != CameraLensType.telephoto) {
        return i;
      }
    }
    return backs.first;
  }

  static int _pickPrimaryFront(List<CameraDescription> cams) {
    final fronts = [
      for (var i = 0; i < cams.length; i++)
        if (cams[i].lensDirection == CameraLensDirection.front) i,
    ];
    if (fronts.isEmpty) return -1;
    for (final i in fronts) {
      if (cams[i].lensType == CameraLensType.wide) return i;
    }
    return fronts.first;
  }

  Future<void> _init(int index) async {
    final c = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: true,
    );
    await c.initialize();
    // iOS: заранее готовит запись — старт без задержки.
    try {
      await c.prepareForVideoRecording();
    } catch (_) {}
    _controller = c;
    _index = index;
    _preview.value = VideoNoteCameraView(
      key: ValueKey(index),
      controller: c,
    );
  }

  Future<void> _dispose() async {
    final c = _controller;
    _controller = null;
    _preview.value = null;
    if (c == null) return;
    try {
      if (c.value.isRecordingVideo) {
        final f = await c.stopVideoRecording();
        await _deleteIfAny(f.path);
      }
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
  }

  @override
  Future<void> open({required bool front}) => _serial(() async {
    if (isOpen) return;
    await _ensureCameras();
    if (_cameras.isEmpty) return;
    final want = front
        ? (_front >= 0 ? _front : _back)
        : (_back >= 0 ? _back : _front);
    await _init(want >= 0 ? want : 0);
  });

  @override
  Future<void> startSegment() => _serial(() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      throw StateError('camera closed');
    }
    if (c.value.isRecordingVideo) return;
    await c.startVideoRecording();
  });

  @override
  Future<String?> stopSegment() => _serial(() async {
    final c = _controller;
    if (c == null || !c.value.isRecordingVideo) return null;
    final f = await c.stopVideoRecording();
    if (f.path.isEmpty || !await File(f.path).exists()) return null;
    return f.path;
  });

  @override
  Future<void> flip() => _serial(() async {
    if (!canFlip) return;
    final next = _index == _front ? _back : _front;
    // Две живые камеры спорят за датчик и зависают — старую закрываем
    // полностью до открытия новой.
    await _dispose();
    await _init(next);
  });

  @override
  Future<void> setTorch(bool on) => _serial(() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    await c.setFlashMode(on ? FlashMode.torch : FlashMode.off);
  });

  @override
  Future<void> close() => _serial(_dispose);

  /// Диапазон — один раз на каждую открытую камеру (удачный ответ).
  CameraController? _zoomFor;
  VideoNoteZoomRange? _zoomRange;

  @override
  Future<VideoNoteZoomRange?> zoomRange() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return null;
    if (identical(_zoomFor, c)) return _zoomRange;
    try {
      final lo = await c.getMinZoomLevel();
      final hi = await c.getMaxZoomLevel();
      // Пока читали, камеру могли сменить.
      if (!identical(_controller, c)) return null;
      final range = VideoNoteZoomRange(lo, hi);
      _zoomFor = c;
      _zoomRange = range;
      return range;
    } catch (_) {
      return null;
    }
  }

  /// Мимо очереди: приближение не должно ждать начала/конца куска (и не
  /// задерживать их). Автомат шлёт не больше одного вызова за раз.
  @override
  Future<void> setZoom(double level) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setZoomLevel(level);
    } catch (_) {}
  }
}

/// Просмотр на `video_player`: части подряд, по кругу в пределах обрезки.
/// Фронтальные части — зеркально (как их видели при съёмке).
class VideoPlayerNotePreview implements VideoNotePreviewPlayer {
  final List<VideoPlayerController> _players = [];
  final List<VideoNoteSegment> _segments = [];
  final List<Duration> _offsets = [];
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<Widget?> _view = ValueNotifier(null);
  Duration _start = Duration.zero;
  Duration _end = Duration.zero;
  int _current = 0;
  bool _playing = false;
  bool _disposed = false;
  bool _switching = false;
  Timer? _tick;

  @override
  ValueListenable<Duration> get position => _position;

  @override
  ValueListenable<Widget?> get view => _view;

  @override
  Future<List<Duration>> load(List<VideoNoteSegment> segments) async {
    final lengths = <Duration>[];
    var offset = Duration.zero;
    for (final s in segments) {
      final c = VideoPlayerController.file(File(s.path));
      await c.initialize();
      await c.setLooping(false);
      _players.add(c);
      _segments.add(s);
      _offsets.add(offset);
      final d = c.value.duration > Duration.zero ? c.value.duration : s.length;
      lengths.add(d);
      offset += d;
    }
    _end = offset;
    _show(0);
    return lengths;
  }

  void _show(int i) {
    if (_disposed || i >= _players.length) return;
    _current = i;
    final c = _players[i];
    final size = c.value.size;
    _view.value = KeyedSubtree(
      key: ValueKey('vn-preview-$i'),
      child: Transform.flip(
        flipX: _segments[i].isFront,
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: size.width > 0 ? size.width : 1,
              height: size.height > 0 ? size.height : 1,
              child: VideoPlayer(c),
            ),
          ),
        ),
      ),
    );
  }

  (int, Duration) _locate(Duration global) {
    for (var i = _players.length - 1; i >= 0; i--) {
      if (global >= _offsets[i]) return (i, global - _offsets[i]);
    }
    return (0, Duration.zero);
  }

  Future<void> _jump(Duration global) async {
    if (_players.isEmpty) return;
    _switching = true;
    try {
      final (i, local) = _locate(global);
      if (i != _current) {
        await _players[_current].pause();
        _show(i);
      }
      await _players[i].seekTo(local);
      if (_playing) await _players[i].play();
      _position.value = global;
    } finally {
      _switching = false;
    }
  }

  void _onTick() {
    if (_disposed || _switching || _players.isEmpty || !_playing) return;
    final c = _players[_current];
    final local = c.value.position;
    final global = _offsets[_current] + local;
    _position.value = global;
    final atEnd =
        c.value.isCompleted ||
        (!c.value.isPlaying &&
            c.value.duration > Duration.zero &&
            local >= c.value.duration - const Duration(milliseconds: 60));
    if (global >= _end) {
      unawaited(_jump(_start));
    } else if (atEnd) {
      final next = _current + 1;
      unawaited(_jump(next < _players.length ? _offsets[next] : _start));
    }
  }

  @override
  Future<void> play() async {
    if (_players.isEmpty) return;
    _playing = true;
    final pos = _position.value;
    if (pos < _start || pos >= _end) {
      await _jump(_start);
    } else {
      await _players[_current].play();
    }
    _tick ??= Timer.periodic(const Duration(milliseconds: 40), (_) => _onTick());
  }

  @override
  Future<void> pause() async {
    _playing = false;
    if (_players.isEmpty) return;
    await _players[_current].pause();
  }

  @override
  Future<void> setRange(Duration start, Duration end) async {
    _start = start;
    _end = end;
  }

  @override
  Future<void> seek(Duration position) => _jump(position);

  @override
  Future<void> dispose() async {
    _disposed = true;
    _tick?.cancel();
    _view.value = null;
    for (final c in _players) {
      try {
        await c.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}
