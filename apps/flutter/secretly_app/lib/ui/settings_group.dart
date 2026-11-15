// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

// Общие детали страниц настроек телефона по макету владельца
// («Settings Redesign», 11.2026): заголовок группы с кнопкой «?», окно
// пояснения снизу, вступление со значком, карточка состояния, пошаговая
// карточка и большие кнопки. Только вид — ничего не сохраняют и не меняют.
// Цвета берутся из темы, поэтому светлая и тёмная темы работают одинаково.

/// Пояснение к пункту или группе: открывается кнопкой «?».
@immutable
class SettingsHelp {
  const SettingsHelp({required this.title, required this.text, this.tip});

  final String title;
  final String text;
  final String? tip;
}

/// Окно пояснения снизу: заголовок, текст, совет и кнопка «Понятно».
Future<void> showSettingsHelp(BuildContext context, SettingsHelp help) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;
      final l10n = AppLocalizations.of(ctx);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const _HelpDot(size: 30, filled: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        help.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                help.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: cs.onSurface.withValues(alpha: 0.86),
                ),
              ),
              if (help.tip != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${l10n?.settingsHelpTip ?? 'Tip'}. ',
                          style: const TextStyle(
                            color: Color(0xFF35B86B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: help.tip),
                      ],
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  l10n?.settingsHelpGotIt ?? 'Got it',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _HelpDot extends StatelessWidget {
  const _HelpDot({this.size = 20, this.filled = false});

  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled
            ? cs.primary.withValues(alpha: 0.16)
            : cs.surfaceContainerHighest,
      ),
      child: Text(
        '?',
        style: TextStyle(
          fontSize: size * 0.55,
          height: 1,
          fontWeight: FontWeight.w800,
          color: filled ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Кнопка «?»: серый кружок, открывает [showSettingsHelp]. Зона нажатия
/// шире самого кружка, чтобы попадать пальцем.
class SettingsHelpButton extends StatelessWidget {
  const SettingsHelpButton(this.help, {super.key});

  final SettingsHelp help;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: '${l10n?.settingsHelpButton ?? 'Explanation'}: ${help.title}',
      excludeSemantics: true,
      child: InkResponse(
        radius: 18,
        onTap: () => showSettingsHelp(context, help),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: _HelpDot(),
        ),
      ),
    );
  }
}

/// Заголовок группы на странице настроек телефона: капсом, приглушённым
/// цветом, над карточкой. [inset] — отступ слева и справа: 32 для страниц,
/// где карточка стоит в отступе 16 (как `_card`), и 16 для страниц, где
/// отступ уже задан у списка. [help] добавляет кнопку «?» с пояснением.
class SettingsGroupHeader extends StatelessWidget {
  const SettingsGroupHeader(
    this.text, {
    super.key,
    this.inset = 32,
    this.help,
  });

  final String text;
  final double inset;
  final SettingsHelp? help;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        textAlign: TextAlign.start,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
    final help = this.help;
    if (help == null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(inset, 18, inset, 6),
        child: label,
      );
    }
    // С кнопкой «?» строка выше на 12 пикселей — ужимаем отступы, чтобы
    // текст заголовка стоял там же, где у групп без пояснения.
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(inset, 12, inset - 6, 0),
      child: Row(
        children: [
          Flexible(child: label),
          SettingsHelpButton(help),
        ],
      ),
    );
  }
}

/// Пояснение под карточкой: одна-две короткие строки.
class SettingsGroupCaption extends StatelessWidget {
  const SettingsGroupCaption(this.text, {super.key, this.inset = 32});

  final String text;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(inset, 6, inset, 2),
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.35,
        ),
      ),
    );
  }
}

/// Плашка значка раздела: цвет раздела на 20 % поверх фона карточки.
Color settingsIconPlate(BuildContext context, Color tint) {
  return Color.alphaBlend(
    tint.withValues(alpha: 0.20),
    Theme.of(context).colorScheme.surface,
  );
}

/// Вступление в начале страницы: значок раздела и одна фраза — зачем
/// здесь заходить.
class SettingsPageIntro extends StatelessWidget {
  const SettingsPageIntro({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    this.inset = 20,
  });

  /// Значок 28×28; цвет задаёт вызывающий.
  final Widget icon;
  final Color color;
  final String text;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 4, inset, 4),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: settingsIconPlate(context, color),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(width: 28, height: 28, child: icon),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка состояния: точка с ореолом, крупная строка и пояснение.
/// [good] — зелёная (всё в порядке), иначе спокойная серая.
class SettingsStatusCard extends StatelessWidget {
  const SettingsStatusCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.good = true,
  });

  final String title;
  final String subtitle;
  final bool good;

  static const Color _green = Color(0xFF35B86B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final tint = good ? _green : cs.onSurfaceVariant;
    final titleColor = good
        ? (dark ? const Color(0xFF7CDCA4) : const Color(0xFF1E7A45))
        : cs.onSurface;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color.alphaBlend(tint.withValues(alpha: 0.12), cs.surface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint,
                boxShadow: [
                  BoxShadow(
                    color: tint.withValues(alpha: 0.18),
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Пошаговая карточка: номера в кружках, соединённые линией.
class SettingsStepsCard extends StatelessWidget {
  const SettingsStepsCard({super.key, required this.steps});

  /// Пары «заголовок шага — пояснение».
  final List<(String, String)> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
        child: Column(
          children: [
            for (var i = 0; i < steps.length; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primary.withValues(alpha: 0.15),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: cs.primary.withValues(alpha: 0.18),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3, bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                steps[i].$1,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              steps[i].$2,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Большая кнопка во всю ширину: главная (залитая) или вторичная.
class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Шрифт — из темы приложения: голый TextStyle заменил бы его системным.
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
    final child = icon == null
        ? Text(label, textAlign: TextAlign.center)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          );
    return primary
        ? FilledButton(style: style, onPressed: onPressed, child: child)
        : FilledButton.tonal(style: style, onPressed: onPressed, child: child);
  }
}
