// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Окно «Встречайте Secretly 1.9» и мини-демо «Что нового» — по
/// спецификации макета (разделы A–C, F, G). Все числа — pt экрана 390×844;
/// сцены карточек рисуются в этих координатах и уменьшаются вместе со
/// снимком (FittedBox → превью 212×459).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../motion/motion.dart';
import '../profile/s_mark_shape.dart';

// ── A. Кривые ──────────────────────────────────────────────────────────────
const Curve _eIn = Cubic(0.2, 0.8, 0.2, 1);
const Curve _eOut = Cubic(0.4, 0, 1, 1);
const Curve _pop = Motion.pop;
const Curve _std = Motion.standard;
const Curve _sheetCurve = Motion.sheet;

/// Одна карточка демо.
const int kWhatsNewCardMs = 4500;
const int _kCards = 6;

class WhatsNewSheet extends StatefulWidget {
  const WhatsNewSheet({
    super.key,
    this.backdrop,
    this.startWithDemo = false,
  });

  /// Размытый снимок главного экрана (или `null` — простое затемнение).
  final ui.Image? backdrop;
  final bool startWithDemo;

  @override
  State<WhatsNewSheet> createState() => _WhatsNewSheetState();
}

enum _Mode { welcome, demo, closing }

class _WhatsNewSheetState extends State<WhatsNewSheet>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  late final AnimationController _scrim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1480),
  );
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  /// Часы текущей карточки: задержка старта + 4,5 с. Ими же движутся
  /// сцены — удержание пальцем ставит на паузу и таймер, и движение.
  late final AnimationController _clock = AnimationController(vsync: this);
  late final AnimationController _close = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  final GlobalKey _welcomeKey = GlobalKey();
  double? _welcomeH;
  _Mode _mode = _Mode.welcome;
  int _card = 0;
  int _clockBase = 350;
  double _drag = 0;
  late final PageController _pages = PageController();
  bool _autoPaging = false;
  bool _rm = false;

  @override
  void initState() {
    super.initState();
    _clock.addStatusListener((s) {
      if (s == AnimationStatus.completed && _mode == _Mode.demo) {
        if (_card < _kCards - 1) _goCard(_card + 1);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rm = motionReduced(context);
      _scrim.forward();
      _enter.forward();
      if (widget.startWithDemo) {
        _openDemo(fromWelcome: false);
      } else {
        _intro.forward();
      }
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _scrim.dispose();
    _intro.dispose();
    _morph.dispose();
    _clock.dispose();
    _close.dispose();
    _pages.dispose();
    super.dispose();
  }

  // ── Переходы ─────────────────────────────────────────────────────────────

  void _openDemo({bool fromWelcome = true}) {
    final box = _welcomeKey.currentContext?.findRenderObject() as RenderBox?;
    _welcomeH = box?.hasSize == true ? box!.size.height : _welcomeH;
    setState(() => _mode = _Mode.demo);
    if (fromWelcome) {
      _morph.forward(from: 0);
    } else {
      _morph.value = 1;
    }
    _card = 0;
    _startClock(350);
  }

  void _startClock(int baseMs) {
    _clockBase = baseMs;
    _clock.duration = Duration(milliseconds: kWhatsNewCardMs + baseMs);
    _clock.forward(from: 0);
  }

  Future<void> _goCard(int i) async {
    i = i.clamp(0, _kCards - 1);
    setState(() => _card = i);
    _startClock(120);
    if (!_pages.hasClients) return;
    _autoPaging = true;
    try {
      if (_rm) {
        _pages.jumpToPage(i);
      } else {
        await _pages.animateToPage(
          i,
          duration: const Duration(milliseconds: 320),
          curve: _std,
        );
      }
    } finally {
      _autoPaging = false;
    }
  }

  void _onPageChanged(int i) {
    if (_autoPaging || i == _card) return;
    setState(() => _card = i);
    _startClock(120);
  }

  void _next() {
    if (_card < _kCards - 1) {
      _goCard(_card + 1);
    } else {
      _closeSheet();
    }
  }

  Future<void> _closeSheet() async {
    if (_mode == _Mode.closing) return;
    setState(() => _mode = _Mode.closing);
    _clock.stop();
    unawaited(_scrim.reverse());
    await _close.forward();
    if (mounted) Navigator.of(context).pop();
  }

  // ── Свайп окна вниз (только приветствие) ─────────────────────────────────

  void _onDragUpdate(DragUpdateDetails d) {
    if (_mode != _Mode.welcome) return;
    setState(() {
      final next = _drag + d.delta.dy;
      _drag = next > 0 ? next : _drag + d.delta.dy * 0.2;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (_mode != _Mode.welcome) return;
    final v = d.primaryVelocity ?? 0;
    if (_drag > 110 || v > 800) {
      _closeSheet();
      return;
    }
    final from = _drag;
    final back = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final anim = CurvedAnimation(parent: back, curve: _eIn);
    anim.addListener(() {
      if (mounted) setState(() => _drag = from * (1 - anim.value));
    });
    back.forward().whenComplete(() {
      anim.dispose();
      back.dispose();
    });
  }

  // ── Сборка ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final screen = mq.size;
    final demoTop = math.max(62.0, mq.padding.top + 8);
    final demoH = math.max(320.0, screen.height - demoTop - 8);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSheet();
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Подложка + затемнение.
            Positioned.fill(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _scrim,
                  curve: _eIn,
                  reverseCurve: _eOut,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.backdrop != null)
                      RawImage(image: widget.backdrop, fit: BoxFit.cover),
                    ColoredBox(
                      color: dark
                          ? const Color(0x73000000)
                          : const Color(0x2E000000),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: AnimatedBuilder(
                animation: Listenable.merge([_enter, _morph, _close]),
                builder: (context, child) {
                  final e = _rm ? _enter.value : _eIn.transform(_enter.value);
                  final closeDy = _close.value == 0
                      ? 0.0
                      : _eOut.transform(_close.value) *
                            ((_mode == _Mode.demo || _morph.value > 0)
                                    ? demoH
                                    : (_welcomeH ?? 440)) +
                            40 * _close.value;
                  final dy = (_rm ? 0 : 48 * (1 - e)) + _drag + closeDy;
                  final m = _rm ? _morph.value : _std.transform(_morph.value);
                  double? h;
                  if (_mode != _Mode.welcome || _morph.value > 0) {
                    final from = _welcomeH ?? demoH;
                    h = from + (demoH - from) * m;
                  }
                  return Opacity(
                    opacity: (_rm && _close.value > 0)
                        ? (1 - _close.value)
                        : e.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, _rm ? _drag : dy),
                      child: SizedBox(height: h, child: child),
                    ),
                  );
                },
                child: GestureDetector(
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  child: _SheetSurface(
                    dark: dark,
                    child: _mode == _Mode.welcome && _morph.value == 0
                        ? _buildWelcome(context)
                        : Stack(
                            children: [
                              if (_morph.value < 1)
                                FadeTransition(
                                  opacity: ReverseAnimation(
                                    CurvedAnimation(
                                      parent: _morph,
                                      curve: const Interval(0, 0.44, curve: _eOut),
                                    ),
                                  ),
                                  child: IgnorePointer(
                                    child: SingleChildScrollView(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      child: _buildWelcome(context),
                                    ),
                                  ),
                                ),
                              FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: _morph,
                                  curve: const Interval(0.55, 1, curve: _eIn),
                                ),
                                child: _buildDemo(context, demoH),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── B. Приветствие ───────────────────────────────────────────────────────

  Widget _buildWelcome(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final acc = theme.colorScheme.primary;
    final tx = dark ? const Color(0xFFE2E6EA) : const Color(0xFF111418);
    final tx2 = dark ? const Color(0x99EBEBF5) : const Color(0x993C3C43);

    Widget stagger(int delayMs, Widget child) => AnimatedBuilder(
      animation: _intro,
      builder: (context, c) {
        final t = _seg(_intro.value * 1480, delayMs, 320, _rm ? Curves.linear : _eIn);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, _rm ? 0 : 8 * (1 - t)),
            child: c,
          ),
        );
      },
      child: child,
    );

    return Column(
      key: _welcomeKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        _Grabber(dark: dark),
        const SizedBox(height: 8),
        SizedBox(
          height: 156,
          child: AnimatedBuilder(
            animation: _intro,
            builder: (context, _) {
              final ms = _intro.value * 1480;
              final g = _seg(ms, _rm ? 0 : 600, _rm ? 200 : 600, _eIn);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: g,
                    child: Transform.scale(
                      scale: _rm ? 1 : 0.7 + 0.3 * g,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              acc.withValues(alpha: dark ? 0.30 : 0.22),
                              acc.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 112 * kSMarkAspect,
                    height: 112,
                    child: CustomPaint(
                      painter: SMarkDrawPainter(
                        ms: _rm ? 1480 : ms,
                        stroke: acc,
                        fill: tx,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: stagger(
            1000,
            Text(
              l?.whatsNewTitle ?? 'Meet Secretly 1.9',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 28,
                height: 34 / 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: tx,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: stagger(
            1080,
            Text(
              l?.whatsNewSubtitle ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, height: 22 / 17, color: tx2),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: stagger(
            1160,
            Column(
              children: [
                _PressScale(
                  onTap: () => _openDemo(),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: acc,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Text(
                      l?.whatsNewOpen ?? 'What’s new',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _PressScale(
                  onTap: _closeSheet,
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        l?.whatsNewLater ?? 'Later',
                        style: TextStyle(fontSize: 17, color: acc),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── C. Мини-демо ─────────────────────────────────────────────────────────

  Widget _buildDemo(BuildContext context, double demoH) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final acc = theme.colorScheme.primary;
    final tx = dark ? const Color(0xFFE2E6EA) : const Color(0xFF111418);
    final tx2 = dark ? const Color(0x99EBEBF5) : const Color(0x993C3C43);
    final titles = [
      l?.whatsNewCard1Title, l?.whatsNewCard2Title, l?.whatsNewCard3Title,
      l?.whatsNewCard4Title, l?.whatsNewCard5Title, l?.whatsNewCard6Title,
    ];
    final bodies = [
      l?.whatsNewCard1Body, l?.whatsNewCard2Body, l?.whatsNewCard3Body,
      l?.whatsNewCard4Body, l?.whatsNewCard5Body, l?.whatsNewCard6Body,
    ];
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  l?.whatsNewHeader ?? 'What’s new in 1.9',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tx2,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: l?.whatsNewClose ?? 'Close',
                child: _PressScale(
                  onTap: _closeSheet,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dark
                          ? const Color(0x3D767680)
                          : const Color(0x1F767680),
                    ),
                    child: Icon(Icons.close_rounded, size: 18, color: tx2),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        Expanded(
          child: Listener(
            onPointerDown: (_) => _clock.stop(),
            onPointerUp: (_) => _resumeIfSame(),
            onPointerCancel: (_) => _resumeIfSame(),
            child: PageView.builder(
              controller: _pages,
              onPageChanged: _onPageChanged,
              itemCount: _kCards,
              itemBuilder: (context, i) => Column(
                children: [
                  const SizedBox(height: 4),
                  // Превью уступает место тексту: на низком экране или при
                  // крупном шрифте уменьшается, пропорции сохраняются.
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 459),
                      child: AspectRatio(
                        aspectRatio: 212 / 459,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final r = 26 * box.maxHeight / 459;
                            return DecoratedBox(
                              position: DecorationPosition.foreground,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(r),
                                border: Border.all(
                                  width: 0.5,
                                  color: dark
                                      ? const Color(0x1FFFFFFF)
                                      : const Color(0x14000000),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(r),
                                child: FittedBox(
                                  fit: BoxFit.fill,
                                  child: SizedBox(
                                    width: 390,
                                    height: 844,
                                    child: AnimatedBuilder(
                                      animation: _clock,
                                      builder: (context, _) => _CardScene(
                                        index: i,
                                        ms: i == _card
                                            ? _clock.value *
                                                      (kWhatsNewCardMs +
                                                          _clockBase) -
                                                  _clockBase
                                            : (i < _card ? 99999 : -1),
                                        dark: dark,
                                        accent: acc,
                                        reduced: _rm,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      titles[i] ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 22,
                        height: 28 / 22,
                        fontWeight: FontWeight.w600,
                        color: tx,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      bodies[i] ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      style: TextStyle(fontSize: 15, height: 20 / 15, color: tx2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _clock,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var j = 0; j < _kCards; j++) ...[
                if (j > 0) const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _goCard(j),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: _std,
                    width: j == _card ? 18 : 6,
                    height: 6,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: j == _card
                          ? acc.withValues(alpha: dark ? 0.16 : 0.12)
                          : tx.withValues(alpha: dark ? 0.25 : 0.20),
                    ),
                    alignment: Alignment.centerLeft,
                    child: j == _card
                        ? FractionallySizedBox(
                            widthFactor: ((_clock.value *
                                            (kWhatsNewCardMs + _clockBase) -
                                        _clockBase) /
                                    kWhatsNewCardMs)
                                .clamp(0.0, 1.0),
                            child: ColoredBox(color: acc),
                          )
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _PressScale(
            onTap: _next,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: acc,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Text(
                _card == _kCards - 1
                    ? (l?.whatsNewStart ?? 'Get started')
                    : (l?.whatsNewNext ?? 'Next'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _resumeIfSame() {
    if (_mode != _Mode.demo) return;
    // Если палец перелистнул карточку, часы уже перезапущены.
    if (!_clock.isAnimating && _clock.value < 1) _clock.forward();
  }
}

/// Доля отрезка [delay, delay + dur] по кривой.
double _seg(double ms, int delay, int dur, Curve curve) {
  if (ms <= delay) return 0;
  if (ms >= delay + dur) return 1;
  return curve.transform((ms - delay) / dur);
}

// ── Поверхность окна ───────────────────────────────────────────────────────

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.dark, required this.child});

  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Плотная плашка: на подложке уже размытый снимок, своё размытие
        // в каждом кадре не нужно (раздел G).
        color: dark ? const Color(0xF21C1C1F) : const Color(0xF7F5F5F7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          width: 0.5,
          color: dark ? const Color(0x1FFFFFFF) : const Color(0xB3FFFFFF),
        ),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: child,
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 5,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(2.5),
      color: dark ? const Color(0x4DEBEBF5) : const Color(0x4D3C3C43),
    ),
  );
}

/// Нажатие — scale 0.97 за 200 мс (MotionDurations.press).
class _PressScale extends StatefulWidget {
  const _PressScale({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: MotionDurations.press,
        curve: _eIn,
        child: widget.child,
      ),
    );
  }
}

// ── Знак S: гребни прорисовываются и заливаются ───────────────────────────

/// 9 контуров `kSMarkContours`: обводка 0→100 % длины за 520 мс (E_in) с
/// 120 + i·45 мс, за следующие 320 мс гаснет; заливка 0→1 за 260 мс с
/// 560 + i·45 мс. Знак готов ≈ 1180 мс.
class SMarkDrawPainter extends CustomPainter {
  SMarkDrawPainter({required this.ms, required this.stroke, required this.fill});

  final double ms;
  final Color stroke;
  final Color fill;

  static List<Path>? _unit;

  static List<Path> _paths() => _unit ??= [
    for (final c in kSMarkContours)
      () {
        final p = Path()..moveTo(c[0], c[1]);
        for (var i = 2; i + 1 < c.length; i += 2) {
          p.lineTo(c[i], c[i + 1]);
        }
        return p..close();
      }(),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height; // доли большей стороны (высоты)
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s, s);
    final paths = _paths();
    for (var i = 0; i < paths.length; i++) {
      final t0 = 120 + i * 45.0;
      final draw = ((ms - t0) / 520).clamp(0.0, 1.0);
      final fade = ((ms - t0 - 520) / 320).clamp(0.0, 1.0);
      final fillT = ((ms - (560 + i * 45)) / 260).clamp(0.0, 1.0);
      if (fillT > 0) {
        canvas.drawPath(
          paths[i],
          Paint()..color = fill.withValues(alpha: fill.a * _eIn.transform(fillT)),
        );
      }
      if (draw > 0 && fade < 1) {
        final p = _eIn.transform(draw);
        final out = Path();
        for (final m in paths[i].computeMetrics()) {
          out.addPath(m.extractPath(0, m.length * p), Offset.zero);
        }
        canvas.drawPath(
          out,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 1.2 / s
            ..color = stroke.withValues(alpha: stroke.a * (1 - fade)),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SMarkDrawPainter old) =>
      old.ms != ms || old.stroke != stroke || old.fill != fill;
}

// ── Сцены карточек (координаты экрана 390×844) ─────────────────────────────

String _shot(String name, bool dark) =>
    'assets/whats_new/shot_${name}_${dark ? 'dark' : 'light'}.jpg';

class _CardScene extends StatelessWidget {
  const _CardScene({
    required this.index,
    required this.ms,
    required this.dark,
    required this.accent,
    required this.reduced,
  });

  final int index;

  /// Время от начала карточки; < 0 — ещё не началась, большое — прошла.
  final double ms;
  final bool dark;
  final Color accent;
  final bool reduced;

  /// Отрезок движения; при «уменьшить движение» — растворение 200 мс с
  /// начала отрезка.
  double t(int delay, int dur, [Curve curve = _eIn]) => reduced
      ? _seg(ms, delay, 200, Curves.linear)
      : _seg(ms, delay, dur, curve);

  Widget img(String name) => Image.asset(
    _shot(name, dark),
    width: 390,
    height: 844,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    filterQuality: FilterQuality.medium,
    errorBuilder: _noShot,
  );

  Color get soft => accent.withValues(alpha: dark ? 0.16 : 0.12);

  /// Строка состояния снимка — неподвижна, как на настоящем телефоне:
  /// под ней едут экраны, а время и значки не двоятся.
  Widget statusStrip(String name) => Positioned(
    left: 0,
    top: 0,
    width: 390,
    height: 47,
    child: ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 844,
        maxHeight: 844,
        child: img(name),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return switch (index) {
      0 => _notification(context),
      1 => _freshLook(),
      2 => _style(),
      3 => _profile(),
      4 => _messages(),
      _ => _emotions(),
    };
  }

  // 1 · из уведомления: баннер сверху → чат на первом непрочитанном.
  Widget _notification(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bannerIn = t(300, 420);
    final bannerOut = t(1500, 260, _eOut);
    final homeOut = t(1550, 320, _eOut);
    final chatIn = t(1550, 420, _std);
    final band = t(1900, 320);
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Opacity(
          opacity: 1 - homeOut,
          child: Transform.scale(
            scale: reduced ? 1 : 1 + 0.03 * homeOut,
            child: img('home'),
          ),
        ),
        if (chatIn > 0)
          Opacity(
            opacity: chatIn,
            child: Transform.translate(
              offset: Offset(0, reduced ? 0 : 48 * (1 - chatIn)),
              child: img('chat_unread'),
            ),
          ),
        // Полоса «Непрочитанные» на снимке — около y 340…365.
        if (band > 0)
          Positioned(
            left: 0,
            right: 0,
            top: 338,
            height: 30,
            child: Opacity(
              opacity: band,
              child: Transform.scale(
                scaleX: reduced ? 1 : 0.6 + 0.4 * band,
                child: ColoredBox(color: soft),
              ),
            ),
          ),
        statusStrip('home'),
        if (bannerIn > 0 && bannerOut < 1)
          Positioned(
            left: 8,
            top: reduced ? 62 : -100 + 162 * bannerIn,
            width: 374,
            height: 72,
            child: Opacity(
              opacity: bannerIn * (1 - bannerOut),
              child: Transform.scale(
                scale: 1 - 0.06 * bannerOut,
                child: _NotifBanner(
                  dark: dark,
                  sender: l?.whatsNewDemoSender ?? 'Alice',
                  message: l?.whatsNewDemoMessage ?? '',
                  now: l?.whatsNewDemoNow ?? 'now',
                ),
              ),
            ),
          ),
        if (!reduced) _finger(173, 76 + 62, 1100),
      ],
    );
  }

  // 2 · новый вид: рамки вокруг островков.
  Widget _freshLook() {
    Widget frame(double x, double y, double w, double h, double r, int dl) {
      final a = t(dl, 320);
      return Positioned(
        left: x,
        top: y,
        width: w,
        height: h,
        child: Opacity(
          opacity: a,
          child: Transform.scale(
            scale: reduced ? 1 : 1.06 - 0.06 * a,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(r),
                border: Border.all(color: accent, width: 2),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        img('home'),
        frame(6, 48, 378, 54, 27, 400),
        frame(6, 750, 140, 66, 33, 850),
        frame(208, 750, 170, 66, 33, 1300),
      ],
    );
  }

  // 3 · ваш стиль: касание строки «Стиль» → раздел выезжает справа.
  Widget _style() {
    final hl = reduced ? 0.0 : _pulse(850, 600);
    final slide = t(1300, 380, _std);
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Transform.translate(
          offset: Offset(reduced ? 0 : -117 * slide, 0),
          child: Stack(
            children: [
              img('settings'),
              Positioned(
                left: 16,
                top: 513,
                width: 358,
                height: 44,
                child: Opacity(
                  opacity: hl,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0x1FFFFFFF)
                          : const Color(0x14000000),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.25 * slide),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (slide > 0)
          Transform.translate(
            offset: Offset(reduced ? 0 : 390 * (1 - slide), 0),
            child: Opacity(
              opacity: reduced ? slide : 1,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 24,
                      offset: Offset(-8, 0),
                    ),
                  ],
                ),
                child: img('style'),
              ),
            ),
          ),
        statusStrip('settings'),
        if (!reduced) _finger(195, 535, 600),
      ],
    );
  }

  // 4 · профиль: прокрутка — аватар уходит в верхний островок.
  Widget _profile() {
    final scroll = t(700, 1100, _std);
    final island = t(1450, 300);
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Transform.translate(
          offset: Offset(0, reduced ? 0 : -180 * scroll),
          child: img('profile'),
        ),
        statusStrip('profile'),
        if (island > 0)
          Positioned(
            left: 12,
            top: 56,
            width: 44,
            height: 44,
            child: Opacity(
              opacity: island,
              child: Transform.scale(
                scale: reduced ? 1 : 0.9 + 0.1 * island,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: dark
                          ? const [Color(0x0FFFFFFF), Color(0x08FFFFFF)]
                          : const [Color(0xA6FFFFFF), Color(0x8CFFFFFF)],
                    ),
                    border: Border.all(
                      width: 0.5,
                      color: dark
                          ? const Color(0x14FFFFFF)
                          : const Color(0x6BFFFFFF),
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: ClipOval(
                    child: Transform.scale(
                      scale: reduced ? 1 : 1.6 - 0.6 * island,
                      child: Image.asset(
                        'assets/whats_new/avatar_daniel.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: _noShot,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 5 · сообщения: кольцо у кнопки эмодзи → панель снизу.
  Widget _messages() {
    final panel = t(1250, 380, _sheetCurve);
    final ringA = ms < 500
        ? 0.0
        : ms < 815
        ? ((ms - 500) / 315).clamp(0.0, 1.0)
        : ms < 1220
        ? 1.0
        : (1 - (ms - 1220) / 180).clamp(0.0, 1.0);
    final ringS = 1.3 - 0.3 * _seg(ms, 500, 315, _eIn);
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        img('chat'),
        if (!reduced && ringA > 0)
          Positioned(
            left: 308 - 22,
            top: 788 - 22,
            width: 44,
            height: 44,
            child: Opacity(
              opacity: ringA,
              child: Transform.scale(
                scale: ringS,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2),
                  ),
                ),
              ),
            ),
          ),
        if (!reduced) _finger(308, 788, 900),
        if (panel > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 334,
            child: Transform.translate(
              offset: Offset(0, reduced ? 0 : 334 * (1 - panel)),
              child: Opacity(
                opacity: reduced ? panel : 1,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: Image.asset(
                    'assets/whats_new/shot_emoji_panel_${dark ? 'dark' : 'light'}.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: _noShot,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 6 · эмоции: ❤️ и 🔥 на весь экран с разлётом.
  Widget _emotions() {
    final dim = t(200, 300);
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        img('chat'),
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.35 * dim)),
        ),
        ..._burst('❤️', 400, 2200),
        ..._burst('🔥', 2600, null),
      ],
    );
  }

  List<Widget> _burst(String ch, int dl, int? outAt) {
    final inT = reduced ? _seg(ms, dl, 200, Curves.linear) : _seg(ms, dl, 520, Curves.linear);
    if (inT <= 0) return const [];
    final outT = outAt == null
        ? 0.0
        : (reduced
              ? _seg(ms, outAt, 200, Curves.linear)
              : _seg(ms, outAt, 260, _eOut));
    if (outT >= 1) return const [];
    double scale;
    if (reduced) {
      scale = 1;
    } else if (inT < 0.6) {
      scale = 0.3 + (1.12 - 0.3) * _pop.transform(inT / 0.6);
    } else {
      scale = 1.12 - 0.12 * _eIn.transform((inT - 0.6) / 0.4);
    }
    scale *= 1 - 0.2 * outT;
    final opacity = (reduced ? inT : (inT / 0.6).clamp(0.0, 1.0)) * (1 - outT);
    final rnd = _Mulberry(ch.runes.first);
    final parts = <Widget>[];
    if (!reduced) {
      for (var k = 0; k < 10; k++) {
        final ang = k / 10 * math.pi * 2 + (rnd.next() - 0.5) * 0.5;
        final dist = 130 + rnd.next() * 60;
        final pt = _seg(ms, dl + 250 + k * 15, 1000, Curves.linear);
        if (pt <= 0 || pt >= 1) continue;
        final e = _eIn.transform(pt);
        final f = pt < 0.25 ? 0.4 * (e / _eIn.transform(0.25)) : e;
        final po = pt < 0.25 ? pt / 0.25 : 1 - (pt - 0.25) / 0.75;
        final ps = pt < 0.25 ? 0.4 + 0.6 * (pt / 0.25) : 1 - 0.2 * ((pt - 0.25) / 0.75);
        parts.add(
          Positioned(
            left: 195 - 15 + math.cos(ang) * dist * f,
            top: 400 - 15 + math.sin(ang) * dist * f,
            width: 30,
            height: 30,
            child: Opacity(
              opacity: po.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: ps,
                child: Text(
                  ch,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, height: 1.1),
                ),
              ),
            ),
          ),
        );
      }
    }
    return [
      ...parts,
      Positioned(
        left: 0,
        right: 0,
        top: 300,
        height: 200,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: Text(ch, style: const TextStyle(fontSize: 150, height: 1)),
            ),
          ),
        ),
      ),
    ];
  }

  /// 0→1→0 за [dur] (держится на 30–70 %).
  double _pulse(int dl, int dur) {
    final x = (ms - dl) / dur;
    if (x <= 0 || x >= 1) return 0;
    if (x < 0.3) return x / 0.3;
    if (x < 0.7) return 1;
    return (1 - x) / 0.3;
  }

  /// Палец-подсказка Ø 44: 0.6→1→0.86→1.1 за 700 мс.
  Widget _finger(double cx, double cy, int dl) {
    final x = (ms - dl) / 700;
    if (x <= 0 || x >= 1) return const SizedBox.shrink();
    double o, s;
    if (x < 0.26) {
      final k = Curves.easeOut.transform(x / 0.26);
      o = k;
      s = 0.6 + 0.4 * k;
    } else if (x < 0.6) {
      o = 1;
      s = 1 - 0.14 * Curves.easeOut.transform((x - 0.26) / 0.34);
    } else {
      final k = Curves.easeOut.transform((x - 0.6) / 0.4);
      o = 1 - k;
      s = 0.86 + 0.24 * k;
    }
    return Positioned(
      left: cx - 22,
      top: cy - 22,
      width: 44,
      height: 44,
      child: IgnorePointer(
        child: Opacity(
          opacity: o,
          child: Transform.scale(
            scale: s,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark ? const Color(0x59FFFFFF) : const Color(0x29111418),
                border: Border.all(
                  width: 1.5,
                  color: dark ? const Color(0x99FFFFFF) : const Color(0x4D111418),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotifBanner extends StatelessWidget {
  const _NotifBanner({
    required this.dark,
    required this.sender,
    required this.message,
    required this.now,
  });

  final bool dark;
  final String sender;
  final String message;
  final String now;

  @override
  Widget build(BuildContext context) {
    final tx = dark ? const Color(0xFFE2E6EA) : const Color(0xFF111418);
    final tx2 = dark ? const Color(0x99EBEBF5) : const Color(0x993C3C43);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1C1C1F) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(9),
            ),
            padding: const EdgeInsets.all(7),
            child: CustomPaint(
              painter: SMarkDrawPainter(
                ms: 99999,
                stroke: Colors.white,
                fill: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tx,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: tx),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 22),
            child: Text(now, style: TextStyle(fontSize: 13, color: tx2)),
          ),
        ],
      ),
    );
  }
}

/// mulberry32 — тот же рисунок при каждом показе (как в макете).
class _Mulberry {
  _Mulberry(int seed) : _a = seed;
  int _a;

  double next() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _imul(_a ^ (_a >>> 15), 1 | _a);
    t = (t + _imul(t ^ (t >>> 7), 61 | t)) & 0xFFFFFFFF ^ t;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
  }

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;
}

@visibleForTesting
double whatsNewSeg(double ms, int delay, int dur) =>
    _seg(ms, delay, dur, Curves.linear);

/// Снимок не загрузился (сборка без растров — открытый репозиторий, или
/// повреждённый файл): тихая подложка вместо красного экрана ошибки.
Widget _noShot(BuildContext context, Object error, StackTrace? stack) =>
    ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest);
