// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'scroll_feel.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../calls/call_manager.dart';
import '../calls/call_audio_route.dart';
import '../calls/call_state.dart';
import '../calls/webrtc_call_session.dart';
import '../l10n/app_localizations.dart';
import 'call_error_text.dart';
import 'android_picture_in_picture.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'wave1_l10n.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/system_bottom_fade.dart';

const _kOneToOneCallBg = Color(0xFF0D0D0D);
const _kOneToOneCallBgTop = Color(0xFF4B2368);
const _kOneToOneCallBgMid = Color(0xFF2A4D94);

/// Full-screen active-call UI (WhatsApp style).
///
/// Covers the full screen with:
/// - Remote video (or gradient + avatar for audio calls)
/// - Local camera PiP (draggable, top-right)
/// - Status bar with encryption badge + connection status
/// - Call duration timer (mm:ss)
/// - Bottom control bar: mute, speaker, camera, switch-cam, hangup
/// - Upgrade-to-video button for audio calls
class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({super.key, required this.callManager});

  final CallManager callManager;

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _durationTimer;
  String _durationText = '00:00';
  late final AnimationController _controlsFadeCtrl;
  bool _controlsVisible = true;
  bool _showAudioRouteChoices = false;

  // Local PiP drag position + spring animation
  Offset _pipOffset = const Offset(16, 56);
  bool _videoSwapped = false;
  bool _pipDragging = false;
  Size _lastScreenSize = const Size(393, 852);
  static const double _pipW = 110;
  static const double _pipH = 160;
  AnimationController? _pipSpringX;
  AnimationController? _pipSpringY;
  bool? _lastAndroidPipEnabled;
  // Single persistent listener — avoids the leak where every snap adds listeners.
  late final VoidCallback _pipSpringListener;

  @override
  void initState() {
    super.initState();
    _controlsFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    widget.callManager.state.addListener(_onStateChange);
    _startDurationTimer();
    _pipSpringX = AnimationController.unbounded(vsync: this);
    _pipSpringY = AnimationController.unbounded(vsync: this);
    _pipSpringListener = _onPipSpringTick;
    _pipSpringX!.addListener(_pipSpringListener);
    _pipSpringY!.addListener(_pipSpringListener);
    WidgetsBinding.instance.addObserver(this);
    unawaited(WakelockPlus.enable());
    _syncNativePictureInPicture();
  }

  void _onStateChange() {
    final phase = widget.callManager.state.value.phase;
    if (phase == CallPhase.ended || phase == CallPhase.idle) {
      _showAudioRouteChoices = false;
      // Let the end-call reason show briefly, then pop will happen
      // automatically via CallManager._endCall (2s delay + popCallScreens).
    }
    _syncNativePictureInPicture();
    if (mounted) setState(() {});
  }

  void _syncNativePictureInPicture() {
    final state = widget.callManager.state.value;
    final enabled = state.isActive && state.isVideo;
    if (_lastAndroidPipEnabled == enabled) {
      return;
    }
    _lastAndroidPipEnabled = enabled;
    unawaited(
      NativePictureInPicture.setAutoEnterEnabled(
        enabled: enabled,
        peerName: state.peerName,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused) {
      return;
    }
    final callState = widget.callManager.state.value;
    if (!callState.isActive || !callState.isVideo) return;
    unawaited(NativePictureInPicture.enter());
  }

  /// 🔴 ОБЫЧНОЕ НАЖАТИЕ ВСЕГДА ПЕРЕКЛЮЧАЕТ ГРОМКУЮ (12.08.2026).
  ///
  /// Жалоба, стоившая суток разбора: «кнопка нажимается, связь не меняется».
  /// Здесь стояло `if (hasMultipleChoices) { показать список; return; }` — и при
  /// трёх и более маршрутах (наушник + громкая + гарнитура) кнопка громкой
  /// переставала быть переключателем и лишь разворачивала полоску выбора.
  /// Человек жмёт «громкую», получает список, которого не просил, и звук не
  /// меняется.
  ///
  /// В журнале это выглядело как ПОЛНАЯ тишина: `toggleSpeaker` не звался ни
  /// разу. Поэтому весь разбор аудиослоя — устаревший `setSpeakerphoneOn`,
  /// маршруты, нативный `setCommunicationDevice` — шёл по пути, который вообще
  /// не исполнялся.
  ///
  /// 🔴 УРОК: начинать от КНОПКИ, а не от механизма, который она якобы дёргает.
  /// Тот же класс, что три предыдущих провала этого дня: правка стояла не там,
  /// где исполнение.
  ///
  /// Выбор маршрута не потерян — он переехал на ДОЛГОЕ нажатие.
  Future<void> _handleAudioRoutePrimaryAction(
    CallAudioRouteState routeState,
  ) async {
    await widget.callManager.toggleSpeaker();
    if (!mounted) {
      return;
    }
    setState(() {
      _showAudioRouteChoices = false;
    });
  }

  Future<void> _selectAudioRoute(String routeId) async {
    await widget.callManager.selectAudioRoute(routeId);
    if (!mounted) {
      return;
    }
    setState(() {
      _showAudioRouteChoices = false;
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final ms = widget.callManager.state.value.connectedAtMs;
      if (ms != null) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - ms;
        final totalSec = (elapsed / 1000).floor();
        final min = totalSec ~/ 60;
        final sec = totalSec % 60;
        setState(() {
          _durationText =
              '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
        });
      }
    });
  }

  void _onPipSpringTick() {
    if (!mounted) return;
    final sx = _pipSpringX;
    final sy = _pipSpringY;
    if (sx == null || sy == null) return;
    setState(() {
      _pipOffset = Offset(
        sx.value.clamp(0.0, _lastScreenSize.width - _pipW),
        sy.value.clamp(0.0, _lastScreenSize.height - _pipH),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.callManager.state.removeListener(_onStateChange);
    _durationTimer?.cancel();
    _controlsFadeCtrl.dispose();
    _pipSpringX?.removeListener(_pipSpringListener);
    _pipSpringY?.removeListener(_pipSpringListener);
    _pipSpringX?.dispose();
    _pipSpringY?.dispose();
    unawaited(NativePictureInPicture.setAutoEnterEnabled(enabled: false));
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  /// Snap PiP to the nearest corner with spring physics.
  /// Listeners are registered once in initState — no per-call addListener.
  void _snapPipToCorner(Size screenSize, {Offset velocity = Offset.zero}) {
    _lastScreenSize = screenSize;
    const margin = 12.0;
    final maxRight = screenSize.width - _pipW - margin;
    final maxBottom = screenSize.height - _pipH - margin;

    final centerX = _pipOffset.dx + _pipW / 2;
    final centerY = _pipOffset.dy + _pipH / 2;
    final biasX = centerX - velocity.dx * 0.15;
    final biasY = centerY + velocity.dy * 0.15;

    final targetRight = biasX < screenSize.width / 2 ? maxRight : margin;
    final targetTop = biasY < screenSize.height / 2 ? margin + 56 : maxBottom;

    const spring = SpringDescription(mass: 1, stiffness: 220, damping: 22);
    _pipSpringX!.animateWith(
      SpringSimulation(spring, _pipOffset.dx, targetRight, -velocity.dx),
    );
    _pipSpringY!.animateWith(
      SpringSimulation(spring, _pipOffset.dy, targetTop, velocity.dy),
    );
  }

  void _toggleControlsVisibility() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _controlsFadeCtrl.forward();
    } else {
      _controlsFadeCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screenSize = MediaQuery.of(context).size;

    return BottomSystemFadeVisibility(
      enabled: false,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            widget.callManager.minimizeActiveCallUi();
          }
        },
        child: ValueListenableBuilder<CallState>(
          valueListenable: widget.callManager.state,
          builder: (context, state, _) {
            return ValueListenableBuilder<CallAudioRouteState>(
              valueListenable: widget.callManager.audioRouteState,
              builder: (context, routeState, _) {
                return _buildScaffold(
                  context: context,
                  state: state,
                  screenSize: screenSize,
                  l10n: l10n,
                  routeState: routeState,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildScaffold({
    required BuildContext context,
    required CallState state,
    required Size screenSize,
    required AppLocalizations l10n,
    required CallAudioRouteState routeState,
  }) {
    final isVideo = state.isVideo;
    final session = widget.callManager.session;
    final phase = state.phase;
    final isEnded = phase == CallPhase.ended;
    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<bool>(
        valueListenable: NativePictureInPicture.isInPipMode,
        builder: (context, isInPip, _) {
          return GestureDetector(
            // Disable controls toggle while in PiP — the OS owns the window.
            onTap: (isVideo && !isInPip) ? _toggleControlsVisibility : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Background (remote video or gradient) ──────
                // While the system shows the PiP mini-window we ALWAYS render
                // the remote-video surface full-bleed and suppress every
                // overlay so only the peer's video is captured by the OS PiP
                // host.
                if (isVideo && session != null)
                  if (isInPip)
                    _RemoteVideoSurface(
                      session: session,
                      peerName: state.peerName,
                      peerProfileId: state.peerProfileId,
                      peerAvatarPath: state.peerAvatarPath,
                      l10n: l10n,
                    )
                  else if (_videoSwapped)
                    _FullscreenLocalVideo(
                      session: session,
                      mirror:
                          state.isFrontCamera && !state.isScreenSharing,
                    )
                  else
                    _RemoteVideoSurface(
                      session: session,
                      peerName: state.peerName,
                      peerProfileId: state.peerProfileId,
                      peerAvatarPath: state.peerAvatarPath,
                      l10n: l10n,
                    )
                else
                  _AudioCallBackground(
                    name: state.peerName,
                    seed: state.peerProfileId,
                    avatarPath: state.peerAvatarPath,
                  ),

                // ── Local-cam PiP (in-app overlay) — hidden in OS PiP ──
                if (!isInPip &&
                    isVideo &&
                    session != null &&
                    !state.isCameraOff)
                  Positioned(
                    right: _pipOffset.dx,
                    top: _pipOffset.dy,
                    child: GestureDetector(
                      // Tap swaps local/remote only if the user didn't drag.
                      onTap: () {
                        if (!_pipDragging) {
                          setState(() => _videoSwapped = !_videoSwapped);
                        }
                        _pipDragging = false;
                      },
                      onPanStart: (_) {
                        _pipDragging = false;
                        _pipSpringX?.stop();
                        _pipSpringY?.stop();
                      },
                      onPanUpdate: (details) {
                        _pipDragging = true;
                        _lastScreenSize = screenSize;
                        setState(() {
                          _pipOffset = Offset(
                            (_pipOffset.dx - details.delta.dx).clamp(
                              0,
                              screenSize.width - _pipW,
                            ),
                            (_pipOffset.dy + details.delta.dy).clamp(
                              0,
                              screenSize.height - _pipH,
                            ),
                          );
                        });
                      },
                      onPanEnd: (details) {
                        _snapPipToCorner(
                          screenSize,
                          velocity: details.velocity.pixelsPerSecond,
                        );
                      },
                      child: _videoSwapped
                          ? _RemotePip(session: session)
                          : _LocalPip(
                              session: session,
                              mirror: state.isFrontCamera &&
                                  !state.isScreenSharing,
                            ),
                    ),
                  ),

                // ── Top status bar (hidden in OS PiP) ─────────
                if (!isInPip)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: FadeTransition(
                      opacity: _controlsFadeCtrl,
                      child: _TopStatusBar(
                        state: state,
                        durationText: _durationText,
                        l10n: l10n,
                        onMinimize:
                            widget.callManager.minimizeActiveCallUi,
                      ),
                    ),
                  ),

                // ── "Call ended" overlay (hidden in OS PiP) ──
                if (!isInPip && isEnded)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _endReasonText(context, state, l10n),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                // ── Bottom controls (hidden in OS PiP) ───────
                if (!isInPip && !isEnded)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: FadeTransition(
                      opacity: _controlsFadeCtrl,
                      child: _BottomControls(
                        state: state,
                        callManager: widget.callManager,
                        l10n: l10n,
                        routeState: routeState,
                        showAudioRouteChoices: _showAudioRouteChoices,
                        onAudioRoutePrimaryTap: () => unawaited(
                          _handleAudioRoutePrimaryAction(routeState),
                        ),
                        onAudioRouteLongPress: routeState.hasMultipleChoices
                            ? () => setState(() {
                                _showAudioRouteChoices =
                                    !_showAudioRouteChoices;
                              })
                            : null,
                        onSelectAudioRoute: (routeId) =>
                            unawaited(_selectAudioRoute(routeId)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _endReasonText(
    BuildContext context,
    CallState state,
    AppLocalizations l10n,
  ) {
    switch (state.endReason) {
      case CallEndReason.localHangup:
      case CallEndReason.remoteHangup:
        return l10n.callEnded;
      case CallEndReason.remoteSuperseded:
        return l10n.callReplacedByNewerAttempt;
      case CallEndReason.remoteDecline:
        return l10n.callDeclined;
      case CallEndReason.localDecline:
        return l10n.callYouDeclined;
      case CallEndReason.timeout:
        return l10n.callNoAnswer;
      case CallEndReason.error:
        if (state.failure != null) {
          return callErrorText(context.l10n, state.failure!);
        }
        return l10n.callConnectionError;
      case null:
        return l10n.callEnded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Remote video (full-screen)
// ═══════════════════════════════════════════════════════════════════════════

class _RemoteVideoView extends StatelessWidget {
  const _RemoteVideoView({required this.session, required this.viewToken});

  final WebRtcCallSession session;
  final String viewToken;

  @override
  Widget build(BuildContext context) {
    return RTCVideoView(
      key: ValueKey('remote-video:$viewToken'),
      session.remoteRenderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}

class _RemoteVideoSurface extends StatelessWidget {
  const _RemoteVideoSurface({
    required this.session,
    required this.peerName,
    required this.peerProfileId,
    required this.peerAvatarPath,
    required this.l10n,
  });

  final WebRtcCallSession session;
  final String peerName;
  final String peerProfileId;
  final String? peerAvatarPath;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RemoteVideoLifecycle>(
      valueListenable: session.remoteVideoLifecycle,
      builder: (context, lifecycle, _) {
        final shouldMountRemoteView = _shouldMountRemoteView(lifecycle);
        return Stack(
          fit: StackFit.expand,
          children: [
            _AudioCallBackground(
              name: peerName,
              seed: peerProfileId,
              avatarPath: peerAvatarPath,
            ),
            if (shouldMountRemoteView)
              _RemoteVideoView(
                session: session,
                viewToken:
                    '${session.hashCode}:${lifecycle.state.name}:${_videoRendererBindingToken(session.remoteRenderer)}',
              ),
          ],
        );
      },
    );
  }

  bool _shouldMountRemoteView(RemoteVideoLifecycle lifecycle) {
    if (lifecycle.isRenderable) {
      return true;
    }
    final stream = session.remoteRenderer.srcObject;
    return stream != null && stream.getVideoTracks().isNotEmpty;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Audio call background (gradient + large avatar)
// ═══════════════════════════════════════════════════════════════════════════

class _AudioCallBackground extends StatelessWidget {
  const _AudioCallBackground({
    required this.name,
    required this.seed,
    this.avatarPath,
  });

  final String name;

  /// Ключ цвета заглушки — профиль собеседника, тот же, что в списке чатов.
  final String seed;

  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [_kOneToOneCallBgTop, _kOneToOneCallBgMid, _kOneToOneCallBg],
          stops: [0.0, 0.38, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(context),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    const size = 130.0;
    if (avatarPath != null && avatarPath!.isNotEmpty) {
      return ClipOval(
        child: Image.file(
          File(avatarPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _letterCircle(context, size),
        ),
      );
    }
    return _letterCircle(context, size);
  }

  // 🔴 ЗАГЛУШКА — ОБЩАЯ С ОСТАЛЬНЫМ ПРИЛОЖЕНИЕМ И С КОМПЬЮТЕРОМ (17.09.2026).
  //
  // Здесь был свой оттенок из `name.hashCode` и одна буква `name[0]`: цвет не
  // совпадал со списком чатов, а имя с эмодзи в начале резалось посреди
  // символа. Теперь ключ, буквы и цвета — те же, что везде. Заливка считается
  // от середины градиента экрана: портрет стоит в центре, где синий уже
  // уходит в чёрный.
  Widget _letterCircle(BuildContext context, double size) =>
      AvatarInitials.fallbackBubble(
        context: context,
        radius: size / 2,
        seed: seed.trim().isNotEmpty ? seed.trim() : name,
        displayName: name,
        background: Color.lerp(_kOneToOneCallBgMid, _kOneToOneCallBg, 0.25)!,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
//   Local PiP (draggable, rounded)
// ═══════════════════════════════════════════════════════════════════════════

class _LocalPip extends StatelessWidget {
  const _LocalPip({required this.session, required this.mirror});

  final WebRtcCallSession session;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final viewToken =
        '${session.hashCode}:${_videoRendererBindingToken(session.localRenderer)}';
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 110,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: RTCVideoView(
            key: ValueKey('local-video:$viewToken'),
            session.localRenderer,
            mirror: mirror,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      ),
    );
  }
}

// Full-screen local video (when user swaps local/remote positions).
class _FullscreenLocalVideo extends StatelessWidget {
  const _FullscreenLocalVideo({required this.session, required this.mirror});

  final WebRtcCallSession session;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final viewToken =
        'local-fs:${session.hashCode}:${_videoRendererBindingToken(session.localRenderer)}';
    return RTCVideoView(
      key: ValueKey(viewToken),
      session.localRenderer,
      mirror: mirror,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}

// Remote video in PiP size (when user swaps local/remote positions).
class _RemotePip extends StatelessWidget {
  const _RemotePip({required this.session});

  final WebRtcCallSession session;

  @override
  Widget build(BuildContext context) {
    final viewToken =
        'remote-pip:${session.hashCode}:${_videoRendererBindingToken(session.remoteRenderer)}';
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 110,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: RTCVideoView(
            key: ValueKey(viewToken),
            session.remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      ),
    );
  }
}

String _videoRendererBindingToken(RTCVideoRenderer renderer) {
  final stream = renderer.srcObject;
  if (stream == null) {
    return 'stream:none';
  }
  try {
    final trackIds = stream.getVideoTracks().map((track) => track.id).join(',');
    return 'stream:${stream.id}|tracks:${trackIds.isEmpty ? 'none' : trackIds}';
  } catch (_) {
    return 'stream:${stream.id}|tracks:error';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Top status bar (encryption badge + status + duration)
// ═══════════════════════════════════════════════════════════════════════════

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar({
    required this.state,
    required this.durationText,
    required this.l10n,
    required this.onMinimize,
  });

  final CallState state;
  final String durationText;
  final AppLocalizations l10n;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(
        top: safeTop + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _kOneToOneCallBgTop.withValues(alpha: 0.42),
            _kOneToOneCallBgMid.withValues(alpha: 0.16),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l10n.callMinimize,
                onPressed: onMinimize,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.lock,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.callEncryptedBadge,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          // Encryption badge
          const SizedBox(height: 6),
          // Name
          Text(
            // 🔴 Пустое имя — не пустая строка на экране (22.08.2026). Имя
            // приходит из контакта или метаданных профиля, и пока резолв не
            // отработал (или собеседник неизвестен), показываем осмысленную
            // подпись. Раньше сюда подставлялся сырой profile_id — владелец
            // видел «3XBC-F5DJ-…» вместо имени.
            state.peerName.trim().isNotEmpty
                ? state.peerName
                : wave1Text(
                    context,
                    ru: 'Звонок',
                    en: 'Call',
                    uk: 'Дзвінок',
                    es: 'Llamada',
                    pt: 'Chamada',
                    ptBr: 'Chamada',
                    fr: 'Appel',
                    de: 'Anruf',
                  ),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          // Status / duration text
          Text(
            _statusText(),
            style: TextStyle(fontSize: 14, color: _statusColor()),
          ),
        ],
      ),
    );
  }

  String _statusText() {
    switch (state.phase) {
      case CallPhase.ringingOutgoing:
        return l10n.callStatusCalling;
      case CallPhase.ringingIncoming:
        return l10n.callStatusIncoming;
      case CallPhase.connecting:
        return l10n.callStatusConnecting;
      case CallPhase.connected:
        return durationText;
      case CallPhase.reconnecting:
        return l10n.callStatusReconnecting;
      case CallPhase.ended:
        return l10n.callStatusEnded;
      case CallPhase.idle:
        return '';
    }
  }

  Color _statusColor() {
    switch (state.phase) {
      case CallPhase.connected:
        return const Color(0xFF4CAF50);
      case CallPhase.reconnecting:
        return Colors.white70;
      case CallPhase.ended:
        return const Color(0xFFE53935);
      default:
        return Colors.white70;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Bottom control bar
// ═══════════════════════════════════════════════════════════════════════════

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.state,
    required this.callManager,
    required this.l10n,
    required this.routeState,
    required this.showAudioRouteChoices,
    required this.onAudioRoutePrimaryTap,
    this.onAudioRouteLongPress,
    required this.onSelectAudioRoute,
  });

  final CallState state;
  final CallManager callManager;
  final AppLocalizations l10n;
  final CallAudioRouteState routeState;
  final bool showAudioRouteChoices;
  final VoidCallback onAudioRoutePrimaryTap;

  /// Выбор маршрута — долгим нажатием. Обычное обязано переключать громкую.
  final VoidCallback? onAudioRouteLongPress;
  final ValueChanged<String> onSelectAudioRoute;

  @override
  Widget build(BuildContext context) {
    // PR-H+2 (2026-05-20): gradient must extend ALL the way to the bottom
    // of the screen (behind the home-indicator) so there is no visible
    // "strip" of un-dimmed pixels between the bottom of the controls and
    // the screen edge. The previous layout wrapped a SafeArea around the
    // gradient Container, which pushed the gradient up by `bottomInset`,
    // leaving the home-indicator region untouched.
    //
    // New layout:
    //   Container(decoration: gradient)   ← covers full bar incl. inset
    //     └── SafeArea(bottom: true)      ← inset baked into padding
    //          └── Padding                ← buttons keep clear of indicator
    //               └── Column(controls…)
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: Padding(
          padding: const EdgeInsets.only(
            top: 20,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAudioRouteChoices && routeState.hasMultipleChoices)
              // PR-H+1: route chips on a horizontal scroller so they stay
              // on one row on iPhone 11 / SE and don't push the control
              // bar past the home-indicator. Chips remain centred when
              // they fit; if they don't, the user scrolls horizontally.
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: secretlyListPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < routeState.availableRoutes.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            left: i == 0 ? 0 : 10,
                          ),
                          child: _AudioRouteChoiceButton(
                            icon: _audioRouteIcon(
                              routeState.availableRoutes[i].kind,
                            ),
                            label: _audioRouteLabel(
                              context: context,
                              route: routeState.availableRoutes[i],
                              speakerLabel: l10n.callControlSpeaker,
                            ),
                            active: routeState.availableRoutes[i].deviceId ==
                                routeState.selectedRouteId,
                            onTap: () => onSelectAudioRoute(
                              routeState.availableRoutes[i].deviceId,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // Upgrade to video (audio-only calls)
            if (!state.isVideo &&
                (state.phase == CallPhase.connected ||
                    state.phase == CallPhase.connecting))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextButton.icon(
                  onPressed: () => callManager.upgradeToVideo(),
                  icon: const Icon(AppIcons.video, color: Colors.white),
                  label: Text(
                    l10n.callVideoCall,
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            // Main control buttons.
            //
            // PR-H+1b (2026-05-20, revised after user feedback): keep
            // ALL buttons on ONE row with even spacing across every
            // screen size. LayoutBuilder computes the button size
            // dynamically — Pro Max keeps the 56 dp legacy buttons with
            // wide gaps, iPhone 11 (375 dp) gets ~46 dp buttons with
            // ~14 dp gaps, iPhone SE (320 dp) bottoms out at 44 dp
            // (Apple HIG min tap target) with ~5 dp gaps.
            //
            // The previous Wrap-based fix put hangup alone in a second
            // row — visually unbalanced. This revision restores the
            // single-row layout the user expects while keeping spacing
            // mathematically even.
            LayoutBuilder(
              builder: (context, constraints) {
                // 🔴 ВХОДЯЩИЙ ЗВОНОК: ДВЕ КНОПКИ, А НЕ ОДИН СБРОС (13.08.2026).
                //
                // Пока трубка не взята, обычная панель бессмысленна и ОПАСНА: в
                // ней единственное действие со звонком — отбой. 12.08 я направил
                // сюда нажатие на уведомление, и человек, жавший «ответить»,
                // сбрасывал себе звонок. Правка откачена, и порядок теперь
                // обратный: сначала кнопки, потом маршрут.
                //
                // Здесь ровно то, что человек вправе ожидать: видно, кто звонит,
                // и два решения рядом — принять или отклонить.
                final incoming =
                    state.phase == CallPhase.ringingIncoming &&
                    state.direction == CallDirection.incoming;
                if (incoming) {
                  return _IncomingCallControls(
                    onAccept: () => unawaited(callManager.acceptIncoming()),
                    onDecline: () => unawaited(callManager.declineIncoming()),
                  );
                }
                final children = <_ControlButton>[
                  _ControlButton(
                    icon: state.isMuted ? AppIcons.micOff : AppIcons.mic,
                    label: l10n.callControlMute,
                    active: !state.isMuted,
                    onTap: () => callManager.toggleMute(),
                  ),
                  _ControlButton(
                    icon: _audioRouteIcon(routeState.selectedRouteKind),
                    label: l10n.callControlSpeaker,
                    active: routeState.isSpeakerSelected,
                    onTap: onAudioRoutePrimaryTap,
                    onLongPress: onAudioRouteLongPress,
                  ),
                  if (state.isVideo)
                    _ControlButton(
                      icon: state.isCameraOff
                          ? AppIcons.videoOff
                          : AppIcons.video,
                      label: l10n.callControlCamera,
                      active: !state.isCameraOff,
                      onTap: () => callManager.toggleCamera(),
                    ),
                  if (state.isVideo)
                    _ControlButton(
                      icon: AppIcons.cameraSwitch,
                      label: l10n.callControlFlip,
                      active: true,
                      onTap: () => callManager.switchCamera(),
                    ),
                  if (state.isVideo &&
                      (state.phase == CallPhase.connected ||
                          state.phase == CallPhase.connecting ||
                          state.phase == CallPhase.reconnecting))
                    _ControlButton(
                      icon: state.isScreenSharing
                          ? AppIcons.screenShareOff
                          : AppIcons.screenShare,
                      label: state.isScreenSharing
                          ? l10n.callControlStop
                          : l10n.callControlShare,
                      active: state.isScreenSharing,
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final permissionDeniedText = wave1Text(
                          context,
                          ru: 'Нет разрешения на демонстрацию экрана',
                          en: 'Screen share permission denied',
                          uk: 'Немає дозволу на демонстрацію екрана',
                          es: 'Permiso de compartir pantalla denegado',
                          pt: 'Permissao de partilha de ecra negada',
                          ptBr: 'Permissao para compartilhar tela negada',
                          fr: 'Autorisation de partage d ecran refusee',
                          de: 'Berechtigung zur Bildschirmfreigabe verweigert',
                        );
                        final ok = await callManager.toggleScreenShare();
                        if (!ok) {
                          messenger.showSnackBar(
                            SecretlySnackBar(
                              content: Text(permissionDeniedText),
                            ),
                          );
                        }
                      },
                    ),
                  _ControlButton(
                    icon: AppIcons.callEnd,
                    label: l10n.callControlEnd,
                    active: true,
                    danger: true,
                    onTap: () => callManager.hangup(),
                  ),
                ];

                // Solve N*size + (N-1)*gap = avail for size.
                // Targets a 14 dp gap and lets the button shrink between
                // 44 (Apple HIG min tap target) and 56 (legacy default).
                // If width is so narrow that 44 dp buttons + 14 dp gaps
                // still overflow, we squeeze the gap down to >= 4 dp.
                final n = children.length;
                final avail = constraints.maxWidth;
                const desiredGap = 14.0;
                const minGap = 4.0;
                const maxBtn = 56.0;
                const minBtn = 44.0;

                final rawSize = (avail - desiredGap * (n - 1)) / n;
                double btnSize = rawSize.clamp(minBtn, maxBtn);
                double gap = desiredGap;
                if (rawSize < minBtn) {
                  btnSize = minBtn;
                  gap = ((avail - btnSize * n) / (n - 1))
                      .clamp(minGap, desiredGap);
                }

                // PR-H+2 (2026-05-20): hard-constrain each control to
                // `btnSize` width, otherwise the Column's natural width is
                // max(circleWidth, labelTextWidth) — Russian labels like
                // "Завершить" / "Демонстрация" stretch the column past
                // `btnSize`, breaking the math and pushing the rightmost
                // button (hangup) off-screen on small phones.
                final row = <Widget>[];
                for (var i = 0; i < children.length; i++) {
                  final c = children[i];
                  row.add(
                    SizedBox(
                      width: btnSize,
                      child: _ControlButton(
                        icon: c.icon,
                        label: c.label,
                        active: c.active,
                        danger: c.danger,
                        accept: c.accept,
                        onTap: c.onTap,
                        size: btnSize,
                      ),
                    ),
                  );
                  if (i < children.length - 1) {
                    row.add(SizedBox(width: gap));
                  }
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: row,
                );
              },
            ),
          ],
        ),
        ),
      ),
    );
  }
}

IconData _audioRouteIcon(CallAudioRouteKind kind) {
  switch (kind) {
    case CallAudioRouteKind.bluetooth:
      return AppIcons.bluetoothAudio;
    case CallAudioRouteKind.wiredHeadset:
      return AppIcons.headphones;
    case CallAudioRouteKind.earpiece:
      return AppIcons.call;
    case CallAudioRouteKind.speaker:
      return AppIcons.volumeUp;
    case CallAudioRouteKind.unknown:
      return AppIcons.volumeDown;
  }
}

String _audioRouteLabel({
  required BuildContext context,
  required CallAudioRouteOption route,
  required String speakerLabel,
}) {
  switch (route.kind) {
    case CallAudioRouteKind.bluetooth:
      return route.label.isNotEmpty ? route.label : 'Bluetooth';
    case CallAudioRouteKind.wiredHeadset:
      return wave1Text(context, ru: 'Наушники', en: 'Headset');
    case CallAudioRouteKind.earpiece:
      return wave1Text(context, ru: 'Телефон', en: 'Earpiece');
    case CallAudioRouteKind.speaker:
      return speakerLabel;
    case CallAudioRouteKind.unknown:
      return route.label.isNotEmpty
          ? route.label
          : wave1Text(context, ru: 'Аудио', en: 'Audio');
  }
}

class _AudioRouteChoiceButton extends StatelessWidget {
  const _AudioRouteChoiceButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? Colors.white.withValues(alpha: 0.36)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Single control button
// ═══════════════════════════════════════════════════════════════════════════

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onLongPress,
    this.danger = false,
    this.accept = false,
    this.size = 56.0,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool danger;

  /// Зелёная кнопка приёма звонка. Отдельно от [danger], чтобы «принять» и
  /// «отклонить» нельзя было перепутать ни в коде, ни глазами.
  final bool accept;
  final VoidCallback onTap;

  /// Долгое нажатие. У громкой связи это выбор маршрута: раньше он
  /// забирал ОБЫЧНОЕ нажатие, и кнопка переставала быть переключателем.
  final VoidCallback? onLongPress;
  // PR-H+1b (2026-05-20): parameterized so the parent LayoutBuilder can
  // shrink the button on small screens. Icon and label scale with size to
  // preserve proportions. Default 56 matches the legacy hard-coded value.
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFFE53935)
        : accept
        ? const Color(0xFF2FA66A)
        : active
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.08);
    final fg = danger || accept || active ? Colors.white : Colors.white54;
    final double buttonSize = size;
    final double iconSize = (size * 26.0 / 56.0).clamp(20.0, 28.0);
    const labelGap = 6.0;
    const labelSize = 11.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(icon, key: ValueKey(icon), color: fg, size: iconSize),
            ),
          ),
          SizedBox(height: labelGap),
          // PR-H+2 (2026-05-20): one line, ellipsis on overflow, centred.
          // Parent SizedBox(width: btnSize) constrains the column width so
          // long Russian labels can't push the row over the screen edge.
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: labelSize,
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}


/// Управление входящим звонком: две большие кнопки, как в профессиональных
/// мессенджерах.
///
/// 🔴 ПОЧЕМУ ОТДЕЛЬНЫЙ УЗЕЛ, А НЕ ДВА `_ControlButton`. Обычная панель
/// рассчитана на пять мелких кнопок в ряд и делит ширину между ними. Для
/// решения «принять или отклонить» это неверно: кнопки должны быть КРУПНЫМИ и
/// РАЗНЕСЁННЫМИ, чтобы в спешке нельзя было промахнуться и сбросить звонок
/// вместо ответа. Промах здесь стоит дорого — 12.08 человек именно так и
/// сбрасывал себе вызовы.
class _IncomingCallControls extends StatelessWidget {
  const _IncomingCallControls({
    required this.onAccept,
    required this.onDecline,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Широкие поля разносят кнопки к краям — палец не перепутает.
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IncomingActionButton(
            icon: AppIcons.callEnd,
            color: const Color(0xFFE53935),
            label: wave1Text(
              context,
              ru: 'Отклонить',
              en: 'Decline',
              uk: 'Відхилити',
              es: 'Rechazar',
              pt: 'Rejeitar',
              ptBr: 'Recusar',
              fr: 'Refuser',
              de: 'Ablehnen',
            ),
            hint: wave1Text(
              context,
              ru: 'смахните вверх',
              en: 'swipe up',
              uk: 'проведіть вгору',
              es: 'desliza arriba',
              pt: 'deslize para cima',
              ptBr: 'deslize para cima',
              fr: 'glissez vers le haut',
              de: 'nach oben wischen',
            ),
            pulse: false,
            onTrigger: onDecline,
          ),
          _IncomingActionButton(
            icon: AppIcons.call,
            color: const Color(0xFF2FA66A),
            label: wave1Text(
              context,
              ru: 'Принять',
              en: 'Accept',
              uk: 'Прийняти',
              es: 'Aceptar',
              pt: 'Atender',
              ptBr: 'Atender',
              fr: 'Répondre',
              de: 'Annehmen',
            ),
            hint: wave1Text(
              context,
              ru: 'смахните вверх',
              en: 'swipe up',
              uk: 'проведіть вгору',
              es: 'desliza arriba',
              pt: 'deslize para cima',
              ptBr: 'deslize para cima',
              fr: 'glissez vers le haut',
              de: 'nach oben wischen',
            ),
            pulse: true,
            onTrigger: onAccept,
          ),
        ],
      ),
    );
  }
}

/// Одна кнопка входящего звонка: нажатие ИЛИ смахивание вверх.
///
/// 🔴 ОБА ЖЕСТА, А НЕ ТОЛЬКО СМАХИВАНИЕ. Смахивание — привычка из Telegram, но
/// оставить ТОЛЬКО его значит отобрать звонок у тех, кто им не владеет: у людей
/// с трясущимися руками, в перчатках, с крупной моторикой. Нажатие остаётся
/// полноценным путём.
class _IncomingActionButton extends StatefulWidget {
  const _IncomingActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.hint,
    required this.pulse,
    required this.onTrigger,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String hint;

  /// Лёгкое «дыхание» у кнопки приёма — она главная. У отклонения его нет:
  /// две пульсирующие кнопки рядом соревнуются за внимание и мешают решать.
  final bool pulse;
  final VoidCallback onTrigger;

  @override
  State<_IncomingActionButton> createState() => _IncomingActionButtonState();
}

class _IncomingActionButtonState extends State<_IncomingActionButton>
    with SingleTickerProviderStateMixin {
  static const double _size = 72;

  /// Порог смахивания. Меньше — и кнопка срабатывала бы от случайного дёрганья
  /// при поднесении телефона к уху.
  static const double _triggerDy = 56;

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  double _dragDy = 0;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _breath.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    widget.onTrigger();
  }

  @override
  Widget build(BuildContext context) {
    // Прогресс смахивания: и подсветка, и подъём кнопки под пальцем.
    final progress = (_dragDy.abs() / _triggerDy).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _fire,
      onVerticalDragUpdate: (d) {
        // Вниз не считаем: жест только вверх, иначе сработает от прокрутки.
        final next = (_dragDy + d.delta.dy).clamp(-_triggerDy * 1.4, 0.0);
        setState(() => _dragDy = next);
      },
      onVerticalDragEnd: (_) {
        if (_dragDy.abs() >= _triggerDy) {
          _fire();
        }
        setState(() => _dragDy = 0);
      },
      onVerticalDragCancel: () => setState(() => _dragDy = 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Подсказка проявляется по мере смахивания — не мозолит глаза сразу.
          AnimatedOpacity(
            opacity: 0.35 + 0.65 * progress,
            duration: const Duration(milliseconds: 120),
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          AnimatedBuilder(
            animation: _breath,
            builder: (context, child) {
              // Дыхание слабое (4 %) и гаснет, как только палец повёл кнопку:
              // два движения одновременно читаются как дребезг.
              final breath = widget.pulse
                  ? 1 + 0.04 * _breath.value * (1 - progress)
                  : 1.0;
              return Transform.translate(
                offset: Offset(0, _dragDy * 0.6),
                child: Transform.scale(scale: breath, child: child),
              );
            },
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(
                      alpha: 0.30 + 0.35 * progress,
                    ),
                    blurRadius: 16 + 14 * progress,
                    spreadRadius: 1 + 2 * progress,
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.hint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
