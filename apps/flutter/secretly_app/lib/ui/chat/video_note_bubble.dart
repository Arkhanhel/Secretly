// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/e2e_payload_v1.dart';

/// Guards that only ONE enlarged video-note exists at a time. When a note
/// expands it publishes its collapse callback here; expanding another note
/// first collapses the previous one (so two big squares never overlap).
VoidCallback? _activeCollapse;

/// Telegram-style round-video message — but SQUARE. A fast record / fast-view
/// mini video-voice-message rendered BARE over the chat wallpaper (no bubble
/// background): just the rounded square plus a minimal floating footer below.
///
/// Behaviour:
///  * In the chat list the note does NOT autoplay. It shows a STATIC first
///    frame (controller initialised, seeked to 0, PAUSED) plus a subtle
///    centered play affordance and the duration. No looping, no muted autoplay.
///  * TAP the small square → it EXPANDS IN PLACE, right inside the chat
///    ListView. The note's reserved layout footprint grows to a large centered
///    square, so neighbouring messages smoothly slide apart ("расступаются") to
///    make room. There is NO overlay, NO scrim, NO dimming — the chat stays
///    fully visible around the growing note. Because the item legitimately
///    occupies more space (real layout, not a Transform.scale), nothing is
///    clipped by the viewport. While enlarged it plays WITH SOUND and centers
///    horizontally across the full chat width (sender-side alignment is
///    ignored). The note also scrolls toward the vertical middle of the
///    viewport via [Scrollable.ensureVisible].
///  * While enlarged: TAP toggles play ⇄ pause (center play glyph when
///    paused); a faint "X" top-right (or a tap) collapses it back to the small
///    in-list static paused frame and the neighbours reflow back. The white
///    bottom-edge progress slider + horizontal drag-to-seek live in the
///    enlarged state.
class VideoNoteBubble extends StatefulWidget {
  const VideoNoteBubble({
    super.key,
    required this.attachment,
    required this.isMe,
    required this.resolveFile,
    required this.footer,
    this.header,
    this.diameter,
  });

  final AttachmentEventV1 attachment;
  final bool isMe;

  /// Resolves (downloads + decrypts, cached) the local file for this note —
  /// wire to `controller.ensureCachedAttachmentFile`.
  final Future<File> Function(AttachmentEventV1 attachment) resolveFile;

  /// Bubble chrome (timestamp + ticks + reactions) built by the chat screen so
  /// the footer stays consistent with every other bubble. Rendered with NO
  /// bubble background, directly below the square.
  final Widget footer;

  /// Optional group-author header (avatar + name) rendered above the square.
  final Widget? header;

  /// Optional override for the (small) square edge length.
  final double? diameter;

  @override
  State<VideoNoteBubble> createState() => _VideoNoteBubbleState();
}

