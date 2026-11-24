// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Вид записи голосового (макет «Voice Recording», 1b).
///
/// * [VoiceRecordGestureArea] — ОДИН слушатель касаний на весь жест. Раньше
///   кнопка-микрофон подменялась другим виджетом прямо под пальцем, и вместе
///   с ней пропадал слушатель: отмена и отправка срабатывали через раз.
/// * [VoiceRecorderPanel] — содержимое поля ввода во время записи: удержание,
///   закреплено, прослушивание, «удалено».
/// * [VoiceRecorderOverlay] — над чатом: большой круг под пальцем (дышит в
///   такт голосу), капсула замка, «Стоп». Над чатом, а не внутри поля ввода —
///   иначе стеклянная панель его подрезала, а касания не доходили.
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../icons/adaptive_icons.dart';
import '../motion/motion.dart';
import 'voice_recorder_controller.dart';

const Color kVoiceRed = Color(0xFFFF5A5F);

/// Значки записи: на iPhone — системные Apple, на Android — Material.
abstract final class VoiceIcons {
  static const IconData mic = AdaptiveIconData(
    Icons.mic_rounded,
    CupertinoIcons.mic_fill,
  );
  static const IconData trash = AdaptiveIconData(
    Icons.delete_rounded,
    CupertinoIcons.trash_fill,
  );
  static const IconData trashOutline = AdaptiveIconData(
    Icons.delete_outline_rounded,
    CupertinoIcons.trash,
  );
  static const IconData lockOpen = AdaptiveIconData(
    Icons.lock_open_rounded,
    CupertinoIcons.lock_open_fill,
  );
  static const IconData lock = AdaptiveIconData(
    Icons.lock_rounded,
    CupertinoIcons.lock_fill,
  );
  static const IconData up = AdaptiveIconData(
    Icons.keyboard_arrow_up_rounded,
    CupertinoIcons.chevron_up,
  );
  static const IconData left = AdaptiveIconData(
    Icons.chevron_left_rounded,
    CupertinoIcons.chevron_left,
  );
  static const IconData play = AdaptiveIconData(
    Icons.play_arrow_rounded,
    CupertinoIcons.play_fill,
  );
  static const IconData pause = AdaptiveIconData(
    Icons.pause_rounded,
    CupertinoIcons.pause_fill,
  );
}

/// Подписи записи на языке интерфейса.
class VoiceRecorderStrings {
  const VoiceRecorderStrings({
    required this.slideToCancel,
    required this.releaseToDelete,
    required this.deleted,
    required this.stop,
    required this.delete,
    required this.play,
    required this.pause,
  });

  final String slideToCancel;
  final String releaseToDelete;
  final String deleted;
  final String stop;
  final String delete;
  final String play;
  final String pause;
}

String _fmt(Duration d, {bool tenths = false}) {
  final total = d.inMilliseconds;
  final m = total ~/ 60000;
  final s = (total ~/ 1000) % 60;
  final base = '$m:${s.toString().padLeft(2, '0')}';
  return tenths ? '$base,${(total ~/ 100) % 10}' : base;
}

/// Один слушатель касаний на всё время жеста — от касания до отпускания,
/// в какую бы фазу ни ушла запись. Ребёнок (вид кнопки) может меняться.
class VoiceRecordGestureArea extends StatefulWidget {
  const VoiceRecordGestureArea({
    super.key,
    required this.controller,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final RecordGestureTarget controller;
  final Widget child;

  /// Короткое касание (запись не началась).
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<VoiceRecordGestureArea> createState() => _VoiceRecordGestureAreaState();
}

class _VoiceRecordGestureAreaState extends State<VoiceRecordGestureArea> {
  int? _pointer;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (!widget.enabled || _pointer != null) return;
        _pointer = e.pointer;
        widget.controller.pointerDown(e.position);
      },
      onPointerMove: (e) {
        if (e.pointer != _pointer) return;
        widget.controller.pointerMove(e.position);
      },
      onPointerUp: (e) {
        if (e.pointer != _pointer) return;
        _pointer = null;
        if (widget.controller.pointerUp()) widget.onTap?.call();
      },
      onPointerCancel: (e) {
        if (e.pointer != _pointer) return;
        _pointer = null;
        widget.controller.pointerCancel();
      },
      child: widget.child,
    );
  }
}

