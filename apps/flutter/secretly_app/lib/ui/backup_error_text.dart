// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//
// 14.11.2026: экран копий показывал человеку трассу Java
// (`PlatformException(… AEADBadTagException … at java.lang.reflect…`).
// Здесь ошибка копии превращается в одну понятную строку.
import '../l10n/app_localizations.dart';

const String _unreadableMarker = 'secure_storage_unreadable';

/// Понятная причина сбоя копии; неизвестная — первая строка, не длиннее 160.
String backupErrorText(AppLocalizations l10n, Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();
  final at = raw.indexOf('$_unreadableMarker:');
  if (at >= 0) {
    final slot = RegExp(r'^[a-z_]+')
            .firstMatch(raw.substring(at + _unreadableMarker.length + 1))
            ?.group(0) ??
        '?';
    return l10n.backupKeystoreUnreadable(slot);
  }
  if (lower.contains('aeadbadtag') ||
      lower.contains('bad_decrypt') ||
      lower.contains('badpadding')) {
    return l10n.backupKeystoreUnreadable('?');
  }
  var line = raw.split('\n').first.trim();
  if (line.length > 160) line = '${line.substring(0, 160)}…';
  return line;
}
