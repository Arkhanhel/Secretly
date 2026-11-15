// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// К4 (14.11.2026): почему сервер не выдал копию. Раньше и неверный пароль, и
// запирание выглядели как «копия не найдена» — человек думал, что копия
// пропала.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Текст отказа по ответу сервера или [fallback] («копия не найдена»), если
/// сервер причину не назвал (сервер до 14.11.2026 или копии действительно
/// нет без предъявленного пароля).
String serverBackupRefusalText(
  BuildContext context,
  AppLocalizations l10n,
  ({String? reason, int? retryAtMs}) refusal, {
  required String fallback,
}) {
  switch (refusal.reason) {
    case 'wrong_password':
      return l10n.backupServerWrongPassword;
    case 'locked':
      final at = refusal.retryAtMs;
      if (at == null || at <= 0) return l10n.backupServerWrongPassword;
      final t = DateTime.fromMillisecondsSinceEpoch(at).toLocal();
      final time = TimeOfDay.fromDateTime(t).format(context);
      final today = DateTime.now();
      final sameDay =
          t.year == today.year && t.month == today.month && t.day == today.day;
      return l10n.backupServerLocked(
        sameDay
            ? time
            : '${MaterialLocalizations.of(context).formatShortMonthDay(t)} $time',
      );
    default:
      return fallback;
  }
}
