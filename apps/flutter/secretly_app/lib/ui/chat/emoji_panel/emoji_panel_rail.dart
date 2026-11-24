// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Верхняя рейка панели: значки разделов и подсветка-пилюля, которая едет за
/// прокруткой (слушает [ValueListenable] номера раздела — без `setState` на
/// кадр) и плавно переезжает (`cubic-bezier(.3,1.3,.5,1)` 450 мс).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'emoji_panel_style.dart';
import 'emoji_panel_widgets.dart';

class PanelRail extends StatefulWidget {
  const PanelRail({
    super.key,
    required this.style,
    required this.count,
    required this.active,
    required this.itemBuilder,
    required this.onTap,
    this.onLongPress,
    this.indicatorHeight = 36,
    this.indicatorRadius = 18,
    this.minItemWidth = 36,
    this.semanticLabels,
  });

  final EmojiPanelStyle style;
  final int count;
  final ValueListenable<int> active;
  final Widget Function(BuildContext context, int index, bool active)
  itemBuilder;
  final ValueChanged<int> onTap;
  final ValueChanged<int>? onLongPress;
  final double indicatorHeight;
  final double indicatorRadius;
  final double minItemWidth;
  final List<String>? semanticLabels;

  @override
  State<PanelRail> createState() => _PanelRailState();
}

class _PanelRailState extends State<PanelRail> {
  final ScrollController _scroll = ScrollController();
  double _itemW = 40;
  double _viewport = 0;

  @override
  void initState() {
    super.initState();
    widget.active.addListener(_keepVisible);
  }

  @override
  void didUpdateWidget(covariant PanelRail old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      old.active.removeListener(_keepVisible);
      widget.active.addListener(_keepVisible);
    }
  }

  @override
  void dispose() {
    widget.active.removeListener(_keepVisible);
    _scroll.dispose();
    super.dispose();
  }

  /// Подсвеченный значок не уезжает за край прокручиваемой рейки.
  void _keepVisible() {
    if (!_scroll.hasClients || _scroll.position.maxScrollExtent <= 0) return;
    final i = widget.active.value;
    final left = 8 + i * _itemW;
    final right = left + _itemW;
    final pos = _scroll.position;
    double? to;
    if (left < pos.pixels + 8) {
      to = left - 8;
    } else if (right > pos.pixels + _viewport - 8) {
      to = right - _viewport + 8;
    }
    if (to == null) return;
    _scroll.animateTo(
      to.clamp(0, pos.maxScrollExtent),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.maxWidth;
        final n = math.max(1, widget.count);
        final fit = (constraints.maxWidth - 16) / n;
        _itemW = math.max(widget.minItemWidth, fit);
        final contentW = 16 + _itemW * widget.count;
        final top = (44 - widget.indicatorHeight) / 2;
        final row = SizedBox(
          width: math.max(contentW, constraints.maxWidth),
          height: 44,
          child: ValueListenableBuilder<int>(
            valueListenable: widget.active,
            builder: (context, active, _) {
              final a = active.clamp(0, math.max(0, widget.count - 1));
              return Stack(
                children: [
                  if (widget.count > 0)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 450),
                      curve: kPanelRailCurve,
                      left: 8 + a * _itemW,
                      top: top,
                      width: _itemW,
                      height: widget.indicatorHeight,
                      child: DecoratedBox(
                        key: const ValueKey('emoji-panel:rail-indicator'),
                        decoration: BoxDecoration(
                          color: s.railInd,
                          borderRadius: BorderRadius.circular(
                            widget.indicatorRadius,
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    left: 8,
                    right: 8,
                    child: Row(
                      children: [
                        for (var i = 0; i < widget.count; i++)
                          SizedBox(
                            width: _itemW,
                            height: 44,
                            child: Semantics(
                              button: true,
                              selected: i == a,
                              label: widget.semanticLabels != null &&
                                      i < widget.semanticLabels!.length
                                  ? widget.semanticLabels![i]
                                  : null,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => widget.onTap(i),
                                onLongPress: widget.onLongPress == null
                                    ? null
                                    : () => widget.onLongPress!(i),
                                child: PanelPress(
                                  child: Center(
                                    child: widget.itemBuilder(context, i, i == a),
                                  ),
                                ),
                              ),
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
        if (contentW <= constraints.maxWidth + .5) return row;
        return SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: row,
        );
      },
    );
  }
}

/// Значок рейки: заливка у выбранного, цвет — с переходом 250 мс.
class PanelRailIcon extends StatelessWidget {
  const PanelRailIcon({
    super.key,
    required this.style,
    required this.icon,
    required this.activeIcon,
    required this.active,
    this.size = 21,
  });

  final EmojiPanelStyle style;
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: active ? style.on : style.off),
      duration: const Duration(milliseconds: 250),
      builder: (context, c, _) =>
          Icon(active ? activeIcon : icon, size: size, color: c),
    );
  }
}
