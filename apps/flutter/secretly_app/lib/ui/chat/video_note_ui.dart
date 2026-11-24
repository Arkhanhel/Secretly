// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Вид записи видео-заметки (макет «Video Notes», 3b, 21.11.2026).
///
/// * квадрат вырастает из кнопки и встаёт над чатом — чат виден сквозь
///   размытие (BackdropFilter 18 + тёмная вуаль 55 % вместо прежнего
///   чёрного 90 %), поле ввода остаётся в вырезе;
/// * прогресс — по контуру квадрата: полный обвод — минута, каждая часть
///   после паузы — свой отрезок, за 10 секунд до конца контур желтеет;
/// * квадрат наклоняется и краснеет вслед за пальцем, при отмене улетает;
/// * двойное касание по квадрату — смена камеры, и во время записи;
/// * два пальца по квадрату — приближение (в замке — и одним пальцем
///   вверх/вниз), значение — в капсуле сверху, гаснет через 0,9 с;
/// * просмотр: ролик по кругу, лента кадров с краями обрезки, «Переснять».
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../icons/adaptive_icons.dart';
import '../motion/motion.dart';
import '../widgets/island_backdrop.dart' show PanelPrefs;
import 'video_note_controller.dart';
import 'video_note_playback.dart' show VideoNotePlayback;
import 'voice_recorder_ui.dart'
    show
        RecordDot,
        RecordGlassCircle,
        RecordLockPill,
        RecordPopIn,
        RecordShimmer,
        RecordTrashButton,
        VoiceIcons,
        kVoiceRed;

const Color _kAccent = Color(0xFF7FD0FF);
const Color _kAccentDeep = Color(0xFF2E9FE4);
const Color _kWarn = Color(0xFFFFD24A);
const Color _kMuted = Color(0xFF8FA3B7);
const Color _kChip = Color(0xB3141C25);

/// Значки видео-заметки: на iPhone — Apple, на Android — Material.
abstract final class VideoNoteIcons {
  static const IconData camera = AdaptiveIconData(
    Icons.videocam_rounded,
    CupertinoIcons.videocam_fill,
  );
  static const IconData flip = AdaptiveIconData(
    Icons.cameraswitch_rounded,
    CupertinoIcons.camera_rotate_fill,
  );
  static const IconData bulbOn = AdaptiveIconData(
    Icons.lightbulb_rounded,
    CupertinoIcons.lightbulb_fill,
  );
  static const IconData bulbOff = AdaptiveIconData(
    Icons.lightbulb_outline_rounded,
    CupertinoIcons.lightbulb,
  );
  static const IconData torchOn = AdaptiveIconData(
    Icons.flash_on_rounded,
    CupertinoIcons.bolt_fill,
  );
  static const IconData torchOff = AdaptiveIconData(
    Icons.flash_off_rounded,
    CupertinoIcons.bolt_slash_fill,
  );
  static const IconData retake = AdaptiveIconData(
    Icons.replay_rounded,
    CupertinoIcons.arrow_counterclockwise,
  );
  static const IconData record = AdaptiveIconData(
    Icons.fiber_manual_record_rounded,
    CupertinoIcons.circle_fill,
  );
  static const IconData zoom = AdaptiveIconData(
    Icons.zoom_in_rounded,
    CupertinoIcons.zoom_in,
  );
}

/// Подписи на языке интерфейса.
class VideoNoteStrings {
  const VideoNoteStrings({
    required this.slideToCancel,
    required this.releaseToDelete,
    required this.pause,
    required this.resume,
    required this.stop,
    required this.delete,
    required this.retake,
    required this.looped,
    required this.flip,
    required this.light,
    required this.play,
    required this.trimStart,
    required this.trimEnd,
    required this.cameraUnavailable,
  });

  final String slideToCancel;
  final String releaseToDelete;
  final String pause;
  final String resume;
  final String stop;
  final String delete;
  final String retake;

  /// «зациклено» — в строке просмотра.
  final String looped;
  final String flip;
  final String light;
  final String play;
  final String trimStart;
  final String trimEnd;
  final String cameraUnavailable;
}

String _fmt(Duration d, {bool tenths = false}) {
  final total = d.inMilliseconds < 0 ? 0 : d.inMilliseconds;
  final m = total ~/ 60000;
  final s = (total ~/ 1000) % 60;
  final base = '$m:${s.toString().padLeft(2, '0')}';
  return tenths ? '$base,${(total ~/ 100) % 10}' : base;
}

bool _recordingPhase(VideoNotePhase p) =>
    p == VideoNotePhase.holding ||
    p == VideoNotePhase.locked ||
    p == VideoNotePhase.paused;

/// Раскладка экрана записи — одна на все фазы, чтобы ничего не прыгало.
@immutable
class VideoNoteLayout {
  const VideoNoteLayout({
    required this.pillTop,
    required this.square,
    required this.controlsTop,
  });

