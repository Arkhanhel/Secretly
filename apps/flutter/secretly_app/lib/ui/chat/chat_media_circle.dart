// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Один круг состояния медиа на весь чат (21.11.2026, владелец: «иконки
/// начала воспроизведения, отмены и загрузки из 2a — на всё, что мы
/// отправляем: фото, видео, медиа в файлах»).
///
/// Язык тот же, что у голосовых и файлов 2a: круг, белый знак платформы
/// (на iPhone — Apple), тонкое белое кольцо хода. Два фона:
/// * [ChatMediaCircleStyle.accent] — сплошной синий 2a (строки файлов,
///   голосовые, музыка);
/// * [ChatMediaCircleStyle.overMedia] — тёмная вуаль поверх фото и видео
///   (белый знак читается на любом кадре).
///
/// Чтобы ничего не дёргалось: ход кольца едет плавно (не скачет по
/// событиям загрузки), смена знака — пружинкой, неопределённый ход —
/// бегущая дуга; по 100 % дуга замыкается.
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../icons/adaptive_icons.dart';
import '../motion/motion.dart';

enum ChatMediaGlyph { play, pause, download, cancel, retry, document, none }

enum ChatMediaCircleStyle { accent, overMedia }

/// Синий 2a — тот же, что у кнопки голосового и круга файла.
const Color kChatMediaAccent = Color(0xFF5C9CEF);

abstract final class ChatMediaIcons {
  static const IconData play = AdaptiveIconData(
    Icons.play_arrow_rounded,
    CupertinoIcons.play_fill,
  );
  static const IconData pause = AdaptiveIconData(
    Icons.pause_rounded,
    CupertinoIcons.pause_fill,
  );
  static const IconData download = AdaptiveIconData(
    Icons.arrow_downward_rounded,
    CupertinoIcons.arrow_down,
  );
  static const IconData cancel = AdaptiveIconData(
    Icons.close_rounded,
    CupertinoIcons.xmark,
  );
  static const IconData retry = AdaptiveIconData(
    Icons.refresh_rounded,
    CupertinoIcons.arrow_clockwise,
  );
  static const IconData document = AdaptiveIconData(
    Icons.insert_drive_file_rounded,
    CupertinoIcons.doc_fill,
  );
}

class ChatMediaCircle extends StatefulWidget {
  const ChatMediaCircle({
    super.key,
    required this.glyph,
    this.size = 48,
    this.style = ChatMediaCircleStyle.overMedia,
    this.ring = false,
    this.progress,
    this.onTap,
    this.semanticsLabel,
    this.icon,
  });

  final ChatMediaGlyph glyph;
  final double size;
  final ChatMediaCircleStyle style;

  /// Показывать кольцо хода. [progress] `null` — бегущая дуга.
  final bool ring;
  final double? progress;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  /// Свой знак вместо [glyph] (например, тип файла).
  final IconData? icon;

  @override
  State<ChatMediaCircle> createState() => _ChatMediaCircleState();
}

class _ChatMediaCircleState extends State<ChatMediaCircle>
    with SingleTickerProviderStateMixin {
  // Бегущая дуга — только когда нужна: круги без неё (их в ленте много)
  // тикера не держат. Создаётся по требованию, НЕ лениво в dispose.
  AnimationController? _spin;

  bool get _indeterminate => widget.ring && widget.progress == null;

  void _syncSpin() {
    if (_indeterminate) {
      (_spin ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )).repeat();
    } else {
      _spin?.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant ChatMediaCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  IconData? get _icon =>
      widget.icon ??
      switch (widget.glyph) {
        ChatMediaGlyph.play => ChatMediaIcons.play,
        ChatMediaGlyph.pause => ChatMediaIcons.pause,
        ChatMediaGlyph.download => ChatMediaIcons.download,
        ChatMediaGlyph.cancel => ChatMediaIcons.cancel,
        ChatMediaGlyph.retry => ChatMediaIcons.retry,
        ChatMediaGlyph.document => ChatMediaIcons.document,
        ChatMediaGlyph.none => null,
      };

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final over = widget.style == ChatMediaCircleStyle.overMedia;
    // Знаки — в пропорции 2a: play 26 в круге 42, крестик чуть мельче.
    final glyphSize = switch (widget.glyph) {
      ChatMediaGlyph.play => s * 0.56,
      ChatMediaGlyph.pause => s * 0.5,
      ChatMediaGlyph.cancel => s * 0.4,
      _ => s * 0.46,
    };
    final icon = _icon;
    // Без размытия под кругом: в ленте и галерее их десятки, а размытие —
    // дорогой слой на каждом (лаги на Android). Плотная тёмная вуаль + тень
    // знака читаются на любом кадре.
    final disc = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: over ? const Color(0x730A0E13) : kChatMediaAccent,
        border: over
            ? Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1)
            : null,
        boxShadow: over
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: const SizedBox.expand(),
    );
    final content = SizedBox(
      width: s,
      height: s,
      child: Stack(
        fit: StackFit.expand,
        children: [
          disc,
          if (widget.ring)
            TweenAnimationBuilder<double>(
              // Ход едет плавно, а не скачет по событиям загрузки.
              tween: Tween<double>(end: (widget.progress ?? 0).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, p, _) => AnimatedBuilder(
                animation: _spin ?? kAlwaysCompleteAnimation,
                builder: (context, _) => CustomPaint(
                  painter: ChatMediaRingPainter(
                    progress: widget.progress == null ? null : p,
                    rotation: _spin?.value ?? 0,
                    stroke: math.max(2.2, s * 0.064),
                  ),
                ),
              ),
            ),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Motion.popElastic),
                  child: child,
                ),
              ),
              child: icon == null
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : Padding(
                      key: ValueKey(icon),
                      // Треугольник «play» оптически смещён вправо.
                      padding: EdgeInsets.only(
                        left: widget.glyph == ChatMediaGlyph.play
                            ? s * 0.05
                            : 0,
                      ),
                      child: Icon(
                        icon,
                        size: glyphSize,
                        color: Colors.white,
                        shadows: over
                            ? const [
                                Shadow(color: Color(0x59000000), blurRadius: 6),
                              ]
                            : null,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
    final tap = widget.onTap;
    return Semantics(
      button: tap != null,
      label: widget.semanticsLabel,
      child: tap == null
          ? IgnorePointer(child: content)
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: tap,
              child: content,
            ),
    );
  }
}

/// Кольцо хода: белая дорожка 26 % и белая дуга с круглыми концами от 12 часов
/// по часовой. `progress == null` — бегущая дуга (0,6 π).
class ChatMediaRingPainter extends CustomPainter {
  ChatMediaRingPainter({
    required this.progress,
    required this.rotation,
    this.stroke = 3,
  });

  final double? progress;
  final double rotation;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2 - stroke / 2 - size.shortestSide * 0.07;
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.26),
    );
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    final p = progress;
    if (p == null) {
      canvas.drawArc(
        rect,
        rotation * 2 * math.pi - math.pi / 2,
        math.pi * 0.6,
        false,
        arc,
      );
    } else if (p > 0.004) {
      // Минимальный видимый кусочек, чтобы 1 % не выглядел пустым.
      final sweep = math.max(p, 0.02) * 2 * math.pi;
      canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
    }
  }

  @override
  bool shouldRepaint(covariant ChatMediaRingPainter old) =>
      old.progress != progress ||
      old.rotation != rotation ||
      old.stroke != stroke;
}