class _VideoNoteBubbleState extends State<VideoNoteBubble>
    with SingleTickerProviderStateMixin {
  /// Anchors the in-list square (used for [Scrollable.ensureVisible]).
  final GlobalKey _squareKey = GlobalKey();

  /// Owned here for the whole widget lifetime: initialised for the static
  /// first frame, played (with sound) while enlarged, and disposed when this
  /// widget is disposed.
  VideoPlayerController? _controller;
  bool _initStarted = false;
  bool _initialized = false;
  bool _failed = false;

  /// Whether the note is currently enlarged (expanded in place).
  bool _enlarged = false;

  /// Drives the in-place grow/collapse. 0 = small in-list note, 1 = large
  /// centered square. The reserved layout footprint AND the inner square both
  /// lerp on this, so the ListView reflows (neighbours part) as it grows.
  late final AnimationController _anim;
  late final Animation<double> _t;

  /// Periodic repaint while enlarged so the progress slider / countdown stay
  /// in sync (the video controller also ticks, but this keeps it smooth even
  /// when no frame event fires).
  Timer? _ticker;

  bool _scrubbing = false;
  double _scrubFraction = 0;

  /// The exact callback this state registered into [_activeCollapse], so
  /// teardown only clears the global guard when it still points at us.
  VoidCallback? _myCollapse;

  static const double _radius = 44;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _t = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
    _anim.addStatusListener(_onAnimStatus);
    // Kick off init for the static first frame (no autoplay).
    unawaited(_ensureInitialized());
  }

  @override
  void dispose() {
    _releaseGlobalGuard();
    _ticker?.cancel();
    _anim.removeStatusListener(_onAnimStatus);
    _anim.dispose();
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    final c = _controller;
    _controller = null;
    _initStarted = false;
    _initialized = false;
    if (c != null) {
      c.removeListener(_onControllerTick);
      unawaited(c.dispose());
    }
  }

  void _onControllerTick() {
    if (!mounted) return;
    // Keep the slider / countdown live while enlarged; cheap repaint for the
    // paused→playing flip otherwise.
    if (_scrubbing) return;
    setState(() {});
  }

  /// Boots the controller, seeks to the first frame, and keeps it PAUSED so the
  /// list shows a static poster — never autoplaying.
  Future<void> _ensureInitialized() async {
    if (_initialized || _initStarted) return;
    _initStarted = true;
    if (_failed && mounted) setState(() => _failed = false);
    try {
      final file = await widget.resolveFile(widget.attachment);
      if (!mounted) {
        _initStarted = false;
        return;
      }
      final controller = VideoPlayerController.file(file);
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        _controller = null;
        _initStarted = false;
        await controller.dispose();
        return;
      }
      _initialized = true;
      // Static poster: muted, paused, parked on the first frame.
      await controller.setLooping(false);
      await controller.setVolume(0);
      await controller.seekTo(Duration.zero);
      await controller.pause();
      controller.addListener(_onControllerTick);
      if (mounted) setState(() {});
    } catch (_) {
      _disposeController();
      if (mounted) setState(() => _failed = true);
    }
  }

  bool get _isReady => _initialized && _controller != null;

  // ── Tap on the SMALL note → expand in place ─────────────────────────────
  void _onTapSmall() {
    if (_failed) {
      _initStarted = false;
      unawaited(_ensureInitialized());
      return;
    }
    if (!_isReady) {
      // Tap landed before init finished — boot it; user can tap again.
      unawaited(_ensureInitialized());
      return;
    }
    _enlarge();
  }

  void _enlarge() {
    if (_enlarged) return;

    // Only one enlarged note at a time — collapse any other open note first.
    if (_activeCollapse != null && _activeCollapse != _myCollapse) {
      _activeCollapse!.call();
    }
    _myCollapse = _collapse;
    _activeCollapse = _myCollapse;

    setState(() => _enlarged = true);

    final c = _controller;
    if (c != null && _initialized) {
      // Play WITH SOUND while enlarged.
      unawaited(() async {
        // Play ONCE (not looped) so it can auto-close when it reaches the end.
        await c.setLooping(false);
        await c.setVolume(1.0);
        await c.seekTo(Duration.zero);
        if (!c.value.isPlaying) await c.play();
        if (mounted) setState(() {});
      }());
    }

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted || !_enlarged) return;
      // Auto-close once it has played through — мягко сворачиваем к постеру.
      final pc = _controller;
      if (pc != null && pc.value.isInitialized && !_scrubbing) {
        final dur = pc.value.duration;
        if (dur > const Duration(milliseconds: 300) &&
            pc.value.position >= dur - const Duration(milliseconds: 80)) {
          _collapse();
          return;
        }
      }
      if (!_scrubbing) setState(() {});
    });

    _anim.forward();

    // Best-effort: scroll the (now growing) note toward the vertical middle of
    // the chat viewport so it "вылезает к середине экрана". Runs after this
    // frame so the enlarged footprint is laid out first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _squareKey.currentContext;
      if (ctx == null || !mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  /// Collapse back to the small in-list note: reverse the grow animation,
  /// mute + pause + park on the first frame, and reflow neighbours back.
  void _collapse() {
    if (!_enlarged) return;
    setState(() => _enlarged = false);
    _ticker?.cancel();
    _releaseGlobalGuard();

    final c = _controller;
    if (c != null && _initialized) {
      // No sound on the way back; restore the static first-frame poster.
      unawaited(() async {
        await c.pause();
        await c.setVolume(0);
        await c.setLooping(false);
        await c.seekTo(Duration.zero);
        if (mounted) setState(() {});
      }());
    }

    _anim.reverse();
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      // Fully collapsed — stop the high-frequency repaint ticker.
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _releaseGlobalGuard() {
    if (_myCollapse != null && _activeCollapse == _myCollapse) {
      _activeCollapse = null;
    }
    _myCollapse = null;
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null || !_initialized) return;
    if (c.value.isPlaying) {
      unawaited(c.pause());
    } else {
      unawaited(c.play());
    }
    if (mounted) setState(() {});
  }

  double get _progress {
    if (_scrubbing) return _scrubFraction;
    final c = _controller;
    if (c == null || !_initialized) return 0;
    final dur = c.value.duration.inMilliseconds;
    if (dur <= 0) return 0;
    return (c.value.position.inMilliseconds / dur).clamp(0.0, 1.0);
  }

  void _seekToFraction(double fraction) {
    final c = _controller;
    if (c == null || !_initialized) return;
    final ms = (c.value.duration.inMilliseconds * fraction).round();
    unawaited(c.seekTo(Duration(milliseconds: ms)));
  }

  /// Small state shows total duration; enlarged state counts down remaining.
  String _durationLabel({required bool countdown}) {
    final c = _controller;
    Duration d;
    if (c != null && _initialized) {
      d = countdown ? (c.value.duration - c.value.position) : c.value.duration;
    } else {
      d = Duration(milliseconds: widget.attachment.durationMs ?? 0);
    }
    if (d.isNegative) d = Duration.zero;
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final double smallSide =
        widget.diameter ?? math.min(216.0, media.size.width * 0.58);
    // Enlarged target: MUCH bigger, centered. min(width*0.82, height*0.55).
    final double largeSide = math.min(
      media.size.width * 0.82,
      media.size.height * 0.55,
    );

    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final double t = _t.value;
        final double side = _lerpD(smallSide, largeSide, t);

        // Sender-side padding relaxes toward symmetric as the note grows, so a
        // large square can occupy the full chat width and sit centered. We also
        // clamp the horizontal insets so `side` always fits.
        final double maxSide = math.max(
          0.0,
          media.size.width - 16, // 8px min gutter each side at full expand
        );
        final double clampedSide = math.min(side, maxSide);

        final double leftBase = widget.isMe ? 48 : 8;
        final double rightBase = widget.isMe ? 8 : 48;
        final double leftPad = _lerpD(leftBase, 8, t);
        final double rightPad = _lerpD(rightBase, 8, t);

        // Cross-axis alignment slides from the sender side toward center.
        final Alignment squareAlign = Alignment.lerp(
          widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
          Alignment.center,
          t,
        )!;

        final square = _buildSquare(clampedSide, t);

        return Padding(
          padding: EdgeInsets.fromLTRB(leftPad, 2, rightPad, 2),
          child: Column(
            crossAxisAlignment: widget.isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // Header / footer fade AND smoothly collapse their reserved
              // height as the note enlarges (a big centered square shouldn't
              // carry author/time chrome). Kept in the tree throughout so the
              // column never jumps when crossing a threshold.
              if (widget.header != null)
                _collapsible(child: widget.header!, t: t),
              // Full-width row so the growing square can center across the chat.
              SizedBox(
                width: double.infinity,
                child: Align(alignment: squareAlign, child: square),
              ),
              _collapsible(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: widget.footer,
                ),
                t: t,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Wraps header/footer chrome so it fades out AND collapses its reserved
  /// height as the note enlarges ([t] 0→1), and restores on collapse — without
  /// being added/removed from the tree (which would jolt the column layout).
  Widget _collapsible({required Widget child, required double t}) {
    final double f = (1 - t * 2).clamp(0.0, 1.0); // 1 at t=0, 0 by t=0.5
    if (f <= 0) {
      // Fully collapsed: keep a zero-size box in the tree to preserve identity.
      return const SizedBox.shrink();
    }
    if (f >= 1) {
      // Fully expanded (small in-list note) — the ONLY state where the footer's
      // reaction chips are visible and play their scale-up "pop" entry. That pop
      // overflows above the footer box on purpose, so we must NOT wrap it in a
      // ClipRect/heightFactor here (that clip is the "invisible wall" that cuts
      // the popping emoji in half). The height-collapse clip is only needed
      // while the note is actively enlarging (0 < f < 1).
      return child;
    }
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: f,
        child: Opacity(opacity: f, child: child),
      ),
    );
  }

  /// The rounded video square at the current animated [side]. [t] (0→1) drives
  /// chrome that only belongs to the enlarged state (slider, X, countdown).
  Widget _buildSquare(double side, double t) {
    final bool enlargedEnough = t > 0.02;
    final bool playing =
        _isReady && (_controller?.value.isPlaying ?? false);
    final bool showSmallPlayGlyph = _isReady && t < 0.5 && !playing;
    final bool showBigPlayGlyph = _isReady && t >= 0.5 && !playing;

    return SizedBox(
      key: _squareKey,
      width: side,
      height: side,
      child: GestureDetector(
        // Small note: tap to expand. Enlarged: tap toggles play/pause.
        onTap: _enlarged ? _togglePlayPause : _onTapSmall,
        // Drag-to-seek only meaningful while enlarged.
        onHorizontalDragStart: _enlarged
            ? (details) {
                setState(() {
                  _scrubbing = true;
                  _scrubFraction =
                      (details.localPosition.dx / side).clamp(0.0, 1.0);
                });
              }
            : null,
        onHorizontalDragUpdate: _enlarged
            ? (details) {
                if (!_scrubbing) return;
                setState(() {
                  _scrubFraction =
                      (details.localPosition.dx / side).clamp(0.0, 1.0);
                });
              }
            : null,
        onHorizontalDragEnd: _enlarged
            ? (_) {
                if (!_scrubbing) return;
                _seekToFraction(_scrubFraction);
                setState(() => _scrubbing = false);
              }
            : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: enlargedEnough
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.42 * t),
                      blurRadius: 38 * t,
                      spreadRadius: 2 * t,
                      offset: Offset(0, 16 * t),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Video texture / poster (or loading / failed placeholder).
                  Positioned.fill(
                    child: _isReady
                        ? FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: _controller!.value.size.width,
                              height: _controller!.value.size.height,
                              child: VideoPlayer(_controller!),
                            ),
                          )
                        : Center(
                            child: _failed
                                ? const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  )
                                : const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                  ),
                  // Small-state centered play affordance.
                  if (showSmallPlayGlyph)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Opacity(
                            opacity: (1 - t * 2).clamp(0.0, 1.0),
                            child: Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.34),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Enlarged-state center play glyph when paused.
                  if (showBigPlayGlyph)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Opacity(
                            opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.42),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Duration label (bottom-right). Small: total. Enlarged:
                  // counts down remaining.
                  Positioned(
                    right: _lerpD(8, 12, t),
                    bottom: _lerpD(10, 16, t),
                    child: IgnorePointer(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: _lerpD(8, 9, t),
                          vertical: _lerpD(3, 4, t),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(_lerpD(10, 11, t)),
                        ),
                        child: Text(
                          _durationLabel(countdown: t >= 0.5),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _lerpD(11, 12, t),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // White bottom-edge progress slider (enlarged only; drag is
                  // handled by the outer GestureDetector).
                  if (enlargedEnough)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: t,
                          child: ClipRRect(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(_radius),
                              bottomRight: Radius.circular(_radius),
                            ),
                            child: SizedBox(
                              height: 5,
                              child: Stack(
                                children: [
                                  Container(
                                    color: Colors.white.withValues(alpha: 0.28),
                                  ),
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: _progress.clamp(0.0, 1.0),
                                    child: Container(
                                      color:
                                          Colors.white.withValues(alpha: 0.95),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Faint close "X" top-right — collapses back down (enlarged).
                  if (enlargedEnough)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Opacity(
                        opacity: t,
                        child: GestureDetector(
                          onTap: _collapse,
                          child: Opacity(
                            opacity: 0.55,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Local double lerp (avoids importing dart:ui just for `lerpDouble`, which is
/// nullable). [a]+(b-a)*t.
double _lerpD(double a, double b, double t) => a + (b - a) * t;