  /// Раскладка для экрана [screen] с безопасными полями [padding] и полем
  /// ввода [composer] (в координатах экрана).
  factory VideoNoteLayout.of({
    required Size screen,
    required EdgeInsets padding,
    required Rect? composer,
  }) {
    const pillH = 36.0;
    const controlsH = 96.0;
    final bottom = (composer?.top ?? screen.height - padding.bottom - 80) - 18;
    // 22.11.2026 (владелец): квадрат записи — почти во всю ширину экрана
    // (по 12 с краёв), сколько позволяет высота между таймером и кнопками.
    final maxEdge = math.max(180.0, screen.width - 24);
    // 23.11.2026: при открытой клавиатуре поле ввода высоко, места над ним
    // мало. Тогда раскладка сжимается: таймер ближе к краю, зазоры 8 вместо
    // 18, квадрат меньше (до 120) — ничего не заходит на поле и за экран.
    var gap = 18.0;
    var pillTop = padding.top + 46;
    var room = bottom - (pillTop + pillH + gap) - controlsH - gap;
    if (room < 220) {
      gap = 8;
      pillTop = padding.top + 10;
      room = bottom - (pillTop + pillH + gap) - controlsH - gap;
    }
    final top = pillTop + pillH + gap;
    final minEdge = math.min(120.0, maxEdge);
    final edge = math
        .min(maxEdge, room)
        .clamp(minEdge, maxEdge)
        .toDouble();
    final spare = math.max(0.0, room - edge);
    final squareTop = top + spare * 0.4;
    final left = (screen.width - edge) / 2;
    return VideoNoteLayout(
      pillTop: pillTop,
      square: Rect.fromLTWH(left, squareTop, edge, edge),
      controlsTop: squareTop + edge + gap,
    );
  }

  final double pillTop;
  final Rect square;
  final double controlsTop;
}

/// Слой записи поверх чата. Вставляется в Overlay, пока фаза не `idle`.
class VideoNoteOverlay extends StatefulWidget {
  const VideoNoteOverlay({
    super.key,
    required this.controller,
    required this.anchor,
    required this.composer,
    required this.strings,
    this.onClosed,
  });

  final VideoNoteController controller;

  /// Кнопка записи (центр большого квадрата-кнопки, капсулы замка).
  final Rect? Function() anchor;

  /// Поле ввода — вырез в размытии.
  final Rect? Function() composer;
  final VideoNoteStrings strings;

  /// Слой доиграл уход — можно убрать из Overlay.
  final VoidCallback? onClosed;

  @override
  State<VideoNoteOverlay> createState() => _VideoNoteOverlayState();
}

class _VideoNoteOverlayState extends State<VideoNoteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 240),
  );

  VideoNoteController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.phase.addListener(_onPhase);
    _onPhase();
  }

  void _onPhase() {
    final p = c.phase.value;
    if (p == VideoNotePhase.idle) {
      _appear.reverse().whenComplete(() {
        if (mounted && c.phase.value == VideoNotePhase.idle) {
          widget.onClosed?.call();
        }
      });
    } else if (p != VideoNotePhase.cancelling) {
      _appear.forward();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.phase.removeListener(_onPhase);
    _appear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final composer = widget.composer();
    final anchor = widget.anchor();
    final layout = VideoNoteLayout.of(
      screen: screen,
      padding: padding,
      composer: composer,
    );
    final phase = c.phase.value;
    final appear = CurvedAnimation(
      parent: _appear,
      curve: const Cubic(0.2, 0.9, 0.25, 1.08),
      reverseCurve: Curves.easeInCubic,
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Размытие с вырезом под поле ввода.
          Positioned.fill(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _appear, curve: Curves.easeOut),
              child: _Backdrop(controller: c, hole: composer),
            ),
          ),
          Positioned(
            top: layout.pillTop,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _appear,
              child: Center(child: _TimerPill(controller: c)),
            ),
          ),
          Positioned.fromRect(
            rect: layout.square,
            child: _GrowFromButton(
              animation: appear,
              from: anchor?.center,
              square: layout.square,
              child: _PosedSquare(
                controller: c,
                child: _Square(
                  controller: c,
                  edge: layout.square.width,
                  strings: widget.strings,
                ),
              ),
            ),
          ),
          Positioned(
            top: layout.controlsTop,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _appear,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                  child: phase == VideoNotePhase.preview
                      ? _PreviewControls(
                          key: const ValueKey('preview'),
                          controller: c,
                          width: layout.square.width - 12,
                          strings: widget.strings,
                        )
                      : _recordingPhase(phase)
                      ? _CameraControls(
                          key: const ValueKey('camera'),
                          controller: c,
                          strings: widget.strings,
                        )
                      : const SizedBox(key: ValueKey('none'), height: 48),
                ),
              ),
            ),
          ),
          if (anchor != null)
            _ButtonLayer(
              controller: c,
              anchor: anchor,
              strings: widget.strings,
            ),
        ],
      ),
    );
  }
}

/// Размытый чат за квадратом. Подсветка фронтальной камеры — белый экран.
///
/// Пока запись открыта, кружки в ленте стоят; без «Размытия панелей» —
/// затемнение вместо размытия (разбор 22.11.2026).
class _Backdrop extends StatefulWidget {
  const _Backdrop({required this.controller, required this.hole});
  final VideoNoteController controller;
  final Rect? hole;

