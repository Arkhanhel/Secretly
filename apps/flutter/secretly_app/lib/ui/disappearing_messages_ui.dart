// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// Исчезающие сообщения у всех участников — общий интерфейс телефона и ПК
// (ТЗ 22.10.2026, шаг 3). Всё здесь показывается только когда сервер открыл
// флаг отправки (`AppController.disappearingVisibleForConvo`): без флага
// телефон и ПК выглядят ровно как раньше.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart' show AppController;
import '../l10n/app_localizations.dart';
import '../messages/disappearing_flags.dart';
import 'package:secretly_app/ui/apple_controls.dart';

/// Срок человеческим языком: «30 с», «5 мин», «8 ч», «30 дн», «1 нед».
///
/// Неделями — только ровное число недель: 30 дней — это «30 дн», а не
/// «4 нед» (как округляла прежняя подпись шапки ПК).
String formatDisappearDuration(int seconds, AppLocalizations l10n) {
  const day = 24 * 60 * 60;
  const week = 7 * day;
  if (seconds >= week && seconds % week == 0) {
    return l10n.desktopThreadWeeks('${seconds ~/ week}');
  }
  if (seconds >= day && seconds % day == 0) {
    return l10n.desktopThreadDays('${seconds ~/ day}');
  }
  if (seconds >= 3600 && seconds % 3600 == 0) {
    return l10n.desktopThreadHours('${seconds ~/ 3600}');
  }
  if (seconds >= 60 && seconds % 60 == 0) {
    return l10n.desktopThreadMinutes('${seconds ~/ 60}');
  }
  return l10n.desktopThreadSeconds('$seconds');
}

/// Текст предупреждения для [support]; `null` — предупреждать не о чем.
String? disappearingSupportWarning(
  DisappearingPeerSupport? support,
  AppLocalizations l10n, {
  // Комната: «у части участников», а не «у собеседника».
  bool room = false,
}) {
  return switch (support) {
    DisappearingPeerSupport.peerOutdated when room =>
      l10n.disappearingRoomOutdated,
    DisappearingPeerSupport.peerOutdated => l10n.disappearingPeerOutdated,
    DisappearingPeerSupport.ownOutdated => l10n.disappearingOwnOutdated,
    DisappearingPeerSupport.unknown => l10n.disappearingSupportUnknown,
    DisappearingPeerSupport.supported || null => null,
  };
}

/// Выбор в окне срока. Отдельный тип, чтобы «выключить» (`seconds == null`)
/// отличалось от «закрыли окно» (результат `null`).
class DisappearChoice {
  const DisappearChoice(this.seconds);
  final int? seconds;
}

/// Окно выбора срока: «Выкл.», сроки как у Signal, «Свой срок…». Честное
/// пояснение сверху (§2.6): не защищает от снимков экрана и старых версий.
///
/// [backgroundColor] и [textColor] — для ПК, где окна красятся своей темой;
/// на телефоне берутся из `Theme`.
Future<DisappearChoice?> showDisappearingTimerPicker(
  BuildContext context, {
  required int? current,
  required int customMinSeconds,
  required int customMaxSeconds,
  // Предупреждение о старой версии у собеседника или у меня (§2.4) — до
  // включения, чтобы человек решал, зная это.
  String? warning,
  Color? backgroundColor,
  Color? textColor,
  Color? accentColor,
  Color? warningColor,
  Future<T?> Function<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  })?
  dialogShower,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final show =
      dialogShower ??
      <T>({required BuildContext context, required WidgetBuilder builder}) =>
          showDialog<T>(context: context, builder: builder);
  final presets = AppController.disappearPresetSeconds;
  // Отрицательное — «своего значения нет» (тема наследует таймер комнаты).
  final isCustomCurrent =
      current != null && current > 0 && !presets.contains(current);
  final picked = await show<Object>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final fg = textColor ?? theme.colorScheme.onSurface;
      final accent = accentColor ?? theme.colorScheme.primary;
      Widget option({
        required String label,
        required bool selected,
        required Object result,
      }) {
        return ListTile(
          dense: true,
          title: Text(label, style: TextStyle(color: fg)),
          trailing: selected ? Icon(Icons.check, color: accent) : null,
          onTap: () => Navigator.of(ctx).pop(result),
        );
      }

      return SecretlyAlertDialog(
        backgroundColor: backgroundColor,
        title: Text(l10n.disappearingTitle, style: TextStyle(color: fg)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.disappearingDialogHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: fg.withValues(alpha: 0.7),
                ),
              ),
              if (warning != null && warning.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  warning,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: warningColor ?? theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              option(
                label: l10n.contactAutoDeleteOff,
                selected: current == null,
                result: const DisappearChoice(null),
              ),
              for (final s in presets)
                option(
                  label: formatDisappearDuration(s, l10n),
                  selected: current == s,
                  result: DisappearChoice(s),
                ),
              option(
                label: isCustomCurrent
                    ? '${l10n.disappearingCustom} '
                          '(${formatDisappearDuration(current, l10n)})'
                    : l10n.disappearingCustom,
                selected: isCustomCurrent,
                result: _customToken,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      );
    },
  );
  if (picked is DisappearChoice) return picked;
  if (!identical(picked, _customToken) || !context.mounted) return null;
  final custom = await show<int>(
    context: context,
    builder: (ctx) => _CustomDurationDialog(
      initialSeconds: isCustomCurrent ? current : null,
      minSeconds: customMinSeconds,
      maxSeconds: customMaxSeconds,
      backgroundColor: backgroundColor,
      textColor: textColor,
    ),
  );
  return custom == null ? null : DisappearChoice(custom);
}

