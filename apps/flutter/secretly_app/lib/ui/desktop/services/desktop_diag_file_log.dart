// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../calls/call_log.dart' show callLogFileSink;

/// 🔴 Журнал событий ПК в файл (25.09.2026).
///
/// На телефоне `DiagLog` пишет в logcat, и по нему разбирают доставку. На
/// macOS канала `secretly/log` нет: всё уходило в никуда, и на вопрос
/// «расшифровал ли ПК сообщение, пришедшее ночью» ответить было нечем.
///
/// Пишутся события и счётчики `DiagLog` и служебные события звонков, текста
/// сообщений нет. Файл лежит в папке поддержки приложения (`logs/diag.log`),
/// держит не больше [maxBytes], а прежнее содержимое — в `diag.1.log`, так что
/// на диске никогда не больше двух таких файлов.
///
/// 🔴 ОДИН ПРИЁМНИК (30.09.2026). События `DiagLog` приходят сюда через
/// `callLog` (`callOpLog` → [callLogFileSink]). Раньше их же принимал и
/// `DiagLog.sink`, и каждое событие ложилось в файл дважды — причём вторая
/// копия шла мимо очистки `…id=`. Теперь приёмник один, а очистка — здесь, на
/// каждой строке ([redact]): в отладочной сборке `callLog` строк не чистит.
class DesktopDiagFileLog {
  DesktopDiagFileLog._();

  static const int maxBytes = 2 * 1024 * 1024;
  static const String fileName = 'diag.log';
  static const String previousFileName = 'diag.1.log';

  /// Те же ключи, что прячет `callLog` в выпускной сборке
  /// (`lib/calls/call_log.dart`): всё, что кончается на `id`, и SDP, ICE,
  /// nonce, подписи.
  static final RegExp _sensitiveKv = RegExp(
    r'\b(sdp|candidate|nonce|signature|[A-Za-z_]*(?:id|Id|ID))=([^\s,;]+)',
    caseSensitive: false,
  );

  /// Строка, какой она ляжет в файл: значения чувствительных ключей скрыты,
  /// переводы строк — пробелы (одна запись — одна строка).
  @visibleForTesting
  static String redact(String line) => line
      .replaceAllMapped(_sensitiveKv, (m) => '${m.group(1)}=<redacted>')
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ');

  static File? _file;
  static IOSink? _sink;
  static int _written = 0;
  static Future<void>? _rotation;

  /// 🔴 Строки до открытия файла (30.09.2026). Файл открывается не первой
  /// строкой `main`, а ошибка запуска случается раньше — и пропадала. После
  /// [captureEarly] строки копятся здесь (не больше [_earlyMax]) и ложатся в
  /// файл первыми, когда [start] его откроет.
  static List<String>? _early;
  static const int _earlyMax = 200;

  /// Папка журнала — для «Показать журнал» и для проверки вживую.
  static String? get directoryPath => _file?.parent.path;

  /// Принимать строки ещё до [start]. Зовётся первой строкой `main`.
  static void captureEarly() {
    if (_sink != null || _early != null) return;
    _early = <String>[];
    callLogFileSink = write;
  }

  static Future<void> start({Directory? directoryForTest}) async {
    if (_sink != null) return;
    try {
      final base = directoryForTest ?? await getApplicationSupportDirectory();
      final dir = Directory(p.join(base.path, 'logs'));
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, fileName));
      _written = await file.exists() ? await file.length() : 0;
      _file = file;
      final sink = file.openWrite(mode: FileMode.append);
      for (final out in _early ?? const <String>[]) {
        sink.write(out);
        _written += out.length;
      }
      _early = null;
      _sink = sink;
      callLogFileSink = write;
      write('event=diag.file_log_started');
    } catch (_) {
      // Нет журнала — приложение всё равно работает.
      _file = null;
      _sink = null;
    }
  }

  static void write(String line) {
    final out = '${DateTime.now().toUtc().toIso8601String()} ${redact(line)}\n';
    final sink = _sink;
    if (sink == null) {
      final early = _early;
      if (early != null && early.length < _earlyMax) early.add(out);
      return;
    }
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
    if (identical(callLogFileSink, write)) callLogFileSink = null;
    _early = null;
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

  /// Последние [maxBytes] журнала — для письма в поддержку (прошлый файл,
  /// затем текущий). `null`, если журнала нет.
  static Future<Uint8List?> recentBytes({int maxBytes = 900 * 1024}) async {
    final file = _file;
    if (file == null) return null;
    try {
      await _sink?.flush();
      final previous = File(p.join(file.parent.path, previousFileName));
      final parts = <int>[
        if (await previous.exists()) ...await previous.readAsBytes(),
        if (await file.exists()) ...await file.readAsBytes(),
      ];
      if (parts.isEmpty) return null;
      final start = parts.length > maxBytes ? parts.length - maxBytes : 0;
      return Uint8List.fromList(parts.sublist(start));
    } catch (_) {
      return null;
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
