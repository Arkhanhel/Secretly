// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';

enum PopoverSide { above, below, left, right }

class DesktopPopover {
  DesktopPopover._();

  /// Anchors a popover next to [anchorKey]. Auto-flips if it doesn't fit.
  static Future<T?> show<T>(
    BuildContext context, {
    required GlobalKey anchorKey,
    required Widget child,
    PopoverSide side = PopoverSide.below,
    double offset = 8,
    double width = 360,
    double maxHeight = 420,
  }) => showFrom<T>(
    context,
    anchorContext: anchorKey.currentContext,
    child: child,
    side: side,
    offset: offset,
    width: width,
    maxHeight: maxHeight,
  );

  /// То же, но якорь задан КОНТЕКСТОМ, а не ключом.
  ///
  /// 🔴 Нужен там, где якорей много и они недолговечны — например, у каждой
  /// строки списка участников. Заводить `GlobalKey` на строку нельзя: строки
  /// перестраиваются, новый ключ на каждой перестройке заново пересаживает
  /// поддерево, а хранить ключ — значит делать строку `StatefulWidget` ради
  /// одного всплывающего окна. Контекст строки у вызывающего уже есть.
  static Future<T?> showFrom<T>(
    BuildContext context, {
    required BuildContext? anchorContext,
    required Widget child,
    PopoverSide side = PopoverSide.below,
    double offset = 8,
    double width = 360,
    double maxHeight = 420,
  }) {
    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox?;
    final anchorBox = anchorContext?.findRenderObject() as RenderBox?;
    if (overlay == null || anchorBox == null) return Future.value(null);

    final anchorTopLeft = anchorBox.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final anchorSize = anchorBox.size;
    final screenSize = overlay.size;

    Offset pos = _positionFor(
      side,
      anchorTopLeft,
      anchorSize,
      Size(width, maxHeight),
      offset,
    );
    pos = _clampAndFlip(
      pos,
      Size(width, maxHeight),
      screenSize,
      anchorTopLeft,
      anchorSize,
      side,
      offset,
    );

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'popover',
      barrierColor: Colors.transparent,
      transitionDuration: DMotion.fast,
      pageBuilder: (ctx, a, b) {
        return _PopoverScaffold(
          position: pos,
          width: width,
          maxHeight: maxHeight,
          animation: a,
          side: side,
          child: child,
        );
      },
      transitionBuilder: (ctx, a, b, child) => child,
    );
  }

  static Offset _positionFor(
    PopoverSide side,
    Offset anchorTL,
    Size anchorSize,
    Size popSize,
    double gap,
  ) {
    switch (side) {
      case PopoverSide.above:
        return Offset(
          anchorTL.dx + anchorSize.width / 2 - popSize.width / 2,
          anchorTL.dy - popSize.height - gap,
        );
      case PopoverSide.below:
        return Offset(
          anchorTL.dx + anchorSize.width / 2 - popSize.width / 2,
          anchorTL.dy + anchorSize.height + gap,
        );
      case PopoverSide.left:
        return Offset(
          anchorTL.dx - popSize.width - gap,
          anchorTL.dy + anchorSize.height / 2 - popSize.height / 2,
        );
      case PopoverSide.right:
        return Offset(
          anchorTL.dx + anchorSize.width + gap,
          anchorTL.dy + anchorSize.height / 2 - popSize.height / 2,
        );
    }
  }

  static Offset _clampAndFlip(
    Offset pos,
    Size popSize,
    Size screen,
    Offset anchorTL,
    Size anchorSize,
    PopoverSide side,
    double gap,
  ) {
    double x = pos.dx;
    double y = pos.dy;
    if (y < 8) {
      // flip below
      y = anchorTL.dy + anchorSize.height + gap;
    }
    if (y + popSize.height > screen.height - 8) {
      // flip above
      y = anchorTL.dy - popSize.height - gap;
    }
    x = x.clamp(8.0, screen.width - popSize.width - 8.0);
    y = y.clamp(8.0, screen.height - popSize.height - 8.0);
    return Offset(x, y);
  }
}

class _PopoverScaffold extends StatelessWidget {
  const _PopoverScaffold({
    required this.position,
    required this.width,
    required this.maxHeight,
    required this.animation,
    required this.side,
    required this.child,
  });

  final Offset position;
  final double width;
  final double maxHeight;
  final Animation<double> animation;
  final PopoverSide side;
  final Widget child;

  Alignment _origin() {
    switch (side) {
      case PopoverSide.above:
        return Alignment.bottomCenter;
      case PopoverSide.below:
        return Alignment.topCenter;
      case PopoverSide.left:
        return Alignment.centerRight;
      case PopoverSide.right:
        return Alignment.centerLeft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _DismissIntent(),
      },
      child: Actions(
        actions: {
          _DismissIntent: CallbackAction<_DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Stack(
          children: [
            // Dismiss on tap outside.
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox.expand(),
            ),
            Positioned(
              left: position.dx,
              top: position.dy,
              child: AnimatedBuilder(
                animation: animation,
                builder: (ctx, _) {
                  final t = Curves.easeOutBack.transform(
                    animation.value.clamp(0.0, 1.0),
                  );
                  return Opacity(
                    opacity: animation.value,
                    child: Transform.scale(
                      scale: 0.96 + 0.04 * t,
                      alignment: _origin(),
                      child: _PopoverCard(
                        c: c,
                        width: width,
                        maxHeight: maxHeight,
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopoverCard extends StatelessWidget {
  const _PopoverCard({
    required this.c,
    required this.width,
    required this.maxHeight,
    required this.child,
  });
  final DColorSet c;
  final double width;
  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: c.elevated,
          borderRadius: BorderRadius.circular(DRadii.md),
          border: Border.all(color: c.borderSubtle),
          boxShadow: DShadows.popover,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}
