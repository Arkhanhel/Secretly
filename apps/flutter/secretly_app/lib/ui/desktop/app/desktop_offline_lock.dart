// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
/// ПАРОЛЬ ПОСЛЕ ДОЛГОГО ОТСУТСТВИЯ СВЯЗИ.
///
/// 🔴 ЗАЧЕМ. Отключить потерянный компьютер можно только пока он выходит на
/// связь: команда приходит с сервера. У выключенного или унесённого без сети
/// она не сработает никогда, и переписка остаётся открытой ровно до тех пор,
/// пока кто-то не откроет крышку.
///
/// Правило простое и без сервера: компьютер давно не связывался — при запуске
/// спрашиваем пароль входа. Данные целы, владелец просто вводит пароль.
///
/// Считаем только по УДАЧНОЙ связи с сервером (её отмечает контроллер), а не
/// по времени запуска: «давно не запускали» — это не потеря.
library;

class DesktopOfflineLock {
  DesktopOfflineLock._();

  /// Срок в днях; 0 — никогда не запирать.
  static const String prefsDaysKey = 'desktop_offline_lock_days';

  /// Две недели: отпуск без интернета переживается, потеря — нет.
  static const int defaultDays = 14;

  /// Выбор в настройках. 0 — «Никогда».
  static const List<int> choices = <int>[0, 7, 14, 30];

  /// Нормализует хранимое значение: чужое число не должно ослаблять защиту
  /// молча — берём ближайший разрешённый вариант.
  static int normalizeDays(int? stored) {
    if (stored == null) return defaultDays;
    if (stored <= 0) return 0;
    for (final c in choices) {
      if (c == stored) return stored;
    }
    return defaultDays;
  }

  /// Нужно ли запереть приложение при запуске.
  ///
  /// `false`, когда:
  /// * пароль входа не задан — запирать нечем;
  /// * выбрано «Никогда»;
  /// * связи ещё не было ни разу (первый запуск с этой правкой) — иначе
  ///   человек получил бы пароль на ровном месте.
  static bool shouldLock({
    required int lastContactAtMs,
    required int nowMs,
    required int days,
    required bool lockEnabled,
  }) {
    if (!lockEnabled) return false;
    final limit = normalizeDays(days);
    if (limit <= 0) return false;
    if (lastContactAtMs <= 0) return false;
    if (nowMs <= lastContactAtMs) return false;
    return nowMs - lastContactAtMs >= limit * 24 * 60 * 60 * 1000;
  }
}
