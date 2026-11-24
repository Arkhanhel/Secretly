// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Вкладки «Мини-галереи» профиля по макету владельца (новый режим,
/// 21.11.2026).
///
/// * Полоса — стеклянный «остров» 44 px, скругление 22; подписи 15 px w600,
///   выбранная — цветом акцента.
/// * Плашка выбора ползёт «гусеницей»: у левого и правого края — свои
///   пружины; ведущий край (по ходу движения) k600 c44, отстающий k260 c30.
/// * Страницы листаются пальцем вбок (резинка у краёв
///   `d·(1 − 1/(x·0,55/d + 1))`, d = ширина), отпустил — к ближней, бросок
///   быстрее 0,7 px/мс — к соседней; страница доезжает пружиной k300 c32.
/// * Высота листалки следует за страницей (страницы разной высоты).
/// * Закреплённая копия полосы под шапкой — [ProfileStickyTabs]; обе копии
///   рисуют одну плашку из общего [ProfileTabsController].
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../glass/glass_category_strip.dart';
import '../widgets/frosted_header_island.dart';

/// Резинка за краем: `d·(1 − 1/(x·0,55/d + 1))`.
@visibleForTesting
double profileTabsRubber(double x, double d) {
  if (x <= 0 || d <= 0) return 0;
  return d * (1 - 1 / (x * 0.55 / d + 1));
}

/// Порог броска, px/мс.
const double kProfileTabsFlingVelocity = 0.7;

// Пружины (масса 1).
const double _kPageK = 300, _kPageC = 32;
const double _kLeadK = 600, _kLeadC = 44;
const double _kTrailK = 260, _kTrailC = 30;

/// Общее состояние вкладок: дробная страница, выбранная вкладка, края
/// плашки и признак «полоса закреплена под шапкой». Одна пружинная
/// петля (один тикер) на всё.
///
/// Края плашки — в долях ячейки: ячейка `i` занимает `[i, i + 1]`.
class ProfileTabsController extends ChangeNotifier {
  ProfileTabsController({
    required TickerProvider vsync,
    required this.length,
    int initialIndex = 0,
    this.onChanged,
    this.hapticsEnabled,
  }) : assert(length > 0),
       _index = initialIndex.clamp(0, length - 1) {
    _page = _index.toDouble();
    _pageTarget = _index;
    _left = _page;
    _right = _page + 1;
    _ticker = vsync.createTicker(_tick);
  }

  /// Число вкладок (должно совпадать с подписями и страницами).
  final int length;

  /// Выбранная вкладка сменилась (касанием, листанием или программно).
  ValueChanged<int>? onChanged;

  /// Настройка «отклик» приложения; `null` — включён.
  bool Function()? hapticsEnabled;

  /// «Уменьшить движение»: вместо пружин — сразу на место. Выставляют
  /// виджеты из `MediaQuery.disableAnimations`; можно задать и вручную.
  bool reduceMotion = false;

  late final Ticker _ticker;
  bool _disposed = false;

  int _index;
  late double _page;
  double _pageVel = 0;
  late int _pageTarget;
  bool _settling = false;

  bool _dragging = false;
  double _dragStart = 0;
  double _dragDx = 0;

  late double _left;
  late double _right;
  double _leftVel = 0;
  double _rightVel = 0;
  // Направление хода плашки: +1 вправо, −1 влево.
  double _dir = 1;

  bool _pinned = false;
  // Ширина листалки с последней раскладки.
  double _pagerWidth = 0;
  Duration _last = Duration.zero;

  /// Выбранная вкладка (куда едем или где стоим).
  int get index => _index;

  /// Дробная страница: 0 — первая, 1,5 — между второй и третьей. За краем
  /// (резинка) бывает чуть меньше 0 или больше `length − 1`.
  double get page => _page;

  /// Левый край плашки, в ячейках.
  double get indicatorLeft => _left;

  /// Правый край плашки, в ячейках.
  double get indicatorRight => _right;

  /// Палец ведёт страницы.
  bool get isDragging => _dragging;

  /// Пружины ещё в ходу.
  bool get isAnimating => _ticker.isActive;

  /// Копия полосы закреплена под шапкой ([ProfileStickyTabs]); полоса в
  /// списке с `hideWhenPinned` при этом прячется, сохраняя место.
  bool get pinned => _pinned;

  bool get _haptics => hapticsEnabled?.call() ?? true;