const Object _customToken = Object();

class _CustomDurationDialog extends StatefulWidget {
  const _CustomDurationDialog({
    required this.initialSeconds,
    required this.minSeconds,
    required this.maxSeconds,
    this.backgroundColor,
    this.textColor,
  });

  final int? initialSeconds;
  final int minSeconds;
  final int maxSeconds;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  State<_CustomDurationDialog> createState() => _CustomDurationDialogState();
}

class _CustomDurationDialogState extends State<_CustomDurationDialog> {
  static const List<int> _units = <int>[1, 60, 3600, 86400];
  late final TextEditingController _amount;
  late int _unit;
  String? _error;

  @override
  void initState() {
    super.initState();
    final init = widget.initialSeconds;
    _unit = 3600;
    var amount = 1;
    if (init != null && init > 0) {
      for (final u in _units.reversed) {
        if (init % u == 0) {
          _unit = u;
          amount = init ~/ u;
          break;
        }
      }
    }
    _amount = TextEditingController(text: '$amount');
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _unitLabel(int unit, AppLocalizations l10n) => switch (unit) {
    1 => l10n.disappearingUnitSeconds,
    60 => l10n.disappearingUnitMinutes,
    3600 => l10n.disappearingUnitHours,
    _ => l10n.disappearingUnitDays,
  };

  void _submit(AppLocalizations l10n) {
    final n = int.tryParse(_amount.text.trim());
    final total = n == null ? null : n * _unit;
    if (total == null ||
        total < widget.minSeconds ||
        total > widget.maxSeconds) {
      setState(() => _error = l10n.disappearingCustomInvalid);
      return;
    }
    Navigator.of(context).pop(total);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fg = widget.textColor ?? theme.colorScheme.onSurface;
    return SecretlyAlertDialog(
      backgroundColor: widget.backgroundColor,
      title: Text(l10n.disappearingCustomTitle, style: TextStyle(color: fg)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.disappearingCustomHint(
              formatDisappearDuration(widget.minSeconds, l10n),
              formatDisappearDuration(widget.maxSeconds, l10n),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: fg.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(color: fg),
                  decoration: InputDecoration(errorText: _error),
                  onSubmitted: (_) => _submit(l10n),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _unit,
                dropdownColor: widget.backgroundColor,
                items: [
                  for (final u in _units)
                    DropdownMenuItem<int>(
                      value: u,
                      child: Text(
                        _unitLabel(u, l10n),
                        style: TextStyle(color: fg),
                      ),
                    ),
                ],
                onChanged: (u) {
                  if (u == null) return;
                  setState(() {
                    _unit = u;
                    _error = null;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => _submit(l10n),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
