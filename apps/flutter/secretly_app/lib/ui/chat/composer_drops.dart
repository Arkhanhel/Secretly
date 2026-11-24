// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Поле ввода «Капля» — макет «Панель ввода в чате», вариант 1a (22.11.2026).
///
/// Три отдельные капли: «+» (вложения), поле (текст и ☺) и действие (микрофон
/// / кружок / отправить). С первым символом микрофон перетекает в стрелку, и
/// капля заливается цветом — без смены размера и рывков.
///
///  * iPhone — жидкое стекло: все капли в одном `BackdropGroup` (один снимок
///    фона за кадр), размытие 14 + насыщенность 170 % одним фильтром, блик
///    края — статичный рисунок в `RepaintBoundary` (при наборе перерисовывается
///    только текст). Нажатие — «линза»: масштаб 1,12 и светлее, пружина.
///    «Размытие панелей» выключено — та же геометрия на сплошной подложке.
///  * Android — матовое стекло, как у прежней панели (размытие 24, тонкий
///    кант; слово владельца 22.11.2026) и морф формы Material 3: круг, с
///    текстом — скруглённый квадрат, нажатие сжимает углы сильнее.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../icons/adaptive_icons.dart';

/// Пружина «линзы» и возврата (`cubic-bezier(.3,1.7,.45,1)`).
const Cubic kDropPressSpring = Cubic(.3, 1.7, .45, 1);

/// Перетекание значков и заливки (`cubic-bezier(.3,1.6,.5,1)`).
const Cubic kDropMorphSpring = Cubic(.3, 1.6, .5, 1);

/// Морф формы Android (`cubic-bezier(.3,1.5,.5,1)`).
const Cubic kDropShapeSpring = Cubic(.3, 1.5, .5, 1);

/// Что показывает капля действия.
enum ComposerDropAction { mic, video, send }

/// Оформление капель для платформы и темы.
@immutable
class ComposerDropStyle {
  const ComposerDropStyle({
    required this.glass,
    required this.frosted,
    required this.dark,
    required this.size,
    required this.fill,
    required this.pressedFill,
    required this.icon,
    required this.hairline,
    required this.highlight,
    required this.shadow,
    required this.accentColors,
    required this.accentInk,
    required this.androidAccent,
    required this.androidOnAccent,
  });

  /// iPhone — стекло; Android — тональные поверхности.
  final bool glass;

  /// Размытие разрешено настройкой «Размытие панелей».
  final bool frosted;
  final bool dark;

  /// Сторона круглой капли: 44 iPhone, 48 Android.
  final double size;
  final Color fill;
  final Color pressedFill;
  final Color icon;
  final Color hairline;
  final Color highlight;
  final List<BoxShadow> shadow;

  /// Заливка капли «отправить» на iPhone (градиент 135°).
  final List<Color> accentColors;
  final Color accentInk;

  /// Заливка капли «отправить» на Android (тональный акцент).
  final Color androidAccent;
  final Color androidOnAccent;

  double get radius => size / 2;

