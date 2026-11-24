// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Шторка просмотра медиа и редактора (макет: удаление, «Отменить
/// изменения?», «Все медиа»): отступ 8 от краёв, радиус 32, стекло
/// `sheet` + размытие 30 (на Android — без размытия), заголовок 17/700,
/// пояснение 14, варианты высотой 54 с радиусом 18, «Отмена» внизу.
/// Появление — 260 мс `Cubic(.2,.8,.2,1)`, сдвиг 40 px и прозрачность.
library;

import 'package:flutter/material.dart';

import '../l10n.dart';
import 'media_viewer_tokens.dart';

@immutable
class MediaSheetOption<T> {
  const MediaSheetOption({
    required this.label,
    required this.value,
    this.danger = false,
  });

  final String label;
  final T value;
  final bool danger;
}

Future<T?> showMediaViewerSheet<T>({
  required BuildContext context,
  required MediaViewerTokens tokens,
  required String title,
  String? subtitle,
  List<MediaSheetOption<T>> options = const [],
  Widget? body,
}) {
  // Всплывающее окно (PopupRoute), а не страница: просмотр под шторкой
  // остаётся живым, а сама шторка видна с первого кадра.
  return Navigator.of(context).push<T>(
    RawDialogRoute<T>(
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: tokens.backdrop,
      transitionDuration: kMediaSheetDuration,
      pageBuilder: (context, _, _) => _MediaSheet<T>(
        tokens: tokens,
        title: title,
        subtitle: subtitle,
        options: options,
        body: body,
      ),
      transitionBuilder: (context, anim, _, child) {
        final t = CurvedAnimation(
          parent: anim,
          curve: kMediaFlightCurve,
          reverseCurve: Curves.easeIn,
        );
        return AnimatedBuilder(
          animation: t,
          builder: (context, child) => Opacity(
            opacity: t.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 40 * (1 - t.value)),
              child: child,
            ),
          ),
          child: child,
        );
      },
    ),
  );
}

class _MediaSheet<T> extends StatelessWidget {
  const _MediaSheet({
    required this.tokens,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.body,
  });

  final MediaViewerTokens tokens;
  final String title;
  final String? subtitle;
  final List<MediaSheetOption<T>> options;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final media = MediaQuery.of(context);
    final bottom = media.viewPadding.bottom > 0 ? media.viewPadding.bottom : 8.0;
    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        color: mediaViewerGlass ? t.sheet : t.sheet.withValues(alpha: 1),
        borderRadius: BorderRadius.circular(32),
        boxShadow: t.sheetShadow,
        border: Border.all(color: t.islandBorder, width: .5),
      ),
      // С-11: при крупном шрифте шторка не вылезает за экран — прокручивается.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
            ),
            if ((subtitle ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Text(
                  subtitle!,
                  style: TextStyle(fontSize: 14, height: 1.4, color: t.sub),
                ),
              ),
            ],
            if (body != null) ...[const SizedBox(height: 6), body!],
            for (final o in options) ...[
              const SizedBox(height: 6),
              _SheetButton(
                label: o.label,
                color: o.danger ? t.danger : t.ink,
                background: t.chip,
                onTap: () => Navigator.of(context).pop(o.value),
              ),
            ],
            const SizedBox(height: 6),
            _SheetButton(
              label: context.l10n.cancel,
              color: t.ink,
              background: Colors.transparent,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
    if (mediaViewerGlass) {
      panel = ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: mediaViewerGlassFilter(MediaViewerTokens.sheetBlur / 2),
          child: panel,
        ),
      );
    }
    // С-11: крупный шрифт растит кнопки (не режет текст), но не больше 1,6×
    // — иначе пара кнопок займёт весь экран.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.6,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            8,
            media.viewPadding.top + 8,
            8,
            bottom,
          ),
          child: Material(type: MaterialType.transparency, child: panel),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
