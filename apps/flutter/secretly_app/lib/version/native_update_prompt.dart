// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Нативная плашка обновления Google Play (гибкая, не принудительная).
///
/// Показывается ПОСЛЕ нашего собственного напоминания (`maybeShowUpdateNudge`)
/// и только там, где Play вообще может её показать.
///
/// 🔴 ГДЕ ОНА НЕ РАБОТАЕТ — и это не дефект, а свойство платформы:
///   * **iOS** — нативного механизма обновления не существует вовсе, Apple его
///     не предоставляет. Там остаётся только наше напоминание;
///   * **ручные APK** — Play обновляет лишь то, что сам и поставил. У ваших
///     тестировщиков сборки ставятся напрямую, поэтому им плашка не покажется;
///   * **десктоп** — очевидно.
///
/// Именно поэтому нативная плашка идёт ДОПОЛНЕНИЕМ к нашему напоминанию, а не
/// заменой: она покрывает меньшую часть аудитории, чем звучит.
///
/// **Гибкая, а не немедленная.** `startFlexibleUpdate` качает обновление в
/// фоне и не мешает пользоваться приложением; `performImmediateUpdate` — это
/// блокирующий экран Google, то есть принуждение, от которого владелец
/// сознательно отказался (03.08.2026).
///
/// **Направление отказа:** любая ошибка проглатывается. Play может быть не
/// установлен, устройство — без сервисов Google, версия в сторе не
/// раскатана на этот телефон; ни один из этих случаев не повод шуметь
/// пользователю или ронять запуск.
class NativeUpdatePrompt {
  NativeUpdatePrompt._();

  /// Не чаще раза в сутки: Play показывает СВОЮ плашку, и если дёргать её на
  /// каждый запуск, человек получит две назойливости подряд — нашу и Google.
  static const Duration _cooldown = Duration(hours: 24);
  static const String _lastShownKey = 'native_update_prompt_last_ms';

  /// Безопасно вызывать при каждом запуске.
  static Future<void> maybePrompt() async {
    // Только Android: на iOS пакет бросит, на десктопе канала нет вовсе.
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lastShownKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < _cooldown.inMilliseconds) return;

      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }
      if (info.flexibleUpdateAllowed != true) {
        // Стор разрешает только немедленное (блокирующее) обновление —
        // не наш случай, молчим и оставляем работу нашему напоминанию.
        return;
      }

      // Отметку ставим ДО показа: если пользователь смахнёт плашку, а мы
      // упадём на следующей строке, он не должен увидеть её снова через
      // минуту.
      await prefs.setInt(_lastShownKey, now);
      await InAppUpdate.startFlexibleUpdate();
      // Обновление скачано в фоне — просим Play его установить. Пользователь
      // увидит нативное «Перезапустить», и это его выбор.
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      // Play нет, сервисов Google нет, сборка не из стора, обновление не
      // раскатано на этот телефон — всё это норма, а не повод шуметь.
      if (!kReleaseMode) {
        debugPrint('NativeUpdatePrompt: пропущено ($e)');
      }
    }
  }
}
