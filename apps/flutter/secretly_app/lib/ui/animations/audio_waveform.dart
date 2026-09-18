// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated waveform visualization for audio playback.
///
/// Shows animated bars that react to playback state.
/// When paused, bars are static and small. When playing, they animate.
class AudioWaveform extends StatefulWidget {
  const AudioWaveform({
    super.key,
    this.isPlaying = false,
    this.barCount = 20,
    this.width = 120,
    this.height = 32,
    this.color,
    this.barWidth = 2.5,
    this.barSpacing = 1.5,
    this.minBarHeight = 0.15,
    this.duration = const Duration(milliseconds: 800),
  });

  final bool isPlaying;
  final int barCount;
  final double width;
  final double height;
  final Color? color;
  final double barWidth;
  final double barSpacing;
  final double minBarHeight;
  final Duration duration;

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<double> _barSeeds;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42); // deterministic seed for consistent look
    _barSeeds = List.generate(widget.barCount, (_) => rng.nextDouble());

    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(AudioWaveform old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !old.isPlaying) {
      _controller.repeat();
    } else if (!widget.isPlaying && old.isPlaying) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.75);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _WaveformPainter(
              progress: _controller.value,
              isPlaying: widget.isPlaying,
              barSeeds: _barSeeds,
              color: color,
              barWidth: widget.barWidth,
              barSpacing: widget.barSpacing,
              minBarHeight: widget.minBarHeight,
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.progress,
    required this.isPlaying,
    required this.barSeeds,
    required this.color,
    required this.barWidth,
    required this.barSpacing,
    required this.minBarHeight,
  });

  final double progress;
  final bool isPlaying;
  final List<double> barSeeds;
  final Color color;
  final double barWidth;
  final double barSpacing;
  final double minBarHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final totalBarWidth = barWidth + barSpacing;
    final barsToFit = (size.width / totalBarWidth).floor().clamp(1, barSeeds.length);
    final startX = (size.width - barsToFit * totalBarWidth) / 2;

    for (int i = 0; i < barsToFit; i++) {
      final seed = barSeeds[i % barSeeds.length];
      double heightFraction;

      if (isPlaying) {
        // Animated: sine wave with per-bar phase offset
        final phase = seed * 2 * math.pi + progress * 2 * math.pi;
        heightFraction = (math.sin(phase) * 0.5 + 0.5) * (0.4 + seed * 0.6);
        heightFraction = heightFraction.clamp(minBarHeight, 1.0);
      } else {
        // Static: small bars at seed-derived heights
        heightFraction = (seed * 0.35 + 0.15).clamp(minBarHeight, 0.5);
      }

      final barH = heightFraction * size.height;
      final x = startX + i * totalBarWidth + barWidth / 2;
      final y1 = (size.height - barH) / 2;
      final y2 = y1 + barH;

      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      progress != old.progress || isPlaying != old.isPlaying;
}

// ─────────────────────────────────────────────────────────────────────────────
// Seekable static waveform — shows audio bars with a played/unplayed split.
// Tap or horizontal drag to seek.
// ─────────────────────────────────────────────────────────────────────────────

class SeekableAudioWaveform extends StatelessWidget {
  const SeekableAudioWaveform({
    super.key,
    this.progress = 0.0,
    required this.seed,
    this.amplitudes,
    this.height = 38.0,
    this.barCount = 42,
    this.barWidth = 2.5,
    this.barSpacing = 2.0,
    this.playedColor = const Color(0xEEFFFFFF),
    this.unplayedColor = const Color(0x44FFFFFF),
    this.onSeek,
  });

  /// Playback progress in [0, 1].
  final double progress;

  /// Deterministic seed for bar heights (use blobId.hashCode). Only used as a
  /// fallback when [amplitudes] is null (e.g. legacy / demo voice notes).
  final int seed;

  /// Real captured amplitude envelope in [0, 100] (one entry per source bar).
  /// When provided the painter renders the actual waveform of the whole track,
  /// stretched to fill the available width.
  final List<int>? amplitudes;

  final double height;
  final int barCount;
  final double barWidth;
  final double barSpacing;

  /// Color for bars that have already been played (left of progress).
  final Color playedColor;

  /// Color for bars that have not been played yet.
  final Color unplayedColor;

  /// Called with a fraction [0, 1] when the user taps or drags on the waveform.
  final void Function(double fraction)? onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onSeek == null
              ? null
              : (d) => onSeek!((d.localPosition.dx / w).clamp(0.0, 1.0)),
          onHorizontalDragUpdate: onSeek == null
              ? null
              : (d) => onSeek!((d.localPosition.dx / w).clamp(0.0, 1.0)),
          child: SizedBox(
            width: w,
            height: height,
            child: CustomPaint(
              painter: _SeekableWaveformPainter(
                progress: progress,
                seed: seed,
                amplitudes: amplitudes,
                barCount: barCount,
                barWidth: barWidth,
                barSpacing: barSpacing,
                playedColor: playedColor,
                unplayedColor: unplayedColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeekableWaveformPainter extends CustomPainter {
  _SeekableWaveformPainter({
    required this.progress,
    required this.seed,
    required this.amplitudes,
    required this.barCount,
    required this.barWidth,
    required this.barSpacing,
    required this.playedColor,
    required this.unplayedColor,
  });

  final double progress;
  final int seed;
  final List<int>? amplitudes;
  final int barCount;
  final double barWidth;
  final double barSpacing;
  final Color playedColor;
  final Color unplayedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final totalBarWidth = barWidth + barSpacing;
    final barsToFit = math.max(1, (size.width / totalBarWidth).floor());

    // Per-drawn-bar height fraction in [0.12, 1.0].
    final real = amplitudes;
    double heightFractionFor(int i) {
      if (real != null && real.isNotEmpty) {
        // Stretch the captured envelope across however many bars fit, so the
        // whole track is always represented regardless of width.
        final src = (i * real.length / barsToFit).floor().clamp(
          0,
          real.length - 1,
        );
        return (0.12 + (real[src].clamp(0, 100) / 100.0) * 0.88).clamp(
          0.12,
          1.0,
        );
      }
      // Fallback: deterministic pseudo-random envelope (squared for nicer peaks).
      final r = math.Random(seed + i).nextDouble();
      return (0.12 + r * r * 0.88).clamp(0.12, 1.0);
    }

    final playedPaint = Paint()
      ..color = playedColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    final unplayedPaint = Paint()
      ..color = unplayedColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final playedBarIndex = (progress * barsToFit).round().clamp(0, barsToFit);

    for (int i = 0; i < barsToFit; i++) {
      final h = heightFractionFor(i) * size.height;
      final x = i * totalBarWidth + barWidth / 2;
      final y1 = (size.height - h) / 2;
      final y2 = y1 + h;
      canvas.drawLine(
        Offset(x, y1),
        Offset(x, y2),
        i < playedBarIndex ? playedPaint : unplayedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SeekableWaveformPainter old) =>
      progress != old.progress ||
      seed != old.seed ||
      !identical(amplitudes, old.amplitudes);
}