  @override
  State<_Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<_Backdrop> {
  late final VoidCallback _resumeFeed;

  @override
  void initState() {
    super.initState();
    _resumeFeed = VideoNotePlayback.instance.suspendFeed();
  }

  @override
  void dispose() {
    _resumeFeed();
    super.dispose();
  }

  VideoNoteController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final frosted = PanelPrefs.frostedEnabled.value;
    final dim = AnimatedBuilder(
          animation: Listenable.merge([
            controller.light,
            controller.front,
            controller.phase,
          ]),
          builder: (context, _) {
            final lit =
                controller.light.value &&
                controller.front.value &&
                _recordingPhase(controller.phase.value);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              color: lit
                  ? const Color(0xF5FFFFFF)
                  : (frosted
                        ? const Color(0x8C080C11)
                        : const Color(0xC7080C11)),
            );
          },
        );
    return ClipPath(
      clipper: _HoleClipper(widget.hole),
      // Без «Размытия панелей» — только затемнение (плотнее), без прохода
      // размытия на каждый кадр записи.
      child: frosted
          ? BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: dim,
            )
          : dim,
    );
  }
}

class _HoleClipper extends CustomClipper<Path> {
  _HoleClipper(this.hole);
  final Rect? hole;

  @override
  Path getClip(Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final h = hole;
    if (h == null) return all;
    // Вырез доходит до низа экрана — вся полоса поля ввода (вместе с местом
    // под ним) остаётся как обычно: капли стеклом поверх чата, а не на
    // тёмной плашке (жалоба 22.11.2026). Скруглены только верхние углы.
    if (h.bottom >= size.height - 0.5) {
      const r = Radius.circular(24);
      return Path.combine(
        PathOperation.difference,
        all,
        Path()..addRRect(RRect.fromRectAndCorners(h, topLeft: r, topRight: r)),
      );
    }
    final r = math.min(h.height / 2, 28.0);
    return Path.combine(
      PathOperation.difference,
      all,
      Path()..addRRect(RRect.fromRectAndRadius(h, Radius.circular(r))),
    );
  }

  @override
  bool shouldReclip(_HoleClipper old) => old.hole != hole;
}

/// Таймер над квадратом: красная точка (идёт), пауза, просмотр; «/ 1:00»
/// желтеет в последние 10 секунд.
class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.controller});
  final VideoNoteController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AnimatedBuilder(
      animation: Listenable.merge([
        c.phase,
        c.elapsed,
        c.nearLimit,
        c.previewPosition,
        c.trim,
      ]),
      builder: (context, _) {
        final p = c.phase.value;
        final preview = p == VideoNotePhase.preview;
        final paused = p == VideoNotePhase.paused;
        final String time;
        final String limit;
        if (preview) {
          final t = c.trim.value;
          time = _fmt(c.previewPosition.value - t.start);
          limit = '/ ${_fmt(t.length)}';
        } else {
          time = _fmt(c.elapsed.value, tenths: true);
          limit = '/ ${_fmt(c.maxDuration)}';
        }
        final warn = c.nearLimit.value && !preview;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: _kChip,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: preview || paused
                          ? Icon(
                              paused ? VoiceIcons.pause : VoiceIcons.play,
                              key: ValueKey(paused),
                              size: 15,
                              color: _kWarn,
                            )
                          : const RecordDot(key: ValueKey('dot'), size: 9),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                // Цвет плавно — стиль наследует шрифт приложения.
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: warn ? _kWarn : _kMuted),
                  duration: const Duration(milliseconds: 250),
                  builder: (context, color, _) => Text(
                    limit,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: warn ? FontWeight.w600 : FontWeight.w400,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Квадрат вырастает из кнопки и уходит в неё.
class _GrowFromButton extends StatelessWidget {
  const _GrowFromButton({
    required this.animation,
    required this.from,
    required this.square,
    required this.child,
  });

  final Animation<double> animation;
  final Offset? from;
  final Rect square;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        final origin = from ?? square.bottomRight;
        final shift = (origin - square.center) * (1 - t);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: shift,
            child: Transform.scale(scale: 0.12 + 0.88 * t, child: child),
          ),
        );
      },
    );
  }
}

/// Поза квадрата за пальцем: влево — едет, наклоняется и сжимается; вверх —
/// чуть поднимается; при отмене — улетает вниз-влево.
@immutable
class _Pose {
  const _Pose(this.dx, this.dy, this.turns, this.scale, this.opacity);
  static const rest = _Pose(0, 0, 0, 1, 1);
  final double dx;
  final double dy;
  final double turns;
  final double scale;
  final double opacity;

  _Pose lerp(_Pose b, double t) => _Pose(
    ui.lerpDouble(dx, b.dx, t)!,
    ui.lerpDouble(dy, b.dy, t)!,
    ui.lerpDouble(turns, b.turns, t)!,
    ui.lerpDouble(scale, b.scale, t)!,
    ui.lerpDouble(opacity, b.opacity, t)!,
  );
}

class _PoseTween extends Tween<_Pose> {
  _PoseTween({super.begin, super.end});
  @override
  _Pose lerp(double t) => begin!.lerp(end!, t);
}

