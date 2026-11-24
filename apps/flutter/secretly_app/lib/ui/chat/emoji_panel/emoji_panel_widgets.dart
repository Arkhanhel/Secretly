// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Общие кирпичи панели: глиф эмодзи с кешем раскладки, нажатие-пружина,
/// островки, поиск в верхней строке, полёт в поле / в чат.
library;

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'emoji_panel_style.dart';

/// Запасные шрифты цветных эмодзи — те же, что `kEmojiFontFallback` в
/// `chat_screen.dart` (Apple Color Emoji намеренно нет: на iOS с ним пробел
/// становился огромным).
const List<String> kPanelEmojiFontFallback = <String>[
  'Noto Color Emoji',
  'NotoColorEmoji',
];

// ─── Глиф эмодзи ────────────────────────────────────────────────────────────

/// Раскладка глифа — один раз на (эмодзи, размер): прокрутка сетки только
/// рисует готовые [TextPainter], не раскладывая текст заново.
class _GlyphCache {
  static const int _max = 1400;
  static final LinkedHashMap<String, TextPainter> _cache =
      LinkedHashMap<String, TextPainter>();

  static TextPainter painter(String emoji, double size) {
    final key = '$emoji@${size.toStringAsFixed(1)}';
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: size,
          height: 1,
          fontFamilyFallback: kPanelEmojiFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    _cache[key] = tp;
    if (_cache.length > _max) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest)?.dispose();
    }
    return tp;
  }
}

/// Эмодзи, вписанный в клетку: глиф масштабируется под размер клетки.
class PanelEmojiGlyph extends LeafRenderObjectWidget {
  const PanelEmojiGlyph({
    super.key,
    required this.emoji,
    this.scale = .66,
    this.toneMark,
    this.fxDot,
  });

  final String emoji;

  /// Серая точка справа вверху: у эмодзи отдельным сообщением есть своя
  /// расширенная анимация на весь экран (23.11.2026). `null` — нет.
  final Color? fxDot;

  /// Доля стороны клетки под глиф (макет: 30 из 46).
  final double scale;

  /// Уголок «есть тон кожи» (правый нижний).
  final Color? toneMark;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPanelEmojiGlyph(emoji, scale, toneMark, fxDot);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderPanelEmojiGlyph renderObject,
  ) {
    renderObject
      ..emoji = emoji
      ..scale = scale
      ..toneMark = toneMark
      ..fxDot = fxDot;
  }
}

class RenderPanelEmojiGlyph extends RenderBox {
  RenderPanelEmojiGlyph(
    this._emoji,
    this._scale,
    this._toneMark, [
    this._fxDot,
  ]);

  String _emoji;
  double _scale;
  Color? _toneMark;
  Color? _fxDot;

  set fxDot(Color? v) {
    if (v == _fxDot) return;
    _fxDot = v;
    markNeedsPaint();
  }

  set emoji(String v) {
    if (v == _emoji) return;
    _emoji = v;
    markNeedsPaint();
  }

  set scale(double v) {
    if (v == _scale) return;
    _scale = v;
    markNeedsPaint();
  }

  set toneMark(Color? v) {
    if (v == _toneMark) return;
    _toneMark = v;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final side = size.shortestSide;
    // Округление до 0,5 — чтобы кеш не рос от дробных размеров клеток.
    final fs = ((side * _scale) * 2).roundToDouble() / 2;
    final tp = _GlyphCache.painter(_emoji, fs);
    final o =
        offset +
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2);
    tp.paint(context.canvas, o);
    final mark = _toneMark;
    if (mark != null) {
      // Треугольный уголок 5 × 5 (макет: border-left/bottom 5px).
      final r = offset.dx + size.width - 4;
      final b = offset.dy + size.height - 5;
      final path = Path()
        ..moveTo(r, b - 5)
        ..lineTo(r, b)
        ..lineTo(r - 5, b)
        ..close();
      context.canvas.drawPath(path, Paint()..color = mark);
    }
    final dot = _fxDot;
    if (dot != null) {
      // Точка Ø4 справа вверху клетки — «у этого эмодзи своя анимация».
      context.canvas.drawCircle(
        offset + Offset(size.width - 6, 6),
        2,
        Paint()..color = dot,
      );
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..label = _emoji
      ..textDirection = TextDirection.ltr
      ..isButton = true;
  }
}

