// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/foundation.dart';

import '../../../app/app_controller.dart' show Conversation;
import '../shell/sidebar.dart' show DesktopSection;

/// Одно посещение: раздел и открытая в нём переписка.
///
/// Хранится целый [Conversation], а не один идентификатор, потому что вернуть
/// человека назад нужно СРАЗУ, а не после запроса к базе: склад выбора
/// принимает именно объект, и секция подхватывает его тем же слушателем, каким
/// подхватывает выбор из ⌘K.
@immutable
class DesktopNavEntry {
  const DesktopNavEntry({required this.section, required this.convo});

  final DesktopSection section;
  final Conversation convo;

  String get convoId => convo.convoId;
}

/// История переходов по перепискам — «назад» и «вперёд» в шапке окна.
///
/// 🔴 ПОЧЕМУ ЭТО НЕ УКРАШЕНИЕ.
///
/// В макете слева от хлебных крошек стоят две стрелки. Нарисовать их и не
/// связать ни с чем — ровно тот случай, который в этом проекте назван мёртвой
/// кнопкой: человек нажмёт один раз, ничего не случится, и дальше он не будет
/// верить ни одной кнопке в шапке.
///
/// Поэтому история настоящая. Она ведёт себя как история браузера:
///
/// * открыли переписку — она встала в конец и стала текущей;
/// * ушли назад и открыли ДРУГУЮ переписку — всё, что было «вперёд»,
///   выбрасывается: развилку хранить некуда и незачем;
/// * повторное открытие той же переписки подряд ничего не добавляет, иначе
///   «назад» упиралось бы в саму себя.
///
/// Длина ограничена: тридцать шагов — это заведомо больше, чем человек
/// отматывает назад, и заведомо меньше, чем стоит держать в памяти.
class DesktopNavHistory extends ChangeNotifier {
  static const int _kMax = 30;

  final List<DesktopNavEntry> _stack = <DesktopNavEntry>[];
  int _cursor = -1;

  /// Только для проверок: снимок пути.
  List<DesktopNavEntry> get entries => List.unmodifiable(_stack);
  int get cursor => _cursor;

  bool get canBack => _cursor > 0;
  bool get canForward => _cursor >= 0 && _cursor < _stack.length - 1;

  /// Текущая точка пути, `null` — пока ничего не открывали.
  DesktopNavEntry? get current =>
      _cursor >= 0 && _cursor < _stack.length ? _stack[_cursor] : null;

  /// Человек открыл переписку. Вызывается ТОЛЬКО для переходов, сделанных
  /// человеком: возврат по стрелке проходит мимо этого метода, иначе «назад»
  /// само дописывало бы историю и никуда не вело.
  void visit(DesktopNavEntry entry) {
    final cur = current;
    if (cur != null &&
        cur.convoId == entry.convoId &&
        cur.section == entry.section) {
      // Тот же чат — обновляем снимок, но шага не делаем.
      _stack[_cursor] = entry;
      return;
    }
    if (canForward) _stack.removeRange(_cursor + 1, _stack.length);
    _stack.add(entry);
    if (_stack.length > _kMax) {
      _stack.removeAt(0);
    }
    _cursor = _stack.length - 1;
    notifyListeners();
  }

  /// Шаг назад. `null` — идти некуда.
  DesktopNavEntry? back() {
    if (!canBack) return null;
    _cursor -= 1;
    notifyListeners();
    return _stack[_cursor];
  }

  /// Шаг вперёд. `null` — идти некуда.
  DesktopNavEntry? forward() {
    if (!canForward) return null;
    _cursor += 1;
    notifyListeners();
    return _stack[_cursor];
  }

  /// Переписку удалили или из неё вышли — выбрасываем её из пути целиком,
  /// иначе стрелка вела бы в пустоту.
  void forget(String convoId) {
    if (convoId.trim().isEmpty) return;
    final before = _stack.length;
    final currentId = current?.convoId;
    _stack.removeWhere((e) => e.convoId == convoId);
    if (_stack.length == before) return;
    if (_stack.isEmpty) {
      _cursor = -1;
    } else if (currentId == convoId) {
      _cursor = _cursor.clamp(0, _stack.length - 1);
    } else {
      _cursor = _stack.indexWhere((e) => e.convoId == currentId);
      if (_cursor < 0) _cursor = _stack.length - 1;
    }
    notifyListeners();
  }
}
