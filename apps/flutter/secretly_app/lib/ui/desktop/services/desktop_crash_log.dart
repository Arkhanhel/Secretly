// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';

import '../../../diagnostics/diag_log.dart';

/// 🔴 НЕОБРАБОТАННЫЕ ОШИБКИ ПК — В ЖУРНАЛ (30.09.2026).
///
/// До этого в журнал ПК попадали только ошибки сборки виджетов
/// (`FlutterError.onError`, `_installDesktopErrorGuard` в `main_desktop.dart`).
/// Ошибка в таймере, в `Future` без обработчика, в ответе платформы уходила
/// только в консоль, которой у выпускной сборки нет, — и после жалобы «что-то
/// перестало работать» разбирать было нечего.
///
/// Необработанная ошибка любой зоны без своего обработчика доходит до корневой
/// зоны, а оттуда движок отдаёт её в [PlatformDispatcher.onError]. Своя
/// `runZonedGuarded` поверх `main` не нужна и вредна: `runApp` обязан идти в
/// той же зоне, что `ensureInitialized`, а своя зона забирала бы ошибки раньше
/// этого обработчика.
///
/// В журнал идут только тип ошибки и верхние кадры стека (файл:строка) — НЕ
/// текст ошибки: в нём бывают данные человека. Прежний обработчик
/// сохраняется и зовётся следом, так что вывод движка в консоль не пропадает.
class DesktopCrashLog {
  DesktopCrashLog._();

  static bool _installed = false;
  static bool _recording = false;

  /// Встать в [PlatformDispatcher.onError] поверх прежнего обработчика.
  /// Повторный вызов ничего не делает.
  static void install() {
    if (_installed) return;
    _installed = true;
    final previous = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      record('platform', error, stack);
      return previous?.call(error, stack) ?? false;
    };
  }

  /// Записать ошибку без её текста; [source] — откуда она пришла.
  static void record(String source, Object error, StackTrace? stack) {
    // Ошибка внутри самого журнала не должна зациклиться.
    if (_recording) return;
    _recording = true;
    try {
      DiagLog.event('crash', source, {
        'type': error.runtimeType.toString(),
        'at': stackTop(stack),
      });
    } catch (_) {
      // Журнал не имеет права ронять то, что он описывает.
    } finally {
      _recording = false;
    }
  }

  static final RegExp _frame = RegExp(
    r'\(package:([^\s()]+?):(\d+)(?::\d+)?\)',
  );
  static const String _ownPackage = 'secretly_app/';

  /// Где упало: до [max] кадров `файл:строка`, сначала свои — без префикса
  /// пакета; своих нет — первые чужие пакеты. Кадры с путями диска
  /// (`file:///…`) не берутся: в них имя пользователя.
  static String stackTop(StackTrace? stack, {int max = 3}) {
    if (stack == null) return '-';
    final own = <String>[];
    final other = <String>[];
    for (final m in _frame.allMatches(stack.toString())) {
      final path = m.group(1)!;
      final line = m.group(2)!;
      if (path.startsWith(_ownPackage)) {
        own.add('${path.substring(_ownPackage.length)}:$line');
        if (own.length >= max) break;
      } else if (other.length < max) {
        other.add('$path:$line');
      }
    }
    final picked = own.isNotEmpty ? own : other;
    return picked.isEmpty ? '-' : picked.join('<');
  }

  @visibleForTesting
  static void debugReset() {
    _installed = false;
    _recording = false;
  }
}
