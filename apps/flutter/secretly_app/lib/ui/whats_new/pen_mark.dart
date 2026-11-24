// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Пометки пером (макет «Whats New 1.9», разделы D–F): неровный круг «от
/// руки» вокруг новинки, подпись и стрелка. Один раз на человека; касание в
/// любом месте — пометка растворяется (касание проходит дальше).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../motion/motion.dart';
import 'whats_new_flow.dart';

const Curve _penCurve = Cubic(0.55, 0.10, 0.35, 1);
const Curve _eIn = Cubic(0.2, 0.8, 0.2, 1);
const Curve _eOut = Cubic(0.4, 0, 1, 1);

/// Подписи пометок.
enum PenHint { search, style, panels, covers, emoji, reactions }

String penHintText(AppLocalizations? l, PenHint h) => switch (h) {
  PenHint.search => l?.penHintSearch ?? 'Search by username and contacts',
  PenHint.style => l?.penHintStyle ?? 'Theme, wallpaper, bubbles, icon',
  PenHint.panels => l?.penHintPanels ?? 'See-through or solid',
  PenHint.covers => l?.penHintCovers ?? 'Live covers',
  PenHint.emoji => l?.penHintEmoji ?? 'Emoji, stickers, GIFs',
  PenHint.reactions => l?.penHintReactions ?? 'Long-press to react',
};

/// Зерно рисунка каждой пометки (как в макете) — форма одна и та же при
/// каждом показе.
int _seedOf(PenHint h) => switch (h) {
  PenHint.search => 11,
  PenHint.style => 23,
  PenHint.panels => 37,
  PenHint.covers => 41,
  PenHint.emoji => 53,
  PenHint.reactions => 67,
};

/// Оборачивает новинку: если пометку ещё не видели, через 400 мс после
/// появления экрана вокруг элемента рисуется перо.
class PenMark extends StatefulWidget {
  const PenMark({
    super.key,
    required this.hint,
    required this.child,
    this.round = false,
    this.enabled = true,
  });

  final PenHint hint;
  final Widget child;

  /// Круглый якорь (кнопка) — круг, а не эллипс.
  final bool round;
  final bool enabled;

  @override
  State<PenMark> createState() => _PenMarkState();
}

/// Одна пометка на экране за раз.
PenHint? _showing;

