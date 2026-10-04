// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// ПРЕВЬЮ КАМЕРЫ В НАСТРОЙКАХ ЗВОНКОВ.
///
/// 🔴 КАМЕРА ВКЛЮЧАЕТСЯ ТОЛЬКО ПО КНОПКЕ. Индикатор микрофона живёт, пока
/// открыт раздел, а камера — нет: её огонёк видно через всю комнату, и
/// приложение для тайной переписки не должно зажигать его оттого, что
/// человек зашёл в настройки. Раздел закрыли, окно спрятали, начался
/// звонок — камера гаснет.
///
/// Камера открывается ТЕМИ ЖЕ ключами, что в звонке 1:1
/// (`WebRtcCallSession.buildVideoCaptureConstraints`): macOS читает
/// `deviceId`, Windows — `optional.sourceId`. Иначе превью показывало бы одну
/// камеру, а звонок включал бы другую.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../calls/call_log.dart';

/// Что с превью.
enum CameraPreviewStatus { off, starting, on, failed }

/// Превью камеры раздела: включить, переключить на другую камеру, погасить.
class DesktopCameraPreviewController extends ChangeNotifier {
  DesktopCameraPreviewController({required DesktopCameraPreviewEngine engine})
    : _engine = engine;

  final DesktopCameraPreviewEngine _engine;

  CameraPreviewStatus _status = CameraPreviewStatus.off;
  CameraPreviewStatus get status => _status;

  /// Включено или включается — кнопка показывает «Скрыть».
  bool get active =>
      _status == CameraPreviewStatus.on ||
      _status == CameraPreviewStatus.starting;

  String? _cameraId;

  /// Какая камера в превью.
  String? get cameraId => _cameraId;

  /// Растёт при каждом включении и выключении: ответ камеры на прежнюю
  /// просьбу не должен перетереть новую.
  int _generation = 0;
  bool _disposed = false;

  /// 🔴 ДЕЙСТВИЯ С КАМЕРОЙ — СТРОГО ПО ОЧЕРЕДИ. Открытие камеры занимает
  /// заметное время, а человек успевает нажать «Скрыть» или выбрать другую
  /// камеру раньше, чем первая откроется. Без очереди вторая камера
  /// открывалась бы поверх первой, и одна из них оставалась бы гореть без
  /// превью. Устаревшее включение пропускается, а успевшее — гасится.
  Future<void> _queue = Future<void>.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) => action()).catchError((Object e) {
      callLog('DesktopCameraCheck', 'preview action failed: $e');
    });
    _queue = next;
    return next;
  }

  /// Показать камеру [cameraId] ('' — системную).
  Future<void> show(String cameraId) {
    if (_disposed) return Future<void>.value();
    final gen = ++_generation;
    _cameraId = cameraId;
    _set(CameraPreviewStatus.starting);
    return _enqueue(() async {
      if (gen != _generation || _disposed) return;
      try {
        await _engine.start(cameraId);
      } catch (e) {
        callLog('DesktopCameraCheck', 'preview start failed: $e');
        if (gen == _generation && !_disposed) _set(CameraPreviewStatus.failed);
        return;
      }
      if (gen != _generation || _disposed) {
        await _engine.stop();
        return;
      }
      _set(CameraPreviewStatus.on);
    });
  }

  /// Погасить камеру.
  Future<void> hide() {
    if (_disposed) return Future<void>.value();
    ++_generation;
    _cameraId = null;
    _set(CameraPreviewStatus.off);
    return _enqueue(_engine.stop);
  }

  /// Выбрали другую камеру: включённое превью переключается на неё.
  Future<void> follow(String cameraId) async {
    if (!active || cameraId == _cameraId) return;
    await show(cameraId);
  }

  Widget view({required bool mirror}) => _engine.view(mirror: mirror);

  void _set(CameraPreviewStatus status) {
    if (_disposed || _status == status) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    // Камера гаснет вместе с разделом — после того, что уже в очереди.
    unawaited(_enqueue(_engine.dispose));
    super.dispose();
  }
}

/// Ограничения захвата для превью камеры [cameraId] ('' — системная, как в
/// звонке без выбора). Чистая функция.
Map<String, dynamic> desktopCameraPreviewConstraints(String cameraId) {
  final camera = cameraId.trim();
  return <String, dynamic>{
    'audio': false,
    'video': <String, dynamic>{
      if (camera.isEmpty) 'facingMode': 'user',
      if (camera.isNotEmpty) 'deviceId': camera,
      if (camera.isNotEmpty)
        'optional': <Map<String, dynamic>>[
          <String, dynamic>{'sourceId': camera},
        ],
      // Превью маленькое: большой кадр грел бы камеру и процессор впустую.
      'width': <String, dynamic>{'ideal': 640, 'min': 320},
      'height': <String, dynamic>{'ideal': 360, 'min': 180},
      'frameRate': <String, dynamic>{'ideal': 24, 'min': 12},
    },
  };
}

/// Превью: открыть камеру и нарисовать её. Настоящая половина —
/// [WebRtcCameraPreviewEngine], в тестах — подставная.
abstract class DesktopCameraPreviewEngine {
  /// Включить камеру [cameraId]. Бросает, если не вышло.
  Future<void> start(String cameraId);

  /// Выключить камеру. Повторный вызов безвреден.
  Future<void> stop();

  /// Картинка включённой камеры.
  Widget view({required bool mirror});

  Future<void> dispose();
}

/// Превью через `flutter_webrtc` — тот же движок, что снимает звонок.
class WebRtcCameraPreviewEngine implements DesktopCameraPreviewEngine {
  RTCVideoRenderer? _renderer;
  MediaStream? _stream;

  @override
  Future<void> start(String cameraId) async {
    await stop();
    var renderer = _renderer;
    if (renderer == null) {
      renderer = RTCVideoRenderer();
      await renderer.initialize();
      _renderer = renderer;
    }
    final stream = await navigator.mediaDevices.getUserMedia(
      desktopCameraPreviewConstraints(cameraId),
    );
    _stream = stream;
    renderer.srcObject = stream;
  }

  @override
  Future<void> stop() async {
    final stream = _stream;
    _stream = null;
    final renderer = _renderer;
    if (renderer != null) renderer.srcObject = null;
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      try {
        await track.stop();
      } catch (_) {}
    }
    try {
      await stream.dispose();
    } catch (_) {}
  }

  @override
  Widget view({required bool mirror}) {
    final renderer = _renderer;
    if (renderer == null) return const SizedBox.shrink();
    return RTCVideoView(
      renderer,
      mirror: mirror,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }

  @override
  Future<void> dispose() async {
    await stop();
    final renderer = _renderer;
    _renderer = null;
    if (renderer != null) {
      try {
        await renderer.dispose();
      } catch (_) {}
    }
  }
}
