// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show FontLoader;

import '../../../diagnostics/diag_log.dart';
import '../design/emoji_font.dart';

/// Итог загрузки шрифта эмодзи Windows — для журнала и самотеста.
@immutable
class DesktopEmojiFontLoad {
  const DesktopEmojiFontLoad({
    required this.loaded,
    required this.reason,
    this.path = '',
    this.bytes = 0,
    this.readMs = 0,
    this.registerMs = 0,
  });

  /// Движок знает семейство [kDesktopEmojiFontFamily] — проверено замером,
  /// а не тем, что вызов вернулся без ошибки (см. [DesktopEmojiFontLoader]).
  final bool loaded;

  /// `ok`, `not_windows`, `absent` (файла нет), `rejected` (движок файл не
  /// принял) или `error:<тип ошибки>`.
  final String reason;
  final String path;
  final int bytes;
  final int readMs;
  final int registerMs;

  @override
  String toString() =>
      'loaded=$loaded reason=$reason bytes=$bytes read=${readMs}ms '
      'register=${registerMs}ms path=$path';
}

/// Шрифт эмодзи Windows — Noto, как на телефоне (30.09.2026, Э1).
///
/// Файл лежит в `data\` рядом с `Secretly.exe` (кладёт `windows/CMakeLists.txt`)
/// и регистрируется под именем [kDesktopEmojiFontFamily]; запасной шрифт с
/// этим именем текст ПК получает из `DType` и темы (см. `emoji_font.dart`).
///
/// 🔴 НИКОГДА НЕ РОНЯЕТ И НЕ ДЕРЖИТ ЗАПУСК. Нет файла, битый файл, отказ
/// движка — остаётся Segoe, как было до правки, и программа идёт дальше.
/// Запуск ждёт шрифт не дольше [kDesktopEmojiFontStartupWait]: если файл
/// читается дольше (холодный медленный диск), шрифт придёт после первого
/// кадра, и движок сам перерисует текст — регистрация шрифта рассылает
/// «шрифты сменились», и каждый абзац пересчитывает себя.
abstract final class DesktopEmojiFontLoader {
  static Future<DesktopEmojiFontLoad>? _load;

  /// Путь к файлу: `data\` рядом с программой — оттуда же движок читает
  /// `flutter_assets` (`DartProject(L"data")` в `windows/runner/main.cpp`).
  static String get fontPath {
    final override = debugFontPathOverride;
    if (override != null) return override;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    return '$exeDir${sep}data$sep$kDesktopEmojiFontFileName';
  }

  /// Загрузить шрифт — один раз за жизнь процесса: повторный вызов отдаёт то
  /// же обещание. Не бросает никогда. Не на Windows сразу отвечает
  /// `not_windows`, не трогая диск.
  static Future<DesktopEmojiFontLoad> load() => _load ??= _loadOnce();

  /// Дождаться [load], но не дольше [max]. `null` — не дождались; загрузка
  /// при этом продолжается и применится сама, когда закончится.
  static Future<DesktopEmojiFontLoad?> waitAtMost(Duration max) async {
    try {
      return await load().timeout(max);
    } catch (_) {
      return null;
    }
  }

  /// Знает ли движок семейство [kDesktopEmojiFontFamily] прямо сейчас.
  ///
  /// Вызов регистрации возвращается без ошибки, даже если движок файл НЕ
  /// принял, — поэтому проверяем по результату. У Noto пробел шириной с
  /// эмодзи: 2550/2048 кегля. У шрифта, который движок возьмёт вместо
  /// незнакомого семейства (Segoe UI на Windows), пробел в четыре-пять раз
  /// уже. Ошибиться тут нельзя.
  static bool probeRegistered() {
    const size = 64.0;
    final painter = TextPainter(
      text: const TextSpan(
        text: ' ',
        style: TextStyle(
          fontFamily: kDesktopEmojiFontFamily,
          fontFamilyFallback: <String>[],
          fontSize: size,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    try {
      painter.layout();
      return (painter.width - size * kNotoEmojiAdvanceEm).abs() < 1.0;
    } catch (_) {
      return false;
    } finally {
      painter.dispose();
    }
  }

  static Future<DesktopEmojiFontLoad> _loadOnce() async {
    if (!DesktopEmojiFont.enabled) {
      return const DesktopEmojiFontLoad(loaded: false, reason: 'not_windows');
    }
    var path = '';
    DesktopEmojiFontLoad result;
    try {
      path = fontPath;
      final watch = Stopwatch()..start();
      final file = File(path);
      if (!await file.exists()) {
        result = DesktopEmojiFontLoad(loaded: false, reason: 'absent', path: path);
      } else {
        final bytes = await file.readAsBytes();
        final readMs = watch.elapsedMilliseconds;
        final register = debugRegisterOverride ?? _register;
        await register(bytes, kDesktopEmojiFontFamily);
        final registered = probeRegistered();
        result = DesktopEmojiFontLoad(
          loaded: registered,
          reason: registered ? 'ok' : 'rejected',
          path: path,
          bytes: bytes.length,
          readMs: readMs,
          registerMs: watch.elapsedMilliseconds - readMs,
        );
      }
    } catch (e) {
      result = DesktopEmojiFontLoad(
        loaded: false,
        reason: 'error:${e.runtimeType}',
        path: path,
      );
    }
    try {
      // В журнал — без пути: в нём имя пользователя Windows.
      DiagLog.event('ui', 'emoji_font', <String, Object?>{
        'ok': result.loaded,
        'why': result.reason,
        'read_ms': result.readMs,
        'reg_ms': result.registerMs,
      });
    } catch (_) {}
    return result;
  }

  static Future<void> _register(Uint8List bytes, String family) {
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    return loader.load();
  }

  /// Подмена пути к файлу для тестов.
  @visibleForTesting
  static String? debugFontPathOverride;

  /// Подмена регистрации для тестов (например, бросающая ошибку).
  @visibleForTesting
  static Future<void> Function(Uint8List bytes, String family)?
      debugRegisterOverride;

  /// Забыть прошлую загрузку и подмены — между тестами.
  @visibleForTesting
  static void debugReset() {
    _load = null;
    debugFontPathOverride = null;
    debugRegisterOverride = null;
  }
}

/// Ширина знака Noto Color Emoji в долях кегля: 2550 единиц при 2048 на кегль
/// (таблица `hmtx` файла). Такая же и у пробела — по ней [probeRegistered]
/// узнаёт шрифт.
const double kNotoEmojiAdvanceEm = 2550 / 2048;

/// Сколько запуск ждёт шрифт перед `runApp`.
///
/// Загрузка начинается первой строкой `main` и идёт параллельно с
/// подготовкой окна и трея, так что к `runApp` она обычно уже закончена
/// (замер на Mac: чтение 10,7 МБ — 12 мс, регистрация — 4 мс; на Windows цифры
/// печатает самотест `--emoji-font-selftest` в журнале CI). Предел — на
/// холодный медленный диск: дольше окно пустым не стоит, а опоздавший шрифт
/// применится сам.
const Duration kDesktopEmojiFontStartupWait = Duration(milliseconds: 300);
