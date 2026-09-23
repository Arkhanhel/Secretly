// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Запуск при входе в систему.
///
/// Тонкая сторона Flutter к `Runner/LoginItemBridge.swift`. Само состояние
/// живёт в системе, а не у нас: человек может отменить автозапуск в
/// «Системных настройках → Основные → Объекты входа», и наш переключатель
/// обязан это показывать, а не спорить.
///
/// 🔴 НИЧЕГО НЕ КЭШИРУЕМ ДОЛЬШЕ ОДНОГО ПОКАЗА. Свой сохранённый «включено»
/// разошёлся бы с системой в первый же раз, когда человек выключит автозапуск
/// снаружи, — и переключатель начал бы врать.
class DesktopLoginItemService {
  DesktopLoginItemService._();

  static final DesktopLoginItemService instance = DesktopLoginItemService._();

  static const MethodChannel _channel = MethodChannel('secretly/login_item');

  /// Умеет ли система это вообще. `false` — переключателя нет.
  final ValueNotifier<bool> available = ValueNotifier<bool>(false);

  /// Включён ли автозапуск прямо сейчас.
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  /// Человек выключил объект входа в системных настройках. Не то же самое,
  /// что «выключено нами»: вернуть это можно только там же.
  final ValueNotifier<bool> needsApproval = ValueNotifier<bool>(false);

  String? lastError;

  /// Только macOS: на Windows своего моста ещё нет, и показывать переключатель
  /// там значило бы обещать то, чего нет.
  static bool get supported => !kIsWeb && Platform.isMacOS;

  /// Подменяется в тестах: настоящий путь идёт в платформенный канал, которого
  /// в тесте нет, а на сборщике CI нет и самой macOS.
  @visibleForTesting
  static Future<Map<String, dynamic>?> Function(String method, bool? enabled)?
      debugProbe;

  Future<Map<String, dynamic>?> _call(String method, {bool? on}) async {
    final probe = debugProbe;
    if (probe != null) return probe(method, on);
    if (!supported) return null;
    return _channel.invokeMapMethod<String, dynamic>(
      method,
      on == null ? null : <String, dynamic>{'enabled': on},
    );
  }

  void _apply(Map<String, dynamic>? res) {
    if (res == null) return;
    available.value = (res['available'] as bool?) ?? false;
    enabled.value = (res['enabled'] as bool?) ?? false;
    needsApproval.value = (res['needsApproval'] as bool?) ?? false;
  }

  Future<void> refresh() async {
    try {
      _apply(await _call('status'));
      lastError = null;
    } catch (e) {
      available.value = false;
      lastError = '$e';
    }
  }

  /// Возвращает `true`, если система согласилась.
  Future<bool> setEnabled(bool on) async {
    try {
      _apply(await _call('setEnabled', on: on));
      lastError = null;
      return enabled.value == on;
    } catch (e) {
      final reason = e is PlatformException ? (e.message ?? '$e') : '$e';
      // Перечитываем: отказ мог оставить состояние где угодно, и показывать
      // желаемое вместо действительного здесь нельзя.
      //
      // 🔴 ПРИЧИНУ ВОЗВРАЩАЕМ ПОСЛЕ перечитывания. `refresh` на успехе
      // обнуляет `lastError` — и стирал бы ровно тот ответ системы, ради
      // которого его и сохраняли. Человек получал бы общее «не удалось»
      // вместо «почему».
      await refresh();
      lastError = reason;
      return false;
    }
  }
}