class _PenMarkState extends State<PenMark> with TickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  AnimationController? _draw;
  AnimationController? _fade;
  Timer? _timer;
  bool _routed = false;

  String get _prefKey => 'pen_${widget.hint.name}_seen_v1';

  @override
  void initState() {
    super.initState();
    if (!widget.enabled || !kPenMarks || !WhatsNew19.active) return;
    WhatsNew19.tourSettled.addListener(_schedule);
    _schedule();
  }

  void _schedule() {
    if (!WhatsNew19.tourSettled.value || _entry != null) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), _tryShow);
  }

  Future<void> _tryShow() async {
    if (!mounted || _entry != null || _showing != null) return;
    if (WhatsNew19.sheetOpen.value) return;
    final route = ModalRoute.of(context);
    if (route != null &&
        (!route.isCurrent || route.animation?.status != AnimationStatus.completed)) {
      // Экран ещё въезжает или накрыт другим — попробуем позже.
      _timer = Timer(const Duration(milliseconds: 600), _tryShow);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || prefs.getBool(_prefKey) == true) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;
    final media = MediaQuery.of(context);
    final topLeft = box.localToGlobal(Offset.zero);
    final screen = Offset.zero & media.size;
    // Только если элемент виден целиком.
    if (!screen.contains(topLeft) ||
        !screen.contains(topLeft + box.size.bottomRight(Offset.zero))) {
      return;
    }
    await prefs.setBool(_prefKey, true);
    if (!mounted || _showing != null) return;
    _show(box.size, topLeft, media.size);
  }

  void _show(Size size, Offset global, Size screen) {
    final reduced = motionReduced(context);
    final theme = Theme.of(context);
    final ink = theme.colorScheme.primary;
    final bg = theme.scaffoldBackgroundColor;
    final caption = penHintText(AppLocalizations.of(context), widget.hint);
    _draw = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: reduced ? 200 : 1010),
    );
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1,
    );
    final geo = _PenGeometry.build(
      size: size,
      round: widget.round,
      seed: _seedOf(widget.hint),
      global: global,
      screen: screen,
      caption: caption,
      textStyle: _captionStyle(ink, bg),
    );
    _showing = widget.hint;
    _entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            child: Align(
              alignment: Alignment.topLeft,
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _fade!, curve: _eOut),
                child: AnimatedBuilder(
                  animation: _draw!,
                  builder: (context, _) {
                    final ms = _draw!.value * (reduced ? 1010 : 1010);
                    final pen = reduced
                        ? 1.0
                        : _penCurve.transform((ms / 600).clamp(0.0, 1.0));
                    final tail = reduced
                        ? 1.0
                        : _eIn.transform(((ms - 750) / 260).clamp(0.0, 1.0));
                    final fadeIn = reduced ? _draw!.value : 1.0;
                    return Opacity(
                      opacity: fadeIn,
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _PenPainter(
                                    geo: geo,
                                    pen: pen,
                                    arrow: tail,
                                    ink: ink,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: geo.captionOffset.dx,
                              top: geo.captionOffset.dy,
                              child: Opacity(
                                opacity: tail,
                                child: Transform.translate(
                                  offset: Offset(0, 4 * (1 - tail)),
                                  child: Transform.rotate(
                                    angle: -3 * math.pi / 180,
                                    child: Text(
                                      caption,
                                      style: _captionStyle(ink, bg),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
    _draw!.forward();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _routed = true;
  }

  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent) _dismiss();
  }

  Future<void> _dismiss() async {
    if (_routed) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
      _routed = false;
    }
    final fade = _fade;
    if (fade == null) return;
    await fade.reverse();
    _remove();
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
    if (_showing == widget.hint) _showing = null;
  }

  TextStyle _captionStyle(Color ink, Color bg) => TextStyle(
    fontFamily: 'Kalam',
    fontSize: 19,
    height: 26 / 19,
    fontWeight: FontWeight.w600,
    color: ink,
    decoration: TextDecoration.none,
    // Ореол цвета фона (2/4/8 по макету + плотнее), чтобы подпись читалась
    // поверх строк списка.
    shadows: [
      Shadow(color: bg, blurRadius: 2),
      Shadow(color: bg, blurRadius: 4),
      Shadow(color: bg, blurRadius: 8),
      Shadow(color: bg, blurRadius: 12),
      Shadow(color: bg, blurRadius: 16),
    ],
  );

  @override
  void dispose() {
    _timer?.cancel();
    WhatsNew19.tourSettled.removeListener(_schedule);
    if (_routed) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    }
    _remove();
    _draw?.dispose();
    _fade?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CompositedTransformTarget(link: _link, child: widget.child);
}

/// Геометрия пометки в координатах элемента (0,0 — его левый верхний угол).
class _PenGeometry {
  _PenGeometry(this.points, this.widths, this.arrow, this.captionOffset);

  final List<Offset> points;
  final List<double> widths;
  final Path arrow;
  final Offset captionOffset;

  static _PenGeometry build({
    required Size size,
    required bool round,
    required int seed,
    required Offset global,
    required Size screen,
    required String caption,
    required TextStyle textStyle,
  }) {
    final r = _Mulberry(seed);
    final cx = size.width / 2 + (r.next() - 0.5) * 4;
    final cy = size.height / 2 + (r.next() - 0.5) * 4;
    double rx, ry;
    if (round) {
      rx = ry = math.max(size.width, size.height) / 2 + 12;
    } else {
      rx = size.width / 2 + 14;
      ry = size.height / 2 + 12;
    }
    const k = 8;
    final jit = [for (var i = 0; i < k; i++) 1 + (r.next() * 2 - 1) * 0.06];
    final ph = r.next() * math.pi * 2;
    const tilt = -4 * math.pi / 180;
    const st = -35 * math.pi / 180;
    const sw = -(2 * math.pi + 18 * math.pi / 180);
    const n = 120;
    final pts = <Offset>[];
    final ws = <double>[];
    for (var i = 0; i <= n; i++) {
      final u = i / n;
      final th = st + sw * u;
      final pos = ((-th) % (2 * math.pi) + 2 * math.pi) % (2 * math.pi) /
          (2 * math.pi) *
          k;
      final i0 = pos.floor();
      final fr = pos - i0;
      final s = (1 - math.cos(fr * math.pi)) / 2;
      final jf = jit[i0 % k] * (1 - s) + jit[(i0 + 1) % k] * s;
      final f = jf * (1 + 0.07 * u) * (1 + 0.012 * math.sin(6 * math.pi * u + ph));
      final x0 = rx * f * math.cos(th), y0 = ry * f * math.sin(th);
      pts.add(Offset(
        cx + x0 * math.cos(tilt) - y0 * math.sin(tilt),
        cy + x0 * math.sin(tilt) + y0 * math.cos(tilt),
      ));
      ws.add(1.4 + 1.8 * math.pow(math.sin(math.pi * u), 0.55));
    }
    // Подпись: под элементом, если он в верхней половине экрана, иначе над.
    final tp = TextPainter(
      text: TextSpan(text: caption, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final below = global.dy + cy < screen.height * 0.55;
    final capTop = below ? cy + ry + 34 : cy - ry - 34 - tp.height;
    var capLeftGlobal = global.dx + cx - tp.width * 0.35;
    capLeftGlobal = capLeftGlobal
        .clamp(12.0, math.max(12.0, screen.width - 12 - tp.width))
        .toDouble();
    final capLeft = capLeftGlobal - global.dx;
    // Стрелка — от подписи к краю пера, с изгибом и двумя «усами».
    final startX = (capLeft + tp.width * 0.3).clamp(cx - rx, cx + rx).toDouble();
    final start = Offset(startX, below ? capTop - 4 : capTop + tp.height + 4);
    final end = Offset(
      cx + rx * 0.25,
      below ? cy + ry * 1.02 + 6 : cy - ry * 1.02 - 6,
    );
    final ctrl = Offset(
      (start.dx + end.dx) / 2 + 14,
      (start.dy + end.dy) / 2,
    );
    var ux = end.dx - ctrl.dx, uy = end.dy - ctrl.dy;
    final ul = math.sqrt(ux * ux + uy * uy);
    ux /= ul;
    uy /= ul;
    Offset head(double a) => Offset(
      end.dx - 8 * (ux * math.cos(a) - uy * math.sin(a)),
      end.dy - 8 * (ux * math.sin(a) + uy * math.cos(a)),
    );
    final arrow = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy)
      ..moveTo(head(0.49).dx, head(0.49).dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo(head(-0.49).dx, head(-0.49).dy);
    return _PenGeometry(pts, ws, arrow, Offset(capLeft, capTop));
  }
}

class _PenPainter extends CustomPainter {
  _PenPainter({
    required this.geo,
    required this.pen,
    required this.arrow,
    required this.ink,
  });

  final _PenGeometry geo;
  final double pen;
  final double arrow;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ink.withValues(alpha: 0.95);
    final pts = geo.points;
    final n = pts.length - 1;
    final last = (pen * n).clamp(0.0, n.toDouble());
    final upto = last.floor();
    if (last > 0) {
      // Лента: левый край туда, правый обратно (толщина w(u)).
      final left = <Offset>[], right = <Offset>[];
      for (var i = 0; i <= upto + 1 && i <= n; i++) {
        var p = pts[i];
        var w = geo.widths[i];
        if (i == upto + 1) {
          final t = last - upto;
          p = Offset.lerp(pts[upto], pts[i], t)!;
          w = geo.widths[upto] + (geo.widths[i] - geo.widths[upto]) * t;
        }
        final a = pts[math.max(0, i - 1)], b = pts[math.min(n, i + 1)];
        var dx = b.dx - a.dx, dy = b.dy - a.dy;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len > 0) {
          dx /= len;
          dy /= len;
        }
        left.add(Offset(p.dx - dy * w / 2, p.dy + dx * w / 2));
        right.add(Offset(p.dx + dy * w / 2, p.dy - dx * w / 2));
      }
      final path = Path()..addPolygon([...left, ...right.reversed], true);
      canvas.drawPath(path, paint);
      canvas.drawCircle(pts.first, geo.widths.first / 2, paint);
      canvas.drawCircle(
        right.isEmpty ? pts.first : Offset.lerp(left.last, right.last, 0.5)!,
        geo.widths[math.min(upto, n)] / 2,
        paint,
      );
    }
    if (arrow > 0) {
      final out = Path();
      for (final m in geo.arrow.computeMetrics()) {
        out.addPath(m.extractPath(0, m.length * arrow), Offset.zero);
      }
      canvas.drawPath(
        out,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = ink.withValues(alpha: 0.95),
      );
    }
  }

  @override
  bool shouldRepaint(_PenPainter old) =>
      old.pen != pen || old.arrow != arrow || old.ink != ink;
}

class _Mulberry {
  _Mulberry(int seed) : _a = seed;
  int _a;

  double next() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _imul(_a ^ (_a >>> 15), 1 | _a);
    t = ((t + _imul(t ^ (t >>> 7), 61 | t)) & 0xFFFFFFFF) ^ t;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
  }

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;
}
