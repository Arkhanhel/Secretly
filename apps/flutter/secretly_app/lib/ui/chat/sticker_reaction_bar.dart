// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Плашка реакций над листом набора стикеров (21.11.2026, владелец: «при
/// нажатии на стикеры — плашка с реакциями вместе с нижней панелью
/// просмотра стикерпака»).
///
/// Стеклянная капсула, как панель реакций меню: эмодзи появляются каскадом
/// с пружиной, своя реакция подсвечена. Выбор отдаёт эмодзи и его место на
/// экране — оттуда реакция летит к сообщению.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/apple_menu.dart';

class StickerReactionBar extends StatefulWidget {
  const StickerReactionBar({
    super.key,
    required this.emojis,
    required this.onPick,
    required this.emojiBuilder,
    this.selected,
  });

  final List<String> emojis;
  final String? selected;
  final Widget Function(String emoji) emojiBuilder;

  /// Эмодзи и его прямоугольник на экране (начало полёта).
  final void Function(String emoji, Rect cell) onPick;

  @override
  State<StickerReactionBar> createState() => _StickerReactionBarState();
}

class _StickerReactionBarState extends State<StickerReactionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();
  final Map<String, GlobalKey> _keys = {};
  bool _picked = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _pick(String e) {
    if (_picked) return;
    _picked = true;
    HapticFeedback.selectionClick();
    final box = _keys[e]?.currentContext?.findRenderObject();
    final rect = box is RenderBox && box.hasSize && box.attached
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.zero;
    widget.onPick(e, rect);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final n = widget.emojis.length;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < n; i++)
          _cell(
            widget.emojis[i],
            reduce
                ? const AlwaysStoppedAnimation<double>(1)
                : CurvedAnimation(
                    parent: _c,
                    curve: Interval(
                      (0.05 + i * 0.06).clamp(0.0, 0.7),
                      (0.55 + i * 0.06).clamp(0.3, 1.0),
                      curve: Curves.elasticOut,
                    ),
                  ),
            cs,
          ),
      ],
    );
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: FittedBox(fit: BoxFit.scaleDown, child: row),
    );
    final Widget capsule = appleMenusEnabled(context)
        ? ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: AppleMenuPanel(child: padded),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: dark ? 0.82 : 0.9),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.34),
                  ),
                ),
                child: padded,
              ),
            ),
          );
    return ScaleTransition(
      scale: reduce
          ? const AlwaysStoppedAnimation<double>(1)
          : CurvedAnimation(
              parent: _c,
              curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
            ),
      alignment: Alignment.bottomCenter,
      child: Center(child: capsule),
    );
  }

  Widget _cell(String e, Animation<double> appear, ColorScheme cs) {
    final key = _keys.putIfAbsent(e, GlobalKey.new);
    final isSelected = e == widget.selected;
    return Semantics(
      button: true,
      selected: isSelected,
      label: e,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(e),
        child: ScaleTransition(
          scale: appear,
          child: Container(
            key: key,
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: isSelected
                ? BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  )
                : null,
            child: SizedBox(
              width: 30,
              height: 30,
              child: widget.emojiBuilder(e),
            ),
          ),
        ),
      ),
    );
  }
}