  /// Плавно к вкладке [i] (без отклика — программный переход).
  void animateTo(int i) => _goTo(i, haptic: false);

  /// Сразу на вкладку [i], без пружин.
  void jumpTo(int i) {
    final target = i.clamp(0, length - 1);
    _dragging = false;
    _settling = false;
    _pageTarget = target;
    _page = target.toDouble();
    _pageVel = 0;
    _left = _page;
    _right = _page + 1;
    _leftVel = 0;
    _rightVel = 0;
    _ticker.stop();
    _setIndex(target, haptic: false);
    notifyListeners();
  }

  /// Касание вкладки в полосе.
  void _tapTab(int i) => _goTo(i, haptic: true);

  void _goTo(int i, {required bool haptic}) {
    final target = i.clamp(0, length - 1);
    if (reduceMotion) {
      final changed = target != _index;
      jumpTo(target);
      if (changed && haptic && _haptics) HapticFeedback.selectionClick();
      return;
    }
    _dragging = false;
    _pageTarget = target;
    _settling = true;
    _setIndex(target, haptic: haptic);
    _ensureTicking();
  }

  // ── Листание пальцем ─────────────────────────────────────────────────────

  /// Палец лёг: подхватываем страницу там, где она сейчас (и на ходу).
  void dragStart() {
    _dragging = true;
    _settling = false;
    _pageVel = 0;
    _dragStart = _page;
    _dragDx = 0;
  }

  /// Палец сдвинулся на [deltaPx] (вправо — плюс) при ширине страницы
  /// [width]: `page = start − dx/width`, за краями — резинка.
  void dragUpdate(double deltaPx, double width) {
    if (!_dragging || width <= 0) return;
    _dragDx += deltaPx;
    final raw = _dragStart - _dragDx / width;
    final last = (length - 1).toDouble();
    if (raw < 0) {
      _page = -profileTabsRubber(-raw * width, width) / width;
    } else if (raw > last) {
      _page = last + profileTabsRubber((raw - last) * width, width) / width;
    } else {
      _page = raw;
    }
    if (reduceMotion) {
      _left = _page;
      _right = _page + 1;
      notifyListeners();
    } else {
      _ensureTicking();
      notifyListeners();
    }
  }

  /// Палец отпустил со скоростью [velocityPxPerMs] (вправо — плюс): бросок
  /// быстрее порога — к соседней странице, иначе к ближней.
  void dragEnd(double velocityPxPerMs, double width) {
    if (!_dragging) return;
    _dragging = false;
    int target;
    if (velocityPxPerMs.abs() > kProfileTabsFlingVelocity) {
      target = velocityPxPerMs < 0 ? _page.floor() + 1 : _page.ceil() - 1;
    } else {
      target = _page.round();
    }
    target = target.clamp(0, length - 1);
    if (reduceMotion || width <= 0) {
      final changed = target != _index;
      jumpTo(target);
      if (changed && _haptics) HapticFeedback.selectionClick();
      return;
    }
    // Скорость пальца переходит в пружину без рывка (страниц в секунду).
    _pageVel = -velocityPxPerMs * 1000 / width;
    _pageTarget = target;
    _settling = true;
    _setIndex(target, haptic: true);
    _ensureTicking();
  }

  /// Жест отменён — к ближней странице.
  void dragCancel() => dragEnd(0, 1);

  // ── Закрепление ──────────────────────────────────────────────────────────

  /// Ставит [ProfileStickyTabs]; отклик «light» на смену.
  void setPinned(bool value, {bool haptic = true}) {
    if (_pinned == value) return;
    _pinned = value;
    if (haptic && _haptics) HapticFeedback.lightImpact();
    notifyListeners();
  }

  // ── Пружинная петля ──────────────────────────────────────────────────────

  void _setIndex(int i, {required bool haptic}) {
    if (i == _index) return;
    _index = i;
    if (haptic && _haptics) HapticFeedback.selectionClick();
    onChanged?.call(i);
  }