class _PosedSquare extends StatelessWidget {
  const _PosedSquare({required this.controller, required this.child});
  final VideoNoteController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AnimatedBuilder(
      animation: Listenable.merge([c.drag, c.phase]),
      child: child,
      builder: (context, child) {
        final p = c.phase.value;
        final d = c.drag.value;
        final vertical = d.dy.abs() > d.dx.abs();
        final cp = c.cancelProgress;
        final _Pose target;
        final bool following;
        if (p == VideoNotePhase.cancelling) {
          target = const _Pose(-160, 120, -14 / 360, 0.4, 0);
          following = false;
        } else if (p == VideoNotePhase.holding && !vertical && d.dx < 0) {
          target = _Pose(d.dx * 0.45, 0, d.dx * 0.05 / 360, 1 - cp * 0.12, 1);
          following = true;
        } else if (p == VideoNotePhase.holding && vertical) {
          target = _Pose(0, d.dy * 0.12, 0, 1, 1);
          following = true;
        } else {
          target = _Pose.rest;
          following = false;
        }
        return TweenAnimationBuilder<_Pose>(
          tween: _PoseTween(begin: _Pose.rest, end: target),
          duration: following
              ? const Duration(milliseconds: 80)
              : const Duration(milliseconds: 420),
          curve: following
              ? Curves.linear
              : (p == VideoNotePhase.cancelling
                    ? Curves.easeInCubic
                    : const Cubic(0.2, 0.9, 0.25, 1.08)),
          child: child,
          builder: (context, pose, child) => Opacity(
            opacity: pose.opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(pose.dx, pose.dy),
              child: Transform.rotate(
                angle: pose.turns * 2 * math.pi,
                child: Transform.scale(scale: pose.scale, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Квадрат: контур-прогресс и кадр (камера или просмотр).
class _Square extends StatelessWidget {
  const _Square({
    required this.controller,
    required this.edge,
    required this.strings,
  });

  final VideoNoteController controller;
  final double edge;
  final VideoNoteStrings strings;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final k = edge / 312;
    final inset = 12 * k;
    final innerRadius = 50 * k;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([c.ranges, c.nearLimit, c.phase]),
            builder: (context, _) => CustomPaint(
              painter: VideoNoteRingPainter(
                ranges: c.ranges.value,
                maxSeconds: c.maxDuration.inMicroseconds / 1e6,
                color: c.nearLimit.value ? _kWarn : _kAccent,
                radius: 59 * k,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(inset),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(innerRadius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x73000000),
                  blurRadius: 60,
                  offset: Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(innerRadius),
              child: _SquareContent(controller: c, strings: strings),
            ),
          ),
        ),
        Positioned(
          top: inset + 12 * k,
          left: 0,
          right: 0,
          child: Center(child: VideoNoteZoomPill(controller: c)),
        ),
      ],
    );
  }
}

class _SquareContent extends StatelessWidget {
  const _SquareContent({required this.controller, required this.strings});
  final VideoNoteController controller;
  final VideoNoteStrings strings;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ValueListenableBuilder<VideoNotePhase>(
      valueListenable: c.phase,
      builder: (context, phase, _) {
        final preview = phase == VideoNotePhase.preview;
        final frame = preview
            ? ValueListenableBuilder<Widget?>(
                valueListenable: c.previewView,
                builder: (context, view, _) => _switch(view),
              )
            : ValueListenableBuilder<Widget?>(
                valueListenable: c.cameraView,
                builder: (context, view, _) => _switch(view),
              );
        return _SquareGestures(
          controller: c,
          phase: phase,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF161D26)),
              frame,
              // Пауза записи.
              _Veil(
                visible: phase == VideoNotePhase.paused,
                color: const Color(0x730A0E13),
                icon: VoiceIcons.pause,
                size: 44,
              ),
              // Просмотр на паузе.
              ValueListenableBuilder<bool>(
                valueListenable: c.previewPlaying,
                builder: (context, playing, _) => _Veil(
                  visible: preview && !playing,
                  color: const Color(0x590A0E13),
                  icon: VoiceIcons.play,
                  size: 48,
                ),
              ),
              // Отмена взведена.
              ValueListenableBuilder<bool>(
                valueListenable: c.cancelArmed,
                builder: (context, armed, _) => _Veil(
                  visible: armed || phase == VideoNotePhase.cancelling,
                  color: const Color(0x80E5484D),
                  icon: VoiceIcons.trash,
                  size: 52,
                  pop: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _switch(Widget? view) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 240),
    child:
        view ??
        const Center(
          key: ValueKey('wait'),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Color(0x99FFFFFF),
            ),
          ),
        ),
  );
}

/// Касания по квадрату: двойное — смена камеры (в просмотре одиночное —
/// пауза), два пальца — приближение, в замке — и один палец вверх/вниз.
/// Щипок — не касание: распознаватель масштаба побеждает касания, только
/// когда пальцы сдвинулись.
class _SquareGestures extends StatefulWidget {
  const _SquareGestures({
    required this.controller,
    required this.phase,
    required this.child,
  });

  final VideoNoteController controller;
  final VideoNotePhase phase;
  final Widget child;

  @override
  State<_SquareGestures> createState() => _SquareGesturesState();
}

class _SquareGesturesState extends State<_SquareGestures> {
  int _pointers = 0;
  Offset _focal = Offset.zero;
  double _scale = 1;

  VideoNoteController get c => widget.controller;

  void _start(int pointers, Offset focal, double scale) {
    _pointers = pointers;
    _focal = focal;
    _scale = scale <= 0 ? 1 : scale;
    c.zoomGestureStart();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.phase;
    final recording = _recordingPhase(phase);
    final preview = phase == VideoNotePhase.preview;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: recording ? c.flip : null,
      onTap: preview ? c.togglePreviewPlay : null,
      onScaleStart: recording
          ? (d) => _start(d.pointerCount, d.localFocalPoint, 1)
          : null,
      onScaleUpdate: recording
          ? (d) {
              if (d.pointerCount != _pointers) {
                // Палец добавили или убрали — новая точка отсчёта.
                _start(d.pointerCount, d.localFocalPoint, d.scale);
                return;
              }
              if (d.pointerCount >= 2) {
                c.zoomPinch(d.scale / _scale);
              } else {
                c.zoomDrag(d.localFocalPoint.dy - _focal.dy);
              }
            }
          : null,
      onScaleEnd: recording ? (_) => c.zoomGestureEnd() : null,
      child: widget.child,
    );
  }
}

/// Приближение для подписи: `1,8×` (в английском — `1.8×`).
String videoNoteZoomLabel(double zoom, Locale? locale) {
  final text = zoom.toStringAsFixed(1);
  final comma = locale != null && locale.languageCode != 'en';
  return '${comma ? text.replaceAll('.', ',') : text}×';
}

/// Капсула приближения над кадром: видна, пока приближение меняется, гаснет
/// через [VideoNoteZoomPill.hideAfter]. Перестраивается только она.
class VideoNoteZoomPill extends StatefulWidget {
  const VideoNoteZoomPill({super.key, required this.controller});