  static ComposerDropStyle of(
    BuildContext context, {
    required bool frosted,
    required Color accentTop,
    required Color accentBottom,
    required Color solidFill,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final glass = defaultTargetPlatform == TargetPlatform.iOS;
    final mid = Color.lerp(accentTop, accentBottom, .5) ?? accentTop;
    if (glass) {
      return ComposerDropStyle(
        glass: true,
        frosted: frosted,
        dark: dark,
        size: 44,
        fill: !frosted
            ? solidFill
            : dark
            ? const Color(0x13FFFFFF) // rgba(255,255,255,.075)
            : const Color(0xB8FFFFFF),
        pressedFill: !frosted
            ? Color.alphaBlend(
                (dark ? Colors.white : Colors.black).withValues(alpha: .08),
                solidFill,
              )
            : dark
            ? const Color(0x29FFFFFF) // .16
            : const Color(0xE6FFFFFF),
        icon: dark ? const Color(0xFFEAF1F7) : cs.onSurface,
        hairline: dark ? const Color(0x24FFFFFF) : const Color(0x140E141B),
        highlight: dark ? const Color(0x57FFFFFF) : const Color(0xE6FFFFFF),
        shadow: [
          BoxShadow(
            color: dark ? const Color(0x47000000) : const Color(0x1A0E141B),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
        accentColors: [accentTop, mid, accentBottom],
        accentInk: Colors.white,
        androidAccent: cs.primary,
        androidOnAccent: cs.onPrimary,
      );
    }
    // Android — матовое стекло, как у прежней панели ввода (слово владельца
    // 22.11.2026): размытие 24 без насыщенности, почти прозрачная подложка в
    // тёмной теме и плотная белая в светлой, тонкий кант. Форма — морф M3.
    return ComposerDropStyle(
      glass: false,
      frosted: frosted,
      dark: dark,
      size: 48,
      fill: !frosted
          ? solidFill
          : dark
          ? const Color(0x0AFFFFFF)
          : const Color(0xA6FFFFFF),
      pressedFill: !frosted
          ? Color.alphaBlend(
              (dark ? Colors.white : Colors.black).withValues(alpha: .08),
              solidFill,
            )
          : dark
          ? const Color(0x24FFFFFF)
          : const Color(0xE6FFFFFF),
      icon: dark ? Colors.white : cs.onSurface,
      hairline: dark ? const Color(0x14FFFFFF) : const Color(0x6BFFFFFF),
      highlight: Colors.transparent,
      shadow: dark
          ? const <BoxShadow>[]
          : const [
              BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
      accentColors: [accentTop, mid, accentBottom],
      accentInk: Colors.white,
      androidAccent: cs.primary,
      androidOnAccent: cs.onPrimary,
    );
  }
}

/// Значки капель: на iPhone — системные Apple, на Android — Material.
class ComposerDropIcons {
  static const IconData add = AdaptiveIconData(
    Icons.add_rounded,
    CupertinoIcons.add,
  );
  static const IconData mic = AdaptiveIconData(
    Icons.mic_rounded,
    CupertinoIcons.mic_fill,
  );
  static const IconData video = AdaptiveIconData(
    Icons.videocam_rounded,
    CupertinoIcons.videocam_fill,
  );
  static const IconData sendIos = AdaptiveIconData(
    Icons.arrow_upward_rounded,
    CupertinoIcons.arrow_up,
  );
  static const IconData sendAndroid = AdaptiveIconData(
    Icons.send_rounded,
    CupertinoIcons.arrow_up,
  );
  static const IconData mood = AdaptiveIconData(
    Icons.mood_rounded,
    CupertinoIcons.smiley,
  );
}

/// Стеклянный (iPhone) или тональный (Android) фон капли — в общем
/// `BackdropGroup` поля ввода.
class ComposerDropSurface extends StatelessWidget {
  const ComposerDropSurface({
    super.key,
    required this.style,
    required this.radius,
    required this.child,
    this.fill,
  });

  final ComposerDropStyle style;
  final BorderRadius radius;
  final Widget child;

  /// Своя заливка (нажатие).
  final Color? fill;

  static final ui.ImageFilter _matteFilter = ui.ImageFilter.blur(
    sigmaX: 24,
    sigmaY: 24,
  );

  static final ui.ImageFilter _glassFilter = ui.ImageFilter.compose(
    outer: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
    inner: const ColorFilter.matrix(<double>[
      // Насыщенность 170 % (как saturate(170%) у CSS).
      1.55118, -0.50064, -0.05054, 0, 0, //
      -0.14882, 1.19936, -0.05054, 0, 0,
      -0.14882, -0.50064, 1.64946, 0, 0,
      0, 0, 0, 1, 0,
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final s = style;
    final body = DecoratedBox(
      decoration: BoxDecoration(color: fill ?? s.fill, borderRadius: radius),
      child: child,
    );
    if (!s.glass) {
      // Матовое стекло Android (как прежняя панель): размытие 24, кант 1.
      Widget matte = ClipRRect(
        borderRadius: radius,
        child: s.frosted
            ? BackdropFilter.grouped(filter: _matteFilter, child: body)
            : body,
      );
      matte = CustomPaint(
        foregroundPainter: _DropEdgePainter(
          radius: radius,
          hairline: s.hairline,
          highlight: Colors.transparent,
        ),
        child: matte,
      );
      return DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: s.shadow),
        child: matte,
      );
    }
    Widget glass = ClipRRect(
      borderRadius: radius,
      child: s.frosted
          ? BackdropFilter.grouped(filter: _glassFilter, child: body)
          : body,
    );
    glass = CustomPaint(
      foregroundPainter: _DropEdgePainter(
        radius: radius,
        hairline: s.hairline,
        highlight: s.highlight,
      ),
      child: glass,
    );
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: s.shadow),
      child: glass,
    );
  }
}

/// Блик края: тонкий контур .5 и светлая дуга сверху, гаснущая к середине.
class _DropEdgePainter extends CustomPainter {
  _DropEdgePainter({
    required this.radius,
    required this.hairline,
    required this.highlight,
  });

  final BorderRadius radius;
  final Color hairline;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(.25);
    final rr = radius.toRRect(rect);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .5
        ..color = hairline,
    );
    final h = size.height;
    canvas.drawRRect(
      radius.toRRect((Offset.zero & size).deflate(.6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [highlight, highlight.withValues(alpha: 0), highlight.withValues(alpha: 0)],
          stops: const [0, .45, 1],
        ).createShader(Rect.fromLTWH(0, 0, size.width, h)),
    );
  }

  @override
  bool shouldRepaint(_DropEdgePainter old) =>
      old.radius != radius ||
      old.hairline != hairline ||
      old.highlight != highlight;
}

/// Нажатие капли: на iPhone «линза» (масштаб 1,12, светлее), на Android —
/// морф углов. Слушает касания, но в борьбу жестов не вступает — снаружи
/// остаются свои распознаватели (касание, удержание, запись).
class ComposerDropPress extends StatefulWidget {
  const ComposerDropPress({
    super.key,
    required this.builder,
    this.enabled = true,
  });

