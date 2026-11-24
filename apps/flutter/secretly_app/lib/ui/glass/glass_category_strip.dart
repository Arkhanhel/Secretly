// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Полоса категорий во всю ширину с переливающейся каплей (план стекла,
/// 23.11.2026): папки, «Личное / Архив», вкладки галереи, темы комнаты.
///
/// * Одна пластина почти во всю ширину экрана при ЛЮБОМ числе пунктов
///   ([computeGlassStripLayout]: поровну → по содержимому → прокрутка).
/// * Выбранный пункт отмечает капля: она идёт по дробной позиции — за пальцем
///   при свайпе страницы ([position]) или пружиной по нажатию — и по ходу
///   вытягивается и сплющивается ([glassThumbRect]).
/// * Подписи в два слоя: под каплей — акцентный цвет, снаружи — обычный, так
///   что цвет «перетекает» по буквам вместе с каплей.
/// * Каплю можно вести пальцем по полосе (кроме режима прокрутки — там палец
///   листает полосу).
/// * Материал пластины — тот же, что у островков ([FrostedHeaderIsland]): на
///   iPhone со включённым стеклом — жидкое стекло, иначе матовое. Капля —
///   часть пластины, а не второе стекло поверх (стекло на стекле серое).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../widgets/frosted_header_island.dart';
import 'glass_strip_layout.dart';
import 'secretly_glass_plate.dart';

/// Выключатель полосы во всю ширину. `false` — прежние полосы.
const bool kGlassCategoryStrip = true;

/// Полоса рисуется движком SecretlyGlass. `false` — пластиной островков
/// (как все основные островки), см. сборку пластины ниже.
const bool kGlassStripUsesEngine = false;

