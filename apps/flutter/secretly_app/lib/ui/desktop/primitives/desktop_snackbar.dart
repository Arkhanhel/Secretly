// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../design/tokens.dart';

enum DSnackKind { info, success, warning, error }

class DesktopSnackbar {
  DesktopSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    DSnackKind kind = DSnackKind.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    showIn(
      Overlay.of(context, rootOverlay: true),
      message: message,
      kind: kind,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// То же самое, но в ЗАРАНЕЕ ИЗВЕСТНЫЙ слой.
  ///
  /// 🔴 Нужно тому, кто строит само приложение.
  ///
  /// `Overlay.of` ищет слой среди ПРЕДКОВ контекста. У корня, который строит
  /// `MaterialApp`, предков-слоёв нет вовсе; не помогает и контекст навигатора
  /// или самого `Overlay` — оба лежат ВЫШЕ слоя, а не внутри него. Попытка
  /// показать что-либо оттуда падает «No Overlay widget found», причём молча:
  /// вызов асинхронный, исключение уходит в неперехваченные, и снаружи это
  /// выглядит ровно как прежнее отсутствие ответа.
  ///
  /// `NavigatorState.overlay` отдаёт слой напрямую — искать его не нужно.
  static void showIn(
    OverlayState overlay, {
    required String message,
    DSnackKind kind = DSnackKind.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final entry = OverlayEntry(
      builder: (ctx) {
        return _SnackbarLayer(
          message: message,
          kind: kind,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction,
        );
      },
    );
    overlay.insert(entry);
    Future.delayed(duration + const Duration(milliseconds: 400), () {
      if (entry.mounted) entry.remove();
    });
  }
}

class _SnackbarLayer extends StatefulWidget {
  const _SnackbarLayer({
    required this.message,
    required this.kind,
    required this.duration,
    this.actionLabel,
    this.onAction,
  });
  final String message;
  final DSnackKind kind;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_SnackbarLayer> createState() => _SnackbarLayerState();
}

class _SnackbarLayerState extends State<_SnackbarLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: DMotion.medium,
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(widget.duration, () {
      if (mounted) _c.reverse();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  IconData _icon() {
    switch (widget.kind) {
      case DSnackKind.success:
        return Icons.check_circle_rounded;
      case DSnackKind.warning:
        return Icons.warning_amber_rounded;
      case DSnackKind.error:
        return Icons.error_rounded;
      case DSnackKind.info:
        return Icons.info_outline_rounded;
    }
  }

  Color _iconColor(DColorSet c) {
    switch (widget.kind) {
      case DSnackKind.success:
        return c.success;
      case DSnackKind.warning:
        return c.warning;
      case DSnackKind.error:
        return c.danger;
      case DSnackKind.info:
        return c.accentPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return Positioned(
      right: 24,
      bottom: 24,
      child: AnimatedBuilder(
        animation: _c,
        builder: (ctx, _) {
          final t = DMotion.easeOutCubic.transform(_c.value);
          return Opacity(
            opacity: _c.value,
            child: Transform.translate(
              offset: Offset((1 - t) * 24, 0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 280,
                    maxWidth: 420,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DSpace.l,
                    vertical: DSpace.m,
                  ),
                  decoration: BoxDecoration(
                    color: c.elevated,
                    borderRadius: BorderRadius.circular(DRadii.md),
                    border: Border.all(color: c.borderSubtle),
                    boxShadow: DShadows.popover,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icon(), size: 18, color: _iconColor(c)),
                      const SizedBox(width: DSpace.m),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: DType.body.copyWith(color: c.textPrimary),
                        ),
                      ),
                      if (widget.actionLabel != null) ...[
                        const SizedBox(width: DSpace.m),
                        TextButton(
                          onPressed: widget.onAction,
                          child: Text(
                            widget.actionLabel!,
                            style: DType.label.copyWith(
                              color: c.accentPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
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