  final bool enabled;
  final Widget Function(BuildContext context, bool pressed) builder;

  @override
  State<ComposerDropPress> createState() => _ComposerDropPressState();
}

class _ComposerDropPressState extends State<ComposerDropPress> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v || !mounted) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.enabled ? (_) => _set(true) : null,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: widget.builder(context, _down && widget.enabled),
    );
  }
}

/// Круглая капля «+» (вложения).
class ComposerAttachDrop extends StatelessWidget {
  const ComposerAttachDrop({
    super.key,
    required this.style,
    required this.onTap,
    required this.tooltip,
  });

  final ComposerDropStyle style;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final s = style;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ComposerDropPress(
          enabled: enabled,
          builder: (context, down) {
            final r = s.glass ? s.radius : (down ? 14.0 : s.radius);
            final surface = TweenAnimationBuilder<double>(
              tween: Tween<double>(end: r),
              duration: const Duration(milliseconds: 350),
              curve: kDropShapeSpring,
              builder: (context, rr, _) => ComposerDropSurface(
                style: s,
                radius: BorderRadius.circular(rr.clamp(0, s.size / 2)),
                fill: down ? s.pressedFill : null,
                child: SizedBox(
                  width: s.size,
                  height: s.size,
                  child: Center(
                    child: Icon(
                      ComposerDropIcons.add,
                      size: s.glass ? 27 : 26,
                      color: enabled ? s.icon : s.icon.withValues(alpha: .4),
                    ),
                  ),
                ),
              ),
            );
            if (!s.glass) return surface;
            return AnimatedScale(
              scale: down ? 1.12 : 1,
              duration: const Duration(milliseconds: 400),
              curve: kDropPressSpring,
              child: surface,
            );
          },
        ),
      ),
    );
  }
}

/// Капля поля: стекло/тон, радиус 22 (iPhone) / 24 (Android), растёт до
/// 6 строк; кнопки прижаты к нижней строке.
class ComposerFieldDrop extends StatelessWidget {
  const ComposerFieldDrop({
    super.key,
    required this.style,
    required this.child,
    this.trailing,
    this.header,
  });

  final ComposerDropStyle style;
  final Widget child;
  final Widget? trailing;

