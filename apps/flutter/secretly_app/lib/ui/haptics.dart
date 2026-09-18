// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Тактильный отклик.
///
/// 🔴 ПРАВИЛО, А НЕ СПИСОК МЕСТ. Отклик был найден в 3 файлах из 88: в настройках
/// 120 нажимаемых элементов и ни одного отклика, в комнатах 85 и ни одного.
/// Расставлять руками по 88 экранам значило бы забыть половину, поэтому здесь
/// три уровня, и каждый нажимаемый элемент выбирает один из них:
///
/// * [tap] — обычное нажатие: кнопка, строка списка, переключатель;
/// * [confirm] — важное или необратимое: отправить, удалить, подтвердить;
/// * [reject] — отказ, ошибка, запрет.
///
/// 🔴 ТОЛЬКО НА ЗАВЕРШЁННОЕ ДЕЙСТВИЕ ЧЕЛОВЕКА. Никогда на программное
/// изменение, прокрутку или повтор автонажатия — иначе отклик превращается в
/// дрожь, и это хуже, чем его отсутствие.
abstract final class Haptics {
  /// Обычное нажатие.
  ///
  /// `selectionClick` намеренно: на iOS он даёт короткий чёткий щелчок выбора, а
  /// не удар, и именно так ощущаются строки списков в дорогих приложениях.
  static void tap() => _fire(HapticFeedback.selectionClick);

  /// Важное или необратимое действие.
  static void confirm() => _fire(HapticFeedback.mediumImpact);

  /// Отказ, ошибка, запрет.
  static void reject() => _fire(HapticFeedback.heavyImpact);

  /// Есть ли смысл вообще звать канал.
  ///
  /// На десктопе тактильного отклика нет, и вызов канала там — не «нет эффекта»,
  /// а исключение на КАЖДОЕ нажатие.
  static bool get _supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static void _fire(Future<void> Function() action) {
    if (!_supported) return;
    // 🔴 МОЛЧА И НИКОГДА НЕ БРОСАЯ. Отклик — украшение; на части устройств он
    // недоступен, и необработанная асинхронная ошибка на каждое нажатие была бы
    // заметно хуже, чем отсутствие вибрации.
    try {
      action().catchError((Object _) {});
    } catch (_) {}
  }
}