  void _ensureTicking() {
    if (_disposed || _ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    if (dt > 1 / 30) dt = 1 / 30;
    final steps = math.max(1, (dt * 240).ceil());
    final h = dt / steps;
    for (var s = 0; s < steps; s++) {
      if (_settling && !_dragging) {
        final a = -_kPageK * (_page - _pageTarget) - _kPageC * _pageVel;
        _pageVel += a * h;
        _page += _pageVel * h;
      }
      // Пока палец ведёт — плашка за живой страницей, иначе — к цели.
      final base = _dragging ? _page : _pageTarget.toDouble();
      final d = (base + 0.5) - (_left + _right) / 2;
      if (d.abs() > 1e-4) _dir = d.sign;
      final leftLeads = _dir < 0;
      final kl = leftLeads ? _kLeadK : _kTrailK;
      final cl = leftLeads ? _kLeadC : _kTrailC;
      final kr = leftLeads ? _kTrailK : _kLeadK;
      final cr = leftLeads ? _kTrailC : _kLeadC;
      _leftVel += (-kl * (_left - base) - cl * _leftVel) * h;
      _left += _leftVel * h;
      _rightVel += (-kr * (_right - (base + 1)) - cr * _rightVel) * h;
      _right += _rightVel * h;
    }
    var rest = true;
    if (_settling && !_dragging) {
      if ((_page - _pageTarget).abs() < 1e-4 && _pageVel.abs() < 1e-3) {
        _page = _pageTarget.toDouble();
        _pageVel = 0;
        _settling = false;
      } else {
        rest = false;
      }
    }
    final base = _dragging ? _page : _pageTarget.toDouble();
    if ((_left - base).abs() < 1e-4 &&
        _leftVel.abs() < 1e-3 &&
        (_right - base - 1).abs() < 1e-4 &&
        _rightVel.abs() < 1e-3) {
      _left = base;
      _right = base + 1;
      _leftVel = 0;
      _rightVel = 0;
    } else {
      rest = false;
    }
    if (rest) _ticker.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Полоса вкладок
// ═══════════════════════════════════════════════════════════════════════════

/// Стеклянная полоса вкладок с «гусеницей». Касание вкладки — пружиной к
/// её странице. Копий может быть несколько (в списке и закреплённая) —
/// все рисуют одно состояние [controller].
class ProfileTabsBar extends StatelessWidget {
  const ProfileTabsBar({
    super.key,
    required this.controller,
    required this.labels,
    this.hideWhenPinned = false,
    this.frosted = false,
    this.accent,
  });

  final ProfileTabsController controller;
  final List<String> labels;

  /// Полоса в списке: пока закреплённая копия видна ([ProfileTabsController.pinned]),
  /// эта прячется, сохраняя место (и не принимает касаний).
  final bool hideWhenPinned;

  /// Размыть то, что под полосой (для закреплённой копии над содержимым).
  final bool frosted;

  /// Цвет выбранной подписи и плашки; по умолчанию `colorScheme.primary`.
  final Color? accent;

  static const double height = 44;
  static const double _radius = 22;
  static const double _inset = 3;
  static const double _pillTop = 5;
  static const double _pillHeight = 34;

  @override
  Widget build(BuildContext context) {
    assert(labels.length == controller.length);
    if (kProfileTabsAsStrip) return _buildStrip(context);
    controller.reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = this.accent ?? theme.colorScheme.primary;
    final sub = theme.colorScheme.onSurfaceVariant;
    final pill = accent.withValues(alpha: dark ? 0.16 : 0.13);
    final n = controller.length;

    Widget bar = SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final cellW = c.maxWidth / n;
          return Stack(
            children: [
              // 23.11.2026 (владелец): пластина — ровно как у основных
              // островков ([FrostedHeaderIsland]; на iPhone со стеклом — то
              // же стекло), а не своя.
              if (kNeutralSelectedPill)
                Positioned.fill(
                  child: FrostedHeaderIsland(
                    radius: _radius,
                    frosted: frosted ? null : false,
                    child: const SizedBox.expand(),
                  ),
                )
              else ...[
                if (frosted)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_radius),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: CustomPaint(painter: _IslandPainter(dark: dark)),
                ),
              ],
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final l = controller.indicatorLeft;
                  // Не уже половины ячейки, даже на отскоке.
                  final r = math.max(controller.indicatorRight, l + 0.5);
                  return Positioned(
                    left: l * cellW + _inset,
                    top: _pillTop,
                    width: math.max(0, (r - l) * cellW - 2 * _inset),
                    height: _pillHeight,
                    child: DecoratedBox(
                      decoration: kNeutralSelectedPill
                          ? islandSelectedPillDecoration(
                              isDark: dark,
                              radius: _pillHeight / 2,
                            )
                          : BoxDecoration(
                              color: pill,
                              borderRadius: BorderRadius.circular(
                                _pillHeight / 2,
                              ),
                            ),
                    ),
                  );
                },
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: _TabCell(
                          controller: controller,
                          index: i,
                          label: labels[i],
                          accent: accent,
                          sub: sub,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    if (hideWhenPinned) {
      bar = ListenableBuilder(
        listenable: controller,
        child: bar,
        builder: (context, child) => Visibility(
          visible: !controller.pinned,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: child!,
        ),
      );
    }
    return bar;
  }
}

/// Вкладки профиля — та же полоса, что папки на главной (23.11.2026,
/// владелец: «по размеру отличаются от папок на главной и друг от друга»).
/// `false` — прежняя своя полоса (44 пт, своя пластина и ползунок).
const bool kProfileTabsAsStrip = true;

/// Дробная страница контроллера как [ValueListenable] — для капли полосы.
class _ProfileTabsPage implements ValueListenable<double> {
  _ProfileTabsPage(this.controller);
  final ProfileTabsController controller;
  @override
  double get value => controller.page;
  @override
  void addListener(VoidCallback l) => controller.addListener(l);
  @override
  void removeListener(VoidCallback l) => controller.removeListener(l);
}

extension on ProfileTabsBar {
  Widget _buildStrip(BuildContext context) {
    Widget bar = ListenableBuilder(
      listenable: controller,
      builder: (context, _) => GlassCategoryStrip(
        items: [for (final l in labels) GlassStripItem(label: l)],
        selected: controller.index,
        position: _ProfileTabsPage(controller),
        onSelect: controller._tapTab,
        haptics: false,
      ),
    );
    if (hideWhenPinned) {
      bar = ListenableBuilder(
        listenable: controller,
        child: bar,
        builder: (context, child) => Visibility(
          visible: !controller.pinned,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: child!,
        ),
      );
    }
    return bar;
  }
}

class _TabCell extends StatelessWidget {
  const _TabCell({
    required this.controller,
    required this.index,
    required this.label,
    required this.accent,
    required this.sub,
  });

  final ProfileTabsController controller;
  final int index;
  final String label;
  final Color accent;
  final Color sub;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => controller._tapTab(index),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          // Цвет подписи следует за плашкой: под ней — акцент.
          final center =
              (controller.indicatorLeft + controller.indicatorRight) / 2 - 0.5;
          final t = (1 - (center - index).abs()).clamp(0.0, 1.0);
          return Semantics(
            button: true,
            selected: controller.index == index,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color.lerp(sub, accent, t),
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

/// Остров: мягкая тень (светлая тема, только снаружи), заливка
/// градиентом сверху вниз, тонкий блик по верхней кромке (тёмная тема).
class _IslandPainter extends CustomPainter {
  const _IslandPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(ProfileTabsBar._radius),
    );
    if (!dark) {
      // box-shadow 0 1 6 rgba(0,0,0,.07): как в CSS — не под полупрозрачной
      // заливкой, а только снаружи.
      canvas.save();
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect.inflate(12))
          ..addRRect(rr),
      );
      canvas.drawRRect(
        rr.shift(const Offset(0, 1)),
        Paint()
          ..color = const Color(0x12000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.restore();
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [
                  Colors.white.withValues(alpha: 0.13),
                  Colors.white.withValues(alpha: 0.07),
                ]
              : [
                  Colors.white.withValues(alpha: 0.5),
                  Colors.white.withValues(alpha: 0.4),
                ],
        ).createShader(rect),
    );
    if (dark) {
      // inset 0 1px 0 rgba(255,255,255,.08) — серп по верхней кромке.
      final crescent = Path.combine(
        PathOperation.difference,
        Path()..addRRect(rr),
        Path()..addRRect(rr.shift(const Offset(0, 1))),
      );
      canvas.drawPath(
        crescent,
        Paint()..color = Colors.white.withValues(alpha: 0.08),
      );
    }
  }

  @override
  bool shouldRepaint(_IslandPainter old) => old.dark != dark;
}

// ═══════════════════════════════════════════════════════════════════════════
// Листалка страниц
// ═══════════════════════════════════════════════════════════════════════════

/// Страницы вкладок, листаются пальцем вбок. Высота — по текущей странице
/// (между соседними — плавно), поэтому листалку можно ставить прямо в
/// вертикальный `ListView`: она забирает только горизонтальные жесты.
///
/// Страницы раскладываются по ширине листалки с неограниченной высотой —
/// сетки внутри должны быть `shrinkWrap` (как и сейчас в списке).
class ProfileTabsPager extends StatelessWidget {
  const ProfileTabsPager({
    super.key,
    required this.controller,
    required this.pages,
  });

  final ProfileTabsController controller;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    assert(pages.length == controller.length);
    controller.reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // Ширина с последней раскладки: во время жеста высота листалки
    // меняется, и `context.size` спрашивать нельзя.
    double width() => controller._pagerWidth;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        HorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              HorizontalDragGestureRecognizer
            >(HorizontalDragGestureRecognizer.new, (r) {
              r.onStart = (_) {
                controller.dragStart();
              };
              r.onUpdate = (d) {
                controller.dragUpdate(d.primaryDelta ?? d.delta.dx, width());
              };
              r.onEnd = (d) {
                controller.dragEnd(
                  (d.primaryVelocity ?? d.velocity.pixelsPerSecond.dx) / 1000,
                  width(),
                );
              };
              r.onCancel = controller.dragCancel;
            }),
      },
      child: _PagerLayout(controller: controller, children: pages),
    );
  }
}