  /// Ответ / правка / пересылка над текстом — ВНУТРИ капли: капля растёт
  /// вверх и шапка выезжает из неё (22.11.2026). `null` — нет.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final s = style;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: s.size),
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.glass ? 16 : 18, 0, s.glass ? 5 : 4, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: child),
            ?trailing,
          ],
        ),
      ),
    );
    final h = header;
    return ComposerDropSurface(
      style: s,
      radius: BorderRadius.circular(s.radius),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Растёт снизу вверх: шапка выезжает из капли, текст стоит на месте.
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: const Cubic(0.2, 0.9, 0.25, 1.05),
              alignment: Alignment.bottomCenter,
              child: h == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          h,
                          // Тонкая черта с отступами, как разделитель в
                          // списках iOS: шапка и текст — одна капля.
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            child: SizedBox(
                              height: 0.5,
                              child: ColoredBox(
                                color: s.icon.withValues(alpha: 0.16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          row,
        ],
      ),
    );
  }
}

/// ☺ внутри поля: 34 (iPhone, нажатие ×1,2) / 40 (Android, круглая подложка).
class ComposerEmojiDrop extends StatelessWidget {
  const ComposerEmojiDrop({
    super.key,
    required this.style,
    required this.onTap,
    required this.tooltip,
    required this.child,
  });

