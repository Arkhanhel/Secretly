// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

import 'package:shared_preferences/shared_preferences.dart';

/// Отметки пути «нажал на уведомление → открылся чат» (13.11.2026, проверка
/// Т10 на iPhone: при закрытом приложении открывался главный экран).
///
/// Последние 12 строк `время|шаг|первые 8 символов чата` в настройках
/// приложения — без текста, без полного идентификатора. Снимаются с
/// устройства вместе с настройками; живой журнал iPhone при холодном запуске
/// с Mac не снять.
class NotifTapTrail {
  NotifTapTrail._();

  static const String prefsKey = 'diag_notif_open_v1';
  static const int _keep = 12;

  static Future<void> add(String stage, String? convoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clean = (convoId ?? '').replaceAll('-', '');
      final pfx = clean.length > 8 ? clean.substring(0, 8) : clean;
      final line = '${DateTime.now().millisecondsSinceEpoch}|$stage|$pfx';
      final list = List<String>.from(prefs.getStringList(prefsKey) ?? const []);
      list.add(line);
      await prefs.setStringList(
        prefsKey,
        list.length > _keep ? list.sublist(list.length - _keep) : list,
      );
    } catch (_) {
      // Отметка — подсказка для разбора, а не часть работы приложения.
    }
  }
}
