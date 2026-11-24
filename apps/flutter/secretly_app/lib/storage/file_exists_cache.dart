// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// «Есть ли файл» для строк списков (аватары): `File.existsSync()` — это
/// обращение к диску в потоке интерфейса на КАЖДУЮ сборку строки. Здесь
/// найденный файл запоминается на 5 секунд; отсутствие не запоминается
/// (только что скачанный аватар появится сразу). Удалённый за эти секунды
/// файл обрабатывает `errorBuilder` картинки, как и раньше при гонке.
library;

import 'dart:io';

abstract final class FileExistsCache {
  static const Duration _ttl = Duration(seconds: 5);
  static const int _max = 512;
  static final Map<String, DateTime> _seen = <String, DateTime>{};

  static bool exists(String path) {
    if (path.isEmpty) return false;
    final now = DateTime.now();
    final at = _seen[path];
    if (at != null && now.difference(at) < _ttl) return true;
    final ok = File(path).existsSync();
    if (ok) {
      if (_seen.length >= _max) _seen.remove(_seen.keys.first);
      _seen[path] = now;
    } else {
      _seen.remove(path);
    }
    return ok;
  }
}