  final VideoNoteController controller;

  static const Duration hideAfter = Duration(milliseconds: 900);

  @override
  State<VideoNoteZoomPill> createState() => _VideoNoteZoomPillState();
}

class _VideoNoteZoomPillState extends State<VideoNoteZoomPill> {
  bool _visible = false;
  Timer? _hide;

  VideoNoteController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.zoom.addListener(_onZoom);
  }

  @override
  void didUpdateWidget(VideoNoteZoomPill old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.zoom.removeListener(_onZoom);
      widget.controller.zoom.addListener(_onZoom);
    }
  }

  void _onZoom() {
    if (!mounted) return;
    final live = _recordingPhase(c.phase.value);
    _hide?.cancel();
    if (live) {
      _hide = Timer(VideoNoteZoomPill.hideAfter, () {
        if (mounted) setState(() => _visible = false);
      });
    }
    setState(() => _visible = live);
  }

  @override
  void dispose() {
    _hide?.cancel();
    c.zoom.removeListener(_onZoom);
    super.dispose();
  }

  void _step(double by) {
    c.zoomGestureStart();
    c.zoomPinch(by);
    c.zoomGestureEnd();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final label = AppLocalizations.of(context)?.vnZoom ?? 'Zoom';
    return ValueListenableBuilder<bool>(
      valueListenable: c.zoomEnabled,
      builder: (context, enabled, _) => ValueListenableBuilder<double>(
        valueListenable: c.zoom,
        builder: (context, z, _) {
          final text = videoNoteZoomLabel(z, locale);
          final canIn = enabled && z < c.maxZoom - 0.001;
          final canOut = enabled && z > c.minZoom + 0.001;
          return ExcludeSemantics(
            excluding: !enabled,
            child: Semantics(
              container: true,
              label: label,
              value: text,
              increasedValue: canIn
                  ? videoNoteZoomLabel(math.min(c.maxZoom, z * 1.5), locale)
                  : null,
              decreasedValue: canOut
                  ? videoNoteZoomLabel(math.max(c.minZoom, z / 1.5), locale)
                  : null,
              onIncrease: canIn ? () => _step(1.5) : null,
              onDecrease: canOut ? () => _step(1 / 1.5) : null,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: _visible ? 120 : 260),
                  curve: Curves.easeOut,
                  opacity: _visible ? 1 : 0,
                  alwaysIncludeSemantics: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x990A0E13),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            VideoNoteIcons.zoom,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Veil extends StatelessWidget {
  const _Veil({
    required this.visible,
    required this.color,
    required this.icon,
    required this.size,
    this.pop = false,
  });

  final bool visible;
  final Color color;
  final IconData icon;
  final double size;
  final bool pop;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: ColoredBox(
          color: color,
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 300),
              curve: pop ? Motion.popElastic : Curves.easeOut,
              scale: visible ? 1 : 0.6,
              child: Icon(icon, size: size, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Контур-прогресс: дорожка и отрезки (по одному на часть между паузами).
/// Полный обвод — [maxSeconds]. Начало — сверху посередине, по часовой.
class VideoNoteRingPainter extends CustomPainter {
  VideoNoteRingPainter({
    required this.ranges,
    required this.maxSeconds,
    required this.color,
    required this.radius,
  });

  final List<VideoNoteRange> ranges;
  final double maxSeconds;
  final Color color;
  final double radius;

  static const double stroke = 4;

  /// Зазор между отрезками — доля обвода.
  static const double gap = 0.008;

  static Path perimeter(Size size, double radius) {
    const h = stroke / 2 + 1;
    final r = Rect.fromLTWH(h, h, size.width - 2 * h, size.height - 2 * h);
    final rr = math.min(radius, r.shortestSide / 2);
    final cx = r.center.dx;
    return Path()
      ..moveTo(cx, r.top)
      ..lineTo(r.right - rr, r.top)
      ..arcToPoint(Offset(r.right, r.top + rr), radius: Radius.circular(rr))
      ..lineTo(r.right, r.bottom - rr)
      ..arcToPoint(Offset(r.right - rr, r.bottom), radius: Radius.circular(rr))
      ..lineTo(r.left + rr, r.bottom)
      ..arcToPoint(Offset(r.left, r.bottom - rr), radius: Radius.circular(rr))
      ..lineTo(r.left, r.top + rr)
      ..arcToPoint(Offset(r.left + rr, r.top), radius: Radius.circular(rr))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = perimeter(size, radius);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0x24FFFFFF),
    );
    if (ranges.isEmpty || maxSeconds <= 0) return;
    final metric = path.computeMetrics().first;
    final len = metric.length;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (var i = 0; i < ranges.length; i++) {
      final g = ranges[i];
      final a = (g.from / maxSeconds).clamp(0.0, 1.0);
      var b = (g.to / maxSeconds).clamp(0.0, 1.0);
      if (i < ranges.length - 1) b = math.max(a, b - gap);
      if (b - a < 0.0005) continue;
      canvas.drawPath(metric.extractPath(a * len, b * len), paint);
    }
  }

  @override
  bool shouldRepaint(VideoNoteRingPainter old) =>
      old.ranges != ranges || old.color != color || old.radius != radius;
}

/// Под квадратом во время записи: смена камеры и подсветка.
class _CameraControls extends StatelessWidget {
  const _CameraControls({
    super.key,
    required this.controller,
    required this.strings,
  });
  final VideoNoteController controller;
  final VideoNoteStrings strings;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AnimatedBuilder(
      animation: Listenable.merge([c.front, c.light, c.flipping]),
      builder: (context, _) {
        final front = c.front.value;
        final lit = c.light.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoundButton(
              label: strings.flip,
              icon: VideoNoteIcons.flip,
              onTap: c.canFlip && !c.flipping.value ? c.flip : null,
            ),
            const SizedBox(width: 16),
            _RoundButton(
              label: strings.light,
              icon: front
                  ? (lit ? VideoNoteIcons.bulbOn : VideoNoteIcons.bulbOff)
                  : (lit ? VideoNoteIcons.torchOn : VideoNoteIcons.torchOff),
              active: lit,
              onTap: c.toggleLight,
            ),
          ],
        );
      },
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      toggled: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: onTap == null ? 0.45 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? _kWarn : _kChip,
              border: Border.all(
                color: Colors.white.withValues(alpha: active ? 0 : 0.12),
              ),
            ),
            child: Icon(
              icon,
              size: 23,
              color: active ? const Color(0xFF1B1405) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Под квадратом в просмотре: лента кадров с краями обрезки и «Переснять».
class _PreviewControls extends StatelessWidget {
  const _PreviewControls({
    super.key,
    required this.controller,
    required this.width,
    required this.strings,
  });

  final VideoNoteController controller;
  final double width;
  final VideoNoteStrings strings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoNoteTrimStrip(controller: controller, strings: strings),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: strings.retake,
            child: GestureDetector(
              onTap: controller.retake,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _kChip,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        VideoNoteIcons.retake,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        strings.retake,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Лента кадров: края — ручки обрезки, белая черта — где сейчас ролик.
class VideoNoteTrimStrip extends StatefulWidget {
  const VideoNoteTrimStrip({
    super.key,
    required this.controller,
    required this.strings,
  });

  final VideoNoteController controller;
  final VideoNoteStrings strings;

  @override
  State<VideoNoteTrimStrip> createState() => _VideoNoteTrimStripState();
}

class _VideoNoteTrimStripState extends State<VideoNoteTrimStrip> {
  static const double _h = 48;
  static const double _handle = 12;
  bool? _draggingStart;

  VideoNoteController get c => widget.controller;

  double _frac(Duration d) {
    final all = c.total.value.inMicroseconds;
    return all <= 0 ? 0 : (d.inMicroseconds / all).clamp(0.0, 1.0).toDouble();
  }

  void _drag(double x, double width, bool start) {
    final f = (x / width).clamp(0.0, 1.0).toDouble();
    if (start) {
      c.setTrim(startFraction: f);
    } else {
      c.setTrim(endFraction: f);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return AnimatedBuilder(
          animation: Listenable.merge([
            c.trim,
            c.previewPosition,
            c.frames,
            c.total,
          ]),
          builder: (context, _) {
            final t = c.trim.value;
            final a = _frac(t.start);
            final b = _frac(t.end);
            final pos = _frac(c.previewPosition.value);
            final left = a * w;
            final right = b * w;
            final frames = c.frames.value;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) {
                final x = d.localPosition.dx;
                // Ближайший край берёт палец.
                _draggingStart = (x - left).abs() <= (x - right).abs();
              },
              onHorizontalDragUpdate: (d) {
                final s = _draggingStart;
                if (s != null) _drag(d.localPosition.dx, w, s);
              },
              onHorizontalDragEnd: (_) {
                _draggingStart = null;
                c.trimSettled();
              },
              child: SizedBox(
                height: _h,
                width: w,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ColoredBox(
                          color: const Color(0xFF0F151C),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < math.max(1, frames.length); i++)
                                Expanded(
                                  child: _Frame(
                                    path: i < frames.length ? frames[i] : null,
                                    index: i,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Вне обрезки — притушено.
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: left,
                      child: const _Dim(left: true),
                    ),
                    Positioned(
                      left: right,
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: const _Dim(left: false),
                    ),
                    // Рамка обрезки с ручками.
                    Positioned(
                      left: left,
                      width: math.max(right - left, _handle * 2),
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: const Border(
                              top: BorderSide(color: _kAccent, width: 3),
                              bottom: BorderSide(color: _kAccent, width: 3),
                              left: BorderSide(color: _kAccent, width: _handle),
                              right: BorderSide(color: _kAccent, width: _handle),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [_Grip(), _Grip()],
                          ),
                        ),
                      ),
                    ),
                    // Где сейчас ролик.
                    if (pos >= a && pos <= b)
                      Positioned(
                        left: (pos * w - 1.5).clamp(
                          left + _handle,
                          math.max(left + _handle, right - _handle - 3),
                        ),
                        top: 4,
                        bottom: 4,
                        width: 3,
                        child: const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.all(
                                Radius.circular(2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x80000000),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Ручки для чтения с экрана.
                    Positioned(
                      left: left - 8,
                      width: 28,
                      top: 0,
                      bottom: 0,
                      child: Semantics(
                        label: widget.strings.trimStart,
                        value: _fmt(t.start),
                        increasedValue: _fmt(t.start + const Duration(seconds: 1)),
                        decreasedValue: _fmt(t.start - const Duration(seconds: 1)),
                        onIncrease: () => c.setTrim(
                          startFraction: _frac(t.start + const Duration(seconds: 1)),
                        ),
                        onDecrease: () => c.setTrim(
                          startFraction: _frac(t.start - const Duration(seconds: 1)),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Positioned(
                      left: right - 20,
                      width: 28,
                      top: 0,
                      bottom: 0,
                      child: Semantics(
                        label: widget.strings.trimEnd,
                        value: _fmt(t.end),
                        increasedValue: _fmt(t.end + const Duration(seconds: 1)),
                        decreasedValue: _fmt(t.end - const Duration(seconds: 1)),
                        onIncrease: () => c.setTrim(
                          endFraction: _frac(t.end + const Duration(seconds: 1)),
                        ),
                        onDecrease: () => c.setTrim(
                          endFraction: _frac(t.end - const Duration(seconds: 1)),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.path, required this.index});
  final String? path;
  final int index;

  static const _placeholders = [
    Color(0xFF2B3A4A),
    Color(0xFF30485C),
    Color(0xFF36506A),
    Color(0xFF2E4459),
    Color(0xFF3A5670),
    Color(0xFF33495F),
    Color(0xFF2C4053),
    Color(0xFF38526B),
  ];

  @override
  Widget build(BuildContext context) {
    final p = path;
    final base = ColoredBox(color: _placeholders[index % _placeholders.length]);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0x59000000))),
      ),
      child: p == null
          ? base
          : Image.file(
              File(p),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: frame == null && !sync ? 0 : 1,
                child: child,
              ),
              errorBuilder: (context, _, __) => base,
            ),
    );
  }
}

class _Dim extends StatelessWidget {
  const _Dim({required this.left});
  final bool left;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x8C05080B),
        borderRadius: left
            ? const BorderRadius.horizontal(left: Radius.circular(14))
            : const BorderRadius.horizontal(right: Radius.circular(14)),
      ),
    ),
  );
}

/// Черта-хват на толстом крае рамки обрезки.
class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) => Container(
    width: 2.5,
    height: 16,
    decoration: BoxDecoration(
      color: const Color(0xFF0F2A3D).withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

/// Кнопка под пальцем, капсула замка, «Стоп».
class _ButtonLayer extends StatelessWidget {
  const _ButtonLayer({
    required this.controller,
    required this.anchor,
    required this.strings,
  });

  final VideoNoteController controller;
  final Rect anchor;
  final VideoNoteStrings strings;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final center = anchor.center;
    return ValueListenableBuilder<VideoNotePhase>(
      valueListenable: c.phase,
      builder: (context, phase, _) {
        final holding = phase == VideoNotePhase.holding;
        final stoppable =
            phase == VideoNotePhase.locked || phase == VideoNotePhase.paused;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (holding)
              AnimatedBuilder(
                animation: Listenable.merge([c.drag, c.cancelArmed]),
                builder: (context, _) {
                  final lp = c.lockProgress;
                  final h = 92 - 44 * lp;
                  return Positioned(
                    left: center.dx - 22,
                    top: center.dy - 58 - h - lp * 18,
                    width: 44,
                    height: h,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: c.cancelArmed.value ? 0 : 1,
                        child: RecordLockPill(progress: lp, accent: _kAccent),
                      ),
                    ),
                  );
                },
              ),
            if (stoppable)
              Positioned(
                left: center.dx - 22,
                top: center.dy - 58 - 44,
                width: 44,
                height: 44,
                child: RecordPopIn(
                  child: Semantics(
                    button: true,
                    label: strings.stop,
                    child: GestureDetector(
                      onTap: c.stopToPreview,
                      child: const RecordGlassCircle(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: kVoiceRed,
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (holding)
              Positioned.fill(
                child: IgnorePointer(
                  child: _BigButton(controller: c, center: center),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Под пальцем — скруглённый квадрат 84 с камерой; влево — краснеет и
/// становится корзиной.
class _BigButton extends StatelessWidget {
  const _BigButton({required this.controller, required this.center});
  final VideoNoteController controller;
  final Offset center;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.55, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: const Cubic(0.2, 0.9, 0.3, 1.2),
      builder: (context, grow, _) => AnimatedBuilder(
        animation: Listenable.merge([c.drag, c.cancelArmed]),
        builder: (context, _) {
          final d = c.drag.value;
          final armed = c.cancelArmed.value;
          final vertical = d.dy.abs() > d.dx.abs();
          final ox = vertical ? d.dx * 0.25 : math.max(d.dx, -170.0);
          final oy = vertical
              ? math.max(d.dy, -c.lockDistance) * 0.9
              : d.dy * 0.25;
          final p = center + Offset(ox - 10, oy - 10);
          const size = 84.0;
          final top = armed ? const Color(0xFFFF7A7E) : _kAccent;
          final bottom = armed ? const Color(0xFFE0404A) : _kAccentDeep;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: p.dx - size / 2,
                top: p.dy - size / 2,
                width: size,
                height: size,
                child: Transform.scale(
                  scale: grow,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [top, bottom],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: bottom.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (c, a) => ScaleTransition(
                          scale: CurvedAnimation(
                            parent: a,
                            curve: Motion.popElastic,
                          ),
                          child: c,
                        ),
                        child: Icon(
                          armed ? VoiceIcons.trash : VideoNoteIcons.camera,
                          key: ValueKey(armed),
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Поле ввода во время записи: «‹ Влево — отмена» / «Отпустите — удалить»;
/// в замке — корзина и «Пауза»/«Продолжить»; в просмотре — корзина и
/// «0:18 · зациклено».
class VideoNoteComposerPanel extends StatelessWidget {
  const VideoNoteComposerPanel({
    super.key,
    required this.controller,
    required this.strings,
  });

  final VideoNoteController controller;
  final VideoNoteStrings strings;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ValueListenableBuilder<VideoNotePhase>(
      valueListenable: c.phase,
      builder: (context, phase, _) {
        final Widget child;
        switch (phase) {
          case VideoNotePhase.locked:
          case VideoNotePhase.paused:
            child = _LockedBar(
              key: const ValueKey('locked'),
              controller: c,
              strings: strings,
            );
          case VideoNotePhase.preview:
            child = _PreviewBar(
              key: const ValueKey('preview'),
              controller: c,
              strings: strings,
            );
          default:
            child = _HoldingBar(
              key: const ValueKey('holding'),
              controller: c,
              strings: strings,
            );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: child,
        );
      },
    );
  }
}

class _HoldingBar extends StatelessWidget {
  const _HoldingBar({
    super.key,
    required this.controller,
    required this.strings,
  });
  final VideoNoteController controller;
  final VideoNoteStrings strings;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AnimatedBuilder(
      animation: Listenable.merge([c.drag, c.cancelArmed, c.phase]),
      builder: (context, _) {
        final d = c.drag.value;
        final armed =
            c.cancelArmed.value || c.phase.value == VideoNotePhase.cancelling;
        final vertical = d.dy.abs() > d.dx.abs();
        final x = vertical || armed ? 0.0 : math.max(d.dx * 0.8, -36.0);
        return Center(
          child: Transform.translate(
            offset: Offset(x, 0),
            child: Opacity(
              opacity: 1 - c.cancelProgress * 0.5,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: armed
                    ? Text(
                        strings.releaseToDelete,
                        key: const ValueKey('armed'),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: const TextStyle(
                          color: kVoiceRed,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : RecordShimmer(
                        key: const ValueKey('slide'),
                        color: _kMuted,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(VoiceIcons.left, size: 20),
                            Flexible(
                              child: Text(
                                strings.slideToCancel,
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: const TextStyle(fontSize: 14.5),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LockedBar extends StatelessWidget {
  const _LockedBar({
    super.key,
    required this.controller,
    required this.strings,
  });
  final VideoNoteController controller;
  final VideoNoteStrings strings;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        RecordTrashButton(onTap: c.cancel, label: strings.delete),
        const SizedBox(width: 8),
        Expanded(
          child: ValueListenableBuilder<VideoNotePhase>(
            valueListenable: c.phase,
            builder: (context, phase, _) {
              final paused = phase == VideoNotePhase.paused;
              return Semantics(
                button: true,
                label: paused ? strings.resume : strings.pause,
                child: GestureDetector(
                  onTap: c.togglePause,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, a) =>
                              ScaleTransition(scale: a, child: child),
                          child: Icon(
                            paused ? VideoNoteIcons.record : VoiceIcons.pause,
                            key: ValueKey(paused),
                            size: paused ? 16 : 20,
                            color: paused ? kVoiceRed : onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            paused ? strings.resume : strings.pause,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({
    super.key,
    required this.controller,
    required this.strings,
  });
  final VideoNoteController controller;
  final VideoNoteStrings strings;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final ink = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.82);
    return Row(
      children: [
        RecordTrashButton(onTap: c.cancel, label: strings.delete),
        const SizedBox(width: 8),
        Expanded(
          child: ValueListenableBuilder<VideoNoteTrim>(
            valueListenable: c.trim,
            builder: (context, t, _) => Text(
              '${_fmt(t.length)} · ${strings.looped}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ink,
                fontSize: 14,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
