// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Число непрочитанных на значке приложения в Dock.
///
/// 🔴 ЗАЧЕМ. Окно живёт в трее и большую часть времени спрятано. Число уже
/// считалось для подсказки значка в трее — но подсказку видно только если
/// навести мышь и подождать, а у спрятанного окна нет и заголовка. Выходило,
/// что о непрочитанном сообщал ровно один баннер уведомления: пропустил — и
/// следов не осталось.
///
/// 🔴 ТОЛЬКО macOS. У Windows значок на кнопке панели задач ставится иначе
/// (`ITaskbarList3`), у Linux единого способа нет вовсе. Здесь честное «ничего
/// не делаем» вместо переключателя, который притворяется работающим.
class DesktopDockBadgeService {
  DesktopDockBadgeService({
    @visibleForTesting MethodChannel? channel,
    @visibleForTesting bool? onMacOS,
  }) : _channel = channel ?? const MethodChannel('secretly/dock_badge'),
       _onMacOS = onMacOS;

  final MethodChannel _channel;

  /// 🔴 Площадка подменяема ТОЛЬКО ради проверок. CI гоняет тесты на Linux, и
  /// без этого поведение значка не проверял бы никто: всё уходило бы в ранний
  /// возврат, а проверка «число дошло до системы» молча превращалась бы в
  /// проверку «ничего не произошло».
  final bool? _onMacOS;

  /// Последнее отправленное число: площадку дёргаем только на изменение.
  int? _last;

  bool get _supported => _onMacOS ?? (!kIsWeb && Platform.isMacOS);

  /// Ставит значок. Отрицательное и ноль — значок снимается.
  Future<void> set(int count) async {
    if (!_supported) return;
    final n = count < 0 ? 0 : count;
    if (n == _last) return;
    _last = n;
    try {
      await _channel.invokeMethod<void>('set', <String, dynamic>{'count': n});
    } catch (_) {
      // Мост мог не подняться (старая сборка, запуск без нативной части).
      // Значок — не то, ради чего стоит ронять приложение.
      _last = null;
    }
  }

  /// Снять значок. Зовётся при выходе из профиля: чужое число на своём значке
  /// хуже, чем его отсутствие.
  Future<void> clear() => set(0);

  @visibleForTesting
  int? get lastSent => _last;
}