// ─── Нажатие ────────────────────────────────────────────────────────────────

/// Пружина нажатия (×[pressedScale]), без борьбы жестов: слушает касания
/// через [Listener], жесты остаются у детей и родителей.
class PanelPress extends StatefulWidget {
  const PanelPress({
    super.key,
    required this.child,
    this.pressedScale = .86,
    this.curve = kPanelPressCurve,
    this.duration = const Duration(milliseconds: 300),
  });

  final Widget child;
  final double pressedScale;
  final Curve curve;
  final Duration duration;

  @override
  State<PanelPress> createState() => _PanelPressState();
}

class _PanelPressState extends State<PanelPress> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v || !mounted) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}

// ─── Островки и поиск ───────────────────────────────────────────────────────

/// Сколько места внизу страницы занимают плавающие островки: сетки кончаются
/// пустым отступом этой высоты, чтобы последний ряд выезжал над ними.
class PanelBottomInset extends InheritedWidget {
  const PanelBottomInset({super.key, required this.value, required super.child});

  final double value;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PanelBottomInset>()?.value ??
      0;

  @override
  bool updateShouldNotify(PanelBottomInset old) => old.value != value;
}

/// Отдельный островок поверх сетки: своё стекло (iPhone — жидкое, Android —
/// матовое), кант и мягкая тень. Размытие — `BackdropFilter.grouped`: все
/// островки одного [BackdropGroup] берут один снимок фона за кадр.
class PanelIsland extends StatelessWidget {
  const PanelIsland({
    super.key,
    required this.style,
    required this.radius,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final EmojiPanelStyle style;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = style;
    final r = BorderRadius.circular(radius);
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: s.islandFill,
        borderRadius: r,
        border: Border.all(color: s.islandEdge, width: s.ios ? .6 : .8),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (s.islandFilter != null) {
      body = ClipRRect(
        borderRadius: r,
        child: BackdropFilter.grouped(filter: s.islandFilter!, child: body),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: s.islandShadow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: body,
    );
  }
}

/// Поиск в верхней строке: в покое — значок лупы справа от рейки; по нажатию
/// пилюля выдвигается от значка влево на всю строку, рейка уезжает, слева
/// появляется «назад». [t] — ход выдвижения 0…1.
class PanelSearchBar extends StatelessWidget {
  const PanelSearchBar({
    super.key,
    required this.style,
    required this.t,
    required this.open,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onOpen,
    required this.onClose,
    required this.searchLabel,
    required this.closeLabel,
    this.fieldKey,
  });

  final EmojiPanelStyle style;
  final double t;
  final bool open;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final String searchLabel;
  final String closeLabel;
  final Key? fieldKey;

  static const double button = 36;
  static const double back = 36;
  static const double gap = 4;

  @override
  Widget build(BuildContext context) {
    final s = style;
    final tc = t.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, c) {
        final full = c.maxWidth - back - gap;
        // Немного «пружины» в ширине (t чуть выходит за 1), но не шире строки.
        final w = (button + (full - button) * t).clamp(button, full);
        final backOpacity = ((tc - .35) / .65).clamp(0.0, 1.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: back,
              child: IgnorePointer(
                ignoring: !open,
                child: Opacity(
                  opacity: backOpacity,
                  child: Transform.translate(
                    offset: Offset(14 * (1 - tc), 0),
                    child: Semantics(
                      button: true,
                      label: closeLabel,
                      child: GestureDetector(
                        key: const ValueKey('emoji-panel:search-close'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onClose,
                        child: PanelPress(
                          child: Icon(
                            s.ios
                                ? Icons.arrow_back_ios_new_rounded
                                : Icons.arrow_back_rounded,
                            size: s.ios ? 19 : 22,
                            color: s.hdr,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: w,
              child: Semantics(
                button: !open,
                label: open ? null : searchLabel,
                child: GestureDetector(
                  key: const ValueKey('emoji-panel:search'),
                  behavior: HitTestBehavior.opaque,
                  onTap: open ? () => focusNode.requestFocus() : onOpen,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        s.pill.withValues(alpha: 0),
                        s.pill,
                        tc,
                      ),
                      borderRadius: BorderRadius.circular(button / 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    // Строка поиска сразу полной ширины, пилюля лишь
                    // приоткрывает её: при выдвижении ничего не
                    // перекладывается и не переполняется.
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: full,
                      maxWidth: full,
                      child: Row(
                      children: [
                        SizedBox(
                          width: button,
                          height: button,
                          child: Icon(
                            Icons.search_rounded,
                            size: 22 - 2 * tc,
                            color: Color.lerp(s.hdr, s.muted, tc),
                          ),
                        ),
                        if (open || tc > .001)
                          Expanded(
                            child: Opacity(
                              opacity: ((tc - .3) / .7).clamp(0.0, 1.0),
                              child: TextField(
                                key: fieldKey,
                                controller: controller,
                                focusNode: focusNode,
                                onChanged: onChanged,
                                textInputAction: TextInputAction.search,
                                cursorColor: s.primary,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: s.text,
                                  height: 1.2,
                                ),
                                decoration: InputDecoration(
                                  hintText: hint,
                                  hintStyle: TextStyle(
                                    fontSize: 15,
                                    color: s.muted,
                                  ),
                                  hintMaxLines: 1,
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (open)
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: controller,
                            builder: (context, v, _) {
                              if (v.text.isEmpty) {
                                return const SizedBox(width: 10);
                              }
                              return GestureDetector(
                                key: const ValueKey('emoji-panel:search-clear'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  controller.clear();
                                  onChanged('');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
                                  child: Icon(
                                    Icons.cancel_rounded,
                                    size: 18,
                                    color: s.muted,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Заголовок раздела эмодзи: прописные 12/650, приглушённый.
class PanelSectionLabel extends StatelessWidget {
  const PanelSectionLabel({super.key, required this.text, required this.style});

  final String text;
  final EmojiPanelStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: .48,
          color: style.muted,
        ),
      ),
    );
  }
}

// ─── Полёт ──────────────────────────────────────────────────────────────────

/// Полёт из клетки в поле (эмодзи) или в чат (стикер): одна [OverlayEntry]
/// с [Transform], сетка не перестраивается.
///
/// Эмодзи: дуга вверх, ×1,35 на середине, к полю — ×0,5 и гаснет.
/// Стикер: ×1,5 на середине, к чату — ×1,9 и гаснет (`fly()` макета).
void launchPanelFlight({
  required BuildContext context,
  required Rect from,
  required Offset to,
  required Widget child,
  bool big = false,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final box = overlay.context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return;
  final local = Rect.fromPoints(
    box.globalToLocal(from.topLeft),
    box.globalToLocal(from.bottomRight),
  );
  final target = box.globalToLocal(to);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Flight(
      from: local,
      to: target,
      big: big,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
      child: child,
    ),
  );
  overlay.insert(entry);
}

class _Flight extends StatefulWidget {
  const _Flight({
    required this.from,
    required this.to,
    required this.big,
    required this.onDone,
    required this.child,
  });

  final Rect from;
  final Offset to;
  final bool big;
  final VoidCallback onDone;
  final Widget child;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.big ? 460 : 400),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.from;
    final d = widget.to - f.center;
    final big = widget.big;
    return Positioned(
      left: f.left,
      top: f.top,
      width: f.width,
      height: f.height,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          child: widget.child,
          builder: (context, child) {
            final t = kPanelFlightCurve.transform(_c.value);
            // Две части: до середины (45 %) — вверх по дуге, дальше — к цели.
            const mid = .45;
            Offset o;
            double s;
            double op;
            if (t <= mid) {
              final k = t / mid;
              o = Offset(d.dx * .45 * k, (d.dy * .45 - 50) * k);
              s = 1 + ((big ? 1.5 : 1.35) - 1) * k;
              op = 1;
            } else {
              final k = (t - mid) / (1 - mid);
              final a = Offset(d.dx * .45, d.dy * .45 - 50);
              o = Offset.lerp(a, d, k)!;
              final s0 = big ? 1.5 : 1.35;
              s = s0 + ((big ? 1.9 : .5) - s0) * k;
              op = 1 - (1 - (big ? 0 : .15)) * k;
            }
            return Opacity(
              opacity: op.clamp(0, 1),
              child: Transform.translate(
                offset: o,
                child: Transform.scale(scale: s, child: child),
              ),
            );
          },
        ),
      ),
    );
  }
}
