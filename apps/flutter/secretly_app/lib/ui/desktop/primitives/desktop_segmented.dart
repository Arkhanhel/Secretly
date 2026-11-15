// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'hover_listener.dart';

/// Сегментированный переключатель из макета: несколько взаимоисключающих
/// значений в одной плашке.
///
/// 🔴 ЗАЧЕМ ОН, КОГДА ЕСТЬ ТУМБЛЕР.
///
/// Тумблер отвечает только «да/нет». Как только значений становится три —
/// «Тёмная», «Светлая», «Авто» — тумблер либо врёт (прячет третье), либо
/// плодит вторую строку «следовать системе», и человек остаётся гадать, что
/// победит при споре двух переключателей.
///
/// Сегменты показывают все значения сразу и то, какое выбрано, — одним
/// взглядом и без чтения.
///
/// Геометрия из макета: плашка с полем 3, радиус 9, сегмент высотой 22,
/// выбранный залит белым с альфой .12, подпись 11/700.
class DesktopSegmented<T> extends StatefulWidget {
  const DesktopSegmented({
    super.key,
    required this.values,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  final List<T> values;
  final List<String> labels;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  State<DesktopSegmented<T>> createState() => _DesktopSegmentedState<T>();
}

/// 🔴 ВЫБОР ПЕРЕЕЗЖАЕТ, А НЕ ЗАГОРАЕТСЯ (05.10.2026, «плавно и дорого»).
///
/// Подложка выбранного значения — одна на весь переключатель и скользит к
/// новому значению. Пока размеры сегментов не измерены (первый кадр),
/// подложку рисует сам выбранный сегмент — без вспышки и без прыжка.
class _DesktopSegmentedState<T> extends State<DesktopSegmented<T>> {
  final GlobalKey _stackKey = GlobalKey();
  List<GlobalKey> _keys = const <GlobalKey>[];
  List<Rect>? _rects;

  void _syncKeys() {
    if (_keys.length != widget.values.length) {
      _keys = List<GlobalKey>.generate(
        widget.values.length,
        (_) => GlobalKey(),
      );
      _rects = null;
    }
  }

  void _measure(Duration _) {
    if (!mounted) return;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || !stack.hasSize) return;
    final rects = <Rect>[];
    for (final k in _keys) {
      final box = k.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final topLeft = box.localToGlobal(Offset.zero, ancestor: stack);
      rects.add(topLeft & box.size);
    }
    final old = _rects;
    var same = old != null && old.length == rects.length;
    for (var i = 0; same && i < rects.length; i++) {
      same = (old![i].left - rects[i].left).abs() < 0.5 &&
          (old[i].width - rects[i].width).abs() < 0.5;
    }
    if (!same) setState(() => _rects = rects);
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    assert(widget.values.length == widget.labels.length);
    _syncKeys();
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    final ink = c.isDark ? Colors.white : Colors.black;
    final activeFill = ink.withValues(alpha: c.isDark ? 0.12 : 0.10);
    final activeIndex = widget.values.indexOf(widget.value);
    final rects = _rects;
    final pillRect =
        rects != null && activeIndex >= 0 && activeIndex < rects.length
        ? rects[activeIndex]
        : null;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Stack(
        key: _stackKey,
        children: [
          if (pillRect != null)
            AnimatedPositioned(
              duration: DMotion.of(context, DMotion.glide),
              curve: DMotion.glideCurve,
              left: pillRect.left,
              top: pillRect.top,
              width: pillRect.width,
              height: pillRect.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: activeFill,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.values.length; i++)
                HoverListener(
                  key: _keys[i],
                  onTap: () => widget.onChanged(widget.values[i]),
                  cursor: SystemMouseCursors.click,
                  builder: (ctx, hovered, pressed) {
                    final active = widget.values[i] == widget.value;
                    return AnimatedContainer(
                      duration: DMotion.fast,
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? (pillRect == null
                                  ? activeFill
                                  : Colors.transparent)
                            : (hovered
                                  ? ink.withValues(alpha: 0.06)
                                  : Colors.transparent),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: AnimatedDefaultTextStyle(
                        duration: DMotion.of(ctx, DMotion.base),
                        curve: DMotion.standard,
                        style: DType.tiny.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active ? c.textPrimary : c.textSecondary,
                        ),
                        child: Text(widget.labels[i]),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
