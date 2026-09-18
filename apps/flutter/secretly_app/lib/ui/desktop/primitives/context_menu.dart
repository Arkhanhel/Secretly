// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import 'hover_listener.dart';

class CtxMenuItem {
  const CtxMenuItem({
    required this.label,
    this.icon,
    this.shortcut,
    this.onTap,
    this.isDanger = false,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
  final String? shortcut;
  final VoidCallback? onTap;
  final bool isDanger;
  final bool enabled;
}

class ContextMenu {
  ContextMenu._();

  /// Opens a menu anchored to a global offset (e.g. cursor on right-click).
  ///
  /// PR3.8 (SPRINT2_AUDIT §13): [headerBuilder] mounts an extra floating
  /// card directly ABOVE the menu items (with a 6 px gap). Used by the
  /// message context menu to surface the quick-reactions row right above
  /// the menu — matches Telegram desktop's right-click flow where the row
  /// of reactions floats above the menu like a tooltip.
  /// The builder receives a callback that lets the header dismiss the
  /// surrounding menu programmatically (used when the user picks an
  /// emoji — we want the menu to vanish with the picker).
  static Future<void> show(
    BuildContext context, {
    required Offset globalPosition,
    required List<List<CtxMenuItem>> sections,
    double width = 220,
    Widget Function(BuildContext ctx, VoidCallback dismiss)? headerBuilder,
  }) {
    return showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'ctx',
      transitionDuration: DMotion.fast,
      pageBuilder: (ctx, a, b) {
        return _CtxScaffold(
          position: globalPosition,
          sections: sections,
          width: width,
          animation: a,
          headerBuilder: headerBuilder,
        );
      },
      transitionBuilder: (ctx, a, b, child) => child,
    );
  }
}

class _CtxScaffold extends StatelessWidget {
  const _CtxScaffold({
    required this.position,
    required this.sections,
    required this.width,
    required this.animation,
    this.headerBuilder,
  });
  final Offset position;
  final List<List<CtxMenuItem>> sections;
  final double width;
  final Animation<double> animation;
  final Widget Function(BuildContext ctx, VoidCallback dismiss)? headerBuilder;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final screen = MediaQuery.of(context).size;

    // Estimate menu height conservatively (~32 per item + 1 per divider +
    // paddings) so we can decide whether to flip vertically.
    final itemCount = sections.fold<int>(0, (a, s) => a + s.length);
    final menuHeight = itemCount * 32.0 + (sections.length - 1) * 9 + 12;
    // Reserve space above the menu for the optional reactions header.
    const headerHeight = 52.0;
    const headerGap = 6.0;
    final totalHeight = headerBuilder != null
        ? menuHeight + headerGap + headerHeight
        : menuHeight;

    double x = position.dx;
    double y = position.dy;
    if (x + width > screen.width - 8) x = screen.width - width - 8;
    if (y + totalHeight > screen.height - 8) {
      y = (screen.height - totalHeight - 8).clamp(8.0, double.infinity);
    }
    // If a header is requested, shift the WHOLE stack down by headerHeight
    // so the y we computed corresponds to the header's top — the menu sits
    // headerHeight + headerGap below that.
    final headerTop = y;
    final menuTop = headerBuilder != null ? y + headerHeight + headerGap : y;

    void dismiss() => Navigator.of(context).maybePop();

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
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox.expand(),
            ),
            if (headerBuilder != null)
              Positioned(
                left: x,
                top: headerTop,
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (ctx, _) {
                    return Opacity(
                      opacity: animation.value,
                      child: Transform.scale(
                        scale: 0.96 + 0.04 * animation.value,
                        alignment: Alignment.bottomLeft,
                        // No SizedBox here — the header sizes to its own
                        // intrinsic width (the reactions row is usually
                        // wider than the menu and may overflow on the
                        // right; the dismiss tap handles that gracefully).
                        child: headerBuilder!(ctx, dismiss),
                      ),
                    );
                  },
                ),
              ),
            Positioned(
              left: x,
              top: menuTop,
              child: AnimatedBuilder(
                animation: animation,
                builder: (ctx, _) {
                  return Opacity(
                    opacity: animation.value,
                    child: Transform.scale(
                      scale: 0.96 + 0.04 * animation.value,
                      alignment: Alignment.topLeft,
                      child: _CtxCard(c: c, sections: sections, width: width),
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

class _CtxCard extends StatelessWidget {
  const _CtxCard({
    required this.c,
    required this.sections,
    required this.width,
  });
  final DColorSet c;
  final List<List<CtxMenuItem>> sections;
  final double width;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (int i = 0; i < sections.length; i++) {
      if (i > 0) {
        children.add(
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: c.borderHairline,
          ),
        );
      }
      for (final item in sections[i]) {
        children.add(_CtxRow(item: item));
      }
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: c.elevated,
          borderRadius: BorderRadius.circular(DRadii.md),
          // Рамка меню — .12 из макета: единственная граница, которая обязана
          // быть видна сама по себе, меню всплывает поверх чужого содержимого.
          border: Border.all(color: c.borderMenu),
          boxShadow: DShadows.popover,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _CtxRow extends StatelessWidget {
  const _CtxRow({required this.item});
  final CtxMenuItem item;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final fg = !item.enabled
        ? c.textDisabled
        : (item.isDanger ? c.danger : c.textPrimary);

    return HoverListener(
      onTap: !item.enabled
          ? null
          : () {
              // 🔴 СНАЧАЛА закрыть меню, ПОТОМ выполнить действие — и именно в
              // таком порядке, а не «оба подряд».
              //
              // Было: `maybePop()` и сразу вызов. Но `maybePop` асинхронный —
              // он ждёт разрешения маршрута и снимает его в микрозадаче, уже
              // ПОСЛЕ того как действие отработало. Если действие открывало
              // окно, к моменту снятия наверху стека оказывалось оно, и
              // закрывалось не меню, а окно; меню же оставалось висеть поверх
              // интерфейса до следующего щелчка мимо.
              //
              // Поймать это можно было только пунктом, который открывает окно,
              // — а такой появился лишь 13.09 («Новый чат»). Все прежние
              // пункты что-то тихо делали и расходились с меню без спора.
              //
              // `pop()` снимает синхронно и именно это меню. Действие уходит
              // за кадр: к моменту вызова меню уже не в дереве, и открывать
              // окна можно без оглядки.
              final navigator = Navigator.of(context);
              final action = item.onTap;
              navigator.pop();
              if (action == null) return;
              WidgetsBinding.instance.addPostFrameCallback((_) => action());
            },
      cursor: item.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      builder: (ctx, hovered, pressed) {
        Color bg = Colors.transparent;
        if (item.enabled && hovered) {
          bg = item.isDanger ? c.danger.withValues(alpha: 0.12) : c.hover;
        }
        return Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: bg,
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 16, color: fg),
                const SizedBox(width: 10),
              ] else
                const SizedBox(width: 26),
              Expanded(
                child: Text(
                  item.label,
                  style: DType.label.copyWith(color: fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.shortcut != null)
                Text(
                  item.shortcut!,
                  style: DType.caption.copyWith(color: c.textDisabled),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}
