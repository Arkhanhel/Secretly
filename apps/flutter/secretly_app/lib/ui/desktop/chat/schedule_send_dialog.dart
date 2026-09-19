// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// «Отправить позже» — выбор момента отправки.
///
/// 🔴 ЭТОЙ ВОЗМОЖНОСТИ В ОКНЕ НЕ БЫЛО ВОВСЕ (до 16.09.2026), хотя на телефоне
/// она есть давно и держится на общем коде: `sendMessage`/`sendGroupMessage`
/// принимают `scheduledAtMs`, кладут местную заготовку и отпускают её в срок
/// сами — переживая перезапуск приложения. То есть недоставало РОВНО окна
/// выбора времени.
///
/// 🔴 СНАЧАЛА ГОТОВЫЕ ОТВЕТЫ, ПОТОМ КАЛЕНДАРЬ. Почти всякая отложенная отправка
/// — это «через час», «сегодня вечером» или «завтра утром»; заставлять ради
/// этого крутить календарь и часы значит менять три секунды на тридцать.
/// Календарь остаётся для остального и открывается одним нажатием.
///
/// 🔴 ПРОШЕДШЕЕ ВРЕМЯ НЕ ПРИНИМАЕТСЯ. Отправка «в прошлое» у контроллера
/// означает «немедленно» — то есть человек нажал «позже», а сообщение ушло
/// сразу. Молчаливое несоответствие обещанию хуже отказа, поэтому такие
/// варианты в списке не показываются, а из календаря не возвращаются.
library;

import '../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../design/tokens.dart';
import '../primitives/desktop_dialog.dart';
import '../primitives/hover_listener.dart';

/// Показывает выбор момента. Возвращает `null`, если человек передумал.
Future<DateTime?> showScheduleSendDialog(
  BuildContext context, {
  DateTime? now,
}) {
  final base = now ?? DateTime.now();
  return DesktopDialog.show<DateTime>(
    context,
    title: AppLocalizations.of(context)!.desktopScheduleTitle,
    size: DDialogSize.small,
    body: _ScheduleBody(now: base),
  );
}

/// Готовые варианты, посчитанные от [now].
///
/// Отдельной функцией — чтобы их можно было проверить без окна: именно здесь
/// живёт правило «в прошлое не предлагаем».
List<({String label, DateTime at})> scheduleSendPresets(
  DateTime now,
  AppLocalizations l10n,
) {
  final out = <({String label, DateTime at})>[];
  out.add((label: l10n.desktopScheduleInHour, at: now.add(const Duration(hours: 1))));

  final tonight = DateTime(now.year, now.month, now.day, 19);
  if (tonight.isAfter(now)) {
    out.add((label: l10n.desktopScheduleTonight, at: tonight));
  }

  final tomorrow = now.add(const Duration(days: 1));
  out.add((
    label: l10n.desktopScheduleTomorrow,
    at: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9),
  ));

  final inWeek = now.add(const Duration(days: 7));
  out.add((
    label: l10n.desktopScheduleInWeek,
    at: DateTime(inWeek.year, inWeek.month, inWeek.day, now.hour, now.minute),
  ));

  // Страховка на случай перевода часов и прочих странностей календаря:
  // показываем только то, что действительно в будущем.
  return out.where((p) => p.at.isAfter(now)).toList(growable: false);
}

/// Подпись момента: «завтра в 9:00», «17.09 в 19:00».
String formatScheduleMoment(
  DateTime at,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final base = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final time = '${two(at.hour)}:${two(at.minute)}';
  final today = DateTime(base.year, base.month, base.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return l10n.desktopScheduleTodayAt(time);
  if (diff == 1) return l10n.desktopScheduleTomorrowAt(time);
  return l10n.desktopScheduleOnAt('${two(at.day)}.${two(at.month)}', time);
}

class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({required this.now});

  final DateTime now;

  Future<void> _pickCustom(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (!context.mounted) return;
    final at = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? now.hour,
      time?.minute ?? now.minute,
    );
    // Выбранное в прошлом — это «отправить немедленно», а человек просил
    // обратного. Закрываем без результата, чтобы он выбрал заново.
    if (!at.isAfter(DateTime.now())) return;
    Navigator.of(context).maybePop(at);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = DColors.of(context);
    final presets = scheduleSendPresets(now, l10n);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.desktopScheduleHint,
          style: DType.caption.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: DSpace.m),
        for (final preset in presets)
          _Row(
            icon: FluentIcons.clock_24_regular,
            label: preset.label,
            hint: formatScheduleMoment(preset.at, l10n, now: now),
            onTap: () => Navigator.of(context).maybePop(preset.at),
          ),
        const SizedBox(height: DSpace.xs),
        _Row(
          icon: FluentIcons.calendar_ltr_24_regular,
          label: l10n.desktopSchedulePickTime,
          onTap: () => _pickCustom(context),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    return HoverListener(
      onTap: onTap,
      cursor: SystemMouseCursors.click,
      builder: (ctx, hovered, pressed) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: DSpace.s),
        decoration: BoxDecoration(
          color: hovered ? c.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(DRadii.sm),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: c.textSecondary),
            const SizedBox(width: DSpace.s),
            Expanded(
              child: Text(
                label,
                style: DType.body.copyWith(color: c.textPrimary),
              ),
            ),
            if (hint != null)
              Text(hint!, style: DType.tiny.copyWith(color: c.textTertiary)),
          ],
        ),
      ),
    );
  }
}
