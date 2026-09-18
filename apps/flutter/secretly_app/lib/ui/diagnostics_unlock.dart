// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:shared_preferences/shared_preferences.dart';

/// Разблокировка раздела «Диагностика» пятью нажатиями по строке версии.
///
/// 🔴 ЗАЧЕМ (16.08.2026). Раздел был открыт всем и в магазинной сборке, а
/// показывает он `profile_id`, `device_id`, адреса серверов, состояние очередей
/// и флаги раскатки. Обычному человеку эти строки ничего не говорят, но
/// скопировать и переслать их он может — и тогда отдаст свои идентификаторы, не
/// понимая, что отдал. Плюс инженерный экран в магазинном приложении выглядит
/// незаконченностью.
///
/// Убирать раздел совсем нельзя: он нужен владельцу и поддержке — по нему
/// смотрят состояние доставки, флаг рукопожатия и качество звонков.
///
/// Отсюда правило: **скрыт по умолчанию, открывается намеренным жестом,
/// закрывается кнопкой внутри самого раздела** (иначе случайно открывший не
/// сможет вернуть как было).
class DiagnosticsUnlock {
  DiagnosticsUnlock._();

  /// Сколько нажатий подряд открывает раздел.
  static const int tapsRequired = 5;

  /// С какого нажатия показывать обратный отсчёт.
  ///
  /// Раньше — значит подсказывать тому, кто просто ткнул в версию дважды;
  /// позже — значит не подсказать вовсе, и жест останется недоказуемым.
  static const int hintFromTap = 3;

  /// Пауза, после которой счёт начинается заново.
  ///
  /// Без неё случайные нажатия за неделю сложились бы в «жест», и раздел
  /// открылся бы сам собой — то есть защита не работала бы вовсе.
  static const Duration resetAfter = Duration(seconds: 2);

  static const String prefsKey = 'diagnostics_unlocked_v1';

  /// Чистое правило счёта. Возвращает новое число нажатий подряд.
  ///
  /// [previousTaps] — сколько было; [lastTapAtMs] — когда было последнее (0 =
  /// не было); [nowMs] — сейчас.
  static int nextTapCount({
    required int previousTaps,
    required int lastTapAtMs,
    required int nowMs,
  }) {
    if (previousTaps <= 0 || lastTapAtMs <= 0) return 1;
    final sinceMs = nowMs - lastTapAtMs;
    // Часы устройства могут прыгнуть назад (сон, смена пояса). Отрицательный
    // промежуток — не повод ни засчитать нажатие, ни сбросить счёт молча:
    // начинаем заново, это предсказуемо для человека.
    if (sinceMs < 0) return 1;
    if (sinceMs > resetAfter.inMilliseconds) return 1;
    return previousTaps + 1;
  }

  /// Сколько нажатий осталось до открытия; `null` — подсказку не показывать.
  static int? remainingHint(int taps) {
    if (taps < hintFromTap) return null;
    if (taps >= tapsRequired) return null;
    return tapsRequired - taps;
  }

  static bool unlocksAt(int taps) => taps >= tapsRequired;

  /// Прочитать состояние. Отказ хранилища читается как «закрыто»: раздел
  /// технический, и показать его по ошибке хуже, чем не показать.
  static Future<bool> isUnlocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefsKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setUnlocked(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value) {
        await prefs.setBool(prefsKey, true);
      } else {
        await prefs.remove(prefsKey);
      }
    } catch (_) {
      // Не смогли сохранить — раздел останется в прежнем состоянии до
      // перезапуска. Ронять настройки из-за этого нельзя.
    }
  }
}