class GlassStripItem {
  const GlassStripItem({
    required this.label,
    this.icon,
    this.iconColor,
    this.badge = 0,
    this.action = false,
    this.semanticLabel,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;

  /// Счётчик справа от подписи (0 — нет).
  final int badge;

  /// Пункт-действие (например, закрытая ветка комнаты): открывает другое,
  /// капля к нему не едет. Ставить в конец списка.
  final bool action;
  final String? semanticLabel;
}

class GlassCategoryStrip extends StatefulWidget {
  const GlassCategoryStrip({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.onLongPress,
    this.haptics = true,
    this.position,
    this.height = 40,
    this.margin = const EdgeInsets.symmetric(horizontal: 14),
    this.fontSize = 14,
  });

  final List<GlassStripItem> items;

  /// Выбранный пункт (-1 — ни один).
  final int selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<int>? onLongPress;

  /// Отклик при выборе. `false` — его даёт владелец полосы сам (вкладки
  /// профиля: свой контроллер со своей настройкой отклика).
  final bool haptics;

  /// Дробная позиция снаружи (PageController.page, TabController.animation):
  /// капля идёт за пальцем. `null` — своя пружина по [selected].
  final ValueListenable<double>? position;
  final double height;
  final EdgeInsets margin;
  final double fontSize;

  @override
  State<GlassCategoryStrip> createState() => GlassCategoryStripState();
}

@visibleForTesting
class GlassCategoryStripState extends State<GlassCategoryStrip>
    with SingleTickerProviderStateMixin {
  static const double _inset = 3; // поле между пластиной и каплей
  static const double _itemPad = 14;
  static const double _iconGap = 5;

  late final AnimationController _spring = AnimationController.unbounded(
    vsync: this,
    value: math.max(0, widget.selected).toDouble(),
  );
  final ScrollController _scroll = ScrollController();
  double? _drag;
  GlassStripLayout? _layout;

  // Для движка SecretlyGlass: рамка капли (в видимых координатах полосы) и
  // сила линзы — только числа для шейдера.
  final ValueNotifier<Rect?> _thumbForGlass = ValueNotifier<Rect?>(null);
  final ValueNotifier<double> _liftForGlass = ValueNotifier<double>(0);
  Rect? _lastThumb;

  void _publishThumb() {
    final r = _lastThumb;
    final dx = (_layout?.mode == GlassStripMode.scroll && _scroll.hasClients)
        ? _scroll.offset
        : 0.0;
    _thumbForGlass.value = r?.shift(Offset(-dx, 0));
  }

  /// Текущая позиция капли (для проверок).
  @visibleForTesting
  double get thumbPosition =>
      _drag ?? widget.position?.value ?? _spring.value;

  @visibleForTesting
  GlassStripLayout? get debugLayout => _layout;

  int get _tabCount {
    var n = 0;
    for (final it in widget.items) {
      if (it.action) break;
      n++;
    }
    return n;
  }

  @override
  void didUpdateWidget(covariant GlassCategoryStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected && widget.selected >= 0) {
      if (widget.position == null && _drag == null) _springTo(widget.selected);
      WidgetsBinding.instance.addPostFrameCallback((_) => _keepVisible());
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_publishThumb);
  }

  @override
  void dispose() {
    _spring.dispose();
    _scroll.removeListener(_publishThumb);
    _scroll.dispose();
    _thumbForGlass.dispose();
    _liftForGlass.dispose();
    super.dispose();
  }

  void _springTo(int index) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _spring.value = index.toDouble();
      return;
    }
    // Новое нажатие посреди движения сохраняет скорость, а не начинает с нуля.
    const spring = SpringDescription(mass: 1, stiffness: 260, damping: 24);
    _spring.animateWith(
      SpringSimulation(
        spring,
        _spring.value,
        index.toDouble(),
        _spring.velocity,
      ),
    );
  }

  /// Режим прокрутки: выбранный пункт — к центру видимой части.
  void _keepVisible() {
    final l = _layout;
    if (!mounted || l == null || l.mode != GlassStripMode.scroll) return;
    if (!_scroll.hasClients || widget.selected < 0) return;
    final i = widget.selected.clamp(0, l.length - 1);
    final view = _scroll.position.viewportDimension;
    final target = (l.lefts[i] + l.widths[i] / 2 - view / 2).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  TextStyle _labelStyle(Color color) => TextStyle(
    fontSize: widget.fontSize,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.15,
  );

  double _naturalWidth(GlassStripItem it, TextScaler scaler, TextStyle base) {
    double textW(String s, double size) {
      // Меряем тем же стилем, каким рисуем (шрифт темы), — иначе замер и
      // рисунок расходятся.
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: base.merge(
            TextStyle(fontSize: size, fontWeight: FontWeight.w700),
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = tp.width;
      tp.dispose();
      return w;
    }

    var w = _itemPad * 2 + textW(it.label, widget.fontSize);
    if (it.icon != null) w += scaler.scale(16) + _iconGap;
    if (it.badge > 0) {
      w += _iconGap + math.max(scaler.scale(18), textW('${it.badge}', 11) + 10);
    }
    return w;
  }

  /// Дробная позиция под пальцем: центр пункта i — ровно i.
  double _positionAt(double x) {
    final l = _layout!;
    final tabs = _tabCount;
    if (tabs <= 1) return 0;
    for (var i = 0; i < tabs - 1; i++) {
      final c0 = l.lefts[i] + l.widths[i] / 2;
      final c1 = l.lefts[i + 1] + l.widths[i + 1] / 2;
      if (x <= c1) {
        if (x <= c0) return i.toDouble();
        return i + (x - c0) / (c1 - c0);
      }
    }
    return (tabs - 1).toDouble();
  }

  void _select(int i) {
    if (i < 0 || i >= widget.items.length) return;
    if (widget.haptics) HapticFeedback.selectionClick();
    widget.onSelect(i);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaler = MediaQuery.textScalerOf(context);
    final h = widget.height;
    final normal = isDark ? Colors.white : Colors.black;
    final accent = cs.primary;
    final glass = liquidGlassIslandsEnabled;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Padding(
      padding: widget.margin,
      child: LayoutBuilder(
        builder: (context, box) {
          final inner = math.max(0.0, box.maxWidth - _inset * 2);
          final layout = computeGlassStripLayout(
            available: inner,
            natural: [
              for (final it in widget.items)
                _naturalWidth(it, scaler, DefaultTextStyle.of(context).style),
            ],
          );
          _layout = layout;
          final scroll = layout.mode == GlassStripMode.scroll;
          final thumbH = h - _inset * 2;

          Widget labels(Color color) => SizedBox(
            width: layout.contentWidth,
            height: thumbH,
            child: Stack(
              children: [
                for (var i = 0; i < layout.length; i++)
                  Positioned(
                    left: layout.lefts[i],
                    top: 0,
                    width: layout.widths[i],
                    height: thumbH,
                    child: _ItemLabel(
                      item: widget.items[i],
                      style: _labelStyle(color),
                      badgeColor: accent,
                    ),
                  ),
              ],
            ),
          );

          final hits = SizedBox(
            width: layout.contentWidth,
            height: thumbH,
            child: Stack(
              children: [
                for (var i = 0; i < layout.length; i++)
                  Positioned(
                    left: layout.lefts[i],
                    top: 0,
                    width: layout.widths[i],
                    height: thumbH,
                    child: Semantics(
                      button: true,
                      selected: i == widget.selected,
                      label: widget.items[i].semanticLabel ??
                          widget.items[i].label,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _select(i),
                        onLongPress: widget.onLongPress == null
                            ? null
                            : () => widget.onLongPress!(i),
                      ),
                    ),
                  ),
              ],
            ),
          );

          final listenables = <Listenable>[
            _spring,
            ?widget.position,
          ];
          Widget content = AnimatedBuilder(
            animation: Listenable.merge(listenables),
            builder: (context, _) {
              final tabs = _tabCount;
              final hasThumb = widget.selected >= 0 &&
                  widget.selected < tabs &&
                  tabs > 0;
              final p = thumbPosition.clamp(0.0, math.max(0, tabs - 1).toDouble());
              final thumb = hasThumb
                  ? glassThumbRect(
                      layout: layout,
                      p: p,
                      top: 0,
                      height: thumbH,
                      stretch: !reduceMotion,
                    )
                  : Rect.zero;
              final thumbR = RRect.fromRectAndRadius(
                thumb,
                Radius.circular(thumbH / 2),
              );
              // Линза капли — только пока она движется или её тащат.
              _lastThumb = hasThumb ? thumb : null;
              final frac = (p - p.roundToDouble()).abs();
              final lift = _drag != null ? 1.0 : (frac * 4).clamp(0.0, 1.0);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _publishThumb();
                _liftForGlass.value = lift;
              });
              return SizedBox(
                width: layout.contentWidth,
                height: thumbH,
                child: Stack(
                  children: [
                    if (hasThumb)
                      Positioned.fromRect(
                        rect: thumb,
                        child: DecoratedBox(
                          decoration: (glass || kNeutralSelectedPill)
                              ? islandSelectedPillDecoration(
                                  isDark: isDark,
                                  radius: thumbH / 2,
                                )
                              : BoxDecoration(
                                  color: accent.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(
                                    thumbH / 2,
                                  ),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.30),
                                    width: 0.8,
                                  ),
                                ),
                        ),
                      ),
                    // Снаружи капли — обычный цвет.
                    IgnorePointer(
                      child: ExcludeSemantics(
                        child: ClipPath(
                          clipper: _OutsideClipper(hasThumb ? thumbR : null),
                          child: labels(normal),
                        ),
                      ),
                    ),
                    // Под каплей — акцентный.
                    if (hasThumb)
                      IgnorePointer(
                        child: ExcludeSemantics(
                          child: ClipRRect(
                            clipper: _RRectClipper(thumbR),
                            child: labels(accent),
                          ),
                        ),
                      ),
                    // Касания и озвучка — отдельным слоем поверх, без обрезки:
                    // выбранный пункт под каплей тоже нажимается (меню папки).
                    hits,
                  ],
                ),
              );
            },
          );

          if (scroll) {
            content = ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [
                  Color(0x00FFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0x00FFFFFF),
                ],
                stops: [0, 0.05, 0.95, 1],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: content,
              ),
            );
          } else {
            // Каплю можно вести пальцем.
            content = GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _tabCount < 2
                  ? null
                  : (d) {
                      _spring.stop();
                      setState(() => _drag = _positionAt(d.localPosition.dx));
                    },
              onHorizontalDragUpdate: _tabCount < 2
                  ? null
                  : (d) => setState(
                      () => _drag = _positionAt(d.localPosition.dx),
                    ),
              onHorizontalDragEnd: _tabCount < 2
                  ? null
                  : (_) {
                      final p = _drag ?? _spring.value;
                      final target = p.round().clamp(0, _tabCount - 1);
                      _spring.value = p;
                      setState(() => _drag = null);
                      if (target != widget.selected) {
                        _select(target);
                      }
                      if (widget.position == null) _springTo(target);
                    },
              onHorizontalDragCancel: () {
                if (_drag == null) return;
                _spring.value = _drag!;
                setState(() => _drag = null);
                if (widget.position == null) _springTo(widget.selected);
              },
              child: content,
            );
          }

          final fallback = FrostedHeaderIsland(
            radius: h / 2,
            height: h,
            padding: const EdgeInsets.all(_inset),
            child: content,
          );
          // 23.11.2026 (владелец): полосы должны быть ровно как основные
          // островки — та же пластина [FrostedHeaderIsland] (со стеклом на
          // iPhone — то же стекло островков). Свой движок давал полосам
          // другой тинт и кромку; вернётся, когда им пойдут ВСЕ островки.
          if (!kSecretlyGlassEngine || !kGlassStripUsesEngine) return fallback;
          // Своё жидкое стекло (план стекла): пластина и капля — один проход.
          return SizedBox(
            height: h,
            child: SecretlyGlassPlate(
              radius: h / 2,
              padding: const EdgeInsets.all(_inset),
              thumb: _thumbForGlass,
              lift: _liftForGlass,
              fallback: fallback,
              child: content,
            ),
          );
        },
      ),
    );
  }
}

