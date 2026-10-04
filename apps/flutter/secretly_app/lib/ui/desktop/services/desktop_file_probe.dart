// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Есть ли файл на диске — с памятью на короткий срок (01.10.2026).
///
/// 🔴 Проверка наличия файла стояла прямо в `build`: портрет каждой строки
/// списка, каждого автора реакции в ленте, обои открытого чата и шапка
/// подробностей спрашивали диск заново на каждую перерисовку. А список и
/// лента перерисовываются на каждый тик контроллера. Один системный вызов
/// дёшев, сотня на кадр — уже нет, особенно на Windows, где каждый из них
/// проходит через антивирус.
///
/// Ответ помнится недолго: «есть» — [presentFor], «нет» — [missingFor].
/// Отрицательный короче намеренно: портрет, которого ещё нет, может вот-вот
/// докачаться, и заглушка с буквами не должна его пережидать. Спрашивать
/// диск асинхронно здесь нельзя: ответ нужен тому же кадру, иначе на первом
/// показе вместо фото мигали бы буквы.
class DesktopFileProbe {
  DesktopFileProbe._();

  /// Сколько верить ответу «файл есть».
  static const Duration presentFor = Duration(seconds: 10);

  /// Сколько верить ответу «файла нет».
  static const Duration missingFor = Duration(seconds: 2);

  /// Сколько путей помнить. Переполнение просто очищает память — путей на
  /// экране столько не бывает, и честная очистка проще любой вытесняющей
  /// политики.
  static const int maxEntries = 1024;

  static final Map<String, ({bool exists, int untilMs})> _cache =
      <String, ({bool exists, int untilMs})>{};

  /// Часы — подменяемые, чтобы проверка не ждала настоящие секунды.
  @visibleForTesting
  static int Function() nowMs = () => DateTime.now().millisecondsSinceEpoch;

  /// Сколько раз пришлось спросить диск. Только для проверок.
  @visibleForTesting
  static int diskChecks = 0;

  /// Есть ли файл [path]. Пустой путь — нет.
  static bool exists(String path) {
    final clean = path.trim();
    if (clean.isEmpty) return false;
    final now = nowMs();
    final hit = _cache[clean];
    if (hit != null && now < hit.untilMs) return hit.exists;
    bool found;
    try {
      diskChecks++;
      found = File(clean).existsSync();
    } catch (_) {
      found = false;
    }
    if (_cache.length >= maxEntries) _cache.clear();
    final ttl = found ? presentFor : missingFor;
    _cache[clean] = (exists: found, untilMs: now + ttl.inMilliseconds);
    return found;
  }

  /// Забыть ответ про [path]: файл только что записали или удалили.
  static void forget(String path) => _cache.remove(path.trim());

  @visibleForTesting
  static void reset() {
    _cache.clear();
    diskChecks = 0;
    nowMs = () => DateTime.now().millisecondsSinceEpoch;
  }
}
