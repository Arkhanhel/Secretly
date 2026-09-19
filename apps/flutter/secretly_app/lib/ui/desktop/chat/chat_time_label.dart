// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';

/// Короткая подпись времени для списков: «14:19» · «вчера» · «пн» · «30.06».
///
/// Одна на весь десктоп: та же подпись стоит у чата в списке и у темы в
/// подробностях комнаты. Пока их было две, они разошлись бы на первой же
/// правке — а человек читает их рядом, в одном окне.
///
/// [now] задаётся только в тестах: без него «вчера» и «пн» нечем проверить,
/// не переводя часы машины.
String desktopTimeLabel(int ms, AppLocalizations l10n, {DateTime? now}) {
  if (ms <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final today = now ?? DateTime.now();
  final sameDay =
      dt.year == today.year && dt.month == today.month && dt.day == today.day;
  if (sameDay) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  final yesterday = today.subtract(const Duration(days: 1));
  final isYesterday =
      dt.year == yesterday.year &&
      dt.month == yesterday.month &&
      dt.day == yesterday.day;
  if (isYesterday) return l10n.desktopTimeYesterday;
  final daysAgo = today.difference(dt).inDays;
  if (daysAgo < 7) {
    // Сокращения дней недели берём у intl: свой список пришлось бы вести
    // на каждом из восьми языков, а система уже знает их наизусть.
    return DateFormat.E(l10n.localeName).format(dt);
  }
  final d = dt.day.toString().padLeft(2, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  return '$d.$mo';
}