class _ItemLabel extends StatelessWidget {
  const _ItemLabel({
    required this.item,
    required this.style,
    required this.badgeColor,
  });

  final GlassStripItem item;
  final TextStyle style;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.icon != null) ...[
            Icon(item.icon, size: 16, color: item.iconColor ?? style.color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              item.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: style,
            ),
          ),
          if (item.badge > 0) ...[
            const SizedBox(width: 5),
            Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                item.badge > 99 ? '99+' : '${item.badge}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Всё, кроме капли.
class _OutsideClipper extends CustomClipper<Path> {
  _OutsideClipper(this.hole);
  final RRect? hole;

  @override
  Path getClip(Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final h = hole;
    if (h == null) return all;
    return Path.combine(PathOperation.difference, all, Path()..addRRect(h));
  }

  @override
  bool shouldReclip(_OutsideClipper old) => old.hole != hole;
}

class _RRectClipper extends CustomClipper<RRect> {
  _RRectClipper(this.rrect);
  final RRect rrect;

  @override
  RRect getClip(Size size) => rrect;

  @override
  bool shouldReclip(_RRectClipper old) => old.rrect != rrect;
}

/// Полоса во всю ширину, привязанная к [TabController] (23.11.2026): капля
/// идёт за свайпом [TabBarView], нажатие листает. Годится и в
/// `AppBar.bottom` — знает свою высоту.
class GlassTabControllerStrip extends StatelessWidget
    implements PreferredSizeWidget {
  const GlassTabControllerStrip({
    super.key,
    required this.controller,
    required this.labels,
    this.padding = const EdgeInsets.fromLTRB(14, 4, 14, 8),
    this.height = 40,
  });

  final TabController controller;
  final List<String> labels;
  final EdgeInsets padding;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height + padding.vertical);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => GlassCategoryStrip(
          items: [for (final l in labels) GlassStripItem(label: l)],
          selected: controller.index,
          position: controller.animation,
          onSelect: controller.animateTo,
          height: height,
          margin: EdgeInsets.only(left: padding.left, right: padding.right),
        ),
      ),
    );
  }
}
