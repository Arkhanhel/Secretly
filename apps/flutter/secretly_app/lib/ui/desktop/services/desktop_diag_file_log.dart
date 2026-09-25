// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../diagnostics/diag_log.dart';

/// 🔴 Журнал событий ПК в файл (25.09.2026).
///
/// На телефоне `DiagLog` пишет в logcat, и по нему разбирают доставку. На
/// macOS канала `secretly/log` нет: всё уходило в никуда, и на вопрос
/// «расшифровал ли ПК сообщение, пришедшее ночью» ответить было нечем.
///
/// Пишется только то, что уже прошло очистку `DiagLog`: события и счётчики,
/// идентификаторы обрезаны до восьми знаков, текста сообщений нет. Файл лежит
/// в папке поддержки приложения (`logs/diag.log`), держит не больше
/// [maxBytes], а прежнее содержимое — в `diag.1.log`, так что на диске никогда
/// не больше двух таких файлов.
class DesktopDiagFileLog {
  DesktopDiagFileLog._();

  static const int maxBytes = 2 * 1024 * 1024;
  static const String fileName = 'diag.log';
  static const String previousFileName = 'diag.1.log';

  static File? _file;
  static IOSink? _sink;
  static int _written = 0;
  static Future<void>? _rotation;

  /// Папка журнала — для «Показать журнал» и для проверки вживую.
  static String? get directoryPath => _file?.parent.path;

  static Future<void> start({Directory? directoryForTest}) async {
    if (_sink != null) return;
    try {
      final base = directoryForTest ?? await getApplicationSupportDirectory();
      final dir = Directory(p.join(base.path, 'logs'));
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, fileName));
      _written = await file.exists() ? await file.length() : 0;
      _file = file;
      _sink = file.openWrite(mode: FileMode.append);
      DiagLog.sink = write;
      write('event=diag.file_log_started');
    } catch (_) {
      // Нет журнала — приложение всё равно работает.
      _file = null;
      _sink = null;
    }
  }

  static void write(String line) {
    final sink = _sink;
    if (sink == null) return;
    final out = '${DateTime.now().toUtc().toIso8601String()} $line\n';
    sink.write(out);
    _written += out.length;
    if (_written > maxBytes && _rotation == null) {
      _rotation = _rotate().whenComplete(() => _rotation = null);
    }
  }

  static Future<void> _rotate() async {
    final file = _file;
    final old = _sink;
    if (file == null || old == null) return;
    _sink = null; // строки, пришедшие во время смены файла, пропадут — не страшно
    try {
      await old.flush();
      await old.close();
      final previous = File(p.join(file.parent.path, previousFileName));
      if (await previous.exists()) await previous.delete();
      await file.rename(previous.path);
      _written = 0;
      _sink = file.openWrite(mode: FileMode.append);
    } catch (_) {
      // Не вышло сменить — пишем дальше в тот же файл.
      try {
        _sink = file.openWrite(mode: FileMode.append);
      } catch (_) {}
    }
  }

  static Future<void> stop() async {
    if (identical(DiagLog.sink, write)) DiagLog.sink = null;
    // Смена файла посреди остановки оставила бы его наполовину переименованным.
    final rotation = _rotation;
    if (rotation != null) {
      try {
        await rotation;
      } catch (_) {}
    }
    final sink = _sink;
    _sink = null;
    _file = null;
    _written = 0;
    if (sink != null) {
      try {
        await sink.flush();
        await sink.close();
      } catch (_) {}
    }
  }

  /// Дождаться начатой смены файла — чтобы проверка не зависела от нагрузки.
  @visibleForTesting
  static Future<void> settleForTest() async {
    final rotation = _rotation;
    if (rotation != null) await rotation;
    await _sink?.flush();
  }

  @visibleForTesting
  static Future<void> resetForTest() => stop();
}
