// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../welcome/welcome_style.dart';

/// Общая рамка экранов входа: «назад» в левом верхнем углу, заголовок и
/// подпись по центру, колонка шириной 400 (макет «Secretly Kit», 17.11.2026).
///
/// Одна на все шаги, чтобы они не разъезжались по отступам и ширине: человек
/// проходит их подряд, и любое «дёрганье» между ними читается как переход в
/// другое приложение. Фон у рамки прозрачный — под всеми шагами лежит один
/// и тот же знак из частиц (`WelcomeBackdrop`).
class DesktopAuthScaffold extends StatelessWidget {
  const DesktopAuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.onBack,
    this.showBack = true,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// `null` — уйти нельзя (идёт необратимый шаг). Кнопка при этом не
  /// исчезает, а гаснет.
  final VoidCallback? onBack;

  /// `false` — у шага нет «назад» вовсе (набор восстановления).
  final bool showBack;

  /// Над заголовком — например, круг с буквой имени.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 64,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (leading != null) ...[
                            Center(child: leading),
                            const SizedBox(height: 28),
                          ],
                          WelcomeHeading(title: title, body: subtitle),
                          const SizedBox(height: 32),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showBack)
          Positioned(
            top: 12,
            left: 16,
            child: WelcomeBackButton(
              tooltip: l10n.desktopAuthBack,
              onPressed: onBack,
            ),
          ),
      ],
    );
  }
}
