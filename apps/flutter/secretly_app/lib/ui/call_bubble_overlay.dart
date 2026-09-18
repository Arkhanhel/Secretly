// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../calls/call_manager.dart';
import '../calls/webrtc_call_session.dart';

/// Floating call bubble shown when the active-call UI is minimized.
/// Sits at the root of the widget tree so it overlays any screen.
/// Behaviour mirrors WhatsApp:
///   • Video bubble shows live remote video.
///   • Freely draggable; snaps to the nearest vertical edge on release.
///   • Single tap reveals minimal expand / close controls; they auto-hide after 4 s.
class CallBubbleOverlay extends StatefulWidget {
  const CallBubbleOverlay({super.key, required this.callManager});

  final CallManager callManager;

  @override
  State<CallBubbleOverlay> createState() => _CallBubbleOverlayState();
}

class _CallBubbleOverlayState extends State<CallBubbleOverlay>
    with TickerProviderStateMixin {
  // Position
  Offset _pos = Offset.zero;
  bool _posInitialized = false;

  // Snap animation (spring to edge)
  AnimationController? _snapCtrl;
  double _snapFrom = 0;
  double _snapTo = 0;

  // Controls overlay (expand / end)
  bool _showControls = false;
  Timer? _controlsTimer;

  // Drag guard to stop accidental tap after pan
  bool _panning = false;

  static const double _videoW = 110;
  static const double _videoH = 160;
  static const double _margin = 12;

  @override
  void initState() {
    super.initState();
    widget.callManager.state.addListener(_onState);
    _snapCtrl = AnimationController.unbounded(vsync: this)
      ..addListener(_onSnapTick);
  }

  void _onState() {
    if (!mounted) return;
    final s = widget.callManager.state.value;
    // Reset position when a new call becomes minimized.
    if (!s.isUiMinimized) _posInitialized = false;
    setState(() {});
  }

  void _onSnapTick() {
    if (!mounted) return;
    setState(() => _pos = Offset(_snapCtrl!.value, _pos.dy));
  }

  void _snapToEdge(Size screen) {
    const w = _videoW;
    final mid = _pos.dx + w / 2;
    _snapFrom = _pos.dx;
    _snapTo = mid < screen.width / 2 ? _margin : screen.width - w - _margin;
    const spring = SpringDescription(mass: 1, stiffness: 300, damping: 24);
    _snapCtrl!.animateWith(SpringSimulation(spring, _snapFrom, _snapTo, 0));
  }

  void _initPos(Size screen, double safeTop) {
    if (_posInitialized) return;
    _posInitialized = true;
    const w = _videoW;
    const h = _videoH;
    _pos = Offset(
      screen.width - w - _margin,
      (screen.height - h) * 0.45 + safeTop,
    );
    _snapCtrl!.value = _pos.dx;
  }

  void _onTap() {
    if (_panning) {
      _panning = false;
      return;
    }
    setState(() => _showControls = !_showControls);
    _controlsTimer?.cancel();
    if (_showControls) {
      _controlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  @override
  void dispose() {
    widget.callManager.state.removeListener(_onState);
    _snapCtrl?.dispose();
    _controlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.callManager.state.value;
    if (!state.isUiMinimized || !state.isActive || !state.isVideo) {
      return const SizedBox.shrink();
    }

    final session = widget.callManager.session;
    final screen = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final minY = padding.top + 8;
    final maxY = screen.height - padding.bottom - _videoH - 8;

    _initPos(screen, padding.top);

    const bubbleW = _videoW;
    const bubbleH = _videoH;
    const radius = 16.0;

    final clampedX = _pos.dx.clamp(0.0, screen.width - bubbleW);
    final clampedY = _pos.dy.clamp(minY, maxY);

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onTap: _onTap,
        onPanStart: (_) {
          _panning = false;
          _snapCtrl?.stop();
        },
        onPanUpdate: (d) {
          _panning = true;
          setState(() {
            _pos = Offset(
              (_pos.dx + d.delta.dx).clamp(0.0, screen.width - bubbleW),
              (_pos.dy + d.delta.dy).clamp(minY, maxY),
            );
            _snapCtrl!.value = _pos.dx;
          });
        },
        onPanEnd: (_) => _snapToEdge(screen),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _BubbleShell(
            key: const ValueKey('video-call-bubble'),
            w: bubbleW,
            h: bubbleH,
            radius: radius,
            child: _BubbleBody(
              session: session,
              showControls: _showControls,
              onOpen: () {
                _controlsTimer?.cancel();
                setState(() => _showControls = false);
                widget.callManager.resumeCallUi();
              },
              onEnd: () {
                _controlsTimer?.cancel();
                setState(() => _showControls = false);
                widget.callManager.hangup();
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shell ────────────────────────────────────────────────────────────────────

class _BubbleShell extends StatelessWidget {
  const _BubbleShell({
    super.key,
    required this.w,
    required this.h,
    required this.radius,
    required this.child,
  });

  final double w;
  final double h;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: child,
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({
    required this.session,
    required this.showControls,
    required this.onOpen,
    required this.onEnd,
  });

  final WebRtcCallSession? session;
  final bool showControls;
  final VoidCallback onOpen;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (session != null)
          _VideoContent(session: session!)
        else
          const _VideoPlaceholder(),

        // Controls overlay: icon-only, with no individual button backgrounds.
        AnimatedOpacity(
          opacity: showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !showControls,
            child: _ControlsOverlay(onOpen: onOpen, onEnd: onEnd),
          ),
        ),
      ],
    );
  }
}

// ─── Video content ────────────────────────────────────────────────────────────

class _VideoContent extends StatelessWidget {
  const _VideoContent({required this.session});

  final WebRtcCallSession session;

  @override
  Widget build(BuildContext context) {
    return RTCVideoView(
      session.remoteRenderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}

// ─── Video placeholder ───────────────────────────────────────────────────────

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black),
        Center(
          child: Icon(Icons.videocam_rounded, color: Colors.white70, size: 30),
        ),
      ],
    );
  }
}

// ─── Controls overlay ─────────────────────────────────────────────────────────

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({required this.onOpen, required this.onEnd});

  final VoidCallback onOpen;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: _OverlayIconButton(
            icon: Icons.open_in_full_rounded,
            semanticLabel: 'Open call',
            size: 32,
            hitSize: 58,
            onTap: onOpen,
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: _OverlayIconButton(
            icon: Icons.close_rounded,
            semanticLabel: 'End call',
            size: 22,
            hitSize: 36,
            onTap: onEnd,
          ),
        ),
      ],
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.size,
    required this.hitSize,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final double size;
  final double hitSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: hitSize,
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: size,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
