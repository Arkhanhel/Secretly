// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Штатный выключатель LiveKit помечен экспериментальным; другого способа
// отдать звуковую сессию личного звонка CallKit в 2.13.1 нет.
// ignore_for_file: experimental_member_use
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../diagnostics/diag_log.dart';
import 'call_state.dart';

/// 🔴 Громкая связь на iPhone в ЛИЧНОМ звонке (15.11.2026).
///
/// livekit_client 2.13.1 (обновление 13.10) при регистрации плагина забирает
/// звуковую сессию iOS у flutter_webrtc для ВСЕХ звонков, не только для
/// комнат: на каждом запуске звукового движка WebRTC он переписывает сессию
/// (режим `videoChat`, `overrideOutputAudioPort(.none)`). В личном звонке
/// сессией управляют CallKit и `AppDelegate` (`setSpeakerEnabled`), и LiveKit
/// сразу же затирал их выбор — переключатель динамика ничего не менял. В 2.4.0
/// такого перехвата не было.
///
/// Решение — штатный выключатель LiveKit: на время личного звонка режим
/// `manual` (LiveKit сессию не трогает), после звонка — снова `automatic`,
/// чтобы созвоны в комнатах работали как раньше.
class LiveKitAudioSessionGuard {
  LiveKitAudioSessionGuard({
    Future<void> Function(lk.AudioSessionManagementMode mode)? setMode,
    bool? isApple,
  })  : _setMode = setMode ??
            ((m) => lk.AudioManager.instance.setAudioSessionManagementMode(m)),
        // Только iPhone: на Mac звуковой сессии iOS нет, а ПК подбирает
        // устройства своим путём (desktop_call_devices.dart).
        _isApple = isApple ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  final Future<void> Function(lk.AudioSessionManagementMode mode) _setMode;
  final bool _isApple;
  bool _manual = false;

  @visibleForTesting
  bool get isManual => _manual;

  /// Вызывать на каждое изменение состояния личного звонка.
  void onCallState(CallState state) {
    if (!_isApple) return;
    final inCall =
        state.phase != CallPhase.idle && state.phase != CallPhase.ended;
    if (inCall == _manual) return;
    _manual = inCall;
    final mode = inCall
        ? lk.AudioSessionManagementMode.manual
        : lk.AudioSessionManagementMode.automatic;
    DiagLog.event('calls', 'livekit_audio_mode', {'mode': mode.name});
    unawaited(_setMode(mode).catchError((Object e) {
      DiagLog.event('calls', 'livekit_audio_mode_failed', {
        'err': e.runtimeType.toString(),
      });
    }));
  }
}