/// Мигающая красная точка «идёт запись».
class RecordDot extends StatefulWidget {
  const RecordDot({super.key, this.size = 10});
  final double size;

  @override
  State<RecordDot> createState() => _RecDotState();
}

class _RecDotState extends State<RecordDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          color: kVoiceRed,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Таймер записи с десятыми.
class _Timer extends StatelessWidget {
  const _Timer({required this.controller, this.size = 16});

  final VoiceRecorderController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: controller.elapsed,
      builder: (context, d, _) => SizedBox(
        width: size * 3.6,
        child: Text(
          _fmt(d, tenths: true),
          maxLines: 1,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Содержимое поля ввода во время записи.
class VoiceRecorderPanel extends StatelessWidget {
  const VoiceRecorderPanel({
    super.key,
    required this.controller,
    required this.strings,
    required this.accent,
  });

  final VoiceRecorderController controller;
  final VoiceRecorderStrings strings;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VoicePhase>(
      valueListenable: controller.phase,
      builder: (context, phase, _) {
        final Widget view = switch (phase) {
          VoicePhase.holding || VoicePhase.arming => _HoldingView(
            key: const ValueKey('voice-holding'),
            controller: controller,
            strings: strings,
          ),
          VoicePhase.locked => _LockedView(
            key: const ValueKey('voice-locked'),
            controller: controller,
            strings: strings,
            accent: accent,
          ),
          VoicePhase.preview => _PreviewView(
            key: const ValueKey('voice-preview'),
            controller: controller,
            strings: strings,
            accent: accent,
          ),
          VoicePhase.cancelling => _DeletedView(
            key: const ValueKey('voice-deleted'),
            strings: strings,
          ),
          VoicePhase.idle => const SizedBox.shrink(key: ValueKey('voice-idle')),
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Motion.standard,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.35),
                end: Offset.zero,
              ).animate(a),
              child: child,
            ),
          ),
          child: SizedBox(key: view.key, height: 44, child: view),
        );
      },
    );
  }
}

class _HoldingView extends StatelessWidget {
  const _HoldingView({
    super.key,
    required this.controller,
    required this.strings,
  });

  final VoiceRecorderController controller;
  final VoiceRecorderStrings strings;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ValueListenableBuilder<bool>(
      valueListenable: controller.cancelArmed,
      builder: (context, armed, _) => Row(
        children: [
          const SizedBox(width: 10),
          SizedBox(
            width: 22,
            height: 22,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Motion.popElastic),
                  child: c,
                ),
                child: armed
                    ? const Icon(
                        VoiceIcons.trash,
                        key: ValueKey('armed'),
                        size: 20,
                        color: kVoiceRed,
                      )
                    : const RecordDot(key: ValueKey('dot')),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Timer(controller: controller),
          Expanded(
            child: ValueListenableBuilder<Offset>(
              valueListenable: controller.drag,
              builder: (context, drag, _) {
                final cp = controller.cancelProgress;
                final vertical = drag.dy.abs() > drag.dx.abs();
                final dx = armed || vertical ? 0.0 : math.max(drag.dx * 0.8, -36);
                return Transform.translate(
                  offset: Offset(dx.toDouble(), 0),
                  child: Opacity(
                    opacity: 1 - cp * 0.5,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: armed
                            ? Text(
                                strings.releaseToDelete,
                                key: const ValueKey('release'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: kVoiceRed,
                                ),
                              )
                            : RecordShimmer(
                                key: const ValueKey('slide'),
                                color: muted,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(VoiceIcons.left, size: 18, color: muted),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        strings.slideToCancel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          color: muted,
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
              },
            ),
          ),
          // Место под кнопку справа (её рисует поле ввода).
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Мерцающая подсказка: блик бежит по тексту справа налево.
class RecordShimmer extends StatefulWidget {
  const RecordShimmer({super.key, required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  State<RecordShimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<RecordShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hi = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = 1.2 - _c.value * 1.4;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => LinearGradient(
            colors: [widget.color, hi, widget.color],
            stops: [
              (t - 0.12).clamp(0.0, 1.0),
              t.clamp(0.0, 1.0),
              (t + 0.12).clamp(0.0, 1.0),
            ],
          ).createShader(r),
          child: child,
        );
      },
    );
  }
}

class RecordTrashButton extends StatelessWidget {
  const RecordTrashButton({super.key, required this.onTap, required this.label});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        highlightColor: kVoiceRed.withValues(alpha: 0.12),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(VoiceIcons.trashOutline, size: 23, color: kVoiceRed),
        ),
      ),
    );
  }
}