class _PagerLayout extends MultiChildRenderObjectWidget {
  const _PagerLayout({required this.controller, required super.children});

  final ProfileTabsController controller;

  @override
  _RenderPager createRenderObject(BuildContext context) =>
      _RenderPager(controller);

  @override
  void updateRenderObject(BuildContext context, _RenderPager renderObject) {
    renderObject.controller = controller;
  }
}

class _PagerParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderPager extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PagerParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PagerParentData> {
  _RenderPager(this._controller);

  ProfileTabsController _controller;
  ProfileTabsController get controller => _controller;
  set controller(ProfileTabsController value) {
    if (identical(value, _controller)) return;
    if (attached) _controller.removeListener(_onTick);
    _controller = value;
    if (attached) _controller.addListener(_onTick);
    markNeedsLayout();
  }

  final List<double> _heights = <double>[];
  int _semanticsPage = -1;
  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PagerParentData) {
      child.parentData = _PagerParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(_onTick);
  }

  @override
  void detach() {
    _controller.removeListener(_onTick);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  double _heightAt(double page) {
    if (_heights.isEmpty) return 0;
    final p = page.clamp(0.0, (_heights.length - 1).toDouble());
    final lo = p.floor();
    final hi = math.min(lo + 1, _heights.length - 1);
    return ui.lerpDouble(_heights[lo], _heights[hi], p - lo)!;
  }

  void _onTick() {
    // Высота та же — только сдвиг страниц, без перекладки списка.
    if (!hasSize || _heightAt(_controller.page) != size.height) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
    final int sp = _controller.page
        .round()
        .clamp(0, math.max(0, childCount - 1))
        .toInt();
    if (sp != _semanticsPage) {
      _semanticsPage = sp;
      markNeedsSemanticsUpdate();
    }
  }

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth, 'ProfileTabsPager: ширина не задана');
    final w = constraints.maxWidth;
    _controller._pagerWidth = w;
    _heights.clear();
    var child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: w), parentUsesSize: true);
      _heights.add(child.size.height);
      child = childAfter(child);
    }
    size = constraints.constrain(Size(w, _heightAt(_controller.page)));
  }

  // Видны не больше двух соседних страниц.
  bool _visible(int i) => (i - _controller.page).abs() < 1;

  Offset _offsetOf(int i) => Offset((i - _controller.page) * size.width, 0);

  @override
  void paint(PaintingContext context, Offset offset) {
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) {
        var child = firstChild;
        var i = 0;
        while (child != null) {
          if (_visible(i)) context.paintChild(child, offset + _offsetOf(i));
          child = childAfter(child);
          i++;
        }
      },
      oldLayer: _clip.layer,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    var c = firstChild;
    var i = 0;
    while (c != null && c != child) {
      c = childAfter(c);
      i++;
    }
    final o = _offsetOf(i);
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    var i = childCount - 1;
    while (child != null) {
      if (_visible(i)) {
        final hit = result.addWithPaintOffset(
          offset: _offsetOf(i),
          position: position,
          hitTest: (result, transformed) =>
              child!.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
      child = childBefore(child);
      i--;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final current = _controller.page.round();
    var child = firstChild;
    var i = 0;
    while (child != null) {
      if (i == current) visitor(child);
      child = childAfter(child);
      i++;
    }
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsic(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsic(width);

  double _intrinsic(double width) {
    final i = _controller.index;
    var child = firstChild;
    var n = 0;
    while (child != null) {
      if (n == i) return child.getMaxIntrinsicHeight(width);
      child = childAfter(child);
      n++;
    }
    return 0;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Закреплённая копия
// ═══════════════════════════════════════════════════════════════════════════

/// Закреплённая копия полосы под шапкой экрана. Ставится в `Stack` экрана:
/// `Positioned(top: headerBottom, left: 16, right: 16, child: ProfileStickyTabs(...))`.
///
/// Следит за прокруткой [scroll] и положением полосы в списке ([inListKey] —
/// ключ на `ProfileTabsBar(hideWhenPinned: true)`): как только её верх
/// уходит выше линии шапки — показывает копию и прячет ту, что в списке
/// (место сохраняется), обратно — наоборот; отклик «light» на смену.
///
/// Линия шапки — собственный верх этого виджета в глобальных координатах
/// (поэтому не важно, где начинается `Stack`); пока он не разложен —
/// [headerBottom].
class ProfileStickyTabs extends StatefulWidget {
  const ProfileStickyTabs({
    super.key,
    required this.controller,
    required this.labels,
    required this.inListKey,
    required this.headerBottom,
    required this.scroll,
    this.accent,
  });

  final ProfileTabsController controller;
  final List<String> labels;
  final GlobalKey inListKey;
  final double headerBottom;
  final ScrollController scroll;
  final Color? accent;

  @override
  State<ProfileStickyTabs> createState() => _ProfileStickyTabsState();
}

class _ProfileStickyTabsState extends State<ProfileStickyTabs> {
  // Верх полосы в «содержимом» (глобальный Y + смещение прокрутки) —
  // чтобы решать прямо в слушателе прокрутки, без отставания на кадр.
  double? _contentY;
  bool _measureQueued = false;

  @override
  void initState() {
    super.initState();
    _shown = widget.controller.pinned;
    widget.scroll.addListener(_onScroll);
    widget.controller.addListener(_onController);
    _queueMeasure();
  }

  @override
  void didUpdateWidget(ProfileStickyTabs old) {
    super.didUpdateWidget(old);
    if (!identical(old.scroll, widget.scroll)) {
      old.scroll.removeListener(_onScroll);
      widget.scroll.addListener(_onScroll);
      _contentY = null;
    }
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _releasePin(old.controller);
      _shown = widget.controller.pinned;
    }
    _queueMeasure();
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_onScroll);
    widget.controller.removeListener(_onController);
    _releasePin(widget.controller);
    super.dispose();
  }

  // Снять закрепление после кадра: из dispose дерево трогать нельзя.
  void _releasePin(ProfileTabsController c) {
    if (!c.pinned) return;
    scheduleMicrotask(() {
      if (!c._disposed) c.setPinned(false, haptic: false);
    });
  }

  void _onController() {
    // Закрепление сменилось — перестроить копию.
    if (mounted && widget.controller.pinned != _shown) {
      setState(() => _shown = widget.controller.pinned);
    }
  }

  // Что сейчас нарисовано (копия видна или нет).
  bool _shown = false;

  double? get _scrollOffset {
    final s = widget.scroll;
    if (!s.hasClients || s.positions.length != 1) return null;
    return s.offset;
  }

  double get _line {
    final box = context.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize) {
      return box.localToGlobal(Offset.zero).dy;
    }
    return widget.headerBottom;
  }

  void _onScroll() {
    final cy = _contentY;
    final off = _scrollOffset;
    if (cy != null && off != null) _apply(cy - off < _line);
    _queueMeasure();
  }

  void _queueMeasure() {
    if (_measureQueued) return;
    _measureQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measureQueued = false;
      _measure();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _measure() {
    if (!mounted) return;
    final ctx = widget.inListKey.currentContext;
    final box = ctx?.findRenderObject();
    // Полоса ушла из списка (ленивый ListView) — оставляем как было.
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final y = box.localToGlobal(Offset.zero).dy;
    final off = _scrollOffset;
    _contentY = off == null ? null : y + off;
    _apply(y < _line);
  }

  void _apply(bool stuck) {
    if (stuck == widget.controller.pinned) return;
    widget.controller.setPinned(stuck);
  }

  @override
  Widget build(BuildContext context) {
    if (!_shown) return const SizedBox(height: 0);
    return ProfileTabsBar(
      controller: widget.controller,
      labels: widget.labels,
      frosted: true,
      accent: widget.accent,
    );
  }
}
