// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import 'desktop_button.dart';
import 'motion_widgets.dart';

enum DDialogSize { small, medium, large, auto }

class DDialogAction {
  const DDialogAction({
    required this.label,
    required this.onPressed,
    this.kind = DButtonKind.filled,
  });

  final String label;
  final VoidCallback? onPressed;
  final DButtonKind kind;
}

class DesktopDialog {
  DesktopDialog._();

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget body,
    String? title,
    DDialogSize size = DDialogSize.medium,
    DDialogAction? primary,
    DDialogAction? secondary,
    bool barrierDismissible = true,
    bool useBlur = true,
  }) {
    // Палитра места вызова едет в окно — см. [DColors.carry].
    final palette = DColors.maybeOf(context);
    // 🔴 05.10.2026: маршрут со своим уходом (короче входа), а масштаб —
    // только у карточки. Раньше переход масштабировал ВЕСЬ слой вместе с
    // затемнением и с отскоком (easeOutBack): по краям окна на мгновение
    // проступало незатемнённое, а сама карточка подпрыгивала.
    return showDesktopOverlay<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'dialog',
      pageBuilder: (ctx, a, b) {
        return DColors.carry(
          palette,
          _DialogScaffold(
            animation: a,
            title: title,
            body: body,
            size: size,
            primary: primary,
            secondary: secondary,
            barrierDismissible: barrierDismissible,
            useBlur: useBlur,
          ),
        );
      },
    );
  }
}

class _DialogScaffold extends StatelessWidget {
  const _DialogScaffold({
    required this.animation,
    required this.title,
    required this.body,
    required this.size,
    required this.primary,
    required this.secondary,
    required this.barrierDismissible,
    required this.useBlur,
  });

  final Animation<double> animation;
  final String? title;
  final Widget body;
  final DDialogSize size;
  final DDialogAction? primary;
  final DDialogAction? secondary;
  final bool barrierDismissible;
  final bool useBlur;

  double _width(double w) {
    switch (size) {
      case DDialogSize.small:
        return 380;
      case DDialogSize.medium:
        return 520;
      case DDialogSize.large:
        return 720;
      case DDialogSize.auto:
        return (w * 0.5).clamp(380.0, 720.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final w = MediaQuery.of(context).size.width;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _DismissIntent(),
      },
      child: Actions(
        actions: {
          _DismissIntent: CallbackAction<_DismissIntent>(
            onInvoke: (_) {
              if (barrierDismissible) Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: FocusScope(
          autofocus: true,
          child: Stack(
            children: [
              Semantics(
                button: true,
                label: MaterialLocalizations.of(
                  context,
                ).modalBarrierDismissLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: barrierDismissible
                      ? () => Navigator.of(context).maybePop()
                      : null,
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (ctx, _) {
                      final t = DMotion.eased(
                        animation,
                        inCurve: DMotion.standard,
                      );
                      return BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: useBlur ? 8 * t : 0,
                          sigmaY: useBlur ? 8 * t : 0,
                        ),
                        child: Container(
                          color: c.scrim.withValues(alpha: 0.45 * t),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Center(
                child: GestureDetector(
                  onTap: () {}, // swallow taps so they don't dismiss
                  child: DPopTransition(
                    animation: animation,
                    fromScale: 0.95,
                    fromOffset: const Offset(0, 14),
                    child: Container(
                      width: _width(w),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.85,
                      ),
                      decoration: BoxDecoration(
                        color: c.elevated,
                        borderRadius: BorderRadius.circular(DRadii.lg),
                        border: Border.all(color: c.borderSubtle),
                        boxShadow: DShadows.dialog,
                      ),
                      // 🔴 Material в основании окна — не украшение, а условие
                      // работоспособности.
                      //
                      // Диалог открывается отдельным маршрутом поверх дерева и
                      // Material от приложения с собой не приносит. А любое поле
                      // ввода — это TextField, и он ищет Material в предках:
                      // без него диалог падает на первой же попытке показать
                      // поле.
                      //
                      // Так и жил диалог создания темы: он НИКОГДА не работал,
                      // и увидеть это можно было только открыв его руками —
                      // разметка выглядит совершенно обычной.
                      //
                      // Ставим здесь, в основании, а не у каждого поля: иначе
                      // следующий диалог с полем повторит ту же ошибку, и
                      // обнаружится она так же поздно. Прозрачный, чтобы не
                      // перекрыть собственный фон и скругление карточки.
                      child: Material(
                        type: MaterialType.transparency,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (title != null) _DialogHeader(title: title!),
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  DSpace.xl2,
                                  DSpace.l,
                                  DSpace.xl2,
                                  DSpace.l,
                                ),
                                child: SingleChildScrollView(child: body),
                              ),
                            ),
                            if (primary != null || secondary != null)
                              _DialogFooter(
                                primary: primary,
                                secondary: secondary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DSpace.xl2,
        DSpace.l,
        DSpace.m,
        DSpace.m,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: DType.title.copyWith(color: c.textPrimary),
            ),
          ),
          DesktopIconButton(
            icon: Icons.close_rounded,
            tooltip: AppLocalizations.of(context)?.close,
            onPressed: () => Navigator.of(context).maybePop(),
            size: 32,
            iconSize: 16,
          ),
        ],
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({required this.primary, required this.secondary});
  final DDialogAction? primary;
  final DDialogAction? secondary;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DSpace.xl2,
        DSpace.m,
        DSpace.xl2,
        DSpace.l,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.borderSubtle)),
      ),
      // 🔴 Перенос, а не ряд (30.09.2026): «Отмена» и «Выйти и удалить» не
      // помещались в малое окно — ряд вылезал за край на 20 точек, а по-
      // немецки и того больше. Не влезли — главная кнопка уходит строкой
      // ниже, прижатая вправо.
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: DSpace.s,
          runSpacing: DSpace.s,
          children: [
            if (secondary != null)
              DesktopButton(
                label: secondary!.label,
                onPressed: secondary!.onPressed,
                kind: secondary!.kind == DButtonKind.filled
                    ? DButtonKind.ghost
                    : secondary!.kind,
              ),
            if (primary != null)
              DesktopButton(
                label: primary!.label,
                onPressed: primary!.onPressed,
                kind: primary!.kind,
              ),
          ],
        ),
      ),
    );
  }
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}

/// Замена `showDialog` для окон ПК на материальных `AlertDialog` и своих
/// виджетах (05.10.2026): та же подача, что у [DesktopDialog.show] — фон
/// плавно темнеет, карточка поднимается и проявляется, уход короче входа.
///
/// Как и `showDialog`, переносит в окно темы места вызова и палитру ПК.
Future<T?> showDesktopDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
}) {
  final palette = DColors.maybeOf(context);
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  return showDesktopOverlay<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor:
        barrierColor ??
        (palette?.scrim ?? Colors.black).withValues(alpha: 0.5),
    pageBuilder: (ctx, animation, _) => DColors.carry(
      palette,
      themes.wrap(
        DPopTransition(
          animation: animation,
          fromScale: 0.95,
          fromOffset: const Offset(0, 14),
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
}
