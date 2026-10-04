// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../rooms/room_call_manager.dart';
import '../../../rooms/room_call_media_controller.dart';

/// Сторож медиа комнатного созвона на ПК (30.09.2026).
///
/// 🔴 ЗАЧЕМ. После «Выйти», «Завершить для всех» или когда тебя убрали из
/// созвона общий управляющий переходил в «созвона нет», но в трёх ветках не
/// отпускал движок: LiveKit оставался подключён, микрофон — опубликован, а
/// окно честно писало «созвона нет». Выход с телефона шёл тем же путём, но
/// исправлять общий код, не трогая выпущенный телефон, можно только
/// добавочным методом ([RoomCallManager.releaseMediaIfIdle]). Здесь — тот,
/// кто его зовёт: на КАЖДОМ переходе в «созвона нет», откуда бы он ни пришёл
/// (кнопка окна, полоса, мини-окно, чужое «завершить», модератор).
///
/// Подключается из того, что на ПК живёт всегда: мини-окон звонков в главном
/// окне и окна созвона. Повторное подключение к тому же управляющему ничего
/// не делает; к новому (смена профиля) — переподключает.
abstract final class DesktopRoomCallMediaGuard {
  static RoomCallManager? _manager;

  /// Следить за [manager]; по умолчанию — за [RoomCallManager.instance].
  static void attach([RoomCallManager? manager]) {
    final next = manager ?? RoomCallManager.instance;
    if (identical(next, _manager)) return;
    // Отписка от разобранного управляющего разрешена: `removeListener`
    // после `dispose` ничего не делает.
    _manager?.state.removeListener(_onState);
    _manager = next;
    if (next == null) return;
    next.state.addListener(_onState);
    // Подключились позже, чем движок осиротел, — отпускаем сразу.
    _onState();
  }

  /// Управляющий, за которым следим. Для проверок.
  @visibleForTesting
  static RoomCallManager? get attachedManager => _manager;

  static void _onState() {
    final manager = _manager;
    if (manager == null || manager.state.value.hasActiveSession) return;
    unawaited(manager.releaseMediaIfIdle());
  }

  // ── Камера (30.09.2026) ──────────────────────────────────────────────────
  //
  // 🔴 ВЫБОР КАМЕРЫ ПРИ ВЫКЛЮЧЕННОЙ КАМЕРЕ ЕЁ ВКЛЮЧАЛ. Выключенная камера в
  // LiveKit — это приглушённая дорожка, а переключение устройства у неё
  // (`switchCamera` → `restartTrack`) заново открывает камеру, не глядя на
  // «приглушено»: горел индикатор камеры, кадры уходили в созвон, а окно
  // писало «камера выключена». Так срабатывали шеврон у «Камеры», выбор в
  // настройках посреди созвона и выбор из настроек, который окно применяло
  // заново при каждом открытии (например, по возвращении из мини-окна).
  //
  // Теперь: камера идёт — переключаем сразу; выключена — только запоминаем,
  // и запомненная пойдёт, когда камеру включат. Память привязана к движку
  // созвона, а не к окну: окно пересоздаётся, движок — нет.

  static final Expando<String> _pendingCamera = Expando<String>();
  static final Expando<VoidCallback> _pendingCameraWatch =
      Expando<VoidCallback>();
  static final Expando<String> _appliedPreferredCamera = Expando<String>();

  /// Выбрать камеру созвона.
  static Future<void> chooseCamera(
    RoomCallMediaController media,
    String deviceId,
  ) async {
    final want = deviceId.trim();
    if (want.isEmpty) return;
    if (!media.state.value.videoCaptureActive) {
      _pendingCamera[media] = want;
      _watchCameraTurnOn(media);
      return;
    }
    _pendingCamera[media] = null;
    if (media.selectedVideoInputId == want) return;
    await media.selectVideoInput(want);
  }

  /// Какую камеру показать выбранной: пока камера выключена — запомненную.
  static String? chosenCamera(RoomCallMediaController media) =>
      _pendingCamera[media] ?? media.selectedVideoInputId;

  /// Камера из настроек — ОДИН раз на движок, а не на каждое окно: иначе
  /// новое окно отматывало бы выбор, сделанный в доке, и снова открывало бы
  /// выключенную камеру. Новый выбор в настройках применяется.
  static Future<void> applyPreferredCamera(
    RoomCallMediaController media,
    String deviceId,
  ) async {
    final want = deviceId.trim();
    if (want.isEmpty || _appliedPreferredCamera[media] == want) return;
    _appliedPreferredCamera[media] = want;
    await chooseCamera(media, want);
  }

  static void _watchCameraTurnOn(RoomCallMediaController media) {
    if (_pendingCameraWatch[media] != null) return;
    void onState() {
      if (!media.state.value.videoCaptureActive) return;
      media.state.removeListener(onState);
      _pendingCameraWatch[media] = null;
      final want = _pendingCamera[media];
      if (want == null) return;
      // Не посреди уведомления движка — следующим шагом, и с повторной
      // проверкой: камеру могли уже снова выключить.
      unawaited(
        Future<void>(() async {
          if (_pendingCamera[media] != want) return;
          if (!media.state.value.videoCaptureActive) {
            _watchCameraTurnOn(media);
            return;
          }
          _pendingCamera[media] = null;
          if (media.selectedVideoInputId == want) return;
          await media.selectVideoInput(want);
        }),
      );
    }

    _pendingCameraWatch[media] = onState;
    media.state.addListener(onState);
  }

  @visibleForTesting
  static void debugReset() {
    _manager?.state.removeListener(_onState);
    _manager = null;
  }
}