  final ComposerDropStyle style;
  final VoidCallback? onTap;
  final String tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = style;
    final box = s.glass ? 34.0 : 40.0;
    return Padding(
      padding: EdgeInsets.only(bottom: s.glass ? 5 : 4),
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ComposerDropPress(
            enabled: onTap != null,
            builder: (context, down) {
              final glyph = SizedBox(
                width: box,
                height: box,
                child: Center(child: child),
              );
              if (s.glass) {
                return AnimatedScale(
                  scale: down ? 1.2 : 1,
                  duration: const Duration(milliseconds: 300),
                  curve: kDropPressSpring,
                  child: glyph,
                );
              }
              return AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: down ? s.pressedFill : s.pressedFill.withValues(alpha: 0),
                ),
                child: glyph,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Капля действия: одна на всё. Без текста — микрофон (касание меняет на
/// кружок), с текстом — заливка цветом и стрелка. Значки перетекают друг в
/// друга поворотом и масштабом; размер капли не меняется никогда.
///
/// Жесты (касание, удержание, запись) — снаружи; [pulse] — счётчик
/// отправок: при каждом новом значении капля коротко сжимается до 0,8.
class ComposerActionDropView extends StatefulWidget {
  const ComposerActionDropView({
    super.key,
    required this.style,
    required this.action,
    required this.filled,
    this.pulse = 0,
    this.enabled = true,
  });

  final ComposerDropStyle style;
  final ComposerDropAction action;

  /// Залита цветом (есть что отправить).
  final bool filled;
  final int pulse;
  final bool enabled;

  @override
  State<ComposerActionDropView> createState() => _ComposerActionDropViewState();
}

class _ComposerActionDropViewState extends State<ComposerActionDropView> {
  bool _squeezed = false;
  Timer? _pulseTimer;

  @override
  void didUpdateWidget(covariant ComposerActionDropView old) {
    super.didUpdateWidget(old);
    if (widget.pulse != old.pulse) {
      _pulseTimer?.cancel();
      setState(() => _squeezed = true);
      _pulseTimer = Timer(const Duration(milliseconds: 170), () {
        if (mounted) setState(() => _squeezed = false);
      });
    }
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  Widget _glyph({
    required IconData icon,
    required bool on,
    required Matrix4 off,
    required Color color,
    double size = 24,
  }) {
    return AnimatedOpacity(
      opacity: on ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: TweenAnimationBuilder<Matrix4>(
        tween: Matrix4Tween(end: on ? Matrix4.identity() : off),
        duration: Duration(milliseconds: widget.style.glass ? 450 : 400),
        curve: widget.style.glass ? kDropMorphSpring : kDropShapeSpring,
        builder: (context, m, child) => Transform(
          alignment: Alignment.center,
          transform: m,
          child: child,
        ),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }

  static Matrix4 _scaleRot(double s, double turns) => Matrix4.identity()
    ..rotateZ(turns * 2 * 3.141592653589793)
    ..scaleByDouble(s, s, 1, 1);

  static Matrix4 _drop(double dy, double s) => Matrix4.identity()
    ..translateByDouble(0, dy, 0, 1)
    ..scaleByDouble(s, s, 1, 1);

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final a = widget.action;
    final filled = widget.filled;
    final isSend = a == ComposerDropAction.send;
    return ComposerDropPress(
      enabled: widget.enabled,
      builder: (context, down) {
        final ink = filled
            ? s.accentInk
            : (widget.enabled ? s.icon : s.icon.withValues(alpha: .4));
        final icons = Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: _glyph(
                icon: ComposerDropIcons.mic,
                on: a == ComposerDropAction.mic,
                // В стрелку — против часовой, в кружок — по часовой.
                off: _scaleRot(.3, isSend ? -.25 : .25),
                color: ink,
              ),
            ),
            Center(
              child: _glyph(
                icon: ComposerDropIcons.video,
                on: a == ComposerDropAction.video,
                off: _scaleRot(.3, -.25),
                color: ink,
              ),
            ),
            Center(
              child: _glyph(
                icon: s.glass ? ComposerDropIcons.sendIos : ComposerDropIcons.sendAndroid,
                on: isSend,
                off: _drop(12, .3),
                color: ink,
                size: s.glass ? 25 : 23,
              ),
            ),
          ],
        );

        Widget drop;
        if (s.glass) {
          // Стекло + заливка-градиент, которая вырастает из центра.
          drop = ComposerDropSurface(
            style: s,
            radius: BorderRadius.circular(s.radius),
            fill: down && !filled ? s.pressedFill : null,
            child: SizedBox(
              width: s.size,
              height: s.size,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedOpacity(
                    opacity: filled ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: AnimatedScale(
                      scale: filled ? 1 : .4,
                      duration: const Duration(milliseconds: 450),
                      curve: kDropMorphSpring,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: s.accentColors,
                            stops: const [0, .55, 1],
                          ),
                        ),
                        child: CustomPaint(
                          painter: _AccentSheenPainter(),
                        ),
                      ),
                    ),
                  ),
                  icons,
                ],
              ),
            ),
          );
          final scale = _squeezed ? .8 : (down ? 1.12 : 1.0);
          return AnimatedScale(
            scale: scale,
            duration: Duration(milliseconds: _squeezed ? 120 : 450),
            curve: _squeezed ? Curves.easeOut : kDropPressSpring,
            child: drop,
          );
        }
        // Android: матовая капля; с текстом — заливка градиентом темы, как у
        // прежней кнопки отправки, и морф формы M3: круг → скруглённый
        // квадрат 16, нажатие — 12.
        final radius = down ? 12.0 : (filled ? 16.0 : s.radius);
        drop = TweenAnimationBuilder<double>(
          tween: Tween<double>(end: radius),
          duration: const Duration(milliseconds: 400),
          curve: kDropShapeSpring,
          builder: (context, r, child) {
            final br = BorderRadius.circular(r.clamp(0, s.size / 2));
            return ComposerDropSurface(
              style: s,
              radius: br,
              fill: down && !filled ? s.pressedFill : null,
              child: SizedBox(
                width: s.size,
                height: s.size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedOpacity(
                      opacity: filled ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: br,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: s.accentColors,
                            stops: const [0, .55, 1],
                          ),
                        ),
                      ),
                    ),
                    child!,
                  ],
                ),
              ),
            );
          },
          child: icons,
        );
        return AnimatedScale(
          scale: _squeezed ? .8 : 1,
          duration: Duration(milliseconds: _squeezed ? 120 : 350),
          curve: _squeezed ? Curves.easeOut : kDropMorphSpring,
          child: drop,
        );
      },
    );
  }
}

/// Внутренний блик заливки: светлая кромка сверху и лёгкая тень снизу
/// (`inset 0 1px 0 rgba(255,255,255,.5), inset 0 -6px 12px rgba(0,0,0,.12)`).
class _AccentSheenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x00000000), Color(0x1F000000)],
          stops: [0, .6, 1],
        ).createShader(Offset.zero & size),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - .6),
      3.141592653589793 * 1.15,
      3.141592653589793 * .7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x80FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_AccentSheenPainter old) => false;
}

/// Остров над каплями: ответ, правка, пересылка, упоминания, ограничения
/// комнаты — та же стеклянная/тональная поверхность.
class ComposerContextDrop extends StatelessWidget {
  const ComposerContextDrop({super.key, required this.style, required this.child});

  final ComposerDropStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ComposerDropSurface(
      style: style,
      radius: BorderRadius.circular(22),
      child: Padding(padding: const EdgeInsets.all(4), child: child),
    );
  }
}
