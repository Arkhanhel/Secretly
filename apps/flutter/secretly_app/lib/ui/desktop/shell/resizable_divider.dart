// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/motion.dart';

/// Draggable edge between two panes.
///
/// Desktop panes were fixed at 300 and 360 logical pixels, which is a phone
/// habit: on a wide screen the chat list is needlessly narrow for long room
/// names, and on a small laptop it steals width the conversation needs. Every
/// desktop messenger lets you drag this edge, and its absence is felt
/// immediately.
///
/// The hit area is deliberately wider than the visible line — a 1px target is
/// unusable with a mouse — and the line only tints while hovered or dragged so
/// the seam stays quiet when nobody is aiming at it.
class ResizableDivider extends StatefulWidget {
  const ResizableDivider({
    super.key,
    required this.onDelta,
    this.onReset,
    this.onDragStart,
    this.onDragEnd,
    this.hitWidth = 8,
    this.showIdleLine = true,
    this.lineCenter,
  });

  /// Где внутри области захвата стоит середина линии, в точках от её левого
  /// края. `null` — посередине.
  ///
  /// Нужна, когда область захвата лежит несимметрично относительно шва: у
  /// списка она почти целиком заходит на переписку, чтобы не отнимать у
  /// списка край, где появляется полоса прокрутки.
  final double? lineCenter;

  /// Horizontal drag delta in logical pixels. Positive means "to the right";
  /// the parent decides whether that grows or shrinks its pane.
  final ValueChanged<double> onDelta;

  /// Двойной щелчок по краю — вернуть колонке ширину по умолчанию.
  ///
  /// Обычай настольных программ: растянутую до неудобного колонку проще
  /// сбросить, чем вымерять обратно на глаз.
  final VoidCallback? onReset;

  /// Перетаскивание началось. Тому, кто мерит край от курсора, здесь пора
  /// начать отсчёт заново — даже если конец прошлого жеста потерялся.
  final VoidCallback? onDragStart;

  /// Перетаскивание закончилось (или сорвалось).
  final VoidCallback? onDragEnd;
  final double hitWidth;

  /// Рисовать ли тонкую линию, пока край никто не трогает.
  ///
  /// `false` — когда край НАЛОЖЕН поверх уже нарисованного шва (список ↔
  /// переписка): там линия своя, и вторая, сдвинутая на долю точки, двоилась
  /// бы. Подсветка при наведении и перетаскивании остаётся.
  final bool showIdleLine;

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final active = _hovered || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Отсчёт — от точки НАЖАТИЯ: иначе первые точки движения уходят на
        // распознавание жеста, и край отстаёт от курсора на этот порог.
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (_) {
          widget.onDragStart?.call();
          setState(() => _dragging = true);
        },
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onDragEnd?.call();
        },
        onHorizontalDragCancel: () {
          setState(() => _dragging = false);
          widget.onDragEnd?.call();
        },
        onHorizontalDragUpdate: (d) => widget.onDelta(d.delta.dx),
        onDoubleTap: widget.onReset,
        child: SizedBox(
          width: widget.hitWidth,
          child: _line(c, active),
        ),
      ),
    );
  }

  Widget _line(DColorSet c, bool active) {
    final width = active ? 2.0 : 1.0;
    final line = AnimatedContainer(
      duration: DMotion.fast,
      width: width,
      color: active
          ? c.accentPrimary
          : (widget.showIdleLine ? c.borderSubtle : Colors.transparent),
    );
    final center = widget.lineCenter;
    if (center == null) return Center(child: line);
    return Stack(
      children: [
        Positioned(
          top: 0,
          bottom: 0,
          left: center - width / 2,
          child: line,
        ),
      ],
    );
  }
}
