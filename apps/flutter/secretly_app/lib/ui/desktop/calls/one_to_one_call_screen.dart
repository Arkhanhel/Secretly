// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../calls/call_manager.dart';
import '../../../calls/call_state.dart';
import '../../../calls/webrtc_call_session.dart';
import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../primitives/avatar.dart';
import '../primitives/hover_listener.dart';
import 'call_controls.dart';
import 'call_peer_label.dart';

/// Сцена созвона — чёрная в любой теме.
const Color _kCallStage = Color(0xFF0A0B0E);

/// Telegram-style 1:1 call, driven by [CallManager]. The big remote stream (or
/// avatar for audio) fills the screen; the local self-view floats as a
/// draggable PIP. Controls reflect + drive real call state (mic / camera /
/// screen-share). The control dock auto-hides after a few seconds of mouse
/// inactivity.
class OneToOneCallScreen extends StatefulWidget {
  const OneToOneCallScreen({
    super.key,
    required this.callManager,
    this.peerName = '',
    this.peerImage,
    this.onEnd,
  });

  final CallManager callManager;
  final String peerName;
  final ImageProvider? peerImage;
  final VoidCallback? onEnd;

  @override
  State<OneToOneCallScreen> createState() => _OneToOneCallScreenState();
}

class _OneToOneCallScreenState extends State<OneToOneCallScreen> {
  bool _controlsVisible = true;
  // Hand-raise has no 1:1 call semantics — kept as a local visual affordance.
  bool _handRaised = false;
  Offset _pipOffset = const Offset(-24, -120);

  Timer? _ticker; // 1s refresh for the duration label
  Timer? _hideTimer;

  /// Полноэкранный режим окна.
  ///
  /// Состояние спрашивается у окна, а не хранится своё: окно можно развернуть
  /// и мимо этой кнопки — из меню или клавишей, — и своя память об этом
  /// разошлась бы с действительностью.
  bool _fullScreen = false;