class _LockedView extends StatelessWidget {
  const _LockedView({
    super.key,
    required this.controller,
    required this.strings,
    required this.accent,
  });

  final VoiceRecorderController controller;
  final VoiceRecorderStrings strings;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 4),
        RecordTrashButton(onTap: controller.cancel, label: strings.delete),
        const SizedBox(width: 4),
        const RecordDot(size: 8),
        const SizedBox(width: 8),
        _Timer(controller: controller, size: 15),
        Expanded(
          child: SizedBox(
            height: 28,
            child: ValueListenableBuilder<int>(
              valueListenable: controller.samplesVersion,
              builder: (context, _, __) => CustomPaint(
                painter: _LiveWavePainter(
                  samples: controller.samples,
                  color: accent,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// Живая волна: последние значения справа.
class _LiveWavePainter extends CustomPainter {
  _LiveWavePainter({required this.samples, required this.color})
    : _count = samples.length;

  final List<double> samples;
  final Color color;
  final int _count;

  @override
  void paint(Canvas canvas, Size size) {
    const bar = 3.0, gap = 2.0;
    final n = (size.width / (bar + gap)).floor();
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = bar;
    final start = math.max(0, samples.length - n);
    var x = size.width - bar / 2;
    for (var i = samples.length - 1; i >= start; i--) {
      final h = 3 + samples[i] * (size.height - 6);
      final cy = size.height / 2;
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
      x -= bar + gap;
    }
  }

  @override
  bool shouldRepaint(_LiveWavePainter old) =>
      old._count != _count || old.color != color;
}

class _PreviewView extends StatelessWidget {
  const _PreviewView({
    super.key,
    required this.controller,
    required this.strings,
    required this.accent,
  });

  final VoiceRecorderController controller;
  final VoiceRecorderStrings strings;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.light
        ? const Color(0xFF0F2A3D)
        : Colors.white;
    final wave = voiceWaveformFrom(controller.samples, 34);
    return Row(
      children: [
        const SizedBox(width: 4),
        RecordTrashButton(onTap: controller.cancel, label: strings.delete),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: controller.previewPlaying,
                  builder: (context, playing, _) => Semantics(
                    button: true,
                    label: playing ? strings.pause : strings.play,
                    child: GestureDetector(
                      onTap: controller.togglePreview,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (c, a) =>
                              ScaleTransition(scale: a, child: c),
                          child: Icon(
                            playing ? VoiceIcons.pause : VoiceIcons.play,
                            key: ValueKey(playing),
                            size: 18,
                            color: onAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 24,
                    child: ValueListenableBuilder<double>(
                      valueListenable: controller.previewPosition,
                      builder: (context, pos, _) => CustomPaint(
                        painter: _ProgressWavePainter(
                          bars: wave,
                          progress: pos,
                          played: accent,
                          rest: accent.withValues(alpha: 0.38),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<double>(
                  valueListenable: controller.previewPosition,
                  builder: (context, pos, _) {
                    final total = controller.elapsed.value;
                    final shown = pos > 0 ? total * pos : total;
                    return Text(
                      _fmt(shown),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// Волна с прогрессом: проигранное — ярко, остальное — бледно.
class _ProgressWavePainter extends CustomPainter {
  _ProgressWavePainter({
    required this.bars,
    required this.progress,
    required this.played,
    required this.rest,
  });

  final List<int> bars;
  final double progress;
  final Color played;
  final Color rest;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const w = 2.5;
    final step = size.width / bars.length;
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w;
    for (var i = 0; i < bars.length; i++) {
      final x = step * i + step / 2;
      final h = 3 + bars[i] / 100 * (size.height - 6);
      p.color = (i + 0.5) / bars.length <= progress ? played : rest;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressWavePainter old) =>
      old.progress != progress || old.bars != bars || old.played != played;
}

class _DeletedView extends StatefulWidget {
  const _DeletedView({super.key, required this.strings});
  final VoiceRecorderStrings strings;

  @override
  State<_DeletedView> createState() => _DeletedViewState();
}

class _DeletedViewState extends State<_DeletedView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 14),
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value;
            // Корзина подпрыгивает, качается и «закрывается».
            final scale = t < 0.3
                ? 1 + t / 0.3 * 0.25
                : (t < 0.6
                      ? 1.25 - (t - 0.3) / 0.3 * 0.15
                      : 1.1 * (1 - (t - 0.6) / 0.4));
            final rot = t < 0.3
                ? -0.21 * t / 0.3
                : (t < 0.6 ? -0.21 + 0.38 * (t - 0.3) / 0.3 : 0.17 * (1 - t));
            return Opacity(
              opacity: t < 0.6 ? 1 : 1 - (t - 0.6) / 0.4,
              child: Transform.rotate(
                angle: rot,
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
          child: const Icon(VoiceIcons.trash, size: 24, color: kVoiceRed),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.strings.deleted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Над чатом: большой круг под пальцем, капсула замка, «Стоп».
///
/// [anchor] — где сейчас кнопка микрофона (глобально); сам слой касаний не
/// ловит, кроме «Стоп».
class VoiceRecorderOverlay extends StatelessWidget {
  const VoiceRecorderOverlay({
    super.key,
    required this.controller,
    required this.anchor,
    required this.accentTop,
    required this.accentBottom,
    required this.strings,
  });

  final VoiceRecorderController controller;
  final Rect? Function() anchor;
  final Color accentTop;
  final Color accentBottom;
  final VoiceRecorderStrings strings;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VoicePhase>(
      valueListenable: controller.phase,
      builder: (context, phase, _) {
        final rect = anchor();
        if (rect == null) return const SizedBox.shrink();
        final c = rect.center;
        final holding = phase == VoicePhase.holding;
        final locked = phase == VoicePhase.locked;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Капсула замка: тянешь вверх — сжимается, замок закрывается.
            if (holding)
              ValueListenableBuilder<Offset>(
                valueListenable: controller.drag,
                builder: (context, _, __) => ValueListenableBuilder<bool>(
                  valueListenable: controller.cancelArmed,
                  builder: (context, armed, _) {
                    final lp = controller.lockProgress;
                    final h = 92 - 44 * lp;
                    return Positioned(
                      left: c.dx - 22,
                      top: c.dy - 58 - h - lp * 18,
                      width: 44,
                      height: h,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          opacity: armed ? 0 : 1,
                          child: RecordLockPill(
                            progress: lp,
                            accent: accentTop,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            // «Стоп» над кнопкой отправки в закреплённой записи.
            if (locked)
              Positioned(
                left: c.dx - 22,
                top: c.dy - 58 - 44,
                width: 44,
                height: 44,
                child: RecordPopIn(
                  child: Semantics(
                    button: true,
                    label: strings.stop,
                    child: GestureDetector(
                      onTap: controller.stopToPreview,
                      child: const RecordGlassCircle(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: kVoiceRed,
                              borderRadius: BorderRadius.all(
                                Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Большой круг под пальцем.
            if (holding)
              Positioned.fill(
                child: IgnorePointer(
                  child: _BigCircle(
                    controller: controller,
                    center: c,
                    accentTop: accentTop,
                    accentBottom: accentBottom,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BigCircle extends StatelessWidget {
  const _BigCircle({
    required this.controller,
    required this.center,
    required this.accentTop,
    required this.accentBottom,
  });

  final VoiceRecorderController controller;
  final Offset center;
  final Color accentTop;
  final Color accentBottom;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Появление: круг вырастает из кнопки.
      tween: Tween<double>(begin: 0.55, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: const Cubic(0.2, 0.9, 0.3, 1.2),
      builder: (context, grow, _) => AnimatedBuilder(
        animation: Listenable.merge([
          controller.drag,
          controller.level,
          controller.cancelArmed,
        ]),
        builder: (context, _) {
          final d = controller.drag.value;
          final armed = controller.cancelArmed.value;
          final vertical = d.dy.abs() > d.dx.abs();
          final ox = vertical ? d.dx * 0.25 : math.max(d.dx, -170.0);
          final oy = vertical
              ? math.max(d.dy, -controller.lockDistance) * 0.9
              : d.dy * 0.25;
          final p = center + Offset(ox, oy);
          const size = 84.0;
          final ring = 1 + controller.level.value * 0.5;
          final top = armed ? const Color(0xFFFF7A7E) : accentTop;
          final bottom = armed ? const Color(0xFFE0404A) : accentBottom;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Дыхание в такт голосу.
              Positioned(
                left: p.dx - size / 2,
                top: p.dy - size / 2,
                width: size,
                height: size,
                child: Transform.scale(
                  scale: ring * grow,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (armed ? kVoiceRed : accentTop).withValues(
                        alpha: 0.22,
                      ),
                    ),
                  ),
                ),
              ),
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
                      shape: BoxShape.circle,
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
                          armed ? VoiceIcons.trash : VoiceIcons.mic,
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

class RecordLockPill extends StatefulWidget {
  const RecordLockPill({super.key, required this.progress, required this.accent});
  final double progress;
  final Color accent;

  @override
  State<RecordLockPill> createState() => _LockPillState();
}

class _LockPillState extends State<RecordLockPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = widget.progress;
    final closed = lp > 0.6;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return RecordPopIn(
      child: RecordGlassCapsule(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Motion.popElastic),
                  child: c,
                ),
                child: Icon(
                  closed ? VoiceIcons.lock : VoiceIcons.lockOpen,
                  key: ValueKey(closed),
                  size: 21,
                  color: closed ? widget.accent : muted,
                ),
              ),
              if (lp < 0.95)
                Expanded(
                  child: Opacity(
                    opacity: (1 - lp).clamp(0.0, 1.0),
                    child: AnimatedBuilder(
                      animation: _bob,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                          0,
                          -5 * Curves.easeInOut.transform(_bob.value),
                        ),
                        child: child,
                      ),
                      child: Icon(VoiceIcons.up, size: 20, color: muted),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Тёмная стеклянная капсула (замок, «Стоп»).
class RecordGlassCapsule extends StatelessWidget {
  const RecordGlassCapsule({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xEB232E3C) : const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.12 : 0.6),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class RecordGlassCircle extends StatelessWidget {
  const RecordGlassCircle({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      RecordGlassCapsule(child: Center(child: child));
}

/// Появление пружинкой.
class RecordPopIn extends StatelessWidget {
  const RecordPopIn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Motion.popElastic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
      child: child,
    );
  }
}

/// Подсказка над полем ввода («Удерживайте, чтобы записать»).
class VoiceHintToast extends StatelessWidget {
  const VoiceHintToast({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return RecordPopIn(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE00A0E13),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
