// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';

/// «Аккаунт заведён здесь, но набор восстановления ещё не сделан».
///
/// 🔴 ЗАЧЕМ ЭТО ОТДЕЛЬНЫЙ ФЛАГ, А НЕ ШАГ ВНУТРИ ЭКРАНА СОЗДАНИЯ.
///
/// Две причины, и обе проверяемые.
///
/// Первая: `createNewServerProfileForCurrentDevice()` снимает запрет входа
/// СРАЗУ (`_setDesktopAuthRequired(prefs, false)`), и корень окна в тот же
/// кадр меняет экран создания на оболочку. Шаг «сохраните набор», живущий
/// внутри того экрана, просто исчез бы вместе с ним — человек оказался бы в
/// приложении без ключа и без всякого следа, что ключ ему полагался.
///
/// Вторая: человек может закрыть окно посреди создания. Шаг, существующий
/// только в памяти, после перезапуска не вернётся, и аккаунт навсегда
/// останется без единственного способа его вернуть.
///
/// Флаг лежит в настройках устройства: он переживает и подмену экрана, и
/// закрытие окна. Снимается ровно тогда, когда набор действительно создан.
class DesktopAccountSetup {
  DesktopAccountSetup._();

  static const String _prefsKitPendingKey = 'desktop_account_kit_pending_v1';

  /// Нужно ли показать шаг «сохраните набор восстановления».
  static final ValueNotifier<bool> kitPending = ValueNotifier<bool>(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    kitPending.value = prefs.getBool(_prefsKitPendingKey) ?? false;
  }

  /// Аккаунт только что заведён на этом компьютере — ключа ещё нет.
  static Future<void> markKitPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKitPendingKey, true);
    kitPending.value = true;
  }

  /// Ключ сделан и показан.
  static Future<void> clearKitPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKitPendingKey);
    kitPending.value = false;
  }
}