  Future<void> _toggleFullScreen() async {
    try {
      final next = !(await windowManager.isFullScreen());
      await windowManager.setFullScreen(next);
      if (mounted) setState(() => _fullScreen = next);
    } catch (_) {
      // Не десктопная система или окно недоступно — кнопка просто ничего не
      // делает, и это лучше, чем упасть посреди звонка.
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _armHideTimer();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _armHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _onHover() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _armHideTimer();
  }

  String _peerNameFor(CallState s) => desktopCallPeerTitle(
    s,
    AppLocalizations.of(context)!,
    preferred: widget.peerName,
  );

  String _statusLabel(CallState s) {
    switch (s.phase) {
      case CallPhase.ringingOutgoing:
        return 'Вызов…';
      case CallPhase.connecting:
        return 'Соединение…';
      case CallPhase.reconnecting:
        return 'Переподключение…';
      case CallPhase.connected:
        final started = s.connectedAtMs ?? s.startedAtMs;
        if (started == null) return 'Зашифровано';
        final ms = DateTime.now().millisecondsSinceEpoch - started;
        return 'Зашифровано · ${_fmtDuration(ms)}';
      case CallPhase.ended:
        return 'Завершено';
      case CallPhase.ringingIncoming:
      case CallPhase.idle:
        return 'Зашифровано';
    }
  }

  static String _fmtDuration(int ms) {
    final total = (ms / 1000).floor().clamp(0, 1 << 30);
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CallState>(
      valueListenable: widget.callManager.state,
      builder: (ctx, s, _) => _buildForState(ctx, s),
    );
  }

  Widget _buildForState(BuildContext context, CallState s) {
    final c = DColors.of(context);
    final cm = widget.callManager;
    final session = cm.session;
    final name = _peerNameFor(s);
    final avatarName = desktopCallPeerKnownName(s, preferred: widget.peerName);
    final label = _statusLabel(s);

    final micOn = !s.isMuted;
    final camOn = s.isVideo && !s.isCameraOff;
    final sharing = s.isScreenSharing;

    final Widget remote = (s.isVideo && session != null)
        ? _DesktopRemoteVideo(
            session: session,
            peerName: name,
            avatarName: avatarName,
            peerSeed: s.peerProfileId,
            peerImage: widget.peerImage,
            label: label,
          )
        : _AvatarStage(
            name: name,
            avatarName: avatarName,
            seed: s.peerProfileId,
            image: widget.peerImage,
            label: label,
          );

    final Widget pipChild = (camOn && session != null)
        ? _DesktopLocalVideo(session: session, mirror: s.isFrontCamera)
        : const _CameraOffTile();

    return MouseRegion(
      onHover: (_) => _onHover(),
      child: Container(
        color: _kCallStage,
        child: Stack(
          children: [
            Positioned.fill(child: remote),
            // 🔴 ШАПКА СОЗВОНА: С КЕМ, В КАКОМ СОСТОЯНИИ, СКОЛЬКО ИДЁТ.
            //
            // Раньше слева висел только ярлычок состояния. В видеозвонке имени
            // собеседника не было видно НИГДЕ: камера занимает весь экран, а
            // подпись под портретом видна лишь пока портрет показывается. То
            // есть окно не отвечало на вопрос «с кем я говорю» — а звонок
            // можно и принять, не разглядев, кто звонит.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: DMotion.base,
                opacity: _controlsVisible ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(
                      DSpace.l,
                      DSpace.m,
                      DSpace.m,
                      DSpace.m,
                    ),
                    decoration: BoxDecoration(
                      // Затемнение сверху: белые подписи поверх светлого кадра
                      // камеры иначе не читаются.
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DType.bodyStrong.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: DSpace.m),
                        _CallChip(label: label, color: c.success),
                        const Spacer(),
                        _CallChromeButton(
                          icon: _fullScreen
                              ? FluentIcons.full_screen_minimize_24_regular
                              : FluentIcons.full_screen_maximize_24_regular,
                          tooltip: _fullScreen
                              ? 'Выйти из полноэкранного'
                              : 'Во весь экран',
                          onTap: _toggleFullScreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Floating local self-view PIP (only meaningful for video calls).
            if (s.isVideo)
              Positioned(
                right: -_pipOffset.dx,
                bottom: -_pipOffset.dy,
                child: _PipSelfView(
                  muted: !micOn,
                  onDrag: (delta) => setState(() => _pipOffset += delta),
                  child: pipChild,
                ),
              ),
            // Control dock.
            Positioned(
              left: 0,
              right: 0,
              bottom: DSpace.xl,
              child: AnimatedOpacity(
                duration: DMotion.base,
                opacity: _controlsVisible ? 1.0 : 0.0,
                child: Center(
                  child: CallControls(
                    micOn: micOn,
                    camOn: camOn,
                    sharingScreen: sharing,
                    handRaised: _handRaised,
                    onToggleMic: () => unawaited(cm.toggleMute()),
                    // Audio call → camera button starts video; video call →
                    // toggle the camera on/off.
                    onToggleCam: () => unawaited(
                      s.isVideo ? cm.toggleCamera() : cm.upgradeToVideo(),
                    ),
                    onToggleScreenShare: () =>
                        unawaited(cm.toggleScreenShare()),
                    onToggleHand: () =>
                        setState(() => _handRaised = !_handRaised),
                    onEnd: () => widget.onEnd?.call(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Чип состояния созвона: замок, состояние и длительность.
///
/// 🔴 Замок, а не просто точка. Точка означает «связь есть» — это и так видно
/// по картинке. Здесь же сказано «Зашифровано», и знак рядом должен означать
/// ровно это: тот же замок и тот же зелёный, что у поля ввода в переписке.
///
/// Задержки в чипе НЕТ, хотя в макете она есть: `CallState` времени отклика не
/// несёт, а рисовать правдоподобное число, взятое ниоткуда, — худшее, что
/// можно сделать в окне, где человек решает, слышно его или нет.
class _CallChip extends StatelessWidget {
  const _CallChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(DRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.lock_closed_16_filled, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: DType.family,
              fontSize: 11.5,
              height: 1.0,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка в шапке созвона. Полупрозрачная: она лежит поверх живого кадра.
class _CallChromeButton extends StatelessWidget {
  const _CallChromeButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: HoverListener(
        onTap: onTap,
        builder: (ctx, hovered, pressed) => AnimatedContainer(
          duration: DMotion.fast,
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: pressed ? 0.20 : (hovered ? 0.14 : 0.06),
            ),
            borderRadius: BorderRadius.circular(DRadii.sm),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// Big remote surface: avatar background with the live remote video mounted on
/// top once it's renderable (mirrors mobile's `_RemoteVideoSurface`).
class _DesktopRemoteVideo extends StatelessWidget {
  const _DesktopRemoteVideo({
    required this.session,
    required this.peerName,
    required this.avatarName,
    required this.peerSeed,
    required this.peerImage,
    required this.label,
  });

  final WebRtcCallSession session;
  final String peerName;
  final String avatarName;
  final String peerSeed;
  final ImageProvider? peerImage;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RemoteVideoLifecycle>(
      valueListenable: session.remoteVideoLifecycle,
      builder: (context, lifecycle, _) {
        final mount =
            lifecycle.isRenderable || _hasVideoTracks(session.remoteRenderer);
        return Stack(
          fit: StackFit.expand,
          children: [
            _AvatarStage(
              name: peerName,
              avatarName: avatarName,
              seed: peerSeed,
              image: peerImage,
              label: label,
            ),
            if (mount)
              RTCVideoView(
                key: ValueKey(
                  'remote:${session.hashCode}:${lifecycle.state.name}:${_bindingToken(session.remoteRenderer)}',
                ),
                session.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
          ],
        );
      },
    );
  }
}

class _DesktopLocalVideo extends StatelessWidget {
  const _DesktopLocalVideo({required this.session, required this.mirror});

  final WebRtcCallSession session;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return RTCVideoView(
      key: ValueKey(
        'local:${session.hashCode}:${_bindingToken(session.localRenderer)}',
      ),
      session.localRenderer,
      mirror: mirror,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}

bool _hasVideoTracks(RTCVideoRenderer renderer) {
  final stream = renderer.srcObject;
  if (stream == null) return false;
  try {
    return stream.getVideoTracks().isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Stable token so [RTCVideoView] rebinds when the underlying stream/tracks
/// change. Mirrors mobile's `_videoRendererBindingToken`.
String _bindingToken(RTCVideoRenderer renderer) {
  final stream = renderer.srcObject;
  if (stream == null) return 'stream:none';
  try {
    final trackIds = stream.getVideoTracks().map((t) => t.id).join(',');
    return 'stream:${stream.id}|tracks:${trackIds.isEmpty ? 'none' : trackIds}';
  } catch (_) {
    return 'stream:${stream.id}|tracks:error';
  }
}

/// Audio / no-remote-video stage: centered avatar, name and status label.
class _AvatarStage extends StatelessWidget {
  const _AvatarStage({
    required this.name,
    this.avatarName = '',
    required this.seed,
    this.image,
    required this.label,
  });

  final String name;

  /// Настоящее имя для букв на заглушке; пустое — «?», а не буквы подписи.
  final String avatarName;

  /// Ключ цвета заглушки — профиль собеседника, как в списке чатов. По имени
  /// тот же человек выходил в звонке другого цвета (17.09.2026).
  final String seed;
  final ImageProvider? image;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заливка — от чёрной сцены, а не от фона окна: в светлой теме
          // иначе на сцене лежало бы бледное пятно.
          Avatar(
            name: avatarName,
            seed: seed,
            image: image,
            size: 160,
            background: _kCallStage,
          ),
          const SizedBox(height: DSpace.l),
          Text(name, style: DType.title.copyWith(color: Colors.white)),
          const SizedBox(height: DSpace.xs),
          Text(label, style: DType.label.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _CameraOffTile extends StatelessWidget {
  const _CameraOffTile();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF16181D),
      alignment: Alignment.center,
      child: const Icon(
        Icons.videocam_off_rounded,
        color: Colors.white38,
        size: 28,
      ),
    );
  }
}

class _PipSelfView extends StatelessWidget {
  const _PipSelfView({
    required this.child,
    required this.muted,
    required this.onDrag,
  });
  final Widget child;
  final bool muted;
  final ValueChanged<Offset> onDrag;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) => onDrag(d.delta),
      child: Container(
        width: 200,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DRadii.lg),
          boxShadow: DShadows.floating,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (muted)
              const Positioned(
                left: 8,
                bottom: 8,
                child: Icon(
                  Icons.mic_off_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
