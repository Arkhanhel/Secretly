// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../primitives/desktop_button.dart';

/// Общая рамка экранов входа: заголовок, подпись, «назад» и колонка по центру.
///
/// Одна на все шаги, чтобы они не разъезжались по отступам и ширине: человек
/// проходит их подряд, и любое «дёрганье» между ними читается как переход в
/// другое приложение.
class DesktopAuthScaffold extends StatelessWidget {
  const DesktopAuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// `null` — уйти нельзя (идёт необратимый шаг). Кнопка при этом не
  /// исчезает, а гаснет: пропадающая кнопка сдвигает то, что под ней.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: c.bg,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DSpace.xl2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: DesktopButton(
                  label: l10n.desktopAuthBack,
                  kind: DButtonKind.ghost,
                  size: DButtonSize.small,
                  icon: FluentIcons.chevron_left_24_regular,
                  onPressed: onBack,
                ),
              ),
              const SizedBox(height: DSpace.l),
              Text(title, style: DType.display.copyWith(color: c.textPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: DSpace.s),
                Text(
                  subtitle!,
                  style: DType.body
                      .copyWith(color: c.textSecondary, height: 1.45),
                ),
              ],
              const SizedBox(height: DSpace.xl2),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
